# bootstrap 모듈 상세 스펙

> **기록 범위**: `bootstrap/application`, `bootstrap/batch` 엔트리 클래스와 `adapter/application`, `adapter/batch`, `adapter/infrastructure`의 `@Configuration` 클래스 및 `src/main/resources/config/` 하위 YML 파일에서 **직접 관찰 가능한** 선언만 기록.
> Spring Security 내부 동작, 외부 jar(`funding-core`, `reward-http-client` 등) 내부 로직, 런타임 동적 빈 생성 등은 기록 범위 밖이다.
> 시크릿/패스워드 값은 `{{secret}}` 으로 마스킹, URL 호스트는 그대로 기재(내부 망 주소이므로 외부 노출 위험 없음).

---

## 1. 모듈 구조

```
bootstrap/
├── application/   → API bootJar 엔트리포인트
│   └── src/main/java/com/wadiz/api/funding/ApplicationBootstrap.java
└── batch/         → Batch bootJar 엔트리포인트
    └── src/main/java/com/wadiz/api/funding/BatchBootstrap.java
```

### 빌드 결과물

`build.gradle.kts` 기준 (`bootprojects` 리스트, `if (parent!!.name != "bootstrap")` 조건):

| 서브모듈 | Gradle 태스크 | 결과물 |
|---|---|---|
| `bootstrap:application` | `bootJar` (활성화) | `bootstrap-application-0.0.1-SNAPSHOT.jar` |
| `bootstrap:batch` | `bootJar` (활성화) | `bootstrap-batch-0.0.1-SNAPSHOT.jar` |
| `adapter:application`, `adapter:batch`, `adapter:infrastructure` | `bootJar` 비활성화 / `jar` 활성화 | 일반 라이브러리 JAR |

`bootstrap:application`의 `bootJar`에는 `launchScript()` 가 선언되어 있어 Unix 실행 스크립트가 포함된다.
`Implementation-Title: "Funding API"`, `Implementation-Version: 0.0.1-SNAPSHOT`.

### 의존 관계 (런타임 클래스패스)

```
bootstrap:application  →  adapter:application  +  adapter:infrastructure
bootstrap:batch        →  adapter:batch        +  adapter:infrastructure
```

`adapter:batch`는 `adapter:infrastructure`에 대한 의존을 가지며, 공통 DB/Redis/Mongo 설정을 재사용한다.

---

## 2. ApplicationBootstrap (API 프로세스)

**파일**: `bootstrap/application/src/main/java/com/wadiz/api/funding/ApplicationBootstrap.java`

```java
@SpringBootApplication
public class ApplicationBootstrap {

  static {
    System.setProperty("com.amazonaws.sdk.disableEc2Metadata", "true");
  }

  public static void main(String[] args) {
    SpringApplication.run(ApplicationBootstrap.class, args);
  }
}
```

### 주요 관찰

| 항목 | 내용 |
|---|---|
| `@SpringBootApplication` | 패키지: `com.wadiz.api.funding` — `scanBasePackages` 미지정이므로 동일 패키지 하위 전체 스캔 |
| static 초기화 | `com.amazonaws.sdk.disableEc2Metadata=true` 설정 → EC2 메타데이터 자동 조회 비활성화 |
| `SpringApplication` 빌드 | `SpringApplication.run(ApplicationBootstrap.class, args)` — 기본 빌더 사용, 커스텀 배너 설정 없음 (`banner-mode`는 deploy 프로파일에서 `log`로 설정) |

### 실질적으로 활성화되는 `@Enable*` 어노테이션 목록

`ApplicationBootstrap` 자체에는 선언이 없고, 자동 스캔되는 `adapter/application` 설정 클래스들이 보유:

| 어노테이션 | 선언 클래스 | 설명 |
|---|---|---|
| `@EnableAutoConfiguration` | `ApplicationConfig` | Spring Boot 자동 설정 활성화 (일부 자동 설정은 `application.yml`에서 exclude) |
| `@EnableWebSecurity` | `WebSecurityConfig` | Spring Security 웹 보안 활성화 |
| `@EnableGlobalMethodSecurity(prePostEnabled = true)` | `WebSecurityConfig.GlobalMethodSecurityConfig` | `@PreAuthorize` SpEL 메서드 보안 활성화 |
| `@EnableAsync` | `AsyncConfig` | `@Async` 비동기 실행 활성화 |
| `@EnableSqs` | `AwsSqsConfig` | AWS SQS 메시지 리스너 활성화 |
| `@EnableCaching` | `CacheConfig` | Spring Cache 추상화 활성화 (구현체: Hazelcast) |
| `@EnableTransactionManagement` | `JdbcConfig` (infrastructure) | 트랜잭션 관리 활성화 |
| `@EnableJdbcAuditing(modifyOnCreate = false)` | `DataJdbcConfig` (infrastructure) | Spring Data JDBC Auditing 활성화 |
| `@EnableJdbcRepositories(basePackages = "com.wadiz.api.funding.persistence.*")` | `DataJdbcConfig` (infrastructure) | JDBC Repository 스캔 경로 지정 |
| `@EnableMongoAuditing` | `DataMongoConfig` (infrastructure) | MongoDB Auditing 활성화 |
| `@EnableMongoRepositories(basePackages = "com.wadiz.api.funding.mongo")` | `DataMongoConfig` (infrastructure) | Mongo Repository 스캔 경로 지정 |
| `@EnableRedisRepositories(basePackages = "com.wadiz.api.funding.redis")` | `DataRedisConfig` (infrastructure) | Redis Repository 스캔 경로 지정 |

> `@MapperScan`은 소스 내 명시적 선언 없음. MyBatis Mapper 경로는 `mybatis.mapper-locations: classpath:mapper/**/*.xml` (application-infrastructure.yml)으로 지정되며 MyBatis Spring Boot Autoconfigure가 처리한다.

> `@EnableScheduling` 선언 없음. 배치 Job은 외부 트리거(Jenkins 등)로만 실행된다.

---

## 3. BatchBootstrap (배치 프로세스)

**파일**: `bootstrap/batch/src/main/java/com/wadiz/api/funding/BatchBootstrap.java`

```java
@SpringBootApplication
public class BatchBootstrap {

  public static void main(String[] args) {
    System.exit(SpringApplication.exit(SpringApplication.run(BatchBootstrap.class, args)));
  }
}
```

### API 대비 차이점

| 항목 | ApplicationBootstrap | BatchBootstrap |
|---|---|---|
| 종료 패턴 | `SpringApplication.run(...)` (서버 상주) | `System.exit(SpringApplication.exit(...))` (실행 후 즉시 종료) |
| static 초기화 블록 | EC2 메타데이터 비활성화 설정 | 없음 |
| 의존 모듈 | `adapter:application` + `adapter:infrastructure` | `adapter:batch` + `adapter:infrastructure` |
| Security 설정 | `WebSecurityConfig` 포함 | 없음 (Security 미포함) |
| SQS | `@EnableSqs` (`AwsSqsConfig`) | 없음 |
| Hazelcast | `HazelcastConfig` + `CacheConfig` | 없음 |
| Async 실행기 | 4종 (`taskExecutor`, `paymentAsyncExecutor`, `nativeAppAsyncExecutor`, `notificationAsyncExecutor`) | 없음 |
| Batch 설정 | 없음 | `BatchConfig`, `BatchJdbcConfig` (별도 DataSource) |

---

## 4. 설정 파일 인벤토리

### 4-1. API (adapter/application)

설정 파일 위치: `adapter/application/src/main/resources/config/`

| 파일 | 활성 조건 | 주요 설정 그룹 |
|---|---|---|
| `application.yml` | 항상 로드 | server(port:9070/관리:9071), spring.application.name(funding), autoconfigure exclude(Hateoas·H2·DataSource), Hazelcast(port:9072), Resilience4j CircuitBreaker/TimeLimiter, logging |
| `application-dev.yml` | `spring.profiles.active=dev` | Redis cluster, MongoDB URI, 외부 클라이언트 URL(dev 환경), wadizdb master/slave URL, AWS SQS queue명 |
| `application-rc.yml` | `spring.profiles.active=rc` | Redis cluster, MongoDB URI, 외부 클라이언트 URL(rc 환경), wadizdb master/slave URL |
| `application-rc2.yml` | `spring.profiles.active=rc2` | Redis cluster, MongoDB URI, 외부 클라이언트 URL(rc2 환경), wadizdb master/slave URL |
| `application-rc3.yml` | `spring.profiles.active=rc3` | Redis cluster, MongoDB URI, 외부 클라이언트 URL(rc3 환경), wadizdb master/slave URL |
| `application-live.yml` | `spring.profiles.active=live` | Redis cluster(3노드), MongoDB URI(ReplicaSet 3노드), 외부 클라이언트 URL(운영), AWS S3 bucket, AWS SQS queue명, logging(root:warn) |
| `application-deploy.yml` | `spring.profiles.active=deploy` | 프로파일 그룹 정의(`dev-deploy`, `rc-deploy`, `rc2-deploy`, `rc3-deploy`, `live-deploy`), consul enabled, banner-mode:log, lazy-initialization:true, 로그 파일 경로(`/app/com.wadiz.api.funding/logs/`) |
| `bootstrap.yml` | Spring Cloud Config bootstrap | `spring.application.name: funding` |
| `bootstrap-dev.yml` | bootstrap (dev) | 내용 없음 (파일 존재만 확인됨) |
| `bootstrap-live.yml` | bootstrap (live) | 내용 없음 (파일 존재만 확인됨) |
| `bootstrap-rc.yml` | bootstrap (rc) | 내용 없음 (파일 존재만 확인됨) |
| `bootstrap-rc2.yml` | bootstrap (rc2) | 내용 없음 (파일 존재만 확인됨) |

**프로파일 활성화 방식**: `application-deploy.yml`의 `spring.profiles.group` 으로 복합 프로파일 그룹 정의.
배포 시 `spring.profiles.active=dev-deploy` (또는 `rc-deploy`, `live-deploy` 등)를 지정하면 해당 환경 YML + `deploy` YML이 동시에 활성화된다.

**`application.yml` 주요 키 구조** (값은 민감하지 않은 구조만):

```yaml
server:
  port: 9070
  shutdown: graceful
  tomcat.threads.max: 500
management:
  server.port: 9071
  endpoints.web.exposure.include: health, info, prometheus, circuitbreakers
spring:
  cache.type: hazelcast
  lifecycle.timeout-per-shutdown-phase: 30s
  mvc.pathmatch.matching-strategy: ant_path_matcher
application:
  jwt:
    secret: {{secret}}
  hazelcast:
    port: 9072
```

### 4-2. Batch (adapter/batch)

설정 파일 위치: `adapter/batch/src/main/resources/config/`

| 파일 | 활성 조건 | 주요 설정 그룹 |
|---|---|---|
| `application.yml` | 항상 로드 | `spring.profiles.include: infrastructure`, Slack webhook URL(`application.slack-webhook-client.webhook-url`), batch DataSource(hikari 파라미터) |
| `application-dev.yml` | `dev` 프로파일 | wadizdb master/slave URL, batch DB URL |
| `application-rc.yml` | `rc` 프로파일 | wadizdb master/slave URL, batch DB URL |
| `application-rc2.yml` | `rc2` 프로파일 | wadizdb master/slave URL, batch DB URL |
| `application-rc3.yml` | `rc3` 프로파일 | wadizdb master/slave URL, batch DB URL |
| `application-live.yml` | `live` 프로파일 | wadizdb master/slave URL, batch DB URL, Redis cluster, MongoDB URI, 알림/번역/결제 클라이언트 URL, logging |
| `application-deploy.yml` | (파일 존재 확인됨) | 내용 미확인 |

**Batch `application.yml` 특이사항**:
- `spring.profiles.include: infrastructure` — `adapter/infrastructure`의 `application-infrastructure.yml`을 자동 포함
- batch 전용 DataSource (`application.datasource.batch.*`) 는 `application.yml`에 hikari 설정 기본값 포함; URL/username/password는 각 프로파일 YML에서 override

### 4-3. Infrastructure 공통 (adapter/infrastructure)

| 파일 | 활성 조건 | 주요 설정 그룹 |
|---|---|---|
| `application-infrastructure.yml` | `spring.profiles.include: infrastructure` | `mybatis.mapper-locations: classpath:mapper/**/*.xml`, `mybatis.configuration-properties.DAMO_ENC_KEY`, Redis cluster 기본값, MongoDB URI 기본값, 외부 클라이언트 기본 URL 그룹 |
| `application-test.yml` | `test` 프로파일 | 테스트 전용 (기록 범위 밖) |

---

## 5. Security 설정

**클래스**: `adapter/application/.../config/WebSecurityConfig.java`
Spring Boot 2.x 방식: `WebSecurityConfigurerAdapter` 상속.

### 5-1. SecurityFilterChain 규칙

`configure(HttpSecurity http)` 에서 선언된 `authorizeRequests()` 규칙:

| 순서 | 패턴 | 요구 권한 |
|---|---|---|
| 1 | `/api/internal/**`, `/api/global/internal/**` | `hasRole("SYSTEM")` — JWT `rol` 클레임에 `SYSTEM` 역할 필요 |
| 2 | `/api/studio/**`, `/api/global/studio/**`, `/api/admin/**`, `/api/global/admin/**`, `/**/preview**` | `authenticated()` — JWT 토큰 인증만 필요 |
| 3 | 나머지 모든 요청 | `permitAll()` — 공개 접근 허용 |

**WebSecurity ignore 패턴** (`configure(WebSecurity web)`):

- `/**/favicon.ico`
- `/v3/api-docs/**`, `/swagger-ui/**`, `/swagger-ui.html`

**기타 HTTP 설정**:

| 항목 | 설정값 |
|---|---|
| 세션 정책 | `STATELESS` — 서버 세션 미생성 |
| CSRF | 비활성화 (`csrf().disable()`) |
| 예외 처리 | `authenticationEntryPoint`, `accessDeniedHandler` 모두 `SecurityProblemSupport` (Zalando Problem 라이브러리) |
| OAuth2 Resource Server | JWT 방식 (`oauth2ResourceServer().jwt()`) |

### 5-2. JWT 검증기 (`jwtDecoder` Bean)

- 알고리즘: `HS256` (HMAC-SHA-256)
- 구현체: `NimbusJwtDecoder.withSecretKey(...)` → `NimbusJwtDecoder` 빈
- 키 소스: `application.jwt.secret` 프로퍼티 (`JwtProperties` `@ConfigurationProperties` 클래스, `@ConstructorBinding`)
- 프로파일별 secret 값: dev/rc/rc2/rc3 공통 `{{secret-non-prod}}`, live 전용 `{{secret-prod}}`

### 5-3. JWT 인증 컨버터

`WadizJwtAuthenticationConverter` → `WadizAuthenticationToken` 생성:

- JWT 클레임 `uid` → `WadizAuthenticationToken.userId` (Integer)
- JWT Subject → `WadizAuthenticationToken.name`
- JWT 클레임 `rol` → GrantedAuthority (prefix: `ROLE_`)

### 5-4. `@PreAuthorize` SpEL 커스텀 함수

`WadizMethodSecurityExpressionRoot` (`adapter/application/.../support/security/WadizMethodSecurityExpressionRoot.java`)에 정의된 커스텀 SpEL 함수:

| SpEL 함수 | 구현 내용 | `SecuritySupport` 위임 여부 |
|---|---|---|
| `isOpened(campaignId)` | `securitySupport.isOpened(campaignId)` | Y (core 내부) |
| `isOpenedOrComingSoonPosting(campaignId)` | `securitySupport.isOpened(campaignId) \|\| securitySupport.isComingSoonPosting(campaignId)` | Y |
| `isComingSoonPosting(campaignId)` | `securitySupport.isComingSoonPosting(campaignId)` | Y (core 내부) |
| `isComingSoonPosted(campaignId)` | `securitySupport.isComingSoonPosted(campaignId)` | Y (core 내부) |
| `isMaker(campaignId)` | `SecurityUtils.isLogin() && securitySupport.isMaker(campaignId, SecurityUtils.currentUserId())` | Y (core 내부) |
| `isAdmin()` | `authentication.getAuthorities()`에서 `ROLE_ADMIN` 존재 여부 확인 | N (SecurityContext 직접 조회) |

`SecuritySupport` 인터페이스는 `core/domain`에 선언되고, 구현체 `SecuritySupportImpl`은 `adapter/infrastructure`에 위치한다. 내부 SQL/로직은 infrastructure 모듈에서 별도 확인 필요.

**ExpressionHandler 등록 흐름**:

```
GlobalMethodSecurityConfig (내부 static 클래스)
  → createExpressionHandler()
  → WadizMethodSecurityExpressionHandler (extends DefaultMethodSecurityExpressionHandler)
  → createSecurityExpressionRoot() → WadizMethodSecurityExpressionRoot
```

### 5-5. ImpersonationInterceptor

`WebMvcConfig.addInterceptors()`에서 `ImpersonationInterceptor`를 조건부(`if != null`) 등록.
`ImpersonationInterceptor`는 `@Autowired(required = false)`로 주입 — 특정 조건에서만 활성화.
`ImpersonationContext`(ThreadLocal 기반)로 운영자가 사용자를 대리(impersonate)하는 것을 지원하며, 전용 로그 파일(`impersonation.log`)에 별도 기록된다.

---

## 6. 데이터 소스 / 커넥션 구성

### 6-1. MySQL (API / Batch 공통 — `adapter/infrastructure`)

**클래스**: `JdbcConfig.java`

| Bean명 | 설정 prefix | 역할 |
|---|---|---|
| `dataSource` (`@Primary`) | — | `RoutingDataSource`(master/slave 라우팅) + `LazyConnectionDataSourceProxy` 래핑 |
| `wadizMasterDataSource` | `application.datasource.wadizdb.master.hikari` | HikariCP Master 커넥션 |
| `waidzSlaveDataSource` | `application.datasource.wadizdb.slave.hikari` | HikariCP Slave 커넥션 (read-only) |
| `wadizMasterDataSourceProperties` | `application.datasource.wadizdb.master` | Master URL/username/password |
| `wadizSlaveDataSourceProperties` | `application.datasource.wadizdb.slave` | Slave URL/username/password |

- DB명: `wadiz_db` (master + slave)
- Hikari 기본 설정: `connection-timeout: 5000ms`, `max-lifetime: 28795000ms`, `maximum-pool-size: 5`

### 6-2. MySQL Batch 전용 (`adapter/batch`)

**클래스**: `BatchJdbcConfig.java`

| Bean명 | 설정 prefix | 역할 |
|---|---|---|
| `batchDataSource` | `application.datasource.batch.hikari` | HikariCP Batch 전용 DataSource |
| `batchDataSourceProperties` | `application.datasource.batch` | Batch DB URL/username/password |

- DB명: `wadiz_funding_batch`
- `BatchConfig`에서 `@Qualifier("batchDataSource")`로 주입받아 JobRepository/JobExplorer 생성

### 6-3. Redis

**클래스**: `DataRedisConfig.java`

| Bean명 | 역할 |
|---|---|
| `longRedisTemplate` (`RedisTemplate<String, Integer>`) | 키: `StringRedisSerializer`, 값: `GenericToStringSerializer<Long>` |
| `redisLockRegistry` (`RedisLockRegistry`) | 분산 락, prefix: `wadiz:funding:distributed-lock` |

- Repository 스캔: `@EnableRedisRepositories(basePackages = "com.wadiz.api.funding.redis")`
- 연결 설정: `spring.redis.cluster.nodes` (프로파일별 3노드 Redis Cluster)

### 6-4. MongoDB

**클래스**: `DataMongoConfig.java`

| 설정 | 값 |
|---|---|
| `serverSelectionTimeout` | 5초 |
| `connectTimeout` | 5초 |
| `readTimeout` | 10초 |
| `maxConnectionIdleTime` | 60초 |
| `maxConnectionLifeTime` | 60초 |
| `maxWaitTime` | 5초 |

- Repository 스캔: `@EnableMongoRepositories(basePackages = "com.wadiz.api.funding.mongo")`
- DB명: `wadiz_funding` (URI: `spring.data.mongodb.uri`, 프로파일별 호스트 상이)
- Auditing: `@EnableMongoAuditing`

### 6-5. MyBatis

**클래스**: `MybatisConfig.java`

| Bean | 역할 |
|---|---|
| `UuidTypeHandler` | UUID ↔ String 변환 TypeHandler 등록 |
| `MyBatisContextIdentifierInterceptor` | MyBatis 실행 시 컨텍스트 식별자(트레이싱 등) 자동 삽입 |
| `SortGroupInterceptor` | 정렬 그룹 처리 인터셉터 |

- Mapper XML 위치: `mybatis.mapper-locations: classpath:mapper/**/*.xml` (`application-infrastructure.yml`)
- 암호화 키: `mybatis.configuration-properties.DAMO_ENC_KEY` — Mapper XML에서 `${DAMO_ENC_KEY}`로 참조

---

## 7. Component Scan 경계

`@SpringBootApplication` 이 `bootstrap/application` (패키지 `com.wadiz.api.funding`)에 선언되므로, Spring이 스캔하는 범위는 **`com.wadiz.api.funding` 패키지 전체**다.
`scanBasePackages` 미지정 → Spring Boot 기본 동작인 선언 클래스 패키지 이하 전체 스캔.

### 하위 모듈별 포함 경로

| 모듈 | 실제 스캔 경로 (패키지) | 주요 구성 요소 |
|---|---|---|
| `adapter:application` | `com.wadiz.api.funding.config.*` | 모든 `@Configuration` 클래스 |
| `adapter:application` | `com.wadiz.api.funding.domain.*` | `@RestController`, Service 빈 |
| `adapter:application` | `com.wadiz.api.funding.support.*` | Security 지원, 필터, 인터셉터 |
| `adapter:infrastructure` | `com.wadiz.api.funding.config.*` | DataSource, Redis, Mongo, MyBatis 설정 |
| `adapter:infrastructure` | `com.wadiz.api.funding.client.*` | HTTP 클라이언트 설정 클래스 |
| `adapter:infrastructure` | `com.wadiz.api.funding.persistence.*` | Spring Data JDBC Repository (`@EnableJdbcRepositories`) |
| `adapter:infrastructure` | `com.wadiz.api.funding.redis.*` | Spring Data Redis Repository (`@EnableRedisRepositories`) |
| `adapter:infrastructure` | `com.wadiz.api.funding.mongo.*` | Spring Data MongoDB Repository (`@EnableMongoRepositories`) |

### Autoconfigure Exclude (application.yml)

`spring.autoconfigure.exclude` 에 명시적으로 제외된 자동 설정:

- `HypermediaAutoConfiguration` — Spring HATEOAS 비활성화
- `H2ConsoleAutoConfiguration` — H2 콘솔 비활성화
- `DataSourceAutoConfiguration` — Spring Boot 기본 DataSource 자동 설정 비활성화 (수동 `JdbcConfig`로 대체)

---

## 8. 비동기 실행기 (`AsyncConfig`)

`@EnableAsync` 활성화. `DelegatingSecurityContextAsyncTaskExecutor`로 래핑 → async 스레드에서 SecurityContext 자동 전파.

| Bean명 | Core | Max | Queue | ThreadPrefix | 비고 |
|---|---|---|---|---|---|
| `taskExecutor` | (기본값) | (기본값) | (기본값) | (기본값) | 이름 없는 `@Async` 메서드용 기본 풀 |
| `paymentAsyncExecutor` | 10 | 30 | 200 | `PaymentAsync-` | `@Async("paymentAsyncExecutor")` |
| `nativeAppAsyncExecutor` | 20 | 60 | 40 | `NativeAppAsync-` | Locale 전파 TaskDecorator 포함, Micrometer 모니터링 등록, AbortPolicy |
| `notificationAsyncExecutor` | 5 | 10 | 25 | `NotificationAsync-` | |

---

## 9. Hazelcast (In-Process Cache)

**클래스**: `HazelcastConfig.java` (adapter/application)

| 설정 | 값 |
|---|---|
| 인스턴스 명 | `funding` |
| 포트 | `application.hazelcast.port: 9072` |
| 캐시 타입 | `spring.cache.type: hazelcast` |
| default Map TTL | 5초 |
| `countries` Map TTL | 3600초 (1시간) |
| `catalogFeed` Map TTL | 3600초 (1시간) |
| `GlobalProjectProxy.AI_SUMMARY_CACHE` Map TTL | 3600초 (1시간) |
| 직렬화 | `KryoSerializer` (GlobalSerializer, Java 직렬화 override) |
| 클러스터 발견 | Consul 연동 (`SpringCloudDiscoveryStrategyFactory`). Consul 미연결 시 `localhost(127.0.0.1)` 단독 실행 |

---

## 10. AWS SQS (`AwsSqsConfig`)

| Bean | 설정 |
|---|---|
| `AmazonSQSAsync` (`@Primary`) | `DefaultAWSCredentialsProviderChain`, region `ap-northeast-2` |
| `SimpleMessageListenerContainerFactory` | `waitTimeOut: 20s`, `visibilityTimeout: 30s`, pool: core=20/max=50/queue=200 |
| `BeanPostProcessor` | `SimpleMessageListenerContainer`의 phase를 `Integer.MAX_VALUE - 1` 로 설정 — Tomcat보다 먼저 종료 |

Queue 이름: `application.aws-sqs.queue-name` (프로파일별 상이, e.g. `pay-webhook-funding-api.fifo`)

---

## 11. Logback 설정

### API (`adapter/application/src/main/resources/logback-spring.xml`)

| 항목 | 내용 |
|---|---|
| 파일 Appender | `ASYNC` (AsyncAppender, queueSize=512) → `FILE` |
| 전용 Appender | `IMPERSONATION_FILE` (Rolling, maxFileSize=10MB, maxHistory=90일) |
| 전용 Logger | `ImpersonationInterceptor` → `IMPERSONATION_FILE` + `CONSOLE` (additivity=false) |
| Root | `CONSOLE` + `ASYNC` |
| ShutdownHook | `DelayingShutdownHook` |

### Batch (`adapter/batch/src/main/resources/logback-spring.xml`)

| 항목 | 내용 |
|---|---|
| 파일 Appender | `ASYNC` (queueSize=512) → `FILE` |
| Root | `CONSOLE` + `ASYNC` |
| 전용 Appender/Logger | 없음 |

---

## 12. 외부 클라이언트 인벤토리

`adapter/infrastructure/src/main/java/.../client/` 하위에 정의된 `*ClientConfig.java` 목록:

| 클라이언트 설정 클래스 | `application.*` 프로퍼티 prefix |
|---|---|
| `RewardClientConfig` | `application.reward-client` |
| `RewardBridgeClientConfig` | `application.reward-bridge-client` |
| `StoreClientConfig` | `application.store-client` |
| `UserClientConfig` | `application.user-client` |
| `MembershipClientConfig` | `application.membership-client` |
| `SettlementClientConfig` | `application.settlement-client` |
| `PointClientConfig` | `application.point-client` |
| `PayClientConfig` | `application.pay-client` |
| `NotificationClientConfig` | `application.notification-client` |
| `InboxClientConfig` | `application.inbox-client` |
| `AlimtalkV2ClientConfig` | `application.alimtalk-client-v2` |
| `SmsV2ClientConfig` | `application.sms-client-v2` |
| `FriendtalkClientConfig` | `application.friend-talk-client` |
| `BrazeClientConfig` | `application.braze-client` |
| `SlackClientConfig` / `SlackWebhookClientConfig` | `application.slack-client` / `application.slack-webhook-client` |
| `OCRClientConfig` | `application.ocr-client` |
| `BankAccountConfig` | `application.bank-account-client` |
| `BusinessClientConfig` | `application.business-client` |
| `StartupClientConfig` | `application.startup-client` |
| `CategorySearchClientConfig` | `application.searcher-client` |
| `AIReviewClientConfig` | `application.ai-review-client` |
| `DataplusClientConfig` | `application.dataplus-client` |
| `ErpClientConfig` | `application.erp-client` |
| `CountryClientConfig` | `application.country-client` |
| `AdPaymentClientConfig` | `application.ad-payment-client` |
| `TranslateClientConfig` | `application.translate-client` |
| `ExchangeRateClientConfig` | `application.exchange-rate-client` |
| `TranslateAiClientConfig` | `application.translate-ai-client` |
| `ProjectAiSummaryClientConfig` | `application.project-ai-summary-client` |
| `KCertificationConfig` | `application.kc-certification` |
| `SafeNumberClientConfig` | `application.safe-number` |
| `AttachConfig` | — |

내부 구현 (RestTemplate / WebClient 여부, timeout 설정 등)은 각 `*ClientConfig.java` 별도 확인 필요.
