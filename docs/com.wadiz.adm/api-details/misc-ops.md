# com.wadiz.adm — 나머지 운영 도구 컨트롤러

## 1. 기록 범위

본 문서는 `com.wadiz.adm`(Wadiz 전사 레거시 어드민, Spring 3.2 + JSP)에서 **리워드 정산/심사/코멘트/쿠폰 영역을 제외한 "나머지 운영 도구"** 컨트롤러를 다룬다. 요약 대상은 다음 카테고리다:

- 대시보드 / 메인 SPA 진입 / 퀵메뉴
- 공용 에러 페이지
- RPA(약정서 본인인증 비교)
- 단축 URL / HTML→PDF
- FTFile(첨부파일 다운로드 · 이미지 스트리밍)
- 엑셀 다운로드 히스토리
- **증권형(Startup / Corporation)** — Corporation 계열 10+, Maker 도메인, Feed 피드
- Store(신규 SPA 라우트) · Store 스크리닝 첨부 다운로드
- IP 프로그램 SPA 진입
- 레거시 오픈프로젝트 신청
- STS(Stats — 세일즈/이메일/SMS/배너)
- Message(sts/message, sts/alimtalk)
- Goal 목표관리
- Analytics / GA Source-Medium 매핑
- RiskProject(리스크 프로젝트 관리)
- 리워드 영업일 Helper API

각 파일은 `src/main/java/com/wadiz/web/<domain>/controller/*.java` 경로에 있다.

## 2. 개요

- **아키텍처**: Spring MVC + JSP. 대부분 `@Controller` + `ModelAndView`("… 페이지" 이동) 또는 `@Controller` + `@ResponseBody` + ajax(JSON) 혼용.
- **세션**: `WEBSessionUtil.getUserId()` 로 로그인 사용자 식별. 퀵메뉴 이미지·엑셀 다운로드 로그·Store 첨부 다운로드 등에서 사용.
- **SPA 진입점 패턴**: `/home`, `/manage/home/quickMenu`, `/ip/programs/**`, `/app/store/**` 등 JSP `"front/main"` 뷰 한 장에 매핑해 CRA SPA를 hosting. SPA 라우트가 어드민 본 애플리케이션에 흡수되는 과도기 구조.
- **증권형 코드 분류**: `com.wadiz.web.startup.*` 는 Wadiz 증권형(Equity) 투자 플랫폼 어드민. `Corporation*` 은 발행회사(피투자 기업) 관리 계열, `Maker*` 은 메이커(프로젝트 운영자) 계열, `feed/*` 는 피드 콘텐츠(증권형 커뮤니케이션) 계열.
- **URL prefix 정책**:
  - `/startup/corporation/*` — Corporation 관리 본체
  - `/startup/corporationNews/*` · `/startup/corporationContract/*` · `/startup/corporationInvestor/*` · `/startup/corporationMember/*` · `/startup/irRequest/*` — 각 하위 계열
  - `/startup/inquiry/*`, `/startup/collections`, `/startup/common/*`
  - `/corporation/contact`, `/maker/*`, `/maker/issue`, `/feeds/contents*`
- **응답 래퍼**:
  - 증권형 corp·contact: `WCommonAjaxResDto`(성공/실패 공용 JSON)
  - 메이커 도메인: `MakerApiResponse<T>`(success/fail)
  - 리워드 Helper: `ResponseWrapper<T>`(리워드 API 쪽 공용 래퍼)
- **엑셀 다운로드 히스토리**: `AdminExcelDownloadLogApiController` 가 "어떤 어드민이, 몇 건, 어떤 사유, 어느 메뉴에서, 비밀번호 zip 포함해 다운로드했는가"를 기록. GDPR/내부통제용 trail.

## 3. 컨트롤러 목록 (도메인별)

| 도메인 | 컨트롤러 | URL Prefix | 역할 |
|---|---|---|---|
| Dashboard | `WEBDashboardController` | `/dashboard` | 투자·리워드 심사/인증 처리 대기 카운트 대시 |
| Home(SPA) | `HomeViewController`, `manageHomeViewController`, `IpProgramViewController`, `StoreViewController` | `/home`, `/manage/home/quickMenu`, `/ip/programs*`, `/app/store/**` | CRA SPA 진입 (JSP `front/main` 1장) |
| Main Quickmenu | `MainController` | `/manage/home` | 퀵메뉴·아이콘·뱃지 CRUD (v1/v2/v3/v4) |
| 공용 | `ErrorPageController` | `/common/errorMessage` | 에러 메시지 페이지 |
| RPA | `RPAController` | `reward/campaign/popCampaignMakerInfo` | 메이커 본인인증/약정서 비교 팝업 |
| URL | `WadizUrlController` | `/url` | 단축URL CRUD + HTML→PDF 변환 다운로드 |
| FTFile | `WEBFTFileController` | `ftcampaign/download`, `imgView/*` | 첨부 단일/다중(zip) 다운로드, 이미지 스트리밍 |
| Excel 로그 | `AdminExcelDownloadLogApiController` | `/api/excel-download-logs/` | 엑셀 다운로드 히스토리 저장/조회 |
| Startup 공용 | `CommonApiController` | `/startup/common/*` | 코드맵(공용 코드 맵) 조회 |
| Corporation | `CorporationApiController` | `/startup/corporation/*` | 기업(발행회사) 관리 본체 |
| Corp News | `CorporationNewsApiController` | `/startup/corporationNews/*` | 기업 새소식 CRUD |
| Corp Contract | `CorporationContractApiController` | `/startup/corporationContract/*` | 기업 계약/반려 처리 |
| Corp Investor | `CorporationInvestorApiController` | `/startup/corporationInvestor/*` | 기업 임직원 투자자 심사 |
| Corp IrRequest | `CorporationIrRequestApiController` | `/startup/irRequest/*` | 온라인 IR 신청 |
| Corp AdminRequest | `CorporationAdminRequestApiController` | `/startup/corporationMember/*` | 기업 관리자(멤버) 신청 |
| Corp Inquiry | `CorporationInquiryController` | `/startup/inquiry/*` | 기업 투자 문의 |
| Corp Contact | `CorporationContactController` | `/corporation/contact` | 기업 담당자 연락처 (토큰·엑셀 포함) |
| StartupCollection | `StartupCollectionController` | `/startup/collections` | 기업 큐레이션(컬렉션) |
| Maker Page | `MakerPageController` | `/maker` | 메이커(스튜디오) 리스트/상세 |
| Maker Issue | `MakerIssueController` | `/maker/issue` | 메이커 이슈 CRUD |
| Maker Admin | `MakerAdminController` | `/maker/{corpNo}/admin` | 메이커 슈퍼관리자 승인 반려 |
| Maker TeamMember | `MakerTeamMemberController` | `/maker/{corpNo}/teammember` | 메이커 팀멤버 리스트 |
| Feed | `FeedContentsApiController` | `/feeds/contents` | 피드 콘텐츠 CRUD |
| FeedFile | `FeedContentsFileApiController` | `/feeds/contents/file` | 피드 첨부 presigned 업로드 |
| Store | `StoreViewController`, `StoreScreeningRequirementController` | `/app/store/**`, `/store/attachments/*` | Store SPA 진입 + 첨부 레거시 다운로드 |
| Legacy | `WEBLRequestController` | `legacy/requestOpenProjectList` | 구 오픈프로젝트 신청 |
| STS | `WEBStatsController`, `MessageController` | `sts/*` | 매출·이메일·SMS·배너·알림톡 통계 |
| Goal | `GoalManageController` | `/goalmanager/*` | 운영 목표/KPI 관리 |
| Analytics | `GaMappingController` | `/analytics/ga/mapping` | GA Source/Medium 매핑 |
| Risk | `RiskProjectController` | `/riskproject/*` | 리스크 프로젝트 관리 |
| Reward helper | `RewardBusinessDayApiController` | `/reward/api/business-days` | 영업일 조회 |

## 4. Dashboard & Home & SPA 진입

### 4.1 `WEBDashboardController`
경로: `src/main/java/com/wadiz/web/dashboard/controller/WEBDashboardController.java`

- `dashboard.java:43` `GET /dashboard` → JSP `dashboard`. 투자(Equity)와 리워드 심사 큐를 한 페이지에서 집계한다.
- 인증 todo: `PA002`(개인투자 진위확인), `PA004/NP200`(적격회원), `PA005/NP300`(전문회원), `CA005`(법인 전문) — `DashboardService.getPersonalAuthTodoCnt`/`_INCOME`, `getCorpAuthTodoCnt_INCOME`, `getCorpAuthRenewalTodoCnt_INCOME`.
- 결제 실패/계좌 입고불가: `getEquityPaymentCancelFailCnt`, `getAccountCheckFailCnt`.
- 투자 새소식/온라인 IR 검토: `getInvestCampaignConfirmNews`, `getInvestCampaignStatus("D100000000")`.
- 리워드 1·2차 심사 대기: `CampaignSearch` + `RewardCampaignService.getQty` 로 건수와 딥링크(`/web/progress/campaignList?campaignScreeningStatus=…`) 동시 바인딩.
- Equity 펀딩 준비 승인 대기: `EquityStage.PREPARING_ATTACHMENT`, `PREPARING_COREINFO` + 오늘 오픈 예정 수(`getEquityCampaignTodayOpenCount`).
- `EquityAssignService.getEquityAssignDashboard()` 로 Equity 배정 대시보드 스냅샷까지 주입.

### 4.2 `HomeViewController` / `manageHomeViewController` / `IpProgramViewController` / `StoreViewController`
경로: `web/home/controller/HomeViewController.java:9`, `web/manage/home/controller/manageHomeViewController.java:9`, `web/ip/program/controller/IpProgramViewController.java:9`, `web/store/controller/StoreViewController.java:9`

- 공통 패턴: SPA 라우트를 모두 JSP `"front/main"` 하나에 묶어 React(CRA/Vite) 번들이 `location.pathname` 으로 라우팅.
- `HomeViewController` — `GET /home`.
- `manageHomeViewController` — `GET /manage/home/quickMenu` (클래스명 소문자 시작 = 원본 그대로의 Java 컨벤션 위반).
- `IpProgramViewController` — `GET /ip/programs`, `GET /ip/programs/editor/{id}` (IP 프로그램 SPA).
- `StoreViewController` — `/app/store/projects`, `/app/store/sales[/{orderNumber}]`, `/app/store/settlement_billing|accounting|maker`, `/app/store/curation`, `/app/store/sellableStockSyncs`, `/app/store/promotion[/detail/{PROMOTION_NUMBER}]`, `/app/store/product-price`, `/app/store/satisfactions` 등 14개 경로를 단일 뷰로.

### 4.3 `ErrorPageController`
경로: `web/common/controller/ErrorPageController.java:10`

- `GET /common/errorMessage?errorMessage=…` → JSP `common/errorMessage`. 단순 메시지 릴레이 용도로, 다른 컨트롤러가 `redirect` 후 알림을 흘리기 위한 landing.

### 4.4 `MainController` (Quickmenu v1~v4)
경로: `web/main/controller/MainController.java:25`, prefix `/manage/home`

- **v1** `api/v1/main/quickmenu` GET/POST/DELETE — `QuickMenu` 리스트 저장·조회·단건 삭제.
- **v2** `api/v2/main/quickmenu` GET/POST + `api/v2/main/quickmenu/types` GET — `QuickMenuV2`.
- **v3** `api/v3/quickmenu/admin` GET/POST(`@Valid QuickMenuAdmin`) — @Valid 검증.
- **v4** `api/v4/quickmenu/admin` GET/POST(`@RequestBody Object`) — 스키마 미정 fallback 버전.
- 아이콘/뱃지: `api/v1/main/icon/quickmenu`, `api/v1/main/icon/badge` (MultipartFile 업로드 + DELETE).
- `@ExceptionHandler(MethodArgumentNotValidException.class)` 로 `{success, code: "VALIDATION_ERROR", errors:[{field,message}]}` JSON 반환.

## 5. RPA / File / Excel / URL

### 5.1 `RPAController`
경로: `web/rpa/controller/RPAController.java:40`

- `GET reward/campaign/popCampaignMakerInfo?campaignId=` → `rpa/maker-info` JSP.
- 리워드 캠페인 **심사 단계의 메이커 정보 비교** 팝업. 세 종류 약정서를 함께 로드: `AgreementType.POA`(위임장), `JRPOA`(주주명부 위임), `JGA`(양도양수).
- `rpaService.getCompareAgreementData` 가 약정서·현재 입력값을 diff 하여 UI에서 하이라이트.
- `PersonalVerificationService.get(STUDIO_REPRESENTATIVE, campaignId)` 로 대표자 본인인증 결과 조회. "본인인증 생략"(`isPassPersonalVerification`) 인 경우 직전 승인된 대표자(`getRecentApprovalRepresentativeByCorpType`) 정보와 비교.
- `ContractCredentialsVerificationService` 로 사업자등록증(`BUSINESS_LICENSE`)·통장사본(`COPY_OF_BANKBOOK`) 검증 정보 주입.
- `MemoService.getByIdAndCategory(campaignId, "AGREEMENT_SCREENING")` 로 약정서 심사 메모 표시.

### 5.2 `WadizUrlController`
경로: `web/url/controller/WadizUrlController.java:23`, prefix `/url`

- `GET management` → `url/wadizUrlManagement` JSP.
- `POST ajaxCreateShortenUrl` — `{longUrl, hash}` → `{success}`.
- `GET/PUT/DELETE ajaxGetShortenUrl/{targetHash}` — 단축 URL 조회·갱신·삭제.
- `POST downloadPdf` — `MultipartFile(targetFile)` 업로드 → `HtmlToPdfConverter.convert` → `tempPdf` 로 저장 후 `ModelAndView("downloadFile", downloadFileInfo)` 으로 내려주기. `test_{millis}.pdf` 파일명, `Files.createTempFile` + `deleteOnExit`.

### 5.3 `WEBFTFileController` (파일 다운로드)
경로: `web/ftfile/controller/WEBFTFileController.java:43`

- `ftcampaign/download?url=…,…&requestFileName=…,…&name=…&requestFileType=…`
  - `realPath.length == 1` → 단일 파일 다운로드(`fullPath ^ pathName` 기묘한 구분자).
  - `realPath.length > 1` → `CompressionUtil.zip` 으로 `wadiz.zip` 또는 `{name}_자료관리.zip` 생성 후 다운로드.
  - GET 요청일 때만 UTF-8 URL 인코딩 적용.
- `imgView/attachFile?attachFileId=` — `FTFileService.getAttachFileByAttachFileId` 로 `FTUploadFileInfo.realPath` 획득 → 파일을 읽어 `HttpServletResponse.getOutputStream()` 로 직접 서빙(1KB 버퍼, `ByteArrayOutputStream` 경유).
- `imgView/photoFile?photoId=` — 사진 파일 동일 로직.
- 2015년 작성된 레거시 코드(주석에 `박주리, 2015.11.27`). try-finally 이중 close, `request.getMethod() == "GET"` 같은 문자열 비교 버그성 패턴 잔존.

### 5.4 `AdminExcelDownloadLogApiController`
경로: `web/excel/controller/AdminExcelDownloadLogApiController.java:17`, prefix `/api/excel-download-logs/`

- `POST ""` — 본체 `{usagePeriod, reason, password, menu}` 를 저장. `WEBSessionUtil.getUserId()` 를 서버에서 주입해 위·변조 방지.
- `GET ""` — `@PathVariable int seq` (주의: 현재 코드는 `value=""` + `@PathVariable` 조합이라 실제 바인딩이 안 됨. 버그성 잔재).
- 응답은 `ResponseWrapper<AdminExcelDownloadLog>`.
- 용도: 엑셀 zip 비밀번호·사유·사용 기간을 포함한 감사 로그. 개인정보 수출 trail.

## 6. Store

### 6.1 `StoreViewController` — 상단 참조.
### 6.2 `StoreScreeningRequirementController`
경로: `web/store/controller/StoreScreeningRequirementController.java:25`

- `GET /store/attachments/{attachmentKey}/legacy-system/download`
  - `StoreClient.getAttachmentMetadata(attachmentKey)` 로 (`originName`, `filePath`) 메타 조회.
  - 실패 → `400 BAD_REQUEST`, 메타 OK 후 `StorageService.get(userId, filePath)` 실패 → `404 NOT_FOUND`.
  - 성공 시 `Content-Disposition: attachment;filename={enc};filename*= UTF-8''{enc}` 헤더 + `application/octet-stream` + `InputStreamResource` 스트리밍.
- Store(w-store, 신규 스토어 플랫폼) 쪽 스크리닝 첨부를 **레거시 어드민 경로로 다운로드**해 주는 브리지 역할.

## 7. Startup (증권형) — Corporation 계열 상세

이 섹션은 본 문서의 핵심이다. `com.wadiz.web.startup.*` 전체는 Wadiz 증권형 투자(Equity)의 발행기업·메이커·피드 관리 UI용 컨트롤러군이다. 모든 엔드포인트 기본값은 `ModelAndView`(JSP) + 부분적으로 `@ResponseBody` ajax. 응답 JSON 래퍼는 대부분 `WCommonAjaxResDto`(`.toJson()`) 또는 `MakerApiResponse`.

### 7.1 `CorporationApiController` (핵심)
경로: `web/startup/controller/CorporationApiController.java:34`, prefix `/startup/corporation/*`

- `/list` (`CorporationApiController.java:58`) — `StartupSearchOption` 으로 기업 리스트 검색. 검색조건 없으면 빈 페이지네이션만, 있으면 `service.selectList` + `service.countList`. JSP `equity/business/corp/startup`.
- `/view/manageDetails/corpNo/{corpNo}` (:78) — 관리상세 모달. `corporation` + `connect`(커넥트 정보).
- `/view/corporationModal/corpNo/{corpNo}` (:87) — 기업정보 모달(`getAllInfo`).
- `/view/studioModal/corpNo/{corpNo}` (:95) — 스튜디오(메이커 페이지) 모달 + `EquityFileInfo.CORPORATION_IR` + `findIR`.
- `/update/corpNo/{corpNo}` (:108) — 본체 `Corporation` 업데이트. `WCommonAjaxResDto.setFailMessage` 로 실패 메시지.
- `/connect/corpNo/{corpNo}` (:122) — 기업 커넥트 on/off 개별.
- `/download/excel` (:135) — 기업 리스트 엑셀.
- `/exposure/all` (:156), `/unExposure/all` (:170) — 노출/비노출 일괄.
- `/connect/all` (:184), `/disconnect/all` (:199) — 커넥트 일괄 on/off.
- `/getNewsScraping` (:218) — `EquityNewsKeywordService` + `EquityJandiSender` 연계. 뉴스 스크래핑 키워드 관리 / 잔디 알림.
- `/api/{corpNo}` GET (:251) — `StartupCorporationApiAdapter` 를 통해 외부 API 호환 형식으로 단건 조회. 타 서비스(Equity/IR) 연동용.

### 7.2 `CorporationContactController`
경로: `web/startup/controller/CorporationContactController.java:41`, prefix `/corporation/contact`

- `/detail/corpNo` (:55) / `/corpNo/{corpNo}/no/{no}` (:82) — 담당자 리스트/단건 JSON.
- `/modify` (:110), `/create` (:142) — 담당자 수정·등록. 변경 시 token 이메일 보냄.
- `/create/token` (:177), `/check/token` (:185) — 담당자 확인용 이메일 토큰 생성/검증.
- `/popContact` (:199) — 팝업.
- `/corpNo/{corpNo}/no/{no}` (:224) / `/corpNo/{corpNo}/view/create` (:246) — 상세·신규 페이지(JSP).
- `/downloadExcel` (:366) — 담당자 엑셀.

532라인으로 Contact 관련 로직의 허브. 토큰 이메일 재전송, 담당자 중복 확인, 엑셀 출력 등이 한 파일에 집약.

### 7.3 `CorporationNewsApiController`
경로: `web/startup/controller/CorporationNewsApiController.java:19`, prefix `/startup/corporationNews/*`

- `/view/newsModal/corpNo/{corpNo}` (:27) — 새소식 목록 모달.
- `/post/corpNo/{corpNo}` (:37) — 새소식 등록/수정 통합.
- `/delete/corpNo/{corpNo}/seq/{seq}` (:51) — 단건 삭제.

### 7.4 `CorporationContractApiController`
경로: `web/startup/controller/CorporationContractApiController.java:16`, prefix `/startup/corporationContract/*`

- `/view/contractModal/corpNo/{corpNo}` (:21) — 계약 상태 모달.
- `/view/rejectModal/contractNo/{contractNo}` (:30) — 반려 사유 모달.
- `POST /update/contractStatus` (:38) — 계약 상태 변경(승인·반려 등).

### 7.5 `CorporationInvestorApiController`
경로: `web/startup/controller/CorporationInvestorApiController.java:22`, prefix `/startup/corporationInvestor/*`

- `/list` (:26), `/update/status` (:40) — 임직원 투자자 리스트/심사 상태 변경.
- `/view/rejectModal/investorNo/{investorNo}` (:53), `/view/updateReasonModal/.../{investorNo}` (:60) — 반려/정정사유 모달.
- `/view/cardPhotoModal/investorNo/{investorNo}` (:68) — 명함 사진 모달.
- `/view/addCorpInvestorModal` (:76), `/add` (:83) — 기업 임직원 투자자 수동 추가.
- `/download/excel` (:97) — 엑셀.

### 7.6 `CorporationIrRequestApiController`
경로: `web/startup/controller/CorporationIrRequestApiController.java:24`, prefix `/startup/irRequest/*`

- `/list` (:29) — 온라인 IR 신청 목록.
- `/view/updateReasonModal/reqNo/{reqNo}` (:42) — 정정 사유 모달.
- `/download/excel` (:49) — 엑셀.

### 7.7 `CorporationAdminRequestApiController`
경로: `web/startup/controller/CorporationAdminRequestApiController.java:15`, prefix `/startup/corporationMember/*`

- `/view/memberModal/corpNo/{corpNo}` (:20) — 기업 관리자(멤버) 리스트.
- `/view/corporationMemberRejectModal/reqNo/{reqNo}` (:30), `/view/corporationMemberCancelModal/reqNo/{reqNo}` (:37), `/view/corporationMemberReasonModal/seq/{seq}` (:44) — 반려/취소/사유 모달.
- `/view/nameCardModal/reqNo/{reqNo}` (:51), `/view/businessRegPhotoModal/reqNo/{reqNo}` (:58) — 명함·사업자등록증 사진.
- `/update/status` (:66) — 상태 변경.
- `POST /alarm/businessFile` (:80) — 사업자 파일 알림 발송.

### 7.8 `CorporationInquiryController`
경로: `web/startup/controller/CorporationInquiryController.java:27`, prefix `/startup/inquiry/*`

- `/list` (:32) — 기업 투자 문의 목록.
- `/download/excel` (:50) — 엑셀.

### 7.9 `StartupCollectionController` (큐레이션)
경로: `web/startup/controller/StartupCollectionController.java:21`, prefix `/startup/collections`

- `""` (:26) — 컬렉션 리스트.
- `/{collectionNo}` (:61), `/api/{collectionNo}` (:72) — JSP 상세 / JSON 상세.
- `/{collectionNo}/modify` (:84) — 수정.
- `/add` GET·POST (:96, :103) — 신규 컬렉션.
- `/{collectionNo}/corporation/{corpNo}/add` (:118), `/mapping/{collectionMappingNo}/remove` (:132) — 단건 편집.
- `/{collectionNo}/corporation/add/confirm` (:146), `/{collectionNo}/corporation/add/bulk` (:160), `/{collectionNo}/corporation/remove/bulk` (:175) — 엑셀/벌크 편집.

### 7.10 `CommonApiController`
경로: `web/startup/controller/CommonApiController.java:15`, prefix `/startup/common/*`

- `/codeMap` (:19) — 증권형 공용 코드맵(드롭다운/뱃지 라벨용) JSON.

### 7.11 Maker 도메인 — `MakerPageController` / `MakerIssueController` / `MakerAdminController` / `MakerTeamMemberController`

`MakerPageController` (`web/startup/domain/maker/controller/MakerPageController.java:27`, prefix `/maker`):
- `/list` GET·POST (:38, :52) — 메이커 리스트 검색.
- `/{corpNo}` (:74) — 메이커 상세. `/group` (:88) 는 그룹.
- `/{corpNo}/stores` (:102), `/{corpNo}/fundings` (:118), `/{corpNo}/fundingsoon` (:136) — 스토어·진행 펀딩·오픈예정 펀딩 목록.

`MakerIssueController` (`web/startup/domain/maker/controller/MakerIssueController.java:27`, prefix `/maker/issue`):
- `/issueNo/{issueNo}` (:37), `/{corpNo}/issues` (:58), `/issueLogs/{issueNo}` (:80) — 단건·목록·이력.
- `/add` (:101), `/update` (:122), `/delete` (:143) — CRUD.

`MakerAdminController` (`web/startup/domain/maker/controller/MakerAdminController.java:23`, prefix `/maker/{corpNo}/admin`):
- `/request/history` GET (:30) — 슈퍼관리자 승인 요청 이력.
- `/request/revert` POST (:46) — 승인 반려. `WEBSessionUtil.getUserId()` 를 `updateUserId` 에 주입.

`MakerTeamMemberController` (`web/startup/domain/maker/controller/MakerTeamMemberController.java:24`, prefix `/maker/{corpNo}/teammember`):
- `/list` (:30) — 팀 멤버 리스트. `MakerApiResponse` 래핑.

### 7.12 Feed 도메인 — `FeedContentsApiController` / `FeedContentsFileApiController`

`FeedContentsApiController` (`web/startup/domain/feed/controller/FeedContentsApiController.java:19`, prefix `/feeds/contents`):
- POST `""` (:26) · GET `/{contentId}` (:34) · GET `""` (:41) · PUT `/{contentId}` (:56) · DELETE `/{contentId}` (:64) — 피드 콘텐츠 완전 CRUD.

`FeedContentsFileApiController` (`web/startup/domain/feed/controller/FeedContentsFileApiController.java:17`, prefix `/feeds/contents/file`):
- `/presigned` GET (:24) — S3 presigned URL 생성.
- `/delete` POST (:31) — 첨부 삭제.

## 8. Legacy / STS / Goal / Analytics / Risk / Reward helper

### 8.1 `WEBLRequestController` (레거시 오픈프로젝트)
경로: `web/legacy/controller/WEBLRequestController.java:38`

- `legacy/requestOpenProjectList` (:54) — 구 "프로젝트 오픈 신청" 리스트. `SearchParamInfo` + `PaginationInfo` 수동.
- `legacy/popRequestOpenProjectDetails?requestId=` (:73) — 상세 팝업.
- 주석에 `김종성, 2015.07.21` — 와디즈 초기(2015년) 코드. 지금은 `wadiz-frontend` 쪽 open reservation 으로 이관되었으나 히스토리 참조용으로 잔존.

### 8.2 `WEBStatsController` (sts 통계)
경로: `web/sts/controller/WEBStatsController.java:48`

- `sts/sales` (:64) — 매출 통계 페이지.
- `sts/ajaxSales/{searchYear}` (:73), `sts/ajaxSalesParam/{searchYear}` (:85) — 연도별 매출 차트 JSON.
- `sts/emailList` (:99), `sts/downloadExcelDown` (:137) — 이메일 통계 + 엑셀.
- `sts/smsList` (:158), `sts/downloadExcelSmsDown` (:195) — SMS 통계 + 엑셀.
- `sts/banner` (:229), `sts/ajaxBannerSectionList` (:239), `sts/ajaxBannerList` (:270) — 배너 노출 통계.

### 8.3 `MessageController` (sts/message, sts/alimtalk)
경로: `web/sts/controller/MessageController.java:38`

- `sts/message` (:53) — 전체 메시지(이메일/SMS/카카오톡) 통합 통계.
- `sts/alimtalk` (:91) — 알림톡(카카오 비즈메시지) 통계.

### 8.4 `GoalManageController`
경로: `web/goal/controller/GoalManageController.java:19`, prefix `/goalmanager/*`

- `""` (:29) — 메인 페이지(목표/KPI 리스트).
- `/popAddGoal` (:47) + `/ajaxAddGoal` POST (:63) — 목표 추가 팝업/등록.
- `/popManagement` (:94) + `/ajaxDeleteGoal` POST (:108) — 관리 팝업/삭제.
- `/popUpdate` (:134) + `/ajaxUpdateGoalTarget` POST (:150) + `/ajaxUpdateGoalInfo` POST (:175) — 목표 수정(타깃값/메타).

### 8.5 `GaMappingController` (Google Analytics Source/Medium)
경로: `web/analytics/ga/GaMappingController.java:24`, prefix `/analytics/ga/mapping`

- `GET /sourceMedium/main` (:29) — 매핑 관리 JSP.
- `GET /sourceMedium?type=&value=` (:34) — 특정 타입/값 조회 or 전체 조회.
- `POST /sourceMedium` (:45) — 신규 매핑 등록 (`@Valid GaSourceMediumMapping`).
- `PUT /sourceMedium?type=&value=` (:50) — 매핑 수정.
- `DELETE /sourceMedium?type=&value=` (:58) — 삭제.
- `GaSourceMediumType` 열거형으로 utm_source/utm_medium 그룹핑.

### 8.6 `RiskProjectController`
경로: `web/riskproject/controller/RiskProjectController.java:26`, prefix `/riskproject/*`

- `/view` (:36) — 리스크 프로젝트 리스트 페이지.
- `/popManagement` (:77) — 관리 팝업.
- `/popViewHistory` (:116) — 이력 팝업.
- `/popAddProjectView` (:138) + `/ajaxAddProject` POST (:181) — 프로젝트 추가 팝업/등록.
- `/popViewReports` (:159) — 리포트 팝업.
- `/ajaxUpdateProject` (:214) — 업데이트.
- `/ajaxGetTitle` POST (:227) — 프로젝트 제목(캠페인 ID → 타이틀) lookup.
- `/downloadExcel` (:241) — 엑셀.
- 목적: 환불 급증·CS 폭증·법적 이슈 등 **관찰 대상 프로젝트**를 워치리스트로 관리하여 정산·환불 플로우에서 특별 처리.

### 8.7 `RewardBusinessDayApiController`
경로: `web/reward/helper/businessday/RewardBusinessDayApiController.java:22`, prefix `/reward/api/business-days`

- `GET ""` (:28) — `BusinessDaySearch`(연·월·기간) → 영업일 `List<Date>`.
- 리워드 도메인의 정산·배송 SLA 계산용 helper. 응답은 `ResponseWrapper<List<Date>>`.

## 9. 경계 (이 문서가 다루지 않는 것)

- **리워드 정산/심사/쿠폰/환불/코멘트/캠페인/메이커커뮤니케이션 전체** — 별도 문서(`com.wadiz.adm` 의 `reward/settlement/*`, `reward/screening/*`, `reward/coupon/*`, `reward/refund/*`, `reward/campaign/*`, `reward/comment/*`, `reward/makercommunication/*`, `reward/maker/*`, `reward/partner/*`, `reward/collection/*`, `reward/spaceexhibition/*`, `reward/satisfaction/*`, `reward/news/notification/*`, `reward/issue/*`, `reward/memo/*`, `reward/comingsoon/*`, `reward/openreservation/*`, `reward/refundShipping/*`, `reward/pdconsulting/*`, `reward/category/*`, `reward/payment/*`, `reward/shipment/*`, `reward/user/*`, `reward/fundingsettlement/*`, `reward/studio/*`)에서 다룸.
- **계정/세션/메이킹/알림/개인인증/결제/어피류에이트** 등 (`account`, `session`, `maker`, `mail`, `notification`, `personalverification`, `nicepay`, `payment`, `waccount`, `wlogin`, `point`, `wsample`, `wevent`, `event`, `campaign`(레거시), `community`, `app`, `braze`, `send`, `wcampaign`, `collection`, `collectionExposure`, `popup`, `progress`, `promotion`, `masking`, `finance`, `audit`, `affiliation`, `supporterclub`, `supporterClubSettlement`, `diagnosis`, `userData`, `wbenefit`, `wcoming`, `wopinion`, `wpartner`, `storage`, `equity`(본체)) 는 각 도메인 문서 참조.
- **Service 클래스 내부 로직, Mapper XML/DB 스키마** — 본 문서는 컨트롤러 URL/엔드포인트 매핑 레벨만 기술. 비즈니스 규칙(심사 기준, 정산 공식)은 다른 문서 소관.
- **FE 쪽 CRA SPA 번들(React) 라우트** — `front/main` JSP 에 마운트되는 React 앱은 별도 repo(`com.wadiz.adm/web` 하위) 분석 대상. 본 문서는 "어드민 서버가 어떤 경로를 SPA로 넘기는가"만 기록.
- **Swagger/OpenAPI 스펙** — 일부 컨트롤러(`MakerApiResponse`·`ResponseWrapper` 기반)는 `@Api/@ApiOperation` swagger-core 1.x 애노테이션을 사용하지만, 실제 Swagger UI 가 떠 있는지 여부는 본 문서에서 검증하지 않음.
- **인증/권한** — `WEBSessionUtil.getUserId()` 수준의 세션 확인만 확인됨. Role 기반 ACL, 메뉴 권한은 필터/인터셉터 레이어에서 처리되며 별도 문서(`com.wadiz.adm.md` 본체)에서 기술.
