# io.wadiz.order (order-api) 분석 문서

> 여러 저장소에 흩어져 있던 **주문·환불 로직을 한곳으로 모으는 신규 서비스**입니다. 저장소 README 의 한 줄 정의가 정확합니다 — *"판단·계산·기록·통지를 소유하고, **PG 실집행은 기존 서비스(`nicepay-api` · `kr.wadiz.api.payment`)에 남긴다**"*.
> Org: `wadiz-service` (`https://github.com/wadiz-service/io.wadiz.order.git`). 배포 이름 **`order-api`**, 플랫폼 `core`.

> 📅 분석 기준: 2026-09-16 clone, **`dev` 브랜치**(`c5ff6a3`, 2026-09-15). Java 196개(main) · 테스트 61개.

> ⚠️ **아직 클라우드 라이브에 배포되지 않았습니다.** 아래 "배포 — 아직 live 가 아닙니다" 를 먼저 보세요.

> ℹ️ 설계 근거는 저장소 밖 Confluence 에 있습니다 — README 가 [주문 서버 설계](https://wadiz.atlassian.net/wiki/spaces/WadizDev/pages/18111365146) 를 정본으로 지목하고, *"아래 내용은 요약이고 판단 근거는 전부 위키에 있다"* 고 명시합니다.

---

## 개요

- **환불(취소·반환)이 첫 번째 대상**입니다. 지금 있는 기능은 전부 환불 계열이고, 주문 생성·결제 같은 것은 없습니다.
- 흩어져 있던 로직의 출처가 코드 주석에 남아 있습니다 — 레거시 [`com.wadiz.web`](./com.wadiz.web.md) 과 어드민([`co.wadiz.adm`](./co.wadiz.adm.md))이 쓰던 테이블·상태값을 **그대로 이어받습니다.**
- 이관은 **"슬라이스" 단위로 쪼개** 진행됐습니다 — 커밋 제목에 `슬라이스 1` · `2-1` · `2-2a/b/c` · `3·4` 가 붙어 있습니다.

> 💡 **왜 PG 호출은 안 가져오나**: 결제대행사(PG) 실집행은 `nicepay-api`·`kr.wadiz.api.payment` 에 남겨 두고, 이 서비스는 **"얼마를 돌려줄지 판단하고, 원장에 기록하고, 알림을 보내는" 부분만** 가져왔습니다. 돈이 실제로 나가는 경로를 건드리지 않아 이관 위험을 낮춘 선택으로 읽힙니다.

## 기술 스택 — 사내 최신

| 구분 | 내용 | 비고 |
|---|---|---|
| 언어 | **Java 21** (toolchain) | 도서관 등록 저장소 중 최신 축 |
| 프레임워크 | **Spring Boot 4.1.1** · Spring Cloud 2025.1.3 | **사내 최신**. 다른 서비스는 대체로 2.7~3.3 |
| 동시성 | **가상 스레드(Virtual Thread) 활성** (`spring.threads.virtual.enabled: true`) | |
| DB | MySQL + **MyBatis 4.0.1** | 매퍼 XML 7종 |
| 캐시·락 | **Redis** (분산 락 · 예약 청구 상태) | |
| 회복성 | **Resilience4j Bulkhead 2.3** | 아웃바운드 동시 호출 제한 |
| 인증 | **OAuth2 Resource Server (JWT)** | `JwtDecoderConfig` + 역할 변환기 |
| API 문서 | springdoc-openapi 3.1 (Swagger UI) | live 에서는 gitops 가 꺼 버림 |
| 관측 | Actuator + Micrometer Prometheus | |
| 쿠버네티스 | `spring-cloud-starter-kubernetes-client-config` + bootstrap | `on-cloud-platform` 으로 k8s 위에서만 활성 |
| 빌드/이미지 | Gradle 멀티모듈 + **Jib 3.4.4**(OCI, `eclipse-temurin:21`) | |
| 사내 의존성 | `com.wadiz.wave:wave-crypto` (증빙 파일 식별자 복호화) | **`transitive = false`** 로 끊음 |

> ⚠️ `wave-crypto` 의 pom 이 **spring-security-core 3.2.5(2014년)와 springfox 를 끌고 와서** `transitive = false` 로 차단했습니다. 대신 `AES256Util` 이 `StringUtils.isEmpty` 하나 때문에 참조하는 `commons-lang 2.6` 만 따로 넣었습니다(주석에 근거 기재).

## 모듈 구성

| 모듈 | Java(main) | 테스트 | 역할 | 포트 |
|---|---:|---:|---|---|
| **`order-core`** | 151 | 49 | 육각형 본체 — `domain` + `application` + `adapter/out`. **`bootJar` 없음**(라이브러리) | — |
| **`order-application-api`** | 44 | 13 | `adapter/in/web`. **Phase 1 배포 대상** | 8080 |
| `order-application-batch` | 1 | 0 | `adapter/in/batch`. **트리거 미정 — 빌드·테스트만** | 8081 |

- 배치 모듈은 **껍데기 1개 파일**입니다. 자리만 잡아 둔 상태입니다.
- actuator 를 **앱과 같은 포트**에 둡니다. README 에 이유가 있습니다 — 분리하면 자식 컨텍스트가 되어 `SecurityFilterChain` 이 닿지 않습니다.

## API 엔드포인트 — 컨트롤러 15개

경로가 **서포터용(`/api/refunds/...`)과 운영자용(`/api/admin/refunds/...`)으로 갈립니다.**

### 서포터 경로 `/api/refunds`

| Method | Path | 용도 |
|---|---|---|
| POST | `/cancels` | 결제 취소 |
| POST | `/returns/claims` | **반환 신청** |
| PATCH | `/returns/claims` | 반환 신청 **사유 변경** |
| POST | `/returns/claims/cancels` | 반환 신청 **철회** |
| POST | `/returns/previews` | 반환 **미리보기(드라이런)** — 리워드 목록을 내려 부분 반환을 고르게 함 |
| POST | `/returns/approvals` | 반환 승인(메이커) — **캠페인 소유자 검증** 포함 |
| POST | `/returns/holds` | 반환 **보류** |
| POST | `/returns/rejections` | 반환 **거절** |

### 운영자 경로 `/api/admin/refunds`

| Method | Path | 용도 |
|---|---|---|
| POST | `/cancels` | 운영자 취소 — **정산 상태·분할결제 가드** 있음 |
| POST | `/returns` | 운영자 반환 |
| POST | `/aborts` | **캠페인 일괄 취소**(미달 종료 등) |
| POST | `/out-of-term` · GET `/out-of-term/{campaignId}` | 기한 외 환불 |
| POST | `/simulations` | 환불 시뮬레이션 |

### 검증용 (운영 제외)

`GET /demo/guards` · `GET /demo/token` — `@Profile` 과 `@Hidden`(OpenAPI 비노출)이 걸린 **로컬·dev 검증 콘솔**입니다. 가드 점검과 토큰 발급을 화면에서 확인하려고 만든 것입니다.

### 인가

`WebSecurityConfig` 기준 — **기본이 `authenticated()`** 이고, `permitAll` 은 `/actuator/health/{liveness,readiness}` · `/demo/**` · Swagger UI/`/v3/api-docs` 뿐입니다. 인증은 **JWT(OAuth2 Resource Server)** 이고 역할 변환기를 붙였습니다.

> 주석에 이런 설명이 있습니다 — live 에서는 springdoc 이 꺼져 **핸들러가 없으니 그 `permitAll` 도 걸리지 않고 401 로 떨어진다.**

## 도메인 모델

`order-core/domain` 에 **37개 타입**이 있습니다. 축을 몇 개로 정리하면 이렇습니다.

| 축 | 타입 |
|---|---|
| 환불 종류 | **`RefundKind`** — `CANCEL` · `ABORT` · `FUND_RETURN` |
| 실행 단위 | `RefundCommand` → `RefundContext` → `RefundPlan` → `RefundResult` |
| 금액 | `RefundAmount` · `Money` · `Currency` · `ExchangeRate` · `ShippingRefund` · `ShippingScope` |
| 신청(반환) | `RefundClaim` · `ClaimStatus` · `ClaimApplicability` · `ClaimContext` · `ClaimWindow` |
| 행위 주체 | **`RefundActor`** · **`RefundActorType`**(`SUPPORTER` · `ADMIN` · `MAKER` · `SYSTEM`) |
| 검증 | `RefundValidation` · `ValidationReason` · `Severity` |
| 결제·정산 | `PayMethod` · `PayStatus` · `PaymentApi` · `PaymentCancelResult` · `SettlementStatus` · `SettlementSystemType` |
| 혜택 | `MembershipBenefit` · `RewardItem` · `Exclusion` |

### `RefundKind` — 캠페인 집계에서 뺄지 말지를 종류가 정합니다

세 값이 각자 다른 규칙을 갖고, **주석에 이유가 붙어 있습니다.**

| 종류 | 집계 제외 규칙 | 근거(주석) |
|---|---|---|
| `CANCEL` | 캠페인 **종료 전이면 제외**, 종료 후면 남김 | *"성공한 캠페인이 사후에 미달로 바뀌면 안 된다"* · *"진행 중이면 누가 취소해도 재고·모집액이 돌아와야 한다"* |
| `ABORT` | **항상 제외** | *"캠페인이 성립하지 않았으므로 종료 후여도 실적으로 셀 수 없다"* |
| `FUND_RETURN` | **건드리지 않음**(`UNCHANGED`) | *"이미 일괄 취소된 건을 반환해도 그 제외 상태를 되돌리면 안 된다"* |

### `ClaimStatus` — 레거시 값 집합을 그대로 씁니다

`APPLY` · `REFUNDED` · `REJECTED` · `CANCEL_APPLICATION` 네 값입니다. 주석에 제약이 명시돼 있습니다 — ***"값 집합은 레거시 `RefundStatus`(com.wadiz.web)를 그대로 쓴다. 늘리거나 이름을 바꾸면 같은 테이블을 읽는 web · adm 이 모르는 값을 만난다."***

즉 **세 저장소가 같은 테이블을 공유하는 과도기**입니다.

## 실행 순서 — `RefundEngine`

이 서비스의 핵심입니다(310줄). 클래스 주석이 설계 의도를 밝힙니다 — ***"환불 실행 순서를 소유한다. 트랜잭션 경계와 permit 획득을 어댑터 뒤로 숨기지 않는다 — 순서가 곧 정합성이라 이 코드를 읽어서 보여야 한다."***

### 계획 단계 (`planRefund`)

1. **bulkhead permit 획득** → 컨텍스트를 읽기 전용 트랜잭션으로 조회
2. **금액 → 검증 → 환산 순서**로 계산. 이 순서인 이유가 주석에 있습니다 — *부분 여부가 계산 결과로 정해지고(부분환불 불가 PG), 거부될 요청으로 환전 API 를 부르지 않기 위해서.*
3. 환산 결과(`pgAmount`)는 **`amount` 를 덮지 않고 따로 듭니다** — 겸하면 통화 컬럼이 없는 `BackingPaymentRefund` 에 결제 통화 값이 들어가 정산이 어긋납니다.

### 실행 단계 (`execute` → `refundWithCompensation`)

```
Redis 락 선점 (보상할 게 없을 때 먼저 거절)
  └ master 재검증 + 선점 갱신          ← slave 복제 지연 회피
  └ lease.renew()                      ← TTL 만료 시 두 번째 요청이 PG 를 중복 호출
  └ 포인트·쿠폰 반환   ┐
  └ 멤버십 반환        ├ 실패하면 역순 보상(rollback)
  └ PG 취소 호출       ┘
  ───────── 이 선을 넘으면 PG 는 이미 취소됨. 어떤 경로도 보상하지 않는다 ─────────
  └ 원장 확정 + 운영자 행위 기록 (한 트랜잭션)
  └ 알림 발송 (실패해도 결과를 바꾸지 않음 — 삼키고 로그만)
```

### 실패를 세 갈래로 나눕니다

| 예외 | 의미 | 처리 |
|---|---|---|
| `PgCallNotAttemptedException` | PG 를 **부르지 않았다** | 보상 후 전파 |
| `PaymentCancelFailedException` | PG 가 **거절했다** | 보상 후 전파. **감싸지 않습니다** — *"감싸면 거절 코드가 502 로 뭉개진다"* |
| **`PgOutcomeUnknownException`** | **갔는지 모른다** | **보상하지 않고** 전파 |

`PgOutcomeUnknownException` 은 세 경우에 납니다 — ① PG 응답 불명, ② **리워드 이중 반환**(같은 리워드를 두 번, `DuplicateKeyException`), ③ **PG 취소는 됐는데 원장 확정 실패**. 각각 로그 문구가 다르고, PG 를 실제로 불렀는지에 따라 *"수동 환수 필요"* 와 *"원장 대조 필요"* 로 갈립니다.

> 💡 **"아는 것만 꺼낸다"** — PG 결과를 응답에 담는 헬퍼에 이런 주석이 있습니다: *"비우면 화면이 '갔는지 모른다' 고 거짓말한다."* 금액·통화·승인시각을 알면 채우고 모르면 비웁니다.

## 정책 계층

`application/service/policy` 에 규칙을 모았습니다.

| 클래스 | 역할 |
|---|---|
| `RefundAmountPolicy` (+`amount/FullVoidAmountPolicy`·`FundReturnAmountPolicy`) | 환불 금액 계산 — 전액 취소 / 부분 반환 |
| `PaymentCancelAmountPolicy` | PG 에 보낼 금액(통화 환산 포함) |
| `RefundValidationPolicy` · `CommonRefundRules` | 환불 가능 여부 판정 |
| `ShippingRefundPolicy` | 배송비 환불 |
| `RefundPolicyResolver` | 상황에 맞는 정책 선택 |

부가 반환은 서비스로 분리돼 있습니다 — `PointCouponRefundService`(포인트·쿠폰) · `MembershipRefundService`(멤버십) · `CurrencyExchangeService`(환전).

## 외부 연동

`application/port/out` 의 클라이언트 포트 8종입니다.

| 포트 | 대상 |
|---|---|
| `PaymentClient` | **PG 취소** — `PaymentClientRouter` 가 `NicePayClient` / `KrPaymentClient` 로 분기 |
| `PointClient` · `CouponClient` | 포인트·쿠폰 반환 |
| `MembershipClient` | 멤버십 혜택 |
| `CurrencyExchangeClient` | 환율 |
| `NotificationClient` (+ `AlimtalkClient` · `MailClient`) | 알림톡·메일 |

- `OutboundBulkhead` 로 **아웃바운드 동시 호출을 제한**합니다. PG permit 은 **호출 구간만** 잡습니다 — 주석: *"여기서 잡으면 원장·알림까지 물고 있다."*
- 분산 락은 `RedisRefundLock`, 예약 청구 상태는 `RedisReservationChargeStatus` 입니다.

## 운영을 위한 장치

### correlationId

모든 로그 줄에 `correlationId` 를 싣습니다(`logging.pattern.level: "%5p [%X{correlationId:-}]"`). 주석에 이유가 있습니다 — ***"손으로 넘긴 줄만 추적되면 빠뜨린 줄(예: 보상 실패의 종단 로그)이 어느 요청인지 알 수 없다."*** 응답에도 함께 내려줍니다.

### 메모리 예산을 코드에 박았습니다

`order-application-api/build.gradle` 의 jib 설정에 **실측 근거가 주석으로** 남아 있습니다.

```
jvmFlags = ['-XX:+UseG1GC', '-Xmx448m', '-XX:MaxMetaspaceSize=256m']
```

- 컨테이너 limit **1Gi 기준**: 힙 448m + 메타 256m + 코드캐시·스레드·다이렉트 ~150m ≒ 850m
- `MaxRAMPercentage=70` 에 맡기면 **힙만 717m 을 잡아 OOMKilled(137)** 가 났습니다.
- 메타스페이스 로컬 실측은 75MB(클래스 18,418개)인데 **Datadog 에이전트의 바이트코드 계측이 얹히면 두 배**가 돼, 128m 으로는 `OutOfMemoryError: Metaspace` 가 났습니다.

### 설정 소유권을 문서로 못 박았습니다

README 에 규칙이 있습니다 — **타임아웃과 그 비율은 저장소(`application-infrastructure.yml`)가, 풀 크기·URL·시크릿은 gitops configmap 이** 소유합니다. 그리고 ***"레포에 크기 기본값을 두지 않는다 — ConfigMap 이 안 붙어도 기동이 성공해 축소 운전이 조용히 지속된다."*** `PoolBudgetValidator` 가 이를 검사합니다.

## 배포 — 아직 live 가 아닙니다

| 브랜치 | 환경 | 갱신 대상 values | 현재 imageVersion |
|---|---|---|---|
| **`master`**(기본) | clive | `core/clive/order-api.yaml` | **`master-000000000000-00000000`** ← 자리표시자 |
| `dev` | dev | `core/dev/order-api.yaml` | `dev-202609151716-f0b6693e` |
| `rc4` | rc4 | `core/rc4/order-api.yaml` | `rc4-202609021518-2c079a0e` (2026-09-02 이후 정체) |

> ⚠️ **`master` 에는 커밋이 1개뿐입니다**(`5b6f11f` "초기 프로젝트 구조", 2026-08-31). 실제 코드는 전부 `dev`(195커밋)에 있고, gitops 의 clive 이미지 태그는 **한 번도 갱신되지 않은 자리표시자**입니다. 즉 **클라우드 라이브 배포 전**이며, 이 문서는 `dev` 기준으로 작성했습니다.

- ECR: dev·rc4 는 `843734097580`, live 는 `393290902814` 계정입니다. 이미지 주소·태그는 **CI 가 `-Djib.to.image`/`-Djib.to.tags` 로 주입**합니다 — build.gradle 에 박으면 두 계정이 갈릴 때 어긋나기 때문입니다(주석).
- helm: `subPath: order`, `containerPort: 8080`, 메모리 **dev 1Gi / clive 2Gi**.
- 사내 아티팩트(`wave-crypto`)는 GitHub Packages(`wadiz-repo/maven-releases`)에서 받고, **CI 가 `-PgprUser`·`-PgprPassword` 로 자격증명을 넣습니다.**

## 테스트

**61개**(core 49 · api 13). 규모 상위는 이렇습니다.

| 테스트 | 줄 | 대상 |
|---|---:|---|
| `RefundEngineTest` | 330 | 실행 순서·보상·실패 분류 |
| `RefundRepositoryImplTest` | 327 | 원장 퍼시스턴스 |
| `ClaimCreationTest` | 267 | 반환 신청 생성 |
| `PointCouponRefundServiceTest` | 231 | 포인트·쿠폰 반환 |
| `RedisRefundLockTest` | 212 | 분산 락 |
| `RefundRequestValidationTest` | 205 | 요청 검증(web) |
| `ClaimApplicabilityTest` | 202 | 신청 가능 판정 |
| `PgOutcomeUnknownContractTest` | 178 | **"갔는지 모름" 응답 계약** |

- `RefundKind` 주석이 *"전체 표는 `RefundKindExclusionTest` 가 갖는다"* 고 명시합니다 — **규칙 표를 테스트가 소유**하는 방식입니다.

## 관련 저장소

| 저장소 | 관계 |
|---|---|
| [`com.wadiz.web`](./com.wadiz.web.md) | 로직 출처. 같은 테이블·상태값을 공유. `RWD-6027`(취소·반환 원장에 행위 주체 기록)·order 서버 프록시 경로 추가가 이쪽과 짝 |
| [`co.wadiz.adm`](./co.wadiz.adm.md) | 어드민. `RWD-6027` 로 `RefundActorType` 을 함께 도입 |
| [`com.wadiz.api.funding`](./com.wadiz.api.funding/com.wadiz.api.funding.md) | `RWD-6027` 로 취소 원장에 행위 주체 기록 |
| `nicepay-api` · `kr.wadiz.api.payment` | **PG 실집행은 계속 이쪽이 담당** |
| [`helm-charts`](./helm-charts.md) · [`helm-charts-gitops`](./helm-charts-gitops.md) | `core/{dev,rc4,clive}/order-api.yaml` |

## 미확인 항목

- **`master` 로의 승격(= clive 배포) 시점** — 저장소만으로는 알 수 없습니다.
- **배치 모듈의 트리거** — README 에 *"트리거 미정"* 이라고 적혀 있습니다.
- **레거시와의 이관 진척도** — `com.wadiz.web`·`co.wadiz.adm` 의 어떤 경로가 이미 이 서비스를 타고 어떤 것이 아직 레거시인지. `com.wadiz.web` 의 order 프록시 경로(`proxy-*.xml`, RWD-6027)를 함께 봐야 합니다.
- **설계 위키의 내용** — README 가 지목한 Confluence 문서(18111365146)가 판단 근거의 정본입니다. 이 문서는 코드에서 읽을 수 있는 것만 담았습니다.
- `RefundClaim` 신청 흐름의 상태 전이 전수 — `ClaimApplicability`·`ClaimWindow` 조합은 이번 범위에서 전수 확인하지 않았습니다.
- dev·clive 의 실제 운영 설정(DB·Redis 접속, 외부 API URL·토큰, 풀 크기) — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `core/{env}/order-api.yaml` `configmap.data` 참조.
