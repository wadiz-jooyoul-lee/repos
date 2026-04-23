# com.wadiz.adm — 리워드 콘텐츠·기획전·메이커 커뮤니케이션 컨트롤러

## 1. 기록 범위

`com.wadiz.adm` (레거시 어드민, Spring 3.2 + JSP) 에서 **리워드 프로젝트를 둘러싼 콘텐츠/큐레이션/메이커 접점** 계열 컨트롤러만 정리한다. 리워드 결제·정산·심사·환불·배송 등 트랜잭션 계열은 별도 문서에서 다룬다.

본 문서에서 다루는 패키지:
- `com.wadiz.web.reward.{studio, collection, category, memo, makercommunication, user, satisfaction, issue, news.notification, comment, partner, pdconsulting, spaceexhibition, campaign, maker}`
- `com.wadiz.web.{collection, collectionExposure, maker, community, supporterclub, wcoming}`

총 **32개 컨트롤러** (Api 21 / Ui(View) 9 / Proxy 2).

## 2. 개요

이 영역의 공통 특성은 "**리워드 프로젝트 라이프사이클에서 콘텐츠·커뮤니케이션을 담당하는 어드민 도구**" 라는 점이다. 크게 세 축으로 갈린다.

1. **콘텐츠 큐레이션 축** — 리워드 프로젝트를 묶어서 노출시키는 기획전/컬렉션 도구.
   - `CollectionApi/Ui` (리워드 전용 컬렉션 CRUD)
   - `CollectionProxy` / `CollectionFileProxy` (신형 Platform Admin 통합 기획전으로 우회하는 프록시)
   - `CollectionExposureApi/Ui` (컬렉션 노출/순서 관리)
   - `RewardSpaceExhibitionApi/Ui` ("공간" 전시)
   - `CategoryApi` (카테고리 마스터)
2. **메이커 커뮤니케이션 축** — 메이커(프로젝트 개설자)와 운영팀 사이 왕복.
   - `MakerCommunicationApi/Ui` (피드백 / QnA 섹션)
   - `PdConsultingMeetingController` (PD 컨설팅 미팅 상태)
   - `RewardMakerStudioSubmitApiController` (메이커 스튜디오 제출 취소)
   - `MemoApiController` (어드민 내부 메모)
   - `CampaignIssueApi/Ui` (리스크·이슈 신고 접수·태스크)
   - `SatisfactionUiController` (메이커 만족도 결과 조회)
3. **유저·콘텐츠 노출 축** — 서포터 측 UGC 및 알림 관리.
   - `CommentApi/Ui` (댓글·답글 관리, 엑셀 다운로드)
   - `NewsNotificationUiController` (공지 알림 화면)
   - `WEBCommunityController` (게시판형 커뮤니티 — 피드/글/댓글/게시판/에디터/메일/머리말)
   - `SupporterClubController` (서포터클럽 할인권 등록결과/엑셀)
   - `WEBComingSoonController` / `WEBComingSoonRegisterController` (오픈알림 신청자 관리)
   - `MakerView*` / `MakerAnnouncementViewController` (SPA 진입점)

콘텐츠/이슈/커뮤니티를 모두 이 레거시 어드민 안에서 처리하지만, 일부 기능(통합 기획전, 메이커 상세 SPA, 커뮤니티 피드 관리)은 **신형 Platform Admin / SPA 로 이관되어 프록시 또는 `front/main` 리다이렉트로만 남아 있다.**

## 3. 컨트롤러 목록 (도메인별)

### 3.1 스튜디오 / 메모 / 메이커

| 파일 | Base path | 역할 |
|---|---|---|
| `web/reward/studio/controller/RewardMakerStudioSubmitApiController.java:20` | `/reward/api/studios` | 메이커 스튜디오 제출 취소 |
| `web/reward/memo/controller/MemoApiController.java:18` | `/reward/api/memos` | 캠페인 메모 조회/저장 |
| `web/reward/maker/controller/MakerApiController.java:20` | `/reward/api/makers` | 캠페인별 메이커 계정 조회 |
| `web/maker/controller/MakerViewController.java:17` | `/maker`, `/maker/detail/...` | SPA 진입 + corp 상세 리다이렉트 |
| `web/maker/announcement/controller/MakerAnnouncementViewController.java:9` | `/maker-announcement` | SPA 진입 only |

### 3.2 컬렉션 / 기획전 / 공간전시 / 카테고리

| 파일 | Base path | 역할 |
|---|---|---|
| `web/reward/collection/controller/CollectionApiController.java:27` | `/reward/api/collections` | (구) 리워드 컬렉션 CRUD + 매핑 |
| `web/reward/collection/controller/CollectionUiController.java:26` | `/reward/collection/*` | 목록/등록/상세 View |
| `web/collection/controller/CollectionProxyController.java:15` | `/manage/collection/**` | Platform Admin 로 generic proxy |
| `web/collection/controller/CollectionFileProxyController.java:13` | `/manage/file/cdn/collection` | 기획전 파일 업로드 proxy |
| `web/collectionExposure/controller/CollectionExposureApiController.java:20` | `/collectionExposure` | 노출 생성/수정/순서/삭제 |
| `web/collectionExposure/controller/CollectionExposureUiController.java:16` | `/collectionExposure` | 노출 목록/추가 팝업/상세 View |
| `web/reward/spaceexhibition/controller/RewardSpaceExhibitionApiController.java:15` | `/reward/space-exhibition/campaigns/{campaignId}` | 공간전시 get/save/valid |
| `web/reward/spaceexhibition/controller/RewardSpaceExhibitionUiController.java:21` | `/reward/space-exhibition` | 공간전시 목록/등록/상세 View |
| `web/reward/category/controller/CategoryApiController.java:19` | `/reward/api/categories` | 카테고리 전체 조회 |

### 3.3 메이커 커뮤니케이션 / PD / 이슈 / 만족도

| 파일 | Base path | 역할 |
|---|---|---|
| `web/reward/makercommunication/controller/MakerCommunicationApiController.java:16` | `/reward/api/feedbacks` | 피드백 템플릿 목록 |
| `web/reward/makercommunication/controller/MakerCommunicationUiController.java:20` | `/reward/feedbacks` | 피드백 조회/등록/템플릿 View |
| `web/reward/pdconsulting/controller/PdConsultingMeetingController.java:19` | `/reward/api/pd-consultings/{campaignId}/meetings` | PD 컨설팅 미팅 상태 변경 |
| `web/reward/issue/controller/CampaignIssueApiController.java:28` | `/reward/api/issue` | 리스크·신고·담당자·태스크 API |
| `web/reward/issue/controller/CampaignIssueUiController.java:26` | `/reward/issue` | 이슈 목록/상세/엑셀 View |
| `web/reward/satisfaction/controller/SatisfactionUiController.java:34` | `/reward/satisfaction` | 만족도 리스트/엑셀 |
| `web/reward/partner/controller/PartnerApiController.java:19` | `/reward/api/partners` | 파트너 목록 (사용중) |

### 3.4 유저 UGC (댓글/뉴스) / 공용

| 파일 | Base path | 역할 |
|---|---|---|
| `web/reward/user/controller/RewardUserController.java:18` | `/reward/api/users` | email 기반 유저 조회 |
| `web/reward/comment/controller/CommentApiController.java:22` | `/reward/api/comments` | 댓글 삭제/답글 등록/부모 조회 |
| `web/reward/comment/controller/CommentUiController.java:37` | `/reward/comment/*` | 댓글 목록/엑셀 다운로드 View |
| `web/reward/news/notification/controller/NewsNotificationUiController.java:14` | `/reward/news/notification` | 알림 목록 View + 유저 상세 팝업 |

### 3.5 캠페인 메타 / 커뮤니티 / 서포터클럽 / 오픈예정

| 파일 | Base path | 역할 |
|---|---|---|
| `web/reward/campaign/controller/CampaignApiController.java:27` | `/reward/api/campaigns` | 캠페인 조회 + 약정(계약) 변경 |
| `web/reward/campaign/controller/CampaignHiddenApiController.java:14` | `/reward/api/campaign-hidden/...` | 캠페인 숨김 조회/저장 |
| `web/reward/campaign/controller/CampaignMarkerApiController.java:18` | `/reward/api/campaigns/{campaignId}/campaign-marker` | 마커(태그·속성) 조회/저장 |
| `web/reward/campaign/controller/RewardCampaignUiController.java:9` | `/reward/campaign/pop*` | 팝업 템플릿 랜딩 |
| `web/reward/campaign/controller/RewardChangeLogController.java:18` | `/reward/api/reward-change-logs` | 리워드 변경 이력 (FundingGateway 경유) |
| `web/community/controller/WEBCommunityController.java:36` | `/community/*` | 커뮤니티 피드·글·댓글·게시판·머리말·에디터·메일 |
| `web/supporterclub/controller/SupporterClubController.java:29` | `/supporter-club*` | 서포터클럽 할인권 등록결과/엑셀 |
| `web/wcoming/controller/WEBComingSoonController.java:31` | `/wcomingsoon/progress/*` | 오픈알림 신청자 목록/알림결과/엑셀 |
| `web/wcoming/controller/WEBComingSoonRegisterController.java:25` | `/wcomingsoon/register` | 오픈알림 등록자 목록/엑셀 |

## 4. 도메인별 섹션

### 4.1 Studio — 메이커 스튜디오 제출 취소

단일 엔드포인트 컨트롤러로, "메이커 스튜디오" 작성 흐름에서 운영자가 강제 **취소** 할 때만 사용된다.

- 단일 API `POST /reward/api/studios/campaigns/{campaignId}/submit-cancel` — `RewardMakerStudioSubmitApiController.java:26`
- 처리 주체는 `RewardMakerStudioSubmitService.cancel(userId, campaignId)` — 실제 상태전환·로그 기록은 service 에 있음.
- `WEBSessionUtil.getUserId()` 로 운영자 식별자 주입 — 본 도메인 전역에서 반복되는 패턴.
- 응답은 `ResponseWrapper.success(true)` — 실질 결과보다 성공 여부만 돌려주는 boolean ack.
- 같은 `studio` 패키지 내부에 `Section`/`SectionLanguage`/`SectionKey`/`MakerProfile` 등 JPA 엔티티·Repository 가 있고, 제출 전 validation 은 `RewardMakerStudioCancelSubmitValidator` 에서 수행 → 컨트롤러는 얇고 도메인이 두꺼운 "pre-validated thin API" 형태.

### 4.2 Collection / CollectionExposure — 구버전 컬렉션과 신버전 기획전

리워드만 대상으로 하는 **(구) 리워드 컬렉션** 과, 전사(리워드+투자) 대상 **(신) 통합 기획전** 이 공존한다. 이행기임을 보여준다.

- **구버전 (`web/reward/collection`)**:
  - `CollectionApiController` 10개 엔드포인트:
    - `GET /reward/api/collections` — `@ModelAttribute CollectionDto.Search` 로 조건 조회 (`CollectionApiController.java:38`).
    - `POST /ajaxSaveCollection` — 등록자 userId 주입 후 `CollectionService.save()` (`CollectionApiController.java:44`).
    - `POST /ajaxSaveCollectionImage` — `MultipartFile` 업로드 → `FTUploadPhotoInfo` 리턴.
    - `POST /ajaxModifyCollection`, `GET /{collectionNo}`, `GET /duplication/keywords/{keyword}` (중복 키워드 검사).
    - `POST /saveCollectionCampaign` + `GET /deleteCollectionCampaign` — 컬렉션-캠페인 매핑 CRUD.
    - `GET /{collectionNo}/types/{type}/count`, `/deleteBulkCollectionMappingIds` — 매핑 카운트·벌크 삭제.
  - `CollectionUiController` 는 `/reward/collection/collectionList` 검색화면, `/saveCollectionView`, `/collectionDetailInfo` 팝업 세 엔드포인트. 검색은 `CollectionSearchInfoDto` → `PageableSearch<CollectionDto.Search>` 로 변환 후 `CollectionService.getCollectionInfo()` 호출 (`CollectionUiController.java:46`).
- **노출 관리 (`web/collectionExposure`)**:
  - `CollectionExposureApiController` — 생성/수정/순서변경/삭제/중복검사 5종. `orderModify` 는 `seqArray[]`, `orderArray[]` 배열 파라미터로 **드래그 정렬** 을 그대로 반영 (`CollectionExposureApiController.java:42`).
  - `CollectionExposureUiController.collectionExposures()` 에서 `getExposureActives()` / `getExposureInactives()` 두 서브리스트로 분리해 뷰 두 패널을 동시 렌더링 (`CollectionExposureUiController.java:26`).
  - `CollectionExposureType` / `CampaignType` enum 두 개의 path variable 로 **탭 구조** 를 URL 로 인코딩 — `/collectionExposure/collectionExposureAdd/exposure-types/{collectionExposureType}/campaign-types/{campaignType}`.
- **신버전 프록시 (`web/collection`)**:
  - `CollectionProxyController.proxyRequest` 는 `/manage/collection/**` 를 **Platform Admin** API 로 bypass. `@CheckUserLogin` AOP (`com.wadiz.core.collection.aop`) 로 어드민 세션만 검증. 본문/쿼리를 그대로 흘려보내 검증·비즈니스 로직이 없다 (`CollectionProxyController.java:23`).
  - `CollectionFileProxyController` 는 `multipart/form-data` 파일을 `collectionId` 와 함께 신형 File API 로 그대로 프록시 (`CollectionFileProxyController.java:28`).
- 두 시스템이 병행 운영된다는 점이 중요: **리워드 컬렉션** 은 `/reward/collection/*` 의 레거시 화면, **통합 기획전** 은 SPA + `/manage/collection/**` 프록시로 운영.

### 4.3 Category / Partner / User — 마스터·조회 단일 API

"메타데이터/드롭다운" 용 아주 얇은 컨트롤러.

- `CategoryApiController.getAll()` — 카테고리 전체 목록만 반환. 메서드가 `private` 인데 Spring 이 노출 (`CategoryApiController.java:27`).
- `PartnerApiController.getAllPartnerByUsed()` — 활성 파트너만. 파트너 도메인 자체는 리워드 수수료·정산 쪽에서 참조 (`PartnerApiController.java:27`).
- `RewardUserController.getUserByEmail(email)` — `/reward/api/users/by-email` 로 메일 키 단일 조회. 본 어드민의 이메일 검색 UI 에서 사용 (`RewardUserController.java:26`).
- 공통: `ResponseWrapper` 혹은 원시 DTO 를 그대로 리턴. DTO 조립 없음.
- `@Api` / `@ApiOperation` (Swagger v2) 는 이 영역 API 컨트롤러들이 일관되게 붙이고 있으나, 네이밍·tag 패턴은 느슨함.

### 4.4 Memo / Feedback(MakerCommunication) — 어드민 내부 기록과 메이커 대외 피드백

- `MemoApiController` 는 **어드민 내부 메모** (심사자/기획자 코멘트). `GET /reward/api/memos/campaigns/{campaignId}/{category}` 로 카테고리별 단건 get, `POST` 로 upsert. 저장 실패 시 빈 `MemoDto.Response.builder().build()` 로 graceful 처리 (`MemoApiController.java:42`) — 내부 메모이므로 실패해도 화면은 계속 쓰도록 설계.
- `MakerCommunicationApiController` 는 사실상 템플릿 목록(`FeedbackTemplate` enum) 만 제공 — 피드백 본체는 Ui 쪽에 있음 (`MakerCommunicationApiController.java:23`).
- `MakerCommunicationUiController` 가 이 도메인의 핵심:
  - `/reward/feedbacks/campaigns/{campaignId}/transactions/{transactionNo}` — 거래별 피드백 조회 (`MakerCommunicationUiController.java:32`).
  - `/reward/feedbacks/popCampaignFeedbackRegister` — 피드백 등록 팝업. `CampaignRepository.findFeedbackAvailableLanguages(campaignId)` 로 다국어 지원, `PackagePlanService.get()` 으로 요금제 타입(`planType`)을 View 에 전달해 템플릿/정책을 분기시킴 (`MakerCommunicationUiController.java:43`).
  - `/reward/feedbacks/templates/{type}` — enum 이 곧 JSP 경로를 결정 (`feedback/<templateFileName>`) — **enum driven view routing** (`MakerCommunicationUiController.java:60`).
- `FeedbackTemplate` 은 섹션·QnA·Feedback 모델과 묶여, `FeedbackSection` 단위로 다국어 메시지를 렌더.
- `PdConsultingMeetingController.modifyStatus(...)` 는 피드백과는 별도로 **PD 컨설팅 미팅** 상태전환 전용. `@Valid @RequestBody PdConsultingMeetingRequest` 로 dto 검증 + `NotAllowedChangeMeetingStatusException` 를 service 레벨에서 던지는 구조 (`PdConsultingMeetingController.java:26`).

### 4.5 CampaignIssue — 리스크·신고·태스크 3층 모델

`reward/issue` 는 본 어드민에서 가장 큰 하위 도메인 중 하나로, **리스크 프로젝트 ↔ 신고(접수) ↔ 조치(태스크)** 3계층 모델을 노출한다.

- `CampaignIssueApiController` (147라인) 에 다음이 섞여 있다:
  - 리스크 등록/상태변경 — `/campaigns/{id}/create` `/update` (`CampaignIssueApiController.java:46`).
  - 신고 저장 — `/campaigns/{id}/reports` + 근거파일 다운로드 (`CampaignIssueApiController.java:74`).
  - 담당자 등록/검증 — `/campaigns/{id}/managers`, `/manager/check`.
  - 태스크 저장(파일첨부) — `@RequestPart MultipartFile fileUpload` + `@RequestPart CampaignIssueTaskSave` 를 같이 받는 **multipart + JSON part** 패턴 (`CampaignIssueApiController.java:101`).
  - 태스크 파일 다운로드 — `/task/{taskId}/download` 에서 `URLEncoder.encode(...)` + `filename*=UTF-8''` 로 한글 파일명 이중 헤더 인코딩 (`CampaignIssueApiController.java:134`).
- `CampaignIssueUiController` 에서 상세 화면을 **`MAIN` / `MAKER` / `OTHER` 이슈 타입** 으로 분기:
  - `/campaigns/{id}/mainissue` vs `/makerissue` 가 별도 view (`detailMainIssue` / `detailMakerIssue`) 를 쓰면서 공통 모델은 `buildCampaignIssueModelAndView()` 로 뽑음 (`CampaignIssueUiController.java:109`).
  - 이슈 목록 리스트 + 두 종류 엑셀 다운로드 (`issueList`, `issueReportList`) — `CampaignIssueSearch` 한 DTO 로 검색·엑셀 모두 공유.
  - 태스크 이력 팝업 (`/keys/{seq}`) 에서 **이슈 신고 등록일** 을 같이 주입해 뷰에서 경과일 계산.

### 4.6 Comment / Satisfaction / NewsNotification — UGC & 만족도

- `CommentApiController` 는 **운영자 개입용** (댓글 삭제, 운영자 답글 등록, 부모 조회) 만 — 일반 유저 댓글 API는 본 어드민에 없음 (`CommentApiController.java:28`).
- `CommentApiController` 의 에러 처리: 예외를 잡아 `CommonAjaxResDto.setFailMessage(e.getMessage())` 로 담아 `ResponseWrapper.success()` 로 감싸 **항상 200** 을 돌려주는 레거시 Ajax 규약 (`CommentApiController.java:33`) — 프론트가 HTTP status 가 아니라 `failMessage` 존재 여부로 분기.
- `CommentUiController.rewardCampaignComment` 는 GET=빈 상태, POST=검색 하는 **단일 URL** 패턴. 엑셀 다운로드에서는 `CampaignScreeningAdapter` 로 "심사 담당자" 를 campaignId 기준 map 으로 lookup 해 각 row 에 합쳐 내보냄 (`CommentUiController.java:91`).
- 엑셀 다운로드는 본 영역 전반에 퍼진 패턴 — `CCI.DWLD_EXCEL_*` 상수 + `modelMap.put()` + `return "downloadExcel"` 으로 고정 뷰를 재사용 (Satisfaction, Comment, CampaignIssue, ComingSoon, SupporterClub 모두 동일).
- `SatisfactionUiController` 는 읽기 전용. `@Auditable(OperationType.READ, targetField="userNames")` 로 **조회 감사 로그** 를 남긴다 (`SatisfactionUiController.java:47`). 5000건 제한 하드코딩.
- `NewsNotificationUiController` 는 리스트 뷰 + 유저 상세 팝업 두 엔드포인트뿐이며, `UserAdapter` 는 외부 user 서비스 호출 (`NewsNotificationUiController.java:26`).

### 4.7 Community / Campaign 메타 — 레거시 메뉴 집합

- `WEBCommunityController` 는 **커뮤니티 관리 전체** 의 원샷 컨트롤러 (530라인, 25개 핸들러). 분할되지 않은 대형 컨트롤러로 다음을 모두 수행:
  - 피드 컨텐츠 (`/community/communityFeedContentList`, SPA 진입)
  - 게시글 (`communityArticleList`, `removeArticle`, `moveArticles`, `modifyArticle`, `copyArticle`, `popArticleInfo`)
  - 댓글 (`communityCommentList`, `removeComment`)
  - 게시판 (`communityBoardList`, `popBoardInfo`, `ajaxRemoveBoard`, `ajaxUpdateBoard`, `ajaxModifyBoardOrderNo`)
  - 머리말 (`ajaxGetHeadWordListByBoardId`, `ajaxRemoveHeadWord`, `ajaxUpdateHeadWord`, `ajaxModifyHeadWordOrderNo`, `ajaxRegistHeadWord`)
  - 에디터 (`communityEditorList`, `popRegistEditor`, `ajaxRegist/Modify/RemoveEditor`)
  - 메일 (`communityEmailList` 등)
- `SearchParamInfo.setPaging("Y"|"N")`, `param.setcPage(...)` 을 조작해 공개/비공개 리스트 두 페이징을 수동으로 맞추는 레거시 패턴 (`WEBCommunityController.java:66`). `CCI.NUMBER_1_INT` 같은 상수가 드러나 있음.
- `RewardCampaignUiController` 는 **팝업 URL → View** 매핑만 존재 (`popCampaignManage`, `popRewardChangeLog`) (`RewardCampaignUiController.java:12`). 비즈니스 로직 0.
- `CampaignApiController` 에는 캠페인 상세 조회 + **약정 변경(agreement change)** 이 혼재 — `modifyCampaignAgreement` / `manualVerification` 두 엔드포인트는 `CampaignAgreementConclusionService` 로 delegate (`CampaignApiController.java:49`).
- `CampaignHiddenApiController` 는 숨김 이력(`CampaignHiddenHistoryCreate`) 을 등록 주체(userId) 와 함께 저장 — 운영자 감사 기본 패턴.
- `CampaignMarkerApiController` 는 임의 attribute triple `(strValue1, intValue1, orderNo)` 의 **범용 마커** 를 저장 — 태그·속성·정렬을 하나의 테이블로 커버 (`CampaignMarkerApiController.java:25`).
- `RewardChangeLogController` 는 특이하게도 **리워드 변경 이력을 MongoDB 보유한 `com.wadiz.api.funding`** 에 `FundingGateway` 로 위임하고, `UserAdapter.getUserNickName(userIds)` 으로 nickname 을 본 어드민에서 enrich (`RewardChangeLogController.java:64`). → 어드민이 서비스 계층을 넘나드는 BFF 역할.

### 4.8 Maker / SupporterClub / ComingSoon — 외연

- `MakerApiController` 는 캠페인 → 메이커 계정 조회 하나뿐 (`MakerApiController.java:27`).
- `MakerViewController` 는 신형 SPA (`front/main`) 로 보내는 진입점 + `/maker/detail/{campaignType}/{campaignId}` 에서 `StartupMakerApiAdapter` 를 타고 `corpNo` 를 얻어 `/web/maker/detail/{corpNo}/history` 로 **redirect** — 캠페인ID → 법인ID 변환 후 SPA 라우트 매핑 (`MakerViewController.java:28`).
- `MakerAnnouncementViewController` 는 `/maker-announcement` 진입만 — 본체는 SPA.
- `SupporterClubController` 는 신형 SPA(`front/main`) 진입 + 레거시 엑셀 다운로드 두 개(`registration/downloadExcel`, `list/downloadExcel`) 를 POI(`XSSFWorkbook`) 로 **직접 셀 조립**. `CCI.DWLD_EXCEL_*` 헬퍼를 쓰지 않고 `response.getOutputStream()` 에 바로 쓰는 드문 패턴 (`SupporterClubController.java:55`). `VoucherService` / `VoucherResultDto` 는 `kr.wadiz.membership` 패키지 → **멤버십 서비스 연동**.
- `WEBComingSoonController` 는 오픈알림 신청현황(`applicantList`) + 알림 결과(`/notification/results/transactionKey/{transactionKey}`) + 엑셀 3 엔드포인트. `WComingSoonService` (core) + `WEBComingSoonService` (web) 두 서비스 혼용 — core 가 DB/비즈, web 이 뷰 조립.
- `WEBComingSoonRegisterController` 는 오픈예정 등록 신청자 리스트 + 엑셀. 포맷/전략이 `WEBComingSoonController` 와 동일.

## 5. UI vs API 분리 패턴 (`*UiController` vs `*ApiController`)

본 영역에서 가장 강하게 관찰되는 규약. 대부분의 신규 하위 도메인(`collection`, `collectionExposure`, `spaceexhibition`, `issue`, `makercommunication`, `comment`) 은 **두 컨트롤러 쌍** 으로 분리되어 있다.

- **`*ApiController`**
  - `@Api` / `@ApiOperation` 로 Swagger 노출.
  - `produces = MediaType.APPLICATION_JSON_VALUE`.
  - 리턴은 `ResponseWrapper<T>` (`com.wadiz.api.reward.support.ResponseWrapper`) 로 wrap.
  - `@ResponseBody` 를 메서드마다 붙이며, 클래스는 `@Controller` (not `@RestController`).
  - 요청 DTO 는 보통 `@RequestBody` JSON (issue·hidden) / `@ModelAttribute` form (collection·exposure) 가 혼재.
- **`*UiController`**
  - `ModelAndView` 를 리턴, `mv.setViewName("...")` 로 JSP 템플릿 경로 지정.
  - `@Auditable(OperationType.READ | EXCEL_DOWNLOAD, targetField=...)` 로 **조회/다운로드 감사** 를 메서드 단위로 추가 (Satisfaction, Comment).
  - 엑셀 다운로드는 별도 엔드포인트로 두고 `return "downloadExcel";` 공통 뷰 + `modelMap.put(CCI.DWLD_EXCEL_*, ...)` 규약.
  - 페이징은 `PaginationInfo(cPage, totalCount, pageSize)` 로 통일. 상수 `DEFAULT_CURRENT_PAGE="1"`, `DEFAULT_PAGE_SIZE="15"`, `VIEW_PAGE_AND_API_PAGE_GAP=1` (1-based 뷰 ↔ 0-based 서비스) 가 이 영역 Ui 전체에서 반복.

대형 레거시 컨트롤러 (`WEBCommunityController`, `WEBComingSoonController`, `SupporterClubController`) 는 이 분리를 따르지 않고 **View + Ajax JSON 을 한 컨트롤러에 섞어 둔다** — 생성 시점이 더 오래됐음을 시사.

세션/사용자 주입도 일관 — 모든 쓰기 엔드포인트에서 `WEBSessionUtil.getUserId()` 또는 `WEBSessionUtil.getUserInfo()` 를 호출해 DTO 에 `registerUserId`/`userId` 를 setter 로 주입 후 서비스로 전달.

## 6. 경계

1. **프록시를 통한 신형 플랫폼 이관** — `CollectionProxy*Controller` 와 `Maker*View*Controller`, `SupporterClubController` 의 `front/main` 리턴이 명확한 증거다. 이 어드민은 **이관 완료 영역은 SPA redirect / 프록시 bypass, 이관 미완 영역은 직접 JSP** 를 유지하는 하이브리드 모드.
2. **FundingGateway / UserAdapter / StartupMakerApiAdapter / CampaignScreeningAdapter** 등 adapter 가 반복 등장 — 레거시 어드민이 실제로 DB 를 직접 다루는 대신, 리워드/스타트업/유저/심사 서비스에 REST 호출을 붙여 BFF 처럼 기능한다. 이 경계는 컨트롤러 레이어에서도 (`RewardChangeLogController`, `CampaignIssueUi`, `CommentUi`) 드러난다.
3. **감사(Audit) 레이어** 는 본 문서 범위 전반에서 느슨하게 적용 — `@Auditable` 이 붙은 핸들러는 Satisfaction/Comment 등 조회·엑셀 계열에 한정. 쓰기 API 쪽은 audit 대신 `CampaignHiddenHistoryCreate` 등 **DTO 에 이력을 포함시켜** 별도 테이블에 남기는 전략.
4. **"메이커 커뮤니케이션" 은 세 시스템으로 흩어져 있다**: `MakerCommunication*` (피드백/QnA/섹션), `CampaignIssue*` (이슈 조치), `PdConsultingMeeting` (컨설팅 미팅 상태), `MemoApi` (내부 메모). 네 도메인 모두 campaignId 를 키로 하지만 모델·화면·엑셀이 각각 독립.
5. **콘텐츠 큐레이션** 영역은 용어가 불안정하다 — `Collection`, `CollectionExposure`, `SpaceExhibition`, `Category`, `CampaignMarker` 가 모두 "묶어서 노출" 계열인데 스키마·화면·권한이 분리되어 있어, 운영자는 동일한 "기획전 느낌" 작업을 다른 메뉴에서 수행한다. 신형 Platform Admin (통합 기획전) 으로의 일원화가 진행 중인 부분.
6. **서포터클럽·커뮤니티·오픈예정** 은 리워드 프로젝트 부속 기능으로 보기 어려우나, 본 어드민이 유일한 운영 화면이라 같이 묶여 있다. 세 도메인 모두 SPA(`front/main`) 진입점을 제공하고, 레거시 엑셀/등록 화면만 JSP 로 남은 상태.
