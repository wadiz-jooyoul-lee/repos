# com.wadiz.api.reward — API 엔드포인트 전수 목록

> 소스 기준: 16개 `*Controller.java` (`reward-api/src/main/java/com/wadiz/api/reward/rest/`) × ≈ **72 엔드포인트**.
> 도메인별 상세 (입력 DTO / Service / SQL) 는 `api-details/*.md` 참조.

모든 컨트롤러는 base path가 `/api/v1/rewards/*` 로 일관.

---

## 1. Coupon (11 컨트롤러, ≈48 endpoints)

### Coupon Core (9 컨트롤러)
**상세**: [`api-details/coupon-core.md`](./api-details/coupon-core.md)

#### CouponController (`rest/coupon/CouponController.java:31`)
base: `/api/v1/rewards/coupons`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 쿠폰 목록 |
| GET | `/owners/{userId}` | 유저가 보유한 쿠폰 |
| GET | `/owners/{userId}/qty` | 유저 보유 쿠폰 수 |
| GET | `/{couponKey}` | 쿠폰 상세 |
| GET | `/{couponKey}/discount-amount` | 할인 금액 계산 |
| GET | `/expected-expiration` | 만료 예정 |

#### CouponIssueController (`rest/coupon/CouponIssueController.java:25`)
base: `/api/v1/rewards/coupons/issues`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 발급 생성 |
| GET | `` | 발급 목록 |
| GET | `/{issueKey}` | 발급 상세 |
| GET | `/{issueKey}/codes` | 발급 코드 |
| GET | `/purpose-types` | 발급 용도 타입 |

#### CouponQueryController (`rest/coupon/CouponQueryController.java:27`)
base: `/api/v1/rewards/coupons/queries`

| Method | Path | 용도 |
|---|---|---|
| GET | `/expected-expiration` | 만료 예정 쿼리 |

#### CouponTemplateController (`rest/coupon/CouponTemplateController.java:24`)
base: `/api/v1/rewards/coupons/templates`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{templateNo}` | 템플릿 상세 |
| GET | `` | 템플릿 목록 |
| GET | `/qty` | 템플릿 수 |
| POST | `` | 템플릿 생성 |
| PUT | `/{templateNo}` | 템플릿 수정 |
| GET | `/{templateNo}/coupons` | 템플릿의 쿠폰 목록 |
| GET | `/{templateNo}/coupons/qty` | 템플릿의 쿠폰 수 |

#### CouponTransactionController (`rest/coupon/CouponTransactionController.java:22`)
base: `/api/v1/rewards/coupons/transactions`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{transactionKey}` | 거래 조회 |
| POST | `/users/{userId}/types/redeem/issue-types/coupon-code` | 코드로 사용 |
| POST | `/users/{userId}/types/redeem/issue-types/{issueType:download\|direct\|api}` | 유형별 사용 |
| POST | `/users/{userId}/types/redeem/issue-types/{issueType:download\|direct\|api}/bulk` | 유형별 bulk |
| POST | `/users/types/redeem/issue-types/{issueType:direct\|api}/bulk` | userId 없는 bulk |
| POST | `/users/{userId}/types/withdraw` | 철회 |
| POST | `/users/{userId}/types/use` | 사용 |
| POST | `/users/{userId}/types/refund` | 환불 |
| DELETE | `/{transactionKey}` | 거래 삭제 |

#### CouponSummationController (`rest/coupon/CouponSummationController.java:24`)
base: `/api/v1/rewards/coupons/summations`

| Method | Path | 용도 |
|---|---|---|
| GET | `/templates` | 템플릿 집계 |
| GET | `/templates/{templateNo}` | 템플릿별 집계 |
| GET | `/issues/{issueKey}` | 발급별 집계 |

#### CouponIssueSummationController (`rest/coupon/CouponIssueSummationController.java:28`)
base: `/api/v1/rewards/coupons/issue-summation`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 발급 집계 |

#### CouponTransactionSummationController (`rest/coupon/CouponTransactionSummationController.java:24`)
base: `/api/v1/rewards/coupons/transaction-summation`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 거래 집계 |

#### ProjectCouponSummaryController (`rest/coupon/ProjectCouponSummaryController.java:18`)
base: `/api/v1/rewards/coupons/projects`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 프로젝트별 쿠폰 요약 |
| GET | `/{projectNo}` | 프로젝트 상세 |

### Coupon External Maker (Braze 연동, 2 컨트롤러)
**상세**: [`api-details/coupon-external-maker.md`](./api-details/coupon-external-maker.md)

#### MakerCouponController (`rest/coupon/external/MakerCouponController.java:17`)
base: `/api/v1/rewards/coupons/makers/braze`

| Method | Path | 용도 |
|---|---|---|
| GET | `/project` | 프로젝트 쿠폰 (Braze 연동) |

#### MakerCouponTemplateController (`rest/coupon/external/MakerCouponTemplateController.java:31`)
base: `/api/v1/rewards/coupons/makers/{makerUserId}/templates`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/{templateNo}` | 템플릿 수정 |
| GET | `/{templateNo}` | 템플릿 조회 |

---

## 2. Collection (2 컨트롤러, ≈13 endpoints)
**상세**: [`api-details/collection-satisfaction-memo.md`](./api-details/collection-satisfaction-memo.md)

### CollectionController (`rest/collection/CollectionController.java:18`)
base: `/api/v1/rewards/collections`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 컬렉션 목록 |
| GET | `/{collectionNo}` | 컬렉션 상세 |
| GET | `/keywords/{keyword}` | 키워드 검색 |
| GET | `/campaigns/{campaignId}` | 캠페인별 컬렉션 |
| POST | `` | 컬렉션 생성 |
| PUT | `/{collectionNo}` | 컬렉션 수정 |

### CollectionMappingController (`rest/collection/CollectionMappingController.java:16`)
base: `/api/v1/rewards/collections`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{collectionNo}/campaigns` | 컬렉션의 캠페인 |
| GET | `/keywords/{keyword}/campaigns` | 키워드별 캠페인 |
| POST | `/{collectionNo}/campaigns` | 매핑 생성 |
| POST | `/{collectionNo}/campaigns/bulk` | bulk 매핑 |
| DELETE | `/{collectionNo}/campaigns/{campaignNo}` | 매핑 해제 |
| DELETE | `/{collectionNo}/campaigns/bulk` | bulk 해제 |

---

## 3. Satisfaction (2 컨트롤러, ≈17 endpoints)
**상세**: [`api-details/collection-satisfaction-memo.md`](./api-details/collection-satisfaction-memo.md)

### SatisfactionController (`rest/satisfaction/SatisfactionController.java:21`)
base: `/api/v1/rewards/satisfactions`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 만족도 등록 |
| PUT | `/{satisfactionNo}` | 수정 |
| PUT | `/{satisfactionNo}/is-hidden` | 숨김 처리 |
| PUT | `/{satisfactionNo}/benefit` | 혜택 지급 |
| DELETE | `/{satisfactionNo}` | 삭제 |
| GET | `/{satisfactionNo}` | 상세 |
| GET | `/campaigns/{campaignId}/users/{userId}` | 유저 만족도 |
| GET | `` | 목록 |
| GET | `/qty` | 수 |
| PUT | `` | 일괄 수정 |
| GET | `/replies/{satisfactionReplyNo}` | 답글 조회 |
| POST | `/{satisfactionNo}/replies` | 답글 작성 |
| PUT | `/replies/{satisfactionReplyNo}` | 답글 수정 |
| DELETE | `/replies/{satisfactionReplyNo}` | 답글 삭제 |
| GET | `/campaigns/bulk` | bulk 캠페인 |
| POST | `/projects/search` | 프로젝트 검색 |

### SatisfactionAggregateController (`rest/satisfaction/SatisfactionAggregateController.java:18`)
base: `/api/v1/rewards/satisfactions/aggregates`

| Method | Path | 용도 |
|---|---|---|
| GET | `/campaigns/{campaignId}` | 캠페인별 집계 |
| POST | `/campaigns/bulk` | bulk 집계 |

---

## 4. Memo (1 컨트롤러, 3 endpoints)
**상세**: [`api-details/collection-satisfaction-memo.md`](./api-details/collection-satisfaction-memo.md)

### MemoController (`rest/memo/MemoController.java:15`)
base: `/api/v1/rewards/memos`

| Method | Path | 용도 |
|---|---|---|
| GET | `/campaigns/{campaignId}/memo-categories/{memoCategory}` | 캠페인·카테고리별 메모 |
| POST | `` | 메모 작성 |
| PUT | `/{memoNo}` | 메모 수정 |

---

## 5. Batch (reward-batch 모듈)
**상세**: [`api-details/batch.md`](./api-details/batch.md)

REST 엔드포인트 없음 (Spring Batch Job). 3개 Job:
- **CouponExpirationNotificationJob** — 쿠폰 만료 알림 (Push / AlimTalk / Email Composite Sender)
- **ProjectCouponSummaryJob** — 프로젝트별 쿠폰 집계 Tasklet
- **CouponTransactionSummationJob** — 쿠폰 거래 합계

---

## 통계

| 도메인 | 컨트롤러 | 엔드포인트 (약) | 상세 파일 |
|---|---|---|---|
| Coupon Core | 9 | 48 | coupon-core.md |
| Coupon External Maker | 2 | 3 | coupon-external-maker.md |
| Collection | 2 | 13 | collection-satisfaction-memo.md |
| Satisfaction | 2 | 17 | collection-satisfaction-memo.md |
| Memo | 1 | 3 | collection-satisfaction-memo.md |
| Batch | — (0 REST) | (3 Job) | batch.md |
| **합계** | **16** | **≈84** | — |
