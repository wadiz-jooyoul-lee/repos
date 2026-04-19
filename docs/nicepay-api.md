# nicepay-api 분석

## 개요

nicepay-api는 와디즈의 **결제 대외계 API 게이트웨이**로, 국내/해외 여러 PG(나이스페이, Stripe, Alipay+)를 단일 REST 인터페이스 뒤로 통합한다. 풀 리액티브(Spring WebFlux + R2DBC + Reactive Mongo)로 구현되어 있으며, PG별 결제 플로우(인증결제/빌링/예약결제/웹훅)를 서비스 타입(ServiceType) 단위로 분기한다.

지원 결제(README 기준):
1. 인증결제 x 나이스페이 (카드, 카카오페이/애플페이/네이버페이/토스페이)
2. 해외카드 즉시결제 (나이스페이) — FUNDING_GLOBAL_AUTH, FUNDING_EC_GLOBAL_AUTH
3. 스토어파트너 즉시/예약결제 (나이스페이) — STORE_PARTNER_AUTH, STORE_PARTNER_SCHEDULED
4. Stripe 카드 즉시/예약결제 — GLOBAL_STRIPE_FUNDING, GLOBAL_STRIPE_PREORDER
5. Alipay+ 즉시결제 (나이스페이 Alipay+) — GLOBAL_ALIPAY_FUNDING, GLOBAL_ALIPAY_PREORDER

핵심 배경지식:
- "인증결제"는 나이스페이 용어로 카드 인증 후 서버에서 승인(authApproval)하는 플로우.
- "빌링"은 Billkey(BID)를 이용한 저장 카드 결제.
- "예약결제"는 Stripe SetupIntent → 추후 off-session PaymentIntent로 청구하는 플로우.
- PG와의 통신은 **나이스페이는 form-urlencoded(EUC-KR)**, **Stripe는 공식 Java SDK(동기)**, **Alipay+는 나이스페이를 경유**.

## 기술 스택

| 영역 | 스택 |
|------|------|
| 언어/런타임 | Java 17 (sourceCompatibility=17), JDK 17 |
| 프레임워크 | Spring Boot 3.0.2 |
| 빌드 | Gradle + jib 3.3.1 (Docker 이미지) |
| HTTP 서버 | Spring WebFlux (Reactor Netty) |
| PG SDK | com.stripe:stripe-java:28.4.0 (Stripe용, 동기 SDK를 Mono.fromCallable로 감쌈) |
| DB | **R2DBC** (MySQL via dev.miku:r2dbc-mysql:0.8.2.RELEASE) + **Reactive Mongo** (spring-boot-starter-data-mongodb-reactive) |
| 이벤트 | **RabbitMQ** via spring-cloud-stream-binder-rabbit + StreamBridge; AWS SQS(software.amazon.awssdk:sqs:2.31.78) — 웹훅 경로 전용 |
| Config | Spring Cloud Kubernetes Client Config + Bootstrap |
| Validation | spring-boot-starter-validation 3.0.1 |
| 매퍼 | MapStruct 1.5.3.Final + Lombok |
| 뷰 | Spring Boot FreeMarker (로컬/데모 페이지: alipay.ftl, stripeCard.ftl) |
| API 문서 | springdoc-openapi-starter-webflux-ui 2.2.0 |
| 배포 | Jib → Docker (eclipse-temurin:17 base) |

추가 특이:
- 테스트: rest-assured 5.3.0, spring-cloud-stream-test-binder, mockwebserver, reactor-test.
- macOS 개발자 환경을 위해 netty-resolver-dns-native-macos 런타임 의존 조건 추가(build.gradle:90-97).

## 아키텍처

패키지 루트: `kr.wadiz.platform.api.nicepay`

```
config/      WebClientConfig(멀티 WebClient 빈), WadizConfig(service mid/merchantKey 맵), StripeConfig(accounts 리스트), WebConfig
controller/  AuthController, BillingController, BillkeyController, ReserveController, TransactionController, WebhookController, InterestController, InstallmentGuideController, FreeController(로컬 데모), ReserveResponseHandler
service/     AuthService, BillingService, BillkeyService, StripeService, StripeClient, TransactionService, InterestService, InstallmentGuideService
model/       Response(공통 응답), AuthApproval/AuthCancel/BillingApproval/... (로그 이벤트 DTO), StripeAccount, CardDetails
  dto/        *Dto Request/Response pair 묶음 (중첩 static class 패턴)
  entity/     Billkey (R2DBC @Table), CardEntity (R2DBC @Table user_cards)
repository/   BillkeyRepository, CardRepository (ReactiveCrudRepository/R2dbcRepository)
publisher/    LogPublisher (StreamBridge로 RabbitMQ 발행)
advice/       CommonAdvice (@RestControllerAdvice - 글로벌 예외처리)
mapper/       MapStruct 매퍼
enums/        ApiVersion, ServiceType, CurrencyCode, ResultCode, ApprovalStatus 등 + EnumValidator(커스텀 @Valid)
util/         AuthDataFormatter (SHA-256 signData, AES encData, tid 생성), DateFormatUtils
exceptions/   도메인 예외
```

### 리액티브 체인 패턴

모든 서비스가 `Mono<Response>`를 반환. 컨트롤러가 직접 `Mono`를 return하거나, `ReserveResponseHandler.handle(...)`(Stripe 계열 공통 래퍼)로 감싸서 로그 발행/에러 복구/ResponseEntity 변환을 한 번에 처리한다(`ReserveResponseHandler.java:36-107`).

WebClient 용도별 분리(`WebClientConfig.java`):
- `billingWebClient` — 나이스페이 빌링 API (EUC-KR)
- `authWebClient` — 나이스페이 인증결제 (EUC-KR, SSL custom, 최대 500 커넥션, 풀타임아웃 세팅)
- `interestWebClient` — 나이스페이 무이자 조회 API
- `wadizApiWebClient` — 와디즈 내부 funding API 콜백용

### 이벤트 발행 — RabbitMQ via StreamBridge

`LogPublisher.java:20`가 Spring Cloud Stream `StreamBridge`로 8개 출력 바인딩에 메시지 발행:
- billkeyRegister-out-0, billkeyRemove-out-0, billingApproval-out-0, billingCancel-out-0
- authApproval-out-0, authCancel-out-0, transactionStatus-out-0
- reserveTransaction-out-0 (예약결제 공통 — status 헤더 기반 헤더 익스체인지)

모든 메서드가 `@Async`이므로 호출 스레드 블로킹 없이 발행.

### 웹훅 경로 — AWS SQS/SNS (별도 pipeline)

`aws/infra/main.tf`에 SNS + 2개 SQS(FIFO 아님) 구성:
- `pay-webhook-sns` → `pay-webhook-api-funding-queue`(API용), `pay-webhook-db-queue`(DB 저장용)
- `aws/lambda/lambda_msg2sns.py`, `lambda_sqs2db.py` Lambda가 나이스페이 Alipay+ 웹훅을 EUC-KR 디코딩 후 SNS로 변환, SQS로부터 MongoDB에 적재.

## API 엔드포인트 목록

webflux.base-path는 dev/local: `/nicepay-api`. 아래 Path는 controller annotation 기준(실제 호출 시 base-path prefix 추가).

| Method | Path | Controller.method | 용도 |
|--------|------|-------------------|------|
| POST | /api/v2/auth/init, /api/v2/auth/init/{payType}, /api/v2/auth/init/{payType}/{payMethod} | AuthController.authInit (AuthController.java:31) | 인증결제 init(간편결제 파라미터 생성: kakaopay/applepay/naverpay/tosspay/alipay/card) |
| POST | /api/v2/auth/approval, /api/v2/auth/approval/{payType} | AuthController.approval (AuthController.java:46) | 인증결제 승인 — 나이스페이 /pay_process.jsp 호출 |
| POST | /api/v2/auth/cancel, /api/v2/auth/cancel/{payType} | AuthController.cancel (AuthController.java:64) | 인증결제 취소 — 나이스페이 /cancel_process.jsp |
| POST | /api/v2/auth/transactions/{tid}/status | TransactionController.transactionStatus (TransactionController.java:19) | 거래 상태 조회 — 나이스페이 /inquery/trans_status.jsp |
| POST | /api/{apiVersion}/billkey | BillkeyController.registBillkey (BillkeyController.java:20) | 빌키 등록 (v1/v2) — 나이스페이 /billing/billing_regist.jsp |
| DELETE | /api/{apiVersion}/billkey | BillkeyController.removeBillkey (BillkeyController.java:26) | 빌키 제거 — 나이스페이 /billing/billkey_remove.jsp |
| POST | /api/{apiVersion}/approval | BillingController.approval (BillingController.java:24) | 빌링 결제 승인 — 나이스페이 /billing/billing_approve.jsp |
| POST | /api/{apiVersion}/cancel | BillingController.cancel (BillingController.java:30) | 빌링 결제 취소 — 나이스페이 /cancel_process.jsp |
| POST | /tid | BillingController.tid (BillingController.java:36) | TID 생성기 디버깅용(10000건 로그) — 운영 비권장 |
| POST | /api/v2/reserve/setup | ReserveController.setup (ReserveController.java:27) | Stripe SetupIntent 생성(예약결제 사전 세팅) |
| POST | /api/v2/reserve/approval | ReserveController.approval (ReserveController.java:38) | Stripe PaymentIntent 생성(예약결제 승인, off_session) |
| POST | /api/v2/reserve/cancel | ReserveController.cancel (ReserveController.java:48) | Stripe Refund (결제 환불) |
| POST | /api/v2/reserve/cancel-intent | ReserveController.cancelIntent (ReserveController.java:58) | Stripe PaymentIntent cancel (승인 전/후 취소) |
| POST | /api/v2/webhook/stripe/{accountName} | WebhookController.handleStripeWebhook (WebhookController.java:26) | Stripe 웹훅(setup_intent.succeeded 처리) |
| GET | /interest/free | InterestController.getInterestFree (InterestController.java:18) | 무이자 전체 조회 |
| GET | /interest/part | InterestController.getInterestPart (InterestController.java:23) | 카드별 부분 무이자 조회 |
| GET | /interest/part/all | InterestController.getInterestPartAll (InterestController.java:28) | 부분 무이자 전체 조회 |
| GET | /v2/installment-guides/{search} | InstallmentGuideController.getInstallmentGuide (InstallmentGuideController.java:19) | 할부 안내 조회 |
| GET | /alipay | FreeController.alipay (FreeController.java:18) | (local/dev only) Alipay 데모 페이지 |
| GET/POST | /alipayApproved | FreeController.alipayApproved/Return (FreeController.java:32,46) | (local/dev only) Alipay 완료 페이지 |
| GET | /stripe | FreeController.stripe (FreeController.java:60) | (local/dev only) Stripe 테스트 페이지 |

## 주요 API 상세 분석

### 1. POST /api/v2/auth/init/{payType}[/{payMethod}] — 인증결제 init

- 컨트롤러 path:line: AuthController.java:31
- 입력 DTO AuthInitDto.Request: serviceType(ServiceType enum 검증), goodsName, amt, moid, buyerName/Email/Tel, rcptType/No/NoType(네이버페이 포인트 현금영수증용), userId
- 처리 로직 (AuthService.java:48-236):
  1. WadizConfig.service[serviceType.lowerCase]에서 mid/merchantKey/card/quota 조회
  2. goodsName을 EUC-KR 39바이트로 잘라냄(subStringBytes, 한글 2바이트)
  3. payType 분기(applepay/kakaopay/naverpay/naverpay-point/alipay/tosspay/card)별로 AuthInit*Response 빌드
  4. signData = SHA-256(ediDate + mid + amt + merchantKey)를 AuthDataFormatter.signData로 생성
  5. Mono.just(Response)로 즉시 반환 (외부 호출 없음, 클라이언트 제출용 파라미터 생성 용도)
- DB: 없음
- 외부 연동: 없음 (클라이언트가 이 파라미터로 NICEPAY JS 호출)

### 2. POST /api/v2/auth/approval/{payType} — 인증결제 승인

- 컨트롤러 path:line: AuthController.java:46
- 입력 DTO AuthApprovalDto.Request (AuthApprovalDto.java:20):
  - serviceType, AuthResultCode, AuthResultMsg, AuthToken, PayMethod, MID, Moid, Signature, Amt(@Min 100), TxTid
- 처리 로직 (AuthService.java:262-299):
  1. authResultCode != "0000"이면 즉시 AUTH_APPROVAL_FAIL 응답
  2. verifyApprovalRequest — hex(SHA-256(AuthToken+MID+Amt+MerchantKey)) 와 request.Signature 대조
  3. form-urlencoded 페이로드 구성(TID/Amt/AuthToken/MID/EdiDate/SignData)
  4. **authWebClient**로 나이스페이 `/pay_process.jsp` POST (WebClient + BodyInserters.fromFormData)
  5. AuthApprovalDto.Response를 받아 authApprovalConvertResponse에서 resultCode 매핑 + LogPublisher.sendAuthApproval로 RabbitMQ authApproval-out-0 발행
  6. 간편결제구분(clickpayCl: 16/20/22/25) 값에 따라 kakaopay/naverpay/applepay/tosspay 문자열로 가공(ResponseWrapper)
- 외부 연동: 나이스페이 `https://webapi.nicepay.co.kr/webapi/pay_process.jsp`
- DB: 없음 (BillkeyRepository는 건드리지 않음)
- 이벤트: RabbitMQ `nicepay.authApproval.{env}` exchange(topic)

### 3. POST /api/v2/auth/cancel/{payType} — 인증결제 취소

- 컨트롤러 path:line: AuthController.java:64
- 입력 DTO AuthCancelDto.Request: serviceType, tid, moid, amt, cancelMsg, isPartialCancel, userId
- 처리 로직 (AuthService.java:436-483):
  1. form: TID/MID/Moid/CancelAmt/CancelMsg/PartialCancelCode/EdiDate/SignData
  2. signData = SHA-256(mid + amt + ediDate + merchantKey)
  3. authWebClient → 나이스페이 `/cancel_process.jsp`
  4. 성공 코드 `2001` 시 ResponseWrapper 변환(cancelDateTime yyMMddHHmmss) + LogPublisher.sendAuthCancel 발행
- 외부 연동: 나이스페이 cancel_process.jsp

### 4. POST /api/{apiVersion}/approval — 빌링 결제 승인 (빌키 기반)

- 컨트롤러 path:line: BillingController.java:24
- 입력 DTO BillingApprovalDto.Request (BillingApprovalDto.java:14): userId, serviceName, productId, billkeyId, bid, moid, amt, goodsName, cardInterest, cardQuota, cardPoint
- 처리 로직 (BillingService.java:45-128):
  1. apiVersion이 v1이면 request.bid를 그대로 사용, v2이면 `billkeyService.getBillkey(billkeyId)` — **R2DBC로 MySQL billkey 테이블 조회** — 후 bid 채움
  2. WadizConfig.service["funding"]에서 mid/merchantKey 조회
  3. tid = AuthDataFormatter.getTid(mid, "01", "16")
  4. signData = SHA-256(mid + ediDate + moid + amt + bid + merchantKey)
  5. **billingWebClient** (EUC-KR) → 나이스페이 `/billing/billing_approve.jsp`
  6. 성공 코드 `3001` 매핑 + RabbitMQ billingApproval-out-0 발행
- 외부 연동: 나이스페이 billing_approve.jsp
- DB: `billkey` 테이블 SELECT (BillkeyRepository.findById → R2DBC)

### 5. POST /api/{apiVersion}/billkey — 빌키 등록

- 컨트롤러 path:line: BillkeyController.java:20
- 입력 DTO BillkeyRegisterDto.Request: serviceType, cardNo, expYear, expMonth, idNo, cardPw
- 처리 로직 (BillkeyService.java:51-128):
  1. encData = "CardNo=.&ExpYear=.&ExpMonth=.&IDNo=.&CardPw=." 를 AuthDataFormatter.encData(merchantKey)로 암호화
  2. signData = SHA-256(mid + ediDate + MOID + merchantKey)
  3. billingWebClient → 나이스페이 `/billing/billing_regist.jsp`
  4. 성공 코드 `F100` 시 cardPw null로 마스킹 후 LogPublisher.sendBillkeyRegister
  - NOTE: 현재 코드에는 성공 시 billkey를 **DB에 persist하는 로직이 명시적이지 않음** (BillkeyRepository.save 호출 없음). 별도 와디즈 내부 시스템에서 RabbitMQ 이벤트 소비 후 저장하는 것으로 추정.

### 6. DELETE /api/{apiVersion}/billkey — 빌키 제거

- 컨트롤러 path:line: BillkeyController.java:26
- 입력 DTO BillkeyRemoveDto.Request: billkeyId, serviceName 등
- 처리 로직 (BillkeyService.java:130-175):
  1. `billkeyRepository.findById(billkeyId)` (R2DBC, MySQL `billkey`) → Mono<Billkey>
  2. 존재 시 request.bid 채워서 나이스페이 `/billing/billkey_remove.jsp` 호출
  3. 성공 코드 `F101` 시 `billkeyRepository.delete(billkey).subscribe()` — **Mono 체인 밖 subscribe로 fire-and-forget 삭제** — 이 방식은 DB 실패 시 로그만 남김
  4. RabbitMQ billkeyRemove-out-0 발행

### 7. POST /api/v2/reserve/setup — Stripe SetupIntent 생성 (예약결제)

- 컨트롤러 path:line: ReserveController.java:27
- 입력 DTO ReserveSetupDto.Request (ReserveSetupDto.java:14): serviceType(GLOBAL_STRIPE_FUNDING/PREORDER), userId
- 처리 로직 (StripeService.java:72-90):
  1. `stripeClient.getAccount(serviceType)` — StripeConfig의 accounts 리스트에서 serviceType으로 매칭된 StripeAccount(secretKey/publicKey/webhookKey) 선택
  2. `cardRepository.findByUserIdAndServiceType(userId, serviceType)` — **R2DBC MySQL `user_cards` 테이블에서 기존 Customer 조회**
  3. 없으면 `stripeClient.createCustomer(userId, apiKey)` → user_cards 저장(`saveCard`) — Mono.fromCallable(Customer.create(...)).subscribeOn(stripe-pool) 블로킹 오프로드
  4. `stripeClient.createSetupIntent(customerId, apiKey)` — SetupIntentCreateParams.Usage.OFF_SESSION, paymentMethodType=card
  5. 응답: clientSecret(orderKey)과 publicKey(pgKey) 반환 → FE에서 Stripe.js로 SetupIntent 확정
- 외부 연동: **Stripe Java SDK 동기 호출**을 Mono.fromCallable + subscribeOn(Schedulers.newBoundedElastic(10,100,"stripe-pool"))로 비동기화(StripeClient.java:36-39)
- DB: user_cards SELECT/INSERT
- 이벤트: ReserveResponseHandler.handle 내부에서 `reserveTransaction-out-0` 헤더 익스체인지로 url/status/data/request 발행(LogPublisher.sendTransaction)

### 8. POST /api/v2/reserve/approval — Stripe PaymentIntent (예약결제 청구)

- 컨트롤러 path:line: ReserveController.java:38
- 입력 DTO ReserveApprovalDto.Request: serviceType, userId, amount, billKey(= SetupIntent ID), moid, signature
- 처리 로직 (StripeService.java:92-121):
  1. `stripeClient.retrieveSetupIntent(setupIntentId, secretKey)` — SetupIntent.paymentMethod 획득
  2. `stripeClient.createPaymentIntent(paymentMethodId, amount, moid, signature, secretKey)` (StripeClient.java:123-169):
     - idempotencyKey = `paymentMethodId-moid-(signature || yyyyMMddHHmm10분단위)`
     - PaymentMethod.retrieve로 customerId 확인 후 PaymentIntentCreateParams currency=krw, setOffSession(true), setConfirm(true)
  3. 응답: resultCode=paymentIntent.status, tid=paymentIntent.id, amount
- 외부 연동: Stripe `/v1/setup_intents/{id}`, `/v1/payment_intents`
- DB: 없음 (customer/card는 이미 저장됨)

### 9. POST /api/v2/reserve/cancel — Stripe Refund (환불)

- 컨트롤러 path:line: ReserveController.java:48
- 입력 DTO ReserveCancelDto.Request: serviceType, tid(PaymentIntent ID), amount, moid
- 처리 로직 (StripeService.java:123-146):
  1. `stripeClient.createRefund(paymentIntentId, amount, moid, secretKey)` — RefundCreateParams(paymentIntent, amount)
  - 주의: 부분취소에 대비해 idempotencyKey를 설정하지 않음(주석 명시)
- 외부 연동: Stripe `/v1/refunds`

### 10. POST /api/v2/reserve/cancel-intent — PaymentIntent 직접 cancel

- 컨트롤러 path:line: ReserveController.java:58
- 처리: PaymentIntent.retrieve → paymentIntent.cancel(options) (StripeService.java:148-165, StripeClient.java:199-215) — 승인된 PaymentIntent를 capture 전 취소 케이스

### 11. POST /api/v2/webhook/stripe/{accountName} — Stripe Webhook

- 컨트롤러 path:line: WebhookController.java:26
- 입력: `@RequestHeader("Stripe-Signature")` + body(String)
- 처리 로직:
  1. `stripeService.verifyStripeSignature(payload, sigHeader, accountName)` (StripeService.java:174-204) — `Webhook.constructEvent(payload, sigHeader, stripeAccount.webhookKey)` — stripe.skip-signature-verification=true면 검증 생략하고 GSON으로 파싱
  2. `stripeService.processStripeEvent(event, accountName)` — `setup_intent.succeeded`만 처리, 그 외는 "Webhook received but not processed"
  3. setup_intent.succeeded 처리(StripeService.java:222-277):
     - SetupIntent.customerId로 `cardRepository.findByCustomerIdAndServiceType` 조회
     - `stripeClient.getCardDetails(paymentMethodId)` — Stripe PaymentMethod 카드 정보
     - 와디즈 funding-api `/api/internal/payments/card-registration`에 카드 등록 요청(wadizApiWebClient, 404/커넥션 에러 재시도 3회 backoff 3s + jitter 0.5)
     - 응답 isCardValid=true면 비동기로 `verifyCardWithManualCapture` — $0.5 PaymentIntent 생성 → `/billkey-verifications`에 APPROVAL 통지 → 즉시 cancel → APPROVAL_CANCEL 통지 (Schedulers.boundedElastic에서 별도 실행)
     - 모든 결과를 ReactiveMongoTemplate.insert로 `stripeWebhookLogs` Mongo 컬렉션에 로그(5s 타임아웃 + Mongo 예외 재시도)
- 외부 연동:
  - Stripe: PaymentMethod.retrieve, PaymentIntent.create/retrieve/cancel
  - 와디즈 funding-api: `/api/internal/payments/card-registration`, `/api/internal/payments/billkey-verifications`, `/api/internal/payments/extra-info`
- DB: R2DBC `user_cards` SELECT + Reactive Mongo `stripeWebhookLogs` INSERT

### 12. POST /api/v2/auth/transactions/{tid}/status — 거래 상태 조회

- 컨트롤러 path:line: TransactionController.java:19
- 처리 (TransactionService.java:35-56):
  1. signData = SHA-256(tid + mid + ediDate + merchantKey)
  2. authWebClient → 나이스페이 `/inquery/trans_status.jsp`
  3. status: 0(승인), 1(취소), 9(승인거래없음)로 매핑 + RabbitMQ transactionStatus-out-0 발행

## DB 스키마 요약

### MySQL (wadiz_payment / wadiz_payment_dev) via R2DBC

| Table | Entity(`@Table`) | 주요 컬럼 | 용도 |
|-------|------------------|-----------|------|
| `billkey` | Billkey (`model/entity/Billkey.java:15`, R2DBC) | id(PK), bid, user_id, card_no, exp_year, exp_month, auth_date, card_code, card_name, created_date, last_modified_date. INDEX(user_id, card_no) | 나이스페이 빌키(BID) 저장. schema.sql에 DDL 명시. |
| `user_cards` | CardEntity (`model/entity/CardEntity.java:19`, R2DBC) | user_cards_no(PK), user_id, service_type, mid, stripe_customer_id, bill_key, card_company_name, last_numbers, registered_at, updated_at | Stripe customer/card 및 나이스페이 빌키 공용 저장(@2025.05.27 신규). BillkeyRepository와는 별도로 사용. |

R2DBC 쿼리 메서드:
- BillkeyRepository: `findByUserIdAndCardNo(Integer userId, String cardNo)` + 기본 CRUD (`ReactiveCrudRepository`)
- CardRepository: `findByUserIdAndServiceType`, `findByCustomerIdAndServiceType` (`R2dbcRepository`)

### MongoDB (payment_nicepay_dev 등) via Reactive Mongo

명시적인 `@Document` 엔티티는 없음. 대신 `ReactiveMongoTemplate.insert(Document, "stripeWebhookLogs")`로 raw Document 사용(StripeService.java:438).

| Collection | 스키마(runtime Document) | 용도 |
|-----------|-------------------------|------|
| `stripeWebhookLogs` | type, accountName, userId, paymentMethodId, setupIntentId, customerId, cardExpireMonth/Year, isCardValid, retryCount, lastRetryError, createdAt | Stripe `setup_intent.succeeded` 웹훅 처리 결과 감사 로그 |

이외 Alipay+ 웹훅은 `aws/lambda/lambda_sqs2db.py`가 자체적으로 MongoDB에 적재(별도 프로비저닝).

## 외부 의존성

### 결제 파트너

| 파트너 | 엔드포인트 | 호출 방식 |
|--------|-----------|-----------|
| **나이스페이 빌링** | https://webapi.nicepay.co.kr/webapi/billing/billing_regist.jsp, /billing_approve.jsp, /billkey_remove.jsp | WebClient billingWebClient, form-urlencoded, EUC-KR |
| **나이스페이 인증결제** | https://webapi.nicepay.co.kr/webapi/pay_process.jsp, /cancel_process.jsp, /inquery/trans_status.jsp | WebClient authWebClient (SSL custom, 최대 500 conn, form-urlencoded, EUC-KR) |
| **나이스페이 무이자** | https://data.nicepay.co.kr/mi/api/ | interestWebClient |
| **Stripe** | /v1/customers, /v1/setup_intents, /v1/payment_intents, /v1/payment_methods, /v1/refunds | stripe-java 28.4.0 **동기 SDK**를 Mono.fromCallable(...).subscribeOn(stripe-pool bounded elastic 10..100) (StripeClient.java:36-84) |
| **Stripe Webhook** | 수신 `/api/v2/webhook/stripe/{accountName}` → Webhook.constructEvent | WebhookController |
| **Alipay+** | 나이스페이 Alipay+ 채널로 경유(별도 AWS Lambda가 웹훅 처리 후 SNS/SQS/Mongo로 집계) | aws/lambda/lambda_msg2sns.py, lambda_sqs2db.py |
| **와디즈 funding-api** | http://dev-gateway.wadiz.kr/funding/ (local), `/api/internal/payments/card-registration`, `/billkey-verifications`, `/extra-info` | wadizApiWebClient (pool 50, read 30s, response 60s, keep-alive) |

### 이벤트 브로커

**RabbitMQ** (Spring Cloud Stream - 결제 로그 파이프라인):
- 호스트 설정: `rabbitmq-main.wadizcorp.net:5672`
- Destination(topic exchange): `nicepay.billkeyRegister.{env}`, `nicepay.billkeyRemove.{env}`, `nicepay.billingApproval.{env}`, `nicepay.billingCancel.{env}`, `nicepay.authApproval.{env}`, `nicepay.authCancel.{env}`, `nicepay.transactionStatus.{env}`
- Destination(headers exchange): `pay.reserveTransaction.{env}` (status 헤더 기반 라우팅)
- 발행 방향만 존재(`*-out-0`). 구독은 타 서비스(예: `com.wadiz.api.funding` 등)가 담당.

**AWS SNS/SQS** (Alipay+ 웹훅 라인, nicepay-api JVM과는 별개):
- SNS Topic: `pay-webhook-sns`
- SQS: `pay-webhook-api-funding-queue`(retention 86400s), `pay-webhook-db-queue`(retention 86400s)
- Lambda가 나이스페이의 form-url-encoded(EUC-KR) 웹훅을 EUC-KR 디코딩 → JSON → SNS publish → SQS fan-out → MongoDB 저장 / funding-api 호출

nicepay-api 자체 코드에는 SQS SDK 의존성은 포함되지만(software.amazon.awssdk:sqs:2.31.78) 본체에서 SQS를 직접 send/receive하는 흐름은 확인되지 않음 — 주로 Lambda 파이프라인 결과를 nicepay-api가 webhook 엔드포인트로 받는 형태.

### 예약결제 스케줄러, DLQ

- 예약결제 자체 스케줄러는 없음. Stripe SetupIntent(저장된 결제수단)로 후속 off_session PaymentIntent를 필요 시 호출하는 API 모델. 주기 청구 트리거는 상위 시스템(funding-api 등)이 담당.
- DLQ는 RabbitMQ 바인딩에 명시되어 있지 않음(현재 yml). 재처리는 nicepay-api 범위 밖(Lambda/타 서비스)에서 관리.

### 인프라/설정

- Kubernetes ConfigMap (`spring-cloud-starter-kubernetes-client-config` + `bootstrap.yml`, `bootstrap-kubernetes.yml`): ENV별 설정 주입.
- Jib Docker 이미지(eclipse-temurin:17, format=OCI, mainClass=NicepayApiApplication).
- EKS 배포: dev eks-svc-dev-0609, rc eks-svc-rc-0604, live eks-svc-live-1019 (README 기준).

## 특이사항

### WebFlux 리액티브 체인 + Stripe 동기 SDK 블로킹 격리

- Stripe Java SDK(28.4.0)는 blocking 동기 API이다. `StripeClient`는 모든 호출을 `Mono.fromCallable(() -> Stripe 호출).subscribeOn(STRIPE_SCHEDULER)` 패턴으로 감싸서 리액티브 체인에 끼워 넣는다(StripeClient.java:71-215).
- `STRIPE_SCHEDULER`는 커스텀 bounded elastic 풀(초기 10 / 최대 100 / 이름 "stripe-pool", StripeClient.java:36-39)로, 공용 `Schedulers.boundedElastic()`와 분리해 Stripe 호출 포화가 다른 IO에 영향주지 않도록 격리.
- 일부 Stripe 호출(`getCardDetails`, StripeClient.java:229-244)은 subscribeOn 누락 — 기본 스레드에서 실행되므로 블로킹 주의. (잠재 개선 포인트)
- Stripe Webhook 처리 중 `verifyCardWithManualCapture`는 메인 플로우를 막지 않도록 `.subscribeOn(Schedulers.boundedElastic()).subscribe(...)`로 fire-and-forget 호출(StripeService.java:406-412) — 외부 호출 결과가 webhook 응답 지연에 영향주지 않도록 의도.

### Reactive 체인 스타일

- 모든 서비스 메서드 반환 타입이 `Mono<T>` (또는 `Mono<Response>`). flatMap/map 체이닝 일관.
- 예외 상황 일부는 `Mono.error(new RuntimeException(...))` 로 올리고, `ReserveResponseHandler.onErrorResume`이 StripeException을 200 OK + errorCode로 전환(클라이언트에 상세 코드 전달 목적, ReserveResponseHandler.java:81-95).
- BillkeyService.removeBillkey의 `billkeyRepository.delete(billkey).subscribe()`는 reactive 체인에서 분리된 subscribe — 실패 시 로그만 남고 상위 호출은 성공 응답 (BillkeyService.java:144)이라 간헐적 불일치 위험.

### 이중 DB 체계: R2DBC + Reactive Mongo

- R2DBC(MySQL)는 거래 정합성이 필요한 billkey/user_cards(카드 customer ID).
- Reactive Mongo는 Stripe 웹훅 감사 로그(`stripeWebhookLogs`) 같은 비정형/대용량 로그용.
- 트랜잭션 통합은 하지 않음(리액티브 XA 미지원).

### ServiceType으로 멀티 PG/멀티 가맹점 선택

- `ServiceType` enum(ServiceType.java:6-31)이 서비스별 MID/MerchantKey 매핑 키. WadizConfig.service 맵에서 runtime 조회.
- Stripe 계정도 동일 ServiceType 단위로 구분(StripeConfig.accounts 리스트). `GLOBAL_STRIPE_FUNDING`, `GLOBAL_STRIPE_PREORDER` 두 개가 각자 secretKey/publicKey/webhookKey 보유.
- 한 프로세스가 여러 가맹점(funding, store_auth, funding_global_auth 등 12+개)을 동시 서비스.

### 암호화/서명 유틸 (AuthDataFormatter)

- `signData`: SHA-256 hex
- `encData`: (AES 기반 추정) merchantKey를 키로 카드 정보 암호화 — 나이스페이 v1 프로토콜 호환
- `getTid`: MID + "01"(승인) + "16"(결제수단) + 시퀀스로 20자리 TID 생성

### 로컬/개발 데모 컨트롤러

- `FreeController`(FreeController.java:14)는 `@Profile({"local", "dev"})` 전용. Alipay/Stripe 데모 페이지(FreeMarker ftl)를 로컬에서 렌더링.

### 운영 이슈/주의점

- application-local.yml에 실제 키로 보이는 secretKey/webhookKey/merchantKey가 하드코딩 돼 있음 — live 배포 전 반드시 ConfigMap/Secrets로 교체 필요.
- `BillingController./tid` 엔드포인트는 10000회 TID 로그를 남김(BillingController.java:36) — 디버깅 목적으로 추정되나 운영 배포 시 제거 권장.
- `stripe.skip-signature-verification: true`가 local에서 활성 — 운영에서는 false로 보장 필요(StripeService.verifyStripeSignature가 이 플래그 체크).
- `BillkeyRepository.findById`는 v2 빌링 승인 경로에서 매 요청마다 발생 — R2DBC 풀(initial 50, max 100)로 대비하지만, billkey ID 자체를 클라이언트가 알아야 하는 구조라 캐시 없이 매번 조회 수행.
- `CardRepository.findByCustomerIdAndServiceType`는 Stripe Webhook 처리 hot path에서 동기적으로 호출되며, Stripe 외부 호출 뒤에 있어 latency 누적.

### 엔진별 주목할 코드 위치

- Stripe SDK 블로킹 격리: StripeClient.java:36-39(스케줄러), 71-84(createCustomer), 86-109(createSetupIntent), 123-169(createPaymentIntent), 171-197(createRefund), 199-215(cancelPaymentIntent)
- EUC-KR 처리: WebClientConfig.java:57-95(authWebClient SSL/EUC-KR), BillingService/BillkeyService에서 `Accept-Charset: EUC-KR` 헤더
- 내부 와디즈 API 콜백: StripeService.java:347-363 (updateVerificationStatus — funding-api 호출)
- 이벤트 발행 집중: publisher/LogPublisher.java — 8개 바인딩 모두 StreamBridge 기반 RabbitMQ 발행
