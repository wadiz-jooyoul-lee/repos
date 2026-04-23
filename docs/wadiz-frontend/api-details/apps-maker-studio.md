# wadiz-frontend - 메이커/스튜디오 apps + 특수 도구

> **기록 범위**
>
> 본 문서는 `wadiz-frontend` 모노레포 안에서 **직접 읽을 수 있는 코드**만 기록합니다.
> - 대상 경로: `studio/{funding,startup,store,studio-services}/`, `apps/{wai-ai-agent-launcher,walink-generator,mail-template,devtools}/`
> - 엔드포인트는 각 앱의 `services/`·`fetch-api/`·`api/` 폴더에서 `grep` 으로 추출한 literal URL 만 기록합니다. 런타임에 동적으로 조립되는 경로(예: `queryKey` 로만 존재)는 문자열 원문을 그대로 남깁니다.
> - Upstream 서버(도메인)는 **환경변수(`.env.*`)와 `studio-services/src/utils/fetch.ts` 의 매핑**에서 읽습니다. 변수 값 자체가 배포 도메인입니다.
> - FE 코드에서 호출되는 서버의 **내부 로직**(SQL/Kotlin 호출 스택 등)은 본 문서의 범위 밖입니다. 서버 측은 `docs/com.wadiz.web/`, `docs/makercenter-be/`, `docs/app-api/` 등을 참조하세요.

## 개요 — 앱별 성격

`studio/` 3개와 `apps/` 4개(5 바이너리)는 모두 `wadiz-frontend` 모노레포의 워크스페이스 진입점이며, 각 진입점은 독립된 Vite 번들을 생성합니다.

| 앱 | 대상 사용자 | 배포 형태 | 인증 | 핵심 upstream |
|---|---|---|---|---|
| `studio/funding` | 외부 메이커 (리워드 펀딩 개설자) | SPA (`/studio/reward/*`) | 쿠키 + 401→웹 리다이렉트 | `www.wadiz.kr` (web) + `/web/apip/funding/*` + `/web/reward/api/*` |
| `studio/startup` | 외부 메이커 (투자형/증권형 발행사) | SPA (`/studio/startup/*`) | Redux + `/web/account/isLoggedIn` | `/web/maker/studio/*`, `/web/startup/*`, `/web/maker-proxy/*` |
| `studio/store` | 외부 메이커 (스토어 판매자) | SPA (`/studio/store/:projectNo`) | Axios `withCredentials: true` | `/web/apip/store/studio/*`, `/web/reward/api/*`, `/web/apip/funding/*` |
| `studio/studio-services` | (shared library) | 빌드 산출물 없음 (TS 소스) | n/a | 공통 fetch 래퍼 + 13 개 서버 모듈 |
| `apps/wai-ai-agent-launcher` | **내부 + 외부** (와디즈 사이트 전반 로더 스크립트) | UMD lib (`main.js`) | 호스트 페이지 세션 상속 | WAi 페이지 (`https://{env}.wadiz.kr/web/wai`) — `iframe` 임베드 |
| `apps/walink-generator` | **내부 도구** (와디즈 URL 단축) | SPA | (토큰 없음) | `POST /api/v2/links` → `app.wadiz.kr` / `api.dev.wadiz.co/app` |
| `apps/mail-template` | **내부 도구** (마케팅/시스템 메일 템플릿 빌더) | 정적 HTML (S3) | n/a | — (빌드 타임에 Handlebars→HTML 변환) |
| `apps/devtools/app-settings-console` | **내부 도구** (관리자용 App Settings) | 개발 서버 (Express + Vite) | 하드코딩 Bearer Token / env | `{env}.app-api` `/api/{env}/v1/settings` 프록시 |
| `apps/devtools/component-playground` | **내부 도구** (waffle 컴포넌트 시연) | SPA | n/a | — |

---

## 1. `studio/funding` — 리워드 펀딩 스튜디오

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `wadiz-maker-studio` (`studio/funding/package.json:3`) |
| 제목 | "와디즈 메이커 스튜디오" |
| Homepage | `https://www.wadiz.kr/studio/` (`package.json:5`) |
| 빌드 도구 | Vite 6 (`vite.config.ts:47`) |
| 개발 서버 포트 | 3000 (`vite.config.ts:242`) — 호스트 `studio.wadiz.kr` (HMR) |
| 번들 outDir | `build/` (`vite.config.ts:61`) |
| 라우팅 | React Router v5 (`BrowserRouter + Switch`, `src/Root.tsx:97`) |
| 상태 관리 | Zustand + TanStack Query v5 + React Hook Form + Recoil 없음 |
| 스타일 | SCSS Modules + `@wadiz/waffle` (`vite.config.ts:124`) |
| 에러 추적 | Sentry (`@sentry/browser@5`, `src/setupSentry.ts`) |
| 앱 초기화 | `Settings.initialize()` → `Root` (`src/index.tsx:30`) |
| 폼 검증 | yup + `@hookform/resolvers` (`package.json:47-50`) |
| 데이터 그리드 | Handsontable 7.1 (`package.json:62`) |
| 시각화 | AmCharts 4 (`package.json:48-49`) |
| 다국어 | i18next 24 + `react-i18next` 15 |
| 테스트 | Vitest 3 + MSW 2.4 + Testing Library |
| 스토리북 | Storybook 8.6 (port 9009) |

### 환경변수 · upstream 매핑

`studio/funding/.env` 시리즈는 env-cmd 없이 Vite `--mode development.{dev,rc,rc2,rc3,stage}` / `production.{dev,rc,rc2,rc3,stage,live}` 으로 직접 로드됩니다 (`package.json:21-26`).

| 변수 | live 값 (`.env.production.live:1-27`) | dev 값 (`.env.development.dev:1-25`) |
|---|---|---|
| `VITE_ENVIRONMENT` | `live` | `dev` |
| `VITE_ANALYTICS_HOST` | `https://analytics.wadiz.kr` | `https://dev-analytics.wadiz.kr` |
| `VITE_PUBLIC_API_HOST` | `https://public-api.wadiz.kr` | `https://public-api-dev.wadiz.kr` |
| `VITE_SERVICE_API_HOST` | `https://service.wadiz.kr` | `https://dev-service.wadiz.kr` |
| `VITE_AI_WADIZDATA_HOST` | `https://genai.wadiz.kr` | `https://dev-gen.ai.wadizdata.com` |
| `VITE_AI_CHATDATA_HOST` | `wss://ws.ai.wadiz.kr` | `wss://dev-ws.ai.wadiz.kr` |
| `VITE_BIZ_CENTER_HOST` | `https://biz.wadiz.kr` | `https://dev.biz.wadiz.11h11m.net` |
| `VITE_AD_CENTER_HOST` | `https://ad.wadiz.kr` | `https://dev-ad.wadiz.kr` |
| `VITE_PLATFORM_CLOUDFRONT_HOST` | `https://cdn3.wadiz.kr` | `https://d1ruwxjthziwe4.cloudfront.net` |
| `VITE_FE_CLOUDFRONT_HOST` | `https://static.wadiz.kr` | `https://static-dev.wadiz.kr` |
| `VITE_APP_API_HOST` | `https://app.wadiz.kr` | `https://api.dev.wadiz.co/app` |
| `VITE_PLATFORM_API_URL` | `https://platform.wadiz.kr` | `/main2` (dev proxy) |
| `VITE_PLATFORM_MAIN2_API_URL` | `https://platform.wadiz.kr/main2` | `/main2` |
| `VITE_PLATFORM_GLOBAL_API_URL` | `https://platform.wadiz.kr/global` | `/global` |
| `VITE_PLATFORM_GLOBAL_API_TOKEN` | `38DC62...` (Bearer) | `27906F...` (dev Bearer) |
| `VITE_STATIC_WEB_URL` | `https://$STATIC_DEPLOYMENT_HOST/web` | (unset) |
| `DEV_SERVER_PROXY` | — | `https://dev.wadiz.kr` |
| `DEV_AUTH_SERVER_PROXY` | — | `https://dev-account.wadiz.kr` |
| `DEV_PLATFORM_MAIN2_API_PROXY` | — | `https://dev-platform.wadizcorp.net` |
| `DEV_PLATFORM_GLOBAL_API_PROXY` | — | `https://dev-platform.wadizcorp.net` |

**Vite define 주입** (`vite.config.ts:106-117`)

런타임 `process.env.*` 로 접근하는 값:

- `process.env.ENVIRONMENT = VITE_ENVIRONMENT`
- `process.env.REACT_APP_AI_WADIZDATA_HOST = VITE_AI_WADIZDATA_HOST`
- `process.env.REACT_APP_SERVICE_API_HOST = VITE_SERVICE_API_HOST`
- `process.env.REACT_APP_PUBLIC_API_HOST = VITE_PUBLIC_API_HOST`
- `process.env.PLATFORM_API_URL = VITE_PLATFORM_API_URL`
- `process.env.PLATFORM_MAIN2_API_URL = VITE_PLATFORM_MAIN2_API_URL`
- `process.env.PLATFORM_GLOBAL_API_URL = VITE_PLATFORM_GLOBAL_API_URL`
- `process.env.PLATFORM_GLOBAL_API_TOKEN = VITE_PLATFORM_GLOBAL_API_TOKEN`

**개발 서버 프록시** (`vite.config.ts:250-367`) — 10 개 경로가 upstream 으로 전달됩니다.

| prefix | target | 목적 |
|---|---|---|
| `/web`, `/resources` | `DEV_SERVER_PROXY` = `dev.wadiz.kr` | com.wadiz.web 레거시 (세션·WAR 리소스) |
| `/global`, `/noti-channel` | `DEV_PLATFORM_GLOBAL_API_PROXY` = `dev-platform.wadizcorp.net` | 플랫폼 (환율·번역·마케팅) |
| `/main2` | `DEV_PLATFORM_MAIN2_API_PROXY` = `dev-platform.wadizcorp.net` | 플랫폼 main2 API |
| `/oauth`, `/login`, `/signup`, `/social-signup`, `/social-link`, `/connect` | `DEV_AUTH_SERVER_PROXY` = `dev-account.wadiz.kr` | kr.wadiz.account OAuth2 IdP |

응답의 `Set-Cookie` 에서 `secure` 플래그를 제거(`vite.config.ts:29-34`), `Location` 헤더를 `http://studio.wadiz.kr:3000` 으로 리라이트(`vite.config.ts:21-27`).

### 라우트 구조

`src/Root.tsx:100-124` (React Router v5 `<Switch>`)

```
/studio/reward/registration         → Registration
/studio/reward/ai/:campaignID       → AIResult (AI 결과보기)
/studio/reward/history/:campaignID  → HistoryViewer (히스토리 뷰어)
/studio/reward/:campaignID/funding/story/translation  → StoryTranslation
/studio/reward/:campaignID          → Reward (중첩 라우터 루트)
(default)                            → NotFoundPage
```

**`Reward` 하위 페이지** (`src/pages/Reward/pages/`, 14 개)

- `FundingIntro/` — 프로젝트 시작 인트로
- `project/` — 기본 프로젝트 편집 (중첩)
  - `project/funding-plan/` — 펀딩 플랜 선택
  - `project/project-type/` — 프로젝트 타입
  - `project/reward-plan/` — 리워드 플랜
  - `project/story/` — 스토리 작성
  - `project/policy/` — 정책·환불·리스크
  - `project/maker-info/` — 메이커 정보
- `Funding/` — 펀딩 진행
- `DashboardComingReport/` — 오픈예정 대시보드 (서브: `acquisition`, `notification-summary`, `notification-users`)
- `DashboardFundingReport/` — 펀딩 대시보드 (서브: `acquisition`, `payment-summary`, `payment-users`)
- `DashboardPaymentReport/` — 결제 대시보드
- `News/` — 새소식
- `MakerQRCode/` — QR 생성
- `Settlement/SettlementDetail` — 정산 상세
- `SettlementInfo/` — 정산 정보
- `Schedule/` — 일정
- `Supporter/` — 서포터 관리
- `FundingMakerService/` — 메이커 부가 서비스

**그 외 탑레벨 라우트** (`src/pages/`)

- `registration/` — 최초 등록 플로우
- `ai-result/` — AI 스토리 생성 결과 (lazy `pages/ai-result/pages/story/StoryAIResult`)
- `history-viewer/` — 과거 버전 뷰어 (`pages/history-viewer/pages/story/Story`)
- `story-translation/` — 다국어 스토리 번역 뷰 (`pages/story-translation/pages/translation/Translation`)
- `app-install-guide/` — 앱 설치 가이드
- (LazyRouters 정의: `src/LazyRouters.tsx:9-62`)

### 기능↔API 매핑 테이블 (funding)

**모든 API 호출은 `studio-services` 를 통해 발생합니다. 즉 funding studio 는 `@wadiz/services` alias(`vite.config.ts:158`) 로 `studio/studio-services/src` 를 참조합니다.**

주요 Endpoint 요약 (relative path 는 `studio-services` fetch 래퍼의 prefix 로 해석):

| 기능 섹션 | Method + Path | Fetch 래퍼 | Upstream prefix |
|---|---|---|---|
| 로그인 상태 | GET `/web/account/isLoggedIn` | fetchWebAPI | `/web` |
| 카테고리 | GET `/web/reward/api/categories` | fetchWebAPI | `/web` |
| 계정 CRUD | POST `/web/v3/account` | fetchWebAPI | `/web` |
| 내정보 | GET `/web/waccount/ajaxMyInfo` | fetchWebAPI | `/web` |
| 마케팅 수신 동의 (국내) | GET `/web/v2/terms/marketing/consent/services`, POST `/web/v2/terms/marketing/consent/services/{code}?agree={bool}` | fetchWebAPI | `/web` |
| 마케팅 수신 동의 (플랫폼) | GET `/noti-channel/v2/marketingconsents?serviceCode={code}`, POST `/noti-channel/v2/marketingconsents` | fetchPlatformAPI | PLATFORM_API_URL |
| 홈 광고 배너 | GET `/main/info/RA1` | fetchPublicAPI | PUBLIC_API_HOST |
| 검색 카테고리 | GET `/api/search/v2/categories` | fetchServiceAPI | SERVICE_API_HOST |
| 진입 언어 | GET `/web/v1/maker/language` | fetchWebAPI | `/web` |
| 추천 국가 | GET `/web/v1/countries/maker?{params}` | fetchWebAPI | `/web` |
| 국가 timezone | GET `/web/v1/countries/time-zones` | fetchWebAPI | `/web` |
| 은행 코드 | GET `/bank-codes` | fetchRewardAPI | `/web/reward/api` |
| 국가 목록 (reward) | GET `/country` | fetchRewardAPI | `/web/reward/api` |
| 캠페인 기본 | GET `/campaigns/{campaignId}` | fetchRewardAPI | `/web/reward/api` |
| 오픈예정 예약 | GET `/campaigns/{campaignId}/open-reservations` | fetchRewardAPI | 〃 |
| 앵콜 가능 | GET `/campaigns/encore/{countryCode}` | fetchRewardAPI | 〃 |
| 캠페인 복사 | POST `/campaigns/copy-from/{src}/to/{dst}` | fetchRewardAPI | 〃 |
| 배송 국가 | GET `/campaigns/{campaignId}/shippingCountry`, GET `/campaigns/{campaignId}/has-domestic-shipping` | fetchRewardAPI | 〃 |
| 패키지 플랜 | GET `/package-plans/{campaignId}`, GET `/package-plans/{campaignId}/types/EXPERT/question-and-answers` | fetchRewardAPI | 〃 |
| 패키지 플랜 (v2 studio API) | GET/POST `/web/apip/funding/studio/{campaignId}/pricing` | fetchAPI 직접 | `/web` |
| 메이커 (studios v1) | GET `/makers/campaigns/{campaignId}`, GET `/makers/campaigns/{id}/members/is-valid?email=` | fetchRewardAPI | `/web/reward/api` |
| 메이커 - 내 리워드 요약 | GET `/makers/my/summations/campaigns` | fetchRewardAPI | 〃 |
| 메이커 공용 설정 | GET `/web/reward/api/studios/maker/{available-countries,write-languages,use-languages}` | fetchWebAPI | `/web` |
| studios 루트 | POST `/studios` | fetchRewardAPI | `/web/reward/api` |
| 캠페인 스튜디오 상세 | GET `/studios/campaigns/{campaignId}`, `/studios/campaigns/{id}/sections/status` | fetchRewardAPI | 〃 |
| 캠페인 스케줄 | GET `/v2/studios/campaigns/{id}/schedule`, PUT `/v2/studios/campaigns/{id}/schedule`, POST `/v2/studios/campaigns/{id}/schedule/recommended-time`, POST `/v2/studios/campaigns/{id}/schedule/closed-status-global`, PUT `/web/reward/api/v2/studios/campaigns/{id}/schedule/valid-range-reward` | fetchRewardAPI / fetchWebAPI | 〃 |
| 성공 스토리 | GET/POST/DELETE `/studios/campaigns/{campaignId}/success-stories` | fetchRewardAPI | 〃 |
| 스토리 섹션 | POST `/studios/campaigns/{id}/sections/plan`, POST `/studios/campaigns/{id}/sections/risk-policy`, GET/POST `/studios/campaigns/{id}/sections/requirement`, POST `/studios/campaigns/{id}/sections/maker-info`, POST `/studios/campaigns/{id}/sections/maker-info/translate`, POST `/studios/campaigns/{id}/sections/contract-info` | fetchRewardAPI | 〃 |
| 제출 | POST `/web/reward/api/studios/campaigns/{id}/submit`, POST `/web/reward/api/studios/campaigns/{id}/re-submit` | fetchWebAPI | `/web` |
| 국가 변경 | POST `/web/reward/api/studios/campaigns/{id}/change-country` | fetchWebAPI | `/web` |
| 인트로 통과 | POST `/studios/campaigns/{id}/pass-intro` | fetchRewardAPI | `/web/reward/api` |
| 이미지 | POST `/studios/campaigns/{id}/images` | fetchRewardAPI | 〃 |
| 섹션 수정 가능 여부 | GET `/studios/campaigns/{id}/section-items/SCREENING_REWARD_ITEM/is-modifiable` | fetchRewardAPI | 〃 |
| 리워드 아이템 (v2 global) | GET `/v2/studios/campaigns/{id}/sections/global/reward`, GET `/v2/studios/campaigns/{id}/sections/global/reward-item/{rewardId}/{languageId}`, GET `/v2/studios/campaigns/{id}/sections/reward-item/{rewardId}`, GET `/v2/studios/campaigns/{id}/sections/reward` | fetchRewardAPI | 〃 |
| 리워드 수량 | GET `/fundings/campaigns/{campaignId}/reward-items/{rewardId}/qty` | fetchRewardAPI | 〃 |
| 스토리 | fetchRewardAPI(`queryKey`) → `/web/reward/api/v2/stories/{id}/{lang}` (neue API) + `studios/campaigns/{id}` 내 story 섹션 | — | 〃 |
| 서포터/오픈예정 상태 | GET `/web/progress/dashboard/{campaignId}/supporter`, POST `/web/progress/dashboard/ajaxSupporterAuthCheck?campaignId=`, POST `/web/progress/dashboard/ajaxMakerCertificationNumberIssued`, GET `/web/progress/dashboard/{id}/supporterInfo?excelDownloadType={type}` | fetchWebAPI | `/web` |
| 결제진행 대시보드 | GET `/web/apip/funding/studio/payment-progress/campaigns/{id}/report` | fetchWebAPI | `/web` |
| 환불 | GET `/refunds/{backingPaymentId}/for-approval`, `/refunds/{id}/amounts?backingIds=`, `/refunds/reason-title`, `/refunds/application-reason-types`, POST `/refunds/{id}/reject`, POST `/refunds/{id}/approve`, GET `/refunds/{id}/backings/{backingId}/logs`, GET `/refunds/{id}/backings/{backingId}`, POST `/refunds/{id}/{backingId}?typeCode=`, POST `refunds/{id}/{backingId}/holding?timezone=` | fetchRewardAPI | `/web/reward/api` |
| 환불 캠페인 집계 | GET `/refunds/campaigns/{campaignId}/aggregates/qty-by-status` | fetchRewardAPI | 〃 |
| 결제 상세 | GET `/backing-payments/{backingPaymentId}` | fetchRewardAPI | 〃 |
| 정산 | GET `/settlements/campaigns/{id}/fee-version`, `/settlements/campaigns/{id}/settlement-files`, `/settlements/campaigns/{id}/contractors`, POST `/studios/campaigns/{id}/sections/contract-info`, POST `/settlements/campaigns/{id}/contractors/files?documentType=COPY_OF_BANKBOOK`, GET `/settlements/fees/campaigns/{id}`, GET `/settlements/v1/campaign/{id}/verification` | fetchRewardAPI | 〃 |
| 정산명세서 / 시스템 | fetchFundingStudioAPI(`url`) — 프로그램 리다이렉트, 정확한 경로는 `studio-services/src/servers/reward/apis/settlements/campaigns.ts:145-161` 참조 | fetchFundingStudioAPI | `/web/apip/funding/studio` |
| 배송 — 국가/요약/리스트 | GET `/studio/shipping/campaigns/{id}/countries`, GET `/shipments/campaigns/{id}/summary`, GET `/shipments/campaigns/{id}?{query}`, GET `/shipments/carriers` | fetchRewardAPI (shipments) / fetchFundingAPI (studio) | `/web/reward/api`, `/web/apip/funding` |
| 배송 일괄 처리 | POST `/shipments/campaigns/{id}`, POST `/shipments/campaigns/{id}/excel`, POST `/shipments/campaigns/{id}/excel/{token}`, POST `/shipments/campaigns/{id}/prepare`, GET `/shipments/campaigns/{id}/preparation-status` | fetchRewardAPI | `/web/reward/api` |
| 스크리닝 요구사항 | GET `/screenings/campaigns/{id}/requirements/reward-items`, POST `/screenings/campaigns/{id}/requirements/files/{documentType}`, POST `/screenings/campaigns/{id}/business-licenses`, GET/POST `/screenings/campaigns/{id}/requirements/kc-documents` | fetchRewardAPI | 〃 |
| 스크리닝 문서 템플릿 | GET `/screenings/document/{categoryCode}/{productType}?isSimpleDistributor=`, `/screenings/document/{categoryCode}` | fetchRewardAPI | 〃 |
| 스크리닝 카테고리 | GET `/screenings/reward-item-categories/{categoryCode}/production-types`, `screenings/reward-item-categories/{code}`, `screenings/reward-item-categories/search?categoryName=` | fetchRewardAPI | 〃 |
| 리스크 정책 | GET `/risk-policies/campaigns/{id}`, GET `/risk-policies/information-notice-categories`, GET `/risk-policies/information-notice-categories/{catId}/items` | fetchRewardAPI | 〃 |
| 환불 정책 | GET `/refund-policies/campaigns/{id}` | fetchRewardAPI | 〃 |
| 메이커 커뮤니케이션 | GET `/maker-communications/campaigns/{id}/sections/{page}/feedbacks?excludeLatest=true`, `/maker-communications/campaigns/{id}/sections/{page}/feedbacks/latest`, `/maker-communications/campaigns/{id}/sections/REQUIREMENT/qnas/latest` (이어지는 라인: `studio-services/src/servers/reward/apis/maker-communications/campaigns.ts:20-63`) | fetchRewardAPI | 〃 |
| 새소식 (funding studio) | GET/POST/PUT/DELETE `/campaigns/{id}/news`, GET `/campaigns/{id}/news/check-write-status`, GET `/campaigns/{id}/news/tags` (라인: `studio-services/src/servers/funding/apis/studio/campaigns.ts:73-194`) | fetchFundingAPI | `/web/apip/funding` |
| 공지 (스튜디오 배너) | GET `/announcements?page=&size=`, GET `/announcements/new/qty/by-user`, POST `/announcements/exposure/{seq}`, GET `/announcements/by-menu`, POST `/announcements/{menuType}/do-not-show-again` | fetchFundingStudioAPI | `/web/apip/funding/studio` |
| 안전번호 | GET `/safe-number/campaigns/{id}`, POST `/safe-number/campaigns/{id}/{status}` | fetchFundingAPI | `/web/apip/funding` |
| 첨부 | POST `/attachments/friend-talk`, POST `/attachments/presign` | fetchFundingAPI | 〃 |
| 이미지 | (`studio-services/src/servers/funding/apis/images.ts`) | fetchFundingAPI | 〃 |
| KCertification | GET `/kcertification/info?certId=&providerType=` | fetchFundingAPI | 〃 |
| 상품정보고시 카테고리 | GET `/product-info-notice/categories` | fetchFundingStudioAPI | `/web/apip/funding/studio` |
| 메이커 초대 | GET `/maker-invitations/invitees/validity`, GET `/maker-invitations/codes/{code}/validity-for-invitee?campaignId=`, GET `/maker-invitations/by-campaign?campaignId=` | fetchFundingAPI | `/web/apip/funding` |
| 은행 계좌/사업자등록 인증 | POST `/v1/campaigns/{id}/bank-accounts/verify`, POST `/v1/campaigns/{id}/business-licenses/verify` | fetchFundingAPI | 〃 |
| 대표자 본인인증 | GET `/v1/campaigns/{id}/representative/authentication/required`, GET `/v1/campaigns/{id}/representative-verifies` | fetchRewardAPI | `/web/reward/api` |
| Final approved (v1) | GET `/campaigns/v1/final-approved-campaign-by-corptype/{countryCode}` | fetchRewardAPI | 〃 |
| 메이커 복사 (v1) | GET `/getCopyMakerInformationPath(src, dst)` (helper in `reward/apis/v1/campaigns.ts:68`) | fetchRewardAPI | 〃 |
| 환율 (global) | GET `/exchange-rates`, `/exchange-rates/{countryCode}` | fetchGlobalAPI | PLATFORM_GLOBAL_API_URL |
| 번역 (global) | POST `/translate/html`, POST `/translate/text` | fetchGlobalAPI | 〃 |
| 어드민 - 매출 세금 | GET `/web/backoffice/sales/v2/tax-accruals/{corpNo}/summary?from=&to=` | fetchWebAPI | `/web` |
| 메이커 가이드 (AI) | POST `/maker/guide` | fetchAIDataAPI | `REACT_APP_AI_WADIZDATA_HOST` |
| 메이커 리워드 (web API) | fetchWebAPI(`queryKey`) — `/web/reward/api/studios/maker/*` (ts: `studio-services/src/servers/web/apis/maker.ts:55,65`) | fetchWebAPI | `/web` |
| 상세 대시보드 (progress dashboard) | GET `/web/progress/dashboard/...` (이미 상단) | fetchWebAPI | `/web` |

> 개별 파일은 `studio/studio-services/src/servers/{reward,funding,store,...}/apis/*.ts` 에 있으며, `studio/funding` 은 alias `@wadiz/services` 로 참조합니다.

### 공유 packages 의존성 (funding)

`vite.config.ts:150-164` 의 `resolve.alias`:

- `@wadiz/metrics` → `packages/core/src/metrics`
- `@wadiz/utils` → `packages/core/src/utils`
- `@wadiz/types` → `packages/core/src/type`
- `@wadiz/waffle` → `packages/waffle/src`
- `@wadiz/waffle-icons` → `packages/waffle-icons/src/components`
- `@wadiz/artworks` → `packages/artworks/src/components`
- `@wadiz/core` → `packages/core/src`
- `@wadiz/services` → `studio/studio-services/src` (**shared service layer**)
- scss: `~@wadiz/waffle`, `~@wadiz/waffle-icons`, `~@wadiz/artworks-assets`

funding studio 전용 구조:

- `src/Root.tsx` — QueryClient onError 인터셉트 (401/403 → `useStore.setLogout` + `@wadiz/waffle.showToast`)
- `src/setupSentry.ts` — `@sentry/browser@5` 초기화
- `src/utils/fetchIntercepter/` — MSW 런타임 토글 UI
- Braze SDK 전역 초기화 (`src/Root.tsx:147-170`)

---

## 2. `studio/startup` — 투자형(증권형) 스타트업 스튜디오

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `wadiz-maker-page-studio` (`studio/startup/package.json:3`) |
| 제목 | "와디즈 메이커 페이지 스튜디오" |
| 빌드 도구 | Vite 6 (`vite.config.ts`) |
| 라우팅 | **React Router v6 data router** (`createBrowserRouter`, `src/Root.jsx:48`) — funding/store 와 차별점 |
| 상태 관리 | **Redux (store legacy) + Redux Thunk + RHF + TanStack Query v5** (`CLAUDE.md:14-21`) — Redux 잔존 |
| 에러 추적 | Sentry (`@sentry/browser@5`) |
| 진입 | `Root({ store })` (`src/Root.jsx:52`) |
| 개발 서버 포트 | 3000 (`vite.config.ts:239`) |
| API 레이어 | **자체 `src/fetch-api/`** (studio-services 와 분리). JS 구현. |
| 프록시 | `/web`, `/resources`, `/oauth`, `/login`, `/signup`, `/social-signup`, `/social-link`, `/connect` (`vite.config.ts:247-337`) |

### 환경변수 (startup)

`.env.production.live`

- `VITE_ENVIRONMENT=live`
- `VITE_AD_CENTER_HOST=https://ad.wadiz.kr`
- `VITE_ANALYTICS_HOST=https://analytics.wadiz.kr`
- `VITE_PUBLIC_API_HOST=https://public-api.wadiz.kr`
- `VITE_SERVICE_API_HOST=https://service.wadiz.kr`
- `VITE_STATIC_WEB_URL=https://$STATIC_DEPLOYMENT_HOST/web`
- `VITE_SENTRY_*`

`.env.development.dev`

- `DEV_SERVER_PROXY=https://dev.wadiz.kr`
- `DEV_AUTH_SERVER_PROXY=https://dev-account.wadiz.kr`

> startup 은 funding 과 달리 `PLATFORM_*` / `AI_*` 환경변수가 없습니다. **레거시 `com.wadiz.web` (`/web/maker/*`, `/web/startup/*`) 를 강하게 바라봅니다.**

### 라우트 구조 (startup)

`src/routes/Startup/routes.js` (참조) + `src/routes/Startup/pages/` 목록:

- `StartupBaseInfo` — 기본 정보
- `StartupProductDescription` — 제품 설명
- `StartupCoreMessage` — 핵심 메시지
- `StartupCoreSpec` — 핵심 스펙
- `StartupBizAndTech` — 사업·기술
- `StartupBusinessModel` — 비즈니스 모델
- `StartupInvestment` / `StartupInvestmentEdit` — 투자 이력 / 수정
- `StartupPitching` — 피칭 영상
- `MakerPageHome` — 메이커 페이지 홈
- `MakerFinanceAndCertification` — 재무·인증
- `MakerImpression` — 메이커 인상
- `MakerNewsManagement` / `MakerNewsSurvey` — 새소식 관리/설문
- `NewsStatistics` — 새소식 통계
- `NewsWrite` — 새소식 작성
- `MakerQRCode` — QR 생성
- `TaxReport` — 세금 리포트

루트 URL 은 `basename` 을 `getBaseURL()` (studio-utils) 으로 받아 `/studio/startup` 아래 매핑됩니다.

### 기능↔API 매핑 (startup)

`src/fetch-api/fetchApi.js:29-108` 에서 8 개 래퍼 export. 실제 호출은 **전량 `fetchWebApi`** 로 `/web/...` 경로를 호출합니다 (`com.wadiz.web` 레거시).

| 기능 | Method + Path | 파일 |
|---|---|---|
| 로그인 상태 | POST `/web/account/isLoggedIn` | `fetch-api/web/index.js:7` |
| 메이커 약관 동의 필요 목록 | GET `/web/maker/terms/{corpNo}/getMakerTermsNeedToAccept` | `fetch-api/account/admin.js:4` |
| 어드민 요청 사용자 | POST `/web/maker/adminRequest/user` | `fetch-api/account/admin.js:15` |
| 약관 동의자 | GET/POST `/web/v2/terms/accepter` | `fetch-api/account/accepter.js:4,8` |
| 법인 정보 | GET `/web/startup/corporation/{corpNo}` | `fetch-api/startup/common.js:4` |
| 공통 code map | GET `/web/startup/common/codeMap` | `common.js:8` |
| 투자희망 질문 예시 | GET `/web/startup/common/questionExampleList?questionType=STARTUP_INVESTMENT_HOPE` | `common.js:12` |
| 법인 이미지 업로드 | POST `/web/startup/corporation/{corpNo}/upload/image` | `common.js:16` |
| 법인 파일 업로드 | POST `/web/startup/corporation/{corpNo}/upload/file` | `common.js:23` |
| 팀원 권한 체크 | GET `/web/startup/corporation/{corpNo}/teamMember/hasAuth` | `common.js:30` |
| 로고 업로드 | POST `/web/maker/studio/{corpNo}/logo` | `common.js:37` |
| 기본 정보 (maker studio) | GET/POST `/web/maker/studio/{corpNo}/basic/hidden` | `baseInfo.js:9,19` |
| 제품 설명 | POST `/web/maker/studio/{corpNo}/introduce` | `productDescription.js:4` |
| 인상 GET/POST | GET/POST `/web/maker/studio/{corpNo}/impression` | `impression.js:8,27` |
| 핵심 메시지 | GET/POST `/web/startup/corporation/{corpNo}/coreMessage` | `coreMessage.js:4,8` |
| 핵심 스펙 | POST `/web/maker/studio/{corpNo}/coreSpec` | `coreSpec.js:4` |
| 비즈니스·기술 | GET/POST `/web/maker/studio/{corpNo}/businessTechnology` | `bizAndTech.js:3,6` |
| 비즈니스 모델 | POST `/web/maker/studio/{corpNo}/businessModel` | `businessModel.js:4` |
| KED 정보 | GET `/web/maker/studio/{corpNo}/ked`, GET/POST `/web/maker/studio/{corpNo}/ked/hidden` | `ked.js:4,8,23` |
| 투자 이력 CRUD | GET/POST `/web/maker/studio/{corpNo}/investmentHistory(/{add,modify,remove,modifySeq})` | `investment.js:4-29` |
| 투자 희망 | GET/POST `/web/startup/corporation/{corpNo}/investmentHope` | `attractInvest.js:4,8` |
| 피칭 영상 | GET/POST/DELETE `/web/maker/studio/{corpNo}/(pitchingVideo|delete/pitchingVideo)` | `pitching.js:4-14` |
| 배너 | GET `/web/startup/common/banners?sectionCode=IST` | `ads.js:4` |
| 팀원 CRUD | GET `/web/startup/corporation/{corpNo}/teamMember`, POST `.../existWadizUserByUserName`, POST `.../add`, POST `.../{memberNo}/modify`, POST `.../{memberNo}/remove`, POST `.../modifySeq`, POST `.../{memberNo}/admin(/release)` | `startup/teamMember.js:4-48` |
| 새소식 (startup) | GET/POST/PUT/DELETE `/web/maker/studio/{corpNo}/news(/{newsId})`, `/web/maker/studio/{corpNo}/news/{id}/isDeletable`, files CRUD `/web/maker/{corpNo}/news/files{/fileId}`, 보상 확인 `/web/maker/REWARD/{campaignId}` | `news.js:5-76` |
| 푸시 | GET `/web/maker/{corpNo}/push/possible`, `/web/maker/{corpNo}/push/statistics/list?category=NEWS&...`, POST `/web/maker/{corpNo}/push/test`, GET `/web/maker/{corpNo}/follow/count`, GET `/web/maker/{corpNo}/notice/count`, GET `/web/maker/{corpNo}/push/credit`, + `fetchFundingApi(...)` (정확한 경로: `fetch-api/startup/push.js:32`) | `push.js:4-32` |
| 파일 업로드 | POST `/maker/upload/{corpNo}`, `/web/maker/upload/{corpNo}/file`, `/web/maker/upload/{corpNo}/image`, POST `/web/maker/upload/{corpNo}/remove`, POST `/web/maker/upload/{corpNo}/image/{photoID}/remove` | `file.js:10-69` |
| 연락처 관리 | GET `/web/startup/corporation/contact/detail/corpNo/{corpNo}`, POST `/web/startup/corporation/{corpNo}/contact`, POST `/web/startup/corporation/contact` | `contactsManagement.js:9-30` |
| 팀원(legacy top) | GET `/web/startup/corporation/{corpNo}/teamMember`, POST `.../existWadizUserByUserName`, POST URL(동적 via `fetchWebApi(url)`), POST `.../{memberNo}/remove`, POST `.../modifySeq` | `teamMember.js:4-32` |

### 공유 packages 의존성 (startup)

`studio/startup/vite.config.ts` 의 alias 는 **funding 과 동일한 `@wadiz/*` 세트**를 참조하지만, 서비스 레이어는 **`@wadiz/services` 를 통해 `studio-services` 를 쓰는 대신 자체 `src/fetch-api/`** 를 주력으로 사용합니다. 팀원 관리 같은 일부 기능은 양쪽에 모두 존재합니다 (구현 중복).

---

## 3. `studio/store` — 스토어 스튜디오

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `wadiz-store-maker-studio` (`studio/store/package.json:3`) |
| 제목 | "와디즈 스토어 메이커 스튜디오" |
| 라우팅 | React Router v5 (`BrowserRouter + Switch`, `src/App.tsx:50`) |
| 상태 관리 | **Redux Toolkit + react-redux 7 + redux-logger + TanStack Query** (`package.json:30-38`) |
| HTTP | **Axios 0.21** (`helpers/axios.ts:125` `axios.defaults.baseURL = '/web/apip/store/studio'`) |
| UI 프레임워크 | **Ant Design 5.12 + @wadiz/waffle 병행** — 3 스튜디오 중 유일 |
| 에디터 | Froala Editor 4 (`package.json:15`) |
| 진입 | `App({ store })` (`src/App.tsx:45`) |
| 라우트 prefix | `/studio/store/:projectNo` (`App.tsx:54`). `/studio/store` 단독 진입 시 `/web/error/serverError` 로 리다이렉트. |

### 환경변수 (store)

- `VITE_APP_API_HOST`, `VITE_PLATFORM_CLOUDFRONT_HOST` 등이 `.env.*` 에 정의됨 (`src/helpers/image.ts:149,166` 에서 사용).
- axios `baseURL` 은 `/web/apip/store/studio` 상대 경로 → 동일 도메인(`www.wadiz.kr`) 에 프록시됨.

### 라우트 구조 (store)

`src/containers/RootContainer.tsx` 안쪽에 스위치가 있으며, 탑레벨 `pages/` 는 7 도메인:

- `home/` — 스토어 홈
- `project/` — 프로젝트 (CRUD, 제출)
- `product/` — 상품 관리 (판매 단위)
- `sales/` — 주문/분쟁/정산 요청
- `settlement/` — 정산 명세서
- `inbound/` — 입고 관리
- `qrcode/` — QR 생성

### 기능↔API 매핑 (store)

axios baseURL prefix `/web/apip/store/studio` 가 모든 상대 경로에 자동으로 붙습니다. 단, `services/maker.ts` 와 `services/reward.ts` 는 호출 시 `baseURL` 을 override 합니다.

| 도메인 | Method + Path (상대) | 파일 |
|---|---|---|
| 로그인 상태 | GET `/isLoggedIn` (실제 `/web/apip/store/studio/isLoggedIn` → baseURL 기반) | `services/account.ts:7` — 주석 `const BASE_URL = '/web/account'` 이지만 baseURL 은 global 설정 유지 |
| 카테고리 | GET `/categories` | `services/store.ts:9` |
| 상품 집계 | GET `/projects/{projectNo}/products/aggregation` | `services/store.ts:21` |
| 첨부 업로드 | POST `/attachments` (multipart), POST `/attachments/presign` | `services/store.ts:34,43` |
| 약관 HTML | GET `/resources/terms/{termsID}.html` | `services/terms.ts:6` |
| 약관 동의 | GET/POST `/projects/{projectNo}/terms-agreements/{termsType}` | `services/terms.ts:17,26` |
| 기능 접근 정책 | GET `/projects/{projectNo}/feature-access-policies` | `services/project.ts:13` |
| 프로젝트 프로필 | GET `/projects/{projectNo}/profile` | `services/project.ts:22` |
| 프로젝트 오픈 | POST `projects/{projectNo}/open` | `services/project.ts:35` |
| 프로젝트 상세 | GET `/projects/{projectNo}`, GET `/projects/{projectNo}/products`, GET `projects/{projectNo}/submit-condition`, GET `/projects/{projectNo}/maker-business-info` | `pages/project/services/project.ts:77-162` |
| 프로젝트 저장 | PUT `/projects/{projectNo}/save`, `/save-by-admin`, `/save-restricted`, `/save-temporary`, `/save-temporary-by-admin` | `pages/project/services/project.ts:173-209` |
| 프로젝트 제출 | POST `/projects/{projectNo}/submit`, `/submit-by-admin` | `pages/project/services/project.ts:214,219` |
| 비즈니스 정보 동기화 | POST (경로 참조: `pages/project/services/project.ts:227`) | 〃 |
| 홈 — 사업 정보 동기화 타겟 | GET `/projects/{projectNo}/maker-business-info/sync-target` | `pages/home/services/project.ts:7` |
| 상품 — 판매단위 상품 | GET `/projects/{projectNo}/sales-unit-products(?params)`, POST `/projects/{projectNo}/sales-unit-products` | `pages/product/services/product.ts:39,62` |
| 분쟁 | GET `/disputes/{disputeNo}`, PUT `.../ack`, PUT `.../approve`, PUT `.../approve/exchange`, PUT `.../approve/refund`, PUT `.../postpone`, PUT `.../reject` | `pages/sales/services/order.ts:78-342` |
| 주문 목록/집계 | GET `/orders`, GET `/orders/aggregation`, GET `/orders/{orderNo}/refund-estimated-bill`, PUT `/orders/shippings/prepare`, GET `/projects/for-order` | `pages/sales/services/order.ts:137-375` |
| 결제 조회 | GET `/payments/order-no/{orderNo}` | `pages/sales/services/order.ts:145` |
| 배송 점검 | GET `/shippings/check` | `pages/sales/services/order.ts:166` |
| 출금 | POST `/withdraws` | `pages/sales/services/order.ts:245` |
| 입고 | GET `/projects/{projectNo}/inbounds(?params)`, GET `/projects/{projectNo}/inbounds/items`, `/inbounds/items/to-reorder`, `/inbounds/supplier`, PUT `/projects/{projectNo}/inbounds/items/{inboundFmsRef}/{inventoryItemCode}`, POST `/projects/{projectNo}/inbounds/orders`, DELETE `/projects/{projectNo}/inbounds/orders`, POST `/projects/{projectNo}/inbounds/orders/upload` (multipart) | `pages/inbound/services/inbound.ts:84-178` |
| 정산 통계 | GET `/settlement/sales/count(?params)`, GET (statements list) | `pages/settlement/services/settlement.ts:28,56` |
| 은행 코드 (reward) | GET `/bank-codes` with `baseURL: '/web/reward/api'` override | `services/reward.ts:14-17` |
| 배송사 목록 (reward) | GET `/shipments/carriers` (`queryKey: /web/reward/api/shipments/carriers`) | `services/reward.ts:25-27` |
| 상품정보고시 카테고리 (funding) | GET `/product-info-notice/categories` with `baseURL: '/web/apip/funding'` override | `services/funding.ts:5-8` |
| 메이커 법인 정보 | GET `/maker/STORE/{campaignId}` with `baseURL: '/web'` override | `services/maker.ts:37-38` |
| 검색 카테고리 (Service API) | GET `{VITE_SERVICE_API_HOST}/api/search/categories` | `services/serviceApi/search.ts:11` |
| External (S3 PUT) | `PUT` to presigned URL (raw `fetch` 사용) | `services/external.ts:1` |

### Axios 인터셉터 (store 특유)

- **중복 요청 방지**: `method+url+params+data` 키로 `pendingMap` 에 `CancelToken` 저장, 같은 조합 재요청 시 기존 요청 cancel (`helpers/axios.ts:22-55`).
- **로딩 스피너 디스패치**: `config.needsLoader` 가 true 면 `SHOW_LOADER`/`HIDE_LOADER` dispatch (`helpers/axios.ts:67-69,94`).
- **에러 캐치**: POST/PUT 은 `needsCatchError=true` 로 기본 처리 → Sentry 캡처. 그 외 요청은 `globalActions.setError(data)` 로 전역 Redux 에러 상태 설정 (`helpers/axios.ts:111-120`).
- **Cancel 구분**: 취소된 요청은 `error.code = 'CANCELED_WITH_DUPLICATE_REQUEST'` 추가 (`helpers/axios.ts:103-106`).
- baseURL: `/web/apip/store/studio`, `withCredentials: true` (`helpers/axios.ts:125-126`).

### 공유 packages 의존성 (store)

- Store 는 **`@wadiz/services` 를 alias 하지 않음** — 자체 `services/` 와 `axios` 만 사용.
- `@wadiz/waffle`, `@wadiz/metrics`, `@wadiz/utils/browser` 는 import (참조).
- `~assets/styles/lib/antd.scss` 로 Ant Design 스타일 커스텀 주입 (`App.tsx:16`).

---

## 4. `studio/studio-services` — 스튜디오 공용 서비스

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `@wadiz/services` (`studio/studio-services/package.json:2`) |
| 진입점 | `src/index.ts` (utils 만 export) |
| 빌드 산출물 | 없음 — 소스 그대로 alias 참조 |
| 사용처 | `studio/funding` 의 `vite.config.ts:158` (`@wadiz/services` alias) |

### 구조

1. **`src/utils/`** — 공용 HTTP 유틸
   - `fetch.ts` — **13 개 fetch 래퍼 (핵심)**, 하단 표 참조.
   - `FetchError.ts`, `JsonParseError.ts` — 커스텀 Error
   - `fetchUrl.ts`, `makeWebApiUrl.ts` — URL 조립
   - `parseAkamaiErrorString.ts` — Akamai CDN 에러 파싱
   - `queryString.ts` — qs 유틸

2. **`src/servers/`** (DEPRECATED) — 13 개 서버 모듈의 apis:
   - `account/` — `isLoggedIn`
   - `backoffice/` — `sales`
   - `funding/apis/` — attachments, images, kcertification, safe-number, studio/campaigns, studio/announcements, studio/shipping, product-info-notice/categories, v1/campaigns
   - `maker/` — guide (AI)
   - `maker-invitations/` — 초대 코드
   - `maker-proxy/apis/startup/maker.ts` — **`/web/maker-proxy/startup/maker/{corpNo}/*`** (dashboard, base, children)
   - `platform/apis/` — global/exchange-rate, global/translate, noti-channel/v2/marketingconsents
   - `progress/apis/` — dashboard (펀딩 진행 대시보드)
   - `public-api/apis/` — main
   - `reward/apis/` — backing-payments, bank-codes, campaigns, country, package-plans, studios, studios.ts + 하위 (maker-communications, shipments, stories, screenings, studios, settlements, refunds, refund-policies, risk-policies, comingsoons, makers, funding(campaigns), v1, v2)
   - `search/apis/` — categories
   - `store/apis/studio/` — projects, set-up-condition
   - `user/` — v1/maker, v2/terms
   - `web/apis/` — categories, maker, waccount, v1/countries, v3/account

3. **`src/api/web/`** (NEW 권장 구조, `CLAUDE.md:v2.0`) — 2 depth 폴더 규칙
   - `web/funding/` — studio-campaigns, studio-dashboard, studio-menus, studio-pricing
   - `web/reward/` — maker-communications, package-plans, story, studio-makers, studios-ai-review, studios-story

### Fetch 래퍼 (`utils/fetch.ts`)

| 래퍼 | Prefix 접두어 | Upstream 변수 | 라인 |
|---|---|---|---|
| `fetchAPI(url, configs)` | (없음 — 절대 경로 전달) | — | `fetch.ts:30` |
| `fetchRewardAPI(url)` | `/web/reward/api` | 동일 도메인 | `fetch.ts:125` |
| `fetchFundingAPI(url)` | `/web/apip/funding` | 동일 도메인 | `fetch.ts:130` |
| `fetchFundingStudioAPI(url)` | `/web/apip/funding/studio` | 동일 도메인 | `fetch.ts:135` |
| `fetchStoreStudioAPI(url)` | `/web/apip/store/studio` | 동일 도메인 | `fetch.ts:140` |
| `fetchWebAPI(url)` | `fetchUrl(url)` (절대) | 동일 도메인 | `fetch.ts:145` |
| `fetchPlatformAPI(url)` | `fetchUrl(url, PLATFORM_API_URL)` | `process.env.PLATFORM_API_URL` | `fetch.ts:149` |
| `fetchPublicAPI(url)` | `fetchUrl(url, REACT_APP_PUBLIC_API_HOST)` | `public-api.wadiz.kr` | `fetch.ts:154` |
| `fetchServiceAPI(url)` | `fetchUrl(url, REACT_APP_SERVICE_API_HOST)` | `service.wadiz.kr` | `fetch.ts:159` |
| `fetchAIDataAPI(url)` | `fetchUrl(url, REACT_APP_AI_WADIZDATA_HOST)` | `genai.wadiz.kr` | `fetch.ts:164` |
| `fetchMakerCenterAPI(url)` | `fetchUrl(url, 'https://api.makercenter.wadiz.kr')` | **하드코딩** (`fetch.ts:170`) |
| `fetchGlobalAPI(url)` | `{PLATFORM_GLOBAL_API_URL}{url}` + `Authorization: Bearer {PLATFORM_GLOBAL_API_TOKEN}` | platform global | `fetch.ts:174-186` |
| `fetchMain2API(url)` | `{PLATFORM_MAIN2_API_URL}{url}` | platform main2 | `fetch.ts:188-196` |

### fetchAPI 공통 동작 (`fetch.ts:30-123`)

- 기본 옵션: `GET`, `Content-Type: application/json`, `credentials: 'same-origin'`, `cache: 'default'` (`fetch.ts:8-17`)
- `body` 가 `FormData` 이거나 `GET` 이면 `Content-Type` 삭제 (`fetch.ts:35-37`)
- 204 → `null`, 그 외 status 200~299 → JSON 반환 / 그 외 → `FetchError`, JSON 파싱 실패 → `JsonParseError`
- `useOriginalResponse: true` 옵션이면 `{...json, originalResponse}` 반환 (`fetch.ts:104-107`)
- 에러 객체는 요청/응답 헤더·body·상태를 `extra` 로 보존 → Sentry 에서 복원 가능

### Export 구조

- `src/index.ts` — **`utils` 만 export** (API 모듈은 alias 패스 직접 import)

---

## 5. `apps/wai-ai-agent-launcher` — WAi AI 에이전트 런처

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `wai` (`apps/wai-ai-agent-launcher/package.json:2`) |
| 빌드 형태 | **UMD 라이브러리** (`main.js`) — 호스트 페이지에서 `<script>` 로드 (`vite.config.ts:31-40`) |
| lib.entry | `src/app/main.tsx` |
| global name | `WAiAIAgentLauncher` |
| format | `['umd']`, `inlineDynamicImports: true` (`vite.config.ts:39`) |
| cssCodeSplit | `false` (`vite.config.ts:45`) — CSS 를 JS 에 인라인 주입 (`vite-plugin-css-injected-by-js`) |
| assetsInlineLimit | `100000` — 이미지/폰트 모두 base64 인라인 |
| 환경 정의 | `process.env.NODE_ENV=production`, `process.env.ENVIRONMENT=live` (hardcoded, `vite.config.ts:26-28`) |
| 공개 Global | `window.WAI('init' \| 'open', options)` (`src/app/main.tsx:124`) |

### 아키텍처

**Feature-Sliced Design** (`CLAUDE.md` 참조):

- `src/app/main.tsx` — 진입점. `WAI('init', {...})` 호출 시 호스트 DOM 에 버튼 마운트, `WAI('open', {...})` 는 즉시 모달/새창 오픈.
- `src/entities/WAiAIAgentButton/` — `WAiAIAgentButton.tsx`, `WAiAIAgentSupporterButton.tsx`
- `src/features/WAiAIAgentContainer/` — 버튼/모달 오케스트레이션
- `src/widgets/WAiAIAgentModal/` — `WAiAIAgentModal.tsx` + `ui/` (`WAiAIAgentDesktopModal`, `WAiAIAgentMobileModal`)
- `src/shared/lib/` — `useWAiAIAgentWindowOpen.tsx` (오픈 전략), `useScrollVisibility.ts`

### 환경변수 · upstream 매핑

**별도 `.env` 파일 없음**. 런타임에 `window.location.hostname` 을 기반으로 환경 판별.

**`ENV_DOMAIN_MAP`** (`shared/lib/useWAiAIAgentWindowOpen.tsx:56-63`):

| env | 도메인 |
|---|---|
| `local` | `https://local.wadiz.kr` |
| `dev` | `https://dev.wadiz.kr` |
| `rc` | `https://rc.wadiz.kr` |
| `rc2` | `https://rc2.wadiz.kr` |
| `stage` | `https://stage.wadiz.kr` |
| `live` | `https://wadiz.kr` |

결정 순서(`getBaseURL`, `useWAiAIAgentWindowOpen.tsx:65-86`):
1. `options.environment` 제공 시 해당 도메인 사용.
2. 현재 `hostname` 이 `wadiz.kr` 또는 `*.wadiz.kr` 이 아니면 **빈 문자열** 반환(런처 비활성).
3. hostname 앞 세그먼트가 `ENV_DOMAIN_MAP` 키와 일치하면 그 값, 아니면 live.

### 라우트 구조 (외부 뷰)

WAi 런처는 자체 라우트가 없고, **WAi 페이지를 새 창/모달/앱 웹뷰로 여는** 단일 책임입니다.

대상 URL 템플릿 (`shared/lib/useWAiAIAgentWindowOpen.tsx:32`):

```
{baseUrl}/web/wai?language={ko|en|...}&question={initialQuestion}&path={path}&projectId={projectId}&agent={supporter|...}&view={modal|...}&returnUrl={...}
```

### 동작 분기 (open)

**`openWAiAIAgent(options)`** (`useWAiAIAgentWindowOpen.tsx:88-191`):

1. **앱 웹뷰 + supporter agent + WAi 페이지 아님**: URL navigation 으로 네이티브 모달 트리거 (`window.location.href = returnUrl`). `inAppWebviewPolicy.isWAiAgentSupported` 확인.
2. **웹 모달 view**: iframe 모달 생성(`WAiAIAgentModal`), 로그인 복귀용 `returnUrl` 세팅.
3. **모바일 (innerWidth ≤ 1095)**: `window.open(url, '_blank')` — 새 탭.
4. **데스크톱**: `window.open(url, 'AI-AGENT', {right-bottom fixed feature})` — 우하단 400x780 팝업.

로그인 복귀 로직 (`main.tsx:92-108`): URL 파라미터 `present=modal&action=openModal&actionParam={url}` 감지 시 모달 자동 재오픈.

### 기능↔API 매핑 (WAi)

런처 자체는 **API 호출 없음**. iframe 안에서 로드되는 `/web/wai` 페이지가 WAi 엔드포인트를 호출합니다 (본 모노레포 범위 밖).

공유 라이브러리만 참조:
- `@wadiz/core/lib/presentUrl` — `parsePresentUrl`, `createPresentUrl`
- `@wadiz/core/policies/inAppWebviewPolicy` — 앱 버전별 지원 여부
- `@wadiz/utils/browser.isWadizApp` — UA 기반 wadiz 앱 판별
- `@wadiz/waffle/useMediaQuery` — 반응형 모달 분기

### 공유 packages 의존성 (WAi)

`vite.config.ts:48-69` — 13 개 alias (funding 과 대부분 동일):
- `@wadiz/api`, `@wadiz/artworks`, `@wadiz/core`, `@wadiz/event-tracker`, `@wadiz/features`, `@wadiz/format`, `@wadiz/i18n`, `@wadiz/metrics`, `@wadiz/queries`, `@wadiz/request-api` (from `libraries/packages`), `@wadiz/settings`, `@wadiz/utils`, `@wadiz/waffle`, `@wadiz/waffle-icons`
- `@` → `./src`

---

## 6. `apps/walink-generator` — 와링크(단축 URL) 생성기

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `walink-generator` (`apps/walink-generator/package.json:2`) |
| 빌드 형태 | SPA (Vite, `base: './'`, `vite.config.ts:12`) |
| 빌드 outDir | `build/` |
| 빌드 target | ES2018 |
| 스타일 | `wadiz/waffle` + CSS Modules + SCSS 주입 |
| 환경 관리 | **`env-cmd` + `.env-cmdrc`** (JSON 기반, `apps/walink-generator/.env-cmdrc`) |

### 환경변수 (walink)

`.env-cmdrc` — 2 개 환경만 정의

```json
{
  "local": {
    "VITE_APP_API_URL": "https://api.dev.wadiz.co/app",
    "VITE_ENVIRONMENT": "local"
  },
  "dev": {
    "VITE_APP_API_URL": "https://app.wadiz.kr",
    "VITE_ENVIRONMENT": "live"
  }
}
```

Vite define (`vite.config.ts:62-66`):

- `process.env.APP_API_URL = VITE_APP_API_URL`
- `process.env.ENVIRONMENT = VITE_ENVIRONMENT`
- `global = window`

개발 서버 프록시 (`vite.config.ts:98-105`):

- `/api` → `https://api.dev.wadiz.co/app` (changeOrigin)

### 라우트 구조

단일 페이지 — `src/pages/(home)/HomePage.tsx` (next-style 괄호 라우트 네이밍 관습 차용, 실제로는 직접 마운트).

구성:
- `src/app/main.tsx` + `src/app/App.tsx` + `src/app/main.scss`
- `src/pages/(home)/HomePage.tsx` — 입력·출력 섹션
- `src/pages/(home)/_ui/URLFieldSection/` — 입력 필드 + 변환 호출
- `src/shared/styles/` — 공용 스타일

### 기능↔API 매핑 (walink)

**단일 엔드포인트** — `POST /api/v2/links` (body `{ targetPath: string[] }`).

로직 (`src/pages/(home)/_ui/URLFieldSection/URLFieldSection.tsx:13-42`):

- `process.env.ENVIRONMENT === 'local'` 이면 상대경로 `fetch('/api/v2/links', ...)` 호출 (dev 서버 프록시 경유).
- 그 외(live) 는 `@wadiz/api/app` 의 `linksService.postWalinks({ targetPath })` 호출.

`linksService.postWalinks` 본체 (`packages/api/src/app/links.service.ts:46-52`):

```ts
POST('/api/v2/links', targets, {
  baseUrl: APP_API_DOMAIN[(process.env.ENVIRONMENT || 'local') as keyof typeof APP_API_DOMAIN],
});
```

**`APP_API_DOMAIN`** (`packages/api/src/app/links.service.ts:7-14`):

- `live` → `https://app.wadiz.kr`
- `local` / `dev` → `https://api.dev.wadiz.co/app`
- `rc` → `https://app-rc.wadizcorp.net`
- `rc2` → `https://app-rc2.wadizcorp.net`
- `rc3` → `https://app-rc3.wadizcorp.net`

응답 타입 — `Walink[]` = `{ linkUrl, shortId, targetPath }[]` (`links.service.ts:40-44`).

### 공유 packages 의존성 (walink)

`vite.config.ts:84-96`:

- `@wadiz/api` → `packages/api/src` (서비스: `linksService`)
- `@wadiz/artworks`, `@wadiz/core`, `@wadiz/utils`, `@wadiz/waffle-icons`, `@wadiz/waffle`
- `@wadiz/request-api` → `libraries/packages/request-api/src` (HTTP base)

---

## 7. `apps/mail-template` — 이메일 템플릿 빌더

### 메타

| 항목 | 값 |
|---|---|
| 패키지명 | `mail-template` |
| 빌드 도구 | **Vite 5 + Vituum + Handlebars + Juice** (`apps/mail-template/package.json`) |
| 진입 | `src/pages/**/*.hbs` (Handlebars) |
| 결과물 | 정적 HTML — 언어별 `build/templates/{name}_{ko|en|ja|zh}.html` |
| 배포 | S3 (`.github/workflows/build-and-deploy-mail-template-to-s3.yml`, `HOW-IT-WORKS.md:257-260`) |
| base | `/mail-template/` (production, `vite.config.js`) |

### 환경변수 · upstream 매핑

**없음**. 빌드 타임 전량 정적.

### 라우트 구조

- `src/pages/index.hbs` — 템플릿 목록 랜딩
- `src/pages/templates/*.hbs` — 개별 템플릿 (70+ 파일 추정). 예:
  - `accountSignup*.hbs` — 회원가입 플로우 (`_multilingual` 접미사: ko/en/ja/zh 4 개 생성)
  - `accountResetPassword_multilingual.hbs`, `accountDeleteVerificationCode_multilingual.hbs`, `accountMarketingConsent_multilingual.hbs`, `accountPrivacyUsage(_multilingual).hbs`
  - `R_M_judge2_approval_precomingsoon*.hbs` — 승인/오픈예정
  - `ad01.hbs`, `ad04ContractModifyAccepted.hbs`, `ad04ContractRequestModify.hbs`, `ad05PaymentFailed.hbs`, `adExecutionGuideDPPush.hbs` — 광고
  - `InformationOnProductsInStockWithSluggyWADelivery.hbs`, `InformationProductsToBeAbleToSoldOutWithin1month(_basic_pro).hbs` — 스토어 재고 안내

### 기능↔API 매핑

**없음** (빌드 타임 Handlebars → HTML). 런타임 API 호출 없음.

### 빌드 파이프라인

1. `scripts/generate-main-data.js` → `src/data/main.json` (메타데이터 목록)
2. `scripts/generate-asset-list.js` → `src/assets/asset-list.html`
3. `vite build` → Vituum/Handlebars 렌더
4. `scripts/export-preview-html.js` → 언어별 HTML 분기 생성
5. Juice → CSS 인라인

### Handlebars 헬퍼 (`vite.config.js:17-37, 173-201`)

- `t "key"` — i18n (packages/i18n/src/mail-template/languages/{ko,en,ja,zh}.json)
- `eq`, `not`, `and`, `set varName varValue`, `concat`, `json`

### 공유 packages 의존성

- `packages/i18n/src/mail-template/languages/{ko,en,ja,zh}.json` — 4 개 로케일 번역 리소스 (vite.config.js 직접 import)
- `src/partials/**/*.hbs` — Handlebars 부분 템플릿
- `src/styles/index.scss` — 공통 스타일 (Juice 로 인라인 주입)

---

## 8. `apps/devtools` — 개발자 도구

2 개 독립 패키지.

### 8-A. `apps/devtools/app-settings-console`

| 항목 | 값 |
|---|---|
| 패키지명 | `@wadiz-apps/app-settings-console` |
| 빌드 도구 | Vite 5 + Express 프록시 서버 |
| 실행 | `pnpm dev` → `concurrently("pnpm:dev:server", "pnpm:dev:client")` (`package.json:7`) |
| 서버 | `tsx watch server/index.ts`, port 9999 (`server/index.ts:5`) |
| 클라이언트 | Vite dev server, 기본 port 3001 (README 기준) |
| HTTP | Axios 1.15 — `axios.create({ baseURL: '/api' })` (`src/services/api.ts:6-11`) |
| 에디터 | Monaco Editor (`@monaco-editor/react`) |

**환경별 upstream (서버 측 ENV_CONFIG, `server/index.ts:12-33`)**

| env | host | token (Bearer, 하드코딩) |
|---|---|---|
| `dev` | `https://api.dev.wadiz.co/app` | `E3F8C93FBC4F...` |
| `rc1` | `https://app-rc.wadizcorp.net` | `B392E653945...` |
| `rc2` | `https://app-rc2.wadizcorp.net` | `61638487...` |
| `rc3` | `https://app-rc3.wadizcorp.net` | `DA59737D...` |
| `live` | `https://app.wadiz.kr` | `FCB942B7...` |

**프록시 엔드포인트** (`server/index.ts:51-83`):

```
GET /                             → 안내 JSON
*   /api/:env/*                   → {host}/api/{path}?{query}
                                    + Authorization: Bearer {token}
```

**클라이언트 API 호출** (`src/services/api.ts:13-59`):

| 기능 | Method + Path | 라인 |
|---|---|---|
| 설정 목록 | GET `/{env}/v1/settings?platform=web` | `api.ts:16` |
| 특정 설정 | (목록에서 find) | `api.ts:21-29` |
| 설정 수정 | PATCH `/{env}/v1/settings/{id}` body `{ setting }` | `api.ts:39` |
| 설정 생성 | POST `/{env}/v1/settings` body `{ platform: 'web', feature, setting }` | `api.ts:48` |
| 설정 삭제 | DELETE `/{env}/v1/settings/{id}` | `api.ts:57` |

**라우트** (`src/pages/`):
- `SettingsList.tsx` — 목록 화면
- `SettingDetail.tsx` — 상세/편집 (Monaco)

### 8-B. `apps/devtools/component-playground`

| 항목 | 값 |
|---|---|
| 패키지명 | `component-playground` |
| 빌드 도구 | Vite 6 |
| 실행 | `pnpm start` 또는 `pnpm start:local` (env-cmd) |
| 라우팅 | React Router v6 |
| 의존성 | React 18, react-router-dom 6, classnames — **waffle 포함 안 함** (자체 타입만) |

**기능**: 디자인 시스템 컴포넌트(Waffle)의 시연/탐색.

**환경변수·API**: 없음.

**라우트 구조**: `src/pages/index.tsx` 단일 엔트리(라우터 정의 내부 참조 필요).

---

## 9. 스튜디오 3종의 공통 UX 패턴

### 인증 전략

| 스튜디오 | 세션 체크 | 401/403 처리 |
|---|---|---|
| funding | TanStack Query `onError` → `useStore.getState().setLogout()` + 토스트 `MESSAGE.NEED_LOGIN` (`src/Root.tsx:48-50`) | `kr.wadiz.account` 리다이렉트는 OAuth proxy `/oauth`·`/login` 으로 처리 |
| startup | TanStack Query `onError` → 로그인 필요 토스트 (`src/Root.jsx:22-25`) + `meta.localErrorHandler` 우회 가능 | 동일 |
| store | Axios 인터셉터 `error.response.data` → `globalActions.setError(data)` (`helpers/axios.ts:116`) | `GET /isLoggedIn` 은 `services/account.ts:7`, baseURL override |

### Toast / UI Feedback

- 세 스튜디오 모두 **`@wadiz/waffle.showToast`** 사용.
- funding: `MESSAGE.FETCH_FAILURE_MESSAGE` 일관 적용.
- startup: `FETCH_FAILURE_MESSAGE` + `HTTP_STATUS.UNAUTHORIZED|FORBIDDEN` 공통 상수.
- store: 쿼리 에러 시 `FETCH_FAILURE_MESSAGE` 토스트.

### Data Fetching

- **TanStack Query v5** 세 스튜디오 공통. `refetchOnWindowFocus: false`, `retry: false` 설정 동일.
- funding: `queryCache.onSettled: expandSession()` 호출 — 세션 타이머 연장 (`Root.tsx:36`).

### 라우팅 버전 불일치

- funding: **React Router v5** (`Switch` + `Route component={}`, `src/Root.tsx:100`)
- startup: **React Router v6 data router** (`createBrowserRouter` + `RouterProvider`, `src/Root.jsx:48`)
- store: **React Router v5** (`BrowserRouter` + `Switch`, `src/App.tsx:50`)

> 3 개 레포에서 2 개 라우터 세대 공존 중.

### 에러 추적 / Browser 툴

- 세 스튜디오 모두 **Sentry `@sentry/browser@5`** 사용 (`src/setupSentry.ts`).
- 세 스튜디오 모두 **Braze Web SDK** 전역 초기화. (`Root.tsx:147-170` funding, `Root.jsx:70-76` startup, `App.tsx:73-98` store) — 공통 상수 `BRAZE_API_KEY`.

### Storybook / 테스트

- funding, startup: **Vitest + MSW 2.4 + Storybook 8**.
- store: Storybook 설정은 package.json 에 없음(확인 필요 — 공식 CLAUDE.md 에는 언급되나 script 없음).

### 스타일 시스템

- 세 스튜디오 모두 `@wadiz/waffle` + SCSS Modules.
- store 만 Ant Design 병행 (`~assets/styles/lib/antd.scss`).

### 메이커 공통 플로우 (기능 단위)

| 플로우 | funding | startup | store |
|---|---|---|---|
| 로그인 상태 | `/web/account/isLoggedIn` (fetchWebAPI) | POST `/web/account/isLoggedIn` | GET `/isLoggedIn` (baseURL `/web/account`) |
| 메이커 법인 정보 | `/makers/campaigns/{id}` (fetchRewardAPI) | `/web/startup/corporation/{corpNo}` | `/maker/STORE/{campaignId}` (baseURL `/web`) |
| 메이커 언어 | `/web/v1/maker/language` | — | — |
| 파일/이미지 업로드 | `/attachments/presign` (fetchFundingAPI) | `/maker/upload/{corpNo}`, `/web/maker/upload/{corpNo}/*` | `/attachments`, `/attachments/presign` (presign S3 PUT) |
| 새소식 | `/campaigns/{id}/news` (fetchFundingAPI) | `/web/maker/studio/{corpNo}/news` | 없음 |
| 약관 동의 | `/web/v2/terms/marketing/consent/services`, `/noti-channel/v2/marketingconsents` | `/web/v2/terms/accepter` | `/projects/{pNo}/terms-agreements/{type}` |
| 메이커 제출 | POST `/web/reward/api/studios/campaigns/{id}/submit(\|re-submit)` | (별도 메이커 승인 플로우 `/web/maker/terms/{corpNo}/getMakerTermsNeedToAccept`) | POST `/projects/{pNo}/submit(\|-by-admin)` |
| 국가/언어 설정 | `/web/reward/api/studios/maker/available-countries\|write-languages\|use-languages`, `/web/v1/countries/maker`, `/web/v1/countries/time-zones` | — | 없음 |
| 환율 | `/exchange-rates(/{country})` (fetchGlobalAPI) | — | 없음 |

---

## 10. WAi AI 에이전트 특이 구조

### Launcher vs WAi 페이지

- **Launcher (본 문서 대상)**: UMD 라이브러리. 호스트 페이지에 떠있는 버튼/모달 컨테이너, API 호출 없음.
- **WAi 페이지**: `/web/wai` — launcher 가 새창/iframe 으로 열지만 코드는 본 모노레포에 없음(또는 별도 경로). 본 문서 범위 밖.

### 런처가 전달하는 WAi 쿼리 파라미터

| 파라미터 | 값 | 출처 |
|---|---|---|
| `language` | `ko` / `en` / `ja` / `zh` (`LanguageCode`) | `options.languageCode` |
| `question` | 초기 질문 | `options.initialQuestion` |
| `path` | 컨텍스트 경로 | `options.path` |
| `projectId` | 프로젝트 ID | `options.projectId` |
| `agent` | `supporter` 등 (`AgentType`) | `options.agent` |
| `view` | `modal` 등 (`ViewType`) | `options.view` |
| `returnUrl` | 로그인 복귀 URL | 내부 조립 |

### 로그인 복귀 메커니즘 (`main.tsx:91-108`, `useWAiAIAgentWindowOpen.tsx:103-124`)

- **웹**: `createPresentUrl({ presentUrl, present: 'replace', action: 'openModal', actionParam: waiUrl })` → 로그인 후 동일 페이지로 돌아와 URL 파라미터 기반으로 모달 재오픈.
- **앱 웹뷰 (상위버전, `inAppWebviewPolicy.isWAiAgentSupported`)**: `present=modal` 로 앱에 시그널 → 앱이 네이티브 모달로 WAi 재오픈.
- **하위버전 앱**: 웹과 동일하게 처리.

### 디바이스/뷰포트 분기

- 모바일(innerWidth ≤ 1095): `window.open(url, '_blank')` — 새 탭.
- 데스크톱: 400×780 우하단 고정 팝업 (`getRightBottomFeatures()`, `useWAiAIAgentWindowOpen.tsx:35-52`).
- 모달 뷰(`view === 'modal'`): iframe 모달, 반응형으로 `WAiAIAgentMobileModal` / `WAiAIAgentDesktopModal` 분기 (`WAiAIAgentModal.tsx:11-29`).
- **중복 방지**: 이미 열린 데스크톱 팝업(`windowObject && !closed`) 이 있으면 focus 만 수행(`useWAiAIAgentWindowOpen.tsx:174-177`).

### 공유 정책/유틸

- `@wadiz/core/lib/presentUrl` — URL 파라미터로 "모달 복귀"를 기술하는 공용 프로토콜 (`present`, `action`, `actionParam`).
- `@wadiz/core/policies/inAppWebviewPolicy` — 앱 기능 지원 여부 플래그 집합 (`isWAiAgentSupported`).
- `@wadiz/utils/browser.isWadizApp` — User-Agent 기반 wadiz 앱 판별.

---

## 11. 전체 Upstream 매트릭스

본 문서 대상 8 앱의 upstream 요약. 도메인은 live 기준.

| 도메인 | 어떤 앱이 호출 | 주요 경로 (prefix) | 환경변수 (live) |
|---|---|---|---|
| `www.wadiz.kr` (com.wadiz.web 레거시 WAR) | funding (거의 전량), startup (거의 전량), store, devtools(proxy 대상 아님) | `/web/*` (account, reward/api, apip/funding, apip/store, maker/*, startup/*, maker-proxy/*, v1, v2, v3, waccount, backoffice, progress) | (동일 도메인 호출 — VITE_SERVER_PROXY 는 dev) |
| `account.wadiz.kr` (kr.wadiz.account) | 3 스튜디오 모두 (OAuth 리다이렉트) | `/oauth`, `/login`, `/signup`, `/social-signup`, `/social-link`, `/connect` (Vite proxy target) | `DEV_AUTH_SERVER_PROXY` (dev) |
| `platform.wadiz.kr` | funding (글로벌 환율·번역·마케팅), startup 미사용, store 미사용 | `/exchange-rates`, `/translate/*`, `/noti-channel/v2/marketingconsents`, `/main2`, `/global` | `VITE_PLATFORM_API_URL`, `VITE_PLATFORM_MAIN2_API_URL`, `VITE_PLATFORM_GLOBAL_API_URL` + Bearer `PLATFORM_GLOBAL_API_TOKEN` |
| `public-api.wadiz.kr` | funding (`/main/info/RA1`) | `/main/*` | `VITE_PUBLIC_API_HOST` |
| `service.wadiz.kr` | funding, store (search categories) | `/api/search/v2/categories`, `/api/search/categories` | `VITE_SERVICE_API_HOST` |
| `app.wadiz.kr` (NestJS `app-api`) | walink-generator, devtools/app-settings-console (live), WAi (iframe 간접) | walink: `/api/v2/links`; devtools: `/api/v1/settings` | `VITE_APP_API_URL` / hardcoded `APP_API_DOMAIN.live` |
| `api.dev.wadiz.co/app` | walink-generator (local), devtools (dev) | walink: `/api/v2/links`; devtools: `/api/v1/settings` | `APP_API_DOMAIN.dev` (하드코딩 in `links.service.ts:10`, `devtools/server/index.ts:14`) |
| `app-rc.wadizcorp.net`, `app-rc2.wadizcorp.net`, `app-rc3.wadizcorp.net` | devtools(app-settings-console) RC 환경 | `/api/*/v1/settings` | `devtools/server/index.ts:17-27` 하드코딩 Bearer |
| `genai.wadiz.kr` (AI wadizdata) | funding (메이커 가이드 AI) | `/maker/guide` | `VITE_AI_WADIZDATA_HOST` → `REACT_APP_AI_WADIZDATA_HOST` |
| `ws.ai.wadiz.kr` (WebSocket) | funding (정의되어 있음, 실제 사용 확인 필요) | ws:// | `VITE_AI_CHATDATA_HOST` |
| `analytics.wadiz.kr` / `dev-analytics.wadiz.kr` | 3 스튜디오 (env 정의만 존재, 이벤트 트래킹 용) | (분석 트래킹) | `VITE_ANALYTICS_HOST` |
| `biz.wadiz.kr`, `ad.wadiz.kr` | funding env 정의 (메이커 센터 간 크로스 링크) | — | `VITE_BIZ_CENTER_HOST`, `VITE_AD_CENTER_HOST` |
| `cdn3.wadiz.kr` (Platform CloudFront) | 3 스튜디오 이미지 호스트 | — | `VITE_PLATFORM_CLOUDFRONT_HOST` |
| `static.wadiz.kr` / `static-dev.wadiz.kr` | 3 스튜디오 정적 자원 | — | `VITE_FE_CLOUDFRONT_HOST` |
| `api.makercenter.wadiz.kr` | studio-services `fetchMakerCenterAPI` (하드코딩, `fetch.ts:170`) — funding 범위에서는 직접 호출 없음 | — | 하드코딩 |
| `{env}.wadiz.kr/web/wai` | WAi launcher 가 iframe/새창으로 열기만 함 | `/web/wai?agent=&view=...` | launcher 가 `ENV_DOMAIN_MAP` 으로 판별 |
| S3 (mail-template 배포, presign PUT in store) | mail-template (빌드 산출물 업로드), store (`services/external.ts` presigned PUT) | — | GitHub Actions + `VITE_PLATFORM_CLOUDFRONT_HOST` |
| Braze (`js.appboycdn.com`, `sdk.iad-06.braze.com`) | 3 스튜디오 (InApp 메시지) | Braze Web SDK | `VITE_BRAZE_API_ENDPOINT`, `VITE_BRAZE_SCRIPT` (inline) |
| Sentry (`sentry.io`) | 3 스튜디오 | — | `VITE_SENTRY_DSN`, `VITE_SENTRY_ORG`, `VITE_SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` |
| GTM (`www.googletagmanager.com`) | funding, startup (`GTM-NDMQ9N4` id 동일) | — | `VITE_GTM_HEAD`, `VITE_GTM_BODY` (live 만) |

---

## 12. 경계 및 미탐색 영역

### 본 문서에서 기록하지 못한 것

1. **서버 측 엔드포인트 내부 로직**: `/web/reward/api/*`, `/web/apip/funding/*`, `/web/apip/store/studio/*`, `/web/maker/*`, `/web/startup/*`, `/web/maker-proxy/*` 의 실제 구현은 `com.wadiz.web`, `com.wadiz.api.funding`, `com.wadiz.api.reward`, `makercenter-be` 에 있습니다. 매핑은 `docs/com.wadiz.web.md`, `docs/com.wadiz.api.funding/`, `docs/makercenter-be.md` 참조.
2. **`/web/wai` (WAi 페이지)**: launcher 는 URL 만 전달합니다. WAi 페이지 자체는 본 모노레포 또는 외부 리포에 존재할 수 있으며, 본 문서에서는 launcher 측만 기록했습니다.
3. **`studio/funding/src/utils/fetchIntercepter/`**: MSW 런타임 토글 UI 의 실제 파일 내부 구조는 경로만 확인했습니다.
4. **`src/@types/*`**: 타입 정의는 런타임 동작이 아니므로 본 문서 대상 외.
5. **`studio/studio-services/src/api/web/`** (신규 NEW 구조): `CLAUDE.md v2.0` 기준 권장 구조이나, 실제 파일 내 경로 리터럴은 `studio-campaigns.services.ts` 등에 분산. 본 문서에서는 DEPRECATED `servers/` 경로 위주로 수집했습니다. 둘 모두 같은 `/web/*` 엔드포인트를 가리킵니다.
6. **Storybook 스토리, 테스트 파일**: 기능↔API 매핑 목적에서는 제외.
7. **`apps/devtools/component-playground/src/pages/index.tsx`** 내부 라우팅: 파일 탐색까지는 했으나 실제 라우트 정의는 읽지 않았습니다.
8. **환경별 프록시 token**: `devtools/app-settings-console/server/index.ts:12-33` 은 **리포에 Bearer Token 이 평문 커밋**되어 있습니다. 본 문서는 관측 사실로만 기록 — 사용·유출 여부는 판단 범위 밖.

### 추정·미확인 항목

- `studio/store` 의 Storybook 지원: `CLAUDE.md` 는 언급하나 `package.json` scripts 에 없음. 실제 동작 여부 미확인.
- `VITE_AI_CHATDATA_HOST` (`wss://ws.ai.wadiz.kr`): funding `.env` 에만 정의. 실제 WebSocket 연결 코드 위치는 확인하지 못했습니다.
- `src/utils/fetchIntercepter/MockUI.tsx`: lazy 로드 시 DEV 에서만 마운트(`Root.tsx:126-130`), 내부 동작 미확인.
- `process.env.STATIC_URL` (링크 서비스 `getShareSettings` in `packages/api/src/app/links.service.ts:16-20`): walink-generator 의 범위에선 호출되지 않음.
- WAi launcher 의 `openWAiAIAgent` 의 `initialQuestion`·`features` 옵션: 외부 호스트 페이지에서 주입되는 값이라 본 모노레포에서 호출하는 지점은 확인되지 않습니다.
- `studio/funding` `src/pages/Reward/` 의 14 페이지 각각이 어느 API 를 부르는지는 **엔드포인트 리스트** 로 대체했습니다. 페이지↔엔드포인트 1:1 매핑은 추후 Phase 2 심층 분석 주제.

### 관련 분석 문서

- 상위 개요: `docs/wadiz-frontend/wadiz-frontend.md`
- FE 패키지: `docs/wadiz-frontend/api-details/` (향후 확장)
- 서버 측: `docs/com.wadiz.api.funding/`, `docs/com.wadiz.api.reward/`, `docs/com.wadiz.api.startup.md`, `docs/com.wadiz.web.md`, `docs/makercenter-be.md`, `docs/app-api.md`, `docs/kr.wadiz.account.md`
- 모바일: `docs/wadiz-android.md`, `docs/wadiz-ios.md`
