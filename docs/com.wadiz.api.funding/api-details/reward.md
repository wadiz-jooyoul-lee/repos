# Reward 계열 API 상세 스펙

리워드·이벤트·상품정보고시·환불정책·시간제한·변경이력 관련 **37개 엔드포인트**.

- **대상 컨트롤러**:
  - `RewardItemController` (`/api/reward-items`) — 1개
  - `RewardPolicyController` (`/api/reward-policy`) — 1개
  - `RewardRefundPolicyController` (`/api/refund-policy`) — 1개
  - `ProductInfoNoticeController` (`/api/product-info-notice`) — 3개
  - `RewardAdminController` (`/api/admin/rewards`) — 1개
  - `RewardLimitedTimeAdminController` (`/api/admin/rewards`) — 5개
  - `EventController` (`/api/event`) — 8개
  - `EventAdminController` (`/api/admin/events`) — 11개
  - `RewardChangeLogInternalController` (`/api/internal/reward-change-logs`) — 5개
  - `GlobalProjectRewardController` (`/api/global/projects/{projectNo}/rewards`) — 2개

- **저장소**:
  - **MySQL**: `Reward`, `RewardLanguage`, `RewardOption`, `RewardOptionSetting`, `RewardLimitedTimeOffer`, `RewardLimitedTimeOfferHistory`, `RewardRefundPolicy`, `CampaignRewardDelay`, `RewardEvent`, `RewardEventBenefitMapping`, `RewardEventParticipant`, `RewardEventRandomBenefitMapping`, `RewardProductContent`, `RewardProductItem`, `RewardProductCategory`, `RewardShippingCountry`
  - **MongoDB**: `RewardChangeLog` (**본 레포에서 관찰된 유일한 MongoDB 사용처**)
  - **외부 API**: `StoreClient` (이벤트 주문 수 조회), `MembershipApiClient` (멤버십 대상 유저 조회)

> **기록 범위**: 이 레포의 Controller / Proxy / Gateway / Mapper XML 에서 직접 관찰 가능한 호출만 기록. UseCase 구현체(`RewardEventUseCase`, `RewardLimitedTimeUseCase` 등)는 외부 jar(`funding-core`)에 있어 내부 호출 순서는 확인 불가.

---

## 1. GET `/api/reward-items/campaigns/{campaignId}` — 프로젝트 리워드 조회

- **Method**: `RewardItemController.getCampaignRewardItems`

### Response — `List<RewardItemResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `rewardId` | `int` | — |
| `amount` | `int` | 리워드 가격 |
| `name / contents` | `String` | 이름 / 설명 |
| `limitQty` | `int` | 최대 개수 (0이면 무제한) |
| `whenOffering` | `LocalDate` | 배송 예정 일자 |
| `requireAddress` | `boolean` | 배송 필요 여부 |
| `shippingCharge` | `int` | 배송비 |
| `remainQty / soldQty` | `int` | 남은/판매 수량 |
| `isDeleted` | `Boolean` | 삭제 여부 |

### MySQL 쿼리 (`RewardItemQueryGatewayImpl.getRewardItems` — 2단 호출)

**① 리워드 목록** (`RewardItemMapper.getRewardItems`)
```sql
SELECT R.RewardId, R.Amount,
       IFNULL(KRL.Summary, R.Summary) AS Name,
       IFNULL(KRL.Text, R.Text) AS Contents,
       R.LimitCount AS LimitQty,
       DATE_FORMAT(R.WhenOffering, '%Y-%m-%d') AS WhenOffering,
       R.RequireAddress, R.ShippingCharge,
       CASE WHEN R.LimitCount = 0 THEN 1
            ELSE CASE WHEN (R.LimitCount - IFNULL(BP2.SoldQty, 0)) < 0 THEN 0
                      ELSE (R.LimitCount - IFNULL(BP2.SoldQty, 0)) END END AS RemainQty,
       IFNULL(BP2.SoldQty, 0) AS SoldQty,
       R.IsDeleted,
       CASE WHEN DATE_ADD(C.WhenOpen, INTERVAL RLTO.LimitedHours HOUR) IS NOT NULL
            THEN CASE WHEN DATE_ADD(C.WhenOpen, INTERVAL RLTO.LimitedHours HOUR) < NOW() THEN TRUE ELSE FALSE END
            ELSE FALSE END AS IsCloseEarly
FROM Campaign C
     INNER JOIN Reward R ON C.CampaignId = R.CampaignId AND R.IsDeleted = FALSE
     INNER JOIN RewardLanguage KRL ON R.RewardId = KRL.RewardId AND KRL.LanguageCode = 'ko'
     LEFT JOIN RewardShippingCountry SC ON R.RewardId = SC.RewardId
     LEFT OUTER JOIN (
         SELECT RewardId, COUNT(*) AS CNT, SUM(B.BackedAmount) AS BackedAmount, SUM(B.Qty) AS SoldQty
         FROM BackingPayment BP
              INNER JOIN BackingPaymentMapping BPM ON BP.BackingPaymentId = BPM.BackingPaymentId
              INNER JOIN Backing B ON BPM.BackingId = B.BackingId
         WHERE BP.CampaignId = ? AND IsCanceled = FALSE
         GROUP BY RewardId) BP2 ON R.RewardId = BP2.RewardId
     LEFT JOIN RewardLimitedTimeOffer RLTO ON R.RewardId = RLTO.RewardId
WHERE R.CampaignId = ?
  AND R.Amount != 0
  AND (SC.CountryCode = 'KR' OR SC.CountryCode IS NULL)
ORDER BY R.DisplayOrder ASC
```

**② 시간제한 조기마감 여부** (`RewardLimitedTimeOfferMapper.isLimitedTimeOut`) — 동일 집계로 `isCloseEarly` 맵 구성 후 `setRemainQty(isCloseEarly ? 0 : remainQty)`

**접근 테이블**: `Campaign`, `Reward`, `RewardLanguage`, `RewardShippingCountry`, `BackingPayment`, `BackingPaymentMapping`, `Backing`, `RewardLimitedTimeOffer`

---

## 2. GET `/api/reward-policy/campaigns/{campaignId}` — 리워드 AS 정책

- **Method**: `RewardPolicyController.getCampaignRewardPolicy`

### Response — `RewardAsPolicyResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `asPolicy` | `String` | AS 정책 텍스트 |
| `updated` | `LocalDateTime` | 최근 수정일시 |

### DB 호출 (`RewardPolicyGatewayImpl.getRewardPolicy`)

`CampaignRewardDelayRepository.getById(campaignId)` (Spring Data JDBC):
```sql
SELECT * FROM CampaignRewardDelay WHERE CampaignId = ?
```
없으면 `expectedDelayDay=0`, `id=0`으로 기본 객체 반환.

**접근 테이블**: `CampaignRewardDelay`

---

## 3. GET `/api/refund-policy/campaigns/{campaignId}/detail` — 환불 정책 상세

- **Method**: `RewardRefundPolicyController.getCampaignRewardPolicy`

### Response — `RewardRefundPolicyResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `returnExchangePolicy` | `String` | AS 정책 |
| `updated` | `LocalDateTime` | 수정일 |
| `delayGuarantee` | `String` | 지연 보상 |
| `noRefundCase` | `String` | 환불 불가 케이스 |
| `isTarget` | `boolean` | 펀딩금 반환 정책 적용 여부 |
| `version` | `Integer` | 정책 버전 |
| `defectTypeRefundApplicableDays` | `Integer` | 하자 반환 신청 기간(버전별) |
| `expectedDelayOfferingDates[]` | `List<ExpectedDelayOfferingDate>` | — |
| `whenOfferingList` | `List<String>` | — |

### DB 호출 (`RewardRefundPolicyGatewayImpl.getRewardRefundPolicy`)

`RewardRefundPolicyRepository.getById(campaignId)` — Spring Data JDBC:
```sql
SELECT * FROM RewardRefundPolicy WHERE CampaignId = ?
```

> UseCase 내부에서 `CampaignRewardDelay`, `Reward` 추가 조회로 delayGuarantee / expectedDelayOfferingDates / whenOfferingList 를 채울 가능성 (funding-core 확인 필요).

**접근 테이블**: `RewardRefundPolicy` (+ UseCase 추가 조회 가능성)

---

## 4. GET `/api/product-info-notice/campaigns/{campaignId}` — 프로젝트 상품정보제공고시 목록

- **Method**: `ProductInfoNoticeController.campaignProductInfoNoticeList`

### Response — `List<CampaignProductInfoNoticeListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `productCode / codeName` | `String` | 상품 카테고리 |
| `items[].itemNo / itemName / itemValue` | Integer/String | 항목(itemValue 비어있으면 응답에서 필터링) |

### MySQL 쿼리 (`RewardProductMapper.rewardProductContentByCampaignId`)

```sql
SELECT RPC.CampaignId, RPC.OrderNo, RPI.ProductCode,
       RPCL.Name AS CodeName,
       RPC.ItemNo, RPI.ItemName, RPC.ItemValue
FROM RewardProductContent RPC
     INNER JOIN RewardProductItem RPI
             ON RPI.ItemNo = RPC.ItemNo AND RPI.isUse = TRUE
     LEFT JOIN RewardProductCategory RPCT
            ON RPI.ProductCode = RPCT.RewardProductCategoryCode AND RPCT.IsDeleted = FALSE
     LEFT JOIN RewardProductCategoryLanguage RPCL
            ON RPCT.RewardProductCategoryCode = RPCL.RewardProductCategoryCode AND RPCL.LanguageCode = 'ko'
WHERE RPC.CampaignId = ?
  AND RPC.isDeleted = FALSE
ORDER BY RPC.CampaignId, RPC.OrderNo, RPI.ProductCode, RPI.ItemOrder
```

**접근 테이블**: `RewardProductContent`, `RewardProductItem`, `RewardProductCategory`, `RewardProductCategoryLanguage`

---

## 5. GET `/api/product-info-notice/categories` — 상품정보제공고시 카테고리

- **Method**: `ProductInfoNoticeController.productInfoNoticeCategoryList`

### Response — `List<ProductInfoNoticeCategoryListResponse>` (상품 코드 + 항목 설명)

### MySQL 쿼리 (`RewardProductMapper.rewardProductCategory`)

```sql
SELECT RPI.ProductCode, RPCL.Name AS CodeName,
       RPI.ItemNo, RPI.ItemName, RPI.ItemDescription
FROM RewardProductItem RPI
     LEFT JOIN RewardProductCategory RPCT
            ON RPI.ProductCode = RPCT.RewardProductCategoryCode AND RPCT.IsDeleted = FALSE
     LEFT JOIN RewardProductCategoryLanguage RPCL
            ON RPCT.RewardProductCategoryCode = RPCL.RewardProductCategoryCode AND RPCL.LanguageCode = 'ko'
WHERE RPI.isUse = true
ORDER BY RPCT.OrderNo, RPI.ItemOrder
```

---

## 6. GET `/api/product-info-notice/campaigns/{campaignId}/detail` — 상품정보제공고시 상세

- **Method**: `ProductInfoNoticeController.campaignProductInfoNotice`

### Response — `List<CampaignProductInfoNoticeDetailsResponse>`
(`orderNo`, `productCode`, `productName`, `itemNo`, `itemName`, `itemValue`, `itemDescription`)

### MySQL 쿼리 (`RewardProductMapper.rewardProductContentItemByCampaignId`)

```sql
SELECT RPI.ProductCode, RPCL.Name AS ProductName,
       PC.OrderNo, PC.ItemNo, RPI.ItemName, RPI.ItemDescription,
       IFNULL(KPCL.ItemValue, PC.ItemValue) AS ItemValue
FROM RewardProductContent PC
     LEFT JOIN RewardProductContentLanguage KPCL ON PC.Seq = KPCL.Seq AND KPCL.LanguageCode = 'ko'
     LEFT JOIN RewardProductItem RPI ON PC.ItemNo = RPI.ItemNo AND RPI.isUse = TRUE
     LEFT JOIN RewardProductCategory RPCT
            ON RPI.ProductCode = RPCT.RewardProductCategoryCode AND RPCT.IsDeleted = FALSE
     LEFT JOIN RewardProductCategoryLanguage RPCL
            ON RPCT.RewardProductCategoryCode = RPCL.RewardProductCategoryCode AND RPCL.LanguageCode = 'ko'
WHERE PC.CampaignId = ? AND PC.isDeleted = FALSE
ORDER BY PC.OrderNo, RPI.ItemOrder
```

---

## 7. GET `/api/admin/rewards/campaigns/{campaignId}` — 리워드 목록 조회 (Admin)

- **Method**: `RewardAdminController.getRewards`
- **Security**: `@PreAuthorize("isAdmin()")`

### Response — `List<RewardListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `rewardId / campaignId` | `Integer` | — |
| `amount` | `Integer` | 금액 |
| `summary` | `String` | 리워드명 |
| `whenOffering` | `LocalDateTime` | 발송 시작 일 |
| `offeringTime` | enum `OfferingTime` | 발송 시기 |
| `shippingCharge` | `Integer` | 배송비 |

### MySQL 쿼리 (`RewardProxy.getRewardsByCampaignId` → `RewardMapper.search`)

```sql
SELECT RewardId, CampaignId, Amount, Summary, Text, LimitCount,
       IsOption, OptionType, OptionDetail, WhenOffering, OfferingTime,
       IsMoney, RequireAddress, IsTaxFree, DisplayOrder, IsAuthen,
       SummaryGlobal, TextGlobal, AmountGlobal,
       ShippingCharge, ShippingChargeGlobal, ShippingChargeFree,
       IsZero, IsDeleted, LimitType
FROM Reward R
WHERE 1=1
  AND R.CampaignId = ?
  -- isDeleted 지정 시 AND R.IsDeleted = ?
-- + 페이징/정렬 (Pages.unpaged() 이므로 실제로는 LIMIT 없음)
```

**접근 테이블**: `Reward`

---

## 8~12. `/api/admin/rewards/...` — 리워드 시간 제한 관리

### 8. GET `/limit-time/campaigns/{campaignId}` — 시간 제한 현황

**Response**: `List<RewardLimitedTimeOfferResponse>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `rewardId` | `Integer` | — |
| `limitedHours` | `Integer` | 제한 시간 |
| `registeredBy` | `Integer` | 등록자 userId |
| `registeredAt` | `LocalDateTime` | 등록일시 |

SQL (`RewardLimitedTimeOfferMapper.search`):
```sql
SELECT RLTO.RewardId, RLTO.LimitedHours, RLTO.RegisteredAt, RLTO.RegisteredBy
FROM Reward R
     INNER JOIN RewardLimitedTimeOffer RLTO ON R.RewardId = RLTO.RewardId
WHERE R.CampaignId = ?
```

### 9. GET `/limit-time/history/campaigns/{campaignId}` — 히스토리

**Response**: `List<RewardLimitedTimeOfferHistoryResponse>` (Type, 등록자 닉네임 포함)

SQL (`searchHistory`):
```sql
SELECT RLTH.RewardId, R.CampaignId, RLTH.Type, RLTH.LimitedHours,
       RLTH.RegisteredAt, RLTH.RegisteredBy,
       UP.NickName AS registerName
FROM Reward R
     INNER JOIN RewardLimitedTimeOfferHistory RLTH ON R.RewardId = RLTH.RewardId
     LEFT JOIN UserProfile UP ON RLTH.RegisteredBy = UP.UserId
WHERE R.CampaignId = ?
```

### 10. POST `/{rewardId}/limit-time` — 시간 제한 적용

**Request** (`RewardLimitedTimePostRequest`):
| 필드 | 타입 | 설명 |
|---|---|---|
| `limitHours` | `Integer` | 제한 시간 |

**Response**: 204 No Content

**DB 호출 (`RewardLimitedTimeOfferGatewayImpl.create`)**:
- `RewardLimitedTimeOfferRepository.save(Insert{id=rewardId, limitedHours})` — Spring Data JDBC INSERT into `RewardLimitedTimeOffer`
- UseCase가 추가로 `createHistory` 호출 가능 → `RewardLimitedTimeOfferHistoryRepository.save(Insert{type, rewardId, limitedHours})`

### 11. PUT `/{rewardId}/limit-time` — 시간 제한 수정

**Request** (`RewardLimitedTimeModifyRequest`): `limitHours`

**DB 호출**: `RewardLimitedTimeOfferRepository.save(Update{id, limitedHours, registeredBy, registeredAt})`

### 12. DELETE `/{rewardId}/limit-time` — 시간 제한 해제

**DB 호출**: `rewardLimitedTimeOfferRepository.deleteById(rewardId)`:
```sql
DELETE FROM RewardLimitedTimeOffer WHERE RewardId = ?
```

**접근 테이블**: `RewardLimitedTimeOffer`, `RewardLimitedTimeOfferHistory`, `Reward`, `UserProfile`

---

## 13. POST `/api/event/{eventKeyword}/entry` — 이벤트 응모 참여

- **Method**: `EventController.participateEntry`
- **Auth**: 로그인 필수 (`SecurityUtils.currentUserId()`)

### Path / Response
- `eventKeyword`: String (path)
- Response: `RewardEventEntryResponse`

### 컨트롤러 코드 흐름
`RewardEventParticipateCommand{userId, keyword, type=ENTRY}` → `rewardEventProxy.participate(command)` → `RewardEventUseCase.participate` (funding-core)

### DB 호출 (`RewardEventGatewayImpl` 관찰)

**① 이벤트 조회** — `RewardEventRepository.findByKeyword(keyword)` (Spring Data JDBC 파생):
```sql
SELECT * FROM RewardEvent WHERE Keyword = ?
```

**② 참여자 기록** — `RewardEventParticipantRepository.save(Insert{userId, eventNo, times, benefitKey})`:
```sql
INSERT INTO RewardEventParticipant (UserId, EventNo, Times, BenefitKey, ...) VALUES (?, ?, ?, ?, ...)
```

**③ 최근 참여자** — `getTopByUserIdAndEventNoOrderByTimesDesc(userId, eventNo)`:
```sql
SELECT * FROM RewardEventParticipant
WHERE UserId = ? AND EventNo = ?
ORDER BY Times DESC
LIMIT 1
```

**접근 테이블**: `RewardEvent`, `RewardEventParticipant`

---

## 14. POST `/api/event/{eventKeyword}/benefit` — 이벤트 베네핏 참여

`participate(ENTRY)` 와 동일 흐름, `type=BENEFIT` 차이.

### DB 호출 추가
**베네핏 매핑 조회** — `RewardEventBenefitMappingRepository.findAllById_EventNoAndApplyFromLessThanEqualAndApplyToGreaterThanEqual(eventNo, now, now)` (Spring Data JDBC 파생):
```sql
SELECT * FROM RewardEventBenefitMapping
WHERE EventNo = ?
  AND ApplyFrom <= ?
  AND ApplyTo >= ?
```

### 외부 API
- `StoreClient.getUserOrdersQty(userId)` — 멤버십/이벤트 조건 판정용 스토어 주문 수
- `MembershipApiClient` — 멤버십 대상 사용자 확인

---

## 15. POST `/api/event/{eventKeyword}/random-benefit` — 랜덤 베네핏

`type=RANDOM_BENEFIT`. 추가로 랜덤 베네핏 매핑 조회:

`RewardEventRandomBenefitMappingRepository.findAllById_EventNo(eventNo)`:
```sql
SELECT * FROM RewardEventRandomBenefitMapping WHERE EventNo = ?
```

**접근 테이블**: `RewardEventRandomBenefitMapping` (추가)

---

## 16. GET `/api/event/{eventKeyword}/participant` — 유저 이벤트 참여 정보

- **Method**: `EventController.getParticipantDetail`

**Response**: `RewardEventParticipantDetailResponse.EventDetail`

### DB 호출
이벤트 조회 + `RewardEventParticipantRepository.findBy...`(funding-core 구체 쿼리 미확인)

---

## 17. GET `/api/event/participant` — 유저 이벤트 참여 정보 목록

- **Query**: `eventKeywords` (List<String>)

여러 이벤트 키워드에 대해 일괄 조회.

---

## 18. GET `/api/event/{eventKeyword}/participation-aggregation` — 참여 집계

**Response**: `RewardEventParticipationAggregationResponse`

---

## 19. GET `/api/event/{eventKeyword}` — 이벤트 정보 조회

**Response**: `RewardEventDetailResponse`

`rewardEventProxy.getEventDetail(keyword)` → `findByKeyword` SQL 위와 동일.

---

## 20. GET `/api/event/benefits` — 이벤트 보상 정보

- **Query**: `eventKeyword`
- **Locale**: `LocaleContextHolder.getLocale().getLanguage()` — 언어별 응답

**Response**: `RewardEventBenefitListResponse`

---

## 21. GET `/api/admin/events` — 이벤트 목록 (Admin, 페이징)

- **Method**: `EventAdminController.eventList`
- **Request** (`RewardEventListRequest` @ModelAttribute) + `Pages`

**Response**: `PageResult<RewardEventListResponse>`

### DB 호출
`RewardEventQueryGatewayImpl` 에서 복합 쿼리 (이 레포 구현체 확인 가능, 상세 SQL 은 `RewardEventMapper.xml` 참조 필요)

---

## 22. DELETE `/api/admin/events/{eventNo}` — 이벤트 비활성화

### DB 호출
UseCase에서 `RewardEventRepository.findById` + 비활성화 플래그 UPDATE (구체 SQL funding-core).

---

## 23. POST `/api/admin/events` — 이벤트 등록

### Request — `CreateRewardEventRequest`
(이벤트 키워드, 기간, 타입, 설명 등)

**Response**: `CreateRewardEventResponse{eventNo}`

### DB 호출
`RewardEventRepository.save(Insert)`

---

## 24. GET `/api/admin/events/{eventNo}` — 이벤트 단건 조회

`RewardEventRepository.findById(eventNo)`

---

## 25. PUT `/api/admin/events/{eventNo}` — 이벤트 수정

**Request**: `ModifyRewardEventRequest`

`RewardEventRepository.save(Update)`

---

## 26~31. Admin — 고정/랜덤 보상 이벤트 CRUD

| # | Method | Path | 설명 |
|---|---|---|---|
| 26 | POST | `/fixed-benefit` | 고정 보상형 이벤트 등록 |
| 27 | GET | `/fixed-benefit/{eventNo}` | 조회 |
| 28 | PUT | `/fixed-benefit/{eventNo}` | 수정 |
| 29 | POST | `/random-benefit` | 랜덤 보상형 이벤트 등록 |
| 30 | GET | `/random-benefit/{eventNo}` | 조회 |
| 31 | PUT | `/random-benefit/{eventNo}` | 수정 |

**Request 검증**: `FixedBenefitRequestValidator`, `RandomBenefitRequestValidator` 적용 (`@Valid`).

### DB 호출
- 등록: `RewardEventRepository.save` + `RewardEventBenefitMappingRepository.save` (batch) + (랜덤은 `RewardEventRandomBenefitMappingRepository`)
- 조회: `findById` + `findAllById_EventNo` (매핑)
- 수정: `save(Update)` — 매핑 재구성

**접근 테이블**: `RewardEvent`, `RewardEventBenefitMapping`, `RewardEventRandomBenefitMapping`

---

## 32. POST `/api/internal/reward-change-logs` — 리워드 변경 이력 저장

- **Method**: `RewardChangeLogInternalController.save`

### Request — `RewardChangeLogRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId / rewardId` | `Integer` | 식별자 |
| `rewardName` | `String` | 리워드명 |
| `beforeData / afterData` | `String` | 변경 전/후 (JSON 직렬화된 문자열) |
| `registerUserId` | `Integer` | — |

컨트롤러에서 `RewardChangeLog.determineChangeType(before, after)`로 변경 타입 산출(CREATED/MODIFIED/DELETED) 후 저장.

### DB 호출 — **MongoDB**

`RewardChangeLogGatewayImpl.save` (`@Async`):
```java
rewardChangeLogMongoRepository.save(RewardChangeLogDto)
```

- MongoDB collection 이름은 `RewardChangeLogDto`의 `@Document` 설정에 따름 (구체 ID는 MongoDB가 자동 생성).
- **본 레포에서 발견된 유일한 MongoDB 저장소**. 비동기(`@Async`) 실패 시 로그만 남기고 무시.

---

## 33. GET `/api/internal/reward-change-logs/campaigns/{campaignId}/rewards/{rewardId}` — 이력 페이징 조회

| Query | 타입 | 기본 | 설명 |
|---|---|---|---|
| `sort` | `String` | `DESC` | ASC/DESC |
| `page / size` | `int` | 0 / 5 | — |

**Response**: `PageResult<RewardChangeLogResponse>`

### MongoDB 호출
`RewardChangeLogMongoRepository.findByCampaignIdAndRewardId(campaignId, rewardId, PageRequest.of(page, size, sort))`

---

## 34. GET `.../rewards/{rewardId}/summaries` — 이력 요약 목록

**Response**: `List<RewardChangeLogResponse>` (id, rewardName, changeType, registerUserId, registered만)

`RewardChangeLogMongoRepository.findByCampaignIdAndRewardId(campaignId, rewardId, Sort)`

---

## 35. GET `.../campaigns/{campaignId}/summaries` — 캠페인별 이력 요약

`RewardChangeLogMongoRepository.findByCampaignId(campaignId, Sort)`

---

## 36. GET `/api/internal/reward-change-logs/{id}` — 이력 상세

`RewardChangeLogMongoRepository.findById(id)` — 없으면 `null` 반환.

---

## 37. GET `/api/global/projects/{projectNo}/rewards/by-country` — 국가별 리워드 목록

- **Method**: `GlobalProjectRewardController.getAllRewardByCountry`
- **Security**: `@PreAuthorize("isOpenedOrComingSoonPosting(#projectNo) or isMaker(#projectNo) or isAdmin()")`
- **Query**: `country` (필수), `isPreview` (선택)

### Response — `GlobalProjectRewardResponse.RewardList`
(rewards: List<Item> — 각 리워드의 id, name, description, limitQty, limitedHours, amount, whenOffering, offeringTime, limitType, rewardType, isAddressRequired, countryCode, shippingCharge, compositionOrSingleOptions[])

### MySQL 쿼리 (`GlobalProjectRewardMapper.findAllByCountry`)

**다국어 3단 fallback + 옵션/컴포지션 조인** (SET 리워드는 RewardComposition 단위, SINGLE은 RewardOption 단위):
```sql
SELECT A.RewardId,
       IFNULL(SRL.Summary, IFNULL(DRL.Summary, WRL.Summary)) AS name,
       IFNULL(SRL.Text, IFNULL(DRL.Text, WRL.Text)) AS description,
       R.LimitCount AS limitQty, LTO.LimitedHours, R.Amount,
       R.WhenOffering, R.OfferingTime,
       IF(R.RewardType = 'SET', RC.LimitType, IFNULL(R.LimitType, 'REWARD')) AS limitType,
       R.RewardType, R.RequireAddress AS isAddressRequired,
       -- country != null 조건일 때:
       SC.countryCode, SC.ShippingCharge,
       -- option / composition 다국어 fallback 필드들 ...
FROM (
  -- SINGLE 리워드
  SELECT R.RewardId, NULL AS RewardCompositionId, ROS.RewardOptionSettingId, RO.RewardOptionId
  FROM Reward R
       LEFT OUTER JOIN RewardOptionSetting ROS ON ROS.RewardId = R.RewardId AND ROS.IsDeleted = false
       LEFT OUTER JOIN RewardOption RO ON RO.RewardId = R.RewardId AND RO.IsDeleted = FALSE
       -- country != null: INNER JOIN RewardShippingCountry
  WHERE R.CampaignId = ?
    AND R.IsDeleted = FALSE
    AND R.RewardType = 'SINGLE'
    -- country != null: AND RSC.CountryCode = ?
    -- !includeNullOffering: AND R.WhenOffering IS NOT NULL
  UNION ALL
  -- SET 리워드 (RewardComposition 추가 조인)
  ...
) A
  INNER JOIN Reward R ON A.RewardId = R.RewardId
  ... (RewardLanguage SL/DL/WL, RewardComposition 다국어, RewardOption 다국어 조인)
  LEFT JOIN RewardLimitedTimeOffer LTO ON LTO.RewardId = R.RewardId
  -- country != null: LEFT JOIN RewardShippingCountry SC ON SC.RewardId = R.RewardId AND SC.CountryCode = ?
ORDER BY R.DisplayOrder, ROS.OptionLevel, RC.OrderNo, RO.OrderNo
```

**접근 테이블**: `Reward`, `RewardLanguage`, `RewardOption`, `RewardOptionLanguage`, `RewardOptionSetting`, `RewardOptionSettingLanguage`, `RewardComposition`, `RewardCompositionLanguage`, `RewardShippingCountry`, `RewardLimitedTimeOffer`

---

## 38. GET `/api/global/projects/{projectNo}/rewards/{rewardId}` — 리워드 단건 조회

- **Method**: `GlobalProjectRewardController.getReward`

37번 `findAllByCountry` 의 SQL을 `findById` 용 변형으로 재사용(rewardId 필터 추가). country 필터는 선택.

---

## 39. 참고 — 이 문서의 Gateway / Repository / Mapper

### Gateway 구현체 (이 레포)

| 구현체 | 대상 |
|---|---|
| `RewardItemQueryGatewayImpl` | `RewardItemMapper`, `RewardLimitedTimeOfferMapper` |
| `RewardPolicyGatewayImpl` | `CampaignRewardDelayRepository` (Spring Data JDBC) |
| `RewardRefundPolicyGatewayImpl` | `RewardRefundPolicyRepository` |
| `ProductInfoNoticeQueryGatewayImpl` | `RewardProductMapper` |
| `RewardLimitedTimeOfferGatewayImpl` | `RewardLimitedTimeOfferRepository`, `RewardLimitedTimeOfferHistoryRepository` |
| `RewardLimitedTimeOfferQueryGatewayImpl` | `RewardLimitedTimeOfferMapper` (search + searchHistory) |
| `RewardEventGatewayImpl` | `RewardEventRepository`, `RewardEventBenefitMappingRepository`, `RewardEventParticipantRepository`, `RewardEventRandomBenefitMappingRepository` + `StoreClient` + `MembershipApiClient` |
| `RewardEventQueryGatewayImpl` | `RewardEventMapper` (추정, Admin 리스트용) |
| `RewardChangeLogGatewayImpl` | **MongoDB** `RewardChangeLogMongoRepository` (`@Async` 저장) |
| `GlobalProjectRewardQueryGatewayImpl` | `GlobalProjectRewardMapper` |

### Spring Data JDBC Repository
- `RewardLimitedTimeOfferRepository` / `RewardLimitedTimeOfferHistoryRepository` — save(Insert/Update), deleteById
- `CampaignRewardDelayRepository` — getById
- `RewardRefundPolicyRepository` — getById
- `RewardEventRepository` — findByKeyword, 기본 CRUD
- `RewardEventBenefitMappingRepository` — `findAllById_EventNoAndApplyFromLessThanEqualAndApplyToGreaterThanEqual`
- `RewardEventParticipantRepository` — `getTopByUserIdAndEventNoOrderByTimesDesc`
- `RewardEventRandomBenefitMappingRepository` — `findAllById_EventNo`

### MyBatis Mapper XML
- `RewardItemMapper.xml` — `getRewardItems` (상세 카운트 로직 + isCloseEarly)
- `RewardMapper.xml` — `search` / `count` / `findMinWhenOfferingByCampaignId`
- `RewardLimitedTimeOfferMapper.xml` — `search`, `searchHistory`, `isLimitedTimeOut`
- `RewardProductMapper.xml` — 상품정보제공고시 3종 (목록/카테고리/상세)
- `GlobalProjectRewardMapper.xml` — 국가·언어별 리워드 옵션 조합 (3단 fallback)

### MongoDB Repository
- `RewardChangeLogMongoRepository` — `findByCampaignIdAndRewardId`, `findByCampaignId`, `findById`, `save` (`@Async`)

### 외부 API
- `StoreClient.getUserOrdersQty(userId)` — 스토어 주문 건수
- `MembershipApiClient` — 멤버십 대상 유저 조회

### 접근 테이블 합계

`Reward`, `RewardLanguage`, `RewardOption`, `RewardOptionLanguage`, `RewardOptionSetting`, `RewardOptionSettingLanguage`, `RewardComposition`, `RewardCompositionLanguage`, `RewardShippingCountry`, `RewardLimitedTimeOffer`, `RewardLimitedTimeOfferHistory`, `RewardRefundPolicy`, `CampaignRewardDelay`, `RewardProductContent`, `RewardProductContentLanguage`, `RewardProductItem`, `RewardProductCategory`, `RewardProductCategoryLanguage`, `RewardEvent`, `RewardEventBenefitMapping`, `RewardEventParticipant`, `RewardEventRandomBenefitMapping`, `BackingPayment`, `BackingPaymentMapping`, `Backing`, `Campaign`, `UserProfile` + **MongoDB `RewardChangeLog` collection**

### 주요 enum (funding-core)
- `EventActionType`: ENTRY / BENEFIT / RANDOM_BENEFIT
- `EventBenefitType`: 보상 카테고리
- `OfferingTime`: 배송 시기
- `RewardType`: SINGLE / SET
- `LimitType`: REWARD / OPTION / …
