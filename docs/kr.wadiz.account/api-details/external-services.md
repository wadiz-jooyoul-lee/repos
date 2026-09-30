# kr.wadiz.account — Outbound Externalservice Adapters

> 📅 **2026-09-30 본문 전면 점검** — `cloud_live` 브랜치 `b42a8e7f`(2026-09-21) 기준
>
> 직전 본문 점검 이후 **`BE3-555`(2026-06-26, `f7d832ac`) 하나가 이 문서의 절반을 낡게 만들었습니다.**
> 커밋 제목이 "user-api 클라이언트 통합 및 wadiz.api 외부서비스 설정 일관화" 입니다.
>
> | 고친 곳 | 예전 | 지금 |
> |---|---|---|
> | `notification/` 어댑터 | 11개 파일 | **패키지 통째로 삭제** |
> | `platform/` 어댑터 | 있음 | **`notichannel/` 로 이름 바뀜** (`BE3-457`, 2026-06-30) |
> | `terms/TermsClient.java` | 있음 | 삭제. 쓰기가 `TermsPort` 로 일원화 |
> | `user/TermsApiAdapter.java`·`TermsApiPort` | 있음 | 삭제 |
> | `usercoupon/UserCouponClient.java` | 있음 | 삭제. `UserClient` 로 통합 |
> | FeignClient | 13개 | **12개** |
> | 설정 키 이름 | `wadiz.api.users`·`braze`·`marketing-consent` 등 | **서비스 이름으로 통일** |
> | 환경 주소 | `dev-app01:9990`·`172.31.1.12:9990` | **`api.dev.wadiz.io/{서비스}`** |
>
> **이 문서가 예전에 한 예측이 맞았습니다.**
> 3.6 절이 `notification/` 을 "호출 지점 없음, dead code 상태"라고 적어 뒀는데,
> 실제로 `BE3-555` 커밋 메시지가 *"notification 패키지 전체(IAM-3399 NotificationAdapter 리팩토링으로 고아화)"* 라며 지웠습니다.
>
> ⚠️ **`application-dev.yml` 과 `application-live.yml` 이 사라졌습니다.**
> `BE3-410`(2026-05-28, `ec729cf5`)이 지웠습니다. 커밋 제목이 "application yml 환경별 설정 분리 및 local 시크릿 env var 외부화" 입니다.
> 지금 저장소에 남은 프로파일 파일은 `local`·`rc`·`rc2`·`rc3`·`test` 다섯입니다.
> **클라우드 환경(`cdev`·`clive`) 값은 저장소에 없고 쿠버네티스 설정맵에 있습니다.**
> 그래서 아래 URL 표는 `application-local.yml` 과 `application-rc.yml` 기준으로 다시 썼습니다.

## 1. 기록 범위

- **대상**: `src/main/java/kr/wadiz/oauth2/adapters/outbound/externalservice/` 아래 11개 어댑터 디렉터리 (실제로 하위 디렉터리 수는 12 — `user/` 안에 3개 어댑터가 혼재).
- **포함**:
  - OpenFeign 클라이언트 인터페이스 (`@FeignClient`) — HTTP path, method, header, body 시그니처.
  - Adapter 구현체 — Port 매핑, 인증 헤더 조립, 예외 처리, 비동기/동기 여부.
  - 요청/응답 DTO — 관측 가능한 필드.
  - 호출 시점 — 실제로 Port 를 주입받아 호출하는 UseCase (`kr.wadiz.oauth2.domain.applicationservice.*`, `kr.wadiz.oauth2.application.*`).
- **제외**:
  - 각 외부 서비스의 내부 로직 (상대 서버가 DB 에 어떻게 저장하는지, Braze/Kakao 내부 동작).
  - Spring Security OAuth2 Client 자체의 토큰 획득 흐름 (Kakao/Naver/Apple 로그인 Provider) — 이는 `WebSecurityConfig` / `ClientRegistrationRepository` 쪽이고 본 문서는 **로그인 이후** outbound 호출만 다룬다.
  - `security.oauth2.client.*` 로 공급되는 Google/Facebook/Line/Apple provider — 외부 IDP 이므로 제외 (KakaoPort 는 카카오 IDP 와는 별개로 `/v2/user/*` 를 호출하므로 포함).
  - 테스트 (`src/test/groovy/.../externalservice/`).
- **인용 규칙**: 모든 HTTP path 와 DTO 필드는 소스의 `경로:줄번호` 를 함께 적습니다.
  URL 값은 `application-local.yml`(클라우드 개발 인프라)과 `application-rc.yml`(사내 온프렘)의 실제 값을 씁니다.
  예전에 쓰던 `application-dev.yml`·`application-live.yml` 은 2026-05-28 에 삭제됐습니다.
- **분석 대상 파일 요약**:
  - Adapter **13개**, FeignClient **12개**, 외부서비스 폴더 **11개**.
  - `kr.wadiz.oauth2.port.outbound` 아래 Port 인터페이스 **20개** (저장소 Port 포함). 여기에 `kr.wadiz.oauth2.domain.terms.TermsPort` 가 더해집니다.
  - `UserClient` 하나를 **`UserApiAdapter`·`UserAppContactApiAdapter`·`TermsAdapter`·`UserCouponAdapter` 넷이 공유**합니다.

---

## 2. 개요

### 2.1 account 가 외부 서비스에 의존하는 이유

`kr.wadiz.account` 는 와디즈 OAuth2 Authorization Server + 통합 회원 시스템이다 (`AuthorizationServiceApplication.java:19`, `@SpringBootApplication` + `@EnableFeignClients`). **회원 가입·로그인·약관 동의** 라이프사이클 자체는 account 가 소유하지만, 부수적인 "회원 생성시 일어나는 일" 들은 전부 사내 외부 서비스가 소유한다:

| 목적 | 담당 서비스 | account 의 Port |
|---|---|---|
| 발송 채널 구독 등록 (app/phone/mail) | `subscribenotification` (platform) | `SubscribeNotificationPort` |
| 마케팅 수신 동의 설정 | `platform /noti-channel` | `MarketingConsentPort` |
| CRM (Braze) unsubscribe key + 사용자 속성 | `crmgateway` | `CrmPort` |
| 회원가입 축하 쿠폰 발급 | `com.wadiz.api.reward` (user-coupon) | `UserCouponPort` |
| 약관 동의 저장 | legacy `terms` 서비스 + `wave.user` | `TermsPort`, `TermsApiPort` |
| 사용자 프로필/연락처/타임존 갱신 | `wave.user` | `UserApiPort`, `UserAppContactApiPort` |
| 이메일 발송 (welcome, 인증코드, 비밀번호 재설정) | `fastmail2` / `mail-normal` | `NotificationPort` |
| 알림톡 발송 (회원가입 알림톡) | `alim-talk` (platform) | `AlimTalkPort` |
| 푸시 + 인박스 (카카오 연결 축하) | `push2` | `Push2Port` |
| IP → 국가코드 (LocaleResolver) | `datasvc` | `GetCountryFromIPPort` |
| Kakao 추가 권한/토큰 재발급 | Kakao Open API | `KakaoPort` |

~~`notification/NotificationClient.java`~~ 는 **2026-06-26 에 패키지째 삭제됐습니다**(`BE3-555`).
예전 문서가 "호출하는 Adapter 가 없다"고 짚어 둔 그대로였습니다. 3.6 절을 봅니다.

### 2.2 Port/Adapter 인터페이스 구조

Hexagonal 패턴을 따른다. **outbound port** 는 `port/outbound/` 에, 해당 구현은 `adapters/outbound/externalservice/<service>/` 에 위치하며 Spring `@Component`/`@Service` 로 등록된다.

```
kr.wadiz.oauth2
├── port.outbound
│   ├── AlimTalkPort, CrmPort, GetCountryFromIPPort, KakaoPort,
│   ├── MarketingConsentPort, NotificationPort, Push2Port,
│   ├── SubscribeNotificationPort, TermsApiPort, UserApiPort,
│   ├── UserAppContactApiPort, UserCouponPort
│   └── DomainCode (enum)
├── domain.terms.TermsPort                    // 한 개만 예외적으로 domain 아래
└── adapters.outbound.externalservice
    ├── alimtalk/          → AlimTalkAdapter      implements AlimTalkPort
    ├── crmgateway/        → CrmGatewayAdapter    implements CrmPort
    ├── datasvc/           → DataServiceAdapter   implements GetCountryFromIPPort
    ├── fastmail2/         → NotificationAdapterV2 implements NotificationPort
    ├── kakao/             → KakaoAdapter         implements KakaoPort
    ├── notification/      → (클라이언트만, 현재 adapter 미사용)
    ├── platform/          → MarketingConsentAdapter implements MarketingConsentPort
    ├── push2/             → Push2Adapter         implements Push2Port
    ├── subscribenotification/ → SubscribeNotificationAdapter implements SubscribeNotificationPort
    ├── terms/             → TermsAdapter         implements TermsPort
    ├── user/              → UserApiAdapter, TermsApiAdapter, UserAppContactApiAdapter
    └── usercoupon/        → UserCouponAdapter    implements UserCouponPort
```

Feign 공통 설정은 `kr.wadiz.oauth2.application.FeignConfig` 에서 로깅 레벨 `FULL` 만 정의 (`FeignConfig.java:9-12`). 공통 `RequestInterceptor` 는 없다 — 인증 헤더는 각 Adapter 가 수동으로 `Bearer <token>` 문자열을 생성해 `@RequestHeader("Authorization")` 파라미터로 전달한다.

`AuthorizationServiceApplication.java:13` 에 `@EnableFeignClients` 만 있으므로 basePackage 제한이 없고, `kr.wadiz` 루트 하위의 모든 `@FeignClient` 를 스캔한다.

### 2.3 공통 관찰

- **클라이언트 구현 기술**: 13개 모두 Spring Cloud OpenFeign 기반. RestClient / WebClient / RestTemplate 사용한 outbound adapter 는 externalservice 디렉터리에 없음.
- **인증 방식**:
  - 대부분 내부 서비스 → `Bearer <static token>` (`@Value` 로 yml 에서 주입).
  - `usercoupon` 은 `Authorization` 헤더 없이 `wadiz-country`, `wadiz-language` 헤더만 사용 (`UserCouponClient.java:15-16`, `WadizHttpHeaders.java:4-5`) — 내부망 IP 기반 신뢰로 추정.
  - `user`, `terms`, `notification`, `crmgateway` 도 `Authorization` 파라미터가 없음 — 역시 내부망 기반.
  - Kakao 는 외부 공개 API 이므로 유저 `access_token` 혹은 `KakaoAK <adminkey>` 사용.
- **mTLS 는 없음**. 모든 호출은 평문 Bearer 토큰 혹은 무인증 내부 HTTP.
- **JWT propagation 은 없음**. 사용자 JWT 를 downstream 에 전달하는 adapter 는 0개 (account 는 본인이 Authorization Server 이므로 스스로 발급한 사용자 토큰을 재사용하지 않음).

### 2.4 URL 설정 총괄

외부 서비스 주소는 `application-{프로파일}.yml` 의 `wadiz.api.*` 아래에 있습니다.

**`BE3-555` 가 설정 키 이름을 서비스 이름으로 통일했습니다.**
커밋 메시지가 이렇게 적고 있습니다 —
*"wadiz.api 키를 commonConfig 서비스명(-api 제외)으로 통일: user/crm-gateway/notification/noti-channel/push/datasvc/alimtalk/mail-fast/mail-normal"*.

| 설정 키 | FeignClient name | local (클라우드 개발) | rc (사내 온프렘) |
|---|---|---|---|
| `wadiz.api.user.base-url` | `wadiz-user-service`, `wadiz-terms-query-service` | `https://api.dev.wadiz.io/user` | `http://rc-api01:9990` |
| `wadiz.api.crm-gateway.base-url` | `braze-service` | `https://api.dev.wadiz.io/crm-gateway` | `http://rc-api01:9990/crmgateway` |
| `wadiz.api.notification.base-url` | `subsciber-client` | `https://api.dev.wadiz.io/notification` | `http://rc-api01:9990/notification` |
| `wadiz.api.noti-channel.base-url` | `noti-channel-client` | `https://api.dev.wadiz.io/noti-channel` | `https://rc-platform.wadizcorp.net/noti-channel` |
| `wadiz.api.push.base-url` | `push2-api-client` | `https://api.dev.wadiz.io/push` | `https://rc-platform.wadizcorp.net/push` |
| `wadiz.api.mail-fast.base-url` | `fast-mail-client` | `https://api.dev.wadiz.io/mail-fast` | (rc 미정의) |
| `wadiz.api.mail-normal.base-url` | `normal-mail-client` | `https://api.dev.wadiz.io/mail-normal` | (rc 미정의) |
| `wadiz.api.alimtalk.base-url` | `alim-talk-service` | `https://api.dev.wadiz.io/alimtalk` | `https://rc-platform.wadizcorp.net/alimtalk` |
| `wadiz.api.datasvc.base-url` | `data-client2` | `https://datasvc.dev.aidata.wadiz.io` | `https://rc-datasvc.wadiz.kr` |
| — (코드에 직접 씀) | `kakao-service` | `https://kapi.kakao.com` | 동일 |
| — (코드에 직접 씀) | `kakao-auth-service` | `https://kauth.kakao.com` | 동일 |

**`BE3-555` 가 Feign 경로 규칙도 통일했습니다.**
커밋 메시지의 표현은 *"base-url=서비스 루트, `@FeignClient(path)`=`/api/v{N}`(버전까지), 메서드=리소스+액션"* 입니다.
버전이 없는 서비스는 `path` 를 붙이지 않습니다.

| FeignClient | `path` |
|---|---|
| `wadiz-user-service` · `braze-service` · `push2-api-client` · `subsciber-client` | `/api/v1` |
| `alim-talk-service` · `fast-mail-client` | `/api/v2` |
| `normal-mail-client` | `/api/v3` |
| `data-client2` | `/global/v1` |
| `wadiz-terms-query-service` · `noti-channel-client` · 카카오 2종 | 없음 |

**확인된 것 세 가지**

| 관찰 | 내용 |
|---|---|
| 클라우드는 게이트웨이 한 곳으로 모임 | 사내 서비스 호출이 전부 `api.dev.wadiz.io/{서비스}` 를 지납니다. 예전의 `dev-app01:9990` 직접 호출이 사라졌습니다 |
| 온프렘은 갈래가 둘 | 사내 서비스는 `rc-api01:9990`, 플랫폼 서비스는 `rc-platform.wadizcorp.net` 입니다 |
| rc 에 메일 설정이 없음 | `mail-fast`·`mail-normal` 키가 `application-rc.yml` 에 없습니다. **확인 필요**입니다 |

> `subsciber-client` 는 이름에 오타가 있습니다(`subscriber` 가 맞습니다). 코드 원문 그대로입니다.
>
> `wadiz.api.datasvc` 의 `token` 값이 `application-rc.yml` 에 **평문으로 적혀 있습니다.**
> 값은 이 문서에 옮기지 않았습니다. 원본 저장소는 읽기 전용이라 기록만 남깁니다.

---

### 2.5 회원가입 → outbound 호출 순서

`AbstractCreateUserService.signUp()` (`AbstractCreateUserService.java:29-39`) 은 템플릿 메서드 패턴으로 다음 순서를 강제한다:

```
signUp(cmd, device, locale)
├── createUser()                                 # abstract; UserRepositoryPort 로 DB insert
│   └── userAppContactApiPort.asyncReconnectContactsByMyMobileNumber()   # @Async (UserApp/contacts)
├── saveTerms()                                  # termsPort.acceptTerms() (terms/)
├── registerNotification()                       # subscribeNotificationPort.registerNotification()
│                                                #   → platformApiPort.updateMarketingConsent() × 동의서비스수
├── registerUnsubscribeKeyForBraze()             # crmPort.setUnsubscribeKey()
└── giveAwaySignupCouponsAndNotifyCRM()          # (locale 조건부) userCouponPort.giveAwaySignupCoupons()
                                                 # crmPort.sendSignUpInformationWithCoupon()
```

이후:

- `CreateUserApplicationService.signUpWithEmail` — `signUp()` 끝에 `UserCreatedEvent` publish → `EmailService.handleEvent` (Async listener) → `sendSignUpCelebrationMail` → fastmail2 NormalMail 발송 (`CreateUserApplicationService.java:62-71`, `EmailService.java:89-99`).
- `CreateUserWithSocialAccountApplicationService.doRemainingWork(user)` — `@Async`, kakao 연결이면 `sendAlarmForKakaoLink` → push2, 모바일 번호 있으면 `alimTalkPort.sendSignUpNotificationTo` (`CreateUserWithSocialAccountApplicationService.java:93-105`).
- `updateUserTimeZone(savedUser)` — `userApiPort.updateUserTimeZoneByCountry` (`AbstractCreateUserService.java:90-92`).

즉 한 번의 이메일 회원가입 당 최대 호출 수 (성공 케이스):

| 단계 | adapter | 호출 횟수 |
|---|---|---|
| 연락처 reconnect | user/UserAppContactApiAdapter | 1 (async) |
| 약관 저장 (legacy) | terms | 1 |
| Subscriber 생성 + 그룹 등록 + 채널 등록 | subscribenotification | 5~6 (Find+Create+FindGroup+AddToGroup+FindWithIncludes+Mail+Phone) |
| 마케팅 동의 (서비스별) | platform | 0~3 |
| Braze unsubscribe key | crmgateway | 1 |
| 쿠폰 발급 (조건부) | usercoupon | 0~1 |
| Braze 가입 정보 | crmgateway | 1 |
| 가입 축하 메일 (async) | fastmail2 normal | 1 |
| 타임존 (상위에서 별도 호출) | user/UserApiAdapter | 1 |

= **약 10~15 건의 HTTP 호출** 이 단일 회원가입에 발생. 소셜 가입은 여기에 Kakao (`getAgreement`, `isFriendsScopeAgreed`) + `push2` + `alimtalk` 추가.

---

## 3. 어댑터별 상세

### 어댑터 index

| # | 디렉터리 | Adapter | Port | FeignClient name | base URL 설정 키 |
|---|---|---|---|---|---|
| 3.1 | `alimtalk/` | `AlimTalkAdapter` | `AlimTalkPort` | `alim-talk-service` | `wadiz.api.alimtalk.base-url` |
| 3.2 | `crmgateway/` | `CrmGatewayAdapter` | `CrmPort` | `braze-service` | `wadiz.api.crm-gateway.base-url` |
| 3.3 | `datasvc/` | `DataServiceAdapter` | `GetCountryFromIPPort` | `data-client2` | `wadiz.api.datasvc.base-url` |
| 3.4 | `fastmail2/` | `NotificationAdapterV2` | `NotificationPort` | `fast-mail-client` · `normal-mail-client` | `wadiz.api.mail-fast.base-url` · `…mail-normal…` |
| 3.5 | `kakao/` | `KakaoAdapter` | `KakaoPort` | `kakao-service` · `kakao-auth-service` | 코드에 직접 씀 |
| 3.6 | ~~`notification/`~~ | **삭제됨** | — | — | — |
| 3.7 | `notichannel/` | `MarketingConsentAdapter` | `MarketingConsentPort` | `noti-channel-client` | `wadiz.api.noti-channel.base-url` |
| 3.8 | `push2/` | `Push2Adapter` | `Push2Port` | `push2-api-client` | `wadiz.api.push.base-url` |
| 3.9 | `subscribenotification/` | `SubscribeNotificationAdapter` | `SubscribeNotificationPort` | `subsciber-client` (오타 원문) | `wadiz.api.notification.base-url` |
| 3.10a | `terms/` | `TermsAdapter` | `TermsPort` | `wadiz-user-service` (공유) | `wadiz.api.user.base-url` |
| 3.10b | `terms/` | `TermsQueryAdapter` | `SignupTermsQueryPort` | `wadiz-terms-query-service` | `wadiz.api.user.base-url` |
| 3.11a | `user/` | `UserApiAdapter` | `UserApiPort` | `wadiz-user-service` | `wadiz.api.user.base-url` |
| 3.11b | `user/` | `UserAppContactApiAdapter` | `UserAppContactApiPort` | `wadiz-user-service` (공유) | `wadiz.api.user.base-url` |
| 3.12 | `usercoupon/` | `UserCouponAdapter` | `UserCouponPort` | `wadiz-user-service` (공유) | `wadiz.api.user.base-url` |

> **`UserClient` 하나를 어댑터 넷이 나눠 씁니다.**
> `TermsAdapter`·`UserApiAdapter`·`UserAppContactApiAdapter`·`UserCouponAdapter` 입니다.
> `BE3-555` 이전에는 약관과 쿠폰이 각자 Feign 클라이언트를 갖고 있었습니다.
> 지금은 클라이언트를 하나로 합치고 **도메인 경계는 Port 로만 유지**합니다.
> 커밋 메시지의 표현이 *"user-api 호출을 단일 UserClient 로 통합(terms/coupon/contacts/timezone); 도메인 경계는 포트로 유지"* 입니다.

`UserClient` 가 노출하는 경로(`user/UserClient.java`, `path = "/api/v1"`)

| 메서드 | 경로 | 쓰는 어댑터 |
|---|---|---|
| `acceptTerms` | `POST /users/terms/accepter/{userId}` | `TermsAdapter` |
| (쿠폰 발급) | `POST /users/coupon/user/{userId}/type/{couponType}` | `UserCouponAdapter` |
| (쿠폰 종류 조회) | `GET /users/coupon/type/{couponType}` | `UserCouponAdapter` |
| `reconnectContactsByMyMobileNumber` | `PUT /users/contacts/{userId}/my-number/reconnection` | `UserAppContactApiAdapter` |
| `updateUserTimeZone` | `PUT /users/{userId}/time-zone/by-country` | `UserApiAdapter` |

---

### 3.1 `alimtalk/` — 회원가입 알림톡 발송

- **파일**: `AlimTalkAdapter.java`, `AlimTalkClient.java`, `dto/AlimTalkRequestDto.java`, `dto/AlimTalkPayloadsRequestDto.java`.
- **호출 대상**: Platform AlimTalk 서비스 v2.
  - Base URL: `${wadiz.api.alim-talk.base-url}` — live: `https://platform.wadiz.kr/alimtalk/api/v2/message` (`application-live.yml:98`), dev: `https://dev-platform.wadizcorp.net/alimtalk/api/v2/message` (`application-dev.yml:80`).
  - 단일 endpoint: `POST /alimtalk` (`AlimTalkClient.java:11-12`).
- **클라이언트 구현**: OpenFeign. `@FeignClient(name = "alim-talk-service", url = "${wadiz.api.alim-talk.base-url}")` (`AlimTalkClient.java:9`).
- **인증 방식**: Bearer 정적 내부 토큰. `internalToken` 을 `${wadiz.api.alim-talk.internal-token}` 으로 주입 → `"Bearer " + internalToken` 을 `@RequestHeader("Authorization")` 로 전달 (`AlimTalkAdapter.java:19-20, 46-47`).
- **요청 DTO** (`AlimTalkRequestDto.java:10-17`):
  - `String tid` — UUID (멱등 키).
  - `String templateCode` — `${wadiz.api.alim-talk.template.code}` = `B_WD_004_02_44717` (live `application-live.yml:101`).
  - `String templateNo` — `${wadiz.api.alim-talk.template.number}` = `3078` (live `application-live.yml:102`).
  - `String reserved` — 빈 문자열.
  - `String priority` — `"NORMAL"` 하드코딩 (`AlimTalkAdapter.java:31`).
  - `List<AlimTalkPayloadsRequestDto> payloads`:
    - `String phoneNumber` — `user.getMobilePhoneNumber()`.
    - `Map<String, String> maps` — `{nickName, couponA="15,000", couponB="2,000", benefit="3개월 0원"}` 하드코딩 (`AlimTalkAdapter.java:36-41`).
- **응답**: `void` — 실패 판정 없음.
- **호출 시점**: `CreateUserWithSocialAccountApplicationService.doRemainingWork(...)` → `this.alimTalkPort.sendSignUpNotificationTo(user)` (`CreateUserWithSocialAccountApplicationService.java:103`). `user.hasMobilePhoneNumber()` 가 true 일 때만 호출. `@Async` 이므로 별도 쓰레드.
- **실패 처리**: 없음. Feign 예외 → 호출자 (해당 `doRemainingWork` 는 `@Async`) 로 전파. retry/fallback/circuit breaker 미구성.
- **Port 시그니처** (`AlimTalkPort.java:5-7`):
  ```java
  public interface AlimTalkPort {
    public void sendSignUpNotificationTo(User user);
  }
  ```
  하위 메서드가 1개뿐이라 port 인터페이스의 목적은 "회원가입 알림톡만" 이다. 일반 알림톡 발송 용 확장 없음.
- **관찰**:
  - `priority = "NORMAL"`, `reserved = ""` 등 운영 시점에 바꿀 가능성이 있는 값이 하드코딩 (`AlimTalkAdapter.java:31-33`).
  - `couponA="15,000"`, `couponB="2,000"`, `benefit="3개월 0원"` 은 프로모션 문구지만 yml 이 아니라 Java 코드에 있다 (`AlimTalkAdapter.java:38-40`) — 프로모션 변경 시 **재배포 필요**.
  - `AlimTalkPayloadsRequestDto.maps` 의 key (`nickName`, `couponA`, `couponB`, `benefit`) 는 수신측 alimtalk 템플릿 `B_WD_004_02_44717` 의 변수와 1:1 매칭되는 것으로 추정 (본 저장소는 템플릿 내용을 모름).

---

### 3.2 `crmgateway/` — Braze CRM 게이트웨이

- **파일**: `CrmGatewayAdapter.java`, `CrmGatewayClient.java`, `SetUnsubscribeKeyRequest.java`, `SetUnsubscribeKeyResponse.java`, `dto/BrazeUserInfoDto.java`.
- **호출 대상**: 사내 Braze CRM Gateway.
  - Base URL: `${wadiz.api.braze}` — live: `http://172.31.1.12:9990/crmgateway/api/v1/crmgateway/braze` (`application-live.yml:80`). 내부 앱 서버 (`dev-app01:9990` 같은 사내 IP).
  - Endpoints (`CrmGatewayClient.java:11-15`):
    - `PUT /setUnsubscribeKey` → `SetUnsubscribeKeyResponse`.
    - `PUT /users/track` → void.
- **클라이언트 구현**: OpenFeign. `@FeignClient(name = "braze-service", url = "${wadiz.api.braze}")` (`CrmGatewayClient.java:8`).
- **인증 방식**: 없음. `Authorization` 헤더를 설정하지 않는다 — 사내망 IP (`172.31.x.x`) 기반 신뢰 경계.
- **요청/응답 DTO**:
  - `SetUnsubscribeKeyRequest { Long userId }` (`SetUnsubscribeKeyRequest.java:6-8`).
  - `SetUnsubscribeKeyResponse { Long userId, String result, String subscriberKey }` (`SetUnsubscribeKeyResponse.java:6-9`). `"success".equals(response.getResult())` 아니면 error 로그 (`CrmGatewayAdapter.java:19-21`).
  - `BrazeUserInfoDto { List<Map<String,Object>> attributes, List<Map<String,Object>> events }` (`BrazeUserInfoDto.java:13-16`).
    - `attributes[0]` 필드 (`BrazeUserInfoDto.java:25-33`): `appwelcome_coupon_download`(boolean), `external_id`(userId), `user_country`, `user_language`.
    - `events[0]` — 빈 맵.
- **호출 시점**:
  - `AbstractCreateUserService.registerUnsubscribeKeyForBraze(user)` → `crmPort.setUnsubscribeKey(userId)` (`AbstractCreateUserService.java:63`). 회원가입 흐름 중 subscribe 등록 이후.
  - `AbstractCreateUserService.giveAwaySignupCouponsAndNotifyCRM(user, locale)` → `crmPort.sendSignUpInformationWithCoupon(user, issuedCoupon)` (`AbstractCreateUserService.java:82`). 쿠폰 발급 여부를 Braze 속성으로 기록.
- **실패 처리**:
  - `setUnsubscribeKey`: 응답이 `"success"` 아니면 error 로그만 (예외 X, `CrmGatewayAdapter.java:20`).
  - `sendUserInfo`: Adapter 자체엔 try/catch 없음. 상위 `giveAwaySignupCouponsAndNotifyCRM` 이 `catch (Exception)` 으로 감싸 warn 로그 + `return false` (`AbstractCreateUserService.java:84-87`).
- **Port 시그니처** (`CrmPort.java:5-9`):
  ```java
  public interface CrmPort {
    void setUnsubscribeKey(Long userId);
    void sendSignUpInformationWithCoupon(User user, Boolean issuedCoupon);
  }
  ```
- **관찰**:
  - Braze 가 "attributes" 와 "events" 두 배열을 받는 형태는 Braze `POST /users/track` API 스펙과 동일. 즉 `crmgateway` 사내 서비스가 Braze API 를 thin passthrough 하는 구조로 추정.
  - `events[0]` 에 빈 맵을 넣는 것은 Braze 에 "event 는 없지만 attribute 는 업데이트" 의미로 보이나, 실제 crmgateway 측 스펙은 경계 밖.
  - `external_id = user.getUserId()` 로 Braze 외부 식별자를 Long 숫자로 지정. 이후 Braze 웹훅/세그먼트가 Long 형식을 기대하는 계약을 가짐.

---

### 3.3 `datasvc/` — IP → 국가코드

- **파일**: `DataClient.kt`, `DataServiceAdapter.kt`, `IpDto.kt`, `CountryDto.kt`.
- **호출 대상**: Wadiz DataService (사내 국가/IP 매핑).
  - Base URL: `${wadiz.api.data.url}` — live: `https://datasvc.wadiz.kr` (`application-live.yml:92`), dev: `https://dev-datasvc.wadiz.kr` (`application-dev.yml:74`).
  - Endpoint: `POST /global/v1/ip` (`DataClient.kt:10-14`).
- **클라이언트 구현**: OpenFeign (Kotlin). `@FeignClient(name = "data-client2", url = "\${wadiz.api.data.url}")` (`DataClient.kt:8`).
- **인증 방식**: Bearer 정적 토큰. `@Value("\${wadiz.api.data.token}")` (live: `D4850ADC...`, `application-live.yml:93`) → `"Bearer $token"` (`DataServiceAdapter.kt:12-17`).
- **요청 DTO**: `IpDto(val ip: String)` (`IpDto.kt:3`).
- **응답 DTO**: `CountryDto(@JsonProperty("country_code") val countryCode: String)` (`CountryDto.kt:4`).
- **호출 시점**: `CustomLocaleResolver.createLocaleFromIpOrDefault(httpRequest)` — 앱/봇이 아닌 HTTP 요청의 기본 Locale 결정 (`CustomLocaleResolver.java:92-98`).
- **실패 처리**: Adapter 가 모든 `Exception` 을 삼키고 `null` 반환 (`DataServiceAdapter.kt:18-21`). `CustomLocaleResolver` 는 null/유효하지 않은 country 면 기본 Locale 로 폴백 (`CustomLocaleResolver.java:94-96`). 즉 fallback 이 호출자 측에 있고, retry/circuit breaker 는 없음.
- **주석**: `DataServiceAdapter.kt:20` 에 `// default?` TODO. Port doc 은 "KR 반환" 을 명시하지만 (`GetCountryFromIPPort.java:9`) 구현은 null 반환. 계약 불일치 있음.
- **Port 시그니처** (`GetCountryFromIPPort.java:3-11`):
  ```java
  public interface GetCountryFromIPPort {
    /** @return country code for ip, "KR" if in case of exception */
    String getCountry(String ip);
  }
  ```
- **관찰**:
  - `IpDto` 가 body 로 전송되는 것이 특이 — 통상 `POST /ip` 는 `?ip=...` 쿼리나 `/ip/{ip}` path 로 하지만 여기선 `{ "ip": "x.x.x.x" }` body. datasvc 스펙에 맞춘 선택.
  - Client name `data-client2` — 접미사 `2` 는 마이그레이션 흔적으로 보임 (v1 client 는 저장소에 없음).
  - 이 호출만 매 HTTP 요청마다 발생 (LocaleResolver 훅) — 회원가입 등 단발 이벤트가 아니라 **거의 모든 unauthenticated 페이지 로드** 에서 발생 가능. 실패시 기본 Locale 로 polyfill 하므로 crit path 아님.

---

### 3.4 `fastmail2/` — 이메일 발송 (Fast + Normal)

단일 디렉터리지만 **2개의 서로 다른 메일 시스템** 을 묶고 있다: FastMail v2 (트랜잭션), NormalMail v3 (템플릿).

- **파일**:
  - Client: `FastMailClient.java`, `NormalMailClient.java`.
  - Adapter: `NotificationAdapterV2.java` (한 개가 두 Client 를 동시 소유).
  - Request: `FastMailRequest.kt`, `FastMailInfo.kt`, `NormalMailRequest.kt`, `NormalMailInfo.kt`.
  - Converter: `FastEmailToMailRequestConverter.kt`, `NormalEmailToMailRequestConverter.kt`.
  - Response: `MailResponse.kt`.

#### 3.4.1 FastMail

- **호출 대상**: `${wadiz.api.mail.fast.path}` — live `https://platform.wadiz.kr/mail-fast` (`application-live.yml:86`).
  - Endpoint: `POST /api/v2/send` (`FastMailClient.java:11-12`).
- **인증**: Bearer 정적 토큰 `${wadiz.api.mail.fast.token}` (live: `C2830C95...`, `application-live.yml:87`). `"Bearer " + fastMailToken` 를 생성자에서 prefix (`NotificationAdapterV2.java:27`).
- **요청 DTO** `FastMailRequest` (`FastMailRequest.kt:3-9`):
  - `tid` UUID, `domainCode="AUTH"`, `senderType="INTERNAL_SERVICE"`, `senderId=0`, `isAd=false`, `fromEmail`, `mailInfoList: List<FastMailInfo>` (`FastEmailToMailRequestConverter.kt:11-27`).
  - `FastMailInfo { toEmail, userId, title, body, cc, bcc }` (`FastMailInfo.kt:3-10`).
- **응답**: `MailResponse { code, data, message }` with `isSuccess() => code == 2000` (`MailResponse.kt:3-13`).

#### 3.4.2 NormalMail

- **호출 대상**: `${wadiz.api.mail.normal.path}` — live `https://platform.wadiz.kr/mail-normal` (`application-live.yml:89`).
  - Endpoint: `POST /api/v3/send` (`NormalMailClient.java:12-15`).
  - 추가 헤더: `WadizHttpHeaders.LANGUAGE = "wadiz-language"` (`NormalMailClient.java:14`, `WadizHttpHeaders.java:5`).
- **인증**: Bearer 정적 토큰 `${wadiz.api.mail.normal.token}` (live: `0245331D...`, `application-live.yml:90`).
- **요청 DTO** `NormalMailRequest` (`NormalMailRequest.kt:3-8`):
  - `tid`, `domainCode` (nullable, 예: `null` — 2025.09.24 주석 참고), `isAd=false`, `templateNo` (필수 int), `attachFileIdList`, `mailInfoList: List<NormalMailInfo>`.
  - `NormalMailInfo { toEmail, cc, bcc, userId, templateData: Map<String, Object> }` (`NormalMailInfo.kt:3-9`).
- **템플릿 번호**: `${wadiz.api.mail.normal.template.signup-complete}` = `1482` (`application.yml:232`) — 회원가입 축하 메일 한 건만 고정 번호로 사용.
- **응답**: 동일 `MailResponse`.

- **호출 시점** (둘 다 `EmailService` 를 통함, `EmailService.java:73-87`):
  - `sendEmailAuthenticationCode()` → `sendFastMail` (`EmailService.java:101-105`). 회원가입 이메일 인증코드 전송.
  - `sendResetPasswordMail()` → `sendFastMail` (`EmailService.java:123-128`). 비밀번호 재설정 링크.
  - `handleEvent(UserCreatedEvent)` → `sendSignUpCelebrationMail()` → `sendNormalMail` (`EmailService.java:89-118`). 가입 축하 메일. 2025.09.24 주석: "반송률 제한 방어를 위해 Normal mail 로 변경" (`EmailService.java:113-114`).
- **실패 처리**:
  - Adapter (`NotificationAdapterV2.java:41-44`, `52-54`): 응답 null 혹은 `!isSuccess()` 이면 error 로그. tid 를 반환해 상위 계층에서 추적 가능.
  - `EmailService` (`:136-151`): Adapter 예외 catch → error 로그 + `EmailNotSentException` re-throw.
  - `EmailService.handleEvent` (`:89-99`): welcome 메일은 `@Async` + 예외 삼킴 (best-effort).
- **Port 시그니처** (`NotificationPort.java:6-9`):
  ```java
  public interface NotificationPort {
    String sendFastMail(FastEmail fastEmail);
    String sendNormalMail(final String languageCode, NormalEmail email);
  }
  ```
  반환 타입이 `String` 인 이유: 각 메일의 `tid` (UUID) 를 돌려줘 상위 로그에서 추적할 수 있게 함.
- **Adapter DI** (`NotificationAdapterV2.java:20-33`):
  ```java
  public NotificationAdapterV2(
    @Value("${wadiz.api.mail.fast.token}") String fastMailToken,
    @Value("${wadiz.api.mail.normal.token}") String normalMailToken,
    FastMailClient fastMailClient,
    FastEmailToMailRequestConverter fastMailConverter,
    NormalMailClient normalMailClient,
    NormalEmailToMailRequestConverter normalEmailToMailRequestConverter) {
      this.bearerFastMailToken = "Bearer " + fastMailToken;
      this.bearerNormalMailToken = "Bearer " + normalMailToken;
      …
  }
  ```
  생성자에서 한 번만 `"Bearer "` prefix concat 후 재사용 (매 호출마다 문자열 생성 방지).
- **`@Qualifier("notificationAdapterV2")`** — `EmailService` 생성자에서 Spring 빈 이름으로 명시 (`EmailService.java:78`). 이는 **예전에 다른 NotificationPort 구현이 있었다** 는 흔적 (추정: `notification/` 패키지의 legacy adapter).
- **FastMail vs NormalMail 분기**:
  - 반송률 제한 방어를 위해 가입 축하는 normal 로 이동했지만 (`EmailService.java:113-114`), 인증코드/비밀번호 재설정은 여전히 fast 채널. 즉 "fast" 는 템플릿 없이 HTML body 를 직접 담아 실시간 전송, "normal" 은 템플릿 번호 기반 비동기/배치성 전송으로 추정.
  - FastMail `FastMailRequest` 는 body 를 직접 전달 (`body: email.body`, `FastEmailToMailRequestConverter.kt:22`). NormalMail `NormalMailRequest` 는 템플릿만 지정하고 `templateData` 로 변수만 전달 (`NormalEmailToMailRequestConverter.kt:19-23`).

---

### 3.5 `kakao/` — Kakao Open API (OAuth 이후)

- **파일**: `KakaoAdapter.java`, `KakaoClient.java`, `KakaoAuthClient.java`, `Agreement.java`, `Scopes.java`, `TokenDto.java`.
- **호출 대상**: 외부 Kakao 플랫폼 (2개의 Feign 클라이언트).
  - `KakaoClient` — `https://kapi.kakao.com` 고정 URL (`KakaoClient.java:8`):
    - `GET /v2/user/service_terms` → `Agreement` (`KakaoClient.java:11-12`).
    - `GET /v2/user/scopes?target_id_type=&target_id=&scopes=` → `Scopes` (`KakaoClient.java:14-18`).
  - `KakaoAuthClient` — `https://kauth.kakao.com` 고정 URL (`KakaoAuthClient.java:8`):
    - `POST /oauth/token?grant_type=refresh_token&client_id=&client_secret=&refresh_token=` + `Content-Type: application/x-www-form-urlencoded` → `TokenDto` (`KakaoAuthClient.java:11-16`).
- **클라이언트 구현**: OpenFeign. URL 이 property 없이 **하드코딩** 된 외부 공개 엔드포인트.
- **인증 방식**: 두 가지 상이한 토큰:
  - 사용자 컨텍스트 API (`getAgreement`) → `"Bearer " + accessToken` (OAuth2 에서 얻은 사용자 토큰, `KakaoAdapter.java:29-30`).
  - 관리자 API (`getScopes`, `isFriendsScopeAgreed`) → `"KakaoAK " + kakaoAdminToken`. `kakaoAdminToken` 은 `${wadiz.kakao.adminkey}` (`KakaoAdapter.java:20-21, 40`; live 에선 `application-live.yml` 에 해당 키, local 에선 `application-local.yml:52` = `f3e319...`).
  - `renewToken()` 은 무인증 (refresh_token flow 자체가 credential) — `client_id`, `client_secret` 는 `OAuth2ClientProperties` 의 kakao registration 에서 꺼내 본문 파라미터로 (`KakaoAdapter.java:50-52`).
- **요청/응답 DTO**:
  - `Agreement { String user_id, List<KakaoTerms> allowed_service_terms }` with inner `KakaoTerms { String tag, LocalDateTime agreed_at }` (`Agreement.java:17-36`). JSON 필드명: `id` → `user_id`, `service_terms` → `allowed_service_terms` (`@JsonProperty`).
  - `Scopes { String id, List<Scope> scopes }` with `Scope { id, display_name, type, boolean using, boolean agreed }` (`Scopes.java:9-25`). helper: `hasAgreedScope("friends")`.
  - `TokenDto { access_token, token_type, expires_in }` (`TokenDto.java:7-10`).
- **호출 시점**:
  - `getAgreement(accessToken)`:
    - `SocialAuthenticationSuccessHandler.syncKakaoAgreement()` — 카카오 소셜 로그인 성공 후 약관 동의 상태 sync (`SocialAuthenticationSuccessHandler.java:143`).
    - `OAuth2UserToKakaoAccountConverter` — OAuth2User → 내부 KakaoAccount 변환 시 (`OAuth2UserToKakaoAccountConverter.java:47`).
  - `isFriendsScopeAgreed(providerUserId)`:
    - `CreateUserWithSocialAccountApplicationService.updateKakaoAccountAboutAgreement` (`CreateUserWithSocialAccountApplicationService.java:113`) — 해당 메서드는 `@Deprecated` 주석.
    - `OAuth2UserToKakaoAccountConverter.java:46`.
  - `renewToken(refreshToken)` — `KakaoAdapter.java:49` 에 존재. 호출 지점은 본 저장소 내에서 찾기 어렵거나 (스케줄러/토큰 갱신 로직에서 사용 가능) 본 adapter 범위 밖.
- **실패 처리**: `getAgreement` 은 `FeignException` 을 catch 하고 `log.error(e.toString())` 후 rethrow (`KakaoAdapter.java:32-35`). 나머지 메서드는 그대로 전파.
- **Port 시그니처** (`KakaoPort.java:6-10`):
  ```java
  public interface KakaoPort {
    Agreement getAgreement(String accessToken);
    boolean isFriendsScopeAgreed(String providerUserId);
    TokenDto renewToken(String refreshToken);
  }
  ```
- **관찰**:
  - `KakaoAuthClient` 는 `feign.Headers("Content-Type: application/x-www-form-urlencoded")` 를 사용 (`KakaoAuthClient.java:12`). 이는 Spring `@RequestMapping(consumes = ...)` 가 아니라 **순수 Feign annotation** 이다. Spring Cloud OpenFeign 이 @RequestParam 을 form-urlencoded 로 직렬화하는지 여부는 Feign encoder 설정에 달려있는데, `FeignConfig.java` 에는 별도 encoder 가 없음. 기본 encoder 가 `@RequestParam` 을 쿼리스트링으로 보내는 게 일반적이라 실제 렌더링이 서버쪽 Kakao 의 `/oauth/token` 스펙과 호환되는지 런타임 검증이 필요 (본 문서 범위 밖).
  - `Agreement.KakaoTerms` 는 `tag`, `agreed_at` 필드를 가짐. Kakao 는 `tag` 에 `funding_xxx_yyyyy` 형태 문자열을 반환 (`Agreement.java:23` 주석 `example: funding_xxx_yyyyy`).
  - `hasAgreedScope("friends")` 로 "카카오톡 친구 목록" 권한 동의 여부를 확인 (`Scopes.java:13-16`).
  - `OAuth2ClientProperties` 주입 (`KakaoAdapter.java:24`) 은 Spring Boot 의 `spring.security.oauth2.client.registration.kakao.*` 를 재사용한다는 의미.

---

### 3.6 ~~`notification/`~~ — **패키지 전체가 삭제됐습니다**

`BE3-555`(2026-06-26, `f7d832ac`)가 지웠습니다. 파일 11개가 한꺼번에 사라졌습니다.

~~`EmailToMailConverter.java`~~ · ~~`Inbox.java`~~ · ~~`InboxRequest.java`~~ · ~~`Mail.java`~~ ·
~~`NotificationClient.java`~~ · ~~`NotificationPolicyCode.java`~~ · ~~`NotificationPublish.java`~~ ·
~~`NotificationPublishRequest.java`~~ · ~~`NotificationPublishWithInbox.java`~~ ·
~~`PublishType.java`~~ · ~~`PublisherType.java`~~

> 취소선은 "이 파일은 이제 없다"는 표시입니다. 낡음 검사기가 이 표시를 보고 소실 인용에서 뺍니다.

> ✅ **이 문서가 미리 짚어 둔 대로였습니다.**
> 예전 3.6 절이 *"저장소 내 실제 호출 지점 없음 … dead code 상태의 shared DTO 모음"* 이라고 적어 뒀습니다.
> 삭제 커밋의 설명도 같은 말을 합니다 —
> *"죽은 코드 제거: … notification 패키지 전체(IAM-3399 NotificationAdapter 리팩토링으로 고아화) + 관련 테스트"*.
>
> 지금 메일 발송은 `fastmail2/NotificationAdapterV2` 가 맡습니다(3.4 절).
> `wadiz.api.notification.base-url` 설정 키는 남아 있고, `subscribenotification/` 이 씁니다(3.9 절).

---

### 3.7 `notichannel/` — 마케팅 수신 동의 (예전 이름 `platform/`)

> 📅 **폴더 이름이 바뀌었습니다.** `BE3-457`(2026-06-30, `a4fe9a60`) "MarketingConsent noti-channel 통일 및 토큰 제거".
> FeignClient 이름도 `platform-api-client` 에서 **`noti-channel-client`** 로,
> 설정 키도 `wadiz.api.marketing-consent` 에서 **`wadiz.api.noti-channel.base-url`** 로 바뀌었습니다.
> 커밋 제목의 "토큰 제거"대로 인증 토큰도 빠졌습니다.

- **파일**: `MarketingConsentAdapter.java`, `MarketingConsentClient.java`, `NotificationChannelAgreement.java`, `ChannelType.java` (+ response DTO 가 `subscribenotification/dto/PlatformNotiChannelMarketingConsentsDto` 에 위치).
- **호출 대상**: Platform Marketing Consent (Noti-Channel).
  - Base URL: `${wadiz.api.marketing-consent}` — live: `https://platform.wadiz.kr/noti-channel` (`application-live.yml:82`), dev: `https://dev-platform.wadizcorp.net/noti-channel` (`application-dev.yml:66`).
  - Endpoints (`MarketingConsentClient.java:10-21`):
    - `PUT /marketingconsents?serviceCode={code}&userId={id}` body=`NotificationChannelAgreement`.
    - `GET /marketingconsents?userId={id}` → `Optional<PlatformNotiChannelMarketingConsentsDto>`.
- **클라이언트 구현**: OpenFeign. `@FeignClient(name = "platform-api-client", url = "${wadiz.api.marketing-consent}")` (`MarketingConsentClient.java:9`).
- **인증 방식**: Bearer 정적 `${wadiz.platform.api.token}` (live `B0D86E95...`, `application-live.yml:69`). Adapter 에서 `"Bearer " + bearerToken` 조립 (`MarketingConsentAdapter.java:15-16, 19`).
- **요청 DTO**:
  - `NotificationChannelAgreement { ChannelType channelType, boolean consentValue }` (`NotificationChannelAgreement.java:8-10`).
  - `ChannelType` enum = `ALL, APP, EMAIL, PHONE` (`ChannelType.java:3-5`). Adapter 는 항상 `ChannelType.ALL + true` (`NotificationChannelAgreement.allChannelAgreement()`, `:16-19`) 로 고정 → "모든 채널 마케팅 동의 ON".
  - `serviceCode` 쿼리파라미터는 `ServiceCode.getNotificationApiName()` (FUNDING/INVEST/STARTUP) (`MarketingConsentAdapter.java:20`).
- **응답 DTO** (`PlatformNotiChannelMarketingConsentsDto.java:8-11`):
  - `String code, Map<TemporaryMarketingConsentValue, Boolean> data`.
  - `TemporaryMarketingConsentValue` (`TemporaryMarketingConsentValue.java:12-22`): 9 조합 (funding/invest/startup × push/mail/sms) + `empty`. 각 원소는 `(ServiceCode, channel)` 을 보유.
- **호출 시점**: `AbstractCreateUserService.registerNotification(user)` → `user.getServiceWithMarketingAgreement()` 로 동의한 ServiceCode 들만 순회하며 `platformApiPort.updateMarketingConsent(serviceCode, userId)` 호출 (`AbstractCreateUserService.java:54-57`). 즉 회원가입 시점, 약관에서 funding/invest/startup 마케팅을 동의한 서비스에 대해서만 전송.
- **실패 처리**: Adapter 자체엔 try/catch 없음. 예외는 호출자 (`AbstractCreateUserService.registerNotification`) 로 전파되고, 여기도 catch 없음 → 회원가입 트랜잭션에 영향 가능.
- **Port 시그니처** (`MarketingConsentPort.java:5-7`):
  ```java
  public interface MarketingConsentPort {
    void updateMarketingConsent(ServiceCode serviceCode, Long userId);
  }
  ```
- **관찰**:
  - Adapter 는 `NotificationChannelAgreement.allChannelAgreement()` 로 **항상 `ALL` + true** 만 보낸다 (`MarketingConsentAdapter.java:22`). 즉 사용자가 약관 중 특정 채널(APP/EMAIL/PHONE)만 선택했더라도 platform 쪽엔 "전 채널 동의" 로 기록된다. 채널별 분리는 `subscribenotification` 쪽 (mail/phone 개별 flag) 에서 관리하는 이중 구조로 추정.
  - `getMarketingConsent` Client 메서드는 정의되어 있지만 Adapter 가 구현하지 않음 — 조회 API 는 account 가 필요 없어 정의만 남았거나, 미래 확장 용.
  - path `/marketingconsents` 는 `marketing-consent` 가 아니라 **복수형 복합명** — URL 철자 주의.

---

### 3.8 `push2/` — 푸시 + 인박스

- **파일**: `Push2Adapter.java`, `Push2Client.java`, `PushRequest.java`, `PushInboxRequest.java`, `PushResponse.java`.
- **호출 대상**: Platform Push2 서비스.
  - Base URL: `${wadiz.api.push2}` — live: `https://platform.wadiz.kr/push/api/v1/push` (`application-live.yml:83`), dev: `https://dev-platform.wadizcorp.net/push/api/v1/push` (`application-dev.yml:67`).
  - Endpoints (`Push2Client.java:8-14`):
    - `POST /user` body=`PushRequest` → void.
    - `POST /inbox` body=`PushInboxRequest` → `PushResponse`.
- **클라이언트 구현**: OpenFeign. `@FeignClient(name = "push2-api-client", url = "${wadiz.api.push2}")` (`Push2Client.java:7`).
- **인증 방식**: 없음 (Authorization 헤더 파라미터 없음). 서비스 간 평문 호출.
- **요청 DTO**:
  - `PushRequest` (`PushRequest.java:16-29`): `List<Long> userIds, Map<Long, Map<String, Object>> templateData, title, body, deepLink, boolean isAd (@JsonProperty "isAd"), tid, serviceCode, image, isSendDaybreak, domainCode`.
  - `PushInboxRequest extends PushRequest` (`PushInboxRequest.java:16-22`): 추가 `inboxTitle, inboxBody, inboxLink, int senderId, senderType, inboxType, String languageCode`.
- **응답 DTO** (`PushResponse.java:5-13`): `int code, String message`. `isSuccess() => code == 2000`.
- **조립 규칙** (`Push2Adapter.java:30-48`):
  - `deepLink = "EVT" + "#,#" + (siteUrl + targetLink)` — `CCI.NOTIFICATION_APP_DEEPLINK_TYPE_WEB = "EVT"`, divider `"#,#"` (`CCI.java:40-41`). siteUrl 은 `${wadiz.com.wadiz.web.address}` (예: `https://www.wadiz.kr`).
  - `serviceCode = ServiceCode.funding.getNotificationApiName()` = `"FUNDING"` 고정 (`Push2Adapter.java:39`).
  - `tid = UUID.randomUUID()`, `senderType="SYSTEM"`, `senderId=0`, `inboxType="SUPPORTER"`, `isAd=false`, `isSendDaybreak=false`.
  - `languageCode = locale.getLanguage()`.
  - `domainCode` — 호출자가 `DomainCode.ACCOUNT_KAKAO` 를 전달 (`DomainCode.java:3-6`).
- **호출 시점**: `CreateUserWithSocialAccountApplicationService.sendAlarmForKakaoLink()` (`:124`) — 카카오 연결 회원가입 시 "연결 축하" 푸시+인박스 발송. 해당 메서드는 `doRemainingWork(user)` 안에서 호출되며 상위가 `@Async` 이므로 비동기 실행.
- **실패 처리**: `pushResponse.isSuccess()` 가 false 이면 `RuntimeException` throw (`Push2Adapter.java:50-52`). `doRemainingWork` 가 `@Async` 라 호출자 main 트랜잭션에는 영향 없음. retry/circuit breaker 없음.
- **Port 시그니처** (`Push2Port.java:5-7`):
  ```java
  public interface Push2Port {
    void push(long userId, String title, String body, String inboxTitle,
              String targetLink, DomainCode domainCode, Locale locale);
  }
  ```
- **관찰**:
  - `Push2Client.push` (`/user`) 는 adapter 에서 호출되지 않음 — `pushInbox` (`/inbox`) 만 사용. 두 엔드포인트의 차이는 "인박스(메시지함) 저장 여부".
  - `DomainCode.ACCOUNT_KAKOA` 가 아닌 `ACCOUNT_KAKAO` (정상 스펠링). 다른 `NEWS`, `FOLLOW`, `STORE_RESTOCK` 등도 정의되어 있지만 account 에서 사용하는 건 `ACCOUNT_KAKAO` 하나뿐.
  - `PushInboxRequest.testCase()` (`:26-45`) 는 하드코딩 된 `userIds=[1000001624L]` — 개발자 테스트용 샘플. 운영 코드 경로에선 미사용.
  - `@JsonProperty("isAd")` (`PushRequest.java:22-23`) — Lombok 의 `@Data` 가 생성하는 getter 이름이 `isAd` 가 아니라 `isIsAd` 로 된 Jackson 기본 추론 문제를 막기 위한 명시적 매핑.

---

### 3.9 `subscribenotification/` — 통합 구독자 관리

가장 많은 엔드포인트를 소비하는 adapter. 한 회원가입당 최대 5번의 HTTP 호출 (조회 + 생성 + 그룹 조회 + 그룹 추가 + mail 등록 + phone 등록).

- **파일**:
  - Client: `SubscribeNotificationClient.java`.
  - Adapter: `SubscribeNotificationAdapter.java`.
  - Converter: `UserToSubscriberRequestConverter.java`.
  - DTO: `SubscriberRequest.java`, `SubscriberResponse.java`, `SubscriberGroupResponse.java`, `SubscriberProperty.java`, `AddSubscriberMailRequest.java`, `AddSubscriberPhoneRequest.java`, `AbstractAddSubscriberInfoRequest.java`, `PostStatus.java`, `PlatformNotiChannelMarketingConsentsDto.java`, `TemporaryMarketingConsentValue.java`.
  - Model: `Subscriber.java`, `SubscriberGroup.java`, `NotificationApp.java`, `NotificationMail.java`, `NotificationMobilePhone.java`, `NotificationMethodStatus.java`, `IncomingType.java`.
- **호출 대상**: 사내 Notification Service.
  - Base URL: `${wadiz.api.notification}` (`notification/` adapter 와 동일 base 공유!) — live: `http://172.31.1.12:9990/notification/api/v1/notifications` (`application-live.yml:81`).
  - Endpoints (`SubscribeNotificationClient.java:14-60`):
    - `GET /subscribers/incomings/{incomingType}/keys/{userId}?serviceCode=&includes=app,phone,mail` → `Optional<Subscriber>`.
    - `GET /subscribers/incomings/{incomingType}/keys/{userId}?serviceCode=` → `Optional<SubscriberResponse>` (includes 없이).
    - `GET /subscribers/incomingType/{incomingType}/incomingKey/{incomingKey}` → `Optional<Subscriber>`.
    - `POST /subscribers` body=`SubscriberRequest` → `SubscriberResponse`.
    - `GET /groups/incomings/{subscriberType}/keys/{subscriberGroupType}` → `SubscriberGroupResponse`.
    - `POST members/groups/{subscriberGroupKey}/subscribers/{subscriberKey}` → void. (leading slash 없음 주의, `SubscribeNotificationClient.java:44`).
    - `PUT /mails/subscribers/{subscriberKey}` body=`AddSubscriberMailRequest`.
    - `POST /mails` body=`AddSubscriberMailRequest`.
    - `PUT /phones/subscribers/{subscriberKey}` body=`AddSubscriberPhoneRequest`.
    - `POST /phones` body=`AddSubscriberPhoneRequest`.
- **클라이언트 구현**: OpenFeign. `@FeignClient(name = "subsciber-client", url = "${wadiz.api.notification}")` (`SubscribeNotificationClient.java:11`) — name 오타 "subsciber".
- **인증 방식**: 없음 (사내망 IP).
- **요청/응답 DTO 핵심 필드**:
  - `SubscriberRequest` (`SubscriberRequest.java:9-19`): `IncomingType incomingType`, `Long incomingKey` (= `user.getUserId()`), `String subscriberName` (= `user.getUsername()`), `String serviceCode` (예 `"FUNDING"`), `SubscriberProperty property`. 모든 필드 `@NotNull`.
  - `SubscriberProperty` (`SubscriberProperty.java:13-20`): `@NotBlank name, @NotBlank nick, photoId, birth`. `photoId` 는 현재 항상 빈 문자열 (`UserToSubscriberRequestConverter.java:20`, "TODO" 주석).
  - `SubscriberResponse` (`SubscriberResponse.java:9-18`): `subscriberKey, subscriberName, incomingType, Integer incomingKey, Boolean isSubscribe, registered, updated, property`.
  - `Subscriber` (`Subscriber.java:9-32`): 조회시 확장 모델. `List<NotificationApp>`, `NotificationMail`, `NotificationMobilePhone` 포함. helper `mailNotificationRegistered()`, `phoneNotificationRegistered()` (:24-31).
  - `SubscriberGroupResponse` (`SubscriberGroupResponse.java:8-26`): `subscriberGroupKey, subscriberGroupName, incomingType, incomingKey, SubscribesStatus status (ACTIVATE/INACTIVATE/DENY/UNKNOWN), registered, updated`.
  - `AddSubscriberMailRequest` (`AddSubscriberMailRequest.java:8-34`): `subscriberKey, email, PostStatus status`, `Boolean isAllowAdsFunding/Invest/Startup`. 두 팩토리 메서드 — `fromKeyAndMail()` (상태만), `fromKeyAndMailAndAdsFalseFlags()` (광고 플래그 3개 모두 false).
  - `AddSubscriberPhoneRequest` (`AddSubscriberPhoneRequest.java:12-39`): 유사 구조, `phoneNumber`.
  - `PostStatus` enum = `NORMAL, INVALID, DENY, COMPLAINT` (`PostStatus.java:6-19`). Adapter 는 항상 `NORMAL` 사용.
  - `IncomingType` enum (`IncomingType.java:6-18`): `USERS("USERS","user")`, `NEWS_MAKER_EQUITY("NEWS_MAKER_EQUITY","equity")`, `NEWS_MAKER_REWARD("NEWS_MAKER_REWARD","reward")`. `subscriberType` 과 `subscriberGroupType` 쌍.
  - `NotificationApp` (`NotificationApp.java:8-66`): `appId, subscriberKey, AppType (C1/M1), DeviceType (ANDROID/IOS), PushCenterType (GCM/APNS/FCM), deviceKey, appVersion, appToken, AppTokenStatus (ACTIVATE/UNREGISTERED/EXPIRED_TOKEN/INACTIVATE), isAllowAds, NotificationMethodStatus status`.
  - `NotificationMail` (`NotificationMail.java:8-15`): `emailId, email, subscriberKey, isAllowAds, status`.
  - `NotificationMobilePhone` (`NotificationMobilePhone.java:8-15`): `phoneNumber, subscriberKey, isAllowAds, isAllowPromotion, status`.
- **호출 시점**: `AbstractCreateUserService.registerNotification(user)` → `subscribeNotificationPort.registerNotification(user)` (`AbstractCreateUserService.java:52`). 회원가입 시 필수 단계.
- **내부 플로우** (`SubscribeNotificationAdapter.registerNotification`, `:29-49`):
  1. `findSubscriberByUserIdAndService(userId, funding)` — 이미 있으면 skip (멱등성).
  2. 없으면 `createSubscriberForService(user, funding)` (`:35`).
  3. `findGroup()` → `findGroupByIncomingTypeAndKey("USERS","user")` (`:38, :98`).
  4. `addSubscriberToGroup(groupKey, subscriberKey)` (`:39`).
  5. 생성된 subscriber 를 `includes=app,phone,mail` 로 재조회 (`:42, :93-95`) → 그 결과로 mail/phone 등록 분기:
     - mail 채널이 아직 등록 전이면 `POST /mails`, 아니면 `PUT /mails/subscribers/{key}` (`:67-75`, `addOrUpdateMailSubscription`).
     - phone 은 `user.hasMobilePhoneNumber()` + 기존 등록여부에 따라 동일 패턴 (`:55-64`).
- **실패 처리**: Adapter 에 try/catch 없음. 각 단계 실패 시 예외 전파. TODO 주석: Reactive 로 combine 하자 (`:23-28`). retry 없음.
- **Port 시그니처** (`SubscribeNotificationPort.java:5-7`):
  ```java
  public interface SubscribeNotificationPort {
    void registerNotification(User user);
  }
  ```
  외부에서 보면 단일 메서드지만 내부 구현은 5~6 HTTP 호출을 조립.
- **`AbstractAddSubscriberInfoRequest` 관찰**:
  - 이 abstract 클래스 (`AbstractAddSubscriberInfoRequest.java:5-29`) 는 `AddSubscriberMailRequest` 와 `AddSubscriberPhoneRequest` 가 공통 필드(`subscriberKey`, `email`, `status`, `isAllowAdsFunding/Invest/Startup`)를 공유할 의도로 보인다. 하지만 실제 두 구체 클래스가 `extends AbstractAddSubscriberInfoRequest` 를 하지 않고 각자 필드를 재정의 (`AddSubscriberMailRequest.java:8-16`, `AddSubscriberPhoneRequest.java:12-19`). 또한 abstract 내부 `PostStatus` enum 이 dto 패키지의 별도 `PostStatus` 와 중복 정의됨 — 디자인 미완성 흔적.
- **오타 FeignClient name**: `subsciber-client` (`SubscribeNotificationClient.java:11`) — Spring bean 이름으로 등록되므로 만약 어디선가 `@Qualifier("subscriber-client")` 로 조회하면 미스매칭. 현재 외부에서 name 으로 조회하는 곳은 없어 실질 영향 없음.

---

### 3.10 `terms/` — 약관 동의 저장과 가입 약관 조회

> 📅 **`BE3-555` 로 크게 바뀐 절입니다.**
> `TermsClient.java` 가 삭제되고 **`UserClient` 를 쓰도록** 바뀌었습니다.
> 대신 가입 화면용 조회 클라이언트 `SignupTermsQueryClient` 가 새로 들어왔습니다.

- **파일**: `TermsAdapter.java`, `TermsQueryAdapter.java`, `SignupTermsQueryClient.java`, `dto/CreateTermsRequest.java`

#### 3.10a `TermsAdapter` (`TermsPort`) — 약관 동의 저장

- 전용 Feign 클라이언트가 없습니다. **`UserClient` 를 주입받아** 씁니다 (`TermsAdapter.java:15`).
- 호출 경로: `POST /api/v1/users/terms/accepter/{userId}`, 본문은 `CreateTermsRequest`
- **호출 시점**: `AbstractCreateUserService.saveTerms(...)` 에서 `termsPort.acceptTerms(userId, terms)`
- **보내기 전에 한 가지를 걸러냅니다.**
  ```java
  terms.removeUserAgeCheck(); // TODO check why? terms api doesn't support this
  ```
  "userAgeCheck" 약관을 뺀 뒤 보냅니다. 주석의 `TODO` 가 이유를 모르겠다고 적고 있습니다.
- **실패 처리**: 없습니다. 성공 로그만 남깁니다.
- **Port 위치**: `TermsPort` 만 `port.outbound` 가 아니라 **`domain.terms`** 에 있습니다.
  리팩터링이 중간에 멈춘 상태로 보입니다(추정).

#### 3.10b `TermsQueryAdapter` (`SignupTermsQueryPort`) — 가입 약관 목록 조회

가입 화면에 보여 줄 약관 목록을 받아 옵니다.

```java
@FeignClient(name = "wadiz-terms-query-service", url = "${wadiz.api.user.base-url}")
public interface SignupTermsQueryClient {
  @GetMapping(value = "/api/v2/terms/{flowType}", produces = "application/json")
  ResponseEntity<List<JsonNode>> getTerms(String flowType, String platformType,
                                          @RequestHeader(COUNTRY) String country,
                                          @RequestHeader(LANGUAGE) String language);
}
```

| 항목 | 내용 |
|---|---|
| `flowType` | 코드에 `"signup"` 으로 고정돼 있습니다 |
| 국가·언어 | 본문이 아니라 **요청 헤더**로 보냅니다 |
| 응답 | `JsonNode` 목록입니다. DTO 로 매핑하지 않습니다 |

> **클라이언트를 따로 둔 이유가 코드 주석에 있습니다.**
> *"통합 UserClient(path=/api/v1)는 v1 전용이라 v2 경로(/api/v2/terms)는 이 클라이언트가 담당한다.
> 단 대상 서비스는 동일하므로 UserClient와 같은 base-url을 재사용한다"*.
> 서비스는 같은데 API 버전이 달라서 나뉜 것입니다.

> **실패해도 빈 목록으로 넘어갑니다.** 다만 조용히 넘기지는 않습니다.
> ```java
> } catch (Exception e) {
>   // 응답을 받고도 디코딩/전송 단계에서 실패하면 빈 목록으로 폴백한다.
>   // 조용히 삼키면 "user-api는 200인데 응답은 []"인 원인 파악이 어려우므로 반드시 로깅한다.
>   log.warn("가입 약관 목록 조회 실패 - country: {}, ...", country, language, platformType, e);
>   return Collections.emptyList();
> }
> ```

---

### 3.11 `user/` — wave.user API

- **파일**: `UserClient.java`, `UserApiAdapter.java`, `UserAppContactApiAdapter.java`, `ReconnectionContactCount.java`
- **클라이언트**: `@FeignClient(name = "wadiz-user-service", url = "${wadiz.api.user.base-url}", path = "/api/v1")`
- **인증**: 없습니다 (사내망)

`UserClient` 가 노출하는 경로 5개는 [어댑터 index](#어댑터-index) 아래 표를 봅니다.
그중 이 폴더의 어댑터가 쓰는 것은 둘입니다.

#### 3.11.1 `UserApiAdapter` (`UserApiPort`)
- `updateUserTimeZoneByCountry(userId, country)` → `PUT /api/v1/users/{userId}/time-zone/by-country`
- **호출 시점**: `AbstractCreateUserService.updateUserTimeZone(savedUser)`. 회원가입 본류가 끝난 뒤 별도로 부릅니다.
- **실패 처리**: 없습니다.

#### 3.11.2 ~~`TermsApiAdapter`~~ — **삭제됐습니다**

`BE3-555` 가 ~~`TermsApiAdapter.java`~~·~~`TermsApiPort.java`~~·~~`TermsTypeWithDate.java`~~ 를 함께 지웠습니다.

> ✅ **이 문서가 지적했던 설계 문제가 실제로 고쳐졌습니다.**
> 예전 3.11.2 절이 이렇게 적어 뒀습니다 —
> *"결과적으로 동일 endpoint 를 두 경로 포맷으로 호출 → 설계 상 정리가 필요해 보임"*.
>
> 삭제 커밋의 설명이 정확히 그 얘기를 합니다 —
> *"terms 쓰기 일원화: 카카오 동의 sync 도 TermsPort.acceptTerms 사용 (TermsApiPort/TermsApiAdapter 제거)"*.
>
> 즉 카카오 로그인 뒤 약관 동의를 맞추는 `SocialAuthenticationSuccessHandler.syncKakaoAgreement()` 도
> 이제 **`TermsPort.acceptTerms` 한 경로만** 씁니다.

#### 3.11.3 `UserAppContactApiAdapter` (`UserAppContactApiPort`)
- `asyncReconnectContactsByMyMobileNumber(userId, mobileNumber)` → `@Async` 로 `PUT /contacts/{userId}/my-number/reconnection { mobileNumber }` (`UserAppContactApiAdapter.java:16-26`).
- **응답 DTO**: `ReconnectionContactCount { int connectedCount }` (`ReconnectionContactCount.java:6-8`) — 결과는 사용하지 않음 (void 반환).
- **호출 시점**:
  - `CreateUserApplicationService.createUser` (`CreateUserApplicationService.java:78`).
  - `CreateUserWithSocialAccountApplicationService.createUser` (`CreateUserWithSocialAccountApplicationService.java:89`).
- **실패 처리**: `try/catch (Exception)` 으로 warn 로그만 남기고 무시 (`UserAppContactApiAdapter.java:22-25`) — best-effort.

#### 3.11.4 사용되지 않는 메서드
- `getAcceptedTerms(userId)` (`UserClient.java:15-16`) — 현재 저장소 내 호출 지점 없음. `TermsTypeWithDate` DTO 는 `termsType`, `updated` 두 필드만 (`TermsTypeWithDate.java:16-17`).

#### 3.11.5 Port 시그니처
- `UserApiPort` (`UserApiPort.java:3-5`):
  ```java
  public interface UserApiPort {
    void updateUserTimeZoneByCountry(Long userId, String country);
  }
  ```
- `TermsApiPort` (`TermsApiPort.java:5-13`):
  ```java
  public interface TermsApiPort {
    /** update terms data of userId */
    void updateAgreement(Long userId, AgreedTerms termsRequest);
  }
  ```
- `UserAppContactApiPort` (`UserAppContactApiPort.java:3-5`):
  ```java
  public interface UserAppContactApiPort {
    void asyncReconnectContactsByMyMobileNumber(Long userId, String mobileNumber);
  }
  ```

#### 3.11.6 왜 3개의 Adapter 인가
하나의 `UserClient` (4개 endpoint) 를 3개의 Port 로 분할. 각 Port 가 다른 UseCase 에서 주입된다:

| Port | 사용 UseCase / 주체 | 호출 빈도 |
|---|---|---|
| `UserApiPort` | `AbstractCreateUserService.updateUserTimeZone` — 회원가입 + (향후 시간대 변경 API) | 회원가입 1회 |
| `TermsApiPort` | `SocialAuthenticationSuccessHandler.syncKakaoAgreement` — 카카오 재로그인 시 약관 sync | 매 카카오 로그인 |
| `UserAppContactApiPort` | `Create[Email/WithSocial]ApplicationService.createUser` — 전화번호 연락처 재연결 | 회원가입 1회 (@Async) |

Single Responsibility Principle 로 port 를 분할했지만 underlying FeignClient 는 공유 — 와디즈 hexagonal 패턴의 일반적 관례.

---

### 3.12 `usercoupon/` — 회원가입 쿠폰 발급·조회

> 📅 **`BE3-555` 로 바뀐 절입니다.**
> `UserCouponClient.java` 가 삭제되고 **`UserClient` 를 쓰도록** 바뀌었습니다.
> 조회 메서드 `getSignupCoupons` 도 새로 들어왔습니다.

- **파일**: `UserCouponAdapter.java`, `dto/UserCouponType.java` (2개만 남았습니다)
- **클라이언트**: 전용 클라이언트가 없습니다. `UserClient` 를 주입받습니다 (`UserCouponAdapter.java:20`)

| 하는 일 | 경로 | 응답 |
|---|---|---|
| 가입 쿠폰 발급 | `POST /api/v1/users/coupon/user/{userId}/type/{couponType}` | `ResponseEntity<Object>` — 본문은 안 쓰고 상태 코드만 봅니다 |
| 가입 쿠폰 목록 조회 | `GET /api/v1/users/coupon/type/{couponType}` | `ResponseEntity<List<JsonNode>>` |

- **인증**: 없습니다. 대신 국적·언어를 **요청 헤더**로 보냅니다 (`wadiz-country`, `wadiz-language`)
- **쿠폰 타입**: `UserCouponType.SIGN_UP("signup")` 하나뿐입니다
- **호출 시점**: `AbstractCreateUserService.giveAwaySignupCouponsAndNotifyCRM(savedUser, locale)`
  - 글로벌 가입이거나 펀딩 마케팅 수신 동의가 있을 때만 부릅니다
  - 결과 `Boolean` 은 `CrmPort.sendSignUpInformationWithCoupon(user, issuedCoupon)` 으로 넘어가 Braze 속성이 됩니다

**실패 처리가 두 메서드에서 다릅니다.**

| 메서드 | 실패했을 때 | 로그 |
|---|---|---|
| `giveAwaySignupCoupons` | `false` 를 돌려줍니다 | **남기지 않습니다** |
| `getSignupCoupons` | 빈 목록을 돌려줍니다 | `log.warn` 으로 남깁니다 |

조회 쪽 주석이 이유를 적어 뒀습니다 —
*"조용히 삼키면 'user-api는 200인데 응답은 []'인 원인 파악이 어려우므로 반드시 로깅한다"*.

> ⚠️ **확인 필요 — 발급 실패는 아무 흔적을 남기지 않습니다.**
> ```java
> } catch (Exception e) {
>   return false;
> }
> ```
> 같은 파일의 조회 메서드는 로그를 남기는데 발급 메서드는 남기지 않습니다.
> 쿠폰이 안 나갔을 때 원인을 찾을 단서가 없습니다.
> 원본 저장소는 읽기 전용이라 고치지 않고 기록만 남깁니다.

> 🔎 **성공 판정이 `HttpStatus.OK` 하나뿐입니다.**
> `201`·`202`·`204` 같은 다른 2xx 응답은 실패로 봅니다.
> 상대 서비스가 정확히 `200` 만 준다는 가정에 기대고 있습니다.

---

## 4. 인증 전파 패턴

### 4.1 사용되는 방식

| 방식 | 사용 adapter | 세부 |
|---|---|---|
| **정적 Bearer (사내 토큰)** | alimtalk, platform, fastmail2 (fast+normal), datasvc | 각각 고유한 `${wadiz.api.*.token}` / `${wadiz.platform.api.token}` / `${wadiz.api.alim-talk.internal-token}` / `${wadiz.api.data.token}`. Adapter 가 `"Bearer " + token` 을 직접 concat. 공통 interceptor 없음. |
| **무인증 (사내망 IP 기반 trust)** | crmgateway, notification, subscribenotification, terms, user (3 adapter), usercoupon, push2 | live 환경에서 전부 `172.31.1.12:9990` 한 호스트. 내부망 trust 로 처리. `wadiz-country`/`wadiz-language` 헤더만 전달 (usercoupon). |
| **사용자 OAuth AccessToken Propagation** | kakao (`getAgreement`) | 소셜 로그인 성공 후 받은 Kakao access_token 을 downstream 으로 그대로 전달 — 사용자 컨텍스트를 요구하는 유일한 외부 호출. |
| **KakaoAK 관리자 키** | kakao (`getScopes`) | `"KakaoAK " + ${wadiz.kakao.adminkey}`. 외부 Kakao 서버에만 특수. |
| **Kakao OAuth refresh_token** | kakao (`renewToken`) | `POST https://kauth.kakao.com/oauth/token` 에 client_id/secret/refresh_token 을 body 로. client_id/secret 은 `OAuth2ClientProperties.getRegistration().get("kakao")` 에서 추출. |

### 4.2 와디즈 사내 서비스 간 토큰 전달 관찰

1. **계정 사용자의 JWT 는 downstream 에 전파되지 않는다.** account 자체가 Authorization Server 이므로 자기가 발급한 사용자 토큰을 굳이 자기 downstream 에 다시 보내지 않는다.
2. **Service-to-Service 토큰 (Bearer) 은 서비스별 pre-shared static secret.** 토큰 자체엔 identity 정보가 없고, Platform 쪽 수신자는 "이 토큰을 가진 호출자는 신뢰" 수준으로만 검증. (자세한 검증은 Platform 내부 — 경계 밖).
3. **mTLS / 서비스메시 X**. 호스트는 live 에서 대부분 **내부 IP `172.31.1.12:9990`** (같은 쿠버 클러스터 호스트 추정) 와 **DMZ `platform.wadiz.kr` / `datasvc.wadiz.kr`** 두 종류로 나뉘며, 전자는 무인증 평문, 후자는 Bearer + HTTPS.
4. **`wadiz-country` / `wadiz-language` 헤더** (`WadizHttpHeaders.java:4-5`) 가 유일한 공통 컨텍스트 헤더. Gateway/BFF 단에서 원본 요청의 locale 를 downstream 까지 전달하기 위한 wadiz 사내 규약 — 현재 account 내에서는 `NormalMailClient` 와 `UserCouponClient` 두 곳에서만 설정한다.
5. **공통 Feign Interceptor 없음** — 각 Adapter 가 직접 header 조립. 결과적으로 토큰 유출 경로가 13군데 (clientId/secret 패턴) 에 흩어져 있다. 중앙화되어 있지 않음은 운영 리스크 (토큰 로테이션 시 각 `application-*.yml` 을 개별 갱신해야 함).

### 4.3 토큰 저장소

- 전부 `src/main/resources/application-{dev,rc,rc2,rc3,stage,live}.yml` 에 **평문 + Jasypt `ENC(...)` 혼재** 로 저장 (`application-local.yml:34` 는 `ENC(...)` 사용; DB 패스워드만 암호화, 외부 서비스 토큰은 평문). Jasypt 활성화: `@EnableEncryptableProperties` (`AuthorizationServiceApplication.java:16`).
- Git 에 평문 토큰이 체크인 되어 있다 (e.g. `application-live.yml:87, 90, 93`). 운영상 재검토 필요 (경계 밖 관측사항).

---

## 5. 경계 및 미탐색 영역

### 5.1 외부 서비스 내부 로직 (경계 밖)

- **Platform (`platform.wadiz.kr`)** 가 `PUT /marketingconsents` 를 받고 내부 DB 에 어떻게 반영하는지, `POST /subscribers` 가 어떤 테이블에 쓰는지는 본 저장소로 알 수 없다. 본 문서는 account 가 보내는 요청까지만 기술.
- **wave.user (`com.wadiz.wave.user`)** 의 `/terms/accepter`, `/contacts/*`, `/time-zone` 핸들러 내부 구현은 레거시 repo 분석 범위.
- **com.wadiz.api.reward** 의 `/user/{userId}/type/{couponType}` 실제 처리 로직은 reward 코어 분석 범위.
- **Braze SDK** 호출은 `crmgateway` 사내 서비스 내부이지, account 가 직접 Braze 에 호출하지 않는다.
- **Kakao 개발자 콘솔 설정** (App admin key 값, OAuth redirect URI 등록) 은 저장소 밖.

### 5.2 dead / 모호한 영역

- ~~**`notification/` 디렉터리**~~ — **해소됐습니다.** 2026-06-26 `BE3-555` 가 패키지를 통째로 지웠습니다.
  예전에 "정의만 남고 죽은 채널"이라고 적어 둔 판단이 맞았습니다.
- ~~**`UserClient.getAcceptedTerms(userId)`**~~ — **해소됐습니다.** `BE3-555` 가 "미사용 terms 조회 메서드"로 함께 지웠습니다.
- **`UserClient.getSignupCoupons` · `SignupTermsQueryClient.getTerms`** — 둘 다 `BE3-555` 이후에 들어온 조회 경로입니다.
  가입 화면이 쓰는 것으로 보이나 상위 호출 그래프는 이 범위에서 확인하지 않았습니다.
- **`KakaoAdapter.renewToken(refreshToken)`** — 호출 지점을 본 저장소에서 즉시 확인 못함. 본 externalservice 범위 밖의 token scheduler / refresh 흐름에서 쓰일 가능성.
- **`CreateUserWithSocialAccountApplicationService.updateKakaoAccountAboutAgreement`** — `@Deprecated` 주석 (`:108-110`). `kakaoPort.isFriendsScopeAgreed` 호출이 이 메서드에 남아있지만 사용 여부는 상위 호출 그래프 추적 필요.

### 5.3 계약 불일치 / TODO

- `GetCountryFromIPPort` doc 은 "KR 반환" 명시하지만 구현은 null 반환 (`DataServiceAdapter.kt:20`, 위 3.3).
- `TermsAdapter` 가 "userAgeCheck" 를 제거하는 이유 주석 (`:17`, "terms api doesn't support this").
- `UserToSubscriberRequestConverter.photoId = ""` + TODO 주석 (`:20`).
- `SubscribeNotificationAdapter` Reactive TODO (`:23-28`).
- ~~`PublishType.SUBSCRBIER_GROUP`·`PublisherType.EXTENRAL_SYSTEM` (오타)~~ — **해소됐습니다.** 두 열거형이 `notification/` 패키지와 함께 삭제됐습니다.
- FeignClient 이름 `subsciber-client` 의 오타는 **그대로 남아 있습니다** (`subscribenotification/SubscribeNotificationClient.java:11`).
- `MarketingConsentClient.getMarketingConsent` 는 정의만 있고 `MarketingConsentAdapter` 는 `updateMarketingConsent` 만 구현 (`MarketingConsentAdapter.java:18-23`). get 메서드는 호출자 없음.

### 5.4 운영 리스크 요약 (관측된 범위만)

- 외부 서비스 호출 대부분 retry / circuit breaker / timeout 미설정 (Feign 기본값 의존).
- **실패 처리가 어댑터마다 제각각입니다.**

  | 어댑터 | 실패했을 때 |
  |---|---|
  | `crmgateway` | 로그만 남김 |
  | `datasvc` | `null` 반환 |
  | `usercoupon` (발급) | `false` 반환, 로그 없음 |
  | `usercoupon` (조회) · `terms` (조회) | 빈 목록 반환, `log.warn` |
  | `subscribenotification` · `terms`(쓰기) · `notichannel` | 예외를 그대로 올림 |
  | `push2` | `RuntimeException` |
  | `UserAppContactApi` | `warn` 남기고 무시 |
  | `fastmail2` | `EmailNotSentException` |
- **설정 파일에 평문 토큰이 남아 있습니다.** `application-rc.yml` 의 `wadiz.api.datasvc.token` 이 그 예입니다.
  다만 `BE3-410`(2026-05-28)이 **로컬 비밀값을 환경 변수로 빼냈습니다** — `application-local.yml` 은 `${data_platform_api_token}` 처럼 참조만 합니다.
  값은 이 문서에 옮기지 않았습니다.
- ~~두 "terms" 어댑터가 동일 서비스를 다른 경로로 호출~~ — **해소됐습니다.**
  `BE3-555` 가 `TermsApiAdapter`·`TermsApiPort` 를 지우고 `TermsPort.acceptTerms` 하나로 일원화했습니다.
- ~~`notification/` 디렉터리는 dead 로 보임~~ — **해소됐습니다.** 패키지가 삭제됐습니다.
- **쿠폰 발급 실패가 로그를 남기지 않습니다** (`UserCouponAdapter.giveAwaySignupCoupons`).
  같은 파일의 조회 메서드는 `log.warn` 을 남깁니다. 3.12 절을 봅니다.
- **`application-rc.yml` 에 메일 설정이 없습니다** (`mail-fast`·`mail-normal`). 확인이 필요합니다.

본 문서는 `src/main` 의 정적 코드 관측만으로 작성했습니다.
실행 시점의 호출 그래프, 스프링 빈이 실제로 뜨는지, 오가는 HTTP 트래픽 기록은 확인하지 않았습니다.

**클라우드 환경(`cdev`·`clive`) 값도 확인하지 못했습니다.**
`BE3-410`(2026-05-28) 이후 그 값들은 저장소가 아니라 쿠버네티스 설정맵에 있습니다.
