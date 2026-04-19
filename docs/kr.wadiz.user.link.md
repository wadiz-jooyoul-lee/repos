# kr.wadiz.user.link 분석 문서

## 개요

`kr.wadiz.user.link`는 와디즈의 **유저/콘텐츠 그래프 서비스**로, Neo4j(Community Edition) 위에 구축된 **User-Follow-UserAction-Project 그래프**를 읽기/쓰기한다. 주 용도는:

- **팔로우 그래프 질의** — N-depth 팔로우/팔로워 추천 (`/user/{userId}/follow`)
- **최근 활동 유저 추천** — "지지서명"/"체험리뷰"/"스토어 만족도리뷰" 등 최근 24시간 활동 기반 (`/action/contents-activity/users`)
- **팔로우 기반 액션 프로젝트 추천** (`/action/user/{userId}/follow/project`)

그래프는 **Wadiz RDB → Debezium → Kafka → 이 서비스** 파이프라인으로 실시간 동기화된다(Node MERGE, Relationship HARD DELETE). Master/Slave Neo4j 이중화, Failover 핸들링, Redis·Caffeine 캐시, Slack 모니터링을 포함한다.

- 애플리케이션 진입점: `LinkApplication.java` (group `com.example`, version `0.0.1-SNAPSHOT`, sourceCompat 17)
- 기본 포트: `9070` (`application.yml:2`)
- ECR 이미지: `843734097580.dkr.ecr.ap-northeast-2.amazonaws.com/userplatform/link` (`build.gradle:61`) — **User Platform 팀** 소유.
- Swagger: `https://{env}-platform.wadizcorp.net/link/swagger-ui/index.html` (dev/rc).

## 기술 스택

- **언어**: Java 17 (lombok 전면 사용), 패키지 prefix `kr.wadiz.user.link`.
- **Spring Boot 3.0.2** (`build.gradle:5`)
  - `spring-boot-starter-data-neo4j` (Neo4j Java Driver 기반, 직접 Cypher 실행 스타일)
  - `spring-boot-starter-web`, `starter-webflux`
  - `spring-boot-starter-cache:3.0.4` + `caffeine:3.1.5`
  - `spring-boot-starter-data-redis:3.0.4` (캐시 + 분산 락)
  - `spring-kafka` (@KafkaListener Master/Slave)
  - `spring-cloud-starter-kubernetes-client-config`, `starter-bootstrap`
  - `aspectjweaver` (`@RecentlyActionTarget` AOP용)
  - `springdoc-openapi-starter-webmvc-ui:2.0.2`
- **빌드 & 배포**: Gradle, **JIB**(`com.google.cloud.tools.jib:3.1.4`)로 `eclipse-temurin:17.0.6_10-jdk` 위에 `userplatform/link` 이미지를 OCI 포맷으로 만든다(`build.gradle:56-68`).
- **테스트**: `spring-boot-starter-test`, `spring-webflux` (JUnit 5).

## 아키텍처

레이어 구조:

- `controller` — REST 엔드포인트 2개 (`FollowLinkController`, `UserActionLinkController`)
- `service` — 비즈니스 서비스 5개 (`FollowLinkService`, `UserActionLinkService`, `LinkService`(Kafka consumer가 사용하는 쓰기 파사드), `LinkInterpolationService`(인기 유저 보간), `CacheService`)
- `kafka` — 13개 Kafka Consumer + `base/KafkaWadizConsumer`(추상) + `base/KafkaMessage`(공통 Payload) + `message/*` (13개 DTO)
- `config` — `LinkCacheConfig`(Redis+Caffeine 통합 CacheManager), `neo4j/Neo4jDriverConfiguration` + `WadizNeo4jClient` + `WadizNeo4jClientManager`(Master/Slave failover), `kafka/*`(각 topic별 ConsumerConfig), `WebClientConfig`, `SchedulerConfig`, `OpenAPIConfig`
- `entity` — 도메인 노드/관계 POJO
  - `node/User.java`, `node/UserActionStats.java`
  - `node/project/*` — `Project`(base), `ProjectFunding`(리워드펀딩), `ProjectStore`(스토어), `ProjectPreorder`(프리오더)
  - `node/userAction/*` — 10종 `UserAction*` (Signature/Experience/CampaignSatisfaction/StoreSatisfaction/CampaignWishItem/StoreWishItem/OpenNotice/CampaignPayment/StoreOrder/UserAction base)
  - `relationship/*` — `Follow`, `Block`, `Blocked`
  - `base/` — `IGraphPrimaryKeyGenerator`, `IUserActionBase`
- `query` — Cypher 질의/스키마 메타 계층 (이 프로젝트의 핵심)
  - `query/base/Neo4jQuery.java` — 추상 base. `generateQueryText()` + `generateQueryParamters()` + `convertModel(Result)` 구조.
  - `query/schema/node/*`(20개), `query/schema/relationship/*`(11개) — 각 노드/관계의 `name`, `Property` enum, `SubLabelQueryEntry`(active/deactive 라벨), `UtilQueryEntry`(자주 쓰는 멀티라벨 프리셋) 관리.
  - `query/util/QueryUtil.java` — 쿼리 템플릿 변환기. `#{user}`, `#{user.userId}`, `#{follow}`, `#{datetimeForm.start/end.kr}` 같은 토큰을 `valuesMap`으로 실제 라벨/프로퍼티명으로 치환.
  - `query/util/neo4j/*` — `WadizNode`, `WadizRelationship`, `WadizRecord`, `WadizNeo4jTypeWrapper` (Neo4j Driver Record 편의 래퍼; `asZonedLocalDateTime`, `asInt`, `asString` 등).
  - `query/node/*`, `query/relationship/*`, `query/service/*`, `query/reference/*` — 실제 Cypher 쿼리 구현(30+ 클래스).
- `aop/annotation/RecentlyActionTarget.java` + `RecentlyActionAspect` — UserAction merge 후 자동으로 `RecentlyActivate`/`DailyAction` 노드에 등록하고 `UserActionStats`를 갱신하는 AOP.
- `slack` — `UserMonitoringSlackChannel`, `LinkInfoMonitoringSlackChannel` (실패/배치 상태 알림).
- `util` — `LinkCacheLockManager`(Redis 분산 락), `UserCacheKeyGenerator`(캐시 key 생성), `EnableScheduledJob`, `importTargetQuery/*` (일괄 import).

### Neo4j 모델

**명명 규칙** (`README.md`):
- Database: kebab-case (`graph-db`)
- Node label: PascalCase (`User`, `Funding`, `UserActionExperience`)
- Relationship type: UPPER_SNAKE_CASE (`FOLLOW`, `PARTICIPATE_WITH_CONTENTS`)
- Property: camelCase (`userId`, `nickName`)

**기본 Property** (모든 노드/관계):
- `registeredAt`: DateTime (소스의 `WhenCreated`)
- `refreshedAt`: DateTime (소스의 `Updated`)

**Community Edition 제약**:
- Multi-database 미지원, 기본 `neo4j` DB 하나만 사용 (`WadizNeo4jClient`의 `database` 파라미터는 확장 가능성용).
- Node Key(복합키 unique) 미지원 → 단일 property Unique constraint만 사용.
- 실시간 설정 변경 불가(재기동 필요).

**Master/Slave HA** (`WadizNeo4jClientManager.java`):
- 동시에 Master, Slave에 쓰기(Kafka Consumer가 Master/Slave 각각 별도 group-id로 `@KafkaListener` 2개 설정) → Slave 지연 시에도 최종 일관성 유지.
- 읽기는 기본 Master → 5회 실패 시 Slave fallback + Slack 알림 → 10회 실패 시 `isFailOver=true`로 Slave를 active로 전환(`WadizNeo4jClientManager.java:65-113`).

## API 엔드포인트 목록

| Method | Path | Controller.method | 용도 |
|---|---|---|---|
| GET | `/user/{userId}/follow` | `FollowLinkController.getTargetByFollow` | 팔로우/팔로워 N-depth 그래프 질의 (depth≤2, target=END_USER or FOLLOWER_OF_END) |
| GET | `/action/contents-activity/users` | `UserActionLinkController.getActiveUserAtContentAction` | 최근 24시간 활동(지지서명/체험리뷰/스토어만족도리뷰) 유저 추천 (Follow*2 + Follow Me + Wadiz Friend) |
| GET | `/action/user/{userId}/follow/project` | `UserActionLinkController.getFollowActionProject` | 팔로우한 유저가 최근 참여한 프로젝트 추천 |
| GET | `/actuator/health`, `/actuator/metrics` | Spring actuator | 헬스/메트릭 (`application.yml:284-288`) |
| GET | `/swagger-ui/index.html`, `/v3/api-docs/**` | springdoc-openapi | Swagger |

(이 서비스는 **Read API만 3개** 제공하고, 쓰기는 모두 **Kafka Consumer가 수행**.)

### Kafka Consumer 토픽 전수조사 (`application.yml:72-182`, `kafka/*Consumer.java`)

| 구독 토픽 | Consumer 클래스 | 갱신되는 그래프 요소 |
|---|---|---|
| `wadiz.UserProfile` | `KafkaUserConsumer` | `User`/`DeactiveUser` 노드 MERGE (nickName, userStatus, registeredAt, refreshedAt), 라벨 전환(활성↔휴면/탈퇴) |
| `wadiz.Follow` | `KafkaFollowConsumer` | `(User)-[:FOLLOW]->(User)` 관계 MERGE/HARD DELETE |
| `wadiz.Block` | `KafkaBlockConsumer` | `(User)-[:BLOCK]->(User)` 관계 MERGE/HARD DELETE |
| `wadiz_wave_follow.UserRecommendationRejection` | `KafkaUserRecommendationRejectionConsumer` | `User.isAllowRecommendation` property 업데이트(`!isRejected`) |
| `wadiz.Campaign` | `KafkaCampaignConsumer` | `Funding` 또는 `Preorder` 노드 MERGE (`ProjectFunding`/`ProjectPreorder`; isOpen 기준 분기), 삭제/숨김 시 `Deactive*` 라벨 전환 |
| `wadiz.StoreProject` | `KafkaStoreProjectConsumer` | `Store` 노드 MERGE (`ProjectStore`) |
| `wadiz.Signature` | `KafkaSignatureConsumer` | `UserActionSignature` 노드 MERGE + `(User)-[:PARTICIPATE_WITH_CONTENTS]->(UserAction:Signature)-[:REVIEW]->(Funding|Preorder)` |
| `wadiz.MiniBoard` | `KafkaMiniboardConsumer` | MiniBoard가 '체험리뷰' 타입이면 `UserActionExperience` MERGE/DELETE, 아니면 `CandidateMiniboard`로 생성(추후 타입 확인되면 정리) |
| `wadiz.RewardSatisfaction` | `KafkaRewardSatisfactionConsumer` | `UserActionCampaignSatisfaction` 노드 및 관계 MERGE |
| `wadiz.StoreSatisfaction` | `KafkaStoreSatisfactionConsumer` | `UserActionStoreSatisfaction` 노드 및 관계 MERGE |
| `wadiz_db.BackingPayment` | `KafkaBackingPaymentConsumer` | `UserActionCampaignPayment` 노드 MERGE (결제 금액/상태/익명표시 포함) |
| `wadiz_db.RewardComingSoonApplicant` | `KafkaRewardComingSoonApplicantConsumer` | `UserActionOpenNotice` 노드 MERGE (오픈 알림 신청) |
| `wadiz_db.UserWishProject` | `KafkaUserWishProjectConsumer` | `UserActionCampaignWishItem` 또는 `UserActionStoreWishItem` MERGE (위시리스트) |
| `wadiz_store.order` | `KafkaStoreOrderConsumer` | `UserActionStoreOrder` MERGE (스토어 주문, actionId는 String) |
| `wadiz_data_db.DPCampaignBlacklist` | `KafkaBlockedCampaignConsumer` | `(Funding|Preorder)-[:BLOCKED]->(BlockedProject)` 관계 MERGE/DELETE |
| `wadiz_store.project_setting` | `KafkaStoreProjectSettingConsumer` | `(Store)-[:BLOCKED]->(BlockedProject)` 관계 MERGE/DELETE |

- Master/Slave 각각 `autoStartup`을 Gitops로 제어(`${kafka.*.consumer.master-auto-start}`, `${kafka.*.consumer.slave-auto-start}`). Slave Neo4j가 없는 환경이어도 offset은 소비(`KafkaWadizConsumer.java:35-45`).
- Group id: `user.link` (Master) / `user.link.slave` (Slave) (`application.yml:25, 74`).
- Auto offset reset: `earliest`.

## 주요 API 상세 분석

### 1. GET `/user/{userId}/follow` — 팔로우/팔로워 N-depth 추천 (`FollowLinkController.java:37-57`)

- **쿼리 파라미터**: `depth` (1~2, default 2), `target`(END_USER/FOLLOWER_OF_END, default END_USER), `limit`(default 10), `limitStrategy`(FIRST_RANDOM_LIMIT/LAST_RANDOM_LIMIT/FIRST_FIXED_LIMIT/LAST_FIXED_LIMIT), `strategyLimit`(default 30), `isRandomRepUser`(default true), `isPureLink`(default false).
- **캐시**: `@Cacheable(value = "user-link", cacheManager = "linkCacheManager", key = UserCacheKeyGenerator.generateKey(...))`. TTL 20분(`CacheKey.User.expireSec = 60*20`), `wadiz.cache.use-caffeine=true` 환경에서는 Caffeine in-memory, 아니면 Redis.
- **서비스 흐름**: `FollowLinkService.getFollowLinkOfMultiDepthFollow / getFollowerLinkOfMultiDepthFollow` → `limitStrategy`에 따라 `LinkFirstLimitFollowOfFollowQuery` 또는 `LinkFollowOfFollowQuery` 빌드 → `WadizNeo4jClientManager.executeRead(query)`.
- **Cypher 예시** (`LinkFollowOfFollowQuery.java:58-77`, END_USER + Block 제외 + FIRST_RANDOM_LIMIT):
  ```cypher
  CALL {
    MATCH (n:User {userId: $userId})-[r1:FOLLOW]->(f1:User)-[r2:FOLLOW*1]->(fx:User {isAllowRecommendation: true})
    WHERE NOT ((n)-[:FOLLOW]->(fx))
      AND NOT ((n)-[:BLOCK]->(fx))
      AND n <> fx
    WITH n, fx, fx.userId AS targetId, fx.nickName AS targetName,
         count(fx.userId) AS targetCnt, collect(distinct f1) AS f1List
    RETURN n, fx, targetId, targetName, targetCnt, f1List, rand() AS randIndex
      ORDER BY randIndex LIMIT $limit
  }
  CALL {
    WITH n, fx
    MATCH (n)-[:FOLLOW]->(c:User)<-[:FOLLOW]-(fx)
    RETURN count(distinct c) AS commonFollowCount
  }
  WITH targetId, targetName, targetCnt, f1List, commonFollowCount,
       toInteger(floor(rand()*(size(f1List)-1))) AS dispIndex
  RETURN targetId, targetName, targetCnt,
         f1List[dispIndex].userId AS weightRepUserId,
         f1List[dispIndex].nickName AS weightRepUserName,
         targetCnt AS weightCount,
         commonFollowCount
  ```
  `target=FOLLOWER_OF_END`인 경우 `(f2:User)<-[:FOLLOW]-(fx:User {isAllowRecommendation:true})` 서브패턴으로 방향을 역전(`LinkFollowOfFollowQuery.java:31-32`).
- **응답 DTO**: `ResponseLink<FollowLink>` — `targetUser(UserLink)`, `weightRepUser`(대표 친구), `commonFollowCount`.
- **부족한 결과 보간**: 팔로우 추천 결과가 `limit`에 못 미치면 `LinkInterpolationService`가 사전에 캐시한 상위 팔로워 유저(30분마다 100명씩) 중 random으로 채움.

### 2. GET `/action/contents-activity/users` — 최근 활동 유저 추천 (`UserActionLinkController.java:29-42`)

- **쿼리 파라미터**: `userId`(nullable, 비로그인 허용), `hasFollowUser`(default false), `followOfFollowLimit`(10), `followMeLimit`(5), `limit`(30), `contentSortType`(PERFORMED/CREATED/UPDATED).
- **캐시 없음** — 실시간성 우선(주석: "비로그인 비율이 적기 때문에 in-memory cache를 운용하지 않는다", `UserActionLinkController.java:37`).
- **흐름**:
  - 비로그인/userId null → `UserActionLinkService.getActiveUserAtContentAction(limit, [], contentSortType)` → `LinkRecentlyActiveUserAtContentActionQuery`
  - 로그인 → `getFollowBasedAndRecentlyActiveUserAtContentAction` → `LinkFollowBasedAndRecentlyActiveUserAtContentActionQuery`
- **핵심 Cypher** (`LinkFollowBasedAndRecentlyActiveUserAtContentActionQuery.java:69-135`, 요약):
  ```cypher
  // 24시간 이내 '지지서명/체험리뷰/스토어만족도리뷰' 활동한 추천 허용 유저 집합 수집
  CALL {
    MATCH (:RecentlyActivate {boundaryHour: $boundaryHour})<-[:INCLUDED]-
          (ua:UserAction:(Signature|Experience|StoreSatisfaction))
          <-[:PARTICIPATE_WITH_CONTENTS]-(ru:User {isAllowRecommendation: true})
    MATCH (ua)-[ra]->(p:Project)
    WHERE NOT EXISTS( (p)-[:BLOCKED]->(:BlockedProject) )
    RETURN ru
  }
  WITH collect(distinct ru.userId) AS recentlyUsers
  MATCH (source:User {userId: $userId})
  WITH recentlyUsers, source

  // 3개 UNION: Follow*2, Follow Me, Wadiz Friend (기타 최근 활동)
  CALL {
    // FOLLOW_OF_FOLLOW
    WITH source, recentlyUsers
    MATCH (source)-[:FOLLOW]->(f1:User)-[:FOLLOW]->(fx:User {isAllowRecommendation: true})
    WHERE NOT ((source)-[:FOLLOW]->(fx)) AND NOT ((source)-[:BLOCK]->(fx))
      AND source <> fx AND fx.userId IN recentlyUsers
    WITH ..., 1 AS typeOrder, rand() AS randIndex
      ORDER BY randIndex LIMIT $followOfFollowLimit
    RETURN ..., "FOLLOW_OF_FOLLOW" AS targetType, ...
    UNION ALL
    // FOLLOW_ME
    WITH source, recentlyUsers
    MATCH (source)<-[:FOLLOW]-(fx:User {isAllowRecommendation: true})
    WHERE NOT ((source)-[:FOLLOW*2]->(fx)) AND NOT ((source)-[:FOLLOW]->(fx))
      AND NOT ((source)-[:BLOCK]->(fx))
      AND source <> fx AND fx.userId IN recentlyUsers
    WITH ..., 2 AS typeOrder, rand() AS randIndex ORDER BY randIndex LIMIT $followMeLimit
    RETURN ..., "FOLLOW_ME" AS targetType, ...
    UNION ALL
    // WADIZ_FRIEND (콘텐츠 활동 자체)
    WITH source
    MATCH (:RecentlyActivate {boundaryHour: $boundaryHour})<-[:INCLUDED]-
          (ua:UserAction:(Signature|Experience|StoreSatisfaction))
          <-[:PARTICIPATE_WITH_CONTENTS]-(ru:User {isAllowRecommendation: true})
    MATCH (ua)-[ra]->(p:Project)
    WHERE NOT ((source)-[:BLOCK]->(ru)) AND source <> ru
      AND NOT EXISTS( (p)-[:BLOCKED]->(:BlockedProject) )
      AND NOT ((source)-[:FOLLOW]->(ru))       // hasFollowUser=false인 경우만 추가
    WITH ..., 3 AS typeOrder, rand() AS randIndex ORDER BY randIndex LIMIT $limit
    RETURN ..., "WADIZ_FRIEND" AS targetType, ...
  }
  // 선별된 target 유저 각각의 실제 콘텐츠 액션과 프로젝트 정보 첨부
  MATCH (targetUser)-[:PARTICIPATE_WITH_CONTENTS]->
        (ua:UserAction:(Signature|Experience|StoreSatisfaction))-[:INCLUDED]->
        (:RecentlyActivate {boundaryHour: $boundaryHour})
  MATCH (ua)-[ra]->(p:Project)
  WHERE NOT EXISTS( (p)-[:BLOCKED]->(:BlockedProject) )
  WITH targetId, targetUser.nickName AS targetNickName, targetType, targetCnt,
       weightRepUserId, weightRepUserName, weightCount, p, ua
       ORDER BY ua.performedAt DESC, typeOrder ASC
  RETURN targetId, targetNickName, targetType, targetCnt,
         weightRepUserId, weightRepUserName, weightCount,
         collect([ua.actionType, ua.actionKey, ua.actionId,
                  ua.performedAt, ua.registeredAt, ua.refreshedAt,
                  p.projectType, p.projectKey, p.projectId]) AS userActions
  ```
- **후처리**: Java 레벨에서 `contentSortType`으로 재정렬 후 중복 유저 제거(`LinkedHashMap` keyed by userId, `UserActionLinkService.java:124-132`).

### 3. GET `/action/user/{userId}/follow/project` — 팔로우 기반 액션 프로젝트 추천 (`UserActionLinkController.java:44-54`)

- **쿼리 파라미터**: `isRandom`(true), `sortType`(ASC/DESC), `dayOffset`(30일), `minActionCount`(5), `actionSize`(5), `projectSize`(1), `limit`(1).
- 팔로우한 유저가 최근 N일 내 액션한 프로젝트 중 지정 건수 이상이면서 랜덤/정렬로 `limit`만큼 반환.
- **Cypher 스케치** (`LinkFollowActionProjectQuery`):
  ```cypher
  MATCH (u:User {userId: $userId})-[:FOLLOW]->(f:User)
        -[:PARTICIPATE_WITH_CONTENTS|PARTICIPATE]->
        (ua:UserAction)-[ra]->(p:Project)
  WHERE ua.performedAt >= $startDate AND ua.performedAt <= $endDate
    AND NOT EXISTS( (p)-[:BLOCKED]->(:BlockedProject) )
  WITH p, ua, count(*) AS actionCnt
  WHERE actionCnt >= $minActionCount
  // ... 집계 후 isRandom/sortType에 맞춰 ORDER BY
  RETURN p, collect({actionKey: ua.actionKey, actionType: ua.actionType, ...}) AS actions
  LIMIT $limit
  ```

### 4. Kafka: Follow Consumer 처리 (`KafkaFollowConsumer.java`)

- Master 리스너(`@KafkaListener(containerFactory = "masterFollowListenerFactory")`)와 Slave 리스너를 같은 클래스에 둠(`KafkaFollowConsumer.java:30-38`).
- Payload는 `List<MessageFollow>`(max-poll-records 100). 같은 관계의 중복 이벤트는 `updated` 타임스탬프를 기준으로 최신 1건만 반영(`KafkaFollowConsumer.java:48-62`).
- DELETED 또는 `!isActive`면 `deleteDatas`로 분류 → `linkService.deleteFollows(...)` (`LinkDeleteRelationshipQuery`로 관계만 삭제).
- 그렇지 않으면 `linkService.mergeFollows(...)` → 각 건마다 `LinkMergeFollowQuery` 실행.
- 처리 후 `cacheService.clearUserCache(userIds)`로 follower/following 양쪽 유저의 캐시 무효화.
- **Cypher (MERGE Follow)** — `LinkMergeFollowQuery.java:19-26`:
  ```cypher
  MERGE (u1:User {userId: $srcUserId})
  MERGE (u2:User {userId: $tgtUserId})
  MERGE (u1)-[r:FOLLOW]->(u2)
  SET r.registeredAt = datetime({ epochMillis: $registeredAt, timezone: 'Asia/Seoul'})
  SET r.refreshedAt  = datetime({ epochMillis: $refreshedAt,  timezone: 'Asia/Seoul'})
  RETURN r
  ```
  (`#{datetimeForm.start} ... #{datetimeForm.end.kr}`이 `QueryUtil`에 의해 `datetime({...timezone:'Asia/Seoul'})` 형식으로 치환됨.)

### 5. Kafka: User Consumer + 휴면/활성 전환 (`KafkaUserConsumer.java`)

- Primary MERGE: `LinkMergeUserQuery` — 최초 없으면 생성, 있으면 `nickName`, `userStatus`, `registeredAt`, `refreshedAt` SET. 상태에 따라 라벨 `User` ↔ `User:deactive` 전환(`LinkMergeUserQuery.java:23-63`).
  ```cypher
  CALL {
    OPTIONAL MATCH (existUser:User|User:deactive {userId: $userId})
    WITH existUser WHERE existUser IS NULL
    MERGE (createdUser:User {userId: $userId})
  }
  WITH $userStatus <> 'NM' AS needChangeActLabel,
       $userStatus =  'NM' AS needChangeDeactLabel
  OPTIONAL MATCH (actUser:User {userId: $userId})
  OPTIONAL MATCH (deactUser:User:deactive {userId: $userId})
  WITH needChangeActLabel, needChangeDeactLabel, actUser, deactUser,
       (CASE WHEN actUser IS NOT NULL THEN actUser
             WHEN deactUser IS NOT NULL THEN deactUser END) AS existUser
  CALL {
    WITH existUser
    MATCH (existUser)
    SET existUser.nickName = $nickName
    SET existUser.userStatus = $userStatus
    SET (CASE WHEN existUser.isAllowRecommendation IS NULL THEN existUser END).isAllowRecommendation = true
    SET existUser.registeredAt = datetime({epochMillis:$registeredAt, timezone:'Asia/Seoul'})
    SET existUser.refreshedAt  = datetime({epochMillis:$refreshedAt,  timezone:'Asia/Seoul'})
  }
  CALL {
    WITH actUser, needChangeActLabel
    MATCH (actUser) WHERE needChangeActLabel
    REMOVE actUser:User SET actUser:User:deactive
  }
  CALL {
    WITH deactUser, needChangeDeactLabel
    MATCH (deactUser) WHERE needChangeDeactLabel
    REMOVE deactUser:User:deactive SET deactUser:User
  }
  RETURN actUser, deactUser, existUser AS result
  ```
- 오류 발생 시 retry 모드 — `User`/`DeactiveUser`에 동시에 존재하는 레코드 발견 → `LinkCopyRelationshipFromUserToDeactiveUserQuery`로 관계 복사 후 `LinkRestoreDuplicateUserAndDeactiveUserQuery`로 충돌 해소(`KafkaUserConsumer.java:104-144`).

### 6. Kafka: Signature Consumer + UserAction Merge (`LinkMergeUserActionSignatureQuery.java:19-37`)

```cypher
MERGE (uasign:UserAction:Signature {actionKey: $actionKey})
SET uasign.actionId   = $actionId
SET uasign.actionType = $actionType
SET uasign.performedAt  = datetime({epochMillis:$performedAt, timezone:'Asia/Seoul'})
SET uasign.registeredAt = datetime({epochMillis:$registeredAt, timezone:'Asia/Seoul'})
SET uasign.refreshedAt  = datetime({epochMillis:$refreshedAt, timezone:'Asia/Seoul'})
WITH uasign
CALL {
  WITH uasign
  MATCH (u:User {userId: $userId})
  MATCH (c:Funding|Preorder {projectId: $campaignId})   // 리워드/프리오더 어느 쪽이든
  MERGE (u)-[:PARTICIPATE_WITH_CONTENTS]->(uasign)
  MERGE (uasign)-[:REVIEW]->(c)
}
RETURN uasign AS result
```

- `LinkService.mergeSignature`에 `@RecentlyActionTarget` 애노테이션 → AOP가 자동으로 `actionKey`들을 `LinkRegisterRecentlyActivateQuery` + `LinkRegisterDailyActivateQuery`로 등록(Async).

### 7. 스케줄된 배치 — `UserActionLinkService.batchDeleteLegacyCandidateMiniboard / batchDeleteLegacyDailyAction`

- `wadiz.schedule.delete-regacy-candidate-miniboard.cron: "0 0 4 * * *"` (매일 04:00 KST), `delete-regacy-daily-action.cron: "0 30 0 * * *"` (매일 00:30).
- `LinkCacheLockManager.lock(RedisLockKey.BATCH_DELETE_...)` 로 분산 락 획득 후 실행.
- Master/Slave 각각 실행(Slave Neo4j가 별도면) 후 결과를 Slack(`LinkInfoMonitoringSlackChannel`)에 보고.

### 8. 팔로우 기반 공통 팔로워 질의 (`LinkCommomFollowUserInfoQuery` / `LinkHasFollowerRankingQuery`)

- 실시간 UI에서 "A와 B가 공통으로 팔로우하는 유저" 등을 조회.
- 예시 스케치:
  ```cypher
  MATCH (a:User {userId: $aUserId})-[:FOLLOW]->(c:User)<-[:FOLLOW]-(b:User {userId: $bUserId})
  RETURN c.userId, c.nickName LIMIT $limit
  ```

### 9. Follow-of-Follow + Recently Active 유저 프로젝트 (`LinkFollowOfFollowActiveUserAtContentActionQuery`, reference)

- 팔로우한 친구의 친구들 중 최근 활동이 있는 유저의 프로젝트 참여를 종합(참조형 쿼리, 실서비스에서는 재사용 전 평가용).

### 10. 삭제 처리 — `LinkDeleteRelationshipQuery` / `LinkDeleteNodeListQuery`

- 예: Follow 삭제
  ```cypher
  MATCH (src:User {userId: $srcKeyPropertyData})-[r:FOLLOW]->
        (tgt:User {userId: $tgtKeyPropertyData})
  DELETE r
  ```
- 노드 일괄 삭제(예: SignatureNode)
  ```cypher
  MATCH (n:Signature) WHERE n.actionId IN $keyPropertyDataList
  DETACH DELETE n
  ```

## DB 스키마 요약

> Neo4j Community Edition, 단일 DB `neo4j`. 모든 기본 property: `registeredAt`, `refreshedAt`. 명명: Node=Pascal, Relationship=UPPER_SNAKE, Property=camelCase.

### Node

**User 관련** (`entity/node/User.java`, `query/schema/node/UserNodeLabel.java`)
- **User** (active) / **User:deactive** (휴면/탈퇴) / **User:deleted** (물리 삭제 예약)
  - Property: `userId`(Integer, unique+index), `nickName`, `userStatus`("NM"/"IA"/"RA"/"DO"), `isAllowRecommendation`(Boolean, default true), `registeredAt`, `refreshedAt`
  - Unique constraint: `userId` (Community는 Node Key 불가 → 단일 unique)
  - Index: `userId`(unique와 자동), `userStatus`(직접 생성)

**Project 관련** (`entity/node/project/*`, `query/schema/node/*NodeLabel.java`)
- **Project** (base 개념, property 공통) — `projectId`(Long), `projectKey`(프리픽스_id 복합), `projectType`, `isActive`, `registeredAt`, `refreshedAt`, `endedAt`
- **Funding** / **Funding:deactive** — 리워드 펀딩 캠페인(open된 것)
- **Preorder** / **Preorder:deactive** — 프리오더(예약 판매) — Campaign 테이블에서 `isOpen=false` 분기
- **Store** / **Store:deactive** — 와디즈 스토어 상품 (`storeStatus` 추가)
- **BlockedProject** — 차단된 프로젝트 플래그 노드 (`(Project)-[:BLOCKED]->(BlockedProject)`)

**UserAction 관련** (`entity/node/userAction/*`)
모두 `UserAction` 라벨 + 하위 라벨:
- **UserAction:Signature** — 지지 서명 (`UserActionSignature`)
- **UserAction:Experience** — 체험 리뷰 (`UserActionExperience`)
- **UserAction:CandidateMiniboard** — 타입 미확정 MiniBoard (`CandidateMiniboardNodeLabel`)
- **UserAction:CampaignSatisfaction** — 리워드 만족도 리뷰 (`UserActionCampaignSatisfaction`)
- **UserAction:StoreSatisfaction** — 스토어 만족도 리뷰 (`UserActionStoreSatisfaction`)
- **UserAction:CampaignWishItem** — 리워드 위시 (`UserActionCampaignWishItem`)
- **UserAction:StoreWishItem** — 스토어 위시 (`UserActionStoreWishItem`)
- **UserAction:OpenNotice** — 오픈 알림 신청 (`UserActionOpenNotice`)
- **UserAction:CampaignPayment** — 리워드 결제 (`UserActionCampaignPayment`, `paidAt`, `payStatus`, `paymentAmount`, `donationAmount`, `fundingAmount`, `isShowPayment`, `isShowNickName`)
- **UserAction:StoreOrder** — 스토어 주문 (`UserActionStoreOrder`, actionId=String, `status`, `paymentAmount`, `orderedAt`)
- 공통 property: `actionId`(Object), `actionKey`(String, prefix_id), `actionType`, `performedAt`, `registeredAt`, `refreshedAt`

**집계/보조 노드**
- **UserActionStats** — 유저별 액션 집계 (`UserActionStatsNodeLabel`) — 카운트 캐시
- **RecentlyActivate** — 최근 활동 프레임 노드 (`boundaryHour`별, default 24)
- **DailyAction** — 일별 액션 프레임 노드(`LinkRegisterDailyActivateQuery`)

### Relationship (`entity/relationship/*`, `query/schema/relationship/*`)

- **FOLLOW** (`FollowRelationshipType`) — `(User)-[:FOLLOW]->(User)`, property `registeredAt`, `refreshedAt`
- **BLOCK** (`BlockRelationshipType`) — `(User)-[:BLOCK]->(User)`, 동일 property
- **BLOCKED** (`BlockedRelationshipType`) — `(Project)-[:BLOCKED]->(BlockedProject)`, blacklist 관계
- **PARTICIPATE** (`ParticipateRelationshipType`) — `(User)-[:PARTICIPATE]->(UserAction)` — 익명/콘텐츠없는 참여(결제/위시/주문/오픈알림 등)
- **PARTICIPATE_WITH_CONTENTS** (`ParticipateWithContentsRelationshipType`) — `(User)-[:PARTICIPATE_WITH_CONTENTS]->(UserAction)` — 콘텐츠 있는 참여(지지서명/체험리뷰/만족도리뷰)
- **REVIEW** (`ReviewRelationshipType`) — `(UserAction:Signature|Experience|*Satisfaction)-[:REVIEW]->(Project)`
- **SUPPORT** (`SupportRelationshipType`) — 리워드 결제의 프로젝트 지원
- **PAY** (`PayRelationshipType`) — 결제 관련
- **COUNT** (`CountRelationshipType`) — 집계용
- **INCLUDED** (`IncludedRelationshipType`) — `(UserAction)-[:INCLUDED]->(RecentlyActivate|DailyAction)`
- **ACTIVATED** (`ActivatedRelationshipType`) — 활성화 상태 연결

### Property 규칙
- 타임존: **Asia/Seoul**로 저장(`#{datetimeForm.end.kr}` 치환)
- Load 시점에 `toInteger` 호출하여 쿼리에서는 변환 없이 사용 (`README.md:58-60`).

### Constraint / Index
- `User.userId` Unique (index 자동)
- `User.userStatus` Index
- 추가 인덱스는 서비스 성숙도에 따라 수동 추가 (Community는 Node Key 불가).

## 외부 의존성

### 내부 시스템
- **Neo4j (Community Edition)** Master + Slave 각 EC2 (`application.yml:53-69`, bolt://, pool 100, DB `neo4j` 단일)
  - Master: `neo4j.master.uri`
  - Slave: `neo4j.slave.uri` (동일 주소면 자동으로 `isOnlyMaster=true`)
  - 둘 다 basic auth (`neo4j` / `W!diz2015#1` 기본, 실환경은 Jasypt/Secret)
- **Kafka** clustering (`bootstrap-servers: localhost:9091,9092,9093` 로컬 기준). Debezium-upstream(Wadiz RDB CDC) 토픽 16개 구독. Master group `user.link`, Slave group `user.link.slave` (`application.yml:20-34, 72-74`).
- **Redis** (Standalone 또는 Cluster 자동 감지, `LinkCacheConfig.java:75-90`) — 캐시 + 분산 락(`LinkCacheLockManager`).

### 외부 알림
- **Slack Webhooks**:
  - `user-dev-monitoring` (`#회원개발팀-monitoring-개발용` / `live`) — Neo4j failover, Kafka consumer 실패 등 알림 (`UserMonitoringSlackChannel`)
  - `link-info-monitoring` (`#회원개발팀-monitoring-체험리뷰`) — 체험리뷰/배치 상태 (`LinkInfoMonitoringSlackChannel`)

### 라이브러리 / 인프라
- **Caffeine 3.1.5** in-memory cache (기본) — `wadiz.cache.use-caffeine=true`
- **Spring Session** 사용 안함(이 서비스는 stateless)
- **Spring Cloud Kubernetes** — ConfigMap 기반 설정 로드(`bootstrap-kubernetes.yml`)
- **JIB → AWS ECR** `843734097580.dkr.ecr.ap-northeast-2.amazonaws.com/userplatform/link` (User Platform 팀 네임스페이스)
- **Base image**: `eclipse-temurin:17.0.6_10-jdk`, main class `kr.wadiz.user.link.LinkApplication`, OCI format

## 특이사항

1. **ECR 경로 `userplatform/link`** — **User Platform 팀** 소유 서비스. Group ID는 아직 `com.example`(0.0.1-SNAPSHOT)로 초기값이 남아 있어 레거시 템플릿에서 시작한 흔적이 보인다(`build.gradle:10-11`).
2. **Cypher 템플릿 치환 시스템** — `QueryUtil.valuesMap`이 `#{user}`, `#{user.userId}`, `#{follow}`, `#{datetimeForm.start}`, `#{datetimeForm.end.kr}` 같은 토큰을 실제 라벨/프로퍼티/Cypher 표현식으로 치환. 노드/관계명 리팩터 시 한 곳만 수정(`README.md:82-84`). 향후 Cypher-DSL 도입 예정(TODO).
3. **Driver 기반 + 직접 Cypher** — Spring Data Neo4j 4.x를 사용하면서도 `@Node`/`@Relationship` 매핑 없이 **Neo4j Java Driver**로 직접 Cypher 실행. 이유: `use [DATABASE]` 같은 Community 제약, Variable length relationship(`FOLLOW*2`) 같은 파라미터 제약 우회.
4. **Master/Slave 쓰기 동시 처리** — Kafka Consumer가 같은 토픽을 Master/Slave 각각 별도 `@KafkaListener`로 소비(group id 분리). 양쪽 Neo4j에 동일 데이터 적재. Slave가 없으면 `isOnlyMaster=true`로 Slave listener는 offset만 소비(`KafkaWadizConsumer.java:35-45`).
5. **Failover 로직** (`WadizNeo4jClientManager.java:65-113`):
   - Master 실패 5회 미만: Slave로 단건 fallback
   - 10회 누적 실패: `isFailOver=true` → active를 Slave로 영구 전환, 수동 복구 필요
   - FailOver 중 또 실패: "BROKEN TWO CONNECTION FOR NEO4j" Slack 알림 + 예외 전파
6. **Debezium Hard Delete** — Follow/Block은 원본 RDB에서 HARD DELETE됨. Kafka 메시지에서 `KafkaEventOperation.DELETED` 또는 `!isActive` 시 Neo4j에서도 관계만 삭제(`KafkaFollowConsumer.java:65-76`).
7. **Topic별 중복 처리** — 한 배치 내 동일 키에 대해 `updated` 최신값만 반영(하드 삭제 때문에 순서 역전 대비, `KafkaFollowConsumer.java:48-62`, `KafkaUserConsumer.java:46-57`).
8. **`isAllowRecommendation`** — `UserRecommendationRejection` 테이블 consume 시 `!isRejected` 값으로 User 노드 property만 업데이트. 기본 true (`User.java:18-20`).
9. **Multi-label로 Project 구분** — `Funding`/`Preorder`/`Store` 노드가 공통 `projectId`를 공유해도 라벨로 타입 구분. Query에서 `MATCH (c:Funding|Preorder {projectId: $campaignId})` 같은 멀티라벨 매칭(`LinkMergeUserActionSignatureQuery.java:32`).
10. **`Funding ↔ Preorder` 변환** — Campaign `isOpen` 플래그가 뒤집히면 같은 `projectId`의 노드 라벨을 교체하고 관계도 `LinkCopyInRelationshipForBetweenCampaignProjectQuery` / `LinkCopyOutRelationshipForBetweenCampaignProjectQuery`로 복사(`LinkService.java:549-603`).
11. **`RecentlyActivate` 프레임 노드** — 최근 24시간 활동 집합을 단일 노드와 `INCLUDED` 관계로 모아 Cypher에서 time-window 필터를 빠르게 수행. Legacy 자동 삭제 배치 2종 운영(체험리뷰 불명 타입 · 오래된 Daily action).
12. **`@RecentlyActionTarget` AOP** — `LinkService`의 `merge*` 메서드에 붙여서 merge 결과 `actionKey` 목록을 자동으로 `RecentlyActivate`/`DailyAction` 등록(`aop/annotation/RecentlyActionTarget.java`), `UserActionStats` 갱신은 `@Async` (`LinkService.java:467-498`).
13. **In-memory 인기 유저 보간** — `LinkInterpolationService`가 30분마다 팔로워 많은 상위 100명을 Caffeine에 caching, 추천 결과 부족 시 랜덤으로 채움(`application.yml:217-221`, `README.md:95-98`).
14. **캐시 전략** (`LinkCacheConfig.java`)
    - 기본 `wadiz.cache.use-caffeine=true` → CaffeineCacheManager, `expireAfterWrite = 120s` (`CacheKey.DEFAULT_EXPIRE_SEC`)
    - `false`일 경우 RedisCacheManager + `user-link` 캐시는 20분 TTL, scan 기반 batch delete
    - 캐시 대상: `FollowLinkController.getTargetByFollow` 만(`@Cacheable`로 선언). 액션 API는 실시간성으로 캐시 없음.
15. **Caffeine 분산 락** — `LinkCacheLockManager` (Redis 기반 분산 락) — 배치 동시 실행 방지 (`RedisLockKey.BATCH_DELETE_*`).
16. **Graceful shutdown 28s** — K8S Pod 기본 30s 보다 작게 설정(`application.yml:9`).
17. **대량 import 전략** (`README.md:140-156`) — 새 RDB 연결 시 (1) Consumer 미연결 상태 배포 → (2) Slave Neo4j에 import → (3) Master/Slave 역할 swap(Gitops) → (4) 기존 Master에 import → (5) 역할 복구 → (6) Consumer 재기동 순으로 무중단 적재. Offset 서로 다를 수 있어 임시 Kafka group 변경 필요.
18. **Scale up**은 EC2 재기동이 필요하여 Devops + 개발팀 공조로 진행(`README.md:174-186`).
19. **에러 사례 메모**(`README.md:189-194`) — 2023.08.08 체험리뷰 레거시 1400건 대량 삭제, 원인은 탈퇴회원 게시글 일괄 삭제로 인한 MiniBoardCommon 업데이트 대량 발생. 결과적으로 정상동작이었으며 이후 Delete 지표 Slack 모니터 추가.
20. **DTO `ResponseLink<T>`** — 단순 `{ data: List<T> }` 래퍼(`vo/ResponseLink.java`). 전체 에러 포맷은 springdoc 기본.
21. **Swagger 설정** — `swagger-custom.servers`로 Local 서버 단일 지정, `use-auth: false`(이 서비스는 내부 플랫폼 API이므로 앞단 Gateway에서 토큰 검증).
22. **Neo4j 버전 차이 대응** — `use [DATABASE]` 문법은 Community에서 실패하므로 `WadizNeo4jClient.java`에서는 Driver.session()에 `database` 인자를 주지 않고, 확장만 남겨둠(`README.md:87-90`).
23. **Build group ID `com.example`** — 초기 Spring Initializr 템플릿 잔재(`build.gradle:10`). 실제 패키지/이미지는 `kr.wadiz.user.link` / `userplatform/link`로 이미 분리됨.
