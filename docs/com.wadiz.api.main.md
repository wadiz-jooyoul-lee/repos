# com.wadiz.api.main (main1-api) 분석 문서

> 와디즈 **메인 지면 1세대 API** 입니다. 추천·트렌딩·기획전·얼리버드·소셜 추천·광고 등 메인 화면 구성 요소를 내려줍니다. 2세대인 [`main2-api`](./main2-api.md) 와 **현재 함께 운영 중**입니다.
> Org: `wadiz-service` (`https://github.com/wadiz-service/com.wadiz.api.main.git`). 배포 이름 `main1-api`, 플랫폼 `display-platform`.

> 📅 분석 기준: 2026-09-01, **`master` 브랜치**(`32cd21af`, 2026-08-12). Java 147개 · 컨트롤러 14개 · 엔드포인트 46개.

---

> 📅 **2026-09-02 master pull 보강** (2 커밋)
>
> ### DISPLAY-1691 — 따라잡기 글로벌 확대를 `/api/v4` 로 분리
>
> 이 레포에서 이번에 가장 중요한 변경입니다. **처음에는 `/api/v3` 를 직접 글로벌로 확대했다가, 되돌리고 `/api/v4` 를 새로 만드는 쪽으로 방향을 바꿨습니다.**
>
> - **1차(`78f690ab`)**: `/api/v3` 에 `wadiz-country` 헤더(기본 KR)를 추가해 요청 국가로 배송 가능한 프로젝트만 노출하도록 필터링. 오픈예정 쿼리에 `wadiz_db.CampaignShippingCountry` EXISTS 조건 추가, fallback 을 국가별로 분기.
> - **2차(`eeb773c1`)**: **`/api/v3` 를 글로벌 확대 이전 코드로 원복**(v1·v2 포함, 동작 변경 없음)하고 **`/api/v4` 를 신설**했습니다.
>   - 신규 엔드포인트 — `GET /api/v4/catchup/{userId}` · `GET /api/v4/catchup/{userId}/coming-soon-today`
>   - `wadiz-country` 헤더(기본 KR)로 배송 가능한 프로젝트만 노출. AI 추천 호출에 `country_code` 쿼리 파라미터 전달.
>   - 오픈예정 조회는 `findByCatchUpComingSoonV4`·`findByCatchUpComingSoonByPostedRangeV4` 로 분리.
>   - **fallback 분기**: KR 은 기존 스토어를 쓰고, **글로벌은 스토어 참여가 불가하므로** 해당 국가로 배송 가능한 진행중 펀딩(`findByCatchUpFunding`)으로 대체합니다.
>   - 슬롯 구성은 v3 와 같지만 V4 전용 상수·조립 메서드로 분리해 **버전 간 영향을 차단**했습니다.
>   - `AiRecommendationAdapter` 만 오버로드로 공유하며, `countryCode` 가 비면 `country_code` 를 붙이지 않아 **v1~v3 요청 URI 는 기존과 동일**합니다.
> - 관련 레포: [`main2-api`](./main2-api.md) 가 호출 경로를 v3 → v4 로 바꿨고(DISPLAY-1688), [`com.wadiz.wave.user`](./com.wadiz.wave.user/com.wadiz.wave.user.md) 가 country/language 를 main2 상품 API 로 전파합니다(BE3-769).
>
> ---
>

## main1 과 main2 의 관계 — 세대 차이가 큽니다

| | **main1-api** (이 문서) | [**main2-api**](./main2-api.md) |
|---|---|---|
| 저장소 | `wadiz-service/com.wadiz.api.main` | `wadiz-tech/main2-api` |
| 소속 org | wadiz-service | wadiz-tech (전시플랫폼) |
| 배포 브랜치 | **`master`** | **`main`** |
| Java / Spring | **Java 8** · Boot(구버전) · Spring Cloud 2021.0.3 | **Java 17** · Boot 3.0.4 · Spring Cloud 2022.0.3 |
| 웹 스택 | **Spring MVC**(동기) | **WebFlux**(리액티브) |
| 저장소 | **MongoDB + MySQL(JPA/JDBC)** 혼용 | MongoDB 전용 |
| 디스커버리 | **Consul** + k8s config | k8s config |
| API 문서 | **Springfox 3.0**(구식) | springdoc |
| 규모 | 컨트롤러 14 · EP 46 | 컨트롤러 6 · EP 71 |
| 코드 활동(90일) | **8커밋** | 20커밋 |
| clive 배포(최근) | 2026-08-22 | 2026-08-26 |

- **둘 다 살아 있습니다.** helm clive 에 각각 values 가 있고 최근 배포 이력도 있습니다.
- main1 은 **Java 8 + Consul + Springfox** 로 구세대 스택이고, main2 는 Java 17 + WebFlux 로 새로 쓴 것입니다. 다만 main1 이 **완전히 죽은 것은 아니고** 2026-06 까지 기능 개발(따라잡기 성인 컨텐츠 필터링 등)이 있었습니다.
- ⚠️ **어떤 지면이 어느 쪽을 타는지는 이 저장소만으로 알 수 없습니다.** main2-api 문서의 미확인 항목과 동일한 숙제이며, 프론트엔드·앱의 호출 경로를 함께 봐야 풀립니다.
- helm 에 `main1-api-opencrm` · `main1-api-public-api` 라는 **파생 서비스 2개**가 더 있습니다(소스 레포 미상). 같은 이미지의 용도별 배포로 보이나 미확인입니다.

## 기술 스택

| 구분 | 내용 |
|---|---|
| 언어 | **Java 8** (`sourceCompatibility = 1.8`) |
| 프레임워크 | Spring Boot(버전은 `gradle.properties` 변수), Spring Cloud **2021.0.3** |
| 포트 | **9070**, graceful shutdown(단계당 10s), MVC async 타임아웃 600초 |
| 저장소 | **MongoDB** + **MySQL**(JPA + JDBC, `mysql-connector-java` 8.0.33, log4jdbc) |
| 캐시 | Ehcache 3.7.1 (JSR-107) |
| 디스커버리 | **Consul** (`spring-cloud-starter-consul-discovery`) + k8s config |
| 회복성 | Resilience4j 서킷브레이커 |
| API 문서 | **Springfox 3.0.0** (springdoc 아님) |
| 사내 라이브러리 | `reward-http-client`/`reward-models` 0.1.12-SNAPSHOT · `equity-http-client`/`equity-models` 0.0.6-SNAPSHOT · `wave-crypto` 1.0.3 |
| JPA 튜닝 | `jdbc.batch_size: 200`, `order_inserts`·`order_updates`·`batch_versioned_data` 활성 |
| 빌드 | Gradle 멀티모듈 — 루트 `main` + `main-model` + `main-client` · Jib 3.4.4 |
| 아티팩트 저장소 | 사내 Nexus(`repo.wadizcorp.com`, **HTTP 허용**) + GitHub Packages |

## 구조

패키지는 `com.wadiz.api.main` 아래 **헥사고날 스타일**로 나뉩니다.

```
presentation/   컨트롤러 14개
application/    유스케이스
adapter/ infra/ 외부 연동·저장소
entity/ model/ enums/ constant/ config/ util/
```

멀티모듈 3개: `main`(앱) · `main-model`(모델) · `main-client`(다른 서비스가 쓰는 클라이언트 라이브러리로 추정).

## API 엔드포인트 (컨트롤러 14개 · 46개)

| 컨트롤러 | base | EP | 용도 |
|---|---|---:|---|
| `RecommendationController` | `/recommendation` | **10** | 추천 |
| `StoreController` | — | 5 | 스토어 지면 |
| `MakerController` | `/maker` | 4 | 메이커 |
| `DisplayAdsController` | — | 4 | 전시 광고 |
| `CommonController` | — | 4 | 공통 |
| `TrendingController` | — | 4 | 트렌딩 |
| `SocialRecommendationController` | — | 4 | 소셜 추천 |
| `CustomCollectionController` | `/v1/custom-collection` | 3 | 커스텀 컬렉션 |
| `FeaturedController` | `/featured` | 2 | 피처드 |
| `EarlybirdController` | `/earlybird` | 2 | 얼리버드 |
| `CacheController` | `/cache` | 2 | 캐시 관리(운영용) |
| `CampaignController` | `/campaign` | 1 | 캠페인 |
| `SearcherController` | `/searcher` | 1 | 검색 연동 |

- 컨트롤러 대부분이 클래스 레벨 `@RequestMapping` 없이 메서드에 전체 경로를 적는 스타일이라, 실제 외부 경로는 메서드 애너테이션을 봐야 합니다.
- helm values 의 `virtualService.subPath` 는 **`main`** 입니다.

## 배포

| 환경 | 트리거 브랜치 | 갱신 대상 values |
|---|---|---|
| **clive** | **`master`** | `display-platform/clive/main1-api.yaml` |
| dev · rc4 | `dev` · `rc4` | 각 환경 |

- `cloud_live` 브랜치는 없고 `master` 가 클라우드 라이브 배포선입니다(`com.wadiz.api.funding`·`com.wadiz.api.friends` 와 같은 패턴).
- 2026-06-05 `Change deployment branch and update ECR registry` 로 배포선이 정리됐고, 2026-08-12 에 rc4 워크플로가 추가됐습니다.
- helm values: `type: api` · `requestsMemory: 2Gi`.

## 최근 변경 (2026-06~08)

활동이 뜸합니다 — 90일간 8커밋이고 그중 절반이 배포 설정입니다.

| 날짜 | 이슈 | 내용 |
|---|---|---|
| 2026-08-12 | — | rc4 배포 워크플로 추가 |
| 2026-06-25 | DISPLAY-1566 | `/api/v3` 따라잡기에 **성인 컨텐츠 필터링** 추가 |
| 2026-06-12 | DISPLAY-1459 | Ehcache 버전 충돌 안정화 |
| 2026-06-11 | — | k8s ConfigMap 설정 수정 |
| 2026-06-05 | — | 배포 브랜치 변경 및 ECR 레지스트리 갱신 |
| 2026-06-04 | DISPLAY | `/api/v3` 따라잡기 — 슬롯 채우기 로직 개선(adCampaign), 오픈예정 24시간 무작위 조회 |

- `/api/v3` **따라잡기(catch-up)** 관련 작업이 마지막 기능 개발입니다. 같은 기능이 `main2-api`(`/api/v1/catchup/{userId}`)와 검색 서버(`com.wadiz.wave.searcher` 의 막펀잡기)에도 있어, **세 곳에 흩어져 있습니다**.

## 미확인 항목

- **main1 과 main2 의 지면별 역할 분담** — 이 문서와 `main2-api.md` 공통 숙제. FE·앱 호출 경로 조사가 필요합니다.
- `main1-api-opencrm` · `main1-api-public-api` 파생 서비스 2개의 정체와 소스 레포.
- `main-client` 모듈을 어떤 서비스가 의존하는지.
- "따라잡기" 기능이 main1 `/api/v3` · main2 `/api/v1/catchup` · searcher `catchup/ending-soon` 세 곳에 있는데, 실제로 무엇이 쓰이는지.
- clive 실제 운영 설정 — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/main1-api.yaml` 참조.
