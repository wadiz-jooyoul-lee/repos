# Flow: 리워드 선택 (서포팅 진입)

> 서포터가 프로젝트 상세에서 "펀딩하기" 진입 시 리워드 리스트·옵션·멤버십 혜택을 한 번에 로드. 이후 주문 세션 생성(`funding-payment` 플로우)으로 연결.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/static/entries/reward/src/reward-product/services/rewardProduct.js:14` (FE 호출)
  - `wadiz-frontend/apps/global/src/features/rewards-selection/lib/testdata/rewardMockGenerator.js:20` (호스트 명시)
  - `wadiz-frontend/packages/api/src/web/funding.service.ts:457` (`/web/apip/funding/reward-items/campaigns/...` 대체 경로)
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/rewarditem/controller/RewardItemApiController.java:23-45`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/rewarditem/service/RewardItemService.java:78, 284-350`
  - `com.wadiz.web/src/main/java/com/wadiz/core/wcampaign/service/WRewardSearchService.java:287-289`
  - `com.wadiz.web/src/main/resources/sqls/wcampaign/wrewardsearch-mapper.xml:274`
- **외부 경계**: `MemberShipService.getUserMemberShipBenefit` 내부, `DonationCheckService` 내부, `WRewardSearchDao` 구현체 (단순 MyBatis 프록시로 관측).

---

## 1. Client Trigger (FE/App)

### 1.1 wadiz-frontend — 두 가지 호출 패턴 공존

| 경로 | 호출처 | 비고 |
|---|---|---|
| `GET /web/reward/api/campaigns/{id}/reward-items/supporter` | `static/entries/reward/src/reward-product/services/rewardProduct.js:14` | **com.wadiz.web 자체 처리** (MyBatis → DB) |
| `GET /web/apip/funding/reward-items/campaigns/{id}` | `packages/api/src/web/funding.service.ts:457` | **ApiProxyServlet → com.wadiz.api.funding** |

두 경로가 공존하는 이유는 본 문서 범위 외. 레거시 UI 영역(static/entries)과 신규 pnpm 모노레포(packages/api)가 각각 다른 백엔드 경로를 쓰는 것으로 관측.

- **fetch 래퍼**: 레거시는 `fetchRewardApi` (static/packages/fetch-api), 신규는 `packages/api/src/fetch.ts` 기반 `GET` 헬퍼
- **Host**: `https://www.wadiz.kr`

### 1.2 wadiz-android / wadiz-ios
- Phase 2 미진행.

---

## 2. Hub — `com.wadiz.web` (자체 처리 경로)

### 2.1 Controller
```java
// reward/rewarditem/controller/RewardItemApiController.java:23
@Controller
@RequestMapping(value = "/web/reward/api/campaigns/{campaignId}/reward-items")
public class RewardItemApiController {
    @Autowired private RewardItemService rewardItemService;

    @RequestMapping(value = "", method = GET)                  // :30 — 리워드 목록 (단순)
    public ResponseWrapper<List<RewardItem>> get(@PathVariable int campaignId) {
        return ResponseWrapper.success(rewardItemService.getAllByCampaignId(campaignId));
    }

    @RequestMapping(value = "/supporter", method = GET)        // :37 — 서포터용 집계 응답
    public ResponseWrapper<RewardItemSupporter> getRewardInfo(@PathVariable int campaignId) {
        return ResponseWrapper.success(
            rewardItemService.makeRewardItemForSupport(SessionUtil.getUserId(), campaignId));
    }
}
```

### 2.2 Service
```java
// reward/rewarditem/service/RewardItemService.java:340
public RewardItemSupporter makeRewardItemForSupport(int userId, int campaignId) {
    return RewardItemSupporter.builder()
        .isDonationCategory(                                   // 기부 프로젝트 여부
            DonationCheckService.isDonation(campaignService.selectCustValueCode(campaignId)))
        .rewardList(getCampaignRewardList(campaignId))         // 리워드 목록 (본 문서 핵심)
        .membershipBenefit(                                    // 멤버십 추가 혜택
            memberShipService.getUserMemberShipBenefit(userId, campaignId))
        .build();
}

// :284
public List<WRewardCampaignProductInfo> getCampaignRewardList(int campaignId) {
    return wRewardSearchService.getCampaignRewardList(campaignId);
}
```

### 2.3 Core Search Service
```java
// core/wcampaign/service/WRewardSearchService.java:287
public List<WRewardCampaignProductInfo> getCampaignRewardList(int campaignId) {
    return wRewardSearchDao.selectCampaignRewardList(campaignId);  // MyBatis
}
```

### 2.4 ApiProxy 경로 (`/web/apip/funding/reward-items/campaigns/{id}`)
`ApiProxyServlet` 을 통해 `com.wadiz.api.funding` 으로 직행. com.wadiz.web 의 Java 코드는 통과만 함.

---

## 3. Backend Service API (proxy 경로의 경우)
`com.wadiz.api.funding` 의 리워드 관련 endpoint 에 도달. funding 내부 구현은 [`docs/com.wadiz.api.funding/api-details/reward.md`](../com.wadiz.api.funding/api-details/reward.md) 참조.

> **관찰**: 리워드 아이템 목록은 com.wadiz.web 와 com.wadiz.api.funding **양쪽 모두 제공**한다. 저장소는 동일 MySQL `Reward` 테이블을 공유하므로 데이터 정합성은 유지되지만, 집계·옵션 필드가 일부 다를 수 있음 (별도 비교 필요).

---

## 4. DB

### 4.1 핵심 SQL (`wrewardsearch-mapper.xml:274`)
```sql
-- selectCampaignRewardList(campaignId)
SELECT A.RewardId, A.CampaignId, A.Amount,
       IFNULL(SRL.Summary, A.Summary) AS Summary,
       IFNULL(SRL.Text, A.Text)       AS Text,
       A.LimitCount, A.IsOption,
       IFNULL(A.RewardType, 'SINGLE') AS RewardType,
       A.OptionType, IFNULL(SRL.OptionDetail, A.OptionDetail) AS OptionDetail,
       DATE_FORMAT(A.WhenOffering, '%Y.%m.%d') AS WhenOffering,
       A.WhenOffering AS WhenOfferingDate, A.OfferingTime, A.IsMoney,
       A.ShippingCharge, A.RequireAddress, A.displayOrder,
       B.CNT AS ParticipationCnt, B.BackedAmount,
       -- 재고 계산: LimitCount=0 이면 무제한, 아니면 잔여 = 한도 - 판매수량
       CASE WHEN A.LimitCount = 0 THEN 1
            ELSE CASE WHEN (A.LimitCount - IFNULL(B.SoldCount,0)) < 0 THEN 0
                      ELSE (A.LimitCount - IFNULL(B.SoldCount,0)) END
       END AS RemainCnt,
       -- 펀딩 종료일 (WhenHoldTo 없으면 WhenOpen + HoldDayCount)
       DATE_FORMAT(IFNULL(C.WhenHoldTo,
                          DATE_ADD(C.WhenOpen, INTERVAL C.HoldDayCount DAY)), '%Y.%m.%d') AS WhenHoldTo,
       C.IsAllOrNothing, B.SoldCount, A.LimitType as LimitQtyUnitType,
       -- 옵션 최대 레벨
       CASE WHEN A.OptionType = 1
            THEN (SELECT MAX(OptionLevel) FROM RewardOptionSetting
                    WHERE RewardId = A.RewardId AND IsDeleted = FALSE)
       END AS MAXOptionLevel,
       -- 조기 마감(LimitedTimeOffering) 여부
       CASE WHEN DATE_ADD(C.WhenOpen, INTERVAL RLTO.LimitedHours HOUR) IS NOT NULL
            THEN CASE WHEN DATE_ADD(C.WhenOpen, INTERVAL RLTO.LimitedHours HOUR) < NOW()
                      THEN TRUE ELSE FALSE END
            ELSE FALSE
       END AS IsCloseEarly
FROM Campaign C
    INNER JOIN Reward A
        ON C.CampaignId = A.CampaignId AND A.IsDeleted = FALSE
    LEFT  JOIN RewardLanguage SRL
        ON A.RewardId = SRL.RewardId AND SRL.LanguageCode = 'ko'
    LEFT  JOIN RewardShippingCountry SC
        ON A.RewardId = SC.RewardId
    LEFT  OUTER JOIN (
        SELECT CC.RewardId,
               COUNT(*)               AS CNT,
               SUM(AA.FundingAmount)  AS BackedAmount,
               SUM(CC.Qty)            AS SoldCount
        FROM BackingPayment AA
            INNER JOIN BackingPaymentMapping BB ON AA.BackingPaymentId = BB.BackingPaymentId
            INNER JOIN Backing CC               ON BB.BackingId        = CC.BackingId
        WHERE AA.CampaignId = #{campaignId}
          AND IsCanceled    = FALSE
        GROUP BY CC.RewardId
    ) B ON A.RewardId = B.RewardId
    LEFT JOIN RewardLimitedTimeOffering RLTO
        ON A.RewardId = RLTO.RewardId
WHERE C.CampaignId = #{campaignId}
ORDER BY A.displayOrder
```

### 4.2 접근 테이블

| 테이블 | 역할 | 참조 |
|---|---|---|
| `Campaign` | 캠페인 메타 (오픈일·종료일·All-or-Nothing·보유일수) | FROM |
| `Reward` | 리워드 본문 (가격·한도·옵션·배송·진행) | INNER JOIN, 메인 |
| `RewardLanguage` | 리워드 다국어 번역 (요약·본문·옵션 디테일) | LEFT JOIN |
| `RewardShippingCountry` | 배송 가능 국가 | LEFT JOIN |
| `RewardOptionSetting` | 옵션 레벨·항목 | 서브쿼리 (MaxOptionLevel) |
| `RewardLimitedTimeOffering` | 시간 제한 조기 마감 | LEFT JOIN |
| `BackingPayment` + `BackingPaymentMapping` + `Backing` | 리워드별 판매 집계 (참여 수·판매 금액·판매 수량) | LEFT OUTER JOIN 서브쿼리 |

### 4.3 후속 조회 (응답 조립)
- `DonationCheckService.isDonation(...)` — `Campaign` 의 커스텀 밸류 코드 기반
- `MemberShipService.getUserMemberShipBenefit(userId, campaignId)` — 로그인 유저의 멤버십 등급별 추가 할인·포인트 적립 (별도 모듈, 본 문서 범위 외)

---

## 엔드투엔드 시퀀스

```
[FE: reward-product/services/rewardProduct.js]
   │ GET /web/reward/api/campaigns/{id}/reward-items/supporter
   ▼
[www.wadiz.kr — com.wadiz.web]
   │
   ├─ RewardItemApiController#getRewardInfo                 [controller/RewardItemApiController.java:39]
   │
   └─ RewardItemService#makeRewardItemForSupport            [service/RewardItemService.java:340]
        ├─ DonationCheckService.isDonation(campaign.custValueCode)
        │     └─ campaignService.selectCustValueCode(id)   → Campaign 테이블
        │
        ├─ getCampaignRewardList(campaignId)
        │     └─ WRewardSearchService                       [core/wcampaign/service/WRewardSearchService.java:287]
        │           └─ wRewardSearchDao.selectCampaignRewardList(id)
        │                 └─ MyBatis: wrewardsearch-mapper.xml#selectCampaignRewardList
        │                      └─ MySQL JOIN:
        │                          Campaign ⇄ Reward ⇄ RewardLanguage
        │                                   ⇄ RewardShippingCountry
        │                                   ⇄ RewardOptionSetting (서브)
        │                                   ⇄ RewardLimitedTimeOffering
        │                                   ⇄ BackingPayment/Mapping/Backing (집계 서브)
        │
        └─ memberShipService.getUserMemberShipBenefit(userId, id)   (외부 모듈)

   → 응답: RewardItemSupporter { isDonationCategory, rewardList[], membershipBenefit }
   → FE 상태 저장 후 주문 세션 생성 (funding-payment.md flow 시작)
```

---

## 경계·미탐색

1. **`/web/reward/api/...` vs `/web/apip/funding/...` 중복** — 두 경로가 공존하는 이유는 별도 조사 필요. 마이그레이션 전환 중으로 추정 (레거시 static/entries → 신규 packages/api).
2. **MemberShipService·DonationCheckService 내부** — 별도 모듈·서비스 호출 여부 미확인.
3. **RewardOptionSetting 의 2/3차 옵션 구조** — MAXOptionLevel 쿼리만 관찰. 실제 옵션 선택 UX·가격 반영 로직은 별도 flow.
4. **상세 페이지 → 리워드 선택 전환 시점** — FE 라우팅 기반이므로 SPA loader/prefetch 존재 가능 (`useDetailPageSPALoader.ts` 에서 관찰됨, 상세 분석 후순위).
5. **앱(모바일) 경로** — 동일 endpoint 를 호출하는지 확인 필요.
6. **com.wadiz.api.funding 의 동명 엔드포인트** — 동일 데이터 집계가 funding 에도 존재. 스냅샷 일치성·update 경합 별도 검증.
