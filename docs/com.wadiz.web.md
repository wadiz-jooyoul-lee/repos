# com.wadiz.web 레거시 분석

> 대상 경로: `/Users/casvallee/work/repos/com.wadiz.web`
> artifactId: `markmount:com.wadiz.web` / packaging: `war`
> 최종 webpack manifest 업데이트: 2019-10-23 (`web/WEB-INF/jsp/winclude/_assetVersions.jsp:8`)

---

> 🔍 **2026-09-22 본문 전면 점검** — `cloud_live`(`ac28913e`, 2026-09-22) 기준
>
> 본문이 2026-07-10 이후 74일 멈춘 사이 저장소에 390 커밋이 들어왔습니다.
> 인용 파일 221개 중 36개가 사라진 상태였습니다.
>
> ### 큰 줄기 — JSP 지면이 대거 걷혔습니다
>
> | 이슈 | 시점 | 무엇을 지웠나 |
> |---|---|---|
> | `FE1-1359` | 2026-08-04 | **투자 지면**과 **스타트업 지면** |
> | `CLIENT-238` | 2026-09-03 | 통합으로 참조를 잃은 **펀딩 상세 JSP** |
> | `CLIENT-239` | 2026-09-04 | **wmain 지면 JSP** 와 공통 include JSP |
>
> ### 정정 9건
>
> | # | 어디가 | 무엇이 틀렸나 |
> |---|---|---|
> | 1 | 개요·브랜치 전략 | 운영 주소를 `www.wadiz.kr` 로 적었습니다. **클라우드 운영은 `www.wadiz.io`** 입니다 |
> | 2 | 4.2 JSP 그룹 | 43개로 적혀 있었으나 **40개**입니다. 네 그룹이 사라지고 `studio` 가 생겼습니다 |
> | 3 | 4.2 `wlayout` | `wRewardDetailSPA.jsp` 가 목록에 있었으나 삭제됐습니다. 지금 16개입니다 |
> | 4 | **6.1 리워드 상세** | **전면 교체.** 전용 JSP 를 쓴다고 했으나 지금은 `GlobalKoreaFundingDetailController` 가 `global-korea/index` React 셸 하나를 돌려줍니다 |
> | 5 | **6.2 결제 체크아웃** | **전면 교체.** `WPaymentController` 가 813줄에서 **699줄**로 줄었고 **지면을 그리지 않습니다.** AJAX·JSON 전용입니다 |
> | 6 | 6.6 통합 메인 | `WStartupMainController` 가 사라졌고 JSP 는 `wmain/main.jsp` 하나만 남았습니다 |
> | 7 | 9.2 청크 맵 | `equity`·`open-account`·`coming` 세 청크가 사라지고 `landing-static` 이 생겼습니다. 지금 11개입니다 |
> | 8 | **9.3 JSP 로 강하게 남은 영역** | 목록 맨 앞의 "리워드 결제 체크아웃"이 **더 이상 해당하지 않습니다** |
> | 9 | 9.5 배포 산출물 | `_assetVersions.jsp` 가 아니라 `winclude/assetVersions.jsp` 입니다 |
>
> ### 방향이 한 줄로 보입니다
>
> `wpayment/` 폴더에는 이제 **`equity/` 하위만** 남았습니다.
> `campaign/` 폴더에는 **`include/` 하위만** 남았습니다.
> 지면 렌더링은 `global-korea/index` 셸을 쓰는 컨트롤러 9개로 모이고 있고,
> 레거시 컨트롤러들은 **AJAX 만 남기고 껍데기를 벗는 중**입니다.
>
> ### 확인하지 못한 것
>
> 저장소 `README.md` 가 낡았습니다. `dev.wadiz.kr` · `stg.wadiz.kr` · `www.wadiz.kr` 로 적혀 있습니다.
> 파일이 EUC-KR 이라 UTF-8 환경에서 한글도 깨집니다.
> **원본 저장소는 읽기 전용이라 고치지 않고 여기 기록만 남깁니다.**
>
> ---
>
> 📅 **2026-09-22 cloud_live pull 보강** (15 커밋, −154,862줄)
>
> **참조 없는 정적 자원 1,814건 삭제**로 15만 줄이 빠졌습니다.
> 그 밖에 `rc1` 프로파일 신설과 보안 수정 두 건이 있습니다.
>
> ### CLIENT-253 — 참조 없는 정적 자원 1,814건 삭제
>
> `web/resources` 아래에서 **아무 데서도 참조하지 않는 파일 1,814개**를 지웠습니다.
> 삭제 줄 수가 154,862줄입니다. SVG 아이콘, 시험용 HTML, PDF 뷰어 등이 들어 있습니다.
> `.gitignore` 에서 PDF 뷰어 제외 규칙도 함께 뺐습니다.
>
> 2026-09-15 회차의 CLIENT-241(참조 없는 스크립트·스타일 제거, −54,764줄)에 이은 정리입니다.
> **두 회차를 합치면 20만 줄이 넘습니다.**
>
> ### RWD-6091 · RWD-6093 — `rc1` 프로파일 신설
>
> - **`rc1` 프로파일을 새로 만들고 구 `rc` 프로파일을 제거**했습니다.
> - `wave-data` 를 3.1.6 으로 올렸습니다. rc1 캐시 설정이 들어간 버전입니다.
> - 인프라 쪽 짝은 [`helm-charts`](./helm-charts.md) 의 rc1 전면 복원입니다.
>
> ### 보안 수정 두 건
>
> | 이슈 | 내용 |
> |---|---|
> | **RWD-6087** | **API 프록시에서 `internal` 경로 전달을 차단**했습니다. 내부 전용 경로가 프록시를 통해 바깥에서 닿을 수 있던 것을 막았습니다. [`co.wadiz.adm`](./co.wadiz.adm.md) 에도 같은 수정이 들어갔습니다 |
> | **RWD-6073** | **청약 완료 API 진입점을 차단**했습니다. 같은 이슈로 [`com.wadiz.api.funding`](./com.wadiz.api.funding/com.wadiz.api.funding.md) 에서 금액·수량 검증을 강화했습니다 |
>
> ### RWD-6077 — 지지서명 생성 앱 API 추가
>
> - **`POST /api/v3/supporter-signatures`** 를 추가했습니다. 앱이 직접 부르는 경로입니다.
> - 쓰이지 않던 v2 지지서명 위임 코드를 함께 지웠습니다.
>
> ### CLIENT-262 — 로케일 결정 근거를 화면에 전달
>
> - 어떤 근거로 언어를 정했는지를 요청 속성으로 넘기고, `wadiz.globals` 에 **서버 경로와 로케일 결정 근거**를 담습니다.
> - `serverPath` 에는 **포워드 전 원래 요청 주소**를 담도록 고쳤습니다.
> - 프런트엔드가 언어 불일치를 센트리로 보고할 때 이 값을 함께 씁니다([`wadiz-frontend`](./wadiz-frontend/wadiz-frontend.md) CLIENT-262·CLIENT-263).
>
> ### 그 밖에
>
> | 이슈 | 내용 |
> |---|---|
> | CLIENT-274 | dev·rc4·로컬의 정적 자원 주소를 `cdn-static` 주소로 교체 |
> | RWD-6089 | 스토리 작성 완료 저장 시 **대표 이미지 필수 검증** 추가 |
> | FE2-1200 | 메이커 홈 정보구조 개편 — WAi 미리보기 |

> 📅 **2026-09-17 cloud_live pull 보강** (29 커밋)
>
> **브레이즈(Braze) 수집 코드를 JSP 에서 프런트엔드 번들로 옮기는 작업**이 최대 테마입니다.
> 브레이즈는 와디즈가 쓰는 고객 마케팅 도구입니다. 사용자 행동을 모아 두었다가 푸시·메일을 보냅니다.
>
> ### JSP 의 브레이즈 수집 코드를 걷어냈습니다 (FE1-1874 · 1891 · 1892 · 1893 · 1896 · 1446 · 1895)
>
> **무엇이 바뀌었나**
>
> | 파일 | 변화 |
> |---|---|
> | `web/WEB-INF/jsp/winclude/tracking-braze-head.jsp` | **삭제**(193줄). 이 파일이 브레이즈 SDK 를 직접 불러오고 초기화했습니다 |
> | `web/WEB-INF/jsp/winclude/wadizGlobals.jsp` | +53줄. **`wadiz.braze` 라는 진입점**을 새로 둡니다 |
> | `web/WEB-INF/jsp/winclude/studioWadizGlobals.jsp` | +50줄. 스튜디오 지면도 같은 진입점을 씁니다 |
>
> 이제 JSP 는 **`wadiz.braze.ensureInit()` 같은 함수 이름만 부릅니다.** 실제 구현은 프런트엔드 번들이 등록합니다.
> `window.appboy` 를 직접 만지던 코드도 모두 이 진입점을 거치도록 바꿨습니다.
>
> **번들이 없으면 조용히 실패하던 문제를 드러냈습니다**
>
> `wadizGlobals.jsp` 의 주석에 이유가 적혀 있습니다.
> 번들은 `head` 안의 동기 스크립트라 본문 호출부보다 반드시 먼저 실행됩니다.
> 그래서 대역(stub) 함수가 실제로 불렸다면 **번들이 로드되지 않았다는 뜻**이고, 그 지면은 수집이 통째로 빕니다.
> 예외도 로그도 남지 않는 실패라, 대역 함수가 불리면 **센트리(Sentry)에 `braze-stub-called` 로 직접 보고**합니다.
> 센트리는 오류를 모아 보여 주는 도구입니다. 지면당 한 번만 보냅니다.
>
> `flush` 만은 예외로 **대역 상태에서도 콜백을 반드시 실행**합니다.
> 콜백으로 화면 전환을 이어 가는 호출부가 있어, 실행하지 않으면 화면이 멈추기 때문입니다.
>
> **SDK 를 안 받는 방문에는 내려주지 않습니다** (`head.jsp`)
>
> 종전에는 모든 방문에 브레이즈 SDK 를 미리 받도록 `preload` 를 걸었습니다.
> 이제 아래 세 경우는 건너뜁니다. 주석에 **"187KB 를 그냥 버리게 되므로"** 라고 적혀 있습니다.
>
> | 건너뛰는 방문 | 판정 방법 |
> |---|---|
> | 봇(검색엔진 등) | `requestScope.isBot` |
> | 앱 웹뷰 | User-Agent 에 `ioswadiz` 또는 `androidwadiz` 포함 |
> | 국내 비로그인 | `country` 쿠키가 `KR` 이면서 로그인 정보가 없음 |
>
> 초기화 시점도 늦췄습니다. 로그인해서 사용자를 식별하는 시점, 또는 첫 수집이 일어나는 시점까지 미룹니다.
>
> ### RWD-5975 — 인공지능 심사 이력 정리
> 프로젝트 스토리를 인공지능이 검토하는 기능입니다. 이번에는 이력 표시와 검증을 손봤습니다.
>
> - 인공지능 심사 이력 목록 응답에 **심사 주체(`reviewSubject`)** 를 추가했습니다. 자동 심사인지 사람의 요청인지 구분합니다.
> - 진행 중 스토리 조회의 최신 심사 판단에 **자동 심사 결과도 포함**하도록 했습니다.
> - **심사 횟수 초과 검사를 "심사 요청" 에만 적용**하고, 경계 기준을 [`com.wadiz.api.funding`](./com.wadiz.api.funding/com.wadiz.api.funding.md) 과 맞췄습니다.
> - 반영 저장 시 **심사 이후에 수정이 있었는지 검증**을 추가했습니다. 신규 예외 `AIReviewRequiredException` 이 들어왔습니다.
>
> ### FE2-1231 — 메이커센터 주소가 별도 도메인에서 하위 경로로 바뀝니다
> `makercenter.wadiz.io` 를 쓰던 것을 **`wadiz.io/web/maker/makercenter`** 로 옮깁니다.
> 같은 이슈가 [`makercenter-fe`](./makercenter-fe.md)·[`makercenter-be`](./makercenter-be.md)·[`helm-charts-gitops`](./helm-charts-gitops.md) 에도 함께 들어갔습니다.
>
> ### 그 밖에
>
> | 이슈 | 내용 |
> |---|---|
> | FE1-1755 | 혜택 안내 랜딩 지면을 `global-korea/index` 로 전환했습니다. 프런트엔드가 `apps/global` 로 이관한 것과 짝입니다 |
> | RWD-6061 | rc4 의 나이스페이 홈 디렉터리 설정을 바꿨습니다 |
> | FE2-1318 | rc4 의 `analytics_host` 를 rc4 전용 수집 호스트로 고쳤습니다 |
> | CLIENT-269 | stage 브랜치를 자동 병합한 뒤 통합 검사 워크플로가 실행되지 않던 문제를 고쳤습니다 |
> | (워크플로 이름) | `prepare-branch-for-regular-deployment` 를 `prepare-branch-for-regular-release` 로 되돌렸습니다 |

> 📅 **2026-09-15 cloud_live pull 보강** (22 커밋)
>
> ⚠️ **직전 동기화 뒤 로컬이 `cloud_dev` 로 옮겨져 있었습니다.** 기준 브랜치 규칙(cloud_live 우선)에 따라 **`cloud_live` 로 되돌린 뒤** 2026-09-10 시점(`e6708608b6`)부터 다시 맞췄습니다.
>
> **stage 환경을 클라우드로 재구축(RWD-6044·CLIENT-258·BE3-930)** 이 최대 테마입니다.
>
> ### RWD-6044 / CLIENT-258 / BE3-930 — stage 환경을 클라우드 기반으로 재구축
> - **스테이지 브랜치명을 `cloud_stage` → `stage` 로 확정**했습니다.
> - **stage 프로파일을 `clive` 기반으로 다시 만들었습니다** (`stage.wadiz.io`). env 별 리소스 **14종을 clive 기준으로 동기화**했고, stage 의 main2·account 호출을 **stage 네임스페이스 서비스**로 돌렸습니다 (`proxy-stage.xml`·`reward-stage.xml`·`searcher-stage.xml`·`user-stage.xml`).
> - stage 지면의 전역 주소를 **stage 전용 공개 호스트**로, 정적 자원 원본을 **`cdn-static.stage.wadiz.io`** 로 바꿨습니다.
> - 인프라 쪽 짝: [`helm-charts`](./helm-charts.md)·[`helm-charts-gitops`](./helm-charts-gitops.md) 에 **`web/stage`·`user-platform/stage` 환경이 신설**됐습니다.
>
> ### FE1-1867 — Braze 초기화 실패 대응
> - **쿠키에 접근할 수 없는 문서에서는 Braze SDK 로드를 차단**합니다(스텁은 유지해 호출부가 깨지지 않게 함). 미초기화 상태에서는 아예 호출하지 않는 게이트를 두고, 전송 호출을 예외로부터 격리했습니다.
> - 초기화 실패 **원인 진단과 재시도**를 추가했습니다 (`web/WEB-INF/jsp/winclude/tracking-braze-head.jsp` +71줄).
>
> ### RWD-6027 — 취소·반환 원장에 행위 주체 기록
> - `RefundActorType` 을 도입하고, **메이커 승인 경로의 반환 주체를 `MAKER` 로** 기록합니다. **order 서버 프록시 경로**도 추가했습니다(`proxy-*.xml` 4종).
> - [`com.wadiz.api.funding`](./com.wadiz.api.funding/com.wadiz.api.funding.md)·[`co.wadiz.adm`](./co.wadiz.adm.md) 의 같은 이슈와 짝입니다.
>
> ### 기타
>
> | 이슈 | 내용 |
> |---|---|
> | FE1-1780 | **카테고리 지면을 global 쉘로 전환**하고 `wmain/category.jsp` 를 삭제했습니다. 프론트에서 카테고리 페이지를 `apps/global` 로 이전한 것과 짝입니다 |
> | BE3-938 | 인증 성공 시 **SMS 발송 카운트 초기화를 허용 국가로 제한**(`SmsAuthenticationSendLimiterTest` 52줄 신규) |
> | CLIENT-269 | 이미지 빌드 워크플로의 환경 순서를 배포 단계에 맞추고 **rc4 추가**, 정기배포 브랜치 준비 대상을 기본 브랜치로 교체 |

> 📅 **2026-09-10 cloud_live pull 보강** (17 커밋, −54,764줄)
>
> **참조 없는 스크립트·스타일 파일 제거(CLIENT-241)** 로 5만 줄 넘게 빠졌고, 결제 유예(GRACE_PERIOD) 대응과 SPA 이관이 이어집니다.
>
> ### CLIENT-241 / CLIENT-242 — 죽은 자산·설정 정리 (−54,764줄)
> - 직전 회차에서 JSP 61개를 지운 데 이어, 이번에는 **그 JSP 들이 참조하던 스크립트·스타일 파일**을 걷어냈습니다 (`js` · `static` · `equity` · `Content` 영역).
> - 빠진 대표 파일: `wadiz/lib/text.js`(408줄) · `wadiz/lib/cookie.js`(165줄) · `lib/jquery.placeholder.js`(185줄) · `TextareaAutoResize.js`(194줄) · `landing.js`(152줄) · `reward.js`(142줄) · `wadiz/lib/lodash.min.js` · `lib/lottie.min.js` · `lib/require.js` · `lib/vue-touch.min.js` · `lazysizes.min.js` 등. **번들 라이브러리(minified)가 다수 포함돼 삭제 줄 수가 큽니다.**
> - CLIENT-242: 목적지가 사라진 **urlrewrite 규칙 3건 제거**, Eclipse 설정 파일 제거, **Maven 래퍼를 jar 없는 방식으로 복구**하고 `local-run.sh` 를 래퍼 호출로 바꿨습니다.
>
> ### 결제 유예(GRACE_PERIOD) 대응 — BE3-783 · BE3-784 · BE3-635 · RWD-5951 · RWD-5981
> - **BE3-783**: 멤버십 상태에 `GRACE_PERIOD` 를 추가하고, 응답에 **`nextRetryDate`(다음 재시도일) · `graceUntil`(유예 종료일)** 을 실어 보냅니다.
> - **BE3-635**: 위 두 날짜를 **`String` 으로 내려보내도록 바꿨습니다.** 이유가 명시돼 있습니다 — 이 저장소는 **Spring Boot 1.x 의 Jackson 이라 `java.time` 타입을 역직렬화하지 못합니다.**
> - **RWD-5951 / RWD-5981**: 커뮤니티 데이터와 참여자 리스트의 멤버십 뱃지를 `isAvailable` → **`hasMembership`** 축으로 전환했습니다. RWD-5981 은 2026-09-03 에 릴리즈 당일 되돌려졌다가 **이번에 다시 적용됐습니다**(`f6fe4bfc75`, "Revert 의 Revert"). 짝이 되는 [`com.wadiz.api.funding`](./com.wadiz.api.funding/com.wadiz.api.funding.md) 의 RWD-5981 도 함께 되살아났습니다.
>
> ### 글로벌 SPA 이관 3건 (FE1-1751 · FE1-1754 · FE1-1756)
> - **서포터클럽 소개**(`/web/supporter-club/intro`) · **앱 설치 랜딩** · **서비스 제공 현황** 세 지면의 뷰를 **`global-korea/index` 로 전환**했습니다. 프론트 쪽에서 같은 이슈로 `apps/global` 한국 라우트에 페이지를 만들었습니다.
> - 앱 설치 랜딩 라우트는 이후 `GlobalKoreaUIController` 로 옮겼습니다.
>
> ### FE1-1836 — 개인정보처리방침 위탁 업체·글로벌 파트너사 목록 변경
> - `web/resources/terms/privacy_entrustments.html` 과 `privacy_third_parties_global_partners.html` 을 갱신했습니다(후자 53줄 변경).
>
> ### 기타
> - **FE1-1811** — 로컬 개발 도메인을 `local.wadiz.io` 로 변경.
> - 직전 회차의 CLIENT-229(HTML 메타데이터 다국어)에서 `html-metadata_ko` 변경분 일부를 되돌렸습니다(FE1-1754).
>
> ---

> 📅 **2026-09-08 cloud_live pull 보강** (40 커밋, −8,858줄)
>
> ⚠️ **이번 pull 의 핵심은 대규모 죽은 코드 정리입니다.** SPA(글로벌) 이관으로 참조를 잃은 **JSP 61개와 컨트롤러·검증기 11개 클래스**가 삭제됐습니다. 이 레거시 저장소가 실제로 줄어들기 시작했습니다.
>
> ### CLIENT-238 / CLIENT-239 / CLIENT-240 — 참조를 잃은 JSP·컨트롤러 제거 (17커밋)
>
> 세 이슈가 단계적으로 진행됐습니다.
>
> | 이슈 | 범위 |
> |---|---|
> | **CLIENT-238** | 통합으로 참조를 잃은 **펀딩 상세·오픈예정 상세** JSP 와, 주석 처리돼 있던 뷰 메서드·미사용 필드. 호출 지점이 없는 검증기 2종(`CampaignAccessPermitValidator`·`WRewardComingSoonValidator`)과 오픈예정 상세 전용 조회·캐시 설정 |
> | **CLIENT-239** | 지면 JSP 일괄 제거 — `wmain`(통합 이전 지면) · `waccount`/`account`(계정) · `wterms`(약관) · `winclude`(공통 include) · `wlayout`(레이아웃) · `wpurchase`·`wpayment`·`wcampaign`·`wcoming`·`wevent`·`wmypage`·`wsub`·`oauth`·`mobile` |
> | **CLIENT-240** | JSP 가 사라져 **존재하지 않는 화면을 가리키게 된 컨트롤러·메서드** 정리 — 투자 커뮤니티·투자 헬프센터 컨트롤러 4종, 이전 약관 컨트롤러, W9 웨비나 컨트롤러, 스쿨 강의 영상·청약 안내·사전 퀴즈·모바일 쿠폰·이벤트 지면 메서드. `waccount` 의 비로그인 분기는 **로그인 지면 리다이렉트로 변경** |
>
> - 삭제된 Java 클래스 11개: `FTMOWCommunityController` · `FTWEBCommunityController` · `FTMOBHelpCenterController` · `FTWEBHelpCenterController` · `WEBTermsController` · `WMyWebinarController` · `CampaignAccessPermitValidator`(+테스트) · `WRewardComingSoonValidator` · `RewardComingSoonPageType` · `ComingSoonForSPA`.
> - **남은 JSP 는 265개**입니다(이번에 61개 삭제).
> - 큰 파일이 여럿 빠졌습니다 — `wpurchase/reward/step10.jsp`(816줄), 약관 include 6종(`innerTerms*`, 합계 1,175줄) 등.
>
> ### RWD-6014 — IP 국가판별 재활성화와 기본값 정리
> - IP 로 접속 국가를 판별하는 기능을 **다시 켰습니다**. 판별 실패 시 기본 언어는 `en` 으로 원복했다가, 이어서 **`KR_ko`** 로 정리했습니다(응답의 `country` 가 `null` 인 경우도 `KR_ko`).
> - rc4·cdev 의 국가판별 API 호스트를 **aidata 도메인으로 교체**했습니다.
>
> ### FE2-1214 — 메이커 이용약관 2026.09.08 개정
> - **2026년 9월 15일 이후 제출된 프로젝트부터 시행**됩니다(개정일 2026.09.08). 직전 판(2026.08.18)은 `funding_maker_service_20260818.html`(1,265줄)로 보존되고 `/web/wterms/maker_service/20260818` 에서 볼 수 있습니다.
> - 주요 변경 두 가지입니다.
>   - **데이터 활용 범위 확대** — 종전 "프로젝트 이력 등의 정보를 통계자료 작성·다른 서비스 적용에 활용" 에서, **판매 데이터·광고 집행 및 성과 이력**까지 포함해 서비스 제공·운영·개선, 신규 서비스 개발, 통계·자료 작성 목적으로 **수집·저장·분석·가공·결합**할 수 있도록 넓혔습니다.
>   - **가공 결과물의 권리 귀속 조항 신설** — 위에 따라 작성한 통계·지표·분석 자료·데이터베이스 등 가공 결과물의 권리는 **회사에 귀속**됩니다.
>
> ### 기타
>
> | 이슈 | 내용 |
> |---|---|
> | RWD-5944 | 프로젝트 라벨 열 정리 — `custom_label_0/1` 을 **기획전·부스터쿠폰 라벨로 교체**하고 미활용 `custom_label_5~9`·`internal_label` 열 제거 |
> | BE3-903 | GTM(구글 태그 매니저) 개발 환경 격리 — rc 계열(rc4 포함)과 dev 를 운영과 분리. 클라우드 캐시가 `null` 을 미처리해 나던 오류도 수정(메이커 인증 상태 조회·펀딩 완료 첫 진입 판정) |
> | RWD-5996 | 레거시 업로드 S3 access/secret key 제거 — IRSA 단일화. [`co.wadiz.adm`](./co.wadiz.adm.md) 과 같은 작업 |
> | FE1-1778 | 더보기 페이지 `/web/main/more` 를 **`global-korea/index` 로 전환** (프론트 `wadiz-frontend` FE1-1778 과 짝) |
> | FE1-1672 | 막펀잡기 페이지 진입 경로 추가 |
> | SCOUT-152 | 결제 배송 정보 엑셀에 **배송비 할인 금액** 추가(+테스트) |
> | RWD-6011 | 호출부가 없는 간편결제 API 를 `deprecated` 처리 |
>
> ---

> 📅 **2026-09-03 cloud_live pull 보강** (26 커밋)
>
> **HTML 메타데이터의 다국어 전환(CLIENT-229, 8커밋)** 이 최대 테마이고, 서포터클럽 약관 개정과 릴리즈 당일 되돌림 1건이 뒤를 잇습니다.
>
> ### CLIENT-229 — HTML 메타데이터를 JSP 분기에서 다국어 메시지로 이전
> - 지금까지 페이지 `title`·`description`·OG/트위터 이미지는 **JSP 안에서 국내/글로벌을 갈라 출력**했습니다. 이 분기를 걷어내고 **메시지 프로퍼티(시트) 기반**으로 바꿨습니다.
> - 신규 `HtmlMetadataMessageResolver`(`src/main/java/com/wadiz/web/fw/utils/`) — 메시지 템플릿 안의 `{{ arg_0 }}` 자리표시자를 인자로 채웁니다. 인자가 모자라면 빈 문자열로 대체해 예외 없이 넘어갑니다.
> - 메시지 파일 `messages/html-metadata{,_ko,_ja,_zh}.properties` 신설. 키는 `{페이지키}.meta.title` · `.meta.description` · `.meta_og.image_url` 형태이고, 프로젝트·스토어 상세처럼 값이 변하는 페이지는 `funding_{project_no}_page.meta.title={{ arg_0 }} by {{ arg_1 }} | 와디즈` 처럼 인자를 씁니다.
> - 기존 `PageKeyResolver` 를 **`HtmlMetadataPageKeyResolver`** 로 이름을 바꿨고, JSP(`global/index.jsp`·`global-korea/index.jsp`)의 출력 분기를 **`meta` 객체 하나로 통일**했습니다(`global-korea/index.jsp` −89줄).
> - 스토어 상세·선물하기 메타데이터도 같은 방식으로 이전했고, 메이커 추천 프로그램의 하드코딩 메타데이터는 제거했습니다.
> - 지지서명 상세의 경로 변수명을 `supportShareNo` → **`supportShareId`** 로 바꿨습니다.
>
> ### FE1-1761 — 서포터클럽 멤버십 약관 개정 (결제 실패 유예기간 신설)
> - **결제 실패 시 익일 효력 상실 → 7일 유예기간**으로 바뀝니다. 개정 약관은 **2026년 9월 10일 시행**(개정일 2026.09.03)입니다.
> - 조문 변경: 결제가 정상 처리되지 않으면 혜택 제공은 즉시 중단되고, 결제 실패일로부터 7일간 유예기간이 부여되며 그 안에 결제가 완료되지 않으면 멤버십이 자동 해지됩니다.
> - 직전 판(2026.08.18 개정)은 `web/resources/terms/supporter_club_20260818.html` 로 보존되고 `/web/wterms/supporter_club/20260818` 에서 볼 수 있습니다.
>
> ### RWD-5981 / RWD-5951 — 멤버십 뱃지 판정 필드 정정 (릴리즈 당일 되돌림)
> - 커뮤니티 데이터와 참여자 리스트의 멤버십 뱃지 판정을 `isAvailable` → **`hasMembership`** 으로 바꿨습니다(RWD-5951 → RWD-5981).
> - ⚠️ 그런데 **RWD-5981 은 `release/v20260903` 에서 되돌려졌습니다**(`72e2296c18`). 짝이 되는 [`com.wadiz.api.funding`](./com.wadiz.api.funding/com.wadiz.api.funding.md) 의 RWD-5981(서포터 목록 `hasMembership`/`canUseBenefit` 분리)도 같은 날 함께 되돌려졌습니다. 앞선 RWD-5951(커뮤니티 데이터)은 남아 있어 **현재 두 지면의 판정 기준이 서로 다릅니다.**
>
> ### 기타
>
> | 이슈 | 내용 |
> |---|---|
> | SCOUT-152 | 중간 배송 처리 시 **프로젝트 KC 인증 여부 체크를 제거**(테스트 포함, `InDemandValidator`) |
> | FE1-1752 | 사용하지 않는 펀딩 결제 실패 지면 매핑 제거(`GlobalUrlMappingConfig`). `wadiz-frontend` 의 같은 이슈와 짝 |
> | RWD-5868 | 정산 비율 버전 조회 실패 시 **기본 버전을 반환**하고 timeout 설정 추가(`SettlementGateway`) |
> | FE1-9 | 로컬 개발 환경 정비 — `scripts/local-setup.sh`·`local-run.sh` 로 CLI 기반 서버 구동, JDK 8 전환, VS Code 디버깅 설정. 2026-03 작업이 이번에 cloud_live 로 올라왔습니다 |
>
> ---

> 📅 **2026-09-02 cloud_live pull 보강** (45 커밋)
>
> ⚠️ 직전 동기화 때 로컬이 `bugfix/rc4-profile-image-cdn-url` 브랜치에 있어 pull 대상이 어긋나 있었습니다. **`cloud_live` 로 복귀**해 다시 맞췄습니다.
>
> **다국어(en/ja/zh) 폴백 전환(RWD-5901·SCOUT-153)** 과 **앵콜 불러오기 정합성(RWD-5915)** 이 핵심입니다.
>
> ### RWD-5901 — 하드코딩 이분 분기를 MessageSource·언어 테이블 조인으로 전환 (9커밋)
> - 심사서류 라벨·**KC 서류 카운트 설명문**의 `ko`/`en` 이분 분기를 **MessageSource 다국어 처리**로 바꿨습니다.
> - **심사 카테고리 조회**를 `ScreeningRewardItemCategoryLanguage`(ko) 조인으로, **은행 코드 조회**를 `BankCodeLanguage` 조인 + **en 폴백**으로 전환했습니다.
> - 메이커 소재지 시/도 명칭을 **ko/en/ja/zh 지원 + 영문 폴백**으로 전환. 정보제공고시 라벨에도 en 폴백 추가.
> - 심사 base 테이블의 `LanguageCode` 컬럼 삭제에 대비해 전환기용 `'ko'` 필터를 제거했습니다. `funding-core` 의존성 1.0.149-SNAPSHOT.
> - '원하는 리워드 없음' 판정을 `IsNoMatching` 플래그 비교로 전환.
>
> ### SCOUT-152 / SCOUT-153 — 인디맨드 발송 처리와 발송 다국어
> - **인디맨드 발송 처리 API 추가**(SCOUT-152). 발송 처리중 전환 API 응답에 **성공·실패 건수와 미전환 발송번호**를 포함하도록 보강했습니다.
> - SCOUT-153: 일괄 발송 처리 다국어, **환불 거절 사유 번역본 저장** 후 서포터 참여 내역 화면에서 번역해 내려주기. 발송 환불 페이지와 발송 관련 API 는 `DisplayLanguageResolver` 로 **ja/zh → en 폴백**을 적용합니다.
>
> ### RWD-5915 — 앵콜 불러오기 정합성
> - 앵콜 불러오기 시 **만족도·체험리뷰 사용여부를 `CampaignMarker` 에 저장**하고, 프로젝트 정보 저장 시 정합성 검증을 추가했습니다. 앵콜 리뷰 마커명은 `MarkerId varchar(30)` 제한에 맞춰 단축했습니다.
>
> ### FE1-1488 — `JoinController` 복원 (삭제 회귀 방지)
> - `/web/v2/join` 컨트롤러를 **복원**했습니다. 소셜 연동 약관(`/web/v2/join/terms`)이 실사용 중이라 삭제하면 회귀가 발생합니다.
>
> ### RWD-5979 — 헬스체크 경로 언어 판별 제외
> - 헬스체크 경로는 **언어 판별 필터를 건너뛰도록** 수정하고, `skip=request-header` 로그를 제거했습니다.
>
> ### BE3-769 — 따라잡기 글로벌
> - 따라잡기 글로벌 확대에 맞춰 country/language 전파를 반영했습니다([`main1-api`](./com.wadiz.api.main.md) DISPLAY-1691 과 연결).
>
> ---
>
> 📅 **2026-08-27 cloud_live pull 보강** (13 커밋)
>
> 광고센터 소재 제작기(`/tools`) 서빙 컨트롤러 신설이 핵심입니다.
>
> ### FE2-1109 — 광고센터 소재 제작기 `/tools` 서빙 컨트롤러 추가
> - **신규 `web/tools/controller/ToolsController.java`** — `GET /tools/{name}`. CDN 에 올려둔 정적 HTML 을 서버가 받아 그대로 내려주는 서빙 엔드포인트입니다.
> - **캐시 없음**: 서버 캐시를 두지 않고 매 요청마다 CDN 에서 최신 HTML 을 가져오며, 응답에 `Cache-Control: no-cache, no-store, must-revalidate` 를 붙입니다(사내 무캐시 관례와 동일) (`:42,66`).
> - **검색 색인 제외**: 응답 헤더에 `X-Robots-Tag: noindex, nofollow` 를 추가했습니다 (`:95`).
> - **에러 매핑**: CDN 이 403(없는 파일)을 주는 경우까지 **404** 로 매핑하고, 에러 응답은 404/500 공통 에러 페이지로 분기합니다.
> - **로케일 리다이렉트 예외**: `GlobalUrlMappingConfig` 의 `noRedirectList` 에 `/tools/**` 를 추가해, 로케일 무관 정적 HTML 이 국내·글로벌 양쪽에서 진입되도록 했습니다 (`fw/config/GlobalUrlMappingConfig.java:86-87`).
>
> ### RWD-5944 / WSR-3459 — 본펀딩 카탈로그 피드에 기획전·부스터쿠폰 구분 라벨 추가
> - `affiliation/criteo/service/CriteoRewardService.java` 의 피드 컬럼에 **`internal_label_0`·`internal_label_1`** 을 추가했습니다. `custom_label_0~9` 가 이미 사용 중이라 별도 이름을 씁니다.
> - `internal_label_0` 은 기획전(`CuratedCollection`) 편입 여부로 `Y` 또는 빈 값, `internal_label_1` 은 부스터쿠폰(`boostercoupon`) 편입 여부로 `booster_y`/`booster_n` 을 채웁니다. 카탈로그 광고의 **제품 세트 자동 구성**이 목적입니다.
> - 캠페인 수천 건을 순회하므로 컬렉션 캠페인 ID 를 **루프 진입 전 1회만 조회해 `Set` 으로 보관**(O(1) 조회)합니다. 컬렉션 조회가 실패하면 피드 전체를 실패시키지 않고 **해당 라벨만 비워** 크롤러가 계속 수집할 수 있게 합니다(`getCampaignIdsByKeywordQuietly`).
>
> ### RWD-5957 — 댓글 이미지 CDN base-url 을 funding-public-cdn 도메인으로 전환
> - `application_funding_cdn_base_url` 을 CloudFront 기본 도메인(`https://d1ruwxjthziwe4.cloudfront.net/`)에서 환경별 **`funding-public-cdn.{env}.wadiz.io`** 로 바꿨습니다 — dev·local 은 `funding-public-cdn.dev.wadiz.io`, rc4 는 `funding-public-cdn.rc4.wadiz.io`(rc4 버킷 배포) (`resources/properties/file-{dev,local,rc4}.properties`).
>
> ### FE1-1680 — 로컬 개발환경 user API HTTPS 호출 실패 수정
> - `catchup/config/CatchUpClientConfig.java` 에 https 스킴 등록을 추가해 로컬에서 user API HTTPS 호출이 실패하던 문제를 고쳤고, 등록 형태를 기존 클라이언트 설정과 동일하게 통일했습니다.
>
> ---
>
> 📅 **2026-08-25 cloud_live pull 보강** (234 커밋)
>
> ⚠️ **기준 브랜치가 `master` → `cloud_live` 로 바뀌었습니다.** 그래서 master 기준으로는 보이지 않던 **클라우드 이관 작업 전체**가 들어옵니다 — 도메인 전환(`wadiz.kr`/`wadiz.co` → `wadiz.io`), 정적 CDN 도메인 교체, 쿠버네티스·Redis 세션·JDBC 설정, 투자(equity)·W9 지면 제거가 그것입니다. 약관 개정과 정책 sitemap 등 서비스 변경은 master 와 공통입니다.
>
> ### FE1-798 / FE1-894 / FE1-1060 — 와디즈 도메인 `wadiz.io` 전환 (cloud_live 전용)
> - 하드코딩된 `wadiz.kr`/`wadiz.co` 도메인을 **동적 분기 처리**로 전환하고, `clive.wadiz.co` 분기 적용과 메일 도메인 교체를 진행했습니다(FE1-798). dev/local/rc4 의 static CDN 도메인도 함께 변경했습니다.
> - CDN 도메인이 여러 차례 정리됐습니다: `clive-cdn-static.wadiz.co` → `cdn-clive-static.wadiz.co` → **`cdn-static.wadiz.co`**(FE1-894), 이어서 **`wadiz.co` 전체를 `wadiz.io` 로 교체**하고 `cdn-funding`·local 도메인까지 맞췄습니다(FE1-1060).
>
> ### FE1-1359 / FE1-1322 — 투자(equity)·W9 지면 제거
> - 규칙에 가려져 도달 불가하던 **W9 멤버십 가입 안내 지면을 제거**하고, 소비처가 사라진 equity chunk 선언을 정리했습니다(FE1-1359).
> - 투자 관련 진입구를 걷어냈습니다 — 회원가입 흐름의 투자 계좌개설 진입구 제거, 투자 예치금·출금계좌 조회 API 호출부 제거, 도달 불가한 투자 가입 불가 모달 분기 제거, 종료 지면으로 보내던 투자 링크 제거, 투자 청약 에러 지면을 공통 에러 페이지로 대체, 스쿨 투자형 강의 이동 대상을 스쿨 메인으로 변경(FE1-1322).
>
> ### RWD-5606 / RWD-5766 / RWD-5863 / RWD-5593 / BE3-688 — 클라우드 인프라 설정 (cloud_live 전용)
> - RWD-5606: `session_token_redis`(standalone/elasticache) 키 추가. oauth2 `issuer-uri` 를 클러스터 내부 account-server 로 바꿨다가 **`https://account.wadiz.co` 로 원복**했습니다.
> - RWD-5766: clive JDBC 주소 변경, JDBC·CORS 필터의 io 전환, `jdbc-local.properties` 개행 문자(CR) 정리.
> - RWD-5863: rc4 `file-rc4.properties` 의 누락 키(walink·redis port 등 env 무관 키)와 세션 Redis host·스토리지 버킷·자격증명 값을 보완했습니다.
> - RWD-5593: `wave-data` 기본값을 **standalone(3.x)** 으로 맞춰 flavor 매트릭스를 정합시키고 누락 설정을 추가했습니다.
> - BE3-688: Tomcat 7 이 지원하지 않는 `disableURLRewriting` 을 **`web.xml` 의 tracking-mode COOKIE** 로 교체하고, Dockerfile 주석을 `RUN` 밖으로 옮겼습니다(IDE 파서 호환).
>
> ### BE3-464 — 따라잡기(catch-up) 연동 보정
> - `CatchUpServiceAdapter` 에서 따라잡기 액션의 `country` 를 **요청 헤더에서 추출해 funding 으로 전달**하도록 하고, funding 응답의 body status 를 검사해 **HTTP 200 + envelope 4xx** 조합을 실패로 판정하게 했습니다.
>
> ### 약관·정책 개정 5종 (FE1-1603 / FE2-1021 / FE2-1012)
> - 현행 약관 5개를 **2026.08.18 개정**본으로 교체하고 직전 버전을 날짜 붙인 파일로 아카이브했습니다. 지난 약관 파일은 신규 추가만 하고 내용은 손대지 않았습니다.
>
> | 현행 파일 | 아카이브된 직전 버전 |
> |---|---|
> | `web/resources/terms/signup.html` | `signup_20251226.html` (개정 2025.12.26) |
> | `web/resources/terms/service_reward.html` | `service_reward_20260721.html` (개정 2026.07.21) |
> | `web/resources/terms/funding_maker_service.html` | `funding_maker_service_20260721.html` (개정 2026.07.21) |
> | `web/resources/terms/supporter_club.html` | `supporter_club_20250220.html` (개정 2025.02.20) |
> | `web/resources/terms/maker_page_service.html` | `maker_page_service_20220215.html` (제정 2022.02.15) |
>
> - 개정 사유는 커밋 기준 **도메인 전환 반영**(FE2-1021)과 **예약결제의 결제시도 횟수 변경**(FE2-1012)입니다.
>
> ### CLIENT-157 — 정책(약관) 전용 sitemap 신설
> - **신규 `seo/service/SitemapPolicyService.java`** — 현행 정책 17종의 라우트(`/web/wterms/{key}`)와 정적 파일명을 `POLICIES` LinkedHashMap 으로 고정하고, 각 HTML 본문에서 `개정|제정 YYYY.M.D` 패턴(`REVISION_DATE`)을 읽어 `lastmod` 를 파생합니다. 항목 DTO 는 `SitemapPolicyEntry`.
> - `SitemapXmlBuilder.buildPolicyUrlset()` 추가, `SeoSitemapController` 에 `sitemap-policies.xml` 매핑 추가, sitemap 인덱스(`web/sitemap.xml`) 편입, `web/sitemap.xsl` 에 `lastmod` 렌더링 추가. 파일명은 작업 중 `sitemap-policy` → **`sitemap-policies.xml`** 로 정리됐습니다.
>
> ### RWD-5819 / PRODUCT-903 — 후원·캠페인 단일 리워드 500만원 상한 검증
> - **신규 `reward/rewarditem/validator/RewardAmountLimitValidator.java`** — 대표 카테고리가 후원(B1380)·캠페인(B1360)인 프로젝트의 **단일 리워드 금액(배송비 제외 판매가)** 상한을 `MAX_SINGLE_REWARD_AMOUNT = 5_000_000` 으로 검증합니다. 위반 시 `NotAllowedRewardAmountException`.
> - 적용 지점: 리워드 저장 · 프로젝트 정보 저장 · 제출/재제출/사후심사 재제출. 검증을 `ScreeningRequirementValidator` 로 옮기면서 **임시저장은 건너뛰도록** 정정했습니다.
>
> ### RWD-5856 — 프로젝트 다건 부스터 쿠폰 API 추가
> - **신규 `reward/coupon/controller/ProjectCouponApiController.java`** — `GET /web/reward/api/coupons/projects/bulk`(비로그인 가능). 파라미터는 `projectNos`(콤마 구분, 최대 100개)·`projectType`(`CouponTargetType`), 헤더 `wadiz-country` 선택. 응답은 `ProjectCouponsVo` 목록이며 프로젝트 전용 쿠폰만 내려줍니다. 실제 조회는 `com.wadiz.api.reward` 의 `/api/v1/rewards/coupons/projects/bulk` 를 호출합니다.
>
> ### RWD-5896 / RWD-5862 / RWD-5916 / RWD-5801 — 피드·예약결제·관측
> - RWD-5896: 사입(와배송) 피드를 추가하고 피드 URL 도메인을 프로퍼티화했습니다. 프로젝트 단위도 넣었다가 **상품 단위만 유지**하는 것으로 정정했습니다.
> - RWD-5862: 예약 결제 회차를 확인해 다음 결제일을 노출하고 최종 결제일에서 공휴일을 제외합니다(funding 의 같은 이슈와 짝).
> - RWD-5916: Datadog 트레이스에 인증 사용자 ID(`usr.id`) 태그 추가 — 비로그인 제외, 태깅 실패는 요청에 영향 없음.
> - RWD-5801: `X-Forwarded-Proto` 관련 로그를 추가했다가 롤백했습니다.
>
> ### FE1-1492 — Framer 프록시를 다중 페이지 구조로 확장
> - `FramerProxyProperties` 의 대상 URI 맵을 `Map<Language, String>` → **`Map<페이지슬러그, Map<Language, String>>`** 2단으로 바꾸고 `getTargetUri(page, language)` 로 조회합니다. 미설정 슬러그는 `NullPointerException` 으로 즉시 드러냅니다.
> - `proxy-common.xml` 에 기존 `about` 외에 **`globalagency`** 슬러그(ko/en/ja/zh 4개 URI)를 추가하고 `web.xml` 에 매핑을 등록했습니다.
>
> ### 기타 (CLIENT-213 / RWD-5872 / FE1-1397 / FE1-1313 / FE2-862)
> - CLIENT-213: 펀딩 상세 `WebPage` 구조화 데이터의 `dateModified` 를 프로젝트 상태별로 분기.
> - RWD-5872: 프로젝트 삭제 시 서버에서 제출 여부와 소유자를 검증.
> - FE1-1397: 지지서명 상세 `og:url` 누락을 `canonicalUrl` 주입으로 수정.
> - FE1-1313: `apple-app-site-association` 을 `web/.well-known/` 으로 이전.
> - FE2-862: `robots.txt` 차단 목록에서 AI 크롤러 **Bytespider** 제거.
>
> ---
>
> 📅 **2026-07-31 master pull 보강** (28 커밋)
>
> 파일 업로드 저장소를 S3 전략으로 전환, 지지서명 레거시 v2 API 정리·community 전환, 글로벌 배송대행 서비스 종료(배너·약관·모델) 후속 정리가 핵심입니다.
>
> ### 파일 업로드 저장소 S3 전환 (RWD-5805, 16 커밋)
> - **신규 패키지 `com.wadiz.web.storage.upload`** — 저장 매체 분기를 `if`문에서 전략 인터페이스 `UploadStorage`(구현 `DiskUploadStorage`/`S3UploadStorage`)로 분리. `StoredFile`·`EncryptedStoredFile`·`EncryptedUploadStore`·`S3ObjectLocation`·`StoredPathParser`(+`UnknownStoredPathException`)·`UploadStorageConfig` 추가.
> - 공개 이미지·비공개 파일의 쓰기·읽기를 `s3` 모드에서 S3 저장소 경유로 전환(`FileService`, `FinanceFileService`, `CommunityFileService`, `MakerFileAdapter`, `FTFileService`). S3 자격증명은 설정 키로 받아 `StaticCredentialsProvider` 인증, 업로드 시 Content-Type 지정.
> - 다운로드 ZIP 생성 위치를 GlusterFS에서 OS 임시 디렉터리로 전환(`ZipDownloadView`), 정산 PDF 다운로드 S3 스트림 재읽기 오류를 `ByteArrayResource`로 수정. 호출처 없는 파일 쓰기 메서드·미주입 설정 키 삭제, 미사용 `FileDownload` 제거.
> - `file-*.properties` 7개 환경 일괄 갱신 — `serverName` 기본값 `wdz`, dev 레거시 업로드 저장소 s3 모드 전환, dev 공개 파일 URL을 CDN 도메인으로 변경.
>
> ### 지지서명 레거시 v2 API 정리·community 전환 (RWD-5834)
> - Live APM 실측에서 유입이 확인된 조회 API(count/list/keywords/user-images/comments)만 남기고 community(v3) 서비스로 전환. v2 응답은 신규 `SupporterSignatureV3Converter`로 기존 v1 계약을 유지하고, SSR은 community 서비스를 직접 호출. 잔존 `SupporterSignatureController`는 `@Deprecated` 표기.
> - 미사용 v2 핸들러·share 컨트롤러/서비스·v1 게이트웨이(`SupporterSignatureGateway` 855줄)·미사용 DTO 대량 삭제로 wave-user 지지서명 연결점 제거(총 −3,000여 줄). `CommentUIController`의 지지서명 관련 메서드도 정리.
>
> ### 콘텐츠 룰·1:1 문의 (RWD-5850)
> - content-rule 1:1 문의 콘텐츠 타입을 `PERSONAL_MESSAGE` → **`PERSONAL_MESSAGE_CLIENT`**로 변경(`ContentRuleContentType`, `PersonalMessageBoardService`). 2026-07-10 보강의 RWD-5731 항목에서 소개한 타입명이 이 커밋으로 바뀌었습니다.
>
> ### 글로벌 배송대행 서비스 종료 (RWD-5833 / FE2-848)
> - RWD-5833: 메이커 스튜디오 `GLOBAL_DELIVERY_AGENCY` 배너 제거(`RewardMakerStudio`, `RewardMakerStudioService`).
> - FE2-848: 글로벌 배송대행 서비스 이용약관 폐지 — `wterms.jsp` 목록에서 링크 제거, `global_shipping_forwarding.html`에 2026.07.01 폐지 노트 추가. `update-terms` 스킬에 약관/정책 폐지 모드 추가.
>
> ### 리워드·일정·발송
> - **리워드 제한수량 단위 유형별 상한 검증 추가** (RWD-5842) — 신규 `RewardItemValidator`(+테스트), `RewardRequest` 연동. 미사용 클래스 정리.
> - **일정 조회 응답에 일정 변경 마감 시각(`openScheduleModifyDeadline`) 필드 추가** (RWD-5860, `ScheduleInfo`, `CampaignScheduleServiceV2`, `CampaignScheduleSaveValidator`).
> - **펀딩 발송 단건 등록 시 집하 전 유효 송장(level 0 + result Y) 등록 허용** (SCOUT-123) — 스윗트래커 스펙 변경(집하 전 level 1→0) 대응. `TrackingInfoResponse`에 `result` 필드·`isRegisteredNotScanned()` 추가, `ShipmentController`가 배송준비중(`STAND_BY_TRANSIT`)으로 저장.
>
> ### 마이페이지·웹뷰 모달
> - **배송지 변경 노출 조건에 펀딩 진행상태(`endYn`) 게이트 복원** (FE1-1384, `myfundingPurchaseDetail.jsp`).
> - **`present=modal` 웹뷰 모달(`/modal`) 글로벌 번들 서빙 매핑 추가** + 로케일 리다이렉트 스킵 목록(`noRedirectList`)에 `/modal/**` 추가 (FE1-1239, `GlobalUIController`, `GlobalKoreaUIController`, `GlobalUrlMappingConfig`).
>
> ### 분석 영향
> - **파일 업로드 흐름**: 저장 매체 분기가 `UploadStorage` 전략으로 일원화되고 s3 모드가 도입됨. 파일 업로드/다운로드 관련 흐름 문서에 저장소 추상화 반영 후보.
> - **지지서명 흐름**: 레거시 v2 컨트롤러가 community(v3) 직접 호출로 축소되고 wave-user 연결점이 제거됨. 지지서명 관련 흐름 문서 보강 후보.

---

> 📅 **2026-07-21 master pull 보강** (약 25 커밋)
>
> 약관·정책 2026.07.21 개정, 도메인 `wadiz.co → wadiz.io` 로컬 프로퍼티 전환, 미사용 SEO JSP 정리가 핵심입니다.
>
> ### FE2-796 / CLIENT-172 — 약관·정책 개정 및 현행 페이지 문구 정비
> - **약관·정책 2026.07.21 개정 반영**(`web/resources/terms/` 다수 HTML). 리워드 심의정책·리워드 서비스 약관 신규 개정본 추가(`reward_screening_policy_20260630.html`, `service_reward_20260630.html`). `update-terms` 스킬에 취소선 삭제 처리·오탐 방지 규칙 보강.
> - CLIENT-172: 약관 현행 페이지의 오탈자·띄어쓰기·조사·문법·중복·개정 이력 중복 등 문구 교정 다수(내용 변경 아닌 표기 정정).
>
> ### FE1-1282 — 도메인 전환 및 앱 세션 keep-alive
> - 로컬 프로퍼티 `wadiz.co` 도메인을 **`wadiz.io`로 변경**. 앱 세션 keep-alive fetch 실패는 무시 처리.
>
> ### RWD-5808 / RWD-5813 / FE1-1112 — 기타
> - RWD-5808: 재제출 약정 처리를 funding agreement API 위임으로 변경하고 미사용 약정 코드 제거(funding 측 RWD-5808 도메인 분리와 연동).
> - RWD-5813: 자격요건 저장 시 수정 불가 예외를 `BadRequestException` 상속으로 400 응답.
> - FE1-1112: 국내/해외 통합 후 미사용 펀딩·스토어 상세 SEO JSP 8개 제거.
>
> ---
>
> 📅 **2026-04-26 master pull 보강** (23 커밋 fast-forward)
>
> ### 신규 추가 영역 (32 새 파일, +2,697 / −78)
> - **`reward/adapter/external/fundingapi/RewardChangeLogGateway`** — funding API 로 리워드 변경 이력 push (RWD-5462: 비노출/최종승인 알림)
> - **`reward/comment/model/`** 확장 — `MakerProjectCommentNewStatus`, `MakerProjectCommentSearch`, `MakerProjectCommentVo` (메이커 프로젝트 댓글 — 리뷰 + 포토 리뷰 통합 조회 RWD-5294)
> - **`reward/rewarditem/model/global/`** — `RewardBadge`, `RewardImage`, `RewardPricing` + Response DTO 글로벌 모델 추가 (해외 리워드 표준화)
> - **`reward/rewarditem/model/constant/`** — `BadgeType`, `DiscountType` (RWD-5374: 가격정책 원가 관리 삭제, ADD_ONLY → NO_DELETE 권한 변경)
> - **`reward/exception/ForbiddenException`**
> - **`reward/schedule/service/RewardDeliveryDateRangeCalculator`** (RWD-5362: 리워드 발송일 조회·저장·검증)
> - **`store/client/model/`** — `StoreContentResponse`, `StoreProductAggregationResponse`, `StoreProductInfoNoticeResponse`, `StoreProjectStatusCountsResponse`
> - **`common/wrapper/AppUserExceptionResponseWrapper`** — 앱 사용자 에러 응답 래퍼
> - **`.claude/commands/update-terms.md`** — 약관/정책 HTML 업데이트 슬래시 커맨드 (FE2-264)
> - 정책 HTML 신규 (`web/resources/terms/`):
>   - `funding_maker_service_20260403.html`
>   - `funding_refund_20250923.html`
>   - `service_reward_20251226.html`
>
> ### 변경된 주요 컨트롤러 (10개)
> - `WEBCampaignController.java` (+113/−51) — RWD-5487 본펀딩 상세 비공개 처리 제거 등
> - `StoreProjectUiController.java` — CLIENT-59 SEO/JSON-LD 추가
> - `MakerApiController` (reward), `RewardMakerStudioSubmitApiController`, `CampaignScheduleV2ApiController`, `RewardMakerStudioSectionV2ApiController`
> - `MakerDashboardController` (mywadiz/dashboard), `GlobalUIController`, `GlobalKoreaUIController`, `DiagnosisController`
>
> ### MyBatis SQL 변경
> - `reward/rewarditem/reward-mapper.xml` (+147줄) — 글로벌 reward 모델 응답 매핑 추가
> - `reward/comment/comment-mapper.xml` (+71줄) — 메이커 프로젝트 댓글 + 포토 리뷰 통합 쿼리
> - `reward/campaign/campaign-mapper.xml`, `maker/maker-mapper.xml`, `story/story-mapper.xml`, `comment/comment-image-mapper.xml` 소량 변경
>
> ### 삭제된 파일
> - `web/WEB-INF/jsp/campaign/detailSPA.jsp` — CLIENT-38 wRewardDetailSPA.java project 기반 SEO 시맨틱 HTML 로 대체
> - `src/main/java/com/wadiz/web/url/dto/BitlyResponseDto.java` — Bitly 단축 URL 의존 제거 (추정)
>
> ### 운영 변경
> - **RWD-5462** — 일정 > 오픈예정·본펀딩 즉시 오픈 기능 삭제
> - **RWD-5343** — Reward Pricing/Badge/Image History 적재 기능 삭제
> - **RWD-5483** — `file_service_api_host` URL 에 `/file` 경로 추가 (5개 환경 properties 일괄)
> - `web/robots.txt` — `/web/wcampaign/search` disallow 추가 (FE1-476)
>
> ### 분석 영향
> - **`docs/_flows/funding-detail.md`**: `WEBCampaignController#detail` 113줄 변경 — 비공개 분기 제거 등 동작 변경. 핵심 SQL 체인은 유지.
> - **`docs/_flows/comment.md`**: 메이커 프로젝트 댓글 + 포토 리뷰 통합 쿼리 추가. SQL 본문 일부 갱신 권장.
> - **`docs/_flows/store-detail.md`**: SEO/JSON-LD 추가 (CLIENT-59) — 시맨틱 HTML 향상.
> - **신규 `RewardChangeLogGateway`**: 리워드 수정 이력을 funding API 로 publish — funding 측 신규 endpoint 가능성. funding Phase 2 문서 보강 후보.

---

> 📅 **2026-07-10 master pull 보강** (2026-06-19 이후 ~150 커밋)
>
> 콘텐츠 룰(욕설·부적절 표현) 사전 차단 연동, 글로벌 상세/기획전 컨트롤러 도메인 분리 리팩토링, SEO canonical/noindex 정교화, Framer 랜딩 프록시(`/web/about`), 개인정보 처리방침 개정, 알리페이 부분환불 차단, 미사용 startup 화면 정리가 핵심입니다.
>
> ### 커뮤니티 콘텐츠 룰 사전 차단 (RWD-5712 / RWD-5731)
> - **신규 게이트웨이 `kr.wadiz.infrastructure.community.contentrule.*`** — `ContentRuleCommunityGateway`(community-api `POST /api/v1/content-rule/{contentType}/{userId}/evaluations` 호출) + `ContentRuleContentType` + `ContentRuleEvaluateDto`. 판정 `BLOCK` 이면 작성 거부.
> - **리워드 댓글** (RWD-5712): 응원/의견/체험리뷰 글·답글 및 새소식 댓글 작성·수정 시 **영속화 직전** 평가 후 `BLOCK` 이면 `kr.wadiz.community.exception.CommunityForbiddenException`(403)으로 `@Transactional` 롤백 (`web/reward/comment/service/CommentService.java`). 답글(depth=1)은 부모 글 타입 조회, 새소식(groupId=3)은 `NEWS_COMMENT`, 만족도·미상은 평가 제외. 평가 불가(transport/HTTP 오류)는 fail-closed(500).
> - **1:1 문의(개인 메시지)** (RWD-5731): `ContentRuleContentType.PERSONAL_MESSAGE` 추가. `PersonalMessageBoardService` 영속화 코어를 `doPostMessage` 로 분리, `postMessage`/`postImage` 진입점에서 1회씩 평가(중복 제거). 이미지는 파일 저장 전 빈 본문 평가(Redis fast-path)로 차단 사용자 파일·DB 미영속. 차단 시 컨트롤러가 "부적절한 내용이 포함되어 메시지를 보낼 수 없습니다." 노출 (`web/board/personalmessage/service/PersonalMessageBoardService.java:309`). **배포 의존성: community-api 의 해당 contentType 선배포 필요.**
>
> ### 글로벌/글로벌코리아 상세·기획전 컨트롤러 분리 (integrated-funding-detail, PR #10406 / CLIENT-173)
> - `GlobalUIController`(−221줄)·`GlobalKoreaUIController`·Store*UiController 의 상세/기획전/컬렉션/선물하기/스토어 매핑을 **도메인별 신규 컨트롤러로 분리** — `GlobalFundingDetailController`(214줄), `GlobalIntegratedExhibitionController`, `GlobalKoreaFundingDetailController`(226줄), `GlobalKoreaCollection/ServiceHome/StoreCollection/StoreDetail/StoreGiftController` 7종 (`GlobalKorea-` 접두사로 통일). URL 매핑은 신규 `web/fw/config/GlobalUrlMappingConfig.java` 로 집중.
> - 상세 SEO 마크업을 별도 JSP 조각으로 분리: `web/WEB-INF/jsp/global/detail-seo-head.jsp`·`detail-seo-body.jsp` (+ global-korea 동일). 하드코딩 메타 주입 베이스 클래스 `AbstractGlobalController` 제거, `LocaleRedirectService` 신설.
> - FE1-959 로그인 사용자 ETag 304 분기를 이 통합 컨트롤러(`GlobalFundingDetailController`)에도 이식.
>
> ### SEO canonical/noindex 정교화 (CLIENT-130 / CLIENT-154~156 / CLIENT-161 / CLIENT-173 / FE2-590)
> - **정책 페이지**(`wterms`): 이전 버전 경로에 `X-Robots-Tag` 헤더 + `noindex` 메타 주입, 효력상실 배너 노출, 개정 이력 링크 `nofollow`, 현행·이전 canonical 적용 (`web/WEB-INF/jsp/wlayout/wterms.jsp`). FE1-1167 로 이전 버전 배너 문구 분기.
> - **news 경로 canonical 을 부모 펀딩 상세로 통합** (`web/global/controller/GlobalFundingDetailController.java`, CLIENT-130).
> - **canonical fallback 을 자기참조 URL 로 변경** (`web/WEB-INF/jsp/global/index.jsp`, `winclude/mainHead.jsp`, CLIENT-161).
> - **JSON-LD publisher 를 와디즈 `Organization @id` 로 일원화**, global-korea index.jsp 에도 JSON-LD 추가 (FE2-590).
> - global-korea 상세·선물하기 메타 제목에 브랜드 접미사 추가 (CLIENT-173).
> - 네이버 EP(카탈로그피드) API URL 오류 수정 (`web/catalogfeed/controller/CatalogFeedController.java`, RWD-5760).
>
> ### Framer 랜딩 프록시 (FE1-635 / RWD-5752)
> - **신규 `com.wadiz.core.httpproxy.FramerProxyServlet`** + `FramerProxyProperties` — Framer 호스팅 랜딩을 프록시 서빙. `PKIX path building failed` 대응(TrustAllStrategy + NoopHostnameVerifier), 커넥션 eviction·재시도 핸들러 추가.
> - `/web/about`(+`/about`, `/ja/about`, `/zh/about`) 를 Framer 프록시로 매핑 (`web/WEB-INF/web.xml:217-226`). 기존 `WMainController#about`(JSP) 매핑 제거. (about2 로 실험 후 about 으로 전환)
>
> ### 약관/정책 개정
> - **개인정보 처리방침 개정 + 행태정보 처리 현황 페이지 신설** (FE1-1089) — `web/resources/terms/privacy.html` 개정, `privacy_20260120.html`(이전본), `privacy_behavioral_information.html`(+`.jsp`) 추가, `WWEBTermsController` +203줄.
> - 후원 관련 약관·후원 정의 수정(FE2-654), 메이커 이용약관 `funding_maker_service_20260616.html`, 리워드 심사정책 `reward_screening_policy_20260602.html`, `service_reward_20260421.html` 신규.
>
> ### 결제·정산·환불
> - **알리페이 부분환불 미지원** (RWD-5768) — `NotAllowedAlipayPartialRefundException` 신규, `BackingPaymentRefundService` 에서 알리페이 부분환불 차단 + 에러 코드 추가. currency 지정 일원화(RWD-5674).
> - **nicepay subpath 분기** (RWD-5784) — `reward/payment/api/PaymentApiSupport.java` + `file-*.properties` 5개 환경 일괄.
> - **선정산 비율 카테고리 분기 제거 → 60% 통일** (`reward/settlement/service/CampaignSettlementService.java`, RWD-5777).
>
> ### 사후심사·메이커 스튜디오
> - **요금제 재판단 후 서비스 요금 상태 변경** (RWD-5675) — `RewardMakerStudioSectionApiController` + `RewardMakerStudioRequirementSectionService`. 프로젝트 정보 저장 시 카테고리 변경 감지→슬랙 알림, funding-api 로 요금제 변경 push(`PlanChangeNotifier`, `PlanChangeNotificationRequest`, `PricingSyncResult` 신규).
> - **사후심사 재제출 시 `RevivalHistory` 기록**(최근 피드백 TransactionNo 포함) + 사후심사 enum 정리, 제출 시 `CampaignMarker` 제거 (RWD-5740, `RewardMakerStudioSubmitService`).
>
> ### 미사용 startup 화면 정리 (FE-11444 / FE-11445 / FE-11446)
> - `wStartupRequestingAdministrator.jsp`·`wRedirectAppStartupDetail.jsp` + `WStartupMainController` 의 `/registration/administrator`·`/detail/preview` 매핑 삭제, 유일 호출자 사라진 `CorporationAdminRequestApiController` 제거.
> - `/web/wstartup/maker/registration` → `/web/maker/registration` urlrewrite 302 redirect 이관.
>
> ### 따라잡기(catch-up) V3 (BE3-464)
> - **신규 `kr.wadiz.catchup.*` 헥사고날 패키지** — `APICatchUpV3Delegate` + `CatchUpActionGateway`/`CatchUpServiceV2`/`CatchUpActionOrchestrator`. 액션 country 를 요청 헤더에서 추출해 funding 전달, funding 응답 body status 검사(HTTP 200 + envelope 4xx 대응).
>
> ### 인프라/기타
> - **Docker 이미지 정비** — `docker/Dockerfile`·`entrypoint.sh`·`push-to-ecr.sh`·redisson.yml 도입. 톰캣 Connector `URIEncoding=UTF-8`(CM2-183), `.well-known` context path 추가(RWD-5772), `/mnt/data` 정적 파일 서빙 context(CM2-186, images/ft#images/wwwwadiz).
> - 마이와디즈 메인 경로를 로그인 인터셉터 제외에 추가 (QA-22413, `spring/dispatcher/interceptor.xml`).
> - 펀딩 참여 상세 **취소·실패 시 배송지 정보 미노출** (FE1-973, `web/wmypage/controller/WMyFundingController.java`).
> - 1:1 상담 조회 기간 **5년 → 3년** 제한(전자상거래법 보유기간 근거, 데이터 파기 아닌 조회 제한, RWD-5771).
> - 스쿨 신청 완료 브레이즈 이벤트에 PD컨설팅 포함 여부(`has_consulting`) 속성 추가 (RWD-5723).
>
> ### 분석 영향
> - **글로벌 흐름 문서**: `GlobalUIController` 단일 컨트롤러 가정이 깨짐 — 상세/기획전/스토어가 도메인별 컨트롤러로 분리됨. 6장·4.1 URL 표의 global/globalkorea 항목 컨트롤러 경로 갱신 후보.
> - **커뮤니티 흐름**: 댓글·1:1 메시지에 community content-rule 사전 차단 게이트가 삽입됨(fail-closed). `docs/_flows/comment.md` 보강 후보.
> - **`docs/_flows/funding-detail.md`**: about 페이지가 JSP → Framer 프록시로 전환.
>
> ---
>
> 📅 **2026-06-18 master pull 보강** (205 커밋 / +8,790 −3,481, 256 파일)
>
> SEO(sitemap/robots/메타데이터) 동적화와 펀딩 상세 캐시 정합성, 글로벌 Stripe 정산·달러 결제, 사후심사 권한 보강이 핵심입니다.
>
> ### 펀딩 상세 캐시 정합성 (FE1-959)
> - `WEBCampaignController#selectCampaign` 의 304 처리를 **로그인 사용자에 한해 ETag 기반**으로 변경 (`WEBCampaignController.java:106-122`). ETag 소스는 `lastModified:userId:성인인증상태` 를 MD5 해시한 값. 본문에 로그인·성인인증 상태가 SSR 되므로, 콘텐츠 시간만으로 304 를 주면 **다른 사용자 상태가 캐시되어 노출되는 인증 sync 갭** 이 발생하던 문제 해소.
> - 비로그인(봇 포함)은 사용자 무관 본문이므로 기존 `Last-Modified` 경로 유지 → SEO 304 보존.
> - `DefaultInterceptor` 에서 전역 `ADULT_VERIFICATION` request attribute 주입 제거 (`DefaultInterceptor.java:158-161` 삭제). 성인인증 상태 조회 책임을 펀딩 상세 컨트롤러로 이전 — 미사용 성인인증 ETag 축·전역 렌더 제거.
>
> ### SEO 동적화 (CLIENT-86 / CLIENT-104 / CLIENT-53 / CLIENT-133)
> - **신규 패키지 `com.wadiz.web.seo`** — sitemap 전용. `SeoSitemapController`(144줄) + `SitemapSearcherGateway`(searcher 페이징 순회 수집) + `SitemapXmlBuilder`(urlset 렌더).
>   - 정적 `sitemap.xml`(index)·`sitemap-static.xml` 은 `web/` 의 정적 템플릿을 읽어 **현재 환경 도메인으로 치환**해 서빙 (1회 치환 후 `ConcurrentHashMap` 캐시).
>   - 동적 `sitemap-funding.xml`·오픈예정·스토어 는 searcher 목록으로 렌더하고 결과를 **ehcache `sitemapXml` 캐시**에 저장(목록이 아닌 **렌더된 XML 문자열** 캐시로 변경). 펀딩·오픈예정 sitemap 엔트리에 글로벌 hreflang + 언어 변형 4개를 각각 url 엔트리로 등록.
>   - 신규 정적 파일: `web/sitemap-static.xml`, `web/sitemap.xsl`. `web/sitemap.xml` 은 index 구조로 전환(531 → 대폭 축소). (CLIENT-86)
> - **robots-noindex 앱 설정 조회** (CLIENT-104) — `AppSettingsRobotsNoIndex` 모델 + `AppSettingsService.getAppSettingsRobotsNoIndex()` (인메모리 **TTL 5분 캐시**, 실패 시 직전 캐시 유지). app-api 의 `web-server`/`robots-noindex` feature 설정에서 `corpNos`·`fundingProjectNos` 를 읽어 `DefaultInterceptor` 가 모델로 주입 → `robotsNoindex.jsp`(campaign/makerprofile) 가 `campaignId` 매칭 시 `<meta name="robots" content="noindex">` 출력. 비노출 목록을 JSP 하드코딩에서 모델 주입 값으로 전환.
> - **정적 페이지 메타데이터 시트화** (CLIENT-53) — `GlobalKoreaUIController` 등의 하드코딩 `og/twitter/title/description` 을 제거하고 `html-metadata*.properties` 시트 기반 동적 메타데이터로 전환(`about_slogan_innovation_begins_page.meta.*` 등). 부수적으로 `AppSettingsService` 를 `settings` → **`app.service` 패키지로 이동**.
> - **robots.txt** (CLIENT-133) — 인증/개인화 신규 SPA 경로 대량 disallow 추가(`/web/wish`, `/wish`, `/my-wadiz/`, `/studio/`, `/notifications`, `/social/friends`, `/refer-a-friend`, `/create-project`, `/maker/*` 등), Sitemap 지시문 유지.
>
> ### 약관/정책 HTML (FE2-498 / FE2-539 / FE2-426 / FE2-454)
> - 수수료 반환 범위 변경에 따른 **선정산 서비스 이용약관**(`early_payout_20260430.html`) + **메이커 이용약관**(`funding_maker_service_20260522.html`, 1,268줄) 개정 (FE2-498/539, Stripe connect 정산·환불 정책 반영).
> - 신규/개정 정책 HTML: `funding_report_20250930.html`(상품정보제공고시), `property_20230829.html`, `reward_screening_policy_20260413.html`(리워드 심사 정책), `ad_review_20240530.html`.
> - **지식재산권 보호 정책 폐지** — 심사/신고/광고심사 정책 목록에서 제거 (FE2-426/454).
>
> ### 글로벌 Stripe 정산·달러 결제 (RWD-5285 / RWD-5375 / RWD-5661)
> - **`StripeFundingGateway`**(140줄) + Stripe Account/Person/BankAccount/Payout 응답 모델 + `CreateStripeAccount(Link)Request`. 정산정보(`CampaignContractorService`, `settlement`)에 Stripe Connect / PayoutMethod(`PayoutMethodType`, `CampaignPayoutMethodRepository`) 도입 — intro/임시저장 분기, Stripe Account·세금계산서 email 까지 확인 후 정산 상태 판단.
> - **달러 결제/환불·달러 쿠폰** — `BackingPaymentFx`(환율 적용 결제) + `CurrencyExchangeClient`/`ExchangeRateConvert(Request|Response)` 로 환전 서버 연동, `ServiceType.GLOBAL_STRIPE` 추가, 쿠폰 다운로드/조회 v2 분기(국가·환율 기준). `payment-fx-mapper.xml` 신규.
> - 국가 통관정보 필요 여부 유형 세분화 — `CustomsInfoRequiredType` (RWD-5621).
>
> ### 사후심사·메이커 스튜디오 (RWD-5514 / RWD-5609 / RWD-5706)
> - **추가질문(QnA) v2 API** — `MakerCommunicationAddQuestionV2Controller`(80줄), `MakerMessage`/`QnAFile`/`QnAFileMapping` 모델, 첨부파일 업로드, 사후심사 재제출(`SectionStatus.REVIVAL_APPLY_FEEDBACK`), 피드백 reset. v1 deprecated, `SectionType` enum 을 funding-core 로 이관.
> - 사후심사 제출 시 Adm 수정 항목 제어용 **`CampaignMarker` 저장/신규 MarkerId** 추가, 정보 피드백 시 수정 권한 체크(메이커정보 권한 ALL 로 변경) (RWD-5609/5706).
>
> ### 본인인증·계정
> - **성인인증 자가증명 앱 v3 PUT API** (BE3-488) — `APIAccountV3Delegate#updateAdultVerification` (`PUT /v3/account/adult-verification/my`). **글로벌(비KR) 전용** — 국내는 NICE ID 인증 필요로 거부, `ageConfirmed` 필수.
> - 대표자 본인인증 필요 유무 판단 API 수정 (RWD-5710).
> - **암복호화 추상화 레이어** — `com.wadiz.core.crypto.*`(CryptoApiClient/CryptoHelper/DamoTextCryptor 등) 신규, crypto-api 연동 (RWD-5415).
>
> ### 운영/기타
> - **스쿨 신청 폼** offline·컨설팅 유형 추가 + 미사용 코드 정리 (RWD-5600).
> - 펀딩 진행 중 **배송지 변경·배송 상태 노출** 허용 (FE1-788).
> - 지지서명 트래킹을 커뮤니티 신규 API(`SignatureTrackingClient`, `SupporterSignatureV3UserCommunityGateway`)로 교체 (RWD-5548).
> - `file_service_api_host` properties 갱신, 메일 푸터 로고 링크 `wadiz.ai → wadiz.kr`(BE3-496), 정산 스케줄 NPE 방어·역직렬화 수정(SCOUT-72), 정산정보 계약정보 복호화 후 검증(RWD-5692).
>
> ### 분석 영향
> - **`docs/_flows/funding-detail.md`**: 304/캐시 로직이 로그인 사용자 ETag 분기로 변경 — sync 갭 설명 반영 필요.
> - **신규 SEO 흐름**: `/sitemap*.xml` 동적 서빙 + robots-noindex 가 컨트롤러/인터셉터로 이동. 4.1 URL 표·6장에 SEO 섹션 보강 후보.

---

## 1. 개요

`com.wadiz.web` 는 와디즈 본체 웹을 구성하는 Spring 3.2 + JSP 레거시 WAR 프로젝트입니다. **운영 기준은 클라우드(`clive`)이고 주소는 `https://www.wadiz.io` 입니다**(`src/main/resources/properties/file-clive.properties` 의 `site_url`). 온프레미스 `real` 환경은 `https://www.wadiz.kr` 로 남아 있습니다. 리워드/투자(증권형) 펀딩 상세·청약·결제·마이페이지·커뮤니티 등 **와디즈 유저 사이드 거의 전 기능을 담고 있는 모놀리식 웹 서버**입니다.

- 브랜치 전략 — **저장소 `README.md` 는 낡았습니다.** 거기에는 `dev` → `dev.wadiz.kr`, `rc` → `stg.wadiz.kr`, `master` → `www.wadiz.kr` 로 적혀 있습니다.
  실제 운영은 **`cloud_live` 브랜치와 `clive` 환경**입니다. 환경별 주소는 `src/main/resources/properties/file-{env}.properties` 가 정본입니다.

  | 환경 | `site_url` | `static_host` |
  |---|---|---|
  | **`clive`**(운영) | `https://www.wadiz.io` | `https://cdn-static.wadiz.io` |
  | `real`(온프레미스) | `https://www.wadiz.kr` | `https://static.wadiz.kr` |
  | `dev` | — | `https://cdn-static.dev.wadiz.io` |

  > ⚠️ `README.md` 는 EUC-KR 로 저장돼 있어 UTF-8 환경에서 한글이 깨집니다. **원본 저장소라 고치지 않고 여기 기록만 남깁니다.**
- Tomcat 서블릿 2.5 기반(`web/WEB-INF/web.xml:4`), `urlrewrite3.0` 필터로 레거시 URL을 신규 URL로 리다이렉트.
- `.frontend/` 에 별도 Node 워크스페이스가 존재하며, 일부 화면(iam, floating-buttons, personal-message, school, embed 등)은 정적 호스트(clive 는 `cdn-static.wadiz.io`)에서 받아 오는 React 번들입니다. 종전에 적혀 있던 `open-account` 청크는 지금 없습니다. `static-dev.wadiz.kr / static.wadiz.kr` 에 배포되는 React 번들을 JSP가 얇게 껴서 불러오는 **SPA 쉘 JSP** 구조입니다 (`com.wadiz.web/.frontend/chunks.config.js:1`, `web/WEB-INF/jsp/react/entries/iam.jsp:29-33`).
- 이미 이관 완료된 화면: React 앱으로 재개발된 iam(로그인/회원가입), open-account, floating-buttons, iam, school, personal-message, 일부 landing(about, wadiz2017, partners 등). 또한 `/studio/reward/**` 로 리다이렉트되는 스튜디오(`web/WEB-INF/urlrewrite.xml:53-54, 227-232`) 및 `makercenter.wadiz.kr` / `helpcenter.wadiz.kr` 로 완전 이관된 커뮤니티·헬프센터(`web/WEB-INF/urlrewrite.xml:112-130, 189-191`).
- 아직 JSP 로 직접 렌더링하는 핵심 영역: **증권형 청약**(`/web/wpayment/equity/*`), **이벤트 기획전**(`/web/wevent/**`), **wpartner**, **wiplicense**, **글로벌 커뮤니티**.
- SNS 공유·봇 크롤링용 서버 사이드 OG/JSON-LD 생성은 **펀딩 상세에서는 더 이상 JSP 가 하지 않습니다.** `CLIENT-238`(2026-09-03)로 상세 JSP 가 사라지고 `GlobalKoreaFundingDetailController` 가 맡습니다. 남은 영역의 JSP 는 여전히 직접 생성합니다.
- 커밋 활동도는 저장소 자체에 .git 이 없어 간접 추정이 필요한데, jasypt / funding-core 1.0.137-SNAPSHOT / reward-http-client 0.4.10-SNAPSHOT / payment-log-client / ksd-client 등 자체 마이크로서비스 클라이언트 의존성은 계속 bumping 되고 있어 **"코드는 동결 안 했지만 화면은 React 로 뽑아내는 중"** 이라는 이관 중간상태입니다.

규모 지표 (기준: Java `*Controller.java` + mapper + JSP):

| 항목 | 수 |
|------|---:|
| Controller 클래스 (`*Controller.java`) | 303 |
| Service 클래스 (`*Service*.java`) | 447 |
| Mapper/Dao (`*Mapper.java` / `*Dao.java`) | 658 |
| MyBatis mapper XML (`src/main/resources/sqls/**`) | 264 |
| JSP (`web/WEB-INF/jsp/**`) | 122 (상위 그룹만 — 서브디렉토리 포함 시 수백 건) |
| Stored procedure 정의 (`src/main/resources/sp/*.sql`) | 20 |

---

## 2. 기술 스택

`pom.xml` (참고: `com.wadiz.web/pom.xml`)

- JDK 1.8 (`pom.xml:11`), Maven WAR, `mvnw` wrapper 동봉.
- **Spring 3.2.10.RELEASE** (MVC + Security 3.2.5 + context/tx/webmvc). Spring Webflux 5.3.10 일부 병용 (`pom.xml:896-900`).
- Spring Boot starter 1.1.4 (단순 스타터만; 부트 런타임 아님).
- MyBatis 3.2.7 / mybatis-spring 1.2.2 / MySQL connector 5.1.48.
- JSP + JSTL 1.2 + **kwonnam jsp-template-inheritance 0.3** (레이아웃 상속: `layout:extends`, `layout:put`), custom TLD `functions.tld` (`https://wadiz.kr/tld/functions`) — `WadizCDNUtil.cdnURL*`, `StringUtil.escapeJson/escapeXml/convertToLinkFromURL` 등 JSP 커스텀 함수.
- Jersey 1.13 + Spring Servlet — `/api/*` JSON REST 엔드포인트 (legacy RESTful layer). `web.xml:158-193` 의 `Jersey Spring Servlet` 에 `com.wadiz.api.*` 16개 패키지 스캔.
- Smiley HTTP proxy servlet (`/web/apip/*` → main API, `/web/maker-proxy/*` → 메이커 API) — `web/WEB-INF/web.xml:195-213` 및 `com.wadiz.core.httpproxy.ApiProxyServlet`.
- URL rewrite: **tuckey urlrewritefilter 3.1.0** — 459라인 규칙 (`web/WEB-INF/urlrewrite.xml`).
- 외부 클라이언트 라이브러리: `com.wadiz.wave wave-client/wave-data/wave-crypto`, `wave.notification notification-client`, `wave.pay pay-client`, `wave.point point-client`, `api.reward reward-http-client`, `api.equity equity-http-client`, `api.main main-client`, `api startup-client`, `api payment-log-client`, `api.ksd ksd-client`, `funding.core funding-core` — 전부 wadiz 내부 SNAPSHOT.
- 결제/인증 SDK: `nicepay-lite 0.9.24`, `inicis inipay 5.0`, `ExecureCrypto`, `KSFCclient`(한국증권금융 증권형), `NiceID.Check`.
- 기타: ehcache 2.10.6, jasypt-spring31 1.9.2 (`encKey=!wadiz@` 프로퍼티 암복호화 키, `pom.xml:14`), jjwt 0.10.7 + nimbus-jose-jwt 9.31, bouncycastle 1.60 (Apple Sign In), googlecode/libphonenumber 8.12.57, emoji-java 5.1.1, jsoup 1.7.2, scala-library 2.10.4 (이상한 혼종 의존성), Spring mobile-device 1.1.3 (디바이스 감지).
- Swagger: `springfox-swagger2` 2.6.1 (UI 포함).
- 프런트 번들: webpack(4.x, `optionalDependencies`) 로 `.frontend` 워크스페이스 빌드 후 정적 호스트에 업로드. **clive 는 `cdn-static.wadiz.io`**, 온프레미스 real 은 `static.wadiz.kr` 입니다. 구성: `.frontend/chunks.config.js` 에서 web/main/account/equity/reward/iam/personal-message/school/open-account/floating-buttons/landing/embed/sentry 청크 정의.

**Maven 프로파일**: local(기본)/dev/dev2/rc/rc2/stage/vqa1/real — WAR 빌드시 `classpath:*-${environment}.xml` 형태로 환경별 스프링 구성 로드 (`pom.xml:20-55`).

---

## 3. 아키텍처

### 3.1 배포/런타임 구조
Tomcat 위 WAR. `DispatcherServlet` 이 `/` 전역을 잡고, `Jersey Spring Servlet` 은 `/api/*`, `ApiProxyServlet`/`MakerApiProxyServlet` 가 `/web/apip/*` / `/web/maker-proxy/*` 를 잡습니다 (`web/WEB-INF/web.xml:141-213`).

### 3.2 필터 체인 (web.xml 순서)
1. `encodingFilter` (UTF-8 force)
2. `GlobalHeaderModifyingFilter` (`com.wadiz.api.fw.filter.GlobalHeaderModifyingFilter`)
3. `APIFilter` (`/api/*`)
4. `CJCookieServletFilter` — CJ Cookie 추적
5. `UrlRewriteFilter` (tuckey, 459 rules)
6. `CORSFilter` (`com.wadiz.web.fw.filter.CORSFilter`)
7. `XssEscapeServletFilter` — `xss/xss-servlet-filter-rule.xml` 기반
8. `oauth2LoginFilter` / `oauth2RedirectFilter` — Spring DelegatingFilterProxy → OAuth2 소셜로그인
9. `bearerTokenAuthenticationFilter` — `/web/v1/maker/*`, `/web/v2/membership`, `/web/apip/funding/supporters/my/fundings`, `/web/apip/store/orders/*` 에만 Bearer JWT 인증 적용 (`web.xml:117-129`)
10. `autoLoginFilter` — rememberMe/자동 로그인

이 다단계 필터 구성은 **"세션 기반 로그인 + 일부 API 만 Bearer token"** 하이브리드 인증 특징.

### 3.3 DispatcherServlet 구성 (`src/main/resources/spring/dispatcher/servlet.xml`)
- Component scan 타겟: `com.wadiz.web, kr.wadiz` (Controller/ControllerAdvice) + `com.wadiz.core` (Repository).
- 네 개의 커스텀 `HandlerMethodArgumentResolver`: `DeviceWebArgumentResolver`(mobile-device), `DeviceTypeResolver`, `ServiceRegionCookieValueResolver`, `ServiceRegionHeaderResolver` — i18n / 디바이스 / 서비스 리전 분기 주입.
- 두 개의 ViewResolver 체인: `ContentNegotiatingViewResolver`(order=1, JSON 전용) → `BeanNameViewResolver`(order=0, download 뷰들) → `InternalResourceViewResolver` → `/WEB-INF/jsp/*.jsp` (order=2).
- AOP: `RequiredCertifyAspect`(본인인증 필수 가드), `RecaptchaAspect`, `EncryptAspect`(프로퍼티/DTO 복호화).
- 다운로드용 뷰 빈 4종: `download`(FileDownload), `downloadExcel`, `downloadFile`(DownloadView), `downloadZip`(ZipDownloadView), `financeDownloadFile`(증권형 전용), `makerDownloadFile`.
- `SuffixPatternDisabler` — Spring 3.2 기본 동작인 `.json/.xml` suffix pattern matching 끄는 BeanPostProcessor (수동 ajax 엔드포인트 충돌 회피).
- Multipart: `WadizCommonsMultipartResolver` (자체 래퍼).

### 3.4 애플리케이션 ContextConfig (`web/WEB-INF/web.xml:221-239`)
환경별 로드되는 XML 14개: `proxy/proxy-${env}.xml`, `point-${env}.xml`, `reward-${env}.xml`, `equity-${env}.xml`, `user-${env}.xml`, `pay-${env}.xml`, `main-${env}.xml`, `root-context.xml`, `datasource-context.xml`, `searcher-${env}.xml`, `startup-${env}.xml`, `payment-log-${env}.xml`, `ksd-${env}.xml`, `cache-${env}.xml`, `message/notification-${env}.xml`.

각 XML 은 해당 도메인의 wave/api client Bean 을 환경별 호스트로 초기화하는 용도.

### 3.5 Java 패키지 최상위

`com/wadiz/` 하위:
- `api/*` — Jersey REST 엔드포인트 (20+ 도메인: account, app, campaign, ftaccount, ftcampaign, login, notification, waccount, wcampaign, wcode, wmain, wmypage, wpoint, store, startupApp, membership, social, error, fw, signature, session2token, signature)
- `core/*` — 도메인 서비스/DAO 계층. campaign, account, progress, reward(screening/settlement/coupon/comingsoon/refund/comment), equity, waccount, wmain, wcampaign, wpartner, wsub, statistics, notification, payment 등 86 서브패키지.
- `web/*` — Spring MVC 컨트롤러 + web-layer 서비스/DTO. 80+ 서브패키지. 대표: `campaign`, `wcampaign`, `wmain`, `wmypage`, `wpayment`, `wpurchase`, `waccount`, `login`, `mywadiz`, `supporter`, `supporterclub`, `storage`, `store`, `wiplicense`, `wevent`, `wboard`, `wpartner`, `wcomingsoon`, `ftexauth`, `redirect`, `reward/*`, `equity/*`, `marketing`, `newsletter`, `popup`, `maker`, `global`, `globalkorea`.
- `kr/wadiz/*` — 일부 신규 모듈(`kr.wadiz.infrastructure.signature.v3` 등). Component-scan 대상으로 포함 (`servlet.xml:29`).

### 3.6 외부 통신 패턴
- **API Gateway 프록시**: `/web/apip/*` → `ApiProxyServlet` → 내부 main-api(funding-api). 프런트 JS 가 `/web/apip/funding/...` 을 치면 서버가 세션 쿠키를 붙여 백엔드로 포워딩.
- **Maker API 프록시**: `/web/maker-proxy/*` → studio/maker BFF.
- `GlobalFundingGateway`(`com.wadiz.web.reward.adapter.external.fundingapi`) — `WebClient` 로 funding-api 직접 호출 (상세, AI 요약, 스토리, 상품정보 고시 등).

---

## 4. 페이지·URL 구조

URL은 대부분 `/web/*` 접두어(과거 `/ko/Campaign/Details/*` 호환성 유지). `@RequestMapping` 은 class-level + method-level 혼합.

### 4.1 URL prefix 요약표

| URL prefix | 용도 | 대표 Controller (path) | JSP 경로 |
|---|---|---|---|
| `/web/main`, `/web/wmain` | 통합 메인 (리워드 기본, 메인·얼리버드·플랜드·마이·모어) | `web/wmain/controller/WMainController.java:86` | `wmain/main.jsp` |
| `/web/winvest/main`, `/web/wmain/main` | 투자(증권형) 메인 | `web/wmain/controller/WInvestMainController.java` | **JSP 없음** — `wmain/wmain.jsp` 는 `CLIENT-239`(2026-09-04)로 삭제 |
| `/web/wreward/main`, `/web/wreward/collection/*` | 리워드 메인/컬렉션 | `web/wmain/controller/WRewardMainController.java` | `wmain/wreward/*.jsp` |
| `/web/campaign/detail/{id}`, `/detail/reward-info/{id}`, `/detail/qa/{id}`, `/detail/fundingInfo/{id}`, `/detailPost/{id}`, `/detailBacker/{id}` | 리워드 펀딩 상세 | **`web/globalkorea/controller/GlobalKoreaFundingDetailController.java:68`** | **`global-korea/index`**(React 셸). 종전 `detail*SPA` JSP 는 `CLIENT-238` 로 삭제 |
| `/web/wcampaign/*` | 캠페인 검색/지지서명/리워드서명 | `web/wcampaign/controller/WSearchCampaignController.java:42`, `WWEBCampaignSignatureController.java:15`, `WWEBRewardSignatureController.java:24`, `WWEBInvestSignatureController.java:24` | `wcampaign/*.jsp` |
| `/web/wpayment/*` | 리워드 결제 관련 **AJAX·JSON 전용** | `web/wpayment/controller/WPaymentController.java` | **JSP 없음.** 약관·에러·완료 지면 JSP 는 모두 삭제 |
| `/web/wpayment/equity/*` | 증권형 청약 결제 | `web/wpayment/controller/WPaymentEquityController.java` | `wpayment/equity/*.jsp` |
| `/web/wpurchase/*` | 리워드 결제(신 플로우) | `web/wpurchase/controller/WEBPaymentController.java` | (주로 JSON) |
| `/web/account/login`, `/web/account/my`, `/web/waccount/*` | 로그인/회원가입/마이(일반/투자/마케팅/드롭아웃) | `web/waccount/controller/WAccountRegistController.java:72`, `WAccountMyController.java:36`, `WAccountSocialController.java`, `WAccountEquityController.java`, `WAccountPlusController.java` 등 17개 | `waccount/*.jsp`, `winclude/*.jsp` |
| `/web/mywadiz/*` | 마이페이지(신버전, 리워드 결제내역/참여) | `web/mywadiz/**/controller/*.java` | `mywadiz/*.jsp` |
| `/web/wmypage/*` | 마이페이지(구버전, 지금은 구 URL은 대부분 redirect) | `web/wmypage/controller/*` | `wmypage/*.jsp` |
| `/web/wevent/{id}`, `/web/wevent/{slug}` | 통합 이벤트/기획전 | `web/wevent/controller/WWEBEventMainController.java` | `wevent/*.jsp` |
| `/web/wcomingsoon/*`, `/web/wreward/comingsoon/*` | 오픈예정 | `web/wcomingsoon/controller/WComingsoonController.java`, `WRewardComingSoonController.java` | `wcoming/*.jsp` |
| `/web/wpartner/detail/{slug}` | 파트너 상세 (외부 /partner/{slug} redirect 대상) | `web/wpartner/controller/*` | `wpartner/*.jsp` |
| `/web/wboard/*` | 지지서명 게시판 | `web/wboard/controller/*` | `wboard/*.jsp` |
| `/web/wcommunity/*`, `/web/ftcommunity/*`, `/web/wcast/*` | (전량 `makercenter.wadiz.kr` 로 301 redirect) | urlrewrite only | — |
| `/web/fthelpCenter/*` | (`helpcenter.wadiz.kr` 로 301 redirect) | urlrewrite only | — |
| `/web/oauth/*`, `/web/login/*` | 소셜로그인(페이스북/카카오/네이버/애플/구글/라인) + 자체 로그인 | `web/login/*`, `web/oauth/*` 및 `oauth2LoginFilter` | `login/*.jsp` |
| `/web/v1/maker/*` | 메이커 BFF (Bearer 토큰) | `web/maker/**/controller/*.java` | JSON |
| `/web/v2/membership/*` | 프리미엄 멤버십 (Bearer 토큰) | `web/membership/controller/*` | JSON |
| `/web/marketing/*`, `/web/marketing/checkUnsubscribeKey/*` | 마케팅 수신거부 | `web/marketing/controller/*` | `marketing/*.jsp` |
| `/web/newsletter/*`, `/web/main/maker/subscribe` | 메이커 뉴스레터 | `web/newsletter/controller/*`, `WMainController.java:198` | `newsletter/*.jsp` |
| `/web/wiplicense/*` | IP 라이선스 파트너(빙그레/디즈니/넥슨 등) | `web/wiplicense/controller/IPLicenseController.java` | `wiplicense/*.jsp`, `wiplicense/fanzmaker/*.jsp` |
| `/web/wlive/*` | 와디즈 라이브 | `web/wlive/controller/*` | `wlive/main.jsp` |
| `/web/wsub/*` | 서브 페이지(Easy Card, 메이커 가이드 등) | `web/wsub/controller/WSubController.java` | `wsub/*.jsp` |
| `/web/embed/*` | 임베드 위젯 | `web/embed/controller/EmbedController.java` | `embed/*.jsp` |
| `/web/global/*`, `/web/globalkorea/*` | 글로벌 크라우드펀딩(WEN) | `web/global/controller/GlobalUIController.java`, `GlobalKoreaUIController.java` | `global/*.jsp`, `global-korea/*.jsp` |
| `/web/school/*` | (구) 와디즈 스쿨 — 리다이렉트 대상 | `web/school/**` | `school/*.jsp` (레거시) |
| `/web/redirect/hashkey/*`, `/web/redirect/keyword/*` | 단축 URL 리다이렉트 | `web/redirect/controller/*` | — |
| `/web/wterms/*`, `/web/waccount/wAccountLogin` 등 | 약관/계약/본인인증 | `web/wterms/*`, `web/waccount/*` | `wterms/*.jsp` |
| `/web/diagnosis/ping` | 헬스체크 | `web/diagnosis/controller/DiagnosisController.java` | JSON |
| `/sitemap.xml`, `/sitemap-static.xml`, `/sitemap-funding.xml`(+오픈예정·스토어) | SEO sitemap (정적은 도메인 치환, 동적은 searcher 렌더 + ehcache 캐시) | `web/seo/controller/SeoSitemapController.java` | XML |
| `/api/*` | (Jersey) account/campaign/ftcampaign/login/notification/waccount/wcampaign/wcode/wmain/wmypage/wpoint/store/startupApp/membership/social | `com.wadiz.api.**` | JSON |
| `/web/apip/*` | 외부 API 프록시 (main-api / funding-api) | `com.wadiz.core.httpproxy.ApiProxyServlet` | JSON |
| `/web/maker-proxy/*` | maker-api 프록시 (스튜디오 SPA 용) | `com.wadiz.core.httpproxy.MakerApiProxyServlet` | JSON |
| `/resources/**`, `/wwwwadiz/**`, `/favicon.ico` | 정적 | mvc:resources | — |

### 4.2 JSP 최상위 그룹 (`web/WEB-INF/jsp/*`)

**2026-09-22 확인 40개 · JSP 파일 260개**입니다.

`account`, `campaign`, `catchup`, `community`, `embed`, `equity`, `error`, `ftexautn`, `funding2015`, `global`, `global-account`, `global-korea`, `include`, `linkprice`, `makerprofile`, `mobile`, `mywadiz`, `oauth`, `personalverification`, `react`, `school`, **`studio`**, `startup`, `video`, `waccount`, `wboard`, `wevent`, `winclude`, `wiplicense`, `wlayout`, `wlive`, `wmain`, `wmypage`, `wpage`, `wpartner`, `wpayment`, `wpersonalmessage`, `wpurchase`, `wsub`, `wterms`

> ⚠️ **네 그룹이 사라졌습니다** — `supporterclub`, `wcampaign`, `wcoming`, `wpremium`.
> `studio` 가 새로 생겼습니다.

주요 그룹의 현재 상태입니다.

| 그룹 | 지금 무엇이 남았나 |
|---|---|
| `wpayment/` | **`equity/` 하위만 남았습니다.** 리워드 결제 JSP 는 전부 사라졌습니다 |
| `campaign/` | **`include/` 하위만 남았습니다.** `detail*SPA.jsp` 는 `CLIENT-238`(2026-09-03)로 삭제 |
| `wmain/` | 8개 — `comment` · `eventPage` · `feed` · `intergratedExibition` · `iplicenseMain` · `main` · `myWadizBirthdaySetting` · `myWadizProfileSetting` |

`wlayout/` 는 kwonnam jsp-template-inheritance 의 레이아웃 베이스입니다. **2026-09-22 확인 16개**입니다.

`_footer`, `_header`, `account`, `common`, `ftCommunity`, `mainCommon`, `wAccount`, `wAwardsCommon`, `wGlobalCommon`, `wcommon`, `wmeta`, `wmypage`, `wnoLayout`, `wnofooter`, `wterms`, `wtermsInvest`

> ⚠️ `wRewardDetailSPA.jsp` 는 여기 없습니다. `CLIENT-238` 로 삭제됐습니다.

### 4.3 urlrewrite 주요 패턴 (`web/WEB-INF/urlrewrite.xml`)
459라인 / 외부 유입 URL 호환성 유지에 집중.
- `/partner/**`, `/crowd/**`, `/sbsinvestor`, `/nhcrowd` → `/web/wpartner/detail/*`
- `/Campaign/Details/*`, `/ko/Campaign/Details/*` → `/web/campaign/detail/*` (301)
- `/Campaign/Edit/*`, `/web/campaign/edit/*`, `/web/campaign/opening` → `/studio/reward/*` (301) — **이미 studio(React) 로 이관된 화면들**
- `/web/wcommunity**`, `/web/wcast**`, `/web/ftcommunity**`, `/web/m/ftcommunity**` → `https://makercenter.wadiz.kr` (전부 외부 이관)
- `/web/fthelpCenter**` → `https://helpcenter.wadiz.kr`
- `/web/myreward` → `/web/mywadiz/payment-info` (구 마이 → 신 마이)
- `/web/wmypage/myfunding/info`, `/web/mywadiz/myfunding/info` → `/web/mywadiz/payment-info`
- `/web/wmypage/myfunding/fundinglist`, `/web/mywadiz/myfunding/fundinglist` → `/web/mywadiz/participation`
- `/web/wmypage/myfunding/rewardfundinglist` → `/web/mywadiz/participation`
- `/web/wevent/{slug}` (ces2024bywadiz, wday2404 등 50개+) → `/web/wevent/{id}` — 이벤트 slug → id 단일화
- `/web/brand/*`, `/web/collection/*` → `/web/wevent/*` (브랜드/컬렉션 → 통합 기획전)
- `/opensoon/*` → `/web/wcomingsoon/ivt/*`
- `/funding/{slug}/community/pledge-support` → `/funding/{slug}/community/support-share` (글로벌 커뮤니티 URL 변경)
- `/life` → `/web/wreward/main` (브랜딩 변경)
- `/web/store/best` → `/web/store/main?order=popular`

---

## 5. 컨트롤러·AJAX 엔드포인트 목록 (대표)

Spring 3.2 스타일로 **대부분 `@RequestMapping` 만 쓰고 `@GetMapping`/`@PostMapping` 은 거의 없음**. `@ResponseBody` + `produces = "application/json;charset=UTF-8"` 또는 `text/plain;charset=UTF-8` 패턴 + `@Controller`(아닌 `@RestController`). JSON view resolution은 `MappingJackson2JsonView` 기본 뷰.

### 5.1 페이지 렌더링 (JSP)

| URL | Method | Controller path:line | View |
|---|---|---|---|
| `/web/campaign/detail/{id}`, `/web/campaign/detail/reward-info/{id}` | GET | `web/campaign/controller/WEBCampaignController.java:67` | `wlayout/wRewardDetailSPA` |
| `/web/campaign/detail/fundingInfo/{id}` | GET | `WEBCampaignController.java:116` | `wlayout/wRewardDetailSPA` |
| `/web/campaign/detail/qa/{id}`, `/web/campaign/detail/qa/{id}/{commentType}` | GET | `WEBCampaignController.java:140` | `campaign/detailQASPA` |
| `/web/campaign/detailPost/{id}`, `/web/campaign/detailPost/{id}/news/{newsId}` | GET | `WEBCampaignController.java:166` | `campaign/detailPostSPA` |
| `/web/campaign/detailBacker/{id}` | GET | `WEBCampaignController.java:193` | `campaign/detailBackerSPA` |
| `/web/main`, `/web/main/earlybird`, `/web/main/planned`, `/web/main/my`, `/web/main/more`, `/web/main/empty` | GET | `web/wmain/controller/WMainController.java:86` | `wmain/main` |
| `/web/about` | GET | `WMainController.java:93` | `wmain/about` |
| `/web/wmain`, `/web/wmain/main` | GET | `WMainController.java:103` | redirect → `/web/main` |
| `/web/account/my` | GET | `web/waccount/controller/WAccountMyController.java:56` | `waccount/*` |
| `/web/waccount/wAccountRegistIntro` | GET | `WAccountRegistController.java:141` | 회원가입 인트로 |
| `/web/waccount/register/type/v2` | GET/POST | `WAccountRegistController.java:188` | 가입 타입 선택 |
| `/web/waccount/wAccountRegistCorp` | GET | `WAccountRegistController.java:259` | 법인 가입 |
| `/web/waccount/wAccountRegistFinish` | GET | `WAccountRegistController.java:442` | 가입 완료 |
| `/web/waccount/register/personal` | POST | `WAccountRegistController.java:460` | 개인 가입 처리 |
| `/web/wpayment/handbook` | GET | `web/wpayment/controller/WPaymentController.java:145` | `wpayment/handbook` |
| `/web/wpayment/{campaignId}` | GET/POST | `WPaymentController.java` (체크아웃 진입) | `wpayment/app` |
| `/web/wpayment/error/{type}` | GET | `WPaymentController.java:386` | `wpayment/error` |
| `/web/wpayment/complete` | GET | `WPaymentController.java` | `wpayment/complete` |
| `/web/waccount/wAccountLogin` | GET | `WAccountCommonController.java` | `waccount/wAccountLogin` |
| `/m/home` | GET | `web/login/controller/MOBLoginController.java:56` | redirect → `/web/wmain` |

### 5.2 AJAX / JSON 엔드포인트 (대표)

| URL | Method | Controller:line | 용도 |
|---|---|---|---|
| `/web/wcampaign/ajaxSearch/category/invest/keyword/{kw}/order/{order}` | GET | `WSearchCampaignController.java:65` | 투자형 통합검색 |
| `/web/wcampaign/ajaxSearch/category/reward/keyword/{kw}/order/{order}` | GET | `WSearchCampaignController.java:98` | 리워드 통합검색 |
| `/web/wcampaign/ajaxSearch/getExistRewardCampaignByUserId` | GET | `WSearchCampaignController.java:126` | 유저별 캠페인 존재 여부 |
| `/web/wcampaign/campaignSignature/ajaxSignatureStatus` | POST | `WWEBCampaignSignatureController.java:51` | 지지서명 상태 |
| `/web/wcampaign/campaignSignature/ajaxMySupportSignatureList` | POST | `WWEBCampaignSignatureController.java:62` | 내 지지서명 |
| `/web/wcampaign/campaignSignature/ajaxSupportSignatureList` | GET | `WWEBCampaignSignatureController.java:84` | 지지서명 리스트 |
| `/web/wcampaign/rewardSignature/ajaxRegisterRewardSignature` | POST | `WWEBRewardSignatureController.java:24` | 리워드 지지서명 등록 |
| `/web/wcampaign/investSignature/ajaxRegisterInvestSignature` | POST | `WWEBInvestSignatureController.java:24` | 투자 청약서명 등록 |
| `/web/campaign/ajaxUploadRewardCampaignEditorImage` | POST (multipart) | `WEBCampaignController.java:217` | 새소식 에디터 이미지 업로드 |
| `/web/campaign/ajaxFacebookSignature` | POST | `WEBCampaignController.java:227` | 페이스북 지지서명 |
| `/web/campaign/{campaignId}/participants` | GET | `WEBCampaignController.java:237` | 참여자 리스트 |
| `/web/campaign/{campaignId}/participants/my` | GET | `WEBCampaignController.java:244` | 내 참여자 리스트 |
| `/web/campaign/ajaxAskForEncore`, `/ajaxCancelEncore` | POST | `WEBCampaignController.java:253, 262` | 앵콜 펀딩 요청/취소 |
| `/web/wmain/ajaxGetBannerCommonList` | GET | `WMainController.java:145` | 메인 배너 공통 리스트 |
| `/web/main/recommendation/social`, `/web/main/v2/recommendation/social` | GET | `WMainController.java:154, 167` | 추천 소셜 피드 |
| `/web/main/maker/is-maker` | GET | `WMainController.java:179` | 메이커 여부 |
| `/web/main/maker/my-campaign` | GET | `WMainController.java:188` | 내 캠페인 |
| `/web/main/maker/subscribe` | POST | `WMainController.java:198` | 뉴스레터 구독 |
| `/web/main/track/section` | POST | `WMainController.java:215` | GA 섹션 트래킹 |
| `/web/waccount/ajaxIsValidCoupon`, `/ajaxRegisterCoupon`, `/ajaxModifyCoupon` | POST | `WAccountMyController.java:90, 110, 130` | 쿠폰 처리 |
| `/web/waccount/ajaxValidBusinessRegNum` | GET | `WAccountRegistController.java:278` | 사업자번호 검증 |
| `/web/waccount/ajaxSendSmsTokenByMarketing`, `/ajaxValidTokenByMarketing` | POST | `WAccountRegistController.java:287, 297` | 마케팅 SMS |
| `/web/waccount/ajaxAddPassword` | POST | `WAccountRegistController.java:322` | 비밀번호 추가 |
| `/web/waccount/ajaxRequestSendEmailConfirm`, `/ajaxRequestConfirmEmail` | POST | `WAccountRegistController.java:404, 414` | 이메일 인증 |
| `/web/waccount/ajaxValidPromotioncode` | POST | `WAccountRegistController.java:423` | 프로모션 코드 검증 |
| `/web/wpayment/getIsRealTime`, `/getIsHoliday`, `/getIsRefundTime` | GET | `WPaymentController.java:159, 171, 184` | 거래 가능시간 체크(증권형) |
| `/web/wpayment/ajaxTermsList` | GET | `WPaymentController.java:253` | 약관 리스트 |
| `/web/wpayment/ajaxGetGoodsList` | GET | `WPaymentController.java:274` | 결제상품 리스트 |
| `/web/wpayment/ajaxGetLimitAmount` | GET | `WPaymentController.java:294` | 투자한도 |
| `/web/wpayment/ajaxSendAuthCodeMail`, `/ajaxConfirmAuthCodeMail` | POST | `WPaymentController.java:551, 638` | 결제 본인인증 메일 |
| `/web/wpayment/ajaxSendEquityRiskNotificationMail` | POST | `WPaymentController.java:690` | 투자 위험고지 메일 |

Jersey(api) 계열은 별도: `/api/campaign/*`, `/api/login/*`, `/api/wmain/*`, `/api/wmypage/*`, `/api/wpoint/*`, `/api/store/*`, `/api/membership/*`, `/api/social/*` — JAX-RS `@Path` 어노테이션 기반. 대부분 모바일/앱 용 엔드포인트.

---

## 6. 주요 화면 상세 분석

### 6.1 리워드 캠페인 상세 (`/web/campaign/detail/{campaignId}`)

> ⚠️ **2026-09-22 전면 정정.** 이 화면은 더 이상 전용 JSP 를 쓰지 않습니다.
> `CLIENT-238`(2026-09-03)이 "통합으로 참조를 잃은 펀딩 상세 JSP" 를 지웠습니다.

- **Controller**: `src/main/java/com/wadiz/web/globalkorea/controller/GlobalKoreaFundingDetailController.java:68` 이 아래 경로를 전부 받습니다.

  | 구분 | 경로 |
  |---|---|
  | 본펀딩 상세 | `/campaign/detail/{id}` · `/campaign/detail/{id}/rewards` |
  | 새소식·질문 | `/campaign/detailPost/{id}` · `/campaign/detail/qa/{id}` |
  | 서포터 | `/campaign/detailBacker/{id}` |
  | 오픈예정 | `/wcomingsoon/rwd/{id}` |

- **렌더링**: `mv.setViewName("global-korea/index")` (`:169`). **React 셸 하나**입니다.
  종전의 `wRewardDetailSPA` · `detailQASPA` · `detailPostSPA` · `detailBackerSPA` 는 모두 없어졌습니다.
- **종전 컨트롤러** `src/main/java/com/wadiz/web/campaign/controller/WEBCampaignController.java` 는 남아 있지만 **AJAX 전용**이 됐습니다.
  에디터 이미지 업로드, 페이스북 서명, 참여자 조회, 앵콜 요청·취소만 처리합니다. 지면 렌더링 코드는 없습니다.
- **의존 서비스**: `CampaignService`, `RewardCampaignService`, `CampaignAccessPermitValidator`, `GlobalFundingGateway` 조합은 `GlobalKoreaFundingDetailController` 로 옮겨 갔습니다.
- **인증/권한**: 세션 기반(`SessionUtil`). 캠페인 비공개면 `CampaignAccessPermitValidator` 가 예외를 던집니다.

### 6.2 리워드 결제 체크아웃 (`/web/wpayment/{campaignId}` 및 서브)
> ⚠️ **2026-09-22 전면 정정.** 이 컨트롤러는 **더 이상 지면을 그리지 않습니다.**

- **Controller**: `src/main/java/com/wadiz/web/wpayment/controller/WPaymentController.java` (`@Controller`, class mapping `/web/wpayment/*`). **699줄**입니다(종전 기록 813줄).
- **지금은 AJAX·JSON 전용입니다.** 뷰 이름을 정하는 코드가 없습니다. 메서드가 전부 `ajax*` 또는 `getIs*` 이고 `produces` 가 `text/plain` 혹은 `application/json` 입니다.
- 종전에 적혀 있던 플로우(약관 `wpayment/handbook` → 결제 앱 `wpayment/app` → 에러 → 완료 `wpayment/complete`)의 **JSP 가 전부 사라졌습니다.** `wpayment/` 폴더에는 `equity/` 하위만 남아 있습니다.
- **ajax 엔드포인트 (17+)**: 약관 목록, 결제상품 목록, 투자한도, 본인인증 메일 코드 발송/확인, 증권형 위험 고지 메일, 실시간/공휴일/환불시간 체크.
- **주요 서비스**: `WPaymentService`, `PaymentService`, `NicePayService`(혹은 Inicis), `PointService`, `CouponService`, `AccountService`, `CampaignService`.
- **Mapper**: `sqls/reward/payment/payment-mapper.xml`, `payment-refund-mapper.xml`, `sqls/equity/payment/wpayment-mapper.xml` / `ftpayment-mapper.xml`.
- **외부 결제 연동**: NicePay(`kr.co.nicepay nicepay-lite`), Inicis(`inicis inipay 5.0`, `ExecureCrypto`) — pom 의존성으로 포함. 가상계좌/실명인증/IBK KSD 전산망 등 증권형 쪽은 `KSFCclient`/`NiceID.Check`.
- **뷰**: 없습니다. 종전의 결제 SPA 쉘·약관·완료 JSP 는 `FE1-1359`(2026-08-04, 투자 지면 제거) 전후로 모두 삭제됐습니다.

### 6.3 투자 청약 (증권형) (`/web/wpayment/equity/*` + `/web/waccount/equity/*`)
- **Controller**: `web/wpayment/controller/WPaymentEquityController.java` (약 700줄) + `web/waccount/controller/WAccountEquityController.java`, `WAccountJoinEquityController.java`.
- **특징**: 한국증권금융(KSFC) 예치금 계좌 API 직접 통신(`KSFCclient`), 투자 한도/본인인증 플로우, 증권신고서 위험고지, 청약확인서 PDF 생성(`pdfbox`).
- **Mapper**: `sqls/equity/**` 전체 — `ftcampaign-mapper.xml`, `equityCamapign-mapper.xml`, `ftpayment-mapper.xml`, `wpayment-mapper.xml`, `premiumMembership.xml`, `wpremiummain-mapper.xml`.
- **관련 JSP**: `web/WEB-INF/jsp/wpayment/equity*.jsp`(equity1/2/3/3-1/4/equityReserved/equityFail), `web/WEB-INF/jsp/wsub/wEasyCard.jsp`, `web/WEB-INF/jsp/equity/*.jsp`.
- **외부**: KSFC 증권금융 전산망, Inicis/NicePay 가상계좌, SmartSheet 연동(adm 쪽과 공유).

### 6.4 마이페이지 리워드 결제내역 (`/web/mywadiz/*`, `/web/wmypage/*`)
- **Controller**: `web/mywadiz/**/controller/*.java`, `web/wmypage/controller/*`.
- **많은 구 URL 이 urlrewrite 로 `/web/mywadiz/*` 로 통일됨** (`web/WEB-INF/urlrewrite.xml:265-287`). 예: `/web/myreward`, `/web/wmypage/myfunding/info`, `/web/wmypage/myfunding/fundinglist`, `/web/mywadiz/myfunding/info`, `/web/mywadiz/myfunding/fundinglist` 등 모두 → `/web/mywadiz/payment-info` 또는 `/web/mywadiz/participation`.
- **서비스/DAO**: `WWEBRewardDashboardService`, `WEBCampaignService`, `sqls/mywadiz/dashboard/maker-dashboard-mapper.xml`, `sqls/wmypage/winvest-mapper.xml`, `wreward-mapper.xml`, `sqls/reward/funding/funding-mapper.xml`.
- **JSP**: `mywadiz/*.jsp`, `wmypage/*.jsp`.

### 6.5 회원가입/로그인 (`/web/waccount/*` + `/web/account/*`)
- **Controller**: `WAccountRegistController.java:72`(665줄), `WAccountMyController.java`, `WAccountSocialController.java`, `WAccountEquityController.java`(17개 WAccount 컨트롤러 중 등록/소셜/내정보/증권형가입/휴면/본인인증 담당).
- **React 전환 진행**: `/WEB-INF/jsp/react/entries/iam.jsp` 가 이미 iam 번들(`__staticPath_iam_main_js`) 을 로드하는 **SPA 쉘** 로만 동작 — 실제 UI 는 React `iam` 번들이 그립니다. 기존 JSP 는 세션 인증·이메일 검증·SMS 인증 AJAX 엔드포인트만 남아있음.
- **Mapper**: `sqls/account/account-mapper.xml`, `userageverification-mapper.xml`, `userprofile-mapper.xml`, `sqls/waccount/waccount-mapper.xml`, `waccountCommon-mapper.xml`, `waccountEquity-mapper.xml`, `waccountSocial-mapper.xml`.
- **외부**: NICE 본인인증(`NiceID.Check`), 페이스북/카카오/네이버/구글/애플/라인 OAuth (`oauth2LoginFilter`, `oauth2RedirectFilter` → `com.wadiz.web.oauth.*`).

### 6.6 통합 메인 (`/web/main`, `/web/wmain`)
- **Controller**: `WMainController.java:86`(`home`), `WInvestMainController.java`(투자 메인), `WRewardMainController.java`(리워드 메인), `WLiveMainController.java`(라이브), `PreOrderUiMainController.java`(오픈예정).
- **서비스**: `WMainService`, `WWEBMainService`, `MainApiService`(main-client로 main-api 호출), `WInvestSearchService`, `WRewardSearchService`, `StatisticService`, `NewsletterService`.
- **Mapper**: `sqls/wmain/wiosmain-mapper.xml`, `sqls/wcampaign/winvestsearch-mapper.xml`(43 `<if>` 동적쿼리), `wrewardsearch-mapper.xml`(11), `WInvestCampaignBaseInfo-mapper.xml`(107 `<if>` — 프로젝트 최대 동적 쿼리).
- **JSP**: `wmain/main.jsp`(통합 리워드 메인) **하나만 남았습니다.**

  > ⚠️ 투자 메인·스타트업·메이커코드·소개 JSP 는 모두 삭제됐습니다.
  > 스타트업 지면은 `FE1-1359`(2026-08-04), 나머지는 `CLIENT-239`(2026-09-04)입니다.
  > `WStartupMainController.java` 도 함께 사라졌습니다.
- **특이**: 메인은 대부분 `main` React 청크 쉘입니다(번들 파일은 정적 호스트에서 받습니다). 서버는 GA 추적 엔드포인트 `/web/main/track/section`, 배너 리스트, 메이커 구독 AJAX 제공.

---

## 7. DB 접근

### 7.1 MyBatis 구성
- `src/main/resources/datasource/mybatis-config.xml` — 147개 `typeAlias` 등록(`userInfo`, `campaignDefaultInfo`, `ftCampaignIRInfo`, `wUserSmsConfirmInfo` 등 대부분 `com.wadiz.core.*.model` 및 `com.wadiz.web.equity.domain.ftcampaign.model`), 3개 `typeHandler`(`WInvestAmountHandler`, `UuidTypeHandler`, `RewardOptionTypeHandler`).
- 매퍼 XML 루트: `src/main/resources/sqls/` — 40 도메인 디렉토리 / 264 XML.
- 동적 쿼리 `<if test>` 사용 횟수: 총 1057회 / 76 파일. **MyBatis dynamic SQL 의존도 매우 높음.** 주요 hotspot:
  - `wcampaign/WInvestCampaignBaseInfo-mapper.xml`: 107
  - `community/communityArticle-mapper.xml`: 145
  - `ftboard/ftboardArticle-mapper.xml`: 111
  - `wpartner/wpartner-mapper.xml`: 91
  - `ftboard/ftboardArticleComment-mapper.xml`: 74
  - `wboard/wBoardComment-mapper.xml`: 52
  - `wcampaign/winvestsearch-mapper.xml`: 43
- XML 내 `<select>/<insert>/<update>/<delete>` 중심. `statementType="CALLABLE"` 은 3건(`code/ftcommon-mapper.xml`) 정도로 적으며, **대부분 CRUD + 조건부 동적 where**.
- `SqlSessionType`: `src/main/java/com/wadiz/core/SqlSessionType.java` 는 master/slave(읽기/쓰기) 또는 DB2(`sqls_db2`) 분리용.

### 7.2 Stored procedure
`src/main/resources/sp/` 에 20개 `.sql` 원본 파일 — 배포 시 DB 측에서 수동으로 관리(소스 버전관리 용). 대표:
- `ProcCampaignContributionInsert.sql` — 캠페인 참여기여도 일배치
- `ProcStatsDailyRewardPerformanceInsert.sql`, `ProcStatsDailyInvestPerformanceInsert.sql`, `ProcStatsDailyFundingPerformanceInsert.sql` — 일간 통계
- `ProcInvestCampaignFinishProcessing.sql`, `ProcInvestCampaignStartProcessing.sql` — 증권형 캠페인 시작/종료 처리
- `ProcCancelInvestCoupon.sql`, `ProcEqCampaingStatus.sql`
- `getCampaignAllUsers.sql`, `getCampaignInterestedUsers.sql`, `getCampaignFinishSignatureUsers.sql` — 대용량 유저 추출(배치)
- `wadiz_raise_err.sql`, `InitCouponNo.sql`, `ProcSetSummationSignature.sql`, `ProcCampaignPopScoreInsert.sql`, `ProcCampaignRandomInit.sql`, `ProcStatsUserPerformanceInsert.sql`.

### 7.3 DataSource
- `spring/application/datasource-context.xml` 에 master/slave DBCP 풀 설정. `datasource/jdbc-${env}.properties` 에 JDBC URL/패스워드(jasypt 암호화).
- `spring/application/monitoring-spring-datasource.xml` — 성능 모니터링용 프록시 DataSource.
- MySQL 5.x (connector 5.1.48) / InnoDB 가정.
- **DB2 병용**: `sqls_db2/**/*.xml` — 과거 IBM DB2 기반 레거시 통계를 위한 별도 SqlSessionFactory 추정(완전 사용 여부는 빌드 include 에서만 확인).
- `sqls` 외에 `statistics/wadizexception-mapper.xml` 에서 예외 로그도 DB 에 적재.

### 7.4 주요 테이블 도메인
매퍼 이름에서 추론:
- `account`, `userageverification`, `userprofile`
- `campaign` 도메인: `campaign`, `campaignInfo`, `campaignCongratulation`, `maker-studio`, `campaign-marker`
- `reward` 도메인: `funding`, `screening`, `settlement`, `coupon`, `comment`, `comment-image`, `story`, `rewarditem`, `makercommunication`, `refund`, `comingsoon`, `category`, `shipment`, `openreservation`
- `equity` 도메인: `ftcampaign`, `equityCampaign`, `wpayment`, `ftpayment`, `premiumMembership`, `wpremiummain`, `premiumContentsBoard`, `equityNews`, `equityInvestor`, `equityMember`, `equityDashboard`
- `waccount`: `waccount`, `waccountCommon`, `waccountEquity`, `waccountSocial`, `waccountHistory`
- `community`: `communityArticle`, `boardMaster`, `boardArticle`, `boardComment`, `supportSignature`
- `board`: `personalmessage`, `personalmessage-inbox`
- `progress`: `progress-tip`, `progress`
- `notification`: `app`(푸시토큰), `newsletterSubscriber`, `message-mapper`, `sts-temp-mapper`
- `statistics`: `wadizexception`, `wOpinion`, `MenuPagesHis`, `RefererHis`
- `startup`: `corporationContract`, `irRequest`, `corporation`, `corporationInvestor`, `corporationInquiry`, `corporationTeamMember`
- `school`: `school`(레거시)
- `wsub`: `weasycard`, `wevent`
- `wpartner`: `wpartner`
- `popup`: `popup`
- `wcoming`: `wcomingSoon`, `comingSoon`
- `wevent`: `eventInfo`, `eventCompensation`
- `letz`: 마케팅
- `follow`, `feedback`, `membership`, `code`, `ftcommon`, `country`
- `userreport`, `rest`

---

## 8. 외부 의존성

### 8.1 Wadiz 내부 마이크로서비스 (`pom.xml`)
- `com.wadiz.wave`: `wave-client 3.0.29-SNAPSHOT`, `wave-data 1.1.15-SNAPSHOT`, `wave-crypto 1.0.3-SNAPSHOT`
- `com.wadiz.wave.notification notification-client 1.4.5-SNAPSHOT`
- `com.wadiz.wave.pay pay-client 1.0.4-SNAPSHOT`
- `com.wadiz.wave.point point-client 1.1.1-SNAPSHOT`
- `com.wadiz.api.reward reward-http-client 0.4.10-SNAPSHOT` / `reward-models 0.4.9-SNAPSHOT`
- `com.wadiz.api.main main-client / main-model 1.0.6-SNAPSHOT`
- `com.wadiz.funding.core funding-core 1.0.137-SNAPSHOT`
- `com.wadiz.api.equity equity-http-client 0.0.6-SNAPSHOT` / `equity-models 0.0.7-SNAPSHOT`
- `com.wadiz.api startup-client / startup-model 1.3.45-SNAPSHOT`
- `com.wadiz.api payment-log-client / payment-log-model 0.1.1-SNAPSHOT`
- `com.wadiz.api.ksd-client ksd-client 0.0.12-SNAPSHOT`

### 8.2 결제·본인인증
- NicePay `nicepay-lite 0.9.24`
- Inicis `inipay 5.0`, `INIpay_Sample 1.2`, `ExecureCrypto 1.0`
- 한국증권금융(KSFC) `KSFCclient 1.0`
- NICE 본인인증 `NiceID.Check 1.0`
- Apple Sign In: `bcpkix-jdk15on 1.60` (JWT 서명 검증)

### 8.3 SNS·OAuth·알림
- Facebook App ID `190622721088710`, Kakao app, Naver, Google, Apple, LINE(twitter4j 는 twitter 만 쓰는 듯). callback: clive 기준 `https://www.wadiz.io/web/oauth/{provider}`.
- Braze(`web/braze/**` 및 `web/crmgateway/**` 추정) 관련 CRM 게이트웨이.

### 8.4 기타
- `org.jasypt jasypt-spring31 1.9.2` — 프로퍼티 암복호화(`encKey=!wadiz@`).
- `net.sf.ehcache 2.10.6` — 2차 캐시.
- `io.lettuce lettuce-core 5.1.6` + `netty-transport-native-epoll 4.1.33 (linux-x86_64)` — Redis 세션/캐시.
- `com.smartsheet smartsheet-sdk-java 2.2.5` (adm 공유).
- `org.apache.poi 3.14` + `poi-ooxml 3.14` — 엑셀 다운로드.
- `org.apache.pdfbox 2.0.24` — 청약서/계약서 PDF.
- `com.google.api-client 1.32.1`, `google-http-client-jackson2 1.32.1` — Google Sign-In, Drive 등.
- `com.wadiz.api ksd-client` — 한국예탁결제원(KSD) 연동.

### 8.5 CDN/정적자산
- `https://cdn.wadiz.kr/resources` — 이미지/공용 리소스.
- **React 번들 배포 원천** — clive `https://cdn-static.wadiz.io`, dev `https://cdn-static.dev.wadiz.io`, 온프레미스 real `https://static.wadiz.kr` (`src/main/resources/properties/file-{env}.properties` 의 `static_host`, `.frontend/static.config.js`).
- `https://www2.wadiz.kr` — `prev_site_url`. 구버전 와디즈 서브도메인.
- `https://app.wadiz.kr`, `https://adm.wadiz.kr`, `https://event.wadiz.kr` — 주변 도메인.

---

## 9. 이관·Deprecation 상태

### 9.1 이미 이관 완료 (urlrewrite 기준 외부 리다이렉트)
| From | To | 근거 |
|---|---|---|
| `/web/wcommunity**`, `/web/wcast**` | `makercenter.wadiz.kr` | urlrewrite.xml:112-120 (permanent) |
| `/web/ftcommunity**`, `/web/m/ftcommunity**` | `makercenter.wadiz.kr` | urlrewrite.xml:122-130 |
| `/web/fthelpCenter**` | `helpcenter.wadiz.kr` | urlrewrite.xml:189-191 |
| `/Campaign/Edit/*`, `/web/campaign/edit/*`, `/web/campaign/opening` | `/studio/reward/*` | urlrewrite.xml:53, 227 — **스튜디오 SPA 로 전량 이관** |
| `/studio/reward/*/funding/contractInfo` | `/studio/reward/*/settlementinfo` | urlrewrite.xml:286 |

### 9.2 내부 이관(SPA 쉘)
- `/WEB-INF/jsp/react/entries/iam.jsp` → iam React 번들(로그인/회원가입). 서버는 세션 + 이메일/SMS 인증 AJAX만 수행.
- ~~펀딩 상세 SPA 쉘 JSP 4종~~ — **없어졌습니다.** `CLIENT-238`(2026-09-03)이 지웠고, 지금은 `GlobalKoreaFundingDetailController` 가 `global-korea/index` 하나를 돌려줍니다. SEO 메타·JSON-LD·봇 HTML·초기 데이터 주입은 그 컨트롤러가 맡습니다.
- `wpayment/app.jsp` → payment React 번들.
- `/web/mywadiz/*` → mywadiz(account React 번들) + 일부 구 JSP.
- `/web/wcomingsoon/*` → coming React 번들.

`.frontend/chunks.config.js`(162줄)에 정의된 React 번들입니다. **2026-09-22 확인 11개**입니다.

| 청크 | 쓰이는 곳 |
|---|---|
| `web` | 공통 polyfill·wui·vendor·common. 모든 지면 |
| `main` | `wmain/main.jsp` |
| `account` | `waccount/*.jsp`, `mywadiz/*.jsp` |
| `reward` | 리워드 지면 |
| `iam` | `react/entries/iam.jsp` |
| `personal-message` | `wpersonalmessage/*.jsp` |
| `school` | `school/*.jsp` |
| `floating-buttons` | 공통 플로팅 버튼 |
| `landing` · **`landing-static`** | `wpage/*.jsp` 계열 |
| `embed` | `embed/*.jsp` |

> ⚠️ **세 청크가 사라졌습니다** — `equity`, `open-account`, `coming`.
> `landing-static` 이 새로 생겼습니다.
> `main` 청크가 쓰던 `wmain/wmain.jsp` 와 `reward` 청크가 쓰던 `wlayout/wRewardDetailSPA.jsp` 도 없어졌습니다.

### 9.3 아직 JSP 로 강하게 남아있는 영역
- ~~**리워드 결제 체크아웃**~~ — **더 이상 해당하지 않습니다.** `WPaymentController.java` 는 699줄이고 지면을 그리지 않습니다. AJAX·JSON 만 제공하며 `wpayment/` 폴더에는 `equity/` 하위만 남았습니다.
- **증권형 청약**: `WPaymentEquityController.java`, `/web/wpayment/equity/*.jsp` — 한국증권금융/KSD 연동 SSR 중심.
- **이벤트 기획전** `/web/wevent/*`: id 기반이지만 JSP 서버 사이드 데이터 주입.
- **wpartner** `/web/wpartner/detail/{slug}`: 파트너 상세 SEO 페이지.
- **wiplicense IP 라이선스 파트너**(빙그레/디즈니/넥슨/현대/라이엇/이코닉스/진로): 고유 JSP 페이지 다수.
- **글로벌(en) 커뮤니티**(`/funding/{slug}/community/*`) — 2024 이후 URL 변경만 되어 있고 JSP 로직 존재.
- **레거시 투자 약관/공지/본인인증** (`wterms/*.jsp`, `waccount/*.jsp`).

### 9.4 Jenkins/CI
루트에 `Jenkinsfile` 없음. 배포는 `mvnw clean install -Dmaven.test.skip=true` (README.md:14) + `package.json scripts.deploy` (`.frontend/scripts/deploy/createStaticPath.js`) 로 프런트 매니페스트를 JSP 에 주입 후 WAR 빌드.

### 9.5 커밋 활동도 간접 지표
- `.frontend/scripts/deploy/createStaticPath.js` 는 매 배포마다 `web/WEB-INF/jsp/winclude/assetVersions.jsp` 를 다시 만듭니다(파일명 앞의 밑줄은 없습니다). **2026-09-22 확인 — 그 파일에 `Last Updated` 주석이 더는 없습니다.** 종전 기록의 "Last Updated: 2019-10-23" 근거는 사라졌으므로, 아래 "2019년 이후" 판단은 재확인이 필요합니다. 해당 번들은 2019년 이후 갱신되지 않은 레거시 webpack build.
- 한편 `chunks.config.js` 의 iam/floating-buttons 는 `manifestPath: '/static/iam/manifest.json'` 식으로 **외부 CDN static-* 호스트**를 가리키므로, 신규 React 앱은 본 레포 외부(`wadiz-frontend` 모노레포로 추정) 에서 빌드/배포됨.
- adm 과 달리 이쪽은 본체 서비스라 커밋은 꾸준: 최근 임포트 클래스에서 `equity-http-client 0.0.6`, `funding-core 1.0.137`, `main-client 1.0.6`, `ksd-client 0.0.12` 등 소수점 두자리 패치 버전이 관찰됨 → **적극 개발 중**.

---

## 10. 특이사항

1. **groupId `markmount`**: 회사 브랜드가 MARKMOUNT → Wadiz 로 바뀐 후에도 Maven groupId 는 유지(pom.xml:4). 소스 저작권 주석(`@COPYRIGHT © MARKMOUNT ALL RIGHTS RESERVED.`)도 그대로.
2. **Spring 3.2 + Spring Security 3.2**: 2014년 릴리즈 라인. JDK 1.8 이 최저선. Spring Boot 1.1.4 는 starter 일부만 차용(본체는 XML 설정).
3. **Jersey 1.13 + Spring MVC 혼재**: `/api/*` 는 Jersey(JAX-RS 1.1 기반), `/web/*` 는 Spring MVC. 같은 세션·같은 DAO 를 공유하지만 프레임워크 분리.
4. **urlrewrite 459라인**: 역사적 URL 전부 유지(구 `/Campaign/Details/*` → 신). 50+ `/web/wevent/{slug}` 리다이렉트로 이벤트 슬러그 → id 정리.
5. **jsp-template-inheritance (kwonnam)**: Django/Jinja 식 `{% extends %}{% block %}` 을 JSP 에서 쓰게 해주는 한국산 라이브러리. `web.xml:258-266` 에서 prefix/suffix 지정. 러브콜 받기 어려운 특수 라이브러리.
6. **커스텀 TLD `functions.tld`**: `wdz:cdnURL`, `wdz:cdnURL2`, `wdz:cdnURL3`, `wdz:escapeJson`, `wdz:convertLink` 등 JSP 유틸. `com.wadiz.core.fw.utils.WadizCDNUtil` 로 image-proxy(dpr, crop, mark) 파라미터 생성.
7. **Scala 2.10.4 의존성**: 이유 불명. 일부 통계/수학 라이브러리 때문에 끌려들어온 과거 잔재.
8. **servlets.com cos 05Nov2002**: 2002년 버전 파일업로드 라이브러리. Commons FileUpload 와 병존 → 레거시 코드 잔존 증거.
9. **jodd 3.3.7 / json-simple 1.1.1 / gson 1.7.1 / fasterxml 2.6.2 / jackson mapper-asl 1.9.13(adm)**: JSON 라이브러리가 4-5개 병존. 뷰마다 사용 라이브러리가 다름.
10. **SuffixPatternDisabler** (`com.wadiz.web.fw.config.SuffixPatternDisabler`): Spring 3.2 default 인 `.json` suffix 매칭을 끄기 위한 BeanPostProcessor. `/ajaxSomething.json` 같은 의도치 않은 매칭 방지.
11. **AOP Aspect 3종**: `RequiredCertifyAspect` (본인인증 필수 메서드), `RecaptchaAspect` (reCAPTCHA 검증), `EncryptAspect` (DTO 필드 자동 복호화) — 파라미터 레벨 관심사 분리.
12. **jasypt encKey `!wadiz@`** 는 pom.xml property 로 평문 저장되어 있음(pom.xml:14). 빌드 시 resource filtering 으로 properties 파일에 주입. 보안상 취약하므로 추후 교체 필요 지점.
13. **`sitemap.xml`, `robots.txt`, `apple-app-site-association`, `service-worker.js` 가 WAR 루트(`web/`) 에 존재**: 웹 본체이므로 SEO/앱 연동 리소스가 직접 서빙됨. `apple-app-site-association` 에는 Universal Link 룰.
14. **mvnw 1.8**: Maven Wrapper 동봉.
15. **security-constraint 로 JSP 직접 접근 차단** (`web.xml:297-313`): `*.jsp` URL 에 auth-constraint 로 직접 접근 불가. 반드시 Controller 경유.
16. **한영 혼용 주석**: `@author 김종성`, `2016.11.04 문종배 회원관리 - 청약개편` 등 한국어 주석 다수. 주석에서 원저자(김종성) 와 공동 저자(이판호, 문종배, 권정훈) 이름 확인 가능.
17. **모바일 분리 흔적**: `/WEB-INF/jsp/mobile/` 디렉토리가 존재하며 `spring-mobile-device 1.1.3` 으로 User-Agent 감지. 반응형 전환 이후에도 일부 mobile JSP 잔존(`mobile/equity/*.jsp`).
18. **기획전/이벤트 redirect 전량 하드코딩**: `/web/wevent/{slug}` 50여개가 urlrewrite.xml 에 일일이 기술(1:1 매핑). 신규 이벤트 추가시 urlrewrite 수정 필요 → 운영 부담 포인트.


---

## 최근 변경사항

**분석 갱신일: 2026-07-10** (최초: 2026-04-20)

### 인프라 / 아키텍처
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| cloud/onprem profile 자동 활성화 분기 (jib.to.image property 기반) | 2026-05-19 | RWD-5578 |
| wave-data 버전 분기 — onprem 1.1.15 / cloud 3.1.1 Maven profile | 2026-05-19 | RWD-5578 |
| CJCookieServletFilter / UserCookieService cookie Domain 분기 | 2026-05-20 | RWD-5578 |
| Redis Cluster/Standalone 양쪽 mode 지원 구조 도입 | 2026-04-24 | COMMON-155 |
| onprem env profile 자동 활성화 (`-Denvironment=<id>`) | 2026-05-20 | RWD-5578 |

### 신규 기능 / 화면
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 글로벌 선정산 — 선정산 서비스 이용약관·메이커 이용약관 글로벌 분기 노출 | 2026-05-21~22 | FE2-402 |
| og:title, og:description 소셜 메타데이터 추가 | 2026-05-19~20 | CLIENT-107 |
| 검색 엔진 비노출 처리 | 2026-05-19 | FE2-387 |
| hreflang 추가 (WAi·메이커·글로벌 경로), sitemap.xml 개선 | 2026-04-24~27 | CLIENT-74 |
| 봇 요청 시 `/` → `/home` 301 리다이렉트 | 2026-04-24 | CLIENT-77 |
| JSP 메타데이터 하드코딩 제거 및 title prefix 정규화 | 2026-05-20 | CLIENT-80 |
| 매출UP 배너 NEW 판정 일(day) 단위 비교로 변경 | 2026-05-20 | RWD-5582 |
| 오픈예정→본펀딩 리다이렉트 302 → 301 변경 | 2026-04-23 | CLIENT-73 |
| /step10 진입 시 펀딩 상세 페이지로 301 redirect | 2026-04-27 | FE1-541 |
| 사후심의 스토리 RevivalHistoryId 기준 조회, StoryVersion deprecated | 2026-04-24~27 | RWD-5500 |
| 얼리버드 뱃지 — 참여내역·환불리스트·참여완료메일·엑셀 파일 | 2026-04-24~27 | RWD-5379 |
| Stripe Connect 배포일·시행일 업데이트 | 2026-05-19 | FE2-395 |
| 펀딩 상세 ETag(로그인 사용자) 기반 304 — 로그인·성인인증 상태 캐시 sync 갭 해소, 성인인증 전역 렌더 제거 | 2026-06-18 | FE1-959 |
| SEO sitemap 동적화 — index 구조 전환, 정적 도메인 치환, 펀딩·오픈예정·스토어 searcher 렌더 + ehcache 캐시, hreflang/언어변형 등록 | 2026-06-05~15 | CLIENT-86 |
| robots-noindex 앱 설정 조회(인메모리 TTL 5분 캐시) → 펀딩/메이커프로필 noindex meta 모델 주입 | 2026-06-15~17 | CLIENT-104 |
| 정적 페이지 하드코딩 메타데이터를 html-metadata 시트 기반 동적 메타데이터로 전환, AppSettingsService → app.service 패키지 이동 | 2026-06-07~10 | CLIENT-53 |
| robots.txt 인증/개인화 신규 SPA 경로 대량 disallow(/web/wish, /studio/, /maker/* 등) | 2026-05-29~06-10 | CLIENT-133 |
| 글로벌 Stripe Connect 정산·PayoutMethod 도입, 달러 결제/환불·달러 쿠폰(환전 서버 연동, GLOBAL_STRIPE) | 2026-04~05 | RWD-5285 / RWD-5375 / RWD-5661 |
| 국가 통관정보 필요 여부 유형 세분화 (CustomsInfoRequiredType) | 2026-06-02 | RWD-5621 |
| 사후심사 추가질문(QnA) v2 API·첨부파일·재제출, v1 deprecated, SectionType funding-core 이관 | 2026-05 | RWD-5514 |
| 사후심사 제출 시 Adm 수정 항목 제어용 CampaignMarker/MarkerId, 메이커정보 권한 ALL | 2026-06-08~16 | RWD-5609 / RWD-5706 |
| 성인인증 자가증명 앱 v3 PUT API (PUT /v3/account/adult-verification/my, 글로벌 전용) | 2026-06-09 | BE3-488 |
| 대표자 본인인증 필요 유무 판단 API 수정 | 2026-06-17 | RWD-5710 |
| 암복호화 추상화 레이어 도입(com.wadiz.core.crypto) 및 crypto-api 연동 | 2026-05-19 | RWD-5415 |
| 선정산·메이커 이용약관 개정(수수료 반환 범위), 지식재산권 보호 정책 폐지 | 2026-05~06 | FE2-498 / FE2-539 / FE2-426 / FE2-454 |
| 스쿨 신청 폼 offline·컨설팅 유형 추가 | 2026-05~06 | RWD-5600 |
| 펀딩 진행 중 배송지 변경·배송 상태 노출 허용 | 2026-05-28 | FE1-788 |
| 지지서명 트래킹을 커뮤니티 신규 API로 교체 | 2026-06-04 | RWD-5548 |
