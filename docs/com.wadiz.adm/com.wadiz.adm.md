# com.wadiz.adm 레거시 분석

> 대상 경로: `/Users/casvallee/work/repos/com.wadiz.adm`
> artifactId: `markmount:com.wadiz.adm` / packaging: `war`
> 타깃 도메인: `https://adm.wadiz.kr` (전사 레거시 어드민)

> **Phase 2 심층 분석 진행 중** (197 컨트롤러). 도메인별 상세는 `api-details/` 하위 참조.
>
> | 영역 | 파일 |
> |---|---|
> | 펀딩 프로젝트 라이프사이클 (심사/오픈/진행/종료/환불) | [`api-details/reward-lifecycle.md`](./api-details/reward-lifecycle.md) |
> | 정산·결제·쿠폰·포인트·증권 | [`api-details/finance-settlement.md`](./api-details/finance-settlement.md) |
> | 리워드 콘텐츠·기획전·메이커 커뮤니케이션 | [`api-details/reward-content.md`](./api-details/reward-content.md) |
> | 프로모션·배너·팝업·메일·푸시·알림 | [`api-details/promotion-marketing.md`](./api-details/promotion-marketing.md) |
> | 계정·세션·로그인·멤버십 | [`api-details/account-session.md`](./api-details/account-session.md) |
> | 대시보드·RPA·엑셀·스토어·IP·제휴 | [`api-details/misc-ops.md`](./api-details/misc-ops.md) |

---

## 1. 개요

`com.wadiz.adm` 는 와디즈 **전사 내부 운영/관리자(어드민) 백오피스** 의 레거시 구현입니다. 리워드·투자(증권형) 캠페인 심사/정산/쿠폰/결제/환불/유저관리/CS/통계/메일·푸시 발송·상품·이벤트·프로모션 등 운영팀 업무 전반을 다루는 JSP 기반 Spring MVC 모놀리스.

- README.md 없음. `Jenkinsfile` 없음. 빌드 방법은 `com.wadiz.web` 와 동일한 `mvnw clean install -Dmaven.test.skip=true` 패턴으로 추정.
- 기본 레이아웃은 **AdminLTE 2 + Bootstrap 3.3.6 + jQuery 2.2.4 기반 관리자 스킨**(`web/WEB-INF/jsp/layout/default.jsp:21-36`). 비 `adm.wadiz.kr` 호스트에서는 `dev-mode` 클래스가 붙어 헤더에 스트라이프가 나타나는 가시 구분(`default.jsp:74`).
- **이관 상태**: 신규 어드민(`wadiz-frontend/static/services/admin`, React SPA)으로 **리워드 영역 대부분이 이관 중**. 그 증거:
  - 신규 React 어드민이 호출하는 `/reward/api/**` REST 엔드포인트가 이 저장소 내에 대량 존재(screening, settlement, refund, campaign, coupon, issue, comingsoon, spaceexhibition, satisfaction, memo, shipment 등). 이 엔드포인트들은 `@ResponseBody` 기반 JSON 만 반환 — **BFF 로 역할이 변하고 있음**.
  - `com.wadiz.adm/web/WEB-INF/jsp/webapp/store-app.jsp` 는 `/resources/webapp/store-app/index.html` (React SPA 빌드 산출물) 을 include 하는 쉘(`store-app.jsp:8`).
  - `RewardApiAuthzInterceptor` 가 `@Deprecated`(2023.10) 로 표시되며 `AuthzInterceptor` 로 통합됨 — 권한 레이어가 재정리되는 중.
  - `MakerPageController.java:36` 의 `@Deprecated Will be deprecated` POST 엔드포인트 — 리스트 조회 GET 으로 통합.
- 여전히 JSP 기반으로 남아있는 운영 화면 대다수:
  - **회원관리**(`WEBAccountController.java` 68개 매핑, `WEBDmAccountController`, `WEBFindAccountInfoController`, `WEBMarketingParticipationController` 등)
  - **증권형 투자 전체 백오피스**(`equity/` 패키지 전체 — WEBEquityController 149 매핑, EquityCampaignController 63, EquityStagePublishController 34, WEBMasterGroupController 24, WEBCouponController 16 등)
  - **결제/환불/정산** (`payment/*`, `settlement/*`)
  - **레거시 프로젝트 신청** (`legacy/WEBLRequestController.java`)
  - **메일/푸시 관리** (`mail/*`, `app/push/*`, `send/*`)
  - **쿠폰 관리** 레거시(`kr.wadiz.coupon`, `equity/domain/wcoupon/*`)

규모 지표:

| 항목 | 수 |
|------|---:|
| Controller 클래스 (`*Controller.java`) | 197 |
| Service 클래스 (`*Service*.java`) | 410 |
| Mapper/Dao (`*Mapper.java` / `*Dao.java`) | 374 |
| MyBatis mapper XML (`sqls/**`) | 223 + `sqls_legacy/**` 1 |
| JSP | 92 최상위 그룹 (하위 디렉토리 포함 시 더 많음) |
| `/reward/api/**` 전용 API 컨트롤러 | 약 50개 (신규 React 어드민 BFF) |

---

## 2. 기술 스택

(`com.wadiz.adm/pom.xml`)

- JDK 1.8, Maven WAR.
- **Spring 3.2.10 + Spring Security 3.2.5** — 메인 본체와 동일.
- Spring Boot starter 1.1.4 (starter만 차용, 본체는 XML 설정).
- MyBatis 3.2.7 / mybatis-spring 1.2.2 / mybatis-typehandlers-jsr310 1.0.2 / MySQL connector 5.1.10(adm 은 더 낮은 버전).
- JSP + JSTL 1.2 + **kwonnam jsp-template-inheritance 0.3**.
- 커스텀 TLD `investTag.tld` (`http://www.wadiz.com/jsp/tlds/investTag`) — `investTag:codeNm` 태그, `com.wadiz.jsp.investtags.CodeNm` 구현. 공통코드를 JSP 에서 렌더링하는 용도. web 본체의 `functions.tld` 와는 다른 투자형 전용 TLD.
- URL rewrite: `PartnerUrlRewriteFilter`(이름은 Partner 지만 전역 적용, `web.xml:70-76`). `urlrewrite.xml` 은 **빈 설정**(`<urlrewrite>` 만 있고 룰 없음) — 과거엔 썼지만 지금은 필터만 로드.
- 로깅: **Logback 1.2.12 + log4j-over-slf4j 1.7.36** (어드민은 이미 logback 전환, `pom.xml:376-387`). web 본체는 log4j 1.x.
- 결제 SDK: `nicepay-lite 0.9.24`, `inicis inipay 5.0`, `ExecureCrypto 1.0`, `KSFCclient 1.0`, `NiceID.Check 1.0` (web 과 동일 stack).
- 엑셀: `poi 3.9`, `poi-ooxml 3.9`, `jxls-core 1.0.6`, `jxls-poi 1.0.9`, `jxls-jexcel 1.0.6` — 어드민 특화로 **JXLS 템플릿 엔진** 사용. 다운로드 다량.
- PDF: `itext 2.1.7` (web 은 pdfbox 2.0.24 — 다른 라이브러리 선택).
- Smartsheet `smartsheet-sdk-java 2.2.5` — 증권형 심사 시트 연동.
- Jasypt `jasypt-spring31 1.9.2` (`encKey=!wadiz@`, pom.xml:14).
- Redis: `lettuce-core 5.3.7` + `netty-transport-native-epoll 4.1.63` — 세션/캐시.
- 2FA: `com.warrenstrange googleauth 1.5.0`, QR: `net.glxn.qrgen javase 2.0` — 관리자 OTP 2차인증.
- UA 감지: `net.sf.uadetector 0.9.22` (로그인 접속 기록/보안 룰).
- FTP: `commons-net 3.9.0`.
- CSV: `commons-csv 1.9.0`.
- zip: `zip4j 1.3.2`.
- Wadiz 내부 클라이언트:
  - `wave-client 3.0.27`, `wave-pay pay-client 1.0.0`, `wave-data 1.1.16`, `wave-crypto 1.0.2`, **`wave-audit-client 1.0.5`**(adm 전용 감사로그), `wave.notification notification-client 1.4.5`, `wave.point point-client 1.1.2`
  - `api.reward reward-http-client 0.4.7`, `reward-models 0.4.6`, **`reward-amqp-client 0.0.1`**(어드민에서 MQ 로 이벤트 발행)
  - `funding.core funding-core 1.0.137`
  - `api.main main-model 0.0.1`
  - `api.equity equity-http-client 0.0.6` / `equity-models 0.0.6`
  - `api startup-client 1.3.48` / `startup-model 1.3.48`
  - `api payment-log-client 0.1.1` / `payment-log-model 0.1.1`
  - `api.ksd-client ksd-client 0.0.4`
- Swagger: `springfox-swagger2 2.6.1`.
- Scala 2.10.4 동일 잔재.
- Jersey 1.13 동일(일부 내부 REST 자원, adm 에서 소량 사용).

**Maven 프로파일**: local/dev/rc/rc2/rc3/vqa1/real (stage 없음).

**Resource filtering 차이**: `log4j-${env}.xml` 은 주석처리(`pom.xml:41`)되고 `logback-${env}.xml` 사용. `sqls_legacy/*.xml` 도 포함(`pom.xml:51`).

---

## 3. 아키텍처

### 3.1 필터 체인 (`web/WEB-INF/web.xml`)
1. `encodingFilter` — UTF-8 force.
2. `springSecurityFilterChain` — Spring Security (`security:http` 하나) 가 전역 인증/인가. **web 본체와 가장 큰 차이**: 세션 기반 폼 로그인 + RBAC(role 1/2/3).
3. `failedRequestFilter` — `/web/maker/newsletter/subscriber/downloadExcel` 멀티파트 실패 대비 용도(오직 한 URL 에 한정).
4. `PartnerUrlRewriteFilter` — tuckey(빈 규칙).

### 3.2 Servlet
- `DispatcherServlet` 은 `/web/*` 만 맵핑(web 본체는 `/` 였음). 따라서 어드민의 **모든 URL 은 `/web/` 로 시작**.
- `api-proxy` (`ApiProxyServlet`) — `/web/apip/*` 를 외부 API 로 프록시.

### 3.3 ContextLoader Listener 구성 (`web.xml:82-102`)
환경별 15개 XML 로드: `audit-${env}.xml`(감사로그), `cache-${env}.xml`, `notification-${env}.xml`, `point-${env}.xml`, `proxy-${env}.xml`, `reward-${env}.xml`, `equity-${env}.xml`, `ksd-${env}.xml`, `pay-${env}.xml`, `user-${env}.xml`, `analytics-${env}.xml`, `payment-log-${env}.xml`, `startup-${env}.xml`, `root-context.xml`, `datasource-context.xml`, **`security/web-security.xml`**.

특히 `analytics-${env}.xml` 은 adm 에만 있음(집계/통계 서비스).

### 3.4 EnumContextListener
`web.xml:104-119`: `com.wadiz.web.fw.common.EnumContextListener` 가 아래 enum 7종을 `ServletContext attribute` 로 노출 → JSP 에서 `${CampaignScreeningStatus.APPROVED}` 식으로 직접 사용 가능.
- `CampaignScreeningStatus`, `CampaignScreeningEventType`
- `CorpType`
- `ComingSoonStatus`
- `OpenReservationStatus`
- `CampaignPeriodSearchType`
- `SettlementStatus`
- `ScreeningValidationCheckItemType`

### 3.5 Spring Security (`src/main/resources/security/web-security.xml`)
- Custom: `CustomUsernamePasswordAuthenticationFilter`, `RedisSessionRegistry`(Lettuce 기반, 동시 로그인 1명 제한), `CustomConcurrentSessionControlAuthenticationStrategy`, `LoginSuccessHandler` → `/web/login/success`, `CustomLogoutSuccessHandler` → `/web/account/login`, `CustomAuthenticationFailureHandler` → `/web/login/fail`.
- `WadizPassWordEncoder` (`com.wadiz.wave.crypto`).
- 권한 규칙:
  - permitAll: `/web/swagger-ui.html`, `/web/swagger-resources/**`, `/web/webjars/**`, `/web/diagnosis/ping`, `/web/login/*`, `/web/account/login`, `/web/account/external`, `/web/account/token`, `/web/account/otpToken/**`, `/resources/**`, `/favicon.ico`, `/index.jsp`, `/login`.
  - `/web/manager/**` → role `2` 또는 `3` (매니저/슈퍼).
  - `/**` → role `1`, `2`, `3`.
- HSTS 2년, session-fixation=migrate, concurrency max 1 + Redis-based `sessionRegistry`.
- OTP 2FA: `googleauth 1.5.0` + `qrgen 2.0` 기반 `/web/account/otpToken/**`.

### 3.6 DispatcherServlet (`spring/dispatcher/servlet.xml`)
- Component scan: `com.wadiz.web, kr.wadiz` (Controller).
- Argument resolver: `SampleArgumentResolver`(web 본체 4개에 비해 단출).
- View resolver 체인: `ContentNegotiatingViewResolver`(PathExtensionContentNegotiationStrategy — `*.json` → `application/json`) → `BeanNameViewResolver` → `InternalResourceViewResolver`(`/WEB-INF/jsp/*.jsp`).
- Download 뷰 bean 7종: `download`, `downloadExcel`, **`downloadExcelInvestUserListForIssueReg`**, `downloadFile`, **`equityDownloadFile`**, **`downloadViewExcelByDataType`**(`com.wadiz.web.equity.domain.excel.DownloadViewExcelByDataType`), `downloadZip`.
- `CommonsMultipartResolver` (web 본체와 다르게 기본 Spring 것).
- AOP: `PerformanceTrackingAspect` (`com.wadiz.core.fw.aop.PerformanceTrackingAspect`) — 어드민에선 성능 메트릭 측정 중심.
- Interceptors (`spring/dispatcher/interceptor.xml`): `DefaultInterceptor`, `LoginInterceptor`, `AuthzInterceptor`, **`RewardApiAuthzInterceptor`(Deprecated 2023.10)**.

### 3.7 Layout (kwonnam JSP template inheritance)
- `jsp-inheritance-prefix=/WEB-INF/jsp/layout/`, `suffix=.jsp` (`web.xml:154-162`).
- 레이아웃 템플릿 3종: `layout/default.jsp`(일반 메뉴 포함 AdminLTE 전역 레이아웃), `layout/empty.jsp`(팝업/iframe), `layout/static-resources-default.jsp`(정적 리소스 주입용).
- 글로벌 JS: `/resources/js/format.js?ver=20210503` + jQuery 2.2.4 + Bootstrap 3.3.6 + AdminLTE CSS + jquery-ui.
- GTM: `/WEB-INF/jsp/common/gtm.jsp`.
- 헤더/사이드바: `/WEB-INF/jsp/common/wHeader.jsp` + `/WEB-INF/jsp/common/wSidebar.jsp`(추정).

---

## 4. 페이지·URL 구조

### 4.1 상위 Java 패키지(컨트롤러 기준)
`com.wadiz.web.*`:
- 계정: `account`, `waccount`
- 계열사/제휴: `affiliation`(criteo 등)
- 분석/통계: `analytics/ga`, `sts`(SendTalk), `performance`, `KPIgoal`
- 앱: `app/banner`, `app/push`
- 감사로그: `audit`
- Braze CRM: `braze`
- 캠페인: `campaign`, `campaignIssue`, `progress`
- 설정: `config`, `constant`, `ip`
- 대시보드: `dashboard`
- 진단: `diagnosis`
- 증권형: `equity/*` (가장 큰 도메인)
- 이벤트/기획전: `event`, `wevent`, `wbenefit`, `collection`, `collectionExposure`, `popup`
- Excel 다운로드 로그: `excel`
- FT 파일 업로드: `ftfile`
- 프레임워크: `fw`
- 목표관리: `goal`(KPI)
- 홈: `home`
- 레거시 요청: `legacy`
- 메일: `mail`, `send`
- 메인: `main`
- 메이커: `maker`, `manage`
- 마스킹: `masking`
- 결제/환불: `nicepay`, `payment`, `refundShipping`
- 알림: `notification`
- 프로모션: `promotion`
- 리스크: `riskproject`
- RPA: `rpa`
- 세션: `session`, `session2token`
- 정산: `settlement`, `supporterClubSettlement`
- 보관: `storage`, `store`, `sts`
- 스타트업: `startup/*` (corporation, feed, maker, maker/team)
- 공급사클럽: `supporterclub`
- 단축 URL: `url`
- 유저 데이터: `userData`
- 유저 후기/의견: `wopinion`
- 리워드 도메인 전체(신 admin 백엔드 역할):
  - `reward/screening/*` — 심사 (Manager, Requirement, ReminderNotice, PdScreening, ScreeningKC)
  - `reward/campaign/*` — 캠페인(Marker, Hidden, Campaign, RewardChangeLog)
  - `reward/coupon/*` — 쿠폰 (Template, Issue, Transaction, TransactionSummation, Ui)
  - `reward/comment/*` — 댓글
  - `reward/comingsoon/*` — 오픈예정(Ui, Api)
  - `reward/settlement/*` — 정산 15종(SettlementStatus, SettlementSearch, SaleSettlement, Advanced, TaxInvoice, SettlementResult, SubMall, SettlementModifiedFee, CampaignContractor, CampaignSettlementFee, EstimatedSettlement, Clawback, FundingSettlementSubMall)
  - `reward/refund/*` — 환불(Command, Policy, EvidenceFile)
  - `reward/refundShipping/*` — 환불배송
  - `reward/news/notification/*`, `reward/event/*`
  - `reward/issue/*` — 이슈(CampaignIssue, CampaignIssueTask, CampaignIssueReport)
  - `reward/fundingsettlement/*`, `reward/partner/*`, `reward/maker/*`, `reward/memo/*`, `reward/pdconsulting/*`
  - `reward/satisfaction/*`, `reward/shipment/*`, `reward/spaceexhibition/*`, `reward/category/*`, `reward/collection/*`
  - `reward/user/*`, `reward/makercommunication/*`
  - `reward/studio/*` — 스튜디오 BFF (RewardMakerStudioSubmitApiController)
  - `reward/helper/businessday/*`, `reward/payment/*`, `reward/rewarditem/*`, `reward/story/*`, `reward/comment/*`
  - `reward/exception/handler` — `RewardGlobalExceptionHandler`(`@ControllerAdvice`)

`kr.wadiz.*`:
- `kr.wadiz.account.controller.FindAccountController` — 계정 찾기
- `kr.wadiz.coupon.controller.UserCouponTemplateController` — 쿠폰 템플릿(구버전)
- `kr.wadiz.membership.management.controller.MembershipController` — 프리미엄 멤버십
- `kr.wadiz.membership.management.controller.VoucherController` — 바우처

### 4.2 URL prefix 요약표

> **주의**: DispatcherServlet 매핑이 `/web/*` 이므로 실제 브라우저 URL 은 `https://adm.wadiz.kr/web/<prefix>` 형태. Controller `@RequestMapping` 값은 이 prefix 없이 표기.

| URL prefix | 용도 | 대표 Controller (path:line) | JSP 경로 (`/WEB-INF/jsp/` 기준) |
|---|---|---|---|
| `/` | 어드민 홈 | `home/controller/HomeViewController.java` | `home/*.jsp` |
| `account/management/**` | 회원관리(개인/법인/본인인증) | `account/controller/WEBAccountController.java:120-930` (`WEBAccountController` 가 68개 매핑 보유) | `account/*.jsp` |
| `account/member/{userId}`, `/account/member/campaign/{userId}`, `/account/member/backed/{userId}` | 회원 상세·참여/캠페인 | `WEBAccountController.java:480, 500, 534` | `account/member*.jsp` |
| `account/jurorIntro`, `/account/jurorInsert`, `/account/ajaxModifyJurorInfo` | 심사위원(법인) 관리 | `WEBAccountController.java:567, 716, 665` | `account/juror*.jsp` |
| `account/changePassword` | 관리자 비번변경 | `WEBAccountController.java:805` | `account/changePassword.jsp` |
| `account/{userId}/memberRoleSetting`, `/member/role/*` | 권한(role) 설정 | `account/controller/MemberRoleSettingController.java` | `account/role*.jsp` |
| `account/userMarketingInfo` | 마케팅 수신동의 | `UserMarketingInfoController.java` | `account/marketing*.jsp` |
| `account/prospectiveMember/*` | 예비회원 | `ProspectiveMemberController.java` | `account/prospective*.jsp` |
| `waccount/**` | 증권형 회원관리 | `waccount/controller/WEBFindAccountInfoController.java`(15), `WEBJoinEquityAccountController.java`(11), `WEBDestructionPrivacyController.java`(6), `WEBMarketingParticipationController.java`, `WEBDmAccountController.java` | `waccount/*.jsp` |
| `find/**`, `kr.wadiz.account/*` | 계정찾기(ID/PW) | `kr/wadiz/account/controller/FindAccountController.java`(13) | `kr/wadiz/account/*.jsp` |
| `manage/home/api/v1/main/quickmenu`, `/api/v2/...`, `/api/v3/...`, `/api/v4/...` | 메인 퀵메뉴 / 메인 뱃지 관리(JSON) | `main/controller/MainController.java:25-130` (35 매핑) | JSON + `dashboard.jsp` |
| `campaign/**`, `/campaign/banner/**` | 리워드 캠페인 구버전 관리 | `campaign/controller/WEBCampaignController.java`(20), `WEBBannerSectionController.java`(38), `WEBCampaignInvestInSideController.java`(6), `WEBCampaignCommentController.java`(6), `UploadFileController.java`(5) | `campaign/*.jsp` |
| `progress/**` | 진행중 캠페인 운영 | `progress/controller/CampaignProgressController.java`(14), `CampaignAbortController.java`(7), `CampaignDeliveryController.java`(6), `CampaignSettlementController.java`(18), `CampaignScreeningController.java`(5), `CampaignPenaltyController.java`(4), `CampaignEncoreController.java`(3), `CampaignPreReservationController.java`(6), `CampaignPersonalMessageController.java`(5) | `progress/*.jsp`, `performance/*.jsp` |
| `wcampaign/**` | 증권형 캠페인 | `wcampaign/controller/WCampaignController.java`(21) | `wcampaign/*.jsp` |
| `ftcampaign/**`, `equity/**` | 증권형 백오피스 전체 | `equity/domain/ftcampaign/controller/WEBEquityController.java:93`(149 매핑 — 최대), `equity/controller/EquityCampaignController.java`(63), `EquityBusinessController.java`(31), `EquityStageController.java`(12), `EquityStagePublishController.java`(34), `EquityCampaignPublishController.java`(26), `EquityNewsController.java`(9), `EquityFileController.java`(19), `EquityCollectionController.java`(17), `EquityDownloadExcelController.java`(5), `WEBMasterGroupController.java`(24), `WEBCouponController.java`(16), `WEBCouponDetailController.java`(13), `WEBEventCouponController.java`(5), `EquityNoticeController.java`(4), `EquityW9ContentsController.java`(6), `PremiumMembershipController.java`(7), `PremiumContentsBoardController.java`(4), `WEBVirtualAccountController.java`(6), `WEBOfferPaymentController.java`(20), `WEBLectureInaugurateController.java`(18) | `ftcampaign/*.jsp`, `equity/*.jsp`, `premiumMembership/*.jsp` |
| `reward/api/**` | **신규 리워드 어드민(React) BFF — JSON** | `reward/*/controller/*ApiController.java` 계열 약 50개 | JSON (View 없음) |
| `reward/**` (UI) | 리워드 어드민 JSP(구버전) | `reward/*/controller/*UiController.java` 계열 (CouponUi, RewardCampaignUi, ScreeningRequirementUi, CollectionUi, RewardComingSoonUi, RefundShippingUi, MakerCommunicationUi, CommentUi, SatisfactionUi, rewardCouponViewController 등) | `reward/*.jsp`, `rewardSpaceExhibition/*.jsp`, `campaignIssue/*.jsp`, `refundShipping/*.jsp`, `satisfaction/*.jsp` |
| `settlement/**` | 리워드 정산(구) | `settlement/controller/WEBSettlementRewardController.java`(23) | `settlement/*.jsp` |
| `payment/**`, `/payment/reward/**`, `/payment/lecture/**` | 결제·가상계좌 | `payment/controller/WEBPaymentController.java`(10), `WEBRewradPaymentController.java`(5), `WEBLecturePaymentController.java`(15) | `payment/*.jsp` |
| `refundShipping/**` | 환불 배송 | `reward/refundShipping/controller/*` | `refundShipping/*.jsp` |
| `app/**`, `app/push/**`, `mobileBanner/**` | 앱 배너/푸시 | `app/banner/controller/WEBMobileBannerController.java`(8), `app/push/controller/AppPushController.java`(24), `MobilePushController.java`(15), `WEBAppController.java`(17) | `app/*.jsp` |
| `popup/**` | 팝업/공지 | `popup/controller/PopupMainController.java`(9) | `popup/*.jsp` |
| `event/**`, `wevent/**`, `wbenefit/**` | 기획전/이벤트/혜택 | `event/controller/EventViewController.java`, `wevent/invite/controller/InviteEventController.java`(10), `InviteEventViewController.java`(3), `wevent/inviteEquityAccount/WEBEventCompensationContoller.java`, `wbenefit/controller/WEBPromotionController.java`(10), `promotion/controller/PromotionController.java`(14) | `wevent/*.jsp`, `wbenefit/*.jsp`, `marketing/*.jsp`, `webapp/index.jsp` |
| `collection/**` | 컬렉션 | `collection/controller/CollectionProxyController.java`, `CollectionFileProxyController.java`, `collectionExposure/controller/CollectionExposureUiController.java`(6), `CollectionExposureApiController.java`(12) | `collection/*.jsp`, `collectionExposure/*.jsp` |
| `supporterClub/**`, `/supporterClubSettlement/**` | 공급사클럽(+ 정산) | `supporterclub/controller/SupporterClubController.java`(6), `supporterClubSettlement/controller/SupporterClubSettlementController.java` | `supporterClub/*.jsp` |
| `wpartner/**` | 파트너사 | `wpartner/controller/WPartnerController.java`(37), `WEBPartnerInquiryController.java` | `wpartner/*.jsp` |
| `wcoming/**` | 오픈예정 | `wcoming/controller/WEBComingSoonController.java`(6), `WEBComingSoonRegisterController.java`(4) | `wcoming/*.jsp` |
| `maker/**`, `maker/newsletter/**` | 메이커 관리 | `maker/controller/MakerViewController.java`, `WEBMakerNewsletter.java`(10), `maker/announcement/controller/MakerAnnouncementViewController.java` | `maker/*.jsp` |
| `startup/**` | 스타트업/법인 IR | `startup/controller/StartupCollectionController.java`(21), `CorporationApiController.java`(22), `CorporationContactController.java`(19), `CorporationAdminRequestApiController.java`(12), `CorporationInvestorApiController.java`(12), `CorporationIrRequestApiController.java`(5), `CorporationInquiryController.java`(4), `CorporationContractApiController.java`(6), `CorporationNewsApiController.java`(7), `CommonApiController.java`(4), `startup/domain/maker/controller/MakerPageController.java`(16), `MakerIssueController.java`(14), `MakerAdminController.java`(6), `MakerTeamMemberController.java`(4), `startup/domain/feed/controller/FeedContentsApiController.java`(12), `FeedContentsFileApiController.java`(6) | `startup/*.jsp` |
| `sts/**` | SendTalk 메시지 발송 | `sts/controller/MessageController.java`(5), `WEBStatsController.java`(15) | `sts/*.jsp` |
| `mail/**` | 메일 템플릿/예약 발송 | `mail/controller/WEBMailController.java`(8), `WEBMailTemplateController.java`(16), `WEBMailSendingController.java`(10), `WEBMailReservationController.java`(9), `WEBMailLogController.java`(13), `WEBMarketingMailController.java`(6) | `mail/*.jsp` |
| `send/**` | 다건 발송 | `send/controller/WEBSendController.java`(9) | `send/*.jsp` |
| `notification/**` | 알림 설정 | `notification/controller/NotificationController.java`(12), `NotificationViewController.java` | `notification/*.jsp` |
| `wopinion/**` | 유저 의견 | `wopinion/WOpinionController.java`(5) | `wopinion/*.jsp` |
| `point/**`, `/point/api/**` | 포인트 | `point/controller/WEBPointController.java`(35), `PointApiController.java`(4) | `point/*.jsp` |
| `coupon/**`, `user/coupon/**` | 쿠폰(구) | `kr/wadiz/coupon/controller/UserCouponTemplateController.java`(14), `reward/coupon/controller/*Controller.java` | `kr/*.jsp`, `wcoupon/*.jsp` |
| `membership/**` | 프리미엄 멤버십 | `kr/wadiz/membership/management/controller/MembershipController.java`(20), `VoucherController.java`(11) | `premiumMembership/*.jsp` |
| `riskproject/**` | 리스크 프로젝트 | `riskproject/controller/RiskProjectController.java`(14) | `riskproject/*.jsp` |
| `rpa/**` | RPA 자동화 | `rpa/controller/RPAController.java` | `rpa/*.jsp` |
| `userData/**` | 유저 데이터 | `userData/controller/UserDataController.java`(22) | `userdata/*.jsp` |
| `promotion/**` | 프로모션/쿠폰 이벤트 | `promotion/controller/PromotionController.java`(14) | `marketing/*.jsp` |
| `ip/program/**` | 브랜드 IP 프로그램 | `ip/program/controller/IpProgramViewController.java` | `kr/*.jsp` (추정) |
| `affiliation/criteo/**`, `/analytics/ga/**` | 마케팅 연동 | `affiliation/criteo/controller/CriteoController.java`(7), `analytics/ga/GaMappingController.java`(11) | `kr/*.jsp` |
| `legacy/requestOpenProjectList`, `/legacy/popRequestOpenProjectDetails` | 레거시 오픈신청 | `legacy/controller/WEBLRequestController.java:54,73` | `legacy/requestOpenProjectList.jsp`, `legacy/popRequestOpenProjectDetails.jsp` |
| `goalmanager/**`, `/goal/**` | KPI 목표 | `goal/controller/GoalManageController.java`(14) | `goalmanager/*.jsp`, `KPIgoal/*` |
| `community/**` | 커뮤니티(구) | `community/controller/WEBCommunityController.java`(42) | `community/*.jsp` |
| `excel/**` | 엑셀 다운로드 로그 | `excel/controller/AdminExcelDownloadLogApiController.java`(6) | `excel/*.jsp` |
| `webapp/**` | 임베디드 React 앱(store-app, mailsystem) | `store/controller/StoreViewController.java`, `store/controller/StoreScreeningRequirementController.java`(3) | `webapp/store-app.jsp`, `webapp/mailsystem.jsp`, `webapp/index.jsp` |
| `storage/**` | 파일 저장소 | `storage/controller/*` | `storage/*.jsp` (없을 수 있음) |
| `url/**` | 단축 URL 생성/관리 | `url/controller/WadizUrlController.java`(12) | `url/*.jsp` |
| `dashboard/**` | 메인 대시보드 | `dashboard/controller/WEBDashboardController.java` | `dashboard.jsp` |
| `diagnosis/ping` | 헬스체크 | `diagnosis/controller/DiagnosisController.java`(3) | JSON |
| `session/**`, `/session2token/**` | 세션 관리 | `session/controller/SessionController.java`(4) | JSON |
| `wlogin/**`, `/login/**` | 관리자 로그인 | `wlogin/controller/WEBLoginController.java`(8) | `account/login.jsp` |
| `manage/home/**` | 관리자 홈/메인 관리 | `manage/home/controller/manageHomeViewController.java` | `manage/home/*.jsp` |
| `wsample/**` | 레거시 샘플 | `wsample/WSampleController.java` | `wsample/*.jsp` |

### 4.3 JSP 최상위 그룹 (`web/WEB-INF/jsp/*`)
`account`, `affiliation`, `analytics`, `app`, `business`, `campaign`, `campaignIssue`, `collectionExposure`, `common`, `community`, `dashboard.jsp`, `equity`, `excel`, `feedback`, `front`, `ftcampaign`, `goalmanager`, `kr`, `layout`, `legacy`, `mail`, `maker`, `marketing`, `mastergroup`, `news`, `payment`, `performance`, `point`, `premiumMembership`, `progress`, `refundShipping`, `reward`, `rewardSpaceExhibition`, `riskproject`, `rpa`, `satisfaction`, `send`, `settlement`, `startup`, `sts`, `supporterClub`, `url`, `userdata`, `waccount`, `wbenefit`, `wcampaign`, `wcoming`, `wcoupon`, `webapp`, `wevent`, `wopinion`, `wpartner`, `wsample`.

---

## 5. 컨트롤러·AJAX 엔드포인트 목록

### 5.1 페이지 렌더링(ModelAndView / String return) 대표

| URL | Method | Controller path:line | View |
|---|---|---|---|
| `/ftcampaign/equityList` | GET | `WEBEquityController.java:123` | `ftcampaign/equityList` |
| `/ftcampaign/equitySeqList` | GET | `WEBEquityController.java:169` | `ftcampaign/equitySeqList` |
| `/ftcampaign/popEquityDetail` | GET | `WEBEquityController.java:240` | `ftcampaign/popEquityDetail` |
| `/account/member/{userId}` | GET | `WEBAccountController.java:480` | `account/memberDetail` |
| `/account/management/memberRecordInfo` | GET/POST | `WEBAccountController.java:842` | `account/memberRecordInfo` |
| `/account/jurorIntro` | GET | `WEBAccountController.java:567` | `account/jurorIntro` |
| `/legacy/requestOpenProjectList` | GET | `WEBLRequestController.java:54` | `legacy/requestOpenProjectList` |
| `/legacy/popRequestOpenProjectDetails` | GET | `WEBLRequestController.java:73` | `legacy/popRequestOpenProjectDetails` |
| `/webapp/store-app` | GET | `store/controller/StoreViewController.java` | `webapp/store-app` (React SPA 쉘) |
| `/manage/home` | GET | `manage/home/controller/manageHomeViewController.java` | `manage/home/main` |

### 5.2 AJAX/JSON 엔드포인트 대표 (`/reward/api/**` 신규 어드민 BFF 중심)

| URL | Method | Controller:line | 용도 |
|---|---|---|---|
| `/reward/api/screenings/managers` | GET | `ScreeningManagerApiController.java:30` | 심사자 목록 |
| `/reward/api/screenings/campaigns/{id}/managers` | POST | `ScreeningManagerApiController.java:37` | 심사자 배정 |
| `/reward/api/screenings/manager/check` | GET | `ScreeningManagerApiController.java:47` | 심사자 검증 |
| `/reward/api/screenings/campaigns/{id}/requirements/files` | POST | `ScreeningRequirementApiController.java:32` | 심사 자료 업로드 |
| `/reward/api/screenings/campaigns/{id}/requirements/files/memo` | POST | `ScreeningRequirementApiController.java:66` | 심사자료 메모 |
| `/reward/api/pd-screenings/campaigns/{id}/events/{eventType}` | POST | `PdScreeningApiController.java:34` | PD 심사 이벤트 |
| `/reward/api/pd-screenings/campaigns/{id}/new-plan/approve` / `reject` / `manual-request` | POST | `PdScreeningApiController.java:62,75,88` | PD 승인/반려/수동요청 |
| `/reward/api/kc-screenings/campaigns/{id}/requirements/files` | POST | `ScreeningKCApiController.java:27` | KC 심사자료 업로드 |
| `/reward/api/remindernotice/campaigns/{id}` | GET/POST | `ReminderNoticeApiController.java:27,41` | 리마인더 공지 |
| `/reward/api/campaigns/{id}` | GET | `CampaignApiController.java:35` | 캠페인 상세 |
| `/reward/api/campaigns/{id}/agreement/change` | PUT/POST | `CampaignApiController.java:49,62` | 계약 변경 |
| `/reward/api/campaigns/{id}/campaign-marker` | GET/POST | `CampaignMarkerApiController.java:39,24` | 캠페인 마커 |
| `/reward/api/campaign-hidden/campaigns/{id}` | GET/POST | `CampaignHiddenApiController.java:20,26` | 숨김 처리 |
| `/reward/api/reward-change-logs/campaigns/{id}/summaries` | GET | `RewardChangeLogController.java:42` | 리워드 변경 이력 |
| `/reward/api/reward-change-logs/{logId}` | GET | `RewardChangeLogController.java:54` | 변경 이력 상세 |
| `/manage/home/api/v1/main/quickmenu` | POST/GET/DELETE | `MainController.java:30,36,42` | 퀵메뉴 CRUD |
| `/manage/home/api/v2/main/quickmenu`, `/v3/quickmenu/admin`, `/v4/quickmenu/admin` | GET/POST | `MainController.java:48-88` | 퀵메뉴 v2/v3/v4 |
| `/account/management/ajaxAllowModify`, `/ajaxStatusModify`, `/ajaxCorpStatusModify`, `/ajaxAccountModify`, `/ajaxCorpAccountModify`, `/ajaxInvestInfoModify`, `/ajaxAuthFileUpload`, `/ajaxNiceFileUpload`, `/ajaxRegistAttachFile` | POST | `WEBAccountController.java:267-825` | 회원상태·계좌·투자정보·파일 수정 |
| `/account/ajaxModifyJurorInfo`, `/ajaxIsValidJurorId`, `/jurorInsert`, `/ajaxDeleteJuror` | POST | `WEBAccountController.java:665-744` | 심사위원 CRUD |
| `/account/downloadExcelJurorList`, `/downloadExcelDownAccount` | GET | `WEBAccountController.java:608, 771` | 엑셀 다운로드 |

(어드민의 ajax 는 주로 `produces="text/plain;charset=UTF-8"` 또는 `"application/json;charset=UTF-8"`, 그리고 *Excel 다운로드 뷰*(`downloadExcel`, `equityDownloadFile`) 로의 `return "downloadExcel";` 패턴)

---

## 6. 주요 화면 상세 분석

### 6.1 회원 관리 (`/web/account/management/**`, `/web/account/member/{userId}`)
- **Controller**: `com/wadiz/web/account/controller/WEBAccountController.java` — 약 **68개 매핑** 을 가진 프로젝트 내 최대 규모 컨트롤러 중 하나.
- **화면**:
  - 팝업: `popNiceCheck`, `popNiceCheckCorp`, `popApproval`, `popApprovalCorp`, `popViewHistory`, `popModifyUserInfo`, `popWithdrawAccount`, `popMywadizAccount`.
  - 상세: `/account/member/{userId}`, `/account/member/campaign/{userId}`(메이커로 활동한 캠페인), `/account/member/backed/{userId}`(참여한 캠페인).
  - 심사위원: `/account/jurorIntro`, `/account/downloadExcelJurorList`, `/account/setPopJurorInfo`, `/account/jurorInsert`.
- **의존 서비스**: `com.wadiz.core.account.service.AccountService`, `WEBAccountService`, `CertificationService`(NICE 본인인증), `WAccountRecordingInfoService`, `SubscriberService`(알림), `VirtualAccountService`, `WAccountEquityPennyTransferService`(증권형 1원 입금), `WEBJoinEquityAccountService`, `CodeService`.
- **DAO / Mapper**: `com.wadiz.core.account.dao.AccountDao` → `sqls/account/account-mapper.xml` (**2761라인**, 221 `<if>` 동적 쿼리 — 프로젝트 최대). 다양한 검색 조건(기간/상태/회원유형/본인인증/거주지/마케팅동의 등)이 단일 mapper 안에 몰려있음. 추가: `sqls/account/userprofile-mapper.xml`, `userageverification-mapper.xml`.
- **렌더링 JSP**: `web/WEB-INF/jsp/account/` 전체 — 리스트/상세/팝업/드롭다운/검색폼이 모두 AdminLTE 테이블 + datepicker + jQuery UI 기반.
- **외부**: NICE 본인인증(`NiceID.Check`), Wave Pay(가상계좌), Wave Point, Wave Notification.

### 6.2 증권형 캠페인 관리 (`/web/ftcampaign/**`, `/web/equity/**`)
- **Controller**: `com/wadiz/web/equity/domain/ftcampaign/controller/WEBEquityController.java` — **149개 매핑** 으로 프로젝트 내 **최대**.
- 주요 흐름 (`WEBEquityController.java:123-800+`):
  - `ftcampaign/equityList` — 투자형 프로젝트 목록(검색, 기간, 상태).
  - `ftcampaign/equitySeqList` — 노출 순서 편집.
  - `ftcampaign/downloadExcelDown` — 엑셀 다운로드.
  - `ftcampaign/popEquityDetail` — 상세 팝업 (수십 개 데이터 조회를 한꺼번에: equityDetails, evnTypes, equityDetailAtcIncorp, equityDetailCertified, equityDetailBusinessLicense, equityDetailLogo, equityDetailegistAttachFile, equityDetailStockholder, equityDetailMember, equityDetailBaseMemeber, equityDetailFaq, equityDetailFileInfo, getApiKsfc, getPoint, equityRelativeCampaignUserList, …).
  - `ftcampaign/ajaxGetCampaignIRFdbkCommentList`, `/ajaxRegisterCampaignIRFdbkComment`, `/ajaxRegisterSubmitCampaignIRFdbkComment`, `/ajaxRemovalCampaignIRFdbkComment`, `/ajaxModifyCampaignIRFdbkComment`, `/ajaxSubmitCampaignIRFdbkComment` — IR 피드백 댓글 CRUD (6개).
  - `ftcampaign/ajaxModifyCampaignRequest*` — Return/Approve/Discontinue.
  - `ftcampaign/ajaxModifyCampaign*` — Manager/Recruitment/PrivateCategory/Deposit/IncomeDeductYn/SecurtType/RelativeCampaignUserAdd/Delete/StartConnection/DisabledYn.
  - `ftcampaign/downloadExcelAccountResult`, `downloadExcelInvestNoAssign`, `downloadExcelInvestRefund`, `downloadExcelScrtGroupList`, `downloadExcelInvestUserList` — 5종 엑셀.
- **의존 서비스**: `WEBEquityService`, `EquityService`, `CodeService`, `CertificationService`, `FTCampaignGoodsService`, `EquityAssignService`, `SmartSheetService`(증권형 심사 시트 연동), `EquityCampaignPublishService`, `EquityCampaignService`, `EquityDao`.
- **Mapper**: `sqls/equity/ftcampaign/equity-mapper.xml`(65), `equityAssign-mapper.xml`(56), `lectureInaugurate-mapper.xml`(16), `sqls/equity/campaign/equityCampaign-mapper.xml`(89), `sqls/equity/payment/offerPayment-mapper.xml`(80), `virtualAccount-mapper.xml`(25), `sqls/equity/coupon/couponDetail-mapper.xml`(85), `coupon-mapper.xml`(22), `eventCoupon-mapper.xml`(14), `couponPool-mapper.xml`, `sqls/equity/news/equityNews.xml`(16), `sqls/equity/premium/contents/premiumContents-mapper.xml`(6), `sqls/equity/premiummembership/premiummembership-mapper.xml`(5), `sqls/equity/business/equityBusiness-mapper.xml`(8).
- **JSP**: `web/WEB-INF/jsp/ftcampaign/`, `equity/`, `waccount/`, `premiumMembership/`, `mastergroup/`. 대부분 페이지네이션 + 팝업 + 엑셀 버튼이 있는 관리자 페이지.
- **외부**: SmartSheet API, KSFC(증권금융), KSD(예탁결제원), NICE 본인인증, Inicis/NicePay(가상계좌).

### 6.3 리워드 심사 (`/reward/api/screenings/**`, `/reward/screening/**`)
- **Controller(API)**: `reward/screening/controller/ScreeningApiController.java`(12), `ScreeningManagerApiController.java`(10), `ScreeningRequirementApiController.java`(12), `PdScreeningApiController.java`(14), `ScreeningKCApiController.java`(8), `ReminderNoticeApiController.java`(8). 모두 `/reward/api/*` 계열 — **React 어드민이 호출하는 JSON 엔드포인트**.
- **Controller(UI)**: `ScreeningRequirementUiController.java`(6) — JSP 쉘.
- **의존 서비스**: `ScreeningService`, `ScreeningRequirementService`, `ScreeningManagerService`, `ReminderNoticeService`, `PdScreeningService`, `ScreeningKCService` (모두 `com.wadiz.web.reward.screening.service`).
- **Mapper**: `sqls/reward/screening/screening-mapper.xml`(4), `screening-log-mapper.xml`(1), `screening-doucment-file-mapper.xml`(1), `screening-requirement-mapper.xml`(1) — 심사 로직은 주로 **reward-http-client**(external funding-api)를 통해 이뤄지고 MyBatis XML 은 메타 정보만 보조.
- **핵심 흐름**: 심사자 배정 → 자료 업로드(S3 추정) → KC 검증 → PD 심사 → 승인/반려. `/reward/api/pd-screenings/campaigns/{id}/new-plan/approve` 등이 주요 상태 전이 엔드포인트.
- **외부**: `reward-amqp-client`(메시지 발행), `wave-audit-client`(감사로그), `com.wadiz.api.reward reward-http-client`, `wave-notification`(심사 결과 메일/알림).

### 6.4 리워드 정산 (`/reward/api/settlements/**`, `/settlement/**`)
- **Controller(API)**: `reward/settlement/controller/CampaignSettlementApiController.java`(10), `CampaignContractorApiController.java`(10), `CampaignSettlementFeeApiController.java`(8), `SaleSettlementApiController.java`(4), `AdvancedSettlementApiController.java`(10), `TaxInvoiceIssuanceApiController.java`(6), `SettlementResultApiController.java`(20), `SettlementModifiedFeeApiController.java`(8), `SettlementSearchApiController.java`(8), `SettlementStatusApiController.java`(18), `SettlementSubMallApiController.java`(11), `SettlementProxyApiController.java`(4), `SettlementClawbackProxyApiController.java`(8), `EstimatedSettlementApiController.java`(4), `FundingSettlementSubMallController.java`(4).
- **Controller(UI)**: `CampaignSettlementUiController.java`(10).
- **구 Controller**: `settlement/controller/WEBSettlementRewardController.java`(23) — 레거시 JSP.
- **Mapper**: `sqls/reward/settlement/settlement-search-mapper.xml`(56), `settlementResult-fee-mapper.xml`(16), `settlementResult-refund-mapper.xml`(20), `settlementResult-paid-mapper.xml`(5), `settlementResult-payment-mapper.xml`(5), `settlementResult-estimated-mapper.xml`(8), `settlement-feetype-mapper.xml`(3), `settlement-sales-mapper.xml`(6), `settlement-contractor-mapper.xml`(6), `optional-service-mapper.xml`(1), `rewardFeeRate.xml`(2) / `settlement/settlementReward-mapper.xml`(33).
- **외부**: 세금계산서 연동, 서브몰(SubMall) 결제 모듈 프록시.
- **JSP**: `web/WEB-INF/jsp/settlement/`, `performance/`, `refundShipping/`.

### 6.5 레거시 프로젝트 오픈 신청 (`/web/legacy/requestOpenProjectList`)
- **Controller**: `com/wadiz/web/legacy/controller/WEBLRequestController.java:54` (단 2개 매핑, 82줄).
- **흐름**: `SearchParamInfo` 로 검색 → `LRequestService.getRequestOpenProject(searchParamInfo)` → `sqls_legacy/lrequest-mapper.xml` → JSP `legacy/requestOpenProjectList.jsp`. `popRequestOpenProjectDetails` 팝업으로 상세.
- **특이**: `sqls_legacy/` 디렉토리는 이 매퍼 1개만 존재(`pom.xml:51`). 2015년 원형 그대로.
- **JSP**: `web/WEB-INF/jsp/legacy/requestOpenProjectList.jsp`, `popRequestOpenProjectDetails.jsp`.

### 6.6 어드민 메인 퀵메뉴 (`/manage/home/api/v*/quickmenu`)
- **Controller**: `com/wadiz/web/main/controller/MainController.java:25-130` — 35개 매핑. v1 → v4 까지 4세대 퀵메뉴 API 가 병존 (v1/v2/v3/v4 호환 유지).
- **의존 서비스**: `MainService`.
- **Mapper**: `sqls/event/event-mapper.xml` 등 이벤트 캐러셀용.
- **JSP**: 어드민 홈 `dashboard.jsp` 에서 React 위젯이 이 API 를 호출.
- **특징**: v1/v2 는 `List<QuickMenu>` 구조, v3 는 `QuickMenuAdmin`, v4 는 `Object` 로 스키마 완전 개방 — **단계적 확장 흔적**.

---

## 7. DB 접근

### 7.1 MyBatis 구성
- `src/main/resources/datasource/mybatis-config.xml` — typeAlias 다수 등록, `mybatis-typehandlers-jsr310` 으로 Java 8 Time 지원.
- 매퍼 XML 루트: `src/main/resources/sqls/` — 41 도메인 디렉토리 / 223 XML. 추가로 `sqls_legacy/lrequest-mapper.xml` 1개.
- 동적 쿼리 `<if test>` 사용 횟수: **1973회 / 95 파일** — web 본체(1057)보다 2배. Hotspot:
  - `account/account-mapper.xml`: 221
  - `community/boardArticle-mapper.xml`: 120
  - `reward/campaign/campaign-mapper.xml`: 109
  - `campaign/bannerSection-mapper.xml`: 91
  - `equity/campaign/equityCampaign-mapper.xml`: 89
  - `equity/coupon/couponDetail-mapper.xml`: 85
  - `equity/payment/offerPayment-mapper.xml`: 80
  - `payment/lecturePayment-mapper.xml`: 71
  - `wpartner/wpartner-mapper.xml`: 66
  - `equity/ftcampaign/equity-mapper.xml`: 65
  - `reward/settlement/settlement-search-mapper.xml`: 56
  - `equity/ftcampaign/equityAssign-mapper.xml`: 56
  - `sts/sts-mapper.xml`: 42
- **`statementType="CALLABLE"` (stored procedure) 사용**: `equity/ftcampaign/equity-mapper.xml` 에 2건(CALL 구문 직접 사용).
- SQL 대부분은 **대규모 동적 where** (검색 조건이 상태/기간/텍스트/플래그 10개 이상 붙는 어드민 전형적 패턴).

### 7.2 DataSource
- `spring/application/datasource-context.xml` + `datasource/jdbc-${env}.properties`. master/slave 분리 가정.
- MySQL 5.x(connector 5.1.10). Jasypt 로 암호화된 password.
- Redis Lettuce 5.3.7 — 세션(`RedisSessionRegistry`) 및 일부 캐시.
- ehcache 2.10.6 — 2차 캐시.

### 7.3 주요 테이블 도메인 (매퍼 기반)
- `account`: 회원 전체(`account-mapper.xml` 2761라인으로 가장 큼)
- `waccount`: 증권형 회원 (`waccount/waccount-mapper.xml`, `waccountMaster-mapper.xml`, `waccountEquityJoin-mapper.xml`, `waccountHistory-mapper.xml`)
- `campaign`: `campaign`, `campaignTag`, `campaignComment`, `rewardComment`, `bannerSection`, `campaignInvestInSide`
- `reward`: `campaign`, `screening*`, `settlement*`(15개 이상), `coupon*`, `comingsoon*`, `refund*`, `issue*`, `payment*`, `comment*`, `story`, `shipment`, `category`, `spaceExhibition`, `event`, `fundingsettlement`, `maker`, `memo`, `partner`
- `equity`: `campaign`, `ftcampaign`, `premiummembership`, `premium/contents`, `business`, `news`, `coupon*`, `payment` (virtualAccount, offerPayment)
- `startup`: `corporation`, `corporationContract`, `corporationInquiry`, `corporationInvestor`, `corporationTeamMember`, `irRequest`
- `community`: `boardMaster`, `boardArticle`, `boardComment`, `supportSignature`
- `wcoming`: `comingSoon`, `comingSoonRegister`
- `wpartner`: `wpartner`, `partnerInquiry`
- `wbenefit`: `promotion`
- `wevent`: `eventCompensation`
- `wopinion`: `opinion`
- `event`: `event`
- `payment`: `payment`, `rewardPayment`, `lecturePayment`
- `popup`: `noticePopup`
- `app`: `app`, `appBanner`
- `mail`: (템플릿/예약/로그)
- `wave/notification`: `message`, `newsletter*`, `sts-temp`
- `maker`: `makerQuiz`
- `affiliation`, `analytics` — 마케팅 연동 데이터
- `riskProject`: `riskproject`
- `rpa`: `makerinfo`
- `userData`: `userdata`
- `holiday`: `investHoliday`
- `KPIgoal`: 목표 관리
- `calendar`: 달력
- `file`, `ftfile`, `ftgoods`
- `collection`: `collection-display-exposure`
- `kr.wadiz.account`: `find`(구 계정찾기), `coupon`(구 쿠폰)
- `menu`: 메뉴 권한(`MenuAuthzDao` 에서 load)
- `personalverification`: 본인인증
- `progress`, `code`, `wgenid`, `excel`, `dashboard`, `ftgoods`

### 7.4 감사 로그
- `audit/audit-${env}.xml` 과 `wave-audit-client 1.0.5` 로 **관리자 행위 감사 로그**를 외부 audit 서비스에 기록. adm 고유 구성.

---

## 8. 외부 의존성

### 8.1 Wadiz 내부
- `wave-client/data/crypto/audit-client/notification-client/point-client/pay-client`
- `reward-http-client + reward-models + reward-amqp-client` — funding-api 와 MQ 브로커.
- `funding-core`, `equity-*`, `startup-*`, `payment-log-*`, `ksd-client`, `main-model`.

### 8.2 외부 SaaS/라이브러리
- **Smartsheet** (`smartsheet-sdk-java 2.2.5`) — 증권형 심사 진행 시트.
- **Google Authenticator** (`googleauth 1.5.0`) + **qrgen** — 관리자 2차 인증 OTP.
- **UADetector** (`uadetector-core 0.9.22`, `uadetector-resources 2014.10`) — 접속 로그/브라우저 식별.
- **iText 2.1.7** — PDF 계약서 생성.
- **JXLS** (`jxls-core 1.0.6`, `jxls-poi 1.0.9`, `jxls-jexcel 1.0.6`) — 엑셀 템플릿 엔진.
- **zip4j 1.3.2** — zip 압축.
- **Apache Commons CSV 1.9.0, Commons Net 3.9.0 (FTP)**.
- **NICE / Inicis / KSFC / KSD** — 결제·본인인증·증권형 인프라.
- **Redis(Lettuce)** — 세션/캐시.
- **Swagger** — `/web/swagger-ui.html` (permitAll).

### 8.3 내부 프록시
- `/web/apip/*` — `ApiProxyServlet` → 외부 API.

---

## 9. 이관·Deprecation 상태

### 9.1 이미 이관/리팩토링된 흔적
- `RewardApiAuthzInterceptor` **@Deprecated (2023.10)** 주석 — `AuthzInterceptor` 로 통합. `/reward/api/**` 권한 관리를 공통 인터셉터로 통합 중(`fw/interceptors/RewardApiAuthzInterceptor.java:22-25`).
- `MakerPageController.list(POST) @Deprecated Will be deprecated` — 메이커 리스트 조회 GET 으로 통합 (`startup/domain/maker/controller/MakerPageController.java:36-49`).
- 리워드 운영 UI 중 일부는 이미 **`/reward/api/**` BFF + React 어드민** 으로 이관되어 UI 컨트롤러(`*UiController`)는 JSP 쉘만 남음. 구체적으로:
  - `RewardCampaignUiController`, `CouponUiController`, `ScreeningRequirementUiController`, `CollectionUiController`, `RewardComingSoonUiController`, `RefundShippingUiController`, `CommentUiController`, `MakerCommunicationUiController`, `SatisfactionUiController`, `RewardSpaceExhibitionUiController`, `CampaignIssueUiController`, `CampaignSettlementUiController`, `NewsNotificationUiController` 등.
- **`webapp/store-app.jsp`** 가 `/resources/webapp/store-app/index.html` (React 빌드) 을 include — 스토어 어드민 영역은 완전 이관 완료 후 쉘 JSP 로만 존재.

### 9.2 아직 JSP UI 기반인 영역 (진한 레거시)
- **회원관리 전체**(account, waccount, juror): `WEBAccountController` 68매핑 + 2761라인 mapper.
- **증권형 캠페인 운영**(ftcampaign, equity/*): `WEBEquityController` 149매핑이 상징적.
- **레거시 오픈신청** (`legacy/*`).
- **팝업/이벤트/기획전/프로모션**(popup, wevent, wbenefit, promotion, collection, collectionExposure).
- **메일 템플릿/예약/마케팅 메일**(mail, send, sts).
- **앱 푸시/배너**(app/push, app/banner).
- **결제/정산 레거시 일부**(payment/lecturePayment 71 `<if>`, settlement/settlementReward 33).
- **쿠폰 구버전**(kr.wadiz.coupon, wcoupon).
- **스타트업/법인 관리**(startup/corporation 계열).
- **유저 데이터·리스크·RPA·KPI**(userData, riskproject, rpa, goalmanager).
- **커뮤니티 운영**(community — `WEBCommunityController` 42매핑). 본체는 이미 makercenter.wadiz.kr 로 이관했지만 어드민 측 백오피스는 잔존.

### 9.3 배포/CI
- `Jenkinsfile` 없음. 빌드: `mvnw clean install -P<env>`.
- `urlrewrite.xml` 이 빈 상태 — 필터는 남아있지만 URL 리다이렉트 룰은 최근 초기화됨. 운영 호스트 `adm.wadiz.kr` 에서는 필요한 리다이렉트가 없음을 시사.

### 9.4 커밋 활동도 간접 지표
- `/reward/api/**` 컨트롤러 약 50개는 지난 수년 간 지속 추가된 **React 어드민용 BFF** (신규 기능). 이 부분은 계속 활발히 개발.
- `@Deprecated` 주석 최신 시점 2023.10 — 코드 cleanup 진행 중.
- logback 전환(log4j-over-slf4j 브릿지) 이 있음 → 비교적 최근 현대화 작업.
- `reward-amqp-client 0.0.1-SNAPSHOT` 등 신규 stack 채택 — 활동 중.

---

## 10. 특이사항

1. **groupId `markmount` 동일** (pom.xml:4).
2. **investTag.tld 커스텀 태그**: `<investTag:codeNm type="..." code="..."/>` — 증권형 코드 표시 전용. web 본체의 `functions.tld` 와 다른 도메인 전용 TLD.
3. **AdminLTE 2 + Bootstrap 3.3.6 + jQuery 2.2.4**: 2016년 경 프론트 스택 고정. 브라우저 호환성 (IE 11 까지) 고려.
4. **dev-mode 표시**: `layout/default.jsp:74` — 운영 호스트(`adm.wadiz.kr`) 이외에서 열면 헤더 스트라이프 + body class 추가 → 실수 방지.
5. **Role 1/2/3**: `web-security.xml:87-88` — `1`(일반 관리자), `2`(매니저), `3`(슈퍼)로 이름 없이 숫자로만 관리.
6. **동시 로그인 1명 제한 + Redis 기반** (`RedisSessionRegistry`): 분산 서버에서도 중복 로그인 방지.
7. **OTP 2차 인증** (`/web/account/otpToken/**`, `googleauth + qrgen`) — 관리자 강화 인증.
8. **EnumContextListener** 로 Java enum 을 JSP EL 에서 바로 참조하는 독특한 패턴(`web.xml:104-119`).
9. **DispatcherServlet 이 `/web/*` 만 잡음**: 루트(`/`)는 기본 서블릿(정적 리소스)이 처리. 따라서 모든 실 URL 이 `/web/` 접두어 필요.
10. **audit-${env}.xml + `wave-audit-client`** — 관리자 행위 감사 로그를 별도 감사 서비스로 전송.
11. **reward-amqp-client** 로 MQ 이벤트 발행 — 심사/정산 상태 변경을 다른 서비스에 전파.
12. **logback + log4j-over-slf4j 브릿지** — log4j 1.x 코드 호환.
13. **JXLS 엑셀 템플릿 엔진** — 운영팀이 수시로 요구하는 복잡 엑셀(병합/서식)을 템플릿 기반으로 빠르게 생성.
14. **Smartsheet 통합** — 증권형 심사에서 Smartsheet 를 워크플로우로 사용.
15. **Jersey 이 어드민에선 거의 안 쓰임**: pom 에는 들어있지만 Jersey 서블릿 매핑이 없음. 라이브러리만 컴파일에 포함.
16. **urlrewrite.xml 이 빈 상태** — 필터는 로드되지만 실제 룰 없음 (`<urlrewrite></urlrewrite>`). 과거 유물.
17. **Spring Security 3.2.5** — 2014년 릴리즈. OAuth2 지원은 전혀 없고 세션+폼로그인+remember-me만.
18. **`kr.wadiz.*` 병존**: `kr.wadiz.membership.management.*`, `kr.wadiz.coupon.*`, `kr.wadiz.account.*` 는 신규 네이밍 규칙으로 분리된 영역. 일부는 web 본체와 공유되는 `kr.wadiz.infrastructure.*` 같은 인프라 라이브러리 도입의 전조.
19. **한영 혼용 주석 + 한글 디렉토리명**: `/WEB-INF/jsp/kr/`(한국 국가코드) 등 특정 국가 리소스 분리.
20. **`sqls_legacy/` 디렉토리** 가 pom build include 에 별도 등록 — 과거 xml 을 원본 그대로 보존하는 격리 방침.
21. **컨트롤러 최대 매핑 수 랭킹**:
    - `WEBEquityController` 149 (증권형 운영)
    - `WEBAccountController` 68 (회원관리)
    - `EquityCampaignController` 63
    - `WEBCommunityController` 42
    - `WPartnerController` 37
    - `EquityStagePublishController` 34
    - `MainController`(manage) 35, `WEBPointController` 35
    - `WEBBannerSectionController` 38, `WEBSettlementRewardController` 23
22. **typeHandler 에 `mybatis-typehandlers-jsr310 1.0.2`** — `LocalDate/LocalDateTime` 지원(web 본체는 미포함).
23. **파일 업로드 두 계열 병존**: `servlets.com cos` (2002) + `commons-fileupload 1.3.1` → web 본체와 동일한 레거시 잔재.

