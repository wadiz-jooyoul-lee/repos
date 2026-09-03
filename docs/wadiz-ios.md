# Wadiz iOS (wadiz-ios) 분석

> 크라우드펀딩 플랫폼 **Wadiz**의 공식 iOS 클라이언트.
> Tuist 기반 멀티 프로젝트 + SPM(`Tuist/Package.swift`) 의존성, MVVM+Coordinator 패턴, 단일 `HTTPClient` + `APIDomain` 라우팅.
> 본 문서는 실제 코드 기준으로 **어떤 API 가 어떤 기능에서 어떤 백엔드로 호출되는지** 를 정리한다.

---

> 📅 **2026-09-03 main pull 보강** (117 커밋, 26.33.2.0 → **26.36.0.9**)
>
> ℹ️ **2026-08-25 보강에서 "develop 에만 있어 아직 반영하지 않았다"고 적었던 작업들이 이번 릴리즈로 모두 `main` 에 올라왔습니다** — IOS-3827(deprecated 어댑터 제거) · FE1-1250(analytics 항목 드롭) · FE1-1585(테스트 Mock 정본화) · FE1-1622(Macro 패키지 제거). 커밋 날짜가 2026-06 까지 거슬러 올라가는 이유입니다. (Bump up·다국어 동기화 커밋 다수 생략)
>
> **웹뷰 풀 안정화(FE1-1436, 23커밋)** 가 최대 테마이고, 그 뒤를 기술부채 정리 3종(IOS-3827 · FE1-1250 · FE1-1585)과 릴리즈 파이프라인 정비(FE1-1463/1464/1466/1468)가 잇습니다.
>
> ### FE1-1436 — 재사용 웹뷰 풀의 백지·고아 헤더 문제 (23커밋)
> - 웹뷰를 미리 만들어 재사용하는 풀(`ReusableWebViewPool`)에서 **화면이 백지로 뜨거나 헤더만 남는 문제**를 여러 각도에서 잡았습니다.
> - 주요 조치: 백지 렌더 순서·취소 체계·고아 헤더 정리(T2) → 지각 브릿지 이벤트 차단(T3) → **자가 회복 풀**(T4) → 복구 시 헤더 hosting view 이동(T5) → **SPA 전환이 불가할 때 파괴적 복구를 제거**(T6) → 인증 변경 시 헤더 정리·렌더 타임아웃 화면 가드·retry 늦은 응답 제외(T7) → 진입 시 이전 문서 감춤(T9) → **로드 생명주기 상태 단일화**(T12).
> - 배제된 슬롯의 회복 판정을 "문서 없음" 까지 넓히고, **프리로드 재시작 예산을 실패 회복에만 쓰도록** 제한했습니다(D72·D72').
> - 풀 프로토콜의 기본 구현을 없애 **시그니처가 어긋나면 컴파일에서 잡히도록** 했습니다. SPA 전환 구간 계측과 R4 판별 계측 로깅도 추가했습니다.
> - ⚠️ 진행 중 **"T8 정제 반송 — 실측이 전제를 흔듦"** 커밋이 있습니다. 측정 결과가 기존 가정과 달라 작업을 되돌린 기록입니다.
>
> ### IOS-3827 — deprecated 어댑터 전면 제거 (15커밋, 2026-06~08)
> - 단계적으로 진행됐습니다 — 1단계 `RecentCategoryManager`·`ZendeskManager` 어댑터 제거 → 2단계 소규모 사용처(`RecentKeywordManager`·`AppsFlyerAnalytics`·`BrazeManager`) → 3단계 중규모(`WadizPreference`·`WaditagEventDispatcher`) → 4단계 `GA4Manager`·`UserManager` 어댑터 제거 후 `GA4AnalyticsService`·`UserService` 직접 전환 → 5단계 `ScrollDepthCheckable` deprecated 제거 및 **`GA360.swift` 파일 삭제**.
> - 작업 문서 `docs/IOS-3827/{requirements,plan,progress}.md`(합계 663줄)가 저장소에 함께 들어왔습니다.
> - 비치명 resolve 의 guard-return 을 `assertionFailure` 로 바꿔 **조용히 넘어가지 않게** 했습니다.
>
> ### FE1-1250 — analytics 쿼리 크래시 가드 (12커밋)
> - `RequestBuilder` 가 잘못된 analytics 쿼리에 크래시하던 것을 **항목 단위 드롭**으로 바꿨습니다. 드롭된 항목은 **Crashlytics 에 non-fatal 로 기록**하되, 같은 조합은 1회만 남기도록 제한했습니다.
> - `NetworkingTests` 타깃을 새로 만들고 보존 특성화 테스트를 붙여 **동작 보존 리팩터**임을 증명하는 방식으로 진행했습니다.
>
> ### FE1-1585 — 테스트 Mock 정본화 (8커밋)
> - 각 모듈에 흩어져 중복되던 테스트 double 을 **정본 Mock 하나로 모으고** 검증용 knob 을 보강했습니다. Core·Login·Search·Service·EndingSoon·ServiceHome 순으로 중복 Mock 을 걷어냈습니다.
>
> ### FE1-1463 / FE1-1464 / FE1-1466 / FE1-1468 — 릴리즈 파이프라인 (13커밋)
> - **`main` 을 라이브 포인터로 명문화**하고(FE1-1466, `branching-pr.md`), `main` 보호 ruleset 을 신설해 classic protection 을 걷어냈습니다(FE1-1463 T4).
> - 라이브 반영·머지백 PR 자동화 워크플로를 만들고(T2·T3), **릴리즈 브랜치 분기점을 검증하는 CI 게이트**를 넣었습니다(FE1-1464). 배포 빌드 태깅도 자동화했습니다(FE1-1468).
> - 적대적 리뷰 반영으로 **라이브 회귀 가드·버전 오입력 차단**과 탐지기가 조용히 죽는 경로 차단이 추가됐습니다.
>
> ### 검색홈 피드 (FE1-1629 · FE1-1719, 9커밋)
> - 검색홈 피드의 **VIDEO 동시 재생**을 구현하고 확정 시안을 반영했습니다. 영상 미리보기 상한을 **5초 → 10초**로 늘리고, 메타광고 소재 카드를 9:16 프레임으로 통일하되 원본 비율은 유지했습니다. 카드 여백 8→12, 모서리 반경 8→12.
> - 스크롤 끊김을 수정하고, 스와이프가 실패하던 문제를 **제스처 대상을 피드 컨테이너에서 `ScrollView` 로 교체**해 해결했습니다. 안드로이드 FE1-1645/1646/1628 과 같은 지면입니다.
>
> ### 기타
>
> | 이슈 | 내용 |
> |---|---|
> | FE1-1536 | **따라잡기 글로벌 대응**. 안드로이드 FE1-1548 과 짝 |
> | FE1-1722 | 알림신청 URL 액션을 **글로벌 한정으로 게이트**(1차). 안드로이드 FE1-1726 과 짝 |
> | FE1-1394 | WAi 버튼 애니메이션 체인을 취소 가능한 `Task` 로 전환, 사이클 완주 시 `animationEnabled` 도 함께 내림, 스크롤 방향 액션은 **방향 전환 시점에만** 전송 |
> | FE1-1749 | 회원가입 완료 **Braze 이벤트 이름을 web·android 와 공통화**하고 정본에 맞춰 정정. `RewardCollection`·`SocialLinkLogin`·`SocialSignUp` 의 누락된 PV 수정 |
> | FE1-1622 | **Macro 로컬 패키지 제거**, `UserDefaults` accessor 를 수동 전환. `-skipMacroValidation` 플래그도 함께 제거 |
> | FE1-1738 | AppSetting Default JSON 업로드 |
> | FE1-1621 / FE1-1624 | 스크린샷 공유 PV 이벤트를 제거(웹이 보내는 것으로 대체), 더보기 GNB 클릭 트래킹 소실 수정 |
> | FE1-1450 / FE1-1451 / FE1-1455 | Braze `wipeData` 메서드명 정정과 로그아웃 경로 정합, 인앱 메시지 억제 문서를 코드와 일치시킴, 미사용 Braze 이벤트 정리 |
> | FE1-1716 | `Info.plist`·entitlements 를 Xcode 네비게이터에 노출 |
> | FE1-1719 | UITest LIVE 서버모드 도메인을 **`wadiz.io`** 로 변경 |
> | FE1-192 | RC4 버전 생성 및 매핑 |
>
> ---

> 📅 **2026-09-02 main pull 보강** (2 커밋, → 26.33.2.0)
>
> ### QA-23115 — 소셜 가입 시 약관·마케팅 동의 모달 미노출 수정
> - 소셜 가입 흐름에서 약관·마케팅 동의 모달이 뜨지 않던 문제를 고쳤습니다 (`Projects/App/Sources/AppCoordinator/AppCoordinator+LoginHome.swift`).
>
> ---
>
> 📅 **2026-08-25 main pull 보강** (135 커밋, 26.30.2 → **26.33.1.0**)
>
> ⚠️ **기준 브랜치가 `develop` → `main` 으로 바뀌었습니다.** FE1-1466 에서 `main` 을 **라이브 포인터**로 정의했으므로, 이제 이 문서는 실제 릴리즈된 상태를 따릅니다. 그래서 develop 에만 있는 작업(IOS-3827 deprecated 어댑터 제거, FE1-1250 analytics 항목 드롭, FE1-1585 테스트 Mock 정본화, FE1-1622 Macro 패키지 제거 등)은 **아직 이 블록에 없습니다** — 릴리즈되면 반영됩니다.
>
> **국내 GNB 위시 탭 복원(FE1-1496)** 과 **홈 와디즈 에디션 섹션(FE1-1316)** 이 핵심입니다. (Bump up·다국어 리소스 동기화 커밋 다수 생략)
>
> ### FE1-1496 — 국내 GNB 위시 탭 구성
> - `TabBarIndex` 구성을 바꿔 국내 GNB 에 **위시 탭**을 다시 넣고 라벨을 붙였습니다. 2026-07-31 보강의 FE1-1236/1378 에서 "위시 탭을 막펀잡기 탭이 대체"하고 `TabBarIndex.wish` 케이스를 제거했던 것이 이 이슈로 되돌아왔습니다.
> - 기본 `rightBarButtonItem` 을 '검색 & 홈' 으로 수정하고 네비게이션 헤더·GNB 이벤트 action 을 정비했으며, 상단 카테고리 버튼 클릭 이벤트 수집 값을 정정했습니다.
>
> ### FE1-1316 — 홈 와디즈 에디션 섹션
> - 에디션 DTO 디코딩 + 도메인 모델·매퍼·디스패치, 기본 섹션/카드 렌더, 탭 이동과 analytics 를 구현했습니다. DEBUG 빌드용 `HomeStub` 에디션 카드와 `UITestConfigurator` 런치 인자 게이트를 붙여 UI 테스트에서 고정 데이터를 쓸 수 있게 했습니다. 웹 FE1-1316/1318, Android FE1-1364 와 같은 지면입니다.
>
> ### FE1-1415 — 막펀잡기 후속 UI 개선
> - 카드 UI 를 고정 타이머 영역·16:9 이미지·뱃지 행·CTA 재구성으로 개편하고, 페이징 전환 모션을 '배경 고정 + 이미지 줌' 으로 교체했습니다. 찜 상태 연동과 자동넘김 진행값을 정합시키고, 다크 배경용 검은 테두리 뱃지 variant 를 추가했으며 '내가 찜한' 뱃지 라벨은 i18n 키로 교체했습니다.
>
> ### FE1-1467 — 이커머스 이벤트에 찜 여부(`is_interested`) 수집
> - `ActivityProvider` 의 찜 상태를 **3-state 저장**(찜함/안함/미조회)으로 바꾸고 찜 상태 조회 창구를 이커머스 수집에 연결했습니다. 막펀잡기 피드 적재 시점과 스토어홈 주 목록에도 찜 상태 조회를 추가했고, 비로그인 처리·수집 값 표기는 플랫폼 합의(웹 FE1-1478, Android FE1-1474)와 맞췄습니다.
>
> ### FE1-1264 — 글로벌 path URL 대응 (수집 URL 언어코드)
> - 화면 URL 조립 공통 관문 `buildScreenUrl` 에 언어코드를 부착하고, `NavigationMap.needLogin` 은 언어코드를 제거한 뒤 비교하도록 바꿔 글로벌 경로에서도 로그인 판별이 되게 했습니다. `getValidDeepLinkUrl` 은 언어코드를 정규화해 비교(딥링크 쿼리 병합 유지)하고, `prependingLanguageCode` 의 `wadiz://` 스킴 언어코드 위치 버그를 고쳤습니다. 언어코드 유틸 2개를 `ScreenKeyParser` 에 프로토콜+구현+Mock 으로 추가.
>
> ### FE1-1597 / FE1-1297 — 도메인 전환·RemoteConfig 이관
> - FE1-1597: `.io` 도메인 전환 시 `kr` 도메인의 `_waid` 쿠키를 `io` 도메인으로 이관하고, preload 실패 경로에서도 이관을 수행하며 조회는 활성 도메인 기준으로 합니다(Android FE1-1598 과 짝).
> - FE1-1297: Firebase RemoteConfig 이관 및 A/B 테스트 작업 머지(#3287), 최신 AppSetting 값으로 `default.json` 갱신(Android FE1-1385 와 짝).
>
> ---
>
> 📅 **2026-07-31 develop pull 보강** (97 커밋, 26.29.1 → 26.30.2)
>
> 신규 **막펀잡기(마감임박, EndingSoon)** 피드 모듈과 위시 Top Nav 전환이 핵심입니다. (Bump up 커밋 다수 생략)
>
> ### FE1-1236 / PRODUCT-859 — 막펀잡기(마감임박) 피드 모듈 신규
> - `Projects/Features/EndingSoon` 신규 모듈. 마감임박 프로젝트를 전체화면 카드 페이저로 넘기는 피드입니다. API: `GET /api/search/v1/catchup/ending-soon`(`.service`, 정렬된 {id, endTime} 리스트 + serverTime/refreshTime), 쿠폰 발급 `POST /web/reward/api/coupons/templates/redemptions`(`.api`). (`Projects/Features/EndingSoon/Sources/Data/EndingSoonAPIRepository.swift`)
> - GNB 탭·네비게이션 통합으로 기존 **위시 탭을 막펀잡기 탭이 대체**하고, BNB 아이콘 등장 모션 + N 뱃지를 추가했습니다. 리워드 선택은 웹 모달(`ModalWebViewController`)로 띄우고 `toast.show` 웹 메시지를 수신합니다. (`Projects/App/Sources/NativeBase/Controller/*`, `WebView/URLNavigation/ModalWebViewController.swift`)
> - 자동 진행 주기 8초→5초, 마감 시 카운트다운 0 표시(오늘마감 라벨 폐지), 쿠폰 뱃지는 정액·정률한도 중 큰 값 노출, 조기 마감 프로젝트 CTA 비활성·쿠폰 뱃지 숨김. Braze 커스텀 이벤트(`finalcall_pv`/`complete`) 추가, 분석 서비스명을 "마감임박"→"막펀잡기"로 통일.
> - 크래시 수정: 페이저를 `UIPageViewController`→`UICollectionView`로 전환하고 스크롤 중 크래시·전환 겹침을 가드. QA 수정 다수(QA-22770 첫 카드 위 스크롤 차단, QA-22776 +0P 당첨 토스트 오노출, QA-22788 쿠폰 다운로드 후 CTA 반영, QA-22811·22813 로그인 모달·타이머 다국어, QA-22817 타이머 0초 즉시 비활성, QA-22818 정지 상태 이탈·복귀 유지).
>
> ### FE1-1378 — 막펀잡기 딥링크·트래킹
> - `/endingsoon/main` 딥링크를 막펀잡기 탭 라우팅으로 연결(`AppCoordinator+EndingSoon.swift`, `NavigationMap+EndingSoon.swift`). 막펀잡기 PV(GA4/Waditag)·GNB 클릭 트래킹 수집을 수정하고, `TabBarIndex`의 미사용 `.wish` 케이스를 제거했습니다.
>
> ### FE1-1255 — 위시 Top Nav 전환 + my-wadiz v5
> - 마이와디즈 Top Nav의 최근본 버튼을 **위시 버튼(카운트 뱃지 포함)** 으로 교체(`WishNavigationButton.swift`), 미사용 `RecentProjectButton` 삭제. 최근본은 플로팅 틸트 카드(`RecentProjectFloatingButton.swift`)로 이동. 위시 뱃지 클리어를 탭 진입뿐 아니라 Top Nav 진입에도 적용.
> - my-wadiz 조회를 v4→**v5**(`/api/v5/my-wadiz`)로 go-live 전환, `CURATION_PROJECT` 실데이터로 위시 환기영역 렌더. DEBUG 상시 스텁 등록 제거, `Main2API`의 무버전 오버로드 정리. (`Projects/Features/MyWadiz/Sources/Data/MyWadizRepositoryImpl.swift`)
>
> ### FE1-1376 / FE1-1361 — 따라잡기(CatchUp)
> - FE1-1376: 보너스 스테이지 Braze 이벤트 추가(`CatchUpBrazeEvent.swift`). FE1-1361: 완료 페이지 위시 유도 팝퍼의 말꼬리표 제거(`CatchUpWishPopperView.swift`).
>
> ### FE1-1307 / FE1-1335 — 마이와디즈·홈
> - FE1-1307: 메인 홈 유저 활동 배너 미노출 수정(`ActivityBannerProvider.swift`). FE1-1335: 마이와디즈 `CARD_ACTIVITY`의 `ActivityType` enum 제거·String 전환(서버 신규 값 유입 시 탭 dead 방지).
>
> ### FE1-1234 / FE1-1391 — 빌드·동시성
> - FE1-1234: **Fastlane 2.237.0** 업데이트 및 **cocoapods 의존성 삭제**(`Gemfile`/`Gemfile.lock`). FE1-1391: `AlarmChannel`에 `Sendable` 채택(Xcode 26.6 대응). WSR-3423: 환기형 프로젝트 카드 width 160→168 통일.
>
> ---
>
> 📅 **2026-07-21 develop pull 보강** (26.27.0 → 26.29.1)
>
> 검색홈 리뉴얼(FE1-699), 앱 재시작 파이프라인(FE1-1227), 세션·네비게이션 안정화가 핵심입니다. (Bump up 커밋 다수 생략)
>
> ### FE1-699 — 검색홈 카드·피드 리뉴얼
> - VIDEO 카드 썸네일→재생 전환 깜빡임 제거, 비디오 카드 최초 로딩 플레이스홀더 크기 이탈 수정, 프로젝트 카드 메이커 클럽 아이콘 제거, 섹션 여백 조정(최근↔인기 16, 인기↔피드 24). 피드 페이징 offset을 `offset+size` 전진으로 변경, masonry 재분배 stale 캡처 수정(무한스크롤 중단 근본원인, QA-22645). 최근검색어 API 식별자 부재 시 요청 스킵.
>
> ### FE1-1227 — 앱 재시작(AppReset) 파이프라인
> - 리셋 파이프라인 및 DI 등록(`AppCoordinator`+`AppReset`), context 산출(cold 흡수 vs running 재시작) 단위테스트, 재시작 성공/실패 Crashlytics 로깅(`Service/*/AppReset/`).
>
> ### FE1-1229 / FE1-1231 / FE1-1119 — 세션·네비게이션·뱃지 안정화
> - FE1-1229: 세션 에러 중복 얼럿 처리(versionCheck in-flight 가드).
> - FE1-1231: back-forward 복원 시 본문 스켈레톤 잔존·빈 화면 방지(opacity 0 유지), stale 플래그 정리.
> - FE1-1119: 뱃지 읽음 처리를 로그인 무관 **디바이스 단위**로 통일, 국가 전환 로딩 중 에디션 팝퍼 노출 방지.
>
> ### FE1-1142 / FE1-1170 / FE1-1209 / FE1-1082 — 기타
> - FE1-1142: `NavigationMap` DETAIL ScreenKey을 `FUNDING_DETAIL`/`STORE_DETAIL`로 분리(`ScreenKeyMatcher`).
> - FE1-1170: CDN config 5종을 앱 설정 API로 이관. FE1-1209: `URLConstant` 미사용 제거 및 하드코딩 도메인 전환 대응.
> - FE1-1082: 로그인 유도 모달 데이터 수집(웹 category 사용·한글 라벨). FE1-1261: provisioning profiles 변경.
>
> ---
>
> 📅 **2026-07-10 develop pull 보강** (90 커밋, 26.23.2 → 26.27.0)
>
> ### FE1-1001 — 와디즈 에디션 탭 신설 (하단 탭바 "친구" 대체)
> - 하단 탭바(BNB)의 `친구(feed)` 탭을 **와디즈 에디션(edition)** 탭으로 교체. `TabBarIndex.feed → .edition`, 라벨 "에디션", waditag action "와디즈에디션". 친구 지면은 push 네비바로 복구 (`Projects/App/Sources/NativeBase/Controller/TabBarIndex.swift`, `TabBarEvent.swift`, `LocalTabBarController.swift`).
> - 신규 `EditionWebViewController` (기본 진입 `/web/wevent/513`, 네비바 "와디즈 에디션"). 에디션 페이지 내 상세 URL 은 `ProjectDetailURLMatcher` 로 판별해 **별도 웹뷰로 분리** 로드, `sessionStorage.SWIPE_EVENT_PAGE` 컨텍스트 주입. `BaseWebViewController` 에 `additionalUserScripts()` hook 추가 (`Projects/App/Sources/WebView/Edition/EditionWebViewController.swift`, `WebView/BaseWebViewController.swift`).
> - 에디션 탭 N뱃지: `EditionTabBadgeStateUseCase` + 앱-스코프 싱글턴 Assembly (cold start 기준 노출/진입 시 제거). 친구 카운트 뱃지 로직은 App→Home 으로 이전 (`Projects/App/Sources/.../EditionActivity/`).
>
> ### FE1-961 — PIPKit SPM 의존성 제거, Core/UI `FloatingViewKit` 자체 구현
> - 외부 `PIPKit`(SPM) 패키지를 제거하고 라이브커머스 PIP 를 `Projects/Core/Sources/UI/FloatingViewKit` 로 완전 재작성. `@MainActor` caseless enum 네임스페이스 + `FloatingViewEventDispatcher`(드래그·스냅) + `FloatingViewLayout`(6영역 판정 순수함수, 단위테스트 대상). `Tuist/Package.swift`·`TargetDependency+Templates.swift`(`.pipKit`)·`App/Project.swift` 에서 PIPKit 선언 제거. → 기술스택의 "PIPKit 1.1.0" 은 더 이상 유효하지 않음.
>
> ### FE1-1047 / FE1-1093 — Navigator 모듈을 Features → Service 계층으로 이주
> - cross-feature 직접 참조 규칙 위반 해소를 위해 `Navigator` 를 Features 레이어에서 **Service 계층 단일 framework** 로 이주. Search/MyActivity 의 dead `.navigator` 의존·import 정리. 이주 직후 import 누락 빌드 실패는 FE1-1093 으로 후속 수정.
>
> ### FE1-984 — ProjectDetailURLMatcher App → Shared 이동, /ko/funding 서브패스 대응
> - `ProjectDetailURLMatcher` 를 App→`Projects/Shared`(public) 로 이동. globalDetail 정규식에 서브패스(`supporters/community/news/refund-policy/reward-details`) + 로케일 프리픽스(`/en/funding`, `/ko/funding`) 조합 추가. 스크린샷 공유 스낵바(`isEnableWadizSnackbar`)·`FirebasePerformanceTraceManager` 의 하드코딩 path 판별을 Matcher 기반으로 교체.
>
> ### FE1-1001(웹뷰) / FE1-985 — 상세 웹뷰 표시 버그 수정
> - 상세→상세 뒤로가기 시 `WKWebView` opacity 미복원으로 흰 화면 되던 문제 수정(FE1-985). GIF 썸네일/배너 CDN 최적화 제외 가드 추가(FE1-970).
>
> ### FE1-1009 — 스타트업 메뉴 `startupMenuEnabled` 플래그 기반 비노출
> - `FeatureFlagsResponse.startupMenuEnabled`(fail-open default=true) 추가. 플래그 false 시 More 단축 아이콘·알림 설정의 스타트업 섹션을 로케일 무관 숨김. `MoreRepository`/`MoreRepositoryImpl` 신설로 `AppSettingAPI` 의존성을 Repository 계층에 격리.
>
> ### FE1-968 — 대체 앱 아이콘 교체 (blackbird 2025 → 펀딩 페스티벌 2026)
> - `AppIcon` 대체 아이콘셋 `icon_blackbird_2025` 제거, `icon_fundingfestival_2026` 추가. Dev/QA/Release xcconfig `ALTERNATE_APPICON_NAMES` 갱신. 교체 자동화 스킬 `.claude/skills/replace-alternate-appicon` 추가.
>
> ### FE1-1015 / FE1-1064 — 최근 검색어 API 식별자 헤더 보완
> - `RecentSearchAPI` 의 register/delete/deleteAll 에 `deviceId`(`_waid` 쿠키, 항상)·`encUserId`(로그인 시) 헤더 주입 — 공통 헤더의 uuid/userId 와 헤더명이 달라 단건 삭제에서 500 나던 문제 수정. 재클릭/동일 키워드 재검색 시 서버 전송 보완(FE1-1064).
>
> ### FE1-1025 — 비 iOS 플랫폼 리소스 제거 (App Store 심사 Guideline 2.3.10 대응)
> - Android/Google Play/Galaxy/Windows 로고 에셋 8종을 xcassets 에서 제거(코드 미사용이나 번들 포함으로 심사 감지). `deeplink_test.html`·`i18n.json`(`android_description_markdown`) 의 Android 참조도 제거.
>
> ### 개발 하네스 / CI (FE1-891 · FE1-1095 · FE1-1138 · FE1-1049 · FE1-1177)
> - 정제→계획→구현→검증 **하네스 파이프라인** 구축(FE1-891) + 결정 로직 python 스크립트 추출·단위테스트(FE1-1095).
> - `.claude/hooks/` + `.claude/settings.json` 배선(FE1-1138 R1~R9): 보호 브랜치 커밋 차단, 강제 언랩·신규 storyboard/xib·생성파일 편집·시크릿 접근·SwiftLint 위반 차단, ARCHITECTURE 동반 경고(Stop 훅). `make hooks-test` 102 green.
> - GitHub Actions 배포 워크플로우에 `environment`(adhoc/release) 부여해 **GitHub Deployments** 이력 추적(FE1-1049). Ad Hoc 프로비저닝 4종에 iPhone 17 기기 추가·재생성(FE1-1177). `make verify` lint 회귀 복구(FE1-1051).

---

## 개요

| 항목 | 값 | 참조 |
| --- | --- | --- |
| Bundle ID | `com.markmount.wadiz` | `Projects/App/Project.swift:94`, `Projects/App/SupportingFiles/Configuration/Base.xcconfig:9` |
| Extension Bundle IDs | `.WadizWidget`, `.MakerStoreProjectIntents`, `.notificationservice` | `Projects/App/Project.swift:300,325,349` |
| 지원 OS 최소 | **iOS 16.1** | `Tuist/ProjectDescriptionHelpers/Environment.swift:5` |
| MARKETING_VERSION / BUILD | `26.30.2` / `26.30.2.0` | `Projects/App/Project.swift:7-8` |
| 배포 채널 | **App Store (Release)** / **TestFlight (QA)** / Fastlane develop / Adhoc | `fastlane/Fastfile:27-55`, `.github/workflows/` |
| Schemes | `wadiz-dev` (Debug), `wadiz-qa` (QA), `wadiz-release` (Release) | `Projects/App/Project.swift:393-441` |
| Development Team | `PN5T77486L` | `Projects/App/SupportingFiles/Configuration/Release.xcconfig:12`, `Environment.swift:8` |
| Associated Domains | `applinks:www.wadiz.kr`, `applinks:www.wadiz.ai`, `applinks:link.wadiz.kr`, `webcredentials:wadiz.kr` | `Projects/App/SupportingFiles/wadiz.entitlements:14-18` |

---

## 기술 스택

- **언어**: Swift (compiler `5.9`, `Tuist.swift:5`). 최소 iOS 16.1, 아키텍처 MVVM + Coordinator (`CLAUDE.md:11`).
- **빌드/의존성**: **Tuist 4.113.1** (`.tuist-version`) + SPM (`Tuist/Package.swift`). Xcode 호환 `upToNextMajor("26.0")`. Workspace `wadiz.xcworkspace` 자동 생성. Ruby `3.2.5` (`.ruby-version`) + Fastlane 2.x.
- **동시성**: 현대 경로는 **async/await** (ex. `HomeRepositoryImpl`, `HTTPClient.request(request:type:)`). Combine 은 Dev 빌드에 `-weak_framework Combine` 로만 링크 (`Dev.xcconfig:19`), Release 빌드는 Combine 없이 (`Release.xcconfig:14-17`). **CombineInterception** SPM 포함.
- **Strict Concurrency 진행 중** — 각 Project 에 `STRICT_CONCURRENCY_GUIDE.md`, `nonisolated(unsafe)` 패턴 다수 (`WadizRequestInterceptorImpl.swift:19,20,23,24`). `Service/USERSERVICE_ACTOR_MIGRATION_GUIDE.md` 로 actor 전환 가이드.
- **네트워킹**: **Alamofire 5.10.2** + 자체 `HTTPClient`/`RequestBuilder`/`WadizRequestInterceptor`. 로그 수집 **Pulse 2.1.5** + `pulseUI`, `pulseLogHandler`. 로깅 어댑터 `CocoaLumberjack 3.8.5`. 디버그 `OHHTTPStubs 9.1.0` (테스트). (`Tuist/Package.swift:26,50,54,73`)
- **이미지**: **Kingfisher 8.6.2**, `SDWebImage 5.21.3`, `SVGKit 3.0.0`. (`Tuist/Package.swift:32,37,36`)
- **UI 컴포넌트**: **SnapKit 5.7.1** (AutoLayout), **Lottie 4.6.0**, **FloatingPanel 2.0.1**, **FSPagerView**, **IGListKit 5.0.0**, **PIPKit 1.1.0**. (`Tuist/Package.swift:33-41`)
- **DI**: **Swinject 2.9.1** (`DIContainer.shared.resolver`), 각 레이어 `…Assembly.swift`. (`APIDomain.swift:35-46`, `Tuist/Package.swift:44`)
- **영속화**: 자체 `Projects/Core/Sources/Persistence` (Interface/Feature 분리) + `Projects/Core/Sources/Preference` + **KeychainSwift 20.0.0** (토큰/자격증명 저장). Core Data/Realm 사용 X, App Group `UserDefaults` 로 Widget/Intents 와 공유 (`Projects/App/Sources/Common/UserDefaults+AppGroup.swift`).
- **Firebase 12.7.0**: Analytics / Crashlytics / Messaging / RemoteConfig / Performance (`Tuist/Package.swift:29`, `Projects/App/Project.swift:252-256`).
- **Analytics/Attribution**: **AppsFlyer 6.17.7**, **Microsoft Clarity 3.4.0** (session replay / heatmap). (`Tuist/Package.swift:56-57`)
- **Push / Engagement**: **Braze Swift SDK 13.3.0** (`brazeKit`, `brazeUI`). (`Tuist/Package.swift:60`)
- **Social Login**: Kakao (`kakao-ios-sdk` 2.24.6), Naver (`naveridlogin-sdk-ios-swift` 5.1.0), Google (`GoogleSignIn-iOS` 7.1.0), Line (`line-sdk-ios-swift` 5.13.0), Facebook (`facebook-ios-sdk` 18.0.1). (`Tuist/Package.swift:62-66`)
- **CS**: Zendesk SDK Messaging 2.27.0 + Logger 0.10.0. (`Tuist/Package.swift:69-70`)
- **Macro 패키지**: `/Packages/Macro` (Swift Macros, swift-tools-version 5.9, `swift-syntax` 509+). `Persistence` 모듈에서 의존 (`Projects/Core/Project.swift`). (`Packages/Macro/Package.swift`)
- **Utility**: `ZMarkupParser 1.11.0` (HTML→AttributedString), `PhoneNumberKit 4.0.2`, `AcknowList 3.3.0` (OSS License), `Pulse`, `CombineInterception 0.1.1`. (`Tuist/Package.swift:47-54`)

---

## 모듈 구성

`Workspace.swift` 가 `Projects/App` + 모든 `Projects/Features/*` + `Projects/Core|Service|API|Model|Shared` 를 포함. 각 Project 는 **Interface / Sources / Tests / Testing / Example** 5 타겟 구조 (Micro Features Architecture, `CLAUDE.md:112-124`).

### `App` (Main Target `wadiz`)
- `App` — 메인 앱 (`Projects/App/Sources/AppCoordinator`, `Common`, `UIComponent`, `Benefit/ServerDriven`, `Contacts`, `Wish`, `Banner`, `Exhibition`, `Startup`, `AD`, `Plus`, `NewOpen`, `NativeBase`, `Account` 등 **레거시 구현이 App Target 내부에 다수 존재**).
- Extensions:
  - `WadizWidget` (`appExtension`, com.markmount.wadiz.WadizWidget) — 홈스크린 위젯 (메이커 스토어 프로젝트).
  - `MakerStoreProjectIntents` (`appExtension`) — SiriKit Intents (스토어 프로젝트 조회).
  - `NotificationService` (`appExtension`) — 푸시 Content Extension (Braze rich push 처리).
- Tests: `WadizTests` (유닛), `WadizUITests` (UI).

### `Projects/Features/*` (Micro Features)
| 모듈 | 역할 |
| --- | --- |
| `AppIcon` | 앱 아이콘 변경 (Blackbird 2025 등 대체 아이콘) |
| `CatchUp` | CatchUp 피드 |
| `Category` | 카테고리 탐색 |
| `ChangeTimeZone` | 타임존 설정 |
| `ConfirmPassword` | 비밀번호 재확인 모달 |
| `CreditCardOCR` | **신용카드 OCR** (`CameraManager.swift` + Vision/CoreML) |
| `Email` | 이메일 수정 |
| `EndingSoon` | 막펀잡기(마감임박) 전체화면 카드 피드 (FE1-1236 신규, 위시 탭 대체) |
| `Home` | 홈 탭 |
| `Intro` | 스플래시/인트로 (Lottie) |
| `KakaoMultiFollow` | 카카오 친구 일괄 팔로우 |
| `Login` | 로그인/SNS Link/이메일 로그인/소셜 회원가입/약관 모달/마케팅 동의 모달 |
| `More` | 더보기 |
| `MyActivity` | 내 활동 (찜/최근 본/구매) |
| `MyWadiz` | 마이와디즈 (서포터 뷰) |
| `MyWadizModeSelect` | 서포터/메이커 모드 전환 |
| `Navigator` | 딥링크/네비게이션 중앙 허브 (`NavigatorImpl.swift`) |
| `NotificationCenter` | 알림 센터 (Inbox) |
| `Onboarding` | 신규 유저 온보딩 |
| `PasswordSetting` | 비밀번호 설정 |
| `Permission` | 권한(카메라/사진/연락처/ATT/Location/Bluetooth) 사전 모달 |
| `Search` | 검색/결과/쿠폰 검색/연관 키워드 |
| `ServiceHome` | 서비스홈 (리워드/스토어/체험단) |
| `SetKeywordAlarm` | 키워드 알람 설정 |
| `Setting` | 설정 홈 / 닉네임 / 전화번호 / 알림 설정 |

### `Projects/Service`
비즈니스 로직 서비스. `Sources/{Activity, Analytics, AppSecurity, Braze, ContactSync, DeviceSetting, FloatingButtons, FriendActivity, KeywordAlarm, LiveCommerce, Locale, MyWadizMode, Notification, RecentCategory, RecentKeyword, RecentProject, RefererURL, RemoteConfig, ScreenKeyParser, SearchBarDayMarketing, Share, SmsAuth, SocialLogin, Spotlight, User, Zendesk}` — 각 폴더에 Feature/Interface 분리. 주요: `Activity` (찜 API), `SmsAuth` (SMS 인증), `Analytics` (Waditag), `KeywordAlarm`, `SocialLogin`. **`LiveCommerce`(FE1-809, 2026-06-02)** 는 App 내부에 있던 라이브커머스 모델/유스케이스를 Service 모듈로 분리한 것으로, Remote Config(`liveCommercePip`)의 노출 ON/URL 을 읽어 JSON 이벤트 목록(`LiveCommerceServiceImpl.currentEvent(isLocal:)`)을 받아 UTC 기간·우선순위로 현재 노출 이벤트를 고른다.

### `Projects/API` (REST Client)
하나의 Project 에 다수의 Framework 타겟 (현재 26개: `AccountAPI, ActivityAPI, AnalyticsAPI, AppAPI, AppSettingAPI, CatchUpAPI, CommonAPI, FriendsAPI, FundingAPI, GlobalAPI, InboxAPI, KeywordAPI, LoginAPI, Main1API, Main2API, SearchAIAPI, SearchAPI, SignUpAPI, SmsAuthAPI, SocialAPI, StartupAPI, StoreAPI, TermsAPI, UserAPI, WebAPI, WishAPI`). 엔드포인트는 `RequestBuilder(apiURLSource: APIURLSource(domain:path:), method:)` 형태로 구성. 주요 타겟:
| 타겟 | 역할 |
| --- | --- |
| `AccountAPI` | 계정 조회/갱신/SNS 링크 |
| `AppSettingAPI` | 앱 설정 (Server-Driven Settings Tab, `/api/v1/settings`) |
| `LoginAPI` | 로그인/로그아웃 |
| `Main1API` / `Main2API` | Platform main2 (홈 메인/퀵메뉴/랭킹/추천/키비주얼; 구 `MainAPI` 가 v1/v2 로 분리) |
| `SearchAPI` | 검색/카테고리/펀딩소프트/스토어검색/프리오더 |
| `SignUpAPI` | 회원가입/이메일 코드 |
| `SocialAPI` | 카카오 친구/다중 팔로우 |

> 참고: 위 26개 타겟 구조는 본 분석 범위(2026-06-19) 이전 리팩토링으로 이미 정착돼 있었다. 구 `MainAPI`는 `Main1API`(`.publicApi(.main1)` 도메인) + `Main2API`(`.platform(.main2)` 도메인, base path `/main2`)로 분리됐고, 본 문서의 "기능별 API 호출 매핑" 표 경로도 신규 타겟명으로 갱신 완료했다.

### `Projects/Core`
하나의 Project 에 4 개 Framework 타겟 (`CLAUDE.md:109`): **`Networking`** (HTTPClient, RequestBuilder, APIDomain, Interceptor, WadizSession), **`Persistence`** (Macro 의존), **`Preference`** (AppPreference, ServerMode), **`UI`** (공통 UI + i18n.json).

### `Projects/Model` + `Projects/Shared`
`Model` 은 도메인 모델 (Core/UI, Shared 의존). `Shared` 는 최하위 Extension/UUIDManager/URL+Extension/TestEnvironmentKey 등.

### Android ↔ iOS 모듈 매핑 간편 비교

| iOS | Android 등가 | 메모 |
| --- | --- | --- |
| `Projects/Core/Networking` | `core/network` | 거의 동일 역할 (HTTPClient ↔ BaseWadizAPIProvider) |
| `Projects/Core/Preference` (+ ServerMode) | `core/legacy/wadiz-common/util/ServerMode.kt` + `core/datastore` (HiddenPrefs) | 동일 8개 환경 모델 |
| `Projects/Core/Persistence` | `core/database` (Room) | iOS 는 Core Data 대신 자체 Persistence + Macro |
| `Projects/Core/UI` + `i18n.json` | `core:design-system` + `core:i18n` | 동일한 i18n.json 포맷 공유 |
| `Projects/API/*` (26 타겟) | `core/network/service/**` (17 ApiService) | Android 는 `ServerMode.xxxUrl` 속성을 baseUrl 분기 키로 쓰는 반면 iOS 는 `APIDomain` enum |
| `Projects/Service/*` | `core/data/repository/**` (+일부 feature 내부) | iOS 는 Service 레이어가 Android Repository + UseCase 일부 역할 |
| `Features/Home` | `feature:main-tab` | 1:1 |
| `Features/CreditCardOCR` | `feature:ocr` | 1:1, 둘 다 온디바이스 |
| `Features/NotificationCenter` + `Service/KeywordAlarm` | `feature:alarm-center` | 1:1 |
| `Features/Login` + `API/{Login,SignUp,Account}API` | `feature:account` | Android 가 단일 feature, iOS 는 분화 |
| `App` target 내부 (`Benefit`, `Contacts`, `Wish`, `Startup`, `AD`, `Banner`) | `feature:benefit`, `feature:my-activities`, `feature:mypage`, `feature:service-home` (startup) | **iOS 는 아직 Feature 모듈화가 덜 됨**; Tuist Phase 마이그레이션 진행 중 (`docs/TUIST_PHASE*.md`) |

---

## 서버 연결 설정 (핵심)

### URL 주입 방식

iOS 는 Android 와 달리 **xcconfig / Info.plist 에 URL 을 심지 않는다.** 대신:

1. **`Projects/Core/Sources/Preference/Interface/ServerMode.swift`** 의 `enum ServerMode` (`local/cdev/rc/rc2/rc3/stage/live`) 가 런타임에 `AppPreference` 로부터 설정됨. (`ServerMode.swift:8-17`) — **FE1-854(2026-06-05)** 로 `dev = "DEV"` 케이스를 제거하고 DEV 전용 URL 을 CDEV URL 로 통합했다. Widget/UITests/ExampleEnvironment 기본값도 `.cdev` 로 일원화.
2. **`Projects/Core/Sources/Networking/Interface/APIDomain.swift`** 의 `enum APIDomain` (`publicApi / api / startupCommon / ad / analytics / service / platform(PlatformAPI) / searchAI / webOrigin / app`) 가 `preference.serverMode` 를 switch 해서 URL 을 반환한다 (`APIDomain.swift:48-191`).
3. `RequestBuilder(domain: .api, path: ..., method: ...)` 가 `APIDomain.urlString` 으로 baseURL 을 결정하고 `HTTPClient` 가 Alamofire `Session.request` 를 호출한다.

xcconfig 는 **PROVISIONING_PROFILE_SPECIFIER, DEBUG 플래그, AppIcon 세트 이름** 만 환경별로 다르다. URL 은 포함되지 않는다.

### 환경별 URL 전체 표 (iOS)

출처: `Projects/Core/Sources/Networking/Interface/APIDomain.swift:48-191`

| `APIDomain` | Live | Stage | RC2 | Dev | 용도 (upstream) |
| --- | --- | --- | --- | --- | --- |
| `.api` / `.startupCommon` | `preference.getDomain()` (= `https://www.wadiz.kr` 등) | 동일 | `https://rc2.wadiz.kr` | `https://dev.wadiz.kr` | **메인 모놀리식 `api.wadiz.kr`** (계정/로그인/찜/알림/CatchUp/주소록/쿠폰/스타트업 전부) |
| `.publicApi` | `https://public-api.wadiz.kr` | 동일 | `https://public-api-rc.wadiz.kr` | `https://public-api-dev.wadiz.kr` | public-api (배너/디스플레이 광고/featured) |
| `.ad` | `https://service.wadiz.kr/api/v1/ad/host` | 동일 | `https://rc2-service.wadiz.kr/api/v1/ad/host` | `https://dev-service.wadiz.kr/api/v1/ad/host` | 홈 KeyVisual/Wad Sections |
| `.analytics` | `https://analytics.wadiz.kr` (KR) / `https://analytics.wadiz.ai` (글로벌) | 동일 | `https://rc-analytics.{domain}` | `https://dev-analytics.{domain}` | **와디태그(Waditag) V1/V2** |
| `.service` | `https://service.wadiz.kr` | 동일 | `https://rc2-service.wadiz.kr` | `https://dev-service.wadiz.kr` | 검색/펀딩소프트/프리오더/카테고리/스토어 검색 |
| `.platform(.main2)` | `https://platform.wadiz.kr` | `https://stage-platform.wadiz.kr` (**main만**) | `https://rc2-platform.wadizcorp.net` | `https://dev-platform.wadizcorp.net` | `/main2/…` 홈/퀵메뉴/랭킹/추천 |
| `.platform(.inbox)` / `.keyword` / `.notiChannel` / `.push` / `.wish` / `.activities` / `.global` | 동일 (stage 에서도 `platform.wadiz.kr`) | 동일 | RC 계열 `wadizcorp.net` | Dev 계열 | 각 플랫폼 MSA |
| `.searchAI` | `https://searchai.wadiz.kr` | 동일 | `https://rc-api.dev-searchai.wadizdata.team` | `https://api.dev-searchai.wadizdata.team` | 연관 키워드 AI |
| `.webOrigin` | `https://www.wadiz.kr` / `.ai` | `https://stage.wadiz.kr` | `https://rc2.wadiz.kr` | `https://dev.wadiz.kr` | 분석 이벤트 `Origin` 헤더용 |
| `.app` | `https://app.wadiz.kr` | 동일 | `https://app-rc2.wadizcorp.net` | `https://app-dev.wadizcorp.net` | **앱 전용 BFF** (설정 탭 Server-Driven 등) |

> Android 와 완전히 동일한 백엔드 구성. 단지 iOS 는 `.webOrigin` / `.startupCommon` / `.app` 의 네이밍이 다르고, `.publicApi` 를 분리한 점이 차이.

### 인증 (Interceptor / Adapter)

**`Projects/Core/Sources/Networking/Feature/WadizRequestInterceptorImpl.swift`** 가 Alamofire `RequestInterceptor` (=`RequestAdapter`+`RequestRetrier`) 를 구현:

1. `adapt(_:for:completion:)` — `UserDefaults` 의 `sessionId`, `UserCredentialProviding` 의 `authKey`/`userID`, `LocaleProviding` 의 `wadiz-language`/`wadiz-country` 헤더 자동 주입. `timeoutInterval = 10s`. (`WadizRequestInterceptorImpl.swift:30-57`)
2. `retry(_:for:dueTo:completion:)` — `retryLimit = 3`, `retryDelay = 2s`.
   - `NetworkError.unauthorized` → `logoutCallback()` 호출 (세션 초기화 후 로그인 플로우 복귀)
   - `NetworkError.preconditionRequired` → `refreshCallback()` async 호출 (유저 정보 refresh) → 성공 시 `retryWithDelay(2)`, 실패 시 `doNotRetry`
   - `invalidEmptyResponse`, `sessionTaskFailed`, 기타 → `doNotRetry`
3. `credentialProvider: UserCredentialProviding?` + `localeProvider: LocaleProviding?` 를 `NetworkingAssembly.swift:22` 에서 Swinject 로 주입. `nonisolated(unsafe)` 패턴 (strict concurrency 진행 중).

`UserCredential` 프로토콜은 `authKey`, `userID` 필드 (`UserCredential.swift:10-13`). 실제 저장은 **KeychainSwift 20.0.0** 기반 (`Tuist/Package.swift:50` + `Service/User`).

### 세션 / 로그아웃 콜백
- `logoutCallback` / `refreshCallback` 은 **`Projects/Core/Sources/Networking/Feature/NetworkingAssembly.swift`** 에서 앱 상위로 연결. 세션 끊김 시 AppCoordinator 가 루트를 `LoginCoordinator` 로 재설정.
- 쿠키 기반 웹뷰 동기화: `Projects/App/Sources/AppCoordinator/AppCoordinator+Setting.swift` (birthday 설정 등), `Service/User` 내부에서 `waccount/auth/request/token` 호출.

### 로깅 / 에러
- **Pulse 2.1.5** (`LoggerMonitor.swift`, `Networking/Feature`) — Alamofire `EventMonitor` 로 모든 요청/응답을 Pulse Store 에 저장. Debug 빌드에서 shake 제스처로 `pulseUI` 뷰어 호출 가능.
- **CocoaLumberjack** — 파일/콘솔 로깅.
- `NetworkError` (`Networking/Interface/NetworkError.swift`) 에 `.unauthorized`, `.preconditionRequired`, `.invalidEmptyResponse` 등 정의. 응답 validation 은 Alamofire `validate` 뒤 `.responseValidationFailed(reason: .customValidationFailed(error: NetworkError.xxx))` 로 매핑.

---

## 네트워크 레이어

- **`HTTPClient`** (interface `Projects/Core/Sources/Networking/Interface/HTTPClient.swift`, impl `…/Feature/HTTPClientImpl.swift`) — `func request<T: Decodable>(request: URLRequest, type: T.Type) async throws -> T`. 내부적으로 Alamofire `Session` + `WadizRequestInterceptor` 사용.
- **`RequestBuilder`** (`Networking/Interface/RequestBuilder.swift`) — `domain/path/method/headers` + `.set(queryName:queryValue:)` chaining + `.build() -> URLRequest`.
- **Endpoint 구조** — 별도의 `enum Endpoint` 타입은 사용하지 않고, 각 `…API.swift` 파일 내부에서 `let path = "..."` 로 직접 지정한다. Moya TargetType 미사용.
- **DTO → Domain 변환** — 각 feature 내부 `Data/…Mapper.swift` 파일 (예: `Features/Home/Sources/Data/HomeMapper.swift`). API 모듈은 **DTO(Decodable)** 만 제공하고, Feature/Service 레이어의 Repository 가 Domain 모델로 변환.
- **Assembly 패턴** — 각 모듈 `…Assembly.swift` 가 Swinject `Container` 에 프로토콜 등록. `DIContainer.shared.resolver.resolve(X.self)` 로 해소.

---

## 기능별 API 호출 매핑 (핵심)

`Grep "let path = \"...\""` + `RequestBuilder(domain: ...)` 전수조사로 추출한 **대표 55+ 엔드포인트**. 도메인 열은 `APIDomain` case.

### 로그인 / 회원가입 (`Features/Login`, `API/LoginAPI`, `API/SignUpAPI`, `Features/Email`, `Features/PasswordSetting`, `Features/ConfirmPassword`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `LoginAPI` | `POST /api/v4/login/email` | `.api` | 이메일 로그인 | 로그인 submit. `LoginAPIImpl.swift:18,24` |
| `LoginAPI` | `POST /api/v4/login/social` | `.api` | 소셜 로그인 | 소셜 버튼 탭. `LoginAPIImpl.swift:44,47` |
| `LoginAPI` | `POST /api/login/logout` | `.api` | 로그아웃 | 설정 > 로그아웃 / 세션 만료. `LoginAPIImpl.swift:68,69` |
| `SignUpAPI` | `POST /api/v4/sign-up/social` | `.api` | 소셜 회원가입 | 소셜 신규 유저 분기. `SignUpAPIImpl.swift:22,25` |
| `SignUpAPI` | `POST /api/v4/sign-up/social/link` | `.api` | 기존 계정 소셜 연동 가입 | 소셜 로그인 기존 계정 분기. `SignUpAPIImpl.swift:46,52` |
| `SignUpAPI` | `POST /api/v4/sign-up/email` | `.api` | 이메일 회원가입 | 회원가입 submit. `SignUpAPIImpl.swift:72,89` |
| `SignUpAPI` | `POST /api/v4/sign-up/email/code` / `/verification` | `.api` | 이메일 코드 발급/검증 | 회원가입 이메일 확인. `SignUpAPIImpl.swift:109,133` |
| `SignUpAPI` | `GET /web/v3/terms/signup` | `.api` | 약관 리스트 | 회원가입 약관 단계. `SignUpAPIImpl.swift:157,158` |
| `Login/Common` | `POST /api/v4/check/email` | `.api` | 이메일 존재 여부 | 로그인 1단계. `CheckAPI.swift:24,27` |
| `Features/Email` | `POST /api/v3/account/email/code` | `.api` | 이메일 변경 인증코드 | 이메일 수정 화면. `ModifyEmailAPI.swift:21,25` |
| `Features/Email` | `PUT /api/v3/account/email` | `.api` | 이메일 변경 | 동일. `ModifyEmailAPI.swift:49,52` |
| `PasswordSetting` | `POST /api/v3/account/password` / `PUT /api/v3/account/password` | `.api` | 비밀번호 설정/변경 | 비밀번호 설정 화면. `PasswordSettingAPI.swift:25,55` |
| `ConfirmPassword` | `POST /api/v3/account/password/verification` | `.api` | 비밀번호 확인 | 민감 작업 전 모달. `ConfirmPasswordAPI.swift:26` |

### 계정 / 설정 (`Features/Setting`, `API/AccountAPI`, `Features/ChangeTimeZone`, `Service/User`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `AccountAPI` | `GET /api/v3/account/info/refresh` | `.api` | 세션 refresh | `WadizRequestInterceptor.refreshCallback` 및 사용자 정보 수정 후. `AccountAPIImpl.swift:15,16` |
| `AccountAPI` | `POST /api/waccount/auth/request/token` | `.api` | 세션 토큰 발급 | 앱 시작/웹뷰 동기화. `AccountAPIImpl.swift:25,42` |
| `AccountAPI` | `POST /api/v3/account/sns-links/{provider}` | `.api` | SNS 연동 | 설정 > SNS 연동. `AccountAPIImpl.swift:56,59` |
| `AccountAPI` | `PUT /api/v3/account/sns-links/{provider}` | `.api` | SNS 재연동 | 설정 > SNS. `AccountAPIImpl.swift:71,74` |
| `AccountAPI` | `DELETE /api/v3/account/sns-links/{provider}` | `.api` | SNS 연동 해제 | 설정 > SNS. `AccountAPIImpl.swift:86,88` |
| `Features/Setting/SettingHome` | `GET /api/v3/account` | `.api` | 내 계정 정보 | 설정 홈 진입. `SettingAPI.swift:25,30` |
| `Features/Setting/SettingHome` | `GET /api/v3/account/sns-links` | `.api` | 연동된 SNS 목록 | 설정 홈. `SettingAPI.swift:36,41` |
| `Features/Setting/SettingHome` | `POST /api/v3/account/profile-image` / `DELETE /api/v3/account/profile-image` | `.api` | 프로필 이미지 업/다운 | 프로필 편집. `SettingAPI.swift:50,62,71,77` |
| `Features/Setting/Nickname` | `PUT /api/v3/account/nickname` | `.api` | 닉네임 변경 | 설정 > 닉네임. `EditNicknameAPI.swift:24,29` |
| `Features/Setting/PhoneNumber` | `GET /api/v3/account/phone-number`, `PUT /api/v3/account/phone-number`, `POST /api/v3/account/phone-number/code` | `.api` | 전화번호 조회/변경/인증코드 | 설정 > 전화번호. `PhoneNumberAPI.swift:26,38,66` |
| `Features/ChangeTimeZone` | `GET /api/v3/time-zones`, `GET/PUT /api/v3/user/time-zone`, `PUT /api/v3/user/time-zone/auto` | `.api` | 타임존 조회/변경/자동설정 | 설정 > 타임존. `TimeZoneAPI.swift:25,48,71,96` |
| `Service/User` | `GET /api/v3/user/location`, `PUT /api/v3/user/location` | `.api` | 국가/지역 조회/변경 | 나라/지역 변경. `UserAPI.swift:22,29` |
| `Features/Setting/NotificationSetting` | `GET /api/v3/user/settings/terms/service/{code}`, `GET/PUT /api/v3/user/settings/terms/marketing/{code}` | `.api` | 서비스/마케팅 약관 동의 | 알림 설정. `NotificationAPI.swift:26,34,42` |
| `App/Account/SetMarketingAlarm` | `POST api/v2/terms/marketing/consent/services`, `PUT api/v2/terms/marketing/consent/services/{service}` | `.api` | 통합 마케팅 동의 | 알림 수신 동의 화면. `SetAlarmAPI.swift:42,92` |
| `App/Account/SetMarketingAlarm` + `Features/Setting/NotificationSetting` | `POST noti-channel/v2/marketingconsents`, `GET noti-channel/v2/marketingconsents` | `.platform(.notiChannel)` | 채널별 마케팅 동의 | 동일. `SetAlarmAPI.swift:66,119`, `NotificationAPI.swift:58,87` |
| `App/Account/TermsAPI` | `GET api/v2/terms/accepter` | `.api` | 약관 동의자 조회 | 설정 > 약관. `TermsAPI.swift:63` |

### 홈 / 서비스홈 (`Features/Home`, `API/Main2API`, `Features/ServiceHome`, `App/Sources/Banner`, `App/Sources/AD`, `App/Sources/Exhibition`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `Main2API` | `GET /main2/api/v9/main` 또는 `/main2/api/v10/main` | `.platform(.main2)` | 홈 메인 큐레이션 (추천 A/B) | 홈 탭 로드/Pull-to-refresh. **FE1-698(2026-05~29)** 로 추천 A/B 실험군이 내려오면 `v10`, 아니면 기존 `v9` 폴백. 실험 참여 시 `X-Device-Type: IOS_APP` + `X-Experiment: {experimentName}_{experimentGroup}` 헤더 동봉. `Main2APIImpl.swift:15` |
| `Main2API` | `GET /main2/api/v{version}/my-wadiz` | `.platform(.main2)` | 홈 하단 마이와디즈 요약 | 홈 스크롤. `Main2APIImpl.swift:40-45` |
| `Main2API` | `GET /main2/api/v1/recommendation/item` | `.platform(.main2)` | 연관 추천 | 상세 진입 후 추천. `Main2APIImpl.swift:49-53` |
| `Main2API` | `GET /main2/api/v1/quickmenu?id={id}` | `.platform(.main2)` | 퀵메뉴 | 홈 진입. `Main2APIImpl.swift:59-66` |
| `Main2API` | `GET /main2/api/v1/pc/ranking/store` | `.platform(.main2)` | 스토어 랭킹 | 서비스홈/홈. `Main2APIImpl.swift:70-73` |
| `Main2API` | `GET /main2/api/v1/banner/key-visual/{type}` | `.platform(.main2)` | 홈 키비주얼 배너 | 홈 상단. `Main2APIImpl.swift:77-80` |
| `App/Banner` | `GET /main/display-ads/event`, `GET /main/display-ads/marketing` | `.publicApi` | 디스플레이 배너 | 홈/이벤트 섹션. `BannerAPI.swift:50,63` |
| `App/Exhibition` | `GET /main/featured/reward` | `.publicApi` | 리워드 기획전 | 기획전 탭. `ExhibitionAPI.swift:25,28` |
| `App/AD/AdService` | `GET /keyvisual`, `GET /wad/sections/{code}`, `GET /event` | `.ad` / `.service` / `.ad` | 광고 키비주얼 / 섹션 / 이벤트 | 홈/서비스홈. `AdService.swift:89,101,113` |
| `Features/ServiceHome/ServiceHomeAdBanner` | `GET /keyvisual`, `GET /wad/sections/{sectionCode}` | `.ad` | 서비스홈 배너 | 리워드 홈 섹션. `ServiceHomeAdBannerAPI.swift:20,30` |
| `Features/ServiceHome/Store` | `GET /wish/api/v1/wish/discount` | `.platform(.wish)` | 찜 할인 프로젝트 | 스토어 홈 섹션. `StoreAPI.swift:22` |
| `App/ServiceHome/Preorder` | `POST api/search/v2/preorder` | `.service` | 프리오더 검색 | 프리오더 탭. `PreorderAPI.swift:26,35` |
| `App/Protocol/CategoryAPI` | `GET api/search/categories`, `GET api/search/v3/categories/service-home` | `.service` | 카테고리 | 카테고리 탭. `CategoryAPI.swift:29,68` |

### 검색 (`API/SearchAPI`, `Features/Search`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `SearchAPI` | `GET api/search/v2/popular/keyword` | `.service` | 인기 키워드 | 검색 초기. `SearchAPIImpl.swift:16` |
| `SearchAPI` | `GET api/search/v3/home` | `.service` | 검색홈 | 검색 탭. `SearchAPIImpl.swift:23` |
| `SearchAPI` | `POST api/search/v3/integrate` | `.service` | 통합 검색 | 검색어 submit. `SearchAPIImpl.swift:32` |
| `SearchAPI` | `POST api/search/v2/integrate/purchased` | `.service` | 구매한 상품 내 검색 | 내 활동 > 검색. `SearchAPIImpl.swift:45` |
| `SearchAPI` | `POST api/search/v2/funding`, `POST api/search/v2/fundingSoon` | `.service` | 펀딩/오픈예정 검색 | 탭별 필터. `SearchAPIImpl.swift:55,89` |
| `SearchAPI` | `GET api/search/categories`, `GET api/search/v3/categories/service-home` | `.service` | 카테고리 | 카테고리 탭. `SearchAPIImpl.swift:64,79` |
| `SearchAPI` | `POST api/search/store` | `.service` | 스토어 검색 | 스토어 검색 탭. `SearchAPIImpl.swift:99` |
| `Features/Search/Result` | `GET /related-keyword` | `.searchAI` | 연관 검색어 AI | 검색어 입력 중. `SearchResultRepositoryImpl.swift:144,146` |
| `Features/Search/Result/CouponAPI` | `GET /web/reward/api/coupons/templates/types/download` | `.api` | 쿠폰 리스트 | 결과 내 쿠폰 섹션. `CouponAPI.swift:21` |
| `Features/Search/Result/CouponAPI` | `POST /web/reward/api/coupons/transactions/types/redeem/issue-types/download` | `.api` | 쿠폰 발급 | 쿠폰 받기. `CouponAPI.swift:37` |

### 찜 / 활동 / 마이와디즈 (`Service/Activity`, `App/Wish`, `App/Benefit`, `Features/MyActivity`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `Service/Activity` | `POST /api/funding/wishes`, `DELETE /api/funding/wishes` | `.api` | 찜 추가/삭제 (service) | 하트 버튼. `ActivityAPI.swift:29,57` |
| `Service/Activity` | `GET /web/apip/funding/campaigns/{id}/pre-reservation-info` | `.api` | 오픈예정 사전예약 정보 | 상세. `ActivityAPI.swift:70` |
| `Service/Activity` | `POST /user-activity/api/v1/wish/projects` | `.platform(.activities)` | 찜 프로젝트 플랫폼 동기화 | 찜 리스트 새로고침. `ActivityAPI.swift:93` |
| `Service/Activity` | `POST /api/funding/comingsoons/{id}/applicants`, `DELETE /api/funding/comingsoons/{id}/applicants` | `.api` | 오픈예정 알림 신청/해제 | "알림받기" 토글. `ActivityAPI.swift:119,137` |
| `App/Wish/WishesAPI` | `POST /api/funding/wishes`, `DELETE /api/funding/wishes` | `.api` | 찜 (App 레이어 중복) | 홈/리스트 하트. `WishesAPI.swift:33,49` |
| `App/Wish/WishesAPI` | `POST /api/wcampaign/comingsoon/applicant`, `POST /api/wcampaign/comingsoon/applicant-cancel` | `.api` | 오픈예정 알림 (레거시) | 레거시 화면. `WishesAPI.swift:78,94` |
| `App/Wish/WishesAPI` | `GET /api/v1/searcher/wish/project/endingsoon` | `.service` | 찜 마감임박 | GNB 뱃지. `WishesAPI.swift:106,109` |
| `App/Wish/WishesAPI` | `GET /api/funding/wishes/my/qty` | `.api` | 내 찜 개수 | 탭 뱃지. `WishesAPI.swift:120,123` |
| `App/Wish/WishesAPI` | `GET /web/apip/funding/campaigns/{id}/pre-reservation-info` | `.api` | 사전예약 정보 (레거시 위치) | 상세. `WishesAPI.swift:132` |
| `Features/MyActivity/Wish` | `GET /api/activities/wishes/search` | `.api` | 내 찜 검색 | 내 활동 > 찜 > 검색. `WishSearchAPI.swift:21` |
| `App/Benefit/BenefitAPI` | `GET /api/mywadiz/account/supporter` | `.api` | 마이와디즈 서포터 요약 | 마이와디즈 진입. `BenefitAPI.swift:238,241` |
| `App/Benefit/BenefitAPI` | `GET /api/v2/membership` | `.api` | 내 멤버십 | 마이와디즈. `BenefitAPI.swift:269,271` |

### 혜택 / 쿠폰 (`App/Benefit`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `App/Benefit/BenefitAPI` | `GET /web/apip/funding/event/{couponName}/participant` | `.api` | 쿠폰 발급 여부 | 쿠폰 페이지 진입. `BenefitAPI.swift:63,65` |
| `App/Benefit/BenefitAPI` | `POST /web/apip/funding/event/{couponType}/{path}` | `.api` | 쿠폰 발급 | "쿠폰 받기". `BenefitAPI.swift:202,204` |
| `App/Benefit/BenefitAPI` | `GET /web/reward/api/comingsoons` | `.api` | 체험단 리스트 | 체험단 탭. `BenefitAPI.swift:90,92` |
| `App/Benefit/BenefitAPI` | `GET api/search/funding/categories` | `.service` | 펀딩 카테고리 | 혜택 필터. `BenefitAPI.swift:108,109` |
| `App/Benefit/BenefitAPI` | `POST /web/reward/api/coupons/transactions/types/redeem/issue-types/download` | `.api` | 한정 쿠폰 발급 | 한정 쿠폰 받기. `BenefitAPI.swift:124,127` |
| `App/Benefit/BenefitAPI` | `GET /web/reward/api/coupons/templates/types/download` (2곳) | `.api` | 쿠폰 템플릿 리스트 | 혜택홈. `BenefitAPI.swift:140,178` |

### 알림 / 키워드 알람 (`Features/NotificationCenter`, `Features/SetKeywordAlarm`, `Service/KeywordAlarm`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `Features/NotificationCenter` | `GET inbox/v6/messages/` | `.platform(.inbox)` | 알림 목록 | 알림 탭. `NotificationCenterAPI.swift:37` |
| `Features/NotificationCenter` | `PUT inbox/v4/messages/read-all` | `.platform(.inbox)` | 전체 읽음 | "모두 읽음". `NotificationCenterAPI.swift:61` |
| `Features/NotificationCenter` | `GET inbox/v4/messages/count-unread` | `.platform(.inbox)` | 미확인 카운트 | GNB 벨. `NotificationCenterAPI.swift:76` |
| `App/Protocol/ProtocolNotification` | `GET inbox/v4/messages/count-unread` | `.platform(.inbox)` | 미확인 카운트 (레거시) | 동일. `ProtocolNotification.swift:25,32` |
| `Features/NotificationCenter` | `GET /api/app/updateApp` | `.api` | 강제 업데이트 체크 | 앱 시작/알림 탭 (중복). `NotificationCenterAPI.swift:125` |
| `Features/SetKeywordAlarm` / `Service/KeywordAlarm` | `GET/POST/DELETE /keyword/api/v1/info-keywords` | `.platform(.keyword)` | 키워드 알람 CRUD | 키워드 알람 설정. `SetKeywordAlarmAPI.swift:62,74,90`, `KeywordAlarmRepositoryImpl.swift:35,47,80` |
| `Features/SetKeywordAlarm` | `GET/POST /keyword/api/v1/info-keywords/push-toggle` | `.platform(.keyword)` | 키워드 알람 푸시 토글 | 스위치 토글. `SetKeywordAlarmAPI.swift:42,50` |
| `Service/RecentKeyword` | `POST /keyword/api/v1/keywords` | `.platform(.keyword)` | 최근 검색어 플랫폼 저장 | 검색 submit. `RecentKeywordRepositoryImpl.swift:55` |

### CatchUp (`Features/CatchUp`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `Features/CatchUp/API` | `GET /api/v1/catchup/today`, `POST /api/v1/catchup/today`, `GET /api/v1/catchup/today/status` | `.api` | 오늘의 픽 조회/액션/상태 | CatchUp 홈 / 스와이프. `CatchUpAPI.swift:19,26,33` |
| `Features/CatchUp/API` | `GET/PUT /api/v1/catchup/notification` | `.api` | CatchUp 알림 조회/변경 | 알림 토글. `CatchUpAPI.swift:43,50` |

### 스토어 / 메이커 / 플러스 / 스타트업 (`App/ServiceHome/Store`, `App/Plus`, `App/NewOpen`, `App/Startup`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `App/ServiceHome/Store` | `GET api/store/orders/my/qty` | `.api` | 내 스토어 주문 수 | 스토어 홈. `StoreAPI.swift:26,28` |
| `Extensions/WadizWidget/StoreProjectAPI` | `GET /api/store/projects/my` | `.api` | 내 스토어 프로젝트 (위젯) | 홈스크린 위젯. `StoreProjectAPI.swift:13` |
| `Extensions/WadizWidget/StoreProjectAPI` | `GET /api/store/studio/orders/aggregation` | `.api` | 스토어 스튜디오 주문 집계 (위젯) | 홈스크린 위젯. `StoreProjectAPI.swift:23` |
| `App/Plus/NewProjectOpenAPI` | `GET /api/maker/mywadiz/pages` | `.api` | 메이커 마이와디즈 페이지 | 메이커 홈. `NewProjectOpenAPI.swift:27,28` |
| `App/Plus/NewProjectOpenAPI` | `GET /web/apip/funding/v2/bottom-sheet/data` | `.api` | 메이커 모드 바텀시트 데이터 | 메이커 모드 진입. `NewProjectOpenAPI.swift:34,35` |
| `App/NewOpen/ProjectOpenAPI` | `GET /web/apip/funding/v2/bottom-sheet/data` | `.api` | (중복) 프로젝트 오픈 바텀시트 | "프로젝트 열기". `ProjectOpenAPI.swift:24,27` |
| `Features/MyWadizModeSelect` | `GET /web/apip/funding/v2/bottom-sheet/data` | `.api` | 서포터/메이커 모드 전환 데이터 | MyWadiz 모드 선택 모달. `MyWadizModeAPI.swift:25` |
| `App/Startup/StartupAPI` | `POST /api/startup/main` | `.startupCommon` | 스타트업 메인 | 스타트업 탭. `StartupAPI.swift:37,119` |
| `App/Startup/StartupAPI` | `GET /api/startup/collection/bannerList` | `.startupCommon` | 스타트업 배너 | 스타트업 탭. `StartupAPI.swift:128,131` |
| `App/Startup/StartupAPI` | `GET /api/startup/corporation/connect` | `.startupCommon` | 법인 연결 | 법인 설정. `StartupAPI.swift:139,160` |
| `App/Startup/StartupCommonAPI` | `GET /api/startup/common/codeMap`, `GET /api/startup/common/questionExampleList`, `GET /api/startup/common/currentBannerList` | `.startupCommon` | 공통 코드/예시/현재 배너 | 스타트업 탭 초기. `StartupCommonAPI.swift:28,44,61` |

### 소셜 / 주소록 / 팔로우 (`API/SocialAPI`, `App/Contacts`, `App/NativeBase/Friend`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `SocialAPI` | `GET /api/v3/social/recommendation/kakao` | `.api` | 카카오 친구 추천 | 팔로우 추천. `SocialAPIImpl.swift:22` |
| `SocialAPI` | `POST /api/v3/social/follows` | `.api` | 다중 팔로우 | "모두 팔로우". `SocialAPIImpl.swift:44` |
| `Service/FriendActivity` | `GET /api/v2/social/recommendation/user/kakao/has-user` | `.api` | 카카오 친구 유저 존재 여부 | 친구 추천 진입. `FriendAPI.swift:21,23` |
| `App/NativeBase/Friend` | `GET /api/friends/activities` | `.service` | 친구 활동 피드 | GNB 배지/친구탭. `FriendAPI.swift:17,19` |
| `App/Contacts/ContactsAPI` | `GET /api/v2/social/contacts/information` | `.api` | 주소록 정보 | 주소록 동의 전 화면. `ContactsAPI.swift:20` |
| `App/Contacts/ContactsAPI` | `PUT /api/v2/social/contacts/sync-allow` | `.api` | 주소록 동기화 동의 | 동의 토글. `ContactsAPI.swift:40` |
| `App/Contacts/ContactsAPI` | `PUT /api/v2/social/contacts`, `DELETE /api/v2/social/contacts` | `.api` | 주소록 업로드/삭제 | 동기화/해제. `ContactsAPI.swift:98,124` |
| `App/Contacts/ContactsAPI` | `GET /api/v2/social/recommendation/user/contacts/count`, `GET /api/v2/social/recommendation/user/contacts/user-info` | `.api` | 주소록 기반 추천 | 친구 추천. `ContactsAPI.swift:145,167` |
| `App/Contacts/ContactsAPI` | `PUT /api/v2/social/recommendation/user/allow-info`, `GET /api/v2/social/recommendation/user/allow-info` | `.api` | 추천 허용 정보 | 설정. `ContactsAPI.swift:62,79` |
| `App/Contacts/ContactsAPI` | `POST /api/v2/social/follower/follow/multi` | `.api` | 다중 팔로우 (레거시 경로) | 친구 추천 "전체 팔로우". `ContactsAPI.swift:178` |

### 앱 공통 / SMS / 로케일 / 분석 / 설정 탭

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `Service/SmsAuth` / `App/Protocol/ProtocolFTAccountConfirm` | `POST /api/ftaccountConfirm/requestSendUserAuthSms`, `POST /api/ftaccountConfirm/requestUserSmsConfirm` | `.api` | SMS 인증 요청/확인 | 법인 인증/계정 보호. `SmsAuthAPI.swift:21,41`, `ProtocolFTAccountConfirm.swift:45,81` |
| `App/Protocol/AppAPI` | `POST /api/app/updateApp` | `.api` | 앱 업데이트 체크/보고 | 앱 시작. `AppAPI.swift:43,47` |
| `Service/Locale` | `GET /web/v1/countries` | `.api` | 국가 리스트 | 국가 설정. `LocaleRepositoryImpl.swift:58,78` |
| `Service/Locale` | `GET /global/exchange-rates/{country}` | `.platform(.global)` | 환율 | 글로벌 결제 화면. `LocaleRepositoryImpl.swift:95` |
| `Service/Analytics/Waditag` | `GET /v2/add`, `POST /v2/add`, `GET /add`, `POST /add` | `.analytics` | **와디태그** V1/V2 (ScreenView/Click) | 스크린 진입/이벤트. `WaditagAnalyticsServiceImpl.swift:53,89,148,206` |
| `AppSettingAPI` | `GET /api/v1/settings` | `.app` | **설정 탭 Server-Driven 구성** | 설정 탭 진입. `AppSettingAPIImpl.swift:15,16` |
| `Features/FloatingButtons` | `GET /api/maker/mywadiz/pages` | `.api` | 플로팅 메이커 버튼 표시 조건 | 화면 공통 floating. `FloatingButtonAPIImpl.swift:15` |
| `App/AppCoordinator/Setting` | `GET /web/mywadiz/settings/birthday` (웹뷰) | `.webOrigin` | 생년월일 설정 페이지 URL | 설정 > 생년월일. `AppCoordinator+Setting.swift:117` |

---

## 주요 화면 흐름 분석

### 1) 홈 / 피드 (`Features/Home`)
- **파일**: `Projects/Features/Home/Sources/Presentation/HomeViewController.swift`, `HomeViewModel.swift`, `Data/HomeRepositoryImpl.swift`, `Data/HomeMapper.swift`.
- 트리거: 루트 `AppCoordinator` 가 `TabCoordinator` → `HomeCoordinator` → `HomeViewController` 생성. 최초 `viewDidLoad` → `viewModel.fetch()`.
- `HomeViewModel` (MVVM, Combine/`AnyPublisher` 또는 async) → `HomeRepositoryImpl.fetchMain(...)`
- Repository → `Main2API.fetchMain(MainRequest(header: encUserId, variant), query: …)` → `RequestBuilder(domain: .platform(.main2), path: "/main2/api/v9/main", method: .get)` + `set(queryName:)` chain → `HTTPClient.request` (`Interceptor adapt/retry`) → `MainResponse`
- `HomeMapper` 가 `MainResponse` → `HomeSectionModel[]` 변환 → `HomeViewController` 의 `UICollectionView` (IGListKit) 섹션 렌더
- 병렬 호출: `fetchMainQuickMenu`, `fetchMainStoreRanking`, `fetchKeyVisualBanner`, `AdService.fetchKeyVisual`, `MainRepositoryImpl.fetchMainMyWadiz`

### 2) 프로젝트 상세 / 결제 (서포팅)
- iOS 도 **상세/결제 페이지는 네이티브가 아닌 WKWebView**. 진입 시 `AccountAPI.requestToken()` (`POST /api/waccount/auth/request/token`) → 쿠키 동기화 → `webOrigin + /web/campaign/detail/{id}` 로 `WKWebView` 로드.
- JS ↔ Native 브릿지: 결제 완료, 찜 토글, 카드 OCR 요청 등. 네이티브 복귀 시 `WishesAPI.add/delete`, `Service/Activity.fetchWishList()` 로 동기화.
- Remote Config 로 URL 패턴 가드 (`Projects/App/SupportingFiles/remote_config_defaults.plist` 에 `wadiz.kr/web/campaign/detail/{arg_0}` 등 정의).
- **공통 웹뷰 → 네이티브 상세 랜딩 (FE1-735, 2026-05-27)**: 일반 웹뷰(`BaseWebViewController`) 내에서 펀딩/오픈예정 상세 URL 로 이동하면, 웹으로 띄우지 않고 `ProjectDetailViewController`(펀딩/오픈예정) 또는 `ProjectWebViewController`(스토어) 네이티브 화면으로 랜딩. URL 판별은 `ProjectDetailURLMatcher` + `tryRouteDetailURLToNative` 헬퍼, `WebViewDependency` 에 `navigator` 주입.
- **스토어 → 펀딩 진입 일관성 (FE1-781, 2026-05-29)**: 스토어 통합 `projectId` Matcher 를 `ProjectDetailURLMatcher` 에 추가하고, 스토어 상세 URL 진입도 `ProjectDetailViewController` 로 게이트(`NavigationMap+WebView`)해 펀딩/스토어 양쪽이 동일한 네이티브 헤더 상태·검증 경로를 타도록 통일.

### 3) 로그인 (`Features/Login`)
- 트리거: `LoginHomeViewController` → 이메일 로그인 or 소셜 버튼
- `LoginHomeViewModel` (`Projects/Features/Login/Sources/LoginHome/Presentation/LoginHomeViewModel.swift`) → `LoginAPI.loginEmail(path: "/api/v4/login/email", body)`
- 응답 후 `UserService` (`Projects/Service/Sources/User`) 가 `UserCredential` (KeychainSwift) + `UserDefaults sessionId` 저장 → Swinject 에서 credentialProvider 갱신 → 다음 요청부터 `WadizRequestInterceptor.adapt` 가 `authKey/userId/sessionId` 헤더 자동 추가
- 후속: `AccountAPI.userRefresh` (`/api/v3/account/info/refresh`), `AccountAPI.requestToken`, `Main2API.fetchMain` (홈 진입)
- 실패 시 `NetworkError.unauthorized` → `logoutCallback()` → AppCoordinator 가 `LoginCoordinator` 로 루트 복귀

### 4) 서포팅 (결제)
- 위 (2) 와 동일하게 **WKWebView 경유**. 네이티브 Alamofire 경로 없음.
- 오픈예정은 `Service/Activity.postFundingSoonNotification` (`POST /api/funding/comingsoons/{id}/applicants`) 로 알림 신청 → 오픈 시 푸시.
- Credit Card OCR: 웹뷰에서 `presentCreditCardOCR` 브릿지 → `Features/CreditCardOCR.CreditCardOCRHostingController` 표시.

### 5) 신용카드 OCR (`Features/CreditCardOCR`)
- 트리거: 결제 웹뷰 내부 "카드 스캔" 버튼 → 네이티브 브릿지 → `CreditCardOCRAssembly` 로 `HostingController` (SwiftUI) 띄움
- `CameraManager.swift` → `AVCaptureSession` + **Vision `VNRecognizeTextRequest`** (온디바이스)
- `CreditCardRecognitionService.swift` 에서 Luhn 검증 + 만료일 파싱 → `CreditCardOCRViewModel.didRecognize(CardInfo)` → dismiss → 웹뷰로 결과 전달
- 서버 호출 **없음**. 권한: `NSCameraUsageDescription` (i18n.json `app_usage_modal.content.camera_message`). (`CLAUDE.md:154`)

---

## 빌드·배포

### Tuist
- **버전**: Tuist `4.113.1` (`.tuist-version`)
- Workspace `wadiz.xcworkspace` + `Projects/App/wadiz.xcodeproj` 생성은 `tuist generate` 로만. Xcode 프로젝트 파일은 레포에 커밋 X.
- `Tuist.swift:5` 로 Xcode 26.0 까지 호환 지정.
- `Tuist/ProjectDescriptionHelpers/TargetDependency+Templates.swift` 에 `.shared`, `.model`, `.networking`, `.preference`, `.home`, `.login`, `.main1API`, `.main2API` 등 공통 의존 매크로 정의.

### Configurations & xcconfig
- `Debug` (Dev scheme), `QA` (QA scheme), `Release` (Release scheme).
- xcconfig: `Base.xcconfig`, `Dev.xcconfig`, `QA.xcconfig`, `Release.xcconfig` 위치 `Projects/App/SupportingFiles/Configuration/`.
  - Dev: `Info_Dev.plist`, `wadiz_dev.entitlements`, `Apple Development`, profile `wadiz develop`, Swift flags `-DDEBUG`, Combine weak link (`Dev.xcconfig:1-27`)
  - Release: `Info.plist`, `wadiz.entitlements`, `Apple Distribution`, profile `wadiz appstore`, Combine 링크 제거 (`Release.xcconfig:1-26`)
- Extension 별 xcconfig: `WadizWidget`, `MakerStoreProjectIntents`, `NotificationService` 각자 Dev/QA/Release 3종.

### Fastlane
- `fastlane/Fastfile` 이 모든 빌드 entrypoint. 주요 lane: `fastlane rc`, `fastlane develop branch:{브랜치명}` (`CLAUDE.md:302-306`).
- Ruby `3.2.5` (`.ruby-version`), `Gemfile` 으로 Fastlane + plugins (`fastlane/Pluginfile`).
- `fastlane/sources/`: `version_manager.rb`, `app_version.rb`, `app_store_version_creator.rb`, `testflight_build_linker.rb`, `manifest_versions.rb` (Project.swift 버전 read/write), `xcconfig_reader.rb`, `uitest_env_injector.rb`.
- 버전 소스: `Projects/App/Project.swift:7-8` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`). `ManifestVersions.read`/`write` 가 파일 직접 편집.
- 프로비저닝: `provisioning_profiles/` 디렉토리에 프로필 파일 포함. `XCConfigReader.read_all_provisioning_profiles` 가 xcconfig → 프로필 이름 파싱.

### 배포 채널
- **AppStore / TestFlight**: Release scheme + `fastlane rc` → TestFlight → App Store Connect.
- **Adhoc (QA)**: QA scheme + Firebase App Distribution 또는 사내 배포.
- **릴리즈 노트**: `release_note_wiki.py`, `release_note_url.txt`, `search_release_note.py`, `bulk_update_release_note.py` (Python 스크립트 군) — Atlassian Confluence 자동 업데이트.
- **i18n 빌드 스크립트**: `transform_i18n_strings.py` (InfoPlist.strings 4개 언어 생성).
- **CI**: `.github/workflows/` (Dependabot 포함) + `.github/actions/`.

### SwiftLint
- Main target post-build script 로 SwiftLint 실행. SwiftPM binary artifact `swiftlint-*-macos/bin/swiftlint`. `.swiftlint.yml` 레포 루트에 존재.

### 검증 게이트 / 개발 하네스 (2026-06 도입)
- **`make verify` 단일 진입점 (FE1-898, 2026-06-16)** — 루트 `Makefile` 이 `build`(swiftlint 자동 포함) + `lint` (+ `TEST_SCHEME` 지정 시 모듈 단위테스트) 를 묶은 단일 검증 게이트. 사람·CI·하네스 모두 동일하게 사용하며 `xcodebuild` 를 직접 추측 호출하지 않는다. 빌드 스킴은 `wadiz-dev`(release 전용 `wadiz` 는 직접 빌드 불가). App 게이트(`WadizTests`)는 실네트워크 API 통합테스트를 제외 → `make verify` green ≠ 전체 테스트 통과.
- **CLAUDE.md 분리 → `.claude/rules/` (FE1-896, 2026-06-16)** — 단일 `CLAUDE.md` 를 always-load(`harness.md`, `branching-pr.md`) + path-scoped(`swift-conventions.md`=`**/*.swift`, `architecture.md`=`Projects/**`, `di-assembly.md`, `testing.md`, `localization.md`, `deployment.md`) 규칙 파일로 쪼갬. Claude Code 가 작업 파일 경로에 매칭되는 규칙만 자동 로드.
- **하네스 산출물 규약 (FE1-899, 2026-06-18)** — 정제→계획→구현→검증 단계 간 상태를 대화 요약이 아니라 `.claude/harness/<JIRA-KEY>/{spec.md, task_list.json, progress.md}` 파일 + git 으로만 인계. 템플릿은 `.claude/harness/templates/`. "생성 ≠ 평가" 분리(정제는 독립 비평기, 구현은 독립 리뷰어가 검증).

---

## 특이사항

### iOS 고유
- **Tuist 멀티 프로젝트** — Tuist 마이그레이션은 단계 계획(구 `TUIST_PHASE*_PLAN.md`)을 완료·정리하고, **FE1-790(2026-05-29)** 로 멀티모듈 프로젝트를 **Xcode 16 Folder(synchronized group) 형식**으로 전환했다(`Project.swift` 들의 그룹 구조 단순화, Onboarding `Resources` 가 `Sources/Resources` → `Resources` 로 이동, 신규 가이드 `docs/app-target-folder-plan.md`). Features 모듈 중 일부(`Benefit`, `Contacts`, `Wish`, `Startup`, `AD`, `Banner`, `Exhibition`)는 **아직 `Projects/App/Sources/` 내부 디렉터리에 남아있음** — 향후 Feature Project 로 분리 예정.
- **Swift Macro Packages** — `/Packages/Macro` 가 로컬 SPM 패키지 (Macros/Macro/MacroClient 타겟). `Core/Persistence` 가 Macro 의존하여 컴파일 타임 매크로 활용. Swift 5.9 필수.
- **Strict Concurrency** — Swift 6 strict concurrency 대응 진행. 각 Project 루트에 `STRICT_CONCURRENCY_GUIDE.md`. `WadizRequestInterceptorImpl.swift:19,20,23,24` 처럼 `nonisolated(unsafe)` 로 임시 대응. `Projects/Service/Sources/USERSERVICE_ACTOR_MIGRATION_GUIDE.md` 는 UserService actor 마이그레이션 가이드.
- **App Extensions 3개** — `WadizWidget` (홈스크린 위젯, 스토어 프로젝트 요약), `MakerStoreProjectIntents` (Siri/Spotlight intent), `NotificationService` (Braze rich notification service extension). 모두 별도 entitlement/xcconfig.
- **Associated Domains** — `link.wadiz.kr` 단축링크 + `www.wadiz.kr` + `www.wadiz.ai` universal link.
- **i18n 런타임 JSON 공유** — `Projects/Core/Sources/UI/Resources/i18n.json` 하나의 파일로 한국어 기본 + 영어/일본어/중국어 지원 (`CLAUDE.md:131-135`). Android 와 동일 JSON 스키마로 동기화.
- **InfoPlist 다국어화** — 권한 문구(NSCameraUsageDescription 등 13개 키)를 4개 `{ko,en,ja,zh}.lproj/InfoPlist.strings` 로 자동 생성 (`CLAUDE.md:137-167`, `transform_i18n_strings.py`).
- **Remote Config 스킴 네비게이션** — `remote_config_defaults.plist` 에 `wadiz.kr/web/…` 경로 → 네이티브 화면 매핑 정의. `Service/ScreenKeyParser` 가 이를 해석해 `Navigator` 로 라우팅.
- **Pulse 네트워크 디버거** — Debug 빌드에서 shake 제스처로 모든 HTTP 요청/응답 시각화 (Alamofire `EventMonitor` 로 연동).
- **OHHTTPStubs** — UI 테스트에서 API mocking. `fastlane/sources/uitest_env_injector.rb` 가 스텁 설정 주입.
- **서포팅 결제 전량 웹뷰** — Android 와 동일하게 펀딩/스토어 상세 + 결제는 모두 WKWebView. 네이티브 Alamofire 결제 엔드포인트 없음.
- **위젯 전용 API** — `Extensions/WadizWidget/Sources/Maker/StoreProject/API/StoreProjectAPI.swift` 는 **메인 앱과 독립된 API 클라이언트**. 메인 앱의 `Core/Networking` 일부(`RequestBuilder`) 를 sources 공유로 재사용 (`Projects/App/Project.swift:329-334`).
- **Crashlytics DSYM 업로드** — post-build script `Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run` 자동 실행 (`Projects/App/Project.swift:130-136`).
- **OSS License** — `Tuist/Package.resolved` 를 빌드 전 `Projects/App/Resources` 로 복사 → `AcknowList` 가 런타임에 표시 (`Projects/App/Project.swift:107-113`).
- **중복 구현 주의** — `/api/funding/wishes` 찜 추가는 `Service/Activity/ActivityAPI.swift:29` 와 `App/Wish/WishesAPI.swift:33` 두 곳에 존재 (Service 레이어로 이주 중). `/api/ftaccountConfirm/*` 역시 `Service/SmsAuth` 와 `App/Protocol/ProtocolFTAccountConfirm.swift` 중복. 마이그레이션 잔재.
- **라이브커머스 PIP (FE1-809, 2026-06-02)** — 메이커 모드 웹뷰(`MakerWebViewController`)에서 Picture-in-Picture 라이브커머스 영상을 띄운다. (**FE1-961, 2026-06-19 이후**: 외부 `PIPKit` SPM 을 제거하고 `Core/UI` 자체 구현 `FloatingViewKit` 으로 교체 — 아래 최상단 보강 블록 참조.) 노출 여부·URL 은 `Service/LiveCommerce` 가 Remote Config `liveCommercePip` 로 게이트. **FE1-865(2026-06-11)** 로 SceneDelegate 환경에서 PIP 최초 노출 시 `safeAreaInsets` 가 0 인 채 프레임이 계산돼 `UITabBar` 를 가리던 버그를 다음 runloop 의 `setNeedsUpdatePIPFrame()` 재계산으로 보정 (`PIPKit+Extension.swift`).
- **HWP/HWPX 웹뷰 첨부 (QA-22250, 2026-06-15)** — iOS 가 hwp/hwpx 를 기본 인식하지 못해 웹 `accept` 에 내려도 파일 선택기에서 비활성화되던 문제를, `Info.plist`/`Info_Dev.plist` 에 `UTImportedTypeDeclarations` 로 확장자(hwp/hwpx) ↔ MIME(`application/x-hwp`, `application/haansofthwpx`) 매핑을 선언해 해결.
- **WADIZChannelIO 스킴 제거 (FE1-796, 2026-05-29)** — `More` 모듈의 `WADIZChannelIO` 커스텀 스킴 핸들러 제거.

---

## 최근 변경사항

**분석 갱신일: 2026-07-10** (이전: 2026-06-19, 2026-05-29, 최초: 2026-04-20)

### 모듈화 / 아키텍처
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| Tuist 멀티모듈 프로젝트를 Xcode 16 Folder 형식으로 전환 | 2026-05-29 | FE1-790 |
| 라이브커머스 모델/유스케이스 App→Service 모듈(`LiveCommerce`) 분리 | 2026-06-02 | FE1-809 |
| ServerMode DEV 케이스 제거, CDEV 로 통합 | 2026-06-05 | FE1-854 |
| Navigator 를 Swinject register/resolve 로 변경 | 2026-05-26 | FE1-741 |
| 미사용 WAiWebViewController/WAiErrorView 제거 | 2026-05-21 | FE1-739 |
| AppRouterService Service Module 분리 | 2026-05-27 | FE1-636 |
| 프로젝트 오픈 Feature Module 분리 | 2026-05-27 | FE1-634 |
| 프리오더 SwiftUI 전환 및 ServiceHome 모듈 이동 | 2026-04-23 | FE1-325 |
| 개발모드 글로벌 메뉴 제거 및 국가변경 메뉴 일원화 | 2026-05-15 | FE1-639 |

### 기능 추가 / 변경
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 메인홈 추천 A/B — main2 v10 분기 + X-Device-Type/X-Experiment 헤더, 성과 측정 전자상거래 데이터로 일원화 | 2026-05~29 | FE1-698 |
| 메이커 모드 라이브커머스 PIP 지원 | 2026-06-02 | FE1-809 |
| 공통 웹뷰 내 펀딩/오픈예정 상세 이동 시 네이티브 화면 랜딩 | 2026-05-27 | FE1-735 |
| 스토어→펀딩 이동 시 네이티브 헤더/검증 경로 일관성 | 2026-05-29 | FE1-781 |
| WADIZChannelIO 스킴 핸들러 제거 | 2026-05-29 | FE1-796 |
| MessageBox 색상 green → mint 변경 | 2026-05-28 | FE1-719 |
| 웹뷰 첨부 HWP/HWPX UTI 선언 추가 | 2026-06-15 | QA-22250 |
| 검색 쿠폰 추천 글로벌 통화 소수값 디코딩 실패 수정 | 2026-06-01 | QA-22165 |
| PIP 최초 노출 시 UITabBar 가림 현상 수정 | 2026-06-11 | FE1-865 |
| KeyVisualBanner 초기 진입 배너 깜빡임 수정 / 최근 프로젝트 카드 하단 잘림·여백 수정 | 2026-05-26~27 | FE1-768, FE1-760, FE1-769 |
| wadiz:// 스킴 URL needLogin 버그 수정 | 2026-05-26 | FE1-740 |
| wadiz.ai 도메인 제거 대응 | 2026-05-20 | FE1-724 |
| 검색 결과 쿠폰 국가별 통화 표시 적용 | 2026-05-20 | FE1-673 |
| 유저 활동 데이터 작업 | 2026-05-18 | FE1-543 |
| OneLink deferred=false 케이스 AppRouterService 처리 추가 | 2026-05-18 | FE1-689 |
| 딥링크 cold start 시 광고 스킵 처리 | 2026-04-20 | FE1-416 |
| 웹뷰 인라인 미디어 자동재생 정책 복구 | 2026-04-22 | FE1-472 |

### 인프라 / 개발 하네스
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| `make verify` 단일 검증 게이트(build·lint·단위테스트) 도입 | 2026-06-16 | FE1-898 |
| CLAUDE.md 분리 → `.claude/rules/`(always·path-scoped) | 2026-06-16 | FE1-896 |
| 하네스 산출물 규약 정립(`.claude/harness/`) | 2026-06-18 | FE1-899 |
| fastlane 2.235.0 업데이트 (jwt 보안 취약점 해결) | 2026-05-27 | FE1-717 |
| Claude 관련 GitHub Actions 워크플로우 제거 | 2026-05-13 | FE1-662 |
| review-loop 프로젝트 스킬 추가 | 2026-05-28 | FE1-785 |
