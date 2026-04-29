# CDC + Kafka 학습 정리 — Debezium 부터 Wadiz user.link 까지

> 📅 2026-04-29 작성
> 학습 대화를 정리한 문서. Kafka·Debezium·CDC 의 개념부터 Wadiz repos 의 실제 사용 패턴까지.

## 1. Apache Kafka — 분산 이벤트 스트리밍 플랫폼

### 1.1 한 줄 정의
**"여러 시스템이 메시지를 주고받는 거대한 우체국 + 녹화 보관소"**

### 1.2 핵심 구성요소
| 용어 | 의미 |
|---|---|
| **Producer** | 메시지를 토픽에 발행하는 쪽 |
| **Consumer** | 토픽을 구독해서 메시지를 가져가는 쪽 |
| **Topic** | 메시지가 쌓이는 채널 (이름 기반) |
| **Partition** | 토픽을 나눈 단위. 병렬 처리 + 순서 보장 단위 |
| **Broker** | Kafka 서버 노드. 클러스터를 이룸 |
| **Consumer Group** | 같은 토픽을 분산 소비하는 컨슈머 묶음 |
| **Offset** | Consumer 가 어디까지 읽었는지의 위치 |

### 1.3 일반 메시지 큐와의 결정적 차이
| 항목 | 일반 MQ (RabbitMQ 등) | Kafka |
|---|---|---|
| 메시지 보관 | 소비되면 삭제 | **기간 내 계속 보관** (며칠~몇 달) |
| 재소비 | 불가 | **offset 되돌리면 가능** |
| 전달 방식 | broker 가 push | **consumer 가 pull (polling)** |
| 처리량 | 보통 | 초당 수백만 건 |

> 비유: RabbitMQ = "편지함, 꺼내면 사라짐". Kafka = "녹화된 방송 채널, 며칠 동안 다시 볼 수 있음".

### 1.4 발신자·수신자 완전 분리
```
[Producer] → [Topic "주문"]
                 ↓
                 ├→ Consumer A (메일 발송)
                 ├→ Consumer B (배송 등록)
                 └→ Consumer C (분석 적재)
```
Producer 는 누가 듣는지 모름 / Consumer 는 누가 발행했는지 모름. **결합도 0.**

---

## 2. Polling 메커니즘 — Kafka 의 데이터 가져오기

### 2.1 Push 가 아니라 Pull
Kafka broker 는 능동적으로 알림을 보내지 않음.
**Consumer 가 직접 broker 에 "새거 있어요?" 라고 계속 물어봄**.

### 2.2 왜 Pull 인가
- **Consumer 가 소비 속도 제어** — 느린 Consumer 가 push 에 깔려 죽지 않음
- **재소비 가능** — offset 만 되돌리면 과거 메시지 다시 읽음
- **Batch 효율** — 한 번에 여러 건 가져오면 빠름

### 2.3 누가 Polling 코드를 작성하나
**Kafka 클라이언트 라이브러리가 제공**. 개발자가 직접 짤 일 거의 없음.

```java
// 라이브러리가 주는 표준 패턴
while (true) {
    ConsumerRecords records = consumer.poll(Duration.ofMillis(500));
    for (record : records) {
        processMessage(record.value());  // 비즈니스 로직만 작성
    }
}
```

또는 추상화 프레임워크로 polling 루프조차 안 보이게:
```java
@KafkaListener(topics = "orders")
public void onOrder(String message) {
    processOrder(message);  // 메시지 도착 시 자동 호출
}
```

### 2.4 누가 어디서 실행되나 (중요한 구분)
```
[당신의 앱 프로세스]            [Kafka 클러스터]
┌────────────────────┐         ┌──────────────┐
│ Kafka Client 라이브러리│ ←pull→ │   Broker     │
│ (poll 루프 여기서 돔) │         │ (응답만 함)  │
└────────────────────┘         └──────────────┘
```
- **Kafka 프로젝트** 가 라이브러리(`kafka-clients.jar`, `kafkajs` 등) 를 배포
- 그 라이브러리는 **앱 프로세스 안에서** 실행됨 (broker 안이 아님)
- broker 는 폴링 요청에 응답만 함

### 2.5 설정으로 튜닝 — 워크로드별
| 설정 | 의미 | 기본값 |
|---|---|---|
| `max.poll.records` | 한 번에 최대 몇 건 | 500 |
| `fetch.max.wait.ms` | 메시지 없을 때 broker 가 대기하는 시간 | 500ms |
| `fetch.min.bytes` | 최소 이만큼 쌓일 때까지 대기 | 1 byte |
| `enable.auto.commit` | offset 자동 커밋 vs 수동 | true |
| `auto.offset.reset` | 처음 읽기 시작 위치 | latest |
| `group.id` | Consumer Group 이름 | (필수) |
| `session.timeout.ms` | heartbeat 끊긴 후 죽었다고 판단할 시간 | 10초 |

워크로드별 예시:
- **실시간 알림**: max-poll=10, fetch.min.bytes=1, fetch.max.wait=100ms
- **대량 배치**: max-poll=5000, fetch.min.bytes=1MB, fetch.max.wait=5초
- **정확성 중시 (결제·정산)**: enable.auto.commit=false, isolation.level=read_committed

---

## 3. Debezium — DB 변경을 Kafka 로 자동 흘려보내는 CDC 도구

### 3.1 한 줄 정의
**"DB 의 트랜잭션 로그를 어깨 너머로 보고 그대로 Kafka 토픽에 발행하는 비서"**

### 3.2 어떻게 동작하나
모든 DB 는 자체 복구·복제용으로 **트랜잭션 로그**를 항상 기록 중:
| DB | 로그 이름 |
|---|---|
| MySQL | binlog |
| PostgreSQL | WAL (Write-Ahead Log) |
| MongoDB | oplog |
| Oracle | redo log |
| SQL Server | Transaction Log |

Debezium 은 **"나 복제본이에요"** 라고 DB 에 등록해서 그 로그를 받아옴 → Kafka 메시지로 변환.

```
[앱이 INSERT/UPDATE/DELETE]
        ↓
[MySQL이 binlog에 기록]   ← DB 가 평소 하던 일
        ↓
[Debezium이 binlog 읽음]  ← 복제본인 척
        ↓
[Kafka 토픽에 메시지 발행]
```

### 3.3 발행되는 메시지 예시
```json
{
  "op": "u",
  "before": { "id": 7, "name": "철수" },
  "after":  { "id": 7, "name": "영수" },
  "source": { "table": "users", "ts_ms": 1714377600000 }
}
```

### 3.4 왜 좋은가
- **DB 부담 0** — 어차피 만들고 있는 로그를 읽기만 함
- **앱 코드 0줄 수정** — Producer 코드 안 짜도 됨
- **누락 없음** — 트랜잭션 commit 된 건 무조건 로그에 있음
- **순서 보장** — binlog 순서 그대로

### 3.5 옛날 방식 (Trigger) 대비
| 방식 | DB 부담 | 누락 위험 | 코드 변경 |
|---|---|---|---|
| Trigger | 매 변경마다 추가 작업 | 트리거 빠지면 누락 | DB 객체 추가 |
| **Debezium CDC** | 거의 0 | 없음 | 0 |

---

## 4. CDC 채택 여부 — 모두가 쓰는 게 아님

### 4.1 잘 맞는 곳
- 데이터 규모 큰 곳 (Netflix, Uber, LinkedIn, 카카오, 네이버, 쿠팡, 토스 등)
- 마이크로서비스 100+ 개
- 실시간 분석 / ML feature store
- 검색 인덱스 동기화 (Elasticsearch)

### 4.2 안 맞는 곳
- 소규모 서비스 (Kafka 클러스터 운영 부담)
- 모놀리식 (DB 1 + 앱 1 이면 불필요)
- 레거시 (Trigger·배치 SQL 로 충분)
- 금융권 코어 (검증된 상용 솔루션 선호 — Oracle GoldenGate 등)

### 4.3 대안들
| 방식 | 특징 |
|---|---|
| **Debezium + Kafka** | 오픈소스 표준 |
| **AWS DMS** | AWS 매니지드 |
| **GCP Datastream** | GCP 매니지드 |
| **Oracle GoldenGate** | 상용. 금융권 |
| **Maxwell, Canal** | MySQL 전용 (Canal = 알리바바) |
| **Outbox 패턴** | 앱이 outbox 테이블에 쓰고 Debezium 추적 |
| **트리거 + 큐 테이블** | 옛날 방식 |
| **배치 ETL** | 야간 동기화. 실시간 X |
| **이중 쓰기** | 안티패턴 (정합성 깨짐) |

---

## 5. Wadiz repos 실측 — 22 repo 中 단 1개만 사용

### 5.1 결과
| 항목 | 값 |
|---|---|
| Kafka 의존성 있는 repo | **`kr.wadiz.user.link` 1개** |
| Kafka Producer 코드 (`KafkaTemplate.send`) | 모든 repo 에서 **0건** |
| Kafka Consumer | user.link 의 **17개** |
| CDC 도구 명시 | user.link 코드 주석에 "Debezium kafka를 Consume" |

### 5.2 컨슘 토픽 17개
```
backing-payment, block, blocked-campaign,
store-order, store-project, store-project-setting,
reward-coming-soon-applicant, reward-satisfaction, store-satisfaction,
follow,
user, user-wish-project, user-recommendation-rejection,
campaign, miniboard, signature
```

### 5.3 데이터 흐름
```
[다른 서비스 DB (MySQL binlog 등)]
   ├ funding DB
   ├ reward DB
   ├ user DB
   ├ store DB
   ├ campaign DB
   └ ...
        │ CDC
        ↓
   [Debezium] ← 별도 인프라 (Wadiz repo 에 코드 없음)
        ↓
   [Kafka 17 토픽]
        ↓ @KafkaListener (0.5초 폴링)
   [kr.wadiz.user.link]
        ↓ 가공
   [Neo4j 유저 관계 그래프]
```

### 5.4 user.link 의 실제 폴링 설정
```yaml
# kr.wadiz.user.link/src/main/resources/application.yml
max-poll-records: 100
```
+ Spring Kafka 기본값:
- `fetch.max.wait.ms`: 500ms
- `fetch.min.bytes`: 1 byte

→ **0.5초 주기로 폴링, 메시지 도착 시 즉시 가져와 Neo4j 갱신.** 사람 시간 기준으로는 거의 실시간.

---

## 6. 다른 21 repo 의 통신 방식 — 압도적으로 REST 동기

| 통신 방식 | 사용량 | 특징 |
|---|---|---|
| **REST 동기** (`RestTemplate`/`FeignClient`/`WebClient`) | com.wadiz.web 147 files, adm 47, wave.user 34, account 19, startup 15 등 | 호출자가 응답 기다림. 결합도 높음 |
| **Internal Callback** (`/api/internal/...`) | 31 endpoint | 비동기 작업 결과 통보 (예: AI Review) |
| **ApiProxyServlet** | com.wadiz.web `/web/apip/*` | FE → 마이크로서비스 게이트웨이 |
| **DB 직접 공유** | 일부 레거시 | 같은 MySQL 을 여러 서비스가 read/write |
| **CDC (Kafka)** | user.link 1개만 | 본 보고서 주제 |

---

## 7. 왜 user.link 만 Kafka 선택했나 — 5가지 조건 동시 만족

| 조건 | user.link | 다른 서비스 |
|---|---|---|
| **다대다 fan-out** (N 도메인 → 1 시스템) | ✅ 17 → 1 | ❌ 대부분 1:1 |
| **결과적 일관성 OK** (수초 지연 허용) | ✅ 그래프는 추천용 | ❌ 결제는 즉시 |
| **백필·재구축 빈번** (ML 알고리즘 변경) | ✅ Kafka 보관 기간 내 재소비 가능 | ❌ 거의 없음 |
| **누락 무관용** (1건 빠지면 그래프 왜곡) | ✅ Kafka at-least-once | 🟡 결제는 트랜잭션으로 보장 |
| **DB 본질이 이벤트 친화적** | ✅ Neo4j = 관계 그래프 = 이벤트 자연 입력 | ❌ MySQL 은 그냥 CRUD |

### 만약 REST 였다면 (반례)
- 17개 도메인 코드에 **각각 user.link 호출 코드 추가**
- user.link URL/스키마 변경 시 **17곳 동시 수정**
- user.link 다운 시 funding 트랜잭션을 실패시킬지(❌ 결합도) 무시할지(❌ 누락) 딜레마

### Kafka 로 한 결과
- 17개 도메인은 **user.link 존재를 모름**
- 자기 DB 만 잘 쓰면 됨 — Debezium 이 자동 발행
- user.link 가 알아서 토픽 폴링해서 그래프 갱신
- **결합도 0**

---

## 8. Neo4j 의 역할 — "통계" 가 아니라 "관계 상태"

### 8.1 용도 비교
| 용도 | 적합한 DB |
|---|---|
| 주기적 통계·집계 (일일/월별 리포트) | BigQuery, Snowflake, ClickHouse |
| **실시간 관계 탐색** (친구의 친구, 추천) | **Neo4j (그래프 DB)** |
| 키 기반 조회 | MySQL, Redis |
| 텍스트 검색 | Elasticsearch |

### 8.2 Neo4j 가 잘하는 쿼리 예시
```cypher
// 추천: 내 친구의 친구가 펀딩한 캠페인
MATCH (me:User {id:7})-[:FOLLOWS]->(:User)-[:FOLLOWS]->(friend2:User)
       -[:BACKED]->(c:Campaign)
RETURN c, count(*) AS score
ORDER BY score DESC LIMIT 10
```
이런 **"몇 단계 떨어진 관계"** 쿼리는 RDB 로 하면 JOIN 폭발. Neo4j 는 native 로 빠름.

### 8.3 정확한 용어 정리
- ❌ "통계 데이터"
- ✅ **"머티리얼라이즈드 뷰"** (DB 용어)
- ✅ **"관계 그래프 스냅샷 (실시간 갱신)"**

각 도메인 raw 데이터(MySQL)는 사방에 분산돼 있는데, **user.link 가 그걸 한 곳에 모아 그래프 형태로 항상 최신 유지**.

---

## 9. 최종 결론

> **"Wadiz 는 대부분 REST 동기 호출로 통신한다. 단 17개 도메인의 변경을 종합해 유저 관계 그래프(Neo4j)를 실시간 유지해야 하는 `kr.wadiz.user.link` 만, 결합도 0 + 누락 0 + 재처리 가능 + 결과적 일관성이라는 4가지 조건을 동시에 충족하는 Debezium + Kafka 를 채택. user.link 컨슈머 17개가 0.5초 주기로 폴링하며 거의 실시간으로 그래프를 갱신한다."**

### 핵심 인사이트
- **Kafka 는 만능이 아니라 특정 문제 해결 도구** — Wadiz 도 그 원칙대로 사용
- 1:1 동기 호출이면 REST 가 더 단순·빠름
- 다대다 fan-out + 결과적 일관성 + 누락 무관용 조합에서만 Kafka 의 강점이 발휘됨
- CDC 의 가장 큰 미덕: **다른 서비스 코드 0줄 변경**으로 데이터 흐름 추가

---

## 참고
- 분석 대상 repo: `kr.wadiz.user.link/src/main/`
- Kafka 설정: `kr.wadiz.user.link/src/main/resources/application.yml`
- Debezium CDC 명시: `kr.wadiz.user.link/src/main/java/kr/wadiz/user/link/util/UserCacheKeyGenerator.java`
- Wadiz repo 이정표: [`../../CLAUDE.md`](../../CLAUDE.md)
