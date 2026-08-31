# com.wadiz.search.indexer-dokdo 분석 문서

> 와디즈 **검색 색인기(indexer)** 입니다. 프로젝트·카테고리·검색홈 피드·해시태그·광고 데이터를 주기적으로 모아 검색엔진에 색인합니다. 검색 서버([`com.wadiz.wave.searcher`](./com.wadiz.wave.searcher.md))가 읽는 인덱스를 **만드는 쪽**입니다.
> Org: `wadiz-search` (`https://github.com/wadiz-search/com.wadiz.search.indexer-dokdo.git`). 배포 이름 `indexer-dokdo`, 플랫폼 `display-platform`.

> 📅 분석 기준: 2026-09-01, **`main` 브랜치**(`f6a0648`, 2026-08-26). Java 173개. README 없음.

> ℹ️ 짝이 되는 색인기가 하나 더 있습니다 — **`indexer-geojedo`**(`wadiz-search/com.wadiz.search.indexer-geojedo`, 기준 브랜치 `master`, Java 155개, 메모리 **4Gi**). 이름만 다른 지명 코드네임이고 둘의 역할 분담은 미확인입니다.

---

## 개요

- **읽기 전용 색인 파이프라인**이 아니라, 스케줄러로 원본을 긁어 색인하고 **수동 실행용 REST API 도 제공**하는 구조입니다.
- 검색엔진은 **Elasticsearch 와 OpenSearch 를 둘 다 지원**합니다(`ElasticsearchConfig` / `OpenSearchConfig`). 2026-07 이후 커밋 대부분이 **OpenSearch 이관 작업**입니다 — 검색 서버(`com.wadiz.wave.searcher`)·친구 서비스(`com.wadiz.api.friends`)와 같은 흐름입니다.
- 코드 활동이 이번에 등록한 22개 중 **2위**(90일 32커밋)로 활발합니다.

## 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 프레임워크 | **Spring Boot 2.7.18**, Spring Cloud 2021.0.8 | `gradle.properties` |
| 저장소 | **MySQL**(`use_mysql=true`) + MyBatis 2.0.1 · Redis 미사용(`use_redis=false`) | `gradle.properties` |
| 검색엔진 | **Elasticsearch + OpenSearch 듀얼** | `config/{Elasticsearch,OpenSearch}Config.java` |
| 캐시 | Ehcache 2.6.9 | `gradle.properties` |
| 기타 | ModelMapper 1.1.1 · Joda-Time 2.9.9 · Guava 18.0 · commons 계열 | `gradle.properties` |
| 빌드/이미지 | Gradle + **Jib 3.4.4** · jacoco · maven-publish | `build.gradle` |
| 아티팩트 저장소 | 사내 Nexus(`repo.wadizcorp.com`, **HTTP 허용**) | `build.gradle` |

## 구조

```
com/wadiz/search/indexer/dokdo/
├── service/     75  ← 색인 로직 본체 (category·follow·feed 등 하위 분리)
├── model/       48
├── repository/  13
├── config/      10  ← Elasticsearch / OpenSearch 구성 분기
├── external/     9
├── schedule/     8  ← 스케줄러 (category·feed·follow 하위 포함)
├── util/         5
├── controller/   2
├── consumer/     1  ← UserSearchEventListener
└── analyzer/     1
```

## 색인 스케줄러

`@Scheduled` 12개 이상이며, **주기·cron 을 전부 설정(`index.scheduler.*`)으로 뺐습니다.**

| 설정 키 | 대상 |
|---|---|
| `index.scheduler.integrate.upsert-delay` / `.daily` / `.daily-multilingual` | 통합 색인(증분·일배치·다국어) |
| `index.scheduler.search-home` | 검색홈 |
| `index.scheduler.funding-category` · `store-category` · `integrate-category` | 카테고리 3종 |
| `index.scheduler.category.additional` · `.project-count` | 카테고리 부가·프로젝트 수 |
| `index.scheduler.project-count-by-group.upsert-delay` | 그룹별 프로젝트 수 |
| `index.scheduler.cast` | cast 색인 |

스케줄러 클래스: `CollectScheduler` · `Scheduler` · `SearchHomeScheduler` · `MetaAdsScheduler` · `ProjectCountByGroupScheduler` + `schedule/{category,feed,follow}` 하위.

**이벤트 소비**: `consumer/UserSearchEventListener` 1개.

## API 엔드포인트 (컨트롤러 2개 · 12개)

| 컨트롤러 | base | EP | 용도 |
|---|---|---:|---|
| `IndexingManualController` | `/api/indexing/manual` | 6 | **색인 수동 실행** — 스케줄을 기다리지 않고 즉시 재색인 |
| `SearchHomeController` | `/api/search-home` | 6 | 검색홈 색인 관련 |

> ⚠️ 수동 색인 실행 API 가 외부 노출 경로(`virtualService.subPath: indexer-dokdo`)에 붙어 있습니다. 접근 통제는 helm values 의 AuthorizationPolicy 를 함께 봐야 합니다(미확인).

## 배포

| 환경 | 트리거 브랜치 | 갱신 대상 values |
|---|---|---|
| **clive** | **`main`** | `display-platform/clive/indexer-dokdo.yaml` |
| dev · rc4 | `dev` · `rc4` | 각 환경 |

- 원격에 `clive` 브랜치가 따로 있으나 **2026-08-11 에서 멈춰 있고**, live 워크플로는 `main` push 를 트리거로 `clive` values 를 갱신합니다. 즉 **`clive` 브랜치는 버려졌고 `main` 이 현행선**입니다(2026-08-26 `GitHub Actions 배포 트리거 브랜치 정리` 커밋으로 확정).
- helm values: `type: api` · `requestsMemory: 2Gi`.

## 최근 변경 (2026-06~08) — OpenSearch 이관이 주제

이슈키 분포: `DISPLAY-1610`(6) · `DISPLAY-1599`(6) · `DISPLAY-1593`(5) · `DISPLAY-1661`(2) · `DISPLAY-1685` · `DISPLAY-1598`

| 날짜 | 내용 |
|---|---|
| 2026-08-26 | GitHub Actions 배포 트리거 브랜치 정리 (→ `main`) |
| 2026-08-11 | OpenSearch 카테고리 색인에 children ordinal 정렬 추가 |
| 2026-08-07 | DISPLAY-1685 — meta 광고 색인의 빈 응답 처리 수정 |
| 2026-07-29 | jib 베이스 이미지를 **jre → jdk** 로 변경 |
| 2026-07-28 | DISPLAY-1661 — 검색홈 피드 색인 **alias 조회 안정화** |
| 2026-07-23 | OpenSearch 프로파일에 메이커 해시태그·해시태그 프로젝트수 색인 추가, 수동 실행 지원 |
| 2026-07-21 | meta_ads·그룹 count 색인을 **엔진 중립 bulk 로 이관**, OpenSearch 클라이언트 매퍼가 unknown 필드를 무시하도록 수정(역직렬화 오류 대응) |

- 흐름이 명확합니다 — **색인 로직을 하나씩 "엔진 중립" 으로 바꿔 OpenSearch 로 옮기는 중**이며, 아직 완료되지 않았습니다(ES 설정이 여전히 함께 존재).

## ⚠️ 확인이 필요해 보이는 점

**원본은 수정하지 않았고 기록만 합니다.**

- **`gradle.properties` 에 Nexus 계정·비밀번호가 평문으로 커밋**돼 있습니다(`nexus_user`·`nexus_cred`). 값은 이 문서에 옮기지 않았습니다. 사내 아티팩트 저장소 publisher 계정으로 보입니다.
- 수동 색인 실행 API(`/api/indexing/manual`, 6개)가 외부 노출 subPath 에 있습니다. 인가 규칙 확인이 필요합니다.

## 미확인 항목

- **`indexer-dokdo` 와 `indexer-geojedo` 의 역할 분담** — 둘 다 검색 색인기이고 규모도 비슷한데(173 vs 155 파일), 무엇을 나눠 맡는지. geojedo 는 기준 브랜치가 `master` 이고 메모리가 4Gi 로 더 큽니다.
- OpenSearch 이관 완료 여부 — clive 에서 실제 어느 엔진을 쓰는지는 [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `configmap.data` 를 봐야 합니다.
- `UserSearchEventListener` 가 소비하는 이벤트 소스(Kafka/Redis 등).
- 색인 대상 인덱스 전체 목록 — 검색 서버 문서([`com.wadiz.wave.searcher.md`](./com.wadiz.wave.searcher.md))의 인덱스와 대조하면 파이프라인 양끝이 맞춰집니다.
- README 가 없어 신규 투입자가 참고할 문서가 저장소 안에 없습니다.
