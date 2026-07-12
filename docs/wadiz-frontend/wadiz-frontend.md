# wadiz-frontend

> 📅 **2026-07-10 master pull 보강** (직전 갱신 2026-06-18 이후 약 684 커밋, 이슈키 60여 종)
>
> 상위 net-new 테마만 추립니다. QA-22xxx 계열 버그픽스 37종 다수는 개별 나열 생략.
>
> ### FE2-670 — apps/global E2E 테스트 앱 신규 추가
> - `apps/global`(글로벌 SPA) 전용 Playwright E2E 프로젝트를 별도 앱으로 신설. 메이커 홈 시나리오부터 시작하며 rc·rc2 환경 스케줄과 브랜치 체크아웃 매핑 포함 (`apps/global-e2e/` — `playwright.config.ts`, `auth.setup.ts`, `maker/`, `helpers/env.ts`)
>
> ### FE2-423 / FE2-648 / FE2-649 / FE2-567 — 매출UP 메이커 광고 페이지 신설
> - 글로벌 앱에 메이커 광고 제안 페이지 신규 구현. WAi greeting instruction(인사말 지침·천 단위 컴마·80자 요약·`<br />` 전용 줄바꿈 규칙), 단계별 전략, 광고 상품 카드 섹션 리뉴얼, 지면별 GA 데이터 수집 (`apps/global/src/pages/maker/ad/` — `MakerAdPage.tsx`, `_lib/salesUpGreetingInstruction.ts`, `_lib/salesUpStrategy.constants.ts`, `_lib/salesUpFallbackCopy.ts`, `_ui/SalesUpOpeningSection/`, `_ui/AdServiceCardSection/`)
> - 메이커홈 WAi greeting 본문 지침 분리·고도화 (FE2-567)
>
> ### FE1-1060 / FE1-1061 / FE2-634 — 클라우드 도메인 wadiz.co → wadiz.io 전환
> - 클라우드 환경 도메인을 `wadiz.co` 에서 `wadiz.io` 로 교체하는 전역 설정 변경. 게이트웨이·스토리 이미지 클라우드 판별과 WAi WebSocket 호스트를 `.io` 기준으로 통일, cdev 환경 교체, `getCloudTld` 제거로 `.io` 전용화 (`static/packages/fetch-api/src/utils/fetchUrl.ts`, `apps/global/src/features/wai/lib/useWAiWebSocket.ts`, `static/services/admin/proxyInfo.js`)
> - clive 웹 호스트 `clive.wadiz.io` → `www.wadiz.io`, 스튜디오 클라우드 도메인 `.co` → `.io` (FE2-634)
> - 로컬 인증서를 `wadiz.io`·`wadiz.com` 포함 4개 TLD로 갱신 (FE1-1061)
>
> ### FE1-988 — GNB 친구 탭 → 와디즈 에디션 탭 교체
> - 하단 네비게이션(BottomNavigationBar) 친구 탭을 "와디즈 에디션" 탭으로 교체, 데스크탑에서 에디션 기획전 네비게이션·목록 노출, 신규 에디션 아이콘 추가 (`packages/ui/src/BottomNavigationBar/BottomNavigationBar.constants.tsx`, `packages/waffle-icons/src/components/EditionIcon.ts`·`EditionOIcon.ts`, `assets/edition.svg`)
>
> ### FE1-927 — 펀딩 상세 E2E testid 대량 추가 (regression 대비)
> - 펀딩 상세의 탭바(탭별), 커뮤니티 필터·섹션·CTA·팔로우·모달, 리워드 선택 모달 Continue to Checkout 버튼 등에 E2E testid 부여. 셀렉터가 아닌 검증용 testid 정리 포함
>
> ### FE2-461 — 모두의 펀딩 자동 랜덤처리
> - 메인 파인딩 배너의 "모두의 펀딩" 자동 랜덤 처리 및 GA label 정비, 스토어 스튜디오 검색 서비스 연동 (`packages/widgets/src/home/ui/MainFindingBanner/MainFindingBanner.tsx`, `studio/store/src/services/serviceApi/search.ts`)
>
> ### FE2-472 — 스토어/입고 스튜디오 E2E 보강
> - 입고 진입 등 스토어 스튜디오 E2E 테스트 추가와 라이브 환경 실행 차단 가드·부재 시 스킵 가드 도입
>
> ### FE1-1110 — 국내 결제수단 뱃지 복원
> - 국내 결제 화면 간편결제·토스 뱃지 복원. 결제 페이지 데이터·campaigns 서비스 응답 반영 (`apps/global/src/pages/funding/payment/_api/usePaymentPageData.ts`, `packages/api/src/web/funding/campaigns.service.ts`)
>
> ### FE1-1042 / FE1-978 — 메이커 기획전 쿠폰·정렬 개편
> - 쿠폰 범위 min/max 개방 구간 입력 지원, 정렬 기준 enum화(최근 오픈순 추가)·정렬 위치 이동, 쿠폰 입력을 정렬과 무관하게 항상 노출/저장 (FE1-1042)
> - dev 환경에서 `maker-projects` 쿼리 파라미터로 메이커 기획전 응답 오버라이드 (FE1-978)
>
> ### FE1-1012 — 기획전 Framer 카드 data-ec 수집
> - 기획전 Framer 카드에 표준 `data-ec` 오버레이 수집 구현. 오버레이 렌더 전 iframe 클릭 차단으로 수집 오차 방지, `data-ec-list` 프레이머 구분값을 framer URL path 기준으로 변경
>
> ### FE1-1097 — 위시/로그인 EncUserId 수집·Sentry 관측
> - static main 라우터 errorElement에 Sentry 관측 추가, 위시 목록 `encUserId` 미존재 대응 및 로그인 EncUserId 누락 수집(`useLoginStatus` 반환값 기준)
>
> ### FE1-1089 / CLIENT-177 — 메일 템플릿
> - 개인정보 이용내역 메일 템플릿 개편 (FE1-1089)
> - `mail-template` 워크플로에 cdev 환경 추가·`build:cdev` 스크립트 도입, `build:dev` 제거 (CLIENT-177)
>
> ### FE1-1032 — account 앱 검색/alias 정비
> - account 앱에 `@wadiz/format`·`@wadiz/queries` alias 추가, `useSearchHelper`의 `@wadiz/queries` 의존을 `AccountSettings`로 교체, 최근 검색어 API `encUserId` 타입을 string 허용으로 확장
>
> ### FE1-973 — 리워드 보유기간/배송지
> - 보유기간 경과·취소 건 배송지 미노출 처리 및 목록 보유기간 안내 문구 추가
>
> ---

> **Phase 2 심층 분석 진행 중**. 도메인별 상세는 `api-details/` 하위 참조.
>
> | 영역 | 파일 |
> |---|---|
> | 사용자 지향 apps (account/global/help-center/ir/partners/partnerzone) | [`api-details/apps-user-facing.md`](./api-details/apps-user-facing.md) |
> | 메이커/스튜디오 apps (studio/*/ wai/walink/mail/devtools) | [`api-details/apps-maker-studio.md`](./api-details/apps-maker-studio.md) |
> | static/entries/ (레거시 호환 진입점 13개) | [`api-details/static-entries.md`](./api-details/static-entries.md) |
> | static/services/admin (와디즈 어드민 SPA) | [`api-details/admin-spa.md`](./api-details/admin-spa.md) |
> | packages/ (공유 패키지 20+) | [`api-details/packages.md`](./api-details/packages.md) |
> | **모든 페이지 전수 카탈로그** (270+ 페이지) | [`api-details/pages-catalog.md`](./api-details/pages-catalog.md) |

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

---

## 최근 변경사항

**분석 갱신일: 2026-07-10** (최초: 2026-04-20 / 직전: 2026-06-18 — 최신 net-new는 문서 상단 2026-07-10 보강 블록 참조)

### 계정 / 로그인 (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 와디즈 앱 웹뷰에서 구글/페이스북 SNS 로그인·가입 차단(임베디드 웹뷰 OAuth 정책 대응). 차단 시 안내 알럿 노출, `isWadizAndroidApp`/`isWadizIosApp` UA 플래그로 앱 웹뷰 판별 | 2026-06-17 | FE1-846 |
| 인앱 SNS 차단 로직(`inAppBlacklist`/`isInAppBlock`/`inAppBlackHandler`)을 `apps/account/src/shared/oauth/inAppBlock.js` 단일 모듈로 공통화(기존 import는 re-export 유지). 차단 표시명을 `WADIZ_APP` 상수로 통합 | 2026-06-17 | FE1-846 |
| JSP 문서 캐싱으로 인한 로그인 갱신 이슈 수정 — `AccountSettings` 생성자에서 `window.wadiz.globals` 기반 초기화 제거, 항상 `initialize()` 호출로 세션 확인하도록 변경 | 2026-06-16 | FE1-950 |

### 개발자 도구 — 앱 설정 콘솔(app-settings-console) 전면 개편 (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| FSD(Feature-Sliced Design) 구조로 재구성(app/pages/entities/shared), axios→네이티브 fetch 전환, CSS Modules + WDS 토큰 도입, Button·Select·AppSettingCard 컴포넌트 분리 | 2026-06-15~16 | CLIENT-104 |
| `local` 환경 + `platform`(web/web-server) 선택 추가, 환경·플랫폼 선택값을 URL 쿼리 파라미터로 유지, 우측 상단 환경 워터마크 표시, app-settings API 네임스페이스 방식 호출 | 2026-06-15~16 | CLIENT-104 |
| 상세는 [`api-details/apps-maker-studio.md` §8-A](./api-details/apps-maker-studio.md) 참조 | | |

### 글로벌 / 펀딩 상세 (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 직접 입력 옵션 안내문구 노출 — by-country 리워드 응답의 `optionGuide` 필드 정합 및 안내문구 폰트/색상/간격 디자인 대응 | 2026-06-18 | FE1-979 |
| 마이와디즈 공지 배너 여백 보정(PC 16px/MO 10px) + 서포터 클럽 혜택 가로 스크롤 페이드 그라데이션 오버레이 추가 | 2026-06-16 | FE1-952 |

### 스튜디오 / 스토리 AI (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 스토리 생성 AI 진입구 확대 — 프로젝트 만들기 페이지·펀딩 스튜디오에 StoryGenerationBanner/StoryGenerationSection·AITextButton 등 진입 UI 추가 | 2026-06-15 | FE2-532 |
| 펀딩 스튜디오 시작·종료일 기간 표기 오류 수정 — 기간 계산 유틸(`helpers/date.ts`) 추가 후 일정/오픈예정 현황 페이지에 적용 | 2026-06-16 | FE2-543 |
| 스튜디오 e2e schedule GitHub Action 추가(시크릿 키 inputs 선언 포함) | 2026-06-17 | FE2-549 |

### studio-services 신규 API 클라이언트 (2026-06)
| 변경 내용 | 관련 이슈 |
|---|---|
| `funding/campaign-markers.services.ts` — 인디맨드 펀딩 여부 조회(`/web/apip/funding/campaign-markers/{id}/indemand-funding`) | |
| `funding/studio-stripe-accounts.services.ts` — Stripe Connect 계정 상태 조회(`PayoutMethodType` NICE/PINGPONG/STRIPE, `StripeKycStatus` 10종) | |
| `reward/maker-communications.services.ts` — 언어별 메이커 피드백 최신/히스토리·추가 질문 조회(`/web/reward/api/v2/maker-communications/...`) | |
| `reward/studio-campaigns.services.ts` — 사후심사 재제출(`revival-re-submit`) 및 스튜디오 캠페인 상태/배너 응답 타입 | |

### 글로벌 / 결제
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 글로벌 결제 화면 통화 표기·멤버십 배지 노출 정비 | 2026-05-22 | FE1-743 |
| 글로벌 선정산 도입 — 이용약관·메이커 이용약관·메일 템플릿 다국어 | 2026-05-21~22 | FE2-401/402 |
| 스트라이프 커넥트 메일 템플릿 핑퐁 영역 수정 | 2026-05-27 | FE2-270 |

### 서포터클럽
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| CurationSupporterClubCard 컴포넌트 추가 및 카드 교체 | 2026-05-26 | FE1-762 |
| 서포터클럽 인트로 페이지 디자인 수정, 해지방어 페이지 카드 너비 분리 | 2026-05-26 | FE1-762 |

### 스튜디오 / 스튜디오 e2e
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 스튜디오 Sentry 소스맵 빌드 추가 | 2026-05-27 | FE2-422 |
| 펀딩 스튜디오·스토어 스튜디오 e2e 테스트 코드 추가 | 2026-05-22~27 | FE2-408/409 |
| 클라우드 이전 — 스튜디오 동적 URL 생성, PostMessage origin 검증, Sentry URL 정규식 | 2026-04-21 | FE2-193/194/195 |

### 기능 추가 / 변경
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 기획전 캐시 저장 웹 환경 활성화 | 2026-05-22 | FE1-737 |
| 플랫폼별 타임아웃 분기 (펀딩 상세) | 2026-05-21 | FE1-712 |
| 브레이즈 이벤트 필드 Number 강제 변환 가드 | 2026-05-21 | FE1-728 |
| 리워드 다중 펼침 지원 | 2026-04-20 | FE1-444 |
| 협력기관 배너 디자인 모드 지원 | 2026-04-21 | FE1-428 |
| Readable한 스토리 구조화 (메이커 사이드) | 2026-04-20~21 | FE2-272 |
