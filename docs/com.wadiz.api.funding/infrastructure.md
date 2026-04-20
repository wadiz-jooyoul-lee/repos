# adapter/infrastructure 모듈 상세 스펙

> **기록 범위**: `adapter/infrastructure/src/main/` 아래의 소스 코드에서 **직접 관측 가능한** 구현 표면만 기록한다.
> 비즈니스 UseCase 구현체는 외부 jar(`funding-core`)에 있으므로 내부 로직은 기술하지 않는다.
> 기록 대상: Gateway/Repository 구현 클래스, MyBatis XML SQL, `@RedisHash` 엔티티, MongoDB `@Document` 컬렉션, Spring `@EventListener` 핸들러, AWS SQS 리스너, 외부 HTTP 클라이언트 메서드.
> 기록 불가 항목은 "확인 불가 (bootstrap 모듈에서 주입)" 으로 표기한다.

---

## 1. 개요 & 기록 범위

`adapter/infrastructure` 모듈은 헥사고날 아키텍처의 **Secondary Adapter(아웃바운드)** 계층이다. `funding-core`가 정의한 Gateway 포트 인터페이스를 구현하며, 실제 데이터 저장소(MySQL, Redis, MongoDB)와 외부 서비스(ERP/Douzone, DataPlus, 결제 PG, 알림, 번역, AI 등)를 연결한다.

주요 역할:
- **MySQL 영속성**: MyBatis Mapper XML(88개) + Spring Data JDBC Repository(약 79개)
- **Redis 세션/캐시**: `@RedisHash` 기반 주문 세션/주문서/재고, `StringRedisTemplate` 기반 중복 방지 락
- **MongoDB 로그**: 알림·주문·리워드 변경·번역 실패 이력 5개 컬렉션
- **외부 HTTP 클라이언트**: 27개 클라이언트 클래스 (RestTemplate 기반)
- **이벤트**: Spring `ApplicationEventPublisher` 디스패치 + 14개 `@EventListener` 핸들러 + AWS SQS 리스너 1개

---

## 2. 패키지 구조

```
java/com/wadiz/api/funding/
├── client/          # 외부 HTTP 클라이언트 (27개 서비스 그룹)
├── config/          # 인프라 설정 (MyBatis, Redis, Mongo, JDBC, 재시도 등)
├── domain/          # 인프라 측 이벤트 핸들러, 도메인 확장 구현체
├── event/           # EventDispatcherImpl (ApplicationEventPublisher 래퍼)
├── mongo/           # MongoDB Document DTO + MongoRepository + Gateway 구현체
├── persistence/     # MyBatis @Mapper + Spring Data JDBC Repository + DTO
├── redis/           # @RedisHash 엔티티 + KeyValueRepository + Gateway 구현체
└── support/         # JSON/타입 변환 유틸, 데이터 상수

resources/
├── config/          # application-infrastructure.yml (profile 별 외부 서비스 설정)
├── mapper/          # MyBatis XML (88개, 서브폴더 포함)
└── templates/mail/  # Thymeleaf 메일 HTML 템플릿 (4개)
```

---

## 3. 외부 HTTP 클라이언트 인벤토리

모두 `RestTemplate` 기반(`@FeignClient` 없음). `application-dev.yml` 의 base URL 값을 기준으로 기재한다.

| 클라이언트 클래스 | 역할 | Base URL (dev 환경 기준) | 주요 엔드포인트/메서드 | 인증/헤더 패턴 |
|---|---|---|---|---|
| `ErpClient` | ERP(Douzone) 부서·직원·미수금 조회 | `https://dev-erp.wadizcorp.kr` | `GET /api/MA/.../IF003` (부서), `GET .../IF004` (직원), `GET /api/FI/.../IF017` (미수금) | HMAC 인증 2단계: `PreAuthKeys` → `token` 후 `X-Authenticate-Token` 헤더 |
| `ErpSettlementClient` | ERP(Douzone) 정산 진행/결과/수수료/정산내역서 조회 | `https://rc-settlement.wadizcorp.kr:8443` | `GET .../IF033` (정산진행), `GET .../IF034` (정산결과), `GET .../IF041` (정산내역서), `GET .../fees/projects/{id}` (수수료), `GET /auth/temporary/token`, `GET /download/file` | 동일 2단계 인증, `X-Authenticate-Token` |
| `ProjectDataplusClient` | 펀딩 프로젝트 대시보드 통계 (결제·유입·서포터) | `https://dev-api.wadizdata.team/dataplus` | `GET /v1/reward/{no}/funding-status/metrics`, `GET .../trends`, `GET .../traffic-status/metrics`, `GET .../channels`, `GET .../supporter-info/metrics`, `GET .../demographics`, `GET .../traffic-status/{key}` | 없음 (내부망) |
| `ComingSoonDataplusClient` | 오픈예정 프로젝트 대시보드 통계 | `https://dev-api.wadizdata.team/dataplus` | `GET /v1/coming-soons/{no}/notification-status/metrics`, `GET .../trends`, `GET .../traffic-status/metrics`, `GET .../trends`, `GET .../channels`, `GET .../subscriber-info/metrics`, `GET .../demographics` | 없음 (내부망) |
| `PayApiClient` | PG 결제 승인·취소 (nicepay-api 서버) | `https://dev-platform.wadizcorp.net/nicepay-api` | `POST /api/v2/auth/approval`, `POST /api/v2/auth/cancel`, `POST /api/v2/reserve/approval`, `POST /api/v2/reserve/cancel`, `POST /v1/scheduled/approval`, `POST /v1/scheduled/cancel`, `POST /api/v1/billkey` | `Authorization: Bearer {secret}` |
| `NotificationClient` | 통합 알림 발송 (메일·푸시·알림함·비즈메시지·구독자) | `http://dev-app01:9990` / `https://dev-platform.wadizcorp.net` | `POST /api/v2/send` (메일), `POST /api/v2/send/batch`, `POST /api/v3/send`, `GET /api/v1/notifications/subscribers/incomingType/.../incomingKey/...`, `POST /api/v1/notifications/publishes/...`, `POST /api/v1/notifications/messages/batch/biz`, `POST /push/api/v1/push/user`, `POST /inbox/messages`, `POST /push/api/v1/push/inbox` | `Authorization: {mailToken}` / `Authorization: {inboxToken}` |
| `AlimtalkV2Client` | 카카오 알림톡 v2 발송 | `https://dev-platform.wadizcorp.net/alimtalk` | `POST /api/v2/message/alimtalk` | `Authorization: Bearer {secret}` |
| `SmsV2Client` | SMS v2.1 발송 | `https://dev-platform.wadizcorp.net/sms` | `POST /api/v2.1/message/sms` | `Authorization: Bearer {secret}` |
| `FriendtalkClient` | 카카오 친구톡 이미지 업로드 | `https://dev-platform.wadizcorp.net/friendtalk-api` | `POST /api/v2/upload/image` | `Authorization: Bearer {secret}` |
| `BrazeClient` | Braze CRM 유저 이벤트 트래킹 | `http://dev-app01:9990/api/v1/crmgateway/braze` | `PUT /users/track` | 없음 (내부 게이트웨이) |
| `BrazeV2Client` | Braze CRM v2 (클래스만 존재, 동일 경로 추정) | 동일 | — | — |
| `MembershipApiClient` | 멤버십 혜택 조회·사용 통보 | `http://dev-app01:9990/usergateway/membership` | `POST /user/availables`, `GET /user/{userId}`, `POST /user/{userId}/product/{productId}/benefit/{benefitId}/{type}`, `PUT /user/{userId}/paymentMethod` | 없음 (내부망) |
| `PointClient` | 포인트 사용·환불·적립 (wave-point SDK 래퍼) | `http://dev-app01:9990` | SDK 경유: `getAccountByUserId`, `postAccount`, `postTransaction`, `deleteTransaction`, `postIssue`, `getTemplateByAlias` | SDK 내부 처리 |
| `RewardClient` | 쿠폰·컬렉션·만족도 (com.wadiz.api.reward SDK 래퍼) | `http://dev-app01:9990` (포트 9990) | SDK 경유: `getAllTemplate`, `getAllIssue`, `redeemByAPI`, `use`, `delete`, `getDiscountAmount`, `getCoupon`, `refund`, `getAllCollectionByCampaignId`, `search` (만족도), `getQtySatisfaction`, `getSatisfactionByCampaignIdAndUserId`, `hiddenSatisfaction` | SDK 내부 처리 |
| `SettlementClient` | 펀딩 정산 스케줄·안심번호 최종결제일 조회 (내부 settlement 서비스) | `http://dev-app01:9990/funding-settlement` | `POST /api/v1/transaction/bulk`, `GET /api/v1/schedule/settlement/projects`, `GET /api/v1/schedule/settlement/due-date` | 없음 (내부망) |
| `StoreClient` | 스토어 프로젝트/상품 조회 (store 서비스) | `http://dev-app01:9990/store` | `GET /api/orders/qty`, `GET /api/projects/by-funding`, `GET /api/projects/{projectNo}`, `GET /api/projects/{projectNo}/products/aggregation` | 없음 (내부망) |
| `UserClient` | 유저 연령 인증 조회 | `http://dev-app01:9990/user` | `GET /api/v1/users/{userId}/age-verification` | 없음 (내부망) |
| `FollowClient` | 팔로우 이벤트 등록·취소·팔로잉 목록 조회 | 동일 (`user-client.base-url`) | `POST /api/v1/users/followers/events`, `PUT /api/v1/users/followers/events`, `GET /api/v1/users/followers/user/{userId}/following/user-id` | 없음 (내부망) |
| `MakerUserClient` | 메이커 언어 설정 조회 (bulk) | 동일 (`user-client.base-url`) | `POST /api/v1/makers/languages/bulk` | 없음 (내부망) |
| `CorporationClient` | Startup API 법인(메이커) 조회·팔로워 확인 | `http://dev-app01:9990/api/v1/startup` | `GET /maker`, `GET /maker/campaignType/{type}/campaignId/{id}`, `GET /maker/{corpNo}/fundings/project-nos`, `POST /maker/follow/check` | 없음 (내부망) |
| `MakerProfileClient` | Startup API 메이커 프로필 등록 | 동일 (startup.base-url) | `POST /maker/interconnect/funding` | 없음 (내부망) |
| `MakerPushClient` | Startup API 메이커 Push 크레딧 발급 | 동일 (startup.base-url) | `POST /maker/{corpNo}/push/credit/issuance` | 없음 (내부망) |
| `MakerClubClient` | Startup API 메이커 등급 목록 조회 | 동일 (startup.base-url) | `GET /maker-club` | 없음 (내부망) |
| `TranslateClient` | 텍스트/HTML 번역 (사내 번역 서비스) | `https://rc-platform.wadizcorp.net/global` | `POST /translate/text`, `POST /translate/html` | `Authorization: Bearer {token}` |
| `AiTranslateClient` | AI 번역 (스토리·이미지) | `https://dev-translate.wadizdata.team/v2` | `POST /story`, `POST /media` | 없음 (내부망) |
| `ExchangeRateClient` | 환율 조회 | `https://rc-platform.wadizcorp.net/global` | `GET /exchange-rates/{countryCode}` | `Authorization: Bearer {token}` |
| `CountryClient` | 국가 목록 조회 | `https://dev.wadiz.kr/web` | `GET /v1/countries` | 없음 |
| `CategorySearchClient` | 검색 카테고리 조회 (펀딩) | `http://dev-app01:9990/searcher` | `GET /api/search/categories?serviceType=FUNDING` | 없음 (내부망) |
| `RewardBridgeClient` | 배송 추적 택배사 목록 조회 | `http://dev-app01:9990/reward-bridge` | `GET /api/v1/tracker/bridge/companylist` | 없음 (내부망) |
| `AIReviewClient` | AI 심의 요청 | `https://dev-api.wadizdata.team/genai` | `POST /v2/maker/content-review` | 없음 (내부망) |
| `ProjectAiSummaryClient` | 프로젝트 AI 요약 조회 | `https://project-data.wadizdata.team` | `GET /summary?project_id={no}&lang={lang}` | 없음 (내부망) |
| `BizMoneyClient` | 광고비 무료 포인트 발행 (ad-payment 서비스) | `https://rc-api.business.wadiz.kr/payments` | `POST /v1/biz-money/free/publish` | HTTP Basic Auth (`client:secret`) |
| `BankAccountClient` | 계좌 실명 확인 (Coocon) | `https://dev2.coocon.co.kr:8443/.../acctnm_rcms_wapi.jsp` | `POST` (form-data `JSONData=`) | `secretKey` + `apiKey` 필드 포함 |
| `BusinessVerifyClient` | 사업자 진위 확인 (공공데이터포털 국세청 API) | `http://api.odcloud.kr/api/nts-businessman/v1` | `POST /validate?serviceKey={key}` | `serviceKey` URL 파라미터 |
| `CertClient` (abstract) | K-본인인증 (EMSIT·SafetyKorea 구체 클래스) | 확인 불가 (bootstrap 모듈에서 주입) | `getCertDetailResult(certId)` | `authKey` 필드 |
| `SafeNumberApiClient` | 안심번호 등록·해제 (통신사 API) | 확인 불가 (bootstrap 모듈에서 주입) | `GET /register?CID=...`, `GET /release?CID=...` | `CID` + `CIDPWD` 쿼리 파라미터 |
| `OCRClient` | 사업자등록증 OCR (Naver CLOVA) | `https://enx57j76yz.apigw.ntruss.com/custom/v1/...` (dev) | `POST {invokeUrl}` | `X-OCR-SECRET: {secretKey}` |
| `AttachClient` | S3 Presigned URL 발급 | AWS S3 SDK (`S3Presigner`) | `PutObjectPresignRequest` (업로드 전용, 10초 TTL) | AWS SigV4 (`BUCKET_OWNER_READ`) |
| `SlackClient` | Slack Webhook 메시지 발송 (키 매핑 방식) | 설정 파일 `webhooks.{key}` URL | `POST {webhookUrl}` | 없음 |
| `SlackWebhookClient` | Slack Webhook 단일 메시지 발송 | 설정 파일 `webhook-url` | `POST {webhookUrl}` | 없음 |

---

## 4. MySQL 영속성 계층

### 4-1. MyBatis Mapper XML 인벤토리 (총 88개)

| 폴더 | 파일 수 | XML 파일 목록 |
|---|---|---|
| `mapper/` (루트) | 47 | `AnnouncementMapper.xml`, `BackingPaymentCancelMapper.xml`, `BackingPaymentCouponMapper.xml`, `BackingPaymentDiscountBenefitMapper.xml`, `BackingPaymentMapper.xml`, `BackingPaymentMappingMapper.xml`, `BackingPaymentRefundMapper.xml`, `BackingPaymentStatisticMapper.xml`, `BackingRewardMapper.xml`, `BillkeyVerificationStatusMapper.xml`, `CampaignAskForEncoreMapper.xml`, `CampaignContractMapper.xml`, `CampaignMapper.xml`, `CampaignMarkerMapper.xml`, `CampaignScreeningRewardItemMapper.xml`, `CampaignSummary.xml`, `CatalogFeedMapper.xml`, `ComingSoonApplicantMapper.xml`, `ComingSoonApplicantStatisticMapper.xml`, `ComingSoonMapper.xml`, `EventDayMapper.xml`, `FundingMapper.xml`, `GlobalProjectMapper.xml`, `GlobalProjectRewardMapper.xml`, `IPLicenseMapper.xml`, `MakerMapper.xml`, `ManagerMapper.xml`, `NewsMapper.xml`, `NewsNotificationMapper.xml`, `ParticipationMapper.xml`, `PartnerMapper.xml`, `PaymentSummationMapper.xml`, `PingpongPaymentReminderMapper.xml`, `ReactionMapper.xml`, `RewardEventMapper.xml`, `RewardItemMapper.xml`, `RewardLimitedTimeOfferMapper.xml`, `RewardMapper.xml`, `RewardProductMapper.xml`, `RewardRefundMapper.xml`, `ShippingMapper.xml`, `SignatureMapper.xml`, `StockRewardMapper.xml`, `TbCodeSubMapper.xml`, `TranslationStatisticsMapper.xml`, `UserMapper.xml`, `WishMapper.xml` |
| `mapper/additionalservice/` | 2 | `AdditionalServiceMapper.xml`, `CampaignAdditionalServiceMapper.xml` |
| `mapper/aireview/` | 1 | `AIReviewMapper.xml` |
| `mapper/askforencore/` | 1 | `CampaignAskForEncoreRepository$SqlMap.xml` |
| `mapper/bottomsheet/` | 1 | `BottomSheetMapper.xml` |
| `mapper/campaign/` | 2 | `CampaignCommandMapper.xml`, `CampaignScreeningMapper.xml` |
| `mapper/campaign/submitapproval/` | 3 | `CampaignAgreementMapper.xml`, `CampaignSubmitApprovalMapper.xml`, `SettlementCommandMapper.xml` |
| `mapper/campaigncongratulationhistory/` | 1 | `CampaignCongratulationHistoryRepository$SqlMap.xml` |
| `mapper/campaignupdate/` | 3 | `CampaignUpdateLanguageRepository$SqlMap.xml`, `CampaignUpdateNotificationDenyRepository$SqlMap.xml`, `CampaignUpdateNotificationRepository$SqlMap.xml` |
| `mapper/dashboard/` | 1 | `MakerDashboardMapper.xml` |
| `mapper/encouragestoreopen/` | 1 | `EncourageStoreOpen.xml` |
| `mapper/languageexpansion/` | 1 | `LanguageExpansionMapper.xml` |
| `mapper/makerclub/` | 1 | `MakerClubMapper.xml` |
| `mapper/makerinvitation/` | 1 | `MakerInvitationMapper.xml` |
| `mapper/migration/` | 1 | `MigrationOngoingStoryMapper.xml` |
| `mapper/pendingstandby/` | 1 | `CampaignPendingStandby.xml` |
| `mapper/personalverification/` | 1 | `PersonalVerificationResultRepository$SqlMap.xml` |
| `mapper/project/` | 1 | `ProjectCorporationMapper.xml` |
| `mapper/qualitymonitor/` | 1 | `TranslationQualityMonitorMapper.xml` |
| `mapper/reaction/` | 1 | `BoardReactionUserRepository$SqlMap.xml` |
| `mapper/rewardevent/` | 2 | `RewardEventBenefitMappingRepository$SqlMap.xml`, `RewardEventRandomBenefitMappingRepository$SqlMap.xml` |
| `mapper/safenumber/` | 1 | `SafeNumberMapper.xml` |
| `mapper/settlement/` | 1 | `CampaignSettlementMapper.xml` |
| `mapper/settlement/excel/` | 2 | `SlipExcelMapper.xml`, `TaxInvoiceExcelMapper.xml` |
| `mapper/shipping/` | 1 | `DeliveredNotificationMapper.xml` |
| `mapper/shipping/pending/` | 1 | `PendingNotificationMapper.xml` |
| `mapper/storycopy/` | 1 | `StoryCopyMapper.xml` |
| `mapper/storytranslation/` | 1 | `StoryTranslationMapper.xml` |
| `mapper/studio/log/` | 1 | `StudioPayloadLogMapper.xml` |
| `mapper/studio/pricing/` | 2 | `CampaignPackagePlanHistoryMapper.xml`, `CampaignPackagePlanMapper.xml` |
| `mapper/studio/section/` | 1 | `StudioSectionMapper.xml` |
| `mapper/support/` | 1 | `Clauses.xml` (공통 SQL fragment) |
| `mapper/user/` | 1 | `UserCustomsCodeMapper.xml` |

> `Clauses.xml`은 공통 `<sql>` 조각(예: `DAMO_ENC_KEY` 암호화 패턴, `IFNULL` 다국어 폴백)을 공유한다.

### 4-2. Spring Data JDBC Repository 인벤토리 (총 79개)

`persistence/` 하위 서브패키지별 주요 Repository:

| 서브패키지 | Repository (Spring Data JDBC `CrudRepository` 구현) |
|---|---|
| `announcement/` | `AnnouncementRepository`, `AnnouncementByMenuRepository`, `AnnouncementDisplayRepository`, `AnnouncementDoNotShowAgainRepository`, `AnnouncementExposureRepository`, `AnnouncementHistoryRepository` |
| `askforencore/` | `CampaignAskForEncoreRepository` |
| `backing/` | `BackingRepository` |
| `backing/backingpayment/` | `BackingPaymentRepository`, `AdminImmediatePaymentLogRepository`, `PaymentApprovalRequestResultRepository` |
| `backing/backingpaymentcancellog/` | `BackingPaymentCancelLogRepository`, `BackingPaymentAdminCancelLogRepository` |
| `backing/backingpaymentcoupon/` | `BackingPaymentCouponRepository` |
| `backing/backingpaymentdiscountbenefit/` | `BackingPaymentDiscountBenefitRepository` |
| `backing/backingpaymentexternalinfo/` | `BackingPaymentExternalInfoRepository` |
| `backing/backingpaymentmapping/` | `BackingPaymentMappingRepository` |
| `backing/backingpaymentpoint/` | `BackingPaymentPointRepository` |
| `backing/backingrewardcomposition/` | `BackingRewardCompositionRepository` |
| `backing/backingrewardoption/` | `BackingRewardOptionRepository` |
| `backing/backingrewardset/` | `BackingRewardSetRepository` |
| `billkey/` | `BillkeyVerificationStatusRepository` |
| `campaign/` | `CampaignRepository`, `CampaignAutoOpenRepository`, `CampaignContractRepresentativeRepository`, `CampaignRewardDelayRepository`, `ComingSoonRepository`, `ComingSoonApplicantRepository` |
| `campaign/submitapproval/` | (MyBatis Mapper로만 처리) |
| `campaigncongratulationhistory/` | `CampaignCongratulationHistoryRepository` |
| `campaignscreening/` | `CampaignScreeningDocumentUploadedRepository` |
| `campaignsnapshot/` | `CampaignSnapshotRepository` |
| `campaignupdate/` | `CampaignUpdateRepository`, `CampaignUpdateLanguageRepository`, `CampaignUpdateLogRepository`, `CampaignUpdateNotificationRepository`, `CampaignUpdateNotificationDenyRepository`, `CampaignUpdateNotificationDenyLogRepository` |
| `iplicense/` | `IPLicenseRepository`, `IPLicenseLogRepository`, `IPLicenseTagRepository`, `IPLicenseTopRankRepository` |
| `makerinvitation/` | `MakerInvitationRepository`, `MakerInvitationCodeRepository`, `MakerInvitationBenefitRepository`, `MakerInvitationBenefitPaymentRepository`, `MakerInvitationBenefitPaymentLogRepository` |
| `misc/` | `PhotoCommonRepository` |
| `personalconsent/` | `PersonalConsentItemRepository`, `CampaignPersonalConsentItemMappingRepository` |
| `personalverification/` | `PersonalVerificationResultRepository` |
| `projectpause/` | `ProjectPauseRepository`, `ProjectPauseHistoryRepository` |
| `reaction/` | `BoardReactionRepository`, `BoardReactionUserRepository`, `ReactionTypeRepository` |
| `refund/` | `RewardRefundPolicyRepository` |
| `reward/` | `RewardRepository`, `RewardLimitedTimeOfferRepository`, `RewardLimitedTimeOfferHistoryRepository` |
| `rewardevent/` | `RewardEventRepository`, `RewardEventParticipantRepository`, `RewardEventBenefitMappingRepository`, `RewardEventRandomBenefitMappingRepository` |
| `rewarditem/` | `RewardItemRepository` |
| `rewardpayment/` | `RewardPaymentRepository` |
| `settlement/` | `RewardSettlementRepository`, `RewardSettlementRateRepository`, `CampaignPackagePlanRepository`, `SettlementSystemRepository` |
| `settlement/excel/` | `SlipExcelRepository`, `TaxInvoiceExcelRepository` |
| `signature/` | `SignatureRepository` |
| `simplepay/` | `BillkeyManagerRepository`, `RewardPasscodeRepository`, `WadizSimplePayUseLogRepository` |
| `spaceexhibition/` | `SpaceExhibitionRepository` |
| `storeopennotification/` | `StoreOpenNotificationRepository` |
| `user/` | `UserProfileRepository` |
| `wish/` | `UserWishProjectRepository` |

> `{Repository}$SqlMap.xml` 형식은 Spring Data JDBC의 `@Query`가 아닌, MyBatis Mapper XML을 통해 복잡한 쿼리를 제공하는 혼합 패턴이다.

### 4-3. 접근 테이블 요약

도메인별 주요 테이블은 각 `api-details/*.md` 에서 상세 SQL과 함께 이미 기술되어 있다 (아래 링크 참조). 여기서는 infrastructure 레이어 관점 그룹만 정리한다.

| 그룹 | 주요 테이블 | 상세 문서 |
|---|---|---|
| 결제·펀딩 참여 | `BackingPayment`, `BackingPaymentCancelLog`, `BackingPaymentCoupon`, `BackingPaymentDiscountBenefit`, `BackingPaymentPoint`, `BackingPaymentExternalInfo`, `BackingRewardSet`, `BackingRewardOption`, `BackingRewardComposition`, `Backing`, `PaymentApprovalRequestResult` | [payment-flow.md](./api-details/payment-flow.md), [supporter-funding-refund.md](./api-details/supporter-funding-refund.md) |
| 캠페인·리워드 | `Campaign`, `CampaignSnapshot`, `CampaignAutoOpen`, `CampaignRewardDelay`, `ComingSoon`, `ComingSoonApplicant`, `Reward`, `RewardItem`, `RewardLimitedTimeOffer`, `RewardPayment`, `RewardEvent`, `RewardEventParticipant`, `RewardEventBenefitMapping` | [campaign-public.md](./api-details/campaign-public.md), [reward.md](./api-details/reward.md) |
| 정산·요금제 | `RewardSettlement`, `RewardSettlementRate`, `SettlementSystem`, `CampaignPackagePlan`, `CampaignPackagePlanHistory`, `CampaignAdditionalService` | [settlement.md](./api-details/settlement.md) |
| 배송 | `Shipping`, `ShippingNotification` | [settlement.md](./api-details/settlement.md) |
| 새소식·공지 | `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateTagMapping`, `CampaignUpdateNotification`, `CampaignUpdateNotificationDeny`, `CampaignUpdateNotificationDenyLog`, `Announcement`, `AnnouncementDisplay`, `AnnouncementByMenu`, `AnnouncementDoNotShowAgain`, `AnnouncementExposure`, `AnnouncementHistory` | [news-announcement.md](./api-details/news-announcement.md) |
| 서명·찜·앵콜 | `Signature`, `UserWishProject`, `CampaignAskForEncore` | [wish-signature-encore-comingsoon.md](./api-details/wish-signature-encore-comingsoon.md) |
| 인증·심플페이 | `BillkeyVerificationStatus`, `BillkeyManager`, `RewardPasscode`, `WadizSimplePayUseLog` | [misc.md](./api-details/misc.md) |
| 메이커·초대 | `MakerInvitation`, `MakerInvitationCode`, `MakerInvitationBenefit`, `MakerInvitationBenefitPayment`, `CampaignCongratulationHistory` | [maker-admin.md](./api-details/maker-admin.md) |
| 리액션·IP라이선스·기타 | `Reaction`, `ReactionType`, `IPLicense`, `IPLicenseLog`, `IPLicenseTag`, `ProjectPause`, `ProjectPauseHistory` | [iplicense-catalog-additional.md](./api-details/iplicense-catalog-additional.md), [misc.md](./api-details/misc.md) |
| 스토리·번역 | `StoryCopy`, `StoryTranslation` | [story-translate-aireview.md](./api-details/story-translate-aireview.md) |

---

## 5. Redis 계층

### 5-1. `@RedisHash` 엔티티 전수

| 엔티티 클래스 | 키 prefix (Spring Data Redis 자동: `{클래스명}`) | @Id 필드 | TTL | 주요 필드 |
|---|---|---|---|---|
| `OrderSession` | `OrderSession` | `token` (UUID) | **600초 (10분)** | `userId`, `campaignId`, `orderNo`, `secureStateBagKey`, `totalShippingCharge`, `rewards` (List), `countryCode`, `attributes` (donation/apid/dontShowName), `membershipBenefit` |
| `ClosedOrderSession` | `ClosedOrderSession` | `token` (UUID) | **10초** | `orderSessionInfo`, `orderSheetInfo`, `failureType`, `failMessage` |
| `OrderSheet` | `OrderSheet` | `orderNo` (String) | **600초 (10분)** | `title`, `invoice`, `rewardSheet`, `couponKey`, `bill` (fundingAmount/couponDiscountAmount/applyPoint), `recipient` (name/phoneNumber/address/shippingMemo/customsCode), `payType`, `deviceType`, `serviceType`, `condition` |
| `Stock` | `Stock` | `key` (String) | **5초** | `qty` |

> `OrderSession`, `ClosedOrderSession`은 `OrderSessionRedisGatewayImpl`이 함께 관리한다. `OrderSession`·`OrderSheet`은 `OrderSessionKeyValueRepository`/`OrderSheetKeyValueRepository`(`CrudRepository<T, UUID/String>` 확장) 경유.

### 5-2. `StringRedisTemplate` 기반 직접 Redis 접근 (비-`@RedisHash`)

| Gateway 구현체 | Redis 키 패턴 | 용도 | TTL |
|---|---|---|---|
| `OrderPaymentRedisGatewayImpl` | `com.wadiz.api.funding.redis.orderpayment:processing:{tid}` | 결제 중복 처리 방지 락 (`SETNX`) | **5분** |
| `CancelPaymentRedisGatewayImpl` | `payment:waiting` | 결제 취소 가능 시간 확인 (키 존재 여부만 확인) | 외부 배치가 관리 |
| `SimplePayRedisGatewayImpl` | `com.wadiz.api.funding.redis.simplepay:processing:{token}` | 심플페이 진행 중 빌키 매핑 | **5분** |
| `StockKeyValueGatewayImpl` | `{keyPrefix}{rewardId}` 또는 `{keyPrefix}{rewardId}_{rewardOptionId}` | 리워드 재고 증분 카운터 (`INCR`) | **5000ms (5초)** — 타임리프 0 이하일 때 갱신 |

---

## 6. MongoDB 계층

### 6-1. 컬렉션 전수

| `@Document(collection=...)` 이름 | DTO 클래스 | MongoRepository | Gateway 구현체 | 용도 |
|---|---|---|---|---|
| `newsNotificationLog` | `NewsNotificationLogDto` | `NewsNotificationLogMongoRepository` | `NewsNotificationLogGatewayImpl` (`@Async`) | 새소식 알림 발송 이력 |
| `OrderPayMessage` | `OrderPayMessageLogDto` | `OrderPayMessageMongoRepository` | `OrderPayMessageLogGatewayImpl` (`@Async`) | PG 결제 웹훅 메시지 수신 로그 |
| `orderSession` | `OrderSessionLogDto` | `OrderSessionMongoRepository` | `OrderSessionLogGatewayImpl` | 주문 세션 생성 로그 |
| `orderSheet` | `OrderSheetLogDto` | `OrderSheetMongoRepository` | `OrderSheetLogGatewayImpl` | 주문서 생성 로그 |
| `rewardChangeLog` | `RewardChangeLogDto` | `RewardChangeLogMongoRepository` | `RewardChangeLogGatewayImpl` | 리워드 변경 이력 |
| `translationFailureLog` | `TranslationFailureLogDto` | `TranslationFailureLogRepository` | (직접 주입) | 번역 실패 이력 |

### 6-2. 문서 스키마 (필드 이름 수준)

**`newsNotificationLog`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | `@MongoId(FieldType.OBJECT_ID)` |
| `updateId` | Integer | CampaignUpdate PK |
| `tid` | String | 트랜잭션 ID |
| `type` | NotificationType | `EMAIL` / `APP_PUSH` |
| `registered` | LocalDateTime | `@CreatedDate` 자동 생성 |

**`OrderPayMessage`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `payType` | String | `NICE`, `STRIPE`, `ALIPAY` 등 |
| `token` | String | 주문 UUID 문자열 |
| `eventType` | String | SQS 메시지 이벤트 구분 |
| `payload` | `Map<String, String>` | PG 응답 raw 필드 |
| `registered` | LocalDateTime | `@CreatedDate` |

**`orderSession`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `campaignId` | Integer | |
| `userId` | Integer | |
| `token` | String | UUID 문자열 |
| `payload` | String | 세션 JSON raw |
| `registered` | LocalDateTime | `@CreatedDate` |

**`orderSheet`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `oid` | String | orderNo |
| `token` | String | 세션 UUID |
| `payload` | String | 주문서 JSON raw |
| `registered` | LocalDateTime | `@CreatedDate` |

**`rewardChangeLog`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `campaignId` | Integer | |
| `rewardId` | Integer | |
| `rewardName` | String | |
| `changeType` | String | 변경 유형 |
| `beforeData` | String | 변경 전 JSON |
| `afterData` | String | 변경 후 JSON |
| `registerUserId` | Integer | |
| `registered` | LocalDateTime | `@CreatedDate` |

**`translationFailureLog`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `targetType` | TargetType | 번역 대상 유형 |
| `targetId` | Integer | |
| `targetField` | String | 번역 대상 필드명 |
| `translationType` | TranslationType | |
| `languageCode` | String | |
| `command` | String | 번역 요청 raw |
| `resultMessage` | String | 오류 메시지 |
| `registered` | LocalDateTime | `@CreatedDate` |

> TTL Index 및 추가 인덱스: 소스에서 `@Indexed`, `@CompoundIndex` 어노테이션 없음 — MongoDB Atlas 또는 운영 스크립트에서 별도 관리하는 것으로 추정 (확인 불가).

---

## 7. 이벤트/메시징

### 7-1. AWS SQS 리스너

Kafka 없음. PG 결제 웹훅 수신은 AWS SQS FIFO 큐를 사용한다.

| 리스너 클래스 | 큐 이름 | 위치 | 역할 |
|---|---|---|---|
| `OrderPaymentSqsListener` | `${application.aws-sqs.queue-name}` (dev: `pay-webhook-funding-api-dev.fifo`) | `adapter/application` (인프라 모듈 밖) | PG WebHook 메시지 수신 → `orderPayMessageLogGateway.saveLog(...)` (MongoDB) → `OrderPaymentUsecase.pay(...)` |

`deletionPolicy = SqsMessageDeletionPolicy.ON_SUCCESS` — 정상 처리 시에만 메시지 삭제.

### 7-2. Spring ApplicationEvent 발행

`EventDispatcherImpl`이 `ApplicationEventPublisher.publishEvent(event)`를 감싸 도메인에서 이벤트를 발행한다.

### 7-3. Spring `@EventListener` / `@TransactionalEventListener` 핸들러

| 핸들러 클래스 | 이벤트 타입 | 처리 내용 |
|---|---|---|
| `NewsEventHandler` | `CreateNewsEvent`, `ModifyNewsEvent` (`@TransactionalEventListener`), `PostNewsEvent` (`@EventListener`) | 새소식 로그 저장(MySQL), 번역 요청(TranslateClient), 알림 등록 (MySQL) |
| `NewsNotificationEventHandler` | `NewsNotificationEvent` | MongoDB `newsNotificationLog` 비동기 저장 |
| `AnnouncementEventHandler` | 공지 관련 이벤트 4종 | 공지 이력·노출·메뉴 저장 (MySQL) |
| `PaymentCancelLogEventHandler` | 결제 취소 이벤트 2종 (`@EventListener`) | `BackingPaymentCancelLog` 저장 (MySQL) |
| `BrazeNotifyEventHandler` | Braze 알림 이벤트 (`@EventListener`) | `BrazeClient.sendUserTrack(...)` 호출 |
| `MembershipNotifyEventHandler` | 멤버십 혜택 알림 이벤트 | `MembershipApiClient.notifyUseMembershipBenefit(...)` 호출 |
| `ComingSoonApplicantBrazeEventHandler` | ComingSoon 신청·취소 이벤트 2종 | Braze 이벤트 전송 |
| `FollowActivityEventHandler` | 팔로우 활동 이벤트 | `FollowClient.addFollowActivityEvent(...)` 호출 |
| `SignatureTrackingEventHandler` | 서명 이벤트 | `SignatureApiClient` 호출 (외부 서비스, 확인 불가) |
| `StoreOpenEventHandler` | 스토어 오픈 이벤트 | `StoreClient` 또는 내부 처리 (상세 불가) |
| `WishEventHandler` | 찜하기 이벤트 | (상세 불가 — core 내부) |
| `BillkeyEventHandler` | 빌키 이벤트 | (상세 불가) |
| `SimplePayEventHandler` | 심플페이 이벤트 | (상세 불가) |
| `CampaignCongratulationHistoryEventHandler` | 캠페인 달성 축하 이벤트 | `CampaignCongratulationHistoryRepository` 저장 |

> `OrderSheetCreateEvent`는 `OrderSheetRedisGatewayImpl` 내 `save()` 호출 시 발행 가능한 이벤트 객체로 정의되어 있으나, 실제 발행 지점은 `funding-core` UseCase 내부이므로 확인 불가.

---

## 8. 메일 템플릿

`resources/templates/mail/` 아래 Thymeleaf HTML 템플릿 4개:

| 파일명 | 용도 |
|---|---|
| `AchievementRateCongratulationMaker.html` | 달성률 축하 메이커 메일 |
| `PaymentCancelMyRewardsSectionEn.html` | 결제 취소 안내 (영문, 리워드 섹션) |
| `myRewardsSectionEn.html` | 내 리워드 섹션 (영문) |
| `myRewardsSectionKo.html` | 내 리워드 섹션 (한국어) |

> 메일 발송은 `NotificationClient.postMailBatchInfo(...)` / `postMailBatchInfoV3(...)` 경유. 템플릿은 `MailBatch` 페이로드에 HTML string으로 포함되어 전달된다.

---

## 관련 문서

- [`com.wadiz.api.funding.md`](./com.wadiz.api.funding.md) — 레포 개요, 도메인별 API·DB 요약
- [`api-details/payment-flow.md`](./api-details/payment-flow.md) — 결제 승인/취소 상세 SQL
- [`api-details/settlement.md`](./api-details/settlement.md) — ERP 연동 상세
- [`api-details/news-announcement.md`](./api-details/news-announcement.md) — MongoDB newsNotificationLog 상세
- [`api-details/reward.md`](./api-details/reward.md) — rewardChangeLog 상세
- [`api-details/dashboard.md`](./api-details/dashboard.md) — DataPlus 연동 상세
