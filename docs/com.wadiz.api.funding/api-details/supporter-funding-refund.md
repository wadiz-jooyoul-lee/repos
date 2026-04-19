# Supporter / Funding / Refund API 상세 스펙

펀딩 참여자(서포터)의 마이페이지/참여내역/환불 조회 관련 16개 엔드포인트.

- **대상 컨트롤러**:
  - `SupporterController` (`/api/supporters`) — 6개
  - `SupporterInternalController` (`/api/internal/supporters`) — 3개
  - `FundingController` (`/api/fundings`) — 3개
  - `FundingInternalController` (`/api/internal/fundings`) — 3개
  - `RefundController` (`/api/refund`) — 1개

- **저장소**: MySQL (MyBatis 주력)
- **주요 Mapper**: `BackingPaymentMapper`, `FundingMapper`, `BackingRewardMapper`, `BackingPaymentRefundMapper`, `RewardRefundMapper`, `CampaignMapper`, `GlobalProjectMapper`

> **기록 범위**: 이 레포의 Controller/Proxy/Gateway/Mapper XML 에서 직접 관찰 가능한 호출만 기록. UseCase 구현체는 외부 jar(`funding-core`)에 있어 Usecase 내부 호출 순서/분기는 확인 불가.

---

## 1. GET `/api/supporters/my/shipping-addresses/latest` — 최근 배송지 목록

- **Method**: `SupporterController.recentShippingAddressList`
- **Auth**: 로그인 필수
- **Cache**: `supporterProxy.recentShippingAddressList`에 `@Cacheable(cacheNames="supporter")`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `qty` | `Integer` | ✅ | 조회 건수 |

### Response — `List<SupporterShippingListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | `String` | 수령인 이름 |
| `phoneNumber` | `String` | 연락처 |
| `address.zipCode / addressLine1 / addressLine2 / countryCode` | `String` | — |
| `customsCode` | `String` | 개인통관부호 |
| `registeredAt` | `ZonedDateTime` | 등록 일자 |

### MySQL 쿼리 (`BackingPaymentMapper.recentShippingAddressSearch`)

```sql
SELECT B.CountryCode,
       B.ZipCode,
       B.Address        AS baseAddress,
       B.AddressDetails AS detailAddress,
       B.PresenteeName  AS name,
       B.ContactNumber  AS phoneNumber,
       MAX(B.RegDate)   AS registeredAt,
       B.CustomsCode
FROM (
  SELECT BackingPaymentId
  FROM BackingPayment
  WHERE UserId = ?
    AND IsCanceled = false
  ORDER BY RegDate DESC LIMIT 100
) AS A
INNER JOIN BackingPayment B ON B.BackingPaymentId = A.BackingPaymentId
WHERE LENGTH(TRIM(B.Address)) > 0
  AND IF(B.CountryCode = 'KR' OR B.CountryCode IS NULL,
         B.ZipCode REGEXP '^[0-9]{3}-?[0-9]{3}$|^[0-9]{5}$',
         TRUE)
GROUP BY B.CountryCode, B.ZipCode, B.Address, B.AddressDetails, B.PresenteeName, B.ContactNumber
ORDER BY registeredAt DESC
LIMIT ?
```

- 최근 100건의 결제 내역에서 주소 중복 제거, 한국은 우편번호 형식 유효성까지 필터
- **접근 테이블**: `BackingPayment`

---

## 2. GET `/api/supporters/my/recent-pay-by` — 최근 결제 수단

- **Method**: `SupporterController.getRecentPayBy`
- **Cache**: `@Cacheable("getRecentPayBy")`

### Response — `SupporterRecentPayByResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `recentPayBy` | `String` | 최근 결제 수단 코드 |

### DB 호출

`RecentPayByUseCase.getRecentPayBy(userId)` — 이 레포에 전용 Gateway 구현체가 **없음**. `BackingPaymentMapper`의 기존 쿼리 조합으로 UseCase 내부에서 처리될 것으로 보이나 특정 불가.

→ **funding-core 확인 필요**

---

## 3. GET `/api/supporters/my/fundings` — 나의 펀딩 참여 내역 목록 (페이징)

- **Method**: `SupporterController.getMyFundingList`
- **정렬 기본**: `BackingPaymentId desc`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `filteringType` | `FilteringType` enum | ⬜ | 결제 상태 필터 (`PAY_RESERVATION`, `PAY_COMPLETE`, `FUNDING_FAILED` 등) |
| `bizModel` | `CampaignBizModel` enum | ⬜ | 서비스 모델 필터 |
| `page / size / sort` | — | ⬜ | 페이징 |

### Response — `PageResult<FundingListResponse>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `payStatus` | `String` | 결제 상태 코드 |
| `backingPaymentId` | `int` | 펀딩 번호 |
| `category / categoryCode` | `String` | 카테고리 |
| `targetAmount / totalFundingAmount` | `long` | 목표/현재 모집 금액 |
| `fundingDate` | `ZonedDateTime` | 펀딩 일자 |
| `title / hostName` | `String` | 프로젝트명/메이커 |
| `isEnded / isFundingSucceeded / isFundingPaused` | `Boolean` | 상태 |
| `achievementRate` | `int` | 달성률 |
| `isAllOrNothing` | `String` | 정산 구분 |
| `billingAmount` | `int` | 실결제 금액 |
| `whenPayFor / whenFinalPayFor` | `ZonedDateTime` | 결제 예정 / 마지막 결제 (17:00 고정) |
| `payStatusNm` | `String` | 결제 상태명 (CodeValue 조인) |
| `isWritableSatisfaction / isWrittenSatisfaction` | `Boolean` | 만족도 관련 |
| `campaignId` | `Integer` | 프로젝트 ID |
| `bizModel` | enum | — |
| `isNowPay` | `Boolean` | 지금 결제 여부 |
| `countryCode` | `String` | 국가 코드 |

### 컨트롤러 코드 흐름

1. `SecurityUtils.currentUserId()` + Locale 언어 획득
2. `FundingListQuery{userId, filteringType, languageCode, bizModel}` 생성
3. `supporterProxy.fundingList(query, pages, Sorts.by(desc("BackingPaymentId")))` 호출 — UseCase는 funding-core
4. Converter로 변환 후 `PageResult` 래핑

### MySQL 쿼리 (`SupporterQueryGatewayImpl.fundingListSearch` — 다단계 호출)

`fundingListSearch` 구현은 다음을 순서대로 실행:

**① 페이징된 펀딩 목록** (`FundingMapper.fundingListSearch`)
```sql
SELECT BP.payStatus, A.BackingPaymentId, C.TargetAmount,
       (SELECT SUM(FundingAmount)
          FROM wadiz_db.BackingPayment SS1
         WHERE SS1.CampaignId = A.CampaignId AND SS1.IsCanceled = false) AS TotalFundingAmount,
       CCM.CategoryCode, BP.RegDate AS FundingDate,
       CASE WHEN C.WhenHoldTo < DATE_ADD(NOW(), INTERVAL -1 DAY) THEN 'true' ELSE 'false' END AS isEnded,
       C.IsAllOrNothing, BP.BillingAmount,
       DATE_ADD(C.WhenHoldTo, INTERVAL 1 DAY) AS WhenPayFor,
       DATE_ADD(C.WhenHoldTo, INTERVAL 2 DAY) AS WhenFinalPayFor,
       PCV.ValueFriendly AS PayStatusNm,
       A.CampaignId, A.DeliveryStatus, A.RefundStatus AS IsRefunded,
       C.BizModel, BP.PayBy, BP.CountryCode,
       CP.PauseEndDate AS fundingPauseEndDate
FROM (
  SELECT A.CampaignId, A.BackingPaymentId,
         CASE WHEN EXISTS(
           SELECT 'O'
             FROM wadiz_db.BackingPaymentMapping SS2
             INNER JOIN wadiz_db.Shipping SS3 USE INDEX(IDX_Shipping__BackingId_DeliveryStatus)
                     ON SS3.BackingId = SS2.BackingId
             WHERE SS2.BackingPaymentId = A.BackingPaymentId
               AND SS3.DeliveryStatus = 'DELIVERED') THEN 'DELIVERED' ELSE 'PENDING' END AS DeliveryStatus,
         CASE WHEN EXISTS(
           SELECT 'O' FROM wadiz_db.RewardRefund SS1
           WHERE SS1.BackingPaymentId = A.BackingPaymentId AND SS1.UserId = A.UserId)
              THEN TRUE ELSE FALSE END AS RefundStatus
  FROM wadiz_db.BackingPayment A
  WHERE 1=1
    AND A.UserId = ?
    /* filteringType.payStatus 필터 */
    /* filteringType.isPayReservation/isPayComplete면 성공/진행중 프로젝트 EXISTS 조건 추가 */
    /* filteringType.isFundingFailed면 실패 프로젝트 EXISTS 조건 */
    /* bizModel 필터 */
  /* + 페이징/정렬 절 */
) A
INNER JOIN wadiz_db.BackingPayment BP       ON BP.BackingPaymentId = A.BackingPaymentId
INNER JOIN wadiz_db.Campaign C              ON C.CampaignId = BP.CampaignId
LEFT JOIN wadiz_db.CampaignCategoryMapping CCM
                                             ON CCM.CampaignId = C.CampaignId AND CCM.IsPrime = TRUE
INNER JOIN wadiz_db.CodeValue PCV            ON PCV.Value = BP.PayStatus AND PCV.GroupId = 'PAYSTATUS'
LEFT JOIN wadiz_db.CampaignPause CP          ON CP.CampaignId = C.CampaignId
ORDER BY A.BackingPaymentId DESC
```

**② 카운트** (`FundingMapper.fundingListcount`) — 동일 WHERE 절로 `COUNT(*)`

**③ 프로젝트 메타(다국어)** (`GlobalProjectMapper.findAllProjectOverview`)
```sql
SELECT C.CampaignId AS projectNo,
       IFNULL(SL.Title, IFNULL(DL.Title, WL.Title)) AS title,
       IF(? = 'ko', C.HostName, IFNULL(C.GlobalMakerName, C.HostName)) AS makerName
FROM Campaign C
     LEFT JOIN CampaignLanguage SL ON C.CampaignId = SL.CampaignId AND SL.LanguageCode = ?
     LEFT JOIN CampaignLanguage DL ON C.CampaignId = DL.CampaignId AND DL.LanguageCode = ?
     LEFT JOIN CampaignLanguage WL ON C.CampaignId = WL.CampaignId AND WL.LanguageCode = C.MakerStudioLanguageCode
WHERE C.CampaignId IN (?, ?, ...)
  AND C.IsDel = false
```

**④ 카테고리 네비게이션** — `CampaignCategoryQueryGateway.getFundingCategory()` (외부 `CategorySearchClient` HTTP 호출, 캐시됨)

- 결과에 Converter로 `category / hostName / title / isNowPay` 채움

**접근 테이블/리소스**: `BackingPayment`, `BackingPaymentMapping`, `Shipping`, `Campaign`, `CampaignCategoryMapping`, `CampaignLanguage`, `CodeValue`, `CampaignPause`, `RewardRefund` + 외부 카테고리 검색 API

---

## 4. GET `/api/supporters/my/fundings/{backingPaymentId}` — 펀딩 내역 상세

- **Method**: `SupporterController.getFundingDetail`
- **Auth**: 로그인 필수 (본인 소유 펀딩만 조회 가능 — SQL의 `AND BP.UserId = ?` 필터로 격리)

### Response — `FundingResponse` (큰 DTO)

주요 필드:
| 필드 | 타입 | 설명 |
|---|---|---|
| `backingPaymentId / campaignId / userId` | `Integer` | 식별자 |
| `whenHoldTo / fundingAt` | `ZonedDateTime` | 일시 |
| `payStatus` | enum `PayStatus` | — |
| `payResult` | `String` | 결제 결과 설명 |
| `bill.*` | `Bill{ fundingAmount, rewardItemAmount, donationAmount, shippingCharge, paymentAmount, pointAmount, couponAmount, isUsedMembershipCoupon, billingShippingCharge, discountShippingCharge }` | 결제 내역 |
| `rewards[]` | `List<Reward>` | 리워드 (옵션/세트 구조 포함) |
| `paymentMethod.*` | `{payBy, serviceType, cardQuota, cardNumber, isSplitPayment, tid, walletName}` | — |
| `recipient.*` | `{name, contactNumber, requestMessage, customsCode, address{addressLine1, addressLine2, zipCode, countryCode}}` | — |
| `refundSummation.*` | `RefundSummation{ times, totalRefundAmount, rewardItemRefundAmount, shippingRefundAmount, donationRefundAmount, paymentCancelAmount, pointRefundAmount, couponRefundAmount, ... }` | 환불 집계 |
| `isWritableSatisfaction / isWrittenSatisfaction / isDeletedSatisfaction` | `Boolean` | 만족도 |
| `isPaymentCancelable` | `Boolean` | `whenHoldTo + 2일` 이전이면 true (계산식은 응답 DTO에서 처리) |

### MySQL 쿼리 (`BackingPaymentMapper.findMyFundingDetailById` + 하위 resultMap 조인)

메인 쿼리:
```sql
SELECT BP.BackingPaymentId, BP.CampaignId, C.WhenClose AS whenHoldTo, BP.UserId,
       BP.PayStatus, BP.Description, BP.RegDate,
       ? AS languageCode,
       BP.FundingAmount AS bill_fundingAmount,
       BP.BillingAmount AS bill_paymentAmount,
       BP.AddDonation AS bill_donationAmount,
       BP.ShippingCharge AS bill_shippingCharge,
       (BP.FundingAmount - BP.ShippingCharge - BP.AddDonation) AS bill_rewardItemAmount,
       BP.ContactNumber AS recipeint_contactNumber,
       BP.PresenteeName AS recipeint_name,
       BP.Memo          AS recipient_requestMessage,
       BP.CustomsCode   AS recipient_customsCode,
       BP.Address       AS address_AddressLine1,
       BP.AddressDetails AS address_AddressLine2,
       IFNULL(BP.CountryCode, 'KR') AS address_countryCode,
       BP.ZipCode       AS address_zipCode,
       BP.PayMemo1 AS paymentMethod_cardNumber,
       BP.PayMemo3 AS paymentMethod_walletName,
       IFNULL(CP.CouponAmount, 0) AS bill_couponAmount,
       IFNULL(P.PointAmount, 0)   AS bill_pointAmount,
       RPDB.DiscountAmount        AS bill_discountShippingCharge,
       IFNULL(RPDB.BillingAmount, BP.ShippingCharge) AS bill_billingShippingCharge,
       CASE WHEN RPDBC.DiscountAmount IS NULL THEN 'FALSE' ELSE 'TRUE' END AS bill_isUsedMemberShipCoupon,
       BP.Tid AS paymentMethod_tid,
       (SELECT COUNT(*) FROM BackingPaymentMultiple BPM
         WHERE BPM.BackingPaymentId = BP.BackingPaymentId) > 0 AS paymentMethod_isSplitPayment,
       IFNULL(RP.CardQuota, 0) AS paymentMethod_cardQuota,
       IFNULL(RP.CardInterest, FALSE) AS paymentMethod_isCardInterest,
       BP.PayBy AS paymentMethod_payBy,
       CASE WHEN EXISTS(
         SELECT 'O' FROM BackingPaymentMapping BPM
         JOIN Shipping S USE INDEX(IDX_Shipping__BackingId_DeliveryStatus) ON S.BackingId = BPM.BackingId
         WHERE BPM.BackingPaymentId = ? AND S.DeliveryStatus = 'DELIVERED') THEN TRUE ELSE FALSE END AS isAnyDelivered
FROM BackingPayment BP
JOIN Campaign C ON BP.CampaignId = C.CampaignId
LEFT JOIN BackingPaymentPoint P                        ON BP.BackingPaymentId = P.BackingPaymentId
LEFT JOIN BackingPaymentCoupon CP                      ON BP.BackingPaymentId = CP.BackingPaymentId
LEFT JOIN RewardPayment RP                             ON RP.BackingPaymentId = BP.BackingPaymentId
LEFT JOIN BackingPaymentDiscountBenefit RPDB           ON BP.BackingPaymentId = RPDB.BackingPaymentId AND RPDB.BenefitType = 'SHIPPING_FEE'
LEFT JOIN BackingPaymentDiscountBenefit RPDBC          ON BP.BackingPaymentId = RPDBC.BackingPaymentId AND RPDBC.BenefitType = 'COUPON'
WHERE BP.BackingPaymentId = ?
  AND BP.UserId = ?
```

MyBatis ResultMap `fundingDetailResult`가 추가로 다음을 자동 호출:
- **환불 집계** → `BackingPaymentRefundMapper.selectRefundSummation(backingPaymentId)`
- **리워드 목록** → `BackingRewardMapper.selectFundingReward(backingPaymentId, languageCode)` (리워드 + 다국어 `RewardLanguage`)
  - 각 리워드 행에 대해 추가:
    - 단일 옵션: `selectBackingRewardOption(backingId, languageCode)` → `BackingRewardOption` + `RewardOption` + `RewardOptionLanguage`
    - 세트: `selectBackingRewardSet` → `selectBackingRewardComposition` → 다국어 조인

**접근 테이블 (전체)**: `BackingPayment`, `Campaign`, `BackingPaymentPoint`, `BackingPaymentCoupon`, `RewardPayment`, `BackingPaymentDiscountBenefit`, `BackingPaymentMultiple`, `BackingPaymentMapping`, `Shipping`, `Backing`, `Reward`, `RewardLanguage`, `BackingRewardOption`, `RewardOption`, `RewardOptionLanguage`, `BackingRewardSet`, `BackingRewardComposition`, `BackingPaymentRefund`(환불 집계)

---

## 5. PUT `/api/supporters/my/fundings/{backingPaymentId}/shipping-address` — 배송지 변경

- **Method**: `SupporterController.modifyShippingAddress`
- **Auth**: 로그인 필수 (본인 펀딩만)

### Request Body — `ModifyShippingAddressRequest`

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `name` | `String` | ⬜ | 받는 사람 |
| `contactNumber` | `String` | ⬜ | 전화번호 |
| `requestMessage` | `String` | ⬜ | 요청 사항 |
| `customsCode` | `String` | ⬜ | 개인통관부호 |
| `address.addressLine1` | `String` | ⬜ `@Size(max=100)` | 기본 주소 |
| `address.addressLine2` | `String` | ⬜ `@Size(max=96)` | 상세 주소 |
| `address.zipCode` | `String` | ⬜ `@Size(max=16)` | 우편번호 |
| `address.countryCode` | `String` | ⬜ | 국가 코드 |

### Response
`ResponseWrapper<Void>` (200, 본문 없음)

### DB 호출

`ShippingAddressModifyUseCase.modifyShippingAddress(command)` — 이 레포에 전용 Gateway/Mapper 구현체가 **없음**. `BackingPayment` 테이블의 주소 컬럼 UPDATE가 일어날 것으로 보이나 실제 쿼리는 funding-core에 있음.

→ **funding-core 확인 필요**

---

## 6. PUT `/api/supporters/my/fundings/{backingPaymentId}/pay-by` — 결제 수단 변경

- **Method**: `SupporterController.modifyPayBy`

### Request Body — `ModifyPayByRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `billKey` | `String` | ⬜ | 예약 결제 billKey |

### Response
`ResponseWrapper<Void>`

### DB 호출

`PayByModifyUseCase.modify(command)` — 이 레포 내 전용 Gateway 없음. `BackingPayment.BillKey`/`PayBy` UPDATE가 일어날 것으로 보이지만 실제 쿼리는 funding-core.

→ **funding-core 확인 필요**

---

## 7. GET `/api/internal/supporters/my-encore` — 참여 내역 펀딩 앵콜 + 스토어 판매중 프로젝트

서포터가 과거에 참여한 프로젝트 중, 현재 앵콜 진행/오픈예정 또는 스토어에서 판매 중인 것을 찾는 API.

- **Method**: `SupporterInternalController.getMyEncoreProject`
- **Cache**: `@Cacheable(value="myPurchasedEncoreProject", key="#userId + '-' + #period + '-' + #searchDeath")`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ | 사용자 ID |
| `searchDeath` | `Integer` | ⬜ (1~3, 기본 1) | 앵콜 탐색 깊이 |
| `period` | `Integer` | ⬜ (30~180, 기본 180) | 과거 조회 일수 |

### Response — `List<MyEncore>`
`MyEncore` DTO 구조는 core/domain 소스 기준 (이 레포 payload 아님).

### 컨트롤러 코드 흐름
1. `searchDeath`, `period` 범위 검증 (Out of Range → `IllegalArgumentException`)
2. `supporterProxy.findMyPurchasedEncoreProjects(userId, period, searchDeath)` 호출 → `FundingListUseCase.findMyPurchasedEncoreProjects` (funding-core)

### MySQL 쿼리 (`SupporterQueryGatewayImpl` 관련 메서드들)

UseCase는 Gateway의 다음 메서드 조합을 호출할 수 있음:

**① 과거 N일 내 구매한 프로젝트** (`CampaignMapper.getPurchasedProjectListInPeriod`)
```sql
SELECT C.CampaignId
FROM BackingPayment BP
     INNER JOIN Campaign C ON C.CampaignId = BP.CampaignId
WHERE BP.UserId = ?
  AND BP.PayStatus IN ('C10', 'P10', 'Z11')
  AND BP.RegDate BETWEEN DATE_SUB(CURDATE(), INTERVAL ? DAY) AND CURDATE()
GROUP BY C.CampaignId
```

**② 앵콜(복제된 캠페인) 탐색 — depth만큼 반복** (`getEncoreCampaignsByCampaignId`)
```sql
SELECT CampaignId FROM Campaign
WHERE CopiedBy IN (?, ?, ...) AND IsDel = FALSE
```

**③ 앵콜 중 진행중 (`getEncoreOngoingCampaignsByCampaignId`)
```sql
SELECT CampaignId FROM Campaign
WHERE CampaignId IN (?, ?, ...)
  AND IsDel = FALSE AND IsOpen = TRUE
  AND DATE_ADD(WhenHoldTo, INTERVAL 1 DAY) - INTERVAL 1 SECOND >= NOW()
```

**④ 앵콜 중 오픈예정 (`getEncoreComingSoonCampaignsByCampaignId`)
```sql
SELECT CampaignId FROM RewardComingSoon
WHERE CampaignId IN (?, ?, ...) AND Status = 'IN_PROGRESS'
```

**⑤ 스토어 판매중 확인** — 각 projectId별로 `StoreClient.getStoreProject(projectId)` 외부 API 호출(반복)해 `Status == 'ON_SALE'` 확인

**접근 테이블/리소스**: `BackingPayment`, `Campaign`, `RewardComingSoon` + 외부 Store 서비스 (매 projectId별 1회 호출)

---

## 8. GET `/api/internal/supporters/my/fundings/unwritten-satisfaction/{userId}` — 만족도 미작성 건수

- **Method**: `SupporterInternalController.unWrittenSatisfaction`

### Response — `UnWrittenSatisfactionResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `unWrittenSatisfactionCount` | `int` | 미작성 건수 |

### 컨트롤러 코드 흐름 (3단계)

1. `supporterProxy.getDeliveredFundingProjectsByUserId(userId)` — 배송 완료된 펀딩 프로젝트 Set 조회
2. `satisfactionProxy.getCampaignIdsByUserId(SatisfactionQuery{campaignIds, userId})` — 만족도 작성된 프로젝트 조회 (satisfaction 도메인)
3. Set 차집합으로 미작성 건수 계산: `deliveredSet.removeAll(satisfactionSet).size()`

### MySQL 쿼리 (`SupporterQueryGatewayImpl.findDeliveredFundingProjectsByUserId`)

`FundingMapper.findDeliveredFundingProjectsByUserId`:
```sql
SELECT A.CampaignId
FROM wadiz_db.BackingPayment A
WHERE A.UserId = ?
  AND A.IsCanceled = FALSE
  AND A.BackingPaymentId NOT IN
    (SELECT SS1.BackingPaymentId FROM wadiz_db.RewardRefund SS1 WHERE SS1.UserId = ?)
  AND EXISTS (
    SELECT 'O'
    FROM wadiz_db.BackingPaymentMapping SS2
    INNER JOIN wadiz_db.Shipping SS3 USE INDEX (IDX_Shipping__BackingId_DeliveryStatus)
            ON SS3.BackingId = SS2.BackingId
    WHERE SS2.BackingPaymentId = A.BackingPaymentId
      AND SS3.DeliveryStatus = 'DELIVERED')
```

두 번째 SQL (`satisfactionProxy.getCampaignIdsByUserId`)은 **satisfaction 도메인**의 Gateway 호출 — 본 문서 범위 밖 (추후 `satisfaction.md` 예정).

**접근 테이블**: `BackingPayment`, `RewardRefund`, `BackingPaymentMapping`, `Shipping` + Satisfaction 도메인

---

## 9. GET `/api/internal/supporters/{userId}/shipping-qty` — 서포터 배송 상태별 건수

- **Method**: `SupporterInternalController.getSupporterShippingQty`
- **Cache**: `supporterProxy.getUserShippingQty`에 `@Cacheable`

### Request

| 위치 | 필드 | 타입 | 필수 | 설명 |
|---|---|---|:---:|---|
| path | `userId` | `Integer` | ✅ | — |
| query (@ModelAttribute) | `deliveryStatuses` | `List<DeliveryStatus>` | ✅ `@NotEmpty` | 조회할 배송 상태 목록 |

### Response — `SupporterShippingQtyResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `qtyByStatus` | `Map<DeliveryStatus, Integer>` | 상태별 건수 |

### DB 호출

`ShippingQtyUseCase.getUserShippingQty(query)` — 이 레포에 **Gateway 구현체 없음**. `Shipping`/`BackingPayment` 조인 집계가 일어날 것으로 보이나 실제 쿼리는 funding-core.

→ **funding-core 확인 필요**

---

## 10. GET `/api/fundings/qty` — 특정 사용자 펀딩 건수

- **Method**: `FundingController.getFundingQty`

### Request (Query, `@ModelAttribute FundingQtyRequest`)

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ `@NotNull` | 조회 대상 |
| `campaignId` | `Integer` | ⬜ | 특정 프로젝트 제한 |
| `within` | `Integer` | ⬜ | 지난 N일 제한 |

### Response
`ResponseWrapper<Integer>` — 건수

### MySQL 쿼리 (`FundingQueryGatewayImpl.count` → `FundingMapper.count`)

```sql
SELECT COUNT(*) AS Qty
FROM BackingPayment
WHERE UserId = ?
  /* within 제공 시 */
  AND RegDate BETWEEN DATE_SUB(NOW(), INTERVAL ? DAY) AND NOW()
  /* campaignId 제공 시 */
  AND CampaignId = ?
  /* includeCanceled == false 시 */
  AND IsCanceled = false
```

- `FundingQtyQuery`에 `includeCanceled` 필드가 있지만 이 엔드포인트는 값 미전달 → 기본 동작은 `null` (canceled 포함/제외 판단이 Query 기본값에 달림, funding-core 로직)

**접근 테이블**: `BackingPayment`

---

## 11. GET `/api/fundings/qty/my` — 로그인 유저 본인 펀딩 건수

- **Method**: `FundingController.getMyFundingQty`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `includeCanceled` | `Boolean` | ⬜ (default false) | 예약 취소 포함 여부 |

### Response
`ResponseWrapper<Integer>`

### MySQL 쿼리
10번과 동일 `FundingMapper.count`. `userId`는 `SecurityUtils.currentUserId()`로 세팅.

---

## 12. GET `/api/fundings/{campaignId}/is-asked-encore` — 앵콜 신청 여부

- **Method**: `FundingController.isAskedEncore`
- **Auth**: 비로그인 시 `false` 반환 (`SecurityUtils.isLogin()` 체크)

### Response
`ResponseWrapper<Boolean>`

### DB 호출

`FundingProxy.isAskedEncore(CampaignAskForEncoreWhetherQuery{userId, campaignId})` — 이 레포에 직접 구현체 없음. `CampaignAskForEncore` 테이블 존재 여부 조회로 보이지만 funding-core 확인 필요.

---

## 13. POST `/api/internal/fundings/qtys/by-user` — 유저별 펀딩 건수 목록

- **Method**: `FundingInternalController.getAllFundingQtyByUser`

### Request Body — `FundingQtyListRequest`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userIds` | `Set<Integer>` | ✅ `@NotEmpty @Size(max=1000)` | 사용자 ID Set |

### Response — `List<FundingQtyListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `userId` | `Integer` | — |
| `qty` | `Integer` | 펀딩 건수 |

> 건수 0인 유저는 응답에 포함되지 않을 수 있음 (Swagger description)

### MySQL 쿼리 (`FundingMapper.countAllGroupByUser`)

```sql
SELECT UserId, COUNT(*) AS Qty
FROM BackingPayment
WHERE UserId IN (?, ?, ...)
  AND IsCanceled = false
GROUP BY UserId
```

**접근 테이블**: `BackingPayment`

---

## 14. POST `/api/internal/fundings/{campaignId}/qtys/by-user` — 프로젝트별 유저 펀딩 참여/비공개 건수

- **Method**: `FundingInternalController.getCampaignAllFundingQtyByUser`

### Request (Path + Body)
| 위치 | 필드 | 타입 | 필수 | 설명 |
|---|---|---|:---:|---|
| path | `campaignId` | `Integer` | ✅ | — |
| body | `userIds` | `Set<Integer>` | ✅ `@NotEmpty @Size(max=1000)` | — |

### Response — `List<FundingParticipationListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `userId` | `Integer` | — |
| `publicQty` | `Integer` | 이름 공개 건수 |
| `hiddenQty` | `Integer` | 이름 비공개 건수 |

### MySQL 쿼리 (`FundingMapper.sumAllGroupByUser`)

```sql
SELECT BP.UserId,
       SUM(BP.DontShowName)  AS HiddenQty,
       SUM(!BP.DontShowName) AS PublicQty
FROM BackingPayment BP
     INNER JOIN BackingPaymentMapping BPM ON BP.BackingPaymentId = BPM.BackingPaymentId
     INNER JOIN Backing B                 ON BPM.BackingId = B.BackingId
     LEFT JOIN RewardRefund RR            ON B.BackingId = RR.BackingId
WHERE BP.UserId IN (?, ?, ...)
  AND BP.CampaignId = ?
  AND BP.IsCanceled = FALSE
  AND BP.PayStatus IN ('A10', 'B10', 'C10', 'Z11', 'D11', 'P10')
  AND (RR.Status IS NULL OR RR.Status != 'REFUNDED')
GROUP BY BP.UserId
```

- **주의**: 실제 Backing 건수 기준(리워드 단위) 집계. 결제 1건이 여러 리워드면 각각 카운트됨.

**접근 테이블**: `BackingPayment`, `BackingPaymentMapping`, `Backing`, `RewardRefund`

---

## 15. GET `/api/internal/fundings/qty` — 특정 유저 전체 펀딩 건수

- **Method**: `FundingInternalController.getUserFundingQty`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ | — |
| `includeCanceled` | `Boolean` | ⬜ (default **true**) | — |

### Response — `FundingQtyResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `qty` | `Integer` | 건수 |

### MySQL 쿼리
`FundingMapper.count` (10번과 동일). `includeCanceled=true` 기본값이므로 취소 건 포함 집계.

---

## 16. GET `/api/refund/my/{campaignId}/detail` — 나의 펀딩금 반환 상세

- **Method**: `RefundController.getRewardRefund`
- **Auth**: 비로그인 시 `{isAllRefund: false}` 즉시 반환

### Response — `RefundResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `isAllRefund` | `Boolean` | 모든 리워드 환불 완료 여부 |

### 컨트롤러 / Gateway 코드 흐름

`RewardRefundQueryGatewayImpl.getRewardRefundDetail`는 두 카운트를 비교:

```java
int fundingRewardItemQty = rewardRefundMapper.getFundingRewardItemQty(query);
int rewardRefundQty      = rewardRefundMapper.getRewardRefundQty(query);
return RewardRefundDetailResult.builder()
    .isAllRefund(fundingRewardItemQty <= rewardRefundQty)
    .build();
```

### MySQL 쿼리 (2회)

**① 펀딩한 리워드 아이템 수** (`RewardRefundMapper.getFundingRewardItemQty`)
```sql
SELECT COUNT(*) AS FundingRewardItemQty
FROM BackingPayment BP
     LEFT JOIN BackingPaymentMapping BM ON BM.BackingPaymentId = BP.BackingPaymentId
     LEFT JOIN Backing BK               ON BK.BackingId = BM.BackingId
     LEFT JOIN Reward R                 ON R.RewardId = BK.RewardId
     LEFT OUTER JOIN CampaignRewardDelay CD ON R.CampaignId = CD.CampaignId
WHERE BP.BackingPaymentId IN (
  SELECT BP.BackingPaymentId FROM BackingPayment BP
  WHERE BP.CampaignId = ?
    AND BP.UserId = ?
    AND BP.PayStatus IN ('A10', 'B10', 'C10', 'Z11', 'D11', 'P10')
    AND BP.IsCanceled = FALSE)
ORDER BY BK.BackingId
```

**② 환불된 리워드 수** (`getRewardRefundQty`)
```sql
SELECT COUNT(*)
FROM RewardRefund RR
     INNER JOIN BackingPayment BP ON RR.BackingPaymentId = BP.BackingPaymentId
WHERE RR.CampaignId = ?
  AND RR.UserId = ?
  AND RR.Status = 'REFUNDED'
```

`isAllRefund = (fundingRewardItemQty <= rewardRefundQty)` — 펀딩 건보다 환불이 같거나 많으면 전액 환불로 판정.

**접근 테이블**: `BackingPayment`, `BackingPaymentMapping`, `Backing`, `Reward`, `CampaignRewardDelay`, `RewardRefund`

---

## 17. 참고 — 이 문서의 Gateway / Mapper 맵

### Gateway 구현체 (이 레포 `adapter/infrastructure`)

| 구현체 | 노출 메서드 → Mapper |
|---|---|
| `SupporterQueryGatewayImpl` | `recentShippingAddressSearch` → `BackingPaymentMapper`, `fundingListSearch` → `FundingMapper + GlobalProjectMapper + CampaignCategory`, `findDeliveredFundingProjectsByUserId` → `FundingMapper`, `purchasedProjectListInPeriod` → `CampaignMapper`, `findEncoreProjects/OngoingProjects/ComingSoonProjects` → `CampaignMapper`, `findOnSaleProjects` → 외부 Store API |
| `FundingQueryGatewayImpl` | `count`, `countAllGroupByUser`, `sumAllGroupByUser`, `countByCampaignIdAndIsCanceledFalse`, `findFundingStatusByCampaignId`, `countByMakerAndPeriod` → `FundingMapper` |
| `RewardRefundQueryGatewayImpl` | `getFundingRewardItemQty`, `getRewardRefundQty` → `RewardRefundMapper` |

### UseCase 중 이 레포에 Gateway 구현체가 **없는** 것
- `RecentPayByUseCase` (recent-pay-by)
- `ShippingAddressModifyUseCase` (배송지 변경)
- `PayByModifyUseCase` (결제 수단 변경)
- `ShippingQtyUseCase` (shipping-qty)
- `CampaignAskForEncoreWhetherUseCase` (is-asked-encore)
- `FundingDetailUseCase`의 `refundSummation` 관련 (`BackingPaymentRefundMapper`는 이 레포에 존재 — 추후 별도 문서에서 커버)

### Mapper XML 파일 (이 레포)
- `BackingPaymentMapper.xml` — 최근 배송지, 펀딩 상세(findMyFundingDetailById), 앙증맞은 resultMap으로 reward/refund 조인
- `FundingMapper.xml` — 건수·목록 집계, 배송 완료 프로젝트 리스트
- `BackingRewardMapper.xml` — 리워드/옵션/세트 다국어 조회
- `RewardRefundMapper.xml` — 환불 카운트
- `CampaignMapper.xml` — 앵콜·구매 이력 조회
- `GlobalProjectMapper.xml` — 프로젝트 메타(다국어)

### 접근 테이블 합계

`BackingPayment`, `BackingPaymentMapping`, `BackingPaymentPoint`, `BackingPaymentCoupon`, `BackingPaymentDiscountBenefit`, `BackingPaymentMultiple`, `Backing`, `BackingRewardOption`, `BackingRewardSet`, `BackingRewardComposition`, `Reward`, `RewardOption`, `RewardPayment`, `RewardLanguage`, `RewardOptionLanguage`, `RewardRefund`, `CampaignRewardDelay`, `Campaign`, `CampaignLanguage`, `CampaignCategoryMapping`, `CampaignPause`, `RewardComingSoon`, `Shipping`, `CodeValue` + 외부 Store API, 외부 카테고리 검색 API
