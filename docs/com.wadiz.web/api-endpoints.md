# com.wadiz.web — 컨트롤러·엔드포인트 전수

> **303 controller / @RequestMapping 1,987회 / Java 43,335줄 / Jersey @Path 14 패키지 / 2 ProxyServlet**
> Spring 3.2 + Jersey JAX-RS 혼용. JSP 페이지 렌더 + AJAX/JSON + REST API + Proxy.

## 1. 패키지 구조 — TOP 30

| 패키지 | 컨트롤러 수 | 라인 합 | 용도 |
|---|---:|---:|---|
| `web/reward/**` | 69 | 5,315 | 리워드 펀딩(스토리·서포터·환불·쿠폰·배송·결제) — `funding`, `screening`, `settlement`, `coupon`, `comment`, `story`, `rewarditem` 등 |
| `web/equity/**` | 32 | 4,427 | 투자형(증권형) 펀딩 — KSFC 예치금·증권신고서·dashboard·premium |
| `web/waccount/**` | 16 | 3,930 | 회원가입·로그인·계정 설정·소셜 로그인·본인인증·드롭아웃 |
| `web/wpayment/**` | 2 | 2,484 | 결제 (보상형 813줄 + 투자형 1,671줄) |
| `web/startup/**` | 17 | 2,103 | 스타트업 IR·투자 |
| `web/maker/**` | 16 | 1,986 | 메이커 센터 (일부) |
| `web/ftdashboard/**` | 2 | 1,735 | 펀딩 담당자 대시보드 |
| `web/community/**` | 4 | 1,419 | 커뮤니티 (대부분 makercenter 이관 redirect) |
| `web/ftcommunity/**` | 2 | 1,365 | 구 투자형 커뮤니티 |
| `web/wmypage/**` | 7 | 1,330 | 마이페이지 (구버전) |
| `web/mywadiz/**` | (다수) | (큼) | 신 마이페이지 (mywadiz/payment-info, participation 등) |
| `web/wcampaign/**` | 4+ | — | 검색·지지서명·리워드 청약 |
| `web/wmain/**` | 7 | — | 통합 메인·투자 메인·리워드 메인·라이브·오픈예정 |
| `web/wevent/**` | 3+ | — | 통합 기획전 |
| `web/wpartner/**` | 1+ | — | 파트너 상세 |
| `web/wpremium/**` | 2+ | — | 프리미엄 멤버십 |
| `web/wpage/**` | (다수) | — | 어워즈, 트렌드 페이지 |
| `web/wlive/**` | 1+ | — | 와디즈 라이브 |
| `web/wsub/**` | 1+ | — | EasyCard, 메이커 가이드 |
| `web/wiplicense/**` | 1+ | — | IP 라이선스 (빙그레/디즈니/넥슨/팬즈메이커) |
| `web/wterms/**` | 1+ | — | 약관 |
| `web/oauth/**`, `web/login/**` | 5+ | — | 소셜 로그인 (페이스북/카카오/네이버/애플/구글/라인) |
| `web/marketing/**` | 1+ | — | 마케팅 수신거부 |
| `web/newsletter/**` | 1+ | — | 메이커 뉴스레터 |
| `web/embed/**` | 1 | — | 임베드 위젯 |
| `web/global/**` | 2 | — | 글로벌 크라우드펀딩 (WEN) |
| `web/store/**` | (다수) | — | 와디즈 스토어 |
| `web/membership/**` | 1+ | — | 멤버십 |
| `web/social/**`, `web/follow/**`, `web/feedback/**`, `web/personalmessage/**` | 5+ | — | 소셜·팔로우·피드백·개인 메시지 |
| `web/wcoming/**` | 2 | — | 오픈예정 |
| **합계** | **303** | **43,335** | — |

## 2. WAccount — 16 컨트롤러 상세

| 컨트롤러 | 라인 | 메소드 수 | 주요 매핑 |
|---|---:|---:|---|
| `WAccountRegistController` | 665 | 18 | `/web/waccount/wAccountRegistIntro`, `/register/type/v2`, `/wAccountRegistCorp`, `/wAccountRegistFinish`, `/register/personal`(POST), `/ajaxValidBusinessRegNum`, `/ajaxSendSmsTokenByMarketing`, `/ajaxValidTokenByMarketing`, `/ajaxAddPassword`, `/ajaxRequestSendEmailConfirm`, `/ajaxRequestConfirmEmail`, `/ajaxValidPromotioncode` |
| `WAccountCommonController` | 800+ | 23 | `/web/waccount/wAccountLogin`, 로그아웃, 본인인증 SMS 토큰, 아이디/비밀번호 찾기, 휴면해제 등 — 가장 큰 컨트롤러 |
| `WAccountSocialController` | — | 6 | 카카오/구글/페이스북/애플/네이버 OAuth 처리 (callback·연동·해제) |
| `WAccountUpdateController` | — | 10 | 개인정보·비밀번호·이메일·전화 수정, 마케팅 동의 변경 |
| `WAccountAdultController` | — | 4 | 성인인증 (NICE 본인인증) |
| `WAccountMyController` | — | (큼) | `/web/account/my`, 쿠폰 ajax(`ajaxIsValidCoupon`, `ajaxRegisterCoupon`, `ajaxModifyCoupon`) |
| `WAccountEquityController` | — | (큼) | 투자 계정 (modify/personal, modify/corporation, KSFC 예치금) |
| `WAccountJoinEquityController` | — | — | 투자형 가입 (개인투자자/전문투자자/법인) |
| `WAccountPlusController` | — | — | 와디즈 플러스 (구 멤버십) |
| `WAccountDropOutController` | — | — | 회원 탈퇴 |
| `WAccountInfoController` | — | — | 계정 정보 조회 |
| `WAccountFindController` | — | — | 아이디/비밀번호 찾기 |
| `WAccountNotificationSettingController` | — | — | 알림 설정 |
| `WAccountAffiliateController` | — | — | 어필리에이트 코드 |
| `WAccountPasswordController` | — | — | 비밀번호 변경 |
| `WAccountVerificationController` | — | — | 본인인증 진입 |

## 3. WPayment — 2 컨트롤러 (5천 라인급)

### 3.1 `WPaymentController.java` (813줄, 11 methods, `/web/wpayment/*`)
| Method | URL | 비고 |
|---|---|---|
| GET | `/web/wpayment/{campaignId}` | 결제 SPA 진입 (`wpayment/app.jsp`) |
| GET | `/web/wpayment/handbook` | 결제 약관 (`wpayment/handbook.jsp`) |
| GET | `/web/wpayment/error/{type}` | 에러 화면 |
| GET | `/web/wpayment/complete` | 결제 완료 |
| GET | `/web/wpayment/getIsRealTime` | 거래 가능시간 |
| GET | `/web/wpayment/getIsHoliday` | 공휴일 체크 |
| GET | `/web/wpayment/getIsRefundTime` | 환불 시간 |
| GET | `/web/wpayment/ajaxTermsList` | 약관 리스트 |
| GET | `/web/wpayment/ajaxGetGoodsList` | 결제 상품 |
| GET | `/web/wpayment/ajaxGetLimitAmount` | 투자 한도 |
| POST | `/web/wpayment/ajaxSendAuthCodeMail`, `/ajaxConfirmAuthCodeMail` | 본인인증 메일 |
| POST | `/web/wpayment/ajaxSendEquityRiskNotificationMail` | 투자 위험고지 메일 |

### 3.2 `WPaymentEquityController.java` (1,671줄, 14 methods, `/web/wpayment/equity/*`)
- 청약 단계별 페이지 (`equity1`~`equity4`, `equityReserved`, `equityFail`)
- KSFC 예치금 입금/출금 처리
- NICE 본인인증
- 청약확인서 PDF 생성 (pdfbox)
- 위험고지 약관 동의

## 4. WMain — 7 컨트롤러

| 컨트롤러 | URL prefix | View |
|---|---|---|
| `WMainController` | `/web/main`, `/web/wmain/*` | `wmain/main.jsp` |
| `WInvestMainController` | `/web/winvest/main`, `/web/wmain/main` | `wmain/wmain.jsp` |
| `WRewardMainController` | `/web/wreward/main`, `/web/wreward/collection/*` | `wmain/wreward/*.jsp` |
| `WStartupMainController` | `/web/wstartup/main` | `wmain/startupMain.jsp` |
| `WLiveMainController` | `/web/wlive/*` | `wlive/main.jsp` |
| `PreOrderUiMainController` | `/web/wcomingsoon/*`, `/web/wreward/comingsoon/*` | `wcoming/*.jsp` |
| `WMainController#ajaxXXX` | `/web/main/recommendation/social`, `/web/main/v2/recommendation/social`, `/web/main/maker/is-maker`, `/web/main/maker/my-campaign`, `/web/main/maker/subscribe`(POST), `/web/main/track/section`(POST) | JSON |

## 5. Campaign 상세 — `WEBCampaignController.java`

```java
@Controller
public class WEBCampaignController {
  @RequestMapping("/web/campaign/detail/{campaignId}")               // line 67
  // → wlayout/wRewardDetailSPA
  @RequestMapping("/web/campaign/detail/reward-info/{id}")
  @RequestMapping("/web/campaign/detail/fundingInfo/{id}")           // line 116
  @RequestMapping("/web/campaign/detail/qa/{id}")                    // line 140
  // → campaign/detailQASPA
  @RequestMapping("/web/campaign/detailPost/{id}")                   // line 166
  @RequestMapping("/web/campaign/detailBacker/{id}")                 // line 193
  @RequestMapping("/web/campaign/ajaxUploadRewardCampaignEditorImage")  // line 217 POST multipart
  @RequestMapping("/web/campaign/ajaxFacebookSignature")             // line 227 POST
  @RequestMapping("/web/campaign/{campaignId}/participants")         // line 237
  @RequestMapping("/web/campaign/{campaignId}/participants/my")      // line 244
  @RequestMapping("/web/campaign/ajaxAskForEncore")                  // line 253 POST
  @RequestMapping("/web/campaign/ajaxCancelEncore")                  // line 262 POST
}
```

## 6. WCampaign — 검색·지지서명

| 컨트롤러 | 메소드·URL |
|---|---|
| `WSearchCampaignController.java:42` | `/web/wcampaign/ajaxSearch/category/invest/keyword/{kw}/order/{order}`, `/category/reward/keyword/{kw}/order/{order}`, `/getExistRewardCampaignByUserId` |
| `WWEBCampaignSignatureController.java:15` | `/web/wcampaign/campaignSignature/ajaxSignatureStatus`, `/ajaxMySupportSignatureList`, `/ajaxSupportSignatureList` |
| `WWEBRewardSignatureController.java:24` | `/web/wcampaign/rewardSignature/ajaxRegisterRewardSignature` |
| `WWEBInvestSignatureController.java:24` | `/web/wcampaign/investSignature/ajaxRegisterInvestSignature` |

## 7. Reward 도메인 (69 컨트롤러, 5,315 라인)

주요 서브패키지:
- `web/reward/funding/` — `RewardFundingController` (서포터 펀딩 처리)
- `web/reward/screening/` — `ScreeningController` (사전심사)
- `web/reward/settlement/` — 정산
- `web/reward/coupon/` — 쿠폰 적용/검증
- `web/reward/comment/` + `comment-image/` — 댓글
- `web/reward/story/` — 새소식/스토리
- `web/reward/rewarditem/` — 리워드 옵션
- `web/reward/refund/` — 환불
- `web/reward/shipment/` — 배송
- `web/reward/comingsoon/` — 오픈예정
- `web/reward/openreservation/` — 오픈 예약
- `web/reward/category/` — 카테고리
- `web/reward/makercommunication/` — 메이커-서포터 1:1
- `web/reward/api/v3/` — 신 v3 API (자체 MyBatis 핸들러 — `/web/reward/api/*` 가 자체 처리)

## 8. Equity 도메인 (32 컨트롤러)

- `web/equity/campaign/` — 투자 캠페인 상세
- `web/equity/payment/` — 결제(`WPaymentEquityController`)
- `web/equity/dashboard/` — 투자자 대시보드
- `web/equity/account/` — 투자 계정 관리
- `web/equity/ksd/` — 한국예탁결제원 연동
- `web/equity/news/` — 투자 뉴스
- `web/equity/file/` — 증권신고서 업로드/다운로드 (FinanceDownloadView)
- `web/equity/premium/` — 프리미엄 멤버십

## 9. Jersey JAX-RS API (`/api/*`)

`web.xml` Jersey SpringServlet 패키지 스캔:
```
com.wadiz.api.account, .app, .campaign, .error, .ftaccount, .ftcampaign,
.fw, .login, .notification, .waccount, .wcampaign, .wcode, .wmain,
.wmypage, .wpoint, .store, .startupApp, .membership, .social
```
14개 도메인 + 38 Delegate 클래스. V4 → V3 → V2/V1 버전 누적.

대표 엔드포인트(추정):
- `/api/campaign/*`
- `/api/login/*`
- `/api/wmain/*`
- `/api/wmypage/*`
- `/api/wpoint/*`
- `/api/store/*`
- `/api/membership/*`
- `/api/social/*`
- `/api/waccount/*`
- `/api/wcampaign/*`
- `/api/notification/*`
- `/api/app/*` (모바일 앱 전용)

대부분 모바일/앱 클라이언트용. JSON 응답.

## 10. ProxyServlet — 마이크로서비스 라우팅

### 10.1 `ApiProxyServlet` — `/web/apip/*`
- 백엔드 마이크로서비스로 요청 전달 (funding-api, store-api, reward-api 등)
- bearer token 필터 통과 후 호출 가능 (`/web/apip/funding/**`, `/web/apip/store/**`)
- 화면에서 직접 노출되는 외부 API 경로 (예: `/web/apip/funding/aireview/...`)

### 10.2 `MakerApiProxyServlet` — `/web/maker-proxy/*`
- 메이커센터 SPA(스튜디오) 가 maker-api 호출 시 사용
- CORS·인증 우회 목적

## 11. Spring 3.2 패턴 특이사항

- `@GetMapping`/`@PostMapping` **거의 사용 안함** — 모두 `@RequestMapping(value=..., method=...)` 패턴
- `@ResponseBody` + `produces = "application/json;charset=UTF-8"` 또는 `text/plain;charset=UTF-8` 로 JSON 응답
- `@RestController` 사용 안함 (Spring 4.x+) — `@Controller` + 메소드별 `@ResponseBody`
- `MappingJackson2JsonView` 가 ContentNegotiating 의 default view (Accept 헤더 application/json 시 자동 JSON)

## 12. 인증/세션

- `SessionUtil.isAdminUser()`, `SessionUtil.isLoggedIn()` — 세션 기반 권한 체크
- `oauth2LoginFilter` — 소셜 로그인 callback 처리 (`/web/oauth/callback/{provider}`)
- `oauth2RedirectFilter` — 로그인 진입 redirect
- `bearerTokenAuthenticationFilter` — `/web/v1/maker/*`, `/web/v2/membership`, `/web/apip/funding/**`, `/web/apip/store/**` 인증
- `autoLoginFilter` — 쿠키 기반 자동 로그인
- 캠페인 비공개 상태: `CampaignAccessPermitValidator` → `serverError.jsp`

## 13. 4-mode Request Handling 정리

이전 분석에서 확인된 4가지 요청 처리 모드:

| 모드 | 라우팅 | 처리 주체 | 예시 URL |
|---|---|---|---|
| **ApiProxyServlet** | `/web/apip/*` | `ApiProxyServlet` (transparent proxy) | `/web/apip/funding/aireview/...` |
| **자체 v3 API** | `/web/reward/api/*` | reward 도메인 자체 컨트롤러 + MyBatis | `/web/reward/api/v3/funding/*` |
| **JSP + AJAX** | `/web/wpurchase/*`, `/web/wpayment/*` | 컨트롤러가 JSP 렌더 + 서브 ajax 엔드포인트 | `/web/wpayment/{id}`, `/ajaxTermsList` |
| **RestTemplate** | `/web/v3/*` | `com.wadiz.web` → wave.user 9990 게이트웨이 | `/web/v3/supporter-signatures/*` (지지서명 V3) |

자세한 내용: `../_flows/funding-detail-native.md`, `../_flows/supporter-signature.md`

## 14. 외부 참조

- 화면별 상세: `api-details/screen-*.md`
- JSP 카탈로그: `api-details/jsp-catalog.md`
- urlrewrite + Filter 체인: `api-details/urlrewrite-and-layouts.md`
- MyBatis: `api-details/mybatis-mappers.md`
