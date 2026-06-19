# makercenter-fe

## 개요
**메이커(프로젝트 개설자)용 사용자 포털** SPA. `makercenter.wadiz.kr` (live) / `dev.makercenter.wadiz.kr` (dev) 에 배포되어 메이커가 자신의 프로젝트를 등록·운영하는 화면을 제공합니다. Org: `wadiz-client`. 패키지명 `wadiz-makercenter`.

## 기술 스택
- React + **Vite 6** (CRA → Vite 마이그레이션 완료, dev 포트 4020).
- Material-UI **v4 + v5 공존** (점진 이관).
- 상태: Recoil + React Query v3.
- HTTP: Axios `0.21.1`.
- 테스트: Playwright (E2E), Vitest.
- Sentry 연동.

## 앱 구성
- 단일 SPA. 주요 폴더:
  - `src/api/` — API 모듈 (`home.js`, `board.js`, `exhibition.js`, `main.js`, `data.js`)
  - `src/pages/`, `src/components/`, `src/hooks/`, `src/recoil/`, `src/utils/`

## 서버 연결 설정 (핵심)

### Axios 인스턴스 (`src/api/axiosInstance.js:3-13`)
- `baseURL = ${VITE_BASE_URL}/api`
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

**분석 갱신일: 2026-06-19** (최초: 2026-04-20)

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
