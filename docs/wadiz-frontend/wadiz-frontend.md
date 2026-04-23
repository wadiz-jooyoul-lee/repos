# wadiz-frontend

> **Phase 2 심층 분석 진행 중**. 도메인별 상세는 `api-details/` 하위 참조.
>
> | 영역 | 파일 |
> |---|---|
> | 사용자 지향 apps (account/global/help-center/ir/partners/partnerzone) | [`api-details/apps-user-facing.md`](./api-details/apps-user-facing.md) |
> | 메이커/스튜디오 apps (studio/*/ wai/walink/mail/devtools) | [`api-details/apps-maker-studio.md`](./api-details/apps-maker-studio.md) |
> | static/entries/ (레거시 호환 진입점 13개) | [`api-details/static-entries.md`](./api-details/static-entries.md) |
> | static/services/admin (와디즈 어드민 SPA) | [`api-details/admin-spa.md`](./api-details/admin-spa.md) |
> | packages/ (공유 패키지 20+) | [`api-details/packages.md`](./api-details/packages.md) |

## 개요
와디즈의 **신규 프론트엔드 모노레포**. "모든 FE 서비스를 단일 저장소에서 운영"이라는 목표로 다수의 앱(account, global, partners, ir, partnerzone, help-center, mail-template, wai-ai-agent-launcher, walink-generator)을 한 곳에 묶었습니다. `com.wadiz.web` (Spring 3.2 + JSP) 의 점진적 후계. Org: `wadiz-fe`.

## 기술 스택
- **빌드/패키지**: pnpm + turbo (모노레포), 일부 `static/` 영역에 yarn workspace 잔존.
- **프레임워크**: React 18, Vite 6, Next.js 14·16 혼재(앱별).
- **상태/데이터**: TanStack Query, Zustand, Recoil(잔존), 자체 Custom Hooks.
- **스타일**: SCSS Modules, Tailwind, Emotion 일부.
- **테스트**: Vitest, Storybook, Playwright (앱별).

## 앱/패키지 구성

### `apps/`
| 앱 | 역할 | 호출 Upstream |
|---|---|---|
| `account` | 글로벌 회원 (로그인/회원가입/프로필) | `account.wadiz.kr`, `app.wadiz.kr` |
| `global` | 글로벌 사이트 | `public-api.wadiz.kr`, `app.wadiz.kr` |
| `partners` | 파트너 소개 | `public-api.wadiz.kr` |
| `partnerzone` | 파트너존 (입점·운영) | `app.wadiz.kr`, `platform.wadiz.kr` |
| `ir` | IR (투자자 정보) | static + 일부 API |
| `help-center` | 고객센터 | `app.wadiz.kr` |
| `mail-template` | 이메일 템플릿 빌더 | n/a |
| `wai-ai-agent-launcher` | WAi AI 에이전트 런처 | `app.wadiz.kr` (WAi) |
| `walink-generator` | 와링크(단축 URL) 생성기 | `app.wadiz.kr/links` |
| `devtools/*` | 개발자 도구 | n/a |

### `studio/`
- `funding`, `startup`, `store` — 메이커/스튜디오 작성 도구.

### `static/entries/` (15개)
- 레거시 호환용 정적 진입점들. 기존 `com.wadiz.web` 의 페이지 단위로 분리되어 점진 이관됨.

### `static/services/`
- `admin` — 와디즈 어드민 SPA(webpack 4). PROXY_TARGET 환경변수로 `devadm/rcadm/rc2adm.wadiz.kr` 또는 `adm.dev.wadiz.co` 로 프록시.

### `packages/` / `libraries/`
- 공통 UI, API 클라이언트, 디자인 토큰, 유틸 등.

## 서버 연결 설정 (핵심)

### 환경 변수 주입
- 빌드: `env-cmd --environments {local|dev|rc|rc2|rc3|stage|live}` + `.env-cmdrc` → Vite `define` 에서 `process.env.*` 로 치환.
- 주요 환경변수:

| 변수 | 의미 |
|---|---|
| `VITE_ACCOUNT_URL` | 회원 IdP (`account.wadiz.kr`) |
| `VITE_APP_API_URL` | NestJS BFF (`app.wadiz.kr`) |
| `VITE_PLATFORM_API_URL` | 플랫폼 API (쪽지/알림/Nicepay/share/marketing) |
| `VITE_PUBLIC_API_URL` | 비로그인 공개 API (`public-api.wadiz.kr`) |
| `VITE_SERVICE_API_URL` | 레거시 서비스(`www.wadiz.kr` `/web/*`, `/web/apip/funding/*`) |
| `VITE_PLATFORM_GLOBAL_API_URL` | 플랫폼 글로벌 |

### Upstream 서버 매핑
| 도메인 | 실체 |
|---|---|
| `account.wadiz.kr` | `kr.wadiz.account` (OAuth2 IdP) |
| `www.wadiz.kr` | `com.wadiz.web` (레거시 Spring 3.2) |
| `app.wadiz.kr` | `app-api` (NestJS BFF) |
| `platform.wadiz.kr` | 플랫폼 서비스 군 (쪽지·알림·Nicepay·share·marketing) |
| `public-api.wadiz.kr` | 비로그인 공개 API |
| `api.makercenter.wadiz.kr` | `makercenter-be` (메이커센터 공지 임베드용) |
| `analytics.wadiz.kr` / `datasvc.wadiz.kr` | 데이터/애널리틱스 |

### Fetch 래퍼
- 위치: `packages/api/src/fetch.ts:22-105`
- HTTP 메서드: GET/POST/PUT/PATCH/DELETE.
- 기본 헤더: `wadiz-country`, `wadiz-language` (i18n 라우팅용).
- Credentials: `same-origin` (쿠키 세션 기반 인증, 와디즈 통합 도메인 전략).
- 인터셉터: 401/403 시 `account.wadiz.kr` 재로그인 리다이렉트.

## 기능별 API 호출 매핑 (대표)

| 기능/화면 | Method + Path | 용도 | Upstream |
|---|---|---|---|
| 로그인 | POST `/account/oauth/...` | 세션 발급 | account.wadiz.kr |
| 세션 → 토큰 교환 | GET `/session2token` | API 호출용 토큰 발급 | app.wadiz.kr |
| 펀딩 메인 피드 | GET `/web/main` | 메인 카탈로그 | www.wadiz.kr (레거시) |
| 펀딩 프로젝트 상세 | GET `/web/apip/funding/projects/:id` | 프로젝트 정보 | www.wadiz.kr |
| 서포터 목록 | GET `/web/apip/funding/projects/:id/supporters` | 서포터 리스트 | www.wadiz.kr |
| 마이펀딩 | GET `/web/myfunding` | 내가 후원한 프로젝트 | www.wadiz.kr |
| 리워드 정보 | GET `/web/apip/funding/reward/...` | 리워드 옵션 | www.wadiz.kr |
| Nicepay 결제 | POST `/platform/nicepay/...` | PG 결제 인증/승인 | platform.wadiz.kr → nicepay-api |
| 쪽지함 (Inbox) | GET `/platform/inbox/...` | 쪽지 조회 | platform.wadiz.kr |
| 마케팅 알림 | POST `/platform/marketing/...` | 알림 옵트인 | platform.wadiz.kr |
| 공유 링크 | POST `/platform/share/...` | 공유 링크 발급 | platform.wadiz.kr |
| 회원 가입 | POST `/account/signup` | 가입 | account.wadiz.kr |
| WAi 에이전트 | POST `/app/wai/...` | AI 에이전트 호출 | app.wadiz.kr |
| 와링크 생성 | POST `/app/links/...` | 단축 URL 생성 | app.wadiz.kr |
| 검색 | GET `/web/search?q=...` | 통합 검색 | www.wadiz.kr |
| 멤버십 | GET `/web/membership/...` | 멤버십 정보 | www.wadiz.kr |
| 메이커센터 공지 임베드 | GET `/api/makercenter/notices/...` | 공지 임베드 | api.makercenter.wadiz.kr |

> Bearer 토큰: `packages/api/src/platform/inbox.service.ts:8-10` 와 `.env-cmdrc` 에 platform inbox/marketing 용 토큰이 하드코딩되어 있음 — **보안 점검 필요 항목**.

## 빌드·배포

- 명령: `pnpm install`, `pnpm dev:<app>`, `pnpm build:<app> --env <env>`.
- turbo pipeline 으로 의존 패키지 우선 빌드.
- 배포: 앱별 S3 + CloudFront 또는 Next 서버. GitHub Actions로 환경별(`dev`, `rc`, `stage`, `live`) 배포.
- `static/services/admin` 은 webpack 4 단독 빌드 (PROXY_TARGET 분기).

## 특이사항

- 모노레포지만 **앱별 빌드 도구가 다름** (Vite 6 vs Next 14 vs Next 16). 점진 통일 진행 중.
- `static/entries/` 는 레거시 JSP에서 직접 import 하던 정적 번들의 후계 — `com.wadiz.web` 이관의 흔적.
- `account.wadiz.kr` 도메인 분리 IdP 전략으로 모든 와디즈 서비스가 단일 OAuth2 세션 공유.
- 환경별 토큰·URL이 `.env-cmdrc` 에 모여 있어 한 파일로 다환경 관리.
- 어드민(static/services/admin)은 아직 webpack 4 — 모더나이제이션 후순위.
