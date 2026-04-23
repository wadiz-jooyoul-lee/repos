# 정산 · 결제 · 쿠폰 · 포인트 · 증권 컨트롤러 (com.wadiz.adm)

> 레거시 어드민(`com.wadiz.adm`, Spring 3.2 / Java 8 / JSP)의 **돈 흐름(Money-flow)** 영역 컨트롤러 정리.
> Reward(리워드 펀딩) 정산/결제·쿠폰·포인트와 Equity(증권형) 청약/수수료/쿠폰/멤버십까지 한 파일에서 본다.

---

## 1. 기록 범위

- 범위: `src/main/java/com/wadiz/web/{reward/{settlement,fundingsettlement,payment,coupon},settlement,supporterClubSettlement,payment,point,equity}/controller` + `src/main/java/kr/wadiz/coupon/controller` 하위 컨트롤러 약 **50개**.
- 대상 URL prefix: `/reward/api/settlements/**`, `/reward/api/payments/**`, `/reward/api/coupons/**`, `/reward/settlement/**`, `/reward/coupon/**`, `/settlement/**`, `/payment/**`, `/ftpayment/**`, `/point/**`, `/v2/account/coupon/**`, `/equity/**`, `/premiumMembership/**`, `/wcoupon/**`, `/wcouponDetail/**`, `/ftcampaign/**`, `/mastergroup/**`, `/app/supporter-club-settlement/**`.
- 제외: 스케줄러·배치·이벤트 컨슈머·어드민 로그인/권한(`account/*`) — 이 문서는 "사람이 화면에서 누르는 돈 관련 엔드포인트"만.

## 2. 개요 (운영 금융 전반)

`com.wadiz.adm` 에서 돈이 흐르는 방향은 크게 **3갈래**다:

1. **리워드(Reward) 펀딩 사이드** — 서포터가 결제하고 펀딩이 성공하면 와디즈가 메이커에게 정산해줘야 한다.
   - **결제(지급/환불)**: `/payment/*`, `/reward/payment/*` — 서포터 결제 내역 조회, 강제 취소/환불, 매출 리포트.
   - **정산(Settlement)**: `/reward/api/settlements/**`, `/reward/settlement/**`, `/settlement/rewardList` — 캠페인별 수수료(`fee`), 상태(`status`: A10 접수/A20 검수/WAIT/HOLD/STOP), 결과(amount, tax-invoice, bank upload format), 서브몰(SubMall) NICEPAY 연동, 미수금 환수(Clawback), 사전정산(Advanced Settlement), 예상정산(Estimated).
   - **쿠폰/포인트 지급·환불**: `/reward/api/coupons/**`, `/point/**` — 쿠폰 템플릿/발급/사용내역, 포인트 템플릿/지급/회수.
2. **증권형(Equity) 사이드** — KRX·법무법인·회계법인이 엮인 청약형 투자. 수수료·청약 결제·가상계좌·이벤트쿠폰·프리미엄멤버십·W9 이 모두 이 도메인 안에 있다.
   - `/equity/**` (레거시 리라이트, `EquityCampaign/Business/Stage/Publish/Collection/…`), `/ftcampaign/**` (구버전 — 1700줄대 god-controller `WEBEquityController`), `/premiumMembership/**`, `/wcoupon/**` (증권형 쿠폰 — 리워드 쿠폰과 다른 체계), `/payment/virtualAccount*`, `/payment/offer*`.
3. **서포터클럽 / 강의** — 주변 도메인. `/app/supporter-club-settlement/sales`, `/payment/lectureInauguratePayment*` (VOD/강의 결제).

공통 특징:
- **프록시 2종**: `SettlementProxyApiController` (`/reward/settlement/proxy/api/**`) 와 `SettlementClawbackProxyApiController` (`/reward/api/v1/settlements/clawback/**`) 가 별도 정산/환수 시스템으로 요청을 통과시킨다 → 실제 로직은 **외부 funding-settlement 서버** (`funding_settlement_api_base_uri` 프로퍼티).
- 대부분 `@Controller` + `@ResponseBody` 또는 `Model` 리턴(JSP). 신규 것만 `@RestController` 스타일.
- URL 네이밍 혼재: `ajaxXxx`, `popXxx` (JSP 팝업), `/api/`, `downloadExcelDown` 등 세대가 섞여있음.

## 3. 컨트롤러 목록 (도메인별)

### 3.1 Reward Settlement (`/reward/api/settlements/**`, `/reward/settlement/**`)
| 컨트롤러 | 경로 prefix | 책임 |
|---|---|---|
| [`CampaignSettlementApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/CampaignSettlementApiController.java):23 | `/reward/api/settlements` | 캠페인 정산 기본 조회(fee-version), 상태 A10/A20 전이, 결제수단 정보/변경 |
| [`CampaignSettlementFeeApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/CampaignSettlementFeeApiController.java):24 | `/reward/api/settlements/fees` | 캠페인 수수료/추가비용(`additionalCost`) 조회 |
| [`CampaignSettlementUiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/CampaignSettlementUiController.java):34 | `/reward/settlement` | 정산 관리 JSP: list / popDetail / popEditFee / popEditSettlement / popEditRefund / popEditPreview / estimatedAmountList / clawback |
| [`SettlementStatusApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementStatusApiController.java):30 | `/reward/api/settlements` | statuses 조회/변경(hold/stop/force), `status/WAIT` 전환, 상태 변경 로그 |
| [`SettlementSearchApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementSearchApiController.java):36 | `/reward/api/settlements/search` | 정산 검색, 엑셀/은행업로드포맷/신탁/정산 엑셀 다운로드 |
| [`SettlementResultApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementResultApiController.java):26 | `/reward/api/settlements/campaigns/{id}/**` | 수수료금액·결제금액·환불금액·미수금·정산파일(advanced/final) 이력 조회 및 생성 |
| [`SettlementModifiedFeeApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementModifiedFeeApiController.java):22 | `/reward/api/settlements/modified-fees` | 수수료 수기 보정(등록/조회/변경로그) |
| [`SettlementSubMallApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementSubMallApiController.java):34 | `/reward/api/settlements/submall/nicepay` | NICEPAY 서브몰: 계좌불일치 캠페인, 등록CSV/pay-request CSV/등록확인 CSV 다운로드 |
| [`SaleSettlementApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SaleSettlementApiController.java):29 | `/reward/api/settlements/sales` | 판매정산 엑셀/프로젝트 엑셀 다운로드 |
| [`EstimatedSettlementApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/EstimatedSettlementApiController.java):16 | `/reward/api/settlements/estimatedAmounts` | 예상 정산금액 검색 |
| [`AdvancedSettlementApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/AdvancedSettlementApiController.java):22 | `/reward/api/settlements/campaigns/{id}/advanced-settlements` | 사전정산 조회/신청/취소, apply-status |
| [`TaxInvoiceIssuanceApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/TaxInvoiceIssuanceApiController.java):16 | `/reward/api/settlements/taxinvoice-issuance` | 세금계산서 발행/취소 (type별) |
| [`CampaignContractorApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/CampaignContractorApiController.java):22 | `/reward/api/settlements/campaigns/{id}/contractors` | 계약자(실명·사업자) 수동검증/취소 |
| [`SettlementProxyApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementProxyApiController.java):23 | `/reward/settlement/proxy/api/**` | **정산 외부서버 프록시** (adminId/adminName 헤더 부여 후 `funding_settlement_api_base_uri` 로 forward) |
| [`SettlementClawbackProxyApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/settlement/controller/SettlementClawbackProxyApiController.java):40 | `/reward/api/v1/settlements/clawback` | 미수금 환수 histories/do/return/status (Outstanding Clawback Gateway) |
| [`FundingSettlementSubMallController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/fundingsettlement/controller/FundingSettlementSubMallController.java):16 | `/reward/api/funding-settlement/submall-ids` | (신)펀딩정산 submall-id 조회 |
| [`SupporterClubSettlementController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/supporterClubSettlement/controller/SupporterClubSettlementController.java):9 | `/app/supporter-club-settlement/sales` | 서포터클럽 매출 리스트 (단일 메서드) |
| [`WEBSettlementRewardController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/settlement/controller/WEBSettlementRewardController.java):46 | `/settlement` | 레거시 JSP: rewardList / popRewardDetail / excel / bankUploadFormat / taxInvoice / ajaxForce/ChangeStatus / settlementRewardResult / InvoiceRegistered / CorpType / Memo |

### 3.2 Reward Payment (서포터 결제)
| 컨트롤러 | 경로 | 책임 |
|---|---|---|
| [`WEBPaymentController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/payment/controller/WEBPaymentController.java):51 | `payment/paymentMgrList`, `payment/popPaymentDetail`, `payment/popPaymentRefund`, `payment/downloadExcelDown`, `payment/emailSend`, `payment/smsSend`, `payment/ajaxCancelPayment`, `payment/popExcelDownload` | 결제내역 관리/환불/엑셀·메일·SMS 발송 |
| [`WEBRewradPaymentController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/payment/controller/WEBRewradPaymentController.java):31 | `/payment/rewardPaymentList`, `/rewardPaymentDownloadExcel`, `/rewardPaymentHistoryDetail` | 리워드 결제 리스트/엑셀/상세 (sic: `Rewrad` 오탈자) |
| [`WEBLecturePaymentController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/payment/controller/WEBLecturePaymentController.java):29 | `payment/lectureInauguratePayment*`, `payment/popLecturePayment*`, `ftpayment/ajaxPaymentCancel`, `payment/updateLectureEnterYn`, `payment/ajaxInsertSchoolForm` | 강의/입학 결제 — 엑셀 다운·취소·학교 폼 (VOD/강의 상품용) |
| [`PaymentSummaryController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/payment/controller/PaymentSummaryController.java):34 | `/reward/payment/summarySearch`, `/searchPaymentApprovalHistoryDownload`, `/makerSalesReport`, `/makerSalesReport/excel/download` | 결제 집계/승인이력 엑셀, 메이커 매출 리포트 |
| [`BackingPaymentRefundApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/payment/controller/BackingPaymentRefundApiController.java):18 | `/reward/api/payments/refunds/{backingPaymentId}/required-cancel-amounts` | 백킹 결제 필요 취소금액 조회 (부분환불 계산) |
| [`BackingPaymentCouponApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/payment/controller/BackingPaymentCouponApiController.java):17 | `/reward/api/payments/coupons/summation` | 결제건별 쿠폰 사용 합계 |

### 3.3 Reward Coupon (`/reward/api/coupons/**`, `/reward/coupon/**`)
| 컨트롤러 | 경로 | 책임 |
|---|---|---|
| [`CouponTemplateApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/CouponTemplateApiController.java):28 | `/reward/api/coupons/templates` | 템플릿 CRUD/summations/coupons/qty |
| [`CouponIssueApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/CouponIssueApiController.java):25 | `/reward/api/coupons/issues` | 발급조회·코드엑셀·발급(coupon-code/direct), purpose-types |
| [`CouponTransactionApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/CouponTransactionApiController.java):17 | `/reward/api/coupons/transactions/types/withdraw` | 쿠폰 회수(WITHDRAW) |
| [`CouponTransactionSummationController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/CouponTransactionSummationController.java):29 | `/reward/api/coupons/transaction-summation` | 트랜잭션 합계/엑셀 |
| [`CouponUiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/CouponUiController.java):35 | `/reward/coupon` | `issue/{key}/code/excel`, `template/{no}/coupon`, `issue/direct/format` (엑셀 포맷) |
| [`rewardCouponViewController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/rewardCouponViewController.java):9 | `/reward/coupon/**` (JSP 뷰) | 다중 뷰 매핑 (class 이름 소문자 시작 — 레거시) |
| [`rewardCouponAccountingViewController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/reward/coupon/controller/rewardCouponAccountingViewController.java):9 | 회계용 쿠폰 뷰 |
| [`UserCouponTemplateController`](../../../com.wadiz.adm/src/main/java/kr/wadiz/coupon/controller/UserCouponTemplateController.java):26 | `/v2/account/coupon/templates`, `/template/issue/{key}`, `/template`, `/template/{no}` | v2 통합 쿠폰 템플릿 CRUD (`kr.wadiz.coupon` 패키지 — 신규) |

### 3.4 Point (`/point/**`)
| 컨트롤러 | 경로 | 책임 |
|---|---|---|
| [`WEBPointController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/point/controller/WEBPointController.java):48 | `/point/template*`, `/addPointTemplate`, `/ajaxRegisterPointTemplateInfo`, `/paymentPoint`, `/ajaxCheckImport{File}`, `/ajaxPaymentPoint`, `/paymentBulkPoint`, `/ajaxPaymentBulkPoint`, `/format/exceldown`, `/bulkFormat/exceldown`, `/popTemplateSummation`, `/issueList*`, `/popIssueDetail`, `/popSearchTemplateByName`, `/transactionList*`, `/popTransactionDetail`, `/ajax/{userId}[/transactions]`, `/withdraw` | 포인트 템플릿 관리, 단건/벌크 지급, 이슈/트랜잭션 조회, 회수 |
| [`PointApiController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/point/controller/PointApiController.java):16 | `/point/api/issue-reason-types` | 포인트 지급 사유 enum 조회 (REST 보조) |

### 3.5 Equity — 신규 `/equity/**`
| 컨트롤러 | 경로 | 책임 |
|---|---|---|
| [`EquityBusinessController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityBusinessController.java):46 | `/equity/business` | 발행사(사업자) 관리: manageList/Details/popBusinessInfo/popMember/popNews/CEO, 뉴스 키워드 등록·스크래핑 |
| [`EquityCampaignController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityCampaignController.java):53 | `/equity/campaign` | 증권형 캠페인 ± 심사: preCampaignList, campaignDetails, popEquityInfo/popStage/popExternalLink/popEquityAuth/popMemo/popHistory/popApprovalFeedback, **status 변경**(back/change/screeningConfirm/fundingConfirm), `campaignRefundAll`(전체환불), fees(basic/rate) 엑셀, smartsheet sync |
| [`EquityCampaignPublishController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityCampaignPublishController.java):48 | `/equity/campaign/publish` | 증권신고서 스테이지: popPublishStage/popEquityFee, saveFactCheck/CampaignFee/Incorporation/LawFirm/AccountingFirm/Increase/Check/FeeDate, mail preview/send |
| [`EquityStageController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityStageController.java):29 | `/equity/stage` | saveStatus, modificationRequest, preparingDescriptionApproval, feedback/{seq}, sendPress |
| [`EquityStagePublishController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityStagePublishController.java):41 | `/equity/stage/publish` | 스테이지별 상태 저장 13종: Description/Brokerage/Incorporation/LawFirmContract/AccountingFirmContract/Securities/IncreaseAsset + 수수료 스테이지(Basic/LawFirm/RateFee/AccountingFirmFee) + 각 Deposit, mail preview |
| [`EquityCollectionController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityCollectionController.java):40 | `/equity/collections` | 컬렉션(캠페인 큐레이션) CRUD, 사진업로드, 캠페인 추가/제거 |
| [`EquityDownloadExcelController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityDownloadExcelController.java):31 | `/equity/download/excel` | assignResult / condensedStatement (약식서류) / descriptionList 엑셀 |
| [`EquityFileController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityFileController.java):39 | `/equity/file` | 파일업로드(business/campaign/etc/financial), 템플릿 pdf/excel 다운, validationAllFiles, photoCopyAll |
| [`EquityNewsController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityNewsController.java):16 | `/equity/news*` | 뉴스 리스트/상세/상태/수정요청 |
| [`EquityNoticeController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityNoticeController.java):31 | `/equity/notice/risk/mail` | 투자자 리스크 메일 발송 |
| [`EquityW9ContentsController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/EquityW9ContentsController.java):30 | `/equity/w9/contents/order` | W9 콘텐츠 순서 관리 (미국 세무) |
| [`PremiumContentsBoardController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/controller/PremiumContentsBoardController.java):19 | `/equity/premium/contents/list` | 프리미엄 콘텐츠 게시판 |

### 3.6 Equity — 구버전 `/ftcampaign/**`, `/wcoupon/**`, `/payment/*` (domain 하위)
| 컨트롤러 | 경로 | 책임 |
|---|---|---|
| [`WEBEquityController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/ftcampaign/controller/WEBEquityController.java):87 | `ftcampaign/**` (**1700+줄 god-controller**) | 구증권 캠페인 전체: list/detail/excel, IR 피드백 코멘트 CRUD, 캠페인 승인/반려/연기, 관리자·모집·카테고리·증권타입·예치금 수정, 로고/사진/태그/비즈정보/시장분석/마일스톤/재무/전략 등 프론트 콘텐츠 전체 수정 ajax, 오픈테스트/오픈, 프리미엄유저 apply/regist/cancel/modify, 파일업로드(bzattach/eligibility/cpattach/fsattach/invest), **청약(equityAssign)** list/detail/엑셀, ajaxEquityAssign/AssignCancel, 계좌검증(bank/realtime), 운영·재시도·알림 재발송 |
| [`WEBLectureInaugurateController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/ftcampaign/controller/WEBLectureInaugurateController.java):28 | `ftcampaign/lecture*` | 청약 강의(lectureInaugurate) CRUD/연관/엑셀 |
| [`WEBCouponController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/wcoupon/controller/WEBCouponController.java):49 | `wcoupon/couponList`, `randomCouponView`, `randomCoupon`, `distributeCoupon[List]`, `exceldownload`, `distribute/exceldownload`, `couponPoolHis` | 증권형 이벤트 쿠폰(랜덤/배포) 발급·풀관리 |
| [`WEBCouponDetailController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/wcoupon/controller/WEBCouponDetailController.java):39 | `/wcouponDetail/*` | 쿠폰 상세·사용내역·**페이백**(ajaxExecutePayBack / paybackList / downloadcouponPaybackListDown / ajaxModifyPayback / dwonloadConditionPaybackChargeInfo — sic 오탈자 다수) |
| [`WEBEventCouponController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/wcoupon/controller/WEBEventCouponController.java):39 | `/wcoupon/event/*` | couponList/couponuseView/paybackView |
| [`WEBVirtualAccountController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/payment/controller/WEBVirtualAccountController.java):52 | `/payment/virtualAccountTransactionLogList`, `/ajaxUpdateVirtualAccountStatus`, `/virtualaccountamount/downloadExcel` | 가상계좌 입금내역·상태변경·엑셀 |
| [`WEBOfferPaymentController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/payment/controller/WEBOfferPaymentController.java):33 | `/payment/offerPaymentList`, `/popOfferPaymentDetail`, `/popOfferPaymentNiceCheck`, `/popOfferPaymentApproval`, `ajaxModifyUserIvstSt/AssignQty/Acoount/AccountCheck/EditableAccountUpdate/RealtimeAccountCheck`, `popMultiSelectSmsSend` | 청약 결제/승인: 사용자 투자상태·배정수량·계좌수정·실시간 계좌검증·SMS 단체발송 |
| [`WEBMasterGroupController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/mastergroup/controller/WEBMasterGroupController.java):33 | `/mastergroup/**` | 마스터(전문가) 그룹: 회원리스트/신청승인/거절/활동관리/계좌변경/정지/재개/히스토리/유형변경/메모/엑셀/추천 |
| [`PremiumMembershipController`](../../../com.wadiz.adm/src/main/java/com/wadiz/web/equity/domain/premiummembership/controller/PremiumMembershipController.java):32 | `/premiumMembership/getList`, `/popPremiumMembershipDetail`, `/cancle`(sic), `/downloadExcel` | 프리미엄 멤버십 가입자 관리/취소 |

## 4. 도메인별 요약

### Settlement (리워드 정산) — 주요 엔드포인트

SettlementStatus (`SettlementStatusApiController.java`:30):
- `GET /reward/api/settlements/statuses/{status}` — 정산 상태 주요 단계 확인(`:42`).
- `GET /reward/api/settlements/campaigns/{id}/statuses` — 현재 상태 조회(`:49`).
- `POST /reward/api/settlements/campaigns/{id}/statuses/hold` — 일시중지/해제(`:56`).
- `POST /reward/api/settlements/campaigns/{id}/statuses/stop` — 완료처리(`:63`).
- `POST /reward/api/settlements/campaigns/{id}/statuses` — 다음 상태 전이(`:70`).
- `POST /reward/api/settlements/campaigns/{id}/statuses/{status}/force` — 강제 변경(`:90`).
- `PUT  /reward/api/settlements/campaigns/{id}/status/WAIT` — 펀딩금 반환 가능 상태(`:108`).
- `GET  /reward/api/settlements/campaigns/{id}/statuses/logs` — 변경 이력(`:132`).

SettlementResult (`SettlementResultApiController.java`:26):
- `GET /reward/api/settlements/campaigns/{id}/fee-amounts` — 수수료 금액(`:39`).
- `GET /reward/api/settlements/campaigns/{id}/payment-amount` — 결제 금액(`:59`).
- `GET /reward/api/settlements/campaigns/{id}/settlement-amounts/types/{settlementType}` — 정산금 지급(`:66`).
- `GET /reward/api/settlements/campaigns/{id}/refund-amounts/{refundTimeType}` — 환불(`:74`).
- `GET /reward/api/settlements/campaigns/{id}/receivable-amount` — 미수금(`:82`).
- `GET /reward/api/settlements/campaigns/{id}/fixedDates` — 확정일자(`:89`).
- `GET /reward/api/settlements/campaigns/{id}/advanced-settlement-file-history` — 사전정산 이력(`:96`).
- `GET /reward/api/settlements/campaigns/{id}/final-settlement-file-history` — 최종 정산 내역서(`:103`).
- `POST /reward/api/settlements/campaigns/{id}/settlement-file-create` — 내역서 즉시 생성(`:110`).

SettlementSearch (`SettlementSearchApiController.java`:36):
- `POST /reward/api/settlements/search` — 조건 검색(`:48`).
- `POST /reward/api/settlements/search/excel` — 검색결과 엑셀(`:60`).
- `POST /reward/api/settlements/search/bankUploadFormat` — 은행 업로드 포맷 엑셀(`:77`).
- `POST /reward/api/settlements/search/trust/excel` — 신뢰보상 엑셀(`:95`).
- `POST /reward/api/settlements/search/settlement/excel` — 정산 완성본 엑셀(`:107`).

AdvancedSettlement (`AdvancedSettlementApiController.java`:22) — 바로정산:
- `GET  .../campaigns/{id}/advanced-settlements` (`:32`), `POST .../types/{type}` (`:39`), `POST .../types/{type}/cancel` (`:46`), `GET .../apply-status` (`:53`).

SettlementModifiedFee (`SettlementModifiedFeeApiController.java`:22):
- `POST /reward/api/settlements/modified-fees` — 수수료 수기 보정 + 정산 재계산(`:29`).
- `GET  /reward/api/settlements/campaigns/{id}/modified-fees` — 현재 보정값(`:50`).
- `GET  /reward/api/settlements/campaigns/{id}/modified-fee-logs` — 보정 로그(`:61`).

CampaignContractor (`CampaignContractorApiController.java`:22) — 실명/사업자 인증:
- `GET .../contractors` (`:32`), `POST .../contractors/manual-verification` (`:39`), `POST .../contractors/manual-cancellation` (`:49`), `POST .../contractors/manualBusiness-cancellation`(`:59`, "국세청 장애로 인해 수동인증 된 사업자번호 상태 초기화").

SubMall (`SettlementSubMallApiController.java`:34) — NICEPAY:
- `GET  .../submall/nicepay/notequal-bankaccount-campaigns/{id}` (`:41`), `POST .../notequal-bankaccont-campaigns`(sic `:48`), `POST .../subMallId-register-csv/download`(`:56`), `POST .../pay-request-csv/download`(`:68`), `POST .../subMallId-register-confirm/download`(`:84`).

TaxInvoice / Fee / Clawback / Estimated / SaleSettlement — 간단:
- `POST /reward/api/settlements/taxinvoice-issuance/issue/{type}` / `.../cancel/{type}` (`TaxInvoiceIssuanceApiController.java`:22, :31).
- `GET /reward/api/settlements/fees/campaigns/{id}` / `.../additionalCost` / `.../additionalCost/type/{type}` (`CampaignSettlementFeeApiController.java`:34, :41, :48).
- `GET /reward/api/v1/settlements/clawback/histories` · `POST /do/return` · `GET /status` (`SettlementClawbackProxyApiController.java`:50, :77, :87) — 외부 Clawback Gateway 호출.
- `POST /reward/api/settlements/estimatedAmounts/search` — 예상 정산금(`EstimatedSettlementApiController.java`:28).
- `POST /reward/api/settlements/sales/excels/download` · `/project/excels/download` (`SaleSettlementApiController.java`:37, :50).

CampaignSettlementUi (`CampaignSettlementUiController.java`:34) — JSP 팝업 7종:
- `/reward/settlement/list`(`:48`), `/popDetail/{id}`(`:60`), `/popEditFee`(`:80`), `/popEditSettlement`(`:96`), `/popEditRefund`(`:104`), `/popEditPreview/{id}`(`:112`), `/estimatedAmountList`(`:144`), `/clawback`(`:155`).

WEBSettlementRewardController (`/settlement/**`, 레거시):
- `/rewardList`(`:66`), `/popRewardDetail`(`:96`), `/downloadExcelDown`(`:132`), `/downloadBankUploadFormatExcel`(`:155`), `/downloadTaxInvoiceUploadFormatExcel`(`:166`), `/ajaxForceChangeStatus`(`:177`), `/ajaxChangeStatus`(`:186`), `/ajaxSettlementRewardResult`(`:198`), `/ajaxRegistInvoiceRegistered`(`:211`), `/ajaxModifySettlementRewardStatusInfo`(`:224`), `/ajaxModifyCorpTypeInfo`(`:237`), `/ajaxRegistMemo`(`:247`), `/ajaxModifySettlementResult`(`:256`).

추가 관찰:
- **상태머신이 중심**: `A10(접수) → A20(검수) → WAIT(대기) → HOLD/STOP/COMPLETE`. `SettlementStatusApiController` 가 조회·변경·force·로그를 모두 담당하고 UI는 `CampaignSettlementUiController` (JSP 팝업 7종) 가 래핑한다.
- **금액 계산은 외부 서버로 위임**: `SettlementResultApiController` 의 fee-amounts/payment-amount/settlement-amounts/refund-amounts/receivable-amount/fixedDates/advanced-settlement-file-history/final-settlement-file-history 는 대부분 wrapper. `SettlementProxyApiController` 가 `/reward/settlement/proxy/api/**` 전체를 `funding_settlement_api_base_uri` 로 forward하는 구조(`SettlementProxyApiController.java`:29).
- **사전정산(AdvancedSettlement)**: 타입별 신청/취소, apply-status 조회. 캠페인이 펀딩 기간 중에도 메이커가 일부 금액을 받을 수 있게 하는 기능.
- **수수료(Fee)**: 기본 수수료는 `CampaignSettlementFeeApiController` 에서 조회, 수기 보정은 `SettlementModifiedFeeApiController` 가 등록/로그까지 책임. 추가비용(additionalCost) 별도 엔드포인트 있음.
- **세금계산서/계약자 실명확인**: `TaxInvoiceIssuanceApiController` (issue/cancel type별), `CampaignContractorApiController` (manual-verification / manual-cancellation / manualBusiness-cancellation).
- **NICEPAY SubMall**: `SettlementSubMallApiController` — 계좌불일치 캠페인 재등록, submall 등록 CSV / pay-request CSV / 등록확인 CSV 를 `text/plain;charset=UTF-8` 로 다운.
- **미수금 환수(Clawback)**: `SettlementClawbackProxyApiController` + `FundingSettlementOutstandingClawbackGateway` 를 통해 histories/do/return/status. UI 진입점은 `CampaignSettlementUiController.java`:155 `/clawback`.
- **레거시 JSP 루트**: `WEBSettlementRewardController`(`/settlement/rewardList`) — 리스트/상세/엑셀/은행양식/세금계산서양식/ForceChangeStatus/Memo/CorpType 등. 신형 API 가 생긴 지금도 남아있음.
- **검색·엑셀 도구상자**: `SettlementSearchApiController` 가 search/excel/bankUploadFormat/trust/excel/settlement/excel 의 **5개 엑셀** 변형을 제공.
- 판매정산 전용 경로는 `SaleSettlementApiController` (`/reward/api/settlements/sales/**`) — 캠페인이 아닌 **판매기간** 단위 정산.

### Payment (리워드 결제) — 주요 엔드포인트

WEBPaymentController (`WEBPaymentController.java`:51, JSP):
- `payment/paymentMgrList`(`:89`), `popPaymentDetail`(`:135`), `popPaymentRefund`(`:176`), `downloadExcelDown POST`(`:192`), `emailSend`(`:247`), `smsSend`(`:263`), `ajaxCancelPayment POST`(`:276`), `popExcelDownload`(`:291`).

WEBRewradPaymentController (`WEBRewradPaymentController.java`:31, `/payment/*`):
- `/rewardPaymentList`(`:47`), `/rewardPaymentDownloadExcel`(`:74`), `/rewardPaymentHistoryDetail`(`:109`).

WEBLecturePaymentController (강의 결제, `WEBLecturePaymentController.java`:29):
- `payment/lectureInauguratePayment`(`:47`), `popLecturePayment`(`:79`), `popLecturePaymentRegist`(`:91`), `ajaxLecturePaymentEnter`(`:104`), `downloadLectureExcelDownload`(`:116`), `ftpayment/ajaxPaymentCancel`(`:145`), `updateLectureEnterYn`(`:155`), `lectureInauguratePayment/{lectureId}`(`:165`), `LecturePreviewExcelDownload/{lectureId}`(`:193`), `ajaxInsertSchoolForm`(`:238`).

PaymentSummary (`PaymentSummaryController.java`:34):
- `/reward/payment/summarySearch`(`:38`), `/searchPaymentApprovalHistoryDownload POST`(`:46`), `/makerSalesReport`(`:61`), `/makerSalesReport/excel/download POST`(`:70`).

API 레이어:
- `GET /reward/api/payments/refunds/{backingPaymentId}/required-cancel-amounts` (`BackingPaymentRefundApiController.java`:26) — 부분환불 시 취소필요금액 계산.
- `GET /reward/api/payments/coupons/summation` (`BackingPaymentCouponApiController.java`:25) — 결제건 쿠폰 합계.

추가 관찰:
- `WEBPaymentController` 가 종합 결제 JSP (`paymentMgrList` / 상세팝업 / 환불팝업 / 엑셀 / 이메일/SMS 발송 / 강제취소 `ajaxCancelPayment`).
- `WEBRewradPaymentController` (오탈자 `Rewrad`): `/payment/rewardPaymentList` + 엑셀/상세. 위 Controller 와 기능이 일부 겹치지만 URL/데이터 모델이 다르다 (리워드 계열 전용).
- `WEBLecturePaymentController` 는 **강의·입학 상품** 결제 (`lectureInauguratePayment`, `popLecturePayment`, `ftpayment/ajaxPaymentCancel`, `updateLectureEnterYn`, `ajaxInsertSchoolForm`) — equity 쪽 강의와 연동.
- `PaymentSummaryController` (`/reward/payment/summarySearch` 외): 결제 **집계**와 승인이력 엑셀, **메이커 매출 리포트** 엑셀.
- API 레이어: `BackingPaymentRefundApiController` (부분환불 시 취소필요금액 계산) + `BackingPaymentCouponApiController` (쿠폰 사용합산).

### Coupon — 주요 엔드포인트

CouponTemplate (`CouponTemplateApiController.java`:28, `/reward/api/coupons/templates`):
- `GET ""` 리스트(`:42`), `GET /{templateNo}` 상세(`:56`), `POST ""` 생성(`:63`), `PUT /{templateNo}` 수정(`:72`), `GET /{templateNo}/summations` 집계(`:80`), `GET /{templateNo}/coupons` 발급분(`:87`), `GET /{templateNo}/coupons/qty` 수량(`:98`).

CouponIssue (`CouponIssueApiController.java`:25, `/reward/api/coupons/issues`):
- `GET ""`(`:33`), `GET /{issueKey}/codes`(`:40`), `POST /types/coupon-code`(`:47`), `POST /types/direct`(multipart `:55`, json `:63`), `GET /purpose-types`(`:71`).

CouponTransaction / Summation:
- `POST /reward/api/coupons/transactions/types/withdraw` (`CouponTransactionApiController.java`:25) — 쿠폰 회수.
- `GET  /reward/api/coupons/transaction-summation` (`CouponTransactionSummationController.java`:37), `GET /excel`(`:44`).

CouponUI + Legacy view (`CouponUiController.java`:35, `/reward/coupon`):
- `GET /issue/{issueKey}/code/excel`(`:53`), `GET /template/{templateNo}/coupon`(`:73`), `GET /issue/direct/format`(`:98`) — 일괄 발급 엑셀 포맷.
- `rewardCouponViewController.java`:10 — JSP 뷰 다수 매핑(예: 회원쿠폰, 회계).

v2 통합 (`UserCouponTemplateController.java`:26, `/v2/account/coupon`):
- `GET /templates`(`:38`) — 사용자용 쿠폰 템플릿 리스트.
- `GET /template/issue/{issue_key}`(`:54`) — 발급 키 기반 조회.
- `POST /template`(`:64`), `DELETE /template/{couponTemplateNo}`(`:78`).

추가 관찰:
- **두 개의 쿠폰 체계 공존**:
  1. **Reward 쿠폰** (`/reward/api/coupons/**`) — 템플릿·발급·트랜잭션(사용/회수)·summation 4축. 신규 REST 스타일. UI는 `CouponUiController` + 레거시 소문자-시작 `rewardCouponViewController` / `rewardCouponAccountingViewController`.
  2. **증권형(wcoupon) 쿠폰** (`/wcoupon/**`, `/wcouponDetail/**`, `/wcoupon/event/*`) — 랜덤쿠폰·배포쿠폰·이벤트쿠폰·**페이백** 체계. 리워드 쿠폰과 스키마·책임이 분리.
- `UserCouponTemplateController` (`kr.wadiz.coupon`, `/v2/account/coupon/**`) — **v2 차세대 쿠폰** (사용자 템플릿 조회/등록/삭제). `kr.wadiz.*` 네이밍으로 신규 인프라 쪽.
- 발급 채널: `coupon-code` (코드기반) vs `direct` (엑셀 직발급, `multipart/form-data` 또는 JSON) — `CouponIssueApiController.java`:47–63.

### Point
- 단일 거대 컨트롤러 `WEBPointController` (500+ 줄) — 템플릿·리스트·지급(단건/벌크)·이슈내역·트랜잭션·회수(`/withdraw`).
- 벌크지급은 엑셀 업로드 2단계(`ajaxCheckImportFile` → `ajaxCheckImport` → `ajaxPaymentBulkPoint`). 포맷 다운로드 `/format/exceldown` / `/bulkFormat/exceldown`.
- 사유 enum은 `PointApiController.java`:21 `/point/api/issue-reason-types` 단 하나의 REST 메서드로 제공.
- 사용자별 포인트 조회: `/point/ajax/{userId}` + `/point/ajax/{userId}/transactions`.

### Equity (증권형 투자)
- 가장 **책임이 넓은 도메인**. 수수료·청약결제·가상계좌·쿠폰·멤버십·W9·법무/회계법인 연동·KRX 정보까지 모두 `/equity/**`(신) + `/ftcampaign/**`(구) + `/payment/**`(domain) + `/wcoupon/**` + `/premiumMembership/**` + `/mastergroup/**` 에 분산.
- **구버전 `WEBEquityController` 는 god-controller** (1700+줄, 70+ 메서드). 신버전 `EquityCampaignController` / `EquityCampaignPublishController` / `EquityStagePublishController` 로 점진 이관 중이지만 `ftcampaign/**` 은 아직 살아있음 (실투자 배정/계좌검증 포함).
- **증권신고서 스테이지 13종** (`EquityStagePublishController`): Description / Brokerage / Incorporation / LawFirmContract / AccountingFirmContract / Securities / IncreaseAsset + 수수료 4축(Basic / LawFirm / RateFee / AccountingFirmFee) 각각 `Stage` + `Deposit`.
- **청약(EquityAssign)**: 구버전 `WEBEquityController` 의 `ftcampaign/equityAssignList`, `popEquityAssignDetail`, `ajaxEquityAssign`, `ajaxEquityAssignCancel`, `ajaxValidationBankAccount`(실명), `ajaxOperation`, `ajaxTransactionRetry`, `ajaxEquityAssignRetryNotification`.
- **결제**: 가상계좌 입금(`WEBVirtualAccountController`) + 청약결제 승인/NICE체크(`WEBOfferPaymentController`). 둘 다 `/payment/*` 공유 prefix 위에서 동작(equity 전용이지만 URL은 공용).
- **쿠폰·페이백**: `WEBCouponDetailController` 가 페이백 엔진(`ajaxExecutePayBack` / `paybackList` / `ajaxModifyPayback` / `dwonloadConditionPaybackChargeInfo`) 까지 포함.
- **부가 서비스**: `PremiumMembershipController` (와디즈 프리미엄), `WEBMasterGroupController` (전문가 그룹 멤버/추천), `PremiumContentsBoardController` (프리미엄 콘텐츠), `EquityW9ContentsController` (미국 W9 세무).
- **상태 전이**는 `EquityCampaignController` 가 관장: `backCampaignStatus` / `changeCampaignStatus` / `screeningConfirm` / `fundingConfirm`(GET=조회, POST=확정) / `campaignRefundAll`(전체환불).

## 5. 외부 연동

- **funding-settlement 서버** (`funding_settlement_api_base_uri`): 정산 로직 대부분의 소스.
  - `SettlementProxyApiController` 가 `/reward/settlement/proxy/api/**` → `http://{base}/**` 로 프록시(`adminId`·`adminName` 헤더 추가).
  - `FundingSettlementOutstandingClawbackGateway` 를 통해 미수금 환수 호출(`SettlementClawbackProxyApiController.java`:44).
- **nicepay-api** (PG):
  - 서브몰 등록·pay-request CSV (`SettlementSubMallApiController`).
  - 청약 결제 NICE 체크(`WEBOfferPaymentController.java`:179 `popOfferPaymentNiceCheck`).
  - 실시간 계좌검증(`WEBOfferPaymentController.java`:334 `ajaxRealtimeAccountCheck`, `WEBEquityController` ftcampaign 계좌검증).
- **`com.wadiz.api.reward`** (리워드 코어): `ResponseWrapper` 사용(clawback), 쿠폰 템플릿·트랜잭션·결제 모델 등의 도메인 스키마 공유.
- **메일/SMS**:
  - 정산·증권 리스크·증권신고서 메일 (`EquityNoticeController`, `EquityStagePublishController.mail/preview`, `EquityCampaignPublishController.mail/preview` + `mail/send/mapkey/assignNoti`).
  - SMS: `WEBPaymentController.smsSend`, `WEBOfferPaymentController.popMultiSelectSmsSend`.
- **엑셀 다운로드 엔진**: 공용 `ExcelDownloadView` 사용 — 40개 이상 엔드포인트가 `xlsx`/`csv`/`text/plain` 리턴.
- **Smartsheet**: `EquityCampaignController.java`:771 `/smartsheet/sync` — 증권형 심사 워크플로우 sync.
- **세션 기반 어드민 식별**: `WEBSessionUtil.getUserId()` / `getNickName()` — 프록시 헤더·감사로그에 사용.

## 6. 경계

- **플랜 문서(.omc/plans/*.md)는 이 문서에 통합 안 함** — 본 문서는 코드(컨트롤러)만 보고 정리.
- **서비스/리포지토리 계층은 대상 아님** — 예: `SettlementSubMallService`, `FundingSettlementOutstandingClawbackGateway` 구현체는 각 컨트롤러가 위임하는 지점까지만 기록.
- **스케줄러·이벤트 컨슈머·배치 잡** 제외 — 어드민 수동 트리거(예: `/ajaxPaymentBulkPoint`) 는 컨트롤러지만 순수 배치 잡은 별도.
- **프론트엔드 JSP/JS** 는 파일명만 언급, 내용 분석 안 함 — `popXxx.jsp`, `jqgrid`, `kendo` 등은 `web/resources/**` 에 있음.
- **권한(`@PreAuthorize` / `WEBSessionUtil.hasRole`)** 체크는 메서드별로 존재하지만 이 문서에 권한 매핑 테이블 미포함 — 별도 분석 필요.
- **com.wadiz.api.funding / com.wadiz.api.reward / com.wadiz.api.startup** 가 실제 비즈 로직을 담고있는 서비스로, 본 어드민 컨트롤러는 대부분 **게이트웨이 / 운영 UI** 역할 — 상세 돈 계산 로직은 해당 서버 문서를 참조.
- **오탈자/네이밍 혼재**: `Rewrad`(Reward), `dwonload`, `cancle`(cancel), `Acoount`(Account), `Ivst`(Invest), `Secur[tT]ype`, `couponuseView` — 레거시라 그대로 둔다.
