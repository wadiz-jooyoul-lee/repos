# 앱(Android/iOS) ↔ Flow 매핑

> 18개 flow 각각에 대해 Android(Retrofit) / iOS(RequestBuilder) 쪽 실제 호출 위치를 매핑합니다.
> 각 flow 문서의 "wadiz-android / wadiz-ios" 절을 보완하는 전용 참고서입니다.

> 📅 **2026-09-30 본문 점검**
> — `wadiz-ios` `main` `9063ca389`(2026-09-18), `wadiz-android` `main` `9b492a0b8b`(2026-09-21) 기준
>
> **iOS 쪽 인용 7건이 전부 죽어 있었습니다.** Android 쪽은 11건 모두 살아 있습니다.
>
> 원인은 하나입니다 — **`IOS-4193`(2026-05-12, 725개 파일)이 API 계층을 통째로 재편**했습니다.
> 기능별 폴더에 흩어져 있던 API 파일이 **`Projects/API/Sources/{모듈}/Interface/`** 아래로 모였습니다.
> 지금 API 모듈은 27개입니다.
>
> | 예전 경로 | 지금 |
> |---|---|
> | `Projects/Features/Login/Sources/Common/Data/CheckAPI.swift` | `Projects/API/Sources/AccountAPI/` |
> | `Projects/Features/MyActivity/Sources/Wish/Data/API/WishSearchAPI.swift` | `Projects/API/Sources/WishAPI/Interface/WishAPI.swift` |
> | `Projects/Features/NotificationCenter/Sources/Data/NotificationCenterAPI.swift` | `Projects/API/Sources/InboxAPI/Interface/InboxAPI.swift` |
> | `Projects/Features/Setting/Sources/NotificationSetting/NotificationAPI.swift` | `Projects/API/Sources/CommonAPI/Interface/CommonAPI.swift` |
> | `Projects/Features/Search/Sources/Result/Data/CouponAPI.swift` | `Projects/API/Sources/WebAPI/` |
> | `Projects/App/Sources/ServiceHome/Preorder/API/PreorderAPI.swift` | `Projects/API/Sources/SearchAPI/Feature/SearchAPIImpl.swift` |
> | `Projects/App/Sources/ServiceHome/Store/API/StoreAPI.swift` | `Projects/API/Sources/StoreAPI/Interface/StoreAPI.swift` |
> | `Projects/App/Sources/Development/NetworkStubs/CategoryAPIStub.swift` | **대응 파일을 못 찾았습니다** (확인 필요) |
>
> `APIDomain` 도 크게 바뀌었습니다. 아래 호스트 분류 절을 다시 썼습니다.

## 중요 관찰 — 앱은 `/web/*` 를 쓰지 않는다

웹(wadiz-frontend)은 `/web/apip/funding/...`, `/web/reward/api/...`, `/web/v3/...` 등 `com.wadiz.web` 경로를 쓰지만, **앱은 동일 기능을 다른 경로로 호출**한다:

| 영역 | 웹 경로 | 앱 경로 |
|---|---|---|
| 펀딩 위시 | `/web/apip/funding/wishes` | `/api/funding/wishes` |
| 검색 펀딩 | `/api/search/v2/funding` (api.wadiz.io) | `/api/search/v2/funding` (서비스 host 동일) |
| 로그인 이메일 | `/oauth/loginPerform` (account.wadiz.io form) | `/api/v4/login/email` (앱 전용 API) |
| 회원가입 | `/api/v1/users` (account) | `/api/v4/sign-up/email` (앱 전용 V4) |

### 앱의 API Host 분류 (iOS `APIDomain.swift` 기준)

`Projects/Core/Sources/Networking/Interface/APIDomain.swift`(166줄)에 **14가지**가 정의돼 있습니다.
예전 문서는 7가지로 적었는데, 그 사이 늘었고 **모양도 바뀌었습니다.**

**하위 서비스를 인자로 받는 형태가 됐습니다.** 예전에는 `.platform(.inbox)` 처럼 일부만 그랬는데
지금은 `.publicApi`·`.service`·`.app` 도 인자를 받습니다.

| 도메인 | 하위 서비스 | live 주소 |
|---|---|---|
| `.publicApi(_)` | `main1` | `https://api.wadiz.io` |
| `.service(_)` | `friends` · `search` · `searcher` | `https://api.wadiz.io` |
| `.platform(_)` | `global` · `inbox` · `main2` · `wish` · `activities` · `projectMetric` | `https://api.wadiz.io` |
| `.app(_)` | `default` (경로 접두 `/app/api`) | `https://api.wadiz.io` |
| `.api` · `.startupCommon` | — | 설정에서 읽습니다 (`preference.getDomain()`) |
| `.crm` | — | `https://api.wadiz.io` |
| `.searchAI` | — | — |
| `.analytics` | — | `https://analytics.aidata.wadiz.io` |
| `.webOrigin` | — | `https://www.wadiz.io` (Origin 헤더용) |
| `.cdn2` | — | `https://cdn-store.wadiz.io` |
| `.cdn3` | — | `https://cdn-funding-public.wadiz.io` |
| `.cdn4` · `.staticCdn` | — | 각 CDN 호스트 |

**예전 문서와 달라진 곳**

| 항목 | 예전 | 지금 |
|---|---|---|
| `.ad` (광고) | 있음 | **삭제됨** |
| `.crm` · `.cdn2` · `.cdn3` · `.cdn4` · `.staticCdn` | 없음 | **추가됨** |
| 기본 호스트 표기 | `api.wadiz.kr` 또는 유사(추정) | **전 환경 `wadiz.io`** |
| `.service` 하위 | 검색 하나로 뭉뚱그림 | `friends`·`search`·`searcher` 셋 |

> 🔎 **stage 환경만 예외가 있습니다.**
> `.platform` 의 stage 분기에 이런 주석이 붙어 있습니다 —
> *"stage 클러스터에 뜬 플랫폼 구획은 main2뿐이라 나머지는 live 호스트를 그대로 본다"*.
> 즉 stage 에서 `main2` 말고 다른 플랫폼을 부르면 **운영 데이터를 보게 됩니다.**

환경별 호스트는 네 갈래입니다 — `cdev` 는 `api.dev.wadiz.io`, `rc4` 는 `api.rc4.wadiz.io`,
`stage` 와 `live` 는 `api.wadiz.io`, `local` 은 설정에 적은 주소를 씁니다.

Android 도 같은 구조입니다 — `WadizPlatformAPIService`·`WadizServiceAPIService`·`AppV3APIService`·
`WadizWebAPIService`·`WadizStoreAPIService` 처럼 **Retrofit 인터페이스마다 기준 주소가 다릅니다.**

---

## Flow별 앱 매핑

### A1 — 펀딩 코어

#### 1. funding-detail (펀딩 상세)
**Android**: `WadizServiceAPIService.kt` 나 별도 feature API 에서 `/api/search/v2/products` 등으로 카드 조회. 상세 페이지는 대부분 **웹뷰(WebView)** 로 `https://www.wadiz.io/campaign/{id}` 렌더 — 네이티브 API 호출 최소화.
**iOS**: 동상. `Projects/API/Sources/StoreAPI/Interface/StoreAPI.swift` 등에서 홈 카드를 받아 옵니다.

> 📌 대부분의 앱 "프로젝트 상세" 는 WebView 기반 (wadiz-android 의 `feature/catchup`, `feature/service-home`, wadiz-ios 의 `Features/ServiceHome`). 순수 네이티브 상세가 아니라 **하이브리드**.

#### 2. funding-payment (서포팅 결제)
**앱**: 결제 시 WebView 로 `/web/wpurchase/reward/step10/{campaignId}` 진입 → 동일 웹 결제 플로우 사용. 순수 네이티브 결제 화면은 **없는 것으로 관측**.
**참고**: `CreditCardOCR` feature 모듈은 카드번호 OCR 인식만 담당 (Features/CreditCardOCR).

#### 3. funding-reward-select
**앱**: 결제와 동일하게 WebView 경로. 네이티브 선택 UI 없음.

#### 4. my-funding (내 펀딩)
**Android**: `WadizWebAPIService.kt:16` `@GET("/web/mywadiz/supporter/usage-count")` (카운트만). 목록은 feature 모듈에서 WebView 또는 `/web/apip/funding/supporters/my/fundings` Retrofit 호출.
**iOS**: `Projects/API/Sources/WishAPI/Interface/WishAPI.swift` — 찜 쪽입니다.
펀딩 내역은 웹뷰 연동으로 보입니다(추정).
지금 이 파일이 내놓는 것은 둘입니다 — `fetchEndingSoonFundingCount`(마감임박 개수), `fetchDiscountWishedProjects`(할인 찜 목록).

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
**iOS**: `Projects/API/Sources/AccountAPI/Feature/AccountAPIImpl.swift:413`
```swift
// POST /api/v4/check/email
let path = "/api/v4/check/email"
let request = RequestBuilder(apiURLSource: APIURLSource(domain: .api, path: path),
                             method: .post, headers: headers)
    .set(httpBody: ["email": email])
    .build()
```

> **요청 만드는 방식도 바뀌었습니다.** 예전에는 `RequestBuilder(domain:path:method:headers:)` 였는데
> 지금은 `APIURLSource(domain:path:)` 를 따로 만들어 넘기고 `.build()` 로 마무리합니다.
> 이 문서의 다른 iOS 코드 조각도 같은 형태로 읽어야 합니다.

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
**iOS**: `Projects/API/Sources/WebAPI/` 아래로 옮겨졌습니다.
마감임박 지면 전용 경로는 `Projects/Features/EndingSoon/Sources/Data/EndingSoonAPIRepository.swift:50` 에 따로 있습니다.

```swift
// POST /web/reward/api/coupons/templates/redemptions, body { projectNo }
APIURLSource(domain: .api, path: "/web/reward/api/coupons/templates/redemptions")
```

→ 쿠폰은 앱도 `/web/reward/api/*` 경로를 그대로 부릅니다. 웹과 같은 경로입니다.
`/coupons/templates/redemptions` 는 예전 문서에 없던 경로입니다.

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
Host: `api.wadiz.io` (`WadizServiceAPIService` baseUrl).

**iOS**: `Projects/API/Sources/SearchAPI/Feature/SearchAPIImpl.swift:66`
```swift
func fetchSearchPreorder(_ request: SearchFundingRequest) async throws -> SearchFundingResponse {
    let urlRequest = RequestBuilder(apiURLSource: .init(domain: .service(.search), path: "/v2/preorder"),
                                    method: .post, headers: headers)
```

> ⚠️ **경로 표기 방식이 바뀌었습니다.**
> 예전에는 경로에 `api/search/` 를 직접 써 넣었습니다.
> 지금은 **서비스가 접두를 갖고** 경로는 `/v2/preorder` 만 적습니다.
> `domain: .service(.search)` 가 `api/search` 부분을 책임집니다.
> 그래서 소스에서 `api/search/v2/preorder` 를 찾으면 **아무것도 안 나옵니다.**

> 🔎 **확인 필요 — `CategoryAPIStub.swift` 의 행방을 못 찾았습니다.**
> 예전 문서가 `Projects/App/Sources/Development/NetworkStubs/CategoryAPIStub.swift` 에서
> `/api/search/categories`·`/api/search/home` 을 관측했다고 적었는데,
> 지금 저장소에 `Category` 가 들어간 API 파일이 없습니다.
> 테스트 스텁이라 API 재편 때 함께 정리된 것으로 보입니다(추정).

→ **검색은 앱과 웹이 같은 호스트·경로를 씁니다** — `api.wadiz.io/api/search/v2/*`.

#### 14. store-detail
**Android**: `WadizStoreAPIService.kt:11`  `@GET("store/projects/my")`. 기타 스토어 상세는 WebView.
**iOS**: `Projects/API/Sources/StoreAPI/Interface/StoreAPI.swift` 하나로 합쳐졌습니다. 예전에는 두 곳에 나뉘어 있었습니다.
`GET /api/store/orders/my/qty`(주문 수량) 등을 내놓습니다.

#### 15. store-order
**Android**: `WadizStoreAPIService.kt` 및 WadizStoreServiceAPIService (`/api/search/store/`). 주문 자체는 WebView 결제 경유 추정.
**iOS**: `Projects/API/Sources/StoreAPI/Interface/StoreAPI.swift`. 주문 상세는 웹뷰입니다.

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
- `InboxDataSource.kt` — 인박스 (api.wadiz.io)
- `WadizPlatformAPIService.kt` — 푸시/키워드
- `keyword/KeywordAlarmDatasource.kt` — 키워드 알림

**iOS 알림함**: `Projects/API/Sources/InboxAPI/Interface/InboxAPI.swift`
메서드가 셋뿐인 작은 규약입니다.

| 메서드 | 경로 | 하는 일 |
|---|---|---|
| `fetchUnreadMessageCount` | `GET /v4/messages/count-unread` | 안 읽은 개수 |
| `fetchMessageList` | `GET /v6/messages` | 목록 (커서 방식) |
| `readAllMessages` | `PUT /v4/messages/read-all` | 전체 읽음 처리 |

> 🔎 **목록만 v6 이고 나머지는 v4 입니다.** 버전이 섞여 있습니다.
> 목록에 커서(`cursorId`)가 들어가면서 그 경로만 올라간 것으로 보입니다(추정).

호스트는 `domain: .platform(.inbox)` 가 정합니다. live 는 `https://api.wadiz.io` 입니다.

**iOS 알림 설정**: `Projects/API/Sources/CommonAPI/Interface/CommonAPI.swift`

| 경로 | 하는 일 |
|---|---|
| `GET /noti-channel/v2/marketingconsents` | 마케팅 수신 동의 상태 조회 |
| `PUT /noti-channel/v2/marketingconsents?serviceCode=...` | 수신 동의 변경 |
| `POST /api/notification/push/read` | 푸시 읽음 처리. 남은 안 읽은 개수를 돌려줍니다 |

→ 앱 알림함은 플랫폼 호스트를 직접 부릅니다.
웹도 같은 플랫폼 서비스를 쓰지만 경로 접두가 다를 수 있습니다.

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
- **알림 인박스** (`api.wadiz.io/inbox/*`)
- **검색** (`api.wadiz.io/api/search/v2/*` — 웹과 host 동일)
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

1. ~~**앱 전용 V4 API 의 백엔드**~~ — ✅ **2026-09-30 해소.** 별도 저장소가 아니라 **`com.wadiz.web`** 이 처리합니다.

   | 경로 | 구현 파일 |
   |---|---|
   | `/api/v4/login/email` · `/social` | `com.wadiz.web/src/main/java/com/wadiz/api/login/v4/APILoginV4Delegate.java` |
   | `/api/v4/sign-up/email` · `/social` · `/email/code` · `/email/code/verification` | `.../api/waccount/v4/APISignUpV4Delegate.java` |
   | `/api/v4/check/email` | `.../api/waccount/v4/APICheckAccountV4Delegate.java` |

   `web.xml:191-194` 가 `/api/*` 를 Jersey 서블릿에 붙이고, 각 델리게이트의 `@Path` 가 뒷부분을 맡습니다.
   예전 문서가 추측한 `app-api`·`mobile-api` 는 **아닙니다.**
   `app-api` 의 컨트롤러 접두는 `event`·`funding/projects`·`links`·`proxy`·`redirect`·`settings`·`support`·`webhooks` 여덟이고
   로그인·가입 경로가 없습니다.

   > 즉 **앱 로그인·가입은 웹 서비스가 그대로 받습니다.**
   > 화면만 앱 전용이고 뒷단은 웹과 같은 서비스라는 뜻입니다.
2. **WebView URL 수신 · JS Bridge** — 앱과 웹 간 메시지 교환은 `feature/catchup`, iOS `Features/Navigator` 등에 있을 것으로 추정, 본 문서 범위 외.
3. **SDUI (Server-Driven UI)** — Android 의 `core/server-driven-ui` 모듈 존재. 홈·피드 일부를 SDUI 로 내려받는 것으로 보이는데 본 문서는 미포함.
4. **각 feature 모듈별 Repository → UseCase → Service 체인** — 본 매핑은 API path 수준까지만. 각 feature 내 `data/remote` · `domain/usecase` 레이어 분석은 Phase 2 앱 분석 범위.
5. **경로 일치 확인** — 앱 `/api/funding/wishes` vs 웹 `/web/apip/funding/wishes` 가 같은 funding 서비스 엔드포인트로 귀결되는지 (gateway 라우팅 차이) 확인 필요.
