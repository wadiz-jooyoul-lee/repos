# Flow: 펀딩 서포팅 결제 (신규 주문)

> 서포터가 프로젝트에 리워드를 선택하고 결제하는 주요 경로입니다.
> 세션을 만들고, 주문서를 확정하고, PG 인증을 거쳐 승인한 뒤 완료 화면으로 갑니다.

> 🔍 **2026-10-06 본문 전면 점검** — 결제 페이지가 **통째로 이관**됐습니다
>
> `FE1-2005`(2026-09-28)가 **두 저장소를 같은 날 함께** 바꿨습니다.
>
> | 저장소 | 커밋 | 지운 양 |
> |---|---|---|
> | `com.wadiz.web` | `0d0b0a07` | 9파일 **2,416줄** — ~~`step20.jsp`~~(1,401줄)와 예약결제 서비스 |
> | `wadiz-frontend` | `391bd419` | 28파일 **2,005줄** — `entries/reward/src/payments/` 와 결제 화면 컴포넌트 |
>
> 이 문서는 **없어진 JSP 페이지를 중심**으로 쓰여 있었습니다. 아래를 고쳤습니다.
>
> | # | 어디가 | 무엇이 틀렸나 |
> |---|---|---|
> | 1 | 2.2 절 전체 | `step20` 이 **결제 수단 입력 페이지**를 띄운다고 했습니다. 지금은 **메인으로 되돌려 보내기만** 합니다 |
> | 2 | 2.2 절 | `ajaxRequestNiceCreditPurchaseReservation` 와 `/payment/fail` 을 적어 뒀는데 **둘 다 없습니다** |
> | 3 | 3.1 Order 표 | 엔드포인트 4개만 적혀 있었습니다. **실제는 7개**이고 그중 하나는 `v2` 입니다 |
> | 4 | 3.2 실패 경로 | `step20?token=` 으로 간다고 했습니다. 지금은 **`/web/funding/payment?token=&failureType=`** 입니다 |
> | 5 | 27줄 | `web.xml:126-128` 을 "다른 servlet 이 선점"이라 했습니다. **실제는 필터 매핑**입니다 |
> | 6 | 기록 범위 | ~~`RewardPaymentCTA.tsx`~~ 를 읽은 파일로 들었는데 **삭제된 파일**입니다 |
> | 7 | 시퀀스 | step20 단계를 지나는 그림이었습니다. 새 경로로 다시 그렸습니다 |
>
> ### 결제 화면이 어디로 갔나
>
> 레거시 JSP 에서 **리액트 셸**로 옮겼습니다. 국내와 글로벌이 같은 화면을 씁니다.
>
> | 단계 | 국내 주소 | 글로벌 주소 |
> |---|---|---|
> | 결제 수단 입력 | `/web/funding/payment` | `/funding/payment` |
> | 승인 대기 | `/web/funding/payment/pending` | `/funding/payment/pending` |
> | 완료 | **아직 `/web/wpurchase/reward/result10/{id}`**(JSP) | `/funding/payment/completed/{id}` |
>
> **완료 화면만 국내가 아직 JSP 입니다.** 그래서 `result10.jsp` 하나가 `wpurchase/reward/` 에 남아 있습니다.
> 리액트 쪽에도 `completed` 화면이 이미 있는데 국내 리다이렉트는 아직 JSP 를 가리킵니다 — **확인 필요**입니다.

## 기록 범위
- **읽은 파일** (2026-10-06 재확인):
  - `wadiz-frontend/packages/api/src/web/funding/orders.service.ts:58,111,178,260,264` — 세션·주문서·금액계산 호출
  - `wadiz-frontend/apps/global/src/app/korea-routes/funding.tsx:54-92` — 새 결제 화면 라우트 3단
  - `com.wadiz.web/web/WEB-INF/web.xml:196-204` — `/web/apip/*` 프록시 servlet
  - `com.wadiz.web/web/WEB-INF/web.xml:121-130` — 일부 `/web/apip/*` 경로에 붙는 토큰 인증 필터
  - `com.wadiz.web/src/main/java/com/wadiz/api/httpproxy/ApiProxyServletDispatcher.java:1-52`
  - `com.wadiz.web/src/main/java/com/wadiz/web/wpurchase/controller/WWEBPurchaseRewardController.java:40-213` — 지금은 **되돌려 보내기 2개 + 완료 페이지 1개**뿐
  - `com.wadiz.web/src/main/java/com/wadiz/web/fw/config/GlobalUrlMappingConfig.java:205-222` — 국내↔글로벌 결제 주소 짝
  - `com.wadiz.api.funding/adapter/application/.../orderpayment/OrderPaymentController.java` (v1) · `OrderPaymentV2Controller.java` (v2)
  - `com.wadiz.api.funding/adapter/application/.../order/OrderController.java` (v1) · `OrderV2Controller.java` (v2)
  - `com.wadiz.api.funding/adapter/infrastructure/.../support/url/ServicePath.java`
  - `docs/com.wadiz.api.funding/api-details/order.md` (기 분석)
  - `docs/com.wadiz.api.funding/api-details/payment-flow.md` (기 분석)
  - 종전에 들었던 ~~`RewardPaymentCTA.tsx`~~ 는 `FE1-2005` 로 삭제됐습니다(599줄).
- **외부 경계**: Nicepay/Stripe/Alipay PG 내부, `com.wadiz.funding.core:funding-core` jar 내 UseCase 구현, ApiProxyServlet 실체(external jar `com.wadiz.core.httpproxy.ApiProxyServlet`).

---

## 🔑 두 개의 경로가 공존

본격 분석 전 이 플로우만의 핵심 관찰:

| 경로 | 핸들러 | 용도 |
|---|---|---|
| **`/web/apip/funding/*`** | `com.wadiz.core.httpproxy.ApiProxyServlet` (`web.xml:196-204`) 역프록시 → `com.wadiz.api.funding` | **REST API** — 주문 세션·주문서·결제 리소스 |
| **`/web/funding/payment*`** | `GlobalKoreaUIController` → `global-korea/index` **리액트 셸** | **결제 화면** (2026-09-28 이관) |
| **`/web/wpurchase/reward/*`** | com.wadiz.web 자체 `@Controller` | 되돌려 보내기 2개 + **완료 페이지 JSP 1개** |

**⚠️ 종전 서술 정정.** 이 자리에 "`/web/apip/funding/supporters/my/fundings` 같은 특정 URL만 다른 servlet 이 선점한다"고 적혀 있었습니다. **그렇지 않습니다.**

`web.xml:121-130` 은 **servlet 이 아니라 필터 매핑**입니다. `bearerTokenAuthenticationFilter` 가 아래 네 경로에만 추가로 붙습니다. 선점이 아니라 **인증을 덧붙이는 것**입니다.

```
/web/apip/funding/supporters/my/fundings
/web/apip/funding/supporters/my/fundings/*
/web/apip/funding/maker-home/dashboard/*
/web/apip/store/orders/*
```

`ApiProxyServletDispatcher` 도 "제한 경로"가 아닙니다. **주소 모양을 맞춰 주는 다리**입니다.
`/funding/*` · `/store/*` · `/order/*` 로 들어온 요청 앞에 `/web/apip` 를 붙여 프록시 servlet 으로 넘깁니다 (`ApiProxyServletDispatcher.java:12,50`). 글로벌 주소에는 `/web` 접두가 없기 때문입니다.

---

## 1. Client Trigger (FE/App)

### 1.1 wadiz-frontend
- **호출부**: `packages/api/src/web/funding/orders.service.ts` (2026-10-06 확인)

  | 줄 | 호출 | 용도 |
  |---|---|---|
  | `:58` | `POST /web/apip/funding/orders/session` | 주문 세션 생성 |
  | `:111` | `GET /web/apip/funding/orders/session/{token}` | 세션 조회 |
  | `:178` | `POST /web/apip/funding/orders/sheet/{token}/billing-previews` | 쿠폰·포인트 바꿀 때 금액 다시 계산 |
  | `:260` | **`POST /web/apip/funding/v2/orders/sheet/{token}`** | 주문서 생성. **`v2` 로 옮겨졌습니다** |
  | `:264` | `DELETE /web/apip/funding/orders/sheet/{token}` | 주문서 삭제 (뒤로가기 등) |

- **결제 화면**: `apps/global/src/pages/funding/payment/` 아래 리액트 페이지입니다.
  라우트는 `apps/global/src/app/korea-routes/funding.tsx:54-92` 에 세 단으로 등록돼 있습니다.
- **종전 간편결제 진입점** ~~`RewardPaymentCTA.tsx`~~ 는 `FE1-2005` 로 삭제됐습니다.
- **fetch 래퍼**: `packages/api/src/fetch.ts` + 펀딩 전용 `fetchFundingApi` (내부에서 `/web/apip/funding/` prefix 부착)
- **Host**: **`https://api.wadiz.io`** (`VITE_SERVICE_API_URL`, clive 기준)

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

### 2.2 레거시 경로 (`/web/wpurchase/reward/*`) — **거의 비었습니다**

`WWEBPurchaseRewardController` 는 **213줄**로 줄었습니다 (종전 443줄 이상).
남은 매핑은 셋뿐이고, 그중 둘은 **되돌려 보내기만** 합니다.

```java
// WWEBPurchaseRewardController.java:40
@RequestMapping(value="/web/wpurchase/reward/*")
public class WWEBPurchaseRewardController {

    @RequestMapping(value = "/step10/{campaignId}")        // :95 — 펀딩 상세로 되돌려 보냄
    public ModelAndView step10(...) {
        // redirect:/web/campaign/detail/{campaignId} (쿼리스트링 유지)
    }

    @RequestMapping(value = "/step20")                     // :112 — 메인으로 되돌려 보냄
    public ModelAndView step20() {
        return new ModelAndView("redirect:/web/main");
    }

    @RequestMapping(value = "/result10/{backingPaymentId}") // :125 — 결제 완료 페이지 (JSP 유지)
    public ModelAndView result10(...) { ... }
}
```

| 종전에 있던 것 | 지금 |
|---|---|
| `step20` 결제 수단 입력 JSP (1,401줄) | **없음.** 메인으로 되돌려 보냄 |
| `ajaxRequestNiceCreditPurchaseReservation` NICE 예약 AJAX | **없음** |
| `/payment/fail` | **없음** |
| `WRewardReservationService` (598줄) | **없음** |
| `result10` 결제 완료 페이지 | **그대로.** `wpurchase/reward/` 에 남은 유일한 JSP |

`result10` 은 본인 확인을 먼저 합니다. 내역이 없거나 **로그인한 사람이 결제자가 아니면** 홈으로 보냅니다 (`:130-139`).

---

## 3. Backend Service API (`com.wadiz.api.funding`)

`ApiProxyServlet` 을 통해 도달하는 엔드포인트들. 상세 분석은 [`docs/com.wadiz.api.funding/api-details/`](../com.wadiz.api.funding/api-details/).

### 3.1 Order — 주문 세션·시트
[`docs/.../order.md`](../com.wadiz.api.funding/api-details/order.md)

**2026-10-06 전수 확인 — 7개입니다.** 종전에는 4개만 적혀 있었습니다.

`OrderController.java` (`/api/orders`):

| Method | Path | 설명 |
|---|---|---|
| POST | `/session` (`:50`) | 주문 세션 생성 (Redis 임시 저장) |
| GET | `/session/{token}` (`:63`) | 세션 조회 |
| GET | `/closed-session/{token}` (`:69`) | **문서에 없던 것.** 닫힌 세션 조회 |
| POST | `/sheet/{token}` (`:84`) | 주문서 생성 (v1) |
| POST | `/sheet/{token}/billing-previews` (`:105`) | **문서에 없던 것.** 쿠폰·포인트를 바꿀 때 금액 미리보기 |
| DELETE | `/sheet/{token}` (`:148`) | 주문서 삭제 (뒤로가기 등) |

`OrderV2Controller.java` (`/api/v2/orders`):

| Method | Path | 설명 |
|---|---|---|
| POST | `/sheet/{token}` (`:39`) | 주문서 생성 (v2). **새 결제 화면이 쓰는 쪽입니다** |

### 3.2 Payment — PG 인증·승인
[`docs/.../payment-flow.md`](../com.wadiz.api.funding/api-details/payment-flow.md)

**컨트롤러가 둘입니다.** 둘 다 살아 있고 되돌려 보내는 주소가 **다릅니다.**

| 컨트롤러 | 기본 경로 | 결제 수단 |
|---|---|---|
| `OrderPaymentController` (v1) | `/api/order-payment` | NICE 인증, Stripe, Alipay, 0원 결제 |
| `OrderPaymentV2Controller` (v2) | `/api/v2/order-payment` | 위 전부 + **빌키**, **간편결제**, **직접결제** |

**되돌려 보내는 주소** (국내는 `Locale.KOREA` 로 가립니다):

| 상황 | v1 국내 | v2 국내 | 글로벌 (공통) |
|---|---|---|---|
| 성공 | `/web/wpurchase/reward/result10/{id}` | 같음 | `/funding/payment/completed/{id}` |
| 취소 | **`/web/wpurchase/reward/step20?token=`** | `/web/funding/payment?token=` | `/funding/payment?token=` |
| 실패 | `/web/campaign/detail/{campaignId}` | `/web/funding/payment?token=&failureType=` | `/funding/payment?token=&failureType=` |

> ⚠️ **확인 필요 — v1 의 국내 취소 경로가 죽은 주소를 가리킵니다.**
> `OrderPaymentController.java:117` 이 `/web/wpurchase/reward/step20?token=` 으로 보냅니다.
> 그런데 `step20` 은 이제 **메인으로 되돌려 보내기만** 합니다(`WWEBPurchaseRewardController.java:112-115`).
> 국내 사용자가 v1 경로로 결제를 취소하면 **토큰이 버려지고 메인으로 떨어집니다.**
> v2 는 `/web/funding/payment?token=` 으로 제대로 돌아갑니다.
> v1 이 아직 국내 요청을 받는지는 코드만으로 판단할 수 없어 **확인 필요**로 남깁니다.
>
> **같은 내용이 설정 상수에도 남아 있습니다.**
> `ServicePath.java:16` 의 `PAYMENT_CANCELED` 가 국내 값으로 `/web/wpurchase/reward/step20` 을 갖고 있습니다.
> 다만 이 상수는 **아무 데서도 쓰이지 않습니다**(2026-10-06 전수 확인). 실제 주소는 컨트롤러에 직접 박혀 있습니다.
> 그 열거형에서 실제로 쓰이는 것은 `MY_PAYMENT_DETAIL` 과 `FUNDING_SATISFACTION` 둘뿐입니다.

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
[FE: apps/global/src/pages/funding/payment/]
   │ 1) POST /web/apip/funding/orders/session             (시작)
   │ 2) POST /web/apip/funding/v2/orders/sheet/{token}    (리워드·쿠폰·포인트 확정, v2)
   ▼
[www.wadiz.io — ApiProxyServlet (web.xml:196-204)]
   │  투명 프록시. com.wadiz.web 의 자바 코드는 통과만 합니다
   ▼
[com.wadiz.api.funding — OrderController / OrderV2Controller]
   │  Redis 에 세션을 TTL 로 저장
   │  DB 에서 Campaign·Reward 를 읽어 유효성 확인
   └─ 응답: token, 결제 준비 데이터

[FE 이동]  /web/funding/payment?token=...        ← 국내
           /funding/payment?token=...            ← 글로벌

[www.wadiz.io — GlobalKoreaUIController]
   │  리액트 셸(global-korea/index)을 내려 줍니다. JSP 렌더링이 아닙니다
   │  국내↔글로벌 주소 짝은 GlobalUrlMappingConfig.java:205-222
   │
   │  결제 수단을 고르고 PG SDK 로 인증 창을 띄웁니다
   ▼
[PG (외부) — Nicepay / Stripe / Alipay+]
   │  사용자 인증 완료 → form-urlencoded POST 콜백
   ▼
[com.wadiz.api.funding — OrderPaymentV2Controller]
   │  POST /api/v2/order-payment/{payType}/{campaignId}/{token}
   │  AuthResultCode 확인
   │  OrderPayProxy.pay(...) → funding-core OrderPaymentUsecase.pay (외부 jar)
   │     ├─ Redis: SET processing:{tid} NX EX 300
   │     ├─ MySQL: INSERT BackingPayment
   │     ├─ MySQL: savePaymentResult (auth·cardResult 머지)
   │     ├─ MySQL: UPDATE BackingPayment (PayStatus·ResultCode)
   │     └─ Redis: DEL processing:{tid}
   │
   │  성공 → HTTP 302
   ▼
[완료 화면]
   국내   www.wadiz.io — WWEBPurchaseRewardController#result10 (:125)
          JSP: wpurchase/reward/result10.jsp  ← 아직 JSP 입니다
   글로벌 /funding/payment/completed/{backingPaymentId}  ← 리액트
```

---

## 경계·미탐색

1. **funding-core jar** — `OrderPaymentUsecase.pay`, `CancelPaymentUsecase`, `ImmediatePaymentUseCase` 등 UseCase 구현체는 외부 jar. 호출 순서/분기 확인 불가.
2. **ApiProxyServlet 내부 구현** — `com.wadiz.core.httpproxy.ApiProxyServlet` 은 외부 jar. 실제 타깃 호스트 해석(`application-*.yml` 또는 ENV) 은 별도 추적.
3. **간편결제(Simple Pay) 경로** — `static/packages/reward-simple-pay-app` 은 `FE1-2005` 로 **크게 줄었습니다**(24파일 정리). 지금 그 패키지가 내보내는 것은 `RewardPaymentInfo` 와 공통 컴포넌트 2개, 상수 3개뿐입니다. 간편결제 자체는 `/api/v2/order-payment/{token}/pay-simple` 로 옮겨졌습니다. 새 결제 화면에서의 세부 이벤트 흐름은 추가 분석이 필요합니다.
4. **쿠폰·포인트 차감 원자성** — funding 측에서 reward-api 쿠폰 차감을 어떻게 처리(사전 홀드 vs 승인 직후)하는지 확인 필요.
5. **해외 결제 분기** (`locale != KOREA`) — Stripe/Alipay 경로의 redirect URL 이 다르다 (`/funding/payment/completed/{id}`). 다국어 페이지 라우팅 별도 검증.
6. **이탈 경로의 세션·주문서 정리** — 뒤로가기나 새로고침으로 빠져나갈 때 `DELETE /orders/sheet/{token}` 이 언제 불리는지는 별도 추적이 필요합니다. 종전의 "JSP + AJAX + 프록시 하이브리드" 서술은 **step20 이 없어져 해당 없음**이 됐습니다.
7. **v1 결제 컨트롤러의 생존 여부** — `/api/order-payment` 가 국내 요청을 아직 받는지 확인이 필요합니다. 받는다면 취소 경로가 메인으로 떨어집니다(3.2 절의 경고 참조).
8. **국내 완료 화면의 이관 시점** — 리액트 쪽 `completed` 화면이 이미 있는데 국내 리다이렉트는 아직 `result10.jsp` 를 가리킵니다. 의도적으로 남긴 것인지 확인이 필요합니다.
