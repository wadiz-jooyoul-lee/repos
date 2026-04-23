# Flow: 로그인 (이메일 · 소셜 · OAuth2 인가)

> 사용자가 와디즈에 로그인하는 체인. Spring Security OAuth2 Authorization Server(`kr.wadiz.account`)가 IdP, www.wadiz.kr 및 모노레포 앱들이 Client. 이메일·카카오·구글·Apple 로그인 모두 동일 IdP에서 수행.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/apps/account/.env-cmdrc:3-81` (환경별 `VITE_ACCOUNT_URL`)
  - `wadiz-frontend/apps/account/src/app/routes/auth.tsx`, `src/entities/oauth/lib/socialUtil.js`, `src/entities/oauth/config/constants.js`
  - `kr.wadiz.account/src/main/java/.../inbound/MainController.java:44-93` (`/`, `/login`)
  - `kr.wadiz.account/src/main/java/.../application/SecurityConfig.java:106-212` (authorizationServer + appSecurity 필터체인)
  - `kr.wadiz.account/src/main/java/.../application/authentication/wadiz/WadizAuthenticationProvider.java:27-80`
  - `kr.wadiz.account/src/main/java/.../application/authentication/wadiz/WadizUserDetailService.java:22-44`
  - `kr.wadiz.account/src/main/java/.../adapters/outbound/persistence/wadiz/user/UserProfileRepository.java:17-60`
- **외부 경계**: `LoginTryLimiter`(Redis 추정), `WadizPassWordUtils.matches`(해시 알고리즘 내부), `EmailAuthenticationSuccessHandler` 후속 리다이렉트, 카카오/구글/Apple OAuth2 Client Provider 내부 통신, `jwtDecoderFactory` JWK 로드.

---

## 개요 — 2가지 인증 진입

| 모드 | 설명 | 담당 필터체인 |
|---|---|---|
| **이메일/비밀번호** | 자체 폼 로그인 | `appSecurity` (SecurityConfig.java:167) `formLogin` |
| **소셜 (카카오/구글/Apple)** | 외부 IdP OAuth2 로그인 | `appSecurity` `oauth2Login` + `oauth2AuthenticationSuccessHandler` |

두 모드 모두 최종적으로 Spring Security Context 에 `Authentication` 을 심어 주면, `authorizationServerSecurity` 필터체인에서 `/oauth2/authorize` 응답을 사용자에게 돌려준다 (authorization code → token).

---

## 1. Client Trigger (FE/App)

### 1.1 Client 앱이 `/oauth2/authorize` 로 리다이렉트
www.wadiz.kr 또는 wadiz-frontend 앱 중 인증이 필요한 리소스를 요청하면, 클라이언트는 `https://account.wadiz.kr/oauth2/authorize?client_id=...&redirect_uri=...&scope=...&response_type=code` 로 리다이렉트.

- **환경별 host** (예: `wadiz-frontend/apps/account/.env-cmdrc:16-81`):
  - dev: `https://dev-account.wadiz.kr`
  - rc/rc2/rc3: `https://rc-account.wadiz.kr` 등
  - live: `https://account.wadiz.kr`

### 1.2 로그인 페이지 SPA 자체도 모노레포에 존재
- `apps/account/` 앱이 로그인 UX 를 Vite 로 빌드, `account.wadiz.kr` 도메인에 배포.
- 페이지 컴포넌트: `src/pages/(auth)/login/AuthLoginPage`
- 소셜 유틸: `src/entities/oauth/lib/socialUtil.js` — `signIn: ['google', 'kakao']` 매핑
- Apple Client ID 고정: `APPLE_CLIENT_ID = 'com.wadiz.signin'`

### 1.3 앱(Android/iOS) 로그인
- OAuth2 authorization code flow + PKCE (추정). 각 앱의 `kr.wadiz.account` 호출 경로는 Phase 2 앱 분석 영역.

---

## 2. IdP — `kr.wadiz.account`

### 2.1 두 개의 SecurityFilterChain
```java
// SecurityConfig.java:106 — authorizationServerSecurity
// Spring Security OAuth2 Authorization Server (OidcConfigurer + authorizationEndpoint)
@Bean
public SecurityFilterChain authorizationServerSecurity(HttpSecurity http, ...) {
    http.oauth2AuthorizationServerConfigurer(authServerConfigurer -> authServerConfigurer
        .authorizationEndpoint(authorize ->
            authorize.authorizationResponseHandler(authorizationAuthenticationSuccessHandler))
        ...);
    return http.build();
}

// :167 — appSecurity (폼 로그인 + 권한 라우팅)
@Bean
public SecurityFilterChain appSecurity(HttpSecurity http, ...) {
    http.addFilterAfter(new ExceptionHandlerFilter(), SecurityContextHolderAwareRequestFilter.class);
    http.formLogin(formLogin -> formLogin
        .loginPage("/login")
        .loginProcessingUrl("/oauth/loginPerform")             // POST 대상
        .failureHandler(wadizAuthenticationFailureHandler)
        .successHandler(emailAuthenticationSuccessHandler));

    http.authorizeHttpRequests(req -> req
        .requestMatchers("/api/**", "/login", "/signup", "/social-signup", "/social-link",
                         "/oauth2/**", "/.well-known/**", "/reset-password/*",
                         "/find-password", "/find-id", "/webhooks/**", ...).permitAll()
        .anyRequest().authenticated());

    http.oauth2ResourceServer(rs -> rs.jwt(Customizer.withDefaults()));
    // + OAuth2 Login (social)
    http.oauth2Login(login -> login.successHandler(oauth2AuthenticationSuccessHandler));
    // + Remember Me
    http.rememberMe(rm -> rm.authenticationSuccessHandler(rememberMeAuthenticationSuccessHandler));
    return http.build();
}
```

### 2.2 GET `/login` — 로그인 페이지 렌더링
```java
// MainController.java:53
@GetMapping("/login")
public String login(Model model, HttpServletRequest request, HttpServletResponse response,
                    Authentication authentication, HttpSession session) {
    if (alreadyLoggedIn(authentication) || clientIdFromSavedRequestIsEmpty(request, response)) {
        return "redirect:" + comWadizWebAddress;   // 이미 로그인 or 허용 client_id 없음
    }

    // authorize 요청 파라미터 중 email 이 있으면 폼 프리필
    String emailFromAuthorize = extractEmailFromSavedRequest(request, response);
    if (!StringUtils.isEmpty(emailFromAuthorize)) {
        model.addAttribute("prefilledEmail", emailFromAuthorize);
    }

    // 이전 실패 exception 노출
    AuthenticationException exception = (AuthenticationException)
        session.getAttribute("SPRING_SECURITY_LAST_EXCEPTION");
    if (exception instanceof IWadizErrorCodeException wadizEx) {
        setErrorLoginModel(model, wadizEx.getErrorCode().name(),
                           extractUsernameFromException(exception));
    }
    return "login.html";
}
```
뷰: Thymeleaf `login.html`. 이메일·비밀번호 입력 폼 + 소셜 로그인 버튼.

### 2.3 POST `/oauth/loginPerform` — 이메일 로그인 처리
Spring Security `UsernamePasswordAuthenticationFilter` 가 처리. `WadizAuthenticationProvider` 가 실제 검증.

```java
// authentication/wadiz/WadizAuthenticationProvider.java:29
@Override
public Authentication authenticate(Authentication authentication) {
    String username = authentication.getName();
    String password = authentication.getCredentials().toString();

    UserDetails userPrincipal = userDetailService.loadUserByUsername(username);
    checkUserPassword(password, userPrincipal, username);
    return new UsernamePasswordAuthenticationToken(userPrincipal, password,
                                                   userPrincipal.getAuthorities());
}

// :54
private void checkUserPassword(String password, UserDetails userPrincipal, String email) {
    final String userId = userPrincipal.getUsername();
    if (loginTryLimiter.isOverLimit(userId)) {
        loginTryLimiter.resetExpireTime(userId);
        throw new WadizTooManyLoginErrorAuthenticationException(email);
    }
    if (!isSame(password, userPrincipal.getPassword())) {
        if (loginTryLimiter.increaseCountAndOverLimit(userId)) {
            throw new WadizTooManyLoginErrorAuthenticationException(email);
        }
        throw new WadizBadCredentialAuthenticationException(email);
    }
    loginTryLimiter.clearCount(userId);
}

// :73
private boolean isSame(String password, String userPassword) {
    return WadizPassWordUtils.matches(password, userPassword);   // 해시 비교
}
```

**속도 제한 (LoginTryLimiter)**: 실패 카운트가 한계 초과 시 `WadizTooManyLoginErrorAuthenticationException`. 성공 시 카운터 클리어 → 정상 경로 복귀.

### 2.4 `WadizUserDetailService#loadUserByUsername`
```java
// authentication/wadiz/WadizUserDetailService.java:23
@Override
public UserDetails loadUserByUsername(String username) {
    UserDTO user = userRepositoryPort.findUserDTOByUsername(username)
        .orElseThrow(() -> new WadizUserNotFoundException(username));
    return createSecurityUser(user.getId().toString(), user.getPassword(), user.getAttributes());
}

private UserDetails createSecurityUser(String userId, String password, Map<String, Object> attrs) {
    WadizUser u = new WadizUser(userId, password,
        AuthorityUtils.createAuthorityList("ROLE_USER"));
    u.setAttribute(attrs);
    return u;
}
```

### 2.5 소셜 로그인 흐름
- `oauth2Login` 필터가 카카오/구글/Apple 인가 완료 후 호출.
- `SocialAuthenticationSuccessHandler` (SecurityConfig.java:229) → 소셜 계정을 와디즈 계정과 연결(없으면 `/social-signup` 또는 `/social-link` 플로우로 분기 가능).

### 2.6 인가 코드 발급 · 토큰 교환
- `formLogin` 또는 `oauth2Login` 성공 → Spring Security Context 에 Authentication 등록
- `authorizationServerSecurity` 필터체인이 대기중이던 `/oauth2/authorize` 요청을 resume → 302 redirect_uri?code=XXX 발급
- 클라이언트가 `/oauth2/token` 으로 code 교환 → access_token + refresh_token

---

## 3. Backend (UserProfile 조회 대상)
IdP 자체가 "백엔드" 이므로 별도 서비스 호출 없음. 단 `kr.wadiz.account` 는 JPA 로 같은 MySQL 내 `UserProfile`, `Password`, `PhotoEntity`, `MakerInfo` 를 조회.

후속 API 호출 시 access_token 검증에는 OAuth2 Resource Server + JWT 이용.

---

## 4. DB

### 4.1 사용자 조회 JPA 쿼리 (`UserProfileRepository.java:17-40`)
```java
@Query("""
  SELECT new kr.wadiz.oauth2.adapters.outbound.persistence.wadiz.user.UserDTO(
      user.userId, password.password, user.nickname, photo.photoUrl,
      user.username, user.validEmail, user.mobileNumber, user.validMobileNumber,
      user.country, user.language, maker.language)
  FROM UserProfile user
  LEFT JOIN PhotoEntity photo ON user.photoId = photo.photoId
  LEFT JOIN Password password ON user.userId = password.userId
  LEFT JOIN MakerInfo maker   ON user.userId = maker.userId
  WHERE user.username = :username
    AND user.userStatus = 'NM'
""")
Optional<UserDTO> findUserDTOByUsername(@Param("username") String username);
```
→ MySQL: UserProfile JOIN Photo JOIN Password JOIN MakerInfo WHERE username = ? AND userStatus = 'NM'(Normal).

### 4.2 관련 테이블

| 테이블 | 역할 |
|---|---|
| `UserProfile` | 기본 사용자 정보 (username, nickname, email, mobile, country, language, photoId, userStatus) |
| `Password` | 사용자 비밀번호 해시 (userId 1:1) |
| `PhotoEntity` | 프로필 사진 |
| `MakerInfo` | 메이커 추가 정보 (1:1, 선택) |
| `SocialAccount` (참고) | 소셜 연결 메타 |

### 4.3 `userStatus` 필터 `'NM'`
Normal 만 로그인 허용. 휴면/탈퇴/파기 상태는 미매칭 → `WadizUserNotFoundException` → 적절한 에러 페이지로 리다이렉트.

### 4.4 LoginTryLimiter (Redis)
- 키 패턴 추정: `login:try:{userId}` (횟수) · TTL
- 상세 구현은 이 문서 범위 외.

---

## 엔드투엔드 시퀀스

### A. 이메일 로그인 + OAuth2 authorize
```
[FE: 보호 리소스 접근 (예: www.wadiz.kr/funding/checkout)]
   │  (세션 없음 감지 → 리다이렉트)
   ▼
GET https://account.wadiz.kr/oauth2/authorize?client_id=X&redirect_uri=...&response_type=code&scope=...
   │
   │  [authorizationServerSecurity] — 인증 안 됨
   │  SavedRequest 에 authorize 요청 저장 → /login 로 redirect
   ▼
GET /login
   │  [appSecurity → MainController#login]     (MainController.java:53)
   │  → login.html (이메일 · 비밀번호 폼, 소셜 버튼)
   ▼
[사용자가 이메일 + 비밀번호 입력 + Submit]
   │
   ▼
POST /oauth/loginPerform  (form data: username, password, _csrf)
   │
   │  [UsernamePasswordAuthenticationFilter]
   │     → WadizAuthenticationProvider#authenticate   (WadizAuthenticationProvider.java:29)
   │          ├─ userDetailService.loadUserByUsername(username)
   │          │     └─ JPA: UserProfile ⋈ Password ⋈ Photo ⋈ MakerInfo
   │          │         WHERE username = ? AND userStatus = 'NM'
   │          ├─ loginTryLimiter.isOverLimit(userId)?  → TooManyLoginError if true
   │          ├─ WadizPassWordUtils.matches(rawPw, hashedPw)
   │          │     ├─ 실패: increaseCountAndOverLimit → BadCredential / TooMany
   │          │     └─ 성공: clearCount
   │          └─ return UsernamePasswordAuthenticationToken(user, pw, authorities)
   │
   │  [EmailAuthenticationSuccessHandler]
   │     ├─ 세션 생성 (JSESSIONID 쿠키 발행)
   │     └─ SavedRequest 로 복귀 (OAuth2 authorize 재개)
   │
   ▼
[authorizationServerSecurity 필터체인 재진입]
   │  사용자 consent 필요하면 consent 페이지 경유
   │  OAuth2AuthorizationCodeGeneration → 302 redirect_uri?code=XXX&state=...
   ▼
[Client (예: com.wadiz.web) 콜백 엔드포인트]
   │  POST https://account.wadiz.kr/oauth2/token    (code + client_credentials)
   │
   │  [OAuth2 Authorization Server 표준 Token Endpoint]
   │     → access_token + refresh_token + id_token(OIDC 시) 발급
   │
   │  클라이언트 서버가 응답 토큰을 브라우저 세션(또는 쿠키)에 저장
   ▼
[사용자는 원래 요청했던 보호 리소스에 세션/토큰과 함께 접근]
```

### B. 소셜 로그인 (예: 카카오)
```
GET /login → "카카오로 로그인" 클릭
   │
   ▼
[oauth2Login 필터 → 카카오 OAuth2 리다이렉트]
   │
   │ 카카오 인증 완료 → GET /login/oauth2/code/kakao?code=XXX
   ▼
[oauth2Login 후처리]
   │  ├─ 카카오 프로필 조회 (kakao API)
   │  └─ 와디즈 SocialAccount 매칭
   │        ├─ 매칭 성공 → 기존 user 로 Authentication
   │        └─ 매칭 실패 → /social-signup 또는 /social-link 로 리다이렉트
   │
   ▼
[SocialAuthenticationSuccessHandler]
   │  세션 생성 → 대기중이던 authorize 재개
   ▼
(A 와 동일하게 code → token 발급)
```

---

## 경계·미탐색

1. **`EmailAuthenticationSuccessHandler` 내부 리다이렉트 규칙** — SavedRequest 복원·에러 시 fallback, `returnURL` 쿼리 파라미터 우선순위 등 추가 검증.
2. **`LoginTryLimiter` 구현** — Redis 사용 여부·키 네임스페이스·TTL·한도 수치. 코드 위치만 확인됨.
3. **`WadizPassWordUtils.matches`** — BCrypt / PBKDF2 / 자체 해시 여부.
4. **Remember-Me 토큰** — `RememberMeAuthenticationSuccessHandler` 경로와 DB 저장소 (`PersistentToken*`) 추가 분석 필요.
5. **OAuth2 Client 등록** — 어떤 client_id 가 등록되어 있고(www.wadiz.kr, 모바일 앱들, 파트너존 등) redirect_uri 규칙은 별도 문서(`kr.wadiz.account/persistence.md`의 `RegisteredClient` 참조).
6. **소셜 계정 연결·분리 플로우** — `/social-signup`, `/social-link`, Apple Notification webhook 은 별도 flow 로 분리 가능.
7. **앱(Android/iOS) PKCE** — 앱의 OAuth2 Authorization Code + PKCE 세부는 Phase 2 앱 분석 영역.
8. **`userStatus = 'NM'`** 외 상태(휴면/파기/탈퇴)에서 사용자가 로그인 시도 시 별도 가이드 페이지 라우팅 경로는 `WadizUserNotFoundException` 핸들러 내부 추적 필요.
