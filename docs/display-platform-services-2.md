# display-platform 서비스 묶음 ② — 메인 배치·위시·인박스·활동·통계

> 전시플랫폼(display-platform) 팀 서비스 중 **중간 규모 5개**를 한 문서로 묶었습니다. 개별 문서를 만들 만큼 크지 않고 성격이 겹쳐, 비교해서 보는 편이 유용합니다.
> 개별 문서가 있는 서비스: [`platform-admin`](./platform-admin.md) · [`kr.wadiz.catalogagent`](./kr.wadiz.catalogagent.md) · [`main2-api`](./main2-api.md) · [`main1-api`](./com.wadiz.api.main.md) · [`indexer-dokdo`](./com.wadiz.search.indexer-dokdo.md) · [`indexer-geojedo`](./com.wadiz.search.indexer-geojedo.md)

> 📅 분석 기준: 2026-09-01. 각 저장소의 기준 브랜치 최신 커밋.

---

> 📅 **2026-09-03 main pull 보강** — `main2-batch-api` (3 커밋)
>
> ### DISPLAY-1713 — 배포 워크플로 정리
> - **live 워크플로의 중복 clive 잡을 제거**했습니다. 아래 "공통 관측" 에 기록한 `update_image_tag` 이중 실행 문제가 이 서비스에서는 해소됐습니다.
> - dev 워크플로의 odev 이미지 태그 갱신 스텝도 제거했고, **rc3 → rc4 로 배포 환경을 전환**했습니다(`aws_deploy_ecr_rc3.yml` → `aws_deploy_ecr_rc4.yml`).
> - 기능 변경 1건: **배너가 0개가 될 때 기존 배너를 삭제**하도록 처리했습니다(`BannerRepositoryV2`·`MainService`). 이전에는 빈 목록이 오면 아무것도 하지 않아 옛 배너가 지면에 남았을 것으로 보입니다(추정).
>
> ---

## 한눈에 보기

| 서비스 | 저장소 | 브랜치 | Java | 컨트롤러/EP | Boot / Java | 저장소 계층 |
|---|---|---|---:|---|---|---|
| **main2-batch-api** | `wadiz-tech/main2-batch-api` | `main` | 104 | 4 / **29** | 3.1.3 / 17 | MongoDB |
| **main2-batch** | `wadiz-batch/main2-batch` | `main` | 85 | 0 / 0 | 2.7.2 / 17 | MongoDB + JPA |
| **wish-api** | `wadiz-tech/wish-api` | `main` | 79 | 3 / 10 | **3.3.0** / 17 | MongoDB + Redis(reactive) |
| **inbox** | `wadiz-tech/kr.wadiz.platform.inbox` | `main` | 48 | 3 / 18 | 2.7.3 / 17 | MongoDB + Redis + **Kafka** |
| **user-activity-api** | `wadiz-tech/user-activity-api` | `main` | 45 | 4 / 14 | **4.0.2** / **21** | MongoDB + Redis(reactive) + Kafka |
| **main1-batch-agent** | `wadiz-batch/com.wadiz.wave.statistics` | `master` | 47 | 1 / 1 | — / **8** | JPA + MyBatis |

> **스택 편차가 큽니다.** `user-activity-api` 는 **Spring Boot 4.0.2 + Java 21(amazoncorretto:21-alpine)** 로 팀 내 가장 최신이고, `main1-batch-agent`(`com.wadiz.wave.statistics`)는 **Java 8** 로 가장 오래됐습니다. 같은 팀 안에서 Boot 2.7 / 3.1 / 3.3 / 4.0 이 공존합니다.

---

## main2-batch-api — 메인 지면 데이터 쓰기 API

- [`main2-api`](./main2-api.md)(읽기)와 짝을 이루는 **쓰기·배치 API** 입니다. MongoDB 의 지면 도큐먼트를 채웁니다.
- 컨트롤러 4개: `MainController` · `DisplayController` · `GlobalController` + 예외 advice. EP 29개.
- helm `subPath: main2-batch`, `requestsMemory: 1.4Gi`.
- **최근 변경**: `DISPLAY-1641` — **와디즈 에디션 저장 API 추가**(2026-07-24), 카테고리 랭킹 저장 시 null 체크 추가(07-31). 웹·앱의 에디션 지면(FE1-1316 등)에 데이터를 넣는 쪽입니다.
- 테스트 0개.

## main2-batch — 메인 지면 수집 배치

- 컨트롤러가 **0개**인 순수 배치입니다. helm 상 `subPath: main2-batch-scheduler`.
- MongoDB 와 **JPA(RDB)** 를 함께 씁니다 — 원본 RDB 에서 읽어 MongoDB 지면 도큐먼트로 옮기는 역할로 보입니다(추정).
- **최근 변경**: `DISPLAY-1641` **와디즈 에디션 수집 추가**(2026-07-23~24), 배포 워크플로 브랜치 전략 변경·rc4 추가(08-26).
- `main2-batch-api`(쓰기 API)와 `main2-batch`(수집 배치)가 **다른 org**(`wadiz-tech` vs `wadiz-batch`)에 있습니다.

## wish-api — 찜·큐레이션

- 컨트롤러 3개: `WishController`(`/api`) · `CurationController`(`/api`) + advice. EP 10개.
- **Boot 3.3.0** 으로 이 묶음에서 두 번째로 최신. MongoDB + reactive Redis.
- **최근 변경**: `DISPLAY-1649`(2026-07-29) — 위시/큐레이션 조회를 서비스 레이어로 정리, **미사용 `/v1/curation` 엔드포인트 제거**, 위시 조회의 `userId` 수신 방식 통일.
- 앱·웹의 찜 기능과 연결됩니다(웹 `FE1-1478`·iOS `FE1-1467`·Android `FE1-1474` 의 `is_interested` 수집과 같은 도메인).
- 테스트 0개.

## inbox — 인박스(알림함)

- 컨트롤러 3개: `InboxController` · `InboxAdminController`(`/admin`) + advice. EP 18개.
- **Kafka** 를 쓰는 유일한 API 성 서비스입니다(이 묶음 기준). MongoDB + Redis 병용.
- 짝이 되는 에이전트가 따로 있습니다 — `inbox-agent`(`wadiz-tech/inbox-agent`, Java 26, 컨트롤러 0).
- helm `requestsMemory: 1.9Gi`.
- **최근 변경**: `DISPLAY-1163`(2026-08-19) — rc3 배포 워크플로 제거하고 **rc4 로 교체**. 기능 변경이 아니라 환경 이관입니다.

## user-activity-api — 사용자 활동 데이터

- 컨트롤러 4개: `RecentSearchController`(최근 검색어) · `RecentViewController`(최근 본 항목) · `WishProjectController` · `FriendActivityController`. EP 14개.
- **Spring Boot 4.0.2 + Java 21** — 팀 내 최신 스택입니다.
- **최근 변경**: `DISPLAY-1603`·`DISPLAY-1612`(2026-07-02) — **최근 검색어 저장·변경 시 `indexer-dokdo` 로 토픽 발행**. 즉 이 서비스가 [`indexer-dokdo`](./com.wadiz.search.indexer-dokdo.md) 의 이벤트 소스 중 하나입니다(dokdo 문서의 `UserSearchEventListener` 미확인 항목과 연결).
- `FriendActivityController` 가 있어 [`com.wadiz.api.friends`](./com.wadiz.api.friends.md) 의 `/api/friends/activities` 와 이름이 겹칩니다 — 역할 분담은 미확인.

## main1-batch-agent (`com.wadiz.wave.statistics`) — 통계 배치

- 유일하게 **`master` 브랜치**·**Java 8** 입니다. helm 상 `type: agent`(인바운드 라우팅 없음), `requestsMemory: 2Gi`.
- 컨트롤러 1개(`JobExecuteController`, EP 1) — 배치 수동 실행용으로 보입니다.
- JPA + MyBatis 병용. 이 묶음에서 **테스트가 가장 많습니다(9개)**.
- **최근 변경**:
  - `DISPLAY-statistics-deadlock`(2026-07-23) — **클라우드(RDS) 배치 메타 테이블 데드락** 대응
  - `DISPLAY-slack-postmessage`(2026-08-13) — 배치 슬랙 알림을 `chat.postMessage` 방식으로 변경
- 이슈키가 `DISPLAY-{숫자}` 가 아니라 `DISPLAY-statistics-deadlock` 처럼 서술형입니다(Jira 키가 아닌 임시 표기로 보임).

---

## ⚠️ 공통 관측 — live 배포 경로가 gitops 에 없습니다

> ⚠️ **2026-09-03 갱신 — 절반이 정리됐습니다.** `main2-batch-api`(DISPLAY-1713)와 [`main2-api`](./main2-api.md)(DISPLAY-1688)는 중복 clive 잡을 제거해 이제 clive 하나만 갱신합니다. **아직 이중으로 남은 서비스는 `inbox` 와 `user-activity-api` 둘뿐입니다.** 아래 서술은 그 둘에 해당합니다.

`inbox` · `user-activity-api` 의 live 워크플로는 **`update_image_tag` 잡을 두 번** 돌립니다.

```yaml
update-image-tag:        value_file_path: display-platform/live/{svc}.yaml    # ①
update-image-tag-clive:  value_file_path: display-platform/clive/{svc}.yaml   # ② needs: ①
```

그런데 **`display-platform/live/` 디렉터리는 [`helm-charts-gitops`](./helm-charts-gitops.md) 에 존재하지 않습니다**(gitops 환경은 `clive`·`dev`·`rc4`·`stage` — `rc1` 은 2026-09-03 에 삭제됐습니다). `live` 경로는 [`wa-infrastructure/helm-charts`](./helm-charts.md) 에만 있습니다.

| 경로 | gitops | wa-infrastructure |
|---|:---:|:---:|
| `display-platform/live/{svc}.yaml` | ❌ | ✅ |
| `display-platform/clive/{svc}.yaml` | ✅ | ✅ |

- ①이 실제로 어디에 반영되는지(다른 gitops 저장소·브랜치인지, 실패하는지)는 **확인하지 못했습니다.**
- ②가 ①에 `needs` 로 걸려 있어, ①이 실패하면 **clive 반영까지 막힐 수 있는 구조**입니다.
- 온프레미스 → 클라우드 이관 과도기의 잔재로 보이나 미확인입니다. 팀이 이 구조를 걷어내는 중이며(DISPLAY-1713 등), 남은 둘도 같은 정리를 기다리는 상태로 보입니다.

## 미확인 항목

- 위 live 경로 문제의 실제 동작(GitHub Actions 실행 이력을 봐야 확인 가능).
- `main2-batch`(수집)와 `main2-batch-api`(쓰기 API)의 경계 — 무엇이 무엇을 호출하는지.
- `user-activity-api` 의 `FriendActivityController` 와 `com.wadiz.api.friends` 의 `/api/friends/activities` 역할 분담.
- `inbox` 와 `inbox-agent` 의 분담.
- 각 서비스의 clive 실제 운영 설정 — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/{svc}.yaml` `configmap.data` 참조.
- 테스트가 대부분 0~3개로, 회귀 안전망이 얇습니다(`main1-batch-agent` 9개가 예외).
