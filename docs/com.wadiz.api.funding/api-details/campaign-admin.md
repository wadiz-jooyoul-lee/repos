# Campaign Internal/Studio/Admin API 상세 스펙

메이커(스튜디오)와 내부 서비스·운영 관리자를 대상으로 한 캠페인(프로젝트) API 12개.

- **대상 컨트롤러 / Base Path**:
  - `CampaignInternalController` (`/api/internal/campaigns`) — 3개
  - `CampaignStudioController` (`/api/studio/campaigns/{campaignId}`) — 2개, `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`
  - `ProjectInternalController` (`/api/internal/projects`) — 2개
  - `CampaignSubmitController` (`/api/studio/submit`) — 1개, `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`
  - `CampaignFinalReviewInternalController` (`/api/internal/campaign-final-review`) — 1개
  - `CampaignHiddenInternalController` (`/api/internal/campaigns`) — 2개
  - `CampaignCategoryController` (`/api/campaign-category`) — 1개

- **저장소**: MySQL (Spring Data JDBC + MyBatis 혼용), 일부는 외부 서비스(카테고리 검색) HTTP 호출

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록한다. UseCase 구현체는 외부 jar `com.wadiz.funding.core:funding-core` 에 있으므로 UseCase 내부 호출 순서/조합은 확인 불가. Gateway 구현체와 MyBatis XML SQL은 이 레포에 존재하므로 "이 엔드포인트의 UseCase가 호출할 수 있는 연산 후보"로 기록한다.

---

## 1. GET `/api/internal/campaigns/{campaignId}/base-info` — 프로젝트 기본 정보 조회 (Internal)

- **Method**: `CampaignInternalController.campaignBaseInfo`
- **Cache**: `campaignProxy.campaignBaseInfo`가 `@Cacheable`

### Response — `CampaignBaseInfoResponse`

주요 필드 (대표 이미지·카테고리·태그·메이커·소셜·카카오톡 채널 등 중첩 구조):

| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `campaignTitle` | `String` | — |
| `representativeImage` | `Image{id, url}` | 대표 이미지 |
| `category` | `Category{id, name}` | 카테고리 |
| `searchTags` | `List<SearchTag{orderNo, tag}>` | 검색용 태그 |
| `introVideoUrl` | `String` | 소개 영상 URL |
| `introImages` | `List<Image>` | 소개 사진 |
| `story` | `String` | 프로젝트 스토리 |
| `maker` | `Maker{userId, name, profileImage, email, callNumber, homepages, snsList, kakaoTalkChannel}` | 메이커 정보 |
| `whenHoldTo` | `LocalDateTime` | 펀딩 종료 일시 |
| `isOpen` / `isAdultContent` | `Boolean` | 상태 |
| `whenSubmitted` | `LocalDateTime` | 제출 일시 |
| `categories` | `List<CampaignCategory{code, isPrime}>` | 카테고리 목록 |

### 컨트롤러 코드 흐름

1. `campaignProxy.campaignBaseInfo(campaignId)` — UseCase 호출
2. `campaignProxy.campaignStatusAsRealTime(campaignId)` — 실시간 상태 조회
3. 1의 결과를 Converter 변환 후 2의 `isOpened` 주입해 응답

### 이 엔드포인트에서 호출될 수 있는 Gateway 연산

`CampaignQueryGatewayImpl.campaignBaseInfo` 내부에서 다음 Mapper 호출이 관찰됨 (공개 `/detail`과 동일 SQL 재사용):
- `CampaignMapper.campaignBaseInfo` — 메인 쿼리 (`Campaign`, `PhotoCommon`, `CodeValue`, `EventDay`, `BackingPayment`, `BackingPaymentMapping`, `Backing`, `Shipping`, `CampaignLabel`, `CampaignMarker` 조인)
- `CampaignMapper.campaignTags` — `SELECT Tag, OrderNo FROM CampaignHashTag WHERE CampaignId = ?`
- `CampaignMapper.introImages` — `SELECT ... FROM CampaignNPhoto JOIN PhotoCommon ... WHERE CampaignId = ?`
- `CampaignMapper.getCampaignStatus` — `SELECT ... FROM Campaign LEFT JOIN RewardComingSoon ...`
- `RewardItemMapper.getRewardItems` — 리워드 목록
- `CampaignAskForEncoreMapper.selectAskForEncoreQty` — 앵콜 수(종료된 경우)
- 외부 `StoreClient.getStoreProject(campaignId)` — 종료·성공 프로젝트인 경우

> 공개 `/api/campaigns/{id}/detail`과 공유되는 메서드. 전체 SQL 원문은 [`campaign-public.md`](./campaign-public.md) 5번 항목 참조.

---

## 2. GET `/api/internal/campaigns/{campaignId}/makers/{userId}` — 프로젝트 메이커 확인

- **Method**: `CampaignInternalController.confirmMaker`
- **Cache**: `campaignProxy.confirmMaker`가 `@Cacheable`

### Response
`ResponseWrapper<Boolean>` — 소유자(메이커) 여부

### 컨트롤러 코드 흐름
1. `ConfirmMakerQuery{campaignId, userId}` 생성
2. `campaignProxy.confirmMaker(query)` 호출 → UseCase `confirmMakerUseCase.confirmMaker()` (funding-core)
3. 불리언 응답

### Gateway / SQL (관찰 가능)

이 엔드포인트 전용의 별도 Gateway 메서드는 없음. `CampaignGatewayImpl.isMaker`가 기능적으로 해당:

```java
@Override
public boolean isMaker(final Integer campaignId, final Integer userId) {
  return campaignRepository.existsByIdAndUserId(campaignId, userId);
}
```

Spring Data JDBC `existsByIdAndUserId` → 파생 쿼리 실행:
```sql
SELECT COUNT(*) > 0 FROM Campaign WHERE CampaignId = ? AND UserId = ?
```
(정확한 생성 SQL은 Spring Data JDBC 런타임 생성)

UseCase가 `isMaker` 외의 다른 검증 로직을 수행할 수도 있으나 funding-core 확인 필요.

**접근 테이블**: `Campaign`

---

## 3. GET `/api/internal/campaigns/maker-business-info` — 프로젝트 대표자/정산 정보 조회

- **Method**: `CampaignInternalController.getMakerBusinessInfo`
- **Cache**: `campaignProxy.getMakerBusinessInfo`에 `@Cacheable` 없음

### Request — `InternalCampaignMakerBusinessInfoRequest` (`@ModelAttribute`, 쿼리)

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `projectNos` | `List<Integer>` | ✅ `@NotEmpty`, `@Size(max=1000)` | 프로젝트 번호 (최대 1000개) |

### Response — `List<CampaignContractInfoResponse>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `businessRegistrationType` | `String` | 사업자 여부 (CorpType) |
| `businessRegistrationNumber` | `String` | 사업자번호 |
| `residentRegistrationNumber` | `String` | 주민등록번호 (복호화) |
| `representative.name` | `String` | 대표자 이름 |
| `settlementInfo.bankAccount.bankCode/bankName/accountNumber/accountHolder` | `String` | 계좌 정보 (계좌번호 복호화) |
| `settlementInfo.taxInvoiceRecipientEmail` | `String` | 세금계산서 이메일 |
| `personalVerification.realName/mobileNumber` | `String` | 개인 인증 정보 (복호화) |

### MySQL 쿼리 (`ContractInfoQueryGatewayImpl.getMakerBusinessInfo`)

`CampaignContractMapper.campaignContractResult`:
```sql
SELECT C.CampaignId,
       C.CorpType AS BusinessRegistrationType,
       CCI.BusinessNumber AS BusinessRegistrationNumber,
       damo.DEC_B64('${DAMO_ENC_KEY}', CCI.ResidentRegistrationNumber) AS ResidentRegistrationNumber,
       CCR.Name AS RepresentativeName,
       CCI.AccountBankCode,
       BC.BankName,
       damo.DEC_B64('${DAMO_ENC_KEY}', CCI.AccountNumber) AS AccountNumber,
       CCI.AccountHolder,
       CCI.InvoiceRecipient,
       damo.DEC_B64('${DAMO_ENC_KEY}', PVR.RealName) AS RealName,
       damo.DEC_B64('${DAMO_ENC_KEY}', PVR.MobileNumber) AS MobileNumber
FROM Campaign C
     LEFT JOIN CampaignContractInfo CCI             ON C.CampaignId = CCI.CampaignId
     LEFT JOIN CampaignContractRepresentative CCR   ON C.CampaignId = CCR.CampaignId AND CCR.OrderNo = 1
     LEFT JOIN BankCode BC                          ON BC.BankCode = CCI.AccountBankCode
     LEFT JOIN PersonalVerificationResult PVR       ON PurposeType = 'STUDIO_REPRESENTATIVE'
                                                   AND PVR.TargetKey = CONCAT(C.CampaignId)
WHERE C.CampaignId IN (?, ?, ...)
```

- `damo.DEC_B64` — 주민/계좌/실명/모바일 번호를 **암호화 저장**하고 조회 시 DB 함수로 복호화
- **접근 테이블**: `Campaign`, `CampaignContractInfo`, `CampaignContractRepresentative`, `BankCode`, `PersonalVerificationResult`

---

## 4. GET `/api/studio/campaigns/{campaignId}/payment-summation` — 결제 요약 (Studio)

- **Method**: `CampaignStudioController.getPaymentSummation`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`
- **Cache**: `campaignProxy.getPaymentSummation`가 `@Cacheable`

### Response — `PaymentSummationResponse`

| 필드 | 타입 | 설명 |
|---|---|---|
| `isCompletePayment` | `Boolean` | 최종 결제 완료 여부 |
| `completePaymentAmount` | `Long` | 결제 완료 금액 |
| `completePaymentQty` | `Long` | 결제 완료 건수 |
| `expectedPaymentAmount` | `Long` | 예상 결제 금액 |
| `expectedPaymentQty` | `Long` | 예상 결제 건수 |

### MySQL 쿼리 (`CampaignQueryGatewayImpl.paymentSummationInfo`)

`BackingPaymentMapper.backingSummationInfo`를 **2회** 호출:

**① 완료 결제 집계** (`payStatuses = C10, Z11, P10, D11`)
```sql
SELECT SUM(FundingAmount) AS BackingAmount,
       COUNT(*) AS BackingQty
FROM BackingPayment
WHERE CampaignId = ?
  AND PayStatus IN ('C10','Z11','P10','D11')
```

**② 예상 결제 집계** (`payStatuses = C10, Z11, P10, D11, A10, B10`)
```sql
SELECT SUM(FundingAmount) AS BackingAmount,
       COUNT(*) AS BackingQty
FROM BackingPayment
WHERE CampaignId = ?
  AND PayStatus IN ('C10','Z11','P10','D11','A10','B10')
```

**접근 테이블**: `BackingPayment`

---

## 5. GET `/api/studio/campaigns/{campaignId}/base-info` — 프로젝트 기본 정보 (Studio)

- **Method**: `CampaignStudioController.campaignBaseInfo`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`

Internal의 `/api/internal/campaigns/{id}/base-info`와 **동일한 Proxy 메서드·동일한 SQL 조합** 사용. 차이는 인증·보안 경계뿐. 상세는 본 문서 1번 및 `campaign-public.md` 5번 참조.

---

## 6. GET `/api/internal/projects/by-userId` — 메이커의 프로젝트 목록 (페이징)

- **Method**: `ProjectInternalController.getByUserId`
- **Cache**: 없음

### Request (Query)

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `userId` | `Integer` | ✅ | 메이커 사용자 ID |
| `page` / `size` | `int` | ⬜ | 페이징 (default 0/10) |

### Response — `PageResult<InternalProjectByUserIdResponse>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `projectNo` | `Integer` | 프로젝트 번호 |
| `title` | `String` | 제목 |
| `status` | `ProjectStatus` (enum) | 상태 |
| `isSubmitted` | `Boolean` | 제출 여부 |

### 컨트롤러 코드 흐름

1. `projectInternalProxy.getByUserId(userId, pages)` → `ProjectSearchByUserIdUseCase.execute()` (funding-core)
2. 응답 변환 후 `PageResult` 래핑

### MySQL 쿼리 (`CampaignQueryGatewayImpl.findAllProjectByUserId`)

**① 목록** (`CampaignMapper.findAllProjectByUserId`)
```sql
SELECT C.CampaignId AS projectNo, C.Title, C.IsSubmitted, C.WhenOpen, C.WhenClose,
       RCS.Status AS comingSoonStatus
FROM Campaign C
     LEFT JOIN RewardComingSoon RCS ON RCS.CampaignId = C.CampaignId
WHERE C.UserId = ?
  AND C.IsDel = FALSE
ORDER BY C.CampaignId DESC
LIMIT ?, ?
```

**② 카운트** (`countProjectByUserId`)
```sql
SELECT COUNT(*)
FROM Campaign C
     LEFT JOIN RewardComingSoon RCS ON RCS.CampaignId = C.CampaignId
WHERE C.UserId = ?
  AND C.IsDel = FALSE
```

**접근 테이블**: `Campaign`, `RewardComingSoon`

---

## 7. POST `/api/internal/projects` — 프로젝트 배치 조회 (project no 리스트)

- **Method**: `ProjectInternalController.getByProjectNos`

### Request Body — `InternalProjectRequest`

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `projectNos` | `List<Integer>` | ✅ `@NotEmpty`, `@Size(max=1000)` | 프로젝트 번호 목록 |

### Response — `List<InternalProjectResponse>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `projectNo` | `Integer` | — |
| `title` | `String` | — |
| `status` | `ProjectStatus` | 상태 |
| `isSubmitted` | `Boolean` | 제출 여부 |
| `comingSoonPostingDateTime` | `ZonedDateTime` | 오픈예정 게시일 |
| `openDateTime` | `ZonedDateTime` | 본펀딩 오픈 |
| `endDateTime` | `ZonedDateTime` | 종료 |
| `categoryCode` | `String` | 카테고리 코드 |
| `maker.userId / maker.email` | `Integer / String` | 메이커 |

### MySQL 쿼리 (`CampaignQueryGatewayImpl.findAllProjectByCampaignIds`)

`CampaignMapper.findAllProjectByProjectNos`:
```sql
SELECT C.CampaignId AS projectNo, C.Title, C.IsSubmitted, C.WhenOpen, C.WhenClose,
       RCS.Status AS comingSoonStatus,
       RCS.PostedAt AS comingSoonPostedAt,
       RCSAO.Scheduled AS comingSoonScheduledAt,
       CCM.CategoryCode AS categoryCode,
       C.UserId,
       UP.UserName AS email
FROM Campaign C
     LEFT JOIN RewardComingSoon RCS         ON RCS.CampaignId = C.CampaignId
     LEFT JOIN RewardComingSoonAutoOpen RCSAO
                                            ON RCSAO.CampaignId = C.CampaignId AND RCSAO.IsCanceled = FALSE
     LEFT JOIN CampaignCategoryMapping CCM  ON CCM.CampaignId = C.CampaignId AND CCM.IsPrime = TRUE
     LEFT JOIN UserProfile UP               ON UP.UserId = C.UserId
WHERE C.CampaignId IN (?, ?, ...)
  AND C.IsDel = FALSE
```

**접근 테이블**: `Campaign`, `RewardComingSoon`, `RewardComingSoonAutoOpen`, `CampaignCategoryMapping`, `UserProfile`

---

## 8. POST `/api/studio/submit/{projectNo}/approval` — 제출 + 최종 승인 (Studio)

프로젝트 제출과 최종 승인을 **한 번에** 처리. PD 컨설팅 미승인 시 2차 심사 중 상태까지만 처리.

- **Method**: `CampaignSubmitController.approval`
- **Security**: `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`

### Path / Response
- `projectNo: Integer` (path)
- Response: `ServiceOperationResponse { success: boolean, errorCode: String, message: String }`
- 예외 발생 시 `error("SUBMIT_APPROVAL_FAILED", ...)` 반환

### 컨트롤러 코드 흐름
1. `SecurityUtils.currentUserId()`로 사용자 ID 획득
2. `SubmitApprovalCommand{projectNo, userId}` 생성
3. `campaignSubmitProxy.approval(command)` 호출 — UseCase는 funding-core
4. 성공 시 `ServiceOperationResponse.success`, 예외 시 `error` 응답

### 이 엔드포인트 관련 Gateway 구현체 (모두 funding-core UseCase가 호출할 수 있는 후보)

`adapter/infrastructure/.../domain/campaign/submitapproval/` 경로에 6개 Gateway 구현체가 존재:

| Gateway 구현체 | 주요 메서드 → Mapper → SQL |
|---|---|
| `CampaignSubmitApprovalGatewayImpl` | `submitCampaign(pid,uid)` → `CampaignSubmitApprovalMapper.submitCampaign` |
| `CampaignSubmitApprovalGatewayImpl` | `standByCampaign(pid,uid)` → `.standByCampaign` |
| `CampaignSubmitApprovalGatewayImpl` | `updateWhenOpenFromReservation(pid)` → `findActiveOpenReservationSchedule` + `updateWhenOpen` |
| `ScreeningCommandGatewayImpl` | `directApprove(pid,uid,storyStatus,event,desc)` → `upsertScreeningStatus` × 2 + `insertScreeningLog` × 2 |
| `ScreeningCommandGatewayImpl` | `getPdScreeningStatus(pid)` → `findPdScreeningByCampaignId` |
| `CampaignAgreementCommandGatewayImpl` | `CampaignAgreementMapper.deleteAgreement` / `insertAgreements` / `insertAgreementHistory` / `upsertAgreeConclusion` / `findJgaAgreementStatus` |
| `SettlementCommandGatewayImpl` | `SettlementCommandMapper.upsertSettlementSystem` / `countBasicServiceFee` / `insertBasicServiceFee` / `confirmSettlementRate` / `insertSettlementStatusLog` |
| `ComingSoonCommandGatewayImpl` | `isApplied(pid)` → `findStatusByCampaignId` / `standby(pid,uid,desc)` → `updateStatusToStandby` + `insertStatusLog` |
| `SubmitApprovalEventGatewayImpl` | 메이커 알림 발송 이벤트 (Slack/메일 등, 구체 호출은 funding-core가 결정) |

### 주요 SQL (UseCase가 호출할 수 있는 후보)

**[1] 제출 상태 업데이트** (`CampaignSubmitApprovalMapper.submitCampaign`)
```sql
UPDATE Campaign SET
  IsSubmitted = TRUE,
  SubmittedUserId = ?,
  WhenSubmitted = NOW()
WHERE CampaignId = ?
```

**[2] 스탠딩바이 상태 업데이트** (`standByCampaign`)
```sql
UPDATE Campaign SET
  IsStandingBy = TRUE,
  StandingByUserId = ?,
  WhenStandingBy = NOW()
WHERE CampaignId = ?
```

**[3] 오픈 예약 조회** (`findActiveOpenReservationSchedule`)
```sql
SELECT AO.Scheduled FROM CampaignAutoOpen AO
WHERE AO.CampaignId = ? AND AO.IsCancel = FALSE
```

**[4] 오픈일 설정** (`updateWhenOpen`)
```sql
UPDATE Campaign SET WhenOpen = ? WHERE CampaignId = ?
```

**[5] 심사 상태 UPSERT** (`CampaignScreeningMapper.upsertScreeningStatus`)
```sql
INSERT INTO CampaignScreening (ScrType, CampaignId, StatusCode, Registered, StatusUpdated)
VALUES (?, ?, ?, NOW(), NOW())
ON DUPLICATE KEY UPDATE
  StatusCode = ?,
  StatusUpdated = NOW()
```

**[6] 심사 로그** (`insertScreeningLog`)
```sql
INSERT INTO CampaignScreeningLog
  (CampaignId, ScrType, StatusCode, Event, Description, RegisterUserId, Registered)
VALUES (?, ?, ?, ?, ?, ?, NOW())
```

**[7] PD 심사 상태 조회** (`findPdScreeningByCampaignId`)
```sql
SELECT StatusCode FROM CampaignScreening
WHERE CampaignId = ? AND ScrType = 'D'
```

**[8] 정산 시스템 UPSERT** (`SettlementCommandMapper.upsertSettlementSystem`)
```sql
INSERT INTO SettlementSystem (CampaignId, SystemType, Registered, Updated)
VALUES (?, ?, NOW(), NOW())
ON DUPLICATE KEY UPDATE SystemType = ?, Updated = NOW()
```

**[9] 기본 서비스 수수료 (99,000원) INSERT** (`insertBasicServiceFee`)
```sql
INSERT INTO RewardSettlementAdditionalCost
  (Type, CampaignId, CostAmount, CostReason, Registered, RegistUserId)
VALUES ('BASIC_SERVICE_FEE', ?, 99000, '기본 서비스 이용 수수료', NOW(), ?)
```

**[10] 정산 비율 확정 A30** (`confirmSettlementRate`)
```sql
UPDATE RewardSettlementRate SET
  Status = 'A30', Updated = NOW()
WHERE CampaignId = ? AND Status IN ('A10','A20')
```

**[11] 약정 INSERT (3건: POA/JRPOA/JGA)** (`CampaignAgreementMapper.insertAgreements`)
```sql
INSERT INTO CampaignAgreement (CampaignId, AgreementType, AgreementStatus, RegisteredBy)
VALUES (?, ?, ?, ?), (?, ?, ?, ?), (?, ?, ?, ?)
```

**[12] 커밍순 STANDBY** (`ComingSoonMapper.updateStatusToStandby` + `insertStatusLog`)
- 실제 XML은 `ComingSoonMapper.xml`에 존재 (본 문서에 전문 미포함)

**접근 테이블(전체 가능 범위)**: `Campaign`, `CampaignAutoOpen`, `CampaignScreening`, `CampaignScreeningLog`, `SettlementSystem`, `RewardSettlementAdditionalCost`, `RewardSettlementRate`, `RewardSettlementStatusLog`, `CampaignAgreement`, `CampaignAgreementHistory`, `CampaignAgreeConclusion`, `RewardComingSoon`, `RewardComingSoonStatusLog`

> 위 SQL 중 **어느 것이 이 단일 엔드포인트 호출 한 번에 실제로 실행되는지**는 funding-core `CampaignSubmitUseCase` 구현 확인 필요.

---

## 9. POST `/api/internal/campaign-final-review/{projectNo}/process` — 최종 심사 처리

관리자가 최종 심사 시 필요한 스토리 복사 + 번역 요청을 묶어 처리.

- **Method**: `CampaignFinalReviewInternalController.processFinalReview`

### Path / Body / Response

**Path**: `projectNo: int`

**Request Body** — `FinalReviewWithCopyRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `adminUserId` | `int` | 관리자 사용자 ID |
| `translationStatus` | `TranslationStatus` (enum) | 번역 요청 상태 |

**Response**: `ServiceOperationResponse`
- 성공 시 `message = "최종 심사 처리가 완료되었습니다."`
- 실패 분기별 errorCode: `STORY_COPY_FAILED`, `INVALID_TRANSLATION_STATUS`, `TRANSLATION_ALREADY_EXISTS`, `INTERNAL_ERROR`

### 컨트롤러 코드 흐름

1. `campaignFinalReviewProxy.processFinalReview(projectNo, adminUserId, translationStatus)` 호출
2. 정의된 예외 4종을 catch해 각각의 errorCode 응답

### Gateway / SQL

본 레포의 `adapter/infrastructure` 하위에 `CampaignFinalReview*` Gateway 구현체는 존재하지 않음. UseCase는 아마도 스토리 복사(`story.copy` 도메인)와 번역 요청(`story.translation` 도메인)의 기존 Gateway/Mapper를 조합해 호출할 것으로 보이며, 해당 SQL은 각 도메인 상세 문서(`story-*.md`, 추후 작성) 참조.

→ **이 엔드포인트 고유의 DB 호출은 이 레포에서 특정 불가**. funding-core 확인 필요.

---

## 10. POST `/api/internal/campaigns/{campaignId}/hidden` — 캠페인 비공개 처리

관리자가 특정 프로젝트를 비공개 처리하고 메이커에게 알림 발송.

- **Method**: `CampaignHiddenInternalController.hide`

### Path / Body

**Path**: `campaignId: int`

**Request Body** — `CampaignHiddenRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `userId` | `int` | 처리 관리자 ID |
| `reason` | `String` | 비공개 사유 |

**Response**: `ServiceOperationResponse` (성공 메시지 or `INTERNAL_ERROR`)

### 컨트롤러 코드 흐름

`campaignHiddenProxy.processHide(campaignId, userId, reason)` 호출 → `CampaignHiddenUseCase.processHide` (funding-core)

### Gateway 구현체 `CampaignHiddenGatewayImpl` 연산 (이 레포 관찰)

`hideCampaign(campaignId, userId, reason)` — 2개 SQL 순차 실행:

**① 비공개 플래그 UPDATE** (`CampaignCommandMapper.hideCampaign`)
```sql
UPDATE Campaign SET IsHidden = TRUE WHERE CampaignId = ?
```

**② 이력 INSERT** (`insertHiddenHistory`)
```sql
INSERT INTO CampaignHiddenHistory (CampaignId, RegisterUserId, Reason, IsHidden)
VALUES (?, ?, ?, TRUE)
```

또한 `hiddenAlarm(campaignId, isHidden=true)`가 UseCase에서 호출되면:

**③ 메이커 언어 조회** (`getMakerStudioLanguageCode`)
```sql
SELECT MakerStudioLanguageCode FROM Campaign WHERE CampaignId = ?
```

**④ 알림 데이터 조회** (`getHiddenAlarmData`)
```sql
SELECT C.UserId, CL.Title, UP.UserName, UP.NickName, UP.MobileNumber
FROM Campaign C
     INNER JOIN CampaignLanguage CL ON C.CampaignId = CL.CampaignId
     INNER JOIN UserProfile UP      ON C.UserId = UP.UserId
WHERE C.CampaignId = ?
  AND CL.LanguageCode = ?
```

**⑤ 외부 API**:
- `AlimtalkV2Client.sendBizMessage(request)` — 카카오 알림톡 발송 (비공개 템플릿 3200, 공개 3159)
- `NotificationClient.postMailBatchInfoV3(mailBatch)` — 이메일 발송 (비공개 템플릿 1504, 공개 1503)

**접근 테이블/리소스**: `Campaign`, `CampaignHiddenHistory`, `CampaignLanguage`, `UserProfile`, 외부 알림/이메일 서비스

> UseCase가 ①②를 호출하는 것은 Gateway의 `hideCampaign` 메서드 구현 상 확정적. ③④⑤는 `hiddenAlarm` 호출 여부에 따라 달라지며 funding-core 확인 필요.

---

## 11. POST `/api/internal/campaigns/{campaignId}/shown` — 캠페인 공개 처리

`hide`의 역방향.

- **Method**: `CampaignHiddenInternalController.show`
- **Request/Response**: `hide`와 동일 구조 (`CampaignHiddenRequest` / `ServiceOperationResponse`)

### Gateway 연산

`CampaignHiddenGatewayImpl.showCampaign`:

**① 공개 플래그 UPDATE** (`CampaignCommandMapper.showCampaign`)
```sql
UPDATE Campaign SET IsHidden = FALSE WHERE CampaignId = ?
```

**② 이력 INSERT** (동일 구조, `IsHidden = FALSE`)

**③~⑤**: `hide`와 동일 (단 템플릿 번호: 메일 1503, 알림 3159)

**접근 테이블/리소스**: 위 10번과 동일

---

## 12. GET `/api/campaign-category/` — 펀딩 카테고리 조회

- **Method**: `CampaignCategoryController.getFundingCategory`
- **Cache**: `@Cacheable(cacheNames="CampaignCategory", keyGenerator="languageKeyGenerator")`

### Response — `List<CampaignCategory>`

| 필드 | 타입 | 설명 |
|---|---|---|
| `categoryCode` | `String` | 카테고리 코드 |
| `categoryName` | `String` | 카테고리 명 |
| `depth` | `Integer` | 깊이 |
| `parentCategoryCode` | `String` | 상위 카테고리 |
| `navigator` | `String` | 상위>하위 네비게이션 문자열 |

### DB 호출 — **없음**

`CampaignCategoryQueryGatewayImpl.getFundingCategory`는 **MySQL을 사용하지 않는다**. 외부 검색 서비스 호출:

```java
@Cacheable
public List<CampaignCategory> getFundingCategory() {
  List<SearchCategoryResponse> searchCategoryResponse = categorySearchClient.getFundingCategory();
  // 결과를 flatten하며 parent>child navigator 문자열 구성
  ...
}
```

- 외부 의존: `CategorySearchClient` (HTTP 클라이언트, 카테고리 검색 서비스)
- 메모리에서 parent/children flatten 처리 후 캐시(`CampaignCategory` 캐시)

---

## 13. 참고 — 이 문서에서 등장한 Gateway / Mapper

### 컨트롤러 → Proxy → UseCase (funding-core) → Gateway(이 레포) 구조

- `CampaignProxy` → `CampaignGatewayImpl` / `CampaignQueryGatewayImpl` / (contractinfo) `ContractInfoQueryGatewayImpl`
- `ProjectInternalProxy` → `CampaignQueryGatewayImpl` 중 project 관련 메서드
- `CampaignSubmitProxy` → 6개 Gateway (Submit / Screening / Agreement / Settlement / ComingSoon / Event)
- `CampaignHiddenProxy` → `CampaignHiddenGatewayImpl`
- `CampaignFinalReviewProxy` → **Gateway 구현체가 이 레포에 없음** (story 복사/번역 도메인 재활용으로 추정)
- `CampaignCategoryProxy` → `CampaignCategoryQueryGatewayImpl` (외부 API)

### 주요 MyBatis Mapper XML (이 문서 범위)
- `CampaignMapper.xml` — 주력 조회
- `CampaignCommandMapper.xml` — hide/show/history/slack-data
- `CampaignContractMapper.xml` — 계약/정산정보/대표자
- `CampaignScreeningMapper.xml` — 심사 상태/로그
- `CampaignSubmitApprovalMapper.xml` — 제출/스탠딩바이
- `CampaignAgreementMapper.xml` — 약정
- `SettlementCommandMapper.xml` — 정산 초기화

### 접근 테이블 합계 (이 문서 모든 SQL의 합집합)

`Campaign`, `CampaignAutoOpen`, `CampaignCategoryMapping`, `CampaignLanguage`, `CampaignLabel`, `CampaignMarker`, `CampaignHiddenHistory`, `CampaignHashTag`, `CampaignNPhoto`, `CampaignScreening`, `CampaignScreeningLog`, `CampaignAgreement`, `CampaignAgreementHistory`, `CampaignAgreeConclusion`, `CampaignContractInfo`, `CampaignContractRepresentative`, `CampaignSubmitApproval(통합 Campaign)`, `RewardComingSoon`, `RewardComingSoonAutoOpen`, `RewardComingSoonStatusLog`, `SettlementSystem`, `RewardSettlementAdditionalCost`, `RewardSettlementRate`, `RewardSettlementStatusLog`, `UserProfile`, `BackingPayment`, `BankCode`, `PersonalVerificationResult`, `PhotoCommon`, `CodeValue`, `EventDay`
