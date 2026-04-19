# Batch 모듈 상세 스펙

Spring Batch 기반 **24개 Job** (20개 도메인). 별도 `bootstrap/batch` 모듈로 독립 실행 JAR를 생성하며(`BatchBootstrap.main`), `adapter/batch`에 모든 Job/Step/Tasklet이 정의된다.

> **기록 범위**: 이 레포의 Tasklet · Reader/Writer 클래스와 MyBatis Mapper XML에서 직접 관찰 가능한 호출만 기록. UseCase 구현체(`StoryTranslationUseCase`, `LanguageExpansionUseCase`, `MakerClubUseCase`, `AIReviewUseCase`, `TranslationQualityMonitorUseCase` 등)는 외부 jar(`funding-core`) 또는 `core/domain` 내부에 있어 내부 호출 순서·SQL은 확인 불가. Gateway 포트를 경유하는 내부 로직은 **"UseCase 호출 (core 내부)"** 로 표시.
>
> 모든 Job은 `@Scheduled` 없이 **외부 트리거**(Jenkins 등 CI/CD 또는 운영 수동 실행)로 기동된다. `adapter/application`에는 `@Scheduled` 선언이 없으며, 배치 JAR는 `SpringApplication.exit(SpringApplication.run(...))` 패턴으로 실행 후 즉시 종료된다.

---

## BatchConfig — Job Repository 설정

`BatchConfig` (`config/BatchConfig.java`):

- **전용 DataSource**: `batchDataSource` — `application.datasource.batch.*` 프로퍼티로 설정된 별도 MySQL DB (`wadiz_funding_batch`)
- **테이블 프리픽스**: `RWD_BATCH_` — Spring Batch JobRepository 메타데이터 테이블(BATCH_JOB_INSTANCE, BATCH_JOB_EXECUTION 등)을 `RWD_BATCH_` 접두사로 사용
- **격리 수준**: `ISOLATION_READ_COMMITTED`
- **RunIdIncrementer**: 모든 Job에 적용 — 동일 파라미터로 재실행 가능

---

## 카테고리별 Job 목록

| 카테고리 | Job명 | 방식 |
|---|---|---|
| **알림** | `newsNotificationJob` | Reader-Processor-Writer (chunk=500) |
| **알림** | `deliveredNotificationJob` | Reader-Processor-Writer (chunk=1000) |
| **알림** | `firstFundingDeliveredNotificationJob` | Tasklet |
| **알림** | `pendingNotificationJob` | Tasklet |
| **알림** | `pendingStandbyJob` | Tasklet |
| **알림** | `encoreOpenNotificationJob` | Tasklet |
| **알림** | `billkeyVerifyRemindJob` | Reader-Writer (chunk=1000, skip) |
| **알림** | `wishProjectDeadlineNotificationJob` | Tasklet |
| **스토어 알림** | `encoreStoreOpenNotificationJob` | Tasklet |
| **스토어 알림** | `encourageStoreOpenJob` | Tasklet |
| **스토어 알림** | `wishStoreOpenNotificationJob` | Tasklet |
| **번역** | `storyTranslationJob` | Tasklet |
| **번역** | `inProgressStoryTranslationJob` | Tasklet |
| **번역** | `languageExpansionJob` | Tasklet |
| **번역** | `translationQualityMonitorJob` | Tasklet |
| **AI 심의** | `aiReviewPostApprovalRetryJob` | Tasklet |
| **AI 심의** | `aiReviewReleaseJob` | Tasklet |
| **메이커 혜택** | `makerInvitationBenefitJob` | 6-Step (Reader-Processor-Writer 혼합) |
| **메이커 CRM** | `comingSoonDailyReportJob` | Tasklet |
| **정산/요금제** | `packagePlanBatchJob` | Tasklet |
| **정산/요금제** | `pingpongPaymentSignupReminderJob` | Tasklet |
| **운영/인프라** | `safeNumberReleaseJob` | Tasklet |
| **운영/인프라** | `collectionCampaignGradeJob` | Tasklet |
| **운영/인프라** | `migrationOngoingStoryJob` | Tasklet |

---

## 1. 알림 카테고리

### 1-1. `newsNotificationJob`

**설정 파일**: `domain/newsnotification/NewsNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Reader → Processor → Writer (chunk=500)  
Skip: `NewsNotificationSkipException` (`skipLimit = Integer.MAX_VALUE`)  
Listener: `NewsNotificationSkipListener`

#### 관측 가능한 DB/외부호출

**Reader** (`NewsNotificationReader`):
- `newsNotificationGateway.findAllByStatus(PENDING, pages)` — PENDING 상태 알림 건 페이징 조회
- `newsNotificationGateway.updateAllNewsNotification(targets)` — 조회 즉시 상태를 STARTED로 UPDATE (`@Transactional`)

**Processor** (`NewsNotificationProcessor`):
- `newsGateway.getNews(newsId)` — 새소식 단건 조회
- `newsNotificationDenyGateway.getAllNewsNotificationDeny(campaignId)` — 수신거부 목록 조회
- `newsNotificationGateway.notificationSubscriberUserIds(targetTypes, campaignId)` — 구독자 userId 목록 조회
- `userGateway.findAllUserByIdAndUserStatus(subscriberUserIds, UserStatus.NM)` — 활성 유저 필터

**Writer** (`NewsNotificationWriter`):
- `newsNotificationClient.sendNewsNotification(EMAIL|APP_PUSH, news, subscribers, uuid)` — 외부 알림 API 호출
- `newsNotificationGateway.updateNewsNotification(...)` — 발송 결과(status/targetQty/successQty/failQty/skipQty) UPDATE

---

### 1-2. `deliveredNotificationJob`

**설정 파일**: `domain/deliverednotification/DeliveredNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Reader → Processor → Writer (chunk=1000)  
Skip: `Exception.class` (`skipLimit = Integer.MAX_VALUE`), `processorNonTransactional`  
Listener: `DeliveredNotificationJobSkipListener`, `DeliveredNotificationJobLoggingListener`

#### 관측 가능한 DB/외부호출

**Reader** (`DeliveredNotificationReader`):
- `deliveredNotificationQueryGateway.shippingForNotificationSearch(query, pages, sort)` — 전일(`어제 00:00~23:59:59`) 배송완료(`DELIVERED`), 취소 아닌 배송 건 페이징 조회. 정렬: `RegDate ASC`

**Processor** (`DeliveredNotificationProcessor`):
- `globalProjectQueryGateway.findProject(campaignId, language)` — 프로젝트 정보 조회 (30분 캐시)
- `globalProjectRewardQueryGateway.getById(projectId, rewardId, language)` — 리워드 이름 조회 (30분 캐시)
- `carrierGateway.getAllToMap()` — 택배사 코드 맵 조회 (30분 캐시)

**Writer** (`DeliveredNotificationWriter`):
- `deliveredNotificationSendService.notify(shippings)` — 배송완료 알림 발송 (UseCase 호출 — core 내부)

---

### 1-3. `firstFundingDeliveredNotificationJob`

**설정 파일**: `domain/deliverednotification/FirstFundingDeliveredNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`FirstFundingDeliveredNotificationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `deliveredNotificationQueryGateway.shippingForNotificationSearch(query, pages, sort)` — 전일 배송완료 이력 조회 (`checkedRefund=true`, `pages = 0/MAX_VALUE`)
2. `deliveredNotificationQueryGateway.firstFundingDeliveredNotificationSearch(query)` — 배송건별 최초 펀딩 여부 + `FIRST_FUNDING_DELIVERED` 상태 확인
3. `userGateway.findUser(userId)` — 유저 조회
4. `notificationClient.sendBizMessages(req)` — 알림톡 발송 (template no: **3006**)

---

### 1-4. `pendingNotificationJob`

**설정 파일**: `domain/pendingnotification/PendingNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`PendingNotificationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `campaignQueryGateway.campaignWhenHoldToSearch(21)` — 종료 21일 경과 보류(HOLD) 캠페인 목록 조회
2. `pendingNotificationQueryGateway.searchPendingUsers(query)` — 캠페인별 미배송(`PENDING`) + 결제완료(`C10/Z11`) 서포터 userId 조회
3. `userGateway.findAllUserByIdAndUserStatus(ids, NM)` — 활성 유저 필터
4. `notificationClient.sendBizMessages(req)` — 알림톡 발송 (template no: **3009**)

---

### 1-5. `pendingStandbyJob`

**설정 파일**: `domain/pendingstandby/PendingStandbyJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`PendingStandByTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `campaignPendingStandbyGateway.findAll(PendingStandbySearch{dueBeforeDay=3})` — 3일 후 마감 예정이며 승인 대기 중인 캠페인 목록 조회
2. `alimtalkV2Client.sendBizMessage(request)` — 알림톡 발송 (template no: **"3106"**)

---

### 1-6. `encoreOpenNotificationJob`

**설정 파일**: `domain/encoreopennotification/EncoreOpenNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`EncoreOpenNotificationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `encoreOpenNotificationGateway.selectEncoreOpenNotificationTarget(query{atLeastEncoreQty=ENCORE_MINCOUNT})` — 앵콜 신청 최소 기준(`ENCORE_MINCOUNT`) 이상인 메이커 조회
2. 필터: `isNotificationTarget()` 통과 항목만
3. `notificationClient.sendPushAndInbox(req)` — 앱 푸시 + 인박스 발송 (청크 500건, domainCode: `M_RETENTION_REOPEN`)
4. 성공 시 `encoreOpenNotificationGateway.saveEncoreOpenNotification(items)` — 발송 완료 기록 INSERT/UPDATE

---

### 1-7. `billkeyVerifyRemindJob`

**설정 파일**: `domain/billkeyverifyremind/BillkeyVerifyRemindJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Reader → Writer (chunk=1000, Processor 없음)  
Skip: `NotificationApiClientException` (`skipLimit = Integer.MAX_VALUE`)  
Listener: `ChunkListener`, `StepExecutionListener`

#### 관측 가능한 DB/외부호출

**Reader** (`BillkeyVerifyRemindReader`):
- `billkeyQueryGateway.searchBillkeyChangeTarget(searchDateTime, pages)` — MyBatis `BillkeyVerificationStatusMapper.searchBillkeyChangeTarget`:
  ```sql
  SELECT BP.BackingPaymentId, VS.Description, U.MobileNumber, C.WhenClose,
         VS.VerificationType, C.Title
  FROM BillkeyVerificationStatus VS
  JOIN BackingPayment BP ON BP.BackingPaymentId = VS.BackingPaymentId
       AND BP.PayStatus = 'A10' AND BP.BillKey = VS.Billkey
  JOIN Campaign C ON C.CampaignId = BP.CampaignId AND C.WhenClose > NOW()
  JOIN UserProfile U ON U.UserId = BP.UserId
  WHERE VS.Registered < #{오늘자정} AND VS.IsVerified = false
  -- + 페이징
  ```

**Writer** (`BillkeyVerifyRemindWriter`):
- `billkeyVerifyAlimtalkSender.sendAlimtalkMessage("3158", payloads)` — 알림톡 발송 (template no: **"3158"**)

---

### 1-8. `wishProjectDeadlineNotificationJob`

**설정 파일**: `domain/wishes/WishProjectDeadlineNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`WishProjectDeadlineNotificationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet** (cursor-style 루프, 500건씩):
1. `wishQueryGateway.searchDeadlineAlarmSubscriber(query{wishId, pageSize=500})` — 찜하기 마감 3일 전 알림 구독자 조회 (wishId 커서 기반 페이징)
2. `globalProjectQueryGateway.findProject(campaignId, langCode)` — 프로젝트 정보 + 타이틀
3. `fundingQueryGateway.findFundingStatusByCampaignId(campaignId)` — 펀딩 달성률 조회
4. `notificationClient.sendPushAndInbox(req)` — 앱 푸시 + 인박스 발송 (캠페인·언어 그룹별, domainCode: `REWARD_END_REMIND`)

---

## 2. 스토어 알림 카테고리

### 2-1. `encoreStoreOpenNotificationJob`

**설정 파일**: `domain/storeopennotification/EncoreStoreOpenNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`EncoreStoreOpenNotificationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `storeEventGateway.findAllNotificationTarget(PENDING, BIZ_MESSAGE, ENCORED, pages)` — 스토어 오픈 알림 대상 조회 (status=PENDING, type=BIZ_MESSAGE, targetType=ENCORED, 정렬: RegisteredAt/CampaignId ASC)
2. `campaignGateway.getByCampaignId(campaignId)` — 캠페인 정보
3. `storeClient.getStoreProject(campaignId)` — 스토어 프로젝트 정보 (외부 Store API)
4. `campaignAskForEncoreQueryGateway.campaignAskForEncoreSearch(query, pages, sort)` — 앵콜 신청 사용자 목록 조회
5. `userGateway.findAllUserByIdAndUserStatus(ids, NM)` — 활성 유저 필터
6. `alimtalkV2Client.sendBizMessage(req)` — 알림톡 발송 (정책: `STORE_ENCORE_PROJECT_OPEN`, 1000건 청크)
7. `storeEventGateway.updateAllStoreOpenNotification(list)` — 발송 결과 UPDATE

---

### 2-2. `encourageStoreOpenJob`

**설정 파일**: `domain/storeopennotification/EncourageStoreOpenJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`EncourageStoreOpenTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `encourageStoreOpenGateway.findAll(query{dueBeforeDay=3})` — 3일 후 마감 캠페인 중 스토어 오픈 가능 조건 필터 (한국, 기부형 제외, `canStoreOpen()=true`)
2. `alimtalkV2Client.sendBizMessage(req)` — 알림톡 발송 (template no: **"3109"**)
3. `notificationClient.postMailBatchInfo(mailBatch)` — 메일 발송 (template no: **1389**)

---

### 2-3. `wishStoreOpenNotificationJob`

**설정 파일**: `domain/storeopennotification/WishStoreOpenNotificationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`WishStoreOpenNotificationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `storeEventGateway.findAllNotificationTarget(PENDING, PUSH, WISHED, pages)` — status=PENDING, type=PUSH, targetType=WISHED 조회
2. `campaignGateway.getByCampaignId(campaignId)` — 캠페인 정보
3. `storeClient.getStoreProject(campaignId)` — 스토어 프로젝트 정보 (외부 Store API)
4. `wishGateway.findAllByWishesByProject(FUNDING, campaignId)` — 찜한 사용자 목록 조회
5. `userGateway.findAllUserByIdAndUserStatus(ids, NM)` — 활성 유저 필터
6. `notificationClient.sendPush(req)` — 앱 푸시 발송 (500건 청크, serviceCode: FUNDING)
7. `storeEventGateway.updateAllStoreOpenNotification(list)` — 결과 UPDATE

---

## 3. 번역 카테고리

### 3-1. `storyTranslationJob`

**설정 파일**: `domain/storytranslation/StoryTranslationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`StoryTranslationTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `storyTranslationUseCase.getStoryTranslationTargets()` — 번역 대상 목록 조회 (UseCase 호출 — core 내부). 100건 초과 시 100건으로 제한
2. `storyTranslationUseCase.prepareStoryTranslation(campaignId, makerWriteLanguage, languageCode)` — 번역 데이터 준비 및 트랜잭션 커밋 (UseCase 호출 — core 내부)
3. `storyTranslationUseCase.executeStoryTranslationRequests(campaignId, makerWriteLanguage, languageCode)` — 번역 API 요청 실행 (UseCase 호출 — core 내부)
4. `translationStatisticsSaver.saveStatistics()` — 번역 통계 저장

**비고**: 2단계 처리 (Step1: 준비/커밋, Step2: 번역 요청). 개별 캠페인 실패 시 다음 캠페인 계속 진행.

---

### 3-2. `inProgressStoryTranslationJob`

**설정 파일**: `domain/storytranslation/InProgressStoryTranslationJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`InProgressStoryTranslationTasklet`)

#### 관측 가능한 DB/외부호출

`storyTranslationJob`과 동일한 2단계 패턴이나, 대상 조회 메서드만 다름:
- `storyTranslationUseCase.getInProgressStoryTranslationTargets()` — **진행 중** 프로젝트 번역 대상 조회 (UseCase 호출 — core 내부). 건수 상한 없음 (100건 제한 없음)

---

### 3-3. `languageExpansionJob`

**설정 파일**: `domain/languageexpansion/LanguageExpansionJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`LanguageExpansionTasklet`)

**대상 언어**: `en`, `ja`, `zh` / **배치 크기**: 1건씩

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `languageExpansionUseCase.findCampaignIdsWithoutLanguage()` — 번역 미적용 캠페인 ID 목록 조회 (UseCase 호출 — core 내부)
2. `languageExpansionUseCase.translateAndSaveCampaignLanguagesBatch(batchCampaignIds, TARGET_LANGUAGES)` — 번역 실행 및 저장 (UseCase 호출 — core 내부, 1건씩 개별 파티션)

---

### 3-4. `translationQualityMonitorJob`

**설정 파일**: `domain/translationqualitymonitor/TranslationQualityMonitorJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`TranslationQualityMonitorTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `useCase.runQualityCheck()` — 전날 최종승인 기준 번역 품질 검사 (UseCase 호출 — core 내부). `QualityCheckReport` 반환
2. 이슈 존재 시: `gateway.sendSlackNotification(message)` — Slack Webhook 알림 발송

---

## 4. AI 심의 카테고리

### 4-1. `aiReviewPostApprovalRetryJob`

**설정 파일**: `domain/aireviewpostapprovalretry/AIReviewPostApprovalRetryJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`AIReviewPostApprovalRetryTasklet`)

#### 관측 가능한 DB/외부호출

**Reader** (Tasklet 내):
- `aiReviewMapper.getPostApprovalSRList()` — MyBatis `AIReviewMapper.xml`:
  ```sql
  SELECT t1.AIReviewManagementId, t1.CampaignId, t1.LanguageCode, t1.RegisteredBy
  FROM AIReviewManagement t1
  INNER JOIN (SELECT CampaignId, MAX(AIReviewManagementId) AS LatestId
              FROM AIReviewManagement
              WHERE AIReviewTime = 'POST_APPROVAL'
              GROUP BY CampaignId) t2
             ON t1.AIReviewManagementId = t2.LatestId
  WHERE t1.AIReviewStatus = 'SR'
    AND t1.UpdatedAt >= DATE_SUB(NOW(), INTERVAL 30 MINUTE)
  ```
  → 30분 이내에 `SR`(심의 요청) 상태인 POST_APPROVAL 건 조회

**처리**:
- `aiReviewUseCase.requestPostApprovalAIReview(campaignId, registeredBy)` — AI 심의 재요청 (UseCase 호출 — core 내부). 개별 실패 시 로그 후 계속

---

### 4-2. `aiReviewReleaseJob`

**설정 파일**: `domain/aireviewrelease/AIReviewReleaseJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`AIReviewReleaseTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `aiReviewQueryGateway.recentAIReviewResponse()` — MyBatis `AIReviewMapper.xml` `getRecentAIReviewResponse`:
   ```sql
   SELECT t1.AIReviewManagementId, t1.AiReviewRequestKey, t1.CampaignId,
          t1.AIReviewTime, DATE_FORMAT(t1.RegisteredAt, '%Y-%m-%d %H:%i') AS RegisteredAt,
          t1.UpdatedAt, t1.LanguageCode
   FROM AIReviewManagement t1
   INNER JOIN (SELECT CampaignId, MAX(UpdatedAt) AS LatestUpdatedAt
               FROM AIReviewManagement
               WHERE AiReviewStatus = 'SA'
               GROUP BY CampaignId) t2
              ON t1.CampaignId = t2.CampaignId AND t1.UpdatedAt = t2.LatestUpdatedAt
   ```
   → 캠페인별 최신 `SA`(승인완료) 상태 레코드 조회

2. `aiReviewQueryGateway.resetAIReviewStatus(list)` — AI 심의 상태 초기화 UPDATE (관련 테이블: `AIReviewManagement`)

---

## 5. 메이커 혜택 카테고리

### 5-1. `makerInvitationBenefitJob`

**설정 파일**: `domain/makerinvitationbenefit/MakerInvitationBenefitJobConfig.java`

**트리거**: 외부 실행. Job Parameter: `target.date` (ISO 날짜, 필수)

**Job 흐름**: **6-Step 순차 체인**

```
selectTargetStep (chunk=500)
  → paymentPointStep (chunk=500)
  → paymentBizMoneyStep (chunk=500)
  → paymentMakerNewsPushCreditStep (chunk=500)
  → sendBenefitPaidNotificationStep (chunk=500)
  → updateBenefitPaidResultStep (chunk=500)
```

StepExecutionContext 공유: `ExecutionContextPromotionListener` — `PAID_BENEFIT_ID` 키 전달

#### 관측 가능한 DB/외부호출

**Step 1 — selectTargetStep**:
- Reader (`BenefitTargetItemReader`):
  - `campaignQueryGateway.findAllCampaignIdByWhenOpen(start, end)` — `target.date` 당일 오픈한 캠페인 ID 조회 (`OPENED_PROJECT` 사유)
  - `comingSoonQueryGateway.findAllCampaignIdByHasBeenOpenedTrueAndPostedAt(start, end)` — 당일 오픈예정 등록한 캠페인 ID 조회 (`POSTED_COMING_SOON` 사유)
  - `makerInvitationGateway.findAllByCampaignIdInAndStatus(ids, REGISTERED_CODE)` — 초대 등록 상태 MakerInvitation 조회
- Writer (`BenefitTargetItemWriter`): `makerInvitationBenefitGateway.create(benefits)` — 혜택 레코드 생성 INSERT

**Step 2 — paymentPointStep**:
- Reader (`PointPaymentItemReader → AbstractBenefitPaymentItemReader`): `makerInvitationBenefitPaymentGateway` 경유, BenefitType=`POINT` 지급 대상 조회
- Writer (`PointPaymentItemWriter`): `pointGateway.issue(targetId, "MAKER_INVITATION_BENEFIT")` — 포인트 지급 외부 호출. 결과 transactionId를 `MakerInvitationBenefitPayment`에 기록

**Step 3 — paymentBizMoneyStep**:
- Reader (`BizMoneyPaymentItemReader`): BenefitType=`BIZ_MONEY` 지급 대상 조회
- Writer (`BizMoneyPaymentItemWriter`): 비즈머니 지급 (UseCase 호출 — core 내부)

**Step 4 — paymentMakerNewsPushCreditStep**:
- Reader (`MakerNewsPushCreditPaymentItemReader`): BenefitType=`MAKER_NEWS_PUSH_CREDIT` 지급 대상 조회
- Writer (`MakerNewsPushCreditPaymentItemWriter`): 메이커 새소식 푸시 크레딧 지급 (UseCase 호출 — core 내부)

**Step 5 — sendBenefitPaidNotificationStep**:
- Reader (`BenefitPaidNotificationItemReader`): 지급 완료된 혜택 조회
- Processor (`BenefitPaidNotificationItemProcessor`): 알림톡 페이로드 생성
- Writer (`BenefitPaidNotificationItemWriter`): 알림톡 발송 (외부 알림 API)

**Step 6 — updateBenefitPaidResultStep**:
- Reader (`BenefitPaidResultItemReader`): 완료 처리 대상 MakerInvitation 조회
- Writer (`BenefitPaidResultItemWriter`): `MakerInvitation` 지급완료 상태 UPDATE

---

## 6. 메이커 CRM 카테고리

### 6-1. `comingSoonDailyReportJob`

**설정 파일**: `domain/makerdashboardcrm/ComingSoonDailyReportJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`ComingSoonDailyReportTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `comingSoonQueryGateway.getComingSoonDailyReportData()` — 어제 기준 오픈예정 데일리 리포트 데이터 조회 (`ComingSoonDailyReportData`)
2. `makerUserGateway.getLanguageMap(userIds)` — 메이커 언어 설정 조회
3. `globalProjectQueryGateway.findProject(campaignId, languageCode)` — 프로젝트 타이틀 조회
4. `messageBundleUtil.getMessage(...)` — 다국어 메시지 생성
5. `notificationClient.sendPushAndInbox(req)` — 앱 푸시 + 인박스 발송 (domainCode: `M_DAILYREPORT_COMINGSOON`, 500건 청크, 중복 userId는 개별 발송)

---

## 7. 정산/요금제 카테고리

### 7-1. `packagePlanBatchJob`

**설정 파일**: `domain/studio/pricing/PackagePlanBatchJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`PackagePlanBatchTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `studioPricingGateway.findSuccessfulProjectsClosedYesterday()` — 전날 종료 + 성공한 프로젝트 ID 목록 조회
2. `studioPricingUseCase.updateBulkPackagePlans(userId=0, projectNos)` — 요금제 일괄 판단 및 저장 (UseCase 호출 — core 내부). `PackagePlanType(STARTER|STANDARD)` 맵 반환

---

### 7-2. `pingpongPaymentSignupReminderJob`

**설정 파일**: `domain/pingpongpaymentreminder/PingpongPaymentSignupReminderJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`PingpongPaymentSignupReminderTasklet`)

**대상**: 해외(비한국) 메이커 중 Pingpong Payment 미가입 또는 제출 후 미등록 대상

#### 관측 가능한 DB/외부호출

**Reader** (Tasklet 내 — MyBatis `PingpongPaymentReminderMapper.xml`, 4가지 조건):

| 메서드 | SQL 조건 |
|---|---|
| `selectPingpongPaymentSignupReminderTargets` | `CI.CountryCode != 'KR' AND CI.PingPongBizId IS NULL AND C.IsSubmitted=FALSE AND DATEDIFF(NOW(), C.WhenCreated) = 7` |
| `selectPingpongPaymentSubmitted7DayTargets` | `CI.PingPongBizId IS NULL AND IsSubmitted=TRUE AND DATEDIFF(NOW(), WhenSubmitted) = 7` |
| `selectPingpongPaymentSubmitted10DayTargets` | `CI.PingPongBizId IS NULL AND IsSubmitted=TRUE AND DATEDIFF(NOW(), WhenSubmitted) = 10` |
| `selectPingpongPaymentSubmitted15DayTargets` | `CI.PingPongBizId IS NULL AND IsSubmitted=TRUE AND DATEDIFF(NOW(), WhenSubmitted) = 15` |

공통 JOIN: `Campaign`, `UserProfile`, `CampaignContractInfo`

**발송**:
- `makerUserGateway.getLanguageMap(userIds)` — 언어 설정 조회
- `notificationClient.postMailBatchInfoV3(mailBatch)` — 메일 발송 (언어별 그룹, 1000건 청크). template no: **1485/1486/1487/1488**

---

## 8. 운영/인프라 카테고리

### 8-1. `safeNumberReleaseJob`

**설정 파일**: `domain/safenumberrelease/SafeNumberReleaseJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`SafeNumberReleaseTasklet`)

**핵심 로직**: 정산 시스템 타입(`WADIZ_ADM` vs `ERP`)에 따라 안심번호 해제 기준이 다름

#### 관측 가능한 DB/외부호출

**Tasklet**:
1. `safeNumberQueryGateway.getReleaseSafeNumber()` — 안심번호 해제 대상 캠페인 조회
2. `safeNumberQueryGateway.getSettlementSystemByCampaignId(ids)` — 정산 시스템 타입 조회 (`SettlementSystem.SystemType`)
3. **WADIZ_ADM 경로**: `settlementClient.checkFinalPaidAt(request{resultType=FINAL})` — 외부 Settlement API 최종정산 완료일 확인 (100건 페이징)
4. **ERP 경로**: `safeNumberQueryGateway.getAllRefundableEndedAt(ids)` — 하자반환종료일 조회
5. 최종정산 7일 경과 시:
   - `safeNumberQueryGateway.safeNumberStatusUpDateByCondition(RELEASE, campaignId)` — 안심번호 상태 UPDATE
   - `safeNumberQueryGateway.releaseSafeNumberByCampaignId(campaignId)` — 안심번호 해제 처리
   - `safeNumberQueryGateway.getISNotNullSafeNumberCountById(campaignId)` == 0 이면 `safeNumberQueryGateway.deleteSafeNumberById(campaignId)` — 레코드 삭제
6. 별도로 `safeNumberQueryGateway.getDeleteSafeNumber()` — 삭제 대상 조회 후 동일 패턴 처리

---

### 8-2. `collectionCampaignGradeJob`

**설정 파일**: `domain/collectioncampaigngrade/CollectionCampaignGradeJobConfig.java`

**트리거**: 외부 실행 (cron 없음)

**Job 흐름**: Tasklet (`CollectionCampaignGradeTasklet`)

#### 관측 가능한 DB/외부호출

**Tasklet**:
- `makerClubUseCase.getCollectionCampaignGrade()` — 컬렉션 캠페인 등급 산정 및 업데이트 (UseCase 호출 — core 내부)

---

### 8-3. `migrationOngoingStoryJob`

**설정 파일**: `domain/migration/MigrationOngoingStoryJobConfig.java`

**트리거**: 외부 실행 (일회성 마이그레이션용)

**Job 흐름**: Tasklet (`MigrationOngoingStoryTasklet`)

**목적**: 영어 번역 완료 프로젝트 중 `OngoingStoryManagement`에 영어 데이터 없는 건을 복사. 최대 500건 처리.

#### 관측 가능한 DB/외부호출

**Reader** (Tasklet 내):
- `migrationOngoingStoryMapper.findMigrationTargetCampaignIds()` — MyBatis `MigrationOngoingStoryMapper.xml`:
  ```sql
  SELECT C.CampaignId
  FROM Campaign C
  JOIN CampaignLanguage CL ON CL.CampaignId = C.CampaignId
  WHERE C.IsDel = FALSE
    AND C.MakerStudioLanguageCode <> 'en'
    AND C.IsSubmitted = TRUE
    AND C.IsStandingBy = TRUE
    AND (C.WhenClose IS NULL OR C.WhenClose >= NOW())
    AND CL.LanguageCode = 'en'
    AND NOT EXISTS (
      SELECT 1 FROM OngoingStoryManagement OSM
      WHERE OSM.CampaignId = C.CampaignId AND OSM.LanguageCode = 'en'
    )
  ```
  → 영어 CampaignLanguage 존재하지만 OngoingStoryManagement 영어 레코드 없는 진행중 프로젝트

**Writer** (Tasklet 내):
- `storyCopyGateway.copyStoryForLanguage(campaignId, LanguageCode.en, userId=0)` — `CampaignLanguage` 영어 데이터를 `OngoingStoryManagement`로 복사 (UseCase 호출 — core 내부)

---

## 9. 참고 — Job 요약 테이블

| Job명 | 방식 | 목적 |
|---|---|---|
| `newsNotificationJob` | Reader-Processor-Writer (chunk=500) | PENDING 상태 새소식 알림 발송 (이메일/앱 푸시) |
| `deliveredNotificationJob` | Reader-Processor-Writer (chunk=1000) | 전일 배송완료 건 배송완료 알림 발송 |
| `firstFundingDeliveredNotificationJob` | Tasklet | 최초 펀딩 배송완료 서포터 알림톡 발송 (template 3006) |
| `pendingNotificationJob` | Tasklet | 종료 21일 경과 HOLD 프로젝트 배송미완료 서포터 알림 (template 3009) |
| `pendingStandbyJob` | Tasklet | 3일 내 마감 승인대기 캠페인 메이커 알림톡 (template 3106) |
| `encoreOpenNotificationJob` | Tasklet | 앵콜 신청 기준 초과 메이커 앱 푸시+인박스 발송 |
| `billkeyVerifyRemindJob` | Reader-Writer (chunk=1000) | 빌키 검증 실패/만료 서포터 결제수단 확인 알림톡 (template 3158) |
| `wishProjectDeadlineNotificationJob` | Tasklet | 찜하기 프로젝트 마감 3일 전 서포터 앱 푸시+인박스 |
| `encoreStoreOpenNotificationJob` | Tasklet | 앵콜 신청자에게 스토어 오픈 알림톡 |
| `encourageStoreOpenJob` | Tasklet | 3일 내 마감 한국 메이커 스토어 오픈 권유 알림톡+메일 |
| `wishStoreOpenNotificationJob` | Tasklet | 찜한 프로젝트 스토어 입점 시 서포터 앱 푸시 |
| `storyTranslationJob` | Tasklet | 신규 프로젝트 스토리 다국어 번역 요청 (최대 100건) |
| `inProgressStoryTranslationJob` | Tasklet | 진행중 프로젝트 스토리 다국어 번역 요청 |
| `languageExpansionJob` | Tasklet | 번역 미적용 캠페인 다국어(en/ja/zh) 확장 (1건씩) |
| `translationQualityMonitorJob` | Tasklet | 전날 최종승인 번역 품질 검사, 이슈 시 Slack 알림 |
| `aiReviewPostApprovalRetryJob` | Tasklet | 30분 내 SR 상태 POST_APPROVAL AI 심의 재요청 |
| `aiReviewReleaseJob` | Tasklet | SA 상태 최신 AI 심의 결과 초기화 |
| `makerInvitationBenefitJob` | 6-Step (chunk=500) | 메이커 초대 혜택(포인트/비즈머니/크레딧) 지급 + 알림 |
| `comingSoonDailyReportJob` | Tasklet | 오픈예정 메이커 데일리 리포트 앱 푸시+인박스 |
| `packagePlanBatchJob` | Tasklet | 전날 종료 성공 프로젝트 요금제(STARTER/STANDARD) 일괄 판단 |
| `pingpongPaymentSignupReminderJob` | Tasklet | 해외 메이커 Pingpong Payment 미가입/제출 후 미등록 메일 알림 (7/10/15일 경과) |
| `safeNumberReleaseJob` | Tasklet | 최종정산 7일 경과 캠페인 안심번호 해제 및 삭제 |
| `collectionCampaignGradeJob` | Tasklet | 컬렉션 캠페인 등급 산정 및 업데이트 |
| `migrationOngoingStoryJob` | Tasklet | 영어 번역 완료 진행중 프로젝트를 OngoingStoryManagement로 일회성 마이그레이션 |
