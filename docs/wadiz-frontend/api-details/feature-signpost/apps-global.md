# 기능 이정표 — 사용자 서비스 도메인 (apps/global + 공유 packages)

> 전체 인덱스·사용법은 [`README.md`](./README.md) 참조. 이 파일은 **글로벌 앱 사용자 화면 9개 도메인**(apps/global 페이지 + 공유 `packages/features·ui·widgets`)을 담습니다.
> 기준: master `4439853b8dd` (2026-07-15). 문구 i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

## 이 파일의 도메인

| 도메인 |
|---|
| [펀딩 상세 (Funding Detail)](#펀딩-상세-funding-detail) |
| [결제 (Funding Payment)](#결제-funding-payment) |
| [홈 / 서비스홈 (Home / Service-Home)](#홈--서비스홈-home--service-home) |
| [마이와디즈 / 위시 (My-Wadiz / Wish)](#마이와디즈--위시-my-wadiz--wish) |
| [메이커 / 프로젝트 만들기 (Maker / Create-Project)](#메이커--프로젝트-만들기-maker--create-project) |
| [소셜 / 친구추천 (Social / Refer-a-Friend)](#소셜--친구추천-social--refer-a-friend) |
| [검색 / 스토어 / 소싱클럽 (Search / Store / Sourcing-Club)](#검색--스토어--소싱클럽-search--store--sourcing-club) |
| [정책 / WAi / 알림 / 이벤트 / 쿠폰 / 기타](#정책--wai--알림--이벤트--쿠폰--기타) |
| [packages 공통 (ui · widgets · features)](#packages-공통-ui--widgets--features) |
| [apps/global 내부 features (부가)](#appsglobal-내부-features-부가) |

---

# 펀딩 상세 (Funding Detail)

> 소스가 `apps/global/src/pages/funding/[projectNo]/**` (페이지·탭), `packages/features/src/{funding-detail,reward-selection,comments,native-detail}`, `apps/global/src/features/detail` 에 분산되어 있습니다.

## 상세 본체 (페이지 골격 · 레이아웃)

관련 이슈: `FE1-511`(국내/해외 통합), `FE1-616`(레거시 제거), `FE1-645`(개발자 검증), `FE1-676`(컨텐츠 상단 여백 40px 통일), `FE1-657`(데스크탑 스크롤 버그), `FE1-889`(canonicalUrl), `FE1-927`(E2E testid), `FE1-1110`(통합 regression)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 상세 페이지 레이아웃 셸(데스크톱/모바일 분기, Outlet 라우팅 컨테이너) | `apps/global/src/pages/funding/[projectNo]/FundingDetailLayout.tsx` (+ `FundingDetailDesktopLayout.tsx`, `FundingDetailMobileLayout.tsx`) |
| 상세 SEO/OG 메타 태그 · canonicalUrl | `apps/global/src/pages/funding/[projectNo]/FundingDetailMeta.tsx` |
| 성인 인증 필요 안내 — 미성년/미인증 접근 차단 화면 (keyPrefix `adult_verification_required_error_content_component._default`) | `apps/global/src/pages/funding/[projectNo]/AdultVerificationRequiredNotice.tsx` |
| 탭 바 — "스토리 / 리워드 / 리워드 정보 / 새소식 / 커뮤니티 / 환불·정책 / 서포터" (keyPrefix `funding_detail_page.tab_bar`, 예: `story_tab_label`="스토리", `community_tab_label`="커뮤니티"/EN "Community") | `apps/global/src/pages/funding/[projectNo]/_ui/TabBar/TabBar.tsx` |
| 프로젝트 개요 섹션 — 제목·달성률·서포터 수 (keyPrefix `funding_detail_page.project_info_section`, 예: `funded_badge_label`="% 달성", `supporter_count_badge_label`="{{arg_0}}명 참여") | `apps/global/src/pages/funding/[projectNo]/_ui/ProjectOverviewSection/ProjectOverviewSection.tsx` |
| 펀딩 정보 섹션(달성 현황·남은 기간·모집액) — "오늘 곧 마감", "{{arg_0}}일 남음", "달성" | `apps/global/src/pages/funding/[projectNo]/_ui/FundingInformationSection/FundingInformationDesktopSection.tsx` (+ Mobile) |
| 데스크톱 우측 고정 aside(리워드 요약/CTA 영역) | `apps/global/src/pages/funding/[projectNo]/_ui/DesktopAside/` |
| 미리보기 모드 오버레이 — "미리 보기 모드", "저장한 내용을 미리 볼 수 있어요." (keyPrefix `funding_detail_page.preview_mode_banner`) | `apps/global/src/pages/funding/[projectNo]/_ui/PreviewOverlay/PreviewOverlay.tsx` |
| 프로젝트 종료 안내 박스 — 성공: "…성공적으로 종료되었어요.", 실패: "…목표 금액을 달성하지 못한 채 …종료되었어요." (`project_info_section.end_status_message_box_*`) | `apps/global/src/pages/funding/[projectNo]/_ui/ProjectEndMessageBox/ProjectEndMessage.tsx` |
| 혜택 섹션 — "혜택"(`benefits_field_label`), "결제"(`payment_field_label`), 결제수단 칩 | `apps/global/src/pages/funding/[projectNo]/_ui/BenefitSection/` |
| 데스크탑 스크롤 위치 보정 / 앵커 스크롤 유틸 | `packages/features/src/funding-detail/lib/correctScroll.ts`, `scrollToAnchor.ts` |

## CTA 버튼 그룹

관련 이슈: `FE1-849`(CTA 버튼 동작 수정), `FE1-850`(로그인 유도 모달), `FE1-847`(앱 다운로드 로그인 적극 유도 · 에픽), `FE1-1226`(앱 로그인 모달 tracking-data 전달)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 펀딩하기 버튼 — "펀딩하기" / EN "Continue to Checkout" (`funding_detail_page.cta_section.checkout_button_label`) | `apps/global/src/pages/funding/[projectNo]/_ui/FundingCTAButtonGroup/CheckoutButton/` |
| 리워드 보기 버튼 — "펀딩하기"(`view_reward_button_label`), 프리오더: "예약 구매하기"(`cta_button_preorder_view_reward_label`) | `apps/global/src/pages/funding/[projectNo]/_ui/FundingCTAButtonGroup/ViewRewardButton/` |
| 관심/오픈 알림 신청 버튼 — "관심 있어요", "오픈 알림 신청" (`cta_section.wish_button_label`, `notification_button_label`) | `apps/global/src/pages/funding/[projectNo]/_ui/FundingCTAButtonGroup/SendInterestButton/` |
| 재오픈 요청 버튼 + 모달 — "재오픈 요청하기"(`reopen_request_button_label`), 완료 시 "재오픈 요청 완료" | `apps/global/src/pages/funding/[projectNo]/_ui/FundingCTAButtonGroup/ReopenRequestButton/` |
| 중단/차단 프로젝트 버튼 — "중단된 프로젝트"(`paused_project_button_label`) | `apps/global/src/pages/funding/[projectNo]/_ui/FundingCTAButtonGroup/PausedProjectButton/`, `BlockedProjectButton/` |
| 품절/지역 불가 상태 버튼 — "품절"(`out_of_stock_button_label`), "해당 지역에서 참여할 수 없어요"(`region_unavailable_button_label`) | `apps/global/src/pages/funding/[projectNo]/_ui/FundingCTAButtonGroup/CTAButton/` |

## 리워드 선택 (`packages/features/src/reward-selection`)

관련 이슈: `FE1-979`(직접 입력 옵션 가이드 문구 미노출), `FE1-388`·`FE1-470`(글로벌 달러 결제 — 결제금액/환율 표기), `FE1-644`(달러 쿠폰 서포터 다운로드 지면)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 리워드 선택 모달 — 헤더 "리워드 선택"/EN "Select your rewards", 하단 "다음 단계"·"펀딩하기"/EN "Continue to Checkout" (keyPrefix `reward_choice_modal`) | `packages/features/src/reward-selection/ui/RewardsSelectionModal/RewardsSelectionModal.tsx` |
| 리워드 선택기 본체(모달/페이지 공용 셀렉터 컨테이너) | `packages/features/src/reward-selection/ui/RewardsSelector/RewardsSelector.tsx` |
| 리워드 목록 — "이 리워드 선택하기"(`funding_detail_rewards_page.reward_card.choose_button_label`), "현재 {{arg_0}}개 남음" | `packages/features/src/reward-selection/ui/RewardsSelector/RewardList/RewardList.tsx` (+ `Reward.tsx`) |
| 리워드 카드 — 얼리버드/제한수량/발송일/무료배송 뱃지 (keyPrefix `reward_card_component._default`, 예: `early_bird_badge_label`="얼리버드", `estimated_delivery_field_label`="발송일") | `packages/features/src/reward-selection/ui/RewardCard/RewardCard.tsx` |
| 얼리버드 뱃지 — "얼리버드/슈퍼 얼리버드/울트라 얼리버드" | `packages/features/src/reward-selection/ui/EarlyBirdBadge/EarlyBirdBadge.tsx` |
| 배송 국가 선택 — "배송지"(`shipping_country_select_menu_label`), 국가 미참여 시 "현재 국가에 참여 가능한 리워드가 없어요" | `packages/features/src/reward-selection/ui/RewardsSelector/ShippingCountrySelect/ShippingCountrySelect.tsx` |
| 리워드 옵션 선택기 — "{{arg_0}} 선택"(`option.option_placeholder_label`), "세트 옵션", "옵션을 선택해 주세요" | `packages/features/src/reward-selection/ui/RewardsSelector/RewardOptionSelector/RewardOptionSelector.tsx` |
| 선택 리워드 카드 목록(단일/세트/추가입력형) — "메시지를 입력해 주세요"(`reward_select_menu_single_reward_input_placeholder`) | `packages/features/src/reward-selection/ui/RewardsSelector/SelectedRewardCardList/SelectedRewardCardList.tsx` |
| 수량/상품 카드 — "수량"(`quantity_field_label`), "선택 가능한 수량을 초과했어요"(`error_messages.exceeded_maximum_quantity_toast_message`) | `packages/features/src/reward-selection/ui/RewardsSelector/ProductCard/ProductCard.tsx` (+ `ProductQuantity.tsx`) |
| 총 결제금액 패널 — "리워드 금액"·"배송비"·"결제 금액"(`payment_amount_section.*`), 환율 안내 popper | `packages/features/src/reward-selection/ui/RewardsSelector/TotalPricePanel/TotalPricePanel.tsx` |
| 리워드 미리보기(선택 없이 카드 뷰) | `packages/features/src/reward-selection/ui/RewardPreviewSection/RewardPreviewSection.tsx` (+ `RewardPreviewCard.tsx`) |
| 리워드 선택 상태 컨텍스트(선택/수량/국가 상태 관리) | `packages/features/src/reward-selection/lib/useRewardsSelectorContext.tsx` |

## 상세 기능 컴포넌트 (`packages/features/src/funding-detail`)

관련 이슈: `FE1-722`(일본어/중국어 줄바꿈 글자 단위 — 실시간 번역), `FE1-979`(옵션 가이드 문구)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 해외 배송 안내 — "본 리워드는 해외 직출고 제품으로 '개인사용목적'으로만…" (keyPrefix `funding_detail_page.story_shipping_section.description`) | `packages/features/src/funding-detail/ui/OverseasShippingNotice/OverseasShippingNotice.tsx` |
| 실시간 번역 경고 박스 — "실시간 자동 번역이 포함되어 있어 의미가 정확하지 않을 수 있어요…" (`funding_detail_page.real_time_translation_warning_message_box.description`) | `packages/features/src/funding-detail/ui/RealTimeTranslationWarningMessageBox/RealTimeTranslationWarningMessageBox.tsx` |
| 배송 정보 섹션 — "배송"(`project_info_section.shipping_field_label`), "해외"(`shipping_field_title`), "리워드가 해외에서 직접 배송돼요"(`shipping_field_description`) | `packages/features/src/funding-detail/ui/ShippingSection/ShippingSection.tsx` |
| 배송 안내 배너 | `packages/features/src/funding-detail/ui/DeliveryBanner/DeliveryBanner.tsx` |
| 환불·정책 본문 — "결제 취소 및 환불 안내", "공통 환불 불가 유형", "A/S 정책" (keyPrefix `funding_detail_refund_policy_page`) | `packages/features/src/funding-detail/ui/RefundPolicyContent/RefundPolicyContent.tsx` |
| 연관 키워드 섹션 — "이 프로젝트 연관 키워드"(`hash_keyword_list_section.title`), "키워드 알림설정 바로가기" | `packages/features/src/funding-detail/ui/RelatedKeywordSection/RelatedKeywordSection.tsx` (+ `RelatedKeywordList.tsx`, `RelatedKeywordItem.tsx`) |
| 스토리 미리보기 배너(메이커 미리보기 언어 전환) — "번역된 스토리는 제출 이후에 확인할 수 있어요."(`funding_detail_page.preview_mode_banner.language_change_popover_description`) | `packages/features/src/funding-detail/ui/StoryPreviewBanner/StoryPreviewBanner.tsx` |
| 상품 구매(프리오더 상품) 버튼 — 실패 토스트 **하드코딩** "잠시 후 다시 시도해 주세요" | `packages/features/src/funding-detail/ui/FundingProductPurchaseButton/FundingProductPurchaseButton.tsx` |
| 디자인 모드 패널(메이커 미리보기용 섹션 토글) — **하드코딩** 라벨: "새소식 배너", "슈퍼 메이커 배너", "해외배송/도서산간 안내", "AI 추천 프로젝트", "혜택 섹션" 등 | `packages/features/src/funding-detail/ui/DesignModePanel/DesignModePanel.tsx` (컨텍스트: `packages/features/src/funding-detail/lib/DesignModeContext.tsx`) |

## 커뮤니티 · 댓글 (community 탭 + `packages/features/src/comments`)

관련 이슈: `FE1-876`(스토리 상단 새소식을 커뮤니티에도 노출), `FE1-956`(마케팅 수신 동의 모달 마이그레이션)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 커뮤니티 탭 페이지(응원·의견·체험리뷰 / 지지서명 / 만족도 리뷰 서브탭) — 서브탭 라벨 keyPrefix `funding_detail_community_page.tab_bar` | `apps/global/src/pages/funding/[projectNo]/community/FundingDetailCommunityPage.tsx` |
| 댓글 목록 컨테이너 — "댓글 더보기"(`comment_section.more_comments_button_label`), "삭제된 글이에요"(`deleted_comment_text`) (keyPrefix `comment_list_component.*`) | `packages/features/src/comments/ui/CommentContainer.jsx` (+ `CommentItem.jsx`, `CommentInput.jsx`) |
| 답글 컨테이너/입력 — "답글을 작성해 주세요"(`reply_section.input_placeholder`), "가장 첫 번째로 답글을 등록해 보세요" | `packages/features/src/comments/ui/ReplyContainer.jsx` (+ `ReplyInput.jsx`, `ReplyItem.tsx`) |
| 커뮤니티 글쓰기 폼 + 리뷰 타입 선택 팝오버 — "응원/의견/체험리뷰"(`funding_detail_community_page.review_type_popover.*`), "글쓰기" | `packages/features/src/comments/ui/CommunityCommentWriteContainer.jsx` (+ `CommunityCommentWriteForm.jsx`) |
| 만족도 점수판 — "만족도"(`comment_list_component.rating_section.title`) | `packages/features/src/comments/ui/score-board/ScoreBoard.jsx` |
| 만족도 리뷰 작성 버튼 — "만족도 리뷰 작성하고 최대 500P 받기"(`rating_section.write_button_label`) | `packages/features/src/comments/ui/satisfaction-write-button/SatisfactionWriteButton.jsx` |
| 지지서명 작성/공유 컨테이너 — "지지서명 하기"·"나의 지지서명 공유하기" | `packages/features/src/comments/ui/SupportShareCommentWriteContainer.jsx` (+ `SupportShareCommentEditContainer.jsx`) |
| 카테고리 필터 — "전체/응원/의견/사진체험리뷰만/체험리뷰만"(`funding_detail_community_comments_page.comment_list.*`) | `packages/features/src/comments/ui/filter/CategoryFilter.jsx` |
| 정렬 선택 — "최신순/높은 평점/추천순" 등(`supporter_review_list.filter_*`) | `packages/features/src/comments/ui/order-select/OrderSelect.tsx` |
| 프로젝트 문의(도움말센터) 섹션 — "프로젝트 문의"(`help_center_section.title`), "도움말센터 바로 가기" | `packages/features/src/comments/ui/help-center/ProjectHelpCenterContainer.jsx` |
| 커뮤니티 가이드 안내 박스 — "커뮤니티 가이드"(`funding_detail_community_page.guideline_message_box.title`) | `packages/features/src/comments/ui/CommunityGuideMessageBox.jsx` |
| 번역 보기 버튼 — **하드코딩** "번역보기 (한글)", "번역됨", "원문보기" | `packages/features/src/comments/ui/content/TranslateButton.tsx` |
| 이미지 업로더 — "PNG, JPG 파일만 업로드할 수 있어요"(`reward_choice_modal.file_extension_validation_failure_modal.message`) | `packages/features/src/comments/ui/image-uploader/ImageUploader.jsx` |
| 신고/더보기 팝메뉴 — "신고"(`review_list_item.report_label`) | `packages/features/src/comments/ui/ReportPopMenu.jsx`, `popup/PopMenu.jsx` |
| 글쓰기 플로팅 버튼 — "글쓰기"(`comment_section.write_post_button_label`) | `packages/features/src/comments/ui/write-button/FloatingButton.tsx` (+ `WriteCommentButtonContainer.jsx`) |

## 새소식 (news 탭)

관련 이슈: `FE1-876`(스토리 상단 새소식을 커뮤니티에도 노출)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 새소식 목록 페이지 — 헤더 "새소식"(`funding_detail_news_page.header.title`), 빈 상태 "등록된 새소식이 없어요." | `apps/global/src/pages/funding/[projectNo]/news/FundingDetailNewsPage.tsx` (+ `_ui/NewsList.jsx`, `NewsListHeader.jsx`) |
| 새소식 정렬/필터 — "최신순/과거순"(`sort_select.*`), "전체"(`type_select.type_filter_all_text`), 목록아이템 "댓글 {{arg_0}}" | `apps/global/src/pages/funding/[projectNo]/news/_ui/SelectBoxLabel.jsx`, `NewsList.jsx` |
| 새소식 상세 페이지 — "목록으로 이동하기"(`navigation_bar.back_button_label`), "더보기" (keyPrefix `funding_detail_news_detail_page`) | `apps/global/src/pages/funding/[projectNo]/news/[newsID]/FundingDetailNewsDetailPage.tsx` (+ `_ui/NewsContent.tsx`) |
| 새소식 댓글(상세) — "{{arg_0}} 님 응원을 남겨 주세요"(`funding_detail_news_detail_page.config.comment_input_write_message`) | `apps/global/src/pages/funding/[projectNo]/news/[newsID]/_ui/NewsComment.tsx` |

## 스토리 · 리워드 · 환불·정책 · 서포터 탭

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 스토리 탭 페이지(스토리 본문·추천/슈퍼메이커/서비스특징 배너) — "프로젝트 스토리"(`funding_detail_story_page.project_story_section.title`), "AI 스토리 요약", "목표 달성 후 결제"·"전액 환불 보장"(`service_feature_banner_section.*`) | `apps/global/src/pages/funding/[projectNo]/story/FundingDetailStoryPage.tsx` (+ Desktop/Mobile) |
| 리워드 선택 탭 페이지 — 헤더 "리워드 선택"/EN "Rewards"(`funding_detail_rewards_page.header.title`), "한국에서만 참여 가능한 리워드예요" | `apps/global/src/pages/funding/[projectNo]/rewards/FundingRewardsPage.tsx` |
| 리워드 정보(고시) 탭 페이지 — "리워드 정보 제공 고시"(`funding_detail_reward_details_page.header.title`), "리워드 상세 정보" | `apps/global/src/pages/funding/[projectNo]/reward-details/FundingDetailRewardDetailsPage.tsx` |
| 환불·정책 탭 페이지 — "환불·정책"/EN "Refund policy"(`funding_detail_refund_policy_page.header.title`) | `apps/global/src/pages/funding/[projectNo]/refund-policy/FundingDetailRefundPolicyPage.tsx` |
| 서포터 탭 페이지 — "참여하는 서포터"(`funding_detail_supporters_page.header.title`), "익명의 서포터", "님이 펀딩했어요", 빈 상태 "아직 참여하는 서포터가 없어요" | `apps/global/src/pages/funding/[projectNo]/supporters/FundingDetailSupportersPage.tsx` (+ `_ui/FundingSupportSupporterList.jsx`) |

## 상세 페이지 모달 · 부가 (page `_ui`)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 오픈예정 알림취소 후 추천 모달 — **하드코딩** "곧 오픈할 펀딩 제품 먼저 체험해 보세요" | `apps/global/src/pages/funding/[projectNo]/_ui/ComingSoonRecommendationModal/ComingSoonRecommendationModal.tsx` |
| 소싱클럽 링크 모달 (keyPrefix `sourcing_club_link_modal`: `header.title_markdown`/`content.description_markdown`/`footer.confirm_button_label`) | `apps/global/src/pages/funding/[projectNo]/_ui/SourcingClubLinkModal/SourcingClubLinkModal.tsx` |
| 상세 모달 포털(모달 마운트 지점) | `apps/global/src/pages/funding/[projectNo]/_ui/FundingDetailModalPortal/FundingDetailModalPortal.tsx` |
| 결제 후 액션 모달 플로우 훅(알림완료/관심완료 모달 연쇄) — "알림을 설정했어요!…", "메이커에게 오픈 요청을 완료했어요!…" | `apps/global/src/pages/funding/[projectNo]/_lib/usePostActionModalFlow.ts` |

## 네이티브 상세 (`packages/features/src/native-detail`)

관련 이슈: `FE1-712`(펀딩 상세 네이티브 타임아웃 제거). 이 폴더는 UI 문구가 없는 앱-웹뷰 연동/레이아웃 제어 로직입니다.

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 네이티브 상세 컨텍스트(네이티브 헤더 표시 여부·헤더 높이 전달) | `packages/features/src/native-detail/context/NativeDetailContext.tsx` |
| 네이티브 상세 상태 추출 훅(Context 우선, Outlet fallback) | `packages/features/src/native-detail/hooks/useNativeDetailPage.ts` |
| 인트로 조건부 렌더 래퍼 — 네이티브 헤더 활성 시 인트로(이미지/비디오) 숨김 | `packages/features/src/native-detail/components/NativeAwareIntro.tsx` |
| 네이티브 헤더 스펙 주입 HOC / 네이티브 앱 게이트 처리 판별 | `packages/features/src/native-detail/lib/withNativeHeaderSpec.ts`, `isGateHandledByNativeApp.ts` |

## 데이터 수집 / API 훅

관련 이슈: `FE1-562`·`FE1-630`·`FE1-638`·`FE1-706`·`FE1-767`(상세페이지 유저 활동 데이터 노출), `FE1-870`(데이터 수집 마이그레이션)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 리워드 만족도 점수 조회 / 메이커 정보 조회 (데이터 훅, UI 문구 없음) | `apps/global/src/features/detail/api/useRewardScores.js`, `useMakerInfo.js` |

## 참고 (문구 매핑 주의)

- CTA "펀딩하기"와 리워드 모달의 "다음 단계"·"펀딩하기"는 **영어에서 모두 "Continue to Checkout"** 으로 매핑됩니다 (`reward_choice_modal.button_section.continue_button_label`, `footer.checkout_button_label`, `funding_detail_page.cta_section.checkout_button_label`).
- **하드코딩 문구(i18n 미적용)** 가 남아 있어 국제화 대상 후보인 곳: `FundingProductPurchaseButton`, `TranslateButton`, `ComingSoonRecommendationModal`, `DesignModePanel`.

## 이슈 히스토리 (펀딩 상세 경로를 건드린 Jira 이슈)

> `git log` 로 위 경로들을 수정한 커밋의 이슈키를 수집하고 Jira 제목을 병기했습니다. 상태는 모두 종료/해결(2026-07 기준).

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-511 | 작업 | [Web][펀딩상세 통합] 펀딩 상세 국내/해외 통합 |
| FE1-616 | 작업 | [Web][펀딩상세 통합] 레거시 코드 제거 |
| FE1-645 | 작업 | [Web][펀딩상세 통합] 개발자 검증 |
| FE1-388 | 에픽 | [FE] 글로벌 달러 결제 도입 |
| FE1-470 | 작업 | [FE] 글로벌 달러 결제 - Phase 4: 결제 완료 + 마이와디즈 결제 상세 |
| FE1-562 | 작업 | [Web] 상세페이지 유저 활동 데이터 노출 개발 |
| FE1-630 | 작업 | [Web] 상세페이지 유저 활동 데이터 노출(데이터 수집) |
| FE1-638 | 작업 | [WEB] 상세페이지 유저 활동 데이터 노출 - QA |
| FE1-706 | 버그 | [Web] 상세 페이지 유저 활동 데이터 노출 - 라이브 배포 후 이슈 대응 |
| FE1-767 | 작업 | [Web] [추천 알고리즘] 프로젝트 카드 내 유저 활동 데이터 노출 구현 |
| FE1-644 | 스토리 | [FE] 달러 쿠폰 - 서포터 쿠폰 다운로드 지면 |
| FE1-657 | 버그 | [Web] 펀딩 상세 데스크탑에서 스크롤 버그 수정 |
| FE1-676 | 작업 | 펀딩 상세 - 컨텐츠 영역의 상단 여백을 40px로 통일 |
| FE1-688 | 에픽 | [Web][스토어] 스토어 코드 마이그레이션 (static -> global) for SPA |
| FE1-712 | 작업 | [web] 펀딩 상세 네이티브 타임아웃 제거 |
| FE1-722 | 에픽 | 이용언어가 일본어, 중국어일 때, 줄바꿈 기준을 '글자 단위'로 변경 |
| FE1-847 | 에픽 | 앱 다운로드 로그인 적극 유도 |
| FE1-849 | 작업 | [Web] 글로벌 펀딩 상세 CTA 버튼 동작 수정 |
| FE1-850 | 작업 | [Web] 글로벌 펀딩 상세 로그인 유도 모달 구현 |
| FE1-870 | 작업 | [Web] 데이터 수집 마이그레이션 |
| FE1-876 | 작업 | 스토리 상단 노출 새소식을 커뮤니티에도 추가 노출 |
| FE1-889 | 작업 | [Web] canonicalUrl 추가 작업 |
| FE1-927 | 작업 | [Web] E2E 테스트를 위한 attribute 추가 |
| FE1-956 | 작업 | [Web] 마케팅 수신 동의 모달 마이그레이션 |
| FE1-979 | 버그 | [Web] 직접 입력 옵션 가이드 문구 미노출 (inputGuide/optionGuide 필드 불일치) |
| FE1-1110 | 작업 | [Web] 상세 통합으로 인한 Regression 기능 확인 |
| FE1-1226 | 작업 | [Web] 앱 로그인 모달에 tracking-data 를 전달해 주기 |

---

# 결제 (Funding Payment)

> 소스: `apps/global/src/pages/funding/payment/**`(결제·완료·대기 페이지), `packages/features/src/funding-payment`(할부 안내), `packages/features/src/simple-pay`(간편결제).
> 국내/글로벌 분기: 결제수단·결제금액 섹션이 국내(NicePay·간편결제 등)와 글로벌(Stripe·Alipay·USD 표기)로 나뉩니다.

## 결제 페이지 (레이아웃 · 헤더)

관련 이슈: `FE1-42`(한국/글로벌 결제 동선 통합 · 에픽), `FE1-469`(달러 결제 Phase 3 — 결제 페이지/결제수단 분기)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 페이지 헤더 — `header.title`="주문 및 결제" / EN "Order and Payment" | `apps/global/src/pages/funding/payment/FundingPaymentDesktopPage.tsx` |
| 결제 페이지 모바일 진입 · 실패 모달 트리거 (`payment_failure_modal.*`, `invalid_order_message`="유효하지 않은 주문이에요.") | `apps/global/src/pages/funding/payment/FundingPaymentPage.tsx` |
| 데스크톱/모바일 레이아웃 분기 (구조 파일) | `apps/global/src/pages/funding/payment/FundingPaymentLayout.tsx` |
| 결제 체크아웃 상태/컨텍스트 (상태 모델) | `apps/global/src/pages/funding/payment/_model/useFundingCheckout.tsx` |

## 리워드 · 배송지 · 서포터 정보

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 선택한 리워드 — `reward_section.title`="선택한 리워드", `option_label`="옵션", `shipping_fee_label`="배송비", `optional_tip_label`="추가 후원금" | `apps/global/src/pages/funding/payment/_ui/RewardsSection/RewardsSection.tsx` |
| 리워드 배송지 — `shipping_address_section.title`="리워드 배송지", `customs_code_label`="개인통관고유부호", `new_address_button_label`="신규 배송지 추가" | `apps/global/src/pages/funding/payment/_ui/ShippingAddressSection/ShippingAddressSection.tsx` |
| 서포터 정보 — `supporter_section.title`="서포터 정보", `phone_label`="휴대폰 인증", `newsletter_label`="펀딩 새소식 및 결제 관련 안내를 받습니다. (필수)" | `apps/global/src/pages/funding/payment/_ui/SupporterSection/SupporterSection.tsx` |
| 서포터클럽 특별가 프로모션 — **하드코딩** "서포터클럽 올인원 특별 금액", "할인 금액" | `apps/global/src/pages/funding/payment/_ui/SupporterClubPromotion/SupporterClubPromotion.tsx` |

## 할인 (쿠폰 · 포인트)

관련 이슈: `FE1-644`(달러 쿠폰 — 서포터 쿠폰 다운로드 지면)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 쿠폰·포인트 적용 — `discount_section.title`="쿠폰,포인트 적용", `coupon_label`="쿠폰", `points_label`="포인트", `use_all_button_label`="모두 사용", `current_point_text`="보유 포인트: {{arg_0}}P" | `apps/global/src/pages/funding/payment/_ui/DiscountSection/DiscountSection.tsx` |
| 쿠폰 선택 메뉴 — `coupon_enabled_placeholder`="쿠폰을 선택해 주세요", `coupon_empty_option_label`="쿠폰 사용 안 함", `coupon_available_until_text`="{{arg_0}}까지 사용 가능" | `apps/global/src/pages/funding/payment/_ui/DiscountSection/components/CouponSelectMenu/CouponSelectMenu.tsx` |

## 결제수단

관련 이슈: `FE1-469`(결제수단 분기), `FE1-611`(iOS 26 간편결제 비밀번호 가상키패드 핫픽스), `FE1-1057`(토스페이 혜택 문구 수정)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 수단 섹션 (국내/글로벌 분기) — `payment_method_section.title`="결제 수단" / EN "Payment method", `pay_now_label`="지금 결제"/"Pay now", `scheduled_payment_label`="예약 결제"/"Pay later", 글로벌은 Stripe/Alipay 렌더 | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/PaymentMethodSection.tsx` |
| 국내 결제수단 목록 컨테이너 (신용/체크카드·간편결제·카카오/네이버/토스/애플페이 조합) | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/KoreaPaymentOptions.tsx` |
| 신용/체크카드(NicePay) + 장기할부 옵션 — **하드코딩** "신용/체크카드" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/NicePayOption.tsx` |
| 카드 할부 개월 선택 — **하드코딩** "일시불", "2개월"~"11개월" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/DirectPayOption.tsx` |
| 와디즈 간편결제 선택 — **하드코딩** "와디즈 간편결제" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/SimplePayOption.tsx` |
| 카카오페이 (로고 아트웍) | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/KakaoPayOption.tsx` |
| 네이버페이 (카드/포인트 서브옵션) — **하드코딩** "카드 결제", "포인트 결제", "복합결제(카드+포인트)는 지원하지 않아요…" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/NaverPayOption.tsx` |
| 토스페이 (프로모션 배너) — **하드코딩** "최대 3천원", "생애 첫 결제 시 : 5만원 이상 결제 시 3,000원 할인…" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/TossPayOption.tsx` |
| 애플페이 (로고 아트웍) | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/ApplePayOption.tsx` |
| 현금영수증 신청 폼 — **하드코딩** "현금영수증", "신청", "미신청", "소득공제용" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/CashReceiptForm.tsx` |
| 참여 공개여부 선택 — **하드코딩** "프로젝트 참여 공개여부 (선택)", "이름 비공개", "금액 비공개" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/PublicitySection.tsx` |

## 결제 금액

관련 이슈: `FE1-388`(글로벌 달러 결제 도입 · 에픽), `FE1-743`(결제금액 섹션 표시통화 기본 노출)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 금액 요약 — `payment_amount_section.title`="결제 금액" / EN "Payment amount", `total_payment_amount_label`="총 결제 금액", `reward_label`="리워드 금액", `shipping_label`="배송비", `coupon_label`="쿠폰 할인", `point_label`="포인트 할인" | `apps/global/src/pages/funding/payment/_ui/PaymentAmountSection/PaymentAmountSection.tsx` |
| 글로벌 결제 금액(USD/현지통화) — `usd_payment_notice`="결제는 USD로 처리됩니다.", `view_local_currency_button_label`="현지 통화 보기", `krw_billing_notice`="표시된 금액은 대략적인 환산 금액이며, 실제로는 {{arg_0}}으로 청구됩니다." | `apps/global/src/pages/funding/payment/_ui/PaymentAmountSection/GlobalPaymentAmount.tsx` |

## 약관 동의 · 결제하기(체크아웃)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 약관 동의 + 결제하기 버튼 — `button_section.submit_button_label`="결제하기" / EN "Submit Payment", `submit_button_label_v2`="{{arg_0}}원 결제하기", `terms_and_conditions_section.title`="주문을 제출함으로써 다음 사항에 동의하는 것으로 간주합니다." | `apps/global/src/pages/funding/payment/_ui/TermsAndCheckout/TermsAndCheckout.tsx` |
| 국내 필수 약관 체크리스트 — **하드코딩** "결제 진행 필수 동의", "구매조건, 결제 진행 및 결제 대행 서비스 동의(필수)", "개인정보 제3자 제공 동의 (필수)" | `apps/global/src/pages/funding/payment/_ui/TermsAndCheckout/RewardPaymentTerms.tsx` |
| 환율(FX) 조회 실패 처리 — `funding_payment_page` 프리픽스 에러 안내 | `apps/global/src/pages/funding/payment/_ui/BillingFxErrorHandler/BillingFxErrorHandler.tsx` |

## 간편결제 (`packages/features/src/simple-pay`)

> 이 폴더는 `useTranslation` 미사용 — 문구 전부 **하드코딩**(국제화 후보).

관련 이슈: `FE1-611`(iOS 26 간편결제 비밀번호 모달 핫픽스)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 간편결제 카드 등록 모달(2스텝) — "간편결제 등록하기" / "간편결제 비밀번호 입력", "카드 등록하고 빠르게 결제해요." | `packages/features/src/simple-pay/ui/CardRegistrationModal/CardRegistrationModal.tsx` |
| 카드 정보 입력 폼 — "신용/체크카드", "유효기간", "카드 비밀번호", "생년월일", "스캔으로 자동 등록하기" | `packages/features/src/simple-pay/ui/CardInfoForm/CardInfoForm.tsx` |
| 결제 비밀번호 설정 폼 — "결제 비밀번호", "결제 비밀번호 재입력", "비밀번호 6자리" | `packages/features/src/simple-pay/ui/CardPasswordForm/CardPasswordForm.tsx` |
| 카드 등록 완료 모달 — "간편결제 정보가 안전하게 등록되었습니다.", "참여 중인 프로젝트 결제도 변경할게요", "확인" | `packages/features/src/simple-pay/ui/CardRegisterSuccessModal/CardRegisterSuccessModal.tsx` |
| 간편결제 비밀번호 확인 모달 — "결제 비밀번호 입력", "…결제 비밀번호 6자리를 입력하세요.", "비밀번호를 잊어버리셨나요?" | `packages/features/src/simple-pay/ui/SimplePayPasscodeConfirmModal/SimplePayPasscodeConfirmModal.tsx` |
| 등록 카드 표시 UI (삭제/유효기간 만료 안내) — "유효기간", "해당 카드의 유효기간이 만료 되었습니다.", "결제 정보를 삭제하시겠어요?" | `packages/features/src/simple-pay/ui/SimplePayCard/SimplePayCard.tsx` |
| 비밀번호 입력 숫자패드 — "전체 삭제", "삭제" | `packages/features/src/simple-pay/ui/NumPad/NumPad.tsx` |
| 참여 중 프로젝트 결제정보 일괄 변경 — 토스트 "선택한 프로젝트의 결제 정보가 변경되었습니다." / "결제정보 변경 중 오류가 발생했습니다…" | `packages/features/src/simple-pay/lib/changePaymentReservation.tsx` |
| 간편결제 데이터 조회 훅 | `packages/features/src/simple-pay/api/useSimplePay.ts` |

## 할부 안내 (`packages/features/src/funding-payment`)

> 문구 전부 **하드코딩**.

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 무이자/장기 할부 안내 모달 — 탭 "무이자 할부 안내", "장기 할부 안내", "부분 무이자할부 안내…", "[유의사항]" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/InterestFreeInfoModal.tsx` |
| 할부 안내 진입 버튼 — "신용/체크 카드 할부 안내" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/InstallmentInfoButton.tsx` |
| 무이자 할부 안내 버튼 — "무이자 할부 안내" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/InterestFreeInfoButton.tsx` |
| 장기 할부 안내 버튼 — "장기 할부 안내" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/LongTermInstallmentInfoButton.tsx` |

## 결제 완료 화면

관련 이슈: `FE1-470`(달러 결제 Phase 4 — 결제 완료 + 마이와디즈 결제 상세)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 주문 완료 헤더/요약 — `funding_payment_completed_page.header.title`="주문 완료" / EN "Your order is complete", `header.description`="프로젝트 성공 시 결제가 처리되고 결제 성공 시 리워드를 발송해요.", `content.view_my_orders_button_label`="참여 내역 보기", `back_to_details_button_label`="상세 페이지 보기" | `apps/global/src/pages/funding/payment/completed/_ui/OrderCompletedSection/OrderCompletedSection.tsx` |
| 완료 페이지 컨테이너 + AI 추천/구매 이벤트 트래킹 — **하드코딩(트래킹명)** "결제완료_AI추천" | `apps/global/src/pages/funding/payment/completed/FundingPaymentCompletedPage.tsx` |
| 메이커 팔로우 유도 — `maker_following_section.description`="메이커 소식을 받아보고 싶다면?" | `apps/global/src/pages/funding/payment/completed/_ui/OrderCompletedSection/MakerFollowingSection.tsx` |
| 해외배송 유의사항 박스 — `international_shipping_message_box.title`="유의 사항", `description_1`="해외배송 프로젝트의 경우 배송이 시작된 이후 단순변심 환불은 거절될 수 있어요…" | `packages/features/src/funding-payment/ui/PaymentCompleteInternationalShippingSection/PaymentCompleteInternationalShippingSection.tsx` |
| 배송지 국가 변경 확인 모달 — `country_change_confirm_modal.title`="국가 변경", `description`="방금 선택한 배송지 국가로 회원 정보를 업데이트 할까요?", `confirm_button_label`="국가 변경하기" | `apps/global/src/pages/funding/payment/completed/_ui/CountryChangeConfirmModal/CountryChangeConfirmModal.tsx` |

## 결제 진행 중 (pending) · 결제 실패 안내

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 진행 중 화면 — `funding_payment_pending_page.header.title`="결제 진행 중", `header.description`="처리 중이니 잠시만 기다려 주세요.", 지연 모달 `pending_failure_modal.title`="결제가 지연되고 있어요" | `apps/global/src/pages/funding/payment/pending/FundingPaymentPendingPage.tsx` |
| 결제 실패 모달 문구 모음 (i18n, 트리거는 `FundingPaymentPage.tsx`) — `payment_failure_modal.title`="결제를 진행할 수 없어요", `out_of_stock_message`="품절된 상품이 있어요…", `expired_order_session_message`="결제 유효 시간이 초과됐어요…" | `packages/i18n/src/supporter/languages/ko.json` (키 `funding_payment_page.payment_failure_modal`) |

## 이슈 히스토리 (결제 경로를 건드린 Jira 이슈)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-42 | 에픽 | [FE1][프로젝트클렌징] 한국/글로벌 결제 동선 통합 |
| FE1-388 | 에픽 | [FE] 글로벌 달러 결제 도입 |
| FE1-469 | 작업 | [FE] 글로벌 달러 결제 - Phase 3: 결제 페이지 금액 표시 + 결제수단 분기 |
| FE1-470 | 작업 | [FE] 글로벌 달러 결제 - Phase 4: 결제 완료 + 마이와디즈 결제 상세 |
| FE1-611 | 버그 | [iOS 26] 간편결제 비밀번호 모달 가상키패드 터치 미동작 핫픽스 |
| FE1-644 | 스토리 | [FE] 달러 쿠폰 - 서포터 쿠폰 다운로드 지면 |
| FE1-664 | 작업 | [QA] 글로벌 달러 결제 도입 - QA 이슈 수정 |
| FE1-743 | 작업 | [Web] 글로벌 결제 페이지 결제금액 섹션에서 표시통화 기본 노출로 변경 |
| FE1-800 | 작업 | [Web] 글로벌 달러 결제 - 환불 동선 관련 후속 대응 |
| FE1-1057 | 작업 | [Web] 토스페이 혜택 문구 수정 |
| FE1-927 | 작업 | [Web] E2E 테스트를 위한 attribute 추가 |
| FE1-1110 | 작업 | [Web] 상세 통합으로 인한 Regression 기능 확인 |

---

# 홈 / 서비스홈 (Home / Service-Home)

> 국내 홈(`KoreaHomeDesktopPage` + `packages/widgets/src/home`)은 대부분 **한국어 하드코딩**, 글로벌 홈(`HomeDesktopPage` + `home_page` keyPrefix)과 서비스홈은 i18n 사용. 홈 섹션 위젯 상당수는 배너/메뉴 API 응답을 그대로 렌더하는 데이터 기반이라 고정 문구가 없습니다.

## 홈 — 라우팅 / 레이아웃

관련 이슈: `FE1-510`(국내/글로벌 통합 · 에픽), `FE1-512`(메인 홈 통합 for SPA), `FE1-62`(글로벌 앱 성능 개선)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 홈 진입 분기 (모바일 / 국내 데스크톱 / 글로벌 데스크톱) | `apps/global/src/pages/home/HomePage.tsx` |
| 홈 공통 레이아웃 (헤더·FAB) / 데스크톱 / 모바일 | `apps/global/src/pages/home/HomeLayout.tsx` (+ `HomeDesktopLayout.tsx`, `HomeMobileLayout.tsx`) |
| 홈 페이지뷰 트래킹 훅 | `apps/global/src/pages/home/_api/useHomePageViewEventTracker.ts` |

## 홈 — 국내 데스크톱 (`KoreaHomeDesktopPage` 조립)

관련 이슈: `FE1-561`(퀵메뉴 가독성 개선 · 에픽), `FE1-988`(SHORTCUT 변경), `FE1-767`(프로젝트 카드 유저 활동 데이터)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 국내 홈 데스크톱 전체 조립 (검색·랭킹·추천·피드 섹션 배치) | `apps/global/src/pages/home/KoreaHomeDesktopPage.tsx` |
| GNB 카테고리 바 — GA `홈_카테고리`, aria "다음/이전 리스트" **하드코딩** | `packages/widgets/src/home/ui/GNBCategoryBar/GNBCategoryBar.tsx` |
| 취향 맞춤 추천 펀딩 — **하드코딩** "취향 맞춤 프로젝트", "와디즈 AI가 서포터님들의 취향을 분석하여 맞춤 프로젝트를 추천해요", "AI 추천 더보기" | `packages/widgets/src/home/ui/RecommendFundingWrap/RecommendFundingWrap.tsx` |
| 데스크톱 랭킹 영역 (카테고리 랭킹 + 컬렉션 카드) | `packages/widgets/src/home/ui/RankingDesktop/RankingDesktop.tsx` |
| 스토어 추천 제품 — **하드코딩** "스토어 추천 제품", "팬들이 인정한 성공 펀딩 집합샵" | `packages/widgets/src/home/ui/RecommendationStore/RecommendationStore.tsx` |
| 좋아할 프로젝트 — **하드코딩** "{닉네임}님이 좋아할 프로젝트" | `packages/widgets/src/home/ui/LikableFundingWrap/LikableFundingWrap.tsx` |
| 얼리버드 섹션/카드 — **하드코딩** "얼리버드", "먼저 참여하는 분들께 드리는 얼리버드 혜택", "지금 참여하기" | `packages/widgets/src/home/ui/EarlybirdApp/EarlybirdApp.tsx` (+ `EarlybirdCard.tsx`) |
| 기획전 섹션/카드 — **하드코딩** "기획전", "오픈예정", "{rate}% 달성", "{n}명 인증" | `packages/widgets/src/home/ui/PlannedApp/PlannedApp.tsx` (+ `PlannedAppCampaignCard.tsx`, `PlannedCard/PlannedCard.tsx`) |
| 트렌드 섹션 — **하드코딩** "트렌드", "#급상승 프로젝트", "#지지서명한 프로젝트", "주목하세요! 오늘 오픈한 프로젝트" | `packages/widgets/src/home/ui/TrendApp/TrendApp.tsx` |
| 하단 추천 푸터 (보도자료 + 배너 묶음) | `packages/widgets/src/home/ui/RecommendationFooter/RecommendationFooter.tsx` |
| 와디즈 소식(보도자료) — **하드코딩** "와디즈 소식" | `packages/widgets/src/home/ui/PressReleaseWrap/PressReleaseWrap.tsx` |
| 펀딩 오픈 정적 배너 — **하드코딩** "지금 바로 와디즈에서 도전해 보세요!", "프로젝트 만들기" | `packages/widgets/src/home/ui/FundingOpenStaticBanner/FundingOpenStaticBanner.tsx` |
| W9 정적 배너 (`MW9` 지면) / PC 메인 팝 배너 (`MCB` 지면) — 배너 API 데이터 기반 | `packages/widgets/src/home/ui/W9StaticBanner/W9StaticBanner.tsx`, `MainPopBanner/MainPopBanner.tsx` |
| 공지 팝업 (`WEB_MAIN`) — **하드코딩** "오늘 하루 보지 않기", "다시 보지 않기", "닫기" | `packages/widgets/src/home/ui/NoticePopup/NoticePopup.tsx` |
| PC 메인 "펀딩으로 내편찾기" 배너 — **하드코딩** "{닉네임}님," + 카테고리별 카피 | `packages/widgets/src/home/ui/MainFindingBanner/MainFindingBanner.tsx` |
| PC 메인 프로젝트 만들기 홍보 배너 — **하드코딩** "{닉네임}님, {키워드}해 보실래요?" | `packages/widgets/src/home/ui/MainMakeProjectBanner/MainMakeProjectBanner.tsx` |

## 홈 — 글로벌 데스크톱/모바일 (`home_page` keyPrefix)

관련 이슈: `FE1-178`(keyvisual api 적용), `FE1-767`(추천 알고리즘)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 글로벌 홈 데스크톱 조립 (검색·퀵메뉴·키비주얼·추천·최근본) | `apps/global/src/pages/home/HomeDesktopPage.tsx` |
| 추천 프로젝트 섹션1 — `home_page.recommendation_project_1_section.title`="추천 프로젝트", `ai_tooltip_message`="와디즈 AI가 …맞춤 프로젝트를 추천해요" | `apps/global/src/pages/home/HomeDesktopPage.tsx` |
| 최근 본 프로젝트 섹션 — `recently_viewed_project_section.nickname_title`="{{arg_0}} 님이 최근에 봤어요" | `apps/global/src/pages/home/HomeDesktopPage.tsx` |
| 추천 프로젝트 섹션2 — `recommendation_project_2_section.title`="서포터님이 좋아할 만한", `content.more_button_label`="더보기" | `apps/global/src/pages/home/HomeDesktopPage.tsx` |
| 모바일 홈 (cardType 기반 무한 피드) — 문구는 API 응답 기반 | `apps/global/src/pages/home/HomeMobilePage.tsx` |
| 키비주얼 데스크톱 배너 (국내 광고 `main`/글로벌 분기) — GA "홈_키비주얼배너" | `apps/global/src/pages/home/_ui/KeyVisualBanner/KeyVisualDesktopBanner.tsx` |
| 메인 키비주얼 캐러셀 배너 (데스크톱) | `apps/global/src/pages/home/_ui/MainKeyVisualBanner/MainDesktopKeyVisualBanner.tsx` |
| 카테고리 트렌드 프로젝트 섹션 — 빈상태 `empty.title`="프로젝트가 없어요", `empty.description`="다음에 다시 확인하거나 다른 국가의 프로젝트를 탐색해 보세요." | `apps/global/src/pages/home/_ui/CategoryTrendProjectSection/CategoryTrendProjectDesktopSection.tsx` (+ Mobile) |
| 지표(Metric) 섹션 — 제목·설명 API 데이터 기반 | `apps/global/src/pages/home/_ui/MetricSection/MetricDesktopSection.tsx` (+ `MetricDefinitionList.tsx`) |
| 글로벌 서비스 안내 링크 배너 — **하드코딩** "Learn about Global services" | `apps/global/src/pages/home/_ui/MetricSection/LinkBanner.tsx` |
| 홈 피처 컴포넌트 (퀵메뉴·숏컷·컬렉션·배너 — 모두 메뉴/배너 API 데이터 기반) | `packages/features/src/home/ui/{QuickMenu,ShortCut,CollectionSlider,Banner,BannerSlider,PCMarketingBannerList}/` |

## 서비스홈 (펀딩/프리오더/오픈예정 홈)

관련 이슈: `FE1-511`(펀딩 상세 국내/해외 통합), `FE1-549`(Main Feed 로직 공통화)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 서비스홈 레이아웃 진입 (모바일/데스크톱 분기) | `apps/global/src/pages/service-home/FundingHomeLayout.tsx` (+ Desktop/Mobile) |
| 서비스홈 공통 페이지 골격 (키비주얼+카테고리탭+필터+리스트) | `packages/widgets/src/service-home/ui/ServiceHomePage.tsx` |
| 펀딩 홈 — GA "펀딩(홈)", 경로 `/web/wreward/category` | `packages/widgets/src/service-home/ui/FundingHomePage.tsx` |
| 프리오더 홈 — GA "프리오더(홈)", 경로 `/web/preorder/main` | `packages/widgets/src/service-home/ui/PreorderHomePage.tsx` |
| 오픈예정(런칭순) 홈 — GA "오픈예정(홈)", 경로 `/web/wreward/comingsoon` | `packages/widgets/src/service-home/ui/LaunchingSoonHomePage.tsx` |
| 필터/정렬 옵션 — **하드코딩** "전체·진행중·종료된", "추천순·인기순·모집금액순·마감임박순·최신순", (오픈예정) "알림신청순·오픈임박순·지지서명순" | `packages/widgets/src/service-home/config/options.ts` |
| 키비주얼 배너 섹션 (광고/일반 지면 코드 분기) | `packages/features/src/service-home/ui/KeyVisualBannerSection/KeyVisualBannerSection.tsx` (+ `KeyVisualBannerContainer.tsx`) |
| 카테고리 탭바 (대분류/소분류) — 카테고리명 API 데이터 기반, "전체" 처리 | `packages/features/src/service-home/ui/{CategoryTabBarSection,MainCategoryTabBar,SubCategoryTabBar}/` |
| 필터/정렬 섹션 — **하드코딩** 불리언 필터 "슈퍼메이커", GA "…_필터/_정렬" | `packages/features/src/service-home/ui/FilterSection/FilterSection.tsx` |
| 프로젝트 리스트 섹션 — **하드코딩** 빈 상태 "현재 새로운 프로젝트를 준비 중이에요." | `packages/features/src/service-home/ui/ProjectListSection/ProjectListSection.tsx` |
| 서비스홈 파라미터 훅 (카테고리/정렬/필터 쿼리 관리) | `packages/features/src/service-home/lib/useServiceHomeParams.ts` |

## 메인 피드 · 추천 위젯

관련 이슈: `FE1-549`(Main Feed(친구) 로직 공통화), `FE1-767`(프로젝트 카드 유저 활동 데이터)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 친구 활동 피드 섹션 — **하드코딩** "친구", "내 친구의 활동을 확인해보세요", "친구 활동 더보기", GA "홈_피드_더보기" | `packages/widgets/src/main-feed/ui/MainFeed/MainFeed.tsx` |
| 피드 카드 — **하드코딩** "{name}님 참여", "{name}님 외 {n}명 참여", 배지 "만족도리뷰·지지서명·체험리뷰" | `packages/widgets/src/main-feed/ui/MainFeed/MainFeedCard.tsx` (+ `Badges.tsx`) |
| 상세 추천 섹션 — **하드코딩** "같이 보면 좋은 프로젝트", GA "펀딩(상세)_AI추천"·"스토어(상세)_AI추천" | `packages/widgets/src/recommendation/ui/RecommendationSection.tsx` |
| 연관 추천 섹션 — **하드코딩** (모바일) "와디즈 추천 프로젝트" / (PC) "같이 보면 좋은 프로젝트" | `packages/widgets/src/recommendation/ui/RecommendationRelatedSection.tsx` |
| 스토어 베스트 프로젝트 섹션 — **하드코딩** "스토어 베스트 프로젝트", "{카테고리} 전체 보기" | `packages/widgets/src/recommendation/ui/StoreBestProjectSection.tsx` |

## 이슈 히스토리 (홈/서비스홈 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-510 | 에픽 | [Web] 국내/글로벌 통합 |
| FE1-511 | 작업 | [Web][펀딩상세 통합] 펀딩 상세 국내/해외 통합 |
| FE1-512 | 작업 | [Web][펀딩상세 통합] 메인 홈 통합 - for SPA |
| FE1-549 | 작업 | [Web][펀딩상세 통합] Main의 Feed(친구)관련 로직 공통화 |
| FE1-561 | 에픽 | 퀵메뉴 가독성 개선 |
| FE1-988 | 작업 | [WEB] SHORTCUT 변경 |
| FE1-178 | 작업 | [Web] keyvisual api 적용 |
| FE1-767 | 작업 | [Web] [추천 알고리즘] 프로젝트 카드 내 유저 활동 데이터 노출 구현 |
| FE1-1113 | 하위작업 | [Web] 국내/글로벌 통합 리그레션 잔여 이슈 수정 |
| FE1-62 | 에픽 | 글로벌 앱 성능 개선 (번들 크기 개선+@) |

---

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

# 메이커 / 프로젝트 만들기 (Maker / Create-Project)

> `apps/global/src/pages/maker/**` 는 메이커센터(대시보드·내 프로젝트·정산일·매출UP·WAi·문의·프로필·전체메뉴), `create-project/**` 는 프로젝트 개설 랜딩. 대부분 i18n(`maker_page`, `maker_dashboard_page`, `maker_ad_page`, `create_project_page` 등).

## 메이커 홈 — 공통 레이아웃 / 탭

관련 이슈: `FE2-276`(메이커 홈 후속 WAi 사용성 개선 · 에픽), `FE2-567`(메이커 홈 WAi 호출 형태 변경), `FE2-650`(사용성 리서치), `FE2-670`(e2e)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 메이커 홈 진입 레이아웃 (반응형 분기) | `apps/global/src/pages/maker/MakerLayout.tsx` (+ Desktop/Mobile) |
| 상단/하단 탭바 — `maker_page.tab_bar`: "대시보드/내 프로젝트/정산일/WAi/매출 UP/전체 메뉴" | `apps/global/src/pages/maker/_ui/PageWrapper/{DesktopTabBar,MobileTabBar}/` |
| 온보딩 코치마크 — `maker_page.onboarding_section`: "한눈에 보는 프로젝트 관리", "WAi가 알려주는 오늘의 인사이트" | `apps/global/src/pages/maker/_lib/hooks/useCoachmark.tsx` |
| 프로모션 배너 (광고 배지, `useMakerBanner`) | `apps/global/src/pages/maker/_ui/PromotionBanner/PromotionBanner.tsx` |

## 메이커 대시보드

관련 이슈: `FE2-320`(대시보드 성공 공식 반영 · 에픽), `FE2-532`(스토리 생성 AI 진입구 개선)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 대시보드 페이지/섹션 컨테이너 | `apps/global/src/pages/maker/dashboard/MakerDashboardPage.tsx` (+ `_ui/DashboardSection/`) |
| 메이커 시작 미션 — `start_maker_guide_section`: "메이커 시작 가이드", "프로젝트 개설하기" / `pre_maker_mission_section`: "메이커 페이지 만들기", "프로젝트 오픈 예약하기" | `apps/global/src/pages/maker/_ui/MissionSection/MissionSection.tsx` |
| 내 정보 섹션 — `profile_section`: "메이커 페이지 관리", "팔로워 {{n}}", "오늘 {{n}}" | `apps/global/src/pages/maker/_ui/MyInfoSection/MyInfoSection.tsx` |
| 실시간 이슈(문의/서포터 의견) — `inquiry_feedback_tab_bar`: "실시간 문의"/"서포터 의견", "새로운 문의 내역이 없어요" | `apps/global/src/pages/maker/_ui/LiveIssueSection/LiveIssueSection.tsx` |
| 오늘 스토어 지표 — `today_store_section`: "스토어 오늘 지표", "결제 금액", "상품 발송 대기 중", "교환·반품 대기 중" | `apps/global/src/pages/maker/_ui/StoreSection/StoreSection.tsx` |
| 오늘의 인사이트 WAi 배너 — `today_insight_section`: "오늘의 인사이트" | `apps/global/src/pages/maker/_ui/WaiBanner/WaiBanner.tsx` |
| 성공 공식/진행 중 지표 + 진단 모달 — `project_metric_section.title` "진행 중 펀딩·프리오더", `key_success_metrics_modal`: "성공 프로젝트 평균 수치인 …상위 {{n}}%" | `apps/global/src/pages/maker/_ui/SuccessFormulaSection/SuccessFormulaSection.tsx` (+ `DiagnosisModal/DiagnosisModal.tsx`) |

## 내 프로젝트 / 정산일

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 내 프로젝트 페이지 (desktop/mobile 분기) | `apps/global/src/pages/maker/projects/MakerProjectsPage.tsx` (+ Layout) |
| 펀딩 프로젝트 목록/카드 — `my_projects_page`: "새로운 도전을 시작해 보세요!", "{{n}}% 달성", "심사 중", "이어서 작성하기" | `apps/global/src/pages/maker/projects/_ui/FundingProjectsContainer/` (+ `FundingCard/FundingCard.tsx`) |
| 스토어 프로젝트 목록/카드 — "성공한 리워드 상시 판매 하세요", "판매 중", "상품 발송하기", "교환·반품하기" | `apps/global/src/pages/maker/projects/_ui/StoreProjectsContainer/` (+ `StoreCard/StoreCard.tsx`) |
| 재오픈 프로젝트 컨테이너 — "재오픈 하기" | `apps/global/src/pages/maker/projects/_ui/ReopenProjectsContainer/` |
| 상태/종류 탭 (`status_tab_bar`, `projects_tab_bar`) | `apps/global/src/pages/maker/projects/_ui/{FilterTabs,ProjectTabs}/` |
| 스토리 생성 AI 배너 (`story_generation_banner`) | `apps/global/src/pages/maker/projects/_ui/StoryGenerationBanner/StoryGenerationBanner.tsx` |
| 정산일 페이지 — `maker_schedule_page.funding_section`: "최종정산 예정일", "선정산 완료일", "최종정산 예정일 계산기" | `apps/global/src/pages/maker/schedule/MakerSchedulePage.tsx` (+ `_ui/ProjectSection/`) |
| 정산 안내 배너/빈 상태 — "추가 약정에 서명해야 정산을 받을 수 있어요…", "예정된 정산 일정이 없어요" | `apps/global/src/pages/maker/schedule/_ui/{Banner,EmptySection}/` |

## 매출 UP (광고)

관련 이슈: `FE2-423`·`FE2-648`(매출 UP 페이지 개편 P1/P2 · 에픽), `FE2-649`(광고 목록 복구·부스터 쿠폰), `FE2-668`·`FE2-684`(링크/버튼 변경)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 매출 UP(광고) 메인 페이지 | `apps/global/src/pages/maker/ad/MakerAdPage.tsx` |
| 광고 상품 오프닝 섹션 — `sales_up_opening_section`: "부스터 쿠폰", "앱 메인 팝업", "펀딩 패키지" | `apps/global/src/pages/maker/ad/_ui/SalesUpOpeningSection/SalesUpOpeningSection.tsx` |
| 광고 서비스 배너 — `ad_service_banner_section`: "광고 상품 소개서", "광고 제안 서비스 신청" | `apps/global/src/pages/maker/ad/_ui/AdServiceBannerSection/AdServiceBannerSection.tsx` |
| 메이커 가이드(클래스/팁/VOD/WAi) — `maker_guide_section`: "매출 더하기, 메이커 클래스", "24시간 무료 신청! VOD 강의" | `apps/global/src/pages/maker/ad/_ui/MakerGuideSection/MakerGuideSection.tsx` (+ `WaiEntry.tsx`) |
| 진행 중 기획전·혜택 모집 배너 — `recruit_banner_section`: "진행 중인 기획전 · 혜택", "{{n}}일 남음" | `apps/global/src/pages/maker/ad/_ui/RecruitBannerSection/RecruitBannerSection.tsx` |
| 광고 서비스 카드/신청 (`ad_products_section`) | `apps/global/src/pages/maker/ad/_ui/AdServiceCardSection/AdServiceCardSection.tsx` |
| 타겟/푸시/디스플레이 광고 상세 (`maker_ad_{target,push,display}_page.key_visual_section`) | `apps/global/src/pages/maker/ad/(type)/{target,push,display}/` |

## WAi / 문의 / 전체 메뉴 / 메이커 프로필

관련 이슈: `FE2-441`(WAi io 도메인 대응)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| WAi 대화 컨테이너 — `maker_wai_page.greeting_section`: "메이커님, 저와 함께 오늘의 인사이트를 분석해볼까요?", `error_section`: "앗! 잠깐 문제가 발생했어요", "다시 연결하기" | `apps/global/src/pages/maker/wai/_ui/MakerWAiContainer/MakerWAiContainer.tsx` |
| 1:1 문의 빈 상태 — `maker_inquiries_page.empty_section`: "메시지가 없어요", "프로젝트 오픈하고, 서포터와 소통해 보세요!" | `apps/global/src/pages/maker/inquiries/InquiriesEmptyView/InquiriesEmptyView.tsx` |
| 전체 메뉴 네비게이션 — `maker_menu_page.navbar`: "프로젝트 새로 만들기", "광고센터", "비즈센터", "공지사항", "기획전·이벤트" | `apps/global/src/pages/maker/menu/_ui/Menu/Menu.tsx` |
| 메이커 프로필 폼 (기본/글로벌 메이커명, 프로필 이미지 · `maker_profile_page`) | `apps/global/src/pages/maker/profile/[corpNo]/_ui/MakerNameSection/` 외 |

## 메이커 배지 / 슈퍼메이커 (maker-club, makerInfo)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 메이커 프로필 배지 섹션 — `funding_detail_page.maker_profile_section`: "슈퍼메이커", "어워즈 TOP 100", "어워즈" | `packages/features/src/maker-club/ui/MakerBadge/MakerBadgeSection.tsx` (+ `MakerBadge.tsx`) |
| 슈퍼메이커 배너 — `funding_detail_story_page.super_maker_banner`: "{{n}} 와디즈 슈퍼메이커", "높은 만족도와 성과를 얻은 우수 메이커의 프로젝트예요." | `packages/features/src/maker-club/ui/SuperMakerBanner/SuperMakerBanner.tsx` |
| 메이커 정보 컴팩트 섹션 / 조회 훅 | `packages/features/src/maker-club/ui/MakerInfoCompactSection/`, `packages/features/src/makerInfo/lib/useMakerInfo.ts` |

## 프로젝트 만들기 (Create-Project)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 프로젝트 만들기 페이지 (헤더 "프로젝트 만들기", 탭 "와디즈 소개/기획전/제공 서비스" · `create_project_page`) | `apps/global/src/pages/create-project/CreateProjectPage.tsx` (+ `CreateProjectFramerPage.tsx`) |
| 프로젝트 시작 진입 버튼 — `content`: "프로젝트 시작하기", "✨ 첫 시작 수수료 50% 할인" | `apps/global/src/pages/create-project/_ui/StartProjectButton/StartProjectButton.tsx` |
| CTA(수수료 할인) 섹션 — `cta`: "지금 새로운 도전을 시작해보세요!", "기본 이용 수수료 30% 할인", "이미 {{n}}명의 메이커가 …" | `apps/global/src/pages/create-project/_ui/CTASection/CTASection.tsx` |
| 키비주얼 섹션 (`key_visual`) | `apps/global/src/pages/create-project/_ui/KeyVisualSection/KeyVisualSection.tsx` |
| 스토리 생성 AI 배너 — `story_ai_banner_section`: "스토리 생성 AI", "스토리 생성 AI로 초안 만들기" | `apps/global/src/pages/create-project/_ui/StoryGenerationSection/StoryGenerationSection.tsx` |
| 제공 서비스/와디즈 소개 리스트 (`service_list_section`, `about_wadiz_list_section`) | `apps/global/src/pages/create-project/_ui/{ServiceListSection,AboutWadizListSection}/` |
| 도움 배너(AI 상담/메일 제안/영상 가이드) — `help_banner_section`: "이런 것도 펀딩할 수 있는지 궁금하신가요?", "AI 상담받기" | `apps/global/src/pages/create-project/_ui/HelpBannerSection/HelpBannerSection.tsx` |

## 오픈예정 · 사전예약 · 알림신청 (pre-reservation, launching-soon-notification)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 오픈 알림 신청 버튼 — `notification_button_component._default`: "오픈 알림 신청", "알림 신청 완료", 토스트 "알림 신청을 완료했어요…" | `packages/features/src/launching-soon-notification/ui/LaunchingSoonNotificationButton/LaunchingSoonNotificationButton.tsx` (+ IconButton, CounterButton) |
| 알림 신청/취소 처리 훅 — `notification_cancel_modal`: "정말 취소하시겠어요?", `notification_paused_project_modal`: "잠시 진행이 중단되었어요", `..._request_duplicated_modal`: "이미 알림 신청한 프로젝트예요" | `packages/features/src/launching-soon-notification/lib/useNotificationRequest.tsx` |
| 사전예약 개인정보 제공 동의 모달 — **하드코딩** "알림 신청", "메이커가 직접 연락 드릴게요", "개인정보 제공 동의", "보유 및 이용 기간: 제공 후 6개월" | `packages/features/src/pre-reservation/ui/ConsentToProvisionOfPrivacyModal/ConsentToProvisionOfPrivacyModal.tsx` |

## 이슈 히스토리 (메이커/프로젝트 만들기 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE2-423 | 에픽 | [FE] '매출 UP' 페이지 개편 P1. LLM 및 전략에 따른 광고 상품 추천 |
| FE2-648 | 에픽 | [FE] '매출 UP' 페이지 개편 P2. 유사프로젝트 조회 기능 추가 |
| FE2-649 | 작업 | [메이커홈] 매출UP P2 - 광고 상품 목록 복구 및 부스터 쿠폰 디자인 변경 |
| FE2-668 | 하위작업 | [메이커홈] 매출UP P2 - '예산 계산하기' 링크 이동 버튼 위치 변경 |
| FE2-684 | 버그 | [메이커홈] 매출UP - 부스터 쿠폰, 타겟 광고 만들기 링크 변경 |
| FE2-567 | 작업 | [메이커 홈] WAi 호출 형태 변경 |
| FE2-532 | 에픽 | [FE] 스토리 생성 AI 진입구 개선 및 법무 리스크 대응 |
| FE2-320 | 에픽 | [FE] P2. 메이커 홈 - 대시보드 성공 공식 반영 |
| FE2-276 | 에픽 | 메이커 홈 - 후속 - WAi 사용성 개선 |
| FE2-650 | 작업 | 메이커 홈 사용성 검증 및 개선 방향 도출 리서치 - 온라인 서베이 |
| FE2-670 | 작업 | [메이커 홈] e2e 테스트 운영 |
| FE2-441 | 작업 | 클라우드 이전 - WAi - io 도메인 대응 |

---

# 소셜 / 친구추천 (Social / Refer-a-Friend)

> 친구 초대 이벤트(`refer-a-friend`), 소셜 친구 관리(`social/friends`), 지지서명(`social/support-share` + `packages/features/src/support-share`), 초대 코드, OneLink 공유 유틸. 소셜 공유 공통 문구는 i18n `social_share_section_component`, 소셜 모달은 대부분 **하드코딩**.

## 친구 초대 / 친구 추천 (Refer-a-Friend)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 친구 초대하기 메인 — `refer_a_friend_page.content.title`="친구 초대하면 나도 친구도 {n}원 포인트" / EN "Earn {n}P for Every Referral", header "친구 초대하기" | `apps/global/src/pages/refer-a-friend/ReferAFriendPage.tsx` |
| 초대 링크 공유 섹션 — `share_section`: "지금 친구 초대하기", "복사하기", "문자", 토스트 "초대 링크를 복사했어요!" | `apps/global/src/pages/refer-a-friend/_ui/ShareButtonSection/ShareButtonSection.tsx` |
| 이벤트 유의사항 — `guideline_article.title`="꼭 읽어 주세요!" | `apps/global/src/pages/refer-a-friend/_ui/NoticeSection/NoticeSection.tsx` |
| 초대받은 친구 랜딩 — `refer_a_friend_invitation_page.content.title`="{name} 님이 와디즈에 초대하셨어요", "지금 포인트 받기" | `apps/global/src/pages/refer-a-friend/invitation/ReferAFriendInvitationPage.tsx` |
| 초대 랜딩 액션 — "초대 코드 복사하기", "와디즈 둘러보기" / 와디즈 소개 "펀딩하기 🎁" | `apps/global/src/pages/refer-a-friend/invitation/_ui/{PageActions,AboutWadizSection}/` |

## 초대 코드 (Invitation Code)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 초대 코드 입력 섹션 — `invitation_code_section_component.header.title`="친구 초대 코드 입력", placeholder "초대 코드 입력", "참여하기", 성공 "포인트 지급을 완료했어요." | `packages/features/src/invitation-code/ui/InvitationCode.tsx` |
| 이벤트/광고 배너 (ADS 응답 동적 title, "AD" 뱃지) | `packages/features/src/invitation-code/ui/event-banner/EventBanner.tsx` |

## 소셜 친구 — 팔로잉/팔로워/차단

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 팔로잉 통합 화면 — `social_friends_page.header.title`="팔로잉" | `apps/global/src/pages/social/friends/_ui/MyFriends.tsx` |
| 팔로잉 메이커 목록 — `social_friends_following_makers_page`: "팔로잉 메이커", "팔로우한 메이커가 없어요" | `apps/global/src/pages/social/friends/following/makers/_ui/FollowingMaker.tsx` |
| 팔로잉 서포터/팔로워 목록 (`social_friends_following_supporters_page`, `social_friends_followers_page`) | `apps/global/src/pages/social/friends/{following/supporters,followers}/_ui/` |
| 차단 서포터 관리 — `social_friends_blocked_page`: "차단 서포터", "차단"/"차단 해제", 토스트 "차단했어요." | `apps/global/src/pages/social/friends/blocked/_ui/BlockedSupporterCard.tsx` |

## 소셜 모달 — 친구 찾기 (하드코딩)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 연락처 친구 찾기 모달 — **하드코딩** "연락처로 친구 찾기", "'연락처로 친구 찾기' 선택시 연락처가 저장되고 친구 추천에 사용됩니다." | `packages/features/src/social-modal/ui/SocialModal.jsx` |
| 전체화면 친구 찾기 모달 — **하드코딩** "와디즈를 이용하는 친구를 찾아보세요!" | `packages/features/src/social-modal/ui/SocialModalFull.jsx` |
| 지지서명 유입용 친구 찾기 모달 — **하드코딩** "내 지지서명으로 친구가 참여하면 결제 금액의 1%를 포인트로 받아요." | `packages/features/src/social-modal/ui/SignatureSocialModal.jsx` |

## 지지서명 (Support Share)

관련 이슈: `FE1-291`(레거시 정리·api 버전 교체), `FE1-311`(포인트 조회 api 제한), `FE1-452`(비로그인 returnURL 수정), `FE1-519`(공유 링크 UTM 프로젝트 ID)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 지지서명 포인트 가이드 — `social_support_share_guide_page`: "포인트 받는 방법", "지지서명 공유하고 포인트 받으세요", "지지서명하러 가기" | `apps/global/src/pages/social/support-share/guide/_ui/SupportShareGuide.tsx` |
| 나의 지지서명 활동 (포인트 요약/카드) — `social_support_share_activity_page`: "나의 지지서명", "총 {n}P 누적", "내 공유로 {n}명이 구매했어요", "지급 완료/예정" | `apps/global/src/pages/social/support-share/activity/_ui/{MyPointSummarySection,PointCard}.tsx` |
| 지지서명 상세 — `social_support_share_detail_page`: "지지서명 상세", "프로젝트 참여하기"/"URL 공유하기", "이 링크로 친구가 결제하면 결제금액의 {n}%가 적립돼요." | `apps/global/src/pages/social/support-share/[supportShareNo]/_ui/SupportShareDetail.tsx` (+ `MySupportShareCount.tsx`) |
| 펀딩 상세 지지서명 배너 — `funding_detail_page.support_and_share_section`: "{n}명이 지지서명했어요", "나의 지지서명 공유하기"/"지지서명 하기" | `packages/features/src/support-share/ui/SupportShareBanner.tsx` (+ `SupportShareIconButton.tsx`) |
| 지지서명 공유 모달 (SNS/링크 복사) — `support_share_share_modal`: "이 링크로 결제하면 {n}% 적립", "링크 복사가 완료되었어요!" | `packages/features/src/support-share/ui/SupportShare/ui/SupportShareModal.tsx` (+ `lib/useSupportShareSnsList.ts`) |
| 결제완료 지지서명 유도 섹션 — `funding_payment_completed_page.support_and_share_section`: "나만 알고 있기 아까운 프로젝트라면?", "포인트를 받아보세요" | `packages/features/src/support-share/ui/SupportShare/ui/OrderCompleteSupportShareSection.tsx` |
| 지지서명 작성/수정 모달 — `support_share_write_modal`: "친구에게 소개하고 1% 포인트 받기", "응원의 글을 남겨주세요.", "작성 완료" | `packages/features/src/support-share/ui/SupportShareRegister.tsx` (+ `Edit/SupportShareEditForm.tsx`) |
| 지지서명 포인트 적립 배너 — **하드코딩** "지지서명 공유로 {n}P 적립중", "지지서명으로 최대 50,000P 받는 방법" | `packages/features/src/support-share/ui/SupportSharePointBanner/SupportSharePointBanner.tsx` |

## 공유 유틸 (OneLink)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| AppsFlyer OneLink 공유 URL 생성 / 조회 훅 / 앱 미설치 리다이렉트 (UI 문구 없음) | `packages/features/src/onelink/{onelink.ts,useOnelink.ts,useAppInstallRedirect.ts}` |

## 이슈 히스토리 (소셜/친구추천 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-291 | 작업 | [Web] 지지서명 관련 레거시 코드 정리 및 api 버전 교체 |
| FE1-311 | 작업 | [Web] 나의 지지서명 상세가 아닌 경우 지지서명 포인트 조회 api 호출 제한 |
| FE1-452 | 버그 | [Web] 지지서명 비로그인시 로그인 시도할때 returnURL이 잘못 들어가는 부분 수정 |
| FE1-519 | 작업 | [Web] 지지서명 공유 링크 UTM에 프로젝트 ID(utm_content) 추가 |
| FE1-716 | 버그 | [Web] platform > share API 이용해 생성한 원링크가 동작하지 않는 문제 |
| FE2-178 | 작업 | [FE2] WAi for Supporter P2 - 메이커센터 |

---

# 검색 / 스토어 / 소싱클럽 (Search / Store / Sourcing-Club)

> 검색만 서포터 i18n(`search_page`, `search_input_component` 등)을 사용하고, **스토어·소싱클럽은 i18n 미사용 — 한국어(스토어)/영어(소싱클럽) 하드코딩**. `apps/global/src/pages/store/**` 는 대부분 `@wadiz/features/store/*` 래퍼라 실제 기능은 `packages/features/src/store/**` 에 있습니다. `apps/global/src/pages/supporters/` 는 소스 파일이 없습니다(`.DS_Store`만 존재).

## 검색 (Search)

관련 이슈: `FE1-553`(Search page 통합), `FE1-714`(검색 홈 추천 리스트 · 에픽), `FE1-866`(최근 검색어 서버 수집 API), `FE1-726`(검색창 글자수 노출 확대), `FE1-1032`(최근 검색어 서버 전송 누락)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 통합 검색 페이지(진입·데스크톱/모바일 분기) | `apps/global/src/pages/search/SearchPage.tsx` |
| 헤더 검색 입력창 — `search_input_component._default.placeholder`="새로운 일상이 필요하신가요?" | `packages/features/src/search/ui/HeaderSearchInput/HeaderSearchInput.tsx` |
| 검색 자동완성·추천 패널 — `search_input_popover_component`: "닫기", "카테고리", "최근 검색어"/"전체 삭제"/"최근 검색어가 없어요." | `packages/features/src/search/ui/SearchSuggestionPanel/SearchSuggestionPanel.tsx` |
| 실시간 인기 검색어 롤링 — `search_popular_keyword_roller_popover_component`: "실시간 인기 검색어", "최근 35분마다 갱신하고 있어요." | `packages/features/src/search/ui/SearchPopularKeywordRolling/SearchPopularKeywordRolling.tsx` |
| 최근 검색어 목록 — `search_page.recent_keyword_section`: "최근 검색어", "전체 삭제", 실패 토스트 "검색어 삭제에 실패했어요…" (로직 `lib/useRecentSearchKeywords.ts`) | `packages/features/src/search/ui/RecentKeywordList/RecentKeywordList.tsx` |
| 인기 검색어 목록 — `search_page.popular_keyword_section.title`="인기 검색어" | `packages/features/src/search/ui/PopularKeywordList/PopularKeywordList.tsx` |
| 연관 검색어 — **하드코딩** "연관검색어"(모바일 "연관") | `packages/features/src/search/ui/RelatedKeywords/RelatedKeywords.tsx` |
| 방금 본 상품 쿠폰 카드 — `search_page.available_coupon_section`: "방금 본 상품에 쿠폰이 있어요", "쿠폰 받기" | `packages/features/src/search/ui/PersonalRecommendationCard/AvailableCouponsCard.tsx` |
| 검색 결과 없음 — `search_page.search_result_empty`: "검색 결과가 없어요", "이 키워드 알림 받기" | `apps/global/src/pages/search/_ui/NoResultsSection/NoResultsSection.tsx` |
| 프로젝트 타입 탭 — `search_page.search_result_section`: "전체", "펀딩+", "오픈예정", "알림 등록", 성공 "{{arg_0}} 알림을 등록했어요!" | `apps/global/src/pages/search/_ui/ProjectTypeTabBar/ProjectTypeTabBar.tsx` |
| 카테고리 선택 모달 — **하드코딩** "카테고리" | `apps/global/src/pages/search/_ui/CategorySelectModal/CategorySelectModal.tsx` |
| 방금 본 프로젝트와 비슷/재오픈 추천 — `search_page.related_project_section.title`="방금 본 프로젝트와 비슷해요", `reopened_project_section.title`="참여한 프로젝트가 재오픈했어요" | `apps/global/src/pages/search/_ui/SearchResultCardSection/RelatedProjectsCardSection/RelatedProjectsCardSection.tsx` |

## 스토어 (Store) — 홈/상세/결제/선물

관련 이슈: `FE1-688`(스토어 코드 마이그레이션 static→global · 에픽), `FE1-1108`(스토어 상세 탭 선택 시 현재 위치 유지)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 스토어 홈(메인) — **하드코딩** 정렬 "추천순/인기순/만족도 높은순/최신순", 키비주얼·카테고리·큐레이션 | `packages/features/src/store/main/Main.tsx` |
| 스토어 오픈 안내 배너 — **하드코딩** "와디즈 스토어 OPEN", "서포터 인정 받은 펀딩 제품 지금 바로 구매해보세요" | `packages/features/src/store/main/ui/components/WadizStoreOpen.tsx` |
| 스토어 상품/랭킹 카드 (데이터 기반 배지·수치) | `packages/features/src/store/shared/ui/StoreCard/StoreCard.tsx` |
| 찜하기(위시) 버튼 — **하드코딩** "찜하기", 토스트 "위시리스트에 추가되었어요." | `packages/features/src/store/shared/ui/StoreWishButton/StoreWishButton.tsx` |
| 통합 기획전(탑랭크 컬렉션) — **하드코딩** "놓칠 수 없는 이벤트", GA "통합기획전_클릭" | `packages/features/src/store/shared/ui/TopRankCollection/TopRankCollection.tsx` |
| 배송 배지 — **하드코딩** "무료배송", "와배송" | `packages/features/src/store/shared/ui/DeliveryBadge/DeliveryBadge.tsx` |
| 스토어 상세 페이지(진입·데이터 세팅) | `packages/features/src/store/detail/Detail.tsx` |
| 상세 탭 — **하드코딩** "스토리", "만족도", "문의・정책" | `packages/features/src/store/detail/ui/components/DetailTab/DetailTab.tsx` |
| 스토리 서브페이지 — **하드코딩** "구매 전 반드시 확인하세요!" | `packages/features/src/store/detail/ui/subpages/story/components/DetailStory/DetailStory.tsx` |
| 교환/환불 정책 서브페이지 — **하드코딩** "서포터 단순 변심에 의한 교환/반품은 상품 수령 후 7일 이내…" | `packages/features/src/store/detail/ui/subpages/refund/components/DetailReturnPolicy/DetailReturnPolicy.tsx` |
| 구매/선물 CTA 버튼 — **하드코딩** "구매하기", "선물하기", "재입고 신청할 상품을 선택해 주세요." | `packages/features/src/store/detail/ui/components/StoreProductPurchaseButton/StoreProductPurchaseButton.tsx` |
| 스토어 결제 페이지(진입·폼) | `packages/features/src/store/payment/Payment.tsx` |
| 배송지 정보(최근/신규 탭) — **하드코딩** "최근", "신규 배송지 입력" | `packages/features/src/store/payment/ui/components/StorePaymentShippingInfo/StorePaymentShippingInfo.tsx` |
| 결제 금액 앱 — **하드코딩** "기본 배송비", "추가 배송비", "쿠폰 할인 금액" | `packages/features/src/store/payment/ui/StorePriceApp/StorePriceApp.tsx` |
| 결제 CTA — **하드코딩** "N원 결제하기", "결제 진행을 위해 결제 필수 동의에 체크해 주세요" | `packages/features/src/store/payment/ui/components/StorePaymentCTA/StorePaymentCTA.tsx` |
| 선물하기 진입/폼 (받는 사람 정보 "받으실 분/연락처/이메일/주소" **하드코딩**) | `packages/features/src/store/gift/Gift.tsx` (+ `ui/components/RecipientInfo/RecipientInfo.tsx`) |
| 선물 수락 CTA — **하드코딩** "선물 받기", "땡큐 포인트 보내고 선물 받기" | `packages/features/src/store/gift/ui/components/GiftCTA.tsx` |
| 결제 성공/실패 페이지 — **하드코딩** "결제가 실패되었습니다. 다시 시도해 주세요.", "유효시간이 초과되어 세션이 만료되었습니다." | `packages/features/src/store/paymentComplete/ui/pages/{PaymentSuccessPage,PaymentFailurePage}.tsx` |

## 소싱클럽 (Sourcing-Club) — 전면 영어 하드코딩

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 소싱클럽 랜딩 페이지(가입 처리·이메일 검증) | `apps/global/src/pages/sourcing-club/SourcingClubPage.tsx` |
| 키비주얼 — **하드코딩** "Wadiz — Korea's Launchpad / Representing Asia's Powerful Consumer Market" | `apps/global/src/pages/sourcing-club/_ui/KeyVisual/KeyVisual.tsx` |
| 일일 런칭 통계 — **하드코딩** "New and Unique Products launch on Wadiz", "Total Seller / Total Products / Total GMV / Monthly Visitors" | `apps/global/src/pages/sourcing-club/_ui/DailyLaunches/DailyLaunches.tsx` |
| 혜택(Benefits) — **하드코딩** "K-Product Weekly Catalog", "K-Product Samples", "B2B Price Negotiation" | `apps/global/src/pages/sourcing-club/_ui/JoinClub/Benefits.tsx` |
| 진행 절차(How It Works) — **하드코딩** "STEP 01~04" (Join / Receive Weekly Catalog / Request Samples / Get the Products) | `apps/global/src/pages/sourcing-club/_ui/HowItWorks/HowItWorks.tsx` |
| 가입 신청 폼 — **하드코딩** "First name/Last name/Business Email/Company Name/Job Title", "Continue" | `apps/global/src/pages/sourcing-club/_ui/ApplicationForm/ApplicationForm.tsx` |
| 플로팅 가입 버튼 — **하드코딩** "Join Now", "Normally $100/month, now completely FREE if you join Beta" | `apps/global/src/pages/sourcing-club/_ui/Floating/Floating.tsx` |

## 기획전 · 컬렉션 (Collection / Exhibition Banner)

관련 이슈: `FE1-1175`(오픈예정 컬렉션 알림신청 카운트 0 표시), `FE1-55`(기획전 배너 검색홈/알림센터 노출)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 컬렉션(기획전) 페이지 — **하드코딩** "더보기", 키비주얼·설명·공유 | `packages/features/src/collection/ui/CollectionPage.tsx` |
| 컬렉션 상품 카드 리스트 — **하드코딩** 빈 상태 "등록된 프로젝트가 없습니다.", GA "기획전_상품카드_스토어/펀딩/오픈예정" | `packages/features/src/collection/ui/CollectionCardList.tsx` |
| 기획전 배너 (배너 문구는 API `banner.title`·`banner.benefitDesc` 기반) | `packages/features/src/exhibition-banner/ui/ExhibitionBanner.tsx` (+ `api/useExhibitionBannersQuery.ts`) |

## 이슈 히스토리 (검색/스토어/소싱클럽 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-688 | 에픽 | [Web][스토어] 스토어 코드 마이그레이션 (static -> global) for SPA |
| FE1-553 | 작업 | [Web][펀딩상세 통합] Search page 통합 |
| FE1-714 | 에픽 | [FE1][추천 알고리즘 반영] 검색 홈 : 추천 리스트 제공 |
| FE1-866 | 작업 | [WEB] 최근 검색어 서버 수집 API 연동 |
| FE1-726 | 작업 | [WEB] 검색창 글자수 노출 영역 확대 |
| FE1-1032 | 버그 | [검색] 최근 검색어 리스트 갱신 시 서버 전송 누락 |
| FE1-1108 | 작업 | [Web] 스토어 상세 탭 선택시 현재 위치 유지하도록 수정 |
| FE1-1175 | 버그 | [Web] 오픈예정 컬렉션 페이지의 알림신청 카운트가 0으로 표시 |
| FE1-55 | 작업 | [Web] 기획전 배너 - 검색 홈, 알림 센터 노출 추가 |

---

# 정책 / WAi / 알림 / 이벤트 / 쿠폰 / 기타

> **정책·약관**: 본문·좌측 네비게이션 전부 약관 API HTML(`useTermsQuery` → `@wadiz/api/terms`)이라 코드에 고정 문구 없음. 각 페이지 식별자는 `TERMS_NAME` 상수. **WAi**: 실제 챗 구현은 `apps/global/src/features/wai`(패키지 아님), i18n `wai_page`. 

## 정책·약관 (policies)

관련 이슈: `FE2-402`(글로벌 선정산 도입 — 약관)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 서비스(회원가입) 이용약관 — `TERMS_NAME='signup'` (본문 API 동적) | `apps/global/src/pages/policies/terms/signup/PoliciesTermsSignupPage.tsx` |
| 메이커 서비스 이용약관 — `TERMS_NAME='maker_service'`→`funding_maker_service` | `apps/global/src/pages/policies/terms/maker/PoliciesTermsMakerPage.tsx` |
| 서포터(리워드) 이용약관 — `TERMS_NAME='service_reward'` | `apps/global/src/pages/policies/terms/supporter/PoliciesTermsSupporterPage.tsx` |
| 조기정산(early-payout) 약관 — 글로벌 약관 파일 | `apps/global/src/pages/policies/terms/early-payout/PoliciesTermsEarlyPayoutPage.tsx` |
| 개인정보 처리방침 — `TERMS_NAME='privacy'` (+ 위탁/제3자 제공/카카오 동의 하위 페이지) | `apps/global/src/pages/policies/privacy/PoliciesPrivacyPage.tsx` (+ `entrustments/`, `third-parties/`, `privacy-agreement/`) |
| 재산·펀딩플랜·배송·환불·심사·신고·커뮤니티 정책 (각 `TERMS_NAME` 상수) | `apps/global/src/pages/policies/{property,plan,shipping,refund,review,report,community}/` |
| 약관 좌측 네비게이션 / 본문 블록 — API HTML 파싱 렌더 (동적) | `apps/global/src/pages/policies/_ui/{TranslatedNavbar,TranslatedBlock}/` |
| 정책 페이지 메타 타이틀 — **하드코딩** "{page} Policy" / "{page} \| Privacy Policy" | `apps/global/src/pages/policies/PoliciesMeta.tsx` |

## WAi (`apps/global/src/features/wai`)

관련 이슈: `FE1-131`(문의 채널 일원화 · 에픽), `FE2-127`(WAi for Supporter 로그인 지원), `FE2-134`·`FE2-277`(스토리 생성 AI PoC)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| WAi 페이지 진입(앱=모달 런처 `window.WAI('open')` / 그 외=인앱 챗봇 분기) | `apps/global/src/pages/wai/WAiPage.tsx` (+ `_ui/WAiModal.tsx`) |
| WAi 챗봇 본체 — `wai_page.header.title`="AI Agent WAi" | `apps/global/src/features/wai/ui/WAiAIAgent.tsx` |
| WAi 채팅 입력 — `prompt_input.placeholder`="무엇이든 물어보세요" / EN "Ask me anything" | `apps/global/src/features/wai/ui/ChatPanel/ChatPanel.tsx` |
| WAi 대화 말풍선/응답 액션 — `chat_action_button_group.copy_button_label`="답변 복사"; 오류 `chat_error_section.title`="앗 잠깐 문제가 발생했어요.", 타임아웃 "10분간 입력이 없어 연결이 끊어졌어요." | `apps/global/src/features/wai/ui/ChatConversation/ChatConversation.tsx` |
| WAi 인사말 — `conversation_panel.greeting_message_1_markdown`="안녕하세요, {{arg_0}} 님! 새로운 아이디어가 있나요?" | `apps/global/src/features/wai/lib/useWAiGreetingMessage.ts` |
| WAi 스타터 프롬프트 — `starter_prompt_group.starter_prompt_1_text`="펀딩에 필요한 필수 서류를 알려 줘" | `apps/global/src/features/wai/ui/ChatContent/ChatContent.tsx` |
| WAi 스토리 생성 미리보기 패널 — `story_preview_panel.title`="스토리 생성 AI 미리보기" | `apps/global/src/features/wai/ui/StoryPreviewPanel/StoryPreviewPanel.tsx` |
| WAi 로그인 유도 배너 — `supporter_login_banner_full.title`="로그인하면 더 많은 도움을 받을 수 있어요" | `apps/global/src/features/wai/ui/LoginCTA/LoginBanner.tsx` |
| WAi 온보딩 워크스루 모달 — `walkthrough_modal.title`="이제 와디즈 상세페이지도 5분이면 초안 완성" | `apps/global/src/features/wai/ui/WalkthroughModal/WalkthroughModal.tsx` |

## 알림 (notifications)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 알림 목록(무한스크롤·읽음처리) — `notification_page.header.title`="알림" / EN "Notifications", 빈 상태 `empty.description`="알림 내역이 없어요." | `apps/global/src/pages/notifications/NotificationsPage.tsx` |
| 알림 리스트 아이템 — 읽음 구분선 `divider.text`="여기까지 읽었어요" / EN "Marked as read" | `apps/global/src/pages/notifications/_ui/NotificationListItem.tsx` |

## 이벤트 · 쿠폰 (events / coupon / signup-coupon / marketing)

관련 이슈: `FE1-644`(달러 쿠폰 — 서포터 다운로드 지면)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 이벤트(기획전) 목록 — `events_page.header.title`="이벤트" / EN "Event" | `apps/global/src/pages/events/EventsPage.tsx` |
| 이벤트 상세(통합 기획전) — `@wadiz/widgets/events/event-detail` IntegratedExhibition, 서포터클럽 가입 모달 연동 | `apps/global/src/pages/events/[eventNo]/EventsDetailPage.tsx` |
| 쿠폰 다운로드 모달(공통) — `coupon_download_modal.header.title`="적용 가능한 쿠폰" / EN "Available Coupons", `footer.confirm_button_label`="쿠폰 모두 받기" | `packages/features/src/coupon/ui/BaseCouponModal/BaseCouponModal.tsx` (+ `ProjectCouponModal/`) |
| 오픈예정 쿠폰+알림 신청 모달 — `coupon_download_on_notification_and_claiming_modal`: "쿠폰 받으시면 알림 신청도 해 드릴게요.", "알림 신청하고 쿠폰 모두 받기" | `packages/features/src/coupon/ui/LaunchingSoonCouponModal/LaunchingSoonCouponModal.tsx` |
| 쿠폰 카드 — `coupon_download_section_component.content.discount_amount_text`="최대 {{arg_0}}원 할인", aria "쿠폰 다운로드" **하드코딩** | `packages/features/src/coupon/ui/UsableCoupon/UsableCoupon.tsx` |
| 최대혜택 쿠폰 배너(펀딩 상세) — `funding_detail_page.coupon_download_banner.discount_amount_title`="최대 {{arg_0}}원 쿠폰", `get_button_label`="받기" / EN "Get" | `packages/features/src/coupon/ui/MaxBenefitCouponBanner/MaxBenefitCouponBanner.tsx` |
| 쿠폰 다운로드 로직(단건/전체/이벤트, 서포터클럽 조건) | `packages/features/src/coupon/lib/useDownloadCoupon.ts` |
| 마감 임박 알림 받기 모달(마케팅 수신동의+휴대폰 인증) — **하드코딩** "마감 임박 알림 받기", "네, 받을게요"/"아니요, 괜찮아요" | `packages/features/src/marketing/ui/MarketingNotificationModal/MarketingNotificationModal.tsx` |

## 고객센터·문의 (support/requests)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 문의 내역 목록 — `support_requests_page.header.title`="문의 내역" / EN "Requests", "고객센터 문의 남기기" | `apps/global/src/pages/support/requests/SupportRequestsPage.tsx` |
| 문의 등록(동적 폼) — `support_requests_new_page.header.title`="문의 등록" / EN "Submit a Request" | `apps/global/src/pages/support/requests/new/SupportRequestsNewPage.tsx` |
| 문의 상세 — `support_requests_detail_page.header.title`="나의 문의 상세" / EN "Ticket Details" | `apps/global/src/pages/support/requests/[requestId]/SupportRequestsDetailPage.tsx` |
| 티켓 상태 뱃지 — `api_code.app_SupportTicketStatus`(REQUESTED/RESPONDED/RESOLVED) | `apps/global/src/pages/support/requests/_ui/TicketStatusBadge/TicketStatusBadge.tsx` |

## 기타 (about / app / settlement-date-calculator / activities)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 앱 정보(글로벌/국내) — `app_about_page.header.title_v2`="앱 정보" / EN "About", "사업자 정보 확인", "오픈소스 라이선스", "Version {{arg_0}}" | `apps/global/src/pages/app/_ui/AboutContent.tsx` (+ `KoreaAboutContent.tsx`) |
| 정산일 계산기 — `settlement_date_calculator_page.header.title`="최종정산 예정일 계산기" / EN "Final Payout Date Calculator" | `apps/global/src/pages/settlement-date-calculator/_ui/SettlementDateCalculatorContainer.tsx` |
| 슬로건 "혁신의 시작"(Framer iframe 임베드, 외부) | `apps/global/src/pages/about/slogan/innovation-begins/InnovationBeginsPage.tsx` |
| 위시/알림신청 활동 토스트(이벤트버스 구독) — `wish_button_component._default.wish_toast_marked_message`, `notification_button_component._default.notification_toast_requested_message` | `packages/features/src/activities/ui/ActivityUIView.tsx` (+ `lib/useActivity.tsx`) |

## 이슈 히스토리 (정책/WAi/알림/이벤트/기타 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-131 | 에픽 | [WAi/상담원 Agent P2] 문의 채널 일원화 |
| FE2-127 | 작업 | [FE2] WAi for Supporter P2 - 로그인 지원 |
| FE1-27 | 작업 | WAi for Supporter P1 - 후속 - '문의자 유형(고객)' 필드 숨김 처리 |
| FE2-277 | 에픽 | [Generative AI] 스토리 생성 AI PoC |
| FE2-134 | 작업 | [Generative AI] 스토리 생성 AI PoC - WAi 페이지 화면 분할 및 스토리 Viewer |
| FE2-402 | 작업 | 글로벌 선정산 도입 - 약관 |
| FE1-115 | 작업 | [Web] cdev activity api 적용 |
| FE1-644 | 스토리 | [FE] 달러 쿠폰 - 서포터 쿠폰 다운로드 지면 |
| FE1-591 | 작업 | [Web][펀딩상세 통합] 데이터 수집 정리 |

---

# packages 공통 (ui · widgets · features)

> 여러 앱이 공유하는 공통 컴포넌트. i18n 값 중 `country_change_modal` 등 일부는 영어 키가 ko.json에도 그대로 들어 있습니다. `phone-verification` 디렉터리는 없고, 휴대폰 번호 유효성 확인은 `packages/features/src/sms-auth`(본인인증과 무관)입니다.

## 공통 UI (`packages/ui/src`)

관련 이슈: `FE1-847`(앱 다운로드 로그인 적극 유도 · 에픽), `FE1-680`(BNB 통합), `FE1-988`(SHORTCUT/에디션 탭), `FE1-613`(color token 정리)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 글로벌 헤더/GNB (로고·검색·뒤로가기·마이와디즈) | `packages/ui/src/Header/Header.tsx` |
| 헤더 로그인/회원가입 버튼 — `header.auth_button_group.login_signup_button_label`="로그인/회원가입" | `packages/ui/src/Header/ui/AuthButton.tsx` |
| 헤더 프로젝트 만들기 버튼 — `header._default.create_project_button_label`="프로젝트 만들기" | `packages/ui/src/Header/ui/CreateProjectButton.tsx` |
| 하단 네비게이션 바 — `bottom_navigation_bar._default`: "홈"/"위시"/"마이와디즈" | `packages/ui/src/BottomNavigationBar/BottomNavigationBar.constants.tsx` |
| 메이커 하단 네비게이션 바 — `maker_page.bottom_sheet_section`: 메이커홈/내 프로젝트/문의 버튼 | `packages/ui/src/BottomNavigationBar/MakerBottomNavigationBar.constants.tsx` |
| 공유하기 모달 — `social_share_section_component.header.title`="공유하기" | `packages/ui/src/Share/components/ShareModal.tsx` |
| 국가 변경 모달 — `country_change_modal.header.title_v2`="Set your preferences", `footer.confirm_button_label_v2`="Save Change" | `packages/ui/src/CountryChangeModal/CountryChangeModal.tsx` |
| 앱 다운로드 유도 모달 — `app_download_modal.header.title_1`="앱에서 첫 결제하고", `title_2`="최대 15,000원 혜택 받으세요" | `packages/ui/src/AppDownload/ui/AppDownloadModal.tsx` |
| 모바일 헤즈업(앱 유도) 배너 — `heads_up_banner_component._default.title`="첫 결제라면 누구나 1만 원 혜택", "앱에서 보기" | `packages/ui/src/AppDownload/ui/MobileHeadsUpBanner.tsx` |
| 성인 인증 콘텐츠 — `adult_verification_required_error_content_component._default.title`="19세 이상만 참여 가능한 프로젝트입니다", "성인 인증" | `packages/ui/src/AdultVerificationContent/AdultVerificationContent.tsx` (+ `AdultLoginNotice/`) |
| 펀딩 만들기(메이커 전환) 모달 + 롤링 헤드라인 — `make_funding_modal.content`: FAQ "사업자가 아니어도 메이커가 될 수 있나요?", "굿즈로 팬 모으기" | `packages/ui/src/MakeFunding/MakeFundingModal.tsx` (+ `RollingHeadLine.tsx`) |
| 모드 전환(서포터/메이커) 모달·버튼 — `mode_switching_modal.content.title`="원하는 사용 모드를 선택해 주세요", `common.term`: "서포터"/"메이커" | `packages/ui/src/ModeSwitch/ModeSwitchModal.tsx` (+ `ModeSwitchButton.tsx`) |
| 스토어 배송 배지 — **하드코딩** "무료배송", "와배송" | `packages/ui/src/StoreDeliveryBadges/StoreDeliveryBadges.tsx` |

## 공통 위젯 (`packages/widgets/src`)

관련 이슈: `FE1-988`(SHORTCUT/에디션 탭), `FE1-1041`(쿠폰 정보 API 연동)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 이벤트 앱 알림(오픈 예정) 모달 — `events_page.open_reservation_modal.app_install_button_label`="앱 설치하기" | `packages/widgets/src/app-install/EventNotifyAppModal.tsx` (+ QR 모달) |
| 앱 다운로드 QR 모달 — `global_app_download_qr_modal.header.title`="이 프로젝트는 곧 와디즈에서 오픈 예정이에요" | `packages/widgets/src/app-install/NotificationQrModal.tsx` |
| 쿠폰 다운로드(쿠폰존) / 내 쿠폰 페이지 — `my_wadiz_coupons_page` 키 그룹 | `packages/widgets/src/coupon/ui/coupon-zone/CouponDownloadPage.tsx` (+ `my-coupon/MyCouponPage.tsx`) |
| 쿠폰 카드/상세 — `my_wadiz_coupons_page.coupon_card` + `api_code.coupon_redeem` | `packages/widgets/src/coupon/ui/components/{CouponCard,CouponDetailContent}.tsx` |
| 이벤트 목록/카드 — `events_page.empty.title`="등록된 이벤트가 없어요", `event_list_item.end_badge_label`="종료" | `packages/widgets/src/events/event-list/ui/{EventList,EventCard}.tsx` |
| 통합 기획전(이벤트 상세 렌더러) — 콘텐츠 서버(Framer/기획전) 주입 | `packages/widgets/src/events/event-detail/ui/IntegratedExhibition.tsx` |
| 한국 푸터 — 사업자 정보 **하드코딩** "사업자등록번호…", 메뉴 "와디즈 정책·약관"/"와디즈 IR" | `packages/widgets/src/korea-footer/ui/KoreaFooter/KoreaFooter.tsx` (+ `FooterInfo/`, `FooterMenu/`) |
| 서포터클럽 소개/가입/구독 모달 (문구 props·서버 주입) | `packages/widgets/src/supporter-club/ui/` |

## 공통 기능 (`packages/features/src`)

관련 이슈: `FE1-767`(프로젝트 카드 유저 활동 데이터), `FE1-1226`(앱 로그인 모달 tracking-data), `FE1-847`(로그인 유도)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 프로젝트 카드 (공용 카드 본체: 썸네일·타이틀·메이커·달성률) | `packages/features/src/project-card/ui/ProjectCard/Card/Card.tsx` (+ `HomeProjectCard/`) |
| 프로젝트 카드 배지 — `project_card_component.badge`: "쿠폰"/"종료"/"마감 임박"/"Global" | `packages/features/src/project-card/lib/useBadgePropsList.ts` (+ `getProjectRemainingDayBadgeProps.ts`) |
| 최근 본 프로젝트 모달 | `packages/features/src/project-card/ui/ProjectModal/RecentlyViewedProjectModal/RecentlyViewedProjectModal.tsx` |
| 신고하기 모달 — `report_community_modal.header.title`="신고하기", "프로젝트 및 게시글에 부적절한 내용이 있다면…" | `packages/features/src/report-modal/ReportModal.tsx` |
| 리워드 만족도 모달 — `satisfaction_review_modal.header.submit_title`="만족도를 써 주세요", "작성한 내용을 등록하시겠어요?" | `packages/features/src/reward-satisfaction-modal/ui/SatisfactionModal.tsx` (+ `SatisfactionRating.jsx`) |
| 로그인 유도 팝업 — `global_login_guide_modal.footer.button_label`="지금 가입하고 {{쿠폰금액}} 받기" | `packages/features/src/login-guide-popup/ui/LoginGuideModal.tsx` |
| 자동 로그인 (UI 없음, 리다이렉트/토큰 처리) | `packages/features/src/auto-login/autoLogin.ts` |
| 성인 콘텐츠 배지 배너 — `funding_detail_page.project_info_section.adult_badge_label`="19세 이상 참여 가능 프로젝트" | `packages/features/src/adult-content-banner/ui/AdultContentBanner/AdultContentBanner.tsx` |
| 라이브 활동 배너(실시간 참여 롤링) — 콘텐츠 서버 주입 | `packages/features/src/live-activity-banner/ui/LiveActivityBanner/LiveActivityBanner.tsx` (+ `CardLiveActivityBanner/`) |
| 휴대폰(SMS) 인증 — `confirm_participation_modal.content.send_button_label`="인증하기", `footer.confirm_button_label`="확인" | `packages/features/src/sms-auth/ui/MobileAuthContainer/MobileAuthContainer.tsx` (+ `components/`) |
| SPA 글로벌 페이지 로더 / 상세페이지 SPA 네비게이션 훅 (문구 없음) | `packages/features/src/navigation/components/GlobalPageLoader.tsx` (+ `hooks/useDetailPageSPALoader.ts`) |

## 이슈 히스토리 (packages 공통 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-847 | 에픽 | 앱 다운로드 로그인 적극 유도 |
| FE1-680 | 작업 | [Web][펀딩상세 통합] BNB(BottomNavigationBar) 통합 |
| FE1-988 | 작업 | [WEB] SHORTCUT 변경 (에디션 탭) |
| FE1-1115 | 작업 | [WEB] N표시 서버 연동 (에디션 프로젝트 연계), 팝퍼 노출 |
| FE1-1188 | 작업 | [Web] 통합기획전 지면 AD1 카드 컴포넌트 수정 |
| FE1-1186 | 에픽 | [Web] 통합 기획전 AD1 카드의 진행중 펀딩에 리워드 노출 |
| FE1-1012 | 작업 | [기획전] 카드 메시지 수신·메타데이터 조회·표준 data-ec 오버레이 생성 |
| FE1-1204 | 버그 | [Web] FramerIframe 리랜더 이슈 수정 |
| FE1-767 | 작업 | [Web] [추천 알고리즘] 프로젝트 카드 내 유저 활동 데이터 노출 구현 |
| FE1-1041 | 작업 | [Web] BE 쿠폰 정보 API 연동 |
| FE1-1226 | 작업 | [Web] 앱 로그인 모달에 tracking-data 를 전달해 주기 |
| FE1-613 | 작업 | WEB - gradation -> gradient로 수정 / deprecated color token 삭제 |

---

# apps/global 내부 features (부가)

> 위 도메인들이 공유하는 `apps/global/src/features/**` 중, 도메인 표에서 다루지 않은 부가 기능과 에러/기타 페이지. `phone-verification`만 문구가 전부 **하드코딩**이고 나머지는 supporter i18n 사용.

## 배송지 입력

관련 이슈: `FE1-470`·`FE1-973`(결제/주문 배송지 연계)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 글로벌 배송지 입력 모달 — `address_setting_modal`: "배송지 입력", `footer.save_button_label`="저장 후 계속", `content.first_name_field_label`·`search_address_field_label` (닫기확인 `address_setting_close_modal`) | `apps/global/src/features/shipping-address/ui/ShippingAddressModal/ShippingAddressModal.tsx` |
| 주소 자동완성/장소 상세 (구글 places) — 문구 없음 | `apps/global/src/features/shipping-address/api/places.service.ts` |
| 국내 배송지 입력 모달 — `korea_shipping_address_modal`: "배송지 입력", `content.search_postcode_button_label`="주소 찾기", `name_field_label`, `phone_number_field_label` | `apps/global/src/features/shipping-address-korea/ui/KoreaShippingAddressModal/KoreaShippingAddressModal.tsx` |

## 새소식 · 스토리 · 배너

관련 이슈: `FE1-876`(스토리 상단 새소식을 커뮤니티에도 노출), `FE1-847`(앱 다운로드 유도)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 새소식 배너(펀딩상세) — `funding_detail_news_page.header.title`="새소식" | `apps/global/src/features/funding-story-banner/ui/NewsBanner/NewsBanner.tsx` |
| 기획전 배너 — 배너 문구는 API(`banner.title`·`banner.benefitDesc`) 기반 | `apps/global/src/features/funding-story-banner/ui/ExhibitionBanner/ExhibitionBanner.tsx` |
| 앱 다운로드 플로팅 배너 — `funding_detail_page.app_download_floating_banner.title`="와디즈 앱에서는 최대 {{arg_0}} 할인" | `apps/global/src/features/funding-story-banner/ui/AppDownloadPopper/AppDownloadPopper.tsx` |
| 새소식 태그 타입 라벨 — `api_code.funding_NewsTagType` + `funding_detail_news_page.type_select.type_filter_all_text` | `apps/global/src/features/news/config/constants.ts` |
| 스토리 HTML 최적화(유튜브/비메오 lazyload, alt 자동삽입) / 핀치줌·우클릭 방지 — 문구 없음 | `apps/global/src/features/story/lib/useStoryOptimize.jsx` (+ `usePinchZoom.ts`) |

## 메이커 문의 (1:1 메시지)

관련 이슈: `FE1-131`(문의 채널 일원화 · 에픽)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 메이커 문의 메인 (`my_wadiz_inquiries_page` + `my_wadiz_inquiries_detail_page`) | `apps/global/src/features/inquiries-maker/InquiriesMaker.tsx` |
| 문의 메시지 탭(전체/관심/안읽음) — `message_tab_bar.{all,favorites,unread_messages}_tab_label` | `apps/global/src/features/inquiries-maker/InquiriesMakerTab.tsx` |
| 문의 상단 탭바 — `tab_bar.my_inquiries_tab_label`="나의 문의", `supporter_inquiries_tab_label` | `apps/global/src/features/inquiries-maker/_ui/InquiriesTabBar/InquiriesTabBar.tsx` |
| 문의 헤더/빈 상태 — `header.title`="1:1 문의", `content.empty_title`="메시지가 없어요" | `apps/global/src/features/inquiries-maker/_ui/{InquiriesHeader,InquiriesEmpty}/` |
| 문의 에러 매핑 — `api_code.board_PersonalMessageException.ERR9999/9998/9997`, `inquiry_self_project_error_modal.title` | `apps/global/src/features/inquiries-maker/_lib/error.ts` |

## 프로젝트 신고

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 신고 진입 버튼/배너 — `funding_detail_story_page.project_report_banner.title`="프로젝트에 문제가 있나요?", 중복신고 `report_project_duplicated_modal` | `apps/global/src/features/project-report/ui/ProjectReportButton/ProjectReportButton.tsx` |
| 신고 모달(메인) — `project_report_modal.header.title`="신고하기", `footer.confirm_button_label`, 취소 `project_report_cancel_modal` | `apps/global/src/features/project-report/ui/ProjectReportModal/ProjectReportModal.tsx` |
| 신고 유형 목록/라벨 — `project_report_modal.report_type_content`: "지식재산권/허위사실/정책위반" 등 | `apps/global/src/features/project-report/ui/ProjectReportModal/ProblemListSection/ProblemListSection.tsx` (+ `lib/useIssueTypeMessages.tsx`) |
| 신고 사유/참고URL/증빙 파일/신고자 정보/필수 동의 섹션 — `project_report_modal.{reason,reference_url,document,writer,consent}_content` | `apps/global/src/features/project-report/ui/ProjectReportModal/` (ReasonForReportingSection·ReferenceURL·SupportingDocumentSection·SupporterInformationSection·RequiredFieldCheckList) |
| 신고 접수 완료 모달 — `project_report_completed_modal.header.title`="프로젝트 신고 접수를 완료했어요" | `apps/global/src/features/project-report/ui/ProjectReportCompletedModal/ProjectReportCompletedModal.tsx` |

## 앱 알림 안내 · 휴대폰 인증

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 글로벌 웹 알림받기 버튼 — `funding_detail_page.cta_section.cta_button_global_launching_soon_label`="앱에서 알림받기" (딥링크 `action=openAlarm`) | `apps/global/src/features/notification-app-guide/ui/GlobalWebNotificationButton.tsx` |
| 휴대폰 번호 인증(번호 입력→인증번호 전송→확인) — **하드코딩** "휴대폰 번호", "'-' 없이 숫자만 입력해 주세요", "인증번호 전송/재전송", "인증이 완료되었습니다" | `apps/global/src/features/phone-verification/ui/PhoneVerification/PhoneVerification.tsx` |

## 에러 · 기타 페이지

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 만료 에러 — `error_expired_page._default.title`="죄송합니다" | `apps/global/src/pages/error/expired/ErrorExpiredPage.tsx` |
| 점검 중 에러 — `error_maintenance_page._default.title_1`="서비스 점검 중입니다" | `apps/global/src/pages/error/maintenance/ErrorMaintenancePage.tsx` |
| 로그인 필요(권한 없음) 에러 — `error_unauthorized_page._default.title`="로그인이 필요해요" | `apps/global/src/pages/error/unauthorized/ErrorUnauthorizedPage.tsx` |
| 접속 대기 에러 — `error_waiting_for_connection_page._default.title`="현재 접속자 수가 많아 연결 대기 중이에요…" | `apps/global/src/pages/error/waiting-for-connection/ErrorWaitingForConnectionPage.tsx` |
| 미지원 브라우저 에러 — `error_browser_not_supported_page._default.description`="Internet Explorer 브라우저에서는…" | `apps/global/src/pages/error/browser-not-supported/ErrorBrowserNotSupportedPage.tsx` |
| 접근 불가/서버 에러 — 공용 컴포넌트 `NotPermittedErrorContent`·`ServerErrorContent`(@wadiz/ui) 사용 | `apps/global/src/pages/error/{not-permitted,server-error}/` |
| 에러 공통 레이아웃(데스크톱/모바일)·메타 | `apps/global/src/pages/error/ErrorLayout.tsx` |
| 어바웃 슬로건("혁신의 시작") — Framer 외부 사이트 iframe 임베드(언어별 URL 분기), 문구는 외부 | `apps/global/src/pages/about/slogan/innovation-begins/InnovationBeginsPage.tsx` |
| 이미지 최적화 / 로딩 스피너 (문구 없음) | `apps/global/src/features/optimized-image/OptimizedImage.jsx`, `apps/global/src/features/spinner/ui/Spinner.tsx` |

## 이슈 히스토리 (apps/global 내부 features)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| CLIENT-101 | 에픽 | [클라이언트] 스토리 생성 AI |
| FE2-687 | 에픽 | [FE2] WAi - 워크스루 모달 |
| FE2-653 | 에픽 | [브레이즈 이벤트 세팅] 스토리 생성 AI 진입구 확장 |
| FE2-580 | 버그 | [WAi] 메이커 홈 - 히스토리 복원 시 추천 칩 미표시 및 입력창 비활성화 수정 |
| FE1-847 | 에픽 | 앱 다운로드 로그인 적극 유도 |
| FE1-876 | 작업 | 스토리 상단 노출 새소식을 커뮤니티에도 추가 노출 |
