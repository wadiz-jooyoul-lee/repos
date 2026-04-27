# com.wadiz.web — JSP 전수 카탈로그

> **447 JSP / 41 최상위 그룹 / 22 레이아웃 / 35 winclude / 9 error / 1 React entry**
> 위치: `/Users/casvallee/work/repos/com.wadiz.web/web/WEB-INF/jsp/`
> 기존 단일 파일(`com.wadiz.web.md`) 의 "JSP 122개" 는 *최상위 그룹 카운트* 였음 — 실제 .jsp 파일은 **447개**.

## 1. 그룹별 파일 분포

| 그룹 | 파일 수 | 주요 레이아웃(부모) | 비고 |
|---|---:|---|---|
| `wterms` | 63 | `wterms`(30), `wtermsInvest`(12) | 약관·정책 |
| `waccount` | 47 | `account`(18), `wAccount`(14) | 계정·인증 |
| `equity` | 39 | `ftCommon`(8), `ftEmpty`(6), `wcommon`(4) | 투자형(증권형) — campaign/dashboard/payment/account/guide |
| `wmain` | 35 | `mainCommon`(31) | 통합 메인 (시즌/테마 변형) |
| `winclude` | 35 | (include only) | head/script/style/tracking/asset version |
| `mobile` | 33 | `ftCommunity`(3) | 모바일 — equity 28 / school 4 / footer 1 |
| `wpage` | 27 | `wAwardsCommon`(9) 등 | 랜딩·프로모션 (app/, wadiztrend/) |
| `wlayout` | 22 | (layout master) | jsp-template-inheritance 베이스 |
| `wpayment` | 15 | `wnofooter` 등 | 결제 (root 5 / equity 10) |
| `wsub` | 13 | `wcommon` | EasyCard, 메이커 가이드, 서브 페이지 |
| `wmypage` | 13 | `wmypage` | 마이페이지(구버전) |
| `error` | 9 | `wnoLayout` | 4xx/5xx 에러 페이지 |
| `account` | 9 | `account` | 레거시 계정 |
| `wboard` | 8 | `common` | 지지서명 게시판 |
| `wiplicense` | 8 | `wcommon` | IP 라이선스 (빙그레/디즈니/넥슨/팬즈메이커) |
| `campaign` | 7 | `wRewardDetailSPA`, `mainCommon` | 캠페인 상세 SPA 쉘 |
| `wevent` | 7 | `wcommon` | 통합 기획전 |
| `community` | 5 | `ftCommunity`(레거시) | (대부분 makercenter 이관) |
| `school` | 5 | `wcommon` | (구) 와디즈 스쿨 |
| `wpurchase` | 4 | `wnoLayout` | JSP+AJAX 결제 변형 |
| `startup` | 4 | `wcommon` | 스타트업 IR 페이지 |
| `global` | 4 | `wGlobalCommon` | 글로벌 크라우드펀딩 |
| `global-korea` | 3 | `wGlobalCommon` | 글로벌 → 한국 inbound |
| `global-account` | 3 | `wGlobalCommon` | 글로벌 계정 |
| `oauth` | 3 | `account` | 소셜 로그인 콜백 폼 |
| `mywadiz` | 3 | `wmypage` | 신 마이페이지 |
| `wpremium` | 2 | `wcommon` | 프리미엄 멤버십 |
| `wpartner` | 2 | `wcommon` | 파트너 상세 |
| `wpersonalmessage` | 2 | `wcommon` | 1:1 메시지 |
| `wcoming` | 2 | `wcommon` | 오픈예정 |
| `personalverification` | 2 | `wnoLayout` | 본인인증 |
| `makerprofile` | 2 | `wcommon` | 메이커 프로필 |
| `wlive` | 1 | `mainCommon` | 와디즈 라이브 |
| `wcampaign` | 1 | `wnoLayout` | 캠페인 검색 보조 |
| `linkprice` | 1 | (include) | 어필리에이트 링크 |
| `react` | 1 | `account` | React entry shell (iam.jsp) |
| `funding2015` | 1 | (legacy) | 폐기된 단일 페이지 |
| `ftexautn` | 1 | (legacy) | 구 본인인증 |
| `embed` | 1 | `wnoLayout` | 위젯 임베드 |
| `catchup` | 1 | (legacy) | (사용 중단 추정) |
| `video`, `supporterclub`, `include` | 1 each | — | — |
| **합계** | **447** | — | — |

## 2. wlayout/ — 22 마스터 레이아웃

| 파일 | 부모 | 정의된 placeholder (`<layout:block>`) | 사용처(주요) |
|---|---|---|---|
| `common.jsp` | (root) | `page_head`, `page_style`, `header`, `contents`, `footer`, `page_script` | wterms 일부, wboard, 레거시 |
| `wcommon.jsp` | (root) | + `page_head_script` + 신규 디자인 CSS (`wlayoutCss.jsp`) | 일반 표준 페이지 |
| `mainCommon.jsp` | `baseLayout` | `title`, `page_head` (mainHead include), `page_style` (`__staticPath_main_main_css`), `contents` (#main-app SPA root) | `/web/main`, `/web/wreward/main` |
| `wRewardDetailSPA.jsp` | `mainCommon` | + Schema.org JSON-LD, OpenGraph, Twitter Card | `/web/campaign/detail/{id}` (리워드 상세 SPA 쉘) |
| `wnoLayout.jsp` | (root) | minimal head/body | 팝업, 임베드, 일부 결제 SPA |
| `wnofooter.jsp` | `wcommon` | footer 제거 | 결제·로그인 (헤더만) |
| `account.jsp` | `common` | `header`, `contents`, `footer` 단순화 | `waccount/*`, `oauth/*`, react/iam |
| `wAccount.jsp` | `wcommon` | 계정 상세 변형 | waccount root 14개 |
| `wmypage.jsp` | `wcommon` | 마이페이지 좌측 메뉴 placeholder | wmypage 그룹 13개 |
| `wterms.jsp` | `common` | 약관 본문/사이드 | wterms 약관 30개 |
| `wtermsCommon.jsp` | `wterms` | 약관 베이스 | (chained) |
| `wtermsInvest.jsp` | `wtermsCommon` | 투자 약관 변형 | wterms invest 12개 |
| `ftCommon.jsp` | (root) | Bootstrap + `equityCommonCss.jsp` | 투자형(equity) 8개 |
| `ftEmpty.jsp` | `ftCommon` | 빈 컨테이너 (팝업) | equity 6개 |
| `ftCommunity.jsp` | `ftCommon` | 커뮤니티 좌우 grid | mobile equity 3개 (대부분 폐기) |
| `wGlobalCommon.jsp` | (root) | `<html lang="${language}">`, `wGlobalHead.jsp`, header/footer **없음** | global, global-korea, global-account |
| `wAwardsCommon.jsp` | `wcommon` | 어워즈 전용 헤더 | wpage 9개 |
| `wEventPopup.jsp` | `common` | 팝업 모달 | 이벤트 팝업 |
| `_header.jsp` | (component) | navigation/menu | (jsp:include) |
| `_footer.jsp` | (component) | 링크/소셜 | (jsp:include) |
| `_storeHeader.jsp` | (component) | 스토어 전용 헤더 | `/web/store/*` |
| `wmeta.jsp` | (template) | OG/Twitter card 템플릿 | (jsp:include) |

> 📌 **`jsp-inheritance-prefix = /WEB-INF/jsp/wlayout/`** 설정으로 `<layout:extends name="parent" />` 가 자동으로 `/WEB-INF/jsp/wlayout/parent.jsp` 로 해석. (`web.xml:258-262`)

## 3. winclude/ — 35 공통 include

### 3.1 헤더 / 메타 (6)
| 파일 | 역할 |
|---|---|
| `head.jsp` | 공통 `<head>` (viewport, title placeholder) |
| `mainHead.jsp` | SPA 메인용 head (#main-app root) |
| `wGlobalHead.jsp` | 글로벌 head (다국어, hreflang) |
| `wmeta.jsp` | OG / Twitter Card 템플릿 |
| `_assetVersions.jsp` | 정적 자산 버전 (CDN path) — 마지막 업데이트 2019-10-23 |
| `_staticPaths.jsp` | static 경로 변수 정의 |

### 3.2 CSS (8)
| 파일 | 역할 |
|---|---|
| `layoutCss.jsp` | 기본 레이아웃 CSS |
| `wlayoutCss.jsp` | 신규 디자인 시스템 CSS |
| `wfontStyleCss.jsp` | 폰트 weight/size |
| `wdetailCss.jsp` | 캠페인 상세 CSS |
| `waccountCss.jsp` | 계정 페이지 CSS |
| `equityCommonCss.jsp` | 투자형 공통 CSS |
| `froalaCustomCss.jsp` | Froala 에디터 커스텀 |
| `editorStyles.jsp` | 에디터 스타일 |

### 3.3 JavaScript (12)
| 파일 | 역할 |
|---|---|
| `requirejs.jsp` | RequireJS 설정 (legacy AMD) |
| `wMotionJs.jsp` | gsap/lottie 애니메이션 |
| `editorScripts.jsp` | Froala WYSIWYG 로드 |
| `froalaEditor.jsp` | Froala 초기화 |
| `wadizGlobals.jsp` | 글로벌 JS 변수 (env, site_url) |
| `studioWadizGlobals.jsp` | Studio 전용 JS 변수 |
| `assetVersions.jsp` / `assetBaseVersions.jsp` | 정적 자산 버전 |
| `daumPost.jsp` | Daum 주소 API |
| `appSupport.jsp` | 앱 bridge 지원 |
| `sendWebMessage.jsp` | WebView ↔ App 통신 |
| `userAgent.jsp` | UA 감지 |

### 3.4 추적·분석 (6)
| 파일 | 역할 |
|---|---|
| `tracking.jsp` | 기본 추적 |
| `tracking-gtm-head.jsp` | GTM (production) |
| `tracking-gtm-head-local.jsp` | GTM (local/dev) |
| `tracking-gtm-noscript.jsp` | GTM noscript fallback |
| `tracking-braze-head.jsp` | Braze CRM |
| `linkprice/*.jsp` (1) | 어필리에이트 링크 |

### 3.5 기타 (3)
- `mask.jsp` — 로딩 마스크/모달 배경
- `templateCardComing.jsp` — 오픈예정 카드 템플릿
- `about.ssr.jsp`, `equity-detail.ssr.jsp` — SSR 스냅샷

## 4. error/ — 9 에러 페이지

| 파일 | HTTP | 비고 |
|---|---|---|
| `serverError.jsp` | 401·403·404·500 | 기본 에러 (web.xml `<error-page>` 매핑) |
| `serverBusy.jsp` | 502 | 과부하 |
| `needLogin.jsp` | (custom) | 로그인 필요 |
| `notPermitted.jsp` | (custom) | 권한 없음 |
| `notPermittedStorePage.jsp` | (custom) | 스토어 권한 |
| `notReady.jsp` | (custom) | 준비중 |
| `notSupportedIE.jsp` | (custom) | IE 미지원 |
| `pageHasExpired.jsp` | (custom) | CSRF/세션 만료 |
| `serverNotice.jsp` | (custom) | 공지사항 |

## 5. React entry shell (1)

| 파일 | 라인 | 번들 |
|---|---|---|
| `react/entries/iam.jsp` | 18 (`layout:extends name="account"`) | `__staticPath_iam_main_js` (async) |

✅ `iam` 회원가입 SPA 가 React로 완전 이관된 화면. JSP는 `account` 레이아웃 + 번들 로드만 담당. 다른 React 이관 화면(`open-account`, `floating-buttons`, `school`, `personal-message`, 일부 `landing`) 은 `entries/` 외부에서 직접 정적 페이지 또는 `static.wadiz.kr` 로드 추정.

## 6. 그룹별 상세 — 6대 그룹

### 6.1 wterms/ (63 JSP) — 약관·정책

```
wterms/
├── (root, 52)         # app.jsp, invest.jsp, community.jsp, ad_center.jsp,
│                      # disclosure_of_personal_info_to_3rd_parties.jsp,
│                      # early_payout.jsp, electronic_financial_transaction.jsp,
│                      # equity_board_policy.jsp, funding_maker_service.jsp,
│                      # funding_plan_policy.jsp, funding_refund.jsp,
│                      # funding_report.jsp, funding_shipping.jsp,
│                      # global_shipping_forwarding.jsp, maker_page_service.jsp …
├── privacy/  (4)      # 개인정보처리정책 변형 (날짜·버전별 archive)
└── include/  (7)      # 약관 공용 부분 (header/footer/print)
```
부모 레이아웃: `wterms`(30), `wtermsInvest`(12). 같은 약관이 시기별로 archive 되어 양산되는 패턴.

### 6.2 waccount/ (47 JSP) — 계정·인증

```
waccount/
├── (root, 27)         # wAccountLogin.jsp, wAccountRegistIntro.jsp,
│                      # wAccountRegistCorp.jsp, wAccountRegistFinish.jsp,
│                      # wAccountSocial*, wAccountFind*, dropOut* …
├── equity/  (12)      # 투자형 계정 (modify/personal, modify/corporation,
│                      # 본인인증, 약관 동의 등)
├── join/    (1)       # 신규 가입 분기
├── notificationSetting/ (2) # 알림 설정
├── popup/   (1)       # 팝업
└── include/ (4)       # 계정 공용 include
```
부모: `account`(18), `wAccount`(14).

### 6.3 equity/ (39 JSP) — 투자형(증권형) 펀딩

```
equity/
├── (root, 4)
├── campaign/   (8)    # 청약 안내, 캠페인 상세 보강 (증권신고서 등)
├── dashboard/  (9)    # 투자자 대시보드 (수익률, 정산, 환급)
├── payment/   (10)    # 결제 (equity1.jsp~equity4.jsp 단계별)
├── account/    (7)    # 투자 한도/예치금 계좌 관리
└── guide/      (1)    # 사용 가이드
```
부모: `ftCommon`(8), `ftEmpty`(6), `wcommon`(4). 한국증권금융(KSFC) 예치금 계좌 연동 화면.

### 6.4 wmain/ (35 JSP) — 통합 메인

모두 root level. `mainCommon`(31) 부모 사용. 시즌/테마/캠페인별로 메인 변형이 누적되는 구조 — `main.jsp`(통합 리워드), `wmain.jsp`(투자 메인), `startupMain.jsp`(스타트업), `wreward/*.jsp`(리워드 컬렉션).

### 6.5 winclude/ (35 JSP)
§ 3 참조 — head/CSS/JS/tracking/SSR.

### 6.6 mobile/ (33 JSP) — 모바일 전용

```
mobile/
├── equity/ (28)       # 모바일 투자형 결제·계정·대시보드·도움말
├── school/ (4)        # 모바일 학교 펀딩
└── footer/ (1)
```
부모: `ftCommunity`(3) 일부. 대부분은 React 이관 대기 또는 폐기. `m.wadiz.kr` 시절 화면 잔재.

## 7. JSP 사용 패턴 통계

| 태그/액션 | 사용 횟수 | 용도 |
|---|---:|---|
| `<layout:put>` | 1,178 | 레이아웃 placeholder 채우기 |
| `<c:if>` | 1,161 | JSTL 조건문 |
| `<c:when>` / `<c:choose>` | 714 / 457 | 다중 조건 |
| `<jsp:include>` | 556 | 정적 include |
| `<c:set>` | 416 | 변수 |
| `<spring:eval>` | 300 | Spring EL |
| `<fmt:formatNumber>` | 300 | 숫자 포맷 |
| `<layout:extends>` | 281 | 레이아웃 상속 |
| `<c:forEach>` | 228 | 반복 |
| `fn:escapeXml` | 237 | XSS 방어 |
| `fn:length` | 138 | 길이 |
| `fn:replace` | 84 | 치환 |
| `fn:substring` | 30 | 부분 문자열 |
| `fn:contains` | 17 | 포함 |
| OG `<meta property=...>` | 20 | SNS 공유 |
| Twitter card | 13 | 트위터 |

## 8. 이관 상태 요약

| 상태 | 그룹/화면 |
|---|---|
| ✅ React 이관 완료 (JSP는 shell만) | iam (회원가입), open-account, floating-buttons, school, personal-message, 일부 landing(about, wadiz2017, partners) |
| ✅ 외부 도메인 이관 완료 | community(`makercenter.wadiz.kr`), helpcenter(`helpcenter.wadiz.kr`), studio(`/studio/reward/*`) |
| 🟡 SPA 쉘 + SEO 서버사이드 (혼합) | 캠페인 상세(`wRewardDetailSPA`), 메인(`mainCommon`) |
| 🔴 풀 JSP 렌더 (이관 안됨) | 약관(wterms), 결제 체크아웃(wpayment), 청약(equity), 마이페이지(wmypage), 이벤트(wevent), 파트너(wpartner), IP라이선스(wiplicense), 글로벌(global), 어워즈(wpage) |
| ❓ 폐기/사용중단 추정 | catchup, ftexautn, funding2015, ftCommunity 일부, mobile/* (대부분) |

## 9. 외부 참조

- 화면별 상세: `screen-*.md`
- 컨트롤러 ↔ JSP 매핑: `../api-endpoints.md`
- urlrewrite + 레이아웃 inheritance: `urlrewrite-and-layouts.md`
