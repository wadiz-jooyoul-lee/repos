# makercenter-fe

> 📅 **2026-08-25 cloud_live pull 보강** (8 커밋)
>
> ⚠️ **기준 브랜치가 `main` → `cloud_live` 로 바뀌었습니다.**
>
> ### FE2-905 — 와디즈 도메인 `wadiz.io` 전환
> - dev·local 환경의 와디즈 도메인을 **`wadiz.io`** 로 전환하고, 자산·링크 origin 기본값도 `wadiz.io` 로 바꿨으며 clive 환경 origin 을 교정했습니다 (`.env`, `.env.local.sample`, `.env.production.dev`, `.env.production.clive`, `.env.production.live`).
> - 고객센터 origin 을 환경 변수로 분리하고 `io` 정적 origin 을 화이트리스트에 추가했습니다 (`src/shared/config/urls.ts`, `src/shared/lib/url.ts`, `src/shared/types/env.d.ts`, `src/widgets/inner-html/api/fetchPageHtml.ts`, `src/widgets/inner-html/ui/InnerHtml.tsx`, `src/widgets/footer/ui/WadizFooter.tsx`, `src/shared/lib/pageMetadata.ts`). 검증 테스트 `url.test.ts`·`fetchPageHtml.test.ts` 보강.
> - WAI AI 에이전트 `environment` 값을 **cdev·clive** 로 전환했습니다.
>
> ### FE2-1121 — cloud_live 환경을 운영으로 판정해 robots.txt 색인 허용
> - `cloud_live` 환경이 운영으로 판정되지 않아 `robots.txt` 가 색인을 막던 문제를 고쳤습니다.
>
> ### FE2-718 / FE2-862 — 기타
> - FE2-718: `cloud_live(clive)` 배포 환경 추가 — `.env.production.clive` 신규 및 `Dockerfile`·CI 워크플로(`app-makercenter-ci.yml`, `event-makercenter-ci.yml`) 반영.
> - FE2-862: `src/app/robots.ts` 차단 목록에서 AI 크롤러 **Bytespider** 제거.
>
> ---
>
> 📅 **2026-07-21 main pull 보강** (4 커밋)
>
> ### FE2-719 — 외부 서비스 URL을 env 기반 상수로 분리
> - 와디즈 외부 서비스 URL을 하드코딩 대신 **환경 변수 기반 상수**로 분리(`src/shared/config/urls.ts`, `src/shared/types/env.d.ts`, `.env*`). 헤더/푸터/사이드바/숏컷 등 UI 위젯이 이 상수를 참조하도록 교체.
>
> ### FE2-746 — E2E를 원격 배포 환경 실데이터 검증으로 전환
> - Playwright E2E를 로컬이 아닌 **원격 배포 환경 대상 실데이터 검증**으로 전환하고 인수조건 테스트 추가. GitHub Actions 워크플로우 `app-makercenter-e2e.yml` 신규, `e2e/helpers/base-url.ts`·`utils.ts` 도입, home/search/menu SSR·SEO i18n·언어 스위처 등 테스트 보강.

## 개요
**메이커(프로젝트 개설자)용 사용자 포털** (Next.js 앱). `makercenter.wadiz.kr` (live) / `dev.makercenter.wadiz.kr` (dev) 에 배포되어 메이커가 자신의 프로젝트를 등록·운영하는 화면을 제공합니다. Org: `wadiz-client`. 패키지명 `wadiz-makercenter`.

## 기술 스택
- **Next.js 16** (App Router) + React 19, dev 포트 4020 (`next dev`). (구 CRA/Vite SPA에서 Next.js로 마이그레이션 완료.)
- **TypeScript** 전면 적용 (src 하위 `.tsx`/`.ts`만, `.js`/`.jsx` 없음).
- 스타일: **SCSS Modules**(`*.module.scss`, sass) — MUI는 더 이상 사용하지 않음.
- 상태: **Redux Toolkit**(`@reduxjs/toolkit`). (Recoil/React Query 미사용.)
- HTTP: Axios `1.15`.
- 테스트: Playwright (E2E).
- Sentry 연동.

## 앱 구성
- Next.js App Router + FSD(Feature-Sliced Design) 구조. 주요 폴더(`src/`):
  - `app/` — App Router 엔트리 (`layout.tsx`, `page.tsx`, `[lang]`, `oauth`, `robots.ts`, `sitemap.ts`, `providers/`)
  - `entities/` — 도메인 API/모델 (`home`, `board`, `exhibition`, `data`, `menu`)
  - `features/`, `widgets/`, `views/`, `shared/`(`api`, `config`, `lib`, `providers`, `types`, `ui`), `hooks/`

## 서버 연결 설정 (핵심)

### Axios 인스턴스 (`src/shared/api/axiosInstance.ts`)
- `baseURL = ${process.env.NEXT_PUBLIC_BASE_URL}/api`
- `withCredentials: true` (쿠키 세션 기반)
- `validateStatus: status === 200` (단순 검증, 그 외는 에러)
- 응답 인터셉터: 코드 `4010` / `4012` 감지 시 `auth:expired` CustomEvent 디스패치 → 글로벌 핸들러가 OAuth 재로그인 트리거.

### 환경별 Base URL
| 환경 | Base URL |
|---|---|
| dev | `https://dev-api.makercenter.wadiz.kr` |
| live | `https://api.makercenter.wadiz.kr` |

### Upstream
- 직접 호출: **`makercenter-be`** (Spring Boot 2.7) 가 거의 단일 Backend.
- 인증: BE가 OAuth 처리 → `/api/oauth/authorize` 호출 → IdP `account.wadiz.kr` 리다이렉트 → `/api/oauth/callback` 으로 복귀.

## 기능별 API 호출 매핑 (대표)

| 기능/화면 | Method + Path | 용도 |
|---|---|---|
| 좌측 메뉴 | GET `/api/menu` | 메뉴 트리 조회 |
| 메인 화면 위젯 | GET `/api/main` | 메인 KV·통계 |
| 공지 배너 | GET `/api/banner/main` | 메인 배너 |
| 메인 팝업 | GET `/api/popup/main` | 팝업 |
| 게시판 리스트 | GET `/api/board?category=...` | 카테고리별 글 목록 |
| 게시판 상세 | GET `/api/board/:id` | 글 상세 |
| 게시판 검색 | GET `/api/board/search?q=...` | 키워드 검색 |
| 기획전 신청 | POST `/api/exhibition/apply` | 메이커 기획전 신청 |
| 기획전 철회 | DELETE `/api/exhibition/:id` | 신청 철회 |
| 기획전 목록 | GET `/api/exhibition` | 진행 중 기획전 |
| 공휴일 정보 | GET `/api/data/holidays` | 캘린더 공휴일 표시 |
| 홈 알림 | GET `/api/home/notice` | 알림 메시지 |
| 로그아웃 | POST `/api/auth/logout` | 세션 종료 |

## 빌드·배포

- `pnpm dev` (포트 4020), `pnpm build`.
- GitHub Actions → S3 (`dev.makercenter.wadiz.kr` / `makercenter.wadiz.kr`) + CloudFront invalidation.
- 환경 분기: `.env.dev` / `.env.live`.

## 특이사항

- **CRA → Vite 마이그레이션 완료** (`config-overrides.js` 부재, `vite.config.js` 단독). 그러나 `react-query ^3.39` 는 v5로 미이관.
- **MUI v4/v5 공존** — 컴포넌트 점진 교체 중. 신규 코드는 v5 권장.
- 토큰 저장 안 함 (쿠키 세션). makercenter-fe-admin 과 인증 방식이 다름 (admin은 localStorage 토큰).
- Axios `0.21.1` 잔존 — 최신 `1.x` 마이그레이션 미완.
- `auth:expired` CustomEvent 패턴 — 인터셉터에서 직접 redirect 하지 않고 이벤트로 위임 → 화면 단에서 모달/리다이렉트 정책 결정 가능.

---

## 최근 변경사항

> 📅 **2026-07-10 main pull 보강** (31 커밋)
>
> 이 기간 변경은 대부분 **i18n(다국어)/SSR 정합**과 **REST 계약 표준화**에 집중되어 있음. (i18n 인프라 자체는 CLIENT-122/123으로 2026-05말 선반영됨.)
>
> ### CLIENT-169 — axios 응답 정책 완화 + 기획전 API REST 표준 전환
> - `axiosInstance` `validateStatus` 를 `200` 단독 → **2xx 전체 수용**(`isSuccessStatus`)으로 완화. 201(생성)·204(내용 없음) 정상 처리 (`src/shared/api/axiosInstance.ts:17`).
> - 세션 만료 판정을 `isSessionExpired` 순수함수로 분리 — **봉투 없는 HTTP 401** 과 레거시 봉투 코드 `4010/4012` 를 함께 만료로 보고 `auth:expired` 디스패치 (`src/shared/api/axiosInstance.ts:30`).
> - 기획전 계약 레이어를 REST 표준 URI로 교체: 신청폼 `GET exhibitions/{no}/application-form`, 신청 `POST exhibitions/user/applications`, 참여 프로젝트 `GET exhibitions/user/projects`, 철회폼 `GET exhibitions/user/withdrawal-form`, 철회 `PATCH exhibitions/user/applications/{applicationId}/withdraw`. `ApiEnvelope` 봉투 의존 제거, 철회 시 `applicationId` 누락이면 호출 전 차단 (`src/entities/exhibition/api/exhibition.ts`).
>
> ### CLIENT-175 — 헤더·배너·메뉴 SSR 첫 페인트 정합 (상단부 CLS 제거)
> - 헤더 툴바 분기를 `useIsMobile() ?? useDeviceHint()` 로 전환해 mobile→desktop 스왑 제거.
> - 상단 배너를 `homeServer.fetchTopBanner` 로 RSC에서 SSR 주입, Viewer(ssr:false)→`fr-view` 인라인으로 교체. 헤더 네비도 `fetchMenuTree()` 로 SSR 시드, `AppShell` 은 시드 성공 시 CSR fetch skip (`src/entities/home/api/homeServer.ts`).
>
> ### CLIENT-121 — 홈 화면 SSR 대응 + 하이드레이션 미스매치 정정
> - 홈 뷰를 SSR 대응으로 전환, 언어 판정을 `window` 직접 접근 → `react-i18next` 훅화하여 SSR/CSR 하이드레이션 미스매치 제거 (`src/views/home/ui/HomeView.tsx`, `src/entities/home/api/homeServer.ts`).
> - 공통 `Link` prefetch 기본 off — dynamic 라우트 RSC prefetch 노이즈 제거. 모바일 UA 판정 유틸 신설(`src/shared/lib/isMobileUA.ts`).
>
> ### CLIENT-176 — 언어 전환 시 헤더 네비 메뉴가 이전 언어로 고정되던 문제 수정
> - `MenuProvider` 가 `[lang]` 세그먼트 경계 위(root layout)에 있어 언어 전환 시 리마운트되지 않던 문제. `router.refresh()` 로 새로 내려오는 `initialMenu` 를 렌더 중 감지해 채택.
>
> ### FE2-719 — 정적 CDN URL 하드코딩을 env 기반 상수로 분리
> - `NEXT_PUBLIC_STATIC_URL` 의미를 "항상 live CDN" → **배포 환경별 CDN**(dev: `static-dev.wadiz.kr` / live: `static.wadiz.kr`)으로 재정의.
> - live 고정이 필요한 곳(푸터 주의 아이콘)을 위해 `NEXT_PUBLIC_STATIC_LIVE_URL` 신설. AI 에이전트 런처 스크립트 URL의 dev/live 하드코딩 분기 제거.
>
> ### FE2-590 — 와디즈 Organization JSON-LD 전역 노드 추가
> - 매 Article마다 인라인하던 `publisher` 를 단일 Organization 노드(SSOT)로 두고 `@id` 참조로 전환, 직렬화 함수 `safeJsonForScript` 를 `jsonLd` 모듈로 공용화 (`src/shared/lib/jsonLd.ts`).
>
> ### CLIENT-190 — WAI AI 상담 런처에 현재 언어값 전달
> - 푸터 채팅 상담 버튼으로 WAI 대화창을 열 때 현재 설정 언어를 전달 (`src/widgets/footer/ui/WadizFooter.tsx`).
>
> ### CLIENT-127 — Weglot 잔재(`data-wg-notranslate`) 제거
> - WAI 런처·캘린더·홈 배너 등에 남아있던 구 Weglot 번역 예외 속성 정리.
>
> ### CLIENT-164 — 캘린더/게시판 다국어 대응 + 공지글 제목 UI
> - 캘린더 영역 다국어 추가, "이벤트·혜택" 게시판명 하드코딩 제거, 공지글 제목이 길 때 작성 날짜가 찌그러지지 않도록 수정 (`src/widgets/calendar/ui/McCalendar.tsx`).
>
> ---

**분석 갱신일: 2026-07-10** (직전: 2026-06-19, 최초: 2026-04-20)

| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 전역 서체 Pretendard 적용 + 전역 스타일 통합 (`global.scss` 신설, `mui-css-baseline.scss`·`main.scss` 통합), 에디터 본문(`.fr-view`) 서체 Pretendard 상속, 불필요 서체 NotoSansKR 제거, 모바일 인풋 포커스 시 페이지 자동확대 방지 | 2026-06-05~09 | FE2-465 |
| 앱 웹뷰 첨부파일 다운로드 시 blob 대신 https 원본 URL 처리 (blob 스킴 크래시 회피, PC는 파일명 지정 다운로드 유지) | 2026-06-01 | FE2-447 |
| 채널톡(Channel.io) 제거 + 구 Footer dead asset(`Footer.tsx`/`.module.scss`·`wadizCopy.svg`·`chatCircle.svg`) 제거 | 2026-06-01 | FE2-425 |
| 기획전 신청폼 문항 진입 GTM 이벤트 수집 추가 | 2026-05-26 | CLIENT-119 |
| 게시글 본문 렌더 시 `fr-view` 래퍼 조건부 부착 | 2026-05-22 | CLIENT-116 |
| 로그인 완료 이벤트 수집 추가 | 2026-05-20 | CLIENT-110 |
| sns_url 그룹 이동 동기화 (부모 비활성값 컨벤션 적용) | 2026-05-14 | CLIENT-95 |
| 젠데스크 문의 연결 링크 교체 | 2026-05-11 | FE2-361 |
| Axios 0.21.1 → 1.15.0 메이저 업그레이드 완료 | 2026-04-14 | CLIENT-57 |
