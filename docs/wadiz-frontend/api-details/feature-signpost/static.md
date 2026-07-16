# 기능 이정표 — 레거시 국내 서비스 (static)

> 전체 인덱스는 [`README.md`](./README.md) 참조. 이 파일은 `static/`(와디즈 한국 서비스 레거시, yarn+lerna, **webpack4**)입니다. 각 엔트리는 독립 빌드되어 JSP(`com.wadiz.web`)에서 번들로 로드됩니다. jQuery·MobX v3·`window.wadiz.*` 전역이 일부 남아 있습니다.
> 엔트리 빌드/주입 상세는 기존 [`../static-entries.md`](../static-entries.md) 참조. 여기서는 "기능 → 소스"만 짚습니다. 문구는 대부분 **한국어 하드코딩**.

## 이 파일의 영역

| 영역 |
|---|
| [static/entries (진입점 15종)](#staticentries-진입점) |
| [static/services/admin (어드민 SPA)](#staticservicesadmin-어드민-spa) |

---

# static/entries (진입점)

## web — 공통 엔트리 (모든 페이지 로드)

> 폴리필·전역 네임스페이스(`window.wadiz`)·jQuery/레거시 스크립트·공통 헤더/푸터 렌더러. publicPath `/static/web/`.

관련 이슈: `FE1-1060`(wadiz.io 교체), `FE1-1097`(공통 errorElement Sentry 수집)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 엔트리 정의(polyfill·wui·common) | `static/entries/web/webpack.config.js` |
| `window.wadiz` 전역 네임스페이스 주입, `wadiz.wds.alert/info` 모달 | `static/entries/web/src/common/wadiz/index.js` |
| 레거시 전역 함수(`window.ajax.post` 등, deprecated) | `static/entries/web/src/common/legacy.js` |
| 서드파티 전역화(moment/ko·Clipboard·UAParser·MobX isolate) | `static/entries/web/src/common/library/index.js` |
| 공통 헤더 렌더러(`window.wadizHeaderRenderer`, `WadizHeaderLoaded` 이벤트) | `static/entries/web/src/layout/headerRenderer.jsx` |
| 공통 푸터 렌더러(`@wadiz/web-footer`, `WadizFooterLoaded` 이벤트) | `static/entries/web/src/layout/footerRenderer.jsx` |
| WAi 런처 로드·스크롤 클래스 토글 | `static/entries/web/src/layout/index.js` |

## main — 메인 서비스 SPA

> react-router SPA(`main-app` 마운트) + react-query + redux. 국내 메인·카테고리·피드·찜·마이와디즈·쿠폰·소셜 등. publicPath `/main/`.

관련 이슈: `FE1-827`·`FE1-1035`(따라잡기 추가 탐색), `FE1-988`(SHORTCUT), `FE1-876`(새소식 커뮤니티 노출), `FE1-767`(유저 활동 데이터), `FE2-461`(모두의 펀딩), `FE1-1112`(통합 후속 코드 정리)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 앱 마운트(`main-app`), MSW 개발 목킹 | `static/entries/main/src/index.jsx` |
| Provider·전역 에러 토스트("잠시 후에 다시 시도해 주세요") | `static/entries/main/src/MainApp.jsx` |
| 전체 라우트 정의(lazy, path→page 매핑) | `static/entries/main/src/routes/RouterConfig.tsx` |
| SPA 처리 경로 목록(SPAPathList/NESTED_PATHS) | `static/entries/main/src/constants/routes.js` |
| 찜("N개 할인 중")·피드·캐치업(포인트/알림)·컬렉션 | `static/entries/main/src/pages/{wish,feed,catchup,collection}` |
| 마이와디즈·소셜·서포터 프로필(팔로우, "N개를 찜했어요") | `static/entries/main/src/pages/{my-wadiz,social,supporter}` |
| 쿠폰존/내쿠폰("가입 즉시 쿠폰팩 지급")·카테고리·약관 | `static/entries/main/src/pages/{coupon,category,terms}` |
| 회원가입 플로우·얼리버드·기획전 | `static/entries/main/src/features/{account,main-earlybird,main-planned-exhibition}` |

## reward — 리워드 결제 (JSP 임베드)

> step20.jsp 등에 임베드. 결제(간편결제)·리워드 상품 선택·결제완료 3영역. publicPath `/reward/`.

관련 이슈: `FE1-788`(참여내역 상세 indemand 대응)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 3개 영역 통합 진입(payments/product/complete) | `static/entries/reward/src/index.jsx` |
| 리워드 간편결제 앱·결제예약(`window.simplepay.initSimpleReservationDialog`, eventBus `payment:simple-pay:requested`) | `static/entries/reward/src/payments/SimplePay.jsx` |
| 펀딩 금액 입력(`@wadiz/payment-price-app`) | `static/entries/reward/src/payments/funding-price.js` |
| 리워드 상품 선택 앱 + 환불정책 안내 | `static/entries/reward/src/reward-product/index.js` |
| 펀딩 결제완료("배송이 완료되면 알림을 보내드릴까요?", "혜택 알림 받기") + AI 추천 | `static/entries/reward/src/funding-complete/RewardFundingCompleteContents.jsx` |

## account — 마이페이지/계정 임베드

> JSP 마이페이지 곳곳에 임베드되는 다중 엔트리. publicPath `/account/`.

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 웹팩 다중 엔트리 정의(main/my/social/follow/makinglist/maker-profile/my-purchase-detail) | `static/entries/account/webpack.config.js` |
| 계정관리("가상계좌 발급") / 나의 와디즈 계좌·투자내역(투자 종료 공지) | `static/entries/account/src/main/index.js`, `my/index.js` |
| 리워드 구매 상세 / 메이커 프로필 / 만든 프로젝트 목록 | `static/entries/account/src/{my-purchase-detail,maker-profile,makinglist}/` |
| 소셜 계정 연동("계정이 연동되었습니다")·팔로우 | `static/entries/account/src/{social,follow}/index.js` |

## iam — 인증/알림 임베드

> 친구초대·마케팅알림설정·성인인증·스타트업 컨택 통합 번들. publicPath `/static/iam/`.

관련 이슈: `FE1-626`(19세 인증 동선·차단 프로젝트 안내 네이티브화)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 4개 기능 통합 엔트리 | `static/entries/iam/webpack.config.js` |
| 친구 초대("님이 와디즈에 초대하셨어요") | `static/entries/iam/invite-friends/index.jsx` |
| 마케팅 알림 설정("결제한 프로젝트 새소식…") | `static/entries/iam/marketing-notification-settings/index.jsx` |
| 성인 인증 완료 | `static/entries/iam/adult-authentication/src/AdultCertificationSuccess.tsx` |
| 스타트업 컨택 리스트(거절 사유/검토 의견) | `static/entries/iam/startup-contact-list/index.jsx` |

## 기타 엔트리 (open-account · landing · personal-message · school · analytics · embed · floating-buttons · assets)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| **open-account** — 투자자 증권계좌 개설·신분증 인증 SPA("계좌 관리하기", "계좌 발급 대기 중", 투자 종료 공지) | `static/entries/open-account/src/OpenAccountApp.jsx` |
| **landing** — 정적 랜딩 모음(회사소개·게시판·약관·스타트업 등록·앱별 랜딩), 디렉터리별 독립 번들 | `static/entries/landing/entries.js`, `src/{about,board,terms,startup-registration,apps}/` |
| **personal-message** — 1:1 메시지(대화 "메시지는 실시간 채팅이 아닙니다"·받은함), `@wadiz/app-initializer` 초기화 | `static/entries/personal-message/src/{ChatSpace,Inbox}.jsx` |
| **school** — 와디즈 스쿨 SPA(강의 모집·영상, "곧 공개될 예정이에요") | `static/entries/school/src/routes/DesktopRouter.jsx` |
| **analytics** — UI 없음. `window.wadiz.analytics`·`pageViewTracker` 전역 설치·큐 플러시(프로덕션 전용) | `static/entries/analytics/src/index.js` |
| **embed** — 프로젝트/동영상 임베드 코드 복사 위젯("위젯 임베드 코드가 복사되었습니다") | `static/entries/embed/src/EmbedSettings/` |
| **floating-buttons** — 전 페이지 우하단 플로팅 버튼(WAi 등), 스쿨 경로 예외 | `static/entries/floating-buttons/src/App.jsx` |
| **assets** — 소스 앱 없음. public 아이콘/에셋 복사 전용 | `static/entries/assets/scripts/copy.js` |

> `auth`·`app-info` 엔트리는 `node_modules`만 있고 소스가 없어 실질 빌드 대상이 아닙니다(잔재 디렉터리).

## 이슈 히스토리 (static/entries)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-827 | 작업 | [WEB] 따라잡기 추가 탐색 연결 |
| FE1-1035 | 하위작업 | [WEB] 따라잡기 추가 탐색 연결 QA 대응 |
| FE1-788 | 작업 | 펀딩 참여내역 상세 페이지 - indemand 대응 |
| FE1-973 | 작업 | [Web] 펀딩 참여 내역/스토어 결제 내역 배송지 정보 미노출 처리 |
| FE1-626 | 작업 | 19세 인증 동선 & 차단 프로젝트 안내 페이지 네이티브화 |
| FE1-1097 | 작업 | [Web] static 번들 공통 errorElement에서 Sentry 예외 수집 추가 |
| FE1-1112 | 작업 | [Web] 국내/해외 코드 통합 후속 작업 - 코드 정리 |
| CLIENT-156 | 작업 | GEO/SEO 정책 페이지 검색·AI 노출 제외 (X-Robots-Tag + 효력상실 배너) |
| FE2-461 | 에픽 | 모두의 펀딩 캠페인 |
| FE1-988 | 작업 | [WEB] SHORTCUT 변경 |
| FE1-876 | 작업 | 스토리 상단 노출 새소식을 커뮤니티에도 추가 노출 |

---

# static/services/admin (어드민 SPA)

> webpack4 React SPA, `static/admin/*` 마운트. 최상위 `Router.jsx`가 `/web/**` 경로별로 `React.lazy` 코드스플리팅하고 도메인별 하위 Router로 위임. 개발 시 `proxyInfo.js`가 `PROXY_TARGET`(devadm/rcadm 등)로 프록시하며 쿠키/리다이렉트/HTML static origin을 로컬로 치환. 사내 관리자 도구. 문구 대부분 **하드코딩**.

## 회원 · 서포터클럽

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 서포터클럽 회원 관리("가입 기간 정보", "멤버십 기간", `/web/supporter-club`) | `static/services/admin/pages/supporter-club/containers/SupporterClubContainer.jsx` |
| 서포터클럽 할인권 지급/관리(`/web/supporter-club-voucher`) | `static/services/admin/pages/supporter-club-voucher/containers/SupporterClubVoucherContainer.jsx` |
| 서포터클럽 매출 마감 조회("매출", "마감 상태", `/web/app/supporter-club-settlement`) | `static/services/admin/pages/supporter-club-settlement/containers/SalesContainer.tsx` |

## 메이커 · 스토어

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 메이커 목록/상세("메이커명", "메이커사업자번호", `/web/maker`) | `static/services/admin/pages/maker/pages/MakerMainPage.jsx` (+ `MakerDetailPage.jsx`) |
| 스토어 프로젝트 목록/상세(`/web/app/store/projects`) | `static/services/admin/pages/store-admin-app/pages/StoreProject/index.jsx` |
| 스토어 컬렉션/큐레이션·결제·정산·프로모션·재고/만족도 관리 | `static/services/admin/pages/store-admin-app/pages/{StoreCollection,StoreOrder,StoreSettlement,StorePromotion,StoreSatisfactions}/` |
| 메이커 스튜디오 공지 관리("목록 노출 관리", "메뉴별 진입 모달", `/web/maker-announcement`) | `static/services/admin/pages/maker-announcement/containers/AnnouncementContainer.tsx` |

## 포인트 · 쿠폰

관련 이슈: `FE1-643`(달러 쿠폰 어드민 템플릿), `FE1-79`(통합기획전 어드민 쿠폰 버그)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 할인 쿠폰 관리("쿠폰 템플릿 생성", "멤버십 전용 쿠폰", "스토어 쿠폰", `/web/app/reward-coupon`) | `static/services/admin/pages/reward-coupon/src/routes/RewardCoupon/index.jsx` |
| 쿠폰 회계 관리("거래 기간 조회", `/web/app/coupon-accounting`) | `static/services/admin/pages/reward-coupon-accounting/containers/CouponAccountingContainer.tsx` |
| 회원 쿠폰 발행키 관리("앱 첫 결제 쿠폰", `/web/app/coupon-issuekey`) | `static/services/admin/pages/coupon-issuekey/components/CouponIssuekeyManagementContainer.jsx` |
| 이벤트 보상형 쿠폰 생성/관리("이벤트 생성", `/web/app/benefit-coupon`) | `static/services/admin/pages/benefit/pages/BenefitCouponManagementPage.tsx` |

## 이벤트(통합 기획전) · 홈 관리

관련 이슈: `FE1-978`(부스터 쿠폰 자동 컬렉션), `FE1-1042`(메이커 기획전 조회), `FE1-1187`(AD1 카드 입력 항목), `FE1-203`(부스터 쿠폰 노출 제어), `FE1-82`(기획전 번역), `FE1-683`(퀵메뉴 저장 로직)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 통합 기획전 목록("새 기획전 생성", `/web/event/big-unique-brand-v2`) | `static/services/admin/pages/event/pages/BigUniqueBrand/BigUniqueBrand.tsx` |
| 기획전 상세("키비주얼·배경색·컨텐츠 설정", "기획전 동기화 모달") | `static/services/admin/pages/event/pages/BigUniqueBrand/BigUniqueBrandDetail.tsx` |
| 퀵메뉴/메뉴 관리("국가별 메뉴", "서비스 홈 메뉴", `/web/manage/home/quickMenu`) | `static/services/admin/pages/web-manage/home/quickMenu/QuickMenuContainerV4.tsx` |
| 친구 초대 이벤트 관리(`/web/event/invitation`) / 메인 팝업 관리(`/web/popup/main`) | `static/services/admin/pages/invite-friends/Router.jsx`, `notice-popup/Router.jsx` |

## 커뮤니티 · 알림 · 기타

관련 이슈: `FE1-173`(어드민 포트모드 버그), `FE1-710`(static-admin wadiz.kr 하드코딩 분기), `FE1-1027`(어드민 개발 환경)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 피드 콘텐츠 관리(`/web/community/communityFeedContentList`) | `static/services/admin/pages/community/feed/App.jsx` |
| 알림 발송 결과 조회(`/web/notification/send-result`) | `static/services/admin/pages/notification-list/containers/NotificationList.tsx` |
| 어드민 랜딩("혁신으로 세상을 바르게", "대시보드 바로가기") | `static/services/admin/pages/home/App.tsx` |
| IP 라이센스 관리 (Router 주석 처리 — 현재 비활성) | `static/services/admin/pages/ip-license/Router.tsx` |
| 첨부파일 미리보기 뷰어 / ERP 모달 앱(별도 엔트리) | `static/services/admin/pages/attachment-preview-viewer/PreviewApp.jsx`, `ERPModalApp.jsx` |

## 이슈 히스토리 (static/services/admin)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-643 | 스토리 | [FE] 달러 쿠폰 - 어드민 쿠폰 템플릿 (발행 + 목록) |
| FE1-978 | 에픽 | 기획전 페이지 - 부스터 쿠폰(할인금액) 기반 프로젝트 자동 컬렉션 |
| FE1-1042 | 작업 | [Web] 어드민 메이커 기획전 조회 영역 추가 |
| FE1-1187 | 작업 | [Web] 통합기획전 어드민 AD1 카드 입력 항목 수정 |
| FE1-203 | 에픽 | [Web] 기획전 부스터 쿠폰 기준 노출 제어 기능 구현 |
| FE1-173 | 작업 | [Web] 어드민 포트모드 실행 버그 수정 |
| FE1-82 | 작업 | [Web] 기획전 번역 방식 수정 |
| FE1-79 | 버그 | [Web] 통합기획전 어드민 쿠폰 버그 수정 |
| FE1-710 | 작업 | [Web][Cloud] static-admin의 wadiz.kr 하드코딩 코드 분기 |
| FE1-683 | 작업 | [Web] 퀵메뉴 관리자 페이지 저장 로직 개선 |
| FE1-1027 | 작업 | [Web] 어드민 개발 환경 수정 |
| FE1-388 | 에픽 | [FE] 글로벌 달러 결제 도입 |
