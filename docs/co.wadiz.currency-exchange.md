# co.wadiz.currency-exchange

> ⚠️ 분석은 `dev` 브랜치 기준입니다. `main` 브랜치는 README만 있는 빈 상태이며 실제 코드는 모두 `origin/dev` 에 있습니다.

> 📅 **2026-04-26 dev pull 보강** (24 커밋, SCOUT-1 시리즈)
>
> ### 신규 엔드포인트 — `display-country-code` 기반 변환
> External 컨트롤러에 **2개 추가** (Internal 에는 없음 — 외부 노출 전용):
> - `POST /api/v1/external/conversion/display-country-code` — 표시 국가 코드로 환전 금액 변환 (단건)
> - `POST /api/v1/external/conversion/display-country-code/bulk` — 일괄 조회
>
> 즉 External 컨트롤러는 **9 endpoint** (이전 7 + 신규 2). Internal 은 **7 endpoint** 동일 (대칭 깨짐).
>
> ### 주요 변경 (SCOUT-1)
> - **`wadiz-country` 헤더로 표시 국가 코드 수신** (한 번에 1개 국가만)
> - 헤더 validation 추가 (`wadiz-country` 미존재/잘못된 값 거부)
> - **소수점 정책 변경**:
>   - 환전 금액: 10째 자리 floor → **3째 자리 ceil** 로 변경
>   - 표시 통화의 소수점 유무에 따라 표시 금액 형식 분기
> - **금액 타입 통일**: 표시 금액(BigDecimal) 외 모두 **Long** 타입으로 변경
> - 매매기준율(baseRate) 에 **weight 반영** 하여 표시 금액 계산
> - 응답 형식 수정 + 누락된 응답 모델 추가
>
> ### 영향
> 본 문서 § "API 엔드포인트 목록" 의 External 컨트롤러는 **9 endpoint 로 갱신** 필요. SQL 변환 로직은 변경 (소수점 정책) 됐으나 OpenSearch 인덱스 구조는 유지.

## 개요
와디즈 글로벌 결제·표시용 **환율 변환 서비스**. 대만달러(TWD), 미달러(USD) 등 외화 ↔ 원화(KRW) 변환을 OpenSearch 인덱스에 저장된 일일 환율 문서를 기반으로 계산합니다. 서포터/메이커 수수료율을 분리해 적용하며, 결제·표시 통화 분리 케이스(payment vs display)도 지원합니다. Org: `wadiz-service`. Java package: `co.wadiz.currencyexchange`.

## 기술 스택
- **Java 21** (toolchain), Virtual Threads 활성화 (`spring.threads.virtual.enabled: true`)
- **Spring Boot 3.4.2**, Spring Cloud `2024.0.0`
- **OpenSearch Java Client 2.8.1** (단일 데이터 저장소 — RDB 없음)
- Hazelcast (분산 캐시)
- Spring Cloud Kubernetes Client Config (k8s ConfigMap 주입)
- **Jib** → ECR `843734097580.dkr.ecr.ap-northeast-2.amazonaws.com/core/currency-exchange-api`
- Spring REST Docs (asciidoctor) — 정적 docs 빌드 후 `bootJar` 에 `static/docs` 로 포함

## 아키텍처
- 단일 모듈, layered (controller → service → repository) 구조.
- 데이터: OpenSearch index `exchange-rate-v2-*` (일자별 환율 문서, 일일 인덱스 추정).
- 서버 포트 `8080`, 헬스체크 `/actuator/health`, 메트릭 `/actuator/metrics`.
- 환율 적재는 외부(별도 배치) — 본 서비스는 **읽기 전용 조회·계산 서비스**.

## API 엔드포인트 목록

`Internal` 과 `External` 두 컨트롤러가 **완전히 동일한 8개 엔드포인트**를 노출합니다 (보안 분리: external은 외부 노출, internal은 사내 호출 — 동일 코드 사용).

| Method | Path | 메서드 | 용도 |
|---|---|---|---|
| POST | `/api/v1/{external\|internal}/conversion` | `convertAmount` | 단건 환율 변환 |
| POST | `/api/v1/{external\|internal}/conversion/bulk` | `convertBulkAmount` | 다건 변환 (그룹별) |
| POST | `/api/v1/{external\|internal}/conversion/multi-currency` | `convertMultiCurrencyAmount` | 결제·표시 분리(2단 환산) |
| POST | `/api/v1/{external\|internal}/conversion/multi-currency/bulk` | `convertMultiCurrencyBulkAmount` | 결제·표시 분리 다건 |
| POST | `/api/v1/{external\|internal}/conversion/direct` | `convertAmountDirectly` | 환율값 직접 받아 변환 (DB 조회 X) |
| POST | `/api/v1/{external\|internal}/conversion/direct/bulk` | `convertBulkAmountDirectly` | 직접 변환 다건 |
| POST | `/api/v1/{external\|internal}/exchange-rate` | `getExchangeRate` | 적용 환율 조회 |

컨트롤러 위치:
- `src/main/java/co/wadiz/currencyexchange/controller/ExternalCurrencyExchangeController.java:13-54`
- `src/main/java/co/wadiz/currencyexchange/controller/InternalCurrencyExchangeController.java:13-54`

## 주요 API 상세 분석

### 1. POST `/conversion` — 단건 환율 변환
- **컨트롤러**: `ExternalCurrencyExchangeController.java:20-23`
- **서비스**: `CurrencyExchangeServiceImpl.java:36-50` `convertAmount`
- **입력 DTO** (`CurrencyConversionRequest`):
  - `baseCurrency: CurrencyCode` (예: USD)
  - `targetCurrency: CurrencyCode` (예: KRW)
  - `amount: BigDecimal`
  - `targetCurrencyUnit: CurrencyUnit` (1, 100 등 단위 스케일)
  - `currencyExchangeFeeType: CurrencyExchangeFeeType` (`SUPPORTER` / `MAKER`)
  - `validAt: LocalDateTime` (이 시점 이전 가장 최근 환율 사용, null 가능)
- **처리 로직**:
  1. `getExchangeRateDocument(base, target, validAt)` — OpenSearch에서 환율 문서 1건 조회.
  2. `getFinalExchangeRate(feeType, doc)` — `SUPPORTER` → `finalSupporterBaseRate`, `MAKER` → `finalMakerBaseRate` 선택.
  3. `CurrencyConversionUtils.convert(amount, rate, 10, FLOOR, unit)` — 소수 10째자리 floor 라운딩.
- **DB 상호작용** (OpenSearch):
  ```
  GET /<index-prefix>exchange-rate-v2-*/_search
  {
    "query": { "bool": { "filter": [
      { "term": { "baseCurrency": "USD" } },
      { "term": { "targetCurrency": "KRW" } },
      { "range": { "announcedAt": { "lte": "2026-04-18T..." } } }   // validAt 있을 때만
    ]}},
    "sort": [
      { "announcedAt": "desc" },
      { "indexedAt":  "desc" }
    ],
    "size": 1
  }
  ```
  - 결과 없으면 `ExchangeRateNotFoundException(EXCHANGE_RATE_NOT_FOUND)`.

### 2. POST `/conversion/multi-currency` — 결제 vs 표시 통화 분리 변환
- **서비스**: `CurrencyExchangeServiceImpl.java:82-111`
- 시나리오: 메이커가 USD로 가격 책정, 서포터에게는 KRW로 표시, 실제 결제는 TWD로 수행.
- **로직**:
  1. `paymentRate = doc(base→payment)` 의 `finalXxxBaseRate` 사용 — 수수료 반영.
  2. 결제 통화로 환산: `convertedPaymentAmount = convert(amount, paymentRate, paymentUnit)`.
  3. `displayRate = doc(payment→display)` 의 `baseRate` 사용 — **수수료 미반영 매매기준율**(표시는 순수 환율).
  4. 표시 금액: `convertedDisplay = convertedPayment × displayRate × displayUnit.scale / paymentUnit.scale`, FLOOR 10자리.
- 두 환율 문서(payment, display)를 한 번에 묶어 반환 (`MultiAmount`).

### 3. POST `/conversion/direct` — 환율 직접 입력
- **서비스**: `CurrencyExchangeServiceImpl.java:157-161`
- DB 조회 없이 호출자가 넘긴 `exchangeRate` 그대로 사용.
- `isReverse` 플래그로 정/역방향(`convert` vs `reverse`) 분기. 결제 취소·환불 등 과거 환율 재현 시 사용 추정.

### 4. POST `/exchange-rate` — 적용 환율 조회
- **서비스**: `CurrencyExchangeServiceImpl.java:189-196`
- 단순히 환율 1건 조회 + 수수료 반영 환율 반환. 화면 표시·검증용.

### 5. POST `/conversion/bulk`, `/conversion/multi-currency/bulk`, `/conversion/direct/bulk`
- **로직**: 그룹 리스트 순회. 각 그룹은 `Map<key, amount>` — 한 번의 OpenSearch 호출로 그룹 내 다수 amount 변환 (성능 최적화: 그룹당 1회 조회).
- 호출자가 여러 가격(원가/판매가/할인가 등)을 한 번에 환산할 때 사용.

## DB 스키마 요약 (OpenSearch)

**Index**: `exchange-rate-v2-*` (alias 또는 일자별 인덱스 와일드카드)

`ExchangeRate` 문서 (`model/index/ExchangeRate.java:16-38`):

| 필드 | 타입 | 의미 |
|---|---|---|
| `id` | String | 문서 ID |
| `baseRate` | BigDecimal | 매매기준율 (수수료 미반영) |
| `baseCurrency` | CurrencyCode | 기준 통화 |
| `targetCurrency` | CurrencyCode | 대상 통화 |
| `weight` | int | 가중치 (다중 소스 통합 시?) |
| `supporterFeeRate` | BigDecimal | 서포터 환전 수수료율 |
| `makerFeeRate` | BigDecimal | 메이커 환전 수수료율 |
| `finalSupporterBaseRate` | BigDecimal | 서포터 수수료 반영 환율 |
| `finalMakerBaseRate` | BigDecimal | 메이커 수수료 반영 환율 |
| `announcedAt` | LocalDate | 환율 공시일 |
| `indexedAt` | LocalDateTime | 인덱싱 시각 (tie-breaker) |

쿼리 패턴 — 항상 `term filter` (base+target) + 옵션 `range filter` (announcedAt ≤ validAt) + 정렬 `announcedAt desc, indexedAt desc` + `size:1`.

## 외부 의존성

- **OpenSearch**: 환율 문서 조회. URL은 `application-{profile}.yml` 의 `opensearch.*` 또는 k8s ConfigMap 주입.
- **Hazelcast**: 분산 캐시 (환율 문서 in-memory 캐시 추정 — actuator health 비활성으로 보아 ES health도 분리 운영).
- **Spring Cloud Kubernetes**: 운영 환경 ConfigMap/Secret 주입.
- **Index Prefix**: `index.prefix` 환경변수로 dev/stage/live 인덱스 분리 (`indexProperties.appendPrefix(...)`).
- 외부 PG/배치(환율 적재 주체)는 별도 시스템.

## 특이사항

- **읽기 전용 환율 조회 서비스** — 환율 데이터 적재(스케줄러/배치)는 다른 시스템에서 수행, 본 서비스는 조회·계산만.
- **Virtual Threads 활성** — Boot 3.4 + JDK 21 조합에서 IO-bound API에 적합.
- **Internal vs External 컨트롤러 동일 로직** — 라우팅·인증 분리 목적으로 코드 복제. SecurityConfig 분기 가능성 높음 (현 시점 미확인).
- **소수점 10째 floor** — 일관된 라운딩 정책으로 정합성 보장 (서버/클라이언트 모두 동일 규칙 필요).
- **두 단계 환율 (payment / display)** — 글로벌 다통화 표시 요구사항 반영. display 환율은 "매매기준율"(`baseRate`), payment 환율은 수수료 반영(`finalXxxBaseRate`).
- README가 "환전 서버" 한 줄뿐이라 main 브랜치를 처음 클론하면 빈 repo로 보임 — `dev` 브랜치 체크아웃 필요.
- Spring REST Docs로 `index.adoc` → 정적 문서가 `static/docs` 로 임베드되어 운영 시 `/docs/...` 로 접근 가능.
- ECR repo path `core/currency-exchange-api` — 인프라 팀에서 "core" 도메인으로 분류.
