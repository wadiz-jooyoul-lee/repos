# Wadiz Android (wadiz-android) 분석

> 크라우드펀딩 플랫폼 **Wadiz**의 공식 Android 클라이언트.
> 본 문서는 repo 의 빌드 설정, 모듈 구조, **어떤 API 가 어떤 백엔드에서 어떤 기능 용도로 호출되는지** 를 실제 코드 기준으로 정리한다.

---

> 📅 **2026-07-31 main pull 보강** (직전 갱신 2026-07-21 이후 187커밋, ~ v26.30.0 build 587)
>
> **마감임박(막펀잡기, Final Call) 피드 신규 모듈**이 이번 릴리즈의 핵심입니다. 그 외 위시 지면 노출 구좌, 리워드 선택 모달 공용화, OkHttp 커넥션 풀 공유, SNS 로그인 실패 계측, 검증 자동화 하네스 재도입이 포함됩니다. (버전 자동 업데이트 커밋 다수 생략)
>
> ### PRODUCT-859 / FE1-1237·1240·1241·1246·1248 — 마감임박(막펀잡기) 피드 신규 feature 모듈
> - `feature:ending-soon` 모듈 신설(`settings.gradle.kts:60`). GNB "위시" 탭 자리를 마감임박 피드로 대체(A-1). `CatchUpFragment` 미러링 구조의 풀 컴포즈 화면 — `feature/ending-soon/.../endingsoon/EndingSoonFragment.kt`, `EndingSoonScreen.kt`, `EndingSoonViewModel.kt`, `compose/EndingSoonCardView.kt`·`EndingSoonFeedPager.kt`·`EndingSoonProgressBar.kt`
> - 신규 API 2종(`serviceUrl`): 마감임박 리스트 `GET /api/search/v1/catchup/ending-soon`, ID 목록 상품 조회 `GET /api/search/v2/products` (`core/network/.../service/service/WadizServiceAPIService.kt:64,73`). DTO `EndingSoonListResponse`/`EndingSoonProductsResponse`, 리포지토리 `core/data/.../repository/endingsoon/RealEndingSoonRepository.kt`, 모델 `core/model/.../model/endingsoon/EndingSoonItemModel.kt`
> - 자동넘김 5초 롤링, 카드 전체 1콜 조회(청크 페이징 폐기), 마지막 카드 이어보기 DataStore 영속, 서버시각 앵커 기반 모노토닉 시계(`core/common/.../time/MonotonicClock.kt`, `core/model/.../endingsoon/ServerTimeAnchor.kt`) 도입
> - FE1-1248: "막펀잡기" 리네임 + waditag 수집 배선(지면명 정정). FE1-1259: 하드코딩 문자열 i18n 키 전환. FE1-1296: 환기형 카드 width 통일
>
> ### 막펀잡기 후속 (FE1-1327·1328·1332·1337·1339·1340·1343·1351)
> - FE1-1327: GNB 막펀잡기 등장 애니메이션(세션당 1회, `feature/.../view/main/AppSessionTracker.kt`). FE1-1339: 자동넘김 5초·타이틀 폰트 16. FE1-1351: 드래그 중 롤링 정지·넘김 취소·재무장
> - FE1-1328: Braze `finalcall_pv`(마감 5초 유예 게이트)·`finalcall_complete`(마지막 카드 첫 도달 1회) 이벤트. FE1-1332: 쿠폰 뱃지 정액/정률 max 노출
> - FE1-1337: 딥링크 네이티브 진입 — `ScreenKey.ENDING_SOON`→`ENDING_SOON_CATCHUP` 리네임, `remote_config_defaults.json` navigationMap 라우트 추가. FE1-1343: 국가 변경 시 이어보기 초기화. FE1-1340: BNB 위시 팝퍼 미사용 코드 제거
> - 관련 QA: QA-22764(막펀잡기 상태바 다크·시스템바 역할별 리네임·더보기 버튼명 잘림), QA-22798(프로그래스바 정지 상태 상세 이동 후 유지), QA-22705(찜 토스트 탭 랜딩)
>
> ### FE1-1256 / FE1-1321 / FE1-1325 — 마이와디즈 찜한 펀딩 환기영역(위시 지면 노출 구좌)
> - 마이와디즈 대시보드 타입에 `WISH` 추가(데이터 수집, `MyWadizSupporterDTO.kt`). 환기영역 노출 개수 제한, `sectionId` 참조 제거. QA-22767: 찜 영역 스크롤 시 하단 서포터클럽 영역이 함께 움직이던 현상 수정
>
> ### FE1-1275 — 리워드 선택 웹 모달 공용 런처 + toast.show 웹뷰 브릿지
> - 프로젝트 번호만 넘기면 표준 스펙으로 여는 전역 런처 `feature/.../navigation/RewardSelectionModalLauncher.kt`(80% 고정 바텀시트, 중복 가드), `core/ui/.../webview/modal/ModalWebViewConfig.kt`
> - `toast.show` 웹뷰 브릿지를 공통 처리로 승격 — 레거시 웹뷰 포함 전 호스트 지원, 상단 커스텀 토스트 렌더(warning 타입 = 빨간 에러 토스트)
>
> ### FE1-1109 — OkHttp 커넥션 풀·디스패처 공유 (API 첫 요청 지연 개선)
> - 모든 API Provider가 커넥션 풀·디스패처를 공유하는 `SharedOkHttpClient` 도입(`core/network/.../service/SharedOkHttpClient.kt`). `maxIdleConnections=10`, `maxRequestsPerHost=64`, `maxRequests=128`. Provider별로 흩어진 host당 상한(각 25)을 통합
>
> ### FE1-1323 — SNS 로그인 SDK 인증 단계 실패 계측
> - 서버 도달 전(SDK 초기화·인증) 실패를 진단할 수 없던 공백 해소. `core/analytics/.../analytics/SnsSignInLogger.kt` 가 provider/errorCode를 **이벤트 스코프 커스텀 키**로 부착해 non-fatal 기록(세션 전역 키 오염 방지). 취소 경로 계측 유실 수정. Kakao/Naver/Line/Facebook 예외 타입 추가
>
> ### 쿠폰·개발 인프라
> - FE1-1332 쿠폰: 국가별 게이트를 `hasCoupon` 권위값 신뢰로 변경(금액 파생 제거). `DownloadBoosterCouponsUseCase`, `WishBadgeUseCase` 신규
> - FE1-1290: 다국어 동기화 워크플로 통합(고정 `i18n-sync` 브랜치, PR 방식 전환, 셸 인젝션 회피). FE1-1262/1246: PR 변경 모듈 단위 유닛 테스트 CI(`.github/workflows/pr-changed-module-test.yml`)
> - FE1-1180~1183 검증 자동화 하네스 **재도입**(직전 릴리즈의 전량 Revert를 다시 Revert). 신호 프로토콜(레지스트리 JSON + 드리프트 검사기)·`scripts/tc/` 재편, `/write-tc`·`i18n-key-extract`·`android-intent-security` 스킬 추가
> - FE1-1237 gradle wrapper 공식 9.4.1 재생성, FE1-1286 qa 빌드 소스셋에 개발 환경 주소 포함, FE1-1120 누락 `consumer-rules.pro` 추가. 의존성 bump(google-services 4.5.0, firebase-bom, rootbeer-lib, libphonenumber)
>
> ---
>
> 📅 **2026-07-21 main pull 보강** (직전 갱신 2026-07-10 이후, v26.27.2 ~ v26.29.2)
>
> 앱 세션 재시작, 구글 로그인 가드, GNB 재사용 웹뷰 예외 수정, 데이터 수집 정합이 핵심입니다. (버전 자동 업데이트 커밋 다수 생략)
>
> ### FE1-1201 / FE1-1232 — 앱 세션 재시작 기능
> - 앱 세션 재시작 기능 구현(`webview/SessionSyncManager.kt`) + 재시작 다이얼로그 다국어 반영.
>
> ### FE1-1289 / FE1-1224 — 로그인·웹뷰 안정화
> - FE1-1289: 구글 로그인 가드 코드 추가(`network_security_config.xml` 등).
> - FE1-1224: GNB 재사용 웹뷰 `addView` 시 `IllegalStateException` 수정(`view/main/web/reuse/owner/ReuseWebViewContainer.kt`).
>
> ### FE1-1235 / FE1-1263 / FE1-1230 — 데이터 수집·노출 정합
> - FE1-1235: 최근검색어 등록/조회 3개 API에서 식별자 없으면 전송 제외·검증(`QA-22665` 저장 판정 로직 추출 포함).
> - FE1-1263: 마이와디즈 서포터 메뉴 클릭 이벤트가 메이커로 잘못 수집되던 문제 수정. QA-22652: authPromo 가입유도모달 데이터 수집(라벨 한글화·More 클릭 수집).
> - FE1-1230: 에디션 뱃지 노출 조건 수정. QA-22697: 검색 홈 프로젝트 카드 메이커명 미표기 수정.
>
> ### 기타
> - FE1-806 clive 대응. FE1-1180~1183(검증 자동화·상태채널·자기교정루프·스킬개편) 머지 **전량 Revert** 후 render-surface 모델 기반 테스트 하네스(`/write-tc`·`/dev-test` 스킬, `scripts/tc-*`)로 재설계.
>
> ---
>
> 📅 **2026-07-10 main pull 보강** (직전 갱신 2026-06-19 이후 132커밋, v26.24 ~ v26.27.2)
>
> ### FE1-992 — 와디즈 에디션 GNB 웹뷰 탭 신설
> - 홈 상단 GNB에 "에디션" 진입점을 추가하고, 별도 네이티브 화면이 아닌 **GNB 웹뷰**로 렌더하는 신규 탭 도입. 전용 프래그먼트/컴포저와 웹뷰 보관 객체를 신설 (`feature/main-tab/src/main/java/com/markmount/wadiz/view/main/edition/EditionGnbFragment.kt`, `feature/main-tab/.../view/main/gnb/GnbWebViewScreen.kt`, `GnbWebViewModel.kt`, `feature/src/main/java/com/markmount/wadiz/view/main/GnbWebViewRetainer.kt`)
> - GNB 웹뷰 로드 동작(loadUrl/reload)·URL 결정 로직을 store(Retainer)로 일원화하고, `GnbWebViewStore → GnbWebViewRetainer` 로 네이밍 정리. 에디션 기획전 URL을 네비게이션 맵(`NavigationState.kt`)에 추가하고 GA 태깅·딥링크·피드 앱바를 보정
> - prefetch 미지원 기기에서 에디션 탭이 빈 화면 뜨던 문제 수정(웹뷰 등록을 prefetch 최적화 가드 밖으로 분리), 웹 가로 스크롤 영역(`touch.started`) 수신 시 SwipeRefresh가 가로 터치를 부모에 넘기지 않도록 처리 (`feature/.../webview/common/CommonWebMessageHandler.kt`). 에디션 GNB 아이콘 drawable 신규 (`core/design-system/src/main/res/drawable/ic_edition*.xml`, `artwork_tint_edition_*.xml`)
>
> ### FE1-1005 / 1020 / 1021 / 1022 / 1024 — Firebase Remote Config 실시간 반영 파이프라인
> - **포그라운드**: Realtime 리스너(`addOnConfigUpdateListener`)의 `onUpdate`에서 로그만 남기고 `activate()`를 호출하지 않아 push된 변경분이 active로 승격되지 않던 문제 수정 — `onUpdate`에서 `activate()` 호출(IO 디스패처) (`core/data/.../data/remote/firebase/RemoteConfigImpl.kt`)
> - **백그라운드**: Realtime 리스너가 포그라운드 전용이라, 앱 복귀 시 `AppObserver.onStart` 재fetch 및 15분 주기 `WorkManager PeriodicWork`(`RemoteConfigSyncWorker`, `core/work`)로 백그라운드 fetch+activate 데워두기. `WadizInitializer.scheduleRemoteConfigSync()`로 분리, `enqueueUniquePeriodicWork(KEEP)` 등록
> - **race 수정**(FE1-1024): 설정 적용 시 `settings/defaults await` 로 초기 fetch 순서 보장, `runCatching`의 `CancellationException` 일관 전파
>
> ### FE1-994 — 클라우드(Cloud) 전환 시 스타트업 메뉴 비노출
> - Cloud 서버는 스타트업 서비스를 제공하지 않으므로 더보기 그리드 메뉴를 `buildList`로 변경해 `serverMode.isCloud()` 시 "스타트업 찾기" 항목 제외 (`feature/more/.../feature/more/HomeMoreViewModel.kt`)
>
> ### FE1-1052 / 1016 — 최근 검색어 서버 전송 시점·식별자 변경
> - (FE1-1052) 최근 검색어 칩·인기검색어·인기/광고태그를 **탭한 시점에 즉시** `addHistory`(user-activity 등록)하도록 변경. 기존엔 결과 첫 스크롤/카드 클릭 시에만 전송됐음. `registerRecentKeyword()` 헬퍼 + `isSameLastKeyword` 중복 전송 가드
> - (FE1-1016) 최근 검색어 등록/삭제 `deviceId` 소스를 `getUUID()` → 쿠키 `_waid`(`getWadizWaIdCookieValue`)로 변경, 로그인 무관 항상 전송·부재 시 null 허용. `getWaIdCookieValue()`가 bare host를 `CookieManager`가 파싱 못 해 항상 null 반환하던 잠재버그 수정(`https://` 접두 보강) — 비로그인 메인 홈 waId도 복구 (`core/common/.../common/StringExt.kt`, `WadizPlatformAPIService.kt`, `WadizPlatformDataSource.kt`)
>
> ### FE1-995 / 972 — PIP 라이브커머스 분석·크래시
> - (FE1-995) PIP 라이브커머스(`/web/live`) 웹뷰가 웹→앱 PV 위임(`WebInterface.sendAnalyticsData`)을 연결하지 않아 waditag PV(tagview)가 누락되던 문제 수정. `CommonWebMessageHandler` 재사용, Braze/AppsFlyer 이벤트 위임 배선, 검색 위 PIP 콘텐츠 이동 수정 (`feature/.../view/pip/PipViewModel.kt`, `PipWebViewHolder.kt`, `PipActivity.kt`)
> - (FE1-972) PIP 크래시 수정
>
> ### FE1-1013 — 휴대폰 인증 429(TOO_MANY_AUTHENTICATION_CODE_REQUESTS) 대응
> - 인증번호 요청 엔드포인트를 `/web/v3/account/phone-number/code` → **`/api/v3/account/phone-number/code`** 로 변경(본 문서 아래 표도 반영). `ErrorCode`에 `TOO_MANY_AUTHENTICATION_CODE_REQUESTS` 추가해 인증 횟수 초과 전용 안내 문구(따라잡기 본인인증 + 공통 본인인증 i18n) 노출 (`core/network/.../network/service/api/AppV3APIService.kt:270`, `.../network/error/ApiErrorException.kt`)
>
> ### 네비게이션·웹뷰 안정화 (버그픽스 묶음)
> - FE1-1103 오프라인 상세 진입 후 뒤로가기 먹통 수정(진입 인덱스 -1 오판 → 유효 인덱스 커밋 전까지 미기록, 성공 로드 시 재캡처)
> - FE1-1067 뒤로가기 시 성인인증 재노출 수정(`ReuseWebFragment`), FE1-964 탑레벨 재진입 스택정리(`NavigationState.kt`, `deeplink_v2.html`)
> - FE1-1098 웹뷰 프리패치 크래시(`AwPrefetchManager.onPrefetchResponseCompleted`) — 콜백 executor를 `Runnable::run` → null(메인스레드 기본 동작)로 변경 (`GnbWebViewRetainer.kt`)
> - FE1-1000 인트로 로딩 중 백그라운드 전환 시 이메일 인증 다이얼로그 크래시, FE1-1081 검색결과 카테고리 모달 데이터 오수집, QA-22393 알림 유도 모달 중복 노출 차단
>
> ### FE1-880 / 893 — 하네스 엔지니어링 v1 (개발 도구, 앱 런타임 무관)
> - Claude Code 세션 대상 품질 게이트 도입: `config/detekt/detekt.yml`(네이밍 + `UndocumentedPublic*` focused 룰) + `config/detekt/baseline.xml`(기존 위반 19,508건 스냅샷 면제, 신규만 검사), Stop 훅 `.claude/hooks/stop_detekt_check.py`
>
> ### 기타
> - FE1-967 펀딩 페스티벌 기획전 시즌 앱 런처 아이콘 변경, FE1-1069 Clarity SDK 3.8.0 → 3.8.2 업그레이드, FE1-1084 와디즈 에디션 노출 이슈 수정

---

## 개요

| 항목 | 값 | 참조 |
| --- | --- | --- |
| 패키지 / applicationId | `com.markmount.wadiz` | `buildSrc/src/main/kotlin/AppBuildConfig.kt:7` |
| 지원 OS 최소 | `minSdk = 26` (Android 8.0 Oreo) | `buildSrc/src/main/kotlin/AppBuildConfig.kt:6` |
| 컴파일/타겟 SDK | `targetSdk = 35` / `compileSdk = 35` | `buildSrc/src/main/kotlin/AppBuildConfig.kt:5` |
| JVM / Kotlin JVM target | `JavaVersion.VERSION_17` / `JVM_17` | `buildSrc/src/main/kotlin/AppBuildConfig.kt:8`, `app/build.gradle.kts:211` |
| 버전 (Release) | `26.14.3` (versionCode 561) | `buildSrc/src/main/kotlin/AppBuildConfig.kt:10,12-14` |
| 배포 채널 | Google Play Internal → Live, **Firebase App Distribution** (QA), 내부테스트 `https://play.google.com/apps/internaltest/4697722624784502447` | `app/build.gradle.kts:146-156,266` |
| 키스토어 | `app/wadiz.keystore` (Release signing) | `app/build.gradle.kts:50-60` |

---

## 기술 스택

- **언어**: Kotlin 2.2.20 100% (Java 미사용). Gradle Kotlin DSL. (`gradle/libs.versions.toml:5`)
- **AGP**: Android Gradle Plugin 8.12.2. (`gradle/libs.versions.toml:2`)
- **UI**: Jetpack Compose BOM `2025.11.00`, Compose Compiler plugin, DataBinding + Compose 공존(Legacy XML → Compose 점진 마이그레이션). (`gradle/libs.versions.toml:49`, `app/build.gradle.kts:91-95`)
- **DI**: Hilt `2.57.1` (+ `hilt-navigation-compose`, `hilt-work`). (`gradle/libs.versions.toml:35-37`)
- **비동기**: Kotlin Coroutines + Flow (최근 MVI 우선, `viewModelScope` 중심). 일부 Legacy 경로에 `RxJava2` (`kotlinx-coroutines-rx2`, `rxbinding`, `retrofit-adapter-rxjava2`) 병행. (`gradle/libs.versions.toml:40-43,64,222-224`)
- **네트워킹**: **Retrofit 2.9.0** + OkHttp `5.3.2` (BOM) + Moshi `1.15.0` + kotlinx.serialization 1.7.2 converter. HTTP 로그: `HttpLoggingInterceptor` + `OkHttpProfilerInterceptor` (DEBUG). (`gradle/libs.versions.toml:40-46`, `core/network/src/main/java/com/wadiz/network/service/BaseWadizAPIProvider.kt:77-97`)
- **로컬 저장소**: Room 2.7.2 (`core/database`), DataStore Preferences + DataStore Proto (+ `protobuf-javalite` 3.25.3). (`gradle/libs.versions.toml:23-25,38`)
- **백그라운드**: WorkManager `2.10.0` + Hilt Work. (`gradle/libs.versions.toml:29`, `core/work` 모듈)
- **이미지**: Coil3 `3.3.0` (Compose) + Glide 5.0.5 (Legacy). (`gradle/libs.versions.toml:32,51`)
- **멀티미디어**: AndroidX Media3 (ExoPlayer/UI/common) `1.8.0`. (`gradle/libs.versions.toml:91`)
- **카메라 & OCR**: CameraX `1.4.1` + ML Kit Text Recognition `16.0.1` (신용카드 OCR). (`gradle/libs.versions.toml:93-95`)
- **푸시/분석**: Firebase BoM `34.8.0` (Messaging/Crashlytics/Analytics/RemoteConfig/Perf), Braze `39.0.0` (In-app/Push/Content Cards), AppsFlyer `6.17.4`. (`gradle/libs.versions.toml:34,57,56`)
- **로깅**: Timber 5.0.1, Firebase Crashlytics, Microsoft **Clarity** 3.8.1 (heatmap). (`gradle/libs.versions.toml:52,94`)
- **SNS 로그인**: Kakao SDK 2.10.0, Naver Login 5.11.1, Line SDK 5.12.0, Facebook 18.1.3, Google (credentials 1.5.0 + googleid 1.1.1). (`gradle/libs.versions.toml:53,58,80,89-90`)
- **보안**: `core/security` 모듈 + `rootbeer-lib` 0.1.1 (루팅 탐지) + `androidx.biometric` 1.1.0. (`gradle/libs.versions.toml:30,59`)
- **고객센터**: Zendesk Messaging Android 2.36.1. (`gradle/libs.versions.toml:55`)
- **웹뷰**: `androidx.browser` 1.4.0 + `androidx.webkit` 1.13.0. (`gradle/libs.versions.toml:28,96`)

---

## 모듈 구성

Gradle 서브프로젝트 전수 (`settings.gradle.kts:31-69`). 각 모듈 한 줄 역할.

### `app` 모듈
- `app` — 메인 앱 타겟(`com.markmount.wadiz`), 모든 feature/core 주입 지점. (`app/build.gradle.kts:382-412`)

### `build-config`
- `build-config` — 버전/bearer 토큰 등 `buildConfigField` 주입 담당. `BuildConfig` 를 공유하기 위한 라이브러리 모듈. (`build-config/build.gradle.kts:19-36`)

### `scripts` (codegen 전용 JVM 모듈)
- `scripts` — 디자인 토큰 codegen 전용 순수 Kotlin/JVM 모듈 (`application` 플러그인, JVM 11). `JsonToColorGenerator` 가 `wadiz-client/design-tokens` 의 `color.normalized.tokens.json` 을 읽어 `Color.kt` / `GradationColor.kt` / `ExtraColor.kt` 를 생성. `./gradlew :scripts:generateColors` 태스크. (`scripts/build.gradle.kts`, `scripts/src/main/java/com/wadiz/scripts/JsonToColorGenerator.kt`) — i18n 동기화 워크플로(i18n-scheduler/worker)와 동일 패턴의 컬러 동기화(colors-scheduler/worker) 자동 PR 봇.

### `core/*`
| 모듈 | 역할 |
| --- | --- |
| `core:analytics` | Firebase/Braze/Wadi-tag(heatmap)/Clarity/GA4 전자상거래 래퍼 |
| `core:common` | 공통 상수(`WadizConstant`), 유틸, arch 인터페이스 |
| `core:data` | Repository 구현 (network → domain 변환), mapper, firebase, ads cache, `abtest/MainHomeExperimentProvider`(Remote Config 기반 A/B 할당) |
| `core:database` | Room DB |
| `core:datastore` | DataStore Preferences/Proto 저장소 (`HiddenPreferenceHelper` 등) |
| `core:design-system` | WDS 컴포넌트, Compose UI 토큰, drawable |
| `core:domain` | UseCase, 도메인 모델(+`CardValidator` 등) |
| `core:i18n` | `Localization` 객체, 다국어 런타임 문자열(`core/i18n/src/main/kotlin/com/wadiz/i18n/…`) |
| `core:legacy`, `core:legacy:wadiz-common`, `core:legacy:wadiz-dialog` | 점진 제거 대상 레거시 공용 코드 (`ServerMode` 가 여기에 있음) |
| `core:model` | 순수 Kotlin 도메인 모델, 네비게이션 Key/Route |
| `core:network` | **Retrofit ApiService 전체 + OkHttp Provider/Interceptor** (핵심) |
| `core:security` | 루팅/바이오메트릭/세션 관련 보안 |
| `core:server-driven-ui` | Server-Driven UI 렌더러 (`ServerAction`, `ServerImageComponent` 등, `core/server-driven-ui/src/main/java/com/markmount/wadiz/server_driven_ui/…`) |
| `core:ui` | 공통 Compose/전통 View 컴포넌트 |
| `core:work` | WorkManager Worker |

### `feature/*`
| 모듈 | 역할 |
| --- | --- |
| `feature` | 공용 레거시 feature (메인 Activity, WebView, PipActivity, Navigation 등) |
| `feature:account` | 계정/로그인/회원가입 |
| `feature:alarm-center` | 알림 센터 (Inbox) |
| `feature:benefit` | 혜택/쿠폰/프로모션 |
| `feature:catchup` | CatchUp 피드 |
| `feature:category` | 카테고리 탐색 |
| `feature:intro` | 온보딩/스플래시 (Lottie 3종) |
| `feature:lab` | 실험실 |
| `feature:legacy` | 레거시 화면 |
| `feature:main-tab` | 루트 5탭 컨테이너 |
| `feature:more` | 더보기 |
| `feature:my-activities` | 찜/구매내역/활동 |
| `feature:mypage` | 마이와디즈 |
| `feature:ocr` | **신용카드 OCR** (CameraX + ML Kit Text Recognition) |
| `feature:search` | 검색/카테고리 |
| `feature:service-home` | 서비스 홈 (리워드/스토어/체험단) |
| `feature:setting` | 설정 |
| `feature:wai` | Wadiz AI (wadiz.ai) |

### Android ↔ iOS 모듈 매핑 (유사점 비교)

| Android | iOS (Tuist Project) | 매핑 확실도 |
| --- | --- | --- |
| `core:network` | `Projects/Core/Sources/Networking` | 1:1 (OkHttp ↔ Alamofire) |
| `core:datastore` + `core:database` | `Projects/Core/Sources/Persistence` + `Projects/Core/Sources/Preference` | 1:1 |
| `core:design-system` + `core:ui` | `Projects/Core/Sources/UI` | 1:1 |
| `core:domain` + `core:model` | `Projects/Model` | 거의 1:1 (iOS 는 domain 통합) |
| `core:i18n` | `Projects/Core/Sources/UI/Resources/i18n.json` + `Service/Locale` | 공유 JSON 포맷 |
| `feature:main-tab` + `feature:service-home` | `Features/Home` + `Features/ServiceHome` | 1:1 |
| `feature:account` | `Features/Login` + `Features/Email` + `Features/ConfirmPassword` + `Features/PasswordSetting` + `API/LoginAPI` + `API/SignUpAPI` + `API/AccountAPI` | Android 쪽이 훨씬 뭉쳐있음 |
| `feature:search` | `Features/Search` + `API/SearchAPI` | 1:1 |
| `feature:catchup` | `Features/CatchUp` | 1:1 |
| `feature:alarm-center` | `Features/NotificationCenter` + `Service/KeywordAlarm` | 1:1 |
| `feature:ocr` | `Features/CreditCardOCR` | 1:1 (둘 다 자체 OCR, 서버 호출 없음) |
| `core:server-driven-ui` | **iOS 는 별도 모듈 없이** `Projects/App/Sources/Benefit/ServerDriven/*` 에 Benefit 한정으로 존재 | Android 가 SDUI 확장 큼 |

---

## 서버 연결 설정 (핵심)

### API Base URL 주입

Android 는 `buildConfigField` 로 **URL 자체를 심지 않는다**. 대신 `ServerMode.Server` 라는 Kotlin 인터페이스를 런타임에 **`WadizHiddenMenu.getServerMode()`** 가 반환하고, 이 인스턴스를 Hilt 로 주입해 `apiUrl`, `platformUrl`, `appApiUrl` 등 속성을 Retrofit `baseUrl()` 에 전달한다. (`core/legacy/wadiz-common/src/main/java/com/markmount/wadiz/util/ServerMode.kt:6-72`)

- `release` 빌드 타입 → `feature/src/release/java/.../WadizServerSelector.kt:41-54` 가 **고정 Live URL** 반환. 히든 메뉴 없음 (`hasMenu()=false`).
- `debug` / `qa` 빌드 타입 → `feature/src/debug/java/.../WadizServerSelector.kt` 가 히든 메뉴(`AlertDialog`) 로 `cdev | rc | rc2 | rc3 | stage | live | local` 중 선택, `HiddenPreferenceHelper` 에 저장 후 `exitProcess(0)` 재시작. (FE1-764: CDEV 실사용 정착에 따라 기존 `dev` 환경 제거됨. `ANDROID-3037` 으로 도입된 cdev 는 서버/앱 배포 후 전환되는 리모트 환경)
- `core:build-config` 는 URL 이 아닌 **외부 파트너 bearer token** 과 `SERVER_MODE` 문자열만 `buildConfigField` 로 노출 (`build-config/build.gradle.kts:23-36,47,57,68`).

### 환경별 URL 전체 표

출처: `feature/src/debug/java/com/markmount/wadiz/hidden/WadizServerSelector.kt:202-346` + `feature/src/release/java/com/markmount/wadiz/hidden/WadizServerSelector.kt:41-55`

| 키 (`ServerMode.Server`) | Live | Stage | RC2 (debug 기본) | Dev | 용도 (upstream) |
| --- | --- | --- | --- | --- | --- |
| `apiUrl` | `https://www.wadiz.kr/api/` | `https://stage.wadiz.kr/api/` | `https://rc2.wadiz.kr/api/` | `https://dev.wadiz.kr/api/` | **메인 모놀리식 `api.wadiz.kr` (v2~v4 + 레거시)** — Retrofit `WadizAppAPILegacyService`, `AppV3APIService`, `WadizMakerPageAPIService` 등 최다 엔드포인트 |
| `domainUrl` | `https://www.wadiz.kr` | `https://stage.wadiz.kr` | `https://rc2.wadiz.kr` | `https://dev.wadiz.kr` | 웹뷰 (프로젝트 상세, 결제, 약관 등) + `WadizDomainAPIService` (`/web/…`) 쿠폰·체험단·국가 리스트 |
| `mainUrl` | `https://public-api.wadiz.kr/` | `https://public-api.wadiz.kr/` | `https://public-api-rc.wadiz.kr/` | `https://public-api-dev.wadiz.kr/` | `public-api` (비회원/배너/메인 디스플레이 광고) — `WadizMainAPIService` (`/main/...`) |
| `advertiseUrl` | `https://service.wadiz.kr/api/v1/ad/host/` | 동일 | `https://rc2-service.wadiz.kr/...` | `https://dev-service.wadiz.kr/...` | 광고 (KeyVisual) — `WadizAdvertiseAPIService` |
| `analyticsUrl` | `https://analytics.wadiz.kr/` | 동일 | `https://rc-analytics.wadiz.kr/` | `https://dev-analytics.wadiz.kr/` | **와디태그(Waditag)** V1/V2 — `WadizAnalyticsAPIService` |
| `serviceUrl` | `https://service.wadiz.kr` | 동일 | `https://rc2-service.wadiz.kr` | `https://dev-service.wadiz.kr` | `service` (검색, 펀딩소프트, 스토어 검색, activities) — `WadizServiceAPIService`, `WadizStoreServiceAPIService`, `SearchApiInterface` |
| `platformUrl` | `https://platform.wadiz.kr/` | `main` 은 `https://stage-platform.wadiz.kr/`, 나머지 `https://platform.wadiz.kr/` | `https://rc2-platform.wadizcorp.net/` | `https://dev-platform.wadizcorp.net/` | **플랫폼 팀 MSA** (main2/wish/inbox/noti-channel/keyword/video/global/push) — `PlatformEndpoint` enum 으로 path-prefix 구분 |
| `searchAiUrl` | `https://searchai.wadiz.kr` | 동일 | `https://rc-api.dev-searchai.wadizdata.team` | `https://api.dev-searchai.wadizdata.team` | 검색 AI 연관 키워드 — `SearchAiDatasource` (`/related-keyword`) |
| `accountUrl` | `https://account.wadiz.kr` | 동일 | `https://rc2-account.wadiz.kr` | `https://dev-account.wadiz.kr` | **Accounts (SSO / OAuth 소셜 계정)** — 현재 Retrofit `baseUrl` 은 아님. 웹뷰 로그인 및 리다이렉트 처리 도메인. 링크 생성용 |
| `appApiUrl` | `https://app.wadiz.kr/` | 동일 | `https://app-rc2.wadizcorp.net/` | `https://app-dev.wadizcorp.net/` | **앱 전용 BFF** — `ClientAppApiService` (`/api/v1/settings` 등 설정 Tab Server-Driven) |
| `aiDomainUrl` | `https://www.wadiz.ai` | `https://stage.wadiz.ai` | `https://rc2.wadiz.ai` | `https://dev.wadiz.ai` | 글로벌(한국 외) 도메인. `feature:wai` 에서 사용 |
| `cdn3` (하드코딩) | `https://cdn3.wadiz.kr/` | 동일 | 동일 | 동일 | 정적 JSON (video_v4, web-benefit-main, scratch_coupon 등) — `WadizCdnAPIService`, `VideoDataSource`, `BenefitHomeDataSource` |
| `maker center` (하드코딩) | `https://api.makercenter.wadiz.kr/…` | 동일 | 동일 | 동일 | 메이커센터 board (기획전 리스트) — `StudioDataSource` (`wadiz-android/core/network/…/service/domain/studio/StudioDataSource.kt:19`) |

**요약**: Live 빌드는 6개 주요 서버 (`api.wadiz.kr`, `public-api.wadiz.kr`, `service.wadiz.kr`, `platform.wadiz.kr`, `analytics.wadiz.kr`, `app.wadiz.kr`) + CDN + Accounts(웹뷰) + SearchAI + MakerCenter(하드코딩) 로 분산되어 있다.

### Retrofit Provider 구조 (Hilt `@Singleton` 묶음)

`core/network/src/main/java/com/wadiz/network/service/WadizAppAPIProvider.kt` 에 **Provider 당 하나의 Retrofit + 하나의 baseUrl + 하나의 APIService** 매핑. 주요 Provider 와 baseUrl:

| Provider | baseUrl 키 | 실제 Retrofit 대상 |
| --- | --- | --- |
| `WadizAppAPIProvider` | `serverMode.apiUrl` | `WadizAppAPILegacyService` (`www.wadiz.kr/api/...`) |
| `AppV3ApiProvider` | `serverMode.apiUrl` | `AppV3APIService` (v3/v4 REST, 계정/소셜/SNS/타임존) |
| `ClientAppAPIProvider` | `serverMode.appApiUrl` | `ClientAppApiService` (BFF) |
| `WadizStartupAPIProvider` | `serverMode.apiUrl` | `WadizStartupAPIService` (스타트업 탭) |
| `WadizWebAPIProvider` | `serverMode.apiUrl` | `WadizWebAPIService` (`/web/…`) |
| `WadizDomainAPIProvider` | `serverMode.domainUrl` | `WadizDomainAPIService` (쿠폰/국가/체험단) |
| `WadizMainAPIProvider` | `serverMode.mainUrl` | `WadizMainAPIService` (public-api 메인) |
| `WadizAdvertiseAPIProvider` | `serverMode.advertiseUrl` | `WadizAdvertiseAPIService` (KeyVisual) |
| `WadizServiceAPIProvider` | `serverMode.serviceUrl` | `WadizServiceAPIService` (검색/친구활동) |
| `WadizStoreServiceApiProvider` | `serverMode.serviceUrl` | `WadizStoreServiceAPIService` (스토어) |
| `WadizStoreApiProvider` | `serverMode.apiUrl` | `WadizStoreAPIService` (`/store/projects/my`) |
| `WadizPlatformApiProvider` | `PlatformEndpoint.DEFAULT.getBaseUrl(serverMode)` | `WadizPlatformAPIService` (키워드/환율/찜할인) |
| `PlatformMainApiProvider` | `PlatformEndpoint.MAIN.getBaseUrl(serverMode)` (stage 에서 `stage-platform.wadiz.kr`) | `PlatformMainAPIService` (`/main2/...`) |
| `WadizAnalyticsAPIProvider` | `serverMode.analyticsUrl` | `WadizAnalyticsAPIService` (Waditag) |
| `WadizCdnApiProvider` | 하드코딩 `https://cdn3.wadiz.kr/` | `WadizCdnAPIService` |

### 인증

**세션 기반(쿠키 + 커스텀 헤더)**, OAuth2 access/refresh 토큰 Bearer 방식 **아님**. 동작:

1. **헤더 주입 (`HeaderInterceptor`)** — 모든 요청에 공통 헤더. (`core/network/src/main/java/com/wadiz/network/interceptor/HeaderInterceptor.kt:22-56`)
   - 로그인 시: `userId`, `authKey`, `encUserId` 추가
   - 공통: `sessionId`, `uuid`, `app_version`, `device=android`, `appId`, `os_version`, `model`, `_waid`, `wadiz-country`, `wadiz-language`, 웹뷰와 동일한 `User-Agent`
2. **쿠키 (`sharedCookie: CookieJar`)** — `platform.wadiz.kr` 제외 도메인에 한해 공유. OkHttp `CookieJar` 주입. (`BaseWadizAPIProvider.kt:56-68`)
3. **세션 갱신 (`UserRefreshInterceptor` — v2 레거시)** — 응답 JSON 의 `returnCode` 가 `USER_REFRESH` 면 `NetworkSessionProvider.userRefresh()` 호출 후 원 요청 재시도. `SESSION_NOT_FOUND` 면 `ACTION_SESSION_NOT_FOUND` 브로드캐스트로 로그인 액티비티로 전환. 415 (`/api/v2/marketing/terms`) 는 서버 버그 워크어라운드로 재시도. (`core/network/src/main/java/com/wadiz/network/interceptor/UserRefreshInterceptor.kt:21-108`)
4. **세션 갱신 (`SessionInterceptor` — v3/v4 신규)** — `ErrorCode.USERINFO_REFRESH_REQUIRED` → refresh 재시도, `ErrorCode.UNAUTHORIZED` → `SessionNotFoundException` throw + 액션 브로드캐스트. kotlinx.serialization 기반 `ErrorResponse`. (`core/network/src/main/java/com/wadiz/network/interceptor/SessionInterceptor.kt:26-100`)
5. **저장소**: `userId/authKey/encUserId/sessionId` 는 `NetworkSessionProvider`(의 구현은 `core/data` + `core/security`) 가 암호화 SharedPreferences/DataStore 에 저장. `core/security` 는 `androidx.biometric` + `rootbeer-lib` 를 포함.

### 에러/재시도/로깅 파이프라인 (DEBUG 전용 부분 포함)

`BaseWadizAPIProvider.makeOkHttpClient()` 의 순서:
- `addNetworkInterceptor(headerInterceptor)` — 헤더
- (옵션) `addInterceptor(userRefreshInterceptor)` 또는 `sessionInterceptor` — 세션
- `timeout` = connect/read/write 10s (`BaseWadizAPIProvider.kt:131`)
- DEBUG:
  - `CookieInterceptor` (쿠키 디버그)
  - `logViewerInterceptor` (내부 로그 뷰어)
  - `HttpLoggingInterceptor(Timber::d, level = BODY)` — Timber 로 전체 body
  - `OkHttpProfilerInterceptor` — Nerdy Things 프로파일러
  - 캐시 상태 로그 (`HIT/MISS/CONDITIONAL_HIT`)
- `dispatcher.maxRequestsPerHost = 25`

---

## 네트워크 레이어

- **Retrofit ApiService 인터페이스 위치**: `core/network/src/main/java/com/wadiz/network/service/**` 총 17개 인터페이스, **147개 엔드포인트** (count by Grep)
- **DTO 레이어**: `core/network/src/main/java/com/wadiz/network/dto/**` (+ 레거시 `com.markmount.wadiz.network.dto`) — Moshi `@JsonClass(generateAdapter = true)` 기반이 많고 일부는 kotlinx-serialization `@Serializable` (특히 `ClientAppApiService` SettingItem 다형성 직렬화, `WadizAppAPIProvider.kt:360-373`)
- **Domain 모델**: `core/model`, `core/domain`
- **Repository**: `core/data/src/main/java/com/wadiz/data/repository/**`
- **Mapper**: `core/data/src/main/java/com/wadiz/data/mapper/**` — DTO → Domain 변환 전용
- **UseCase**: `core/domain/src/main/java/...` 내 UseCase 클래스
- **ViewModel**: 각 `feature/**/src/main/java/**/ViewModel.kt` — `@HiltViewModel` + `StateFlow<UiState>` + `SharedFlow<UiEvent>` (MVI). Legacy 는 RxJava2 `Observable`.

---

## 기능별 API 호출 매핑 (핵심)

아래 표는 Retrofit 어노테이션 전수조사(`Grep "@(GET|POST|PUT|DELETE|PATCH|HTTP)("`) 결과에서 발췌한 **대표 엔드포인트 55+개**. 도메인 열은 앞서 정의한 `ServerMode.Server` 속성명을 쓴다.

### 로그인 / 회원가입 / 소셜 (`feature:account`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:account` | `POST /api/v3/login/email` | `apiUrl` | 이메일 로그인 (v3) | 로그인 화면 → 제출. `AppV3APIService.kt:71` |
| `feature:account` | `POST /api/v4/login/email` | `apiUrl` | 이메일 로그인 (v4) | 동일, 신규 스펙. `AppV3APIService.kt:105` |
| `feature:account` | `POST /api/v4/login/social` | `apiUrl` | 소셜 로그인 (Kakao/Naver/Google/Apple/Line/Facebook) | 로그인 버튼 탭. `AppV3APIService.kt:76` |
| `feature:account` | `POST /api/v4/sign-up/email` | `apiUrl` | 이메일 회원가입 | 회원가입 Submit. `AppV3APIService.kt:97` |
| `feature:account` | `POST /api/v4/sign-up/email/code` | `apiUrl` | 이메일 인증번호 요청 | 회원가입 중 이메일 확인. `AppV3APIService.kt:121` |
| `feature:account` | `POST /api/v4/sign-up/email/code/verification` | `apiUrl` | 이메일 인증번호 확인 | 코드 입력 확인. `AppV3APIService.kt:129` |
| `feature:account` | `POST /api/v4/sign-up/social` | `apiUrl` | 소셜 회원가입 | 소셜 로그인 후 신규 유저 분기. `AppV3APIService.kt:89` |
| `feature:account` | `POST /api/v4/sign-up/social/link` | `apiUrl` | 기존 계정에 소셜 연동 가입 | 소셜 로그인 → 연동 분기. `AppV3APIService.kt:81` |
| `feature:account` | `POST /api/v4/check/email` | `apiUrl` | 이메일 존재 여부 확인 | 회원가입 1단계. `AppV3APIService.kt:113` |
| `feature:account` | `GET /api/v3/account/info/refresh` | `apiUrl` | 세션/사용자 정보 갱신 (interceptor 내부) | `UserRefreshInterceptor`, 내 프로필 수정 후 |
| `feature:account` | `GET /api/v3/account` | `apiUrl` | 내 계정 정보 | 마이와디즈 진입. `AppV3APIService.kt:177` |
| `feature:account` | `POST /api/v3/account/sns-links/{provider}` | `apiUrl` | 소셜 연동 | 설정 > SNS 연동 화면. `AppV3APIService.kt:152` |
| `feature:account` | `DELETE /api/v3/account/sns-links/{provider}` | `apiUrl` | 소셜 연동 해제 | 설정 > SNS 연동 화면. `AppV3APIService.kt:172` |
| `feature:account` | `POST login/logout` | `apiUrl` | 로그아웃 | 설정 > 로그아웃. `WadizAppAPILegacyService.kt:82` |
| `feature:account` | `GET join/social/terms` | `apiUrl` | 소셜 회원가입 약관 | 카카오 소셜 회원가입 첫 진입. `WadizAppAPILegacyService.kt:91` |
| `feature:account` | `GET /web/v3/terms/signup` | `apiUrl` | 약관 리스트 (신 스펙) | 회원가입 약관 단계. `AppV3APIService.kt:137` |
| `feature:account` | `POST waccount/auth/request/token` | `apiUrl` | 세션 토큰 발급 | 앱 시작 직후 `SessionSyncManager`. `WadizAppAPILegacyService.kt:130` |

### 설정 / 계정 관리 (`feature:setting`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:setting` | `PUT /api/v3/account/nickname` | `apiUrl` | 닉네임 변경 | 설정 > 닉네임. `AppV3APIService.kt:180` |
| `feature:setting` | `PUT /api/v3/account/email` | `apiUrl` | 이메일 변경 | 설정 > 이메일. `AppV3APIService.kt:196` |
| `feature:setting` | `POST /api/v3/account/email/code` | `apiUrl` | 이메일 변경 인증코드 요청 | 동일. `AppV3APIService.kt:188` |
| `feature:setting` | `GET /api/v3/account/phone-number` / `PUT /api/v3/account/phone-number` | `apiUrl` | 전화번호 조회/수정 | 설정 > 전화번호. `AppV3APIService.kt:257,271` |
| `feature:setting` | `POST /api/v3/account/phone-number/code` | `apiUrl` | 전화번호 인증코드 요청 (FE1-1013: `/web/v3`→`/api/v3` 변경) | 동일. `AppV3APIService.kt:270` |
| `feature:setting` | `POST /api/v3/account/password` / `PUT /api/v3/account/password` | `apiUrl` | 비밀번호 설정/변경 | 설정 > 비밀번호. `AppV3APIService.kt:213,221` |
| `feature:setting` | `POST /api/v3/account/password/verification` | `apiUrl` | 비밀번호 확인 | 비밀번호 변경 전 재확인 모달. `AppV3APIService.kt:204` |
| `feature:setting` | `POST /api/v3/account/profile-image` (Multipart) / `DELETE /api/v3/account/profile-image` | `apiUrl` | 프로필 이미지 업로드/삭제 | 프로필 이미지 편집. `AppV3APIService.kt:280,288` |
| `feature:setting` | `GET /api/v3/user/time-zone`, `PUT /api/v3/user/time-zone`, `PUT /api/v3/user/time-zone/auto`, `GET /api/v3/time-zones` | `apiUrl` | 타임존 조회/변경 | 설정 > 국가/타임존. `AppV3APIService.kt:294-312` |
| `feature:setting` | `PUT /api/v3/user/location` | `apiUrl` | 국가/언어 변경 | 나라/지역 변경 화면. `AppV3APIService.kt:58` |
| `feature:setting` | `GET /api/v3/user/settings/terms/service/{serviceCode}` | `apiUrl` | 서비스 약관 동의 조회 | 설정 > 약관. `AppV3APIService.kt:230` |
| `feature:setting` | `GET/PUT /api/v3/user/settings/terms/marketing/{serviceCode}` | `apiUrl` | 마케팅 수신 동의 조회/변경 | 설정 > 알림 동의. `AppV3APIService.kt:239,248` |
| `feature:setting` | `GET /noti-channel/v2/marketingconsents`, `PUT /noti-channel/v2/marketingconsents` | `platformUrl` | 노티 채널 별 마케팅 동의 | 설정 > 알림. `NotiChannelDataSource.kt:21,30` |
| `feature:setting` | `GET /api/v2/terms/accepter` | `apiUrl` | 약관 동의자 정보 | 법인/연령 재확인. `WadizAppAPILegacyService.kt:222` |
| `feature:setting` | `GET /api/v2/membership` | `apiUrl` | 내 멤버십 | 마이와디즈 진입. `WadizAppAPILegacyService.kt:225` |

### 홈 / 메인탭 / 서비스홈 (`feature:main-tab`, `feature:service-home`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:main-tab` | `GET /main2/api/v9/main` | `platformUrl(.main)` | **홈 메인 큐레이션** (페이지, 추천, ai) | 홈 탭 렌더 / Pull-to-refresh. `PlatformMainAPIService.kt:25` |
| `feature:main-tab` | `GET /main2/api/v10/main` (헤더 `X-Experiment`, `X-Device-Type=ANDROID_APP`) | `platformUrl(.main)` | **홈 AI 추천 A/B 실험판** (FE1-686) — 실험 파라미터를 쿼리→헤더로 전환 | 홈 탭 렌더 시 실험군 할당된 경우. `PlatformMainAPIService.kt:37` |
| `feature:main-tab` | `GET /main2/api/v1/quickmenu` | `platformUrl(.main)` | 홈 상단 퀵메뉴 | 홈 진입. `PlatformMainAPIService.kt:48` |
| `feature:main-tab` | `POST /main2/api/v1/recentview` | `platformUrl(.main)` | 최근 본 프로젝트 일괄 조회 | 홈 최근 본 섹션. `PlatformMainAPIService.kt:39` |
| `feature:main-tab` | `GET /main2/api/v3/my-wadiz` | `platformUrl(.main)` | 홈 하단 마이와디즈 요약 | 홈 스크롤 | `PlatformMainAPIService.kt:53` |
| `feature:main-tab` | `GET /main2/api/v1/pc/ranking/{productType}` | `platformUrl(.main)` | 랭킹 | 랭킹 섹션. `PlatformMainAPIService.kt:56` |
| `feature:main-tab` | `GET main2/api/v1/recommendation/item` | `platformUrl(.main)` | 연관 추천 | 프로젝트 상세 진입 후. `PlatformMainAPIService.kt:59` |
| `feature:main-tab` | `GET /main/earlybird/coming-soon`, `/main/earlybird/popular`, `/main/featured/reward`, `/main/featured/equity`, `/main/display-ads/event`, `/main/display-ads/marketing`, `/main/info/{sectionCode}`, `/main/display-ads/MPB`, `/main/display-ads/{bannerList}` | `mainUrl` | public-api 홈 섹션/배너/EB | 홈 섹션별 로드. `WadizMainAPIService.kt:17-52` |
| `feature:main-tab` | `POST /main/campaign/rate` | `mainUrl` | 캠페인 만족도 | 종료 후 팝업. `WadizMainAPIService.kt:23` |
| `feature:main-tab` | `POST /main/v1/store/participants` | `mainUrl` | 스토어 참여 | 스토어 홈 배너 이벤트. `WadizMainAPIService.kt:67` |
| `feature:main-tab` | `GET keyvisual` | `advertiseUrl` | 홈 최상단 키비주얼 광고 | 홈 최초 렌더. `WadizAdvertiseAPIService.kt:9` |

### 검색 / 카테고리 (`feature:search`, `feature:category`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:search` | `GET /api/search/v3/home` | `apiUrl` | 검색홈 (인기/최근/추천태그) | 검색 탭 진입. `SearchDataSource.kt:45` |
| `feature:search` | `POST /api/search/v3/integrate` | `apiUrl` | 통합 검색 | 검색어 입력 submit. `SearchDataSource.kt:48` |
| `feature:search` | `POST /api/search/v2/integrate/purchased` | `apiUrl` | 구매한 상품 내 검색 | 마이와디즈 검색. `SearchDataSource.kt:85` |
| `feature:search` | `GET /api/search/categories` | `apiUrl` | 카테고리 트리 | 카테고리 탭. `SearchDataSource.kt:62` |
| `feature:search` | `GET /api/search/v3/categories/service-home` | `apiUrl` | 카테고리 서비스 홈 | 카테고리 세부 진입. `SearchDataSource.kt:73` |
| `feature:search` | `GET /api/activities/wishes/search` | `apiUrl` | 내 찜 내 검색 | 내 찜 탭 검색. `SearchDataSource.kt:78` |
| `feature:search` | `GET /api/search/v2/popular/keyword` | `serviceUrl` | 인기 키워드 | 검색 초기 화면. `WadizServiceAPIService.kt:24` |
| `feature:search` | `POST /api/search/v2/funding` | `serviceUrl` | 펀딩 검색 결과 | 탭 별 필터. `WadizServiceAPIService.kt:31` |
| `feature:search` | `POST /api/search/v2/fundingSoon` | `serviceUrl` | 오픈예정 검색 | 오픈예정 탭. `WadizServiceAPIService.kt:42` |
| `feature:search` | `POST /api/search/v2/preorder` | `serviceUrl` | 프리오더 검색 | 프리오더 탭. `WadizServiceAPIService.kt:71` |
| `feature:search` | `GET /related-keyword` | `searchAiUrl` | 연관 검색어 (AI) | 검색어 입력 중. `SearchAiDatasource.kt:19` |
| `feature:search` | `POST /api/search/store/` | `serviceUrl` | 스토어 검색 | 스토어 검색 탭. `WadizStoreServiceAPIService.kt:17` |
| `feature:search` | `GET /wad/sections` | `serviceUrl` | 광고 섹션 | 결과 페이지 스폰서 행. `WadizStoreServiceAPIService.kt:26` |

### 찜 / 활동 / 알림신청 (`feature:my-activities`, `feature:mypage`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:my-activities` | `POST /api/funding/wishes`, `DELETE /api/funding/wishes` | `apiUrl` | 찜 추가/삭제 | 하트 버튼. `WadizAppAPILegacyService.kt:240,250` |
| `feature:my-activities` | `POST /api/wcampaign/comingsoon/applicant` / `POST /api/funding/comingsoons/{projectNo}/applicants` | `apiUrl` | 오픈예정 알림 신청 (구/신) | "알림받기" 버튼. `WadizAppAPILegacyService.kt:261,273` |
| `feature:my-activities` | `POST /api/wcampaign/comingsoon/applicant-cancel` / `DELETE /api/funding/comingsoons/{projectNo}/applicants` | `apiUrl` | 오픈예정 알림 해제 | 동일. `WadizAppAPILegacyService.kt:283,292` |
| `feature:my-activities` | `GET /api/funding/campaigns/{campaignId}/pre-reservation-info` | `apiUrl` | 오픈예정 사전예약 정보 | 상세 배너 탭. `WadizAppAPILegacyService.kt:297` |
| `feature:my-activities` | `POST /api/activities` | `serviceUrl` | 카드별 찜/알림 상태 일괄 조회 | 리스트 렌더 배치. `WadizServiceAPIService.kt:51` |
| `feature:my-activities` | `GET /api/v1/searcher/wish/project/endingsoon` | `serviceUrl` | GNB 찜 마감임박 | GNB 아이콘 클릭. `WadizServiceAPIService.kt:61` |
| `feature:mypage` | `GET /api/mywadiz/account/supporter` | `apiUrl` | 마이와디즈 서포터 요약 | 마이페이지 진입. `WadizAppAPILegacyService.kt:206` |
| `feature:mypage` | `GET /web/mywadiz/supporter/usage-count` | `apiUrl` | 서포터 사용횟수 | 마이페이지. `WadizWebAPIService.kt:16` |

### 알림 센터 / 키워드 알람 (`feature:alarm-center`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:alarm-center` | `GET /inbox/v6/messages` | `platformUrl` | 알림 센터 목록 | 알림 탭 진입. `InboxDataSource.kt:46` |
| `feature:alarm-center` | `GET /inbox/v4/messages/count-unread` | `platformUrl` | 미확인 알림 뱃지 카운트 | GNB 벨 아이콘. `InboxDataSource.kt:36` |
| `feature:alarm-center` | `PUT /inbox/v4/messages/read-all` | `platformUrl` | 알림 전체 읽음 처리 | "모두 읽음" 버튼. `InboxDataSource.kt:56` |
| `feature:alarm-center` | `POST notification/push/read` | `apiUrl` | 푸시 트래킹 코드 전송 | 푸시 알림 탭. `WadizAppAPILegacyService.kt:115` |
| `feature:alarm-center` | `GET /keyword/api/v1/info-keywords`, `POST /keyword/api/v1/info-keywords`, `DELETE /keyword/api/v1/info-keywords` (hasBody) | `platformUrl` | 키워드 알림 등록/조회/삭제 | 키워드 알림 설정 화면. `KeywordAlarmDatasource.kt:25,31,38` |
| `feature:alarm-center` | `GET /keyword/api/v1/info-keywords/push-toggle`, `POST /keyword/api/v1/info-keywords/push-toggle` | `platformUrl` | 키워드 알림 푸시 토글 | 스위치 토글. `KeywordAlarmDatasource.kt:44,50` |
| `feature:search`(실제로는 plat) | `POST /keyword/api/v1/keywords` | `platformUrl` | 최근 검색어 플랫폼 저장 | 검색 submit. `WadizPlatformAPIService.kt:34` |

### CatchUp (`feature:catchup`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:catchup` | `GET /api/v1/catchup/notification`, `PUT /api/v1/catchup/notification` | `apiUrl` | CatchUp 알림 설정 조회/변경 | 알림 탭 토글. `WadizAppAPILegacyService.kt:354,357` |
| `feature:catchup` | `GET /api/v1/catchup/today`, `POST /api/v1/catchup/today`, `GET /api/v1/catchup/today/status` | `apiUrl` | 오늘의 픽 조회/반응 액션/상태 | CatchUp 홈 / 카드 스와이프. `WadizAppAPILegacyService.kt:362,365,370` |

### 혜택 / 쿠폰 (`feature:benefit`)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:benefit` | `GET /web/apip/funding/event/{couponName}/participant` | `domainUrl` | 쿠폰 발급 여부 | 혜택 페이지 진입. `WadizDomainAPIService.kt:34` |
| `feature:benefit` | `POST /web/apip/funding/event/{couponName}/{couponType}` | `domainUrl` | 쿠폰 발급 | "쿠폰 받기" 클릭. `WadizDomainAPIService.kt:42` |
| `feature:benefit` | `GET /web/reward/api/coupons/templates/types/download` | `domainUrl` | 기간 한정 쿠폰 리스트 | 한정 쿠폰 섹션. `WadizDomainAPIService.kt:51` |
| `feature:benefit` | `POST /web/reward/api/coupons/transactions/types/redeem/issue-types/download` | `domainUrl` | 한정 쿠폰 발급 요청 | 동일. `WadizDomainAPIService.kt:60` |
| `feature:benefit` | `POST /web/reward/api/coupons/transactions/types/redeem/issue-types/download/bulk/by-project/{projectId}` | `domainUrl` | 프로젝트 단위 쿠폰 일괄 발급 | 상세 쿠폰 "전체 받기". `WadizDomainAPIService.kt:87` |
| `feature:benefit` | `GET /web/reward/api/comingsoons?collectionKeyword=preview21` | `domainUrl` | 펀딩 체험단(preview21) | 혜택/체험단 탭. `WadizDomainAPIService.kt:68` |
| `feature:benefit` | `GET https://cdn3.wadiz.kr/app/web-benefit-main.json` | CDN | 혜택홈 Server-Driven UI JSON | 혜택홈. `BenefitHomeDataSource.kt:17` |

### 스토어 / 프로젝트 / 메이커 페이지

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 화면/이벤트 |
| --- | --- | --- | --- | --- |
| `feature:service-home` | `GET store/projects/my` | `apiUrl` | 내 스토어 프로젝트 | 마이와디즈 메이커. `WadizStoreAPIService.kt:11` |
| `feature:service-home` | `GET /api/store/projects/my` | `apiUrl` | 스토어 메이커 프로젝트 (요약) | 위젯(홈스크린)/마이와디즈. `WadizAppAPILegacyService.kt:305` |
| `feature:service-home` | `GET /api/store/studio/orders/aggregation` | `apiUrl` | 스토어 메이커 주문 집계 | 마이와디즈 메이커 대시보드. `WadizAppAPILegacyService.kt:311` |
| `feature:service-home` | `GET /wish/api/v1/wish/discount` | `platformUrl` | 찜 할인 프로젝트 | 홈/서비스홈 섹션. `WadizPlatformAPIService.kt:47` |
| `feature:service-home` | `GET /api/maker/mywadiz/pages` | `apiUrl` | 메이커 마이와디즈 페이지 구성 | 메이커 홈. `WadizMakerPageAPIService.kt:8` |
| `feature:service-home` | `GET /web/reward/api/makers/my/summations/campaigns` | `domainUrl` | 프로젝트 개설 이력 | "새 프로젝트 열기". `WadizDomainAPIService.kt:27` |
| `feature:service-home` | `GET /web/apip/funding/v2/bottom-sheet/data` | `domainUrl` | 메이커 모드 선택 바텀시트 데이터 | 메이커 모드 전환. `StudioDataSource.kt:16` |
| `feature:service-home` | `GET https://api.makercenter.wadiz.kr/api/board/user/lists?board_type=event&…` | makercenter-be (하드코딩) | 메이커센터 기획전 보드 | 메이커 홈 배너. `StudioDataSource.kt:19` |

### 스타트업 (투자)

| Feature 모듈 | 엔드포인트 | 도메인 | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `feature:service-home` (startup) | `GET /api/startup/common/codeMap` | `apiUrl` | 코드맵 캐시 | 스타트업 탭 초기화. `WadizStartupAPIService.kt:22` |
| `feature:service-home` | `POST /api/startup/main` | `apiUrl` | 스타트업 메인 리스트 | 스타트업 탭. `WadizStartupAPIService.kt:26` |
| `feature:service-home` | `GET /api/startup/corporation/connect`, `POST /api/startup/corporation/{corpNo}/interested`, `GET /api/startup/corporation/my` | `apiUrl` | 법인 연결/관심 기업 | 법인 설정. `WadizStartupAPIService.kt:29-36` |
| `feature:service-home` | `GET /api/startup/collection/bannerList` | `apiUrl` | 스타트업 배너 컬렉션 | 스타트업 탭. `WadizStartupAPIService.kt:40` |

### 소셜 팔로우 / 주소록 (`feature:account`, `feature:mypage`)

| Feature | 엔드포인트 | 도메인 | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `feature:account` | `GET /api/v3/account/sns-links` | `apiUrl` | 내 SNS 연동 목록 | 설정 > SNS 연동. `AppV3APIService.kt:145` |
| `feature:account` | `GET /api/v3/social/recommendation/kakao` | `apiUrl` | 카카오 친구 기반 유저 추천 | 팔로우 추천 화면. `AppV3APIService.kt:317` |
| `feature:account` | `POST /api/v3/social/follows` | `apiUrl` | 다중 팔로우 | "모두 팔로우". `AppV3APIService.kt:326` |
| `feature:mypage` | `GET /api/v2/social/recommendation/user/kakao/has-user`, `GET /api/v2/social/recommendation/user/allow-info`, `PUT /api/v2/social/recommendation/user/allow-info` | `apiUrl` | 주소록 허용 상태 | 주소록 연동 동의 화면. `WadizAppAPILegacyService.kt:316,348,351` |
| `feature:mypage` | `PUT /api/v2/social/contacts`, `PUT /api/v2/social/contacts/sync-allow`, `DELETE /api/v2/social/contacts`, `GET /api/v2/social/contacts/information` | `apiUrl` | 주소록 업로드/동의/삭제/정보 | 주소록 동기화 워크플로우. `WadizAppAPILegacyService.kt:320-334` |
| `feature:mypage` | `GET /api/v2/social/recommendation/user/contacts/count`, `GET /api/v2/social/recommendation/user/contacts/user-info` | `apiUrl` | 주소록 기반 추천 카운트/리스트 | 친구 추천 화면. `WadizAppAPILegacyService.kt:334,337` |
| `feature:mypage` | `POST /api/v2/social/follower/follow/multi` | `apiUrl` | 다중 팔로우 (legacy) | 친구 추천 "전체 팔로우". `WadizAppAPILegacyService.kt:343` |
| `feature:friends` | `GET /api/friends/activities` | `serviceUrl` | 친구 활동 피드 | GNB 배지/친구탭. `WadizServiceAPIService.kt:76` |

### 앱 공통 / 시작 / 분석

| Feature | 엔드포인트 | 도메인 | 용도 | 트리거 |
| --- | --- | --- | --- | --- |
| `app` / `feature` | `POST app/getVersionCheck` | `apiUrl` | 버전체크 + 세션수립 + FCM 토큰 등록 | Application start. `WadizAppAPILegacyService.kt:71` |
| `app` | `POST /api/app/adid` | `apiUrl` | GAID 전달 | `AdvertisingIdClient` 획득 직후. `WadizAppAPILegacyService.kt:60` |
| `feature:main-tab` | `POST /api/main/track/section` | `apiUrl` | 배너 섹션 클릭 트래킹 | 홈 배너 탭. `WadizAppAPILegacyService.kt:189` |
| 앱 설정 | `GET /api/v1/settings` | `appApiUrl` | **설정 탭 Server-Driven 구성** | 설정 탭 진입. `ClientAppApiService.kt:10` |
| 분석 | `GET /v2/add?…&id=…&action=2010&…` | `analyticsUrl` | 와디태그 V2 ScreenView/PV | `ScreenViewPVTracker` 스크린 진입. `WadizAnalyticsAPIService.kt:17` |
| 분석 | `POST /add` (multipart `action`, `actions`) | `analyticsUrl` | 와디태그 클릭/멀티태그 | 버튼 탭/배치 로그. `WadizAnalyticsAPIService.kt:32` |
| 글로벌 | `GET /global/exchange-rates/{country}` | `platformUrl` | 환율 | 글로벌(일본/중국) 결제 조회. `WadizPlatformAPIService.kt:41` |
| 글로벌 | `GET /web/v1/countries`, `GET /web/v1/countries/{code}` | `domainUrl` | 국가 리스트 / 단건 | 회원가입/배송 국가 선택. `WadizDomainAPIService.kt:76,82` |
| 비디오 홈 | `GET /video/v1/shorts` | `platformUrl` | 비디오 숏츠 | 비디오 홈. `VideoDataSource.kt:19` |
| 비디오 홈 | `GET https://cdn3.wadiz.kr/app/video_v4.json`, `http://cdn3.wadiz.kr/app/videoHome.json` | CDN | 비디오 홈 SDUI JSON | 비디오 홈 렌더. `VideoDataSource.kt:24,27` |
| CDN 구성 | (Url 주입) | CDN3 | SearchBar 마케팅/Home Swipe Lottie/Intro/LiveCommerce/Inbox config 등 JSON 로드 | 여러 화면. `WadizCdnAPIService.kt:11-27` |

---

## 주요 화면 흐름 분석

### 1) 홈/피드 (`feature:main-tab`, `feature:service-home`)
- 트리거: `MainActivity` → `MainFragment` (`feature/src/main/java/com/markmount/wadiz/view/main/`) 의 홈 탭 선택 → `HomeViewModel.load()`
- ViewModel: `HiltViewModel` 에서 `viewModelScope.launch` → `GetHomeMainUseCase` (core:domain) 실행
- UseCase → `MainRepository` (core:data) 의 `fetchMain(page, encUserId, …)`
- Repository → `PlatformMainApiProvider.provider.getMain(...)` (`platformUrl(.main)` = `https://platform.wadiz.kr/main2/api/v9/main`)
- 응답 `ResponseCuration` → Mapper 로 `HomeSection` 도메인 변환 → `StateFlow<HomeUiState>` update → Compose `HomeScreen` 에서 `LazyColumn` 렌더
- 부속 호출 병렬: `getQuickMenu` (platform), `getMain` (platform), `keyvisual` (advertise), `getMyWadiz` (platform), `/main/earlybird/*` (public-api `mainUrl`)

### 2) 프로젝트 상세 / 결제 (펀딩 리워드)
- 프로젝트 상세는 **네이티브가 아닌 WebView** 로 `https://www.wadiz.kr/web/campaign/detail/{id}` 를 로드 (`feature/src/main/java/com/markmount/wadiz/view/main/web/WebFragmentModule.kt`, `ReuseWebView*`).
- `SessionSyncManager` (`feature/src/main/java/com/markmount/wadiz/webview/SessionSyncManager.kt`) 가 앱 진입 시 `POST waccount/auth/request/token` 으로 세션토큰 발급 → 웹뷰 쿠키 동기화
- `RewardJavascriptInterface` / `InvestJavascriptInterface` 로 결제 완료/닫기 이벤트 수신 → 네이티브 복귀
- 찜 버튼만 네이티브: `POST /api/funding/wishes` / `DELETE /api/funding/wishes`

### 3) 로그인 (`feature:account`)
- 트리거: 로그인 화면 → 이메일/비밀번호 입력 → Submit
- ViewModel → `LoginUseCase.loginEmail(body)` → `AccountRepository`
- Repository → `AppV3ApiProvider.provider.loginEmail(body)` (`POST /api/v4/login/email` @ `apiUrl`)
- 응답 `ResponseLogin` → `NetworkSessionProvider` 가 `userId/authKey/encUserId/sessionId` 저장 (암호화 DataStore) → 쿠키 CookieJar 업데이트
- 후속: `POST waccount/auth/request/token` 으로 웹뷰용 토큰 발급, `GET /api/v3/account` 로 최초 프로필 로드
- 오류: v4 응답이 `preconditionRequired` 면 `SessionInterceptor` 가 user refresh 수행

### 4) 서포팅(결제)
- 결제는 전부 **웹뷰** (`https://www.wadiz.kr/…/order/...`) 에서 진행. 네이티브 Retrofit 경로 없음.
- 사전 체크: 오픈예정인 경우 `POST /api/funding/comingsoons/{projectNo}/applicants` 로 알림 신청 → 오픈 시 FCM 푸시. 상세는 `GET /api/funding/campaigns/{campaignId}/pre-reservation-info`.
- 결제 완료 후 웹뷰 → 네이티브 브릿지 → 홈 리프레시

### 5) 신용카드 OCR (`feature:ocr`)
- 트리거: 결제 웹뷰 내에서 "카드 스캔" 브릿지 호출 → `CardOcrDialogFragment` 시작 (`feature/ocr/src/main/java/com/markmount/wadiz/view/cardocr/CardOcrDialogFragment.kt`)
- `CameraPreview` (CameraX) → ML Kit Text Recognition (`mlkit-text-recognition:16.0.1`) 로 카드 번호/만료일 OCR
- `CardInfoParser` + `CardValidator` (core:domain) 로 Luhn 검증 → 3초 타이머 실패 시 수동 입력 모드
- `CardOcrViewModel` 은 `MutableSharedFlow<CardOcrResult?>` 에 결과 emit → 웹뷰 JS 인터페이스로 전달 (서버 호출 없음, 온디바이스)

---

## 빌드·배포

### 빌드 타입
- `release` — `isMinifyEnabled=true`, Crashlytics mapping 업로드, `wadiz.keystore` 서명. Live 서버 고정 (`feature/src/release/...`). (`app/build.gradle.kts:98-110`)
- `debug` — `versionNameSuffix=".{QA_VERSION}"`, debug 전용 src 사용(히든 메뉴 활성). (`app/build.gradle.kts:112-139`)
- `qa` — `isMinifyEnabled=true`, debug src 사용, Firebase App Distribution 업로드 타겟(appId `1:359446206708:android:12aa95fe824c9bf4`). (`app/build.gradle.kts:141-162,146-153`)

### 배포 스크립트
- **`app_distribution.sh`** — 루트, `./gradlew assembleRelease_log appDistributionUploadRelease_log` 실행.
- **Gradle tasks** (`app/build.gradle.kts`)
  - `deployQA` → `deployFirebaseAppDistribution` (Fastlane 없음, Firebase Gradle 플러그인 사용) + Slack webhook `sendMessage(...)` (웹훅 `hooks.slack.com/.../B043S0NSVJR/...`). (`app/build.gradle.kts:247-261,337-339`)
  - `deployLiveApk` → Live 배포 후 Slack 공지 (InternalTest URL 첨부).
  - `incrementVersionName`, `printVersion`, `printReleaseVersion` — CI 에서 버전 조작.
- **Google Play** — Play Console 수동 업로드 + `core/playstore/` 하위 메타데이터. Fastlane 은 리포지토리에 설정되어 있지 않음.
- **릴리즈노트** — `app/release_note_wiki.py` + Atlassian Confluence (`https://wadiz.atlassian.net/wiki/spaces/ServiceDev/pages/17733648840/2026-14W+AOS+Release+Note`). (`app/build.gradle.kts:24`)
- **CI** — `.github/workflows/` + Dependabot + Jira integration actions.

### 버전 규칙
- Release: `{MAJOR}.{MINOR}.{PATCH}` (예: `26.14.3`)
- QA: `{MAJOR}.{MINOR}.{PATCH}.{QA_VERSION}` (`AppBuildConfig.kt:20-21`)
- CI 가 `gradle incrementVersionName -PbranchName=release/26.14.3` 또는 `-PversionCode=...` 로 파일 직접 수정

### 키스토어
- `wadiz.keystore` 가 레포에 포함. `gradle.properties` 의 `RELEASE_STORE_FILE / _PASSWORD / KEY_ALIAS / KEY_PASSWORD` 주입. (`app/build.gradle.kts:50-60`)

---

## 특이사항

### Android 고유
- **Server-Driven UI 모듈 (`core:server-driven-ui`)** — `ServerAction`, `ServerImageComponent`, `ServerMargin`, `ServerGravity` 등 서버가 내려준 JSON 으로 레이아웃 조립. Benefit 홈(`cdn3/app/web-benefit-main.json`), 비디오홈(`video_v4.json`) 에서 활용. iOS 보다 범위가 훨씬 넓다.
- **히든 메뉴 서버 전환** — debug/qa 빌드에서 3회 탭 등의 제스처로 `WadizServerSelector` 다이얼로그 → 8개 환경 중 선택 + `local` 커스텀 URL. 변경 시 `exitProcess(0)` 로 앱 강제 재시작.
- **한글 i18n 런타임 JSON** — `core:i18n` 이 문자열을 런타임 JSON 번들(`i18n.json`) 로 관리(`Localization.ApiCode.Common.ERROR.text` 식 접근). 하드코딩 금지, 모든 UI 문자열은 `Localization` 통과.
- **OCR (`feature:ocr`)** — **신용카드 스캔 전용** (신분증 OCR 아님). 서버 호출 없음, 순수 온디바이스 ML Kit. 결제 편의 UX.
- **Wadiz AI (`feature:wai`)** — `wadiz.ai` 도메인 진입용 네이티브 래퍼. 별도 `aiDomainUrl`.
- **Clarity heatmap** (`com.microsoft.clarity:clarity-compose`) — Compose 화면 세션 리플레이/히트맵. `core:analytics`.
- **Waditag (자체 분석)** — Firebase Analytics + AppsFlyer 외에 **사내 `analytics.wadiz.kr`** 에 GET(ScreenView) / POST(Click) 로 이벤트 전송. action=2010 이 PV.
- **Compose 임프레션(노출) 수집 — Modifier.Node 재작성 (FE1-799)** — 기존 `composed{}` 기반 `Modifier.impression` 이 recomposition 마다 인스턴스를 재생성하고 노드마다 `ProcessLifecycleOwner` 옵저버를 등록(노드 N개 = 옵저버 N개)해 홈 노출이 과수집되던 근본 원인(`ANDROID-3068`)을 제거. `ModifierNodeElement` + `Modifier.Node`(`BaseImpressionNode`/`ImpressionNode`/`GenericImpressionNode`)로 재작성, 가시성은 `registerOnLayoutRectChanged` + `RelativeLayoutBounds.fractionVisibleInWindow`(임계 >0.5, 1000ms hold) 로 측정. 신규 `ImpressionGate`(`view/compose/ImpressionGate.kt`)가 앱당 1개 옵저버로 통합(background 경계는 기존 ON_PAUSE/RESUME 유지). 콜사이트 37개 시그니처 무변경. (테스트 `ImpressionNodeTest`/`ImpressionGateTest`/`ImpressionUiTest`)
- **메인홈 AI 추천 A/B 테스트 + GA4 전자상거래 (FE1-686)** — `core:data/abtest/MainHomeExperimentProvider` 가 Firebase Remote Config 기반으로 실험군을 할당하고, 홈 요청을 `/main2/api/v10/main` (실험 파라미터를 헤더 `X-Experiment` 로 전송)으로 분기. GA4 전자상거래 item-level 에 `experiment`(값 `{실험명}_{실험군}`, 예 `RECOMMENDATION_A`) + `item_source` 필드 추가(`EcommerceInterface`/`Ga4Tag`). A/B 노출·클릭은 데이터팀용 `ua_event+와디탁` 발사를 제거하고 Firebase 목표 이벤트(`main_home_recommendation_impression`/`_click`) 1건 + GA4 전자상거래 `experiment` 필드로 통합(`TraceModelMainHomeAb`). `Modifier.mainHomeAbTracking` 이 전자상거래 impression 과 A/B impression 을 하나의 `Modifier.impression(List)` 로 합쳐 발사(노출 modifier 중첩 시 안쪽 `onVisibilityChanged` 가 가려져 `view_item_list` 0건이던 회귀 해결). 와디태그(WADI) detail 채널에서 `item_source`/`experiment` 가 빠지던 회귀도 별도 수정(FE1-805).
- **다중 Firebase 설정** — `app/google-services.json`, `build-config/google-services.json`, `feature/src/{debug|local|rc|release|stage}/google-services.json` 등 환경별 분리.
- **중복 Retrofit Provider 주의** — `WadizStoreApiProvider.WadizStoreApiProvider()` 재귀 이름이 오타성 매서드 (`WadizAppAPIProvider.kt:246-251`). 실제 동작은 `WadizStoreAPIService` 주입.
- **Play Policy Lint** — `play-policy-insights-lint` 0.1.4 로 Google Play 정책(Accessibility, Background Location 등) 위반 사전 감지 (`app/build.gradle.kts:66-81`).
- **자체 Maven 미러** — `devrepo.kakao.com`, `jitpack`, `appboy.github.io` (Braze), `zendesk.jfrog.io` 설정 (`settings.gradle.kts:17-22`).
- **LeakCanary** — debug/AndroidTest 에만 포함.

---

## 최근 변경사항

**분석 갱신일: 2026-07-10** (이전: 2026-06-19, 2026-05-29, 최초: 2026-04-20)

### 주요 릴리즈 (v26.23.0)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| Compose 임프레션 수집 Modifier.Node 재작성 (옵저버 N개 누적/과수집 제거) | 2026-06-01 | FE1-799 |
| 메인홈 AI 추천 A/B 테스트 구조 + GA4 전자상거래 `experiment`/`item_source` 필드 도입 (wadiTrace 제거, `/main2/api/v10/main` + `X-Experiment` 헤더, impression 노드 중첩 회귀 fix) | 2026-05-29 | FE1-686 |
| 와디태그(WADI) detail 채널 `item_source`/`experiment` 누락 회귀 수정 | 2026-06-01 | FE1-805 |
| CDEV 실사용 정착 → 기존 DEV 환경 제거 | 2026-05-29 | FE1-764 |
| 디자인 토큰(컬러) 자동 동기화 — `scripts` 모듈 + `JsonToColorGenerator` + colors-scheduler/worker 워크플로 | 2026-05-11 | FE1-633 |
| WebView blob/data 등 미지원 스킴 다운로드 크래시 방어 | 2026-06-01 | FE1-802 |
| 라이브커머스 PIP 미진입 수정 (prefetch 지원 기기 + 메이커 모드 포함) | 2026-06-01 | FE1-807/809 |
| 상세 네이티브 프래그먼트 재진입 시 스켈레톤 겹침 수정 | 2026-06-01 | FE1-810 |
| 검색결과 탭 전환 시 스크롤 최상단 초기화 수정 | 2026-06-01 | FE1-811 |
| 글로벌 메인홈 오픈예정 랭킹(마지막 카드) 미노출 수정 (죽은 가드 제거) | 2026-06-01 | FE1-801 |
| 글로벌(한/미/일 외) 쿠폰 추천 미노출 수정 (`displayDiscountAmount` 금액 Int→Double 파싱) | 2026-05-29 | QA-22165 |
| 검색결과 사용가능 쿠폰 국가·통화 적용 (쿠폰 API v2 + currency 추가) | 2026-05-21 | FE1-675 |
| 성인인증 후 같은 프로젝트 재진입 시 상세 겹침 수정 (펀딩 URL path 정규식 한정) | 2026-05-28 | FE1-749 |
| 계정 변경 후 위시리스트에 이전 계정 위시 노출 문제 수정 | 2026-05-21 | FE1-718 |
| 디자인 시스템 메시지 박스 컬러 변경 | 2026-05-21 | FE1-720 |
| 디버그 빌드에서만 Cloud 전환 로직 사용하도록 안정성 개선 | 2026-04-16 | FE1-402 |

### 주요 릴리즈 (v26.20 ~ v26.21.2)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 홈 기획전 스토어 금액 표시 오류 수정 | 2026-05-21 | FE1-729 |
| 스토어 랭킹 금액 오노출 수정 | 2026-05-20 | FE1-725 |
| analytics.wadiz.ai 연동 | 2026-05-20 | FE1-723 |
| 상세 겹침 오류 수정 (webKit 안정화, NativeState 로딩 처리) | 2026-05-19~20 | QA-21908 |
| 앱 런처 아이콘 변경 | 2026-05-11 | FE1-623 |
| 메인 네비게이션 바 노출 애니메이션 수정 | 2026-05-12 | FE1-655 |
| Clarity Compose 다운그레이드 | 2026-05-08 | FE1-582 |
| 카테고리 클릭 시 검색결과 진입 race 수정 | 2026-05-08 | FE1-622 |
| 메이커 모드 로그인/국가 변경 시 서포터 홈 노출 이슈 수정 | 2026-05-13 | FE1-660 |
| WebView 앱모드 주입 개선 | 2026-04-20 | FE1-447 |
| 딥링크 재진입 상세 유지 및 비로그인 AccountActivity 튕김 수정 | 2026-04-20 | FE1-443 |
| Google Sign-In 수정 | 2026-04-22 | FE1-223 |
