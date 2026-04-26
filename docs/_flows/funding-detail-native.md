# Flow: 펀딩 상세 — 하이브리드 네이티브 (Android · iOS · Web)

> 펀딩 프로젝트 상세 페이지의 **새로운 하이브리드 아키텍처** 분석. 기존 [`funding-detail.md`](./funding-detail.md) 의 "앱은 WebView 위임" 가정 보강 — 실제로는 **앱이 상단 영역을 네이티브로 렌더하고, 본문은 WebView, 양측이 AppBridge 로 동기화** 하는 하이브리드.

## 기록 범위
- **읽은 파일**:
  - `wadiz-ios/docs/FE1-35-펀딩상세-네이티브-구현-결과.md` (사내 비교 분석 문서)
  - `wadiz-ios/Projects/App/Sources/WebView/Detail/` (전체 구조)
  - `wadiz-ios/Projects/App/Sources/WebView/Detail/Data/API/FundingDetailAPI.swift:26-79`
  - `wadiz-android/feature/detail/src/main/java/com/wadiz/feature/detail/screen/*.kt` (Compose 섹션)
  - `wadiz-android/core/domain/src/main/java/com/wadiz/domain/usecase/{GetFundingDetailDataUseCase,GetFundingDetailActionUseCase,ParseFundingDetailUrlUseCase}.kt`
  - `wadiz-android/core/network/src/main/java/com/wadiz/network/service/api/AppV3APIService.kt:335`
  - `wadiz-frontend/packages/features/src/native-detail/index.ts`
  - `wadiz-frontend/packages/features/src/native-detail/lib/withNativeHeaderSpec.ts:1-40`
- **외부 경계**: AppBridge (`@wadiz/core/lib/AppBridge`) 의 native ↔ web 메시지 프로토콜 내부, `inAppWebviewPolicy` 의 환경 판별 로직, BE 의 `/api/funding/native/v1/*` 응답 스키마 (별도 백엔드 repo).

---

## 🔑 핵심 발견 (이전 분석 정정)

이전 [`funding-detail.md`](./funding-detail.md), [`app-mapping.md`](./app-mapping.md) 에서는 **"앱은 펀딩 상세를 WebView 단순 위임"** 으로 기술했음. 실제 아키텍처는 다름:

> 앱이 **상단 영역(헤더·인트로·메이커정보·달성률·스토어배너 등)을 네이티브 Compose/SwiftUI 로 렌더**하고, 그 아래 **본문(스토리·뉴스·커뮤니티·리워드)은 WebView** 로 띄움. 두 영역은 **AppBridge** 로 헤더 높이·스크롤·이벤트를 동기화.

이로 인해:
- **새 BE 엔드포인트** `/api/funding/native/v1/projects/{projectNo}` 가 네이티브용 데이터(이미지·메이커·달성률·AI요약 등)를 한 번에 내려줌
- **웹 측** 은 WebView 안에 있을 때 자기가 in-app 임을 감지하고, **상단 영역을 비워주거나 축소** (네이티브가 그린 영역과 겹치지 않게)

---

## 1. iOS — `wadiz-ios/Projects/App/Sources/WebView/Detail/`

### 1.1 디렉터리 구조
```
WebView/Detail/
├── FundingDetailAssembly.swift          # DI Assembly
├── ProjectDetailURLMatcher.swift        # URL → projectNo 파싱
├── EventTrack/
│   ├── TrackFundingDetailEventUseCase.swift
│   ├── HeaderImpressionTracker.swift
│   ├── FundingDetailEvent.swift
│   └── DetailImpressionModifier.swift
├── Data/
│   ├── DTO/
│   │   ├── FundingDetailResponse.swift
│   │   ├── FundingDetailMakerInfoResponse.swift
│   │   ├── AdultVerificationResponse.swift
│   │   └── CollectionDetailBanner.swift
│   ├── API/
│   │   └── FundingDetailAPI.swift           # ★ 네이티브 API 호출 4종
│   ├── FundingDetailRepositoryImpl.swift
│   ├── FundingDetailCache.swift
│   ├── FundingDetailError.swift
│   ├── FundingDetailHeaderModel.swift
│   └── AdultVerificationStatus.swift
├── Domain/
│   ├── FundingDetailRepository.swift
│   ├── GetFundingDetailUseCase.swift                # ★ 핵심 유스케이스
│   └── GetFundingDetailCollectionBannerUseCase.swift
└── Presentation/
    ├── ProjectDetailSkeletonView.swift
    └── View/
        ├── FundingDetailHeaderImageView.swift
        ├── FundingDetailHeaderView.swift           # ★ 메인 컨테이너
        ├── FundingDetailMakerInfoView.swift
        ├── FundingDetailInfoView.swift
        ├── FundingDetailAchievementView.swift
        ├── FundingDetailComingSoonDateView.swift
        ├── FundingDetailAISummaryView.swift
        ├── FundingDetailStoreBannerView.swift
        └── (YouTubePlayerView)
```

### 1.2 네이티브 API 호출
```swift
// Data/API/FundingDetailAPI.swift
func projectInfo(with projectNo: Int) async throws -> FundingDetailDataResponse {
    let path = "/api/funding/native/v1/projects/\(projectNo)"        // ★ 신규 BE
    let request = RequestBuilder(domain: .api, path: path, method: .get).build()
    ...
}

func projectMakerInfo(with projectNo: Int) async throws -> ... {
    let path = "/web/maker/REWARD/\(projectNo)"                      // 기존 web 경로
}

func projectCollectionBanner() async -> ... {
    let path = "/api/search/v2/funding"                              // service.wadiz.kr
}

func adultVerification() async throws -> String? {
    let path = "/api/v3/account/adult-verification/my"               // app V3 API
}
```

### 1.3 GetFundingDetailUseCase 분기
- **대기열 + 면제 카테고리** 2개 병렬 (대기열일 땐 detail 호출 절약)
- **비공개 프로젝트** → `fallbackToWeb`
- **성인 콘텐츠 + 비로그인** → `fallbackToWeb`
- **성인 콘텐츠 + 미인증** → `fallbackToWeb`
- 정상 → `return headerData`

### 1.4 미리보기·preview 분기
`NavigationMap+WebView.swift` 의 `canUseNativeHeader(routeURL:)` 가 URL 쿼리 `?preview=Y` 검출 → 네이티브 헤더 미사용 → 전체를 WebView 로.

---

## 2. Android — `wadiz-android/feature/detail/`

### 2.1 디렉터리 구조
```
feature/detail/src/main/java/com/wadiz/feature/detail/
├── DetailViewModel.kt
├── NativeAreaWebFragment.kt              # ★ 네이티브 + WebView 컨테이너 Fragment
├── di/                                   # Hilt 모듈
├── reuse/                                # WebView 재사용 (메모리 절약)
└── screen/
    ├── FundingDetailScreen.kt            # ★ 메인 Compose 진입점
    ├── FundingDetailContent.kt           # ★ 컨텐츠 컨테이너
    ├── DetailMediaSection.kt             # 이미지/영상
    ├── DetailMakerSection.kt             # 메이커
    ├── DetailTitleSection.kt             # 제목/설명
    ├── FundingStatsSection.kt            # 달성률/모금액
    ├── StorySummarySection.kt            # AI 스토리 요약
    ├── StoreBannerSection.kt             # 스토어 배너
    ├── CollectionBannerSection.kt        # 컬렉션 배너
    ├── DetailBanner.kt                   # 한국 전용 안내 배너
    └── MeasuredContent.kt
```

### 2.2 네이티브 API
```kotlin
// core/network/.../service/api/AppV3APIService.kt:335
@GET("/api/funding/native/v1/projects/{projectNo}")
suspend fun getFundingDetailNative(@Path("projectNo") projectNo: Int): FundingDetailDTO
```
iOS 와 **동일 BE 엔드포인트**.

### 2.3 UseCase 3종
- `GetFundingDetailDataUseCase` — 데이터 조회 + 분기 (iOS 와 1:1 매핑)
- `GetFundingDetailActionUseCase` — 사용자 액션 (펀딩하기·공유 등)
- `ParseFundingDetailUrlUseCase` — URL → projectNo 추출 (iOS `ProjectDetailURLMatcher` 와 동일 역할)

### 2.4 `NativeAreaWebFragment` — 하이브리드 컨테이너
이 Fragment 가 **상단(Compose 네이티브) + 하단(WebView)** 을 한 화면에 결합. 핵심 클래스명이 패턴 자체를 표현: "Native Area + Web Fragment".

### 2.5 WebView 재사용
`reuse/` 디렉터리 — 신규 추가된 모듈 (`ReuseWebViewCompTest.kt`, `WebViewTraceResultTest.kt` 테스트도 추가). WebView 인스턴스 풀링으로 메모리·초기화 비용 절감.

---

## 3. Web — `wadiz-frontend/packages/features/src/native-detail/`

웹은 WebView 내부에서 동작하면서 **네이티브와 협업**.

### 3.1 모듈 구조
```
packages/features/src/native-detail/
├── index.ts                                  # 배럴
├── components/NativeAwareIntro.tsx           # 네이티브 인지 인트로
├── context/NativeDetailContext.tsx           # NativeDetailProvider + useNativeDetailPage
├── hooks/useNativeDetailPage.ts              # 페이지 hook
└── lib/withNativeHeaderSpec.ts               # ★ AppBridge 호출
```

### 3.2 `withNativeHeaderSpec` 핵심
```ts
// lib/withNativeHeaderSpec.ts:1-40
import { appBridge } from '@wadiz/core/lib/AppBridge';
import { inAppWebviewPolicy } from '@wadiz/core/policies/inAppWebviewPolicy';

export interface NativeHeaderSpec {
  isVisible: boolean;
  heightPx: number;
  includesSafeArea: boolean;
}

export const withNativeHeaderSpec = async <T extends Record<string, unknown>>(
  data: T,
): Promise<T & { headerSpec?: NativeHeaderSpec }> => {
  if (!inAppWebviewPolicy.isNativeDetailPageSupported) {
    return data;                                                  // 일반 브라우저 — 그대로
  }

  try {
    const headerSpec = await appBridge.request('topArea.spec.request', {}, 2000);
    return { ...data, headerSpec };                               // 네이티브로부터 헤더 스펙 수신
  } catch (error) {
    console.error('Error fetching header spec:', error);
    return data;
  }
};
```
- **2초 타임아웃** — 네이티브 응답 늦으면 fallback (헤더 스펙 없이)
- **`appBridge.request('topArea.spec.request', {}, 2000)`** — 메시지 이름이 핵심
- 응답: `{ isVisible, heightPx, includesSafeArea }` — 웹이 자기 상단을 그릴 때 이 spec 만큼 비워둘지/축소할지 결정

### 3.3 `inAppWebviewPolicy` 환경 판별
- 일반 브라우저 → 정상 모드
- 앱 WebView (네이티브 상세 지원 버전) → 네이티브와 협업 모드

### 3.4 funding-detail 페이지에서 사용
[`funding-detail.md`](./funding-detail.md) 의 § 1.1 페이지(예: `apps/global/src/pages/funding/[projectNo]/story/FundingDetailStoryPage.tsx`) 데이터 로더가 `withNativeHeaderSpec(rawData)` 를 호출 → 헤더 spec 받아 적절한 컴포넌트 분기.

---

## 4. 백엔드 — `/api/funding/native/v1/projects/{projectNo}`

새로운 **앱 전용 통합 BE 엔드포인트**.

### 4.1 응답 데이터 (사내 doc 기반 추정)
- 이미지/영상 URL
- 메이커 정보 (compact)
- 한국 전용 배너 정보
- 달성률·모금액·서포터 수·뱃지
- 오픈 예정일 (BEFORE_PROGRESS 시)
- AI 스토리 요약
- 스토어 배너 정보 (할인율, 프로모션 아이콘)
- 펀딩 일시중지 상태
- 성인 콘텐츠 플래그 (분기용)

### 4.2 BE 위치
이 레포 내에서는 controller 미관측. 추정:
- `com.wadiz.api.funding` 의 신규 `native` 패키지 (Phase 2 funding 분석에서 미커버 시점)
- 또는 별도 mobile-api 서비스 (app.wadiz.kr 또는 별도 host)

본 분석 범위 외. 별도 추적 권장.

### 4.3 연관 데이터 호출
iOS API 파일 기준, 네이티브 상세는 위 통합 API 외에:
- `/web/maker/REWARD/{projectNo}` — 메이커 정보 (com.wadiz.web 경유)
- `/api/search/v2/funding` — 컬렉션 배너 (service.wadiz.kr)
- `/api/v3/account/adult-verification/my` — 성인 인증 상태

도 호출함.

---

## 5. AppBridge 메시지 프로토콜 (관측된 것만)

| 메시지 | 방향 | 내용 |
|---|---|---|
| `topArea.spec.request` | Web → Native | 네이티브가 그린 상단 영역의 spec(높이·SafeArea 포함 여부) 요청 |
| (응답) | Native → Web | `{ isVisible, heightPx, includesSafeArea }` |

기타 메시지(스크롤 동기화, 이벤트 추적, 페이지 이벤트 등)는 본 문서 범위 외 — `@wadiz/core/lib/AppBridge` 구현 추적 필요.

---

## 6. 컴포넌트 매핑 — 웹 vs iOS vs Android

| 웹 컴포넌트 (apps/global) | iOS View | Android Section |
|---|---|---|
| ProjectIntro | `FundingDetailHeaderImageView` (+ YouTubePlayerView) | `DetailMediaSection.kt` |
| ParticipationRestrictionBanner | `FundingDetailHeaderView.koreaOnlyBannerView` | `DetailBanner.kt` (한국 전용 배너) |
| MakerInfoCompactSection | `FundingDetailMakerInfoView` | `DetailMakerSection.kt` |
| ProjectOverviewSection | `FundingDetailInfoView` (+ adultBadgeView) | `DetailTitleSection.kt` |
| FundingStatus | `FundingDetailAchievementView` | `FundingStatsSection.kt` |
| FundingComingSoonDate | `FundingDetailComingSoonDateView` | (미관측 추정) |
| StorySummarySection (AI) | `FundingDetailAISummaryView` | `StorySummarySection.kt` |
| StoreBanner | `FundingDetailStoreBannerView` | `StoreBannerSection.kt` |
| FundingPaused | `FundingDetailHeaderImageView.fundingPausedOverlay` | (미관측 추정) |

> 누락: iOS `BEFORE_PROGRESS` 상태 분기 뷰 없음 (사내 doc 명시).

---

## 7. 엔드투엔드 시퀀스

```
[사용자: 앱에서 펀딩 프로젝트 카드 탭]
    │
    ▼
[App: ParseFundingDetailUrlUseCase / ProjectDetailURLMatcher]
    │ URL → projectNo 파싱
    ▼
[App: GetFundingDetailUseCase]
    ├─ 병렬 호출
    │   ├─ /api/funding/native/v1/projects/{projectNo}    ← 네이티브 통합 데이터
    │   ├─ 대기열 / 면제 카테고리 / 성인 인증 상태       ← 분기 데이터
    │   └─ /api/v3/account/adult-verification/my          (필요 시)
    │
    ├─ 분기:
    │   ├─ 비공개 / 대기열 → fallbackToWeb (전체 WebView)
    │   ├─ 성인 + 비로그인/미인증 → fallbackToWeb
    │   └─ 정상 → DrawNativeScreen
    │
    ▼
[App: 화면 렌더]
    │
    ├─ 상단 영역 (네이티브)
    │   iOS: FundingDetailHeaderView + 8개 SwiftUI View
    │   Android: NativeAreaWebFragment + Compose 9개 Section
    │
    └─ 하단 영역 (WebView, www.wadiz.kr/.../funding/{projectNo}/story)
         │
         │ 웹뷰 로드 → 페이지 데이터 로더
         ▼
    [Web: withNativeHeaderSpec(data)]
         │ inAppWebviewPolicy.isNativeDetailPageSupported?
         │   true → AppBridge.request('topArea.spec.request', {}, 2000ms)
         ▼
    [App → Web: { isVisible, heightPx, includesSafeArea }]
         │
         ▼
    [Web: 본문 렌더]
         │ headerSpec.heightPx 만큼 상단 padding/spacer
         │ 자기 상단 영역(중복) 제거 → 본문(스토리/뉴스/커뮤니티/리워드)만 표시
         ▼
    [최종 화면: 네이티브 헤더 + WebView 본문 자연스럽게 결합]

    ※ 이후 스크롤·이벤트는 AppBridge 로 양방향 동기화 (별도)
```

---

## 8. 영향 — 이전 분석 정정

| 이전 표기 | 정정 |
|---|---|
| "펀딩 상세는 앱이 WebView 단순 위임" | **하이브리드 — 상단 네이티브 + 본문 WebView, AppBridge 동기화** |
| "앱 매핑 누락 — Phase 2 미진행" | **iOS `WebView/Detail/`, Android `feature/detail/` 위치 확정** |
| "WebView ↔ 네이티브 JS Bridge 별도 분석 필요" | **`@wadiz/core/lib/AppBridge` + `topArea.spec.request` 메시지 1건 관측** |

---

## 9. 경계·미탐색

1. **`/api/funding/native/v1/projects/{projectNo}` 백엔드 구현 위치** — 이 레포(`repos/`)에 controller 미관측. com.wadiz.api.funding 의 새 native 도메인 또는 별도 mobile-api 서비스 추정.
2. **AppBridge 전체 메시지 카탈로그** — `topArea.spec.request` 외 스크롤·이벤트·페이지 라이프사이클 메시지가 다수 있을 것. `@wadiz/core/lib/AppBridge` 추적 필요.
3. **`inAppWebviewPolicy.isNativeDetailPageSupported`** 판별 로직 — User-Agent? 커스텀 헤더? AppBridge 사전 핸드셰이크?
4. **WebView 재사용 풀** (Android `reuse/`) — 인스턴스 수, 라이프사이클, 메모리 누수 방지 정책.
5. **fallback 시나리오** — 네이티브 BE 실패, AppBridge 타임아웃, 부분 데이터 등 다양한 실패 경로의 UX.
6. **이벤트 추적** — iOS `EventTrack/HeaderImpressionTracker` 외 임프레션·체류시간·스크롤 깊이 추적 정밀도.
7. **버전 호환성** — 구버전 앱(네이티브 상세 미지원) 사용자에 대해 웹은 어떻게 감지하고 일반 모드로 동작하는지.
8. **iOS vs Android UseCase 미세 차이** — 사내 doc 기준 "병렬 호출 개수 차이" (iOS 2병렬, Android 3병렬) 등 작은 차이가 있어 일관성 검토 가치.

---

## 관련 문서
- 기존 [`funding-detail.md`](./funding-detail.md) — 데스크톱·일반 웹 흐름 (com.wadiz.web → MyBatis → MySQL)
- [`app-mapping.md`](./app-mapping.md) — 18 flow × Android/iOS 매핑 (펀딩 상세 부분 본 문서로 보강)
- iOS 사내 비교 분석: `wadiz-ios/docs/FE1-35-펀딩상세-네이티브-구현-결과.md`
- 추가 사내 spec: `wadiz-frontend/apps/global/src/pages/funding/[projectNo]/_spec/{NATIVE_DETAIL_FLOW,FIGMA_ANALYSIS,SCROLL_ISSUES,RENDER_EVENT_REFACTOR,STYLE_CHANGES}.md`
