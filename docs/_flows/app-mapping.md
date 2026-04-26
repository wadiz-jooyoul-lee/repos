# 앱(Android/iOS) ↔ Flow 매핑

> 18개 flow 각각에 대해 Android(Retrofit) / iOS(RequestBuilder) 쪽 실제 호출 위치를 매핑. 각 flow 문서의 "wadiz-android / wadiz-ios" 섹션을 보완하는 전용 레퍼런스.

## 중요 관찰 — 앱은 `/web/*` 를 쓰지 않는다

웹(wadiz-frontend)은 `/web/apip/funding/...`, `/web/reward/api/...`, `/web/v3/...` 등 `com.wadiz.web` 경로를 쓰지만, **앱은 동일 기능을 다른 경로로 호출**한다:

| 영역 | 웹 경로 | 앱 경로 |
|---|---|---|
| 펀딩 위시 | `/web/apip/funding/wishes` | `/api/funding/wishes` |
| 검색 펀딩 | `/api/search/v2/funding` (service.wadiz.kr) | `/api/search/v2/funding` (서비스 host 동일) |
| 로그인 이메일 | `/oauth/loginPerform` (account.wadiz.kr form) | `/api/v4/login/email` (앱 전용 API) |
| 회원가입 | `/api/v1/users` (account) | `/api/v4/sign-up/email` (앱 전용 V4) |

### 앱의 API Host 분류 (iOS `APIDomain.swift` 기준)
- `.api` → 기본 (내부 API, 예: `api.wadiz.kr` 또는 유사) — V3/V4 앱 API
- `.publicApi` → `public-api.wadiz.kr` (비로그인 공개)
- `.platform(.inbox/.keyword/.main/.push/.wish/.activities)` → `platform.wadiz.kr` (알림/키워드/푸시/위시 플랫폼)
- `.service` → `service.wadiz.kr` (검색)
- `.ad` / `.analytics` → 광고/분석
- `.webOrigin` → `www.wadiz.kr` (Origin 헤더 용도)

Android 도 동일 구조 — `WadizPlatformAPIService`, `WadizServiceAPIService`, `AppV3APIService`, `WadizWebAPIService`, `WadizStoreAPIService` 등 **Retrofit interface 별로 baseUrl 다름**.

---

## Flow별 앱 매핑

### A1 — 펀딩 코어

#### 1. funding-detail (펀딩 상세)
**Android**: `WadizServiceAPIService.kt` 나 별도 feature API 에서 `/api/search/v2/products` 등으로 카드 조회. 상세 페이지는 대부분 **웹뷰(WebView)** 로 `https://www.wadiz.kr/campaign/{id}` 렌더 — 네이티브 API 호출 최소화.
**iOS**: 동상. `Projects/Features/ServiceHome/Sources/Store/Data/API/StoreAPI.swift` 등에서 홈 카드 조회.

> 📌 대부분의 앱 "프로젝트 상세" 는 WebView 기반 (wadiz-android 의 `feature/catchup`, `feature/service-home`, wadiz-ios 의 `Features/ServiceHome`). 순수 네이티브 상세가 아니라 **하이브리드**.

#### 2. funding-payment (서포팅 결제)
**앱**: 결제 시 WebView 로 `/web/wpurchase/reward/step10/{campaignId}` 진입 → 동일 웹 결제 플로우 사용. 순수 네이티브 결제 화면은 **없는 것으로 관측**.
**참고**: `CreditCardOCR` feature 모듈은 카드번호 OCR 인식만 담당 (Features/CreditCardOCR).

#### 3. funding-reward-select
**앱**: 결제와 동일하게 WebView 경로. 네이티브 선택 UI 없음.

#### 4. my-funding (내 펀딩)
**Android**: `WadizWebAPIService.kt:16` `@GET("/web/mywadiz/supporter/usage-count")` (카운트만). 목록은 feature 모듈에서 WebView 또는 `/web/apip/funding/supporters/my/fundings` Retrofit 호출.
**iOS**: `Projects/Features/MyActivity/Sources/Wish/Data/API/WishSearchAPI.swift` — 위시 쪽. 펀딩 내역은 WebView 연동 추정.

#### 5. funding-refund
**앱**: WebView (네이티브 환불 UI 미관측).

#### 6. funding-autopay (Billkey)
**앱**: Billkey 등록은 WebView 로 진입. 카드 SDK 팝업 → 웹 결제 페이지 재사용.

---

### A2 — 계정/가치교환

#### 7. login (로그인)
**Android**: `core/network/.../service/api/AppV3APIService.kt`
```kotlin
@POST("/api/v3/login/email")           // :71   이메일 로그인 (레거시)
@POST("/api/v4/login/email")           // :105  V4 이메일
@POST("/api/v4/login/social")          // :76   소셜 (구글/카카오/Apple)
@POST("/api/v4/check/email")           // :113  이메일 중복 검사
```
**iOS**: `Projects/Features/Login/Sources/Common/Data/CheckAPI.swift:24`
```swift
let path = "/api/v4/check/email"
let request = RequestBuilder(domain: .api, path: path, method: .post, headers: headers)
```

→ **앱은 OAuth2 authorize/token 플로우 대신 자체 V4 로그인 API 사용**. 웹과 완전히 다른 경로. 결과 토큰은 앱 내 저장소(Keychain/EncryptedSharedPreferences) 에 보관.

#### 8. signup (회원가입)
**Android**: `AppV3APIService.kt`
```kotlin
@POST("/api/v4/sign-up/email")                   // :97   이메일 가입
@POST("/api/v4/sign-up/social")                  // :89   소셜 가입
@POST("/api/v4/sign-up/social/link")             // :81   소셜 연결
@POST("/api/v4/sign-up/email/code")              // :121  코드 발송
@POST("/api/v4/sign-up/email/code/verification") // :129  코드 검증
@GET("/web/v3/terms/signup")                     // :137  가입 약관 (웹과 공유)
```
**iOS**: `Features/Login/Sources/*/Data/*.swift` (SignUpRepository, SignUpTermsModalView 등).

#### 9. mypage (마이와디즈)
**Android**:
```kotlin
// AppV3APIService.kt
@GET("/api/v3/account")                    // :177  계정 정보
@GET("/api/v3/account/info/refresh")       // :68   갱신
@GET("/api/v3/account/sns-links")          // :145  SNS 연결 목록
@GET("/api/v3/user/settings/terms/...")    // :230  약관 설정
// WadizWebAPIService.kt
@GET("/web/mywadiz/supporter/usage-count") // :16
```
**iOS**: `Projects/Features/MyWadiz`, `Projects/Features/MyActivity`, `Projects/Features/Setting/Sources/*`.

#### 10. coupon-use
**Android**: `WadizDomainAPIService.kt`
```kotlin
@GET("/web/reward/api/coupons/templates/types/download?...")                          // :51  다운로드 가능 쿠폰
@POST("/web/reward/api/coupons/transactions/types/redeem/issue-types/download")     // :60  다운로드 등록
@POST("/web/reward/api/coupons/transactions/types/redeem/issue-types/download/bulk/by-project/{projectId}")  // :87
```
**iOS**: `Projects/Features/Search/Sources/Result/Data/CouponAPI.swift`.

→ 쿠폰은 앱도 `/web/reward/api/*` 경로를 그대로 호출 (웹과 동일 경로).

#### 11. supporter-signature
**Android**: `WadizWebAPIService.kt` 또는 서명 전용 서비스에서 `/web/v3/supporter-signatures/...` 호출 (웹과 동일 경로).
**iOS**: WebView 기반으로 서명 UI 사용 가능성 높음. 네이티브 서명 모듈 없음.

#### 12. comment
**앱**: WebView 기반 댓글 UI (프로젝트 상세가 WebView 이므로 동반).

---

### A3 — 부가/스토어

#### 13. search (검색)
**Android**: `WadizServiceAPIService.kt`
```kotlin
@GET("/api/search/v2/popular/keyword")    // :24
@POST("/api/search/v2/funding")           // :31
@POST("/api/search/v2/fundingSoon")       // :42
@POST("/api/search/v2/preorder")          // :71
@GET("/api/v1/searcher/wish/project/endingsoon")  // :61
```
Host: `service.wadiz.kr` (`WadizServiceAPIService` baseUrl).

**iOS**: `Projects/App/Sources/ServiceHome/Preorder/API/PreorderAPI.swift:26`
```swift
let path = "api/search/v2/preorder"
// RequestBuilder(domain: .service, path: path, method: .post, ...)
```
`Projects/App/Sources/Development/NetworkStubs/CategoryAPIStub.swift` — 테스트 스텁으로 `/api/search/categories`, `/api/search/home` 관측.

→ **검색은 앱·웹 모두 `service.wadiz.kr/api/search/v2/*`** 로 동일 host/path.

#### 14. store-detail
**Android**: `WadizStoreAPIService.kt:11`  `@GET("store/projects/my")`. 기타 스토어 상세는 WebView.
**iOS**: `Projects/App/Sources/ServiceHome/Store/API/StoreAPI.swift`, `Projects/Features/ServiceHome/Sources/Store/Data/API/StoreAPI.swift`.

#### 15. store-order
**Android**: `WadizStoreAPIService.kt` 및 WadizStoreServiceAPIService (`/api/search/store/`). 주문 자체는 WebView 결제 경유 추정.
**iOS**: Store 영역 (`Projects/Features/ServiceHome/Sources/Store/Data/API/StoreAPI.swift`). 주문 상세는 WebView.

#### 16. store-wish (위시)
**Android**: 위시 API (별도 wishlist 서비스). Retrofit path 는 `WadizPlatformAPIService.kt:47` `@GET("/wish/api/v1/wish/discount")` 및 activities 기반.
**iOS**: `Projects/App/Sources/Wish/Service/WishesAPI.swift:33, 49, 120`
```swift
// addWish
let path = "/api/funding/wishes"
// removeWish  동상
// wishesQty
let path = "/api/funding/wishes/my/qty"
```
또한 `Projects/Service/Sources/Activity/Feature/ActivityAPI.swift:29, 57` 동일 path.

→ 앱은 `/api/funding/wishes` (`/web/` 없음). **웹과 Host 분리** — 앱 전용 API gateway 에서 처리하는 경로.

#### 17. notification (알림)
**Android**:
- `NotiChannelDataSource.kt` — 알림 채널
- `InboxDataSource.kt` — 인박스 (platform.wadiz.kr)
- `WadizPlatformAPIService.kt` — 푸시/키워드
- `keyword/KeywordAlarmDatasource.kt` — 키워드 알림

**iOS**: `Projects/Features/NotificationCenter/Sources/Data/NotificationCenterAPI.swift:41,65,80,129`
```swift
RequestBuilder(domain: .platform(.inbox), path: path, method: .get, ...)   // 인박스 목록
RequestBuilder(domain: .platform(.inbox), path: path, method: .put, ...)   // 읽음 처리
RequestBuilder(domain: .api, path: path, method: .post, ...)               // 알림 전송 관련
```
`Projects/Features/Setting/Sources/NotificationSetting/NotificationAPI.swift` — 알림 설정.

→ 앱 인박스는 `platform.wadiz.kr/inbox/*` 직접 호출. 웹도 동일 플랫폼 서비스를 공유하지만 경로 prefix 가 다를 수 있음.

#### 18. wai-agent
**Android**: `SearchAiDatasource.kt` 에 AI 검색 일부. AI 에이전트 런처 전용 클라이언트 feature 미관측 (또는 WebView).
**iOS**: `Projects/Features/Search/Sources/...` AI 검색 관련. WAi 런처는 현재 앱에서 별도 모듈 보이지 않음 — **웹 전용 기능** 또는 WebView.

---

## 정리 — 앱 통합 패턴

### 🔵 "순수 네이티브 API" 영역 (앱 전용 경로 존재)
- **인증** (`/api/v4/login/*`, `/api/v4/sign-up/*`)
- **계정 관리** (`/api/v3/account/*`)
- **설정** (약관·알림 설정)
- **위시** (`/api/funding/wishes`)
- **알림 인박스** (`platform.wadiz.kr/inbox/*`)
- **검색** (`service.wadiz.kr/api/search/v2/*` — 웹과 host 동일)
- **홈 피드** (`/main/*`, `/main/display-ads/*`)

### 🟡 "웹 경로 공유" 영역 (앱이 웹 Retrofit 경로 그대로 사용)
- **쿠폰** (`/web/reward/api/coupons/*`)
- **서포터 서명** (`/web/v3/supporter-signatures/*` — 일부 앱 feature 에서)
- **마이펀딩 일부** (`/web/mywadiz/supporter/*`)

### 🟠 "WebView 위임" 영역 (앱은 URL 만 전달, 렌더는 웹)
- **펀딩 프로젝트 상세**
- **펀딩 결제** (step10/step20/result10)
- **리워드 선택**
- **환불·Billkey 등록**
- **스토어 상세·주문**
- **댓글·서포터 서명 UI**
- **WAi 에이전트 런처** (런처 페이지 자체는 웹)

→ 앱의 많은 주요 구매/결제/콘텐츠는 WebView 로 웹에 위임. 성능·일관성 측면 분석 가치 있음.

---

## 경계·미탐색

1. **앱 전용 V4 API 의 백엔드** — `/api/v3/*`, `/api/v4/*` 는 앱 API host 에서 처리. 본 `repos/` 폴더에 해당 백엔드 서비스가 없음 — **별도 repo 추정** (예: `app-api` 일부 or `mobile-api` 별도).
2. **WebView URL 수신 · JS Bridge** — 앱과 웹 간 메시지 교환은 `feature/catchup`, iOS `Features/Navigator` 등에 있을 것으로 추정, 본 문서 범위 외.
3. **SDUI (Server-Driven UI)** — Android 의 `core/server-driven-ui` 모듈 존재. 홈·피드 일부를 SDUI 로 내려받는 것으로 보이는데 본 문서는 미포함.
4. **각 feature 모듈별 Repository → UseCase → Service 체인** — 본 매핑은 API path 수준까지만. 각 feature 내 `data/remote` · `domain/usecase` 레이어 분석은 Phase 2 앱 분석 범위.
5. **경로 일치 확인** — 앱 `/api/funding/wishes` vs 웹 `/web/apip/funding/wishes` 가 같은 funding 서비스 엔드포인트로 귀결되는지 (gateway 라우팅 차이) 확인 필요.
