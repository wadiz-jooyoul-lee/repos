# News / Notification / Announcement API 상세 스펙

프로젝트 새소식·알림 수신 설정·공지사항 관련 **21개 엔드포인트**.

- **대상 컨트롤러**:
  - `NewsController` (`/api/campaigns/{campaignId}/news`) — 3개 (Public)
  - `NewsStudioController` (`/api/studio/campaigns/{campaignId}/news`) — 9개 (`isMaker or isAdmin`)
  - `NewsNotificationController` (`/api/news/notifications`) — 2개 (Public, 로그인 필요)
  - `NewsNotificationAdminController` (`/api/admin/news/notifications`) — 2개 (`isAdmin`)
  - `AnnouncementController` (`/api/studio/announcements`) — 5개 (Studio)
  - `AnnouncementAdminController` (`/api/admin/announcements`) — 10개 (`isAdmin`)

> Phase 7에서 세어둔 15개 + 2개(NewsNotification Admin) → 실제 총 **21개**. `api-endpoints.md`의 News Notification은 사용자/관리자 합산.

- **저장소**:
  - **MySQL**: `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateTagMapping`, `MiniBoardCommon`(댓글수), `CampaignUpdateNotificationDeny`, `CampaignUpdateNotificationDenyLog`, `Announcement`, `AnnouncementDisplay`, `AnnouncementByMenu`, `AnnouncementDoNotShowAgain`, `AnnouncementExposure`, `AnnouncementHistory`
  - **MongoDB**: `NewsNotificationLog` (`NewsNotificationLogMongoRepository`, `@Async`)

> **기록 범위**: 이 레포의 Controller / Gateway / Mapper XML 에서 직접 관찰 가능한 호출만 기록. UseCase 내부 호출 순서는 funding-core 확인 필요.

---

## 1. GET `/api/campaigns/{campaignId}/news` — 새소식 목록 (Public, 페이징)

- **Method**: `NewsController.list`
- **정렬 기본**: `WhenCreated desc`
- **Locale**: `LocaleContextHolder.getLocale().getLanguage()` — 번역본 조회

### Request
| 위치 | 필드 | 타입 | 설명 |
|---|---|---|---|
| path | `campaignId` | `Integer` | — |
| query | `newsType` | enum | 새소식 유형 필터 |
| query | `tagType` | enum | 말머리 필터 |
| query | `page / size` | `int` | 페이징 |

### Response — `PageResult<NewsListResponse.CampaignDetail>`

### MySQL 쿼리 (`NewsMapper.search` + `count`)

```sql
SELECT CU.CampaignId, CU.UpdateId AS NewsId, CU.UpdateType AS NewsType,
       CUT.TagType, CU.Title,
       IF(CU.TitleHash = CUL.SourceTitleHash, CUL.Title, null) AS translatedTitle,
       IFNULL(CU.DetectedLanguageCode, 'ko') AS detectedLanguageCode,
       CU.IsCampaignMain AS IsDisplayedStory,
       CU.IsWadizNotice, CU.WhenCreated, CU.WhenUpdated, CU.WhenPosted,
       CU.IsTemporary, CU.RegisterUserId,
       (SELECT COUNT(*) FROM MiniBoardCommon MBC
        WHERE MBC.CommonId = CU.UpdateId AND MBC.GroupId = 3
          AND MBC.Depth = 0 AND MBC.Del = FALSE) AS CommentsQty
FROM CampaignUpdate CU
     LEFT JOIN CampaignUpdateLanguage CUL
            ON CU.UpdateId = CUL.UpdateId AND CUL.LanguageCode = ?
     LEFT OUTER JOIN CampaignUpdateTagMapping CUT ON CUT.UpdateId = CU.UpdateId
WHERE CU.CampaignId = ?
  AND CU.Del = false
  -- <if>: AND CU.UpdateType = ?
  -- <if>: AND CUT.TagType = ?
  -- query.includeTemporary == false: AND CU.IsTemporary = false
  -- <if>: AND CU.IsCampaignMain = ?
-- + 페이징/정렬
```

- `translatedTitle`: 원문 해시가 번역본의 `SourceTitleHash`와 일치할 때만 번역본 제공 (원문 변경 시 번역본 무효화)
- 댓글 수는 `MiniBoardCommon` 서브쿼리 (`GroupId = 3`이 새소식, `Depth = 0`은 최상위 댓글)

**접근 테이블**: `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateTagMapping`, `MiniBoardCommon`

---

## 2. GET `/api/campaigns/{campaignId}/news/qty` — 새소식 건수

`NewsMapper.count` — 1번 SQL의 `COUNT(*)` 변형.

**Response**: `Integer`

---

## 3. GET `/api/campaigns/{campaignId}/news/{newsId}` — 새소식 상세

### Response — `NewsDetailResponse.CampaignDetail`

### MySQL 쿼리 (`NewsMapper.detail`)

목록과 유사하지만 `CU.Body`, `translatedBody`, `RestrictReason`, `IsNotificationRequested`, `NotificationTargets`(JSON) 추가 조회:
```sql
SELECT CU.CampaignId, CU.UpdateId AS NewsId, CU.UpdateType AS NewsType,
       CUT.TagType, CU.Title, CU.Body,
       IF(CU.TitleHash = CUL.SourceTitleHash, CUL.Title, null) AS translatedTitle,
       IF(CU.BodyHash  = CUL.SourceBodyHash,  CUL.Body,  null) AS translatedBody,
       ...(목록 필드들)...
       CU.RestrictReason, CU.IsNotificationRequested, CU.NotificationTargets
FROM CampaignUpdate CU
     LEFT JOIN CampaignUpdateLanguage CUL
            ON CU.UpdateId = CUL.UpdateId AND CUL.LanguageCode = ?
     LEFT OUTER JOIN CampaignUpdateTagMapping CUT ON CUT.UpdateId = CU.UpdateId
WHERE CU.CampaignId = ? AND CU.UpdateId = ? AND CU.Del = false
```

- `NotificationTargets`는 JSON 필드 → `NotificationTargetsTypeHandler` 커스텀 TypeHandler로 역직렬화

없으면 `ResourceNotFoundException`.

---

## 4. POST `/api/studio/campaigns/{campaignId}/news` — 새소식 생성 (Studio)

- **Method**: `NewsStudioController.create`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`

### Request — `CreateNewsRequest`
(title, body, newsType, tagType, isTemporary, isNotificationRequested, notificationTargets, restrictReasons 등)

### Response — `CreateNewsResponse{newsId}`

### DB 호출 (`NewsGatewayImpl.createNews`)

`CampaignUpdateRepository.save(Insert)` — Spring Data JDBC INSERT into `CampaignUpdate`.

**추가 동작** (`setDisplayedStoryIfAvailable`):
- 새 뉴스가 `DisplayStoryStatus.DISPLAYED`이면:
  - 동일 campaignId의 다른 "displayed" 뉴스들 `findAllByCampaignIdAndIsCampaignMainIsTrueAndIsTemporaryIsFalse` 조회
  - 본인 외 모두 `IsCampaignMain = false`로 `saveAll` (batch UPDATE) — **프로젝트당 대표 새소식 1개 규칙 강제**

UseCase 내부에서 `NewsLanguageGatewayImpl` 통해 `CampaignUpdateLanguage` INSERT도 가능 (번역 저장).

**접근 테이블**: `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateTagMapping`

---

## 5. PUT `/api/studio/campaigns/{campaignId}/news/{newsId}` — 새소식 수정

- **Method**: `NewsStudioController.modify`

### Request — `ModifyNewsRequest`

### DB 호출
`NewsGatewayImpl.updateNews` → `CampaignUpdateRepository.save(Update{id=newsId, ...})` + 4번의 대표 새소식 규칙 재적용.

`isAdmin` 플래그로 관리자 수정 판별 (일반 메이커와 수정 권한 분기).

---

## 6. GET `/api/studio/campaigns/{campaignId}/news/tags` — 말머리 목록

**Response**: `List<NewsTagListResponse>`

→ `newsProxy.getTags(campaignId)` — funding-core. 이 레포 infra에 `NewsTagMapping` 조회가 있을 것으로 추정.

---

## 7. GET `/api/studio/campaigns/{campaignId}/news/availability` — 작성 가능 상태 확인

**Response**: `NewsAvailabilityResponse`

→ `newsProxy.availability(campaignId, userId)` — 작성 가능 여부(메이커 권한, 프로젝트 상태 등) 복합 판정. funding-core.

---

## 8. DELETE `/api/studio/campaigns/{campaignId}/news/{newsId}` — 새소식 삭제

- **Method**: `NewsStudioController.delete`

### Command
`DeleteNewsCommand{newsId, campaignId, userId, isAdmin}` → 소프트 삭제(`CU.Del = TRUE`)로 추정.

### DB 호출
`CampaignUpdateRepository.save(Update{del=true})` 또는 유사 UPDATE.

---

## 9. GET `/api/studio/campaigns/{campaignId}/news` — 스튜디오 목록

4번 `NewsMapper.search` 재사용. 단 `includeTemporary=true`(임시저장 포함), 응답에 `isModifiable` 계산 추가 (`newsModifiableChecker.isModifiable(userId, isWadizNotice)` — 와디즈 공지는 와디즈만 수정 가능).

**Response**: `PageResult<NewsListResponse.Studio>`

---

## 10. GET `/api/studio/campaigns/{campaignId}/news/{newsId}` — 스튜디오 상세

3번 `NewsMapper.detail` + `isModifiable` 계산.

---

## 11. GET `/api/studio/campaigns/{campaignId}/news/isSendNotification` (Deprecated)

`availability`의 `publishing.isAllowed` 리턴.

---

## 12. GET `/api/studio/campaigns/{campaignId}/news/writes/check-status` (Deprecated)

위와 동일. `"WRITING"` / `"WRITING_STOP"` 문자열 반환.

---

## 13. PUT `/api/news/notifications/settings/my/campaigns/{campaignId}` — 알림 수신 설정

- **Method**: `NewsNotificationController.setUpNotificationDeny`
- **Auth**: 로그인 필요

### Request (Path + Query)
| 위치 | 필드 | 타입 | 설명 |
|---|---|---|---|
| path | `campaignId` | `Integer` | — |
| query | `isDeny` | `boolean` | true=수신거부, false=수신 |

### DB 호출
`NewsNotificationGatewayImpl` / `NewsNotificationDenyGatewayImpl`:
- `CampaignUpdateNotificationDenyRepository` — UPSERT 또는 save
- `CampaignUpdateNotificationDenyLog` — 변경 이력 INSERT

**추가**: `NewsNotificationLogGatewayImpl.save` (`@Async`) — **MongoDB** `NewsNotificationLog` 컬렉션에 설정 변경 로그 비동기 저장.

---

## 14. GET `/api/news/notifications/settings/my` — 내 알림 설정 목록 (페이징)

- **정렬 기본**: `WhenAlarm desc, WhenOpen desc, CampaignId desc`

### Request
| Query | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `isShowDeny` | `boolean` | ✅ | true면 수신거부만, false면 전체 |

### MySQL 쿼리 (`NewsNotificationMapper.notificationDenyCampaignSearch` + `count`)

XML에 `selectDenyTargetClause` + `fromWhereDenyTargetClause` 공통 SQL 블록 사용. 내 프로젝트 펀딩 이력과 알림 설정(`CampaignUpdateNotificationDeny`)을 JOIN해 조회.

---

## 15. GET `/api/admin/news/notifications/settings` — 서포터 목록 (Admin, 페이징)

- **Request** — `NewsNotificationDenySupporterListRequest`:

| 필드 | 타입 | 설명 |
|---|---|---|
| `keywordType` | enum (`NONE/PROJECT_ID/NICKNAME/USER_NAME/USER_ID`) | 검색 조건 |
| `keyword` | `String` | 검색어 |

### MySQL 쿼리 (`NewsNotificationMapper.notificationDenySupporterSearch`)

알림 거부한 서포터 검색 — `CampaignUpdateNotificationDeny + UserProfile` JOIN.

---

## 16. GET `/api/admin/news/notifications/settings/{userId}` — 유저별 상세 (페이징)

특정 유저의 프로젝트별 알림 거부 설정 조회. `notificationDenyCampaignDetailList`.

**정렬**: `LastDenyUpdated desc, CampaignId asc`

---

## 17. GET `/api/studio/announcements` — 공지 목록 (사용자용)

- **Method**: `AnnouncementController.announcementList`
- **정렬**: `IsImportant desc, Registered desc`

### Response
`PageResult<AnnouncementListResponse.AnnouncementDisplayedListResponse>` + extras `{ "exposedDisplaySeq": N }` (현재 유저가 읽은 displaySeq)

### DB 호출

**① 노출된 공지 목록** (`AnnouncementMapper.searchAnnouncementDisplayedList` + `countAnnouncementDisplayedList`) — MyBatis
```sql
SELECT ... FROM Announcement A
     INNER JOIN AnnouncementDisplay AD ON A.AnnouncementId = AD.AnnouncementId
WHERE AD.IsDisplay = TRUE
-- + 페이징/정렬
```

**② 유저 노출 시퀀스** — `AnnouncementExposureRepository.findById(userId)` → `AnnouncementExposure.displaySeq`

**접근 테이블**: `Announcement`, `AnnouncementDisplay`, `AnnouncementExposure`

---

## 18. GET `/api/studio/announcements/by-menu` — 메뉴별 공지

현재 로그인 유저 기준 (do-not-show-again 필터 포함)으로 메뉴별 노출 가능한 공지 조회.

### DB 호출
`AnnouncementMapper.searchAnnouncementByMenuList` + `AnnouncementDoNotShowAgain` 제외 로직.

---

## 19. POST `/api/studio/announcements/exposure/{displaySeq}` — 읽은 공지 시퀀스 설정

### DB 호출 (`AnnouncementGatewayImpl`)
`AnnouncementExposureRepository.save(Insert/Update{userId, displaySeq})`:
```sql
INSERT INTO AnnouncementExposure (UserId, DisplaySeq) VALUES (?, ?)
ON DUPLICATE KEY UPDATE DisplaySeq = ?
```

---

## 20. POST `/api/studio/announcements/{menuType}/do-not-show-again` — 메뉴별 다시 안보기

### DB 호출 (`AnnouncementGatewayImpl.createDoNotShowAgain`)
`AnnouncementDoNotShowAgainRepository.save(Insert{userId, menuType})`:
```sql
INSERT INTO AnnouncementDoNotShowAgain (UserId, MenuType) VALUES (?, ?)
```

---

## 21. GET `/api/studio/announcements/new/qty/by-user` — 새 공지 건수

현재 유저의 `displaySeq` 이후 노출된 공지 수.

---

## 22. POST `/api/admin/announcements` — 공지 등록 (Admin)

### Request — `CreateAnnouncementRequest{title, body, header}`

### DB 호출 (`AnnouncementGatewayImpl.createAnnouncement`)
`AnnouncementRepository.save(Insert)`:
```sql
INSERT INTO Announcement (Title, Body, Header, Registered, RegisterUserId, ...) VALUES (?, ?, ?, NOW(), ?, ...)
```

`Announcement` + `AnnouncementHistory`(이력) 동시 저장 가능 (UseCase 레벨).

---

## 23. GET `/api/admin/announcements/{announcementId}` — 상세

`AnnouncementRepository.findById`.

---

## 24. PUT `/api/admin/announcements/{announcementId}/contents` — 콘텐츠 수정

- **Request**: `ModifyAnnouncementContentsRequest{title, body, header}`
- `actionType = UPDATE_CONTENTS`

### DB 호출
`AnnouncementRepository.save(Update)` + `AnnouncementHistory` INSERT (이력).

---

## 25. GET `/api/admin/announcements/history/{announcementId}` — 히스토리 (페이징)

### MySQL 쿼리 (`AnnouncementMapper.searchAnnouncementHistoryList` + `countAnnouncementHistoryList`)
```sql
SELECT ... FROM AnnouncementHistory AH
WHERE AH.AnnouncementId = ?
-- + 페이징/정렬 (Updated desc)
```

---

## 26. GET `/api/admin/announcements/by-menu/history` — 메뉴별 노출 히스토리 (페이징)

`searchAnnouncementByMenuHistoryList` — `AnnouncementByMenuHistory` 테이블.

---

## 27. GET `/api/admin/announcements` — 공지 목록 (Admin, 필터+페이징)

### Request — `SearchAnnouncementListRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `importantFilterType` | enum | 중요/일반 필터 |
| `displayFilterType` | enum | 노출/비노출 |
| `displayByMenuFilterType` | enum | 메뉴별 노출 여부 |

### Response
`PageResult<AnnouncementListResponse>` + extras `{ "qtyAnnouncementImportant": N }`

### DB 호출
- `AnnouncementMapper.searchAnnouncementList` + `countAnnouncementList`
- `announcementProxy.qtyAnnouncementImportant()` → `announcementMapper.countAnnouncementImportant()`

---

## 28. PUT `/api/admin/announcements/{announcementId}` — 공지 수정 (중요/노출)

- **Request**: `ModifyAnnouncementRequest{isImportant, isDisplay}`

### 특이 로직
`announcementDisplay`가 null이면 "안내 상태를 노출로 변경 후 중요 설정 가능합니다." `ValidationFailureException` 던짐 → **노출(Display)이 먼저 설정돼야 중요(Important) 설정 가능**.

### DB 호출
- `AnnouncementRepository.save(Update{isImportant})`
- `AnnouncementDisplayRepository.save(Insert/Update{isDisplay})`

---

## 29. PUT `/api/admin/announcements/by-menu/{menuType}` — 메뉴별 노출 설정 (배치)

**Request**: `ModifyAnnouncementByMenuRequest[]` (varargs) — 메뉴당 여러 공지 순서 설정

반복 루프로 각 공지에 대해 `modifyAnnouncementByMenu(command, userId)` 호출. 내부는 `AnnouncementByMenuRepository.save`.

---

## 30. GET `/api/admin/announcements/by-menu` — 메뉴별 공지 목록 (Admin)

18번과 동일 Proxy 메서드(`announcementByMenuList`) — userId 없이 호출(전체 조회).

---

## 31. GET `/api/admin/announcements/by-menu/menus` — 노출 가능 메뉴 목록

### Response — `List<MenuListResponse>`

### DB 호출 **없음**. `AnnouncementMenuType.getActiveMenuTypes()` enum 정적 메서드 반환.

---

## 32. 참고 — 이 문서의 Gateway / Repository / Mapper

### Gateway 구현체 (이 레포)

| 구현체 | 대상 |
|---|---|
| `NewsGatewayImpl` | `CampaignUpdateRepository` (Spring Data JDBC) |
| `NewsQueryGatewayImpl` | `NewsMapper` (MyBatis) |
| `NewsLanguageGatewayImpl` | `CampaignUpdateLanguageRepository` |
| `NewsNotificationGatewayImpl` / `NewsNotificationDenyGatewayImpl` | `CampaignUpdateNotificationDeny*Repository` |
| `NewsNotificationQueryGatewayImpl` | `NewsNotificationMapper` (MyBatis) |
| `NewsNotificationLogGatewayImpl` | **MongoDB** `NewsNotificationLogMongoRepository` (`@Async`) |
| `AnnouncementGatewayImpl` | `AnnouncementRepository`, `AnnouncementDisplayRepository`, `AnnouncementByMenuRepository`, `AnnouncementDoNotShowAgainRepository`, `AnnouncementExposureRepository`, `AnnouncementMapper` |
| `AnnouncementQueryGatewayImpl` | `AnnouncementMapper` (목록 조회 전용) |

### MyBatis Mapper XML
- `NewsMapper.xml` — `search`, `count`, `detail` (번역 해시 매칭, 댓글수 서브쿼리)
- `NewsNotificationMapper.xml` — `notificationDenyCampaignSearch`, `notificationDenySupporterSearch` (2개 SQL 블록 공용)
- `AnnouncementMapper.xml` — `searchAnnouncementList/DisplayedList/HistoryList/ByMenuHistoryList`, `countAnnouncement*`, `countAnnouncementImportant`

### MongoDB Collection
- `NewsNotificationLog` — 알림 수신 거부 설정 변경 로그 (`@Async` 저장)

### 접근 테이블 합계

- **MySQL**: `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateTagMapping`, `MiniBoardCommon`, `CampaignUpdateNotificationDeny`, `CampaignUpdateNotificationDenyLog`, `Announcement`, `AnnouncementDisplay`, `AnnouncementByMenu`, `AnnouncementByMenuHistory`, `AnnouncementDoNotShowAgain`, `AnnouncementExposure`, `AnnouncementHistory`, `UserProfile`
- **MongoDB**: `NewsNotificationLog`

### 주요 enum
- `NewsType` / `NewsTagType` / `NewsRestrictReason` (flags combine)
- `AnnouncementMenuType` (`getActiveMenuTypes()` 정적 상수)
- `ActionType` — UPDATE_CONTENTS 등 감사용
- `ImportantFilterType / DisplayFilterType / DisplayByMenuFilterType` — Admin 검색 필터
