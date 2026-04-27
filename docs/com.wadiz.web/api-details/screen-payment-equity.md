# 화면 상세 — 결제·청약 (`/web/wpayment/*`, `/web/wpayment/equity/*`)

> com.wadiz.web 의 최대 컨트롤러 2개 (총 ~2,500 라인). 보상형(리워드) + 투자형(증권형) 결제 흐름.

## 1. 보상형 결제 (`/web/wpayment/{campaignId}`)

### 컨트롤러
`web/wpayment/controller/WPaymentController.java` (813줄, 11 methods, class mapping `/web/wpayment/*`)

| URL | Method | 용도 |
|---|---|---|
| `/web/wpayment/{campaignId}` | GET/POST | 결제 SPA 진입 → `wpayment/app.jsp` |
| `/web/wpayment/handbook` | GET (line 145) | 결제 약관 → `wpayment/handbook.jsp` |
| `/web/wpayment/error/{type}` | GET (line 386) | 에러 화면 |
| `/web/wpayment/complete` | GET | 완료 화면 |
| `/web/wpayment/getIsRealTime` | GET (line 159) | 거래 가능 시각 |
| `/web/wpayment/getIsHoliday` | GET (line 171) | 공휴일 |
| `/web/wpayment/getIsRefundTime` | GET (line 184) | 환불 가능 시각 |
| `/web/wpayment/ajaxTermsList` | GET (line 253) | 약관 목록 |
| `/web/wpayment/ajaxGetGoodsList` | GET (line 274) | 결제 상품 |
| `/web/wpayment/ajaxGetLimitAmount` | GET (line 294) | 투자 한도 (리워드 결제에선 거의 안씀) |
| `/web/wpayment/ajaxSendAuthCodeMail` | POST (line 551) | 본인인증 메일 발송 |
| `/web/wpayment/ajaxConfirmAuthCodeMail` | POST (line 638) | 본인인증 메일 확인 |
| `/web/wpayment/ajaxSendEquityRiskNotificationMail` | POST (line 690) | 투자 위험고지 메일 |

### 결제 플로우
```
[메인 진입 GET /web/wpayment/{id}]
  → [약관 GET /web/wpayment/handbook]
  → [결제 SPA wpayment/app.jsp]
       │
       ├─ ajaxTermsList, ajaxGetGoodsList, ajaxSendAuthCodeMail/ajaxConfirmAuthCodeMail
       ├─ getIsRealTime, getIsHoliday (거래 시간 체크)
       ├─ NicePay/Inicis 결제 모듈 호출 (가상계좌·신용카드)
       └─ 완료 → /web/wpayment/complete
              → 에러 → /web/wpayment/error/{type}
```

### 의존 서비스
- `WPaymentService`
- `PaymentService`
- `NicePayService` (또는 `InicisService`)
- `PointService` — 포인트 차감
- `CouponService` — 쿠폰 검증/적용
- `AccountService` — 본인인증 메일
- `CampaignService` — 캠페인 정보

### Mapper
- `sqls/reward/payment/payment-mapper.xml`
- `sqls/reward/payment/payment-refund-mapper.xml`

### 외부 결제 PG
- **NicePay**: `kr.co.nicepay nicepay-lite 0.9.24` (가상계좌·실명인증)
- **Inicis**: `inicis inipay 5.0`, `INIpay_Sample 1.2`, `ExecureCrypto 1.0`
- **NICE 본인인증**: `NiceID.Check 1.0`

### 뷰
- `wpayment/app.jsp` — 결제 SPA 쉘
- `wpayment/handbook.jsp` — 약관
- `wpayment/complete.jsp` — 완료
- `wpayment/error.jsp` — 에러

## 2. 투자형(증권형) 청약 (`/web/wpayment/equity/*` + `/web/waccount/equity/*`)

### 컨트롤러
- `web/wpayment/controller/WPaymentEquityController.java` (1,671줄, 14 methods)
- `web/waccount/controller/WAccountEquityController.java` — 투자 계정 관리
- `web/waccount/controller/WAccountJoinEquityController.java` — 투자형 가입 (개인/법인/전문투자자)

### 청약 단계
| 단계 JSP | 역할 |
|---|---|
| `wpayment/equity1.jsp` | 청약 안내·주의사항 |
| `wpayment/equity2.jsp` | 본인인증 + 투자 한도 확인 |
| `wpayment/equity3.jsp` | 투자 의향서·위험고지 동의 |
| `wpayment/equity3-1.jsp` | (분기) 추가 동의 |
| `wpayment/equity4.jsp` | 청약 금액 입력 + KSFC 예치금 입금 |
| `wpayment/equityReserved.jsp` | 청약 완료(예약 상태) |
| `wpayment/equityFail.jsp` | 청약 실패 |

### 의존
- **한국증권금융 KSFC**: `com.wadiz.api ksd-client` 또는 `KSFCclient 1.0` — 예치금 계좌 직접 통신
- **한국예탁결제원 KSD**: `ksd-client` — 증권 발행/관리 연동
- **NICE 본인인증**: `NiceID.Check 1.0`
- **PDFBox**: `org.apache.pdfbox 2.0.24` — 청약확인서 PDF 생성
- **Inicis/NicePay**: 가상계좌
- **SmartSheet**: `com.smartsheet smartsheet-sdk-java 2.2.5` — 운영팀 공유 (adm 와 공유)

### Mapper
- `sqls/equity/**` 전체:
  - `ftcampaign-mapper.xml` (26 resultMap, 최대)
  - `equityCamapign-mapper.xml`
  - `ftpayment-mapper.xml`
  - `wpayment-mapper.xml`
  - `premiumMembership.xml`
  - `wpremiummain-mapper.xml`
  - `premiumContentsBoard.xml`
  - `equityNews-mapper.xml`
  - `equityInvestor-mapper.xml`
  - `equityMember-mapper.xml`
  - `equityDashboard-mapper.xml`

### 관련 JSP
- `web/WEB-INF/jsp/wpayment/equity*.jsp` — 7개 단계 페이지
- `web/WEB-INF/jsp/equity/*.jsp` — 39개 (campaign/8, dashboard/9, payment/10, account/7, guide/1, root/4)
- `web/WEB-INF/jsp/wsub/wEasyCard.jsp` — EasyCard 결제 수단

### 인증/권한
- 적격투자자 (전문투자자/일반투자자) 분기
- 투자 한도: 일반 1,000만원/년, 전문 무제한 등 유형별 제한
- 본인인증 + 위험고지 약관 동의 강제

## 3. 4-mode 결제 처리 변형

| 모드 | 경로 | 처리 |
|---|---|---|
| **JSP+AJAX (이 문서)** | `/web/wpayment/*` | 컨트롤러 + JSP 렌더 + ajax 엔드포인트 |
| **JSP+AJAX 자체변형** | `/web/wpurchase/*` | `wpurchase/` (4 JSP) — 별도 결제 변형 |
| **자체 v3 API** | `/web/reward/api/v3/*` | reward 도메인 v3 (자체 MyBatis 핸들러) |
| **API Proxy** | `/web/apip/funding/*` | funding-api 마이크로서비스 프록시 |

## 4. 외부 참조
- 화면별 funding-api 호출 흐름: `../../_flows/funding-payment.md`
- 사용 레이아웃: `wnofooter` (헤더만, 결제는 풀스크린)
