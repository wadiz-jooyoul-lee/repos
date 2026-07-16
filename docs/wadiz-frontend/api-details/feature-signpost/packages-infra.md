# 기능 이정표 — 인프라 · 디자인시스템 패키지

> 전체 인덱스는 [`README.md`](./README.md) 참조. 이 파일은 **화면 문구가 없는 공통 인프라/디자인시스템 패키지**의 역할·위치 참조입니다. UI 기능 패키지(`features`·`ui`·`widgets`)는 [`apps-global/`](./apps-global/README.md)에 있습니다.
> 깊이 있는 내부 구조는 기존 [`../packages.md`](../packages.md) 참조. 여기서는 "무엇을 고칠 때 어디를 보는가"만 빠르게 짚습니다.
> 레이어(상위→하위): `features` → (`i18n`·`queries`·`ui`) → `api` → (`core`·`format`·`settings`). 하위는 상위를 import하지 않습니다.

## 데이터 · API

| 패키지 | 역할 | 주요 위치 / 진입점 |
|---|---|---|
| `@wadiz/api` | HTTP 클라이언트 + 도메인별 service. **namespace import 규칙**(`CouponService.ProjectType`). fetch 래퍼(헤더 `wadiz-country`·`wadiz-language`, 401/403 리다이렉트, cloud TLD 판별) | `packages/api/src/fetch.ts` (래퍼), `packages/api/src/{account,app,collection,friends,inbox,keyword,coupon,funding,web,...}/*.service.ts` |
| `@wadiz/queries` | TanStack Query 래퍼 훅(세션/토큰·로그인 여부·국가·안읽은 메시지 등 공통 쿼리) | `packages/queries/src/{useSession2tokenQuery,useIsLoggedInQuery,useCountriesQuery,useUnreadMessageCountQuery}.ts` |

## 공통 함수 (최하위 레이어)

| 패키지 | 역할 | 주요 위치 |
|---|---|---|
| `@wadiz/core` | 범용 유틸(쿠키·클립보드·eventBus·앱버전 체크·PDF·환경) + **analytics/metrics**(트래킹·Sentry·Braze·captureError) | `packages/core/src/*.ts`, `packages/core/src/metrics/{Metrics,trackingBraze,sentry,captureError}.ts`(= `@wadiz/metrics`), `packages/core/src/utils` |
| `@wadiz/format` | 숫자·통화·날짜·쿠폰 할인 포맷 유틸 | `packages/format/src/{formatCurrency,formatDisplayAmount,formatIntlDateTime,formatCouponDiscount,dateFromNow}.ts` |
| `@wadiz/settings` | 계정·앱·통화·로케일 설정 싱글턴/훅(세션 초기화 등) | `packages/settings/src/{AccountSettings,AppSettings,CurrencySettings,LocaleSettings}.ts` |
| `@wadiz/event-tracker` | 지면별 GA/트래킹 정의(도메인별 `*.tracker.ts`) | `packages/event-tracker/src/{funding-detail,home,coupon,create-project,maker-home,ecommerce,...}.tracker.ts` |
| `@wadiz/app-initializer` | 앱 부트스트랩(전역 `window.wadiz` 셋업·초기화 단계) | `packages/app-initializer/src/{AppInitializer.tsx,setupWadizGlobal.ts,stages/}` |

## 다국어

| 패키지 | 역할 | 주요 위치 |
|---|---|---|
| `@wadiz/i18n` | i18next 인스턴스 + 언어 리소스. **화면 문구 실제 텍스트의 출처**(이 이정표 전반의 i18n 키가 여기로 해석됨) | `packages/i18n/src/i18n.ts`, `packages/i18n/src/supporter/languages/{ko,en,ja,zh}.json`, `packages/i18n/src/{mail-template,wai-ai-agent-launcher}/languages/` |

## 디자인시스템

| 패키지 | 역할 | 주요 위치 |
|---|---|---|
| `@wadiz/tokens` | 디자인 토큰(색·타이포·간격)을 css/scss/js로 산출 | `packages/tokens/src/{css,scss,js}` |
| `@wadiz/waffle` | 와디즈 디자인 시스템 컴포넌트. **서브경로 import**(`@wadiz/waffle/Button`) | `packages/waffle/src/*` |
| `@wadiz/waffle-icons` | 디자인 시스템 아이콘. generate 스크립트로 `src/components/` + `index.ts` 생성 | `packages/waffle-icons/src/components/*`, `index.ts` |
| `@wadiz/artworks` | 아트웍(일러스트) 컴포넌트. waffle-icons와 동일 구조 | `packages/artworks/src/` |

## 비 소스 · 빈/placeholder 패키지 (참고)

| 패키지 | 상태(사실) |
|---|---|
| `cert` | JS 패키지가 아님 — 로컬 개발용 TLS 인증서(`local.wadiz.crt`·`local.wadiz.key`) 보관 |
| `sentry` · `store` · `events` | `src`에 소스 파일 없음(빈/placeholder). Sentry 실제 구현은 `@wadiz/core`의 `core/src/metrics/sentry.ts` |

## 이슈 히스토리 (인프라 패키지 관련)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-3 | 작업 | [Web] static main 번들 사이즈 개선을 위한 waffle-icons, artworks 작업 |
| FE1-26 | 작업 | [Web] wadiz-frontend waffle-icons, artworks의 barrel 참조 제거 |
| FE1-235 | 작업 | @wadiz/artworks alias 설정 확인 - apps, static, packages, studio |
| FE1-613 | 작업 | WEB - gradation -> gradient로 수정 / deprecated color token 삭제 |
| FE1-909 | 작업 | [app-api] auth header 의 bearer token 삭제 |
| FE1-1041 | 작업 | [Web] BE 쿠폰 정보 API 연동 |
| FE1-1060 | 작업 | [Web] wadiz.io 교체 작업 - cdev (fetch cloud 판별) |
| FE1-387 | 스토리 | [Web] axios 보안 이슈 대응 |
| FE2-735 | 작업 | [보안] wadiz-frontend Dependabot 경고 정리 |
