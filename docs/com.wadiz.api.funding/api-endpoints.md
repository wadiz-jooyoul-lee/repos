# com.wadiz.api.funding — 전체 REST 엔드포인트 목록

`adapter/application` 모듈의 모든 `@*Mapping` 어노테이션을 파싱해서 작성한 전체 REST 엔드포인트 목록.
경로 그룹(Public / Internal / Studio / Admin / Global / Native)별로 그룹화했다.

- 상세 Request/Response 스펙 및 DB 쿼리는 `api-details/{domain}.md` 참조
- 프로젝트 아키텍처·도메인 개요는 `com.wadiz.api.funding.md` 참조

---

## 1. 주문 · 결제

### Order — `order/OrderController` (`/api/orders`)
| Method | Path | 메서드 목적 |
|---|---|---|
| POST | `/api/orders/session` | 주문 세션 생성 |
| GET | `/api/orders/session/{token}` | 주문 세션 조회 |
| GET | `/api/orders/closed-session/{token}` | 종료된 주문 세션 조회 |
| POST | `/api/orders/sheet/{token}` | 주문서 생성 |
| DELETE | `/api/orders/sheet/{token}` | 주문서 삭제 |

### OrderPayment — `orderpayment/OrderPaymentController` (`/api/order-payment`)
| Method | Path |
|---|---|
| POST | `/api/order-payment/{payType}/{campaignId}/{token}` (NICE 인증 콜백) |
| GET | `/api/order-payment/{payType}/{token}/pay-via-stripe` |
| POST | `/api/order-payment/alipay/{token}/callback-bypass` |
| POST | `/api/order-payment/{token}/pay-zero` |
| GET | `/api/order-payment/{token}/approve-status` |

### OrderPayment Admin — `orderpayment/AdminOrderPaymentController` (`/api/admin`)
| Method | Path |
|---|---|
| POST | `/api/admin/immediate-approve` |
| POST | `/api/admin/cancel-payment` |

### Payment Internal — `payment/PaymentInternalController` (`/api/internal/payments`)
| Method | Path |
|---|---|
| GET | `/api/internal/payments` |
| POST | `/api/internal/payments/congratulation` |
| POST | `/api/internal/payments/extra-info` |
| POST | `/api/internal/payments/card-registration` |
| POST | `/api/internal/payments/billkey-verifications` |

### Payment Cancel — `paymentcancel/CancelPaymentController` / `CancelPaymentInternalController`
| Method | Path |
|---|---|
| POST | `/api/cancel-payment` |
| POST | `/api/internal/cancel-payment/bulk` |
| POST | `/api/internal/cancel-payment/bulk/payment-gateway` |

### Payment Progress
| Method | Path | Controller |
|---|---|---|
| GET | `/api/payment-progress/campaigns/{campaignId}/relevant-info` | `PaymentProgressController` |
| GET | `/api/studio/payment-progress/campaigns/{campaignId}/report` | `PaymentProgressStudioController` |

### Billkey / SimplePay
| Method | Path | Controller |
|---|---|---|
| POST | `/api/internal/billkey/card-expire-verification` | `BillkeyInternalController` |
| POST | `/api/simple-pay/card` | `SimplePayController` |
| GET | `/api/simple-pay/card` | `SimplePayController` |
| DELETE | `/api/simple-pay/card` | `SimplePayController` |
| POST | `/api/simple-pay/{token}/passcode` | `SimplePayController` |
| POST | `/api/internal/simple-pay/billkey` | `SimplePayInternalController` |
| POST | `/api/internal/simple-pay/verify` | `SimplePayInternalController` |

---

## 2. 펀딩 참여 · 서포터

### Supporter — `supporter/SupporterController` (`/api/supporters`)
| Method | Path |
|---|---|
| GET | `/api/supporters/my/shipping-addresses/latest` |
| GET | `/api/supporters/my/recent-pay-by` |
| GET | `/api/supporters/my/fundings` |
| GET | `/api/supporters/my/fundings/{backingPaymentId}` |
| PUT | `/api/supporters/my/fundings/{backingPaymentId}/shipping-address` |
| PUT | `/api/supporters/my/fundings/{backingPaymentId}/pay-by` |

### Supporter Internal — `supporter/SupporterInternalController` (`/api/internal/supporters`)
| Method | Path |
|---|---|
| GET | `/api/internal/supporters/my-encore` |
| GET | `/api/internal/supporters/my/fundings/unwritten-satisfaction/{userId}` |
| GET | `/api/internal/supporters/{userId}/shipping-qty` |

### Funding — `funding/FundingController` / `FundingInternalController`
| Method | Path |
|---|---|
| GET | `/api/fundings/qty` |
| GET | `/api/fundings/qty/my` |
| GET | `/api/fundings/{campaignId}/is-asked-encore` |
| POST | `/api/internal/fundings/qtys/by-user` |
| POST | `/api/internal/fundings/{campaignId}/qtys/by-user` |
| GET | `/api/internal/fundings/qty` |

### Refund
| Method | Path | Controller |
|---|---|---|
| GET | `/api/refund/my/{campaignId}/detail` | `refund/RefundController` |

---

## 3. 캠페인(프로젝트)

### Campaign — `campaign/CampaignController` (`/api/campaigns`, `/api/v1/campaigns`)
| Method | Path |
|---|---|
| GET | `/api/campaigns/card` |
| GET | `/api/campaigns/comingsoon/card` |
| GET | `/api/campaigns/{campaignId}/statistics-summation` |
| POST | `/api/campaigns/card/base-info` |
| GET | `/api/campaigns/{campaignId}/detail` |
| GET | `/api/campaigns/{campaignId}/summary` |
| GET | `/api/campaigns/{campaignId}/tags` |
| GET | `/api/campaigns/{campaignId}/status` |
| GET | `/api/campaigns/{campaignId}/pre-reservation-info` |

### Campaign Internal — `campaign/CampaignInternalController` (`/api/internal/campaigns`)
| Method | Path |
|---|---|
| GET | `/api/internal/campaigns/{campaignId}/base-info` |
| GET | `/api/internal/campaigns/{campaignId}/makers/{userId}` |
| GET | `/api/internal/campaigns/maker-business-info` |

### Campaign Studio — `campaign/CampaignStudioController` (`/api/studio/campaigns/{campaignId}`)
| Method | Path |
|---|---|
| GET | `/api/studio/campaigns/{campaignId}/payment-summation` |
| GET | `/api/studio/campaigns/{campaignId}/base-info` |

### Project Internal — `campaign/internal/ProjectInternalController` (`/api/internal/projects`)
| Method | Path |
|---|---|
| GET | `/api/internal/projects/by-userId` |
| POST | `/api/internal/projects` |

### Campaign Submit / Final Review / Hidden
| Method | Path |
|---|---|
| POST | `/api/studio/submit/{projectNo}/approval` |
| POST | `/api/internal/campaign-final-review/{projectNo}/process` |
| POST | `/api/internal/campaigns/{campaignId}/hidden` |
| POST | `/api/internal/campaigns/{campaignId}/shown` |

### Native App — `campaign/nativeapp/NativeProjectController` (`/api/native/v1/projects`)
| Method | Path |
|---|---|
| GET | `/api/native/v1/projects/{projectNo}` |

### Global — `campaign/global/GlobalProjectController` (`/api/global/projects`)
| Method | Path |
|---|---|
| GET | `/api/global/projects/{projectNo}` |
| GET | `/api/global/projects/{projectNo}/story` |
| GET | `/api/global/projects/{projectNo}/coming-soon-story` |
| GET | `/api/global/projects/{projectNo}/maker` |
| GET | `/api/global/projects/{projectNo}/shipping-countries` |
| GET | `/api/global/projects/{projectNo}/refund-policy` |
| GET | `/api/global/projects/{projectNo}/product-info-notice` |
| GET | `/api/global/projects/{projectNo}/supporters` |
| GET | `/api/global/projects/{projectNo}/activity-counts` |
| GET | `/api/global/projects/{projectNo}/funding-status` |
| GET | `/api/global/projects/{projectNo}/activity/my` |
| GET | `/api/global/projects/{projectNo}/satisfaction/display-status` |
| GET | `/api/global/projects/{projectNo}/funding-pause` |
| GET | `/api/global/projects/{projectNo}/hidden` |
| GET | `/api/global/projects/{projectNo}/distribution` |
| GET | `/api/global/projects/{projectNo}/ai-summary` |

### Global Project Internal — `campaign/global/GlobalProjectInternalController` (`/api/internal/global/projects`)
| Method | Path |
|---|---|
| GET | `/api/internal/global/projects/{projectNo}` |
| DELETE | `/api/internal/global/projects/{projectNo}/ai-summary/cache` |
| DELETE | `/api/internal/global/projects/ai-summary/cache` |

### Campaign Category
| Method | Path |
|---|---|
| GET | `/api/campaign-category/` |

---

## 4. 리워드

### RewardItem / RewardPolicy / RefundPolicy
| Method | Path | Controller |
|---|---|---|
| GET | `/api/reward-items/campaigns/{campaignId}` | `RewardItemController` |
| GET | `/api/reward-policy/campaigns/{campaignId}` | `RewardPolicyController` |
| GET | `/api/refund-policy/campaigns/{campaignId}/detail` | `RewardRefundPolicyController` |
| GET | `/api/product-info-notice/campaigns/{campaignId}` | `ProductInfoNoticeController` |
| GET | `/api/product-info-notice/categories` | `ProductInfoNoticeController` |
| GET | `/api/product-info-notice/campaigns/{campaignId}/detail` | `ProductInfoNoticeController` |

### Reward Admin — `reward/RewardAdminController` / `RewardLimitedTimeAdminController` (`/api/admin/rewards`)
| Method | Path |
|---|---|
| GET | `/api/admin/rewards/campaigns/{campaignId}` |
| GET | `/api/admin/rewards/limit-time/campaigns/{campaignId}` |
| GET | `/api/admin/rewards/limit-time/history/campaigns/{campaignId}` |
| POST | `/api/admin/rewards/{rewardId}/limit-time` |
| PUT | `/api/admin/rewards/{rewardId}/limit-time` |
| DELETE | `/api/admin/rewards/{rewardId}/limit-time` |

### Global Project Reward — `reward/global/GlobalProjectRewardController` (`/api/global/projects/{projectNo}/rewards`)
| Method | Path |
|---|---|
| GET | `/api/global/projects/{projectNo}/rewards/by-country` |
| GET | `/api/global/projects/{projectNo}/rewards/{rewardId}` |

### Reward Change Log Internal — `rewardchangelog/RewardChangeLogInternalController` (`/api/internal/reward-change-logs`)
| Method | Path |
|---|---|
| POST | `/api/internal/reward-change-logs` |
| GET | `/api/internal/reward-change-logs/campaigns/{campaignId}/rewards/{rewardId}` |
| GET | `/api/internal/reward-change-logs/campaigns/{campaignId}/rewards/{rewardId}/summaries` |
| GET | `/api/internal/reward-change-logs/campaigns/{campaignId}/summaries` |
| GET | `/api/internal/reward-change-logs/{id}` |

### Reward Event — `rewardevent/EventController` (`/api/event`)
| Method | Path |
|---|---|
| POST | `/api/event/{eventKeyword}/entry` |
| POST | `/api/event/{eventKeyword}/benefit` |
| POST | `/api/event/{eventKeyword}/random-benefit` |
| GET | `/api/event/{eventKeyword}/participant` |
| GET | `/api/event/participant` |
| GET | `/api/event/{eventKeyword}/participation-aggregation` |
| GET | `/api/event/{eventKeyword}` |
| GET | `/api/event/benefits` |

### Reward Event Admin — `rewardevent/EventAdminController` (`/api/admin/events`)
| Method | Path |
|---|---|
| GET | `/api/admin/events` |
| POST | `/api/admin/events` |
| DELETE | `/api/admin/events/{eventNo}` |
| GET | `/api/admin/events/{eventNo}` |
| PUT | `/api/admin/events/{eventNo}` |
| POST | `/api/admin/events/fixed-benefit` |
| GET | `/api/admin/events/fixed-benefit/{eventNo}` |
| PUT | `/api/admin/events/fixed-benefit/{eventNo}` |
| POST | `/api/admin/events/random-benefit` |
| GET | `/api/admin/events/random-benefit/{eventNo}` |
| PUT | `/api/admin/events/random-benefit/{eventNo}` |

---

## 5. 정산 (Settlement)

### Settlement Studio — `settlement/SettlementStudioController` (`/api/studio/campaigns/{campaignId}`)
| Method | Path |
|---|---|
| GET | `/api/studio/campaigns/{campaignId}/settlement` |
| GET | `/api/studio/campaigns/{campaignId}/settlement-statement/download` |
| GET | `/api/studio/campaigns/{campaignId}/settlement-statement` |
| GET | `/api/studio/campaigns/{campaignId}/fees` |
| GET | `/api/studio/campaigns/{campaignId}/settlement-system` |
| GET | `/api/studio/campaigns/{campaignId}/fee-version` |
| GET | `/api/studio/campaigns/{campaignId}/v2/fees` |

### Settlement Internal — `settlement/SettlementInternalController` (`/api/internal/settlement`)
| Method | Path |
|---|---|
| GET | `/api/internal/settlement/{campaignId}/maker-info` |
| GET | `/api/internal/settlement/{campaignId}/package-plan` |
| GET | `/api/internal/settlement/fee-proposals` |
| GET | `/api/internal/settlement/fees` |
| GET | `/api/internal/settlement/settlement-statement` |
| GET | `/api/internal/settlement/settlement-statement/download` |
| GET | `/api/internal/settlement/settlement-result-state` |
| GET | `/api/internal/settlement/is-split` |
| GET | `/api/internal/settlement/{campaignId}/settlement-system` |
| GET | `/api/internal/settlement/{campaignId}/fee-version` |
| GET | `/api/internal/settlement/{campaignId}/v2/fees` |

### Settlement Admin — `settlement/SettlementAdminController` (`/api/admin/settlement`)
| Method | Path |
|---|---|
| GET | `/api/admin/settlement/fees` |
| GET | `/api/admin/settlement/fee-proposals` |
| GET | `/api/admin/settlement` |
| GET | `/api/admin/settlement/adCost` |
| GET | `/api/admin/settlement/campaigns/{campaignId}/fee-version` |
| GET | `/api/admin/settlement/campaigns/{campaignId}/v2/fees` |

### Studio Pricing — `studio/pricing/StudioPricingController` (`/api/studio/pricing`)
| Method | Path |
|---|---|
| GET | `/api/studio/pricing/{projectNo}` |
| POST | `/api/studio/pricing/{projectNo}` |
| POST | `/api/studio/pricing/{projectNo}/determine` |

### Outstanding — `outstanding/OutstandingAdmController`
| Method | Path |
|---|---|
| GET | `/api/admin/outstandings/{campaignId}` |

---

## 6. 배송 (Shipping)

| Method | Path | Controller |
|---|---|---|
| GET | `/api/studio/shipping/campaigns/{campaignId}/countries` | `ShippingStudioController` |
| GET | `/api/studio/shipping/campaigns/{campaignId}/export-declaration/excel` | `ShippingStudioController` |
| GET | `/api/internal/shipping/campaigns/{campaignId}/status` | `ShippingInternalController` |

---

## 7. 새소식 · 알림 (News / Notification)

### News — `news/NewsController` (`/api/campaigns/{campaignId}/news`)
| Method | Path |
|---|---|
| GET | `/api/campaigns/{campaignId}/news` |
| GET | `/api/campaigns/{campaignId}/news/qty` |
| GET | `/api/campaigns/{campaignId}/news/{newsId}` |

### News Studio — `news/NewsStudioController` (`/api/studio/campaigns/{campaignId}/news`)
| Method | Path |
|---|---|
| POST | `/api/studio/campaigns/{campaignId}/news` |
| PUT | `/api/studio/campaigns/{campaignId}/news/{newsId}` |
| DELETE | `/api/studio/campaigns/{campaignId}/news/{newsId}` |
| GET | `/api/studio/campaigns/{campaignId}/news` |
| GET | `/api/studio/campaigns/{campaignId}/news/{newsId}` |
| GET | `/api/studio/campaigns/{campaignId}/news/tags` |
| GET | `/api/studio/campaigns/{campaignId}/news/availability` |
| GET | `/api/studio/campaigns/{campaignId}/news/isSendNotification` |
| GET | `/api/studio/campaigns/{campaignId}/news/writes/check-status` |

### News Notification
| Method | Path |
|---|---|
| PUT | `/api/news/notifications/settings/my/campaigns/{campaignId}` |
| GET | `/api/news/notifications/settings/my` |
| GET | `/api/admin/news/notifications/settings` |
| GET | `/api/admin/news/notifications/settings/{userId}` |

### Announcement
| Method | Path | Controller |
|---|---|---|
| GET | `/api/studio/announcements` | `AnnouncementController` |
| GET | `/api/studio/announcements/by-menu` | `AnnouncementController` |
| POST | `/api/studio/announcements/exposure/{displaySeq}` | `AnnouncementController` |
| POST | `/api/studio/announcements/{menuType}/do-not-show-again` | `AnnouncementController` |
| GET | `/api/studio/announcements/new/qty/by-user` | `AnnouncementController` |
| POST | `/api/admin/announcements` | `AnnouncementAdminController` |
| GET | `/api/admin/announcements` | `AnnouncementAdminController` |
| GET | `/api/admin/announcements/{announcementId}` | `AnnouncementAdminController` |
| PUT | `/api/admin/announcements/{announcementId}` | `AnnouncementAdminController` |
| PUT | `/api/admin/announcements/{announcementId}/contents` | `AnnouncementAdminController` |
| GET | `/api/admin/announcements/history/{announcementId}` | `AnnouncementAdminController` |
| GET | `/api/admin/announcements/by-menu` | `AnnouncementAdminController` |
| PUT | `/api/admin/announcements/by-menu/{menuType}` | `AnnouncementAdminController` |
| GET | `/api/admin/announcements/by-menu/menus` | `AnnouncementAdminController` |
| GET | `/api/admin/announcements/by-menu/history` | `AnnouncementAdminController` |

---

## 8. 서명 · 찜하기 · 앵콜 · 오픈예정

| Method | Path | Controller |
|---|---|---|
| GET | `/api/signatures/campaigns/{campaignId}/qty` | `SignatureController` |
| GET | `/api/wishes/my` | `WishController` |
| GET | `/api/wishes/projects/qty` | `WishController` |
| GET | `/api/wishes/my/qty` | `WishController` |
| POST | `/api/wishes` | `WishController` |
| DELETE | `/api/wishes` | `WishController` |
| GET | `/api/wishes` | `WishController` |
| POST | `/api/internal/wishes/users/{userId}` | `WishInternalController` |
| POST | `/api/internal/wishes/qty/by-projects` | `WishInternalController` |
| POST | `/api/projects/{projectNo}/ask-for-encore` | `AskForEncoreController` |
| DELETE | `/api/projects/{projectNo}/ask-for-encore` | `AskForEncoreController` |
| POST | `/api/comingsoons/applicants/{userId}` | `ComingSoonController` |
| GET | `/api/comingsoons/{projectNo}/applicants/qty` | `ComingSoonApplicantController` |
| POST | `/api/comingsoons/{projectNo}/applicants` | `ComingSoonApplicantController` |
| DELETE | `/api/comingsoons/{projectNo}/applicants` | `ComingSoonApplicantController` |

---

## 9. 스튜디오 · 대시보드

### Studio Menu
| Method | Path |
|---|---|
| GET | `/api/studio/projects/{projectNo}/menus` |

### Studio Project Dashboard — `dashboard/StudioProjectDashBoardController` (`/api/studio/dashboard/projects/{projectNo}`)
| Method | Path |
|---|---|
| GET | `/api/studio/dashboard/projects/{projectNo}` |
| GET | `/api/studio/dashboard/projects/{projectNo}/wishes/country-count` |
| GET | `/api/studio/dashboard/projects/{projectNo}/wishes/country-ranking` |
| GET | `/api/studio/dashboard/projects/{projectNo}/payments/country-ranking` |
| GET | `/api/studio/dashboard/projects/{projectNo}/dataplus/{key}` |

### Acquisition Dashboard (`/api/studio/dashboard/projects/{projectNo}/acquisitions`)
| Method | Path |
|---|---|
| GET | `.../cards/data` |
| GET | `.../charts/trend-by-source/data` |
| GET | `.../tables/by-source/data` |
| GET | `.../tables/by-source/download` |

### Engagement Dashboard (`/api/studio/dashboard/projects/{projectNo}/engagements`)
| Method | Path |
|---|---|
| GET | `.../cards/data` |
| GET | `.../charts/payment-trend/data` |
| GET | `.../charts/payment-trend/download` |
| GET | `.../tables/reward-ranking/data` |
| GET | `.../tables/reward-ranking/download` |

### Supporter Dashboard (`/api/studio/dashboard/projects/{projectNo}/supporters`)
| Method | Path |
|---|---|
| GET | `.../cards/data` |
| GET | `.../charts/age-gender-count/data` |
| GET | `.../tables/items/data` |
| GET | `.../tables/items/download` |

### Coming Soon Dashboard — `StudioComingSoonDashBoardController` (`/api/studio/dashboard/coming-soons/{projectNo}`)
| Method | Path |
|---|---|
| GET | `/api/studio/dashboard/coming-soons/{projectNo}` |
| GET | `.../engagements/cards/data` |
| GET | `.../engagements/q1/cards/data` |
| GET | `.../engagements/q2/cards/data` |
| GET | `.../engagements/charts/open-notify-subscriber-count/data` |
| GET | `.../engagements/charts/open-notify-subscriber-count/download` |
| GET | `.../acquisitions/cards/data` |
| GET | `.../acquisitions/charts/trend-by-source/data` |
| GET | `.../acquisitions/tables/by-source/data` |
| GET | `.../acquisitions/tables/by-source/download` |
| GET | `.../open-notify-subscribers/cards/data` |
| GET | `.../open-notify-subscribers/q3/cards/data` |
| GET | `.../open-notify-subscribers/charts/age-gender-count/data` |
| GET | `.../open-notify-subscribers/tables/items/data` |
| GET | `.../open-notify-subscribers/tables/items/download` |
| GET | `.../open-notify-subscribers/country-ranking` |

### Maker Dashboard — `dashboard/MakerDashboardController` (`/api/maker-dashboard`, `/api/v1/maker-dashboard`)
| Method | Path |
|---|---|
| GET | `/api/maker-dashboard/openDisclosures` |
| GET | `/api/maker-dashboard/cards` |
| GET | `/api/maker-dashboard/settlements` |
| GET | `/api/maker-dashboard/settlements/{campaignId}` |
| GET | `/api/maker-dashboard/settlement-system/{campaignId}` |
| GET | `/api/maker-dashboard/settlements/expected-date` |

---

## 10. 메이커 · 담당자 · 사업자

| Method | Path | Controller |
|---|---|---|
| GET | `/api/maker/{campaignId}` | `MakerController` |
| GET | `/api/maker-club/campaign-grade` | `MakerClubController` |
| GET | `/api/makers/my/projects` | `MyProjectController` |
| GET | `/api/makers/my/project-summary` | `MyProjectController` |
| GET | `/api/maker-invitations/inviters/my` | `MakerInvitationController` |
| GET | `/api/maker-invitations/inviters/my/is-expected-benefit` | `MakerInvitationController` |
| GET | `/api/maker-invitations/invitees/validity` | `MakerInvitationController` |
| POST | `/api/maker-invitations` | `MakerInvitationController` |
| GET | `/api/maker-invitations/codes/{code}/validity-for-invitee` | `MakerInvitationController` |
| GET | `/api/maker-invitations/codes/{code}` | `MakerInvitationController` |
| GET | `/api/maker-invitations/by-campaign` | `MakerInvitationController` |
| GET | `/api/admin/maker-invitations/by-campaign` | `AdminMakerInvitationController` |
| GET | `/api/internal/managers/{userId}` | `ManagerInternalController` |
| GET | `/api/admin/managers` | `ManagerAdminController` |
| GET | `/api/v1/admin/departments` | `DepartmentAdminController` |
| GET | `/api/v1/admin/employees` | `EmployeeAdminController` |
| GET | `/api/v1/admin/employees/{employee-code}` | `EmployeeAdminController` |
| POST | `/api/v1/campaigns/{campaignId}/business-licenses` | `BusinessVerifyController` |
| GET | `/api/v1/campaigns/{campaignId}/business-licenses/verify` | `BusinessVerifyController` |
| GET | `/api/v1/campaigns/{campaignId}/bank-accounts/verify` | `BankAccountController` |
| GET | `/api/studio/campaigns/{campaignId}/contract-info` | `ContractInfoStudioController` |

---

## 11. 스토리 · 번역 · AI 리뷰

| Method | Path | Controller |
|---|---|---|
| GET | `/api/story/{campaignId}/funding` | `StoryController` |
| GET | `/api/story/{campaignId}/comingsoon` | `StoryController` |
| POST | `/api/internal/story-copy/{projectNo}` | `StoryCopyInternalController` |
| POST | `/api/v1/translate/request/{projectNo}` | `StoryTranslationRequestController` |
| POST | `/api/internal/story-translation/{projectNo}/final-review` | `StoryTranslationInternalController` |
| POST | `/api/internal/translation/{campaignId}/{languageCode}/{translationTaskType}` | `StoryTranslationController` |
| POST | `/api/internal/translation/{campaignId}/{languageCode}/{translationTaskType}/{orderNo}` | `StoryTranslationController` |
| POST | `/api/internal/translation/request/{translationRequestKey}` | `StoryTranslationController` |
| POST | `/api/internal/translate/text` | `InternalTranslateController` |
| POST | `/api/internal/translate/html` | `InternalTranslateController` |
| POST | `/api/internal/translate/ai` | `InternalTranslateController` |
| POST | `/api/internal/translate/image` | `InternalTranslateController` |
| POST | `/api/internal/translate/callback` | `InternalTranslateController` |
| POST | `/api/internal/translate/image/callback` | `InternalTranslateController` |
| POST | `/api/v1/ai-review/story/request/{campaignId}` | `AIReviewController` |
| POST | `/api/internal/story/response/{campaignId}` | `AIReviewInternalController` |

---

## 12. IP라이선스 · 카탈로그 · 추가서비스

### IP License
| Method | Path |
|---|---|
| GET | `/api/iplicenses` |
| GET | `/api/iplicenses/{licenseKey}` |
| GET | `/api/iplicenses/tags` |
| GET | `/api/admin/iplicenses` |
| GET | `/api/admin/iplicenses/{licenseKey}` |
| PUT | `/api/admin/iplicenses/{licenseKey}` |
| POST | `/api/admin/iplicenses` |
| DELETE | `/api/admin/iplicenses/{licenseKey}` |
| GET | `/api/admin/iplicenses/top-ranks` |
| POST | `/api/admin/iplicenses/top-ranks` |
| GET | `/api/admin/iplicenses/campaigns/{campaignId}/related-mappings` |

### Catalog
| Method | Path |
|---|---|
| GET | `/api/v1/catalog/meta/feed/{countryCode}` |

### Additional Service
| Method | Path |
|---|---|
| POST | `/api/additional-services/{projectNo}` |
| GET | `/api/additional-services/{projectNo}` |
| GET | `/api/additional-services` |
| PUT | `/api/internal/additional-services/{projectNo}/services/{serviceCode}/approve` |
| PUT | `/api/internal/additional-services/{projectNo}/services/{serviceCode}/reject` |
| PUT | `/api/internal/additional-services/{projectNo}/services/pd-consulting/manual-request` |

---

## 13. 인증 · 참여 · 기타

| Method | Path | Controller |
|---|---|---|
| GET | `/api/kcertification/info` | `CertVerifyController` |
| GET | `/api/internal/personal-verify/{purposeType}/key/{targetKey}` | `PersonalVerificationInternalController` |
| GET | `/api/participation/by-following/{campaignId}` | `ParticipationController` |
| GET | `/api/participation/{campaignId}` | `ParticipationController` |
| GET | `/api/reactions` | `ReactionController` |
| PUT | `/api/reactions/{reactionsTypeId}` | `ReactionController` |
| GET | `/api/reactions-types` | `ReactionController` |
| GET | `/api/supporter-club/my/benefit` | `MembershipController` |
| GET | `/api/payment-progress/campaigns/{campaignId}/relevant-info` | `PaymentProgressController` |
| GET | `/api/notice-banner/campaigns/{campaignId}` | `NoticeBannerController` |
| GET | `/api/preorders` | `PreOrderController` |
| GET | `/api/bottom-sheet/data` | `BottomSheetController` |
| GET | `/api/bottom-sheet/bridge` | `BottomSheetController` |
| GET | `/api/bottom-sheet/recentInfo/{userId}` | `BottomSheetController` |
| GET | `/api/v2/bottom-sheet/data` | `BottomSheetControllerV2` |
| GET | `/api/day/business-date` | `EventDayController` |
| GET | `/api/day/business-date/detail` | `EventDayController` |
| GET | `/api/safe-number/campaigns/{campaignId}` | `SafeNumberController` |
| POST | `/api/safe-number/campaigns/{campaignId}/{safeNumberActionType}` | `SafeNumberController` |
| PUT | `/api/admin/satisfactions/{satisfactionNo}/hidden` | `SatisfactionAdminController` |
| GET | `/api/campaign-category/` | `CampaignCategoryController` |
| GET | `/api/admin/pause/projects/{projectNo}` | `ProjectPauseAdminController` |
| GET | `/api/admin/pause/projects/{projectNo}/histories` | `ProjectPauseAdminController` |
| GET | `/api/internal/pause/projects/{projectNo}` | `ProjectPauseInternalController` |
| POST | `/api/internal/campaigns/{campaignId}/store-events/open` | `StoreEventInternalController` |
| POST | `/api/internal/store-events/selling-price-changed` | `StoreEventInternalController` |
| POST | `/api/attachments/presign` | `AttachmentController` |
| POST | `/api/attachments/friend-talk` | `AttachmentController` |
| POST | `/api/v1/slack/campaigns/{projectNo}/hidden/send` | `SlackController` |
| POST | `/api/v1/slack/campaigns/{projectNo}/story-modified/send` | `SlackController` |
| POST | `/api/internal/slack/campaigns/{campaignId}/hidden/send` | `SlackInternalController` |
| POST | `/api/internal/slack/campaigns/{campaignId}/story-modified/send` | `SlackInternalController` |
| POST | `/api/internal/users` | `UserInternalController` |
| GET | `/api/internal/users` | `UserInternalController` |
| GET | `/api/internal/users/{userId}` | `UserInternalController` |

### Sample (템플릿/예제)
| Method | Path |
|---|---|
| POST | `/api/global/samples/{pathVariable}/modelAttribute` |
| POST | `/api/global/samples/{pathVariable}/requestBody` |
| GET | `/api/global/samples/{pathVariable}/pageResult` |

---

## 14. 요약 통계

- **총 컨트롤러 파일**: 약 70+개
- **총 엔드포인트**: 약 200개
- **경로 그룹별 분포**:
  - Public(`/api/...`): 펀딩 참여자/게스트가 쓰는 조회·액션 API
  - Internal(`/api/internal/...`): 사내 서비스 간 통신용
  - Studio(`/api/studio/...`): 메이커(프로젝트 운영자) 전용
  - Admin(`/api/admin/...`, `/api/v1/admin/...`): 운영·관리자 전용
  - Global(`/api/global/...`): 해외(영문) 프로젝트/리워드
  - Native(`/api/native/v1/...`): 네이티브 앱 전용
  - v1/v2 접두 및 복수 base path 어노테이션으로 버전/호환 경로 병존

> 이 목록은 `@RequestMapping` / `@GetMapping` / `@PostMapping` / `@PutMapping` / `@DeleteMapping` / `@PatchMapping` 전수 그렙 결과를 파싱한 것이며, 동적 라우팅(필터·서블릿)이나 WebFlux 라우팅은 포함되지 않을 수 있다.
