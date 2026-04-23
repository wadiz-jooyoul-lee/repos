# `com.wadiz.adm` — 계정·세션·멤버십 (Account / Session / Membership)

## 1. 기록 범위

레거시 어드민(Spring 3.2 + JSP)에서 **회원·세션·멤버십·파트너·진단·유저데이터** 운영을 담당하는 컨트롤러 계층만 다룬다. 마케팅 수신동의 부분(`UserMarketingInfoController`, `WEBDmAccountController`, `WEBMarketingParticipationController`)은 별도 문서. MyBatis DAO / 서비스 임플은 제외하고, 컨트롤러에서 외부 시스템으로 나가는 경계와 `WEBSessionUtil` 세션 의존만 노트한다.

- 대상 패키지/파일: `com.wadiz.web.account.controller` 4개 + `com.wadiz.web.waccount.controller` 3개 + `com.wadiz.web.wlogin` + `com.wadiz.web.session` + `com.wadiz.web.diagnosis` + `com.wadiz.web.userData` + `com.wadiz.web.wpartner` + `kr.wadiz.account.controller.FindAccountController` + `kr.wadiz.membership.management.controller` 2개.
- 총 16 컨트롤러, 약 4.3k LOC.

---

## 2. 개요

| 축 | 요점 |
|---|---|
| 세션 규약 | 모든 내부 Ajax가 `WEBSessionUtil.getUserId() < 0` 가드 → JSP의 Spring Security 세션을 그대로 신뢰. 별도 토큰 없음. |
| 권한 계층 | `WEBSessionUtil.getRoleId()` 기반. `MemberRoleSettingController` 에 `SUPER_ADMIN=2`, `DEFAULT_ROLE_ID=1` 하드코딩. |
| 외부 로그인 | `WEBLoginController` 가 IP 화이트리스트 실패 시 `account/token` OTP 페이지로 강제. `external_login_enabled` property 로 on/off. |
| API 스타일 | 대다수 `@Controller` + JSP ModelAndView. `Membership*`·`Voucher*` 두 개만 `ResponseWrapper<T>` 기반 JSON API + Swagger 어노테이션. |
| 신·구 동거 | `com.wadiz.web.account.controller.*` = 레거시, `kr.wadiz.account.controller.FindAccountController` = 리뉴얼 계정조회 (Auditable AOP 적용, 뷰 prefix `kr/wadiz/account/find/...`). |
| 감사(Audit) | `@Auditable(operationType=..., targetField=...)` AOP 가 주요 READ/UPDATE/EXCEL_DOWNLOAD 에 걸려 있고, 사내 `AuditClientService` 로 로그 적재 (`MemberRoleSettingController#menuUsageHistoryView/excel`). |

---

## 3. 컨트롤러 목록

| # | 경로 | 파일 | 역할 | 라인 |
|---|---|---|---|---:|
| 1 | `com.wadiz.web.account.controller.WEBAccountController` | account/controller/ | 회원관리 메인(증빙·승인·배심원·가상계좌·포인트·지지서명) | 1417 |
| 2 | `…MemberRoleSettingController` | account/controller/ | 어드민 Role/메뉴권한 + 감사로그 | 289 |
| 3 | `…ProspectiveMemberController` | account/controller/ | 1:1 투자형 오픈상담·리워드 오픈가이드 신청자 | 191 |
| 4 | `…WAccountCommonController` | account/controller/ | 외부 NSDI 행정구역 API 프록시 | 34 |
| 5 | `kr.wadiz.account.controller.FindAccountController` | kr/wadiz/account/ | 신규 계정조회(상세 탭: basic/social/adult/point/support/marketing*) | 215 |
| 6 | `com.wadiz.web.waccount.controller.WEBFindAccountInfoController` | waccount/controller/ | 투자회원 실명조회 + 증빙자료 뷰 + CSV | 196 |
| 7 | `…WEBDestructionPrivacyController` | waccount/controller/ | 개인정보 파기대상 목록·파기 실행 | 90 |
| 8 | `…WEBJoinEquityAccountController` | waccount/controller/ | 투자회원 가입진행(신한1원이체·실명·가상계좌) | 232 |
| 9 | `kr.wadiz.membership.management.controller.MembershipController` | membership/management/ | 멤버십 관리자 API (`/v2/membership/admin`) | 178 |
| 10 | `…VoucherController` | membership/management/ | 멤버십 할인이용권(Voucher) CSV 등록·조회 | 108 |
| 11 | `com.wadiz.web.wlogin.controller.WEBLoginController` | wlogin/ | 어드민 로그인·OTP 토큰·외부접속 가드 | 156 |
| 12 | `com.wadiz.web.session.controller.SessionController` | session/ | Spring SessionRegistry 덤프 (JSON) | 52 |
| 13 | `com.wadiz.web.diagnosis.controller.DiagnosisController` | diagnosis/ | `/diagnosis/ping` → "pong" | 30 |
| 14 | `com.wadiz.web.userData.controller.UserDataController` | userData/ | 유저/프로젝트/리워드·쿠폰 빅데이터 엑셀 추출 | 568 |
| 15 | `com.wadiz.web.wpartner.controller.WPartnerController` | wpartner/ | 파트너(브랜드)·배너·프로젝트·문의 관리 | 561 |
| 16 | `…WEBPartnerInquiryController` | wpartner/ | 파트너 문의 2번째 리스트(구 버전) | 45 |

---

## 4. 도메인 섹션

### 4.1 Account Ops — `WEBAccountController`

레거시 회원관리의 **모노리스 중앙**. 1417줄 통으로 한 클래스 안에 증빙·승인·배심원·출금계좌·가상계좌·포인트·지지서명·등급초기화가 섞여 있다.

- **실명/소득/전문 증빙** (`/account/management/popNiceCheck(Corp)`, `/popApproval(Corp)`, `/popViewHistory`) — `AccountApproval.authType` 의 `PA004`(소득) / `PA005`(개인전문) / `CA005`(법인전문) 분기로 JSP 팝업만 분기 (`WEBAccountController.java:120-259`).
- **상태 변경** (`ajaxStatusModify`, `ajaxCorpStatusModify`, `ajaxAccountModify`, `ajaxCorpAccountModify`, `ajaxInvestInfoModify`) — `EQUITY_AUTH_TYPE_PREFIX_PERSONAL` vs `…_CORP` 로 서비스 분기, 성공 여부는 `CommonAjaxResDto.code == CCI.RETURN_CD_SUCCESS` 체크 (`WEBAccountController.java:279-426`).
- **파일 업로드** `ajaxAuthFileUpload` / `ajaxNiceFileUpload` / `ajaxRegistAttachFile` — `FTUploadFileInfo` + `MultipartFile` 단건/다건, 파일 업로드 전 `WEBSessionUtil.getUserId() < 0` 로그인 가드는 있으나 **CommonAjaxResDto 만 만들고 리턴은 안 함** (무시되는 dead branch) — `WEBAccountController.java:437-447, 459-469`.
- **배심원(Juror) CRUD** (`/account/jurorIntro`, `setPopJurorInfo`, `ajaxModifyJurorInfo`, `ajaxInsertJuror`, `ajaxDeleteJuror`, `ajaxIsValidJurorId`) — `JurMidCate` 공통코드를 산업(0~10) / 심사(10~16) 로 슬라이스. 엑셀 `downloadExcelJurorList` 는 CCI 템플릿 상수 그대로 사용.
- **법인/개인 투자회원 그리드** (`/account/accntauth/personal(/list)`, `…/corp(/list)`) — jqGrid 스타일 `page`/`rows` 파라미터를 `WEBHttpHelper.getParameterMap` 로 꺼내 `GridData` 로 싸서 응답 (`WEBAccountController.java:1134-1199`).
- **My와디즈계좌 / 출금계좌** `popWithdrawAccount`, `popMywadizAccount`, `popPublishVirtualAccountBefore`, `ajaxPublishCorpVirtualAccount` — `WAccountEquityPennyTransferService.getWithdrawAccount` 로 AES 복호화된 계좌번호를 JSP 로 내려보내고, 법인 가상계좌 발급은 생년월일/대표자명/휴대폰 유효성을 수동 검증 후 `wEBaccountService.ajaxPublishCorpVirtualAccount` 호출. `birth.length() != 8` 등 도메인 검증이 컨트롤러에 있음 (`WEBAccountController.java:962-1029`).
- **법인회원 정보 수정** `popModifyUserInfo` / `ajaxModifyUserInfo` — `userType == "BIZ"` 여부로 13개 필드 가드를 컨트롤러에서 `if(StringUtils.isBlank(…)) return errorMessage(…)` 식으로 쌓는다. `SSN` 은 `Math.log10 + 1 == 6/7` 로 자릿수 검증 (`WEBAccountController.java:1040-1091`).
- **포인트/지지서명/SNS/DM 이력** `pointList`, `supportSignatureList`, `popSNSLinkedInfo`, `popAllowDMHistory` — `Pageable(page-1, pageSize)` 로 `PageSearch<TransactionVo, TransactionSearch>` 받아 JSP 렌더. DM 히스토리는 `SubscriberService.getSubscriberInfo(IncomingType.USERS, userId)` 로 email/sms/appPush 3채널 동의 여부를 함께 뿌림 (`WEBAccountController.java:1305-1330`).
- **회원등급 조정** `popApprovalExpired`, `previewTemplate`, `ajaxRenewalrequest`, `ajaxResetAccnttype` — 유효기간 임박 적격/전문 회원에 템플릿 미리보기·갱신요청·초기화. SMS 제목/본문은 `com.wadiz.web.account.constant.AccountAuth` 상수 (`WEBAccountController.java:1343-1415`).

### 4.2 Account Admin Role — `MemberRoleSettingController`

- **가드 방식**: `checkRole()` 내부에서 `WEBSessionUtil.getRoleId() < SUPER_ADMIN(=2)` 이면 `throw new Exception("잘못된 접근!")`. 인터셉터가 아니라 메서드 선두에서 매번 호출.
- **기본 Role 부여/해제**: `/manager/management/role/{insert|delete}` 에서 `DEFAULT_ROLE_ID=1` 고정 값을 넣고, 삭제 시 `deleteAllMenuAuth` 도 함께 (Role=1 은 "ADMIN" 기본 역할).
- **메뉴권한 diff 적용**: `ajaxChangePermission` 이 before/after 문자열(쉼표구분)을 `roleAccountService.findDiffMenulist` 로 diff 내서 `deleteMenuAuth` / `addMenuAuth` 를 나눠 호출하고, 끝에 `sendPermissionInfoMail` 로 알림 메일 발송.
- **감사 뷰 + 엑셀**: `menuUsageHistoryView` / `menuUsageHistory/excel` 는 `AuditClientService.getAuditLogs(AdminPermissionVo)` 로 외부 감사로그 시스템을 조회. 엑셀은 `@RequestParam String excelDownloadPassword` 를 받아 `modelMap` 에 그대로 전달 (뷰에서 ZIP 암호화).
- `adminPermissionLogView` 는 사내 `roleAccountService.getLogList` 기반이라 외부 Audit 서비스와는 이원화.

### 4.3 Prospective / Counsel — `ProspectiveMemberController`

- `/prospectiveMember/equityCounsel` — 1:1 투자형 오픈 상담 신청 목록 + 엑셀(컬럼명 Korean 인라인 하드코딩).
- `equityCounselApplication`·`ajaxSaveEquityCounselApplication` — 팝업 상세 조회 + 상태코드/메모 저장. 세션 로그인 시에만 `adminId = WEBSessionUtil.getUserId()` 주입, 아니면 `return -1`.
- `/account/rewardOpenGuideApplicant` — 리워드 오픈안내 메일 신청자 조회. `InflowChannelType` / `ItemCategoryType` / `ScheduledType` enum (소속: `com.wadiz.wave.reward.studio.open.constant`) 을 `EnumMap` 로 재조립해 JSP 드롭다운에 공급.

### 4.4 WAccount Common — `WAccountCommonController`

- `/waccount/ajaxGetCityList`, `/waccount/ajaxGetRegionList` — 국토부 `openapi.nsdi.go.kr` 행정구역 API 를 `WebUtils.httpRequest(GET, …)` 로 **authkey 를 소스에 하드코딩** (예: `authkey=c8ef51c56d17e143f2f6de`) 해서 대리호출. 주소 입력 UI 에서 호출.

### 4.5 Find / Account — `FindAccountController` (kr.wadiz)

레거시 대비 리뉴얼된 계정조회. 모든 라우트가 `/account/find/*`.

- **리스트 + 감사**: `@Auditable(operationType=READ, targetField="userIds")` 가 메인 진입(`""`)에 붙어 호출된 userId 목록을 감사 로그로 남김. 페이징은 `cPage`/`pageSize` 로 `startNum = (cPage-1)*pageSize` 수동 계산.
- **패스워드 초기화**: `/account/find/{userId}/resetPassword` (GET 팝업) + `/account/find/{sendMethod}/resetPassword` (POST Ajax). `sendMethod` 는 SMS/EMAIL 등 경로 분기.
- **상세 탭**: `/detail/{userId}/{basic|social|adult|point|support|marketingTerms|marketingChannels}` — 뷰는 `kr/wadiz/account/find/detail/*`. point/support 는 `WEBAccountService` 의 공통 메서드를 재사용(레거시와 동일 백엔드). marketing 섹션은 신규+구 이력을 별도 페이지 번호(`newListPage`, `oldListPage`)로 공존 렌더.

### 4.6 Investor Account (waccount) — `WEBFindAccountInfoController` / `WEBJoinEquityAccountController` / `WEBDestructionPrivacyController`

투자형(Equity) 전용 회원 운영.

- **실명조회 단건/다건** (`WEBFindAccountInfoController`)
  - `realname/unit` POST: 단건 `targetUserId` → `WEBFindRealNameService.findRealNameForUnit`.
  - `realname/list` POST: CSV 파일(`fileByUserId`) 업로드 → `findRealNameForList`.
  - `realname/download/csv` GET: 결과 JSON 문자열을 받아 `downloadExcel` 또는 1000건 초과 시 `downloadZipCsvData` 뷰로 분기.
  - 증빙자료 `/waccount/find/evidence(/list)` — `SearchParamInfo` 기반 JSON 결과.
- **가입진행(WEBJoinEquityAccountController)**
  - `joiningInfo` GET: 검색어가 `USERREALNAME` 이면 `AES256Util.encWadizKey` 로 암호화 후 검색, 렌더 직전에 `decWadizKey` 로 복원.
  - `{statusType}/popStatusDetail` — `statusType` path var(예: `idcard`, `penny`, `join` 등)로 단계별 상세 서비스를 분기.
  - `reset/pennyTransfer` POST: 신한 1원이체 실패카운트 리셋.
  - `modify/virtualAccount` / `modify/userAccount` POST: 가상계좌 고객정보/실명 수정. 모든 Ajax 에서 `WEBSessionUtil.getUserInfo() == null` 이면 "로그인 정보가 없습니다" 예외 생성 후 `responseObj` 실패 메시지.
  - `joiningInfo/downloadExcel` — **10000건 초과 시 `throw new RuntimeException`** 하드리밋.
- **개인정보 파기(WEBDestructionPrivacyController)**
  - `/waccount/privacy/destructionInfo` — `isDestruct`, `destructionDueDate` 필터로 `DestructionPrivacy` 목록. `com.wadiz.wave.user.privacy.domain.DestructionPrivacy` 타입이라 **wave.user 도메인 직접 임포트**.
  - `destruct` POST: `userId + destructionId + retentionGroupName` 3종을 받아 `WEBDestructionPrivacyService.destructionPrivacy` 호출 → 실제 파기는 서비스 + 원격 시스템 합작.
  - 주석에 "2019.01.18 배포 - 후속작업 대기로 wSidebar.jsp 미등록 : 코드삭제금지" — **사이드바에서 가려진 dark launch**.

### 4.7 Membership / Voucher — `MembershipController` / `VoucherController`

`/v2/membership/admin` 프리픽스. 여기만 **JSON-first**.

- 공통 응답: `com.wadiz.wave.user.support.ResponseWrapper<T>` (success/fail + HttpStatus 코드).
- 공통 가드: 각 엔드포인트 첫 줄이 `if (WEBSessionUtil.getUserId() < 0) throw new UnauthorizedException("로그인이 필요합니다.")`.
- **Membership** (`MembershipController`)
  - `POST /list` — 메인 리스트(페이지/사이즈/`MainListSearchDto`).
  - `GET /user/{userId}/product/{productId}/detail(/membership|/transaction|/benefit)` — 상세/이용내역/결제/혜택사용 4종 탭을 개별 엔드포인트로. `productId` 는 파라미터로 받지만 구현은 `getDetailInfo(userId)` 등 userId 만 전달하는 형태(productId 는 라우팅용).
  - `PUT /user/{userId}/product/{productId}/unsubscribe_forcibly` — 수동 해지. 해지 요청자(`WEBSessionUtil.getUserId()`)와 대상(`userId`)이 다르게 들어감.
  - `@ExceptionHandler` 로컬 정의: `UnauthorizedException→401`, `NoAvailableMemberShipException→204`, `FailTransactionException→code=100`, `PartlyFailTransactionException→code=101`, `MethodArgumentNotValidException→400`, 기타 → 500+`ErrorVo`.
- **Voucher** (`VoucherController`)
  - `POST /voucher/csv` — `VoucherCsvParser` 인스턴스(new 로 필드 초기화, DI 아님)로 CSV 파싱 → `voucherService.register(List<RegisterVoucherDto>)`.
  - `GET /voucher` (이름 + 시작/종료일 `LocalDate.parse` + 페이지/사이즈), `GET /voucher/user/{userId}` — 조회 2형.
  - 로그인 실패 시 `throw new UnsupportedOperationException("로그인이 필요합니다.")` (다른 컨트롤러와 예외 타입 상이).
  - `CsvParsingException→400`, `MethodArgumentNotValidException→400`, 그 외 → 500("처리를 실패 했습니다.").

### 4.8 Login — `WEBLoginController`

- 엔드포인트 5개: `account/login` / `account/token` (GET/POST) / `login/success` / `login/fail` / `home` / `account/otpToken/{userName}`.
- **화이트리스트 분기**: `ipCheckUtils.checkWhitelist(WebUtils.getClientIP(request))` 가 false(=사외 IP)면 `account/login` 대신 `getExternalLoginPage()` → `external_login_enabled==true` 인 경우 `account/token`, 아니면 `common/errorPage`.
- **OTP 발급**: `account/token` POST 가 `OneTimeTokenService.requestToken(j_username)` 호출 → `UserToken` 반환 시 `account/external` 뷰(토큰 발송 안내). OTP QR 은 `account/otpToken/{userName}` 에서 `getQrCode` 로 base64 QR 전달.
- `login/success` 는 Spring Security 성공 시 Redirect URL. 내부에서 `wEBLoginService.loginSuccessExecute(request)` 로 `AdminUserLoginInfo` 적재(`WEBLoginServiceImpl` + `AdminUserDao` + `FixedSizedQueue`). `home` 은 단순 `redirect:dashboard`.
- **세션 모델 바인딩**: `WEBAccountController`, `MemberRoleSettingController` 두 곳이 `@SessionAttributes("memberListInfo")` + `@ModelAttribute` 로 `List<MemberIntro>` 를 세션에 들고 다님(검색결과 다건 액션용).

### 4.9 Session — `SessionController`

- 단 1개 엔드포인트: `GET /session/registry-data`.
- Spring Security `SessionRegistry.getAllSessions(authentication.getPrincipal(), true)` 를 그대로 JSON 직렬화 + 서버 hostname/IP 를 `additionalParams` 에 덧붙임.
- 즉, **현재 로그인한 본인의 모든 세션 정보를 돌려주는 운영용 덤프** (동시 로그인 감지/강제 종료 UI 에서 사용). 권한 가드는 없음 — Spring Security 전역 필터에 의존.

### 4.10 Diagnosis — `DiagnosisController`

- `GET /diagnosis/ping` → `"pong"`. LB Health Check 전용. 그 외 정보 제공 없음.

### 4.11 UserData — `UserDataController`

**전사 "빅데이터" 엑셀 다운로드 집결소**. 거의 모든 메서드가 `searchVo → list → insertLog → 엑셀/ZipCsv` 패턴.

- `information` 뷰 — 메뉴 안내 페이지 하나만.
- **유저**: `/userdata/userAdidList` (광고ID + 가입일/OS + 동의상태), `/userdata/userPersonal` (파일 업로드된 userId 목록으로 개인정보 일괄 조회).
- **프로젝트**: `/userdata/userAction` (`CampaignType.EQUITY|REWARD` 분기), `/userdata/equityCampaignInfo` (32컬럼 프로젝트 종합 리포트), `/userdata/equityUserInfo` (투자등급+금액), `/userdata/userInvestInfo` (`PromotionCode` 기준 회원 투자 누적).
- **리워드**: `/userdata/rewardinfoList`, `/userdata/rewardList`, 별도 엑셀 2종.
- **쿠폰/프로모션**: `/userdata/couponPromotionResult` — 템플릿번호·날짜별 쿠폰 사용 결과. `excelDownloadPassword` 받아서 ZIP 암호화.
- 공통 로직:
  - `@Auditable(operationType=EXCEL_DOWNLOAD, targetField=CCI.DWLD_EXCEL_DATA_LIST_PUT_STRING)` 로 다운로드 감사.
  - `userDataService.insertLog(request, requestDetails, listCount)` 가 컨트롤러에서 항상 호출 (DB 저장).
  - **1000건 임계값**: ≤1000 이면 `downloadExcel`, 초과면 `downloadZipCsvData` 로 뷰 분기.
  - 엑셀 컬럼명/ID/폭/정렬이 각 메서드 안에 **인라인 String[]** 으로 중복 정의.

### 4.12 Partner — `WPartnerController` / `WEBPartnerInquiryController`

`wpartner` 는 "브랜드 파트너 페이지" (예: 제휴 기업 큐레이션) 운영.

- **목록/상세**
  - `partnerList` (+ `@Auditable(READ, targetField="registerNames")`), `registPartner`, `modifyPartner/{partnerId}`, `modifyPartnerProject/{partnerId}`, `modifyPartnerBanner/{partnerId}`.
  - `modifyPartnerProject` 는 프로젝트타입 3(리워드 예정)/4(투자 예정) 로 `getPartnerComingProjectList` 두 번 호출.
- **배너**: `popRegistPartnerBanner` (sectionType 1/2 두 슬롯), `popModifyPartnerBanner`, `ajaxRegistPartnerBanner`, `ajaxModifyPartnerBanner`, `ajaxRegistPartnerCardPhotoImage`(멀티파트 이미지 업로드).
- **프로젝트 편성**: `ajaxRegistPartnerProject` / `ajaxRemovePartnerProject` / `ajaxModifyPartnerProjectView` (노출 on/off) / `ajaxModifyProjectTypeOrder` (섹션순서).
- **중복 체크**: `ajaxGetPartnerCodeExistYn`, `ajaxGetPartnerProgramExistYn`.
- **문의**: `partnerInquiryList` + `popPartnerInquiryDetail`, 프로그램 문의는 별도 `partnerProgramInquiryList/{partnerId}`.
- **엑셀**: `wpartner/downloadExcel` — RWD + IVT 리포트를 하나로 합쳐 `DWLD_EXCEL_PARTNERREPORT_*` 템플릿으로 출력.
- `WEBPartnerInquiryController` 는 **구 버전 문의 목록**(`partnerInquiryList2`). `PartnerInquiryService` + 구모델 `PartnerInquiryInfo`. 신버전(`WPartnerInqInfo`)로 마이그레이션 중 잔존.

---

## 5. 외부 연동

컨트롤러가 직접 임포트하거나, 한 홉 아래 서비스가 의존하는 외부 도메인.

| 대상 | 위치 | 근거 |
|---|---|---|
| **`com.wadiz.wave.user`** 도메인 | `WEBDestructionPrivacyController` import `com.wadiz.wave.user.privacy.domain.DestructionPrivacy`; `MembershipController`/`VoucherController` import `com.wadiz.wave.user.support.ResponseWrapper`; `WEBAccountController` import `com.wadiz.wave.user.verification.bankaccount.domain.UserWithdrawAccount` | 개인정보 파기/출금계좌/공통 응답래퍼 모두 레거시 `wave.user` 모노리스 타입 재사용. |
| **`kr.wadiz.account`** (Auth 2.0, OAuth2 인가서버) | `kr.wadiz.account.controller.FindAccountController` 하위 `AccountListService`/`AccountDetailService` 및 뷰 prefix `kr/wadiz/account/find/*`. | 신규 Account 쪽 로직. 레거시 `WEBAccountService` 도 일부 재사용해서 이원화. |
| **`com.wadiz.api.reward`** 쿠폰 | `ProspectiveMemberController` 가 `com.wadiz.wave.reward.studio.open.constant.{InflowChannelType, ItemCategoryType, ScheduledType}` 를 import; `UserDataController` `/userdata/couponPromotionResult` 가 쿠폰 템플릿번호·사용결과 엑셀. | 쿠폰/리워드 정책 상수를 어드민에서 enum 값 그대로 드롭다운으로 노출. 실제 쿠폰 도메인은 `api.reward` 관할. |
| **`com.wadiz.wave.pay`** 가상계좌 | `WEBAccountController` import `com.wadiz.wave.pay.model.virtualaccount.VirtualAccount` + `VirtualAccountService.getMyVirtualAccountInfo(userId)`. | My와디즈계좌 조회 팝업. |
| **`com.wadiz.wave.point`** 포인트 클라이언트 | `WEBAccountController`/`FindAccountController` import `com.wadiz.wave.point.client.transaction.domain.TransactionSearch`, `common.domain.{Pageable, PageSearch}`. | 포인트 거래내역 조회. 별도 서비스 HTTP 클라이언트 추정. |
| **`SubscriberService`** (notification) | `WEBAccountController#popAllowDMHistory` 가 `IncomingType.USERS` 로 email/sms/appPush 허용값 조회. | notification service (내부 Kafka/HTTP). |
| **감사 서비스** | `MemberRoleSettingController` 의 `AuditClientService.getAuditLogs(AdminPermissionVo)` + 리턴 `AuditLogs`/`Audit`. | 사내 audit 서비스 HTTP 클라이언트 (`com.wadiz.web.audit.*`). 엑셀 다운로드 AOP `@Auditable` 이 같은 라인으로 이벤트 발행. |
| **NSDI 행정구역 API** | `WAccountCommonController` 가 `http://openapi.nsdi.go.kr/nsdi/eios/service/rest/AdmService/…` 를 authkey 하드코딩해 GET 프록시. | 주소 입력 UI. 국토교통부 공공 API. |
| **멤버십 도메인 서비스** (`com.wadiz.wave.user` 또는 별도) | `MembershipService`/`VoucherService` 는 `kr.wadiz.infrastructure.membership.management.*` DTO 로 통신 — 별도 인프라 서비스/리포지토리 존재. CSV 등록 시 `VoucherCsvParser` 가 파일 파싱. | 어드민은 호출자일 뿐, 실제 멤버십/바우처 원장은 별 시스템. |
| **AES256Util / 암호화** | `com.wadiz.wave.crypto.AES256Util.encWadizKey/decWadizKey` 를 `WEBJoinEquityAccountController` 에서 실명검색 시 바로 사용. | DB 저장 실명이 AES 암호화 포맷이라, 어드민이 암호화된 값으로 조회 → 렌더 전 복호화. |

---

## 6. 경계 / 주의

- **컨트롤러에 도메인 로직 혼재**: `WEBAccountController#ajaxModifyUserInfo` (컨트롤러에서 13개 필드 수동 validate, `Math.log10` 으로 주민번호 자릿수 확인), `#ajaxPublishCorpVirtualAccount` (생년월일 포맷/법인여부 가드). 리라이트 시 `co.wadiz.api.community`/신 account 쪽 DTO validation 으로 옮기는 게 자연스러움.
- **하드코딩된 상수/시크릿**: `WAccountCommonController` 의 NSDI `authkey`, `MemberRoleSettingController` 의 Role ID 매직넘버(1, 2), `UserDataController` 의 1000/10000건 임계값.
- **세션 가드 중복/누락**:
  - `SessionController`, `DiagnosisController`, `FindAccountController` 상세 탭 GET 메서드 일부는 `WEBSessionUtil` 체크가 **메서드 내부엔 없고** 전역 Spring Security 필터에만 의존.
  - `WEBAccountController#ajaxAuthFileUpload/ajaxNiceFileUpload` 는 로그인 실패 시 CommonAjaxResDto 만 만들고 실제 처리 분기(=`return`)가 빠져 있어 업로드가 그대로 진행됨(버그성). 리라이트 시 가드 패턴을 Filter/AOP 로 일원화해야.
- **응답 포맷 이원화**:
  - 레거시 `CommonAjaxResDto.toJson()` (com.wadiz.web.fw.common) + 신규 `ResponseWrapper<T>` (com.wadiz.wave.user.support). Membership/Voucher 만 ResponseWrapper.
  - ExceptionHandler 가 컨트롤러마다 로컬 정의되어 있어서 글로벌 어드바이스가 아님. Voucher 는 UnsupportedOperationException → 500 으로 다른 컨트롤러와 동작이 다름.
- **엑셀 책임 과다**: `UserDataController` 568줄 중 대부분이 컬럼 메타 배열 선언. 공통 엑셀 빌더(`CCI.DWLD_EXCEL_*` 상수) 존재하지만 컬럼 정의는 여전히 인라인. 리라이트 시 유스케이스별 DTO + `@ExcelColumn` 어노테이션으로 이관 가능.
- **세션 기반 `@SessionAttributes("memberListInfo")`**: 멀티탭/멀티인스턴스 환경에서 HTTP 세션에 `List<MemberIntro>` 가 쌓여서 가끔 OOM/동기화 문제를 유발 — 리라이트 시 서버 세션 의존 제거 권장.
- **`com.wadiz.wave.user` 직접 참조**: 파기/가상계좌/출금계좌/ResponseWrapper 까지 wave.user 모노리스 타입을 구조적으로 끌어안고 있어, 해당 모노리스 해체(co.wadiz.api.community 이관) 전까지는 어드민 분리 불가.
- **JSP + jqGrid 레거시 UI**: `WEBAccountController#personalAccntAuthList/corpAccntAuthList` 가 `GridData(pageNo, pageSize, listCount, list)` 로 jqGrid 포맷 응답. 신 FE(Next.js) 로 옮길 때는 커서 기반/ResponseWrapper 기반 JSON 으로 표준화 필요.
