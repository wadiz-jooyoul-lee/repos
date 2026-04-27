# com.wadiz.web — URL Rewrite + JSP Layout 시스템

> 외부 호환성·이관 redirect · 서블릿 필터 체인 · ViewResolver · jsp-template-inheritance 레이아웃 트리.
> 핵심 파일: `web/WEB-INF/urlrewrite.xml`(459줄), `web/WEB-INF/web.xml`(315줄), `src/main/resources/spring/dispatcher/servlet.xml`(121줄).

## 1. urlrewrite.xml — 459줄 카테고리 정리

`tuckey UrlRewriteFilter` 가 모든 요청에 대해 가장 먼저 수행하는 URL 변환 단계.

### 1.1 외부 호환성 (legacy 보존)
| FROM | TO | Type |
|---|---|---|
| `/partner/(.+)`, `/web/partner/(.+)` | `/web/wpartner/detail/$2` | regex |
| `/web/wprogram/*`, `/crowd/*` | `/web/wpartner/detail/$1` | wildcard |
| `/sbsinvestor` | `/web/wpartner/detail/sbs` | exact |
| `/nhcrowd` | `/web/wpartner/detail/nhcrowd` | 301 |
| `/Campaign/Details/*`, `/ko/Campaign/Details/*` | `/web/campaign/detail/$1` | 301 |
| `/Campaign/Dashboard/*` | `/web/campaign/dashboard/$1` | 301 |
| `/funding2015`, `/2015funding` | `/web/wmain` | 301 |
| `/invest`, `/Invest` | `/web/winvest/main` | 301 |
| `/web/ftmain*`, `/web/m/ftmain*`, `/ios/mainBanner1` | `/web/winvest/main` | 301 |
| `/web/ftaccount/login` | `/web/waccount/wAccountLogin` | 301 |

### 1.2 Studio (React) 이관 redirect (301)
| FROM | TO |
|---|---|
| `/Campaign/Edit/*`, `/web/campaign/edit/*`, `/web/campaign/opening` | `/studio/reward/$1/funding` |

### 1.3 외부 도메인 이관 redirect (301)
| FROM | TO |
|---|---|
| `/web/wcommunity**`, `/web/wcast**`, `/web/ftcommunity**`, `/web/m/ftcommunity**` | `https://makercenter.wadiz.kr` |
| `/web/fthelpCenter**` | `https://helpcenter.wadiz.kr` |

### 1.4 마이페이지 통합 (`/web/account/my`, `/web/wmypage/*`, `/web/myreward` → `/web/mywadiz/*`)
**Parameter 기반 redirect** (`/web/account/my?viewType=...`):
| viewType | TO |
|---|---|
| `backed` | `/web/wmypage/participation` |
| `history` | `/web/wmypage/participation` |
| `my` | `/web/wmypage/myfunding/makinglist` |
| `int` | `/web/wmypage/myfunding/likelist` |
| `point` | `/web/wmypage/mybenefit/pointlist` |
| `coupon` | `/web/wmypage/mybenefit/coupon/my` |

**경로 통합**:
| FROM | TO |
|---|---|
| `/web/myreward` | `/web/mywadiz/payment-info` |
| `/web/wmypage/myfunding/info`, `/web/mywadiz/myfunding/info` | `/web/mywadiz/payment-info` |
| `/web/wmypage/myfunding/fundinglist`, `/web/mywadiz/myfunding/fundinglist` | `/web/mywadiz/participation` |
| `/web/wmypage/myfunding/rewardfundinglist` | `/web/mywadiz/participation` |
| `/myreward/*` | `/web/wmypage/myfunding/purchase/$1` |

### 1.5 이벤트 slug → ID (50+ 규칙, lines 292-433)
| 슬러그 | ID |
|---|---|
| `ces2024bywadiz` | 73 |
| `thebetterbeauty` | 72 |
| `thebetterstyle` | 71 |
| `wday2404` | 70 |
| `maisondewa` | 1 |
| ... (50+ slug → id mapping) | ... |

패턴: `/web/wevent/{slug}` → `/web/wevent/{id}` (모두 301).

### 1.6 브랜드/컬렉션 통합
| FROM | TO |
|---|---|
| `/web/brand/*` | `/web/wevent/$1` |
| `/web/collection/*` | `/web/wevent/$1` |
| `/opensoon/*` | `/web/wcomingsoon/ivt/$1` |

### 1.7 단건 redirect
| FROM | TO | 비고 |
|---|---|---|
| `/life` | `/web/wreward/main` | 라이프스타일 → 리워드 메인 |
| `/web/store/best` | `/web/store/main?order=popular` | best → popular |
| `/web/store/best/**` | `/web/store/main/$1?order=popular` | 카테고리 포함 |
| `/web/s/([\w\d-_]+)` | `/web/redirect/hashkey/$1` | 짧은 링크 (regex) |
| `/web/main/trend` | `/web/main` | 트렌드 페이지 폐기 |
| `/kitas2019` | `/web/wreward/comingsoon/collection/kitas2019` | |
| `/web/wreward/hopetogether` | `/web/wreward/collection/hopetogether` | |
| `/web/waccount/wAccountUpdatePlusInvest` | `/web/waccount/equity/modify/personal` | 301 Permanent |

### 1.8 글로벌 커뮤니티 URL 변경
| FROM | TO |
|---|---|
| `/funding/([\w\d-]+)/community/pledge-support` | `/funding/$1/community/support-share` |

## 2. web.xml — 서블릿/필터 체인 (315줄)

### 2.1 Listener (lines 11-25)
| 리스너 | 역할 |
|---|---|
| `Log4jConfigListener` | log4j 초기화 |
| `WadizSessionListener` | 와디즈 커스텀 세션 |
| `ContextLoaderListener` | Spring Root ApplicationContext |
| `RequestContextListener` | 스레드-로컬 Request/Session binding |

### 2.2 Filter Chain — 순서대로 (lines 28-139)
| # | 이름 | 클래스 | URL | 목적 |
|---|---|---|---|---|
| 1 | `encodingFilter` | `CharacterEncodingFilter` | `/*` | UTF-8 강제 (forceEncoding=true) |
| 2 | `GlobalHeaderModifyingFilter` | `com.wadiz.api.fw.filter.GlobalHeaderModifyingFilter` | `/*` | 글로벌 HTTP 헤더 수정 |
| 3 | `APIFilter` | `com.wadiz.api.fw.filter.APIFilter` | `/api/*` | Jersey REST 전용 |
| 4 | `CJCookieServletFilter` | `com.wadiz.api.fw.filter.CJCookieServletFilter` | `/*` | CJ 카드사 쿠키 |
| 5 | **`UrlRewriteFilter`** | `org.tuckey.web.filters.urlrewrite.UrlRewriteFilter` | `/*` | URL Rewrite 엔진 |
| 6 | `CORSFilter` | `com.wadiz.web.fw.filter.CORSFilter` | `/*` | CORS |
| 7 | `XssEscape` | `com.wadiz.web.fw.filter.XssEscapeServletFilter` | `/*` | XSS 이스케이프 |
| 8 | `oauth2LoginFilter` | `DelegatingFilterProxy` | `/web/oauth/callback/*` | OAuth2 로그인 콜백 |
| 9 | `oauth2RedirectFilter` | `DelegatingFilterProxy` | `/*` | OAuth2 리다이렉트 |
| 10 | `bearerTokenAuthenticationFilter` | `DelegatingFilterProxy` | `/web/v1/maker/*`, `/web/v2/membership`, `/web/apip/funding/**`, `/web/apip/store/**` | Bearer token 인증 |
| 11 | `autoLoginFilter` | `DelegatingFilterProxy` | `/*` | 자동 로그인 (쿠키) |

### 2.3 Servlet 매핑 (lines 140-213)
| Servlet | Class | URL | load-on-startup | 역할 |
|---|---|---|---|---|
| `dispatcher` | `DispatcherServlet` | `/` | 1 | Spring MVC (`spring/dispatcher/servlet.xml`) |
| Jersey | `SpringServlet` | `/api/*` | 2 | Jersey JAX-RS REST API |
| `api-proxy` | `ApiProxyServlet` | `/web/apip/*` | 3 | API 프록시 (마이크로서비스 라우팅) |
| `maker-proxy` | `MakerApiProxyServlet` | `/web/maker-proxy/*` | 4 | maker-api 프록시 (스튜디오 SPA) |

### 2.4 jsp-template-inheritance (lines 257-266)
```xml
<context-param>
  <param-name>jsp-inheritance-prefix</param-name>
  <param-value>/WEB-INF/jsp/wlayout/</param-value>
</context-param>
<context-param>
  <param-name>jsp-inheritance-suffix</param-name>
  <param-value>.jsp</param-value>
</context-param>
```
→ 모든 `<layout:extends name="X" />` 는 `/WEB-INF/jsp/wlayout/X.jsp` 로 해석.

### 2.5 Error Page (lines 273-295)
| HTTP | JSP |
|---|---|
| 401, 403, 404, 500 | `/WEB-INF/jsp/error/serverError.jsp` |
| 502 | `/WEB-INF/jsp/error/serverBusy.jsp` |
| (예외) | `serverError.jsp` |

### 2.6 ApplicationContext (lines 216-240)
환경 분기 컨텍스트 XML:
```
classpath:proxy/proxy-${environment}.xml
classpath:point/point-${environment}.xml
classpath:reward/reward-${environment}.xml
classpath:equity/equity-${environment}.xml
classpath:message/notification-${environment}.xml
classpath:cache/cache-${environment}.xml
classpath:user/user-${environment}.xml
classpath:pay/pay-${environment}.xml
classpath:main/main-${environment}.xml
classpath:spring/application/root-context.xml
classpath:spring/application/datasource-context.xml
classpath:searcher/searcher-${environment}.xml
classpath:startup/startup-${environment}.xml
classpath:payment-log/payment-log-${environment}.xml
classpath:ksd/ksd-${environment}.xml
```
환경 기본값 `product`.

### 2.7 Jersey 패키지 스캔
```
com.wadiz.api.account, .app, .campaign, .error, .ftaccount, .ftcampaign,
.fw, .login, .notification, .waccount, .wcampaign, .wcode, .wmain,
.wmypage, .wpoint, .store, .startupApp, .membership, .social
```

## 3. ViewResolver Chain (servlet.xml 52-88)

```xml
<!-- order=0 (최우선): 다운로드 빈 -->
<bean class="org.springframework.web.servlet.view.BeanNameViewResolver">
  <property name="order" value="0" />
</bean>

<!-- order=1: Accept 헤더 기반 (JSON/XML) -->
<bean class="org.springframework.web.servlet.view.ContentNegotiatingViewResolver">
  <property name="order" value="1" />
  <!-- defaultViews: MappingJackson2JsonView -->
</bean>

<!-- order=2 (최후): JSP -->
<bean id="viewResolver" class="org.springframework.web.servlet.view.InternalResourceViewResolver">
  <property name="viewClass" value="JstlView" />
  <property name="order" value="2" />
  <property name="prefix" value="/WEB-INF/jsp/" />
  <property name="suffix" value=".jsp" />
</bean>
```

### 3.1 BeanNameViewResolver 로 매핑되는 다운로드 뷰 (lines 97-107)
| Bean ID | Class | 용도 |
|---|---|---|
| `download` | `FileDownload` | 파일 다운로드 (legacy) |
| `downloadExcel` | `DownloadViewExcel` | 엑셀 |
| `downloadFile` | `DownloadView` | 신규 파일 다운로드 |
| `downloadZip` | `ZipDownloadView` | ZIP |
| `financeDownloadFile` | `FinanceDownloadView` | 투자형 파일 |
| `makerDownloadFile` | `MakerDownloadView` | 메이커 파일 |

## 4. JSP Layout Inheritance — 22개 마스터

`kwonnam.pe.kr/jsp/template-inheritance` taglib (Sitemesh 유사). 태그: `<layout:extends>`, `<layout:put>`, `<layout:block>`, `<layout:get>`.

### 4.1 베이스 (root)
**`common.jsp`**
```jsp
<head>
  <jsp:include page="head.jsp" />
  <layout:block name="page_head" />
  <layout:block name="page_style" />
</head>
<body>
  <div id="page-container">
    <layout:block name="header"><jsp:include page="_header.jsp" /></layout:block>
    <layout:block name="contents" />
    <layout:block name="footer"><jsp:include page="_footer.jsp" /></layout:block>
  </div>
  <layout:block name="page_script" />
</body>
```
**사용처**: wterms 일부, wboard, 레거시.

**`wcommon.jsp`** — 신규 표준
- `wlayoutCss.jsp` + `/resources/static/css/style.css` 로드
- `page_head_script` placeholder 추가
- 사용처 확장: `wAccount`, `wmypage`, `wAwardsCommon`

### 4.2 특화 레이아웃
| 파일 | 부모 | 정의 (`layout:block`/`put`) | 사용처 |
|---|---|---|---|
| `mainCommon.jsp` | (root) | `title`, `page_head`(`mainHead.jsp` include), `page_style`(`__staticPath_main_main_css`), `contents`(#main-app SPA root) | `/web/main`, `/web/wreward/main`, `/web/winvest/main` |
| `wRewardDetailSPA.jsp` | `mainCommon` | `title="${project.title} by ${project.maker.name}"`, Schema.org JSON-LD, OG, Twitter Card, 봇 전용 SEO HTML | `/web/campaign/detail/{id}` 풀 SPA 쉘 |
| `ftCommon.jsp` | (root) | Bootstrap CSS/JS, `equityCommonCss.jsp` | 투자형 페이지 |
| `ftEmpty.jsp` | `ftCommon` | 빈 컨테이너 | 투자형 팝업 |
| `ftCommunity.jsp` | `ftCommon` | 커뮤니티 grid | 모바일 일부 (대부분 폐기) |
| `wGlobalCommon.jsp` | (root) | `<html lang="${language}">`, `wGlobalHead.jsp`, **header/footer 없음** | global, global-korea, global-account |
| `wnoLayout.jsp` | (root) | minimal head/body | 팝업, 임베드, 일부 결제 SPA |
| `wnofooter.jsp` | `wcommon` | footer 제거 | 결제, 로그인 (헤더만) |
| `account.jsp` | `common` | 단순화된 header/contents/footer | waccount, oauth, react/iam |
| `wAccount.jsp` | `wcommon` | 계정 상세 변형 | waccount root |
| `wmypage.jsp` | `wcommon` | 좌측 메뉴 placeholder | wmypage 13개 |
| `wterms.jsp` | `common` | 약관 본문/사이드 | wterms 30개 |
| `wtermsCommon.jsp` | `wterms` | 약관 베이스 | (chained) |
| `wtermsInvest.jsp` | `wtermsCommon` | 투자 약관 변형 | wterms invest 12개 |
| `wAwardsCommon.jsp` | `wcommon` | 어워즈 헤더 | wpage 9개 |
| `wEventPopup.jsp` | `common` | 팝업 모달 | 이벤트 팝업 |

### 4.3 컴포넌트 (jsp:include 전용)
- `_header.jsp` — 공통 헤더 (navigation/menu)
- `_footer.jsp` — 공통 풋터 (links/social)
- `_storeHeader.jsp` — 스토어 전용 헤더 (`/web/store/*`)
- `wmeta.jsp` — OG/Twitter Card 메타 템플릿

## 5. 렌더링 흐름 종합

```
HTTP Request
  ↓
[Filter Chain]
  encoding → headerModify → APIFilter(/api/*) → CJCookie → UrlRewrite
  → CORS → XSS → oauth2Login → oauth2Redirect → bearerToken → autoLogin
  ↓
[Servlet 매핑]
  ├ /api/*        → SpringServlet (Jersey JAX-RS)
  ├ /web/apip/*   → ApiProxyServlet (마이크로서비스 프록시)
  ├ /web/maker-proxy/* → MakerApiProxyServlet
  └ /              → DispatcherServlet (Spring MVC)
  ↓
[Spring Controller @RequestMapping]
  return "viewName"
  ↓
[ViewResolver Chain]
  (0) BeanNameViewResolver → 다운로드 뷰 빈
  (1) ContentNegotiatingViewResolver → JSON (Accept: application/json)
  (2) InternalResourceViewResolver → /WEB-INF/jsp/{viewName}.jsp
  ↓
[JSP Layout Inheritance]
  <layout:extends name="parent"> → /WEB-INF/jsp/wlayout/parent.jsp
  <layout:put block="..."> → 부모 placeholder 채움
  <jsp:include page="/WEB-INF/jsp/winclude/..."> → 공통 모듈 (head/css/js/tracking)
  ↓
HTML Response
```

## 6. 운영 인사이트

- **Spring 3.2 한계**: `@GetMapping`/`@PostMapping` 안씀, 모든 mapping 이 `@RequestMapping(value=..., method=...)` 패턴.
- **legacy slug 누적**: 50+ 이벤트 slug가 ID 로 매핑되는 거대한 redirect 표가 `urlrewrite.xml` 에 누적됨. 새 이벤트 launch 시 두 군데 등록 필요(slug → id, 이후 컨트롤러).
- **External 이관 redirect** 가 다수 (`/web/wcommunity*` → makercenter, `/web/fthelpCenter*` → helpcenter, studio 진입 URL 등). 이미 코드 자체는 비어있지만 외부 봇/검색결과를 고려해 redirect 만 살아있음.
- **ApiProxyServlet** — `/web/apip/*` 가 funding/store 마이크로서비스 게이트웨이 역할. 최신 도메인 호출은 모두 이 경로 (예: `/web/apip/funding/aireview/...`, `/web/apip/store/products/...`). bearer token 필터로 인증.
- **MakerApiProxyServlet** — 스튜디오 SPA 가 `/web/maker-proxy/*` 를 통해 maker-api 호출.
- **Filter 순서** 의 미묘함: `UrlRewriteFilter` 가 CORS·XSS 보다 먼저 실행되어 redirect 화면에는 CORS/XSS 처리가 안 들어감 (외부 redirect 라 무관).
