# adapter/infrastructure 모듈 상세 스펙

> **기록 범위**: `adapter/infrastructure/src/main/` 아래의 소스 코드에서 **직접 관측 가능한** 구현 표면만 기록한다.
> 비즈니스 UseCase 구현체는 외부 jar(`funding-core`)에 있으므로 내부 로직은 기술하지 않는다.
> 기록 대상: Gateway/Repository 구현 클래스, MyBatis XML SQL, `@RedisHash` 엔티티, MongoDB `@Document` 컬렉션, Spring `@EventListener` 핸들러, AWS SQS 리스너, 외부 HTTP 클라이언트 메서드.
> 기록 불가 항목은 "확인 불가 (bootstrap 모듈에서 주입)" 으로 표기한다.

---

> 📅 **2026-09-29 본문 전면 점검** — `master` 브랜치 `a9fac634f` 기준
>
> 직전 본문 점검이 2026-04-20 이었습니다. 그 사이 504개 커밋이 들어왔습니다.
> 개수·경로·URL 을 코드에서 다시 세어 아래 항목을 고쳤습니다.
>
> | 고친 곳 | 예전 | 지금 |
> |---|---|---|
> | MyBatis Mapper XML | 88개 | **101개** |
> | Spring Data JDBC 저장소 | 79개 | **80개** |
> | MongoDB 컬렉션 | 5개 | **8개** |
> | 외부 호출 클라이언트 클래스 | 27개 | **50개** |
> | 이벤트 핸들러 클래스 | 14개 | **17개** |
> | AWS SQS 리스너 | 1개 | **2개** |
> | 메일 템플릿 | 4개 | **7개** |
>
> **가장 큰 변화는 설정 파일 구조입니다.**
> `RWD-5766`(2026-07-01, `3dfb6a6bf`)이 `application-dev.yml` 을 지웠습니다.
> 커밋 제목이 "도메인 io 적용 및 dev profile 설정삭제(helmchart 대체)" 입니다.
> 개발 환경 값은 이제 쿠버네티스 차트의 설정맵에서 주입합니다.
> 그래서 이 문서의 Base URL 표는 **`application-local.yml` 기준으로 다시 썼습니다.**
> 로컬 프로파일이 클라우드 개발 인프라(`api.dev.wadiz.io`)를 바라보기 때문입니다.
>
> 이번 기간에 새로 들어온 연동은 넷입니다.
>
> | 이슈키 | 날짜 | 무엇이 들어왔나 |
> |---|---|---|
> | `RWD-5311` | 2026-03-20 | Stripe 중계서버(FEP) 연동 — 클라이언트·몽고 컬렉션·SQS 리스너·매퍼 4개 |
> | `RWD-5375` | 2026-03-30 | 환전 서버 연동 (`CurrencyExchangeClient`) |
> | `RWD-5415` | 2026-05-07 | 암복호화 추상화 계층과 `crypto-api` 연동 |
> | `RWD-5785` | 2026-07-09 | DataPlus Elasticsearch 직접 조회 (`DpSearchClient`) |
>
> `RWD-5785`(2026-07-09, `2823633ba`)는 **rc3 환경을 폐기**했습니다.
> 지금 설정 파일에 남은 프로파일은 `local`·`rc`·`rc2`·`live`·`deploy` 다섯입니다.

---

## 1. 개요 & 기록 범위

`adapter/infrastructure` 모듈은 헥사고날 아키텍처의 **Secondary Adapter(아웃바운드)** 계층이다. `funding-core`가 정의한 Gateway 포트 인터페이스를 구현하며, 실제 데이터 저장소(MySQL, Redis, MongoDB)와 외부 서비스(ERP/Douzone, DataPlus, 결제 PG, 알림, 번역, AI 등)를 연결한다.

주요 역할:
- **MySQL 영속성**: MyBatis Mapper XML **101개** + Spring Data JDBC 저장소 **80개**
- **Redis 세션/캐시**: `@RedisHash` 기반 주문 세션·주문서·재고 4종, `StringRedisTemplate` 기반 중복 방지 락 4종
- **MongoDB 로그**: **8개 컬렉션** — 알림·주문 3종·리워드 변경·번역 실패·Stripe 계정 이력·개인정보 파기 이력
- **외부 호출 클라이언트**: **50개 클래스**. 대부분 `RestTemplate` 이지만 예외가 셋 있습니다
- **이벤트**: Spring `ApplicationEventPublisher` 디스패치 + **17개 핸들러 클래스** + AWS SQS 리스너 **2개**

> ⚠️ **"모두 `RestTemplate`" 이 더는 맞지 않습니다.** 세 갈래가 다릅니다.
>
> | 클라이언트 | 통신 방식 |
> |---|---|
> | `DpSearchClient` | Elasticsearch 저수준 `RestClient` 로 색인을 직접 조회합니다 |
> | `AttachClient` | AWS S3 SDK 의 `S3Presigner` 를 씁니다. HTTP 호출이 아닙니다 |
> | `PointClient` · `RewardClient` | 사내 SDK 라이브러리를 감싼 래퍼입니다 |
>
> `@FeignClient` 는 여전히 한 곳도 쓰지 않습니다.

---

## 2. 패키지 구조

```
java/com/wadiz/api/funding/
├── client/          # 외부 호출 클라이언트 (41개 서비스 폴더, 클라이언트 클래스 50개)
├── compliance/      # 개인정보 파기 이력 기록 (MongoDB) — 신규
├── config/          # 인프라 설정 (MyBatis, Redis, Mongo, JDBC, 재시도 등)
├── domain/          # 인프라 측 이벤트 핸들러, 도메인 확장 구현체
├── event/           # EventDispatcherImpl (ApplicationEventPublisher 래퍼)
├── mongo/           # MongoDB Document DTO + MongoRepository + Gateway 구현체
├── persistence/     # MyBatis @Mapper(105개) + Spring Data JDBC 저장소(80개) + DTO
├── redis/           # @RedisHash 엔티티 + KeyValueRepository + Gateway 구현체
└── support/         # JSON/타입 변환 유틸, 데이터 상수, 공통 저장소 인터페이스

resources/
├── config/          # application-infrastructure.yml · application-test.yml
├── mapper/          # MyBatis XML (101개, 서브폴더 포함)
└── templates/mail/  # Thymeleaf 메일 HTML 템플릿 (7개)
```

`compliance/` 는 이 기간에 새로 생긴 최상위 패키지입니다.
개인정보를 파기한 기록을 MongoDB 에 남깁니다. 어떤 표의 어떤 칼럼을 지웠는지까지 적습니다.

### 2-1. 환경 프로파일 구성 (중요)

**설정 파일의 구조가 이 기간에 근본적으로 바뀌었습니다.**
`application-dev.yml` 이 2026-07-01 에 삭제됐습니다(`RWD-5766`, `3dfb6a6bf`).
개발 환경 값은 쿠버네티스 차트의 설정맵으로 옮겨 갔습니다.

지금 저장소에 남아 있는 프로파일 파일은 다섯입니다.

| 파일 | 무엇을 담나 |
|---|---|
| `adapter/application/src/main/resources/config/application.yml` | 환경 무관 기본값. 환경 파일이 덮어쓰지 않으면 이 값이 그대로 쓰입니다 |
| `.../application-local.yml` | 로컬 실행. **클라우드 개발 인프라(`api.dev.wadiz.io`)를 바라봅니다** |
| `.../application-rc.yml` · `application-rc2.yml` | 사내(온프렘) 검증 환경 |
| `.../application-live.yml` | 사내(온프렘) 운영 환경. 도메인이 `www.wadiz.kr`·`platform.wadiz.kr` 입니다 |
| `.../application-deploy.yml` | 배포 공통 22줄 |

> ⚠️ **운영 환경이 둘입니다.** `application.yml` 의 주석이 이렇게 적고 있습니다 —
> *"운영 채널은 live(application-live.yml)·clive(helm configmap)에서만 override"*.
> 즉 사내(온프렘) `live` 와 클라우드 `clive` 가 함께 돌고 있고,
> **클라우드 쪽 값은 이 저장소에 없습니다.** 차트의 설정맵을 봐야 합니다.

`RWD-5785`(2026-07-09, `2823633ba`)가 **rc3 환경을 폐기**했습니다. 해당 파일이 사라졌습니다.

---

## 3. 외부 호출 클라이언트 인벤토리

`client/` 아래에 서비스 폴더가 **41개**, 실제 호출을 하는 클라이언트 클래스가 **50개** 있습니다.
`@FeignClient` 는 한 곳도 쓰지 않습니다.

**Base URL 은 `adapter/application/src/main/resources/config/application-local.yml` 값입니다.**
예전에는 `application-dev.yml` 을 기준으로 적었는데 그 파일이 삭제됐습니다.
로컬 프로파일이 클라우드 개발 인프라를 그대로 바라보므로 이 값이 개발 환경 값과 같습니다.
운영(온프렘 `live`) 값이 눈에 띄게 다른 것만 따로 적었습니다.

### 3-1. 사내 플랫폼 게이트웨이 경유 (`api.dev.wadiz.io/*`)

클라우드 전환 뒤 사내 서비스 호출이 **하나의 게이트웨이 호스트로 모였습니다.**
예전 문서가 적어 둔 `http://dev-app01:9990/*` 직접 호출은 대부분 사라졌습니다.

| 클라이언트 클래스 | 역할 | 설정 키 | Base URL (local/dev) | 주요 엔드포인트 |
|---|---|---|---|---|
| `RewardClient` | 쿠폰·만족도 (com.wadiz.api.reward SDK 래퍼) | `application.reward-client` | `https://api.dev.wadiz.io/reward` | SDK 경유 |
| `CollectionClient` | 컬렉션 조회·프로젝트 편입 | `application.reward-client` | 동일 | `getAllCollection`, `findCollectionNoByKeyword`, `addProjectsToCollection` |
| `RewardBridgeClient` | 배송 추적 택배사 목록 | `application.reward-bridge-client` | `https://api.dev.wadiz.io/reward/bridge` | `GET /api/v1/tracker/bridge/companylist` |
| `StoreClient` | 스토어 프로젝트·상품 조회 | `application.store-client` | `https://api.dev.wadiz.io/store` | `GET /api/orders/qty`, `GET /api/projects/by-funding`, `GET /api/projects/{projectNo}`, `GET /api/projects/{projectNo}/products/aggregation` |
| `UserClient` | 유저 연령 인증 조회 | `application.user-client` | `https://api.dev.wadiz.io/user` | `GET /api/v1/users/{userId}/age-verification` |
| `FollowClient` | 팔로우 이벤트 등록·취소·팔로잉 조회 | `application.user-client` | 동일 | `POST`·`PUT /api/v1/users/followers/events`, `GET /api/v1/users/followers/user/{id}/following/user-id` |
| `MakerUserClient` | 메이커 언어 설정 조회 (묶음) | `application.user-client` | 동일 | `POST /api/v1/makers/languages/bulk` |
| `SignatureApiClient` | 지지서명 추적 등록·삭제 | `application.community-client` | `https://api.dev.wadiz.io/community` | `POST /api/v3/users/{userId}/supporter-signatures/{id}/affiliates`, `DELETE /api/v3/supporter-signatures/{id}` |
| `MembershipApiClient` | 멤버십 혜택 조회·사용 통보 | `application.membership-client` | `https://api.dev.wadiz.io/membership` | `POST /user/availables`, `GET /user/{userId}`, 혜택 사용 통보, 결제수단 변경 |
| `SettlementClient` | 정산 스케줄·안심번호 최종결제일 조회 | `application.settlement-client` | `https://api.dev.wadiz.io/funding/settlement` | `POST /api/v1/transaction/bulk`, `GET /api/v1/schedule/settlement/projects`, `GET /api/v1/schedule/settlement/due-date` |
| `PointClient` | 포인트 사용·환불·적립 (wave-point SDK 래퍼) | `application.point-client` | `https://api.dev.wadiz.io/point` | SDK 경유 |
| `CorporationClient` | 법인(메이커) 조회·팔로워 확인 | `application.startup-client` | `https://api.dev.wadiz.io/startup/api/v1/startup` | `GET /maker`, `GET /maker/campaignType/{type}/campaignId/{id}`, `POST /maker/follow/check` |
| `MakerProjectsClient` | 메이커의 프로젝트 번호 목록 조회 | `application.startup-client` | 동일 | `GET /maker/{projectType}/project-nos` |
| `MakerProfileClient` | 메이커 프로필 등록 | `application.startup-client` | 동일 | `POST /maker/interconnect/funding` |
| `MakerPushClient` | 메이커 Push 크레딧 발급 | `application.startup-client` | 동일 | `POST /maker/{corpNo}/push/credit/issuance` |
| `MakerClubClient` | 메이커 등급 목록 조회 | `application.startup-client` | 동일 | `GET /maker-club` |
| `CategorySearchClient` | 검색 카테고리 조회 | `application.searcher-client` | `https://api.dev.wadiz.io/search` | `GET /api/search/categories` |
| `BrazeClient` · `BrazeV2Client` | Braze 유저 이벤트 트래킹 | `application.braze-client` | `https://api.dev.wadiz.io/crm/api/v1/crmgateway/braze` | `PUT /users/track` |
| `AlimtalkV2Client` | 카카오 알림톡 v2 발송 | `application.alimtalk-client-v2` | `https://api.dev.wadiz.io/alimtalk` | `POST /api/v2/message/alimtalk` |
| `SmsV2Client` | SMS v2.1 발송 | `application.sms-client-v2` | `https://api.dev.wadiz.io/sms` | `POST /api/v2.1/message/sms` |
| `FriendtalkClient` | 카카오 친구톡 이미지 올리기 | `application.friend-talk-client` | `https://api.dev.wadiz.io/friends` | `POST /api/v2/upload/image` |
| `NotificationClient` | 메일·푸시·알림함·비즈메시지 발송 | `application.mail-normal-client` · `application.push-client` | 메일 `https://api.dev.wadiz.io/mail-normal`, 푸시 `https://api.dev.wadiz.io/push` | 메일 `POST /api/v2/send`·`/api/v2/send/batch`·`/api/v3/send`, 푸시 `POST /api/v1/push/user`·`/api/v1/push/inbox` |
| `PayApiClient` | PG 결제 승인·취소 (nicepay-api) | `application.pay-client` | `https://api.dev.wadiz.io/nicepay-api` | `POST /api/v2/auth/approval`·`/cancel`, `/api/v2/reserve/*`, `/v1/scheduled/*`, `/api/v1/billkey` |
| `CryptoApiClient` | 개인정보 암복호화 | `application.crypto-client` | `https://api.dev.wadiz.io/crypto` | `POST /api/crypto/encrypt`·`/decrypt`, `/encrypt/bulk`, `/decrypt/bulk` |
| `TranslateClient` | 텍스트·HTML 번역 | `application.translate-client` | `https://api.dev.wadiz.io/global` | `POST /translate/text`, `POST /translate/html` |
| `ExchangeRateClient` | 환율 조회 | `application.exchange-rate-client` | `https://api.dev.wadiz.io/global` | `GET /exchange-rates/{countryCode}` |
| `CurrencyExchangeClient` | 통화 환산 (묶음·다중통화) | `application.currency-exchange-client` | `https://api.dev.wadiz.io/currency-exchange` | `POST /api/v1/internal/conversion/bulk`, `POST /api/v1/internal/conversion/multi-currency/bulk` |
| `CountryClient` | 국가 목록 조회 | `application.country-client` | `https://dev.wadiz.io/web` | `GET /v1/countries` |

> 🔎 **메일 발송 경로에 함정이 있습니다.** `NotificationClient` 는 `/api/v2/send` 를 부를 때
> 설정된 주소의 `/mail-normal` 을 **`/mail-fast` 로 바꿔치기**합니다
> (`client/notification/NotificationClient.java:53`). `/api/v3/send` 는 바꾸지 않습니다.
> 설정 값만 보고 "빠른 메일 서버는 안 쓴다"고 읽으면 틀립니다.

### 3-2. 사내 데이터·AI 서비스 (`wadizdata.team`)

| 클라이언트 클래스 | 역할 | Base URL (local/dev) | 주요 엔드포인트 |
|---|---|---|---|
| `ProjectDataplusClient` | 펀딩 프로젝트 대시보드 통계 | `https://dev-api.wadizdata.team/dataplus` | `GET /v1/reward/{no}/funding-status/metrics`·`/trends`·`/traffic-status/*`·`/supporter-info/*` |
| `ComingSoonDataplusClient` | 오픈예정 대시보드 통계 | 동일 | `GET /v1/coming-soons/{no}/notification-status/*`·`/traffic-status/*`·`/subscriber-info/*` |
| `CommonDataplusClient` | 카테고리 벤치마크·팔로워 수 | 동일 | `GET /v1/common/benchmark/category`, `GET /v1/common/{projectNo}/follower/count` |
| `AIReviewClient` | AI 심의 요청 | `https://dev-api.wadizdata.team/genai/v2` | `POST /maker/content-review` |
| `AiTranslateClient` | AI 번역 (스토리·이미지) | `https://dev-translate.wadizdata.team/v3` | `POST /story`, `POST /media` |
| `ProjectAiSummaryClient` | 프로젝트 AI 요약 조회 | `https://project-data.wadizdata.team` | `GET /summary?project_id={no}&lang={lang}` |
| `DpSearchClient` | DataPlus Elasticsearch 색인 직접 조회 | `dev-esai.wadizdata.team:443` | `POST /{index}/_search` |

> `AiTranslateClient` 의 경로가 `/v2` 에서 **`/v3`** 으로 올라갔습니다(`RWD-5746`, 2026-06-23).
>
> `DpSearchClient` 는 이 표에서 유일하게 **HTTP 클라이언트가 아닙니다.**
> Elasticsearch 저수준 `RestClient` 로 색인을 직접 읽습니다(`RWD-5785`, 2026-07-09).
> 급상승 프로젝트 컬렉션을 자동으로 뽑는 데 씁니다.

### 3-3. 외부 업체·공공 API

| 클라이언트 클래스 | 역할 | Base URL | 주요 엔드포인트 | 인증 |
|---|---|---|---|---|
| `ErpClient` | ERP(더존) 부서·직원·미수금 조회 | `application.erp-client.erp-url` — rc `https://dev-erp.wadizcorp.kr`, live `https://erp.wadizcorp.kr` | `GET /api/MA/.../IF003`·`IF004`, `GET /api/FI/.../IF017` | 2단계 토큰 발급 뒤 `X-Authenticate-Token` |
| `ErpSettlementClient` | ERP 정산 진행·결과·수수료·내역서 | `application.erp-client.settlement-url` — rc `https://rc-settlement.wadizcorp.kr:8443`, live `https://settlement.wadizcorp.kr` | `GET .../IF033`·`IF034`·`IF041`, `GET .../fees/projects/{id}` | 동일 |
| `StripeApiClient` | Stripe 중계서버(FEP) 계정 관리 | live `https://platform.wadiz.kr/fep` | `POST /api/internal/v1/accounts`, `POST .../{id}/link`, `GET .../{id}`·`/status`·`/payout-info`·`/persons` | 설정 토큰 |
| `BizMoneyClient` | 광고비 무료 포인트 발행 | `https://rc-api.business.wadiz.kr/payments` | `POST /v1/biz-money/free/publish` | HTTP 기본 인증 |
| `BankAccountClient` | 계좌 실명 확인 (쿠콘) | `https://dev2.coocon.co.kr:8443/sol/gateway/acctnm_rcms_wapi.jsp` | `POST` (form-data `JSONData=`) | 설정 키 2종 |
| `BusinessVerifyClient` | 사업자 진위 확인 (국세청 공공데이터) | `http://api.odcloud.kr/api/nts-businessman/v1` | `POST /validate?serviceKey=...` | URL 파라미터 |
| `OCRClient` | 사업자등록증 OCR (네이버 클로바) | `https://enx57j76yz.apigw.ntruss.com/custom/v1/...` | `POST {invokeUrl}` | `X-OCR-SECRET` |
| `SafeNumberApiClient` | 안심번호 등록·해제 | `https://customer.safenumber.co.kr/api/sn` | `GET /register`, `GET /release` | `CID`·`CIDPWD` |
| `CertClient` (추상) | K-본인인증 공통 뼈대 | — | `getCertDetailResult(certId)` | 구현체가 결정 |
| `EmsitCertClient` | 본인인증 (EMSIT) | `http://emsit.go.kr` | 상동 | 설정 키 |
| `SafetyKoreaCertClient` | 본인인증 (제품안전정보센터) | `http://www.safetykorea.kr` | 상동 | 설정 키 |
| `AttachClient` | S3 올리기용 서명 주소 발급 | AWS S3 SDK (`S3Presigner`) | `PutObjectPresignRequest` (10초 유효) | AWS 서명 |
| `SlackClient` | 슬랙 웹훅 발송 (키로 채널 고르기) | 설정 `application.slack-client.webhooks.{key}` | `POST {webhookUrl}` | 없음 |
| `SlackWebhookClient` | 슬랙 웹훅 단일 발송 | 설정 `application.slack-webhook-client.webhook-url` | `POST {webhookUrl}` | 없음 |

> ⚠️ **확인 필요 — `application.yml` 의 ERP 설정이 아무 데도 연결되지 않습니다.**
> `application.yml:123-125` 가 이렇게 적고 있습니다.
>
> ```yaml
>   # erp-client.base-url 은 환경 yml 에 명시되지 않아 base 값이 모든 환경에 fallback (live 포함)
>   erp-client:
>     base-url: https://39.125.169.243/api
> ```
>
> 그런데 설정을 받는 클래스에는 **`baseUrl` 이라는 항목이 없습니다.**
> `client/erp/ErpClientProperties.java` 가 가진 항목은 `settlementUrl`·`erpUrl`·`defaultPath`·`tokenTtl` 넷입니다.
> 즉 이 IP 값은 어디에도 주입되지 않고, 위 주석의 설명도 지금 코드와 맞지 않습니다.
>
> 실제로 쓰이는 값은 `application-rc.yml`·`application-rc2.yml`·`application-live.yml` 의 `erp-url`·`settlement-url` 입니다.
> **`application-local.yml` 에는 `erp-client` 항목 자체가 없습니다.** 로컬에서 ERP 호출은 주소가 비어 있습니다.
> 원본 저장소는 읽기 전용이라 고치지 않고 여기 기록만 남깁니다.

> ⚠️ **슬랙 웹훅 기본값이 개발 채널로 바뀌었습니다.**
> `RWD-5909`(2026-08-27, `b1e93aa11`)가 `application.yml` 의 웹훅 4종을 개발 채널로 내렸습니다.
> 운영 채널은 `application-live.yml` 과 차트 설정맵에서만 덮어씁니다.
> 새 환경이 생겨도 덮어쓰기를 빠뜨리면 운영 채널을 더럽히지 않습니다.

> 🔐 **확인 필요 — 설정 파일에 평문 비밀값이 그대로 있습니다.**
> `application.yml` 과 `application-local.yml` 에 OCR 비밀키, 계좌 확인 키,
> 국세청 서비스 키, 본인인증 키, 안심번호 비밀번호, JWT 비밀값, 각 사내 서비스 토큰이
> 평문으로 적혀 있습니다. 값은 이 문서에 옮기지 않았습니다.
> 개발·로컬 값이라 해도 공개 저장소가 아니라는 전제에 기대고 있습니다. 담당 팀 확인이 필요합니다.

---

## 4. MySQL 영속성 계층

### 4-1. MyBatis Mapper XML 인벤토리 (총 101개)

| 폴더 | 파일 수 | XML 파일 목록 |
|---|---|---|
| `mapper/` (루트) | 50 | `AnnouncementMapper.xml`, `AutomatedCollectionMapper.xml`, `BackingPaymentCancelMapper.xml`, `BackingPaymentCouponMapper.xml`, `BackingPaymentCouponQueryMapper.xml`, `BackingPaymentDiscountBenefitMapper.xml`, `BackingPaymentMapper.xml`, `BackingPaymentMappingMapper.xml`, `BackingPaymentRefundMapper.xml`, `BackingPaymentStatisticMapper.xml`, `BackingRewardMapper.xml`, `BillkeyVerificationStatusMapper.xml`, `CampaignAskForEncoreMapper.xml`, `CampaignContractMapper.xml`, `CampaignMapper.xml`, `CampaignMarkerMapper.xml`, `CampaignScreeningRewardItemMapper.xml`, `CampaignSummary.xml`, `CatalogFeedMapper.xml`, `ComingSoonApplicantMapper.xml`, `ComingSoonApplicantStatisticMapper.xml`, `ComingSoonMapper.xml`, `EventDayMapper.xml`, `FundingMapper.xml`, `GlobalProjectMapper.xml`, `GlobalProjectRewardMapper.xml`, `IPLicenseMapper.xml`, `MakerMapper.xml`, `ManagerMapper.xml`, `NewsMapper.xml`, `NewsNotificationMapper.xml`, `ParticipationMapper.xml`, `PartnerMapper.xml`, `PaymentSummationMapper.xml`, `PingpongPaymentReminderMapper.xml`, `ReactionMapper.xml`, `ReviewImportMapper.xml`, `RewardEventMapper.xml`, `RewardItemMapper.xml`, `RewardLimitedTimeOfferMapper.xml`, `RewardMapper.xml`, `RewardProductMapper.xml`, `RewardRefundMapper.xml`, `ShippingMapper.xml`, `SignatureMapper.xml`, `StockRewardMapper.xml`, `TbCodeSubMapper.xml`, `TranslationStatisticsMapper.xml`, `UserMapper.xml`, `WishMapper.xml` |
| `mapper/additionalservice/` | 2 | `AdditionalServiceMapper.xml`, `CampaignAdditionalServiceMapper.xml` |
| `mapper/aireview/` | 1 | `AIReviewMapper.xml` |
| `mapper/aistory/` | 1 | `AIStoryMapper.xml` |
| `mapper/askforencore/` | 1 | `CampaignAskForEncoreRepository$SqlMap.xml` |
| `mapper/bottomsheet/` | 1 | `BottomSheetMapper.xml` |
| `mapper/campaign/` | 2 | `CampaignCommandMapper.xml`, `CampaignScreeningMapper.xml` |
| `mapper/campaign/agreement/` | 1 | `CampaignAgreementMapper.xml` |
| `mapper/campaign/submitapproval/` | 2 | `CampaignSubmitApprovalMapper.xml`, `SettlementCommandMapper.xml` |
| `mapper/campaigncongratulationhistory/` | 1 | `CampaignCongratulationHistoryRepository$SqlMap.xml` |
| `mapper/campaignupdate/` | 3 | `CampaignUpdateLanguageRepository$SqlMap.xml`, `CampaignUpdateNotificationDenyRepository$SqlMap.xml`, `CampaignUpdateNotificationRepository$SqlMap.xml` |
| `mapper/crypto/` | 1 | `DamoCryptoMapper.xml` |
| `mapper/dashboard/` | 1 | `MakerDashboardMapper.xml` |
| `mapper/encouragestoreopen/` | 1 | `EncourageStoreOpen.xml` |
| `mapper/languageexpansion/` | 1 | `LanguageExpansionMapper.xml` |
| `mapper/makerclub/` | 1 | `MakerClubMapper.xml` |
| `mapper/makerinvitation/` | 1 | `MakerInvitationMapper.xml` |
| `mapper/migration/` | 1 | `MigrationOngoingStoryMapper.xml` |
| `mapper/miniboard/` | 1 | `MiniBoardSpamGuardMapper.xml` |
| `mapper/pendingstandby/` | 1 | `CampaignPendingStandby.xml` |
| `mapper/personalmessage/` | 1 | `PersonalMessageSpamGuardMapper.xml` |
| `mapper/personalverification/` | 1 | `PersonalVerificationResultRepository$SqlMap.xml` |
| `mapper/project/` | 1 | `ProjectCorporationMapper.xml` |
| `mapper/qualitymonitor/` | 1 | `TranslationQualityMonitorMapper.xml` |
| `mapper/reaction/` | 1 | `BoardReactionUserRepository$SqlMap.xml` |
| `mapper/rewardevent/` | 2 | `RewardEventBenefitMappingRepository$SqlMap.xml`, `RewardEventRandomBenefitMappingRepository$SqlMap.xml` |
| `mapper/safenumber/` | 1 | `SafeNumberMapper.xml` |
| `mapper/screening/` | 1 | `ScreeningAlimtalkMapper.xml` |
| `mapper/settlement/` | 1 | `CampaignSettlementMapper.xml` |
| `mapper/settlement/excel/` | 2 | `SlipExcelMapper.xml`, `TaxInvoiceExcelMapper.xml` |
| `mapper/shipping/` | 1 | `DeliveredNotificationMapper.xml` |
| `mapper/shipping/pending/` | 1 | `PendingNotificationMapper.xml` |
| `mapper/signature/` | 1 | `SignatureSpamGuardMapper.xml` |
| `mapper/storycopy/` | 1 | `StoryCopyMapper.xml` |
| `mapper/storytranslation/` | 1 | `StoryTranslationMapper.xml` |
| `mapper/stripe/` | 4 | `CampaignPayoutMethodMapper.xml`, `StripeAccountMapper.xml`, `StripeConnectReminderMapper.xml`, `StripeNotificationMapper.xml` |
| `mapper/studio/log/` | 1 | `StudioPayloadLogMapper.xml` |
| `mapper/studio/pricing/` | 2 | `CampaignPackagePlanHistoryMapper.xml`, `CampaignPackagePlanMapper.xml` |
| `mapper/studio/section/` | 1 | `StudioSectionMapper.xml` |
| `mapper/support/` | 1 | `Clauses.xml` (공통 SQL 조각) |
| `mapper/user/` | 1 | `UserCustomsCodeMapper.xml` |

> `Clauses.xml` 은 공통 `<sql>` 조각을 담습니다. `DAMO_ENC_KEY` 암호화 패턴과 `IFNULL` 다국어 폴백이 그 예입니다.

**2026-04-20 이후 늘어난 13개는 이렇습니다.**

| 추가된 곳 | 무엇 |
|---|---|
| `mapper/stripe/` 4개 | Stripe 계정·지급수단·연결 독촉·알림 (`RWD-5311`) |
| `mapper/crypto/DamoCryptoMapper.xml` | 다모(DAMO) 암복호화 (`RWD-5415`) |
| `mapper/aistory/AIStoryMapper.xml` | AI 스토리 생성 |
| `mapper/screening/ScreeningAlimtalkMapper.xml` | 심사 알림톡 |
| 스팸 차단 3종 | `miniboard/`·`personalmessage/`·`signature/` 의 `*SpamGuardMapper.xml` |
| 루트 3개 | `AutomatedCollectionMapper.xml`, `BackingPaymentCouponQueryMapper.xml`, `ReviewImportMapper.xml` |
| `mapper/campaign/agreement/` | `CampaignAgreementMapper.xml` 이 `campaign/submitapproval/` 에서 옮겨 왔습니다 |

> **스팸 차단 매퍼 3종이 함께 생긴 점이 눈에 띕니다.**
> 미니보드·개인 메시지·지지서명 세 군데에 같은 방식의 차단 장치가 들어갔습니다.
> 배치 설정(`adapter/batch/.../application.yml:44-45`)에도 `signature-spam-guard` 항목이 있습니다.
> 주석이 *"Signature(지지서명) 피싱 봇 자동 감지·삭제"* 라고 적고 있습니다.

### 4-2. Spring Data JDBC 저장소 인벤토리 (총 80개)

> ⚠️ **기반 인터페이스가 바뀌었습니다.** 예전에는 대부분 스프링이 주는 `CrudRepository` 를 직접 상속했습니다.
> 지금은 **80개 중 66개가 `PersistableCrudRepository`** 를 상속합니다.
> 이건 이 저장소가 직접 만든 인터페이스입니다 —
> `support/data/PersistableCrudRepository.java` 에서 `CrudRepository` 를 한 겹 감쌌을 뿐이고,
> 대상 타입이 스프링의 `Persistable` 을 구현하도록 강제합니다.
> `Persistable` 은 "이 객체가 새것인지 이미 저장된 것인지"를 객체 스스로 답하게 하는 규약입니다.
> 나머지는 `CrudRepository` 직접 상속 4개, `PersistablePagingAndSortingRepository` 2개입니다.

`persistence/` 하위 서브패키지별 저장소입니다.

| 서브패키지 | 저장소 인터페이스 |
|---|---|
| `announcement/` | `AnnouncementRepository`, `AnnouncementByMenuRepository`, `AnnouncementDisplayRepository`, `AnnouncementDoNotShowAgainRepository`, `AnnouncementExposureRepository`, `AnnouncementHistoryRepository` |
| `askforencore/` | `CampaignAskForEncoreRepository` |
| `backing/` | `BackingRepository` |
| `backing/backingpayment/` | `BackingPaymentRepository`, `AdminImmediatePaymentLogRepository`, `PaymentApprovalRequestResultRepository` |
| `backing/backingpaymentcancellog/` | `BackingPaymentCancelLogRepository`, `BackingPaymentAdminCancelLogRepository` |
| `backing/backingpaymentcoupon/` | `BackingPaymentCouponRepository` |
| `backing/backingpaymentdiscountbenefit/` | `BackingPaymentDiscountBenefitRepository` |
| `backing/backingpaymentexternalinfo/` | `BackingPaymentExternalInfoRepository` |
| `backing/backingpaymentfx/` | `BackingPaymentFxRepository` — **신규**. 결제 건의 환전 정보 |
| `backing/backingpaymentmapping/` | `BackingPaymentMappingRepository` |
| `backing/backingpaymentpoint/` | `BackingPaymentPointRepository` |
| `backing/backingrewardcomposition/` | `BackingRewardCompositionRepository` |
| `backing/backingrewardoption/` | `BackingRewardOptionRepository` |
| `backing/backingrewardset/` | `BackingRewardSetRepository` |
| `billkey/` | `BillkeyVerificationStatusRepository` |
| `campaign/` | `CampaignRepository`, `CampaignAutoOpenRepository`, `CampaignContractRepresentativeRepository`, `CampaignRewardDelayRepository`, `ComingSoonRepository`, `ComingSoonApplicantRepository` |
| `campaigncongratulationhistory/` | `CampaignCongratulationHistoryRepository` |
| `campaignscreening/` | `CampaignScreeningDocumentUploadedRepository` |
| `campaignsnapshot/` | `CampaignSnapshotRepository` |
| `campaignupdate/` | `CampaignUpdateRepository`, `CampaignUpdateLanguageRepository`, `CampaignUpdateLogRepository`, `CampaignUpdateNotificationRepository`, `CampaignUpdateNotificationDenyRepository`, `CampaignUpdateNotificationDenyLogRepository` |
| `iplicense/` | `IPLicenseRepository`, `IPLicenseLogRepository`, `IPLicenseTagRepository`, `IPLicenseTopRankRepository` |
| `makerinvitation/` | `MakerInvitationRepository`, `MakerInvitationCodeRepository`, `MakerInvitationBenefitRepository`, `MakerInvitationBenefitPaymentRepository`, `MakerInvitationBenefitPaymentLogRepository` |
| `misc/` | `PhotoCommonRepository` |
| `personalconsent/` | `PersonalConsentItemRepository`, `CampaignPersonalConsentItemMappingRepository` |
| `personalverification/` | `PersonalVerificationResultRepository` |
| `projectpause/` | `ProjectPauseRepository`, `ProjectPauseHistoryRepository` |
| `reaction/` | `BoardReactionRepository`, `BoardReactionUserRepository`, `ReactionTypeRepository` |
| `refund/` | `RewardRefundPolicyRepository` |
| `reward/` | `RewardRepository`, `RewardLimitedTimeOfferRepository`, `RewardLimitedTimeOfferHistoryRepository` |
| `rewardevent/` | `RewardEventRepository`, `RewardEventParticipantRepository`, `RewardEventBenefitMappingRepository`, `RewardEventRandomBenefitMappingRepository` |
| `rewarditem/` | `RewardItemRepository` |
| `rewardpayment/` | `RewardPaymentRepository` |
| `settlement/` | `RewardSettlementRepository`, `RewardSettlementRateRepository`, `CampaignPackagePlanRepository`, `SettlementSystemRepository` |
| `settlement/excel/slip/` | `SlipExcelRepository` |
| `settlement/excel/taxinvoice/` | `TaxInvoiceExcelRepository` |
| `signature/` | `SignatureRepository` |
| `simplepay/` | `BillkeyManagerRepository`, `RewardPasscodeRepository`, `WadizSimplePayUseLogRepository` |
| `spaceexhibition/` | `SpaceExhibitionRepository` |
| `storeopennotification/` | `StoreOpenNotificationRepository` |
| `user/` | `UserProfileRepository` |
| `wish/` | `UserWishProjectRepository` |

**예전 문서와 달라진 곳은 셋입니다.**

| 무엇 | 내용 |
|---|---|
| `backing/backingpaymentfx/` 추가 | 결제 건의 환전 정보를 담습니다. `CurrencyExchangeClient` 도입과 짝을 이룹니다 |
| `settlement/excel/` 이 둘로 갈라짐 | `settlement/excel/slip/` 과 `settlement/excel/taxinvoice/` 로 나뉘었습니다 |
| `campaign/submitapproval/` 사라짐 | 예전 문서가 "MyBatis 로만 처리"라고 적어 둔 칸입니다. 지금은 저장소 패키지 자체가 없습니다 |

> `{Repository}$SqlMap.xml` 형식은 Spring Data JDBC 의 `@Query` 가 아니라
> MyBatis Mapper XML 로 복잡한 쿼리를 제공하는 혼합 방식입니다.

### 4-3. 접근 테이블 요약

도메인별 주요 테이블은 각 `api-details/*.md` 에서 상세 SQL과 함께 이미 기술되어 있다 (아래 링크 참조). 여기서는 infrastructure 레이어 관점 그룹만 정리한다.

| 그룹 | 주요 테이블 | 상세 문서 |
|---|---|---|
| 결제·펀딩 참여 | `BackingPayment`, `BackingPaymentCancelLog`, `BackingPaymentCoupon`, `BackingPaymentDiscountBenefit`, `BackingPaymentPoint`, `BackingPaymentExternalInfo`, `BackingRewardSet`, `BackingRewardOption`, `BackingRewardComposition`, `Backing`, `PaymentApprovalRequestResult` | [payment-flow.md](./api-details/payment-flow.md), [supporter-funding-refund.md](./api-details/supporter-funding-refund.md) |
| 캠페인·리워드 | `Campaign`, `CampaignSnapshot`, `CampaignAutoOpen`, `CampaignRewardDelay`, `ComingSoon`, `ComingSoonApplicant`, `Reward`, `RewardItem`, `RewardLimitedTimeOffer`, `RewardPayment`, `RewardEvent`, `RewardEventParticipant`, `RewardEventBenefitMapping` | [campaign-public.md](./api-details/campaign-public.md), [reward.md](./api-details/reward.md) |
| 정산·요금제 | `RewardSettlement`, `RewardSettlementRate`, `SettlementSystem`, `CampaignPackagePlan`, `CampaignPackagePlanHistory`, `CampaignAdditionalService` | [settlement.md](./api-details/settlement.md) |
| 배송 | `Shipping`, `ShippingNotification` | [settlement.md](./api-details/settlement.md) |
| 새소식·공지 | `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignUpdateTagMapping`, `CampaignUpdateNotification`, `CampaignUpdateNotificationDeny`, `CampaignUpdateNotificationDenyLog`, `Announcement`, `AnnouncementDisplay`, `AnnouncementByMenu`, `AnnouncementDoNotShowAgain`, `AnnouncementExposure`, `AnnouncementHistory` | [news-announcement.md](./api-details/news-announcement.md) |
| 서명·찜·앵콜 | `Signature`, `UserWishProject`, `CampaignAskForEncore` | [wish-signature-encore-comingsoon.md](./api-details/wish-signature-encore-comingsoon.md) |
| 인증·심플페이 | `BillkeyVerificationStatus`, `BillkeyManager`, `RewardPasscode`, `WadizSimplePayUseLog` | [misc.md](./api-details/misc.md) |
| 메이커·초대 | `MakerInvitation`, `MakerInvitationCode`, `MakerInvitationBenefit`, `MakerInvitationBenefitPayment`, `CampaignCongratulationHistory` | [maker-admin.md](./api-details/maker-admin.md) |
| 리액션·IP라이선스·기타 | `Reaction`, `ReactionType`, `IPLicense`, `IPLicenseLog`, `IPLicenseTag`, `ProjectPause`, `ProjectPauseHistory` | [iplicense-catalog-additional.md](./api-details/iplicense-catalog-additional.md), [misc.md](./api-details/misc.md) |
| 스토리·번역 | `StoryCopy`, `StoryTranslation` | [story-translate-aireview.md](./api-details/story-translate-aireview.md) |

---

## 5. Redis 계층

### 5-1. `@RedisHash` 엔티티 전수

| 엔티티 클래스 | 키 prefix (Spring Data Redis 자동: `{클래스명}`) | @Id 필드 | TTL | 주요 필드 |
|---|---|---|---|---|
| `OrderSession` | `OrderSession` | `token` (UUID) | **600초 (10분)** | `userId`, `campaignId`, `orderNo`, `secureStateBagKey`, `totalShippingCharge`, `rewards` (List), `countryCode`, `attributes` (donation/apid/dontShowName), `membershipBenefit` |
| `ClosedOrderSession` | `ClosedOrderSession` | `token` (UUID) | **10초** | `orderSessionInfo`, `orderSheetInfo`, `failureType`, `failMessage` |
| `OrderSheet` | `OrderSheet` | `orderNo` (String) | **600초 (10분)** | `title`, `invoice`, `rewardSheet`, `couponKey`, `bill` (fundingAmount/couponDiscountAmount/applyPoint), `recipient` (name/phoneNumber/address/shippingMemo/customsCode), `payType`, `deviceType`, `serviceType`, `condition` |
| `Stock` | `Stock` | `key` (String) | **5초** | `qty` |

> `OrderSession`, `ClosedOrderSession`은 `OrderSessionRedisGatewayImpl`이 함께 관리한다. `OrderSession`·`OrderSheet`은 `OrderSessionKeyValueRepository`/`OrderSheetKeyValueRepository`(`CrudRepository<T, UUID/String>` 확장) 경유.

### 5-2. `StringRedisTemplate` 기반 직접 Redis 접근 (비-`@RedisHash`)

| Gateway 구현체 | Redis 키 패턴 | 용도 | TTL |
|---|---|---|---|
| `OrderPaymentRedisGatewayImpl` | `com.wadiz.api.funding.redis.orderpayment:processing:{tid}` | 결제 중복 처리 방지 락 (`SETNX`) | **5분** |
| `CancelPaymentRedisGatewayImpl` | `payment:waiting` | 결제 취소 가능 시간 확인 (키 존재 여부만 확인) | 외부 배치가 관리 |
| `SimplePayRedisGatewayImpl` | `com.wadiz.api.funding.redis.simplepay:processing:{token}` | 심플페이 진행 중 빌키 매핑 | **5분** |
| `StockKeyValueGatewayImpl` | `{keyPrefix}{rewardId}` 또는 `{keyPrefix}{rewardId}_{rewardOptionId}` | 리워드 재고 증감 카운터 (`INCR`) | **5000밀리초(5초)** — 남은 수명이 0 이하일 때만 다시 건다 |

> 예전 문서가 "타임리프 0 이하일 때 갱신"이라고 적어 뒀는데 잘못된 말입니다.
> 타임리프(Thymeleaf)는 메일 템플릿 도구이고 여기와 아무 상관이 없습니다.
> 실제 동작은 `redis/stock/StockKeyValueGatewayImpl.java:29-33` 입니다.
>
> ```java
> long remainTimeToLive = getTimeToLive(key).orElse(0L);
> if (remainTimeToLive <= 0) {
>   longRedisTemplate.expire(key, STOCK_INVENTORY_TTL, TimeUnit.MILLISECONDS);
> }
> ```
>
> 키의 **남은 수명**을 읽어 0 이하일 때만 5초를 다시 겁니다.
> 그래서 재고를 계속 건드려도 5초마다 한 번은 반드시 만료 후보가 됩니다.

---

## 6. MongoDB 계층

### 6-1. 컬렉션 전수

| `@Document(collection=...)` 이름 | DTO 클래스 | MongoRepository | Gateway 구현체 | 용도 |
|---|---|---|---|---|
| `newsNotificationLog` | `NewsNotificationLogDto` | `NewsNotificationLogMongoRepository` | `NewsNotificationLogGatewayImpl` (`@Async`) | 새소식 알림 발송 이력 |
| `OrderPayMessage` | `OrderPayMessageLogDto` | `OrderPayMessageMongoRepository` | `OrderPayMessageLogGatewayImpl` (`@Async`) | PG 결제 웹훅 메시지 수신 로그 |
| `orderSession` | `OrderSessionLogDto` | `OrderSessionMongoRepository` | `OrderSessionLogGatewayImpl` | 주문 세션 생성 로그 |
| `orderSheet` | `OrderSheetLogDto` | `OrderSheetMongoRepository` | `OrderSheetLogGatewayImpl` | 주문서 생성 로그 |
| `rewardChangeLog` | `RewardChangeLogDto` | `RewardChangeLogMongoRepository` | `RewardChangeLogGatewayImpl` | 리워드 변경 이력 |
| `translationFailureLog` | `TranslationFailureLogDto` | `TranslationFailureLogRepository` | (직접 주입) | 번역 실패 이력 |
| `stripeAccountHistory` | `StripeAccountHistoryDto` | `StripeAccountHistoryMongoRepository` | `StripeAccountHistoryGatewayImpl` | Stripe 계정 상태 변경 이력 — **신규** (`RWD-5311`) |
| `personal_data_destruction_log` | `PersonalDataDestructionLogDto` | `PersonalDataDestructionLogMongoRepository` | `PersonalDataDestructionLogGatewayImpl` | 개인정보 파기 이력 — **신규**. `compliance/` 패키지에 있습니다 |

> 컬렉션 이름 규칙이 하나가 아닙니다.
> 대문자 시작(`OrderPayMessage`), 낙타 표기(`orderSheet`), 밑줄 표기(`personal_data_destruction_log`)가 섞여 있습니다.

### 6-2. 문서 스키마 (필드 이름 수준)

**`newsNotificationLog`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | `@MongoId(FieldType.OBJECT_ID)` |
| `updateId` | Integer | CampaignUpdate PK |
| `tid` | String | 트랜잭션 ID |
| `type` | NotificationType | `EMAIL` / `APP_PUSH` |
| `registered` | LocalDateTime | `@CreatedDate` 자동 생성 |

**`OrderPayMessage`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `payType` | String | `NICE`, `STRIPE`, `ALIPAY` 등 |
| `token` | String | 주문 UUID 문자열 |
| `eventType` | String | SQS 메시지 이벤트 구분 |
| `payload` | `Map<String, String>` | PG 응답 raw 필드 |
| `registered` | LocalDateTime | `@CreatedDate` |

**`orderSession`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `campaignId` | Integer | |
| `userId` | Integer | |
| `token` | String | UUID 문자열 |
| `payload` | String | 세션 JSON raw |
| `registered` | LocalDateTime | `@CreatedDate` |

**`orderSheet`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `oid` | String | orderNo |
| `token` | String | 세션 UUID |
| `payload` | String | 주문서 JSON raw |
| `registered` | LocalDateTime | `@CreatedDate` |

**`rewardChangeLog`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `campaignId` | Integer | |
| `rewardId` | Integer | |
| `rewardName` | String | |
| `changeType` | String | 변경 유형 |
| `beforeData` | String | 변경 전 JSON |
| `afterData` | String | 변경 후 JSON |
| `registerUserId` | Integer | |
| `registered` | LocalDateTime | `@CreatedDate` |

**`translationFailureLog`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `targetType` | TargetType | 번역 대상 유형 |
| `targetId` | Integer | |
| `targetField` | String | 번역 대상 필드명 |
| `translationType` | TranslationType | |
| `languageCode` | String | |
| `command` | String | 번역 요청 raw |
| `resultMessage` | String | 오류 메시지 |
| `registered` | LocalDateTime | `@CreatedDate` |

**`stripeAccountHistory`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `stripeAccountId` | String | Stripe 계정 식별자 |
| `previousStatus` | String | 바뀌기 전 상태 |
| `currentStatus` | String | 바뀐 뒤 상태 |
| `payload` | String | Stripe 가 보낸 원본 |
| `registered` | LocalDateTime | `@CreatedDate` |

**`personal_data_destruction_log`**
| 필드 | 타입 | 비고 |
|---|---|---|
| `_id` | ObjectId | |
| `registeredAt` | LocalDateTime | 파기 시각 |
| `taskType` | String | 파기 작업 종류 |
| `taskSummary` | String | 작업 요약 |
| `taskCount` | int | 파기한 건수 |
| `taskDetail` | `List<TaskDetailDto>` | 표 이름·칼럼 목록·기본키 이름·기본키 값 |
| `registeredBy` | String | 실행한 사람 |
| `registeredIp` | String | 실행한 곳의 IP |

> 파기 기록이 **어떤 표의 어떤 칼럼을 지웠는지까지** 남깁니다.
> 개인정보 파기는 "지웠다"는 사실만으로는 증빙이 안 되기 때문으로 보입니다(추정).
> 코드에 그 이유가 적혀 있지는 않아 추정이라고 밝힙니다.

> ⚠️ **인덱스 서술을 정정합니다.** 예전 문서는 "소스에 `@Indexed`·`@CompoundIndex` 가 없다"고 적었습니다.
> 지금은 `StripeAccountHistoryDto.java:16` 에 복합 인덱스 선언이 있습니다.
>
> ```java
> @CompoundIndex(name = "idx_accountId_registered", def = "{'stripeAccountId': 1, 'registered': -1}")
> ```
>
> 나머지 7개 컬렉션에는 여전히 인덱스 선언이 없습니다. 그쪽은 운영 쪽에서 따로 관리하는 것으로 보입니다(확인 불가).

---

## 7. 이벤트/메시징

### 7-1. AWS SQS 리스너

Kafka 없음. PG 결제 웹훅 수신은 AWS SQS FIFO 큐를 사용한다.

| 리스너 클래스 | 큐 이름 설정 키 | local 값 | 역할 |
|---|---|---|---|
| `OrderPaymentSqsListener` | `application.aws-sqs.queue-name` | `pay-webhook-funding-api-dev.fifo` | PG 웹훅 메시지를 받습니다. MongoDB `OrderPayMessage` 에 남긴 뒤 결제 처리를 부릅니다 |
| `StripeAccountUpdatedSqsListener` | `application.aws-sqs.stripe-account-updated-queue-name` | `dev-stripe-account-updated-webhook.fifo` | **신규.** Stripe 계정 상태 변경 웹훅을 받습니다. 파싱에 실패하면 오류만 남기고 넘어갑니다 |

두 리스너 모두 `adapter/application` 모듈에 있습니다. 인프라 모듈 밖입니다.
둘 다 `deletionPolicy = SqsMessageDeletionPolicy.ON_SUCCESS` 입니다. 정상 처리했을 때만 메시지를 지웁니다.

> **두 리스너는 같은 스위치로 함께 꺼집니다.**
> `@ConditionalOnProperty(name = "application.aws-sqs.listener.enabled", havingValue = "true", matchIfMissing = true)` 입니다.
> 설정이 없으면 켜진 것으로 봅니다. `application-local.yml` 만 `false` 로 둡니다.
> 로컬에서 AWS 자격증명이 없어도 부팅이 실패하지 않게 하려는 장치라고 코드 주석이 적고 있습니다.

### 7-2. Spring ApplicationEvent 발행

`EventDispatcherImpl`이 `ApplicationEventPublisher.publishEvent(event)`를 감싸 도메인에서 이벤트를 발행한다.

### 7-3. Spring `@EventListener` / `@TransactionalEventListener` 핸들러

핸들러 클래스가 **17개**입니다. 그 안에 `@EventListener` 15곳, `@TransactionalEventListener` 18곳이 있습니다.
한 클래스가 여러 이벤트를 받는 경우가 있어 클래스 수와 어노테이션 수가 다릅니다.

새로 들어온 세 개는 모두 `@TransactionalEventListener(phase = AFTER_COMMIT)` 입니다.
데이터베이스 변경이 확정된 뒤에만 바깥으로 알림을 내보내겠다는 뜻입니다.

| 핸들러 클래스 | 이벤트 타입 | 처리 내용 |
|---|---|---|
| `NewsEventHandler` | `CreateNewsEvent`, `ModifyNewsEvent` (`@TransactionalEventListener`), `PostNewsEvent` (`@EventListener`) | 새소식 로그 저장(MySQL), 번역 요청(TranslateClient), 알림 등록 (MySQL) |
| `NewsNotificationEventHandler` | `NewsNotificationEvent` | MongoDB `newsNotificationLog` 비동기 저장 |
| `AnnouncementEventHandler` | 공지 관련 이벤트 4종 | 공지 이력·노출·메뉴 저장 (MySQL) |
| `PaymentCancelLogEventHandler` | 결제 취소 이벤트 2종 (`@EventListener`) | `BackingPaymentCancelLog` 저장 (MySQL) |
| `BrazeNotifyEventHandler` | Braze 알림 이벤트 (`@EventListener`) | `BrazeClient.sendUserTrack(...)` 호출 |
| `MembershipNotifyEventHandler` | 멤버십 혜택 알림 이벤트 | `MembershipApiClient.notifyUseMembershipBenefit(...)` 호출 |
| `ComingSoonApplicantBrazeEventHandler` | ComingSoon 신청·취소 이벤트 2종 | Braze 이벤트 전송 |
| `FollowActivityEventHandler` | 팔로우 활동 이벤트 | `FollowClient.addFollowActivityEvent(...)` 호출 |
| `SignatureTrackingEventHandler` | 서명 이벤트 | `SignatureApiClient` 호출 (외부 서비스, 확인 불가) |
| `StoreOpenEventHandler` | 스토어 오픈 이벤트 | `StoreClient` 또는 내부 처리 (상세 불가) |
| `WishEventHandler` | 찜하기 이벤트 | (상세 불가 — core 내부) |
| `BillkeyEventHandler` | 빌키 이벤트 | (상세 불가) |
| `SimplePayEventHandler` | 심플페이 이벤트 | (상세 불가) |
| `CampaignCongratulationHistoryEventHandler` | 캠페인 달성 축하 이벤트 | `CampaignCongratulationHistoryRepository` 저장 |
| `BillkeyVerifyAfterReservationEventHandler` | `BillkeyVerifyAfterReservationEvent` (`@TransactionalEventListener`) | **신규.** 예약 결제를 잡은 뒤 빌키를 검증합니다 |
| `TranslationEventListener` | `TranslationRequestCompletedEvent` 외 (`@TransactionalEventListener`, 커밋 뒤 실행) | **신규.** 번역이 끝나면 알림톡과 메일로 메이커에게 알립니다 |
| `PackagePlanEventListener` | `PackagePlanBulkChangedEvent` 외 (`@TransactionalEventListener`, 커밋 뒤 실행) | **신규.** 요금제를 한꺼번에 바꾸면 메이커에게 알립니다 |

> `OrderSheetCreateEvent`는 `OrderSheetRedisGatewayImpl` 내 `save()` 호출 시 발행 가능한 이벤트 객체로 정의되어 있으나, 실제 발행 지점은 `funding-core` UseCase 내부이므로 확인 불가.

---

## 8. 메일 템플릿

`resources/templates/mail/` 아래 Thymeleaf HTML 템플릿이 **7개** 있습니다.
그런데 **코드에서 실제로 부르는 것은 3개뿐입니다.**

| 파일명 | 용도 | 코드에서 부르는가 |
|---|---|---|
| `myRewardsSectionKo2.html` | 내 리워드 구간 (한국어) | ✅ `PaymentMailSender.java:129` |
| `myRewardsSectionEn2.html` | 내 리워드 구간 (영문) | ✅ `PaymentMailSender.java:119` |
| `PaymentCancelMyRewardsSectionEn2.html` | 결제 취소 안내의 리워드 구간 (영문) | ✅ `PaymentMailSender.java:71` |
| `myRewardsSectionKo.html` | 위 파일의 예전 판 (한국어) | ❌ 참조 0건 |
| `myRewardsSectionEn.html` | 위 파일의 예전 판 (영문) | ❌ 참조 0건 |
| `PaymentCancelMyRewardsSectionEn.html` | 위 파일의 예전 판 | ❌ 참조 0건 |
| `AchievementRateCongratulationMaker.html` | 달성률 축하 메이커 메일 | ❌ 참조 0건 |

> 🔎 **확인 필요 — 쓰이지 않는 템플릿 4개.**
> 저장소 전체를 `.java`·`.xml`·`.yml`·`.html` 로 훑어도 참조가 나오지 않습니다.
> 이름 끝에 `2` 가 붙은 새 판으로 갈아탄 뒤 옛 판을 안 지운 것으로 보입니다(추정).
> `AchievementRateCongratulationMaker.html` 은 짝이 되는 새 판도 없어 용도가 불분명합니다.
> 원본 저장소는 읽기 전용이라 지우지 않고 기록만 남깁니다.

> 메일 발송은 `NotificationClient` 의 메일 전송 메서드를 거칩니다.
> 템플릿은 `CustomTemplateProcessor.process(...)` 로 HTML 문자열을 만든 뒤
> 발송 요청의 `rewardItemsHtml` 값으로 실려 나갑니다.

---

## 관련 문서

- [`com.wadiz.api.funding.md`](./com.wadiz.api.funding.md) — 레포 개요, 도메인별 API·DB 요약
- [`api-details/payment-flow.md`](./api-details/payment-flow.md) — 결제 승인/취소 상세 SQL
- [`api-details/settlement.md`](./api-details/settlement.md) — ERP 연동 상세
- [`api-details/news-announcement.md`](./api-details/news-announcement.md) — MongoDB newsNotificationLog 상세
- [`api-details/reward.md`](./api-details/reward.md) — rewardChangeLog 상세
- [`api-details/dashboard.md`](./api-details/dashboard.md) — DataPlus 연동 상세
