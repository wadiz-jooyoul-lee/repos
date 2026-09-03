# kr.wadiz.catalogagent (catalog-agent) 분석 문서

> 와디즈 **카탈로그 데이터 동기화 파이프라인**입니다. DB 의 CDC(변경 데이터 캡처) 이벤트를 Kafka Streams 로 가공해 전시 지면이 쓸 카탈로그로 만들어 `display-agent` 에 넘깁니다. **전시 지면 데이터의 입구**에 해당합니다.
> Org: `wadiz-service` (`https://github.com/wadiz-service/kr.wadiz.catalogagent.git`). 배포 이름 `catalog-agent`, 플랫폼 `display-platform`.

> 📅 분석 기준: 2026-09-01, **`main` 브랜치**(`ab55392`, 2026-08-31). Java 202개(멀티모듈 6개), Avro 스키마 **46개**.

> ℹ️ 저장소의 `README.md` 가 구조·데이터 흐름·토픽·모니터링까지 잘 정리해 두었습니다. 이 문서는 그것과 겹치지 않게 **모듈 규모·배포선·최근 변경**과 원문에 없는 관측을 담습니다.

---

> 📅 **2026-09-03 main pull 보강** (1 커밋)
>
> ### DISPLAY-1725 — 찜 갱신 이벤트를 500건 단위로 쪼개 발행
> - 프로젝트·캠페인이 바뀌면 그 프로젝트를 찜하거나 알림신청한 **모든 사용자 ID 를 하나의 대용량 레코드로** 발행하고 있었습니다. 인기 프로젝트일수록 레코드가 커집니다.
> - 이 때문에 소비 쪽(`createUserCuration` 컨슈머)이 한 건을 처리하다 poll 타임아웃에 걸려 **리밸런스(파티션 재배치)가 반복되는 루프**에 빠졌습니다. 컨슈머가 계속 재시작되니 처리가 진행되지 않는 상태입니다.
> - 토폴로지를 `map` → **`flatMap`** 으로 바꾸고 사용자 ID 를 **500개씩 청크로 나눠 여러 레코드로 발행**하도록 고쳤습니다 (`agent/.../topology/wish/ProjectChangeToUserWishTopologies.java`, 38줄 추가 / 63줄 삭제).
> - 대상 토폴로지 3종 모두에 적용됐습니다 — `campaignToUserWishCurationRefresh`(펀딩 캠페인) · `rewardComingSoonToUserWishCurationRefresh`(오픈예정 알림신청) · `projectToUserWishCurationRefresh`(스토어).
>
> ---

## 개요

- **데이터 흐름**: `Database CDC → Kafka Topics → Kafka Streams → Internal Topics → display-agent` (README).
- Debezium CDC 형식의 Avro 이벤트를 받아 **28개 이상의 Kafka Streams 토폴로지**로 가공합니다.
- 최종 산출은 4~5개 토픽입니다 — `display-agent-funding-catalog-v2` · `display-agent-store-catalog-v2` · `display-agent-user-wish-curation` · `display-agent-wish` · `display-agent-launch-notification`.
- 즉 **이 서비스가 멈추면 전시 지면의 카탈로그가 갱신되지 않습니다.** 이번에 등록한 22개 중 배포가 가장 최근(2026-08-31)인 것도 이 서비스입니다.

## 모듈 구조 (멀티모듈 Gradle)

루트 프로젝트명은 `catalog-agent` 입니다(폴더명 `kr.wadiz.catalogagent` 와 다름).

| 모듈 | Java 파일 | 역할 |
|---|---:|---|
| **core** | 88 | 비즈니스 로직·도메인 모델 |
| **agent** | 77 | 메인 애플리케이션 (Spring Boot + Kafka Streams 토폴로지) |
| **infrastructure** | 25 | DB·HTTP 클라이언트 등 외부 시스템 연동 |
| external | 7 | 외부 API 클라이언트 |
| tools | 4 | 도구 |
| shared | 1 | 공통 유틸·설정 |

- 스트림 처리 클래스(`StreamsBuilder`/`KStream` 사용) **17개**.
- 토폴로지는 도메인별 폴더로 나뉩니다 — `topology/{category,wish,coupon,friendactivity,...}` + 공통 `CDCFilter`.

## Avro 스키마 46개

CDC 원본과 내부 이벤트 스키마가 함께 들어 있습니다. 도메인 묶음(README 기준):

| 묶음 | 대표 스키마 |
|---|---|
| activity (찜하기·알림신청) | `Campaign` · `BackingPayment` · `UserWishProject` · `RewardComingSoonApplicant` · `Follow` |
| project (프로젝트 카탈로그) | `Project` · `CouponTemplate` · `RewardCollection` · `Corporation` · `ProjectCouponSnapshot` |
| collection (통합기획전) | `CollectionEmblem` · `collection-emblem-changed` |
| 내부 이벤트 | `WishRefresh` · `LaunchNotificationRefresh` |
| 블랙리스트 | `DPCampaignBlacklist` · `DPStoreBlacklist` |

## 기술 스택

Java 17 · Spring Boot + **Spring Cloud Stream** · **Kafka Streams** + Confluent Schema Registry · **Avro(Debezium CDC 형식)** · MySQL(Master/Slave) · MyBatis · MapStruct · Gradle 7.x. 자세한 표는 저장소 `README.md` 참조.

## 배포 — Jenkins와 GitHub Actions 이중

README 는 **Jenkins**(`cd.wadizcorp.com` 의 `dev/rc/rc2/rc3/live.agent.catalog` 잡)를 안내하지만, 저장소에는 **GitHub Actions 워크플로도 함께** 있습니다.

| 환경 | 트리거 브랜치 | 갱신 대상 values |
|---|---|---|
| **clive** | **`main`** | `display-platform/clive/catalog-agent.yaml` |
| dev · rc4 | `dev` · `rc4` | 각 환경 |

- 2026-08-25 커밋 `[update_workflow] live 배포 트리거를 main 브랜치로 변경` 으로 **클라우드 live 배포선이 `main` 으로 확정**됐습니다.
- helm values 기준 `requestsMemory: **3Gi**` — 이번 22개 중 `indexer-geojedo`(4Gi) 다음으로 큽니다. 스트림 상태 저장(state store) 때문으로 보입니다(추정).
- 모니터링: `/actuator/health`(Kafka Streams binder health 를 Jenkins 가 주기 체크 → 슬랙 알림) · `/actuator/prometheus` · **`/actuator/kafkastreamstopology`**(토폴로지 확인용).

## 최근 변경 (2026-06~08)

이슈키 분포: `DISPLAY-1668`(4) · `DISPLAY-1649`(3) · `DISPLAY-1589`(2) · `DISPLAY-1582`(2) · `RWD-5664` · `DISPLAY-1636` · `DISPLAY-1609`

### DISPLAY-1589 — 클라우드 스키마 일원화와 발행량 절감 (2026-08-25~28)

- **on-prem Avro 스키마를 제거하고 `avro_cloud` 로 일원화**했습니다. 온프레미스/클라우드 이중 스키마 관리를 끝낸 정리입니다.
- "내 친구의 참여" CDC 이벤트 발행량을 **델타 방식**으로 바꿔 줄였습니다.

### 헬스체크 튜닝 — 되돌림으로 끝남 (2026-08-20~21)

- **ES 클러스터가 red 상태일 때 health 가 `OUT_OF_SERVICE` 로 떨어지는 문제**를 막으려고 liveness/readiness health group 을 분리했다가, **이틀 만에 두 차례에 걸쳐 전부 원복**했습니다(`8/20 17:43` 분리 → `8/20 17:54` 되돌림 → `8/21 16:19` 설정 원복).
- 즉 **이 문제는 아직 해결되지 않은 상태**로 보입니다. 외부 의존성(ES) 장애가 이 서비스의 기동 판정에 영향을 주는 구조가 그대로입니다.

### DISPLAY-1668 — 스키마 정리 (2026-07-30)

- `ProjectCouponSnapshot` 스키마에서 미사용 `__deleted` 필드를 제거했습니다.

## 미확인 항목

- **Jenkins 와 GitHub Actions 중 현재 실제 배포 경로** — README 는 Jenkins 기준으로 쓰여 있고 클라우드 워크플로는 8/25에 `main` 으로 바뀌었습니다. 온프레미스와 클라우드가 병행 중인지, 클라우드로 넘어갔는지 확인이 필요합니다.
- **ES health 문제의 현재 상태** — 위 되돌림 이후 다른 방식으로 해결됐는지.
- 토폴로지 28개의 개별 입출력 매핑 — README 에 요약만 있고 전수 목록은 없습니다. 필요하면 `agent/src/main/java/.../topology/` 를 전수 조사해야 합니다.
- `display-agent`(소비처)와의 계약 — 토픽 이름은 알지만 메시지 스키마 버전 관리 방식은 미확인.
- clive 실제 운영 설정(Kafka 브로커·Schema Registry·MySQL) — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/catalog-agent.yaml` 참조.
