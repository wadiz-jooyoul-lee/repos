# Supporter Signature V1 — `com.wadiz.wave.user`

> 레거시 Wave User 모놀리식 API 중, **지지서명(Supporter Signature) V1** 패키지의 6개 Controller + 연관 Service/Mapper 심층 분석.
> 대상 패키지: `com.wadiz.wave.user.supporter.signature.v1`, `com.wadiz.wave.user.supporter.signature.v1.share`
> 대상 MyBatis 매퍼 디렉터리: `src/main/resources/mapper/wadiz/supporter/signature/`

---

## 1. 기록 범위

### 읽은 파일 (In-scope)

Controller (6):
- `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/supporter/signature/v1/SupporterSignatureOldController.java` (275 lines)
- `…/v1/SupporterSignatureTrackingController.java` (132 lines)
- `…/v1/SupporterSignaturePointController.java` (167 lines)
- `…/v1/SupporterSignatureInterestDegreeController.java` (95 lines)
- `…/v1/SupporterSignatureCommunicationController.java` (153 lines)
- `…/v1/share/SupporterSignatureShareController.java` (98 lines)

Service layer (직접 호출되는 6개 + 공유 1):
- `…/v1/service/SupporterOldSignatureService.java`
- `…/v1/service/SupporterSignatureTrackingService.java`
- `…/v1/service/SupporterSignaturePointService.java`
- `…/v1/service/SupporterSignatureInterestDegreeService.java`
- `…/v1/service/SupporterSignatureCommunicationService.java`
- `…/v1/service/SupporterSignatureKeywordService.java`
- `…/v1/share/service/SupporterSignatureShareService.java`

DTO/VO:
- `…/v1/dto/SupportSignatureTrackingDto.java`
- `…/v1/dto/SupporterSignatureCommentDto.java`
- `…/v1/dto/SupporterSignatureDto.java`
- `…/v1/dto/SupporterSignatureInterestDegreeDto.java`
- `…/v1/dto/SupporterSignatureKeywordDto.java`
- `…/v1/dto/SupporterSignaturePointDto.java`
- `…/v1/dto/SupporterSignatureReactionDto.java`
- `…/v1/share/dto/ShareAdditionalInfoDto.java`
- `…/v1/share/vo/ShareInfo.java`, `ShareIssuePointsInfo.java`
- `…/v1/constant/SupporterSignatureErrorCode.java`

MyBatis Mapper XML (6):
- `src/main/resources/mapper/wadiz/supporter/signature/supporterSignature-mapper.xml` (703 lines)
- `…/supporterSignatureKeyword-mapper.xml`
- `…/supporterSignatureKeywordData-mapper.xml`
- `…/supporterSignaturePoint-mapper.xml`
- `…/supporterSignatureShare-mapper.xml`
- `…/supporterSignatureTracking-mapper.xml`

### 경계 밖 (Out-of-scope, 외부 호출로만 표기)

- Service가 의존하는 `SupporterSignature*Component` (CommandComponent / QueryComponent)류 내부 로직. 매퍼 호출 매칭은 XML id 수준까지만 맞추고 컴포넌트 코드는 읽지 않음.
- `com.wadiz.wave.infrastructure.push.*` (PushGateway) — 푸시 알림 발송. "외부 호출" 경계.
- `com.wadiz.wave.infrastructure.points.*` (Point 지급) — 포인트 적립. "외부 호출" 경계.
- `com.wadiz.wave.infrastructure.campaign.*` — 캠페인 상세 조회. "외부 호출" 경계.
- V3 컨트롤러 (`…/v1/../v3/*V3Controller.java`) 본문 — v1 주석에 적힌 "신규 API" 매핑 문자열만 그대로 인용.
- Cache(Spring Cache/Redis) 설정 — 메서드 시그니처에 `refreshCaching`/`usingCache` 플래그는 있으나 실제 캐시 계층은 분석 안 함.

---

## 2. 개요

### 책임

**Supporter Signature (지지서명) V1**은 와디즈 크라우드펀딩 프로젝트의 서포터(후원자)가 남기는 "지지 서명"을 CRUD하고, 그에 딸린 키워드·댓글·리액션·공유·트래킹(affiliate)·포인트 지급·관심도 푸시를 모두 담당하는 레거시 API 집합이다. 하나의 "지지서명"은 `(UserId, CampaignId)` 조합에 대해 유일하며, 서포터가 프로젝트에 남기는 짧은 메시지 + 태그 키워드 묶음을 구성한다.

### V3와의 관계 (이관 상태)

모든 V1 엔드포인트(총 약 34개)는 클래스 메서드에 `@Deprecated`가 달려 있고, 각 메서드 위 주석에 **"→ 신규 API: `{V3 path}`"** 형식으로 대응되는 V3 URL이 명시되어 있다 (예: `SupporterSignatureOldController.java:58` — `"신규 API: PUT /api/v3/supporter-signatures/{signatureId}/hide"`).

- Jira 태스크 **IAM-3451** 배포 완료가 전제 조건 (주석에 반복: "TODO: IAM-3451 배포 후 삭제 검토").
- V3 컨트롤러는 `com.wadiz.wave.user.supporter.signature.v3.*V3Controller`로 존재 (별도 문서).
- 이 v1 계층은 여전히 **레거시 FE/Admin/Batch/BackOffice가 호출 중**이며, 일부는 삭제하지 못하는 추가 이슈가 명시됨 (예: `SupporterSignatureOldController.java:58` "IAM-3451 배포 후 추가작업 해야 삭제 가능!!!").
- Interest Degree와 Share 경로 중 일부는 "추가작업" 없이 "IAM-3451 배포 후 삭제 가능"으로 표기됨 (예: `SupporterSignatureShareController.java:33, 46`).

### 공통 base path

모든 컨트롤러가 `"/api/v1/users/supporter-signatures"` 프리픽스 하위에 존재한다.

| Controller | class-level `@RequestMapping` |
|---|---|
| SupporterSignatureOldController | `/api/v1/users/supporter-signatures` |
| SupporterSignatureTrackingController | `/api/v1/users/supporter-signatures/event/tracking` |
| SupporterSignaturePointController | `/api/v1/users/supporter-signatures/points` |
| SupporterSignatureInterestDegreeController | `/api/v1/users/supporter-signatures/interest-degree` |
| SupporterSignatureCommunicationController | `/api/v1/users/supporter-signatures` |
| SupporterSignatureShareController | `/api/v1/users/supporter-signatures/share` |

### 공통 예외 핸들러 패턴

6개 컨트롤러 모두 자체 `@ExceptionHandler`를 보유:
- `SupporterSignatureException` → HTTP 403 + `SignatureErrorVo{code, message}` (에러코드 enum: `SupporterSignatureErrorCode`)
- `Exception` (fallthrough) → HTTP 500
- Old/Point: `NotFoundException` (javassist) → HTTP 404
- Interest-Degree / Communication: `ConstraintViolationException` → HTTP 400 + 메시지 조립
- Share: 추가로 `CampaignDetailInfoSearchException`, `IssuePointsException`, `SupporterSignatureShareException` 개별 403 핸들러 (ShareErrorVo 사용)

---

## 3. 엔드포인트 전수 테이블

### SupporterSignatureOldController (base: `/api/v1/users/supporter-signatures`)

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| POST   | `/supporter/{userId}/signatures` | `postSupportSignature` | 지지서명 생성 |
| PUT    | `/supporter/{userId}/signatures` | `putSupportSignature` | 지지서명 생성 or 업데이트 (upsert) |
| PUT    | `/signatures/{signatureId}/hiding` | `hideSignature` | 지지서명 숨김(BLIND) 처리 |
| DELETE | `/signatures` | `deleteSignature` | 지지서명 삭제 (by signatureId or campaignId) |
| GET    | `/supporter/{userId}/signed-id` | `signed` | 유저가 서명한 `SignatureId` 조회 |
| GET    | `/supporter/{userId}/signatures/count` | `getCountByUserId` | 유저 기준 지지서명 수 |
| GET    | `/signatures/count` | `getCountByCampaignId` | 캠페인 기준 지지서명 수 (cache refresh 가능) |
| GET    | `/signatures/counts` | `getCountByCampaignIdList` | 캠페인 id 리스트별 수 |
| GET    | `/supporter/{userId}/is-signed` | `isSigned` | 해당 캠페인에 서명했는지 |
| GET    | `/signatures/{signatureId}` | `get` | 지지서명 단건 상세 조회 |
| GET    | `/supporter/{userId}` | `getByUserIdAndCampaignId` | 유저+캠페인 기준 단건 상세 |
| GET    | `/supporter/{userId}/signatures` | `getListByUserId` | 유저의 지지서명 리스트 (페이지/커서) |
| GET    | `/signatures` | `getListByCampaignId` | 캠페인의 지지서명 리스트 (페이지/커서) |
| GET    | `/signatures/keywords` | `getKeywordList` | 공통(COMMON) 키워드 리스트 |
| GET    | `/signatures/keywords/count` | `getKeywordCountList` | 캠페인 기준 키워드별 개수 |
| GET    | `/signatures/user-images` | `getUserImageInfoByCampaignId` | 캠페인의 서명자 User Image 리스트 |

### SupporterSignatureTrackingController (base: `/api/v1/users/supporter-signatures/event/tracking`)

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| POST   | `""` | `postTracking` | 지지서명 공유로 유입된 결제 tracking 생성 |
| PUT    | `/results` | `updateResult` | tracking 결과 코드 일괄 업데이트 |
| PUT    | `/canceled-signatures/results` | `updateResultForCanceledSignatures` | 삭제된 지지서명의 tracking 결과 일괄 처리 |
| GET    | `/point-targets/count` | `getPointTargetCount` | 포인트 적립 대상 tracking 수 |
| POST   | `/point` | `postTrackingPoint` | tracking 건 포인트 지급 |
| GET    | `/point/issue-key` | `checkTrackingPoint` | tracking 포인트 지급 발급키(issue key) 조회 |
| GET    | `/point/infos` | `getTrackingPointInfos` | 현재 적용 tracking point template 정보 |
| POST   | `/point/push` | `sendTrackingPointPush` | tracking 포인트 지급 push 알림 |

### SupporterSignaturePointController (base: `/api/v1/users/supporter-signatures/points`)

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| GET | `/supporter/{userId}/count` | `getCountByUserId` | 유저의 포인트 건수 (1년 default) |
| GET | `/supporter/{userId}` | `findPointStatDetailByUserId` | 유저 포인트 내역 리스트 (커서 기반) |
| GET | `/signatures/{signatureId}/total` | `getSignatureSharePointInfo` | 단건 지지서명의 공유/포인트 총계 |
| GET | `/supporter/{userId}/total` | `getUserSharePointInfo` | 유저 포인트 전체 총계 |
| GET | `""` | `getSignatureTotalPointInfo` | 전체 지지서명 포인트 전체 통계 (1년치) |

### SupporterSignatureInterestDegreeController (base: `/api/v1/users/supporter-signatures/interest-degree`)

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| POST | `/notification/range/1` | `sendNotification5gt` | 관심도 1구간(예: 5명 이상) 메시지 발송 |
| POST | `/notification/range/2` | `sendNotification50gt` | 관심도 2구간(예: 50명 이상) 메시지 발송 |

### SupporterSignatureCommunicationController (base: `/api/v1/users/supporter-signatures`)

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| POST   | `/supporter/{userId}/signatures/{signatureId}/comments` | `postComment` | 지지서명 댓글 생성 |
| PUT    | `/supporter/{userId}/signatures/{signatureId}/comments/{commentId}` | `putComment` | 댓글 수정 (null commentId면 생성) |
| GET    | `/signatures/{signatureId}/comments` | `getCommentList` | 댓글 리스트 |
| DELETE | `/comments/{commentId}` | `deleteComment` | 댓글 삭제 |
| PUT    | `/supporter/{userId}/signatures/{signatureId}/reactions/{reactionTypeId}` | `putReaction` | 지지서명 리액션 upsert |
| PUT    | `/supporter/{userId}/comments/{commentId}/reactions/{reactionTypeId}` | `putCommentReaction` | 댓글 리액션 upsert |

### SupporterSignatureShareController (base: `/api/v1/users/supporter-signatures/share`)

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| POST | `/supporter/{userId}/signatures/{signatureId}` | `share` | 공유 이벤트 저장 + 공유 포인트 지급 + 알림 |
| GET  | `/points/supporter/{userId}/signatures/{signatureId}` | `issuePoints` | 공유 포인트 "지급 가능 여부" 조회 (실제 지급 X) |

---

## 4. 컨트롤러별 상세

### 4.1 SupporterSignatureOldController

- 파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/supporter/signature/v1/SupporterSignatureOldController.java:31`
- base path: `/api/v1/users/supporter-signatures`
- DI: `SupporterOldSignatureService`, `SupporterSignatureKeywordService`
- Swagger tag: `지지서명 리소스`

#### 주요 DTO

`SupporterSignatureDto.SignatureRequest` (SupporterSignatureDto.java:241-256):
- `@NotNull @Min(1) Integer campaignId`
- `@NotNull @Size(max = 1000) String content`
- `@NotNull @Size(min = 1) List<Integer> keywordIds`

응답 `SignatureInfo` (SupporterSignatureDto.java:133-215) 필드: `signatureId, userId, campaignId, isOwner, userProfile(UserInfo), content, keywordIds, created, updated, publicSupportCount, privateSupportCount, commentCount, reactions`.

#### 메서드 → Service → Mapper(XML)

| Controller method | Service call | Mapper SQL (읽은 XML의 본문) |
|---|---|---|
| `postSupportSignature` (`:37`) | `SupporterOldSignatureService.create` → `signatureCommandComponent.create` | `supporterSignature-mapper.xml` `insertData` (see §5) + `supporterSignatureKeywordData-mapper.xml` `insertDatas` |
| `putSupportSignature` (`:48`) | `createOrUpdate` → existence 확인(`findByUserIdAndCampaignId`) 후 `update` 또는 `create` | `findByUserIdAndCampaignId` + `updateContent` + `supporterSignatureKeywordData-mapper.xml` `deleteBySignatureId`+`insertDatas` |
| `hideSignature` (`:60`) | `hideSignature` → `updateStatus(signatureId, BLIND)` | `updateStatusType` |
| `deleteSignature` (`:70`) | `deleteSignatureByMaker` or `deleteSignatureByAdmin` | `deleteSignatureBySignatureId` or `deleteSignatureByCampaignId` (둘 다 IsDeleted=true, StatusType=…) |
| `signed` (`:94`) | `signedId` → `signatureQueryComponent.signedId` | `findIdByUserIdAndCampaignId` |
| `getCountByUserId` (`:104`) | `findCountByUserId` | `findCountByUserId` (mapper 쿼리명 동일) |
| `getCountByCampaignId` (`:113`) | `findCountByCampaignId(refreshCaching, id)` | `findCountByCampaignId` |
| `getCountByCampaignIdList` (`:124`) | `findCountByCampaignIdList` | `findCountByCampaignIdList` (GROUP BY CampaignId) |
| `isSigned` (`:133`) | `isSigned` → Component 내부에서 `findCountByUserIdAndCampaignId` 활용(추정 경계) | `findCountByUserIdAndCampaignId` |
| `get` (`:143`) | `findDetail(signatureId, loginUserId, hasPaymentInfo)` | `findDetail` (giant LEFT JOIN: UserProfile, PhotoCommon, wadiz_membership.member, wadiz_wave_follow.Follow, wadiz_wave_follow.UserBlocking, SupporterSignatureKeywordData, SupporterSignatureReactionStat, SupporterSignatureReaction, SupporterSignatureComment count sub-query) |
| `getByUserIdAndCampaignId` (`:156`) | `findDetailByUserIdAndCampaignId` | `findDetailByUserIdAndCampaignId` |
| `getListByUserId` (`:170`) | `findDetailListByUserId` | `findDetailByUserId` (커서 + OFFSET, `hasUserProfile` 분기) |
| `getListByCampaignId` (`:187`) | `findDetailListByCampaignId` | `findDetailByCampaignId` |
| `getKeywordList` (`:205`) | `SupporterSignatureKeywordService.findList(refreshCaching, COMMON)` | `supporterSignatureKeyword-mapper.xml` `findListByKeywordType` |
| `getKeywordCountList` (`:215`) | `findCountListByCampaignId` | `supporterSignatureKeywordData-mapper.xml` `findCountByCampaignId` |
| `getUserImageInfoByCampaignId` (`:226`) | `findUserImageInfoByCampaignId` | `findUserImageInfoByCampaignId` |

#### 특이사항

- 전 메서드 `@Deprecated`. 각 v3 대응 API URL이 주석에 있음 (예: `hideSignature` → `PUT /api/v3/supporter-signatures/{signatureId}/hide`).
- `deleteSignature`는 `signatureId`, `campaignId` 중 정확히 **한 개만** 들어와야 함 (XOR 체크, `:77`).
- `get`, `getByUserIdAndCampaignId`는 `loginUserId`를 옵셔널로 받아 비로그인 조회 허용 (`:146`, `:160`).
- `hasPaymentInfo` 파라미터는 단건 조회에 한해 존재하나 "현재까지는 '참여' 여부 표시 케이스 없음" 주석 (`:147-148`).
- `getCountByCampaignId`의 `refreshCaching` 플래그는 캐시 무효화 힌트 (Service 내부에서 해석).

---

### 4.2 SupporterSignatureTrackingController

- 파일: `…/v1/SupporterSignatureTrackingController.java:27`
- base path: `/api/v1/users/supporter-signatures/event/tracking`
- DI: `SupporterSignatureTrackingService`
- Swagger tag: `지지서명 리소스 Tracking`

#### 입력 DTO 핵심 필드

`SupportSignatureTrackingDto.CreateRequest` (SupportSignatureTrackingDto.java:19-56):
- `@NotNull @Min(1) Integer userId, campaignId, signatureId, paymentId`
- `@NotNull LocalDate paymentDay`
- `@Nullable String affiliateType` — `AffiliateType.parse`로 매핑; **null일 때 하위호환 위해 기본 `SHARE`**이지만 컨트롤러에서 null이 이미 와 있으면 `NOT_EXIST_AFFILIATE_TYPE` 예외 (`:37`). `AffiliateType` enum: `share`, `feed`.

`UpdateResultRequest`: `List<Integer> trackingIds`, `AffiliatePointResultCode resultCode`.
`UpdateForCanceledSignatureRequest`: `Integer targetDays (Min 0)`.
`PointRequest`: `trackingId, userId, signatureId, campaignId, pointAmount`.
`PointPushRequest`: `List<Integer> targetUserIds`.
`TrackingPointInfoResponse`: `version, templateAlias, ratio, limitAmount, targetDays`.

#### 메서드 → Service → Mapper

| Controller method | Service call | Mapper/경계 |
|---|---|---|
| `postTracking` (`:33`) | `createTracking` → `affiliateCommandComponent.create(campaignId, entity)` | `supporterSignatureTracking-mapper.xml` `insertData` |
| `updateResult` (`:49`) | `updateResult` → `affiliateCommandComponent.updateResult` | `updateResult` (WHERE TrackingId IN (…)) |
| `updateResultForCanceledSignatures` (`:58`) | `updateResultForCanceledSignature` → `affiliateCommandComponent.updateCanceledSignatureResult` | `updateResultForCanceledSignature` (JOIN Signature ON IsDeleted=TRUE AND PaymentDay < targetDay) |
| `getPointTargetCount` (`:67`) | `countPointTarget` → `affiliateCommandComponent.countPointTarget` | `countPointTarget` |
| `postTrackingPoint` (`:76`) | `payTrackingPoint` → `affiliateCommandComponent.issuePoint(trackingId, userId, signatureId, campaignId, pointAmount)` | `insertSupporterSignaturePoint` + **외부 호출: 포인트 발급 (infrastructure.points)** |
| `checkTrackingPoint` (`:85`) | `getTrackingPointIssueKey` → `affiliateCommandComponent.getPointIssueKey(trackingId)` | 경계: 내부에서 `findSupporterSignaturePointByReference` 등 활용 (추정하지 않음) |
| `getTrackingPointInfos` (`:94`) | `getTrackingPointInfos` → `affiliateCommandComponent.getPointVersion(v1)` | **XML 없음** — 정적 설정/상수 기반 추정. `SupporterSignatureAffiliatePointVersion.v1` 상수 사용. |
| `sendTrackingPointPush` (`:103`) | `sendTrackingPointPush` → `affiliateCommandComponent.sendPointNotification(targetUserIds)` | **외부 호출: `PushGateway` (infrastructure.push)** |

#### 특이사항

- "affiliate"는 "지지서명을 공유해 유입된 결제"를 가리키는 도메인 용어. `AffiliateType.share` / `.feed`가 소문자인 건 "FE URL에서 파싱되는 데이터가 소문자"라는 주석 때문 (AffiliateType.java:11).
- `updateResultForCanceledSignatures`는 배치용 — 지지서명이 삭제된 케이스의 tracking을 `targetDay` 이전 건 일괄 처리.
- `payTrackingPoint`는 `ZERO_POINT`(0원) / `FAIL_PAY_POINT` 코드로 내부 `UserForbiddenApiException`을 `SupporterSignatureException`으로 래핑 (`SupporterSignatureTrackingService.java:82-86`).
- `getTrackingPointInfos` 자체가 `@Deprecated` (service 내부에서도): IAM-3451 이후 Batch가 신규 API로 전환 예정 (`SupporterSignatureTrackingService.java:96`).

---

### 4.3 SupporterSignaturePointController

- 파일: `…/v1/SupporterSignaturePointController.java:32`
- base path: `/api/v1/users/supporter-signatures/points`
- DI: `SupporterSignaturePointService`
- Swagger tag: `지지서명 리소스 포인트`

#### 쿼리 파라미터 패턴

공통 패턴 (Controller 내 반복):
- `isAllCount` (default `false`) — false면 기간 필터 적용.
- `fromDay` (default: 1년 전, `SupporterSignatureAffiliateUtil.getDefaultFromDay()`).
- `toDay`만 `getSignatureTotalPointInfo`에서 사용 (default: 하루 전 = 오늘 00:00까지, `SupporterSignaturePointController.java:122`).
- 단건 정보 조회 옵션: `hasShareInfo`, `hasPointInfo` (둘 다 default false).

#### 메서드 → Service → Mapper

| Controller method | Service call | Mapper XML |
|---|---|---|
| `getCountByUserId` (`:37`) | `findCountByUserId` → `pointQueryComponent.count` | `supporterSignature-mapper.xml` `findCountByUserId` (동일 쿼리 재사용, fromDay 필터) |
| `findPointStatDetailByUserId` (`:54`) | `findPointStatDetailByUserId` → `pointDetails` | `supporterSignaturePoint-mapper.xml` `findPointStatDetailByUserId` (중첩 서브쿼리 + `GROUP_CONCAT`, cursor + limit) |
| `getSignatureSharePointInfo` (`:84`) | `getSignatureSharePointInfo` → `sharePointDetail` | `findPointStatDetailBySignatureId` (single signature 버전) |
| `getUserSharePointInfo` (`:93`) | `getUserSharePointInfo` → `userShareInfo` | `sumMyValidPointShareAmount` + `countShareByUserId` (supporterSignatureShare-mapper) — Component에서 조합 (추정 X, XML 확인) |
| `getSignatureTotalPointInfo` (`:110`) | `getSignatureTotalPointInfo` → `totalPointInfo(…, usingCache)` | `sumValidTotalPointStat` (ReferenceType별 distinct UserCount + SUM Amount) |

#### 특이사항

- `usingCache` 판정 로직 (`:114-126`): `isAllCount`가 true면 캐시 미사용. `toDay`가 명시된 경우 `오늘 이전`인지 판정해 결정 — 실시간 필요 시 캐시 우회.
- `findPointStatDetailBySignatureId` SQL은 `<if test="hasShareInfo">`, `<if test="hasPointInfo">` 분기에 따라 SELECT column이 동적으로 추가된다.
- `sumMyValidPointAmountAll` (SQL 내부) 컬럼명 `S.SinatureId`, `SP.SinatureId`는 **타이포** (Sinature → Signature 누락)로 보인다. 레거시 버그 가능성. (`supporterSignaturePoint-mapper.xml:78`)

---

### 4.4 SupporterSignatureInterestDegreeController

- 파일: `…/v1/SupporterSignatureInterestDegreeController.java:28`
- base path: `/api/v1/users/supporter-signatures/interest-degree`
- DI: `SupporterSignatureInterestDegreeService`
- Swagger tag: `지지서명 리소스 관심도`

#### 입력 DTO

`SupporterSignatureInterestDegreeDto.InterestDegreeUserInfo`: `{ int userId, int interestDegreeCount, List<Integer> signatureIds }` (Dto.java:10-24).

요청 본문: `@RequestBody @Size(min=1, max=500) List<InterestDegreeUserInfo>` — 1~500건 제한 (`:35`).

#### 메서드 → Service → 외부 경계

| Controller method | Service call | 경계 |
|---|---|---|
| `sendNotification5gt` (`:33`) | `sendRange1InterestDegreeMessage` → `interestDegreeComponent.sendRange1Message(domainUsers)` | **외부 호출: `PushGateway` (infrastructure.push)** — `TemplateSignatureInterestDegreeUser` 템플릿 기반 |
| `sendNotification50gt` (`:44`) | `sendRange2InterestDegreeMessage` → `interestDegreeComponent.sendRange2Message(domainUsers)` | 동일 |

#### 특이사항

- DB SQL 없음. 이 컨트롤러는 **오로지 푸시 메시지 발송 전용**.
- "range 1"(5gt — 5 이상)과 "range 2"(50gt — 50 이상) 두 구간. 메시지 코드는 `SupporterSignatureMessageCode` enum에 `INTEREST_DEGREE_RANGE_1_{SINGLE,MULTI}_PUSH_*`, `RANGE_2_*` 로 정의됨.
- `@Validated` 클래스 레벨 + `ConstraintViolationException` 핸들러로 400 응답.
- Batch 또는 Job 서버에서 호출되는 형태로 보임 (한 요청에 최대 500건).

---

### 4.5 SupporterSignatureCommunicationController

- 파일: `…/v1/SupporterSignatureCommunicationController.java:32`
- base path: `/api/v1/users/supporter-signatures`
- DI: `SupporterSignatureCommunicationService`
- Swagger tag: `지지서명 리소스 댓글/리액션`

#### 입력 DTO

`SupporterSignatureCommentDto.CommentRequest`: `@NotNull @Size(max=2000) String content` (CommentDto.java:104-109).
`SupporterSignatureReactionDto.Request`: `@NotNull Boolean isChecked` (ReactionDto.java:90-97).

응답 `CommentInfo` 필드: `commentId, userId, signatureId, isOwner, isMaker, userProfile(UserInfo), content, created, updated, publicSupportCount, privateSupportCount, reactions`.
응답 `SignatureReaction`/`CommentReaction` 필드: `signatureId/commentId, userId, typeId, isChecked, reactions[]`.

#### 메서드 → Service → Mapper

| Controller method | Service call | Mapper XML |
|---|---|---|
| `postComment` (`:38`) | `createComment` → `communicationCommandComponent.createComment` | `supporterSignature-mapper.xml` `insertComment` + `findCommentDetail` |
| `putComment` (`:48`) | commentId null이면 `createComment`, 아니면 `updateComment` | `updateComment` + `findCommentDetail` |
| `getCommentList` (`:63`) | `getCommentList` | `findCommentDetailAll` (커서 기반, `hasUserProfile` 분기) |
| `deleteComment` (`:78`) | `deleteComment` — `UserForbiddenApiException` → `SupporterSignatureException(FAIL, "댓글의 소유자가 아닙니다.")` | `deleteComment` (soft delete: `IsDeleted=true`, Status 설정) |
| `putReaction` (`:91`) | `createOrUpdateReaction` → `upsertSignatureReaction` | `upsertReaction` (ON DUPLICATE KEY UPDATE) + `upsertReactionStat` + `findReactionDetailAll` |
| `putCommentReaction` (`:102`) | `createOrUpdateCommentReaction` → `upsertCommentReaction` | `upsertCommentReaction` + `upsertCommentReactionStat` + `findCommentReactionDetailAll` |

#### 특이사항

- `deleteComment`에 주석 (`:80-82`): "RequestBody com.wadiz.web spring 버전(3.2.x)으로 인해 사용하지 못 한다. (Spring 버전 3.2.x 대에서 DELETE method에 request body를 허용하지 않음.) 향후 Token이 생기면 token으로 대체" — 호출 쪽 레거시 Spring 3.2 호환이 제약.
- `getCommentList` size는 `@Max(100)` 강제 — "허용 조회 사이즈를 초과했습니다.(최대 100건)".
- `findCommentDetail` / `findCommentDetailAll`은 `UserProfile`, `PhotoCommon`, `wadiz_membership.member`, `wadiz_wave_follow.Follow`, `wadiz_wave_follow.UserBlocking` join을 `hasUserProfile` 플래그로 조건부 포함.
- `upsertReactionStat` / `upsertCommentReactionStat`은 리액션 통계를 집계 카운트로 재계산해 넣는 구조 (SELECT COUNT(IsChecked) 서브쿼리).

---

### 4.6 SupporterSignatureShareController

- 파일: `…/v1/share/SupporterSignatureShareController.java:24`
- base path: `/api/v1/users/supporter-signatures/share`
- DI: `SupporterSignatureShareService`
- Swagger tag: `지지서명 공유하기`

#### 입력 DTO

`ShareAdditionalInfoDto` (dto/ShareAdditionalInfoDto.java:16-24):
- `@NotNull String provider` — `facebook`, `kakao` (enum `ShareProvider`에서 `twitter`는 false로 Deprecate).
- `@Null String chatType` — `ShareChatType`(`MemoChat`, `DirectChat`, `MultiChat`, `NothingType`)로 매핑. `@Null` 어노테이션이 달려 있으나 `ShareInfo.share()`에서 실제로 읽어 `findChatType(chatType)`으로 사용 (레거시 불일치 가능).

#### 메서드 → Service → Mapper/경계

| Controller method | Service call | 경계 |
|---|---|---|
| `share` (`:34`) | `shareService.share(ShareInfo.share(userId, signatureId, additionalInfo))` | 1) `signatureQueryComponent.getCampaignId(signatureId)` → `supporterSignature-mapper.xml`의 `find` 또는 유사 (XML 명확 매핑 불명, 경계). 2) `shareCommandComponent.validateShare(...)` → duplicate/over-limit 체크. 3) `shareCommandComponent.saveShareInfo(...)` → `supporterSignatureShare-mapper.xml` `insert`. 4) `pointCommandComponent.issueSharePoint(...)` → `insertSupporterSignaturePoint` + **외부 포인트 발급 호출**. 5) `shareCommandComponent.sendShareNotification(userId, campaignTitle)` → **외부 호출: `PushGateway`**. 6) `getCampaignKRTitle(campaignId)` → **외부 호출: `infrastructure.campaign`**. |
| `issuePoints` (`:49`) | `shareService.issuePoints(ShareInfo.point(userId, signatureId))` | `isDuplicateIssuePointsBySignatureId` + `isOverLimitIssuePointsByRegistered` → `supporterSignaturePoint-mapper.xml`의 `countPurePointBySignatureIdAndReferenceType` / `countTodayPointByUserIdAndReferenceType`. "포인트 지급 가능 여부"만 반환, 실제 지급 X. |

#### 특이사항

- `ShareProvider.isEnable(provider)` 검증 실패 시 `SupporterSignatureShareException(PointErrorCode.FAIL, "Unsupported Provider")` 발생 (`:39`).
- `share` 메서드 service 주석 (`SupporterSignatureShareService.java:39`): "공유 정보 저장 및 포인트 지급 (From.PO: 공유 포인트 지급은 다시 복구할 가능성이 있음.)" — 즉, 현재 정책에 따라 포인트 지급이 일시 비활성 가능.
- `issuePoints`는 이름과 달리 **실제 지급이 아니라 "지급 가능 여부 판정"**. 응답 `ShareIssuePointsInfo{ boolean issuePoints }`. service 주석 (`:78`): "실제 내용은 '포인트 지급 됐어'가 아님, '포인트 지급 가능 여부'에 가까움."

---

## 5. DB 스키마

### MyBatis ResultMap → Entity 매핑

| resultMap id | Type | 원본 XML |
|---|---|---|
| `SupporterSignatureUserEntity` | `com.wadiz.wave.repository.wadiz.entity.SupporterSignatureUserEntity` | supporterSignature-mapper.xml:5 |
| `SupporterSignatureDetailEntity` | `…SupporterSignatureDetailEntity` (userProfile, keywordIds, reactions nested collections) | supporterSignature-mapper.xml:17 |
| `SupporterSignatureReactionStatDataEntity` | `…SupporterSignatureReactionStatDataEntity` | supporterSignature-mapper.xml:35 |
| `SupporterSignatureCommentDetailEntity` | `…SupporterSignatureCommentDetailEntity` (userProfile, reactions) | supporterSignature-mapper.xml:41 |
| `SupporterSignaturePointShareStatEntity` | `…SupporterSignaturePointShareStatEntity` | supporterSignaturePoint-mapper.xml:5 |
| `SupporterSignaturePointStatEntity` | `…SupporterSignaturePointStatEntity` | supporterSignaturePoint-mapper.xml:11 |
| `SupporterSignaturePointStatDetailEntity` | `…SupporterSignaturePointStatDetailEntity` (shareStats) | supporterSignaturePoint-mapper.xml:17 |

### 테이블 (XML에서 관측된 실제 테이블명)

- `Signature` — 컬럼: `SignatureId, UserId, CampaignId, Content, TrackingPointInfoVersion, IsDeleted, StatusType, Provider, WhenCreated, Updated`
- `SupporterSignatureKeyword` — `KeywordId, KeywordName, KeywordType, Message, KeywordOrder, InUse`
- `SupporterSignatureKeywordData` — `SignatureId, KeywordId` (M:N 관계 테이블)
- `SupporterSignatureComment` — `CommentId, UserId, SignatureId, Content, IsMaker, IsDeleted, Status, Created, Updated`
- `SupporterSignatureReaction` — `TypeId, UserId, SignatureId, IsChecked`
- `SupporterSignatureCommentReaction` — `TypeId, UserId, CommentId, IsChecked`
- `SupporterSignatureReactionStat` — `StatReferenceId, StatType, ReactionTypeId, ReactionCount` (`StatType: 1=Signature, 2=Comment`)
- `SupporterSignatureTracking` — `TrackingId, UserId, SignatureId, PaymentId, PaymentDay, AffiliateType, Result, Created`
- `SupporterSignaturePoint` — `PointId, UserId, SignatureId, ReferenceId, ReferenceType, Amount, Created`
- `SupporterSignatureShare` — `ShareId, SignatureId, ShareStatus, Provider, Reason`

### Cross-DB 조인

상세 조회 쿼리(`findDetail`, `findCommentDetailAll` 등)는 **3개 스키마**를 횡단:
- `wadiz_db.*` — 기본 (`Signature`, `SupporterSignatureComment`, `SupporterSignatureReaction*`, `SupporterSignaturePoint`, `SupporterSignatureShare`, `SupporterSignatureTracking`, `SupporterSignatureKeyword*`, `UserProfile`, `PhotoCommon`).
- `wadiz_membership.member` (컬럼: `user_id`, `end`, `state`) — 멤버십 상태.
- `wadiz_wave_follow.Follow` (컬럼: `FollowNo`, `FollowingUserId`, `FollowerUserId`, `OptIn`), `wadiz_wave_follow.UserBlocking` (컬럼: `UserId`, `TargetUserId`, `OptIn`) — 팔로우/차단.

### 예시 SQL 인용 (XML 본문 그대로)

지지서명 생성 — `supporterSignature-mapper.xml:61-72`:
```sql
INSERT INTO Signature (UserId, CampaignId, Content, TrackingPointInfoVersion)
VALUES ( #{userId} , #{campaignId} , #{content} , #{trackingPointInfoVersion} )
-- selectKey: SELECT LAST_INSERT_ID()
```

tracking 삭제 지지서명 일괄 결과 처리 — `supporterSignatureTracking-mapper.xml:38-46`:
```sql
UPDATE SupporterSignatureTracking SST
    INNER JOIN Signature S ON S.SignatureId = SST.SignatureId AND S.IsDeleted is TRUE
    SET Result = #{result}
WHERE Result is NULL
AND PaymentDay < #{targetDay}
```

공유 포인트 전체 통계 (ReferenceType별 사용자 수 distinct) — `supporterSignaturePoint-mapper.xml:146-156`:
```sql
SELECT SP.ReferenceType,
       COUNT(distinct SP.UserId) as UserCount,
       SUM(SP.Amount) as Amount
FROM wadiz_db.SupporterSignaturePoint SP
         INNER JOIN Signature S ON S.SignatureId = SP.SignatureId AND S.IsDeleted is FALSE
WHERE SP.Created BETWEEN #{fromDay} AND #{toDay}
GROUP BY SP.ReferenceType;
```

(나머지 SQL은 §3 매퍼 XML 원본을 직접 참조 — 추측으로 재구성하지 않음.)

---

## 6. 외부 의존성

관측된 외부 호출 경계 (패키지명만):

| 의존 | 사용처 | 비고 |
|---|---|---|
| `com.wadiz.wave.infrastructure.push.PushGateway` | Tracking(`sendTrackingPointPush`), InterestDegree(both endpoints), Share(`sendShareNotification`), Communication(댓글 알림, 추정) | 내부 코드 미분석 — "외부 호출". `SupporterSignatureNotificationClient`가 래퍼. 템플릿/Inbox/Push 분기. |
| `com.wadiz.wave.infrastructure.points.*` | Tracking(`payTrackingPoint`), Share(`share`의 `issueSharePoint`) | 실제 포인트 지급. 실패 시 `IssuePointsException`(`PointErrorCode`). |
| `com.wadiz.wave.infrastructure.campaign.*` | Share(`getCampaignKRTitle`) | 캠페인 상세 조회. 실패 시 `CampaignDetailInfoSearchException`(`CampaignErrorCode`). |
| `com.wadiz.wave.user.supporter.signature.component.SupporterSignature*Component` | 모든 Service에서 Mapper 호출 중간층 | 이 문서에서는 경계. `CommandComponent` / `QueryComponent` 분리 CQRS 패턴 형태. |

### Kafka/RabbitMQ

`Grep`으로 `signature` 하위에서 `Kafka|RabbitMQ|SqsTemplate|@KafkaListener` 일치 건 없음. V1 지지서명은 **동기 HTTP 기반만** 사용 (push도 `PushGateway` 직접 호출).

---

## 7. 경계 및 미탐색 영역

### V3와의 중복

- Controller 6개 안의 **전 엔드포인트**에 V3 신규 API URL이 주석으로 대응되어 있음. 동일 기능을 V3가 완전히 대체할 계획 (IAM-3451).
- Service/Component 계층은 **공유**: V1의 `SupporterOldSignatureService`는 `SupporterSignatureCommandComponent`/`QueryComponent`를 사용하며, V3 서비스도 같은 Component를 호출하는 구조일 가능성이 높음(v3 Controller 이름 매칭으로 추정, 실제 코드 미확인). 즉, DB 로직은 이미 공유되었고, V1은 껍데기 성격.

### 삭제 예정 endpoint (주석 등급)

1. **"IAM-3451 배포 후 삭제 가능"** — 추가작업 불필요, 단독 삭제 가능:
   - `SupporterSignatureShareController#share` (`:33`)
   - `SupporterSignatureShareController#issuePoints` (`:46`)

2. **"IAM-3451 배포 후 추가작업 해야 삭제 가능!!!"** — 추가 마이그레이션 필요:
   - `SupporterSignatureOldController#hideSignature` (`:58`)
   - `SupporterSignatureOldController#deleteSignature` (`:68`) — admin/batch 연동 수정 필요

3. **"IAM-3451 배포 후 삭제 검토"** — 나머지 대부분. 호출처 조사 후 삭제.

4. **Service 내 `@Deprecated`**:
   - `SupporterSignatureTrackingService#getTrackingPointInfos` (`:96`) — Batch 쪽 신규 API 대체 배포 후 삭제.
   - `SupporterSignatureShareService#share`, `#issuePoints` — Component로 주요 기능 이관 시 삭제.

### 답 못한 질문 (미탐색)

- `SupporterSignatureQueryComponent#getCampaignId(signatureId)`가 정확히 어느 SQL id를 호출하는지 XML에 명시적 일치 쿼리 없음 (`find`, `findByUserIdAndCampaignId` 등에서 SELECT *로 꺼내 자바단에서 가공하는 것으로 추정되나 컴포넌트 본문 미확인).
- `SupporterSignaturePointQueryComponent#userShareInfo`가 `sumMyValidPointShareAmount` + `countShareByUserId`만으로 `UserSharePointInfo`를 충족시키는지 확인 필요 (DTO 필드에 `scheduledRewardCount`가 없어 SQL 부족분 없음으로 보이나, 집계 로직은 컴포넌트 내부).
- `findCountByUserIdAndCampaignId` 결과를 `boolean isSigned`로 변환하는 지점은 Component. Controller/Service 계층에서는 단순 위임.
- `supporterSignaturePoint-mapper.xml:78` — `S.SinatureId`/`SP.SinatureId` 타이포 (`Sinature`). 현재도 작동하는지는 해당 테이블 실제 컬럼명 확인 필요 (레거시 버그 후보).
- `ShareAdditionalInfoDto.chatType`의 `@Null` 제약과 실제 `ShareInfo.share()` 내부 사용(`findChatType(additionalInfo.getChatType())`)의 불일치 — 요청 스펙상 `chatType`은 null이어야 하지만 `MemoChat`/`DirectChat` 등 실제 값을 처리하려는 분기 존재. 호출 쪽과 제약의 어긋남 가능.
- Cache(`refreshCaching`, `usingCache`) 구현 계층 (Spring Cache / Caffeine / Redis?) — 이 문서에서는 파라미터 존재만 기록.
- `TrackingPointInfoResponse`의 값 소스(`affiliateCommandComponent.getPointVersion(v1)`)는 DB가 아닌 정적 설정/Enum으로 보이나 실제 backing source 미확인.

### 분석 품질 메모

- 컨트롤러 → 서비스까지는 코드 완독. 서비스 → 컴포넌트는 호출 메서드명만 대응 인용, 컴포넌트 내부는 미탐색 (경계).
- 모든 SQL 본문 인용은 XML 실제 내용 발췌 — 추측 재구성 없음.
- V3 API URL은 V1 Controller **주석 문자열 그대로** 옮김 (검증: V3 파일은 존재하나 본문 분석 범위 밖).
