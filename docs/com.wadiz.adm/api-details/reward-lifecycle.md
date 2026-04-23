# 리워드 펀딩 프로젝트 라이프사이클 (com.wadiz.adm)

## 1. 기록 범위

- `com.wadiz.web.progress.controller` 9개 + `com.wadiz.web.reward.screening.controller` 7개 + `reward.comingsoon` 2개 + `reward.openreservation` 2개 = **총 20개** 컨트롤러를 직접 열람해 구성.
- 프로젝트 개설부터 종료/환불/페널티까지 메이커센터가 아닌 **어드민(CS/운영) 측 컨트롤 플레인**만 다룸. 메이커가 스스로 하는 작업(스튜디오 업로드, 프로젝트 생성 마법사 등)은 본 문서 외.
- 관측 대상 체인: **Controller → Service → (MyBatis Mapper | FundingGateway REST)**. 프레임워크는 Spring MVC 3.2 / Java 8 / JSP, Swagger `io.swagger.annotations.*`로 API 설명 주석만 추가돼 있음.

## 2. 개요

- 어드민 라이프사이클 진입은 대부분 `progress/popCampaign*` JSP 팝업으로 시작 (`ModelAndView` + `@ModelAttribute` + `@RequestParam`).
- 상태 전이(이벤트 등록)는 `/reward/api/screenings/**`, `/reward/api/comingsoons/**`, `/reward/api/pd-screenings/**`, `/reward/api/campaigns/{id}/open-reservations/**` 같은 **내부 JSON API**로 POST/PUT 요청이 가는 분리 구조.
- 모든 이벤트 메서드는 `WEBSessionUtil.getUserId()`로 actor(어드민 유저)를 주입하고 응답은 `com.wadiz.api.reward.support.ResponseWrapper<T>`로 감싸서 리턴.
- 심사 상태는 세 레일로 분리: `CampaignScreening`(프로젝트/스토리/사후심의, single table w/ `ScrType` 컬럼 `'P'|'S'|'V'`) + `PdScreening` + `KCScreening`. 이벤트는 `CampaignScreeningEventType` / `PdScreeningEventType` enum으로 전이.
- 라이프사이클 외부효과(캠페인 공개/비공개, 부가서비스 승인·반려·수동신청, 최종심사 후처리)는 **`com.wadiz.api.funding`** REST를 `FundingGateway`로 bearer 토큰 호출 (`/api/internal/**`).

## 3. 컨트롤러 목록

| 컨트롤러 | base path (대표) | 단계 |
|---|---|---|
| `CampaignProgressController` | `progress/campaignList`, `progress/popCampaignDetails`, `progress/ajax*CampaignTag`, `progress/pause` | 전(全) 단계 허브 / 일시중지 |
| `CampaignScreeningController` | `progress/popCampaignScreening`, `progress/popCampaignKCScreening`, `progress/updateCampaignGroup` | 심사 메인 팝업 |
| `CampaignSettlementController` | `progress/popCampaignSettlement`, `progress/popCampaignErp`, `progress/*Optional*`, `progress/*AdditionalCost`, `progress/*AgreementFile` | 정산/약정서 |
| `CampaignPreReservationController` | `progress/pre-reservation`, `progress/pre-reservation/reset`, `progress/pre-reservation/excel-download` | 사전예약 |
| `CampaignEncoreController` | `progress/popCampaignEncore`, `progress/popCampaignEncoreExcel` | 앵콜(연속 오픈) |
| `CampaignPenaltyController` | `progress/popPenalty/{campaignId}`, `progress/ajaxProcessCancel` | 페널티 |
| `CampaignDeliveryController` | `progress/popCampaignShipping`, `progress/modifyDeliveryStatusToNotDelivered`, `.../ToDelivered` | 배송 |
| `CampaignAbortController` | `progress/popCampaignAbort`, `progress/campaignAbortSendTextMessage`, `progress/camapaignAbortDeleteData`, `progress/campaignAbortExcel` | 중단/환불 |
| `CampaignPersonalMessageController` | `progress/popCampaignMessage`, `/popCampaignMessageDetails`, `/putIsOptIn` | 1:1 문의 |
| `ScreeningApiController` | `/reward/api/screenings/campaigns/{id}/events/{eventType}`, `/with-feedback`, `/reset-campaign-marker`, `/story/reset/{resetKey}` | 심사 이벤트 |
| `ScreeningManagerApiController` | `/reward/api/screenings/managers`, `/campaigns/{id}/managers`, `/manager/check`, `/validate-sales-manager` | 심사 담당자 |
| `ScreeningRequirementApiController` | `/reward/api/screenings/campaigns/{id}/requirements/**` | 필수서류 업로드 |
| `ScreeningRequirementUiController` | `/reward/screenings/campaigns/{id}/requirements/files/{download|preview}` | 서류 다운로드/미리보기 |
| `ReminderNoticeApiController` | `/reward/api/remindernotice/campaigns/{id}`, `/seq/{seq}` | 메이커 독촉알림 |
| `PdScreeningApiController` | `/reward/api/pd-screenings/campaigns/{id}/events/{eventType}`, `/plan-types/{planType}`, `/new-plan/{approve|reject|manual-request}` | PD 심사 |
| `ScreeningKCApiController` | `/reward/api/kc-screenings/campaigns/{id}/requirements/**` | KC 인증 |
| `RewardComingSoonApiController` | `/reward/api/comingsoons/campaigns/{id}/{abort|apply|cancel-application}`, `/noti-application/{pause|resume}` | 오픈예정 |
| `RewardComingSoonUiController` | `/reward/campaign/popCampaignComingSoon`, `/reward/campaign/comingSoon/applicant/{id}` | 오픈예정 팝업 |
| `OpenReservationApiController` | `/reward/api/campaigns/{id}/open-reservations`, `/cancel` | 오픈 시각 예약 |
| `ComingSoonOpenReservationApiController` | `/reward/api/campaigns/{id}/comingsoon-open-reservations`, `/cancel` | 오픈예정 노출 예약 |

## 4. 단계별 흐름

### 4.1 사전예약 (Pre-Reservation)

- `CampaignPreReservationController.save` (controller:33) → `PreReservationService.savePreReservationInfo(userId, req)`; request DTO는 `ProjectPauseCreateRequest`와 동일 패턴의 JSON.
- `reset` (controller:46)은 설정 전체 초기화 — 구현은 `preReservationService.resetPreReservationInfo(userId, campaignId)`.
- 알림 신청자 엑셀 다운로드: `progress/pre-reservation/excel-download` (controller:60) → `preReservationService.getAll(campaignId)` 결과 `List<ComingSoonApplicantion>`을 `CCI.DWLD_EXCEL_FILE_NM_REWARD_PRE_RESERVATION_CONSENT_LIST` 포맷으로 `downloadExcel` 뷰 전달. `@Auditable(operationType = OperationType.EXCEL_DOWNLOAD, targetField = CCI.DWLD_EXCEL_DATA_LIST_PUT_STRING)` 로 감사 로그.
- 펀딩 **일시중지**는 사전예약과 별도지만 같은 단계에서 자주 쓰임: `CampaignProgressController.registerProjectPause` (controller:324) / `deleteProjectPause` (controller:338) — MyBatis `campaignPause-mapper.xml`의 `upsertCampaignPause` + `insertCampaignPauseHistory` 조합.
- 모델 바인딩용 drop-down은 `CampaignProgressController.campaignList` (controller:185) 가 `preReservationService.getConsentItems()` 호출해 동의 항목 리스트를 함께 전달.

### 4.2 오픈예정 (Coming Soon) & 오픈예약

- 신청/취소/중단:
  - `RewardComingSoonApiController.apply` (controller:58) → `RewardComingSoonService.apply(userId, campaignId, reason)`.
  - `cancelApplication` (controller:64) — 메이커 신청을 어드민이 취소.
  - `abort` (controller:50) — 운영자 직접 중단, 메이커 의사 무관.
- 알림 신청 **일시중지/해제**:
  - `/noti-application/pause` (controller:74): `comingSoonService.pauseNotiApplication`이 1을 리턴해야 성공으로 인정하고 이어서 `openReservationService.cancel(campaignId)` 까지 호출 (controller:78) — 알림 중단 시 오픈예약도 동시에 취소하는 연쇄 효과.
  - `/noti-application/resume` (controller:84): 동일 패턴. 오픈예약 복원은 자동이 아님 (관측상 resume 코드에는 openReservation 재설정 없음).
- 오픈시각 예약 변경/취소:
  - `OpenReservationApiController.change` (controller:36), `cancel` (controller:43) — 실제 오픈 시각(펀딩 시작) 조정.
  - `ComingSoonOpenReservationApiController.change` (controller:33), `cancel` (controller:43) — 오픈예정 노출 시작 시각 조정(오픈예정 페이지 공개 시각).
- 팝업 진입점: `RewardComingSoonUiController.popCampaignComingSoon` (controller:50)은 `OpenReservationAdapter.getOpenReservation`, `CampaignScreeningAdapter.getComingSoonScreening`, `RewardMakerStudioSubmitAdapter.getRewardMakerStudioSubmit`, `MakerAdapter.getUserByCampaignId`의 4개 internal adapter 결과를 단일 뷰 모델로 합산.
- 신청자 리스트: `comingSoonStatus` (controller:74) — `ComingSoonSearch` + 페이지네이션(`PaginationInfo`), `@Auditable(operationType = READ, targetField = "userIds")` 로 개인정보 열람 감사.
- 오픈예정 엑셀 다운로드: `RewardComingSoonApiController.applicantDownloadExcelDown` (controller:94) — 무 페이지네이션(`paging="N"`)으로 전체 받음.

### 4.3 심사 (Screening) — 3-rail 구조

- **프로젝트/스토리/사후심의(Revival)**: 이벤트 등록은 `ScreeningApiController.event` (controller:32) `POST /campaigns/{id}/events/{eventType}`. 피드백 동반 이벤트는 `feedback` (controller:42) `/with-feedback`.
- **PD 심사**: `PdScreeningApiController.event` (controller:36) + 신규요금제(STARTER/STANDARD) 전용 워크플로우:
  - `approveForNewPlan` (controller:62) — 승인 + 부가서비스(PD_CONSULTING) 자동 승인 호출.
  - `rejectForNewPlan` (controller:76) — 반려 + 부가서비스 반려.
  - `manualRequestForNewPlan` (controller:89) — PD 컨설팅 수동 신청.
  - 세 메서드 모두 `PdScreeningService` 를 거쳐 궁극적으로 `FundingGateway.approveAdditionalService` / `rejectAdditionalService` / `manualRequestPdConsulting` 내부 REST 호출.
- 요금제 저장: `PdScreeningApiController.savePackagePlan` (controller:55) `POST /campaigns/{id}/plan-types/{planType}` → `packagePlanService.save(userId, campaignId, planType)`.
- **KC 인증**: `ScreeningKCApiController.uploadFile` (controller:29), `delete` (controller:40), `getRequirementsDocumentTypes` (controller:50). 파일 식별자는 항상 `ScreeningDocumentFileHelper.decUploadSeq(encUploadSeq)`로 복호화(서버 외부에는 암호화된 seq만 노출).
- **필수 인증서류**: `ScreeningRequirementApiController.uploadFile` (controller:33). 메일 확인 토글 `isCheckedDocumentEmail` (controller:45) `POST .../is-checked-email`, KC 확인 토글 `isKCChecked` (controller:74) `POST .../is-kc-checked`.
- **파일 다운로드/프리뷰**: `ScreeningRequirementUiController.downloadObject` (controller:29) — UTF-8 인코딩 파일명 헤더(`Content-Disposition`) 직접 세팅, `@Auditable(FILE_DOWNLOAD)`. `previewObject` (controller:46)는 `downloadObject`로 위임(같은 바이트 스트림).
- **심사 담당자**:
  - 목록: `ScreeningManagerApiController.getAll` (controller:32) — `ScreeningType` 파라미터.
  - 등록: `save` (controller:37) — `ManagerSaveRequest`에 `campaignId`를 세팅 후 저장.
  - 확인: `getScreeningManager` (controller:48), 매출 담당자 유효성: `getVerificationSalesManager` (controller:55).
  - 사용되는 `ScreeningType`(CampaignScreeningController에서 나열):
    - `PROJECT`, `STORY`, `PD` — 3-rail 심사 담당자.
    - `PROJECT_MANAGER`, `MANAGER`, `LOCAL_EXPERT`, `SD`, `REVIVAL` — 부가 역할.
    - `PROJECT_PRO_SALES`, `PROJECT_BASIC_SALES`, `PD_SALES`, `SD_SALES` — 매출 담당자 변형.
- **독촉알림**: `ReminderNoticeApiController.save` (controller:42) — `ReminderNoticeMessageType` + `messageTitle` + `messageBody`로 메이커에게 발송. 목록/상세 각각 `getAll`/`get` (controller:29,36).
- **사후심의(Revival) 특수 동작**:
  - `resetRivivalCampaignMarker` (sic, controller:64) `POST /campaigns/{id}/reset-campaign-marker` — 사후심의 상태 마커 초기화(확인완료).
  - `resetStoryByVersion` (controller:72) `POST /story/reset/{resetKey}` — 특정 `RevivalHistoryId`로 Story 스냅샷 복구.
- 심사 팝업(`CampaignScreeningController.popCampaignScreening`, controller:124)은 **허용 이벤트 계산**을 `CampaignScreeningStatus.getAllowedAndDisplayedEventsByCampaignAndComingSoon(isOpen, type, comingSoonStatus)` (controller:167,173)에 위임 — 컨트롤러는 enum을 호출만.
- 같은 팝업에서 **STARTER/STANDARD 전용 부가서비스 관련 뷰 필드**까지 표현: `pdConsultingAdditionalService` (controller:156), `hasAssignedDirector` (controller:159), `consultingManagerName` (controller:162).
- KC 전용 팝업 분리: `popCampaignKCScreening` (CampaignScreeningController:235) — `kcScreeningService.getDocumentFiles(search)` + `getAll(campaignId)`.

### 4.4 오픈/진행 중 (Running)

- **진행 허브**: `CampaignProgressController.campaignList` (controller:144) — `CampaignSearch` 기반 페이지네이션(기본 currentPage=1, pageSize=15, `VIEW_PAGE_AND_API_PAGE_GAP=1`로 1-based↔0-based 변환). 주요 모델:
  - 프로젝트 태그(`campaignTagService.getUniqueTag("ADM_HASH")`), 카테고리(`categoryService.getAll/getFundingCategory`), 담당자 enum별 목록, 오픈예정/심사/PD심사 상태 enum, 패키지 플랜 타입, 메이커 클럽 등급, 법인 타입, 사전예약 동의항목 등.
  - `isDisableList=true` 면 목록 쿼리 스킵, 필터만 세팅 (수동 검색 첫 진입 때 사용).
  - 엑셀 다운로드 한도 `DEFAULT_LIMIT_ROW = 5000` (controller:137).
- **상세 팝업**: `CampaignProgressController.popCampaignDetails` (controller:214) 가 한 화면에서 다음을 aggregate:
  - 환불 플래그 `refundCommandService.getRefundOnOff`.
  - 수수료 `rewardFeeRateService.getSettlementRateInfo`.
  - 펀딩 보류여부 `campaignProgressService.isHoldingFunding`.
  - 메이커/파트너/오픈예정/오픈예약/심사/계약자/스튜디오 제출/환불정책/요금제/수혜 타입/정산 시스템 타입/배송국가.
- **카테고리 태그 관리**: `ajaxSaveCampaignTag` (controller:251), `ajaxDeleteCampaignTag` (controller:269), `ajaxGetCampaignTag` (controller:285) — 모두 `CommonAjaxResDto.toJson()` 포맷.
- **일시중지 API**: `progress/pause` POST (controller:322) / DELETE (controller:336).
- **정산 입력**: `CampaignSettlementController.popCampaignSettlement` (controller:92):
  - `campaignSettlementService.getCampaignSettlementPayMethodModifyLogs` — 분할/일괄 정산 토글(`PaymentMethodType.SPLIT`).
  - `fundingSettlementCampaignFeeGateway.getCampaignSettlementFees(campaignId)` (controller:133) → funding API에서 실제 수수료 구성 로드.
  - 종료 후(`endYn == 1`)만 `settlementService.getDefaultInfo` + `rewardHolidayDAO.selectRewardWorkingday` 로 최종결제일(+4영업일, `LAST_PAYMENT_RUNDAY = 4`) 계산 (controller:105-118).
  - 부가서비스 수수료: `campaignSettlementFeeTypeService.getAll(isDisplay=true, FeeTypeGroupType.getOptionalService())`.
  - 외부광고 수수료: `ExternalAdFeeType` enum에서 `BIZ_CENTER_DEFERRED_SETTLEMENT_10_FEE/_15_FEE` 제외(controller:131).
- **정산 팝업 하위 액션**:
  - `addCampaignOptioinalService` (오타 유지, controller:163) / `delCampaignOptionalService` (controller:184).
  - `addCampaignAdditionalCost` (controller:205) / `delCampaignAdditionalCost` (controller:226).
  - `addSettlementMemo` (controller:247).
  - 약정서: `downloadAgreementFile` (controller:271) / `uploadAgreementFile` (controller:292) / `modifyAgreementFile` (controller:303).
- **ERP 연동 팝업**: `popCampaignErp` (controller:152) — 현재는 빈 ModelAndView (JSP 내에서 ajax로 다시 조회하는 구조).
- **1:1 문의**: `CampaignPersonalMessageController.popCampaignMessage` (controller:20), 상세 `popCampaignMessageDetails` (controller:28), 차단 토글 `putIsOptIn` (controller:41) — `progress-mapper.xml`의 `selectCampaignPersonalMessageList/Details` + `updatePersonalMessageIsOptIn` 에 매핑.

### 4.5 앵콜·페널티 / 배송

- **앵콜(재오픈)**: `CampaignEncoreController.popCampaignEncore` (controller:27) — 빈 팝업 JSP, 실제 리스트는 다음 엑셀 다운로드로. `popCampaignEncoreExcel` (controller:35) → `progressService.getCampaignEncoreParticipantsList(campaignId)`. MyBatis는 `progress-mapper.xml`의 `selectCampaignEncoreParticipantsList`.
- **페널티**: `CampaignPenaltyController.popPenalty` (controller:30) — `isRead` 파라미터로 읽기 전용/수정 가능 구분. 처리 취소 `ajaxProcessCancel` (controller:41)는 `PenaltyInfo`에 세션 userId를 `setUpdateId`로 주입 후 `campaignPenaltyService.processCancel` 호출. `CampaignPenaltyService`는 `funding.core.inventory.constant.CampaignStatus`를 import해 펀딩 코어 enum과 연계.
- **배송**:
  - `popCampaignShipping` (CampaignDeliveryController:32) — `getMakerCertificationInfo`, `getCampaignDefaultInfo`, `getCampaignShippingList`, `getShippingUpdateList`, `refundPolicyService.get` 5개 정보 표시.
  - 개별 서포터(실제 후원 건 = `backingPaymentId`) 단위 상태 토글: `modifyDeliveryStatusToNotDelivered` (controller:50) / `modifyDeliveryStatusToDelivered` (controller:64) — MyBatis `updateRewardDeliveredStatusN/Y`.

### 4.6 중단·환불 (Abort)

- `CampaignAbortController.popCampaignAbort` (controller:46)는 단일 팝업에 다음을 모두 aggregate:
  - `campaignAbortService.getAbortStatus(campaignId)` — 현재 중단 단계.
  - `campaignAbortService.getCampaignAbortLog(campaignId)` — 액션 이력.
  - `campaignSettlementService.getSettlementSystem(campaignId)` — 정산 시스템 타입(중단 시 경로 분기에 사용).
  - 혜택 사용 카운트/이력: `benefitedUserService.getUsingCouponCount`, `getUsingPointCount`, 관련 포인트/쿠폰 로그.
  - 페널티: `campaignPenaltyService.isPenalty`, `getPenaltyHistory`.
  - `CANCEL_PROCESS_LIMIT` 상수를 모델에 노출 — 동시 처리 건수 가드를 뷰에서 비교.
- **서포터 일괄 문자 발송**: `campaignAbortSendTextMessage` (controller:67) → `CampaignAbortService.sendMessageToSupporter(campaignId, messageBody)` 가 `CampaignAbortResult` 리턴 (결과 건수·에러 집계).
- **관련 데이터 삭제**: `camapaignAbortDeleteData` (오타 유지, controller:75) — `CampaignAbortActionType` enum으로 삭제 범주 지정. 같은 enum이 엑셀 다운로드 구분자(`EXCEL_POINT`, `EXCEL_COUPON`)도 겸용.
- **포인트/쿠폰 사용내역 엑셀**: `campaignAbortExcel` (controller:82) — `excelType` 파라미터 문자열로 분기.

## 5. 주요 MyBatis XML (발췌)

- `src/main/resources/sqls/reward/screening/screening-mapper.xml` (namespace `com.wadiz.web.reward.screening.repository.ScreeningRepository`):
  - `<select id="findAll">` (xml:4): 한 테이블을 3번 self-join — `CampaignScreening PS LEFT JOIN CampaignScreening SS ON PS.CampaignId = SS.CampaignId AND PS.ScrType='P' AND SS.ScrType='S'` 그리고 `RS.ScrType='V'` 까지. 단일 튜플로 프로젝트/스토리/사후심의 상태를 한 번에 뽑음.
  - `<select id="findById">` (xml:45) — 단건 조회 동일 구조.
  - `<insert id="save">` (xml:69): `INSERT INTO CampaignScreening(ScrType, CampaignId, StatusCode, Registered, StatusUpdated) ... ON DUPLICATE KEY UPDATE StatusCode=#{statusCode}, StatusUpdated=now()` — 상태 upsert.
- `src/main/resources/sqls/reward/screening/screening-manager-mapper.xml`: `findAllByScreeningType`, `findNameByCampaignIdAndScreeningType`, `findByCampaignIdAndScreeningType`, `save` — 네 개로 `ScreeningType`별 담당자 조회/저장만.
- `src/main/resources/sqls/reward/screening/kc-screening-mapper.xml`: `screeningRewardItemResult`, `kcItemsMap`, `findAll`, `findById`, `insert`, `update`, `findRequireTypeById`, `findKcDocumentFileById`, `updateDeleted` — KC 서류 메타 + 삭제 플래그 전용.
- `src/main/resources/sqls/progress/progress-mapper.xml`: `selectCampaignDefaultInfo`, `selectCampaignShippingList`, `selectCampaignCategory`, `selectCampaignPersonalMessageList/Details`, `updatePersonalMessageIsOptIn`, `selectShippingUpdateList`, `selectMakerCertificationInfo`, `selectCampaignEncoreParticipantsList`, `updateRewardDeliveredStatusY/N` — 한 파일에서 상세팝업/1:1메시지/배송/앵콜 리스트를 모두 커버.
- `src/main/resources/sqls/progress/campaignAbort-mapper.xml`:
  - `selectContributionCount`, `selectFundingCount` — 환불 대상 집계.
  - `existsSplitPayment` — 분할결제 존재 여부(중단 경로 분기).
  - `selectCancelFundingTarget` — 취소 대상 후원 목록.
  - `selectCampaignAbortLog` / `insertCampaignAbortLog` — 중단 이력.
  - `deleteContribution` (id는 `<select>` 네이밍이지만 삭제용 SQL — 관측된 네이밍 불일치).
- `src/main/resources/sqls/progress/campaignPause-mapper.xml`: `selectCampaignPause`, `upsertCampaignPause`, `deleteCampaignPause`, `insertCampaignPauseHistory` — 현재상태와 이력을 분리 저장.

## 6. 외부 연동

### 6.1 com.wadiz.api.funding (REST, 내부 토큰)

- 게이트웨이 객체: `com.wadiz.web.reward.adapter.external.fundingapi.FundingGateway` (전체 337줄). 헤더는 `bearer <internalToken>` (`@Value("#{file['funding_internal_api_token']}")`).
- 호출 엔드포인트 (모두 `/api/internal/*`):
  - **부가서비스 승인** `PUT /additional-services/{projectNo}/services/{serviceCode}/approve` — `FundingGateway.approveAdditionalService` (FundingGateway.java:40).
  - **부가서비스 반려** `PUT /additional-services/{projectNo}/services/{serviceCode}/reject` — `rejectAdditionalService` (FundingGateway.java:81).
  - **PD 컨설팅 수동 신청** `PUT /additional-services/{projectNo}/services/pd-consulting/manual-request` — `manualRequestPdConsulting` (FundingGateway.java:122).
  - **최종심사 후처리** `POST /campaign-final-review/{projectNo}/process` — `processFinalReview` (FundingGateway.java:156). 번역 상태 `translationStatus="E00"` 하드코딩.
  - **캠페인 비공개** `POST /campaigns/{campaignId}/hidden` — `hideCampaign` (FundingGateway.java:258).
  - **캠페인 공개** `POST /campaigns/{campaignId}/shown` — `showCampaign` (FundingGateway.java:295).
  - **리워드 변경이력**:
    - `GET /reward-change-logs/campaigns/{id}/rewards/{rewardId}/summaries` — `getRewardChangeLogSummaries` (FundingGateway.java:193).
    - `GET /reward-change-logs/campaigns/{id}/summaries` — `getCampaignRewardChangeLogSummaries` (FundingGateway.java:215).
    - `GET /reward-change-logs/{logId}` — `getRewardChangeLogDetail` (FundingGateway.java:237).
- 실패시 `ServiceOperationResponse.error("EXCEPTION", ...)` 로 감싸서 리턴 — 호출자는 null/isSuccess 체크로 분기.
- 호출자 매핑:
  - `PdScreeningApiController.approveForNewPlan/rejectForNewPlan/manualRequestForNewPlan` → `PdScreeningService` → `FundingGateway.approve/reject/manualRequest`.
  - 캠페인 숨김은 본 문서 범위 외의 다른 컨트롤러에서 사용.
- 정산 수수료 로딩은 별도 게이트웨이: `FundingSettlementCampaignFeeGateway.getCampaignSettlementFees` (CampaignSettlementController:133)가 `CampaignSettlement` 객체를 funding 측에서 가져옴.

### 6.2 com.wadiz.api.reward (공유 라이브러리)

- HTTP 아님 — 같은 네트워크 위치의 리워드 API 프로젝트에서 생성된 **jar 의존성**을 함께 끌어쓰는 구조.
- `com.wadiz.api.reward.support.ResponseWrapper`, `com.wadiz.api.reward.dto.PageSearch/Pageable/Sort`, `com.wadiz.api.reward.dto.coupon.CouponTransactionDto` (BenefitedUserService 등에서).

### 6.3 com.wadiz.wave.user (레거시 유저)

- 라이프사이클 컨트롤러 20개 내에서는 **직접 사용 없음**.
- 참고로 같은 어드민 WAR 내 별도 도메인에선 사용 중 (`kr/wadiz/membership/*`, `kr/wadiz/account/*`, `com/wadiz/web/wevent/*`, `com/wadiz/core/waccount/*`, `com/wadiz/web/waccount/*` 등 — `com.wadiz.wave.user.*` 패키지 import).

### 6.4 내부 어댑터(동일 WAR)

- `com.wadiz.web.reward.adapter.internal.*` 에 20여 개 어댑터가 있고, 라이프사이클 관련만 추려보면: `CampaignInternalAdapter`, `CampaignScreeningAdapter`, `CampaignSettlementInternalAdapter`, `ComingSoonAdapter`, `OpenReservationAdapter`, `MakerAdapter`, `MakerCommunicationAdapter`, `RewardMakerStudioSubmitAdapter`, `RefundAdapter`, `RefundPolicyAdapter`, `PackagePlanAdapter`, `ScreeningRequirementAdapter`, `SettlementStatusAdapter`, `ShipmentAdapter`.
- 외부 어댑터(`com.wadiz.web.reward.adapter.external.*`)에는 REST 호출이 들어있는 `FundingGateway` 외에 `CampaignAdapter`, `CampaignSettlementAdapter`, `PointAdapter`, `BackingPaymentAdapter`, `SatisfactionAdapter`, `UserAdapter`, `SettlementV1Adapter`, `NotificationAdapter`, `NormalMailClient`, `BankCodeAdapter`, `MakerProfileAdapter`, `PartnerAdapter`, `FileAdapter` 등 다수.

## 7. 경계

- 어드민 측 **컨트롤 플레인만** 기록. 실제 후원/결제/정산 집행은 `com.wadiz.api.funding` 이 소유 — 본 컨트롤러들은 그쪽 API를 호출해 상태를 갱신하거나, 공유 DB의 메타 테이블(CampaignScreening, CampaignAbortLog 등)을 upsert할 뿐.
- 모든 상태전이는 `WEBSessionUtil.getUserId()`가 전제 — 세션 없는 호출은 어드민 프레임워크가 거절함(인증/권한 레이어 자체는 본 문서 범위 외).
- 상태 전이 유효성(전이 허용 여부)은 컨트롤러가 아니라 **enum + 서비스**가 캡슐화: `CampaignScreeningStatus.getAllowedAndDisplayedEventsByCampaignAndComingSoon`, `PdScreeningStatus.getAllowedAndDisplayedEventByCampaignAndPlan` 등. 뷰는 enum이 내뿜는 허용 이벤트만 렌더.
- `CampaignAbortActionType` enum은 "중단 액션 종류"와 "엑셀 다운로드 구분자"를 겸용(`CampaignAbortController.campaignAbortExcel`:86의 `EXCEL_POINT`/`EXCEL_COUPON` 케이스) — 확장 시 의미 중첩 주의.
- 일부 URL 오타가 그대로 계약됨: `progress/camapaignAbortDeleteData`, `progress/addCampaignOptioinalService`. JSP 쪽과 맞물려 임의 변경 불가 — 마이그레이션 시 별도 alias 필요.
- `ScreeningApiController.resetRivivalCampaignMarker`(오타: Rivival) 메서드명과 URL `reset-campaign-marker` 의 의미가 "사후 심의 확인완료"인 것도 네이밍 불일치 포인트.
- 컨트롤러 일부는 **빈 ModelAndView만 리턴**(`CampaignEncoreController.popCampaignEncore`, `CampaignSettlementController.popCampaignErp`) — 실제 데이터는 JSP 내 AJAX 재호출로 채움. 상태 흐름 추적 시 해당 JSP와 함께 봐야 함.
- 본 문서 범위 외:
  - 메이커 스튜디오(`RewardMakerStudioSubmitService`) 자체의 CRUD — 어댑터 참조만 기록.
  - 환불 실행 자체 (`RefundCommandService`) — 본 문서는 진입점만 표시.
  - 리워드 아이템/패키지 플랜 CRUD — 팝업 뷰 데이터 소스로만 등장.
