> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

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
