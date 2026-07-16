> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
