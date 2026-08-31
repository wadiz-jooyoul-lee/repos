# com.wadiz.api.friends 분석 문서

> 와디즈 **친구(Friends) 서비스** API 서버입니다. 저장소 설명은 "친구 서비스 (과거 피드 서비스)" — 원래 피드(Feed) 서비스로 만들어졌다가 친구 서비스로 이름이 바뀐 내력이 코드 곳곳에 남아 있습니다(패키지 `com.wadiz.friends`, 내부 모델·서비스는 대부분 `feed` 네이밍).
> Org: `wadiz-service` (`https://github.com/wadiz-service/com.wadiz.api.friends.git`). Gradle 루트 프로젝트명 `friends`, 배포 이름 `friends-api`.

> 📅 분석 기준: 2026-08-31 clone, **`master` 브랜치**(`4e58fbb`, 2026-08-19). Java 파일 150개, 테스트 1개.

---

## ⚠️ 기준 브랜치 주의 — `cloud_live` 가 아니라 `master`

다른 레포와 달리 이 저장소는 **`cloud_live` 브랜치가 버려진 상태**입니다. 문서·작업 기준은 `master` 입니다.

| 근거 | 내용 |
|---|---|
| 브랜치 관계 | `cloud_live` 는 `master` 대비 **ahead 5 / behind 8**, 마지막 커밋이 2026-06-05 로 약 3개월 정체 |
| 클라우드 이관 위치 | 클라우드 마이그레이션(DISPLAY-1479)·clive 워크플로·ES/OpenSearch 듀얼 지원이 **`master` 에** 들어 있습니다. `cloud_live` 의 마이그레이션은 그보다 앞선 DISPLAY-334 판이라 구버전입니다 |
| 배포 워크플로 | `master` 의 `.github/workflows/aws_deploy_ecr_live.yml` 이 **`master` push 를 트리거**로 `display-platform/clive/friends-api.yaml` 의 이미지 태그를 갱신합니다. 즉 **master = 클라우드 라이브(clive) 배포선** |

`com.wadiz.api.funding` 과 같은 패턴입니다(클라우드 브랜치가 정리되고 master 가 현행선).

---

## 개요

- 와디즈 앱·웹의 **서포터 피드(친구 활동 피드)** 를 만들어 내려주는 서비스입니다. 내가 팔로우한 사람의 펀딩 참여·찜·오픈예정 신청·주문 같은 **행동(액션형)** 과 만족도·후기 같은 **콘텐츠형** 활동을 모아 카드 목록으로 제공합니다.
- 데이터 저장소는 **RDB 가 아니라 Elasticsearch/OpenSearch** 입니다. `DataSourceAutoConfiguration` 을 명시적으로 제외해 JPA 데이터소스를 아예 띄우지 않습니다 (`application.yml`).
- 부가로 **피드 푸시 대상 필터링/메시지 생성**, **광고 카드 조회**, **유저 추천** 을 담당합니다.

### 주요 기능 묶음

| 묶음 | 설명 |
|---|---|
| 서포터 피드 | 안읽은 피드·기본 피드·필터·안읽은 수·커서 관리 (`/api/friends/supporter/feeds/*`) |
| 친구 활동 | 친구 활동 요약 조회 (`/api/friends/activities`) |
| 피드 푸시 | 푸시 대상 필터·메시지 생성·발송 이력 (`/api/friends/push/feeds/*`) |
| 광고 | 섹션코드별 광고 카드 조회 (`/api/friends/advertisement/{sectioncode}`) |
| 점검·디버그 | `GreetController` (`/api/friends/greet/*`) |

## 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 언어/런타임 | **Java 8** (`eclipse-temurin:8` 베이스 이미지) | `build.gradle` jib 설정 |
| 프레임워크 | **Spring Boot 2.7.18**, Spring Cloud 2021.0.3 | `gradle.properties` |
| 빌드 | Gradle (단일 모듈), **Jib 3.4.4** 로 컨테이너 이미지 생성(OCI), `bootJar` 병행 | `build.gradle` |
| 포트 | **9510** | `application.yml:2` |
| 검색엔진 | **Elasticsearch 7.4.0** (RestHighLevelClient) + **OpenSearch `opensearch-java` 3.1.0** 듀얼 지원 | `build.gradle` |
| 캐시 | **Ehcache 3.8.1** (JSR-107 `javax.cache`), `classpath:ehcache.xml` | `application.yml` |
| 서비스 디스커버리 | Consul (`spring-cloud-starter-consul-discovery`) — 단 `spring.cloud.consul.enabled: false` 로 **기본 비활성** | `application.yml` |
| 쿠버네티스 설정 | `spring-cloud-starter-kubernetes-client-config` — ConfigMap `common-config`·`friends-api` 를 읽음 | `bootstrap-kubernetes.yml` |
| 회복성 | Resilience4j CircuitBreaker (`recentFeeds` 인스턴스) | `application.yml` |
| API 문서 | springdoc-openapi-ui 1.7.0 | `build.gradle`, `config/SwaggerConfig.java` |
| 기타 | ModelMapper 1.1.1, commons-io 2.4, Lombok, 사내 `com.wadiz.wave:wave-crypto 1.0.3-SNAPSHOT` | `build.gradle` |
| 아티팩트 저장소 | 사내 Nexus(`repo.wadizcorp.com`, **HTTP 허용**) + GitHub Packages(`wadiz-repo/maven-releases`) | `build.gradle` |

## 검색엔진 추상화 (ES ↔ OpenSearch)

DISPLAY-1479(클라우드 마이그레이션)에서 도입된 구조로, **`search.engine` 프로퍼티 하나로 런타임 전환**합니다.

```
client/SearchClient.java              # 인터페이스 (search 2종 + index)
├── elasticsearch/ElasticsearchSearchClient.java   @ConditionalOnProperty search.engine=elasticsearch (matchIfMissing=true)
└── opensearch/OpenSearchSearchClient.java         @ConditionalOnProperty search.engine=opensearch
config/ElasticSearchConfig.java / OpenSearchConfig.java   # 같은 조건으로 빈 구성 분기
service/common/ElasticESCommonServiceImpl.java / OpenSearchCommonServiceImpl.java
```

- 기본값은 `search.engine: elasticsearch` 이고, `matchIfMissing = true` 라 프로퍼티가 없으면 ES 구현이 뜹니다 (`application.yml:4`).
- 응답은 엔진 중립 모델 `client/model/SearchEngineResponse`·`SearchEngineHit` 으로 감싸 서비스 계층이 엔진을 모르게 합니다.
- `com.wadiz.wave.searcher` 도 같은 시기에 동일한 방향(검색엔진 추상화 → OpenSearch)으로 전환했습니다.

## 사용하는 인덱스

| 인덱스(별칭) | 용도 |
|---|---|
| `integrate_feeds-alias` | 통합 피드 — 피드 카드의 주 조회 대상 |
| `supporter_activity_feeds` / `-alias` | 서포터 활동 피드 |
| `last_entered_feeds` / `-alias` | 마지막 진입 시각(안읽은 피드 커서 기준). 월 단위 인덱스 `last_entered_feeds-yyyyMM` 로 생성 후 별칭 갱신 |
| `push_history_feeds` / `-alias` | 푸시 발송 이력 |
| `popular_index` | 인기 지표 |

인덱스 매핑 정의는 `src/main/resources/mapping/lastEnteredFeeds.json`·`pushHistoryFeeds.json` 에 있고, `index.mapping.*` 프로퍼티로 주입됩니다.

**스케줄러**는 하나뿐입니다 — `handler/ScheduledHandler.timerBulkLastEnteredFeeds()` 가 **30초 고정 주기**(`@Scheduled(fixedRate = 30000)`)로 메모리에 모아둔 "마지막 진입" 업데이트 요청을 ES 에 bulk 로 밀어 넣습니다. 이때 당월 인덱스가 없으면 만들고 별칭을 옮깁니다 (`ScheduledHandler.java:32-49`).

## API 엔드포인트

컨트롤러 **5개 · 엔드포인트 18개**입니다(SupporterFeed 6 · Greet 6 · FeedPush 4 · FriendActivity 1 · Advertisement 1). 공통 base 는 `/api/friends`.

### `SupporterFeedController` — `/api/friends/supporter/feeds`

| HTTP | 경로 | 메서드 | 용도 |
|---|---|---|---|
| POST | `/recent` | `recentFeeds` | 안읽은 피드 조회. `@CircuitBreaker(name="recentFeeds")` 적용 |
| POST | `` | `defaultFeeds` | 기본 피드 조회 |
| POST | `/following` | `findFilters` | 팔로잉 기준 필터 목록 |
| POST | `/unread/count` | `unreadCount` | 안읽은 피드 수 |
| GET | `/cusor` | `currentCursor` | 현재 커서(마지막 진입 시각) 조회 ※ 경로 오타 `cusor` 그대로 |
| GET | `/cusor/update` | `updateCursor` | 커서 갱신 |

- 헤더 `encUserId`(암호화 회원 식별값, 기본 0)·`wadiz-language`(기본 `ko`)·`wadiz-country`(기본 `KR`)를 받습니다.
- `/recent` 는 **비로그인이거나 필터가 걸려 있으면 빈 배열**을 반환하고, 첫 진입이면 ES 에서 마지막 진입 시각을 조회해 커서로 씁니다. 커서가 없으면 역시 빈 배열입니다 (`SupporterFeedController.java:44-69`).
- 서킷이 열리면 `fallback` 두 개가 빈 응답을 돌려줍니다 (`:71,80`).

### `FriendActivityController` — `/api/friends/activities`

| HTTP | 경로 | 용도 |
|---|---|---|
| GET | `` | 친구 활동 조회. 헤더 `encUserId` **필수** |

### `FeedPushController` — `/api/friends/push/feeds`

| HTTP | 경로 | 용도 |
|---|---|---|
| POST | `/filters` | 푸시 대상 userId 목록 필터링 |
| POST | `/messages` | 푸시 메시지 목록 생성 |
| POST | `/update` | 푸시 발송 이력 기록 |
| POST | `/history` | 푸시 발송 이력 조회 |

### `AdvertisementController` — `/api/friends/advertisement`

| HTTP | 경로 | 용도 |
|---|---|---|
| GET | `/{sectioncode}` | 섹션코드별 광고 카드 조회 |

### `GreetController` — `/api/friends/greet`

점검·디버그용으로 보이지만 **clive 에서 외부로 열려 있습니다.** helm-charts 의 `display-platform/clive/friends-api.yaml`(23줄) AuthorizationPolicy 는 `remoteIpBlocks: 0.0.0.0/0`·`::/0` 만 두고 **경로 제한(`to.operation.paths`)도 토큰 조건(`when`)도 없습니다.** 따라서 `api.wadiz.io` 의 `friends` subPath 를 통해 `/api/friends/greet/*` 도 그대로 도달합니다. 이 중 `/user-id`·`/user-id/recommend`·`/feeds/action`·`/feeds/contents` 는 **인증 없이 쿼리 파라미터 `userId` 만으로 남의 피드·추천 결과를 조회**할 수 있는 형태입니다 — 확인·차단 검토가 필요합니다.

| HTTP | 경로 | 용도 |
|---|---|---|
| GET | `` | hello |
| GET | `/user-id` | `userId` 로 조회 확인 |
| GET | `/user-id/recommend` | 유저 추천 결과 확인 |
| GET | `/user-id/header` | 헤더 `encUserId` 복호화 확인 |
| GET | `/feeds/action` | 액션형 피드 조회 확인 |
| GET | `/feeds/contents` | 콘텐츠형 피드 조회 확인 |

## 피드 종류 (`model/feed/FeedType`)

```java
SATISFACTION, REVIEW, FOLLOWER_SUPPORT,                    // 콘텐츠형 피드
PROJECT_OPEN, MAKER_RECOMMEND, MAKER_NEWS, MAKER_VOTE,     // 미사용 (주석 명시)
FOLLOWER_FUNDING, FOLLOWER_LIKE,
FOLLOWER_COMING_SOON_APPLICANT, FOLLOWER_ORDER             // 액션형 피드
```

- 11종 중 **4종(`PROJECT_OPEN`·`MAKER_RECOMMEND`·`MAKER_NEWS`·`MAKER_VOTE`)은 코드 주석에 "미사용"으로 명시**돼 있습니다.
- enum 에 `// 새로 만드는게 좋을 듯.(FE논의 필요)` 라는 정리 필요 메모가 남아 있습니다.

## 외부 연동

`RestTemplate` 기반이며 대상 URL 은 전부 프로퍼티로 주입됩니다.

| 대상 | 프로퍼티 | 호출부 |
|---|---|---|
| 광고 API | `advertisement-api.base-url`, `advertisement-api.sectioncode-ad-url` | `service/feed/advertisement/AdvertisementAdapter` |
| 스타트업(투자) API | `startup-api.base-url`, `startup-api.maker-info-by-campaign`, `startup-api.maker-info-by-corpno` | `service/feed/maker/MakerApiService` |
| 유저 API | `user-api.feed-user-info` | `service/user/UserRecommendationService`, `service/follow/FollowUserServiceImpl` |

> **DISPLAY-1677(2026-08-06)**: 서포터 피드가 startup 의 `/feeds/contents/all` 을 호출하던 경로를 제거했습니다. 이미 startup 쪽에서 폐기돼 404 만 남기고 카드가 누락되던 경로라 **동작에는 변화가 없습니다(behavior-neutral)**. `FeedContentsApiService`(83줄) 삭제, `FeedType` 에서 관련 값 제거, `CacheConfig`·`FeedServiceImpl` 정리 (`34a3328`).

## 소비처

| 소비처 | 호출 경로 | 근거 |
|---|---|---|
| wadiz-android | `GET /api/friends/activities` | `core/network/.../WadizServiceAPIService.kt:87` (클라우드용 `CloudWadizServiceAPIService.kt` 별도 존재) |
| wadiz-ios | base 경로를 배포 정책에 따라 분기 — 클라우드면 `/friends/api/friends`, 아니면 `/api/friends` | `Projects/Core/.../APIService.swift:39-40` |
| wadiz-frontend | `@wadiz/api/friends` 패키지(`friendsService`) 경유. BNB 배지 카운트·피드 화면에서 사용 | `packages/ui/src/BottomNavigationBar/lib/useFriendsBadgeCount.ts`, `packages/features/src/feed/lib/feedHelpers.ts` |

## 배포

| 환경 | 트리거 브랜치 | 갱신 대상 values | 워크플로 |
|---|---|---|---|
| dev | `dev` | `display-platform/dev/friends-api.yaml` | `.github/workflows/aws_deploy_ecr_dev.yml` |
| clive(클라우드 라이브) | **`master`** | `display-platform/clive/friends-api.yaml` | `.github/workflows/aws_deploy_ecr_live.yml` |

- 두 워크플로 모두 `wadiz-gitops/workflows-container-image-build-push` 재사용 워크플로를 호출합니다. ECR: `393290902814.dkr.ecr.ap-northeast-2.amazonaws.com/display-platform/friends-api`, `java-version: '8'`.
- 쿠버네티스 배포 스펙은 [`helm-charts`](./helm-charts.md) 의 `charts/service/values/display-platform/{env}/friends-api.yaml` 에 있습니다. clive 기준 `containerPort: 9000`, `requestsMemory: 1Gi`, `virtualService.subPath: friends`, CORS `https://www.wadiz.io` 허용.
- **운영 실제 설정은 [`helm-charts-gitops`](./helm-charts-gitops.md) 의 같은 경로 values 파일에 있습니다.** clive 기준으로 확인된 값:
  - `server.port: 9000` — 소스의 기본값 9510 을 ConfigMap 이 덮어씁니다(포트 불일치의 답).
  - **`search.engine: opensearch`** — 즉 clive 에서는 ES 가 아니라 **OpenSearch 로 떠 있습니다.** 소스 기본값(`elasticsearch`)만 보고 판단하면 안 됩니다.
  - ES 접속은 `${commonConfig.opensearch.url}` · port 443 · shard 1 · replica 2, 계정 `wadiz_friends`, 비밀번호는 치환자 `${es_pw_wadiz_friends}` (평문 아님).
  - Consul 은 `enabled: false`, 외부 API 주소는 `${commonConfig.service.user-api}`·`.startup-api`·`.ad-api` 로 주입, 로깅 레벨 `com.wadiz.friends: INFO`(소스 기본값 DEBUG 를 덮어씀).
  - 현재 이미지 태그 `main-202608241952-a960c2b2`.
- 별도로 `friends-api-service` values 가 있어 `service.wadiz.kr` 호스트의 `api/friends` 경로를 `friends-api` 로 넘깁니다(라우팅 전용, DestinationRule·ConfigMap 비활성).

## ⚠️ 주의: 설정 파일에 평문 자격증명이 있습니다

`src/main/resources/application.yml` 의 `spring.data.elasticsearch.user-name`·`user-password` 에 **Elasticsearch 계정과 비밀번호가 평문으로 커밋**돼 있습니다(사내 IP `192.168.1.186:9200` 과 함께). 이 문서에는 값을 옮기지 않았습니다. 저장소 내용을 인용·공유할 때 딸려 나가지 않도록 주의하세요.

또한 사내 Nexus 저장소를 `allowInsecureProtocol = true` 로 **HTTP** 로 참조합니다 (`build.gradle`).

## 최근 변경 이력 (master 기준)

| 날짜 | 이슈 | 내용 |
|---|---|---|
| 2026-08-19 | — | `application-live.yml` 제거 (클라우드 ConfigMap 으로 이관) |
| 2026-08-06 | DISPLAY-1677 | 서포터 피드의 폐기된 startup 콘텐츠 호출 제거(동작 무변화), 로컬 실행 프로필 정비 및 미사용 DataSource 자동설정 제외 |
| 2026-06-10 | DISPLAY-1479 | clive 배포 워크플로 추가 |
| 2026-05-28 | DISPLAY-1479 | **AWS EKS 배포를 위한 클라우드 마이그레이션**, Elasticsearch/OpenSearch 듀얼 지원 추가, `application-local.yml` 을 dev 환경으로 정렬 |
| 2025-09-09 | — | 언어 및 국가 코드 지원 추가 |
| 2025-08-27 | — | 쿠폰 보유 여부 필드 추가 |

## 미확인 항목

- **테스트가 사실상 없습니다**(테스트 Java 파일 1개). 회귀 안전망이 없는 상태입니다.
- ~~피드 카드를 만드는 원천 데이터(누가 `integrate_feeds` 인덱스에 색인하는지)~~ → **해소(2026-09-01)**: [`indexer-geojedo`](./com.wadiz.search.indexer-geojedo.md) 가 채웁니다. `integrate_feeds`·`supporter_activity_feeds`·`maker_activity_feeds`·`last_entered_feeds`·`push_history_feeds` 를 스케줄러 14종으로 색인하며, 이 저장소는 조회와 `last_entered`·`push_history` 색인만 담당합니다.
