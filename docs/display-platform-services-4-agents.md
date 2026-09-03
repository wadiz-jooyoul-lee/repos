# display-platform 서비스 묶음 ④ — 스트림 에이전트·키워드

> 전시플랫폼(display-platform) 팀의 **Kafka 스트림 에이전트 3종과 키워드 API** 를 묶었습니다. 앞의 발송 채널([묶음 ③](./display-platform-services-3-messaging.md))이 RabbitMQ 를 쓰는 것과 달리, 이쪽은 **Kafka 기반 데이터 파이프라인**입니다.
> 같은 팀 다른 묶음: [`묶음 ②`(메인 배치·위시·인박스·활동·통계)](./display-platform-services-2.md) · [`묶음 ③`(발송 채널)](./display-platform-services-3-messaging.md)

> 📅 분석 기준: 2026-09-01. 각 저장소 `main` 브랜치.

---

> 📅 **2026-09-03 main pull 보강** — `inbox-agent` (4 커밋)
>
> - **DISPLAY-1163** — 로그 소음 정리입니다. 캐시 이미지 조회 반복 로그를 제거하거나 `debug` 로 낮추고(`RedisCacheUtil`), 중복 데이터 제거 로그도 `debug` 로 낮췄습니다(`InboxService`).
> - **CI 워크플로 정규화** — live 워크플로에서 9줄이 지워졌습니다. 아래 "워크플로 정리 상태" 표의 이중 `update_image_tag` 가 이 서비스에서도 해소됐습니다.
>
> ---

## 한눈에 보기

| 서비스 | 저장소(`wadiz-tech/…`) | Boot | 컨트롤러/EP | 리스너 | 저장소 계층 | helm type |
|---|---|---|---|---|---|---|
| **display-agent** | `display-agent` | **3.3.1** | 0 / 0 | `ProjectMetricListener` · `UserActivityListener` | Kafka + MongoDB | `agent` |
| **inbox-agent** | `inbox-agent` | 3.0.2 | 0 / 0 | `InboxConsumer` | Kafka + RabbitMQ + MongoDB + Redis | `agent` |
| **main2-stream-agent** | `main2-stream-agent` | 3.0.2 | 0 / 0 | `KafkaStreamsConfig` | Kafka(Streams) + MongoDB | `agent` |
| **keyword-api** | `keyword` | 3.0.2 | 4 / **11** | — | Kafka + MongoDB | `api` |

- 앞의 셋은 **컨트롤러가 0개**인 순수 백그라운드 워커이고, `keyword` 만 외부 노출 API 입니다.
- 넷 다 **MongoDB + Kafka** 조합입니다. 지면 데이터를 MongoDB 에 쌓는 공통 패턴입니다.

---

## display-agent — 카탈로그 최종 소비자

- [`kr.wadiz.catalogagent`](./kr.wadiz.catalogagent.md) 가 만든 카탈로그를 **받는 쪽**입니다. catalog-agent 의 데이터 흐름은 `Database CDC → Kafka Streams → Internal Topics → **display-agent**` 로 끝납니다.
- catalog-agent 가 내보내는 토픽: `display-agent-funding-catalog-v2` · `display-agent-store-catalog-v2` · `display-agent-user-wish-curation` · `display-agent-wish` · `display-agent-launch-notification`.
- 리스너 2개: `ProjectMetricListener`(프로젝트 지표) · `UserActivityListener`(사용자 활동). 후자는 [묶음 ②](./display-platform-services-2.md) 의 `user-activity-api` 와 연결될 가능성이 있으나 미확인입니다.
- **Boot 3.3.1** 로 이 묶음에서 가장 최신이고, helm 메모리도 **2Gi** 로 가장 큽니다.
- **최근 변경**(2026-08-26): `Point live deploy image-tag to clive and remove duplicate clive`, `Remove odev image-tag step from dev deploy workflow` — 배포 워크플로에서 **중복 clive 스텝과 odev 스텝을 걷어냈습니다.**
  - 이는 [묶음 ②](./display-platform-services-2.md) 에서 기록한 "live/clive 이중 `update_image_tag`" 문제를 **이 서비스는 정리한 것**으로 보입니다. 같은 정리가 아직 안 된 서비스가 남아 있습니다.

## inbox-agent — 인박스 적재

- [묶음 ②](./display-platform-services-2.md) 의 `inbox`(조회 API, EP 18)와 짝입니다. `InboxConsumer` 1개로 메시지를 받아 적재합니다.
- 이 묶음에서 유일하게 **Kafka 와 RabbitMQ 를 함께** 씁니다 — 발송 채널(RabbitMQ)과 데이터 파이프라인(Kafka) 사이에 걸쳐 있다는 뜻으로 보입니다(추정).
- **최근 변경**: `DISPLAY-1163`(2026-08-19) — rc3 워크플로 제거 → 복원(rc4 병행) → 다시 제거. **환경 이관 과정에서 세 번 뒤집혔습니다.** `inbox` 저장소도 같은 이슈로 같은 시기에 정리됐습니다.

## main2-stream-agent — 메인 지면 스트림 처리

- `KafkaStreamsConfig` 기반 **Kafka Streams** 애플리케이션입니다. [`main2-api`](./main2-api.md)(읽기)·`main2-batch-api`(쓰기)·`main2-batch`(수집)와 함께 **main2 4형제**를 이룹니다.
- helm 메모리 **2.5Gi** — 스트림 상태 저장 때문으로 보입니다(추정).
- **최근 변경**:
  - `DISPLAY-1644` — **`avro` / `avro_cloud` 스키마 디렉터리 분기**. [`catalog-agent`](./kr.wadiz.catalogagent.md) 가 `DISPLAY-1589`(2026-08-25)로 **on-prem 스키마를 제거하고 `avro_cloud` 로 일원화**한 것과 같은 작업의 다른 쪽입니다. catalog-agent 는 이미 일원화를 끝냈고, 이쪽은 분기 상태입니다.
  - `RWD-5644` — Gradle 7.5 → 8.2.1, Jib 3.1.4 → 3.3.2 업그레이드.

## keyword-api (`keyword`) — 검색 키워드

- 이 묶음에서 유일한 API 서비스입니다. 컨트롤러 4개 · EP 11개.

| 컨트롤러 | base | EP |
|---|---|---:|
| `SearchKeywordController` | `api/v1/keywords` | 4 |
| `InfoKeywordController` | `api/v1/info-keywords` | 5 |
| `TriggerController` | — | 2 |

- 짝이 되는 `keyword-agent` 가 따로 있습니다(이번 범위 밖).
- **최근 변경**: `DISPLAY-1645` — **신규 사용자 키워드 푸시 알림 토글 오류 수정**, 노후화된 배포 워크플로 정리.
- 검색 색인기([`indexer-dokdo`](./com.wadiz.search.indexer-dokdo.md))도 해시태그·키워드를 색인하므로 역할이 겹칠 여지가 있으나 확인하지 못했습니다.

---

## ⚠️ 관측 — 워크플로 정리 상태가 서비스마다 다릅니다

[묶음 ②](./display-platform-services-2.md) 에서 기록한 **live/clive 이중 `update_image_tag`** 문제를 기준으로 보면, 팀 전체가 같은 정리를 서로 다른 속도로 하고 있습니다.

| 상태 | 서비스 |
|---|---|
| **정리 완료** | `display-agent`(중복 clive·odev 스텝 제거, 2026-08-26) · `indexer-dokdo`(트리거 브랜치 정리, 08-26) · `catalog-agent`(live 트리거를 main 으로, 08-25) · `main2-api`(DISPLAY-1688, 09-02) · **`inbox-agent`**(CI 워크플로 정규화, 09-02) · **`main2-batch-api`**(DISPLAY-1713, 09-03) |
| **미정리** | `inbox` · `user-activity-api` — live/clive 이중 스텝이 남아 있고 `display-platform/live/` 는 gitops 에 없음 |

> 📅 2026-09-03 기준입니다. 2026-09-01 최초 작성 시점의 "미정리 3건"이 **2건으로 줄었습니다.**

## 미확인 항목

- `display-agent` 의 `UserActivityListener` 와 `user-activity-api` 의 관계.
- `main2-stream-agent` 의 avro 스키마 분기가 catalog-agent 처럼 `avro_cloud` 일원화로 갈지.
- `keyword-api` 와 `indexer-dokdo` 의 키워드/해시태그 역할 분담.
- 각 에이전트가 실제로 소비·발행하는 토픽 목록 — 코드 문자열로는 잡히지 않아(설정 주입) [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `configmap.data` 를 봐야 합니다.
- `inbox-agent` 가 Kafka 와 RabbitMQ 를 각각 어디에 쓰는지.
