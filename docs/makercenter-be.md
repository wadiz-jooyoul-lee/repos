# makercenter-be 분석 문서

> 📅 **2026-04-26 master pull 보강** (3 커밋, CLIENT-58)
>
> ### 어드민 기획전 대리 벌크 신청 신규
> - **`POST /api/exhibition/{...}/bulk-apply`** (또는 유사) — 어드민이 여러 메이커 프로젝트를 한꺼번에 기획전에 신청
> - 새 DTO:
>   ```java
>   // ReqBulkApplicationApply
>   @NotNull Integer exhibition_no;
>   @NotEmpty @Size(max = 1000) List<Long> project_nos;
>   ```
> - 새 응답: `ResBulkApplicationResult`
> - 새 서비스: `ExhibitionApplicationAdminService`
> - 새 매퍼 항목: `mappers/Exhibition.xml`
> - DB 마이그레이션: `migration/V004__exhibition_application_apply_manager_idx.sql` (apply_manager 인덱스)
> - **CSV export 갱신**: utm 소스/미디엄/캠페인/콘텐츠/키워드 모두 노출
> - 변경된 컨트롤러: `ExhibitionAdminController.java`
>
> ### 기타
> - `MvcConfig`, `XssDeserializeUtil`, `ErrorCode`, `ReqBoardData{Modify,Regist}` 소량 변경

---

## 개요

`makercenter-be`는 **와디즈 메이커센터**의 백엔드 API 서버입니다. 메이커센터는 와디즈에서 프로젝트를 오픈한 메이커에게 공지사항·이용가이드·이벤트·기획전 모집 등 커뮤니케이션 채널과 제반 정보를 제공하고, 동시에 사내 관리자(운영자)가 컨텐츠를 관리할 수 있는 CMS 기능을 제공합니다.

핵심 기능군 (`CLAUDE.md:1-91`):

- 메이커 대상 컨텐츠 소비: 메인 배너/팝업/게시판(일반/이벤트/카드/캘린더) 및 통합 검색
- 어드민용 CMS: 게시판·게시물·배너·팝업·뉴스레터·메뉴·카테고리·추천검색어·관리자 계정/그룹/권한 관리
- 기획전(Exhibition): 어드민이 기획전을 등록/수정/삭제/문항 구성 → 메이커가 신청/철회 → 자동 이메일 발송, 엑셀 Export
- 메이커 OAuth 로그인(account.wadiz.kr) + 어드민 JWT 로그인의 이중 인증
- 파일 업로드(AWS S3), 이메일 발송(AWS SES 14종 템플릿), 공휴일 데이터 연동(공공데이터포털)
- ShedLock 기반 분산 스케줄러

호출 클라이언트: `makercenter-fe`(사용자 페이지), `makercenter-fe-admin`(어드민 페이지). 인프라: AWS VPC, EC2+ELB(`api.makercenter.wadiz.kr`), RDS MySQL(Master/Slave). (`CLAUDE.md:60-91`)

## 기술 스택

| 구분 | 기술 |
| --- | --- |
| 언어/빌드 | Java 8, Gradle, Spring Boot 2.7.2 |
| 웹 서버 | Undertow (Tomcat 제외) |
| ORM | MyBatis 3.5.10 + mybatis-spring 2.0.7 (JPA 미사용), PageHelper 1.4.3 |
| DB 드라이버 | mysql-connector-java (HikariCP) |
| 인증 | JJWT 0.9.1 (access/refresh), Spring Session 쿠키 `MAKERCENTER_SESSION` |
| AWS SDK | S3 1.12.281, SES 1.12.312 |
| 엑셀 | Apache POI 5.2.2 |
| 한글 분석 | Apache Lucene analyzers-nori 8.11.2 |
| HTML 파싱 | Jsoup 1.15.3 |
| XML ↔ JSON | jackson-dataformat-xml 2.13.4 (공휴일 API) |
| 분산 잠금 | ShedLock 4.42.0 (jdbc-template provider) |
| 테스트 | JUnit 5, Mockito, RestAssured |
| 기타 | Lombok, commons-lang3, commons-io, gson 2.9.0 |
| 런타임 포트 | 8080 (`application.yml:2`) |

`build.gradle:1-74` 참조.

## 아키텍처

- 레이어: `Controller → Service → Mapper(MyBatis XML) → MySQL` (`CLAUDE.md:8`)
- 패키지 루트: `kr.wadiz.api.{controller, service, mapper, data.entity, data.request, data.response, config, interceptor, event, scheduler, utils, constant, exception}`
- 데이터소스: `ReplicationRoutingDataSource` (`config/ReplicationRoutingDataSource.java:6-13`)
  - `@Transactional(readOnly=true)` 시 slave, 그 외 master로 라우팅
  - HikariCP 두 풀(master/slave), `minimum-idle=5, maximum-pool-size=5`
- MyBatis: `classpath:/mappers/*.xml`, 타입 별칭 `kr.wadiz.api.data`, MariaDB dialect의 pagehelper
- 인증 이중 구조 (`MvcConfig.java:37-88`)
  - **어드민 JWT** (`RequestInterceptor`): `Authorization: Bearer <JWT>`를 파싱하여 `manager_idx`, `manager_level`, `expired_date` 요청 속성 설정. `token_type=access`는 `/api/auth/access_token|refresh_token` 호출 금지, `token_type=refresh`는 두 경로에서만 허용.
  - **메이커 세션** (`MakerRequestInterceptor`): 세션 쿠키 `MAKERCENTER_SESSION`에서 `USER_ID` 추출. 해당 인터셉터는 `/api/exhibition/user/projects|apply|withdraw*` 경로에 한정 적용
  - CORS는 `CorsProperties` 기반(`/**`, `allowCredentials=true`)
- OAuth2 플로우 (`controller/OAuthController.java`, `service/OAuthService.java`)
  - `/api/oauth/authorize` → state 생성 후 세션 저장 + authorize URL 반환
  - `/api/oauth/callback` → state 비교 및 세션 무효화(fixation 방지) → 인가코드 토큰 교환 → `/userinfo` 조회 → 세션에 `wadiz_user_id, email, nickname` 저장
- 이벤트 아키텍처 (`event/ApplicationAppliedEvent.java`, `ApplicationAppliedEventListener.java`)
  - 기획전 신청 성공 시 `ApplicationEventPublisher`로 이벤트 발행, `@Async @EventListener`가 SES 템플릿 메일 발송. 메일 실패는 업무 흐름과 분리됨.
- 스케줄러(`scheduler/SchedulerService.java`): 분산 환경에서 `@SchedulerLock` (lockAtMostFor/leastFor=PT5M)으로 중복 실행 방지
- 예외: `ApiException`/`ErrorCode`/`ExceptionController`로 에러 코드 표준화

## API 엔드포인트 목록

> 인증 컬럼: `JWT`=어드민 JWT 필수, `Session`=메이커 세션 필수, `None`=공개, `Admin(SU)`=슈퍼관리자(`manager_level=SU`) 추가 체크.

| Method | Path | Controller.method | 인증 | 용도 |
| --- | --- | --- | --- | --- |
| POST | /api/auth/login | AuthController.login | None | 어드민 이메일/비번 로그인 |
| POST | /api/auth/access_token | AuthController.accessToken | JWT(refresh) | access token 발급 |
| POST | /api/auth/refresh_token | AuthController.refreshToken | JWT(refresh) | refresh token 발급 |
| GET | /api/auth/menu | AuthController.menu | None | 메뉴 권한 계층 |
| GET | /api/auth/expired_timer | AuthController.expiredTimer | JWT | 토큰 잔여 시간 |
| GET | /api/oauth/authorize | OAuthController.authorize | None | OAuth authorize URL + state 발급 |
| POST | /api/oauth/callback | OAuthController.callback | None | 인가코드 → 토큰교환 → 세션생성 |
| GET | /api/auth/me | OAuthController.me | None(Session) | 메이커 세션 상태 조회 |
| POST | /api/auth/logout | OAuthController.logout | None(Session) | 세션 무효화 + logout URL |
| GET | /api/banner/lists | BannerController.lists | JWT | 배너 목록(top/rolling/kv) |
| GET | /api/banner/info | BannerController.info | JWT | 배너 상세 |
| POST | /api/banner/regist | BannerController.regist | JWT | 배너 등록 |
| PUT | /api/banner/modify | BannerController.modify | JWT | 배너 수정 |
| PATCH | /api/banner/modify_pri | BannerController.modifyPriority | JWT | 배너 우선순위 수정 |
| PATCH | /api/banner/modify_detail | BannerController.modifyDetail | JWT | 배너 상세 일괄 수정 |
| PATCH | /api/banner/view_count | BannerController.viewCount | JWT | 조회수 카운트 |
| DELETE | /api/banner/delete | BannerController.delete | JWT | 배너 삭제 |
| PATCH | /api/banner/sort | BannerController.sort | JWT | 배너 정렬 |
| GET | /api/banner/user/lists | BannerController.userLists | None | 사용자용 배너 조회 |
| GET | /api/board/total_lists | BoardController.totalLists | Admin(SU) | 전체 게시판 목록 |
| GET | /api/board/lists | BoardController.lists | Admin(SU) | 게시판 목록 |
| GET | /api/board/detail | BoardController.detail | Admin(SU) | 게시판 상세 |
| POST | /api/board/regist | BoardController.regist | Admin(SU) | 게시판 등록 |
| PUT | /api/board/modify | BoardController.modify | Admin(SU) | 게시판 수정 |
| DELETE | /api/board/delete | BoardController.delete | Admin(SU) | 게시판 삭제 |
| GET | /api/board/update/history | BoardController.updateHistory | Admin(SU) | 게시판 수정 이력 |
| GET | /api/board/data/lists | BoardController.dataLists | JWT | 게시물 목록 |
| GET | /api/board/data/detail | BoardController.dataDetail | JWT | 게시물 상세 |
| GET | /api/board/data/move/lists | BoardController.dataMoveLists | JWT | 이동 가능 게시판 |
| PATCH | /api/board/data/move | BoardController.dataMove | JWT | 게시물 이동 |
| POST | /api/board/data/regist | BoardController.dataRegist | JWT | 게시물 등록 |
| PUT | /api/board/data/modify | BoardController.dataModify | JWT | 게시물 수정 |
| POST | /api/board/data/temp_regist | BoardController.dataTempRegist | JWT | 임시 저장 등록 |
| PUT | /api/board/data/temp_modify | BoardController.dataTempModify | JWT | 임시 저장 수정 |
| DELETE | /api/board/data/temp_delete | BoardController.dataTempDelete | JWT | 임시 게시물 삭제 |
| DELETE | /api/board/data/delete | BoardController.dataDelete | JWT | 게시물 삭제 |
| GET | /api/board/data/temp_lists | BoardController.dataTempLists | JWT | 임시 게시물 목록 |
| GET | /api/board/lists_banner_yn | BoardController.selectBannerYnBoard | JWT | 롤링 배너용 게시판 |
| GET | /api/board/user/lists | BoardController.selectUserBoardLists | None | 사용자 게시물 목록 |
| GET | /api/board/user/detail | BoardController.selectUserBoardDetail | None/Session | 사용자 게시물 상세 (로그인 필수 게시물은 세션 체크) |
| GET | /api/category/group/lists | CategoryController.groupLists | JWT | 말머리 그룹 목록 |
| GET | /api/category/lists | CategoryController.lists | JWT | 말머리 목록 |
| GET | /api/category/detail | CategoryController.detail | JWT | 말머리 상세 |
| POST | /api/category/group/regist | CategoryController.groupRegist | JWT | 말머리 그룹 등록 |
| PATCH | /api/category/group/modify | CategoryController.groupModify | JWT | 말머리 그룹 수정 |
| POST | /api/category/regist | CategoryController.regist | JWT | 말머리 등록 |
| DELETE | /api/category/delete | CategoryController.delete | JWT | 말머리 삭제 |
| PUT | /api/category/sort | CategoryController.sort | JWT | 말머리 정렬 |
| GET | /api/data/holiday | DataController.holiday | None | 공휴일 목록(DB 캐시) |
| GET | /api/data/set_holiday | DataController.setHoliday | None | 공휴일 수동 동기화 |
| GET | /api/exhibition/lists | ExhibitionAdminController.lists | JWT | 기획전 목록 |
| GET | /api/exhibition/detail | ExhibitionAdminController.detail | JWT | 기획전 상세 |
| POST | /api/exhibition/regist | ExhibitionAdminController.regist | JWT | 기획전 등록 |
| PUT | /api/exhibition/modify | ExhibitionAdminController.modify | JWT | 기획전 수정 |
| DELETE | /api/exhibition/{exhibId} | ExhibitionAdminController.delete | JWT | 기획전 삭제 |
| GET | /api/exhibition/{exhibId}/questions | ExhibitionAdminController.exhibitionQuestions | JWT | 기획전 가변 문항 조회 |
| GET | /api/exhibition/questions | ExhibitionAdminController.allQuestions | JWT | 전체 문항 카탈로그 |
| GET | /api/exhibition/application/lists | ExhibitionAdminController.applicationLists | JWT | 신청자 목록 |
| GET | /api/exhibition/application/excel/lists | ExhibitionAdminController.applicationExcel | JWT | 신청자 엑셀 다운로드(CSV) |
| PATCH | /api/exhibition/application/{id}/withdraw | ExhibitionAdminController.withdrawApplication | JWT | 어드민 강제 철회 |
| GET | /api/exhibition/email/template | ExhibitionAdminController.emailTemplate | JWT | 이메일 템플릿 HTML 미리보기 |
| GET | /api/exhibition/user/projects | ExhibitionUserController.projects | Session | 메이커 프로젝트 목록(펀딩 API 프록시+신청여부) |
| GET | /api/exhibition/user/apply/form | ExhibitionUserController.form | None | 기획전 신청 폼 조회 |
| POST | /api/exhibition/user/apply | ExhibitionUserController.apply | Session | 기획전 신청 |
| GET | /api/exhibition/user/withdraw/form | ExhibitionUserController.withdrawForm | Session | 기획전 철회 폼 |
| POST | /api/exhibition/user/withdraw | ExhibitionUserController.withdraw | Session | 기획전 철회 |
| GET | /api/group/total_lists | GroupController.totalLists | Admin(SU) | 전체 그룹 목록 |
| GET | /api/group/lists | GroupController.lists | Admin(SU) | 그룹 목록 |
| GET | /api/group/detail | GroupController.detail | Admin(SU) | 그룹 상세 |
| POST | /api/group/regist | GroupController.regist | Admin(SU) | 그룹 추가 |
| GET | /api/group/manager_lists | GroupController.managerLists | JWT | 그룹 구성원 조회 |
| POST | /api/group/manager_regist | GroupController.managerRegist | Admin(SU) | 그룹 멤버 추가 |
| DELETE | /api/group/manager_delete | GroupController.managerDelete | Admin(SU) | 그룹 멤버 삭제 |
| PUT | /api/group/manager_modify | GroupController.managerModify | Admin(SU) | 그룹 멤버 수정 |
| DELETE | /api/group/delete | GroupController.delete | Admin(SU) | 그룹 삭제 |
| PUT | /api/group/modify | GroupController.modify | Admin(SU) | 그룹 수정 |
| GET | /api/main/data | MainController.data | None | 메인 페이지 원샷 DTO(배너+게시판 8종+추천검색어) |
| GET | /api/manager/chk_dup_id | ManagerController.chkDupId | None | 아이디 중복 확인 |
| GET | /api/manager/find_account | ManagerController.findAccount | None | 계정 찾기 → 임시 비번 메일 |
| PATCH | /api/manager/reset_password | ManagerController.resetPassword | JWT | 비밀번호 재설정 |
| POST | /api/manager/signup | ManagerController.signup | None | 관리자 가입 요청(대기 상태) |
| POST | /api/manager/regist | ManagerController.regist | Admin(SU) | 관리자 계정 등록 |
| GET | /api/manager/lists | ManagerController.lists | Admin(SU) | 관리자 목록 |
| PATCH | /api/manager/status | ManagerController.status | Admin(SU) | 관리자 상태 변경 |
| GET | /api/manager/info | ManagerController.info | JWT | 관리자 정보 조회(본인/SU) |
| PATCH | /api/manager/modify | ManagerController.modify | JWT | 관리자 정보 수정 |
| GET | /api/manager/request/lists | ManagerController.requestLists | JWT | 개인 요청사항 목록 |
| POST | /api/manager/request/regist | ManagerController.requestRegist | JWT | 요청사항 등록 |
| PATCH | /api/manager/request/modify | ManagerController.requestModify | JWT | 요청사항 수정 |
| DELETE | /api/manager/request/delete | ManagerController.requestDelete | JWT | 요청사항 삭제 |
| POST | /api/manager/request/regist_disabled | ManagerController.requestRegistDisabled | JWT | 비활성 계정 해제 요청 |
| GET | /api/menu/admin | MenuController.adminMenu | JWT | 어드민 좌측 메뉴 |
| GET | /api/menu/user | MenuController.userMenu | None | 사용자 메뉴 |
| GET | /api/menu/lists | MenuController.lists | Admin(SU) | 메뉴 관리 목록 |
| GET | /api/menu/detail | MenuController.detail | Admin(SU) | 메뉴 상세 |
| GET | /api/menu/parent | MenuController.parent | Admin(SU) | 상위 메뉴(카테고리) 조회 |
| POST | /api/menu/regist | MenuController.regist | Admin(SU) | 메뉴 등록 |
| PUT | /api/menu/modify | MenuController.modify | Admin(SU) | 메뉴 수정 |
| DELETE | /api/menu/delete | MenuController.delete | Admin(SU) | 메뉴 삭제 |
| POST | /api/newsletter/regist | NewsletterController.regist | None | 뉴스레터 신청 |
| GET | /api/newsletter/lists | NewsletterController.lists | JWT | 뉴스레터 신청 목록 |
| PATCH | /api/newsletter/modify | NewsletterController.modify | JWT | 뉴스레터 처리상태 변경 |
| DELETE | /api/newsletter/delete | NewsletterController.delete | JWT | 뉴스레터 삭제(상태변경) |
| ANY | /api/newsletter/excel | NewsletterController.excelDownload | JWT | 뉴스레터 엑셀 다운로드(xlsx) |
| GET | /api/newsletter/excel/lists | NewsletterController.excelLists | JWT | 엑셀용 목록 조회 |
| GET | /api/popular_word/user/lists | PopularWordController.userLists | None | 사용자 추천검색어 |
| GET | /api/popular_word/lists | PopularWordController.lists | JWT | 추천검색어 목록 |
| POST | /api/popular_word/regist | PopularWordController.regist | JWT | 추천검색어 등록 |
| PUT | /api/popular_word/modify | PopularWordController.modify | JWT | 추천검색어 수정 |
| DELETE | /api/popular_word/delete | PopularWordController.delete | JWT | 추천검색어 삭제 |
| PATCH | /api/popular_word/sort | PopularWordController.sort | JWT | 추천검색어 자동정렬 |
| GET | /api/popup/user/info | PopupController.userInfo | None | 사용자 팝업 |
| GET | /api/popup/lists | PopupController.lists | JWT | 팝업 목록 |
| GET | /api/popup/info | PopupController.info | JWT | 팝업 상세 |
| POST | /api/popup/regist | PopupController.regist | JWT | 팝업 등록 |
| PUT | /api/popup/modify | PopupController.modify | JWT | 팝업 수정 |
| PATCH | /api/popup/modify_pri | PopupController.modifyPriority | JWT | 팝업 우선순위 |
| DELETE | /api/popup/delete | PopupController.delete | JWT | 팝업 삭제 |
| PATCH | /api/popup/sort | PopupController.sort | JWT | 팝업 자동정렬 |
| GET | /api/search | SearchController.selectSearchLists | None | 통합 검색(Lucene Nori 형태소+NGram) |
| POST | /api/upload/file | UploadController.file | JWT | S3 파일 업로드(6개 타입 분기) |

## 주요 API 상세 분석

### 1. POST /api/auth/login

- 위치: `controller/AuthController.java:32-35`, `service/AuthService.java:36-116`
- 입력: `ReqLogin{ id, password }` (ReqLogin에서 유효성)
- 로직
  1. `ManagerMapper.chkEmail` — 이메일 존재 여부 확인
  2. `AuthMapper.login(reqLogin)` 정식 비번 매칭 조회
  3. `AuthMapper.loginTempPassword(reqLogin)` 임시 비번 매칭 조회 → 일치 시 `temp_password_login_yn=Y` 플래그
  4. 둘 다 실패 → `MANAGER_LOGIN_FALIED1`
  5. `managerService.info(managerIdx)`로 메뉴 권한 포함 사용자 정보 로드, 비활성 상태면 `menu_auth=null`
  6. `ManagerMapper.updateLastLoginDate` 호출
  7. `JwtUtil.makeJwtToken(managerIdx, level, "access"/"refresh")` 두 토큰 발급 후 반환
- 외부 연동: 없음

### 2. POST /api/oauth/callback (메이커 로그인)

- 위치: `controller/OAuthController.java:45-69`, `service/OAuthService.java`
- 입력: `ReqOAuthCallback{ code, state }`
- 로직
  1. 세션에서 `SessionKeys.OAUTH_STATE` 가져와 요청 state와 일치 확인 → 불일치 시 `OAUTH_CALLBACK_FAILED`
  2. 기존 세션 무효화 (세션 fixation 방지) 및 state 1회성 제거
  3. `OAuthService.exchangeCodeForToken(code)` — `token-uri`로 Basic(client_id/secret) + `authorization_code` form POST
  4. `getUserInfo(accessToken)` — `user-info-uri` GET. `sub, email, nickname` 추출
  5. 새 세션 생성 후 `USER_ID=sub`, `EMAIL`, `NICKNAME` 저장
- 외부 연동: `wadiz.oauth.*`(account.wadiz.kr)

### 3. POST /api/exhibition/user/apply (기획전 신청)

- 위치: `controller/ExhibitionUserController.java:55-60`, `service/ExhibitionApplyService.java:125-235`
- 입력: `ReqExhibitionApply{ exhibition_no, project_no, responses[{exhibition_question_id, content}], utm_* }`
- 트랜잭션 단계
  1. `ExhibitionMapper.selectExhibitionByIdx` → 기획전 존재/상태 확인 (`recruitment_status` 필수 `recruiting`)
  2. `selectApplicationByProjectNumber(project_no)` → 이미 신청된 프로젝트 차단 (`PROJECT_ALREADY_APPLIED`)
  3. `selectExhibitionQuestions(exhibition_no)` → 해당 기획전 문항 목록 로드
  4. 클라이언트 응답 검증: 유효 `question_id`, 필수문항(`is_required=1`) 누락 체크, `parent_field_key` 조건부 필수 처리(부모 응답이 `Y`인 경우만 검증)
  5. `ExhibitionFieldKey.MAKER_NAME / MAKER_EMAIL / EXPERT_YN` 필드의 응답값 추출
  6. `insertApplication(app)` → `exhibition_application_no` 생성(selectKey)
  7. `insertApplicationAnswers(applyId, responses)` 배치 insert
  8. `ApplicationAppliedEvent` 발행 (메일 발송 비동기)
- 이벤트 리스너 (`event/ApplicationAppliedEventListener.java:41-119`)
  - `exhibition.email_auto_send=1`일 때만 발송
  - `ExhibitionType`(BASIC/BOOSTER_COUPON/MIXED) + `expert_yn` 조합으로 type09~14 중 하나 선택
  - `email_template_data`(JSON)을 자동 치환 맵과 병합, 미정의 키는 빈 문자열로 보장 (메일 내 `{{변수}}` 노출 방지)
  - BOOSTER_COUPON 타입에 한해 `withdraw_url = {user-site-url}/exhibition/{exhibId}/withdraw` 주입
  - SES `sendTemplatedEmail`로 발송
- 외부 연동: AWS SES

### 4. GET /api/exhibition/user/projects

- 위치: `controller/ExhibitionUserController.java:34-42`, `service/FundingApiService.java:32-49`, `service/ExhibitionApplyService.java:74-94`
- 로직
  1. 세션의 `USER_ID`(와디즈 사용자 ID)로 `FundingApiService.getProjectsByUserId`
     - 호출: `GET ${wadiz.funding-api-url}/api/internal/projects/by-userId?userId={userId}` (Bearer `funding-api-token`)
  2. 응답 `data.content[*].projectNo`를 추출하여 `ExhibitionMapper.selectAppliedProjectNumbers`로 신청 여부 조회
  3. 각 항목에 `appliedToExhibition: boolean` 필드 주입 후 반환
- 외부 연동: **펀딩 API(`com.wadiz.api.funding` Public Gateway 경유)**

### 5. GET /api/exhibition/application/excel/lists

- 위치: `controller/ExhibitionAdminController.java:115-121` → `ExhibitionApplicationAdminService.getApplicationCsv` (CSV 응답, 본 파일에서는 세부 구현 생략)
- 어드민이 선택한 `exhibition_no`, `is_withdrawn`에 따라 신청자 리스트를 CSV로 스트리밍

### 6. GET /api/main/data

- 위치: `controller/MainController.java:39-164`
- 한 번의 GET으로 메이커센터 메인에 필요한 데이터를 일괄 조립:
  - `bannerService.userLists`(top, kv 배너 2회)
  - `boardService.selectUserBoardList`(board_idx 고정 ID: 7=FAQ, 8=이용가이드, 10=와디 사전, 1=공지, 5=캘린더(이번주), 3=이벤트, 12=메이커 성공사례, 11=와디즈 아카데미)
  - `popularWordService.userLists(limit=10)`
- 캘린더는 현재 주 월~일 날짜 범위(`Calendar.DAY_OF_WEEK=MONDAY` 기준)를 자동 계산

### 7. GET /api/search (통합 검색)

- 위치: `controller/SearchController.java:27-33`, `service/SearchService.java:28-131`, `utils/SearchTokensUtil.java`
- 로직
  1. 활성 검색 탭 id 목록 조회(`selectSearchTab`) + 전체(null) 추가
  2. `SearchTokensUtil.makeSearchTokens(searchText)`
     - 원문 `>원문,` + `원문*,` 토큰
     - NGram(2~2) 토큰
     - Lucene Korean Nori 분석기로 형태소 분해 (`KoreanTokenizer.DecompoundMode.MIXED`)
     - 공백 기반 split
  3. 각 탭에 대해 `SearchMapper.selectSearchListsV2(SearchData)` 실행 → FULLTEXT MATCH IN BOOLEAN MODE로 검색
  4. `hashtag_text` → `hashtag` 배열 변환, distinct 처리 후 반환
- 외부 연동: 없음, 순수 MySQL FULLTEXT + Nori

### 8. POST /api/upload/file

- 위치: `controller/UploadController.java:40-139`
- 지원 타입: `menu_page`, `board_image`, `board_attachment`, `banner_image`, `popup_image`, `exhibition_banner`
- 검증
  - 파일 크기 ≤ 25MB
  - 확장자: 이미지 계열(jpg, png, gif, webp, webm 등), `menu_page`는 html만, `board_attachment`는 office/pdf/hwp/아카이브 허용
- 업로드 분기
  - `board_attachment` → 원본 파일명 유지, `board/attachment/{yyyyMMdd}/{uuid}/{filename}`로 저장. 이후 `uploadService.uploadAttachment`로 DB(tb_board_attachment)에 메타데이터 저장
  - `menu_page` → `S3Util.uploadFileForMenu` (site-bucket 사용)
  - 그 외 → static-bucket에 UUID 파일명으로 저장
- 외부 연동: AWS S3 (`static-bucket` / `site-bucket`)

### 9. POST /api/newsletter/regist + Excel Export

- 위치: `controller/NewsletterController.java:42-173`
- 사용자는 인증 없이 뉴스레터 신청(`regist`) → `tb_newslatter`에 저장
- 어드민 `/api/newsletter/excel` — `pageSize=20000`으로 한 번에 조회, Apache POI `XSSFWorkbook`로 xlsx를 스트리밍 응답
- 엑셀 헤더: `이름, 이메일주소, 휴대전화번호, 소속&기업명, 등록일자, 최근수정일, 최근수정자, 처리상태`

### 10. GET /api/data/holiday / GET /api/data/set_holiday

- 위치: `controller/DataController.java`, `service/DataService.java`
- `/holiday` — DB(`tb_holiday`)에서 날짜 범위 조회
- `/set_holiday` — 공공데이터포털 `http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo` XML 응답을 `XmlMapper`로 파싱. 기준일부터 +25개월까지 월 단위 루프. 기존 공휴일 delete 후 일괄 재삽입
- 스케줄러도 주 1회 이 로직을 호출 (`SchedulerService.managerHolidayScheduler`)

### 스케줄러 목록

| 이름 | 크론 | 용도 | 위치 |
| --- | --- | --- | --- |
| managerEndDateScheduler | `0 0 10 * * *` (매일 10시) | 계정 만료 45/30/15/7일 전 이메일 알림(type03) | `scheduler/SchedulerService.java:34-73` |
| managerDisabledScheduler | `0 0 0 * * *` (매일 0시) | 마지막 로그인 후 90일 지난 관리자 비활성화 | `SchedulerService.java:76-89` |
| managerHolidayScheduler | `0 0 1 * * 1` (매주 월 01시) | 공공데이터 API로 2년치 공휴일 재적재 | `SchedulerService.java:92-104` |

모두 ShedLock `@SchedulerLock(lockAtMostFor=PT5M, lockAtLeastFor=PT5M)` 적용.

## DB 스키마 요약

DB: `wadiz_makercenter` (MySQL/MariaDB, Master/Slave). MyBatis 매퍼 XML에서 사용되는 테이블을 기준으로 정리합니다.

| 테이블 | 용도 |
| --- | --- |
| tb_manager | 관리자(운영자) 계정 정보, 만료일/상태/레벨(SU/일반) |
| tb_manager_auth | 관리자-메뉴 개별 권한 |
| tb_manager_request | 관리자 개인 요청사항 + 비활성 해제 요청 |
| tb_group | 관리자 그룹(부서) |
| tb_group_auth | 그룹-메뉴 권한 |
| tb_group_member | 그룹 소속 관리자 맵핑 |
| tb_menu | 사이트 메뉴(카테고리/게시판/페이지/링크) 트리 구조(depth 1~3) |
| tb_category_group | 게시판 말머리 그룹 |
| tb_category | 말머리 |
| tb_board | 게시판 마스터(일반/이벤트/카드/캘린더) |
| tb_board_basic | 일반형 게시물 본문 |
| tb_board_card | 카드형 게시물 |
| tb_board_event | 이벤트형 게시물 |
| tb_board_calendar | 캘린더형 게시물 |
| tb_board_hashtag | 게시물 해시태그 |
| tb_board_attachment | 게시물 첨부 파일 메타 |
| tb_board_update_history | 게시판 수정 이력 |
| tb_banner | 배너(top/rolling/kv) |
| tb_popup | 팝업 |
| tb_popular_word | 추천 검색어 |
| tb_newslatter | (오타 유지) 뉴스레터 신청 목록 |
| tb_holiday | 공휴일 캐시(공공데이터포털 원본) |
| exhibition | 기획전 마스터(제목, 기간, 유형 BASIC/BOOSTER_COUPON/MIXED, PD 컨설팅, 이메일 자동발송, 템플릿 데이터 JSON) — `migration/V001__exhibition_schema.sql:4` |
| exhibition_question | 문항 카탈로그(시스템 field_key 포함) — `V001__exhibition_schema.sql:29` |
| exhibition_question_configuration | 기획전-문항 매핑 + 필수여부 + 표기/부모 필드 — `V001__exhibition_schema.sql:48` |
| exhibition_application | 기획전 신청 이력(메이커 ID, 프로젝트 ID, UTM, 철회 정보) — `V001__exhibition_schema.sql:65` |
| exhibition_application_answer | 신청 시 제출한 문항별 답변 — `V001__exhibition_schema.sql:89` |

## 외부 의존성

- **Funding API** (`wadiz.funding-api-url`, `${FUNDING_API_TOKEN}` Bearer)
  - `GET /api/internal/projects/by-userId?userId=` (사용자 프로젝트 목록)
  - `POST /api/internal/projects` (`projectNos` 배치 조회)
  - 경로: Public Gateway (`dev-gateway.wadiz.kr` → 운영 `gateway.wadiz.kr`)
- **Startup API** (`wadiz.startup-api-url`)
  - `POST /api/v1/startup/makers/funding/bulk` (`projectNos` 기준 메이커 정보 일괄 조회)
- **OAuth / Account 서버** (`wadiz.oauth.*`)
  - `authorize-uri`, `token-uri`, `user-info-uri`, `end-session-uri`
  - dev: `dev-account.wadiz.kr`, live: `account.wadiz.kr`
- **AWS S3** (static-bucket / site-bucket 분리)
  - `dev-static.makercenter.wadiz.kr`, `dev.makercenter.wadiz.kr` (local/dev), `static.makercenter.wadiz.kr`, `makercenter.wadiz.kr`(prod)
- **AWS SES** — 14종 템플릿(type01~type14), 발신자 `help.maker@wadiz.kr` / 관리자 알림 `makercenter@wadiz.kr`, 리전 `ap-northeast-2`
- **공공데이터 API** — `apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo` (XML 응답, `${HOLIDAY_API_KEY}` 필요)
- **ShedLock** — `shedlock` 테이블을 공유해 다중 인스턴스 스케줄러 락
- 캐시/세션 — 서버 로컬 세션(`MAKERCENTER_SESSION`) 사용. 공유 Redis는 사용하지 않음.
- 이벤트 — Spring `ApplicationEventPublisher`(in-process)만 사용. 외부 메시징 큐 없음.

## 특이사항

- **읽기/쓰기 DB 분리**: `ReplicationRoutingDataSource`가 `@Transactional(readOnly=true)` 트랜잭션을 slave로 라우팅합니다. 읽기 전용 조회는 서비스 메서드에서 `readOnly=true`를 명시해 slave로 보내야 하며, 기본 트랜잭션은 master로 갑니다.
- **이중 인증**: 어드민은 JWT(access/refresh 구분 + URI별 허용 리스트), 메이커는 OAuth2 세션. 동일 컨트롤러 그룹(`/api/exhibition/*`)에서 관리자 경로와 `/user/*` 메이커 경로가 공존합니다 (`MvcConfig.java:37-88`).
- **세션 Fixation 방지**: OAuth 콜백에서 토큰 교환 전에 반드시 기존 세션을 `invalidate()`하고 새 세션을 생성합니다 (`OAuthController.java:58-67`).
- **템플릿 변수 치환**: 기획전 신청 폼에서 문항 description의 `{{key}}`를 `exhibition.email_template_data`(JSON)으로 선치환합니다 (`ExhibitionApplyService.java:44-68`). 이메일 리스너에서도 동일 JSON을 기본값으로 사용하고, 누락 키는 빈 문자열로 보장하여 실수로 리터럴이 메일에 노출되지 않도록 방어합니다.
- **한글 형태소 검색**: `SearchTokensUtil`이 Lucene Nori analyzer + NGramTokenizer + whitespace split을 조합해 부울 MATCH 검색용 토큰 문자열을 생성합니다. MySQL FULLTEXT `MATCH ... AGAINST(... IN BOOLEAN MODE)`와 결합되어 한국어 부분 일치를 지원합니다.
- **메인 화면 고정 ID**: `MainController.data`는 `board_idx`를 상수(1, 3, 5, 7, 8, 10, 11, 12)로 박아두고 있으며, 새로운 메인 섹션이 필요하면 게시판을 만들고 해당 상수를 추가해야 합니다.
- **비밀번호 정책**: 대/소문자, 숫자, 특수문자(+ 또는 `~!@#$%^&*()_/,.?\-=`) 중 3종 이상, 9자 이상. 컨트롤러 레벨에서 정규식 3회 매칭으로 검사합니다 (예: `ManagerController.java:207-215`).
- **정책/상수**
  - 계정 상태: `I`=대기, `Y`=활성, `N`=비활성, `D`=반려. 로그인 실패/성공 모두 `MANAGER_LOGIN_FALIED*` 에러코드 사용(오타 유지)
  - 관리자 이메일은 `wadiz.kr` 도메인만 허용 (`ManagerController.java:42-43, 107, 175`)
- **S3 CLI vs SDK**: 과거 CLI 방식 업로드 코드가 주석으로 남아 있고 현재는 SDK 사용 (`UploadController.java:95-96`).
- **Lombok `@Data` 엔티티 + snake_case 필드**: 일반적인 Java 컨벤션과 달리 필드명이 모두 `snake_case`입니다(`manager_idx`, `board_idx` 등). MyBatis 결과 매핑과 일관성을 맞추기 위함.
- **환경별 차이**
  - local: DB localhost, funding API `http://dev-app01:9070`
  - dev: `dev-wadiz-rds`, funding `https://dev-gateway.wadiz.kr:10443/funding`
  - prod: `real-wadiz-rds` + slave `read-wadiz-rds-read`, `gateway.wadiz.kr` (`CLAUDE.md:83-91`)
- **env 파일 보안**: `/etc/makercenter/env` (chmod 600), systemd `EnvironmentFile`로 JVM에 주입 (`CLAUDE.md:72-76`)
- **WAF/방화벽**: 사용자/어드민 FE는 `wadiz_office` 공인 IP만 접근 가능한 개발망, 백엔드는 VPC 보안그룹 + VPN(GlobalProject) 기반 (`CLAUDE.md:78-81`)
