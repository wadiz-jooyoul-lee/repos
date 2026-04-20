# core/domain 모듈 분석

> **기록 범위**: `core/domain` 모듈 안에서 직접 읽을 수 있는 소스 코드만 기록한다.
> UseCase 클래스들은 이 레포 안에 구현체(`@UseCase`)가 존재하며 직접 관찰 가능하다.
> 단, 이들이 호출하는 외부 jar(`com.wadiz.funding.core:funding-core`)의 내부 로직은 확인 불가이며
> 해당 경계에서 관찰을 중단한다. Gateway 인터페이스의 구현체는 `adapter/infrastructure` 모듈에
> 있으므로 실제 SQL·Redis 키·DB 테이블은 이 문서 범위 밖이다.
> 총 Java 파일: **1,381개**, 도메인 패키지: **74개**, Gateway 인터페이스: **163개**(도메인) + 4개(support)

---

## 1. 모듈 구조

```
core/domain/src/main/java/com/wadiz/api/funding/
├── domain/            # 74개 도메인 서브패키지 (~1,300+ 파일)
├── event/             # EventDispatcher 포트 인터페이스 (1파일)
├── exception/         # 공통 예외 계층 (7파일)
├── validators/        # Bean Validation 커스텀 어노테이션·유틸 (10파일)
└── support/           # 도메인 지원 유틸·Gateway (31파일)
    ├── carrier/
    ├── country/
    ├── data/          # Pages, Sorts, ServiceType 등
    ├── security/
    ├── translate/
    └── util/
```

---

## 2. 도메인 패키지 인벤토리

> 파일 수는 `find … -name "*.java" | wc -l` 으로 계측. Gateway/UseCase 수는 직접 관찰 결과.

### 2.1 주문·결제

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `order` | 30 | 4 (`OrderSessionRedisGateway`, `OrderSheetRedisGateway`, `OrderSessionLogGateway`, `OrderSheetLogGateway`) | 5 (session create/detail, sheet create/delete, closedSession) | 주문 세션·주문서 생성/조회/삭제, 재고 체크 포함 |
| `orderpayment` | 24 | 3 (`OrderPaymentGateway`, `OrderPaymentRedisGateway`, `OrderPayMessageLogGateway`) | 1 (`OrderPaymentUsecase` — NICE/Stripe/Alipay/0원 결제 분기) | PG 결제 승인 콜백 처리 + `EventDispatcher` 다수 발행 |
| `payment` | 9 | 1 (`PaymentGateway`) | 0 (쿼리 UseCase 없음) | 내부 결제 정보 조회/저장 |
| `paymentcancel` | 20 | 2 (`CancelPaymentGateway`, `CancelPaymentRedisGateway`) | 1 (`CancelPaymentUsecase`) | 취소 프로세서 3종(예약·즉시·정기) + 이벤트 발행 |
| `paymentprogress` | 10 | 1 (`PaymentProgressGateway`) | 2 (`PaymentRelevantInfoUseCase`, `PaymentReportUseCase`) | 결제 진행 연관 정보 조회 |
| `paymentnotification` | 1 | 1 (`PaymentNotificationGateway`) | 0 | 결제 알림 Gateway 포트 |
| `billkey` | 9 | 1 (`BillkeyQueryGateway`) | 1 (`CardExpireVerificationUseCase`) | 정기결제 빌키 만료 검증 |
| `simplepay` | 26 | 2 (`SimplePayGateway`, `SimplePayRedisGateway`) | 6 (create/use/verify/remove/detail/registerPasscode) | 와디즈 간편결제 빌키 전 생애주기 관리 |
| `outstanding` | 3 | 1 (`OutstandingGateway`) | 0 | 미수금 Gateway 포트 |
| `coupon` | 10 | 1 (`CouponGateway`) | 0 | 쿠폰 적용 Gateway 포트 |
| `point` | 5 | 1 (`PointGateway`) | 0 | 포인트 적용 Gateway 포트 |

### 2.2 캠페인·프로젝트

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `campaign` | 77 | 9+ (`CampaignGateway`, `CampaignQueryGateway`, `CampaignHiddenGateway`, `CampaignMarkerGateway`, `CampaignPendingStandbyGateway`, `CampaignSubmitApprovalGateway`, `SubmitApprovalEventGateway`, `ComingSoonCommandGateway`, `ScreeningCommandGateway`, `SettlementCommandGateway`, …) | 다수 | 가장 큰 도메인 패키지; 조회·심사·승인 제출·카테고리·숨김·마커 등 |
| `globalproject` | 49 | 2 (`GlobalProjectQueryGateway`, `GlobalProjectRewardQueryGateway`) | 다수 | 다국어 글로벌 프로젝트 조회 (분배·보상·언어 등) |
| `comingsoon` | 7 | 3 (`ComingSoonGateway`, `ComingSoonQueryGateway`, `CampaignAutoOpenGateway`) | 0 | 오픈예정(coming soon) 프로젝트 |
| `comingsoonapplicant` | 22 | 3 (`ComingSoonApplicantGateway`, `ComingSoonApplicantQueryGateway`, `ComingSoonApplicantStatisticQueryGateway`) | 2 (create/delete) | 오픈예정 신청자 생성·삭제 + `WishCreateEvent`/`WishDeleteEvent` 연동 |
| `campaigncategory` | 4 | 1 (`CampaignCategoryQueryGateway`) | 0 | 카테고리 조회 포트 |
| `campaignsnapshot` | 2 | 1 (`CampaignSnapshotQueryGateway`) | 0 | 캠페인 스냅샷 조회 포트 |
| `campaignscreening` | 8 | 1 (`CampaignScreeningRewardItemQueryGateway`) | 0 | PD 심사 Gateway 포트 |
| `project` | 1 | 0 | 0 | 단일 공통 VO |
| `projectaisummary` | 2 | 1 (`ProjectAiSummaryGateway`) | 0 | AI 요약 저장 Gateway 포트 |
| `projectpause` | 6 | 1 (`ProjectPauseGateway`) | 0 | 프로젝트 일시정지 |
| `preorder` | 3 | 1 (`PreOrderQueryGateway`) | 1 (`PreOrderListUseCase`) | 사전예약 조회 |
| `spaceexhibition` | 3 | 1 (`SpaceExhibitionGateway`) | 0 | 공간전시 Gateway 포트 |

### 2.3 리워드·상품

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `reward` | 25 | 3 (`RewardQueryGateway`, `RewardLimitedTimeOfferGateway`, `RewardLimitedTimeOfferQueryGateway`) | 0 | 리워드·한정 시간 오퍼 |
| `rewarditem` | 10 | 2 (`RewardItemQueryGateway`, `RewardItemGateway`) | 1 (`RewardItemListUseCase`) | 리워드 아이템 조회 |
| `rewardevent` | 60 | 2 (`RewardEventGateway`, `RewardEventQueryGateway`) | 8+ (list/detail/participate/benefitList/fixed·random 생성·수정·삭제) | 리워드 이벤트 전 생애주기; 가장 큰 단일 도메인 중 하나 |
| `rewardpayment` | 2 | 1 (`RewardPaymentGateway`) | 0 | 리워드 결제 |
| `rewardpolicy` | 4 | 1 (`RewardPolicyGateway`) | 0 | 환불 정책 조회 |
| `rewardchangelog` | 3 | 1 (`RewardChangeLogGateway`) | 1 (`RewardChangeLogUseCase`) | 리워드 변경 이력 (MongoDB 경유, 인프라 계층에서 확인) |
| `refund` | 4 | 1 (`RewardRefundQueryGateway`) | 0 | 환불 조회 |
| `refundpolicy` | 6 | 1 (`RewardRefundPolicyGateway`) | 0 | 환불 정책 조회 |
| `productinfonotice` | 8 | 1 (`ProductInfoNoticeQueryGateway`) | 0 | 상품 정보 고시 |
| `stock` | 8 | 2 (`StockGateway`, `StockQueryGateway`) | 1 (`StockUsecase` — 재고 선점·체크) | Redis 기반 재고 선점 (주문서 생성 시 사용) |

### 2.4 정산·배송

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `settlement` | 60 | 5+ (`SettlementGateway`, `ErpSettlementGateway`, `StatementGateway`, `SlipExcelGateway`, `TaxInvoiceExcelGateway`) | 5+ (status/statement/erp/slip/taxinvoice) | 정산 2.0 포함 전 정산 로직; Excel/PDF/ERP 연동 |
| `shipping` | 19 | 3 (`ShippingQueryGateway`, `DeliveredNotificationQueryGateway`, `PendingNotificationQueryGateway`) | 0 | 배송 조회·알림 Gateway 포트 |
| `erp` | 2 | 0 | 0 | ERP 관련 공통 VO |

### 2.5 서포터·펀딩 참여

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `supporter` | 20 | 1 (`SupporterQueryGateway`) | 6 (fundingList/detail/recentShippingAddress/recentPayBy/modifyShipping/modifyPayBy/shippingQty) | 서포터 마이페이지 전 기능 |
| `backing` | 50 | 8+ (`BackingGateway`, `BackingPaymentGateway`, `BackingPaymentQueryGateway`, `BackingPaymentStatisticQueryGateway`, `BackingRewardSetGateway`, `BackingRewardOptionGateway`, `BackingRewardCompositionGateway`, `BackingPaymentCouponGateway`, `BackingPaymentPointGateway`, `BackingPaymentDiscountBenefitGateway`, `BackingPaymentExternalInfoGateway`, `BackingPaymentCancelLogGateway`, …) | 0 | 펀딩 참여(백킹) 결제·보상·쿠폰·포인트 전 Gateway 포트 집합 |
| `participation` | 16 | 1 (`ParticipationQueryGateway`) | 0 | 참여 현황 조회 |
| `funding` | 11 | 1 (`FundingQueryGateway`) | 0 | 펀딩 횟수 통계 조회 |

### 2.6 메이커·사업자

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `maker` | 24 | 5 (`MakerQueryGateway`, `MakerUserGateway`, `MakerFollowQueryGateway`, `MakerClubQueryGateway`, `CorporationQueryGateway`) | 0 | 메이커 정보·팔로우·법인 조회 |
| `makerinvitation` | 30 | 5 (`MakerInvitationGateway`, `MakerInvitationQueryGateway`, `MakerInvitationCodeGateway`, `MakerInvitationBenefitGateway`, `MakerInvitationBenefitPaymentGateway`) | 0 | 메이커 초대 코드·혜택 전 생애주기 |
| `manager` | 6 | 1 (`ManagerQueryGateway`) | 0 | 프로젝트 담당자 조회 |
| `department` | 4 | 1 (`DepartmentQueryGateway`) | 0 | 부서 조회 |
| `employee` | 7 | 1 (`EmployeeQueryGateway`) | 0 | 사원 조회 |
| `bankaccount` | 4 | 1 (`BankAccountQueryGateway`) | 0 | 계좌 조회 |
| `contractinfo` | 10 | 2 (`ContractInfoGateway`, `ContractInfoQueryGateway`) | 1 (`CampaignContractInfoUseCase`) | 계약 정보 |
| `business` | 8 | 1 (`BusinessVerifyQueryGateway`) | 0 | 사업자 인증 조회 |
| `personalverification` | 5 | 1 (`PersonalVerificationGateway`) | 0 | 개인 검증 |
| `kcertification` | 6 | 1 (`CertCheckQueryGateway`) | 0 | K-본인인증 조회 |

### 2.7 커뮤니케이션·알림

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `news` | 38 | 3 (`NewsQueryGateway`, `NewsGateway`, `NewsLanguageGateway`) | 2+ (create/modify) + `EventDispatcher` 발행 | 새소식 생성·수정·조회 + 게시 이벤트 |
| `newsnotification` | 23 | 4 (`NewsNotificationGateway`, `NewsNotificationQueryGateway`, `NewsNotificationDenyGateway`, `NewsNotificationLogGateway`) | 1 (`NewsNotificationSetupDenyUseCase`) | 새소식 수신 거부 설정·해제 |
| `announcement` | 51 | 2 (`AnnouncementGateway`, `AnnouncementQueryGateway`) | 3+ (create/modify/modifyByMenu/modifyContents) | 공지사항 전 CRUD + 이벤트 발행; 가장 큰 단일 패키지 |
| `noticebanner` | 3 | 1 (`NoticeBannerQueryGateway`) | 0 | 공지 배너 조회 |
| `braze` | 1 | 0 | 0 | Braze 관련 이벤트 참조 VO |

### 2.8 찜·서명·앵콜·팔로우

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `wish` | 26 | 2 (`WishGateway`, `WishQueryGateway`) | 2 (create/delete) + `EventDispatcher` 발행 | 찜 생성·삭제 이벤트 포함 |
| `signature` | 5 | 2 (`SignatureGateway`, `SignatureQueryGateway`) | 1 (`SignatureQtyUseCase`) | 지지서명 수 조회 |
| `encore` | 13 | 3 (`AskForEncoreGateway`, `CampaignAskForEncoreQueryGateway`, `EncoreOpenNotificationGateway`) | 3 (ask/cancel/whether) | 앵콜 신청·취소·여부 조회 |
| `follow` | 5 | 2 (`FollowGateway`, `FollowQueryGateway`) | 0 | 팔로우 Gateway 포트 (`FollowActivityEvent` 수신용) |

### 2.9 스토리·번역·AI 심사

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `story` | 65 | 3 (`StoryCopyGateway`, `StoryTranslationQueryGateway`, `TranslationStatisticsGateway`) | 다수 (번역 요청·상태·이력 등) | 스토리 복사·번역 전 생애주기 |
| `aireview` | 23 | 1 (`AIReviewQueryGateway`) | 1 (`AIReviewUseCase`) | AI 심사 결과 조회 |
| `language` | 6 | 2 (`LanguageExpansionGateway`, `TranslationQualityMonitorGateway`) | 0 | 다국어 확장·품질 모니터링 Gateway 포트 |

### 2.10 대시보드·스튜디오·통계

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `dashboard` | 46 | 1 (`MakerDashboardQueryGateway`) | 다수 | 메이커 대시보드 조회 (DataPlus 외부 연동 포함) |
| `studio` | 41 | 5 (`StudioMenuUseCase`, `StudioSectionGateway`, `StudioSectionQueryGateway`, `StudioPayloadLogGateway`, `StudioPricingGateway`, `PackagePlanDeterminationGateway`) | 3+ (menu/section/pricing/log) | 스튜디오 메뉴·요금제·로그 |
| `studiodashboard` | 6 | 0 | 0 | 스튜디오 대시보드 VO |
| `statistic` | 68 | 2 (`ProjectDataplusGateway`, `ComingSoonDataplusGateway`) | 다수 | DataPlus 통계 조회; 두 번째로 큰 패키지 |

### 2.11 부가기능·기타

| 패키지 | 파일 수 | 주요 Gateway 수 | UseCase 수 | 한줄 설명 |
|---|---|---|---|---|
| `additionalservice` | 17 | 1 (`AdditionalServiceGateway`) | 0 | 부가서비스 신청 상태 관리 |
| `iplicense` | 32 | 2 (`IPLicenseGateway`, `IPLicenseQueryGateway`) | 3+ (save/setupTag/setupTopRank) + 이벤트 발행 | IP 라이선스 태그·랭킹 설정 |
| `catalog` | 5 | 2 (`CatalogFeedQueryGateway`, `ExchangeRateQueryGateway`) | 0 | 메타 카탈로그·환율 조회 |
| `membership` | 15 | 2 (`MembershipGateway`, `MembershipQueryGateway`) | 0 | 멤버십 혜택 조회 (주문서 생성 시 배송비 할인 연동) |
| `reaction` | 17 | 2 (`ReactionGateway`, `ReactionQueryGateway`) | 3 (list/typeList/save) | 좋아요·반응 |
| `safenumber` | 10 | 1 (`SafeNumberQueryGateway`) | 1 (`SafeNumberUseCase`) | 안심번호 조회 |
| `satisfaction` | 10 | 1 (`SatisfactionGateway`) | 0 | 만족도 조사 |
| `storeevent` | 11 | 2 (`StoreEventGateway`, `StoreEventQueryGateway`) | 1 (`StoreOpenUseCase`) | 스토어 오픈 이벤트 + `StoreOpenNotificationCreateEvent` 발행 |
| `storeproject` | 4 | 1 (`StoreProjectQueryGateway`) | 0 | 스토어 프로젝트 조회 |
| `eventday` | 5 | 1 (`EventDayQueryGateway`) | 1 (`BusinessDateUseCase`) | 영업일·이벤트 데이 계산 |
| `bottomsheet` | 17 | 1 (`BottomSheetQueryGateway`) | 0 | 바텀시트 UI 데이터 조회 |
| `collection` | 1 | 1 (`CollectionGateway`) | 0 | 컬렉션 Gateway 포트 |
| `partner` | 2 | 1 (`PartnerGateway`) | 0 | 파트너 Gateway 포트 |
| `attach` | 7 | 1 (`AttachGateway`) | 0 | 첨부파일 + Braze 친구톡 이미지 타입 |
| `slack` | 2 | 1 (`SlackGateway`) | 0 | Slack 알림 포트 |
| `user` | 10 | 2 (`UserGateway`, `UserQueryGateway`) | 0 | 유저 조회·상태 확인 |
| `pingpongpaymentreminder` | 1 | 0 | 0 | 핑퐁 결제 리마인더 VO |
| `common` | 1 | 0 | 0 | 공통 VO |

---

## 3. UseCase 클래스 인벤토리 (주요 241개 중 발췌)

> 이 레포의 `core/domain` 안에는 UseCase 구현체(`@UseCase` 스테레오타입)가 직접 존재한다.
> 아래는 비즈니스적으로 중요한 UseCase만 나열한다. 패키지별 전체 목록은 소스 디렉터리를 참조.

### 주문·결제

| UseCase 클래스 | 패키지 | 핵심 public 메서드 |
|---|---|---|
| `CreateOrderSessionUsecase` | `order.session.create` | `create(command)` |
| `OrderSessionDetailUsecase` | `order.session.detail` | `get(token)` |
| `CreateOrderSheetUsecase` | `order.sheet.create` | `create(command)`, `validateCustomsCode(command)` |
| `DeleteOrderSheetUsecase` | `order.sheet.delete` | `delete(token)` |
| `FindClosedSessionUsecase` | `order.closedsession` | `find(token)` |
| `OrderPaymentUsecase` | `orderpayment` | `pay(command)`, `zeroPayApprove(command)` — NICE/Stripe/Alipay/0원 분기 |
| `CancelPaymentUsecase` | `paymentcancel` | `cancel(command)`, `adminCancel(command)` 등 |
| `StockUsecase` | `stock` | `checkStock(rewardOrder, rewardStock, prefix)` |
| `CardExpireVerificationUseCase` | `billkey.verifycardexpire` | 빌키 만료 검증 |

### 간편결제 (simplepay)

| UseCase 클래스 | 주요 역할 |
|---|---|
| `CreateBillkeyUseCase` | 빌키 등록 + `CreateBillkeyEvent` 발행 |
| `UseBillkeyUseCase` | 빌키 결제 사용 + `UseBillkeyEvent` 발행 |
| `BillkeyVerificationUseCase` | 빌키 검증 + `BillkeyVerificationEvent` 발행 |
| `RemoveBillkeyUseCase` | 빌키 삭제 + `RemoveBillkeyEvent` 발행 |
| `BillkeyDetailUseCase` | 빌키 상세 조회 + `BillkeyDetailEvent` 발행 |
| `RegisterPasscodeUseCase` | 비밀번호 등록 + `RegisterPasscodeEvent` 발행 |

### 캠페인·프로젝트

| UseCase 클래스 | 패키지 | 비고 |
|---|---|---|
| `PreOrderListUseCase` | `preorder.list` | 사전예약 목록 |
| `BusinessDateUseCase` | `eventday.businessdate` | 영업일 계산 |

### 리워드 이벤트 (rewardevent — 8개 UseCase)

| UseCase 클래스 | 역할 |
|---|---|
| `RewardEventListUseCase` | 이벤트 목록 조회 |
| `RewardEventDetailUseCase` | 이벤트 상세 조회 |
| `RewardEventDetailParticipantUseCase` | 참가자 상세 |
| `RewardEventParticipateUseCase` | 이벤트 참여 |
| `RewardEventBenefitListUseCase` | 혜택 목록 |
| `RewardEventParticipationAggregationUseCase` | 참여 집계 |
| `FixedBenefitEventUseCase` / `ModifyFixedBenefitEventUseCase` | 고정 혜택 이벤트 생성·수정 |
| `RandomBenefitEventUseCase` / `ModifyRandomBenefitEventUseCase` | 랜덤 혜택 이벤트 생성·수정 |
| `DeleteRewardEventUseCase` | 이벤트 삭제 |
| `ModifyRewardEventUseCase` | 이벤트 수정 |

### 정산 (settlement — 5개 UseCase)

| UseCase 클래스 | 역할 |
|---|---|
| `CampaignSettlementStatusUseCase` | 정산 진행 상태 |
| `StatementUsecase` | 정산 내역서 |
| `ErpSettlementUseCase` | ERP 정산 연동 |
| `SlipExcelUseCase` | 전표 Excel 생성 |
| `TaxInvoiceExcelUseCase` | 세금계산서 Excel 생성 |

### 서포터 (supporter — 7개 UseCase)

| UseCase 클래스 | 역할 |
|---|---|
| `FundingListUseCase` | 내 펀딩 참여 목록 |
| `FundingDetailUseCase` | 펀딩 상세 |
| `RecentShippingAddressListUseCase` | 최근 배송지 목록 |
| `RecentPayByUseCase` | 최근 결제 수단 |
| `ShippingAddressModifyUseCase` | 배송지 변경 |
| `PayByModifyUseCase` | 결제 수단 변경 |
| `ShippingQtyUseCase` | 배송 건수 조회 |

### 새소식·공지

| UseCase 클래스 | 역할 |
|---|---|
| `CreateNewsUseCase` | 새소식 생성 + `CreateNewsEvent`/`PostNewsEvent` 발행 |
| `ModifyNewsUseCase` | 새소식 수정 + `ModifyNewsEvent`/`PostNewsEvent` 발행 |
| `CreateAnnouncementUseCase` | 공지 생성 + `CreateAnnouncementEvent` 발행 |
| `ModifyAnnouncementUseCase` | 공지 수정 + `ModifyAnnouncementEvent` 발행 |
| `ModifyAnnouncementByMenuUseCase` | 메뉴별 공지 수정 + `ModifyAnnouncementByMenuEvent` 발행 |
| `ModifyAnnouncementContentsUseCase` | 공지 내용 수정 + `ModifyAnnouncementContentsEvent` 발행 |
| `NewsNotificationSetupDenyUseCase` | 새소식 수신거부 + `NewsNotificationSetupDenyEvent` 발행 |

### 찜·서명·앵콜·IP라이선스

| UseCase 클래스 | 역할 |
|---|---|
| `WishCreateUseCase` | 찜 생성 + `WishCreateEvent` 발행 |
| `WishDeleteUseCase` | 찜 삭제 + `WishDeleteEvent` 발행 |
| `SignatureQtyUseCase` | 지지서명 수 조회 |
| `AskForEncoreUseCase` | 앵콜 신청 |
| `CancelEncoreUseCase` | 앵콜 취소 |
| `CampaignAskForEncoreWhetherUseCase` | 앵콜 신청 여부 조회 |
| `SaveIPLicenseUseCase` | IP라이선스 저장 + `SaveIPLicenseEvent` 발행 |
| `SetupTagUseCase` | IP 태그 설정 + `SetupTagEvent` 발행 |
| `SetupTopRankUseCase` | IP 랭킹 설정 + `SetupTopRankEvent` 발행 |

### 기타

| UseCase 클래스 | 역할 |
|---|---|
| `ReactionListUseCase` / `ReactionTypeListUseCase` / `ReactionSaveUseCase` | 좋아요·반응 |
| `StudioMenuUseCase` / `StudioSectionUseCase` / `StudioPricingUseCase` / `StudioPayloadLogUseCase` | 스튜디오 메뉴·요금제·로그 |
| `AIReviewUseCase` | AI 심사 결과 |
| `RewardChangeLogUseCase` | 리워드 변경 이력 (MongoDB) |
| `RewardItemListUseCase` | 리워드 아이템 목록 |
| `CampaignContractInfoUseCase` | 계약 정보 |
| `SafeNumberUseCase` | 안심번호 |
| `StoreOpenUseCase` | 스토어 오픈 이벤트 + `StoreOpenNotificationCreateEvent` 발행 |
| `PaymentRelevantInfoUseCase` / `PaymentReportUseCase` | 결제 진행 정보 |
| `ComingSoonApplicantUserCreateUseCase` / `ComingSoonApplicantUserDeleteUseCase` | 오픈예정 신청자 생성·삭제 |

> **외 약 180개** UseCase 클래스 — `story`, `campaign`, `dashboard`, `statistic`, `globalproject` 등의 세부 서브패키지에 분산. 전수 목록은 각 패키지 소스 디렉터리 참조.

---

## 4. 주요 Gateway 포트 인벤토리

> 메서드 수는 세미콜론(`;`) 라인 수 기반 근사치.

| Gateway 인터페이스 | 패키지 | 메서드 수(근사) | 역할 |
|---|---|---|---|
| `BackingPaymentQueryGateway` | `backing.payment` | ~15 | 결제 조회 (핵심 읽기 포트) |
| `BackingPaymentGateway` | `backing.payment` | ~13 | 결제 쓰기 (핵심 쓰기 포트) |
| `CampaignQueryGateway` | `campaign` | ~24 | 캠페인 조회 (가장 많은 메서드) |
| `CampaignGateway` | `campaign` | ~6 | 캠페인 쓰기 |
| `GlobalProjectQueryGateway` | `globalproject` | ~11 | 글로벌 프로젝트·분배·배분 조회 |
| `AnnouncementQueryGateway` | `announcement` | ~12 | 공지 조회 |
| `AnnouncementGateway` | `announcement` | ~12 | 공지 쓰기 |
| `OrderSessionRedisGateway` | `order.session` | ~6 | 주문 세션 Redis CRUD |
| `OrderSheetRedisGateway` | `order.sheet` | ~3 | 주문서 Redis CRUD |
| `WishGateway` | `wish` | ~11 | 찜 쓰기 |
| `WishQueryGateway` | `wish` | ~7 | 찜 조회 |
| `RewardEventGateway` | `rewardevent` | ~12 | 리워드 이벤트 쓰기 |
| `RewardEventQueryGateway` | `rewardevent` | ~10 | 리워드 이벤트 조회 |
| `StoryCopyGateway` | `story.copy` | ~15 | 스토리 복사 쓰기 |
| `SimplePayGateway` | `simplepay` | ~8 | 간편결제 쓰기 |
| `MakerInvitationGateway` | `makerinvitation` | ~6 | 메이커 초대 쓰기 |
| `MakerInvitationQueryGateway` | `makerinvitation` | ~3 | 메이커 초대 조회 |
| `ProjectDataplusGateway` | `statistic.dataplus` | ~7 | 통계 DataPlus 외부 연동 |
| `MakerDashboardQueryGateway` | `dashboard` | ~6 | 메이커 대시보드 조회 |
| `ShippingQueryGateway` | `shipping` | ~5 | 배송 조회 |
| `NewsQueryGateway` | `news` | ~6 | 새소식 조회 |
| `NewsGateway` | `news` | ~3 | 새소식 쓰기 |
| `SettlementGateway` | `settlement` | ~4 | 정산 쓰기 |
| `ErpSettlementGateway` | `settlement.erp` | ~4 | ERP 정산 쓰기 |
| `OrderPaymentGateway` | `orderpayment` | ~4 | 결제 승인 쓰기 |
| `SignatureGateway` | `signature` | ~1 | 서명 쓰기 |
| `SignatureQueryGateway` | `signature` | ~2 | 서명 조회 |
| `ComingSoonApplicantGateway` | `comingsoonapplicant` | ~3 | 오픈예정 신청자 쓰기 |
| `EventDispatcher` | `event` (루트) | 1 (`dispatch(Object)`) | 인-프로세스 이벤트 발행 포트 |
| `TranslateGateway` | `support.translate` | — | 번역 외부 연동 포트 |
| `CountryGateway` | `support.country` | — | 국가 정보 조회 포트 |
| `CarrierGateway` | `support.carrier` | — | 택배사 정보 조회 포트 |

> 도메인 Gateway 총 163개, support Gateway 4개. 위 표는 비즈니스 비중이 높은 것만 발췌.

---

## 5. 도메인 이벤트

### 5.1 EventDispatcher 포트

```java
// event/EventDispatcher.java
public interface EventDispatcher {
  void dispatch(Object event);
}
```

`@UseCase` 클래스가 `EventDispatcher`를 주입받아 인-프로세스 이벤트를 발행한다.
구현체(`ApplicationEventPublisher` 래퍼 등)는 `adapter/infrastructure` 또는 `bootstrap` 계층에 위치 (이 모듈 밖).

### 5.2 발행되는 이벤트 클래스 (관찰 가능 26종)

| 이벤트 클래스 | 발행 UseCase | 도메인 영역 |
|---|---|---|
| `WishCreateEvent` | `WishCreateUseCase`, `ComingSoonApplicantUserCreateUseCase` | 찜 |
| `WishDeleteEvent` | `WishDeleteUseCase`, `ComingSoonApplicantUserDeleteUseCase` | 찜 |
| `ComingSoonApplicantUserCreateEvent` | `ComingSoonApplicantUserCreateUseCase` | 오픈예정 |
| `ComingSoonApplicantUserDeleteEvent` | `ComingSoonApplicantUserDeleteUseCase` | 오픈예정 |
| `StoreOpenNotificationCreateEvent` | `StoreOpenUseCase` | 스토어 이벤트 |
| `FollowActivityEvent` | `OrderPaymentUsecase`, `CancelPaymentUsecase` | 팔로우 |
| `CampaignCongratulationHistoryEvent` | `OrderPaymentUsecase` | 캠페인 축하 |
| `SendPaymentBrazeEvent` | `CancelPaymentUsecase` | 결제 취소 알림 (Braze) |
| `MembershipDiscountNotifyEvent` | `OrderPaymentUsecase`, `CancelPaymentUsecase` | 멤버십 할인 알림 |
| `CancelPaymentLogEvent` | `ReservationPayCancelProcessor`, `NowPayCancelProcessor`, `ScheduledPaymentCancelProcessor` | 결제 취소 로그 |
| `CreateNewsEvent` | `CreateNewsUseCase` | 새소식 |
| `ModifyNewsEvent` | `ModifyNewsUseCase` | 새소식 수정 |
| `PostNewsEvent` | `CreateNewsUseCase`, `ModifyNewsUseCase` | 새소식 게시 |
| `CreateAnnouncementEvent` | `CreateAnnouncementUseCase` | 공지 |
| `ModifyAnnouncementEvent` | `ModifyAnnouncementUseCase` | 공지 수정 |
| `ModifyAnnouncementByMenuEvent` | `ModifyAnnouncementByMenuUseCase` | 메뉴별 공지 수정 |
| `ModifyAnnouncementContentsEvent` | `ModifyAnnouncementContentsUseCase` | 공지 내용 수정 |
| `NewsNotificationSetupDenyEvent` | `NewsNotificationSetupDenyUseCase` | 새소식 수신거부 |
| `CreateBillkeyEvent` | `CreateBillkeyUseCase` | 빌키 생성 |
| `UseBillkeyEvent` | `UseBillkeyUseCase` | 빌키 사용 |
| `BillkeyVerificationEvent` | `BillkeyVerificationUseCase` | 빌키 검증 |
| `RemoveBillkeyEvent` | `RemoveBillkeyUseCase` | 빌키 삭제 |
| `BillkeyDetailEvent` | `BillkeyDetailUseCase` | 빌키 조회 |
| `RegisterPasscodeEvent` | `RegisterPasscodeUseCase` | 비밀번호 등록 |
| `SaveIPLicenseEvent` | `SaveIPLicenseUseCase` | IP라이선스 저장 |
| `SetupTagEvent` / `SetupTopRankEvent` | `SetupTagUseCase` / `SetupTopRankUseCase` | IP 태그·랭킹 |

> `PackagePlanBulkChangedEvent` (`studio.pricing.event` 하위) — Javadoc에 "요금제 일괄 변경 이벤트"로 명시. `dispatch` 호출 사이트는 이 모듈 내에서 직접 관찰되지 않음; 배치 처리 후 발행 가능성 있음.

### 5.3 Kafka 이벤트

Kafka 관련 Producer/Consumer 설정은 `adapter/infrastructure` 및 `bootstrap` 계층에 위치하며 이 모듈 범위 밖이다.

---

## 6. 주요 Enum·상수

### 결제·주문

| Enum | 값 | 설명 |
|---|---|---|
| `ApproveStatus` | `CONFIRMED`, `DENIED`, `PENDING` | 결제 승인 상태 (`orderpayment.approvestatus`) |
| `ApprovalStatus` | `APPROVAL`, `APPROVAL_FAIL`, `APPROVAL_CANCEL`, `APPROVAL_CANCEL_FAIL` | 빌키 승인 상태 (`billkey`) |
| `ServiceType` | `NONE`, `FUNDING`, `FUNDING_EC`, `FUNDING_IP`, `FUNDING_EC_IP`, `FUNDING_AUTH`, `FUNDING_IP_AUTH`, `FUNDING_EC_AUTH`, `FUNDING_EC_IP_AUTH`, `FUNDING_LONG_TERM_INSTALLMENT_AUTH`, `FUNDING_EC_LONG_TERM_INSTALLMENT_AUTH`, `FUNDING_GLOBAL_AUTH`, `FUNDING_EC_GLOBAL_AUTH`, `GLOBAL_STRIPE_FUNDING`, `GLOBAL_STRIPE_PREORDER`, `GLOBAL_ALIPAY_FUNDING`, `GLOBAL_ALIPAY_PREORDER` | 결제 서비스 유형 (PG·EC·글로벌 분기 포함) |
| `ResultCode` | — (소스에 존재; 값 목록 확인 필요) | 백킹 결제 결과 코드 (`backing.payment`) |
| `ResultType` | — | 취소 결과 유형 (`paymentcancel.dto`) |
| `ExternalInfoType` | — | PG 외부 정보 유형 (`backing.paymentexternalinfo`) |
| `PaymentKeyType` | — | 결제 키 유형 (`payment.saveextrainfo`) |
| `FailureType` | — | 주문 세션 실패 유형 (`order.session`) |
| `SimplePayErrorCode` | — | 간편결제 에러 코드 (`simplepay`) |
| `SimplePayLogType` | — | 간편결제 로그 유형 (`simplepay`) |

### 정산

| Enum | 값 | 설명 |
|---|---|---|
| `SettlementStatus` | `A10`(수수료 선택), `A20`(수수료 결정), `A30`(수수료 확정), `B10`(내역서 발송 대기중), `B20`(입금요청서 제출 대기중), `B30`(입금요청서 제출 완료), `C10`(정산금 지급대기중), `C20`(정산금 지급완료), `C30`(정산금 지급대기중), `D10`(정산금 지급완료), `B00`·`B01`·`B11`·`B21`·`B31`(정산 2.0), `WAIT`(배송·반환 완료 대기중), `HOLD`(정산 일시중지), `STOP`(정산 이슈 종료) | 정산 진행 상태 (2.0 버전 상태 포함) |
| `FeeProposalStatus` | `STORED`(저장), `SUBMITTED`(상신), `IN_PROGRESS`(진행), `CONCLUDED`(종결), `REJECTED`(반려), `CANCEL`(취소), `HOLD`(보류), `ARCHIVE`(보관), `ERROR`(에러) | ERP 수수료 품의 상태 |
| `SettlementResultState` | — | 지급 결과 상태 |
| `SettlementResultStep` | — | 지급 결과 단계 |
| `SettlementResultCode` | — | 지급 결과 코드 |
| `SettlementCode` | — | 정산 코드 |
| `SystemType` | — | 정산 시스템 유형 |
| `SlipExcelType` | — | 전표 Excel 유형 |
| `TaxInvoiceExcelType` | — | 세금계산서 Excel 유형 |
| `FundingType` | — | 펀딩 유형 (Excel) |
| `FeeCategory` | — | 수수료 카테고리 |
| `FeeFormat` | — | 수수료 포맷 |
| `EnteredType` | — | 입력 유형 (ERP) |

### 배송·오픈예정

| Enum | 값 | 설명 |
|---|---|---|
| `DeliveryStatus` | `PENDING`(미발송), `PREPARING_FOR_DELIVERY`(발송준비중), `CHECKING_RECEIPT`(수령확인중), `INVOICE_VALIDATING`(발송확인중), `PROCESS_DELIVERY`(발송처리중), `STAND_BY_TRANSIT`(배송대기중), `IN_TRANSIT`(배송중), `DELIVERED`(배송완료) | 배송 상태 (`isCompletedShipping` 플래그 포함) |
| `DeliveryType` | — | 배송 유형 |
| `ComingSoonStatus` | `APPLY`, `STANDBY`, `IN_PROGRESS`, `END_OF_PROGRESS`, `ABORT`, `CANCEL_APPLICATION` | 오픈예정 상태 |

### 리워드·스크리닝

| Enum | 값 | 설명 |
|---|---|---|
| `LimitType` | — | 리워드 한정 유형 |
| `OptionType` | — | 리워드 옵션 유형 |
| `OfferingTime` | — | 배송 시점 유형 |
| `RewardLimitedHistoryType` | — | 한정 수량 이력 유형 |
| `ServiceRequestStatus` | `NOT_REQUESTED`(미신청), `PENDING`(대기), `APPROVED`(승인), `REJECTED`(반려) | 부가서비스 요청 상태 |
| `PdScreeningStatus` | `BEFORE_PD_SCREENING`(스크리닝 전), `PD_APPROVAL`(승인), `PD_REJECT`(담당자 반려), `PD_REJECT_FEEDBACK`(반려) | PD 심사 상태 |
| `EventBenefitType` | — | 리워드 이벤트 혜택 유형 |
| `EventActionType` | — | 리워드 이벤트 액션 유형 |
| `EventTargetType` | — | 리워드 이벤트 대상 유형 |

### 새소식·알림

| Enum | 값 | 설명 |
|---|---|---|
| `NewsNotificationStatus` | `PENDING`, `STARTED`, `COMPLETED`, `FAILED` | 새소식 알림 처리 상태 |
| `NewsNotificationTargetType` | — | 알림 대상 유형 |
| `NotificationType` | — | 알림 유형 |
| `NewsType` | — | 새소식 유형 |
| `DisplayStoryStatus` | — | 스토리 표시 상태 |
| `NewsTagType` | — | 새소식 태그 유형 |
| `NewsRestrictReason` | — | 새소식 제한 사유 |
| `StoreOpenNotificationStatus` | `PENDING`, `START`, `COMPLETE`, `FAIL` | 스토어 오픈 알림 상태 |

### 스토리·번역

| Enum | 값 | 설명 |
|---|---|---|
| `TranslationStatus` | `A00`(제출 번역 대기중), `A10`(제출 번역중), `A11`(제출 번역 요청 실패), `B00`~`B11`(글로벌 스토리 재번역), `C10`(번역 완료), `C11`(번역 실패), `D00`~`D99`(진행중 스토리 번역), `E00`~`E11`(최종 심사 번역) | 번역 상태 (계층 구조 14단계) |
| `TranslationStatus.TranslationStatusGroup` | — | 번역 상태 그룹 |
| `TranslationRequestStatus` | — | 번역 요청 상태 |
| `TranslationTargetType` | — | 번역 대상 유형 |
| `MessageType` | — | 메시지 유형 |

### 메이커 초대·멤버십

| Enum | 값 | 설명 |
|---|---|---|
| `MakerInvitationStatus` | `REGISTERED_CODE`(추천 코드 등록), `PROCESSING_BENEFIT_PAYMENT`(혜택 지급 처리 중), `PAID_BENEFIT`(혜택 지급 완료), `ALREADY_PAID_OTHER_INVITATION`(혜택 지급 미대상), `ALREADY_OPENED_OTHER_PROJECT`(혜택 지급 미대상) | 메이커 초대 코드 상태 |
| `MakerInvitationBenefitType` | — | 초대 혜택 유형 |
| `MakerInvitationBenefitGradeType` | — | 초대 혜택 등급 |
| `MakerInvitationUserType` | — | 초대 유저 유형 |
| `MakerInvitationBenefitReasonType` | — | 초대 혜택 사유 유형 |
| `MembershipState` | — | 멤버십 상태 |
| `BenefitType` | `SHIPPING_FEE`, … | 멤버십 혜택 유형 |
| `MembershipServiceType` | — | 멤버십 서비스 유형 |
| `UseBenefit` | `USE`, `CANCEL` | 멤버십 혜택 사용·취소 |

### 기타

| Enum | 값 | 설명 |
|---|---|---|
| `UserStatus` | `NM`(정상), `IA`(휴면), `DO`(탈퇴) | 유저 상태 |
| `ProjectStatus` | — | 메이커 MY 프로젝트 상태 |
| `ProjectPhase` | — | 프로젝트 단계 |
| `CertState` | — | K-인증 상태 |
| `KCProviderType` | — | K-인증 제공자 유형 |
| `SpaceExhibitionStatus` | — | 공간전시 상태 |
| `PackagePlanType` | — | 요금제 유형 |
| `PackagePlanChangeType` | — | 요금제 변경 유형 |
| `StudioSectionType` | — | 스튜디오 섹션 유형 |
| `SectionStatus` | — | 섹션 상태 |
| `DashboardExposureLevel` | — | 대시보드 노출 레벨 |
| `GranularityType` | — | 통계 집계 단위 |
| `AggregationType` | — | 통계 집계 유형 |
| `DeviceType` | — | 디바이스 유형 (`support.data`) |

> 위 표에서 "—"로 표기된 enum 값은 소스 파일이 존재하나 이 문서에서 전수 나열을 생략. 소스 직접 확인 권장.

---

## 7. Exception 계층

### 7.1 기반 인터페이스·클래스

```
com.wadiz.api.funding.exception
├── ErrorCode                        (interface) — code + message 제공
├── ErrorCodeProvider                (interface) — ErrorCode getter + clientMessage + additionalParameters
├── ValidationFailureException       (extends javax.validation.ValidationException, implements ErrorCodeProvider)
│   └── CampaignEndedException       (extends ValidationFailureException)
├── EntityNotFoundException          (extends RuntimeException, implements ErrorCodeProvider)
├── EntityAlreadyExistException      (extends RuntimeException, implements ErrorCodeProvider)
├── InvalidStateException            (extends RuntimeException, implements ErrorCodeProvider)
└── AccessDeniedException            (extends RuntimeException, implements ErrorCodeProvider)
    └── AdultContentAccessDeniedException  (내부 클래스 in AdultContentAccessValidator)
```

> `IntegrityConstraintViolationException`은 `Validators.requireValid()`에서 참조되나, 소스 파일이 `exception/` 패키지에서 직접 관찰되지 않음. `validators` 패키지 내부에 위치하거나 `funding-core` jar에 있을 가능성 — 확인 불가.

### 7.2 각 예외 클래스 역할

| 클래스 | 용도 | 비고 |
|---|---|---|
| `ValidationFailureException` | 비즈니스 규칙 위반 (주문 금액 부족, 세션 만료, 재고 소진 등) | `ErrorCode`를 담아 클라이언트 메시지 전달 가능; `@Deprecated` 생성자(String만)도 존재 |
| `CampaignEndedException` | 종료된 캠페인에 대한 접근 | `ValidationFailureException` 하위; 특정 캠페인 종료 상황 표현 |
| `EntityNotFoundException` | 엔티티를 찾을 수 없을 때 | `ErrorCode` 또는 code/message 조합 생성자 |
| `EntityAlreadyExistException` | 이미 존재하는 엔티티 중복 생성 시도 | 호환성 유지 주석 있음 |
| `InvalidStateException` | 유효하지 않은 상태 전이 또는 상태 불일치 | `ErrorCode` 담기 가능 |
| `AccessDeniedException` | 권한 없는 접근 (성인 인증 필요 포함) | `AdultContentAccessDeniedException` 내부 하위 클래스로 확장 |

### 7.3 도메인별 로컬 ErrorCode Enum

각 도메인 패키지에 `ErrorCode` 인터페이스를 구현하는 enum이 흩어져 있다.

| 도메인 | 로컬 ErrorCode enum |
|---|---|
| `order` | `OrderErrorCode` (예: `EXPIRED_ORDER_SESSION`, `INVALID_MINIMUM_PAY_AMOUNT`) |
| `rewardevent` | `EventErrorCode` |
| `comingsoonapplicant` | `ComingSoonApplicantErrorCode` |
| `simplepay` | `SimplePayErrorCode` |
| `additionalservice` (내 exception) | `AdditionalServiceStateException` |
| `validators` | `AdultContentErrorCode` (`ADULT_VERIFICATION_REQUIRED`) |

---

## 8. Validators

### 8.1 Validators 유틸 클래스

`validators/Validators.java` — 정적 Bean Validation 헬퍼.

```java
public final class Validators {
  public static <T> T requireValid(T object)           // ConstraintViolation 시 IntegrityConstraintViolationException 던짐
  public static <T> T requireValid(T object, String message)
  public static <T> Set<ConstraintViolation<T>> validate(T object, Class<?>... groups)
  public static <T> Set<ConstraintViolation<T>> validateProperty(...)
  public static <T> Set<ConstraintViolation<T>> validateValue(...)
}
```

### 8.2 커스텀 Bean Validation 어노테이션

| 어노테이션 (`constraints/`) | Validator 클래스 (`constraintvalidators/`) | 검증 대상 | 검증 내용 |
|---|---|---|---|
| `@ManagerListQueryChecker` | `ManagerListQueryCheckerValidator` | `ManagerListQuery` | `userId`와 `name` 둘 다 null이면 invalid |
| `@PostedNewsChecker` | `PostedNewsCheckerValidator` | `PostedNewsCommand` | 임시저장(`isTemporary=true`)이 아닌 경우 `tagType`이 필수 |
| `@UserListQueryChecker` | `UserListQueryCheckerValidator` | `UserListQuery` | `userIds`와 `keyword` 중 최소 하나 필수; `keyword`가 있으면 `keywordType`도 필수 |
| `@UserWishListQueryChecker` | `UserWishListQueryCheckerValidator` | `UserWishListQuery` | `projects` 목록의 `projectType`이 유효한 값 목록 내에 있어야 함 |

### 8.3 AdultContentAccessValidator (`validators/`)

`@Helper` 스테레오타입. 성인 콘텐츠 접근 제어 로직.

- `validateOrThrow(ProjectType, projectNo, userId)` — 성인 인증 미완료 시 `AdultContentAccessDeniedException` 던짐
- `ProjectType` enum: `FUNDING`, `STORE`
- 내부적으로 `GlobalProjectQueryGateway` / `StoreProjectQueryGateway` / `CampaignCategoryQueryGateway` / `UserQueryGateway` 사용

---

## 9. support 패키지 유틸

| 클래스/인터페이스 | 패키지 | 역할 |
|---|---|---|
| `Pages`, `PageResult`, `SliceResult`, `Sorts` | `support.data` | 페이징·정렬 공통 추상화 |
| `ServiceType` (enum) | `support.data` | 결제 서비스 유형 분기 로직 내장 (위 §6 참조) |
| `ServiceTypeCondition` | `support.data` | `ServiceType.getServiceType()` 입력 조건 VO |
| `PrivacyDataMasker`, `CardNumberMaskingUtils` | `support.data` | 개인정보·카드번호 마스킹 |
| `SecuritySupport` | `support.security` | 도메인 내 보안 컨텍스트 지원 |
| `CountryFinder` | `support.country` | 국가 코드 → `CountryResult` 변환 (`CountryGateway` 사용) |
| `CarrierFinder` | `support.carrier` | 택배사 코드 변환 (`CarrierGateway` 사용) |
| `Translator` | `support.translate` | HTML/텍스트/이미지/AI 번역 지원 (`TranslateGateway` 사용) |
| `ErpEncryptUtil`, `JsonUtil` | `support.util` | ERP 암호화·JSON 유틸 |

---

> 본 문서는 `core/domain` 모듈 소스에서 직접 관찰 가능한 내용만 기록한다.
> UseCase 구현체의 세부 분기 로직이나 Gateway 구현체의 SQL은
> 각각 이 모듈 내부 소스와 `adapter/infrastructure` 소스를 기준으로 확인해야 한다.
