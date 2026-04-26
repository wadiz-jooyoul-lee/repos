# wadiz-frontend — 페이지 전수 카탈로그

> 모노레포의 **모든 페이지(라우트)를 인덱스화**. 각 페이지마다 라우트 경로 + 1줄 용도 + 파일 위치.
> 270+ 페이지 (apps + studio + static) 를 한 곳에서 조회.

## 카탈로그 개요

| 영역 | 페이지 수 (대략) | 비고 |
|---|---|---|
| `apps/account` | ~37 | 인증/회원가입 (Desktop/Mobile 분기) |
| `apps/global` | ~131 | 메인 사용자 앱 (펀딩·메이커·마이와디즈·정책 등) |
| `apps/ir` | ~14 | IR (Investor Relations) |
| `apps/walink-generator` | 1 | 와링크 생성기 |
| `apps/partners` | 1 | 파트너 소개 (Next.js) |
| `apps/partnerzone` | 다수 | 파트너존 (multi page) |
| `apps/help-center` | — | Zendesk Guide 테마 (페이지 아님) |
| `apps/mail-template` | 다수 | 이메일 템플릿 (Vite) |
| `apps/wai-ai-agent-launcher` | 다수 | AI 에이전트 런처 |
| `apps/devtools` | 다수 | 개발자 도구 (component-playground·app-settings) |
| `studio/funding` | ~10+ | 펀딩 메이커 스튜디오 (Reward 작성) |
| `studio/startup` | 다수 | 증권형 메이커 스튜디오 |
| `studio/store` | 다수 | 스토어 메이커 스튜디오 |
| `static/entries/*` | ~59 | 레거시 호환 정적 진입점 (13 entries) |
| `static/services/admin` | ~8+ | 와디즈 어드민 SPA |
| **총합** | **~270+** | |

> Desktop/Mobile 변형 (`*DesktopPage.tsx`, `*MobilePage.tsx`) 은 동일 라우트의 디바이스별 분기로, 표기 시 같은 항목 1건으로 카운트.

---

## 1. `apps/account` — 인증/회원

배포: `account.wadiz.kr`. SPA 라우터 기반.

### `(auth)` — 일반 인증
| Route | 페이지 | 위치 |
|---|---|---|
| `/login` | 로그인 (이메일·소셜) | `pages/(auth)/login/AuthLoginPage.tsx` |
| `/signup` | 이메일 회원가입 | `pages/(auth)/signup/AuthSignupPage.tsx` |
| `/social-signup` | 소셜 회원가입 | `pages/(auth)/social-signup/AuthSocialSignupPage.tsx` |
| `/social-link` | 소셜 계정 연결 | `pages/(auth)/social-link/AuthSocialLinkPage.tsx` |
| `/find-id` | 아이디 찾기 | `pages/(auth)/(find)/find-id/AuthFindIDPage.tsx` |
| `/find-password` | 비밀번호 찾기 | `pages/(auth)/(find)/find-password/AuthFindPasswordPage.tsx` |
| `/reset-password` | 비밀번호 재설정 | `pages/(auth)/reset-password/AuthResetPasswordPage.tsx` |
| `/account/delete` | 회원 탈퇴 | `pages/(auth)/account/delete/AuthAccountDeletePage.tsx` |
| `/account/signup/completed` | 가입 완료 | `pages/(auth)/account/signup/completed/AuthAccountSignupCompletedPage.tsx` |

### `(auth-app)` — 앱 임베드용
| Route | 페이지 | 위치 |
|---|---|---|
| `/account/signup` (app) | 앱 가입 | `pages/(auth-app)/account/signup/AuthAppAccountSignupPage.tsx` |
| `/account/signup/completed-legacy` (app) | 레거시 완료 | `.../completed-legacy/...Page.tsx` |
| `/account/social-link` (app) | 앱 소셜 연결 | `.../social-link/...Page.tsx` |
| `/account/social-signup` (app) | 앱 소셜 가입 | `.../social-signup/...Page.tsx` |

각 페이지는 Desktop/Mobile/공통 3개 파일 (총 ~37 페이지 파일).

---

## 2. `apps/global` — 메인 앱

배포: `www.wadiz.kr` 의 SPA 영역. **마이와디즈·펀딩 상세 SPA·정책·이벤트** 등 핵심.

### 2.1 홈/검색
| Route | 페이지 | 위치 |
|---|---|---|
| `/` | 홈 | `pages/home/HomePage.tsx` (+ Desktop/Mobile) |
| `/search` | 통합 검색 | `pages/search/SearchPage.tsx` (+ D/M) |

### 2.2 펀딩 상세
| Route | 페이지 | 위치 |
|---|---|---|
| `/funding/{projectNo}/story` | 스토리 | `pages/funding/[projectNo]/story/FundingDetailStoryPage.tsx` (+ D/M) |
| `/funding/{projectNo}/community` | 커뮤니티 허브 | `.../community/FundingDetailCommunityPage.tsx` |
| `/funding/{projectNo}/community/comments` | 댓글 | `.../community/comments/FundingDetailCommunityCommentsPage.tsx` |
| `/funding/{projectNo}/community/reviews` | 리뷰 | `.../community/reviews/FundingDetailCommunityReviewsPage.tsx` |
| `/funding/{projectNo}/community/support-share` | 지지서명 | `.../community/support-share/FundingDetailCommunitySupportSharePage.tsx` |
| `/funding/{projectNo}/news` | 뉴스 목록 | `.../news/FundingDetailNewsPage.tsx` |
| `/funding/{projectNo}/news/{newsID}` | 뉴스 상세 | `.../news/[newsID]/FundingDetailNewsDetailPage.tsx` |
| `/funding/{projectNo}/refund-policy` | 환불 정책 | `.../refund-policy/FundingDetailRefundPolicyPage.tsx` |
| `/funding/{projectNo}/reward-details` | 리워드 상세 | `.../reward-details/FundingDetailRewardDetailsPage.tsx` |
| `/funding/{projectNo}/rewards` | 리워드 선택 | `.../rewards/FundingRewardsPage.tsx` |
| `/funding/{projectNo}/supporters` | 서포터 목록 | `.../supporters/FundingDetailSupportersPage.tsx` |

### 2.3 펀딩 결제
| Route | 페이지 | 위치 |
|---|---|---|
| `/funding/payment` | 결제 메인 | `pages/funding/payment/FundingPaymentPage.tsx` (+ D/M) |
| `/funding/payment/completed` | 결제 완료 | `.../completed/FundingPaymentCompletedPage.tsx` |
| `/funding/payment/pending` | 결제 대기 | `.../pending/FundingPaymentPendingPage.tsx` |

### 2.4 마이와디즈
| Route | 페이지 |
|---|---|
| `/my-wadiz/coupons` | 쿠폰 허브 |
| `/my-wadiz/coupons/my` | 내 쿠폰 |
| `/my-wadiz/coupons/history` | 사용 이력 |
| `/my-wadiz/orders` | 내 펀딩 (주문) |
| `/my-wadiz/orders/{orderNo}` | 주문 상세 |
| `/my-wadiz/points` | 포인트 |
| `/my-wadiz/settings` | 설정 |
| `/my-wadiz/settings/notification` | 알림 설정 |
| `/my-wadiz/settings/notification/news` | 뉴스 알림 |
| `/my-wadiz/inquiries/supporter` | 서포터 1:1 문의 |
| `/my-wadiz/inquiries/maker` | 메이커 1:1 문의 |
| `/my-wadiz/inquiries/conversation` | 문의 상세 |
| `/my-wadiz/invitation-code` | 초대 코드 |
| `/my-wadiz/maker` | 메이커 홈 |
| `/my-wadiz/maker/profile/{corpNo}` | 메이커 프로필 |
| `/my-wadiz/maker/projects` | 메이커 프로젝트 (+ D/M) |
| `/my-wadiz/maker/ad` | 광고 허브 |
| `/my-wadiz/maker/ad/display` | 디스플레이 광고 |
| `/my-wadiz/maker/ad/push` | 푸시 광고 |
| `/my-wadiz/maker/ad/target` | 타겟팅 광고 |

위치: `pages/my-wadiz/...` 하위.

### 2.5 메이커 영역 (마이와디즈 외)
| Route | 페이지 |
|---|---|
| `/maker/dashboard` | 메이커 대시보드 |
| `/maker/projects` | 프로젝트 관리 (+ D/M) |
| `/maker/profile/{corpNo}` | 프로필 |
| `/maker/inquiries` | 문의 |
| `/maker/menu` | 메뉴 |
| `/maker/schedule` | 일정 |
| `/maker/wai` | WAi 메이커 |
| `/maker/ad` | 광고 |
| `/maker/ad/display` / `/push` / `/target` | 광고 타입별 |

### 2.6 정책 페이지 (Static)
| Route | 페이지 |
|---|---|
| `/policies/community` | 커뮤니티 정책 |
| `/policies/plan` | 플랜 정책 |
| `/policies/privacy` | 개인정보 처리방침 |
| `/policies/privacy-agreement` | 카카오 개인정보 동의 |
| `/policies/privacy/entrustments` | 위탁 |
| `/policies/privacy/third-parties` | 제3자 제공 |
| `/policies/privacy/third-parties/global-partners` | 글로벌 파트너 |
| `/policies/privacy/third-parties/makers` | 메이커 |
| `/policies/property` | 자산 정책 |
| `/policies/refund` | 환불 정책 |
| `/policies/report` | 신고 정책 |
| `/policies/review` | 리뷰 정책 |
| `/policies/shipping` | 배송 정책 |
| `/policies/terms/maker` | 메이커 이용약관 |
| `/policies/terms/signup` | 가입 약관 |
| `/policies/terms/supporter` | 서포터 약관 |

### 2.7 소셜·지지서명·소싱클럽
| Route | 페이지 |
|---|---|
| `/social/friends` | 친구 |
| `/social/friends/blocked` | 차단 |
| `/social/friends/followers` | 팔로워 |
| `/social/support-share/{no}` | 지지서명 상세 |
| `/social/support-share/activity` | 활동 |
| `/social/support-share/guide` | 가이드 |
| `/sourcing-club` | 소싱클럽 |

### 2.8 부가 기능
| Route | 페이지 |
|---|---|
| `/wai` | WAi |
| `/wish` | 위시 |
| `/notifications` | 알림 |
| `/refer-a-friend` | 친구 초대 |
| `/refer-a-friend/invitation` | 초대 화면 |
| `/events` | 이벤트 목록 |
| `/events/{eventNo}` | 이벤트 상세 |
| `/events/top` | 탑 이벤트 |
| `/create-project` | 프로젝트 만들기 (Framer 변형 포함) |
| `/settlement-date-calculator` | 정산일 계산기 |
| `/about/slogan/innovation-begins` | 슬로건 |
| `/app/about` | 앱 소개 |

### 2.9 고객지원
| Route | 페이지 |
|---|---|
| `/support/requests` | 문의 목록 |
| `/support/requests/new` | 새 문의 |
| `/support/requests/{requestId}` | 문의 상세 |

### 2.10 에러 페이지
| Route | 페이지 |
|---|---|
| `/error/browser-not-supported` | 브라우저 미지원 |
| `/error/expired` | 만료 |
| `/error/maintenance` | 점검 |
| `/error/not-permitted` | 권한 없음 |
| `/error/server-error` | 서버 오류 |
| `/error/unauthorized` | 미인증 |
| `/error/waiting-for-connection` | 연결 대기 |

---

## 3. `apps/ir` — IR (Investor Relations)

배포: `ir.wadiz.kr` 추정.

| Route | 페이지 | 위치 |
|---|---|---|
| `/` | 홈 | `views/(home)/HomePage.tsx` |
| `/financial-information/audit-report` | 감사 보고서 | `.../audit-report/AuditReportPage.tsx` |
| `/financial-information/consolidated-financial-statement` | 연결 재무제표 | `.../ConsolidatedFinancialStatementPage.tsx` |
| `/information/about` | 회사 소개 | `.../about/AboutPage.tsx` |
| `/information/ceo-message` | CEO 메시지 | `.../ceo-message/CeoMessagePage.tsx` |
| `/information/corporate-governance/board-of-directors` | 이사회 | `.../board-of-directors/BoardOfDirectorsPage.tsx` |
| `/information/corporate-governance/committee` | 위원회 | `.../committee/CommitteePage.tsx` |
| `/information/corporate-governance/stockholders-meeting` | 주주총회 | `.../stockholders-meeting/StockholdersMeetingPage.tsx` |
| `/information/corporate-governance/subsidiary` | 자회사 | `.../subsidiary/SubsidiaryPage.tsx` |
| `/information/esg` | ESG | `.../esg/EsgPage.tsx` |
| `/information/history` | 연혁 | `.../history/HistoryPage.tsx` |
| `/ir-information/announcement` | 공시 | `.../announcement/AnnouncementPage.tsx` |
| `/ir-information/disclosure-information` | 정보공개 | `.../disclosure-information/DisclosureInformationPage.tsx` |
| `/ir-information/reference-room` | 자료실 | `.../reference-room/ReferenceRoomPage.tsx` |

---

## 4. `apps/walink-generator` — 와링크 생성기

| Route | 페이지 | 위치 |
|---|---|---|
| `/` | 홈 (단축 URL 생성) | `pages/(home)/HomePage.tsx` |

---

## 5. `apps/partners` — 파트너 소개

Next.js App Router (`app/page.tsx`).

| Route | 페이지 |
|---|---|
| `/` | 파트너 메인 |

(서브 페이지 추가 가능 — `app/` 하위 디렉터리 추적 필요)

---

## 6. `apps/partnerzone` — 파트너존 (입점 운영)

`pages/main/Main.tsx` 외 multi page 구조. Vite SPA. 진입점 `pages/main/index.tsx`.

> 추가 라우트 상세는 별도 라우터 분석 필요 (현재 카탈로그 미포함).

---

## 7. `apps/help-center` — Zendesk Guide 테마

**일반 React 앱이 아님**. Zendesk Guide 테마 (`manifest.json`, `templates/*.hbs`, `style.css`, `script.js`). 페이지 라우팅 없음 — Zendesk 가 호스팅.

---

## 8. `apps/mail-template`, `apps/wai-ai-agent-launcher`, `apps/devtools`

각 앱마다 별도 구조. 본 카탈로그에서는 라우트 상세 미포함 — Phase 3 보강 대상.

---

## 9. `studio/` — 메이커 스튜디오

### 9.1 `studio/funding` (펀딩 메이커 스튜디오)
주요 페이지: `pages/Reward/components/FundingPage.tsx` 외 다수. 라우터 기반.

> 메이커가 펀딩 프로젝트 작성/심사/오픈예정 관리. 상세 페이지 카탈로그는 별도 분석 (`docs/wadiz-frontend/api-details/apps-maker-studio.md` 참조).

### 9.2 `studio/startup` (증권형 스튜디오)
`routes/Startup/...` 구조. Redux 액션 + reducer 기반.

### 9.3 `studio/store` (스토어 스튜디오)
`components/Page/Page.tsx` + `pages/...`. 주문·재고·기획전 관리.

---

## 10. `static/entries/` — 레거시 호환 진입점

13 entries × 각 entry 내부 페이지. com.wadiz.web JSP 에서 직접 import 되는 정적 번들.

### 10.1 `landing` — 시작 등록
- `RegistrationMakerPage.tsx` (메이커 등록)

### 10.2 `iam` — 인증/권한
| 페이지 | 위치 |
|---|---|
| `MarketingNotificationSettingsPage.jsx` | `marketing-notification-settings/MarketingNotificationSettingsApp/pages/...` |
| `NotificationDenyPage.jsx` | `.../FundingNoticiationDenyApp/pages/...` |
| `InvestmentAndStartupNotificationSettingsPage` | `.../pages/...` |
| `InviteFriendsReceptionUserPage.jsx` | `invite-friends/...` |
| `InviteFriendsWadizUserPage.jsx` | 동상 |
| `ContactListPage.jsx` | `startup-contact-list/...` |

### 10.3 `open-account` — 증권형 계좌 개설
| 페이지 | 용도 |
|---|---|
| `OpenAccountCompletePage.jsx` | 완료 |
| `OpenAccountMobileAuthPage.jsx` | 모바일 본인 인증 |
| `OpenAccountOneCoinTransferPage.jsx` | 1원 송금 인증 |
| `OpenAccountAddressPage.jsx` | 주소 입력 |
| `OpenAccountIdCertificationPage.jsx` | 신분증 인증 |

### 10.4 `main` — 와디즈 메인 (가장 큰 entry)
| 페이지 | 용도 |
|---|---|
| `FundingPage.tsx` (`reward-main/`) | 펀딩 리워드 메인 |
| `StoryPage.jsx` (`funding/reward/.../Story/`) | 펀딩 스토리 |
| `RewardCommunityPage.jsx` (`funding/reward/.../Community/`) | 리워드 커뮤니티 |
| `ComingSoonCommunityPage.jsx` (`funding/comingsoon/.../Community/`) | 오픈예정 커뮤니티 |
| `EventPage.tsx` (`pages/landing/event/`) | 이벤트 페이지 |
| `OrderListPage.tsx` (`my-wadiz/.../my-purchase/.../order/`) | 주문 목록 |
| `OrderDetailPage.jsx` (동상) | 주문 상세 |
| `MyWadizMakerPage` (`my-wadiz/.../legacy-makertab/`) | 레거시 메이커 탭 |
| `LoginRequiredPage.jsx` (`my-wadiz/.../schedule/`) | 로그인 필요 |
| `SupporterProfilePage.jsx` (`supporter/pages/`) | 서포터 프로필 |
| `MyCouponPage.jsx` (`coupon/.../containers/`) | 내 쿠폰 |
| `LastCouponPage.jsx` (동상) | 만료 임박 |
| `CouponDownloadPage.jsx` (동상) | 쿠폰 다운로드 |
| `RecommendedFriendsPage.jsx` (`social/.../recommend/`) | 추천 친구 |
| `RecommendedFriendsPage.jsx` (`feed/.../RecommendedFriends/`) | 피드 추천 |
| `RecommendedFriendEmptyPage.jsx` (동상) | 빈 상태 |
| `PaymentSuccessPage.jsx` (`store/.../paymentComplete/`) | 스토어 결제 성공 |
| `PaymentFailurePage.jsx` (동상) | 결제 실패 |

> `static/entries/main` 은 **가장 큰 entry** — 마이와디즈·쿠폰·피드·소셜·결제 후속 페이지를 한 entry 가 모두 포함.

### 10.5 기타 entries
- `account` — 계정 관련 entry
- `analytics` — 분석
- `assets` — 정적 자산
- `embed` — 임베드 위젯
- `floating-buttons` — 플로팅 버튼
- `personal-message` — 1:1 쪽지
- `reward` — 리워드 (별도)
- `school` — 학교 인증
- `web` — 웹 공통

각 entry 내부 페이지는 본 카탈로그에서 일부만 다룸. 상세는 [`static-entries.md`](./static-entries.md) 참조.

---

## 11. `static/services/admin` — 와디즈 어드민 SPA

webpack 4. `pages/store-admin-app/...` 가 주축. 운영자 화면.

> 상세 라우트는 [`admin-spa.md`](./admin-spa.md) 참조.

---

## 12. 페이지 ↔ Flow 매핑

각 flow ([docs/_flows/](../../_flows/)) 가 대응하는 페이지:

| Flow | 주 페이지 |
|---|---|
| funding-detail | `apps/global/pages/funding/[projectNo]/story/...`, `static/entries/main/.../FundingPage.tsx` |
| funding-payment | `apps/global/pages/funding/payment/...` |
| funding-reward-select | `apps/global/pages/funding/[projectNo]/rewards/FundingRewardsPage.tsx` |
| my-funding | `apps/global/pages/my-wadiz/orders/MyWadizOrdersPage.tsx`, `static/entries/main/.../OrderListPage.tsx` |
| funding-refund | `apps/global/pages/funding/[projectNo]/refund-policy/...` + 결제 취소는 `my-wadiz/orders/{no}` |
| funding-autopay | `apps/global/pages/funding/payment/...` (Billkey 등록 모달) |
| login | `apps/account/pages/(auth)/login/AuthLoginPage.tsx` |
| signup | `apps/account/pages/(auth)/signup/AuthSignupPage.tsx` |
| mypage | `apps/global/pages/my-wadiz/...` (15+ 페이지) |
| coupon-use | `apps/global/pages/my-wadiz/coupons/MyWadizCouponsPage.tsx`, `static/entries/main/.../coupon/...` |
| supporter-signature | `apps/global/pages/funding/[projectNo]/community/support-share/...`, `social/support-share/...` |
| comment | `apps/global/pages/funding/[projectNo]/community/comments/...` |
| search | `apps/global/pages/search/SearchPage.tsx` |
| store-detail | (apps/global 또는 static/entries/main/store) |
| store-order | `static/entries/main/.../store/.../paymentComplete/...` + 마이와디즈 |
| store-wish | `apps/global/pages/wish/WishPage.tsx` |
| notification | `apps/global/pages/notifications/NotificationsPage.tsx`, `apps/global/pages/my-wadiz/settings/notification/...` |
| wai-agent | `apps/global/pages/wai/WAiPage.tsx`, `apps/wai-ai-agent-launcher/` |

---

## 경계·미탐색

1. **partnerzone, mail-template, wai-ai-agent-launcher, devtools** 의 라우트 상세는 본 카탈로그 미포함. 각 앱 라우터 분석 별도.
2. **static/entries/main** 외 12개 entry 의 내부 페이지 카탈로그는 일부만 다룸. 모두 채우려면 각 entry 별 추가 분석 필요.
3. **studio/** 의 페이지·라우트 그래프는 [`apps-maker-studio.md`](./apps-maker-studio.md) 참조 — 본 카탈로그는 진입점만 표시.
4. **데이터 의존성** — 각 페이지가 호출하는 정확한 API 목록은 [`apps-user-facing.md`](./apps-user-facing.md), [`apps-maker-studio.md`](./apps-maker-studio.md), [`packages.md`](./packages.md) 의 매핑 표를 참조.
5. **라우트 가드/권한** — 로그인 필요 페이지, 운영자 권한 요구 페이지 분기 로직은 별도 분석 (각 앱 router config).
