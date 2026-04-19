# Wish / Signature / Encore / ComingSoonApplicant API 상세 스펙

찜하기·지지서명·앵콜 요청·오픈예정 알림신청 관련 **15개 엔드포인트**.

- **대상 컨트롤러**:
  - `WishController` (`/api/wishes`) — 6개 (로그인 필요)
  - `WishInternalController` (`/api/internal/wishes`) — 2개 (Internal)
  - `SignatureController` (`/api/signatures`) — 1개 (Public)
  - `AskForEncoreController` (`/api/projects/{projectNo}/ask-for-encore`) — 2개 (로그인 필요)
  - `ComingSoonController` (`/api/comingsoons`) — 1개 (Internal 성격)
  - `ComingSoonApplicantController` (`/api/comingsoons/{projectNo}/applicants`) — 3개 (로그인 필요)

- **저장소**: MySQL 중심 (Spring Data JDBC + MyBatis 혼용)
- **주요 테이블**: `UserWishProject`, `UserInterestedInCampaign`(legacy), `Signature`, `CampaignAskForEncore`, `RewardComingSoonApplicant`

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록. UseCase 구현체는 외부 jar(`funding-core`)에 있어 내부 순서는 확인 불가.

---

## 1. GET `/api/wishes/my` (Deprecated) — 내 찜 프로젝트 목록

- **Method**: `WishController.list`
- **정렬 기본**: `UIC.WhenCreated desc`

### Response — `PageResult<WishesResponse>`
(campaignId, title, hostName, isOpen, isAllOrNothing, categoryName, photoUrl, targetAmount, totalFundingAmount, isCampaignEnded, remainingDay)

### MySQL 쿼리 (`WishMapper.search` + `count`)

**legacy `UserInterestedInCampaign`** 테이블 사용 (현재 `UserWishProject`와 별도):
```sql
SELECT UIC2.CampaignId, C.Title, C.HostName, C.IsOpen, C.IsAllOrNothing,
       CD.Value AS CategoryName, PC.PhotoUrl, C.TargetAmount,
       (SELECT SUM(FundingAmount) FROM BackingPayment TBP
        WHERE TBP.CampaignId = C.CampaignId AND TBP.IsCanceled = 0) AS TotalFundingAmount,
       DATE_ADD(C.WhenHoldTo, INTERVAL 1 DAY) < NOW() AS IsCampaignEnded,
       TO_DAYS(C.WhenHoldTo) - TO_DAYS(NOW()) AS RemainingDay
FROM (SELECT UIC.CampaignId
      FROM UserInterestedInCampaign UIC
      WHERE UIC.UserId = ?
      -- + 페이징/정렬
     ) UIC2
     INNER JOIN Campaign C ON C.CampaignId = UIC2.CampaignId
     INNER JOIN PhotoCommon PC ON PC.PhotoId = C.PhotoId
     LEFT JOIN CodeValue CD ON CD.Code = C.CustValueCode AND CD.GroupId = 'NEWCUSTVALUE'
```

**접근 테이블**: `UserInterestedInCampaign`, `Campaign`, `PhotoCommon`, `CodeValue`, `BackingPayment`

---

## 2. GET `/api/wishes/projects/qty` — 프로젝트 찜하기 건수

### Request (Query, 모두 선택)
| 필드 | 타입 | 설명 |
|---|---|---|
| `fundingNo` | `Integer` | 펀딩 프로젝트 번호 |
| `preorderNo` | `Integer` | 프리오더 프로젝트 번호 |
| `storeNo` | `Integer` | 스토어 프로젝트 번호 |

### Response — `ProjectWishQtyResponse{fundingQty, preorderQty, storeQty}`

### DB 호출

`wishProxy.getProjectWishQty(fundingNo, preorderNo, storeNo)` — UseCase 내부에서 타입별 `UserWishProject COUNT`.

UseCase는 아마도 세 번의 `UserWishProjectRepository.countByProjectTypeAndProjectNoAndIsDelFalse(...)` 파생 쿼리 또는 WishMapper 를 조합 호출 (정확한 매핑은 funding-core 확인 필요).

---

## 3. GET `/api/wishes/my/qty` — 나의 찜 건수

### Response — `MyWishQtyResponse{totalQty, wishStoreQty, wishFundingQty, applicantFundingQty}`

### MySQL 쿼리 (`WishMapper.countMyWishes`)

```sql
SELECT IFNULL(FUNDING.ApplicantFundingQty, 0) AS ApplicantFundingQty,
       IFNULL(FUNDING.WishFundingQty, 0)      AS WishFundingQty,
       STORE.WishStoreQty
FROM (SELECT SUM(CASE WHEN UWP.SourceType = 'APPLICANT' AND C.IsOpen = FALSE THEN 1 ELSE 0 END) AS ApplicantFundingQty,
             SUM(CASE WHEN C.IsOpen = TRUE THEN 1 ELSE 0 END) AS WishFundingQty
      FROM UserWishProject UWP
           INNER JOIN Campaign C ON C.CampaignId = UWP.ProjectNo
      WHERE UWP.UserId = ?
        AND UWP.IsDel = FALSE
        AND UWP.ProjectType = 'FUNDING') FUNDING
     INNER JOIN (SELECT COUNT(*) AS WishStoreQty
                 FROM UserWishProject UWP
                 WHERE UWP.UserId = ?
                   AND UWP.IsDel = FALSE
                   AND UWP.ProjectType = 'STORE') STORE
```

- `SourceType = 'APPLICANT'` + `IsOpen = FALSE` = 오픈예정 알림신청 수(펀딩 프로젝트 중)
- `IsOpen = TRUE` = 진행중 펀딩 찜 수
- STORE = 스토어 찜 수

**접근 테이블**: `UserWishProject`, `Campaign`

---

## 4. POST `/api/wishes` — 찜하기 등록

### Request — `WishCreateRequest{projectNo, projectType, sourceType}`

### Response — `WishCreateResponse{wishId}`

### 컨트롤러 코드 흐름
`Locale.getCountry()`로 국가코드 추출 후 `WishCreateCommand{userId, projectNo, projectType, sourceType, countryCode}` 전달.

### DB 호출 (`WishGatewayImpl.createUserWishProject`)

`UserWishProjectRepository.save(Insert{projectType, projectNo, userId, isDel=false, sourceType, countryCode})` (Spring Data JDBC):
```sql
INSERT INTO UserWishProject (ProjectType, ProjectNo, UserId, IsDel, SourceType, CountryCode, Registered, Updated)
VALUES (?, ?, ?, FALSE, ?, ?, NOW(), NOW())
```

- `DbActionExecutionException` 발생 시 `EntityAlreadyExistException("이미 찜하기 정보가 존재합니다.")` 변환 — 유니크 제약 위반 대응
- 이전 찜 레코드(isDel=true)가 있으면 `registerWish` 경로(update 재활성화)로 분기할 수 있음

**접근 테이블**: `UserWishProject`

---

## 5. DELETE `/api/wishes` — 찜하기 해제

- **Request (Query @ParameterObject)**: `WishDeleteRequest{projectNo, projectType}`

### DB 호출 (`WishGatewayImpl.deleteWish`)

`UserWishProjectRepository.save(Update{isDel=TRUE})` — **소프트 삭제**:
```sql
UPDATE UserWishProject
SET IsDel = TRUE, Updated = NOW()
WHERE WishId = ?
```

(주의: `DELETE`가 아닌 `UPDATE IsDel = TRUE`)

---

## 6. GET `/api/wishes` — 찜하기 확인

- **Request (Query)**: `projectType`, `projectNo`

### DB 호출
`wishProjectRepository.findByProjectTypeAndProjectNoAndUserId(projectType, projectNo, userId)` — Spring Data JDBC 파생 쿼리.

### Response — `UserWishResponse` (없어도 응답 있음, isDel 포함)

---

## 7. POST `/api/internal/wishes/users/{userId}` — 유저 찜 프로젝트 조회 (커서 페이징)

- **Method**: `WishInternalController.getUserWishList`

### Request Body — `UserWishListRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `projects[]` | List | 프로젝트 타입별 필터 (`projectType`, `sourceType`, `projectNos[]`, `searchFundingApplicant/Wish` 플래그) |
| `cursorPage.cursor` | `Long` | epoch ms 기반 커서(`Updated` 기준) |
| `cursorPage.size` | `int` | 페이지 크기 |

### Response — `SliceResult<UserWishResponse>` (hasNext, cursor 포함)

### MySQL 쿼리 (`WishMapper.selectUserWishList`)

```sql
SELECT UWP.WishId, UWP.ProjectType, UWP.SourceType, UWP.ProjectNo, UWP.UserId,
       UWP.Registered, UWP.Updated
FROM UserWishProject UWP
  -- query.searchFundingProject: LEFT JOIN Campaign C ON C.CampaignId = UWP.ProjectNo
WHERE UWP.UserId = ? AND UWP.IsDel = FALSE
  -- query.projects: AND (projectType별 OR 조합, searchFundingApplicant 시 C.IsOpen=FALSE + sourceType 조건, searchFundingWish 시 C.IsOpen=TRUE)
  -- query.updated != null: AND UWP.Updated < ?  (커서)
-- + 페이징/정렬 (Updated desc)
```

**접근 테이블**: `UserWishProject`, `Campaign` (옵션)

---

## 8. POST `/api/internal/wishes/qty/by-projects` — 여러 프로젝트 찜 건수 합

### Request — `SearchWishQtyByProjectsRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `projectType` | enum | — |
| `projectNos[]` | `List<Integer>` | — |
| `periodFrom / periodTo` | `LocalDate` | 선택 — 기간 필터 (periodTo는 +1일로 보정) |

### Response — `SearchWishQtyResponse{totalQty: Integer}`

### 컨트롤러 분기
- `periodFrom`/`periodTo` 둘 다 있으면 기간 필터 적용 `wishProxy.getWishQtyByProjects(type, nos, from, to)`
- 없으면 전체 기간 `wishProxy.getWishQtyByProjects(type, nos)`

### DB 호출
`UserWishProjectRepository` 파생 쿼리 또는 `WishMapper` 커스텀 쿼리 (구체는 funding-core).

---

## 9. GET `/api/signatures/campaigns/{campaignId}/qty` — 지지서명자 수

- **Method**: `SignatureController.getCampaignSignatureQty`

### Response
`ResponseWrapper<Integer>` — 서명자 고유 수

### MySQL 쿼리 (`SignatureQueryGatewayImpl.campaignSignatureQty` → `SignatureMapper.campaignSignatureQty`)

```sql
SELECT COUNT(DISTINCT UserId) AS QTY
FROM Signature
WHERE CampaignId = ?
  AND IsDeleted = FALSE
```

`COUNT(DISTINCT UserId)` — 한 유저가 여러 번 서명해도 1명으로 집계.

**접근 테이블**: `Signature`

---

## 10. POST `/api/projects/{projectNo}/ask-for-encore` — 앵콜 요청

- **Method**: `AskForEncoreController.ask`
- **Auth**: 로그인 필요

### DB 호출 (`AskForEncoreGatewayImpl.save`)

```java
Optional<dto> = findById_CampaignIdAndId_UserId(projectNo, userId);
if (present) save(Update{isCancel=false, ...})
else          save(Insert{campaignId, userId, isCancel=false, ...})
```

- `CampaignAskForEncoreRepository`는 복합 키 `(CampaignId, UserId)` 사용
- **UPSERT 패턴**: 이미 있으면 UPDATE(isCancel=false로 재활성화), 없으면 INSERT

```sql
-- 조회
SELECT * FROM CampaignAskForEncore
WHERE CampaignId = ? AND UserId = ?

-- INSERT or UPDATE
INSERT INTO CampaignAskForEncore (CampaignId, UserId, IsCancel, Registered, Updated) VALUES (?, ?, FALSE, NOW(), NOW())
UPDATE CampaignAskForEncore SET IsCancel = FALSE, Updated = NOW() WHERE CampaignId = ? AND UserId = ?
```

**접근 테이블**: `CampaignAskForEncore`

---

## 11. DELETE `/api/projects/{projectNo}/ask-for-encore` — 앵콜 요청 취소

### DB 호출
`AskForEncoreGatewayImpl.save(askForEncore.toBuilder().isCancel(true).build())` — 소프트 삭제:
```sql
UPDATE CampaignAskForEncore SET IsCancel = TRUE, Updated = NOW()
WHERE CampaignId = ? AND UserId = ?
```

---

## 12. POST `/api/comingsoons/applicants/{userId}` — 사용자 알림신청 프로젝트 조회 (커서 페이징)

- **Method**: `ComingSoonController.getComingSoonApplicantsByUser`

### Request Body — `ComingSoonApplicantsByUserRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `cursorPage.cursor` | `Long` | epoch ms (Registered 기준) |
| `cursorPage.size` | `int` | 페이지 크기 |

### Response — `SliceResult<ComingSoonApplicantsByUserResponse>`

### 정렬: `Registered desc`

### DB 호출
`ComingSoonApplicantRepository` 또는 `ComingSoonApplicantMapper` 기반. `UserId` + `Registered < cursor` 조건으로 커서 페이징.

**접근 테이블**: `RewardComingSoonApplicant`

---

## 13. GET `/api/comingsoons/{projectNo}/applicants/qty` — 오픈예정 신청 건수

- **Method**: `ComingSoonApplicantController.qty`

### Response
`ResponseWrapper<Integer>`

### DB 호출
`ComingSoonApplicantRepository.countByCampaignIdAndIsCanceledFalse(projectNo)` 또는 Mapper 기반 — `COUNT(*) FROM RewardComingSoonApplicant WHERE CampaignId = ? AND IsCanceled = FALSE`.

---

## 14. POST `/api/comingsoons/{projectNo}/applicants` — 오픈 알림 신청 등록

- **Method**: `ComingSoonApplicantController.create`
- **Auth**: 로그인 필요

### Request Body — `ComingSoonApplicantRequest{hasConsentItems}`

### Command 빌드
- `userId = SecurityUtils.currentUserId()`
- `deviceType = UserDeviceUtils.currentUserDevice()` — User-Agent 기반 디바이스 판정
- `countryCode = LocaleContextHolder.getLocale().getCountry()`

### DB 호출
`ComingSoonApplicantRepository.save(Insert)` 또는 UPSERT(취소 상태면 재활성화):
```sql
INSERT INTO RewardComingSoonApplicant
  (CampaignId, UserId, IsCanceled, HasConsentItems, DeviceType, CountryCode, Registered, Updated)
VALUES (?, ?, FALSE, ?, ?, ?, NOW(), NOW())
```

**접근 테이블**: `RewardComingSoonApplicant`

---

## 15. DELETE `/api/comingsoons/{projectNo}/applicants` — 오픈 알림 신청 해제

### DB 호출
소프트 삭제:
```sql
UPDATE RewardComingSoonApplicant
SET IsCanceled = TRUE, Updated = NOW()
WHERE CampaignId = ? AND UserId = ?
```

---

## 16. 참고 — 이 문서의 Gateway / Repository / Mapper

### Gateway 구현체 (이 레포)

| 구현체 | 대상 |
|---|---|
| `WishGatewayImpl` | `UserWishProjectRepository` (Spring Data JDBC), `WishMapper` (MyBatis) |
| `SignatureGatewayImpl` | `SignatureRepository` (Spring Data JDBC) |
| `SignatureQueryGatewayImpl` | `SignatureMapper` (MyBatis) |
| `AskForEncoreGatewayImpl` | `CampaignAskForEncoreRepository` (Spring Data JDBC, 복합 키 `(CampaignId, UserId)`) |
| `ComingSoonApplicantRepository` 기반 (복수 Gateway 구성) | — |

### MyBatis Mapper XML
- `WishMapper.xml` — `search`/`count` (legacy UIC), `selectUserWishList` (커서 페이징), `countMyWishes`, `existsByProjectAndUserId`, `countCountry`, `selectDeadlineAlarmSubscriber`, `findAllCountryRanking`(dashboard에서도 사용)
- `SignatureMapper.xml` — `campaignSignatureQty`, `countByMakerAndPeriod`
- `ComingSoonApplicantMapper.xml` — `findAllCountryRanking` 등
- `ComingSoonApplicantStatisticMapper.xml` — 통계/집계

### 공통 패턴
- **Soft delete**: 모든 도메인이 물리 삭제 대신 `IsDel`/`IsCanceled`/`IsDeleted` 플래그 UPDATE 사용
- **커서 기반 페이징**: internal API(`/users/{userId}`, `/applicants/{userId}`)에서 epoch ms 커서 사용 — 일반 페이징 대비 무한 스크롤 호환 + 새 항목 추가로 인한 중복/누락 방지
- **UPSERT by 복합키**: 앵콜(`CampaignAskForEncore`), 찜(`UserWishProject` unique 제약) 모두 유니크 제약 위반 시 Update로 전환
- **SourceType 필드**: `UserWishProject`에 `APPLICANT`/`WISH` 구분 — 오픈예정 알림신청과 실제 찜을 같은 테이블에서 구분 저장

### 접근 테이블 합계
`UserWishProject`, `UserInterestedInCampaign`(legacy), `Signature`, `CampaignAskForEncore`, `RewardComingSoonApplicant`, `Campaign`, `PhotoCommon`, `CodeValue`, `BackingPayment`, `UserProfile`, `CampaignShippingCountry`
