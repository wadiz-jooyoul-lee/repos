# Admin SPA (`static/services/admin`) — Wadiz 운영 어드민 React 번들

> **기록 범위**
>
> - 소스 대상: `wadiz-frontend/static/services/admin/**`, `wadiz-frontend/static/packages/fetch-api/**`, `wadiz-frontend/packages/api/src/admin/**`.
> - 서버/백엔드 처리는 **이 repo 안에서 호출하는 URL 문자열**까지만 기록한다. 실제 매핑은 `com.wadiz.adm`(레거시 JSP 어드민) / `co.wadiz.*` 리라이트 서버에 있으므로 "외부"로 취급한다.
> - 참조한 JSP `front/main.jsp` mount point는 사이드 검증으로만 사용 (`/Users/casvallee/work/repos/com.wadiz.adm/web/WEB-INF/jsp/front/main.jsp:16-17`).
> - 페이지별 상세 기능 설명은 UI 텍스트·라우트·서비스 파일로 관측된 것만 기입한다. 백엔드 DB 쿼리·권한 enum은 서술하지 않는다.

---

## 1. 개요

`static/services/admin` 은 **와디즈 전사 운영 어드민(백오피스)의 React SPA 번들** 이다. 엔트리는 단 한 개(`admin-app` DOM id)이고, **각 레거시 JSP 라우트가 같은 번들을 include 하여 해당 경로의 `<Route>` 만 렌더링**하는 "여러 경로 → 같은 번들 → React Router 분기" 모델이다.

- 빌드 산출물은 `static/admin/main.js` + `static/admin/main.css`.
- 레거시 JSP 쉘에서 다음과 같이 로드한다 — `com.wadiz.adm/web/WEB-INF/jsp/front/main.jsp:11-18`
  ```jsp
  <link rel="stylesheet" href="${static_host}/static/admin/main.css">
  <div id="admin-app"></div>
  <script src="${static_host}/static/admin/main.js"></script>
  ```
- Spring MVC Controller 다수가 `ModelAndView("front/main")` 으로 **동일한 JSP 한 장을 반환**한다(`com.wadiz.adm/src/main/java/com/wadiz/web/**/*ViewController.java`). 즉 adm 서버는 라우팅·인증만 담당하고, 화면은 전부 이 SPA 가 그린다.
- mount/renderer: `static/services/admin/index.js:1-7`
  ```js
  import { reactRenderer } from 'shared/reactRenderer';
  import App from './App';
  import './ERPModalApp';
  import './pages/attachment-preview-viewer/PreviewApp';
  reactRenderer(App, 'admin-app');
  ```
  `ERPModalApp` 과 `PreviewApp` 은 `App` 과 별개로 전역 `window.wadiz.*` 메서드를 노출하여 **JSP 쪽에서 호출되는 공통 모달**을 제공한다. 이 부분은 레거시 JSP 화면과 React SPA 화면이 공존하는 "혼합 상태" 를 보여주는 핵심 단서.
- `App.jsx:1-27` — Redux `Provider` + `BrowserRouter` + `ErrorBoundary` 래핑. 전역 UI 테마로 `antd` CSS (`import 'antd/dist/antd.css'`) 를 먼저 로드하고 프로젝트 reset 을 위에 씌운다(`App.scss:1-40`).
- 배포 도메인 (관찰 가능): 레거시 스택은 `https://{env}adm.wadiz.kr` 계열(`helpers/wadizDomain.ts:11-19`), 클라우드 스택은 `https://adm.{env}.wadiz.co`(`package.json:8-20` scripts + `proxyInfo.js:10-14`).

### `com.wadiz.adm`(레거시 JSP) 과의 관계

- SPA 가 **점진적으로 JSP 를 대체** 중이다. 이 SPA 의 `Router.jsx` 에 등록된 19개 최상위 라우트는 모두 `ViewController`가 `front/main` JSP 로 포워딩하는 경로와 1:1 대응된다(아래 "5. 라우트 구조" 참조).
- 반대로 **회원관리/결제·환불/증권형 투자 전체/쿠폰 레거시/메일·푸시·통계 등은 아직 JSP 로 유지**되어 있다(`docs/com.wadiz.adm.md:20-27`). 이 SPA 에는 해당 페이지가 없다.
- 레거시 JSP 가 사용하는 `admin-lte 2 + Bootstrap 3.3.6` 스킨이 SPA 상위 프레임을 여전히 감싸고 있고 — ERP 사원/부서 검색 모달이 `window.wadiz.openEmployeeSearchModal()` 전역 함수로 노출되는 이유다(`ERPModalApp.jsx:77-79`). JSP 쪽 화면이 React 모달을 띄울 수 있도록 bridge 역할.

---

## 2. 기술 스택 · 빌드

파일: `static/services/admin/package.json`, `static/services/admin/webpack.config.js`.

### 2.1 React / 상태관리

- React 18.2 + React Router DOM v6.26 (`package.json:43,35`).
- **Redux 4.0 + redux-thunk + react-redux 7.1** (legacy store, `store/index.js:1-22`) **와** **@reduxjs/toolkit 1.6** (도메인별 slice, `pages/maker/store/store.js:1-9` 등) 이 공존.
- **@tanstack/react-query 5.66** 을 **도메인별로 각각 `QueryClientProvider`** 로 감싸는 방식 — 글로벌 단일 queryClient 가 아니라 `supporter-club`, `maker-announcement`, `notification-list`, `coupon-issuekey`, `benefit`, `community/feed`, `web-manage/home/quickMenu` 각각이 독립 인스턴스(`pages/supporter-club/App.jsx:3-19`, `pages/benefit/BenefitApp.jsx:3-19`, `pages/web-manage/home/quickMenu/App.tsx:2-14` 등). 레거시 페이지는 redux-thunk + `requestApi` 패턴.
- **MobX 3.5 / mobx-react 4.4** (`package.json:50-51`) 는 이름만 의존성에 남아있고 실제 `observer` 사용 지점 없음 — 과거 잔재로 추정.
- 최상위 reducer 는 현재 `inviteFriends` 하나만 combine 됨(`reducers/index.js:1-7`). 나머지 redux state 는 서브 앱 내부(`pages/maker/features/rootReducer.js`, `pages/reward-coupon/src/reducers/rootReducer.js`) 로 캡슐화.

### 2.2 UI

- **antd 4.16** (`package.json:34`) 가 메인 UI 라이브러리. `Button`, `Modal`, `Table`, `DatePicker`, `Select`, `Dropdown`, `Space`, `Typography` 등.
- **@wadiz/waffle** 디자인 시스템 스타일을 `index.scss:1` 에서 `@use '~@wadiz/waffle/styles' as *;` 로 전역 변수 주입. 홈 화면에서는 `Button`, `wadizSloganBlackKrLogoArtwork`, `OpenlinkIcon` 등 waffle 토큰을 직접 사용(`pages/home/App.tsx:1-42`).
- DnD: `react-beautiful-dnd 13.1`, `react-dnd 16.0` + HTML5 backend, `react-sortable-hoc 2.0` 세 라이브러리가 동시에 의존성에 존재(`package.json:37-40,57`) — 페이지별로 다르게 선택.
- Rich text: **Froala 3.2 (react-froala-wysiwyg)** (`components/FroalaEditor/**`).
- 날짜/시간: `dayjs 1.10` + `moment 2.24` + `react-dates 21.8` 병행(`package.json:44,51,54`). antd 4.x 가 moment 의존이라 moment 를 유지하는 형태.
- 파일 다운로드: `file-saver 2.0`, `streamsaver 2.0.6` (대용량 엑셀용).
- HWP 뷰어: `hwp.js 0.0.3` devDependency (`components/HWPViewer`).
- 아이콘: `@ant-design/icons 5.0`, `@wadiz/waffle-icons`.

### 2.3 빌드

파일: `webpack.config.js:1-50`.

- 공통 웹팩 설정은 `@wadiz/shared/config/webpack.config` 에서 받음(`webpack.config.js:5`). Wadiz 모노레포의 모든 `static/services/*` 앱이 동일 base 를 공유.
- **Node ≥ 17 대응**: `NODE_OPTIONS='--openssl-legacy-provider'` 가 모든 start/build 스크립트에 강제. webpack 4 시대 산출물(`@wadiz/shared/config/webpack.config`)이 최신 Node 의 OpenSSL 3 와 불일치하기 때문.
- `cross-env NODE_ENV=development|production|analyze` + `SERVICE_DOMAIN=admin` 을 env 로 전달해서 shared config 가 분기.
- Alias: `~`, `~components`, `~constants`, `~helpers`, `~pages`, `~types` + `react`/`react-router-dom` 을 루트 `node_modules` 로 강제 singleton(`webpack.config.js:14-24`). React 중복 로드 방지.
- SCSS: `sass-resources-loader` 로 `index.scss` 를 **모든 SCSS 파일 앞에 자동 prepend**(`webpack.config.js:29-40`). `@wadiz/waffle` 변수/믹스인을 각 파일이 import 하지 않아도 쓸 수 있게 만듦.
- `node.fs = 'empty'`: 번들러가 `fs` 참조를 만났을 때 빈 객체로 replace (웹팩 4 문법). `jsPDF` / `pdfkit` 계 라이브러리 대응.
- Dev server `publicPath` 는 `${공통 publicPath}static/admin` + `output.publicPath` 는 dev 에서 `/static/admin/` 고정(`webpack.config.js:42-49`).

### 2.4 SPA 엔트리 분할

`index.js` 가 세 개의 컴포넌트를 같은 번들에 합친다.

1. **`App` (React Router 앱)** — id `admin-app` DOM 에 마운트. Router.jsx 에 정의된 19개 최상위 라우트 담당.
2. **`ERPModalApp`** (`ERPModalApp.jsx`) — `window.wadiz.openEmployeeSearchModal()`, `window.wadiz.openDepartmentSearchModal()` 두 함수를 전역 노출. 호출 시 `document.createElement('div')` 로 새 루트를 만들어 `EmployeeSearchModal` / `DepartmentSearchModal` 을 렌더(`ERPModalApp.jsx:20-40,49-76`). Bootstrap 3 modal 의 `focusin.bs.modal` 이벤트를 off 하는 것이 눈에 띄는 호환 코드(`ERPModalApp.jsx:8-10`).
3. **`PreviewApp`** (`pages/attachment-preview-viewer/PreviewApp.jsx:6-35`) — `window.wadiz.openPreviewModal({ fileName, hwpUrl, imgUrl, pdfUrl, onClose })` 노출. hwp/pdf/이미지 첨부 미리보기.

이 두 전역 모달은 **레거시 JSP 화면(증권형 심사, 결제/환불 등)에서 React SPA 의 사원/부서 검색과 첨부 미리보기 UI 를 공유**하기 위한 brige.

---

## 3. 환경변수 · 프록시 설정

### 3.1 PROXY_TARGET

`package.json:8-20` 의 `start:*` scripts 가 `--env.PROXY_TARGET=<url>` 로 웹팩에 전달. `webpack.config.js:43` 에서 `devServer.proxy = require('./proxyInfo')(PROXY_TARGET, port)` 로 주입.

| 스크립트 | PROXY_TARGET | 도메인군 |
|---|---|---|
| `start:local` | `http://local.wadiz.kr:8090` | wadiz.kr (레거시) |
| `start:dev` | `https://devadm.wadiz.kr` | wadiz.kr |
| `start:rc` | `https://rcadm.wadiz.kr` | wadiz.kr |
| `start:rc2` | `https://rc2adm.wadiz.kr` | wadiz.kr |
| `start:cloud:local` | `http://local.wadiz.co:8090` | wadiz.co (클라우드) |
| `start:cloud:dev` | `https://adm.dev.wadiz.co` | wadiz.co |
| `start:cloud:rc4` | `https://adm.rc4.wadiz.co` | wadiz.co |

- 운영(`live`) PROXY_TARGET 은 존재하지 않는다 — 로컬 개발 → 원격 어드민 서버 프록시 전용.
- 환경변수로 두 도메인 계열이 갈린다:
  - `LOCAL_DOMAIN=wadiz.co`: `subdomainPrefix='adm'` 사용, 그 외에는 `'admin'` (`proxyInfo.js:11-13`).
  - `ADMIN_PORT_MODE=true`: 서브도메인 모드 대신 포트 모드로 전환(`proxyInfo.js:9,14-16`).

### 3.2 proxyInfo.js 동작

파일: `proxyInfo.js:1-95`.

- `http-proxy-middleware` v2 기반. context 는 `['/', '/web', '/resources', '/j_spring_security_check']` (`proxyInfo.js:81`). 즉 **루트부터 전부 proxyTarget 으로 보내되 `/static/admin` 같은 webpack-dev-server 에셋은 자동으로 먼저 가로챈다**.
- `changeOrigin: true`, `selfHandleResponse: true`, `autoRewrite: true`, `logLevel: 'debug'` (`proxyInfo.js:73-79`).
- `cookieDomainRewrite: { '*': 'local.wadiz.kr' 또는 '.local.wadiz.kr' }` — 포트/서브도메인 모드에 따라 다름. 원격 adm 서버가 `Set-Cookie: domain=.wadiz.kr` 을 내려도 브라우저가 로컬 도메인으로 저장하게 한다.
- `onProxyRes` (`proxyInfo.js:22-66`):
  - `Access-Control-Allow-Credentials: true` 강제.
  - 응답 `Set-Cookie` 에서 `Secure` 플래그를 제거 — 로컬 HTTPS 가 자가 서명이라 Secure 쿠키 거부 방지.
  - `Location` 헤더 / `application/json` 응답 body 안의 원격 도메인 문자열을 로컬 도메인으로 replace (`proxyInfo.js:32-35,56-58`).
  - `text/html` 응답: static origin URL(`https://static-{env}.wadiz.kr` or `https://static.{env}.wadiz.co`) 을 로컬로 치환해서 **JSP 가 내려주는 `<script src="${static_host}/static/admin/main.js">` 를 로컬 dev-server 에셋으로 리라이팅** (`proxyInfo.js:40-55`). 이것이 SPA 가 원격 JSP 레이아웃 안에서 실제로 로컬 모듈을 로드하는 핵심.
- `onProxyReq`: `origin` 헤더를 proxyTarget 로 재설정하고 `x-forwarded-*` 제거(`proxyInfo.js:86-90`) — 원격 adm 서버의 CSRF/Origin 검증 통과용.

### 3.3 로컬 도메인 모델

`README.md:15-46` 에 세부 정리. 요약:

- **서브도메인 모드(기본)**: `https://admin.local.wadiz.kr` / `https://adm.local.wadiz.co` 로 접속 → nginx(443)가 `127.0.0.1:9000`(webpack-dev-server)로 reverse proxy.
- **포트 모드(`ADMIN_PORT_MODE=true`)**: `https://local.wadiz.kr:9000` 으로 직접 접속, nginx 불필요.
- `/etc/hosts` 에 `127.0.0.1 local.wadiz.kr admin.local.wadiz.kr local.wadiz.co adm.local.wadiz.co` 등록 필요.
- 자가 서명 인증서: `packages/cert/local.wadiz.{crt,key}` (`wadiz.kr` / `wadiz.co` 둘 다 SAN).

---

## 4. 앱 레이어 · 공통 인프라

### 4.1 fetch 계층

어드민 SPA 는 요청을 다음 레이어로 뚫는다.

| 레이어 | 경로 prefix | 위치 |
|---|---|---|
| `fetchApi` (기본) | 없음 (풀 경로 그대로) | `static/packages/fetch-api/src/fetchApi.js:36` |
| `fetchWebApi` | `/` (동일 오리진 쿠키, GET 시 Content-Type 자동 삭제) | 같은 파일:139 |
| `fetchRewardApi` | `/web/reward/api` | 같은 파일:tail |
| `fetchFundingApi` | `/web/apip/funding` | 같은 파일:tail |
| `fetchStoreApi` | `/web/apip/store` | 같은 파일:tail |
| `fetchMakerCenterApi` | `https://api.makercenter.wadiz.kr` | 같은 파일:tail |
| `@wadiz/api` (신규 TS) | 전용 `GET/POST/PUT/DELETE` (`packages/api/src/fetch.ts`) | `packages/api/src/admin/account.services.ts` |

- 실패 시 `JsonParseError`, `FetchError` 를 throw (`fetchApi.js:20,89-100`).
- 204 는 `json=null` 로 정규화, `DELETE` 는 빈 문자열 허용(`fetchApi.js:68-80`).
- `loginController` 는 **`@wadiz/utils/loginController`** 를 임포트만 해 놓고 이 SPA 내부에서 직접 호출하는 지점은 관측되지 않음. adm 레거시 JSP 쪽 세션을 그대로 사용(쿠키 기반)하는 것으로 보인다.

### 4.2 fetch-api/admin 패키지

파일: `static/packages/fetch-api/src/admin/*` (5개 도메인만). 어드민 전용 URL 문자열을 모아 둔 씬 래퍼.

| 파일 | 엔드포인트 |
|---|---|
| `inviteFriends.js:3-26` | `GET /web/event/api/invite/list`, `GET /web/event/api/invite/rewardTemplate/{rewardType}`, `GET /web/event/api/invite/detail`, `POST /web/event/api/invite/register` (multipart/form-data) |
| `noticePopup.js:3-13` | `GET /web/popup/list`, `POST /web/popup/update` |
| `maker.js:11-66` | `GET /web/maker/list`, `GET /web/maker/{corpNo}/group`, `GET /web/startup/corporation/{corpNo}/teamMember/adminType`, `GET /web/startup/corporation/{corpNo}/teamMember/superAdmin` |
| `projects.js:11-35` | `GET /web/maker/{corpNo}/fundings?campaignStatusType&start&limit`, `GET /web/maker/{corpNo}/stores?start&limit` |
| `history.js:9-132` | `GET /web/maker/issue/{corpNo}/issues`, `GET /web/maker/issue/issueLogs/{issueNo}`, `GET /web/maker/issue/issueNo/{issueNo}`, `POST /web/maker/issue/add`, `POST /web/maker/issue/update`, `POST /web/maker/issue/delete` |
| `teamMember.js:7-57` | `GET /web/maker/{corpNo}/teammember/list`, `GET /web/maker/{corpNo}/admin/request/history`, `POST /web/maker/{corpNo}/admin/request/revert`, `GET /web/startup/corporationMember/view/businessRegPhotoModal/reqNo/{reqNo}` (HTML 응답 직접 파싱) |

`@wadiz/fetch-api/admin` 을 import 하는 유일한 페이지는 `maker/*` 와 `invite-friends/*`, `notice-popup/*` 뿐이다. 나머지는 각 페이지가 직접 `fetchApi`/`fetchWebApi` 를 쓰거나 `raw fetch()` 로 엔드포인트 문자열을 작성.

### 4.3 `packages/api/src/admin` (TypeScript 신규)

위치: `wadiz-frontend/packages/api/src/admin/`. pnpm 모노레포 패키지(`@wadiz/api`) 의 admin 서브모듈.

- `account.services.ts:47-80` — `accountService`
  - `GET /web/v2/account/coupon/templates` + `generateQueryKey` → react-query 키 자동 생성
  - `POST /web/v2/account/coupon/template`
  - `POST /web/v2/account/coupon/template/validation` 등
- `index.ts` 는 `export * as accountService from './account.services'` 하나만.
- `@wadiz/api/admin` 을 import 하는 화면은 현재 **coupon-issuekey** 둘(`RegisteredCouponList.jsx:6`, `IssuekeyRegisterButton.jsx:9`) 뿐. 신규 어드민 API 의 `@wadiz/api` 이관 출발점.

### 4.4 공통 구성요소

- `components/` — `BlockContainer`, `DatePicker`, `DateTimePickerCustomComponent`, `DepartmentSearchModal`, `EmployeeSearchModal`, `EnterIgnoreInput`, `ExpandToggle`, `FroalaEditor`, `HWPViewer`, `Page`, `PlusButton`, `ScrollTop`, `TagInput`, `TemporarySaveGuide`, `TagInput`, `ColorInput`.
- `helpers/`:
  - `wadizDomain.ts:1-23` — `getWadizBaseURL()` / `getAdminBaseURL()` 이 `process.env.ENVIRONMENT` (`local|live|dev|rc|...`) 로 분기해 링크 타겟 URL 생성. `live` 만 `www.wadiz.kr` / `adm.wadiz.kr` 고정.
  - `notification.js:1-24` — antd `notification` 래핑 (우하단 배치).
  - `checkEmail.ts`, `checkEmoji.ts`, `comma.ts`, `fileDownloader.ts`, `arrayMove.ts`, `utils.ts`, `hooks/`.
- `constants/api.js:1` — 딱 한 줄: `export const SUCCESS_CODE = 'SUSS000';` (백엔드 공통 응답 코드).
- `constants/httpStatus.ts:1-30` — HTTP 상태코드 상수 enum.
- `services/erp.ts:6-33` — `fetchDepartments()`, `fetchEmployees()` 두 함수만. `/web/apip/funding/v1/admin/departments` / `.../employees` 호출. ERP 모달에서 사용.
- `services/users.ts:7-9` — `fetchFindUserId(email)` → `/web/reward/api/users/by-email?email=...`.
- `types/erp.ts` — `Department`, `Employee` 타입 정의.

---

## 5. 라우트 구조

파일: `Router.jsx:1-77`.

최상위 `<Routes>` 는 19개 최상위 `<Route>` + `React.lazy` 동적 import. 라우트 주석에 담긴 **어드민 메뉴명** 이 곧 이 SPA 가 대체하고 있는 JSP 메뉴 트리다.

### 5.1 최상위 라우트 → 페이지 모듈 매핑

| 라우트 | 메뉴 분류 | React 모듈 | 주 저장소 |
|---|---|---|---|
| `/web/home/*` | 홈 | `pages/home/App.tsx` | — (정적 랜딩) |
| `/web/event/invitation/*` | 사이트 관리 → 친구 초대 이벤트 | `pages/invite-friends/App.jsx` | Redux (global store) |
| `/web/popup/*` | 사이트 관리 → 팝업 관리 | `pages/notice-popup/App.jsx` | (local state) |
| `/web/supporter-club/*` | 회원 관리 → 서포터클럽 회원 | `pages/supporter-club/App.jsx` | react-query |
| `/web/supporter-club-voucher/*` | 회원 관리 → 서포터클럽 할인권 | `pages/supporter-club-voucher/App.jsx` | react-query |
| `/web/app/supporter-club-settlement/*` | 서포터클럽 정산 관리 | `pages/supporter-club-settlement/App.tsx` | react-query |
| `/web/maker/*` | 메이커 관리 | `pages/maker/App.jsx` | Redux Toolkit (`maker/store`) |
| `/web/app/store/*` | 스토어 프로젝트 관리 | `pages/store-admin-app/App.jsx` | react-query + local state |
| `/web/maker-announcement/*` | 리워드 프로젝트 관리 → 메이커 스튜디오 공지 | `pages/maker-announcement/App.tsx` | react-query |
| `/web/app/reward-coupon/*` | 포인트/쿠폰 → 할인 쿠폰 관리 | `pages/reward-coupon/src/App.jsx` | (내부 reducers) |
| `/web/app/coupon-accounting` | 포인트/쿠폰 → 할인 쿠폰 회계 | `pages/reward-coupon-accounting/App.tsx` | react-query |
| `/web/app/coupon-issuekey` | 포인트/쿠폰 → 회원 쿠폰 발행키 | `pages/coupon-issuekey/App.jsx` | react-query |
| `/web/ip/*` | IP 라이센스 사업 관리 | `pages/ip-license/App.tsx` | react-query |
| `/web/community/communityFeedContentList` | 커뮤니티 관리 → 피드 콘텐츠 | `pages/community/feed/App.tsx` | react-query |
| `/web/event/big-unique-brand-v2/*` | 이벤트 관리 | `pages/event/App.tsx` | react-query |
| `/web/manage/home/quickMenu` | 홈 관리 → 퀵메뉴 관리 | `pages/web-manage/home/quickMenu/App.tsx` | react-query |
| `/web/notification/send-result` | 알림 발송 관리 → 발송 결과 조회 | `pages/notification-list/App.jsx` | react-query |
| `/web/app/benefit-coupon` | 이벤트 보상형 쿠폰 생성/관리 | `pages/benefit/BenefitApp.jsx` | react-query |

`/web/ip/*` 는 코드에서 **주석 처리**(`Router.jsx:57`)되어 있고 `ip-license/*` 모듈 자체는 남아 있음 — "미사용" 으로 표기.

### 5.2 서브 라우트 대표 예시

각 서브 앱은 자체 `<Routes>` 를 갖고 있다.

- **invite-friends** (`pages/invite-friends/Router.jsx:3-14`)
  - `/manager` — 이벤트 목록
  - `/detail/:id?` — 이벤트 등록/수정 폼 (FormData, multipart/form-data 업로드)
- **notice-popup** (`pages/notice-popup/Router.jsx:3-13`)
  - `/web/popup/main` — 팝업 조회/수정 (단일 레코드, `popupSeq: 1` 고정)
- **maker** (`pages/maker/Router.jsx:8-16`)
  - `/` → `MakerMainPage`
  - `/detail/:corpNo` → `MakerDetailPage`
  - `/detail/:corpNo/history` → `MakerDetailPage tabIndex="3"`
- **store-admin-app** (`pages/store-admin-app/Router.jsx:19-85`) — 14개
  - `/projects`, `/projects/:PROJECT_NUMBER`
  - `/collection`, `/curation`, `/sellableStockSyncs`, `/satisfactions`
  - `/sales`, `/sales/:ORDER_NUMBER`
  - `/settlement_billing`, `/settlement_accounting`, `/settlement_maker`
  - `/promotion`, `/promotion/detail/:promotionNo`
  - `/product-price`
- **reward-coupon** (`pages/reward-coupon/src/routes/RewardCoupon/RewardCoupon.jsx:7-15`)
  - index → `RewardCouponList`
  - `/:id` → `RewardCouponDetail`
- **event** (`pages/event/Router.tsx:7-13`)
  - index → `BigUniqueBrand`
  - `/:collectionID` → `BigUniqueBrandDetail`
- **reward-coupon-accounting** (`pages/reward-coupon-accounting/Router.tsx`)
  - index → 할인 쿠폰 회계 페이지
- **supporter-club-settlement** (`pages/supporter-club-settlement/App.tsx:10`)
  - `/sales` → `SalesContainer`

---

## 6. 도메인별 화면 · API 매핑

각 섹션은 **"이 SPA 에서 호출하는 URL"** 만 나열한다. 실제 처리 서버는 관측 밖.

### 6.1 홈 (`/web/home/*`)

- 파일: `pages/home/App.tsx:7-47` — 텍스트+로고+"대시보드 바로가기" 한 줄 짜리 정적 랜딩.
- 외부 호출: 없음. 버튼 클릭 시 `/web/dashboard`(JSP 쪽) 로 이동.

### 6.2 친구 초대 이벤트 (`/web/event/invitation/*`)

- 파일: `pages/invite-friends/App.jsx`, `.../Router.jsx`, `actions/inviteFriendsList.js`, `actions/inviteFriendsDetail.js`.
- 상태: Redux thunk + 각 API 당 `makeAsyncActionCreator` + `requestApi` (구 패턴).
- API (`actions/inviteFriendsList.js:5`, `actions/inviteFriendsDetail.js:5-10`):
  - `GET /web/event/api/invite/list` — 이벤트 목록
  - `GET /web/event/api/invite/rewardTemplate/{rewardType}` — 보상 템플릿
  - `GET /web/event/api/invite/detail` — 상세 (이벤트 id 는 세션 기반인 듯, URL 파라미터 없음)
  - `POST /web/event/api/invite/register` — 이벤트 등록/수정 (multipart/form-data, `components/InviteFriendsEventForm/InviteFriendsEventForm.jsx` 가 FormData 로 빌드)
- 이미지: `/web/imgView/photoFile?photoId=...` 경로 직접 참조(`InviteFriendsEventForm.jsx:330,363`).

### 6.3 팝업 관리 (`/web/popup/main`)

- 파일: `pages/notice-popup/containers/NoticePopupFormContainer.jsx:1-40`.
- API (`fetch-api/src/admin/noticePopup.js:3-13`):
  - `GET /web/popup/list` → `data[0]` (사이트 공지 팝업은 단일 row)
  - `POST /web/popup/update` (`popupSeq: 1` 하드코딩)

### 6.4 서포터클럽 회원 (`/web/supporter-club/*`)

- 파일: `pages/supporter-club/containers/SupporterClubContainer.jsx`, `pages/supporter-club/services/service.js:3-80`.
- BASE: `/web/v2/membership/admin`.
- API:
  - `POST /web/v2/membership/admin/list` — 멤버십 회원 목록 (검색 필터를 POST body, 페이지네이션은 query `page`,`size`)
  - `GET /web/v2/membership/admin/user/{userId}/product/{productId}/detail` — 회원 상세
  - `GET .../detail/benefit` — 혜택 이용 내역
  - `GET .../detail/membership` — 멤버십 이력
  - `GET .../detail/transaction` — 결제 이력
  - `PUT .../unsubscribe_forcibly` — 강제 해지
  - `GET /web/v2/membership/admin/voucher/user/{userId}` — 보유 할인권

### 6.5 서포터클럽 할인권 (`/web/supporter-club-voucher/*`)

- 파일: `pages/supporter-club-voucher/services/service.js:3-23`, `components/VoucherTable.jsx`, `Registration.jsx`.
- API:
  - `GET /web/v2/membership/admin/voucher?voucherName&start&end&page&size` — 할인권 목록
  - 그 외 `Registration.jsx`/`VoucherTable.jsx` 내 `/web/v2/membership/admin/...` 호출 2건 (각 raw fetch, 파일별 로컬)

### 6.6 서포터클럽 정산 (`/web/app/supporter-club-settlement/sales`)

- 파일: `pages/supporter-club-settlement/services/service.ts:1-37`, `containers/SalesContainer.tsx`.
- BASE: `/web/v2/membership/adjustment`.
- API:
  - `GET /web/v2/membership/adjustment/excel/closing/month/{yearMonth}` — 월별 마감 엑셀 URL 조회
  - `POST /web/v2/membership/adjustment/list?page&size` — 정산 목록 (검색 필터 body)
  - `POST /web/v2/membership/adjustment/sum/count/{totalCount}` — 합계 조회

### 6.7 메이커 관리 (`/web/maker/*`)

- 파일:
  - `pages/maker/pages/MakerMainPage/`, `.../MakerDetailPage/`
  - `pages/maker/features/makerSlice.js:9-33`, `makersSlice.js:14-58`, `fundingSlice.js:16-34`, `storeSlice.js:15-30`, `historySlice.js`, `teamMemberSlice.js`
- 패턴: Redux Toolkit `createAsyncThunk` + `@wadiz/fetch-api/admin` 에서 URL 함수 import. `SUCCESS_CODE === 'SUSS000'` 여부로 성공/실패 분기(`makerSlice.js:20-30`).
- API (함수명 → URL은 §4.2 maker/projects/history/teamMember 표 참조):
  - 목록 — `GET /web/maker/list?searchType&searchValue&adminRequestRoute&adminApprovalStatus&start&limit&startPercent&endPercent`
  - 상세 — `GET /web/maker/{corpNo}/group`
  - 펀딩 프로젝트 — `GET /web/maker/{corpNo}/fundings`
  - 스토어 프로젝트 — `GET /web/maker/{corpNo}/stores`
  - 팀 멤버 — `GET /web/maker/{corpNo}/teammember/list`
  - 관리자 승인 이력 — `GET /web/maker/{corpNo}/admin/request/history`
  - 관리자 승인 반려 — `POST /web/maker/{corpNo}/admin/request/revert`
  - 메이커 권한 조회 — `GET /web/startup/corporation/{corpNo}/teamMember/adminType`
  - 슈퍼관리자 정보 — `GET /web/startup/corporation/{corpNo}/teamMember/superAdmin`
  - 사업자등록증 이미지 — `GET /web/startup/corporationMember/view/businessRegPhotoModal/reqNo/{reqNo}` (HTML 응답)
  - 이력 — `GET /web/maker/issue/{corpNo}/issues`, `GET .../issueLogs/{issueNo}`, `GET .../issueNo/{issueNo}`, `POST .../add`, `POST .../update`, `POST .../delete`

### 6.8 스토어 운영 (`/web/app/store/*`)

이 SPA 에서 **가장 거대한 서브 앱**. 14개 라우트, 자체 `api/` 디렉터리 5개(`project`, `product`, `promotion`, `curation`, `sellableStock`, `file`) + 공통 `api/index.js:4-22` 의 `request()` 래퍼.

- 공통 래퍼 (`api/index.js:4-22`):
  - 기본 URL: `/web/apip/{store|funding}/admin/{path}`
  - 응답 code/status 검사 후 data 반환; `401` 이면 `window.location.href = '/web/account/login'` 으로 redirect (**SPA 레벨 인증 실패 처리**).
- `antdConfig.js:1-3` — `message.config({ top: 60, duration: 3 })` 전역 설정.

**스토어 프로젝트 관리** (`/projects`, `/projects/:PROJECT_NUMBER`)
- `GET /web/apip/store/admin/projects?...` — 검색/페이지. `enteredTypes`, `thirdPartyInvolvedTypes` 는 복수 param 으로 직렬화(`api/index.js:26-46`).
- `GET .../projects/excel?...` — 엑셀 다운로드는 `window.open` (`api/index.js:48-69`).
- `GET .../projects/{projectNo}` — 기본 정보
- `GET .../project-managements/{projectNo}` — 관리 정보
- `GET .../project-managements/{projectNo}/screening-condition` — 심사 조건
- `GET .../projects/{projectNo}/labels/{labelKeyword}/histories` — 태그 히스토리
- `GET .../projects/{projectNo}/partner-service/histories`
- `GET .../projects/{projectNo}/base-funding`
- `GET .../projects/{projectNo}/maker-business-info` + `/sync-histories` + `/sync-candidate`
- `DELETE .../projects/{projectNo}/documents/{documentNo}` / `POST .../documents` (body: `{file}`)
- `GET .../project-managements/{projectNo}/histories`
- `GET .../projects/{projectNo}/maker-required-documents`, `.../documents`
- 담당자/진행: `GET /web/apip/funding/admin/managers?name=` (type: funding), `POST .../project-managements/{projectNo}/manager`, `POST .../progress-type/{progressType}`, `PUT .../events/{eventType}` (skipHandleError)
- 태그/파트너: `POST .../projects/{projectNo}/labels/{labelKeyword}`, `DELETE` 동일 / `POST .../partner-service`, `DELETE` 동일
- 메모/피드백: `PUT .../project-managements/{projectNo}/notes/{noteType}` body `{comment}`, `POST .../feedbacks` body `{fromEmail, feedbacks}`, `GET .../feedbacks/{feedbackNo}`
- 수수료 관리 — 9개:
  - `GET feerate/list` (fee rate master)
  - `GET feerate/projects/{projectNo}/list?date=`
  - `POST feerate/projects/{projectNo}/validate` / `.../register` / `PUT .../update` / `DELETE .../feerates/{seq}` / `POST .../validate-for-update/{type}` (type: `DELETE`|`UPDATE`) / `GET .../feerate-today`
- 세금/3자정산: `POST .../project-managements/{projectNo}/tax-type/{taxType}`, `PUT .../project-managements/{projectNo}/3party-involved-types` body `{thirdPartyInvolvedTypes}`
- 상품가격 이력: `GET .../projects/{projectNo}/products/price-histories`
- 와딜리버리 (`api/project/project.ts:14-36`):
  - `PUT .../projects/{projectNo}/entered-type` body `{enteredType}`
  - `GET .../projects/{projectNo}/wa-delivery`
  - `PUT .../projects/{projectNo}/wa-delivery/actions/{actionType}` body `{storageType}`
  - `GET .../orders/qty?projectNo=&orderStatusFilter=ORDER_PROCESSING` — 발송 대기 수량
  - `GET .../projects/{projectNo}/wa-delivery/histories`
- 수수료 관리 v2 (신규, ERP fee, `api/project/project.ts:71-202`):
  - `GET .../fee-management/projects/{projectNo}` — 프로젝트 수수료
  - `GET .../fee-management/confirm-fee?projectNo=&applyDatePeriod.from=&applyDatePeriod.to=&page=&size=`
  - `GET .../fee-management/proposal-progress?projectNo=...` — 수수료 제안 진행 상황
- 수기 프로젝트 생성 (관리자 강제 생성):
  - `POST .../projects/set-up-without-funding` body `{project, maker}` (`api/project/project.ts:108-125`)
  - `POST .../projects/set-up-via-copy` body `{projectNo, qty, isJoined, isCopyProductRequired, maker}` (`api/project/project.ts:141-148`)
- 카테고리 메타(원격 service 서버 호출): `GET https://{env}-service.wadiz.kr/api/search/categories` — `api/project/project.ts:38-67`

**주문/발송** (`/sales`, `/sales/:ORDER_NUMBER`)
- `GET /web/apip/store/admin/orders?...` — 주문 목록 (20개 이상 필터)
- `GET .../orders/{orderNo}` — 주문 상세
- `PUT .../orders/{orderNo}/cancel-shipping` — 미발송 처리
- `POST .../orders/{orderNo}/shipping` body `{...}` — 발송 처리
- `PUT .../orders/shippings/prepare` body `{orderNos}` — 일괄 발송 준비
- `GET .../settlement/sale/status?orderNumber=` — 정산 제외 상태
- `GET .../orders/{orderNumber}/status-history` — 상태 이력
- `POST /web/apip/store/admin/withdraws` body `{orderNo, reasonType, refunderType, detailedReason, refundType}` — 환불 (직접 `fetch`, response.ok 로 체크, INVALID_REFUND_AMOUNT 코드 특수 메시지, `api/index.js:380-417`)
- 엑셀: `window.open(/web/apip/store/admin/orders/excel?...)`, `.../orders/for-shipping/excel?...`
- 택배사: `GET /web/apip/tracker-bridge/companylist`

**스토어 정산** (`/settlement_billing`, `/settlement_accounting`, `/settlement_maker`)
- `GET /web/apip/store/admin/settlement/sale?settlementRound&detailSearch&searchText&oid&size&page&sortBy&isExcluded&isReIncluded` — 판매 정산 조회
- `POST .../settlement/sale/orders/{orderNumber}/excludedSettlement` — 정산 제외
- `POST .../settlement/seller/handAdjustment` body `{sellerSettlementSeq, price, memo}` — 수기 조정
- `GET .../settlement/seller?settlementRound&detailSearch&searchText&hasReceivable&size&page` — 메이커 정산
- `POST .../settlement/seller/settlementRounds/{round}/close` / `.../accountingClose` / `GET .../close/confirm` / `.../accountingClose/confirm`
- `POST .../settlement/seller/memo` body `{sellerSettlementSeq, memo}`
- `GET .../settlement/seller/handAdjustment/history?seq=`
- `GET .../settlement/seller/handAdjustment/accumulatedHistory?bizNumber=`
- `GET .../settlement/pay-agents/nicepay/subMallId-register/checkIfCan?settlementRound=`
- 엑셀 다운로드(`window.open`): `.../settlement/sale/excels/download`, `.../settlement/seller/excel-download/settlement`, `.../settlement/seller/excel-download/monthly-trans-statement`, `.../settlement/seller/excel-download/taxBill`, `.../settlement/seller/slip/excel`, `.../settlement/seller/excel-download/paymentRequest`, `.../settlement/pay-agents/nicepay/subMallId-register-csv`, `.../settlement/pay-agents/nicepay/pay-request-csv`, `.../payments/excel?periodType=PAYMENT_DATE&...` (회계용)
- 거래명세서: `.../settlement/seller/{seq}/statement-file?statementAttachId=` (window.open)

**컬렉션/큐레이션** (`/collection`, `/curation`)
- 파일: `api/curation/curation.ts:1-96`.
- 자체 로컬 `request()` 래퍼(같은 401 리다이렉트 동작).
- `GET /web/apip/store/admin/curations?isUsable&sortBy&size&page` — 목록
- `PUT .../curations/{curationNo}/usable` / `.../unusable` — 사용 여부 토글
- `PUT .../curations/ordinal` body `{changeOrdinals:[{curationNo,ordinal}]}` — 순서 변경 (DnD)
- `POST .../curations` — 등록
- `PUT .../curations/{curationNo}` — 수정
- `GET .../collections?searchTargetType=KEYWORD&searchText=` — 컬렉션 검색
- 스토어 컬렉션 상세: `GET .../collections/{collectionNumber}` (`pages/reward-coupon/.../services/couponList.ts:37`)

**할인 프로모션** (`/promotion`, `/promotion/detail/:promotionNo`)
- 파일: `api/promotion/promotion.ts:1-62`.
- `GET /web/apip/store/admin/discount-promotions/eligible-user-types`
- `GET .../discount-promotions?...`
- `GET .../discount-promotions/{promotionNo}`
- `POST .../discount-promotions` — 등록
- `PUT .../discount-promotions/{promotionNo}` — 수정
- `PUT .../discount-promotions/{promotionNo}/items` body `{items}` — 프로모션 상품 일괄 세팅
- `GET .../products/for-add-to-promotion?...` — 추가 가능 상품 목록
- `PUT .../discount-promotions/{promotionNo}/priority/top` — 우선순위 최상단

**만족도 관리** (`/satisfactions`)
- 파일: `pages/StoreSatisfactions/*.tsx`.
- `GET /web/apip/store/admin/satisfactions/{satisfactionId}` — 상세
- `PUT .../satisfactions/{id}/hidden` — 숨김 토글
- `POST .../satisfactions/{id}/replies` — 답글 등록
- `GET .../satisfactions/replies/{replyId}`, `PUT 동일`, `DELETE 동일` — 답글 수정/삭제

**와딜리버리 판매 가능 수량 동기화** (`/sellableStockSyncs`)
- 파일: `api/sellableStock/syncs.ts:1-15`.
- `GET /web/apip/store/admin/products/sellable-stock-syncs/histories?page=0&size=20`
- `POST .../products/sellable-stock-syncs` body `{waDeliveryStorageType}`

**상품 금액 관리** (`/product-price`)
- 파일: `api/product/price/price.ts:1-120`, `pages/StoreProductPrice/*`.
- 엔드포인트 문자열은 샘플 데이터 위주이고 실제 요청 hook 은 별도 탐색 필요 (이 repo 내 관측 가능 URL: `GET /web/apip/store/admin/projects/{projectNo}/products/price-histories` `api/index.js:308-315`).

**첨부** (파일 업로드/다운로드)
- `POST /web/apip/store/attachments` (FormData, `api/index.js:486-499`) — 파일 업로드
- 다운로드: `/web/apip/store/attachments/{attachmentKey}` 또는 레거시 `/web/store/attachments/{attachmentKey}/legacy-system/download` 분기(`pages/StoreProjectDetail/FileManage.jsx:20-23`).

### 6.9 메이커 스튜디오 공지 (`/web/maker-announcement/*`)

- 파일: `pages/maker-announcement/services/announcement.ts:1-86`, `byMenu.ts:1-38`.
- BASE: `/web/apip/funding/admin/announcements`.
- 공지:
  - `GET /web/apip/funding/admin/announcements?page&size&importantFilterType&displayFilterType&displayByMenuFilterType`
  - `GET .../announcements/{announcementId}` (+ `.../history/{announcementId}`)
  - `POST .../announcements` — 등록
  - `PUT .../announcements/{announcementId}/contents` body `{title, body, header}` — 내용 수정
  - `PUT .../announcements/{announcementId}` body `{isDisplay, isImportant}` — 노출 플래그 수정
- 메뉴별 노출 (`byMenu.ts`):
  - `GET .../announcements/by-menu`
  - `GET .../announcements/by-menu/menus`
  - `GET .../announcements/by-menu/history?menuType&size&page`
  - `PUT .../announcements/by-menu/{menuType}` body — 메뉴별 공지 노출 여부

### 6.10 할인 쿠폰 관리 (`/web/app/reward-coupon/*`)

- 파일:
  - `pages/reward-coupon/src/App.jsx:9`
  - `routes/RewardCoupon/services/*.js` (구 JS)
  - `routes/RewardCoupon/routes/RewardCouponList/services/couponList.ts:1-50` (신규 TS)
  - `routes/RewardCoupon/routes/RewardCouponDetail/services/couponDetail.ts`
- BASE: `/web/reward/api/coupons`.
- `GET /web/reward/api/coupons/templates?...` — 쿠폰 템플릿 목록
- `POST /web/reward/api/coupons/templates` — 생성
- `PUT /web/reward/api/coupons/templates/{templateNo}` — 수정
- `GET /web/reward/api/coupons/templates/{templateNo}` — 상세
- `GET /web/reward/api/coupons/templates/{templateNo}/summations` — 요약 통계
- `GET /web/reward/api/payments/coupons/summation?templateNo=` — 결제 쿠폰 집계
- `GET /web/reward/api/coupons/templates/management-departments` — 관리 부서 목록
- `GET /web/reward/api/partners` — 파트너 목록
- `GET /web/reward/api/collections?type=CAMPAIGN` — 컬렉션 목록
- `GET /web/reward/api/collections/{collectionNumber}`
- `GET /web/apip/store/admin/collections/{collectionNumber}` — 스토어 컬렉션 상세 (쿠폰을 스토어 컬렉션에 거는 경우)

### 6.11 할인 쿠폰 회계 (`/web/app/coupon-accounting`)

- 파일: `pages/reward-coupon-accounting/services/couponAccounting.ts:1-29`.
- `GET /web/reward/api/coupons/templates/management-departments` — 관리 부서
- `GET /web/reward/api/coupons/transaction-summation?...` — 거래 합계
- 엑셀: `window.open('/web/reward/api/coupons/transaction-summation/excel?managementDepartmentCode&transactionStartDate&transactionEndDate')`

### 6.12 회원 쿠폰 발행키 (`/web/app/coupon-issuekey`)

- 파일:
  - `pages/coupon-issuekey/App.jsx:1-22`
  - `components/CouponIssuekeyManagementContainer.jsx` (컨테이너)
  - `components/RegisteredCouponList.jsx:6` 와 `IssuekeyRegisterButton.jsx:9` — **신규 `@wadiz/api/admin` 패키지** 의 `accountService` 직접 import.
- API (`packages/api/src/admin/account.services.ts`):
  - `GET /web/v2/account/coupon/templates` (`accountService.getCouponTemplatesQuery` — react-query key 자동 생성)
  - `POST /web/v2/account/coupon/template` — 등록 (`accountService.getPostCouponTemplateMutation`)
  - `POST /web/v2/account/coupon/template/validation` (validation)
- 쿠폰 종류 드롭다운: `SIGN_UP` (앱 첫 결제 쿠폰) 한 가지만 등록 UI 노출(`IssuekeyRegisterButton.jsx:44-48`).
- 등록 후 `/web/app/reward-coupon/{templateNo}` 로 이동(`RegisteredCouponList.jsx:31`).

### 6.13 IP 라이센스 (`/web/ip/*`, 주석 처리됨)

- 파일: `pages/ip-license/services/ipLicense.ts:6-60`.
- BASE: `/web/apip/funding/admin/iplicenses`.
- `GET /web/apip/funding/admin/iplicenses?...` (필터)
- `GET .../iplicenses/{licenseId}` / `DELETE .../iplicenses/{licenseSeq}`
- `POST .../iplicenses` — 등록/수정
- `GET .../iplicenses/top-ranks?programName=` / `POST .../top-ranks` body `{ranks, programName}`
- `GET .../iplicenses/campaigns/{campaignId}/related-mappings?campaignType=` — 참여 프로젝트 매핑
- `POST /web/apip/funding/attachments/presign` — IP 이미지 프리사인 URL
- Router.jsx 에서 주석 처리됨 → **현재 접근 불가하지만 코드는 유지**.

### 6.14 커뮤니티 피드 (`/web/community/communityFeedContentList`)

- 파일: `pages/community/feed/App.tsx` + `containers/FeedContentsContainer.jsx` + `helpers/hooks/queries/use{Contents,CreateContents,UpdateContents,DeleteContents}.js`.
- BASE: `/web/feeds/contents` (**본 프로젝트에서 유일하게 `/web/feeds/*` prefix 를 사용**하는 모듈).
- `GET /web/feeds/contents{queryStr}` — 목록
- `POST /web/feeds/contents/` — 등록
- `PUT /web/feeds/contents/{contentId}` — 수정
- `DELETE /web/feeds/contents/{contentId}` — 삭제
- 이미지 업로드 (`components/ImageUploader.jsx:86,154`):
  - `GET /web/feeds/contents/file/presigned`
  - `POST /web/feeds/contents/file/delete`
- 주의: `services/service.js:1-99` 는 **구조적으로 복붙된 supporter-club 서비스 코드**이고 실제로는 사용되지 않는다(파일 내용과 hook 이 다름). 데드 코드.
- `App.tsx` 상단에 MSW 로 ADMIN_COMMUNITY mock 을 띄우는 블록이 전부 주석 처리되어 있음 — 개발 편의 용.

### 6.15 이벤트 관리 — Big Unique Brand v2 (`/web/event/big-unique-brand-v2/*`)

- 파일: `pages/event/Router.tsx:7-13`, `services/customCollection.ts:1-45`.
- 원격 API(Bearer token 고정, `CUSTOM_COLLECTION_TOKEN` 하드코딩 `customCollection.ts:3`):
  - Host: `https://public-api{env-suffix}.wadiz.kr/main/v1/custom-collection` (`-` 분기: local→`-dev`, live→``, rc2→`-rc`)
  - `GET {host}/{collectionId}` — 기획전 조회
  - `POST {host}` — 기획전 등록 (`Authorization: Bearer ...`, body `{collectionId, data}`)
- SPA 내부에서 **유일하게 외부 public-api 서버를 credentials:include 로 직접 호출** 하는 지점.

### 6.16 퀵메뉴 관리 (`/web/manage/home/quickMenu`)

- 파일: `pages/web-manage/home/quickMenu/App.tsx` + `QuickMenuContainer.tsx` / `QuickMenuContainerV4.tsx` + `helpers/hooks/*`.
- `App.tsx:16-35` — URL query `?v3=true` 로 V3/V4 토글. V4 가 기본.
- BASE: `/web/manage/home`.
- `POST /web/manage/home/api/v3/quickmenu/admin` — 퀵메뉴 저장 (`useFetchSaveQuickMenuList.ts:57`)
- `GET /web/manage/home/api/v2/main/quickmenu/types` — 퀵메뉴 타입 enum (`useQuickMenuTypes.ts:8`)
- `useUrlToLottie.ts` — `fetch(url)` 로 임의 lottie JSON 을 프리뷰용 로드.
- 로컬 시드 데이터: `helpers/hooks/localQuickMenu.js` — 개발 기본 데이터. 모든 `linkUrl` 이 `/web/*` (wadiz.kr 본체 페이지).

### 6.17 알림 발송 결과 (`/web/notification/send-result`)

- 파일: `pages/notification-list/containers/NotificationList.tsx` + `hooks/queries/*.ts`.
- `GET /web/api/notification/list?...` (`useGetNotificationList.ts:12`)
- `GET /web/api/notification/{api}/detail?...` (`useGetNotificationDetail.ts:12`)
- `GET /web/api/notification/summary/result?...` (`useGetNotificationSummary.ts:12`)
- 딥링크: `${getWadizBaseURL()}/web/store/detail/{projectNo}` or `.../web/campaign/detail/{projectNo}` (타입 분기, `NotificationList.tsx:77,81`).

### 6.18 이벤트 보상형 쿠폰 (`/web/app/benefit-coupon`)

- 파일: `pages/benefit/BenefitApp.jsx` + `pages/BenefitCouponManagementPage.tsx` + `hooks/benefitApis.ts:1-60`.
- BASE: `/web/apip/funding/admin/events`.
- 이벤트(진입점) — `ACTION_TYPE.ENTRY`:
  - `POST /web/apip/funding/admin/events`
  - `GET  /web/apip/funding/admin/events/{EVENT_NO}`
  - `PUT  /web/apip/funding/admin/events/{EVENT_NO}`
  - `DELETE /web/apip/funding/admin/events/{eventNo}` (`deleteBenefit`)
- 고정 보상 — `ACTION_TYPE.BENEFIT`: `POST/GET/PUT /web/apip/funding/admin/events/fixed-benefit[/{EVENT_NO}]`
- 랜덤 보상 — `ACTION_TYPE.RANDOM_BENEFIT`: `POST/GET/PUT /web/apip/funding/admin/events/random-benefit[/{EVENT_NO}]`
- 목록: `GET /web/apip/funding/admin/events?size&page&eventStarted&eventEnded&keyword&name` (`getAllEvents`)
- `benefitApis.ts:24-28` 의 `getEventURL` 이 `{EVENT_NO}` 템플릿을 치환하는 구조 — 세 가지 ACTION_TYPE 의 대칭성을 유지.

---

## 7. 인증 · 권한

관측 가능한 단서만.

### 7.1 로그인 쿠키/세션

- SPA 는 **자체 로그인 화면이 없다**. 레거시 `com.wadiz.adm` 의 Spring Security + 2FA(OTP) 로그인 플로우를 그대로 사용(docs `com.wadiz.adm.md:59` googleauth / qrgen / uadetector).
- `proxyInfo.js:81` 의 프록시 context 에 `/j_spring_security_check` 가 포함 — 로컬 개발에서 로그인 폼 POST 도 동일 프록시로 전달.
- SPA 내부 세션 체크:
  - `api/index.js:20-22`: 스토어 API 래퍼에서 `status === 401` 이면 `window.location.href = '/web/account/login'` redirect.
  - `api/curation/curation.ts:10-18`: 큐레이션 API 의 동일 패턴.
  - 이외 대부분의 hook 은 401 처리를 하지 않고 에러를 그대로 throw.
- `fetchApi.js:5` 가 `@wadiz/utils/loginController` 를 import 하지만 이 SPA 에서 해당 훅을 호출하는 지점은 관측되지 않음 — adm 쿠키 자체를 신뢰.

### 7.2 권한 분기

- SPA 코드 내에는 **권한 enum/role 체크 로직이 없다**. 메뉴 노출/숨김은 전적으로 레거시 어드민 측에서 결정:
  - `com.wadiz.adm/src/main/java/com/wadiz/web/fw/interceptors/AuthzInterceptor.java:109-144` 가 권한 없는 요청을 차단하고 `alert('permission denied.');location.href='/web/home'` 스크립트로 응답(docs `com.wadiz.adm.md` 참조 영역).
  - 따라서 운영자가 URL 을 직접 쳐도 어드민 서버에서 먼저 막는 구조. SPA 는 모든 라우트를 렌더링 가능 상태로 가진다.
- SPA 가 **권한 관련 API 호출 후 받은 응답값**으로 UI 를 분기하는 부분은 존재(예: `adminApprovalStatus`, `adminRequestRoute` 로 메이커 상태 분기 — `pages/maker/containers/MakerAdminRequestorList/...`). 즉 역할 기반이 아니라 **"대상 데이터의 상태"** 기반 UI 분기.

### 7.3 도메인 별 세부사항

- `packages/api/src/admin/account.services.ts` 의 `getCouponTemplates` 는 `development` + `?account_mock=true` 쿼리가 있을 때 `./mocks/account_coupon_templates` 로 대체(같은 파일:48-54) — **테스트 환경에서 권한 없이도 UI 를 열 수 있게 하는 mock path**.

---

## 8. 레거시 대체 진행 상태

### 8.1 SPA 로 이관된 메뉴 (관측 증거: `setViewName("front/main")`)

아래 Spring ViewController 들이 전부 `front/main` JSP 한 장을 반환하므로 **라우트 경로가 React Router 에 넘어간다**는 것이 이관 완료 증거 (`grep 'ModelAndView("front/main")' com.wadiz.adm/src`).

| 어드민 ViewController | React 모듈 | Router.jsx 경로 |
|---|---|---|
| `web.home.HomeViewController` | `home` | `/web/home/*` |
| `web.wevent.invite.InviteEventViewController` | `invite-friends` | `/web/event/invitation/*` |
| `web.popup.PopupMainController` | `notice-popup` | `/web/popup/*` |
| `web.supporterclub.SupporterClubController` | `supporter-club`, `supporter-club-voucher` | 2개 경로 |
| `web.supporterClubSettlement.SupporterClubSettlementController` | `supporter-club-settlement` | `/web/app/supporter-club-settlement/*` |
| `web.maker.MakerViewController` | `maker` | `/web/maker/*` |
| `web.store.StoreViewController` | `store-admin-app` | `/web/app/store/*` |
| `web.maker.announcement.MakerAnnouncementViewController` | `maker-announcement` | `/web/maker-announcement/*` |
| `web.reward.coupon.rewardCouponViewController` | `reward-coupon` | `/web/app/reward-coupon/*` |
| `web.reward.coupon.rewardCouponAccountingViewController` | `reward-coupon-accounting` | `/web/app/coupon-accounting` |
| `web.ip.program.IpProgramViewController` | `ip-license` | (주석 처리) |
| `web.community.WEBCommunityController:51` | `community/feed` | `/web/community/communityFeedContentList` |
| `web.event.EventViewController` | `event` | `/web/event/big-unique-brand-v2/*` |
| `web.manage.home.manageHomeViewController` | `web-manage/home/quickMenu` | `/web/manage/home/quickMenu` |
| `web.notification.NotificationViewController` | `notification-list` | `/web/notification/send-result` |

추가로 직접 관측된 `front/main` 반환 컨트롤러:
- `web.store.StoreViewController:27` — 스토어 전체
- `web.supporterclub.SupporterClubController:36,152` — 두 메서드가 각각 supporter-club 본체/하위 경로 담당

### 8.2 아직 JSP 에 남아 있는 주요 운영 화면 (`docs/com.wadiz.adm.md:20-27`)

- **회원 관리**: `WEBAccountController`(68 매핑), `WEBDmAccountController`, `WEBFindAccountInfoController`, `WEBMarketingParticipationController` 등
- **증권형(투자) 전체**: `WEBEquityController`(149), `EquityCampaignController`(63), `EquityStagePublishController`(34), `WEBMasterGroupController`(24), `WEBCouponController`(16)
- **리워드 결제/환불/정산** 대부분: `payment/*`, `settlement/*` 패키지
- **레거시 프로젝트 신청**: `legacy.WEBLRequestController`
- **메일/푸시/통계**: `mail/*`, `app.push.*`, `sts.*`
- **배너/이벤트 구버전**: `wpartner.*` 시리즈 (`WPartnerController` 의 `wpartner/*` 뷰)

### 8.3 이관 과도기 특징

- `ERPModalApp` / `PreviewApp` 이 `window.wadiz.*` 전역을 노출하는 이유가 **JSP 화면에서도 React 모달을 띄우기 위함** — 양쪽이 병존하기 때문.
- SPA 내부에서도 **구 패턴(redux-thunk + `@wadiz/fetch-api/src` requestApi)** 과 **신 패턴(react-query + `@wadiz/api/admin` TS)** 이 페이지별로 다르다. 비교적 최신인 `coupon-issuekey`, `benefit`, `reward-coupon-accounting`, `store-admin-app/promotion`, `event`, `web-manage/home/quickMenu` 는 TS + react-query.
- `reward-coupon` 서브 앱은 **JS + react-query 없음** (내부 reducers 사용) — 초기 이관 페이지.
- `community/feed/services/service.js` 는 다른 모듈의 copy-paste dead code — 정리되지 않은 상태의 증거.
- `store-admin-app/api/curation/curation.ts:7-20` 에 `TODO: @wadiz/fetch-api 에 정의된 fetchApi 함수로 변경되어야 함` 주석 — 공통 fetch 래퍼 이관이 진행 중.

### 8.4 SPA 가 레거시 자원을 참조하는 지점 (아직 JSP/레거시 도메인 의존)

- `pages/maker/components/MakerAdminRequestorList/MakerAdminRequestorList.jsx:53` — `https://${currentEnv}.wadiz.kr/web/ftcampaign/download/attach?encFileId=` (레거시 도메인 직접 링크)
- `pages/store-admin-app/pages/StoreProjectDetail/ProjectInfo.jsx:35,312,362,371` — 레거시 어드민/웹 본체로 outbound 링크 생성 (`getAdminBaseURL()`, `WADIZ_DOMAIN`)
- `pages/store-admin-app/pages/StoreProjectDetail/FileManage.jsx:22-23,77-78` — 첨부 다운로드가 **legacy-system/download** 와 신규 `store/attachments` 를 동시에 지원 (두 시스템 공존).

---

## 9. 경계 및 미탐색 영역

- **백엔드 처리**: 모든 `/web/apip/funding/admin/*`, `/web/apip/store/admin/*`, `/web/reward/api/*`, `/web/v2/membership/admin/*`, `/web/maker/*`, `/web/popup/*`, `/web/event/api/invite/*`, `/web/feeds/*`, `/web/api/notification/*`, `/web/manage/home/*` 의 **실제 서버 처리/DB 쿼리/권한 체크** 는 이 repo 에 없다. 대부분 `com.wadiz.adm` (JSP 어드민) 또는 `co.wadiz.*` 리라이트 서비스, 그리고 `kr.wadiz.account`, `com.wadiz.api.funding`, `com.wadiz.api.reward` 의 admin 섹션에 흩어져 있음.
- **Redux 전역 state 의 완전한 형태**: `reducers/index.js` 는 `inviteFriends` 하나만 combine 하고 나머지는 페이지별 store 로 격리된다. 페이지별 slice 파일을 전부 읽어야 도메인 state 모델이 보인다 — 이번 문서 범위에서는 maker 도메인 (`features/{maker,makers,funding,store,history,teamMember}Slice.js`) 만 확인.
- **Query key 설계 / cache 전략**: 각 도메인마다 `QueryClient` 를 새로 만들고 있어 **cross-domain cache 공유가 불가능**. 이 설계가 의도인지 잔재인지는 관측 불가.
- **ERP 사원/부서 검색 모달**이 JSP 에서 실제로 어디서 호출되는지는 `com.wadiz.adm` 쪽 JS 를 읽어야 함(이 repo 범위 밖).
- **`ip-license` 주석 처리 시점** 과 그 이유는 코드로 확인 불가. Router.jsx 주석 한 줄 `IP 라이센스 사업 관리 - 미사용` 뿐.
- **인증/2FA 플로우**: SPA 는 이미 로그인된 세션을 가정한다. 로그인 화면은 JSP 측(`com.wadiz.adm/src/main/java/com/wadiz/web/wlogin/controller/WEBLoginController.java`)에 있어 이 repo 범위 밖.
- **e2e 시나리오·스모크 테스트**: `static/services/admin/**/*.test.*` / `.spec.*` 파일 없음. 테스트 인프라 미확인.
- **`packages/cert/` SSL 인증서 갱신/배포 방법**: README 에 언급만 있고 파일 자체는 범위 밖.
- **`@wadiz/api/admin` 전환 로드맵**: 현재 `account.services` 만 있고, 다른 도메인은 여전히 `@wadiz/fetch-api` 에 의존. 공식 이관 계획 문서는 이 repo 내에 없음.
