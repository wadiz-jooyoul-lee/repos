> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
