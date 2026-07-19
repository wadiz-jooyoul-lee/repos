> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
