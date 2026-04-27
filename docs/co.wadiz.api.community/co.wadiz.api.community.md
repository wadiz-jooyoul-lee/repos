# co.wadiz.api.community

> 📅 **2026-04-26 master pull (36 커밋, 224 파일 +)** — 본 분석 baseline 시점에는 Phase 0~1 스캐폴드 였으나, 현재는 **Phase 6 v1.3.0 풀 구현 완료**. 이 문서 본문은 baseline 기준 (구버전). 현재 구현은 아래 박스 참조.
>
> ### 현재 상태 (2026-04-26)
> - **202 Java 파일**, **37 REST endpoint**, 10 Swagger Tag
> - 서비스 포트 `9011` (이전 8080)
> - Java 25 `--enable-preview` (StructuredTaskScope JEP 505), Virtual Thread, Jackson 3 + 2.x annotations 호환, RestClient 단일화
> - 모듈 구조:
>   ```
>   src/main/java/co/wadiz/community/
>   ├── config/{middleware, properties, db}
>   ├── integration/{mail, user, push, campaign, points, event}
>   ├── module/supporter_signature/   # ★ wave.user V3 11 컨트롤러 풀 이관
>   │   ├── controller/ service/ repository/{entity,mapper,param}
>   │   ├── dto/{request,response}/{signature,point,affiliate,communication,keyword}
>   │   ├── integration/{cache, notification}
>   │   ├── component/, model/{constant, domain}, event/
>   └── shared/{wadiz, response, cache, util, common, error}
>   ```
> - **공개 API 11 컨트롤러** (V3, wave.user 와 동일 경로):
>   `/api/v3/supporter-signatures{,/keywords,/points,/interest-degree}`,
>   `/api/v3/users/{userId}/supporter-signatures`, `/api/v3/supporter-signatures/{comments,affiliates}` 등
> - 사내 `ARCHITECTURE.md` 추가 — Modular Monolith 설계 철학
>
> ### 분석 영향
> - **`docs/_flows/supporter-signature.md`** — 기존엔 `com.wadiz.web → RestTemplate → wave.user`. 현재 community 가 동일 V3 경로 풀 구현 상태이므로 **RestTemplate target 이 community(9011)로 전환됐는지 / 라우팅 분기 중인지 검증 필요**.
> - **Phase 2 승격 권장**: 단일 파일 → `docs/co.wadiz.api.community/api-details/` 폴더로 분할 (module/integration/shared 별 심화).

---

## 개요
`com.wadiz.wave.user` 의 **Supporter Signature V3** 모듈을 독립 서비스로 포팅하며, 신규 커뮤니티 기능(messaging, points, campaign 등)을 함께 개발 중인 신규 서비스입니다. **(baseline 시점 Phase 0~1 스캐폴드)** — 현재는 풀 구현 (위 박스 참조). Org: `wadiz-service`.

## 기술 스택 (현 시점)
- **Java 25** (LTS toolchain)
- **Spring Boot 4.0.5**
- **Gradle 9.4.1 Kotlin DSL**
- **MyBatis 4.0.1** + **QueryDSL 7.0** (`io.github.openfeign.querydsl` fork)
- **MapStruct 1.6.3**
- **SpringDoc 3.0.0** (OpenAPI)
- Redis, RabbitMQ, JPA(예정)
- 가장 신스택 — 회사 내 미래 표준 검증용 성격.

## 아키텍처 (계획)
- 모듈형 레이어드 + CQRS 유사 패턴 추정 (도메인 미구현 상태).
- 패키지 prefix: `co.wadiz.community.*`.
- 도메인 후보: `signature` (서명/펀딩 응원), `campaign`, `points`, `messaging`.
- Hexagonal/DDD 구조는 community.signature.repository 매퍼 패키지 참조로 보아 layered + repository pattern 으로 시작 추정.

## 현재 코드 구성

```
src/main/java/co/wadiz/community/
├── CommunityApplication.java        ← @MapperScan("co.wadiz.community.domain.signature.repository.mapper")
└── config/
    ├── AsyncConfig.java             ← signatureTaskExecutor (core 4 / max 8 / queue 50, prefix sig-async-)
    ├── DdlAutoSafetyGuard.java      ← non-embedded JDBC URL일 때 ddl-auto 위험값 차단
    ├── HttpClientConfig.java        ← campaign/campaignShort/point RestClient 3종
    ├── MybatisConfig.java
    ├── RabbitMqConfig.java          ← DirectExchange("community.signature.exchange")
    ├── RedisConfig.java
    ├── SecurityConfig.java          ← 현재 .anyRequest().permitAll() (OAuth2 JWT 활성화는 Phase 6 예정)
    └── WebConfig.java

src/main/resources/
├── application.yml
├── application-dev.yml
└── META-INF/spring.factories         ← DdlAutoSafetyGuard EnvironmentPostProcessor 등록

src/test/java/co/wadiz/community/
├── CommunityApplicationTests.java
└── DdlAutoSafetyGuardTest.java
```

## API 엔드포인트 목록
- **현재 0개** — `@RestController` 가 아직 정의되지 않음.
- `@MapperScan` 이 가리키는 `co.wadiz.community.domain.signature.repository.mapper` 패키지도 미존재.
- Phase 진행 시 signature/campaign/points/messaging 도메인 추가 예정.

## 주요 설정 분석

### `HttpClientConfig.java`
3개의 `RestClient` Bean — community 가 외부 점수/캠페인 서비스를 호출하는 구조 사전 정의:

| Bean | connect / read | 용도 |
|---|---|---|
| `campaignRestClient` | 5s / 10s | 캠페인 일반 호출 |
| `campaignShortRestClient` | 1s / 2s | 캠페인 빠른 응답용 (two-tier SLA) |
| `pointRestClient` | 5s / 10s | 포인트 적립/차감 호출 |

### `RabbitMqConfig.java`
- DirectExchange: `community.signature.exchange` (레거시 `userApiExchange` 와 명시적으로 단절 — 새 네이밍 채택).

### `AsyncConfig.java`
- `signatureTaskExecutor` (core 4 / max 8 / queue 50, thread prefix `sig-async-`) — 서명 후속 처리(이벤트 발행, 알림 등) 비동기 디스패치용.

### `DdlAutoSafetyGuard.java`
- `EnvironmentPostProcessor` 로 등록.
- prod/stage 환경(임베드 JDBC URL 아님)에서 `spring.jpa.hibernate.ddl-auto` 가 `create`/`create-drop`/`update` 면 부팅 차단.
- 운영 사고 방지용 가드. `META-INF/spring.factories` 통해 자동 활성.

### `SecurityConfig.java`
- 현재 `.anyRequest().permitAll()` — Phase 6 에 OAuth2 Resource Server JWT 검증 활성화 예정 (주석으로 코드 보존).

### dev/test 프로파일
- `spring.autoconfigure.exclude` 로 `RedisAutoConfiguration` / `RabbitAutoConfiguration` 제외.
- 각 Config 에도 `@ConditionalOnBean` 추가로 더블 가드.

## DB 스키마 요약
- 미정 (Entity 0개, Mapper XML 0개).
- 향후 `signature` 도메인부터 테이블 정의 예정 — 레거시 `wave.user` 의 supporter signature 테이블 마이그레이션 또는 신규 설계.

## 외부 의존성 (사전 정의)
- HTTP: campaign 서비스, point 서비스 (RestClient Bean).
- MQ: RabbitMQ exchange `community.signature.exchange` (publisher 역할 추정).
- Cache: Redis (도메인 캐시 예정).
- Auth: OAuth2 Resource Server (Phase 6 활성).

## 특이사항

- **회사 내 최첨단 스택** — Java 25 + Spring Boot 4 + Gradle 9 + QueryDSL 7. 다른 어떤 wadiz repo보다 새로움. 신기술 검증 + 표준 정립 의도.
- **DdlAutoSafetyGuard** 가 `EnvironmentPostProcessor` + `spring.factories` 로 자동 작동 — 사고 방지 패턴 모범 사례.
- **이중 방어 (autoconfigure exclude + ConditionalOnBean)** — dev/test 환경에서 외부 인프라 부재로 부팅 실패 방지.
- **two-tier SLA RestClient** (`campaignShortRestClient` 1s/2s) — 빠른 fallback 용도 사전 마련.
- **Phase 6 OAuth2 활성** 주석 처리 — 인증 통합 시점이 도메인 구현 이후로 잡혀 있음.
- 도메인 코드는 비어 있어 분석 가치는 **설정 패턴** 위주. 진행도 추적은 git log로 확인 권장.
