# `kr.wadiz.account` — OAuth2 인증/인가 코어 상세 분석

## 1. 기록 범위

- **루트**: `/Users/casvallee/work/repos/kr.wadiz.account`
- **대상 패키지**:
  - `src/main/java/kr/wadiz/oauth2/application/` (루트 설정 5종)
  - `src/main/java/kr/wadiz/oauth2/application/authentication/` (핸들러 · Resolver · Remember-me · 필터 · Social · Wadiz)
  - `src/main/java/kr/wadiz/oauth2/application/authentication/converter/` (소셜 → 계정 변환기 6종)
  - `src/main/java/kr/wadiz/oauth2/application/authentication/social/` (`WadizOAuth2UserService`, `WadizOidcUserService`, Apple, LINE 파서)
  - `src/main/java/kr/wadiz/oauth2/application/authentication/social/kakao/` (Kakao AuthorizationRequest 등록 Controller)
  - `src/main/java/kr/wadiz/oauth2/application/authentication/wadiz/` (`WadizUser`, `WadizAuthenticationProvider`, `WadizUserDetailService`, Jackson Mixin/Deserializer 6종)
  - `src/main/java/kr/wadiz/oauth2/application/customgrant/` (`wadiz_web` Grant 3파일)
  - `src/main/java/kr/wadiz/oauth2/application/config/filter/` (`WadizUsernamePasswordAuthenticationFilter` — deprecated)
  - `src/main/java/kr/wadiz/oauth2/application/aspect/` (`LoggingAspect`, `TransactionLogAspect`)
  - `src/main/java/kr/wadiz/oauth2/domain/authenticationcode/AuthenticationCodeService.java`
  - `src/main/java/kr/wadiz/oauth2/domain/service/Service.java`, `ServiceType.java`, `ServiceTypeManager.java` (모두 `@Deprecated`)
  - `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/iam/client/JpaRegisteredClientRepository.java` (Client 저장/로드 + custom grant resolve 지점)

- **미기록 대상**: 컨트롤러 (`adapters/inbound/...`), 회원/약관 도메인(`domain/user`, `domain/terms`) 내부 구현, 어드민/Signup/Link 로직, Kakao Port 전체 구현 (`adapters/outbound/externalservice/kakao`), Email Verification / JoinAuth, DB Datasource/JPA/Redis Config, 테스트 모듈. OAuth2 **인증·인가 코어** 관점에서 접촉 지점만 언급.

- **접근 방법**: 실제 파일 내용만 인용 (Spring Security OAuth2 Authorization Server `1.x` / Boot 3 위에 올라가 있는 소스). 문서 내 `path:line` 주석은 위 저장소 절대 경로에서 `src/main/...`부터 표기.

---

## 2. 개요

### 2.1 구성

- **Spring Boot 3 + Spring Security `oauth2-authorization-server` (Servlet, Jakarta) 기반의 IdP**. `AuthorizationServiceApplication`(`application/../AuthorizationServiceApplication.java:1-23`) 에서 `@EnableAsync`, `@EnableFeignClients`, `@EnableScheduling`, `@EnableJpaAuditing`, `@EnableEncryptableProperties`(Jasypt), `@EnableAspectJAutoProxy`, `@SpringBootApplication` 를 모두 켠다.
- **역할**: (1) 자체 IdP (Authorization Server + OIDC RP-initiated logout), (2) `oauth2Login()`을 통한 **소셜 로그인 통합 게이트웨이** (Kakao, Naver, Google, Facebook, Apple, LINE), (3) 자체 **Persistent Remember-me** 발급/검증, (4) 사내 전용 `wadiz_web` Custom Grant.
- **와디즈 확장 포인트**
  - 표준 Authorization Server endpoint 경로를 **와디즈 레거시 호환 경로**로 재정의 (`/oauth/authorize`, `/oauth/token`, `/oauth/check_token`, `/oauth/revoke`, `/oauth/token_key`) — `SecurityConfig.authorizationServerSettings()` (`application/SecurityConfig.java:268-278`).
  - TokenEndpoint에 **`wadiz_web` grant converter/provider를 주입** (`SecurityConfig.java:139-147`).
  - `oauth2Login`: social login 은 자체 엔드포인트 `/oauth2/authorize`, callback은 `/oauth2/callback/*` (`SecurityConfig.java:215-230`).
  - `OidcLogoutEndpoint`: ID Token이 없는 (DUMMY) 로그아웃 허용, 로그아웃 시 Remember-me 쿠키 같이 처리 (`SecurityConfig.java:118-137`, `WadizOidcLogoutAuthenticationConverter.kt`, `WadizOidcLogoutAuthenticationProvider.java`, `WadizOidcLogoutHandler.java`).
  - OIDC `OidcUserService` 는 LINE(`HS256`) 용 커스텀 디코딩 포함 (`WadizOidcUserService.java`, `LineIdTokenDecoder.java`).
  - Apple `client_secret`은 **주기적으로 JWT 재발급** 후 `CustomClientRegistrationRepository` 에 덮어쓰기 (`ProjectConfig.java`, `SchedulingService.changeAppleSecurityToken`).
  - Custom `AuthorizationRequestResolver`가 **Remember-me 파라미터를 세션에 저장**해 social 로그인 후에도 Remember-me가 이어지도록 함 (`WadizOAuth2AuthorizationRequestResolver`).
  - **Token Theft 대응**: `WadizPersistentTokenBasedRememberMeServices`에서 `CookieTheftException`을 Redis lock 기반으로 동시 리프레시 충돌을 방지하면서 처리.
  - Client 저장소(`JpaRegisteredClientRepository`)는 **alien grant 타입을 그대로 `new AuthorizationGrantType(...)` 으로 복원**하여 `wadiz_web`이 DB에 영속되도록 허용 (`JpaRegisteredClientRepository.java:143-152`).

### 2.2 사용자/토큰 모델 축약

| 개념 | 구현 | 설명 |
|---|---|---|
| `WadizUser` | `authentication/wadiz/WadizUser.java` | `spring-security-core` 의 `User`를 확장, `attributes` 맵 보유. |
| `UserDetailsService` | `authentication/wadiz/WadizUserDetailService.java` | 이메일 → `UserDTO` → `WadizUser(userId, password, ROLE_USER)`. 내부적으로 principal 이름은 `userId` 문자열. |
| `OAuth2User` (소셜) | Spring 기본 `DefaultOAuth2User` / `DefaultOidcUser` | `attributes`에 `wadizUser`(도메인 `User`)가 담겨 `SocialAuthenticationSuccessHandler`에서 사용. |
| Access/Refresh/ID Token | `SecurityConfig.tokenGenerator` (`:311-320`) | `JwtGenerator + JwtCustomizer`, `OAuth2AccessTokenGenerator`, `OAuth2RefreshTokenGenerator` 를 `DelegatingOAuth2TokenGenerator`로 묶음. RSA KeyStore `keystore/oauth-keystore.jks`, alias `oauth2.0`, password `oauth-pass`. |
| Remember-me | `authentication/WadizPersistentTokenBasedRememberMeServices.java` + `RememberMeConfig.java` | Cookie `WRMAT`, 파라미터 `rememberme`, 도메인 `wadiz.kr`, series 저장은 JDBC(`persistent_logins`), 동시성 락은 Redis. |

---

## 3. `SecurityConfig` 분석

파일: `application/SecurityConfig.java`. 2개의 `SecurityFilterChain` Bean이 선언된다.

### 3.1 FilterChain `@Order(1)` — Authorization Server (`:104-163`)

```
OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http);  // :113
```
Spring Security 기본 Authorization Server 필터를 그대로 적용한 뒤 **Configurer DSL**로 아래 지점만 교체:

- `authorizationEndpoint.authorizationResponseHandler` = `AuthorizationAuthenticationSuccessHandler` (`:116`)
  - `/oauth/authorize` 응답 시 `code`, `state`와 함께 `login_by` 쿼리(`wadiz|kakao|google|...|rememberme`) 를 붙여 RP redirect (`AuthorizationAuthenticationSuccessHandler.java:33-45`).
- `oidc.logoutEndpoint` (`:118-138`)
  - `logoutResponseHandler` = `WadizOidcLogoutHandler(abstractRememberMeServices)` — 세션 로그아웃 + Remember-me logout + `post_logout_redirect_uri` 리다이렉트를 직접 수행 (`WadizOidcLogoutHandler.java:40-65`).
  - `logoutRequestConverter` = `WadizOidcLogoutAuthenticationConverter` — `id_token_hint`가 없으면 `"DUMMY"` 값으로 `OidcLogoutAuthenticationToken` 생성 (`WadizOidcLogoutAuthenticationConverter.kt:62-65`).
  - `authenticationProvider` = `WadizOidcLogoutAuthenticationProvider` — `DUMMY` 면 즉시 인증 통과, `INVALID_TOKEN: sid` 에러는 기존 `OidcLogoutAuthenticationProvider` 대신 `authorizationService`에서 idToken을 다시 찾아 인증 토큰을 재구성 (`WadizOidcLogoutAuthenticationProvider.java:54-84`).
- `tokenEndpoint` (`:139-147`)
  - `authenticationProvider` = `OAuth2CustomWadizAuthenticationProvider(authorizationService, tokenGenerator, userDetailsService)`.
  - `accessTokenRequestConverter` = `OAuth2CustomWadizAuthenticationConverter` — `grant_type=wadiz_web` 만 처리.
- `oauth2ResourceServer.jwt(Customizer.withDefaults())` (`:151-153`) — userinfo/OIDC client registration용 Bearer 검증.
- `exceptionHandling.authenticationEntryPoint` = `LoginUrlAuthenticationEntryPoint("/login")` (`:155-160`) — 비인증 시 로그인 페이지로 redirect.
- `cors` = `@Qualifier("corsConfigurationSource")` Bean 사용.

### 3.2 FilterChain `@Order(2)` — App Security (`:165-251`)

- `ExceptionHandlerFilter`를 `SecurityContextHolderAwareRequestFilter` 뒤에 삽입 (`:173`). `CookieTheftException`을 잡아 `/error`로 redirect (`filter/ExceptionHandlerFilter.java:18-20`).
- **Form login** (`:174-179`)
  - `loginPage("/login")`, `loginProcessingUrl("/oauth/loginPerform")`.
  - `failureHandler = WadizAuthenticationFailureHandler`, `successHandler = EmailAuthenticationSuccessHandler`.
  - 실제 Provider는 명시적 등록 없이 `UsernamePasswordAuthenticationToken`에 대응하는 `WadizAuthenticationProvider`(`@Component`, `authentication/wadiz/WadizAuthenticationProvider.java:20-95`) 가 ProviderManager에 자동 등록.
- **authorizeHttpRequests** (`:181-207`)
  - `permitAll`: `/v3/api-docs/**`, `/api/**`, `/h2-console/**`, `/.well-known/**`, `/static/favicon.ico`, `/login`, `/reset-password/*`, `/find-password`, `/find-id`, `/signup`, `/social-signup`, `/social-link`, `/oauth2/**`, `/error`, `/swagger-ui/**`, `/test/**`, `/info/**`, `/sockjs-node/**`, `/actuator/**`, `/webhooks/**` (Apple Server-to-Server notification).
  - CORS preflight `permitAll` (`:204`).
  - 그 외 `authenticated()`.
- `oauth2ResourceServer.jwt` 활성 (`:208-209`) — API resource 보호.
- `logout.logoutUrl("/oauth/logout")` (`:211-213`). (단, OIDC logout endpoint는 Authorization Server chain에서 처리되므로 이건 일반 세션 로그아웃 용도.)
- **oauth2Login** (`:215-230`)
  - `loginPage("/login")`
  - `authorizationEndpoint.baseUri("/oauth2/authorize")` + `authorizationRequestResolver = WadizOAuth2AuthorizationRequestResolver` (Kakao `service_terms`, LINE `bot_prompt` 파라미터 주입 + Remember-me 세션 저장).
  - `redirectionEndpoint.baseUri("/oauth2/callback/*")`.
  - `userInfoEndpoint.userService = WadizOAuth2UserService`, `.oidcUserService = WadizOidcUserService`.
  - `failureHandler = WadizAuthenticationFailureHandler`, `successHandler = SocialAuthenticationSuccessHandler`.
- `csrf.disable()`, `sessionFixation().migrateSession()` (`:233-237`).
- `headers.frameOptions.sameOrigin()` (`:239-243`).
- `rememberMe` 설정 (`:245-248`)
  - `rememberMeServices(abstractRememberMeServices)` (bean = `WadizPersistentTokenBasedRememberMeServices`).
  - `authenticationSuccessHandler(rememberMeAuthenticationSuccessHandler)`.

### 3.3 Authorization Server Endpoints 재매핑 (`:267-278`)

```java
AuthorizationServerSettings.builder()
  .authorizationEndpoint("/oauth/authorize")        // changed (default /oauth2/authorize)
  .tokenEndpoint("/oauth/token")                    // changed (default /oauth2/token)
  .tokenIntrospectionEndpoint("/oauth/check_token") // changed
  .tokenRevocationEndpoint("/oauth/revoke")         // changed
  .jwkSetEndpoint("/oauth/token_key")               // changed
  .oidcUserInfoEndpoint("/userinfo")                // same
  .oidcClientRegistrationEndpoint("/connect/register") // same
```
주석에 `changed`로 표시된 4+1개가 **와디즈가 기존 Spring Security OAuth(구버전) 호환을 위해 경로를 옮겨둔 것**. 참고: `oauth2Login`의 자체 소셜 엔드포인트(`/oauth2/authorize`, `/oauth2/callback/*`) 와 충돌을 피한다.

### 3.4 JWK 및 Token 생성 (`:280-325`)

- `JWKSource`는 **기동 시 한 번** `ClassPathResource("keystore/oauth-keystore.jks")` (password `oauth-pass`, alias `oauth2.0`) 로부터 RSA key pair 1개를 로드하고 `keyId`를 `${wadiz.jwkset.keyId}` 로 고정 (`generateJWKSet`, `:286-296`). `generateRsaKeyPairOld()` 는 참조되지 않는 런타임 생성 버전(fallback로 남아있음).
- `tokenGenerator(JWKSource)` 는 `JwtGenerator(NimbusJwtEncoder) → OAuth2AccessTokenGenerator → OAuth2RefreshTokenGenerator` 순서의 `DelegatingOAuth2TokenGenerator`.
  - `JwtCustomizer` (`jwtCustomizer()`, `:328-348`):
    - `ACCESS_TOKEN`: `scope` claim을 공백 구분 문자열로 덮어쓰고(`setScopeClaimFromArrayToString`, `:350-352`), Principal이 `OAuth2User` 또는 `WadizUser` 이면 `id` / `user_name` 두 claim 추가 (`setAccessTokenClaims`, `:377-380`).
    - `ID_TOKEN`: `nickname`, `picture`(선택), `email`, `email_verified` claim 추가 (`setIdTokenClaims`, `:363-375`).
- `jwtDecoder`는 `OAuth2AuthorizationServerConfiguration.jwtDecoder(jwkSource)` (`:322-325`).
- `jwtDecoderFactory`는 **LINE 전용 분기** — `registrationId == "line"` 이면 HS256 `LineIdTokenDecoder`, 그 외는 `JwtDecoders.fromIssuerLocation(...)` (`:413-430`).
- `sessionRegistry` = `SpringSessionBackedSessionRegistry` + `httpSessionEventPublisher` (`:392-405`).

### 3.5 Client 등록 (`RegisteredClientRepository`)

- **소셜 RP** (account 서버가 **RP로 붙는** Kakao/Naver/Google/Facebook/Apple/LINE): `application.yml` `spring.security.oauth2.client.registration.*`를 로드해 `CustomClientRegistrationRepository`(`application/CustomClientRegistrationRepository.java`) 에 주입. `ProjectConfig.clientRegistrationRepository` (`:40-48`) 에서 생성 직후 `apple` 항목은 `AppleOAuthService.generateClientSecret()` 로 **client_secret을 JWT로 재발행**해 덮어쓴다. 이 업데이트는 월 1회 `SchedulingService.changeAppleSecurityToken`(`SchedulingService.java:136-140`) 으로도 돌아간다.
- **와디즈 IdP 소속 Client (RP가 와디즈 앱들)**: `JpaRegisteredClientRepository`(`adapters/outbound/persistence/iam/client/JpaRegisteredClientRepository.java`) 가 DB `iam.Client` 테이블에서 load. grant type 문자열 → 객체 변환은 `resolveAuthorizationGrantType`(`:143-152`) — `authorization_code`, `client_credentials`, `refresh_token` 세 표준 외의 문자열은 `new AuthorizationGrantType(value)` 로 처리하므로 **`wadiz_web`이 DB에 등록돼 있어도 그대로 복원된다**. `ClientSettings`, `TokenSettings`는 JSON으로 저장되며 `settings.client.link-complete-uri`, `settings.client.signup-complete-uri` 같은 **와디즈 전용 키**를 `SocialAuthenticationSuccessHandler`, `WadizAuthenticationFailureHandler`에서 조회해 사용한다(`SocialAuthenticationSuccessHandler.java:119-125`, `WadizAuthenticationFailureHandler.java:141-151`).
- Client 설정 샘플은 `client_settings/clientsettiong_{local,rc,rc2,rc3}.json` (와디즈 커스텀 `settings.client.*` 키 예시).

---

## 4. Grant Type

### 4.1 표준 Grant

Spring Authorization Server 가 기본 제공. `OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http)` 로 활성화되며, DB에 저장된 Client의 `authorizationGrantTypes` 컬럼 값으로 노출 가능 여부가 결정된다.

- `authorization_code` — 기본. 응답은 `AuthorizationAuthenticationSuccessHandler`가 가로채서 `login_by` 를 덧붙인 redirect 수행.
- `refresh_token` — `RefreshTokenGenerator`가 `DelegatingOAuth2TokenGenerator`에 포함됨. Custom grant provider 도 Client가 `refresh_token`을 지원하면 같이 발급 (`OAuth2CustomWadizAuthenticationProvider.java:110-128`).
- `client_credentials` — 기본 제공. 본 코드에선 별도 커스터마이즈 없음.
- `password` — 표준 OAuth2 password grant를 사용하는 코드 경로는 존재하지 않음. `WadizAuthenticationProvider`(`UsernamePasswordAuthenticationToken` 기반) 는 **폼 로그인**(`/oauth/loginPerform`)에서만 쓰인다. password grant 자리를 `wadiz_web`이 대체.

> **주의**: `application/config/filter/WadizUsernamePasswordAuthenticationFilter.java`는 `@Deprecated`이며 `attemptAuthentication` 이 `return null` 로 비활성화되어 있다(`:19-21`). 어디서도 등록되지 않음.

### 4.2 커스텀 Grant: `wadiz_web` (session/trust → token 교환)

핵심 3파일: `application/customgrant/OAuth2CustomWadizAuthenticationConverter.java`, `...Provider.java`, `...Token.java`.

#### 4.2.1 Converter (`OAuth2CustomWadizAuthenticationConverter`, `:20-96`)

- `grant_type`이 `"wadiz_web"`이 아니면 **`null` 리턴 → 다음 converter에게 양보** (`:28-31`).
- **필수 파라미터**: `username`. 없으면 `OAuth2Error("invalid_request", "OAuth 2.0 Parameter: username", rfc6749#section-5.2)` (`:33-39`).
- **선택 파라미터**: `scope`. 다중 제출 시 `invalid_request` (`:46-53`).
- `SecurityContextHolder`의 `Authentication`을 `clientPrincipal`로 사용 (BasicAuth 기준 `OAuth2ClientAuthenticationToken`).
- `grant_type`, `scope` 외 나머지 파라미터를 `additionalParameters`로 수집 (`:61-67`).
- 결과: `OAuth2CustomWadizAuthenticationToken(clientPrincipal, requestedScopes, additionalParameters)`.

#### 4.2.2 Token (`OAuth2CustomWadizAuthenticationToken`, `:9-26`)

- `OAuth2AuthorizationGrantAuthenticationToken` 서브클래스. `AuthorizationGrantType("wadiz_web")` 고정.
- `scopes` (UnmodifiableSet), `username` 을 별도 필드로 보관.

#### 4.2.3 Provider (`OAuth2CustomWadizAuthenticationProvider`, `:32-219`)

핵심 흐름:

1. Client 인증 확인 — `OAuth2ClientAuthenticationToken` 이 authenticated 인지 검사, 아니면 `invalid_client` (`:170-179`).
2. Client가 `wadiz_web` grant type 을 **등록되어 있어야 함** — 없으면 `unauthorized_client` (`:59-61`).
3. `userDetailsService.loadUserByUsername(customAuthentication.getUsername())` 로 `UserDetails` 조회.
   - `UsernameNotFoundException` → `OAuth2AuthenticationException("username_not_found")` (`:66-68`).
4. `UsernamePasswordAuthenticationToken.authenticated(userDetails, null, null)` — **비밀번호 검증 없이 Principal 인증 완료 처리** (`:70-72`). 비밀번호가 `null`이라 신뢰 가정이 필수.
5. 요청 scope들이 Client 허용 scope의 부분집합인지 확인, 아니면 `invalid_scope` (`:74-82`).
6. `OAuth2TokenContext`를 ACCESS_TOKEN 용으로 만들어 `tokenGenerator.generate` → `OAuth2AccessToken(BEARER)` 구성 (`:84-105`).
7. **ID Token (선택)**: `authorizedScopes`에 `openid`(`OidcScopes.OPENID`) 가 있을 때만 별도 `OAuth2TokenContext`로 생성 (`generateIdToken`, `:186-218`). 결과가 `OidcIdToken` 또는 `Jwt` 인 경우 둘 다 지원.
8. **Refresh Token**: Client 가 `REFRESH_TOKEN`을 지원하면 **무조건** 생성 — 원래는 `offline_access` scope 필수여야 하나 `// TODO DM : 일단은 Access Token의 길이 문제로 offline_access scope의 필수요건 주석처리` (`:112-113`) 주석 그대로 임시로 풀려 있음.
9. `OAuth2Authorization`을 빌드해 `authorizationService.save(authorization)` — Claim 이 있는 accessToken은 `CLAIMS_METADATA_NAME` 로 함께 저장 (`:131-154`).
10. `id_token`을 `additionalParameters`에 실어 `OAuth2AccessTokenAuthenticationToken` 반환 (`:156-161`).

> **Observation**: `wadiz_web`은 **사용자 패스워드를 제출하지 않는 grant**다. 사전 인증된 세션/서명된 username을 Client(웹서버)가 대신 전달해 토큰을 받는 “session → token” 교환 용도로 구현되어 있다. Access Token 길이 완화를 위해 `offline_access` 필요 조건이 주석 처리된 상태가 현재 유효.

### 4.3 기타 grant 미구현

- OAuth2 **Password** grant / **Device Authorization** grant / **Token Exchange (RFC 8693)** 용 converter·provider는 코드에 없다.
- RP-Initiated Logout(`/logout`, OIDC 1.0) 만 대체 구현 (뒤 3장 참조).

---

## 5. 소셜 로그인 — Kakao 중심 흐름

### 5.1 Authorization Request 흐름

두 가지 진입 경로:

#### A) 표준 브라우저 redirect

`/oauth2/authorize/{provider}` → Spring `OAuth2AuthorizationRequestRedirectFilter` → `WadizOAuth2AuthorizationRequestResolver.resolve(...)` (`authentication/WadizOAuth2AuthorizationRequestResolver.java:48-80`).

- 내부에서 `DefaultOAuth2AuthorizationRequestResolver`에 **Customizer** 연결 (`:32-45`):
  - `kakao` → `service_terms=funding_membership,funding_use,funding_privacy,funding_marketing,user_age_check` 파라미터 추가.
  - `line` → `bot_prompt=aggressive` 파라미터 추가.
- 요청 파라미터로 `remember-me 이름(기본 "rememberme")`가 오면 **HttpSession에 복사**(`:56-61`, `:72-78`). 소셜 로그인 완료 후 `WadizPersistentTokenBasedRememberMeServices.rememberMeRequested()` 가 이 세션 값을 꺼내 쿠키 발급 여부를 결정 (`WadizPersistentTokenBasedRememberMeServices.java:46-60`).

#### B) SDK 기반 사전 등록 (Kakao)

`/api/v1/authorization-register/kakao` — `social/kakao/KakaoOAuth2AuthorizationRequestRegisterController.kt:22-54`.

- 동일 `WadizOAuth2AuthorizationRequestResolver`를 **다른 baseUri `/api/v1/authorization-register/`** 로 하나 더 생성.
- Resolver로 만들어진 `OAuth2AuthorizationRequest`를 `HttpSessionOAuth2AuthorizationRequestRepository`에 저장해 **같은 세션의 이후 callback 이 기존 Spring filter 와 동일하게 state 매칭**되도록 함.
- `KakaoAuthorizationRequest`(`social/kakao/KakaoAuthorizationRequest.kt`) 로 `state`, `clientId`, `responseType`, `redirectUri`, `serviceTerms` 다섯 필드만 응답 — Kakao SDK 호출 쪽에서 쓰도록 설계.

### 5.2 Callback / UserInfo 단계

`/oauth2/callback/*` → `OAuth2LoginAuthenticationFilter` → `userInfoEndpoint.userService` = `WadizOAuth2UserService` (OAuth2 일반) 또는 `oidcUserService = WadizOidcUserService` (OIDC).

#### `WadizOAuth2UserService` (`social/WadizOAuth2UserService.java`)

- `loadUser(oAuth2UserRequest)` (`:54-80`)
  1. `getOAuth2User`: Apple 이면 id_token(parser `OpenIdTokenVerifyParser`) 을 파싱해 `sub/email/id` attribute로 `DefaultOAuth2User` 생성(`:103-123`). 그 외는 `super.loadUser` (Kakao/Naver/Google/Facebook/LINE userinfo endpoint 호출).
  2. `provider` → `SocialAccountConverterMap.getConverter(provider)` (`converter/SocialAccountConverterMap.java:40-42`) → provider별 `OAuth2UserToXxxAccountConverter`.
  3. 예) `OAuth2UserToKakaoAccountConverter.convert(user, accessToken)` (`converter/OAuth2UserToKakaoAccountConverter.java:19-57`):
     - `kakao_account.profile.nickname / profile_image_url`, `kakao_account.email`, `phone_number`, `birthday`, `birthyear`, `gender` 수집.
     - `providerUserId = user.getName()` (`sub` 에 해당).
     - `account.setAgreement(kakaoPort.getAgreement(accessToken))`, `account.setAgreeToFriendsScope(kakaoPort.isFriendsScopeAgreed(...))` — Kakao 약관 동의 내역 동기화를 위해 외부 호출.
  4. `createOAuth2User(provider, socialAccount)` → `SocialUserService.findUserDTOByProviderIdAndProviderUserId` (`social/SocialUserService.java:39-54`) 로 와디즈 `UserDTO` 매칭 → `createUserAttributes`로 `attributes`에 도메인 `User` 를 `"wadizUser"` 키로 주입 → `DefaultOAuth2User(emptyAuthorities, userAttributes, "sub")`.

- **매칭 실패 시 흐름** (`SocialUserService.handleExceptionCases`, `:78-112`):
  - `email` 공백 → `SocialEmptyEmailException`.
  - 같은 이메일의 활성 와디즈 유저가 존재 → 상황별 `EmailAlreadyRegisteredException(CaseNumber.{LINK_WITH_PASSWORD | LOGIN_WITH_EMAIL | LOGIN_WITH_ANOTHER_SNS})` (케이스 구분은 `user.isLinkedToProvider`, `user.isActive`, `user.hasPassword` 조합).
  - 없고 90일 내 탈퇴 이력 있음 → `DropoutHistoryExistsException`.
  - 없고 탈퇴 이력도 없음 → `SignUpNeededException` (가입 안내).
  - 각 예외는 `HavingSocialAccount` 인터페이스로 `SocialAccount`를 붙여 전달.

#### `WadizOidcUserService` (`social/WadizOidcUserService.java`)

- OIDC RP 경로. **LINE 전용 커스텀**: `registrationId == "line"` 이면 `LineIdTokenDecoder.decode(idToken)` 로 HS256 서명을 직접 풀고(`:53-94`), 이후는 `SocialUserService`로 동일하게 매핑. LINE 외(Google 등)은 `OidcUserService` 기본 구현에 위임.
- LINE 매칭 성공 시 기존 OIDC attributes에 `wadizUser` attribute를 병합하여 `DefaultOidcUser`를 리빌드.

### 5.3 `SocialAuthenticationSuccessHandler` (`authentication/SocialAuthenticationSuccessHandler.java`)

소셜 로그인 성공 후 최종 리다이렉션을 결정한다.

1. `OAuth2AuthenticationToken`에서 `getAttribute("wadizUser")` → 도메인 `User` 획득 (`:87-88`).
2. `oAuth2AuthorizedClient`에서 `accessToken`/`refreshToken`을 꺼내 `TokenStorable` 인터페이스 구현 소셜 계정에만 저장 (`:92`, `updateToken`, `:165-182`).
3. `userRepositoryPort.update(wadizUser)` — 소셜 계정 정보/토큰 갱신 (`:93`).
4. `syncKakaoAgreement(wadizUser, oAuth2AuthorizedClient)` — 카카오 계정인 경우만 `KakaoPort.getAgreement(token)` → `AgreementToTermsConverter.convert` → `TermsApiPort.updateAgreement` 호출 (`:141-151`).
5. `UserLoggedEvent` 발행(`:99`) — `SessionCleanerService.cleanUpExpiredSessionIdInIndexedRepository`가 비동기로 해당 principal의 고아 sessionId를 Redis Index에서 청소.
6. 분기 (`:102-116`):
   - `SavedRequest`가 없으면 **default client (`defaultClientId = ${wadiz.com.wadiz.web.client_id}`)** 의 `settings.client.link-complete-uri` 로 redirect (`goToClientAuthorizationRedirectURL`, `:119-125`).
   - `SavedRequest.requestURL`에 `/oauth/authorize`가 들어 있으면 → `super.onAuthenticationSuccess` → `SavedRequestAwareAuthenticationSuccessHandler` 가 원래 요청 URL로 돌려보내 **authorize 재호출**.
   - 그 외 (예: signup 중 소셜 로그인) → `savedRequest.getParameterValues("client_id")[0]` 로 해당 client의 `link-complete-uri` 로 이동.

부모 클래스 `WadizAuthenticationSuccessHandler.onAuthenticationSuccess` (`authentication/WadizAuthenticationSuccessHandler.java:20-29`) 는 `CookieUtil.setUserCookiesFromAuthentication(...)` 을 호출해 **DB 조회 없이 인증 객체로부터 유저 쿠키를 세팅**한 뒤 Spring 기본 success 흐름(`SavedRequestAwareAuthenticationSuccessHandler`)으로 이어진다.

### 5.4 실패 흐름 — `WadizAuthenticationFailureHandler` (`authentication/WadizAuthenticationFailureHandler.java`)

- 소셜 매칭 실패 예외를 분기 처리:
  - `DropoutHistoryExistsException` → `socialAccountRepositoryPort.removeSocialUser()` 후 `/login?errorCode=DROPOUT_HISTORY_EXISTS` (`:77-82`).
  - `HavingSocialAccount` (= `SignUpNeededException`·`SocialEmptyEmailException`) → `/social-signup?returnURL=<signup-complete-uri>` (`:160-176`). 소셜 계정은 `socialAccountRepositoryPort.saveSocialAccount(...)` 로 보관되어 signup 완료 시 재사용.
  - `EmailAlreadyRegisteredException`:
    - `LINK_WITH_PASSWORD` → `/social-link?username&returnURL` (client의 `settings.client.signup-complete-uri` 가 `returnURL`로 사용됨, `:141-144`, `linkReturnUrlFrom`).
    - 그 외 → `/login?errorCode=...&username&(providers)`.
  - 그 외 → `DebugUtil.showStackTrace` 후 기본 `/login?error;` (`:63-66`).
- **`getClientIdFrom`** — `savedRequest`에 `client_id` 가 없으면 기본값 `"com_wadiz_web"` 사용 (`:116-125`).

### 5.5 Converter 일람

| Provider | 파일 | 특이사항 |
|---|---|---|
| Kakao | `converter/OAuth2UserToKakaoAccountConverter.java` | kakao_account 중첩 map 파싱, 약관 동의 + friends scope 확인 호출(`KakaoPort`) |
| Naver | `converter/OAuth2UserToNaverAccountConverter.java:14-53` | `response` 루트 밑에서 id/nickname/email/birthday 추출, `age` 범위 문자열 그대로 보관. |
| Google | `converter/OAuth2UserToGoogleAccountConverter.java` | (미발췌) — provider 매핑용 경량 converter. |
| Facebook | `converter/OAuth2UserToFacebookAccountConverter.java` | (미발췌) |
| Apple | `converter/OAuth2UserToAppleAccountConverter.java:9-22` | `user.getName()`을 providerUserId로, email은 id_token claim에서 받은 값. |
| LINE | `converter/OAuth2UserToLineAccountConverter.java:8-26` | `name/picture/email` attribute 매핑. |
| 매핑 팩토리 | `converter/SocialAccountConverterMap.java:11-43` | `@PostConstruct`로 `Provider` enum → converter map 구성. |

### 5.6 Apple 부가 구성

- **client_secret JWT 재발급**: `AppleOAuthService.generateClientSecret` (`social/AppleOAuthService.java:39-56`)
  - `ES256` JWT: `iss=teamId`, `sub=clientId`, `aud=https://appleid.apple.com`, `exp=now+clientSecretExpirationDays`, `kid` 헤더 설정.
  - private key는 `spring.security.oauth2.client.registration.apple.keyFile` 경로의 PEM 파일(classpath)을 BouncyCastle로 파싱.
- **id_token 검증**: `OpenIdTokenVerifyParser` (`social/OpenIdTokenVerifyParser.java:19-73`) — `RemoteJWKSet` 로 Apple JWKS fetching, exp/iss/aud 수동 검증. `Claims`(`social/Claims.java`) 로 변환.
- **Server-to-Server Notification**: `AppleEventTokenParser` (`social/AppleEventTokenParser.java`) — `events` claim 을 `AppleEventPayload`(type/sub/email/is_private_email/event_time) 로 변환. `/webhooks/**` endpoint에서 소비.

---

## 6. `AuthenticationCode` 도메인

파일: `domain/authenticationcode/AuthenticationCodeService.java`(`:1-32`).

- `${wadiz.authentication.code.size}` 기반 **숫자 N자리 무작위 문자열** 생성 (`generateCode`, `:16-21`). 기본값 6자리. `Random` 인스턴스를 재사용.
- `checkValidity(code)` 메서드는 **선언만 되어 있고 구현이 비어 있음** (`:29-31`, 주석 `TODO change Exception type`).
- **V1/V2 분리**: 현재 이 저장소 내에서 `AuthenticationCodeService` 는 단일 버전만 존재 (`authenticationcode` 패키지에 다른 클래스 없음). 따라서 “V1/V2 차이” 는 **이 저장소 OAuth2 코어 범위에서는 관측되지 않음**. (코드 재전송/유효기간 관리는 다른 도메인/이메일 인증 로직에 위치할 가능성이 있으며 본 기록 범위를 벗어남.)
- 실제 OAuth2 흐름에서 호출 지점은 본 분석 범위 파일 내에 없고 (이메일 인증/가입 플로우에서 사용 추정) — **핵심 OAuth2 인가 경로에는 개입하지 않는다**.

## 6-bis. Service / ServiceType (deprecated)

- `domain/service/Service.java`(`@Deprecated`, `:1-23`), `ServiceType.java`(`@Deprecated`, `:14-58`), `ServiceTypeManager.java`(`@Deprecated`, `:9-58`).
- 과거 `funding`, `startup`, `equity` 서비스의 약관·경로 매핑을 하던 구조. URL prefix (`reward|rwd|wstartup|corporation|union`) → `ServiceType` lookup 을 제공했다.
- 모두 `@Deprecated`. OAuth2 인증·인가 코어 경로에서는 호출되지 않음. 문서에서는 존재 사실만 기록하고 상세 분석은 생략.

---

## 7. Aspect

### 7.1 `LoggingAspect` (`application/aspect/LoggingAspect.java`)

- **무효(disabled) 상태**. 파일 내 `@Component` 와 `@Aspect` 가 **둘 다 주석 처리**돼 있고(`:9`, `:11`), `@ConditionalOnClass` 만 남아 있으나 실제 등록되지 않는다.
- Pointcut 은 Spring **구버전** 경로 `org.springframework.security.oauth2.provider.endpoint.TokenEndpoint.postAccessToken(..)` 으로, 현재 의존성(`oauth2-authorization-server`)에는 존재하지 않는 클래스다. → 남아 있어도 무효.

### 7.2 `TransactionLogAspect` (`application/aspect/TransactionLogAspect.java`)

- `@Aspect @Component` 활성 (`:10-12`).
- `@annotation(transactional)` 바인딩으로 `@Transactional` 메서드 진입 직전에 `log.info("Transaction started: {}", transactional.value())` 를 남긴다. **OAuth2 인증 로직 자체에 개입하지는 않고**, 트랜잭션 메서드가 걸리는 도메인 업데이트(`userRepositoryPort.update`, `socialAccountRepositoryPort.saveSocialAccount` 등) 에서 전체 로그에 섞여 보이게 된다.

### 7.3 관측·보안 관점 로깅

명시적 Aspect 외의 로깅은 각 핸들러/서비스에 `@Slf4j` 로 직접 박혀 있다. 보안상 중요한 지점:

- `WadizPersistentTokenBasedRememberMeServices` — `TOKEN-CREATE`, `TOKEN-REFRESHING`, `TOKEN-THEFT`, `COOKIE THEFT`, `GET_CACHE-COOKIE`, `SET_CACHE-COOKIE`, `DELETE_CACHE-COOKIE` 로그를 `user-agent` 포함해 상세 기록 (`:100-171`).
- `WadizAuthenticationProvider` — 로그인 시도/성공/실패 카운트는 `LoginTryLimiter`(Redis, `common/utils/LoginTryLimiter.java`) 가 담당하며 Provider에서 과다 시도 시 `WadizTooManyLoginErrorAuthenticationException` 던짐.
- `ExceptionHandlerFilter` — `CookieTheftException` 발생 시 `HANDLER_TOKEN_THEFT` 로그 + `/error` redirect (`:18-20`).

---

## 8. 경계 · 미탐색 영역

- **본 문서가 다루지 않은 코어 주변**
  - `adapters/inbound/*` 전체 (Controller, DTO, CSRF 처리). OAuth2 흐름과 분리된 비즈니스 REST 엔드포인트.
  - `adapters/outbound/persistence/iam/authorization/AuthorizationRepository` (JPA 기반 `OAuth2AuthorizationService` 구현체로 추정) — Token 영속/만료 삭제 주체. `SchedulingService.removeExpiredToken` 에서 배치 사용.
  - `adapters/outbound/externalservice/kakao/*` (KakaoPort 구현, `KakaoAdapter`, `KakaoAuthClient`) — 약관/친구 scope 동의 확인 외부 호출. 본 문서는 SuccessHandler·Converter 가 호출하는 `Port` 인터페이스 지점까지만.
  - `domain/user/*` 의 User/SocialAccount/AppleAccount/LineAccount/KakaoAccount 세부 구조 — 이름과 인터페이스(`TokenStorable`, `getFirstSocialAccount`, `isLinkedToProvider`, `hasPassword`, `isActive`, `isKakaoUser`) 만 인용.
  - `domain/terms`, `AgreementToTermsConverter`, `TermsApiPort` — 약관 도메인은 분석 범위 밖.
  - Email Verification / 비밀번호 찾기 / 가입 / Link 실제 비즈니스 로직 — `/social-signup`, `/social-link`, `/reset-password/*` 컨트롤러 미조사.
  - `DatasourceConfig`, `IamDbJpaConfig`, `WadizDbJpaConfig`, `PropertyEncryptionConfig`, `CorsConfig`, `RestTemplateConfig`, `WebConfig`, `DeviceTypeResolver`, `CustomLocaleResolver`, `FeignConfig` — 인증 코어 주변 인프라 설정. 필요 지점(Cors는 `SecurityConfig` 에서 `corsConfigurationSource`로 주입, Redis/Jdbc는 RememberMe에서 사용) 에서만 언급.

- **관측 가능하지만 사용처 미검증**
  - `AuthenticationCodeService.checkValidity` 가 공백이라 실사용자 검증 로직이 다른 계층에 있을 것으로 보이나 이 범위에서는 호출 지점을 확인할 수 없음.
  - `OidcLogoutSuccessHandler`(`authentication/OidcLogoutSuccessHandler.java`) 는 `@Component` 로 존재하나 `SecurityConfig` 에서 logoutEndpoint response handler 로는 `WadizOidcLogoutHandler`(new 인스턴스) 가 쓰인다. 이 Bean 이 외부에서 재사용되는 지점은 본 스코프에서 확인 안 됨 (추후 컨트롤러 검토 필요).
  - `LoggingAspect` 는 주석 처리된 상태로 빌드에 영향 없음.
  - `application/config/filter/WadizUsernamePasswordAuthenticationFilter` 는 `@Deprecated` 이며 `attemptAuthentication → return null`. 어디에서도 bean 으로 올라가지 않음.

- **세대 힌트**
  - 코드베이스는 “**이전 Spring Security OAuth2 구버전 → `oauth2-authorization-server` 1.x 이관**” 의 흔적이 뚜렷하다: endpoint 경로를 `/oauth/token` 등으로 맞춰 둔 점, `LoggingAspect`가 구버전 `TokenEndpoint`를 가리키는 점, `setAccessTokenClaims`에 레거시 스타일 `user_name` 클레임이 남아있는 점.
  - Kotlin 파일은 최소 (`WadizOidcLogoutAuthenticationConverter.kt`, `social/kakao/*.kt`) — 신규 로직 일부만 Kotlin 으로 추가되고 있는 단계.

- **확인 필요(observability gaps)**
  - `wadiz_web` grant의 **실제 호출 주체**(어느 내부 서비스가 Client로서 `grant_type=wadiz_web&username=...` 를 호출하는지) 는 본 저장소 코드로는 관측 불가. Client 등록 DB (`iam.Client` 테이블) 에 `wadiz_web` 이 등록된 client_id 목록을 봐야 함.
  - `setCookieDomain("wadiz.kr")` (`RememberMeConfig.java:61`) 및 `CookieRemoveFilter`(`authentication/filter/CookieRemoveFilter.java`) 의 도메인 하드코딩 — 비-prod 환경(`local.wadiz.kr`, `rc.wadiz.kr` 등) 동작은 설정/Nginx 수준에서 결정되며 본 파일들에는 환경 분기 없음.
  - LINE `HS256` id_token 디코딩 (`LineIdTokenDecoder`) 은 `client-secret` 원문을 HMAC 키로 사용 — OIDC spec 상 허용되지만 배포환경 시크릿 관리가 전제. `jwtDecoderFactory` 는 LINE 외 provider에 대해 `JwtDecoders.fromIssuerLocation` 을 쓰므로 provider 별 issuer 설정이 yml에 정확히 들어 있어야 함.
  - `WadizOidcLogoutAuthenticationConverter`의 `getQueryParameters` 에서 `queryString.contains(key)` 문자열 매칭(`:78`) — 파라미터명 간섭(예: `state` vs `state_x`) 가능성이 있음. 엄밀한 파라미터 추출과는 다르다는 점만 기록.

---

*(기록 시점: 2026-04-20. Spring Boot 3.1 / Spring Security 6.x / `spring-security-oauth2-authorization-server` 1.x 가정 — build.gradle 미포함 범위이므로 버전은 소스 import 패턴으로만 추정.)*
