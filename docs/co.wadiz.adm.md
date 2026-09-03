# co.wadiz.adm 분석 문서

> 와디즈 **관리자 포털(어드민)** 의 Spring Boot 전환판입니다. 레거시 [`com.wadiz.adm`](./com.wadiz.adm/com.wadiz.adm.md)(Spring 3.2.10 + 외장 Tomcat WAR)을 Spring Boot 2.7 로 옮기는 프로젝트로, 전환 이슈는 **RWD-5489** 입니다.
> Org: `wadiz-web` (`https://github.com/wadiz-web/co.wadiz.adm.git`). 배포 이름 `admin-server`, 플랫폼 `web`.

> 📅 분석 기준: 2026-09-01, **`master` 브랜치**(`ed66488`, 2026-08-26). Java 2,476개 · JSP 413개 · 테스트 10개.

> ℹ️ 저장소 안에 `README.md`·`DEPLOY.md`·`CLAUDE.md`·`docs/` 가 잘 갖춰져 있습니다. 이 문서는 그것들과 겹치지 않게 **구조·규모·배포선·최근 변경** 위주로 정리하고, 원문이 더 자세한 부분은 링크로 넘깁니다.

---

> 📅 **2026-09-03 master pull 보강** (3 커밋)
>
> 세 커밋 모두 `BE3-643` 한 이슈이며, 주제는 **하드코딩된 도메인 정리**입니다.
>
> ### 관리자 화면·메일의 `wadiz.kr` → `wadiz.io` 전환 (BE3-601 후속)
> - 관리자 회원·메이커 화면 JSP 3종(`account/memberBacked·memberCampaign·memberDetail`, `maker/makerNewsletter`)과 메일 템플릿에 박혀 있던 `wadiz.kr` 하드코딩을 **`wadiz.io`** 로 바꿨습니다.
>
> ### 발신자 주소·메일 푸터 도메인 전환 (BE3-828 정책)
> - `application-real.yml` 의 `default_send_email` 을 `info@wadiz.kr` → **`info@wadiz.io`** 로 바꿨습니다. 이는 RWD-5882 가 base 설정을 `.io` 로 바꾼 뒤 real 프로파일에만 걸어 두었던 **`.kr` override 를 해제**한 것입니다.
> - 같은 이유로 2026-08-11 이후 실패 상태였던 `LegacyPropertiesFileBeanTest` 의 기대값도 함께 정상화됐습니다.
> - 범위에서 제외된 것: 심사 BCC 수신자(`reward_scr1_email`), 참조 0건인 죽은 상수 3종.
>
> ### 메일 템플릿 정적 이미지 호스트를 `cdn.wadiz.kr` 로 통일
> - 메일 템플릿 22종에 흩어져 있던 `www.wadiz.kr/resources/static/img/*` **102건을 `cdn.wadiz.kr` 로 치환**했습니다. 저장소에 이미 있던 cdn 사용 55건과 혼재하던 상태를 없애 **도메인 전환의 영향을 차단**하려는 조치입니다.
> - `authResetPassword.mail` 의 가입 안내 이미지는 URL 에 `/web/` 세그먼트가 끼어 있어 `.kr`·`.io` 양쪽에서 모두 404 였습니다. 이번에 정상 경로로 교체했습니다.
> - ⚠️ **이미지 호스트는 아직 `wadiz.kr` 쪽입니다.** 위의 발신자·링크 도메인은 `.io` 로 가는 중인데 이미지만 `.kr` 로 모은 것이라, CDN 도메인 전환 시 이 102건이 다시 대상이 됩니다.
> - 별도 처리가 필요하다고 커밋에 남은 항목: `wadizres.imgix.net`(410 응답, 대체 이미지 없음), `application-real.yml` 의 `pdfviewer_url`(404).
>
> ---

## 개요

- 와디즈 사내 관리자 포털입니다. 정산·심사·쿠폰·캠페인·회원·메일·투자(equity)·스타트업 등 운영 업무 화면을 JSP 로 렌더링합니다.
- **레거시와 신규가 한동안 함께 돕니다.** rc·rc2·live 는 기존 `com.wadiz.adm` 외장 Tomcat(8082)을 유지한 채 신규 Spring Boot WAR 를 8083 으로 띄우고, Apache vhost 를 8083 으로 돌린 뒤 안정화되면 구 Tomcat 을 제거하는 **병행 가동** 전략입니다. dev 는 이미 8082 로 통합됐습니다 (`DEPLOY.md`).
- 동시에 **클라우드(clive) 배포선도 따로 있습니다** — 아래 "배포" 참조. 즉 온프레미스 병행 가동과 클라우드 이관이 같이 진행 중입니다.

## 기술 스택

핵심만 옮깁니다. 전체 표는 저장소 `README.md` 에 있습니다.

| 구분 | 내용 |
|---|---|
| JDK / 프레임워크 | **Java 8**(Corretto 1.8.0_442) · **Spring Boot 2.7.18** |
| 패키징 | **Executable WAR**(내장 Tomcat 9.0.83, JSP 포함) — `./gradlew bootWar` |
| 빌드 | Gradle 7.6.4 |
| View | **JSP** 413개 (`jsp-template-inheritance`) |
| ORM | MyBatis (`mybatis-spring-boot-starter` 2.3.2) |
| 보안 | Spring Security 5.7 (JDBC 인증 + **Redis 세션**), `WadizPassWordEncoder`(wave-crypto) |
| DB | MySQL (HikariCP, **Read/Write Replication**) |
| 캐시 | EhCache + Redis Cluster(Lettuce) |
| 설정 암호화 | `jasypt-spring-boot-starter` 3.0.5 (PBEWithMD5AndDES + NoIvGenerator) |
| 로컬 부팅 | AWS SSO 프로파일 필요 — DB 비밀번호를 **AWS Secrets Manager**(`rds_wadiz_web_dev_pw`)에서 주입, 실패 시 yml 의 `:default` 평문 fallback (RWD-5529) |

## 소스 구조 — 패키지가 두 갈래입니다

| 패키지 | 파일 수 | 성격 |
|---|---:|---|
| `com.wadiz.web.*` (+ `com.wadiz.core`, `com.wadiz.jsp`) | **2,342** | **레거시에서 그대로 옮겨온 업무 코드**. 화면·컨트롤러·서비스 대부분 |
| `co.wadiz.adm.*` | 28 | 신규 부트 진입점과 설정 — `CoWadizAdmApplication`, `config/{datasource,cache,redis,beans}` |
| `kr.wadiz.*` | 소수 | 일부 신규/공통 코드 |

> 즉 **"패키지를 새로 판 것이 아니라, 부팅·설정 계층만 새로 만들고 업무 코드는 레거시 패키지명을 유지한 채 얹은" 구조**입니다. 코드를 찾을 때 `co.wadiz.adm` 아래를 뒤지면 거의 나오지 않습니다 — 업무 로직은 `com.wadiz.web` 아래에 있습니다.

### 규모

- **컨트롤러 204개 · 매핑 1,282개.** 도메인별 컨트롤러 수 상위: 리워드 정산 15 · 투자(equity) 12 · 스타트업 10 · 진행현황 9 · 리워드 심사 7 · 리워드 쿠폰 7 · 메일 6 · 와디즈계정 5 · 리워드 캠페인 5 · 캠페인 5 · 회원 5.
- 테스트 10개 — 규모 대비 매우 적습니다.

## 배포 — 온프레미스(Jenkins)와 클라우드(GitHub Actions) 이중

### ① 온프레미스 (레거시 병행 가동)

`DEPLOY.md` 에 환경별 서버·포트·Jenkins Job·브랜치가 정리돼 있습니다. 요약:

| 환경 | 브랜치 | 포트 | 프로파일 | 외부 URL |
|---|---|---|---|---|
| dev | `dev` | 8082 (통합 완료) | `dev` | devadm.wadiz.kr |
| rc | `rc` | 8083 (구 Tomcat 8082 병행) | `rc` | rcadm.wadiz.kr |
| rc2 | `rc2` | 8083 (병행) | `rc2` | — |
| live | **`master`** | 8082 절체 | `real` | adm.wadiz.kr |

- init 시스템 **SysV(CentOS 6)**, 배포 경로 `/app/co.wadiz.adm/wadiz-adm-{build_id}/`, `current` 심볼릭 링크 방식, 헬스체크 `GET /web/diagnosis/ping`.

### ② 클라우드 (clive)

| 워크플로 | 트리거 | 갱신 대상 values |
|---|---|---|
| `.github/workflows/aws_deploy_ecr_live.yml` | **`master` push** | `web/clive/admin-server.yaml` |
| `aws_deploy_ecr_dev.yml` · `aws_deploy_ecr_rc4.yml` | `dev` · rc4 | 각 환경 |

- ECR `393290902814.dkr.ecr.ap-northeast-2.amazonaws.com/web/admin-server`, `java-version: 8`.
- **`cloud_live` 브랜치는 없습니다.** `master` 가 온프레미스 live 와 클라우드 clive 를 **동시에** 먹입니다(Jenkins 잡과 GitHub Actions 워크플로가 같은 브랜치를 봄).
- 배포 스펙은 [`helm-charts`](./helm-charts.md), 배포 상태(이미지 태그·ConfigMap)는 [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `web/clive/admin-server.yaml` 에 있습니다.

## 최근 변경 (2026-07~08)

### RWD-5947 — 클라우드 외장 Tomcat `server.xml` 추가 (2026-08-26)

- 쿠키가 쌓여 **HTTP 요청 헤더 총합이 8KB(Tomcat 기본값)를 넘으면 `Request header is too large`(400)** 가 나던 문제를 고쳤습니다.
- `docs/k8s-tomcat9/server.xml` 을 추가하고 HTTP Connector 에 **`maxHttpHeaderSize="65536"`(64KB)** 만 지정했습니다. 후속 커밋(`4b53136`)에서 변경 범위를 이 속성 하나로 좁혔고, 나머지 Connector 속성은 베이스 이미지 기본값을 그대로 둡니다. 포트는 8080 으로 jib `container.ports` 와 맞춥니다.

### RWD-5916 — Datadog 트레이스에 관리자 ID 태그 (2026-08-21)

- 로그인 관리자 ID 를 트레이스에 태깅하고, 키를 Datadog 표준 **`usr.id`** 로 맞췄습니다. 비로그인 기본값은 태깅에서 제외하고, **태깅 실패가 요청 처리에 영향을 주지 않도록** 예외를 차단했습니다.
- `com.wadiz.api.funding`(RWD-5916)·`com.wadiz.store`(STORE-1633)와 **같은 작업이 서비스별로 나뉘어 진행**된 건입니다.

### RWD-5879 / RWD-5836 — 실시간 콘텐츠 검사 화면

- 어드민에 실시간 콘텐츠 검사 화면 진입과 조회 API 중계를 추가(RWD-5836)하고, 목록 필터 확장·상세 스레드·판정/점수/타입 컬럼을 붙였습니다(RWD-5879). 지지서명 답글에서도 상세 스레드로 진입할 수 있게 했습니다.
- 백엔드는 [`co.wadiz.api.community`](./co.wadiz.api.community/co.wadiz.api.community.md) 의 `/api/v3/admin/realtime-content` 3 endpoint, 프론트는 `wadiz-frontend` 의 `static/services/admin` 입니다.

### 기타

| 이슈 | 내용 |
|---|---|
| RWD-5892 | IDC(real) 어드민 접근 허용 IP 에 CX 업체 대역 추가 |
| BE3-786 | Redis 캐시가 null 을 반환할 때 미처리로 NPE 가 나던 문제 수정(세션 kick·배너 등) |
| RWD-5882 | 기본 발송 메일(`default_send_email`) 도메인을 **`wadiz.io`** 로 변경 |
| BE3-785 | 멤버십 결제유예(`GRACE_PERIOD`) 상태 라벨 추가 |
| DISPLAY-1656 | 공통 배너 목록 썸네일 로딩 성능 개선 |

## 저장소 안의 문서

| 파일 | 내용 |
|---|---|
| `README.md` | 기술 스택 전체 표, 빠른 시작, `gradle.properties`·AWS SSO 사전 요구사항 |
| `DEPLOY.md` | 환경별 서버·포트·Jenkins Job·브랜치, 최초 셋업 스크립트, 병행 가동 전략 |
| `CLAUDE.md` | JDK 설정, 브랜치 규칙(`feature/RWD-xxxx`), 빌드 명령 |
| `docs/local-dev.md` · `docs/external-tomcat-setup.md` · `docs/dev-tomcat9-setup/` · `docs/k8s-tomcat9/` | 로컬·외장 Tomcat·k8s Tomcat 설정 |

## 미확인 항목

- 레거시 `com.wadiz.adm` 과의 **기능 전환 진척도** — 어떤 화면이 신규로 넘어왔고 어떤 게 아직 레거시에만 있는지. 두 저장소의 컨트롤러 대조가 필요합니다.
- 브랜치가 많고(`cloud_master-userplatform`·`conflict/*` 다수) 정리되지 않은 상태 — 어느 것이 살아 있는 라인인지.
- 온프레미스 live(Jenkins, 8082)와 클라우드 clive 중 **현재 실제 트래픽을 받는 쪽**.
- 테스트 10개로 회귀 안전망이 사실상 없습니다.
