# Flow: 검색 (통합 검색 · 카테고리)

> 사용자가 상단 검색창 또는 카테고리 탭에서 프로젝트를 탐색하는 체인. **별도 호스트 `service.wadiz.kr`** (Service API) 로 직접 호출. 내부 검색 엔진(ElasticSearch/OpenSearch 추정)을 사내 Searcher API 가 래핑.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/apps/global/.env-cmdrc:13-133` (`VITE_SERVICE_API_URL` 환경별 host)
  - `wadiz-frontend/packages/api/src/search/search.service.ts:10-485` (검색 API)
  - `wadiz-frontend/packages/api/src/searcher/searcher.service.ts:42` (별도 searcher wrapper)
  - `wadiz-frontend/apps/global/src/features/rewards-selection/lib/testdata/rewardMockGenerator.js:3` (hostname 명시)
  - `com.wadiz.web/src/main/java/.../searcher/adapter/SearcherApiAdapter.java:20-45`
  - `com.wadiz.web/src/main/java/.../reward/category/external/SearcherGateway.java` (SearcherGateway — 내부 용도)
  - `com.wadiz.web/web/WEB-INF/web.xml:190-193` (`/api/*` Jersey Spring Servlet 매핑)
- **외부 경계**: `service.wadiz.kr` 의 실체(어느 서비스가 Host 를 담당하는지), 내부 Searcher 서비스 스택(ElasticSearch/OpenSearch 추정), 랭킹·광고 믹싱 로직.

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

## 2. Hub — `service.wadiz.kr`
`/api/search/*` 는 **com.wadiz.web 이 아닌 별도 호스트** `service.wadiz.kr` 에서 처리한다. 이 레포에서는 해당 서비스의 서버 측 코드를 직접 볼 수 없으므로 **외부 경계**.

### 2.1 com.wadiz.web 내부 Searcher 호출 (참고)
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
- `searcher_api_url` 은 외부 파일(예: `wave.properties`) 로 주입 → 런타임에 search 엔진 호스트 변경 가능.

### 2.2 Jersey `/api/*` 경로
com.wadiz.web 의 web.xml 은 `/api/*` 를 **Jersey Spring Servlet** 으로 매핑(:190). 하지만 Jersey `@Path` 중 `api/search/*` 를 매칭하는 리소스는 본 레포에 없음 → 따라서 FE 가 `service.wadiz.kr/api/search/*` 를 호출할 때 www.wadiz.kr 을 경유하지 않고 **별도 호스트(다른 서비스)** 로 가는 것으로 해석.

---

## 3. Backend — Searcher / Catalog 서비스 (외부)
레포 외부. Searcher 는:
- 내부 경로: `/api/v1/searcher/campaign/*` (광고·리워드 기본 검색)
- FE 용: `/api/search/v2/*`, `/api/search/v3/*` (카테고리·통합·탭별)

검색 엔진(ElasticSearch/OpenSearch 추정) + 랭킹·A/B + 광고 mixin.

---

## 4. DB
이 레포에서 관측 불가. 검색 인덱싱은 별도 서비스가 MySQL `Campaign`·`Reward`·카테고리 등을 읽어 ES/OS 에 싱크하는 배치/CDC 로 이루어질 것으로 추정. 본 flow 범위 외.

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
   │ GET https://service.wadiz.kr/api/search/v2/categories?parentId=0&country=KR
   ▼
[service.wadiz.kr]
   │
   └─ Category 트리 + 각 카테고리 별 카운트
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

1. **`service.wadiz.kr` 서비스 정체** — Wadiz 내부 어떤 서비스(별도 Searcher 서비스 or 통합 Service Gateway)가 이 Host 를 담당하는지 본 레포(repos 폴더)에서 확인 불가. 별도 repo(예: `searcher-api`, `service-api-gateway`) 가 있을 가능성.
2. **내부 Searcher 스택** — ElasticSearch vs OpenSearch, 버전, 인덱스 설계. `co.wadiz.currency-exchange` 와 별개.
3. **인덱스 싱크** — Campaign/Reward 원장 변경 시 ES 인덱스 업데이트 방식 (Kafka CDC / 주기 배치 / 이벤트 기반). com.wadiz.api.funding 이 상태 변경 시 인덱스 publish 하는지 확인 필요.
4. **광고 카드 mixin 로직** — `rewardAD` 와 `reward` 의 조합 시점(서버단 vs FE 조합) 추적.
5. **개인화** — 로그인 시 유저 관심사 기반 재랭킹이 Searcher 내부에서 이뤄지는지, 아니면 FE 가 별도 personalization API 를 호출하는지.
6. **`/api/search/v2/*` vs `/api/search/v3/*` 공존** — v3 는 home 카테고리 한정인지, 혹은 v2 → v3 이관 중인지 확인 필요.
7. **검색 이벤트 로깅** — 검색어 로그·클릭 로그가 어떤 analytics 스택(Analytics 호스트)에 적재되는지 별도.
