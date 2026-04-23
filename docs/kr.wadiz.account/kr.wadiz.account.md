# kr.wadiz.account 분석 문서

> **Phase 2 심층 분석 진행 중**. 전체 엔드포인트는 [`api-endpoints.md`](./api-endpoints.md), 도메인별 상세는 `api-details/` 하위 참조.
>
> | 영역 | 파일 |
> |---|---|
> | inbound Controllers (OAuth2 커스텀 엔드포인트 12개) | [`api-details/inbound-controllers.md`](./api-details/inbound-controllers.md) |
> | OAuth2 Authorization Server 코어 (authentication + customgrant) | [`api-details/oauth2-auth-core.md`](./api-details/oauth2-auth-core.md) |
> | Persistence (wadiz/iam DB + Redis) | [`api-details/persistence.md`](./api-details/persistence.md) |
> | 외부 서비스 연동 (11 externalservice 어댑터) | [`api-details/external-services.md`](./api-details/external-services.md) |
> | Domain Model (DDD aggregates + Ports) | [`api-details/domain-model.md`](./api-details/domain-model.md) |

## 개요

`kr.wadiz.account`는 와디즈의 **OAuth2 Authorization Server + 계정(회원) 플랫폼**이다. 표준 OAuth2/OIDC 인가서버 기능(`/oauth/authorize`, `/oauth/token`, `/oauth/revoke`, `/oauth/check_token`, `/oauth/token_key`, `/userinfo`, `/connect/register`, `/.well-known/*`)과 와디즈 자체의 로그인 UI, 이메일/소셜 회원가입, 계정 연결(link), 비밀번호 재설정, 세션 관리 등 계정 도메인 전반을 함께 수행한다.

- 애플리케이션 진입점: `src/main/java/kr/wadiz/oauth2/Application.java` (group `kr.wadiz.auth`)
- 기본 포트: `8080` (`src/main/resources/application.yml:6`)
- Spring Session은 **Redis**(`namespace: account`) 기반, 인가/계정 데이터는 **MySQL**(JPA)에 저장, 계정 원장(`UserProfile`, `webpages_Membership` 등)은 기존 Wadiz RDB 테이블을 그대로 매핑.
- 아키텍처는 **Hexagonal(포트 & 어댑터)**, 주 패키지는 `kr.wadiz.oauth2.adapters`, `kr.wadiz.oauth2.application`, `kr.wadiz.oauth2.domain`, `kr.wadiz.oauth2.port`.
- 배포: Kubernetes / ansible / skaffold (`Jenkinsfile_account_*`, `skaffold.yaml`). Jasypt로 properties 암호화(`application.yml:161-163`).

## 기술 스택

- **언어**: Java 17 + Kotlin 1.9.24 혼용 (domain/adapters는 대부분 Java, 일부 컨트롤러·mail DTO·common은 `.kt`).
- **Spring Boot 3.1.2** (`build.gradle:17`)
  - `spring-boot-starter-oauth2-client`, `spring-security-oauth2-authorization-server:1.2.6`
  - `spring-boot-starter-data-jpa`, `starter-security`, `starter-thymeleaf`, `starter-web`, `starter-webflux`, `starter-data-redis`, `spring-session-data-redis`, `starter-validation`
  - Spring Cloud 2022.0.3: `starter-openfeign`, `starter-kubernetes-client-config`
- **DB/Cache**: MySQL(`mysql-connector-j`), Redis(세션/이메일인증/비번재설정 토큰)
- **라이브러리**: Jasypt(properties 암호화), MapStruct 1.5.5, Lombok, Nimbus JWT, BouncyCastle, `jjwt:0.9.1`, `UserAgentUtils`(device 감지), `libphonenumber:8.13.40`, `springdoc-openapi 2.0.2`, `jackson-module-kotlin`
- **테스트**: Spock 2.4 + Groovy 4, Kotlintest 3.3.1, MockK 1.9, Testcontainers
- **빌드**: Gradle, `bootBuildImage`로 `wadiz/${project.name}:${version}` 이미지 생성(`build.gradle:142-145`).

## 아키텍처

Hexagonal 구조로 4개 레이어:

- `kr.wadiz.oauth2.adapters.inbound` — HTTP 컨트롤러, DTO, validator, mapper, 전역 예외 핸들러(`GlobalExceptionHandler.java`)
- `kr.wadiz.oauth2.adapters.outbound.persistence` — JPA/Redis 기반 리포지토리 + 엔티티
  - `wadiz/*`: 서비스 RDB (유저, 소셜유저, 마케팅동의/이력, 추천, 사진, 유저이력녹음)
  - `iam/*`: 인가서버 전용 테이블(Client, Authorization, AuthorizationConsent)
  - `redis/*`: 이메일 인증코드, 비밀번호 재설정 토큰, SocialAccount 세션 저장
- `kr.wadiz.oauth2.adapters.outbound.externalservice` — Feign 기반 외부 서비스 어댑터
- `kr.wadiz.oauth2.application` — Spring Security / OAuth2 Authorization Server / OAuth2 Client 구성, custom grant, authentication providers, session/rememberMe/scheduling
- `kr.wadiz.oauth2.domain` — 순수 도메인(User, SocialAccount, Terms, 이벤트) + `applicationservice`(트랜잭션 경계)
- `kr.wadiz.oauth2.port` — `inbound`(UseCase 인터페이스), `outbound`(RepositoryPort·Feign 추상 인터페이스)

### Spring Security 설정 (`src/main/java/kr/wadiz/oauth2/application/SecurityConfig.java`)

두 개의 `SecurityFilterChain`으로 구성:

1. **Order(1) — Authorization Server 체인** (`SecurityConfig.java:106`)
   - `OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http)` 위에
   - `tokenEndpoint`에 커스텀 `OAuth2CustomWadizAuthenticationConverter` + `OAuth2CustomWadizAuthenticationProvider` 추가(`application/customgrant/*`). 기본 password grant 대체로 와디즈 전용 로직 수행.
   - OIDC Logout은 `WadizOidcLogoutAuthenticationConverter` + `WadizOidcLogoutAuthenticationProvider` + `WadizOidcLogoutHandler`로 대체(RememberMe까지 정리, `SecurityConfig.java:118-137`).
   - `authorizationResponseHandler`에 `AuthorizationAuthenticationSuccessHandler` 주입.

2. **Order(2) — App 체인** (`SecurityConfig.java:166`)
   - 세션 로그인: `/login` + `formLogin(loginProcessingUrl=/oauth/loginPerform)` → 성공 시 `EmailAuthenticationSuccessHandler`, 실패 시 `WadizAuthenticationFailureHandler`.
   - 소셜 로그인: `oauth2Login` `authorizationEndpoint baseUri=/oauth2/authorize`, `redirectionEndpoint=/oauth2/callback/*`, 성공 시 `SocialAuthenticationSuccessHandler`.
   - `rememberMe` + `WadizPersistentTokenBasedRememberMeServices`.
   - 공개 경로: `/v3/api-docs/**`, `/api/**`, `/.well-known/**`, `/login`, `/signup`, `/social-signup`, `/social-link`, `/reset-password/*`, `/find-password`, `/find-id`, `/oauth2/**`, `/swagger-ui/**`, `/webhooks/**`, `/actuator/**` (`SecurityConfig.java:182-203`).
   - 로그아웃: `/oauth/logout`.

### OAuth2 Authorization Server 엔드포인트 재매핑 (`SecurityConfig.java:268-278`)

Spring 기본 경로를 와디즈 전용으로 리맵:

```java
AuthorizationServerSettings.builder()
  .authorizationEndpoint("/oauth/authorize")
  .tokenEndpoint("/oauth/token")
  .tokenIntrospectionEndpoint("/oauth/check_token")
  .tokenRevocationEndpoint("/oauth/revoke")
  .jwkSetEndpoint("/oauth/token_key")
  .oidcUserInfoEndpoint("/userinfo")
  .oidcClientRegistrationEndpoint("/connect/register");
```

- JWK 키는 `resources/keystore/oauth-keystore.jks`의 `oauth2.0` alias에서 RSA 키페어를 로드해 `JWKSource` 구성(`SecurityConfig.java:298-303`).
- Access Token 커스터마이저: `id`, `user_name`, `scope` 클레임 주입(`SecurityConfig.java:377-380`).
- ID Token 커스터마이저: `nickname`, `picture`, `email`, `email_verified` 클레임 주입(`SecurityConfig.java:363-375`).
- LINE OIDC는 HS256이라 `JwtDecoderFactory`에서 `LineIdTokenDecoder` 분기 처리(`SecurityConfig.java:413-430`).

### Custom Grant

`application/customgrant/OAuth2CustomWadizAuthenticationProvider.java` + `OAuth2CustomWadizAuthenticationConverter.java` + `OAuth2CustomWadizAuthenticationToken.java`는 Spring 3.x에서 삭제된 password grant를 와디즈 전용으로 재구현하여 `tokenEndpoint`에 등록.

## API 엔드포인트 목록

> OAuth2/OIDC 표준 엔드포인트는 Spring Authorization Server가 자동 등록하므로 와디즈 레포에 컨트롤러 매핑이 없다.

### OAuth2/OIDC 표준 (Spring Authorization Server가 제공)

| Method | Path | 제공 방식 | 용도 |
|---|---|---|---|
| GET/POST | `/oauth/authorize` | `AuthorizationServerSettings.authorizationEndpoint` | Authorization Code 발급 진입점 |
| POST | `/oauth/token` | `.tokenEndpoint` + Custom Converter/Provider | 토큰 발급(`authorization_code`, `refresh_token`, wadiz custom password) |
| POST | `/oauth/check_token` | `.tokenIntrospectionEndpoint` | 토큰 인트로스펙션(RFC 7662) |
| POST | `/oauth/revoke` | `.tokenRevocationEndpoint` | 토큰 취소(RFC 7009) |
| GET | `/oauth/token_key` | `.jwkSetEndpoint` | JWK Set 조회 |
| GET | `/.well-known/jwks.json` | Authorization Server 기본 | JWK Set(표준 디스커버리 경로) |
| GET | `/.well-known/openid-configuration` | Authorization Server 기본 | OIDC Discovery |
| GET | `/userinfo` | `.oidcUserInfoEndpoint` | OIDC UserInfo |
| POST | `/connect/register` | `.oidcClientRegistrationEndpoint` | OIDC Dynamic Client Registration |
| GET | `/oauth2/authorize` | `oauth2Login.authorizationEndpoint.baseUri` | 외부 Provider(카카오/네이버/애플/LINE/구글/페북) 로그인 진입 |
| GET | `/oauth2/callback/*` | `oauth2Login.redirectionEndpoint.baseUri` | 외부 Provider 콜백 |
| POST | `/oauth/loginPerform` | `formLogin.loginProcessingUrl` | 이메일/패스워드 로그인 폼 처리 |
| POST | `/oauth/logout` | `logout.logoutUrl` | 서버 세션 로그아웃 |
| GET | `/connect/logout` | OIDC RP-Initiated Logout | 클라이언트 주도 로그아웃 |

### 커스텀 컨트롤러

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| GET | `/` | `MainController.index` | wadiz.kr로 리다이렉트 (`MainController.java:44`) |
| GET | `/login` | `MainController.login` | 로그인 페이지(`login.html`), authorize 파라미터 email 프리필 (`MainController.java:53`) |
| GET | `/signup` | `MainController.signup` | 회원가입 페이지 (`MainController.java:112`) |
| GET | `/social-signup` | `MainController.socialSignup` | 소셜 가입 페이지 (`MainController.java:143`) |
| GET | `/social-link` | `MainController.linkUser` | 소셜 계정 연결 페이지 (`MainController.java:165`) |
| GET | `/reset-password/{token}`, `/find-password`, `/find-id` | `MainController.resetPassword` | 비밀번호/ID 찾기 SPA 진입 (`MainController.java:181`) |
| POST | `/api/v1/users` | `SignUpController.signUpWithEmail` | 이메일 기반 회원 가입 (`SignUpController.java:80`) |
| POST | `/api/v1/social-users` | `SignUpController.signUpWithSocialAccount` | 소셜 계정 기반 회원 가입 (`SignUpController.java:112`) |
| GET | `/api/v1/signup-information` | `SignUpController.getSignUpStatus` | 가입 플로우 중 필요한 정보 조회 (`SignUpController.java:153`) |
| POST | `/api/v1/link-users` | `LinkController.linkUserToSocialAccount` | 기존 이메일 계정에 소셜 계정 연결 (`LinkController.java:56`) |
| POST | `/api/v1/authentication-code` | `AuthenticationCodeV1Controller.authenticate` | 이메일 인증코드 발송(200) (`AuthenticationCodeV1Controller.java:31`) |
| GET | `/api/v1/authentication-code/{code}/valid` | `AuthenticationCodeV1Controller.isValid` | 이메일 인증코드 검증(200) (`AuthenticationCodeV1Controller.java:43`) |
| POST | `/api/v2/authentication-code` | `AuthenticationCodeV2Controller.authenticate` | 이메일 인증코드 발송(204) (`AuthenticationCodeV2Controller.java:31`) |
| GET | `/api/v2/authentication-code/{code}/valid` | `AuthenticationCodeV2Controller.isValid` | 이메일 인증코드 검증(204) (`AuthenticationCodeV2Controller.java:44`) |
| POST | `/api/v1/find-id` | `IdPasswordManagementController.findUserByUsername` | 아이디 존재 여부 조회 (`IdPasswordManagementController.kt:35`) |
| POST | `/api/v1/password-reset/request` | `IdPasswordManagementController.sendPasswordResetMail` | 비밀번호 재설정 메일 발송 (`IdPasswordManagementController.kt:45`) |
| POST | `/api/v1/password-reset/confirm` | `IdPasswordManagementController.resetPassword` | 토큰 기반 비밀번호 재설정 (`IdPasswordManagementController.kt:59`) |
| POST | `/api/v1/cookie/validity` | `SessionController.isCookieValid` | RememberMe 쿠키 유효성 점검(x-api-key 인증) (`SessionController.kt:30`) |
| DELETE | `/api/v1/users/{userId}/sessions` | `SessionController.removeAllSessions` | 특정 사용자 세션/토큰 전체 삭제(x-api-key) (`SessionController.kt:48`) |
| DELETE | `/api/v1/sessions` | `SessionController.removeAllSessions(jwt)` | Bearer token 기반 전체 세션 삭제 (`SessionController.kt:65`) |
| GET | `/api/v1/user-login-status` | `SessionController.currentStatus` | 현재 로그인/RememberMe 상태 확인 (`SessionController.kt:73`) |
| GET | `/api/v1/error-codes` | `ErrorCodeController.errorCodes` | i18n 에러코드 목록 조회 (`ErrorCodeController.java:22`) |
| POST | `/webhooks/apple/server-notifications` | `AppleNotificationController.handleNotification` | Apple Server-to-Server Notification 수신(JWS 검증) (`AppleNotificationController.java:42`) |
| GET | `/v0/oauth2/callback` | `CallbackController.callback` | 토큰 발급 테스트/디버깅 페이지 (`CallbackController.java:42`) |
| GET | `/test_page` | `CallbackController.testPage` | hello 렌더링(테스트) (`CallbackController.java:138`) |
| GET | `info` | `MaintenanceController.configuration` | 버전/세션/IP 정보 (`MaintenanceController.java:28`) |
| GET | `info/{fileName}` | `MaintenanceController.releaseNote` | 릴리즈노트 텍스트 파일 조회 (`MaintenanceController.java:45`) |

## 주요 API 상세 분석

### 1. POST `/api/v1/users` — 이메일 회원가입 (`SignUpController.java:79-107`)

- **요청 DTO**: `EmailSignUpDto`(email, password, nickname, country, language, agreedTerms 등)
- **흐름**:
  1. `Locale`(language, country) 생성 → `EmailSignUpDtoToCommandMapper.toCommand`로 `EmailSignUpCommand` 변환.
  2. `checkEmailAuthentication(session.getId(), email)` — Redis(`EmailValidationCodeEntity`)에 저장된 인증 결과 조회. 실패 시 `EmailNotAuthenticatedException`.
  3. `getSignUpCompleteUri(request, response)` — SavedRequest의 `client_id`로 `RegisteredClient`를 조회해 `settings.client.signup-complete-uri` 추출(`SignUpController.java:170-187`).
  4. `createUserApplicationService.signUpWithEmail(command, deviceType, locale)` — `@Transactional("wadizTransactionManager")` 안에서 (`CreateUserApplicationService.java:62-71`):
     - `User.createUserWithEmail(...)` 팩토리로 도메인 객체 생성
     - `userRepositoryPort.create(user)` — JPA로 `UserProfile`, `webpages_Membership`(Password), `TbUserProvider`, `UserLocaleHistory` 등 생성
     - `UserCreatedEvent` 발행 → 리스너들이 약관/CRM/쿠폰/푸시 후처리
     - `servletPort.login(user, password)` — 자동 로그인
  5. 후처리(개별 예외 catch):
     - `updateUserTimeZone(user)` → `UserClient.updateUserTimeZone(userId, UserTimeZoneUpdateByCountryRequest)` (`PUT /{userId}/time-zone/by-country`)
     - `doRemainingWork(user)` (확장 훅)
- **DB 상호작용 (SQL 개요)**:
  ```sql
  INSERT INTO UserProfile (`UserId`, UserName, NickName, Grade, AccntType, UserStatus,
                           AllowDM, LanguageCode, CountryCode, WhenLastLogon, ...)
  VALUES (DEFAULT, ?, ?, 'f', 'N1000', 'NM', ?, ?, ?, NOW(), ...);

  INSERT INTO webpages_Membership (`UserId`, `Password`, `CreateDate`, `PasswordChangedDate`)
  VALUES (?, ?, NOW(), NOW());                       -- JPA @CreationTimestamp / @UpdateTimestamp

  INSERT INTO TbUserProvider (...) VALUES (...);
  INSERT INTO UserLocaleHistory (...) VALUES (...);
  INSERT INTO LoginHis(ClientType, UserId, SessionId, ReqDate, ReqIP, WaId)
  VALUES (?, ?, ?, NOW(), ?, ?);
  ```
  `UserProfile` 컬럼명은 CamelCase + 백틱 유지(`@Column(name="\`UserId\`")` 패턴, `UserProfile.java:22-81`).
- **응답**: `201 Created`, `Location: /api/v1/users/{userId}`, body = `SignUpSuccessDto(signUpCompleteUri)`.

### 2. POST `/api/v1/social-users` — 소셜 회원가입 (`SignUpController.java:111-149`)

- Redis 세션에 저장된 `SocialAccount`(`SocialAccountRepositoryPort.loadSocialAccount()`)를 꺼내 `SocialSignUpCommand`에 바인딩.
- `KakaoAccount`인 경우 `AgreementToTermsConverter.convert(kakaoAccount.getAgreement())`로 카카오 약관을 Wadiz Terms 스키마로 변환 (`SignUpController.java:129-132`).
- `createUserWithSocialAccountApplicationService.signUpWithSocial(...)` — 일반 가입 흐름 + `webpages_OAuthMembership` 테이블 INSERT + `TbProviderProfile`, `TbProviderScope` 기록.
- **SQL**:
  ```sql
  INSERT INTO webpages_OAuthMembership(`Provider`, `ProviderUserId`, `UserId`, Token, RefreshToken,
                                        Registered, Updated)
  VALUES (?, ?, ?, ?, ?, NOW(), NOW());
  INSERT INTO TbProviderProfile(`userId`, `provider`, `gender`, `birthday`, `birthyear`,
                                `friendscount`, `created`, `updated`)
  VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW());
  ```

### 3. POST `/api/v1/link-users` — 기존 이메일 계정에 소셜 계정 연결 (`LinkController.java:55-90`)

- 요청: `LinkSocialAccountDto(username=email, password)`.
- 세션의 `SocialAccount` 로드 후 email 일치 검증(`EmailNotMatchedException`), `WadizAuthenticationProvider.authenticate(email, password)`로 재로그인 후 `servletPort.login(authentication, true)`.
- `LinkUserToSocialUserApplicationService.linkWithoutCheck(command)`로 `webpages_OAuthMembership` 행 생성 → 응답 `linkCompleteUrl`.
- **SQL**:
  ```sql
  SELECT * FROM webpages_Membership WHERE `UserId` = ?;
  SELECT * FROM UserProfile WHERE UserName = ?;
  INSERT INTO webpages_OAuthMembership(`Provider`, `ProviderUserId`, `UserId`, Token, RefreshToken, ...)
  VALUES (?, ?, ?, ?, ?, ...);
  ```

### 4. POST `/api/v1/authentication-code` — 이메일 인증 코드 발송 (`AuthenticationCodeV1Controller.java:30-37`, V2는 204)

- `SendAuthenticationCodeViaEmailUsecase.sendAuthenticationCode(sessionId, email, locale)`
- 내부: 인증 코드 생성 → Redis(`EmailValidationCodeEntity`, key=sessionId) TTL 저장 → `FastMailClient.sendMail(bearer, FastMailRequest)` (`externalservice/fastmail2/FastMailClient.java:11`, `POST https://{profile}-platform.wadizcorp.net/mail-fast/api/v2/send`)로 HTML 메일 발송. Bearer 토큰은 `wadiz.api.mail.fast.token` 사용.

### 5. POST `/api/v1/password-reset/request` / `/api/v1/password-reset/confirm` (`IdPasswordManagementController.kt`)

- **request**: Redis에 `PasswordResetTokenEntity`(TTL) 생성 + FastMail로 재설정 링크 발송.
- **confirm**: 토큰 조회·검증 → `WadizPassWordUtils` 해시로 `webpages_Membership.Password` UPDATE + `PasswordChangedDate` 자동 갱신. 기존 비밀번호와 동일 시 `SamePasswordException`. 재설정 후 세션도 정리.
- **SQL**:
  ```sql
  SELECT * FROM webpages_Membership WHERE `UserId` = ?;
  UPDATE webpages_Membership SET `Password` = ?, `PasswordChangedDate` = NOW()
  WHERE `UserId` = ?;
  ```

### 6. POST `/oauth/token` — 토큰 발급 (표준 + 커스텀)

- 표준 grant(`authorization_code`, `refresh_token`, `client_credentials`)는 Spring Authorization Server가 처리.
- 와디즈 커스텀 grant: `OAuth2CustomWadizAuthenticationConverter`가 요청 → `OAuth2CustomWadizAuthenticationToken` 변환 → `OAuth2CustomWadizAuthenticationProvider`가 `UserDetailsService`(→ `WadizUserDetailService` → `webpages_Membership`, `UserProfile` 조회)로 검증 후 `tokenGenerator`(`DelegatingOAuth2TokenGenerator[JwtGenerator, OAuth2AccessTokenGenerator, OAuth2RefreshTokenGenerator]`)로 JWT 발급.
- **DB 상호작용 (SQL)**:
  ```sql
  SELECT * FROM `RegisteredClient` WHERE clientId = ?;
  SELECT * FROM webpages_Membership WHERE `UserId` = ?;
  SELECT * FROM UserProfile WHERE UserName = ?;

  INSERT INTO `Authorization`(id, registeredClientId, principalName, authorizationGrantType,
                               authorizedScopes, attributes, state,
                               authorizationCodeValue, authorizationCodeIssuedAt, authorizationCodeExpiresAt,
                               accessTokenValue, accessTokenIssuedAt, accessTokenExpiresAt,
                                 accessTokenMetadata, accessTokenType, accessTokenScopes,
                               refreshTokenValue, refreshTokenIssuedAt, refreshTokenExpiresAt,
                                 refreshTokenMetadata,
                               oidcIdTokenValue, oidcIdTokenIssuedAt, oidcIdTokenExpiresAt,
                                 oidcIdTokenMetadata, oidcIdTokenClaims,
                               userCodeValue, userCodeIssuedAt, userCodeExpiresAt, userCodeMetadata,
                               deviceCodeValue, deviceCodeIssuedAt, deviceCodeExpiresAt, deviceCodeMetadata)
  VALUES (...);
  ```
  `Authorization.java:19-85`에 매핑. 토큰 값과 메타데이터는 BLOB 컬럼.
- Access Token 클레임: `scope`, `id`, `user_name` (`SecurityConfig.java:377-380`).
- ID Token 클레임: `nickname`, `picture`, `email`, `email_verified` (`SecurityConfig.java:363-375`).

### 7. POST `/oauth/revoke` + DELETE `/api/v1/users/{userId}/sessions`

- 표준 `/oauth/revoke`가 `Authorization` 테이블 레코드 무효화.
- `SessionController.removeAllSessions`(`SessionController.kt:47`)는 `x-api-key` 헤더(`wadiz.authorization.server.adminkey`) 검증 후 `UserSessionService.cleanupAllUserSessions(userId)`:
  - Spring Session Redis의 indexed `PRINCIPAL_NAME_INDEX_NAME` 기반 전체 세션 제거
  - `UserToken` / `UserTokenStandby` INSERT/UPDATE로 사용 불가 처리
- **SQL**:
  ```sql
  SELECT * FROM UserToken WHERE `UserId` = ? AND `Unavailable` = FALSE;
  UPDATE UserToken SET `Unavailable` = TRUE, `Expired` = NOW() WHERE `TokenId` = ?;
  DELETE FROM `Authorization` WHERE principalName = ?;
  ```

### 8. POST `/webhooks/apple/server-notifications` (`AppleNotificationController.java:41`)

- Apple Sign-In 서버-투-서버 알림(JWS) 수신.
- `AppleEventTokenParser.parse(payload)`로 Apple JWK(`https://appleid.apple.com/auth/keys`)로 서명 검증 후 `AppleEventPayload` 획득.
- 이벤트 분기(`AppleNotificationController.java:82-108`): `email-disabled`, `email-enabled`, `consent-revoked`, `account-deleted`. 현재는 로그 + TODO.

### 9. GET `/api/v1/user-login-status` (`SessionController.kt:72`)

- `UserSessionService.getCurrentUserLoginStatus(request)` — 세션/RememberMe 쿠키를 기반으로 `LOGGED_IN`/`REMEMBER_ME_AUTO_LOGIN_POSSIBLE`/`NEED_LOGIN` 상태 반환. 다른 Wadiz 서비스(com.wadiz.web 등)가 cross-service 로그인 상태 동기화에 사용.

### 10. GET `/oauth2/authorize` + GET `/oauth2/callback/{provider}` — 소셜 로그인

- 진입: `WadizOAuth2AuthorizationRequestResolver`가 provider별 Authorization Request 생성(RememberMe 힌트 유지, `SecurityConfig.java:253-259`).
- 콜백: `WadizOAuth2UserService` / `WadizOidcUserService`가 Provider userinfo 조회 → `SocialAccount`(`KakaoAccount`, `NaverAccount`, `AppleAccount`, `GoogleAccount`, `FacebookAccount`, `LineAccount`)로 변환. 이미 `webpages_OAuthMembership`에 연결된 사용자면 `SocialAuthenticationSuccessHandler`가 로그인 완료, 없으면 `SocialAccount`를 HttpSession(Redis)에 임시 저장하고 `/social-signup` 또는 `/social-link`로 리다이렉트.

## DB 스키마 요약

> Wadiz Core DB는 레거시 .NET Wadiz 웹 시절의 테이블을 그대로 씀. 컬럼/테이블명을 유지하기 위해 `@Column(name="\`CamelCase\`")` 백틱을 엔티티 전반에 사용.

### 유저 원장 (`adapters/outbound/persistence/wadiz/user`)
- **`UserProfile`** (테이블 `UserProfile`) — 기본 프로필. 주요 컬럼: `UserId`(PK, IDENTITY), `UserName`(=email), `NickName`, `Grade`, `AccntType`(Enum `N1000` 등), `PhotoId`, `Birth`, `ValidMobileNumber`(Y/N 컨버터), `CallingCode`, `MobileNumber`, `ValidEmail`, `ValidEmailFirstCheck`, `AllowDM`, `JoinAuthType`, `UserStatus`(`NM/IA/RA/DO`), `WhenLastLogon`, `LanguageCode`, `CountryCode`. (`UserProfile.java:19-81`, `UserStatus.java`)
- **`Password`** (테이블 `webpages_Membership`) — `UserId`(PK), `Password`, `CreateDate`, `PasswordChangedDate`. (`Password.java:22-37`)
- **`UserProvider`** (테이블 `TbUserProvider` 추정) — 가입 경로/약관 출처.
- **`UserTokenEntity`** (테이블 `UserToken`) — `TokenId`(PK), `UserId`, `Unavailable`, `TokenValue`, `Expired`, `Registered`. `UserTokenStandbyEntity`와 1:1 (`UserTokenEntity.java:14-48`).
- **`UserDropOutLogEntity`** — 탈퇴 이력.
- **`UserRecordingEntity`** — 사용자 데이터 변경 이력 (userrecording 도메인).
- **`UserLocaleHistory`** — 언어/국가 변경 이력.
- **`LoginHistory`** (테이블 `LoginHis`) — `HisNo`(PK), `ClientType`, `UserId`, `SessionId`, `ReqDate`, `ReqIP`, `WaId` (`LoginHistory.java:15-33`).

### 소셜 (`persistence/wadiz/socialuser`)
- **`SocialUser`** (테이블 `webpages_OAuthMembership`, 복합키 `Provider`+`ProviderUserId`) — Provider-Wadiz UserId 매핑. `Token`, `RefreshToken`, `Registered`, `Updated` (`SocialUser.java:19-46`).
- **`ProviderProfile`** (테이블 `TbProviderProfile`, PK `userId`) — `provider`, `gender`, `birthday`, `birthyear`, `friendscount`, `created`, `updated` (`ProviderProfile.java:19-71`).
- **`ProviderProfileLog`**, **`ProviderScope`**(복합키) — 소셜 프로필 변경 이력 + Provider scope 기록.
- Provider별 Repository: `KakaoAccountRepository`, `NaverAccountRepository`, `FacebookAccountRepository`, `LineAccountRepository` + `SocialAccountRepositoryMap`(provider → repo 매핑).

### 마케팅 / 쿠폰 / 기타 (`persistence/wadiz/*`)
- `MarketingAgreementEntity`, `MarketingAgreementHistoryEntity`, `MarketingParticipationHistoryEntity`
- `RecommendJoinEventEntity` (추천인 가입 이벤트, 복합키 `RecommendJoinEventEntityId`)
- `PhotoEntity` (프로필 사진)

### IAM / OAuth2 Authorization Server (`persistence/iam`)
- **`Client`** (테이블 `RegisteredClient`) — PK `id`, `clientId`, `clientIdIssuedAt`, `clientSecret`(+ `clientSecretExpiresAt`), `clientName`, `clientAuthenticationMethods`(쉼표 구분), `authorizationGrantTypes`, `redirectUris`, `scopes`, `clientSettings`(JSON, length 2000), `tokenSettings`(JSON), `postLogoutRedirectUris`. (`Client.java:16-38`)
- **`Authorization`** (테이블 `Authorization`) — PK `id`, `registeredClientId`, `principalName`, `authorizationGrantType`, `authorizedScopes`(BLOB), `attributes`(BLOB), `state`. Code/Access/Refresh/OIDC ID Token/DeviceCode/UserCode 각각 `value(BLOB) / issuedAt / expiresAt / metadata(BLOB)` 컬럼군(`Authorization.java:19-85`).
- **`AuthorizationConsent`** (테이블 `AuthorizationConsent`, 복합키 `registeredClientId`+`principalName`) — `authorities`(쉼표 분리) (`AuthorizationConsent.java:11-42`).

### Redis (`persistence/redis/*`)
- **`EmailValidationCodeEntity`** (`emailvalidationcode/`) — 이메일 인증코드 (key = sessionId, TTL).
- **`PasswordResetTokenEntity`** (`passwordreset/`) — 비밀번호 재설정 토큰 (TTL).
- **`HttpSessionSocialAccountRepository`** — 소셜 가입·연결 플로우에서 `SocialAccount`를 HttpSession에 임시 보관.

### DataSource 구성 (`application/config/*`)
- `DatasourceConfig` + `WadizDbJpaConfig`(Wadiz DB) + `IamDbJpaConfig`(IAM DB) — 멀티 데이터소스 분리.
- Hibernate naming: `CamelCaseToUnderscoresNamingStrategy` 전역 지정이지만, 엔티티별 `@Column(name="\`CamelCase\`")`로 원래 케이스를 보존.
- HikariCP `maximum-pool-size: 10`, JPA statement cache 활성(`application.yml:254-266`).

## 외부 의존성

모든 외부 서비스는 Spring Cloud OpenFeign + OkHttp로 호출. 공통 설정은 `application/FeignConfig.java`(타임아웃 5s, Full 로깅).

| 어댑터 패키지 | FeignClient | Base URL | 용도 |
|---|---|---|---|
| `externalservice/alimtalk` | `AlimTalkClient` | `${wadiz.api.alim-talk.base-url}/alimtalk` | **카카오 알림톡** 발송(회원 이벤트·가입 완료 안내 등). Bearer 토큰 필요 (`AlimTalkClient.java:11`). |
| `externalservice/crmgateway` | `CrmGatewayClient` | `${wadiz.api.braze}` | **Braze(CRM) 게이트웨이**: `PUT /setUnsubscribeKey`(구독 해제 키), `PUT /users/track`(회원 속성 동기화) (`CrmGatewayClient.java:11-15`). |
| `externalservice/kakao` | `KakaoClient`, `KakaoAuthClient` | `https://kapi.kakao.com` / `https://kauth.kakao.com` | **Kakao Open API**: `/v2/user/service_terms`, `/v2/user/scopes` 조회(가입시 동의 정보 수집) (`KakaoClient.java:11-18`). |
| `externalservice/fastmail2` | `FastMailClient`(`/api/v2/send`), `NormalMailClient`(`/api/v3/send`) | `${wadiz.api.mail.fast.path}`, `${wadiz.api.mail.normal.path}` | **사내 메일 플랫폼**. FastMail은 인증코드·비번재설정·보안 경고 등 즉시 발송, NormalMail은 템플릿 기반(회원가입 축하 메일 템플릿ID `1482`) (`FastMailClient.java`, `NormalMailClient.java`). |
| `externalservice/notification` | `NotificationClient` | `${wadiz.api.notification}` | 메일 송신 API(`POST /mails/send/priority/fast`), **Publish/Subscribe 알림**(`POST /publishes/subscribers/{subscriberKey}`, `GET /publishes/{transactionKey}`, `GET /inboxes/{subscriberKey}/transactions/{transactionKey}`, `POST /publishes/groups/{subscriberGroupKey}`) (`NotificationClient.java:13-27`). |
| `externalservice/push2` | `Push2Client` | `${wadiz.api.push2}` | **푸시 알림 & 인박스** 서비스 v2 (`POST /user`, `POST /inbox`). 회원 가입 완료/보안 이벤트 푸시·인박스 (`Push2Client.java:9-13`). |
| `externalservice/subscribenotification` | `SubscribeNotificationClient` | 구독 알림 플랫폼 | 회원 가입 시 기본 구독 topic 등록 (푸시/메일 구독 키 관리). `UserToSubscriberRequestConverter.java`로 DTO 변환. |
| `externalservice/terms` | `TermsClient` | `${wadiz.api.terms}` | **약관 서비스**: `POST /accepter/{userId}` 동의 저장, `GET /accepter/{userId}` 조회 (`TermsClient.java:14-19`). |
| `externalservice/usercoupon` | `UserCouponClient` | `${wadiz.api.user-coupon.base-url}` | **쿠폰 서비스**: `POST /user/{userId}/type/{couponType}`로 가입 축하 쿠폰 발급. Country/Language 헤더 전송 (`UserCouponClient.java:12-17`). |
| `externalservice/user` | `UserClient`, `UserApiAdapter`, `UserAppContactApiAdapter` | `${wadiz.api.users}` | **User 도메인 서비스**: 약관 조회/저장(`/terms/accepter/{userId}`), 연락처 재연결(`PUT /contacts/{userId}/my-number/reconnection`), 타임존 업데이트(`PUT /{userId}/time-zone/by-country`) (`UserClient.java:15-25`). |
| `externalservice/platform` | `MarketingConsentClient` | 플랫폼 API | 채널별 마케팅 동의 동기화(EMAIL/SMS/PUSH, `ChannelType`, `MarketingConsentAdapter.java`). |
| `externalservice/datasvc` | `DataClient` (Kotlin) | Data 서비스 | IP 기반 국가 매핑(`IpDto`, `CountryDto`, `DataServiceAdapter.kt`). |

### 외부 OAuth2 Provider (`application.yml:54-134`)
- **Kakao**, **Naver**, **Apple**(Sign in with Apple, client-secret JWT 90일 주기 자동 교체 `wadiz.scheduler.cron.change-apple-security-token`), **LINE**(HS256 토큰 → 전용 decoder), **Google**, **Facebook**.

### 인프라
- **MySQL** × 2 (`wadiz` = 회원 원장, `iam` = 인가서버 전용)
- **Redis** (세션 + 인증코드 + 패스워드 리셋 토큰 + 로그인 시도 락)
- **Kubernetes** (`bootstrap-kubernetes.yml`, `spring-cloud-starter-kubernetes-client-config`)
- **Jasypt** (DB/Feign 시크릿 암호화)
- **Jenkins** 파이프라인 (dev/rc/rc2/rc3/stage/live + backup — 6+ 환경 분리)
- **이미지**: `wadiz/kr.wadiz.account:${version}` (`bootBuildImage`)

## 특이사항

1. **Hexagonal 준수**: `adapters.inbound`는 HTTP 진입, `adapters.outbound.persistence`는 DB, `adapters.outbound.externalservice`는 외부 API, `domain`은 순수 자바, `application`은 Spring Security/Config 및 `applicationservice`. 포트는 `port.inbound`(UseCase)와 `port.outbound`(Repo/Feign 추상)로 분리. 내부 호출 가능한 `adapters.outbound.internalservice` 패키지도 존재.
2. **Kotlin/Java 혼용**: 대부분 Java. 일부 컨트롤러(`IdPasswordManagementController.kt`, `SessionController.kt`), Fast/Normal mail DTO, `WadizOidcLogoutAuthenticationConverter.kt`, `common/Request.kt`가 Kotlin data class.
3. **OAuth2 엔드포인트 경로 리맵**: Spring 기본(`/oauth2/authorize`, `/oauth2/token`, …)을 `/oauth/*`로 재매핑. 와디즈 레거시 호환 때문(`SecurityConfig.java:268-278`). 동시에 `/oauth2/authorize`는 **외부 Provider 소셜 로그인**용으로 재사용(서로 다른 필터 체인).
4. **Custom grant**: Spring 3.x에서 제거된 `password` grant를 Wadiz용으로 재구현(`OAuth2CustomWadizAuthenticationProvider`). 모바일 앱이 이메일/비밀번호로 직접 토큰을 받는 플로우 유지.
5. **JWK 키 고정**: JWKSet은 `keystore/oauth-keystore.jks` (`oauth2.0` alias, 비밀번호 `oauth-pass`)에서 매 기동 시 RSA 키 로드. `keyId`는 `wadiz.jwkset.keyId` 프로퍼티에서 주입.
6. **LINE OIDC**: `jwk-set-uri`는 있지만 실제 ID Token이 HS256이라 `LineIdTokenDecoder`로 별도 서명 검증(`SecurityConfig.java:413-430`).
7. **Apple 지원**: client-secret JWT 자동 재발급(매월 1일 02:00 `wadiz.scheduler.cron.change-apple-security-token`), `/webhooks/apple/server-notifications`로 계정 삭제·이메일 변경 이벤트 수신. `wadiz.oauth.apple.client-secret-expiration-days: 90`.
8. **로그인 시도 제한**: `LoginTryLimiter` + Redis로 N회 실패 시 잠금 → `WadizTooManyLoginErrorAuthenticationException` (`WadizAuthenticationProvider.java:56-71`). 계정 단위 키, 실패 시 만료 시간 연장.
9. **패스워드 해시**: 레거시 .NET Identity의 `Rfc2898DeriveBytes`(PBKDF2) 호환 구현(`persistence/wadiz/user/util/Rfc2898DeriveBytes.java`, `WadizPassWordUtils.java`) — 과거 ASP.NET 계정도 그대로 로그인 가능.
10. **세션 공유**: Spring Session Redis(`namespace: account`, `repository-type: indexed`)로 Account 서버와 다른 Wadiz 서비스가 `user-login-status` API로 세션 상태를 조회.
11. **RememberMe**: `WadizPersistentTokenBasedRememberMeServices` 커스터마이징. `SessionController`가 RememberMe 쿠키 유효성·정리 API를 x-api-key 기반으로 별도 제공 → 내부 서비스(com.wadiz.web 등)에서 호출.
12. **OIDC Logout 커스터마이징**: `WadizOidcLogoutAuthenticationConverter` + `WadizOidcLogoutAuthenticationProvider` + `WadizOidcLogoutHandler`가 기본 `OidcLogoutAuthenticationProvider` 앞에 위치해 RememberMe까지 삭제하고 동의된 redirect로 이동(`SecurityConfig.java:119-137`).
13. **`TbProviderProfile` 차등 업데이트**: `ProviderProfile.updateWith`로 변경 필드만 갱신하는 도메인 메서드(`ProviderProfile.java:49-66`).
14. **스케줄 작업** (`application.yml:213-218`):
    - `remove-expired-token`: 매일 02:00 만료 `UserToken` 삭제
    - `change-apple-security-token`: 매월 1일 02:00 Apple client-secret JWT 재발급
    - `remove-expired-authorization-code`: 매일 02:30 `Authorization` 테이블 만료 레코드 정리
    - `cleanup-dropped-user-data`: 매일 01:00 탈퇴(DO) 회원 데이터 정리
    - `wadiz.authorization.deletion.cron.expression`: 랜덤 시간에 추가 정리(`application.yml:212`)
15. **배포 브랜치 다분화**: `Jenkinsfile_account_dev/rc/rc2/rc3/stage/live` + `backup` 등 6개 이상 환경을 분리 운영. `application-{profile}.yml`도 환경별 존재.
16. **테스트 러너**: Spock(그루비) + Kotlintest(Kotlin) + MockK + `testcontainers:spock` 혼용(`build.gradle:128-138`).
17. **`webpages_*` 테이블명**: 과거 .NET Wadiz 웹페이지에서 물려받은 테이블(`webpages_Membership`, `webpages_OAuthMembership`). Hibernate naming strategy 우회를 위해 엔티티에 `@Column(name = "\`...\`")` 백틱을 전반적으로 사용.
18. **도메인 이벤트 + ApplicationEventPublisher**: 회원 가입·연결 시 `UserCreatedEvent` 등을 발행 → 리스너들이 약관(`TermsAdapter`), CRM(`CrmGatewayAdapter`), 쿠폰(`UserCouponAdapter`), 푸시/알림(`Push2Adapter`, `NotificationAdapterV2`), 구독알림(`SubscribeNotificationAdapter`) 후처리. 실패 시 로그만 남기고 원 트랜잭션은 계속 진행(`SignUpController.java:94-102`, `CreateUserApplicationService.java:67-70`).
19. **JPA는 `ddl-auto=none` + `generate-ddl=false`**. 테이블 생성은 `schema/*`, `migration/*` 디렉터리 SQL/스크립트로 관리(Autoconf 도구로 변경 이력 생성 `autoconf.txt`).
20. **BLOB 사용**: `Authorization` 테이블이 MySQL BLOB을 대량 사용(토큰 원본/메타데이터). `Client.clientSettings`/`tokenSettings`는 JSON length 2000.
