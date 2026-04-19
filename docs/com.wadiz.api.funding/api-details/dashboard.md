# Dashboard API 상세 스펙

스튜디오 대시보드(프로젝트 현황·유입·결제·서포터·오픈예정)와 메이커 대시보드 관련 **40개 엔드포인트**.

- **대상 컨트롤러**:
  - `StudioProjectDashBoardController` (`/api/studio/dashboard/projects/{projectNo}`) — 5개
  - `StudioProjectAcquisitionDashBoardController` (`.../acquisitions`) — 4개
  - `StudioProjectEngagementDashBoardController` (`.../engagements`) — 5개
  - `StudioProjectSupporterDashBoardController` (`.../supporters`) — 4개
  - `StudioComingSoonDashBoardController` (`/api/studio/dashboard/coming-soons/{projectNo}`) — 16개
  - `MakerDashboardController` (`/api/maker-dashboard`, `/api/v1/maker-dashboard`) — 6개

- **공통 보안**: Studio 계열 전부 `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`. MakerDashboard는 `@Impersonatable`(대리 접근) 지원.
- **공통 설계 특징**:
  - **카드 프리셋**: `StudioDashBoardCardPreset` enum으로 `OVERVIEW/FULL` 메트릭 세트 전환 (메트릭 키 순서 보존을 위해 `Comparator.comparingInt(indexOf)`로 재정렬)
  - **IANA Timezone**: 대부분 `timezone` 파라미터로 `ZoneId.of(timezone)` 해석
  - **DataPlus 외부 API**: 유입·행동 분석은 `https://dev-api.wadizdata.team/dataplus/docs` 로 위임 (funding-core 내부)
  - **Excel/CSV 다운로드**: `XlsxStreamingResponseBody` + `CsvExporter` + `MessageResolver`(i18n) 조합으로 통일된 패턴
- **캐시**: `StudioProjectDashBoardProxy`, `StudioComingSoonDashBoardProxy` 대부분 메서드 `@Cacheable(cacheNames="studioProjectDashBoard", keyGenerator="cacheKeyGenerator")`. `MakerDashboardQueryGatewayImpl`은 `@Transactional(readOnly=true)` 적용.

> **기록 범위**: 이 레포의 Controller / Proxy / `MakerDashboardQueryGatewayImpl` / MyBatis XML 에서 직접 관찰 가능한 호출만 기록한다. 통계 UseCase(`ProjectEngagementStatisticMetricUseCase` 등), `projectExternalStatisticUseCase`(DataPlus 호출 주체)는 외부 jar(`funding-core`)에 있어 내부 호출 순서는 확인 불가.

---

## 1. Studio 프로젝트 대시보드 (`/api/studio/dashboard/projects/{projectNo}`)

### 1.1 GET `/` — 프로젝트 현황 정보

- **Method**: `StudioProjectDashBoardController.get`
- **Cache**: `@Cacheable`

**Response**: `StudioProjectDashBoardResponse` — 폴리시 기반 집계 (`StudioProjectDashBoardPolicyUseCase.get`) 결과

### 1.2 GET `/wishes/country-count` — 찜하기 국가 건수 (Deprecated)

| Query | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `timezone` | `String` | ⬜ | IANA Time Zone |
| `isShippable` | `Boolean` | ⬜ | 발송 가능 국가만 |

**Response**: `WishCountryCountResponse`

→ `ProjectWishCountryCountUseCase.countCountry(FUNDING, projectNo, isShippable, zoneId)` (funding-core)

### 1.3 GET `/wishes/country-ranking` — 찜하기 국가 순위

**Response**: `List<StudioDashBoardCountryRankingResponse>`

MySQL (`WishMapper.findAllCountryRanking`):
```sql
SELECT UWP.CountryCode, COUNT(*) AS value
FROM UserWishProject UWP
-- type = 'FUNDING'일 때 추가:
LEFT JOIN CampaignShippingCountry CSC
       ON CSC.CampaignId = UWP.ProjectNo AND UWP.CountryCode = CSC.CountryCode
WHERE UWP.IsDel = FALSE
  AND UWP.ProjectNo = ?
  AND UWP.ProjectType = ?
  -- isShippable=true: AND CSC.CountryCode IS NOT NULL
GROUP BY UWP.CountryCode
ORDER BY value DESC
```

### 1.4 GET `/payments/country-ranking` — 결제 국가 순위

**Response**: `List<StudioDashBoardCountryRankingResponse.Payment>`

MySQL (`BackingPaymentMapper.findAllCountryRanking`):
```sql
SELECT BP.CountryCode, COUNT(*) AS value, IFNULL(SUM(BP.FundingAmount),0) AS amount
FROM BackingPayment BP
WHERE BP.CampaignId = ?
  AND BP.IsCanceled = false
GROUP BY BP.CountryCode
ORDER BY value DESC
```

### 1.5 GET `/dataplus/{key}` — 데이터 플러스 키별 조회 (Deprecated)

| Path | 설명 |
|---|---|
| `key` | `total_inflow`, `funding_payment`, `action`, `gender`, `age` 중 하나 |

**Response**: `Map<String, Object>` (DataPlus raw 응답)

→ **외부 DataPlus API** 호출. 이 레포에서 구체 요청 구조 확인 불가.

---

## 2. Acquisition(유입 분석) 대시보드 (`.../acquisitions`)

| # | Method | Path | 설명 |
|---|---|---|---|
| 2.1 | GET | `/cards/data` | 유입 카드 (OVERVIEW/FULL) |
| 2.2 | GET | `/charts/trend-by-source/data` | 유입 경로별 추이 차트 |
| 2.3 | GET | `/tables/by-source/data` | 유입 경로별 테이블 (페이징) |
| 2.4 | GET | `/tables/by-source/download` | 테이블 다운로드 (XLSX / CSV) |

### 2.1 카드 조회

**Query**: `timezone` ✅, `preset` (`OVERVIEW`(기본)/`FULL`)

**내부 동작**: `StudioDashBoardCardPreset.PROJECT_ACQUISITION_{OVERVIEW|FULL}_METRIC_KEY` 상수 리스트의 순서대로 메트릭 요청. `ProjectAcquisitionStatisticMetricUseCase.getMetrics` 호출.

### 2.2~2.4 Trend / Table

- Trend: `DataplusTrendQuery` 변환해서 `projectExternalStatisticUseCase.getAcquisitionTrend` 호출 → DataPlus API
- Table data: `projectExternalStatisticUseCase.getAcquisitionTrendItem(projectNo, zone, pages)` → DataPlus
- Download: 동일 데이터를 `Pages.of(0, 1000)` 최대 1000건으로 받아 `ProjectAcquisitionRowDataConverter`로 행 변환 후 Excel/CSV 스트리밍

### DB 호출
**없음.** 전부 DataPlus 외부 API. 이 레포의 MySQL Mapper 미사용.

---

## 3. Engagement(결제 분석) 대시보드 (`.../engagements`)

| # | Method | Path | 설명 |
|---|---|---|---|
| 3.1 | GET | `/cards/data` | 결제 카드 (OVERVIEW/FULL) |
| 3.2 | GET | `/charts/payment-trend/data` | 결제 추이 (시계열) |
| 3.3 | GET | `/charts/payment-trend/download` | 결제 추이 다운로드 |
| 3.4 | GET | `/tables/reward-ranking/data` | 리워드 순위 (페이징) |
| 3.5 | GET | `/tables/reward-ranking/download` | 리워드 순위 다운로드 |

### 3.2 결제 추이 차트

**Request** (`@ModelAttribute StudioDashBoardChartRequest`):
| 필드 | 타입 | 설명 |
|---|---|---|
| `countryCode` | `String` | null이면 전체 국가 |
| `withReferenceMetric` | `Boolean` | 기준 지표 포함 여부 |
| `from / to` | `LocalDateTime` | 기간 |
| `granularity` | enum (HOURLY/DAILY/WEEKLY/MONTHLY) | 시간 단위 |
| `aggregation` | enum (VALUE/CUMULATIVE) | 값/누적 |

→ `CountsByGranularityQueryFactory.create()`로 Query 구성 후 `projectEngagementStatisticTimeSeriesUseCase.getPaymentTimeSeries` 호출.

### 3.3 다운로드
- `granularity = DAILY`, `aggregation = CUMULATIVE` 고정
- 국가명 i18n: `countryFinder.getByCodeSafely(code).map(CountryResult::getName)` or `messageResolver.get(TEXT_ALL_COUNTRIES)`
- 파일명 template: `({projectNo}) {i18n_file_name}_{countryName}_{from}_{to}`

### 3.4 리워드 순위 — MySQL 사용 엔드포인트

Proxy `getRewardRanking(projectNo, pages, Sorts.by(desc("amount")))` → `BackingPaymentRewardRankingUseCase.getAll` (funding-core).

**Gateway 구현체가 본 레포에 없음**(`BackingPaymentRewardRankingUseCase` 직접 조회) — UseCase가 `BackingPaymentMapper` 계열을 사용하는 것으로 추정되지만 정확한 SQL은 funding-core 확인 필요.

### 3.5 다운로드
`Pages.unpaged()` 로 전량 조회 후 `RewardRankingRowDataConverter` 변환. Excel은 `RankNo` 컬럼 포함(`writeWithSchemaWithRowNo`).

---

## 4. Supporter 대시보드 (`.../supporters`)

| # | Method | Path | 설명 |
|---|---|---|---|
| 4.1 | GET | `/cards/data` | 서포터 카드 (OVERVIEW/FULL) |
| 4.2 | GET | `/charts/age-gender-count/data` | 나이/성별 추이 |
| 4.3 | GET | `/tables/items/data` | 서포터 테이블 (페이징) |
| 4.4 | GET | `/tables/items/download` | 서포터 테이블 다운로드 |

### 4.2 나이/성별 (`getSupporterAgeGenderCount`)

**Response**: `StudioDashBoardDemographicChartResponse{demographics: List<Map<String,Object>>}`

→ `projectExternalStatisticUseCase.getSupporterAgeGenderCount(projectNo)` — **DataPlus 외부 API**

### 4.3 서포터 테이블 (`getAllSupporterItem`)

**정렬**: `Sorts.by(desc("RegDate"))`

**Response**: `PageResult<StudioDashBoardSupporterTableItemResponse>`

→ `projectSupporterItemUseCase.getAll` (funding-core). 이 UseCase는 MySQL `BackingPayment`/`UserProfile` 조합 조회로 추정되나 이 레포 Gateway 구현체 직접 관찰 불가.

### 4.4 다운로드
`Pages.unpaged()` + `SupporterRowDataConverter.to(items, zone)` + Excel/CSV 스트리밍.

---

## 5. ComingSoon 대시보드 (`/api/studio/dashboard/coming-soons/{projectNo}`)

**16개** 엔드포인트. 3개 서브 섹션:

### 5.1 루트 + 참여현황 (engagements)

| # | Method | Path | 설명 |
|---|---|---|---|
| 5.1.1 | GET | `/` | 전체 개요 |
| 5.1.2 | GET | `/engagements/cards/data` | 카드 (OVERVIEW/FULL) |
| 5.1.3 | GET | `/engagements/q1/cards/data` | Q1 카드 (Deprecated) |
| 5.1.4 | GET | `/engagements/q2/cards/data` | Q2 카드 (Deprecated) |
| 5.1.5 | GET | `/engagements/charts/open-notify-subscriber-count/data` | 알림신청 추이 차트 |
| 5.1.6 | GET | `/engagements/charts/open-notify-subscriber-count/download` | 알림신청 추이 다운로드 |

차트 로직은 **3번(결제 추이)와 동일 패턴**. UseCase만 다름(`getEngagementOpenNotifySubscriberCountChart`).

### 5.2 유입 분석 (acquisitions) — 4개

| # | Method | Path | 설명 |
|---|---|---|---|
| 5.2.1 | GET | `/acquisitions/cards/data` | 카드 |
| 5.2.2 | GET | `/acquisitions/charts/trend-by-source/data` | 유입 경로 추이 |
| 5.2.3 | GET | `/acquisitions/tables/by-source/data` | 유입 경로 테이블 |
| 5.2.4 | GET | `/acquisitions/tables/by-source/download` | 테이블 다운로드 |

Project Acquisition(2번)과 동일 구조. 단 `ComingSoonAcquisitionExportRowData` / 별도 DataPlus 엔드포인트 (`/dataplus/v1/coming-soons/{projectNo}/traffic/status/channels`).

### 5.3 알림신청자 정보 (open-notify-subscribers) — 6개

| # | Method | Path | 설명 |
|---|---|---|---|
| 5.3.1 | GET | `/open-notify-subscribers/cards/data` | 카드 (OVERVIEW/FULL) |
| 5.3.2 | GET | `/open-notify-subscribers/q3/cards/data` | Q3 카드 (Deprecated) |
| 5.3.3 | GET | `/open-notify-subscribers/charts/age-gender-count/data` | 나이/성별 |
| 5.3.4 | GET | `/open-notify-subscribers/tables/items/data` | 알림신청자 테이블 (페이징) |
| 5.3.5 | GET | `/open-notify-subscribers/tables/items/download` | 테이블 다운로드 |
| 5.3.6 | GET | `/open-notify-subscribers/country-ranking` | 국가 순위 |

### 5.3.4 테이블 (`getAllOpenNotifySubscriberItem`)
**정렬**: `Sorts.by(desc("Registered"))`
`UserItem` 반환 (Purchaser가 아님).

### 5.3.6 국가 순위 — MySQL

`ComingSoonApplicantMapper.findAllCountryRanking`:
```sql
SELECT RCSA.CountryCode AS countryCode, COUNT(*) AS value
FROM RewardComingSoonApplicant RCSA
     LEFT JOIN CampaignShippingCountry CSC
            ON CSC.CampaignId = RCSA.CampaignId AND RCSA.CountryCode = CSC.CountryCode
WHERE RCSA.CampaignId = ?
  AND RCSA.IsCanceled = false
  -- isShippable=true: AND CSC.CountryCode IS NOT NULL
  -- isShippable=false: AND CSC.CountryCode IS NULL
GROUP BY RCSA.CountryCode
ORDER BY value DESC
```

**접근 테이블**: `RewardComingSoonApplicant`, `CampaignShippingCountry`

---

## 6. Maker 대시보드 (`/api/maker-dashboard`, `/api/v1/maker-dashboard`)

메이커(사용자) 기준 전체 프로젝트 요약. **MySQL `MakerDashboardMapper` 집중 사용**.

| # | Method | Path | 설명 |
|---|---|---|---|
| 6.1 | GET | `/openDisclosures` | 공개 유도 (Deprecated, `@Impersonatable`) |
| 6.2 | GET | `/cards` | 응원지표 + 진행중 프로젝트 (Deprecated, `@Impersonatable`) |
| 6.3 | GET | `/settlements` | 정산 대시보드 목록 (`@Impersonatable`) |
| 6.4 | GET | `/settlements/{campaignId}` | 특정 프로젝트 정산 |
| 6.5 | GET | `/settlement-system/{campaignId}` | 정산 시스템 타입 |
| 6.6 | GET | `/settlements/expected-date` | 정산 예정일 계산 |

### 6.1 GET `/openDisclosures` (Deprecated)

**Response**: `OpenDisclosuresInfo { openDisclosuresList[], recentEditCampaign? }`

**MySQL** (`MakerDashboardMapper`):

`getRecentEditCampaign`:
```sql
SELECT C.CampaignId, PC.PhotoUrl, C.Title
FROM Campaign C
     LEFT JOIN PhotoCommon PC ON C.PhotoId = PC.PhotoId
WHERE C.UserId = ?
  AND C.IsSubmitted = FALSE
  AND C.IsDel = FALSE
ORDER BY C.WhenCreated DESC
LIMIT 1
```

`getOpenDisclosures`:
```sql
SELECT C.CampaignId, PC.PhotoUrl, C.Title, CS.StatusUpdated
FROM Campaign C
     INNER JOIN PhotoCommon PC ON C.PhotoId = PC.PhotoId
     INNER JOIN CampaignScreening CS
             ON C.CampaignId = CS.CampaignId
            AND CS.ScrType = 'S'
            AND CS.StatusCode = 'STORY_APPROVAL'
     LEFT JOIN CampaignAutoOpen CAO ON C.CampaignId = CAO.CampaignId
WHERE C.UserId = ?
  AND C.IsDel = FALSE
  AND C.IsOpen = FALSE
  AND CAO.CampaignId IS NULL
ORDER BY StatusUpdated
LIMIT 3
```

**접근 테이블**: `Campaign`, `PhotoCommon`, `CampaignScreening`, `CampaignAutoOpen`

### 6.2 GET `/cards` (Deprecated)

복잡한 로직. `DashboardCards { summaryInfoCard, productCards[], productSimpleCards, contactUs }` 구조.

**단일 요청에 발생하는 SQL (관찰)**:

① `getSummaryExceptionInfo` (요약 예외 판정)
```sql
SELECT A.OpenCount, B.IngCount, CS.ComingSoonCount
FROM (SELECT COUNT(*) AS OpenCount FROM Campaign
      WHERE UserId = ? AND IsDel = FALSE AND IsOpen = TRUE) A,
     (SELECT COUNT(*) AS IngCount FROM Campaign
      WHERE UserId = ? AND IsDel = FALSE AND IsOpen = TRUE AND WhenHoldTo >= NOW()) B,
     (SELECT COUNT(*) AS ComingSoonCount
      FROM RewardComingSoon RCS
           INNER JOIN Campaign C
                      ON RCS.CampaignId = C.CampaignId AND C.UserId = ? AND C.IsDel = FALSE
      WHERE RCS.Status = 'IN_PROGRESS') CS
```

② `getHoldToAddMonth`:
```sql
SELECT DATE_ADD(WhenHoldTo, INTERVAL 6 MONTH) AS CheckDate
FROM Campaign
WHERE UserId = ? AND IsDel = FALSE AND IsOpen = TRUE AND WhenHoldTo < NOW()
ORDER BY WhenHoldTo DESC
LIMIT 1
```

③ `getSummaryInfoCard` (찜/결제/지지/앵콜 당일 건수 — UNION ALL 4단)
```sql
-- [1] 당일 신규 찜
SELECT COUNT(*) AS SummaryData, 'Wish' AS SummaryType
FROM UserWishProject UWP
     INNER JOIN Campaign C ON UWP.ProjectNo = C.CampaignId AND C.UserId = ? AND C.IsDel = FALSE
WHERE UWP.ProjectType IN ('FUNDING','PREORDER')
  AND UWP.sourceType IN ('APPLICANT','WISH')
  AND UWP.IsDel = FALSE
  AND UWP.Updated BETWEEN <오늘 00:00:00> AND <오늘 23:59:59>
UNION ALL
-- [2~4] 결제/지지서명/앵콜 집계 (유사 구조, BackingPayment·Signature·CampaignAskForEncore 테이블 사용)
...
```

④ 진행 중 프로젝트별 `getOnGoingProject` → 각 row마다 `getOnGoingComingSoon` 또는 `getOnGoingFunding` 조회 (N+1 구조)

⑤ `getAllContactUsQty`:
```sql
SELECT COUNT(*) FROM CampaignContactUs ...
```

⑥ `getEncoreCards`:
```sql
SELECT SUM(CASE WHEN ... <= DATE_SUB(NOW(), INTERVAL ? DAY) THEN 1 ELSE 0 END) AS EncoreCountWithin30Days,
       SUM(CASE WHEN ... > DATE_SUB(NOW(), INTERVAL ? DAY) THEN 1 ELSE 0 END) AS EncoreCountAfter30Days,
       CAE.CampaignId, C.Title, PC.ThumbnailUrl, C.BizModel, C.HostName AS MakerName, CCM.CategoryCode
FROM CampaignAskForEncore CAE
     INNER JOIN Campaign C ON CAE.CampaignId = C.CampaignId
     INNER JOIN PhotoCommon PC ON C.PhotoId = PC.PhotoId
     INNER JOIN CampaignCategoryMapping CCM ON CCM.CampaignId = CAE.CampaignId AND CCM.IsPrime = TRUE
     LEFT JOIN StoreOpenNotification SON
               ON SON.CampaignId = CAE.CampaignId
              AND SON.NotificationType = 'BIZ_MESSAGE'
              AND SON.TargetType = 'ENCORED'
WHERE CAE.IsCancel = FALSE
  AND C.UserId = ?
  AND C.WhenHoldTo < CURRENT_DATE
  AND SON.NotificationId IS NULL
GROUP BY CAE.CampaignId
HAVING COUNT(*) >= ?
ORDER BY C.WhenHoldTo DESC
```

**접근 테이블**: `Campaign`, `RewardComingSoon`, `UserWishProject`, `BackingPayment`, `PhotoCommon`, `CampaignCategoryMapping`, `CampaignAskForEncore`, `StoreOpenNotification`, `CampaignContactUs`, `Signature`(추정)

### 6.3 GET `/settlements` — 정산 스케줄 목록

**Response**: `List<SettlementScheduleResultItem>`

1. `makerDashboardProxy.getSettlementSchedules(userId)` 호출
2. 내부적으로 `SettlementClient.getSettlementSchedule(query)` — **정산 외부 서비스 API** 호출 (`SettlementClient`는 별도 서비스 HTTP Client)
3. 실패 시 빈 리스트 반환 (`Collections.EMPTY_LIST`)

**DB 호출 없음** (이 경로에서는).

### 6.4 GET `/settlements/{campaignId}` — 특정 프로젝트 정산

1. `makerDashboardProxy.getSettlementSchedules([campaignId])` — 위와 같은 외부 호출
2. 추가로 MySQL `MakerDashboardMapper.getSettlementSchedules`:
```sql
SELECT C.CampaignId, C.Title, PC.PhotoUrl AS Thumbnail, CCR.Email, C.WhenHoldTo,
       IF(CONCAT(CCI.InvoiceRecipient, CCI.AccountNumber, CCI.AccountHolder) IS NULL, TRUE, FALSE) AS SubmitRequired,
       CASE
         WHEN CM.IntValue1 = 1 THEN (SELECT EventDate FROM EventDay
                                     WHERE EventDate < DATE_ADD(C.WhenHoldTo, INTERVAL 30 DAY)
                                       AND EventDate > C.WhenHoldTo
                                       AND Type = 'o'
                                     LIMIT 3, 1)
         WHEN CM.IntValue1 IS NULL THEN DATE_ADD(C.WhenHoldTo, INTERVAL 2 DAY)
       END AS FinalPaymentDate,
       IFNULL(CAC.AgreeConclusionNeed, FALSE) AS AgreementRequired,
       IFNULL(RIM.NeedToModify, FALSE) AS UpdatingRequired,
       IF(C.TargetAmount <= (SELECT IFNULL(SUM(FundingAmount),0) FROM BackingPayment
                             WHERE IsCanceled = FALSE AND CampaignId = C.CampaignId),
          TRUE, FALSE) AS SuccessfulEnded,
       CCM.CategoryCode, CM2.CategoryId
FROM Campaign C
     LEFT JOIN RewardComingSoon RCS                 ON RCS.CampaignId = C.CampaignId
     LEFT JOIN PhotoCommon PC                       ON PC.PhotoId = C.PhotoId
     INNER JOIN CampaignContractRepresentative CCR  ON C.CampaignId = CCR.CampaignId
     LEFT JOIN CampaignContractInfo CCI             ON CCI.CampaignId = C.CampaignId
     LEFT JOIN CampaignAgreeConclusion CAC          ON CAC.CampaignId = C.CampaignId
     LEFT JOIN RewardSettlementInfoModifyNeed RIM   ON RIM.CampaignId = C.CampaignId
     LEFT JOIN CampaignMarker CM
               ON C.CampaignId = CM.CampaignId AND CM.MarkerId = 'PAYMENT_VERSION' AND CM.OrderNo = 1
     LEFT JOIN CampaignCategoryMapping CCM          ON C.CampaignId = CCM.CampaignId AND CCM.IsPrime = TRUE
     LEFT JOIN CategoriesMappings CM2               ON C.CampaignId = CM2.CampaignId
WHERE C.CampaignId IN (?, ?, ...)
ORDER BY C.WhenOpen
```

**접근 테이블**: `Campaign`, `RewardComingSoon`, `PhotoCommon`, `CampaignContractRepresentative`, `CampaignContractInfo`, `CampaignAgreeConclusion`, `RewardSettlementInfoModifyNeed`, `CampaignMarker`, `EventDay`, `BackingPayment`, `CampaignCategoryMapping`, `CategoriesMappings`

### 6.5 GET `/settlement-system/{campaignId}` — 정산 시스템

**Response**: `SettlementSystemResponse { campaignId, systemType }`

→ `settlementProxy.getSettlementSystem(campaignId)` — 이미 정산 문서 5번 참조 (`SettlementSystemRepository.findById`)

### 6.6 GET `/settlements/expected-date` — 정산 예정일 계산

| Query | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `deliveryEndDate` | `ZonedDateTime` (ISO DATE_TIME) | ✅ | 배송 완료 일시 |

**Response**: `CalculationSettlementScheduleResponse`

→ `makerDashboardProxy.getCalculationSettlementScheduleItem(deliveryEndDate)` — funding-core 계산 로직 (영업일 + 정책 기반).

---

## 7. 공통 Request/Response DTO

### `StudioDashBoardCardPreset` (enum)
- `OVERVIEW` — 개요 카드
- `FULL` — 전체 카드

각 섹션별 `*_OVERVIEW_METRIC_KEY` / `*_FULL_METRIC_KEY` 정적 List<StatisticMetricKey> 보유.

### `StudioDashBoardCardsResponse`
카드 메트릭 배열 (각 카드에 key, label, value, unit, diff 등).

### `StudioDashBoardChartRequest` (시계열 공용)
- `countryCode`: String?
- `withReferenceMetric`: Boolean
- `from / to`: LocalDateTime
- `granularity`: HOURLY/DAILY/WEEKLY/MONTHLY
- `aggregation`: VALUE/CUMULATIVE

### `StudioDashBoardTimeSeriesChartResponse`
시계열 포인트 배열 (timestamp, value, referenceValue).

### `DownloadFormat` enum
`XLSX`, `CSV`

### `StudioDashBoardDownloadRequest`
차트 다운로드 요청 (기간, 포맷, 국가 등).

---

## 8. 참고 — 이 문서의 Gateway / Repository / Mapper

### Gateway 구현체 (이 레포 `adapter/infrastructure`)

| 구현체 | 주요 메서드 → 대상 |
|---|---|
| `MakerDashboardQueryGatewayImpl` | `getOpenDisclosures` / `getCards` / `getProjectsSchedule` / `getSettlementScheduleCards` — `MakerDashboardMapper` + `SettlementClient` 외부 API |

**그 외 Dashboard 관련 Gateway 구현체가 이 레포에 별도 존재하지 않음**. Studio 계열 대시보드의 통계 조회는 funding-core의 `Project*StatisticMetricUseCase` / `Project*StatisticTimeSeriesUseCase` / `ProjectExternalStatisticUseCase` 내부에서 DataPlus API 호출 + 보조 MySQL Mapper (WishMapper / BackingPaymentMapper / ComingSoonApplicantMapper / …) 를 조합해 처리.

### 관찰 가능한 MySQL Mapper XML

| Mapper 파일 | 주요 쿼리 |
|---|---|
| `MakerDashboardMapper.xml` | getRecentEditCampaign, getOpenDisclosures, getSummaryExceptionInfo, getHoldToAddMonth, getSummaryInfoCard, getOnGoingProject, getOnGoingComingSoon, getOnGoingFunding, getAllContactUsQty, getSettlementSchedules, getEncoreCards |
| `WishMapper.xml` | `findAllCountryRanking` (찜 국가 순위) |
| `BackingPaymentMapper.xml` | `findAllCountryRanking` (결제 국가 순위) |
| `ComingSoonApplicantMapper.xml` | `findAllCountryRanking` (알림신청 국가 순위) |

### 외부 API

| 서비스 | 용도 |
|---|---|
| **DataPlus** (`https://dev-api.wadizdata.team/dataplus/...`) | 유입 분석, 행동 추이, 나이/성별, AgeGender |
| **Settlement Service** (`SettlementClient`) | `getSettlementSchedule` — 정산 스케줄 조회 |
| **Store API** (본 문서에선 미사용) | — |

### UseCase 중 이 레포에 Gateway 구현체가 **없는** 것 (funding-core 확인 필요)

- `StudioProjectDashBoardPolicyUseCase` (현황 조회)
- `ProjectEngagementStatisticMetricUseCase` / `ProjectAcquisitionStatisticMetricUseCase` / `ProjectSupporterStatisticMetricUseCase` — 카드 메트릭 집계
- `ProjectEngagementStatisticTimeSeriesUseCase` — 시계열
- `ProjectSupporterItemUseCase` — 서포터 아이템
- `ProjectExternalStatisticUseCase` — DataPlus 호출 주체
- `ProjectWishCountryCountUseCase` / `ProjectWishCountryRankingUseCase` / `BackingPaymentCountryRankingUseCase` / `BackingPaymentRewardRankingUseCase` — 집계

이들 UseCase가 위 Mapper 쿼리들을 내부적으로 호출한다고 추정되지만, 정확한 매핑은 funding-core 소스 확인 필요.

### 접근 테이블 합계 (이 문서 관찰 SQL 기준)

`Campaign`, `CampaignScreening`, `CampaignAutoOpen`, `CampaignAskForEncore`, `CampaignContactUs`, `CampaignContractInfo`, `CampaignContractRepresentative`, `CampaignAgreeConclusion`, `CampaignMarker`, `CampaignCategoryMapping`, `CategoriesMappings`, `CampaignShippingCountry`, `PhotoCommon`, `RewardComingSoon`, `RewardComingSoonApplicant`, `RewardSettlementInfoModifyNeed`, `EventDay`, `UserWishProject`, `BackingPayment`, `StoreOpenNotification`, + (Signature/UserProfile 등 추가 도메인 Mapper 필요 시)
