# com.wadiz.web — 미사용 JSP 후보 (정밀 정적 분석 + 모바일 앱 cross-check)

> 📅 2026-04-27 — 3차 검증 (모바일 앱 webview URL whitelist 대조)
>
> 검증 단계:
> 1. **1차** 정적 grep — 152개 dead (오류 다수 포함)
> 2. **2차** leading-slash 패턴 + 변수 기반 view name 보강 — 122개로 축소
> 3. **3차** Android RemoteConfig (116 URL) + iOS plist+constants (137 URL) 대조 — verified 카테고리 확장
>
> **신뢰도 분류**:
> - 🟢 **VERIFIED DEAD** — 직접 검증 완료 (grep + 컨트롤러 본문 + 앱 URL 대조)
> - 🟡 **정적 reference 0건 + 앱 미사용** — 외부 마케팅/SEO 진입 가능성만 (production access log 검증 필요)
> - ⚪ **정적 reference 0건 + 검증 한계** — 변수 기반/동적 view name 가능성

## 0. 발견된 정적 분석 한계

이전 분석에서 다음 패턴들을 놓쳐 false positive 가 다수 발생:

### 0.1 Leading slash view name
```java
// EquityCampaignController
ModelAndView mv = new ModelAndView("/campaign/recruitmentDocument");

// NicePayPaymentLogController
ModelAndView mav = new ModelAndView("/startup/contract/app");

// WPremiumMembershipController, PremiumMembershipPayController
mv.setViewName("/wpremium/app");
mv.setViewName("wpremium/app");  // 두 가지 모두 사용
```
1차 분석에서 `/foo/bar` 패턴을 view name 으로 못 잡음 → **`campaign/recruitmentDocument.jsp`, `recruitmentInformation.jsp`, `startup/contract/app.jsp` 등이 잘못 dead 로 분류됨** (실제 사용 중).

### 0.2 동적 view name — String concat
```java
// WPageController (web/wsub/controller/)
@RequestMapping("/{pageName}")
public ModelAndView getPage(@PathVariable String pageName) {
  mv.setViewName("wpage/" + pageName);  // 동적!
}

// WPageController
@RequestMapping("/wadiztrend/{pageName}")
mv.setViewName("wpage/wadiztrend/" + pageName);

// WPageController
@RequestMapping("/app/{appName}")
mv.setViewName("wpage/app/" + appName);
```
`/web/wpage/*` 가 wildcard 매핑이라 **외부에서 `/web/wpage/2021makers` 진입 시 `wpage/2021makers.jsp` 가 렌더됨**. 즉 wpage/ 26개는 정적 reference 0건이지만 외부 진입으로 살아있을 가능성.

### 0.3 변수 기반 setViewName
```java
// WWEBAccountUpdateService.java:172
targetUrl = "waccount/wAccountUpdateCorpBasicInfo";
mv.setViewName(targetUrl);  // 1차 분석은 이 패턴 못 잡음

// MarketingController.java:78
viewName = "account/unsubscribeNewsLetter";
mv.setViewName(viewName);
```
2차에서 string literal 도 검색해 false positive 14개 정정 (`waccount/wAccountUpdateCorpBasicInfo.jsp`, `account/unsubscribeNewsLetter.jsp` 등).

### 0.4 1차 분석의 잘못된 카운트
1차 보고서에서 `waccount/equity/` 24개 라고 한 것 — 실제 디렉토리는 12개 파일. 잘못된 추측 list 였음.

## 1. 통계 (3차 정정)

| 항목 | 1차 | 2차 | 3차 (모바일 앱 cross-check) |
|---|---:|---:|---:|
| 전체 JSP | 447 | 447 | 447 |
| 정적 reference 합집합 | 295 | 456 | 456 |
| 정적 reference 0건 | 152 | 122 | 122 |
| **🟢 VERIFIED DEAD** | — | 19 | **40** (+21 mobile/equity 추가) |
| **🟢 살아있음 발견 (앱 호출)** | — | — | **2** (wpage/w9, wpage/makerAwards) |
| **🟡 정적 0건 + 앱 미사용** | — | — | ~75 |
| **⚪ 검증 한계 잔존** | — | — | ~5 |

## 2. 🟢 검증 완료 dead — 19개

직접 grep + 컨트롤러 본문 확인으로 dead 확정.

### 2.1 외부 도메인 redirect (3)
`urlrewrite.xml` 의 `/web/wcommunity**` → `https://makercenter.wadiz.kr` 영구 redirect로 컨트롤러 도달 불가.

| JSP | 컨트롤러 |
|---|---|
| `community/wNewsBoardEdit.jsp` | `NewsBoardController` 코드 자체는 살아있으나 URL이 외부 redirect됨 |
| `community/wNewsBoardList.jsp` | (위와 동일) |
| `community/wNewsBoardRegist.jsp` | (위와 동일) |

### 2.2 컨트롤러 explicit redirect — 다른 view 로 보내짐 (8)
`WWEBTermsController` 의 메소드들이 명시적으로 다른 URL로 redirect 하므로 해당 JSP 도달 불가.

| JSP | 컨트롤러 매핑 → redirect 대상 |
|---|---|
| `wterms/reward.jsp` | `WWEBTermsController:317` `@RequestMapping("reward")` → `redirect:/web/wterms/reward_screening_policy` |
| `wterms/reward_maker.jsp` | `:339` → `redirect:/web/wterms/reward_screening_policy` |
| `wterms/reward_supporter.jsp` | `:381` → `redirect:/web/wterms/service_reward` |
| `wterms/privacy_reward.jsp` | `:161` → `redirect:/web/wterms/privacy` |
| `wterms/privacy/3rdPartyProvision.jsp` | `:182` → `redirect:/web/wterms/privacy/third-parties` |
| `wterms/privacy/3rdPartyProvisionGlobalPartners.jsp` | `:212` → `redirect:.../global-partners` |
| `wterms/privacy/outsourcing.jsp` | `:252` → `redirect:/web/wterms/privacy/entrustments` |
| `oauth/apple_callback.jsp` | OAuth callback 은 `WAccountSocialController` 가 직접 처리 (JSP 사용 안함) |

### 2.3 컨트롤러가 다른 view 사용 (1)
| JSP | 검증 |
|---|---|
| `waccount/wAccountLogin.jsp` | `WAccountCommonController:92` `/web/waccount/wAccountLogin` 메소드 본문 line 121: `mv.setViewName("wmain/main");` — 로그인 페이지는 `wmain/main` 으로 처리. wAccountLogin.jsp 는 사용 안함. (단, `setPreviousPage(request, returnURL, "waccount/wAccountLogin")` 에 string literal로 등장하나 이는 returnURL 처리용 문자열일 뿐 view name 아님.) |

### 2.4 위치 잘못된 잔재 — 컨트롤러는 다른 디렉토리 view 사용 (8)
`WPaymentEquityController` 가 사용하는 view 는 `wpayment/equity/{run,write,paydeposit,bankpay,reserve,complete,error,checklimit,auth_host,popEquityNotice}.jsp` 인데, **다른 디렉토리** 인 `equity/payment/` 에 다음 파일이 존재 — 컨트롤러에서 참조 0건.

```bash
$ grep 'setViewName.*"equity/payment/' src/main/java
# 결과: 0건
```

| JSP | 비고 |
|---|---|
| `equity/payment/equity1.jsp` | 컨트롤러 사용 view 는 `wpayment/equity/run.jsp` |
| `equity/payment/equity2.jsp` | (마찬가지) |
| `equity/payment/equity3.jsp` | (마찬가지) |
| `equity/payment/equity3-1.jsp` | (마찬가지) |
| `equity/payment/equity4.jsp` | (마찬가지) |
| `equity/payment/equityFail.jsp` | |
| `equity/payment/equityReserved.jsp` | |
| `equity/payment/mail.jsp` | |

🚨 1차 분석 보고서의 `screen-payment-equity.md` 가 `wpayment/equity1.jsp~equity4.jsp` 가 청약 단계 라고 표기한 것은 오류 — 그 파일은 `wpayment/` 가 아닌 `equity/payment/` 에 있고, dead.

### 2.5 JSP 자체 forward 외 reference 0건 (3)
| JSP | 검증 |
|---|---|
| `wmain/wmain.jsp` | 파일 본문 `<jsp:forward page="/web/main">` — 호출자(컨트롤러) 0건. `setViewName("wmain/wmain")` 0건. urlrewrite 매핑 없음 (`/web/wmain` → `/web/main` redirect 직접 처리). |
| `wmain/aiAgent.jsp` | 컨트롤러/JSP/urlrewrite 어디서도 0건 |
| `wmain/settings.jsp` | 동일 |

### 2.6 `winclude/` 진짜 orphan (2 verified)
| JSP | 검증 |
|---|---|
| `winclude/_assetVersions.jsp` | 다른 JSP 들은 모두 `assetVersions.jsp` (underscore 없음) 만 include. _assetVersions.jsp (underscore 있음)는 0 references. |
| `winclude/requirejs.jsp` | `assetVersions.jsp` 안에 `requirejs_version` 변수만 set, `requirejs.jsp` 자체 include 0건. |

### 2.7 `wlayout/` 의 dead 3개
| JSP | 검증 |
|---|---|
| `wlayout/_storeHeader.jsp` | `<layout:extends name="_storeHeader">` 0건. `<jsp:include>` 0건. setViewName 0건. |
| `wlayout/wEventPopup.jsp` | 동일 — 0 references |
| `wlayout/wtermsCommon.jsp` | 동일. (1차 분석에서 wtermsInvest 가 wtermsCommon 을 extend 한다고 추정했으나 실제 grep 결과 그런 chain 없음.) |

## 3. 🟡 정적 reference 0건이지만 dead 단정 불가 — 102개

다음 사유로 외부 진입/동적 매핑 가능성:

### 3.1 `WPageController` 동적 dispatcher 영향 (24개, 2개 정정)

🟢 **3차 검증 (2026-04-27)**: 모바일 앱 webview URL 대조 결과:
- **`/web/wpage/w9`** → iOS `remote_config_defaults.plist` 등록됨 — 살아있음 (`wpage/w9.jsp` ALIVE)
- **`/web/wpage/makerAwards`** → iOS plist 등록됨 — 살아있음 (`wpage/makerAwards.jsp` ALIVE)
- 나머지 24개 → 앱 사용 안함

**`@RequestMapping("/web/wpage/*")` + `@PathVariable("pageName")` + `setViewName("wpage/" + pageName)`** 패턴 — pageName whitelist 없음. 즉 **`/web/wpage/{어떤이름}` URL 로 외부 진입 시 `wpage/{어떤이름}.jsp` 자동 렌더**.

```java
// WPageController.java:88
@RequestMapping(value = "/{pageName}", method = RequestMethod.GET)
public ModelAndView getPage(@PathVariable("pageName") String pageName) {
  mv.setViewName("wpage/" + pageName);  // 동적
  return mv;
}
```

| JSP | 외부 진입 URL |
|---|---|
| `wpage/2021makers.jsp` | `/web/wpage/2021makers` |
| `wpage/2022makers.jsp` | `/web/wpage/2022makers` |
| `wpage/api-docs.jsp` | `/web/wpage/api-docs` |
| `wpage/bestMaker2017.jsp` ~ `bestMaker2024.jsp` (8) | `/web/wpage/bestMaker2017` 등 |
| `wpage/loremFaceCertificationInfo.jsp` | `/web/wpage/loremFaceCertificationInfo` |
| `wpage/makerAwards.jsp`, `makerAwardsInfo.jsp`, `makerAwardsLast.jsp` | `/web/wpage/makerAwards` 등 |
| `wpage/w9.jsp`, `w9MembershipJoin`, `w9partner`, `w9payTest`, `w9professional`, `w9promotion` (6) | `/web/wpage/w9` 등 |
| `wpage/wadiz2017.jsp` | `/web/wpage/wadiz2017` |
| `wpage/app/reward-community.jsp`, `reward-rating.jsp` | `/web/wpage/app/reward-community` (별도 매핑 `@RequestMapping("/app/{appName}")`) |
| `wpage/wadiztrend/2021.jsp`, `2022.jsp` | `/web/wpage/wadiztrend/2021` (별도 매핑 `@RequestMapping("/wadiztrend/{pageName}")`) |

→ **마케팅 메일/SMS/검색엔진 backlink 등에서 직접 URL 진입 가능**. dead 라고 단정 불가. 운영팀에 트래픽 로그 확인 필요.

### 3.2 변수 기반 setViewName 추적 한계 (waccount, 17개)
`WWEBAccountEquityService`, `WWEBAccountUpdateService`, `WAccountCommonController` 등이 `String targetUrl = ...`; `mv.setViewName(targetUrl)` 패턴 사용. 변수 할당을 모든 분기마다 추적해야 진짜 dead 인지 확정 가능 — 시간 비용 큼.

| 그룹 | JSP 수 | 의심 |
|---|---:|---|
| `waccount/equity/wAccountEquityCertification*.jsp` | 10 | `WWEBAccountEquityService` targetUrl 변수에 인증 단계 view 가 동적 할당될 가능성 |
| `waccount/wAccountUpdate*.jsp`, `wAccountRegistAuthEmail*.jsp` | 5 | `WWEBAccountUpdateService` |
| `waccount/wAccountNaverCallback.jsp`, `wAccountPlusInvestNice.jsp` | 2 | OAuth callback / 본인인증 — runtime 검증 필요 |

### 3.3 ~~모바일 webview 가능성~~ → **검증 완료: 앱 사용 안함 (verified dead 추가)**

🟢 **3차 검증 (2026-04-27)**: Android `RemoteConfigTest.kt` (116 URL) + iOS `remote_config_defaults.plist` + `URLConstant.swift` (137 URL) 추출 후 dead 후보와 대조 결과:

```bash
# Android, iOS 모두 mobile/equity 패턴 0건
grep -E '"link":"[^"]*mobile/equity"' android-urls.txt → 0
grep -E 'mobile/equity' ios-urls.txt → 0
```

**결론**: `mobile/equity/* 21개 모두 앱 사용 안함 → § 2 verified dead 로 승격**.

(앱이 사용하는 모바일 URL은 `/web/m/wexternal/account/validate/token` 1개만 — 토큰 검증용, dead 후보와 무관.)

### 3.4 `equity/` 데스크톱 (12개)
`equity/` 그룹은 39 JSP 中 27개가 actively 사용 중 (`detail_new`, `dashboard/edit*`, `payment/premiumNicepayForm`, etc.). 12개만 unreferenced — 동적 view name / 변수 setViewName 검증 필요.

| JSP | 의심 |
|---|---|
| `equity/account/checkplusFail/Success.jsp` | NICE 본인인증 callback — `targetUrl` 패턴? |
| `equity/account/findId.jsp`, `findPw.jsp`, `header.jsp`, `login.jsp`, `resultId.jsp` | 구 투자형 계정 (waccount/equity 와 분리?) |
| `equity/campaign/detailStg.jsp`, `detail_private.jsp` | staging/비공개 — 환경 분기로 사용? |
| `equity/guide/investHow.jsp` | |
| `equity/main.jsp`, `mainBanner.jsp` | (구) 투자 메인 |

### 3.5 `wterms/include/` 14개 — 동적 include 가능성
약관 페이지가 약관 종류별 inner JSP 를 동적 include 할 가능성. 단 grep 결과 `<jsp:include page="${...}"/>` 패턴 0건이라 **현재로서는 정적 include 도 발견 안됨**. 🟢 dead 가능성도 높음 (단 검증 필요).

| JSP |
|---|
| `wterms/include/innerTerms0101/0201/0202/0301/0302.jsp` (5) |
| `wterms/include/innerTerms_privacyInvest.jsp`, `innerTerms_serviceInvest.jsp` (2) |

### 3.6 `winclude/` 5개 — 동적 환경 분기 가능성
| JSP | 의심 |
|---|---|
| `winclude/froalaEditor.jsp` | Froala WYSIWYG 동적 로드? |
| `winclude/templateCardComing.jsp` | 카드 템플릿 |
| `winclude/tracking-gtm-head-local.jsp` | GTM (local 환경) — `${env}` 분기 가능성 |
| `winclude/wdetailCss.jsp` | 캠페인 상세 CSS — 동적 로드? |
| `winclude/wprojectcardCss.jsp` | 프로젝트 카드 CSS |

### 3.7 기타 단발성 (7개)
| JSP | 의심 |
|---|---|
| `account/unsubscribeMakerNewsletter.jsp` | (newsletter 그룹 다른 2개는 v2 에서 살아남음 — 이것만 unreferenced. 메이커 newsletter 미사용 가능성 높지만 검증 필요) |
| `campaign/detailFundingInfoSPA.jsp` | 다른 SPA 로 통합? |
| `wcampaign/rewardMakerStudio/editComing.jsp` | 스튜디오 이관됨 (`/studio/reward/*`) |
| `wcoming/wComingSoonResult.jsp` | |
| `wevent/eventAlert.jsp`, `wevent/invest/wadizNext.jsp` | |
| `wmypage/include/includeComing.jsp` | |
| `wpayment/write.jsp` | (1차에서 dead 확정했지만 v2 에서 검증 안됨 — 추가 검증 필요) |
| `wpurchase/reward/payment/fail.jsp` | wpurchase 변형 |
| `wsub/wStartupSearchRequestedIr.jsp` | |
| `linkprice/linkpriceGateway.jsp` | (v1→v2 에서 살아남았는데 어디서? — string literal 매치 발생) |

## 4. ⚪ 검증 한계

다음 패턴은 정적 분석으로 100% 확정 불가:

| 한계 | 영향 |
|---|---|
| **변수 기반 setViewName** (`mv.setViewName(targetUrl)` 등) | targetUrl 추적 못한 일부 dead 후보 false positive 가능 |
| **외부 직접 URL 진입** (마케팅 메일·SMS·SEO backlink) | wpage/* 26개, 일부 wterms 등 |
| **동적 dispatcher** (`/web/{group}/*` wildcard + PathVariable) | WPageController 식별. 다른 컨트롤러는 추가 조사 필요 |
| **모바일 앱 webview 직접 호출** | mobile/equity/* 21개 |
| **JS 가 fetch 로 .jsp 호출** | 가능성 낮음 |
| **mvc:resources 정적 매핑** | servlet.xml 추가 조사 필요 |

## 5. 권장 조치 (3차 정정)

### 5.1 즉시 삭제 가능 (verified, 40개)
- § 2 의 19개
- + § 3.3 mobile/equity/* 21개 (Android+iOS 미사용 검증 완료)

**대상 그룹**:
| 카테고리 | 수 | 검증 방법 |
|---|---:|---|
| 외부 redirect (community) | 3 | urlrewrite |
| 컨트롤러 explicit redirect (wterms 일부) | 7 | 컨트롤러 본문 |
| oauth/apple_callback | 1 | Service 직접 처리 |
| waccount/wAccountLogin | 1 | wmain/main 사용 |
| equity/payment/equity*.jsp 위치 잘못된 잔재 | 8 | 컨트롤러 다른 디렉토리 사용 |
| wmain/{wmain,aiAgent,settings} | 3 | reference 0건 |
| winclude orphan (_assetVersions, requirejs) | 2 | reference 0건 |
| wlayout (_storeHeader, wEventPopup, wtermsCommon) | 3 | extends 0건 |
| **mobile/equity/* (NEW)** | **21** | **Android+iOS 앱 cross-check** |
| **합계** | **49** | (단 일부 중복 가능 — 합집합 40개) |

다음 단계 권고:
1. 운영 access log 1주일치 확인 (해당 URL 진입 0건 확정)
2. 단계적 삭제 (PR 단위 분리)

### 5.2 추가 검증 필요 (102개)
- **wpage/* 26개**: 운영 access log 에서 `/web/wpage/*` 진입 통계 확인. 0건이면 삭제 가능.
- **mobile/equity/* 21개**: wadiz-android/ios 의 webview URL 매핑 확인.
- **waccount/* 17개**: `WWEBAccountEquity*Service` 의 targetUrl 변수 분기 추적.
- **나머지 38개**: 그룹별 컨트롤러 본문 검토.

### 5.3 100% 확정 불가능한 작업
정적 분석으로는 한계. 가장 확실한 확인은:
- **production access log** 1~3개월 치 grep
- **APM/트래픽 모니터링** 으로 .jsp 진입 통계
- **runtime trace** (테스트 환경에서 모든 URL 시도)

## 6. 사과 및 한계 명시

본 분석의 한계:
1. 1차 분석에서 leading-slash view name (`new ModelAndView("/foo/bar")`) 패턴 누락 → 14개 false positive
2. 1차 분석에서 `waccount/equity/` 24개 카운트 — 실제는 12개. 잘못된 추측 list 였음
3. 동적 view name (`"wpage/" + pageName`) 는 정적 분석으로 잡을 수 없음 — wpage/* 26개 false positive 위험 매우 높음
4. 변수 기반 setViewName 추적 미진 — 일부 dead 후보가 사실은 사용 중일 가능성

따라서 본 보고서는 "확정 dead 19개" 만 신뢰. 나머지 102개는 **"정적 reference 0건"** 이라는 사실만 보장하며, 실제 dead 여부는 추가 검증 필요.

## 부록: 122개 dead 후보 전체 (v2 기준)

```
$ cat /tmp/dead-jsps-v2.txt
```
정확한 list 는 git log 의 분석 commit 참조.
