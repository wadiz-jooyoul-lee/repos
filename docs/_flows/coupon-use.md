# Flow: 쿠폰 사용 (발급 등록 · 결제 시 적용 · 환불 시 반환)

> 서포터가 쿠폰을 **발급받고 → 결제 시 사용 → 환불 시 반환**하는 라이프사이클. 쿠폰 도메인은 `com.wadiz.api.reward` 에서 일관 관리되며, 다른 서비스(funding/store)가 명령을 던지는 구조.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/reward/coupon.service.ts:60-350` (FE 쿠폰 API)
  - `com.wadiz.api.reward/.../rest/coupon/CouponTransactionController.java:22-125`
  - [`docs/com.wadiz.api.reward/api-details/coupon-core.md`](../com.wadiz.api.reward/api-details/coupon-core.md) (Phase 2 기존 분석)
- **외부 경계**: `couponRedeemService`, `couponUseService`, `couponRefundService`, `couponWithdrawService` 의 내부 SQL·트랜잭션 경계는 coupon-core 문서 참조. funding 의 쿠폰 호출 시점(결제 승인 직전/직후 어느 시점인지)은 funding-core jar 내부.

---

## 쿠폰 라이프사이클 4단계

| 단계 | 엔드포인트 (reward API) | 트리거 | 비고 |
|---|---|---|---|
| **1. Redeem (발급 등록)** | `POST /api/v1/rewards/coupons/transactions/users/{uid}/types/redeem/issue-types/{type}` | 마이페이지 "쿠폰함 → 받기", 코드 등록, 가입 쿠폰 자동 | `{type}`: `download` / `direct` / `api` / `coupon-code` |
| **2. Use (사용)** | `POST /.../users/{uid}/types/use` | 펀딩 결제 승인 직전 (funding → reward 호출) | `CouponTransactionDto.Use` |
| **3. Refund (반환)** | `POST /.../users/{uid}/types/refund` | 결제 취소/리워드 환불 시 | `CouponTransactionDto.Refund` |
| **4. Withdraw (회수)** | `POST /.../users/{uid}/types/withdraw` | 운영자 회수 (부정 사용 등) | `Boolean` 응답 |
| **조회** | `GET /.../transactions/{transactionKey}` | 거래 상세 | |
| **거래 취소** | `DELETE /.../transactions/{transactionKey}` | 부정한 거래 자체 삭제 (어드민) | |
| **Bulk Redeem** | `POST /.../types/redeem/issue-types/{type}/bulk` (by issueKeys), `POST /.../types/redeem/issue-types/{type:direct\|api}/bulk` (by userIds) | 대량 지급 | |

---

## 1. Client Trigger (FE)

### 1.1 보유 쿠폰 조회 (조회 영역)
```ts
// packages/api/src/web/reward/coupon.service.ts:69
GET /web/reward/api/coupons/owners/my              // 보유 목록
GET /web/reward/api/coupons/owners/my/qty          // 보유 수
```

### 1.2 쿠폰 받기
- **코드로 등록** (`:80`): POST `/web/reward/api/coupons/transactions/types/redeem/issue-types/coupon-code`
- **다운로드형** (`:328`): POST `/web/reward/api/coupons/transactions/types/redeem/issue-types/download`
- **Bulk 다운로드** (`:347`): POST `/web/reward/api/coupons/transactions/types/redeem/bulk` (`issueKeys[]`)

### 1.3 다운로드 가능 쿠폰 노출
```ts
// :271, :285
GET /web/reward/api/coupons/templates/types/download
GET /web/reward/api/coupons/templates/types/download/qty
```

### 1.4 결제 시 쿠폰 적용
결제 주문 시트 생성(`orders/sheet/{token}`) 때 `couponKey` 를 함께 넣는다. 실제 "USE" 호출은 FE 가 직접 하지 않고, **funding 서비스가 결제 승인 단계에서 reward 의 `/types/use` 를 서버-서버로 호출**.

---

## 2. Hub — `com.wadiz.web`

`/web/reward/api/coupons/*` 는 com.wadiz.web 내부 컨트롤러 또는 Feign adapter 가 받아 `com.wadiz.api.reward` 의 `/api/v1/rewards/coupons/*` 로 변환·전달. (상세는 Phase 2 reward 문서 참조, 본 flow 에서는 투명 패스)

---

## 3. Backend — `com.wadiz.api.reward`

### 3.1 CouponTransactionController (핵심)
```java
// reward-api/.../rest/coupon/CouponTransactionController.java:22
@RequestMapping("/api/v1/rewards/coupons/transactions")
public class CouponTransactionController {
    // 6개 서비스 위임
    private final CouponTransactionConverter converter;
    private final CouponRedeemService couponRedeemService;    // 발급 등록
    private final CouponUseService     couponUseService;      // 사용
    private final CouponRefundService  couponRefundService;   // 반환
    private final CouponWithdrawService couponWithdrawService;// 회수
    private final CouponTransactionService couponTransactionService;  // 조회·취소

    @GetMapping("/{transactionKey}")                           // :42  거래 상세
    @PostMapping("/users/{userId}/types/redeem/issue-types/coupon-code")  // :48  코드
    @PostMapping("/users/{userId}/types/redeem/issue-types/{issueType:download|direct|api}")  // :58
    @PostMapping("/users/{userId}/types/redeem/issue-types/{issueType:download|direct|api}/bulk")  // :68
    @PostMapping("/users/types/redeem/issue-types/{issueType:direct|api}/bulk")  // :78
    @PostMapping("/users/{userId}/types/withdraw")             // :84
    @PostMapping("/users/{userId}/types/use")                  // :95  (funding 호출)
    @PostMapping("/users/{userId}/types/refund")               // :105 (취소/환불 호출)
    @DeleteMapping("/{transactionKey}")                        // :115 거래 삭제 (어드민)
}
```

### 3.2 사용자 일치 검증 패턴
거의 모든 엔드포인트가 path `userId` 와 요청 body 의 `ownerUserId`/`userId` 를 비교하여 불일치 시 `NotEqualTransactionUserException`. URL 을 그대로 드러내도 다른 사용자의 쿠폰을 조작할 수 없게 방어.
```java
if (!userId.equals(request.getOwnerUserId())) {
    throw new NotEqualTransactionUserException();
}
```

### 3.3 Redeem (발급 등록) 4 종 분기
| issueType | 시나리오 |
|---|---|
| `coupon-code` | 유저가 직접 쿠폰 코드 문자열 입력 |
| `download` | 쿠폰존·이벤트 페이지에서 "받기" |
| `direct` | 가입 축하, 생일 등 운영 자동 지급 (대량: `bulk`) |
| `api` | 외부 API 연동 지급 (제휴·CRM) |

### 3.4 Use — funding 결제 승인 단계에서 서버-서버 호출
결제 승인 시점:
```
funding: OrderPaymentUsecase.pay (funding-core, 외부)
   └─ HTTP POST → reward /api/v1/rewards/coupons/transactions/users/{userId}/types/use
         body: { userId, couponKey, backingPaymentId, amount, ... }
   └─ reward: couponUseService.use(request)
         ├─ Coupon 상태 검증 (사용 가능 / 만료 / 중복)
         ├─ INSERT CouponTransaction (type='USE', transactionKey=UUID)
         ├─ UPDATE Coupon SET Status='USED', usedAt=NOW(), usedFor=backingPaymentId
         └─ 요약 집계(`CouponSummationController`)는 배치가 별도로 갱신
```

### 3.5 Refund — 결제 취소/환불 시 원복
```
funding 결제 취소 / 리워드 환불 승인 시
   └─ HTTP POST → reward /api/v1/rewards/coupons/transactions/users/{userId}/types/refund
         body: { userId, couponKey, originalTransactionKey, ... }
   └─ reward: couponRefundService.refund(request)
         ├─ 원본 USE transaction 조회
         ├─ INSERT CouponTransaction (type='REFUND', ref=originalTransactionKey)
         └─ UPDATE Coupon SET Status='AVAILABLE', usedAt=NULL
```

### 3.6 Withdraw — 운영자 회수
부정 사용·정책 위반 시 운영자가 사용자에게서 쿠폰을 회수. `Coupon.Status='WITHDRAWN'` 처리. DB 트랜잭션 기록 남기지만 유저에게 환불하지 않는 경로.

---

## 4. DB (`com.wadiz.api.reward`)

### 4.1 주요 테이블 (Phase 2 reward 문서 참조)

| 테이블 | 역할 |
|---|---|
| `t_reward_coupon_template` | 쿠폰 템플릿 (정책 + 발행량) |
| `t_reward_coupon_issue` | 발행 단위 (템플릿 × 수량) |
| `t_reward_coupon` | 발급된 개별 쿠폰 (owner userId, couponKey, status, expireAt) |
| `t_reward_coupon_transaction` | 모든 거래 이력 (REDEEM/USE/REFUND/WITHDRAW 4가지 타입, transactionKey UUID) |
| 집계 (비정규화) | `t_reward_coupon_summation`, `t_reward_coupon_issue_summation`, `t_reward_coupon_transaction_summation` (배치 갱신) |

### 4.2 대표 거래 패턴
```sql
-- Redeem
INSERT INTO t_reward_coupon (couponKey, templateNo, issueKey, ownerUserId, status='AVAILABLE', expireAt, ...);
INSERT INTO t_reward_coupon_transaction (transactionKey, type='REDEEM', couponKey, ownerUserId, ...);

-- Use
INSERT INTO t_reward_coupon_transaction (transactionKey, type='USE', couponKey, userId, usedFor=backingPaymentId, ...);
UPDATE t_reward_coupon SET status='USED', usedAt=NOW() WHERE couponKey = ? AND status='AVAILABLE';

-- Refund
INSERT INTO t_reward_coupon_transaction (transactionKey, type='REFUND', refTransactionKey=<use-tx>, ...);
UPDATE t_reward_coupon SET status='AVAILABLE', usedAt=NULL WHERE couponKey=?;

-- Withdraw
INSERT INTO t_reward_coupon_transaction (transactionKey, type='WITHDRAW', ...);
UPDATE t_reward_coupon SET status='WITHDRAWN' WHERE couponKey=?;
```

### 4.3 집계 배치
`CouponTransactionSummationJob`, `ProjectCouponSummaryJob` 이 주기적으로 집계 (배치: [`docs/com.wadiz.api.reward/api-details/batch.md`](../com.wadiz.api.reward/api-details/batch.md)).

---

## 엔드투엔드 시퀀스

### A. 쿠폰 받기 (다운로드)
```
[FE: 쿠폰존/이벤트 페이지 → "받기" 버튼]
   │ POST /web/reward/api/coupons/transactions/types/redeem/issue-types/download
   │    body: { issueKey, userId, ... }
   ▼
[com.wadiz.web 쿠폰 adapter → com.wadiz.api.reward]
   │
   └─ CouponTransactionController#redeemByIssue                  (:58)
        └─ couponRedeemService.redeemByIssue(request, 'download')
             ├─ Issue 검증 (발행 잔량, 사용자당 한도)
             ├─ INSERT t_reward_coupon (ownerUserId=?, status='AVAILABLE', expireAt=정책)
             └─ INSERT t_reward_coupon_transaction (type='REDEEM', transactionKey=UUID)

   → Response { transactionKey, couponKey, expireAt }
```

### B. 결제 시 쿠폰 사용 (funding ↔ reward 서버간)
```
[FE: 결제 시트 선택 → "결제하기"]
   │ POST /web/apip/funding/orders/sheet/{token}   (couponKey 포함)
   │        + 이후 PG 인증 완료 → /api/order-payment/... 콜백
   ▼
[com.wadiz.api.funding — OrderPaymentUsecase.pay (funding-core, 외부 jar)]
   │   결제 승인 전 단계에서:
   │
   │   HTTP POST → com.wadiz.api.reward
   │     /api/v1/rewards/coupons/transactions/users/{userId}/types/use
   │     body: { userId, couponKey, backingPaymentId, discountAmount, ... }
   ▼
[com.wadiz.api.reward — CouponTransactionController#use  (:95)]
   │  path userId ↔ body userId 일치 검증
   │
   └─ couponUseService.use(request)
        ├─ Coupon 상태 체크: 'AVAILABLE' + 미만료 + 캠페인/프로젝트 적용 가능?
        ├─ 원자적 상태 전환 (UPDATE t_reward_coupon WHERE status='AVAILABLE' ROWS_AFFECTED=1)
        │   └─ 실패(이미 사용됨) → 예외 → funding 결제 실패로 롤백
        └─ INSERT t_reward_coupon_transaction (type='USE', transactionKey, usedFor=backingPaymentId)

   → Response { transactionKey }  → funding: BackingPayment 에 쿠폰 메타 기록 후 PG 승인 진행
```

### C. 환불 시 쿠폰 반환
```
[funding 환불 승인 또는 주문 취소]
   │
   │ HTTP POST → com.wadiz.api.reward
   │   /api/v1/rewards/coupons/transactions/users/{userId}/types/refund
   │   body: { userId, couponKey, originalTransactionKey, ... }
   ▼
[CouponTransactionController#refund  (:105)]
   │
   └─ couponRefundService.refund(request)
        ├─ 원본 USE 거래 검증 (transactionKey 존재, type='USE', not already refunded)
        ├─ INSERT t_reward_coupon_transaction (type='REFUND', refTransactionKey=<use-tx>)
        └─ UPDATE t_reward_coupon SET status='AVAILABLE', usedAt=NULL WHERE couponKey=?

   → Response { transactionKey }
```

### D. 운영자 회수
```
[어드민 SPA 또는 com.wadiz.adm]
   │ POST /api/v1/rewards/coupons/transactions/users/{userId}/types/withdraw
   ▼
[CouponTransactionController#withdraw  (:84)]
   │ path/body userId 일치 검증
   └─ couponWithdrawService.withdraw(request)
        ├─ INSERT t_reward_coupon_transaction (type='WITHDRAW', 사유 메타)
        └─ UPDATE t_reward_coupon SET status='WITHDRAWN'
```

---

## 경계·미탐색

1. **Coupon 사용 원자성** — funding 이 `use` 호출에 실패했을 때(네트워크 타임아웃, reward 500) funding 이 PG 결제를 어떻게 롤백하는지 정확한 보상 트랜잭션 경로는 funding-core jar 내부.
2. **중복 방지** — 동일 couponKey 로 두 결제가 동시에 `use` 호출 시, DB 조건부 UPDATE (`WHERE status='AVAILABLE'`) 로 1건만 성공 — 이 동작이 실제 매퍼 SQL 에 명시되어 있는지 [coupon-core.md](../com.wadiz.api.reward/api-details/coupon-core.md) 의 SQL 에서 확인 권장.
3. **Bulk API 의 사용자 권한** — `/bulk` 경로는 path userId 가 없고 body 만 검증 — 운영/CRM 계정만 접근 가능하도록 보안 필터가 있는지 (별도 인가 layer) 확인 필요.
4. **쿠폰 만료 정책** — 만료 임박 배치(`CouponExpirationNotificationJob`)는 [batch.md](../com.wadiz.api.reward/api-details/batch.md) 에서 다룸. 실제 만료 처리(자동 status 변경)는 별도 배치 추적 필요.
5. **쿠폰 + 포인트 복합 적용** — 한 결제에서 쿠폰+포인트 동시 사용 시 우선순위, 쿠폰 Refund 시 포인트 재차감 여부는 funding 정책 (별도).
6. **reward 의 쿠폰 정책 객체(`t_reward_coupon_template`)** — 할인율·고정금액·최소 주문 금액·대상 카테고리 등 정책 필드의 전체 스키마는 Phase 2 reward 문서 참조.
7. **Braze 와의 연동** — `/api/v1/rewards/coupons/makers/braze/project` (MakerCouponController) 는 메이커 ↔ Braze 캠페인 연동. 본 flow (서포터 사용) 와는 다른 경로.
