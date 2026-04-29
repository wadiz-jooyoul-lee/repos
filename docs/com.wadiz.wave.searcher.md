# com.wadiz.wave.searcher

> 와디즈 **검색 서버**. 외부 호스트 `service.wadiz.kr` 의 실체로, FE/앱이 호출하는 `/api/search/v2/*`, `/api/search/v3/*`, `/api/search/v4/*` 와 사내 호출용 `/api/v1/searcher/*` 를 동시에 노출. **ElasticSearch 7.x + MySQL JPA** 하이브리드. Org: `wadiz-service`. Java 패키지: `com.wadiz.wave.searcher`.

> 📅 분석 기준: 2026-04-29 클론, `main` 브랜치 (별도 dev 브랜치 미확인).

## 개요

- 검색·카테고리·피드·메이커 팔로우·소셜 활동·홈카드 등 **읽기 위주** 엔드포인트의 단일 진입점.
- 데이터 출처:
  - **ElasticSearch** (`192.168.1.186:9200` dev / `192.168.1.187:9200` rc) — 검색·집계의 주 저장소
  - **MySQL `wadiz_db`** (master/slave RoutingDataSource) — 카테고리·메이커·기본 메타 직조회 (JPA)
  - **외부 API** — search-ai, main2(추천), startup, funding, store, ad 등
- 자체 ScheduledHandler 는 **검색어/피드 색인만** 담당. **Campaign·Reward 등 메인 도큐먼트 색인은 외부 indexer 가 publish** (본 레포에 색인 코드 없음).

## 기술 스택

- **Java 8** (`sourceCompatibility = 1.8`, `gradle.properties`)
- **Spring Boot 2.1.3.RELEASE**, Spring Cloud `Greenwich.SR1`
- **ElasticSearch 7.x** — 클라이언트는 `org.elasticsearch.action.*` (RestHighLevelClient 시대) 직접 사용
- **JPA** + Hibernate (`spring.jpa.hibernate.ddl-auto: validate`) — MyBatis 미사용 (의존성에는 선언되어 있으나 `@Mapper` 모두 MapStruct, MyBatis SQL 매퍼 없음)
- **Lucene Nori 7.7.2** — 한국어 형태소 분석기 (compound-classpath: `dictionary.dic`)
- **EhCache 2.6.9** (`classpath:ehcache.xml`) — 인메모리 캐시
- **Resilience4j** — 서킷브레이커 (`searchPurchased` 인스턴스 등)
- **Consul Discovery** + Eureka (`192.168.1.216:8500` dev) — service-name `searcher`
- **HikariCP** — master/slave 풀 5/5
- **Wadiz Crypto** (`com.wadiz.wave:wave-crypto`) — 사내 암호화 라이브러리
- 빌드: Gradle, `bootJar` + `application-{env}.conf.script` 인라인 launchScript

## 아키텍처

```
┌────────────────────────────────────────────────────────────────┐
│ com.wadiz.wave.searcher (port 9120)                            │
│                                                                │
│  web/rest/ ── 16 Controllers (FE + 사내)                       │
│      │                                                         │
│      ▼                                                         │
│  core/{category, campaign, integrate, banner}/service          │
│  service/{advertise, follow, feed, homecard, wish, ...}        │
│      │                                                         │
│      ├─ ESCommonService ──► ElasticSearch 7.x                  │
│      │                       (192.168.1.186:9200 dev)          │
│      │                                                         │
│      ├─ JPA Repository ──► RoutingDataSource                   │
│      │                       (master 192.168.0.162:3306        │
│      │                        slave  192.168.0.163:3306)       │
│      │                                                         │
│      └─ External RestTemplate ──► main2 / search-ai /          │
│                                    startup / funding / store / │
│                                    ad / corporation            │
│                                                                │
│  handler/ScheduledHandler                                      │
│      ├─ 10분: 검색어 통계 색인 (search_keyword-{yyyyMM})       │
│      └─ 3분 : last-entered-feeds 색인                          │
└────────────────────────────────────────────────────────────────┘
```

## 컨트롤러 / API 엔드포인트 목록

전체 16개 컨트롤러. FE 가 직접 호출하는 핵심 path 위주 정리.

| Controller | Base path | 비고 |
|---|---|---|
| `CategoryController` | `/api/search/categories`, `/api/search/v2/categories`, `/api/search/v3/categories/service-home`, `/api/search/v4/categories/service-home` | v0/v2/v3/v4 다세대 공존. v4 만 `wadiz-language` + `wadiz-country` 헤더 지원 |
| `SearchController` | `/api/search/v2/funding`, `/api/search/v2/preorder`, `/api/search/v2/fundingSoon`, `/api/search/v2/products`, `/api/search/v2/integrate`, `/api/search/v2/popular/keyword`, `/api/search/v2/integrate/purchased` | 통합·탭별 검색. 앱·웹 공통 |
| `ActivityCampaignController` | `/api/.../campaigns/activity` | 활동 캠페인 |
| `FundingController`, `FundingSoonController` | `/api/.../funding/*` | 펀딩 / 오픈예정 |
| `PreorderController` | `/api/.../preorder/*` | 프리오더 |
| `StoreController` | `/api/.../store/*` | 스토어 검색 |
| `CastController` | `/api/.../cast/*` | 캐스트(소셜) |
| `FeedController`, `MSFeedController`, `SupporterFeedController`, `FeedPushController` | `/api/.../feed/*` | 피드 (메이커·서포터·푸시) |
| `MakerFollowController` | `/api/.../makers/follow/*` | 메이커 팔로우 |
| `InternalSearchController`, `MembershipSalesController` | `/api/internal/*` | 사내 service 간 호출 |

### 핵심 엔드포인트 — `/api/search/v2/categories`

```java
// web/rest/category/CategoryController.java:46
@RestController
@RequestMapping("/api")
public class CategoryController {
    @GetMapping("/search/v2/categories")
    public ApiCommonResponse<List<CategoryResponse>> getGlobalCategories(
            CategorySearchRequest request,
            @RequestHeader(value = "wadiz-language", required = false, defaultValue = "en") String languageCode) {
        List<CategorySearchResult> results = categorySearchService.searchCategoryInfo(
            request.getServiceType(), ProjectType.ALL, languageCode, request.getCategoryCode());
        return ApiCommonResponse.success(CategoryPayloadConverter.INSTANCE.convert(results));
    }
}
```

`CategorySearchService.searchCategoryInfo` (`core/category/service/CategorySearchService.java:314`) 가 ES 인덱스 `Const.CATEGORY_PROJECT_COUNT_INDEX` 에 BoolQuery 를 날려 결과를 가져온 뒤 `serviceType` 으로 후필터링한다 (DB 조회 없음).

## 데이터 저장소

### ElasticSearch 인덱스

| 인덱스 (alias) | 용도 | 색인 주체 |
|---|---|---|
| `category_project_count` | 카테고리별 프로젝트 수 (`/api/search/v2/categories`) | **외부 indexer** (본 레포 외) |
| `integrate_category-alias` | 통합 카테고리 매핑 (`model/campaign/IntegrateCategory.INDEX_ALIAS`) | 외부 indexer |
| `search_keyword-alias` (`search_keyword-{yyyyMM}`) | 검색어 통계 (10분 단위 bulk) | **자체 `ScheduledHandler.timerBulkSearchKeyword`** |
| `last_entered_feeds-alias` (`last_entered_feeds-{yyyyMM}`) | 사용자별 최근 피드 진입 (3분 단위 bulk) | **자체 `ScheduledHandler.timerBulkLastEnteredFeeds`** |
| `push-history-feeds` | 푸시 이력 피드 | (mapping 만 정의) |
| (Campaign·Reward·Maker 도큐먼트) | 검색·카드 표시용 | **외부 indexer** — 본 레포에 코드 없음 |

⚠️ Campaign·Reward 도큐먼트의 publisher 는 본 레포에 없음. 후보:
- 별도 repo (예: `searcher-indexer`, `wave-indexer`)
- Kafka CDC (Debezium) — MySQL binlog → ES
- `com.wadiz.api.funding` 등의 도메인 이벤트 publish

### MySQL (RoutingDataSource)

`config/JdbcConfig.java:17-50` 에서 master/slave 두 개의 HikariDataSource 를 각각 Bean 으로 등록하고 `RoutingDataSource` 로 라우팅. `LazyConnectionDataSourceProxy` 로 감싸 트랜잭션 시점까지 커넥션 획득 지연.

| Bean | URL (dev) | 용도 |
|---|---|---|
| `wadizMasterDataSource` | `jdbc:mysql://192.168.0.162:3306/wadiz_db` | 쓰기 + RW 트랜잭션 (현실적으로 검색 서버라 거의 사용 안 함) |
| `waidzSlaveDataSource` | `jdbc:mysql://192.168.0.163:3306/wadiz_db?...` (read-only) | 읽기 (메이커 / 카테고리 / 캠페인 메타 JPA 조회) |

`naming.physical-strategy: WadizDbNamingStrategy` — 와디즈 사내 컬럼명 컨벤션을 JPA 엔티티에 매핑.

## 자체 색인 작업 (`ScheduledHandler`)

```java
// handler/ScheduledHandler.java
@Scheduled(fixedRate = 600000)               // 10분
public void timerBulkSearchKeyword() {
    List<IndexRequest> indexRequestList = SingleTon.getInstance().getIndexRequestList(...);
    // index 이름: search_keyword-{yyyyMM}
    // 없으면 createIfNotExist + updateAlias(SEARCH_KEYWORD_ALIAS)
    esCommonService.bulk(bulkRequest);
}

@Scheduled(fixedRate = 180000)               // 3분
public void timerBulkLastEnteredFeeds() {
    Collection<UpdateRequest> indexRequestList = SingleTon.getInstance().getLastEnteredRequestList();
    // index 이름: last_entered_feeds-{yyyyMM}
    esCommonService.bulk(bulkRequest);
}
```

검색 요청이 들어올 때마다 `SingleTon` 에 IndexRequest 가 누적되고, 스케줄러가 주기적으로 비워서 ES 에 bulk 적재.

**중요**: 이 두 개가 자체 색인 작업의 전부다. **Campaign 도큐먼트 색인은 여기 없다.**

## 외부 의존성 (dev 기준)

`application-dev.yml` 에서 호출하는 외부 호스트:

| 의존 | URL | 용도 |
|---|---|---|
| `user-api` | `http://dev-app01:9990/user/api/v1/...` | 추천·피드 사용자 정보 (`com.wadiz.wave.user` 추정) |
| `startup-api` | `http://dev-app01:9500/api/v1/startup/...` + `dev-app01:9990/api/v1/startup/...` | 메이커 팔로우/뉴스/피드 (`com.wadiz.api.startup`) |
| `main-api` | `http://dev-app01:9990/main/main/v2/recommendation/...` | 소셜 추천 |
| `advertisement-api` | `https://rc-api.business.wadiz.kr/wad/...` | 광고 sections / search-keyword |
| `store-api` | `http://dev-app01:9080/api/internal/orders/ordered-projects` | 주문된 프로젝트 (Bearer 고정 토큰) |
| `funding-api` | `http://dev-app01:9990/funding/api/internal/supporters/my-encore` | 앵콜 후보 (Bearer 고정 토큰) |
| `corporation` | `http://dev-app01:9990` | 메이커/기업 정보 |
| `external-api.search-ai` | `https://api.dev-searchai.wadizdata.team` | AI 검색 (시맨틱·임베딩 추정), `search-period: 12M` |
| `external-api.main2` | `https://dev-platform.wadizcorp.net/main2` | 메인 추천 v2 |

## 특이사항

- **Java 8 + Boot 2.1** — 와디즈 백엔드 중에서도 **구세대 스택**. com.wadiz.api.funding(Boot 2.7), kr.wadiz.account(Boot 3.1), co.wadiz.api.community(Boot 4.0/Java 25) 와 비교하면 4년 이상 뒤짐. 업그레이드 후보.
- **검색 엔진 직조작** — Spring Data Elasticsearch 의 `ElasticsearchOperations`/`ElasticsearchRepository` 가 아니라 **`org.elasticsearch.action.*` 저수준 API** 를 직접 호출 (BoolQueryBuilder, SearchSourceBuilder, IndexRequest, UpdateRequest, BulkRequest). ES 7.x 시대의 일반적 패턴.
- **MyBatis 라이브러리만 선언, 실 사용 코드 없음** — `gradle.properties` 의 `spring_boot_mybatis_version` 변수와 `gradle/mysql.gradle` 는 있으나 실제 `@Mapper`(MyBatis), Mapper XML 발견 못함. 모든 `@Mapper` 는 **MapStruct** (DTO 변환).
- **Internal vs External 분리 없음** — currency-exchange 처럼 internal/external 컨트롤러를 분리하지 않고 path prefix(`/api/internal/*` vs `/api/search/*`) 만으로 구분.
- **카테고리 v0/v2/v3/v4 공존** — `CategoryController` 한 클래스 안에 6개 엔드포인트가 모두 살아있음. v4 만 country 헤더 지원 → 글로벌 대응 진행 중. v0/v2 service-home 은 `@Deprecated` 마킹.
- **검색어 로깅 자체 운영** — Google Analytics 같은 외부 analytics 가 아니라 **자체 ES 인덱스** 에 검색어를 매월 별 인덱스로 저장. 사내 분석/검색어 자동완성·인기 키워드에 활용 추정.
- **Spring Cloud Greenwich.SR1** — Eureka client 와 Consul discovery 를 동시에 등록 (yml 의 `eureka` 와 `spring.cloud.consul` 둘 다 있음). 운영 환경에서 어느 쪽이 주력인지 별도 확인 필요.
- **검색 결과의 광고 카드 mixin** — `service/advertise/AdvertisementServiceImpl` 가 `business.wadiz.kr` 광고 API 와 결합. 현재 응답에 어느 시점에 광고가 끼는지(server-side mix vs FE composition) 별도 분석 필요.
- **AI 검색** — `external/searchai` 패키지 + `search-ai` 외부 API 가 있음. 어느 검색 엔드포인트가 이걸 호출하는지(임베딩/시맨틱 보강) 별도 추적.

## 참고

- 본 서비스 호출자(외부 경계) 정리는 [`docs/_flows/search.md`](./_flows/search.md) (검색 플로우)
- com.wadiz.web 의 SearcherApiAdapter (사내 RestTemplate 호출) 는 **같은 서비스의 다른 path prefix(`/api/v1/searcher/*`)** 를 호출 — 동일 인스턴스에 두 entry point.
- 분석 미진행 영역: 광고 mixin 알고리즘, AI 검색 통합 지점, Campaign 인덱스 publisher 정체.
