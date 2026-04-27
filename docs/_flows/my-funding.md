# Flow: 마이펀딩 (내 펀딩 참여 내역)

> 서포터가 마이와디즈 → 펀딩 탭에서 자신이 후원한 프로젝트 목록·상세를 조회. 주문 이력·배송 상태·환불 여부·결제 예약 일자를 한 번에 노출.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/funding.service.ts:615-645` (`getMyFundingList`)
  - `wadiz-frontend/apps/global/src/pages/my-wadiz/orders/_ui/MyFundingList.tsx:29-44` (무한 스크롤 페이지 UI)
  - `com.wadiz.web/web/WEB-INF/web.xml:125-130` (`bearerTokenAuthenticationFilter` 매핑)
  - `com.wadiz.web/src/main/java/com/wadiz/api/httpproxy/ApiProxyServletDispatcher.java:13`
  - `com.wadiz.api.funding/adapter/application/.../supporter/SupporterController.java:26-80`
  - `com.wadiz.api.funding/adapter/infrastructure/src/main/resources/mapper/FundingMapper.xml:109-155`
- **외부 경계**: `supporterProxy.fundingList(...)` 는 funding-core jar UseCase 위임. WhereClause 분기 일부는 SQL `<include>` 경유로 `fundingListWhereClause` 확인 후 분석 가능.

---

## 1. Client Trigger (FE)

### 1.1 화면 — `MyFundingList.tsx`
```tsx
// apps/global/src/pages/my-wadiz/orders/_ui/MyFundingList.tsx:29
const myFundingListQueryObj = fundingService.getMyFundingListQuery({ filteringType });
const myFundingListQuery = useInfiniteQuery({ ...myFundingListQueryObj, ... });
```
- **무한 스크롤**: `useInfiniteQuery` (TanStack Query) + pageParam `{ page, filteringType }`
- **필터 타입**: `filteringType` (결제상태), `bizModel` (펀딩/스토어/investment 등)

### 1.2 API 호출 — `funding.service.ts:615`
```ts
const getMyFundingList = async (params) => {
  return GET('/web/apip/funding/supporters/my/fundings', { params });
};
```
- **Query key**: `['/web/apip/funding/supporters/my/fundings', { filteringType, bizModel }]`
- **page size 기본 20**, stale time 기본
- **Host**: `https://www.wadiz.kr` (쿠키 세션 + Bearer 토큰 이중 지원)

### 1.3 앱(Android/iOS)
- Phase 2 미진행.

---

## 2. Hub — `com.wadiz.web` (특수 처리 경로)

### 2.1 인증 필터 (web.xml 중요 관찰)
```xml
<!-- com.wadiz.web/web/WEB-INF/web.xml:119-130 -->
<filter>
    <filter-name>bearerTokenAuthenticationFilter</filter-name>
    <filter-class>org.springframework.web.filter.DelegatingFilterProxy</filter-class>
</filter>
<filter-mapping>
    <filter-name>bearerTokenAuthenticationFilter</filter-name>
    <url-pattern>/web/v1/maker/*</url-pattern>
    <url-pattern>/web/v2/membership</url-pattern>
    <url-pattern>/web/v2/membership/payment/history</url-pattern>
    <url-pattern>/web/apip/funding/supporters/my/fundings</url-pattern>      <!-- ★ -->
    <url-pattern>/web/apip/funding/supporters/my/fundings/*</url-pattern>    <!-- ★ -->
    <url-pattern>/web/apip/store/orders/*</url-pattern>
</filter-mapping>
```

**관찰**: 일반 `/web/apip/*` 요청은 쿠키 세션만 검증되지만, **`/web/apip/funding/supporters/my/fundings` 는 추가로 Bearer 토큰 필터를 거친다**. 앱에서 OAuth2 access token 으로 호출할 수 있도록 분기한 것으로 추정 — 동일 URL 을 웹(쿠키)과 앱(Bearer)이 공유.

### 2.2 프록시 단계
필터 통과 후 `ApiProxyServlet` 이 `com.wadiz.api.funding` 으로 요청을 그대로 포워딩 (`ApiProxyServletDispatcher.java:55` 의 `request.getRequestDispatcher(...).forward(...)`).

내부 타깃 URL은 funding의 `/api/supporters/my/fundings`.

---

## 3. Backend Service — `com.wadiz.api.funding`

### 3.1 Controller
```java
// adapter/application/.../domain/supporter/SupporterController.java:26
@RestController
@RequestMapping("/api/supporters")
public class SupporterController {
    private final SupporterProxy supporterProxy;

    @GetMapping("/my/fundings")                                        // :60
    public ResponseWrapper<PageResult<FundingListResponse>> getMyFundingList(
        @RequestParam(required = false) final FilteringType filteringType,
        @RequestParam(required = false) final CampaignBizModel bizModel,
        @PageableDefault final Pages pages) {

        final PageResult<FundingListResultItem> result = supporterProxy.fundingList(
            FundingListQuery.builder()
                .userId(SecurityUtils.currentUserId())
                .filteringType(filteringType)
                .languageCode(LocaleContextHolder.getLocale().getLanguage())
                .bizModel(bizModel)
                .build(),
            pages,
            Sorts.by(Sorts.Order.desc("BackingPaymentId")));

        final List<FundingListResponse> content =
            SupporterResponseConverter.INSTANCE.toFundingListResponse(result.getContent());
        return ResponseWrapper.ok(new PageResult<>(content, result.getPages(), result.getTotalElements()));
    }

    @GetMapping("/my/fundings/{backingPaymentId}")                     // :80  상세
    @PutMapping("/my/fundings/{backingPaymentId}/shipping-address")    // :90  배송지 변경
    @PutMapping("/my/fundings/{backingPaymentId}/pay-by")              // :104 결제수단 변경
    ...
}
```

- `SecurityUtils.currentUserId()` — Spring Security Context 에서 userId 추출 (Bearer/쿠키 모두 동일 Context)
- `supporterProxy.fundingList(...)` — UseCase 호출. 실제 구현은 `funding-core` jar (외부) 에서 SupporterListUseCase 같은 포트로 위임되는 것으로 추정.

### 3.2 도메인 proxy
`SupporterProxy` 는 이 레포의 얇은 래퍼로, 실제 로직은 funding-core 에서 MyBatis 매퍼를 호출한다 (SQL 은 이 레포의 `FundingMapper.xml` 에 존재).

---

## 4. DB

### 4.1 핵심 SQL — `FundingMapper.xml#fundingListSearch` (:109)
```sql
SELECT BP.payStatus
     , A.BackingPaymentId
     , C.TargetAmount
     , (SELECT SUM(FundingAmount)
          FROM wadiz_db.BackingPayment SS1
         WHERE SS1.CampaignId = A.CampaignId
           AND SS1.IsCanceled = FALSE) AS TotalFundingAmount
     , CCM.CategoryCode AS categoryCode
     , BP.RegDate  AS FundingDate
     , CASE WHEN C.WhenHoldTo < DATE_ADD(NOW(), INTERVAL -1 DAY)
            THEN 'true' ELSE 'false' END AS isEnded
     , C.IsAllOrNothing
     , BP.BillingAmount
     , DATE_ADD(C.WhenHoldTo, INTERVAL 1 DAY) AS WhenPayFor
     , DATE_ADD(C.WhenHoldTo, INTERVAL 2 DAY) AS WhenFinalPayFor
     , PCV.ValueFriendly AS PayStatusNm
     , A.CampaignId
     , A.DeliveryStatus  AS DeliveryStatus
     , A.RefundStatus    AS IsRefunded
     , C.BizModel
     , BP.PayBy , BP.CountryCode
     , CP.PauseEndDate AS fundingPauseEndDate
FROM (
    -- 서브쿼리: 사용자별 BackingPayment + 배송 완료 여부 + 환불 여부 선계산
    SELECT A.CampaignId, A.BackingPaymentId
         , CASE WHEN EXISTS (
              SELECT 'O' FROM wadiz_db.BackingPaymentMapping SS2
              INNER JOIN wadiz_db.Shipping SS3
                USE INDEX(IDX_Shipping__BackingId_DeliveryStatus)
                  ON (SS3.BackingId = SS2.BackingId)
              WHERE SS2.BackingPaymentId = A.BackingPaymentId
                AND SS3.DeliveryStatus = 'DELIVERED'
           ) THEN 'DELIVERED' ELSE 'PENDING' END AS DeliveryStatus
         , CASE WHEN EXISTS (
              SELECT 'O' FROM wadiz_db.RewardRefund SS1
              WHERE SS1.BackingPaymentId = A.BackingPaymentId
                AND SS1.UserId = A.UserId
           ) THEN TRUE ELSE FALSE END AS RefundStatus
      FROM wadiz_db.BackingPayment A
    <include refid="fundingListWhereClause"/>     -- UserId + PayStatus IN (...) + 조건
    <include refid="...Clauses.pagesAndFallbackSorts"/>
) A
INNER JOIN wadiz_db.BackingPayment BP ON BP.BackingPaymentId = A.BackingPaymentId
INNER JOIN wadiz_db.Campaign       C  ON C.CampaignId = BP.CampaignId
LEFT  JOIN wadiz_db.CampaignCategoryMapping CCM
                                      ON CCM.CampaignId = C.CampaignId
                                     AND CCM.IsPrime = TRUE
INNER JOIN wadiz_db.CodeValue      PCV ON PCV.Value = BP.PayStatus
                                     AND PCV.GroupId = 'PAYSTATUS'
LEFT  JOIN wadiz_db.CampaignPause  CP  ON CP.CampaignId = C.CampaignId
ORDER BY A.BackingPaymentId DESC
```

### 4.2 접근 테이블 · 의미

| 테이블 | 역할 | 관계 |
|---|---|---|
| `BackingPayment` | 결제(주문) 메인 — 본인 소유 행만 WHERE UserId 필터 | 메인 FROM |
| `BackingPaymentMapping` + `Backing` | 결제 ↔ 리워드 매핑 | 서브쿼리 — 배송 상태 계산용 |
| `Shipping` | 배송 상태 (`DELIVERED` 여부) | 서브쿼리 EXISTS |
| `RewardRefund` | 환불 이력 존재 여부 | 서브쿼리 EXISTS |
| `Campaign` | 목표금액·종료일·All-or-Nothing·BizModel | INNER JOIN |
| `CampaignCategoryMapping` | 대표 카테고리 코드 (`IsPrime = TRUE`) | LEFT JOIN |
| `CodeValue` (`GroupId='PAYSTATUS'`) | 결제상태 코드 → 다국어 레이블 | INNER JOIN |
| `CampaignPause` | 펀딩 일시 중단 상태 (기간 내면 PauseEndDate 노출) | LEFT JOIN |

### 4.3 추가 집계
- `TotalFundingAmount` — 같은 캠페인의 유효 결제 합계를 각 행마다 재계산 (서브쿼리, 많은 건수에서 비용 ↑ — 캐시/머테리얼라이즈 여지 있음)
- `WhenPayFor`, `WhenFinalPayFor` — All-or-Nothing 결제 예약 일정 (홀드 종료 +1일/+2일)

---

## 엔드투엔드 시퀀스

```
[FE: MyFundingList.tsx → useInfiniteQuery]
   │ GET /web/apip/funding/supporters/my/fundings?page=N&size=20&filteringType=...&bizModel=...
   │ (쿠키 세션 또는 Bearer 토큰)
   ▼
[www.wadiz.kr]
   │
   ├─ bearerTokenAuthenticationFilter   (web.xml:123 특수 적용)
   │     └─ 토큰 검증 → Spring Security Context 주입
   │
   └─ ApiProxyServlet (web.xml:202)
         │ forward: /api/supporters/my/fundings
         ▼
[com.wadiz.api.funding]
   │
   ├─ SupporterController#getMyFundingList               [supporter/SupporterController.java:60]
   │     userId = SecurityUtils.currentUserId()
   │     languageCode = Locale 현재
   │
   └─ supporterProxy.fundingList(FundingListQuery, pages, sort=desc(BackingPaymentId))
         │ (UseCase: funding-core 외부 jar)
         │
         └─ MyBatis → FundingMapper.xml#fundingListSearch     [infrastructure/FundingMapper.xml:109]
               ├─ FROM BackingPayment (UserId 필터, PayStatus IN, 페이지)
               ├─ 서브: EXISTS Shipping(DELIVERED) + RewardRefund
               ├─ JOIN Campaign / CampaignCategoryMapping / CodeValue / CampaignPause
               └─ SUM(FundingAmount) by CampaignId  (행별 재계산)

   → 응답: PageResult<FundingListResponse>
   → FE: 카드 리스트 렌더, 다음 페이지 prefetch
```

---

## 경계·미탐색

1. **`fundingListWhereClause`** — 파일 내 재사용 fragment (`FundingMapper.xml:156~`). 필터타입별(`isPayReservation`, `isPayComplete`) 분기 조건 상세는 추가 확인 필요.
2. **`supporterProxy.fundingList` 실구현** — funding-core jar 내부. 이 레포에서 관측 가능한 것은 위 SQL 까지.
3. **인증 이중 지원의 실제 동작** — Bearer vs 쿠키 분기 지점(서블릿 필터 체인 순서, 토큰 검증 실패 시 fallback 등) 은 SecurityConfig 차원 문서가 별도.
4. **`TotalFundingAmount` 재계산 비용** — 한 페이지당 20 건 기준 20 회 서브쿼리. Campaign 통계가 별도 캐시/머테리얼라이즈되어 있는지 별도 확인.
5. **상세/변경 엔드포인트** — `/my/fundings/{id}` 상세, `/shipping-address` 변경, `/pay-by` 변경은 본 문서 범위 밖 (각각 별도 flow 로 분화 가능).
6. **앱에서의 Bearer 토큰 발급 경로** — OAuth2 access token 은 `kr.wadiz.account` 에서 발급되어 `www.wadiz.kr` 에 전달되는 흐름 (별도 flow: login).
