# Flow: 펀딩 프로젝트 상세 조회

> 서포터가 펀딩 프로젝트 상세 페이지를 열 때 트리거되는 체인. 캠페인 메타·리워드 아이템·카테고리·만족도 삭제 수를 한 번에 묶어 내려준다.

> 📅 **2026-04-26 업데이트** — wadiz-frontend master pull 후 펀딩 상세 화면이 다음과 같이 진화 중:
>
> ### 신규 컴포넌트 (`packages/features/src/funding-detail/`)
> - **`OverseasShippingNotice`** — 해외 배송 안내 섹션 신규
> - **`RelatedKeywordSection`** — 연관 키워드 노출 (SEO·탐색 강화) + 관련 hooks: `useInfoKeywordMutation`, `useInfoKeywords`, `useProjectTags`
> - **`DesignModeContext` + `DesignModePanel`** — 디자이너용 디자인 모드 토글 (UI 검토 도구)
> - **`scrollToAnchor`, `correctScroll`** — 탭 이동·앵커 스크롤 보정 유틸
>
> ### 신규: 앱 네이티브 인지 (`packages/features/src/native-detail/`)
> - `NativeAwareIntro`, `NativeDetailContext`, `useNativeDetailPage`, `withNativeHeaderSpec`
> - 의미: 본 문서 § 1.2 "wadiz-android/wadiz-ios — Phase 2 미진행" 부분이 진화. **WebView 가 자기가 앱 안에 있음을 감지하여 헤더·인트로 스펙을 네이티브에 맞게 조정** 하는 하이브리드 패턴 적용 중.
>
> ### Spec 문서
> `apps/global/src/pages/funding/[projectNo]/_spec/` 에 8개 spec md 추가 — `FIGMA_ANALYSIS`, `NATIVE_DETAIL_FLOW`, `RENDER_EVENT_REFACTOR`, `SCROLL_ISSUES`, `STYLE_CHANGES`, `DETAIL_MOBILE_COMPONENT_ORDER` 등. 디자인·렌더링 결정 사항 사내 기록.
>
> ### 영향
> 본 flow 의 § 1.1 wadiz-frontend 호출 대상 API/컴포넌트가 늘어남. 핵심 SQL 체인(§ 4)은 **변경 없음**. RelatedKeywordSection 의 `useInfoKeywords` 가 호출하는 새 endpoint 는 별도 추적 필요 (현 시점 미확인).

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/studio/funding/src/mocks/reward/fundingCampaignHandlers.ts:63` (FE mock으로 실제 호출 패턴 확인)
  - `wadiz-frontend/apps/global/src/features/rewards-selection/lib/testdata/rewardMockGenerator.js:20` (명시적 호스트: `https://www.wadiz.kr`)
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/campaign/controller/CampaignApiController.java:1-45`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/campaign/service/RewardCampaignService.java:144-165`
  - `com.wadiz.web/src/main/java/com/wadiz/web/reward/campaign/repository/CampaignRepository.java:30-44`
  - `com.wadiz.web/src/main/resources/sqls/reward/campaign/campaign-mapper.xml:19-~70`
- **외부 경계**: `rewardItemAdapter`, `campaignConverter`, `getSatisfactionDeletedQty` 내부 구현은 이 문서 범위 외 (별도 adapter 분석 필요).

---

## 1. Client Trigger (FE/App)

### 1.1 wadiz-frontend (웹)
- **엔드포인트 패턴**: `GET /web/reward/api/campaigns/{campaignId}`
- **실제 호출 위치**: Mock/테스트 데이터에서 명시 — `studio/funding/src/mocks/reward/fundingCampaignHandlers.ts:63`, `apps/global/src/features/rewards-selection/lib/testdata/rewardMockGenerator.js:20`
- **Host**: `https://www.wadiz.kr` (환경변수 `VITE_SERVICE_API_URL`, `com.wadiz.web` 레거시)
- **fetch 래퍼**: `packages/api/src/fetch.ts` (쿠키 세션, `wadiz-country`/`wadiz-language` 헤더 자동 첨부)
- **사용처**: 상세 페이지, 리워드 선택 화면, 메이커 스튜디오 미리보기

### 1.2 wadiz-android / wadiz-ios
- Phase 2 분석 미진행. Retrofit/URLSession 인터페이스에 동일 경로가 있을 것으로 추정되나 본 문서에서는 확인 범위 외.

---

## 2. Hub — `com.wadiz.web`

### 2.1 Controller
```java
// com.wadiz.web/reward/campaign/controller/CampaignApiController.java:29-44
@Controller
@RequestMapping(value = "/web/reward/api/campaigns")
public class CampaignApiController {

    @Autowired
    private RewardCampaignService rewardCampaignService;

    @RequestMapping(value = "/{campaignId}", method = RequestMethod.GET)
    @ResponseBody
    public ResponseWrapper<Campaign> get(@PathVariable int campaignId) {
        return ResponseWrapper.success(rewardCampaignService.get(campaignId));
    }
}
```

### 2.2 Service
```java
// com.wadiz.web/reward/campaign/service/RewardCampaignService.java:144-165
public Campaign get(int campaignId) {
    final String languageCode = LocaleContextHolder.getLocale().getLanguage();
    return Optional.ofNullable(campaignRepository.findById(campaignId))
        .map(campaign -> {
            if (campaign.getCategory() != null)
                campaign.getCategory().setCategoryName(
                    searcherCategoryUtil.getCategoryNavigator(
                        languageCode, campaign.getCategory().getCategoryId()));

            List<RewardItem> rewardItems = rewardItemAdapter.getAllByCampaignId(campaignId);
            Date earliestOffering = Optional.ofNullable(
                rewardItemAdapter.getEarliestOffering(rewardItems))
                .map(WhenOffering::getStartDate).orElse(null);

            campaign.setRewardItems(campaignConverter.toCampaignRewardItems(rewardItems));
            campaign.setEarliestOffering(earliestOffering);
            campaign.setSatisfactionDeletedQty(getSatisfactionDeletedQty(campaignId));
            return campaign;
        })
        .orElseThrow(() -> new CampaignNotFoundException("캠페인 정보가 존재하지않습니다."));
}
```

### 2.3 주요 관찰 — **com.wadiz.web 가 funding API 를 호출하지 않고 MyBatis 로 DB 직접 조회**
이 엔드포인트는 `com.wadiz.api.funding` 으로 요청을 포워딩하지 않는다. com.wadiz.web 내부에 자체 Campaign 저장소·매퍼가 있어 MySQL 을 직접 조회한다.

- `GlobalFundingGateway`, `FundingAdapter`, `MyFundingGateway` 등 upstream 어댑터가 존재하지만 **상세 조회 경로에서는 사용되지 않음**. (글로벌/내 펀딩 경로에서만 사용되는 것으로 추정, 별도 추적 필요.)
- 즉, 레거시 도메인과 신규 `com.wadiz.api.funding` 이 **같은 MySQL 을 공유**하는 상태 (역참조 없음).

---

## 3. Backend Service API
해당 플로우에서는 **com.wadiz.api.funding 호출이 관측되지 않았다**. 상세 엔드포인트에서는 com.wadiz.web 가 직접 DB 접근.

단, 별도 기능에서 com.wadiz.api.funding 이 같은 테이블을 읽을 수 있다:
- [`docs/com.wadiz.api.funding/api-details/campaign-public.md`](../com.wadiz.api.funding/api-details/campaign-public.md) — funding의 캠페인 공개 API

상세·리워드 선택은 레거시 web 이, 주문·결제·서포터 관리는 funding이 서로 다른 책임.

---

## 4. DB

### 4.1 MyBatis 쿼리 (발췌)
```xml
<!-- com.wadiz.web/src/main/resources/sqls/reward/campaign/campaign-mapper.xml:19 -->
<select id="findById" parameterType="map" resultMap="campaignResult">
    SELECT C.CampaignId
         , IFNULL(CLG.Title, C.Title) AS Title
         , C.Title AS OriginalTitle
         , IF(#{languageCode} = 'ko', C.HostName,
              IFNULL(C.GlobalMakerName, C.HostName)) AS HostName
         , C.HostEmail
         , C.PhotoId AS representativeImage_photoId
         , IF(#{languageCode} = 'ko', P.PhotoUrl,
              IFNULL(CLG.PhotoUrl, P.PhotoUrl)) AS representativeImage_photoUrl
         , P.PhotoUrl AS representativeImage_originalPhotoUrl
         , CCM.CategoryCode AS category_CategoryId
         , CM.CategoryId AS category_SubCategoryId
         , C.WhenHoldTo , C.WhenClose
         , (SELECT MIN(R.WhenOffering) FROM Reward R
              WHERE R.CampaignId = C.CampaignId AND IsDeleted = FALSE
           ) AS WhenEarliestOffering
         , (SELECT IFNULL(SUM(B.FundingAmount), 0) FROM BackingPayment B
              WHERE B.IsCanceled = FALSE AND B.CampaignId = C.CampaignId
           ) AS TotalFundingAmount
         , (SELECT COUNT(*) > 0 FROM BackingPayment
              WHERE CampaignId = C.CampaignId
                AND IsCanceled = FALSE AND IsDelivered = TRUE
                AND DeliveryStatusUpdateUserId = C.UserId
           ) AS existsDeliveredByMaker
         , C.TargetAmount, C.IsOpen, C.WhenOpen
         , C.IsStandingBy, C.IsDel, C.IsAdultContent
         , C.IsSubmitted, C.WhenSubmitted, C.isAllOrNothing
         , DATE_ADD(C.WhenHoldTo, INTERVAL 1 DAY) AS WhenPayFor
         ...
    FROM Campaign C
    LEFT JOIN CampaignLanguage CLG ON CLG.CampaignId = C.CampaignId
                                  AND CLG.LanguageCode = #{languageCode}
    LEFT JOIN Photo P              ON P.PhotoId = C.PhotoId
    LEFT JOIN CategoryMap CM       ON CM.SubCategoryId = C.CategoryId
    LEFT JOIN CategoryCodeMap CCM  ON CCM.CategoryId = CM.CategoryId
    WHERE C.CampaignId = #{campaignId}
</select>
```

### 4.2 접근 테이블

| 테이블 | 역할 | 참조 방향 |
|---|---|---|
| `Campaign` | 캠페인 본문 (제목·호스트·목표금액·일정·상태) | 메인 FROM |
| `CampaignLanguage` | 다국어 번역 | LEFT JOIN |
| `Photo` | 대표 이미지 | LEFT JOIN |
| `CategoryMap` / `CategoryCodeMap` | 카테고리 매핑 | LEFT JOIN |
| `Reward` | 리워드 아이템 (최초 offering 시점 계산) | 서브쿼리 + 후속 adapter |
| `BackingPayment` | 누적 펀딩 금액, 메이커가 직접 배송한 이력 여부 | 서브쿼리 |
| `Satisfaction` | 삭제된 만족도 수 (getSatisfactionDeletedQty) | 후속 조회 |

### 4.3 후속 조회
- `rewardItemAdapter.getAllByCampaignId(campaignId)` → `Reward` 테이블 (본 문서 범위 외)
- `getSatisfactionDeletedQty(campaignId)` → `Satisfaction` 테이블

---

## 엔드투엔드 시퀀스

```
[FE: wadiz-frontend]
     │ fetch(`${VITE_SERVICE_API_URL}/web/reward/api/campaigns/${id}`)
     │ credentials: same-origin, headers: wadiz-country/language
     ▼
[www.wadiz.kr  (com.wadiz.web, Spring 3.2)]
     │
     ├─ CampaignApiController#get(campaignId)           [reward/campaign/controller/CampaignApiController.java:39]
     │
     ├─ RewardCampaignService#get(campaignId)           [service/RewardCampaignService.java:144]
     │   │
     │   ├─ campaignRepository.findById(campaignId)     [repository/CampaignRepository.java:33]
     │   │     │ MyBatis → campaign-mapper.xml#findById
     │   │     ▼
     │   │   MySQL: SELECT FROM Campaign C
     │   │           LEFT JOIN CampaignLanguage / Photo / CategoryMap / CategoryCodeMap
     │   │           + 서브쿼리: Reward, BackingPayment
     │   │
     │   ├─ rewardItemAdapter.getAllByCampaignId(id)    → Reward 테이블
     │   ├─ campaignConverter.toCampaignRewardItems(...) (in-memory 변환)
     │   └─ getSatisfactionDeletedQty(id)               → Satisfaction 테이블
     │
     └─ JSON 응답 (ResponseWrapper<Campaign>)
```

---

## 경계·미탐색

1. **rewardItemAdapter / campaignConverter 내부** — 본 문서에서는 "외부 어댑터" 로만 표시. 상세는 별도 flow (리워드 선택) 에서 다룰 예정.
2. **GlobalFundingGateway / FundingAdapter** — 상세 조회 경로에서는 미사용. 해외 프로젝트·내 펀딩 관련 별도 flow 에서 관찰 대상.
3. **com.wadiz.api.funding 과의 DB 공유** — 두 서비스가 동일한 `Campaign`·`Reward`·`BackingPayment` 테이블을 읽는 것으로 보이나, 쓰기 책임 경계는 별도 검증 필요.
4. **앱(Android/iOS) 경로** — 앱 쪽 Retrofit endpoint 가 동일 URL 을 호출하는지 여부는 Phase 2 앱 분석 시 확정.
5. **다국어 폴백 규칙** — CampaignLanguage 미번역 시 원본 Title 을 쓰는 로직은 SQL IF 문으로 관측.
6. **만족도 삭제 수** — `getSatisfactionDeletedQty` 가 API 요청 시점에 계산되는지 캐시되는지 미확인.
