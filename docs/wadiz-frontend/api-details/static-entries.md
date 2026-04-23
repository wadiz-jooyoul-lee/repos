# static/entries 레거시 호환 진입점 상세 스펙

> **기록 범위**: `wadiz-frontend/static/entries/` 디렉터리 13개 엔트리(`account`, `analytics`, `assets`, `embed`, `floating-buttons`, `iam`, `landing`, `main`, `open-account`, `personal-message`, `reward`, `school`, `web`)의 `package.json` · `webpack.config.js` · `src/index.*` 등 빌드·부트스트랩 코드에서 직접 관측 가능한 것만 기록합니다. 각 엔트리가 불러오는 공통 패키지(`@wadiz/react-common`, `@wadiz/reward-simple-pay-app`, `@wadiz/equity-*`, …) 내부는 외부 모듈로 간주하고 진입점에서 import 되는 사실만 기록합니다. `entries/RENDERER_ID_SELECTORS.md` 에 2025-01-05 기준으로 정리된 selector 목록을 참고 자료로 활용하되, 본 문서는 현행 소스에서 다시 확인한 내용을 우선합니다. 실제 배포 파이프라인(Jenkins/S3/CDN 구성)은 이 repo 바깥에 있어 확인 불가이며, `cdnPurge.js` 와 `STATIC_DEPLOYMENT_ORIGIN` 환경 변수에서 드러나는 부분만 기록합니다.

---

## 개요

`static/entries/` 는 레거시 JSP 기반 포털(`com.wadiz.web`, `www.wadiz.kr`) 이 `<script src="…">` 로 직접 로드하던 정적 번들을 공급하는 디렉터리입니다. 각 엔트리는 Yarn workspace 1개(`@wadiz-static/<name>`) 로 등록되어 있고 (`wadiz-frontend/static/package.json:35-42`), `lerna run --scope=@wadiz-static/* build` 로 독립적으로 빌드되어 (`wadiz-frontend/static/package.json:16`) `build/<publicPath>/` 하위에 `main.js`, `vendor.js`, `manifest.json`, `<name>.css` 등 산출물을 출력합니다.

### 왜 존재하는가

상위 `wadiz-frontend/CLAUDE.md` 와 `wadiz-frontend/static/CLAUDE.md` 에 따르면, 이 `static/` 디렉터리는 레거시 메인 프로젝트의 "Wadiz Frontend Legacy Main Project" 이며 신규 Next.js 모노레포(`apps/`) 와 병행 운영됩니다. JSP 페이지가 `<script src="${resourceServerUrl}/static/web/bundle.js"></script>` 처럼 번들을 직접 로드하고, React 앱은 서비스 워커/SSR 없이 번들 내부에서 `createRoot(document.getElementById('…'))` 으로 특정 DOM 노드를 찾아 렌더합니다. 이 방식은 `static/packages/shared/reactRenderer.tsx` 의 `reactRenderer` / `reactEmbedRenderer` 함수가 담당합니다.

### 엔트리 한 개가 레거시 페이지에 주입되는 흐름

1. **빌드**: `<entry>/webpack.config.js` 가 `entry.main = ['./src/index.(jsx|js|tsx)']` 로 진입점을 정의합니다. 공통 설정은 `static/libraries/shared/config/webpack.config.js` 또는 `static/packages/shared/config/webpack.config.js` 에서 래핑됩니다. output 은 기본 UMD, `libraryTarget: 'umd'` 로 고정 (`static/libraries/shared/config/webpack.config.js:38`).
2. **산출물**: `publicPath` 는 각 `package.json` 의 `publicPath` 필드(`/static/web/`, `/main/`, `/static/iam/` 등)로 지정되고, `STATIC_DEPLOYMENT_ORIGIN` 환경 변수가 있으면 그 origin 과 결합되어 절대 URL 이 됩니다 (`static/packages/shared/config/paths.js:12-17`, `static/config/webpackCommonConfig/paths.js:12-17`). 이 URL 은 `manifest.json` 에 기록됩니다.
3. **CDN 배포 · 무효화**: 빌드된 파일이 `static.wadiz.kr` 으로 추정되는 호스트에 업로드되고, 배포 후 `static/scripts/tasks/cdnPurge.js` 가 각 엔트리의 `manifest.json` 을 순회해 `http://purge.concdn.com/cgi-bin/cpurge.cgi?url=static.wadiz.kr<path>` 로 CDN 퍼지 요청을 날립니다 (`static/scripts/tasks/cdnPurge.js:30-56`). 업로드 자체는 이 repo에 정의되어 있지 않아 확인 불가.
4. **주입**: 레거시 JSP/HTML 이 `<script src="…/static/<entry>/main.js">` 를 포함합니다. 실제 JSP 는 이 repo 외부(`com.wadiz.web`) 에 있어 확인 불가이나, `wadiz-frontend/static/CLAUDE.md` 가 "1) web 번들 → 2) 페이지별 번들 1개" 패턴을 설명합니다. 본 repo에서는 `reward/src/payments/SimplePay.jsx:29-34` 의 주석 `리워드 결제 예약 - step20.jsp / myfundingPurchaseDetail.jsp` 와 `main/src/index.jsx:9` 의 `reactRendererWithInitialization(MainApp, 'main-app')` 처럼, 특정 JSP 가 `<div id="main-app">` 같은 placeholder 를 심어둔다는 가정을 확인할 수 있습니다.
5. **렌더**: 번들이 실행되면 `shared/reactRenderer` 의 `reactRenderer` / `reactEmbedRenderer` 가 `document.getElementById('<selector>')` 를 찾아 React 18 `createRoot(el).render(<Component {...dataSetProps} />)` 으로 실제 렌더링을 수행합니다 (`static/packages/shared/reactRenderer.tsx:87-90`).

### `RENDERER_ID_SELECTORS.md` 의 의미

`static/entries/RENDERER_ID_SELECTORS.md` 는 2025-01-05 기준으로 `reactRenderer()` / `reactEmbedRenderer()` 호출에서 사용된 모든 DOM id selector 를 추출한 색인입니다 (63개 selector, 10개 엔트리). 주요 목적은 아래와 같이 문서화됨:

> "Use this to verify that function signature changes don't break existing functionality."
> (`static/entries/RENDERER_ID_SELECTORS.md:5`)

즉, 진입점의 selector 가 레거시 JSP 의 `<div id="…">` 와 1:1 대응되는 **대외계 인터페이스** 이기 때문에, selector 를 잘못 건드리면 JSP 쪽이 조용히 깨지는 구조임을 보여줍니다. 본 문서 각 엔트리 섹션의 "주요 selector" 는 이 파일을 참고하여 현행 소스에 존재하는 것만 재확인했습니다.

---

## 엔트리별 섹션

### 1. `account`

- **패키지**: `@wadiz-static/account` (`entries/account/package.json:3`)
- **publicPath**: `/account/` (`entries/account/package.json:5`)
- **devServer.port**: 9092 (`entries/account/package.json:14`)
- **책임**: 레거시 **마이페이지** 관련 UI — 내 계좌, 팔로우 목록, 소셜 계정 연결, 메이커 프로필, 제작 내역(makinglist), 투자 내역 하단 배너, W9 회원정보, 리워드 구매 상세 등. 디렉터리명이 대부분 JSP 의 subpath 와 동일 추정.
- **빌드 진입점** (`entries/account/webpack.config.js:17-34`) — 단일 webpack.config 에 **8개 multi-entry** 를 선언:
  | chunk | 엔트리 파일 |
  |---|---|
  | `main` | `src/main/index.js` |
  | `follow` | `src/follow/index.js` |
  | `social` | `src/social/index.js` |
  | `my` | `src/my/index.js` |
  | `reward-payments` | `src/empty/index.jsx` |
  | `makinglist` | `src/makinglist/index.js` |
  | `maker-profile` | `src/maker-profile/index.js` |
  | `my-purchase-detail` | `src/my-purchase-detail/index.jsx` |
- **주요 렌더링 호출**
  - `src/main/activeAccount/index.js:5` — `reactRendererWithInitialization(ActiveAccountComponent, 'active-account')`
  - `src/my/index.js:11` — `reactEmbedRendererWithInitialization(MyVirtualAccount, 'my-virtual-account-app')` (`@wadiz/equity-my-virtual-account-app`)
  - `src/my/index.js:24` — `EquityCloseNotice` → `equity-close-notice` (`@wadiz/react-common`)
  - `src/my/index.js:27` — `ImageBanner` → `my-equity-banner` (`@wadiz/react-promotion-banner`)
  - `src/my/index.js:30` — `EquityCloseNotice` → `account-equity-certification-face-certification`
  - `src/my/index.js:46` — `RegistAccountCompleteBox` → `my-equity--normal-member-app`
  - `src/my/w9-info.js:7` — `W9MembershipInfo` → `my-w9-info-app` (`@wadiz/equity-w9-membership-app`)
  - `src/maker-profile/index.js:4` — `MakerProfileApp` → `maker-profile-app` (`@wadiz/maker-profile-app`)
  - `src/my-purchase-detail/index.jsx:8-9` — `MyRewardPurchaseDetail` → `myreward-purchase-detail` + `MyRewardPurchaseDetailFooter` → `myreward-purchase-detail-footer`
  - `src/follow/follow.js` — jQuery 기반, React 렌더 없음 (`.social-user-item[data-item-id="…"]` DOM 조작)
  - `src/social/index.js` — jQuery 기반, `#facebookLink` `#naverLink` 등 OAuth 연동 핸들러 (`@wadiz/oauth` 의 `linkHandler`, `inAppBlackHandler`)
  - `src/empty/index.jsx` — `fundingDetail` 엘리먼트를 숨기기만 함 (com.wadiz.web 배포 중간 과도기 처리)
- **사용 라이브러리**: React 18.2, MobX 3 (`mobx`, `mobx-react`), react-redux + redux + redux-thunk, react-router-dom 6, jQuery 2.1.3 (`entries/account/package.json:21-35`). Redux store 는 하위 `my-purchase-detail/store/` 등에서 사용.
- **외부 패키지 의존**: `@wadiz/equity-my-virtual-account-app`, `@wadiz/equity-w9-membership-app`, `@wadiz/reward-simple-pay-app`, `@wadiz/maker-profile-app`, `@wadiz/react-common`, `@wadiz/web-redux-store`, `@wadiz/react-promotion-banner`, `@wadiz/reward-satisfaction-modal`, `@wadiz/fetch-api` (`entries/account/package.json:36-43`).
- **API 호출 패턴**: 엔트리 진입점에서 직접 fetch/axios 호출은 없음. 호출은 `@wadiz/fetch-api`, `@wadiz/equity-*` 등 외부 패키지 내부에서 수행 — 이 repo 내에서 추적 불가.
- **MSW**: `my-purchase-detail/index.jsx:12-28` 에서 `process.env.NODE_ENV === 'development' && process.env.REACT_APP_MSW_ENABLE === 'true'` 조건으로 `mocks/` 의 `getWorkder(MOCK_TYPE.MY)` 실행.

---

### 2. `analytics`

- **패키지**: `@wadiz-static/analytics` (`entries/analytics/package.json:3`)
- **publicPath**: `/analytics/` (`entries/analytics/package.json:5`)
- **책임**: 비(非)-React 분석 부트스트랩 스크립트. `window.wadiz.analytics` 전역에 `WadizAnalytics` 인스턴스를 1회 바인딩하고, 스크립트 로드 이전에 큐잉된 이벤트(`window.wadiz.__analyticsQueue`) 를 flush 합니다. `PageViewTracker` 도 중복 방지 조건(`window.wadiz.pageViewTracker`) 아래 1회만 설치.
- **빌드 진입점** (`entries/analytics/webpack.config.js:22-34`)
  - entry: `src/index.js`
  - output: `filename: 'client.js'` (다른 엔트리와 다른 고정 파일명, UMD)
  - production-only 빌드 (`mode: 'production'`, dev server 스크립트 없음 — `package.json:7-8`)
  - ESBuildMinify `es2018`
- **진입 코드** (`src/index.js` 전체 19줄):
  ```js
  import { WadizAnalytics, PageViewTracker } from '@wadiz/core/analytics';
  if (process.env.NODE_ENV === 'production') {
    window.wadiz = window.wadiz || {};
    const queue = window.wadiz.__analyticsQueue || [];
    window.wadiz.analytics = new WadizAnalytics();
    queue.forEach(item => { window.wadiz.analytics[item.method](...item.args); });
    delete window.wadiz.__analyticsQueue;
    if (!window.wadiz.pageViewTracker) {
      window.wadiz.pageViewTracker = new PageViewTracker();
    }
  }
  ```
- **사용 라이브러리**: React 없음, Redux 없음. `@wadiz/core` 패키지만 소비. `lodash-es`, `lodash.camelcase`, `whatwg-fetch` 가 번들됨.
- **API 호출**: 이 진입점에서 직접 호출은 없음. `WadizAnalytics` / `PageViewTracker` 내부의 tracking endpoint 는 `@wadiz/core` 외부에 있어 확인 불가.

---

### 3. `assets`

- **패키지**: `@wadiz-static/assets` (`entries/assets/package.json:3`)
- **publicPath**: `/assets/` (`entries/assets/package.json:5`)
- **책임**: **JS/CSS 번들이 아님**. 정적 파일(이미지·폰트·PDF·Lottie JSON 등) 을 복사만 수행하는 "pass-through" 엔트리.
- **빌드 스크립트** (`entries/assets/package.json:6-11`):
  ```
  "prebuild": "run-s clean",
  "build":    "run-s copy",
  "copy":     "node scripts/copy.js",
  "clean":    "build-clean"
  ```
- **빌드 동작** (`entries/assets/scripts/copy.js` 전체 12줄): `fs-extra` 로 `public/` 디렉터리 전체를 `<buildDirectory>/assets/` 로 `emptyDirSync` 후 `copySync`. Webpack 은 돌지 않습니다.
- **루트 `index.js`**: 0바이트(`wc -l` → 0). 번들이 아닌 workspace 플레이스홀더로 보이며 실제로는 `public/` 자산만 배포됨.
- **복사 대상 `public/` 하위**: `equity/`, `error/`, `fonts/`, `funding2015/`, `icon/`, `pdfjs/`, `startup-search/`, `svgs/`, `wadizawards/`, `welcomeMaker/`, `landingEventList.json` (`ls` 결과).
- **사용 라이브러리**: 없음 (shared 만 의존). React / Redux 없음.
- **참고**: 다른 엔트리 코드에서 `https://static.wadiz.kr/assets/wadiz2017/…` 처럼 이 `/assets/` 경로의 파일을 직접 URL 로 참조하는 패턴이 다수 확인됨 (예: `entries/landing/src/wadiz2017/default.js:342,359`, `entries/school/src/containers/SchoolRootPage/SchoolMainLectureApp/components/KeyVisual.tsx:46`, `entries/school/.../SchoolBannerList.jsx:18,24`, `entries/landing/src/wadiz2017/index.scss` 다수 — `static.wadiz.kr/assets/...`).

---

### 4. `embed`

- **패키지**: `@wadiz-static/embed` (`entries/embed/package.json:3`)
- **publicPath**: `/embed/` (`entries/embed/package.json:5`)
- **devServer.port**: 9094 (`entries/embed/package.json:7`)
- **책임**: 프로젝트 임베드 위젯 설정 UI ("프로젝트를 외부 페이지에 임베드하기" 기능). Desktop/Mobile 분기 UI.
- **빌드 진입점** (`entries/embed/webpack.config.js:12-22`):
  - entry: `src/index.js` (+ dev 용 waffle css / `@babel/polyfill` / `webpackHotDevClient`)
  - `output.library: 'WadizEmbedApp'` — **다른 엔트리와 달리 전역 `window.WadizEmbedApp` 으로 export** (라이브러리 타겟 UMD 네임드 바인딩).
- **진입 코드** (`src/index.js` 전체):
  ```js
  import { reactRendererWithInitialization } from 'shared/reactRenderer';
  import EmbedSettings from './EmbedSettings';
  reactRendererWithInitialization(EmbedSettings, 'embed-settings-app');
  ```
- **컴포넌트 구성**: `src/EmbedSettings/` 하위 `EmbedSettings.jsx`, `EmbedSettingsDesktop.jsx`, `EmbedSettingsMobile.jsx`, `components/`, `containers/`, `contexts/`, `hooks/`, `utils/` (`ls` 결과).
- **사용 라이브러리**: React 18.2, `clipboard`, `classnames`, `prop-types`. Redux 없음.
- **API 호출**: 진입점에 없음. 하위 containers 내부에서 처리될 가능성 — 이 문서에서는 다루지 않음.

---

### 5. `floating-buttons`

- **패키지**: `@wadiz-static/floating-buttons` (`entries/floating-buttons/package.json:3`)
- **publicPath**: `/static/floating-buttons/` (`entries/floating-buttons/package.json:5`)
- **devServer.port**: 9119 (`entries/floating-buttons/package.json:7`)
- **책임**: 페이지 우하단 등에 고정되는 **플로팅 버튼 세트** (채팅/상단 이동 등). 특히 "WAi(와이) 플로팅 버튼" 을 앱/웹 모두에서 동일하게 노출하는 책임.
- **빌드 진입점** (`entries/floating-buttons/webpack.config.js:11-17`):
  - entry: `./index.jsx` (엔트리 디렉터리 최상단의 `index.jsx`)
- **진입 코드** (`index.jsx` 전체 5줄):
  ```js
  import { reactRendererWithInitialization } from 'shared/reactRenderer';
  import App from './src/App';
  reactRendererWithInitialization(App, 'floating-buttons-app');
  ```
- **App 본체** (`src/App.jsx:10-33`):
  - `@tanstack/react-query` 의 `QueryClient` 인스턴스를 모듈 스코프에서 생성 (`refetchOnWindowFocus: false`)
  - `isWadizApp` (와디즈 앱 내부 WebView 여부) 이고 경로가 `/web/school` · `/web/m/school` 이 아니면 `return null` — 앱에서는 스쿨 페이지에서만 노출되는 조건부 부착
  - `<QueryClientProvider><FloatingButtons /></QueryClientProvider>` 렌더. `FloatingButtons` 는 `@wadiz/react-common` 제공
- **사용 라이브러리**: React 18.2, `@tanstack/react-query` (동일 `QueryClient` 를 쓰지만 외부 alias 로 해결: `resolve.alias` 에서 `static/node_modules/@tanstack/react-query` 지정, `webpack.config.js:24`). Redux 없음.
- **API 호출**: 진입점에서 없음. `FloatingButtons` 내부에서 react-query 로 어떤 조회를 할 수는 있으나 이 repo의 엔트리 바운더리를 넘어감.

---

### 6. `iam`

- **패키지**: `@wadiz-static/iam` (`entries/iam/package.json:3`)
- **publicPath**: `/static/iam/` (`entries/iam/package.json:5`)
- **devServer.port**: 9110 (`entries/iam/package.json:7`)
- **책임**: Identity & Access 관련 작은 컴포넌트 묶음. 본인(성인)인증, 친구 초대, 스타트업 연락처 목록, 마케팅 알림 동의 등 4개 독립 마이크로 페이지.
- **빌드 진입점** (`entries/iam/webpack.config.js:9-19`): 4개 파일을 **동일한 `main` chunk 에 합쳐서** 번들링 — 각 페이지 DOM placeholder 존재 여부로 조건 분기하는 패턴이 아니라, 렌더러 호출이 대상 id 가 없으면 `null` 을 반환하도록 설계됨.
  - `./adult-authentication/index.js`
  - `./invite-friends/index.jsx`
  - `./marketing-notification-settings/index.jsx`
  - `./startup-contact-list/index.jsx`
- **렌더링 호출**
  - `adult-authentication/index.js:7-8` —
    ```js
    reactRendererWithInitialization(AdultVerificationContent, 'adult-auth-app');
    reactRendererWithInitialization(AdultCertificationSuccess, 'adult-auth-success-app');
    ```
    `AdultVerificationContent` 는 `@wadiz/ui/AdultVerificationContent`, `AdultCertificationSuccess` 는 `./src/AdultCertificationSuccess` (로컬). RENDERER_ID_SELECTORS.md 는 과거 `AdultCertification` 컴포넌트였음을 기록 — 현행은 `@wadiz/ui` 로 대체된 상태.
  - `invite-friends/index.jsx:4` — `reactRendererWithInitialization(InviteFriendsApp, 'invite-friends-app')`
  - `startup-contact-list/index.jsx:4` — `reactRendererWithInitialization(StartupContactListApp, 'startup-contact-list-app')`
  - `marketing-notification-settings/index.jsx` — `MarketingNotificationSettingsApp` 을 **default export 만** 하고 `reactRenderer` 호출 없음. 렌더 시점 호출부가 이 repo에서는 확인되지 않음 (다른 엔트리나 외부 묶음에서 사용될 가능성).
- **사용 라이브러리**: React 18.2, `@reduxjs/toolkit`, react-redux, redux, redux-thunk (Redux store 사용), `react-router-dom@6`, `react-helmet-async@1.3.0`, `react-media@1.9.2`, `immer`, `dayjs`. (`entries/iam/package.json:17-42`)
- **외부 패키지**: `@wadiz/fetch-api`, `@wadiz/request`, `@wadiz/react-common`, `@wadiz/web-root`, `@wadiz/web-redux-store`, `@wadiz/store-component`, `@wadiz/maker-following`, `@wadiz/main-common`.
- **API 호출**: 진입점에서 없음. `invite-friends`/`startup-contact-list` 의 하위 `*App` 컴포넌트가 `@wadiz/fetch-api`/`@wadiz/request` 를 사용할 것으로 추정되나 본 문서 범위 밖.

---

### 7. `landing`

- **패키지**: `@wadiz-static/landing` (`entries/landing/package.json:3`)
- **publicPath**: `/landing/` (`entries/landing/package.json:5`)
- **devServer.port**: 9096 (`entries/landing/package.json:7`)
- **책임**: 캠페인/이벤트/약관 등 **다(多) 랜딩 페이지 집합**. 엔트리 1개에서 webpack multi-entry 로 다수의 랜딩 페이지를 각자의 chunk 로 빌드. Wadiz Awards 연도별, 팬즈메이커 월별, 라인프렌즈, IP 라이선스, 트렌드 리포트, Welcome Maker, Supporter Club 등 마케팅 · 이벤트 페이지가 모두 여기에 소속.
- **빌드 진입점** (`entries/landing/webpack.config.js:22-36` + `entry.config.js:1-42` + `entries.js`):
  - `entries.js` 가 고정 디렉터리 목록 나열(`about`, `board`, `bestmaker2017`, `bestmaker2018`, `partners`, `startup-registration`, `startup-requesting-administrator`, `terms`, `terms-confirm`, `terms-embed`, `wadiz2017`, `apps`) — 주석으로 `w9`, `w9-webinar` 는 비활성 (`entries.js:1-17`)
  - `entry.config.js` 가 각 디렉터리의 `index.scss`/`index.js`/`index.ts` 존재 여부에 따라 entry 자동 구성, 결과를 `{dirName: [stylePath, scriptPath]}` 형태로 반환 (`entry.config.js:18-37`).
  - 결과적으로 chunk 이름이 디렉터리명과 동일 (`about.js`, `terms.js`, `apps.js` 등).
- **주요 렌더링 호출 (selector 중심)**
  - `src/startup-registration/landing.tsx:4-6` — `DOMContentLoaded` 후 `reactEmbedRendererWithInitialization(StartupRegistrationApp, '#startup-registration-app')` (jQuery 스타일 `#` 셀렉터).
  - `src/terms-confirm/terms-confirm.jsx:4` — `reactEmbedRendererWithInitialization(TermsConfirmApp, '#terms-confirm-app', { isOpen: true })` (`@wadiz/terms-confirm-modal`).
  - `src/supporter-club/index.js:4` — `SupporterClubIntro` → `supporter-club-intro`. 컴포넌트는 `../../../main/src/pages/landing/supporter-club-intro/SupporterClubIntro` 로 **`main` 엔트리의 소스 트리를 넘나들어 import** 하는 교차 참조가 존재.
  - `src/w9/w9-landing.js` — `#w9` 페이지 (w9 비활성화 주석과 별개로 파일은 존재). `$('.w9-join-button-app').each(function … reactEmbedRendererWithInitialization(W9MembershipJoinButton, this))` 처럼 jQuery 각 DOM 요소 자체를 target 으로 넘김 (`w9-landing.js:42-56`). `@wadiz/equity-w9-membership-app` 을 **동적 import**.
  - `src/apps/index.js` — 6개 서브 앱 번들(`welcomeMaker`, `wadizAwards`, `trend-report`, `line-friends`, `iplicense`, `fanz-maker`) 재수출.
  - `src/apps/welcomeMaker/index.js:5` — `WelcomeMakerApp` 를 `lazyWithPreload` 로 동적 import 후 `welcome-maker` id 에 임베드.
  - `src/apps/wadizAwards/wadiz-awards.jsx` — 연도별 컨테이너(2019~2025) 를 `lazyWithPreload` 로 모두 import 해두고 `document.querySelector` 로 존재 여부 확인 뒤 렌더:
    - `#wadiz-awards-app-2025-result` (`:50-51`), `2024-result`(`:54`), `2023-result`(`:58`), `2022-result`(`:62`), `2022`(`:67`), `2021`(`:72`), `2021-result`(`:77-90`), `2020`(`:94`), `2019`(`:99`), `#awards-header`(`:104`), `#awards-introduce`(`:108`), `#last-awards`(`:113`)
    - 각 연도 컨테이너 근처에서 `renderTabElement()` 를 호출해 `#maker-tab-control` 의 오프셋에 맞춰 `.wadiz-awards .header` 의 `top` CSS 를 스크롤에 연동 (`:23-36`). 순수 DOM 조작.
    - `LoginAuthentication` (`@wadiz/react-common`) 래퍼로 권한 체크를 강제하는 패턴.
    - RENDERER_ID_SELECTORS.md 는 2025 항목이 누락된 상태이며 현행 소스는 2025 까지 추가됨.
  - `src/apps/fanz-maker/index.js:12-18` — 월별 id 7개 (`fanz-maker-202107`, `…108`, `…109`, `…112`, `fanz-maker-202201`, `…204`, `…206`) 에 각기 다른 컨테이너 렌더.
  - `src/apps/line-friends/index.js:6` — `reactRendererWithInitialization(LineFriends, '#line-Friends')` (`#` 접두 + 대문자 id).
  - `src/apps/iplicense/index.js:7-11` — `#iplicense-main` / `#alwayz-maker` 존재 시에만 렌더.
  - `src/apps/trend-report/index.js:7-8` — `#trend-report-2022`, `#trend-report-202101` (`#` 접두).
- **퍼블리시 스크립트** (`entries/landing/scripts/publish.js`):
  - `public/` 하위의 `*.html` 을 읽어 `<body>` 부분만 추출(cheerio), `<basename>.ssr.html` 로 `buildDirectory` 에 복사. `static-manifest.json` 을 생성해 각 파일의 publicPath 를 기록 (`publish.js:20-42`).
  - `copy-html` 이 `prebuild: run-s clean copy-html` 에서 자동 실행됨 (`package.json:11`).
  - `STATIC_DEPLOYMENT_ORIGIN` 이 있으면 절대 URL, 없으면 상대 URL 로 저장.
- **사용 라이브러리**: React 18.2, MobX 3, react-redux + redux + redux-thunk, react-router-dom 6, `react-dates@21.8.0`, `react-hook-form@7.54.2` + `react-hook-form-deprecated@3.28.4`, `react-slick@0.26`, `slick-carousel@1.6`, `react-helmet-async@1.3`, `react-countup`, `d3@5`, `flipclock`, `jquery@2.1.3`, `dayjs`, `cheerio` (`entries/landing/package.json:18-58`).
- **외부 패키지**: `@wadiz/banner`, `@wadiz/react-promotion-banner`, `@wadiz/equity-w9-membership-app`, `@wadiz/fetch-api`, `@wadiz/terms-confirm-modal`, `@wadiz/lottie`.
- **API 호출**: 진입점에서 직접 호출은 없음. 내부 컨테이너에서 `@wadiz/fetch-api` 사용 가능성 — 범위 외.

---

### 8. `main`

- **패키지**: `@wadiz-static/main` (`entries/main/package.json:3`)
- **publicPath**: `/main/` (`entries/main/package.json:6`)
- **devServer.port**: 9091 (`entries/main/package.json:8`)
- **책임**: 와디즈 **메인 SPA** — 홈, 리워드 프로젝트 상세, 투자 프로젝트 상세, 주문 페이지 등 주요 서비스 화면의 클라이언트 런타임. 엔트리 13개 중 가장 무거움(의존성 70+).
- **빌드 진입점** (`entries/main/webpack.config.js:87-97`):
  ```
  entry.main = [
    (dev) react-dev-utils/webpackHotDevClient,
    (dev) @babel/polyfill,
    (dev) packages/waffle/src/styles/style.css,
    '@wadiz/polyfill',
    '../web/src/common/index-main.js',   // web 엔트리의 공통 부팅 코드 포함
    '../web/src/layout/index.js',        // web 엔트리의 헤더/푸터 레이아웃 부팅 포함
    './src/index.jsx',
  ]
  ```
  → 빌드 결과가 **자체적으로 `web` 엔트리의 레이아웃·부트스트랩을 흡수** 하므로 JSP 에서 web 번들 없이 main 번들만으로도 공통 초기화가 가능하도록 설계. (React SPA 이므로 JSP 를 통하지 않는 경우도 고려된 듯.) dev server 에는 `historyApiFallback` 이 `^/web/(main|winvest|wreward)` 경로를 `/index.html` 로 재작성하도록 등록됨 (`webpack.config.js:40-42`).
- **dev proxy** (`webpack.config.js:48-63`): `/web/account`, `/web/waccount`, `/web/wmypage`, `/web/wpoint`, `/web/board`, `/web/wmain`, `/web/wpremium`, `/web/winvest/ajax`, `/web/wreward/ajax`, `/web/reward/api`, `/web/equity/`, `/web/campaign/ajaxGetEquityComingList`, `/web/wsub/getCampaignStatistics`, `/resources` 등 레거시 `com.wadiz.web` 경로를 프록시.
- **주요 렌더링 호출**
  - `src/index.jsx:9` — `reactRendererWithInitialization(MainApp, 'main-app')` — `div#main-app` placeholder 가 JSP 에 심어져 있는 구조.
  - `src/index.jsx:12-28` — MSW 부트 (`NODE_ENV=development && REACT_APP_MSW_ENABLE=true` 시 `getWorkder(MOCK_TYPE.MAIN)` 로드 후 `renderApp()`).
  - `src/features/funding/reward/pages/Supporter/funding-detail/index.jsx:4` — `FundingDetailApp` → `funding-detail-app`.
  - `src/pages/invest/index.js:4` — `NextBrand` → `wadiz-next-brand` (투자 > 넥스트브랜드 페이지).
- **MainApp 구성** (`src/MainApp.jsx:1-77`):
  - Redux `Provider` (`configureStore()` 에서 생성된 store) + `@tanstack/react-query` `QueryClientProvider` + React Router 6 `RouterProvider` + `GlobalPageLoader`.
  - `QueryCache.onError` 에 전역 Sentry 리포트 + `showToast` 로직. 401/403 은 무시. `PATH_WHITELIST = ['/web/wreward/', '/web/preorder/', '/web/store/', '/web/main']` 에 속한 페이지에서만 토스트 노출.
  - `initRouteMatcher(router.routes, NESTED_PATHS)` — SPA 여부 판정용 라우트 매처 초기화.
  - `process.env.ENVIRONMENT !== 'live'` 일 때 `./CustomFetch` 를 dynamic import 해 fetch monkey-patch.
- **사용 라이브러리**: React 18.2, `@reduxjs/toolkit`, react-redux, redux, redux-logger, redux-pack, redux-thunk, react-router-dom 6, `@tanstack/react-query`, `react-hook-form@7.54.2`, `yup`, `@hookform/resolvers`, `react-helmet-async`, `react-modal`, `react-slick`, `react-easy-crop`, `react-player`, MobX 3, `axios@1.15`, `axios-mock-adapter`, `marked`, dayjs, slick-carousel, `qrcode.react`, `sha1`, `classnames`, `js-cookie`, `lodash-es` 등 대규모 의존성 (`entries/main/package.json:18-86`).
- **외부 패키지** (`main-common`, `notice-popup`, `main-more-app`, `maker-profile-app`, `reward-project-report`, `reward-news-app`, `reward-simple-pay-app`, `store-component`, `maker-following`, `coupon`, `components`, `search-input`, `banner`, `lottie`, `board-common`, `oauth`, `react-ad-boundary`, `react-promotion-banner`, `html-markup-component`, `fetch-api`, `request`, `helpers`, `web-root`, `web-redux-store`, `web-footer`, `react-common`, `polyfill`, `core` 등).
- **API 호출**: 엔트리 진입점 단에는 없음. MainApp 내부에서 `@tanstack/react-query` 를 이용한 대량 호출이 일어나며 onError 만 엔트리에서 관측 가능.

---

### 9. `open-account`

- **패키지**: `@wadiz-static/open-account` (`entries/open-account/package.json:3`)
- **publicPath**: `/static/open-account/` (`entries/open-account/package.json:5`)
- **devServer.port**: 9102 (`entries/open-account/package.json:7`)
- **책임**: 투자 서비스용 **계좌 개설(구 W9) 흐름** 전용 페이지.
- **빌드 진입점** (`entries/open-account/webpack.config.js:8-14`):
  - entry: `./src/index.jsx` (+ dev polyfill · hot client · waffle css)
- **진입 코드** (`src/index.jsx` 전체):
  ```js
  import { reactRendererWithInitialization } from 'shared/reactRenderer';
  import OpenAccountApp from './OpenAccountApp';
  reactRendererWithInitialization(OpenAccountApp, 'open-account-app');
  ```
- **static.config.js** (`entries/open-account/static.config.js`): 한 줄 — `module.exports = require('shared/config/webpack.static.config')`. 이는 **SSG(static site generator)** 모드용 보조 설정(`static/packages/shared/config/webpack.static.config.js:53-55` 의 `StaticSiteGeneratorPlugin`) 을 import 하는 파일로, 정적 HTML 프리렌더 파이프라인이 일부 엔트리에 존재함을 시사합니다. 실행 스크립트는 이 repo 에서는 별도 정의되지 않음 — 사용 실태는 확인 불가.
- **사용 라이브러리**: React 18.2, `react-redux`, `redux`, `redux-thunk` (Redux store 존재 — `src/store/` ), `react-router-dom 6`, `react-hook-form-deprecated@3.28.4` (레거시 react-hook-form 3 을 deprecated 별칭으로 사용), `@wadiz/validation-deprecated`, classnames, lodash-es, prop-types (`entries/open-account/package.json:16-34`).
- **외부 패키지**: `@wadiz/react-common`, `@wadiz/web-root`, `@wadiz/web-redux-store`.
- **API 호출**: 진입점에서 없음. 내부 `AccountWrapperApp.jsx` / `iam-open-account/` 서브 컴포넌트에서 처리.

---

### 10. `personal-message`

- **패키지**: `@wadiz-static/personal-message` (`entries/personal-message/package.json:3`)
- **publicPath**: `/personal-message/` (`entries/personal-message/package.json:5`)
- **devServer.port**: 9099 (`entries/personal-message/package.json:8`)
- **책임**: 프로젝트 문의하기 / 1:1 메시지함 (메이커 ↔ 서포터). 두 페이지(`chatSpace`, `inbox`) 를 하나의 번들로.
- **빌드 진입점** (`entries/personal-message/webpack.config.js:13-19`):
  - entry: `./src/index.jsx`
  - dev proxy (`:22-28`): `/web/error`, `/web/waccount`, `/web/wmain`, `/web/board`, `/resources` 를 `com.wadiz.web` 으로 프록시
  - dev 전용 `HtmlWebpackPlugin` 2개 → `chatSpace.html`, `inbox.html` (로컬 개발 편의용)
- **진입 코드** (`src/index.jsx` 전체 67줄, 요약):
  - `AppInitializer.initialize()` (공통 부트스트랩 — `@wadiz/app-initializer`) → resolve 되면 DOM 에 `#chatSpace-app` 또는 `#inbox-app` 이 있는지 각각 조회 후 `createRoot(el).render(<ErrorBoundary><ChatSpace|Inbox {...props} /></ErrorBoundary>)` 수행 (`:18-43`).
  - `ChatSpace` 는 URL 쿼리에서 `projectId`, `projectType` 를 `qs.parse` 해 props 로 주입 (`:21`).
  - 초기화 실패 시 Sentry fatal 리포트 + `AppInitErrorContent` 를 대신 렌더 (`:49-66`).
  - **특징**: 다른 엔트리와 달리 `shared/reactRenderer` 를 거치지 않고 `react-dom/client` 의 `createRoot` 를 직접 사용. (반면 dataSet 프롭 주입은 동일하게 `@wadiz/utils/element` 의 `getDataSet` 로 수행.)
- **API 호출** (`src/services/ChatSpaceService.js`, `src/services/InboxService.js`):
  - 내부 유틸 `utils/fetchJSON` (`axios` 래퍼, `src/utils/fetchJSON.js`) 로 다음 엔드포인트에 호출:
    - `GET /web/board/personalMessage/projectType/{projectType}/projectId/{projectId}` — 메시지 목록 조회 (`ChatSpaceService.js:3-14`)
    - `POST /web/board/personalMessage/projectType/{projectType}/projectId/{projectId}` — 메시지 생성 (`ChatSpaceService.js:16-22`)
    - `GET /web/board/personalMessage/inbox/personal` — 서포터용 inbox 목록 (`InboxService.js:3-14`)
    - `GET /web/board/personalMessage/inbox/host` / … — 메이커용 inbox 목록 (파일 상단 일부만 관측)
  - **WadizError** 코드 매핑 (`fetchJSON.js:29-55`): `ERR9999`(발송 차단) / `ERR9998`(본인 문의 불가) / `ERR9997`(사진 전송 5회 제한). 성공 코드는 `SUSS000` + `success === 'true'`. 이 규약이 레거시 `com.wadiz.web` 응답 포맷임을 시사.
- **사용 라이브러리**: React 18.2, `axios`, `axios-mock-adapter`, `qs`, `zustand@5.0.5`, `react-router-dom 6` (`entries/personal-message/package.json:17-32`). Redux 없음, zustand store 사용 (`src/zustand-stores/`).

---

### 11. `reward`

- **패키지**: `@wadiz-static/reward` (`entries/reward/package.json:3`)
- **publicPath**: `/reward/` (`entries/reward/package.json:5`)
- **devServer.port**: 9100 (`entries/reward/package.json:7`)
- **책임**: 리워드(크라우드펀딩) **결제 플로우** 및 제품 디테일 UI. 결제 예약(간편결제), 펀딩 완료 화면, 리워드 제품 카드, 환불 정책 가이드 등.
- **빌드 진입점** (`entries/reward/webpack.config.js:11-14`):
  - entry: `./src/index.jsx` (+ dev hot client)
- **진입 코드 트리**
  - `src/index.jsx` (`:1-3`):
    ```js
    import './payments/index';
    import './reward-product/index';
    import './funding-complete/index';
    ```
  - `src/payments/index.jsx` (`:1-2`):
    ```js
    import './SimplePay';
    import './funding-price';
    ```
  - `src/payments/SimplePay.jsx` (전체 55줄):
    - `window.simplepay.initSimpleReservationDialog(data)` 를 글로벌에 바인딩. 내부에서 `@wadiz/core` 의 `eventBus.emit('payment:simple-pay:requested', data)` 실행 (`:24-31`).
    - 주석 `리워드 결제 예약 - step20.jsp / myfundingPurchaseDetail.jsp` 로 **레거시 JSP 파일명이 명시** (`:29`). 본 repo 에서 직접 관측되는 몇 안 되는 JSP 연결 흔적 중 하나.
    - `DOMContentLoaded` 후 `document.getElementById('reward-simplepay-app')` 발견 시 `createRoot` 로 `PurchaseApp` (`@wadiz/reward-simple-pay-app`) 렌더. `'datachange'` 커스텀 이벤트 와 `'pageshow'` (Safari bfcache) 이벤트에 재렌더 훅을 연결 (`:36-55`).
  - `src/payments/funding-price.js` (전체 5줄):
    ```js
    reactEmbedRendererWithInitialization(FundingPriceApp, 'reward-funding-price-app');
    ```
  - `src/reward-product/index.js` (`:1-16`):
    - `reactEmbedRendererWithInitialization(RewardProductApp, 'reward-product-app')`
    - `DOMContentLoaded` 후 `document.querySelectorAll('#funding-refund-policy-guide-app')` 를 전부 순회해 `FundingRefundPolicyGuideApp` 렌더 — selector 가 중복된 경우(여러 id 중복) 대비.
    - MSW 토글: `REACT_APP_MSW_ENABLE` 일 때 `MOCK_TYPE.FUNDING_PRODUCT` 워커 부팅 후 `initialize()`.
  - `src/funding-complete/index.js` (전체 4줄):
    ```js
    reactEmbedRendererWithInitialization(RewardFundingCompleteApp, '#reward-funding-complete-app');
    ```
- **RENDERER_ID_SELECTORS.md 대비 차이**: 해당 문서에는 `campaign-support-signature` 가 `reward/src/payments/SimplePay.jsx:73` 에 있다고 기록되어 있으나, **현재 SimplePay.jsx 에는 이 호출이 없습니다** (현행 파일은 55줄). 제거된 것으로 보이며, RENDERER_ID_SELECTORS.md 의 2025-01-05 스냅샷 이후 변경됨.
- **사용 라이브러리**: React 18.2, `@reduxjs/toolkit`, react-redux, MobX 3, `classnames`, `intersection-observer`, `qs`, `prop-types`, `react-moment-proptypes` (`entries/reward/package.json:15-42`).
- **외부 패키지**: `@wadiz/reward-simple-pay-app`, `@wadiz/reward-update-news-app`, `@wadiz/reward-coming-news-app`, `@wadiz/reward-news-app`, `@wadiz/reward-project-report`, `@wadiz/payment-price-app`, `@wadiz/react-common`, `@wadiz/maker-following`, `@wadiz/components`, `@wadiz/fetch-api`, `@wadiz/helpers`, `@wadiz/request`, `reward-common`.
- **API 호출**: 진입점에서 없음. 모든 실제 호출은 `@wadiz/reward-*`, `@wadiz/payment-price-app` 등 외부 패키지가 담당.

---

### 12. `school`

- **패키지**: `@wadiz-static/school` (`entries/school/package.json:3`)
- **publicPath**: `/school/` (`entries/school/package.json:5`)
- **devServer.port**: 9104 (`entries/school/package.json:7`)
- **책임**: **Wadiz School** (교육 · 강의) 섹션의 SPA.
- **빌드 진입점** (`entries/school/webpack.config.js:8-14`):
  - entry: `./src/index.jsx`
- **진입 코드** (`src/index.jsx` 전체):
  ```js
  import { reactRendererWithInitialization } from 'shared/reactRenderer';
  import SchoolMainApp from './SchoolMainApp';
  reactRendererWithInitialization(SchoolMainApp, process.env.ROOT_ELEMENT_ID);
  ```
  - **특이점**: 다른 엔트리는 고정 selector 를 쓰지만 여기는 `process.env.ROOT_ELEMENT_ID` (기본값 `'root'`, webpack DefinePlugin 에서 주입 — `static/config/webpackCommonConfig/webpackConfigInstance.js:177`) 로 동적 대상 지정. JSP 쪽에서 다른 루트 id 를 쓸 경우도 수용.
- **SchoolMainApp** (`src/SchoolMainApp.jsx`): `HelmetProvider > Router (BrowserRouter) > SchoolMainWrapper` — 자체 라우터 보유.
- **static.config.js**: 한 줄 `require('shared/config/webpack.static.config')` — open-account 와 동일하게 SSG 보조 설정. 실행 경로 확인 불가.
- **사용 라이브러리**: React 18.2, react-redux, redux, redux-thunk, react-router-dom 6, react-helmet-async, react-media, react-slick, slick-carousel, dayjs, classnames, prop-types, `@wadiz/react-ad-boundary`, `@wadiz/react-promotion-banner` (`entries/school/package.json:16-38`).
- **외부 패키지**: `@wadiz/main-common`, `@wadiz/web-root`.
- **API 호출**: 진입점에 없음. `containers/` 하위에서 `static.wadiz.kr/assets/school/…` 경로의 배너 · Lottie JSON 을 직접 URL 참조 (`src/containers/SchoolRootPage/SchoolMainLectureApp/components/KeyVisual.tsx:46`, `SchoolBannerList.jsx:18,24`).

---

### 13. `web`

- **패키지**: `@wadiz-static/web` (`entries/web/package.json:3`)
- **publicPath**: `/static/web/` (`entries/web/package.json:5`)
- **devServer.port**: 9090 (`entries/web/package.json:7`)
- **책임**: **가장 중요한 공통 엔트리**. 레거시 JSP 거의 모든 페이지에서 최우선으로 로드되어 (a) 전역 폴리필, (b) 전역 jQuery · 레거시 스크립트 · 스타일, (c) 공통 레이아웃(헤더/푸터) 렌더러, (d) 본문 내 HTML 마크업 컴포넌트 오토 렌더링, (e) Sentry 초기화(별도 `sentry` chunk) 를 담당. 또한 `MiniCssExtractPlugin` 과 함께 `wui` chunk 로 Waffle UI 전역 CSS 를 뽑아 배포.
- **빌드 진입점** (`entries/web/webpack.config.js:77-83`):
  ```js
  entry: {
    polyfill: require.resolve('@wadiz/polyfill'),
    wui: path.resolve(paths.frontendRoot, './packages/waffle/src/styles/style.css'),
    common: path.join(__dirname, './src/index.js'),
  }
  ```
  → **3개 번들이 동시에 빌드**: `polyfill.js`, `wui.css`(+ 공통 CSS), `common.js`.
  - 추가로 `webpack.sentry.config.js` 가 별도 실행되어 `src/sentry/index.js` → `sentry.js` chunk 를 만들고 `@sentry/webpack-plugin` 으로 **Sentry 릴리즈 업로드 + 소스맵 전송** 수행 (`webpack.sentry.config.js:22-47`). `release` 값은 `process.env.GIT_COMMIT`.
  - `optimization.splitChunks` 로 `node_modules` 의존성(`@wadiz`, `@sentry`, `wadiz-` 제외) 을 별도 `vendor.js` 로 enforce 분리 (`webpack.config.js:100-118`).
  - `output.libraryTarget: 'umd'` (`:90`).
- **진입 코드** (`src/index.js` 전체 2줄):
  ```js
  import './common/index';
  import './layout/index';
  ```
- **common/index.js** (`src/common/index.js` 전체 28줄):
  - `./library/handlebar` + `./library` + `./library/jquery` import (순서 중요 — jQuery 가 이후 `wadiz` 네임스페이스 코드에서 필요).
  - 공통 SCSS: `_legacy.scss`, `terms-dialog.scss`, `errorpage.scss`, `ui-tabs.scss`.
  - `./wadiz` — 전역 `window.wadiz` 네임스페이스 초기화 (jQuery 의존).
  - `./misc/html-tag`, `./misc/dom-ready` — HTML 태그 · dom-ready 훅.
  - `./legacy` — 레거시 스크립트 묶음.
  - `@wadiz/helpers/utils/trackingEventHelper` import — tracking 유틸 초기화.
  - **WAi 런처 호출** (`:26-27`): `loadAIAgent(undefined, { hideButton: true })` — 버튼 숨김 상태로 `@wadiz/core/hooks/useWAiAIAgent` 의 AI 에이전트 스크립트를 로드. `catch(() => {})` 로 실패 무시.
- **layout/index.js** (`src/layout/index.js` 전체 59줄):
  - `window.wadizHeaderRenderer = headerRenderer`, `window.wadizFooterRenderer = footerRenderer` — 전역 함수 바인딩 (`:6-7`).
  - `WadizHeaderLoaded` / `WadizFooterLoaded` 커스텀 이벤트 핸들러 (`:9-17`) — JSP 가 `<script>` 로드 타이밍에 맞춰 `dispatchEvent(new CustomEvent('WadizHeaderLoaded', { detail: { element } }))` 를 쏴주면 그 자리에 React 헤더를 임베드하도록 설계. JSP-React 브릿지의 핵심.
  - 홈 화면 title 보정 (`:20-26`): 구글봇 외 방문자가 `wadiz` 호스트 + `/` or `/web/wmain` 이면 `document.title = '와디즈'` 로 재설정.
  - `renderHtmlMarkupComponents()` 호출 (`:31-37`) — `DOMContentLoaded` 이후 실행되어 본문의 데이터 속성 기반 컴포넌트들을 자동 React 컴포넌트로 교체 (아래 별도 설명).
  - 스크롤 이벤트 처리 (`:42-58`): `scroll-half-screen`, `scroll-top`, `scroll-apex` 클래스를 `<html>` 에 토글.
- **headerRenderer** (`src/layout/headerRenderer.jsx`): `reactEmbedRendererWithInitialization(Layout, renderTarget)` — JSP 가 전달한 DOM 노드에 `Layout` 컴포넌트를 임베드.
- **footerRenderer** (`src/layout/footerRenderer.jsx`): 동일한 패턴으로 `@wadiz/web-footer` 의 `Footer` 컴포넌트를 임베드.
- **htmlMarkupComponentRenderer.jsx** (`src/layout/htmlMarkupComponentRenderer.jsx:16-22`): 다음 CSS 셀렉터를 가진 요소를 자동 탐지하여 각기 다른 React 컴포넌트로 교체:
  | 셀렉터 | 컴포넌트 |
  |---|---|
  | `div[data-component-name="downloadable-coupons"]` | `DownloadableCouponsWrapper` |
  | `div[data-component-name="wadiz-youtube-player"]` | `YoutubePlayerReactWrapper` |
  | `div[data-component-name="wadiz-image-slider"]` | `ImageSlider` (+ `getPropsFromTarget`) |
  | `div[data-component-name="wadiz-tabs"]` | `Tabs` (+ `getPropsFromTarget`) |
  | `div[data-collection-keyword][data-domain]` | `CollectionCardList` |
  컴포넌트는 모두 `@wadiz/html-markup-component` 제공. `.fr-element` (Froala 에디터) 내부는 skip (`:11`).
- **sentry/index.js** (`src/sentry/index.js:1-83`):
  - `@wadiz/metrics` 의 `Metrics.initialize({ sentry, userInfo })` 로 Sentry 초기화.
  - `installBlacklistPaths` 정규식 목록 (`:10-20`): `/web/wcast/`, `/web/wboard/`, `/web/wsub/`, `/web/wevent/`, `/web/wpage/`, `/web/school/`, `/web/wpartner/`, `/web/waccount/master/`, `/web/progress/dashboard/` — 이 경로들에서는 Sentry 를 설치하지 않음.
  - `allowUrls`: `https?://*.wadiz.kr`.
  - `userInfo` 는 `window.wadiz.globals.userId` / `userName` / `userAccntType` 에서 추출 (live 환경은 email 제외).
  - `beforeSend` 에서 `/web/main/empty` 경로의 이벤트 drop, User-Agent 가 `checkAllowedBrowser` 통과 실패 시 drop (`:37-48`).
- **사용 라이브러리**: React 18.2, jQuery 2.1.3, `jquery-ui`, `jquery-validation`, `js-cookie`, MobX 3, `mobx-react`, `slick-carousel`, `moment`, `handlebars`, `alertifyjs`, `clipboard`, `taggle`, `ua-parser-js`, `prop-types`, `shared` (`entries/web/package.json:26-53`).
- **외부 패키지**: `@wadiz/polyfill`, `@wadiz/fetch-api`, `@wadiz/web-footer`, `@wadiz/react-common`, `@wadiz/terms-confirm-modal`, `@wadiz/html-markup-component`.
- **API 호출**: 엔트리 부트에서 직접 호출은 없음. `@wadiz/metrics` 가 Sentry ingest 로 이벤트 전송(+Sentry 소스맵 업로드는 빌드 시점). `loadAIAgent` 가 외부 AI Agent 스크립트를 동적 로드.

---

## 공통 패턴 (entries 간)

### 1. 렌더러 계약 — `reactRenderer` / `reactEmbedRenderer`

`static/packages/shared/reactRenderer.tsx` 가 단일 계약점. 전 엔트리가 이 모듈의 `reactRenderer` / `reactEmbedRenderer` / `…WithInitialization` 4개 export 중 하나만 사용합니다 (예외: `personal-message` 는 직접 `createRoot`).

- **차이점** (`reactRenderer.tsx:55-108`):
  - `reactEmbedRenderer` — `<Component {...props} />` 만 렌더. ErrorBoundary 없음. 데이터 속성은 자동 주입 (`getDataSet(target)`).
  - `reactRenderer` — 위를 `<ErrorBoundary>` 로 한 겹 감싸고 렌더.
  - `*WithInitialization` — 호출 전에 `AppInitializer.initialize()` (`@wadiz/app-initializer`) 가 resolve 되기를 기다린 뒤 렌더. 실패 시 `AppInitErrorContent` / `ServerErrorContent` (`@wadiz/waffle`) 를 렌더해 사용자에게 초기화 실패를 알리고 Sentry fatal 리포트.
- **타겟 해석** (`reactRenderer.tsx:64-72`):
  - `target` 은 `string | HTMLElement | null` 수용.
  - 문자열이면 `getElements(target)` (from `@wadiz/utils/element`) 가 id 또는 `#…`/`.…` 셀렉터를 파싱. 배열(여러 매칭) 이면 각 요소마다 재귀 호출.
- **Props 병합** (`:75-84`): `Object.assign({}, dataSetProps, optsProps, targetProps)` — DOM 의 `data-*` 속성 우선, 호출자가 준 `props` 로 override, `getPropsFromTarget` 콜백 결과가 최종 override. `metas` 옵션이 있으면 `<meta>` 태그 값도 props 에 주입 (`getMetaData`).
- **렌더** (`:87-90`): React 18 `createRoot(target).render(<ComponentWrapper …/>)`. `ComponentWrapper` 는 디버그 로그(`console.info('[React] Rendered Embed App <Name>')` + `[Props]`, `[Meta]`) 만 담당 (`:38-50`).
- **반환값**: `{ unmount }` — 호출자가 필요 시 언마운트 가능.

### 2. 셀렉터 규칙

- 대부분은 **bare id**: `'main-app'`, `'funding-detail-app'`, `'active-account'` 등.
- 일부는 **jQuery 스타일 `#` 접두**: `'#startup-registration-app'`, `'#terms-confirm-app'`, `'#line-Friends'`, `'#trend-report-2022'`, `'#trend-report-202101'`, `'#reward-funding-complete-app'`.
- 일부는 **동적 DOM 요소**: `reward/src/reward-product/index.js:12` 는 `querySelectorAll` 로 얻은 `element` 를 그대로 전달, `landing/src/w9/w9-landing.js:42-56` 은 jQuery `$(selector).each(function(){ …, this })` 로 `this` 전달, `web/src/layout/headerRenderer.jsx:9` 와 `footerRenderer.jsx:10` 는 호출자가 넘긴 `renderTarget` 을 그대로 전달.
- 일부는 **env 변수**: `school/src/index.jsx:6` — `process.env.ROOT_ELEMENT_ID` (기본 `'root'`).

### 3. AppInitializer + Sentry 실패 처리

`…WithInitialization` 계열을 쓰는 엔트리(거의 전부) 는 초기화 실패 시 해당 DOM 루트에 `<AppInitErrorContent />` 를 렌더하고 Sentry 로 fatal 리포트 (`reactRenderer.tsx:117-134, 143-162`). 사용자는 "앱 초기화 실패" 에러 UI 를 보게 되므로 적어도 빈 화면으로 방치되지 않음.

### 4. MSW (Mock Service Worker) 토글

`main`, `account/my-purchase-detail`, `reward/reward-product` 3곳에서만 다음 공통 패턴:

```js
if (process.env.NODE_ENV === 'development' && process.env.REACT_APP_MSW_ENABLE === 'true') {
  const { getWorkder, MOCK_TYPE } = await import('../../../mocks');
  const { worker } = getWorkder(MOCK_TYPE.XXX);
  await worker.start({ serviceWorker: { url: '…/mockServiceWorker.js' }, onUnhandledRequest: 'bypass' });
  initialize();
} else {
  initialize();
}
```

`mocks/` 는 `static/mocks/` 에 위치 (상위 루트). `MOCK_TYPE` 은 엔트리별 분류(`MAIN`, `MY`, `FUNDING_PRODUCT`).

### 5. 빌드 공통 설정 계층

- **최하층**: `static/config/webpackCommonConfig/webpackConfigInstance.js` (CommonJS 클래스형 빌더). DefinePlugin 주입(`STATIC_DEPLOYMENT_ORIGIN`, `DEPLOYMENT_ORIGIN`, `ROOT_ELEMENT_ID`, `NODE_ENV`, `ENVIRONMENT`), ProvidePlugin(`window.$`/`window.jQuery` = `jquery`), ESLint, Manifest, MiniCssExtract, HtmlWebpackPlugin(dev only), BundleAnalyzer.
- **중층**: `static/packages/shared/config/webpack.config.js` 가 공통 externals(`@sentry/browser: 'Sentry'`, `jquery: 'jQuery'`) 를 추가 후 webpack-merge — 여기가 **CDN 로드 전제의 externals 규약을 박는 지점**. 외부 스크립트(`<script src="CDN/react.js">` 등) 가 존재한다고 가정하고 번들에서 제외.
- **상층**: 각 `entries/<x>/webpack.config.js` 가 entry/resolve.alias 만 차별화.
- **static SSG 보조**: `static/packages/shared/config/webpack.static.config.js` — `ssr.jsx` 를 `StaticSiteGeneratorPlugin` 으로 프리렌더. `axios` 는 `fakeModules/axios.js` 로 치환되어 SSG 중에는 실제 네트워크 호출을 차단. `school`, `open-account` 가 이 설정 파일을 `static.config.js` 에서 re-export. 실행 스크립트는 이 repo에 직접 정의되지 않음.
- **개발 인증서**: 모든 dev server 가 `shared/config/cert` 의 `key`/`crt` 로 HTTPS + `host: 'local.wadiz.kr'` 고정 (`entries/web/webpack.config.js:57-59` 등).

### 6. externals — 바벨 번들에서 빠지는 라이브러리

공통 `webpack.config.js` (`packages/shared/config/webpack.config.js:13-17`):

```js
webpackConfig.externals = { ...webpackConfig.externals, '@sentry/browser': 'Sentry', jquery: 'jQuery' };
```

즉 Sentry 와 jQuery 는 런타임 전역에 이미 있다고 가정. React / React-DOM 은 각 엔트리에서 `resolve.alias` 로 `static/node_modules/react` 를 강제 지정해 **버전 일관성** 을 보장하지만, 본 repo 에서는 ProvidePlugin/externals 로 React 를 CDN 처리하는 것은 관측되지 않습니다. (상위 `static/CLAUDE.md` 는 React 도 CDN externals 처리된다고 기술하지만, 현행 webpack 설정에서는 externals 에 react 가 빠져 있어 번들에 포함되는 것으로 보입니다. 확인 불가.)

---

## 배포 · 주입 흐름

### 빌드 → 산출물

```
static/
└── build/
    ├── static/web/        ← /static/web/main.js, vendor.js, manifest.json, wui.css, sentry.js (별개 build:sentry)
    ├── main/              ← /main/main.js, main.css, manifest.json, js/*.chunk.js
    ├── account/           ← /account/main.js, follow.js, social.js, my.js, makinglist.js, maker-profile.js, my-purchase-detail.js, reward-payments.js, vendor.js, manifest.json
    ├── analytics/         ← /analytics/client.js (only)
    ├── assets/            ← /assets/ 하위 전체 public 복사본 (이미지/폰트/PDF/Lottie JSON 등)
    ├── embed/
    ├── static/floating-buttons/
    ├── static/iam/        ← 4개 하위 앱이 하나의 main.js
    ├── landing/           ← about.js, apps.js, bestmaker2017.js, …, terms.js, wadiz2017.js 등 + *.ssr.html
    ├── static/open-account/
    ├── personal-message/
    ├── reward/
    └── school/
```

(경로는 각 `package.json` 의 `publicPath` + `webpack.config.js` 의 entry 이름 결합)

### CDN 업로드 · 무효화

- 빌드 후 어떤 파이프라인이 `build/` 의 산출물을 `static.wadiz.kr` 에 업로드하는지는 이 repo 에서는 확인 불가 (Jenkins/스크립트 외부).
- `static/scripts/tasks/cdnPurge.js` (`:30-56`) 가 배포 후 CDN 캐시를 무효화하는 스크립트. 동작:
  1. `findEntryChunks()` 로 각 엔트리의 `build/<publicPath>/manifest.json` 을 모두 읽어 `Object.values()` 를 합친 URL 리스트 생성 (`:17-28`).
  2. 각 URL 에 대해 `http://purge.concdn.com/cgi-bin/cpurge.cgi?url=<host><path>` 에 GET 요청 (호스트가 `static.wadiz.kr` 일 때만).
  3. purge 결과 문자열에 `'success'` 가 포함되면 성공, 추가로 `axios.get(chunkUrl)` 로 200 여부 확인.
- `STATIC_DEPLOYMENT_ORIGIN` 환경 변수가 빌드 시 `process.env` 에 설정되면 manifest 에 **절대 URL** 이 저장되어 JSP 에서 그대로 사용 가능 (`static/packages/shared/config/paths.js:12-17`, `static/config/webpackCommonConfig/paths.js:12-17`).

### 레거시 JSP 주입

- 이 repo 에는 JSP 파일이 없어 실제 주입 코드는 관측 불가. 단, 일부 주석과 엔트리 엔트리포인트에서 간접 근거를 찾을 수 있음:
  - `reward/src/payments/SimplePay.jsx:29` 주석: `// 리워드 결제 예약 - step20.jsp / myfundingPurchaseDetail.jsp`
  - `account/src/empty/index.jsx:1-5` 주석: `// TODO: com.wadiz.web 배포 이전에 UI 중복 노출 방지(배포 이후 제거)`
- 상위 `static/CLAUDE.md` Section 8 이 JSP 로드 순서를 규약으로 설명(공통 `web` 번들 → 페이지별 번들 1개). 본 repo 의 코드와는 정합적이나 실제 JSP 가 그 규약을 지키는지는 `com.wadiz.web` 문서 참조 필요.

### 배포 관련 환경 변수

`static/config/webpackCommonConfig/webpackConfigInstance.js:169-182` 에서 `webpack.DefinePlugin` 으로 주입:

| 변수 | 용도 |
|---|---|
| `process.env.NODE_ENV` | `'development'` / `'production'` |
| `process.env.ENVIRONMENT` | `'local'` / `'dev'` / `'stage'` / `'live'` (기본 `'local'`) |
| `process.env.DEPLOYMENT_ORIGIN` | 서비스 origin 추정 |
| `process.env.STATIC_DEPLOYMENT_ORIGIN` | 정적 자원 origin (보통 `https://static.wadiz.kr`) — publicPath 절대화에도 사용 |
| `process.env.ROOT_ELEMENT_ID` | SPA 루트 id (기본 `'root'`) — school 에서 사용 |

Sentry 릴리즈는 별도 빌드 스크립트(`build:sentry` in `entries/web/package.json:12`) 가 `entries/web/webpack.sentry.config.js` 를 사용해 `sentry.js` chunk + 소스맵을 Sentry 프로젝트에 업로드. Release 키는 `GIT_COMMIT` 환경 변수.

---

## 경계 및 미탐색 영역

이 repo(`wadiz-frontend/static/entries/`) 에서 **확인 불가** 하므로 본 문서가 다루지 않는 영역:

1. **JSP 파일 본체**: `<script src="…">` 삽입 위치, `<div id="main-app">` 등 placeholder 선언, `dispatchEvent(new CustomEvent('WadizHeaderLoaded'))` 트리거 로직은 `com.wadiz.web` (레거시 Spring + JSP) 에 존재. `docs/com.wadiz.web.md` 및 `docs/com.wadiz.adm.md` 참조.
2. **외부 패키지 내부 구현**: `@wadiz/react-common`, `@wadiz/reward-simple-pay-app`, `@wadiz/equity-*`, `@wadiz/main-common`, `@wadiz/web-footer`, `@wadiz/html-markup-component`, `@wadiz/core`, `@wadiz/metrics`, `@wadiz/fetch-api`, `@wadiz/oauth`, `@wadiz/waffle`, `@wadiz/app-initializer` 등은 `wadiz-frontend/static/packages/` 와 `wadiz-frontend/packages/` 에 모노레포 내부로 존재. 각 진입점이 **어떤 prop · 이벤트 인터페이스를 노출하는지, 내부에서 어떤 API 를 호출하는지** 는 해당 패키지의 문서 필요 — 본 문서는 import 관계만 기록.
3. **CDN 업로드 · Jenkins 파이프라인**: 이 repo 에는 `Jenkinsfile`, CI 스크립트가 포함되어 있지 않아 확인 불가. `cdnPurge.js` 가 purge 만 담당하며 업로드 스크립트는 별도.
4. **com.wadiz.web 측 `resourceServerUrl`, `STATIC_DEPLOYMENT_ORIGIN` 값의 실제 기본 설정**: 환경별 값이 어디에 정의되는지 역시 외부.
5. **`school`, `open-account` 의 `static.config.js`(SSG) 실행 엔트리**: `webpack --config static.config.js` 같은 스크립트가 각 엔트리 `package.json` 에 명시되지 않아 실제 언제 호출되는지 확인 불가. SSG 산출물(`*.ssr.html`) 은 `landing/scripts/publish.js` 경로와 달리 별도로 빌드되는 것으로 보이나 본 repo 에 사용례 없음.
6. **`assets` 의 상세 콘텐츠 목록**: 복사 대상 디렉터리(`public/equity`, `public/fonts`, `public/pdfjs`, `public/wadizawards` 등) 는 바이너리 자산이므로 구성만 기록하고 내용은 생략.
7. **RENDERER_ID_SELECTORS.md 와 현행 소스의 불일치**: 본 문서 작성 시점(2026-04-20) 기준, 최소 다음 2개 drift 관측 — (a) `reward/SimplePay.jsx:73` 의 `campaign-support-signature` 제거됨, (b) `landing/src/apps/wadizAwards/wadiz-awards.jsx` 에 `wadiz-awards-app-2025-result` 가 추가됨(RENDERER_ID_SELECTORS.md 는 2024 까지만 기록). 현행 소스가 항상 우선.
8. **`iam/marketing-notification-settings` 의 렌더러 호출 위치**: 이 디렉터리는 `MarketingNotificationSettingsApp` 을 default export 만 할 뿐 이 repo 내부에서 `reactRenderer` 를 호출하지 않음. 과거 버전에서 제거된 렌더러 호출일 수 있으나 컴파일 대상에는 여전히 포함 — 사용처 확인 필요.
9. **`landing/w9` 활성/비활성 혼재**: `entries.js` 에서 `w9`/`w9-webinar` 디렉터리가 주석 처리되었지만 `src/w9/w9-landing.js` 는 그대로 유지. 빌드 포함 여부는 `entries.js` 의 명시적 목록에 의존하므로 **현재 빌드에는 미포함**.
10. **`RENDERER_ID_SELECTORS.md:83-97` auth 섹션**: 문서에는 `auth` 엔트리(2개 selector: `auth-app`, `error-app`) 가 기록되어 있으나 현 task 대상 13개에는 포함되지 않음. `entries/auth/` 디렉터리 자체가 현재 존재하지 않거나 이름 변경된 것으로 보이며 — `ls entries/` 결과에는 포함되지 않음. (본 task 의 scope 는 13개 entries 로 제한.)

---

## 요약 표

| 엔트리 | publicPath | devPort | React | Redux | React-Query | MSW | 주요 selector 개수 |
|---|---|---|---|---|---|---|---|
| account | `/account/` | 9092 | ✅ | ✅ (react-redux + thunk) | — | ✅ (my-purchase-detail) | 13 (~selector + 다수 내부 id) |
| analytics | `/analytics/` | — | ❌ | ❌ | ❌ | ❌ | 0 (React 미사용) |
| assets | `/assets/` | — | ❌ | ❌ | ❌ | ❌ | 0 (단순 파일 복사) |
| embed | `/embed/` | 9094 | ✅ | ❌ | ❌ | ❌ | 1 (`embed-settings-app`) |
| floating-buttons | `/static/floating-buttons/` | 9119 | ✅ | ❌ | ✅ | ❌ | 1 (`floating-buttons-app`) |
| iam | `/static/iam/` | 9110 | ✅ | ✅ (toolkit) | — | ❌ | 3 (+ marketing-settings 미호출) |
| landing | `/landing/` | 9096 | ✅ | ✅ (toolkit) | — | ❌ | 30+ (Awards 연도별 · Fanz-maker 월별) |
| main | `/main/` | 9091 | ✅ | ✅ (toolkit + redux-pack) | ✅ | ✅ | 3 (`main-app`, `funding-detail-app`, `wadiz-next-brand`) |
| open-account | `/static/open-account/` | 9102 | ✅ | ✅ (thunk) | — | ❌ | 1 (`open-account-app`) |
| personal-message | `/personal-message/` | 9099 | ✅ | ❌ (zustand) | ❌ | ❌ | 2 (`chatSpace-app`, `inbox-app`) |
| reward | `/reward/` | 9100 | ✅ | ✅ (toolkit) | — | ✅ (reward-product) | 5 (`reward-funding-price-app`, `reward-simplepay-app`, `reward-product-app`, `#reward-funding-complete-app`, `#funding-refund-policy-guide-app`) |
| school | `/school/` | 9104 | ✅ | ✅ (thunk) | — | ❌ | 1 (dynamic `ROOT_ELEMENT_ID`) |
| web | `/static/web/` | 9090 | ✅ (공통 라이브) | ❌ | ❌ | ❌ | dynamic (header/footer renderTarget + 5개 `data-component-name` 마크업 컴포넌트) |

- **React 없음**: `analytics` (순수 부트 스크립트), `assets` (파일 복사).
- **Redux store 보유**: `account`, `iam`, `landing`, `main`, `open-account`, `reward`, `school`.
- **Redux 아님 / zustand**: `personal-message`.
- **`@tanstack/react-query`**: `main`, `floating-buttons` (공용 alias: `static/node_modules/@tanstack/react-query`).
- **MSW 훅**: `main`, `account/my-purchase-detail`, `reward/reward-product`.

---

## 참고 · 교차 링크

- 상위 개요: `docs/wadiz-frontend/wadiz-frontend.md`
- 렌더러 셀렉터 색인: `wadiz-frontend/static/entries/RENDERER_ID_SELECTORS.md`
- 공통 렌더러 구현: `wadiz-frontend/static/packages/shared/reactRenderer.tsx`
- 공통 빌드 상속: `wadiz-frontend/static/config/webpackCommonConfig/webpackConfigInstance.js`, `wadiz-frontend/static/packages/shared/config/webpack.config.js`, `wadiz-frontend/static/libraries/shared/config/webpack.config.js`
- CDN 퍼지: `wadiz-frontend/static/scripts/tasks/cdnPurge.js`
- 레거시 JSP 본체: 본 repo 범위 외 — `docs/com.wadiz.web.md`
