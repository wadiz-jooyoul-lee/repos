# Social 도메인 상세 스펙

> **기록 범위**
>
> 이 문서는 `com.wadiz.wave.user` repo 내부에서 실제로 관측 가능한 코드/XML/설정만을 기록한다.
> 대상 범위:
> - `src/main/java/com/wadiz/wave/user/social/**` (컨트롤러·서비스·컴포넌트·DTO·상수)
> - `src/main/java/com/wadiz/wave/repository/social/follow/**` (MyBatis 인터페이스·엔티티·파라미터 객체)
> - `src/main/resources/mapper/follow/**` (쓰기용 MyBatis XML)
> - `src/main/resources/mapper/wadizReplication/social/**`, `mapper/wadizReplication/feed/**` (리플리카 읽기 XML)
> - `src/main/resources/user*.yml` (RabbitMQ exchange, user-link endpoint)
>
> 기록하지 않는/못하는 것:
> - 본 repo는 **RabbitMQ 사용**. Kafka 토픽은 본 repo의 social 도메인 어디에도 존재하지 않는다(전사 Kafka broker/스키마는 본 repo에서 확인 불가).
> - `com.wadiz.wave.user.link.*` 의 HTTP 클라이언트 구현 자체는 확인했지만, 호출 대상인 `kr.wadiz.user.link` 내부 로직(Neo4j 갱신, Kafka 구독 등)은 본 repo 밖이므로 "외부"로만 표기한다.
> - `social/follow` 컨트롤러들이 호출하는 `PushGateway.sendInboxMessage(...)` 등 푸시/CRM 메시지 발송은 HTTP 또는 RabbitMQ 기반이며, 본 문서는 해당 호출 존재 여부까지만 기록한다.
> - 컨트롤러 상단 "팔로우 그래프 → Neo4j 갱신" 같은 구독 체인은 본 repo에서 publish/produce 코드가 존재하지 않으므로 **확인 불가**. (social 도메인은 내부 MySQL 쓰기만 수행한다.)

---

## 1. 개요

`social` 도메인은 레거시 Wave User 모놀리식(Boot 구버전 / Java 8 / MyBatis) 중 사용자 간 연결 그래프와 주소록 매칭을 담당한다. 하위 5개 서브도메인으로 구성된다.

| 서브도메인 | 책임 | 주요 패키지 |
|---|---|---|
| follow | 팔로우·언팔로우(양방향), 생일자 팔로잉 조회, 활동이력(FollowEvent) | `social/follow` |
| block | 사용자 차단/해지, 차단 리스트 조회 | `social/block` |
| recommendation | 카카오·와디즈·주소록 친구 추천, 추천 거부 설정 | `social/recommendation` |
| contact | 앱 주소록 업로드·매칭·삭제 동기화(UserAppContacts + ConnectedAppContactUser) | `social/contact` |
| feed | 피드 화면용 다건 UserInfo + 팔로잉/멤버십 상태 조회 | `social/feed` |

### 공유 의존성

- **DB (쓰기/조회)**: MySQL `wadiz_wave_follow` 스키마 (+`wadiz_db`, `wadiz_membership`, `wadiz_user` JOIN)
- **Tx Manager**: 대부분 서비스가 `@Transactional("followTxManager")` 사용 — `wadiz_wave_follow` 전용 tx manager.
- **공유 컴포넌트**: `social/component/FollowCommandComponent` (팔로우 insert+log+push), `FollowValidationComponent`, `UserBlockValidationComponent`, `UserAppContactQueryComponent`.

### `kr.wadiz.user.link` 와의 관계 (관측 가능한 한)

| 항목 | 내용 |
|---|---|
| 통신 방식 | **HTTP (RestTemplate)**. `infrastructure/link/UserLinkGateway` 가 `https://{profile}-platform.wadizcorp.net/link` 로 호출. `user.yml:320-323` |
| 호출 방향 | `com.wadiz.wave.user` → `kr.wadiz.user.link` (wave.user가 클라이언트) |
| 엔드포인트 (조회) | `GET /user/{userId}/follow`, `GET /action/contents-activity/users`, `GET /action/user/{userId}/follow/project` — `UserLinkGateway.java:48~112` |
| 이 문서의 팔로우 커맨드와의 연결 | **직접 코드 경로 없음.** `FollowV3Service`/`FollowOldService`/`BlockCommandService` 어디에서도 UserLinkGateway를 호출하지 않는다. social 도메인은 MySQL `Follow` 테이블에만 쓴다. `kr.wadiz.user.link` 의 Neo4j 갱신이 wave.user의 쓰기를 구독하는 구조(CDC/Kafka/Debezium 등)는 **본 repo 내에서는 관측되지 않음**. |
| 인증 | `Authorization: Bearer ${user-link.api.internal-token}` (설정: `user.yml:323`) |

### RabbitMQ 발행 (참고: 본 repo에는 Kafka 없음)

| 컴포넌트 | 대상 Exchange | Routing Key | 발행 위치 |
|---|---|---|---|
| `CrmGatewayPublisher` | `crmGateway.braze.USER_STATUS.*` (TopicExchange) | `DEACTIVATE_USER`, `REACTIVATE_USER`, `DELETE_USER` | **social 도메인 외부** (`privacy/` `account/` 서비스) |
| `UserApiPublisher` | `user.api` (DirectExchange) | `SUPPORTER_SIGNATURE` | supporter 도메인 |
| **social 도메인에서 직접 발행** | — | — | **없음** (`Grep`으로 `social/` 하위에서 `RabbitTemplate`, `Publisher`, `@EventListener` 참조 0건 확인) |

파일 참조: `publisher/UserApiPublisher.java:23`, `publisher/CrmGatewayPublisher.java:22-32`, `publisher/routingkey/CrmGatewayRoutingKey.java:8-10`, `config/WadizRabbitMqConfig.java:70-83`.

---

## 2. 엔드포인트 전수 테이블

### 2.1 Follow

| # | Method | Path | Controller | 설명 |
|---|---|---|---|---|
| 1 | POST | `/api/v3/social/{userId}/follows` | FollowV3Controller | 다중 팔로우(@Deprecated) |
| 2 | POST | `/api/v3/social/{userId}/follows/{tgtUserId}` | FollowV3Controller | 단건 팔로우(@Deprecated) |
| 3 | DELETE | `/api/v3/social/{userId}/follows/{tgtUserId}` | FollowV3Controller | 단건 언팔로우(@Deprecated) |
| 4 | POST | `/api/v3/users/{userId}/follows` | FollowV3UserController | 다중 팔로우 |
| 5 | POST | `/api/v3/users/{userId}/follows/{tgtUserId}` | FollowV3UserController | 단건 팔로우 |
| 6 | DELETE | `/api/v3/users/{userId}/follows/{tgtUserId}` | FollowV3UserController | 단건 언팔로우 |
| 7 | POST | `/api/v1/users/followers` | FollowOldController | 팔로우 맺기 (Legacy) |
| 8 | POST | `/api/v1/users/followers/following` | FollowOldController | 팔로우 + 푸시 |
| 9 | POST | `/api/v1/users/followers/following/multi` | FollowOldController | 다중 팔로우 + 푸시 |
| 10 | DELETE | `/api/v1/users/followers/{followNo}` | FollowOldController | 팔로우 차단(단건) |
| 11 | DELETE | `/api/v1/users/followers/drop/{targetUserId}` | FollowOldController | 팔로우 전체 삭제(회원탈퇴) |
| 12 | GET | `/api/v1/users/followers` | FollowOldController | 팔로워/팔로잉 페이징 |
| 13 | GET | `/api/v1/users/followers/getFollowUserIdsHavingActivityWithinDays` | FollowOldController | N일 내 활동 유저 팔로우 목록 |
| 14 | GET | `/api/v1/users/followers/user/{userId}/{type}/recent-active` | FollowOldController | N일 내 활동 유저(최근활동순) |
| 15 | GET | `/api/v1/users/followers/user/{userId}/following/user-id` | FollowOldController | 팔로잉 UserId 전체 |
| 16 | GET | `/api/v1/users/followers/user/{userId}/following/user-info` | FollowOldController | 팔로잉 UserInfo 페이징/커서 |
| 17 | GET | `/api/v1/users/followers/user/{userId}/following/count` | FollowOldController | 팔로잉 수 |
| 18 | GET | `/api/v1/users/followers/user/{userId}/following/is-full` | FollowOldController | 최대 팔로잉 도달 여부 |
| 19 | GET | `/api/v1/users/followers/user/{userId}/follower/user-id` | FollowOldController | 팔로워 UserId 전체 |
| 20 | GET | `/api/v1/users/followers/user/{userId}/follower/user-info` | FollowOldController | 팔로워 UserInfo 페이징/커서 |
| 21 | GET | `/api/v1/users/followers/user/{userId}/follower/count` | FollowOldController | 팔로워 수 |
| 22 | GET | `/api/v1/users/followers/follower/{followerUserId}/following/{followingUserId}/follow-no` | FollowOldController | FollowNo 조회 |
| 23 | GET | `/api/v1/users/followers/user/{userId}/follower/is-following` | FollowOldController | 다건 팔로잉 여부 |
| 24 | GET | `/api/v1/users/followers/user/{userId}/following/birth-day/user-info` | FollowOldController | 팔로잉 생일자 조회 |
| 25 | GET | `/api/v1/users/followers/recommendations` | DeprecatedRecommendController | 친구추천(Deprecated) |
| 26 | POST | `/api/v1/users/followers/recommendations/find/activate` | DeprecatedRecommendController | 추천 대상 휴면여부 필터 |
| 27 | POST | `/api/v1/users/followers/events` | EventController | 활동이력 등록 |
| 28 | GET | `/api/v1/users/followers/events/{targetUserId}` | EventController | 활동이력 카운트 |
| 29 | GET | `/api/v1/users/followers/events` | EventController | 활동이력 서포터 리스트 |
| 30 | PUT | `/api/v1/users/followers/events` | EventController | 활동이력 취소 |

### 2.2 Block

| # | Method | Path | Controller | 설명 |
|---|---|---|---|---|
| 31 | POST | `/api/v1/social/block` | BlockCommandController | 차단하기 |
| 32 | POST | `/api/v1/social/unblock` | BlockCommandController | 차단 해지 |
| 33 | GET | `/api/v1/social/block` | UserBlockingController | 차단 여부 확인 |
| 34 | GET | `/api/v1/social/block/all` | UserBlockingController | 차단 UserId 리스트 |
| 35 | GET | `/api/v1/social/block/userinfo` | UserBlockingController | 차단 UserInfo 페이징/커서 |
| 36 | GET | `/api/v1/social/block/userinfo/count` | UserBlockingController | 차단 UserInfo 총수 |

### 2.3 Recommendation

| # | Method | Path | Controller | 설명 |
|---|---|---|---|---|
| 37 | PUT | `/api/v1/social/recommendation/user/{userId}/allow-info` | RecommendationUserController | 추천 허용 여부 토글 |
| 38 | GET | `/api/v1/social/recommendation/user/{userId}/allow-info` | RecommendationUserController | 추천 허용 여부 조회 |
| 39 | POST | `/api/v1/social/recommendation/user/kakao/has-user` | RecommendationUserController | 카카오 추천 존재 여부 |
| 40 | POST | `/api/v1/social/recommendation/user/kakao/user-info` | RecommendationUserController | 카카오 친구 추천 |
| 41 | POST | `/api/v1/social/recommendation/user/wadiz/user-info` | RecommendationUserController | 와디즈 친구 추천 |
| 42 | POST | `/api/v1/social/recommendation/user/contacts/count` | RecommendationUserController | 주소록 추천 총수 |
| 43 | POST | `/api/v1/social/recommendation/user/contacts/user-info` | RecommendationUserController | 주소록 친구 추천 |

### 2.4 Contact

| # | Method | Path | Controller | 설명 |
|---|---|---|---|---|
| 44 | GET | `/api/v3/users/{userId}/contacts/information` | UserAppContactV3UserController | 주소록 이력 조회(V3) |
| 45 | PUT | `/api/v1/users/contacts/{userId}/sync-allow` | UserAppContactOldController | 주소록 업로드 허용 토글 |
| 46 | GET | `/api/v1/users/contacts/{userId}/information` | UserAppContactOldController | 주소록 이력 조회(V1) |
| 47 | PUT | `/api/v1/users/contacts/{userId}` | UserAppContactOldController | 주소록 업로드(벌크) |
| 48 | DELETE | `/api/v1/users/contacts/{userId}` | UserAppContactOldController | 주소록 전체 삭제 |
| 49 | PUT | `/api/v1/users/contacts/{userId}/my-number/reconnection` | UserAppContactOldController | 내 전화번호 재연결 |

### 2.5 Feed

| # | Method | Path | Controller | 설명 |
|---|---|---|---|---|
| 50 | POST | `/api/v1/users/feed/userInfo/get` | FeedUserInfoController | 피드 다건 UserInfo 조회 |

합계: **50개 엔드포인트** (V3 중복: 1~3번 `FollowV3Controller`는 `@Deprecated`, 4~6번 `FollowV3UserController`가 live 대체품)

---

## 3. 하위 도메인별 상세

### 3.1 Follow

파일 인벤토리:

| 구성요소 | 경로 |
|---|---|
| V3 컨트롤러(deprecated) | `social/follow/FollowV3Controller.java` |
| V3 컨트롤러(live) | `social/follow/FollowV3UserController.java` |
| Old 컨트롤러 | `social/follow/FollowOldController.java` |
| 추천(구) | `social/follow/DeprecatedRecommendController.java` |
| 이벤트 | `social/follow/EventController.java` |
| 서비스 V3 | `social/follow/service/FollowV3Service.java` |
| 서비스 Old | `social/follow/service/FollowOldService.java` |
| 추천 서비스(구) | `social/follow/service/DeprecatedRecommendService.java` |
| 이벤트 서비스 | `social/follow/service/EventService.java` |
| 생일 캐시 | `social/follow/service/FollowBirthDaysCacheService.java` |
| 공통 컴포넌트 | `social/component/FollowCommandComponent.java` |
| 검증 컴포넌트 | `social/component/FollowValidationComponent.java`, `UserBlockValidationComponent.java` |
| 매퍼(쓰기) | `repository/social/follow/FollowMapper.java` + `mapper/follow/follow-mapper.xml` |
| 매퍼(이벤트) | `repository/social/follow/EventMapper.java` + `mapper/follow/event-mapper.xml` |
| 매퍼(추천 구) | `repository/social/follow/RecommendationMapper.java` + `mapper/follow/recommend-mapper.xml` |
| 매퍼(리플리카: 생일) | `social/follow/repository/FollowReplicationMapper.java` + `mapper/wadizReplication/social/follow/followReplication-mapper.xml` |

#### 엔드포인트 상세

##### POST `/api/v3/users/{userId}/follows/{tgtUserId}` (단건)

- **Service**: `FollowV3Service.followUser()` — `FollowV3Service.java:31`
- **권한/검증**:
  - `FollowValidationComponent.validateSelfFollow` — 자신 팔로우 금지 → `CANNOT_FOLLOW_SELF`
  - `UserBlockValidationComponent.validateBlockedUser` — 차단 관계 금지 → `FOLLOW_BLOCKED_USER`
  - `validateFollowingLimit` — 최대 3000 (`FollowCommandComponent.MAX_FOLLOWING`)
- **DB 경로**:
  1. `FollowMapper.countByFollowerUserId` — `follow-mapper.xml:281-288`
  2. `UserBlockingMapper.findBlockedAndDropUserIds` — `userblocking-mapper.xml:28-41`
  3. `FollowMapper.insertIgnoreFollows` — `follow-mapper.xml:5-20` (주요 SQL):
     ```sql
     INSERT IGNORE INTO wadiz_wave_follow.Follow (FollowerUserId, FollowingUserId, OptIn)
     SELECT #{userId}, VU.FollowingUserId, #{optIn}
     FROM (SELECT UserId AS FollowingUserId FROM wadiz_db.UserProfile UP
           WHERE UserId IN (...) AND UserStatus = 'NM') VU
     ```
  4. `FollowMapper.updateFollows` — `follow-mapper.xml:53-66` (INSERT IGNORE로 튕겨진 row 보완, `UserStatus != 'DO'` 조건 반영)
  5. `FollowMapper.selectTargetFollowingList` — `follow-mapper.xml:94-104`
  6. `FollowMapper.insertFollowLogs` (description=`"팔로우 맺기"`) — `follow-mapper.xml:23-37`
- **후처리 (비동기)**: `FollowCommandComponent.sendFollowMessage()` → `followTaskExecutor` 에서 `UserLocaleMapper.findUserLocaleByUserIds` 후 `PushGateway.sendInboxMessage`. 언어별로 분기하여 인박스/푸시 발송. `FollowCommandComponent.java:159-227`
- **Kafka 발행**: 없음.

##### POST `/api/v3/users/{userId}/follows` (다건)

- **Service**: `FollowV3Service.followUsers()` — `FollowV3Service.java:51`
- 동일 체인, 단 자신-팔로우 검증/블록 검증은 서비스 레벨에서 생략하고 `filterValidTargetUsers`로 일괄 필터. MAX_FOLLOWING 초과분은 `subList(0, availableSize)`로 컷.
- 로그 description = `"모두 팔로우"`

##### DELETE `/api/v3/users/{userId}/follows/{tgtUserId}`

- **Service**: `FollowV3Service.unFollowUsers()` — `FollowV3Service.java:75`
- **DB**:
  1. `FollowMapper.selectTargetFollowingNoList` — `follow-mapper.xml:83-93`
  2. `FollowMapper.updateFollowsByFollowNo(optIn=false)` — `follow-mapper.xml:40-52`
  3. `FollowMapper.insertFollowLogs(description="팔로우 차단")` — description enum `UN_FOLLOW`.

##### POST `/api/v1/users/followers` (Legacy 단건)

- `FollowOldService.createOld()` — `FollowOldService.java:81`. 내부적으로 `followingOld()` 호출 → V3와 동일한 검증 로직. 예외 발생 시 빈 `Follow` 반환(무응답 보존).

##### POST `/api/v1/users/followers/following` / `/following/multi`

- `FollowOldService.create(SingleRequest|FollowRequest)` — 푸시 포함. `FollowCommandComponent.followUsers(... optIn=true ...)` 경로.

##### DELETE `/api/v1/users/followers/{followNo}` / `/drop/{targetUserId}`

- `FollowOldService.delete(FollowReq)` — `FollowOldService.java:157`
- `followNo` 제공 시: `unFollowUsers([followNo], UN_FOLLOW)`
- `targetUserId` 제공 시: `FollowMapper.selectAllFollowNoList(targetUserId, targetUserId)` (OR 조건으로 양방향 수집) → `unFollowUsers(..., DROP_USER)`.

##### GET `/api/v1/users/followers` (팔로워/팔로잉 페이징)

- `search.type` = `"following"` | `"follower"` 분기:
  - following: `FollowMapper.findAllByFollowerUserId` — `follow-mapper.xml:167-190` (FollowEvent JOIN으로 FundingCnt/SignatureCnt 집계)
  - follower: `FollowMapper.findAllByFollowingUserId` — `follow-mapper.xml:291-314`
- `useRandomSort=true` 시 `ORDER BY RAND(#{userId+hour})` 적용.

##### GET `/api/v1/users/followers/getFollowUserIdsHavingActivityWithinDays`

- `FollowMapper.hasFollowing` → `findAllFollowing|FollowerUserIdsBy...ActivityDateWithin[OrderByEventRegisteredDesc]`
- `follow-mapper.xml:415-532`: 4종 쿼리. `FollowEvent` 의 `Registered >= DATE_ADD(NOW(), INTERVAL -#{withinDays} DAY) AND IsCancel = FALSE` 기반.

##### GET `/api/v1/users/followers/user/{userId}/{type}/recent-active`

- 위 메서드의 `orderByEventRegistered=true` 분기.

##### GET `/api/v1/users/followers/user/{userId}/following/user-id`

- `FollowMapper.findAllFollowingUserIdByFollowerUserId` — `follow-mapper.xml:193-200`:
  ```sql
  SELECT F.FollowingUserId
  FROM wadiz_wave_follow.Follow F
    INNER JOIN wadiz_db.UserProfile UP ON F.FollowingUserId = UP.UserId AND UP.UserStatus = 'NM'
  WHERE F.FollowerUserId = #{userId} AND F.OptIn = true
  ```

##### GET `/api/v1/users/followers/user/{userId}/following/user-info`

- `FollowMapper.findFollowingUserInfoByFollowerUserId` — `follow-mapper.xml:203-278`.
- 주요 특징: `BackingPayment` + `TbInvest` 서브쿼리로 FundingCnt, `FollowEvent` 서브쿼리로 SignatureCnt, `usingCursor=true` 시 `CONCAT(UNIX_TIMESTAMP(Updated), LPAD(FollowNo, '10', '0'))` CursorId 구조, `sortType`은 `${}` 치환(주의: SQL injection 잠재 가능성 — 컨트롤러에서 `SearchSortType` enum으로 바인딩).
- loginUserId 가 있으면 `IsFollowing` 필드 추가(해당 login user가 팔로우하는지 여부).

##### GET `/api/v1/users/followers/user/{userId}/following/count`

- `FollowMapper.countByFollowerUserId` — `follow-mapper.xml:281-288`.

##### GET `/api/v1/users/followers/user/{userId}/following/is-full`

- `countByFollowerUserId >= 3000` 단순 비교. `FollowOldService.java:301`.

##### GET `/api/v1/users/followers/user/{userId}/follower/user-id`

- `FollowMapper.findAllFollowerUserIdByFollowingUserId` — `follow-mapper.xml:317-324`.

##### GET `/api/v1/users/followers/user/{userId}/follower/user-info`

- `FollowMapper.findFollowerUserInfoByFollowingUserId` — `follow-mapper.xml:327-402` (위 팔로잉 쿼리와 대칭).

##### GET `/api/v1/users/followers/user/{userId}/follower/count`

- `FollowMapper.countByFollowingUserId` — `follow-mapper.xml:405-412`.

##### GET `/api/v1/users/followers/follower/{followerUserId}/following/{followingUserId}/follow-no`

- `FollowMapper.findFollowNoByFollowerUserIdAndFollowingUserId` — `follow-mapper.xml:534-541`.

##### GET `/api/v1/users/followers/user/{userId}/follower/is-following`

- `FollowMapper.selectTargetFollowingList` (위 단건 팔로우용 조회와 동일).

##### GET `/api/v1/users/followers/user/{userId}/following/birth-day/user-info`

- `FollowBirthDaysCacheService.getRangeDays(startDay, endDay)` — Redis 캐시 24h (`FollowBirthDaysCacheService.java:17-40`). 미스시 날짜 범위 생성 후 `FollowReplicationMapper.findBirthDayFollowUserInfo`:
  ```sql
  -- followReplication-mapper.xml:4-29
  SELECT BF.BirthDayUserId as UserId, UP.NickName, BF.birthday
  FROM (
    SELECT f.FollowingUserId as BirthDayUserId, tbp.birthday, CASE ... END as birthOrder
    FROM wadiz_wave_follow.Follow f
    INNER JOIN wadiz_db.TbProviderProfile tbp ON tbp.userId = f.FollowingUserId AND tbp.birthday IN (...)
    WHERE f.FollowerUserId = #{userId} AND f.OptIn is true
  ) BF
  INNER JOIN UserProfile UP ON UP.UserId = BF.BirthDayUserId AND UP.UserStatus = 'NM'
  LEFT JOIN wadiz_db.UserSettings US ON US.UserId = BF.BirthDayUserId AND US.SettingType = #{notShowBirthDaySettingType}
  WHERE US.UserId is NULL
  ORDER BY BF.birthOrder;
  ```
- 설정 타입 `NOT_SHOW_BIRTH_DAY` 의 `typeNumber` 를 이용해 생일 비공개 유저 제외.

##### GET `/api/v1/users/followers/recommendations` (Deprecated)

- `DeprecatedRecommendService.getRecommendList()` — `DeprecatedRecommendService.java:44`
- DB: `RecommendationMapper.selectRecommendFollowList` — `recommend-mapper.xml:36-43`:
  ```sql
  SELECT eventUserId AS followingUserId, MAX(Registered) AS registered
  FROM FollowEvent
  WHERE Registered >= DATE_ADD(NOW(), INTERVAL -3 DAY)
  GROUP BY eventUserId
  HAVING COUNT(eventUserId) >= 3
  ORDER BY MAX(Registered) DESC LIMIT 30;
  ```
- 각 대상에 대해 `CommonPrivacyService.findCurrentAccountStatus` 호출하여 휴면/탈퇴 필터.
- `Callable<Recommend>` 반환(비동기 MVC).

##### POST `/api/v1/users/followers/recommendations/find/activate` (Deprecated)

- `DeprecatedRecommendService.findActivateFollow(String[])`
- `InactiveAccountByWadizMapper.selectArchivalDataByProviderUserId` → `CommonPrivacyService.findCurrentAccountStatusList` 로 휴면/탈퇴 판별.

##### POST `/api/v1/users/followers/events`

- `EventService.create(EventReq)` — `EventService.java:51`
- DB: `EventMapper.insertFollowEvent` — `event-mapper.xml:6-17`:
  ```sql
  INSERT INTO FollowEvent (EventUserId, EventType, EventValue, Registered)
  VALUES (#{eventUserId}, #{eventType}, #{eventValue}, NOW())
  ```

##### GET `/api/v1/users/followers/events/{targetUserId}`

- `EventService.get(EventSearch)` — followerCnt/followingCnt + EventType별 count(1~4).
- `EventMapper.selectFollowTargetEventCount`:
  ```sql
  SELECT COUNT(*) CT
  FROM FollowEvent A
  WHERE A.IsCancel = false AND A.EventType = #{eventType} AND A.EventUserId = #{eventUserId};
  ```
- EventType 코드: 1=리워드 펀딩, 2=투자 펀딩, 3=리워드 지지서명, 4=투자 지지서명 (`EventService.java:97-104` 주석).

##### GET `/api/v1/users/followers/events` (서포터 리스트)

- `EventMapper.selectEventSupporterList` — `event-mapper.xml:29-40`.

##### PUT `/api/v1/users/followers/events` (취소)

- `EventMapper.updateFollowEvent(IsCancel=true)` — `event-mapper.xml:54-61`.

### 3.2 Block

파일 인벤토리:

| 구성요소 | 경로 |
|---|---|
| Command 컨트롤러 | `social/block/controller/BlockCommandController.java` |
| Query 컨트롤러 | `social/block/controller/UserBlockingController.java` |
| Command 서비스 | `social/block/service/BlockCommandService.java` |
| Query 서비스 | `social/block/service/UserBlockingService.java` |
| 매퍼(쓰기) | `repository/social/follow/BlockCommandMapper.java` + `mapper/follow/blockCommand-mapper.xml` |
| 매퍼(읽기) | `social/block/repository/UserBlockingMapper.java` + `mapper/wadizReplication/social/block/userblocking-mapper.xml` |

#### 엔드포인트 상세

##### POST `/api/v1/social/block`

- **Service**: `BlockCommandService.block()` — `BlockCommandService.java:18`
- **처리 순서**:
  1. `validate(userId, targetUserId)` — null/<=0/same 검증 → `IllegalArgumentException`
  2. `unfollow()` — `FollowCommandComponent.getFollowNo` → 존재 시 `unFollowUsers(..., USER_BLOCK)`
  3. `blockUser()` — `BlockCommandMapper.upsertBlockAndLogging(userId, targetUserId, optIn=true)`:
     ```sql
     -- blockCommand-mapper.xml:4-11
     INSERT INTO UserBlocking(UserId, TargetUserId, OptIn) VALUES (#{userId}, #{targetUserId}, #{optIn})
       ON DUPLICATE KEY UPDATE OptIn = #{optIn};
     INSERT INTO UserBlockingLog(UserId, TargetUserId, OptIn)
       VALUES (#{userId}, #{targetUserId}, #{optIn});
     ```
  - 실패 시 `BlockCommandException` → 500 응답.

##### POST `/api/v1/social/unblock`

- `BlockCommandService.unblock()` — `BlockCommandMapper.upsertBlockAndLogging(..., optIn=false)`. 팔로우 관계 복구는 하지 않음.

##### GET `/api/v1/social/block`

- `UserBlockingService.isBlocking` → `UserBlockingMapper.isBlocking`:
  ```sql
  -- userblocking-mapper.xml:8-13
  SELECT (CASE WHEN COUNT(*) = 1 THEN TRUE ELSE FALSE END)
  FROM wadiz_wave_follow.UserBlocking
  WHERE UserId = #{userId} AND TargetUserId = #{targetUserId} AND OptIn = true
  ```

##### GET `/api/v1/social/block/all`

- `UserBlockingMapper.findBlockedUserIds` — `userblocking-mapper.xml:18-23`.

##### GET `/api/v1/social/block/userinfo`

- `UserBlockingMapper.findBlockedUserInfo` — `userblocking-mapper.xml:46-95`.
- `usingCursor=true` 시 `CONCAT(UNIX_TIMESTAMP(Updated), UNIX_TIMESTAMP(Registered)) AS CursorId`.
- `ProfileImageService.getProfileImageUrlWithFixedRandomDefault` 로 기본 이미지 매핑 (`UserBlockingService.java:36`).

##### GET `/api/v1/social/block/userinfo/count`

- `UserBlockingMapper.countBlockedUserInfo` — `userblocking-mapper.xml:100-107`.

##### (추가 경로) 회원탈퇴 시 전체 차단 해지

- `BlockCommandService.unblockAll(userId)` — 컨트롤러 노출 없음. `privacy/service/PrivacyDropoutProcessingService:140` 에서 호출.
- SQL: `blockCommand-mapper.xml:13-23`:
  ```sql
  UPDATE UserBlocking SET OptIn = false WHERE UserId = #{userId};
  INSERT INTO UserBlockingLog(UserId, TargetUserId, OptIn)
  SELECT UserBlocking.UserId, UserBlocking.TargetUserId, UserBlocking.OptIn
  FROM UserBlocking WHERE UserId = #{userId} AND OptIn = false;
  ```

### 3.3 Recommendation

파일 인벤토리:

| 구성요소 | 경로 |
|---|---|
| 컨트롤러 | `social/recommendation/controller/RecommendationUserController.java` |
| 서비스 | `social/recommendation/service/RecommendationUserInfoService.java` |
| 매퍼(쓰기) | `repository/social/follow/RecommendationMapper.java` + `mapper/follow/recommend-mapper.xml` |
| 매퍼(읽기) | `social/recommendation/repository/RecommendationUserInfoMapper.java` + `mapper/wadizReplication/social/recommendation/recommendationUserInfo-mapper.xml` |
| 외부 Gateway | `social/recommendation/gateway/StoreGateway.java`, `infrastructure/campaign/CampaignGateway.java`(외부, 본 repo에 존재) |

#### 엔드포인트 상세

##### PUT `/api/v1/social/recommendation/user/{userId}/allow-info`

- `RecommendationUserInfoService.rejectRecommendation(userId, !isAllow)` — 외부 인터페이스는 "허용" 이지만 내부 테이블은 `UserRecommendationRejection` 으로 저장.
- `RecommendationMapper.upsertRecommendationRejection` + `insertRecommendationRejectionLog`:
  ```sql
  -- recommend-mapper.xml:6-19
  INSERT INTO wadiz_wave_follow.UserRecommendationRejection(UserId, IsRejected)
  VALUES (#{userId}, #{isRejected})
    ON DUPLICATE KEY UPDATE IsRejected = #{isRejected};
  INSERT INTO wadiz_wave_follow.UserRecommendationRejectionLog(UserId, IsRejected)
  VALUES (#{userId}, #{isRejected});
  ```

##### GET `/api/v1/social/recommendation/user/{userId}/allow-info`

- `RecommendationUserInfoMapper.isRejectionRecommendation` — `recommendationUserInfo-mapper.xml:16-20`. 응답은 `!isRejected` (controller 레벨에서 invert).

##### POST `/api/v1/social/recommendation/user/kakao/has-user`

- `RecommendationUserInfoMapper.hasSocialRecommendationUserByTargetUserIdAndUserIds(..., provider="kakao")`:
- 주요 특징 (`recommendationUserInfo-mapper.xml:22-50`):
  - `wadiz_db.webpages_OAuthMembership` 와 `Provider = #{provider}` JOIN
  - 추천거절/Follow/Blocking 에 대해 **NOT-JOIN 대신 `EXISTS(...=FALSE) OR NOT EXISTS` 패턴** 사용(DBA 권고, DB-1968)

##### POST `/api/v1/social/recommendation/user/kakao/user-info`

- `findSocialRecommendationUserInfoByTargetUserIdAndUserIds(..., provider="kakao", type=KAKAO)` — `recommendationUserInfo-mapper.xml:60-147`.
- 반환 컬럼: `UserId, NickName, Provider, ProviderUserId, ProviderLinkedAt, PhotoUrl, MembershipEnd, MembershipState, FollowerCount, commonFollowCount, RecommendationType, CursorId`.
- 공통 서브쿼리 `_COMMON_FOLLOW_COUNT` (recommendationUserInfo-mapper.xml:5-14):
  ```sql
  SELECT count(f1.FollowerUserId)
  FROM wadiz_wave_follow.Follow f1
  INNER JOIN wadiz_wave_follow.Follow f2 ON (f1.FollowingUserId = f2.FollowingUserId AND f2.OptIn is true)
  WHERE f1.FollowerUserId = #{loggedUserId} AND f2.FollowerUserId = U.UserId AND f1.OptIn is true
  ```
- 서비스 레벨: `collectRecommendationUserInfoStatistics` 가 `CampaignGateway.getFundingCountByUserIds` + `StoreGateway.getFundingCountByUserIds` 를 호출해 펀딩수/스토어구매수를 병합. 실패 시 `null` 설정 (`RecommendationUserInfoService.java:149-178`).

##### POST `/api/v1/social/recommendation/user/wadiz/user-info`

- `findWadizRecommendationUserInfoByTargetUserId(..., type=WADIZ)` — `recommendationUserInfo-mapper.xml:149-200`.
- 쿼리 요지: `FollowEvent` 최근 3일 & IsCancel=FALSE & COUNT>=3 인 EventUserId를 추천 대상으로 집계 후 Rejection/Follow/Blocking 필터. `ORDER BY CNT DESC LIMIT #{size}`.

##### POST `/api/v1/social/recommendation/user/contacts/count`

- `findContactsRecommendationCountByTargetUserId` — `recommendationUserInfo-mapper.xml:203-222`.
- `ConnectedAppContactUser` JOIN `UserProfile` (주석: "`UserStatus='NM'` 조건은 DBA 권고로 제거 — 성능 저하 주요 원인").

##### POST `/api/v1/social/recommendation/user/contacts/user-info`

- `findContactsRecommendationUserInfoByTargetUserId` — `recommendationUserInfo-mapper.xml:225-331`.
- 3가지 `cursorType` 분기:
  - `USER_REGISTER_AND_USER_ID`: `CONCAT(UNIX_TIMESTAMP(UP.WhenCreated), LPAD(UP.UserId, '10','0'))`
  - `CONTACT_NAME_AND_CONNECTED_ID`: `CONCAT(UAC.OrderKey, '-', UAC.ContactName, CACU.ConnectedUserId)` + ASCII 범위 기반 정렬(한글>영문>숫자>특수문자)
  - `MATCHING_REGISTER_AND_USER_ID` (default): `CONCAT(UNIX_TIMESTAMP(CACU.Registered), LPAD(CACU.ConnectedUserId, '10','0'))`

##### (추가 경로) 회원탈퇴 시

- `RecommendationUserInfoService.dropRecommendationRejectionData(userId)` — `@Async @Transactional("followTxManager")`. `privacy/service/PrivacyDropoutProcessingService:141` 에서 호출. `DELETE FROM UserRecommendationRejection[Log]`.

### 3.4 Contact

파일 인벤토리:

| 구성요소 | 경로 |
|---|---|
| V3 컨트롤러 | `social/contact/UserAppContactV3UserController.java` |
| Old 컨트롤러 | `social/contact/UserAppContactOldController.java` |
| V3 서비스 | `social/contact/service/UserAppContactV3Service.java` |
| Old 서비스 | `social/contact/service/UserAppContactService.java` |
| Query 컴포넌트 | `social/component/UserAppContactQueryComponent.java` |
| 도메인 | `social/domain/UserAppContactDomain.java` |
| 매퍼 | `repository/social/follow/UserAppContactMapper.java` + `mapper/follow/userAppContact-mapper.xml` |

#### 엔드포인트 상세

##### GET `/api/v3/users/{userId}/contacts/information`

- `UserAppContactV3Service.getUserAppContactsInfo(userId)` — `UserAppContactQueryComponent.getUserAppContactsInfo` → `UserAppContactMapper.findContactInfo`:
  ```sql
  -- userAppContact-mapper.xml:133-143
  SELECT uacs.IsAllowed, uacs.Updated,
         (SELECT COUNT(AppContactId) FROM UserAppContacts uac WHERE uac.UserId = #{userId}) AS ContactCount
  FROM UserAppContactSync uacs WHERE uacs.UserId = #{userId}
  ```

##### PUT `/api/v1/users/contacts/{userId}/sync-allow`

- `UserAppContactService.allowSync(userId, isAllowed)` — `UserAppContactService.java:91`
- DB: `upsertSyncAllow` + `insertSyncAllowLog` — `userAppContact-mapper.xml:21-34`
- 부가 호출: `CrmApiGateway.sendContactSyncAllow` — HTTP POST to CRM (attribute `contact_subscribe_custom`, event `contact_subscribe_updated`). `CrmApiGateway.java:56-74`

##### GET `/api/v1/users/contacts/{userId}/information`

- `UserAppContactOldController.getContactInfo` → `UserAppContactService.getUserAppContactsInfo` → 위 V3와 동일한 `findContactInfo`.

##### PUT `/api/v1/users/contacts/{userId}` (주소록 업로드)

- `UserAppContactService.upload()` — `UserAppContactService.java:106` (Bulk), 단건 버전 `uploadDetail()` 별도 존재하나 현재 컨트롤러에서는 Bulk만 사용.
- **Redis Lock**: `RedisLockManager.trySpinLock(CONTACTS, userId, "UPLOAD")`, key 획득 실패 시 `FAIL_WAIT_PROGRESS` (HTTP 408).
- **제약**:
  - 동기화 비활성화 → `NOT_ALLOWED_UPLOAD` (403)
  - 10,000건 초과 → `OVER_THE_MAXIMUM` (403) (정확도 일부 오차 허용)
  - 단일 요청 최대 100건 (`@Size(min=1, max=100)`)
  - 매칭 최대 5명 (`CONTACTS_MATCHING_LIMIT`)
- **처리 단계**:
  1. `EncryptComponent.mobileNumberEncrypt` 로 전화번호 해시 생성
  2. `bulkDeleteConnectedUsersByUserIdAndMobileNumberHash` + `bulkDeleteContactsByUserIdAndMobileNumberHash`
  3. `bulkInsertContactWithoutPK` + `bulkInsertIgnoreConnectedAppContactUser`
- **핵심 SQL** (userAppContact-mapper.xml):
  - `bulkInsertContactWithoutPK` L77-83:
    ```sql
    INSERT IGNORE INTO UserAppContacts (UserId, ContactName, MobileNumberHash) VALUES ...
    ```
  - `bulkInsertIgnoreConnectedAppContactUser` L86-114 — 전화번호 매칭. `@grp/@row_num` 변수로 매칭 대상 중 WhenCreated DESC로 limit(5)명까지 연결.
- **후처리 (컨트롤러)**: `UserAppContactOldController.upload:60` 에서 `sendConnectedUserCountToCrm` 호출 (`@Async`) → `CrmApiGateway.sendConnectedContactCount(userId, count)` HTTP.

##### DELETE `/api/v1/users/contacts/{userId}`

- `UserAppContactService.delete(userId, checkSyncAllow=true)` — `UserAppContactService.java:468`
- 동기화 비활성화 후 Redis Lock → 슬라이스(500건) 반복 삭제 with `LIMIT`:
  ```sql
  -- userAppContact-mapper.xml:192-197, 220-225
  DELETE FROM UserAppContacts WHERE UserId=#{userId} LIMIT #{size}
  DELETE FROM ConnectedAppContactUser WHERE OwnerUserId=#{userId} LIMIT #{size}
  ```

##### PUT `/api/v1/users/contacts/{userId}/my-number/reconnection`

- `UserAppContactService.reConnectMyNumber()` — `UserAppContactService.java:532`
- 1) `deleteConnectedUsersByConnectedUserId(userId)` 로 자기 번호 매칭 전체 제거
- 2) 전화번호 해시 생성 후 `insertIgnoreConnectedAppContactUserByConnectedUserId`:
  ```sql
  -- userAppContact-mapper.xml:117-122
  INSERT IGNORE INTO ConnectedAppContactUser(AppContactId, OwnerUserId, ConnectedUserId)
  SELECT UAC.AppContactId, UAC.UserId, #{connectedUserId}
  FROM wadiz_wave_follow.UserAppContacts AS UAC
  WHERE UAC.MobileNumberHash = #{mobileNumberHash} AND UAC.UserId != #{connectedUserId}
  ```
  - 주의 주석(userAppContact-mapper.xml:119): 신규 매칭 시 5명 제한이 있지만 본 메서드는 제한을 벗어날 수 있음.

##### (추가 경로) 회원탈퇴 시

- `UserAppContactService.dropData(userId)` — `@Async @Transactional("followTxManager")`. `delete(userId, false)` + `deleteConnectedUsersByConnectedUserId` + `deleteSyncAllow[Log]`. 실패 시 `UserMonitoringSlackChannel.send(...)`.
- `sendConnectedUserCountsToCrm(List<Integer>)` — 여러 userId 에 대해 Braze 75건 단위로 슬라이스 전송. `UserAppContactService.java:556-569`, `CrmApiGateway.java:86-104`.

### 3.5 Feed

파일 인벤토리:

| 구성요소 | 경로 |
|---|---|
| 컨트롤러 | `social/feed/controller/FeedUserInfoController.java` |
| 서비스 | `social/feed/service/FeedUserInfoService.java` |
| 매퍼(읽기) | `social/feed/repository/FeedUserInfoMapper.java` + `mapper/wadizReplication/feed/feedUserInfo-mapper.xml` |
| 모델 | `social/feed/model/FeedUserInfo.java` |
| Converter | `social/feed/converter/FeedUserInfoConverter.java` |

#### 엔드포인트 상세

##### POST `/api/v1/users/feed/userInfo/get`

- **Request** (`FeedUserInfoDto.FeedUserInfoBulkRequest`):
  - `loggedUserId: Integer` — 선택. 0보다 크면 팔로잉 여부 포함.
  - `userIds: List<Integer>` — 필수(`@NotEmpty`).
- **Service**: `FeedUserInfoService.getFeedUserInfo` — `FeedUserInfoService.java:20`
- **DB**: `FeedUserInfoMapper.findFeedUserInfoByTargetUserIdAndUserIds` — `feedUserInfo-mapper.xml:5-32`:
  ```sql
  SELECT U.UserId, U.NickName, U.UserStatus, P.PhotoUrl,
         M.end MembershipEnd, M.state MembershipState
         <if test="loggedUserId > 0">, IF(F.FollowNo IS NULL, false, true) IsFollowing</if>
  FROM wadiz_db.UserProfile U
    LEFT JOIN wadiz_db.PhotoCommon P ON P.PhotoId = U.PhotoId
    LEFT JOIN wadiz_membership.member M ON U.UserId = M.user_id
    <if test="loggedUserId > 0">
    LEFT JOIN wadiz_wave_follow.Follow F
      ON U.UserId = F.FollowingUserId AND F.FollowerUserId = #{loggedUserId} AND F.OptIn = true
    </if>
  WHERE U.UserId IN (...)
  ```
- **Response** 필드: `userId, encUserId, nickName, userStatus, profileImageUrl, following, hasMembership` (`FeedUserInfoDto.java:26-48`).
- 주석 TODO: 서포터클럽 여부, 멤버십 도메인 연동 보류.

---

## 4. DB 스키마

관측 가능한 테이블과 컬럼(모두 MyBatis XML에서 직접 추출, 전체 DDL은 본 repo에 없음).

### 4.1 `wadiz_wave_follow` 스키마 (팔로우·차단·추천·주소록 쓰기 전용)

| 테이블 | 주요 컬럼(XML 기반) | 용도 |
|---|---|---|
| `Follow` | `FollowNo(PK, auto)`, `FollowerUserId`, `FollowingUserId`, `OptIn`, `Updated`, (Unique: FollowerUserId+FollowingUserId) | 팔로우 관계. `insertIgnoreFollows` + `updateFollows` upsert 패턴 (follow-mapper.xml:5-66) |
| `FollowLog` | `FollowNo`, `FollowerUserId`, `FollowingUserId`, `OptIn`, `Description`, `Registered` | 팔로우 변경 이력 (description=`FollowLogDescription` enum). insert-select 패턴 (follow-mapper.xml:23-37) |
| `FollowEvent` | `EventNo(PK)`, `EventUserId`, `EventType`, `EventValue`, `Registered`, `Updated`, `IsCancel` | 활동이력(펀딩/지지서명). EventType 1~4 |
| `UserBlocking` | `UserId`, `TargetUserId`, `OptIn`, `Updated`, `Registered`, (Unique: UserId+TargetUserId) | 차단 관계. upsert via `ON DUPLICATE KEY UPDATE` (blockCommand-mapper.xml:4-11) |
| `UserBlockingLog` | `UserId`, `TargetUserId`, `OptIn` | 차단 변경 이력 |
| `UserRecommendationRejection` | `UserId`, `IsRejected` | 추천 거부 설정 |
| `UserRecommendationRejectionLog` | `UserId`, `IsRejected` | 추천 거부 이력 |
| `UserAppContactSync` | `UserId(PK)`, `IsAllowed`, `Updated` | 주소록 동기화 허용 플래그 |
| `UserAppContactSyncLog` | `UserId`, `IsAllowed` | 허용 변경 이력 |
| `UserAppContacts` | `AppContactId(PK, auto)`, `UserId`, `ContactName`, `MobileNumberHash`, (Unique: UserId+MobileNumberHash 추정 — DuplicateKeyException 처리 존재) | 사용자가 업로드한 주소록 엔트리 |
| `ConnectedAppContactUser` | `AppContactId`, `OwnerUserId`, `ConnectedUserId`, `Registered` | 전화번호 매칭으로 연결된 와디즈 회원 |

엔티티 매핑(JPA 아닌 MyBatis POJO):

| 엔티티 클래스 | 파일 | 비고 |
|---|---|---|
| `FollowEntity` | `repository/social/follow/entity/FollowEntity.java:13-90` | `followNo, followerUserId, followingUserId, optIn, registered, fundingCnt, signatureCnt` |
| `FollowLogEntity` | `repository/social/follow/entity/FollowLogEntity.java` | — |
| `EventEntity` | `repository/social/follow/entity/EventEntity.java:12-58` | `eventNo, eventUserId, eventType, eventValue, registered` |
| `UserAppContactEntity` | `repository/social/follow/entity/UserAppContactEntity.java` | — |
| `UserAppContactSyncEntity` | `repository/social/follow/entity/UserAppContactSyncEntity.java` | `isAllowed, updated` |
| `UserAppContactInfoEntity` | `repository/social/follow/entity/UserAppContactInfoEntity.java` | `SyncInfo` collection + `contactCount` (resultMap in userAppContact-mapper.xml:10-13) |
| `ConnectedAppContactUserEntity` | `repository/social/follow/entity/ConnectedAppContactUserEntity.java` | — |
| `UserAppConnectedContactCountEntity` | `repository/social/follow/entity/UserAppConnectedContactCountEntity.java` | `userId, connectedCount` |
| `EventCountEntity` | `repository/social/follow/entity/EventCountEntity.java` | — |

**주의**: 본 repo의 social 도메인은 **JPA 엔티티가 아니다**. `@Entity`/`@Table` 어노테이션은 존재하지 않으며, 모든 매퍼는 MyBatis `@Mapper`. 엔티티 클래스는 `resultType`/`resultMap` 용 POJO.

### 4.2 조인되는 외부 스키마 (읽기 전용)

| 스키마.테이블 | 용도 | 쿼리 위치 예시 |
|---|---|---|
| `wadiz_db.UserProfile` | 회원 상태(`UserStatus` = NM/IA/DO), NickName, PhotoId | follow-mapper.xml 전역, userblocking-mapper.xml, feedUserInfo-mapper.xml |
| `wadiz_db.PhotoCommon` | 프로필 사진 URL (`PhotoUrl`) | 동일 |
| `wadiz_db.BackingPayment`, `wadiz_db.TbInvest` | 펀딩 집계 (FundingCnt) | follow-mapper.xml:207-215 |
| `wadiz_db.webpages_OAuthMembership` | Provider(kakao 등) 연동 조회 | recommendationUserInfo-mapper.xml:33, 104 |
| `wadiz_db.TbProviderProfile` | 생일 조회 | followReplication-mapper.xml:17 |
| `wadiz_db.UserSettings` | `NOT_SHOW_BIRTH_DAY` 필터 | followReplication-mapper.xml:26 |
| `wadiz_membership.member` | 멤버십 기간/상태(`end`, `state`) | recommendationUserInfo-mapper.xml:125, feedUserInfo-mapper.xml:19 |

### 4.3 Enum 참조

| Enum | 위치 | 값 |
|---|---|---|
| `FollowLogDescription` | `social/constant/FollowLogDescription.java` | FOLLOW, FOLLOW_ALL, UN_FOLLOW, DROP_USER, USER_BLOCK |
| `SocialReturnCode` | `social/code/SocialReturnCode.java` | FOLLOW_BLOCKED_USER, CANNOT_FOLLOW_SELF, FOLLOW_LIMIT_EXCEEDED |
| `FollowConst.SearchSortType` | `social/follow/constant/FollowConst.java` | ASC, DESC |
| `UserBlockingConst.SearchSortType` | `social/block/constant/UserBlockingConst.java` | ASC, DESC |
| `RecommendationType` | `social/recommendation/constant/RecommendationType.java` | WADIZ, KAKAO, CONTACTS |
| `RecommendationCursorType` | `social/recommendation/constant/RecommendationCursorType.java` | MATCHING_REGISTER_AND_USER_ID, USER_REGISTER_AND_USER_ID, CONTACT_NAME_AND_CONNECTED_ID |
| `RecommendationCursorSortType` | `social/recommendation/constant/RecommendationCursorSortType.java` | ASC, DESC |
| `RecommendationUserOrderBy` | `social/recommendation/constant/RecommendationUserOrderBy.java` | DEFAULT, USERID_ASC/DESC, USERNAME_ASC/DESC, NICKNAME_ASC/DESC, ACTIVITY_COUNT_DESC |
| `UserAppContactConst.ContactUploadType` | `social/contact/constant/UserAppContactConst.java` | INSERTED, UPDATED, DELETED |
| `UserAppContactConst.ContactUploadResult` | 동 | FAIL, NOT_VALID_MOBILE_NUMBER, INSERTED, UPDATED, DELETED, OVER_THE_MAXIMUM |
| `UserAppContactConst.ErrorCode` | 동 | FAIL_WAIT_PROGRESS(408), NOT_ALLOWED_UPLOAD(403), OVER_THE_MAXIMUM(403), FAIL(500) |

---

## 5. 외부 의존성

### 5.1 메시징 (RabbitMQ — social 도메인 기준)

| 방향 | Exchange | Routing Key | Publisher/Consumer 위치 |
|---|---|---|---|
| — | — | — | **social 도메인은 RabbitMQ publish를 직접 수행하지 않는다.** (확인 방법: `Grep` on `social/**` for `RabbitTemplate`, `publisher`, `@RabbitListener`, `@EventListener` → 매치 0) |

단, **social 도메인 밖**에서 탈퇴/휴면 시 다음 publish가 일어나며, social 도메인의 drop 정리(`FollowV3Service.dropUser`, `UserAppContactService.dropData`, `BlockCommandService.unblockAll`, `RecommendationUserInfoService.dropRecommendationRejectionData`)가 **같은 호출 그래프에 포함**된다:

- `CrmGatewayPublisher.publishDropOutInfo(userIdStr)` → Exchange `crmGateway.braze.USER_STATUS.{profile}` / Routing key `DELETE_USER` — `privacy/service/PrivacyDropoutProcessingService:146`
- 해당 코드 순서(`PrivacyDropoutProcessingService.java:137-147`):
  ```
  userAppContactService.dropData(targetUserId);
  blockCommandService.unblockAll(targetUserId);
  recommendationUserInfoService.dropRecommendationRejectionData(targetUserId);
  termsService.rejectByDropOut(targetUserId);
  ...
  crmGatewayPublisher.publishDropOutInfo(dropUserId.toString());
  followV3Service.dropUser(dropUserId);
  ```

### 5.2 HTTP 연동 (본 repo에서 호출)

| 대상 | Gateway | Base URL 설정 | 호출 시점 |
|---|---|---|---|
| `kr.wadiz.user.link` | `infrastructure/link/UserLinkGateway` | `user-link.api.url` (`user.yml:320-323`) e.g. `https://dev-platform.wadizcorp.net/link` | **social 도메인에서 직접 호출 없음.** `user/link/*` 패키지의 `UserLinkFollowService`/`UserLinkActionService` 경로(`UserLinkController /api/v1/link/*`)에서만 호출. |
| CRM (Braze) | `infrastructure/crm/CrmApiGateway` | `wadiz.crm-api.base-url` (`user.yml:281`) | contact sync 변경, connected count 업데이트 (`@Async` HTTP POST) |
| Campaign (펀딩 집계) | `infrastructure/campaign/CampaignGateway` | 본 repo 존재 | 추천 리스트 펀딩수 (카카오/와디즈) |
| Store (스토어 구매수) | `social/recommendation/gateway/StoreGateway` | `wadiz.store.api.base-uri` | 추천 리스트 스토어 구매수 |
| Push/Inbox | `infrastructure/push/PushGateway` | 본 repo 존재 | 팔로우 성공 시 인박스/푸시 (`followTaskExecutor` 비동기) |
| Slack(모니터링) | `infrastructure/slack/UserMonitoringSlackChannel` | — | `dropRecommendationRejectionData` / `dropData` 에러 시 |

### 5.3 Redis

| 용도 | 위치 | 키 전략 |
|---|---|---|
| 분산 Lock (주소록 업로드/삭제) | `lock/RedisLockManager.trySpinLock(CONTACTS, userId, action)` — `UserAppContactService.java:107, 238, 474` | `LockType.CONTACTS` |
| 생일 범위 캐시 (24h) | `FollowBirthDaysCacheService` — `CacheKeyGenerator("FOLLOW", BIRTH_DAY, startDay, endDay)` | 24시간 TTL |

### 5.4 외부 서비스/모듈 (읽기 조회)

- `CommonPrivacyService.findCurrentAccountStatus[List]` — 휴면/탈퇴 판별 (`DeprecatedRecommendService.java:73, 93`)
- `InactiveAccountByWadizMapper.selectArchivalDataByProviderUserId` — SNS provider → userId 변환 (`DeprecatedRecommendService.java:115`)
- `ProfileImageService.getProfileImageUrlWithFixedRandomDefault` — 차단 유저 프로필 이미지 기본값 적용 (`UserBlockingService.java:36`)
- `UserLocaleMapper.findUserLocaleByUserIds` — 팔로우 알림 다국어 처리 (`FollowCommandComponent.java:180`)

---

## 6. 경계 및 미탐색 영역

### 6.1 본 문서에서 확인할 수 없는 것

1. **Kafka 발행/구독 체인**: 본 repo 전체(social 포함)에서 Kafka 사용 코드 0건(`Grep kafka|KafkaTemplate|ProducerRecord` → 0). 태스크 요구사항에 "Kafka publish 토픽"이 있었으나 본 repo는 **RabbitMQ만** 사용한다. `kr.wadiz.user.link`(Neo4j + Kafka)가 wave.user의 DB 변경을 어떻게 구독하는지는 **본 repo에서는 알 수 없다**(Debezium CDC/별도 ETL/해당 repo 내 다른 경로 가능성 — 확인 불가).
2. **`Follow` 테이블 CDC/Outbox**: social 도메인의 팔로우/차단 서비스는 MySQL에 직접 쓰고, 어떤 이벤트도 publish 하지 않는다. 외부 서비스가 이 데이터를 어떻게 동기화하는지는 **wave.user 밖**.
3. **`kr.wadiz.user.link` 의 역방향 호출**: 본 repo는 `user-link` 로 HTTP 호출만 하고, link 서비스로부터의 callback/subscription 구조는 wave.user에 존재하지 않는다.
4. **Push/CRM 메시지 포맷 전체**: `FollowFormData` 의 인박스 템플릿 full body, `PushGateway` 구현 세부는 본 파일 범위 밖(별도 infrastructure 분석 필요).
5. **`Follow` 테이블의 DDL(컬럼 타입·인덱스·제약)**: `ddl/` 폴더에는 `change_20250110.sql`, `create-catchup.sql` 등 catch-up 관련만 존재. Follow/UserBlocking/UserAppContacts DDL은 이 repo 트리에 없다 → 컬럼명/타입은 XML 추출만 가능.

### 6.2 잠재적 리스크 / 주목할 점 (코드 기반 관측)

1. **`FollowV3Controller` (`/api/v3/social/...`)** 은 `@Deprecated`. `FollowV3UserController` (`/api/v3/users/...`)가 live. IAM-3451 배포 후 삭제 예정 (주석 `FollowV3Controller.java:30`).
2. **`DeprecatedRecommendController`** — 신규 추천은 `RecommendationUserController` 사용. 해당 컨트롤러는 `Callable` 기반 비동기 MVC 스타일로 구식.
3. **MAX_FOLLOWING = 3000**: 하드코딩(`FollowCommandComponent.java:33`). 변경 시 서비스 리빌드 필요.
4. **주소록 `sortType` 치환**: `follow-mapper.xml`·`userblocking-mapper.xml`·`recommendationUserInfo-mapper.xml` 에서 `ORDER BY ... ${sortType}` 사용(문자열 치환). 컨트롤러에서 Enum(`SearchSortType`) 바인딩으로 차단하지만, 신규 사용자 주의 필요.
5. **`RecommendationUserOrderBy.orderBy` 파라미터 사실상 무력화**: `RecommendationUserController:76-80` 주석에 "성능 튜닝상 `ACTIVITY_COUNT_DESC` 만 유효" 명시. 쿼리에서 `orderBy != 'ACTIVITY_COUNT_DESC'` 경로는 최적화되지 않음.
6. **`insertIgnoreConnectedAppContactUserByConnectedUserId`** (내 전화번호 재연결) — 매칭 5명 제한 미적용. 번호 변경이 빈번한 유저는 5명 초과 매칭 가능(XML 주석 언급).
7. **`@Transactional("followTxManager")` 와 `@Async`**: `dropData`, `dropRecommendationRejectionData`, `sendConnectedUserCount[s]ToCrm` 에서 동시 사용. async 스레드에서 tx manager 루크업이 정상 동작하도록 configure 되어있음을 전제.
8. **`updateFollows` SQL의 독특한 패턴** (follow-mapper.xml:53-66): `SET F.OptIn = UP.isValid AND #{optIn}` — `UserStatus != 'DO'` 유저에 한해서만 optIn 반영. 데이터 정합성 유지 의도.
9. **`EventService.get` 의 `catch` 블럭 로그 오타** — `log.warn("[활동이력-카운터] 조회 에러: {]", e.getMessage())` (`EventService.java:109`). `{}` 가 아닌 `{]` 로 포맷 지시자 깨짐 → 로그에 userId 미출력.
10. **`selectRecommendFollowList`**  (`recommend-mapper.xml:36-43`) 의 hardcoded `INTERVAL -3 DAY` / `COUNT >= 3` — 최근 3일간 3번 이상 이벤트 발생한 유저 기준. 파라미터화 되지 않음.

### 6.3 향후 분석이 필요한 부분

- `com.wadiz.wave.user/src/main/java/com/wadiz/wave/infrastructure/**` 전수 조사 (gateway 메서드·외부 endpoint 맵)
- `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/link/**` — `UserLinkController` + `UserLinkFollowService/ActionService/InfrastructureService` 의 캐싱·호출 정책
- `config/WadizRabbitMqConfig` 의 프로파일별 exchange 이름 매핑 (test/dev/live)
- 배치/스케줄 모듈 — `social/` 외에 팔로우 카운트 집계/동기화 배치가 있는지 (`@Scheduled` 전수)

---

**요약**: social 도메인은 50개 엔드포인트, 5개 서브도메인으로 구성되며 전적으로 MySQL(`wadiz_wave_follow`) MyBatis 기반이다. 팔로우 알림은 Push Gateway(HTTP) + Async executor, CRM 연동은 CrmApiGateway(HTTP), 친구추천의 펀딩/스토어 집계는 외부 gateway HTTP 호출로 병합한다. **이 repo의 social 도메인은 Kafka도 RabbitMQ publish도 수행하지 않으며, `kr.wadiz.user.link` 와의 연동은 `user/link` 패키지에서만 HTTP GET 호출로 제한된다.** social 도메인 → Neo4j 간의 갱신 경로는 본 repo에서는 관측 불가.
