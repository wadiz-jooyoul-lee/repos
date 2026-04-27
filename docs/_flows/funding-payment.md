# Flow: 펀딩 서포팅 결제 (신규 주문)

> 서포터가 프로젝트에 리워드를 선택하고 결제하는 주요 경로. 세션 → 시트 → PG 인증 → 승인 → 성공 페이지의 다단계 체인.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/funding/orders.service.ts:132` (FE `orders/sheet` 호출)
  - `wadiz-frontend/static/packages/reward-simple-pay-app/src/components/RewardPaymentCTA/RewardPaymentCTA.tsx:79, 342` (간편결제 시트)
  - `com.wadiz.web/WEB-INF/web.xml:126-202` (`/web/apip/*` servlet 매핑)
  - `com.wadiz.web/src/main/java/com/wadiz/api/httpproxy/ApiProxyServletDispatcher.java:13-55`
  - `com.wadiz.web/src/main/java/com/wadiz/web/wpurchase/controller/WWEBPurchaseRewardController.java:72-443` (JSP 기반 결제 페이지 + AJAX 예약)
  - `docs/com.wadiz.api.funding/api-details/order.md` (기 분석)
  - `docs/com.wadiz.api.funding/api-details/payment-flow.md` (기 분석)
- **외부 경계**: Nicepay/Stripe/Alipay PG 내부, `com.wadiz.funding.core:funding-core` jar 내 UseCase 구현, ApiProxyServlet 실체(external jar `com.wadiz.core.httpproxy.ApiProxyServlet`).

---

## 🔑 두 개의 경로가 공존

본격 분석 전 이 플로우만의 핵심 관찰:

| 경로 | 핸들러 | 용도 |
|---|---|---|
| **`/web/apip/funding/*`** | `com.wadiz.core.httpproxy.ApiProxyServlet` (web.xml:197-202) 역프록시 → `com.wadiz.api.funding` | **REST API** — 주문 세션·시트·결제 리소스 |
| **`/web/reward/*`, `/web/wpurchase/reward/*`** | com.wadiz.web 자체 `@Controller` → JSP · 자체 DB | **페이지 렌더링 + 일부 AJAX** |

web.xml `/web/apip/funding/supporters/my/fundings` 같은 특정 URL만 다른 servlet 이 선점하므로 (web.xml:126-128 → `ApiProxyServletDispatcher` 제한 경로), 대부분의 `/web/apip/*` 요청은 바로 funding 서비스로 직행한다.

---

## 1. Client Trigger (FE/App)

### 1.1 wadiz-frontend
- **시트 CRUD**: `packages/api/src/web/funding/orders.service.ts:132`
  - `POST /web/apip/funding/orders/sheet/{token}` (시트 생성)
  - `DELETE /web/apip/funding/orders/sheet/{token}`
- **간편결제**: `static/packages/reward-simple-pay-app/src/components/RewardPaymentCTA/RewardPaymentCTA.tsx:79, 342`
  - `fetchFundingApi('orders/sheet/{token}', ...)`
- **fetch 래퍼**: `packages/api/src/fetch.ts` + 펀딩 전용 `fetchFundingApi` (내부에서 `/web/apip/funding/` prefix 부착)
- **Host**: `https://www.wadiz.kr` (VITE_SERVICE_API_URL)

### 1.2 wadiz-android / wadiz-ios
- Phase 2 미진행. 동일 주문 세션/시트 경로를 호출할 것으로 추정되나 확인 필요.

---

## 2. Hub — `com.wadiz.web`

### 2.1 REST 경로 (`/web/apip/funding/*`) — **투명 프록시**
```xml
<!-- com.wadiz.web/web/WEB-INF/web.xml:197-202 -->
<servlet-class>com.wadiz.core.httpproxy.ApiProxyServlet</servlet-class>
<url-pattern>/web/apip/*</url-pattern>
```
내부 디스패처는 `ApiProxyServletDispatcher.forward()` 를 통해 동일 경로로 request dispatch.

→ 결과: FE 의 `/web/apip/funding/orders/sheet/{token}` 는 그대로 **com.wadiz.api.funding** 에 도달. com.wadiz.web 의 Java 코드는 통과만 함 (비즈니스 로직 없음).

### 2.2 페이지 + AJAX 경로 (`/web/wpurchase/reward/*`)
`WWEBPurchaseRewardController` (`wpurchase/controller/WWEBPurchaseRewardController.java:72`) 가 결제 단계별 페이지 렌더링.

```java
// :72
@RequestMapping(value="/web/wpurchase/reward/*")
public class WWEBPurchaseRewardController {

    @RequestMapping(value = "/step10/{campaignId}")   // :152  — 리워드 선택 진입
    ...
    @RequestMapping(value = "/step20")                 // :216  — 결제 수단 입력 페이지
    public ModelAndView step20(...) { ...; mv.setViewName("wpurchase/reward/step20"); ... }

    @RequestMapping(value = "/ajaxRequestNiceCreditPurchaseReservation",
                    produces = "application/json;charset=UTF-8")   // :335 — NICE 결제 예약 AJAX
    ...
    @RequestMapping(value = "/result10/{backingPaymentId}")         // :373 — 결제 성공 페이지
    public ModelAndView result10(@PathVariable int backingPaymentId) { ... }

    @RequestMapping("/payment/fail")                                // :443
    ...
}
```

---

## 3. Backend Service API (`com.wadiz.api.funding`)

`ApiProxyServlet` 을 통해 도달하는 엔드포인트들. 상세 분석은 [`docs/com.wadiz.api.funding/api-details/`](../com.wadiz.api.funding/api-details/).

### 3.1 Order — 주문 세션·시트
[`docs/.../order.md`](../com.wadiz.api.funding/api-details/order.md)

| Method | Path (funding internal) | 설명 |
|---|---|---|
| POST | `/api/orders/session` | 주문 세션 생성 (Redis 임시 저장) |
| GET | `/api/orders/session/{token}` | 세션 조회 |
| POST | `/api/orders/sheet/{token}` | 주문서 생성 (리워드/쿠폰/포인트 확정) |
| DELETE | `/api/orders/sheet/{token}` | 주문서 삭제 (뒤로가기 등) |

### 3.2 Payment — PG 인증·승인
[`docs/.../payment-flow.md`](../com.wadiz.api.funding/api-details/payment-flow.md)

- `OrderPaymentController` (`/api/order-payment`) — Nicepay/Stripe/Alipay 콜백 수신 + `OrderPaymentUsecase.pay()` 위임
- **콜백 성공 시 redirect**: `/web/wpurchase/reward/result10/{backingPaymentId}` → com.wadiz.web 의 JSP 결과 페이지
- **실패 시**: `/web/wpurchase/reward/step20?token={token}` 또는 `/funding/payment?token={token}` (해외)

### 3.3 PG (외부)
- **Nicepay** — 국내 카드/계좌/휴대폰
- **Stripe** — 해외 카드 (결제 수단별 분기)
- **Alipay+** — 중화권/동남아

PG 는 form-urlencoded POST 로 `/api/order-payment/{payType}/{campaignId}/{token}` 콜백 발송.

---

## 4. DB

### 4.1 Redis (`com.wadiz.api.funding`)
- `OrderSession` · `OrderSheet` — 결제 완료 전 임시 데이터 (TTL)
- 결제 처리 락: `com.wadiz.api.funding.redis.orderpayment:processing:{tid}` (중복 방지)

### 4.2 MySQL

`com.wadiz.api.funding` (Spring Data JDBC + MyBatis) 와 `com.wadiz.web` 이 **동일 MySQL 스키마 공유**.

| 테이블 | 용도 | 기록 주체 |
|---|---|---|
| `BackingPayment` | 서포팅 결제 메인 (TID·Mid·PayStatus·ResultCode·FundingAmount·IsCanceled ...) | funding (`BackingPaymentGatewayImpl`) |
| `BackingReward` / `Reward` | 주문된 리워드 스냅샷 | funding |
| `CouponTransaction` | 쿠폰 사용 이력 | `com.wadiz.api.reward` (funding 에서 외부 호출 가능성 있음) |
| `Point*` | 포인트 차감 기록 | 외부 시스템 |
| `Campaign` | 누적 펀딩 금액 (SUM 집계용) | 읽기 전용 |

### 4.3 핵심 SQL 요약 (`BackingPayment`)
```sql
-- BackingPaymentGatewayImpl (Spring Data JDBC, funding-core 내부 호출)
INSERT INTO BackingPayment (UserId, CampaignId, FundingAmount, Tid, Mid, PayStatus, ...)
SELECT ... FROM BackingPayment WHERE UserId = ? AND Tid = ?   -- 중복 결제 방지
UPDATE BackingPayment SET Tid=?, Mid=?, PayStatus=?, ResultCode=?, Description=?, ProcDate=?
  WHERE BackingPaymentId = ?
```
상세 SQL 은 funding 모듈의 repository + payment-flow 문서 참조.

---

## 엔드투엔드 시퀀스

```
[FE: RewardPaymentCTA.tsx]
   │ 1) POST /web/apip/funding/orders/session             (시작)
   │ 2) POST /web/apip/funding/orders/sheet/{token}       (리워드/쿠폰 확정)
   ▼
[www.wadiz.kr  — ApiProxyServlet (web.xml:202)]
   │  투명 프록시 (비즈니스 로직 없음)
   ▼
[com.wadiz.api.funding  — Order/OrderSheet Controllers]
   │  Redis TTL 세션 저장
   │  DB: Campaign·Reward 조회로 유효성 검증
   └─ 응답: token, 결제 준비 데이터

[FE 이동]  window.location = /web/wpurchase/reward/step20?token=...

[www.wadiz.kr — WWEBPurchaseRewardController#step20 (:216)]
   │  JSP 렌더링: 결제수단 입력 폼 + SDK
   │
   │ AJAX: POST /web/wpurchase/reward/ajaxRequestNiceCreditPurchaseReservation (:335)
   │      └─ com.wadiz.web 자체 처리 (NICE 예약 토큰 취득)
   │
   │ SDK → PG (Nicepay / Stripe / Alipay+) 인증 창
   ▼
[PG (외부)]
   │  사용자 인증 완료 → callback form-urlencoded POST
   ▼
[com.wadiz.api.funding  — OrderPaymentController#payViaNiceAuth]
   │  :27  POST /api/order-payment/{payType}/{campaignId}/{token}
   │  AuthResultCode 검증
   │  OrderPayProxy.pay(...) → funding-core OrderPaymentUsecase.pay (외부 jar)
   │     ├─ Redis: SET processing:{tid} NX EX 300
   │     ├─ MySQL: INSERT BackingPayment
   │     ├─ MySQL: savePaymentResult (auth/cardResult 머지)
   │     ├─ MySQL: UPDATE BackingPayment (PayStatus/ResultCode)
   │     └─ Redis: DEL processing:{tid}
   │
   │  성공 → HTTP 302 redirect
   ▼
[www.wadiz.kr — WWEBPurchaseRewardController#result10/{id} (:373)]
   │  JSP: wpurchase/reward/result10  (결제 완료 페이지)
```

---

## 경계·미탐색

1. **funding-core jar** — `OrderPaymentUsecase.pay`, `CancelPaymentUsecase`, `ImmediatePaymentUseCase` 등 UseCase 구현체는 외부 jar. 호출 순서/분기 확인 불가.
2. **ApiProxyServlet 내부 구현** — `com.wadiz.core.httpproxy.ApiProxyServlet` 은 외부 jar. 실제 타깃 호스트 해석(`application-*.yml` 또는 ENV) 은 별도 추적.
3. **간편결제(Simple Pay) 경로** — `static/packages/reward-simple-pay-app` 은 별도 번들. step20 페이지 대신 모달 UX 로 동일 API 시퀀스를 호출하는 것으로 관측되나 세부 이벤트 흐름은 추가 분석.
4. **쿠폰·포인트 차감 원자성** — funding 측에서 reward-api 쿠폰 차감을 어떻게 처리(사전 홀드 vs 승인 직후)하는지 확인 필요.
5. **해외 결제 분기** (`locale != KOREA`) — Stripe/Alipay 경로의 redirect URL 이 다르다 (`/funding/payment/completed/{id}`). 다국어 페이지 라우팅 별도 검증.
6. **페이지 + AJAX + 프록시 하이브리드** — step20 같은 JSP 중심 페이지가 내부 AJAX + 외부 PG SDK + 프록시 API 세 가지를 동시에 사용. 모든 이탈 경로(뒤로가기·새로고침) 시 세션/시트 정리는 별도 추적 필요.
