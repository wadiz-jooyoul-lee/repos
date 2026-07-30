# com.wadiz.store — API 엔드포인트 전수 목록

> 소스 기준: `store-api` 모듈 **73개 `*Controller.java` × 252 엔드포인트**(관측 기준).
> 도메인별 상세(입력 DTO / Service / SQL)는 향후 `api-details/*.md`로 확장 예정입니다.

## 작성 원칙·관측 규약

- 관측 가능한 사실만 기록했습니다. 추정은 "추정"으로 표기합니다.
- 경로는 클래스 레벨 `@RequestMapping`(base) + 메서드 매핑을 결합한 전체 경로입니다.
- **인증 표현식**(`isAdmin()`, `isMakerByProjectNo(#projectNo)`, `hasBeenOpenedByProjectNo(#projectNo)`, `isSupporterByOrderNo(#orderNo)` 등)은 커스텀 Spring Security SpEL 메서드로 관측됩니다(정의 파일은 별도).
- "없음(currentUserId)"은 `@PreAuthorize`가 없으나 본문에서 `SecurityUtils.currentUserId()`로 로그인 사용자를 요구하는 경우입니다. 전역 시큐리티 설정에 의한 URL 기반 보호 여부는 컨트롤러 코드 범위 밖입니다.
- `@ForceMasterDataSource`: 조회도 마스터 DB로 강제(스튜디오 계열 다수). `@Impersonatable`: 대리 접근 허용 커스텀 애노테이션(추정).

---

## 1. 주문/결제 (9 컨트롤러, 49 endpoints)

### `MyOrderController` — 본인 주문 조회·수령·분쟁·선물 SMS
base: `/api/orders` (`store-api/.../rest/order/MyOrderController.java:45`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/orders/my` | getAllMyOrder | 나의 구매 목록 | 없음(currentUserId) |
| GET | `/api/orders/{orderNo}` | getMyOrder | 나의 구매 상세 | isSupporterByOrderNo |
| GET | `/api/orders/my/qty` | getMyOrderQty | 나의 구매 건수 | 없음(currentUserId) |
| PUT | `/api/orders/{orderNo}/receive` | receive | 수령 완료 처리 | isSupporterByOrderNo |
| GET | `/api/orders/{orderNo}/refund-estimated-bill` | estimateRefundBill | 환불 예상 금액 | 없음(관측) |
| POST | `/api/orders/{orderNo}/dispute` | dispute | 분쟁 신청 | isSupporterByOrderNo |
| DELETE | `/api/orders/{orderNo}/dispute` | dropDispute | 분쟁 취소 | isSupporterByOrderNo |
| POST | `/api/orders/{orderNo}/dispute/evidence/presign` | presignDisputeEvidence | 분쟁 증빙 Presign URL | isSupporterByOrderNo |
| POST | `/api/orders/{orderNo}/gift-sms` | sendGiftSms | 선물 SMS 발송 | isSupporterByOrderNo |

### `OrderController` — 프로젝트 단위 주문 집계·카운트
base: `/api/orders` (`store-api/.../rest/order/OrderController.java:16`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/orders/aggregation` | getAggregation | 프로젝트 주문 집계 | 없음 |
| GET | `/api/orders/qty` | getSearchQty | 검색 조건 카운트 | 없음 |

### `OrderGiftController` — 선물(cardToken 기반) 수령·변경·조회
base: `/api/order-gift` (`store-api/.../rest/order/OrderGiftController.java:24`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/order-gift/{cardToken}` | receiveGift | 선물 받기 | 없음(cardToken) |
| PUT | `/api/order-gift/{cardToken}/options` | changeOptions | 선물 옵션 변경 | 없음(cardToken) |
| PUT | `/api/order-gift/{cardToken}/shipping-address` | changeShippingAddress | 수령인 배송지 변경 | 없음(cardToken) |
| GET | `/api/order-gift/{cardToken}` | getGiftOrder | 선물 주문 기본 정보 | 없음(cardToken) |
| GET | `/api/order-gift/{cardToken}/detail` | getGiftOrderDetail | 선물 주문 상세 | 없음(cardToken) |
| GET | `/api/order-gift/card-themes` | getGiftCardThemes | 카드 테마 목록 | 없음 |
| GET | `/api/order-gift/card-themes/{themeCode}` | getGiftCardTheme | 카드 테마 단건 | 없음 |
| GET | `/api/order-gift/{cardToken}/promotion-code` | getGiftPromotionCode | 구매자 프로모션 코드 | 없음(cardToken) |

### `OrderSessionController` — 주문 세션·주문서 CRUD
base: `/api/order-sessions` (`store-api/.../rest/order/OrderSessionController.java:24`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/order-sessions` | create | 주문 세션 생성 | 없음(currentUserId) |
| GET | `/api/order-sessions/{token}` | getOrderSession | 주문 세션 조회 | 없음(currentUserId) |
| GET | `/api/order-sessions/closed/{token}` | getClosed | 종료 세션 조회 | 없음(currentUserId) |
| POST | `/api/order-sessions/{token}/sheet` | createSheet | 주문서 생성 | 없음(currentUserId) |
| PUT | `/api/order-sessions/{token}/reset` | reset | 세션 초기화(`@Deprecated`) | 없음(currentUserId) |
| DELETE | `/api/order-sessions/{token}/sheet` | deleteSheet | 주문서 삭제 | 없음(currentUserId) |

### `OrderSessionPaymentController` — 결제 승인(Nice/와디즈간편/0원)
base: `/api/order-sessions/{token}` (`store-api/.../rest/order/OrderSessionPaymentController.java:22`, **`@Controller`**: REST 아님, 리다이렉트 반환. 전 핸들러 `consumes=x-www-form-urlencoded`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/order-sessions/{token}/pay-via-nice[/{simplePayMethod}]` | payViaNice | Nice 결제 승인→리다이렉트 | 없음(currentUserId) |
| POST | `/api/order-sessions/{token}/pay-via-wadiz` | payViaWadiz | 와디즈 간편결제 승인→리다이렉트 | 없음(currentUserId) |
| POST | `/api/order-sessions/{token}/pay-zero` | payZero | 0원 결제 승인→리다이렉트 | 없음(currentUserId) |

### `InternalOrderController` — 내부(서비스 간) 주문 집계
base: `/api/internal/orders` (`store-api/.../rest/order/internal/InternalOrderController.java:19`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/internal/orders/qtys/by-user` | getAllQtyByUser | 사용자별 주문 건수 | 없음(내부용 추정) |
| GET | `/api/internal/orders/ordered-projects` | getOrderedProjects | 구매 프로젝트 목록 | 없음(내부용 추정) |
| GET | `/api/internal/orders/aggregation` | getAggregation | 사용자 구매 건수 집계 | 없음(내부용 추정) |

### `StudioOrderController` — 메이커 주문/분쟁/결제 관리
base: `/api/studio` (`store-api/.../rest/order/studio/StudioOrderController.java:46`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/orders` | getAllOrder | 주문 목록 검색 | 메이커 or isAdmin |
| GET | `/api/studio/orders/aggregation` | aggregation | 주문 상태 요약 | 메이커 or isAdmin |
| GET | `/api/studio/disputes/{disputeNo}` | getDispute | 분쟁 상세 | 메이커 or isAdmin |
| PUT | `/api/studio/disputes/{disputeNo}/ack` | ackDispute | 분쟁 확인 | 메이커 or isAdmin |
| PUT | `/api/studio/disputes/{disputeNo}/approve/exchange` | approveDisputeExchange | 분쟁 승인(교환) | 메이커 or isAdmin |
| PUT | `/api/studio/disputes/{disputeNo}/approve/refund` | approveDisputeRefund | 분쟁 승인(환불) | 메이커 or isAdmin |
| PUT | `/api/studio/disputes/{disputeNo}/reject` | rejectDispute | 분쟁 반려 | 메이커 or isAdmin |
| PUT | `/api/studio/disputes/{disputeNo}/postpone` | postponeDispute | 자동 환불 연기 | 메이커 or isAdmin |
| GET | `/api/studio/orders/{orderNo}/refund-estimated-bill` | estimateRefundBill | 환불 예상 금액 | 메이커 or isAdmin |
| GET | `/api/studio/payments/order-no/{orderNo}` | getPayment | 결제 상세 | 메이커 or isAdmin |
| GET | `/api/studio/projects/for-order` | getAllProjectForOrder | 판매 관리 프로젝트 목록 | 메이커 or isAdmin |

### `AdminOrderController` — 관리자 주문 검색·상세·이력·엑셀
base: `/api/admin/orders` (`store-api/.../rest/order/admin/AdminOrderController.java:35`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/orders` | getAllOrder | 주문 목록 검색 | isAdmin |
| GET | `/api/admin/orders/{orderNo}` | getOrder | 주문 상세 | isAdmin |
| GET | `/api/admin/orders/{orderNo}/status-history` | getAllStatusHistory | 주문/환불 상태 이력 | isAdmin |
| GET | `/api/admin/orders/{orderNo}/dispute-history` | getAllDisputeHistory | 분쟁 상태 이력 | isAdmin |
| GET | `/api/admin/orders/excel` | getAllOrderExcel | 주문 목록 엑셀 다운로드 | isAdmin |
| GET | `/api/admin/orders/qty` | getOrderQty | 주문 카운트 | isAdmin |

### `AdminPaymentController` — 관리자 결제(정산관리) 엑셀
base: `/api/admin/payments` (`store-api/.../rest/payment/admin/AdminPaymentController.java:28`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/payments/excel` | excel | 결제 내역 엑셀 다운로드 | isAdmin |

> 외부 연동(관측): `OrderGiftController`→`UserApiClient.getInviteCodeUsing`(사용자 서비스). `MyOrderController`→`PublicStorage.presign`(S3 presign 추정)·`TrackerService`(택배 송장/운송사). `OrderSessionPaymentController`→`PayOrderService`(나이스페이 연동, `@see` 주석), 성공/실패 시 JSP `/web/store/payment/...` 리다이렉트.

---

## 2. 상품/재고/카테고리 (7 컨트롤러, 15 endpoints)

### `ProductController` — 프로젝트별 판매 상품 조회(공개)
base: `/api/projects/{projectNo}/products` (`store-api/.../rest/product/ProductController.java:22`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/projects/{projectNo}/products` | getAllProduct | 판매 중 상품 목록 | hasBeenOpenedByProjectNo |
| GET | `/api/projects/{projectNo}/products/aggregation` | getAggregation | 상품 집계 | hasBeenOpenedByProjectNo or isMakerByProjectNo or isAdmin |

### `ProductRestockSubscriptionController` — 상품 재입고 구독
base: `/api/products/restock-subscriptions` (`store-api/.../rest/product/ProductRestockSubscriptionController.java:19`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/products/restock-subscriptions` | save | 재입고 구독 신청 | 없음(currentUserId) |
| GET | `/api/products/restock-subscriptions/my` | getRestockSubscriptions | 내 구독 목록 | 없음(currentUserId) |
| DELETE | `/api/products/restock-subscriptions/{restockSubscriptionNo}` | deleteRestockSubscription | 구독 삭제 | isSupporterByRestockSubscriptionNo |

### `StudioProductController` — 스튜디오 상품 목록
base: `/api/studio/projects/{projectNo}/products` (`store-api/.../rest/product/studio/StudioProductController.java:18`, `@RestController`, 클래스 `isMakerByProjectNo or isAdmin` + `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/projects/{projectNo}/products` | getAllProduct | 프로모션 포함 상품 목록 | isMakerByProjectNo or isAdmin |

### `StudioSalesUnitProductController` — 스튜디오 판매 단위 상품
base: `/api/studio/projects/{projectNo}/sales-unit-products` (`store-api/.../rest/product/studio/StudioSalesUnitProductController.java:26`, `@RestController`, 클래스 `isMakerByProjectNo or isAdmin` + `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/projects/{projectNo}/sales-unit-products` | search | 판매 단위 상품 검색 | isMakerByProjectNo or isAdmin |
| POST | `/api/studio/projects/{projectNo}/sales-unit-products` | save | 판매 단위 상품 저장 | isMakerByProjectNo or isAdmin |

### `AdminProductController` — 관리자 상품/가격/가격이력
base: `/api/admin` (`store-api/.../rest/product/admin/AdminProductController.java:29`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/products` | search | 상품 목록 검색 | isAdmin |
| PUT | `/api/admin/products` | save | 상품 가격 저장 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/products/price-histories` | getAllPriceHistory | 프로젝트별 가격 이력 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/products/{productNo}/price-histories` | getAllPriceHistoryByProductNo | 상품별 가격 이력 | isAdmin |

### `AdminSellableStockSyncController` — 와배송 판매가능수량 동기화(관리자)
base: `/api/admin/products/sellable-stock-syncs` (`store-api/.../rest/product/admin/AdminSellableStockSyncController.java:21`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/admin/products/sellable-stock-syncs` | synchronize | FMS→store 판매가능수량 동기화 | isAdmin |
| GET | `/api/admin/products/sellable-stock-syncs/histories` | getAllSyncHistory | 동기화 히스토리 조회 | isAdmin |

### `StoreCategoryController` — 스토어 카테고리 목록 (`@Deprecated`)
base: `/api/categories` (`store-api/.../rest/category/StoreCategoryController.java:15`, `@RestController`, 클래스 `@Deprecated`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/categories` | getCategories | 스토어 카테고리 목록 | 없음 |

---

## 3. 프로젝트 (12 컨트롤러, 54 endpoints)

### `ProjectController` — 공개(오픈된) 스토어 프로젝트 상세
base: `/api/projects` (`store-api/.../rest/project/ProjectController.java:19`, `@RestController`, 클래스 `hasBeenOpenedByProjectNo`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/projects/{projectNo}` | getProject | 프로젝트 조회 | hasBeenOpenedByProjectNo and isNotHiddenByProjectNo |
| GET | `/api/projects/{projectNo}/content` | getContent | 프로젝트 컨텐츠 | hasBeenOpenedByProjectNo and isNotHiddenByProjectNo |
| GET | `/api/projects/{projectNo}/shipping-info` | getShippingInfo | 배송 정보 | hasBeenOpenedByProjectNo |
| GET | `/api/projects/{projectNo}/setting` | getSetting | 셋팅 조회 | hasBeenOpenedByProjectNo |
| GET | `/api/projects/{projectNo}/claim-as-guide` | getClaimAsGuide | 교환/환불/AS 가이드 | hasBeenOpenedByProjectNo |
| GET | `/api/projects/{projectNo}/product-info-notice` | getProductInfoNotice | 상품 정보 제공 고시 | hasBeenOpenedByProjectNo |
| GET | `/api/projects/{projectNo}/base-funding` | getBaseFunding | 본펀딩 정보 | hasBeenOpenedByProjectNo |

### `ProjectByFundingController` — 펀딩 campaignId로 프로젝트 조회
base: `/api/projects` (`store-api/.../rest/project/ProjectByFundingController.java:14`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/projects/by-funding?campaignId=` | getProjectByFunding | 스토어 프로젝트 조회 By 펀딩(오픈된 것만) | 없음 |

### `ProjectLabelController` — 프로젝트 태그 목록
base: `/api/project-labels` (`store-api/.../rest/projectlabel/ProjectLabelController.java:14`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/project-labels` | getAllLabel | 프로젝트 태그 목록 | 없음 |

### `ProjectMakerController` — 오픈 프로젝트의 메이커 정보
base: `/api/projects` (`store-api/.../rest/project/ProjectMakerController.java:17`, `@RestController`, 클래스 `hasBeenOpenedByProjectNo`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/projects/{projectNo}/maker-contact` | getMakerContact | 메이커 연락 정보 | hasBeenOpenedByProjectNo |
| GET | `/api/projects/{projectNo}/maker-business-info` | getMakerBusinessInfo | 메이커 기업 정보 | hasBeenOpenedByProjectNo |

### `MyProjectController` — 로그인 메이커 본인 프로젝트 조회·요약
base: `/api` (`store-api/.../rest/project/MyProjectController.java:31`, `@RestController`, `@Impersonatable` 사용)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/projects/my` | getAllMyProject | 메이커 만든 프로젝트(`@Deprecated`) | 없음(currentUserId) |
| GET | `/api/makers/my/projects` | searchMyProject | 메이커 프로젝트 조회(페이징) | @Impersonatable + currentUserId |
| GET | `/api/makers/my/project-summary` | getMyProjectSummary | 메이커 프로젝트 요약 | @Impersonatable + currentUserId |
| GET | `/api/makers/my/project-status-counts` | getProjectStatusCounts | 상태별 건수 | @Impersonatable + currentUserId |

### `StudioProjectController` — 스튜디오 프로젝트 개설·조회·오픈
base: `/api/studio/projects` (`store-api/.../rest/project/studio/StudioProjectController.java:27`, `@RestController`, `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/studio/projects/set-up?campaignId=` | setUp | 프로젝트 시작하기 | isMakerByCampaignId or isAdmin |
| GET | `/api/studio/projects/set-up-condition?campaignId=` | checkSetUp | 개설 조건 확인 | isMakerByCampaignId or isAdmin |
| GET | `/api/studio/projects/exists?campaignId=` | exists | 개설 여부 | 없음 |
| GET | `/api/studio/projects/{projectNo}/profile` | getProjectProfile | 프로파일 정보 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/projects/{projectNo}` | getProject | 상세 정보 | isMakerByProjectNo or isAdmin |
| POST | `/api/studio/projects/{projectNo}/open` | open | 프로젝트 오픈 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/projects/{projectNo}/submit-condition` | checkSubmit | 제출 조건 확인 | isMakerByProjectNo or isAdmin |

### `StudioProjectByFundingController` — 스튜디오 펀딩 campaignId로 조회
base: `/api/studio/projects` (`store-api/.../rest/project/studio/StudioProjectByFundingController.java:16`, `@RestController`, `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/projects/by-funding?campaignId=` | getProjectByFunding | 스토어 프로젝트 조회 By 펀딩 | isMakerByCampaignId or isAdmin |

### `StudioSaveProjectController` — 스튜디오 프로젝트 저장·제출
base: `/api/studio/projects/{projectNo}` (`store-api/.../rest/project/studio/StudioSaveProjectController.java:13`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| PUT | `/api/studio/projects/{projectNo}/save-temporary` | saveTemporary | 임시 저장(메이커) | isMakerByProjectNo |
| PUT | `/api/studio/projects/{projectNo}/save` | save | 저장(메이커) | isMakerByProjectNo |
| PUT | `/api/studio/projects/{projectNo}/save-restricted` | saveRestricted | 판매중 제한 정보 저장(메이커) | isMakerByProjectNo |
| PUT | `/api/studio/projects/{projectNo}/save-temporary-by-admin` | saveTemporaryByAdmin | 임시 저장(관리자) | isAdmin |
| PUT | `/api/studio/projects/{projectNo}/save-by-admin` | saveByAdmin | 저장(관리자) | isAdmin |
| POST | `/api/studio/projects/{projectNo}/submit` | submit | 제출(메이커) | isMakerByProjectNo |
| POST | `/api/studio/projects/{projectNo}/submit-by-admin` | submitByAdmin | 제출(관리자) | isAdmin |

### `AdminProjectController` — 관리자 프로젝트 목록/상세·레이블·입점타입
base: `/api/admin/projects` (`store-api/.../rest/project/admin/AdminProjectController.java:40`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/projects` | search | 프로젝트 목록 조회 | isAdmin |
| GET | `/api/admin/projects/excel` | searchForExcel | 프로젝트 목록 엑셀 | isAdmin |
| GET | `/api/admin/projects/{projectNo}` | getProject | 프로젝트 상세 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/base-funding` | getBaseFunding | 본펀딩 조회 | isAdmin |
| POST | `/api/admin/projects/{projectNo}/labels/{labelKeyword}` | saveLabel | 태그 설정 | isAdmin |
| DELETE | `/api/admin/projects/{projectNo}/labels/{labelKeyword}` | deleteLabel | 태그 미설정 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/labels/{labelKeyword}/histories` | getLabelHistory | 태그 히스토리 | isAdmin |
| PUT | `/api/admin/projects/{projectNo}/entered-type` | changeEnteredType | 입점 타입 전환 | isAdmin |

### `AdminProjectDocumentController` — 관리자 프로젝트 서류
base: `/api/admin/projects` (`store-api/.../rest/project/admin/AdminProjectDocumentController.java:23`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/admin/projects/{projectNo}/documents` | save | 프로젝트 파일 저장 | isAdmin |
| DELETE | `/api/admin/projects/{projectNo}/documents/{documentNo}` | delete | 프로젝트 파일 삭제 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/documents` | getAllProjectDocument | 프로젝트 서류 조회 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/maker-required-documents` | getAllMakerRequiredDocument | 메이커 필수 서류 | isAdmin |

### `AdminProjectManagementController` — 관리자 프로젝트 진행 관리
base: `/api/admin/project-managements` (`store-api/.../rest/projectmanagement/admin/AdminProjectManagementController.java:32`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/project-managements/{projectNo}` | getProjectManagement | 프로젝트 관리 조회 | isAdmin |
| GET | `/api/admin/project-managements/{projectNo}/histories` | getAllHistory | 진행 관리 히스토리 | isAdmin |
| PUT | `/api/admin/project-managements/{projectNo}/events/{eventType}` | event | 진행 상태 변경 | isAdmin |
| POST | `/api/admin/project-managements/{projectNo}/feedbacks` | feedback | 피드백 전송 | isAdmin |
| GET | `/api/admin/project-managements/{projectNo}/feedbacks/{feedbackNo}` | getFeedback | 피드백 조회 | isAdmin |
| POST | `/api/admin/project-managements/{projectNo}/manager` | saveManager | 담당자 저장 | isAdmin |
| PUT | `/api/admin/project-managements/{projectNo}/notes/{noteType}` | saveNote | 메모 저장 | isAdmin |
| PUT | `/api/admin/project-managements/{projectNo}/3party-involved-types` | saveThirdPartyInvolved | 3자정산 타입 저장 | isAdmin |
| POST | `/api/admin/project-managements/{projectNo}/progress-type/{progressType}` | saveProgressType | 진행관리 구분 저장 | isAdmin |
| POST | `/api/admin/project-managements/{projectNo}/tax-type/{taxType}` | saveTaxType | 세금 구분 저장 | isAdmin |
| GET | `/api/admin/project-managements/{projectNo}/screening-condition` | getScreeningCondition | 심사 조건 데이터 | isAdmin |

### `AdminProjectManagerController` — 관리자 담당자 목록
base: `/api/admin/project-managers` (`store-api/.../rest/projectmanagement/admin/AdminProjectManagerController.java:16`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/project-managers` | getAllManager | 담당자 목록 조회 | isAdmin |

---

## 4. 정산/수수료/출금 (12 컨트롤러, 44 endpoints)

> `SettlementBaseController`(`store-api/.../rest/settlement/SettlementBaseController.java:9`)는 매핑 없는 공통 예외 처리 베이스 클래스입니다(엔드포인트 0, `@ExceptionHandler` 2건). 다른 정산 컨트롤러가 이를 상속합니다.

### `SettlementRestController` — 메이커 정산 내역서 다운로드
base: `/api/settlement/seller` (`store-api/.../rest/settlement/SettlementRestController.java:22`, `@RestController`, `@Validated`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/settlement/seller/{seq}/statement-file` | downloadSettlementStatementFile | 정산 내역서 PDF 다운로드 | 관측된 보안 없음 |

### `StudioSellerSaleSettlementRestController` — 스튜디오 매출 정산 내역
base: `/api/studio/settlement` (`store-api/.../rest/settlement/studio/StudioSellerSaleSettlementRestController.java:28`, `@RestController`, `@Validated`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/settlement/sales/excel-download` | downloadSellerSaleSettlementExcel | 매출수수료 상세 엑셀 | 관측된 보안 없음 |
| GET | `/api/studio/settlement/sales/count` | getTotalCount | 정산 내역 총 건수 | 관측된 보안 없음 |

### `StudioSettlementManagementController` — 스튜디오 정산 내역서 목록·다운로드
base: `/api/studio/settlement-management/projects/{projectNo}` (`store-api/.../rest/settlement/studio/StudioSettlementManagementController.java:30`, `@RestController`, 클래스 `isMakerByProjectNo or isAdmin`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/settlement-management/projects/{projectNo}/statements` | getSettlementStatementList | 정산 내역서 목록 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/settlement-management/projects/{projectNo}/statement-download` | downloadSettlementStatement | 정산 내역서 PDF | isMakerByProjectNo or isAdmin |

### `AdminSaleSettlementRestController` — 관리자 판매 정산
base: `/api/admin/settlement/sale` (`store-api/.../rest/settlement/admin/AdminSaleSettlementRestController.java:38`, `@RestController`, `@Validated`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/settlement/sale` | getSaleSettlementList | 판매 정산 목록 | isAdmin |
| GET | `/api/admin/settlement/sale/excels/download` | downloadSaleSettlementExcel | 구매확정 판매내역 엑셀 | isAdmin |
| POST | `/api/admin/settlement/sale/orders/{orderNumber}/excludedSettlement` | addExcludedSaleSettlement | 판매 정산 제외 추가 | isAdmin |
| GET | `/api/admin/settlement/sale/status` | getSaleSettlementStatus | 정산 상태 조회 | isAdmin |
| POST | `/api/admin/settlement/sale/orders/{orderNo}/pay` | addSaleSettlement | 판매 정산 확정(이벤트) | isAdmin |
| POST | `/api/admin/settlement/sale/orders/pay` | addBulkSaleSettlement | 판매 정산 일괄 확정(이벤트) | isAdmin |
| POST | `/api/admin/settlement/sale/orders/{orderNo}/cancel` | addPayCanceledSaleSettlement | 결제 취소 정산 처리(이벤트) | isAdmin |
| POST | `/api/admin/settlement/sale/projects/{projectNo}/open` | openProject | 오픈 시 기본 수수료율 등록 | isAdmin |
| DELETE | `/api/admin/settlement/sale/{seq}` | removeSaleSettlement | 판매 정산 삭제 | isAdmin |

### `AdminSellerSettlementRestController` — 관리자 메이커 정산(마감·조정·재정산)
base: `/api/admin/settlement/seller` (`store-api/.../rest/settlement/admin/AdminSellerSettlementRestController.java:48`, `@RestController`, 메서드별 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/settlement/seller` | getSellerSettlementList | 메이커 정산 목록(회차) | isAdmin |
| GET | `/api/admin/settlement/seller/{seq}/statement-file` | downloadSettlementStatementFile | 정산 내역서 PDF | isAdmin |
| GET | `/api/admin/settlement/seller/excel-download/settlement` | downloadSellerSettlementExcel | 메이커 정산 엑셀 | isAdmin |
| GET | `/api/admin/settlement/seller/excel-download/monthly-trans-statement` | downloadMonthlyTransStatementExcel | 월별 거래 명세 엑셀 | isAdmin |
| GET | `/api/admin/settlement/seller/excel-download/taxBill` | downloadTaxBillExcel | 세금계산서 발행 엑셀 | isAdmin |
| GET | `/api/admin/settlement/seller/excel-download/paymentRequest` | downloadPaymentRequestExcel | 지급요청서 엑셀 | isAdmin |
| POST | `/api/admin/settlement/seller/handAdjustment` | addHandAdjustmentAmount | 수기 조정 금액 입력 | isAdmin |
| GET | `/api/admin/settlement/seller/handAdjustment/history` | getHandAdjustmentHistory | 수기 조정 히스토리 | isAdmin |
| GET | `/api/admin/settlement/seller/handAdjustment/accumulatedHistory` | getHandAdjustmentAccumulatedHistory | 수기 조정 누적 히스토리 | isAdmin |
| POST | `/api/admin/settlement/seller/memo` | inputSettlementRoundMemo | 정산 메모 입력 | isAdmin |
| GET | `/api/admin/settlement/seller/memo` | getSettlementRoundMemo | 정산 메모 조회 | isAdmin |
| POST | `/api/admin/settlement/seller/settlementRound/close` | closeSettlementRound | 정산 마감(seq 리스트) | isAdmin |
| POST | `/api/admin/settlement/seller/settlementRounds/{settlementRound}/close` | closeSettlementRounds | 회차 전체 정산 마감 | isAdmin |
| GET | `/api/admin/settlement/seller/settlementRounds/{settlementRound}/close/confirm` | confirmCloseSettlementRound | 정산 마감 여부 확인 | isAdmin |
| POST | `/api/admin/settlement/seller/accountingClose` | doAccountingClose | 회계 마감(seq 리스트) | isAdmin |
| POST | `/api/admin/settlement/seller/settlementRounds/{settlementRound}/accountingClose` | doAccountingCloses | 회차 전체 회계 마감 | isAdmin |
| GET | `/api/admin/settlement/seller/settlementRounds/{settlementRound}/accountingClose/confirm` | confirmAccountingClose | 회계 마감 여부 확인 | isAdmin |
| POST | `/api/admin/settlement/seller/statements/{seq}/regenerate` | regenerateSettlementStateFile | 정산 내역서 재생성 | isAdmin |
| POST | `/api/admin/settlement/seller/statements/{seq}/noti/resend` | resendSettlementStateFile | 정산 내역서 재발송(seq) | isAdmin |
| POST | `/api/admin/settlement/seller/settlementRounds/{settlementRound}/noti/resend` | resendSettlementStateFileBySettlementRound | 정산 내역서 재발송(회차) | isAdmin |
| PUT | `/api/admin/settlement/seller/settlementRounds/{settlementRound}/recalculate` | recalculateSaleSettlements | 재정산(이벤트) | isAdmin |
| GET | `/api/admin/settlement/seller/slip/excel` | downloadSlip | 자동 전표용 엑셀 | isAdmin |

### `AdminPayAgentSettlementRestController` — 관리자 지급대행(나이스페이) 파일
base: `/api/admin/settlement/pay-agents` (`store-api/.../rest/settlement/admin/AdminPayAgentSettlementRestController.java:25`, `@RestController`, `@Validated`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/settlement/pay-agents/nicepay/subMallId-register-csv` | downloadSubMallIdRegisterCvsFile | 서브몰ID 등록 파일 | isAdmin |
| GET | `/api/admin/settlement/pay-agents/nicepay/pay-request-csv` | downloadPayRequestDataCvsFile | 지급데이터 등록 파일 | isAdmin |
| GET | `/api/admin/settlement/pay-agents/nicepay/subMallId-register/checkIfCan` | checkIfCanDownloadSubMallIdRegisterCvsFile | 등록 파일 다운로드 가능 여부 | isAdmin |

### `AdminFeeManagementController` — 관리자 수수료 현황·확정·품의
base: `/api/admin/fee-management` (`store-api/.../rest/fee/admin/AdminFeeManagementController.java:27`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/fee-management/projects/{projectNo}` | getFee | 프로젝트 수수료 현황 | isAdmin |
| GET | `/api/admin/fee-management/confirm-fee` | getConfirmFee | 확정 수수료 조회 | isAdmin |
| GET | `/api/admin/fee-management/proposal-progress` | getFeeProposalProgress | 수수료 품의 진행 검색 | isAdmin |

### `AdminFeeRateRestController` — 관리자 수수료율 등록·조회·검증·변경·삭제
base: `/api/admin/feerate` (`store-api/.../rest/fee/admin/AdminFeeRateRestController.java:29`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/admin/feerate/register` | registerFeerateList | 수수료율 등록 | isAdmin |
| GET | `/api/admin/feerate/list` | getList | 전체 수수료율 조회 | isAdmin |
| GET | `/api/admin/feerate/projects/{projectNo}/list` | getProjectFeeRates | 프로젝트 수수료율 조회 | isAdmin |
| POST | `/api/admin/feerate/projects/{projectNo}/validate` | validateProjectFeerate | 등록 전 중복 확인 | isAdmin |
| POST | `/api/admin/feerate/projects/{projectNo}/validate-for-update/{type}` | validateProjectFeerateForUpdate | 업데이트/삭제 검증 | isAdmin |
| DELETE | `/api/admin/feerate/projects/{projectNo}/feerates/{projectFeerateSeq}` | deleteProjectFeeRates | 프로젝트 수수료 삭제 | isAdmin |
| POST | `/api/admin/feerate/projects/{projectNo}/register` | registerProjectFeerateList | 프로젝트 수수료 등록 | isAdmin |
| PUT | `/api/admin/feerate/projects/{projectNo}/update` | updateProjectFeerateList | 프로젝트 수수료 변경 | isAdmin |
| PUT | `/api/admin/feerate/memo` | updateMemo | 수수료 메모 등록 | isAdmin |
| GET | `/api/admin/feerate/projects/{projectNo}/feerate-today` | getTotalFeeRateForToday | 오늘 적용 총수수료율 | isAdmin |

### `WithdrawController` — 서포터 주문 철회
base: `/api/withdraws` (`store-api/.../rest/withdraw/WithdrawController.java:19`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/withdraws` | withdraw | 서포터 본인 주문 철회 | isSupporterByOrderNo(#request.orderNo) |

### `StudioWithdrawController` — 스튜디오 주문 철회
base: `/api/studio/withdraws` (`store-api/.../rest/withdraw/studio/StudioWithdrawController.java:19`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/studio/withdraws` | withdraw | 메이커 정책 주문 철회 | isMakerHandleableOrderByOrderNo or isAdmin |

### `AdminWithdrawController` — 관리자 주문 철회
base: `/api/admin/withdraws` (`store-api/.../rest/withdraw/admin/AdminWithdrawController.java:19`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/admin/withdraws` | withdraw | 와디즈 정책 주문 철회 | isAdmin |

> 외부 연동(관측): `AdminPayAgentSettlementRestController`→나이스페이 지급대행 파일 생성(`PayAgentService`). 정산 확정/취소/재정산은 응답 메시지에 "이벤트 발송" 명시(내부 이벤트/비동기).

---

## 5. 스튜디오/메이커 (10 컨트롤러, 26 endpoints)

### `StudioInboundController` — 스튜디오 입고 관리
base: `/api/studio/projects/{projectNo}/inbounds` (`store-api/.../rest/inbound/studio/StudioInboundController.java:54`, `@RestController`, 클래스 `isMakerByProjectNo or isAdmin`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/projects/{projectNo}/inbounds` | search | 입고 목록 조회 | isMakerByProjectNo or isAdmin |
| POST | `/api/studio/projects/{projectNo}/inbounds/orders` | register | 입고 요청 등록 | isMakerByProjectNo or isAdmin |
| POST | `/api/studio/projects/{projectNo}/inbounds/orders/upload` | uploadBatch | 입고 요청 엑셀 일괄 등록 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/projects/{projectNo}/inbounds/orders/upload-form` | downloadUploadForm | 일괄 등록 양식 다운로드 | isMakerByProjectNo or isAdmin |
| DELETE | `/api/studio/projects/{projectNo}/inbounds/orders` | cancel | 입고 취소 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/projects/{projectNo}/inbounds/items/to-reorder` | getInboundReorderItems | 재등록 품목 조회 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/projects/{projectNo}/inbounds/items` | getInboundOrderItems | 입고 가능 품목 조회 | isMakerByProjectNo or isAdmin |
| PUT | `/api/studio/projects/{projectNo}/inbounds/items/{inboundFmsRef}/{inventoryItemCode}` | updateInboundItem | 입고 품목 수정 | isMakerByProjectNo or isAdmin |

### `StudioMakerBusinessInfoController` — 프로젝트 대표자/정산정보 조회
base: `/api/studio/projects/{projectNo}/maker-business-info` (`store-api/.../rest/project/studio/StudioMakerBusinessInfoController.java:18`, `@RestController`, `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/projects/{projectNo}/maker-business-info` | getMakerBusinessInfo | 대표자/정산정보 조회 | isMakerByProjectNo or isAdmin |
| GET | `/api/studio/projects/{projectNo}/maker-business-info/sync-target` | getSyncTarget | 정산정보 동기화 대상 | isMakerByProjectNo or isAdmin |
| POST | `/api/studio/projects/{projectNo}/maker-business-info/sync-target/by-to-be-changed` | getSyncTargetByToBeChanged | 저장될 정보 기준 동기화 대상 | isAdmin |

### `StudioFeatureAccessPolicyController` — 스튜디오 기능 접근 정책
base: `/api/studio/projects` (`store-api/.../rest/accesspolicy/studio/StudioFeatureAccessPolicyController.java:17`, `@RestController`, `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/projects/{projectNo}/feature-access-policies` | get | 기능 접근 정책 조회 | isMakerByProjectNo or isAdmin |

### `StudioTermsAgreementController` — 프로젝트 약관 동의/조회
base: `/api/studio/projects/{projectNo}/terms-agreements/{termsType}` (`store-api/.../rest/termsaggrement/studio/StudioTermsAgreementController.java:16`, `@RestController`, `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/studio/projects/{projectNo}/terms-agreements/{termsType}` | agree | 약관 동의 | isMakerByProjectNo |
| GET | `/api/studio/projects/{projectNo}/terms-agreements/{termsType}` | getTermsAgreement | 약관 동의 조회 | isMakerByProjectNo or isAdmin |

### `StudioShippingController` — 스튜디오 발송 처리
base: `/api/studio` (`store-api/.../rest/order/studio/StudioShippingController.java:66`, `@RestController`, `implements InitializingBean`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/studio/shippings/check` | checkInvoice | 송장 확인 | 관측된 보안 없음 |
| PUT | `/api/studio/orders/shippings/prepare` | prepareForShipping | 발송 준비 처리 | isMakerAccessibleOrderBy… or isAdmin |
| GET | `/api/studio/orders/for-shipping/excel` | downloadExcelForShipping | 발송 처리용 엑셀 | isMakerAccessibleOrderBy… or isAdmin |
| POST | `/api/studio/orders/{orderNo}/shipping` | shipping | 발송 처리 | isMakerHandleableOrderByOrderNo or isAdmin |
| POST | `/api/studio/projects/{projectNo}/shippings` | uploadBatch | 일괄 발송 엑셀 업로드 | isMakerAccessibleOrderBy… or isAdmin |
| PUT | `/api/studio/projects/{projectNo}/shippings/{token}` | requestBatch | 일괄 발송 처리 요청 | isMakerAccessibleOrderByProjectNo or isAdmin |

### `DeprecatedStudioShippingController` — (deprecated) 발송 준비
base: `/api/studio` (`store-api/.../rest/order/studio/DeprecatedStudioShippingController.java:21`, `@RestController`, 클래스·메서드 `@Deprecated`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| PUT | `/api/studio/projects/{projectNo}/shippings/prepare` | prepareForShipping | 발송 준비(deprecated) | isMakerHandleableOrderByProjectNo or isAdmin |

### `InternalMakerBusinessInfoController` — 내부 대표자/정산정보 bulk 조회
base: `/api/internal/projects` (`store-api/.../rest/project/internal/InternalMakerBusinessInfoController.java:19`, `@RestController`, `@ForceMasterDataSource`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/internal/projects/maker-business-info` | getAllMakerBusinessInfo | 대표자/정산정보 bulk 조회 | 관측된 보안 없음 |

### `AdminMakerBusinessInfoController` — 관리자 사업자/정산정보 조회
base: `/api/admin/projects/{projectNo}/maker-business-info` (`store-api/.../rest/project/admin/AdminMakerBusinessInfoController.java:25`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/projects/{projectNo}/maker-business-info` | getMakerBusinessInfo | 사업자 정보 조회 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/maker-business-info/sync-histories` | getBusinessInfoSyncHistory | 정산정보 동기화 히스토리 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/maker-business-info/sync-candidate` | getSyncCandidate | 동일 사업자번호 프로젝트 조회 | isAdmin |

### `MakerDashboardController` — 메이커 대시보드 집계
base: `/api/dashboard/maker` (`store-api/.../rest/aggregation/MakerDashboardController.java:22`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/dashboard/maker` | getMakerDashboard | 메이커 대시보드 데이터 | isAdmin or isMatchUserId(#request.userId) |
| GET | `/api/dashboard/maker/settlements` | getMakerSettlementDashboard | 대시보드 정산일 데이터 | @Impersonatable(currentUserId) |

### `AdminPartnerServiceController` — 관리자 파트너 서비스 설정
base: `/api/admin/projects/{projectNo}/partner-service` (`store-api/.../rest/partnerservice/admin/AdminPartnerServiceController.java:14`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/admin/projects/{projectNo}/partner-service` | enable | 파트너 서비스 설정 | isAdmin |
| DELETE | `/api/admin/projects/{projectNo}/partner-service` | disable | 파트너 서비스 해제 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/partner-service/histories` | getAllHistory | 파트너 서비스 히스토리 | isAdmin |

> 외부 연동(관측): `StudioInboundController`→`FulfillmentApiClient`(풀필먼트 FMS: 입고 목록·검증), 엑셀 파싱(Apache POI). `StudioShippingController`→`TrackerService`(송장), `PublicStorage`+CDN(실패 사유 엑셀 업로드). `@ForceMasterDataSource`가 `StudioMakerBusinessInfo`/`StudioFeatureAccessPolicy`/`StudioTermsAgreement`/`InternalMakerBusinessInfo` 클래스에 적용됩니다.

---

## 6. 배송/만족도/리액션 (10 컨트롤러, 30 endpoints)

### `ShippingController` — 택배 송장 확인
base: `/api/shippings` (`store-api/.../rest/order/ShippingController.java:11`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/shippings/check` | checkInvoice | 송장 확인 | 없음 |

### `AdminShippingController` — 어드민 발송/미발송 처리
base: `/api/admin/orders` (`store-api/.../rest/order/admin/AdminShippingController.java:36`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| PUT | `/api/admin/orders/{orderNo}/cancel-shipping` | cancelShipping | 미발송 처리 | isAdmin |
| POST | `/api/admin/orders/{orderNo}/shipping` | shipping | 발송 처리(송장 등록) | isAdmin |
| PUT | `/api/admin/orders/shippings/prepare` | prepareForShipping | 발송 준비 처리 | isAdmin |
| GET | `/api/admin/orders/for-shipping/excel` | getAllOrderForShippingExcel | 발송용 주문 엑셀 | isAdmin |

### `DeliveryRegionController` — 우편번호 제주/도서산간 확인
base: `/api/delivery-regions` (`store-api/.../rest/region/DeliveryRegionController.java:15`, `@RestController`, `@Validated`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/delivery-regions/{zipCode}` | get | 제주/도서산간 여부 확인 | 없음 |

### `AdminWaDeliveryController` — 어드민 와배송 조회/상태 변경
base: `/api/admin/projects/{projectNo}/wa-delivery` (`store-api/.../rest/wadelivery/admin/AdminWaDeliveryController.java:22`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/projects/{projectNo}/wa-delivery` | getWaDelivery | 와배송 조회 | isAdmin |
| GET | `/api/admin/projects/{projectNo}/wa-delivery/histories` | getAllHistory | 와배송 상태 히스토리 | isAdmin |
| PUT | `/api/admin/projects/{projectNo}/wa-delivery/actions/{action}` | changeStatus | 와배송 상태 변경 | isAdmin |

### `SatisfactionController` — 프로젝트 만족도 평가 CRUD
base: `/api/satisfactions` (`store-api/.../rest/satisfaction/SatisfactionController.java:41`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/satisfactions` | getAllSatisfaction | 만족도 목록 조회 | 없음 |
| GET | `/api/satisfactions/aggregation` | getAggregation | 만족도 집계 조회 | 없음 |
| GET | `/api/satisfactions/my/by-order` | getMySatisfaction | 나의 만족도 단건(주문번호) | isSupporterByOrderNo |
| POST | `/api/satisfactions` | register | 만족도 등록 | isSupporterByOrderNo(#request.orderNo) |
| PUT | `/api/satisfactions/{satisfactionNo}` | edit | 만족도 수정 | isSupporterBySatisfactionNo |
| DELETE | `/api/satisfactions/{satisfactionNo}` | delete | 만족도 삭제 | isSupporterBySatisfactionNo |
| GET | `/api/satisfactions/images/by-proejct/{projectNo}` | getSatisfactionImagesByProjectNo | 만족도 이미지(`@Deprecated`, 경로 오타 `by-proejct` 관측) | 없음 |

### `SatisfactionReplyController` — 만족도 답글(사용자)
base: `/api/satisfactions` (`store-api/.../rest/satisfaction/SatisfactionReplyController.java:42`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/satisfactions/{satisfactionNo}/replies` | getSatisfactionReplies | 답글 리스트 조회 | 없음 |
| POST | `/api/satisfactions/{satisfactionNo}/replies` | registerSatisfactionReply | 답글 등록 | 없음(currentUserId) |
| PATCH | `/api/satisfactions/replies/{satisfactionReplyNo}` | modifySatisfactionReply | 답글 수정 | isSupporterBySatisfactionReplyNo |
| DELETE | `/api/satisfactions/replies/{satisfactionReplyNo}` | deleteSatisfactionReply | 답글 삭제 | isSupporterBySatisfactionReplyNo |

### `AdminSatisfactionController` — 어드민 만족도 조회·블라인드
base: `/api/admin/satisfactions` (`store-api/.../rest/satisfaction/admin/AdminSatisfactionController.java:32`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/satisfactions` | search | 만족도 목록 조회 | isAdmin |
| PUT | `/api/admin/satisfactions/{satisfactionNo}/hidden` | changeHidden | 만족도 블라인드(숨김) | isAdmin |
| GET | `/api/admin/satisfactions/{satisfactionNo}` | getSatisfactionDetail | 만족도 단건 조회 | isAdmin |

### `AdminSatisfactionReplyController` — 어드민 만족도 댓글
base: `/api/admin/satisfactions` (`store-api/.../rest/satisfaction/admin/AdminSatisfactionReplyController.java:33`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/satisfactions/{satisfactionNo}/replies` | getAdminSatisfactionReplies | 댓글 리스트 조회 | isAdmin |
| POST | `/api/admin/satisfactions/{satisfactionNo}/replies` | registerAdminSatisfactionReply | 댓글 등록(isWadiz=true) | isAdmin |
| PUT | `/api/admin/satisfactions/replies/{satisfactionReplyNo}` | editAdminSatisfactionReply | 댓글 수정 | isAdmin |
| DELETE | `/api/admin/satisfactions/replies/{satisfactionReplyNo}` | deleteAdminSatisfactionReply | 댓글 삭제 | isAdmin |
| GET | `/api/admin/satisfactions/replies/{satisfactionReplyNo}` | getAdminSatisfactionReply | 특정 댓글 조회 | isAdmin |

### `ReactionController` — 리액션 토글
base: `/api/reactions` (`store-api/.../rest/reaction/ReactionController.java:21`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| PUT | `/api/reactions` | toggleReaction | 리액션 토글 | 없음(currentUserId) |

### `SupporterController` — 서포터 최근 배송지 조회
base: `/api/supporters` (`store-api/.../rest/supporter/SupporterController.java:15`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/supporters/my/shipping-addresses/latest` | getLatestShippingAddresses | 최근 배송지 조회 | 없음(currentUserId) |

> 외부 연동(관측): `ShippingController.checkInvoice`→`TrackerService`(택배 조회 추정). `AdminShippingController.shipping`은 `HttpClientErrorException` 처리(TODO STORE-857 스튜디오 송장 조회 실패, 외부 HTTP 연동 추정). `SatisfactionReplyController`는 `application.cdn.base-url`로 프로필 이미지 URL 조합.

---

## 7. 컬렉션/큐레이션/프로모션/첨부/연동/셋업 (13 컨트롤러, 34 endpoints)

### `CollectionController` — 컬렉션 공개 조회
base: `/api/collections` (`store-api/.../rest/collection/CollectionController.java:18`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/collections/{collectionNo}` | get | 컬렉션 상세 조회 | 없음 |
| GET | `/api/collections/by-keyword` | getByKeyword | 키워드로 컬렉션 조회 | 없음 |
| GET | `/api/collections` | search | 컬렉션 목록 조회 | 없음 |

### `AdminCollectionController` — 어드민 컬렉션 CRUD
base: `/api/admin/collections` (`store-api/.../rest/collection/admin/AdminCollectionController.java:25`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/collections` | search | 컬렉션 목록 조회 | isAdmin |
| GET | `/api/admin/collections/{collectionNo}` | get | 컬렉션 상세 조회 | isAdmin |
| POST | `/api/admin/collections` | create | 컬렉션 등록 | isAdmin |
| PUT | `/api/admin/collections/{collectionNo}` | modify | 컬렉션 수정 | isAdmin |

### `AdminCollectionProjectController` — 어드민 컬렉션-프로젝트 매핑
base: `/api/admin/collections/{collectionNo}/projects` (`store-api/.../rest/collection/admin/AdminCollectionProjectController.java:18`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/collections/{collectionNo}/projects` | getAll | 컬렉션 프로젝트 목록 | isAdmin |
| POST | `/api/admin/collections/{collectionNo}/projects/check-status` | checkStatus | 프로젝트 상태 확인 | isAdmin |
| POST | `/api/admin/collections/{collectionNo}/projects/add-bulk` | addBulk | 프로젝트 여러 건 등록 | isAdmin |
| POST | `/api/admin/collections/{collectionNo}/projects/delete-bulk` | deleteBulk | 프로젝트 여러 건 제외 | isAdmin |
| DELETE | `/api/admin/collections/{collectionNo}/projects/{projectNo}` | delete | 프로젝트 단건 제외 | isAdmin |

### `CurationController` — 큐레이션 공개 조회
base: `/api/curations` (`store-api/.../rest/curation/CurationController.java:14`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/curations` | getAll | 큐레이션 목록 조회 | 없음 |

### `AdminCurationController` — 어드민 큐레이션 관리
base: `/api/admin/curations` (`store-api/.../rest/curation/admin/AdminCurationController.java:29`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/curations` | search | 큐레이션 목록 조회 | isAdmin |
| POST | `/api/admin/curations` | create | 큐레이션 등록 | isAdmin |
| PUT | `/api/admin/curations/{curationNo}` | modify | 큐레이션 수정 | isAdmin |
| PUT | `/api/admin/curations/ordinal` | changeOrdinal | 노출 순서 변경 | isAdmin |
| PUT | `/api/admin/curations/{curationNo}/usable` | curationUsable | 큐레이션 활성 | isAdmin |
| PUT | `/api/admin/curations/{curationNo}/unusable` | curationUnusable | 큐레이션 비활성 | isAdmin |

### `AdminDiscountPromotionController` — 어드민 할인 프로모션
base: `/api/admin` (`store-api/.../rest/promotion/admin/AdminDiscountPromotionController.java:31`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/discount-promotions/eligible-user-types` | getAllEligibleUser | 할인 대상 타입 목록 | isAdmin |
| GET | `/api/admin/discount-promotions` | search | 프로모션 목록 조회 | isAdmin |
| GET | `/api/admin/discount-promotions/{discountPromotionNo}` | get | 프로모션 상세 조회 | isAdmin |
| POST | `/api/admin/discount-promotions` | create | 프로모션 추가 | isAdmin |
| PUT | `/api/admin/discount-promotions/{discountPromotionNo}` | modify | 프로모션 수정 | isAdmin |
| PUT | `/api/admin/discount-promotions/{discountPromotionNo}/priority/top` | changePriorityToTop | 우선순위 최상단 변경 | isAdmin |
| PUT | `/api/admin/discount-promotions/{discountPromotionNo}/items` | saveItems | 상품/할인 정보 저장 | isAdmin |
| GET | `/api/admin/products/for-add-to-promotion` | searchProductForAddToPromotion | 프로모션 추가용 상품 목록 | isAdmin |

### `AdminEventRestController` — 어드민 정산 실패 이벤트 관리
base: `/api/admin/settlement` (`store-api/.../rest/settlement/admin/AdminEventRestController.java:17`, `@RestController`, `@Validated`, `SettlementBaseController` 상속)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/admin/settlement/events/unhandledFailEvents` | getHandleFailedEvents | 미처리 실패 이벤트 조회 | 관측된 보안 없음 |
| POST | `/api/admin/settlement/events/unhandledFailEvents/retry` | retryHandlingFailedEvents | 지정 seq 실패 이벤트 재처리 | 관측된 보안 없음 |
| POST | `/api/admin/settlement/events/unhandledFailEvents/all/retry` | retryHandlingFailedAllEvents | 전체 실패 이벤트 재처리 | 관측된 보안 없음 |

### `AdminSetUpController` — 어드민 스토어 프로젝트 개설/복사
base: `/api/admin/projects` (`store-api/.../rest/project/admin/AdminSetUpController.java:21`, `@RestController`, 클래스 `isAdmin()`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/admin/projects/set-up-without-funding` | setUpWithoutFunding | 비펀딩 프로젝트 개설 | isAdmin |
| POST | `/api/admin/projects/set-up-via-copy` | setUpViaCopy | 스토어 프로젝트 복사 | isAdmin |

### `AttachmentController` — 첨부파일 업로드/다운로드/프리사인
base: `/api/attachments` (`store-api/.../rest/attachment/AttachmentController.java:30`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| POST | `/api/attachments` | upload | 파일 업로드(multipart) | 없음(currentUserId) |
| GET | `/api/attachments/{attachmentKey}` | download | 파일 다운로드(스트리밍) | isAdmin |
| POST | `/api/attachments/presign` | presign | S3 프리사인 URL 발급 | 없음 |

### `InternalAttachmentController` — 내부 첨부파일 메타데이터 조회
base: `/api/internal/attachments` (`store-api/.../rest/attachment/internal/InternalAttachmentController.java:15`, `@RestController`, `// FIXME is system` 주석)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/internal/attachments/{attachmentKey}/metadata` | getMetadata | 파일 메타데이터 조회 | 없음 |

### `InternalScmController` — 내부 SCM(외부 물류/재고) 조회
base: `/api/internal/scm` (`store-api/.../rest/scm/InternalScmController.java:18`, `@RestController`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/internal/scm/products` | getProducts | makerManagedCode로 SCM 상품 조회 | 없음 |
| GET | `/api/internal/scm/orders` | getOrder | orderNo·makerManagedCode로 SCM 주문 조회 | 없음 |
| GET | `/api/internal/scm/orders/confirmed` | getConfirmedOrders | 기간별 확정 주문 목록 | 없음 |

### `ExternalProjectCatalogFeedController` — 외부 광고/쇼핑 카탈로그 피드
base: `/api/external/projects/catalog-feed` (`store-api/.../rest/project/external/ExternalProjectCatalogFeedController.java:30`, `@RestController`, 응답 `text/plain`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/external/projects/catalog-feed/criteo-csv` | getCriteoCatalogAsCsv | 크리테오 카탈로그(CSV) | 없음 |
| GET | `/api/external/projects/catalog-feed/facebook-csv` | getFacebookCatalogAsCsv | 페이스북 카탈로그(CSV) | 없음 |
| GET | `/api/external/projects/catalog-feed/by-project/naver-shopping-tsv` | getNaverShoppingCatalogAsTsvByProject | 네이버 쇼핑(프로젝트 단위 TSV) | 없음 |
| GET | `/api/external/projects/catalog-feed/naver-shopping-tsv` | getNaverShoppingCatalogAsTsv | 네이버 쇼핑(상품 단위 TSV) | 없음 |

### `LinkpriceCpsPerformanceController` — 링크프라이스 CPS 실적
base: `/api/linkprice/performances` (`store-api/.../rest/external/linkprice/LinkpriceCpsPerformanceController.java:17`, `@RestController`, `@Validated`)

| HTTP | Path | 메서드 | 용도 | 인증 |
|---|---|---|---|---|
| GET | `/api/linkprice/performances` | getPerformances | 결제·취소·확정 일자 기준 CPS 실적 조회 | 없음 |

> 외부 연동(관측): 카탈로그 피드(Criteo/Facebook/Naver Shopping)와 Linkprice CPS 실적은 외부 광고·제휴 플랫폼이 수집해 가는 피드로 추정. `InternalScmController`는 외부 SCM(물류/재고) 조회.

---

## 통계

| 도메인 | 컨트롤러 | 엔드포인트 |
|---|---|---|
| 주문/결제 | 9 | 49 |
| 상품/재고/카테고리 | 7 | 15 |
| 프로젝트 | 12 | 54 |
| 정산/수수료/출금 | 12 | 44 |
| 스튜디오/메이커 | 10 | 26 |
| 배송/만족도/리액션 | 10 | 30 |
| 컬렉션/큐레이션/프로모션/첨부/연동/셋업 | 13 | 34 |
| **합계** | **73** | **252** |

## 인증 표현식 관측 목록

컨트롤러 `@PreAuthorize`에서 관측된 커스텀 SpEL 메서드(정의 파일 미확인):

- `isAdmin()` — 관리자
- `isMakerByProjectNo(#projectNo)` / `isMakerByCampaignId(#campaignId)` — 프로젝트/캠페인 담당 메이커
- `hasBeenOpenedByProjectNo(#projectNo)` — 오픈된 프로젝트 공개 접근
- `isNotHiddenByProjectNo(#projectNo)` — 숨김 아님
- `isSupporterByOrderNo(#orderNo)` / `isSupporterBySatisfactionNo` / `isSupporterBySatisfactionReplyNo` / `isSupporterByRestockSubscriptionNo` — 대상 리소스 소유 서포터 본인
- `isMakerAccessibleOrderBy…` / `isMakerHandleableOrderByOrderNo` / `isMakerHandleableOrderByProjectNo` — 주문 접근·처리 권한 메이커
- `isMatchUserId(#request.userId)` — 요청 userId 일치
