# Flow: 펀딩 환불

> 서포터의 펀딩 환불 체인. **결제 전 취소**(주문 세션 취소)와 **결제 후 반환**(리워드 환불 신청·승인) 두 모드가 공존.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/funding.service.ts:475-494` (정책·내 환불 정보 조회)
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/refund/RefundController.java:1-40`
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/refundpolicy/RewardRefundPolicyController.java:14-25`
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/paymentcancel/CancelPaymentController.java:1-35`
  - `com.wadiz.api.funding/adapter/infrastructure/src/main/resources/mapper/RewardRefundMapper.xml` (전체 ≈ 30 줄)
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/refund/controller/RefundCommandController.java:1-110`
- **외부 경계**: `refundProxy`, `cancelPaymentProxy`, `refundCommandService`, `refundApplicationService`, `refundService` 는 funding-core / com.wadiz.web 내부 service. 실제 PG 환불 호출(`nicepay-api` 위임)은 이 레포에서 관측 불가.

---

## 환불 모드 2가지 개요

| 구분 | 시점 | 주요 엔드포인트 | 서비스 |
|---|---|---|---|
| **A. 결제 취소** (결제 중/직후) | 마감 이전 단일 결제 취소 | `POST /api/cancel-payment` | funding `CancelPaymentController` |
| **B. 리워드 환불 신청·승인** (배송 단계) | 배송 지연/하자 → 신청 → 승인/거절 | `POST /web/reward/api/refunds/{id}/apply-by-(defect\|delay)`, `approve`, `reject`, `hold` | com.wadiz.web `RefundCommandController` |

읽기 경로는 두 모드 공통:
- `GET /api/refund-policy/campaigns/{id}/detail` (정책)
- `GET /api/refund/my/{campaignId}/detail` (내 환불 현황)
- `GET /web/apip/funding/refund/my/{id}/detail`, `GET /web/apip/funding/global/projects/{id}/refund-policy` (FE proxy)

---

## 1. Client Trigger (FE)

### 1.1 정책 조회
```ts
// packages/api/src/web/funding.service.ts:475
export const getFundingRefundPolicy = (projectNo: number) => {
  return GET<Response<FundingRefundPolicy>>(`web/apip/funding/global/projects/${projectNo}/refund-policy`);
};
```

### 1.2 내 환불 정보 조회
```ts
// :487
export const getMyRefundInfo = (projectNo: number) => {
  return GET(`/web/apip/funding/refund/my/${projectNo}/detail`);
};
```

### 1.3 환불 신청·승인·거절·보류 (메이커/어드민 화면)
운영 화면 또는 메이커센터 측에서 호출. FE 에서 POST `/web/reward/api/refunds/{backingPaymentId}/...` 경로 시리즈를 사용 (운영 SPA 경로).

### 1.4 앱(Android/iOS)
- Phase 2 미진행.

---

## 2. Hub — `com.wadiz.web`

### 2.1 정책·내 환불 정보 조회 (ApiProxy)
`/web/apip/funding/global/projects/{id}/refund-policy` 와 `/web/apip/funding/refund/my/{id}/detail` 은 **ApiProxyServlet** 을 통해 funding 으로 직행. com.wadiz.web 의 Java 코드는 통과만 함.

### 2.2 환불 명령 (자체 처리)
```java
// com.wadiz.web/reward/refund/controller/RefundCommandController.java:23
@Controller
@RequestMapping(RefundCommandController.BASE_URI)   // "/web/reward/api/refunds"
public class RefundCommandController {
    public static final String BASE_URI                    = "/web/reward/api/refunds";
    public static final String APPLY_BY_DEFECT_API_URI     = "/{backingPaymentId}/apply-by-defect";
    public static final String APPLY_BY_DELAY_API_URI      = "/{backingPaymentId}/apply-by-delay";
    public static final String MODIFY_APPLY_REASON_API_URI = "/{backingPaymentId}/{backingId}";
    public static final String APPLICATION_CANCEL_API_URI  = "/{backingPaymentId}/cancel-application";
    public static final String APPROVE_API_URI             = "/{backingPaymentId}/approve";
    public static final String REJECT_API_URI              = "/{backingPaymentId}/reject";
    public static final String HOLD_API_URI                = "/{backingPaymentId}/{backingId}/holding";

    // 신청 (하자) — RewardRole.FUNDING_OWNER 만 (서포터)
    @PostMapping(APPLY_BY_DEFECT_API_URI)   // :48
    @RequiredAnyRole({RewardRole.FUNDING_OWNER})
    public ResponseWrapper<List<Refund>> applyByDefect(...) {
        return ResponseWrapper.success(
            refundCommandService.applyByDefect(SessionUtil.getUserId(), backingPaymentId, req));
    }

    // 신청 (지연) — RewardRole.FUNDING_OWNER 만
    @PostMapping(APPLY_BY_DELAY_API_URI)    // :57

    // 사유 변경 — WADIZ_ADMIN 또는 CAMPAIGN_OWNER
    @PutMapping(MODIFY_APPLY_REASON_API_URI)

    // 신청 취소 — FUNDING_OWNER (서포터 본인)
    @PostMapping(APPLICATION_CANCEL_API_URI)

    // 승인 — WADIZ_ADMIN 또는 CAMPAIGN_OWNER (메이커)
    @PostMapping(APPROVE_API_URI)

    // 거절 — WADIZ_ADMIN 또는 CAMPAIGN_OWNER
    @PostMapping(REJECT_API_URI)

    // 보류 — WADIZ_ADMIN 또는 CAMPAIGN_OWNER
    @PostMapping(HOLD_API_URI)
}
```

**권한 분기**:
- `FUNDING_OWNER` (서포터) — 신청·신청취소
- `CAMPAIGN_OWNER` (메이커) + `WADIZ_ADMIN` — 승인·거절·보류·사유변경

내부 서비스 3종(`refundCommandService` / `refundApplicationService` / `refundService`) 이 각자의 MyBatis 매퍼를 통해 DB 업데이트.

---

## 3. Backend Service — `com.wadiz.api.funding`

### 3.1 내 환불 정보 조회
```java
// adapter/application/.../domain/refund/RefundController.java:16
@RestController
@RequestMapping("/api/refund")
public class RefundController {
    private final RefundProxy refundProxy;

    @GetMapping("/my/{campaignId}/detail")
    public ResponseWrapper<RefundResponse> getRewardRefund(@PathVariable Integer campaignId) {
        if (!SecurityUtils.isLogin()) {
            return ResponseWrapper.ok(RefundResponse.builder().isAllRefund(false).build());
        }
        final RewardRefundDetailResult result = refundProxy.getRewardRefundDetail(
            RewardRefundDetailQuery.builder()
                .campaignId(campaignId)
                .userId(SecurityUtils.currentUserId())
                .build());
        return ResponseWrapper.ok(RefundResponseConverter.INSTANCE.resultToRefund(result));
    }
}
```
비로그인 시 기본값 응답 (전체 환불 여부 `false`).

### 3.2 환불 정책
`/api/refund-policy/campaigns/{id}/detail` — 캠페인별 환불 정책. funding-core 에서 `RewardRefundPolicyDetailUseCase` 로 처리.

### 3.3 결제 취소 (Cancel Payment)
```java
// paymentcancel/CancelPaymentController.java:17
@RestController
@RequestMapping("/api/cancel-payment")
public class CancelPaymentController {
    private final CancelPaymentProxy cancelPaymentProxy;

    @PostMapping
    public ResponseWrapper<CancelPaymentResponse> cancel(@Valid @RequestBody CancelPaymentRequest request) {
        final CancelPaymentResult result = cancelPaymentProxy.cancel(
            CancelPaymentCommand.builder()
                .backingPaymentId(request.getBackingPaymentId())
                .userId(SecurityUtils.currentUserId())
                .build());
        return ResponseWrapper.ok(CancelPaymentResponse.builder()
            .backingPaymentId(result.getBackingPaymentId())
            .orderNo(result.getOrderNo())
            .build());
    }
}
```
funding-core 의 `CancelPaymentUseCase` 가 `BackingPayment.IsCanceled = TRUE` 처리 + PG 취소 호출(외부 `nicepay-api` 추정) + 쿠폰·포인트 회수(`com.wadiz.api.reward` 호출 추정).

---

## 4. DB

### 4.1 핵심 테이블

| 테이블 | 역할 |
|---|---|
| `BackingPayment` | `IsCanceled`, `PayStatus` (취소/환불 플래그) |
| `RewardRefund` | 리워드 환불 신청·진행 상태 (`Status`: APPLIED / APPROVED / REFUNDED / REJECTED / HOLD ...) |
| `CampaignRewardDelay` | 지연 사유에 의한 정책 적용 기준 |
| `Backing`, `BackingPaymentMapping` | 결제-리워드 매핑 (환불 대상 아이템 조회) |
| `Shipping` | 배송 상태 (발송 전/후 환불 정책 차이) |

### 4.2 조회 SQL (funding — `RewardRefundMapper.xml`)
```sql
<!-- :5 -->
<select id="getFundingRewardItemQty">   <!-- 환불 가능 리워드 개수 -->
    SELECT COUNT(*) AS FundingRewardItemQty
    FROM BackingPayment BP
         LEFT JOIN BackingPaymentMapping BM ON BM.BackingPaymentId = BP.BackingPaymentId
         LEFT JOIN Backing BK ON BK.BackingId = BM.BackingId
         LEFT JOIN Reward R ON R.RewardId = BK.RewardId
         LEFT OUTER JOIN CampaignRewardDelay CD ON R.CampaignId = CD.CampaignId
    WHERE BP.BackingPaymentId IN (
        SELECT BP.BackingPaymentId
          FROM BackingPayment BP
         WHERE BP.CampaignId = #{query.campaignId}
           AND BP.UserId = #{query.userId}
           AND BP.PayStatus IN ('A10','B10','C10','Z11','D11','P10')   -- 유효 결제 상태
           AND BP.IsCanceled = FALSE)
    ORDER BY BK.BackingId;
</select>

<!-- :21 -->
<select id="getRewardRefundQty">         <!-- 이미 환불된 개수 -->
    SELECT COUNT(*)
    FROM RewardRefund RR
         INNER JOIN BackingPayment BP ON RR.BackingPaymentId = BP.BackingPaymentId
    WHERE RR.CampaignId = #{query.campaignId}
      AND RR.UserId = #{query.userId}
      AND RR.Status = 'REFUNDED';
</select>
```
두 값의 차이로 "일부 환불 / 전체 환불" 상태 판별 (`RefundResponse.isAllRefund`).

### 4.3 명령 경로 (com.wadiz.web 측)
`refundCommandService.applyByDefect/applyByDelay/...` 은 이 레포 내 `refund` 도메인 매퍼(XML 미첨부 범위)로 `RewardRefund` 행 INSERT/UPDATE 를 수행하는 것으로 관측됨. 정확한 SQL 은 별도 추적.

### 4.4 PG 취소 (결제 취소 경로)
`CancelPaymentUseCase` 는 PG(나이스페이/Stripe/Alipay)로 취소 요청을 보내야 함 — 실제 구현은 funding-core + `nicepay-api`. 이 레포에서는 관측 불가.

---

## 엔드투엔드 시퀀스

### 모드 A — 결제 취소 (주문 직후 이탈)
```
[FE]
   │ POST /web/apip/funding/cancel-payment   (body: { backingPaymentId })
   ▼
[ApiProxyServlet → com.wadiz.api.funding]
   │
   ├─ CancelPaymentController#cancel                  [paymentcancel/CancelPaymentController.java:23]
   │     userId = SecurityUtils.currentUserId()
   │
   └─ cancelPaymentProxy.cancel(cmd)  (funding-core)
        ├─ PG 취소 호출           → nicepay-api / Stripe / Alipay (외부)
        ├─ UPDATE BackingPayment SET IsCanceled=TRUE, PayStatus=?, CancelAt=NOW()
        ├─ 쿠폰 회수              → com.wadiz.api.reward (추정)
        └─ 포인트 환원            → 외부

   → CancelPaymentResponse { backingPaymentId, orderNo }
```

### 모드 B — 리워드 환불 신청·승인
```
[서포터 FE: 환불 신청 화면]
   │ POST /web/reward/api/refunds/{bpId}/apply-by-defect   (권한: FUNDING_OWNER)
   ▼
[com.wadiz.web — RefundCommandController#applyByDefect (:48)]
   │   권한 필터: @RequiredAnyRole(FUNDING_OWNER)
   ▼
[refundCommandService.applyByDefect(userId, bpId, req)]
   │
   ├─ INSERT RewardRefund (Status='APPLIED', Reason=..., UserId, CampaignId, BackingPaymentId, BackingId)
   └─ 알림 (메이커에게 신청 발생 알림)

   → List<Refund> 응답

[메이커 어드민 화면]
   │ POST /web/reward/api/refunds/{bpId}/approve          (권한: CAMPAIGN_OWNER 또는 WADIZ_ADMIN)
   ▼
[RefundCommandController#approve (:87)]
   │
   └─ refundCommandService.approve(userId, bpId, req)
        ├─ UPDATE RewardRefund SET Status='APPROVED', ApproveAt=NOW()
        ├─ PG 부분 취소 요청        → nicepay-api / Stripe (외부)
        ├─ UPDATE BackingPayment (잔여금, 부분취소 이력 반영)
        └─ INSERT 정산 이력 (환불액 정산 차감)

   → 서포터에게 환불 완료 알림
```

### 읽기 — 서포터 "내 환불 정보" 페이지
```
[FE]
   │ GET /web/apip/funding/refund/my/{campaignId}/detail
   ▼
[ApiProxyServlet → com.wadiz.api.funding: RefundController#getRewardRefund (/api/refund/my/{id}/detail)]
   │
   └─ refundProxy.getRewardRefundDetail(query)   (funding-core)
         ├─ MyBatis: getFundingRewardItemQty (환불 가능 총 개수)
         ├─ MyBatis: getRewardRefundQty       (이미 환불된 개수)
         └─ isAllRefund = (refunded == fundingItemQty)

   → RefundResponse { isAllRefund, ... }
```

---

## 경계·미탐색

1. **funding-core jar 내부** — `CancelPaymentUseCase`, `RewardRefundDetailUseCase`, `RewardRefundPolicyDetailUseCase` 구현체는 외부 jar. PG 취소 호출 순서·트랜잭션 경계 확인 불가.
2. **실제 PG 취소 호출 경로** — funding → nicepay-api (WebFlux + R2DBC) → PG사. [docs/nicepay-api.md](../nicepay-api.md) 의 취소 엔드포인트 참조.
3. **쿠폰·포인트 회수** — funding 취소 시 `com.wadiz.api.reward` 의 `/api/v1/rewards/coupons/transactions/users/{userId}/types/refund` 호출 여부 확인 필요.
4. **com.wadiz.web 내 refund 매퍼** — `refundCommandService` / `refundApplicationService` / `refundService` 의 SQL 구체(INSERT/UPDATE 컬럼)는 별도 추적.
5. **환불 상태 머신** — `APPLIED → APPROVED → REFUNDED` 외에 `REJECTED`, `HOLD`, `CANCELED(신청취소)` 등 분기. 각 전환 규칙·재신청 정책 별도 문서화 대상.
6. **부분 환불 vs 전체 환불** — `isAllRefund` 플래그만 관찰. 한 주문에서 여러 리워드 중 일부만 환불할 때 `BackingPayment` 자체는 어떻게 남는지(부분취소 처리) 추적 필요.
7. **All-or-Nothing 실패 자동 환불** — 목표 미달 시 일괄 환불 배치는 본 플로우 범위 밖 (별도 배치 추적 필요).
