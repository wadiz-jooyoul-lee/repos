# Flow: 마이페이지 (마이와디즈 — 프로필 · 포인트 · 쿠폰)

> 서포터가 "마이와디즈" 상단 허브와 포인트·쿠폰 탭을 열 때 발생하는 데이터 체인. 여러 서비스에서 병렬로 데이터를 모아 오는 **composite page** 성격.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/apps/global/src/pages/my-wadiz/` (10개 하위 폴더 구조)
  - `wadiz-frontend/apps/global/src/pages/my-wadiz/points/_ui/PointList.tsx:1-40` (포인트 탭 UI)
  - `wadiz-frontend/packages/api/src/web/point.service.ts:24-60`
  - `wadiz-frontend/packages/api/src/web/reward/coupon.service.ts:60-135` (쿠폰 탭)
  - `com.wadiz.web/src/main/java/com/wadiz/web/point/MyPointApiController.java:23-75`
  - `com.wadiz.web/src/main/java/com/wadiz/web/wpoint/controller/WWEBPointInquiryController.java:11-45`
  - `com.wadiz.web/src/main/java/com/wadiz/core/wpoint/service/WPointInquiryService.java:40-130`
- **외부 경계**: `pointService` 의 내부 `Transaction`/`Bookkeeping` 모델 (별도 포인트 도메인 jar), `com.wadiz.api.reward` 쿠폰 로직은 [`docs/com.wadiz.api.reward/api-details/coupon-core.md`](../com.wadiz.api.reward/api-details/coupon-core.md) 참조.

---

## 마이페이지 구성 (FE 라우트 기준)

```
apps/global/src/pages/my-wadiz/
├── _api/                     # 공통 hook
├── coupons/                  # 쿠폰함
├── inquiries/                # 1:1 문의
├── invitation-code/          # 초대 코드
├── maker/                    # 메이커 프로젝트/대시보드
├── orders/                   # 내 펀딩 (→ [my-funding.md](./my-funding.md))
├── points/                   # 포인트
├── settings/                 # 계정 설정 + 알림
└── supporter/                # 서포터 허브 (상단 요약)
```

본 문서는 **허브(supporter) · 포인트 · 쿠폰 · 설정** 네 영역에 집중. orders(마이펀딩)와 inquiries(1:1)는 별도 flow.

---

## 1. Client Trigger (FE)

### 1.1 허브 진입
- 상단 "서포터 요약" 카드: 보유 포인트·쿠폰 수·내 펀딩 수를 한 번에 표시
- `MyWadizSupporterLayout.tsx` / `MyWadizSupporterDesktopLayout.tsx` / `MyWadizSupporterMobileLayout.tsx` 세 레이아웃 (반응형)

### 1.2 포인트 탭 API
```ts
// packages/api/src/web/point.service.ts:24
export const getMyPointSummary = (params = { isExact: true }) =>
  POST('web/wpoint/pointInquiry/ajaxGetMyPointInquirySummary', params);   // 요약(레거시 AJAX)

// :31
export const getMyPointHistory = ({ page, size }) =>
  GET('/web/point/api/transactions/my', { params: { page, size } });      // 거래 목록

// :58
export const getMyPointSummation = () =>
  GET('/web/point/api/summation/my');                                     // 보유액 + 내일 만료
```
- TanStack Query `useInfiniteQuery` 기반 (PointList 컴포넌트 내부)

### 1.3 쿠폰 탭 API
```ts
// packages/api/src/web/reward/coupon.service.ts:69
// 보유 쿠폰 목록
GET /web/reward/api/coupons/owners/my

// :131  보유 쿠폰 수
GET /web/reward/api/coupons/owners/my/qty

// :80   쿠폰 코드로 등록 (발급)
POST /web/reward/api/coupons/transactions/types/redeem/issue-types/coupon-code

// :271  다운로드 가능 쿠폰 목록
GET /web/reward/api/coupons/templates/types/download

// :328  특정 템플릿 쿠폰 다운로드
POST /web/reward/api/coupons/transactions/types/redeem/issue-types/download
```

### 1.4 설정
- `my-wadiz/settings/MyWadizSettingsPage.tsx` (프로필/탈퇴/개인정보)
- `my-wadiz/settings/notification/MyWadizSettingsNotificationPage.tsx` (앱푸시/이메일/알림톡/마케팅 소식)

---

## 2. Hub — `com.wadiz.web`

### 2.1 포인트 허브 요약 (레거시 JSP/AJAX)
```java
// com.wadiz.web/wpoint/controller/WWEBPointInquiryController.java:11
@RequestMapping("/web/wpoint/pointInquiry/*")
public class WWEBPointInquiryController {

    @RequestMapping(value = "/ajaxGetMyPointInquirySummary",            // :23
                    produces = "application/json;charset=UTF-8")
    public ResponseWrapper<?> getMyPointSummary(@RequestBody ... params) { ... }

    @RequestMapping(value = "/ajaxGetMyCouponInquirySummary",           // :36
                    produces = "application/json;charset=UTF-8")
    public ResponseWrapper<?> getMyCouponSummary(...) { ... }
}
```

### 2.2 포인트 거래 내역 + 보유액 (신규 API)
```java
// com.wadiz.web/point/MyPointApiController.java:30
@RequiredLogin
@GetMapping("/web/point/api/transactions/my")
public ResponseWrapper<Page<MyPointTransactionResponse>> getAllMyPointTransactions(Pageable pageable) {
    final int size = pageable.getSize() == 0 ? 10 : pageable.getSize();
    pageable.setSize(size);
    Paging<WPointInOutInfo> result = pointService.getHistoryPointInfoList(
        "Y", pageable.getPage() + 1, pageable.getSize(), SessionUtil.getUserId());
    List<MyPointTransactionResponse> response = result.getItems().stream()
        .map(this::toMyPointTransactionResponse)
        .collect(Collectors.toList());
    return ResponseWrapper.success(new Page<>(result.getTotalItemsCount(), pageable, response));
}

// :64
@RequiredLogin
@GetMapping("/web/point/api/summation/my")
public ResponseWrapper<MyPointSummationResponse> getAllMyPointSummation() {
    WPointInquiryUserSummaryInfo result =
        pointService.getPointInquiryUserSummary(SessionUtil.getUserId(), true);
    int expirationPointTomorrow = pointService.getExpirationPointTomorrow(SessionUtil.getUserId());
    return ResponseWrapper.success(MyPointSummationResponse.builder()
        .availableAmount(result.getPossessionPoint())
        .expiringAmountTomorrow(expirationPointTomorrow)
        .build());
}
```

`@RequiredLogin` 인터셉터가 쿠키 세션/Bearer 토큰 중 하나라도 없으면 401.

### 2.3 Point Service 내부
```java
// com.wadiz.web/core/wpoint/service/WPointInquiryService.java:43
public WPointInquiryUserSummaryInfo getPointInquiryUserSummary(int userId, boolean isExact) {
    Integer availableAmount = pointService.getAvailablePoint(userId, isExact);
    ...return new WPointInquiryUserSummaryInfo(availableAmount);
}

// :58
public Paging<WPointInOutInfo> getHistoryPointInfoList(String paging, int cPage, int pageSize, int userId) {
    Page<Transaction> pageTransactions =
        pointService.getPageableTransactionByUser(userId, cPage - 1, pageSize);
    ...
    // Transaction.bookkeepings → Issue → Template 탐색해서
    // "적립"/"사용"/"만료"/"환불" 메타 (templateName, effectedUntil, orderNo, rewardTitle) 조립
    return new Paging<>(wPointInOutInfos, cPage, pageSize, total);
}
```
`pointService` 는 별도 포인트 도메인 서비스 (point 모듈). `Transaction`/`Bookkeeping`/`Issue`/`Template` 4단 엔터티로 포인트 이력을 관리.

### 2.4 쿠폰 경로 — `com.wadiz.api.reward`
`/web/reward/api/coupons/owners/my` 는 com.wadiz.web 의 쿠폰 인바운드 컨트롤러가 아니라, com.wadiz.web → com.wadiz.api.reward 어댑터 호출을 래핑하는 컨트롤러로 이어진다. 세부 분석은 [`docs/com.wadiz.api.reward/api-details/coupon-core.md`](../com.wadiz.api.reward/api-details/coupon-core.md) 참조.

---

## 3. Backend Services 요약

| 영역 | 서비스 | 경로 |
|---|---|---|
| 포인트 요약/내역 | 포인트 도메인(내부 jar) via com.wadiz.web | `/web/point/api/*`, `/web/wpoint/pointInquiry/*` |
| 쿠폰 | `com.wadiz.api.reward` via com.wadiz.web | `/web/reward/api/coupons/*` |
| 내 펀딩 | `com.wadiz.api.funding` via ApiProxy | `/web/apip/funding/supporters/my/fundings` ([my-funding.md](./my-funding.md)) |
| 프로필·설정 | `com.wadiz.wave.user` | `/web/reward/api/users/...` 및 wave.user 직접 |
| 알림 설정 | Notification 서비스 | (별도 flow) |
| 1:1 문의 | 별도 inquiry 서비스 | (별도 flow) |

---

## 4. DB

### 4.1 포인트
포인트 도메인 내부 엔터티 (별도 모듈, 본 레포에서는 `Transaction`/`Bookkeeping`/`Issue`/`Template` 클래스만 관측).
개념적으로:
```
Transaction (pointTransactionId, userId, type, amount, executionDate)
  └── Bookkeeping (장부 — 복식부기)
        └── Issue (발급 단위)
              └── Template (적립/차감 템플릿, 이름 + 만료 정책)
```
테이블명은 별도 스키마일 가능성 (`point_transaction`, `point_bookkeeping`, `point_issue`, `point_template` 추정).

### 4.2 쿠폰
`com.wadiz.api.reward` DB 의 `t_reward_coupon*`, `t_reward_coupon_template*`, `t_reward_coupon_transaction*` 등 — 상세는 Phase 2 문서 참조.

### 4.3 프로필/설정
`UserProfile`, `MakerInfo`, `UserSettings`, `UserLocale`, `UserTimeZone` (wave.user). 조회 경로는 wave.user 의 `UserAccountInfosController` · `UserSettingsController` · `UserLocaleController`.

---

## 엔드투엔드 시퀀스 (포인트 탭)

```
[FE: MyWadizPointsPage → PointList]
   │ (병렬 호출)
   ├─ GET /web/point/api/summation/my                       (보유 + 내일 만료)
   └─ GET /web/point/api/transactions/my?page=N&size=10     (내역 — useInfiniteQuery)
   ▼
[www.wadiz.kr — com.wadiz.web]
   │
   ├─ MyPointApiController#getAllMyPointSummation            (point/MyPointApiController.java:64)
   │     @RequiredLogin → SessionUtil.getUserId()
   │     └─ WPointInquiryService.getPointInquiryUserSummary(userId, true)
   │            └─ pointService.getAvailablePoint(userId, true)   (내부 포인트 모듈)
   │     └─ WPointInquiryService.getExpirationPointTomorrow(userId)
   │
   └─ MyPointApiController#getAllMyPointTransactions          (:30)
         @RequiredLogin
         └─ WPointInquiryService.getHistoryPointInfoList("Y", page+1, size, userId)
                └─ pointService.getPageableTransactionByUser(userId, page, size)
                        └─ DB (point 도메인 스키마):
                             SELECT Transaction → Bookkeeping → Issue → Template
                                (적립 템플릿 이름 / 만료일 / 관련 주문번호·리워드명 조립)

   → JSON 응답 (페이지 + 거래 목록, 보유액 + 내일 만료)
   → FE: 카드 렌더 + 다음 페이지 prefetch
```

## 엔드투엔드 시퀀스 (쿠폰 탭)

```
[FE: my-wadiz/coupons 페이지]
   │ (병렬)
   ├─ GET /web/reward/api/coupons/owners/my            (목록)
   └─ GET /web/reward/api/coupons/owners/my/qty        (개수)
   ▼
[www.wadiz.kr — com.wadiz.web]
   │ 쿠폰 adapter → com.wadiz.api.reward HTTP 호출 (추정: Feign/RestClient)
   ▼
[com.wadiz.api.reward]
   │
   └─ CouponController#getMyCoupons
         └─ CouponService → MyBatis (t_reward_coupon*, owner=userId)
            (상세: docs/com.wadiz.api.reward/api-details/coupon-core.md)
```

## 엔드투엔드 시퀀스 (허브 요약)

```
[FE: MyWadizSupporterLayout 초기 렌더]
   │ 병렬 호출 (여러 API):
   ├─ 포인트 요약        → /web/point/api/summation/my
   ├─ 쿠폰 개수          → /web/reward/api/coupons/owners/my/qty
   ├─ 펀딩 개수·상태     → /web/apip/funding/supporters/my/fundings?... (my-funding flow)
   ├─ 프로필/닉네임       → (wave.user 측 user-info 조회 — 별도)
   └─ (필요시) 알림 미읽음 개수 → (platform inbox — 별도)
   │
   │ TanStack Query 가 각 쿼리 캐시 → 전역 공유 (여러 탭에서 재사용)
   ▼
 [상단 카드 + 탭 진입 시 개별 페이지는 이미 prefetch 된 데이터로 즉시 렌더]
```

---

## 경계·미탐색

1. **포인트 도메인 스키마** — `Transaction`/`Bookkeeping`/`Issue`/`Template` 의 실제 테이블명·관계는 별도 포인트 모듈 jar 에서 확인. 이 레포에서는 서비스 호출 지점만.
2. **쿠폰 허브 요약(`/ajaxGetMyCouponInquirySummary`)** — 레거시 AJAX 경로. 내부 구현 상세 미확인.
3. **보유액 정확 계산(`isExact=true`)** — false 일 때 캐시 사용 여부, 일관성 타이밍 차이 별도 추적.
4. **만료 예정 계산** (`getExpirationPointTomorrow`) — 어떤 기간 범위(내일 00:00 이전?)인지 정확한 경계 확인 필요.
5. **TanStack Query 캐시 공유** — 서브페이지마다 별도 queryKey 를 쓰는지, 허브 카드용 "미니 요약"과 탭 페이지 "full detail" 이 다른 쿼리인지 확인.
6. **알림 설정 탭 → notification 서비스 경로** — 본 문서 범위 외, `settings/notification` 개별 flow 로 분화 권장.
7. **메이커 탭** (`my-wadiz/maker/...`) — 서포터용 본 문서에서 제외. 별도 메이커 플로우 영역.
