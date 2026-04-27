# Flow: 회원가입 (이메일 · 소셜)

> 신규 사용자가 와디즈 계정을 생성하는 체인. 이메일 확인코드 발송/검증 → 약관 동의 → 사용자 생성 → 알림·Braze·쿠폰 연동 후처리 → 자동 로그인까지 IdP(`kr.wadiz.account`) 안에서 완결.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/apps/account/src/entities/oauth/lib/socialUtil.js` (소셜 분기)
  - `kr.wadiz.account/.../inbound/SignUpController.java:59-155` (가입 REST)
  - `kr.wadiz.account/.../inbound/AuthenticationCodeV1Controller.java:22-45` (코드 발송/검증)
  - `kr.wadiz.account/.../domain/applicationservice/CreateUserApplicationService.java:62-90`
  - `kr.wadiz.account/.../domain/applicationservice/AbstractCreateUserService.java:25-80`
- **외부 경계**: `subscribeNotificationPort`, `crmPort`(Braze), `userCouponPort`(reward), `platformApiPort`, `userApiPort`, `userAppContactApiPort`, `termsPort`, `servletPort`, `emailValidationRepositoryPort` — 모두 outbound port 인터페이스. 실구현은 `adapters/outbound/externalservice/*` 참조 ([`docs/kr.wadiz.account/api-details/external-services.md`](../kr.wadiz.account/api-details/external-services.md)).

---

## 개요 — 2가지 가입 경로

| 경로 | 엔드포인트 | 사전 검증 |
|---|---|---|
| **이메일 가입** | `POST /api/v1/users` | `POST /api/v1/authentication-code` → 코드 발송, `GET /api/v1/authentication-code/{code}/valid` → 검증 |
| **소셜 가입** | `POST /api/v1/social-users` | 카카오/구글/Apple OAuth2 Login (세션에 프로필 사전 저장) |

---

## 1. Client Trigger (FE)

### 1.1 가입 페이지
- `apps/account/src/pages/(auth)/signup/...` (Vite Thymeleaf 없음 — SPA)
- 소셜 유틸: `socialUtil.js`에서 지역별 활성 provider 분기 (`signIn: ['google','kakao']` 등)

### 1.2 이메일 코드 발송·검증
```http
POST https://account.wadiz.kr/api/v1/authentication-code
Content-Type: application/json
{ "email": "user@example.com", "language": "ko", ... }

GET  https://account.wadiz.kr/api/v1/authentication-code/{code}/valid?email=...
```

### 1.3 가입 제출
```http
POST https://account.wadiz.kr/api/v1/users
Content-Type: application/json
{
  "email": "...", "password": "...", "nickname": "...",
  "language": "ko", "country": "KR",
  "agreedTerms": [{ "termsId": "...", "isAgreed": true }, ...]
}
```

---

## 2. IdP — `kr.wadiz.account`

### 2.1 Authentication Code (이메일 확인)
```java
// adapters/inbound/AuthenticationCodeV1Controller.java:22
@RestController
@RequestMapping("/api/v1")
public class AuthenticationCodeV1Controller {
    private final SendAuthenticationCodeViaEmailUsecase sendAuthenticationCodeViaEmailUsecase;
    private final CheckAuthenticationCodeValidityUsecase checkAuthenticationCodeValidityUsecase;

    @PostMapping("/authentication-code")
    public ResponseEntity<?> sendCode(@Valid @RequestBody SendCodeCommand cmd) {
        sendAuthenticationCodeViaEmailUsecase.send(...);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/authentication-code/{code}/valid")
    public ResponseEntity<?> check(@PathVariable String code, @RequestParam String email) {
        checkAuthenticationCodeValidityUsecase.check(...);
        return ResponseEntity.ok().build();
    }
}
```
- 코드 저장: **Redis** (`EmailValidationCodeRepository`) — TTL 기반
- 발송: `fastmail2` outbound adapter 경유
- 에러 상황: "공백 이메일 / 형식 오류 / 이미 사용 중 / 탈퇴 90일 미경과" 등 분기

### 2.2 `SignUpController#signUpWithEmail`
```java
// adapters/inbound/SignUpController.java:79
@PostMapping(value = "/users", consumes = MediaType.APPLICATION_JSON_VALUE)
public ResponseEntity<SignUpSuccessDto> signUpWithEmail(
        @Valid @RequestBody EmailSignUpDto dto,
        @CurrentDevice DeviceType deviceType,
        HttpServletRequest req, HttpServletResponse res, HttpSession session) {

    Locale locale = new Locale(dto.getLanguage(), dto.getCountry());
    EmailSignUpCommand cmd = emailSignUpDtoToCommandMapper.toCommand(dto, locale);

    // ★ 세션 + 이메일 → Redis 에 저장된 검증 상태 확인
    checkEmailAuthentication(session.getId(), cmd.getEmail());

    String signUpCompleteUri = getSignUpCompleteUri(req, res);

    // 핵심: 생성 + 자동 로그인
    User user = createUserApplicationService.signUpWithEmail(cmd, deviceType, locale);

    // Best-effort 후처리 (예외 무시)
    try { createUserWithSocialAccountApplicationService.updateUserTimeZone(user); } catch (...) {}
    try { createUserApplicationService.doRemainingWork(user); } catch (...) {}

    return ResponseEntity.created(URI.create("/api/v1/users/" + user.getUserId()))
        .body(new SignUpSuccessDto(signUpCompleteUri));
}
```

### 2.3 `CreateUserApplicationService` (이메일)
```java
// domain/applicationservice/CreateUserApplicationService.java:64
@Transactional("wadizTransactionManager")
public User signUpWithEmail(EmailSignUpCommand dto, DeviceType deviceType, Locale locale) {
    User savedUser = this.signUp(dto, deviceType, locale);              // 공통 signUp (부모)
    eventPublisher.publishEvent(new UserCreatedEvent(savedUser));
    servletPort.login(savedUser, dto.getPassword());                     // ★ 바로 로그인 (세션 생성)
    return savedUser;
}

@Override
User createUser(Object object, DeviceType deviceType, Locale locale) {
    EmailSignUpCommand dto = (EmailSignUpCommand) object;
    User user = User.createUserWithEmail(
        dto.getEmail(), dto.getNickname(), dto.getPassword(), deviceType, locale);
    User savedUser = userRepositoryPort.create(user);                    // ★ DB INSERT (User + Password + Profile)

    // 내 휴대폰 번호로 연락처 재연결 (비동기)
    userAppContactApiPort.asyncReconnectContactsByMyMobileNumber(
        savedUser.getUserId(), savedUser.getMobilePhoneNumber());
    return savedUser;
}
```

### 2.4 공통 signUp (`AbstractCreateUserService`)
```java
// :29
public <T extends WithAgreedTerms> User signUp(T object, DeviceType deviceType, Locale locale) {
    User savedUser = createUser(object, deviceType, locale);             // 자식 구현
    savedUser = saveTerms(savedUser, object.getAgreedTerms());           // 약관 동의 저장
    registerNotification(savedUser);                                     // 알림 구독 등록
    registerUnsubscribeKeyForBraze(savedUser);                           // Braze 키
    giveAwaySignupCouponsAndNotifyCRM(savedUser, locale);                // 가입 쿠폰 + CRM
    return savedUser;
}

private User saveTerms(User savedUser, AgreedTerms terms) {
    termsPort.acceptTerms(savedUser.getUserId(), terms);                 // → terms 외부 서비스 HTTP
    savedUser.setAgreedTerms(terms.getTermsList());
    return savedUser;
}

private void registerNotification(User user) {
    subscribeNotificationPort.registerNotification(user);                // → platform notification
    user.getServiceWithMarketingAgreement()
        .forEach(code -> platformApiPort.updateMarketingConsent(code, user.getUserId()));
}

private void registerUnsubscribeKeyForBraze(User user) {
    crmPort.setUnsubscribeKey(user.getUserId());                         // → Braze (crmgateway)
}

private boolean giveAwaySignupCouponsAndNotifyCRM(User savedUser, Locale locale) {
    if (isGlobal(locale) || isAgreedFundingMarketingTerms(savedUser)) {
        return userCouponPort.giveAwaySignupCoupons(savedUser);          // → com.wadiz.api.reward
    }
    return false;
}
```

### 2.5 소셜 가입 분기 (`/api/v1/social-users`)
- 사전 OAuth2 Login 으로 세션에 소셜 프로필 저장됨
- `CreateUserWithSocialAccountApplicationService.signUpWithSocialAccount` 호출
  - 카카오 약관 형식 → terms API 형식 변환 (kakao mapping 주의)
  - `SocialAccount` 테이블에 연결 저장
  - 이후 공통 `signUp` 체인 재사용 (약관·알림·Braze·쿠폰)

---

## 3. 외부 서비스 연동 (회원가입 후처리)

| Port | 실구현 (outbound adapter) | 용도 |
|---|---|---|
| `termsPort` | `externalservice/terms` | 약관 동의 저장 (wave.user terms 서비스) |
| `subscribeNotificationPort` | `externalservice/subscribenotification` | 알림 구독 등록 |
| `platformApiPort` | `externalservice/platform` | 마케팅 동의 상태 전파 |
| `crmPort` | `externalservice/crmgateway` | Braze 언서브 키 |
| `userCouponPort` | `externalservice/usercoupon` | 가입 쿠폰 발급 (`com.wadiz.api.reward`) |
| `userApiPort` | `externalservice/user` | `com.wadiz.wave.user` 호출 |
| `userAppContactApiPort` | 동상 | 연락처 재연결 (내 번호 기준) |
| `servletPort` | 내부 래퍼 | SecurityContext + session 조립 |

---

## 4. DB

### 4.1 주요 INSERT (JPA)
`UserProfile`, `Password`, `SocialAccount`(소셜 시), 약관 동의 레코드 등.

### 4.2 핵심 테이블

| 테이블 | 역할 |
|---|---|
| `UserProfile` | 기본 사용자 (username=email, nickname, country, language, userStatus='NM', createAt 등) |
| `Password` | 비밀번호 해시 (userId 1:1) |
| `SocialAccount` | 소셜 provider 연결 (카카오/구글/Apple) |
| `MakerInfo` | 메이커 신청 시 추가 (가입 시 비어있음) |
| `PhotoEntity` | 기본 프로필 이미지 |

### 4.3 Redis
- `EmailValidationCode` — `{email:code}` 매핑 + TTL
- 세션 ID 연결로 "세션에서 발급된 코드만 검증 유효" 제어 (`checkEmailAuthentication(session.getId(), email)`)

### 4.4 외부 저장 (outbound)
- **Terms 동의**: `com.wadiz.wave.user` terms 서비스 (내부 API 호출)
- **Braze 언서브 키**: Braze SaaS
- **쿠폰**: `com.wadiz.api.reward` (CouponIssue transaction)

---

## 엔드투엔드 시퀀스

### 이메일 가입
```
[FE: apps/account/signup]
   │ ① POST /api/v1/authentication-code    (이메일, 언어)
   ▼
[kr.wadiz.account — AuthenticationCodeV1Controller#sendCode]
   │
   └─ SendAuthenticationCodeViaEmailUsecase.send
       ├─ Redis: SET emailValidation:{sessionId}:{email} = {code} EX TTL
       └─ fastmail2: 이메일 발송

[FE: 사용자가 코드 입력]
   │ ② GET /api/v1/authentication-code/{code}/valid?email=...
   ▼
[AuthenticationCodeV1Controller#check]  → 200 OK or InvalidAuthenticationCodeException

[FE: 약관 동의 체크 + 비밀번호 입력 후 제출]
   │ ③ POST /api/v1/users
   │    body: { email, password, nickname, language, country, agreedTerms[...] }
   ▼
[SignUpController#signUpWithEmail]                    (SignUpController.java:79)
   │  checkEmailAuthentication(sessionId, email)      — Redis 확인
   │
   └─ CreateUserApplicationService#signUpWithEmail    (CreateUserApplicationService.java:64)
        │  @Transactional("wadizTransactionManager")
        │
        ├─ AbstractCreateUserService#signUp           (:29)
        │    ├─ createUser(cmd)                       — ★ JPA INSERT
        │    │     ├─ INSERT INTO UserProfile (email, nickname, country, ...)
        │    │     ├─ INSERT INTO Password (userId, hash)
        │    │     └─ userAppContactApiPort.asyncReconnectContactsByMyMobileNumber  (비동기)
        │    │
        │    ├─ saveTerms(user, terms)                — termsPort.acceptTerms(...)  → wave.user terms API
        │    ├─ registerNotification(user)            — subscribeNotificationPort + platformApiPort.updateMarketingConsent (서비스별)
        │    ├─ registerUnsubscribeKeyForBraze(user)  — crmPort.setUnsubscribeKey  → Braze
        │    └─ giveAwaySignupCouponsAndNotifyCRM     — userCouponPort.giveAwaySignupCoupons → reward-api
        │
        ├─ publishEvent(new UserCreatedEvent)          — 내부 이벤트 (리스너들이 추가 처리)
        │
        └─ servletPort.login(user, password)           — 자동 로그인 (세션·쿠키 생성)

   [after response, best-effort async]
   ├─ updateUserTimeZone(user)   — 실패해도 무시
   └─ doRemainingWork(user)      — @Async

   → 201 Created, body: { signUpCompleteUri }
   → FE: 브라우저 세션 쿠키 자동 설정되어 있으므로 로그인 상태로 authorize 재개
```

### 소셜 가입
```
(카카오/구글/Apple OAuth2 Login 완료)
   │  세션에 소셜 프로필 + 제공자별 약관 원본 저장됨
   ▼
[FE: 와디즈 약관 추가 동의 화면 → 제출]
   │ POST /api/v1/social-users
   ▼
[SignUpController#signUpWithSocialAccount]            (:111)
   │  사회약관(kakao format) → 와디즈 약관 형식 변환 (`socialSignUpDtoToCommandMapper`)
   │
   └─ CreateUserWithSocialAccountApplicationService#signUpWithSocialAccount
        ├─ createUser           — INSERT UserProfile + SocialAccount (ProviderId, ProviderUserId)
        └─ 나머지는 email 가입과 동일한 공통 signUp 체인
```

---

## 경계·미탐색

1. **`checkEmailAuthentication` 구현 상세** — `EmailValidationCodeRepository` 의 key 구성(`sessionId` vs `email` 우선순위) 과 TTL 은 Redis adapter 내부.
2. **UserCreatedEvent 구독자** — 내부 Spring `@EventListener` 들이 어떤 후속 작업을 하는지 (통계·분석·추가 프로비저닝) 별도 추적.
3. **`servletPort.login` 구현** — Spring Security Context + session 직접 조립 vs `SecurityContextRepository` 사용 여부.
4. **90일 탈퇴 후 재가입 제한** — `wave.user` 측의 `inactiveAccount` / `privacyDestruction` 상태 와의 연동 (회원 생성 전 조회 호출).
5. **글로벌 가입 흐름** — Locale 이 KR 이 아닐 때 쿠폰 발급 조건, 소셜 Provider 집합 차이, 약관 구성 차이.
6. **Apple Sign in with Secret Key 관리** — `com.wadiz.signin` 클라이언트 ID 뿐, 서버 키 `AuthKey.p8` 위치·보안 관리 체계는 별도.
7. **이메일 재발송 / 코드 만료 시 UX** — FE 재시도 로직과 서버 rate-limit 정책 (Limiter 중복?) 확인 필요.
