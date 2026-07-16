> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

# 마이와디즈 / 위시 (My-Wadiz / Wish)

> 구조: 각 기능은 `*Layout.tsx`(모바일/데스크톱 분기) + `_ui/` 하위 실제 UI 컴포넌트. `settings/notification`·`maker/(home)/ad` 하위는 `.jsx`(레거시)와 `.tsx` 혼재.

## 마이와디즈 — 서포터 홈

관련 이슈: `FE1-952`(마이와디즈 공지 배너 대응 · 에픽), `FE1-244`(서포터 프로필 margin)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 서포터 홈 (헤더 "마이와디즈" · `my_wadiz_page.header.title`) | `apps/global/src/pages/my-wadiz/supporter/MyWadizSupporterMobileLayout.tsx` |
| 서포터 탭 본문 컨테이너 (프로필/활동/혜택/메뉴 조합) | `packages/widgets/src/my-wadiz/supporter/ui/MyWadizSupporter.tsx` |
| 프로필 섹션 ("{{닉네임}} 님, 안녕하세요." · `my_wadiz_page.profile_section`) | `packages/widgets/src/my-wadiz/supporter/ui/SupporterProfileSection/SupporterProfileSection.tsx` |
| 나의 활동 섹션 (포인트/쿠폰 "보기" · `activity_section`, `point_section`, `coupon_section`) | `packages/widgets/src/my-wadiz/supporter/ui/SupporterActivitySection/SupporterActivitySection.tsx` |
| 서포터 혜택 섹션 (쿠폰 "{{n}}장" · `supporter_benefit_section`) | `packages/widgets/src/my-wadiz/supporter/ui/SupporterBenefitSection/SupporterBenefitSection.tsx` |
| 서포터 메뉴 섹션 ("나의 활동"/"고객센터" · `menu_title_section`) | `packages/widgets/src/my-wadiz/supporter/ui/SupporterMenuSection/SupporterMenuSection.tsx` |
| 롤링 배너 / 서포터클럽 배너 / 멀티보드 광고 배너 / 큐레이션 카드 / 재구매 카드 (CMS·props 데이터 기반) | `packages/widgets/src/my-wadiz/supporter/ui/{SupporterRollingBannerSection,SupporterClubBannerSection,SupporterMultiBoardAdBannerSection,SupporterClubCurationCard,SupporterRepeatedPurchaseProjectsCard}/` |
| 로그인/로그아웃 버튼 (`login_logout_section`) | `packages/widgets/src/my-wadiz/supporter/ui/LoginButton.tsx`, `LogoutButton.tsx` |

## 마이와디즈 — 설정 / 알림 설정

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 설정 페이지 (헤더 "설정" · `my_wadiz_settings_page.header.title`, 프로필: 닉네임/이메일/국가·지역 `profile_section`) | `apps/global/src/pages/my-wadiz/settings/_ui/Settings.tsx` |
| 프로필 이미지 편집 팝업 ("수정/삭제/파일 선택" · `profile_image_section`) | `apps/global/src/pages/my-wadiz/settings/_ui/ProfileEditPopup.tsx` |
| SNS 계정 연동 (`sns_section`; 카카오/네이버/애플) | `apps/global/src/pages/my-wadiz/settings/_ui/SNSSetting.tsx` |
| 설정 항목 목록 (알림/비밀번호/전화번호/동영상 자동재생 · `settings_section`) | `apps/global/src/pages/my-wadiz/settings/_ui/SettingItem.tsx` |
| 닉네임/이메일/전화번호/비밀번호 설정·확인 모달 | `apps/global/src/pages/my-wadiz/settings/_ui/modal/{NicknameSetting,EmailSetting,PhoneNumberSetting,PasswordSetting,ConfirmPassword}.tsx` |
| 회원 탈퇴 진입 (footer "회원 탈퇴" · `footer`) | `apps/global/src/pages/my-wadiz/settings/MyWadizSettingsMobileLayout.tsx` |
| 알림 설정 (헤더 "알림 설정", 이벤트 혜택 알림 이메일/SMS/푸시 토글 · `my_wadiz_settings_notification_page`) | `apps/global/src/pages/my-wadiz/settings/notification/_ui/MarketingNotificationSettingsContainer.jsx` (+ `...List.jsx`) |
| 새소식 알림 설정 (프로젝트별 "종료"/"결제" 뱃지 · `my_wadiz_settings_notification_news_page`) | `apps/global/src/pages/my-wadiz/settings/notification/news/_ui/container/NotificationDenyPageContainer.jsx` |

## 마이와디즈 — 참여 내역 / 주문 상세

관련 이슈: `FE1-470`(달러 결제 Phase 4 — 마이와디즈 결제 상세), `FE1-973`(참여내역/스토어 결제내역 배송지 미노출), `FE1-800`(환불 동선 후속), `FE2-362`(젠데스크 문의 링크 교체 — 주문/환불)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 참여 내역 목록 페이지 (헤더 "참여 내역" · `my_wadiz_orders_page.header.title`) | `apps/global/src/pages/my-wadiz/orders/_ui/MyFundingListContainer.tsx` |
| 참여 내역 카드 (결제 상태·"만족도 쓰기" · `order_history_card`) | `apps/global/src/pages/my-wadiz/orders/_ui/MyFundingListItem.jsx` |
| 주문 유형 필터/목록 (빈 상태 "참여 내역이 없어요." · `order_history_list`, `order_type_select`) | `apps/global/src/pages/my-wadiz/orders/_ui/MyFundingList.tsx` |
| 주문 상세 페이지 (`my_wadiz_orders_detail_page`) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/MyWadizOrdersDetailPage.tsx` |
| 프로젝트 정보/결제 상태 (진행중·성공·실패 뱃지 · `project_info_section`) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/_ui/PurchaseInfoContainer.tsx` |
| 결제 정보/방법 (`payment_method_section`) / 결제 내역·금액 (`payment_amount_section`) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/_ui/PaymentMethod.tsx`, `PaymentInfo.tsx` |
| 리워드 정보/수령 확인 (`reward_detail_section`) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/_ui/PurchaseStatus.tsx` |
| 환불 내역 (`refund_info_section`) / 배송지 정보·변경 (`shipping_address_section`) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/_ui/RefundInfo.tsx`, `ShippingAddressInfo.tsx` |
| 결제 취소/예약 취소 버튼 (`payment_cancellation_modal`) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/_ui/PurchaseInfoFooter.tsx` |
| 리워드 환불 신청 모달군 (지연/하자/정정 환불) | `apps/global/src/pages/my-wadiz/orders/[orderNo]/_ui/modal/refund/RefundReason.tsx` 외 |

## 마이와디즈 — 포인트 / 쿠폰 / 1:1 문의 / 초대코드

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 포인트 내역 (헤더 "포인트 내역", "현재 사용 가능 포인트", 빈 상태 "포인트 내역이 없어요." · `my_wadiz_points_page`) | `apps/global/src/pages/my-wadiz/points/MyWadizPointsMobileLayout.tsx` (+ `_ui/PointList.tsx`) |
| 쿠폰 페이지 (헤더 "쿠폰", 탭 "쿠폰 받기"/"나의 쿠폰" · `my_wadiz_coupons_page`) | `apps/global/src/pages/my-wadiz/coupons/MyWadizCouponsMobileLayout.tsx` |
| 나의 쿠폰 목록 ("사용 가능한 쿠폰이 없어요." · `coupon_card_list`) / 지난 쿠폰 내역 | `apps/global/src/pages/my-wadiz/coupons/my/MyWadizCouponsMyPage.tsx`, `history/MyWadizCouponsHistoryPage.tsx` |
| 1:1 문의 탭 바 ("나의 문의"/"서포터 문의" · `my_wadiz_inquiries_page.tab_bar`) | `apps/global/src/pages/my-wadiz/inquiries/_ui/MyWadizInquiriesTabBar/MyWadizInquiriesTabBar.tsx` |
| 문의 목록/빈 상태 ("메시지가 없어요" · `content.empty_title`) | `apps/global/src/pages/my-wadiz/inquiries/_ui/MyWadizInquriesList/MyWadizInquriesList.tsx` |
| 대화(채팅) 화면 (헤더 "메시지는 실시간 채팅이 아니에요", 입력 "메시지 내용을 입력해 주세요"/"보내기" · `my_wadiz_inquiries_detail_page`) | `apps/global/src/pages/my-wadiz/inquiries/conversation/_ui/{MyWadizInquiriesConversationHeader,ConversationInputForm/ConversationInputForm}.tsx` |
| 친구 초대 코드 입력 (헤더 "친구 초대 코드 입력" · `my_wadiz_invitation_code_page`) | `apps/global/src/pages/my-wadiz/invitation-code/_ui/InvitationCodeContainer.tsx` |

## 마이와디즈 — 메이커 홈 / 메이커 광고 / 메이커 프로필

관련 이슈: `FE2-423`·`FE2-648`(매출 UP 페이지 개편 · 에픽), `FE2-320`(대시보드 성공 공식)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 메이커 홈 ("메이커 홈"/"매출 UP" 탭 · `my_wadiz_maker_page.tab_bar`) | `apps/global/src/pages/my-wadiz/maker/(home)/MyWadizMakerMobileLayout.tsx` |
| 메이커 프로필 섹션 ("팔로워", "메이커 프로필 설정하기" · `profile_section`) | `apps/global/src/pages/my-wadiz/maker/(home)/_ui/ProfileSection/ProfileSection.tsx` |
| 만든 프로젝트 섹션/카드 ("만든 프로젝트", "새로운 도전을 시작해 보세요", "이어서 작성/데이터 확인/삭제" · `my_project_section`) | `apps/global/src/pages/my-wadiz/maker/(home)/_ui/MyProjectSection/MyProjectSection.tsx` (+ `MyProjectCard.tsx`) |
| 메이커 내비게이션 바 (광고센터/비즈센터/1:1 문의 · `navbar`) | `apps/global/src/pages/my-wadiz/maker/(home)/_ui/Navbar/Navbar.tsx` |
| 서비스 소개 배너 ("와디즈에선 누구나 '메이커'가 될 수 있어요!" · `service_introduction_banner_section`) | `apps/global/src/pages/my-wadiz/maker/(home)/_ui/ServiceIntroductionBannerSection/ServiceIntroductionBannerSection.tsx` |
| FAQ 섹션 ("질문 있으신가요?" · `faq_list_section`) | `apps/global/src/pages/my-wadiz/maker/(home)/_ui/FAQListSection/FAQListSection.tsx` |
| 광고 홈 ("1000만 서포터 대상 광고 서비스" · `my_wadiz_maker_ad_page.ad_service_card_section`) | `apps/global/src/pages/my-wadiz/maker/(home)/ad/MyWadizMakerAdPage.tsx` |
| 디스플레이/타겟/푸시 광고 소개 페이지 | `apps/global/src/pages/my-wadiz/maker/(home)/ad/(type)/{display,target,push}/` |
| 메이커 프로필 편집 폼 (헤더 "메이커 프로필", 메이커명/글로벌 메이커명/프로필 이미지 · `my_wadiz_maker_profile_page`) | `apps/global/src/pages/my-wadiz/maker/profile/[corpNo]/_ui/MakerProfileForm/MakerProfileForm.tsx` |

## 위시 (내 위시리스트)

관련 이슈: `FE1-272`(위시 — 알림신청/찜하기 선노출 로직 변경)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 위시 페이지 (헤더 "내 위시리스트" · `wish_page.header.title`) | `apps/global/src/pages/wish/WishMobileLayout.tsx` |
| 탭 바 ("전체"/"찜한 펀딩+"/"알림신청" · `wish_page.tab_bar`) | `apps/global/src/pages/wish/_ui/TabsContainer/TabsContainer.tsx` |
| 찜한 펀딩 목록 ("찜으로 담아둔 펀딩+ 프로젝트" · `funding_section`) | `apps/global/src/pages/wish/_ui/FundingContainer/FundingContainer.tsx` |
| 알림 신청(오픈예정) 목록 ("알림 신청한 프로젝트" · `launching_soon_section`) | `apps/global/src/pages/wish/_ui/ComingSoonContainer/ComingSoonContainer.tsx` |
| 마감 임박 프로젝트 섹션 (`ending_soon_section`) | `apps/global/src/pages/wish/_ui/EndingSoonProjectSection/EndingSoonProjectSection.tsx` |
| 빈 상태 ("찜한 프로젝트가 없어요"/"알림 신청한 프로젝트가 없어요" · `empty`) | `apps/global/src/pages/wish/_ui/EmptyContainer/EmptyContainer.tsx` |
| 로그인 유도 박스 ("로그인이 필요해요", "로그인하고 찜한 콘텐츠를 확인해 보세요." · `login_section`) | `apps/global/src/pages/wish/_ui/LoginBox/LoginBox.tsx` |

## 위시(찜) / 팔로우 / 마이펀딩 배너 (공용 features)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 찜 버튼 ("찜하기", 토스트 "위시리스트에 추가했어요…" · `wish_button_component._default`) | `packages/features/src/wish/ui/WishButton/WishButton.tsx` (+ `WishIconButton.tsx`) |
| 찜 상태/토글 로직 훅 | `packages/features/src/wish/lib/useWishMark.ts` |
| 메이커 팔로우 버튼 (**하드코딩** "팔로우"/"팔로잉", 토스트 로직 훅은 `maker_follow_button_component._default` "메이커를 팔로우할게요.") | `packages/features/src/maker-following/ui/FollowingButton.tsx` (+ `lib/useMakerFollowMark.ts`) |
| 마이펀딩 프로모션 배너 (title props 주입, GA "노출"/"클릭", "AD" 뱃지) | `packages/features/src/my-funding-banner/ui/Banner/Banner.tsx` (+ `AdBadge.tsx`) |

## 이슈 히스토리 (마이와디즈/위시 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-470 | 작업 | [FE] 글로벌 달러 결제 - Phase 4: 결제 완료 + 마이와디즈 결제 상세 |
| FE1-973 | 작업 | [Web] 펀딩 참여 내역/스토어 결제 내역 배송지 정보 미노출 처리 |
| FE1-952 | 에픽 | [WEB] 마이와디즈 공지 배너 대응 |
| FE1-800 | 작업 | [Web] 글로벌 달러 결제 - 환불 동선 관련 후속 대응 |
| FE2-362 | 작업 | [FE2] 젠데스크 문의 연결 링크 교체 - 마이와디즈 - 주문/환불 |
| FE1-272 | 작업 | [Web] 위시 - 알림신청/찜하기 선노출 로직 변경 |
| FE1-244 | 작업 | 서포터 프로필 섹션의 margin 값을 32에서 14로 변경 |
| FE1-679 | 작업 | 통합기획전 페이지에서 찜하기/알림신청시 와디태그 데이터 수집 |
| FE2-423 | 에픽 | [FE] '매출 UP' 페이지 개편 P1. LLM 및 전략에 따른 광고 상품 추천 |
| FE2-648 | 에픽 | [FE] '매출 UP' 페이지 개편 P2. 유사프로젝트 조회 기능 추가 |

---
