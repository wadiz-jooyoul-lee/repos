# com.wadiz.api.funding 레포지토리 API 분석 리포트

> 📅 **2026-07-21 master pull 보강** (약 29 커밋)
>
> 급상승 프로젝트 컬렉션 자동화(DP ES 연동), 주민등록번호 파기 배치, 약정 도메인 분리가 핵심입니다.
>
> ### RWD-5785 — 급상승 프로젝트 컬렉션(crowdedproject) 자동화 + DP Elasticsearch 연동
> - 신규 자동화 컬렉션 전략 `CrowdedProjectAutomatedCollection`(+`CrowdedProjectScore`/`CrowdedProjectSource`). 신규방문자·공유유입 지표를 DP(Display Platform) ES에서 조회(`ProjectAcquisitionMetricsGateway` + `dpsearch/*` 쿼리 JSON)해 점수화. **low-level RestClient 채택**(ADR `docs/adr/RWD-5785-dp-es-low-level-client.md`, OS 전환 대비). 급상승 도메인 식별자를 `campaignId → projectNo`로 통일, rc3 환경 폐기 정리. rc 배포 health check 실패 해소를 위해 ES RestClient 자동설정 제외.
>
> ### RWD-5725 — 메이커 주민등록번호 파기 배치 + compliance 감사로그
> - 보관기간 경과 파기 배치 `rrnDestructionJob`(`RrnDestructionGatewayImpl`) 추가. 파기+감사로그를 wadizdb 트랜잭션으로 사실상 원자화(`PersonalDataDestructionLog`). compliance 감사 로그용 Mongo 스택을 batch 전용 조건부 빈으로 분리하고 `@Qualifier` 고정(@Primary 오배선으로 감사 로그가 기본 DB로 저장되던 버그 수정), rc/rc2/live Mongo URI에 `authSource=admin` 추가.
>
> ### RWD-5808 — 약정 등록을 agreement 도메인으로 분리
> - 약정 등록을 `CampaignSubmit` 도메인에서 별도 `agreement` 도메인(`CampaignAgreementUseCase`/`CampaignAgreementCommandGateway`)으로 분리. 약정 최초/N차 판정 시 현재 캠페인 제외하도록 수정(`CampaignAgreementMapper`).
>
> ### RWD-5807 / RWD-5795 / RWD-5796 — 기타
> - RWD-5807: 서포터클럽 배송비 할인 대상 상태 추가(`CampaignScreeningMapper`).
> - RWD-5795: 후원 프로젝트인 경우 결제동선 내 천만원 결제 제한 해제(`CalculateBillingUsecase`/`CreateOrderSheetUsecase`).
> - RWD-5796: AI 심의 알림 `languageCode` 전달 및 `alarmData` null 방어.
>
> ---
>
> 📅 **2026-07-10 master pull 보강** (2026-06-18 이후 master, net-new 9테마)
>
> 컬렉션 자동화 3종 추가, 글로벌 서포터 목록 서포터클럽 뱃지, 정산내역서 다운로드 보안 강화, ISMS 5년 조회 제한이 핵심입니다.
>
> ### RWD-5763 / RWD-5790 / RWD-5744 — 자동화 컬렉션 키워드 3종 추가·튜닝
> - `CollectionKeyword` enum에 신규 키워드 3개 추가 (**`CollectionKeyword.java:20-22`**): `SUPPORT_FANDOM`(`supportfandom`, 후원·팬덤 = SOCIAL 요금제), `LOCAL_FUNDING`(`localfunding`, 로컬 = LOCAL 요금제+사업자), `BOOKMARKS`(`bookmarks`, 글로벌 전자책·클래스 = 비KR 배송 + `CategoryType.CLASS`).
> - 각 키워드마다 `@Helper` 전략 클래스(`SupportFandomAutomatedCollection`·`LocalFundingAutomatedCollection`·`BookmarksAutomatedCollection`)를 추가하면 `collectionAutomationJob`에 자동 편입되는 구조. `AutomatedCollectionMapper.xml`에 후보 조회 SQL 추가.
> - RWD-5744: 왓츠넥스트코리아 컬렉션에서 전자책·클래스 카테고리를 제외하고, `AutomatedCollectionMapper.xml` 하드코딩 카테고리 코드를 `CategoryType.PUBLISH/CLASS` 상수 참조 + foreach 파라미터로 정리.
>
> ### RWD-5781 — 글로벌 서포터 목록 응답에 서포터클럽 여부(hasMembership) 추가
> - `GlobalProjectSupporterResponse`에 `Boolean hasMembership` 필드 추가 (**`GlobalProjectSupporterResponse.java:45`**). 신규 펀딩 상세 서포터 탭의 클럽 뱃지 노출용(QA-22487). 멤버십 일괄 조회(`MembershipQueryGateway`)로 세팅하고, 익명/탈퇴 회원은 기존 `user` null 가드로 미노출.
> - 서포터 목록 MyBatis 생성자 매핑 오류(RWD-5781 후속)를 Enhanced 패턴 적용으로 해소.
>
> ### RWD-5761 — 메이커 회원 ID 조회 내부 bulk API 2건
> - **`CampaignInternalController.java:61`** `GET /api/internal/campaigns/maker-user-ids` — 캠페인 ID 목록으로 메이커 회원 ID 일괄 조회(소스: `Campaign.UserId`).
> - **`NewsInternalController.java:25`** `GET /api/internal/news/maker-user-ids` — 새소식(CampaignUpdate) ID 목록으로 `campaignId`·메이커 회원 ID 조회(CampaignUpdate→Campaign 조인). 둘 다 상태 필터 없는 순수 lookup, 미존재 ID는 결과에서 생략.
>
> ### SCOUT-82 / SCOUT-83 — 정산내역서 다운로드 보안·검증 강화
> - Path Traversal 차단(`../`, `./`, `/`, `\` 포함 시 400)과 `campaignId` 소유권 검증(serviceCode + campaignId prefix 매칭)을 `StatementUsecase` 서비스 레이어로 이동. `StatementDownloadQuery`에 `campaignId` 필드 추가 (SCOUT-82).
> - 스토어 캠페인은 `Campaign` 테이블에 없어 `getBizModel()`이 null → `ProjectType.fromName()`에서 예외가 나던 문제를 사업자번호 기반 검증으로 해결. `StatementDownloadQuery`·`SettlementInternalController`에 optional `businessRegistrationNumber` 파라미터 추가, 제공 시 사업자번호로 prefix 검증(미제공 시 기존 bizModel 로직) (SCOUT-83).
> - 내부 API 사용처가 Store뿐이므로 `SettlementInternalController` 파라미터명 `campaignId → projectNo`로 변경.
>
> ### RWD-5738 — 펀딩 내역 조회 5년 경과 데이터 제외 (ISMS)
> - `FundingMapper.xml`의 공통 WHERE 조각 `fundingListWhereClause`에 `AND A.RegDate > DATE_SUB(NOW(), INTERVAL 5 YEAR)` 추가 (**`FundingMapper.xml:161`**). 개인정보 파기는 5년 이전(`<=`), 조회는 5년 이후(`>`)로 경계를 비중복 처리.
>
> ### RWD-5675 — 프로젝트 요금제 변경 Slack 알림 + 글로벌 메이커 CorpType 고정
> - 신규 엔드포인트 `POST /api/v1/slack/campaigns/{projectNo}/plan-change/send` (**`SlackController.java:59`**, `PlanChangeNotificationRequest` — before/after PlanType + status). ⚠️ 구현 초기 `category-change/send`(`CategoryChangeNotificationRequest`)로 추가됐으나 같은 이슈 안에서 요금제 변경(plan-change)으로 개명·재용도되어 최종 반영됨.
> - 요금제 판단(`PackagePlanDeterminationGatewayImpl`)에서 글로벌 메이커인 경우 `CorpType`를 `IB`로 고정 (**`PackagePlanDeterminationGatewayImpl.java`**). (2026-06-18 문서의 "서비스요금 개인/사업자 분기" RWD-5671의 후속 보정.)
>
> ### RWD-5720 — 캠페인 계약 실명인증 복호화 CryptoHelper 마이그레이션
> - `CampaignContractMapper.xml`의 `findVerifiedRealName`에서 `damo.DEC_B64()` 호출 제거(암호화 원문 반환)하고, `CampaignAgreementCommandGatewayImpl`의 `isRepresentativeVerified()`에서 `CryptoHelper`로 복호화하도록 이전. DB 함수 복호화 → 애플리케이션 복호화로 통일.
>
> ### RWD-5774 / RWD-5375 — 리팩터링·의존성
> - AIReview payload(`AIReviewRequest`·`InputParameter`)의 `@Setter` 제거 및 `AIReviewQueryGatewayImpl` builder 누적 방식 전환, `funding-core` 1.0.146-SNAPSHOT 반영 (RWD-5774). AI 심사 호출 URL 수정(RWD-5764).
> - 환전 응답 `convertedAmounts` 타입이 `BigDecimal → Long`으로 변경됨에 맞춰 `CurrencyExchangeClientTest` 컴파일 에러 수정 (RWD-5375).

---

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
- [`infrastructure.md`](./infrastructure.md) — adapter/infrastructure 모듈 (외부 HTTP 클라이언트 35개, MyBatis XML 88파일/32폴더, JDBC Repository 79개, Redis 4 해시, Mongo 6 컬렉션)
- [`core-domain.md`](./core-domain.md) — core/domain 모듈 (도메인 패키지 74개, Gateway 포트 167개, UseCase 241개, 인프로세스 이벤트 26종, 주요 상태 Enum)
- [`bootstrap.md`](./bootstrap.md) — bootstrap 모듈 (application/batch 엔트리, YML 프로파일 14개, SecurityFilterChain, `@PreAuthorize` SpEL 6개)


---

## 최근 변경사항

**분석 갱신일: 2026-07-31** (직전: 2026-07-10, 최초: 2026-04-20)

### 신규 기능 (2026-07-31 갱신분)

#### 사후심사 스토리 버전 복구 다국어 대응 (RWD-5792)
- `StoryCopyInternalController`에 신규 엔드포인트 `POST /api/internal/story-copy/{projectNo}/restore` 추가. 관리자가 사후심사 히스토리의 특정 버전(스냅샷)으로 스토리를 복구하며, 스냅샷 언어를 기준으로 작성언어/옵션언어를 분기 처리한다.
- 요청 DTO `StoryRestoreRequest{revivalHistoryId, adminUserId}` 신규. `StoryCopyUseCase.restoreStoryByVersion`·`StoryCopyGateway.restoreStoryByVersion`(구현 `StoryCopyGatewayImpl`)·`StoryCopyMapper` 추가. 응답은 기존 스토리 복사와 동일한 `ServiceOperationResponse`(실패 시 errorCode `STORY_RESTORE_FAILED`, 내부 오류 `INTERNAL_ERROR`).
- 버전 스냅샷 역직렬화 시 미지 필드(`encPhotoId`)로 인한 실패를 막기 위해 `CampaignImage`/`CampaignRepresentativeImage`/`CampaignStory`/`CampaignTag` 모델에 `@JsonIgnoreProperties(ignoreUnknown = true)` 적용.

#### 단순 변심 환불 제한 프로젝트 결제 취소 버튼 비활성화 (RWD-5844)
- 단순 변심 환불이 제한된 프로젝트(`RewardRefundPolicy.IsRestrictedForRevised = TRUE`)는 결제 예약 배치 이전(`PayStatus` A10/B10) 상태가 아니고 프로젝트 종료일(`whenHoldTo`)이 지났으면 결제 취소 불가로 처리한다. `FundingResponse.getIsPaymentCancelable` 로직에 해당 분기를 추가하고 `isRestrictedForRevised` 필드를 노출.
- 서버 측 취소 검증(`BackingPaymentSummationCancelInfo.valid`)에도 동일 조건을 추가해 종료 이후 취소 시도 시 `"단순 변심에 의한 결제 취소가 제한된 프로젝트입니다."` 예외 반환. DTO에 `whenClose`·`isRestrictedForRevised` 필드, `FundingDetailResult`에 `isRestrictedForRevised` 필드 추가.
- `BackingPaymentMapper.xml`에서 `RewardRefundPolicy` 서브쿼리로 `IsRestrictedForRevised`·`WhenClose`를 함께 조회.

#### 정산 fee-version 조회 시 BizModel null 방어 (SCOUT-125)
- 캠페인 `BizModel`이 null(미생성/비정상 캠페인)일 때 `ProjectType.fromName(null)`이 `IllegalArgumentException`을 던져 500이 발생하던 문제를, name이 null이면 `EntityNotFoundException`(404)으로 전환. `fromName` 중앙 수정으로 정산 관련 UseCase 전체에 방어 적용. (SCOUT-83의 후속 방어)

#### 인프라·설정
- `rc4` 브랜치용 AWS ECR 배포 GitHub Actions 워크플로(`aws_deploy_ecr_rc4.yml`) 추가 및 배포 `value_file_path` 갱신.

### 신규 기능 (2026-06-18 갱신분)

#### 스팸가드(SpamGuard) — 게시판 피싱 봇 자동 감지·삭제 배치 (RWD-5694)
- `core/domain/spamguard/PhishingDetection` — **공용 피싱 탐지기**(순수 함수). 알려진 피싱 템플릿과의 문자 n-gram(3-shingle) Jaccard 유사도를 핵심 기준으로 판정하며, `https://wadiz.kr@verify-access.world` 같은 **userinfo(`@`) 도메인 스푸핑 링크**·wadiz 사칭 외부 링크·피싱 키워드를 보조 신호로 결합. 오탐 최소화 설계(유사도 단독 또는 사칭링크+키워드 다수 조합 시에만 판정). `Signature`/`PersonalMessageBoard`/`MiniBoardCommon` 세 게시판이 공유.
- 신규 배치 Job 3종(모두 `adapter/batch`, Tasklet 방식): `signatureSpamGuardJob`(지지서명), `personalMessageSpamGuardJob`(1:1 메신저), `miniBoardSpamGuardJob`(미니 게시판 댓글). 각 Job은 최근 N분(스캔 윈도우) 내 게시물을 조회 → 피싱 판정 → 삭제 → Slack 웹훅으로 리포트. `dryRun`/`enabled` 토글 프로퍼티 지원.
- 지지서명 삭제는 직접 UPDATE SQL이 아니라 **Community API 호출로 전환**(RWD-5697): `SignatureApiClient`에 `DELETE /api/v3/supporter-signatures/{signatureId}` 추가, 삭제 유형 `SignatureDeleteType`(`DELETED_BY_MAKER`/`DELETED_BY_ISSUE`) 신설, 스팸가드는 `DELETED_BY_ISSUE`로 삭제.
- 스캔 윈도우 5→10분 확대(RWD-5701), 피싱 판정을 템플릿 유사도 중심으로 재설계해 오탐 최소화(RWD-5694).

#### AI 스토리 생성 사용량 한도 API (RWD-5620)
- `aistory` 도메인 신규: 회원의 AI 스토리 생성 일별 사용량·한도를 관리. 한도 초과 시 Slack 알림.
- 신규 엔드포인트: `GET /api/v1/ai-story/quota`(내 사용 현황), `POST /api/internal/ai-story/generation`(사용량 적재), `PUT /api/internal/ai-story/quota/{userId}`(한도 조정), `GET /api/internal/ai-story/quota/{userId}`, `GET /api/internal/ai-story/stats/daily`(일별 통계).

#### Stripe Connect 계정(메이커 정산 계정) API·배치 (RWD-5285/5618)
- `stripe.account` 도메인 신규: 글로벌 메이커의 Stripe Connect 계정 생성·온보딩 링크·심사 상태·정산(payout) 정보를 관리. `StripeAccountStatusType`(인증 진행/추가서류 필요/승인 등 상태머신), 상태 변경 이력은 MongoDB 저장, 상태 변경 이벤트는 SQS 리스너(`StripeAccountUpdatedSqsListener`)로 수신.
- 신규 엔드포인트(메이커 `/api/studio/stripe/accounts/{projectNo}`): `GET /find`, `POST`(생성), `POST /create`(projectNo 기반 생성), `POST /{accountId}/link`(온보딩 링크), `GET /{accountId}/status`, `GET /status`(projectNo 기반), `GET /{accountId}/status/realtime`(FEP 실시간), `GET /{accountId}/payout-info`, `GET /{accountId}/persons`, `GET /detail`. 내부(`/api/internal/stripe/accounts`): `GET /projects/{projectNo}/status`, `GET /{accountId}/history`.
- 신규 배치 `stripeConnectReminderJob` — 사업자 인증 진행/추가 서류 제출이 지연된 메이커에게 1·2차(3일·7일 경과) 리마인드 메일 발송. Step 4개, 매일 09:00 KST Jenkins cron 실행.

#### 통관번호(개인통관고유부호) 저장·수정 (RWD-5687)
- 배송지 변경 API(`PUT /api/supporters/my/fundings/{backingPaymentId}/shipping-address`)에서 통관번호 수정 기능 추가. `ShippingAddressModifyUseCase`가 기존 `BackingPaymentInfo`와 병합(`StringUtils.defaultIfBlank`)하며 `customsCode`도 함께 저장(null 허용).

#### Stripe 원화/USD 결제·예약결제 취소 currency 분기 (RWD-5622)
- Stripe 원화 예약 결제 취소 시 통화(currency) 분기 처리. `ReservationPayCancelProcessor`/`CancelPaymentUsecase`에서 취소 통화를 결제 통화 기준으로 결정, `ApproveReservePaymentRequest`/`CancelReservePaymentRequest`·`BackingPaymentSummationCancelInfo`에 currency 필드 추가.

#### 환불 총액 Display 금액 (RWD-5689)
- 펀딩 상세(`FundingDetailUseCase`) 환불 요약에 `displayTotalPaymentCancelAmount`/`displayTotalPaymentCancelAmountCurrency` 추가. Stripe(USD) 분기에서 `totalPaymentCancelAmount`가 USD cents로 덮어써지기 전 KRW 원본을 캡처해 별도 표시 금액으로 노출.

#### 컬렉션 자동화 확장 (RWD-5663/5665/5705)
- 기존 `collectionAutomationJob`에 자동화 컬렉션 추가: 푸드 산지직송·로컬맛집(`EveryNookandCorner`, RWD-5663), 신규 메이커(`RookieBox`, RWD-5665), 글로벌 배송국가별 6종(미국/일본/중화권 × 본펀딩/오픈예정 — `whatsnext*` 계열, RWD-5705). `CollectionKeyword` enum 확장, 배송국가 전략(`ShippingCountryGroup`) 신설.

#### 서비스요금 개인/사업자 분기 (RWD-5671)
- 요금제 판단(`PackagePlanDeterminationGatewayImpl`)에서 메이커 유형을 분기: 개인(IV)은 userId 기준, 사업자(IB/CB)는 사업자등록번호 기준으로 기존 펀딩 프로젝트 목록을 조회(`MakerProjectsClient.findFundingProjectNos`에 `CorpType` 파라미터 추가).

### 신규 API
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 파트너 조회 API 추가 | 2026-05-14 | RWD-5566 |
| 메이커 프로필 등록 API 추가 | 2026-05-04 | RWD-5469 |
| 메이커홈 대시보드 프로젝트 리스트 API | 2026-04-29 | RWD-5497/5504 |
| 메이커홈 통합 메트릭 API (팔로워 수 포함) | 2026-05-04 | RWD-5497/5506 |
| 글로벌 리워드 API `shippingCountry` 파라미터 추가 (country 하위 호환) | 2026-04-22 | RWD-5492 |

### API 변경
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| Category benchmark API `dayN` 파라미터 제거 | 2026-05-13 | RWD-5497 |
| Category benchmark key 명 변경 | 2026-05-04 | RWD-5497 |
| 리워드 단건 조회(Item) 응답에서 할인 정보 제외 | 2026-04-21 | RWD-5345 |
| 새소식 말머리 유효성 체크 HTTP 400 반환 | 2026-05-19 | RWD-5569 |
| 결제 실패 시 redirect URL에 `&failureType=` 파라미터 추가 | 2026-04-29 | PRODUCT-639 |

### 결제·비즈니스 로직 변경
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| nicepay 외부PG 오류 시 결제완료된 건 자동 결제취소 처리 | 2026-05-18 | RWD-5576 |
| 오픈 프로젝트 노출 조건 변경 + 글로벌 진행중 컬렉션 자동화 | 2026-05-21~22 | RWD-5585 |
| 예약 결제 100원 검증 추가 | 2026-04-27 | PRODUCT-639 |
| 리워드 뱃지(RewardBadge) 추가 — 결제·참여취소 화면 | 2026-04-23~24 | PRODUCT-781 |
| 쿠폰+포인트 전액 결제 시 메일 문구 일시불 정보 제거 | 2026-04-24 | PRODUCT-781 |
| 프로젝트 공개/비공개 알림톡 Template 변경 | 2026-04-20~21 | RWD-5479 |
| 프로젝트 공개 처리 시 번역 요청 자동화 | 2026-04-20 | RWD-5479 |
| batch AI 심사 설정 추가 | 2026-04-21 | RWD-5479 |

### 인프라·설정
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| clive 환경 GitHub Actions workflow 추가 | 2026-05-28 | RWD-5606 |
| Hazelcast Kubernetes 디스커버리 1.3.1 → 1.5.2 업그레이드 | 2026-05-13 | RWD-5554 |
| SSM 라이브러리 제외 방식 변경 (`-PciBuild` → `-PlocalBuild`) | 2026-05-18 | - |
| reward-models 0.4.11-SNAPSHOT 적용 | 2026-05-18 | - |
| SQS 도메인 변경 | 2026-04-23 | RWD-5496 |
| batch 컨텍스트에 dataplusAsyncExecutor 빈 추가 | 2026-05-21 | RWD-5589 |
