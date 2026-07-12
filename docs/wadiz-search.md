# wadiz-search — ElasticSearch Indexer 서버군 (3 repo)

> `wadiz-search` org 소속 3개 Spring Boot 인덱서 서비스. **MySQL → ES 색인 파이프라인의 실제 소스**로, 그동안 `kafka-cdc-and-user-link.md` 와 `_flows/feed.md` 에서 "wave.searcher ES 인덱스가 어떻게 채워지는지 미확인" 이라고 표기했던 그 파이프라인의 실증 서비스입니다.
>
> - 지도 이름 컨벤션: **한국 섬 이름** (dokdo, geojedo). 아마 신구 색인기의 blue/green 병행 배치용.

## Repo 요약표

| Repo | 색인 도메인 | Kafka Listener | 소스 위치 힌트 |
|---|---|---|---|
| `com.wadiz.search.indexer-dokdo` | 통합·카테고리·팔로우·피드·스토어 | ✓ (UserSearchEventListener) | `resources/mapping/{category,integrate,follow,feed}` + `mapper/{wadiz,follow,store}` |
| `com.wadiz.search.indexer-geojedo` | 통합·팔로우·피드·유저·위시·메이커·리액션 | ✓ (SignatureListener 등) | `resources/mapping/{reaction,integrate,follow,user,user/wish,feed,maker}` + `mapper/wadiz` |
| `indexer-startup` | 스타트업(투자형) 전용 | (없음, MyBatis 만) | `resources/mapper/`, v1/v2 handler 병존 |

모두 **Spring Boot / Java 8** (build.gradle 의 `sourceCompatibility = 1.8`), Boot 버전은 `gradle.properties` 의 공용 `spring_boot_version` 변수 참조.

---

## 1. `com.wadiz.search.indexer-dokdo` — 메인 통합 인덱서

**메인 클래스**: `com/wadiz/search/indexer/dokdo/IndexerApplication.java`

**색인 대상 도메인** (`resources/mapping/` 서브폴더):
- `category/` — 카테고리
- `integrate/` — 통합검색
- `follow/` — 팔로우 그래프
- `feed/` — 친구 피드

**DB 매퍼** (`resources/mapper/`):
- `wadiz/` — 메인 스키마
- `follow/` — 팔로우 스키마 (`wadiz_wave_follow`)
- `store/` — 스토어 스키마

**Kafka Consumer**: `consumer/UserSearchEventListener.java` — 유저 이벤트 수신 후 ES 재색인

## 2. `com.wadiz.search.indexer-geojedo` — 확장 인덱서

**메인 클래스**: `com/wadiz/search/indexer/geojedo/IndexerApplication.java`

**색인 대상** (dokdo 대비 확장):
- reaction, integrate, follow, feed
- **`user`, `user/wish`** — 유저·위시 (dokdo 에는 없음)
- **`maker`** — 메이커 (dokdo 에는 없음)

**Kafka Consumer**: `listener/feed/SignatureListener.java` — 지지서명 이벤트 수신

→ **dokdo → geojedo 로 도메인 확장/리라이트 진행 중** 추정 (섬 이름 컨벤션이 세대 구분자 역할).

## 3. `indexer-startup` — 스타트업(투자) 전용

**메인 클래스**: `com/wadiz/search/indexer/startup/IndexerStartupApplication.java`

**구조**:
- `handler/` — v1 핸들러
- `v2/` — v2 핸들러 (마이그레이션 진행 흔적)
- MyBatis 매퍼만 (`resources/mapper/`), Kafka Consumer 없음

→ 배치 스케줄 기반 재색인 추정 (본 repo 내 `@Scheduled` 미확인, 외부 트리거 가능성).

---

## 파이프라인 종합 (실증 완료)

이 3개 인덱서가 있는 지점을 반영해 CDC 흐름을 갱신:

```
[MySQL master 172.31.1.230:8450]
     │
     ├───► binlog → Debezium (wa-infrastructure/cdc)
     │      │
     │      ▼
     │   [Kafka 16 topics]
     │      │
     │      ├─► kr.wadiz.user.link (Neo4j 그래프)
     │      │
     │      └─► com.wadiz.search.indexer-{dokdo,geojedo} (Kafka Consumer)
     │             │
     │             ▼
     │          [ElasticSearch 인덱스]
     │             ▲
     │             │ 폴링/증분 색인 (MyBatis)
     ├──────────────┘  ← indexer-startup, indexer-dokdo/geojedo 배치성 색인
     │
[com.wadiz.wave.searcher] ─────── ES 읽기 (검색 서빙)
     · /api/search/feeds
     · /api/search/feed
     · /api/search/push/feeds
     · /api/search/following/maker/products
```

- **dokdo/geojedo** 는 CDC Kafka + MyBatis 폴링 **양쪽** 지원 (mapper 폴더 + Kafka listener 공존)
- **wave.searcher** 는 이 인덱서들이 채운 ES 를 읽기만 함 (read-side 서버)

## 문서 갱신 대상

이 발견으로 아래 문서들의 "미확인" 표기를 실증 근거로 갱신 가능:

- `docs/_concepts/kafka-cdc-and-user-link.md` — "user.link 외의 컨슈머" 에 wadiz-search 인덱서 3종 추가
- `docs/_flows/feed.md` §11.1 "wave.searcher ES 인덱스 적재 ETL 파이프라인 위치 — 여전히 미확인" → 실증 완료
- `docs/com.wadiz.wave.searcher.md` — 인덱스 소스 서비스로 wadiz-search 3 repo 링크

## 관측 한계

- 각 인덱서의 실제 배포 매니페스트 (Kubernetes/ECS) 는 본 repo 에 없음
- `indexer-startup` 의 배치 트리거 위치 미확인 (외부 스케줄러 추정)
- ES 인덱스 alias 관리(`user_follow-alias` 등) 코드는 wave.searcher 나 별도 툴에 있을 가능성
- dokdo/geojedo 병행 운영 vs 마이그레이션 전략 (blue/green? shadow indexing?) 상세 미확인
