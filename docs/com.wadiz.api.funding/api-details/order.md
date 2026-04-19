# Order 도메인 API 상세 스펙

주문 **세션(OrderSession)** 과 **주문서(OrderSheet)** 관리. 결제 전 임시 상태를 Redis 기반 TTL로 유지.

- **Controller**: `adapter/application/.../domain/order/OrderController.java`
- **Base Path**: `/api/orders`
- **Proxy / Usecase**: `OrderProxy` → `CreateOrderSessionUsecase`, `OrderSessionDetailUsecase`, `CreateOrderSheetUsecase`, `DeleteOrderSheetUsecase`, `FindClosedSessionUsecase`
- **저장소**: Redis (TTL 기반)
  - `OrderSession` : `@RedisHash(timeToLive = 600)` — 10분
  - `OrderSheet` : `@RedisHash(timeToLive = 600)` — 10분
  - `ClosedOrderSession` : `@RedisHash(timeToLive = 10)` — 10초(결제 직후 리다이렉트용)
- **Repository**: Spring Data KeyValue (`OrderSessionKeyValueRepository`, `OrderSheetKeyValueRepository`, `ClosedOrderSessionKeyValueRepository`)

> **기록 범위**: 본 문서는 **이 레포(com.wadiz.api.funding)에서 직접 추적 가능한 호출만** 기록한다.  
> `OrderProxy`가 호출하는 Usecase 구현체는 외부 jar(`com.wadiz.funding.core:funding-core`)에 있어 **이 레포에서는 Usecase 내부의 호출 순서/로직을 확인할 수 없다.**  
> 따라서 "이 API 호출 시 Redis 외 어떤 DB 연산이 일어나는가"는 이 문서에 기록하지 않는다 (가설 금지). Redis 연산은 이 레포의 Gateway 구현체에 코드로 존재하므로 기록 대상이다.

---

## 1. POST `/api/orders/session` — 주문 세션 생성

결제 플로우의 시작점. 선택한 리워드/옵션/배송지 등을 받아 Redis에 세션을 생성하고 10분 TTL 토큰을 반환한다.

- **Method**: `OrderController.createSession`
- **Consumes**: `application/json`
- **Auth**: 로그인 필요 (`SecurityUtils.currentUserId()`)

### Request Body — `OrderSessionRequest`

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `campaignId` | `Long` | ✅ `@NotNull` | 프로젝트 식별자 |
| `rewards` | `List<RewardOrder>` | ✅ `@NotEmpty` | 주문 리워드 항목 (빈 리스트 금지) |
| `attributes` | `Attribute` | ⬜ | 후원금·공개여부 등 부가 정보 |
| `secureStateBagKey` | `String` | ⬜ | 뒤로가기 방지 Key |
| `countryCode` | `String` | ⬜ | 배송 국가 코드. 빈 값이면 `KR` 기본값 |

#### `RewardOrder`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `id` | `Integer` | ✅ `@NotNull` | 리워드 식별자 |
| `qty` | `int` | - | 리워드 수량 (primitive) |
| `memo` | `String` | ⬜ | 옵션 직접 입력 |
| `optionMemo` | `String` | ⬜ | 레거시 옵션 메모 |
| `options` | `List<RewardOptionOrder>` | ⬜ | 단일 옵션 주문 |
| `sets` | `List<RewardSetOrder>` | ⬜ | 세트 옵션 주문 |

#### `RewardOptionOrder`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `id` | `Integer` | ⬜ | 옵션 식별자 |
| `qty` | `int` | - | 옵션 수량 |

#### `RewardSetOrder`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `qty` | `int` | - | 세트 수량 |
| `compositions` | `List<RewardCompositionOrder>` | ⬜ | 옵션 구성 |

#### `RewardCompositionOrder`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `rewardCompositionId` | `Integer` | ⬜ | 구성 식별자 |
| `rewardOptionId` | `Integer` | ⬜ | 옵션 식별자 |

#### `Attribute`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `addDonation` | `long` | - | 후원금 |
| `dontShowNameYn` | `String` | ⬜ | 이름 공개 여부(Y/N) |
| `dontShowAmountYn` | `String` | ⬜ | 금액 공개 여부(Y/N) |
| `apid` | `String` | ⬜ | 지지서명 포인트 지급 Key |

### Response — `CreateOrderSessionResponse` (wrapped in `ResponseWrapper`)

| 필드 | 타입 | 설명 |
|---|---|---|
| `token` | `UUID` | 세션 토큰 (이후 API 호출 시 사용) |

### 컨트롤러 코드 흐름 (이 레포 내에서 관찰 가능한 동작)

1. `SecurityUtils.currentUserId()`로 로그인 사용자 ID 확인
2. `OrderSessionPayloadConverter`로 Request를 `CreateOrderSessionCommand`로 매핑
3. `orderProxy.create(command)` 호출 — 내부에서 `CreateOrderSessionUsecase.create()` 호출 (구현체는 funding-core jar)
4. 반환된 `OrderSessionInfo.token`을 `CreateOrderSessionResponse`로 래핑해 응답

### 이 레포의 Redis Gateway 연산

`OrderSessionRedisGatewayImpl` 구현체가 지원하는 연산 (Spring Data Redis `CrudRepository.save` 동작):

| 연산 | Redis 명령 | 동작 설명 |
|---|---|---|
| `save(OrderSessionInfo)` | `DEL orderSession:{token}` → `HMSET orderSession:{token} <fields>` → `SADD orderSession {token}` → `EXPIRE orderSession:{token} 600` → `EXPIRE orderSession 600` | 기존 키 제거 후 Hash로 필드 일괄 저장, 인덱스 셋에 추가, TTL 600초 부여 |

> Usecase가 위 `save`를 언제·몇 번 호출하는지는 funding-core jar 코드 확인 필요.

---

## 2. GET `/api/orders/session/{token}` — 주문 세션 조회

- **Method**: `OrderController.getSession`
- **Cache**: `@Cacheable("ordersession")` — Proxy 레벨 캐싱

### Path Variable
| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `token` | `UUID` | ✅ | 주문 세션 토큰 |

### Response — `OrderSessionResponse`

| 필드 | 타입 | 설명 |
|---|---|---|
| `token` | `UUID` | 세션 토큰 |
| `userId` | `Integer` | 유저 ID |
| `campaignId` | `Integer` | 프로젝트 ID |
| `orderNo` | `String` | 주문 번호 |
| `totalShippingCharge` | `int` | 배송비 |
| `rewards` | `List<RewardOrder>` | 리워드 주문 정보 |
| `countryCode` | `String` | 배송 국가 코드 |
| `attributes` | `Attribute` | 후원금 정보 |
| `membershipBenefit` | `MembershipBenefit` | 멤버십 혜택(배송비 할인) |
| `couponKey` | `UUID` | 쿠폰 키 |
| `recipient` | `Recipient` | 수령인 정보 |
| `bill` | `Bill` | 청구 금액 |
| `payType` | `String` | 결제 지불 방식 |
| `condition` | `Condition` | 부가 정보(장기할부 등) |

#### `Bill`
| 필드 | 타입 | 설명 |
|---|---|---|
| `fundingAmount` | `long` | 펀딩 금액(리워드+후원금+배송비) |
| `couponDiscountAmount` | `int` | 쿠폰 할인 금액 |
| `applyPoint` | `int` | 적용 포인트 |

#### `Recipient` / `Address`
| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | `String` | 수령인 이름 |
| `phoneNumber` | `String` | 전화번호 |
| `requestMessage` | `String` | 배송 요청 사항 |
| `customsCode` | `String` | 개인통관고유부호 |
| `address.addressLine1` | `String` | 기본 주소 |
| `address.addressLine2` | `String` | 상세 주소 |
| `address.zipCode` | `String` | 우편번호 |
| `address.countryCode` | `String` | 국가 코드 |

### 컨트롤러 코드 흐름 (이 레포 내에서 관찰 가능한 동작)

1. `@PathVariable`로 token(UUID) 수신
2. `orderProxy.get(token, SecurityUtils.currentUserId())` 호출 — Proxy에 `@Cacheable("ordersession")` 적용되어 동일 인자 캐시 히트 시 내부 호출 생략
3. Proxy는 `OrderSessionDetailUsecase.getOrderSession()` 호출 (구현체는 funding-core jar)
4. 반환값을 `OrderSessionPayloadConverter.toResponse()`로 변환해 응답

### 이 레포의 Redis Gateway 연산

| 연산 | Redis 명령 | 동작 설명 |
|---|---|---|
| `findById(UUID)` | `HGETALL orderSession:{token}` | 해당 token의 Hash 전체 필드 조회, 없으면 `Optional.empty` |
| `existsById(UUID)` | `EXISTS orderSession:{token}` | 키 존재 여부 확인 |

> Usecase가 `findById`/`existsById` 중 무엇을 어떤 순서로 호출하는지는 funding-core jar 확인 필요.

---

## 3. GET `/api/orders/closed-session/{token}` — 종료된 주문 세션 조회

결제 실패/완료 직후 클라이언트가 상태를 확인하기 위한 짧은 수명의 별도 저장소(10초 TTL).

- **Method**: `OrderController.getClosedSession`
- **Cache**: `@Cacheable("ordersession")`

### Path Variable
| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `token` | `UUID` | ✅ | 종료된 세션 토큰 |

### Response — `ClosedOrderSessionResponse`

| 필드 | 타입 | 설명 |
|---|---|---|
| `orderNo` | `String` | 주문 번호 |
| `campaignId` | `Integer` | 프로젝트 ID |
| `failureType` | `FailureType` | 실패 유형 enum |
| `failureMessage` | `String` | 실패 메시지 |

### 컨트롤러 코드 흐름 (이 레포 내에서 관찰 가능한 동작)

1. `@PathVariable`로 token(UUID) 수신
2. `ClosedOrderSessionPayloadConverter.map(token, userId)`로 Command 생성
3. `orderProxy.find(command)` — `@Cacheable("ordersession")` 적용
4. Proxy는 `FindClosedSessionUsecase.getClosedSession()` 호출 (구현체는 funding-core jar)
5. 결과의 `orderNo`, `campaignId`, `failureType`, `failureMessage`를 응답에 담아 반환

### 이 레포의 Redis Gateway 연산

| 연산 | Redis 명령 | 동작 설명 |
|---|---|---|
| `findClosedSessionById(UUID)` | `HGETALL closedOrderSession:{token}` | `ClosedOrderSession`(@RedisHash TTL 10s) 조회. 10초가 지난 뒤엔 키 만료로 없음 |
| `save(ClosedOrderSessionInfo)` | `DEL` → `HMSET closedOrderSession:{token}` → `SADD closedOrderSession {token}` → `EXPIRE` 10s | 결제 종료 직후 결과 스냅샷 저장 (이 엔드포인트의 GET 호출에서는 발생하지 않음) |

---

## 4. POST `/api/orders/sheet/{token}` — 주문서 생성

주문 세션 토큰을 받아 최종 결제용 **주문서(OrderSheet)** 를 생성. 결제 지불 방식 · 수령인 정보 · 청구 금액이 확정된다. 응답의 `returnUrl`이 PG사 결제 화면으로의 리다이렉트 URL.

- **Method**: `OrderController.createSheet`
- **Auth**: 로그인 필요

### Path Variable
| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `token` | `UUID` | ✅ | 주문 세션 토큰 |

### Request Body — `OrderSheetRequest`

| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `campaignId` | `Integer` | ✅ `@NotNull` | 프로젝트 ID |
| `couponKey` | `UUID` | ⬜ | 쿠폰 키 |
| `payType` | `String` | ⬜ | 결제 수단 코드 (`PayMethodType`) |
| `bill` | `Bill` | ⬜ | 청구 금액 |
| `recipient` | `Recipient` | ⬜ `@Valid` | 수령인 정보 |
| `condition` | `Condition` | ⬜ | 부가 정보 |

#### `Bill`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `fundingAmount` | `long` | - | 펀딩 금액 |
| `couponDiscountAmount` | `int` | - | 쿠폰 할인 금액 |
| `applyPoint` | `int` | - | 적용 포인트 |

#### `Recipient` / `Address`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `name` | `String` | ⬜ | 수령인 이름 |
| `phoneNumber` | `String` | ⬜ | 전화번호 |
| `requestMessage` | `String` | ⬜ | 배송 요청 |
| `customsCode` | `String` | ⬜ | 통관 부호 |
| `address.addressLine1` | `String` | ⬜ `@Size(max=250)` | 기본 주소 |
| `address.addressLine2` | `String` | ⬜ `@Size(max=96)` | 상세 주소 |
| `address.zipCode` | `String` | ⬜ `@Size(max=16)` | 우편번호 |
| `address.countryCode` | `String` | ⬜ | 국가 코드 |

#### `Condition`
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `longTermInstallment` | `boolean` | - | 장기 할부 여부 |
| `isNowPay` | `Boolean` | ⬜ | 지금 결제 여부(nullable) |

### Response — `OrderSheetResponse`

| 필드 | 타입 | 설명 |
|---|---|---|
| `orderNo` | `String` | 생성된 주문 번호 |
| `returnUrl` | `String` | 결제 페이지 리다이렉트 URL (payType / serviceType별 분기) |
| `retryUrl` | `String` | 재시도 URL (ALI_PAY 전용, 아니면 null) |
| `billingAmount` | `long` | 결제 청구액 |
| `title` | `String` | 프로젝트 제목 |
| `serviceType` | `ServiceType` | 서비스 유형 enum (NICE/STRIPE/ALI_PAY/NONE) |

### 컨트롤러 코드 흐름 (이 레포 내에서 관찰 가능한 동작)

1. `@PathVariable` token, `@RequestBody` request 수신 (`@Valid` 검증)
2. `LocaleContextHolder.getLocale()`로 한국 여부(`isKorea`) 판별
3. `OrderSheetPayloadConverter`로 `CreateOrderSheetCommand` 생성 (token, request, userId, userDevice 결합)
4. `request.getCondition()` + `isKorea`로 `Condition` 생성하여 command에 주입
5. `orderProxy.create(command)` 호출 — 내부에서 `CreateOrderSheetUsecase.create()` 호출 (구현체는 funding-core jar)
6. 반환된 `OrderSheetInfo`에서 `orderNo`, `title`, `serviceType`, `invoice.billingAmount` 추출
7. `getReturnUrl()` / `getRetryUrl()` 로직으로 결제 리다이렉트 URL 생성 (payType/serviceType 분기: NICE / STRIPE / ALI_PAY / NONE)
8. `OrderSheetResponse` 반환

### 이 레포의 Redis Gateway 연산

`OrderSheetRedisGatewayImpl`이 지원하는 연산:

| 연산 | Redis 명령 | 동작 설명 |
|---|---|---|
| `save(OrderSheetInfo)` | `DEL orderSheet:{orderNo}` → `HMSET orderSheet:{orderNo} <fields>` → `SADD orderSheet {orderNo}` → `EXPIRE orderSheet:{orderNo} 600` → `EXPIRE orderSheet 600` | 주문서 Hash 저장, TTL 600초 |
| `findById(String orderNo)` | `HGETALL orderSheet:{orderNo}` | 저장된 주문서 조회 |
| `deleteById(String orderNo)` | `DEL orderSheet:{orderNo}` → `SREM orderSheet {orderNo}` | 주문서 삭제 및 인덱스 정리 |

> Usecase가 위 연산들을 어떤 순서·조건으로 호출하는지는 funding-core jar 확인 필요. 특히 세션 조회가 먼저 일어나는지, 어떤 검증을 거쳐 save가 호출되는지는 이 레포에서 확인 불가.

---

## 5. DELETE `/api/orders/sheet/{token}` — 주문서 삭제

생성된 주문서를 취소(삭제)한다.

- **Method**: `OrderController.deleteSheet`

### Path Variable
| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `token` | `UUID` | ✅ | 주문 세션 토큰 |

### Response
- 본문 없음 (`ResponseWrapper<Void>`). 성공 시 200.

### 컨트롤러 코드 흐름 (이 레포 내에서 관찰 가능한 동작)

1. `@PathVariable` token 수신
2. `OrderSheetDeleteCommand` 생성 (token + `SecurityUtils.currentUserId()`)
3. `orderProxy.delete(command)` — 내부에서 `DeleteOrderSheetUsecase.delete()` 호출 (구현체는 funding-core jar)
4. 본문 없는 200 응답

### 이 레포의 Redis Gateway 연산

| 연산 | Redis 명령 | 동작 설명 |
|---|---|---|
| `deleteById(String orderNo)` | `DEL orderSheet:{orderNo}` → `SREM orderSheet {orderNo}` | 키 삭제 + 인덱스 셋에서 제거 |

> 이 엔드포인트는 path variable이 `token`(UUID)이지만 `OrderSheet`의 Redis 키는 `orderNo`(String)이다. Usecase(funding-core)에서 token → orderNo로 변환하는 조회 단계가 있을 것으로 보이나, 정확한 로직은 이 레포에서 확인 불가.

---

## 6. 저장소 요약

| 엔티티 | TTL | Key | 용도 |
|---|---:|---|---|
| `OrderSession` | 600s (10분) | `UUID token` | 주문 선택 상태 보관 |
| `OrderSheet` | 600s (10분) | `String orderNo` | 결제용 확정 정보 |
| `ClosedOrderSession` | 10s | `UUID token` | 결제 종료 직후 결과 스냅샷 |

### 공통 특징 (이 레포에서 관찰 가능한 사실)
- 모든 엔티티는 **Redis Hash** (`@RedisHash`)로 선언됨
- Spring Data Redis `CrudRepository`/`KeyValueRepository` 사용
- 본 레포 Gateway 구현체가 노출하는 연산: `save` / `findById` / `existsById` / `deleteById` (+ `OrderSessionRedisGateway`는 `findClosedSessionById`, `save(ClosedOrderSessionInfo)` 추가)
- `OrderProxy`의 `get` / `find` 메서드에 `@Cacheable("ordersession")` 적용 → 동일 인자 반복 호출 시 Proxy 아래 단계(Usecase) 호출 생략
- 본 레포 Order 도메인 코드에 **MySQL·JPA·QueryDSL 접근 코드는 존재하지 않음**
- Usecase(비즈니스 로직)는 외부 jar `funding-core`에 있으므로 이 레포만으로는 호출 순서/추가 DB 접근 여부를 확인할 수 없음

---

## 7. 엔드포인트 호출 순서 (컨트롤러 관점)

본 도메인 API들이 일반적으로 호출되는 순서 (실제 호출은 클라이언트 로직에 따름):

```
POST /api/orders/session            → 세션 토큰 발급
GET  /api/orders/session/{token}    → 세션 확인
POST /api/orders/sheet/{token}      → 주문서 생성, returnUrl 반환
(returnUrl은 다른 도메인인 /api/order-payment/... 또는 외부 PG 페이지를 가리킴)
GET  /api/orders/closed-session/{token}  → 결제 종료 직후 결과 확인
```

본 레포 Order 도메인의 컨트롤러는 위 5개 엔드포인트까지만 담당. 이후의 결제 승인/펀딩 확정 흐름은 `orderpayment` 도메인이 처리한다(본 문서 범위 밖).
