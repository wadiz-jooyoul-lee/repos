> 📅 **2026-09-02 cloud_live pull 보강** (2 커밋)
>
> ### BE3-769 — 따라잡기 글로벌: 요청 country/language 를 main2 상품 API 로 전파
> - **신규 `outbound/external/product/Main2CatchUpClient.java`(83줄)** — 따라잡기 상품 조회를 별도 클라이언트로 분리하고, 요청의 `wadiz-country`·`wadiz-language` 를 main2 상품 API 로 전파합니다. 기존 `ProductAdapter`(−55줄)·`BonusProductAdapter`(−40줄)에서 해당 로직을 걷어냈습니다.
> - 검증 테스트 `Main2CatchUpClientLocaleTest`(89줄) 신규.
> - 관련: [`main1-api`](../com.wadiz.api.main.md) 가 `/api/v4` 를 신설(DISPLAY-1691)하고 [`main2-api`](../main2-api.md) 가 호출 경로를 v4 로 바꾼(DISPLAY-1688) 것과 **같은 따라잡기 글로벌 확대 작업**입니다.
>
> ### `wadiz-country`/`wadiz-language` 헤더 상수 중앙화
> - **신규 `common/WadizHeaders.java`(18줄)** — 두 헤더 이름을 상수로 모았습니다. `HeaderLocaleResolver`·`SwaggerConfig`·`CampaignGateway`·`NormalMailV3Gateway` 가 이 상수를 참조하도록 바꿨습니다.
>
> ---
>
> 📅 **2026-07-21 master pull 보강** (3 커밋 · 전부 BE3-592 단일 피처)
>
> ### BE3-592 — 회원가입 쿠폰 정보 조회 API 추가 (user-api)
> - **`coupon/controller/CouponInquiryController.java`** — 회원가입 쿠폰 조회 컨트롤러 신규(user-api). `coupon/service/SignupCouponInquiryService.java`가 조회 로직 담당.
> - 가입 쿠폰 조회를 reward의 **by-issue-key 단건 API**로 대체(`f8124a6` 계열). 신규 게이트웨이 `coupons/RewardCouponGateway.java` + 설정 `config/RewardCouponApiConfig.java`로 reward-api(RWD-5794로 추가된 issueKey 상세 조회)를 호출. 단위 테스트 3종 추가.
>
> ---
>
> 📅 **2026-07-10 master pull 보강** (14 커밋 · 전부 BE3-464 단일 피처)
>
> ### BE3-464 — 따라잡기(catchup) 보너스 + v2 API 신설
> - **`catchup/adapter/in/CatchUpV2Controller.java:48`** — 신규 v2 네임스페이스 `/api/v2/users/{userId}/catchup/*` 컨트롤러. status(통합), daily(GET/POST), bonus(GET/POST), notification(PUT/GET) 7개 매핑. 예외는 단일 `@ExceptionHandler(CatchUpException.class)`(`:126`)로 처리하고 예외가 들고 있는 `v2Code`+HTTP status 로 응답(컨트롤러 하드코딩 없음). 기존 v1 의 status/bonus 는 여기로 이관(`CatchUpBonusController` 삭제).
> - **`catchup/adapter/in/CatchUpController.java:139`** — v1 에 활성 이벤트 조회 `GET /v1/catchup/event/active`, 관리자용 캐시 강제 갱신 `POST /v1/catchup/event/cache/evict` 2개 추가(v1 나머지는 미변경).
> - **`catchup/adapter/outbound/persistence/JPACatchUpEventRepository.java:18`** — 이벤트를 Redis 에 **TTL 1시간**(`CACHE_TTL_SECONDS=3600`, key `catchup:events:all`) 캐싱. 이벤트 겹침 시 **최근 등록 이벤트 우선(registeredAt DESC)**. `evictCache()`(`:128`)로 서버 3대 동시 반영.
> - **`catchup/application/service/CatchUpService.java:57`** — `completeProductV2`: 데일리 v2 액션은 v1(멱등-silent)과 달리 **strict** — 이미 완료(PASS 완료 포함)된 카드 재액션 시 `DailyAlreadyProcessedException`(409), 리소스 미변경. `appliedAction`(web orchestrator 가 funding 강등 시 PASS 치환) 반환. `getCatchUpProductsV2WithLock`(`:227`)에 `firstTime` 플래그 부활.
> - **`catchup/application/service/CatchUpBonusService.java:187`** — 보너스 카드 액션(WISH/NOTIFICATION/PASS) + 랜덤 포인트. **예산 소진 시 amount=0 + `budgetExhausted=true`** 로 액션은 그대로 반영, 꽝도 point=0.
> - **`catchup/adapter/outbound/external/point/PointAdapter.java:62`** — point-api RANDOM 포인트 연동. **422=예산소진**(`budgetExhausted()`), **204=꽝**(미발행, catch_up_point 미생성), 4xx 는 상태/바디/요청컨텍스트 로깅 후 호출자에 전달. 요청에서 amount 제거(400 수정).
> - **`catchup/adapter/outbound/external/product/BonusProductAdapter.java:32`** — 보너스 상품 풀은 main2-api `GET /api/v1/catchup/{userId}/coming-soon-today`(응답모델 데일리와 동일, `code==2000` 검증)에서 조회. base-url property 키 `catchup.platform.base-url` 로 정리.
> - **`catchup/adapter/outbound/persistence/entity/CatchUpBonusEntity.java:23`** — 신규 테이블 3종: `catch_up_bonus`(catch_up_id UNIQUE), `catch_up_bonus_product`(월 파티션 스냅샷), `catch_up_action_history`(`source_id`로 액션 이력 영구 보존, `CatchUpActionHistoryEntity.java:27`). DDL 은 `ddl/create-catchup-bonus.sql`, DB-2869 기준. `@OrderColumn(order_no)` 단방향 이슈로 catch_up_bonus_id·order_no nullable.
> - **`catchup/domain/exception/CatchUpV2ReturnCode.java:11`** — v2 표준 코드(SCREAMING_SNAKE, code+HTTP status 한 쌍): DAILY_NOT_COMPLETE(422)/NOT_FOUND(404)/ALREADY_PROCESSED(409)/INTERNAL_SERVER_ERROR(500). v1 은 `CatchUpV1ReturnCode`(@Deprecated dot.case)로 분리해 v1 클라 호환 유지.
>
> ---

# com.wadiz.wave.user

> **Phase 2 심층 분석 진행 중**. 전체 엔드포인트는 [`api-endpoints.md`](./api-endpoints.md), 도메인별 상세는 `api-details/` 하위 참조.
>
> | 도메인 | 파일 | 컨트롤러 수 |
> |---|---|---|
> | Supporter Signature V1 | [`api-details/signature-v1.md`](./api-details/signature-v1.md) | 6 |
> | Supporter Signature V3 | [`api-details/signature-v3.md`](./api-details/signature-v3.md) | 11 |
> | Social (follow/block/contact/recommendation/feed) | [`api-details/social.md`](./api-details/social.md) | 11 |
> | Account | [`api-details/account.md`](./api-details/account.md) | 9 |
> | Misc (privacy/terms/coupon/message/bank/push/maker/link/sourcingclub) | [`api-details/misc-domains.md`](./api-details/misc-domains.md) | ~20 |
> | Session/Event Invite/CatchUp | [`api-details/session-event-catchup.md`](./api-details/session-event-catchup.md) | 7 |

## 개요
와디즈 **User Platform 의 레거시 모놀리식 API** ("Wave" 플랫폼). 회원/계정/소셜(팔로우·차단·피드·연락처)/서포터(Signature V1·V3)/메이커 정보/약관/쿠폰/뱅크 인증/푸시 타깃/링크/소싱클럽 등 사실상 **전사 유저 도메인 전체**를 한 서비스에 모아둔 가장 큰 레거시 코어. Org: `wadiz-service`. Java package: `com.wadiz.wave`.

> **이관 진행 중**: Signature V3 → `co.wadiz.api.community` 로 분리 중.

## 기술 스택
- **Java 1.8**, **Spring Boot** (gradle/boot.gradle 외부 분리, 사내 Maven `repo.wadizcorp.com/repository/plugins` 사용)
- **MyBatis** + JPA 일부, **MySQL** (gradle/mysql.gradle 조건부 적용)
- **RabbitMQ** (이벤트 발행)
- **Redis** (gradle/redis.gradle, 캐시)
- **EhCache** (`ehcache.xml`)
- **Eureka** (deprecated, 단계적 제거)
- **bootRepackage executable jar** (전통적 fat-jar 운영)
- 운영 포트 `9020`, Swagger `/swagger-ui.html`, H2 콘솔(개발) `/console`

## 아키텍처
- 패키지: `com.wadiz.wave.user.<domain>.{controller,service,repository,domain,dto}`.
- 컨트롤러 **57개**. 도메인 폭이 매우 넓어 사실상 user 관련 모든 기능을 망라.
- MyBatis Mapper XML 위치: `src/main/resources/mapper/wadiz/<domain>/*-mapper.xml`.
- 설정 흐름(레거시):
  1. `user.yml` (소스에 포함된 공통 property)
  2. `/home/wadiz/.wave/wave-local.yml` 로 override (서버별)
  3. `/app/com.wadiz.wave.user/config/user-local.yml` 로 다시 override
  - 2023.2 Renewal로 git 관리 + profile-yml 분기 전환 진행 중.

## API 엔드포인트 (도메인 그룹)

| 도메인 | 컨트롤러 (대표) | 책임 |
|---|---|---|
| **supporter signature v1** | `SupporterSignatureOldController`, `SupporterSignatureTrackingController`, `SupporterSignaturePointController`, `SupporterSignatureInterestDegreeController`, `SupporterSignatureCommunicationController`, `SupporterSignatureShareController` | 서포터 응원 서명 V1 |
| **supporter signature v3** | `SupporterSignatureV3Controller`, `SupporterSignatureV3UserController`, `SupporterSignatureKeywordV3Controller`, `SupporterSignatureInterestDegreeV3Controller`, `SupporterSignaturePointV3Controller`/`UserController`, `SupporterSignatureCommunicationV3Controller`/`UserController`, `SupporterSignatureAffiliateV3Controller`/`UserController` | V3 (community 로 이관 중) |
| **privacy** | `CommonPrivacyController`, `DestructionPrivacyController`, `InactiveAccountController`, `DecodingAccountReactivateController`, `PrivacyDropoutController` | 개인정보 파기·휴면·재활성·탈퇴 |
| **sourcingclub** | `SourcingClubController` | 소싱클럽 |
| **terms** | `TermsController`, `TermsV2Controller` | 약관 동의 |
| **message** | `MessageController` | 쪽지/메시지 |
| **coupon** | `IssueCouponController` | 쿠폰 발급 |
| **social/recommendation** | `RecommendationUserController` | 유저 추천 |
| **social/contact** | `UserAppContactV3UserController`, `UserAppContactOldController` | 앱 연락처 동기화 |
| **social/follow** | `FollowV3Controller`, `FollowV3UserController`, `FollowOldController`, `DeprecatedRecommendController`, `EventController` | 팔로우 V3/구버전 |
| **social/feed** | `FeedUserInfoController` | 피드용 유저 정보 |
| **social/block** | `BlockCommandController`, `UserBlockingController` | 차단 |
| **push** | `PushTargetController` | 푸시 대상 정의 |
| **verification/bankaccount** | `BankController` | 본인 계좌 인증 |
| **link** | `UserLinkController` | 유저 링크(추천 그래프 호출) |
| **maker** | `MakerInfoController` | 메이커 정보 조회 |
| **account** | `FindAccountController`, `UserAccountInfosController`, `UserLocaleController`, `JoinEquityAccountController`, `UserAgeVerificationController`, `UserTimeZoneController`, `ProfileImageController`, `UserSettingsController`, `DropAccountController` | 계정/프로필/로케일/시간대/연령인증/탈퇴 |

총 ≈ 57개 컨트롤러. 엔드포인트 수는 수백 개 추정.

## 주요 API 상세 분석

### 1. SupporterSignatureV3Controller — 서포터 응원 서명 V3
- 펀딩 프로젝트에 서포터가 응원/서명을 남기는 V3 API.
- DB(MyBatis):
  - `mapper/wadiz/supporter/signature/supporterSignature-mapper.xml` — 서명 본문
  - `supporterSignatureKeyword-mapper.xml`, `supporterSignatureKeywordData-mapper.xml` — 키워드 추출/저장
  - `supporterSignatureTracking-mapper.xml` — 트래킹/노출 이력
  - `supporterSignaturePoint-mapper.xml` — 서명에 따른 포인트 적립
  - `supporterSignatureShare-mapper.xml` — 공유 통계
- **현재 community 서비스로 이관 중** — 신규 코드는 `co.wadiz.api.community` 우선.

### 2. FollowV3Controller / FollowV3UserController — 팔로우
- 유저 ↔ 유저, 유저 ↔ 메이커 팔로우 관리.
- Kafka 발행 → `kr.wadiz.user.link` 가 그래프 갱신.
- DB: `t_user_follow` 등.

### 3. PrivacyDropoutController + InactiveAccountController + DestructionPrivacyController
- 회원 탈퇴 → 휴면 전환 → 일정 후 파기의 3단계 라이프사이클.
- DB: `mapper/wadiz/privacy/destructionPrivacy-mapper.xml`, `inactiveAccountByWadiz-mapper.xml`.
- 법정 보관 기간 + GDPR/개인정보보호법 대응.

### 4. UserAccountInfosController — 회원 정보 통합 조회
- 다른 서비스가 한 번에 user 메타를 가져갈 때 사용.
- 응답: 닉네임, 프로필, 약관, 알림 설정, 푸시 토큰 등.

### 5. BankController — 본인 계좌 인증
- 신한은행 API 연동(`mapper/wadiz/shinhan-mapper.xml`).
- 1원 인증 또는 실명 확인.

### 6. IssueCouponController — 쿠폰 발급
- 가입/이벤트/캠페인 쿠폰 발급 처리.

### 7. UserLocaleController / UserTimeZoneController
- 사용자 로케일·시간대 조회/변경. DB: `user-locale*-mapper.xml`, `user-timezone-mapper.xml`.

## DB 스키마 요약 (대표 테이블)

| 영역 | 테이블 추정 | Mapper XML |
|---|---|---|
| Signature | `t_supporter_signature*`, `t_signature_keyword*`, `t_signature_tracking`, `t_signature_point`, `t_signature_share` | `mapper/wadiz/supporter/signature/*` |
| Privacy | `t_destruction_privacy`, `t_inactive_account_by_wadiz` | `mapper/wadiz/privacy/*` |
| Terms | `t_terms_accept`, `t_terms_accept_history` | `mapper/wadiz/terms/*` |
| User Settings | `t_user_settings`, `t_user_locale`, `t_user_locale_history`, `t_user_timezone`, `t_user_age_verification` | `mapper/wadiz/user/*` |
| Bank | `t_bank` | `mapper/wadiz/bank-mapper.xml` |
| Verification | `t_verification` | `mapper/wadiz/verification-mapper.xml` |
| Sourcing Club | `t_sourcing_club` | `mapper/wadiz/sourcingclub/*` |
| Shinhan 연동 | (실명/계좌 인증 로그) | `mapper/wadiz/shinhan-mapper.xml` |
| Repository (JPA) | `social/{follow,recommendation,feed,block}/repository`, `terms/repository`, `link/repository` | (JPA) |

## 외부 의존성

- **MySQL** (메인), 서비스별 schema 분리 가능 (`spring.datasource` 다중 정의).
- **Redis** — 세션·캐시.
- **EhCache** — JVM 인-메모리 캐시.
- **RabbitMQ** — 이벤트 발행 (팔로우/탈퇴/약관 변경 등 → 다운스트림 컨슈머).
- **Eureka** — 서비스 디스커버리(Deprecated, K8s service 로 이전 중).
- **신한은행 API** — 계좌 본인인증.
- **사내 Maven Nexus** (`repo.wadizcorp.com`) — 빌드 의존성.
- 호출자: 거의 모든 와디즈 백엔드/프론트가 user 정보를 위해 wave.user를 호출.

## 특이사항

- **57개 컨트롤러 / 단일 모놀리식** — 와디즈 백엔드 중 최대 규모. 분해(community, account, link 등)로 분산 진행 중.
- **Signature V3 → community 이관** 진행 중 — 신규 기능은 community에 작성, 기존 호출자는 wave.user 유지.
- **V1/V3 컨트롤러 공존** — Old/V1/V3 명명으로 deprecated 표기. 점진 제거 예정.
- **Eureka deprecated** — K8s service discovery 로 전환 진행.
- **설정 파일 다중 외부 override** — 운영자가 서버에 yml 직접 두는 레거시 운영. 2023.2 Renewal로 git 기반 profile 분기로 이전 중.
- **executable jar (`bootRepackage`)** — Docker/K8s 미적용 또는 일부만 적용. 일부 환경에선 systemd로 직접 실행.
- 사내 Maven (`repo.wadizcorp.com`) HTTP(non-https) 사용 — 사내 망 한정.
- **이미 `com.wadiz.wave` 그룹의 다른 서비스(wave.payment 등)가 추가로 분리됐을 가능성** — 본 repo는 user 한정.
- 마이그레이션 정책상 새 기능 추가는 community/account/link 신규 서비스에 우선, wave.user는 유지보수 중심.

---

## 최근 변경사항

**분석 갱신일: 2026-05-29** (최초: 2026-04-20)

| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 회원 정보 제공 bulk API 추가 | 2026-04-22 | BE3-353 |
| detailBulk API — 탈퇴 회원 placeholder 응답 옵션 추가 (`includeDropOut`) | 2026-04-27 | BE3-353 |
| 닉네임 변경 endpoint 신규 추가 + 검증 룰 이전 | 2026-04-30 | BE3-378 |
| 닉네임 변경 시 Braze `first_name` 동기화 추가 | 2026-04-30 | BE3-378 |
| 닉네임 예외 코드 다국어 시트 기준으로 정렬 (`FORBIDDEN_NICKNAME`, `INVALID_NICKNAME_PATTERN`) | 2026-05-12 | BE3-378 |
