# wadiz-frontend packages 상세 분석

> **기록 범위**: `wadiz-frontend/packages/*` 와 `wadiz-frontend/libraries/**` 에서 실제로 관측 가능한 소스·`package.json`·배럴(`index.ts`)만 기록합니다. 런타임 HTTP 동작, Sentry/Braze SDK 내부, app-api/web-api 서버 응답 구조 등은 **외부**로 표기합니다. pnpm workspace(`pnpm-workspace.yaml`)는 `packages/*`·`apps/*`·`apps/devtools/*` 만 등록하고, 각 app `vite.config.ts`의 `resolve.alias`로 `@wadiz/*` 를 `packages/*/src` 에 바로 매핑하므로 패키지 빌드 결과물은 따로 생성되지 않습니다.

## 1. 개요

`wadiz-frontend` 루트는 `packages/`·`apps/`·`libraries/`·`studio/`·`static/` 로 나뉘며, `turbo.json`(`pipeline: build/test/lint/dev/deploy`)으로 워크스페이스 전체의 pnpm 스크립트를 오케스트레이션합니다. `packages/` 하위 15개 패키지는 전부 `private: true`·`version: 0.0.0` 으로 릴리스하지 않고, app(`apps/global`, `apps/account`, `apps/walink-generator`, `apps/wai-ai-agent-launcher`, `apps/partnerzone`, `apps/devtools/component-playground`) 쪽에서 Vite `alias` 로 `packages/<name>/src` 를 직접 로드합니다.

- 워크스페이스 설정: `wadiz-frontend/pnpm-workspace.yaml:1-4`
- pipeline 정의: `wadiz-frontend/turbo.json:1-22`
- alias 매핑 표준: `wadiz-frontend/apps/global/vite.config.ts:141-165` (`@wadiz/api` → `../../packages/api/src`, `@wadiz/core` → `../../packages/core/src`, `@wadiz/metrics` → `../../packages/core/src/metrics`, `@wadiz/utils` → `../../packages/core/src/utils`, `@wadiz/request-api` → `../../libraries/packages/request-api/src` 등)

### 1.1 레이어 구조

`wadiz-frontend/packages/README.md:24-55` 에 공식 정의되어 있으며, 상위→하위로만 import 가능합니다.

| 레이어 | 패키지 |
|---|---|
| 1. 비즈니스 (최상위) | `@wadiz/features` |
| 2. 도메인 | `@wadiz/i18n`, `@wadiz/queries`, `@wadiz/ui` |
| 3. 데이터 | `@wadiz/api` |
| 4. 공통 (최하위) | `@wadiz/core`, `@wadiz/format`, `@wadiz/settings` |

`@wadiz/waffle`, `@wadiz/waffle-icons`, `@wadiz/artworks` 는 레이어와 독립된 "디자인 시스템" 축이며, `@wadiz/widgets`, `@wadiz/app-initializer`, `@wadiz/event-tracker` 는 README 레이어 표에는 등록되지 않은 보조 패키지입니다.

### 1.2 배럴(namespace) 규칙

`packages/CLAUDE.md:39-67` 지침대로, `@wadiz/api` 는 반드시 `export * as accountService from './account.service'` 형태의 네임스페이스 객체로만 export 합니다. 호출 측은 `import { accountService } from '@wadiz/api/web'` 후 `accountService.getMakerQuery(...)` 같은 메서드 호출로 사용합니다. 순환 참조 방지를 위해 패키지 내부에서는 자기 자신의 배럴(`@wadiz/waffle`)을 import 하지 않고 상대 경로(`../Modal`)를 씁니다.

### 1.3 앱별 alias 특이점

- `@wadiz/artworks` alias 는 `packages/artworks/src/components` 로 매핑됩니다(= 배럴 자동 생성, tree-shaking 용이성 목적).
- `@wadiz/waffle-icons` alias 는 `packages/waffle-icons/src/components` 로 매핑됩니다.
- SCSS 용 alias(`~@wadiz/waffle`, `~@wadiz/artworks-assets`, `~@wadiz/waffle-icons`)가 별도로 잡혀 있어 `@use`/`url()` 경로에서 사용합니다.
- `static/` 프로젝트(Webpack 4 기반)는 트리쉐이킹 제약으로 인해 배럴 대신 `@wadiz/waffle/src/Button` 형태의 직접 경로 import 를 강제합니다(`wadiz-frontend/packages/CLAUDE.md:84-94`).

---

## 2. 패키지별 섹션

### 2.1 `@wadiz/api`

- **책임**: HTTP 요청을 주관하는 데이터 레이어. 도메인별 `*.service.ts` 파일에 TanStack Query 호환 `queryFn`/`mutationFn`/`queryKey` 를 묶어서 export.
- **주요 파일**
  - `packages/api/src/fetch.ts` — fetch 래퍼(GET/POST/PUT/PATCH/DELETE)
  - `packages/api/src/FetchError.ts` — `Error` 상속 커스텀 에러
  - `packages/api/src/parseFetchError.ts` — 표준화된 에러 파서(`isUnauthorized`)
  - `packages/api/src/generateQueryKey.ts` — 정렬된 queryKey 생성기
- **도메인 서브디렉터리** (배럴: `packages/api/src/web/index.ts`, `.../app/index.ts`, `.../platform/index.ts`, `.../search/index.ts` 등)
  - `account/` 계정(Account 서버, `ACCOUNT_URL` 환경별 분기, `packages/api/src/account/account.service.ts:9-17`)
  - `activities/`, `admin/`, `collection/`, `friends/`, `inbox/`, `keyword/`, `main2/`, `makercenter/`, `oauth/`, `public/`, `search/`, `searcher/`, `terms/`, `wadizad/`, `wai/`, `wish/`
  - `app/` (app-api; `app/funding/projects.service.ts`, `app/links.service.ts`, `app/settings.service.ts`, `app/support.service.ts`)
  - `platform/` (`nicepay.service.ts`, `marketingconsents.service.ts`, `notification.service.ts`, `share.service.ts`, `inbox.service.ts`, `global/exchange-rate.service.ts`, `global/translate.service.ts`)
  - `web/` (web-api; 레거시 `www.wadiz.kr` 백엔드; 하위 `funding/`, `reward/`, `store/`, `event/`, `marketing/`, `membership/`, `term/`)
- **의존 패턴**
  - `@wadiz/core` 의 `Locale` 을 읽어 기본 헤더 생성(`packages/api/src/fetch.ts:12-20`)
  - `@wadiz/request-api` 의 `JSONParseError`·`parseAkamaiErrorString` 을 재사용(`packages/api/src/fetch.ts:3`, `packages/api/src/FetchError.ts:1`)
  - 상위 레이어(`@wadiz/queries`, `@wadiz/settings`, app 엔티티) 에서 `import { makerProxyService } from '@wadiz/api/web'` 식으로 호출
- **특이사항**
  - `generateQueryKey(['path/...'], additionalParams?)` 는 키 배열·오브젝트 키를 **정렬**해 JSON 문자열로 병합하므로 동일 파라미터면 호출 순서와 무관하게 동일 key 가 나옵니다(`packages/api/src/generateQueryKey.ts:1-14`).
  - 일부 서비스는 `@wadiz/api` 래퍼(`fetch.ts`) 대신 원시 `fetch()` 를 직접 사용합니다. 예: `packages/api/src/account/account.service.ts:89-108` (회원가입 직후 응답 `location` 헤더를 읽기 위해서).
  - `process.env.ACCOUNT_URL`, `process.env.ENVIRONMENT`, `process.env.PLATFORM_GLOBAL_API_TOKEN` 등은 각 app 의 `vite.config.ts` `define` 에서 주입됩니다(`apps/global/vite.config.ts:76-96`).
  - 생성 쿼리 호출 수(관찰): `generateQueryKey` 호출 317 건 / 79 파일.

### 2.2 `@wadiz/app-initializer`

- **책임**: 앱 마운트 전 i18n / Settings / AppConfig 초기화를 병렬 실행하고 재시도·에러 처리를 담당. React `createRoot` 헬퍼도 제공.
- **주요 export** (`packages/app-initializer/src/index.ts`)
  - `AppInitializer.initialize()` — Singleton Promise, MAX_RETRIES=2, 실패 stage 만 재시도(`packages/app-initializer/src/AppInitializer.tsx:19-140`)
  - `renderAppWithInitialization(element, target)` — 초기화 후 `createRoot(...).render(...)`, 실패 시 `AppInitErrorContent` 대체 렌더(`...:142-166`)
  - 타입: `InitResult`, `InitStageError`
- **스테이지 3종** (`packages/app-initializer/src/stages/`)
  - `initI18n.ts` — `@wadiz/i18n/supporter/i18n` 의 `initializeI18n()` 호출
  - `initSettings.ts` — `AccountSettings.initialize()` 필수, `LocaleSettings.isKorea` 가 false 일 때만 `CurrencySettings.initialize()` 추가
  - `initAppConfig.ts` — `inAppWebviewPolicy.isAppConfigSupported` 가 true 일 때만 `AppConfig.initialize()`
- **의존**: `@wadiz/core`, `@wadiz/settings`, `@wadiz/i18n`, `@wadiz/waffle` (AppInitErrorContent), `dayjs` locale(`en/ja/ko/zh`).
- **특이사항**
  - 초기화 성공 시 `dayjs.locale(LocaleSettings.languageCode)` 를 전역 설정.
  - 모든 stage 가 성공할 때까지 재시도; 최대 재시도 초과 시 `Sentry.fatal` 로 리포트 후 `AppInitErrorContent` 를 보여주고 렌더는 하지 않음.

### 2.3 `@wadiz/artworks`

- **책임**: Figma Waffle Design System 의 Artwork(카테고리 일러스트, 결제사 로고, 배너용 이미지) 를 React 컴포넌트·Storybook 리소스로 배포. 자동 생성된 인덱스.
- **구조**
  - `src/assets/*.svg` — 원본 SVG 자산
  - `src/components/<Name>Artwork.tsx` — 자동 생성 React 컴포넌트
  - `src/index.ts` — 468 라인, 모든 Artwork named export(`AllCategoryArtwork`, `ArtCategoryArtwork`, … 결제사 로고 `AmexSymbolColoredLogoArtwork` 등)
  - `src/usage-stats.json`, `src/usage-stats.ts` — `scripts/count-artworks-usage.ts` 가 생성하는 사용량 통계
  - `scripts/generate-artworks.ts` — SVG → React 컴포넌트·배럴 자동 생성
- **의존 패턴**: 각 app 이 `~@wadiz/artworks-assets` (SCSS)·`@wadiz/artworks` (JS) 로 소비.
- **특이사항**: `packages/artworks/src/index.ts` 는 자동 생성 파일로 수정 금지(`packages/CLAUDE.md:70-75`). Storybook 은 Webpack5 기반.

### 2.4 `@wadiz/cert`

- **책임**: 로컬 개발 SSL 인증서 저장소.
- **파일**: `packages/cert/local.wadiz.crt`, `packages/cert/local.wadiz.key`, `README.md`.
- **의존 패턴**: `apps/global/vite.config.ts:174-175` 같은 app 의 `server.https` 설정에서 cert/key 를 로드. `package.json` 없음(소스 패키지 아님).

### 2.5 `@wadiz/core`

- **책임**: 프레임워크 비종속 공통 함수 / 브라우저 헬퍼 / React 훅 / Sentry 래퍼 / 분석 유틸 / 도메인 모델 모음. 레이어 최하위(데이터·도메인 패키지가 모두 의존).
- **서브디렉터리**
  - `analytics/` — `PageViewTracker`, 레거시 `WadizAnalytics.js`(JS 믹스)
  - `config/` — `config/searchParams.ts` 배럴
  - `hooks/` — 30+ 훅(`useBrowserStorage`, `usePageView`, `useScrollDirection`, `useInView`, `useInfiniteScrollWithReactQuery`, `useModalWithHistoryBack`, `useResizeObserver`, `useSwipeView`, `useURLSearchParams`, `useAppFlag`, `usePageShow`, `usePreventBfcache`, `useWAiAIAgent` 등)
  - `lib/` — `AppBridge/`(네이티브 앱 ↔ 웹 메시지 브리지), `AppConfig.ts`, `modalRegistry.ts`, `useModalPortal.ts`, `presentUrl.ts`, `usePresentAction.ts`, `gaData.ts`, `goToLoginPage.ts`, `goToAdultVerificationPage.ts`, `preloadIntroImage.ts`, `isAllowedAdultCategory.ts`
  - `metrics/` — `sentry.ts`, `Metrics.ts`, `trackingEvent.ts`, `trackingBraze.ts`, `captureError.ts`, `errorReportDialog.ts`, `getLastEventId.ts` (외부에서 `@wadiz/metrics` alias 로 이 디렉터리 직접 참조)
  - `model/` — `model/project` 서브배럴; `project.types.ts`, `transformers/`
  - `policies/` — `inAppWebviewPolicy.ts`
  - `type/` — 전역 타입 선언(`wadiz.d.ts`, `global.d.ts`), 미리 컴파일된 `.d.ts.map` 포함
  - `utils/` — `@wadiz/utils` alias 타깃. JS/TS 혼재 (`action.js`, `browser.js`, `date.js`, `element.js`, `event.js`, `file.js`, `is.js`, `logger.js`, `misc.js`, `number.js`, `page.js`, `string.js`, `url.js`, `user.js`, `xhr.js`, `compareSemver.ts`, `loginController.ts`, `ui/`)
- **루트 파일 (`packages/core/src/`)**: `addCustomEventListener`, `cardNumberValidator`, `checkAppVersion`, `clipboard.js`, `compareAppVersions`, `cookie`, `downloadPDF`, `eventBus`, `formatIntlNumberWithLanguage`, `getAppSchemeURL`, `getChildNodeCount`, `getOptimizedURL`, `getURLS`, `getWeglotClass`, `jsonComparator`, `locale` (Locale 싱글톤), `preloadImage`, `processStoryHTML`, `routeUtil`
- **주요 export 배럴** (`packages/core/src/index.ts`): `Locale`, `addCustomEventListener`, `validateCardNumberWithLuhn`, `downloadPDF`, `getAllCookies(Snapshot)`, `eventBus`, `processStoryHTML`, `useInView`, `useLocalStorage/useSessionStorage`, `usePageShow/usePageView`, `usePreventBfcache`, `getIsPreviewMode`, `inAppWebviewPolicy`, `preloadImage`, `getOptimizedURL(ByWidth/Intro)`, `appBridge`, `useAppFlag`, `createPresentUrl/parsePresentUrl`, `usePresentAction` 등 63개 public entry.
- **의존 패턴**: 하위 레이어이므로 상위(`@wadiz/api`, `@wadiz/queries` 등) import 금지. 내부에서는 `metrics/sentry` 를 써서 `Locale` 에서 언어 불일치 리포트(`packages/core/src/locale.ts:51-95`).
- **특이사항**
  - `Locale` 싱글톤은 쿠키(`country`/`language`), URL pathname `/xx/` prefix, 프리뷰 파라미터, `/web/*` 경로(한국), `window.wadiz?.globals?.isGlobalBundle` 을 종합 평가하여 `countryCode`/`languageCode` 확정. 번들-언어 불일치 시 Sentry fatal 리포트 후 기대값으로 강제 교정(`packages/core/src/locale.ts:66-95`).
  - `eventBus` 는 `window.eventBus` 에 저장되는 전역 싱글톤 EventEmitter(여러 번들 공유 용도). 지원 EventName 은 union 타입으로 고정(`packages/core/src/eventBus.ts:3-13`).

### 2.6 `@wadiz/event-tracker`

- **책임**: DOM 요소 노출(impression)·클릭 추적 인프라와 도메인별 `tracking*` 함수 카탈로그.
- **코어** (`packages/event-tracker/src/EventTracker.ts`)
  - `EventTracker` 싱글톤: `IntersectionObserver` (`threshold 0.5`) + 100ms interval 로 `impression-time` 속성 누적, 1초 충족 시 `impressionCallback()` 호출(`packages/event-tracker/src/EventTracker.ts:1-128`)
  - `shouldTrackImpressionOnce` 옵션으로 1회성 노출만 집계(`impression-once="1"`).
  - `useTrackingEventRef(options)` — ref callback 형태로 observe/update/unobserve 자동 관리(`.../useTrackingEventRef.ts`)
- **도메인별 트래커** (`packages/event-tracker/src/*.tracker.ts`): `account`, `app-download`, `coupon`, `ecommerce`, `funding-detail`, `maker-home`, `marketing`, `multi-follow`, `notifications`, `search`, `simple-pay`, `sourcing-club`, `story`, `support`, `support-share`, `wai`.
- **의존**: `@wadiz/metrics` (`trackingCustomTag`, `trackingBraze`) 를 사용해 GA custom tag 와 Braze 이벤트 동시 송출(`packages/event-tracker/src/account.tracker.ts:1-14`).
- **배럴** (`packages/event-tracker/src/index.ts`): `appDownloadTracker`, `multiFollowTracker`, `fundingDetailTracker`, `simplePayTracker`, `sourcingClubTracker`, `storyTracker`, `supportTracker`, `notificationsTracker`, `waiTracker`, `couponTracker`, `accountTracker`, `marketingTracker`, `supportShareTracker`, `ecommerceTracker`, `makerHomeTracker`, `searchTracker`, `useTrackingEventRef`.

### 2.7 `@wadiz/features`

- **책임**: 여러 app 에서 재사용되는 화면 단위 feature 컴포넌트/훅(FSD `features` 레이어의 공통판). 레이어 최상위.
- **하위 feature 33개** (`packages/features/src/*`): `ab-test`, `activities`, `auto-login`, `comments`, `coupon`, `error-handler`, `events`, `funding-detail`, `funding-payment`, `funding-tracking-event`, `home`, `invitation-code`, `launching-soon-notification`, `maker-club`, `marketing`, `my-funding-banner`, `navigation`, `onelink`, `optimized-image`, `pre-reservation`, `project-card`, `report-modal`, `reward-satisfaction-modal`, `search`, `service-home`, `simple-pay`, `sms-auth`, `social`, `social-modal`, `spinner`, `storage`, `support-share`, `wish`.
- **feature 내부 구조 관찰 예**: `features/src/comments/{api,config,lib,ui,index.ts}`, `features/src/simple-pay/{api,lib,ui,requirements.md}`, `features/src/funding-detail/{ui,index.ts}` 로 feature 별 `api/lib/ui/config/index.ts` 분할 패턴.
- **의존** (`packages/features/package.json`): `@tanstack/react-query`, `react-hook-form`, `yup`, `@hookform/resolvers`, `zustand`, `dayjs`, `libphonenumber-js`, `react-modal`, `react-router-dom`, `lodash-es`. 내부적으로 `@wadiz/api`·`@wadiz/core`·`@wadiz/ui`·`@wadiz/waffle`·`@wadiz/queries` 등 모든 하위 레이어를 호출.
- **특이사항**: 개별 feature 는 이 문서의 심층 대상이 아님(각 feature 자체가 별도 분석 단위).

### 2.8 `@wadiz/format`

- **책임**: 통화·숫자·날짜 포맷터. `CurrencySettings`, `LocaleSettings` 를 주입 받아 얇게 래핑.
- **배럴** (`packages/format/src/index.ts`): `formatIntlDateTime`, `formatCurrency`, `formatIntlNumber`, `dateFromNow`.
- **핵심 API** (`packages/format/src/formatCurrency.ts`)
  - `formatKRW(amount)` / `useFormatKRW(amount)` — `CurrencySettings.formatKRW` 호출
  - `formatCurrency(amount)` / `useFormatCurrency(amount)` — `CurrencySettings.formatCurrency` 호출
  - `formatIntlCompactCurrency(amount, { maximumFractionDigits })` — `Intl.NumberFormat(notation: 'compact', style: 'currency')` 직접 사용, 1000 이상이면 접미사 `+` 부착
- **의존**: `@wadiz/settings` (의존 체인상 하위→하위 허용), `dayjs`, `react`.

### 2.9 `@wadiz/i18n`

- **책임**: 도메인별 다국어 리소스 관리와 `i18next` 초기화 래퍼. 자세한 내용은 아래 [5. i18n](#5-i18n) 섹션 참조.
- **배럴 (`packages/i18n/src/index.ts`)**: `getTranslation`, `i18n`, `useTranslation`, `TranslationKeys` 전부 `./supporter` 에서 재수출.
- **도메인**
  - `supporter/` — 서포터(일반 사용자) 번역(5,700 라인/언어)
  - `mail-template/` — 메일 템플릿 번역
  - `wai-ai-agent-launcher/` — WAi AI Agent Launcher 전용 번역
- **타입 트릭** (`packages/i18n/src/i18n.ts:1-18`)
  - `RecursiveKeyOf<T>` — JSON 리소스를 flatten 한 dot-path 유니언 타입 생성
  - `KeyPrefix<T>` — 2레벨까지의 접두사 타입만 허용(3레벨 key 가독성 보정)

### 2.10 `@wadiz/queries`

- **책임**: 여러 페이지에서 공유되는 복합 TanStack Query 훅·유틸리티(단순 `*.service.getXxxQuery()` 는 `@wadiz/api` 에 내장되므로, 여기엔 UI 레이어 로직과 결합된 쿼리만 존재).
- **배럴** (`packages/queries/src/index.ts`)
  - `useCategoriesAndCategoryMapQuery`, `ensureuseCategoriesAndCategoryMapQueryData`, `setGADataToCategories`, `useHomeCategories`
  - `getProcessedComingSoonStory`/`…Query`, `getProcessedFundingStory`/`…Query`
  - `useIsLoggedInQuery`
  - `useServiceHomeCategoriesQueries`
  - `useUnreadMessageCountQuery`
  - `useSession2tokenQuery`
  - `useUserMakerPages`
  - `useWAiChatHistoryQuery`
  - `withAccessTokenRefresh`
- **상세 카탈로그**: 아래 [4.2 queries 심층](#42-queries) 참조.
- **의존**: `@tanstack/react-query`, `@wadiz/api`, `@wadiz/core`, `@wadiz/settings`.

### 2.11 `@wadiz/settings`

- **책임**: 앱 전역 상태 싱글톤(로그인·국가·통화·Feature Flag) 관리. 모두 클래스 싱글톤 인스턴스로 export.
- **배럴** (`packages/settings/src/index.ts`)
  - `AccountSettings` — 로그인 상태·성인인증 캐시
  - `AppSettings` — 서버에서 받는 Feature Flag(`SettingsService.FeatureSettingMap`), `getSetting`(async)/`getSettingSync` 두 시그니처, Proxy 를 씌워 `AppSettings['walink']` 같은 속성 접근도 `getSettingSync` 로 위임
  - `CurrencySettings` — `exchangeRateService` 호출로 기본 환율(`baseRate 1447.1, code USD`)을 갱신하고 `Intl.NumberFormat` 생성
  - `LocaleSettings` — `@wadiz/core` 의 `Locale` 을 얇게 래핑, `getLocalizedURL` / `getBaseURL` / `getLanguageCodeFromURL` 제공(허용 도메인 `wadiz.kr`, `wadiz.ai`)
  - `useAppSettings` / `usePaymentPromotionSettings` — `AppSettings` React 훅(`packages/settings/src/hooks/useAppSettings.ts:1-57`)
- **의존**: `@wadiz/api` (`accountService`, `settingsService`, `exchangeRateService`), `@wadiz/core` (`Locale`), `@wadiz/utils` (`numberFormat`).
- **특이사항**
  - `AppSettings` 는 최초 로드 후 10분 경과(`REFETCH_INTERVAL`) + `visibilitychange`/`click`/`keydown`/`touchstart` 트리거 시 자동 재요청(`packages/settings/src/AppSettings.ts:13-80`).
  - `AccountSettings` 는 `window.wadiz.globals` (JSP 서버가 주입) 가 존재하면 즉시 초기화, 없으면 `accountService.getUserInfo()` 로 후속 로딩(`packages/settings/src/AccountSettings.ts:14-56`).

### 2.12 `@wadiz/ui`

- **책임**: 디자인시스템 위에 얹어지는 **비즈니스형 공통 UI 컴포넌트** 모음(결제·공유·푸터·컬렉션·쿼리 로그인 안내 등).
- **배럴 (`packages/ui/src/index.ts`) 주요 컴포넌트 27개**
  - `AdultVerificationContent`, `AppNotificationBanner`, `BottomNavigationBar`, `MakerBottomNavigationBar`, `BottomSafeArea`
  - `CollectionBanner`, `CollectionCardTypeBanner`, `CountryChangeButton`, `CountryChangeModal`
  - `ErrorContent`, `HiddenProjectErrorContent`, `NotPermittedErrorContent`, `ServerErrorContent`
  - `EventBannerCard`, `GridLayout`, `Header`, `KoreaDesktopHeader`
  - `Lottie`, `OrderSelect`, `PaymentChangeConfirmModal`(+타입 `PaymentChangeConfirmModalProps`, `ProjectPaymentInfo`)
  - `RatingScore`, `Share`, `Slider`, `StoreDeliveryBadges`, `SupporterFollowingButton`, `TableLayout`, `ThreeColumnCarousel`, `ThumbnailImage`
  - `ModeSwitchButton`, `ModeSwitchModal`, `MakeFundingButton`, `MakeFundingModal`
- **src 디렉터리 추가 컴포넌트**(배럴 미포함, 내부용 가능성): `AdultLoginNotice`, `AppDownload`, `CollapsibleDescription`, `ImageUploader`, `MakerFollowing`, `MultiFollow`, `PhoneNumberInput`, `StorySummarySection`, `SupporterFollowing`, `ThumbnailViewer`, `TossPaymentsBenefit`, `styles/` (글로벌 SCSS).
- **의존**: `@hookform/resolvers`, `@tanstack/react-query`, `classnames`, `clipboard`, `libphonenumber-js`, `lodash-es`, `marked`, `react-hook-form`, `react-lottie`, `react-modal`, `react-phone-number-input`, `react-slick`, `slick-carousel`, `yup`, `react-router-dom`, `@google.maps` 타입(지도 연동 가능). 내부적으로 `@wadiz/waffle`, `@wadiz/core`, `@wadiz/api`, `@wadiz/format` 등 참조.
- **sideEffects**: `**/*.(css|scss)` 만 부수효과로 지정하여 JS 는 tree-shaking 허용.

### 2.13 `@wadiz/waffle`

- **책임**: Wadiz Design System(Waffle) 의 **기본 React 컴포넌트** 라이브러리. 레거시 `@wadiz/waffle-v3-deprecated`, `@wadiz/waffle-v5-deprecated` 를 대체(`libraries/README.md:10-20`).
- **배럴 (`packages/waffle/src/index.ts`) 주요 컴포넌트 65종**: `Avatar`, `Badge`(Counter/Dot/Label/Notification/Reversal), `BlindText`, `Button`, `CardTable`, `CategorySelector`, `Checkbox`, `DatePicker`, `DateRangePicker`, `Divider`, `ErrorContent`(`NotPermittedErrorContent`, `ServerErrorContent`, `AppInitErrorContent`), `HelperMessage`, `HorizontalScrollLayout`, `IconButton`, `ImageEditor`, `ImageEditorModal`, `ImageSlider`, `Input`, `Loader`, `LanguageProvider`, `LocaleProvider`, `MarkdownToHtml`(+ `MarkdownToHtmlWithTyping`), `MessageBox`, `Modal`(AlertModal/ConfirmModal/InfoModal/PostcodeModal + `modalUtil` 배럴), `Popper`, `Popover`, `Portal`, `Radio`, `Rating`, `Select`, `SelectMenu`, `SubTabs`, `Tab`, `Tabs`, `TabPanels`, `Text`, `TextField`, `Textarea`, `TextareaAutosize`, `TimePicker`, `Toast` (+ `toastUtil`), `Toggle`, `Tooltip`, `VirtualNumberPadInput`, `WYSIWYGEditor`, `Zendesk`.
- **WAi 서브**: `WAi/ChatForm`, `WAi/WAiAIAgentSymbol`, `WAi/Tip` 타입 포함.
- **훅**: `useCopy`, `useForkRef`, `useIsKeyboardOpen`, `useMediaQuery`, `useOutsideClickRef`, `useSwipe`, `useWindowSize`.
- **styles**: `src/styles/style.scss` → `style.css` 빌드 스크립트(`sass:build`). app 의 SCSS `additionalData` 에 `@use '~@wadiz/waffle/styles' as *;` 로 주입(`apps/global/vite.config.ts:68-74`).
- **의존**: React 18.2, `froala-editor`/`react-froala-wysiwyg` (4.1.0), `react-datepicker`, `react-select`, `react-modal`, `react-lottie`, `react-jss`, `marked`, `classnames`, `date-fns`, `dayjs`, `lodash-es`, `copy-to-clipboard`, Storybook 8.
- **특이사항**: Vite/Vitest 기반. `vitest.workspace.ts` 로 단위 테스트 구성. `sideEffects` 에 `WYSIWYGEditor/**/*.(js|ts)` 와 `**/*.(css|scss)` 만 포함.

### 2.14 `@wadiz/waffle-icons`

- **책임**: Waffle 아이콘 시스템. SVG 259개(`src/assets/*.svg`)를 React 컴포넌트·자동 배럴로 변환.
- **배럴** (`packages/waffle-icons/src/index.ts`, 259 라인): `AccountCircleOIcon`/`accountCircleOIcon`(컴포넌트 + 메타 오브젝트 쌍)으로 export. 메타 오브젝트는 `withProps` 스타일 속성 주입용.
- **공통 래퍼**: `src/WithProps.tsx`, `src/WithProps.module.scss` (props → SVG 속성 적용 유틸).
- **생성 스크립트**: `scripts/generate-waffle-icons.ts` (SVG → TSX + index 자동).
- **의존**: React 18, `classnames`, `lodash-es`, Storybook 8. 배럴 자동 생성 → 수정 금지.

### 2.15 `@wadiz/widgets`

- **책임**: 여러 app 에서 공유되는 **복합 위젯**(헤더/푸터/마이페이지/쿠폰/이벤트/서포터 클럽 등 페이지-레벨 구성요소).
- **배럴 (`packages/widgets/src/index.ts`)**: `KoreaFooter`, `MyWadizSupporterContainer`, `MyWadizSupporter` 만 공개. (나머지는 내부 전용)
- **서브디렉터리**: `coupon/{config,lib,model,spec,ui}`, `events/{event-detail,event-list}`, `korea-footer/{lib,ui,index.ts}`, `my-wadiz/{supporter}`, `supporter-club/{assets,config,lib,ui,index.ts}`.
- **의존**: `@tanstack/react-query`, `react-hook-form`, `yup`, `zustand`, `dayjs`, `react-slick`, `slick-carousel`, `libphonenumber-js`, `lodash-es`, `react-modal`, `react-router-dom`, `classnames`. 상위 레이어에서 `@wadiz/ui`, `@wadiz/api`, `@wadiz/core` 소비 추정.

---

## 3. libraries/ 공유물

`wadiz-frontend/libraries/` 는 과거 Lerna 기반 모노레포의 흔적으로, 현재 4개 패키지를 현역으로 유지하고 app `vite.config.ts` alias 로 직접 참조합니다.

### 3.1 `@wadiz/request-api` (`libraries/packages/request-api/`)

- **책임**: `@wadiz/api` 보다 더 하위의 네트워크 프리미티브. Akamai/Unauthorized 처리, 커스텀 에러 계층, Service/Reward/Public/Embed API 도메인 바인딩.
- **배럴 (`src/index.ts`)**: `requestAjax`, `requestApi`, `rewardApi`, `publicApi`, `serviceApi`, `embedApi`, `config`, `errors`, `types`.
- **에러 계층 (`src/errors/`)**: `RequestApiError`, `HttpStatusError`, `HttpRequestError`, `HttpInternalServerError`, `JsonParseError`, `Unauthorized`, `WebAjaxError`.
- **유틸**: `parseAkamaiErrorString.ts`(CDN 에러 HTML → 메시지 추출), `pathPrefixer.ts`, `queryString.ts`, `requestApiUrl.ts`.
- **특이사항**
  - `request()` 가 `fetch` 를 `isomorphic-unfetch` 로 폴리필하며, IE 감지 시 `Pragma: no-cache` 를 강제(`libraries/packages/request-api/src/request.ts:14-42`).
  - 401 → `Unauthorized` throw, 503 → `HttpStatusError(response.statusText)` throw 로 Akamai 에러 캡처 경로 확보.
  - `@wadiz/api/FetchError` 가 이 라이브러리의 `parseAkamaiErrorString` 을 재사용해 FetchError 에 `akamai.errorString` extra 를 주입(`packages/api/src/FetchError.ts:1-40`).

### 3.2 `@wadiz/react-components` (`libraries/libraries/react-components/`)

- **책임**: `@wadiz/waffle` 로 이관되기 전의 레거시 React 컴포넌트(`Avatar`, `BackgroundImage`, `Button`, `Contents`, `DateRangePicker`, `Dialog`(Basic/Confirm/Modal), `EquityRiskButton`/`Modal`, `EquityStepModal`, `FluidText`, `InputNumeric`, `ListContainer`, `Loader`, `MoreButton`, `PDFViewer`, `Pagination`, `PopMenu`, `RouterHelper`, `SectionSlider`, `SortingSelect`, `Text`, `VisibleObserver`).
- **배럴** (`src/index.js`): 16종 재수출. app alias `@wadiz/react-components` 로 직접 소비.

### 3.3 `@wadiz/react-modal` (`libraries/packages/react-modal/`)

- **책임**: `react-modal` 위의 얇은 래퍼(`WadizModal.tsx` + `.module.scss`).

### 3.4 `@wadiz/wysiwyg-editor` (`libraries/packages/wysiwyg-editor/`)

- **책임**: Froala 기반 WYSIWYG 에디터 레거시. 에셋/컴포넌트/컨테이너/jquery.js/스타일 혼재. `@wadiz/waffle/WYSIWYGEditor` 로 점진 대체.

### 3.5 기타

- `libraries/libraries/babel-preset`, `eslint-config`, `stylelint-config`, `react-error-boundary` — 빌드/린트 구성. app alias `@wadiz/react-error-boundary` 로 소비(`apps/global/vite.config.ts:154`).

---

## 4. 핵심 패키지 심층

### 4.1 api — fetch 래퍼·헤더·업스트림 전환

파일: `packages/api/src/fetch.ts`

1. **HTTP 메서드 엔트리**(라인 번호는 해당 파일 기준)
   - `GET<T,R>(url, config?: RequestConfig & { params?: T })` — `URLSearchParams` 로 쿼리 부착, `0`/`false` 는 유지·그 외 falsy 는 제거(`:22-38`)
   - `POST<T,R>(url, data?, config?)` — `FormData` 이면 바이너리 전송 + 자동 Content-Type, 아니면 `JSON.stringify` + `Content-Type: application/json` 부착(`:41-51`)
   - `PUT`, `PATCH`, `DELETE` — POST 와 동일 패턴, body 유무에 따라 Content-Type 분기(`:53-77`)
2. **URL 정규화 (`resolveUrl`, `getNormalizedUrl`)**(`:79-105`)
   - 절대 URL 이면 `URL` 객체로 파싱해 `pathname + search + hash` 보존
   - 상대 URL 이면 선행 `/` 보정 후 `baseUrl` 과 결합(양쪽 슬래시 정리)
3. **공통 헤더 `getDefaultHeaders()`**(`:12-20`)
   - `Locale.countryCode` → `wadiz-country` 헤더
   - `Locale.languageCode` → `wadiz-language` 헤더
   - 쿠키/프리뷰/URL path 가 모두 반영된 Locale 싱글톤(`packages/core/src/locale.ts`) 사용
4. **요청 처리 `request()`**(`:107-125`)
   - `cache: 'default'`, `credentials: 'same-origin'` 기본값
   - 정상 시 `handleFetchResponse`, 예외 시 `handleFetchError`
5. **응답 핸들러 `handleFetchResponse()`**(`:127-172`)
   - 204 → `null` 반환
   - JSON 파싱 실패 → `JSONParseError` (response clone 에서 text 백업해 extra 채움)
   - `response.ok === false` → `FetchError` 로 `http.error.status`, `response.json`, `request.init` 등 extra 전부 부착
6. **에러 핸들러 `handleFetchError()`**(`:174-191`)
   - 네트워크 예외는 `'알 수 없는 오류가 발생하였습니다.'` 기본 메시지와 함께 `FetchError` 로 통합
7. **에러 후처리 `FetchError`**(`packages/api/src/FetchError.ts`)
   - Sentry fingerprint 에 pathname 자동 추가
   - `response.text` 가 있으면 `parseAkamaiErrorString` 으로 `akamai.errorString` 파싱
   - `response` 필드에 JSON body 보존
8. **에러 정규화 `parseFetchError<T>(error)`**(`packages/api/src/parseFetchError.ts`)
   - 반환 타입 `ParsedFetchError<T>` = `{ config, message, name, isUnauthorized, response, status, statusText }`
   - `FetchError`/`JSONParseError` 각각 별도 브랜치로 extra 추출
   - status 401 → `isUnauthorized=true`
9. **업스트림 전환 로직 — FeatureFlag 기반 web↔app api 전환**
   - `packages/queries/src/processedStoryQuery.ts` — `AppSettings.getSettingSync('funding-story-api').enabled` 참조
     - 플래그 on·프리뷰 아닐 때: `app-api` (`projectsService.getFundingStory`) 호출
     - 플래그 off 또는 preview 모드: `web-api` (`fundingService.getFundingStory`) 호출
     - app-api 실패 시 `catch` 블록에서 web-api 로 fallback(`:18-34`)
     - app-api 는 서버에서 HTML 처리 완료로 간주, web-api 응답만 `processStoryHTML` 추가 가공(`:41-45`)
     - queryKey 도 플래그에 따라 `/api/v1/funding/projects/{no}/story` vs `web/apip/funding/global/projects/{no}/story` 로 달라짐
10. **Account 서버 업스트림 전환** (`packages/api/src/account/account.service.ts:9-43`)
    - `ACCOUNT_URL` = `{local, dev, rc, rc2, rc3, stage, live}` 도메인 매핑
    - `location.origin` 이 `local-account.wadiz.kr` 이면 동일 origin 사용(서버팀 로컬 테스트), 아니면 `process.env.ENVIRONMENT === 'stage'` 일 때 stage 도메인, 그 외는 `process.env.ACCOUNT_URL` (Vite env)
    - `credentials` 는 dev 환경에서만 `'include'` 로 쿠키 전송
    - 회원가입(`postUser`, `postSocialUser`)은 Location 헤더를 읽기 위해 원시 `fetch` 를 직접 호출하는 예외 케이스
11. **Account Token 자동 갱신** — `withAccessTokenRefresh` (`packages/queries/src/accessTokenRefresh.ts`)
    - 쿼리/뮤테이션 래퍼. 401 에러 시 `session2token.getSession2tokenQuery()` 로 Access Token 재발급 후 재시도
    - 재시도 중복 방지: `retriedKeys Set` + `refreshPromise` 를 전역으로 공유(`:14-38`)
    - 단일 key 에 대해 **한 번만** 재시도(무한 루프 방지), 성공하면 key 제거

### 4.2 queries — TanStack Query 카탈로그

카탈로그는 `@wadiz/api` 의 `get*Query()` 를 결합·가공하거나 staleTime 을 조정하는 상위 훅 위주. 경로 형식은 각 service 가 쓰는 백엔드 endpoint 이며 `generateQueryKey` 로 정렬된 배열 키를 생성합니다.

| export | queryKey (기반 endpoint) | staleTime | 대상 서버 |
|---|---|---|---|
| `useIsLoggedInQuery` | `/web/account/isLoggedIn` | `1000*60*30` (30분, 훅 내부) | web-api (accountService.getIsLoggedIn) |
| `useSession2tokenQuery` | `/web/session2token/oauth2_token` | `1000*60*3` (서비스에 고정, 3분) | web-api (session2token.getSession2token) |
| `useUnreadMessageCountQuery(encUserId)` | inbox 서비스 키 | 기본값 | `@wadiz/api/inbox` inboxService |
| `useUserMakerPages` | makerProxy 서비스 키 | 기본값 (`refetchOnWindowFocus: false`, `enabled: AccountSettings.isLoggedIn`) | web-api makerProxyService |
| `useServiceHomeCategoriesQueries([productType])` | 서비스별 카테고리 키 | `Infinity` | search-api searchService |
| `useCategoriesAndCategoryMapQuery(serviceType, { gaCategory, addCategoryAll })` | `getCategoriesAndCategoryMapQuery(...)` 키 | `Infinity` | search-api searchService |
| `useHomeCategories(type, gaCategory, queryOption)` | `getServiceHomeCategoriesQuery({ type })` 키 | `Infinity` | search-api searchService |
| `ensureuseCategoriesAndCategoryMapQueryData(client, serviceType)` | prefetch 헬퍼 | `Infinity` | 동일 |
| `getProcessedFundingStoryQuery(projectNo)` | `/api/v1/funding/projects/{no}/story \| web/apip/funding/global/projects/{no}/story` + `'processed'` | (호출측이 결정) | AppSettings flag 에 따라 app-api/web-api |
| `getProcessedComingSoonStoryQuery(projectNo)` | `/api/v1/funding/projects/{no}/launching-soon-story \| web/apip/funding/global/projects/{no}/coming-soon-story` + `'processed'` | (호출측이 결정) | 동일 |
| `useWAiChatHistoryQuery({ sessionId, accessToken })` | `['wai-chat-history', sessionId]` | `0` (retry:1) | WAi data 서버(`dev-aidata.wadiz.kr`, `aidata.wadiz.kr`) |
| `withAccessTokenRefresh(client, fn, getKey?)` | queryClient 래퍼 | — | 위 4.1 참조 |

- **utility** `setGADataToCategories(categories, gaCategory)` — BFS 로 카테고리 트리에 `gaData` 를 주입(depth 1 = 대분류, depth>1 = 중분류) (`packages/queries/src/category/useCategoriesAndCategoryMapQuery.ts:7-22`).
- **test 픽스처** `packages/queries/src/_localData/fundingstory.js` — 개발 환경(`process.env.NODE_ENV==='development'` + URL param `test=Y`)에서만 로드되는 mock.

### 4.3 디자인 시스템 — ui / waffle / waffle-icons / artworks

| 역할 | 패키지 | 성격 |
|---|---|---|
| 기본 UI 토큰·제스처·입력 컨트롤 | `@wadiz/waffle` | 범용 디자인 시스템 컴포넌트 |
| SVG 아이콘 | `@wadiz/waffle-icons` | 자동 생성 배럴, 259개 아이콘 |
| 일러스트/로고 | `@wadiz/artworks` | 자동 생성 배럴, 카테고리 + 결제사 + 플랫폼 로고 |
| 비즈니스 단위 컴포넌트 | `@wadiz/ui` | 펀딩/결제/공유/배너 등 |
| 복합 위젯 | `@wadiz/widgets` | 헤더·푸터·쿠폰·이벤트 |
| 공통 feature | `@wadiz/features` | 33개 feature 모음 |

**의존 방향**: `features` → `widgets`/`ui` → `waffle`/`waffle-icons`/`artworks`. `waffle` 은 외부 React 라이브러리(`react-select`, `react-datepicker`, `react-froala-wysiwyg`, `react-jss`, `react-lottie`) 위에 구현. `ui` 와 `features` 는 `@wadiz/api`/`@wadiz/core`/`@wadiz/settings` 까지 의존 가능.

**SCSS 주입**: app 의 `vite.config.ts` `css.preprocessorOptions.scss.additionalData` 에 `@use '~@wadiz/waffle/styles' as *;` 을 넣어 Waffle 변수/믹스인을 전역으로 쓸 수 있게 함(`apps/global/vite.config.ts:68-74`).

**아이콘·아트웍 tree-shaking**: app alias 가 배럴 대신 `components/` 디렉터리를 직접 가리키므로, `import { WishIcon } from '@wadiz/waffle-icons'` 은 실제로 `packages/waffle-icons/src/components/WishIcon.tsx` 로 리졸브됨 → 개별 아이콘만 번들 포함.

### 4.4 features — 공통 feature 모듈

`packages/features/src` 하위 33개 feature(상단 섹션 참조). 각 feature 는 `api/` `lib/` `ui/` `config/` 중 일부와 `index.ts` 를 포함하는 FSD(Feature-Sliced Design) 미니 구조를 따릅니다. 예:

- `simple-pay/` — `api/`, `lib/`, `ui/`, `requirements.md`
- `comments/` — `api/`, `config/`, `lib/`, `ui/`, `index.ts`
- `funding-detail/` — `ui/`, `index.ts` (API 는 상위 app 이 주입)

feature 들은 도메인 경계에 따라 app 의 FSD(`src/app`, `src/pages`, `src/widgets`, `src/features`, `src/entities`, `src/shared`)에서 `@wadiz/features` 로 import 되어 **재사용 가능한 기능 단위**로 소비됩니다(`apps/CLAUDE.md` Feature-Sliced Design 섹션 참고).

---

## 5. i18n — 다국어 리소스

### 5.1 도메인

`packages/i18n/src/` 아래 3개 도메인이 각각 `i18n.ts / index.ts / getTranslation.ts / useTranslation.ts / languages/` 조합을 갖습니다.

- `supporter/` — 서포터 웹의 기본 번역
- `mail-template/` — 메일 템플릿 번역
- `wai-ai-agent-launcher/` — WAi AI Agent Launcher 번역

현재 최상위 `packages/i18n/src/index.ts` 가 `supporter` 만 재수출하므로, 외부에서 `import { useTranslation } from '@wadiz/i18n'` 은 **supporter 도메인 한정**. mail-template/wai-ai-agent-launcher 는 필요 시 직접 경로로 import 해야 합니다.

### 5.2 로케일 리소스

| 도메인 | 언어 | 파일 | 라인 수(관찰) |
|---|---|---|---|
| supporter | ko | `supporter/languages/ko.json` | 5,678 |
| supporter | en | `supporter/languages/en.json` | 5,700 |
| supporter | ja | `supporter/languages/ja.json` | 5,692 |
| supporter | zh | `supporter/languages/zh.json` | 5,691 |
| mail-template | ko/en/ja/zh | `mail-template/languages/*.json` | (관찰) |
| wai-ai-agent-launcher | ko/en/ja/zh | `wai-ai-agent-launcher/languages/*.json` | (관찰) |

라인 수는 JSON 포맷 줄 수이며 실제 key 개수와는 다릅니다. `ko/en/ja/zh` 모두 lines 가 거의 비슷한 것으로 미루어 **동일 key 트리**를 유지합니다(각 app 의 `scripts/validate-translation-key-mismatch.ts` 로 검증).

### 5.3 초기화 로직 (`packages/i18n/src/supporter/i18n.ts`)

- `initializeI18n()` 은 Promise singleton. 이미 진행 중이면 기존 Promise 반환(`:22-33`).
- `performInitialization()` 에서 `LocaleSettings.languageCode` 로 lng 결정, `i18next.use(initReactI18next).init({ fallbackLng: 'en', resources: { en, ja, ko, zh } })` 실행(`:63-77`).
- `returnObjects: true` — 트리 값을 통째로 반환해 배열/객체 번역도 지원.
- 주석 처리된 CDN 버전(`https://static-dev.wadiz.kr/test/i18n/supporter/{lng}.json`)이 남아 있어, 향후 JSON 을 CDN 에서 로드할 구조도 예정됨(`:41-61`).
- TS 트릭: `export type TranslationKeys = RecursiveKeyOf<typeof en>;` 로 key 자동완성을 제공(`:94`).

### 5.4 훅·함수

- **`useTranslation`** (`packages/i18n/src/supporter/useTranslation.ts`)
  - `i18n.isInitialized` 가 false 면 즉시 예외 throw (AppInitializer 스테이지 순서 강제, `:11-13`).
  - `t(key, args?)` 는 `args` 배열을 `arg_0`, `arg_1` 형태 오브젝트로 변환해 i18next interpolation 에 주입(`:22-28`).
  - 제네릭 `P extends KeyPrefix<TranslationKeys>` 로 `keyPrefix` 옵션 타입 안전성 제공.
- **`getTranslation`** (`packages/i18n/src/supporter/getTranslation.ts`)
  - 훅이 아닌 함수형 API. `i18n.t(...)` 를 직접 호출. `keyPrefix` 옵션으로 prefix 적용.

### 5.5 import 규약

- 상위 레이어(`@wadiz/ui`, `@wadiz/waffle`, `@wadiz/features`, app) 에서만 호출.
- `@wadiz/core`, `@wadiz/settings` 는 `@wadiz/i18n` 보다 하위이므로 여기서 번역을 호출할 수 없습니다(레이어 규칙).

---

## 6. event-tracker — 애널리틱스 이벤트 명세

### 6.1 저수준 인프라 — `EventTracker`

`packages/event-tracker/src/EventTracker.ts` 의 단일 싱글톤(`export default new EventTracker()`).

- **관측 단위**: `observe(element, { clickCallback?, impressionCallback?, shouldTrackImpressionOnce? })`
- **impression 규칙**
  - IntersectionObserver threshold 0.5
  - 가시 상태가 1,000ms 누적되면 `impressionCallback` 실행, `impression-fired="1"` DOM 속성 부여
  - `shouldTrackImpressionOnce=true` 이면 fire 된 요소는 unobserve
  - 가시 이탈 시 `impression-time` 속성 초기화(once 가 아닌 경우 재집계)
- **click 규칙**: `element.addEventListener('click', cb)` 직접 등록. `unobserve()` 시 자동 해제.

### 6.2 도메인 트래커

`packages/event-tracker/src/*.tracker.ts` 각 파일은 `trackingCustomTag({ category, action, label })` (GA 유니버설 호환 태그) 와 `trackingBraze('event'|'attr', key, value?)` 를 조합하여 이벤트를 송출합니다. 호출 대상은 `@wadiz/metrics` (= `packages/core/src/metrics/`) 에 있는 `trackingCustomTag`, `trackingBraze` 함수이며 내부 SDK(GTM/Braze) 연동은 core/metrics 에서 처리합니다(**외부 SDK**).

| 트래커 파일 | 주요 이벤트 카테고리(관찰) |
|---|---|
| `account.tracker.ts` | `waccount_create_complete_pv`, `waccount_create_complete`, `로그인/회원가입_*`, `이메일로시작하기_*` |
| `app-download.tracker.ts` | 앱 다운로드 유도 |
| `coupon.tracker.ts` | 쿠폰 박스/다운로드 |
| `ecommerce.tracker.ts` | GA ecommerce payload |
| `funding-detail.tracker.ts` | `${projectType}_상세`, `진행중CTA` |
| `maker-home.tracker.ts` | 메이커홈 노출/클릭 |
| `marketing.tracker.ts` | 마케팅 캠페인 |
| `multi-follow.tracker.ts` | 다중 팔로우 |
| `notifications.tracker.ts` | 알림 설정 |
| `search.tracker.ts` | 검색 UX |
| `simple-pay.tracker.ts` | 간편결제 |
| `sourcing-club.tracker.ts` | 소싱 클럽 |
| `story.tracker.ts` | 프로젝트 스토리 |
| `support.tracker.ts` | 서포트/펀딩참여 |
| `support-share.tracker.ts` | 서포트 공유 |
| `wai.tracker.ts` | WAi AI Agent |

- 배럴이 모두 `export * as <name>Tracker` 로 감싸므로 호출은 `supportTracker.trackingXxx(...)` 처럼 네임스페이스 접근만 허용됩니다.
- 이벤트명·라벨·카테고리 체계는 레거시 GA 유니버설(트리 분류형 `category/action/label`) 을 기반으로 하며, Braze 는 `event`(이벤트명) / `attr`(사용자 속성)만 사용.

### 6.3 React 훅 — `useTrackingEventRef`

`packages/event-tracker/src/useTrackingEventRef.ts:6-28`

- `ref` callback 을 반환 → 요소 mount/unmount 시 `EventTracker.observe/unobserve` 자동 호출
- `options` 변경 시 `EventTracker.update(refObject.current, options)` 로 콜백 최신화(재관측하지 않고 맵만 갱신)
- DOM ref 객체(`refObject`) 도 함께 반환

---

## 7. 경계 및 미탐색 영역

- **서버 응답 스키마**: `@wadiz/api` 각 service 의 `Response`/`Request` 인터페이스는 관찰 기록이지만, 실제 엔드포인트에서 반환하는 모든 필드의 정확성은 `com.wadiz.web`, `com.wadiz.api.funding`, app-api, account 서버 등 외부 백엔드에서 확인해야 합니다.
- **WAi 서버**: `packages/api/src/wai/chatHistory.service.ts` 가 `dev-aidata.wadiz.kr`, `aidata.wadiz.kr` 로 호출. rc 환경 기본값은 `rc-aidata.wadiz.kr`. 해당 서버는 이 repo 범위 밖.
- **Exchange Rate 서버**: `@wadiz/api/platform/global/exchange-rate.service.ts` 는 `process.env.PLATFORM_GLOBAL_API_URL` + `Bearer ${PLATFORM_GLOBAL_API_TOKEN}` 로 호출. 실제 URL 은 app env (`VITE_PLATFORM_GLOBAL_API_URL`) 에서 주입됨.
- **레거시 JS 혼재**: `packages/core/src/analytics/WadizAnalytics.js`, `packages/core/src/utils/*.js`, `packages/queries/src/_localData/fundingstory.js` 등 `.js` 혼재 → 타입 안전성 부재 구간.
- **`@wadiz/widgets` 배럴 미공개 영역**: `coupon/`, `events/`, `supporter-club/` 은 `index.ts` 루트에서 export 하지 않음 → 내부 전용 또는 하위 경로 직접 import 요구. 외부 사용 여부는 app 코드 개별 확인 필요.
- **Storybook 리소스**: `packages/artworks/stories/`, `packages/waffle/stories/`, `packages/waffle-icons/stories/` 는 런타임에 포함되지 않음(문서/QA 용).
- **테스트**: `packages/core/vitest.config.ts`, `packages/waffle/vitest.workspace.ts` 만 vitest 설정 보유. 나머지 패키지는 테스트 러너 미정.
- **Lerna 잔재**: `libraries/lerna.json`, `libraries/yarn.lock`, `libraries/webpack.config.js`, `libraries/babel.config.json` 등 Lerna/Webpack/Yarn 시절 유산이 그대로 남아 현재 pnpm 워크스페이스와 병존.
- **`@wadiz/i18n` 미배럴 도메인**: `mail-template`, `wai-ai-agent-launcher` 는 루트 `index.ts` 에서 export 하지 않으므로 app 이 `@wadiz/i18n/mail-template` 같은 서브경로로 import 해야 함(실제 import 패턴은 미확인).
- **`cert` 패키지**: `packages/cert/` 는 `package.json` 이 없어 pnpm 워크스페이스에 등록되지 않음. app 의 `cert/` 디렉터리와 별개로 참고용으로 추정됨.
- **환경변수 주입**: `@wadiz/api` 의 도메인 분기는 `process.env.*` 를 참조하지만, 각 app 의 `vite.config.ts:define` 블록에 정의된 변수만 주입됩니다. devtools/component-playground, walink-generator 등 일부 app 은 `vite.config.ts:7~16` 개 alias 만 등록해 동일 env 를 쓰는지 추가 확인 필요.

---

## 부록 A. `@wadiz/api` 서비스 상세 카탈로그

각 서비스 파일의 관측 정보(배럴 이름, 베이스 URL 결정, 주요 endpoint). 서버 내부 동작은 **외부** 처리.

### A.1 `web/` (레거시 www.wadiz.kr 백엔드)

| 서비스 | 배럴 이름 | 주요 endpoint (prefix) | 비고 |
|---|---|---|---|
| `account.service.ts` (490L) | `accountService`, `AccountService` | `/web/account/isLoggedIn` 등 | `UserInfo` 정규화(`getIsLoggedIn`→`getUserInfo`, `packages/api/src/web/account.service.ts:51-66`) |
| `catchup.service.ts` | `catchupService` | `/web/catchup/...` | 메이커 뉴스(공지) |
| `countries.service.ts` | `countriesService` | `/web/countries/...` | 국가·언어 리스트 |
| `funding.service.ts` (1,183L) | `fundingService` | `web/apip/funding/...` | News/Participation/Pre-reservation/Story/Order 등 펀딩 코어 |
| `funding/` 하위 14개 | `fundingService.*` (상세는 `web/funding/index.ts`: `campaignService`, `comingSoonsService`, `ordersService`, `simplePayService`, `supportersService`, `wishesService`, `fundingEventService`, `reactionsService`, `projectService`, `paymentProgressService`, `bottomSheetService`, `makerService`, `storyService`) | 각각 `web/apip/funding/...` | |
| `funding/global/project.service.ts` | `fundingService` 내부 | `web/apip/funding/global/projects/{no}/...` | 글로벌 전용 분기 |
| `join.service.ts` | `joinService` | `/web/join/...` | 회원 가입 래퍼 |
| `maker.service.ts` | `makerService` | `/web/maker/...` | 메이커 페이지 |
| `maker-proxy.service.ts` | `makerProxyService` | maker 정보 프록시 | `getUserMakerPagesQuery` 제공 (queries 에서 사용) |
| `marketing/` | `marketingService`, `termService` | `/web/marketing/...` | 마케팅 동의/이용약관 |
| `membership/` | `membershipService`, `membershipPaymentService` | `/web/membership/...` | 멤버십 결제 |
| `myfunding.service.ts` | `myFundingService` | `/web/myfunding/...` | 마이 펀딩 |
| `payment.service.ts` | `paymentService` | `/web/payment/...` | 결제 공통 |
| `point.service.ts` | `pointService` | `/web/point/...` | 와디즈 포인트 |
| `quick-menu.services.ts` | `quickMenuService` | `/web/quick-menu/...` | 하단 고정 메뉴 |
| `reward/backing-payment.service.ts` (301L) | `backingPaymentService` | `/web/reward/backing-payment/...` | `getRewardPurchaseInfoQuery`, `getMyChangeablePaymentInfoQuery` |
| `reward/campaign.service.ts` | `projectService`(alias!), `CampaignService` 아닌 `ProjectService` 로 export | 리워드 프로젝트 | 배럴에서 `projectService` 로 rename(`web/reward/index.ts:4`) |
| `reward/collections.service.ts` | `rewardCollectionsService` | 리워드 컬렉션 | |
| `reward/comments.service.ts` | `commentsService` | 리워드 댓글 | |
| `reward/coupon.service.ts` (445L) | `couponService` | 리워드 쿠폰 | `getMyUsableCouponListQuery`, `getMyCouponCountQuery`, `getDownloadCouponListQuery`, `getAllAvailableCouponsQuery`, `getMaxBenefitCouponQuery`, `postDownloadCouponMutate`, `postDownloadCouponsMutate`, `postCouponRedemptionsMutate` |
| `reward/delivery.service.ts` | `deliveryService` | 리워드 배송 | |
| `reward/funding.service.ts` | `fundingService`(배럴에서 `RewardFundingService` 가 아닌 `fundingService` 로 충돌; `@wadiz/api/web/reward` 경로에서 import) | 리워드 펀딩 집계 | |
| `reward/issue-report.service.ts` | `issueReportService` | 이슈 리포트 | |
| `reward/maker.service.ts` | `makerService` (web/reward 내부) | 리워드 메이커 | |
| `reward/refund.service.ts` (323L) | `refundService` | 환불 | |
| `reward/satisfaction.service.ts` | `satisfactionService` | 만족도 조사 | |
| `reward/shipment.service.ts` | `shipmentService` | 발송 정보 | |
| `reward/supporter-club.service.ts` | `supporterClubService` | 서포터 클럽 | |
| `reward/type.ts` (334L) | 타입 전용 | `PayStatus` 등 공용 | |
| `session2token.service.ts` | `session2token` | `/web/session2token/oauth2_token` | staleTime 3분 고정 |
| `settlement.service.ts` | `settlementService` | `/web/settlement/...` | 정산 |
| `sign-up.service.ts` | `signUpService` | 회원 가입 | |
| `social.service.ts` | `socialService` | 소셜 계정 연동 | |
| `sourcing-club.service.ts` | `sourcingClubService` | 소싱 클럽 | |
| `store.service.ts` | `storeService` | `/web/store/...` | 스토어 |
| `store/{maker,orders,projects}.service.ts` | `storeService.*` | 스토어 하위 | |
| `support-share.service.ts` | `supportShareService` | 응원 공유 | |
| `term/marketing.service.ts`, `terms.service.ts` | `termsService` | `/web/terms/...` | 약관 |
| `user.service.ts` | `userService` | `/web/user/...` | 사용자 일반 |
| `wpurchase.service.ts` | `wpurchaseService` | `/web/wpurchase/...` | W구매 |
| `event/invite.service.ts` | `inviteService` | 이벤트 초대 | |

### A.2 `app/` (신규 app-api, `APP_API_DOMAIN` 환경별 분기)

- `app/funding/projects.service.ts` — `getFundingStory(projectNo)`, `getLaunchingSoonStory(projectNo)`. 베이스 URL 은 `https://app.wadiz.kr` **고정**(local/dev/rc 의 경우 해당 endpoint 미확인 → 외부; `packages/api/src/app/funding/projects.service.ts:19-40`).
- `app/links.service.ts` — `getShareSettings()` → `/2023/onelink/settings.json` (`process.env.STATIC_URL`), `postWalink(url)` → `/api/v1/links` (`process.env.APP_API_URL`), `postWalinks(targets)`/`postWalinksQuery(targets)` → `/api/v2/links` (`APP_API_DOMAIN[process.env.ENVIRONMENT]`). (`packages/api/src/app/links.service.ts:1-60`).
- `app/settings.service.ts` — `getAppSettings()` Feature Flag 목록 반환. 타입 `AppSettingsFeature = 'app-install-promotion' | 'bnbStoreTab' | 'browser-reload' | 'funding-story-api' | 'global-only-project' | 'login-buttons-layout' | 'sample' | 'walink' | 'queue-enabled-projects'` (`packages/api/src/app/settings.service.ts:15-24`). 각 Feature 에 대응하는 세부 타입(`AppInstallPromotionSetting`, `BnbStoreTabSetting`, `FundingStoryApiSetting` 등)도 동일 파일에 정의.
- `app/support.service.ts` — `getTicketsQuery(accessToken, params?)` 티켓 목록 (`/api/v1/support/tickets`, Bearer 인증). `APP_API_DOMAIN` 을 재선언해 환경별 분기.

### A.3 `platform/` (공통 플랫폼 API)

- `platform/nicepay.service.ts` — Nicepay PG 연동 (`getLongTermInstallmentQuery`).
- `platform/share.service.ts` — 공유 기능.
- `platform/inbox.service.ts` — 인박스/쪽지.
- `platform/notification.service.ts` — 알림 토큰/설정.
- `platform/marketingconsents.service.ts` — 마케팅 수신 동의.
- `platform/global/exchange-rate.service.ts` — 환율 목록. `Bearer ${process.env.PLATFORM_GLOBAL_API_TOKEN}` 헤더 필수. `CurrencySettings` 가 초기화 시 호출.
- `platform/global/translate.service.ts` — 번역 게이트웨이(외부 번역 API 래퍼 추정).

### A.4 기타

- `search/search.service.ts` (검색·카테고리·서비스 홈). `SERVICE_API_URL` 또는 `window.wadiz.globals.serviceApiHost` fallback 사용(`packages/api/src/search/search.service.ts:51`). `ProductType = 'COMING_SOON' | 'FUNDING' | 'PREORDER' | 'STORE'`, `ServiceType = 'ALL' | 'FUNDING' | 'STORE'`. `createCategoryMap(categories)` 가 BFS 로 `Map<categoryCode, Category>` 생성 유틸 제공.
- `search/home.service.ts`, `search/integrate.service.ts` — 홈·통합 검색.
- `wai/chatHistory.service.ts` — `dev-aidata.wadiz.kr` / `aidata.wadiz.kr` (`WAI_URL`), Bearer 토큰. `{ code: 'UNAUTHORIZED' | 'SESSION_ACCESS_DENIED' | 'SESSION_NOT_FOUND' | 'INTERNAL_ERROR' }` 에러 스키마.
- `account/account.service.ts` — account 서버 직접 호출(위 4.1 참고).
- `activities/`, `admin/`, `collection/`, `friends/`, `inbox/`, `keyword/`, `main2/` (MyWadiz 메인), `makercenter/`, `oauth/`, `public/`, `searcher/`, `terms/`, `wadizad/` (광고), `wish/` — 각 도메인 단일 service 파일.
- `createPostForm.ts` — FormData 빌드 유틸(파일 업로드에 사용).

### A.5 Mock 파일

다수 서비스 디렉터리에 `mocks/` 폴더가 있습니다(`packages/api/src/main2/mocks/`, `packages/api/src/web/mocks/`, `packages/api/src/web/funding/mocks/`, `packages/api/src/web/reward/mocks/`, `packages/api/src/web/funding/global/mocks/`, `packages/api/src/search/mocks/`, `packages/api/src/inbox/mocks/`, `packages/api/src/collection/mocks/`, `packages/api/src/admin/mocks/`, `packages/api/src/platform/mocks/`). `packages/CLAUDE.md:58-60` 규정상 `process.env.NODE_ENV === 'development'` 가드로 분기 후 import 되며, 빌드 시 esbuild `drop` 으로 제거됩니다(`apps/global/vite.config.ts:59-61` — `env.VITE_ENVIRONMENT === 'live'` 일 때 console/debugger 제거; mock 은 NODE_ENV 분기).

---

## 부록 B. `@wadiz/core` 서브모듈 맵

서브디렉터리별 관측 가능한 구성.

### B.1 `core/hooks/`

30개 훅(`packages/core/src/hooks/`). 주요 훅:

| 훅 | 파일 | 역할(관찰) |
|---|---|---|
| `useBrowserStorage` | `useBrowserStorage.ts` | localStorage/sessionStorage 래퍼(`useLocalStorage`, `useSessionStorage`, `clearDataFromStorage` 등) |
| `useInView` / `useElementInView` | `useInView.ts` | IntersectionObserver 노출 감지 |
| `useResizeObserver` | `useResizeObserver.ts` | `useHeightObserver`, `useWidthObserver`, with-element 버전 |
| `usePageShow` | `usePageShow.ts` | `pageshow` 이벤트 훅(bfcache 포함) |
| `usePageView` | `usePageView.ts` | SPA 페이지뷰 추적 연동 |
| `usePreventBfcache` | `usePreventBfcache.ts` | `unload` 리스너로 bfcache 차단 |
| `useIsPreviewMode` | `useIsPreviewMode.ts` | URL 쿼리 `preview=Y` 검증 (`getIsPreviewMode`, `getPreviewInformation`) |
| `useURLSearchParams` | `useURLSearchParams.ts` | 타입 있는 URL 쿼리 훅(`getURLSearchParams`) |
| `useModalWithHistoryBack` | `useModalWithHistoryBack.ts` | 뒤로가기 시 모달 닫기 |
| `useOnWadizAppPageShow` | `useOnWadizAppPageShow.ts` | 네이티브 앱 pageshow 이벤트 |
| `useAppFlag` | `useAppFlag.ts` | 앱 런타임 플래그 |
| `useElementHeightTracker` | `useElementHeightTracker.ts` | `useRegisterNamedElementHeightRef`/`useNamedElementHeightTracker` 고정 UI 높이 측정 |
| `useFormattedNumberInput` | `useFormattedNumberInput.ts` | 숫자 입력 포맷 |
| `useHorizontalTabScrollNavigator` | `useHorizontalTabScrollNavigator.ts` | 가로 스크롤 탭 인디케이터 |
| `useHover`, `useForceRender`, `useAutoIndex`, `useSwipe`, `useSwipeView` | — | 범용 유틸 |
| `useScrollDirection` (`useScrollUp`, `useScrollDown`) | `useScrollDirection.js` | 스크롤 방향 감지 (JS) |
| `useInfiniteScrollWithReactQuery` | `useInfiniteScrollWithReactQuery.js` | TanStack Query 기반 무한 스크롤 |
| `useFollowCountNotation` | `useFollowCountNotation.js` | 팔로우 수 표기(`1.2k` 등) |
| `useOncePerSession` | `useOncePerSession.ts` | 세션 1회 실행 가드 |
| `useSmartScrollRestoration` | `useSmartScrollRestoration.ts` | 라우팅 간 스크롤 복구 |
| `useScrollSpyWithElements` | `useScrollSpyWithElements.ts` | 스크롤 스파이 |
| `PathChangeObserver` | `PathChangeObserver.ts` | URL path 변경 감지 유틸(+테스트) |
| `useWAiAIAgent` | `useWAiAIAgent.ts` | WAi AI Agent 런처 상태 |

### B.2 `core/lib/`

- `AppConfig.ts` — 네이티브 앱이 주입한 설정(`window.wadiz.appConfig`) 또는 bridge 요청(`requestId` 기반). `initialize()` 를 `@wadiz/app-initializer/stages/initAppConfig.ts` 가 호출.
- `AppBridge/AppBridge.ts` — `webkit.messageHandlers` / `window.wadizBridge` 추상화. `webToApp` 이벤트 송출, `appToWeb` 이벤트 수신(`CustomEvent` 디스패치).
- `AppBridge/webToAppEvents.ts` — 48종 WebToApp 이벤트 유니언 타입 정의(모달·푸시·공유·로컬스토리지·pdfDownload·creditCard.scan·app.config.request·SPA 페이지 네비게이션 등; `packages/core/src/lib/AppBridge/webToAppEvents.ts:1-405`).
- `AppBridge/appToWebEvents.ts` — 반대 방향 이벤트 타입.
- `modalRegistry.ts` + `useModalPortal.ts` — 중앙화된 모달 관리. `MODAL_NAMES` 상수, `useOpenModalPortal`, `useModalPortalState`, `useStripePaymentFormModal`.
- `presentUrl.ts` + `usePresentAction.ts` — "선물하기"(Present) 링크 URL 생성/파싱. `PresentMode` 타입.
- `goToLoginPage.ts`, `goToAdultVerificationPage.ts` — 공통 리다이렉트 유틸.
- `gaData.ts` — 프로젝트 카드 GA 데이터 생성(`getCardGADataFromCampaign`).
- `appMessageBridge2.ts` — 레거시 bridge(v2) 잔존.

### B.3 `core/metrics/` (= `@wadiz/metrics` alias)

- `sentry.ts` — `@sentry/react` 래핑. `Sentry.init`, `Sentry.fatal` (`Locale` 불일치 등에서 사용).
- `Metrics.ts` — Metrics 싱글톤(default export).
- `trackingEvent.ts` — `trackingEvent`, `trackingCustomTag({ category, action, label })` (GA 유니버설 이벤트).
- `trackingBraze.ts` — `trackingBraze('event'|'attr', key, value?)`.
- `captureError.ts`, `getLastEventId.ts`, `errorReportDialog.ts` — Sentry 보조.
- `ignoreErrors.ts` — Sentry 에서 무시할 에러 메시지 리스트.
- `integrations/` — Sentry integrations 커스터마이징.
- `hooks/` — `usePageView` 연동 훅들.

### B.4 `core/utils/` (= `@wadiz/utils` alias)

- `browser.js` — `isMSIE`, 브라우저 감지.
- `number.js` — `numberFormat` (`CurrencySettings.formatKRW` 가 사용).
- `date.js` — 날짜 포맷 헬퍼.
- `element.js` — DOM 요소 조작.
- `event.js`, `is.js`, `misc.js`, `page.js`, `string.js`, `url.js`, `user.js`, `xhr.js`, `action.js`, `file.js`, `logger.js` — 각 카테고리별 유틸(대부분 JS).
- `compareSemver.ts`, `loginController.ts` — TS.
- `ui/` — UI 관련 유틸 서브디렉터리.

### B.5 `core/policies/`

- `inAppWebviewPolicy.ts` — 앱 웹뷰 여부 감지, `isAppConfigSupported` 플래그, 앱 스킴/버전별 정책 판단.

### B.6 `core/analytics/`

- `PageViewTracker.ts` (+ 테스트·AC 문서) — SPA 페이지뷰 트래커. URL 변화 시 GA 페이지뷰 이벤트 발행.
- `WadizAnalytics.js` — 레거시 Wadiz 내부 수집 서버 클라이언트.
- `utils.js` — 공통 파라미터 빌더.

### B.7 `core/model/`

- `model/project/` — 프로젝트 타입 정의 + transformer. `project.types.ts` 에 `Project`, `LaunchingSoonProject`, `FundingProject`, `StoreProject` 정의. `transformers/` 에 `searchServiceHomeProjectTransformer` 등 서버 응답 → 앱 모델 변환기(`@wadiz/core/model` 로 `@wadiz/api/search/search.service.ts:1-8` 에서 import).

### B.8 루트 파일

- `locale.ts` — `Locale` 싱글톤 (위 2.5 참조).
- `eventBus.ts` — 전역 EventEmitter (위 2.5 참조).
- `cookie.ts` — `getCookie`, `getAllCookies`, `getAllCookiesSnapshot` (`@wadiz/api/account/account.service.ts:21-29` 에서 사용).
- `clipboard.js` — `writeToClipboard`, `writeToClipboardForExcelFormat`, `writeToClipboardFromInputElement`.
- `downloadPDF.ts` — PDF 다운로드 헬퍼(앱 환경에서는 `pdfDownload` WebToApp 이벤트 활용).
- `cardNumberValidator.ts` — Luhn 검증.
- `processStoryHTML.ts` — 프로젝트 스토리 HTML 전처리(이미지 lazy-loading, script 제거 등).
- `preloadImage.ts` — Image preload 헬퍼.
- `getOptimizedURL.ts` — CDN 최적화 URL 생성(`getOptimizedURL`, `getOptimizedURLByWidth`, `getOptimizedIntroURL`).
- `getAppSchemeURL.ts` — 앱 스킴(`wadiz://...`) 생성.
- `getURLS.ts` — `getAccountToWebURL` 등 공통 URL 생성.
- `getWeglotClass.ts` — Weglot 번역 제외 클래스 부착(`isWebsite` 체크).
- `getChildNodeCount.ts`, `jsonComparator.ts`, `formatIntlNumberWithLanguage.ts`, `addCustomEventListener.ts`, `checkAppVersion.ts`, `compareAppVersions.ts`, `routeUtil.ts` — 공통 유틸.

---

## 부록 C. `@wadiz/waffle` 컴포넌트 그룹 상세

`packages/waffle/src/` 는 각 컴포넌트 디렉터리 안에 `Component.tsx`, `Component.module.scss`, `index.ts`, (대부분) Storybook `*.stories.tsx` 구조.

- **폼 컨트롤**: `Input`, `TextField`, `Textarea`, `TextareaAutosize`, `Select`, `SelectMenu`, `Checkbox`, `Radio`, `Toggle`, `DatePicker`/`DateRangePicker`, `TimePicker`, `Rating`, `CategorySelector`, `VirtualNumberPadInput`, `PhoneNumberInput`(ui 쪽에 존재), `ImageEditor`(+ `ImageEditorModal`).
- **네비게이션**: `Tab`, `Tabs`, `TabPanels`, `SubTabs`, `HorizontalScrollLayout`.
- **컨테이너/레이아웃**: `CardTable`, `Divider`, `ImageSlider`, `BlindText`, `HelperMessage`, `Text`.
- **오버레이**: `Modal`(AlertModal, ConfirmModal, InfoModal, PostcodeModal + `modalUtil`), `Popper`, `Popover`, `Portal`, `Tooltip`, `Toast`(+ `toastUtil`).
- **상태/피드백**: `Loader`, `MessageBox`, `ErrorContent`(NotPermitted/Server/AppInit 3종), `Badge` 5종(Counter/Dot/Label/Notification/ReversalLabel).
- **미디어/텍스트**: `Avatar`, `MarkdownToHtml`(+ `MarkdownToHtmlWithTyping`), `WYSIWYGEditor`(Froala 기반), `Zendesk`(고객지원 위젯), `IconButton`, `Button`, `Geometry`(도형 유틸).
- **WAi**: `WAi/ChatForm`, `WAi/WAiAIAgentSymbol`, `WAi/Tip`(`TipItem` 타입).
- **locale**: `locale/` 디렉터리에 `LanguageProvider`, `LocaleProvider`(i18n context).
- **훅(공개 7개)**: `useCopy`, `useForkRef`, `useIsKeyboardOpen`, `useMediaQuery`, `useOutsideClickRef`, `useSwipe`, `useSwipeView` 별도, `useWindowSize`, `useHorizontalReveal`.
- **types**: `@types/`, `types.ts`, `constants.ts`.
- **스타일 엔트리**: `src/styles/style.scss` → `sass:build` 스크립트가 `style.css` 생성.

---

## 부록 D. 앱↔패키지 참조 매트릭스 (관찰)

`wadiz-frontend/apps/*/vite.config.ts` 의 alias 숫자(각 app 이 참조하는 `@wadiz/*` 패키지 수).

| app | vite.config alias 수 | 관찰 import 수(샘플) |
|---|---|---|
| `apps/global` | 16 | 65+ (`apps/global/src/` 30 파일에서 `@wadiz/*` import) |
| `apps/account` | 14 | 다수 |
| `apps/wai-ai-agent-launcher` | 15 | WAi 전용 |
| `apps/partnerzone` | 7 | 파트너존 |
| `apps/walink-generator` | 8 | 와링크 생성기 |
| `apps/devtools/component-playground` | 16 | waffle/icons 디버그 |

추가로 Next.js 앱들(`apps/ir`, `apps/partners`, `apps/help-center`, `apps/mail-template`) 은 `vite.config.ts` 가 아닌 `next.config.*` 를 사용하므로 본 alias 수치에 포함되지 않지만, `package.json` 의존성 및 소스 내 `@wadiz/*` 참조로 동일 패키지를 공유하는 것으로 관찰됩니다(정확한 수치는 이 문서 범위 밖).

### D.1 패키지가 요구하는 환경 변수(관찰)

| 변수 | 사용처 |
|---|---|
| `process.env.ENVIRONMENT` | `@wadiz/api/account`, `@wadiz/api/app/links`, `@wadiz/api/wai/chatHistory` (도메인 선택) |
| `process.env.ACCOUNT_URL` | account 서버 URL |
| `process.env.APP_API_URL` | app-api URL |
| `process.env.PLATFORM_API_URL`, `PLATFORM_MAIN2_API_URL` | platform 도메인 |
| `process.env.PLATFORM_GLOBAL_API_URL`, `PLATFORM_GLOBAL_API_TOKEN` | 환율 API (Bearer) |
| `process.env.SERVICE_API_URL` | 검색·카테고리 |
| `process.env.PUBLIC_API_URL` | 공개 API |
| `process.env.DATA_API_URL`, `ANALYTICS_URL` | 분석/데이터 수집 |
| `process.env.SENTRY_DSN`, `VITE_SENTRY_*` | Sentry 리포트 |
| `process.env.STATIC_URL` | CDN(이미지/onelink 설정) |
| `process.env.WEB_URL` | 레거시 www.wadiz.kr 리다이렉트 |
| `process.env.TOKEN_MARKETING`, `TOKEN_INBOX`, `TOKEN_KEYWORDS` | platform 보조 토큰 |
| `process.env.NODE_ENV` | mock 분기 |

모두 각 app `vite.config.ts:define` 에서 `VITE_*` 환경변수로 주입됩니다(`apps/global/vite.config.ts:76-96`).
