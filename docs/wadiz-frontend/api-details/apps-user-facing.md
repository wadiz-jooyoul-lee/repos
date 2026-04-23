# 사용자 지향 Apps 상세 스펙 (account / global / help-center / ir / partners / partnerzone)

> **기록 범위**
>
> - 본 문서는 `wadiz-frontend/apps/` 하위 6개 애플리케이션(`account`, `global`, `help-center`, `ir`, `partners`, `partnerzone`) 소스 트리에서 실제로 관측 가능한 파일, 환경 설정(`.env*`, `.env-cmdrc`), 빌드 설정(`vite.config.ts`, `next.config.js`), 라우트 선언, `@wadiz/api` 패키지를 경유하는 API 호출만 기록합니다.
> - 백엔드(upstream) 서버 내부 구현은 이 repo 범위가 아니므로 "외부 서비스"로 표기합니다. 매핑은 각 앱이 어떤 `VITE_*_URL` / `NEXT_PUBLIC_*` 를 경유하여 어느 서버 도메인에 붙는지의 관측치만 기록합니다.
> - 엔드포인트 URL은 `packages/api/src/**/<service>.ts` 의 실제 `GET/POST/PUT/PATCH/DELETE` 호출과 `baseUrl` 조합으로 관측한 것에 한정합니다. 서비스 파일은 공용 패키지이므로 각 앱별 "호출 여부"는 `import { ... } from '@wadiz/api/...'` 사용처로 확인합니다.
> - 추측은 하지 않습니다. 관측할 수 없는 부분은 "확인 불가"로 명시합니다.

---

## 1. 개요

`wadiz-frontend` 모노레포의 최상위 `apps/` 디렉터리에는 CI/CD 가 독립된 9개 앱이 있으며, 그중 본 문서가 다루는 **사용자 지향(End-User Facing) 앱은 6개** 입니다. 나머지 3개(`mail-template`, `wai-ai-agent-launcher`, `walink-generator`)는 템플릿/사내용이므로 본 문서에서는 제외합니다.

### 6개 앱 요약

| 앱 | 빌드 도구 | 타겟 사용자 | 주된 역할 | 배포 도메인 (live) |
|---|---|---|---|---|
| `account` | Vite 6 + React 18 | 일반 사용자 (글로벌+국내) | 통합 로그인/회원가입/비밀번호/소셜연동/탈퇴 | `https://account.wadiz.kr` |
| `global` | Vite 6 + React 18 (SPA) | 글로벌 사용자 (및 국내 일부 재사용) | 글로벌 펀딩/홈/마이와디즈/결제/고객센터 통합 | `https://www.wadiz.kr` (live 기준 `VITE_WEB_URL`) |
| `help-center` | **Zendesk Guide 테마** (Handlebars) | 고객센터 방문자 | FAQ, 문의 티켓 — Zendesk 플랫폼 위에서 동작 | `https://helpcenter.wadiz.kr` |
| `ir` | Next.js 16 (export static) + Webpack | 투자자/주주 | 회사 소개·IR 공시·재무정보 정적 사이트 | `https://www.wadizcorp.com` |
| `partners` | Next.js 14 (export static) | 잠재 파트너 기업 | "와디즈파트너스" 브랜드 랜딩 | `https://partners.wadiz.kr` |
| `partnerzone` | Vite 5 + React 18 (SPA → WordPress 임베드) | 파트너존 방문자 | 파트너존 서비스 소개 iframe 콘텐츠 | `https://static.wadiz.kr/partnerzone` (WordPress 내 임베드 `https://partnerzone.wadiz.kr`) |

### 공통점
- 6개 모두 **SPA 또는 정적 사이트 출력 (`output: 'export'` / `vite build`)** 이며, `AWS S3` 로 배포합니다 (각 README 의 "배포" 섹션 참조).
- 런타임 서버가 없으므로 **`BFF` 층이 없고 브라우저가 직접 wadiz 백엔드에 CORS 호출**합니다. (예외: `help-center` 는 Zendesk 내부 API, `ir/partners` 는 CDN JSON 페치)
- React 18.2.0 고정, `pnpm` 워크스페이스 내에서 `packages/*` 를 소스 참조 (빌드 산출물 재사용 X).

### 차이점
- **API 호출 비중**: `global` > `account` >>> `ir` ≈ `partners` ≈ `partnerzone` ≈ `help-center`. IR/Partners/Partnerzone 은 API 호출이 거의 없거나 정적 JSON (`cdn3.wadiz.kr/app`, Google Sheets Apps Script 배포 JSON) 만 소비.
- **환경 관리**: `account`, `global` 은 `env-cmd` + `.env-cmdrc` 다중 환경(local/dev/rc/rc2/rc3/stage/live) 7단계. `ir`, `partners`, `partnerzone` 은 `.env.production.*` + `.env.development.local` 2~4단계. `help-center` 는 Zendesk 전용 `.env.dev` / `.env.live`.
- **다국어(i18n)**: `account`, `global` 은 `@wadiz/i18n` (i18next) 기반 다국어 지원. 나머지 4개는 단일 언어(한국어) 혹은 Zendesk 내장 로케일.
- **라우팅**: `account`, `global`, `partnerzone` 은 React Router v6 클라이언트 라우팅. `ir`, `partners` 는 Next.js App Router. `help-center` 는 Zendesk Guide 템플릿 시스템 (`.hbs`).

---

## 2. 앱별 섹션

### 2.1 `apps/account`

#### 앱 메타

| 항목 | 값 | 비고 |
|---|---|---|
| 빌드 도구 | Vite 6 | `apps/account/vite.config.ts:1-169` |
| 프레임워크 | React 18.2.0 + React Router 6.26 | `apps/account/package.json:45-54` |
| 언어/모듈 | TypeScript 5.6, ESM (`"type": "module"`) | `apps/account/package.json:5` |
| 진입 HTML | `apps/account/index.html` |  |
| 진입 TS | `src/app/main.tsx` | Vite rollup input 설정 |
| Dev 서버 | `https://local.wadiz.kr:5174` | `apps/account/vite.config.ts:159-166` |
| Dev 인증서 | `apps/account/cert/local.wadiz.{crt,key}` |  |
| 상태 관리 | TanStack Query 5.66, Zustand 5.0 |  |
| 폼/검증 | react-hook-form 7.54, yup 1, @hookform/resolvers |  |
| 결제 SDK | `@stripe/stripe-js` 5.6, `@stripe/react-stripe-js` 3.1 | 글로벌 결제 SDK (회원가입 완료 연계) |
| 지도/전화 | `@googlemaps/js-api-loader`, `libphonenumber-js`, `react-phone-number-input` | 가입/정보 입력 시 국가·전화 |
| Sentry | `@sentry/vite-plugin` 3.3 | `apps/account/vite.config.ts:117-122` |
| 배포 | S3 `wadiz.static/global-account` (live) | `apps/account/README.md:51-55` |
| 배포 도메인 | `https://account.wadiz.kr` (live), `https://dev-account.wadiz.kr`, `rc/rc2/rc3-account.wadiz.kr`, `stage-account.wadiz.kr` |  |

#### 환경변수 · upstream 매핑

`apps/account/.env-cmdrc` (환경 7개) + `apps/account/.env` (Sentry, Braze 상수):

| VITE 환경변수 | live | 용도 | 매핑된 wadiz 서비스 |
|---|---|---|---|
| `VITE_ACCOUNT_URL` | `https://account.wadiz.kr` | **계정 서버 (Auth 2.0)** | 실제로 계정 자신이면서 동시에 `@wadiz/api/account/account.service.ts` 의 `BASE_URL` | `kr.wadiz.account` |
| `VITE_APP_API_URL` | `https://app.wadiz.kr` | App BFF | `app-api` (NestJS) |
| `VITE_PLATFORM_API_URL` | `https://platform.wadiz.kr` | 플랫폼 API | (레거시 플랫폼 게이트웨이, `com.wadiz.*` 도메인) |
| `VITE_PLATFORM_GLOBAL_API_URL` | `https://platform.wadiz.kr/global` | 플랫폼 글로벌 서브패스 | (상동) |
| `VITE_PUBLIC_API_URL` | `https://public-api.wadiz.kr` | 공용 퍼블릭 API | (내부 퍼블릭 API) |
| `VITE_SERVICE_API_URL` | `https://service.wadiz.kr` | 서비스 API | 검색·친구 등 서비스 레이어 |
| `VITE_STATIC_URL` | `https://static.wadiz.kr` | 정적 리소스 | S3 CDN |
| `VITE_WEB_URL` | `https://www.wadiz.kr` | 레거시 웹 | `com.wadiz.web` (JSP) |
| `VITE_ANALYTICS_URL` | `https://analytics.wadiz.kr` | 분석 서버 | Analytics 서버 (내부 확인 불가) |
| `VITE_BRAZE_API_KEY` / `VITE_BRAZE_BASE_URL` | `0c308381-...` / `https://sdk.iad-06.braze.com` | Braze SDK | Braze (외부 SaaS) |
| `VITE_SENTRY_DSN` | `https://b3c9d2a629edc6779b9288616d5491eb@o194600.ingest.us.sentry.io/4506376215396352` | Sentry | Sentry Cloud |

`vite.config.ts` 의 `define` 블록이 **`process.env.ACCOUNT_URL`, `process.env.WEB_URL` 등** 으로 재-export 합니다 (`apps/account/vite.config.ts:70-85`). 따라서 `@wadiz/api/account/account.service.ts:43` 의 `process.env.ACCOUNT_URL` 는 실행 시점에 위 값으로 치환됩니다.

특이사항:
- `account.service.ts:39-43` 는 `location.origin.includes('local-account.wadiz.kr')` 인 경우 `window.location.origin` 을 `BASE_URL` 로 채택합니다 → 회원팀이 자체 로컬 서버를 띄울 때 테스트 용.
- `process.env.ENVIRONMENT === 'stage'` 인 경우 stage 도메인 강제 (`ACCOUNT_URL.stage`) — `stage`는 `VITE_ENVIRONMENT=live` 로 세팅되기 때문에 별도 분기.

#### 라우트 구조

진입 `src/app/App.tsx:37-45` → 라우터 루트는 `path: '/'` 하나, 그 아래 `getAuthRoute()` 한 개.

`apps/account/src/app/routes/auth.tsx:21-72` — `:languageCode?` prefix + 다음 하위 경로:

| 경로 | 컴포넌트 | 대상 |
|---|---|---|
| `/[:lang]/find-id` | `AuthFindIDPage` | 아이디 찾기 |
| `/[:lang]/find-password` | `AuthFindPasswordPage` | 비밀번호 찾기 |
| `/[:lang]/reset-password/:token` | `AuthResetPasswordPage` | 비밀번호 재설정 (이메일 토큰) |
| `/[:lang]/social-link` | `AuthSocialLinkPage` | 소셜 계정 연동 |
| `/[:lang]/social-signup` | `AuthSocialSignupPage` | 소셜 회원가입 |
| `/[:lang]/login` | `AuthLoginPage` | 통합 로그인 |
| `/[:lang]/signup` | `AuthSignupPage` | 이메일 회원가입 |
| `/[:lang]/account/...` | `getAccountRoute()` | 구버전 **앱(모바일) 호환** 경로 (`apps/account/src/app/routes/account.tsx:13-45`) |
| `/[:lang]/web/account/signup/completed` | `getWebRoute()` | 구버전 글로벌 **웹** 호환 경로 (`apps/account/src/app/routes/web.tsx`) |

앱 호환 경로(`(auth-app)` 그룹):
- `/account/delete` — 회원 탈퇴
- `/account/signup` / `/account/signup/completed` / `/account/signup/completed-legacy`
- `/account/social-link`, `/account/social-signup`

디렉터리: `apps/account/src/pages/(auth)/` 및 `apps/account/src/pages/(auth-app)/`.

#### 기능↔API 매핑 테이블

관측 위치: `apps/account/src/pages/**/*.{ts,tsx,js,jsx}` 내 `accountService.*`, `termsService.*` 호출 + `fetch('/api/v1/...')` 직접 호출.

**계정 서버 (`VITE_ACCOUNT_URL` → `kr.wadiz.account`)** — 경로는 `@wadiz/api/account/account.service.ts` 에서 추출:

| 화면/기능 | 호출 엔드포인트 | 용도 | Upstream |
|---|---|---|---|
| 이메일 가입 (`signup`) / 소셜 연동 가입 | `POST /api/v1/users` · `POST /api/v1/social-users` | 신규 회원 생성, 응답 `location` 헤더에서 신규 userID 추출 | `kr.wadiz.account` |
| 소셜 계정 연동 (`social-link`) | `POST /api/v1/link-users` | 기존 와디즈 계정과 소셜 연동 | `kr.wadiz.account` |
| 이메일 인증 코드 발송 (signup/login-validation) | `POST /api/v2/authentication-code` | 인증번호 발송 | `kr.wadiz.account` |
| 이메일 인증 코드 검증 | `GET /api/v2/authentication-code/{code}/valid` | 인증번호 유효성 | `kr.wadiz.account` |
| 아이디 찾기 (`find-id`) | `POST /api/v1/find-id` | 가입 이메일 상태 조회 (EMAIL_LOGIN_OK / SNS_LOGIN_OK / NOT_REGISTERED / DROPPED_OUT_WITHIN_90DAYS) | `kr.wadiz.account` |
| 가입 정보 조회 (소셜 분기) | `GET /api/v1/signup-information` | joinType / providerType / social 정보 | `kr.wadiz.account` |
| 로그인 상태 | `GET /api/v1/user-login-status` | isLoggedIn 확인 | `kr.wadiz.account` |
| 카카오 인가 파라미터 | `GET /api/v1/authorization-register/kakao?rememberme=on\|off` | 카카오 OAuth state/redirectUri/clientId | `kr.wadiz.account` |

사용처:
- `apps/account/src/pages/(auth)/_api/useSignUp.ts:26-37` — `postUserMutation`, `postSocialUserMutation`, `postLinkUsersMutation`.
- `apps/account/src/pages/(auth)/_ui/EmailAuth/EmailAuthContainer.tsx:42,79` — `postAuthenticationCodeMutation`, `getAuthenticationCodeValidMutation`.
- `apps/account/src/pages/(auth)/login/_ui/EmailValidationForm.tsx:134,167` — `postAuthenticationCodeMutation`, `postFindIdMutation`.
- `apps/account/src/pages/(auth)/login/_ui/LoginFormAndSocialButtons.tsx:216` — `accountService.getKakaoAuthorizationRequestParm(...)`.
- `apps/account/src/pages/(auth)/social-signup/_ui/SocialSignup.tsx:24` — `getSignUpInformationQuery`.
- `apps/account/src/shared/api/useIsLoggedInQuery.ts:55` — `accountService.getIsLoggedInQuery()`.

**레거시 웹 (`VITE_WEB_URL` → `com.wadiz.web`)** — `@wadiz/api/web/account.service.ts` 와 기타 `web/*`:

| 화면/기능 | 엔드포인트 (상대경로, baseUrl=WEB_URL) | 용도 | 위치 |
|---|---|---|---|
| 탈퇴 — 인증번호 요청 | `accountService.requestWithdrawalAuthCode` | 탈퇴용 인증번호 요청 (레거시 web) | `apps/account/src/pages/(auth)/account/delete/_api/useDropOut.ts:7` |
| 탈퇴 — 인증번호 확인 | `accountService.confirmWithdrawalAuthCode` | 확인 | `:14` |
| 탈퇴 실행 | `accountService.withdrawal` | 탈퇴 처리 | `:21` |
| 탈퇴 가능 여부 | `GET /web/v3/account/dropout/availability` | 탈퇴 가능 검증 | `apps/account/src/pages/(auth)/account/delete/_ui/AccountDropOutContainer/AccountDropOutContainer.jsx:185` |
| 가입 약관 (국가별) | `termsService.getSignupTermsQuery()` | 서포터 약관 목록 | `apps/account/src/pages/(auth)/signup/_ui/SignupForm.tsx:118`, `apps/account/src/widgets/signup-terms-confirm-app/lib/hooks/useTerms.ts:24` |
| 마케팅 수신 약관 | `termsService.getMarketingTermsQuery()` | 완료 페이지 마케팅 팝업 | `apps/account/src/pages/(auth)/account/signup/completed/_ui/SignupCompleted.tsx:39` |
| 소셜 링크 핸들러 약관 | `termsService.getLinkHandlerTerms()` | 소셜 연동 안내 | `apps/account/src/entities/oauth/lib/socialUtil.js:102` |
| 약관 본문 HTML | `GET {WEB_URL}/resources/terms/{name}.html` | 약관 원문 (SSR 렌더된 HTML) | `packages/api/src/terms/terms.service.ts:25` |
| 로그인 리턴 URL | `GET /web/login/return_url` (credentials=include) | 앱 딥링크 / 리턴 복귀용 | `packages/api/src/web/account.service.ts:414`, 사용 `apps/account/src/widgets/app-launch-button/ui/AppLaunchButton.tsx:38` |
| 핸드폰 인증번호 요청 | `POST /web/waccount/ajaxRequestSendUserAuthSmsCorpManager?mobileNumber=...` | 모바일 SMS OTP | `packages/api/src/web/account.service.ts:447` |
| 회원가입 완료 프로모션 코드 확인 | (app-app) `useValidPromotionCode` | 프로모션 검증 | `apps/account/src/pages/(auth-app)/account/signup/completed-legacy/_api/useValidPromotionCode.js` |
| 모바일 번호 인증 상태 | `accountService.getIsMobileNumberCertification` | 인증 완료 플래그 | `apps/account/src/pages/(auth-app)/account/signup/completed-legacy/_api/useIsMobileNumberCertification.js:10` |
| 모바일 번호 인증 쿼리 | `accountService.getMobileNumberCertificationQuery()` | 완료 페이지 가입 후 프로모션 적용 전 확인 | `apps/account/src/pages/(auth)/account/signup/completed/_ui/SignUpPromotionApplication.tsx:71` |

**비밀번호/아이디 찾기 (상대경로, account 도메인 동일 출처)**
- `POST /api/v1/password-reset/confirm` — `apps/account/src/pages/(auth)/reset-password/_ui/ResetPassword.tsx:32`
- `POST /api/v1/find-id` (상대경로 fetch) — `apps/account/src/pages/(auth)/(find)/_ui/FindPassword.tsx:39`
- `POST /api/v1/password-reset/request` — `:59`
  → 모두 같은 도메인 상대경로 fetch. 브라우저 관점에서 `account.wadiz.kr` 본인(= `VITE_ACCOUNT_URL`) 이므로 동일 upstream(`kr.wadiz.account`).

**국가 목록 (레거시 web)**
- `GET /web/v1/countries` — `apps/account/src/pages/(auth-app)/_api/country.ts:12` (host = `process.env.WEB_URL`)

**앱 전용 가입 약관**
- `POST /web/v2/join/terms` — `apps/account/src/pages/(auth-app)/account/signup/_api/useListOfTermsForMembershipType.jsx:4` (상대경로)

#### 공유 packages 의존성

`apps/account/vite.config.ts:131-152` 의 alias 선언 기준:

- `@wadiz/api` → `packages/api/src` (핵심 `account.service.ts`, `web/account.service.ts`, `web/term/...`, `terms/...`)
- `@wadiz/artworks`, `@wadiz/waffle`, `@wadiz/waffle-icons` — 디자인 시스템
- `@wadiz/core` — `Locale`, `getAllCookiesSnapshot`, 공용 유틸
- `@wadiz/event-tracker` — 이벤트 트래킹
- `@wadiz/features` — 공통 기능 (`auto-login`, `navigation` 등 — 주로 global 과 공유)
- `@wadiz/i18n` — 다국어
- `@wadiz/metrics` — Sentry wrapper
- `@wadiz/settings` — `LocaleSettings`, `AccountSettings`
- `@wadiz/ui` — 공용 UI (`MultiFollow`)
- `@wadiz/request-api` / `@wadiz/react-components` / `@wadiz/react-error-boundary` (libraries/)

---

### 2.2 `apps/global`

#### 앱 메타

| 항목 | 값 | 비고 |
|---|---|---|
| 빌드 도구 | Vite 6 | `apps/global/vite.config.ts` |
| 프레임워크 | React 18.2.0 + React Router 6.26 | `apps/global/package.json` |
| 이중 엔트리 | `src/app/main.tsx` (글로벌), `src/app/korea-main.tsx` (국내용) | `vite.config.ts:25-28` |
| Dev 서버 | `https://local.wadiz.kr:5173` (origin) | `apps/global/vite.config.ts:167-179` |
| CSS 번들 | `cssCodeSplit: false` → 단일 `main.css` | `:22`, `:41-43` |
| 상태 관리 | TanStack Query 5.66, Zustand 5.0 |  |
| 헬멧 | `react-helmet-async` 2.0 |  |
| Stripe | `@stripe/stripe-js`, `@stripe/react-stripe-js` |  |
| 배포 | S3 `wadiz.static/global` (live), `wadiz.static.dev/global` (dev) | `apps/global/README.md:52-55` |
| 배포 도메인 | `VITE_WEB_URL` 와 동일 (`www.wadiz.kr` / `dev.wadiz.kr`) — 사실상 `com.wadiz.web` 이 HTML 호스팅, SPA 자산은 S3 | `apps/global/README.md:18-22` |

**중요**: `com.wadiz.web` (JSP) 이 HTML 메타데이터·세션·전역변수를 제공하고, `global` SPA는 그 위에 삽입되는 구조 (`README.md:18`). 글로벌용(`main.tsx`) / 국내 재사용(`korea-main.tsx`) 두 엔트리로 분기.

#### 환경변수 · upstream 매핑

`apps/global/.env-cmdrc` (환경 7개). account 보다 몇 개 더 많음:

| VITE 환경변수 | live 값 | 매핑 wadiz 서비스 / 외부 |
|---|---|---|
| `VITE_ACCOUNT_URL` | `https://account.wadiz.kr` | `kr.wadiz.account` |
| `VITE_APP_API_URL` | `https://app.wadiz.kr` | `app-api` (NestJS) |
| `VITE_DATA_API_URL` | `https://datasvc.wadiz.kr` | 데이터/분석 서비스 (`support-share` 등) |
| `VITE_PLATFORM_API_URL` | `https://platform.wadiz.kr` | 플랫폼 게이트웨이 |
| `VITE_PLATFORM_GLOBAL_API_URL` | `https://platform.wadiz.kr/global` | 글로벌 서브패스 (번역/환율) |
| `VITE_PLATFORM_GLOBAL_API_TOKEN` | `38DC62EE...` | 글로벌 API Bearer 토큰 |
| `VITE_PLATFORM_MAIN2_API_URL` | `https://platform.wadiz.kr` | `main2/api/v*` 네임스페이스 (홈·랭킹) |
| `VITE_PUBLIC_API_URL` | `https://public-api.wadiz.kr` | 퍼블릭 |
| `VITE_SERVICE_API_URL` | `https://service.wadiz.kr` | 검색·친구 |
| `VITE_STATIC_URL` | `https://static.wadiz.kr` | 정적 자산 |
| `VITE_WEB_URL` | `https://www.wadiz.kr` | `com.wadiz.web` (JSP) |
| `VITE_ANALYTICS_URL` | `https://analytics.wadiz.kr` | 분석 |
| `VITE_TOKEN_MARKETING` / `VITE_TOKEN_INBOX` / `TOKEN_KEYWORDS` | (32-byte hex) | 마케팅·인박스·키워드 서비스 인증 토큰 |
| `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` | `https://joicppugmewvksclxfox.supabase.co` / (JWT) | Supabase (외부 BaaS) — 용도 관측 불가 |

`vite.config.ts:76-96` 가 `process.env.PLATFORM_MAIN2_API_URL`, `process.env.DATA_API_URL`, `process.env.TOKEN_*` 등을 `define` 으로 노출.

#### 라우트 구조

- **엔트리 1: `src/app/main.tsx`** — `renderAppWithInitialization(<App />, 'root')`. `autoLogin()` 먼저 실행.
- `src/app/App.tsx:40-47` — `AppLayout` 자식으로 `getRootRoute(queryClient)` 하나.
- `src/app/routes/root.tsx:32-89` — `:languageCode?` prefix + 하위:

| Route | 주요 파일 |
|---|---|
| `/` → `/home` redirect | `root.tsx:48-50` |
| `/home` | `pages/home/HomeLayout`, `HomePage` |
| `/about` | `routes/about.tsx` |
| `/app/about` | `routes/app.tsx` (앱 설치 안내) |
| `/create-project` | `routes/create-project.tsx` |
| `/error/*` | browser-not-supported, expired, maintenance, not-permitted, server-error, unauthorized, waiting-for-connection (`pages/error/*`) |
| `/events`, `/events/top`, `/events/:eventNo` | `routes/events.tsx` |
| `/funding/:projectNo` (+ `/story`, `/news`, `/news/:newsID`, `/community`, `/community/comments`, `/community/support-share`, `/community/reviews`, `/refund-policy`, `/reward-details`, `/rewards`, `/supporters`) | `routes/funding.tsx:37-130` |
| `/funding/payment` (+ `/pending`, `/completed/:backingPaymentId`) | `routes/funding.tsx:41-79` |
| `/my-wadiz` 서브트리 (orders, coupons, inquiries, invitation-code, maker, points, settings, supporter) | `pages/my-wadiz/*` |
| `/maker`, `/maker/projects`, `/maker/profile/[corpNo]` | `routes/maker.tsx` |
| `/notifications` | `pages/notifications` |
| `/policies` | `pages/policies` |
| `/refer-a-friend`, `/refer-a-friend/invitation` | `routes/refer-a-friend.tsx` |
| `/search` | `routes/search.tsx` |
| `/settlement-date-calculator` | `routes/settlement-date-calculator.tsx` |
| `/social` (친구·팔로우·차단) | `routes/social.tsx` |
| `/sourcing-club` | `routes/sourcing-club.tsx` |
| `/support` (고객센터 요청/상세/신규) | `routes/support.tsx` |
| `/wai` | `routes/wai.tsx` |
| `/wish` | `routes/wish.tsx` |

- **엔트리 2: `src/app/korea-main.tsx`** + `src/app/korea-routes/root.tsx:14-31`
  - `about`, `events`, `inbox`, `maker`, `my-wadiz`, `settlement-date-calculator`, `social`, `sourcing-club`, `support`, `wai` — 글로벌에서 정의한 동일 페이지 서브셋을 국내 서비스(`com.wadiz.web` 임베드)에서도 재사용.
  - 기본 이동: `<Navigate to="/web/main" />`.

#### 기능↔API 매핑 테이블

관측치 범위가 매우 크므로 **핵심 페이지/위젯 단위**로 요약합니다. 상세는 `@wadiz/api` 서비스 파일 각각 참조.

| 화면/기능 (경로) | 호출 서비스.메서드 | 관측된 HTTP + URL | Upstream baseUrl (env 기반) |
|---|---|---|---|
| 홈 키비주얼 배너 (`/home`) | `main2Service.getKeyVisualBannersQuery` | `GET /main2/api/v1/pc/main/key-visual` | `PLATFORM_MAIN2_API_URL` (`platform.wadiz.kr`) |
| 홈 메트릭 오버뷰 | `main2Service.getMetricsOverviewQuery` | `GET /main2/api/v1/pc/main/metrics` | `PLATFORM_MAIN2_API_URL` |
| 홈 퀵메뉴 | (main2) | `GET /main2/api/v1/quickmenu?id=...` | `PLATFORM_MAIN2_API_URL` |
| 홈 최근 본 | (main2) | `GET /main2/api/v1/recentview` | `PLATFORM_MAIN2_API_URL` |
| 홈 PC 메인 펀딩 / 랭킹 / 커밍순 / 스토어 | (main2) | `GET /main2/api/v1/pc/main/funding`, `.../ranking/{funding,coming-soon,store}`, `.../pc/main/store` | `PLATFORM_MAIN2_API_URL` |
| 홈 큐레이션 hot/like/support/debut | (main2) | `GET /main2/api/v1/curation/{hot,like,support,debut}` | `PLATFORM_MAIN2_API_URL` |
| 카테고리 트렌드 / 랭킹 그룹 | (main2) | `GET /main2/api/v1/pc/main/category/{trends,rankings/groups}` | `PLATFORM_MAIN2_API_URL` |
| 홈 (모바일 9버전) | (main2) | `GET /main2/api/v9/main` (query: `?...`) | `PLATFORM_MAIN2_API_URL` |
| 추천 아이템 / 상세 | (main2) | `GET /main2/api/v1/recommendation/item?type=REWARD|STORE&id=...` | `PLATFORM_MAIN2_API_URL` |
| 리워드 랭킹 | (main2) | `GET /main2/api/v1/ranking/reward` | `PLATFORM_MAIN2_API_URL` |
| 서포트·공유 트렌드 | (main2) | `GET /main2/api/v1/trends?...` | `PLATFORM_MAIN2_API_URL` |
| 최근 본 POST | (main2) | `POST /main2/api/v1/products` | `PLATFORM_MAIN2_API_URL` |
| 펀딩 상세 (로더) | `fundingService.*`, `projectService.*` | `@wadiz/api/web` · `@wadiz/api/web/funding/global` | `WEB_URL` / `PLATFORM_API_URL` 혼합 |
| 펀딩 스토리 | `fundingService.getFundingStoryQuery` (loader) | (확인 불가 — service 파일 내 정의) | `WEB_URL` 류 (추정 금지, service 상세 필요시 별도 확인) |
| 리워드 선택 (`rewards-selection`) | `ordersService.*`, `projectService.*` | `@wadiz/api/web/funding` · `@wadiz/api/web/funding/global` | `WEB_URL` / `PLATFORM_API_URL` |
| 결제 (`/funding/payment`) | `ordersService.createOrderSheet`, `paymentProgressService.*`, `supportersService.getMyLatestShippingAddress/getMyRecentPayBy`, `pointService.getMyPointSummary`, `couponService.getMyUsableCouponList`, `countriesService.*` | 각 service 파일에 정의 (대부분 `WEB_URL`) | `WEB_URL` 중심 |
| 결제 (Nicepay 초기화) | `nicepayService.authInit`, `submitAlipayWithNicepay`, `reserveSetup` | `@wadiz/api/platform/nicepay.service.ts` | `PLATFORM_API_URL` |
| 결제 (Zero pay) | `ordersService.payZero` | `WEB_URL` 기반 | `WEB_URL` |
| 마이와디즈 펀딩 내역 | `fundingService.*` | — | `WEB_URL` |
| 마이와디즈 주문 상세 `[orderNo]` | `backingPaymentService.getRewardPurchaseInfoQuery`, `campaign/fundingStatus/supporterDetail/maker/...Service.*` | `@wadiz/api/web/reward/*`, `@wadiz/api/web/*` | `WEB_URL` |
| 마이와디즈 포인트 | `pointService.*` | `@wadiz/api/web/point.service.ts` | `WEB_URL` |
| 마이와디즈 메이커 | `main2Service.*`, `fundingService.*` | 혼합 | `PLATFORM_MAIN2_API_URL` + `WEB_URL` |
| 마이와디즈 쿠폰 | `couponService.*` | `@wadiz/api/web/reward/coupon.service.ts` | `WEB_URL` |
| 마이와디즈 설정 — 닉네임/비번/이메일/SNS/전화 | `accountService.*` (web), `userService.*`, `socialService.*` | `@wadiz/api/web/account.service.ts`, `user.service.ts`, `social.service.ts` | `WEB_URL` |
| 친구·팔로잉·팔로워 (`/social/*`) | `socialService.*`, `makerService.*`, `friendsService.*` | `@wadiz/api/web/social.service.ts`, `maker.service.ts`, `@wadiz/api/friends/friends.service.ts` | 혼합 (`WEB_URL`, `SERVICE_API_URL`) |
| 검색 (`/search`) | `searchService.*`, `searcherService.*` | `GET /api/search/v2/funding`, `.../v2/preorder`, `.../v2/fundingSoon`, `.../v3/integrate` | `SERVICE_API_URL` |
| 위시 (`/wish`) | `wishService.getWishProjectsV2InfiniteQuery`, `endingsoon` | `/wish/api/v2/wish`, `/wish/api/v1/wish/endingsoon` | `PLATFORM_API_URL` |
| 컬렉션 배너 (펀딩/메이커 스토리 배너) | `collectionService.*` | `@wadiz/api/collection` | `PLATFORM_API_URL` |
| 알림 (`/notifications`) | `notificationService.*` | `@wadiz/api/platform/notification.service.ts` | `PLATFORM_API_URL` |
| 마케팅 수신 동의 | `marketingService.*`, `marketingconsentsService.*` | `@wadiz/api/web/term/marketing`, `@wadiz/api/platform/marketingconsents.service.ts` | `WEB_URL` / `PLATFORM_API_URL` |
| 인박스 — 메이커 문의 | `inboxService.*` | `@wadiz/api/inbox/inbox.service.ts`, `@wadiz/api/platform/inbox.service.ts` | `PLATFORM_API_URL` |
| 메이커 팔로우 | `makerService.*` | — | `WEB_URL` |
| 커뮤니티·리뷰 | `commentsService.*`, `satisfactionService.*`, `issueReportService.*` | `@wadiz/api/web/reward/*` | `WEB_URL` |
| 신고 (ProjectReport) | `issueReportService.*` | — | `WEB_URL` |
| 환불 | `refundService.*`, `backingPaymentService.*`, `shipmentService.*`, `deliveryService.*` | `@wadiz/api/web/reward/*` | `WEB_URL` |
| 결제 전/후 보내기(`support-share`) | `supportShareService.*` | `@wadiz/api/web/support-share.service.ts` | `DATA_API_URL` (`datasvc.wadiz.kr`) — baseUrl fallback `DATA_DOMAIN_URL[ENVIRONMENT]` |
| 고객센터 티켓 목록 (`/support/requests`) | `supportService.getTickets` | `GET /api/v1/support/tickets` (Bearer accessToken) | `APP_API_URL` (`app.wadiz.kr` = `app-api`) |
| 고객센터 티켓 상세 (`/support/requests/[requestId]`) | `supportService.getTicket`, `putTicket`, `uploads`, `postTicket` | `/api/v1/support/tickets/*` | `APP_API_URL` |
| 고객센터 신규 티켓 (폼·업로드) | `supportService.getTicketForms`, `postUploads` | — | `APP_API_URL` |
| 고객센터 — 내 펀딩/스토어 리스트 | `fundingService.*` (myfunding) | `@wadiz/api/web/myfunding.service.ts` | `WEB_URL` |
| 친구 초대 (`/refer-a-friend`) | `inviteService.getInviteEventInfoQuery`, `getInviteReceivedEventInfoQuery` | `@wadiz/api/web/event/*` | `WEB_URL` |
| 소싱 클럽 폼 (`/sourcing-club`) | (useSourcingClubForm은 폼 밸리데이션만, 실 submit service 미확인) | — | 확인 불가 |
| 소싱 클럽 상태 | `sourcing-club.service` | `@wadiz/api/web/sourcing-club.service.ts` | `WEB_URL` |
| 정책 (`/policies`) | `termsService.getTermsQuery`, `getTermsNavbarQuery` | `@wadiz/api/terms` | `WEB_URL` |
| 국가 리스트 (결제·배송지) | `countriesService.*` | `GET /web/v1/countries?...` | `WEB_URL` |
| 로그인 리턴 URL | `accountService.getReturnUrl` | `GET /web/login/return_url` | `WEB_URL` |
| 정산일 계산기 | `settlementService.*` | `@wadiz/api/web/settlement.service.ts` | `WEB_URL` |
| 메이커 스토리 배너 / 뉴스 | `collectionService`, `fundingService(news)` | `@wadiz/api/collection`, `@wadiz/api/web` | `PLATFORM_API_URL` / `WEB_URL` |
| 퀵메뉴 | `quickMenuServices` | `@wadiz/api/web/quick-menu.services.ts` | `WEB_URL` |
| 번역 (`translate.service`) | `translateService.*` (Bearer `PLATFORM_GLOBAL_API_TOKEN`) | `/global/translate/...` 류 | `PLATFORM_GLOBAL_API_URL` |
| 환율 (`exchange-rate.service`) | `exchangeRateService.*` | `/global/exchange-rate/...` | `PLATFORM_GLOBAL_API_URL` |
| 친구 검색 (친구 찾기) | `friendsService.*` | `@wadiz/api/friends/friends.service.ts` | `SERVICE_API_URL` |
| WAi 챗 히스토리 (`/wai`) | `chatHistoryService.getMessages` | `/v1/chat/sessions/{sessionId}/messages` | `@wadiz/api/wai/chatHistory.service.ts` — `getBaseUrl()` 구현 확인 필요 (확인 불가: 파일 내부 동적) |
| 공공 API (서포터 배너 등) | `publicService.*` | `@wadiz/api/public/*` | `PUBLIC_API_URL` |
| 활동 (활동 카운트) | `activitiesService.*` | `@wadiz/api/activities/*` | `PLATFORM_API_URL` |
| 키워드 서비스 | `keywordService.*` | `@wadiz/api/keyword/keyword.service.ts` | `PLATFORM_API_URL` |

**정적/외부 링크**
- 워케이션 OAuth 링크, 정적 이미지 링크 `process.env.STATIC_URL` 사용.
- `process.env.WEB_URL + '/home'` 홈 버튼 링크 — 레거시 웹으로 돌아가기.

#### 공유 packages 의존성

`apps/global/vite.config.ts:142-164` alias — account 와 거의 동일. 추가로:
- `@wadiz/format` (포맷 유틸)
- `@wadiz/queries` (`withAccessTokenRefresh` 등 — `apps/global/src/pages/support/requests/_api/useTicketsInfiniteQuery.ts:6` 에서 사용)
- `@wadiz/ui` (`MultiFollow`, 기타)

내부 패키지 중요 사용처 샘플:
- `@wadiz/core`: `initRouteMatcher`, `usePresentAction`, `Locale`, `goToLoginPage`, `getAllCookiesSnapshot`
- `@wadiz/features/auto-login`, `@wadiz/features/navigation`
- `@wadiz/metrics`: `Sentry.wrapCreateBrowserRouterV6`
- `@wadiz/app-initializer`: `renderAppWithInitialization`

---

### 2.3 `apps/help-center`

#### 앱 메타

| 항목 | 값 | 비고 |
|---|---|---|
| 빌드 도구 | **Zendesk CLI (`zcli`)** | `apps/help-center/package.json:5-14` |
| 프레임워크 | Handlebars 템플릿 + Zendesk Guide | `.hbs` 파일 21개 |
| 런타임 | Zendesk 호스팅 (`wadiz6256.zendesk.com` live, `wadiz-dev.zendesk.com` dev) |  |
| 진입 HTML | `src/templates/home_page.hbs` (+ 각 페이지별) |  |
| 스크립트 | `src/script.js` — Zendesk DOM 헬퍼, ZAFClient, Messenger 위젯 (266 lines) |  |
| 스타일 | `src/style.css` (SCSS 혼용 허용) |  |
| manifest | `src/manifest.json` — 테마 설정 schema |  |
| 배포 도메인 | `https://helpcenter.wadiz.kr` (live) |  |

#### 환경변수 · upstream 매핑

`apps/help-center/.env.dev`, `apps/help-center/.env.live` — **Zendesk 자격증명만**:

| 환경변수 | dev | live |
|---|---|---|
| `ZENDESK_SUBDOMAIN` | `wadiz-dev` | `wadiz6256` |
| `ZENDESK_EMAIL` | `team.fe@wadiz.kr` | `helpcenter@wadiz.kr` |
| `ZENDESK_API_TOKEN` | `CIh2OayhmR3QlNHq2s0lryF01qw9jKfq8Hckctym` | 상동 |
| `ZENDESK_THEME_ID` | `678e142d-adbd-488a-9a69-8dfc5f39c28c` | `73e893a6-ba60-45e7-a679-08105fc68f8b` |

**주의**: `.env.dev`/`.env.live` 는 `scripts/zendesk-login.sh` 에서 로컬 ZCLI 로그인에만 사용하며, 프론트엔드 빌드에는 주입되지 않습니다.

**upstream 매핑**:
- **Zendesk 내부 API**: 티켓, FAQ, 아티클은 Zendesk Guide/Support 가 자체 엔드포인트 제공. 이 repo 에서 직접 호출하는 JS는 없으며, `ZAFClient.init()` + `client.get('ticket.ticket_form_id')` 형태로 Zendesk 앱 프레임워크를 사용 (`apps/help-center/src/script.js:105-122`).
- **와디즈 본체로의 링크**: `manifest.json` 안에 하드코딩된 URL들:
  - `https://helpcenter.wadiz.kr/hc/ko/categories/6459500660889-서포터` (`:1434`)
  - `https://www.wadiz.kr/web/main` (`:1455`, `:1476`)
  - `https://www.facebook.com/wadiz.funding` (`:2670`)
  - `https://www.instagram.com/wadiz_official/` (`:2691`)

#### 라우트 구조

Zendesk Guide 템플릿 시스템 — 라우팅은 Zendesk 가 처리. 이 repo의 `.hbs` 파일 = 페이지:

| Template | 용도 |
|---|---|
| `home_page.hbs` | 홈 |
| `category_page.hbs` | 카테고리 |
| `section_page.hbs` | 섹션 |
| `article_page.hbs` | FAQ 아티클 |
| `search_results.hbs` | 검색 결과 |
| `new_request_page.hbs` | 신규 문의(티켓) |
| `request_page.hbs` | 단일 티켓 조회 |
| `requests_page.hbs` | 내 티켓 목록 |
| `community_*_page.hbs` | 커뮤니티 (토픽/포스트) |
| `new_community_post_page.hbs` | 신규 커뮤니티 포스트 |
| `subscriptions_page.hbs` | 구독 관리 |
| `user_profile_page.hbs` | 사용자 프로필 |
| `contributions_page.hbs` | 내 기여 |
| `error_page.hbs` | 에러 |
| `header.hbs` / `footer.hbs` | 공통 영역 |
| `document_head.hbs` | `<head>` |
| `custom_pages/` | 추가 커스텀 페이지 |

#### 기능↔API 매핑 테이블

이 앱은 **브라우저에서 wadiz 백엔드로 직접 API를 호출하지 않습니다**. 기능은 전부 Zendesk Guide 내장 기능으로 수행:

| 기능 | 제공 주체 | 주석 |
|---|---|---|
| FAQ 조회·검색 | Zendesk Guide | Handlebars `{{dc ...}}` / `{{t ...}}` |
| 고객 티켓 생성·목록·상세 | Zendesk Support | `new_request_page.hbs` / `request(s)_page.hbs` |
| 커뮤니티 Q&A | Zendesk Gather | `community_*.hbs` |
| 채팅 메신저 | `zE('messenger', 'open')` (`script.js:33`), `zE('messenger:on', 'unreadMessages')` (`:28-30`) | Zendesk Messenger SDK |
| 티켓 폼 분기 | ZAFClient — `client.get('ticket.ticket_form_id')` (`:110-122`) | 특정 `ticketFormId=25534849537561` 일 때 `makerCriteriaContainer` 보이기 |
| 와디즈 메인/카테고리 링크 | manifest URL (위 참조) | 외부 링크 |

**wadiz 본체 연계 주의**: `apps/help-center/CLAUDE.md` 에 따르면 `src/templates/footer.hbs` 는 아래 파일들과 동기화되어야 함 (자동 동기화 아님):
- `packages/widgets/src/korea-footer/ui/FooterContainer/FooterContainer.tsx`
- `packages/widgets/src/korea-footer/ui/FooterMenu/FooterMenu.tsx`
- `apps/global/src/widgets/footer/ui/Footer/Footer.tsx`

#### 공유 packages 의존성

- **없음** (Zendesk 테마는 pnpm workspace 의 `packages/*` 를 import 하지 않음).
- `package.json` devDependencies 는 `stylelint`, `stylelint-config-clean-order` 2개 뿐.

---

### 2.4 `apps/ir`

#### 앱 메타

| 항목 | 값 | 비고 |
|---|---|---|
| 빌드 도구 | Next.js 16.1.6 (App Router) + Webpack | `apps/ir/package.json:23` |
| 출력 | `output: 'export'`, `distDir: 'build'` | `apps/ir/next.config.js:20-21` |
| 이미지 최적화 | `unoptimized: true` (CF 앞단 없음) | `:17` |
| 타입체크 | `ignoreBuildErrors: true` (강제 빌드) | `:27` |
| 진입 | `src/app/layout.tsx`, `src/app/(home)/page.tsx` | App Router |
| Dev | `next dev --hostname local.wadiz.kr --webpack --port 3000` | `package.json:11` |
| 배포 | S3 `wadiz.ir.dev` / `wadiz.ir.live` + CloudFront Function (`frontend-rewrite-html-route`) | `README.md:59-65` |
| 배포 도메인 | dev: `https://ir-dev.wadiz.kr`, live: `https://www.wadizcorp.com` |  |

#### 환경변수 · upstream 매핑

4개 env 파일 (`.env`, `.env.development.local`, `.env.production.{dev,local,live}`):

| 환경변수 | live | 용도 | upstream |
|---|---|---|---|
| `NEXT_CONFIG_ASSET_PREFIX` | `https://www.wadizcorp.com` | Next.js assetPrefix | S3/CF (자산) |
| `NEXT_PUBLIC_STATIC_URL` | `https://www.wadizcorp.com` | OG/메타 |  |
| `NEXT_PUBLIC_DATA_URL` | `https://cdn3.wadiz.kr/app` (`.env`) | **IR 데이터 JSON CDN** | CloudFront (외부 CDN) — 원본은 Google Sheets Apps Script 배포 (README.md:67-69) |
| `MOCK_DATA_ENABLE` | `false` (dev only) | 로컬 목데이터 토글 | — |
| `ENVIRONMENT` | `live` | env-cmd 분기 | — |
| `BROWSER` | `false` (dev) | 로컬 서버 자동 브라우저 열기 방지 | — |

→ IR 앱은 **wadiz 백엔드 서비스 호출이 전혀 없음**. 모든 데이터는 Google Sheets → Apps Script → `cdn3.wadiz.kr/app/*.json` 로 흘러간 **정적 JSON** 을 fetch.

#### 라우트 구조

Next.js App Router (`src/app/*/page.tsx`):

| 경로 | 파일 |
|---|---|
| `/` | `app/(home)/page.tsx` |
| `/information` | `app/information/page.tsx` (+ `template.tsx`) |
| `/information/about` | `app/information/about/page.tsx` |
| `/information/ceo-message` | `app/information/ceo-message/page.tsx` |
| `/information/history` | `app/information/history/page.tsx` |
| `/information/esg` | `app/information/esg/page.tsx` |
| `/information/corporate-governance` (+ `/committee`, `/board-of-directors`, `/stockholders-meeting`, `/subsidiary`) | `app/information/corporate-governance/*/page.tsx` |
| `/financial-information` (+ `/consolidated-financial-statement`, `/audit-report`) | `app/financial-information/*/page.tsx` |
| `/ir-information` (+ `/reference-room`, `/disclosure-information`, `/announcement`) | `app/ir-information/*/page.tsx` |

뷰는 `src/views/*` 에 동일한 트리로 분리 (예: `views/ir-information/disclosure-information/DisclosureInformationPage.tsx`).

#### 기능↔API 매핑 테이블

`apps/ir/src/entities/*/api/get*.ts` 14개 파일 — 모두 동일 패턴:

```ts
// apps/ir/src/entities/announcement/api/getAnnouncements.ts:32-34
const response = await fetch(`${process.env.NEXT_PUBLIC_DATA_URL}/announcements.json`);
const data = await response.json();
```

| 화면/기능 | 엔드포인트 (GET) | 원본 | Upstream |
|---|---|---|---|
| 홈 — 주요 뉴스 | `{NEXT_PUBLIC_DATA_URL}/top-news-list.json` | `top-news/api/getTopNews.ts:18` | `cdn3.wadiz.kr/app` (Google Sheets Apps Script 산출) |
| 홈 — 대표 프로젝트 | `{DATA_URL}/representative-projects.json` | `project/api/getProjects.ts:31` | 상동 |
| 공시 공고 | `{DATA_URL}/announcements.json` | `announcement/api/getAnnouncements.ts:33` | 상동 |
| 공시 감사보고서 | `{DATA_URL}/audit-reports.json` | `report/api/getReports.ts:33` | 상동 |
| 공시 정보(공시보고서) | `{DATA_URL}/disclosure-reports.json` | `report/api/getReports.ts:52` | 상동 |
| 이사회 구성원 | `{DATA_URL}/directors.json` (추정 — `getDirectors.ts`) | `director/api/getDirectors.ts` | 상동 |
| 위원회 | `{DATA_URL}/committees.json` | `committee/api/getCommittees.ts` | 상동 |
| 자회사 | `{DATA_URL}/subsidiaries.json` | `subsidiary/api/getSubsidiaries.ts` | 상동 |
| 주주총회 | `{DATA_URL}/meetings.json` | `meeting/api/getMeetings.ts` | 상동 |
| 주주 구성 | `{DATA_URL}/stockholders.json` | `stockholder/api/getStockholders.ts` | 상동 |
| 재무제표 | `{DATA_URL}/statements.json` | `statement/api/getStatements.ts` | 상동 |
| 참고 자료 | `{DATA_URL}/references.json` | `reference/api/getReferences.ts` | 상동 |
| ESG 목록 | `{DATA_URL}/esg-*.json` | `esg/api/getEsgList.ts` | 상동 |
| 연혁 | `{DATA_URL}/histories.json` | `history/api/getHistories.ts` | 상동 |
| 일반 콘텐츠 | `{DATA_URL}/contents.json` | `content/api/getContents.ts` | 상동 |

모든 함수는 **fetch 실패 시 로컬 `*.json` mock 으로 폴백**합니다 (`if (process.env.NODE_ENV === 'development') ...` + `catch { return mockData }` 패턴).

⚠️ **호출 경로에 wadiz 내부 백엔드 서비스 없음**. CDN + 정적 JSON 만.

#### 공유 packages 의존성

`apps/ir/next.config.js:68-73` webpack alias:
- `@wadiz/waffle-icons`, `@wadiz/waffle` 만 import. `@wadiz/api` 는 **import 하지 않음**.

tsconfig paths / jest.config 은 더 상세하나 실제 소스에서 쓰는 import 는 위 두 개가 중심.

---

### 2.5 `apps/partners`

#### 앱 메타

| 항목 | 값 | 비고 |
|---|---|---|
| 빌드 도구 | Next.js 14.2.14 (App Router) | `apps/partners/package.json:23` |
| 출력 | `output: 'export'`, `distDir: 'build'` | `apps/partners/next.config.js:20-21` |
| 이미지 최적화 | `unoptimized: true` |  |
| 타입체크 | `ignoreBuildErrors: true` |  |
| 진입 | `src/app/layout.tsx`, `src/app/page.tsx`, `src/app/template.tsx` |  |
| Dev | `next dev --hostname local.wadiz.kr` (포트 기본 3000) | `package.json:10` |
| 배포 도메인 | dev: `https://partners-dev.wadiz.kr`, live: `https://partners.wadiz.kr` |  |

#### 환경변수 · upstream 매핑

| 환경변수 | live | 용도 |
|---|---|---|
| `NEXT_CONFIG_ASSET_PREFIX` | `https://partners.wadiz.kr` | Next assetPrefix |
| `NEXT_PUBLIC_STATIC_URL` | `https://partners.wadiz.kr` | OG 메타 |
| `ENVIRONMENT` | `live` | env-cmd |

→ **wadiz 백엔드 호출 없음**. 단일 페이지 정적 랜딩.

#### 라우트 구조

App Router 단일 페이지:
- `/` → `src/app/page.tsx:20-72` — 12개 섹션을 세로 조합 (`KeyVisual`, `Status`, `History`, `Partner`, `Invest`, `HowWeWork`, `NextBrand`, `IRDay`, `Register`, `Portfolio`, `Logo`, `Video`).

섹션 컴포넌트: `src/app/components/{KeyVisualSection, StatusSection, HistorySection, PartnerSection, InvestSection, HowWeWorkSection, NextBrandSection, IRDaySection, RegisterSection, PortfolioSection, LogoSection, VideoSection}/`.

#### 기능↔API 매핑 테이블

| 기능 | 엔드포인트/데이터 소스 | 주석 |
|---|---|---|
| 네비/메뉴 | `src/app/data/menu.ts`, `menu.json` | 정적 TS/JSON |
| 포트폴리오 목록 | `src/app/data/portfolio.ts` | 정적 |
| 연혁 | `src/app/data/history.ts` | 정적 |
| 혜택 | `src/app/data/benefit.ts` | 정적 |
| 로고 | `src/app/data/logo.ts` | 정적 |
| 외부 CTA 링크 | typeform 등 하드코딩 | 외부 |

`fetch(`, `axios`, `useQuery`, `@wadiz/api` — **전체 `src/` 에서 0건 매칭** (Grep 결과 "No files found").

#### 공유 packages 의존성

`apps/partners/next.config.js:61-66` webpack alias:
- `@wadiz/core`
- `@wadiz/waffle-icons`
- `@wadiz/waffle`

`@wadiz/api` 는 import하지 않음.

---

### 2.6 `apps/partnerzone`

#### 앱 메타

| 항목 | 값 | 비고 |
|---|---|---|
| 빌드 도구 | Vite 5 + TSC | `apps/partnerzone/package.json:7-8` |
| 프레임워크 | React 18.2, React Router 6.26, react-query 3.34 (legacy v3) | `:15-30` |
| 진입 | `index.html` → `src/pages/main/index.tsx` → `Main.tsx` |  |
| Base URL | `process.env.BASE_URL \|\| './'` | `vite.config.ts:10` |
| 배포 도메인 | dev: `https://static-dev.wadiz.kr/partnerzone` live: `https://static.wadiz.kr/partnerzone` (배포는 S3) |  |
| 공개 경로 | WordPress 임베드 `https://partnerzone.wadiz.kr/wp-admin` → 콘텐츠 영역에 `{{https://static.wadiz.kr/partnerzone/index.html}}` 임베드 (`README.md:59-62`) |  |

특이: `fetchApi: link:@wadiz/fetch-api/src/fetchApi` 의존성(`package.json:18`) 이 있지만 실제 소스에서 import 한 흔적은 없음. 빌드에서 external 처리 (`vite.config.ts:31` — `@wadiz/request-api/errors/JsonParseError` 등 external).

#### 환경변수 · upstream 매핑

| 환경변수 | live |
|---|---|
| `BASE_URL` | `https://static.wadiz.kr/partnerzone` |
| `ENVIRONMENT` | `live` |

→ wadiz 백엔드 호출 없음. Vite 번들을 S3 에 올리고 WordPress 가 iframe/임베드.

#### 라우트 구조

BrowserRouter 로 감쌌으나 라우트는 **단일 `<Main />` 페이지** 하나 (`src/pages/main/index.tsx:9-15`).

`Main.tsx:7-35` 섹션 구성: `KeyVisual`, `Partner`, `WhyWadiz`, `Usage`, `FAQ`, `Footer`. 네비게이션은 탭 기반 스크롤 (`useTabNavigation`).

#### 기능↔API 매핑 테이블

| 기능 | 엔드포인트/데이터 소스 | 주석 |
|---|---|---|
| 네비게이션 아이템 | `src/data/navigation.ts` | 정적 |
| FAQ | `src/data/faq.ts` | 정적 |
| 기타 텍스트 | `src/data/data.js` | 정적 |
| KV Typeform CTA | `https://wadiz.typeform.com/partnerservice?utm_source=partnerzone&utm_medium=main` | 외부 SaaS 링크 (`Main.tsx:11-12`) |
| Lottie 애니메이션 JSON | `fetch(animationUrl)` → `response.json()` | `utils/useLottieObserver.ts:56-58` — 인자로 받은 임의 URL (정적 자산 추정) |

Wadiz 내부 백엔드 호출 **0건**.

#### 공유 packages 의존성

`apps/partnerzone/vite.config.ts:62-71` alias:
- `@wadiz/artworks`
- `@wadiz/metrics` (→ `packages/core/src/metrics`)
- `@wadiz/utils` (→ `packages/core/src/utils`)
- `@wadiz/waffle`, `@wadiz/waffle-icons`

`@wadiz/api` 없음.

---

## 3. 전체 Upstream 매트릭스

각 앱이 어떤 환경변수를 통해 어떤 wadiz 서비스(또는 외부)에 호출을 보내는지 요약. ✅ = 앱 코드에서 관측된 호출, ⚪ = 환경변수는 있으나 이 repo 내 호출 미관측, ❌ = 해당 없음.

| Upstream (env 기준) | 매핑 서비스 repo | `account` | `global` | `help-center` | `ir` | `partners` | `partnerzone` |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|
| `VITE_ACCOUNT_URL` → `account.wadiz.kr` | `kr.wadiz.account` | ✅ 메인 | ⚪ (로그인 링크) | ❌ | ❌ | ❌ | ❌ |
| `VITE_WEB_URL` → `www.wadiz.kr` | `com.wadiz.web` (JSP) | ✅ (탈퇴, 약관, 리턴URL, countries, SMS) | ✅ (대부분 — 펀딩/마이/고객센터 일부/쿠폰/포인트/약관/정책/국가/소셜) | ⚪ (링크만) | ❌ | ❌ | ❌ |
| `VITE_APP_API_URL` → `app.wadiz.kr` | `app-api` (NestJS) | ⚪ | ✅ (고객센터 `/api/v1/support/tickets` 등) | ❌ | ❌ | ❌ | ❌ |
| `VITE_PLATFORM_API_URL` → `platform.wadiz.kr` | 플랫폼 게이트웨이 | ⚪ | ✅ (위시, 알림, 인박스, 마케팅동의, 컬렉션, nicepay, keyword, activities) | ❌ | ❌ | ❌ | ❌ |
| `VITE_PLATFORM_MAIN2_API_URL` → `platform.wadiz.kr` (main2/*) | main2 서비스 | ❌ | ✅ (홈, 랭킹, 큐레이션, 카테고리, mywadiz) | ❌ | ❌ | ❌ | ❌ |
| `VITE_PLATFORM_GLOBAL_API_URL` → `platform.wadiz.kr/global` | 글로벌 번역/환율 | ⚪ | ✅ (번역, 환율 — Bearer Token) | ❌ | ❌ | ❌ | ❌ |
| `VITE_SERVICE_API_URL` → `service.wadiz.kr` | 서비스 레이어 (검색·친구) | ⚪ | ✅ (search v2/v3, friends) | ❌ | ❌ | ❌ | ❌ |
| `VITE_PUBLIC_API_URL` → `public-api.wadiz.kr` | 퍼블릭 API | ⚪ | ✅ (publicService, makerBanner) | ❌ | ❌ | ❌ | ❌ |
| `VITE_DATA_API_URL` → `datasvc.wadiz.kr` | Data/Analytics | ❌ | ✅ (support-share) | ❌ | ❌ | ❌ | ❌ |
| `VITE_ANALYTICS_URL` → `analytics.wadiz.kr` | Analytics | ⚪ (global 변수) | ⚪ (global 변수) | ❌ | ❌ | ❌ | ❌ |
| `VITE_STATIC_URL` / `NEXT_PUBLIC_STATIC_URL` | S3/CloudFront | ⚪ (이미지 링크) | ✅ (이미지, 앱 링크 등) | ⚪ (자산) | ⚪ (자산) | ⚪ (자산) | ✅ (BASE_URL) |
| `NEXT_PUBLIC_DATA_URL` → `cdn3.wadiz.kr/app` | CloudFront → Google Sheets Apps Script | ❌ | ❌ | ❌ | ✅ (IR JSON 14종) | ❌ | ❌ |
| Zendesk API | Zendesk Cloud | ❌ | ❌ | ✅ (내장, ZAFClient) | ❌ | ❌ | ❌ |
| Braze SDK | Braze Cloud | ✅ (초기화) | ⚪ (환경변수 정의, `main.tsx` 초기화 확인 필요) | ❌ | ❌ | ❌ | ❌ |
| Sentry | Sentry Cloud | ✅ (vite plugin) | ✅ (`Sentry.wrapCreateBrowserRouterV6`) | ❌ | ❌ | ❌ | ❌ |
| Supabase | Supabase Cloud | ❌ | ⚪ (env 정의, 실제 import 미관측) | ❌ | ❌ | ❌ | ❌ |
| Typeform | Typeform | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (CTA 링크) |
| Google Maps API | Google Cloud | ⚪ (SDK 로드) | ⚪ (SDK 로드) | ❌ | ❌ | ❌ | ❌ |
| Stripe | Stripe | ⚪ (SDK) | ⚪ (SDK) | ❌ | ❌ | ❌ | ❌ |

### 호출 패턴 요약
- **`global`** 이 가장 많은 upstream 과 통신. `main2`, `platform`, `service`, `public`, `app-api`, `web`, `datasvc` 등 거의 모든 백엔드.
- **`account`** 는 `account` 서버 + 레거시 `web` 의 약관·탈퇴·SMS·countries 만.
- **`help-center`, `ir`, `partners`, `partnerzone`** 은 wadiz 내부 RESTful API 호출이 거의 없음 (자산 링크·CDN JSON·외부 SaaS 한정).

---

## 4. `@wadiz/api` 서비스 파일 — 관측된 엔드포인트 전수

아래는 `packages/api/src/**/*.service.ts` 중 위 6개 앱이 **실제로 import 하는** 파일들에서 `GET/POST/PUT/PATCH/DELETE` 호출로 관측한 엔드포인트입니다. baseUrl 은 각 서비스 파일 상단의 `process.env.*` 치환 결과 기준. 추가 파라미터/Body 타입은 각 파일 참조 — 여기서는 **URL + 메서드** 만 정리합니다.

### 4.1 `account/account.service.ts` (baseUrl = `ACCOUNT_URL`)

| Method | Path | 용도 | 호출 위치 |
|---|---|---|---|
| POST | `/api/v2/authentication-code` | 이메일 인증번호 발송 | `apps/account` login / signup |
| GET | `/api/v2/authentication-code/{code}/valid` | 인증번호 확인 | 동일 |
| POST | `/api/v1/users` | 이메일 회원가입 | `apps/account` signup |
| POST | `/api/v1/social-users` | 소셜 회원가입 | `apps/account` social-signup |
| POST | `/api/v1/link-users` | 소셜 계정 연동 | `apps/account` social-link |
| GET | `/api/v1/signup-information` | 가입 정보 조회 (joinType/providerType/social) | `apps/account` social-signup |
| GET | `/api/v1/user-login-status` | 로그인 상태 | `apps/account` shared/api, `apps/global` (예상) |
| GET | `/api/v1/authorization-register/kakao?rememberme=on\|off` | 카카오 OAuth 파라미터 | `apps/account` login |
| POST | `/api/v1/find-id` | 아이디 찾기 | `apps/account` find/login |

→ 총 9 엔드포인트 × 1 upstream (`kr.wadiz.account`).

### 4.2 `web/account.service.ts` (baseUrl = `WEB_URL` → `com.wadiz.web`)

| Method | Path | 용도 |
|---|---|---|
| GET | `/web/account/isLoggedIn` | 로그인 여부 + UserInfo |
| GET | `/web/v3/account` | 내 계정 정보 |
| PUT | `/web/v3/account/nickname` | 닉네임 변경 |
| POST | `/web/v3/account/email/code` | 이메일 변경 인증 코드 요청 |
| PUT | `/web/v3/account/email` | 이메일 변경 확정 |
| POST | `/web/v3/account/password/verification` | 비밀번호 검증 |
| POST | `/web/v3/account/password` | 비밀번호 설정 |
| PUT | `/web/v3/account/password` | 비밀번호 변경 |
| POST | `/web/v3/account/profile-image` | 프로필 이미지 업로드 |
| DELETE | `/web/v3/account/profile-image` | 프로필 이미지 삭제 |
| GET | `/web/v3/account/phone-number` | 휴대폰 번호 조회 |
| PUT | `/web/v3/account/phone-number` | 휴대폰 번호 변경 |
| POST | `/web/v3/account/phone-number/code` | 휴대폰 번호 인증 코드 |
| GET | `/web/v3/account/dropout/availability` | 탈퇴 가능 여부 |
| POST | `/web/v3/account/dropout/code` | 탈퇴 인증코드 발송 |
| POST | `/web/v3/account/dropout/code/verification` | 탈퇴 인증코드 검증 |
| GET | `/web/v3/account/sns-links` | 연동된 SNS 목록 |
| DELETE | `/web/v3/account/sns-links/{provider}` | SNS 연동 해제 |
| GET | `/web/login/return_url` | 로그인 후 복귀 URL |
| POST | `/web/waccount/ajaxRequestSendUserAuthSmsCorpManager?mobileNumber=...` | 기업 담당자 SMS 발송 |
| POST | `/web/waccount/ajaxRequestUserSmsCorpManagerConfirm?...` | 기업 담당자 SMS 확인 |
| GET | `/web/account/adult-verification/my` | 성인 인증 상태 |
| PUT | `/web/account/adult-verification/my` | 성인 인증 확인 |

→ 23 엔드포인트. `apps/account` (탈퇴, 리턴URL, 핸드폰 인증) + `apps/global` (마이와디즈 설정·프로필, 성인인증) 에서 사용.

### 4.3 `app/support.service.ts` (baseUrl = `APP_API_URL` → `app-api`/NestJS)

| Method | Path | 용도 |
|---|---|---|
| GET | `/api/v1/support/tickets` | 티켓 목록 |
| GET | `/api/v1/support/tickets/{ticketId}` | 티켓 상세 |
| POST | `/api/v1/support/tickets` | 티켓 생성 |
| PUT | `/api/v1/support/tickets/{ticketId}` | 티켓 수정 |
| GET | `/api/v1/support/ticket-forms` | 티켓 폼 목록 |
| POST | `/api/v1/support/uploads` | 첨부 업로드 |
| DELETE | `/api/v1/support/uploads/{token}` | 첨부 삭제 |

→ 7 엔드포인트. `apps/global` 의 `/support/requests/*` 페이지에서 사용 (accessToken Bearer).

### 4.4 `wish/wish.service.ts` (baseUrl = `PLATFORM_API_URL`)

| Method | Path | 용도 |
|---|---|---|
| GET | `/wish/api/v2/wish` | 위시 프로젝트 목록 v2 |
| GET | `/wish/api/v1/wish` | 위시 프로젝트 목록 v1 |
| GET | `/wish/api/v2/curation` | 위시 큐레이션 |
| GET | `/wish/api/v1/wish/endingsoon` | 마감 임박 |

→ 4 엔드포인트. `apps/global` `/wish` 페이지.

### 4.5 `collection/collection.service.ts` (baseUrl = `PLATFORM_API_URL`)

| Method | Path | 용도 |
|---|---|---|
| GET | `/collection/api/v2/banner/{projectType}/{projectNo}` | 전시 배너 |
| GET | `/collection/api/v2/events/open` | 진행 중 이벤트 |
| GET | `/collection/api/v2/events` | 이벤트 목록 |
| GET | (동적 api path) | 상세 컨텐츠 |

→ 4 엔드포인트. `apps/global` `news-banner`, `exhibition-banner` 위젯.

### 4.6 `platform/notification.service.ts` (baseUrl = `PLATFORM_API_URL`)

| Method | Path | 용도 |
|---|---|---|
| PUT | `/noti-channel/v2/marketingconsents?serviceCode={code}` | 알림 채널 동의 변경 |
| GET | `/noti-channel/v2/marketingconsents` | 알림 채널 동의 조회 |

→ 2 엔드포인트. `apps/global` marketing-agreement.

### 4.7 `platform/marketingconsents.service.ts` (baseUrl = `PLATFORM_API_URL`)

관측 위치 2건 (`:39`, `:51`) — 엔드포인트 경로는 파일 추가 확인 필요. `apps/global` 마케팅 동의.

### 4.8 `platform/share.service.ts` (baseUrl = `PLATFORM_API_URL`)

관측 위치 1건 (`:39`) — `apps/global` 공유 기능.

### 4.9 `platform/nicepay.service.ts` (baseUrl = `PLATFORM_API_URL`)

| Method | Path | 용도 |
|---|---|---|
| POST | `/nicepay-api/api/v2/auth/init/{pathSuffix}` | 나이스페이 인증 초기화 (pathSuffix 예: alipay) |
| POST | `/nicepay-api/api/v2/reserve/setup` | Stripe Setup 예약 |
| GET | `/nicepay-api/v2/installment-guides/longTermInstallment` | 장기할부 가이드 |

→ 3 엔드포인트. `apps/global` 결제 페이지 (Alipay, Stripe Setup 경로).

### 4.10 `platform/inbox.service.ts` (baseUrl = `PLATFORM_API_URL`)

관측 위치 4건 (`:75, :102, :119, :136`) — 엔드포인트 세부 확인 필요.

### 4.11 `inbox/inbox.service.ts` (baseUrl = `PLATFORM_API_URL` 추정)

| Method | Path | 용도 |
|---|---|---|
| GET | `/inbox/v4/messages/count-unread` | 미확인 메시지 수 |
| GET | `/web/board/personalMessage/inbox/host` | 메이커 인박스 |
| GET | `/web/board/personalMessage/inbox/personal` | 개인 인박스 |
| POST | (동적) | 메시지 북마크 |
| GET | `/web/board/personalMessage/isAgreed` | 인박스 약관 동의 여부 |
| POST | `/web/board/personalMessage/isAgreed` | 동의 처리 |
| GET | (동적) | 인박스 초기 정보 |
| GET | (동적) | 인박스 메시지 페이징 |
| POST | (동적) | 메시지 발송 |
| GET | (동적) | 인박스 펀딩 정보 |
| POST | (동적) | 이미지 업로드 |

→ 11 호출점. `apps/global` `features/inquiries-maker/*`. host/personal 경로 분기 확인됨.

### 4.12 `activities/activities.service.ts` (baseUrl = `PLATFORM_API_URL`)

관측 위치 1건 — POST `WishProjectsRequest` 형태. `apps/global` 활동 카운트.

### 4.13 `friends/friends.service.ts` (baseUrl = `SERVICE_API_URL`)

관측 위치 1건 (`:26`) — `apps/global` 친구 검색.

### 4.14 `search/*.service.ts` (baseUrl = `SERVICE_API_URL`)

| 파일 | Method | Path |
|---|---|---|
| `search/home.service.ts` | GET | `/api/search/v3/home` |
| `search/integrate.service.ts` | POST | `/api/search/v3/integrate` (경로 동적) + 추가 POST |
| `search/search.service.ts` | GET | `/api/search/v2/categories` |
| `search/search.service.ts` | GET | `/api/search/v2/products?...` |
| `search/search.service.ts` | POST | `/api/search/store` |
| `search/search.service.ts` | POST | `/api/search/v2/funding` |
| `search/search.service.ts` | POST | `/api/search/v2/preorder` |
| `search/search.service.ts` | POST | `/api/search/v2/fundingSoon` |
| `search/search.service.ts` | POST | (추가 ServiceHome 엔드포인트들) |

→ `apps/global` 검색 페이지/컴포넌트.

### 4.15 `searcher/searcher.service.ts` (baseUrl = `SERVICE_API_URL`)

관측 위치 1건 (`:42`) — `apps/global` 자동완성/검색 추천.

### 4.16 `keyword/keyword.service.ts` (baseUrl = `PLATFORM_API_URL`)

관측 위치 1건 — 키워드 서비스. `apps/global`.

### 4.17 `wadizad/wadizad.service.ts` (baseUrl = `PLATFORM_MAIN2_API_URL`)

관측 위치 1건 (`:33`) — 와디즈 AD 관련.

### 4.18 `main2/main2.service.ts` (baseUrl = `PLATFORM_MAIN2_API_URL`) — `apps/global` 홈의 핵심

| Method | Path | 용도 |
|---|---|---|
| GET | `/main2/api/v1/pc/main/key-visual` | PC 메인 키비주얼 |
| GET | `/main2/api/v1/quickmenu?id={id}` | 퀵메뉴 |
| GET | `/main2/api/v1/pc/main/metrics` | PC 메인 메트릭 |
| POST | `/main2/api/v1/recentview` (동적) | 최근 본 조회 |
| POST | `/main2/api/v1/products` | 최근 본 등록 |
| GET | `/main2/api/v1/pc/main/funding` | PC 메인 펀딩 |
| GET | `/main2/api/v1/pc/ranking/funding` | PC 펀딩 랭킹 |
| GET | `/main2/api/v1/pc/ranking/coming-soon` | 공개예정 랭킹 |
| GET | `/main2/api/v1/pc/ranking/store` | 스토어 랭킹 |
| GET | `/main2/api/v1/pc/main/store` | PC 메인 스토어 |
| GET | `/main2/api/v1/curation/hot` | 핫 큐레이션 |
| GET | `/main2/api/v1/curation/like` | 관심 큐레이션 |
| GET | `/main2/api/v1/curation/support` | 서포트 큐레이션 |
| GET | `/main2/api/v1/curation/debut` | 신규 큐레이션 |
| GET | `/main2/api/v1/pc/main/category/trends` | 카테고리 트렌드 |
| GET | `/main2/api/v1/pc/main/category/rankings/groups` | 카테고리 랭킹 그룹 |
| GET | `/main2/api/v9/main` | 모바일 메인 v9 |
| GET | `/main2/api/v8/main?{queryParams}` | 메인 v8 (추가 파라미터) |
| GET | `/main2/api/v1/recommendation/item?type=REWARD\|STORE&id=...` | 추천 아이템 |
| GET | `/main2/api/v1/recommendation/item/detail?type=...&id=...` | 추천 아이템 상세 |
| GET | `/main2/api/v1/ranking/reward` | 리워드 랭킹 |
| GET | `/main2/api/v1/trends?{queryString}` | 공유 트렌드 |

→ 22 관측 엔드포인트. `apps/global` 홈, 랭킹, 큐레이션 전반.

### 4.19 `main2/mywadiz.service.ts` (baseUrl = `PLATFORM_MAIN2_API_URL`)

관측 위치 3건 (`:239, :247, :292`) — `apps/global` 마이와디즈. 세부 경로 파일 내 추가 확인 필요.

### 4.20 `platform/global/translate.service.ts` (baseUrl = `PLATFORM_GLOBAL_API_URL`, Bearer `PLATFORM_GLOBAL_API_TOKEN`)

| Method | 개요 |
|---|---|
| POST | 텍스트 번역 요청 |
| POST | 번역 텍스트 (응답 타입 `TranslateTextResponse`) |

Fallback 로직: `getBaseUrl()` 이 env 없으면 live/dev 도메인 분기.

### 4.21 `platform/global/exchange-rate.service.ts` (baseUrl = `PLATFORM_GLOBAL_API_URL`, Bearer Token)

| Method | Path |
|---|---|
| GET | `/exchange-rates` |
| GET | `/exchange-rates/{countryCode}` |

### 4.22 `public/{main,public}.service.ts` (baseUrl = `PUBLIC_API_URL`)

| Method | Path |
|---|---|
| GET | `/main/info/{sectionCode}` |
| GET | `main/info/{sectionCode}` (상대) |

→ `apps/global` 메이커 배너, 메인 섹션 정보.

### 4.23 `app/settings.service.ts` (baseUrl = `APP_API_URL`)

관측 위치 1건 (`:209`) — `AppSettingsFeature` 열거형에 따라 설정 조회. Feature 예: `app-install-promotion`, `bnbStoreTab`, `funding-story-api`, `walink`, `queue-enabled-projects`.

### 4.24 `app/links.service.ts` (baseUrl 혼합: `STATIC_URL`, `APP_API_URL`, `APP_API_DOMAIN[ENV]`)

관측 위치 3건 (`:18, :32, :50`). 앱 링크 / 와링크.

### 4.25 `app/funding/projects.service.ts` (baseUrl = **하드코딩** `https://app.wadiz.kr`)

관측 위치 2건 (`:21, :35`). app-api 호출이지만 환경 변수 미사용 (live 도메인 하드코딩 — dev/rc 환경에서 동작 확인 불가).

### 4.26 `terms/terms.service.ts` (baseUrl = `WEB_URL`)

| Method | Path |
|---|---|
| GET | `{WEB_URL}/resources/terms/{name}.html` (fetch 직접) |
| GET | `{WEB_URL}{urlObj.pathname}` (동적 URL 재작성) |

→ `apps/global`, `apps/account` 약관 본문 로드.

### 4.27 `web/countries.service.ts`

| Method | Path |
|---|---|
| GET | `{WEB_URL}/web/v1/countries?...` |

→ `apps/account`, `apps/global` 국가 리스트 (결제·배송지).

### 4.28 `web/support-share.service.ts` (baseUrl = `DATA_API_URL`)

관측 위치 2건 (`:576, :593`). `datasvc.wadiz.kr`. `apps/global` 서포트·공유 지표.

### 4.29 `web/reward/*` (baseUrl = `WEB_URL` 기본, `SERVICE_API_URL` 일부)

`apps/global` 리워드 관련 대부분:
- `backing-payment.service.ts` — 주문 결제 정보
- `campaign.service.ts` — 캠페인
- `comments.service.ts` — 커뮤니티 댓글
- `coupons_owners_my.ts` (mock) — 쿠폰
- `delivery.service.ts` — 배송
- `funding.service.ts` — 펀딩 리워드
- `issue-report.service.ts` — 신고
- `maker.service.ts` — 메이커
- `my_changeable_payment_info.ts` (mock) — 변경 가능 결제
- `satisfaction.service.ts` — 만족도
- `shipment.service.ts` — 배송
- `supporter-club.service.ts` — 서포터 클럽 (`WEB_URL` + `SERVICE_API_URL` 혼용)
- `type.ts` — PayStatus enum

세부 엔드포인트 URL 은 각 파일별 확인 필요 (상당수 파일이 아직 Grep 미완).

### 4.30 `web/*.service.ts` (apps/global 에서 폭넓게 사용)

- `funding.service.ts` — 펀딩 상세 조회
- `join.service.ts` — 가입 프로세스
- `maker-proxy.service.ts` — 메이커 프록시
- `maker.service.ts` — 메이커
- `myfunding.service.ts` — 내 펀딩 내역
- `payment.service.ts` — 결제
- `point.service.ts` — 포인트
- `settlement.service.ts` — 정산
- `sign-up.service.ts` — 가입
- `social.service.ts` — 소셜 활동 (팔로우/차단)
- `sourcing-club.service.ts` — 소싱 클럽
- `store.service.ts` — 스토어
- `support-share.service.ts` — 공유
- `term/marketing.service.ts` — 마케팅 약관
- `user.service.ts` — 사용자 정보
- `quick-menu.services.ts` — 퀵메뉴

### 4.31 `makercenter/makercenter.service.ts`

관측 위치 확인 필요. `apps/global/pages/my-wadiz/maker/*` 에서 사용 가능.

### 4.32 `oauth/oauth.service.ts`

`apps/global/entities/oauth/*` 에서 사용 가능. 세부 미확인.

### 4.33 `wai/chatHistory.service.ts`

`apps/global/features/wai/hooks/useWAiChatHistory.ts`. baseUrl 은 `getBaseUrl()` 동적 — 세부 미확인.

### 4.34 `wadizad/wadizad.service.ts` (baseUrl = `PLATFORM_MAIN2_API_URL`)

관측 위치 1건. 메인 화면 광고 큐레이션 추정.

---

## 5. 경계 및 미탐색 영역

### 본 문서가 다루지 않는 것
- `packages/api/src/**/*.service.ts` 내부 엔드포인트 전수 목록: 본 문서는 **앱별 import·사용처** 관점의 요약. 서비스 파일 전수 목록은 별도 분석이 필요합니다 (파일 수가 많음 — 예: `main2.service.ts` 1600줄 이상, `search.service.ts` 500줄 이상).
- `packages/queries`, `packages/features`, `packages/widgets` 등 공유 패키지 내부의 비즈니스 로직과 추가 API 호출. 예: `packages/features/*/api/*.ts` 에 숨어있는 호출은 별도 스윕 필요.
- `apps/global` 의 `korea-main.tsx` 국내 재사용 모드에서 **`com.wadiz.web` 의 JSP 가 어떻게 SPA를 임베드하는지의 HTML-레벨 결합** 관측은 `com.wadiz.web` 레거시 쪽 작업.
- `help-center` 내 **Zendesk 자체의 API** (티켓/FAQ 생성 등) 엔드포인트: 이 repo 는 Zendesk 제공 JS (`zE`, `ZAFClient`) 를 호출할 뿐이므로 Zendesk 에 보내는 HTTP 트래픽은 Zendesk SDK 내부 구현이며 관측 불가.
- `apps/global/.env-cmdrc` 내 `VITE_SUPABASE_*`, `VITE_TOKEN_MARKETING/INBOX`, `TOKEN_KEYWORDS` 의 **실제 사용처**: `define` 으로 노출되지만 현재 Grep 상 사용 위치 추가 확인 필요. (`packages/api/src/keyword/keyword.service.ts` 에서 `PLATFORM_API_URL` 과 연관된 토큰 사용 가능성 존재 — 상세 Grep 필요.)
- `apps/global` 의 **`mail-template`, `wai-ai-agent-launcher`, `walink-generator`** 는 범위 밖이라 다루지 않음.

### 확인 불가로 표시한 사항
- `packages/api/src/wai/chatHistory.service.ts` 의 `getBaseUrl()` 반환값: 파일 내부 로직 미확인.
- `VITE_PLATFORM_MAIN2_API_URL` 가 live 에서 `platform.wadiz.kr` 로 `PLATFORM_API_URL` 과 동일하게 세팅되는 이유: env 상 동일값이지만 서비스 레이어에서 경로 prefix 로 구분(`/main2/...` vs 기타).
- `apps/global` 의 `VITE_PLATFORM_GLOBAL_API_TOKEN` Bearer 토큰이 stage/live/dev 에서 다른 이유 및 발급 주체: 관측 불가 (32-byte hex 값만 제공).
- `apps/partnerzone` 의 `fetchApi: link:@wadiz/fetch-api/src/fetchApi` 가 실제로 무엇을 link 하는지 (`@wadiz/fetch-api` 패키지 경로 미관측) — 의존성 선언만 있고 import 흔적은 없음.
- Help Center 의 `.env.live` 에 `ZENDESK_API_TOKEN` 이 평문으로 dev 와 동일하게 적혀있는 것: secret 관리 이슈 가능성. (관찰 사실만 기록)

### 다음 분석 단계 제안
- **Phase A**: `packages/api/src/**/*.service.ts` 전수 엔드포인트 인벤토리 (`@wadiz/api endpoint catalog`) → 본 문서가 참조할 수 있는 단일 소스.
- **Phase B**: `packages/features/`, `packages/widgets/` 의 숨은 API 호출 스윕.
- **Phase C**: `apps/mail-template`, `apps/wai-ai-agent-launcher`, `apps/walink-generator` 및 `static/services/admin`, `studio/{funding,startup,store}` 의 동일 포맷 분석.
- **Phase D**: `com.wadiz.web` 과 `apps/global/korea-main.tsx` 임베드 경계 문서화.
