# Flow: 펀딩(리워드) 프로젝트 개설

> 메이커가 신규 리워드 펀딩 프로젝트를 만드는 흐름. `/studio/reward/registration` 진입 → 인트로 통과 → 7개 섹션 작성 → 메이커 제출 → funding-api 최종 승인까지의 다단계 체인.

## 기록 범위

- **읽은 파일**:
  - `wadiz-frontend/docs/wadiz-frontend/api-details/apps-maker-studio.md:147-198` (FE → BE 매핑)
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/controller/RewardMakerStudioApiController.java:72-113`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/controller/RewardMakerStudioSectionApiController.java:104-191`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/controller/RewardMakerStudioFileController.java:39-44`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/controller/RewardMakerStudioSubmitApiController.java:40-50`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/service/RewardMakerStudioService.java:242-303` (`setUp`/`saveDefaultSetting`)
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/validator/RewardMakerStudioSubmitValidator.java:66-157`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/validator/RewardMakerStudioSetUpValidator.java`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/model/constant/SectionStatus.java`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/studio/model/request/RequirementRequest.java:75-163`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/adapter/external/fundingapi/MakerInvitationGateway.java`
  - `com.wadiz.web/src/main/resources/sqls/reward/campaign/campaign-setup-mapper.xml`
  - `com.wadiz.web/src/main/resources/sqls/reward/studio/maker-studio-mapper.xml`
  - `com.wadiz.web/src/main/resources/sqls/reward/studio/maker-studio-section-mapper.xml`
  - `com.wadiz.web/src/main/resources/sqls/reward/studio/maker-studio-section-language-mapper.xml`
  - `com.wadiz.web/src/main/resources/sqls/reward/studio/campaign-language-setting-mapper.xml`
  - `com.wadiz.web/src/main/resources/sqls/reward/comingsoon/comingsoon-mapper.xml:77-82`
  - `com.wadiz.web/src/main/resources/sqls/reward/settlement/settlement-mapper.xml:11-14`
  - `com.wadiz.web/src/main/resources/sqls/reward/maker/maker-mapper.xml:48-61`
  - `com.wadiz.web/src/main/resources/sqls/reward/campaign/campaign-mapper.xml:84-94, 180-194`
  - `com.wadiz.web/src/main/resources/sqls/reward/screening/screening-requirement-mapper.xml:289-301`
  - `com.wadiz.web/src/main/resources/sqls/reward/riskpolicy/risk-policy-mapper.xml:49-71`
  - `com.wadiz.web/src/main/resources/sqls/reward/packageplan/packageplan-mapper.xml:61-84`
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/makerinvitation/MakerInvitationController.java:44-53`
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/aireview/{AIReviewController,AIReviewInternalController}.java`
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/translate/InternalTranslateController.java`
  - `com.wadiz.api.funding/core/domain/src/main/java/com/wadiz/api/funding/domain/{makerinvitation,aireview}/...`
  - `docs/com.wadiz.api.funding/api-details/campaign-admin.md:309-428` (Submit Approval 단계)
- **외부 경계**:
  - `com.wadiz.funding.core:funding-core` jar 내 UseCase 구현 (예: `CampaignSubmitUseCase`)
  - 외부 AI 심사 서버 (`AIReviewClient`) — 동기 등록 후 비동기 콜백
  - 외부 번역 서버 (AI/Image) — 비동기 콜백
  - AWS S3 (이미지 업로드 — `RewardMakerStudioFileController` → 업로더)
  - 카카오 알림톡(`AlimtalkV2Client`) / Slack / 이메일(`NotificationClient`) — 알림 발송
  - `MakerInvitationBenefitJobConfig` 배치 잡 — 초대코드 혜택 지급

---

## 🔑 핵심 관찰 — 두 BE 가 분담

| 서버 | 담당 | 경로 prefix |
|---|---|---|
| **`com.wadiz.web`** (레거시) | 메이커 입력 저장 / 섹션 status 관리 / 메이커 제출 | `/web/reward/api/*`, `/web/apip/funding/*` |
| **`com.wadiz.api.funding`** (신규) | 최종 승인 · 심사 · 정산 · 약정 · 알림 / 가격 결정 / 초대코드 / AI리뷰 / 번역 | `/api/studio/*`, `/api/internal/*`, `/api/v1/*` |

`POST /web/reward/api/studios/campaigns/{id}/submit` 자체는 본문이 거의 비어 있음(`isAuthenticationRequired` 한 필드뿐). **데이터 입력은 STEP 1~7 동안 누적**되고, **/submit** 은 단지 funding-api 의 `POST /api/studio/submit/{projectNo}/approval` 을 트리거하는 메타 호출.

---

## 1. Client Trigger (FE) — `wadiz-frontend / studio/funding`

- **앱**: `studio/funding` (Vite SPA, package `wadiz-maker-studio`, port 3000, host `studio.wadiz.kr`)
- **라우트**: `/studio/reward/registration` → `Registration` → 이후 `/studio/reward/{campaignID}` 의 중첩 페이지들
- **fetch 래퍼**: `studio-services` (`@wadiz/services` alias) — `fetchWebAPI`, `fetchRewardAPI`, `fetchFundingAPI`, `fetchFundingStudioAPI`, `fetchPlatformAPI`
- **호출 API 시퀀스** (등록 위저드 순):
  1. `GET /web/account/isLoggedIn`, `GET /web/waccount/ajaxMyInfo`
  2. `GET /web/reward/api/categories`, `GET /web/reward/api/country`, `GET /web/reward/api/bank-codes`
  3. **`POST /web/reward/api/studios`** ← 캠페인 row 발급
  4. `POST /web/reward/api/studios/campaigns/{id}/pass-intro`
  5. `POST /web/reward/api/studios/campaigns/{id}/sections/{requirement|risk-policy|maker-info|contract-info|plan}` (반복 호출, 임시저장↔완료)
  6. `POST /web/reward/api/studios/campaigns/{id}/images` (multipart)
  7. `GET/POST /web/apip/funding/studio/{id}/pricing` (가격 결정 — funding-api 로 프록시)
  8. `POST /web/reward/api/studios/campaigns/{id}/submit`

> wadiz-android / wadiz-ios 는 펀딩 개설 화면을 제공하지 않음. 메이커 도구는 웹 SPA 전용.

---

## 2. Hub — `com.wadiz.web` (메이커 스튜디오 BE)

`@RequiredLogin` + `@RequiredAnyRole({WADIZ_ADMIN, CAMPAIGN_OWNER})` 클래스 레벨. 각 섹션마다 `PermissionChecker.getPermissionType(campaignId, sectionType)` 추가 검증.

### 2.1 `POST /web/reward/api/studios` ⭐ — 캠페인 row 발급

**Controller**: `RewardMakerStudioApiController.java:103-113`

**Request**: `RewardMakerStudioSetUpRequest`

| 필드 | 타입 | 필수 | 의미 |
|---|---|:--:|---|
| `corpType` | enum | 권장 | 개인 IV / 개인사업자 IB / 법인 CB |
| `categoryId` | Integer | ✅ | 카테고리 ID |

**Service**: `RewardMakerStudioService.setUp(userId, request)` (`RewardMakerStudioService.java:242-277`)

처리 순서 (`@Transactional`):
1. `campaignInternalAdapter.setUp(...)` → `CampaignSetUpRepository.insert` → **`Campaign` INSERT** → `CampaignId` auto-increment
2. `campaignSettlementAdapter.setUp(...)` → `RewardSettlementRate` INSERT (기본 수수료 row)
3. `refundPolicyAdapter.create(new RefundPolicy(campaignId))` → `CampaignRewardDelay` 빈 row UPSERT
4. `rewardMakerStudioRepository.insert` → **`RewardMakerStudio`** INSERT
5. `rewardMakerStudioSectionRepository.insert(sections)` → **`RewardMakerStudioSection` 7건** 배치 INSERT (`BEFORE_WRITING`)
6. `saveDefaultSetting(...)` (`RewardMakerStudioService.java:283-303`):
   - 위험요인/메이커정보 임시저장 (각 섹션 status `BEFORE_WRITING` 유지)
   - `Campaign.HostName` 을 세션의 nickname 으로 UPDATE
   - `comingSoonAdapter.save(ComingSoon{status=APPLY})` → `RewardComingSoon` UPSERT

응답: `RewardMakerStudio { campaignId, sections:[…], isPassedIntro:false }`.

### 2.2 `POST /studios/campaigns/{id}/pass-intro` — 인트로 통과

**Controller**: `RewardMakerStudioApiController.java:72-84`

**Request**: `RewardMakerStudioIntroRequest`

| 필드 | 타입 | 필수 | 의미 |
|---|---|:--:|---|
| `categoryId` | String | ✅ | 카테고리 ID |
| `isAdultContent` | Boolean | ✅ | 성인 콘텐츠 |
| `invitationCode` | String | ❌ | 초대코드 (있으면 funding-api `POST /api/maker-invitations`) |
| `makerCountry` | enum | ❌ | 기본 KR |
| `makerLanguage` | enum | ❌ | 기본 ko (→ `MakerStudioLanguageCode`) |
| `corpType` | enum | (KR 필수) | IV/IB/CB |
| `businessNumber` | String | (KR 필수) | 사업자번호 |

**Service** (`RewardMakerStudioService.passIntro`, `:305-` 부근):
- `RewardMakerStudio.IsPassedIntro=true` UPDATE
- `CampaignCategoryMapping` DELETE → INSERT (`IsPrime=true, OrderNo=1`)
- `CampaignCategoryMappingHistory` INSERT
- `Campaign.{IsAdultContent, MakerStudioLanguageCode, CorpType}` UPDATE
- `CampaignContractInfo` UPSERT (`CountryCode`, `BusinessNumber`)
- `CampaignLanguageSetting` UPSERT (`IsMain=1, IsAutoTranslate=0`)
- `RewardMakerStudioSectionLanguage` 배치 INSERT (`STORY`)

### 2.3 섹션 저장 (`POST /studios/campaigns/{id}/sections/*`)

**Controller**: `RewardMakerStudioSectionApiController.java`

| 섹션 | 라인 | Request DTO 핵심 필드 | DB 작업 |
|---|---|---|---|
| `requirement` | 104-117 | `targetAmount`(`@Min(500_000)@Max(1_000_000_000)`), `screeningRewardItems[]`, `campaignBizModel`, `classification`, `preOrderCondition`, `campaignFeature`, `categoryId`, `corpType`, `businessNumber`(`@Size(max=20)`), `invoiceRecipient`(`@Email`), `representatives[]`(mobile `@Pattern("[0-9]{10,11}")`), `isTemporary`(`@NotNull`) | `Campaign.{BizModel,Classification,CopiedBy,TargetAmount,CustValueCode,CorpType,IsAdultContent}` UPDATE, `ScreeningRewardItem` 다건 INSERT, `CampaignContractInfo` UPSERT (사업자 검증 결과) |
| `risk-policy` | 120-129 | 위험요인 텍스트, 환불정책 텍스트, `expectedDelayDays`, `noRefundCase` | `CampaignRewardDelay`(UPSERT) + `CampaignRewardDelayLanguage`(UPSERT) |
| `maker-info` | 139-148 | `makerName`, `globalMakerName`, `profileImage.photoId`, `contactEmail`, `websiteAUrl/BUrl`, `facebookUrl/instagramUrl/twitterUrl`, `makerContactJson` | `Campaign.{HostName, GlobalMakerName, PhotoIdHost, HostEmail, WebsiteA/B, SocialUrlFb/Ig/TW, MakerContactProperty}` UPDATE |
| `contract-info` | 170-178 | 정산 계좌(은행코드, 계좌번호, 예금주), 사업자 정보 보강 | `CampaignContractInfo` UPSERT |
| `plan` | 181-191 | `packagePlanType`(`'STARTER'`/`'STANDARD'` 만 제출 가능) | `CampaignPackagePlan` UPSERT + `CampaignPackagePlanHistory` INSERT |

각 섹션 저장 마지막에 공통:
```sql
UPDATE RewardMakerStudioSection
   SET Status = ?, Updated = NOW()
 WHERE CampaignId = ? AND Section = ?
```
저장 시 status 는 `SectionStatus.getSaveNextStatus(isCompleted)` 가 결정 → `WRITING` 또는 `COMPLETED_WRITING`.

### 2.4 `POST /studios/campaigns/{id}/images` — 이미지 업로드

**Controller**: `RewardMakerStudioFileController.java:39-44`. multipart `file` 받아 S3 업로드 + `PhotoCommon` row 메타 INSERT, `{ fileId, url }` 반환. 메이커가 다른 섹션에서 이 `fileId` 를 사용.

### 2.5 `POST /studios/campaigns/{id}/submit` — 메이커 제출

**Controller**: `RewardMakerStudioSubmitApiController.java:40-50`

**Request**: `RewardMakerStudioSubmitRequest`

| 필드 | 타입 | 필수 | 의미 |
|---|---|:--:|---|
| `isAuthenticationRequired` | Boolean | ❌ | 본인인증 필수 여부 |

**Service**: `RewardMakerStudioSubmitService.submit()`
1. `RewardMakerStudioSubmitValidator.validate(userId, campaignId, request)` (자세한 검증 규칙 § 5)
2. **`MyFundingGateway.postSubmitApproval(campaignId)`** ← funding-api 호출
3. 성공 시 `RewardMakerStudio` 최신 상태 반환

이 단계에서 com.wadiz.web 자체의 큰 DB 쓰기는 거의 없음 — 진짜 변경은 funding-api 가 함.

---

## 3. Backend Service API — `com.wadiz.api.funding`

### 3.1 `POST /api/studio/submit/{projectNo}/approval` — 제출 + 최종 승인

상세는 [`docs/com.wadiz.api.funding/api-details/campaign-admin.md:309-428`](../com.wadiz.api.funding/api-details/campaign-admin.md). 요약하면:

| 단계 | 테이블 | 작업 |
|---|---|---|
| 제출 플래그 | `Campaign` | `IsSubmitted=TRUE, SubmittedUserId, WhenSubmitted=NOW()`, (조건부) `IsStandingBy=TRUE` |
| 오픈예약 적용 | `CampaignAutoOpen` 조회 → `Campaign.WhenOpen` UPDATE | (오픈예약이 있을 때만) |
| 심사 UPSERT | `CampaignScreening` | `ScrType='S'/'D'` 2건 UPSERT |
| 심사 로그 | `CampaignScreeningLog` | 2건 INSERT |
| 정산 시스템 | `SettlementSystem` | UPSERT (`SystemType`) |
| **기본 서비스 수수료** | `RewardSettlementAdditionalCost` | INSERT (`Type='BASIC_SERVICE_FEE', CostAmount=99000`) |
| 정산 비율 확정 | `RewardSettlementRate` | `Status` 를 `A10/A20` → `A30` UPDATE |
| 약정 3건 | `CampaignAgreement` | POA / JRPOA / JGA INSERT |
| 약정 결의 | `CampaignAgreeConclusion` | UPSERT |
| 커밍순 STANDBY | `RewardComingSoon` | `Status='STANDBY'` UPDATE + `StatusLog` INSERT |
| 메이커 알림 | (외부) | `AlimtalkV2Client.sendBizMessage`, `NotificationClient.postMailBatchInfoV3`, Slack |

> 어떤 SQL 이 단일 호출에서 실제 실행되는지의 정확한 조합은 funding-core jar 내 `CampaignSubmitUseCase` 구현에 의존.

### 3.2 `POST /api/maker-invitations` — 초대코드 등록 (옵션)

**Controller**: `MakerInvitationController.java:44-53` (`@PreAuthorize("isMaker(#request.campaignId)")`)

**UseCase**: `RegisterMakerInvitationUseCase.register` — `// TODO validate` 주석만 있고 검증 없음. `MakerInvitation` 1건 INSERT (`Status='REGISTERED_CODE'`).

```java
// MakerInvitation.java:24-29
public MakerInvitation(final String code, final Integer campaignId, final Integer inviteeUserId) {
  this.code = code;
  this.campaignId = campaignId;
  this.inviteeUserId = inviteeUserId;
  this.status = MakerInvitationStatus.REGISTERED_CODE;
}
```

→ **혜택 지급은 batch 잡이 처리** (`MakerInvitationBenefitJobConfig`). `REGISTERED_CODE` → `PROCESSING_BENEFIT_PAYMENT` → `PAID_BENEFIT` 으로 진행하면서 `MakerInvitationBenefit` / `MakerInvitationBenefitPayment` row 들을 만듦. 펀딩 생성 자체에는 영향 없음.

### 3.3 `POST /api/v1/ai-review/story/request/{campaignId}` — AI 스토리 심사 (옵션)

**Controller**: `AIReviewController.java:25-29` → `AIReviewQueryGatewayImpl.requestAIReview` (`:65-`)

```
[메이커] POST /api/v1/ai-review/story/request/{id}
   │
   ▼
[funding-api] CampaignStory 조회 + 최대 횟수 체크
   │
   ▼  ★ 동기 호출 (RestTemplate)
[외부 AI 서버] aiReviewClient.requestAiReview(...)
   │
   ▼ 즉시 SA(접수)/SR(거부) 응답
[funding-api] AIReviewManagement INSERT (status='SA'/'SR')
              AIReviewManagementHistory INSERT
              OngoingStoryItemContext 다건 INSERT
   │
   ▼
[메이커에게] { resultCode: SA|SR, resultMsg }
```

실제 심사 결과는 외부 AI 서버가 콜백:
```
POST /api/internal/story/response/{campaignId}
  → AIReviewInternalController:28
  → AIReviewManagement UPDATE + 알림톡/메일 발송
```

→ **주기적 폴링/스케줄러 아님. API 호출 시에만 외부 서버에 작업 등록.** 펀딩 생성 흐름에서는 옵션.

### 3.4 번역 (`/api/internal/translate/*`)

**Controller**: `InternalTranslateController.java`

| 경로 | 동작 |
|---|---|
| `POST /api/internal/translate/text` | **동기**, 즉시 결과 반환 |
| `POST /api/internal/translate/html` | **동기**, 즉시 결과 반환 |
| `POST /api/internal/translate/ai` | **비동기**, 결과는 `/callback` |
| `POST /api/internal/translate/image` | **비동기**, 결과는 `/image/callback` |

`POST /api/v1/translate/request/{projectNo}` (메이커 호출용) → 위 ai/image async 흐름 트리거. 한국어 단일 메이커이면 호출 안 해도 무관.

---

## 4. DB — 관련 테이블·컬럼 전체

| 단계 | 테이블 | 핵심 컬럼 | 작업 |
|---|---|---|---|
| setUp | `Campaign` | `CampaignId(PK,AI)`, **`UserId`**, `WhenCreated`, `IsDel(=FALSE 기본)` | INSERT |
| setUp | `RewardSettlementRate` | `CampaignId`, `FeeTypeSeq`, `Status` | INSERT (Status NULL → A10) |
| setUp | `RewardMakerStudio` | `CampaignId`, `IsPassedIntro=false` | INSERT |
| setUp | `RewardMakerStudioSection` | `CampaignId`, `Section`(7종 enum), `Status='BEFORE_WRITING'` | 배치 INSERT 7건 |
| setUp default | `CampaignRewardDelay` | `CampaignId`, `ExpectedDelayDay`, `DelayGuarantee`, `ReturnExchangePolicy`, `NoRefundCase` | UPSERT (NULL) |
| setUp default | `Campaign` | `HostName`(=세션 nickname) | UPDATE |
| setUp default | `RewardComingSoon` | `CampaignId`, `Status='APPLY'` | UPSERT |
| pass-intro | `RewardMakerStudio` | `IsPassedIntro=true` | UPDATE |
| pass-intro | `CampaignCategoryMapping` | `CampaignId`, `CategoryCode`, `IsPrime=true`, `OrderNo=1`, `RegisteredBy` | DELETE+INSERT |
| pass-intro | `CampaignCategoryMappingHistory` | `CampaignId`, `CategoryCode`, `IsPrime` | INSERT |
| pass-intro | `Campaign` | `IsAdultContent`, `MakerStudioLanguageCode`, `CorpType` | UPDATE |
| pass-intro | `CampaignContractInfo` | `CampaignId`, `CountryCode`, `BusinessNumber`, `RegisterUserId`, `Registered` | UPSERT |
| pass-intro | `CampaignLanguageSetting` | `CampaignId`, `LanguageCode`, `IsMain`, `IsOption`, `IsAutoTranslate`, `CanSyncTranslation`, `RegisterUserId` | UPSERT |
| pass-intro | `RewardMakerStudioSectionLanguage` | `CampaignId`, `Section='STORY'`, `LanguageCode`, `Status='BEFORE_WRITING'` | 배치 INSERT |
| sections/requirement | `Campaign` | `BizModel`, `Classification`, `CopiedBy`, **`TargetAmount`**, `CustValueCode`, `CorpType`, `IsAdultContent` | UPDATE |
| sections/requirement | `CampaignContractInfo` | `BusinessNumber`, `BusinessName`, `OpeningDate`, `IsBusinessLicenseVerified`, `IsBusinessManualAuthProcessed`, `BusinessAddress` | UPSERT |
| sections/requirement | `ScreeningRewardItem` | `ScreeningRewardItemNo(AI)`, `CampaignId`, `CategoryCode`, `ProductionTypeCode`, `IsSimpleDistributor`, `IsUsedMold`, `OrderNo`, `IsDeleted=false` 외 | INSERT N개 |
| sections/risk-policy | `CampaignRewardDelay` | `ExpectedDelayDay`, `DelayGuarantee`, `ReturnExchangePolicy`, `NoRefundCase` | UPSERT |
| sections/risk-policy | `CampaignRewardDelayLanguage` | `CampaignId`, `LanguageCode`, `ReturnExchangePolicy`, `NoRefundCase` | UPSERT |
| sections/maker-info | `Campaign` | `HostName`, `GlobalMakerName`, `PhotoIdHost`, `HostEmail`, `WebsiteA/B`, `SocialUrlFb/Ig/TW`, `MakerContactProperty(JSON)` | UPDATE |
| sections/contract-info | `CampaignContractInfo` | (위 + 정산계좌·예금주) | UPSERT |
| sections/plan | `CampaignPackagePlan` | `CampaignId`, `PackagePlanType`, `Registered`, `Updated` | UPSERT |
| sections/plan | `CampaignPackagePlanHistory` | `CampaignId`, `PreviousPackagePlanType`, `NewPackagePlanType`, `ChangeType`, `RegisterUserId` | INSERT |
| 모든 섹션 저장 | `RewardMakerStudioSection` | `Status='WRITING'`/`'COMPLETED_WRITING'`, `Updated=NOW()` | UPDATE |
| 제출 검증 보강 | `RewardMakerAgreement` | `CampaignId`, `RegisterUserId`, `MakerAgreementType`('MAKER_SERVICE_USE_AGREE' 또는 'GLOBAL_MAKER_SERVICE_USE_AGREE'), `ClientIp` | INSERT |
| 제출 검증 보강 | `CampaignShippingCountry` | `CampaignId`, `CountryCode`('KR' 필수), `RegisterUserId` | INSERT |
| (옵션) 초대코드 | `MakerInvitation` | `Code`, `CampaignId`, `Status='REGISTERED_CODE'`, `InviteeUserId`, `RegisterUserId` | INSERT |
| submit | `Campaign` | `IsSubmitted=TRUE`, `SubmittedUserId`, `WhenSubmitted=NOW()`, `IsStandingBy=TRUE` | UPDATE |
| submit | `CampaignScreening` | `(ScrType,CampaignId)`, `StatusCode`, `Registered`, `StatusUpdated` | UPSERT × 2 (`'S'`/`'D'`) |
| submit | `CampaignScreeningLog` | `CampaignId`, `ScrType`, `StatusCode`, `Event`, `Description`, `RegisterUserId` | INSERT × 2 |
| submit | `SettlementSystem` | `CampaignId`, `SystemType` | UPSERT |
| submit | `RewardSettlementAdditionalCost` | `Type='BASIC_SERVICE_FEE'`, `CampaignId`, `CostAmount=99000`, `CostReason`, `RegistUserId` | INSERT |
| submit | `RewardSettlementRate` | `Status='A30'`, `Updated` | UPDATE (A10/A20 → A30) |
| submit | `CampaignAgreement` | `CampaignId`, `AgreementType`(POA/JRPOA/JGA), `AgreementStatus`, `RegisteredBy` | INSERT × 3 |
| submit | `CampaignAgreeConclusion` | `CampaignId`, `AgreeConclusionNeed` | UPSERT |
| submit | `RewardComingSoon` | `Status='STANDBY'` | UPDATE |

### 4.1 주요 SQL 본문 (MyBatis XML 발췌)

**Campaign 발급** — `campaign-setup-mapper.xml:5-8`
```sql
INSERT INTO Campaign (UserId, WhenCreated)
VALUES (#{userId}, NOW())
```

**스튜디오 + 섹션** — `maker-studio-mapper.xml:25-28`, `maker-studio-section-mapper.xml:24-30`
```sql
INSERT INTO RewardMakerStudio(CampaignId, IsPassedIntro)
VALUES (#{campaignId}, #{isPassedIntro})

INSERT INTO RewardMakerStudioSection(CampaignId, Section, Status) VALUES
  (..., ..., ...)
```

**기본 수수료** — `settlement-mapper.xml:11-14`
```sql
INSERT INTO RewardSettlementRate (CampaignId, FeeTypeSeq)
VALUES(#{campaignId}, #{settlementFee.baseFeeType.feeTypeSeq})
```

**카테고리·인트로** — `campaign-setup-mapper.xml:38-44, 46-54`
```sql
UPDATE Campaign
SET IsAdultContent = #{isAdultContent},
    MakerStudioLanguageCode = #{makerWriteLanguage},
    CorpType = #{corpType}
WHERE CampaignId = #{campaignId}

INSERT INTO CampaignContractInfo (CampaignId, CountryCode, BusinessNumber, RegisterUserId, Registered)
VALUES (...) ON DUPLICATE KEY UPDATE ...
```

**요건 섹션** — `campaign-mapper.xml:84-94`
```sql
UPDATE Campaign
SET BizModel       = #{campaignBizModel},
    Classification = #{classification},
    CopiedBy       = #{copiedBy},
    TargetAmount   = #{targetAmount},
    CustValueCode  = #{categoryId},
    CorpType       = #{corpType},
    IsAdultContent = #{isAdultContent}
WHERE CampaignId = #{campaignId}
```

**메이커 정보 섹션** — `maker-mapper.xml:48-61`
```sql
UPDATE Campaign SET
  HostName = #{makerName}, GlobalMakerName = #{globalMakerName},
  PhotoIdHost = #{profileImage.photoId}, HostEmail = #{contactEmail},
  WebsiteA = #{websiteAUrl}, WebsiteB = #{websiteBUrl},
  SocialUrlFb = #{facebookUrl}, SocialUrlIg = #{instagramUrl}, SocialUrlTW = #{twitterUrl},
  MakerContactProperty = #{makerContactJson}
WHERE CampaignId = #{campaignId}
```

**요금제** — `packageplan-mapper.xml:61-67`
```sql
INSERT INTO CampaignPackagePlan(CampaignId, PackagePlanType, Registered, Updated)
VALUES (#{campaignId}, #{packagePlan.type}, NOW(), NOW())
ON DUPLICATE KEY UPDATE PackagePlanType = #{packagePlan.type}, Updated = NOW()
```

---

## 5. Validator — 두 단계로 막는다

### 5.1 단계 1: DTO `@Valid` (컨트롤러 진입 시)

| 단계 | 필드 | 어노테이션 |
|---|---|---|
| pass-intro | `categoryId`, `isAdultContent` | `@NotNull` |
| sections/requirement | `targetAmount` | `@Min(500_000)` `@Max(1_000_000_000)` |
| sections/requirement | `businessNumber` | `@Size(max=20)` |
| sections/requirement | `invoiceRecipient` | `@Email` |
| sections/requirement | `isAdultContent`, `isTemporary` | `@NotNull` |
| sections/requirement | `representatives[].mobileNumber` | `@Pattern("[0-9]{10,11}")` |

→ DB 직접 INSERT 시 `targetAmount=100` 같은 값을 넣으면 row 는 들어가지만, 이후 메이커가 수정/저장하는 순간 이 검증에 걸려 저장 실패.

### 5.2 단계 2: `RewardMakerStudioSubmitValidator.validate()` (제출 시)

| 검증 | 내용 | 위배 시 예외 |
|---|---|---|
| 휴대폰 인증 | KR: `UserProfile.IsCertifiedMobileNumber=TRUE`<br>그 외: `UserProfile.MobileNumber` 비어있지 않음 | `NotCertifiedMobileNumberException` |
| 섹션 일치 | `feeVersion` 별 정의된 섹션 셋 == DB 의 `RewardMakerStudioSection` 셋 | `SectionMismatchException` |
| 모든 섹션 제출 가능 status | `SectionStatus.isSubmittable=true` 인 값만 허용 | `NotAllowedSubmitException` |
| 메이커 동의 | KR: `RewardMakerAgreement` 에 `'MAKER_SERVICE_USE_AGREE'` row<br>그 외: `'GLOBAL_MAKER_SERVICE_USE_AGREE'` row | `MissingRequiredMakerAgreementException` |
| 대표자 본인인증 | `request.isAuthenticationRequired=true` AND `feeVersion >= SIMPLIFIED_CONTRACT_MIN_FEE_VERSION` 시 `Contractor.representative.isVerified=true` | `RequiredRepresentativeVerifiedException` |
| 배송국가 KR | `CampaignShippingCountry` 에 `CountryCode='KR'` row 존재 | `ShippingCountryNotValidException` |
| 요금제 | `CampaignPackagePlan.PackagePlanType IN ('STARTER','STANDARD')`. 다르면 PLAN 섹션 자동 초기화 후 예외 | `InvalidPackagePlanException` |

### 5.3 `SectionStatus` enum 전체

| 값 | 한글 | isSubmittable |
|---|---|:--:|
| `BEFORE_WRITING` | 작성 전 | ❌ |
| `WRITING` | 작성 중 | ❌ |
| **`COMPLETED_WRITING`** | **작성 완료** | ✅ |
| `FEEDBACK` | 수정 요청 | ❌ |
| `ASK_QUESTION` | 추가 응답 요청 | ❌ |
| `FEEDBACK_AND_ASK_QUESTION` | 수정·추가 응답 요청 | ❌ |
| `APPLY_FEEDBACK` | 수정 완료 | ✅ |
| `UNDER_REVIEW` | 확인 중 | ❌ |
| `REVIVAL_FEEDBACK` | 사후 심의 피드백 중 | ✅ |
| `NONE` | 제출 완료 | ✅ |

---

## 엔드투엔드 시퀀스

```
[FE: studio/funding /studio/reward/registration]
     │ POST /web/reward/api/studios
     ▼
[com.wadiz.web: RewardMakerStudioApiController.setUp]
     │ INSERT Campaign, RewardSettlementRate, RewardMakerStudio,
     │ RewardMakerStudioSection×7, CampaignRewardDelay, RewardComingSoon
     │ + UPDATE Campaign.HostName
     ▼ { campaignId }
[FE]
     │ POST /pass-intro
     ▼
[com.wadiz.web]
     │ UPDATE RewardMakerStudio.IsPassedIntro=true
     │ + CampaignCategoryMapping(DEL+INS) + History
     │ + UPDATE Campaign + UPSERT CampaignContractInfo
     │ + UPSERT CampaignLanguageSetting + RewardMakerStudioSectionLanguage
     ▼
[FE]  POST /sections/{requirement|risk-policy|maker-info|contract-info|plan} (반복)
     ▼
[com.wadiz.web]  각 섹션 도메인 테이블 UPSERT + RewardMakerStudioSection.Status
     ▼
[FE]  POST /images (multipart) → S3
     ▼
[FE]  GET/POST /web/apip/funding/studio/{id}/pricing  (funding-api 프록시)
     ▼
[com.wadiz.api.funding: StudioPricingController]  CampaignPackagePlan UPSERT
     ▼
[FE]  POST /submit  { isAuthenticationRequired }
     ▼
[com.wadiz.web: RewardMakerStudioSubmitApiController]
     │ Validator (휴대폰/섹션/동의/배송/요금제)
     │ MyFundingGateway.postSubmitApproval(campaignId)
     ▼
[com.wadiz.api.funding: CampaignSubmitController]
     │ Campaign(IsSubmitted=TRUE), Screening×2 + Log×2
     │ SettlementSystem, RewardSettlementAdditionalCost(99,000원)
     │ RewardSettlementRate.Status='A30'
     │ Agreement×3, AgreeConclusion
     │ RewardComingSoon STANDBY
     │ + 외부: Alimtalk / Slack / Email
     ▼
완료 (메이커가 어드민 심사 대기 상태)
```

---

## 부록 — "데이터만 동등하게" SQL 합성 (테스트 목적)

> **주의**: 단일 트랜잭션, `@user_id` 는 이미 `UserProfile` 에 존재하는 메이커여야 함. enum 값(BizModel/Classification/AgreementType 등)은 도메인이 허용한 값을 박았음. 외부 알림·S3·콜백은 흉내내지 않음 — 어디까지나 row 수준 동등성.

```sql
SET @user_id          = 12345;
SET @maker_nickname   = '와디즈메이커';
SET @category_code    = 'CT001';
SET @cust_value_code  = 1001;
SET @is_adult         = FALSE;
SET @maker_country    = 'KR';
SET @maker_lang       = 'ko';
SET @corp_type        = 'IB';
SET @business_number  = '1234567890';
SET @business_name    = '와디즈컴퍼니';
SET @target_amount    = 5000000;
SET @biz_model        = 'PRE_ORDER';
SET @classification   = 'NEW';
SET @package_plan     = 'STANDARD';
SET @fee_type_seq     = 1;

START TRANSACTION;

-- STEP 1. setUp
INSERT INTO Campaign (UserId, WhenCreated) VALUES (@user_id, NOW());
SET @campaign_id = LAST_INSERT_ID();

INSERT INTO RewardSettlementRate (CampaignId, FeeTypeSeq) VALUES (@campaign_id, @fee_type_seq);

INSERT INTO CampaignRewardDelay
  (CampaignId, ExpectedDelayDay, DelayGuarantee, ReturnExchangePolicy, NoRefundCase, Updated)
VALUES (@campaign_id, NULL, NULL, NULL, NULL, NOW())
ON DUPLICATE KEY UPDATE Updated = NOW();

INSERT INTO RewardMakerStudio (CampaignId, IsPassedIntro) VALUES (@campaign_id, FALSE);

INSERT INTO RewardMakerStudioSection (CampaignId, Section, Status) VALUES
  (@campaign_id, 'REQUIREMENT',   'BEFORE_WRITING'),
  (@campaign_id, 'PLAN',          'BEFORE_WRITING'),
  (@campaign_id, 'RISK_POLICY',   'BEFORE_WRITING'),
  (@campaign_id, 'MAKER_INFO',    'BEFORE_WRITING'),
  (@campaign_id, 'CONTRACT_INFO', 'BEFORE_WRITING'),
  (@campaign_id, 'STORY',         'BEFORE_WRITING'),
  (@campaign_id, 'BASIC_INFO',    'BEFORE_WRITING');

UPDATE Campaign SET HostName = @maker_nickname WHERE CampaignId = @campaign_id;

INSERT INTO RewardComingSoon (CampaignId, Status) VALUES (@campaign_id, 'APPLY')
ON DUPLICATE KEY UPDATE Status = 'APPLY';

-- STEP 2. pass-intro
UPDATE RewardMakerStudio SET IsPassedIntro = TRUE WHERE CampaignId = @campaign_id;

DELETE FROM CampaignCategoryMapping WHERE CampaignId = @campaign_id;
INSERT INTO CampaignCategoryMapping
  (CampaignId, CategoryCode, IsPrime, OrderNo, RegisteredBy)
VALUES (@campaign_id, @category_code, TRUE, 1, @user_id);

INSERT INTO CampaignCategoryMappingHistory (CampaignId, CategoryCode, IsPrime)
VALUES (@campaign_id, @category_code, TRUE);

UPDATE Campaign
   SET IsAdultContent          = @is_adult,
       MakerStudioLanguageCode = @maker_lang,
       CorpType                = @corp_type
 WHERE CampaignId = @campaign_id;

INSERT INTO CampaignContractInfo
  (CampaignId, CountryCode, BusinessNumber, RegisterUserId, Registered)
VALUES (@campaign_id, @maker_country, @business_number, @user_id, NOW())
ON DUPLICATE KEY UPDATE
  CountryCode    = @maker_country,
  BusinessNumber = @business_number,
  UpdateUserId   = @user_id,
  Updated        = NOW();

INSERT INTO CampaignLanguageSetting
  (CampaignId, LanguageCode, IsMain, IsOption, IsAutoTranslate, CanSyncTranslation, RegisterUserId)
VALUES (@campaign_id, @maker_lang, 1, 0, 0, 1, @user_id)
ON DUPLICATE KEY UPDATE
  IsMain = 1, IsOption = 0, IsAutoTranslate = 0, CanSyncTranslation = 1,
  Updated = CURRENT_TIMESTAMP;

INSERT INTO RewardMakerStudioSectionLanguage
  (CampaignId, Section, LanguageCode, Status)
VALUES (@campaign_id, 'STORY', @maker_lang, 'BEFORE_WRITING');

-- STEP 3~7. 섹션 저장 (예시 값)
UPDATE Campaign
   SET BizModel       = @biz_model,
       Classification = @classification,
       CopiedBy       = NULL,
       TargetAmount   = @target_amount,
       CustValueCode  = @cust_value_code,
       CorpType       = @corp_type,
       IsAdultContent = @is_adult
 WHERE CampaignId = @campaign_id;

INSERT INTO CampaignRewardDelay
  (CampaignId, ExpectedDelayDay, DelayGuarantee, ReturnExchangePolicy, NoRefundCase, Updated)
VALUES (@campaign_id, 30, '리워드 발송 지연 시 안내…', '환불 정책 본문…', '환불 불가 케이스…', NOW())
ON DUPLICATE KEY UPDATE
  ExpectedDelayDay     = VALUES(ExpectedDelayDay),
  DelayGuarantee       = VALUES(DelayGuarantee),
  ReturnExchangePolicy = VALUES(ReturnExchangePolicy),
  NoRefundCase         = VALUES(NoRefundCase),
  Updated              = NOW();

INSERT INTO CampaignRewardDelayLanguage
  (CampaignId, LanguageCode, ReturnExchangePolicy, NoRefundCase, RegisterUserId)
VALUES (@campaign_id, @maker_lang, '환불 정책 본문…', '환불 불가 케이스…', @user_id)
ON DUPLICATE KEY UPDATE
  ReturnExchangePolicy = VALUES(ReturnExchangePolicy),
  NoRefundCase         = VALUES(NoRefundCase);

UPDATE Campaign
   SET HostName             = '와디즈컴퍼니',
       GlobalMakerName      = 'Wadiz Company',
       PhotoIdHost          = 999001,
       HostEmail            = 'maker@example.com',
       WebsiteA             = 'https://example.com',
       MakerContactProperty = '{"kakaoChannel":""}'
 WHERE CampaignId = @campaign_id;

INSERT INTO CampaignContractInfo
  (CampaignId, BusinessNumber, BusinessName, RegisterUserId, Registered,
   OpeningDate, IsBusinessLicenseVerified, IsBusinessManualAuthProcessed, BusinessAddress)
VALUES (@campaign_id, @business_number, @business_name, @user_id, NOW(),
        '2020-01-01', TRUE, FALSE, '서울특별시 ...')
ON DUPLICATE KEY UPDATE
  BusinessNumber = VALUES(BusinessNumber),
  BusinessName   = VALUES(BusinessName),
  UpdateUserId   = @user_id,
  Updated        = NOW(),
  OpeningDate    = VALUES(OpeningDate),
  IsBusinessLicenseVerified     = VALUES(IsBusinessLicenseVerified),
  IsBusinessManualAuthProcessed = VALUES(IsBusinessManualAuthProcessed),
  BusinessAddress               = VALUES(BusinessAddress);

INSERT INTO CampaignPackagePlan (CampaignId, PackagePlanType, Registered, Updated)
VALUES (@campaign_id, @package_plan, NOW(), NOW())
ON DUPLICATE KEY UPDATE PackagePlanType = @package_plan, Updated = NOW();

INSERT INTO CampaignPackagePlanHistory
  (CampaignId, PreviousPackagePlanType, NewPackagePlanType, ChangeType, RegisterUserId, Registered)
VALUES (@campaign_id, NULL, @package_plan, 'CREATE', @user_id, NOW(3));

-- 모든 섹션 제출 가능 status 로
UPDATE RewardMakerStudioSection
   SET Status = 'COMPLETED_WRITING', Updated = NOW()
 WHERE CampaignId = @campaign_id;

-- 제출 검증 보강
INSERT INTO RewardMakerAgreement
  (CampaignId, RegisterUserId, MakerAgreementType, ClientIp)
VALUES (@campaign_id, @user_id, 'MAKER_SERVICE_USE_AGREE', '127.0.0.1');

INSERT INTO CampaignShippingCountry (CampaignId, CountryCode, RegisterUserId)
VALUES (@campaign_id, 'KR', @user_id);

UPDATE UserProfile SET IsCertifiedMobileNumber = TRUE WHERE UserId = @user_id;

-- STEP 9. submit + funding-api approval
UPDATE Campaign
   SET IsSubmitted     = TRUE,
       SubmittedUserId = @user_id,
       WhenSubmitted   = NOW(),
       IsStandingBy    = TRUE,
       StandingByUserId = @user_id,
       WhenStandingBy  = NOW()
 WHERE CampaignId = @campaign_id;

INSERT INTO CampaignScreening (ScrType, CampaignId, StatusCode, Registered, StatusUpdated)
VALUES ('S', @campaign_id, 'WRITING', NOW(), NOW())
ON DUPLICATE KEY UPDATE StatusCode = 'WRITING', StatusUpdated = NOW();

INSERT INTO CampaignScreening (ScrType, CampaignId, StatusCode, Registered, StatusUpdated)
VALUES ('D', @campaign_id, 'APPROVED', NOW(), NOW())
ON DUPLICATE KEY UPDATE StatusCode = 'APPROVED', StatusUpdated = NOW();

INSERT INTO CampaignScreeningLog
  (CampaignId, ScrType, StatusCode, Event, Description, RegisterUserId, Registered)
VALUES
  (@campaign_id, 'S', 'WRITING',  'SUBMIT',          '메이커 제출', @user_id, NOW()),
  (@campaign_id, 'D', 'APPROVED', 'DIRECT_APPROVAL', 'PD 직접 승인', @user_id, NOW());

INSERT INTO SettlementSystem (CampaignId, SystemType, Registered, Updated)
VALUES (@campaign_id, 'AUTO', NOW(), NOW())
ON DUPLICATE KEY UPDATE SystemType = 'AUTO', Updated = NOW();

INSERT INTO RewardSettlementAdditionalCost
  (Type, CampaignId, CostAmount, CostReason, Registered, RegistUserId)
VALUES ('BASIC_SERVICE_FEE', @campaign_id, 99000, '기본 서비스 이용 수수료', NOW(), @user_id);

UPDATE RewardSettlementRate
   SET Status = 'A30', Updated = NOW()
 WHERE CampaignId = @campaign_id
   AND Status IN ('A10', 'A20');

INSERT INTO CampaignAgreement (CampaignId, AgreementType, AgreementStatus, RegisteredBy) VALUES
  (@campaign_id, 'POA',   'PENDING', @user_id),
  (@campaign_id, 'JRPOA', 'PENDING', @user_id),
  (@campaign_id, 'JGA',   'PENDING', @user_id);

INSERT INTO CampaignAgreeConclusion (CampaignId, AgreeConclusionNeed)
VALUES (@campaign_id, TRUE)
ON DUPLICATE KEY UPDATE AgreeConclusionNeed = TRUE;

UPDATE RewardComingSoon SET Status = 'STANDBY' WHERE CampaignId = @campaign_id;

COMMIT;
SELECT @campaign_id AS createdCampaignId;
```

### SQL 만으로는 빠지는 것
1. **메이커 알림** — 카카오 알림톡(템플릿 3159/3200), 이메일(1503/1504), Slack
2. **이미지 업로드** — `PhotoCommon` row 와 S3 객체. 이미 업로드된 fileId/url 을 재사용하면 SQL 만으로 가능
3. **초대코드 혜택 지급** — `MakerInvitation` INSERT 까지는 SQL 로 가능하나 혜택 row 들은 batch 가 처리
4. **AI 리뷰 / 번역** — API 호출 시점에 외부 서버 등록되는 흐름이라 SQL 로는 트리거 안 됨 (펀딩 생성 자체에는 영향 없음)
5. **검증 우회** — `@Min/@Max/@Pattern/@Email` + `RewardMakerStudioSubmitValidator` 8개 룰. SQL 로 비정상 값을 박으면 row 는 들어가도 이후 화면에서 깨질 수 있음

---

## 경계·미탐색

- `com.wadiz.funding.core:funding-core` jar 내 `CampaignSubmitUseCase` / `RegisterMakerInvitationUseCase` 등 UseCase 구현 — 어떤 Gateway 메서드들을 어떤 순서로 호출하는지의 정확한 조합은 jar 디컴파일 필요. 본 문서는 Gateway 구현체에서 관찰 가능한 SQL 만 기록.
- `MakerInvitationBenefitJobConfig` 배치 잡의 정확한 cron / 처리 윈도우
- `AIReviewClient` 의 외부 AI 서버 endpoint·SLA·max retry
- `MyFundingGateway.postSubmitApproval` 의 정확한 호출 위치 (com.wadiz.web 측 adapter) — 본 문서는 흐름만 기록
- 어드민 측 최종 심사 처리(`POST /api/internal/campaign-final-review/{projectNo}/process`) — 별도 운영자 플로우
