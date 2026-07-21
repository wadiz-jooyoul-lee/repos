# co.wadiz.fep 분석

> 📅 **2026-07-21 main pull 보강** (1 커밋)
>
> ### SCOUT-111 — DLQ 재처리 payload 형식 정합 (버그수정)
> - **`agent/scheduler/DlqReprocessScheduler.java`** — DLQ 실패 메시지를 원본 큐에 재투입할 때 **동일한 형식의 payload**를 넣도록 수정. (아래 SCOUT-79 블록의 `DlqReprocessScheduler` DLQ 재처리 흐름의 후속 버그픽스.) 로컬 검증 테스트 `DlqReprocessSchedulerLocalTest` 추가.
>
> ---
>
> 📅 **2026-07-10 main pull 보강** (36 커밋, net-new)
>
> 이번 구간의 핵심은 **SCOUT-79** — FEP가 "Stripe Connect 정산 중계"에서 **PG 결제 실시간 대사(webhook 수신→중복판정→SNS 발행) 게이트웨이**로 확장되고, 저장소·재처리 인프라가 통째로 교체됨. 아래 서술 중 기존 본문(MongoDB / Batch 모듈 / API Key 인증 필터)과 충돌하는 부분은 **이 블록이 최신**이다.
>
> ### SCOUT-79 — PG 결제 실시간 대사 웹훅 도입 (net-new 핵심)
> - **`adapter/in/web/NicePayWebhookController.java:54`** — `POST /api/v1/webhooks/nicepay/payment` 신규. NICEPAY v1 통보(form-urlencoded)를 `@RequestBody` 대신 `request.getInputStream()`로 원본 바이트를 직접 읽어 **EUC-KR 디코딩**(`NicePayWebhookController.java:61,92`, charset은 `nicepay.webhook.request-charset:EUC-KR`). `@RequestBody`가 form 파라미터를 UTF-8로 재인코딩해 한글이 깨지는 문제를 우회(클래스 주석 :21-33).
> - **`adapter/in/web/StripeWebhookController.java:47`** — Stripe 웹훅이 `POST /api/v1/webhooks/stripe/account`(계정)와 `.../stripe/payment`(결제) 2갈래로 분리. 결제 웹훅은 `verifyPayment` 서명 검증 후 `StripeEventMapper.mapToEvent`로 매핑.
> - **`domain/PgPaymentEvent.java:9` / `PgPaymentStatus.java` / `PgProvider.java`** — NICEPAY·Stripe 공통 정규화 도메인. status는 `PAID`/`CANCELLED`, provider는 `NICEPAY`/`STRIPE`. eventId는 `{tid|cancelTid}_{status}` 규칙(`PgPaymentEvent.java:25`).
> - **`mapper/NicePayEventMapper.java:66`** — `StateCd`+`ResultCode`로 상태 도출(`0`&`3001`→PAID, `1`/`2`&`2001`→CANCELLED, 그 외 drop). `mapper/StripeEventMapper.java:31`은 이벤트 타입에 `refund` 포함 여부로 결제/환불 분기.
> - **`application/service/PgPaymentUseCaseResolver.java:29`** — `PgProvider`별 `HandlePgPaymentUseCase`(`NicePayPaymentWebhookService`/`StripePaymentWebhookService`) 라우팅. 각 서비스는 **중복 판정 통과 시에만 발행**(`NicePayPaymentWebhookService.java:27`).
> - **`adapter/out/cache/RedisDuplicatePgPaymentCheckAdapter.java:26`** — ElastiCache(Redis) `SETNX`+TTL 1h로 중복 이벤트 무시. 키 `{env}:fep-api:checkDuplicateTransaction:{provider}:{eventId}`. (api build.gradle에 `spring-boot-starter-data-redis` 추가)
> - **`adapter/out/event/SnsPgPaymentEventPublisher.java:20`** — 신규 SNS 카테고리 `PG_PAYMENT_COMPLETED`, eventType `PG_PAYMENT`, messageGroupId `payment-{tid}`. 동시에 `category=LOG`로 이중 기록(:58).
> - **`infra/localstack/init-aws.sh:33,87`** — 신규 큐 `pg-payment-completed-webhook.fifo`(+`-dlq`, maxReceiveCount=3)와 `wadiz-payment-requested`(+`-dlq`) 추가. SNS 필터폴리시 `PG_PAYMENT_COMPLETED` 구독 신설.
>
> ### SCOUT-79 — 저장소/재처리 인프라 대개편 (기존 본문과 충돌)
> - **Batch 모듈 완전 삭제** — `settings.gradle`에서 `finance-fep-application-batch` 제거, `deploy-batch.yml` 삭제. 3-모듈(api/agent/batch) → **2-모듈(api/agent)**. 본문의 "예약결제 스케줄러·Batch one-shot Job" 서술은 폐기됨.
> - **`agent/scheduler/DlqReprocessScheduler.java:49`** — Batch를 대체하는 Agent 내부 `@Scheduled`(cron `${scheduler.dlq-reprocess}`, KST) + **ShedLock**(`@SchedulerLock`, `ShedLockConfig.java:14` Redis LockProvider)로 DLQ 재처리. eventType 접두사로 재발행 큐 라우팅(PG_*→pg-payment, ACCOUNT_UPDATED→stripe-webhook, 그 외→wadiz-payment-requested, `:93`).
> - **MongoDB → OpenSearch 전환** — Agent의 `FinanceLog`/`FailedEvent`가 Mongo `MongoRepository`에서 `FinanceLogOpenSearchRepository`/`FailedEventOpenSearchRepository`로 교체. `OpenSearchConfig.java:33`(opensearch-java 2.8.1 저수준 클라이언트, Spring Data OpenSearch 미사용), `MonthlyIndexResolver.java:19`로 **월별 인덱스**(`prefix-yyyy-MM`) 색인. docker-compose에서 MongoDB 제거, redis·opensearch·opensearch-dashboards 추가.
> - **`agent/adapter/web/PgPaymentLogQueryController.java:16`** — `GET /api/internal/v1/pg-payments?tid=` / `.../pg-payments/period?from=&to=` 조회 API 신설(대사 조회용, Agent 모듈 최초의 REST 엔드포인트).
> - **`agent/listener/FinanceEventDlqListener.java:15`** — DLQ 리스너가 stripe-account-updated-dlq 외에 **pg-payment-completed-dlq, wadiz-payment-requested-dlq** 3종 구독으로 확장.
> - **API Key 인증 필터 제거** — `ApiAuthenticationFilter`·`ApiAuthProperties`·테스트 삭제(SCOUT-79 "fep-api 인증 중복으로 제거", beff4bf). 본문 "Ingress 인증: 고정 API Key Bearer" 서술 폐기 — 인증은 상위(게이트웨이) 위임.
>
> ### SCOUT-103 — Stripe 결제 웹훅 결제수단 CARD 고정
> - **`mapper/StripeEventMapper.java:36`** — `payMethod = "CARD"` 하드코딩 고정(4ce7a81). 빌드 시 통합 테스트 스킵 설정도 함께(d572c38).
>
> ### (부가) NICEPAY 웹훅 디버그 로그
> - **`NicePayWebhookController.java:63`** — 수신 시 StateCd/ResultCode/TID/MOID/Amt/PayMethod/ResultMsg INFO 로깅(65c3112).

---

## 개요

Wadiz Finance FEP(Front-End Processor = 결제 대외계)는 와디즈 내부 서비스와 해외 결제 파트너(Stripe Connect) 사이를 중계하는 결제 대외계 게이트웨이이다. 역할은 세 가지.

1. Stripe Connect 계정 생성/온보딩 링크 발급, 계정 상태/정산 정보 조회, Transfer(정산 이체) 생성 및 취소.
2. Stripe 웹훅(account.updated)을 수신하여 내부 이벤트로 변환 후 SNS 발행.
3. 모든 금융 이벤트를 MongoDB로 영속화, 실패 이벤트는 DLQ에서 수집해 Spring Batch가 재발행.

FEP의 주력은 Stripe Connect(해외 정산)이며 KR(한국) 국가는 Stripe 계정 생성 시 명시적으로 거절(AccountService.java:21-23). 다만 Stripe 외에도 **NICE 정산(payout) 연동**(NICE submall 정산 요청·취소·조회, `adapter/out/nicepay`)과 **환율 조회**(한국은행 ECOS + OpenExchangeRate, `adapter/out/exchangeRate` + `application/service/exchangeRate`)가 내부 API로 함께 들어와 있다. PG 결제(승인/취소) 본체는 여전히 별도 nicepay-api 레포가 담당하고, FEP의 NICE 연동은 "정산(payout)"에 한정된다. (Alipay+ 연동 코드는 없음)

멀티모듈:

| 모듈 | 패키지 | 포트 | 역할 |
|------|--------|------|------|
| finance-fep-application-api | co.wadiz.fep.api | 8080 | REST API, Stripe 호출, SNS 발행 |
| finance-fep-application-agent | co.wadiz.fep.agent | 8081 | SQS 수신 → MongoDB 로그 적재, DLQ 추적 |
| finance-fep-application-batch | co.wadiz.fep.batch | 8082 | Spring Batch로 DLQ 실패 이벤트 재발행 |

## 기술 스택

| 영역 | 스택 |
|------|------|
| 언어/런타임 | Java 21, Spring Boot 3.4.2 |
| 빌드 | Gradle 8.14.4 (멀티모듈) |
| HTTP | Spring MVC (Servlet) + Virtual Threads (spring.threads.virtual.enabled=true) |
| PG SDK | com.stripe:stripe-java:31.3.0 (API 모듈 전용) |
| 이벤트 | AWS SNS(발행) / SQS(구독) via io.awspring.cloud:spring-cloud-aws-starter-sns(3.3.0), -sqs |
| 저장소 | MongoDB (Agent, Batch) |
| 배치 | Spring Batch on Mongo (MongoJobRepositoryFactoryBean) |
| 설정 | Spring Cloud Kubernetes ConfigMap, Bootstrap |
| 매퍼 | MapStruct 1.6.3, Lombok |
| 문서 | Spring REST Docs + AsciiDoctor |
| 배포 | Jib → ECR core/fep-{api,agent,batch} |
| 로컬 | LocalStack(4566) + MongoDB(27017) via docker-compose |

주목: R2DBC/RabbitMQ/Stream 미사용. 이벤트는 AWS SNS/SQS 단일, DB는 MongoDB 단일. JPA/RDBMS 의존성 전무.

## 아키텍처

### API — Hexagonal

```
application/
  port/in/   UseCase 인터페이스
  port/out/  StripeGateway, AccountEventPublisher, TransferEventPublisher, FinanceLogPublisher, WebhookSignatureVerifier
  service/   AccountService, TransferService, AccountQueryService, AccountWebhookService
domain/      BusinessType 등 VO
adapter/
  in/web/    Controller(Account/Transfer/Webhook + NicePayoutController, ExchangeRateController), payload DTO, ApiAuthenticationFilter, GlobalExceptionHandler
  out/stripe/      StripeGatewayImpl, StripeConfig, StripeWebhookVerifier
  out/nicepay/     NicepayGatewayImpl(정산 요청/취소/조회), NicepayEncKeyGenerator, NicepayConfig, message DTO
  out/exchangeRate/ ExchangeRateGatewayImpl(한국은행·OpenExchangeRate 호출)
  out/event/       Sns*Publisher
```

의존 방향: adapter → application → domain (역방향 금지).

### Agent — Layered

```
listener/   FinanceLogListener, FinanceEventDlqListener (@SqsListener)
service/    FinanceLogService, FailedEventService
document/   FinanceLog, FailedEvent, FailedEventStatus (MongoDB Document)
repository/ MongoRepository
```

### Batch — Spring Batch on Mongo

- BatchConfig.java:32-45 — MongoJobRepositoryFactoryBean으로 Mongo를 JobRepository 저장소로 사용.
- FinanceFailedEventRetryJobConfig.java:37-65 — Chunk(10) Reader/Processor/Writer.
- BatchJobRunner.java:19 — @ConditionalOnProperty("spring.batch.job.names")로 기동 시 1회 실행 후 SpringApplication.exit. K8s CronJob 전용 one-shot.

### 인증·서명 검증

- ApiAuthenticationFilter.java:30 — Authorization: Bearer {API_AUTH_API_KEY} 고정 API Key. Webhook/docs/actuator 제외.
- StripeWebhookVerifier.java:22-29 — stripe.webhook-verify=false일 때만 서명 검증 우회.

## API 엔드포인트 목록

API 서버(finance-fep-application-api) 전수 스캔. Agent/Batch 모듈에는 외부 REST 엔드포인트 없음(Actuator 제외).

| Method | Path | Controller.method | 용도 |
|--------|------|-------------------|------|
| POST | /api/internal/v1/accounts | AccountController.createAccount (AccountController.java:34) | Stripe Connect Express 계정 생성 |
| POST | /api/internal/v1/accounts/{accountId}/link | AccountController.createAccountLink (AccountController.java:41) | Stripe 온보딩 링크 생성 |
| GET  | /api/internal/v1/accounts/{accountId}/status | AccountController.getAccountStatus (AccountController.java:50) | 계정 상태(capabilities, requirements) 조회 |
| GET  | /api/internal/v1/accounts/{accountId}/payout-info | AccountController.getAccountPayoutInfo (AccountController.java:67) | 정산용 외부 은행계좌 조회 |
| POST | /api/internal/v1/transfers | TransferController.createTransfer (TransferController.java:24) | Connect 계정으로 Transfer(이체) 생성 |
| POST | /api/internal/v1/transfers/{transferId}/reverse | TransferController.reverseTransfer (TransferController.java:46) | Transfer 취소(Reversal) |
| POST | /api/internal/v1/webhooks/stripe | StripeWebhookController.handleStripeWebhook (StripeWebhookController.java:21) | Stripe 웹훅 (account.updated만 처리) |

## 주요 API 상세 분석

### 1. POST /api/internal/v1/accounts — Stripe Connect 계정 생성

- 컨트롤러: AccountController.java:34
- 입력 DTO CreateAccountRequest (payload/CreateAccountRequest.java:8):
  - email (@NotBlank @Email)
  - country (@NotBlank, KR 입력 시 IllegalArgumentException)
  - businessType (@NotNull, enum INDIVIDUAL|COMPANY|NON_PROFIT|GOVERNMENT_ENTITY)
- 처리 로직 (AccountService.java:19-40):
  1. KR 국가 거절
  2. StripeGatewayImpl.createConnectedAccount (StripeGatewayImpl.java:33-62) — stripe-java 동기 블로킹 SDK(StripeClient)로 AccountCreateParams.Type.EXPRESS + card_payments/transfers capability 요청
  3. 성공 시 accountId 반환 + FinanceLogPublisher.publish("ACCOUNT_CREATED", payload)로 SNS 발행
- 외부 연동: Stripe API /v1/accounts
- DB 상호작용: 없음 (FEP은 Stripe ID를 로컬에 저장하지 않음 — Stripe가 source of truth)
- 이벤트: SNS finance-event.fifo, category=LOG, eventType=ACCOUNT_CREATED

### 2. POST /api/internal/v1/accounts/{accountId}/link — 온보딩 링크 발급

- 컨트롤러: AccountController.java:41
- 입력 DTO CreateAccountLinkRequest: refreshUrl, returnUrl
- 처리: stripeClient.v1().accountLinks().create(...) with Type.ACCOUNT_ONBOARDING (StripeGatewayImpl.java:65-80)
- 이벤트: eventType=ACCOUNT_LINK_CREATED를 category=LOG로 SNS 발행

### 3. POST /api/internal/v1/transfers — 이체 생성

- 컨트롤러: TransferController.java:24
- 헤더: Idempotency-Key 필수 (Stripe 멱등키로 그대로 전달)
- 입력 DTO CreateTransferRequest (payload/CreateTransferRequest.java:7):
  - amount (@NotNull @Min(1) Long)
  - currency (@NotBlank)
  - destination (@NotBlank, Connect 계정 ID acct_xxx)
  - description (선택)
- 처리 로직 (TransferService.java:22-45):
  1. StripeGatewayImpl.createTransfer (StripeGatewayImpl.java:83-111) — TransferCreateParams + RequestOptions.builder().setIdempotencyKey(...)로 Stripe 멱등성 보장
  2. 결과(TransferResult)를 FinanceLogPublisher.publish("TRANSFER_CREATED", ...)로 발행
- 외부 연동: Stripe /v1/transfers
- 예외: StripeException → ExternalPgException으로 래핑, GlobalExceptionHandler.java:37에서 pgStatusCode 기반으로 4xx 통과

### 4. POST /api/internal/v1/transfers/{transferId}/reverse — 이체 취소

- 컨트롤러: TransferController.java:46
- 헤더: Idempotency-Key 필수
- DTO ReverseTransferRequest: amount(@Min(1) — null이면 전액), description
- 처리: stripeClient.v1().transfers().reversals().create(transferId, params, requestOptions) (StripeGatewayImpl.java:113-141)
- 이벤트: TRANSFER_REVERSED 발행 (SnsTransferEventPublisher.java:36-39, category=LOG)

### 5. GET /api/internal/v1/accounts/{accountId}/status — 계정 상태 조회

- 컨트롤러: AccountController.java:50
- 처리: stripeClient.v1().accounts().retrieve(accountId) (StripeGatewayImpl.java:144-171)
- 응답: chargesEnabled, payoutsEnabled, detailsSubmitted와 requirements.currentlyDue/eventuallyDue/pastDue/disabledReason + **pendingVerification, errors** (ERP-1025 추가) + **capabilities** (Map<String,String>, 예: card_payments=active, transfers=active — StripeGatewayImpl.java:176-185에서 account.getCapabilities() raw JSON을 파싱, ERP-1025 추가)
- DB: 없음, 로그 이벤트: 없음 (조회성 API)

### 6. GET /api/internal/v1/accounts/{accountId}/payout-info — 정산용 은행계좌 조회

- 컨트롤러: AccountController.java:67
- 처리: AccountRetrieveParams.builder().addExpand("external_accounts")로 확장 조회 후 BankAccount 타입만 필터링 (StripeGatewayImpl.java:173-202) — 카드는 제외
- 응답: bankName, last4, currency, country, accountHolderName + **Stripe BankAccount 전체 필드** (ERP-1025 확장)

### 7. POST /api/internal/v1/webhooks/stripe — Stripe 웹훅 수신

- 컨트롤러: StripeWebhookController.java:21
- 입력: @RequestBody String payload + Stripe-Signature 헤더
- 인증 필터 제외 경로(ApiAuthenticationFilter.java:34) — 대신 Stripe 서명 검증
- 처리 로직:
  1. StripeWebhookVerifier.verifyAndParse (StripeWebhookVerifier.java:22-29) — Webhook.constructEvent(payload, sig, secret), 서명 불일치 시 400
  2. account.updated 이벤트만 분기 처리 → AccountWebhookService.handleAccountUpdated(rawJson) (AccountWebhookService.java:24-52) — Jackson JsonNode로 수동 파싱
  3. AccountUpdatedCommand 생성 → SnsAccountEventPublisher.publishAccountUpdated (SnsAccountEventPublisher.java:30-36). 발행 이벤트(AccountUpdatedEvent)에는 chargesEnabled/payoutsEnabled/detailsSubmitted/requirements 외에 **capabilities** 맵도 포함 — 웹훅 JSON의 `capabilities` 오브젝트를 String 값만 추려 파싱(AccountWebhookService.toStringMap, ERP-1025 추가).
  4. SNS에 category=STRIPE_ACCOUNT_UPDATED, messageGroupId=account-{accountId} (FIFO 키)로 publish + 동시에 category=LOG로 이중 기록
- 외부 연동: Stripe → FEP 수신 / FEP → SNS 발행 / Agent가 SQS stripe-account-updated-webhook.fifo에서 구독

### 8. (Agent) SQS Listener

- FinanceLogListener.java:17 — @SqsListener("${sqs.queue.finance-log}") → FinanceLogService.saveLog → FinanceLog Document를 finance_log 컬렉션에 저장.
- FinanceEventDlqListener.java:16 — @SqsListener("${sqs.queue.stripe-account-updated-webhook-dlq}") → FailedEventService.handleFailedEvent (FailedEventService.java:40-76): 첫 실패 시 PENDING 저장, 재시도 시 retryCount++, maxRetry(3) 초과 시 DEAD.
- 중요: Agent는 정상 큐(stripe-account-updated-webhook.fifo)를 직접 구독하지 않음 — 외부 와디즈 타 서비스가 소비하도록 설계.

### 9. (Batch) financeFailedEventRetryJob — DLQ 재발행

- FailedEventProcessor.java:30-67:
  1. retryCount >= maxRetry → DEAD 마킹
  2. 그 외에는 SqsTemplate.send(to.queue(webhookQueue).payload(...).header("message-group-id", eventId))로 stripe-account-updated-webhook.fifo에 재발행
  3. retryCount++, nextRetryAt = now + retryCount * 30min, status=RETRY
- Reader 쿼리(FinanceFailedEventRetryJobConfig.java:59): { 'status': { $in: ['PENDING','RETRY'] }, 'nextRetryAt': { $lte: now } } — 30/60/90분 backoff

## DB 스키마 요약

### MongoDB (기본 URI mongodb://localhost:27017/fep_local)

Agent와 Batch는 동일한 failed_event 컬렉션을 각자 Document 클래스로 중복 정의하여 공유.

| Collection | Document 클래스 | 주요 필드 | 용도 |
|-----------|----------------|-----------|------|
| finance_log | FinanceLog (finance-fep-application-agent/src/main/java/co/wadiz/fep/agent/document/FinanceLog.java:12) | id, **externalId**, eventType, payload(Object), createdAt | 모든 금융 이벤트(LOG 카테고리) 원본 적재 (externalId: 2026-05-14 추가) |
| failed_event | FailedEvent (FailedEvent.java:14) | id, eventId, eventType, payload, status(PENDING/RETRY/DEAD), retryCount, maxRetry, nextRetryAt, createdAt, updatedAt | DLQ 실패 이벤트 추적 및 재시도 스케줄 |
| BATCH_JOB_* (자동) | Spring Batch Meta | MongoJobRepositoryFactoryBean이 생성 | Batch Job/Step Execution 메타데이터 |

### RDB

사용하지 않음 — JPA/R2DBC 의존성 전무. Stripe가 account/transfer의 source of truth이며 내부에는 이벤트 로그만 남김.

## 외부 의존성

### 결제 파트너

| 파트너 | 엔드포인트 | 어디서 |
|--------|-----------|--------|
| Stripe Connect | https://api.stripe.com/v1/accounts, /v1/account_links, /v1/transfers, /v1/transfers/{id}/reversals | StripeGatewayImpl.java (stripe-java:31.3.0 SDK 동기 호출) |
| Stripe Webhook | FEP 수신: POST /api/internal/v1/webhooks/stripe → Webhook.constructEvent 서명 검증 | StripeWebhookVerifier.java:28 |
| NICE 정산(payout) | POST /api/internal/v1/nice/payouts/inquiry (정산 조회). Gateway는 정산 요청/취소/조회 지원, NicepayEncKeyGenerator로 거래 암호화키 생성(SID 정산 0102001/취소 0103001/조회 0101002) | NicePayoutController.java, NicepayGatewayImpl.java |
| 환율 | GET /api/internal/v1/exchange-rate/korea-bank (한국은행 ECOS), GET /api/internal/v1/exchange-rate/open-exchange-rate (OpenExchangeRate) | ExchangeRateController.java, ExchangeRateService.java |

PG 결제(승인/취소) 본체는 nicepay-api 레포 담당. FEP의 NICE 연동은 정산(payout)에 한정. Alipay+는 FEP에 없음.

### 이벤트 브로커 (AWS SNS/SQS only)

SNS Topic: finance-event.fifo (${sns.topic.finance-event}) — FIFO.

SQS Queues (infra/localstack/init-aws.sh):
- stripe-account-updated-webhook.fifo — SNS Filter category=STRIPE_ACCOUNT_UPDATED 구독. DLQ redrive maxReceiveCount=3.
- stripe-account-updated-webhook-dlq.fifo — 위 큐의 DLQ. Agent 구독.
- finance-log.fifo — SNS Filter category=LOG 구독. Agent 구독 → MongoDB 로그 적재.

발행 방향:
- API 모듈 → SNS finance-event.fifo (SnsAccountEventPublisher, SnsTransferEventPublisher, SnsFinanceLogPublisher)
- SNS Filter Policy(category)로 SQS 분기 라우팅

구독 방향:
- Agent: finance-log.fifo + stripe-account-updated-webhook-dlq.fifo
- Batch: 직접 구독하지 않음. MongoDB failed_event를 Reader로 읽어 SQS stripe-account-updated-webhook.fifo에 재발행.

메시지 속성:
- messageGroupId: account-{accountId} / transfer-{transferId} / log-{eventType} — FIFO 키
- category: STRIPE_ACCOUNT_UPDATED 또는 LOG
- eventType: 구체 이벤트명 (ACCOUNT_UPDATED, TRANSFER_CREATED 등)

### 예약결제 스케줄러·DLQ 재처리 체계

- Spring Batch + Mongo JobRepository. @ConditionalOnProperty("spring.batch.job.names")로 기동 직후 1회 실행 후 JVM 종료 → 외부 스케줄러(K8s CronJob) 필요.
- DLQ → FailedEvent(Agent 기록) → Batch Reader 쿼리(nextRetryAt <= now) → SQS 재발행 → Chunk(10)로 묶어 Mongo 상태 업데이트.
- FEP는 "예약결제" 자체 스케줄러는 없음(예약결제 본체는 nicepay-api/Stripe가 담당).

### 인프라/설정

- spring-cloud-starter-kubernetes-client-config + bootstrap.yml / bootstrap-kubernetes.yml → ConfigMap에서 환경별 설정 로드(live/rc/dev).
- 배포 환경 프로파일: odev / cdev / dev / rc / rc2 / rc4 / clive / live (api·agent·batch별 application-{env}.yml). GitHub Actions deploy-api/agent/batch 워크플로우가 브랜치(dev/rc/rc2/rc4/cloud_dev/cloud_live/main)별로 gitops 경로(core/{rc1,rc2,rc4,cdev,clive}/fep-*.yaml)에 매핑(deploy-api.yml). API 문서 도메인 표(index.adoc)에 odev=dev-platform.wadizcorp.net/fep, rc/rc2/rc4=rc{,2,4}-platform.wadizcorp.net/fep, cdev=api.dev.wadiz.co/fep 등록.
- Jib 이미지 빌드: ECR 843734097580.dkr.ecr.ap-northeast-2.amazonaws.com/core/fep-{api,agent,batch} 태그 주입(-Dimage.tag).
- LocalStack(docker-compose.yml + infra/localstack/init-aws.sh)으로 개발환경에서 SNS/SQS/토픽/구독 자동 생성.

## 특이사항

### 멀티모듈 역할 분담 (api/agent/batch)

- API (finance-fep-application-api, port 8080): 외부 트래픽을 받는 유일한 모듈. Hexagonal로 Stripe SDK 호출 로직과 SNS 발행을 분리. 도메인 로직은 얇고 거의 Stripe 래퍼에 가까움(결제 상태는 Stripe가 보관). Virtual Threads 활성화로 Stripe 동기 SDK 블로킹 완화.
- Agent (finance-fep-application-agent, port 8081): SQS 리스너만 소비, 외부 HTTP 엔드포인트 없음(Actuator 제외). MongoDB에 모든 금융 이벤트 영속화 + DLQ를 실패 추적 컬렉션으로 변환.
- Batch (finance-fep-application-batch, port 8082): one-shot Job 러너. Mongo에 쌓인 FailedEvent 중 nextRetryAt <= now 조건을 만족하는 항목만 찾아 SQS 재발행. 30분 × retryCount backoff. K8s CronJob 주기 실행 전제.

3분할 의도: 결제 인입(API)과 이벤트 영속/재시도(Agent/Batch)를 격리해 Stripe 호출 경로의 장애가 로그/복구 경로에 전파되지 않도록 한다.

### FIFO & 멱등성

- SNS/SQS 모두 FIFO(.fifo). messageGroupId를 accountId/transferId로 잡아 동일 대상 이벤트 순서를 보장.
- Stripe 측 멱등: Idempotency-Key 헤더를 API 입구에서 요구하여 Stripe RequestOptions에 그대로 전달(TransferController.java:26, StripeGatewayImpl.java:94).

### account.updated 이외 이벤트 미처리

- StripeWebhookController.java:34에서 오직 account.updated만 분기 처리. 그 외 Stripe 이벤트(charge.*, payout.*, transfer.* 등)는 200 OK로 무시됨.

### NICE 연동 RestClient 설정 (NicepayConfig)

- `nicepayRestClient` 빈(NicepayConfig.java:18): baseUrl=NicepayProperties.apiUrl, 기본 헤더 `Content-Type: application/json` + `Charset: utf-8`.
- 요청/응답 로깅 interceptor 추가 — 요청 URI/헤더/body(UTF-8 문자열), 응답 상태/헤더를 INFO 로그로 기록(NicepayConfig.java:25-35).
- **인코딩 최종 상태(ERP-1025)**: NICE 요청 본문은 **원본 UTF-8 그대로 전송**한다. 작업 중 `Content-Type: charset=EUC-KR` 및 본문 EUC-KR 인코딩을 시도한 커밋(2aa4866 등)이 있었으나, Jackson 호환성 문제로 모두 되돌려졌고(9c524d7 revert) 최종적으로는 `application/json` Content-Type에 `Charset: utf-8` 헤더만 남았다. 즉 EUC-KR 변환은 적용되지 않은 net 결과.

### Ingress 인증

- 고정 API Key Bearer 방식 (api.auth.api-key 프로퍼티, 기본값 하드코딩 — 운영에서는 ENV 오버라이드 전제). JWT/OAuth 등은 사용하지 않음.

### 테스트 & 문서

- Spring REST Docs 기반 자동 문서화가 api 모듈에만 적용(finance-fep-application-api/build.gradle:51, 58). asciidoctor 태스크가 test 산출 스니펫을 HTML로 변환, bootJar가 static/docs로 포함.
- copyDocs 태스크로 bootRun 시에도 /docs/index.html 제공 가능.

### 하드코딩/운영 이슈

- application.yml:19의 API_AUTH_API_KEY에 실제 값으로 보이는 64자 hex 토큰이 default로 박혀 있음 — 운영 전 ENV로 덮어써야 함.
- KR 국가 거절은 AccountService.java:22에 문자열 비교로 구현 — ISO 국가코드 전체 블랙/화이트리스트 체계가 아님.
- GlobalExceptionHandler.handleRuntime(GlobalExceptionHandler.java:52)이 모든 RuntimeException을 500으로 떨어뜨리는데, SnsAccountEventPublisher.java:53가 SNS 실패 시 RuntimeException을 던지므로 Webhook 응답이 500이 되어 Stripe가 재시도 — 의도된 설계.

---

## 최근 변경사항

**분석 갱신일: 2026-07-10** (최초: 2026-04-20)

| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| Stripe 결제 웹훅 결제수단 `CARD` 고정 + 빌드 시 통합테스트 스킵 | 2026-07-08 | SCOUT-103 |
| NICEPAY 웹훅 수신 디버그 로그 추가 | 2026-07-06 | - |
| PG 결제 실시간 대사 웹훅 도입 (nicepay/payment·stripe/payment 엔드포인트, PgPaymentEvent 도메인·매퍼·resolver, Redis 중복판정, SNS `PG_PAYMENT_COMPLETED`, pg-payment/wadiz-payment 큐) | 2026-06-25 ~ 2026-07-02 | SCOUT-79 |
| Batch 모듈 삭제 → Agent DlqReprocessScheduler + ShedLock(Redis) 로 DLQ 재처리 이관 | 2026-06-25 | SCOUT-79 |
| Agent 저장소 MongoDB → OpenSearch 전환 (월별 인덱스, PgPaymentLogQuery 조회 API) | 2026-06-25 ~ 2026-07-01 | SCOUT-79 |
| API Key 인증 필터(ApiAuthenticationFilter) 제거 — 인증 중복 정리 | 2026-07-02 | SCOUT-79 |
| NICEPAY 웹훅 EUC-KR 원본 스트림 디코딩 처리 | 2026-06-30 ~ 2026-07-01 | SCOUT-79 |
| NicepayConfig에 NICE API 요청/응답 로깅 interceptor 추가 | 2026-06-04 | ERP-1025 |
| NICE 요청 인코딩 최종 정리 — EUC-KR 변환 시도 후 모두 revert, `application/json` + `Charset: utf-8` 헤더로 원본 UTF-8 전송 유지 | 2026-06-04 | ERP-1025 |
| account.updated 웹훅 발행 이벤트에 `capabilities`(Map) 필드 추가 | 2026-06-01 | ERP-1025 |
| 계정 상태 조회 응답에 `capabilities`(Map) 필드 추가 | 2026-06-01 | ERP-1025 |
| 배포 환경 odev / cdev / rc4 추가 및 환경별 application yml·CI/CD 분기 정리 | 2026-06-01 ~ 2026-06-02 | ERP-1025 |
| rc/rc2/clive/live에 nicepay api-url 추가, 미사용 stripe.accounts 설정 제거 | 2026-05-28 ~ 2026-05-29 | ERP-1025 |
| 내부 API URL `/api/v1/` → `/api/internal/v1/` 일괄 변경 | 2026-05-20 | ERP-1025 |
| 계정 상태 조회 응답에 `pendingVerification`, `errors` 필드 추가 | 2026-04-24 | ERP-1025 |
| 정산 계좌 조회 응답 Stripe BankAccount 전체 필드 확장 | 2026-04-24 | ERP-1025 |
| Stripe API 응답 전체 필드 추가 | 2026-04-24 | ERP-1025 |
| account.updated 웹훅에 requirements.errors 파싱 추가 | 2026-04-24 | ERP-1025 |
| account.updated 이벤트에 Stripe 이벤트 ID 추가 | 2026-04-27 | ERP-1025 |
| SNS 메시지에 environment 속성 추가 | 2026-04-29 | ERP-1025 |
| FinanceLog에 `externalId` 필드 추가 | 2026-05-14 | - |
| JVM 메모리 설정 최적화 | 2026-05-15 | ERP-1025 |
| 라이브(Live) 배포 설정 추가 | 2026-05-19 | ERP-1025 |
| rc-funding, rc2-funding, clive 환경 설정 추가 | 2026-04-20 ~ 2026-05-28 | ERP-1025 |
| GitHub Actions workflow 통합 및 clive 환경 추가 | 2026-05-28 | ERP-1025 |
