# kr.wadiz.account — API 엔드포인트 전수 목록

> 소스 기준: 12개 inbound Controller (`src/main/java/kr/wadiz/oauth2/adapters/inbound/`). **커스텀 엔드포인트만 나열**, Spring Security OAuth2 Authorization Server가 제공하는 표준 엔드포인트(`/oauth2/authorize`, `/oauth2/token`, `/oauth2/revoke`, `/oauth2/jwks`, `/userinfo`, `/.well-known/*`)는 **표준 섹션** 에 별도 기재.
> 도메인별 상세: `api-details/*.md`.

---

## Spring Security OAuth2 표준 엔드포인트 (프레임워크 제공)

`application/config/SecurityConfig` 에서 활성화. (상세: [`api-details/oauth2-auth-core.md`](./api-details/oauth2-auth-core.md))

| Method | Path | 프레임워크 구현 | 용도 |
|---|---|---|---|
| GET | `/oauth2/authorize` | OAuth2AuthorizationEndpointFilter | 인가 요청 |
| POST | `/oauth2/token` | OAuth2TokenEndpointFilter | 토큰 발급 (access/refresh) |
| POST | `/oauth2/revoke` | OAuth2TokenRevocationEndpointFilter | 토큰 폐기 |
| GET | `/oauth2/jwks` | OAuth2TokenIntrospectionEndpointFilter | JWK Set |
| GET | `/userinfo` | OidcUserInfoEndpointFilter | OIDC userinfo |
| GET | `/.well-known/openid-configuration` | OidcConfigurationEndpointFilter | OIDC discovery |
| GET | `/.well-known/oauth-authorization-server` | OAuth2 discovery | Authorization server metadata |

---

## 1. Main View (Thymeleaf 페이지)
**상세**: [`api-details/inbound-controllers.md#main`](./api-details/inbound-controllers.md)

### MainController (`adapters/inbound/MainController.java:44`)
base: `/` — 로그인·회원가입 페이지 렌더링

| Method | Path | 용도 |
|---|---|---|
| GET | `/` | 루트 (리다이렉트) |
| GET | `/login` | 로그인 페이지 |
| GET | `/signup` | 회원가입 페이지 |
| GET | `/social-signup` | 소셜 가입 페이지 |
| GET | `/social-link` | 소셜 연동 페이지 |
| GET | (multi paths) | 추가 페이지 |

### CallbackController (`adapters/inbound/CallbackController.java:37`)
base: `/`

| Method | Path | 용도 |
|---|---|---|
| GET | `/v0/oauth2/callback` | 레거시 OAuth 콜백 |
| GET | `/test_page` | 테스트 페이지 |

### MaintenanceController (`adapters/inbound/MaintenanceController.java`)
base: (class-level 미지정, 메서드 path-level)

| Method | Path | 용도 |
|---|---|---|
| GET | `info` | 점검 정보 |
| GET | `info/{fileName}` | 점검 파일 |

---

## 2. Signup · Link · IdPassword (회원 관리)
**상세**: [`api-details/inbound-controllers.md`](./api-details/inbound-controllers.md)

### SignUpController (`adapters/inbound/SignUpController.java:59`)
base: `/api/v1`

| Method | Path | 용도 |
|---|---|---|
| POST | `/users` | 신규 가입 |
| POST | `/social-users` | 소셜 가입 |
| GET | `/signup-information` | 가입 필요 정보 조회 |

### LinkController (`adapters/inbound/LinkController.java:43`)
base: `/api/v1`

| Method | Path | 용도 |
|---|---|---|
| POST | `/link-users` | 기존 계정에 소셜 연동 |

### IdPasswordManagementController (`adapters/inbound/IdPasswordManagementController.kt:24`)
base: `/api/v1`

| Method | Path | 용도 |
|---|---|---|
| POST | `/find-id` | 아이디 찾기 |
| POST | `/password-reset/request` | 비밀번호 재설정 요청 |
| POST | `/password-reset/confirm` | 재설정 확정 |

---

## 3. Session (세션 관리)
**상세**: [`api-details/inbound-controllers.md#session`](./api-details/inbound-controllers.md)

### SessionController (`adapters/inbound/SessionController.kt:21`)
base: `/api/v1`

| Method | Path | 용도 |
|---|---|---|
| POST | `cookie/validity` | 쿠키 유효성 |
| DELETE | `users/{userId}/sessions` | 유저 세션 강제 종료 |
| DELETE | `/sessions` | 현재 세션 종료 |
| GET | `/user-login-status` | 로그인 상태 |

---

## 4. AuthenticationCode (인증 코드 V1/V2)
**상세**: [`api-details/inbound-controllers.md#authcode`](./api-details/inbound-controllers.md), [`api-details/oauth2-auth-core.md`](./api-details/oauth2-auth-core.md)

### AuthenticationCodeV1Controller (`adapters/inbound/AuthenticationCodeV1Controller.java:21`)
base: `/api/v1`

| Method | Path | 용도 |
|---|---|---|
| POST | `/authentication-code` | V1 인증 코드 발급 |
| GET | `/authentication-code/{code}/valid` | V1 유효성 검증 |

### AuthenticationCodeV2Controller (`adapters/inbound/AuthenticationCodeV2Controller.java:21`)
base: `/api/v2`

| Method | Path | 용도 |
|---|---|---|
| POST | `/authentication-code` | V2 발급 |
| GET | `/authentication-code/{code}/valid` | V2 검증 |

---

## 5. Error Code (오류 코드 노출)

### ErrorCodeController (`adapters/inbound/ErrorCodeController.java:17`)
base: `/api/v1`

| Method | Path | 용도 |
|---|---|---|
| GET | `/error-codes` | 등록된 오류 코드 전체 조회 |

---

## 6. Apple Notification (Webhook)
**상세**: [`api-details/inbound-controllers.md#apple`](./api-details/inbound-controllers.md)

### AppleNotificationController (`adapters/inbound/AppleNotificationController.java:29`)
base: `/webhooks/apple`

| Method | Path | 용도 |
|---|---|---|
| POST | `/server-notifications` | Apple Server-to-Server notification (구독 변경 등) |

---

## 7. Kakao Social 진입
**상세**: [`api-details/oauth2-auth-core.md`](./api-details/oauth2-auth-core.md)

### KakaoOAuth2AuthorizationRequestRegisterController (`application/authentication/social/kakao/KakaoOAuth2AuthorizationRequestRegisterController.kt`)
카카오 OAuth2 인가 요청 생성기 — Spring Security oauth2-client 연동용 커스텀 엔드포인트. (정확한 경로는 상세 문서 참조)

---

## 통계

| 도메인 | 컨트롤러 | 커스텀 엔드포인트 (약) | 상세 파일 |
|---|---|---|---|
| Main View | 1 | 6+ | inbound-controllers.md |
| Callback/Maintenance | 2 | 4 | inbound-controllers.md |
| Signup/Link/IdPassword | 3 | 7 | inbound-controllers.md |
| Session | 1 | 4 | inbound-controllers.md |
| AuthCode V1/V2 | 2 | 4 | inbound-controllers.md |
| ErrorCode | 1 | 1 | inbound-controllers.md |
| Apple Webhook | 1 | 1 | inbound-controllers.md |
| Kakao Social | 1 | (커스텀) | oauth2-auth-core.md |
| **커스텀 합계** | **12** | **≈27** | — |
| (+ Spring Security 표준) | — | 7 | oauth2-auth-core.md |

**추가 관점**:
- 도메인 모델 상세 → [`api-details/domain-model.md`](./api-details/domain-model.md)
- DB (wadiz/iam/redis) 스키마 → [`api-details/persistence.md`](./api-details/persistence.md)
- 외부 서비스 11종 → [`api-details/external-services.md`](./api-details/external-services.md)
