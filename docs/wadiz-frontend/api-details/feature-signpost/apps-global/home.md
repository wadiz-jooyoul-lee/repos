> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
