# Flow: 친구·피드 (Friend / Social Feed)

> 사용자가 다른 사용자를 팔로우/차단/추천받고, 팔로우한 사람들의 활동(펀딩·지지서명·만족도·위시 등)을 피드 카드로 보는 기능. **쓰기 owner = `com.wadiz.wave.user/social`** (MySQL), **그래프 read = `kr.wadiz.user.link`** (Neo4j), **피드 view = `com.wadiz.wave.searcher`** (ES 7.x).

## 기록 범위

- **읽은 파일·디렉터리**:
  - `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/social/**` (controllers·services·DTOs·5 서브도메인)
  - `com.wadiz.wave.user/src/main/resources/mapper/{follow,wadizReplication/social,wadizReplication/feed}/**` (MyBatis XML)
  - `kr.wadiz.user.link/` 전체 구조 (`docs/kr.wadiz.user.link.md` 참조 + `WadizNeo4jClientManager.java`, `LinkApplication.java`)
  - `com.wadiz.wave.searcher/src/main/java/com/wadiz/wave/searcher/web/rest/{feed,follow}/**`, `service/{feed,follow}/**`, `model/{feed,follow}/**`
  - `com.wadiz.web/src/main/java/kr/wadiz/social/{follow,recommendation}/**`, `infrastructure/social/**`
  - `com.wadiz.api.funding/core/domain/src/main/java/com/wadiz/api/funding/domain/{follow,participation/list/byfollowing}/**`
  - `wadiz-frontend/packages/api/src/{web/social.service.ts,friends/friends.service.ts}`, `static/packages/fetch-api/src/fetchApi.js`, `static/entries/main/src/pages/feed/**`, `apps/global/src/pages/social/friends/**`, `packages/widgets/src/main-feed/**`, `packages/features/src/feed/lib/**`
  - `wadiz-android/feature/.../{multifollow,contacts/multifollow,common/social}/**`, Retrofit `AppV3APIService.kt`, `WadizAppAPILegacyService.kt`, `WadizServiceAPIService.kt`
  - `wadiz-ios/Projects/{Features/KakaoMultiFollow, Service/Sources/{FriendActivity,ContactSync}, API/Sources/SocialAPI, App/Sources/WebView/Feed}/**`
  - 기존 분석: `docs/com.wadiz.wave.user/api-details/social.md`, `docs/kr.wadiz.user.link.md`, `docs/com.wadiz.wave.searcher.md`

- **외부 경계 (코드 근거 미존재, 인프라/플랫폼팀 검증 필요)**:
  - `wave.user` MySQL → `user.link` Neo4j 동기화 파이프라인 (Debezium → Kafka 추정)
  - `wave.searcher` ES 인덱스 (`user_follow-alias`) 적재 ETL 파이프라인 위치
  - `service.wadiz.kr/api/friends/*` 의 정확한 라우팅 (게이트웨이 path rewrite 추정)
  - `kr.wadiz.user.link` 가 구독하는 13개 Kafka 토픽 발행자 (User Platform 외부 팀)

---

## 0. 한눈에 보기

- "친구를 맺는 곳"(쓰기)과 "친구 활동을 보여주는 곳"(읽기)이 **서로 다른 시스템**으로 분리되어 있습니다.
- 쓰기는 `wave.user/social` (MySQL), 그래프 모델은 `kr.wadiz.user.link` (Neo4j), 피드 표시는 `wave.searcher` (ES) 가 담당합니다.
- 모바일 앱의 피드 본화면은 **웹뷰**입니다. 네이티브가 아니라 `wadiz-frontend` 의 웹페이지를 앱이 띄워줍니다.

---

## 1. 용어 정리: "feed" 가 가리키는 3가지

본 문서는 **친구 피드(social feed)** 만 다룹니다.

| 종류 | 의미 | 위치 | 본 분석 대상 |
|---|---|---|---|
| **친구 피드 (social feed)** | 내가 팔로우한 사람의 활동(펀딩·지지서명 등) | wave.user / user.link / wave.searcher / FE | 메인 |
| 카탈로그 피드 (catalog feed) | Naver 쇼핑·Facebook 상품 카탈로그 export | `com.wadiz.web/web/catalog-feed/*` | 무관 |
| 어드민 피드 카드 | 운영자가 피드에 노출할 카드 CRUD | `com.wadiz.adm` → startup-api | 별개 시스템 |

---

## 2. 도서관 비유 (시스템 매핑)

와디즈의 친구 시스템을 도서관에 비유하면 다음과 같습니다.

| 비유 | 실제 시스템 | 하는 일 |
|---|---|---|
| 책을 빌리고 반납하는 **대출 카운터** | `com.wadiz.wave.user/social` | 팔로우/언팔로우 등 "쓰기" 담당. MySQL DB 에 기록. |
| 책 사이의 인용 관계를 그린 **지식 지도** | `kr.wadiz.user.link` (Neo4j) | "A 가 B 를 팔로우하고, B 는 C 프로젝트에 펀딩했다" 같은 그래프. |
| 매일 "오늘의 추천 책" 게시판 | `com.wadiz.wave.searcher` (검색 서버) | 친구 피드 보여주기. ElasticSearch 로 빠르게 검색. |
| 입구 안내판 | `com.wadiz.web` 의 `/web/v2/v3/social/*` | FE 에서 들어온 요청을 위 시스템들로 안내(게이트웨이 역할). |
| 도서관 회원증 발급실 | `kr.wadiz.account` | 로그인·인증. 친구 기능 자체는 안 다룸. |

---

## 3. 시스템 토폴로지

```
                       ┌────────────────────────────────────────┐
                       │  사용자 행동 (펀딩 / 지지서명 / 차단 등)  │
                       └──────────────┬─────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────────┐
        │                             │                                 │
        ▼                             ▼                                 ▼
┌────────────────────┐     ┌──────────────────────┐         ┌─────────────────────┐
│ com.wadiz.api.     │     │ com.wadiz.wave.user  │         │ co.wadiz.api.       │
│ funding            │     │ /social/{follow,     │         │ community           │
│ (UseCase: 내 팔로우 │     │  block, contact,     │         │ (signature 쓰기 →   │
│  참여 프로젝트)     │     │  recommendation,     │         │  wave.user 응답으로 │
│                    │     │  feed}               │         │  편입)              │
└────────┬───────────┘     └──────────┬───────────┘         └─────────────────────┘
         │ → wave.user                │ MySQL: Follow / FollowEvent /
         │                            │   UserBlocking / UserAppContacts /
         │                            │   ConnectedAppContactUser
         │                            │ RabbitMQ: user.api / crmGateway.*
         │                            │ HTTP → kr.wadiz.user.link
         │                            ▼
         │                  ┌─────────────────────────────┐
         │       Debezium   │   MySQL binlog              │
         │     (추정,코드 미관측)│                          │
         │       ─────────► │                             │
         │                  └────────────┬────────────────┘
         │                               │ Kafka (13 topics)
         │                               ▼
         │                  ┌─────────────────────────────┐
         │                  │  kr.wadiz.user.link         │
         │                  │  Neo4j Master/Slave         │
         │                  │  (User-FOLLOW-User,         │
         │                  │   User-PARTICIPATE-Project, │
         │                  │   UserActionStats,          │
         │                  │   RecentlyActivate)         │
         │                  └────────────┬────────────────┘
         │                               │ HTTP /user/{id}/follow,
         │                               │   /action/contents-activity/users,
         │                               │   /action/user/{id}/follow/project
         │                               │
         │                  ┌────────────┴────────────────┐
         │                  │  com.wadiz.wave.searcher    │
         │                  │  ES 7.x: user_follow-alias  │
         │                  │  + FeedController,          │
         │                  │    MSFeedController,        │
         │                  │    FeedPushController       │
         │                  │  (ES indexer 위치는 본 repo │
         │                  │   에서 미관측)              │
         │                  └────────────┬────────────────┘
         │                               │
         ▼                               ▼
┌────────────────────────────────────────────────────────────┐
│                  Edge / Gateway Layer                      │
│  com.wadiz.web (게이트웨이: v2 로컬DB + v3 → wave.user 프록시) │
│  app-api(NestJS BFF): 친구/피드 핸들러 없음                  │
│  service.wadiz.kr/api/friends/* → 게이트웨이 rewrite 추정    │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────┐
│   FE 컨슈머                                                │
│   wadiz-frontend (apps/global, packages/widgets/main-feed,│
│      packages/features/feed, static/entries/main/pages/feed)│
│   Android (FeedWebViewFragment + 네이티브 follow/contact)  │
│   iOS (FeedWebViewController + KakaoMultiFollow Feature)   │
└──────────────────────────────────────────────────────────┘
```

---

## 4. 백엔드 책임 분배

### 4.1 `com.wadiz.wave.user` — 쓰기 owner (write-side, MySQL)

**쉬운 설명**: 친구 관계의 "원본 장부"입니다. 팔로우/언팔로우/차단/주소록 매칭 등 모든 변경이 여기 MySQL 에 먼저 기록됩니다.

**상세**

- 위치: `social/{follow,block,recommendation,contact,feed}` 5 서브도메인, 50+ endpoint (`docs/com.wadiz.wave.user/api-details/social.md`)
- DB: `wadiz_wave_follow.{Follow, FollowLog, FollowEvent, UserBlocking, UserRecommendationRejection, UserAppContacts, ConnectedAppContactUser}` + `wadiz_db.UserProfile` 조인
- Tx Manager: `@Transactional("followTxManager")` (전용 tx manager)
- 메시지: RabbitMQ만 사용. **Kafka 없음**. social 도메인 내 publish 코드 0건 (privacy/account 도메인이 `crmGateway.*` 발행)
- 외부 호출: `UserLinkGateway` → `kr.wadiz.user.link` (HTTP, 읽기 전용 — 추천/N-depth 조회용)
- **결정적 사실**: social/follow 쓰기와 user.link 동기화는 코드 레벨에서 직접 연결 없음. Debezium CDC 추정이지만 본 repo 내 publish 코드 미존재.

**서브도메인별 책임**

| 서브도메인 | 책임 | 주요 패키지 |
|---|---|---|
| follow | 팔로우·언팔로우(양방향), 생일자 팔로잉 조회, 활동이력(FollowEvent) | `social/follow` |
| block | 사용자 차단/해지, 차단 리스트 조회 | `social/block` |
| recommendation | 카카오·와디즈·주소록 친구 추천, 추천 거부 설정 | `social/recommendation` |
| contact | 앱 주소록 업로드·매칭·삭제 동기화(UserAppContacts + ConnectedAppContactUser) | `social/contact` |
| feed | 피드 화면용 다건 UserInfo + 팔로잉/멤버십 상태 조회 | `social/feed` |

**대표 엔드포인트** (전체는 `docs/com.wadiz.wave.user/api-details/social.md` 의 § 2 참조)

- `POST /api/v3/users/{userId}/follows` — 다중/단건 팔로우
- `DELETE /api/v3/users/{userId}/follows/{tgtUserId}` — 언팔로우
- `GET /api/v1/users/followers/user/{userId}/{type}/recent-active` — N일 내 활동 유저
- `POST /api/v1/users/feed/userInfo/get` — 피드 다건 UserInfo (팔로잉/멤버십 동봉)
- `POST /api/v1/users/followers/recommendations/find/activate` — 추천 대상 휴면여부 필터
- `POST /api/v1/users/followers/events`, `GET /api/v1/users/followers/events/{targetUserId}` — 활동이력 등록/카운트

### 4.2 `kr.wadiz.user.link` — 그래프 read 모델 (Neo4j)

**쉬운 설명**: "A 가 B 를 팔로우하고, B 는 C 프로젝트에 펀딩했다" 같은 사람-사람-프로젝트 관계를 그래프 형태로 저장한 곳입니다. "내 친구의 친구" 같은 N-단계 추천에 강합니다.

**상세**

- 포트: 9070 / 이미지: `userplatform/link` (User Platform 팀)
- Spring Boot 3.0.2 / Java 17 / Neo4j Community Edition
- 데이터 입력: Kafka 13 토픽 컨슈머 (외부 발행자가 채움)
- 노드: `User`, `UserActionStats`, `Project{Funding,Store,Preorder}`, 10종 `UserAction*` (Signature/Experience/Satisfaction/Wish/OpenNotice/Payment/Order)
- 관계: `Follow`, `Block`, `Blocked`
- HA: Master/Slave 동시 쓰기, 5회 실패 시 Slave fallback, 10회 시 failover (`WadizNeo4jClientManager.java:65-113`)
- AOP: `@RecentlyActionTarget` — UserAction merge 시 자동으로 `RecentlyActivate`/`DailyAction` 노드 + `UserActionStats` 갱신
- 노출 API:
  - `GET /user/{userId}/follow` (N-depth 팔로우/팔로워 추천)
  - `GET /action/contents-activity/users` (24시간 내 활동 유저)
  - `GET /action/user/{userId}/follow/project` (팔로우 기반 프로젝트 추천)

### 4.3 `com.wadiz.wave.searcher` — 피드 view·검색·푸시 (ES 7.x)

**쉬운 설명**: 피드 화면을 빠르게 보여주는 검색 서버입니다. MySQL 에서 매번 조인해서 가져오면 느리니까, 미리 ElasticSearch 에 인덱싱해두고 즉시 응답합니다.

**상세**

- 도메인: `service.wadiz.kr` (검색 서버)
- 인덱스: `user_follow-alias` 외 다수
- 컨트롤러 (코드 근거):
  - `FeedController` — `/api/search/feed` (`FeedController.java:19`)
  - `MSFeedController` — `/api/search/feeds` 베이스, `POST /` (전체 피드), `POST /recent` (최신), `POST /{feedId}` (단건), `POST /following` (팔로잉 유저), `POST /following/supporter` (팔로잉 서포터) (`MSFeedController.java:29-100`)
  - `FeedPushController` — `/api/search/push/feeds`, `/filters`, `/messages`, `/update`, `/history`
  - `MakerFollowController` — `/api/search/following/maker/products`
- 핵심 서비스: `FollowServiceImpl`, `FollowerActivityFeedService`, `FeedPushService`, `ImproveFeedService`, `RecentFeedService`
- 모델: `FeedType`, `FeedUser`, `FeedFilter`, `IntegrateFeed`, `LastEnteredFeed`, `SupporterActivityFeed`

### 4.4 `com.wadiz.api.funding` — read-only 컨슈머

**쉬운 설명**: 펀딩 도메인은 친구 데이터를 "참고만" 합니다. "내가 팔로우한 사람들이 참여한 프로젝트" 같은 통계 화면에서만 wave.user 를 조회합니다.

**상세**

- UseCase 두 개:
  - `FollowingListUseCase` — 내 팔로우 목록 조회 (gateway: `FollowQueryGateway`)
  - `FollowingParticipationListUseCase` — "내 팔로우들이 참여한 프로젝트"
- **이벤트 발행 없음**: 사용자 펀딩 시 follow/feed 이벤트 publish 코드 미관측. 피드는 다른 경로(Debezium → Kafka → user.link 추정)로 채워짐.
- 메이커센터 대시보드용 팔로워 상태 표시 (i18n: `studio_dashboard.project.supporter.table_item.export.column.following=Follower Status`)

### 4.5 `co.wadiz.api.community` — 현재 무관

- signature V3 만 다룸. follow/feed/friend 0건. 향후 owner 후보지만 **현재 아님**.

### 4.6 `com.wadiz.adm` — 피드 카드만 (별개 시스템)

- `FeedContentsApiController` → `startup-api` 위임 (POST/PUT `/feeds/contents`)
- 친구/팔로우 운영 도구 없음
- 운영용 카드 컨텐츠 CRUD뿐 — 친구 피드와 무관

### 4.7 `app-api` (NestJS BFF), `makercenter-be` — 없음

- app-api: 친구/피드 핸들러 0건. `/api/{funding, health, links, proxy, redirect, settings, support, webhooks}` 만 존재.
- makercenter-be: friend/feed/follow/social 키워드 0건.

---

## 5. 게이트웨이/프록시 layer — `com.wadiz.web`

**쉬운 설명**: 사용자가 웹/앱에서 보내는 요청을 받아 어느 백엔드로 보낼지 안내하는 "안내판"입니다. 옛날 방식(v2)과 새 방식(v3)이 공존합니다.

| 패턴 | 경로 | 위임 대상 |
|---|---|---|
| v2 (legacy) | `/web/v2/social/follow/my/{follower,following}/*` | **로컬 DB 직접** (FollowOldController + MyBatis) |
| v3 (현재) | `/web/v3/social/follows{,/{encUserId}}` | `FollowV3Gateway` → wave.user `/api/v3/users/{userId}/follows` |
| recommendation (kakao/wadiz) | `/web/v2/social/recommendation/user/{kakao,wadiz}/user-info` | `RecommendationUserGateway` → wave.user |
| recommendation (link) | `/web/v2/social/recommendation/user/link/user-{following,follower}` | `RecommendationUserGateway` → **kr.wadiz.user.link** |
| 피드 화면 (JSP) | `/web/feed/main` | `FeedUiController` → JSP 만, 데이터 없음 |

**핵심 파일**

- `com.wadiz.web/src/main/java/kr/wadiz/social/follow/v3/FollowV3Controller.java`
- `com.wadiz.web/src/main/java/kr/wadiz/social/follow/v3/FollowV3Service.java`
- `com.wadiz.web/src/main/java/kr/wadiz/infrastructure/social/follow/FollowV3Gateway.java`
- `com.wadiz.web/src/main/java/kr/wadiz/social/recommendation/controller/RecommendationUserController.java`
- `com.wadiz.web/src/main/java/kr/wadiz/infrastructure/social/recommendation/RecommendationUserGateway.java`

핵심 관찰:

- FE/모바일이 **wave.user 를 직접 호출하지 않습니다**. com.wadiz.web 의 `/web/v2`·`/web/v3` 가 단일 진입점.
- 단, 모바일은 `app-api`(NestJS) 가 아니라 `com.wadiz.app-api` 라는 별도 호스트를 통해서도 같은 v3 경로에 도달합니다(아래 6.2 참조).

---

## 6. FE/모바일 컨슈머

### 6.1 `wadiz-frontend` (모노레포)

| 패키지 | 책임 |
|---|---|
| `packages/api/src/web/social.service.ts` | follow/block/recommendation API 클라이언트 (`/web/v2/v3/social/*`) |
| `packages/api/src/friends/friends.service.ts` | 친구 피드/활동 (`/api/friends/supporter/feeds`, `/api/friends/activities`) |
| `packages/widgets/src/main-feed/` | 메인 홈 피드 위젯 (`useMainFeed` 훅) |
| `packages/features/src/feed/lib/feedApis.ts` | 차단 사용자 로컬스토리지 캐시 (3분 TTL) |
| `apps/global/src/pages/social/friends/` | `/social/friends` 라우트 (탭: 팔로잉 메이커/지지자/팔로워/차단) |
| `static/entries/main/src/pages/feed/` | `/web/feed/main` 정적 엔트리 (FeedLayout, RecommendedFriendCard, FollowingModal) |

**주요 React Query 키**

```
'/web/v2/social/follow/my/following/count'
'/web/v2/social/follow/my/following/user-info'
'/web/v2/social/follow/my/follower/count'
'/web/v2/social/follow/my/follower/user-info'
'/api/friends/supporter/feeds' + [encUserId, caller, page]
'/api/friends/activities'

// 로컬스토리지 (packages/features/src/feed/lib/feedApis.ts)
'FEED_BLOCKING_INFO_{hashedUserName}' — 차단 목록
'FEED_FOLLOWING_INFO_{hashedUserName}' — 팔로우 상태 (3분 TTL)
```

**핵심 BaseURL 로직**

- `wadiz-frontend/static/packages/fetch-api/src/fetchApi.js:218-221` — `fetchServiceApi()` = `globalsVar('serviceApiHost')` → `service.wadiz.kr`
- `wadiz-frontend/packages/api/src/friends/friends.service.ts:26,112` — `baseUrl: process.env.SERVICE_API_URL || window?.wadiz?.globals?.serviceApiHost`
- `fetchWebApi()` = web 호스트 → `www.wadiz.kr/web/*` (com.wadiz.web)

### 6.2 모바일

| 항목 | Android | iOS |
|---|---|---|
| 피드 화면 | **웹뷰** (`FeedWebViewFragment` + `WadizUriParser.HOME_FEED_URI`) | **웹뷰** (`FeedWebViewController`) |
| 팔로우 | `AppV3APIService.kt:327` POST `/api/v3/social/follows` (com.wadiz.app-api) | `SocialAPIImpl.swift:44` POST `/api/v3/social/follows` |
| 카카오 친구 추천 | `AppV3APIService.kt:318` GET `/api/v3/social/recommendation/kakao` | `SocialAPIImpl.swift:22` |
| 주소록 매칭 | `WadizAppAPILegacyService.kt` → `/api/v2/social/contacts/*`, `/api/v2/social/recommendation/user/contacts/*` (전화번호 해시) | `ContactSyncAssembly` + `OSContactsManager` (`/api/v2/...`) |
| 친구 활동(피드) | `WadizServiceAPIService.kt:63` GET `/api/friends/activities` (**service.wadiz.kr**) | `FriendActivity/Interface/FriendRecommendationCheckService.swift` |
| 카카오 멀티팔로우 모듈 | `feature/multifollow/` | `Projects/Features/KakaoMultiFollow/` |

**핵심 관찰**: 두 플랫폼 모두 피드 본화면은 웹뷰입니다. 네이티브는 follow 액션·주소록·카카오 친구·푸시 핸들링만 담당합니다.

---

## 7. 데이터 흐름

### 7.1 팔로우 액션 (write)

**쉬운 흐름**: "팔로우 버튼" 한 번 누르면 두 단계로 나뉘어 처리됩니다. 즉시 MySQL 에 기록되고, 잠시 후 자동으로 그래프와 검색 인덱스로 퍼져나갑니다.

```
[사용자 모바일에서 "팔로우" 탭]
         │
         ▼
앱 → POST /api/v3/social/follows                 (com.wadiz.app-api 또는 com.wadiz.web)
         │
         ▼
com.wadiz.web 안내판 → POST /api/v3/users/{userId}/follows  (wave.user)
         │
         ▼
wave.user → MySQL Follow upsert + FollowLog insert       (FollowCommandComponent)
         │
         ├──► PushGateway.sendInboxMessage()           (HTTP/RabbitMQ로 푸시)
         │
         └──► [이후 자동 동기화 — 코드 직접 미관측]
                  │
                  ▼
          MySQL binlog → Debezium → Kafka              (인프라팀, 본 repo 외부)
                  │
                  ▼
          kr.wadiz.user.link Kafka consumer
                  │
                  ▼
          Neo4j FOLLOW relationship MERGE
                  │
                  ▼
          @RecentlyActionTarget AOP → RecentlyActivate / UserActionStats 갱신
```

**시간차 주의**: 팔로우 즉시 그래프(Neo4j) 가 동기 갱신되는 게 아닙니다. **MySQL → Kafka → Neo4j** 사이에 보통 수 초의 지연이 있습니다.

### 7.2 친구 피드 조회 (read)

**쉬운 흐름**: 피드는 ElasticSearch 에서 검색합니다. MySQL/Neo4j 는 가운데서 빠지고, 미리 만들어둔 검색 인덱스만 읽기 때문에 빠릅니다.

```
[사용자가 홈 → 피드 탭]
         │
         ▼
모바일: 웹뷰가 wadiz-frontend 의 /web/feed/main 을 로드
         │
         ▼
FE useMainFeed() → POST service.wadiz.kr/api/friends/supporter/feeds
                                    (service.wadiz.kr 도메인 = wave.searcher 영역)
         │
         ▼
   [게이트웨이가 /api/search/feeds 로 path rewrite 추정 — 검증 필요]
         │
         ▼
wave.searcher (MSFeedController) → ES user_follow-alias 검색
         │
         ▼
"내가 팔로우한 사람들이 최근 한 일 목록" 반환
         │
         ▼
FE 어댑터에서 차단 유저 필터링 (packages/features/feed/lib/feedApis.ts, 3분 TTL)
         │
         ▼
카드 컴포넌트로 렌더링
```

### 7.3 추천 친구 (read, hybrid)

**쉬운 흐름**: 추천은 두 갈래로 나옵니다. 카카오에서 받은 친구 목록으로 와디즈 가입자를 매칭하는 방식과, Neo4j 그래프에서 N-단계 친구를 찾는 방식이 있고, FE 가 둘을 합쳐 보여줍니다.

```
FE → GET /web/v2/social/recommendation/user/kakao/user-info  (com.wadiz.web)
         │
         ▼
   wave.user RecommendationGateway → MySQL ConnectedAppContactUser + 카카오 OAuth 매칭

FE → GET /web/v2/social/recommendation/user/link/user-following
         │
         ▼
   wave.user → kr.wadiz.user.link → Neo4j N-depth 추천
```

### 7.4 펀딩 → 피드 반영 (event-driven, 추정)

**쉬운 흐름**: 사용자가 펀딩을 하면 그 행동도 피드 카드가 됩니다. 이건 Kafka 와 Debezium 으로 비동기 흘러간다고 추정되지만, 본 monorepo 내에서 publish 코드는 발견되지 않습니다.

```
사용자가 com.wadiz.api.funding 으로 결제 완료
         │
         ▼
MySQL BackingPayment insert
         │
         ▼
[추정] Debezium binlog → Kafka                  (본 repo 미관측)
         │
         ▼
kr.wadiz.user.link Kafka consumer
         │
         ▼
Neo4j UserActionCampaignPayment 노드 + PARTICIPATE_WITH_CONTENTS 관계 생성
@RecentlyActionTarget AOP → RecentlyActivate / UserActionStats 갱신
         │
         ▼
[별도 indexer 추정] wave.searcher ES user_follow-alias 색인
         │
         ▼
친구가 피드 조회 시 노출
```

---

## 8. DB 스키마

### 8.1 `wadiz_wave_follow` 스키마 (wave.user 쓰기)

| 테이블 | 주요 컬럼 | 용도 |
|---|---|---|
| `Follow` | `FollowNo(PK)`, `FollowerUserId`, `FollowingUserId`, `OptIn`, `Updated` (Unique: FollowerUserId+FollowingUserId) | 팔로우 관계. `insertIgnoreFollows` + `updateFollows` upsert (`follow-mapper.xml:5-66`) |
| `FollowLog` | `FollowNo`, `FollowerUserId`, `FollowingUserId`, `OptIn`, `Description`, `Registered` | 팔로우 변경 이력 |
| `FollowEvent` | `EventNo(PK)`, `EventUserId`, `EventType`, `EventValue`, `Registered`, `Updated`, `IsCancel` | 활동이력(펀딩/지지서명). EventType 1~4 |
| `UserBlocking` | `UserId`, `TargetUserId`, `OptIn`, `Updated`, `Registered` | 차단 관계. upsert via `ON DUPLICATE KEY UPDATE` |
| `UserBlockingLog` | `UserId`, `TargetUserId`, `OptIn` | 차단 변경 이력 |
| `UserRecommendationRejection` | `UserId`, `IsRejected` | 추천 거부 설정 |
| `UserAppContactSync` | `UserId(PK)`, `IsAllowed`, `Updated` | 주소록 동기화 허용 플래그 |
| `UserAppContacts` | `AppContactId(PK)`, `UserId`, `ContactName`, `MobileNumberHash` | 사용자가 업로드한 주소록 엔트리 |
| `ConnectedAppContactUser` | `AppContactId`, `OwnerUserId`, `ConnectedUserId`, `Registered` | 전화번호 매칭으로 연결된 와디즈 회원 |

### 8.2 조인되는 외부 스키마 (읽기 전용)

| 스키마.테이블 | 용도 |
|---|---|
| `wadiz_db.UserProfile` | 회원 상태(`UserStatus` = NM/IA/DO), NickName, PhotoId |
| `wadiz_db.PhotoCommon` | 프로필 사진 URL (`PhotoUrl`) |
| `wadiz_db.BackingPayment`, `wadiz_db.TbInvest` | 펀딩 집계 (FundingCnt) |
| `wadiz_db.webpages_OAuthMembership` | Provider(kakao 등) 연동 조회 |
| `wadiz_db.TbProviderProfile` | 생일 조회 |
| `wadiz_db.UserSettings` | `NOT_SHOW_BIRTH_DAY` 필터 |
| `wadiz_membership.member` | 멤버십 기간/상태(`end`, `state`) |

### 8.3 Neo4j 모델 (kr.wadiz.user.link)

- 명명: Database `kebab-case`, Node `PascalCase`, Relationship `UPPER_SNAKE_CASE`, Property `camelCase`
- 노드: `User`, `UserActionStats`, `Project{Funding,Store,Preorder}`, `UserActionSignature/Experience/CampaignSatisfaction/StoreSatisfaction/CampaignWishItem/StoreWishItem/OpenNotice/CampaignPayment/StoreOrder`
- 관계: `FOLLOW`, `BLOCK`, `BLOCKED`, `PARTICIPATE_WITH_CONTENTS`
- Community Edition 제약: Multi-database 미지원, Node Key(복합 unique) 미지원, 실시간 설정 변경 불가(재기동 필요)

---

## 9. 핵심 관찰

1. **메인 owner = `com.wadiz.wave.user/social` + `kr.wadiz.user.link`**. 두 시스템이 짝(쓰기 vs 그래프 read)을 이룹니다.
2. **`co.wadiz.api.community` 로의 이관 미진행**. signature 만 옮겨졌고 follow/feed/contact 는 wave.user 에 잔류 → 향후 deprecate 매트릭스 작성 시 주의.
3. **Kafka publish 는 코드 레벨로 추적 불가**. wave.user 의 social 도메인에 Kafka producer 없음. Debezium CDC 가정이지만 본 디렉터리 트리에서는 미확인.
4. **읽기 시스템이 둘**(Neo4j + ES) 이라는 점이 의외입니다. 캐싱·인덱스 정책 문서가 없으면 정합성 추적이 어렵습니다.
5. **app-api(NestJS BFF) 는 친구/피드를 안 다닙니다**. 모바일 v3 follow 호출은 별개 호스트(`com.wadiz.app-api`) 로 가고, friend feed 는 `service.wadiz.kr` 로 직접 → BFF 게이트웨이 통합 미적용.
6. **FE 모노레포 분산**: `apps/global`(Vite, /social/friends) + `static/entries/main`(Webpack, /web/feed/main). 두 빌드 시스템이 같은 도메인을 다룹니다 → 마이그레이션 진척도 추적 필요.
7. **모바일 피드는 웹뷰**. 네이티브 마이그레이션 계획이 있는지/없는지가 dead JSP 매트릭스에도 영향 (`docs/com.wadiz.web/api-details/dead-jsp-candidates.md` 와 교차).

---

## 10. 손대야 할 위치 가이드

| 하고 싶은 일 | 손대야 할 위치 |
|---|---|
| 팔로우/언팔로우 비즈니스 로직 변경 | `com.wadiz.wave.user/social/follow/*` |
| 차단 로직 변경 | `com.wadiz.wave.user/social/block/*` |
| 추천 알고리즘 (그래프) | `kr.wadiz.user.link/query/*` (Cypher 쿼리) |
| 추천 알고리즘 (카카오/주소록) | `com.wadiz.wave.user/social/recommendation/*` |
| 피드 검색·정렬·필터링 | `com.wadiz.wave.searcher/service/feed/*` + ES 인덱스 매핑 |
| 피드 푸시 알림 | `com.wadiz.wave.searcher/service/feed/push/*` |
| 피드 화면 UI (메인) | `wadiz-frontend/static/entries/main/src/pages/feed/` |
| 친구 관리 페이지 UI | `wadiz-frontend/apps/global/src/pages/social/friends/` |
| 메인 홈 피드 위젯 | `wadiz-frontend/packages/widgets/src/main-feed/` |
| 차단 사용자 로컬 캐시 정책 | `wadiz-frontend/packages/features/src/feed/lib/feedApis.ts` |
| 게이트웨이 라우팅 변경 | `com.wadiz.web` `FollowV3Controller`, `RecommendationUserController`, `FollowV3Gateway`, `RecommendationUserGateway` |
| 모바일 친구 단축 진입 | Android `feature/multifollow/`, iOS `Projects/Features/KakaoMultiFollow/` |
| 모바일 주소록 동기화 | Android `RequestContacts.kt`, iOS `ContactSync/Feature/` |

---

## 11. 경계·미탐색

코드 근거만으로는 더 이상 좁힐 수 없는 항목입니다. 인프라/플랫폼팀 또는 환경 검증이 필요합니다.

### 11.1 우선순위 높음

- **`/api/friends/*` 의 정확한 owner 확정**
  - FE 호출 도메인은 `service.wadiz.kr` 로 코드 근거 확정 (`wadiz-frontend/static/packages/fetch-api/src/fetchApi.js:218-221`, `wadiz-frontend/packages/api/src/friends/friends.service.ts:26,112`)
  - 그러나 `service.wadiz.kr` 의 Java owner 인 `wave.searcher` 는 `/api/search/feeds/*` 만 가지고 있고 `/api/friends/*` 는 없음 (전수 grep 0건)
  - 두 가능성: ① nginx/ALB path rewrite (`/api/friends/supporter/feeds/recent` ↔ `/api/search/feeds/recent`), ② 모노레포에 없는 별도 마이크로서비스
  - 검증 방법: 인프라 게이트웨이 설정 또는 실제 dev/prod 환경 호출 추적

- **CDC 파이프라인 실증**
  - wave.user MySQL → Debezium → Kafka 토픽 스키마 → user.link 컨슈머 매핑
  - user.link 의 13 Kafka 토픽 이름과 wave.user 테이블의 1:1 대응표
  - 검증 방법: 인프라팀 Kafka 카탈로그 또는 Debezium connector 설정

- **wave.searcher 색인 파이프라인**
  - ES `user_follow-alias` 가 어떻게 채워지는지 (별도 indexer? user.link 미러? batch?)
  - 본 monorepo 내에 indexer 코드 미관측

### 11.2 우선순위 중간

- **푸시 발행 분기**
  - `PushGateway.sendInboxMessage` (wave.user) vs wave.searcher `FeedPushService` 의 책임 구분
  - 팔로우 푸시는 누가, 활동 푸시는 누가

- **`FollowEvent` 의 사용처**
  - wave.user `EventController` 4개 endpoint(activity 등록/카운트/리스트/취소) 가 누구한테서 호출되는지
  - funding 도메인의 흔적이 본 분석에서 안 보임

- **FE 의 두 빌드 시스템 분기 이유**
  - `apps/global/social/friends`(Vite) vs `static/entries/main/pages/feed`(Webpack)
  - 마이그레이션 상태와 deprecate 계획

### 11.3 우선순위 낮음

- **dead JSP 검증과의 교차**
  - `com.wadiz.web` 의 피드 관련 JSP 가 dead-jsp 후보에 들어있는지 vs 모바일 웹뷰가 살려두고 있는지 (`docs/com.wadiz.web/api-details/dead-jsp-candidates.md` 와 교차 검증)

- **userStatus 등 코드값 변환 매트릭스**
  - feed 응답에 `userStatus`(NM/IA/DO) 가 포함되는지, FE 어댑터가 어떻게 변환하는지 (CLAUDE.md 의 추적 가이드 적용)
