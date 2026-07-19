> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
