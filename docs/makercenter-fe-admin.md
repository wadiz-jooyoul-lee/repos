# makercenter-fe-admin

> 📅 **2026-07-10 main pull 보강** (19 커밋)
>
> ### CLIENT-169 — 기획전/신청자 API REST 표준 계약 적용
> - 기획전 API 레이어를 동사형 경로에서 RESTful 리소스 경로로 전면 이관: `exhibition/lists`→`GET exhibitions`, `exhibition/detail?exhibition_no=`→`GET exhibitions/{id}`, `exhibition/regist`→`POST exhibitions`, `exhibition/modify`(PUT body)→`PUT exhibitions/{id}`, 신청자 목록 `exhibition/application/lists`→`GET exhibitions/{id}/applications`, 신청 철회 `exhibition/application/{no}/withdraw`→`PATCH exhibitions/{id}/applications/{applicationId}/withdraw` (`src/api/exhibition.js`).
> - 성공 판정 확장: axios `validateStatus`를 `status === 200` → `2xx(200~299)`로 변경해 201/204 응답도 성공 처리 (`src/api/axiosInstance.js:12`). 비-기획전 모듈은 여전히 200 전제(무회귀).
> - 공통 헬퍼 신설: `isSuccess(status)`(2xx 판정)와 `errorMessageFor(status, beMessage)`(400 영문 reason-phrase 한국어 폴백, 5xx·네트워크 오류는 BE 내부정보 노출 방지 위해 일반 메시지로 마스킹) (`src/lib/utils.js:196-210`).
> - nested path 식별자 누락 시 `.../undefined/...` 요청을 막는 `requireId` 가드 추가. 신청자 관리·기획전 목록/폼 호출부 시그니처를 `(exhibitionNo, ...)` 로 갱신 (`src/components/applicationManage/ApplicationList.jsx`, `src/components/exhibitionManage/ExhibitionForm.jsx`).
>
> ### FE2-646 — 관리자 추가(등록) 기능 제거
> - 관리자 목록 화면의 "관리자 추가" 진입점을 전면 제거. `AddManager.jsx`(487줄) 컴포넌트 삭제, `managerApi.regist`(`POST manager/regist`) 및 `AdminUser`의 `cAddUser` 모드/버튼/렌더링 삭제 (`src/components/adminUser/AddManager.jsx` 삭제, `src/api/manager.js`, `src/pages/AdminUser.jsx`). 그룹 추가·사용자 편집 등 나머지 모드는 유지.
>
> ### FE2-542 — 사용자 편집에 권한등급(SU/MNG) 설정 추가
> - 사용자 편집 화면에 권한등급(총관리자 SU / 관리자 MNG) 라디오를 추가하고 수정 payload에 `level` 필드를 함께 전송. 기존 값 없으면 기본 `MNG`. 본인 계정 편집 시(`geUserIdx()` 일치)에는 라디오가 비활성화되어 스스로 등급을 변경할 수 없음 (`src/components/adminUser/UserEdit.jsx:47-48,135,231-`).
>
> ### CLIENT-164 — 본문 번역 한도 초과 시 한국어만 저장 안내
> - BE 응답코드 2202(TRANSLATE_OVERSIZE)를 인식해, 재시도가 무의미한 오버사이즈는 '다시 시도' 없이 '한국어만 저장' 단일 버튼 다이얼로그로 안내 (`src/components/modal/TranslateFailDialog.jsx`, `src/lib/translateSave.js`).
>
> ### CLIENT-121 — 번역저장 공통 에러 핸들러 추출·타임아웃 안내 보완
> - `translateSave`에 `handleTranslateSaveError` 헬퍼를 추가해 번역실패(2200/2201)·클라이언트 타임아웃 분기를 중앙화하고, 13개 저장 컴포넌트의 catch를 헬퍼로 치환 (`src/lib/translateSave.js`). Board/Menu/Category/Popular 8곳의 타임아웃 안내 누락(저장 여부 확인 안내)을 해소.
>
> ---

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
- **어드민 계정 발급(ISMS 대응)**: 신규 가입 화면(`src/pages/Join.jsx`)에서 신청자가 직접 권한 메뉴를 체크하고 업무를 입력하던 절차를 폐지(아이디/비밀번호/사용기간만 신청). 권한·업무는 운영자가 권한 수정 화면(`src/components/adminUser/UserEdit.jsx`)에서 부여하도록 일원화 — 업무 필드도 읽기전용에서 입력 가능(TextField)으로 변경.

---

## 최근 변경사항

**분석 갱신일: 2026-06-16** (최초: 2026-04-20)

| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| ISMS 대응 — 어드민 계정 발급 절차 변경 (가입 화면 권한·업무 셀프 선택 폐지, 권한 수정은 운영자 화면으로 일원화) | 2026-06-09 | FE2-421 |
| 게시글 작성 시 Froala 스타일 적용 안 함 토글 추가 | 2026-05-22 | CLIENT-116 |
| 기획전 이메일 쿠폰 권종 다건 입력 지원 | 2026-05-21 | CLIENT-96 |
| sales_info 그룹 추가 및 부모 비활성값 컨벤션 적용 | 2026-05-14 | CLIENT-95 |
| 어드민 기획전 벌크 신청 다이얼로그 추가 | 2026-04-17 | CLIENT-58 |
