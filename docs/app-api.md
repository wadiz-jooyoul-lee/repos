> 📅 **2026-09-03 cloud_live pull 보강** (5 커밋)
>
> ### CLIENT-235 — 클라우드 CDN 호스트 매핑 신설
> - 기존 `wadiz.kr` CDN 호스트를 **클라우드 CDN(`wadiz.io`) 호스트로 치환**하는 표와 헬퍼를 새로 만들었습니다 (`src/common/constants/cdn.constants.ts`, `src/common/helpers/cdn.helper.ts`).
> - 핵심은 **kr 호스트 하나가 로케일에 따라 두 호스트로 갈린다**는 점입니다. 클라우드 CDN 은 국내(`cdn-*`)와 해외(`cf-*`)를 서로 다른 도메인으로 관리하기 때문입니다. 해외 배포가 없는 서비스는 국내 호스트를 그대로 씁니다.
>
> | kr 호스트 | 국내(KR) | 해외 |
> |---|---|---|
> | `cdn.wadiz.kr` | `cdn-funding.wadiz.io` | (동일) |
> | `cdn1.wadiz.kr` | `cdn-business.wadiz.io` | `cf-business.wadiz.io` |
> | `cdn2.wadiz.kr` | `cdn-store.wadiz.io` | (동일) |
> | `cdn3.wadiz.kr` | `cdn-funding-public.wadiz.io` | `cf-funding-public.wadiz.io` |
> | `cdn4.wadiz.kr` | `cdn-display.wadiz.io` | (동일) |
> | `cdnai.wadiz.kr` | `cdn-aidata.wadiz.io` | `ai-cdn.wadiz.io` |
>
> - 국가 코드는 `wadiz-country` 헤더에서 오고, **값이 없으면 해외로 판정**합니다(컨트롤러 기본값과 같은 규칙). 표에 없는 호스트는 원본 URL 을 그대로 돌려주고, 치환은 호스트 부분만 바꿔 경로·쿼리는 원문을 유지합니다.
> - 적용처는 펀딩 프로젝트 조회입니다 (`src/api/funding/projects/project.service.ts`). 테스트 165줄이 함께 붙었습니다.
> - 후속 커밋에서 **`cloud` 환경 판정 분기를 제거**했습니다 — 환경과 무관하게 표에 있으면 치환하는 단순한 규칙으로 정리한 것입니다.
> - 짝이 되는 작업이 `wadiz-frontend` 에도 있습니다(FE1-1733, 스토리 이미지 변환의 클라우드 CDN 호스트 인식 확장).
>
> ---

> 📅 **2026-08-27 cloud_live pull 보강** (1 커밋)
>
> ### FE1-1685 — 프로덕션 환경 debug 로그 출력 차단
> - `ConsoleLogger` 에 `logLevels` 를 명시해 로그 레벨을 환경별로 갈랐습니다 (`src/main.ts:31-39`). 프로덕션(`NODE_ENV === 'production'`)은 `['log','warn','error','fatal']` 만, 그 외 환경은 여기에 `'debug'`·`'verbose'` 를 더한 6종을 출력합니다.
> - 기존에는 `json` 옵션만 환경으로 갈랐고 레벨은 NestJS 기본값(전 레벨 출력)이라 프로덕션에도 debug·verbose 로그가 그대로 나가고 있었습니다.
>
> ---

> 📅 **2026-08-25 cloud_live pull 보강** (11 커밋)
>
> ⚠️ **기준 브랜치가 `main` → `cloud_live` 로 바뀌었습니다.** 아래 내용은 클라우드 라이브 배포선 기준이며, 도메인 전환(`wadiz.kr` → `wadiz.io`)과 `/api` 접두사 제거가 핵심입니다.
>
> ### FE1-859 — `/api` 글로벌 접두사 제거 + 하위버전 호환 미들웨어
> - **본문 "아키텍처" 절의 "글로벌 Prefix `/api` 설정" 서술은 더 이상 사실이 아닙니다.** `app.setGlobalPrefix('api', { exclude: [...] })` 를 통째로 제거해 이제 컨트롤러 경로가 곧 최종 경로입니다 (`src/main.ts:47-53`).
> - 대신 `/api/` 로 시작하는 요청의 접두사를 지우는 Express 미들웨어를 앞단에 두어 구버전 클라이언트를 계속 받습니다(`req.url.replace(/^\/api/, '')`). `/links/:shortId`·`/links/*splat`·`/redirect/*splat` 를 예외로 빼던 `exclude` 설정도 함께 불필요해져 삭제됐습니다.
> - 단위 테스트 `api-prefix-rewrite.middleware.spec.ts`(82줄) 추가, e2e 테스트 경로 수정.
>
> ### FE1-1063 / FE1-1551 / FE1-1552 / FE1-1673 — 와디즈 도메인 `wadiz.io` 전환
> - 와링크 허용 도메인을 `wadiz.co` → **`wadiz.io`** 로 변경(FE1-1063). cloud 환경에 남은 `wadiz.kr` 하드코딩을 정리(FE1-1552)하고, 로컬 개발 도메인 `local.wadiz.io` 를 CORS 허용에 추가(FE1-1551).
> - FE1-1673: **구 도메인(`wadiz.kr`) 와링크가 브리지 페이지를 거치도록 수정**하고, 테스트용으로 주석 처리했던 모바일 웹 자동 이동을 복원했습니다.
>
> ### FE1-1469 — OIDC 프로바이더 초기화 실패 시 요청 시점 재초기화
> - `AccountOidcProvider` 는 기동 시점(`onModuleInit`)에 한 번만 초기화되던 구조라, 그때 OpenID 구성 조회가 실패하면 파드를 다시 띄울 때까지 모든 인증 요청이 401로 고착됐습니다. `ensureInitialized()` 를 두어 `getPublicKey()`·`getUserInfo()` 진입 시 미초기화면 그 자리에서 재초기화합니다 (`src/common/providers/oidc.provider.ts:29,93,106`).
> - 동시 요청이 몰려도 중복 실행되지 않도록 진행 중인 Promise(`initializing`)를 공유하고, 재초기화 후에도 실패면 마지막 오류(`lastInitializationError`)를 `cause` 로 연결해 던집니다(ES2021 타깃에 `cause` 옵션 타입이 없어 `Object.assign` 사용).
> - OpenID 구성 fetch 에 `AbortSignal.timeout(3000)` 3초 타임아웃을 걸었습니다. 검증 스펙 `oidc.provider.spec.ts` 148줄 신규.
>
> ---

> 📅 **2026-07-10 main pull 보강** (3 커밋)
>
> ### 펀딩 스토리 HTML 후처리에 Vimeo iframe 지연 로딩 추가 (FE1-1178)
> - 스토리 HTML 처리 파이프라인의 1-1단계로 `replaceVimeoIframes()`가 새로 삽입됨. YouTube placeholder 변환(1단계) 직후, img `src→data-src` 변환(2단계) 직전에 실행 (`src/api/funding/projects/project.service.ts:67-68`).
> - `player.vimeo.com` iframe의 `src`를 `data-vimeo-src`로 보관하고 `src=""`로 비워 초기 동시 로딩·자동재생을 차단, 기존 `style`은 보존하면서 `opacity:0`을 덧붙임 (`project.service.ts:131-146`). background 제거·autopause 및 뷰포트 진입 시 복원은 클라이언트 `useStoryOptimize`가 담당(주석 명시).
> - `replaceGifImagesToVideoTags()` JSDoc이 `Vimeo→lazy`를 포함하도록 갱신됨 (`project.service.ts:24`). 단일/다중 Vimeo iframe 처리 테스트 2건 추가 (`project.service.spec.ts`).
> - 나머지 2커밋은 릴리스/버그픽스 머지(#470·#471)로 net-new 코드 없음.
>
> ---

# app-api 분석 문서

## 개요

`app-api`는 와디즈의 BFF(Backend For Frontend) 서비스입니다. 프론트엔드(웹 및 앱) 관점에서 필요한 "경량" 기능을 담당하며, 와디즈의 전체 서비스 구조에 큰 영향을 주지 않는 범위에서 다음 기능을 제공합니다.

- 와링크(단축 URL / 리다이렉트 / 앱 브릿지) 발급 및 포워딩
- 펀딩 프로젝트 스토리 캐싱 및 HTML 후처리 (GIF→Video, YouTube 지연 로드)
- 외부 도메인 이미지 프록시 다운로드
- 앱 런타임 설정값(A/B 및 feature toggle) 관리
- Zendesk 기반 고객센터(Support) 티켓 및 첨부 파일 처리
- Zendesk 헬프센터 한국어 문서 게시 웹훅 → 자동 다국어 번역/등록
- 단순 헬스체크

주요 호출 주체는 와디즈 웹(www.wadiz.kr), 와디즈 모바일 앱(iOS/Android), 고객센터 페이지이며, `/api/links` 같은 BFF API와 `/links/:shortId` 같은 브라우저 직접 진입 엔드포인트를 함께 제공합니다. 참고: `README.md:1-61`, `CLAUDE.md:1-73`.

## 기술 스택

| 구분 | 기술 |
| --- | --- |
| 언어 | TypeScript 5.6 |
| 프레임워크 | NestJS 11 (Express, global `api` prefix, URI versioning) |
| ORM | TypeORM 0.3 + MySQL 8 (`mysql2`), `SnakeNamingStrategy` |
| 캐시 | `@nestjs/cache-manager` 3 (in-memory) + 자체 in-flight 동시성 제거 Map |
| 인증 | 내부 Bearer 토큰 + OIDC(RS256 JWT + JWKS) + Zendesk Webhook HMAC-SHA256 |
| 외부 SDK | `node-zendesk`, `jwks-rsa`, `linkedom` |
| 로깅/트레이싱 | NestJS `ConsoleLogger`(production json) + Datadog (`dd-trace`, `nestjs-ddtrace`) |
| 파일 제공 | `@nestjs/serve-static` (`public/`) |
| 빌드/실행 | SWC builder, pnpm, Docker, AWS ECR → EKS, ArgoCD 배포 |
| 런타임 포트 | 3000 (`src/main.ts:65`) |

`package.json:41-98` 참조.

## 아키텍처

- 진입점 `src/main.ts:14-67`
  - 로컬 환경일 때 `cert/local.wadiz.*`를 이용한 HTTPS 바인딩
  - ~~글로벌 Prefix `/api` 설정~~ → **2026-08-25 갱신(FE1-859)**: `setGlobalPrefix('api')` 제거. 컨트롤러 경로가 곧 최종 경로이며, `/api/` 로 들어오는 구버전 요청만 Express 미들웨어가 접두사를 잘라 하위호환을 유지합니다 (`src/main.ts:47-53`). 기존 예외 대상(`/links/:shortId`, `/links/*splat`, `/redirect/*splat`)도 함께 불필요해져 삭제됐습니다.
  - `ValidationPipe`(whitelist, transform), 글로벌 `HttpExceptionFilter`, `DatadogErrorInterceptor`
  - URI versioning(`app.enableVersioning()`) + 각 컨트롤러에서 `@Version('1')`, `@Version('2')` 명시
- 모듈 구성 `src/app.module.ts:19-43`
  - `ConfigModule`: `.env.${ENVIRONMENT}` → `.env` 순서로 병합
  - `TypeOrmModule.forRootAsync` + `ServeStaticModule`(정적 파일 루트 `public/`)
  - API 모듈: `Health`, `Links`, `Proxy`, `Project`, `Redirect`, `Settings`, `Support`, `Webhooks`
- 요청 파이프라인: `HttpExceptionFilter → CORS → ValidationPipe → Controller → Service → Repository(TypeORM)` (README mermaid)
- 공통 구성
  - `AuthGuard` (`src/common/guards/auth.guards.ts:17-28`): 내부 `BEARER_TOKEN` 정적 비교 — `Settings` 쓰기 API에만 사용
  - `AccountGuard` (`auth.guards.ts:53-92`): `ACCOUNT_API_OPENID_CONFIGURATION_URL`에서 OpenID 구성 로드, JWKS로 RS256 검증, `userinfo_endpoint` 호출 → `request.userInfo` 주입
  - `ZendeskWebhookGuard` (`auth.guards.ts:98-127`): `X-Zendesk-Webhook-Signature*` 헤더를 `APP_API_ZENDESK_SIGNING_SECRET`으로 HMAC-SHA256 검증 (`rawBody` 필요 → `main.ts:31`)
  - `zendeskClientProvider` (`src/common/providers/zendesk.provider.ts:12-76`): live=`wadiz6256`, 그 외=`wadiz-dev` 서브도메인 자동 분기, Basic 인증 헤더 자동 주입, 에러 재포장
  - `AccountOidcProvider` (`src/common/providers/oidc.provider.ts`): JWKS 10분 캐시, 분당 10회 요청 제한
  - `LinksService.templateHTML`: 서비스 생성자에서 `walink-bridge.html` 사전 로드 (요청 시 매번 읽지 않음)

## API 엔드포인트 목록

모든 경로는 글로벌 prefix `/api`를 포함합니다(예외: `/links/:shortId`, `/links/*splat`, `/redirect/*splat`). `v1`/`v2`는 `@Version` 데코레이터 기반 URI versioning으로 실제 호출 시 `/api/v1/...` 형태가 됩니다.

| Method | Path | Controller.method | 용도 |
| --- | --- | --- | --- |
| GET | /api/v1/health | HealthController.check | 헬스체크 (`health.controller.ts:5-11`) |
| POST | /api/v1/links | LinksController.createV1 | 단일 targetPath 단축 링크 발급 |
| POST | /api/v2/links | LinksController.createV2 | 다건 targetPath 배치 단축 링크 발급 |
| GET | /links/:shortId | LinksController.forwardWaLink | shortId → 실제 URL 포워딩(앱 브릿지 또는 302) |
| GET | /redirect/*splat | RedirectController.redirectDeepLink | 레거시 경로 기반 딥링크 포워딩 |
| GET | /api/v1/funding/projects/:projectNo/story | ProjectController.getStory | 펀딩 프로젝트 스토리 조회(+캐시 +GIF→Video) |
| GET | /api/v1/funding/projects/:projectNo/launching-soon-story | ProjectController.getLaunchingSoonStory | 런칭 예정 스토리 조회(+캐시 +GIF→Video) |
| DELETE | /api/v1/funding/projects/:projectNo/story/cache | ProjectController.deleteStoryCache | 스토리 캐시 삭제 (204) |
| DELETE | /api/v1/funding/projects/:projectNo/launching-soon-story/cache | ProjectController.deleteLaunchingSoonStoryCache | 런칭 예정 스토리 캐시 삭제 (204) |
| GET | /api/v1/proxy?targetUrl=... | ProxyController.proxyImage | 외부 리소스 프록시 다운로드(SSRF 방어 포함) |
| POST | /api/v1/settings | SettingsController.createV1 | 앱 설정 생성 (BEARER) |
| GET | /api/v1/settings?platform=...&feature=... | SettingsController.findV1 | 앱 설정 조회(플랫폼 + COMMON 병합, 캐시) |
| PATCH | /api/v1/settings/:id | SettingsController.updateV1 | 앱 설정 값 수정 (BEARER) |
| DELETE | /api/v1/settings/:id | SettingsController.removeV1 | 앱 설정 삭제 (BEARER) |
| GET | /api/v1/support/tickets | SupportController.getTickets | 사용자 Zendesk 티켓 목록 (AccountGuard) |
| GET | /api/v1/support/tickets/:ticketId | SupportController.getTicket | 티켓 상세(폼/필드/동적콘텐츠 포함) |
| POST | /api/v1/support/tickets | SupportController.postTicket | 티켓 생성(사용자 생성/동기화 포함) |
| PUT | /api/v1/support/tickets/:ticketId | SupportController.putTicket | 티켓 업데이트(댓글/상태/제목) |
| GET | /api/v1/support/ticket-forms?requesterType=supporter\|maker | SupportController.getTicketForms | 언어별 티켓 양식(+필드+동적콘텐츠) |
| POST | /api/v1/support/uploads | SupportController.postUploads | 첨부 파일 Zendesk 업로드 (multipart) |
| DELETE | /api/v1/support/uploads/:token | SupportController.deleteUploads | 첨부 파일 Zendesk 삭제 |
| POST | /api/v1/webhooks/help-center | WebhooksController.helpCenter | Zendesk 헬프센터 게시 webhook → 자동 번역(de/en/ja/zh) |

## 주요 API 상세 분석

### 1. GET /api/v1/funding/projects/:projectNo/story

- 위치: `src/api/funding/projects/project.controller.ts:33-46`, `project.service.ts:26-308`
- 캐시 키: `funding:project:story:{projectNo}:{language}-{country}` (기본 `en-US`, 헤더 `wadiz-country`, `wadiz-language` 기반) — `project.controller.ts:170-176`
- 캐시 TTL: 3분. 동일 키 in-flight 요청은 `Promise` 재사용으로 upstream 중복 호출 방지 (`project.controller.ts:26, 104-120`)
- Upstream 호출: `${BASE_URL}/web/apip/funding/global/projects/{projectNo}/{storyType}` — 즉, 공용 와디즈 펀딩 API(`com.wadiz.api.funding`류)로 전달. 30초 타임아웃, `AbortController`로 취소 (`project.controller.ts:181-248`)
- 전달 헤더: `accept`, `accept-language`, `cache-control`, `pragma`, `wadiz-country`, `wadiz-language`, `cookie` 화이트리스트
- Post-processing `ProjectService.replaceGifImagesToVideoTags`
  - 10초 처리 타임아웃 + 3초 HEAD 요청 타임아웃, 최대 병렬 10개
  - YouTube iframe → div placeholder 치환
  - `<img src>` → `data-src`로 변환, alt 기본값 `no description` 삽입
  - `.gif` URL에 대해 동일 경로의 `.mp4` 존재 여부를 HEAD로 확인 후, 존재 시 `<video>` 태그(자동재생 속성 포함)로 교체
  - live 환경에서는 `wadiz.kr` 도메인만 변환, 예외 도메인(`www.wadiz.kr`, `cdn.wadiz.kr` 등)은 스킵

### 2. POST /api/v1/links (및 v2)

- 위치: `src/api/links/links.controller.ts:18-50`, `links.service.ts:46-98`
- 입력 DTO `LinksRequestDto` / `LinksV2RequestDto` — targetPath 검증기:
  - `http://` 금지, `https://`는 화이트리스트 도메인(`wadiz.kr`, `wadiz.co` 서브도메인 포함) 허용 — `WHITELISTED_DOMAINS = ['wadiz.kr', 'wadiz.co']` (`domain.constants.ts`, FE1-856에서 `wadiz.ai` 제거·`wadiz.co` 추가)
  - 절대 경로는 `..` 상대표기와 `<>"'\\:!` 특수문자 금지 (`links.dto.ts:14-107`)
- 로직
  - `walinkid` 쿼리 제거 후 MD5 해시 생성 → 기존 레코드 존재하면 재사용
  - `nanoid(10)`으로 shortId 생성. `ER_DUP_ENTRY` 충돌 시 재시도 루프
  - 응답: `{ linkUrl: "${DOMAIN}/links/{shortId}", shortId, targetPath }`
- DB 저장: `walink` 테이블

### 3. GET /links/:shortId (브릿지 포워딩)

- 위치: `links.controller.ts:52-74`, 헬퍼 `links.service.ts:100-157`
- 순서
  1. 캐시에서 `targetPath` 조회 → 미존재 시 DB, 미매칭 시 `BASE_URL`로 단순 리다이렉트
  2. `getWalinkUrl(targetPath, referer)`로 최종 URL 구성
     - 절대 URL이면 도메인 화이트리스트 검사, 상대 경로는 `BASE_URL`과 결합
     - 쿼리에 `walinkid`(난수+현재시각 하위 5자리) 부여, `originReferer`에 referer 덮어쓰기
  3. User-Agent 판정(`request.helper.ts:1-15`): bot/desktop/비-BASE_URL 진입은 302, 모바일 웹뷰는 `walink-bridge.html`(앱 스킴 fallback)을 렌더

### 4. GET /api/v1/proxy?targetUrl=...

- 위치: `src/api/proxy/proxy.controller.ts:12-60`, `proxy.service.ts:10-100`
- SSRF 방어
  - `http(s)` 프로토콜만 허용
  - hostname에 `wadiz` 포함 금지(서비스 내부 루프 방지)
  - DNS 조회 후 사설망 IP 발견 시 거부 (`proxy.utils.ts`)
- 다운로드
  - 5분 타임아웃, 50MB 크기 제한
  - `Readable.fromWeb`으로 Node 스트림 변환, `StreamableFile` 반환
  - AbortController 기반 취소, SSL 인증서 오류(`UNABLE_TO_VERIFY_LEAF_SIGNATURE`, `CERT_HAS_EXPIRED`, `SELF_SIGNED_CERT_IN_CHAIN`)는 400으로 변환

### 5. 앱 설정 API (`/api/v1/settings`)

- 위치: `src/api/settings/settings.controller.ts`, `settings.service.ts`
- 인증: 쓰기 API는 `AuthGuard`로 `.env.BEARER_TOKEN` 정적 비교(내부용)
- 데이터 모델: `app_setting (platform_name ENUM, feature_name, setting_value TEXT JSON)` (`entities/app-setting.entity.ts`)
- 플랫폼 enum 분리 (CLIENT-104): `Platform`이 클라이언트용 `ClientPlatform`(`common/android/ios/web`)과 서버용 `ServerPlatform`(`web-server`)의 합집합으로 분리됨. `isServerPlatform()` 헬퍼로 서버 플랫폼 여부 판별
- 조회 로직 `find()` (`settings.service.ts:53-111`)
  - 플랫폼별 캐시 키 = `${platform}` (TTL 5분, `settings.module.ts:13`)
  - 병합 규칙 `getMergedCache()`: 서버 플랫폼(`web-server`)과 `COMMON`은 자체 설정만 반환, 그 외 클라이언트 플랫폼은 요청 플랫폼 캐시 + `COMMON` 캐시를 병합 후 (플랫폼 우선) 반환
  - `feature` 쿼리가 있으면 키 단위 필터
- 쓰기는 DB 저장 후 캐시 객체 선택적 갱신 (기존 키 존재 시만)

### 6. 고객센터 (Zendesk 연동) `/api/v1/support/*`

- 위치: `src/api/support/support.controller.ts`, `support.service.ts`
- 인증: 대부분 `AccountGuard` — OIDC access token으로 사용자 식별
- 특이 로직
  - 사용자 해석 `resolveZendeskUser(userInfo)` — 모든 티켓 API의 단일 진입점 (FE1-731)
    - `IS_EXTERNAL_ID_ENABLED=true`(dev/rc/live)이면 와디즈 `userId` 기준 `external_id:{userId}` 검색을 우선(`getZendeskUserInfoByExternalId`)하고, 미스 시 이메일 검색(`getZendeskUserInfo(email)`)으로 fallback. 이메일은 변경될 수 있으나 `userId`는 불변이므로 이메일 변경에도 매칭이 끊기지 않음
    - 이메일로 찾은 사용자의 `external_id`가 다른 `userId`면 이메일 재사용 충돌로 보고 매칭 거부(`null` 반환) + `logger.warn`으로 PII 없는 식별자만 관측 로그 기록. `external_id`가 비어 있는 레거시 사용자는 충돌이 아니므로 통과
    - 플래그가 꺼져 있으면 기존대로 이메일 기준 조회만 수행
  - `postTicket`
    - `locale_id` 캐시 미스 시 `/locales`에서 언어코드(`ko`, `en` 등) 선두 일치로 탐색
    - `IS_EXTERNAL_ID_ENABLED` 활성 시 `external_id` 불일치 **또는 이메일 불일치**면 `/users/create_or_update` 호출로 정보 동기화(이메일 변경 시 Zendesk 이메일도 갱신) + `external_id`에 `userId` 기록 (기존 `ENVIRONMENT === 'live'` 분기를 플래그 기반으로 대체)
    - 기본 커스텀 필드(응답 채널, 와디즈 계정 이메일, WAI session id) + 태그(`문의등록유입경로_*`) 자동 부여
  - `getTickets` (문의 목록)
    - Zendesk Search API를 `page`/`per_page`로 페이지네이션(이전 `offset`/`limit`는 미지원이라 수정 — QA-22336)
    - 정렬은 `sort_by=created_at&sort_order=desc`(등록 시간순). `created_at`은 Zendesk 정렬 키라 페이지네이션과 양립. 이전의 애플리케이션단 status 기준 정렬은 페이지 내에서만 적용돼 20건 초과 시 깨지므로 제거 (QA-22341)
  - `getTicket`
    - 본인 여부(`requester_id`) 및 `is_public` 확인 후 403
    - `ticket_form`, `ticket_fields`, dynamic content(언어별 `{{dc.*}}`) 병합하여 반환
    - 동적 콘텐츠는 `/dynamic_content/items`를 페이지네이션으로 모두 수집 (1시간 캐시)
  - `getTicketForms` — 요청자 유형(supporter/maker) + 언어(ko/non-ko)별 하드코딩된 폼 ID 세트(`support.constants.ts`)로 필터 및 정렬
  - `postUploads` — multipart 파일을 그대로 Zendesk `/uploads`로 전달. 파일명 latin1→UTF-8 재해석 + NFC 정규화

### 7. POST /api/v1/webhooks/help-center

- 위치: `src/api/webhooks/webhooks.controller.ts:18-117`, `help-center/help-center.service.ts`
- 인증: `ZendeskWebhookGuard` (HMAC-SHA256 서명 검증)
- 트리거: `type=zen:event-type:article.published` AND `event.locale=ko`
- 흐름
  1. 한국어 원본 문서 조회 (`/help_center/ko/articles/{id}`)
  2. 누락 번역 언어 조회 (`/help_center/articles/{id}/translations/missing`)
  3. 대상 언어 `de, en, ja, zh`에 대해 사내 번역 API 호출
     - `TranslateService`가 `${PLATFORM_GLOBAL_API_URL}/translate/html` 및 `/translate/text`를 `PLATFORM_GLOBAL_API_TOKEN` Bearer로 호출 (`help-center.service.ts:22-74`)
  4. 언어별 누락 여부에 따라 `POST /help_center/articles/{id}/translations` 또는 `PUT .../translations/{locale}` 분기 실행
  5. 로케일 치환 규칙: `en` → `en-us`, `zh` → `zh-cn`

## DB 스키마 요약

- 대상 DB: `DATABASE_NAME` (dev: `wadiz_app_dev`) — MySQL 8
- TypeORM 엔티티(SnakeNamingStrategy 사용, 공통 `created_at`, `updated_at` 컬럼은 `BaseEntity`에서 `registeredAt/updatedAt`으로 맵)
- 테이블 목록

| 테이블 | 엔티티 | 용도 |
| --- | --- | --- |
| walink | `WalinkEntity` (`src/api/links/entities/walink.entity.ts`) | 단축 URL: walink_no PK, target_path_hash(md5, 인덱스), target_path(varchar 2000), short_id(uniq 15자), is_app_store_fallback_enabled, created_at/updated_at |
| app_setting | `AppSettingEntity` (`src/api/settings/entities/app-setting.entity.ts`) | 앱 런타임 설정: setting_id PK, platform_name(클라이언트 common/android/ios/web + 서버 web-server), feature_name(30), setting_value(text JSON), UNIQUE(platform_name, feature_name) |

> Support/Help-Center/Proxy는 외부 Zendesk·와디즈 API를 직접 호출하므로 DB 테이블을 사용하지 않습니다.

## 외부 의존성

- 업스트림 서비스
  - 와디즈 펀딩 Public API: `${BASE_URL}/web/apip/funding/global/projects/...` — 스토리 원본 조회 (`project.controller.ts:188`)
  - 와디즈 OIDC 인증 서버(account.wadiz.kr): `ACCOUNT_API_OPENID_CONFIGURATION_URL` — `jwks_uri` + `userinfo_endpoint` 사용
  - 와디즈 Global Translate API(플랫폼 내부): `${PLATFORM_GLOBAL_API_URL}/translate/html`, `/translate/text`
  - Zendesk Support API: `https://{wadiz6256|wadiz-dev}.zendesk.com/api/v2/*` (Brand ID 및 계정을 환경별로 분기)
- 외부 CDN: 펀딩 스토리 내 이미지의 `.mp4` 존재 여부 확인을 위해 `HEAD` 요청(`wadiz.kr` 이하)
- 인프라
  - RDS MySQL 8 (AWS) — `DATABASE_*` 환경변수, AWS Secrets Manager `eks/secrets/client`에서 패스워드 주입
  - cloud 환경(`cdev`/`rc4`/`clive`) DB 인증 분기 (FE1-858): `ENVIRONMENT`가 cloud 환경이면 `APP_API_CLOUD_DATABASE_USER_NAME`과 cloud용 패스워드 시크릿을 사용. cloud 패스워드는 `clive`이면 `mysql_wadiz_app_password`, 그 외(cdev/rc4)는 `mysql_wadiz_app_dev_password`로 분기 (`typeorm.config.ts`의 `getCloudPassword`). 기존 `rc3` 환경은 제거됨
  - AWS EKS + ArgoCD 배포, AWS ECR 컨테이너 레지스트리
  - Datadog APM (`tracing.ts`, `DatadogTraceModule`, `DatadogErrorInterceptor`)
- 주요 환경 변수: `BASE_URL`, `DOMAIN`, `ENVIRONMENT`(live/dev/local + cloud: cdev/rc4/clive), `BEARER_TOKEN`, `APP_API_ZENDESK_SIGNING_SECRET`, `ZENDESK_API_TOKEN`, `IS_EXTERNAL_ID_ENABLED`(Zendesk external_id 우선 조회 토글), `ACCOUNT_API_OPENID_CONFIGURATION_URL`, `PLATFORM_GLOBAL_API_URL`, `PLATFORM_GLOBAL_API_TOKEN`, `DATABASE_*`, `APP_API_DATABASE_USER_NAME`, `APP_API_DATABASE_PASSWORD`, cloud 환경용 `APP_API_CLOUD_DATABASE_USER_NAME`, `mysql_wadiz_app_password`, `mysql_wadiz_app_dev_password`

## 특이사항

- BFF 특성상 자체 데이터는 최소(walink/app_setting 2개 테이블)이고, 대부분 외부 API를 래핑·가공·캐싱합니다. 대표 가공 로직은 펀딩 스토리의 GIF→Video 치환과 Zendesk 다국어 티켓 응답 조립입니다.
- URI 버저닝(v1/v2)을 혼용하지만 글로벌 prefix는 `/api`이며 `links`/`redirect` 일부 경로는 의도적으로 prefix에서 제외되어 사용자 직접 진입이 가능합니다 (`main.ts:45-54`).
- 동일 키 동시 요청 처리를 위해 `inflightRequests` Map과 `Promise.race` + `AbortController` 조합으로 duplicate upstream 호출을 차단합니다 (`project.controller.ts:26, 104-120`).
- SSRF 방지는 `proxy.controller.ts:24-40`에 집중되어 있으며 DNS 해석 후 사설 IP 범위 검사(`proxy.utils.isPrivateIp`)까지 수행합니다.
- Zendesk 웹훅은 `rawBody: true` 설정과 `timingSafeEqual` 비교로 서명 검증을 수행하며 (`main.ts:31`, `auth.guards.ts:113-123`), 번역 실패 언어는 건너뛰고 나머지는 계속 처리합니다.
- 로그는 production에서 JSON 포맷으로 출력되어 Datadog 수집 친화적으로 구성됩니다 (`main.ts:29-33`).
- 호출 주체 추정: 펀딩 스토리 API는 `wadiz-country`/`wadiz-language` 헤더와 `cookie`를 전달하는 구조상 와디즈 웹/모바일 앱과 Next.js 프론트에서 사용, `/links`는 광고·마케팅 단축링크 발급에 활용, Settings API는 앱 내부(iOS/Android/Web) 런타임 구성 조회에 사용되는 것으로 보입니다(`AppSettingEntity.platformName`). Support API는 고객센터 페이지와 앱의 "1:1 문의"에서 호출됩니다.
