# main2-api 분석 문서

> 와디즈 **메인 홈(2세대) API 서버**입니다. 메인 지면·마이와디즈·랭킹·큐레이션·추천·배너를 한곳에서 조립해 앱과 웹에 내려줍니다. 지면 데이터는 RDB 가 아니라 **MongoDB 도큐먼트**에 들어 있습니다.
> Org: `wadiz-tech` (`https://github.com/wadiz-tech/main2-api.git`). 배포 이름 `main2-api`, 플랫폼 `display-platform`(전시플랫폼).

> 📅 분석 기준: 2026-09-01 clone, **`main` 브랜치**(`861ff56`, 2026-08-26). Java 파일 251개, 테스트 1개.

> ℹ️ 이 문서는 **display-platform(전시플랫폼) 팀 저장소 중 첫 분석 대상**입니다. 같은 팀의 다른 서비스 40여 개는 아직 미분석입니다 — [`helm-charts-gitops.md`](./helm-charts-gitops.md) 의 "이 저장소를 읽는 실전 요령"으로 활동 중인 서비스를 추릴 수 있습니다.

---

> 📅 **2026-09-02 main pull 보강** (4 커밋)
>
> ### DISPLAY-1688 — 따라잡기 API 호출 경로를 v3 → v4 로 전환
> - 따라잡기 글로벌 지원을 위해 [`main1-api`](./com.wadiz.api.main.md) 의 **`/api/v4` 를 호출하도록 변경**했습니다 (`controller/CommonController.java`, `service/CommonService.java`). main1 이 v3 를 원복하고 v4 를 신설한 것(DISPLAY-1691)과 짝입니다.
> - dev 배포 워크플로에서 **odev 이미지 태그 갱신 스텝을 제거**했습니다. live 워크플로의 중복 스텝도 정리(−9줄).
>
> ### DISPLAY-1667 — 추천 카드 링크에 `recommendation_type` 추가
> - 추천 카드 링크 URL 에 `recommendation_type` 파라미터를 붙이고 **MOMENTUM 필터링을 제거**했습니다.
>
> ---
>

## 개요

- 와디즈 **메인 홈 지면**을 구성하는 API 입니다. 프론트엔드는 `packages/api/src/main2/main2.service.ts` 로 이 서버를 호출합니다(예: 홈 와디즈 에디션 섹션, FE1-1316·FE1-1497).
- 지면 구성(배너·컬렉션·큐레이션·랭킹·퀵메뉴)을 **MongoDB 도큐먼트로 관리**하고, 조회 시 Ehcache 로 캐싱한 뒤 **Redis Pub/Sub 으로 여러 파드의 캐시를 동기화**합니다.
- **WebFlux(리액티브)** 기반이며 외부 서비스 호출마다 Resilience4j 서킷브레이커를 겁니다.
- 이름의 "main2" 는 2세대라는 뜻으로 보입니다. 1세대는 별도 서비스 `main1-api`(`wadiz-service/com.wadiz.api.main`)로 아직 함께 운영됩니다.

## 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 언어/런타임 | **Java 17** (`eclipse-temurin:17`) | `build.gradle` (`sourceCompatibility = '17'`, jib) |
| 프레임워크 | **Spring Boot 3.0.4**, Spring Cloud 2022.0.3, **WebFlux(리액티브)** | `build.gradle` |
| 포트 | **9000**, graceful shutdown | `application.yml:2-3` |
| 저장소 | **MongoDB**(`spring-boot-starter-data-mongodb`) — 지면 도큐먼트 | `build.gradle` |
| 캐시 | **Redis(reactive)** + **Ehcache 3.10.1**(JSR-107) 2단 | `build.gradle` |
| 회복성 | Resilience4j **리액터용** 서킷브레이커 — 인스턴스 `recommendationItem`·`recommendationPersonal`·`searcher` | `application.yml` |
| 쿠버네티스 설정 | `spring-cloud-starter-kubernetes-client-config` + `spring-cloud-starter-bootstrap` | `build.gradle`, `bootstrap-kubernetes.yml` |
| 관측 | Actuator + **Micrometer Prometheus**(`health, info, metrics, prometheus, caches, circuitbreakers` 노출) | `application.yml` |
| 다국어 | `messages_{ko,en,ja,zh}.properties` + `I18nMessageService` | `src/main/resources` |
| 기타 | MapStruct 1.5.3, httpclient5 5.2.1, json-simple, Lombok | `build.gradle` |
| 빌드/이미지 | Gradle + **Jib 3.3.1**(OCI), SonarQube 플러그인 | `build.gradle` |

## 배포

| 환경 | 트리거 브랜치 | 갱신 대상 values | 워크플로 |
|---|---|---|---|
| live / clive | **`main`** | `display-platform/live/main2-api.yaml` **와** `display-platform/clive/main2-api.yaml` **둘 다** | `aws_deploy_ecr_live.yml` |
| dev · rc · rc2 · rc3 · stage | 각 브랜치 | 각 환경 values | `aws_deploy_ecr_{dev,rc,rc2,rc3,stage}.yml` |

- ECR: `393290902814.dkr.ecr.ap-northeast-2.amazonaws.com/platform/main2-api`.
- **live 워크플로 하나가 `live` 와 `clive` 두 환경의 values 를 함께 갱신합니다.** 온프레미스와 클라우드를 같은 커밋으로 동시에 배포한다는 뜻이라, 이관 과도기 운영 방식으로 보입니다(다른 서비스는 보통 한쪽만 갱신).
- 배포 상태(이미지 태그·ConfigMap)는 [`helm-charts-gitops`](./helm-charts-gitops.md), 배포 스펙(리소스·라우팅·인가)은 [`helm-charts`](./helm-charts.md) 에 있습니다.
- `SonarQube.yml` 로 정적 분석도 함께 돕니다.

## API 엔드포인트

컨트롤러 **6개 · 엔드포인트 71개**입니다. 인증·헤더 규약은 각 컨트롤러 시그니처를 직접 확인해야 합니다(이 문서에서는 경로만 정리).

### `MainController` — 메인 지면 (13개)

`/api/v1/main/default` 와 **`/api/v1/main` ~ `/api/v12/main`**.

> ⚠️ **버전이 12개까지 누적돼 있습니다.** 앱·웹의 구버전 호환 때문으로 보이나, 어느 버전이 현재 주력이고 어느 것이 사장됐는지는 코드만으로 알 수 없습니다. 지면을 고칠 때 **어느 버전에 반영해야 하는지 먼저 확인**해야 합니다.

### `MyWadizController` — 마이와디즈 (6개)

`/api/v1/mywadiz`(붙여쓴 옛 경로) · `/api/v1/my-wadiz` ~ `/api/v5/my-wadiz`. 여기도 v1~v5 누적입니다.

### `CommonController` — 공통 지면 요소 (20개)

| 경로 | 용도 |
|---|---|
| `/api/v1/maker/follow` | 메이커 팔로우 |
| `/api/v1/store/repeatedPurchase` | 스토어 재구매 |
| `POST /api/v1/recentview` | 최근 본 항목 |
| `/api/v1/curation/{debut,hot,like,support}` | 큐레이션 4종 |
| `/api/v1/collection` · `/api/v1/trends` · `/api/v1/quickmenu` | 컬렉션·트렌드·퀵메뉴 |
| `/api/v1/catchup/{userId}` · `/api/v1/catchup/{userId}/coming-soon-today` | 막펀잡기(따라잡기) |
| `POST /api/v1/products` · `POST /api/v2/products` | 상품 조회 |
| `/api/v1/pc/main/earlybird` · `key-visual` · `metrics` · `category/trends` · `category/rankings` · `category/rankings/groups` | PC 메인 전용 |

### `RankingController` — 랭킹 (7개)

`/api/v1/ranking/{reward,rewardComingSoon,store}` · `/api/v1/pc/ranking/{funding,coming-soon,store}` · `/api/v1/category-ranking/projects/{projectId}`

### `RecommendationController` — 추천 (8개)

`/api/v1/pc/main/{funding,store}` · `/api/v1/recommendation/item`(+`/detail`, `/payment/reward`, `/payment/store`, `/braze`) · `/api/v1/recommendation/personal/braze`

- `braze` 접미 경로 2개는 **Braze(CRM 마케팅 도구)용 추천**입니다.

### `BannerController` — 배너 (9개)

`/api/v1/banner/{detail,mypage,collection}` · `/api/v1/banner/my-wadiz/maker` · `/api/v1/banner/key-visual/{main,funding,preorder,launching-soon,store}`

## 도메인 구조

```
controller/    6개 (위 참조)
service/       23개 — Main·MyWadiz·Ranking·Recommendation·Curation·Collection·Banner·Ad·Benefit·
                       Category·Funding·Store·Reward·Point·User·Wish·Searcher·AiRecommendation·
                       Message·I18nMessage·Common·Util·Backup
model/document/ MongoDB 도큐먼트 — Banner(V2)·Collection(V2)·Category(Ranking)·Debut·Hot·Like·
                       Ad(Banner)·Benefit·Coordination·Funding·FundingOrderHistory·Equity·I18nMessage·Backup 등
model/card/     카드 렌더링 모델      model/ai/  AI 추천 모델
cache/sync/     CachePubSubConfig · CacheSyncPublisher · CacheSyncListener
mapper/         MapStruct 매퍼        validation/ · advice/ · enums/ · constant/ · util/
```

### 캐시 동기화 구조

Ehcache 는 파드마다 따로 있어서 어드민이 지면을 바꿔도 일부 파드만 갱신되는 문제가 생깁니다. 이를 **Redis Pub/Sub** 으로 해결합니다 — `CacheSyncPublisher` 가 무효화 이벤트를 발행하고, 각 파드의 `CacheSyncListener` 가 받아 자기 로컬 캐시를 비웁니다 (`cache/sync/`).

### 외부 연동

프로퍼티로 주입되는 대상 서비스입니다.

| 프로퍼티 | 대상 |
|---|---|
| `wadiz.funding.base-url` (+ `wadiz.funding.token`) | 펀딩 API |
| `wadiz.main.base-url` | 메인(1세대) API |
| `wadiz.membership.base-url` | 멤버십 API |
| `wadiz.point.base-url` | 포인트 API |

서킷브레이커 인스턴스 이름(`searcher`·`recommendationItem`·`recommendationPersonal`)으로 보아 **검색 서버(`com.wadiz.wave.searcher`)와 추천 서버**도 호출합니다.

### 지면 튜닝 파라미터

지면 구성값이 설정으로 빠져 있어 코드 수정 없이 조절할 수 있습니다 — `wadiz.page-size`, `wadiz.quick-menu.size`, `wadiz.collection.first`·`second`, `wadiz.ranking.{funding,coming-soon,store}`, `wadiz.catchup.ad-size`·`ad-indexes`, `wadiz.recommendation.item.size`·`limit`·`detail.*`, `wadiz.card.divider.{height,top-margin,bottom-margin}`.

## 소비처

- **wadiz-frontend** — `packages/api/src/main2/main2.service.ts`. 홈 지면(에디션 섹션 포함)과 PC 메인이 이 서비스를 씁니다.
- 앱(iOS/Android)도 메인 지면을 쓰지만 이번 분석에서 호출 경로까지는 확인하지 않았습니다(미확인).

## 미확인 항목

- **`/api/v1~v12/main` 중 실제 사용 버전** — 앱 최소 지원 버전과 대조해야 정리 가능합니다. 사장된 버전이 있다면 정리 후보입니다(`my-wadiz` v1~v5 도 동일).
- clive 의 실제 운영 설정(MongoDB·Redis 접속, 프로파일) — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/main2-api.yaml` `configmap.data` 를 봐야 합니다.
- `main1-api`(1세대)와의 역할 분담 — 어떤 지면이 어느 쪽을 타는지.
- `AiRecommendationService`·`model/ai` 가 연결되는 추천 엔진의 정체.
- 테스트가 사실상 없습니다(테스트 파일 1개). 회귀 안전망이 없는 상태입니다.
