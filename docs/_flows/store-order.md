# Flow: 스토어 주문 (Store Order)

> 스토어 상품 주문·결제 체인. 펀딩과 다른 "즉시 결제" 특성. `/web/apip/store/orders/*` 는 `bearerTokenAuthenticationFilter` 특수 적용 경로.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/store/orders.service.ts:78` (`GET /web/apip/store/orders/my`)
  - `wadiz-frontend/packages/api/src/web/store/orders.service.ts:115-140` (주문 세션·주문서·간편결제 경로)
  - `wadiz-frontend/packages/features/src/store/payment/ui/containers/PaymentFormControlContainer.tsx` (주문서 생성·결제수단별 승인 호출)
  - `wadiz-frontend/packages/features/src/store/payment/lib/utils/payment.js` (결제창 호출 래퍼·폼 생성)
  - `wadiz-frontend/packages/features/src/store/payment/ui/containers/PaymentWadizSimplePaymentModalContainer.tsx` (간편결제 비밀번호 모달)
  - `wadiz-frontend/packages/features/src/store/payment/ui/layout/PaymentLayout.tsx` (결제수단·현금영수증 노출 조건)
  - `wadiz-frontend/packages/features/src/store/payment/lib/utils/index.ts:77` (`createOrderSheet` — 주문서 요청 본문 조립)
  - `wadiz-frontend/packages/features/src/store/shared/lib/services/orders.js` (주문 세션·주문서 서비스 함수)
  - `wadiz-frontend/static/services/admin/pages/store-admin-app/api/index.js:371-471` (admin 경로)
  - `wadiz-frontend/studio/store/src/pages/sales/services/order.ts` (메이커 스튜디오 경로)
  - `com.wadiz.web/web/WEB-INF/web.xml:128` (`/web/apip/store/orders/*` — bearerToken 필터)
  - `com.wadiz.web/src/main/java/.../store/order/controller/StoreGiftUiController.java`
- **외부 경계**: Store API 서비스 (주문·결제·배송 실제 로직). 본 레포에서는 FE 호출 패턴과 com.wadiz.web 의 JSP 엔트리만 관측.

---

## 1. Client Trigger (FE)

### 1.1 서포터(구매자) 경로
```ts
// packages/api/src/web/store/orders.service.ts:78
GET /web/apip/store/orders/my?page=&size=&status=...           // 내 주문 목록
```

### 1.2 메이커 스튜디오 (판매자)
```ts
// studio/store/src/pages/sales/services/order.ts
GET /web/apip/store/studio/orders/for-shipping/excel?...       // 배송용 엑셀 다운로드
GET /web/apip/store/studio/orders/aggregation?projectNo=...     // 집계
GET /orders/{orderNo}/refund-estimated-bill                     // 환불 예상 금액
```

### 1.3 어드민 (운영자)
```js
// static/services/admin/pages/store-admin-app/api/index.js
GET /web/apip/store/admin/orders/qty?projectNo=...&orderStatusFilter=...
GET /orders/{orderNo}                                           // 상세
PUT /orders/{orderNo}/cancel-shipping                           // 배송 취소
GET /web/apip/store/admin/orders/excel?...                      // 관리자 엑셀
GET /web/apip/store/admin/orders/for-shipping/excel?...         // 배송용
GET /orders/{orderNo}/status-history                            // 상태 이력
PUT /settlement/sale/orders/{orderNo}/excludedSettlement        // 정산 제외
POST /orders/shippings/prepare                                  // 배송 준비
POST /orders/{orderNo}/shipping                                 // 배송 처리
```

### 1.4 서포터(구매자) — 결제 화면

주문·결제 화면은 `packages/features/src/store/payment/` 에 있고 폼 상태를 `react-hook-form` 으로 관리합니다. 결제하기를 누르면 **주문서를 먼저 만들고**, 주문번호가 나오면 그때 결제수단에 맞는 승인 경로를 탑니다.

```
[결제하기 버튼]
   │
   ├─ 1) 주문서 생성
   │     POST /web/apip/store/order-sessions/{token}/sheet
   │       (PaymentFormControlContainer.tsx:287 → createOrderSheet)
   │       본문: recipient(배송지) · requestMessage · bill(상품금액·배송비·추가배송비·
   │             쿠폰할인·결제금액·배송지원금) · giftCard · orderType · isAuthPayment
   │       응답: { orderNo, serviceType, ... }
   │
   └─ 2) orderNo 가 생기면 결제수단별 분기 (PaymentFormControlContainer.tsx:369~431)
         │
         ├─ 결제금액 0원 → 폼을 만들어 submit
         │     POST /web/apip/store/order-sessions/{token}/pay-zero
         │
         ├─ 와디즈 간편결제 → 비밀번호 6자리 모달 → 검증 후 폼 submit
         │     POST /web/apip/store/order-sessions/{token}/pay-via-wadiz
         │       (PaymentWadizSimplePaymentModalContainer.tsx:38,48)
         │
         └─ 나이스페이 · 카카오페이 · 애플페이 · 네이버페이 → 나이스페이 결제창
               nicepayService.authInit → submitNicepayForm  (@wadiz/api/platform, 펀딩과 공용)
               돌아올 주소(returnUrl)는 **화면이 직접 조립**합니다 —
               `{origin}/web/apip/store/order-sessions/{token}/pay-via-nice[/{payType}]`
               payType 은 kakaopay · applepay · naverpay (신용/체크카드는 뒤에 붙이지 않음)
```

- 주문서 삭제 `DELETE /web/apip/store/order-sessions/{token}/sheet` 는 **화면에 들어올 때**와 **PC 에서 결제창을 닫았을 때** 호출합니다.
- 현금영수증은 **네이버페이 포인트 결제**를 골랐을 때만 입력받아 결제창 요청에 실어 보냅니다(`rcptType` · `rcptNo` · `rcptNoType`). 번호가 10자리 이상일 때만 실리고, 그 밖에는 미발행(`rcptType: 0`)으로 넘어갑니다.
- 서버 쪽 엔드포인트 정의는 [`com.wadiz.store/api-endpoints.md`](../com.wadiz.store/api-endpoints.md) 의 `OrderSessionController` · `OrderSessionPaymentController` 를 봅니다.

---

## 2. Hub — `com.wadiz.web`

### 2.1 특수 인증 필터 (web.xml:119-130)
```xml
<filter-mapping>
    <filter-name>bearerTokenAuthenticationFilter</filter-name>
    ...
    <url-pattern>/web/apip/store/orders/*</url-pattern>            <!-- ★ 스토어 주문 -->
</filter-mapping>
```
마이펀딩과 동일하게 **Bearer 토큰도 허용** — 웹(쿠키)과 앱(토큰) 공유 URL.

### 2.2 ApiProxyServlet 투명 프록시
web.xml `/web/apip/*` 매핑 → Store API 서비스(외부) 로 직행.

### 2.3 선물하기 JSP 경로
```java
// com.wadiz.web/.../store/order/controller/StoreGiftUiController.java
// "선물하기" 페이지 렌더링 (JSP)
```
스토어 상품을 다른 사람에게 선물하는 UX 는 별도 JSP 기반 플로우.

## 3. Backend — Store API (외부)
`/web/apip/store/orders/*` → 외부 Store 주문 서비스.
- 주문 생성·조회
- 배송 상태 관리 (준비/출고/배송중/배송완료)
- 환불·취소
- 정산 (`com.wadiz.adm` 의 SettlementSubMall 과 연동)

**공통 의존**:
- 결제: `nicepay-api` (Billing/Auth)
- 쿠폰: `com.wadiz.api.reward` (USE/REFUND 동일 규약)
- 포인트: 포인트 도메인

## 4. DB
외부. 추정 테이블 `StoreOrder`, `StoreOrderItem`, `StoreShipping`, `StoreOrderStatusHistory` 등. com.wadiz.adm 의 Store 관련 컨트롤러([misc-ops.md](../com.wadiz.adm/api-details/misc-ops.md)) 에서 일부 관측.

## 엔드투엔드 시퀀스

### 구매자 — 내 주문 목록
```
[FE: 마이페이지 → 주문 탭]
   │ GET /web/apip/store/orders/my?page=0&size=20
   │   (쿠키 세션 or Bearer 토큰)
   ▼
[www.wadiz.io]
   ├─ bearerTokenAuthenticationFilter           (web.xml:128 특수)
   └─ ApiProxyServlet → 외부 Store API
        ▼
[Store API]
   └─ SELECT ... FROM StoreOrder WHERE UserId=?
```

### 메이커 — 주문 배송 처리
```
[메이커 스튜디오]
   │ POST /orders/{orderNo}/shipping  body: { trackingNo, carrier }
   ▼
[www.wadiz.io — ApiProxy → Store API]
   │
   └─ Store API: UPDATE StoreShipping SET TrackingNo=?, Status='SHIPPED'
         → 알림 발송 (구매자에게 배송 시작)
```

### 어드민 — 배송 취소
```
[adm SPA]
   │ PUT /orders/{orderNo}/cancel-shipping
   ▼
[Store API]
   └─ 취소 절차 + PG 환불 요청 (nicepay-api 연동)
```

## 펀딩 결제와 다른 점

같은 회사의 결제 화면이지만 **코드를 거의 공유하지 않습니다.** 두 화면을 오가며 작업할 때 틀리기 쉬운 지점을 모았습니다. 펀딩 쪽은 [`funding-payment.md`](./funding-payment.md).

| 항목 | 펀딩 결제 | 스토어 결제 |
|---|---|---|
| 코드 위치 | `apps/global/src/pages/funding/payment/` | `packages/features/src/store/payment/` |
| 폼·상태 관리 | 자체 컨텍스트 `_model/useFundingCheckout.tsx` | `react-hook-form` (`PaymentFormControlContainer.tsx`) |
| 결제수단 폼 값 | `payType` — 국내 `sbcredit`(간편결제)·`dbcredit`(카드 직접입력)·`nicepay`·`kakaopay`·`naverpay`·`applepay`·`tosspay`, 0원 `none`, 글로벌 `stripe`·`alipay` (`packages/api/src/web/funding/orders.service.ts:121`) | `paymentMode` — `simplePay`·`nicePay`·`kakaoPay`·`naverPay`(서브옵션 `subPaymentType` = `card`·`point`)·`applePay` |
| 주문서 생성 | `POST /web/apip/funding/v2/orders/sheet/{token}` | `POST /web/apip/store/order-sessions/{token}/sheet` |
| 주문서 응답 | `{ data: ... }` 봉투 안에 들어 있음 | 봉투 없이 본문이 곧 데이터 |
| 결제창 호출 | 공용 `nicepayService.authInit` → `submitNicepayForm` | **같은 공용 함수를 씀** |
| 돌아올 주소(returnUrl) | **서버가 주문서 응답으로 내려준 값**을 그대로 씀 | **화면이 직접 조립**(`{origin}/web/apip/store/order-sessions/{token}/pay-via-nice[/{payType}]`) |
| 0원 결제 | 결제창 없이 `checkoutFormSubmit` | 폼 submit → `pay-zero` |
| 현금영수증 용도 값 | `cashReceiptType` — `'0'` 소득공제 · `'1'` 지출증빙 | `rcptType` — **`'1'` 소득공제 · `'2'` 지출증빙** |
| 현금영수증 노출 조건 | 네이버페이 포인트 결제 | 네이버페이 포인트 결제 (같음) |

> ⚠️ **현금영수증 용도 값이 한 칸씩 어긋나 있습니다.** 스토어의 `'1'` 은 소득공제인데 펀딩의 `'1'` 은 지출증빙입니다. 한쪽 코드를 다른 쪽으로 옮길 때 그대로 쓰면 용도가 바뀝니다.

## 경계·미탐색
1. **Store API 서비스 실체** — 별도 repo. 본 repos 에 없음.
2. **Payment 연계(서버 구간)** — 화면에서 승인 경로를 부르는 데까지는 1.4 에 적었습니다. 그 뒤 Store API 가 `nicepay-api` 를 부르는 순서와 실패 시 롤백은 미탐색.
3. **배송 API 연계** — 택배사 API (CJ/한진 등) 연동은 Store API 내부.
4. **선물하기 결제** — StoreGiftUiController 와 연결된 결제 flow 는 별도.
5. **정산** — com.wadiz.adm 의 `SettlementSubMall` 과 Store 주문 행 매핑 시점.
