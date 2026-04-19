# com.wadiz.api.funding 레포지토리 API 분석 리포트

## 1. 프로젝트 개요

- **프로젝트명**: com.wadiz.api.funding
- **역할**: 와디즈 크라우드펀딩 플랫폼의 **펀딩 도메인 핵심 비즈니스 로직**을 담당하는 백엔드 API 서비스. 레거시 `com.wadiz.web`에서 펀딩 관련 기능을 점진적으로 이관해 오는 것이 목표.
- **아키텍처**: Spring Boot 기반 멀티모듈 + **DDD + Hexagonal/Onion Architecture** + **CQRS**
- **데이터 저장소**: MySQL (JPA / QueryDSL), Redis (주문 세션), 외부 결제·인증 연동(Nice, Stripe, Alipay, K-인증)

### 모듈 구성

```
com.wadiz.api.funding
├── adapter
│   ├── application     (@RestController, 웹 계층)
│   ├── batch           (Spring Batch tasklet)
│   ├── infrastructure  (JPA Entity / Repository / QueryDSL)
│   └── parent          (공통 의존성)
├── bootstrap
│   ├── application     (API bootJar)
│   └── batch           (Batch bootJar)
└── core
    ├── domain          (POJO 기반 비즈니스 로직)
    └── support         (도메인 지원 유틸)
```

- `core:domain`은 프레임워크 의존성이 없는 **순수 자바**로 작성되어 있고, 비즈니스 로직에서 Spring을 쓰지 못하도록 **컴파일 타임에 강제**하는 것이 핵심 설계.
- 도메인 → 인프라 의존은 **DIP(의존성 역전)** 로 단절.
- 도메인 모델의 오염을 막기 위해 **CQRS** 도입(읽기 전용 경로와 쓰기 경로 분리).

---

## 2. 도메인별 API & DB 작업 요약

약 60여 개의 도메인 패키지가 존재하며(`adapter/application/src/main/java/com/wadiz/api/funding/domain/*`), 컨트롤러는 공개용(`{Domain}Controller`) / 내부용(`{Domain}InternalController`) / 관리자용(`{Domain}AdminController`)으로 분리되어 있다.

### 2.1 주문/결제 플로우

#### `order` — 주문 세션 · 주문서
펀딩 결제를 위한 **주문서(OrderSheet)** 와 **주문 세션(OrderSession)** 의 생성·조회·삭제를 담당. 세션 기반 설계로 결제 전까지의 임시 데이터를 다룬다.

| Method | Path | 설명 |
|--------|------|------|
| POST | `/api/orders/session` | 주문 세션 생성 |
| GET | `/api/orders/session/{token}` | 주문 세션 조회 |
| POST | `/api/orders/sheet/{token}` | 주문서 생성 |
| DELETE | `/api/orders/sheet/{token}` | 주문서 삭제 |
| GET | `/api/orders/closed-session/{token}` | 종료된 주문 세션 조회 |

**DB 작업**: `OrderSession`, `OrderSheet` (Redis 기반 임시 저장), 연관 리워드/쿠폰/포인트 정보 조회.

---

#### `orderpayment` — 결제 승인/콜백
외부 PG사(Nice, Stripe, Alipay) 연동과 결제 승인 처리.

| Method | Path | 설명 |
|--------|------|------|
| POST | `/api/order-payment/{payType}/{campaignId}/{token}` | NICE 결제 인증 콜백 |
| GET | `/api/order-payment/{payType}/{token}/pay-via-stripe` | Stripe 결제 |
| POST | `/api/order-payment/alipay/{token}/callback-bypass` | Alipay 결제 콜백 |
| POST | `/api/order-payment/{token}/pay-zero` | 0원 결제 승인 |
| GET | `/api/order-payment/{token}/approve-status` | 결제 승인 상태 조회 |

**DB 작업**: `BackingPayment` INSERT, `PaymentApprovalRequest` 기록, 외부 승인 결과로 상태 업데이트.

---

#### `payment` (Internal) — 결제 정보 조회/관리
내부 시스템에서 호출하는 결제 정보 관리 API.

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/internal/payments` | 결제 목록 조회 |
| POST | `/api/internal/payments/congratulation` | 메이커 축하 메일 발송 |
| POST | `/api/internal/payments/extra-info` | 결제 추가 정보 저장 |
| POST | `/api/internal/payments/card-registration` | 카드 등록 정보 저장 |
| POST | `/api/internal/payments/billkey-verifications` | 빌키 검증 상태 업데이트 |

**DB 작업**: `BackingPayment`, `BackingPaymentExternalInfo`, `BillkeyVerificationStatus`.

---

#### `paymentcancel` — 결제 취소
환불/취소 처리 및 로그 기록.

**DB 작업**: `BackingPayment` 상태 변경, `BackingPaymentCancelLog` INSERT.

---

#### `paymentprogress` — 결제 진행 정보
프로젝트별 결제 진행 연관 정보 조회.

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/payment-progress/campaigns/{campaignId}/relevant-info` | 프로젝트 결제 진행 연관 정보 |

**DB 작업**: `BackingPayment`, `Campaign` 조회 + 집계.

---

### 2.2 펀딩 참여/서포터

#### `supporter` — 펀더(서포터) 마이페이지
펀딩 참여자의 내역, 배송지, 결제 수단 관리.

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/supporters/my/shipping-addresses/latest` | 최근 배송지 목록 |
| GET | `/api/supporters/my/recent-pay-by` | 최근 결제 수단 |
| GET | `/api/supporters/my/fundings` | 내 펀딩 참여 내역 (페이징) |
| GET | `/api/supporters/my/fundings/{backingPaymentId}` | 펀딩 내역 상세 |
| PUT | `/api/supporters/my/fundings/{backingPaymentId}/shipping-address` | 배송지 변경 |
| PUT | `/api/supporters/my/fundings/{backingPaymentId}/pay-by` | 결제 수단 변경 |

**DB 작업**: `BackingPayment`, `Backing`, `BackingRewardSet`, `BackingRewardOption` 조회/수정.

---

#### `funding` — 펀딩 통계
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/fundings/qty` | 펀딩 횟수 조회 |
| GET | `/api/fundings/qty/my` | 로그인 유저 펀딩 횟수 |
| GET | `/api/fundings/{campaignId}/is-asked-encore` | 앵콜 신청 여부 |

**DB 작업**: `BackingPayment`, `CampaignAskForEncore` COUNT.

---

#### `refund` — 펀딩금 반환
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/refund/my/{campaignId}/detail` | 펀딩금 반환 상세 |

**DB 작업**: `BackingPayment`, `RewardRefundPolicy` 조회.

---

### 2.3 프로젝트/캠페인

#### `campaign` — 프로젝트 조회 (공개 API)
프로젝트 카드, 상세, 상태, 태그, 통계 등 조회. 메인 트래픽이 집중되는 API.

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/campaigns/card` | 메인 카드 목록 (페이징) |
| GET | `/api/campaigns/comingsoon/card` | 오픈예정 카드 목록 |
| GET | `/api/campaigns/{campaignId}/statistics-summation` | 통계 요약 |
| POST | `/api/campaigns/card/base-info` | 여러 프로젝트 기본 정보 배치 조회 |
| GET | `/api/campaigns/{campaignId}/detail` | 상세 조회 |
| GET | `/api/campaigns/{campaignId}/summary` | 요약 |
| GET | `/api/campaigns/{campaignId}/tags` | 해시태그 |
| GET | `/api/campaigns/{campaignId}/status` | 상태 |
| GET | `/api/campaigns/{campaignId}/pre-reservation-info` | 사전 예약 정보 |

**DB 작업**: `Campaign`, `CampaignSnapshot`, `Reward` 조회 (QueryDSL 동적 쿼리, 페이징).

---

#### `campaign` (Internal)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/internal/campaigns/{campaignId}/base-info` | 기본 정보 |
| GET | `/api/internal/campaigns/{campaignId}/makers/{userId}` | 프로젝트 메이커 확인 |
| GET | `/api/internal/campaigns/maker-business-info` | 메이커 사업자 정보 |

**DB 작업**: `Campaign` 조회, 권한 확인용 조인.

---

### 2.4 리워드/상품

| 도메인 | 역할 | DB |
|--------|------|----|
| `reward` | 관리자용 리워드 목록 (`/api/admin/rewards/campaigns/{campaignId}`) | `Reward`, `RewardItem`, `RewardLimitedTimeOffer` |
| `rewarditem` | 공개 리워드 조회 (`/api/reward-items/campaigns/{campaignId}`) | `RewardItem`, `Reward` |
| `rewardevent` | 리워드 이벤트 참여 관리 | `RewardEvent`, `RewardEventParticipant`, `RewardEventBenefitMapping` |
| `rewardpolicy` | 리워드 정책 조회 | `RewardRefundPolicy` |
| `refundpolicy` | 환불 정책 조회 | `RewardRefundPolicy` |
| `rewardchangelog` | 리워드 변경 이력 | `RewardChangeLog` |

---

### 2.5 정산 (Settlement)

정산은 메이커용(Studio)과 내부용(Internal)으로 분리됨.

#### `settlement` (Studio)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/studio/campaigns/{campaignId}/settlement` | 정산 진행 상태 |
| GET | `/api/studio/campaigns/{campaignId}/settlement-statement` | 정산 내역서 정보 |
| GET | `/api/studio/campaigns/{campaignId}/settlement-statement/download` | 정산 내역서 PDF |
| GET | `/api/studio/campaigns/{campaignId}/fees` | 수수료 |
| GET | `/api/studio/campaigns/{campaignId}/v2/fees` | 수수료 v2 |
| GET | `/api/studio/campaigns/{campaignId}/settlement-system` | 정산 시스템 |
| GET | `/api/studio/campaigns/{campaignId}/fee-version` | 수수료 버전 |

#### `settlement` (Internal)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/internal/settlement/{campaignId}/maker-info` | 메이커 정산 정보 |
| GET | `/api/internal/settlement/{campaignId}/package-plan` | 요금제 조회 |
| GET | `/api/internal/settlement/fee-proposals` | 수수료 품의 진행상태 |
| GET | `/api/internal/settlement/fees` | 수수료 조회 |
| GET | `/api/internal/settlement/settlement-statement` | 정산 내역서 |
| GET | `/api/internal/settlement/settlement-result-state` | 지급 상태 |
| GET | `/api/internal/settlement/is-split` | 분할정산 여부 |

**DB 작업**: `RewardSettlement`, `RewardSettlementRate`, `SettlementSystem`, `CampaignPackagePlan` — 대부분 READ-heavy 조회 및 Excel/PDF 출력.

---

### 2.6 배송 (Shipping)

#### `shipping` (Studio)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/studio/shipping/campaigns/{campaignId}/countries` | 발송 국가 목록 |
| GET | `/api/studio/shipping/campaigns/{campaignId}/export-declaration/excel` | 수출 신고 Excel 다운로드 |

**DB 작업**: `Shipping`, `ShippingNotification`, `BackingPayment` 조인 집계.

---

### 2.7 커뮤니케이션 (News / Notification)

#### `news` — 프로젝트 새소식
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/campaigns/{campaignId}/news` | 새소식 목록 (페이징) |
| GET | `/api/campaigns/{campaignId}/news/qty` | 새소식 건수 |
| GET | `/api/campaigns/{campaignId}/news/{newsId}` | 새소식 상세 |

**DB 작업**: `CampaignUpdate`, `CampaignUpdateLanguage` 조회.

#### `newsnotification`
새소식 알림 설정/해제.

**DB 작업**: `CampaignUpdateNotificationDeny`, `CampaignUpdateNotificationDenyLog`.

---

### 2.8 메이커 (Maker)

| 도메인 | 역할 | DB |
|--------|------|----|
| `maker` | 프로젝트별 메이커 정보 조회 (`/api/maker/{campaignId}`) | `Campaign`, `UserProfile` |
| `makerinvitation` | 메이커 초대 코드 생성·관리 | `MakerInvitation`, `MakerInvitationCode`, `MakerInvitationBenefit` |
| `manager` | 프로젝트 담당자 관리 | `Manager`, `CampaignManager` |

---

### 2.9 서명 · 찜하기 · 앵콜

| 도메인 | 주요 엔드포인트 | DB |
|--------|----------------|-----|
| `signature` | `GET /api/signatures/campaigns/{campaignId}/qty` (지지서명자 수) | `Signature` |
| `wish` | `POST/DELETE /api/wishes`, `GET /api/wishes/my/qty`, `GET /api/wishes/projects/qty` | `UserWishProject` |
| `encore` | `POST/DELETE /api/projects/{projectNo}/ask-for-encore` | `CampaignAskForEncore` |
| `comingsoonapplicant` | `POST /api/comingsoons/applicants/{userId}` | `ComingSoonApplicant`, `ComingSoon` |

---

### 2.10 대시보드 & 스튜디오

#### `dashboard` (Studio)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/studio/dashboard/projects/{projectNo}` | 프로젝트 현황 |
| GET | `/api/studio/dashboard/projects/{projectNo}/wishes/country-ranking` | 찜 국가 순위 |
| GET | `/api/studio/dashboard/projects/{projectNo}/payments/country-ranking` | 결제 국가 순위 |

**DB 작업**: `BackingPayment`, `Campaign`, `Backing`, `UserWishProject` 집계 쿼리.

#### `studio` — 스튜디오 메뉴
| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/studio/projects/{projectNo}/menus` | 스튜디오 메뉴 구성 |

**DB 작업**: `StudioMenu`, `StudioSection`.

---

### 2.11 스토리 · 번역

| 도메인 | 역할 | DB |
|--------|------|----|
| `story` | `/api/story/{campaignId}/funding`, `/api/story/{campaignId}/comingsoon` | `Campaign`, `StoryContent` |
| `translate` | 스토리/프로젝트 번역 요청·관리 | `StoryCopy`, `StoryTranslation` |

---

### 2.12 인증/결제수단/기타

| 도메인 | 역할 | DB |
|--------|------|----|
| `billkey` | 정기결제 빌키 관리 | `BillkeyVerificationStatus` 등 |
| `simplepay` | 심플페이 관련 | 카드/결제수단 관련 |
| `kcertification` | K-본인인증 | 인증 로그 |
| `personalverification` | 개인 검증 | 인증 정보 |
| `businessverify` | 사업자 인증 | 사업자 정보 |
| `bankaccount` | 계좌 정보 관리 | 계좌 관련 테이블 |
| `contractinfo` | 계약 정보 | 계약 관련 |
| `department` | 부서/담당 | 부서 정보 |
| `announcement` | 공지사항 | `Announcement` |
| `reaction` | 좋아요/반응 | `Reaction`, `ReactionType` |
| `safenumber` | 안심번호 | 안심번호 매핑 |
| `satisfaction` | 만족도 조사 | 설문 응답 |
| `eventday` | 이벤트 데이 | 이벤트 정보 |
| `projectpause` | 프로젝트 일시정지 | 일시정지 이력 |
| `storeevent` | 스토어 이벤트 | 스토어 이벤트 |
| `preorder` | 사전예약 | 사전예약 |
| `aireview` | AI 리뷰 | AI 리뷰 결과 |
| `catalog` | 카탈로그 | 카탈로그 |
| `sample` | 샘플 (템플릿) | 샘플 |

---

## 3. DB 접근 요약 (infrastructure 모듈)

주요 테이블(엔티티)을 도메인 그룹으로 정리하면 다음과 같다.

### 결제 · 펀딩 참여
- `BackingPayment` — 결제 핵심 테이블
- `BackingPaymentCancelLog` — 취소 이력
- `BackingPaymentCoupon` / `BackingPaymentDiscountBenefit` / `BackingPaymentPoint` — 할인/혜택
- `BackingPaymentExternalInfo` — 외부 PG 정보
- `BackingRewardSet` / `BackingRewardOption` / `BackingRewardComposition` — 리워드 구성

### 프로젝트 · 리워드
- `Campaign`, `CampaignSnapshot`, `CampaignAutoOpen`, `CampaignRewardDelay`
- `ComingSoon`, `ComingSoonApplicant`
- `Reward`, `RewardItem`, `RewardLimitedTimeOffer`, `RewardPayment`
- `RewardEvent`, `RewardEventParticipant`, `RewardEventBenefitMapping`

### 정산 · 배송
- `RewardSettlement`, `RewardSettlementRate`, `SettlementSystem`, `CampaignPackagePlan`
- `Shipping`, `ShippingNotification`

### 커뮤니티 · 상호작용
- `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateNotification`, `CampaignUpdateNotificationDeny`
- `Signature`, `UserWishProject`, `CampaignAskForEncore`
- `Reaction`, `Announcement`

### 인증 · 계정
- `BillkeyVerificationStatus`
- `MakerInvitation`, `MakerInvitationCode`, `MakerInvitationBenefit`

### 접근 패턴
- **Spring Data JPA Repository**: 단순 CRUD
- **QueryDSL**: 동적/복합 조건 조회(카드 목록, 대시보드 집계 등)
- **Redis**: `OrderSession`, `OrderSheet` 등 단기 캐시/세션 저장
- **외부 API 연동**: Nice · Stripe · Alipay 결제, K-인증

---

## 4. 요청 처리 패턴

### 네이밍 컨벤션
- `{Domain}Controller` — 공개 API
- `{Domain}InternalController` — 내부 서비스 호출용
- `{Domain}AdminController` — 관리자 전용
- `{Domain}Proxy` — 컨트롤러 ↔ 도메인 서비스 연결 계층
- `payload/` 하위에 Request/Response DTO 및 Converter 배치

### 보안
- `@PreAuthorize("isMaker(#projectNo)")`, `isAdmin()` 등 메서드 수준 권한 제어
- Public / Internal / Admin 경로 명시적 분리

### 페이징
- `Pages`, `PageResult`, `Sorts` 공통 추상화 사용

---

## 5. 전체 펀딩 생명주기 (예시 플로우)

1. **주문 세션 생성**: `POST /api/orders/session` → Redis에 `OrderSession`
2. **주문서 생성**: `POST /api/orders/sheet/{token}` → `OrderSheet` 생성 (리워드·배송·쿠폰·포인트 포함)
3. **결제 요청**: `/api/order-payment/{payType}/...` → 외부 PG 콜백 처리
4. **펀딩 확정**: `BackingPayment` INSERT + `BackingRewardSet/Option` 구성
5. **커뮤니케이션**: `CampaignUpdate`(새소식), `Signature`(지지서명), `UserWishProject`(찜)
6. **배송 준비**: `Shipping`/`ShippingNotification`, 국가별 수출신고 Excel
7. **정산**: `RewardSettlement`, `RewardSettlementRate`로 수수료·지급액 산정
8. **사후 처리**: 환불(`BackingPaymentCancelLog`), 앵콜(`CampaignAskForEncore`)

---

## 6. 요약

- 본 API 서비스는 와디즈 펀딩 도메인의 **주문 → 결제 → 펀딩 확정 → 배송 → 정산 → 사후 커뮤니케이션** 전체 라이프사이클을 책임진다.
- 약 **60여 개의 도메인 패키지**가 있으며, 대부분 공개/내부/관리자 컨트롤러로 분리되어 관심사별로 잘 격리되어 있다.
- 데이터 접근은 **JPA + QueryDSL** 중심이며, 결제 세션 등 임시 상태는 Redis에 둔다.
- 설계 목표는 **도메인 순수성 유지(프레임워크 비의존)** 와 **CQRS 기반 읽기/쓰기 분리**이다.

> 본 문서는 `adapter/application` 하위 컨트롤러와 `adapter/infrastructure` 리포지토리 탐색 결과를 기반으로 작성되었다. 신규 도메인이 추가되거나 엔드포인트가 변경될 수 있으므로 최신 내용은 소스 코드를 기준으로 확인해야 한다.

---

## 7. 관련 문서

- [`api-endpoints.md`](./api-endpoints.md) — 전체 REST 엔드포인트 전수 목록 (약 200개, 경로 그룹별 정리)
- [`api-details/`](./api-details/) — 도메인별 상세 스펙 (Request/Response 필드·타입·옵션, DB 쿼리)
  - [`api-details/order.md`](./api-details/order.md) — 주문 세션/주문서 (5개 엔드포인트, Redis)
  - [`api-details/campaign-public.md`](./api-details/campaign-public.md) — 캠페인 공개 조회 (9개 엔드포인트, MySQL/MyBatis)
  - [`api-details/campaign-admin.md`](./api-details/campaign-admin.md) — 캠페인 Internal/Studio/Submit/Hidden/Category (12개 엔드포인트)
  - [`api-details/campaign-global-native.md`](./api-details/campaign-global-native.md) — 캠페인 Global/Native + Internal AI cache (20개 엔드포인트, 다국어 패턴)
  - [`api-details/supporter-funding-refund.md`](./api-details/supporter-funding-refund.md) — 서포터 마이페이지 + 펀딩 통계 + 환불 조회 (16개 엔드포인트)
  - [`api-details/payment-flow.md`](./api-details/payment-flow.md) — OrderPayment/Payment/PaymentCancel/PaymentProgress (17개 엔드포인트, 결제 쓰기·집계)
  - [`api-details/settlement.md`](./api-details/settlement.md) — 정산/수수료/요금제/미수금 (28개 엔드포인트, ERP 외부 연동)
  - [`api-details/dashboard.md`](./api-details/dashboard.md) — 스튜디오/메이커 대시보드 (40개 엔드포인트, DataPlus 외부 연동)
  - [`api-details/reward.md`](./api-details/reward.md) — 리워드/이벤트/상품고시/환불정책/변경이력 (37개 엔드포인트, MongoDB 혼용)
  - [`api-details/news-announcement.md`](./api-details/news-announcement.md) — 새소식/알림/공지 (21개 엔드포인트, MongoDB 로그)
  - [`api-details/wish-signature-encore-comingsoon.md`](./api-details/wish-signature-encore-comingsoon.md) — 찜/서명/앵콜/오픈예정 (15개 엔드포인트)
  - [`api-details/maker-admin.md`](./api-details/maker-admin.md) — 메이커/담당자/사원/사업자/계좌/계약/초대 (21개 엔드포인트)
  - [`api-details/story-translate-aireview.md`](./api-details/story-translate-aireview.md) — 스토리/번역/AI심사 (16개 엔드포인트, 비동기 콜백)
  - [`api-details/iplicense-catalog-additional.md`](./api-details/iplicense-catalog-additional.md) — IP라이선스/Meta카탈로그/부가서비스 (18개 엔드포인트)
  - [`api-details/misc.md`](./api-details/misc.md) — 인증/UI/리액션/안심번호/참여/멤버십/공지배너/프리오더/영업일/만족도/일시정지/스토어이벤트/첨부/슬랙/유저/샘플 (27개 엔드포인트)
  - [`api-details/batch.md`](./api-details/batch.md) — Spring Batch 모듈 (24개 Job, 20개 도메인 — 알림·번역·AI심의·메이커혜택·정산·운영)

