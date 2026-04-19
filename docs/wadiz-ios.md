# Wadiz iOS (wadiz-ios) 분석

> 크라우드펀딩 플랫폼 **Wadiz**의 공식 iOS 클라이언트.
> Tuist 기반 멀티 프로젝트 + SPM(`Tuist/Package.swift`) 의존성, MVVM+Coordinator 패턴, 단일 `HTTPClient` + `APIDomain` 라우팅.
> 본 문서는 실제 코드 기준으로 **어떤 API 가 어떤 기능에서 어떤 백엔드로 호출되는지** 를 정리한다.

---

## 개요

| 항목 | 값 | 참조 |
| --- | --- | --- |
| Bundle ID | `com.markmount.wadiz` | `Projects/App/Project.swift:94`, `Projects/App/SupportingFiles/Configuration/Base.xcconfig:9` |
| Extension Bundle IDs | `.WadizWidget`, `.MakerStoreProjectIntents`, `.notificationservice` | `Projects/App/Project.swift:300,325,349` |
| 지원 OS 최소 | **iOS 16.1** | `Tuist/ProjectDescriptionHelpers/Environment.swift:5` |
| MARKETING_VERSION / BUILD | `26.14.1` / `26.14.1.2` | `Projects/App/Project.swift:7-8` |
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
비즈니스 로직 서비스. `Sources/{Activity, Analytics, AppSecurity, Braze, ContactSync, DeviceSetting, FloatingButtons, FriendActivity, KeywordAlarm, Locale, MyWadizMode, Notification, RecentCategory, RecentKeyword, RecentProject, RefererURL, RemoteConfig, ScreenKeyParser, SearchBarDayMarketing, Share, SmsAuth, SocialLogin, Spotlight, User, Zendesk}` — 각 폴더에 Feature/Interface 분리. 주요: `Activity` (찜 API), `SmsAuth` (SMS 인증), `Analytics` (Waditag), `KeywordAlarm`, `SocialLogin`.

### `Projects/API` (REST Client)
하나의 Project 에 7 개 Framework 타겟.
| 타겟 | 역할 |
| --- | --- |
| `AccountAPI` | 계정 조회/갱신/SNS 링크 |
| `AppSettingAPI` | 앱 설정 (Server-Driven Settings Tab, `/api/v1/settings`) |
| `LoginAPI` | 로그인/로그아웃 |
| `MainAPI` | Platform main2 (홈 메인/퀵메뉴/랭킹/추천/키비주얼) |
| `SearchAPI` | 검색/카테고리/펀딩소프트/스토어검색/프리오더 |
| `SignUpAPI` | 회원가입/이메일 코드 |
| `SocialAPI` | 카카오 친구/다중 팔로우 |

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
| `Projects/API/*` (7 타겟) | `core/network/service/**` (17 ApiService) | Android 는 `ServerMode.xxxUrl` 속성을 baseUrl 분기 키로 쓰는 반면 iOS 는 `APIDomain` enum |
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

1. **`Projects/Core/Sources/Preference/Interface/ServerMode.swift`** 의 `enum ServerMode` (`local/dev/cdev/rc/rc2/rc3/stage/live`) 가 런타임에 `AppPreference` 로부터 설정됨. (`ServerMode.swift:8-17`)
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
| `.platform(.main)` | `https://platform.wadiz.kr` | `https://stage-platform.wadiz.kr` (**main만**) | `https://rc2-platform.wadizcorp.net` | `https://dev-platform.wadizcorp.net` | `/main2/…` 홈/퀵메뉴/랭킹/추천 |
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

### 홈 / 서비스홈 (`Features/Home`, `API/MainAPI`, `Features/ServiceHome`, `App/Sources/Banner`, `App/Sources/AD`, `App/Sources/Exhibition`)

| 모듈 | 엔드포인트 | APIDomain | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `MainAPI` | `GET /main2/api/v9/main` | `.platform(.main)` | 홈 메인 큐레이션 | 홈 탭 로드/Pull-to-refresh. `MainAPIImpl.swift:16,24` |
| `MainAPI` | `GET /main2/api/v3/my-wadiz` (+v? 버전 파라미터) | `.platform(.main)` | 홈 하단 마이와디즈 요약 | 홈 스크롤. `MainAPIImpl.swift:38-43` |
| `MainAPI` | `GET /main2/api/v1/recommendation/item` | `.platform(.main)` | 연관 추천 | 상세 진입 후 추천. `MainAPIImpl.swift:47-53` |
| `MainAPI` | `GET /main2/api/v1/quickmenu?id={id}` | `.platform(.main)` | 퀵메뉴 | 홈 진입. `MainAPIImpl.swift:57-66` |
| `MainAPI` | `GET /main2/api/v1/pc/ranking/store` | `.platform(.main)` | 스토어 랭킹 | 서비스홈/홈. `MainAPIImpl.swift:69-73` |
| `MainAPI` | `GET /main2/api/v1/banner/key-visual/{type}` | `.platform(.main)` | 홈 키비주얼 배너 | 홈 상단. `MainAPIImpl.swift:76-80` |
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
- Repository → `MainAPI.fetchMain(MainRequest(header: encUserId, variant), query: …)` → `RequestBuilder(domain: .platform(.main), path: "/main2/api/v9/main", method: .get)` + `set(queryName:)` chain → `HTTPClient.request` (`Interceptor adapt/retry`) → `MainResponse`
- `HomeMapper` 가 `MainResponse` → `HomeSectionModel[]` 변환 → `HomeViewController` 의 `UICollectionView` (IGListKit) 섹션 렌더
- 병렬 호출: `fetchMainQuickMenu`, `fetchMainStoreRanking`, `fetchKeyVisualBanner`, `AdService.fetchKeyVisual`, `MainRepositoryImpl.fetchMainMyWadiz`

### 2) 프로젝트 상세 / 결제 (서포팅)
- iOS 도 **상세/결제 페이지는 네이티브가 아닌 WKWebView**. 진입 시 `AccountAPI.requestToken()` (`POST /api/waccount/auth/request/token`) → 쿠키 동기화 → `webOrigin + /web/campaign/detail/{id}` 로 `WKWebView` 로드.
- JS ↔ Native 브릿지: 결제 완료, 찜 토글, 카드 OCR 요청 등. 네이티브 복귀 시 `WishesAPI.add/delete`, `Service/Activity.fetchWishList()` 로 동기화.
- Remote Config 로 URL 패턴 가드 (`Projects/App/SupportingFiles/remote_config_defaults.plist` 에 `wadiz.kr/web/campaign/detail/{arg_0}` 등 정의).

### 3) 로그인 (`Features/Login`)
- 트리거: `LoginHomeViewController` → 이메일 로그인 or 소셜 버튼
- `LoginHomeViewModel` (`Projects/Features/Login/Sources/LoginHome/Presentation/LoginHomeViewModel.swift`) → `LoginAPI.loginEmail(path: "/api/v4/login/email", body)`
- 응답 후 `UserService` (`Projects/Service/Sources/User`) 가 `UserCredential` (KeychainSwift) + `UserDefaults sessionId` 저장 → Swinject 에서 credentialProvider 갱신 → 다음 요청부터 `WadizRequestInterceptor.adapt` 가 `authKey/userId/sessionId` 헤더 자동 추가
- 후속: `AccountAPI.userRefresh` (`/api/v3/account/info/refresh`), `AccountAPI.requestToken`, `MainAPI.fetchMain` (홈 진입)
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
- `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` 에 `.shared`, `.model`, `.networking`, `.preference`, `.home`, `.login`, `.mainAPI` 등 공통 의존 매크로 정의.

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

---

## 특이사항

### iOS 고유
- **Tuist 멀티 프로젝트** — `docs/TUIST_PHASE1_PLAN.md` ~ `TUIST_PHASE8_PLAN.md` 로 Tuist 마이그레이션을 8단계로 쪼개 진행 중. Features 모듈 중 일부(`Benefit`, `Contacts`, `Wish`, `Startup`, `AD`, `Banner`, `Exhibition`)는 **아직 `Projects/App/Sources/` 내부 디렉터리에 남아있음** — 향후 Feature Project 로 분리 예정.
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
