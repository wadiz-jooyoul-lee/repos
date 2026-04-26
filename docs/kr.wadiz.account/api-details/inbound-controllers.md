# kr.wadiz.account Inbound Controllers 상세 스펙

> 📅 **2026-04-26 master pull 보강** (7 커밋)
>
> ### Apple Notification DTO 분리 (`adapters/inbound/dto/`)
> - **`AppleEventPayload.java`** 신규 — `events` 객체 페이로드 (type, sub_type 등)
>   - 이벤트 타입: `email-disabled` / `email-enabled` / `consent-revoked` / `account-delete`
> - **`AppleServerNotificationEvent.java`** 신규 — Apple S2S Notification 요청 본문
>   - Apple 은 `payload` 필드만 전송 (JWT 형태) — JWT 디코딩하여 type/sub/email 등 추출 필요
>   - 참고: https://developer.apple.com/documentation/sign_in_with_apple/processing_changes_for_sign_in_with_apple_accounts
>
> 기존 `AppleNotificationController` (`POST /webhooks/apple/server-notifications`) 가 위 DTO 사용하도록 갱신.
>
> ### 소셜 로그인 BE3-310
> - **소셜 로그인 시 같은 provider 슬롯 점유 edge case** 분리 처리 (`SocialUserRepository`)
> - 소셜 계정 목록 연동 시점 **오름차순 정렬** 변경
>
> ### FE1-421 — sendWebMessage 브리지 추가
> - `global-account` layout.html 에 `sendWebMessage` JS 브리지 함수 추가
> - 의미: account.wadiz.kr 이 앱 WebView 안에서 동작할 때 native 와 메시지 교환하기 위한 브리지 — login flow 의 앱 임베드 흐름에 영향
>
> ### 기타
> - `usercoupon/UserCouponAdapter`, `UserCouponClient`, `fastmail2/NormalMailClient` 변경
> - `application/ProjectConfig` 변경 (Spring 설정 보강)

---

> **기록 범위**
>
> - 이 문서는 `kr.wadiz.account` 레포 안의 `kr.wadiz.oauth2.adapters.inbound` 패키지(및
>   소셜 인가 어댑터에 해당하는 `application.authentication.social.kakao`의 `KakaoOAuth2AuthorizationRequestRegisterController`)의
>   HTTP 엔드포인트만을 관측하여 기록한다.
> - OAuth2/OIDC 표준 엔드포인트(`/oauth/authorize`, `/oauth/token`, `/oauth/revoke`,
>   `/oauth/check_token`, `/oauth/token_key`, `/userinfo`, `/connect/register`,
>   `/.well-known/*`)는 Spring Authorization Server가 제공하며 이 레포에 별도
>   컨트롤러 매핑이 없다. `SecurityConfig.java`의 `AuthorizationServerSettings`를
>   통해서 경로만 리맵되어 있고, 상세 동작(토큰 발급·검증 로직)은 외부(Spring
>   Authorization Server 1.2.6) 라이브러리의 기본 필터/핸들러 영역이다.
> - Spring Security 표준 필터가 제공하는 `/oauth/loginPerform`, `/oauth/logout`,
>   `/oauth2/authorize/**`, `/oauth2/callback/*`는 `SecurityConfig`의 `formLogin` /
>   `logout` / `oauth2Login`이 등록한 경로이므로 "컨트롤러 없음 / 설정만 존재"로
>   명시한다.
> - UseCase/ApplicationService 구현체 내부 로직은 같은 레포의 `domain.applicationservice`
>   패키지에 있지만 본 문서에서는 컨트롤러 입구까지만 기록하고, UseCase는
>   포트 시그니처만 나열한다. DB/Redis/외부 호출의 세부 SQL·키·Feign URL은
>   이 레포의 overview 문서(`docs/kr.wadiz.account/kr.wadiz.account.md`)와
>   `adapters.outbound.*` 문서에 의존한다.

---

## 1. 개요

`kr.wadiz.account`의 inbound 계층은 크게 세 가지 축으로 나뉜다.

1. **Spring Authorization Server 표준 OAuth2/OIDC 엔드포인트**
   - `OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http)`
     (`SecurityConfig.java:113`)로 자동 등록된다.
   - Wadiz는 기본 Spring 경로(`/oauth2/*`)를 `AuthorizationServerSettings`
     (`SecurityConfig.java:268-278`)에서 `/oauth/*`로 **리맵**만 하고, 해당 경로에
     대응하는 `@Controller`는 이 레포에 존재하지 않는다.
2. **Spring Security form/social login 필터가 제공하는 경로**
   - `/oauth/loginPerform` (이메일·패스워드 로그인),
     `/oauth/logout` (로그아웃),
     `/oauth2/authorize/*` (외부 Provider 소셜 로그인 진입),
     `/oauth2/callback/*` (외부 Provider 리다이렉트 수신).
   - `SecurityConfig`의 `formLogin`, `logout`, `oauth2Login` 구성으로 등록되며,
     이 레포에 매핑된 `@Controller` 메서드는 없다.
3. **Wadiz 커스텀 컨트롤러 (본 문서 주 대상, 12개)**
   - 로그인/가입/소셜 연결을 위한 SPA 페이지 진입(뷰 렌더링)
   - 이메일 간편 가입/소셜 간편 가입/계정 연결 REST API
   - 이메일 인증 코드 발송·검증(V1·V2)
   - 아이디 찾기/비밀번호 재설정 REST API
   - 세션/토큰/쿠키 관리 API (관리자용 x-api-key + 사용자용 JWT 두 방식)
   - Apple Sign-In 이벤트 웹훅
   - 에러 코드 i18n 목록
   - 운영 정보(info, release note)
   - 카카오 SDK 용 Authorization Request 수동 등록 API
   - 디버깅용 callback page

이 문서는 **3의 12개 컨트롤러**를 파일별로 전수 기록한다.

---

## 2. Spring Authorization Server가 제공하는 표준 엔드포인트

### 2.1 두 개의 `SecurityFilterChain`

`SecurityConfig.java`는 두 개의 `@Bean SecurityFilterChain`을 `@Order`로 분리한다. 이 순서가 경로 매칭의 우선순위를 결정한다.

1. **`@Order(1) authorizationServerSecurity`** (`SecurityConfig.java:104-163`)
   - `OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http)` 호출 — 내부에서 `OAuth2AuthorizationServerConfigurer`가 요청 매처를 등록. 해당 매처가 매칭되는 요청만 이 필터 체인에서 처리된다(즉 `/oauth/authorize`, `/oauth/token`, `/oauth/revoke`, `/oauth/check_token`, `/oauth/token_key`, `/userinfo`, `/connect/register`, `/connect/logout`, `/.well-known/*`).
   - `tokenEndpoint`에 Wadiz 커스텀 grant의 converter/provider 추가(`SecurityConfig.java:139-147`). 기본 authorization_code/refresh_token/client_credentials grant 외에 **Wadiz custom password grant**를 지원.
   - `oidc().logoutEndpoint(...)`에 `WadizOidcLogoutAuthenticationConverter` + `WadizOidcLogoutAuthenticationProvider` + `WadizOidcLogoutHandler`를 추가하여 **RememberMe 쿠키까지 정리**한다(`SecurityConfig.java:119-137`).
   - `authorizationEndpoint`에 `AuthorizationAuthenticationSuccessHandler`를 `authorizationResponseHandler`로 주입(`SecurityConfig.java:116`) — authorization_code 발급 후 리다이렉트 플로우 커스터마이즈.
   - `oauth2ResourceServer(jwt)` 활성 — access token 유효성 검증. JWK는 `resources/keystore/oauth-keystore.jks`(alias `oauth2.0`, 비밀번호 `oauth-pass`)에서 매 기동 시 로드(`SecurityConfig.java:298-303`).
   - `exceptionHandling(authenticationEntryPoint=new LoginUrlAuthenticationEntryPoint("/login"))` — 미인증 상태에서 `/oauth/authorize` 접근 시 `/login`으로 리다이렉트.

2. **`@Order(2) appSecurity`** (`SecurityConfig.java:165-251`)
   - `ExceptionHandlerFilter`를 `SecurityContextHolderAwareRequestFilter` 뒤에 추가해 필터 레벨 예외를 JSON `ProblemDetail`로 변환(`SecurityConfig.java:173`).
   - `formLogin(loginPage="/login", loginProcessingUrl="/oauth/loginPerform", successHandler=EmailAuthenticationSuccessHandler, failureHandler=WadizAuthenticationFailureHandler)` (`SecurityConfig.java:174-179`).
   - `oauth2Login(loginPage="/login", authorizationEndpoint.baseUri="/oauth2/authorize", redirectionEndpoint.baseUri="/oauth2/callback/*", userInfoEndpoint.userService=WadizOAuth2UserService, oidcUserService=WadizOidcUserService, successHandler=SocialAuthenticationSuccessHandler, failureHandler=WadizAuthenticationFailureHandler)` (`SecurityConfig.java:215-230`).
   - `rememberMe(rememberMeServices=WadizPersistentTokenBasedRememberMeServices, authenticationSuccessHandler=RememberMeAuthenticationSuccessHandler)` (`SecurityConfig.java:245-248`).
   - `logout(logoutUrl="/oauth/logout")` (`SecurityConfig.java:211-213`).
   - `authorizeHttpRequests`로 `permitAll` 경로 21개 + CORS preflight 허용, 그 외 `authenticated()` (`SecurityConfig.java:181-207`).
   - `sessionManagement.sessionFixation().migrateSession()`, CSRF disable, `X-Frame-Options=SAMEORIGIN`, CORS enabled.

### 2.2 AuthorizationServerSettings 경로 리맵

`SecurityConfig.java:268-278` 의 `AuthorizationServerSettings`:

```java
AuthorizationServerSettings.builder()
    .authorizationEndpoint("/oauth/authorize")          // default: /oauth2/authorize
    .tokenEndpoint("/oauth/token")                      // default: /oauth2/token
    .tokenIntrospectionEndpoint("/oauth/check_token")   // default: /oauth2/introspect
    .tokenRevocationEndpoint("/oauth/revoke")           // default: /oauth2/revoke
    .jwkSetEndpoint("/oauth/token_key")                 // default: /oauth2/jwks
    .oidcUserInfoEndpoint("/userinfo")                  // default: /userinfo
    .oidcClientRegistrationEndpoint("/connect/register")// default: /connect/register
    .build();
```

| Method   | Path                                | 제공 주체              | 비고 |
|----------|-------------------------------------|------------------------|------|
| GET/POST | `/oauth/authorize`                  | Authorization Server   | authorization_code 발급 진입점. `LoginUrlAuthenticationEntryPoint("/login")` 이 401→`/login` 리다이렉트(`SecurityConfig.java:158-159`). |
| POST     | `/oauth/token`                      | Authorization Server   | 표준 grant(`authorization_code`, `refresh_token`, `client_credentials`) + Wadiz 커스텀 password grant. 커스텀 converter/provider(`application/customgrant/*`)가 `tokenEndpoint`에 등록됨(`SecurityConfig.java:139-147`). |
| POST     | `/oauth/check_token`                | Authorization Server   | 토큰 인트로스펙션(RFC 7662). |
| POST     | `/oauth/revoke`                     | Authorization Server   | 토큰 취소(RFC 7009). |
| GET      | `/oauth/token_key`                  | Authorization Server   | JWK Set. 키는 `resources/keystore/oauth-keystore.jks` alias `oauth2.0` (`SecurityConfig.java:298-303`)에서 매 기동 시 로드. |
| GET      | `/.well-known/jwks.json`            | Authorization Server   | JWK 표준 디스커버리 경로(기본 제공). |
| GET      | `/.well-known/openid-configuration` | Authorization Server   | OIDC Discovery(기본 제공). |
| GET      | `/userinfo`                         | Authorization Server   | OIDC UserInfo. `WadizOidcUserService`가 커스터마이즈. |
| POST     | `/connect/register`                 | Authorization Server   | OIDC Dynamic Client Registration. |
| GET      | `/connect/logout`                   | Authorization Server   | OIDC RP-Initiated Logout. `WadizOidcLogoutAuthenticationConverter` + `WadizOidcLogoutAuthenticationProvider` + `WadizOidcLogoutHandler` 주입(`SecurityConfig.java:119-137`) — RememberMe까지 정리. |
| POST     | `/oauth/loginPerform`               | `formLogin.loginProcessingUrl` | `SecurityConfig.java:176`. username/password로 세션 로그인. 성공: `EmailAuthenticationSuccessHandler`, 실패: `WadizAuthenticationFailureHandler`. |
| POST     | `/oauth/logout`                     | `logout.logoutUrl`      | `SecurityConfig.java:211-213`. |
| GET      | `/oauth2/authorize/{registrationId}`| `oauth2Login.authorizationEndpoint.baseUri` | `SecurityConfig.java:218-219`. 외부 Provider(kakao/naver/apple/line/google/facebook) 로그인 진입. `WadizOAuth2AuthorizationRequestResolver`가 Kakao는 `service_terms`, LINE은 `bot_prompt` 파라미터 주입. |
| GET      | `/oauth2/callback/{registrationId}` | `oauth2Login.redirectionEndpoint.baseUri` | `SecurityConfig.java:221-223`. 외부 Provider 콜백. `WadizOAuth2UserService`/`WadizOidcUserService` 가 userinfo 조회 → `SocialAccount`로 변환. 성공: `SocialAuthenticationSuccessHandler`, 실패: `WadizAuthenticationFailureHandler`. |

> 위 표의 "Provider별 등록 경로"는 `application.yml`의 `spring.security.oauth2.client.registration.*`에서 오며, 이 레포에 별도 매핑 클래스는 없다. 단, **카카오 SDK용 수동 등록**은 아래 §4.12 `KakaoOAuth2AuthorizationRequestRegisterController`가 별도로 제공한다.

### 2.3 JWT 클레임 커스터마이저

`SecurityConfig.jwtCustomizer()` (`SecurityConfig.java:327-348`)가 `tokenEndpoint`의 토큰 생성 시점에 클레임을 주입한다.

| 토큰 종류 | 주입 클레임 | 소스 |
|-----------|-------------|------|
| `ACCESS_TOKEN` | `scope` (space-separated), `id`, `user_name` | `setAccessTokenClaims(claims, attributes)` (`SecurityConfig.java:377-380`), principal이 `OAuth2User` 또는 Wadiz `WadizUser`일 때 |
| `ID_TOKEN` (OIDC) | `nickname`, `picture` (optional), `email`, `email_verified` | `setIdTokenClaims(claims, attributes)` (`SecurityConfig.java:363-375`) |

- `scope`는 배열→공백 구분 문자열로 변환(`setScopeClaimFromArrayToString`, `SecurityConfig.java:350-361`).
- `phone_number`/`phone_number_verified`는 주석 처리된 TODO로 남아 있음.

### 2.4 Token Generator

`SecurityConfig.tokenGenerator(jwkSource)` (`SecurityConfig.java:311-320`):

```java
DelegatingOAuth2TokenGenerator(
    jwtGenerator,                    // OIDC ID Token · scope=openid인 경우 JWT access token
    new OAuth2AccessTokenGenerator(), // 반투명 access token (기본)
    new OAuth2RefreshTokenGenerator() // refresh token
)
```

- `JwtEncoder`는 `NimbusJwtEncoder(jwkSource)`. 서명 키는 §2.1의 `oauth2.0` alias RSA.
- `JwtDecoder` Bean은 `OAuth2AuthorizationServerConfiguration.jwtDecoder(jwkSource)` (`SecurityConfig.java:322-325`).

### 2.5 LINE OIDC 분기

`SecurityConfig.jwtDecoderFactory(LineIdTokenDecoder)` (`SecurityConfig.java:413-430`): `registrationId == "line"` 인 경우 `LineIdTokenDecoder`(HS256 직접 처리)를 반환, 그 외(google, apple 등 OIDC)는 `JwtDecoders.fromIssuerLocation(issuerUri)` 표준 decoder 사용.

### 2.6 공개 경로 (`SecurityConfig.java:182-204`)

App FilterChain(`Order(2)`)이 `permitAll` 처리하는 경로는 다음과 같다.

```
/v3/api-docs/**, /api/**, /h2-console/**, /.well-known/**, /static/favicon.ico,
/login, /reset-password/*, /find-password, /find-id,
/signup, /social-signup, /social-link,
/oauth2/**, /error, /swagger-ui/**, /test/**, /info/**,
/sockjs-node/**, /actuator/**, /webhooks/**
```

그 외 요청은 `authenticated()`. 세션은 `migrateSession()`, CSRF disable, CORS 활성화.

---

### 2.7 SecurityFilterChain 간 경로 중복 주의

Authorization Server FilterChain이 담당하는 경로(§2.1 목록)는 App FilterChain(`Order(2)`)의 `permitAll` 매처와 **별도**로 처리된다. 예를 들어:

- `/oauth/authorize` → `Order(1)` 체인. `LoginUrlAuthenticationEntryPoint("/login")`이 401 → `/login` 리다이렉트 후 App 체인의 `/login`(`MainController.login`)에서 뷰 렌더.
- `/oauth2/authorize/kakao` → `Order(2)` 체인. `oauth2Login.authorizationEndpoint`가 가로채 Kakao 리디렉션 생성.
- `/oauth2/callback/kakao` → `Order(2)` 체인. `oauth2Login.redirectionEndpoint`가 Kakao code → access token 교환.

따라서 **`/oauth/*` 경로와 `/oauth2/*` 경로는 의미가 완전히 다르다**. `/oauth/authorize`는 "이 레포를 Authorization Server로 보는 클라이언트용", `/oauth2/authorize/*`는 "이 레포가 Kakao/Naver 등에 대해 Client가 되는 경로"다. 네이밍이 동일 prefix로 시작해 혼동하기 쉬움.

---

## 3. 전역 예외 핸들러

`GlobalExceptionHandler.java:28` (`@RestControllerAdvice`) — 본 문서 내 모든 REST 컨트롤러(view 반환 컨트롤러 제외)에 공통 적용되는 응답 포맷을 결정한다.

| 예외                                                                 | HTTP Status | 응답 포맷                                                      |
|----------------------------------------------------------------------|-------------|----------------------------------------------------------------|
| `MethodArgumentNotValidException`                                    | 400 (기본)  | `ProblemDetail` + `errorCode` 프로퍼티(첫 번째 FieldError의 message → `ErrorCode`로 변환, 실패 시 `INPUT_VALIDATION_ERROR`). `detail` 필드는 `MessageSource.getMessage(ErrorCode.key(), locale)`로 i18n 치환. (`GlobalExceptionHandler.java:46-65`) |
| `BadCredentialsException`                                            | 400         | `errorCode=BAD_CREDENTIAL` (`GlobalExceptionHandler.java:68-74`) |
| `WadizAuthenticationException`, `WadizUserNotFoundException`, `WadizException` | 각 예외의 `getHttpStatus()` | `errorCode` = 예외의 `getErrorCode().name()` (`GlobalExceptionHandler.java:76-83`) |
| `Exception` (그 외)                                                  | 500         | `UNKNOWN_ERROR` (`GlobalExceptionHandler.java:85-90`) |

공통 `ErrorCode` enum은 `kr.wadiz.oauth2.common.ErrorCode` (`ErrorCode.java:3-77`). 40여 개 코드 + i18n 메시지 키.

### 3.1 `ErrorCode` 전수 목록 (`ErrorCode.java:3-40`)

```
# email
INPUT_VALIDATION_ERROR      input.validation.error
EMAIL_ALREADY_EXISTS        email.already.exists
DROPOUT_HISTORY_EXISTS      dropout.history.exists
INVALID_PASSWORD            invalid.password
NO_PASSWORD                 no.password
BAD_CREDENTIAL              bad.credential
TOO_MANY_LOGIN_TRY          too.many.login.try
EXPIRED_AUTHENTICATION_CODE expired.authentication.code
INVALID_AUTHENTICATION_CODE invalid.authentication.code
INVALID_EMAIL_PATTERN       invalid.email.pattern
INVALID_NICKNAME_PATTERN    invalid.nickname.pattern
INVALID_PASSWORD_PATTERN    invalid.password.pattern
FORBIDDEN_NICKNAME          forbidden.nickname
EMAIL_NOT_AUTHENTICATED     email.not.authenticated

# social
LINK_WITH_PASSWORD          link.with.password
LOGIN_WITH_EMAIL            login.with.email
LOGIN_WITH_ANOTHER_SNS      login.with.another.sns
EMAIL_NOT_MATCH             email.not.match
SOCIAL_LOGIN_REQUIRED       social.login.required

# password
SAME_AS_PREVIOUS_PASSWORD   same.as.previous.password
INVALID_RESET_LINK          invalid.reset.link
EMAIL_NOT_FOUND             email.not.found

# common
EMPTY_VALUE                 empty.value
TERMS_NOT_AGREED            terms.not.agreed
CLIENT_ID_NOT_FOUND         client.id.not.found
INVALID_API_KEY             invalid.api.key
UNKNOWN_ERROR               unknown.error
SIGNUP_COMPLETE_URL_NOT_REGISTERED signup.complete.url.not.registered
LINK_COMPLETE_URL_NOT_REGISTERED   link.complete.url.not.registered
```

i18n 메시지 파일은 `MessageSource` Bean이 로드하는 `messages_{locale}.properties` (프로젝트 `src/main/resources`에 있다고 추정 — 정확한 위치 확인은 본 문서 범위 밖).

### 3.2 `ValidationErrorCodeExtractor` 동작

`handleMethodArgumentNotValid`(`GlobalExceptionHandler.java:46-65`)는 첫 번째 `FieldError`의 `DefaultMessage`를 `ValidationErrorCodeExtractor.extractErrorCodeFromFieldError(fe)`로 넘겨 `ErrorCode`로 변환한다. 매칭 로직:

- `ErrorCode.fromKey(messageKey)` — `ErrorCode.values()`를 순회해 `key()`가 일치하는 enum 반환(`ErrorCode.java:56-67`).
- DTO의 `@Email(message="{invalid.email.pattern}")`, `@NotBlank(message="{empty.value}")`, `@Password(message="{invalid.password.pattern}")` 메시지 키가 각각 `INVALID_EMAIL_PATTERN`, `EMPTY_VALUE`, `INVALID_PASSWORD_PATTERN`으로 매핑된다.

---

## 4. 컨트롤러별 상세

### 4.1 `MainController` — 로그인/가입 SPA 진입

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/MainController.java:30`
- 클래스 선언: `@Controller`(뷰 반환), **base path 없음**.
- 의존성:
  - `SocialAccountRepositoryPort socialUserRepository` (Redis-backed HttpSession에 임시 저장된 소셜 계정 로드)
  - `@Value("${wadiz.com.wadiz.web.address}") String comWadizWebAddress` — 리다이렉트 대상(와디즈 본 사이트).
  - `RequestCache requestCache = new HttpSessionRequestCache()` — Spring Security의 `SavedRequest`에서 `client_id`/`email` 파라미터를 읽어와 로그인 폼에 프리필.
- 공통 동작:
  - `isBeusableBot(request)`: `beusable: true` 헤더 가진 봇 트래픽은 대부분의 사전 검증을 건너뛴다 (`MainController.java:190-193`). Beusable은 사용자 행동 분석 SaaS.
  - `alreadyLoggedIn(authentication)`: 이미 인증된 사용자면 `comWadizWebAddress`로 리다이렉트.
  - `clientIdFromSavedRequest(...)`: SavedRequest의 `client_id` 파라미터 추출. 없으면 빈 문자열.
  - 뷰는 전부 `login.html` (SPA 진입) — 로그인/가입/소셜링크가 한 SPA로 통합된다.

| 메서드 | HTTP | 경로 | 반환 | 동작 요약 | 파일:라인 |
|--------|------|------|------|-----------|-----------|
| `index` | GET | `/` | `redirect:${comWadizWebAddress}` (로그인 여부와 무관하게 항상 와디즈 본 사이트로) | — | `MainController.java:44-51` |
| `login` | GET | `/login` | `login.html` | Beusable bot 체크 → 이미 로그인했거나 SavedRequest에 `client_id` 없으면 본 사이트로. 아니면 `errorCode` 파라미터 or `session.SPRING_SECURITY_LAST_EXCEPTION`으로 모델에 `errorCode`/`username` 주입. `SavedRequest`에서 `email` 파라미터 추출하여 `prefilledEmail` 모델 속성으로 주입(이미 authorize 요청에 `email=...`이 포함된 경우 로그인 폼 자동 채우기). | `MainController.java:53-93` |
| `signup` | GET | `/signup` | `login.html` | Beusable bot 체크 → 로그인이면 본 사이트로. `client_id` 파라미터가 직접 주어지면 `requestCache.saveRequest(request, response)`로 저장(나중 로그인용). SavedRequest에 `client_id`도 없으면 본 사이트로. | `MainController.java:112-141` |
| `socialSignup` | GET | `/social-signup` | `login.html` | Beusable bot 체크 → 로그인/SavedRequest `client_id` 부재 시 본 사이트로. `socialUserRepository.loadSocialAccount()` 호출(없으면 `/signup`으로 강제 전환). | `MainController.java:143-163` |
| `linkUser` | GET | `/social-link` | `login.html` | Beusable bot 체크 → 로그인/client_id 부재 시 본 사이트로. 진입만, 뷰 그대로. | `MainController.java:165-178` |
| `resetPassword` | GET | `/reset-password/{token}`, `/find-password`, `/find-id` | `login.html` | 세 경로 모두 **같은 SPA 뷰** 반환. 실제 로직은 프런트에서 `/api/v1/find-id`, `/api/v1/password-reset/*`로 호출. | `MainController.java:181-188` |

- DB/외부 호출: `socialUserRepository.loadSocialAccount()` → Redis(`HttpSessionSocialAccountRepository`)에서 현재 HttpSession에 붙은 임시 `SocialAccount` 로드(소셜 로그인 성공 시 신규 사용자면 저장된 것).
- 특이사항:
  - `@Controller` + view name 반환이므로 GlobalExceptionHandler 의 `@RestControllerAdvice`가 JSON으로 감싸지 않는다.
  - 모든 페이지가 동일한 `login.html`을 반환하는 **single-page wrapper**. 실제 UI 분기는 프런트엔드(`src/main/resources/templates/login.html`)에서 `window.location.pathname`으로 결정.
  - `extractEmailFromSavedRequest` — `authorize?email=...` 형태로 접속 시 이메일 프리필을 지원(`MainController.java:229-241`).

---

### 4.2 `CallbackController` — 토큰 발급 디버깅 페이지 (`/v0/oauth2/callback`)

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/CallbackController.java:38`
- 클래스 선언: `@Controller @RequestMapping("/")`
- 의존성: `@Value("${spring.profiles.active}") String activeProfile`
- 특이: **프로덕션 로그인 플로우의 일부가 아니라** `authorization_code`로 토큰을 직접 교환해 디코딩 결과를 HTML로 보여주는 **개발자/디버깅 도구**.

| 메서드 | HTTP | 경로 | 동작 | 파일:라인 |
|--------|------|------|------|-----------|
| `callback` | GET | `/v0/oauth2/callback?code=...` | profile에 따라 `https://account.wadiz.kr/oauth/token` 또는 `https://{profile}-account.wadiz.kr/oauth/token`을 자기 자신에게 POST 호출(`code`/`grant_type=authorization_code`/`redirect_uri`). `client_id=com_wadiz_web`, `client_password` 또한 코드에 하드코딩. 응답 `access_token`/`id_token`을 `JwtUtils.decodeJwtPayload(...)`로 디코딩 후 `test.html` 모델에 세팅. | `CallbackController.java:42-74` |
| `testPage` | GET | `/test_page` | `hello.html` 반환. 더미. | `CallbackController.java:138-141` |

- 보안 관측:
  - `getRestTemplateForHttps()` 가 TrustStrategy로 **모든 인증서를 신뢰**(self-signed 포함, `CallbackController.java:121-123`). 내부 디버그용 명칭을 따르는 것으로 보인다.
  - `clientPassword()`에 `live=="dnrhd2Tks!"`(?) / 나머지 `"secret"` 가 **소스코드에 하드코딩**돼 있다 (`CallbackController.java:97-103`). 소스 내 `TODO : Live password needs to be changed` 주석 존재.
- DB/외부 호출: `POST {self}/oauth/token` — 본인(Authorization Server)에게 다시 token endpoint를 호출.
- 특이사항:
  - `@Controller` + view 반환. REST 아님.
  - `v0` 접두어 — v1 이전 단계 디버그용. `RequestMapping("/")`이라 `/v0/oauth2/callback`로 바로 매핑된다.

---

### 4.3 `SessionController` — 세션/토큰 관리 (Kotlin)

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/SessionController.kt:23`
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`, `@Tag(name = "세션 및 토큰 관리 Controller")`.
- 의존성: `UserSessionService`, `@Value("\${wadiz.authorization.server.adminkey}") String apiKey`.
- `const val SUB = "sub"` — JWT claim 키.

| 메서드 | HTTP | 경로 | 인증 방식 | Request | Response | 호출 | 파일:라인 |
|--------|------|------|-----------|---------|----------|------|-----------|
| `isCookieValid` | POST | `/api/v1/cookie/validity` | `x-api-key` 헤더 == `apiKey` | Header `x-api-key`; Body `CookieHolder(cookie: String)` | `CookieValidity(validity: Boolean, description: String)` | `userSessionService.validateRememberMeToken(cookieHolder.cookie)` → `WadizPersistentTokenBasedRememberMeServices.checkCookieValidity(...)`. Exception catch 시 `validity=false, description=e.message` 반환. 성공 시 `(true, "cookie is valid")`. | `SessionController.kt:29-43` |
| `removeAllSessions`(apiKey) | DELETE | `/api/v1/users/{userId}/sessions` | `x-api-key` 헤더 검증 | Path `userId: Long`; Header `x-api-key` | `ResponseEntity<Void>` 200 | `userSessionService.cleanupAllUserSessions(userId.toString())` | `SessionController.kt:46-59` |
| `removeAllSessions`(JWT) | DELETE | `/api/v1/sessions` | Bearer JWT (resource server) | `@AuthenticationPrincipal Jwt jwt` | `ResponseEntity<Void>` 200 | `userSessionService.cleanupAllUserSessions(jwt.getClaimAsString("sub"))` | `SessionController.kt:62-68` |
| `currentStatus` | GET | `/api/v1/user-login-status` | 공개 (`/api/**` permitAll) | — | `ResponseEntity<UserLoginStatus>` (body `UserLoginStatus(isLoggedIn, description)`) | `userSessionService.getCurrentUserLoginStatus(request)` | `SessionController.kt:71-79` |

- `UserSessionService.getCurrentUserLoginStatus` (`UserSessionService.java:81-101`):
  - `HttpSessionSecurityContextRepository.loadDeferredContext(request)`로 현재 세션의 `SecurityContext` 로드.
  - 인증됨 → `UserLoginStatus(true, "Account Session Exists")`
  - RememberMe 쿠키 유효 → `UserLoginStatus(true, "Rememberme Cookie Exists")`
  - 나머지 → `UserLoginStatus(false, "Login Required")`
- `cleanupAllUserSessions(userId)` (`UserSessionService.java:52-57`):
  - `sessionCleanerService.removeAllSessionsAndTokens(userId)` — Spring Session Redis indexed 세션 삭제 + (overview 문서에 따르면) `UserToken`/`UserTokenStandby` 무효화.
  - `rememberMeService.deleteToken(userId)` — RememberMe 영속 토큰 삭제.
- 예외: `apiKey` 불일치 시 `InvalidApiKeyException`(`HttpStatus.FORBIDDEN`, `INVALID_API_KEY`).
- 특이사항:
  - **두 DELETE 경로가 같은 메서드명 `removeAllSessions`로 오버로드**되어 있다(Kotlin은 허용). 하나는 admin용(x-api-key), 하나는 사용자 self-logout용(Bearer token).
  - `POST cookie/validity`는 매핑에 슬래시가 없어 `/api/v1cookie/validity`로 해석될 수 있지만 Spring이 `/api/v1/cookie/validity`로 처리한다(`@RequestMapping` path에서 leading `/` 없이 사용). 실제 호출 경로 확인 필요.

#### SessionController 인증 모드 비교표

| 엔드포인트 | 인증 매커니즘 | 예상 호출자 | `userId` 소스 |
|-----------|---------------|-------------|----------------|
| `POST /api/v1/cookie/validity` | `x-api-key` 헤더 == `${wadiz.authorization.server.adminkey}` (Jasypt 복호화) | 내부 서비스(com.wadiz.web 등)가 사용자 RememberMe 쿠키 검증 대행 | Body `CookieHolder.cookie` |
| `DELETE /api/v1/users/{userId}/sessions` | 동일 `x-api-key` | 관리 서비스가 특정 사용자의 전체 세션 강제 삭제 (예: CS 탈퇴 처리) | Path `userId: Long` |
| `DELETE /api/v1/sessions` | Bearer JWT (Authorization Server가 발급한 access token) | 사용자 본인의 전체 로그아웃(모든 기기) | JWT `sub` claim |
| `GET /api/v1/user-login-status` | 없음 (현재 세션 / RememberMe 쿠키) | 프런트엔드 / 타 서비스가 공유 세션 상태 조회 | 현재 세션 |

`HttpSessionSecurityContextRepository.loadDeferredContext(request).get()`는 요청에 붙은 세션 쿠키(JSESSIONID)를 Redis 세션 스토어에서 조회한다. Spring Session Redis는 `namespace: account`로 분리 — 다른 Wadiz 서비스가 같은 Redis 네임스페이스를 참조하여 세션 공유.

---

### 4.4 `SignUpController` — 이메일/소셜 회원가입

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/SignUpController.java:61`
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`, `@Tag(name = "회원 가입 Controller")`.
- 의존성:
  - `CreateUserApplicationService createUserApplicationService`
  - `CreateUserWithSocialAccountApplicationService createUserWithSocialAccountApplicationService`
  - `ServiceTypeManager serviceTypeManager`
  - `TermsRequestMapper mapper`
  - `SocialSignUpDtoToCommandMapper socialSignUpDtoToCommandMapper`
  - `EmailSignUpDtoToCommandMapper emailSignUpDtoToCommandMapper`
  - `SocialAccountRepositoryPort socialUserRepository` (Redis 세션 저장소)
  - `EmailValidationRepositoryPort emailValidationRepositoryPort` (Redis 인증코드)
  - `GetSignUpInformationUsecase getSignUpInformationUsecase`
  - `RegisteredClientRepository registeredClientRepository` (JPA `RegisteredClient` 테이블)
  - `AgreementToTermsConverter agreementToTermsConverter`
  - `RequestCache requestCache = new HttpSessionRequestCache()` (setter 주입 가능, 테스트용)

#### 4.4.1 POST `/api/v1/users` — 이메일 기반 회원가입

- 파일:라인: `SignUpController.java:79-107`
- Consumes: `application/json`
- Request body: `EmailSignUpDto`
  - `@Email @NotBlank String email` (메시지 키: `{invalid.email.pattern}` / `{empty.value}`)
  - `String nickname` (setter에서 `trim()` 적용, `EmailSignUpDto.java:38-40`)
  - `@Password String password` (커스텀 validator: 공백 금지·8자 이상·숫자/영문/특수문자 각 1자 이상, `PasswordValidator.java:22-60`)
  - `@NotNull AgreedTerms agreedTerms` (메시지 키: `{terms.not.agreed}`)
  - `String language = "ko"` (기본값)
  - `String country = "KR"` (기본값)
- 파라미터: `@CurrentDevice DeviceType deviceType` (커스텀 argument resolver), `HttpServletRequest`, `HttpServletResponse`, `HttpSession`.
- 흐름:
  1. `Locale locale = new Locale(emailSignUpDto.getLanguage(), emailSignUpDto.getCountry())`
  2. `emailSignUpDtoToCommandMapper.toCommand(dto, locale)` → `EmailSignUpCommand` (MapStruct. `nickname`은 `NicknameMapper.processNicknameWithEmail(nickname, email, locale)`로 보정: null이면 email 로컬파트 기반 기본 닉네임).
  3. `checkEmailAuthentication(session.getId(), email)` (`SignUpController.java:220-226`): `emailValidationRepositoryPort.loadEmailValidation(sessionId)` → 없거나 email 미일치면 `EmailNotAuthenticatedException`(`ErrorCode.EMAIL_NOT_AUTHENTICATED`, 400).
  4. `getSignUpCompleteUri(request, response)` (`SignUpController.java:170-187`):
     - `requestCache.getRequest(...).getParameterValues("client_id")`으로 SavedRequest에서 `client_id` 추출.
     - 없으면 `ClientIdNotFoundException(PRECONDITION_FAILED, CLIENT_ID_NOT_FOUND)`.
     - `registeredClientRepository.findByClientId(clientId)` → `RegisteredClient.getClientSettings().getSettings().get("settings.client.signup-complete-uri")` 추출.
     - 값 없으면 `SignUpCompleteUriNotRegisteredException(PRECONDITION_FAILED)`.
  5. `createUserApplicationService.signUpWithEmail(emailSignUpCommand, deviceType, locale)` → `User` (`@Transactional` 내부에서 `UserProfile`, `webpages_Membership`, `TbUserProvider`, `UserLocaleHistory`, `LoginHis` INSERT + 자동 로그인. 상세는 overview §4).
  6. `createUserWithSocialAccountApplicationService.updateUserTimeZone(user)` — 실패 catch + warn log only.
  7. `createUserApplicationService.doRemainingWork(user)` — 실패 catch + warn log only.
  8. 응답: `201 Created`, `Location: /api/v1/users/{userId}`, body `SignUpSuccessDto(signupRedirectUri)` = signUpCompleteUri.
- 예외 매핑: `GlobalExceptionHandler`가 `ProblemDetail` + `errorCode` 필드로 응답.

#### 4.4.2 POST `/api/v1/social-users` — 소셜 회원가입

- 파일:라인: `SignUpController.java:111-149`
- Consumes: `application/json`
- Request body: `SocialSignUpDto`
  - `@Email @NotBlank String email`
  - `String nickname`
  - `String language = "ko"`, `String country = "KR"`
  - `AgreedTerms agreedTerms` (`@NotNull` 주석 처리되어 있어 null 허용 — 카카오의 경우 서버가 약관 정보 변환해 주입)
- 흐름:
  1. `Locale` 생성.
  2. `socialSignUpDtoToCommandMapper.toCommand(dto, locale)` → `SocialSignUpCommand` (MapStruct, `socialAccount`는 ignore).
  3. `socialUserRepository.loadSocialAccount()` (Redis 세션) → null이면 `SocialLoginRequiredException(BAD_REQUEST, SOCIAL_LOGIN_REQUIRED)`.
  4. `socialSignUpCommand.setSocialAccount(socialUser)`.
  5. `socialUser instanceof KakaoAccount` 인 경우 `agreementToTermsConverter.convert(kakaoAccount.getAgreement())`로 카카오 약관 스키마를 Wadiz `Terms` 구조로 변환 후 `agreedTerms` 덮어쓰기.
  6. `getSignUpCompleteUri(request, response)` 호출 (4.4.1과 동일 로직).
  7. `createUserWithSocialAccountApplicationService.signUpWithSocial(socialSignUpCommand, deviceType, locale)` → `User` (소셜의 경우 `webpages_OAuthMembership`, `TbProviderProfile`, `TbProviderScope` INSERT 추가).
  8. `updateUserTimeZone(user)` + `doRemainingWork(user)` — 실패 시 warn log only.
  9. 응답: `201 Created`, `Location: /api/v1/users/{userId}`, body `SignUpSuccessDto(signupRedirectUri)`.
- 특이사항: 코드에 `TODO 약관정보 재정의` 주석. 카카오 약관이 terms API 포맷과 달라서 백엔드가 변환 — FE vs BE 책임 소재에 대한 결정이 남아 있음.

#### 4.4.3 GET `/api/v1/signup-information` — 가입 플로우 상태 조회

- 파일:라인: `SignUpController.java:151-163`
- 쿼리 파라미터: `isApp=false`, `isAndroid=false`, `joinType=null` (모두 optional).
- 파라미터: `@CurrentDevice DeviceType deviceType`, `HttpSession`, `Locale`.
- 흐름: `getSignUpInformationUsecase.getSignUpInformation(locale)` 반환.
- Response: `SignUpInformation(joinType, providerType, social: Social(userName, nickName, existUserName), fromTheLoginPage)` (`SignUpInformation.java:12-27`).
- 관찰: `isApp`/`isAndroid`/`joinType`/`deviceType`/`session` 파라미터는 메서드 본문에서 사용되지 않고 서명에만 존재(향후 확장 또는 Swagger 문서화 용도로 추정).

#### 4.4.4 회원가입 플로우 개요 (관측된 호출 체인)

**이메일 회원가입 full-flow (브라우저 관점)**:

1. 프런트엔드가 `POST /api/v2/authentication-code {email: "..."}` → 서버가 HttpSession id 기반 Redis 키에 6자리 코드 저장 + FastMail 발송.
2. 사용자가 수신한 코드 입력 → `GET /api/v2/authentication-code/{code}/valid` → 200/204 or 404.
3. `POST /api/v1/users`:
   - `@Valid` 검증(Jakarta Validation) — 실패 시 400 + `errorCode`.
   - `checkEmailAuthentication(sessionId, email)` — Redis에서 email 매칭 확인.
   - `getSignUpCompleteUri(...)` — SavedRequest의 `client_id`로 `RegisteredClient.clientSettings.settings.client.signup-complete-uri` 조회.
   - `createUserApplicationService.signUpWithEmail(command, deviceType, locale)` — 트랜잭션 경계. `UserProfile`, `webpages_Membership`, `TbUserProvider`, `UserLocaleHistory`, `LoginHis` INSERT + `UserCreatedEvent` 발행 + `servletPort.login(user, password)` 자동 로그인.
   - `updateUserTimeZone(user)` → `UserClient.updateUserTimeZone(userId, UserTimeZoneUpdateByCountryRequest)` — 실패 시 warn log.
   - `doRemainingWork(user)` — 확장 훅, 실패 시 warn log.
4. 201 응답 `SignUpSuccessDto(signupRedirectUri)`. 프런트엔드는 `signupRedirectUri`로 리다이렉트 → `RegisteredClient`의 redirect URL에서 세션 이미 확보된 상태로 원래 페이지 복귀.

**소셜 회원가입 full-flow**:

1. 사용자가 `GET /oauth2/authorize/kakao`(또는 다른 Provider) 진입 → Spring OAuth2 Client가 Kakao로 리다이렉트.
2. Kakao 콜백 → `GET /oauth2/callback/kakao` → `WadizOAuth2UserService.loadUser(...)` → `SocialAccount`로 변환. 기존 사용자면 `SocialAuthenticationSuccessHandler`가 바로 로그인 완료. 신규 사용자면 `SocialAccount`가 `SocialAccountRepositoryPort`(Redis-backed HttpSession)에 임시 저장 + `/social-signup`으로 리다이렉트.
3. `GET /social-signup` → `MainController.socialSignup` → `login.html` SPA 렌더.
4. 사용자 약관 동의 → `POST /api/v1/social-users`:
   - `socialUserRepository.loadSocialAccount()` — Redis에서 임시 `SocialAccount` 꺼내기.
   - KakaoAccount인 경우 `AgreementToTermsConverter.convert(...)`로 Kakao 약관 구조 → Wadiz Terms로 변환.
   - `createUserWithSocialAccountApplicationService.signUpWithSocial(command, deviceType, locale)` — `UserProfile`, `webpages_OAuthMembership`, `TbProviderProfile`, `TbProviderScope` INSERT + 로그인.
5. 201 응답 → 프런트는 `signupRedirectUri`로 리다이렉트.

**소셜 계정 기존 이메일 계정에 연결 full-flow**:

1. 1-2 단계 동일. Kakao 콜백에서 `EmailAlreadyRegisteredException` 같은 케이스 발생 시 `/social-link` 페이지로 유도.
2. `GET /social-link` → `MainController.linkUser` → `login.html` SPA.
3. 사용자가 기존 Wadiz 이메일/비번 입력 → `POST /api/v1/link-users`:
   - 세션에서 SocialAccount 로드.
   - `authenticationProvider.authenticate(email, password)` — WadizAuthenticationProvider가 `webpages_Membership` + `UserProfile` 기반 검증.
   - `servletPort.login(authentication, true)` — 세션 로그인.
   - `linkUserToSocialUserApplicationService.linkWithoutCheck(command)` — `webpages_OAuthMembership` INSERT.
4. 201 응답 `LinkSuccessDto(linkRedirectUri)`.

---

### 4.5 `IdPasswordManagementController` — 아이디/비번 관리 (Kotlin)

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/IdPasswordManagementController.kt:26`
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`, `@Tag(name = "아이디/비밀번호 관리 Controller")`.
- 의존성: `FindIdUsecase`, `SendResetPasswordMailUsecase`, `ResetPasswordUsecase`.

| 메서드 | HTTP | 경로 | Request | Response | 호출 | 파일:라인 |
|--------|------|------|---------|----------|------|-----------|
| `findUserByUsername` | POST | `/api/v1/find-id` | `EmailInfo(email: String, @NotBlank)` | `UsernameStatus(username: String, status: Status)` - `Status` enum: `EMAIL_LOGIN_OK / SNS_LOGIN_OK / DROPOUT_HISTORY_EXISTS / NOT_REGISTERED` | `findIdUsecase.findUsername(email.email)` | `IdPasswordManagementController.kt:34-39` |
| `sendPasswordResetMail` | POST | `/api/v1/password-reset/request` | `EmailInfo(email, @NotBlank)` | `ResponseEntity<Void>` 200 | `sendResetPasswordMailUsecase.sendResetPasswordMail(email.email, locale)` | `IdPasswordManagementController.kt:44-53` |
| `resetPassword` | POST | `/api/v1/password-reset/confirm` | `ResetPasswordDto(token: String @NotBlank, newPassword: String @NotBlank @Password)` | `ResponseEntity<Void>` 200 | `resetPasswordUsecase.resetPassword(dto.token, dto.newPassword)` — `@Throws(InvalidResetLinkException, SamePasswordException)` | `IdPasswordManagementController.kt:58-62` |

- `FindIdUsecase` 시그니처 (`FindIdUsecase.kt:1-11`):
  ```kotlin
  interface FindIdUsecase {
      fun findUsername(userName: String): UsernameStatus
  }
  data class UsernameStatus(val username: String, val status: Status)
  enum class Status { EMAIL_LOGIN_OK, SNS_LOGIN_OK, DROPOUT_HISTORY_EXISTS, NOT_REGISTERED }
  ```
- `ResetPasswordUsecase` 시그니처 (`ResetPasswordUsecase.kt:7-13`):
  ```kotlin
  interface ResetPasswordUsecase {
      @Throws(InvalidResetLinkException::class, SamePasswordException::class)
      fun resetPassword(token: String, password: String)
  }
  ```
- `SendResetPasswordMailUsecase.sendResetPasswordMail(username, locale)` (`SendResetPasswordMailUsecase.kt:5-7`).
- 관측 가능한 DB/외부 호출: overview 문서에 따르면 `webpages_Membership` UPDATE + Redis `PasswordResetTokenEntity` + FastMail Feign 호출. 본 컨트롤러에서는 UseCase 호출까지만 관측 가능.
- DTO 정의(하단 data class):
  - `EmailInfo(@field:NotBlank email: String)` (`IdPasswordManagementController.kt:65-68`)
  - `ResetPasswordDto(@field:NotBlank token, @field:NotBlank @field:Password newPassword)` (`IdPasswordManagementController.kt:70-77`)
- 특이: Kotlin `@field:` target을 사용해 `data class` 프로퍼티에 Jakarta Validation 적용. Java DTO(`EmailSignUpDto`)와 스타일이 다르다.

---

### 4.6 `LinkController` — 기존 계정에 소셜 계정 연결

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/LinkController.java:45`
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`, `@Tag(name = "회원 Link Controller")`.
- 의존성:
  - `LinkUserToSocialUserApplicationService linkUserToSocialUserApplicationService`
  - `LinkUserToSocialAccountCommandMapper linkUserToSocialAccountCommandMapper`
  - `SocialAccountRepositoryPort socialAccountRepository`
  - `WadizAuthenticationProvider authenticationProvider` (Wadiz 자체 email/password 인증기)
  - `ServletPort servletPort` (`login(Authentication, boolean)` 추상화)
  - `RegisteredClientRepository registeredClientRepository`
  - `RequestCache requestCache = new HttpSessionRequestCache()`

#### POST `/api/v1/link-users` — 이메일 계정 ↔ 소셜 계정 연결

- 파일:라인: `LinkController.java:55-90`
- Consumes: `application/json`
- Request body: `LinkSocialAccountDto`
  - `@Email @NotBlank String username` (= 기존 Wadiz 이메일)
  - `String password` (현재 `@Password` **미적용**; 실제 검증은 WadizAuthenticationProvider 내부에서)
- 흐름:
  1. `socialAccountRepository.loadSocialAccount()` (Redis 세션) — null이면 `SocialLoginRequiredException`.
  2. `email.equals(socialAccount.getEmail())` 미일치 → `EmailNotMatchedException(BAD_REQUEST, EMAIL_NOT_MATCH)`.
  3. `authenticationProvider.authenticate(UsernamePasswordAuthenticationToken.unauthenticated(email, password))` — 성공 시 `Authentication` 반환, 실패 시 내부에서 `BadCredentialsException` 등.
  4. `servletPort.login(authentication, true)` — 세션에 Security Context 설정(두 번째 인자 = rememberMe true).
  5. `linkUserToSocialAccountCommandMapper.toCommand(dto)` → `LinkUserToSocialAccountCommand(UserId, socialAccount)` (MapStruct; `socialAccount` ignore).
  6. `command.setSocialAccount(socialAccount)`.
  7. `WadizUser wadizUser = (WadizUser) authentication.getPrincipal()` → `command.setUserId((Long) wadizUser.getAttributes().get("id"))`.
  8. `linkUserToSocialUserApplicationService.linkWithoutCheck(command)` — `webpages_OAuthMembership` INSERT (overview §3 참조).
  9. `createLinkSuccessDto(request, response)` → `getLinkCompleteUri(...)`에서 SavedRequest의 `client_id`로 `settings.client.link-complete-uri` 추출.
  10. 응답: `201 Created`, `Location: /social-users/{provider}/{providerUserId}`, body `LinkSuccessDto(linkRedirectUri)`.
- 예외:
  - `SocialLoginRequiredException` (400, `SOCIAL_LOGIN_REQUIRED`)
  - `EmailNotMatchedException` (400, `EMAIL_NOT_MATCH`)
  - `BadCredentialsException` → `GlobalExceptionHandler`가 400, `BAD_CREDENTIAL` 변환.
  - `ClientIdNotFoundException` (412, `CLIENT_ID_NOT_FOUND`)
  - `LinkCompleteUriNotRegisteredException` (412, `LINK_COMPLETE_URL_NOT_REGISTERED`)
- 특이:
  - `HttpSession session` 파라미터는 signature에 있지만 사용되지 않음 — `TODO check .. added for test, without this test code fail, why??` 주석(`LinkController.java:60`).
  - `getClientIdFromRequestCache`가 camelCase `clientId`와 snake_case `client_id` 두 키를 모두 시도(`LinkController.java:114-122`) — 레거시 Wadiz 웹과의 호환.
  - `getLinkCompleteUri`의 throws 선언에 `SignUpCompleteUriNotRegisteredException`가 있지만 실제로 던지는 예외는 `LinkCompleteUriNotRegisteredException`(오타로 남아있는 것으로 보이나 catch되는 쪽은 superclass `WadizException`).

---

### 4.7 `MaintenanceController` — 운영 정보

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/MaintenanceController.java:24`
- 클래스 선언: `@RestController`, **base path 없음**.
- 의존성: `SessionRepository sessionRepository` (Spring Session).
- `SecurityConfig`에서 `/info/**`가 `permitAll`.

| 메서드 | HTTP | 경로 | Request | Response | 동작 | 파일:라인 |
|--------|------|------|---------|----------|------|-----------|
| `configuration` | GET | `info` | — | `ResponseEntity<Object>` JSON `{version, sessionId, client ip, server ip}` | `gradle.properties`에서 `version` 읽어 캐싱(`getVersion()`). `session.getId()` + `request.getLocalAddr()`(서버가 받은 로컬) + `request.getRemoteAddr()`(클라이언트 IP)를 섞어 반환. `sessionRepository.findById(sessionId)`도 호출되지만 반환값은 사용하지 않음. | `MaintenanceController.java:28-43` |
| `releaseNote` | GET | `info/{fileName}` | Path `fileName` | `text/plain; charset=UTF-8` | 현재 작업 디렉터리의 `{fileName}.txt` 파일을 `Files.readString(Paths.get(fileName + ".txt"))`로 읽어 본문 반환. 읽기 실패 시 `"error while reading file"`. | `MaintenanceController.java:45-58` |

- 관측:
  - `@RequestMapping` 에 leading slash가 없는 `"info"` — Spring이 `/info`로 매핑.
  - `releaseNote`가 **현재 디렉터리 상대 경로**에서 파일을 읽기 때문에 path traversal 가능성 있음(예: `?fileName=../../etc/passwd`). 실제로 `Paths.get(fileName + ".txt")`는 상위 경로를 그대로 받아들인다. `permitAll`이므로 외부에서 호출 가능.
  - 라벨된 파일은 레포 루트에 `releaseNote.txt`, `releaseHistory.txt`, `autoconf.txt` 등.
  - 필드 `version`은 첫 호출 시 1회 로드 후 메모리 캐싱.
  - `request.getLocalAddr()`/`getRemoteAddr()`의 주석(`"client ip"`/`"server ip"`)은 실제 의미와 반대. `getLocalAddr()`는 "서버가 요청을 수신한 로컬 IP", `getRemoteAddr()`는 "원격(클라이언트) IP"다.

---

### 4.8 `AuthenticationCodeV1Controller` — 이메일 인증 코드 (V1, 200)

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/AuthenticationCodeV1Controller.java:23`
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`, `@Tag(name = "이메일 확인 Controller")`.
- 의존성: `SendAuthenticationCodeViaEmailUsecase`, `CheckAuthenticationCodeValidityUsecase`.

| 메서드 | HTTP | 경로 | Request | Response | 호출 | 파일:라인 |
|--------|------|------|---------|----------|------|-----------|
| `authenticate` | POST | `/api/v1/authentication-code` | `SendCodeCommand(email)` (consumes `application/json`) | **200 OK**, void | `sendAuthenticationCodeViaEmailUsecase.sendAuthenticationCode(session.getId(), email.getEmail(), locale)` | `AuthenticationCodeV1Controller.java:30-37` |
| `isValid` | GET | `/api/v1/authentication-code/{code}/valid` | Path `code` | 200 OK / 404 (`InvalidAuthenticationCodeException` 던질 경우) | `checkAuthenticationCodeValidityUsecase.isValid(session.getId(), code)` — false면 `throw new InvalidAuthenticationCodeException()` (`kr.wadiz.oauth2.domain.exception.InvalidAuthenticationCodeException`) | `AuthenticationCodeV1Controller.java:41-48` |

- UseCase 시그니처:
  - `SendAuthenticationCodeViaEmailUsecase.sendAuthenticationCode(String sessionId, String email, Locale locale)` (`SendAuthenticationCodeViaEmailUsecase.java:5-7`).
  - `CheckAuthenticationCodeValidityUsecase.isValid(String sessionId, String code): boolean` (`CheckAuthenticationCodeValidityUsecase.java:3-5`).
- 실제 DB/외부 호출은 UseCase 구현체(domain/applicationservice)에서 수행 — overview §4 참고(Redis 코드 저장 + FastMail 발송).

---

### 4.9 `AuthenticationCodeV2Controller` — 이메일 인증 코드 (V2, 204)

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/AuthenticationCodeV2Controller.java:23`
- 클래스 선언: `@RestController @RequestMapping("/api/v2")`, `@Tag(name = "이메일 확인 Controller")` (V1과 동일 태그).
- 의존성: V1과 **완전히 동일** (`SendAuthenticationCodeViaEmailUsecase`, `CheckAuthenticationCodeValidityUsecase`).

| 메서드 | HTTP | 경로 | Request | Response | 호출 | 파일:라인 |
|--------|------|------|---------|----------|------|-----------|
| `authenticate` | POST | `/api/v2/authentication-code` | `SendCodeCommand(email)` | **204 No Content** | `sendAuthenticationCodeViaEmailUsecase.sendAuthenticationCode(...)` → `ResponseEntity.noContent().build()` | `AuthenticationCodeV2Controller.java:30-38` |
| `isValid` | GET | `/api/v2/authentication-code/{code}/valid` | Path `code` | **204 No Content** / 404 | 동일, 성공 시 `ResponseEntity.noContent().build()` | `AuthenticationCodeV2Controller.java:43-49` |

- **V1 vs V2 차이**: 제5절 참조.

---

### 4.9-bis V1과 V2의 코드 차이 (Unified Diff 관점)

두 파일은 거의 동일하다. 차이점 6곳만 요약.

| V1 | V2 |
|----|----|
| `@RequestMapping("/api/v1")` | `@RequestMapping("/api/v2")` |
| `@ApiResponse(responseCode = "200", description = "이메일 코드 발송 성공")` | `@ApiResponse(responseCode = "204", description = "이메일 코드 발송 성공")` |
| `public void authenticate(...)` | `public ResponseEntity<Void> authenticate(...)` + `return ResponseEntity.noContent().build();` |
| `@ApiResponse(responseCode = "200", description = "코드 확인 ok")` | `@ApiResponse(responseCode = "204", description = "코드 확인 ok")` |
| `return ResponseEntity.ok().build();` (isValid) | `return ResponseEntity.noContent().build();` (isValid) |

UseCase 호출부는 **완전히 동일**:

```java
this.sendAuthenticationCodeViaEmailUsecase.sendAuthenticationCode(session.getId(), email.getEmail(), locale);
// ...
if (!this.checkAuthenticationCodeValidityUsecase.isValid(session.getId(), code)) {
  throw new InvalidAuthenticationCodeException();
}
```

---

### 4.10 `AppleNotificationController` — Apple Sign-In S2S 웹훅

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/AppleNotificationController.java:31`
- 클래스 선언: `@RestController @RequestMapping("/webhooks/apple")`.
- SecurityConfig `/webhooks/**` permitAll (`SecurityConfig.java:202`).
- 의존성: `AppleEventTokenParser appleEventTokenParser` (Nimbus JOSE 기반 JWT 검증기, `application/authentication/social/AppleEventTokenParser.java:29`).

| 메서드 | HTTP | 경로 | Request (consumes JSON) | Response | 파일:라인 |
|--------|------|------|------------------------|----------|-----------|
| `handleNotification` | POST | `/webhooks/apple/server-notifications` | Body `AppleServerNotificationEvent { @JsonProperty("payload") String payload }` — `payload`는 Apple이 서명한 JWT(JWS) | `200 OK` 성공 / `400 Bad Request` payload 결손 or JWT 파싱 실패 / `500 Internal Server Error` 그 외 | `AppleNotificationController.java:41-75` |

- 흐름:
  1. `payload` null/empty → `400`.
  2. `appleEventTokenParser.parse(payload)` → `AppleEventPayload(type, sub, email, isPrivateEmail, eventTime)`.
     - 내부: `SignedJWT.parse` → `RemoteJWKSet(jwkUrl)`로 서명 검증. `issuer` 및 `audience`(=clientId) 검증. 만료(`exp`) 검증. `events` claim(문자열 or Map) → `AppleEventPayload` 빌드. 실패 시 `IdTokenParsingException` (`AppleEventTokenParser.java:47-88`).
  3. `handleEventByType(payload)` — switch(`type`)
     - `"email-disabled"` → info log + TODO
     - `"email-enabled"` → info log + TODO
     - `"consent-revoked"` → warn log + TODO
     - `"account-deleted"` → warn log + TODO
     - default → warn log
  4. 예외: `IdTokenParsingException` → 400, 그 외 `Exception` → 500 (spec: Apple에서 4xx 반환 시 재시도).
- 관측: **실제 비즈니스 로직은 TODO**. 현재는 로그만 남긴다.
- 특이: Apple 공식 이벤트 타입은 `email-disabled`, `email-enabled`, `consent-revoked`, `account-delete`(Apple 문서). 컨트롤러는 `account-deleted` (과거형)로 매칭 — 문서(`AppleNotificationController.java:17-26`)는 `account-delete`로 기술됨. 둘 중 무엇이 실제 오는지는 관측 데이터 없음.

---

### 4.11 `ErrorCodeController` — i18n 에러 코드 목록

- 파일: `src/main/java/kr/wadiz/oauth2/adapters/inbound/ErrorCodeController.java:18`
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`.
- 의존성: `MessageSource`.

| 메서드 | HTTP | 경로 | Request | Response | 파일:라인 |
|--------|------|------|---------|----------|-----------|
| `errorCodes` | GET | `/api/v1/error-codes` | `?language=ko` (default `ko`) | `ResponseEntity<Object>` = `TreeMap<String, String>` — key=ErrorCode name, value=localized message | `ErrorCodeController.java:22-29` |

- 흐름: `ErrorCode.values()`를 순회하며 `messageSource.getMessage(c.key(), [], new Locale(language, ""))` 로 번역문 획득. `TreeMap`이라 알파벳 정렬.
- 용도: 프런트엔드가 백엔드의 에러 코드 목록을 가져와 i18n 번역 매핑을 캐싱. `ErrorCode` enum에는 40여 개 에러 코드가 정의됨(`ErrorCode.java:3-40`).

---

### 4.12 `KakaoOAuth2AuthorizationRequestRegisterController` — 카카오 SDK용 Authorization Request 수동 등록

- 파일: `src/main/java/kr/wadiz/oauth2/application/authentication/social/kakao/KakaoOAuth2AuthorizationRequestRegisterController.kt:22`
- 패키지가 `application.authentication.social.kakao`에 위치하지만 클래스는 `@RestController`로 inbound에 해당한다.
- 클래스 선언: `@RestController @RequestMapping("/api/v1")`, `@Tag(name = "카카오 AuthorizationRequest 등록 Controller")`.
- 의존성 (생성자 주입):
  - `ClientRegistrationRepository clientRegistrationRepository`
  - `AbstractRememberMeServices abstractRememberMeServices`
- 초기화(`init` 블록):
  - `kakaoAuthorizationRequestRegisterResolver = WadizOAuth2AuthorizationRequestResolver(clientRegistrationRepository, "/api/v1/authorization-register/", abstractRememberMeServices)`
    - **주의**: `SecurityConfig` 내 `authorizationRequestResolver`는 baseUri `/oauth2/authorize`이지만, 이 컨트롤러는 `/api/v1/authorization-register/`로 baseUri를 달리 설정(`KakaoOAuth2AuthorizationRequestRegisterController.kt:31-36`).
  - `authorizationRequestRepository = HttpSessionOAuth2AuthorizationRequestRepository()`

| 메서드 | HTTP | 경로 | Request | Response | 파일:라인 |
|--------|------|------|---------|----------|-----------|
| `kakaoAuthorizationRequest` | GET | `/api/v1/authorization-register/kakao` | — | `KakaoAuthorizationRequest(state, clientId, responseType, redirectUri, serviceTerms)` | `KakaoOAuth2AuthorizationRequestRegisterController.kt:40-54` |

- 흐름:
  1. `kakaoAuthorizationRequestRegisterResolver.resolve(request)` → `OAuth2AuthorizationRequest` 생성 (`WadizOAuth2AuthorizationRequestResolver.resolve`가 kakao면 `service_terms=funding_membership,funding_use,funding_privacy,funding_marketing,user_age_check` 파라미터 추가, `WadizOAuth2AuthorizationRequestResolver.java:37-44`).
  2. `authorizationRequestRepository.saveAuthorizationRequest(oauth2AuthorizationRequest, request, response)` → HttpSession에 저장(Spring Security 표준 리다이렉트 플로우와 동일한 키로 저장됨, Kakao 콜백 시 `HttpSessionOAuth2AuthorizationRequestRepository`가 꺼내 검증).
  3. 응답 본문: `KakaoAuthorizationRequest(state, clientId, responseType=Code.value, redirectUri, serviceTerms=KAKAO_SERVICE_TERMS_VALUE)`. (`KakaoAuthorizationRequest.kt:3-9`)
- 용도: **카카오 JavaScript/Native SDK**가 OAuth2 URL을 자체적으로 조립해야 할 때, 서버가 미리 state/clientId/redirectUri/serviceTerms를 생성해 내려주면 SDK는 그 값으로 카카오 로그인 팝업을 띄운다. 콜백은 Spring OAuth2 Client 표준 플로우(`/oauth2/callback/kakao`)로 되돌아온다.
- 특이:
  - `serviceTerms` 상수는 `WadizOAuth2AuthorizationRequestResolver.KAKAO_SERVICE_TERMS_VALUE`를 공개(`public const`)해 공유.
  - `OAuth2AuthorizationRequest.authorizationRequestUri`에 serviceTerms가 이미 들어가지만, 파싱 불편 때문에 별도 필드로 내려준다는 주석 존재(`KakaoOAuth2AuthorizationRequestRegisterController.kt:51`).
  - 같은 `OAuth2AuthorizationRequest` 객체를 `HttpSessionOAuth2AuthorizationRequestRepository`에 저장하지만, 실제 redirectUrl로의 리다이렉트는 클라이언트가 수행한다.

---

## 5. AuthenticationCode V1 vs V2

두 컨트롤러는 **동일한 UseCase 두 개(`SendAuthenticationCodeViaEmailUsecase`, `CheckAuthenticationCodeValidityUsecase`)를 호출**하며, 내부 로직은 완전히 같다.

| 항목                     | V1                                            | V2                                            |
|--------------------------|-----------------------------------------------|-----------------------------------------------|
| 파일                     | `AuthenticationCodeV1Controller.java`         | `AuthenticationCodeV2Controller.java`         |
| Base path                | `/api/v1`                                     | `/api/v2`                                     |
| POST 성공 status         | **200 OK** (메서드 반환 `void` → Spring 기본) | **204 No Content** (`ResponseEntity.noContent()`) |
| GET `/valid` 성공 status | **200 OK**                                    | **204 No Content**                            |
| 예외                     | 실패 시 `InvalidAuthenticationCodeException`  | 동일                                          |
| Swagger `@ApiResponse`   | `200 description="이메일 코드 발송 성공"` / `200 description="코드 확인 ok"` / `404` | `204 description="이메일 코드 발송 성공"` / `204 description="코드 확인 ok"` / `404` |
| 구현 차이                | 없음                                          | 없음 (response status만 REST 규약에 맞춰 204로 변경) |

- V1은 POST/POST successful에서 본문 없음에도 200으로 응답했던 초기 구현. V2는 **Body 없음 = 204**라는 HTTP 관례에 맞춘 재발행이다. UseCase 변경 없음.
- 두 컨트롤러 모두 **동일 HttpSession id를 키로 Redis에 코드 저장**하므로, 같은 브라우저에서 V1·V2 어느 쪽으로 발송해도 다른 쪽으로 검증 가능.
- V1을 deprecated로 표시하는 어노테이션은 없지만, 신규 클라이언트는 V2를 쓰도록 경로 분리된 것으로 관측됨(Swagger/`api/v1` · `api/v2` 두 개가 공존).

---

## 6. Apple Notification (Apple Sign-In S2S 웹훅)

§4.10과 중복되는 부분은 요약.

### 엔드포인트

- `POST /webhooks/apple/server-notifications` — Apple이 **서명된 JWT(JWS)** 를 payload로 감싸 전송.

### 요청 포맷

```json
{ "payload": "<compact JWS string>" }
```

Apple 서버가 이 한 필드만 보낸다. 실제 이벤트 데이터는 JWS 내부 claims에 있다 (`AppleServerNotificationEvent.java:10-27`).

### JWS 검증 (`AppleEventTokenParser.java:47-88`)

1. `SignedJWT.parse(payload)` → header 포함 파싱.
2. `JWSVerificationKeySelector(algorithm, RemoteJWKSet(jwkUrl))` — Apple JWK(`https://appleid.apple.com/auth/keys`)로 서명 검증.
3. `exp` claim 존재 및 미만료 검증.
4. `iss` claim == 주입된 `issuer` 검증.
5. `aud` claim contains `clientId` 검증.
6. `events` claim(JSON string or Map) 파싱 → `type`, `sub`, `email`, `is_private_email`, `event_time` 추출.

### 이벤트 처리 (`AppleNotificationController.java:81-108`)

| `events.type`       | 의미                                        | 현 구현 | TODO                                |
|---------------------|---------------------------------------------|---------|-------------------------------------|
| `email-disabled`    | 사용자가 Apple ID로 이메일 수신 중단        | info log | 이메일 수신 거부 처리               |
| `email-enabled`     | 사용자가 Apple ID로 이메일 수신 활성화      | info log | 이메일 수신 활성화 처리             |
| `consent-revoked`   | 사용자가 앱의 Apple ID 사용 중단            | warn log | 사용자 계정 연동 해제 처리          |
| `account-deleted`   | 사용자가 Apple ID 삭제                      | warn log | 사용자 계정 삭제 처리               |
| (기타)              | 알 수 없는 타입                             | warn log | —                                   |

### 응답

- 성공: `200 OK` (Apple은 2xx를 기대).
- payload 비어있음 or JWT 파싱/검증 실패: `400 Bad Request`.
- 그 외: `500 Internal Server Error`.

### 보안

- `/webhooks/**` 경로가 `permitAll`이므로 누구나 호출 가능하다. 서명 검증이 사실상의 인증이다(Apple의 개인키로 서명된 JWT만 검증 통과).
- `issuer`, `audience` 값은 Spring 설정에서 주입 — `AppleEventTokenParser` 생성 시점에 결정된다(`application/authentication/social/AppleEventTokenParser.java:34-38`). 구체적 Bean 등록 위치는 본 문서 범위를 벗어난다.

---

## 7. 엔드포인트 일람 (본 문서 범위)

| # | Method | Path | Controller.method | Auth | 파일:라인 |
|---|--------|------|-------------------|------|-----------|
| 1 | GET | `/` | `MainController.index` | public | `MainController.java:44` |
| 2 | GET | `/login` | `MainController.login` | public | `MainController.java:53` |
| 3 | GET | `/signup` | `MainController.signup` | public | `MainController.java:112` |
| 4 | GET | `/social-signup` | `MainController.socialSignup` | public | `MainController.java:143` |
| 5 | GET | `/social-link` | `MainController.linkUser` | public | `MainController.java:165` |
| 6 | GET | `/reset-password/{token}`, `/find-password`, `/find-id` | `MainController.resetPassword` | public | `MainController.java:181` |
| 7 | GET | `/v0/oauth2/callback` | `CallbackController.callback` | public | `CallbackController.java:42` |
| 8 | GET | `/test_page` | `CallbackController.testPage` | public | `CallbackController.java:138` |
| 9 | POST | `/api/v1/cookie/validity` | `SessionController.isCookieValid` | `x-api-key` | `SessionController.kt:29` |
| 10 | DELETE | `/api/v1/users/{userId}/sessions` | `SessionController.removeAllSessions(apiKey)` | `x-api-key` | `SessionController.kt:46` |
| 11 | DELETE | `/api/v1/sessions` | `SessionController.removeAllSessions(jwt)` | Bearer JWT | `SessionController.kt:62` |
| 12 | GET | `/api/v1/user-login-status` | `SessionController.currentStatus` | public | `SessionController.kt:71` |
| 13 | POST | `/api/v1/users` | `SignUpController.signUpWithEmail` | public (SavedRequest client_id 필요) | `SignUpController.java:79` |
| 14 | POST | `/api/v1/social-users` | `SignUpController.signUpWithSocialAccount` | public (SavedRequest client_id + 세션 SocialAccount 필요) | `SignUpController.java:111` |
| 15 | GET | `/api/v1/signup-information` | `SignUpController.getSignUpStatus` | public | `SignUpController.java:151` |
| 16 | POST | `/api/v1/find-id` | `IdPasswordManagementController.findUserByUsername` | public | `IdPasswordManagementController.kt:34` |
| 17 | POST | `/api/v1/password-reset/request` | `IdPasswordManagementController.sendPasswordResetMail` | public | `IdPasswordManagementController.kt:44` |
| 18 | POST | `/api/v1/password-reset/confirm` | `IdPasswordManagementController.resetPassword` | public (토큰 검증) | `IdPasswordManagementController.kt:58` |
| 19 | POST | `/api/v1/link-users` | `LinkController.linkUserToSocialAccount` | public (세션 SocialAccount + 이메일/비번) | `LinkController.java:55` |
| 20 | POST | `/api/v1/authentication-code` | `AuthenticationCodeV1Controller.authenticate` (200) | public | `AuthenticationCodeV1Controller.java:30` |
| 21 | GET | `/api/v1/authentication-code/{code}/valid` | `AuthenticationCodeV1Controller.isValid` (200) | public | `AuthenticationCodeV1Controller.java:41` |
| 22 | POST | `/api/v2/authentication-code` | `AuthenticationCodeV2Controller.authenticate` (204) | public | `AuthenticationCodeV2Controller.java:30` |
| 23 | GET | `/api/v2/authentication-code/{code}/valid` | `AuthenticationCodeV2Controller.isValid` (204) | public | `AuthenticationCodeV2Controller.java:43` |
| 24 | POST | `/webhooks/apple/server-notifications` | `AppleNotificationController.handleNotification` | 공개 경로 + JWS 검증 | `AppleNotificationController.java:41` |
| 25 | GET | `/api/v1/error-codes` | `ErrorCodeController.errorCodes` | public | `ErrorCodeController.java:22` |
| 26 | GET | `info` (`/info`) | `MaintenanceController.configuration` | public | `MaintenanceController.java:28` |
| 27 | GET | `info/{fileName}` (`/info/{fileName}`) | `MaintenanceController.releaseNote` | public | `MaintenanceController.java:45` |
| 28 | GET | `/api/v1/authorization-register/kakao` | `KakaoOAuth2AuthorizationRequestRegisterController.kakaoAuthorizationRequest` | public | `KakaoOAuth2AuthorizationRequestRegisterController.kt:40` |

> 위 28개 엔드포인트가 본 문서의 분석 대상. Spring Authorization Server / Security 필터가 제공하는 경로(§2 표)는 별도.

---

## 8. 공통 DTO/Exception 참조

### DTO 인벤토리

| DTO | 필드 | 사용처 | 파일:라인 |
|-----|------|--------|-----------|
| `EmailSignUpDto` | email(@Email @NotBlank), nickname(trim), password(@Password), agreedTerms(@NotNull), language="ko", country="KR" | `POST /api/v1/users` | `adapters/inbound/dto/EmailSignUpDto.java:17` |
| `SocialSignUpDto` | email(@Email @NotBlank), nickname, language="ko", country="KR", agreedTerms | `POST /api/v1/social-users` | `adapters/inbound/dto/SocialSignUpDto.java:15` |
| `LinkSocialAccountDto` | username(@Email @NotBlank), password | `POST /api/v1/link-users` | `adapters/inbound/dto/LinkSocialAccountDto.java:15` |
| `SignUpSuccessDto` | signupRedirectUri | `201` 응답 body | `adapters/inbound/SignUpSuccessDto.java:8` |
| `LinkSuccessDto` | linkRedirectUri | `201` 응답 body | `adapters/inbound/LinkSuccessDto.java:8` |
| `AppleEventPayload` | type, sub, email, isPrivateEmail, eventTime | 내부 변환 | `adapters/inbound/dto/AppleEventPayload.java:15` |
| `AppleServerNotificationEvent` | payload(JWT) | 웹훅 요청 바디 | `adapters/inbound/dto/AppleServerNotificationEvent.java:20` |
| `CookieHolder` | cookie | `POST /api/v1/cookie/validity` 바디 | `SessionController.kt:82` |
| `CookieValidity` | validity, description | `POST /api/v1/cookie/validity` 응답 | `adapters/inbound/CookieValidity.kt:3` |
| `UserLoginStatus` | isLoggedIn, description | `GET /api/v1/user-login-status` 응답 | `adapters/inbound/UserLoginStatus.kt:3` |
| `EmailInfo` | email(@NotBlank) | `/find-id`, `/password-reset/request` 바디 | `IdPasswordManagementController.kt:65` |
| `ResetPasswordDto` | token(@NotBlank), newPassword(@NotBlank @Password) | `/password-reset/confirm` 바디 | `IdPasswordManagementController.kt:70` |
| `KakaoAuthorizationRequest` | state, redirectUri, clientId, responseType, serviceTerms | `/api/v1/authorization-register/kakao` 응답 | `application/authentication/social/kakao/KakaoAuthorizationRequest.kt:3` |
| `ApplicationInfo` | version, notes | 미사용(정의만 존재) | `adapters/inbound/ApplicationInfo.kt:3` |
| `SendCodeCommand` | email | `/authentication-code` 바디(V1, V2 공용) | `domain/applicationservice/dto/SendCodeCommand` |
| `SignUpInformation` | joinType, providerType, social{userName, nickName, existUserName}, fromTheLoginPage | `GET /api/v1/signup-information` 응답 | `common/SignUpInformation.java:12` |
| `UsernameStatus` | username, status(`EMAIL_LOGIN_OK / SNS_LOGIN_OK / DROPOUT_HISTORY_EXISTS / NOT_REGISTERED`) | `/find-id` 응답 | `port/inbound/FindIdUsecase.kt:7` |

### Validator

- `@Password` (`adapters/inbound/validator/Password.java:12`) + `PasswordValidator` (`adapters/inbound/validator/PasswordValidator.java:12-60`):
  1. 공백 포함 금지
  2. 8자 이상
  3. 숫자 1자 이상 (`[0-9]`)
  4. 특수문자 1자 이상 (`[!@#$%^&*+=-]`)
  5. 영문자 1자 이상 (`[a-zA-Z]`)
  - 실패 시 validator 내부에서 log.warn (검증 단계의 평문 password를 warn 레벨로 **로그에 노출**하는 점 관찰됨).

### Exception 인벤토리

| Exception | HTTP | ErrorCode | 파일 |
|-----------|------|-----------|------|
| `InvalidApiKeyException` | 403 | `INVALID_API_KEY` | `exception/InvalidApiKeyException.java:10` |
| `SocialLoginRequiredException` | 400 | `SOCIAL_LOGIN_REQUIRED` | `exception/SocialLoginRequiredException.java:7` |
| `EmailNotAuthenticatedException` | 400 | `EMAIL_NOT_AUTHENTICATED` | `exception/EmailNotAuthenticatedException.java:10` |
| `EmailNotMatchedException` | 400 | `EMAIL_NOT_MATCH` | `exception/EmailNotMatchedException.java:7` |
| `ClientIdNotFoundException` | 412 | `CLIENT_ID_NOT_FOUND` | `exception/ClientIdNotFoundException.java:7` |
| `SignUpCompleteUriNotRegisteredException` | 412 | `SIGNUP_COMPLETE_URL_NOT_REGISTERED` | `exception/SignUpCompleteUriNotRegisteredException.java:7` |
| `LinkCompleteUriNotRegisteredException` | 412 | `LINK_COMPLETE_URL_NOT_REGISTERED` | `exception/LinkCompleteUriNotRegisteredException.java:7` |
| `RequiredTermsNotAcceptedException` | (확인 필요) | `TERMS_NOT_AGREED` | `exception/RequiredTermsNotAcceptedException.java` |
| `EmailNotFoundException` | — | `EMAIL_NOT_FOUND` | `exception/EmailNotFoundException.java` |
| `SamePasswordException` | — | `SAME_AS_PREVIOUS_PASSWORD` | `exception/SamePasswordException.java` |
| `InvalidResetLinkException` | — | `INVALID_RESET_LINK` | `exception/InvalidResetLinkException.java` |
| `InvalidAuthenticationCodeException` (domain) | 404 추정 | `INVALID_AUTHENTICATION_CODE` | `domain/exception/InvalidAuthenticationCodeException.java` |

- 모두 `WadizException` 또는 그 파생 (`common.exception.WadizException` → `IWadizErrorCodeException` 구현). `GlobalExceptionHandler.handleIWadizErrorCodeException`이 `ProblemDetail` + `errorCode` 프로퍼티로 일관된 JSON 응답 포맷을 적용.

### Mapper 인벤토리 (MapStruct, componentModel="spring")

| Mapper | 변환 | 특이 | 파일:라인 |
|--------|------|------|-----------|
| `EmailSignUpDtoToCommandMapper` | `EmailSignUpDto + Locale` → `EmailSignUpCommand` | `nickname` 비어있으면 email + locale로 기본 닉네임 생성(`processNicknameWithEmail`) | `mapper/EmailSignUpDtoToCommandMapper.java:12` |
| `SocialSignUpDtoToCommandMapper` | `SocialSignUpDto + Locale` → `SocialSignUpCommand` | `socialAccount` ignore, `nickname` 동일 규칙 | `mapper/SocialSignUpDtoToCommandMapper.java:12` |
| `LinkUserToSocialAccountCommandMapper` | `LinkSocialAccountDto` → `LinkUserToSocialAccountCommand` | `socialAccount` ignore | `mapper/LinkUserToSocialAccountCommandMapper.java:8` |
| `TermsRequestMapper` | `List<Terms>` → `List<Service>` | 약관 → 와디즈 서비스 enum 매핑 | `mapper/TermsRequestMapper.java` |
| `NicknameMapper` | 공통 default 메서드 — `processNicknameWithEmail(nickname, email, locale)` | Mapper 인터페이스 상속으로 재사용 | `mapper/NicknameMapper.java` |

---

## 9. 경계 및 미탐색 영역

1. **UseCase 구현체 내부 로직**: 모든 REST 컨트롤러는 `FindIdUsecase`, `ResetPasswordUsecase`, `SendResetPasswordMailUsecase`, `SendAuthenticationCodeViaEmailUsecase`, `CheckAuthenticationCodeValidityUsecase`, `GetSignUpInformationUsecase` 등 포트 인터페이스를 호출한다. 구현체(`domain.applicationservice` 패키지 + `adapters.outbound.*` 어댑터)는 **본 문서의 관측 범위를 벗어난다**. 실제 DB SQL/Redis 키/외부 API 호출은 overview 문서(`docs/kr.wadiz.account/kr.wadiz.account.md`) §4 주요 API 상세에 요약돼 있으니 그쪽 참고.
2. **`CreateUserApplicationService`, `CreateUserWithSocialAccountApplicationService`, `LinkUserToSocialUserApplicationService`**: `SignUpController` / `LinkController`가 직접 호출하지만 이들은 `@Service` 수준의 application service로 본 문서에서는 시그니처 호출까지만 관측.
3. **Spring Security 내부 필터 체인**: `/oauth/loginPerform`(formLogin), `/oauth/logout`, `/oauth2/authorize/*`, `/oauth2/callback/*`의 실제 처리 로직은 Spring Security/Authorization Server의 필터가 담당. 컨트롤러 매핑 없음. 성공/실패 핸들러만 Wadiz가 구현 — `EmailAuthenticationSuccessHandler`, `SocialAuthenticationSuccessHandler`, `AuthorizationAuthenticationSuccessHandler`, `RememberMeAuthenticationSuccessHandler`, `WadizAuthenticationFailureHandler` (구현체 분석 별도).
4. **OAuth2 Authorization Server 내부 상태 머신**: `/oauth/authorize` / `/oauth/token` / `/oauth/revoke` / `/oauth/check_token`의 정확한 흐름은 Spring Authorization Server 1.2.6의 책임이다. Wadiz 커스텀 요소는 `application/customgrant/OAuth2CustomWadizAuthenticationConverter.java` + `OAuth2CustomWadizAuthenticationProvider.java` (password grant 대체)와 `OAuth2CustomWadizAuthenticationToken.java`에 한정 — 이 역시 본 문서 범위 밖.
5. **`CurrentDevice` 커스텀 어노테이션**: `SignUpController.signUpWithEmail`·`signUpWithSocialAccount`·`getSignUpStatus`에서 `@CurrentDevice DeviceType`로 User-Agent 기반 디바이스 분류가 주입된다 — 관련 argument resolver 구현체는 `application/config/CurrentDevice*`에 있지만 본 문서 범위 밖.
6. **Beusable 체크의 정확한 효과**: `MainController`의 `isBeusableBot`는 "헤더 `beusable: true` 이면 로그인/가입 사전 검증을 생략하고 뷰를 그대로 렌더한다"는 것 외에, Beusable의 크롤러가 인증된 페이지를 스크린샷 찍을 수 있도록 우회하는 장치로 보인다. 실제 Beusable 설정·User-Agent 매칭은 이 레포 바깥.
7. **`MaintenanceController.releaseNote` path traversal**: `Paths.get(fileName + ".txt")`가 사용자 입력에 대한 정제 없이 파일 시스템에 접근. 운영 관점에서 리스크 체크 필요 — 본 문서는 관측만 기록, 수정은 별건.
8. **`CallbackController`의 운영 노출**: `/v0/oauth2/callback`이 `permitAll`이며 `RestTemplate`이 모든 TLS 인증서를 신뢰, 하드코딩 client_secret을 포함한다. 과거 디버그 도구지만 현재 라이브 프로파일에서도 활성화됨. 삭제/가드 여부 확인은 본 문서 범위 밖.
9. **세션 정리 세부**: `SessionController.removeAllSessions`가 호출하는 `SessionCleanerService.removeAllSessionsAndTokens(userId)`의 구체 구현(Redis 키 스캔/DB UPDATE)은 `application/authentication/SessionCleanerService` 또는 인프라 어댑터에 있음.
10. **`AuthenticationCodeV1/V2Controller`의 Swagger Tag 이름 중복**: 두 컨트롤러가 동일 `@Tag(name="이메일 확인 Controller")`를 가져 Swagger UI에서 한 그룹으로 묶일 가능성. 실제 Swagger 결과 확인은 본 문서 범위 밖.
11. **`KakaoOAuth2AuthorizationRequestRegisterController`의 대응 콜백**: 이 컨트롤러는 AuthorizationRequest를 저장만 하고, 카카오 SDK가 결과 code를 들고 오는 콜백은 SecurityConfig의 `oauth2Login.redirectionEndpoint.baseUri("/oauth2/callback/*")`가 처리. baseUri `/api/v1/authorization-register/`는 **resolve 전용**이다.
12. **RememberMe 쿠키 포맷**: `SessionController.isCookieValid`가 받는 `CookieHolder(cookie: String)`는 RememberMe 쿠키 문자열(base64 인코딩된 username/expiry/token 등). 포맷 검증 세부는 `WadizPersistentTokenBasedRememberMeServices.checkCookieValidity` 구현체 참고.
13. **`servletPort.login(authentication, boolean)`의 두 번째 인자 의미**: `LinkController`가 `true`를 전달. `ServletPort` 인터페이스와 구현체(`adapters.outbound.internalservice.ServletAdapter` 추정)의 시그니처/동작은 본 문서 범위 밖.

---

## 10. 보조 컴포넌트 참조 표

### 10.1 `@CurrentDevice` + `DeviceTypeResolver`

- 애노테이션: `application/config/CurrentDevice.java:10` — `@Target(PARAMETER) @Retention(RUNTIME) @interface CurrentDevice {}`
- 리졸버: `application/config/DeviceTypeResolver.java`가 `HandlerMethodArgumentResolver`를 구현해 `User-Agent` 헤더를 `UserAgentUtils` 라이브러리로 파싱 → `DeviceType` enum 반환.
- 사용처: `SignUpController.signUpWithEmail`, `SignUpController.signUpWithSocialAccount`, `SignUpController.getSignUpStatus`.
- `DeviceType` enum은 `common/DeviceType.java`에 정의.

### 10.2 `NicknameMapper.processNicknameWithEmail`

- 파일: `adapters/inbound/mapper/NicknameMapper.java:18-20`
- MapStruct `default` 메서드가 `NicknameUtil.processNicknameWithEmail(nickname, email, locale)` 위임.
- 용도: null/blank nickname → 이메일 로컬파트 기반 기본 닉네임 생성(locale별 랜덤 suffix 가능성, 정확한 규칙은 `common/utils/NicknameUtil` 참고).

### 10.3 `SavedRequest` 사용 패턴

`/oauth/authorize?client_id=X&response_type=code&redirect_uri=...`에 비인증 상태로 접근하면 `LoginUrlAuthenticationEntryPoint`가 원 요청을 `HttpSessionRequestCache`에 저장하고 `/login`으로 리다이렉트한다. 이후 로그인/가입 플로우가 이 `SavedRequest`에서 `client_id`를 꺼내 다음과 같이 활용한다:

| 위치 | 사용 목적 |
|------|-----------|
| `MainController.clientIdFromSavedRequest` (`MainController.java:208-220`) | `/login`/`/signup`/`/social-signup`/`/social-link` 뷰 진입 조건 검사. client_id 없으면 본 사이트로 축출. |
| `MainController.extractEmailFromSavedRequest` (`MainController.java:229-241`) | `/oauth/authorize?email=...`에서 email 프리필. |
| `SignUpController.getSignUpCompleteUri` (`SignUpController.java:170-187`) | 가입 완료 후 리다이렉트할 URL을 `RegisteredClient.clientSettings`에서 조회. |
| `LinkController.getClientIdFromRequestCache` (`LinkController.java:114-122`) | 동일. `clientId`/`client_id` 두 표기 모두 시도. |

### 10.4 내부/외부 인증 분리 요약

| 엔드포인트 분류 | 인증 수단 | 권한 |
|----------------|-----------|------|
| MainController 뷰 | 세션(authenticated) 여부만 검사, 실제로는 permitAll | — |
| SignUp/Link REST | SavedRequest `client_id` 필수, 세션에 `SocialAccount` 있으면 활용 | — |
| AuthenticationCode V1/V2 | 세션 id 기반 Redis 키 | 공개 |
| FindId/PasswordReset | 공개 | 토큰 검증 |
| SessionController `/cookie/validity`, `/users/{userId}/sessions` | `x-api-key` (Jasypt 암호화 설정) | 내부 서비스 전용 |
| SessionController `/sessions` | Bearer JWT | 사용자 self-logout |
| SessionController `/user-login-status` | 없음 (세션/쿠키 스니핑) | 공개 |
| Apple 웹훅 | JWS 서명 검증 | 공개 경로 |
| KakaoAuthorizationRegister | 없음 | 공개 |
| Callback/Maintenance/ErrorCode | 없음 | 공개 |

### 10.5 UseCase 포트 인벤토리 (inbound)

| 포트 인터페이스 | 시그니처 | 파일 | 호출 컨트롤러 |
|----------------|----------|------|---------------|
| `SendAuthenticationCodeViaEmailUsecase` | `void sendAuthenticationCode(String sessionId, String email, Locale locale)` | `port/inbound/SendAuthenticationCodeViaEmailUsecase.java:5` | V1/V2 AuthenticationCode |
| `CheckAuthenticationCodeValidityUsecase` | `boolean isValid(String sessionId, String code)` | `port/inbound/CheckAuthenticationCodeValidityUsecase.java:3` | V1/V2 AuthenticationCode |
| `FindIdUsecase` | `fun findUsername(userName: String): UsernameStatus` | `port/inbound/FindIdUsecase.kt:3` | IdPasswordManagement |
| `ResetPasswordUsecase` | `fun resetPassword(token: String, password: String)` | `port/inbound/ResetPasswordUsecase.kt:7` | IdPasswordManagement |
| `SendResetPasswordMailUsecase` | `fun sendResetPasswordMail(username: String, locale: Locale)` | `port/inbound/SendResetPasswordMailUsecase.kt:5` | IdPasswordManagement |
| `GetSignUpInformationUsecase` | `SignUpInformation getSignUpInformation(Locale locale)` | `port/inbound/GetSignUpInformationUsecase.java:7` | SignUp |
| `CreateUserUseCase` | (인터페이스) | `port/inbound/CreateUserUseCase.java` | SignUp (via `CreateUserApplicationService`) |
| `CreateUserWithSocialAccountUsecase` | (인터페이스) | `port/inbound/CreateUserWithSocialAccountUsecase.java` | SignUp (via `CreateUserWithSocialAccountApplicationService`) |
| `LinkSocialUserUseCase` | (인터페이스) | `port/inbound/LinkSocialUserUseCase.java` | Link (via `LinkUserToSocialUserApplicationService`) |

> `CreateUserUseCase` / `CreateUserWithSocialAccountUsecase` / `LinkSocialUserUseCase`는 컨트롤러가 직접 호출하지 않고, `@Service` 레벨 ApplicationService를 거친다. 구현체는 `domain/applicationservice/*ApplicationService.java`.

### 10.6 Command/Query DTO (port.inbound)

| DTO | 필드 | 파일 |
|-----|------|------|
| `EmailSignUpCommand` | email, nickname, password, agreedTerms | `port/inbound/EmailSignUpCommand.java:14` |
| `LinkUserToSocialAccountCommand` | UserId, socialAccount | `port/inbound/LinkUserToSocialAccountCommand.java:7` |
| `SocialSignUpCommand` (domain) | email, nickname, agreedTerms, socialAccount | `domain/applicationservice/dto/SocialSignUpCommand` |
| `SendCodeCommand` (domain) | email(@Email @NotBlank) | `domain/applicationservice/dto/SendCodeCommand` |

---

## 11. 요약

`kr.wadiz.account`의 inbound 계층은 **Spring Authorization Server가 제공하는 OAuth2/OIDC 표준 엔드포인트 11종**과 **Spring Security 필터가 제공하는 form/social 로그인 엔드포인트 4종** 위에 **Wadiz 커스텀 HTTP 엔드포인트 28개(12 컨트롤러, §4·§7)**를 얹어 구성된다. 커스텀 엔드포인트는 다음과 같은 축으로 나뉜다.

- **SPA 진입 (뷰 렌더링)**: `MainController` 6경로 → 모두 `login.html` 반환.
- **회원가입/연결 REST**: `SignUpController` 3, `LinkController` 1, `IdPasswordManagementController` 3, `AuthenticationCodeV1/V2Controller` 각 2.
- **세션 관리**: `SessionController` 4 (x-api-key 2, JWT 1, public 1).
- **외부 웹훅**: `AppleNotificationController` 1 (JWS 검증 기반 인증).
- **서비스 보조**: `ErrorCodeController` 1, `MaintenanceController` 2.
- **Kakao SDK 연동**: `KakaoOAuth2AuthorizationRequestRegisterController` 1.
- **디버그 도구**: `CallbackController` 2.

입력 검증은 Jakarta Validation + 커스텀 `@Password` (`PasswordValidator.java:22-60`)으로 일원화, 에러 응답은 `GlobalExceptionHandler`가 `ProblemDetail` + `errorCode` 필드로 표준화하며, i18n은 `MessageSource` + `ErrorCode` enum(`ErrorCode.java:3-77`) 기반으로 작동한다.

Kotlin 컨트롤러(`SessionController.kt`, `IdPasswordManagementController.kt`, `KakaoOAuth2AuthorizationRequestRegisterController.kt`) 3개와 Java 컨트롤러 9개가 공존한다. Kotlin 쪽은 `data class` + `@field:Validation` 스타일을 사용하고, Java 쪽은 Lombok `@Data` + 필드 어노테이션 스타일을 사용한다.

### 11.1 주의할 운영 리스크(관측 기반)

본 문서는 평가가 아니라 관측 기록이지만, 코드를 읽으며 마주친 리스크 포인트를 정리한다.

1. **`CallbackController`의 하드코딩된 `client_secret`** (`CallbackController.java:97-103`). 소스코드에 `live="dnrhd2Tks!"`, nonlive="secret" 이 평문으로 포함돼 있고, `permitAll` 경로에서 접근 가능하다. 디버그 의도로 추정되지만 라이브 환경에서도 활성화됨.
2. **`CallbackController`의 all-trust TrustStrategy** (`CallbackController.java:121-123`). 모든 TLS 인증서를 신뢰하는 `RestTemplate`. 자체 호출이라 MITM 위험은 낮지만 패턴 상 위험.
3. **`MaintenanceController.releaseNote`의 path traversal** (`MaintenanceController.java:46-51`). `Paths.get(fileName + ".txt")`가 상대 경로를 정제 없이 받아들여 `../../etc/passwd` 등 접근 가능. `permitAll`.
4. **`PasswordValidator`의 평문 password 로깅** (`PasswordValidator.java:56-58`). 검증 실패 시 `log.warn("... inputData: {} ...", password)` — 입력 패스워드가 WARN 로그에 노출될 수 있음.
5. **`@Tag` 중복** (`AuthenticationCodeV1Controller.java:19`, `AuthenticationCodeV2Controller.java:19`). 두 컨트롤러가 같은 Swagger Tag 이름을 써 UI에서 혼재 표시 가능.

### 11.2 본 문서의 커버리지

- 전수 분석: `adapters/inbound/*` 디렉터리의 `@Controller` / `@RestController` 12개 + `application/authentication/social/kakao/KakaoOAuth2AuthorizationRequestRegisterController.kt` 1개 = **13개 파일 × 28 엔드포인트**.
- DTO/Exception/Validator/Mapper 인벤토리는 `adapters/inbound/{dto,exception,mapper,validator}` 서브디렉터리를 모두 조회한 결과.
- `SecurityConfig.java` (`application/SecurityConfig.java`) 및 `UserSessionService.java` (`application/authentication/UserSessionService.java`), `WadizOAuth2AuthorizationRequestResolver.java` (`application/authentication/`), `AppleEventTokenParser.java` (`application/authentication/social/`) 는 컨트롤러를 이해하기 위한 맥락으로 참조.
- UseCase 구현체 내부 로직, JPA 엔티티, Redis 어댑터, Feign 외부 서비스는 본 문서 범위 밖 (overview `docs/kr.wadiz.account/kr.wadiz.account.md` 및 타 문서 참고).
