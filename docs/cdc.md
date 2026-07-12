# cdc — Debezium 커넥터 관리 리포지토리

> `wa-infrastructure` org 소속 인프라 저장소. Wadiz 전 조직의 MySQL binlog → Kafka CDC 파이프라인을 담당하는 **Debezium 커넥터 설정 JSON 원본**이 여기에 있습니다.
>
> 지금까지 `docs/_concepts/kafka-cdc-and-user-link.md`, `docs/_flows/feed.md` 에서 "Debezium 은 별도 인프라(본 monorepo 미관측)" 로 표기했던 그 파이프라인의 **실증 소스**입니다.

- Clone URL: `git@github.com:wa-infrastructure/cdc.git`
- 로컬 경로: `/Users/casvallee/work/repos/cdc/`
- 관리 팀: 인프라 (`wa-infrastructure` org)

---

## 1. 저장소 구조

```
cdc/
├── debezium/            # 커넥터 설정 원본 (.jsonc / .json)
│   ├── backoffice/      # 30.cdc — wadiz-db, etc-db, notification
│   ├── core/            # live.core — 코어 DB
│   ├── data-platform/   # 40.dataplatform — 데이터 플랫폼
│   ├── display-platform/# 10.platform / live.display / live.catalog — 메인·위시·카탈로그
│   ├── user-platform/   # 20.user + 21.user — 유저·펀딩·서명·스토어 (user.link 소스)
│   └── test/            # 배포 파이프라인 테스트용
├── jenkins/
│   ├── dev/Jenkinsfile  # dev 환경 배포
│   └── live/Jenkinsfile # live 환경 배포
└── util/                # Kafka Connect REST API 유틸 스크립트
    ├── create_connector_with_json.sh
    ├── update_connector_config.sh
    ├── get_connector.sh
    ├── get_connector_detail.sh
    ├── get_connector_plugin.sh
    ├── pause_connector.sh
    ├── delete_connector_by_name.sh
    └── auto-failover/   # FAILED 태스크 자동 재시작 + Slack 알림
        ├── main.sh
        ├── delete_prefix_topic.sh
        └── delete_schema_topic.sh
```

## 2. 환경별 커넥터 세트

각 platform 은 다음 환경 폴더를 가집니다.

| 환경 | 의미 |
|---|---|
| `dev` / `cdev` / `odev` | 개발 (콘텐츠/오퍼레이션 개발) |
| `rc` / `rc2` / `clive` | 스테이징·릴리스 후보 |
| `live` / `olive` | 프로덕션 |
| `local` | 로컬 테스트 |
| `test` | 배포 파이프라인 테스트 (display-platform, test) |

**live 환경 커넥터 총 목록** (실측):

| Platform | 커넥터 파일 | Topic Prefix |
|---|---|---|
| backoffice | `wadiz-connector.jsonc` | `30.cdc` |
| backoffice | `etc-connector.jsonc` | `30.cdc` |
| backoffice | `wadiz-wave-notification-connector.jsonc` | `30.cdc` |
| core | `olive/core.jsonc` | `live.core` |
| data-platform | `dp-connector.jsonc` | `40.dataplatform` |
| display-platform | `main2/order-history-connector.jsonc` | `10.platform.main2.order.v1` |
| display-platform | `wish/catalog-project.jsonc` | `live.catalog.project.v1` |
| display-platform | `wish/user-activity.jsonc` | `live.display.userActivity.v1` |
| user-platform | `20-user-connector.json` | `20.user` |
| user-platform | `21-user-connector.json` | `21.user` |

## 3. `user-platform` 커넥터 상세 — `kr.wadiz.user.link` 의 소스

`kr.wadiz.user.link` 는 16 Kafka 토픽을 컨슘합니다. 그 토픽에 이벤트를 발행하는 것이 바로 아래 두 Debezium 커넥터입니다.

### 3.1 `20.user` — 유저·팔로우·차단 그래프

파일: `cdc/debezium/user-platform/live/20-user-connector.json`

- **Connector class**: `io.debezium.connector.mysql.MySqlConnector`
- **DB source**: `172.31.1.230:8450`
- **Topic prefix**: `20.user`
- **Kafka**: `kafka-01:9092,kafka-02:9092,kafka-03:9092` (3 broker)
- **snapshot.mode**: `schema_only_recovery`
- **heartbeat.interval.ms**: `86400000` (24시간)

**캡처 대상 테이블·컬럼**:

| 스키마.테이블 | 캡처 컬럼 |
|---|---|
| `wadiz_db.UserProfile` | UserId, NickName, UserStatus, WhenCreated, Updated |
| `wadiz_wave_follow.Follow` | FollowerUserId, FollowingUserId, OptIn, Registered, Updated |
| `wadiz_wave_follow.UserBlocking` | UserId, TargetUserId, OptIn, Registered, Updated |
| `wadiz_wave_follow.UserRecommendationRejection` | UserId, IsRejected |

### 3.2 `21.user` — 캠페인·서명·펀딩·스토어

파일: `cdc/debezium/user-platform/live/21-user-connector.json`

- 위와 동일한 설정 (DB, Kafka, snapshot 방식)
- 추가 `RegexRouter` transform 적용 (`MiniBoardCommon` → `21.user.wadiz_db.MiniBoard`)

**캡처 대상 테이블·컬럼**:

| 스키마.테이블 | 캡처 컬럼 |
|---|---|
| `wadiz_db.Campaign` | CampaignId, BizModel, IsStandingBy, WhenCreated, WhenEdited, IsHidden, IsDel, WhenHoldTo, IsOpen |
| `wadiz_db.Signature` | SignatureId, UserId, CampaignId, WhenCreated, Updated, IsDeleted |
| `wadiz_db.MiniBoardCommon` | BoardId, UserId, CommonId, GroupId, WhenCreated, WhenEdited, Del, WhenDeleted, Depth, ParentBoardId |
| `wadiz_db.MiniBoardCommonCommentTypeMapping` | BoardId, CommentType |
| `wadiz_db.BackingPayment` | BackingPaymentId, UserId, CampaignId, IsCanceled, RegDate, ProcDate, PayStatus, AddDonation, BillingAmount, FundingAmount, DontShowAmount, DontShowName, CancelDate |
| `wadiz_db.RewardComingSoonApplicant` | Seq, UserId, CampaignId, IsCanceled, Registered |
| `wadiz_db.UserWishProject` | WishId, UserId, ProjectType, ProjectNo, IsDel, Registered, Updated |
| `wadiz_reward.Satisfaction` | SatisfactionNo, UserId, CampaignId, Registered, IsHidden, IsDeleted, hiddenUpdated, Updated |
| `wadiz_store.project` | project_no, registered_at, updated_at, status, ended_at |
| `wadiz_store.satisfaction` | satisfaction_no, registered_by, project_no, is_deleted, registered_at, updated_at |
| `wadiz_store.order` | order_no, registered_by, project_no, registered_at, updated_at, status, payment_amount, ordered_at |
| `wadiz_store.project_setting` | project_no, is_discovery_suppressed |
| `wadiz_data_db.DPCampaignBlacklist` | CampaignId, Type, IsValid, Registered, Updated |

### 3.3 user.link 컨슈머 매핑 (실증표)

`docs/_concepts/kafka-cdc-and-user-link.md` 에서 "user.link 컨슈머 16개 ↔ MySQL 테이블 매핑은 추정" 이라고 표기했던 부분의 **1:1 실증**입니다.

| user.link 토픽 | 대응 MySQL 테이블 | 커넥터 |
|---|---|---|
| `user` | `wadiz_db.UserProfile` | 20.user |
| `follow` | `wadiz_wave_follow.Follow` | 20.user |
| `block` | `wadiz_wave_follow.UserBlocking` | 20.user |
| `user-recommendation-rejection` | `wadiz_wave_follow.UserRecommendationRejection` | 20.user |
| `campaign` | `wadiz_db.Campaign` | 21.user |
| `signature` | `wadiz_db.Signature` | 21.user |
| `miniboard` | `wadiz_db.MiniBoardCommon` | 21.user |
| `backing-payment` | `wadiz_db.BackingPayment` | 21.user |
| `reward-coming-soon-applicant` | `wadiz_db.RewardComingSoonApplicant` | 21.user |
| `user-wish-project` | `wadiz_db.UserWishProject` | 21.user |
| `reward-satisfaction` | `wadiz_reward.Satisfaction` | 21.user |
| `store-project` | `wadiz_store.project` | 21.user |
| `store-satisfaction` | `wadiz_store.satisfaction` | 21.user |
| `store-order` | `wadiz_store.order` | 21.user |
| `store-project-setting` | `wadiz_store.project_setting` | 21.user |
| `blocked-campaign` | `wadiz_data_db.DPCampaignBlacklist` | 21.user |

**16 tables = 16 topics = 16 user.link Kafka*Consumer 클래스** — 완벽 매핑.

## 4. Jenkins 배포 파이프라인

파일: `cdc/jenkins/live/Jenkinsfile`

- **Agent**: `cd-worker03` 라벨
- **Parameters**:
  - `EXECUTE_TYPE`: `CREATE` (신규) 또는 `UPDATE` (기존 수정, snapshot.mode 자동 변경)
  - `TARGET_CONNECTOR_PATH`: 커넥터 설정 파일 경로 (예: `debezium/display-platform/odev/test/test.jsonc`)
- **Env**:
  - `ENV=live`
  - `REMOTE_HOST=172.31.1.236`
  - `REMOTE_PATH=/srv/platform-connector-admin/connector_configs`
- **흐름**:
  1. 파라미터 검증
  2. GitHub `wa-infrastructure/cdc` main 브랜치 checkout
  3. 대상 JSON 을 REMOTE_HOST 에 전송
  4. Kafka Connect REST API 로 CREATE / UPDATE 수행

## 5. `util/` — Kafka Connect REST API 유틸

Kafka Connect 는 `http://localhost:8083` 에서 REST API 를 노출합니다. 이 폴더의 스크립트는 그 API 의 간단한 래퍼입니다.

| 스크립트 | 호출 | 용도 |
|---|---|---|
| `create_connector_with_json.sh <json>` | `POST /connectors/` | 신규 커넥터 생성 |
| `update_connector_config.sh <name> <json>` | `PUT /connectors/{name}/config` | 설정 갱신 |
| `get_connector.sh` | `GET /connectors/` | 목록 조회 |
| `get_connector_detail.sh` | `GET /connectors?expand=status&expand=info` | 상세 조회 |
| `get_connector_plugin.sh` | `GET /connector-plugins` | 플러그인 목록 |
| `pause_connector.sh <name>` | `PUT /connectors/{name}/pause` | 일시정지 |
| `delete_connector_by_name.sh <name>` | `DELETE /connectors/{name}` | 삭제 |

### 5.1 auto-failover — FAILED 태스크 자동 복구

`cdc/util/auto-failover/main.sh` 의 로직:

1. `GET /connectors?expand=status` 로 태스크 상태 조회
2. `state == "FAILED"` 태스크 자동 재시작 (`POST /connectors/{name}/tasks/{id}/restart`)
3. 10초 대기 후 재검사
4. 여전히 FAILED 면:
   - Slack 알림 발행
   - `delete_prefix_topic.sh` — 토픽 삭제
   - `delete_schema_topic.sh` — 스키마 히스토리 토픽 삭제
   - 재시작

Slack 훅 URL 이 코드에 하드코딩되어 있으나 현재 주석 처리됨 (`# curl -X POST https://hooks.slack.com/services/...`).

## 6. 인프라 토폴로지 (실측 종합)

```
[MySQL master (172.31.1.230:8450)]
     │
     │ binlog (schema_only_recovery)
     ▼
[Debezium MySqlConnector × 10+ (live)]
   ├ 20.user  (UserProfile, Follow, UserBlocking, UserRecommendationRejection)
   ├ 21.user  (Campaign, Signature, MiniBoardCommon, BackingPayment,
   │           RewardComingSoonApplicant, UserWishProject, Satisfaction,
   │           store.project/order/satisfaction/project_setting,
   │           DPCampaignBlacklist)
   ├ 30.cdc   (backoffice: wadiz-db, etc-db, notification)
   ├ 40.dataplatform
   ├ 10.platform.main2.order.v1
   ├ live.core
   ├ live.catalog.project.v1
   └ live.display.userActivity.v1
     │
     ▼
[Kafka Cluster (kafka-01/02/03:9092)]
     │
     │ 각 소비자 서비스가 자신에게 필요한 토픽 구독
     ▼
[다양한 컨슈머]
   ├ kr.wadiz.user.link (16 토픽 → Neo4j 그래프)
   ├ com.wadiz.wave.searcher (일부 → ES 색인, 추정)
   └ 그 외 (본 인벤토리로는 미확인)

[Kafka Connect REST API (http://localhost:8083)]
     ▲
     │ 관리 명령 (CREATE/UPDATE/PAUSE/DELETE, 자동 failover)
     │
[cdc/util/*.sh 스크립트]
[cdc/jenkins/live/Jenkinsfile (수동/자동 배포)]
```

## 7. 관측 한계

이 repo 는 **커넥터 설정만** 담고 있고 다음은 여기서 확인 불가:

- Kafka broker 자체 설정·토픽 파티션·retention 정책
- Kafka Connect 클러스터 배치 매니페스트 (Kubernetes/Ansible 어디에 있는지)
- 컨슈머 오프셋·컨슈머 그룹 상태
- Debezium 이 실제로 발행하는 각 토픽의 record 스키마 (Avro/JSON 여부는 커넥터 config 에서 유추 가능하나 별도 Schema Registry 필요)

## 8. 다른 문서와의 연결

- 이 파이프라인의 **개념 설명**: [`docs/_concepts/kafka-cdc-and-user-link.md`](./_concepts/kafka-cdc-and-user-link.md)
- 이 파이프라인의 **소비 예시**: [`docs/_flows/feed.md`](./_flows/feed.md) (친구·피드가 wave.user 쓰기 → CDC → user.link 그래프로 반영되는 경로)
- 소비자 서비스 상세: [`docs/kr.wadiz.user.link.md`](./kr.wadiz.user.link.md)
