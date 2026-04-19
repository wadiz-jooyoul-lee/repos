# makercenter-fe-admin

## 개요
**메이커센터 어드민** SPA. `admin.makercenter.wadiz.kr` (live) / `dev-admin.makercenter.wadiz.kr` (dev) 에 배포. 와디즈 내부 운영자가 메이커가 등록한 프로젝트를 심사·관리하고 배너/팝업/기획전/뉴스레터를 운영합니다. Org: `wadiz-client`. 패키지명 `wadiz-makercenter-admin`.

## 기술 스택
- React + **CRA (react-scripts 5)** + react-app-rewired (Vite 미이관).
- Material-UI **v4 + v5 공존**, Material Table, Froala Editor.
- React Router v6.
- HTTP: Axios.
- 패키지: yarn 1.
- dev 포트 4010.
- Sentry, Playwright.

## 앱 구성
- 단일 SPA. 주요 폴더:
  - `src/api/` — 모듈 14개: `banner`, `board`, `category`, `exhibition`, `file`, `global`(auth), `group`, `manager`, `menu`, `newsletter`, `popular`, `popup`, `post`.

## 서버 연결 설정 (핵심)

### Axios 인스턴스 (`src/api/axiosInstance.js:5-14`)
- `baseURL = ${REACT_APP_BASE_URL}/api`
- `withCredentials` **없음** (쿠키 미사용).
- 토큰: 각 호출에서 `getAuthorizationHeader()` 로 `Authorization: Bearer <token>` 직접 주입.

### 환경별 Base URL
| 환경 | Base URL |
|---|---|
| dev | `https://dev-api.makercenter.wadiz.kr` |
| live | `https://api.makercenter.wadiz.kr` |
| `REACT_APP_USER_SITE_URL` | 사용자 사이트(`makercenter-fe`) 링크 (메이커 페이지 미리보기 등) |

### Upstream
- 직접 호출: **`makercenter-be`** (Spring Boot 2.7).

### 인증 흐름
- `auth/login` → access/refresh 토큰을 **localStorage** 에 저장.
- `auth/access_token` (재발급), `auth/refresh_token` 갱신.
- `manager/info` (현재 로그인 매니저 정보), `manager/find_account` (계정 조회).
- 토큰 자동첨부 인터셉터 **없음** — 호출 코드에서 헤더 명시적으로 붙여야 함 (makercenter-fe 와 큰 차이).

## 기능별 API 호출 매핑 (대표)

| 기능/화면 | Method + Path | 용도 |
|---|---|---|
| 로그인 | POST `/api/auth/login` | 운영자 로그인, 토큰 발급 |
| 토큰 재발급 | POST `/api/auth/access_token` | access token 갱신 |
| 매니저 목록 | GET `/api/manager` | 운영자 계정 목록 |
| 매니저 등록 | POST `/api/manager` | 운영자 계정 추가 |
| 매니저 정보 | GET `/api/manager/info` | 본인 정보 |
| 메뉴 관리 | GET/POST/PUT/DELETE `/api/menu` | 좌측 메뉴 트리 CRUD |
| 권한 그룹 | GET/POST `/api/group` | 운영자 권한 그룹 CRUD |
| 카테고리 | GET/POST/PUT/DELETE `/api/category` | 카테고리 트리 |
| 배너 KV | GET/POST `/api/banner/kv` | 메인 KV 배너 |
| 배너 Top | GET/POST `/api/banner/top` | 상단 배너 |
| 배너 Rolling | GET/POST `/api/banner/rolling` | 롤링 배너 |
| 팝업 | GET/POST/DELETE `/api/popup` | 팝업 CRUD |
| 게시글 | GET/POST/PUT/DELETE `/api/post` | 글 CRUD |
| 게시판(6종) | GET/POST `/api/board/{notice|faq|...}` | 게시판별 운영 |
| 기획전 신청자 목록 | GET `/api/exhibition/applicants` | 신청자 조회 |
| 기획전 신청자 Excel | GET `/api/exhibition/applicants/excel` | 엑셀 다운로드 |
| 기획전 등록 | POST `/api/exhibition` | 기획전 생성 |
| 인기 키워드 | GET/POST `/api/popular` | 인기 검색어 관리 |
| 뉴스레터 | GET/POST `/api/newsletter` | 뉴스레터 발송 관리 |
| 파일 업로드 | POST `/api/file/upload` | S3 업로드 (BE 경유) |

## 빌드·배포

- `yarn start` (포트 4010), `yarn build`.
- GitHub Actions → S3 (`dev-admin.makercenter.wadiz.kr` / `admin.makercenter.wadiz.kr`) + CloudFront invalidation.
- 환경 분기: `.env.development` / `.env.production`.

## 특이사항

- **CRA 잔존** (Vite 미이관) — makercenter-fe와 빌드 도구 분리.
- **인증이 fe와 다름**: 어드민은 localStorage Bearer 토큰, fe는 쿠키 세션.
- **인터셉터 자동첨부 없음** — 각 API 호출에서 `getAuthorizationHeader()` 명시적 호출. 신규 API 추가 시 누락 주의.
- 14개 API 모듈로 분리 — 운영 도메인(배너/팝업/뉴스레터/카테고리/기획전 등) 폭이 넓음.
- Froala Editor: 게시판/공지/뉴스레터 본문 작성.
- React Router v6 업그레이드는 됐지만 react-scripts 5 가 한계 — Webpack 5/CRA 자체 deprecated.
