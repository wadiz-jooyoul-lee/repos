# co.wadiz.fep 분석

## 개요

Wadiz Finance FEP(Front-End Processor = 결제 대외계)는 와디즈 내부 서비스와 해외 결제 파트너(Stripe Connect) 사이를 중계하는 결제 대외계 게이트웨이이다. 역할은 세 가지.

1. Stripe Connect 계정 생성/온보딩 링크 발급, 계정 상태/정산 정보 조회, Transfer(정산 이체) 생성 및 취소.
2. Stripe 웹훅(account.updated)을 수신하여 내부 이벤트로 변환 후 SNS 발행.
3. 모든 금융 이벤트를 MongoDB로 영속화, 실패 이벤트는 DLQ에서 수집해 Spring Batch가 재발행.

FEP는 Stripe Connect 전용. 나이스페이/Alipay+ 연동 코드는 존재하지 않음(별도 nicepay-api 레포 담당). KR(한국) 국가는 명시적으로 거절(AccountService.java:21-23).

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
  in/web/    Controller, payload DTO, ApiAuthenticationFilter, GlobalExceptionHandler
  out/stripe/ StripeGatewayImpl, StripeConfig, StripeWebhookVerifier
  out/event/  Sns*Publisher
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
| POST | /api/v1/accounts | AccountController.createAccount (AccountController.java:34) | Stripe Connect Express 계정 생성 |
| POST | /api/v1/accounts/{accountId}/link | AccountController.createAccountLink (AccountController.java:41) | Stripe 온보딩 링크 생성 |
| GET  | /api/v1/accounts/{accountId}/status | AccountController.getAccountStatus (AccountController.java:50) | 계정 상태(capabilities, requirements) 조회 |
| GET  | /api/v1/accounts/{accountId}/payout-info | AccountController.getAccountPayoutInfo (AccountController.java:67) | 정산용 외부 은행계좌 조회 |
| POST | /api/v1/transfers | TransferController.createTransfer (TransferController.java:24) | Connect 계정으로 Transfer(이체) 생성 |
| POST | /api/v1/transfers/{transferId}/reverse | TransferController.reverseTransfer (TransferController.java:46) | Transfer 취소(Reversal) |
| POST | /api/v1/webhooks/stripe | StripeWebhookController.handleStripeWebhook (StripeWebhookController.java:21) | Stripe 웹훅 (account.updated만 처리) |

## 주요 API 상세 분석

### 1. POST /api/v1/accounts — Stripe Connect 계정 생성

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

### 2. POST /api/v1/accounts/{accountId}/link — 온보딩 링크 발급

- 컨트롤러: AccountController.java:41
- 입력 DTO CreateAccountLinkRequest: refreshUrl, returnUrl
- 처리: stripeClient.v1().accountLinks().create(...) with Type.ACCOUNT_ONBOARDING (StripeGatewayImpl.java:65-80)
- 이벤트: eventType=ACCOUNT_LINK_CREATED를 category=LOG로 SNS 발행

### 3. POST /api/v1/transfers — 이체 생성

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

### 4. POST /api/v1/transfers/{transferId}/reverse — 이체 취소

- 컨트롤러: TransferController.java:46
- 헤더: Idempotency-Key 필수
- DTO ReverseTransferRequest: amount(@Min(1) — null이면 전액), description
- 처리: stripeClient.v1().transfers().reversals().create(transferId, params, requestOptions) (StripeGatewayImpl.java:113-141)
- 이벤트: TRANSFER_REVERSED 발행 (SnsTransferEventPublisher.java:36-39, category=LOG)

### 5. GET /api/v1/accounts/{accountId}/status — 계정 상태 조회

- 컨트롤러: AccountController.java:50
- 처리: stripeClient.v1().accounts().retrieve(accountId) (StripeGatewayImpl.java:144-171)
- 응답: chargesEnabled, payoutsEnabled, detailsSubmitted와 requirements.currentlyDue/eventuallyDue/pastDue/disabledReason
- DB: 없음, 로그 이벤트: 없음 (조회성 API)

### 6. GET /api/v1/accounts/{accountId}/payout-info — 정산용 은행계좌 조회

- 컨트롤러: AccountController.java:67
- 처리: AccountRetrieveParams.builder().addExpand("external_accounts")로 확장 조회 후 BankAccount 타입만 필터링 (StripeGatewayImpl.java:173-202) — 카드는 제외
- 응답: bankName, last4, currency, country, accountHolderName

### 7. POST /api/v1/webhooks/stripe — Stripe 웹훅 수신

- 컨트롤러: StripeWebhookController.java:21
- 입력: @RequestBody String payload + Stripe-Signature 헤더
- 인증 필터 제외 경로(ApiAuthenticationFilter.java:34) — 대신 Stripe 서명 검증
- 처리 로직:
  1. StripeWebhookVerifier.verifyAndParse (StripeWebhookVerifier.java:22-29) — Webhook.constructEvent(payload, sig, secret), 서명 불일치 시 400
  2. account.updated 이벤트만 분기 처리 → AccountWebhookService.handleAccountUpdated(rawJson) (AccountWebhookService.java:24-52) — Jackson JsonNode로 수동 파싱
  3. AccountUpdatedCommand 생성 → SnsAccountEventPublisher.publishAccountUpdated (SnsAccountEventPublisher.java:30-36)
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
| finance_log | FinanceLog (finance-fep-application-agent/src/main/java/co/wadiz/fep/agent/document/FinanceLog.java:12) | id, eventType, payload(Object), createdAt | 모든 금융 이벤트(LOG 카테고리) 원본 적재 |
| failed_event | FailedEvent (FailedEvent.java:14) | id, eventId, eventType, payload, status(PENDING/RETRY/DEAD), retryCount, maxRetry, nextRetryAt, createdAt, updatedAt | DLQ 실패 이벤트 추적 및 재시도 스케줄 |
| BATCH_JOB_* (자동) | Spring Batch Meta | MongoJobRepositoryFactoryBean이 생성 | Batch Job/Step Execution 메타데이터 |

### RDB

사용하지 않음 — JPA/R2DBC 의존성 전무. Stripe가 account/transfer의 source of truth이며 내부에는 이벤트 로그만 남김.

## 외부 의존성

### 결제 파트너

| 파트너 | 엔드포인트 | 어디서 |
|--------|-----------|--------|
| Stripe Connect | https://api.stripe.com/v1/accounts, /v1/account_links, /v1/transfers, /v1/transfers/{id}/reversals | StripeGatewayImpl.java (stripe-java:31.3.0 SDK 동기 호출) |
| Stripe Webhook | FEP 수신: POST /api/v1/webhooks/stripe → Webhook.constructEvent 서명 검증 | StripeWebhookVerifier.java:28 |

나이스페이/Alipay+는 FEP에 없음 — nicepay-api 레포 담당.

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

### Ingress 인증

- 고정 API Key Bearer 방식 (api.auth.api-key 프로퍼티, 기본값 하드코딩 — 운영에서는 ENV 오버라이드 전제). JWT/OAuth 등은 사용하지 않음.

### 테스트 & 문서

- Spring REST Docs 기반 자동 문서화가 api 모듈에만 적용(finance-fep-application-api/build.gradle:51, 58). asciidoctor 태스크가 test 산출 스니펫을 HTML로 변환, bootJar가 static/docs로 포함.
- copyDocs 태스크로 bootRun 시에도 /docs/index.html 제공 가능.

### 하드코딩/운영 이슈

- application.yml:19의 API_AUTH_API_KEY에 실제 값으로 보이는 64자 hex 토큰이 default로 박혀 있음 — 운영 전 ENV로 덮어써야 함.
- KR 국가 거절은 AccountService.java:22에 문자열 비교로 구현 — ISO 국가코드 전체 블랙/화이트리스트 체계가 아님.
- GlobalExceptionHandler.handleRuntime(GlobalExceptionHandler.java:52)이 모든 RuntimeException을 500으로 떨어뜨리는데, SnsAccountEventPublisher.java:53가 SNS 실패 시 RuntimeException을 던지므로 Webhook 응답이 500이 되어 Stripe가 재시도 — 의도된 설계.
