# platform-admin 분석 문서

> 전시플랫폼(display-platform) 팀의 **운영 어드민**입니다. 컬렉션(기획전)·메일·메시지(알림톡·SMS·친구톡)·푸시·인박스·메인 지면·통계를 한 화면에서 관리합니다. API 서버가 아니라 **Freemarker 로 화면까지 직접 그리는 서버 렌더링 어드민**입니다.
> Org: `wadiz-tech` (`https://github.com/wadiz-tech/platform-admin.git`). 배포 이름 `platform-admin`, 플랫폼 `display-platform`.

> 📅 분석 기준: 2026-09-01, **`main` 브랜치**(`3674eed`, 2026-08-31). Java 424개 · Freemarker 템플릿 49개 · 컨트롤러 34개 · 엔드포인트 128개.

> ℹ️ display-platform 팀 저장소 중 **규모가 가장 큽니다**(이번에 등록한 22개 기준). 같은 팀의 다른 서비스는 [`helm-charts-gitops.md`](./helm-charts-gitops.md) 의 "이 저장소를 읽는 실전 요령"으로 추적할 수 있습니다.

---

## 개요

- 전시플랫폼 팀이 쓰는 **사내 운영 도구**입니다. 와디즈 서비스의 어드민(`co.wadiz.adm`)과는 별개로, 지면·발송 채널 운영에 특화돼 있습니다.
- **API + 화면이 한 저장소**에 있습니다. Freemarker 템플릿 49개와 `static/` 을 직접 서빙합니다.
- 저장 계층은 **MongoDB** 입니다(`spring-boot-starter-data-mongodb`). RDB 는 쓰지 않습니다.
- 발송 채널 연동(Braze·휴머스온·NHN)과 **Kafka(Avro)** 파이프라인을 함께 물고 있습니다.

## 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 언어/런타임 | **Java 17** (`eclipse-temurin:17`) | `build.gradle` |
| 프레임워크 | **Spring Boot 3.0.4**, Spring Cloud 2022.0.5, Tomcat 10.1.13 | `build.gradle` |
| 포트 | **9000**, graceful shutdown, **세션 타임아웃 없음(`-1`)** | `application.yml` |
| 저장소 | **MongoDB** | `spring-boot-starter-data-mongodb` |
| 뷰 | **Freemarker** (캐시 off, 페이지당 최대 20건) + `static/` | `application.yml`, 템플릿 49개 |
| 보안 | Spring Security + **OAuth2 Client** 로그인 | `web/config/WebMvcSecurity.java`, `web/security/*` |
| 메시징 | **Spring Kafka 3.2.2** + Spring Cloud Stream Kafka + **Confluent Avro**(`kafka-avro-serializer` 7.4.0, `avro` 1.11.0) | `build.gradle`, `.avsc` 1개 |
| 쿠버네티스 설정 | `spring-cloud-starter-kubernetes-client-config` + bootstrap | `bootstrap-kubernetes.yml` |
| 관측 | Actuator + Prometheus | `application.yml` |
| 기타 | MapStruct 1.6.0 · **Apache POI**(엑셀 다운로드) · **Mustache**(템플릿 치환) · jsoup · spring-retry | `build.gradle` |
| 빌드/이미지 | Gradle + **Jib 3.3.1**(OCI) + Avro 플러그인 | `build.gradle` |

## 도메인 구조

`kr.wadiz.platform.admin` 아래 도메인 모듈로 나뉩니다.

| 모듈 | 파일 | 컨트롤러 | EP | 역할 |
|---|---:|---:|---:|---|
| **message** | 110 | **13** | 33 | 알림톡·SMS·친구톡 등 **메시지 발송 채널 관리**. 가장 큰 모듈 |
| **collection** | 101 | 4 | 14 | **컬렉션(기획전)** 관리. 스케줄러 3종 보유 |
| **mail** | 63 | 5 | 17 | 메일 템플릿·발송 관리 |
| **statistics** | 41 | 3 | 7 | 발송·지면 통계. 스케줄러 1종 |
| **main** | 35 | 2 | 18 | 메인 지면 관리. 스케줄러 1종 |
| **web** | 22 | 3 | 30 | 보안 설정·로그인·공통 화면 |
| **push** | 17 | 2 | 7 | 푸시 관리 |
| **external** | 11 | 0 | 0 | 외부 연동 — `braze` · `humuson`(휴머스온) · `nhn` · `project` |
| common · display · file · inbox | 24 | 2 | 2 | 공통 코드·전시·파일·인박스 |

### 스케줄러 5종

모두 **cron 표현식을 설정으로 빼고 `Asia/Seoul`** 로 고정했습니다(`MainService` 것만 하드코딩).

| 위치 | cron 설정 키 | 용도 |
|---|---|---|
| `collection/scheduler/CollectionScheduler` | `wadiz.collection.cron.open-and-close.expression` | 컬렉션 오픈·마감 |
| 〃 | `wadiz.collection.cron.sync-external-collection.expression` | 외부 컬렉션 동기화 |
| 〃 | `wadiz.collection.cron.delete-nhn-template.expression` | NHN 템플릿 정리 |
| `statistics/scheduler/NotificationScheduler` | `wadiz.notification.cron.collect-history.expression` | 발송 이력 수집 |
| `main/service/MainService:668` | `0 5 0 * * ?` (하드코딩) | 매일 00:05 |

## 배포

| 환경 | 트리거 브랜치 | 갱신 대상 values |
|---|---|---|
| **clive** | **`main`** | `display-platform/clive/platform-admin.yaml` |
| dev · rc1 · rc2 · rc4 | `dev` · `rc` · `rc2` · `rc4` | 각 환경 |

- 워크플로 5종 모두 `wadiz-gitops/workflows-container-image-build-push` 를 호출합니다.
- helm values 기준 `requestsMemory: 1.5Gi`, `type: api`, VirtualService `subPath` 로 외부 노출됩니다.
- 배포 스펙은 [`helm-charts`](./helm-charts.md), 운영 설정은 [`helm-charts-gitops`](./helm-charts-gitops.md) 의 같은 경로에 있습니다.
- ⚠️ helm 에 **`platform-admin-ui` 라는 별도 서비스**가 있습니다(clive 배포 2026-06-08). 이 저장소가 화면까지 그리는데 UI 서비스가 따로 있는 이유는 미확인입니다.

## 최근 변경 (2026-06~08)

이슈키 분포: `DISPLAY-1547`(15) · `DISPLAY-1710`(11) · `DISPLAY-1651`(4) · `RWD-5647`(3) · `DISPLAY-1723`(3) · `DISPLAY-1586`(2)

### DISPLAY-1710 — 접근 권한 개편과 public 페이지 도입 (2026-08-26~27)

- **페이지 접근 ROLE 을 정리**했습니다. `MANAGER`·`MAIL`·`PUSH` 롤을 제거하고 `DEV` 를 추가했으며, 기본 접근 ROLE 을 **`ROLE_USER`** 로 바꾸고 첫 로그인 시 기본 롤을 부여하도록 했습니다.
- **로그인 없이 볼 수 있는 public 페이지**를 추가했습니다 — 템플릿 관리 페이지의 public 버전과 public 홈. 정적 리소스(`/assets`)를 `permitAll` 로 열었습니다. (public 홈의 안내 콘텐츠는 이후 제거돼 빈 content 만 남았습니다.)
- 템플릿 치환자 추출 로직을 공통 유틸로 통합. SonarQube 설정은 제거했습니다.

### DISPLAY-1723 — 도메인코드 공용화 (2026-08-27)

- 도메인코드 조회를 `platform_admin` 으로 이전하고 공용화했습니다(`ChannelType` 을 `common` 으로 이동). 메일 템플릿에서도 도메인코드를 등록·조회할 수 있게 했습니다.

## ⚠️ 확인이 필요해 보이는 점

문서화 과정에서 눈에 띈 것들입니다. **원본은 수정하지 않았고 기록만 합니다.**

| # | 내용 |
|---|---|
| ① | **세션 타임아웃이 `-1`(무제한)** 입니다 (`application.yml`). 운영 어드민에서 세션이 만료되지 않는 설정이라 확인이 필요합니다. |
| ② | **로그인 없이 접근 가능한 페이지가 도입**됐습니다(DISPLAY-1710). 템플릿 관리 public 버전이 사내 도구에서 어디까지 노출되는지 확인이 필요합니다. helm values 의 AuthorizationPolicy 와 함께 봐야 합니다. |

## 미확인 항목

- **`platform-admin-ui` 서비스의 정체** — 이 저장소가 Freemarker 로 화면을 그리는데 별도 UI 서비스가 존재하는 이유. 소스 레포도 미상입니다.
- Kafka/Avro 를 실제로 어디에 쓰는지 — 의존성과 `.avsc` 1개는 있으나 `@KafkaListener`·`StreamsBuilder` 가 코드에서 잡히지 않았습니다(Spring Cloud Stream 함수형 바인딩 추정, 미확인).
- 외부 연동 3사(`braze`·`humuson`·`nhn`)의 역할 분담 — 어떤 채널이 어디로 나가는지.
- clive 실제 운영 설정(MongoDB 접속·cron 값·OAuth2 provider) — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/platform-admin.yaml` `configmap.data` 참조.
- 테스트 코드 유무는 이번 스캔 범위 밖입니다.
