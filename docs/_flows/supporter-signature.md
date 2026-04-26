# Flow: 서포터 서명 (지지서명 V3)

> 서포터가 프로젝트에 "응원/지지서명"을 남기는 체인. FE → com.wadiz.web 내부 컨트롤러 → **RestTemplate 으로 com.wadiz.wave.user 호출** → MyBatis → MySQL.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/support-share.service.ts:161-517` (FE 호출)
  - `com.wadiz.web/src/main/java/.../web/WEB-INF/web.xml:192` (`/api/*` → REST Filter)
  - `com.wadiz.web/src/main/java/kr/wadiz/signature/v3/controller/SupporterSignatureV3Controller.java:30-225`
  - `com.wadiz.web/src/main/java/kr/wadiz/signature/v3/service/SupporterSignatureV3UserService.java:1-40`
  - `com.wadiz.web/src/main/java/kr/wadiz/infrastructure/signature/v3/SupporterSignatureV3UserGatewary.java:40-90` (RestTemplate)
  - [`docs/com.wadiz.wave.user/api-details/signature-v3.md`](../com.wadiz.wave.user/api-details/signature-v3.md) (Phase 2 기존 분석, SQL 포함)
- **외부 경계**: `restTemplateForUserGateway` bean 설정(타임아웃/retry/인증 헤더), V3 API 내부 이벤트 발행 (RabbitMQ), `PushGateway` / `SupporterSignatureNotificationClient` 구체.

---

## 🔑 중요 — 3번째 요청 처리 모드
A1 플로우에서 언급한 세 요청 패턴 외에, **네 번째 패턴**이 등장:

| 경로 | 처리 방식 |
|---|---|
| `/web/apip/*` | ApiProxyServlet 투명 프록시 → funding/store API (A1 참조) |
| `/web/reward/api/*` | com.wadiz.web 자체 `@Controller` + MyBatis (자체 DB 접근) |
| `/web/wpurchase/*` | JSP 페이지 + AJAX |
| **`/web/v3/supporter-signatures/*`** ← | **com.wadiz.web `@Controller` → `RestTemplate` 으로 com.wadiz.wave.user 호출** |

`com.wadiz.web` 이 내부에서 Spring RestTemplate 으로 `com.wadiz.wave.user` 를 호출하는 별도의 백엔드 래핑 계층이다.

---

## 1. Client Trigger (FE)

### 1.1 주요 API 매트릭스 (V3)
```ts
// packages/api/src/web/support-share.service.ts

POST   /web/v3/supporter-signatures                                      // 161  지지서명 생성
GET    /web/v3/supporter-signatures?...                                  // 173  목록
PUT    /web/v3/supporter-signatures/{signatureId}                        // 184  수정
GET    /web/v3/supporter-signatures/{signatureId}                        // 309  단건
GET    /web/v3/supporter-signatures/count?encUserId=&campaignId=         // 348  개수
GET    /web/v3/supporter-signatures/status?campaignId=&encUserId=        // 364  서명 여부/상태
GET    /web/v3/supporter-signatures/user-images?campaignId=...           // 335  서명자 이미지
GET    /web/v3/supporter-signatures/keywords                             // 296  키워드
GET    /web/v3/supporter-signatures/points/total                         // 456  전체 포인트
GET    /web/v3/supporter-signatures/points                               // 468  포인트 목록
GET    /web/v3/supporter-signatures/{signatureId}/points                 // 504  서명별 포인트 상세
```

### 1.2 댓글·리액션 (V2 유지)
```ts
POST   /web/v2/supporter-signatures/{commentId}/comments                 // 218
GET    /web/v2/supporter-signatures/{commentId}/comments                 // 230
PUT    /web/v2/supporter-signatures/{commentId}/comments/{replyId}       // 242
DELETE /web/v2/supporter-signatures/{commentId}/comments/{replyId}       // 261
PUT    /web/v2/supporter-signatures/{commentId}/reactions/{typeId}       // 199
PUT    /web/v2/supporter-signatures/comments/{commentId}/reactions/...   // 277
```
V2 는 댓글/리액션에 한정. 서명 본문은 V3 로 통합됨.

---

## 2. Hub — `com.wadiz.web`

### 2.1 Controller
```java
// com.wadiz.web/src/main/java/kr/wadiz/signature/v3/controller/SupporterSignatureV3Controller.java:30
@Controller
@RequestMapping(value = "/web/v3/supporter-signatures")
public class SupporterSignatureV3Controller {
    @Autowired private SupporterSignatureV3Service supporterSignatureV3Service;
    @Autowired private SupporterSignatureV3UserService supporterSignatureV3UserService;

    @PostMapping("")                                              // :143
    public SignatureInfoV3 createSignature(@RequestBody @Valid CreateSignatureRequestV3 request) {
        if (SessionUtil.getUserId() < 0) {
            throw new UserUnauthorizedException();
        }
        return supporterSignatureV3UserService.createSignature(SessionUtil.getUserId(), request);
    }

    @GetMapping("")                                               // :161  목록
    @PutMapping("/{signatureId}")                                 // :200  수정
    @GetMapping("/{signatureId}")                                 // :220  단건
    @GetMapping("/count")                                         // :75
    @GetMapping("/status")                                        // :124
    @GetMapping("/id")       @Deprecated                          // :106
    @GetMapping("/keywords")                                      // :43
    @GetMapping("/user-images")                                   // :55
}
```
세션 기반 인증(`SessionUtil.getUserId()`), 음수면 `UserUnauthorizedException`.

### 2.2 Service → Gateway
```java
// kr/wadiz/signature/v3/service/SupporterSignatureV3UserService.java:24
public SignatureInfoV3 createSignature(Integer userId, CreateSignatureRequestV3 request) {
    return supporterSignatureV3UserGateway.createSignature(userId, request);
}
```

### 2.3 Gateway — RestTemplate 으로 wave.user 호출

> 📅 **2026-04-26 검증** — RestTemplate target host 확정:
> - `SupporterSignatureV3Gatewary` baseUrl = `${file['user_api_base_uri']}/v3/supporter-signatures`
> - `SupporterSignatureGateway` (V1) = `${file['user_api_v1_base_uri']}/users/supporter-signatures`
> - 환경별 `user_api_base_uri` 값 (`src/main/resources/properties/file-{env}.properties`):
>   - rc3: `http://rc3-private-gateway.wadizcorp.com:9990/user/api`
>   - rc: `http://rc-api01:9990/user/api`
>   - stage: `http://172.31.1.12:9990/user/api`
>   - local: `http://dev-app01:9990/user/api`
>
> → 모두 **9990 사설 게이트웨이 → wave.user** 경로. **community(9011) 로의 전환 아직 미적용**.
>
> 즉 `co.wadiz.api.community` 가 V3 11 컨트롤러 풀 구현 (2026-04-26 기준) 됐어도, com.wadiz.web 은 여전히 wave.user 를 호출 중. **두 백엔드가 공존하는 상태**이며 cutover 타이밍은 별도 추적 필요.

```java
// kr/wadiz/infrastructure/signature/v3/SupporterSignatureV3UserGatewary.java:40
@Autowired
@Qualifier("restTemplateForUserGateway")
private RestTemplate restTemplate;

// baseUrl = ${file['user_api_base_uri']}/v3/users/  → 9990 게이트웨이 → wave.user

public SignatureInfoV3 createSignature(final Integer userId, final CreateSignatureRequestV3 request) {
    UriComponents uri = UriComponentsBuilder.fromUriString(baseUrl)
        .pathSegment("{userId}", "supporter-signatures")
        .buildAndExpand(userId);

    HttpEntity<CreateSignatureRequestV3> entity = new HttpEntity<>(request, defaultV3Headers());
    ResponseEntity<SignatureInfoV3> response =
        restTemplate.postForEntity(uri.toUriString(), entity, SignatureInfoV3.class);
    return response.getBody();
}
```
→ 실제 요청: `POST http://{wave.user.host}/api/v3/users/{userId}/supporter-signatures`
- `defaultV3Headers()` 에 내부 식별/인증 헤더 추가 (추정: 사내 신뢰 토큰)
- `restTemplateForUserGateway` bean 에서 timeout/error-handler 구성

---

## 3. Backend Service — `com.wadiz.wave.user`

V3 엔드포인트 전체 상세·SQL 은 기존 분석 문서 참조:

- [`docs/com.wadiz.wave.user/api-details/signature-v3.md`](../com.wadiz.wave.user/api-details/signature-v3.md) (574줄)
  - 컨트롤러: `SupporterSignatureV3UserController` (`/api/v3/users/{userId}/supporter-signatures`)
  - 관련 MyBatis XML 6개: supporterSignature / Keyword / KeywordData / Point / Share / Tracking
  - 외부 호출: `PushGateway`, `SupporterSignatureNotificationClient`

### 관련 wave.user 엔드포인트 (참고)

| com.wadiz.web 경로 | wave.user 내부 경로 | 용도 |
|---|---|---|
| POST `/web/v3/supporter-signatures` | POST `/api/v3/users/{userId}/supporter-signatures` | 서명 생성 |
| PUT `/web/v3/supporter-signatures/{id}` | PUT `/api/v3/users/{userId}/supporter-signatures/{id}` | 서명 수정 |
| GET `/web/v3/supporter-signatures/count` | GET `/api/v3/supporter-signatures/count` | 개수 (비사용자 컨트롤러) |
| GET `/web/v3/supporter-signatures/{id}` | GET `/api/v3/supporter-signatures/{id}` | 단건 |
| GET `/web/v3/supporter-signatures/keywords` | GET `/api/v3/supporter-signatures/keywords` | 키워드 |

---

## 4. DB

### 4.1 주요 테이블 (com.wadiz.wave.user MySQL)
[signature-v3.md 참조](../com.wadiz.wave.user/api-details/signature-v3.md):

| 테이블 | 역할 |
|---|---|
| `t_supporter_signature` | 서명 본문 (userId, campaignId, text, imageUrl, status, RegDate) |
| `t_supporter_signature_keyword` | 서명 ↔ 키워드 매핑 |
| `t_supporter_signature_keyword_data` | 키워드 마스터 |
| `t_supporter_signature_tracking` | 트래킹/노출 이력 |
| `t_supporter_signature_point` | 서명으로 적립된 포인트 |
| `t_supporter_signature_share` | 공유 통계 |

### 4.2 생성 트랜잭션 (추정 순서)
1. INSERT `t_supporter_signature` (본문)
2. Keyword NLP/추출 → INSERT `t_supporter_signature_keyword` (N 개)
3. Tracking 이벤트 INSERT `t_supporter_signature_tracking`
4. 포인트 적립 정책 만족 시 INSERT `t_supporter_signature_point` (+ 외부 포인트 서비스 호출 가능성)
5. Push 발송: `PushGateway` → 푸시 서비스

---

## 엔드투엔드 시퀀스

```
[FE: 프로젝트 상세 페이지 → "응원하기" 모달에서 텍스트·키워드 선택]
   │ POST /web/v3/supporter-signatures
   │    body: { campaignId, text, keywords[...], imageUrl?, ... }
   │    (쿠키 세션, credentials: same-origin)
   ▼
[www.wadiz.kr — com.wadiz.web]
   │
   ├─ SupporterSignatureV3Controller#createSignature        [v3/controller/:143]
   │     SessionUtil.getUserId() > 0 검증 → UserUnauthorizedException 방어
   │
   ├─ SupporterSignatureV3UserService.createSignature       [v3/service/:24]
   │
   └─ SupporterSignatureV3UserGatewary.createSignature      [infrastructure/.../:46]
         │  restTemplateForUserGateway 로 내부 HTTP POST:
         │     POST {waveUserBaseUrl}/{userId}/supporter-signatures
         │     headers: defaultV3Headers()  (사내 신뢰 토큰)
         │     body: CreateSignatureRequestV3
         ▼
[com.wadiz.wave.user — SupporterSignatureV3UserController#create]
   │
   ├─ 서비스 로직 (signature-v3.md 참조):
   │   ├─ INSERT t_supporter_signature
   │   ├─ INSERT t_supporter_signature_keyword (N rows)
   │   ├─ INSERT t_supporter_signature_tracking
   │   ├─ (포인트 정책 충족 시) INSERT t_supporter_signature_point + 외부 포인트 API 호출
   │   └─ 알림: PushGateway / SupporterSignatureNotificationClient
   │
   └─ Response: SignatureInfoV3
         ▲
         │ restTemplate response.getBody()
         │
[com.wadiz.web → FE]
   → JSON { signatureId, createdAt, ... }
   → FE: 캐시 무효화 (count, list), 완료 모달
```

---

## 경계·미탐색

1. **`restTemplateForUserGateway` Bean 설정** — timeout, retry 정책, connection pool, `ErrorHandler`, `defaultV3Headers()` 내부 토큰 생성 방식 확인 필요 (공유 시크릿 vs mTLS).
2. **V3 데이터 모델 + wave.user 이관 중** — `co.wadiz.api.community` 로 Signature V3 이관이 Phase 0~1 스캐폴드 단계. 향후 이 gateway 의 `baseUrl` 이 community 로 전환 예정 (별도 flow 로 업데이트 필요).
3. **포인트 적립 조건** — 첫 서명, 특정 캠페인, 제휴 캠페인(affiliate) 등 어떤 정책이 있는지 signature-v3.md 의 AffiliateV3 섹션 참조.
4. **Push 전송 실패 시** — 포인트 적립/서명 생성 트랜잭션이 push 실패로 롤백되는지 아닌지 (일반적으로 best-effort, 이벤트 큐로 분리 추정).
5. **댓글 V2 유지 이유** — 서명 본문은 V3, 댓글/리액션은 V2. 이관 계획 및 버저닝 정책 확인.
6. **wave.user → `kr.wadiz.user.link` Kafka 연계** — 서명 생성 시 그래프 DB(Neo4j) 에 `:SIGNATURE` 관계가 쌓이는 Kafka consumer 가 존재([kr.wadiz.user.link.md](../kr.wadiz.user.link.md) 의 `KafkaSignatureConsumer`). wave.user 가 Kafka publish 하는 시점은 별도 추적.
7. **`encUserId` 암호화** — 다른 사용자의 서명 조회 시 userId 를 암호화하여 노출 방지. 키 로테이션·만료 정책은 별도.
