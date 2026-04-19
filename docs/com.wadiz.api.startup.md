# com.wadiz.api.startup 분석 문서

## 개요
- Wadiz의 **메이커(스타트업) 도메인** API 서버. 펀딩/스토어 "메이커" 기업 정보(기업/멤버/담당자), 메이커 프로필 스튜디오(사업기술, 투자이력, 피칭), 메이커 뉴스/댓글/반응, 메이커 팔로우/알림, 메이커 부스터(Wish), 메이커 클럽, 컬렉션(기획전), 만족도 요약, 컨퍼런스(투표/어워드), 기업 IR 문의 등을 담당한다.
- org `com.wadiz.api`, Java package base `com.wadiz.api.startup.*`. Gradle 멀티 프로젝트(`startup-model`, `startup-client`, 루트가 API). 서버 포트 **9500**.
- 주요 사용자: Wadiz 메이커(기업), Wadiz 운영자(백오피스 등록·연동), 공통 서비스(com.wadiz.web, com.wadiz.api.funding 등)에서 내부 호출.

## 기술 스택
- 언어/버전: **Java 1.8**, Spring Boot **2.3.10.RELEASE**, Spring Cloud **Hoxton.SR12** (Consul discovery).
- 빌드: Gradle 멀티 프로젝트. 하위 `startup-client` / `startup-model` 는 외부 공개용 클라이언트·모델 JAR(wadizcorp maven repo로 publish, `gradle.properties` 에서 `model_version`/`client_version` 관리).
- 프로젝트별 의존: `startup-model`(도메인 모델), `startup-client`(외부 소비 DTO/클라이언트), 루트(API 서버).
- DB: **MySQL** (hikari, master/slave `wadiz_db` DB, Jasypt 로 password 암호화 `ENC(...)`).
- ORM: **Spring Data JPA + Hibernate(MySQL Dialect, 2nd-level cache Ehcache 사용)** + **MyBatis 1.3.2** (복잡 쿼리) + **QueryDSL 4.4.0** (+ MapStruct 1.5.5).
- 검색: **Spring Data Elasticsearch** (`fn-funding-active`, `fn-store-active`, `fn-company-active`, `fn-invest-active`, `fn-maker-grade`, `maker_activity_feeds-alias` 인덱스, `createIndex = false`로 외부 인덱서가 관리).
- 캐시: **Ehcache 3.8.1** (JCache) + Hibernate 2차 캐시. Spring Cache 활성화.
- 인증/보안: Spring Security + OAuth2 Resource Server (JWT wadiz pub key `iam.pub`, `iam-live.pub`), Jasypt for YML 암호화.
- 파일 스토리지: MinIO 8.0.0 SDK (S3 버킷도 직접 사용 — `wadiz.funding.public.*`).
- 외부: Wadiz Notification Client, Wadiz Payment Log Client (shared lib), BitLy, Slack, FriendTalk(Kakao).
- 문서: Springfox Swagger 2.9.2 (`/swagger-ui.html`).
- 기타: Lombok, spring-retry, problem-spring-web, commons-lang/commons-httpclient(레거시), json-simple.
- 배포: Jenkinsfile. bootJar executable JAR 바로 service 등록 방식 (`bootRepackage executable=true`).

## 아키텍처
- **도메인 패키지 중심의 MVC** 구조 (DDD 규약 레포처럼 강제되지는 않음). 도메인별로 `controller`, `service`, `repository`, `model`(Entity), `dto`, `constant` 서브 패키지가 반복된다. 별도의 application/domain 레이어 분리는 얕다.
- 패키지 트리 1단계 (`src/main/java/com/wadiz/api/startup`):
```
com.wadiz.api.startup
├── config/                                # Spring config, Jpa/Datasource, Interceptor, Security 등
│   ├── converter/ properties/
├── constant/                              # 공통 enum (CountryCode, LanguageCode)
├── excepion/                              # 예외(오타 주의 "excepion") GlobalExceptionHandler
├── repository/wadiz/                      # 공통 MyBatis mapper 인터페이스
├── service/                               # 공통 서비스
├── support/                               # 공통 지원 (authority, converter, friendtalk, session, proxy, prevVersion)
├── utils/                                 # util
└── domain/                                # 33개 도메인 서브패키지
    ├── admin/ adminRequest/ club/ collection/ common/ contact/
    ├── corporation/ corpInvestor/ detail/ event/ external/ faq/
    ├── feed/ file/ follow/ inquiry/ investment/ irRequest/ ked/
    ├── maker/ member/ mywadiz/ news/ newsComment/ notice/
    ├── notification/ project/ push/ registration/ satisfaction/
    ├── slack/ terms/ user/ wish/
    └── (각각 controller/, service/, repository/, model/, dto/, constant/)
```
- ES 인덱스 기반 조회: `maker/model/Funding`, `Store`, `Company`, `Invest`, `MakerGrade`, `MakerActivityFeedIndex` 는 `@Document`로 Elasticsearch 저장소와 연동 (createIndex=false, 외부 indexer 서비스에서 색인).
- 설정 프로파일: local / dev / rc / rc2 / rc3 / live — 단일 `startup.yml` 내 `---` 구분으로 관리.

## API 엔드포인트 목록
33개 Controller. 모두 prefix `/api/v1/startup/...` (or `/api/v1`) 기반.

| Method | Path | Controller.method | 용도 |
|--------|------|-------------------|------|
| GET | /api/v1/startup/maker/third-party | MakerApiController.getThirdPartyProvisionMakers | 3rd party 제공 메이커 목록 |
| GET | /api/v1/startup/maker/{corpNo}/children | MakerApiController.getChildrenMaker | 자회사/하위 메이커 |
| POST | /api/v1/startup/maker/follow/request | MakerApiController.requestMakerFollow | 메이커 팔로우 요청 |
| POST | /api/v1/startup/maker/notice/request | MakerApiController.requestMakerNotice | 알림 수신 요청 |
| GET | /api/v1/startup/maker/{corpNo} | MakerApiController.getMakerInfoByCorpNo | 메이커 상세(By corpNo) |
| GET | /api/v1/startup/maker/campaignType/{campaignId} | MakerApiController.getMakerInfoByCampaignId | 캠페인 ID로 메이커 조회 |
| GET | /api/v1/startup/maker/campaignType/{campaignType}/campaignId/{campaignId} | MakerApiController.getMakerInfo | 다국어 지원 메이커 조회 |
| GET | /api/v1/startup/maker | MakerApiController.getMakerInfoByCampaignIds | Bulk 캠페인 조회 |
| GET | /api/v1/startup/maker/{corpNo}/stores | MakerApiController.getStoreList | 메이커의 스토어 목록 |
| GET | /api/v1/startup/maker/{corpNo}/stores/project-nos | MakerApiController.getStoreProjectIds | 스토어 프로젝트 번호 |
| GET | /api/v1/startup/maker/{corpNo}/fundings | MakerApiController.getFundingList | 펀딩 목록 |
| GET | /api/v1/startup/maker/{corpNo}/fundings/project-nos | MakerApiController.getFundingProjectIds | 펀딩 프로젝트 번호 |
| GET | /api/v1/startup/maker/{corpNo}/isFollow | MakerApiController.isFollowMaker | 팔로우 여부 |
| GET | /api/v1/startup/maker/{corpNo}/isNotice | MakerApiController.isNoticeMaker | 알림 수신 여부 |
| POST | /api/v1/startup/maker/list | MakerApiController.getMakerList | 메이커 목록 |
| GET | /api/v1/startup/maker/{corpNo}/isVisible | MakerApiController.isVisible | 노출 여부 |
| GET | /api/v1/startup/maker/{corpNo}/equity | MakerApiController.getMakerEquity | 투자 정보 |
| POST | /api/v1/startup/maker/{corpNo}/equity/more | MakerApiController.getMakerEquityMore | 투자 상세 |
| POST | /api/v1/startup/makers/{projectType}/bulk | MakerApiController.getBulkMakerInfo | Bulk 메이커 정보 |
| GET | /api/v1/startup/maker/studio/base/{corpNo} | MakerStudioApiController.baseInfo | 스튜디오 기본 정보 |
| GET | /api/v1/startup/maker/{corpNo}/studio/base | MakerStudioApiController.baseInfoV2 | 스튜디오 기본 (new) |
| POST | /api/v1/startup/maker/studio/base | MakerStudioApiController.saveBase | 기본 저장 |
| POST | /api/v1/startup/maker/{corpNo}/studio/base | MakerStudioApiController.saveBaseV2 | 기본 저장 (new) |
| GET | /api/v1/startup/maker/studio/impression/{corpNo} | MakerStudioApiController.impressionGet | 인상 조회 |
| POST | /api/v1/startup/maker/studio/impression | MakerStudioApiController.impressionPost | 인상 저장 |
| GET | /api/v1/startup/maker/studio/ked/{corpNo} | MakerStudioApiController.kedGet | KED 연동 기업 정보 |
| GET | /api/v1/startup/maker/studio/businessTechnology/{corpNo} | MakerStudioApiController.btGet | 사업기술 조회 |
| POST | /api/v1/startup/maker/studio/businessTechnology | MakerStudioApiController.btPost | 사업기술 저장 |
| POST | /api/v1/startup/maker/studio/introduce | MakerStudioApiController.introPost | 소개 저장 |
| POST | /api/v1/startup/maker/studio/businessModel | MakerStudioApiController.bmPost | 비즈니스 모델 저장 |
| POST | /api/v1/startup/maker/studio/coreSpec | MakerStudioApiController.coreSpecPost | 핵심스펙 저장 |
| GET | /api/v1/startup/maker/studio/pitchingVideo/{corpNo} | MakerStudioApiController.pitchingGet | 피칭 비디오 |
| POST | /api/v1/startup/maker/studio/pitchingVideo | MakerStudioApiController.pitchingPost | 피칭 저장 |
| GET | /api/v1/startup/maker/studio/investmentHistory/{corpNo} | MakerStudioApiController.invGet | 투자 이력 |
| POST | /api/v1/startup/maker/studio/investmentHistory | MakerStudioApiController.invPost | 투자 이력 저장 |
| PUT | /api/v1/startup/maker/studio/investmentHistory | MakerStudioApiController.invPut | 이력 수정 |
| PUT | /api/v1/startup/maker/studio/investmentHistory/modifySeqs | MakerStudioApiController.invSeqs | 순서 변경 |
| POST | /api/v1/startup/maker/studio/investmentHistory/delete | MakerStudioApiController.invDelete | 삭제 |
| POST | /api/v1/startup/maker/studio/dashboard | MakerStudioApiController.dashboardPost | 대시보드 |
| GET | /api/v1/startup/maker/{corpNo}/studio/dashboard | MakerStudioApiController.dashboardGet | 대시보드 조회 |
| GET | /api/v1/startup/maker/studio/immediatelyElasticUpdate/{corpNo} | MakerStudioApiController.elasticUpdate | ES 즉시 갱신 |
| GET | /api/v1/startup/maker/studio/hidden/{corpNo} | MakerStudioApiController.hiddenGet | 숨김 여부 |
| POST | /api/v1/startup/maker/studio/hidden | MakerStudioApiController.hiddenPost | 숨김 처리 |
| POST | /api/v1/startup/maker/promotion/funding/users | MakerPromotionApiController.fundingUsers | 펀딩 프로모션 사용자 |
| POST | /api/v1/startup/maker/promotion/store/users | MakerPromotionApiController.storeUsers | 스토어 프로모션 |
| POST | /api/v1/startup/maker/promotion/maker-promotion/funding/supporter | MakerPromotionApiController.mpFundingSup | 펀딩 메이커프로모션 서포터 |
| POST | /api/v1/startup/maker/promotion/maker-promotion/store/supporter | MakerPromotionApiController.mpStoreSup | 스토어 메이커프로모션 서포터 |
| POST | /api/v1/startup/maker/vote | MakerEventApiController.vote | 어워드 투표 |
| GET | /api/v1/startup/maker/vote/isVoters | MakerEventApiController.isVoters | 투표자 여부 |
| GET | /api/v1/startup/maker/vote/corpNo/votes | MakerEventApiController.corpVotes | 기업 투표 |
| GET | /api/v1/startup/maker/vote/totalVotes | MakerEventApiController.total | 총 투표수 |
| GET | /api/v1/startup/maker/vote/expirationDateTime | MakerEventApiController.exp | 투표 마감일시 |
| GET | /api/v1/startup/maker/award/category/maker | MakerEventApiController.awardCatMaker | 어워드 카테고리 메이커 |
| GET | /api/v1/startup/maker/award/category/supporter | MakerEventApiController.awardCatSupporter | 어워드 카테고리 서포터 |
| GET | /api/v1/startup/maker/award/awardee/maker | MakerEventApiController.awardeeMaker | 수상자 메이커 |
| GET | /api/v1/startup/maker/award/awardee/supporter | MakerEventApiController.awardeeSupporter | 수상자 서포터 |
| GET | /api/v1/startup/maker/vote/candidate/maker | MakerEventApiController.candidateMaker | 후보 메이커 |
| GET | /api/v1/startup/maker/{corpNo}/member/superAdmin | MakerMemberApiController.superAdmin | 대표 운영자 |
| GET | /api/v1/startup/maker/{corpNo}/member/list | MakerMemberApiController.list | 멤버 리스트 |
| GET | /api/v1/startup/maker/{projectNo}/members | MakerMemberApiController.projectMembers | 프로젝트 기준 멤버 |
| GET | /api/v1/startup/maker/member/{memberNo} | MakerMemberApiController.member | 멤버 상세 |
| POST | /api/v1/startup/maker/member/Admin/register | MakerMemberApiController.registerAdmin | Admin 등록 |
| GET | /api/v1/startup/corporation/{corpNo}/investmentHope | CorporationApiController.investHope | 투자 희망 조회 |
| POST | /api/v1/startup/corporation/{corpNo}/investmentHope | CorporationApiController.investHopePost | 투자 희망 등록 |
| POST | /api/v1/startup/corporation/{corpNo}/contract | CorporationApiController.contract | 계약 등록 |
| GET | /api/v1/startup/corporation/{corpNo}/contract/startIndex/{s}/limitSize/{l} | CorporationApiController.contractList | 계약 목록 |
| GET | /api/v1/startup/corporation/contract/contractNo/{contractNo} | CorporationApiController.contractDetail | 계약 상세 |
| POST | /api/v1/startup/corporation/{corpNo}/contract/cancel | CorporationApiController.cancelContract | 계약 취소 |
| GET | /api/v1/startup/corporation/{corpNo}/detail | CorporationApiController.detail | 기업 상세 |
| GET | /api/v1/startup/corporation/interested/user/{userId} | CorporationApiController.interested | 관심 기업(by user) |
| GET | /api/v1/startup/corporation/{corpNo}/contact | CorporationApiController.contact | 담당자 |
| GET | /api/v1/startup/corporation/contact/no/{no} | CorporationApiController.contactByNo | 담당자 by no |
| POST | /api/v1/startup/corporation/contact/create | CorporationApiController.contactCreate | 담당자 등록 |
| POST | /api/v1/startup/corporation/contact/modify | CorporationApiController.contactModify | 담당자 수정 |
| GET | /api/v1/startup/corporation/contact/detail/corpNo/{corpNo}/type | CorporationApiController.contactDetailType | 담당자 타입별 |
| GET | /api/v1/startup/corporation/contact/detail/corpNo/{corpNo} | CorporationApiController.contactDetail | 담당자 상세 |
| GET | /api/v1/startup/corporation/contact/detail/corpNo/{corpNo}/keyContact | CorporationApiController.keyContact | 핵심 담당자 |
| POST | /api/v1/startup/maker-club | MakerClubController.insertAll | 메이커 클럽 등록 |
| GET | /api/v1/startup/maker-club | MakerClubController.getAll | 메이커 클럽 목록 |
| GET | /api/v1/startup/maker-club/project-type/{projectType}/project-no/{projectNo} | MakerClubController.getOneByProjectTypeAndNo | 프로젝트 기준 클럽 |
| GET | /api/v1/startup/maker-club/business-reg-number/{businessRegNumber} | MakerClubController.getOneByBusinessRegNumber | 사업자번호 기준 클럽 |
| POST | /api/v1/startup/inquiry/create | CorporationInquiryController.create | 기업 문의 등록 |
| GET | /api/v1/startup/inquiry/corpNo | CorporationInquiryController.byCorp | 기업별 문의 |
| GET | /api/v1/startup/inquiry/inquirerUserId | CorporationInquiryController.byUser | 사용자별 문의 |
| POST | /api/v1/startup/inquiry/reply | CorporationInquiryController.reply | 문의 답변 |
| GET | /api/v1/startup/inquiry/isReplied | CorporationInquiryController.isReplied | 답변 여부 |
| GET | /api/v1/startup/inquiry/defaultMessage | CorporationInquiryController.defaultMessage | 기본 메시지 |
| GET | /api/v1/startup/inquiry/inquirer | CorporationInquiryController.inquirer | 문의자 |
| GET | /api/v1/startup/inquiry/exist | CorporationInquiryController.exist | 문의 존재 |
| GET | /api/v1/startup/inquiry/no | CorporationInquiryController.byNo | 문의 번호 |
| GET | /api/v1/startup/maker/registration/searchByBusinessRegNumber | MakerRegistrationApiController.searchByBiz | 사업자번호 조회 |
| POST | /api/v1/startup/maker/registration | MakerRegistrationApiController.register | 메이커 등록 |
| POST | /api/v1/startup/maker/registration/individual | MakerRegistrationApiController.registerIndividual | 개인 메이커 등록 |
| GET | /api/v1/startup/maker/registration/individual/check | MakerRegistrationApiController.checkIndividual | 개인 등록 체크 |
| GET | /api/v1/startup/maker/registration/individual | MakerRegistrationApiController.individual | 개인 조회 |
| POST | /api/v1/startup/maker/interconnect/funding | MakerInterconnectApiController.interconnectFunding | 펀딩 자동 등록(연동) |
| POST | /api/v1/startup/maker/interconnect/store | MakerInterconnectApiController.interconnectStore | 스토어 자동 등록(연동) |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/create | NewsCommentApiController.create | 댓글 등록 |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/{commentId}/create | NewsCommentApiController.reply | 대댓글 |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/list | NewsCommentApiController.list | 댓글 목록 |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/{commentId}/list | NewsCommentApiController.replyList | 대댓글 목록 |
| PUT | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/{commentId}/update | NewsCommentApiController.update | 댓글 수정 |
| DELETE | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/{commentId}/delete | NewsCommentApiController.delete | 댓글 삭제 |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/comment/{commentId}/reaction | NewsCommentApiController.reaction | 댓글 반응 |
| POST | /api/v1/startup/maker/follow/user | MakerFollowApiController.getFollowMakerList | 사용자 팔로우 메이커 |
| POST | /api/v1/startup/maker/follow/my/user | MakerFollowApiController.getMyFollowMakerList | 내 팔로우 |
| GET | /api/v1/startup/maker/follow/user | MakerFollowApiController.getFollowerMakerList | 암호화 userId 기반 |
| GET | /api/v1/startup/maker/{corpNo}/follow/count | MakerFollowApiController.getMakerFollowCount | 팔로우 수 |
| GET | /api/v1/startup/maker/follow/increase | MakerFollowApiController.getMakerInfoByFollowIncrease | 팔로우 증가 메이커 |
| POST | /api/v1/startup/maker/follow/check | MakerFollowApiController.checkFollowedUsers | 팔로우 여부 Bulk (5000 제한) |
| GET | /api/v1/startup/collection/bannerList | StartupCollectionApiController.bannerList | 컬렉션 배너 |
| GET | /api/v1/startup/collection/keyword/{keyword} | StartupCollectionApiController.byKeyword | 키워드 컬렉션 |
| GET | /api/v1/startup/collection/keyword/{keyword}/card | StartupCollectionApiController.cards | 키워드 카드 |
| GET | /api/v1/startup/collection | StartupCollectionApiController.list | 컬렉션 목록 |
| GET | /api/v1/startup/collection/{collectionNo} | StartupCollectionApiController.byNo | 컬렉션 상세 |
| POST | /api/v1/startup/collection/{collectionNo}/modify | StartupCollectionApiController.modify | 수정 |
| POST | /api/v1/startup/collection/create | StartupCollectionApiController.create | 생성 |
| GET | /api/v1/startup/collection/{collectionNo}/corporation | StartupCollectionApiController.corporations | 매핑 기업 |
| POST | /api/v1/startup/collection/{collectionNo}/mapping/create | StartupCollectionApiController.addMapping | 매핑 추가 |
| POST | /api/v1/startup/collection/mapping/{mappingNo}/delete | StartupCollectionApiController.delMapping | 매핑 삭제 |
| POST | /api/v1/startup/collection/{collectionNo}/mapping/create/bulk | StartupCollectionApiController.addMappingBulk | 매핑 Bulk |
| POST | /api/v1/startup/collection/{collectionNo}/mapping/delete/bulk | StartupCollectionApiController.delMappingBulk | 매핑 Bulk 삭제 |
| POST | /api/v1/startup/collection/{collectionNo}/mapping/create/confirm | StartupCollectionApiController.confirm | 매핑 확정 |
| GET | /api/v1/startup/maker/mywadiz/completion/{corpNo} | MakerMyWadizApiController.completion | 완료도 |
| GET | /api/v1/startup/maker/mywadiz/makerpages | MakerMyWadizApiController.makerpages | 페이지들 |
| GET | /api/v1/startup/maker/mywadiz/pages | MakerMyWadizApiController.pages | MyWadiz 페이지 |
| POST | /api/v1/startup/maker/mywadiz/page/{corpNo} | MakerMyWadizApiController.page | 페이지 |
| POST | /api/v1/startup/maker/{corpNo}/mywadiz/profile | MakerMyWadizApiController.profile | 프로필 |
| POST | /api/v1/startup/maker/{corpNo}/push/test | PushApiController.test | 푸시 테스트 |
| GET | /api/v1/startup/maker/{corpNo}/push/statistics/list | PushApiController.stats | 푸시 통계 |
| GET | /api/v1/startup/maker/{corpNo}/push/isAvailable | PushApiController.isAvailable | 푸시 가능여부 |
| GET | /api/v1/startup/maker/{corpNo}/push/credit | PushApiController.credit | 크레딧 |
| POST | /api/v1/startup/maker/{corpNo}/push/credit/issuance | PushApiController.issue | 크레딧 발행 |
| POST | /api/v1/startup/maker/{corpNo}/push/credit/cancel | PushApiController.cancel | 크레딧 취소 |
| GET | /api/v1/startup/maker/studio/{corpNo}/news | MakerNewsStudioApiController.getAll | 스튜디오 뉴스 |
| GET | /api/v1/startup/maker/studio/{corpNo}/news/{newsId} | MakerNewsStudioApiController.getOne | 상세 |
| POST | /api/v1/startup/maker/studio/{corpNo}/news | MakerNewsStudioApiController.create | 등록 (+푸시 발송) |
| PUT | /api/v1/startup/maker/studio/{corpNo}/news/{newsId} | MakerNewsStudioApiController.update | 수정 |
| DELETE | /api/v1/startup/maker/studio/{corpNo}/news/{newsId} | MakerNewsStudioApiController.delete | 삭제 |
| GET | /api/v1/startup/maker/studio/{corpNo}/news/{newsId}/isDeletable | MakerNewsStudioApiController.isDeletable | 삭제 가능 |
| GET | /api/v1/startup/maker/{corpNo}/news | MakerNewsApiController.getAll | 공개 뉴스 |
| GET | /api/v1/startup/maker/{corpNo}/news/{newsId} | MakerNewsApiController.getOne | 공개 뉴스 상세 |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/reaction | MakerNewsApiController.saveReaction | 반응 등록 |
| POST | /api/v1/startup/maker/{corpNo}/news/{newsId}/vote/{voteId}/multiple/{voteMultipleId}/choose | MakerNewsApiController.chooseVoteMultiple | 뉴스 투표 |
| POST | /api/v1/startup/maker/news/files | MakerNewsFileApiController.upload | 뉴스 파일 업로드 |
| DELETE | /api/v1/startup/maker/news/files/{fileId} | MakerNewsFileApiController.delete | 파일 삭제 |
| GET | /api/v1/startup/maker/news/files/{fileId} | MakerNewsFileApiController.get | 파일 조회 |
| GET | /api/v1/startup/maker/news/files/transform/{fileId} | MakerNewsFileApiController.transformGet | 변환 조회 |
| POST | /api/v1/startup/maker/news/files/transform/{fileId} | MakerNewsFileApiController.transformPost | 변환 실행 |
| PUT | /api/v1/startup/maker/news/files/{prevFileId} | MakerNewsFileApiController.replace | 교체 |
| GET | /api/v1/startup/maker/{corpNo}/notice/count | NoticeApiController.count | 알림 수 |
| GET | /api/v1/startup/maker/notices | NoticeApiController.all | 알림 목록 |
| POST | /api/v1/startup/maker/notice/campaign/open | NoticeApiController.campaignOpen | 캠페인 오픈 알림 |
| GET | /api/v1/startup/maker/terms/{corpNo}/isPreviousStartupAdmin | MakerTermsApiController.previous | 이전 스타트업 운영자 여부 |
| POST | /api/v1/startup/maker/admin/list | MakerPageAdminApiController.listPost | admin 페이지 목록 |
| GET | /api/v1/startup/maker/admin/list | MakerPageAdminApiController.listGet | admin 페이지 목록 |
| GET | /api/v1/startup/maker/admin/{corpNo}/group | MakerPageAdminApiController.group | 그룹 |
| GET | /api/v1/startup/maker/admin/{corpNo}/fundings | MakerPageAdminApiController.fundings | 펀딩 목록 |
| GET | /api/v1/startup/maker/admin/{corpNo}/stores | MakerPageAdminApiController.stores | 스토어 목록 |
| GET | /api/v1/startup/maker/admin/{corpNo}/teammember/list | MakerPageAdminApiController.team | 팀멤버 |
| GET | /api/v1/startup/irRequest/feedback/{feedbackNo} | IrRequestApiController.feedback | IR 피드백 |
| POST | /api/v1/startup/irRequest/feedback/create | IrRequestApiController.feedbackCreate | IR 피드백 생성 |
| GET | /api/v1/startup/maker/issue/{corpNo}/list | MakerIssueApiController.list | 이슈 목록 |
| GET | /api/v1/startup/maker/issue/{corpNo}/issues | MakerIssueApiController.issues | 이슈들 |
| GET | /api/v1/startup/maker/issue/issueNo/{issueNo} | MakerIssueApiController.detail | 이슈 상세 |
| GET | /api/v1/startup/maker/issue/issueLogs/{issueNo} | MakerIssueApiController.logs | 이슈 로그 |
| POST | /api/v1/startup/maker/issue/add | MakerIssueApiController.add | 추가 |
| POST | /api/v1/startup/maker/issue/update | MakerIssueApiController.update | 수정 |
| POST | /api/v1/startup/maker/issue/delete | MakerIssueApiController.delete | 삭제 |
| GET | /api/v1/startup/projects | ProjectController.getProjects | 프로젝트 조회 (공용) |
| POST | /api/v1/startup/maker/adminRequest/register | AdminRequestApiController.register | 운영자 요청 |
| GET | /api/v1/startup/maker/adminRequest/{corpNo}/history | AdminRequestApiController.history | 이력 |
| POST | /api/v1/startup/maker/adminRequest/revert | AdminRequestApiController.revert | 되돌리기 |
| POST | /api/v1/startup/maker/adminRequest/user | AdminRequestApiController.user | 사용자 기반 |
| GET | /api/v1/startup/maker/satisfaction/{corpNo}/summation | MakerSatisfactionApiController.summation | 만족도 요약 |
| GET | /api/v1/startup/common/codeMap | CommonApiController.codeMap | 공통 코드맵 |
| GET | /api/v1/startup/common/questionExampleList | CommonApiController.qExamples | 질문 예시 |
| GET | /api/v1/startup/common/currentBannerList | CommonApiController.banners | 현재 배너 |
| GET | /api/v1/startup/wish/following/maker | WishApiController.followingMaker | 팔로잉 메이커 위시 |
| GET | /api/v1/startup/wish/project/endingsoon | WishApiController.endingSoon | 마감임박 |
| GET | /api/v1/startup/wish/following/maker/contentsId | WishApiController.contentsId | 컨텐츠ID |
| GET | /api/v1/startup/wish/findWishes | WishApiController.findWishes | 위시 조회 |
| GET | /api/v1/startup/wish/recommend/maker | WishApiController.recommendMaker | 추천 메이커 |
| GET | /api/v1/startup/wish/following/maker/news | WishApiController.followingMakerNews | 팔로우 메이커 뉴스 |
| GET | /api/v1/startup/wish/project/user | WishApiController.projectUser | 프로젝트 사용자 위시 |
| POST | /api/v1/startup/wish/following/main-maker-nos | WishApiController.followingMainMakerNos | 메인 메이커 번호 |
| GET | /api/v1/startup/wish | WishApiController.list | 위시 전체 |
| GET | /api/v1/startup/wish/integrate | WishApiController.integrate | 통합 위시 |
| GET | /api/v1/startup/my/wish/integration | WishSessionController.integration | 내 위시 통합 |
| GET | /api/v1/startup/maker/feed/follow/news/{id} | MakerFeedApiController.news | 피드 뉴스 |
| POST | /api/v1/startup/maker/feed/card/list | MakerFeedApiController.cardList | 피드 카드 |
| POST | /api/v1/startup/maker/feed/follow/news | MakerFeedApiController.followNews | 피드 팔로우 뉴스 |
| POST | /api/v1/startup/feeds/contents | FeedContentsApiController.create | 피드 콘텐츠 생성 |
| GET | /api/v1/startup/feeds/contents/{contentId} | FeedContentsApiController.get | 피드 콘텐츠 상세 |
| GET | /api/v1/startup/feeds/contents | FeedContentsApiController.list | 목록 |
| PUT | /api/v1/startup/feeds/contents/{contentId} | FeedContentsApiController.update | 수정 |
| DELETE | /api/v1/startup/feeds/contents/{contentId} | FeedContentsApiController.delete | 삭제 |
| GET | /api/v1/startup/feeds/contents/all | FeedContentsApiController.all | 전체 |
| POST | /api/v1/startup/feeds/contents/file | FeedContentsFileApiController.upload | 피드 파일 |
| GET | /api/v1/startup/feeds/contents/file/presigned | FeedContentsFileApiController.presigned | presigned URL |
| DELETE | /api/v1/startup/feeds/contents/file/delete | FeedContentsFileApiController.delete | 파일 삭제 |

## 주요 API 상세 분석

### 1) POST /api/v1/startup/maker/interconnect/funding (펀딩 연동 메이커 자동등록)
- `src/main/java/com/wadiz/api/startup/domain/registration/controller/MakerInterconnectApiController.java:34`
- 입력 DTO `FundingInterconnectDto.Request`: `corpName`, `makerName`, `globalMakerName`, `businessRegNumber`, `corporationType`, `countryCode`, `registerUserId`, `projectId`.
- 처리 흐름:
  1. `MakerRegistrationService.registrationByFundingAndStore(...)` — Corporation upsert + Super Admin 생성(`MakerSuperAdminRequestDto`, `AdminRequestRoute.REWARD`).
  2. `projectId` 존재 시 `CompanyRepository.findByCorpNo(originCorpNo)` 로 ES(`fn-company-active`)에서 `mainCorpNo` 탐색 → `service.upsertProjectCorporation("FUNDING", projectId, corpNoForSearch, originCorpNo)` 로 `ProjectCorporation` 매핑 upsert.
  3. `immediatelyElasticRegistration(corpNo, REWARD, projectId)` — ES 즉시 색인 요청(메이커 indexer로 HTTP 호출).
  4. 예외시 `slackTopic.toFinanceExceptionManaging(...)` 로 슬랙 알림.
- DB: `Corporation`, `ProjectCorporation(ProjectType/ProjectNo unique)`, `CorporationMember`, `AdminRequest`, `CorporationInterested`.
- 외부: ES (`fn-company-active` Elasticsearch), Indexer (`wadiz.indexer.maker.url`), Slack Webhook.

### 2) GET /api/v1/startup/maker/{corpNo}
- `src/main/java/com/wadiz/api/startup/domain/maker/controller/MakerApiController.java:70`
- 처리: `MakerService.getMakerDetail(corpNo)` — JPA `Corporation` + `ProjectCorporation` + `CorporationMember(SUPER ADMIN)` + ES 문서(`Company`, `Funding`) 결합.
- DB/인덱스: JPA 테이블 `Corporation`, `CorporationProperty`, `CorporationLogoMapping`, `CorporationInterested`, `CorporationConnect`, `CorporationCampaignMapping`; ES `fn-company-active`, `fn-funding-active`.

### 3) GET /api/v1/startup/maker/third-party
- `MakerApiController.java:39`
- 처리: `MakerMapper.selectThirdPartyProvisionMakers`, `selectCountThirdPartyProvisionMakers`.
- DB SQL (`src/main/resources/mapper/wadiz/maker-mapper.xml:4`): `ProjectCorporation` ⋈ `Campaign`(FUNDING, IsOpen, WhenHoldTo+100일 미초과) ∪ `wadiz_store.project`(ON_SALE) ⋈ `Corporation` 조합으로 유효 메이커 이름 목록. LIMIT offset, limit 페이징.
- 용도: 3rd party(ex: 외부 파트너)에 노출할 메이커 목록 — "공개 가능한 상태의 메이커"만 추출.

### 4) POST /api/v1/startup/maker/studio/{corpNo}/news
- `src/main/java/com/wadiz/api/startup/domain/news/controller/MakerNewsStudioApiController.java:53`
- 입력: `MakerNewsDto.Create` (title, content, category, isUsePush, isAd, pushContentsBody, registerUserId).
- 처리:
  - `MakerNewsService.create(corpNo, create)` → `MakerNews` Entity (+ `MakerNewsFileMapping`) 저장, 상태 `CONFIRM`/`TEMPORARY`.
  - `PushService.isAvailable(corpNo)` 체크 후 가능시 `PushService.sendMakerNewsPush(corpNo, newsId, body, isAd, "${wadiz.url}/web/maker/detail/{corpNo}/makerNews/detail/{newsId}", registerUserId)` 푸시 발송 → Wadiz push 서버 HTTP.
  - 예외 시 push만 실패 처리.
- DB: `MakerNews`, `MakerNewsFileMapping`, `MakerNewsRestrictionWordPostReason`.

### 5) GET /api/v1/startup/maker/follow/user (암호화 userId)
- `src/main/java/com/wadiz/api/startup/domain/follow/controller/MakerFollowApiController.java:45`
- 입력: Header `encUserId` — `WadizCryptoUtil.decryptUserIdForLong(encUserId)` 로 복호화, `wadiz-language` 헤더도 지원.
- 처리: `MakerFollowService.getMyWadizMakerFollow(request)` — `MakerFollow` 테이블 + `Corporation` + 언어별 `CorporationLanguage` 조인으로 MyWadiz 영역에 노출할 팔로우 메이커 카드/리스트 구성.
- `POST /follow/check` 는 userIdList 최대 5000 건 제한 (`checkFollowedUsersWithDate`).

### 6) GET /api/v1/startup/collection/keyword/{keyword}
- `src/main/java/com/wadiz/api/startup/domain/collection/controller/StartupCollectionApiController.java:46`
- 처리: `StartupCollectionService.findCollectionByKeyword(keyword)` — `StartupCollection` (Entity) 단건 + 매핑된 기업/카드 구성.
- 매핑 API(`/collection/{collectionNo}/mapping/create|delete|bulk|confirm`)는 운영/백오피스에서 사용.

### 7) GET /api/v1/startup/maker/satisfaction/{corpNo}/summation
- `src/main/java/com/wadiz/api/startup/domain/satisfaction/controller/MakerSatisfactionApiController.java:17`
- 처리: `SatisfactionService.getSatisfactionSummation(request)` — 다른 서비스(com.wadiz.api.reward)의 rewards/satisfactions/aggregates 를 내부 호출하여 집계. 메이커(기업) 기준 만족도 요약.

### 8) POST /api/v1/startup/maker/{corpNo}/push/credit/issuance
- `src/main/java/com/wadiz/api/startup/domain/push/controller/PushApiController.java:59`
- 처리: 메이커에게 푸시 크레딧 발행(유료 푸시 인벤토리). `PushService` 가 내부 로직 수행 후 notification 서버에 연계.

### 9) POST /api/v1/startup/maker/vote
- `src/main/java/com/wadiz/api/startup/domain/event/controller/MakerEventApiController.java:32`
- Wadiz 어워드 투표: `MakerAwardee`, `MakerVote` Entity에 투표 기록. 기간(`wadiz.award.period.start/end`)을 yml 로 관리.

### 10) POST /api/v1/startup/inquiry/create
- `src/main/java/com/wadiz/api/startup/domain/inquiry/controller/CorporationInquiryController.java:21`
- 처리: 기업 상세 페이지에서 투자/제휴 등 문의 등록 → `CorporationInquiry` Entity, 기본 답변 템플릿/상태 관리.

## DB 스키마 요약
### JPA 주요 테이블 (모두 `@Entity`, `@Table(name=...)` 지정)
| 테이블 | 용도 |
|-------|------|
| `Corporation` | 메이커(기업) 마스터 (corpNo, kedId, businessRegNumber, countryCode, name/displayName, representativeName 등) |
| `CorporationProperty` | 기업 속성(스튜디오 기본 정보) |
| `CorporationContract` | 기업 계약 |
| `CorporationInterested` | 관심 기업 |
| `CorporationConnect` | 기업 연결 (투자/제휴) |
| `CorporationCampaignMapping` | 기업-캠페인 매핑 |
| `CorporationLogoMapping` | 기업 로고 |
| `CorporationLanguage` | 기업 다국어(이름/설명) |
| `CorporationIRPreview` | IR 미리보기 |
| `CorporationTech` | 기업 기술 정보 |
| `CorporationFAQ` | 기업 FAQ |
| `CorporationBusinessCategory` | 업종 카테고리 |
| `CorporationMember` | 기업 멤버(운영자) |
| `CorporationMemberEducation`, `CorporationMemberCareer` | 학력·경력 |
| `CorporationContactMobile`, `CorporationContactEmail` | 담당자 연락처 |
| `CorporationIrRequest`, `CorporationIrRequestFeedback`, `TbQuestionExampleIrRequestAnswer` | IR 요청/피드백 |
| `ProjectCorporation` | 프로젝트-메이커 매핑 (FUNDING/STORE) |
| `MakerAwardee`, `MakerVote` | 어워드/투표 |
| `MakerNews`, `MakerNewsReaction`, `MakerNewsVote`, `MakerNewsVoteMultiple`, `MakerNewsVoteMultipleUser`, `MakerNewsFileMapping`, `MakerNewsRestrictionWordPostReason` | 메이커 뉴스 & 투표 |
| `MakerNewsComment`, `MakerNewsCommentReaction` | 뉴스 댓글 |
| `MakerNotice` | 오픈 알림 수신 요청 |
| `MakerClub` | 메이커 클럽 (정책 V1/V2 기간 관리) |
| `TbBannerCommon`, `TbBannerSection`, `TbQuestion`, `TbQuestionExample`, `TbAttachFileInfo`, `TbUploadPhoto`, `TbCodeSub` | 공통 배너/질문/파일/코드 (Tb 접두) |
| `CampaignLanguage` | 외부 캠페인 다국어 (external 패키지) |

### Elasticsearch 인덱스 (`@Document(createIndex=false)`)
- `fn-funding-active` (`Funding.java`): 활성 펀딩 캠페인
- `fn-store-active` (`Store.java`): 스토어
- `fn-company-active` (`Company.java`): 기업/메이커 통합 인덱스 (mainCorpNo 포함)
- `fn-invest-active` (`Invest.java`): 투자(에쿼티)
- `fn-maker-grade` (`MakerGrade.java`): 등급
- `maker_activity_feeds-alias` (`MakerActivityFeedIndex.java`): 활동 피드

### MyBatis Mapper (`src/main/resources/mapper/wadiz/*.xml`)
- `maker-mapper.xml` — 3rd party maker 목록/카운트
- `wadizFunding-mapper.xml` / `wadizFile-mapper.xml` / `wadizUser-mapper.xml` — wadiz_db 참조 조회
- `greeting-mapper.xml`, `equityCampaign-mapper.xml`, `corporationMemberStartupAdmin-mapper.xml` — 특수 쿼리

## 외부 의존성
설정: `src/main/resources/startup.yml` (profile별 `---` 분기).
- **wadiz.api.notification** (dev `http://dev-app01:9990`) — 알림(notification-client 라이브러리).
- **wadiz.api.payment-log** (dev `http://dev-app01:9990`) — 결제 로그 (payment-log-client).
- **wadiz.api.user** (dev `http://dev-app01:9990/user`) — com.wadiz.wave.user 로 내부 호출.
- **wadiz.api.searcher** (dev `http://dev-app01:9120`) — 검색 서비스.
- **wadiz.api.relay** (dev `https://dev-service.wadiz.kr`) — 릴레이.
- **wadiz.api.funding** (dev `http://dev-app01:9990/funding`, `auth-token` JWT) — 펀딩 `POST /api/internal/wishes/users/*`.
- **wadiz.api.advertisement** (dev `http://dev-app01:9990/ad-host/wad`) — 광고.
- **wadiz.elasticsearch.makerProfile** — 메이커 프로필 ES 클러스터 (dev `192.168.1.186:9200`).
- **wadiz.indexer.maker** (dev `http://192.168.0.221:9111`) — ES 즉시 색인 트리거.
- **wadiz.eks** (dev `https://dev-platform.wadizcorp.net`) — EKS 게이트웨이(Bearer 토큰).
- **friend.talk** (dev `https://dev-platform.wadizcorp.net/friendtalk-api`) — 카카오 친구톡.
- **slack** — 슬랙 웹훅 (`slack.url.financeExceptionManaging` 등), 예외 알림.
- **bitly** (`bitly.api.url`) — 단축 URL.
- **s3** (`wadiz.funding.public.{env}`, CloudFront cdnUrl) — 이미지/파일.
- **shinhan** — 신한은행 API (cert `shb_api_test_cert2.p12`).
- **Consul Discovery** — `192.168.1.216:8500` (dev), service-name=`startup`.
- DB: `wadiz_db` master/slave, Jasypt 암호화 비밀번호.

## 특이사항
- **"MVC + 도메인 풀분리"** 혼재: `application`/`presentation` 구분이 명확치 않음. 도메인 패키지 안에 controller/service/repository/model 이 함께 존재하는 패턴.
- **오타 패키지** `excepion`(exception 의 오타)으로 `GlobalExceptionHandler` 및 핸들러가 들어있음. 변경 시 import 주의.
- **`TbXxx` 테이블**: 공통 관리 테이블은 레거시 접두사 `Tb`(TbCodeSub, TbBannerCommon, TbQuestion, TbQuestionExample, TbAttachFileInfo, TbUploadPhoto)로 존재.
- **Multi-ORM**: JPA + MyBatis + QueryDSL + ES 를 같이 사용. 같은 도메인(Corporation)도 JPA 로는 `Corporation`, ES 로는 `Company`에 저장.
- **ES 인덱스는 읽기 전용** (`createIndex=false`). 색인은 **외부 indexer 서비스**(`wadiz.indexer.maker.url`) 에 HTTP로 "immediatelyElasticUpdate" 트리거.
- **암호화 파라미터**: `encUserId` (Long으로 암호화) 를 URL/Header에 받아 `WadizCryptoUtil.decryptUserIdForLong()` 으로 복호화하는 패턴 다수.
- **보안/자격증명 평문 노출**: yml 내 내부 API 토큰(`auth-token=eyJ...`), 슬랙 hook, 신한/비틀리/S3 access key 가 평문으로 커밋되어 있음.
- **Spring Boot 2.3 + Spring Cloud Hoxton**: 세 레포 중 가장 **구버전** 스택. Eureka → Consul 로 전환 이력 (README 언급). 업그레이드 후보.
- **MakerClub 정책 V1/V2**: `wadiz.maker-club.policy.{v1,v2}.effective-until/from` yml 로 기간 분기 (2025-12-08/09 경 전환). 개발 환경에서 시간 조작 가능.
- **Elasticsearch dialect가 MySQLDialect** (mysql5 아닌 구버전, hibernate-ehcache 5.4). 변경 시 DB 테이블 호환성 주의.
- **starter-security + OAuth2 Resource Server**: JWT (RS256, `iam.pub` / `iam-live.pub` 공개키 기반) 로 인증.
- **Subproject publish** — `startup-client`/`startup-model` 은 `http://repo.wadizcorp.com/repository/libs` 에 별도 versioning 으로 publish → 다른 서비스에서 의존.
- **Request timeout 600초**(`server.mvc.async.request-timeout: 600000`) — ES/indexer 호출/대용량 쿼리 대응.
