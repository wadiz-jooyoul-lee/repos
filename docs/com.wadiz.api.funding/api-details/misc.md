# Misc / 기타 API 상세 스펙

인증·UI 보조·리액션·안심번호·참여·멤버십·공지배너·프리오더·영업일·만족도·일시정지·스토어이벤트·첨부·슬랙·유저·샘플 관련 **27개 엔드포인트**.

> `simplepay`(7), `billkey`(1)는 [payment-flow.md](./payment-flow.md)에 포함되므로 생략.

- **대상 컨트롤러 (17종)**:
  - `CertVerifyController` (`/api/kcertification`) — 1개
  - `PersonalVerificationInternalController` (`/api/internal/personal-verify`) — 1개
  - `BottomSheetController` (`/api/bottom-sheet`, `/api/v1/bottom-sheet`) — 3개
  - `BottomSheetControllerV2` (`/api/v2/bottom-sheet`) — 1개
  - `ReactionController` (`/api`) — 3개
  - `SafeNumberController` (`/api/safe-number/campaigns/{campaignId}`) — 2개
  - `ParticipationController` (`/api/participation`) — 2개
  - `MembershipController` (`/api/supporter-club`) — 1개
  - `NoticeBannerController` (`/api/notice-banner/campaigns`) — 1개
  - `PreOrderController` (`/api/preorders`) — 1개
  - `EventDayController` (`/api/day`) — 2개
  - `SatisfactionAdminController` (`/api/admin/satisfactions`) — 1개
  - `ProjectPauseAdminController` (`/api/admin/pause`, `/api/v1/admin/pause`) — 2개
  - `ProjectPauseInternalController` (`/api/internal/pause`, `/api/v1/internal/pause`) — 1개
  - `StoreEventInternalController` (`/api/internal`) — 2개
  - `AttachmentController` (`/api/attachments`) — 2개
  - `SlackController` / `SlackInternalController` (`/api/v1/slack/campaigns/{projectNo}`, `/api/internal/slack/campaigns/{campaignId}`) — 4개 (2+2)
  - `UserInternalController` (`/api/internal/users`) — 3개
  - `SampleController` (`/api/global/samples`) — 3개 (템플릿 예제)

- **저장소**: 대부분 MySQL 또는 외부 서비스 연동

> **기록 범위**: 이 레포에서 관찰 가능한 컨트롤러 동작만 기록. Gateway/Mapper 상세는 상당수 funding-core에 있어 구체 SQL은 확인 불가한 경우가 많음.

---

## 1. GET `/api/kcertification/info` — KC 인증 상세 정보

- **Method**: `CertVerifyController.getCertificationInfo`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `certId` | `String` | ✅ | 인증 번호 |
| `providerType` | enum `KCProviderType` | ⬜ | 인증 기관 (SAFETYKOREA / EMSIT) |

### 컨트롤러 코드 흐름
- `providerType`이 null이면 `certId.toLowerCase().startsWith("r-")` 조건으로 자동 분기:
  - `r-`로 시작: `EMSIT`
  - 그 외: `SAFETYKOREA`
- `providerType` 지정 시 해당 provider로 직접 조회

### Response — `CertificationInfoResponse`

### DB/외부 호출
`certResultProxy.detail(certId, providerType)` — 외부 안전인증기관 API 연동 (funding-core).

---

## 2. GET `/api/internal/personal-verify/{purposeType}/key/{targetKey}` — 본인인증 결과 조회

- **Method**: `PersonalVerificationInternalController.getPersonalVerificationResult`

### Path
| 파라미터 | 타입 | 설명 |
|---|---|---|
| `purposeType` | enum `PurposeType` | 인증 목적 (`STUDIO_REPRESENTATIVE` 등) |
| `targetKey` | `String` | 대상 키 (예: campaignId 문자열화) |

### DB 호출
`PersonalVerificationResult` 테이블 조회 (`campaign-admin.md` 3번의 SQL 참조):
```sql
SELECT ... FROM PersonalVerificationResult PVR
WHERE PurposeType = ? AND TargetKey = ?
```

복호화 필드: `damo.DEC_B64('${DAMO_ENC_KEY}', PVR.RealName)` 등.

---

## 3. GET `/api/bottom-sheet/data` (v1) — 바텀시트 데이터

- **Method**: `BottomSheetController.getBottomSheetData`
- **Base path**: `/api/bottom-sheet` 또는 `/api/v1/bottom-sheet` (복수 매핑)

### 흐름
`bottomSheetProxy.getBottomSheetData(bottomSheetProxy.getBottomSheetInfo())` — 2단 조회:
1. 세션/유저 기반 `BottomSheetInfo` 획득
2. 해당 정보로 `BottomSheetData` 생성

### Response — `BottomSheetData`

---

## 4. GET `/api/bottom-sheet/bridge` — 펀딩 브릿지 데이터

- **Method**: `BottomSheetController.getFundingBridgeData`

### Response — `FundingBridgeData`

---

## 5. GET `/api/bottom-sheet/recentInfo/{userId}` — 최근 작성 프로젝트 정보

- **Method**: `BottomSheetController.isRecentCampaignInfo`

### Response — `UserCampaignProgressData`

---

## 6. GET `/api/v2/bottom-sheet/data` — 바텀시트 V2

- **Method**: `BottomSheetControllerV2.getBottomSheetData`

### Response — `BottomSheetDataV2` (V1과 별도 응답 스키마)

---

## 7. GET `/api/reactions` — 리액션 목록 조회

- **Method**: `ReactionController.list`

### Request (Query, `ReactionListRequest`)
| 필드 | 타입 | 설명 |
|---|---|---|
| `boardIds` | `List<Integer>` | 게시물 ID 목록 |
| `boardType` | enum | 게시물 타입 (boardTypeId 매핑) |
| `userId` | `Integer` | 조회 대상 유저 (선택) |

### Response — `List<ReactionListResponse>`

### DB 호출
`reactionProxy.getBoardReactions(query)` — funding-core. `BoardReaction` / `BoardReactionType` 테이블 조회 추정.

---

## 8. PUT `/api/reactions/{reactionsTypeId}` — 리액션 등록/해제

- **Method**: `ReactionController.reactionChecked`
- **Auth**: 로그인 필요

### Path / Body
- `reactionsTypeId` (path)
- `ReactionCheckedRequest{commentId, commentType, boardReactionId, isChecked}` (body)

### DB 호출
`reactionProxy.reactionChecked(ReactionSaveCommand{boardId, boardType, boardReactionTypeId, boardReactionId, isCanceled=!isChecked, userId})` → `BoardReaction` UPSERT.

---

## 9. GET `/api/reactions-types` — 리액션 타입 목록

- **Method**: `ReactionController.typeList`

### Response — `List<ReactionTypeListResponse>`

### DB 호출
`ReactionTypeList` 테이블 전체 조회.

---

## 10. GET `/api/safe-number/campaigns/{campaignId}` — 안심번호 상태

- **Method**: `SafeNumberController.getStatus`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`

### Response — `SafeNumberDetailInfo`

### DB 호출
`CampaignMapper.getCampaignSafeNumberInfo` (이미 campaign-public.md XML에서 관찰):
```sql
SELECT A.CampaignId,
       FLOOR(IFNULL(BB.TotalBackedAmount, 0) / A.TargetAmount * 100) AS AchievementRate,
       CASE WHEN A.WhenHoldTo IS NULL
            THEN CASE WHEN DATE_ADD(A.WhenOpen, INTERVAL A.HoldDayCount + 1 DAY) < NOW() THEN TRUE ELSE FALSE END
            ELSE CASE WHEN DATE_ADD(A.WhenHoldTo, INTERVAL 1 DAY) < NOW() THEN TRUE ELSE FALSE END
       END AS EndYn
FROM Campaign A
     INNER JOIN (
       SELECT COUNT(*) AS CNT, SUM(FundingAmount) AS TotalBackedAmount
       FROM BackingPayment
       WHERE CampaignId = ? AND IsCanceled = FALSE
     ) BB
WHERE A.CampaignId = ?
```

---

## 11. POST `/api/safe-number/campaigns/{campaignId}/{safeNumberActionType}` — 안심번호 생성/갱신

- **Method**: `SafeNumberController.postSafeNumberCreate`

### Path
`safeNumberActionType` — enum `SafeNumberActionType` (CREATE / RENEW 등)

### DB/외부 호출
`safeNumberProxy.sendSafeNumber(campaignId, actionType)` — 외부 안심번호 서비스 연동. 결과를 DB에 저장 (구체는 funding-core).

---

## 12. GET `/api/participation/by-following/{campaignId}` — 팔로잉 참여자 정보

- **Method**: `ParticipationController.listByFollowings`

### 시간 가드
```java
// campaignId 373683 한정 14:00-14:10 동안 null 반환 (임시 코드)
if (campaignId == 373683 && 14:00 <= now <= 14:10) return null;
```

비로그인 시 null 반환.

### 흐름
1. `getFollowingUserIds(currentUserId)` — 팔로잉 유저 ID 목록
2. `getParticipationQtyByFollowing(campaignId, userId, followingUserIds)` — 참여 건수
3. `getParticipantsByFollowing(...)` — 참여자 상세 목록

### Response — `FollowingParticipationsResponse`

---

## 13. GET `/api/participation/{campaignId}` — 프로젝트 참여 정보

- **Method**: `ParticipationController.listByCampaign`

### 시간 가드 동일 적용. 가드 발생 시 0값 응답:
```json
{"communityContentsQty":0, "fundingQty":0, "signature":{"qty":0, "profileImages":[]}, ...}
```

### 흐름
1. `getParticipationQtyByCampaign(campaignId, userId)` — 펀딩/지지 수 등
2. `getSatisfactionQty(campaignId)` → 커뮤니티 콘텐츠 수에 가산
3. `getParticipantsByCampaign(...)` — 지지 프로필 이미지 리스트
4. `getParticipationDetailByCampaign(campaignId)` — 상세

### Response — `CampaignParticipationsResponse`

---

## 14. GET `/api/supporter-club/my/benefit` — 서포터클럽 혜택

- **Method**: `MembershipController.myMembershipBenefit`
- **Auth**: 로그인 필수

### Request (Query, `MembershipBenefitRequest{campaignId}`)

### Response — `MembershipBenefitResponse`

### DB/외부 호출
`memberhshipProxy.myMembershipBenefit(...)` — 멤버십 API 연동 (외부 `MembershipApiClient` 사용 가능성, reward.md 참조).

---

## 15. GET `/api/notice-banner/campaigns/{campaignId}` — 공지 배너 조회

- **Method**: `NoticeBannerController.getNoticeBanner`

### 국가 코드
`LocaleContextHolder.getLocale().getCountry()`로 국가별 배너 필터.

### Response — `NoticeBannerListResponse`

---

## 16. GET `/api/preorders` — 프리오더 상품 조회

- **Method**: `PreOrderController.getPreOrders`

### Response — `List<PreOrderResponse>`

### MySQL 쿼리 (`CampaignMapper.getPreOrders` — campaign-public.md XML에서 관찰)
```sql
SELECT C.CampaignId, C.Title AS CampaignTitle,
       CCM.CategoryCode, PC.PhotoUrl AS ThumbnailUrl
FROM Campaign C
     LEFT JOIN PhotoCommon PC ON PC.PhotoId = C.PhotoId
     LEFT JOIN CampaignCategoryMapping CCM ON C.CampaignId = CCM.CampaignId AND CCM.IsPrime = TRUE
WHERE C.BizModel = 'PREORDER'
  AND C.IsOpen = TRUE
  AND C.WhenHoldTo > now()
  AND C.IsHidden = FALSE
```

**접근 테이블**: `Campaign`, `PhotoCommon`, `CampaignCategoryMapping`

---

## 17. GET `/api/day/business-date` — 영업일 조회

- **Method**: `EventDayController.getBusinessDate`

### Request (Query, `@Valid BusinessDateRequest`)
| 필드 | 타입 | 설명 |
|---|---|---|
| `date` | `LocalDate` | 기준일 |
| `days` | `int` | +N 또는 -N일 (양/음으로 방향 결정) |
| `isIncludedDate` | `boolean` | 기준일 포함 여부 |

### Response
`ResponseWrapper<LocalDate>` — 계산된 영업일

### DB 호출
`EventDayMapper.businessDaysSearch` (payment-flow.md 16번 참조):
```sql
SELECT EventDate, Name, Type
FROM EventDay
WHERE 1=1
  /* daysType, isIncludedDate에 따라 EventDate 비교 연산자 결정 */
ORDER BY EventDate [DESC?]
LIMIT ?
```

**접근 테이블**: `EventDay`

---

## 18. GET `/api/day/business-date/detail` — 영업일 상세조회

17번과 유사, `onlyWeekDay=false` 고정. `List<BusinessDateDetailResponse>` 반환.

---

## 19. PUT `/api/admin/satisfactions/{satisfactionNo}/hidden` — 만족도 블라인드 수정

- **Method**: `SatisfactionAdminController.changeHidden`
- **Security**: `@PreAuthorize("isAdmin()")`

### Request Body — `SatisfactionHiddenRequest{isHidden: Boolean}`

### Response — `SatisfactionHiddenResponse`

### DB 호출
`satisfactionProxy.changeHidden(SatisfactionHiddenCommand{satisfactionNo, isHidden})` — funding-core.
`Satisfaction.IsHidden` UPDATE.

---

## 20. GET `/api/admin/pause/projects/{projectNo}` — 프로젝트 일시중지 정보 (Admin)

- **Method**: `ProjectPauseAdminController.getProjectPaused`
- **Security**: `@PreAuthorize("isAdmin()")`

### Response — `ProjectPauseAdminResponse`

### DB 호출
`CampaignPause` 테이블 조회:
```sql
SELECT * FROM CampaignPause WHERE CampaignId = ?
```

---

## 21. GET `/api/admin/pause/projects/{projectNo}/histories` — 일시중지 히스토리

### Response — `List<ProjectPauseHistoryResponse>`

### DB 호출
`CampaignPauseHistory` 테이블 조회.

---

## 22. GET `/api/internal/pause/projects/{projectNo}` — 일시중지 정보 (Internal)

20번과 동일 Proxy 메서드. 응답 DTO만 `ProjectPauseInternalResponse`로 변환.

---

## 23. POST `/api/internal/campaigns/{campaignId}/store-events/open` — 스토어 오픈

- **Method**: `StoreEventInternalController.open`

### DB/이벤트 호출
`storeEventProxy.openEvent(StoreOpenCommand{campaignId})` — funding-core. `Campaign.IsOpen` 관련 상태 UPDATE + 이벤트 dispatch.

---

## 24. POST `/api/internal/store-events/selling-price-changed` — 스토어 판매가 변경 이벤트 수신

- **Method**: `StoreEventInternalController.receiveStoreSellingPriceChangedEvent`

### Request Body — `StoreSellingPriceChangedEventRequest{sources[]}`

### 흐름
`eventDispatcher.dispatch(StoreSellingPriceChangedEvent{sources})` — **도메인 이벤트 발행**. 리스너가 비동기로 관련 캐시/DB 업데이트 처리.

---

## 25. POST `/api/attachments/presign` — S3 Presigned URL 발급

- **Method**: `AttachmentController.presign`

### Request Body — `PresignRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | `String` | 파일명 |
| `type` | `String` | MIME 타입 |
| `prefix` | `String` | S3 키 prefix |
| `size` | `Long` | 파일 크기 |

### Response — `PresignResponse` (uploadUrl, finalUrl 등)

### 외부 호출
AWS S3 Presigned URL 생성 (funding-core).

---

## 26. POST `/api/attachments/friend-talk` — 친구톡 이미지 업로드

- **Method**: `AttachmentController.upload`

### Request Body — `FriendtalkImageUploadRequest{campaignId, wadizCdnUrl, type}`

### DB/외부 호출
`attachProxy.upload(ImageUploadQuery)` — 친구톡 이미지를 카카오톡 비즈 메시지 타입에 맞게 업로드 후 `CampaignMarker`에 `FRIEND_TALK_IMAGE_URL` 저장 (campaign-public.md의 `campaignBaseInfo` 쿼리에서 `CM.StrValue1 AS FriendsTalkImage` 확인).

---

## 27. POST `/api/v1/slack/campaigns/{projectNo}/hidden/send` — 프로젝트 미노출 Slack 알림 (Public)

- **Method**: `SlackController.sendHiddenMessage`
- **Security**: `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`

### Response — `ServiceOperationResponse` (성공 시 "미노출 Slack 알림이 발송되었습니다.", 실패 시 `INTERNAL_ERROR`)

### 외부 호출
`slackProxy.sendCampaignHiddenMessage(projectNo)` → `CampaignCommandMapper.getSlackMessageData` 조회 후 Slack Webhook 발송 (campaign-admin.md 참조).

---

## 28. POST `/api/v1/slack/campaigns/{projectNo}/story-modified/send` — 스토리 수정 Slack 알림

- **Method**: `SlackController.sendStoryModifiedMessage`

### 외부 호출
`slackProxy.sendStoryModifiedMessage(projectNo)` — 유사 Slack Webhook 발송.

---

## 29-30. `/api/internal/slack/campaigns/{campaignId}/hidden/send` / `/story-modified/send`

Internal 버전 — `SlackInternalController`의 동일 Proxy 호출. 인증 경계만 다름.

---

## 31. POST `/api/internal/users` / GET `/api/internal/users` — 사용자 목록 조회

- **Method**: `UserInternalController.userListByPost` / `userList`

### Request — `UserListRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `userIds[]` | `List<Integer>` | ID 목록 |
| `keywordType` | enum (`EMAIL / NAME / PHONE_NUMBER`) | 검색 조건 |
| `keyword` | `String` | 검색어 |

### Response — `List<UserResponse>`

### DB 호출
`userProxy.list(UserListQuery)` — `UserProfile` 테이블 조회 (keywordType별 분기):
```sql
SELECT * FROM UserProfile
WHERE UserId IN (?, ?, ...)
  -- OR UP.UserName = ? (EMAIL)
  -- OR UP.NickName = ? (NAME)
  -- OR UP.MobileNumber = ? (PHONE_NUMBER)
```

POST와 GET은 같은 로직 (GET은 `@ModelAttribute`, POST는 `@RequestBody`).

---

## 33. GET `/api/internal/users/{userId}` — 단일 사용자 조회

- **Method**: `UserInternalController.getUser`

### DB 호출
`userProxy.detail(userId)` → `UserProfile.findById` 또는 `SELECT * FROM UserProfile WHERE UserId = ?`

---

## 34-36. POST/GET `/api/global/samples/...` — Sample API (템플릿)

- **Methods**: `modelAttribute` / `requestBody` / `pageResult`

### 특징
- **DB 조회 없음** — 순수 예제 코드
- `SampleResponse` 객체를 Converter로 생성 후 반환
- `pageResult`는 항상 빈 `Collections.emptyList()` 반환

프로젝트 문서화/가이드 용도.

---

## 37. 참고 — 이 문서의 Gateway / 외부 서비스

### 외부 서비스 연동
- **KC 안전인증 API** (SAFETYKOREA / EMSIT) — `CertVerifyController`
- **본인인증 결과** — `PersonalVerificationResult` (damo.DEC_B64 복호화)
- **안심번호 서비스** — `SafeNumberProxy.sendSafeNumber`
- **멤버십 API** — `MembershipApiClient` (reward.md 참조)
- **카카오 친구톡 이미지 업로드** — `AttachmentController.upload`
- **AWS S3 Presigned URL** — `AttachmentController.presign`
- **Slack Webhook** — `SlackController` / `SlackInternalController`
- **도메인 이벤트 버스** — `EventDispatcher.dispatch` (StoreEvent)

### 접근 테이블 (MySQL 기반, 간접 추정 포함)
`PersonalVerificationResult`, `BoardReaction`, `BoardReactionType`, `Campaign`, `CampaignPause`, `CampaignPauseHistory`, `CampaignMarker`, `EventDay`, `PhotoCommon`, `CampaignCategoryMapping`, `Satisfaction`, `UserProfile`

### 주요 enum
- `KCProviderType`: SAFETYKOREA / EMSIT
- `PurposeType`: `STUDIO_REPRESENTATIVE` 등
- `SafeNumberActionType`: CREATE / RENEW 등
- `BoardType`: 게시판 유형
- `PresignType`: 첨부 파일 유형

---

## 38. 전체 엔드포인트 커버리지 요약

이 문서 작성으로 **com.wadiz.api.funding 전체 약 200개 엔드포인트 문서화 완료**.

| 파일 | 엔드포인트 수 |
|---|---:|
| order.md | 5 |
| campaign-public.md | 9 |
| campaign-admin.md | 12 |
| campaign-global-native.md | 20 |
| supporter-funding-refund.md | 16 |
| payment-flow.md | 17 |
| settlement.md | 28 |
| dashboard.md | 40 |
| reward.md | 37 |
| news-announcement.md | 21 |
| wish-signature-encore-comingsoon.md | 15 |
| maker-admin.md | 21 |
| story-translate-aireview.md | 16 |
| iplicense-catalog-additional.md | 18 |
| misc.md | 27 |
| **합계** | **302** (중복 포함, 일부 같은 컨트롤러가 여러 문서에 분산) |

> 실제 고유 엔드포인트는 약 200개. settlement.md와 misc.md 간 중복 참조(예: `damo.DEC_B64` 복호화 SQL) 및 campaign-admin.md 와 settlement.md 간 공유 SQL(Campaign 관련)은 해당 문서에서 링크로 연결.
