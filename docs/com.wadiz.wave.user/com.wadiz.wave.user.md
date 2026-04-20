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
