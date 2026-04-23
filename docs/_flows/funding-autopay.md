# Flow: 자동결제 (Billkey 간편결제 + All-or-Nothing 예약결제)

> 서포터가 카드 정보를 저장(빌키 발급)하고, 펀딩 마감 후 목표 달성 시 저장된 빌키로 자동 결제가 실행되는 체인. 간편결제 등록 / 결제 수단 변경 / 예약결제 실행 / 빌키 만료 알림 4개 축.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/funding.service.ts:1160-1170` (결제 수단 변경 FE)
  - `wadiz-frontend/packages/api/src/web/funding/supporters.service.ts:43` (최근 결제 수단)
  - `com.wadiz.api.funding/adapter/application/.../simplepay/SimplePayController.java:17-70`
  - `com.wadiz.api.funding/adapter/application/.../billkey/BillkeyInternalController.java:13-25`
  - `com.wadiz.api.funding/adapter/application/.../supporter/SupporterController.java:104` (`PUT /my/fundings/{id}/pay-by`)
  - `com.wadiz.api.funding/adapter/application/.../paymentprogress/PaymentProgressController.java:13-26`
  - `com.wadiz.api.funding/adapter/batch/.../billkeyverifyremind/BillkeyVerifyRemindJobConfig.java:1-75`
  - `docs/nicepay-api.md` (BillingController `/api/{apiVersion}/approval`)
- **외부 경계**: `simplePayProxy`, `paymentProgressProxy` 는 funding-core jar 위임. 실제 PG(나이스페이) billing 호출은 nicepay-api 서비스에서 수행.

---

## 전체 개요 — 4가지 흐름

| # | 흐름 | 트리거 | 핵심 엔드포인트 | 담당 서비스 |
|---|---|---|---|---|
| 1 | **빌키 등록** | 서포터가 "간편결제 등록" 선택 | `POST /api/simple-pay/card` → PG 빌키 발급 | funding → nicepay-api |
| 2 | **간편결제 비밀번호** | 빌키 등록 직후 | `POST /api/simple-pay/{token}/passcode` | funding |
| 3 | **결제 수단 변경** | 예약 상태 주문에서 다른 카드로 전환 | `PUT /api/supporters/my/fundings/{id}/pay-by` | funding |
| 4 | **예약결제 실행** | 펀딩 마감 +1일 / +2일 (배치) | 내부 (funding 배치/스케줄) → nicepay-api `POST /api/{apiVersion}/approval` | funding + nicepay-api |
| 부수 | **빌키 만료 알림** | 카드 만료 예정 (배치) | `BillkeyVerifyRemindJob` | funding 배치 |

---

## 1. Client Trigger (FE)

### 1.1 빌키 등록 (서포터 카드 저장)
- FE 에서 PG SDK 로 카드 번호 인증 후 funding 으로 빌키 생성 요청.
- 사용자 경험: 결제 모달 내 "간편결제 등록" 체크박스 + 카드 정보 입력.

### 1.2 결제 수단 변경
```ts
// packages/api/src/web/funding.service.ts:1167
export const putChangePaymentBy = ({ backingPaymentID, billKey }) => {
  return PUT(`/web/apip/funding/supporters/my/fundings/${backingPaymentID}/pay-by`, { billKey });
};
```

### 1.3 최근 결제 수단 조회
```ts
// packages/api/src/web/funding/supporters.service.ts:43
export const getMyRecentPayBy = () =>
  GET('/web/apip/funding/supporters/my/recent-pay-by');
```

---

## 2. Hub — `com.wadiz.web`

위 모든 경로(`/web/apip/funding/...`)는 **ApiProxyServlet** 투명 프록시. `/my/fundings/*` 는 `bearerTokenAuthenticationFilter` 추가 (웹/앱 공유).

com.wadiz.web 의 Java 에서 별도 처리 없음.

---

## 3. Backend Service — `com.wadiz.api.funding`

### 3.1 `SimplePayController` — 빌키 등록/조회/삭제/비밀번호
```java
// adapter/application/.../simplepay/SimplePayController.java:17
@RestController
@RequestMapping("/api/simple-pay")
public class SimplePayController {
    private final SimplePayProxy simplePayProxy;

    @PostMapping("/card")                                   // :27  빌키 생성
    public ResponseWrapper<CreateBillkeyResponse> createBillkey(@RequestBody CreateBillkeyRequest request) {
        final CreateBillkeyCommand command = SimplePayRequestConverter.INSTANCE.toCommand(request).toBuilder()
            .userId(SecurityUtils.currentUserId())
            .build();
        return ResponseWrapper.ok(CreateBillkeyResponse.builder()
            .token(simplePayProxy.createBillKey(command))
            .build());
    }

    @GetMapping("/card")                                    // :40  빌키 조회
    public ResponseWrapper<BillkeyManagerResponse> getBillkeyManager() {
        final BillkeyManager billkeyManager = simplePayProxy.getBillkeyManager(SecurityUtils.currentUserId());
        return ResponseWrapper.ok(SimplePayResponseConverter.INSTANCE.toResponse(billkeyManager));
    }

    @DeleteMapping("/card")                                 // :49  빌키 삭제
    public ResponseWrapper<Void> removeBillkeyManager() {
        simplePayProxy.removeBillkeyManager(SecurityUtils.currentUserId());
        return ResponseWrapper.ok();
    }

    @PostMapping("/{token}/passcode")                       // :59  비밀번호 등록
    public ResponseWrapper<Void> registerPasscode(@PathVariable UUID token,
                                                  @RequestBody @Valid RegisterPasscodeRequest request) {
        simplePayProxy.registerPasscode(RegisterPasscodeCommand.builder()
            .userId(SecurityUtils.currentUserId())
            .passcode(request.getPasscode())
            .token(token)
            .build());
        return ResponseWrapper.ok();
    }
}
```

### 3.2 `BillkeyInternalController` — 카드 만료 사전 검증
```java
// adapter/application/.../billkey/BillkeyInternalController.java:13
@RequestMapping("/api/internal/billkey")
public class BillkeyInternalController {
    @PostMapping("/card-expire-verification")              // :20
    ...
}
```
내부(운영/배치) 호출용. 카드 유효기간 만료 임박 빌키 검출.

### 3.3 `SupporterController#modifyPayBy` — 주문 결제 수단 변경
```java
// supporter/SupporterController.java:104
@PutMapping("/my/fundings/{backingPaymentId}/pay-by")
public ResponseWrapper<?> modifyPayBy(@PathVariable Integer backingPaymentId,
                                      @RequestBody PayByModifyCommand command) {
    // supporterProxy.modifyPayBy(...) — billKey 를 BackingPayment 에 교체
}
```

### 3.4 `PaymentProgressController` — 결제 예약 진행률
```java
// paymentprogress/PaymentProgressController.java:13
@RequestMapping("/api/payment-progress")
public class PaymentProgressController {
    @GetMapping("/campaigns/{campaignId}/relevant-info")   // :23
    ...
}
```
마감 이후 "전체 중 몇 %가 결제 승인 완료" 진행률 조회 (메이커 대시보드).

### 3.5 빌키 만료 알림 배치 — `BillkeyVerifyRemindJob`
```java
// adapter/batch/.../billkeyverifyremind/BillkeyVerifyRemindJobConfig.java:21
@Configuration
public class BillkeyVerifyRemindJobConfig {
    @Bean
    public Step billkeyVerifyRemindStep(BillkeyVerifyRemindReader reader,
                                        BillkeyVerifyRemindWriter writer) {
        return stepBuilderFactory.get("billkeyVerifyRemindStep")
            .<BillkeyVerifyRemindTarget, BillkeyVerifyRemindTarget>chunk(1000)
            .reader(reader)
            .writer(writer)
            .faultTolerant()
            .skip(NotificationApiClientException.class)
            .skipLimit(Integer.MAX_VALUE)
            ...
    }
}
```
- 1000건 청크, 알림 실패는 스킵 (무한 skipLimit) → 알림 실패가 전체 배치를 막지 않도록.
- `BillkeyVerifyRemindReader` 가 만료 예정 빌키 목록 조회 → `Writer` 가 알림 서비스 호출.

---

## 3.6 예약결제 실행 (All-or-Nothing 마감 후)
정확한 엔트리 Job 은 본 검색 범위에서 이름만 발견되지 않음. 단, 데이터와 API 관점 확인 가능한 사실:

- **예약 일자**: `FundingMapper.xml#fundingListSearch` 에서 `WhenPayFor = WhenHoldTo + 1일`, `WhenFinalPayFor = WhenHoldTo + 2일` 계산.
- **예약 결제 대상**: `BackingPayment.PayStatus` 가 '예약' 상태 집합 (내부 코드값) 으로 남아 있는 건.
- **실제 결제 승인 호출**: `com.wadiz.api.funding` → `nicepay-api` `/api/{apiVersion}/approval` (Billing 방식)
  - [docs/nicepay-api.md](../nicepay-api.md) `BillingController.approval`

---

## 4. DB

### 4.1 주요 테이블

| 테이블 | 역할 |
|---|---|
| `BillkeyManager` (혹은 동등) | 사용자별 빌키 메타 (BillKey, 카드사, 마지막 4자리, 만료일, Passcode 해시) |
| `BackingPayment` | 주문 메인 — `PayStatus`(예약/완료/실패), `BillKey`, `WhenPayFor`, `BillingAmount` |
| `SimplePaySession` / `RegisterPasscodeToken` | 간편결제 세션 토큰 (UUID) — TTL Redis 가능성 |
| `Campaign` | `WhenHoldTo`, `IsAllOrNothing` (예약일 계산 기준) |

### 4.2 결제 수단 변경 SQL (추정)
```sql
UPDATE BackingPayment
   SET BillKey = ?, PayBy = ?, ModDate = NOW()
 WHERE BackingPaymentId = ?
   AND UserId = ?
   AND PayStatus IN ('reservation-status-set')
   AND IsCanceled = FALSE;
```

### 4.3 예약결제 실행 SQL (추정 시퀀스)
```sql
-- 1) 오늘 결제 예정 대상 조회
SELECT BackingPaymentId, UserId, CampaignId, BillKey, BillingAmount, CountryCode
  FROM BackingPayment BP
 INNER JOIN Campaign C ON C.CampaignId = BP.CampaignId
 WHERE BP.PayStatus IN ('reserved-set')
   AND BP.IsCanceled = FALSE
   AND C.IsAllOrNothing = TRUE
   AND (현재일 = DATE_ADD(C.WhenHoldTo, INTERVAL 1 DAY)     -- 1차
     OR 현재일 = DATE_ADD(C.WhenHoldTo, INTERVAL 2 DAY));   -- 재시도

-- 2) 각 건당 nicepay-api 호출 (Billing approval) — HTTP POST /api/{v}/approval
-- 3) 결과 저장
UPDATE BackingPayment
   SET PayStatus=?, ResultCode=?, Description=?, ProcDate=NOW(), Tid=?, Mid=?
 WHERE BackingPaymentId=?;
```
실제 UseCase 는 funding-core 내부.

### 4.4 빌키 만료 알림 쿼리 (추정)
```sql
SELECT BM.Userid, BM.BillKey, BM.CardExpire
  FROM BillkeyManager BM
 WHERE BM.CardExpire BETWEEN '{오늘+N일}' AND '{오늘+M일}'    -- N, M 은 Reader 파라미터
   AND BM.IsDeleted = FALSE;
```

---

## 엔드투엔드 시퀀스

### A. 빌키 등록 (사용자 액션)
```
[FE — 결제 모달: "간편결제 등록" 선택]
   │ ① FE가 PG SDK로 카드 인증 요청 (nicepay-js)
   ▼
[PG (Nicepay) — 카드 인증 + 빌키 발급 토큰]
   │
   │ ② POST /web/apip/funding/simple-pay/card
   │    body: { cardToken, ... }
   ▼
[ApiProxyServlet → com.wadiz.api.funding]
   │
   └─ SimplePayController#createBillkey
        │ userId = SecurityUtils.currentUserId()
        └─ simplePayProxy.createBillKey(CreateBillkeyCommand)   (funding-core)
             ├─ PG 검증: nicepay-api /billkey/* (POST) — 카드 유효성 + 빌키 생성
             ├─ INSERT BillkeyManager (UserId, BillKey, CardMetadata, Expire)
             └─ 간편결제 세션 토큰 UUID 발급

   → CreateBillkeyResponse { token }

[FE — 비밀번호 입력]
   │ ③ POST /web/apip/funding/simple-pay/{token}/passcode
   ▼
[SimplePayController#registerPasscode]
   └─ UPDATE BillkeyManager SET Passcode = HASH(?), ... WHERE UserId = ? AND Token = ?
```

### B. 결제 수단 변경
```
[FE — 마이펀딩 상세]
   │ PUT /web/apip/funding/supporters/my/fundings/{id}/pay-by
   │    body: { billKey: "..." }
   ▼
[SupporterController#modifyPayBy]   [supporter/SupporterController.java:104]
   └─ supporterProxy.modifyPayBy(...)
        └─ UPDATE BackingPayment SET BillKey=?, PayBy='billkey', ... WHERE BackingPaymentId=? AND UserId=?
```

### C. 예약결제 실행 (마감 +1/+2일 배치)
```
[Scheduler (WhenHoldTo + 1 day) → Job 실행]
   │
   │ Reader: SELECT BackingPayment WHERE PayStatus IN(예약상태) AND WhenPayFor = TODAY
   ▼
[Writer — 각 건에 대해]
   │ HTTP POST → [nicepay-api]
   │    /api/{apiVersion}/approval   (BillingController.approval)
   │    body: { billKey, amount, orderNo, ... }
   ▼
[nicepay-api — BillingService.approval]
   │  PG 승인 → 결과 응답 (WebFlux + R2DBC + Mongo 로그)
   │  Publisher: RabbitMQ/SQS 이벤트 발행
   │
   │ 응답
   ▼
[funding Writer — 결과 기록]
   │ UPDATE BackingPayment SET PayStatus=?, ResultCode=?, Tid=?, Mid=?, ProcDate=NOW() WHERE BackingPaymentId=?
   │
   │ 실패 시 → 다음 배치(WhenFinalPayFor = +2일)에서 재시도
   │ 최종 실패 → 서포터에게 실패 알림 + 정책상 주문 취소
```

### D. 빌키 만료 알림 (일일 배치)
```
[Scheduler → BillkeyVerifyRemindJob]
   │
   │ Reader: SELECT BillkeyManager WHERE CardExpire BETWEEN ... (1000건 청크)
   ▼
[Writer — 알림 발송]
   │ HTTP → com.wadiz.api.funding.client.notification.* (알림 외부 서비스)
   │   "카드 만료 D-N, 간편결제를 갱신해 주세요"
   │ 실패(NotificationApiClientException) → skip 후 다음 건 진행 (skipLimit = MAX)
```

---

## 경계·미탐색

1. **예약결제 실행 Job 위치·이름** — 본 문서에서는 개념·데이터 흐름만 기술. 구체 Job/Scheduler 이름·cron 표현식은 추가 추적 필요 (`adapter/batch` 하위 payment 관련 Job 재검색).
2. **BillkeyManager 테이블 정확한 이름·스키마** — funding-core 외부. 이 레포에는 표준 조회 쿼리 미첨부.
3. **PG billing 파라미터** — `apiVersion` 분기, `orderNo` 규약, 실패 코드 별 처리는 nicepay-api 쪽 문서 참조.
4. **쿠폰·포인트 재차감** — 예약결제 실패 시 이미 차감된 쿠폰·포인트 환원 여부는 별도 추적.
5. **간편결제 Passcode 해시** — 비밀번호 저장 방식(해시 알고리즘/솔트)은 simplePayProxy 구현 확인 필요 (현 레포 외부).
6. **글로벌 결제(Stripe)에서의 빌키 개념** — Stripe 의 PaymentMethod/Customer 개념과 1:1 매핑 여부 미확인.
7. **빌키 변경 시 배송·쿠폰 영향 없음** — 결제 수단만 바꾸고 주문 자체는 유지되는 것으로 관측되나, 일부 쿠폰 정책이 결제 수단 의존적일 경우 재검증 필요.
