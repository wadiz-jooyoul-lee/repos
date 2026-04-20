# 지지서명 V3 (Supporter Signature V3) 상세 스펙

> **기록 범위**: `com.wadiz.wave.user/src/main/java/.../supporter/signature/v3/**` 의 컨트롤러·DTO·서비스와
> `src/main/resources/mapper/wadiz/supporter/signature/*.xml` 에서 **직접 관측 가능한** 호출·SQL만 기록.
> - 서비스가 호출하는 `component.*CommandComponent / *QueryComponent` 내부 로직(트랜잭션 조합, Redis/EhCache hit 조건,
>   Push/메일 전송 전문 등)은 구현 세부라 본 문서에서는 **경계까지만** 표시.
> - 외부 `funding`/`campaign` 등 타 서비스 호출은 관측되지 않음(서명 V3는 자체 DB + Push Gateway만 사용).
> - 코드상 "V3 컨트롤러 11개" 로 지시되었으나 실제 디렉터리 스캔 결과 **10개**. 누락 파일 없음(`v3/*.java` 전수 10개 확인,
>   나머지 1개는 하위 `v3/service/*` / `v3/dto/*` 패키지 클래스들의 다발로 보임).

---

## 1. 개요

### V3가 V1 대비 달라진 점 (관측 사실)
- **라우트 구조 재설계**: V1의 단일 prefix `/api/v1/users/supporter-signatures/...` (user-id 를 바디/쿼리로 받던 혼재 구조) 를,
  V3는 **리소스 컨트롤러 (`/api/v3/supporter-signatures/...`) vs 사용자 컨트롤러 (`/api/v3/users/{userId}/supporter-signatures/...`)** 로
  **URL 경로에서 분리** (모든 V3 User 컨트롤러는 `{userId}` 를 PathVariable로 강제).
  - V1의 기존 경로는 각 V3 컨트롤러 상단에 `// Old: /api/v1/users/supporter-signatures/...` 주석으로 명시 유지.
  - 확인 지점: `SupporterSignatureAffiliateV3Controller.java:38,50,63`, `SupporterSignaturePointV3Controller.java:71,84,102`,
    `SupporterSignatureInterestDegreeV3Controller.java:41,57`, `SupporterSignaturePointV3UserController.java:137`,
    `SupporterSignatureAffiliateV3UserController.java:40`.
- **"event/tracking" 용어 제거 → "affiliate" 로 통일**: 지지서명을 통한 구매 추적·포인트 지급 기능이 V1에서는
  `event/tracking/...` 경로, V3에서는 `affiliates/...` 로 리네임.
- **DTO 슬림화**:
  - V3 `KeywordV3` 에서 `message`, `backgroundColor` 필드 제거 — "FE 다국어 처리로 미사용, FE 미사용" (`SupporterSignatureKeywordV3Dto.java:27`).
  - `SignatureDetailV3` 에 `availableMaxPointRatio`(공유 시 최대 포인트 비율) 필드 추가되어 V1 대비 포인트 정책을
    응답 스펙에 노출.
- **Cursor 페이지네이션 공식화**: 모든 목록 API가 `usingCursor / cursorId` 파라미터를 가지며, SQL에서 `SignatureId` 기반
  키셋 페이지네이션 (`supporterSignature-mapper.xml:312-331, 388-408` 참조).
- **응답 모델의 isOwner / reactions / commentCount 인라인 조립**:
  V3 `SignatureDetailV3` 는 댓글 수·리액션 통계·키워드·유저 프로필을 단일 `findDetail` SQL 로 collection 매핑하여 반환
  (`supporterSignature-mapper.xml:179-225`).

### 내부(Internal) vs 사용자(User) 엔드포인트 분리 의미
- `*V3Controller` (리소스 컨트롤러) — **조회·집계·관리자 삭제·운영용 발송 API**. `loginUserId` 는 optional query param 이며,
  내부 서비스 / 어드민에서 호출하는 것으로 보임.
  - 예: 캠페인별 서명 목록, 서명 상세, 캠페인별 서명 수, 유저 이미지 목록, 관리자 일괄 삭제, 관심도 푸시, 어필리에이트 결과 업데이트.
- `*V3UserController` (사용자 컨트롤러) — **본인 `{userId}` 기반 CRUD**. 서명 작성/수정, 내 서명 조회/카운트, 내 포인트,
  댓글 작성·수정·삭제, 리액션, 트래킹 생성 등 **일반 사용자의 self-mutation** 을 담당.
  - 권한 체크는 서비스 레이어에서 `entity.getUserId().equals(userId)` 불일치 시 `UserForbiddenApiException`
    (`SupporterSignatureV3UserService.java:42`, `SupporterSignaturePointV3UserController.java:117`).

### `co.wadiz.api.community` 로의 이관 상태 (관측 가능 범위)
- `docs/co.wadiz.api.community.md:4` — "`com.wadiz.wave.user` 의 **Supporter Signature V3** 모듈을 독립 서비스로 포팅하며 …
  **Phase 0~1 (스캐폴드만 구축)** 단계. 도메인 코드는 미구현."
- 즉 **현재 트래픽은 여전히 `com.wadiz.wave.user` 의 V3 컨트롤러가 처리**. Community 서비스는 RabbitMQ DirectExchange
  `community.signature.exchange` 준비 상태로 포팅 대기.
- `co.wadiz.api.community` 쪽에서 wave.user 로의 역호출·HTTP 클라이언트 임포트는 wave.user 코드에서 관측되지 않음
  (grep `co.wadiz.api.community|community-api|community api` → 0 hit).

---

## 2. 엔드포인트 전수 테이블

컨트롤러 10개, 엔드포인트 **28개**.

| # | Controller | Method | Path | 요약 |
|---|---|---|---|---|
| **1. SupporterSignatureV3Controller** (`base: /api/v3/supporter-signatures`) |||||
| 1-1 | V3 | GET | `/{signatureId}` | 특정 지지서명 상세 조회 |
| 1-2 | V3 | DELETE | `/{signatureId}` | 메이커 삭제 (deleteType=DELETE_BY_MAKER 강제) |
| 1-3 | V3 | GET | `` | 캠페인별 서명 목록 조회 |
| 1-4 | V3 | GET | `/count` | 캠페인별 서명 개수 |
| 1-5 | V3 | GET | `/counts` | 여러 캠페인별 서명 개수 |
| 1-6 | V3 | GET | `/user-images` | 캠페인별 사용자 이미지 목록 |
| 1-7 | V3 | DELETE | `` | 캠페인 전체 서명 삭제 (DELETED_BY_ADMIN 강제) |
| **2. SupporterSignatureV3UserController** (`base: /api/v3/users/{userId}/supporter-signatures`) |||||
| 2-1 | V3User | POST | `` | 지지서명 생성 |
| 2-2 | V3User | PUT | `/{signatureId}` | 지지서명 수정 |
| 2-3 | V3User | GET | `/count` | 내 서명 개수 |
| 2-4 | V3User | GET | `/id` | (@Deprecated) 특정 캠페인 서명 ID |
| 2-5 | V3User | GET | `/status` | 특정 캠페인 서명 상태 + 최대 포인트 비율 |
| 2-6 | V3User | GET | `/detail` | 특정 캠페인 서명 상세 |
| 2-7 | V3User | GET | `` | 내 서명 목록 |
| **3. SupporterSignatureKeywordV3Controller** (`base: /api/v3/supporter-signatures/keywords`) |||||
| 3-1 | Keyword | GET | `` | 키워드 목록 조회(COMMON) |
| 3-2 | Keyword | GET | `/count` | 캠페인별 키워드 개수 |
| **4. SupporterSignatureInterestDegreeV3Controller** (`base: /api/v3/supporter-signatures/interest-degree`) |||||
| 4-1 | InterestDegree | POST | `/notification/range/1` | 관심도 1구간 메시지 발송 |
| 4-2 | InterestDegree | POST | `/notification/range/2` | 관심도 2구간 메시지 발송 |
| **5. SupporterSignaturePointV3Controller** (`base: /api/v3/supporter-signatures/points`) |||||
| 5-1 | Point | GET | `/total-info` | 전체 포인트 통계(기본 전일 기준 1년치) |
| 5-2 | Point | GET | `/affiliates/versions` | 어필리에이트 포인트 버전 목록 |
| 5-3 | Point | GET | `/affiliates/{trackingId}/issue-key` | 트래킹 포인트 발급 키 조회 |
| 5-4 | Point | POST | `/affiliates/notification` | 어필리에이트 포인트 푸시 |
| **6. SupporterSignaturePointV3UserController** (`base: /api/v3/users/{userId}/supporter-signatures`) |||||
| 6-1 | PointUser | GET | `/points` | 내 포인트 상세 리스트 (cursor) |
| 6-2 | PointUser | GET | `/points/count` | 내 포인트 레코드 개수 |
| 6-3 | PointUser | GET | `/points/total` | 내 포인트 전체 요약 |
| 6-4 | PointUser | GET | `/{signatureId}/points/detail` | 특정 서명 공유/포인트 상세 |
| 6-5 | PointUser | POST | `/{signatureId}/points/affiliates/{trackingId}` | 트래킹 포인트 지급 |
| **7. SupporterSignatureCommunicationV3Controller** (`base: /api/v3/supporter-signatures`) |||||
| 7-1 | Communication | GET | `/{signatureId}/comments` | 댓글 다건 조회 (cursor) |
| **8. SupporterSignatureCommunicationV3UserController** (`base: /api/v3/users/{userId}/supporter-signatures`) |||||
| 8-1 | CommUser | POST | `/{signatureId}/comments` | 댓글 생성 |
| 8-2 | CommUser | PUT | `/comments/{commentId}` | 댓글 수정 |
| 8-3 | CommUser | DELETE | `/comments/{commentId}` | 댓글 삭제 (HTTP 204) |
| 8-4 | CommUser | PUT | `/{signatureId}/reactions/{reactionTypeId}` | 서명 리액션 upsert |
| 8-5 | CommUser | PUT | `/comments/{commentId}/reactions/{reactionTypeId}` | 댓글 리액션 upsert |
| **9. SupporterSignatureAffiliateV3Controller** (`base: /api/v3/supporter-signatures`) |||||
| 9-1 | Affiliate | PUT | `/affiliates/results` | 추적 결과 업데이트 |
| 9-2 | Affiliate | PUT | `/affiliates/canceled-signatures/results` | 취소된 서명의 추적 결과 업데이트 |
| 9-3 | Affiliate | GET | `/affiliates/targets/count` | 포인트 적립 대상 개수 |
| **10. SupporterSignatureAffiliateV3UserController** (`base: /api/v3/users/{userId}/supporter-signatures`) |||||
| 10-1 | AffUser | POST | `/{signatureId}/affiliates` | 트래킹 생성 (결제 시점) |

주) 1-2(`DeleteMapping("/{signatureId}")`)와 1-7(`DeleteMapping("")`)은 둘 다 `SupporterSignatureDeleteType` enum을
쿼리스트링으로 받되, 컨트롤러 단에서 허용값을 **강제 체크**한다. (`SupporterSignatureV3Controller.java:63,149`)

---

## 3. 컨트롤러별 상세

> 공통: 전부 `@UserApiExceptionHandling` + `@Validated`. Swagger 는 `@Api(tags=...)` 로 한글 태그 부여.
> 인증·인가 어노테이션(`@PreAuthorize` 등)은 V3 컨트롤러에 **관측되지 않음** — 내부 네트워크/BFF 레이어에서 처리되는 것으로 보임.

---

### 3.1 `SupporterSignatureV3Controller`
파일: `.../v3/SupporterSignatureV3Controller.java`
Service: `SupporterSignatureV3Service`
의존 Component: `SupporterSignatureCommandComponent`, `SupporterSignatureQueryComponent`, `SupporterSignatureAffiliateCommandComponent`

| Method | Path | 입력 | 서비스 호출 | 핵심 SQL |
|---|---|---|---|---|
| GET | `/{signatureId}` | signatureId, loginUserId?, hasPaymentInfo(def:false) | `signatureDetail(...)` | `findDetail` (SQL 아래) |
| DELETE | `/{signatureId}` | deleteType (DELETE_BY_MAKER 만 허용) | `deleteByMaker(...)` → `CommandComponent.deleteBySignatureId(signatureId, DELETED_BY_MAKER)` | `deleteSignatureBySignatureId` |
| GET | `` | campaignId, loginUserId?, hasUserProfile, hasPaymentInfo(def:true), usingCursor, cursorId, page, size, sortType(DESC) | `signatureDetails(...)` | `findDetailByCampaignId` |
| GET | `/count` | refreshCaching(def:false), campaignId | `countByCampaignId(...)` | `findCountByCampaignId` (+ Redis 캐시, 아래 참조) |
| GET | `/counts` | campaignIds(List<Integer>) | `countsByCampaignIdList(...)` | `findCountByCampaignIdList` |
| GET | `/user-images` | campaignId, usingCache(def:true), isRandom(def:true), usingCursor, cursorId, page, size, sortType | `signatureUserImages(...)` | `findUserImageInfoByCampaignId` |
| DELETE | `` | campaignId, deleteType (DELETED_BY_ADMIN 만 허용) | `deleteSignatureByAdmin(...)` | `deleteSignatureByCampaignId` |

**대표 SQL — `findDetail`** (`supporterSignature-mapper.xml:179-225`, 발췌):
```sql
SELECT S.SignatureId, S.UserId, S.CampaignId, S.Provider, S.WhenCreated, S.Updated, S.Content, S.TrackingPointInfoVersion
     , UP.NickName, UP.UserStatus, P.PhotoUrl
     , M.end MembershipEnd, M.state MembershipState
     , IF(F.FollowNo IS NULL, false, true) IsFollowing
     , IF(UB.OptIn IS NULL, false, true) IsBlocking
     , (SELECT COUNT(*) FROM wadiz_wave_follow.Follow F1
        WHERE F1.FollowingUserId = S.UserId AND F1.OptIn = true) AS FollowerCount
     , (SELECT COUNT(*) FROM SupporterSignatureComment
        WHERE SignatureId = S.SignatureId AND IsDeleted IS FALSE) AS CommentCount
     , SSKD.KeywordId
     , SSRS.ReactionTypeId as TypeId, SSRS.ReactionCount as Count
     , IF(SSR.IsChecked IS NULL, false, SSR.IsChecked) as IsChecked
FROM Signature S
  LEFT JOIN SupporterSignatureKeywordData SSKD ON SSKD.SignatureId = S.SignatureId
  LEFT JOIN UserProfile UP on UP.UserId = S.UserId
  LEFT JOIN PhotoCommon P on P.PhotoId = UP.PhotoId
  LEFT JOIN wadiz_membership.member M on M.user_id = UP.UserId
  LEFT JOIN wadiz_wave_follow.Follow F
      ON UP.UserId = F.FollowingUserId AND F.FollowerUserId = #{loginUserId} AND F.OptIn = true
  LEFT JOIN wadiz_wave_follow.UserBlocking UB
      ON UB.UserId = #{loginUserId} AND UB.TargetUserId = S.UserId AND UB.OptIn = true
  LEFT JOIN wadiz_db.SupporterSignatureReactionStat SSRS
      ON SSRS.StatType = 1 AND SSRS.StatReferenceId = S.SignatureId
  LEFT JOIN wadiz_db.SupporterSignatureReaction SSR
      ON SSR.SignatureId = SSRS.StatReferenceId AND SSR.UserId = #{loginUserId} AND SSR.TypeId = SSRS.ReactionTypeId
WHERE S.SignatureId = #{signatureId} AND S.IsDeleted is FALSE
ORDER BY SSKD.KeywordId, SSRS.ReactionTypeId;
```

**특이사항**:
- 서비스 `signatureDetail` 은 `SignatureDetailV3.from(domain, affiliateCommandComponent.getAvailableMaxPointRatio(domain.getTrackingPointVersion()))`
  로 `availableMaxPointRatio` 를 추가 계산하여 반환. (`SupporterSignatureV3Service.java:30-36`)
- 삭제 API 두 건은 enum 강제 체크 (`UserForbiddenApiException`).
- `user-images` 는 `isRandom=true` 면 `ORDER BY RAND()` 로 랜덤 샘플링(`supporterSignature-mapper.xml:446-451`).

---

### 3.2 `SupporterSignatureV3UserController`
파일: `.../v3/SupporterSignatureV3UserController.java`
Service: `SupporterSignatureV3UserService`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| POST | `` | userId, CreateSignatureRequestV3{campaignId, content(<=1000), keywordIds(min=1)} | `create(...)` → `signatureCommandComponent.create(...)` | `insertData` + `SupporterSignatureKeywordDataMapper.insertDatas` |
| PUT | `/{signatureId}` | userId, signatureId, UpdateSignatureRequestV3 | `update(...)` → `getEntity` + owner 체크 + `update(entity,...)` | `find` → `updateContent` + keyword data replace |
| GET | `/count` | userId | `countByUserId(...)` | `findCountByUserId` (isAllCount=true 경로 호출) |
| GET | `/id` (@Deprecated) | userId, campaignId | `signatureId(...)` | `findIdByUserIdAndCampaignId` |
| GET | `/status` | userId, campaignId | `signatureStatus(...)` | `findByUserIdAndCampaignId` + `availableMaxPointRatio` 계산 |
| GET | `/detail` | userId, campaignId, loginUserId?, hasPaymentInfo | `signatureDetailByUserIdAndCampaignId(...)` | `findDetailByUserIdAndCampaignId` |
| GET | `` | userId, loginUserId(required), hasUserProfile, usingCursor, cursorId, page, size, sortType | `signatureDetailsByUserId(...)` | `findDetailByUserId` |

**`/status` 동작** (`SupporterSignatureV3UserService.java:63-77`):
- 해당 `(userId, campaignId)` Signature 엔티티가 있으면 `signatureId` + `availableMaxPointRatio(TrackingPointInfoVersion)` 반환.
- 없으면 `signatureId=null, availableMaxPointRatio=currentAvailableMaxPointRatio` 만 반환 (= V2 버전의 최대 비율 = `5f`,
  `SupporterSignatureAffiliatePointVersion.v2 = share 5f + feed 1f`).

**생성/수정 SQL** (`supporterSignature-mapper.xml:61-80`):
```sql
-- 지지서명 추가
INSERT INTO Signature (UserId, CampaignId, Content, TrackingPointInfoVersion)
VALUES (#{userId}, #{campaignId}, #{content}, #{trackingPointInfoVersion})
-- selectKey: SELECT LAST_INSERT_ID()

-- 지지서명 Content 수정
UPDATE Signature SET Content = #{content}
WHERE UserId = #{userId} AND CampaignId = #{campaignId}
```

---

### 3.3 `SupporterSignatureKeywordV3Controller`
파일: `.../v3/SupporterSignatureKeywordV3Controller.java`
Service: `SupporterSignatureKeywordV3Service` → `SupporterSignatureKeywordQueryComponent`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| GET | `` | refreshCaching | `findKeywordList(refreshCaching, SupporterSignatureKeywordType.COMMON)` | `findListByKeywordType` (+ Redis/EhCache: `SupporterSignatureKeywordCacheClient`) |
| GET | `/count` | campaignId, sortType | `findKeywordCountListByCampaignId(campaignId, sortType)` | `findCountByCampaignId` |

**SQL — 키워드 목록** (`supporterSignatureKeyword-mapper.xml:26-31`):
```sql
SELECT * FROM SupporterSignatureKeyword
WHERE KeywordType = #{keywordType}
ORDER BY KeywordOrder ASC
```

**SQL — 캠페인별 키워드 카운트** (`supporterSignatureKeywordData-mapper.xml:21-27`):
```sql
SELECT SSKD.KeywordId, COUNT(*) AS `count`
FROM Signature S
INNER JOIN SupporterSignatureKeywordData SSKD ON SSKD.SignatureId = S.SignatureId
WHERE S.CampaignId = #{campaignId}
GROUP BY SSKD.KeywordId ORDER BY `count` ${sortType};
```
> `${sortType}` 는 `@RequestParam SupporterSignatureConst.SearchSortType` enum (ASC/DESC) 에서 온다.

**특이사항**: V3 응답에서 `message`, `backgroundColor` 제거(위 1절 참고). DB 테이블에는 Message/KeywordOrder 가 존재하지만
응답 매핑만 제거.

---

### 3.4 `SupporterSignatureInterestDegreeV3Controller`
파일: `.../v3/SupporterSignatureInterestDegreeV3Controller.java`
Service: `SupporterSignatureInterestDegreeV3Service` → `SupporterSignatureInterestDegreeComponent` → `SupporterSignatureNotificationClient` / `PushGateway`

| Method | Path | 입력 | 동작 |
|---|---|---|---|
| POST | `/notification/range/1` | `List<InterestDegreeUserV3>` (min=1, max=500) | 구간 1 메시지 발송 |
| POST | `/notification/range/2` | 동일 | 구간 2 메시지 발송 |

**요청 DTO** (`SupporterSignatureInterestDegreeV3Dto.java`):
```java
class InterestDegreeUserV3 { Integer userId; Integer interestDegreeCount; List<Integer> signatureIds; }
```
제약: `@Size(min=1, max=500, message = "요청 건수는 1~500건 가능합니다.")`.

**흐름** (`SupporterSignatureInterestDegreeComponent.java:25-69`):
1. 대상 userIds 의 닉네임을 `UserAccountInfosMapper.selectNickNameByUserIds` 로 일괄 조회 (Map<UserId, NickName>).
2. `signatureIds.size() > 1` → Multi 템플릿, 1 이면 Single 템플릿으로 분기 (`templateInterestDegreeUserInfosSingle` / `Multi`).
3. `SupporterSignatureNotificationClient.sendRangeN*InterestDegreeMessage{Single,Multi}` 호출.
4. 닉네임 맵에 없는 사용자(탈퇴/휴면 등)는 `missedUserIds` 로 누락 경고 로그.
5. NotificationClient 내부: `UserLocaleMapper.findUserLocaleByUserIds` 로 언어별 그룹핑 → `PushGateway.sendInboxMessage(..., isAd=true, senderType=SYSTEM, serviceCode=FUNDING)` 일괄 전송.

**응답**: HTTP 204 No Content (`@ResponseStatus(HttpStatus.NO_CONTENT)`), body 없음.

**외부 의존성 경계**: `PushGateway` (→ 외부 푸시/인박스 시스템, 본 repo 에서 내부 전송 프로토콜 확인 불가), `UserLocaleMapper`,
`UserAccountInfosMapper` (user 계정 정보 조회 SQL — 본 signature 도메인 외부).

---

### 3.5 `SupporterSignaturePointV3Controller`
파일: `.../v3/SupporterSignaturePointV3Controller.java`
Service: `SupporterSignaturePointV3Service`

| Method | Path | 입력 | 서비스 호출 | SQL / 외부 |
|---|---|---|---|---|
| GET | `/total-info` | isAllCount(def:false), fromDay?, toDay? | `getTotalPointInfo(isAllCount, fromDay, toDay, usingCache)` | `sumValidTotalPointStat` (+ EhCache/Redis 조건부) |
| GET | `/affiliates/versions` | refreshCache | `getAffiliatePointVersions(...)` | In-memory enum (`SupporterSignatureAffiliatePointVersion`) + `AffiliateCommandComponent.getCachedPointInfos` |
| GET | `/affiliates/{trackingId}/issue-key` | trackingId | `getAffiliateIssuedKey(trackingId)` | `AffiliateCommandComponent.getPointIssueKey` — **core 내부 (포인트 발급 서버 연동 키)** |
| POST | `/affiliates/notification` | `AffiliatePointNotificationRequestV3{targetUserIds(min=1)}` | `sendAffiliateNotification(request)` → `affiliateCommandComponent.sendPointNotification(...)` | Push (외부) |

**날짜 기본값 로직** (`SupporterSignaturePointV3Controller.java:45-58`):
- `isAllCount=true` → fromDay/toDay 무시, 전체 합계.
- `isAllCount=false` 기본:
  - `fromDay = SupporterSignatureAffiliateUtil.getDefaultFromDay()` (1년 전)
  - `toDay = SupporterSignatureAffiliateUtil.getDefaultToDay()` (오늘 00:00 직전 = 전일)
- `toDay` 가 오늘 이후면 `usingCache = false` (실시간 계산 강제).

**SQL — total-info** (`supporterSignaturePoint-mapper.xml:146-156`):
```sql
SELECT SP.ReferenceType,
       COUNT(distinct SP.UserId) as UserCount,
       SUM(SP.Amount) as Amount
FROM wadiz_db.SupporterSignaturePoint SP
  INNER JOIN Signature S ON S.SignatureId = SP.SignatureId AND S.IsDeleted is FALSE
<if test="!isAllCount">
WHERE SP.Created BETWEEN #{fromDay} AND #{toDay}
</if>
GROUP BY SP.ReferenceType;
```
→ Response `SignatureTotalPointInfoV3` 는 ReferenceType 별로 socialPoints/rewardPoints, socialUserCount/rewardUserCount 에 분배.

**`/affiliates/versions` 응답** — in-memory Enum 변환:
- `SupporterSignatureAffiliatePointVersion.v1` → version=1, targetDays=1, templates=[share(SIGNATURE_SHARE_PURCHASE, 1f)]
- `SupporterSignatureAffiliatePointVersion.v2` (현재 버전) → version=2, targetDays=1, templates=[share(SIGNATURE_SHARE_PURCHASE_OUT, 5f), feed(SIGNATURE_SHARE_PURCHASE_IN, 1f)]

**`/affiliates/notification`** — `targetUserIds(List<Integer>)` 에 대해 `NotificationClient.sendAffiliatePoint` 실행
(`SupporterSignatureNotificationClient.java:66-109`): UserLocale 기반 언어별 `PushGateway.processBatches` 로 Inbox push.

---

### 3.6 `SupporterSignaturePointV3UserController`
파일: `.../v3/SupporterSignaturePointV3UserController.java`
Service: `SupporterSignaturePointV3UserService`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| GET | `/points` | userId, isAllCount, fromDay?, hasShareInfo(def:true), hasPointInfo(def:true), cursorId?, size(def:5), sortType | `pointDetails(...)` | `findPointStatDetailByUserId` |
| GET | `/points/count` | userId, isAllCount, fromDay? | `count(...)` | `findCountByUserId` |
| GET | `/points/total` | userId, isAllCount, fromDay? | `userShareInfo(...)` | `sumMyValidPointShareAmount` + `countShareByUserId` |
| GET | `/{signatureId}/points/detail` | userId, signatureId | `sharePointDetail(signatureId)` — **본인 소유자 체크 (컨트롤러)** | `findPointStatDetailBySignatureId` |
| POST | `/{signatureId}/points/affiliates/{trackingId}` | userId, signatureId, trackingId, `AffiliatePointRequestV3{campaignId, pointAmount}` | `issueAffiliatePoint(...)` → `affiliateCommandComponent.issuePoint(trackingId, userId, signatureId, campaignId, pointAmount)` | `insertSupporterSignaturePoint` (+ core 검증 체인) |

**본인 체크 로직** (`SupporterSignaturePointV3UserController.java:113-121`):
```java
final SignatureShareInfoV3 result = pointV3UserService.sharePointDetail(signatureId);
if (result == null) throw new UserNotFoundApiException();
if (!result.getUserId().equals(userId)) throw new UserForbiddenApiException();
return ResponseEntity.ok().body(result);
```

**SQL — 내 포인트 상세 (`findPointStatDetailByUserId`)** (`supporterSignaturePoint-mapper.xml:200-266`, 발췌):
- 서명 단위 cursor 페이지네이션 (`A.SignatureId < cursorId` / `> cursorId`).
- `GROUP_CONCAT` 으로 `StrKeywordIds`, `StrPaymentResults` 컬럼 조립 → 서비스에서 domain 파싱.
- `LEFT OUTER JOIN SupporterSignaturePoint` + `GROUP BY SignatureId, ReferenceType` 로 Point 합계·개수 산출.

**SQL — 공유 개수** (`supporterSignatureShare-mapper.xml:11-21`):
```sql
SELECT COUNT(SSS.ShareId)
FROM wadiz_db.SupporterSignatureShare SSS
  INNER JOIN wadiz_db.Signature S ON S.UserId = #{userId}
     AND S.SignatureId = SSS.SignatureId
     AND S.IsDeleted is FALSE
     <if test="!isAllCount">
     AND S.WhenCreated BETWEEN #{fromDay} AND NOW()
     </if>
WHERE 1=1;
```

**SQL — 포인트 insert (포인트 지급)** (`supporterSignaturePoint-mapper.xml:33-39`):
```sql
INSERT INTO wadiz_db.SupporterSignaturePoint (UserId, SignatureId, ReferenceId, ReferenceType, Amount)
VALUES (#{userId}, #{signatureId}, #{referenceId}, #{referenceType}, #{amount})
```

---

### 3.7 `SupporterSignatureCommunicationV3Controller`
파일: `.../v3/SupporterSignatureCommunicationV3Controller.java`
Service: `SupporterSignatureCommunicationV3Service` → `SupporterSignatureCommunicationCommandComponent`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| GET | `/{signatureId}/comments` | signatureId, loginUserId?, hasUserProfile(def:false), hasPaymentInfo(def:true), usingCursor, cursorId, size(max=100, def=30), sortType | `getCommentList(...)` | `findCommentDetailAll` |

**검증**: `@Max(value = 100, message = "허용 조회 사이즈를 초과했습니다.(최대 100건)")`.

**SQL** (`supporterSignature-mapper.xml:563-627`, 발췌): Cursor 기반 댓글 조회, `hasUserProfile=true` 이면 UserProfile/Photo/Membership/Follow/UserBlocking/FollowerCount 서브쿼리 포함. ReactionStat (StatType=2) + CommentReaction (로그인 유저 기준 IsChecked) 좌외부 조인.

---

### 3.8 `SupporterSignatureCommunicationV3UserController`
파일: `.../v3/SupporterSignatureCommunicationV3UserController.java`
Service: `SupporterSignatureCommunicationV3UserService`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| POST | `/{signatureId}/comments` | CommentRequestV3{content(<=2000)} | `createComment(userId, signatureId, content)` | `insertComment` |
| PUT | `/comments/{commentId}` | CommentRequestV3 | `updateComment(userId, commentId, content)` | `findComment` + owner 체크 + `updateComment` |
| DELETE | `/comments/{commentId}` | — | `deleteComment(userId, commentId)` → HTTP 204 | `deleteComment` (soft delete) |
| PUT | `/{signatureId}/reactions/{reactionTypeId}` | ReactionRequestV3{isChecked} | `upsertSignatureReaction(...)` | `upsertReaction` + `upsertReactionStat` |
| PUT | `/comments/{commentId}/reactions/{reactionTypeId}` | 동일 | `upsertCommentReaction(...)` | `upsertCommentReaction` + `upsertCommentReactionStat` |

**SQL — 댓글 작성** (`supporterSignature-mapper.xml:480-491`):
```sql
INSERT INTO SupporterSignatureComment (UserId, SignatureId, Content, IsMaker)
VALUES (#{userId}, #{signatureId}, #{content}, #{isMaker})
```
> `isMaker` 값 주입은 `SupporterSignatureCommunicationCommandComponent` 내부에서 campaign의 makerUserId 비교로 결정됨 (core 내부).

**SQL — 댓글 삭제 (soft delete)** (`supporterSignature-mapper.xml:507-511`):
```sql
UPDATE SupporterSignatureComment
SET IsDeleted = true, Status = #{statusType}
WHERE CommentId = #{commentId}
```

**SQL — 리액션 upsert** (`supporterSignature-mapper.xml:630-638`):
```sql
INSERT INTO SupporterSignatureReaction(TypeId, UserId, SignatureId, IsChecked)
VALUES (#{typeId}, #{userId}, #{signatureId}, #{isChecked})
ON DUPLICATE KEY UPDATE IsChecked = #{isChecked}
```

**SQL — 리액션 통계 동기화 (upsertReactionStat, 672-685)**:
```sql
INSERT INTO SupporterSignatureReactionStat(StatReferenceId, StatType, ReactionTypeId, ReactionCount)
VALUES (#{statReferenceId}, #{statType}, #{reactionTypeId},
        (SELECT COUNT(IsChecked) FROM SupporterSignatureReaction
         WHERE IsChecked is true AND SignatureId = #{statReferenceId} AND TypeId = #{reactionTypeId}))
ON DUPLICATE KEY UPDATE ReactionCount = (SELECT COUNT(IsChecked) ...);
```
> StatType: 1 = 지지서명 리액션, 2 = 지지서명 댓글 리액션.

**특이**: 댓글 작성 시 Push Notification 도 `SupporterSignatureNotificationClient.sendComment(...)` 로 발송
(`SupporterSignatureNotificationClient.java:111-143`, core 내부에서 호출). 대상은 서명 작성자, 발신자 타입은 `RWD_MAKER` 또는 `USER`.

---

### 3.9 `SupporterSignatureAffiliateV3Controller`
파일: `.../v3/SupporterSignatureAffiliateV3Controller.java`
Service: `SupporterSignatureAffiliateV3Service` → `SupporterSignatureAffiliateCommandComponent`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| PUT | `/affiliates/results` | `UpdateResultRequestV3{trackingIds(min=1), resultCode(AffiliatePointResultCode)}` | `updateResult(trackingIds, resultCode)` | `updateResult` |
| PUT | `/affiliates/canceled-signatures/results` | `UpdateCanceledSignatureResultRequestV3{targetDays(min=0)}` | `updateCanceledSignatureResult(AffiliateTargetDay)` | `updateResultForCanceledSignature` |
| GET | `/affiliates/targets/count` | targetDays(min=0) | `getTargetCount(AffiliateTargetDay)` | `countPointTarget` |

**`AffiliatePointResultCode` enum** (전수):
`POINT_PAID, ZERO_POINT, NOT_VALID_SIGNATURE_ID, IS_SIGNATURE_OWNER, NOT_MISMATCH_CAMPAIGN_ID, NOT_VALID_PAYMENT_ID,
NOT_EXIST_PAYMENT_ID, CANCELED_SIGNATURE, CANCELED_PAYMENT`.
정상 지급으로 간주되는 코드: `POINT_PAID, ZERO_POINT`.

**SQL — updateResult** (`supporterSignatureTracking-mapper.xml:27-35`):
```sql
UPDATE SupporterSignatureTracking
SET Result = #{result}
WHERE TrackingId IN (
<foreach collection="trackingIds" item="item" separator=",">
    #{item}
</foreach>
)
```

**SQL — updateResultForCanceledSignature** (`supporterSignatureTracking-mapper.xml:38-46`):
```sql
UPDATE SupporterSignatureTracking SST
  INNER JOIN Signature S ON S.SignatureId = SST.SignatureId AND S.IsDeleted is TRUE
  SET Result = #{result}
WHERE Result is NULL
  AND PaymentDay < #{targetDay}
```

**SQL — countPointTarget** (`supporterSignatureTracking-mapper.xml:49-57`):
```sql
SELECT COUNT(SST.TrackingId)
FROM SupporterSignatureTracking SST
     INNER JOIN Signature S ON S.SignatureId = SST.SignatureId AND S.IsDeleted is FALSE
WHERE SST.Result is NULL
  AND SST.PaymentDay < #{targetDay}
```

---

### 3.10 `SupporterSignatureAffiliateV3UserController`
파일: `.../v3/SupporterSignatureAffiliateV3UserController.java`
Service: `SupporterSignatureAffiliateV3UserService`

| Method | Path | 입력 | 서비스 호출 | SQL |
|---|---|---|---|---|
| POST | `/{signatureId}/affiliates` | userId, signatureId, `CreateAffiliateRequestV3{campaignId, paymentId, paymentDay, affiliateType?}` | `create(...)` → `affiliateCommandComponent.create(campaignId, entity)` | `insertData` (SupporterSignatureTracking) |

**SQL** (`supporterSignatureTracking-mapper.xml:11-24`):
```sql
INSERT INTO SupporterSignatureTracking (UserId, SignatureId, PaymentId, PaymentDay, AffiliateType, Result)
VALUES (#{userId}, #{signatureId}, #{paymentId}, #{paymentDay}, #{affiliateType}, #{result})
-- selectKey: SELECT LAST_INSERT_ID()
```

**AffiliateType enum** (`AffiliateType.java:10-26`): `share`, `feed` (소문자, FE url 파싱 값과 동일). 현재 V3 create 에서는
미지정 허용(Nullable).

---

## 4. DB 스키마 (관측)

### 주 테이블 (schema: `wadiz_db`)
| 테이블 | 주요 컬럼 (관측) | 역할 |
|---|---|---|
| `Signature` | SignatureId, UserId, CampaignId, Provider, WhenCreated, Updated, Content, TrackingPointInfoVersion, IsDeleted, StatusType | 지지서명 본문 |
| `SupporterSignatureKeyword` | KeywordId, KeywordName, KeywordType, Message, KeywordOrder, InUse | 키워드 사전 |
| `SupporterSignatureKeywordData` | SignatureId, KeywordId | 서명-키워드 N:M |
| `SupporterSignatureComment` | CommentId, UserId, SignatureId, IsMaker, Content, Created, Updated, IsDeleted, Status | 댓글 |
| `SupporterSignatureReaction` | TypeId, UserId, SignatureId, IsChecked | 서명 리액션 (PK: {TypeId, UserId, SignatureId}) |
| `SupporterSignatureCommentReaction` | TypeId, UserId, CommentId, IsChecked | 댓글 리액션 |
| `SupporterSignatureReactionStat` | StatReferenceId, StatType(1=sig,2=comment), ReactionTypeId, ReactionCount | 리액션 집계 (비정규화) |
| `SupporterSignatureTracking` | TrackingId, UserId, SignatureId, PaymentId, PaymentDay, AffiliateType, Result, Created | 어필리에이트 추적(결제 발생 시) |
| `SupporterSignaturePoint` | PointId, UserId, SignatureId, ReferenceId, ReferenceType, Amount, Created | 포인트 지급 원장 |
| `SupporterSignatureShare` | ShareId, SignatureId, ShareStatus, Provider, Reason | 공유 이력 |

### 조인 대상 외부 schema
| Schema.Table | 용도 (관측 쿼리 기준) |
|---|---|
| `UserProfile` (기본 schema) | 닉네임/상태/PhotoId |
| `PhotoCommon` | PhotoUrl |
| `wadiz_membership.member` | 멤버십 end/state |
| `wadiz_wave_follow.Follow` | 로그인 사용자→서명자 팔로우 여부, 팔로워 수 서브쿼리 |
| `wadiz_wave_follow.UserBlocking` | 로그인 사용자→서명자 차단 여부 |

### resultMap 계층 (`supporterSignature-mapper.xml:5-52`)
- `SupporterSignatureUserEntity` (userProfile 매핑)
- `SupporterSignatureDetailEntity` (서명 + userProfile + keywordIds collection + reactions collection)
- `SupporterSignatureReactionStatDataEntity` (typeId/count/isChecked)
- `SupporterSignatureCommentDetailEntity` (댓글 + userProfile + reactions)

### Point / Share resultMap (`supporterSignaturePoint-mapper.xml:5-30`)
- `SupporterSignaturePointShareStatEntity` (referenceType/count/amount)
- `SupporterSignaturePointStatEntity` (signatureId + shareStats collection)
- `SupporterSignaturePointStatDetailEntity` (상세 + `StrKeywordIds`/`StrPaymentResults` GROUP_CONCAT 문자열 + shareStats)

---

## 5. 외부 의존성 & 메시지 전송

### Push / Inbox (유일한 외부 채널, 관측)
- `com.wadiz.wave.infrastructure.push.PushGateway` — 본 repo 밖(공통 infrastructure) 의 push 게이트웨이. 내부 프로토콜(HTTP/Kafka)은 본 문서 범위 밖.
- `SupporterSignatureNotificationClient` (`component/infrastructure`) 가 래퍼:
  - `sendShare(userId, campaignName)` — V3에서 직접 호출 지점은 관측되지 않음(V1 shareController 잔존).
  - `sendAffiliatePoint(List<Long>)` — **5-4 (`/affiliates/notification`)** 에서 사용.
  - `sendComment(...)` — **8-1 댓글 작성** 시 core 내부에서 호출.
  - `sendRange{1,2}InterestDegreeMessage{Single,Multi}` — **4-1, 4-2** 에서 사용.
- Push 인자: `ServiceCode.FUNDING`, `SenderType.SYSTEM|USER|RWD_MAKER`, `isAd=true(관심도)/false(댓글/공유)`.

### RabbitMQ / Kafka (관측 결과)
- V3 signature 코드 경로에서 **Kafka/RabbitMQ 직접 publish 코드는 관측되지 않음**
  (grep `kafkaTemplate|rabbitTemplate|@KafkaListener|@RabbitListener|eventPublisher` → signature 경로 hit 0건).
- `co.wadiz.api.community` 는 `community.signature.exchange` DirectExchange 를 미리 선언해 두었으나, 현재 wave.user 가 거기로
  publish 하는 연동은 확인 불가(없음).

### 외부 서비스 호출
- 캠페인/결제(payment) 정보는 **DB 조인/쿼리로만** 참조 (Signature.CampaignId, SupporterSignatureTracking.PaymentId).
- HTTP client 로 `funding-core`/`campaign-api` 등 타 서비스 콜은 signature v3 경로에서 관측되지 않음.

### 캐시 (component 경계)
- `SupporterSignatureCountCacheClient`, `SupporterSignatureKeywordCacheClient`, `SupporterSignaturePointCacheClient`, `SupporterSignatureUserImageCacheClient`
  — 컴포넌트 내부 용도로 존재. V3 컨트롤러에서 `refreshCaching` / `usingCache` / `refreshCache` 쿼리 파라미터로 캐시 우회/재생성을 제어.

---

## 6. 경계 및 미탐색 영역

- **권한/인증 체크 위치**: V3 컨트롤러 전반에 Spring Security `@PreAuthorize` 미관측. `{userId}` 경로 기반 신뢰 전제 + 서비스 레이어
  owner 체크(서명 수정·공유 상세)만 관측됨. 실제 인증은 상단 API Gateway 에서 이뤄지는 것으로 추정되나 본 repo 에서는 확인 불가.
- **Component 내부 SQL**: `SupporterSignatureCommandComponent.create(userId, campaignId, content, keywordIds)`,
  `deleteBySignatureId`, `update(entity, content, keywordIds)` 등의 **여러 매퍼 호출 조합·트랜잭션 경계**는 component 구현체(본 문서 범위 외)에
  있음. 본 문서는 매퍼 XML에 실제 존재하는 SQL만 인용.
- **isMaker 판별 로직**: 댓글 생성 시 `IsMaker=true` 저장 기준(캠페인 makerUserId 비교 등)이 `SupporterSignatureCommunicationCommandComponent`
  에 있을 것으로 보이나, 본 문서에서는 컨트롤러/서비스 경계까지만 기록.
- **`AffiliateCommandComponent.issuePoint / getPointIssueKey`**: 포인트 지급 엔진 연동(외부 포인트 서버 호출 여부, 사기 검증 등) 은
  core 내부로 간주하고 미탐색.
- **Community 이관 매핑**: V3 각 엔드포인트 → community 서비스의 신규 경로 매핑 표가 필요하나, 대상(community) 서비스가 Phase 0~1
  스캐폴드 단계라 아직 작성 불가.
- **11번째 컨트롤러**: 태스크 지시문은 11개를 언급했으나 `v3/*.java` 디렉터리에는 10개. 누락 가능성을 재확인하려면 운영 배포 jar 의
  실제 컨트롤러 bean 목록(actuator `/mappings`) 대조가 필요(환경 밖).

---

## 7. 참조 인덱스

- 컨트롤러: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/supporter/signature/v3/*.java`
- DTO: `.../v3/dto/*.java`
- 서비스: `.../v3/service/*.java`
- 공통 Component (경계): `.../signature/component/*.java`
- 외부 notification: `.../signature/component/infrastructure/SupporterSignatureNotificationClient.java`
- MyBatis XML: `com.wadiz.wave.user/src/main/resources/mapper/wadiz/supporter/signature/*.xml`
- V3 enum/상수: `.../signature/constant/{AffiliatePointResultCode, AffiliateType, SupporterSignatureAffiliatePointVersion, SupporterSignatureDeleteType}.java`
- 페이지네이션 enum: `com.wadiz.wave.repository.wadiz.constant.SupporterSignatureConst.{SearchSortType, SignatureStatusType}` (외부 repository 모듈)
