# 화면 상세 — 마이페이지 + 통합 메인

> 두 화면군을 1개 파일에 묶음. 둘 다 React 부분 이관 + 신/구 URL 누적.

## 1. 마이페이지 (`/web/mywadiz/*`, `/web/wmypage/*`)

### 1.1 신/구 URL 통합 (urlrewrite)
구 URL 다수가 신 mywadiz 로 강제 redirect:

| FROM | TO | 비고 |
|---|---|---|
| `/web/myreward` | `/web/mywadiz/payment-info` | 리워드 결제정보 |
| `/web/wmypage/myfunding/info`, `/web/mywadiz/myfunding/info` | `/web/mywadiz/payment-info` | URL 정규화 |
| `/web/wmypage/myfunding/fundinglist`, `/web/mywadiz/myfunding/fundinglist` | `/web/mywadiz/participation` | 참여현황 |
| `/web/wmypage/myfunding/rewardfundinglist` | `/web/mywadiz/participation` | 리워드 참여 |
| `/myreward/*` | `/web/wmypage/myfunding/purchase/$1` | 상세 리워드 |

### 1.2 컨트롤러
| 패키지 | 컨트롤러 수 | 라인 |
|---|---:|---:|
| `web/mywadiz/**` | (다수) | (큼) |
| `web/wmypage/**` | 7 | 1,330 |

주요:
- `WWEBRewardDashboardController` — 대시보드
- `WMypageController` — 메인 진입
- `WMypageInvestController` — 투자 마이
- `WMypageRewardController` — 리워드 마이

### 1.3 의존 서비스 / Mapper
| Service | Mapper |
|---|---|
| `WWEBRewardDashboardService` | `mywadiz/dashboard/maker-dashboard-mapper.xml` |
| `WEBCampaignService` | `wmypage/winvest-mapper.xml` |
| (riding) | `wmypage/wreward-mapper.xml` |
| (funding) | `reward/funding/funding-mapper.xml` |

### 1.4 JSP
- `mywadiz/*.jsp` (3 파일)
- `wmypage/*.jsp` (13 파일) — 부모 `wmypage` 레이아웃 (좌측 메뉴 placeholder)

### 1.5 화면 구조
```
[/web/mywadiz/payment-info — 결제정보]
  ├─ 진행중인 펀딩
  ├─ 종료된 펀딩
  └─ 환불 내역

[/web/mywadiz/participation — 참여현황]
  ├─ 리워드 펀딩 참여
  ├─ 투자 펀딩 참여
  └─ 메이커 활동

[/web/wmypage/mybenefit/pointlist — 포인트]
  └─ 포인트 적립/사용 내역

[/web/wmypage/mybenefit/coupon/my — 쿠폰]
  └─ 사용가능 쿠폰 / 만료 쿠폰
```

## 2. 통합 메인 (`/web/main`, `/web/wmain`)

### 2.1 컨트롤러 매트릭스
| 컨트롤러 | URL | View |
|---|---|---|
| `WMainController:86` | `/web/main`, `/web/main/earlybird`, `/web/main/planned`, `/web/main/my`, `/web/main/more`, `/web/main/empty` | `wmain/main` |
| `WMainController:93` | `/web/about` | `wmain/about` |
| `WMainController:103` | `/web/wmain`, `/web/wmain/main` | redirect → `/web/main` |
| `WInvestMainController` | `/web/winvest/main`, `/web/wmain/main` | `wmain/wmain` |
| `WRewardMainController` | `/web/wreward/main`, `/web/wreward/collection/*` | `wmain/wreward/*.jsp` |
| `WStartupMainController` | `/web/wstartup/main` | `wmain/startupMain` |
| `WLiveMainController` | `/web/wlive/*` | `wlive/main` |
| `PreOrderUiMainController` | `/web/wcomingsoon/*`, `/web/wreward/comingsoon/*` | `wcoming/*` |

### 2.2 AJAX 엔드포인트 (WMainController)
| URL | Method | 라인 | 용도 |
|---|---|---:|---|
| `/web/wmain/ajaxGetBannerCommonList` | GET | 145 | 메인 배너 |
| `/web/main/recommendation/social` | GET | 154 | 추천 소셜 피드 |
| `/web/main/v2/recommendation/social` | GET | 167 | v2 |
| `/web/main/maker/is-maker` | GET | 179 | 메이커 여부 |
| `/web/main/maker/my-campaign` | GET | 188 | 내 캠페인 |
| `/web/main/maker/subscribe` | POST | 198 | 뉴스레터 구독 |
| `/web/main/track/section` | POST | 215 | GA 섹션 트래킹 |

### 2.3 의존 서비스
- `WMainService`, `WWEBMainService` — 메인 데이터 집계
- `MainApiService` — main-client (`com.wadiz.api.main main-client/main-model 1.0.6-SNAPSHOT`)로 main-api 호출
- `WInvestSearchService`, `WRewardSearchService` — 검색
- `StatisticService` — 통계
- `NewsletterService` — 메이커 뉴스레터

### 2.4 Mapper
| XML | `<if>` |
|---|---:|
| `wmain/wiosmain-mapper.xml` | (메인 핵심) |
| `wcampaign/winvestsearch-mapper.xml` | 43 |
| `wcampaign/wrewardsearch-mapper.xml` | 11 |
| `wcampaign/WInvestCampaignBaseInfo-mapper.xml` | 107 (최대 동적쿼리) |

### 2.5 JSP
- `wmain/main.jsp` — 통합 리워드 메인
- `wmain/wmain.jsp` — 투자 메인
- `wmain/startupMain.jsp` — 스타트업
- `wmain/makerCode.jsp` — 메이커 코드
- `wmain/about.jsp` — 와디즈 소개

### 2.6 SPA 쉘 패턴
대부분 `mainCommon.jsp` 부모 사용. 본문은 React 번들 (`__staticPath_main_main_js`) 이 그리고, JSP는:
- `mainHead.jsp` (head 메타)
- 배너·트래킹·SEO 메타만 서버 렌더
- 실제 메인 컨텐츠는 클라이언트 React

### 2.7 외부 호출
- `main-client` HTTP → main-api (캠페인 추천·랭킹·인기)
- Braze / Google Analytics — `tracking-gtm-head.jsp`, `tracking-braze-head.jsp` include
- Spring Mobile Device — 모바일 분기

## 3. urlrewrite 보조 (메인 진입)
| FROM | TO | 비고 |
|---|---|---|
| `/funding2015`, `/2015funding` | `/web/wmain` | 고정 캠페인 폐기 |
| `/invest`, `/Invest` | `/web/winvest/main` | 투자 메인 |
| `/web/ftmain*`, `/web/m/ftmain*` | `/web/winvest/main` | 모바일 ftmain |
| `/ios/mainBanner1` | `/web/winvest/main` | 앱 deep-link |
| `/life` | `/web/wreward/main` | 라이프 → 리워드 |
| `/web/main/trend` | `/web/main` | 트렌드 폐기 |

## 4. 외부 참조
- 메인 → 캠페인 상세 흐름: `screen-campaign-detail.md`
- 마이페이지 → 결제 흐름: `screen-payment-equity.md`
