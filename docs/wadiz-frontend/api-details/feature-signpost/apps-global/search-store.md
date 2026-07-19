> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
