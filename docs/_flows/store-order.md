# Flow: 스토어 주문 (Store Order)

> 스토어 상품 주문·결제 체인. 펀딩과 다른 "즉시 결제" 특성. `/web/apip/store/orders/*` 는 `bearerTokenAuthenticationFilter` 특수 적용 경로.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/store/orders.service.ts:78` (`GET /web/apip/store/orders/my`)
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
[www.wadiz.kr]
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
[www.wadiz.kr — ApiProxy → Store API]
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

## 경계·미탐색
1. **Store API 서비스 실체** — 별도 repo. 본 repos 에 없음.
2. **Payment 연계** — 주문 결제 시 `nicepay-api` 호출 순서, 실패 시 롤백.
3. **배송 API 연계** — 택배사 API (CJ/한진 등) 연동은 Store API 내부.
4. **선물하기 결제** — StoreGiftUiController 와 연결된 결제 flow 는 별도.
5. **정산** — com.wadiz.adm 의 `SettlementSubMall` 과 Store 주문 행 매핑 시점.
