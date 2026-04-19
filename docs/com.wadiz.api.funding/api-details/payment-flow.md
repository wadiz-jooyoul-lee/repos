# Payment Flow API 상세 스펙

결제 쓰기 경로 — 주문 결제 승인·취소·집계 관련 17개 엔드포인트.

- **대상 컨트롤러**:
  - `OrderPaymentController` (`/api/order-payment`) — 5개 (PG 콜백, 0원 결제, 상태 조회)
  - `AdminOrderPaymentController` (`/api/admin`) — 2개 (즉시 결제, 관리자 취소)
  - `PaymentInternalController` (`/api/internal/payments`) — 5개 (조회/메일/카드/빌키)
  - `CancelPaymentController` (`/api/cancel-payment`) — 1개
  - `CancelPaymentInternalController` (`/api/internal/cancel-payment`) — 2개 (벌크)
  - `PaymentProgressController` (`/api/payment-progress`) — 1개
  - `PaymentProgressStudioController` (`/api/studio/payment-progress`) — 1개

- **저장소**: MySQL (Spring Data JDBC + MyBatis), Redis (결제 중복 방지 락)
- **주요 Gateway 구현체 (이 레포)**:
  - `BackingPaymentGatewayImpl` — `BackingPaymentRepository` (Spring Data JDBC)
  - `OrderPaymentRedisGatewayImpl` — 결제 처리 중복 방지 락
  - `AdminImmediatePaymentLogGatewayImpl` — 즉시 결제 로그
  - `BackingPaymentCancelLogGatewayImpl` — 취소 로그
  - `PaymentProgressGatewayImpl` — 결제 집계 MyBatis
- **핵심 외부 의존**: Nicepay, Stripe, Alipay (PG사 — 콜백 파라미터로 수신)

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록. UseCase 구현체(`OrderPaymentUsecase`, `CancelPaymentUsecase`, `ImmediatePaymentUseCase`, `PaymentExtraInfoSaveUseCase` 등)는 외부 jar `com.wadiz.funding.core:funding-core` 에 있으므로 Usecase 내부 호출 순서/분기는 확인 불가.

---

## 1. POST `/api/order-payment/{payType}/{campaignId}/{token}` — NICE 결제 인증 콜백

NICE PG에서 인증 완료 후 form-urlencoded로 callback.

- **Method**: `OrderPaymentController.payViaNiceAuth`
- **Consumes**: `application/x-www-form-urlencoded`
- **Controller Type**: `@Controller` (`@RestController` 아님) — view redirect 반환

### Path / Body

| 위치 | 필드 | 타입 | 필수 | 설명 |
|---|---|---|:---:|---|
| path | `payType` | `String` | ✅ | 결제 수단 코드 |
| path | `campaignId` | `Integer` | ✅ | 프로젝트 ID |
| path | `token` | `UUID` | ✅ | 주문 세션 토큰 |
| body(form) | `AuthResultCode` | `String` | — | NICE 인증 결과 코드 (`0000` = SUCCESS) |
| body(form) | `AuthResultMsg` | `String` | — | 결과 메시지 |
| body(form) | `userId`, `TID`, ... | — | — | PG 콜백 파라미터들 (`Map<String,String>` 전체 수신) |

### 컨트롤러 코드 흐름
1. Locale이 `Locale.KOREA`인지 판별 → KR/해외 redirect 분기용
2. `AuthResultCode == "0000"` (SUCCESS):
   - `orderPayProxy.pay(OrderPaymentConverter.toNiceAuthPayment(token, payType, param, campaignId))` 호출
   - 반환된 `backingPaymentId`로 성공 URL redirect:
     - KR: `redirect:/web/wpurchase/reward/result10/{backingPaymentId}`
     - 해외: `redirect:/funding/payment/completed/{backingPaymentId}`
3. 실패 시 cancel redirect:
   - KR: `redirect:/web/wpurchase/reward/step20?token={token}`
   - 해외: `redirect:/funding/payment?token={token}`

### Response
HTTP 302 (redirect)

### DB 호출 (이 레포 Gateway 기준, UseCase 구현은 funding-core)

이 엔드포인트가 호출하는 `OrderPaymentUsecase.pay`는 아래 Gateway들을 조합 사용할 것으로 보임:

**Redis** (`OrderPaymentRedisGatewayImpl`) — 중복 방지 락
```redis
SET  "com.wadiz.api.funding.redis.orderpayment:processing:{tid}"  "1"  EX 300  NX
  → 성공 시 처리, 실패(락 이미 존재) 시 중복 요청으로 판단
DEL  "com.wadiz.api.funding.redis.orderpayment:processing:{tid}"
```

**MySQL** (`BackingPaymentGatewayImpl`):

| 연산 | SQL / 메서드 |
|---|---|
| `save(backingPaymentInfo)` | `BackingPaymentRepository.save(Insert dto)` — Spring Data JDBC INSERT into `BackingPayment` |
| `savePaymentResult(backingPayment, orderPayment)` | orderPayment의 `authDate/cardResult` 머지 후 INSERT |
| `updateBackingPayment(info, status, ...)` | `@Query UPDATE BackingPayment SET Tid/Mid/PayStatus/ResultCode/Description/ProcDate WHERE BackingPaymentId = ?` |
| `findByUserIdAndTid(userId, tid)` | 중복 결제 방지 조회 |

**실제 호출 순서는 funding-core `OrderPaymentUsecase.pay` 확인 필요.** 일반적으로:
1. Redis 락 획득 (tid 중복 방지)
2. PG 최종 승인 API 호출 (외부)
3. `BackingPayment` INSERT/UPDATE
4. `OrderSession` / `OrderSheet` 삭제 (Redis)
5. `ClosedOrderSession` 저장 (Redis)
6. Redis 락 해제

**접근 테이블/리소스**: `BackingPayment`, Redis 락, NICE PG API, 주문 세션 Redis

### 예외 처리
- `@ExceptionHandler(OrderPaymentException)` — Proxy의 `exceptionHandler.handle(e)` 호출 후 fail redirect

---

## 2. GET `/api/order-payment/{payType}/{token}/pay-via-stripe` — Stripe 결제 완료 콜백

Stripe PG 결제 완료 후 클라이언트가 callback URL로 리다이렉트됨.

- **Method**: `OrderPaymentController.payViaStripe`

### Request (Path + Query)

| 위치 | 필드 | 타입 | 설명 |
|---|---|---|---|
| path | `payType` | `String` | — |
| path | `token` | `UUID` | — |
| query | `redirect_status` | `String` | Stripe 결과 (`succeeded`) |
| query | `Moid` | `String` | 주문 ID |

### 컨트롤러 코드 흐름
1. `redirect_status == "succeeded"` (`StripeAuthType.SUCCESS`):
   - `orderPayProxy.pay(toStripePayment(token, payType, param))` → backingPaymentId 발급
   - 해외용 success redirect 반환
2. 실패 시 해외 cancel redirect

### Response
HTTP 302 redirect

### DB 호출
NICE와 동일 Gateway 세트 사용. Locale은 해외로 고정.

---

## 3. POST `/api/order-payment/alipay/{token}/callback-bypass` — Alipay 인증 bypass

Alipay 인증 후 중간 파이프라인을 거쳐 결제 대기 화면으로 이동.

- **Method**: `OrderPaymentController.payViaAlipay`
- **Consumes**: form-urlencoded

### Request (Path + Form)
| 위치 | 필드 | 타입 | 설명 |
|---|---|---|---|
| path | `token` | `UUID` | — |
| body(form) | `ResultCode` | `String` | `0000` = SUCCESS |
| body(form) | `TID` | `String` | 거래 번호 |
| body(form) | `Moid` | `String` | 주문 ID |
| body(form) | `isWadizApp` | `String` | "Y" 시 네이티브 앱 deeplink |

### 컨트롤러 코드 흐름
1. 성공이면 **pay 호출 없이** 바로 pending 페이지로 redirect:
   - app (`isWadizApp=Y`): `redirect:wadiz://funding/payment/pending?token={}&tid={}`
   - web: `redirect:/funding/payment/pending?token={}&tid={}`
2. 실패 시 해외 cancel redirect

### DB 호출
**이 엔드포인트는 `orderPayProxy.pay`를 호출하지 않음.** 인증 단계 bypass만 처리하고 실제 결제 승인은 `/approve-status` 폴링 또는 SQS 메시지로 이후 처리됨 (`OrderPaymentSqsListener`에서 처리).

---

## 4. POST `/api/order-payment/{token}/pay-zero` — 0원 결제 승인

쿠폰/포인트 100% 차감 등으로 결제 금액이 0인 경우 PG를 거치지 않고 즉시 승인.

- **Method**: `OrderPaymentController.payZero`

### Request
| 위치 | 필드 | 타입 | 필수 | 설명 |
|---|---|---|:---:|---|
| path | `token` | `UUID` | ✅ | — |
| body(form) | `orderNo` | `String` | ✅ `@NotBlank` | 주문 번호 |

### 컨트롤러 코드 흐름
1. `orderPayProxy.pay(toZeroPayment(token, orderNo))` → backingPaymentId
2. Locale 기반 success redirect

### DB 호출
NICE와 동일 Gateway 세트 사용. 단 PG 외부 호출은 생략됨.

---

## 5. GET `/api/order-payment/{token}/approve-status` — 결제 승인 상태 조회

Alipay 등 비동기 결제에서 클라이언트가 승인 상태를 폴링.

- **Method**: `OrderPaymentController.getApproveStatus`
- **@ResponseBody**: JSON 응답

### Request
| 위치 | 필드 | 타입 | 필수 |
|---|---|---|:---:|
| path | `token` | `UUID` | ✅ |
| query | `tid` | `String` | ✅ |

### Response — `ApproveStatusResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `backingPaymentId` | `Integer` | 결제 번호 (발급되지 않았으면 null) |
| `approveStatus` | `ApproveStatus` enum | 승인 상태 |

### 컨트롤러 코드 흐름
`orderPayProxy.getApproveStatus(userId, token, tid)` → `ApproveStatusUseCase.getApproveStatus` (funding-core)

### DB 호출
`BackingPaymentRepository.findByUserIdAndTid(userId, tid)` 호출 가능성 — Spring Data JDBC 파생 쿼리:
```sql
SELECT * FROM BackingPayment WHERE UserId = ? AND Tid = ?
```

상세 로직은 funding-core 확인 필요.

---

## 6. POST `/api/admin/immediate-approve` — 즉시 결제 (관리자)

예약 결제 상태(A10)인 건에 대해 관리자가 즉시 PG 승인을 발동.

- **Method**: `AdminOrderPaymentController.executeImmediatePayment`
- **Security**: `@PreAuthorize("isAdmin()")`

### Request Body — `ImmediatePaymentRequest`

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `paymentReason` | `String` | ✅ `@NotNull @Size(max=500)` | 사유 |
| `adminId` | `String` | ✅ `@NotNull` | 관리자 식별자 |
| `backingPaymentId` | `int` | ✅ `@NotNull` | 결제 번호 |

### Response
```json
{ "message": "즉시 결제가 성공적으로 처리되었습니다." }
```

### 컨트롤러 / Proxy 코드 흐름 (관찰 가능)

`OrderPaymentProxy.immediatePay(command)` 내부:
1. `backingPaymentGateway.getById(backingPaymentId)` — 결제 정보 조회
2. `campaignGateway.getByCampaignId(campaignId)` — 프로젝트 조회
3. 검증:
   - 종료된 캠페인이면 `CampaignEndedException`
   - `payBy`가 `sbcredit/dbcredit/stripe` 아니면 `IllegalArgumentException`
4. `PaymentInfo` 조립 후 `immediatePaymentUseCase.execute(paymentInfo, adminId, reason)` 호출 (funding-core)
5. 실패 시 `immediatePaymentUseCase.handlePaymentResult(paymentInfo, PayStatus.A10, false, ...)` + `sendNotificationSilently`

### DB 호출 (이 레포 Gateway)

**MySQL** (`BackingPaymentRepository`, `CampaignRepository`):
```sql
-- getById
SELECT * FROM BackingPayment WHERE BackingPaymentId = ?

-- getByCampaignId
SELECT * FROM Campaign WHERE CampaignId = ?
```

`immediatePaymentUseCase.execute`의 내부 로직은 funding-core. 일반적으로:
- PG 외부 승인 API
- `BackingPaymentRepository.updateBackingPayment` (status → C10 or A10)
- `AdminImmediatePaymentLogGatewayImpl.save` — 관리자 로그 INSERT (`AdminImmediatePaymentLogRepository.save`)

**접근 테이블**: `BackingPayment`, `Campaign`, `AdminImmediatePaymentLog`

---

## 7. POST `/api/admin/cancel-payment` — 관리자 결제 취소

관리자가 펀딩 중인 결제를 직접 취소.

- **Method**: `AdminOrderPaymentController.cancel`
- **Security**: `@PreAuthorize("isAdmin()")`

### Request Body — `AdminCancelPaymentRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `backingPaymentId` | `int` | ✅ | — |
| `adminId` | `int` | ✅ | — |
| `userId` | `Integer` | ✅ | 원 주문자 |

### Response — `CancelPaymentResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `backingPaymentId` | `Integer` | — |
| `orderNo` | `String` | — |

### 컨트롤러 / Proxy 코드 흐름

`CancelPaymentProxy.cancelInAdmin(request)` 내부:
1. `cancelPaymentUsecase.addAdminCancelLog(backingPaymentId, adminId)` — 관리자 취소 로그 기록
2. `cancelPaymentUsecase.cancel(CancelPaymentCommand{backingPaymentId, userId})` — 일반 취소 플로우

### DB 호출 (이 레포 Gateway)

**관리자 로그** (`BackingPaymentCancelLogGatewayImpl.saveAdminLog`):
`BackingPaymentAdminCancelLogRepository.saveAll` — Spring Data JDBC batch INSERT

**취소 로그** (`BackingPaymentCancelLogGatewayImpl.save`):
`BackingPaymentCancelLogRepository.save` — Spring Data JDBC INSERT

**결제 테이블 UPDATE** (`BackingPaymentRepository.updateBackingPayment`):
```sql
UPDATE BackingPayment
SET PayStatus = 'D10', ... , ProcDate = ?
WHERE BackingPaymentId = ?
```

PG 취소 API 호출, 포인트/쿠폰 환원 등 세부는 funding-core `CancelPaymentUsecase.cancel` 확인 필요.

**접근 테이블**: `BackingPayment`, `BackingPaymentCancelLog`, `BackingPaymentAdminCancelLog` + PG 취소 API

---

## 8. GET `/api/internal/payments` — 결제 목록 조회

- **Method**: `PaymentInternalController.paymentList`

### Request (Query, `@ModelAttribute PaymentListRequest`)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `ids` | `List<Integer>` | ⬜ `@Size(max=500)` | 펀딩 번호 배열 |

### Response — `List<PaymentListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `backingPaymentId` | `Integer` | — |
| `userId / campaignId` | `Integer` | — |
| `isCanceled` | `Boolean` | — |
| `fundingAmount / billingAmount / shippingCharge` | `long` | — |
| `payStatus` | enum `PayStatus` | — |
| `payBy / resultCode` | `String` | — |
| `regDate / procDate / cancelDate` | `LocalDateTime` | — |

### 컨트롤러 코드 흐름
`paymentProxy.list(ids)` → `ListBackingPaymentUseCase.getBackingPaymentInfo(ids)` (funding-core)

### DB 호출

`BackingPaymentRepository.findAllById(ids)` — Spring Data JDBC:
```sql
SELECT * FROM BackingPayment WHERE BackingPaymentId IN (?, ?, ...)
```

**접근 테이블**: `BackingPayment`

---

## 9. POST `/api/internal/payments/congratulation` — 메이커 축하 메일 발송

- **Method**: `PaymentInternalController.congratulateOnMakersAchievement`
- **Async**: `@Async("paymentAsyncExecutor")` — 비동기 실행

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `campaignId` | `Integer` | ✅ | — |

### Response
`ResponseWrapper<Void>` (즉시 200 반환, 실제 작업은 백그라운드)

### 컨트롤러 코드 흐름
`paymentProxy.sendCongratulationMailToMaker(campaignId)` — `@Async`로 실행, `CampaignCongratulationHistoryUseCase.congratulationMaker(campaignId)` 위임 (funding-core)

### DB 호출

`adapter/infrastructure/.../domain/campaigncongratulationhistory`에 관련 구현체 존재(이 문서 범위 밖). 이 레포에는 `CampaignCongratulationHistoryMapper` 관련 XML이 있을 가능성.

→ **상세 SQL은 funding-core 및 campaigncongratulationhistory 인프라 확인 필요**

---

## 10. POST `/api/internal/payments/extra-info` — 결제 추가 정보 저장

NICE PG 응답 중 일부(카드번호 일부 등)를 사후 저장.

- **Method**: `PaymentInternalController.saveExtraInfo`

### Request Body — `SavePaymentExtraInfoRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ `@NotNull` | — |
| `paymentKey` | `String` | ✅ `@NotEmpty` | 검색 키 |
| `paymentKeyType` | enum `PaymentKeyType` | ✅ `@NotNull` | `BILL_KEY / BACKING_PAYMENT_ID / ORDER_NO` |
| `cardNumber` | `String` | ⬜ | 카드 번호 (마스킹된 것) |

### Response
`ResponseWrapper<Void>`

### 컨트롤러 코드 흐름
`paymentProxy.saveExtraInfo(command)` → `PaymentExtraInfoSaveUseCase.saveExtraInfo` (funding-core)

### DB 호출

Usecase가 호출할 가능성이 높은 SQL:

**① 대상 결제 조회** (`BackingPaymentMapper.findByKeyAndUserId` — paymentKeyType별 분기)
```sql
SELECT *
FROM BackingPayment BP
WHERE BP.UserId = ?
  AND BP.BillKey = ?           -- BILL_KEY
  -- OR AND BP.BackingPaymentId = ?  -- BACKING_PAYMENT_ID
  -- OR AND BP.Oid = ?           -- ORDER_NO
```

**② 카드 번호 저장** (`BackingPaymentMapper.savePaymentExtraInfo`)
```sql
UPDATE BackingPayment
SET PayMemo1 = ?
WHERE BackingPaymentId = ?
```

UseCase 호출 여부는 funding-core 확인 필요.

**접근 테이블**: `BackingPayment`

---

## 11. POST `/api/internal/payments/card-registration` — 카드 등록 정보 저장

- **Method**: `PaymentInternalController.saveCardInfo`

### Request Body — `SaveCardInfoRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ `@NotNull` | — |
| `paymentKey` | `String` | ✅ | — |
| `paymentKeyType` | `String` | ✅ | — |
| `cardNumber` | `String` | ✅ | — |
| `cardExpireYear / cardExpireMonth` | `Long` | ✅ | 만료년/월 |
| `currencyCode` | enum `CurrencyCode` | ⬜ | — |

### Response — `CardRegistrationInfo`
이 DTO는 `core/domain`에 위치 — 이 레포 응답 payload 디렉토리에 명시되지 않음.

### 컨트롤러 코드 흐름
`paymentProxy.saveCardInfo(command)` → `PaymentExtraInfoSaveUseCase.saveCardInfo` (funding-core)

### DB 호출
이 레포에 전용 Gateway 구현체가 없음. `BackingPayment` UPDATE 또는 별도 `CardRegistration` 테이블 INSERT 가능성.

→ **funding-core 확인 필요**

---

## 12. POST `/api/internal/payments/billkey-verifications` — 빌키 검증 상태 업데이트

외부 PG의 빌키 검증 결과(성공/실패)를 이 서비스에 반영.

- **Method**: `PaymentInternalController.updateVerificationStatus`

### Request Body — `BillkeyVerificationRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ `@NotNull` | — |
| `billKey` | `String` | ✅ `@NotNull` | 빌키 |
| `approvalStatus` | enum `ApprovalStatus` | ✅ `@NotNull` | 승인 상태 |
| `referenceKey` | `String` | ⬜ | — |
| `billingAmount` | `BigDecimal` | ⬜ | 테스트 결제 금액 |
| `currencyCode` | enum (default KRW) | ⬜ | — |
| `mid` | `String` | ⬜ | — |

### Response
`ResponseWrapper<Void>`

### 컨트롤러 코드 흐름
`paymentProxy.updateVerificationStatus(command)` → `BillkeyVerificationUseCase.updateVerificationStatus` (funding-core)

### DB 호출 (이 레포)

`BillkeyVerificationStatusRepository` (Spring Data JDBC):
```java
BillkeyVerificationStatusDto findByBackingPaymentId(Integer backingPaymentId);
// save/update는 CrudRepository 기본 메서드
```

UseCase는 보통 `findByBackingPaymentId` → `save(updatedDto)` 순서로 호출.

**접근 테이블**: `BillkeyVerificationStatus`

---

## 13. POST `/api/cancel-payment` — 사용자 결제 취소

- **Method**: `CancelPaymentController.cancel`

### Request Body — `CancelPaymentRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `backingPaymentId` | `Integer` | ✅ `@NotNull` | — |

### Response — `CancelPaymentResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `backingPaymentId` | `Integer` | — |
| `orderNo` | `String` | — |

### 컨트롤러 코드 흐름
`CancelPaymentProxy.cancel(CancelPaymentCommand{backingPaymentId, userId=SecurityUtils.currentUserId()})` → `CancelPaymentUsecase.cancel` (funding-core)

### DB 호출 (이 레포 Gateway)

`CancelPaymentUsecase.cancel`이 호출할 수 있는 Gateway:

**① 결제 정보 조회** — `BackingPaymentRepository.findByIdAndUserId(backingPaymentId, userId)` (userId 격리로 본인 확인)

**② 취소 로그 INSERT** — `BackingPaymentCancelLogGatewayImpl.save` → `BackingPaymentCancelLogRepository.save`:
```sql
INSERT INTO BackingPaymentCancelLog (...) VALUES (...)
```

**③ 결제 상태 UPDATE** — `BackingPaymentRepository.updateBackingPayment`:
```sql
UPDATE BackingPayment
SET PayStatus = ?, ResultCode = ?, Description = ?, ProcDate = ?
WHERE BackingPaymentId = ?
```

**④ 추가** — 포인트/쿠폰 환원, PG 취소 API 호출 등은 funding-core 로직

**접근 테이블**: `BackingPayment`, `BackingPaymentCancelLog`, (추가 가능: `BackingPaymentPoint`, `BackingPaymentCoupon`) + PG 취소 API

---

## 14. POST `/api/internal/cancel-payment/bulk` — 벌크 취소

내부 서비스에서 여러 결제를 한 번에 취소.

- **Method**: `CancelPaymentInternalController.cancelBulk`

### Request Body — `CancelPaymentInternalRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `backingPaymentIds` | `List<Integer>` | ⬜ `@Size(max=1000)` | — |

### Response — `CancelPaymentInternalResult`
| 필드 | 타입 | 설명 |
|---|---|---|
| `count` | `Integer` | 처리 건수 |

### 컨트롤러 코드 흐름
`CancelPaymentProxy.cancelBulk(command)` → `CancelPaymentUsecase.cancelBulk` (funding-core)

### DB 호출
13번과 동일 Gateway 세트 반복 호출 (funding-core가 batch 처리 방식 결정)

---

## 15. POST `/api/internal/cancel-payment/bulk/payment-gateway` — PG 취소 전용 벌크

일반 취소 경로와 다르게 **PG 외부 취소**만 처리하는 경로.

- **Method**: `CancelPaymentInternalController.cancelBulkPg`

### Request / Response
14번과 동일

### 컨트롤러 코드 흐름
`CancelPaymentProxy.cancelBulkPg(command)` → `CancelPaymentUsecase.cancelBulkPg` (funding-core)

### DB 호출
`cancelBulk`와 유사하나 PG 취소 중심. 구체 차이점은 funding-core 확인 필요.

---

## 16. GET `/api/payment-progress/campaigns/{campaignId}/relevant-info` — 프로젝트 결제 진행 연관 정보

예상 결제일 목록을 반환.

- **Method**: `PaymentProgressController.getPaymentRelevantInfo`

### Response — `PaymentRelevantInfoResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `expectedPaymentDays[].ordinal` | `int` | 결제 차수 (1~) |
| `expectedPaymentDays[].whenPayFor` | `ZonedDateTime` | 결제 예정일 |

### 컨트롤러 코드 흐름
`paymentProgressProxy.getPaymentRelevantInfo(campaignId)` → `PaymentRelevantInfoUseCase.getPaymentRelevantInfo` (funding-core)

### DB 호출 (`PaymentProgressGatewayImpl.getExpectedPaymentDay`)

**① 캠페인 마커 조회** (`CampaignMarkerMapper.selectCampaignVersion`) — 신규 버전이면 4, 구버전이면 2
```sql
-- CampaignMarker에서 버전 마커 조회 (실제 XML은 CampaignMarkerMapper.xml)
```

**② 영업일 기준 N일 뒤 날짜 조회** (`EventDayMapper.businessDaysSearch`)
```sql
SELECT EventDate, Name, Type
FROM EventDay
WHERE 1=1
  /* daysType=PLUS면 */ AND EventDate > ?
  /* onlyWeekDay=true면 */ AND Type = 'o'
ORDER BY EventDate
LIMIT ?
```

- `WhenHoldTo` 다음 날부터 N 영업일 (2 또는 4)
- 각 결과 row를 1부터 차수로 ordinal 부여

**접근 테이블**: `EventDay`, `CampaignMarker`

---

## 17. GET `/api/studio/payment-progress/campaigns/{campaignId}/report` — 메이커 스튜디오 결제 현황 리포트

**단일 엔드포인트가 5+개의 집계 SQL을 조합**하는 무거운 조회.

- **Method**: `PaymentProgressStudioController.getPaymentReport`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`

### Response — `StudioPaymentReportResponse`

| 최상위 | 필드 | 타입 | 설명 |
|---|---|---|---|
| `paymentCompleted` | `expectedPaymentDays[]` | `{ordinal, whenPayFor}` | 예상 결제일 |
| | `paymentCompletedRate` | `long` | 결제 완료율 |
| | `paymentCompletedCnt` | `long` | 결제 완료 건수 |
| | `paymentCompletedAmount` | `long` | 완료 금액 |
| | `rewardAmount / donation / shippingCharge / billingAmount` | `long` | 세부 금액 |
| | `benefitAmount / benefitAmountByMaker` | `long` | 쿠폰+포인트+배송비지원 (메이커 부담 분리) |
| | `domesticAmount / overseasAmount` | `long` | 국내/해외 |
| | `overseasAmountDetails[].countryCode/countryName/amount` | | 국가별 상세 |
| `refundCompleted` | `refundCompletedAmount / rewardAmount / donation / shippingCharge / paymentCancelAmount / benefitAmount / benefitAmountByMaker / domesticAmount / overseasAmount` | `long` | 환불 상세 |
| | `overseasAmountDetails[]` | | 국가별 환불 상세 |

### 컨트롤러 코드 흐름
`paymentProgressProxy.getPaymentReport(campaignId)` → `PaymentReportUseCase.getPaymentReport` (funding-core)

### MySQL 쿼리 (`PaymentProgressGatewayImpl`이 호출하는 5개 쿼리)

**① 결제 완료 요약** (`PaymentSummationMapper.findPaymentSummation`) — **복잡한 4중 LEFT JOIN 서브쿼리**
```sql
SELECT A.CampaignId,
       ROUND(IFNULL(PAYF.BackedCnt,0) / PAYR.BackedCnt * 100) AS paymentCompletedRate,
       IFNULL(PAYF.BackedCnt, 0) AS paymentCompletedCnt,
       IFNULL(PAYF.ShippingCharge,0) AS shippingCharge,
       IFNULL(PAYF.AddDonation,0)   AS addDonation,
       IFNULL(PAYD.BillingAmount, 0) + IFNULL(PAYO.BillingAmount, 0) AS billingAmount,
       IFNULL(PAYD.ApplyPoint,0) + IFNULL(PAYO.ApplyPoint,0) AS applyPoint,
       IFNULL(PAYD.ApplyCoupon,0) + IFNULL(PAYO.ApplyCoupon,0) AS applyCoupon,
       IFNULL(PAYD.ApplyCouponByMaker,0) + IFNULL(PAYO.ApplyCouponByMaker,0) AS applyCouponByMaker,
       IFNULL(PAYD.ApplyDiscountShippingAmount,0) + IFNULL(PAYO.ApplyDiscountShippingAmount,0) AS applyDiscountShippingCharge,
       /* 국내 총액 */ IFNULL(PAYD.BillingAmount,0) + IFNULL(PAYD.ApplyPoint,0) + ... AS domesticAmount,
       /* 해외 총액 */ IFNULL(PAYO.BillingAmount,0) + IFNULL(PAYO.ApplyPoint,0) + ... AS overseasAmount
FROM Campaign A
/* PAYR: 결제 예정(전체 비취소) */ LEFT OUTER JOIN (
   SELECT BP.CampaignId, COUNT(*) AS BackedCnt
   FROM BackingPayment BP WHERE BP.IsCanceled = FALSE AND BP.CampaignId = ?) PAYR ON ...
/* PAYF: 결제 완료 (status C10/Z11/D11/P10) */ LEFT OUTER JOIN (
   SELECT BP.CampaignId, COUNT(*) AS BackedCnt, SUM(BP.ShippingCharge), SUM(BP.AddDonation)
   FROM BackingPayment BP WHERE BP.PayStatus IN ('C10','Z11','D11','P10') AND BP.CampaignId = ?) PAYF ON ...
/* PAYD: 국내(KR) 항목별 결제 금액 */ LEFT OUTER JOIN (
   SELECT BP.CampaignId, SUM(BP.BillingAmount), IFNULL(SUM(P.PointAmount),0),
          SUM(CASE WHEN C.CostBearer='WADIZ' THEN C.CouponAmount ELSE 0 END),
          SUM(CASE WHEN C.CostBearer='MAKER' THEN C.CouponAmount ELSE 0 END),
          SUM(BB.DiscountAmount)
   FROM BackingPayment BP
        LEFT JOIN BackingPaymentPoint P              ON BP.BackingPaymentId = P.BackingPaymentId
        LEFT JOIN BackingPaymentCoupon C             ON BP.BackingPaymentId = C.BackingPaymentId
        LEFT JOIN BackingPaymentDiscountBenefit BB   ON BP.BackingPaymentId = BB.BackingPaymentId AND BB.BenefitType ='SHIPPING_FEE'
   WHERE BP.PayStatus IN ('Z11','C10','D11','P10') AND BP.CampaignId = ?
     AND (BP.CountryCode IS NULL OR BP.CountryCode = 'KR')) PAYD ON ...
/* PAYO: 해외(!KR) 동일 구조 */ LEFT OUTER JOIN (... BP.CountryCode != 'KR' ...) PAYO ON ...
WHERE A.CampaignId = ?
GROUP BY A.CampaignId
```

**② 해외 결제 국가별** (`findOverseasPaymentSummation`)
```sql
SELECT BP.CountryCode,
       SUM(BP.BillingAmount) AS billingAmount,
       IFNULL(SUM(P.PointAmount),0) AS applyPoint,
       SUM(CASE WHEN C.CostBearer='WADIZ' THEN C.CouponAmount ELSE 0 END) AS applyCoupon,
       SUM(CASE WHEN C.CostBearer='MAKER' THEN C.CouponAmount ELSE 0 END) AS applyCouponByMaker,
       SUM(BB.DiscountAmount) AS applyDiscountShippingCharge
FROM BackingPayment BP
     LEFT JOIN BackingPaymentPoint P              ON BP.BackingPaymentId = P.BackingPaymentId
     LEFT JOIN BackingPaymentCoupon C             ON BP.BackingPaymentId = C.BackingPaymentId
     LEFT JOIN BackingPaymentDiscountBenefit BB   ON BP.BackingPaymentId = BB.BackingPaymentId AND BB.BenefitType ='SHIPPING_FEE'
WHERE BP.PayStatus IN ('Z11','C10','D11','P10')
  AND BP.CampaignId = ? AND BP.CountryCode != 'KR'
GROUP BY BP.CountryCode
```

**③ 환불 완료 요약** (`findRefundSummation`)
```sql
SELECT IFNULL(SUM(BPR.TotalRefundAmount),0)      AS refundCompletedAmount,
       IFNULL(SUM(BPR.RewardItemRefundAmount),0) AS rewardAmount,
       IFNULL(SUM(BPR.DonationRefundAmount),0)   AS addDonation,
       IFNULL(SUM(BPR.ShippingRefundAmount),0)   AS shippingCharge,
       IFNULL(SUM(BPR.PointRefundAmount),0)      AS refundPoint,
       SUM(CASE WHEN C.CostBearer='WADIZ' THEN BPR.CouponRefundAmount ELSE 0 END) AS refundCoupon,
       SUM(CASE WHEN C.CostBearer='MAKER' THEN BPR.CouponRefundAmount ELSE 0 END) AS refundCouponByMaker,
       IFNULL(SUM(BB.DiscountAmount),0)          AS refundDiscountShippingCharge,
       IFNULL(SUM(BPR.PaymentCancelAmount),0)    AS paymentCancelAmount
FROM BackingPaymentRefund BPR
     JOIN BackingPayment BP          ON BPR.BackingPaymentId = BP.BackingPaymentId
     LEFT JOIN BackingPaymentCoupon C ON BPR.BackingPaymentId = C.BackingPaymentId
     LEFT JOIN BackingPaymentDiscountBenefit BB
               ON BPR.BackingPaymentId = BB.BackingPaymentId
              AND BB.BenefitType = 'SHIPPING_FEE'
              AND BB.IsRefund = TRUE
              AND BB.BackingPaymentId NOT IN (
                  SELECT DISTINCT BackingPaymentId FROM RewardRefund
                  WHERE Type = 'REVISED'
                     OR (Type IN ('TRUSTED','OTHER') AND RefundAmountType = 'EXCLUSIVE_SHIPPING_AMOUNT'))
WHERE BP.IsCanceled = FALSE
  AND BPR.BackingPaymentId IN (SELECT BackingPaymentId FROM RewardRefund WHERE CampaignId = ? AND Status = 'REFUNDED')
```

**④ 해외 환불 국가별** (`findOverseasRefundSummation`)
```sql
SELECT BP.CountryCode,
       SUM(BPR.PointRefundAmount)       AS refundPoint,
       SUM(CASE WHEN C.CostBearer='WADIZ' THEN BPR.CouponRefundAmount ELSE 0 END) AS refundCoupon,
       SUM(CASE WHEN C.CostBearer='MAKER' THEN BPR.CouponRefundAmount ELSE 0 END) AS refundCouponByMaker,
       SUM(BB.DiscountAmount)           AS refundDiscountShippingCharge,
       SUM(BPR.PaymentCancelAmount)     AS paymentCancelAmount
FROM BackingPaymentRefund BPR
     JOIN BackingPayment BP ON BPR.BackingPaymentId = BP.BackingPaymentId
     LEFT JOIN BackingPaymentCoupon C ON BPR.BackingPaymentId = C.BackingPaymentId
     LEFT JOIN BackingPaymentDiscountBenefit BB
               ON BPR.BackingPaymentId = BB.BackingPaymentId
              AND BB.BenefitType = 'SHIPPING_FEE'
              AND BB.IsRefund = TRUE
              AND BB.BackingPaymentId NOT IN (SELECT DISTINCT BackingPaymentId FROM RewardRefund WHERE Type='REVISED' OR (Type IN ('TRUSTED','OTHER') AND RefundAmountType = 'EXCLUSIVE_SHIPPING_AMOUNT'))
WHERE BP.IsCanceled = FALSE
  AND BPR.BackingPaymentId IN (SELECT BackingPaymentId FROM RewardRefund WHERE CampaignId = ? AND Status = 'REFUNDED')
GROUP BY BP.CountryCode
```

**⑤ 예상 결제일 (16번과 동일)** — `CampaignMarkerMapper.selectCampaignVersion` + `EventDayMapper.businessDaysSearch`

**접근 테이블**: `Campaign`, `BackingPayment`, `BackingPaymentPoint`, `BackingPaymentCoupon`, `BackingPaymentDiscountBenefit`, `BackingPaymentRefund`, `RewardRefund`, `CampaignMarker`, `EventDay`

---

## 18. 참고 — 이 문서의 Gateway / Repository / Mapper

### Gateway 구현체 (이 레포)

| 구현체 | 주 메서드 → Repository/Mapper |
|---|---|
| `BackingPaymentGatewayImpl` | `save`/`updateBackingPayment`/`getById`/`getByIdAndUserId`/`findAllByIds`/`findByRecentPayBy`/`findByUserIdAndTid` → `BackingPaymentRepository` |
| `OrderPaymentRedisGatewayImpl` | `isOrderProcessing`/`deleteProcessingKey` → Redis `SET...NX`, `DEL` (`orderpayment:processing:{tid}`) |
| `AdminImmediatePaymentLogGatewayImpl` | `save` → `AdminImmediatePaymentLogRepository` |
| `BackingPaymentCancelLogGatewayImpl` | `save` + `saveAdminLog(List)` → `BackingPaymentCancelLogRepository` + `BackingPaymentAdminCancelLogRepository` |
| `PaymentProgressGatewayImpl` | `getCompletedPayment`/`getOverseasPayment`/`getCompletedRefund`/`getOverseasRefund`/`getExpectedPaymentDay` → `PaymentSummationMapper` + `EventDayMapper` + `CampaignMarkerMapper` |

### Spring Data JDBC Repository 핵심 쿼리

**`BackingPaymentRepository`** — 파생 메서드 대부분 + 커스텀 @Query:
```java
boolean existsByUserIdAndPayStatusNotIn(int userId, Collection<PayStatus>);
boolean existsByCampaignIdAndPayStatusIn(int campaignId, Collection<PayStatus>);
@Query("SELECT DISTINCT CampaignId FROM BackingPayment WHERE UserId = :userId AND IsCanceled = FALSE")
List<Integer> findAllDistinctCampaignIdByUserIdAndIsCanceledFalse(int userId);
Optional<BackingPaymentDto> findByIdAndUserId(Integer id, Integer userId);
Optional<BackingPaymentDto> findByUserIdAndTid(Integer userId, String tid);
Optional<BackingPaymentDto> findTop1ByUserIdOrderByRegDateDesc(int userId);
@Modifying @Query("UPDATE BackingPayment SET Tid=:tid,Mid=:mid,PayStatus=:payStatus,ResultCode=:resultCode,Description=:description,ProcDate=:procDate WHERE BackingPaymentId = :backingPaymentId")
int updateBackingPayment(...);
```

### UseCase 중 이 레포에 **직접 구현이 없는 것**
- `OrderPaymentUsecase`, `ApproveStatusUseCase` (order-payment 전체)
- `CancelPaymentUsecase` (취소 전체)
- `ImmediatePaymentUseCase` (즉시 결제)
- `ListBackingPaymentUseCase`
- `PaymentExtraInfoSaveUseCase` (extra-info, card-registration)
- `BillkeyVerificationUseCase`
- `CampaignCongratulationHistoryUseCase` (축하 메일)
- `PaymentReportUseCase`, `PaymentRelevantInfoUseCase` (progress)

### 접근 테이블 합계

`BackingPayment`, `BackingPaymentPoint`, `BackingPaymentCoupon`, `BackingPaymentDiscountBenefit`, `BackingPaymentRefund`, `BackingPaymentCancelLog`, `BackingPaymentAdminCancelLog`, `AdminImmediatePaymentLog`, `BillkeyVerificationStatus`, `RewardRefund`, `Campaign`, `CampaignMarker`, `EventDay` + Redis 락 + 외부 PG (NICE/Stripe/Alipay) + 외부 메일 서비스

### 결제 생명주기 상태 (PayStatus 코드)

| 코드 | 의미 |
|---|---|
| `A10` | 결제 예약(카드 등록 완료, 결제 미발생) |
| `B10` | 결제 예약(빌키 검증 중) |
| `C10` | 결제 완료 |
| `D10` | 결제 취소 |
| `D11` | 결제 완료 후 환불 |
| `E10` | (집계 포함되는 특수 상태) |
| `P10` | 종료 후 결제 완료(국제/지연) |
| `Z11` | 결제 확정 |

해당 코드는 집계 SQL의 WHERE 절에서 반복 사용됨. 완전한 정의는 funding-core `PayStatus` enum 참조.
