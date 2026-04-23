# Flow: 알림 (푸시·알림톡·이메일 + 앱 알림센터)

> 와디즈 전체 알림 체인. **발행자** (funding/reward/wave.user/account 등) → **플랫폼 알림 서비스** → **채널별 게이트웨이** (APNs/FCM, Kakao AlimTalk, Email) + **알림센터** (앱 인박스).

## 기록 범위
- **읽은 파일**:
  - `kr.wadiz.account/.../externalservice/subscribenotification/` (port + adapter)
  - `kr.wadiz.account/.../externalservice/push2/` (푸시 게이트웨이)
  - `kr.wadiz.account/.../externalservice/alimtalk/` (카카오 알림톡)
  - `kr.wadiz.account/.../externalservice/fastmail2/` (이메일)
  - `com.wadiz.api.funding/.../adapter/batch/.../billkeyverifyremind/...` (예시 발행)
  - `com.wadiz.api.reward/.../batch/couponexpirationnotification/` (쿠폰 만료 알림)
  - `com.wadiz.wave.user/.../push/PushTargetController.java` (푸시 대상 조회)
  - `com.wadiz.wave.user/.../message/MessageController.java` (알림톡 수신자 관리)
  - `wadiz-frontend/apps/global/src/pages/my-wadiz/settings/notification/` (설정 UI)
- **외부 경계**: 플랫폼 알림 서비스(`platform.wadiz.kr` 의 notification 부분) 내부 로직, 실 FCM/APNs/Kakao/메일 게이트웨이.

---

## 1. 개념 맵

```
┌───────────────────────────────────────────────────────────────────┐
│  발행자 (여러 서비스)                                                │
│   funding, reward, wave.user, account, admin, community, store ...   │
└────────────────────┬──────────────────────────────────────────────┘
                     │ HTTP POST (outbound port: subscribenotification/push2/alimtalk/fastmail2)
                     │ 또는 Kafka publish
                     ▼
┌───────────────────────────────────────────────────────────────────┐
│  플랫폼 알림 서비스 (platform.wadiz.kr)                              │
│  - 수신자 토큰·설정 조회                                              │
│  - 채널별 라우팅 (push / alimtalk / email / inbox)                   │
│  - 템플릿 렌더링 + i18n                                              │
└────────┬────────────┬─────────────┬─────────────┬─────────────────┘
         ▼            ▼             ▼             ▼
    [APNs/FCM]   [Kakao API]    [메일 GW]      [인박스 DB]
     (푸시)       (알림톡)        (이메일)       (앱/웹 인박스)
```

---

## 2. 발행자 패턴

### 2.1 com.wadiz.api.funding — 빌키 만료 알림 배치
[docs/_flows/funding-autopay.md](./funding-autopay.md) 참조.
```java
// adapter/batch/.../billkeyverifyremind/BillkeyVerifyRemindJobConfig.java
.skip(NotificationApiClientException.class).skipLimit(Integer.MAX_VALUE)
```
- Reader → 만료 임박 빌키 대상 → Writer → 알림 API 호출
- 실패해도 skip (전체 배치 보호)

### 2.2 com.wadiz.api.reward — 쿠폰 만료 Composite Sender
[docs/com.wadiz.api.reward/api-details/batch.md](../com.wadiz.api.reward/api-details/batch.md) 참조.
- `CouponExpirationNotificationJob` 가 Push / AlimTalk / Email 세 개 Sender 를 Composite 로 묶어 동시 발송
- `LocaleConstants` + `RequestBodyTranslator` 로 i18n 분기

### 2.3 com.wadiz.wave.user — 푸시 대상 조회
```java
// com.wadiz.wave.user/.../push/PushTargetController.java
@RequestMapping("/api/v1/users/pushTarget")
  POST /count           // 대상 수
  POST /list            // 대상 목록
```
다른 서비스가 "어느 사용자에게 푸시를 보낼지" 조회할 때 사용.

### 2.4 com.wadiz.wave.user — 알림톡 수신자 등록
```java
// com.wadiz.wave.user/.../message/MessageController.java
@PostMapping("/api/v1/users/message/alim-talk/receiver/{userId}/sign-up")
```
가입 직후 사용자별 알림톡 수신 설정.

### 2.5 kr.wadiz.account — outbound port 4종
```
oauth2/adapters/outbound/externalservice/
├── subscribenotification/   # 알림 구독 등록/해제
├── push2/                   # 푸시 발송
├── alimtalk/                # 카카오 알림톡
└── fastmail2/               # 이메일 발송
```
가입·로그인·비밀번호 재설정 등 계정 이벤트 발생 시 사용.

---

## 3. 설정 UI (wadiz-frontend)

### 3.1 서포터 알림 설정
`apps/global/src/pages/my-wadiz/settings/notification/`
- `MyWadizSettingsNotificationPage.tsx` — 채널별 on/off 스위치
- `MyWadizSettingsNotificationNewsPage.jsx` — 뉴스/소식 카테고리 세분
- `MarketingNotificationSettingsContainer.jsx` — 마케팅 동의 별도

### 3.2 설정 저장 경로 (추정)
사용자 알림 설정은 플랫폼 알림 서비스에 저장 (`platform.wadiz.kr` API). wave.user 의 `UserSettings` 와 구분.

---

## 4. 채널별 세부

| 채널 | 용도 | 경계 |
|---|---|---|
| **앱 푸시** (APNs/FCM) | 긴급 알림, 결제 완료, 배송 시작 | `push2` adapter · external SaaS |
| **알림톡** (Kakao) | 결제 영수증, 친구 초대, 법정 의무 안내 | Kakao Biz 메시지 API |
| **이메일** | 상세 알림, 뉴스레터, 정책 변경 안내 | fastmail2 · 외부 SMTP/ESP |
| **앱/웹 인박스** | 히스토리 보관, 재열람 | 플랫폼 inbox 서비스 |
| **브라우저 푸시** | (사용 여부 불확실) | Service Worker + push2 |

---

## 5. DB (추정)
플랫폼 알림 서비스 내부. 원장·대기열·발송 이력·사용자 구독 설정 등. 본 레포에서는 확인 불가.

와디즈 repos 내 추적 가능한 보조 데이터:
- `wave.user`: `UserSettings`, 알림톡 수신자 테이블
- `reward-batch`: 쿠폰 만료 알림 발송 대상 queue
- `funding-batch`: 빌키·위시 프로젝트 마감 알림 대상

---

## 엔드투엔드 시퀀스

### A. 회원가입 → 환영 알림
```
[kr.wadiz.account — CreateUserApplicationService#signUp]
   ├─ subscribeNotificationPort.registerNotification(user)
   │     └─ HTTP POST → platform notification /api/... (사용자 구독 등록)
   │
   ├─ platformApiPort.updateMarketingConsent(serviceCode, userId)
   │     └─ 마케팅 동의 상태 전파
   │
   └─ crmPort.setUnsubscribeKey(userId)       → Braze 언서브 키

[후속: 환영 쿠폰·이벤트 알림 발송은 플랫폼이 자체 트리거]
```

### B. 결제 성공 → 다중 채널 알림
```
[com.wadiz.api.funding — 결제 승인 직후]
   │ (이벤트: PaymentCompleted publish — Kafka 추정)
   ▼
[플랫폼 알림 서비스 — Event consumer]
   ├─ 사용자 구독 설정 조회
   ├─ 템플릿 렌더: "{nickname}님, {campaign} 결제가 완료되었습니다"
   ├─ 채널 분기:
   │   ├─ (push 허용) FCM/APNs push2 호출
   │   ├─ (알림톡 허용) Kakao Biz 호출
   │   └─ (이메일 허용) fastmail2 호출
   └─ 인박스 INSERT (history)
```

### C. 쿠폰 만료 임박 (스케줄 배치)
```
[reward-batch — CouponExpirationNotificationJob (매일)]
   │ Reader: SELECT 사용 가능 & 만료 D-N 쿠폰 + 소유자
   ▼
[Writer: CompositeCouponExpirationSender]
   ├─ CouponExpirationPushSender        → push2 adapter
   ├─ CouponExpirationAlimTalkSender    → Kakao
   └─ CouponExpirationNormalMailSender  → fastmail2

   (실패 시 skip, skipLimit=MAX — 전체 배치 보호)
```

### D. 사용자 설정 변경
```
[FE: my-wadiz/settings/notification 스위치 토글]
   │ PUT /platform/notification/settings
   │   body: { category: 'marketing-funding', enabled: true }
   ▼
[platform.wadiz.kr]
   └─ 사용자 구독 설정 업데이트 → 이후 발행 시 반영
```

---

## 경계·미탐색
1. **플랫폼 알림 서비스 실체** — 별도 repo. 본 repos 에 없음.
2. **이벤트 전달 방식** — HTTP 동기 vs Kafka async 섞여 있음. 각 발행자별 선택 기준.
3. **알림 템플릿 관리** — 코드형 vs DB형 + i18n 리소스 위치.
4. **수신거부·GDPR 대응** — 탈퇴 시 인박스/큐 정리, Braze 언서브 키 주기.
5. **법정 필수 알림** (영수증·약관 변경) — 유저 설정 무관 발송 예외 로직.
6. **앱 인박스 UI** — [docs/wadiz-android.md](../wadiz-android.md), [docs/wadiz-ios.md](../wadiz-ios.md) 의 NotificationCenter feature 모듈 참조.
7. **실시간 채널 (WebSocket/SSE) 여부** — 현재 관측 범위 내 확인 불가, 대부분 poll + push 구조로 보임.
