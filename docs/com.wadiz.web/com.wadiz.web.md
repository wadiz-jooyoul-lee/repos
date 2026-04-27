# com.wadiz.web 레거시 분석

> 대상 경로: `/Users/casvallee/work/repos/com.wadiz.web`
> artifactId: `markmount:com.wadiz.web` / packaging: `war`
> 최종 webpack manifest 업데이트: 2019-10-23 (`web/WEB-INF/jsp/winclude/_assetVersions.jsp:8`)

> 📅 **2026-04-27 Phase 2 승격** — 단일 파일에서 폴더 구조로 이전. 본 파일은 overview 만 담당하고, 상세는 분리 파일로:
> - [`api-endpoints.md`](./api-endpoints.md) — 303 controller / 1,987 `@RequestMapping` 전수
> - [`api-details/jsp-catalog.md`](./api-details/jsp-catalog.md) — **447 JSP** / 41 그룹 / 22 layout / 35 winclude (이전 "122개" 는 그룹 카운트였음 — 실제는 3.6배)
> - [`api-details/urlrewrite-and-layouts.md`](./api-details/urlrewrite-and-layouts.md) — urlrewrite 459줄 + Filter chain 11개 + ViewResolver + jsp-template-inheritance 트리
> - [`api-details/mybatis-mappers.md`](./api-details/mybatis-mappers.md) — 264 XML / 1,082 statement / 917 동적쿼리 / 19 SP / 147 typeAlias
> - [`api-details/screen-campaign-detail.md`](./api-details/screen-campaign-detail.md) — 리워드 캠페인 상세 (SPA 쉘 + SEO)
> - [`api-details/screen-payment-equity.md`](./api-details/screen-payment-equity.md) — 보상형 결제 + 투자형 청약
> - [`api-details/screen-account.md`](./api-details/screen-account.md) — 회원가입·로그인·OAuth
> - [`api-details/screen-mypage-and-main.md`](./api-details/screen-mypage-and-main.md) — 마이페이지 + 통합 메인

---

> 📅 **2026-04-26 master pull 보강** (23 커밋 fast-forward)
>
> ### 신규 추가 영역 (32 새 파일, +2,697 / −78)
> - **`reward/adapter/external/fundingapi/RewardChangeLogGateway`** — funding API 로 리워드 변경 이력 push (RWD-5462: 비노출/최종승인 알림)
> - **`reward/comment/model/`** 확장 — `MakerProjectCommentNewStatus`, `MakerProjectCommentSearch`, `MakerProjectCommentVo` (메이커 프로젝트 댓글 — 리뷰 + 포토 리뷰 통합 조회 RWD-5294)
> - **`reward/rewarditem/model/global/`** — `RewardBadge`, `RewardImage`, `RewardPricing` + Response DTO 글로벌 모델 추가 (해외 리워드 표준화)
> - **`reward/rewarditem/model/constant/`** — `BadgeType`, `DiscountType` (RWD-5374: 가격정책 원가 관리 삭제, ADD_ONLY → NO_DELETE 권한 변경)
> - **`reward/exception/ForbiddenException`**
> - **`reward/schedule/service/RewardDeliveryDateRangeCalculator`** (RWD-5362: 리워드 발송일 조회·저장·검증)
> - **`store/client/model/`** — `StoreContentResponse`, `StoreProductAggregationResponse`, `StoreProductInfoNoticeResponse`, `StoreProjectStatusCountsResponse`
> - **`common/wrapper/AppUserExceptionResponseWrapper`** — 앱 사용자 에러 응답 래퍼
> - **`.claude/commands/update-terms.md`** — 약관/정책 HTML 업데이트 슬래시 커맨드 (FE2-264)
> - 정책 HTML 신규 (`web/resources/terms/`):
>   - `funding_maker_service_20260403.html`
>   - `funding_refund_20250923.html`
>   - `service_reward_20251226.html`
>
> ### 변경된 주요 컨트롤러 (10개)
> - `WEBCampaignController.java` (+113/−51) — RWD-5487 본펀딩 상세 비공개 처리 제거 등
> - `StoreProjectUiController.java` — CLIENT-59 SEO/JSON-LD 추가
> - `MakerApiController` (reward), `RewardMakerStudioSubmitApiController`, `CampaignScheduleV2ApiController`, `RewardMakerStudioSectionV2ApiController`
> - `MakerDashboardController` (mywadiz/dashboard), `GlobalUIController`, `GlobalKoreaUIController`, `DiagnosisController`
>
> ### MyBatis SQL 변경
> - `reward/rewarditem/reward-mapper.xml` (+147줄) — 글로벌 reward 모델 응답 매핑 추가
> - `reward/comment/comment-mapper.xml` (+71줄) — 메이커 프로젝트 댓글 + 포토 리뷰 통합 쿼리
> - `reward/campaign/campaign-mapper.xml`, `maker/maker-mapper.xml`, `story/story-mapper.xml`, `comment/comment-image-mapper.xml` 소량 변경
>
> ### 삭제된 파일
> - `web/WEB-INF/jsp/campaign/detailSPA.jsp` — CLIENT-38 wRewardDetailSPA.java project 기반 SEO 시맨틱 HTML 로 대체
> - `src/main/java/com/wadiz/web/url/dto/BitlyResponseDto.java` — Bitly 단축 URL 의존 제거 (추정)
>
> ### 운영 변경
> - **RWD-5462** — 일정 > 오픈예정·본펀딩 즉시 오픈 기능 삭제
> - **RWD-5343** — Reward Pricing/Badge/Image History 적재 기능 삭제
> - **RWD-5483** — `file_service_api_host` URL 에 `/file` 경로 추가 (5개 환경 properties 일괄)
> - `web/robots.txt` — `/web/wcampaign/search` disallow 추가 (FE1-476)
>
> ### 분석 영향
> - **`docs/_flows/funding-detail.md`**: `WEBCampaignController#detail` 113줄 변경 — 비공개 분기 제거 등 동작 변경. 핵심 SQL 체인은 유지.
> - **`docs/_flows/comment.md`**: 메이커 프로젝트 댓글 + 포토 리뷰 통합 쿼리 추가. SQL 본문 일부 갱신 권장.
> - **`docs/_flows/store-detail.md`**: SEO/JSON-LD 추가 (CLIENT-59) — 시맨틱 HTML 향상.
> - **신규 `RewardChangeLogGateway`**: 리워드 수정 이력을 funding API 로 publish — funding 측 신규 endpoint 가능성. funding Phase 2 문서 보강 후보.

---

## 1. 개요

`com.wadiz.web` 는 `https://www.wadiz.kr` 본체를 구성하는 Spring 3.2 + JSP 레거시 WAR 프로젝트입니다. 리워드/투자(증권형) 펀딩 상세·청약·결제·마이페이지·커뮤니티 등 **와디즈 유저 사이드 거의 전 기능을 담고 있는 모놀리식 웹 서버**입니다.

- 브랜치 전략(README.md:5-9): `dev` → dev.wadiz.kr, `rc` → stg.wadiz.kr, `master` → www.wadiz.kr.
- Tomcat 서블릿 2.5 기반(`web/WEB-INF/web.xml:4`), `urlrewrite3.0` 필터로 레거시 URL을 신규 URL로 리다이렉트.
- `.frontend/` 에 별도 Node 워크스페이스가 존재하며, 일부 화면(iam, open-account, floating-buttons, personal-message, school, embed 등)은 `static-dev.wadiz.kr / static.wadiz.kr` 에 배포되는 React 번들을 JSP가 얇게 껴서 불러오는 **SPA 쉘 JSP** 구조입니다 (`com.wadiz.web/.frontend/chunks.config.js:1`, `web/WEB-INF/jsp/react/entries/iam.jsp:29-33`).
- 이미 이관 완료된 화면: React 앱으로 재개발된 iam(로그인/회원가입), open-account, floating-buttons, iam, school, personal-message, 일부 landing(about, wadiz2017, partners 등). 또한 `/studio/reward/**` 로 리다이렉트되는 스튜디오(`web/WEB-INF/urlrewrite.xml:53-54, 227-232`) 및 `makercenter.wadiz.kr` / `helpcenter.wadiz.kr` 로 완전 이관된 커뮤니티·헬프센터(`web/WEB-INF/urlrewrite.xml:112-130, 189-191`).
- 아직 남아있는 핵심: 리워드/투자 **펀딩 상세(`/web/campaign/detail/**`)**, **결제/청약(`/web/wpayment/*`, `/web/wpayment/equity/*`)**, **이벤트 기획전(`/web/wevent/**`)**, **wpartner / wcomingsoon / wevent / wpremium / 글로벌 커뮤니티** 등 SEO·상거래 흐름을 직접 렌더링하는 JSP. 특히 SNS 공유/봇 크롤링을 위한 서버 사이드 OG/JSON-LD 생성은 전부 JSP 로직(`wRewardDetailSPA.jsp:50-146`)에 그대로 살아 있습니다.
- 커밋 활동도는 저장소 자체에 .git 이 없어 간접 추정이 필요한데, jasypt / funding-core 1.0.137-SNAPSHOT / reward-http-client 0.4.10-SNAPSHOT / payment-log-client / ksd-client 등 자체 마이크로서비스 클라이언트 의존성은 계속 bumping 되고 있어 **"코드는 동결 안 했지만 화면은 React 로 뽑아내는 중"** 이라는 이관 중간상태입니다.

규모 지표 (기준: Java `*Controller.java` + mapper + JSP):

| 항목 | 수 |
|------|---:|
| Controller 클래스 (`*Controller.java`) | 303 |
| Service 클래스 (`*Service*.java`) | 447 |
| Mapper/Dao (`*Mapper.java` / `*Dao.java`) | 658 |
| MyBatis mapper XML (`src/main/resources/sqls/**`) | 264 |
| JSP (`web/WEB-INF/jsp/**`) | 122 (상위 그룹만 — 서브디렉토리 포함 시 수백 건) |
| Stored procedure 정의 (`src/main/resources/sp/*.sql`) | 20 |

---

## 2. 기술 스택

`pom.xml` (참고: `com.wadiz.web/pom.xml`)

- JDK 1.8 (`pom.xml:11`), Maven WAR, `mvnw` wrapper 동봉.
- **Spring 3.2.10.RELEASE** (MVC + Security 3.2.5 + context/tx/webmvc). Spring Webflux 5.3.10 일부 병용 (`pom.xml:896-900`).
- Spring Boot starter 1.1.4 (단순 스타터만; 부트 런타임 아님).
- MyBatis 3.2.7 / mybatis-spring 1.2.2 / MySQL connector 5.1.48.
- JSP + JSTL 1.2 + **kwonnam jsp-template-inheritance 0.3** (레이아웃 상속: `layout:extends`, `layout:put`), custom TLD `functions.tld` (`https://wadiz.kr/tld/functions`) — `WadizCDNUtil.cdnURL*`, `StringUtil.escapeJson/escapeXml/convertToLinkFromURL` 등 JSP 커스텀 함수.
- Jersey 1.13 + Spring Servlet — `/api/*` JSON REST 엔드포인트 (legacy RESTful layer). `web.xml:158-193` 의 `Jersey Spring Servlet` 에 `com.wadiz.api.*` 16개 패키지 스캔.
- Smiley HTTP proxy servlet (`/web/apip/*` → main API, `/web/maker-proxy/*` → 메이커 API) — `web/WEB-INF/web.xml:195-213` 및 `com.wadiz.core.httpproxy.ApiProxyServlet`.
- URL rewrite: **tuckey urlrewritefilter 3.1.0** — 459라인 규칙 (`web/WEB-INF/urlrewrite.xml`).
- 외부 클라이언트 라이브러리: `com.wadiz.wave wave-client/wave-data/wave-crypto`, `wave.notification notification-client`, `wave.pay pay-client`, `wave.point point-client`, `api.reward reward-http-client`, `api.equity equity-http-client`, `api.main main-client`, `api startup-client`, `api payment-log-client`, `api.ksd ksd-client`, `funding.core funding-core` — 전부 wadiz 내부 SNAPSHOT.
- 결제/인증 SDK: `nicepay-lite 0.9.24`, `inicis inipay 5.0`, `ExecureCrypto`, `KSFCclient`(한국증권금융 증권형), `NiceID.Check`.
- 기타: ehcache 2.10.6, jasypt-spring31 1.9.2 (`encKey=!wadiz@` 프로퍼티 암복호화 키, `pom.xml:14`), jjwt 0.10.7 + nimbus-jose-jwt 9.31, bouncycastle 1.60 (Apple Sign In), googlecode/libphonenumber 8.12.57, emoji-java 5.1.1, jsoup 1.7.2, scala-library 2.10.4 (이상한 혼종 의존성), Spring mobile-device 1.1.3 (디바이스 감지).
- Swagger: `springfox-swagger2` 2.6.1 (UI 포함).
- 프런트 번들: webpack(4.x, `optionalDependencies`) 로 `.frontend` 워크스페이스 빌드 → `static-dev.wadiz.kr` / `static.wadiz.kr` 에 업로드. 구성: `.frontend/chunks.config.js` 에서 web/main/account/equity/reward/iam/personal-message/school/open-account/floating-buttons/landing/embed/sentry 청크 정의.

**Maven 프로파일**: local(기본)/dev/dev2/rc/rc2/stage/vqa1/real — WAR 빌드시 `classpath:*-${environment}.xml` 형태로 환경별 스프링 구성 로드 (`pom.xml:20-55`).

---

## 3. 아키텍처

### 3.1 배포/런타임 구조
Tomcat 위 WAR. `DispatcherServlet` 이 `/` 전역을 잡고, `Jersey Spring Servlet` 은 `/api/*`, `ApiProxyServlet`/`MakerApiProxyServlet` 가 `/web/apip/*` / `/web/maker-proxy/*` 를 잡습니다 (`web/WEB-INF/web.xml:141-213`).

### 3.2 필터 체인 (web.xml 순서)
1. `encodingFilter` (UTF-8 force)
2. `GlobalHeaderModifyingFilter` (`com.wadiz.api.fw.filter.GlobalHeaderModifyingFilter`)
3. `APIFilter` (`/api/*`)
4. `CJCookieServletFilter` — CJ Cookie 추적
5. `UrlRewriteFilter` (tuckey, 459 rules)
6. `CORSFilter` (`com.wadiz.web.fw.filter.CORSFilter`)
7. `XssEscapeServletFilter` — `xss/xss-servlet-filter-rule.xml` 기반
8. `oauth2LoginFilter` / `oauth2RedirectFilter` — Spring DelegatingFilterProxy → OAuth2 소셜로그인
9. `bearerTokenAuthenticationFilter` — `/web/v1/maker/*`, `/web/v2/membership`, `/web/apip/funding/supporters/my/fundings`, `/web/apip/store/orders/*` 에만 Bearer JWT 인증 적용 (`web.xml:117-129`)
10. `autoLoginFilter` — rememberMe/자동 로그인

이 다단계 필터 구성은 **"세션 기반 로그인 + 일부 API 만 Bearer token"** 하이브리드 인증 특징.

### 3.3 DispatcherServlet 구성 (`src/main/resources/spring/dispatcher/servlet.xml`)
- Component scan 타겟: `com.wadiz.web, kr.wadiz` (Controller/ControllerAdvice) + `com.wadiz.core` (Repository).
- 네 개의 커스텀 `HandlerMethodArgumentResolver`: `DeviceWebArgumentResolver`(mobile-device), `DeviceTypeResolver`, `ServiceRegionCookieValueResolver`, `ServiceRegionHeaderResolver` — i18n / 디바이스 / 서비스 리전 분기 주입.
- 두 개의 ViewResolver 체인: `ContentNegotiatingViewResolver`(order=1, JSON 전용) → `BeanNameViewResolver`(order=0, download 뷰들) → `InternalResourceViewResolver` → `/WEB-INF/jsp/*.jsp` (order=2).
- AOP: `RequiredCertifyAspect`(본인인증 필수 가드), `RecaptchaAspect`, `EncryptAspect`(프로퍼티/DTO 복호화).
- 다운로드용 뷰 빈 4종: `download`(FileDownload), `downloadExcel`, `downloadFile`(DownloadView), `downloadZip`(ZipDownloadView), `financeDownloadFile`(증권형 전용), `makerDownloadFile`.
- `SuffixPatternDisabler` — Spring 3.2 기본 동작인 `.json/.xml` suffix pattern matching 끄는 BeanPostProcessor (수동 ajax 엔드포인트 충돌 회피).
- Multipart: `WadizCommonsMultipartResolver` (자체 래퍼).

### 3.4 애플리케이션 ContextConfig (`web/WEB-INF/web.xml:221-239`)
환경별 로드되는 XML 14개: `proxy/proxy-${env}.xml`, `point-${env}.xml`, `reward-${env}.xml`, `equity-${env}.xml`, `user-${env}.xml`, `pay-${env}.xml`, `main-${env}.xml`, `root-context.xml`, `datasource-context.xml`, `searcher-${env}.xml`, `startup-${env}.xml`, `payment-log-${env}.xml`, `ksd-${env}.xml`, `cache-${env}.xml`, `message/notification-${env}.xml`.

각 XML 은 해당 도메인의 wave/api client Bean 을 환경별 호스트로 초기화하는 용도.

### 3.5 Java 패키지 최상위

`com/wadiz/` 하위:
- `api/*` — Jersey REST 엔드포인트 (20+ 도메인: account, app, campaign, ftaccount, ftcampaign, login, notification, waccount, wcampaign, wcode, wmain, wmypage, wpoint, store, startupApp, membership, social, error, fw, signature, session2token, signature)
- `core/*` — 도메인 서비스/DAO 계층. campaign, account, progress, reward(screening/settlement/coupon/comingsoon/refund/comment), equity, waccount, wmain, wcampaign, wpartner, wsub, statistics, notification, payment 등 86 서브패키지.
- `web/*` — Spring MVC 컨트롤러 + web-layer 서비스/DTO. 80+ 서브패키지. 대표: `campaign`, `wcampaign`, `wmain`, `wmypage`, `wpayment`, `wpurchase`, `waccount`, `login`, `mywadiz`, `supporter`, `supporterclub`, `storage`, `store`, `wiplicense`, `wevent`, `wboard`, `wpartner`, `wcomingsoon`, `ftexauth`, `redirect`, `reward/*`, `equity/*`, `marketing`, `newsletter`, `popup`, `maker`, `global`, `globalkorea`.
- `kr/wadiz/*` — 일부 신규 모듈(`kr.wadiz.infrastructure.signature.v3` 등). Component-scan 대상으로 포함 (`servlet.xml:29`).

### 3.6 외부 통신 패턴
- **API Gateway 프록시**: `/web/apip/*` → `ApiProxyServlet` → 내부 main-api(funding-api). 프런트 JS 가 `/web/apip/funding/...` 을 치면 서버가 세션 쿠키를 붙여 백엔드로 포워딩.
- **Maker API 프록시**: `/web/maker-proxy/*` → studio/maker BFF.
- `GlobalFundingGateway`(`com.wadiz.web.reward.adapter.external.fundingapi`) — `WebClient` 로 funding-api 직접 호출 (상세, AI 요약, 스토리, 상품정보 고시 등).

---

## 4. 페이지·URL 구조

URL은 대부분 `/web/*` 접두어(과거 `/ko/Campaign/Details/*` 호환성 유지). `@RequestMapping` 은 class-level + method-level 혼합.

### 4.1 URL prefix 요약표

| URL prefix | 용도 | 대표 Controller (path) | JSP 경로 |
|---|---|---|---|
| `/web/main`, `/web/wmain` | 통합 메인 (리워드 기본, 메인·얼리버드·플랜드·마이·모어) | `web/wmain/controller/WMainController.java:86` | `wmain/main.jsp` |
| `/web/winvest/main`, `/web/wmain/main` | 투자(증권형) 메인 | `web/wmain/controller/WInvestMainController.java` | `wmain/wmain.jsp` |
| `/web/wreward/main`, `/web/wreward/collection/*` | 리워드 메인/컬렉션 | `web/wmain/controller/WRewardMainController.java` | `wmain/wreward/*.jsp` |
| `/web/campaign/detail/{campaignId}`, `/web/campaign/detail/reward-info/{id}`, `/web/campaign/detail/qa/{id}`, `/web/campaign/detail/fundingInfo/{id}`, `/web/campaign/detailPost/{id}`, `/web/campaign/detailBacker/{id}` | 리워드 캠페인 상세(SPA 쉘 + SEO 서버 렌더) | `web/campaign/controller/WEBCampaignController.java:67,116,140,166,193` | `wlayout/wRewardDetailSPA.jsp`, `campaign/detailQASPA.jsp`, `campaign/detailPostSPA.jsp`, `campaign/detailBackerSPA.jsp` |
| `/web/wcampaign/*` | 캠페인 검색/지지서명/리워드서명 | `web/wcampaign/controller/WSearchCampaignController.java:42`, `WWEBCampaignSignatureController.java:15`, `WWEBRewardSignatureController.java:24`, `WWEBInvestSignatureController.java:24` | `wcampaign/*.jsp` |
| `/web/wpayment/*`, `/web/wpayment/handbook`, `/web/wpayment/error/{type}`, `/web/wpayment/complete` | 리워드 결제 + 약관 + 본인인증 메일코드 | `web/wpayment/controller/WPaymentController.java:84` | `wpayment/app.jsp`, `wpayment/handbook.jsp`, `wpayment/complete.jsp`, `wpayment/error.jsp` |
| `/web/wpayment/equity/*` | 증권형 청약 결제 | `web/wpayment/controller/WPaymentEquityController.java` | `wpayment/equity/*.jsp` |
| `/web/wpurchase/*` | 리워드 결제(신 플로우) | `web/wpurchase/controller/WEBPaymentController.java` | (주로 JSON) |
| `/web/account/login`, `/web/account/my`, `/web/waccount/*` | 로그인/회원가입/마이(일반/투자/마케팅/드롭아웃) | `web/waccount/controller/WAccountRegistController.java:72`, `WAccountMyController.java:36`, `WAccountSocialController.java`, `WAccountEquityController.java`, `WAccountPlusController.java` 등 17개 | `waccount/*.jsp`, `winclude/*.jsp` |
| `/web/mywadiz/*` | 마이페이지(신버전, 리워드 결제내역/참여) | `web/mywadiz/**/controller/*.java` | `mywadiz/*.jsp` |
| `/web/wmypage/*` | 마이페이지(구버전, 지금은 구 URL은 대부분 redirect) | `web/wmypage/controller/*` | `wmypage/*.jsp` |
| `/web/wevent/{id}`, `/web/wevent/{slug}` | 통합 이벤트/기획전 | `web/wevent/controller/WWEBEventMainController.java` | `wevent/*.jsp` |
| `/web/wcomingsoon/*`, `/web/wreward/comingsoon/*` | 오픈예정 | `web/wcomingsoon/controller/WComingsoonController.java`, `WRewardComingSoonController.java` | `wcoming/*.jsp` |
| `/web/wpartner/detail/{slug}` | 파트너 상세 (외부 /partner/{slug} redirect 대상) | `web/wpartner/controller/*` | `wpartner/*.jsp` |
| `/web/wboard/*` | 지지서명 게시판 | `web/wboard/controller/*` | `wboard/*.jsp` |
| `/web/wcommunity/*`, `/web/ftcommunity/*`, `/web/wcast/*` | (전량 `makercenter.wadiz.kr` 로 301 redirect) | urlrewrite only | — |
| `/web/fthelpCenter/*` | (`helpcenter.wadiz.kr` 로 301 redirect) | urlrewrite only | — |
| `/web/oauth/*`, `/web/login/*` | 소셜로그인(페이스북/카카오/네이버/애플/구글/라인) + 자체 로그인 | `web/login/*`, `web/oauth/*` 및 `oauth2LoginFilter` | `login/*.jsp` |
| `/web/v1/maker/*` | 메이커 BFF (Bearer 토큰) | `web/maker/**/controller/*.java` | JSON |
| `/web/v2/membership/*` | 프리미엄 멤버십 (Bearer 토큰) | `web/membership/controller/*` | JSON |
| `/web/marketing/*`, `/web/marketing/checkUnsubscribeKey/*` | 마케팅 수신거부 | `web/marketing/controller/*` | `marketing/*.jsp` |
| `/web/newsletter/*`, `/web/main/maker/subscribe` | 메이커 뉴스레터 | `web/newsletter/controller/*`, `WMainController.java:198` | `newsletter/*.jsp` |
| `/web/wiplicense/*` | IP 라이선스 파트너(빙그레/디즈니/넥슨 등) | `web/wiplicense/controller/IPLicenseController.java` | `wiplicense/*.jsp`, `wiplicense/fanzmaker/*.jsp` |
| `/web/wlive/*` | 와디즈 라이브 | `web/wlive/controller/*` | `wlive/main.jsp` |
| `/web/wsub/*` | 서브 페이지(Easy Card, 메이커 가이드 등) | `web/wsub/controller/WSubController.java` | `wsub/*.jsp` |
| `/web/embed/*` | 임베드 위젯 | `web/embed/controller/EmbedController.java` | `embed/*.jsp` |
| `/web/global/*`, `/web/globalkorea/*` | 글로벌 크라우드펀딩(WEN) | `web/global/controller/GlobalUIController.java`, `GlobalKoreaUIController.java` | `global/*.jsp`, `global-korea/*.jsp` |
| `/web/school/*` | (구) 와디즈 스쿨 — 리다이렉트 대상 | `web/school/**` | `school/*.jsp` (레거시) |
| `/web/redirect/hashkey/*`, `/web/redirect/keyword/*` | 단축 URL 리다이렉트 | `web/redirect/controller/*` | — |
| `/web/wterms/*`, `/web/waccount/wAccountLogin` 등 | 약관/계약/본인인증 | `web/wterms/*`, `web/waccount/*` | `wterms/*.jsp` |
| `/web/diagnosis/ping` | 헬스체크 | `web/diagnosis/controller/DiagnosisController.java` | JSON |
| `/api/*` | (Jersey) account/campaign/ftcampaign/login/notification/waccount/wcampaign/wcode/wmain/wmypage/wpoint/store/startupApp/membership/social | `com.wadiz.api.**` | JSON |
| `/web/apip/*` | 외부 API 프록시 (main-api / funding-api) | `com.wadiz.core.httpproxy.ApiProxyServlet` | JSON |
| `/web/maker-proxy/*` | maker-api 프록시 (스튜디오 SPA 용) | `com.wadiz.core.httpproxy.MakerApiProxyServlet` | JSON |
| `/resources/**`, `/wwwwadiz/**`, `/favicon.ico` | 정적 | mvc:resources | — |

### 4.2 JSP 최상위 그룹 (`web/WEB-INF/jsp/*`)
`account`, `campaign`, `catchup`, `community`, `embed`, `equity`, `error`, `ftexautn`, `funding2015`, `global`, `global-account`, `global-korea`, `include`, `linkprice`, `makerprofile`, `mobile`, `mywadiz`, `oauth`, `personalverification`, `react`, `school`, `startup`, `supporterclub`, `video`, `waccount`, `wboard`, `wcampaign`, `wcoming`, `wevent`, `winclude`, `wiplicense`, `wlayout`(레이아웃 템플릿), `wlive`, `wmain`, `wmypage`, `wpage`, `wpartner`, `wpayment`, `wpersonalmessage`, `wpremium`, `wpurchase`, `wsub`, `wterms`.

`wlayout/` 는 kwonnam jsp-template-inheritance 의 레이아웃 베이스: `common.jsp`, `mainCommon.jsp`, `wmeta.jsp`, `wcommon.jsp`, `wAwardsCommon.jsp`, `wGlobalCommon.jsp`, `wnoLayout.jsp`, `wnofooter.jsp`, `wRewardDetailSPA.jsp`, `_header.jsp`, `_footer.jsp`, `ftCommunity.jsp` (`jsp-inheritance-prefix = /WEB-INF/jsp/wlayout/`, `web.xml:258-262`).

### 4.3 urlrewrite 주요 패턴 (`web/WEB-INF/urlrewrite.xml`)
459라인 / 외부 유입 URL 호환성 유지에 집중.
- `/partner/**`, `/crowd/**`, `/sbsinvestor`, `/nhcrowd` → `/web/wpartner/detail/*`
- `/Campaign/Details/*`, `/ko/Campaign/Details/*` → `/web/campaign/detail/*` (301)
- `/Campaign/Edit/*`, `/web/campaign/edit/*`, `/web/campaign/opening` → `/studio/reward/*` (301) — **이미 studio(React) 로 이관된 화면들**
- `/web/wcommunity**`, `/web/wcast**`, `/web/ftcommunity**`, `/web/m/ftcommunity**` → `https://makercenter.wadiz.kr` (전부 외부 이관)
- `/web/fthelpCenter**` → `https://helpcenter.wadiz.kr`
- `/web/myreward` → `/web/mywadiz/payment-info` (구 마이 → 신 마이)
- `/web/wmypage/myfunding/info`, `/web/mywadiz/myfunding/info` → `/web/mywadiz/payment-info`
- `/web/wmypage/myfunding/fundinglist`, `/web/mywadiz/myfunding/fundinglist` → `/web/mywadiz/participation`
- `/web/wmypage/myfunding/rewardfundinglist` → `/web/mywadiz/participation`
- `/web/wevent/{slug}` (ces2024bywadiz, wday2404 등 50개+) → `/web/wevent/{id}` — 이벤트 slug → id 단일화
- `/web/brand/*`, `/web/collection/*` → `/web/wevent/*` (브랜드/컬렉션 → 통합 기획전)
- `/opensoon/*` → `/web/wcomingsoon/ivt/*`
- `/funding/{slug}/community/pledge-support` → `/funding/{slug}/community/support-share` (글로벌 커뮤니티 URL 변경)
- `/life` → `/web/wreward/main` (브랜딩 변경)
- `/web/store/best` → `/web/store/main?order=popular`

---

## 5. 컨트롤러·AJAX 엔드포인트 목록 (대표)

Spring 3.2 스타일로 **대부분 `@RequestMapping` 만 쓰고 `@GetMapping`/`@PostMapping` 은 거의 없음**. `@ResponseBody` + `produces = "application/json;charset=UTF-8"` 또는 `text/plain;charset=UTF-8` 패턴 + `@Controller`(아닌 `@RestController`). JSON view resolution은 `MappingJackson2JsonView` 기본 뷰.

### 5.1 페이지 렌더링 (JSP)

| URL | Method | Controller path:line | View |
|---|---|---|---|
| `/web/campaign/detail/{id}`, `/web/campaign/detail/reward-info/{id}` | GET | `web/campaign/controller/WEBCampaignController.java:67` | `wlayout/wRewardDetailSPA` |
| `/web/campaign/detail/fundingInfo/{id}` | GET | `WEBCampaignController.java:116` | `wlayout/wRewardDetailSPA` |
| `/web/campaign/detail/qa/{id}`, `/web/campaign/detail/qa/{id}/{commentType}` | GET | `WEBCampaignController.java:140` | `campaign/detailQASPA` |
| `/web/campaign/detailPost/{id}`, `/web/campaign/detailPost/{id}/news/{newsId}` | GET | `WEBCampaignController.java:166` | `campaign/detailPostSPA` |
| `/web/campaign/detailBacker/{id}` | GET | `WEBCampaignController.java:193` | `campaign/detailBackerSPA` |
| `/web/main`, `/web/main/earlybird`, `/web/main/planned`, `/web/main/my`, `/web/main/more`, `/web/main/empty` | GET | `web/wmain/controller/WMainController.java:86` | `wmain/main` |
| `/web/about` | GET | `WMainController.java:93` | `wmain/about` |
| `/web/wmain`, `/web/wmain/main` | GET | `WMainController.java:103` | redirect → `/web/main` |
| `/web/account/my` | GET | `web/waccount/controller/WAccountMyController.java:56` | `waccount/*` |
| `/web/waccount/wAccountRegistIntro` | GET | `WAccountRegistController.java:141` | 회원가입 인트로 |
| `/web/waccount/register/type/v2` | GET/POST | `WAccountRegistController.java:188` | 가입 타입 선택 |
| `/web/waccount/wAccountRegistCorp` | GET | `WAccountRegistController.java:259` | 법인 가입 |
| `/web/waccount/wAccountRegistFinish` | GET | `WAccountRegistController.java:442` | 가입 완료 |
| `/web/waccount/register/personal` | POST | `WAccountRegistController.java:460` | 개인 가입 처리 |
| `/web/wpayment/handbook` | GET | `web/wpayment/controller/WPaymentController.java:145` | `wpayment/handbook` |
| `/web/wpayment/{campaignId}` | GET/POST | `WPaymentController.java` (체크아웃 진입) | `wpayment/app` |
| `/web/wpayment/error/{type}` | GET | `WPaymentController.java:386` | `wpayment/error` |
| `/web/wpayment/complete` | GET | `WPaymentController.java` | `wpayment/complete` |
| `/web/waccount/wAccountLogin` | GET | `WAccountCommonController.java` | `waccount/wAccountLogin` |
| `/m/home` | GET | `web/login/controller/MOBLoginController.java:56` | redirect → `/web/wmain` |

### 5.2 AJAX / JSON 엔드포인트 (대표)

| URL | Method | Controller:line | 용도 |
|---|---|---|---|
| `/web/wcampaign/ajaxSearch/category/invest/keyword/{kw}/order/{order}` | GET | `WSearchCampaignController.java:65` | 투자형 통합검색 |
| `/web/wcampaign/ajaxSearch/category/reward/keyword/{kw}/order/{order}` | GET | `WSearchCampaignController.java:98` | 리워드 통합검색 |
| `/web/wcampaign/ajaxSearch/getExistRewardCampaignByUserId` | GET | `WSearchCampaignController.java:126` | 유저별 캠페인 존재 여부 |
| `/web/wcampaign/campaignSignature/ajaxSignatureStatus` | POST | `WWEBCampaignSignatureController.java:51` | 지지서명 상태 |
| `/web/wcampaign/campaignSignature/ajaxMySupportSignatureList` | POST | `WWEBCampaignSignatureController.java:62` | 내 지지서명 |
| `/web/wcampaign/campaignSignature/ajaxSupportSignatureList` | GET | `WWEBCampaignSignatureController.java:84` | 지지서명 리스트 |
| `/web/wcampaign/rewardSignature/ajaxRegisterRewardSignature` | POST | `WWEBRewardSignatureController.java:24` | 리워드 지지서명 등록 |
| `/web/wcampaign/investSignature/ajaxRegisterInvestSignature` | POST | `WWEBInvestSignatureController.java:24` | 투자 청약서명 등록 |
| `/web/campaign/ajaxUploadRewardCampaignEditorImage` | POST (multipart) | `WEBCampaignController.java:217` | 새소식 에디터 이미지 업로드 |
| `/web/campaign/ajaxFacebookSignature` | POST | `WEBCampaignController.java:227` | 페이스북 지지서명 |
| `/web/campaign/{campaignId}/participants` | GET | `WEBCampaignController.java:237` | 참여자 리스트 |
| `/web/campaign/{campaignId}/participants/my` | GET | `WEBCampaignController.java:244` | 내 참여자 리스트 |
| `/web/campaign/ajaxAskForEncore`, `/ajaxCancelEncore` | POST | `WEBCampaignController.java:253, 262` | 앵콜 펀딩 요청/취소 |
| `/web/wmain/ajaxGetBannerCommonList` | GET | `WMainController.java:145` | 메인 배너 공통 리스트 |
| `/web/main/recommendation/social`, `/web/main/v2/recommendation/social` | GET | `WMainController.java:154, 167` | 추천 소셜 피드 |
| `/web/main/maker/is-maker` | GET | `WMainController.java:179` | 메이커 여부 |
| `/web/main/maker/my-campaign` | GET | `WMainController.java:188` | 내 캠페인 |
| `/web/main/maker/subscribe` | POST | `WMainController.java:198` | 뉴스레터 구독 |
| `/web/main/track/section` | POST | `WMainController.java:215` | GA 섹션 트래킹 |
| `/web/waccount/ajaxIsValidCoupon`, `/ajaxRegisterCoupon`, `/ajaxModifyCoupon` | POST | `WAccountMyController.java:90, 110, 130` | 쿠폰 처리 |
| `/web/waccount/ajaxValidBusinessRegNum` | GET | `WAccountRegistController.java:278` | 사업자번호 검증 |
| `/web/waccount/ajaxSendSmsTokenByMarketing`, `/ajaxValidTokenByMarketing` | POST | `WAccountRegistController.java:287, 297` | 마케팅 SMS |
| `/web/waccount/ajaxAddPassword` | POST | `WAccountRegistController.java:322` | 비밀번호 추가 |
| `/web/waccount/ajaxRequestSendEmailConfirm`, `/ajaxRequestConfirmEmail` | POST | `WAccountRegistController.java:404, 414` | 이메일 인증 |
| `/web/waccount/ajaxValidPromotioncode` | POST | `WAccountRegistController.java:423` | 프로모션 코드 검증 |
| `/web/wpayment/getIsRealTime`, `/getIsHoliday`, `/getIsRefundTime` | GET | `WPaymentController.java:159, 171, 184` | 거래 가능시간 체크(증권형) |
| `/web/wpayment/ajaxTermsList` | GET | `WPaymentController.java:253` | 약관 리스트 |
| `/web/wpayment/ajaxGetGoodsList` | GET | `WPaymentController.java:274` | 결제상품 리스트 |
| `/web/wpayment/ajaxGetLimitAmount` | GET | `WPaymentController.java:294` | 투자한도 |
| `/web/wpayment/ajaxSendAuthCodeMail`, `/ajaxConfirmAuthCodeMail` | POST | `WPaymentController.java:551, 638` | 결제 본인인증 메일 |
| `/web/wpayment/ajaxSendEquityRiskNotificationMail` | POST | `WPaymentController.java:690` | 투자 위험고지 메일 |

Jersey(api) 계열은 별도: `/api/campaign/*`, `/api/login/*`, `/api/wmain/*`, `/api/wmypage/*`, `/api/wpoint/*`, `/api/store/*`, `/api/membership/*`, `/api/social/*` — JAX-RS `@Path` 어노테이션 기반. 대부분 모바일/앱 용 엔드포인트.

---

## 6. 주요 화면 상세 분석

### 6.1 리워드 캠페인 상세 (`/web/campaign/detail/{campaignId}`)
- **Controller**: `web/campaign/controller/WEBCampaignController.java:67-111` (`selectCampaign`).
- **의존 서비스**:
  - `CampaignService.getCampaignOverview(id)` — `com.wadiz.core.campaign.service.CampaignService`.
  - `RewardCampaignService.getStatus(id)` — `com.wadiz.web.reward.campaign.service.RewardCampaignService`.
  - `CampaignAccessPermitValidator.validate(...)` — 프리뷰/종료 접근권한 검사.
  - `CampaignService.getCampaignDefaultInfo(id)` — 오픈/종료 시간.
  - `GlobalFundingGateway.getProject(id, "ko")` — funding-api 호출(HTTP).
  - (봇 전용) `getAiSummary`, `getProjectProductInfoNotice`, `getProjectStory`, `CampaignService.getSignatureRewardOverview`, `CommentService.getComments`.
- **DAO / Mapper**:
  - `com.wadiz.core.campaign.dao.CampaignDao` → `src/main/resources/sqls/campaign/campaign-mapper.xml:selectCampaignDefaultInfo`, `selectCampaignOverview`, `selectSignatureRewardOverview`, `selectCampaignProgressSummary1`, `selectCampaignRewardList`, `selectCampaignSocialReach`.
  - SQL 패턴: MyBatis resultMap + `parameterType="map"` 중심. 매우 많은 `<if test>` 동적 쿼리(1057건 전체 중 `wcampaign/WInvestCampaignBaseInfo-mapper.xml` 107건, `community/communityArticle-mapper.xml` 145건 최다).
- **렌더링 JSP**: `web/WEB-INF/jsp/wlayout/wRewardDetailSPA.jsp` — `layout:extends name="mainCommon"` 구조. 실제 프로젝트 본문은 React 번들(`__staticPath_reward_main_js`)이 그리고, 이 JSP 는 **OG 메타태그 / JSON-LD schema.org (WebPage, Product, QAPage) / Twitter card / 봇 전용 HTML** 을 서버사이드로 렌더. If-Modified-Since/304 처리도 컨트롤러 단에서 수행 (`WEBCampaignController.java:81-98`).
- **외부 호출**: `globalFundingGateway` (funding-api HTTP), 모바일 디바이스 판별(`spring-mobile-device`).
- **인증/권한**: 세션 기반 (`SessionUtil.isAdminUser()`, `SessionUtil.isLoggedIn()`), 캠페인 비공개 상태면 `CampaignAccessPermitValidator` 가 예외 발생 → `serverError.jsp`.

### 6.2 리워드 결제 체크아웃 (`/web/wpayment/{campaignId}` 및 서브)
- **Controller**: `web/wpayment/controller/WPaymentController.java:84` (class mapping `/web/wpayment/*`, 813 줄로 프로젝트 내 최대 컨트롤러 중 하나).
- **포함 플로우**: 메인 진입 → 약관 페이지 `wpayment/handbook` → 결제 앱 진입 `wpayment/app` → 에러 `wpayment/error/{type}` → 완료 `wpayment/complete`.
- **ajax 엔드포인트 (17+)**: 약관 목록, 결제상품 목록, 투자한도, 본인인증 메일 코드 발송/확인, 증권형 위험 고지 메일, 실시간/공휴일/환불시간 체크.
- **주요 서비스**: `WPaymentService`, `PaymentService`, `NicePayService`(혹은 Inicis), `PointService`, `CouponService`, `AccountService`, `CampaignService`.
- **Mapper**: `sqls/reward/payment/payment-mapper.xml`, `payment-refund-mapper.xml`, `sqls/equity/payment/wpayment-mapper.xml` / `ftpayment-mapper.xml`.
- **외부 결제 연동**: NicePay(`kr.co.nicepay nicepay-lite`), Inicis(`inicis inipay 5.0`, `ExecureCrypto`) — pom 의존성으로 포함. 가상계좌/실명인증/IBK KSD 전산망 등 증권형 쪽은 `KSFCclient`/`NiceID.Check`.
- **뷰**: `wpayment/app.jsp`(결제 SPA 쉘), `wpayment/handbook.jsp`, `wpayment/complete.jsp`.

### 6.3 투자 청약 (증권형) (`/web/wpayment/equity/*` + `/web/waccount/equity/*`)
- **Controller**: `web/wpayment/controller/WPaymentEquityController.java` (약 700줄) + `web/waccount/controller/WAccountEquityController.java`, `WAccountJoinEquityController.java`.
- **특징**: 한국증권금융(KSFC) 예치금 계좌 API 직접 통신(`KSFCclient`), 투자 한도/본인인증 플로우, 증권신고서 위험고지, 청약확인서 PDF 생성(`pdfbox`).
- **Mapper**: `sqls/equity/**` 전체 — `ftcampaign-mapper.xml`, `equityCamapign-mapper.xml`, `ftpayment-mapper.xml`, `wpayment-mapper.xml`, `premiumMembership.xml`, `wpremiummain-mapper.xml`.
- **관련 JSP**: `web/WEB-INF/jsp/wpayment/equity*.jsp`(equity1/2/3/3-1/4/equityReserved/equityFail), `web/WEB-INF/jsp/wsub/wEasyCard.jsp`, `web/WEB-INF/jsp/equity/*.jsp`.
- **외부**: KSFC 증권금융 전산망, Inicis/NicePay 가상계좌, SmartSheet 연동(adm 쪽과 공유).

### 6.4 마이페이지 리워드 결제내역 (`/web/mywadiz/*`, `/web/wmypage/*`)
- **Controller**: `web/mywadiz/**/controller/*.java`, `web/wmypage/controller/*`.
- **많은 구 URL 이 urlrewrite 로 `/web/mywadiz/*` 로 통일됨** (`web/WEB-INF/urlrewrite.xml:265-287`). 예: `/web/myreward`, `/web/wmypage/myfunding/info`, `/web/wmypage/myfunding/fundinglist`, `/web/mywadiz/myfunding/info`, `/web/mywadiz/myfunding/fundinglist` 등 모두 → `/web/mywadiz/payment-info` 또는 `/web/mywadiz/participation`.
- **서비스/DAO**: `WWEBRewardDashboardService`, `WEBCampaignService`, `sqls/mywadiz/dashboard/maker-dashboard-mapper.xml`, `sqls/wmypage/winvest-mapper.xml`, `wreward-mapper.xml`, `sqls/reward/funding/funding-mapper.xml`.
- **JSP**: `mywadiz/*.jsp`, `wmypage/*.jsp`.

### 6.5 회원가입/로그인 (`/web/waccount/*` + `/web/account/*`)
- **Controller**: `WAccountRegistController.java:72`(665줄), `WAccountMyController.java`, `WAccountSocialController.java`, `WAccountEquityController.java`(17개 WAccount 컨트롤러 중 등록/소셜/내정보/증권형가입/휴면/본인인증 담당).
- **React 전환 진행**: `/WEB-INF/jsp/react/entries/iam.jsp` 가 이미 iam 번들(`__staticPath_iam_main_js`) 을 로드하는 **SPA 쉘** 로만 동작 — 실제 UI 는 React `iam` 번들이 그립니다. 기존 JSP 는 세션 인증·이메일 검증·SMS 인증 AJAX 엔드포인트만 남아있음.
- **Mapper**: `sqls/account/account-mapper.xml`, `userageverification-mapper.xml`, `userprofile-mapper.xml`, `sqls/waccount/waccount-mapper.xml`, `waccountCommon-mapper.xml`, `waccountEquity-mapper.xml`, `waccountSocial-mapper.xml`.
- **외부**: NICE 본인인증(`NiceID.Check`), 페이스북/카카오/네이버/구글/애플/라인 OAuth (`oauth2LoginFilter`, `oauth2RedirectFilter` → `com.wadiz.web.oauth.*`).

### 6.6 통합 메인 (`/web/main`, `/web/wmain`)
- **Controller**: `WMainController.java:86`(`home`), `WInvestMainController.java`(투자 메인), `WRewardMainController.java`(리워드 메인), `WStartupMainController.java`(스타트업), `WLiveMainController.java`(라이브), `PreOrderUiMainController.java`(오픈예정).
- **서비스**: `WMainService`, `WWEBMainService`, `MainApiService`(main-client로 main-api 호출), `WInvestSearchService`, `WRewardSearchService`, `StatisticService`, `NewsletterService`.
- **Mapper**: `sqls/wmain/wiosmain-mapper.xml`, `sqls/wcampaign/winvestsearch-mapper.xml`(43 `<if>` 동적쿼리), `wrewardsearch-mapper.xml`(11), `WInvestCampaignBaseInfo-mapper.xml`(107 `<if>` — 프로젝트 최대 동적 쿼리).
- **JSP**: `wmain/main.jsp`(통합 리워드 메인), `wmain/wmain.jsp`(투자 메인), `wmain/startupMain.jsp`, `wmain/makerCode.jsp`, `wmain/about.jsp`.
- **특이**: 메인은 대부분 `main.js` React 번들 쉘. 서버는 GA 추적 엔드포인트 `/web/main/track/section`, 배너 리스트, 메이커 구독 AJAX 제공.

---

## 7. DB 접근

### 7.1 MyBatis 구성
- `src/main/resources/datasource/mybatis-config.xml` — 147개 `typeAlias` 등록(`userInfo`, `campaignDefaultInfo`, `ftCampaignIRInfo`, `wUserSmsConfirmInfo` 등 대부분 `com.wadiz.core.*.model` 및 `com.wadiz.web.equity.domain.ftcampaign.model`), 3개 `typeHandler`(`WInvestAmountHandler`, `UuidTypeHandler`, `RewardOptionTypeHandler`).
- 매퍼 XML 루트: `src/main/resources/sqls/` — 40 도메인 디렉토리 / 264 XML.
- 동적 쿼리 `<if test>` 사용 횟수: 총 1057회 / 76 파일. **MyBatis dynamic SQL 의존도 매우 높음.** 주요 hotspot:
  - `wcampaign/WInvestCampaignBaseInfo-mapper.xml`: 107
  - `community/communityArticle-mapper.xml`: 145
  - `ftboard/ftboardArticle-mapper.xml`: 111
  - `wpartner/wpartner-mapper.xml`: 91
  - `ftboard/ftboardArticleComment-mapper.xml`: 74
  - `wboard/wBoardComment-mapper.xml`: 52
  - `wcampaign/winvestsearch-mapper.xml`: 43
- XML 내 `<select>/<insert>/<update>/<delete>` 중심. `statementType="CALLABLE"` 은 3건(`code/ftcommon-mapper.xml`) 정도로 적으며, **대부분 CRUD + 조건부 동적 where**.
- `SqlSessionType`: `com.wadiz.core.SqlSessionType.java`(`src/main/java/com/wadiz/core/SqlSessionType.java`) 는 master/slave(읽기/쓰기) 또는 DB2(`sqls_db2`) 분리용.

### 7.2 Stored procedure
`src/main/resources/sp/` 에 20개 `.sql` 원본 파일 — 배포 시 DB 측에서 수동으로 관리(소스 버전관리 용). 대표:
- `ProcCampaignContributionInsert.sql` — 캠페인 참여기여도 일배치
- `ProcStatsDailyRewardPerformanceInsert.sql`, `ProcStatsDailyInvestPerformanceInsert.sql`, `ProcStatsDailyFundingPerformanceInsert.sql` — 일간 통계
- `ProcInvestCampaignFinishProcessing.sql`, `ProcInvestCampaignStartProcessing.sql` — 증권형 캠페인 시작/종료 처리
- `ProcCancelInvestCoupon.sql`, `ProcEqCampaingStatus.sql`
- `getCampaignAllUsers.sql`, `getCampaignInterestedUsers.sql`, `getCampaignFinishSignatureUsers.sql` — 대용량 유저 추출(배치)
- `wadiz_raise_err.sql`, `InitCouponNo.sql`, `ProcSetSummationSignature.sql`, `ProcCampaignPopScoreInsert.sql`, `ProcCampaignRandomInit.sql`, `ProcStatsUserPerformanceInsert.sql`.

### 7.3 DataSource
- `spring/application/datasource-context.xml` 에 master/slave DBCP 풀 설정. `datasource/jdbc-${env}.properties` 에 JDBC URL/패스워드(jasypt 암호화).
- `spring/application/monitoring-spring-datasource.xml` — 성능 모니터링용 프록시 DataSource.
- MySQL 5.x (connector 5.1.48) / InnoDB 가정.
- **DB2 병용**: `sqls_db2/**/*.xml` — 과거 IBM DB2 기반 레거시 통계를 위한 별도 SqlSessionFactory 추정(완전 사용 여부는 빌드 include 에서만 확인).
- `sqls` 외에 `statistics/wadizexception-mapper.xml` 에서 예외 로그도 DB 에 적재.

### 7.4 주요 테이블 도메인
매퍼 이름에서 추론:
- `account`, `userageverification`, `userprofile`
- `campaign` 도메인: `campaign`, `campaignInfo`, `campaignCongratulation`, `maker-studio`, `campaign-marker`
- `reward` 도메인: `funding`, `screening`, `settlement`, `coupon`, `comment`, `comment-image`, `story`, `rewarditem`, `makercommunication`, `refund`, `comingsoon`, `category`, `shipment`, `openreservation`
- `equity` 도메인: `ftcampaign`, `equityCampaign`, `wpayment`, `ftpayment`, `premiumMembership`, `wpremiummain`, `premiumContentsBoard`, `equityNews`, `equityInvestor`, `equityMember`, `equityDashboard`
- `waccount`: `waccount`, `waccountCommon`, `waccountEquity`, `waccountSocial`, `waccountHistory`
- `community`: `communityArticle`, `boardMaster`, `boardArticle`, `boardComment`, `supportSignature`
- `board`: `personalmessage`, `personalmessage-inbox`
- `progress`: `progress-tip`, `progress`
- `notification`: `app`(푸시토큰), `newsletterSubscriber`, `message-mapper`, `sts-temp-mapper`
- `statistics`: `wadizexception`, `wOpinion`, `MenuPagesHis`, `RefererHis`
- `startup`: `corporationContract`, `irRequest`, `corporation`, `corporationInvestor`, `corporationInquiry`, `corporationTeamMember`
- `school`: `school`(레거시)
- `wsub`: `weasycard`, `wevent`
- `wpartner`: `wpartner`
- `popup`: `popup`
- `wcoming`: `wcomingSoon`, `comingSoon`
- `wevent`: `eventInfo`, `eventCompensation`
- `letz`: 마케팅
- `follow`, `feedback`, `membership`, `code`, `ftcommon`, `country`
- `userreport`, `rest`

---

## 8. 외부 의존성

### 8.1 Wadiz 내부 마이크로서비스 (`pom.xml`)
- `com.wadiz.wave`: `wave-client 3.0.29-SNAPSHOT`, `wave-data 1.1.15-SNAPSHOT`, `wave-crypto 1.0.3-SNAPSHOT`
- `com.wadiz.wave.notification notification-client 1.4.5-SNAPSHOT`
- `com.wadiz.wave.pay pay-client 1.0.4-SNAPSHOT`
- `com.wadiz.wave.point point-client 1.1.1-SNAPSHOT`
- `com.wadiz.api.reward reward-http-client 0.4.10-SNAPSHOT` / `reward-models 0.4.9-SNAPSHOT`
- `com.wadiz.api.main main-client / main-model 1.0.6-SNAPSHOT`
- `com.wadiz.funding.core funding-core 1.0.137-SNAPSHOT`
- `com.wadiz.api.equity equity-http-client 0.0.6-SNAPSHOT` / `equity-models 0.0.7-SNAPSHOT`
- `com.wadiz.api startup-client / startup-model 1.3.45-SNAPSHOT`
- `com.wadiz.api payment-log-client / payment-log-model 0.1.1-SNAPSHOT`
- `com.wadiz.api.ksd-client ksd-client 0.0.12-SNAPSHOT`

### 8.2 결제·본인인증
- NicePay `nicepay-lite 0.9.24`
- Inicis `inipay 5.0`, `INIpay_Sample 1.2`, `ExecureCrypto 1.0`
- 한국증권금융(KSFC) `KSFCclient 1.0`
- NICE 본인인증 `NiceID.Check 1.0`
- Apple Sign In: `bcpkix-jdk15on 1.60` (JWT 서명 검증)

### 8.3 SNS·OAuth·알림
- Facebook App ID `190622721088710`, Kakao app, Naver, Google, Apple, LINE(twitter4j 는 twitter 만 쓰는 듯). callback: `https://www.wadiz.kr/web/oauth/{provider}`.
- Braze(`web/braze/**` 및 `web/crmgateway/**` 추정) 관련 CRM 게이트웨이.

### 8.4 기타
- `org.jasypt jasypt-spring31 1.9.2` — 프로퍼티 암복호화(`encKey=!wadiz@`).
- `net.sf.ehcache 2.10.6` — 2차 캐시.
- `io.lettuce lettuce-core 5.1.6` + `netty-transport-native-epoll 4.1.33 (linux-x86_64)` — Redis 세션/캐시.
- `com.smartsheet smartsheet-sdk-java 2.2.5` (adm 공유).
- `org.apache.poi 3.14` + `poi-ooxml 3.14` — 엑셀 다운로드.
- `org.apache.pdfbox 2.0.24` — 청약서/계약서 PDF.
- `com.google.api-client 1.32.1`, `google-http-client-jackson2 1.32.1` — Google Sign-In, Drive 등.
- `com.wadiz.api ksd-client` — 한국예탁결제원(KSD) 연동.

### 8.5 CDN/정적자산
- `https://cdn.wadiz.kr/resources` — 이미지/공용 리소스.
- `https://static.wadiz.kr` / `https://static-dev.wadiz.kr` — **React 번들 배포 원천**(`file-real.properties:static_host`, `.frontend/static.config.js`).
- `https://www2.wadiz.kr` — `prev_site_url`. 구버전 와디즈 서브도메인.
- `https://app.wadiz.kr`, `https://adm.wadiz.kr`, `https://event.wadiz.kr` — 주변 도메인.

---

## 9. 이관·Deprecation 상태

### 9.1 이미 이관 완료 (urlrewrite 기준 외부 리다이렉트)
| From | To | 근거 |
|---|---|---|
| `/web/wcommunity**`, `/web/wcast**` | `makercenter.wadiz.kr` | urlrewrite.xml:112-120 (permanent) |
| `/web/ftcommunity**`, `/web/m/ftcommunity**` | `makercenter.wadiz.kr` | urlrewrite.xml:122-130 |
| `/web/fthelpCenter**` | `helpcenter.wadiz.kr` | urlrewrite.xml:189-191 |
| `/Campaign/Edit/*`, `/web/campaign/edit/*`, `/web/campaign/opening` | `/studio/reward/*` | urlrewrite.xml:53, 227 — **스튜디오 SPA 로 전량 이관** |
| `/studio/reward/*/funding/contractInfo` | `/studio/reward/*/settlementinfo` | urlrewrite.xml:286 |

### 9.2 내부 이관(SPA 쉘)
- `/WEB-INF/jsp/react/entries/iam.jsp` → iam React 번들(로그인/회원가입). 서버는 세션 + 이메일/SMS 인증 AJAX만 수행.
- `wRewardDetailSPA.jsp`, `detailQASPA.jsp`, `detailPostSPA.jsp`, `detailBackerSPA.jsp` → 각자 reward React 번들이 본문 렌더, JSP 는 SEO 메타/JSON-LD/봇 HTML/초기 project 데이터 주입.
- `wpayment/app.jsp` → payment React 번들.
- `/web/mywadiz/*` → mywadiz(account React 번들) + 일부 구 JSP.
- `/web/wcomingsoon/*` → coming React 번들.

`chunks.config.js` 에 정의된 React 번들과 JSP 연결 맵:
| 청크 | JSP 쉘 |
|---|---|
| `web` (공통 polyfill/wui/vendor/common) | 모든 JSP |
| `main` | `wmain/main.jsp`, `wmain/wmain.jsp` |
| `account` | `waccount/*.jsp`, `mywadiz/*.jsp` |
| `equity` | `equity/**`, `wpayment/equity*.jsp` |
| `reward` | `wlayout/wRewardDetailSPA.jsp`, `wmain/main.jsp` |
| `iam` | `react/entries/iam.jsp` |
| `open-account` | 계좌개설 |
| `personal-message` | `wpersonalmessage/*.jsp` |
| `school` | `school/*.jsp` |
| `floating-buttons` | 공통 플로팅 버튼 |
| `embed` | `embed/*.jsp` |
| `landing` | `wpage/*.jsp` (about, wadiz2017, partners, terms, bestmaker2017/2018) |

### 9.3 아직 JSP 로 강하게 남아있는 영역
- **리워드 결제 체크아웃** (`/web/wpayment/*`): `WPaymentController.java` 813 라인, 증권형/리워드 결제 전체 서버 로직.
- **증권형 청약**: `WPaymentEquityController.java`, `/web/wpayment/equity/*.jsp` — 한국증권금융/KSD 연동 SSR 중심.
- **이벤트 기획전** `/web/wevent/*`: id 기반이지만 JSP 서버 사이드 데이터 주입.
- **wpartner** `/web/wpartner/detail/{slug}`: 파트너 상세 SEO 페이지.
- **wiplicense IP 라이선스 파트너**(빙그레/디즈니/넥슨/현대/라이엇/이코닉스/진로): 고유 JSP 페이지 다수.
- **글로벌(en) 커뮤니티**(`/funding/{slug}/community/*`) — 2024 이후 URL 변경만 되어 있고 JSP 로직 존재.
- **레거시 투자 약관/공지/본인인증** (`wterms/*.jsp`, `waccount/*.jsp`).

### 9.4 Jenkins/CI
루트에 `Jenkinsfile` 없음. 배포는 `mvnw clean install -Dmaven.test.skip=true` (README.md:14) + `package.json scripts.deploy` (`.frontend/scripts/deploy/createStaticPath.js`) 로 프런트 매니페스트를 JSP 에 주입 후 WAR 빌드.

### 9.5 커밋 활동도 간접 지표
- `.frontend/scripts/deploy/createStaticPath.js` 는 매 배포마다 `_assetVersions.jsp` 를 regenerate. `_assetVersions.jsp:8` 주석에 **Last Updated: 2019-10-23 15:15:34** — 해당 번들은 2019년 이후 갱신되지 않은 레거시 webpack build.
- 한편 `chunks.config.js` 의 iam/floating-buttons 는 `manifestPath: '/static/iam/manifest.json'` 식으로 **외부 CDN static-* 호스트**를 가리키므로, 신규 React 앱은 본 레포 외부(`wadiz-frontend` 모노레포로 추정) 에서 빌드/배포됨.
- adm 과 달리 이쪽은 본체 서비스라 커밋은 꾸준: 최근 임포트 클래스에서 `equity-http-client 0.0.6`, `funding-core 1.0.137`, `main-client 1.0.6`, `ksd-client 0.0.12` 등 소수점 두자리 패치 버전이 관찰됨 → **적극 개발 중**.

---

## 10. 특이사항

1. **groupId `markmount`**: 회사 브랜드가 MARKMOUNT → Wadiz 로 바뀐 후에도 Maven groupId 는 유지(pom.xml:4). 소스 저작권 주석(`@COPYRIGHT © MARKMOUNT ALL RIGHTS RESERVED.`)도 그대로.
2. **Spring 3.2 + Spring Security 3.2**: 2014년 릴리즈 라인. JDK 1.8 이 최저선. Spring Boot 1.1.4 는 starter 일부만 차용(본체는 XML 설정).
3. **Jersey 1.13 + Spring MVC 혼재**: `/api/*` 는 Jersey(JAX-RS 1.1 기반), `/web/*` 는 Spring MVC. 같은 세션·같은 DAO 를 공유하지만 프레임워크 분리.
4. **urlrewrite 459라인**: 역사적 URL 전부 유지(구 `/Campaign/Details/*` → 신). 50+ `/web/wevent/{slug}` 리다이렉트로 이벤트 슬러그 → id 정리.
5. **jsp-template-inheritance (kwonnam)**: Django/Jinja 식 `{% extends %}{% block %}` 을 JSP 에서 쓰게 해주는 한국산 라이브러리. `web.xml:258-266` 에서 prefix/suffix 지정. 러브콜 받기 어려운 특수 라이브러리.
6. **커스텀 TLD `functions.tld`**: `wdz:cdnURL`, `wdz:cdnURL2`, `wdz:cdnURL3`, `wdz:escapeJson`, `wdz:convertLink` 등 JSP 유틸. `com.wadiz.core.fw.utils.WadizCDNUtil` 로 image-proxy(dpr, crop, mark) 파라미터 생성.
7. **Scala 2.10.4 의존성**: 이유 불명. 일부 통계/수학 라이브러리 때문에 끌려들어온 과거 잔재.
8. **servlets.com cos 05Nov2002**: 2002년 버전 파일업로드 라이브러리. Commons FileUpload 와 병존 → 레거시 코드 잔존 증거.
9. **jodd 3.3.7 / json-simple 1.1.1 / gson 1.7.1 / fasterxml 2.6.2 / jackson mapper-asl 1.9.13(adm)**: JSON 라이브러리가 4-5개 병존. 뷰마다 사용 라이브러리가 다름.
10. **SuffixPatternDisabler** (`com.wadiz.web.fw.config.SuffixPatternDisabler`): Spring 3.2 default 인 `.json` suffix 매칭을 끄기 위한 BeanPostProcessor. `/ajaxSomething.json` 같은 의도치 않은 매칭 방지.
11. **AOP Aspect 3종**: `RequiredCertifyAspect` (본인인증 필수 메서드), `RecaptchaAspect` (reCAPTCHA 검증), `EncryptAspect` (DTO 필드 자동 복호화) — 파라미터 레벨 관심사 분리.
12. **jasypt encKey `!wadiz@`** 는 pom.xml property 로 평문 저장되어 있음(pom.xml:14). 빌드 시 resource filtering 으로 properties 파일에 주입. 보안상 취약하므로 추후 교체 필요 지점.
13. **`sitemap.xml`, `robots.txt`, `apple-app-site-association`, `service-worker.js` 가 WAR 루트(`web/`) 에 존재**: 웹 본체이므로 SEO/앱 연동 리소스가 직접 서빙됨. `apple-app-site-association` 에는 Universal Link 룰.
14. **mvnw 1.8**: Maven Wrapper 동봉.
15. **security-constraint 로 JSP 직접 접근 차단** (`web.xml:297-313`): `*.jsp` URL 에 auth-constraint 로 직접 접근 불가. 반드시 Controller 경유.
16. **한영 혼용 주석**: `@author 김종성`, `2016.11.04 문종배 회원관리 - 청약개편` 등 한국어 주석 다수. 주석에서 원저자(김종성) 와 공동 저자(이판호, 문종배, 권정훈) 이름 확인 가능.
17. **모바일 분리 흔적**: `/WEB-INF/jsp/mobile/` 디렉토리가 존재하며 `spring-mobile-device 1.1.3` 으로 User-Agent 감지. 반응형 전환 이후에도 일부 mobile JSP 잔존(`mobile/equity/*.jsp`).
18. **기획전/이벤트 redirect 전량 하드코딩**: `/web/wevent/{slug}` 50여개가 urlrewrite.xml 에 일일이 기술(1:1 매핑). 신규 이벤트 추가시 urlrewrite 수정 필요 → 운영 부담 포인트.

