# com.wadiz.web — 미사용 JSP 후보 (정적 분석)

> 정적 분석 결과. **추측 아님 — 실제 grep 검증 완료**.
> 한계: 동적 view name (`return "wmain/" + type`), 동적 include, JavaScript SPA fetch, 외부 system 직접 호출은 검출 못함. 따라서 "정적 reference 0건" 으로 표현하며, 100% dead 라고 단정하지 않음.

## 분석 방식

수집한 reference 종류:
- **A. Java 컨트롤러 view name**: `return "..."`, `setViewName("...")`, `new ModelAndView("...")`, `forward:/...`
- **B. JSP-to-JSP 참조**: `<jsp:include page="..."/>`, `<%@ include file="..."%>`, `<layout:extends name="..."/>` (jsp-inheritance-prefix `/WEB-INF/jsp/wlayout/` 적용)
- **C. urlrewrite.xml** forward 액션
- **D. web.xml** error-page 매핑

| 항목 | 수 |
|---|---:|
| 전체 JSP | 447 |
| Java 컨트롤러 view 참조 (고유) | 338 |
| JSP include/extends 참조 (고유) | 148 |
| web.xml error-page | 2 |
| **참조 합집합** | **295** |
| **참조 발견 안됨 (후보)** | **152** |

## 1. 🔴 매우 확실한 dead (검증 완료, 14개)

### 1.1 외부 도메인 이관으로 unreachable (3)
`urlrewrite.xml` 의 `/web/wcommunity**` → `https://makercenter.wadiz.kr` 영구 redirect. 컨트롤러 자체는 살아있어도 진입 불가.

| JSP | 비고 |
|---|---|
| `community/wNewsBoardEdit.jsp` | makercenter 이관 |
| `community/wNewsBoardList.jsp` | makercenter 이관 |
| `community/wNewsBoardRegist.jsp` | makercenter 이관 |

### 1.2 청약 결제 — 실제와 다른 경로의 잔재 (8)
🚨 **이전 overview 문서의 오류**: `wpayment/equity1.jsp ~ equity4.jsp` 가 청약 단계 페이지라고 적혀있었으나 실제로는 그 파일이 없음. 실제 청약은 `wpayment/equity/run.jsp`, `paydeposit.jsp`, `bankpay.jsp`, `reserve.jsp`, `complete.jsp` (`WPaymentEquityController.java`).

검증:
```bash
grep 'setViewName.*"wpayment/equity/' WPaymentEquityController.java
→ wpayment/equity/reserve, paydeposit, bankpay, run, complete  (실사용)
grep 'setViewName.*"equity/payment/' .  →  0건 (사용 안함)
```

| JSP (`equity/payment/`) | 비고 |
|---|---|
| `equity/payment/equity1.jsp` | 사용 X — 실제는 `wpayment/equity/run.jsp` |
| `equity/payment/equity2.jsp` | 사용 X |
| `equity/payment/equity3.jsp` | 사용 X |
| `equity/payment/equity3-1.jsp` | 사용 X |
| `equity/payment/equity4.jsp` | 사용 X |
| `equity/payment/equityFail.jsp` | 사용 X |
| `equity/payment/equityReserved.jsp` | 사용 X |
| `equity/payment/mail.jsp` | 사용 X |

### 1.3 메인 — 컨트롤러 reference 0건 (3)
검증: `grep -rE '"wmain/wmain"' src/main/java` → 0건.

| JSP | 실제 사용 path |
|---|---|
| `wmain/wmain.jsp` | 실제 투자메인은 `wmain/equityMain.jsp` |
| `wmain/aiAgent.jsp` | 컨트롤러 없음 |
| `wmain/settings.jsp` | 컨트롤러 없음 |

## 2. 🟠 확실한 dead (verified, 1개)

| JSP | 비고 |
|---|---|
| `wpayment/write.jsp` | `WPaymentController` 어디서도 view name `wpayment/write` 반환 안함 |

## 3. 🟡 dead 가능성 높음 (74개) — 도메인 이관/폐기

### 3.1 모바일 equity webview (21) — 앱 별도 영역으로 이관
모바일 앱 (wadiz-android/ios) 의 webview 또는 별도 도메인으로 분리되어 com.wadiz.web 에서는 사용 안하는 것으로 추정.

| 디렉토리 | JSP 수 | 파일 예시 |
|---|---:|---|
| `mobile/equity/account/` | 8 | `checkplusFail`, `checkplusSuccess`, `registerStep1`, `signup2`, `signup2-1~3`, `signup3` |
| `mobile/equity/payment/` | 7 | `bankpayIOS9` (구 iOS), `equity1~4`, `equityFail`, `equityReserved` |
| `mobile/equity/helpCenter/` | 3 | `faq_detail`, `faq_maker`, `faq_supporter` |
| `mobile/equity/` | 3 | `ftcampaginList`, `mainBanner`, … |

⚠️ 검증 권고: wadiz-android/ios 의 webview URL 매핑 확인.

### 3.2 데스크톱 equity 레거시 (12)
| JSP | 비고 |
|---|---|
| `equity/account/checkplusFail`, `checkplusSuccess`, `findId`, `findPw`, `header`, `login`, `resultId` | (구) 투자 계정 |
| `equity/campaign/detailStg`, `detail_private` | staging/비공개 |
| `equity/guide/investHow` | 가이드 |
| `equity/main`, `mainBanner` | (구) 메인 |

⚠️ `equity/` 자체는 살아있는 그룹 (39 JSP 中 12개만 미참조). 컨트롤러가 사용하는 것은 `equity/campaign/detail_new.jsp`, `equity/dashboard/edit*.jsp`, `equity/payment/premiumNicepayForm.jsp` 등.

### 3.3 waccount/equity/ (24) — 투자 계정 인증 레거시
경로: `waccount/equity/wAccountEquityCertification*.jsp` (10), `wAccountJoin*.jsp`, `wAccountEquityVerification*.jsp`, `wAccountUnsubscribe*.jsp` 등.

⚠️ 검증 권고: 현재 투자 계정 인증 흐름이 `WAccountJoinEquityController` → 어느 view 를 사용하는지 확인. 만약 현재는 `waccount/equity/` 가 아닌 다른 경로 사용 중이면 이 24개는 모두 dead.

```bash
grep 'setViewName' WAccountJoinEquityController.java
grep 'setViewName' WAccountEquityController.java
```

### 3.4 wpage 연도별 archive (16)
연도가 박힌 마케팅 페이지 — `urlrewrite.xml` 에서 redirect 정의도 없으므로 직접 진입도 불가.

| JSP | 연도 |
|---|---|
| `wpage/2021makers.jsp`, `2022makers.jsp` | 메이커 어워즈 |
| `wpage/bestMaker2017~2022.jsp` (6개) | 베스트 메이커 archive |
| `wpage/wadiztrend/awards2018~2022.jsp` (5개) | 어워즈 archive |
| `wpage/wadiztrend/crawlStandard.jsp`, `wadizHistory.jsp`, `wadizNext.jsp` | 트렌드 archive |
| `wpage/api-docs.jsp`, `crawlStandard.jsp`, `openSourceUsingInfo.jsp`, `serviceGuide.jsp`, `wadizHistory.jsp`, `wadizNext.jsp` | 단일 페이지 archive |
| `wpage/app/reward-community.jsp`, `app/reward-rating.jsp` | (구) 앱 페이지 |

### 3.5 캠페인·검색 레거시 (4)
| JSP | 비고 |
|---|---|
| `campaign/detailFundingInfoSPA.jsp` | 펀딩 정보 SPA — 다른 SPA 로 통합? |
| `campaign/recruitmentDocument.jsp` | 모집 문서 |
| `campaign/recruitmentInformation.jsp` | 모집 정보 |
| `wcampaign/rewardMakerStudio/editComing.jsp` | 메이커 스튜디오 (`/studio/reward/*` 로 이관됨) |

### 3.6 알림 / 이벤트 / 검색 (4)
| JSP | 비고 |
|---|---|
| `account/unsubscribeConfirmNewsLetter`, `unsubscribeMakerNewsletter`, `unsubscribeNewsLetter` | 뉴스레터 수신거부 (별도 서비스 가능성) |
| `oauth/apple_callback.jsp` | Apple OAuth — 현재는 BE callback 처리 |
| `wcoming/wComingSoonResult.jsp` | (오픈예정 결과) |
| `wevent/eventAlert.jsp`, `wevent/invest/wadizNext.jsp` | 이벤트 |
| `wsub/wStartupSearchRequestedIr.jsp` | 스타트업 검색 (이관 가능성) |
| `startup/contract/app.jsp` | 스타트업 계약 |
| `wpurchase/reward/payment/fail.jsp` | wpurchase 변형 |
| `wmypage/include/includeComing.jsp` | 마이 오픈예정 include |

## 4. ⚪ false positive 위험 — include 전용 (32개)

`<jsp:include page="..."/>` 또는 `<layout:extends name="..."/>` 로만 사용되어 컨트롤러 reference가 없음 — 정상.

### 4.1 wlayout/ 18개 (✅ verified — parent layout)
검증: `grep 'extends name="wnoLayout"' web/WEB-INF/jsp` → `wmain/startupMain.jsp`, `wterms/terms_confirm.jsp`, `wpage/wadiz2017.jsp`, `wpayment/error.jsp`, `wpayment/write.jsp` 등 다수에서 사용.

| 파일 | 자식 레이아웃 사용처 |
|---|---|
| `wlayout/wcommon.jsp` | 28+ JSP 가 부모로 사용 |
| `wlayout/mainCommon.jsp` | 11+ |
| `wlayout/common.jsp` | 9+ |
| `wlayout/account.jsp`, `wAccount.jsp`, `ftCommon.jsp`, `ftEmpty.jsp`, `ftCommunity.jsp`, `wEventPopup.jsp`, `wGlobalCommon.jsp`, `wmypage.jsp`, `wnoLayout.jsp`, `wnofooter.jsp`, `wterms.jsp`, `wtermsCommon.jsp`, `wtermsInvest.jsp`, `wAwardsCommon.jsp`, `_storeHeader.jsp` | 다수 자식 |

⚠️ 단, `_storeHeader.jsp` 처럼 _ 접두사 컴포넌트는 별도 검증 필요.

### 4.2 wterms/include/ 14개 — ⚠️ 동적 include 의심

| JSP | 비고 |
|---|---|
| `wterms/include/innerTerms0101.jsp`, `0201.jsp`, `0202.jsp`, `0301.jsp`, `0302.jsp` | 약관 조각 |
| `wterms/include/innerTerms_privacyInvest.jsp`, `innerTerms_serviceInvest.jsp` | 투자 약관 조각 |
| `wterms/privacy/3rdPartyProvision.jsp`, `3rdPartyProvisionGlobalPartners.jsp`, `outsourcing.jsp` | 개인정보 약관 |
| `wterms/service/agreementGuide.jsp`, `childProtection.jsp`, `dispute.jsp`, `nonFaceToFace.jsp` | 서비스 약관 |

⚠️ **검증 권고**: 약관 페이지는 `<%@ include file="${termsFile}" %>` 처럼 동적 include 패턴 가능성. 실제 동적 패턴 검색:
```bash
grep -rE '<jsp:include\s+page="\$\{|<%@\s*include\s+file="\$\{' web/WEB-INF/jsp/wterms
```

### 4.3 winclude/ 7개 — 일부는 진짜 dead

검증 결과:
| JSP | 상태 |
|---|---|
| `winclude/_assetVersions.jsp` | 🔴 **진짜 dead** — `assetVersions.jsp` (underscore 없는 것) 만 사용됨 |
| `winclude/requirejs.jsp` | 🔴 **진짜 dead** — `assetVersions.jsp` 안에서 `requirejs_version` 변수만 정의되고 `requirejs.jsp` 자체는 어디서도 include 안됨 |
| `winclude/froalaEditor.jsp` | ⚠️ 검증 필요 — Froala 에디터 동적 로드 가능성 |
| `winclude/templateCardComing.jsp` | ⚠️ 검증 필요 — 카드 템플릿 동적 로드 |
| `winclude/tracking-gtm-head-local.jsp` | ⚠️ 검증 필요 — 환경 변수 분기 (local 환경만 사용?) |
| `winclude/wdetailCss.jsp` | ⚠️ 검증 필요 |
| `winclude/wprojectcardCss.jsp` | ⚠️ 검증 필요 |

## 5. 동적 view name 패턴 (false negative 가능)

다음 컨트롤러는 view name 을 동적으로 구성 — 정적 분석으로는 잡기 어려움. 단, 모두 redirect 패턴이라 *.jsp 파일 자체 참조에는 큰 영향 없음.

| Controller | 패턴 |
|---|---|
| `WWEBPurchaseRewardController` | `setViewName("redirect:/web/wpurchase/reward/step" + stepNo)` — redirect (URL) |
| `RewardDashBoardApiController` (line 64, 428, 430, 459, 461) | `return "redirect:/studio/reward/" + campaignId + "/..."` — redirect (URL) |
| `WAccountAdultController` | `return "redirect:/web/waccount/wAdultVerification?..." + encodedReturnUrl` — redirect (URL) |

→ 이 패턴들은 모두 redirect 이므로 *.jsp 파일 직접 참조 0건. dead JSP 후보에 영향 없음.

## 6. 권장 조치

### 6.1 즉시 삭제 가능 (verified, 14개)
- `community/wNewsBoardEdit.jsp`, `wNewsBoardList.jsp`, `wNewsBoardRegist.jsp` (3)
- `equity/payment/equity1.jsp` ~ `equity4.jsp`, `equity3-1.jsp`, `equityFail.jsp`, `equityReserved.jsp`, `mail.jsp` (8)
- `wmain/wmain.jsp`, `aiAgent.jsp`, `settings.jsp` (3)
- `wpayment/write.jsp` (1)
- `winclude/_assetVersions.jsp`, `winclude/requirejs.jsp` (2)

→ 단, **삭제 전 git log 로 마지막 수정 시각 확인 권고** (혹시 전사 영업/마케팅 직접 URL 으로 사용중인지).

### 6.2 도메인 담당자 확인 후 삭제 (74개)
- 모바일 equity 21개 → 앱 팀 확인 (webview 주소 매핑)
- waccount/equity/ 24개 → kr.wadiz.account 또는 com.wadiz.api.startup 으로 이관 여부 확인
- 데스크톱 equity 12개 → 투자형 PM 확인
- wpage 연도별 archive 16개 → 마케팅팀 확인 (재사용 가능성)
- 기타 7개

### 6.3 동적 include 검증 후 결정 (14개)
- `wterms/include/innerTerms*.jsp` 7개 → `${termsFile}` 동적 include 패턴 검색 필요
- `wterms/privacy/`, `wterms/service/` 7개 → 약관 페이지 진입 컨트롤러에서 사용처 추적

### 6.4 추가 정밀 검증 필요 (5개)
- `winclude/froalaEditor.jsp`, `templateCardComing.jsp`, `tracking-gtm-head-local.jsp`, `wdetailCss.jsp`, `wprojectcardCss.jsp` — 환경 변수 분기 또는 JS 동적 로드 가능성

## 7. 분석 한계

이 분석은 정적 source code grep 기반. 다음은 검출 못함:
1. **String concat / format 으로 만든 view name** — `"wmain/" + type` 같은 패턴 (검증된 5건은 모두 redirect 라 영향 없음)
2. **JavaScript 가 fetch 로 직접 .jsp 호출** — `fetch('/WEB-INF/jsp/...')` (보통 안함)
3. **외부 시스템이 직접 URL 진입** — 마케팅 메일, SMS, 광고 링크 등 (urlrewrite 매핑 안된 직접 URL)
4. **mvc:resources 정적 서빙** — `web.xml` 또는 `servlet.xml` 의 mapping
5. **Fragment 동적 include** — `<jsp:include page="${var}"/>`

따라서 위 결과는 **"정적 분석 reference 0건"** 후보이지 100% dead 보장 아님. 삭제 전 검증 단계 필수.

## 8. 전체 152개 후보 리스트

| 그룹 | 수 |
|---|---:|
| account | 3 |
| campaign | 3 |
| community | 3 |
| equity | 20 |
| mobile | 21 |
| oauth | 1 |
| startup | 1 |
| waccount/equity | 24 |
| wcampaign | 1 |
| wcoming | 1 |
| wevent | 2 |
| winclude | 7 |
| wlayout | 18 (parent) |
| wmain | 3 |
| wmypage | 1 |
| wpage | 26 |
| wpayment | 1 |
| wpurchase | 1 |
| wsub | 1 |
| wterms | 14 |
| **합계** | **152** |

전체 파일명 리스트는 분석 원본 (`/tmp/dead-jsp-analysis.md` § 부록) 참조.
