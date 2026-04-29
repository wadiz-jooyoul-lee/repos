# Flow: 검색 (통합 검색 · 카테고리)

> 사용자가 상단 검색창 또는 카테고리 탭에서 프로젝트를 탐색하는 체인. **별도 호스트 `service.wadiz.kr`** (Service API) 로 직접 호출. 사내 **`com.wadiz.wave.searcher`** 가 ElasticSearch 7.x 인덱스를 래핑하는 검색 엔진 서버.

> 📅 **2026-04-29 업데이트** — `com.wadiz.wave.searcher` 클론 후 검증.
>
> ### 해소된 외부 경계
> - **`service.wadiz.kr` 의 실체 확정**: `com.wadiz.wave.searcher` (Spring Boot, port 9120)
> - **검색 엔진 스택 확정**: **ElasticSearch 7.x** (호스트: dev `192.168.1.186:9200`, `org.elasticsearch.action.*` API 직접 사용)
> - **데이터 저장소 이중화 확인**: ES 인덱스 + MySQL master/slave 직조회 (JPA, `RoutingDataSource`)
>
> ### 신규 발견
> - searcher 는 **MyBatis 미사용**, JPA만 사용
> - 자체 `ScheduledHandler` 는 **검색어 통계 / last-entered-feeds 색인만** 처리 (Campaign 도큐먼트 색인은 외부 indexer 가 담당 — 본 레포에 Campaign 인덱싱 코드 없음)
> - `/api/search/v2/categories` 의 실 구현: `CategoryController.getGlobalCategories` → ES 인덱스 `category_project_count` 조회 (`Const.CATEGORY_PROJECT_COUNT_INDEX`)

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/apps/global/.env-cmdrc:13-133` (`VITE_SERVICE_API_URL` 환경별 host)
  - `wadiz-frontend/packages/api/src/search/search.service.ts:10-485` (검색 API)
  - `wadiz-frontend/packages/api/src/searcher/searcher.service.ts:42` (별도 searcher wrapper)
  - `wadiz-frontend/apps/global/src/features/rewards-selection/lib/testdata/rewardMockGenerator.js:3` (hostname 명시)
  - `com.wadiz.web/src/main/java/.../searcher/adapter/SearcherApiAdapter.java:20-45`
  - `com.wadiz.web/src/main/java/.../reward/category/external/SearcherGateway.java` (SearcherGateway — 내부 용도)
  - `com.wadiz.web/web/WEB-INF/web.xml:190-193` (`/api/*` Jersey Spring Servlet 매핑)
  - `com.wadiz.wave.searcher/src/main/resources/application.yml`, `application-dev.yml` (ES host, MySQL master/slave, port 9120)
  - `com.wadiz.wave.searcher/src/main/java/.../web/rest/category/CategoryController.java:30-119`
  - `com.wadiz.wave.searcher/src/main/java/.../core/category/service/CategorySearchService.java:314-362`
  - `com.wadiz.wave.searcher/src/main/java/.../config/JdbcConfig.java:17-50` (master/slave RoutingDataSource)
  - `com.wadiz.wave.searcher/src/main/java/.../handler/ScheduledHandler.java:42-79` (검색어/피드 색인만)
- **외부 경계**: **Campaign 도큐먼트 색인을 publish 하는 인덱서**의 정체(별도 repo 추정 — searcher 자체에는 Campaign 인덱싱 코드 없음), MySQL→ES sync 메커니즘(이벤트/배치/CDC), 랭킹·광고 믹싱 알고리즘 상세.

---

## 🔑 새로운 Host 발견 — `service.wadiz.kr`
지금까지 확인된 host 목록에 추가:

| Host | 환경변수 | 담당 서비스 |
|---|---|---|
| `www.wadiz.kr` | `VITE_SERVICE_API_URL` 아님 (별도 `VITE_BASE_URL` 또는 none) | com.wadiz.web (레거시 + ApiProxy hub) |
| `account.wadiz.kr` | `VITE_ACCOUNT_URL` | kr.wadiz.account (OAuth2 IdP) |
| `app.wadiz.kr` | `VITE_APP_API_URL` | app-api (NestJS BFF) |
| `platform.wadiz.kr` | `VITE_PLATFORM_API_URL` | 플랫폼 서비스 군 |
| **`service.wadiz.kr`** ← | **`VITE_SERVICE_API_URL`** | **검색·카테고리·통합 조회 (Service API)** |
| `public-api.wadiz.kr` | `VITE_PUBLIC_API_URL` | 비로그인 공개 |
| `analytics.wadiz.kr` | — | 애널리틱스 |

환경별 prefix: live/stage → `https://service.wadiz.kr`, rc/rc2/rc3 → `https://rc-service.wadiz.kr`, dev → `https://dev-service.wadiz.kr`.

---

## 1. Client Trigger (FE)

### 1.1 주요 검색 엔드포인트 (`packages/api/src/search/search.service.ts`)

| Method | Path | 용도 |
|---|---|---|
| GET | `/api/search/v2/categories` | 카테고리 트리 조회 |
| GET | `/api/search/v3/categories/service-home` | 서비스 홈 카테고리 |
| GET | `/api/search/v2/products` | 상품(프로젝트) 검색 (쿼리/필터/정렬) |
| POST | `/api/search/v2/funding` | 펀딩 탭 검색 (Body: params) |
| POST | `/api/search/v2/preorder` | 프리오더 검색 |
| POST | `/api/search/v2/fundingSoon` | 오픈예정 검색 |
| POST | `/api/search/store` | 스토어 검색 |

FE 호출 규약:
```ts
// search.service.ts:322  (searchFunding 예시)
const baseUrl = process.env.SERVICE_API_URL || window?.wadiz?.globals?.serviceApiHost;
// 실제 endpoint:  ${baseUrl}/api/search/v2/funding
```
`process.env.SERVICE_API_URL` 는 빌드 타임(Vite define)에 `VITE_SERVICE_API_URL` 값으로 치환. 브라우저 런타임에서는 fallback 으로 `window.wadiz.globals.serviceApiHost` 사용.

### 1.2 TanStack Query 캐싱 패턴
```ts
// :58
queryKey: generateQueryKey(['api/search/v2/categories'], params)

// :281
queryKey: generateQueryKey(['/api/search/v2/products'], params)

// :334
queryKey: generateQueryKey(['api/search/v2/funding'], params)
```
검색어·필터 조합을 queryKey 로 만들어 캐싱. 브라우저 내 동일 조건 재검색 시 재요청 없음.

### 1.3 무한스크롤
검색 결과는 `useInfiniteQuery` + `pageParam` 기반 페이지네이션. `last: true` 도달 시 종료.

---

## 2. Hub — `service.wadiz.kr` = `com.wadiz.wave.searcher`

`/api/search/*` 는 **com.wadiz.web 이 아닌 별도 호스트** `service.wadiz.kr` 에서 처리하며, 그 실체는 **본 모노레포의 `com.wadiz.wave.searcher`** (port 9120) 이다. 외부 경계가 아니라 추적 가능 영역.

### 2.0 기술 스택 요약 (`com.wadiz.wave.searcher`)

| 항목 | 값 |
|---|---|
| 프레임워크 | Spring Boot (Eureka client, Consul discovery) |
| 검색 엔진 | **ElasticSearch 7.x** (`org.elasticsearch.action.*`) |
| ES 호스트 | dev `192.168.1.186:9200` (`spring.data.elasticsearch.host`) |
| RDB | MySQL master/slave (`192.168.0.162:3306` / `0.163:3306`) — JPA, `RoutingDataSource` |
| ORM | **JPA only** (MyBatis 미사용) |
| 포트 | 9120 (`server.port`) |
| 캐시 | EhCache (`classpath:ehcache.xml`) |
| 외부 의존 | main2, search-ai (`api.dev-searchai.wadizdata.team`), startup, funding (`/api/internal/supporters/my-encore`), store, ad |
| 자체 Scheduler | 검색어 색인 10분마다, last-entered-feeds 3분마다 (`ScheduledHandler`) |

### 2.1 `/api/search/v2/categories` 실 구현

```java
// com.wadiz.wave.searcher/web/rest/category/CategoryController.java:46
@RestController
@RequestMapping("/api")
public class CategoryController {
    @GetMapping("/search/v2/categories")
    public ApiCommonResponse<List<CategoryResponse>> getGlobalCategories(
            CategorySearchRequest request,
            @RequestHeader(value="wadiz-language", defaultValue="en") String languageCode) {
        List<CategorySearchResult> results = categorySearchService.searchCategoryInfo(
            request.getServiceType(), ProjectType.ALL, languageCode, request.getCategoryCode());
        return ApiCommonResponse.success(CategoryPayloadConverter.INSTANCE.convert(results));
    }
}
```

`CategorySearchService.searchCategoryInfo` (`core/category/service/CategorySearchService.java:314`) 는 ES 인덱스 `Const.CATEGORY_PROJECT_COUNT_INDEX` 에 BoolQuery 를 날려 결과를 가져온 뒤 `serviceType` 으로 필터링한다. **DB 조회가 아니라 ES 직조회**.

같은 컨트롤러의 형제 엔드포인트:

| Method | Path | 비고 |
|---|---|---|
| GET | `/api/search/categories` | v0 (`@GetMapping(":39")`) |
| GET | `/api/search/v2/categories` | 글로벌 (language 헤더 지원) `:46` |
| GET | `/api/search/categories/service-home` | `@Deprecated` `:55` |
| GET | `/api/search/v2/categories/service-home` | `@Deprecated` `:70` |
| GET | `/api/search/v3/categories/service-home` | `:84` |
| GET | `/api/search/v4/categories/service-home` | language + country 헤더 `:102` |

### 2.2 `com.wadiz.web` 내부 Searcher 호출 (참고)
서버 측(메이커센터·campaign 목록 등)에서 내부 RestTemplate 으로 Searcher 를 호출하는 Adapter 가 존재:

```java
// com.wadiz.web/src/main/java/com/wadiz/web/searcher/adapter/SearcherApiAdapter.java:20
@Component
public class SearcherApiAdapter {
    @Value("#{file['searcher_api_url']}")
    private String baseUrl;          // 외부 설정 파일에서 Searcher URL 주입

    @Autowired private ApiClientConfig config;
    private RestTemplate restTemplate;

    // :31  광고 결과
    public SearchAdResult<RewardAd> rewardAD(RewardCriteria params) {
        return restTemplate.exchange(baseUrl + "/api/v1/searcher/campaign/reward_ad",
            POST, new HttpEntity<>(params), SearchAdResult.class).getBody();
    }

    // :36  일반 리워드 결과
    public SearchResult<Reward> getReward(RewardCriteria params) {
        return restTemplate.exchange(baseUrl + "/api/v1/searcher/campaign/reward",
            POST, new HttpEntity<>(params), SearchResult.class).getBody();
    }
}
```
- 내부 경로 prefix `/api/v1/searcher/campaign/*` — FE 가 사용하는 `/api/search/v2/*` 와 **다른 prefix 구조**. FE 버전은 확장된 통합 검색 API, 내부 버전은 기본 검색.
- `searcher_api_url` 은 외부 파일(예: `wave.properties`) 로 주입 → 런타임에 search 엔진 호스트 변경 가능. **실 호스트는 `dev-app01:9120` 등 — 결국 동일 `com.wadiz.wave.searcher` 인스턴스.**

### 2.3 Jersey `/api/*` 경로
com.wadiz.web 의 web.xml 은 `/api/*` 를 **Jersey Spring Servlet** 으로 매핑(:190). 하지만 Jersey `@Path` 중 `api/search/*` 를 매칭하는 리소스는 본 레포에 없음 → 따라서 FE 가 `service.wadiz.kr/api/search/*` 를 호출할 때 www.wadiz.kr 을 경유하지 않고 **별도 호스트(`com.wadiz.wave.searcher`)** 로 가는 것으로 해석.

---

## 3. Backend — `com.wadiz.wave.searcher`

본 모노레포 내. 핵심 구조:

| 영역 | 위치 | 역할 |
|---|---|---|
| 컨트롤러 | `web/rest/{category, campaign, internal, funding, preorder, feed, ...}` | FE/내부용 검색 엔드포인트 |
| 코어 서비스 | `core/{category, campaign, integrate, banner}/service` | 검색 쿼리 빌딩·결과 변환 |
| ES 공통 | `service/common/ESCommonService`, `model/common/ElasticSearchResponse` | ES 클라이언트 래퍼 |
| MySQL JPA | `config/JdbcConfig`, `config/RoutingDataSource` | wadiz_db master/slave |
| 광고/랭킹 mix | `service/advertise/AdvertisementServiceImpl` | 광고 카드 결합 |
| 외부 API | `external/main2`, `external/searchai` | 추천·AI 검색 |

### 3.1 노출 경로

- **FE 용**: `/api/search/v2/*`, `/api/search/v3/*`, `/api/search/v4/*` — 카테고리·통합·탭별 (CategoryController, SearchController, FundingSoonController, PreorderController, ...)
- **내부 용**: `/api/v1/searcher/campaign/*` (광고·리워드 기본 검색), `/api/internal/*` (사내 service 간 호출)
- **소셜/피드**: `/api/...` (CastController, FeedController, MakerFollowController 등)

### 3.2 데이터 흐름

```
[검색 요청]
   ▼
CategorySearchService / IntegrateCampaignServiceImpl / TotalSearchServiceImpl
   │
   ├─ ES 인덱스 조회 (대부분의 검색)
   │     ElasticSearchResponseService → ES `192.168.1.186:9200`
   │     인덱스 예: integrate_category-alias, category_project_count,
   │              search_keyword-alias, last_entered_feeds-alias
   │
   ├─ MySQL JPA 조회 (메타·메이커·기본 정보)
   │     RoutingDataSource (master/slave) → wadiz_db (192.168.0.162/163:3306)
   │
   └─ 외부 API
         ├─ search-ai (api.dev-searchai.wadizdata.team)
         ├─ main2 (추천)
         ├─ ad/* (광고 mixin, business.wadiz.kr)
         └─ funding /api/internal/supporters/my-encore
```

### 3.3 `ScheduledHandler` — 자체 색인 작업 (`handler/ScheduledHandler.java`)

| 메서드 | 주기 | 대상 인덱스 | 출처 |
|---|---|---|---|
| `timerBulkSearchKeyword` | 10분 (`fixedRate=600000`) | `search_keyword-{yyyyMM}` (alias `search_keyword-alias`) | `SingleTon.indexRequestList` (검색 시점에 추가) |
| `timerBulkLastEnteredFeeds` | 3분 (`fixedRate=180000`) | `last_entered_feeds-{yyyyMM}` (alias `last_entered_feeds-alias`) | `SingleTon.lastEnteredMap` |

⚠️ **Campaign / Reward / Category 도큐먼트 색인은 이 두 스케줄러에 포함되지 않는다**. 즉 카드 화면의 달성률·모금액·카테고리별 프로젝트 수가 의존하는 인덱스(`integrate_category-alias`, `category_project_count` 등)는 **외부 indexer 가 별도로 publish** 한다 (본 레포에는 그 indexer 코드 없음 — 추정 후보: 별도 repo, Logstash/Kafka CDC, 또는 운영 배치).

---

## 4. DB
**ES 인덱스 (검색·집계의 주 출처)**:

| 인덱스 (alias) | 용도 |
|---|---|
| `category_project_count` | 카테고리별 프로젝트 수 (`/api/search/v2/categories`) |
| `integrate_category-alias` | 통합 카테고리 매핑 |
| `search_keyword-alias` | 검색어 통계 (자체 색인) |
| `last_entered_feeds-alias` | 사용자별 최근 피드 진입 (자체 색인) |
| (Campaign/Reward 인덱스) | 본 레포에 명시적 alias 정의 없음 — 외부 indexer 가 publish |

**MySQL `wadiz_db`** (master/slave RoutingDataSource): 메이커 / 카테고리 / 캠페인 메타 일부를 JPA 로 직접 조회.

**외부 indexer (미확인)**: Campaign/Reward 의 ES 색인 publisher. 후보:
- 별도 repo (예: `searcher-indexer`, `wave-indexer`)
- Kafka CDC (Debezium) — MySQL binlog → ES
- 펀딩 도메인 (`com.wadiz.api.funding`)이 이벤트 publish

⚠️ dev DB 의 `Campaign.TargetAmount` / `BackingPayment` 를 직접 변경해도 **검색 카드 / 카테고리 카운트는 ES 인덱스가 갱신되기 전까지 옛 값**. 강제 갱신은 외부 indexer 트리거 또는 풀 색인 배치 필요.

---

## 엔드투엔드 시퀀스

### A. 통합 검색 (쿼리 입력)
```
[FE: 상단 검색창 → "키워드" 입력 → 엔터]
   │ GET https://service.wadiz.kr/api/search/v2/products?q=키워드&page=0&size=20&sort=...
   │ (별도 host — www.wadiz.kr 경유 X)
   │ credentials 불필요 (비로그인도 가능한 경우), 단 일부 검색은 쿠키 전송 가능
   ▼
[service.wadiz.kr — Searcher / Catalog API (외부 서비스)]
   │
   └─ (내부 구현 불명)
        ├─ 쿼리 파싱 · 필터 적용
        ├─ ElasticSearch/OpenSearch 쿼리
        ├─ 광고 카드 mix in (ad placement)
        └─ 카테고리·정렬 스코어 반영

   → Response: { count, list: [...] }
   → FE: SearchResultList 렌더 + 다음 페이지 prefetch
```

### B. 카테고리 진입
```
[FE: 카테고리 탭 클릭]
   │ GET https://service.wadiz.kr/api/search/v2/categories?serviceType=...&categoryCode=...
   │ Header: wadiz-language: ko/en
   ▼
[com.wadiz.wave.searcher  (port 9120)]
   │
   ├─ CategoryController.getGlobalCategories          [web/rest/category/CategoryController.java:46]
   │
   └─ CategorySearchService.searchCategoryInfo        [core/category/service/CategorySearchService.java:314]
        │  BoolQuery: matchQuery(projectType) + termsQuery(serviceType+ALL)
        │             + matchQuery(languageCode) + termQuery(categoryCode)
        │  size: 1000
        ▼
   ElasticSearchResponseService.search → ES `192.168.1.186:9200`
        index: Const.CATEGORY_PROJECT_COUNT_INDEX

   → 응답: List<CategorySearchResult> (children 포함, serviceType 후필터)
   → FE: 좌측 트리 + 서브카테고리 선택 가능
```

### C. 탭별 검색 (펀딩/프리오더/오픈예정)
```
[FE: 펀딩 탭]
   │ POST https://service.wadiz.kr/api/search/v2/funding
   │    body: { filters: {...}, sort: '...', page: 0, size: 20 }
   ▼
[service.wadiz.kr]
   └─ 펀딩 전용 인덱스 쿼리 (프리오더/오픈예정은 각자 다른 endpoint)
```

### D. 서버 사이드 — com.wadiz.web 내부 Searcher 호출 (참고)
```
[com.wadiz.web — 예: 메이커센터 프로젝트 운영, 리워드 목록 페이지 등]
   │
   └─ SearcherApiAdapter.getReward(RewardCriteria)     [searcher/adapter/:36]
        └─ POST http://{searcher_api_url}/api/v1/searcher/campaign/reward
             body: RewardCriteria (운영자용 필터)

   (광고: /api/v1/searcher/campaign/reward_ad — :31)
```

---

## 경계·미탐색

1. ~~**`service.wadiz.kr` 서비스 정체**~~ → ✅ 해소: `com.wadiz.wave.searcher` (port 9120, Spring Boot) 로 확정 (2026-04-29).
2. ~~**내부 Searcher 스택**~~ → ✅ 해소: **ElasticSearch 7.x** (`org.elasticsearch.action.*` 직접 사용) + MySQL master/slave (JPA 직조회 hybrid). `co.wadiz.currency-exchange` 와 별개.
3. **인덱스 싱크 publisher 의 정체** ⚠️ — `com.wadiz.wave.searcher` 의 자체 `ScheduledHandler` 는 **검색어 통계 + last-entered-feeds 색인만** 담당. **Campaign/Reward 도큐먼트(카드·달성률·카테고리 카운트)** 색인은 외부 indexer 가 publish 하는데, 본 모노레포에는 해당 코드 없음. 후보: (a) 별도 repo, (b) Kafka CDC (Debezium) MySQL binlog → ES, (c) `com.wadiz.api.funding` 의 도메인 이벤트 발행. **추적 필요**.
4. **광고 카드 mixin 로직** — `rewardAD` 와 `reward` 의 조합 시점(서버단 vs FE 조합). searcher 의 `service/advertise/AdvertisementServiceImpl` 에 단서 있을 것 — 별도 분석 필요.
5. **개인화** — 로그인 시 유저 관심사 기반 재랭킹이 Searcher 내부에서 이뤄지는지(`SupporterContentsService`, `FeedFilterService` 단서), 아니면 FE 가 별도 personalization API 를 호출하는지.
6. **`/api/search/v2/*` vs `/api/search/v3/*` vs `/api/search/v4/*` 공존** — `CategoryController` 에 v0/v2/v3/v4 가 모두 살아있음. v4 만 country 헤더 지원 → 글로벌 대응 진행 중. v0/v2 service-home 은 `@Deprecated`. v2 → v4 이관이 진행 중인 것으로 보임.
7. **검색 이벤트 로깅** — 검색어 로그가 ES `search_keyword-{yyyyMM}` 인덱스에 10분 단위 bulk 적재됨 (`ScheduledHandler.timerBulkSearchKeyword`). 클릭 로그·외부 analytics 적재 여부는 별도.
8. **`search-ai` 외부 API** — `application-dev.yml:151` 의 `https://api.dev-searchai.wadizdata.team` 가 무엇을 반환하는지(임베딩·시맨틱 검색?), 어느 엔드포인트가 의존하는지 별도 추적.
