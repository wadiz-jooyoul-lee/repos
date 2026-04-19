# Campaign 공개 API 상세 스펙

프로젝트(캠페인) 공개 조회 API. 프론트엔드가 가장 많이 호출하는 경로로, **MySQL + MyBatis** 기반의 복합 집계 쿼리가 중심.

- **Controller**: `adapter/application/.../domain/campaign/CampaignController.java`
- **Base Path**: `/api/campaigns`, `/api/v1/campaigns` (동일 핸들러)
- **Proxy**: `CampaignProxy` — 대부분 `@Cacheable(cacheNames="campaign")` 적용
- **저장소**: MySQL (Spring Data JDBC + MyBatis)
- **Gateway 구현체**:
  - `CampaignGatewayImpl` — `CampaignRepository` (Spring Data JDBC) 사용
  - `CampaignQueryGatewayImpl` — `CampaignMapper`, `CampaignSummaryMapper`, `BackingPaymentMapper`, `RewardItemMapper`, `CampaignAskForEncoreMapper` 등 MyBatis Mapper들 조합
- **Mapper XML 위치**: `adapter/infrastructure/src/main/resources/mapper/CampaignMapper.xml`, `CampaignSummary.xml`, `BackingPaymentMapper.xml` 등

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록한다. `CampaignProxy`가 호출하는 UseCase 구현체는 외부 jar `com.wadiz.funding.core:funding-core` 에 있으며, UseCase 내부 호출 순서/분기는 이 레포에서 확인할 수 없다. 단, UseCase가 사용하는 QueryGateway 구현체와 그 구현체가 호출하는 Mapper XML SQL은 이 레포에 있으므로 추적 가능하다. 아래 "MySQL 쿼리" 섹션은 해당 SQL을 그대로 옮긴 것이다.

---

## 1. GET `/api/campaigns/card` — 프로젝트 메인 카드 목록 (페이징)

프로젝트 ID 목록을 받아 메인 카드용 요약 데이터를 페이징 반환.

- **Method**: `CampaignController.campaignCardList`
- **Cache**: `@Cacheable`

### Request — `CampaignCardListRequest` + `Pages` (쿼리 파라미터)

| 위치 | 필드 | 타입 | 필수 | 설명 |
|---|---|---|:---:|---|
| query | `campaignIds` | `List<Integer>` | ✅ `@NotEmpty` | 조회할 프로젝트 ID 목록 |
| query | `page` | `int` | ⬜ | 페이지 번호 (default 0) |
| query | `size` | `int` | ⬜ | 페이지 크기 (default 10) |
| query | `sort` | `String[]` | ⬜ | 정렬 조건 (기본 `CampaignId asc`) |

### Response — `PageResult<CampaignCardListResponse.Card>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `content[]` | `List<Card>` | 카드 목록 |
| `pages.page` | `int` | 현재 페이지 |
| `pages.size` | `int` | 페이지 크기 |
| `totalElements` | `long` | 전체 개수 |

#### `Card` 필드
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | 프로젝트 ID |
| `campaignTitle` | `String` | 제목 |
| `makerName` | `String` | 메이커 명 (HostName) |
| `photoUrl` | `String` | 카드 이미지 URL |
| `categoryId` | `Integer` | 카테고리 ID (CustValueCode) |
| `categoryName` | `String` | 카테고리 명 |
| `targetAmount` | `BigInteger` | 목표 금액 |
| `achievementRate` | `String` | 목표 달성률 |
| `remainDay` | `Long` | 잔여일수 |
| `totalBackedAmount` | `BigInteger` | 펀딩 금액 누계 |
| `whenHoldTo` | `LocalDateTime` | 종료 일시 (23:59:59로 보정) |

### 컨트롤러 코드 흐름

1. `@Valid`로 request 검증(`campaignIds` 비어있지 않음)
2. `CampaignCardListQuery`로 매핑 후 `campaignProxy.campaignCardList(query, pages, Sorts.by("CampaignId asc"))` 호출
3. 반환된 `PageResult<CampaignCardListResultItem>`을 `CampaignResponseConverter`로 `Card` 목록으로 변환
4. 새 `PageResult`로 래핑해 반환

### MySQL 쿼리 (이 레포 Gateway가 호출하는 SQL)

`CampaignQueryGatewayImpl.campaignCardInfoSearch`는 다음 두 쿼리를 순차 실행:

**① 카드 목록 조회** (`CampaignMapper.campaignCardInfoSearch`)
```sql
SELECT C.CampaignId,
       C.Title AS CampaignTitle,
       C.HostName AS MakerName,
       C.TargetAmount,
       C.WhenHoldTo,
       TO_DAYS(C.WhenHoldTo) - TO_DAYS(NOW()) AS RemainDay,
       PC.photoUrl,
       C.CustValueCode AS CategoryId,
       CV.Value AS CategoryName,
       (SELECT SUM(FundingAmount) FROM BackingPayment BP
        WHERE BP.CampaignId = C.CampaignId AND IsCanceled = FALSE) AS TotalBackedAmount
FROM Campaign C
     LEFT JOIN PhotoCommon PC ON PC.PhotoId = C.PhotoId
     LEFT JOIN CodeValue CV ON CV.Code = C.CustValueCode
WHERE C.IsOpen = TRUE
  AND C.IsDel = FALSE
  AND C.CampaignId IN (?, ?, ...)
-- + 페이징/정렬 절 (support.data.Clauses.pagesAndFallbackSorts)
```

**② 전체 개수** (`CampaignMapper.campaignCardInfoCount`)
```sql
SELECT COUNT(*)
FROM Campaign C
     LEFT JOIN PhotoCommon PC ON PC.PhotoId = C.PhotoId
     LEFT JOIN CodeValue CV ON CV.Code = C.CustValueCode
WHERE C.IsOpen = TRUE AND C.IsDel = FALSE
  AND C.CampaignId IN (?, ?, ...)
```

**접근 테이블**: `Campaign`, `PhotoCommon`, `CodeValue`, `BackingPayment`(서브쿼리)

---

## 2. GET `/api/campaigns/comingsoon/card` — 오픈예정 프로젝트 카드 목록 (페이징)

- **Method**: `CampaignController.comingSoonCardList`
- **Cache**: `@Cacheable`

### Request / Response
- Request: `/card`와 동일 (`campaignIds` + `Pages`)
- Response: `PageResult<CampaignCardListResponse.ComingSoonCard>`

#### `ComingSoonCard` 필드
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` ~ `categoryName` | (base와 동일) | — |
| `openDate` | `OpenDateResponse` | 오픈 예정 일시 |
| `isStandingBy` | `boolean` | 오픈예정 확정 여부 |

### MySQL 쿼리

**① 목록 조회** (`CampaignMapper.campaignComingSoonCardInfoSearch`)
```sql
SELECT C.CampaignId,
       C.Title AS CampaignTitle,
       C.HostName AS MakerName,
       PC.photoUrl,
       C.CustValueCode AS CategoryId,
       CV.Value AS CategoryName,
       AO.Scheduled AS OpenDate,
       C.IsStandingBy
FROM Campaign C
     JOIN RewardComingSoon CS ON CS.CampaignId = C.CampaignId
     JOIN CampaignAutoOpen AO ON AO.CampaignId = C.CampaignId
     LEFT JOIN PhotoCommon PC ON PC.PhotoId = C.PhotoId
     LEFT JOIN CodeValue CV ON CV.Code = C.CustValueCode
WHERE CS.Status = 'IN_PROGRESS'
  AND C.IsDel = FALSE
  AND C.CampaignId IN (?, ?, ...)
-- + 페이징/정렬 절
```

**② 카운트** — 동일 FROM/WHERE로 `COUNT(*)`

**접근 테이블**: `Campaign`, `RewardComingSoon`, `CampaignAutoOpen`, `PhotoCommon`, `CodeValue`

---

## 3. GET `/api/campaigns/{campaignId}/statistics-summation` — 통계 요약

펀딩 모집액·서포터 수·목표 달성 여부 등 통계 반환.

- **Method**: `CampaignController.getStatisticsSummation`
- **Cache**: `@Cacheable`

### Path / Response

| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `campaignId` | `Integer` | ✅ | 프로젝트 ID |

**Response** — `StatisticsSummationResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `isSuccessClose` | `Boolean` | 성공 종료 여부 |
| `isReachTargetAmount` | `Boolean` | 목표 달성 여부 |
| `totalFundingAmount` | `Long` | 펀딩 모집 금액 |
| `fundingSupporterQty` | `Long` | 서포터 건수 |

### MySQL 쿼리 (총 3회)

`CampaignQueryGatewayImpl.statisticsSummationInfo`는 3개 쿼리를 순차 실행:

**① 펀딩 집계** (`BackingPaymentMapper.backingSummationInfo`)
```sql
SELECT SUM(FundingAmount) AS BackingAmount,
       COUNT(*) AS BackingQty
FROM BackingPayment
WHERE CampaignId = ?
  AND PayStatus IN ('C10','Z11','P10','D11','E10')
```

**② 성공 종료 여부** (`CampaignMapper.isSuccessClose`)
```sql
SELECT IF(SUM(BP.FundingAmount) >= C.TargetAmount, true, false)
FROM Campaign C
     JOIN BackingPayment BP ON BP.CampaignId = C.CampaignId
WHERE C.WhenHoldTo <= NOW()
  AND C.CampaignId = ?
  AND BP.IsCanceled = FALSE
```

**③ 목표 달성 여부** (`CampaignMapper.isReachTargetAmount`)
```sql
SELECT IF(SUM(BP.FundingAmount) >= C.TargetAmount, true, false)
FROM Campaign C
     JOIN BackingPayment BP ON BP.CampaignId = C.CampaignId
WHERE C.CampaignId = ?
  AND BP.IsCanceled = FALSE
```

**접근 테이블**: `BackingPayment`, `Campaign`

---

## 4. POST `/api/campaigns/card/base-info` — 프로젝트 기본 정보 일괄 조회

여러 프로젝트의 기본 카드 정보를 배치로 조회.

- **Method**: `CampaignController.getCampaignBaseInfoCardList`
- **Cache**: `@Cacheable`

### Request Body
`List<Integer>` — 프로젝트 ID 목록 (직접 배열 본문)

### Response — `List<CampaignBaseCardInfoListResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | 프로젝트 ID |
| `campaignTitle` | `String` | 제목 |
| `makerName` | `String` | 메이커 명 |
| `photoUrl` | `String` | 카드 이미지 |

### MySQL 쿼리

(`CampaignMapper.campaignBaseInfoSearch`)
```sql
SELECT C.CampaignId,
       C.Title AS CampaignTitle,
       C.HostName AS MakerName,
       PC.photoUrl
FROM Campaign C
     LEFT JOIN PhotoCommon PC ON PC.PhotoId = C.PhotoId
WHERE C.IsOpen = TRUE
  AND C.IsDel = FALSE
  AND C.CampaignId IN (?, ?, ...)
```

**접근 테이블**: `Campaign`, `PhotoCommon`

---

## 5. GET `/api/campaigns/{campaignId}/detail` — 프로젝트 상세 정보

스토리/메이커/외부 Store 연동 정보를 포함한 풍부한 상세 조회. **2회의 Proxy 호출**이 연속으로 일어남.

- **Method**: `CampaignController.getCampaignDetail`
- **Cache**: `campaignProxy.campaignDetail`만 `@Cacheable(key="'campaignDetail: ' + #campaignId")`. `campaignStatusAsRealTime`은 캐시 없음.

### Path / Response

| 이름 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | 프로젝트 ID |

**Response** — `CampaignDetailResponse` (주요 필드)
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` / `title` / `whenHoldTo` | 기본 | — |
| `riskSolution` | `String` | 리스크 해결방안 |
| `classification` | `String` | 타입 |
| `whenPayFor` | `String` | 결제 예정일 (EventDay 기반) |
| `achievementRate` | `int` | 달성률 |
| `remainingDay` | `Integer` | 잔여일수 |
| `whenOpen` / `whenOpenWithTime` | `LocalDateTime` | 오픈 일자/시각 |
| `isOpen` / `isEnded` | `Boolean` | 오픈·종료 상태 |
| `targetAmount` / `totalFundingAmount` | `Long` | 목표/현재 금액 |
| `isAdultContent` | `Boolean` | 성인물 여부 |
| `askForEncoreQty` | `int` | 앵콜 요청 수 |
| `thumbnailUrl` / `friendsTalkImageUrl` | `String` | 이미지 |
| `campaignProgressStatus` | `String` | 진행 상태 enum |
| `categoryId` / `categoryCode` / `categoryName` | — | 카테고리 |
| `isInProgressComingSoon` / `isCancelAutoOpen` | `Boolean` | 오픈예정 관련 |
| `partners` | `List<Partner>` | 협력업체 (`name`, `code`) |
| `store` | `Store` | 스토어 정보 (`isOpen`, `thumbnailUrl`, `projectNo`) |
| `bizModel` | `CampaignBizModel` | 프로젝트 구분 enum |
| `label` | `PreOrderCondition` | 프리오더 라벨 |
| `preReservation` | `PreReservation` | 사전예약 정보 |

### 컨트롤러 코드 흐름

1. `campaignProxy.campaignDetail(campaignId)` 호출 → `CampaignDetailResultItem` 반환
2. `campaignProxy.campaignStatusAsRealTime(campaignId)` 호출 → 실시간 상태(`isOpened`) 반환
3. 1의 결과 `toBuilder()`에 2의 `isOpened`을 병합해 응답 변환

### MySQL 쿼리 (복수)

`CampaignQueryGatewayImpl.campaignBaseInfo` 가 다음 쿼리를 조합:

**① 베이스 정보** (`CampaignMapper.campaignBaseInfo`) — 대규모 단일 쿼리
```sql
SELECT C.CampaignId, C.Title, C.WhenHoldTo, C.IsAdultContent, C.WhenSubmitted,
       C.WhenOpen, C.isOpen,
       C.PhotoId AS RepresentativeImageId, PC.PhotoUrl AS RepresentativeImageUrl,
       C.CustValueCode AS CategoryId, CV.Value AS CategoryName,
       C.VideoUrl AS IntroVideoUrl, C.IntroDetails AS Story,
       C.UserId AS MakerUserId, C.HostName AS MakerName,
       C.PhotoIdHost AS MakerImageId, PCH.PhotoUrl AS MakerImageUrl,
       C.HostEmail AS MakerEmail, C.HostCallNum AS MakerCallNumber,
       C.WebsiteA AS HomepageA, C.WebsiteB AS HomepageB,
       C.SocialUrlFb AS Facebook, C.SocialUrlTw AS Twitter, C.SocialUrlIg AS Instagram,
       C.MakerContactProperty AS KakaoJson,
       DATE_FORMAT((SELECT MIN(EventDate) FROM EventDay
                    WHERE Type='o' AND EventDate > C.WhenHoldTo),'%Y.%m.%d') AS WhenPayFor,
       (SELECT IFNULL(SUM(FundingAmount),0) FROM BackingPayment BP
        WHERE BP.CampaignId = #{campaignId} AND BP.IsCanceled = FALSE) AS TotalFundingAmount,
       TO_DAYS(C.WhenHoldTo) - TO_DAYS(NOW()) AS RemainingDay,
       IFNULL(C.TargetAmount,0) AS TargetAmount,
       (SELECT EXISTS(
          SELECT 1 FROM BackingPayment BP
                   INNER JOIN BackingPaymentMapping BM ON BP.BackingPaymentId = BM.BackingPaymentId
                   INNER JOIN Backing B ON BM.BackingId = B.BackingId
                   LEFT JOIN Shipping S ON B.BackingId = S.BackingId
          WHERE BP.CampaignId = C.CampaignId AND S.DeliveryStatus = 'DELIVERED'
        )) AS existsAnyDelivered,
       C.BizModel, CL.Label, CM.StrValue1 AS FriendsTalkImage
FROM Campaign C
     LEFT JOIN CodeValue CV ON CV.Code = C.CustValueCode AND GroupId = 'NEWCUSTVALUE'
     LEFT JOIN PhotoCommon PC  ON PC.PhotoId = C.PhotoId
     LEFT JOIN PhotoCommon PCH ON PCH.PhotoId = C.PhotoIdHost
     LEFT JOIN CampaignLabel CL ON C.CampaignId = CL.CampaignId
     LEFT JOIN CampaignMarker CM
               ON C.CampaignId = CM.CampaignId
              AND CM.MarkerId = 'FRIEND_TALK_IMAGE_URL'
              AND CM.OrderNo = 1
WHERE C.CampaignId = ?
```

**② 해시태그** (`CampaignMapper.campaignTags`)
```sql
SELECT Tag, OrderNo FROM CampaignHashTag WHERE CampaignId = ? ORDER BY OrderNo
```

**③ 소개 이미지** (`CampaignMapper.introImages`)
```sql
SELECT C.CampaignId, CNP.PhotoId AS Id, PCN.PhotoUrl AS Url
FROM wadiz_db.Campaign C
     INNER JOIN wadiz_db.CampaignNPhoto CNP ON CNP.CampaignId = C.CampaignId
     INNER JOIN wadiz_db.PhotoCommon PCN   ON PCN.PhotoId = CNP.PhotoId
WHERE C.CampaignId = ?
ORDER BY CNP.OrderNo
```

**④ 프로젝트 상태** (`CampaignMapper.getCampaignStatus`)
```sql
SELECT C.CampaignId, C.WhenOpen, C.WhenHoldTo, C.WhenClose,
       RCS.Status AS ComingSoonStatus, RCS.PostedAt AS ComingSoonPostedAt
FROM Campaign C
     LEFT JOIN RewardComingSoon RCS ON C.CampaignId = RCS.CampaignId
WHERE C.CampaignId = ? AND C.IsDel = FALSE
```

**⑤ 리워드 아이템** (`RewardItemMapper.getRewardItems`) — 리워드 최소 출고일 계산용 (실제 SQL은 RewardItemMapper.xml 참조)

**⑥ 앵콜 요청 수** (`CampaignAskForEncoreMapper.selectAskForEncoreQty`) — 종료된 프로젝트만 실행

**외부 API**: `StoreClient.getStoreProject(campaignId)` — 성공·종료 프로젝트인 경우 Store(다른 서비스) REST 호출

**접근 테이블/리소스**: `Campaign`, `CodeValue`, `PhotoCommon`, `CampaignLabel`, `CampaignMarker`, `CampaignHashTag`, `CampaignNPhoto`, `EventDay`, `BackingPayment`, `BackingPaymentMapping`, `Backing`, `Shipping`, `RewardComingSoon`, `RewardItem`, `CampaignAskForEncore`, 외부 Store API

> `campaignStatusAsRealTime`은 UseCase 내부 구현이므로 여기서는 확인 불가. `CampaignQueryGatewayImpl`에는 별도 메서드가 없다.

---

## 6. GET `/api/campaigns/{campaignId}/summary` — 프로젝트 요약

간단한 요약 정보 (카드보다 상세, detail보다 단순).

- **Method**: `CampaignController.getCampaignSummary`
- **Cache**: `@Cacheable(keyGenerator = "cacheKeyGenerator")`

### Response — `CampaignSummaryResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `campaignTitle` | `String` | — |
| `whenHoldTo` | `LocalDateTime` | 종료일 |
| `bizModel` | `String` | 프로젝트 타입 (Classification 컬럼) |
| `achievementRate` | `int` | 달성률 |
| `remainingDay` | `int` | 잔여일수 |
| `whenOpen` | `LocalDateTime` | 오픈일 |
| `isOpen` / `isHidden` | `Boolean` | 상태 |
| `targetAmount` / `totalFundingAmount` | `Long` | 금액 |
| `thumbnailUrl` | `String` | — |
| `isInProgressComingSoon` | `Boolean` | 오픈예정 여부 |
| `applicants` | `int` | 참여자 |
| `categoryName` / `makerName` | `String` | — |

### MySQL 쿼리

(`CampaignSummaryMapper.campaignSummary` — `CampaignSummary.xml`)
```sql
SELECT C.CampaignId,
       C.Title AS CampaignTitle,
       IFNULL(C.TargetAmount, 0) AS TargetAmount,
       C.WhenHoldTo,
       C.isOpen,
       C.isHidden,
       C.Classification AS BizModel,
       TO_DAYS(C.WhenHoldTo) - TO_DAYS(NOW()) AS RemainingDay,
       IF(C.IsOpen IS TRUE,
          (SELECT IFNULL(SUM(FundingAmount),0) FROM BackingPayment BP
           WHERE BP.CampaignId = C.CampaignId AND IsCanceled = FALSE),
          0) AS totalFundingAmount,
       PC.PhotoUrl AS ThumbnailUrl,
       IFNULL(AO.Scheduled, C.WhenOpen) AS WhenOpen,
       CS.Status AS ComingSoonStatus,
       C.HostName AS MakerName,
       CV.Value AS CategoryName
FROM Campaign C
     LEFT JOIN RewardComingSoon CS ON CS.CampaignId = C.CampaignId
     LEFT JOIN CampaignAutoOpen AO ON AO.CampaignId = C.CampaignId
     LEFT JOIN PhotoCommon PC      ON PC.PhotoId = C.PhotoId
     LEFT JOIN CodeValue CV        ON CV.Code = C.CustValueCode
WHERE C.CampaignId = ?
  AND C.IsDel = FALSE
```

**접근 테이블**: `Campaign`, `RewardComingSoon`, `CampaignAutoOpen`, `PhotoCommon`, `CodeValue`, `BackingPayment`

---

## 7. GET `/api/campaigns/{campaignId}/tags` — 해시태그 목록

- **Method**: `CampaignController.getCampaignTags`
- **Cache**: `@Cacheable(key="'campaignTags: ' + #campaignId")`

### Response
`List<String>` — 태그 문자열 배열

### MySQL 쿼리

(`CampaignMapper.campaignTags`)
```sql
SELECT Tag, OrderNo FROM CampaignHashTag WHERE CampaignId = ? ORDER BY OrderNo
```

> 응답은 `List<String>`이지만 쿼리는 `SearchTag` 오브젝트를 반환한다. Usecase(funding-core)에서 변환할 것으로 추정되나 이 레포에서는 컨트롤러가 받은 `List<String>`만 관찰됨.

**접근 테이블**: `CampaignHashTag`

---

## 8. GET `/api/campaigns/{campaignId}/status` — 프로젝트 상태

현재 상태 코드 반환.

- **Method**: `CampaignController.getCampaignStatus`
- **Cache**: 없음 (Proxy 메서드에 `@Cacheable` 없음)

### Response — `CampaignStatusResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `campaignStatus` | `CampaignStatus` (enum) | 프로젝트 상태 (funding-core 상수) |

### MySQL 쿼리

`CampaignQueryGatewayImpl.getCampaignStatus` → (`CampaignMapper.getCampaignStatus`)
```sql
SELECT C.CampaignId, C.WhenOpen, C.WhenHoldTo, C.WhenClose,
       RCS.Status AS ComingSoonStatus, RCS.PostedAt AS ComingSoonPostedAt
FROM Campaign C
     LEFT JOIN RewardComingSoon RCS ON C.CampaignId = RCS.CampaignId
WHERE C.CampaignId = ? AND C.IsDel = FALSE
```

반환된 `CampaignStatusInfo`가 UseCase에서 `CampaignStatus` enum으로 변환됨 (변환 규칙은 funding-core 확인 필요).

**접근 테이블**: `Campaign`, `RewardComingSoon`

---

## 9. GET `/api/campaigns/{campaignId}/pre-reservation-info` — 사전 예약 정보

- **Method**: `CampaignController.getCampaignPreReservationInfo`
- **Cache**: 없음

### Response — `CampaignPreReservationResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `isPreReservation` | `Boolean` | 사전예약 여부 |
| `makerName` | `String` | 메이커명 |
| `consentItems` | `List<String>` | 제공 동의 항목 |

### MySQL 쿼리

`CampaignPreReservationInfoUseCase` 및 관련 Gateway 구현체가 **이 레포의 infrastructure 하위에 존재하지 않는다** (`find … -name "*PreReservation*"` 결과 없음).  
→ **이 엔드포인트의 DB 호출은 본 레포에서 확인 불가**. funding-core jar 내부에서 처리되는 것으로 보인다.

---

## 10. 참고 — 본 레포 Campaign Gateway / Repository 요약

### `CampaignGatewayImpl` (Spring Data JDBC 기반)
| 메서드 | 용도 |
|---|---|
| `getByCampaignId(id)` | `CampaignRepository.findById` → 없으면 `EntityNotFoundException` |
| `findById(id)` | Optional 반환 |
| `getActiveByCampaignId(id)` | `findByIdAndIsDelFalse` 사용 |
| `isMaker(id, userId)` | `existsByIdAndUserId` |
| `existById(id)` | `existsById` |
| `findAllByUserId(userId)` | `findAllByUserId` |

### `CampaignRepository` (derived/annotated queries)
```java
boolean existsByIdAndUserId(Integer campaignId, Integer userId);
List<CampaignDto> findAllByUserId(Integer userId);

@Query("SELECT campaignId, whenOpen FROM Campaign WHERE campaignId = :campaignId")
Optional<CampaignOpenDto> findWhenOpenById(Integer campaignId);

Optional<CampaignDto> findByIdAndIsDelFalse(Integer campaignId);
```

### `CampaignQueryGatewayImpl` (MyBatis 기반) — 본 문서 대상 공개 API가 주로 사용
| 메서드 | Mapper 메서드 |
|---|---|
| `campaignCardInfoSearch` | `CampaignMapper.campaignCardInfoSearch` + `campaignCardInfoCount` |
| `campaignComingSoonCardInfoSearch` | `CampaignMapper.campaignComingSoonCardInfoSearch` + `campaignComingSoonCardInfoCount` |
| `campaignBaseInfo` | `CampaignMapper.campaignBaseInfo`, `campaignTags`, `introImages`, `getCampaignStatus` + `RewardItemMapper.getRewardItems` + `CampaignAskForEncoreMapper.selectAskForEncoreQty` + `StoreClient` |
| `paymentSummationInfo` | `BackingPaymentMapper.backingSummationInfo` × 2 (완료 / 예정 상태별) |
| `statisticsSummationInfo` | `backingSummationInfo` + `isSuccessClose` + `isReachTargetAmount` |
| `campaignBaseInfoSearch` | `CampaignMapper.campaignBaseInfoSearch` |
| `campaignSummary` | `CampaignSummaryMapper.campaignSummary` |
| `campaignTags` | `CampaignMapper.campaignTags` |
| `getCampaignStatus` | `CampaignMapper.getCampaignStatus` |
| 그 외 `getBizModel`, `getRefundableEndedAt`, `getWhenHoldTo`, `findMyProjects`, `findAllCampaignIdByWhenOpen` 등 | 각각 `CampaignMapper` 동명 쿼리 |

UseCase(funding-core)가 위 Gateway 메서드 중 어떤 조합을 호출하는지는 이 레포에서 확인 불가.
