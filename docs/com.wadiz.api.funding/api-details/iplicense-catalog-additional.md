# IPLicense / Catalog / AdditionalService API 상세 스펙

IP 라이선스·메타 카탈로그 피드·부가서비스 관련 **18개 엔드포인트**.

- **대상 컨트롤러**:
  - `IPLicenseController` (`/api/iplicenses`) — 3개 (Public)
  - `IPLicenseAdminController` (`/api/admin/iplicenses`) — 8개 (`isAdmin`)
  - `CatalogController` (`/api/v1/catalog`) — 1개 (Public, 외부 Meta 연동)
  - `AdditionalServiceController` (`/api/additional-services`) — 3개 (`isMaker or isAdmin`, 마지막 1개는 `isAuthenticated`)
  - `AdditionalInternalServiceController` (`/api/internal/additional-services`) — 3개 (Admin)

- **저장소**: MySQL
- **주요 테이블**: `IPLicense`, `IPLicenseRelatedMapping`, `IPLicenseTopRank`, `IPLicenseTag`, `CampaignLanguage`, `Reward`, `RewardShippingCountry`, `CriteoFeedExclude`, `AdditionalService`, `CampaignAdditionalService`

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록.

---

## 1. GET `/api/iplicenses` — IP 홈 (Public, 페이징)

- **Method**: `IPLicenseController.list`
- **정렬**: `OrderNo asc, Seq desc`

### Request (Query, `IPLicenseCardListRequest`)
| 필드 | 타입 | 설명 |
|---|---|---|
| `tags` | `List<String>` | 태그 필터 |

### Response — `PageResult<IPLicenseCardListResponse>`
(Seq, ProgramName, CompanyName, Thumbnail, Tags 등)

### MySQL 쿼리 (`IPLicenseMapper.searchCardList` + `cardListCount`)
```sql
SELECT ...
FROM IPLicense IPL
     LEFT JOIN ...
WHERE IPL.IsHidden = FALSE AND IPL.IsTemporary = FALSE
  -- query.tags != empty: JOIN IPLicenseTag
-- + 페이징/정렬
```

**접근 테이블**: `IPLicense`, `IPLicenseTag`

---

## 2. GET `/api/iplicenses/{licenseKey}` — IP 상세 (Public)

- **Method**: `IPLicenseController.list(licenseKey)` (오버로딩)

### Response — `IPLicenseBasicResponse.IPLicenseResponse`

### MySQL 쿼리 (`IPLicenseMapper.detail` with `IPLicenseDetail` resultMap)
복합 조인으로 IPLicense + RelatedMapping + Tag 등 조회.

---

## 3. GET `/api/iplicenses/tags` — 연관 태그 목록

- **Method**: `IPLicenseController.tagList`

### Response
`ResponseWrapper<List<String>>`

### DB 호출
`IPLicenseProxy.tagList()` → IPLicense에 사용된 전체 태그 DISTINCT 목록 조회.

---

## 4. GET `/api/admin/iplicenses` — IP 전체 목록 (Admin, 페이징)

- **Method**: `IPLicenseAdminController.list`
- **정렬**: `Seq desc`

### Request (Query, `IPLicenseListRequest`)
| 필드 | 타입 | 설명 |
|---|---|---|
| `licenseSeq` | `Integer` | 식별자 |
| `programName` | `String` | 프로그램명 |
| `companyName` | `String` | 회사명 |
| `category` | `String` | 카테고리 |
| `name` | `String` | — |
| `contractFrom/To` | `LocalDate` | 계약 기간 |
| `isHidden / isTemporary / isTopRank` | `Boolean` | 상태 필터 |

### MySQL 쿼리 (`IPLicenseMapper.search` + `count`)
Admin 목록은 모든 상태 포함 조회 (IsHidden/IsTemporary 필터링 없음).

---

## 5. GET `/api/admin/iplicenses/{licenseKey}` — IP 상세 (Admin)

2번과 동일 SQL. 임시(Temporary) / 숨김(Hidden)도 포함해 조회.

---

## 6. PUT `/api/admin/iplicenses/{licenseKey}` — IP 게시

- **Method**: `IPLicenseAdminController.post`

임시 상태에서 게시 상태로 전환:
```sql
UPDATE IPLicense SET IsTemporary = FALSE, IsHidden = FALSE, Updated = NOW()
WHERE Seq = ?
```

---

## 7. POST `/api/admin/iplicenses` — IP 프로그램 저장

- **Method**: `IPLicenseAdminController.save`

### Request Body — `SaveIPLicenseRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `ipLicenseSeq` | `Integer` | null이면 신규, 있으면 수정 |
| `programName / companyName / name / category` | `String` | — |
| `isHidden` | `Boolean` | — |
| `contractFrom / contractTo` | `LocalDate` | — |
| `basicInfo / detail / introduction` | `String` | HTML |
| `relatedMapping[]` | List | 연관 프로젝트 매핑 |
| `notice` | `String` | — |
| `tags[]` | `List<String>` | — |

### Response — `SaveIPLicenseResponse{ipLicenseSeq}`

### DB 호출 (UPSERT 패턴)
- 신규: `IPLicense` INSERT (`IsTemporary = TRUE`)
- 수정: `IPLicense` UPDATE + `IPLicenseTag` / `IPLicenseRelatedMapping` 재구성

`registerUserId = SecurityUtils.currentUserId()`

---

## 8. DELETE `/api/admin/iplicenses/{licenseKey}` — IP 삭제

```sql
-- 소프트 삭제 또는 물리 삭제 (구현체 확인 필요)
UPDATE IPLicense SET IsDeleted = TRUE WHERE Seq = ?
-- 또는
DELETE FROM IPLicense WHERE Seq = ?
```

---

## 9. GET `/api/admin/iplicenses/top-ranks` — 상단 노출 설정 조회

- **Query**: `programName`

### MySQL 쿼리 (`IPLicenseMapper.searchTopRank`)
`IPLicenseTopRank` 테이블 기반 상단 우선 노출 설정 조회.

---

## 10. POST `/api/admin/iplicenses/top-ranks` — 상단 노출 설정

### Request Body — `CreateIPLicenseTopRankRequest{ranks[], programName}`

### DB 호출
`IPLicenseTopRank` DELETE + 배치 INSERT.

---

## 11. GET `/api/admin/iplicenses/campaigns/{campaignId}/related-mappings` — 프로젝트 연관 조회

- **Query**: `campaignType`

### Response — `RelatedMappingDetailResponse`

### DB 호출
`IPLicenseProxy.relatedMappingDetail(query)` → `IPLicenseRelatedMapping` + `Campaign` 조인.

---

## 12. GET `/api/v1/catalog/meta/feed/{countryCode}` — Meta 카탈로그 피드

- **Method**: `CatalogController.getMetaCatalogFeed`
- **Produces**: `text/plain;charset=UTF-8`

### Path
| 파라미터 | 타입 | 설명 |
|---|---|---|
| `countryCode` | `String` | `US`, `JP`, `TW` |

### Response
`ResponseEntity<String>` — **CSV 형식** Meta 광고 카탈로그 피드 (해당 국가에서 구매 가능한 프로젝트)

### 컨트롤러 코드 흐름
`catalogFeedProxy.getMetaCatalogFeed(countryCode)` → 내부에서 `CatalogFeedMapper.getCatalogFeedItems` 호출 후 `CatalogFeedCsvConverter` 로 CSV 변환.

### MySQL 쿼리 (`CatalogFeedMapper.getCatalogFeedItems`)

```sql
SELECT RCS.CampaignId AS projectNo,
       COALESCE(CL.Title, CL_EN.Title, C.Title) AS projectTitle,
       COALESCE(CL.CoreMessage, CL_EN.CoreMessage, C.CoreMessage) AS projectDescription,
       COALESCE(CL.PhotoUrl, CL_EN.PhotoUrl, P.PhotoUrl) AS photoUrl,
       C.HostName AS makerName, C.IsAdultContent,
       FirstReward.Amount AS price,
       CASE
         WHEN RCS.Status = 'IN_PROGRESS' THEN '오픈예정'
         WHEN C.WhenOpen <= NOW() AND C.WhenClose >= NOW() THEN '본펀딩'
       END AS status,
       IF(FirstReward.LimitCount > IFNULL(
           (SELECT SUM(BK.Qty) FROM BackingPayment BP
            INNER JOIN BackingPaymentMapping BPM ON BPM.BackingPaymentId = BP.BackingPaymentId
            INNER JOIN Backing BK ON BK.BackingId = BPM.BackingId
            WHERE BP.CampaignId = C.CampaignId
              AND BK.RewardId = FirstReward.RewardId
              AND BP.IsCanceled = FALSE), 0),
         TRUE, FALSE) AS inStock,
       CCM.CategoryCode AS categoryCode1,
       CCM2.CategoryCode AS categoryCode2
FROM RewardComingSoon RCS
     INNER JOIN Campaign C ON RCS.CampaignId = C.CampaignId
     INNER JOIN PhotoCommon P ON P.PhotoId = C.PhotoId
     LEFT JOIN CampaignLanguage CL_EN
            ON CL_EN.CampaignId = C.CampaignId AND CL_EN.LanguageCode = 'en'
     LEFT JOIN CampaignLanguage CL
            ON CL.CampaignId = C.CampaignId AND CL.LanguageCode = ?
     LEFT JOIN CampaignCategoryMapping CCM
            ON CCM.CampaignId = C.CampaignId AND CCM.IsPrime = TRUE
     LEFT JOIN CampaignCategoryMapping CCM2
            ON CCM2.CampaignId = C.CampaignId AND CCM2.IsPrime = FALSE
     INNER JOIN (
       SELECT R.CampaignId, MIN(R.RewardId) AS MinRewardId
       FROM Reward R
            INNER JOIN RewardShippingCountry RSC
                   ON R.RewardId = RSC.RewardId AND RSC.CountryCode = ?
       WHERE R.IsDeleted = FALSE
       GROUP BY R.CampaignId
     ) MinReward ON MinReward.CampaignId = C.CampaignId
     INNER JOIN Reward FirstReward ON FirstReward.RewardId = MinReward.MinRewardId
     LEFT JOIN CriteoFeedExclude CFE
            ON CFE.CampaignId = C.CampaignId AND CFE.CampaignType = 'RWD'
WHERE (RCS.Status = 'IN_PROGRESS' AND RCS.IsPreReservation = FALSE)
   OR (C.WhenOpen <= NOW() AND C.WhenClose >= NOW() AND C.IsHidden = FALSE)
    AND CFE.CampaignId IS NULL
ORDER BY RCS.PostedAt, C.WhenOpen
```

**특징**:
- `COALESCE`로 언어 fallback (국가별 언어 → 영어 → 원문)
- `FirstReward` subquery로 프로젝트당 최저 RewardId 선택 (가격 대표값)
- `RewardShippingCountry.CountryCode = ?` 조건으로 해당 국가 배송 가능 리워드만 포함
- `CriteoFeedExclude`로 제외 프로젝트 필터
- `inStock` 계산: 리워드 잔여 수량 > 0 여부

**접근 테이블**: `RewardComingSoon`, `Campaign`, `PhotoCommon`, `CampaignLanguage`, `CampaignCategoryMapping`, `Reward`, `RewardShippingCountry`, `BackingPayment`, `BackingPaymentMapping`, `Backing`, `CriteoFeedExclude`

### 외부
응답 포맷: **CSV** (text/plain) — Meta 광고 플랫폼이 주기적으로 크롤링.

---

## 13. POST `/api/additional-services/{projectNo}` — 부가서비스 신청/재신청

- **Method**: `AdditionalServiceController.requestService`
- **Security**: `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`

### Request Body — `RequestServiceRequest`
(serviceCode, additionalServiceData)

### Response — `CampaignAdditionalServiceResponse`

### DB 호출
`additionalServiceProxy.requestService(userId, projectNo, request)` → funding-core.

`CampaignAdditionalServiceMapper.upsertCampaignService` (settlement.md 26번에서 관찰된 SQL):
```sql
INSERT INTO CampaignAdditionalService
  (CampaignId, AdditionalServiceCode, IsRequested, Requested, RequestedUserId, Status, AdditionalServiceData)
VALUES (?, ?, TRUE, NOW(), ?, ?, ?)
ON DUPLICATE KEY UPDATE
  IsRequested = TRUE, Requested = NOW(),
  RequestedUserId = ?, Status = ?, AdditionalServiceData = ?, Updated = CURRENT_TIMESTAMP
```

---

## 14. GET `/api/additional-services/{projectNo}` — 캠페인 부가서비스 목록

- **Method**: `AdditionalServiceController.getCampaignServices`

### MySQL 쿼리 (`CampaignAdditionalServiceMapper.findByProjectNo`) — settlement.md 참조

```sql
SELECT CampaignId, AdditionalServiceCode, IsRequested, Requested, RequestedUserId,
       Status, AdditionalServiceData, Registered, Updated
FROM CampaignAdditionalService
WHERE CampaignId = ?
ORDER BY Requested DESC
```

---

## 15. GET `/api/additional-services` — 전체 부가서비스 목록 (활성)

- **Method**: `AdditionalServiceController.getAllServices`
- **Security**: `@PreAuthorize("isAuthenticated()")`

### Response — `List<AdditionalServiceResponse>`
(serviceCode, displayName, description, price, isActive)

### MySQL 쿼리 (`AdditionalServiceMapper.findAllActiveServices`)

```sql
SELECT * FROM AdditionalService WHERE IsActive = TRUE
```

**접근 테이블**: `AdditionalService`

---

## 16. PUT `/api/internal/additional-services/{projectNo}/services/{serviceCode}/approve` — 승인 (Admin)

- **Method**: `AdditionalInternalServiceController.approveService`

### Request Body — `AdminServiceRequest{adminUserId}`

### Response — `ServiceOperationResponse`
- `AdditionalServiceNotFoundException` → `SERVICE_NOT_FOUND`
- `AdditionalServiceStateException` → `INVALID_SERVICE_STATE`
- 기타 → `INTERNAL_ERROR`

### DB 호출
`CampaignAdditionalService.Status` UPDATE (예: `REQUESTED` → `APPROVED`).

---

## 17. PUT `/api/internal/additional-services/{projectNo}/services/{serviceCode}/reject` — 반려 (Admin)

16번과 동일 패턴. `Status` → `REJECTED`.

---

## 18. PUT `/api/internal/additional-services/{projectNo}/services/pd-consulting/manual-request` — PD 컨설팅 수동 신청

- **Method**: `AdditionalInternalServiceController.requestService`

관리자가 PD 컨설팅 부가서비스를 수동으로 신청. 13번과 동일한 UPSERT 패턴이나 `serviceCode`는 `PD_CONSULTING` 고정.

### Request Body — `AdminServiceRequest{adminUserId, additionalServiceData}`

---

## 19. 참고 — 이 문서의 Gateway / Mapper

### Gateway 구현체 (이 레포)
| 구현체 | 대상 |
|---|---|
| `IPLicenseGatewayImpl` | `IPLicense*Repository` — save/delete/post |
| `IPLicenseQueryGatewayImpl` | `IPLicenseMapper` (search/count/detail/searchTopRank/searchCardList/cardListCount) |
| `CatalogFeedService` + `CatalogFeedProxy` | `CatalogFeedMapper.getCatalogFeedItems` → `CatalogFeedCsvConverter` |
| `AdditionalServiceGateway` (추정) | `AdditionalServiceMapper`, `CampaignAdditionalServiceMapper` (settlement 문서 참조) |

### MyBatis Mapper XML
- `IPLicenseMapper.xml` — `search` / `count` / `detail` / `searchTopRank` / `searchCardList` / `cardListCount`
- `CatalogFeedMapper.xml` — `getCatalogFeedItems` (언어 COALESCE + 국가별 배송 가능 리워드 필터)
- `additionalservice/AdditionalServiceMapper.xml` — `findByServiceCode`, `findAllActiveServices`
- `additionalservice/CampaignAdditionalServiceMapper.xml` — `findByProjectNo`, `upsertCampaignService`, `updateIsRequested` (settlement.md 참조)

### 접근 테이블
`IPLicense`, `IPLicenseTag`, `IPLicenseRelatedMapping`, `IPLicenseTopRank`, `RewardComingSoon`, `Campaign`, `CampaignLanguage`, `CampaignCategoryMapping`, `PhotoCommon`, `Reward`, `RewardShippingCountry`, `BackingPayment`, `BackingPaymentMapping`, `Backing`, `CriteoFeedExclude`, `AdditionalService`, `CampaignAdditionalService`

### 주요 enum
- `AdditionalServiceCode` — 서비스 유형 (PD_CONSULTING, ...)
- `AdditionalServiceStatus` — REQUESTED / APPROVED / REJECTED
