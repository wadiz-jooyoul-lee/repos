# Campaign Global / Native API 상세 스펙

해외(영문) 서비스 및 네이티브 앱을 위한 프로젝트 조회 API 20개.

- **대상 컨트롤러**:
  - `NativeProjectController` (`/api/native/v1/projects`) — 1개
  - `GlobalProjectController` (`/api/global/projects`) — 16개
  - `GlobalProjectInternalController` (`/api/internal/global/projects`) — 3개

- **공통 보안**: `@PreAuthorize("isOpenedOrComingSoonPosting(#projectNo) or isMaker(#projectNo) or isAdmin()")` — 서포터는 오픈 전이면 403, 프로젝트 없으면 404 (Global/Native)
- **다국어 처리**: Mapper는 `CampaignLanguage`와 관련 `*Language` 테이블에 대해 **3단 fallback** 조인 수행 — 요청 언어(`SL`) → 기본 언어(`DL`, 예: 'en') → 프로젝트 메이커 기본 언어(`WL`, `MakerStudioLanguageCode`)
- **캐싱**: `GlobalProjectProxy`의 주요 조회 메서드에 `@Cacheable(cacheNames="globalProject", keyGenerator="languageKeyGenerator")` — 언어별 캐시 분리

> **기록 범위**: 본 레포에서 직접 관찰 가능한 호출만 기록. UseCase 구현체는 외부 jar `com.wadiz.funding.core:funding-core` 에 있어 Usecase 내부 호출 순서/분기는 확인 불가. Gateway 구현체·Mapper XML은 이 레포에 있으므로 추적 가능.

---

## 1. GET `/api/native/v1/projects/{projectNo}` — 네이티브 앱 프로젝트 상세

앱에서 한 화면에 필요한 데이터를 **8개 병렬 비동기 호출**로 조회해 통합 응답. `NativeProjectFacade`가 `GlobalProjectProxy` + 외부 Store 서비스를 조합.

- **Method**: `NativeProjectController.getProject`
- **Facade**: `NativeProjectFacade.getProject`
- **Cache**: `@Cacheable(cacheNames="nativeProject", keyGenerator="languageKeyGenerator", sync=true)`
- **Executor**: `nativeAppAsyncExecutor` (@Qualifier 빈)

### Response — `NativeProjectResponse`

| 필드 | 타입 | 설명 |
|---|---|---|
| `isHidden` | `Boolean` | ✅ 숨김 여부 |
| `projectType` | enum `FUNDING/PREORDER` | — |
| `title` / `summary` | `String` | — |
| `aiSummary.richSummary[]` | `List<RichSummaryItem{emoji, headline, detail}>` | AI 요약 |
| `category` | `{code, isDonation}` | — |
| `isAdultContent` | `Boolean` | — |
| `maker.name / profileImageUrl` | `String` | 메이커 |
| `status` | enum `BEFORE_PROGRESS/COMING_SOON/IN_PROGRESS/END_OF_PROGRESS` | — |
| `openDateTime / endDateTime` | `ZonedDateTime` | — |
| `isFundingPaused` | `Boolean` | — |
| `preReservation.isPreReservation / preReservationType` | Boolean/String | — |
| `story.introImageUrls / introVideoUrl` | List/String | — |
| `fundingStatus.totalFundingAmount / achievementRate` | `Long` | — |
| `activityCounts.fundingCount / signatureCount` | `Long` | — |
| `shippingCountries[].code` | List | — |
| `store` | `{projectNo, isOnSale, sellingPriceOfSignature, discountPercentageOfSignature, promotionOfSignature}` | 스토어 연동 결과 |

### 컨트롤러 / Facade 코드 흐름 (관찰 가능한 단계)

```
Phase 1: isHidden 확인 (동기적, status와 독립)
  CompletableFuture.supplyAsync(globalProjectProxy::isProjectHidden, executor).join()
  ↓ true면 {isHidden:true}만 담아 즉시 반환

Phase 2: status 조회로 분기 결정
  globalProjectProxy.getProjectStatus(projectNo)
  ↓
  isComingSoon / isEnded 판정

Phase 3: 6~8개 병렬 비동기 호출
  CompletableFuture.supplyAsync(...):
    - globalProjectProxy.getProject(projectNo)
    - globalProjectProxy.getProjectStory(projectNo) OR getComingSoonStory(projectNo)
    - globalProjectProxy.getProjectFundingStatus(projectNo)
    - globalProjectProxy.getProjectActivityCount(projectNo, [FUNDING, SIGNATURE])
    - globalProjectProxy.getProjectShippingCountry(projectNo)
    - globalProjectProxy.getAiSummary(projectNo, lang)       ← 1초 timeout
    - storeProjectQueryGateway.getStoreProjectByCampaignId(projectNo) (isEnded 시) ← 1초 timeout

  Store가 ON_SALE이면 추가로:
    - storeProjectQueryGateway.getProductAggregation(storeProjectNo) ← 1초 timeout

Phase 4: 결과 결합해 NativeProjectResponse 빌드
```

### 이 엔드포인트가 호출하는 Proxy 메서드 (실제 관찰)

| Proxy 메서드 | 용도 | 이 레포 내 관찰 가능한 Gateway |
|---|---|---|
| `isProjectHidden` | 숨김 확인 | Gateway는 funding-core (이 레포에 미존재) |
| `getProjectStatus` | 상태 | 동상 |
| `getProject` | 프로젝트 기본 | `GlobalProjectQueryGatewayImpl.findProject` → `GlobalProjectMapper.findProject` |
| `getProjectStory` / `getComingSoonStory` | 스토리 | `findProjectStory` / `findComingSoonStory` + `findAllIntroMedia` |
| `getProjectFundingStatus` | 펀딩 달성 | Gateway는 funding-core |
| `getProjectActivityCount` | 활동 건수 | Gateway는 funding-core |
| `getProjectShippingCountry` | 배송 국가 | `GlobalProjectRewardQueryGatewayImpl.findAllProjectShippingCountry` → `GlobalProjectRewardMapper.findAllShippingCountry` |
| `getAiSummary` | AI 요약 | Gateway는 funding-core (외부 AI 서비스 연동 추정) |

### 외부 의존
- `storeProjectQueryGateway` — `com.wadiz.funding.core.store.StoreProjectQueryGateway`, 외부 Store 서비스 연동 (1초 timeout)
- `StoreProductAggregationResult` 조회 — 스토어 판매 중일 때만

---

## 2. GET `/api/global/projects/{projectNo}` — 해외 프로젝트 기본 정보

- **Method**: `GlobalProjectController.get`
- **QueryParam**: `isPreview` (Boolean, default false)
- **Cache**: `getProject`에 `@Cacheable` (preview는 캐시 없음)

### Response — `GlobalProjectResponse`

| 필드 | 타입 | 설명 |
|---|---|---|
| `projectType` | enum `FUNDING/PREORDER` | ✅ |
| `projectSubType` | enum `FUNDING/PREORDER/PREORDER_ENCORE/PREORDER_GLOBAL` | ✅ |
| `preorderBenefitType` | enum `ONLY/SPECIAL/LIMITED` | 프리오더 혜택 |
| `title` / `summary` / `featuredImageUrl` | `String` | — |
| `category.code / isDonation` | String / Boolean | ✅ code |
| `isAdultContent` | `Boolean` | ✅ |
| `maker.name / profileImageUrl / isCurrentUser` | — | 메이커 |
| `status` | enum `BEFORE_PROGRESS/COMING_SOON/IN_PROGRESS/END_OF_PROGRESS` | ✅ |
| `openDateTime / endDateTime` | `ZonedDateTime` | — |
| `isFundingPaused` | `Boolean` | ✅ |
| `preReservation.isPreReservation / preReservationType` | `Boolean / String` | ✅ |

### 컨트롤러 코드 흐름
1. `isPreview == true`면 `getProjectPreview`, 아니면 `getProject` (동일 UseCase, Proxy에서 캐시 여부만 분기)
2. `getProjectStatus(projectNo)` 추가 호출
3. `SecurityUtils.getCurrentUserId().orElse(null)` — 로그인 유저 ID
4. `CONVERTER.to(project, status, currentUserId)` 합성

### MySQL 쿼리 (`GlobalProjectMapper.findProject`)

```sql
SELECT C.BizModel, C.Classification, C.CampaignGroup, L.Label,
       IFNULL(SL.Title, IFNULL(DL.Title, WL.Title)) AS title,
       C.Title AS originalTitle,
       IFNULL(SL.CoreMessage, IFNULL(DL.CoreMessage, WL.CoreMessage)) AS summary,
       IFNULL(SL.PhotoUrl, IFNULL(DL.PhotoUrl, WL.PhotoUrl)) AS featuredImageUrl,
       CA.CategoryCode, C.IsAdultContent,
       IF(#{language.language} = 'ko', C.HostName, IFNULL(C.GlobalMakerName, C.HostName)) AS makerName,
       HPC.PhotoUrl AS makerProfileImageUrl,
       C.UserId AS makerUserId, C.IsOpen,
       C.WhenOpen, C.whenClose, AO.scheduled, C.WhenHoldTo,
       CP.PauseEndDate AS fundingPauseEndDate,
       C.IsHidden,
       IFNULL(RCS.IsPreReservation, false) AS isPreReservation,
       IF(RCS.IsPreReservation, RCS.PreReservationType, null) AS PreReservationType
FROM Campaign C
     LEFT JOIN CampaignAutoOpen AO          ON C.CampaignId = AO.campaignId AND AO.isCancel = false
     LEFT JOIN CampaignLabel L              ON C.CampaignId = L.CampaignId
     LEFT JOIN CampaignCategoryMapping CA   ON C.CampaignId = CA.CampaignId AND CA.IsPrime = true
     LEFT JOIN PhotoCommon HPC              ON C.PhotoIdHost = HPC.PhotoId
     LEFT JOIN CampaignPause CP             ON C.CampaignId = CP.CampaignId
     LEFT JOIN RewardComingSoon RCS         ON C.CampaignId = RCS.CampaignId
     LEFT JOIN CampaignLanguage SL          ON C.CampaignId = SL.CampaignId AND SL.LanguageCode = ?  -- 요청 언어
     LEFT JOIN CampaignLanguage DL          ON C.CampaignId = DL.CampaignId AND DL.LanguageCode = ?  -- 기본 언어
     LEFT JOIN CampaignLanguage WL          ON C.CampaignId = WL.CampaignId AND WL.LanguageCode = C.MakerStudioLanguageCode
WHERE C.CampaignId = ?
  AND C.IsDel = false
```

**접근 테이블**: `Campaign`, `CampaignAutoOpen`, `CampaignLabel`, `CampaignCategoryMapping`, `PhotoCommon`, `CampaignPause`, `RewardComingSoon`, `CampaignLanguage`

> `getProjectStatus`의 Gateway 구현체는 이 레포에 없음 (funding-core). 실제 DB 호출은 여기서 특정 불가.

---

## 3. GET `/api/global/projects/{projectNo}/story` — 스토리

- **Method**: `getStory`
- **QueryParam**: `isPreview`

### Response — `GlobalProjectStoryResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `introImageUrls` | `List<String>` | 소개 이미지 URL 리스트 |
| `introVideoUrl` | `String` | — |
| `story` | `String` | 본문 |

### MySQL 쿼리 (2회)

**① 스토리 본문** (`GlobalProjectMapper.findProjectStory`)
```sql
SELECT IFNULL(SL.IntroDetails, IFNULL(DL.IntroDetails, WL.IntroDetails)) AS story
FROM Campaign C
     LEFT JOIN CampaignLanguage SL ON C.CampaignId = SL.CampaignId AND SL.LanguageCode = ?
     LEFT JOIN CampaignLanguage DL ON C.CampaignId = DL.CampaignId AND DL.LanguageCode = ?
     LEFT JOIN CampaignLanguage WL ON C.CampaignId = WL.CampaignId AND WL.LanguageCode = C.MakerStudioLanguageCode
WHERE C.CampaignId = ? AND C.IsDel = false
```

**② 소개 이미지/영상** (`findAllIntroMedia`) — `CampaignPhotoLanguage` 조인 포함, introVideoUrl 선택 로직 내장
```sql
SELECT C.CampaignId AS projectNo,
       CASE
         WHEN (SL.VideoUrl IS NOT NULL OR EXISTS(SELECT 1 FROM CampaignPhotoLanguage SPL WHERE SPL.CampaignId = C.CampaignId AND SPL.LanguageCode = ?))
              THEN SL.VideoUrl
         WHEN (DL.VideoUrl IS NOT NULL OR EXISTS(SELECT 1 FROM CampaignPhotoLanguage DPL WHERE DPL.CampaignId = C.CampaignId AND DPL.LanguageCode = ?))
              THEN DL.VideoUrl
         ELSE WL.VideoUrl
       END AS introVideoUrl,
       PL.PhotoUrl AS introImageUrl
FROM Campaign C
     LEFT JOIN CampaignLanguage SL          ON C.CampaignId = SL.CampaignId AND SL.LanguageCode = ?
     LEFT JOIN CampaignLanguage DL          ON C.CampaignId = DL.CampaignId AND DL.LanguageCode = ?
     LEFT JOIN CampaignLanguage WL          ON C.CampaignId = WL.CampaignId AND WL.LanguageCode = C.MakerStudioLanguageCode
     LEFT JOIN CampaignPhotoLanguage PL     ON C.CampaignId = PL.CampaignId AND PL.LanguageCode = (위 CASE와 동일 분기)
WHERE C.CampaignId = ? AND C.IsDel = false
ORDER BY PL.OrderNo
```

**접근 테이블**: `Campaign`, `CampaignLanguage`, `CampaignPhotoLanguage`

---

## 4. GET `/api/global/projects/{projectNo}/coming-soon-story` — 오픈예정 스토리

- **Method**: `getComingSoonStory`
- **Security**: 다른 엔드포인트보다 엄격 — `@PreAuthorize("isComingSoonPosting(#projectNo) or isMaker(#projectNo) or isAdmin()")`

### Response
`GlobalProjectStoryResponse` (스토리와 동일)

### MySQL 쿼리

**① 스토리** (`findComingSoonStory`)
```sql
SELECT IFNULL(SCSL.Story, IFNULL(DCSL.Story, WCSL.Story)) AS story
FROM Campaign C
     LEFT JOIN RewardComingSoon CS                ON C.CampaignId = CS.CampaignId
     LEFT JOIN RewardComingSoonLanguage SCSL      ON CS.CampaignId = SCSL.CampaignId AND SCSL.LanguageCode = ?
     LEFT JOIN RewardComingSoonLanguage DCSL      ON CS.CampaignId = DCSL.CampaignId AND DCSL.LanguageCode = ?
     LEFT JOIN RewardComingSoonLanguage WCSL      ON CS.CampaignId = WCSL.CampaignId AND WCSL.LanguageCode = C.MakerStudioLanguageCode
WHERE C.CampaignId = ? AND C.IsDel = false
```

**② IntroMedia** — `findAllIntroMedia` (3번과 동일)

**접근 테이블**: `Campaign`, `RewardComingSoon`, `RewardComingSoonLanguage`, `CampaignLanguage`, `CampaignPhotoLanguage`

---

## 5. GET `/api/global/projects/{projectNo}/maker` — 메이커 정보

- **Method**: `getMakerContact`

### Response — `GlobalProjectMakerResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | `String` | 메이커명 (ko면 HostName, 그 외 GlobalMakerName) |
| `profileImageUrl` | `String` | — |
| `contract.email` | `String` | 연락 이메일 (HostEmail, 필드명 오탈자 `contract`) |
| `contract.homepages[]` | `List<String>` | WebsiteA/B |
| `contract.snsList[]` | `List<Sns{type=FACEBOOK/INSTAGRAM/TWITTER, url}>` | — |
| `contract.kakaoTalkChannel.id / url` | — | KAKAOPLUS_SEARCH_ID / KAKAOPLUS_HOME_URL (JSON 추출) |

### MySQL 쿼리 (`GlobalProjectMapper.findMaker`)

```sql
SELECT IF(#{language.language} = 'ko', C.HostName, IFNULL(C.GlobalMakerName, C.HostName)) AS name,
       PC.PhotoUrl AS profileImageUrl,
       CCI.CountryCode,
       C.UserId AS user_userId,
       UP.UserName AS user_email,
       C.HostEmail AS contact_email,
       C.WebsiteA AS contact_websiteA,
       C.WebsiteB AS contact_websiteB,
       C.SocialUrlFb AS contact_facebook,
       C.SocialUrlTw AS contact_twitter,
       C.SocialUrlIg AS contact_instagram,
       CASE TRIM(C.MakerContactProperty ->> '$.KAKAOPLUS_SEARCH_ID')
            WHEN 'null' THEN null WHEN '' THEN null
            ELSE C.MakerContactProperty ->> '$.KAKAOPLUS_SEARCH_ID' END AS contact_kakaoTalkChannel_id,
       CASE TRIM(C.MakerContactProperty ->> '$.KAKAOPLUS_HOME_URL')
            WHEN 'null' THEN null WHEN '' THEN null
            ELSE C.MakerContactProperty ->> '$.KAKAOPLUS_HOME_URL' END AS contact_kakaoTalkChannel_url
FROM Campaign C
     LEFT JOIN PhotoCommon PC          ON C.PhotoIdHost = PC.PhotoId
     LEFT JOIN UserProfile UP          ON C.UserId = UP.UserId
     LEFT JOIN CampaignContractInfo CCI ON C.CampaignId = CCI.CampaignId
WHERE C.CampaignId = ? AND C.IsDel = false
```

**접근 테이블**: `Campaign`, `PhotoCommon`, `UserProfile`, `CampaignContractInfo`

---

## 6. GET `/api/global/projects/{projectNo}/shipping-countries` — 배송 가능 국가

- **Method**: `getShippingCountries`
- **QueryParam**: `isPreview`

### Response — `GlobalProjectShippingCountryListResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `countries[].code` | `String` | ✅ 국가 코드 |
| `countries[].name` | `String` | ✅ 국가명 |

### MySQL 쿼리 (`GlobalProjectRewardMapper.findAllShippingCountry`)

```sql
SELECT DISTINCT SC.CountryCode AS code
FROM Reward R
     INNER JOIN RewardShippingCountry SC ON R.RewardId = SC.RewardId
WHERE R.CampaignId = ?
  AND R.IsDeleted = false
  -- includeNullOffering=false면 추가:
  AND R.WhenOffering is not null
```

- `includeNullOffering` 파라미터로 "출시일 미정 리워드" 포함 여부 제어 (2종 메서드 `findAllProjectShippingCountry`, `findAllProjectShippingCountryByIncludeNullOffering`)
- 응답의 `name` 필드는 이 SQL에서 반환되지 않음 → Converter 단계에서 country code → name 매핑 (구현체 funding-core)

**접근 테이블**: `Reward`, `RewardShippingCountry`

---

## 7. GET `/api/global/projects/{projectNo}/refund-policy` — 환불 정책

- **Method**: `getRefundPolicy`

### Response — `GlobalProjectRefundPolicyResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `nonRefundablePolicy` | `String` | 기타 환불 불가 정책 |
| `asPolicy` | `String` | A/S 정책 |

### MySQL 쿼리 (`GlobalProjectMapper.findRefundPolicy`)

```sql
SELECT IFNULL(SRDL.NoRefundCase, IFNULL(DRDL.NoRefundCase, WRDL.NoRefundCase)) AS nonRefundablePolicy,
       IFNULL(SRDL.ReturnExchangePolicy, IFNULL(DRDL.ReturnExchangePolicy, WRDL.ReturnExchangePolicy)) AS asPolicy
FROM Campaign C
     LEFT JOIN CampaignRewardDelay RD                ON C.CampaignId = RD.CampaignId
     LEFT JOIN CampaignRewardDelayLanguage SRDL      ON RD.CampaignId = SRDL.CampaignId AND SRDL.LanguageCode = ?
     LEFT JOIN CampaignRewardDelayLanguage DRDL      ON RD.CampaignId = DRDL.CampaignId AND DRDL.LanguageCode = ?
     LEFT JOIN CampaignRewardDelayLanguage WRDL      ON RD.CampaignId = WRDL.CampaignId AND WRDL.LanguageCode = C.MakerStudioLanguageCode
WHERE RD.CampaignId = ?
```

**접근 테이블**: `Campaign`, `CampaignRewardDelay`, `CampaignRewardDelayLanguage`

---

## 8. GET `/api/global/projects/{projectNo}/product-info-notice` — 상품정보제공 고시

- **Method**: `getAllProductInfoNotice`

### Response — `List<GlobalProjectProductInfoNoticeResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `category.code / name` | ✅ | 카테고리 |
| `descriptions[].itemName / description` | List | 항목 설명 |

### MySQL 쿼리 (`GlobalProjectMapper.findAllProjectProductInfoNotice`)

```sql
SELECT PC.OrderNo,
       CT.RewardProductCategoryCode AS category_code,
       IFNULL(SCTL.Name, IFNULL(DCTL.Name, WCTL.Name)) AS category_name,
       I.ItemNo AS description_itemNo,
       IFNULL(SIL.ItemName, IFNULL(DIL.ItemName, WIL.ItemName)) AS description_itemName,
       IFNULL(SCL.ItemValue, IFNULL(DCL.ItemValue, WCL.ItemValue)) AS description_description
FROM Campaign C
     INNER JOIN RewardProductContent PC  ON C.CampaignId = PC.CampaignId
     INNER JOIN RewardProductItem I      ON PC.ItemNo = I.ItemNo AND I.isUse = TRUE
     INNER JOIN RewardProductCategory CT ON I.ProductCode = CT.RewardProductCategoryCode AND CT.IsDeleted = FALSE
     LEFT JOIN RewardProductContentLanguage SCL  ON PC.Seq = SCL.Seq AND SCL.LanguageCode = ?
     LEFT JOIN RewardProductContentLanguage DCL  ON PC.Seq = DCL.Seq AND DCL.LanguageCode = ?
     LEFT JOIN RewardProductContentLanguage WCL  ON PC.Seq = WCL.Seq AND WCL.LanguageCode = C.MakerStudioLanguageCode
     LEFT JOIN RewardProductItemLanguage SIL     ON I.ItemNo = SIL.ItemNo AND SIL.LanguageCode = ?
     LEFT JOIN RewardProductItemLanguage DIL     ON I.ItemNo = DIL.ItemNo AND DIL.LanguageCode = ?
     LEFT JOIN RewardProductItemLanguage WIL     ON I.ItemNo = WIL.ItemNo AND WIL.LanguageCode = C.MakerStudioLanguageCode
     LEFT JOIN RewardProductCategoryLanguage SCTL ON CT.RewardProductCategoryCode = SCTL.RewardProductCategoryCode AND SCTL.LanguageCode = ?
     LEFT JOIN RewardProductCategoryLanguage DCTL ON CT.RewardProductCategoryCode = DCTL.RewardProductCategoryCode AND DCTL.LanguageCode = ?
     LEFT JOIN RewardProductCategoryLanguage WCTL ON CT.RewardProductCategoryCode = WCTL.RewardProductCategoryCode AND WCTL.LanguageCode = C.MakerStudioLanguageCode
WHERE PC.CampaignId = ?
  AND PC.isDeleted = FALSE
ORDER BY PC.OrderNo, CT.RewardProductCategoryCode, I.ItemOrder
```

**접근 테이블**: `Campaign`, `RewardProductContent`, `RewardProductItem`, `RewardProductCategory`, `RewardProductContentLanguage`, `RewardProductItemLanguage`, `RewardProductCategoryLanguage`

---

## 9. GET `/api/global/projects/{projectNo}/supporters` — 서포터 목록 (페이징)

펀딩 참여자 + 지지서명자를 UNION해서 시간 역순으로 페이징.

- **Method**: `getAllSupporter`
- **정렬 기본**: `SupportedAt desc`

### Response — `PageResult<GlobalProjectSupporterResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `type` | enum `SIGNATURE / FUNDING / PREORDER` | ✅ |
| `amount` | `Long` | 참여 금액 (미공개 시 null) |
| `user.encUserId` | `Long` | 암호화된 유저 ID |
| `user.name` | `String` | ✅ |
| `user.profileImageUrl` | `String` | — |
| `supportedAt` | `ZonedDateTime` | ✅ |

### MySQL 쿼리 (`GlobalProjectMapper.findAllSupporter` + `countSupporter`)

**① 목록**
```sql
SELECT T.Type, T.UserId, UP.NickName AS UserName, PC.PhotoUrl AS UserProfileImageUrl, T.Amount, T.SupportedAt
FROM (
  SELECT 'SIGNATURE' AS Type,
         S.UserId AS UserId,
         null AS Amount,
         MAX(S.WhenCreated) AS SupportedAt
  FROM Signature S
  WHERE S.IsDeleted = FALSE AND S.CampaignId = ?
  GROUP BY S.UserId
  UNION ALL
  SELECT C.BizModel AS Type,
         IF(BP.DontShowName, null, BP.UserId) AS UserId,
         IF(BP.DontShowAmount, null, BP.FundingAmount) AS Amount,
         BP.RegDate AS SupportedAt
  FROM BackingPayment BP
       INNER JOIN Campaign C ON BP.CampaignId = C.CampaignId
  WHERE BP.IsCanceled = FALSE AND BP.CampaignId = ?
) T
LEFT JOIN UserProfile UP ON T.UserId = UP.UserId AND UP.UserStatus = 'NM'
LEFT JOIN PhotoCommon PC ON UP.PhotoId = PC.PhotoId
-- + 페이징/정렬 절 (Clauses.pagesAndFallbackSorts)
```

**② 카운트** (`countSupporter`)
```sql
SELECT SUM(countSupporter)
FROM (
  SELECT COUNT(DISTINCT UserId) AS countSupporter FROM Signature S
  WHERE S.IsDeleted = FALSE AND S.CampaignId = ?
  UNION ALL
  SELECT COUNT(*) AS countSupporter FROM BackingPayment BP
  WHERE BP.IsCanceled = FALSE AND BP.CampaignId = ?
) T
```

**접근 테이블**: `Signature`, `BackingPayment`, `Campaign`, `UserProfile`, `PhotoCommon`

---

## 10. GET `/api/global/projects/{projectNo}/activity-counts` — 활동 건수

- **Method**: `getActivityCounts`
- **QueryParam**: `types` (ActivityType[] — `NEWS/SATISFACTION/COMMENT/FUNDING/SIGNATURE/WISH/OPEN_NOTIFICATION_SUBSCRIBER/ASK_FOR_ENCORE`)

### Response — `GlobalProjectActivityCountsResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `newsCount / satisfactionCount / commentCount / fundingCount / signatureCount / wishCount / openNotificationSubscriberCount / askForEncoreCount` | `Long` (요청한 타입만 값 있음, 나머지 null) | — |

### DB 호출

Proxy → `GlobalProjectActivityCountUseCase.get(projectNo, types)` (funding-core) → Gateway 구현체가 **이 레포 infrastructure에 별도로 존재하지 않음**. 각 활동 유형별 집계는 다른 도메인(news/satisfaction/comment/funding/signature/wish/comingsoonapplicant/encore)의 기존 Gateway/Mapper를 재활용할 것으로 보이나, 실제 호출은 funding-core 확인 필요.

→ **이 엔드포인트의 구체적 SQL은 이 레포에서 특정 불가**.

---

## 11. GET `/api/global/projects/{projectNo}/funding-status` — 펀딩 달성 정보

- **Method**: `getFundingStatus`

### Response — `GlobalProjectFundingStatusResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `totalFundingAmount` | `Long` | ✅ 펀딩 금액 |
| `achievementRate` | `Long` | ✅ 달성률 |

### DB 호출

`GlobalProjectFundingStatusUseCase.get()` — Gateway 구현체가 이 레포에 **별도로 없음**. `BackingPaymentMapper.backingSummationInfo` + `Campaign.TargetAmount` 조합을 UseCase가 사용할 것으로 보이나 확정 불가.

→ **funding-core 확인 필요**.

---

## 12. GET `/api/global/projects/{projectNo}/activity/my` — 로그인 유저 활동

- **Method**: `getMyActivity`
- **Auth**: 로그인 필수 (`SecurityUtils.currentUserId()`)

### Response — `GlobalProjectMyActivityResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `isWishing` | `Boolean` | ✅ 찜 |
| `isEncoreAsked` | `Boolean` | ✅ 앵콜 요청 (종료 후만) |
| `isOpenNotificationSubscribed` | `Boolean` | ✅ 오픈 알림 |
| `hasFunded` | `Boolean` | ✅ 펀딩 참여 |
| `satisfactionWritingStatus` | enum `NONE/WRITABLE/WRITTEN` | ✅ |

### DB 호출

`GlobalProjectMyActivityUseCase.get(projectNo, userId)` — 전용 Gateway 구현체 없음. wish/encore/signature/backingPayment/satisfaction 관련 Gateway 조합 호출로 추정되나 확정 불가.

---

## 13. GET `/api/global/projects/{projectNo}/satisfaction/display-status` — 만족도 노출 여부

- **Method**: `getSatisfactionDisplayStatus`

### Response — `GlobalProjectSatisfactionDisplayStatusResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `isSatisfactionDisplayed` | `Boolean` | ✅ |
| `recommendedOrder.property` | enum `AVERAGE_SCORE/REGISTERED` | 정렬 기준 |
| `recommendedOrder.direction` | `String` "desc"/"asc" | — |

### DB 호출

`GlobalProjectSatisfactionDisplayStatusUseCase` — 이 레포에 Gateway 없음. satisfaction 도메인 Gateway 조합 추정.

---

## 14. GET `/api/global/projects/{projectNo}/funding-pause` — 펀딩 일시 중지 정보

- **Method**: `getFundingPaused`

### Response — `GlobalProjectFundingPausedResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `isFundingPaused` | `Boolean` | ✅ |
| `noticeUrl` | `String` | 안내 URL |

### MySQL 쿼리 (`GlobalProjectMapper.findFundingPause`)

```sql
SELECT PauseEndDate AS fundingPauseEndDate,
       RedirectUrl AS noticeUrl
FROM CampaignPause
WHERE CampaignId = ?
```

- 응답의 `isFundingPaused`는 UseCase에서 `PauseEndDate > now()` 로직으로 도출될 가능성 높음 (이 SQL만으로는 확정 불가)

**접근 테이블**: `CampaignPause`

---

## 15. GET `/api/global/projects/{projectNo}/hidden` — 숨김 여부

- **Method**: `isHidden`

### Response
```json
{ "isHidden": true|false }
```

### DB 호출

`GlobalProjectHiddenUseCase.isHidden()` — 전용 Gateway 없음. `Campaign.IsHidden` 필드 조회일 가능성이 높지만 확정 불가.  
(Spring Data JDBC 파생 쿼리 또는 MyBatis 중 어느 경로인지도 funding-core 확인 필요)

---

## 16. GET `/api/global/projects/{projectNo}/distribution` — 유통 정보

- **Method**: `getDistribution`

### Response — `GlobalProjectDistributionResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `isKorOfficialDistribution` | `Boolean` | ✅ 한국 정식 유통 여부 |
| `dispatch.countryCode` | `String` | 출고지 (배송 없음이면 null) |
| `dispatch.coordinator.name / email` | — | 출고 담당자 |

### MySQL 쿼리 (`GlobalProjectMapper.findDistribution`)

```sql
SELECT NOT EXISTS(SELECT 1
                  FROM wadiz_db.ScreeningRewardItem RI
                  WHERE RI.CampaignId = C.CampaignId
                    AND RI.IsDeleted = FALSE
                    AND RI.IsDirectPurchase = TRUE) AS isKorOfficialDistribution,
       IF(CD.DispatchType = 'WITH_DISPATCH', CD.DispatchCountryCode, null) AS dispatch_countryCode,
       IF(CD.DispatchType = 'WITH_DISPATCH', CD.Coordinator, null) AS dispatch_coordinator_name,
       IF(CD.DispatchType = 'WITH_DISPATCH', CD.CoordinatorContact, null) AS dispatch_coordinator_email
FROM wadiz_db.Campaign C
     LEFT JOIN wadiz_db.CampaignDispatch CD ON C.CampaignId = CD.CampaignId
WHERE C.CampaignId = ?
```

**접근 테이블**: `Campaign`, `CampaignDispatch`, `ScreeningRewardItem`

---

## 17. GET `/api/global/projects/{projectNo}/ai-summary` — AI 요약

- **Method**: `getAiSummary`
- **Cache**: `@Cacheable(cacheNames=AI_SUMMARY_CACHE="globalProjectAiSummary", sync=true)`
- **Locale**: `LocaleContextHolder.getLocale().getLanguage()`로 언어 결정

### Response — `AiSummaryResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `richSummary[].emoji / headline / detail` | `String` | 요약 아이템 (결과 없으면 빈 객체) |

### DB/외부 호출

`GlobalProjectAiSummaryUseCase.get(projectNo, lang)` — 이 레포에 AI 요약 전용 Gateway·Mapper가 **없음**. AI 서비스(외부 LLM/검색 API)와의 통신으로 추정되지만 구현은 funding-core.  
→ 캐시(`AI_SUMMARY_CACHE`)는 이 레포에서 관찰됨. 18/19번 Internal 엔드포인트가 이 캐시를 evict 용도.

---

## 18. GET `/api/internal/global/projects/{projectNo}` — 내부용 프로젝트 조회

- **Method**: `GlobalProjectInternalController.get`

### Response — `InternalGlobalProjectResponse`
공개 `GlobalProjectResponse`와 유사한 구조 (Converter가 `InternalGlobalProjectResponseConverter.INSTANCE`).

### 컨트롤러 코드 흐름
1. `globalProjectProxy.getProjectStatus(projectNo)` 호출
2. `globalProjectProxy.getProject(projectNo)` 호출
3. Converter로 결합

### MySQL 쿼리
2번 `/api/global/projects/{projectNo}`의 `findProject` SQL 동일 + Status 조회(funding-core).

---

## 19. DELETE `/api/internal/global/projects/{projectNo}/ai-summary/cache` — AI 요약 캐시(프로젝트 단위) 삭제

- **Method**: `evictAiSummaryCache`

### 컨트롤러 코드 흐름
```java
final String lang = LocaleContextHolder.getLocale().getLanguage();
localeCacheHelper.evict(
    GlobalProjectProxy.AI_SUMMARY_CACHE,           // "globalProjectAiSummary"
    GlobalProjectProxy.GET_AI_SUMMARY,             // "getAiSummary"
    projectNo, lang);
return ResponseWrapper.ok(null);
```

- **DB 호출 없음**. 캐시 인프라에서 해당 키만 제거.
- `LocaleCacheHelper`는 요청 언어 기반으로 캐시 키를 생성/제거하는 유틸

---

## 20. DELETE `/api/internal/global/projects/ai-summary/cache` — AI 요약 캐시 전체 삭제

- **Method**: `evictAllAiSummaryCache`

### 컨트롤러 코드 흐름
```java
localeCacheHelper.clear(GlobalProjectProxy.AI_SUMMARY_CACHE);
return ResponseWrapper.ok(null);
```

- **DB 호출 없음**. `globalProjectAiSummary` 캐시를 통째로 비움.

---

## 21. 참고 — 이 문서의 Gateway / Mapper 맵

### Gateway 구현체 (이 레포 `adapter/infrastructure` 하위)

| 구현체 | 주요 메서드 → Mapper |
|---|---|
| `GlobalProjectQueryGatewayImpl` | `findAllProjectOverview`, `findAllSupporter` + `countSupporter`, `findProject`, `findProjectStory` / `findComingSoonStory` + `findAllIntroMedia`, `findMaker`, `findAllProjectProductInfoNotice`, `findRefundPolicy`, `findFundingPause`, `findDistribution` → `GlobalProjectMapper` |
| `GlobalProjectRewardQueryGatewayImpl` | `findAllProjectShippingCountry` (+ includeNullOffering 변형) → `GlobalProjectRewardMapper.findAllShippingCountry` |

### UseCase 중 이 레포에 Gateway 구현체가 **없는** 것 (funding-core 확인 필요)
- `GlobalProjectHiddenUseCase` (hidden)
- `GlobalProjectStatusUseCase` (project status enum)
- `GlobalProjectActivityCountUseCase` (activity-counts)
- `GlobalProjectFundingStatusUseCase` (funding-status)
- `GlobalProjectMyActivityUseCase` (my-activity)
- `GlobalProjectSatisfactionDisplayStatusUseCase` (satisfaction/display-status)
- `GlobalProjectAiSummaryUseCase` (ai-summary)

### 3단 언어 fallback 패턴

`CampaignLanguage`, `CampaignRewardDelayLanguage`, `RewardComingSoonLanguage`, `RewardProductContentLanguage`, `RewardProductItemLanguage`, `RewardProductCategoryLanguage`, `CampaignPhotoLanguage` — 각 다국어 테이블에 대해:

```
SL (selected language)
  → DL (default language, 예: 'en')
    → WL (maker's study language, Campaign.MakerStudioLanguageCode)
```

`IFNULL(SL.x, IFNULL(DL.x, WL.x))` 형태로 조회되어 빈 번역 시 역순 대체.

### 접근 테이블 합계 (관찰된 SQL 기준)

`Campaign`, `CampaignAutoOpen`, `CampaignLabel`, `CampaignCategoryMapping`, `CampaignLanguage`, `CampaignPhotoLanguage`, `CampaignPause`, `CampaignDispatch`, `CampaignRewardDelay`, `CampaignRewardDelayLanguage`, `CampaignContractInfo`, `RewardComingSoon`, `RewardComingSoonLanguage`, `RewardProductContent`, `RewardProductItem`, `RewardProductCategory`, `RewardProductContentLanguage`, `RewardProductItemLanguage`, `RewardProductCategoryLanguage`, `Reward`, `RewardShippingCountry`, `ScreeningRewardItem`, `Signature`, `BackingPayment`, `UserProfile`, `PhotoCommon`

### 네이티브 전용: 외부 Store 서비스

`NativeProjectFacade`에서만 사용:
- `StoreProjectQueryGateway.getStoreProjectByCampaignId(campaignId)` — 펀딩 종료된 프로젝트가 스토어에 등록됐는지 조회
- `StoreProjectQueryGateway.getProductAggregation(storeProjectNo)` — 대표 상품 가격/할인/프로모션 집계
- 각 호출에 **1초 timeout** 적용. 실패 시 해당 필드만 null로 응답

Gateway 구현체는 별도 외부 서비스 HTTP 연동 (이 레포 내부에 존재하지 않는 funding-core 모듈).
