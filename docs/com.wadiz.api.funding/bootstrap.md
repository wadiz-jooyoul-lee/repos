# bootstrap 모듈 상세 스펙

> **기록 범위**: `bootstrap/application`, `bootstrap/batch` 엔트리 클래스와 `adapter/application`, `adapter/batch`, `adapter/infrastructure`의 `@Configuration` 클래스 및 `src/main/resources/config/` 하위 YML 파일에서 **직접 관찰 가능한** 선언만 기록.
> Spring Security 내부 동작, 외부 jar(`funding-core`, `reward-http-client` 등) 내부 로직, 런타임 동적 빈 생성 등은 기록 범위 밖이다.
> 시크릿/패스워드 값은 `{{secret}}` 으로 마스킹, URL 호스트는 그대로 기재(내부 망 주소이므로 외부 노출 위험 없음).

---

> 📅 **2026-09-29 본문 전면 점검** — `master` 브랜치 `a9fac634f` 기준
>
> 직전 본문 점검이 2026-04-20 이었고, 그 사이 504개 커밋이 들어왔습니다.
> 설정 파일 인벤토리(4장)와 외부 클라이언트 접두사 목록(12장)을 코드에서 다시 세어 고쳤습니다.
>
> | 고친 곳 | 예전 | 지금 |
> |---|---|---|
> | 서비스 이름 | `funding` | **`funding-api`** (Consul 등록명만 `funding` 유지) |
> | `application-dev.yml` | 있음 | **삭제됨** — 값이 쿠버네티스 ConfigMap 으로 이동 |
> | `application-rc3.yml` | 있음 | **삭제됨** — rc3 환경 폐기 |
> | 자동설정 제외 | 3개 | **4개** (Elasticsearch 추가) |
> | SQS 큐 | 1개 | **2개** (Stripe 계정 변경 큐 추가) |
> | 외부 클라이언트 접두사 | 31개(허수 2개 포함) | **37개** |
> | 라이브 API 문서 | 언급 없음 | **차단됨** (2026-08-05 결정) |
>
> 뿌리가 된 커밋은 넷입니다.
>
> | 이슈키 | 날짜 | 무엇이 바뀌었나 |
> |---|---|---|
> | `RWD-5535` | 2026-05-07 | 설정 파일 정리. `application-infrastructure.yml` 을 58줄로 줄임 |
> | `RWD-5766` | 2026-07-01 | 도메인 `io` 적용. `application-dev.yml` 삭제 |
> | `RWD-5785` | 2026-07-09~13 | rc3 폐기. Elasticsearch 자동설정 제외 |
> | `RWD-5875` | 2026-08-05 | OpenAPI 스펙 개편. 라이브에서 API 문서 차단 |

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
| `application.yml` | 항상 로드 | 서버 포트 9070 / 관리 포트 9071, `spring.application.name: funding-api`, 자동설정 제외 4종, Hazelcast 포트 9072, Resilience4j, 환경 무관 외부 API 기본값 |
| `application-local.yml` | `local` (기본값) | **클라우드 개발 인프라를 바라봅니다.** Redis·MongoDB·MySQL 호스트, 외부 클라이언트 URL, AWS SQS 큐 이름 |
| `application-rc.yml` | `rc` | 사내(온프렘) rc 환경. Redis 클러스터, MongoDB, ERP URL, MySQL |
| `application-rc2.yml` | `rc2` | 사내(온프렘) rc2 환경 |
| `application-live.yml` | `live` | 사내(온프렘) 운영. Redis 클러스터, MongoDB 3노드, `www.wadiz.kr`·`platform.wadiz.kr` 계열 URL, S3 버킷, SQS 큐 |
| `application-deploy.yml` | `deploy` | 프로파일 묶음 정의, Consul 등록, 배너 로그 출력, 로그 파일 경로 |
| `bootstrap.yml` | 항상 | `spring.application.name: funding-api`, 쿠버네티스 설정 읽기 끔, AWS 비밀관리자 옛 방식 끔 |
| `bootstrap-kubernetes.yml` | `kubernetes` | **클라우드 환경 전용.** ConfigMap `common-config` 와 `funding-api` 를 읽습니다 |
| `bootstrap-dev.yml` · `bootstrap-rc.yml` · `bootstrap-rc2.yml` · `bootstrap-live.yml` | 각 프로파일 | **네 파일 모두 내용이 비어 있습니다** |

> ⚠️ **`application-dev.yml` 과 `application-rc3.yml` 이 사라졌습니다.**
> `RWD-5766`(2026-07-01, `3dfb6a6bf`)이 dev 설정을 지웠습니다. 커밋 제목이 "도메인 io 적용 및 dev profile 설정삭제(helmchart 대체)" 입니다.
> `RWD-5785`(2026-07-09, `2823633ba`)가 rc3 환경을 폐기했습니다.
> **개발 환경 값은 이제 저장소가 아니라 쿠버네티스 ConfigMap 에 있습니다.**

**프로파일 묶음 정의** (`application-deploy.yml`)

```yaml
spring:
  profiles:
    group:
      dev-deploy: dev, deploy
      rc-deploy: rc, deploy
      rc2-deploy: rc2, deploy
      live-deploy: live, deploy
```

배포할 때 `spring.profiles.active=rc-deploy` 처럼 지정하면 그 환경 파일과 `deploy` 파일이 함께 켜집니다.

> 🔎 **확인 필요 — `dev-deploy` 묶음이 남아 있습니다.**
> 그런데 그 묶음이 가리키는 `dev` 프로파일 파일(`application-dev.yml`)은 삭제됐습니다.
> 지금 `dev-deploy` 로 띄우면 `application.yml` 기본값과 `application-deploy.yml` 만 적용됩니다.
> 클라우드에서는 ConfigMap 이 값을 채워 주므로 문제가 안 되는 구조로 보입니다(추정).
> 코드에 그 의도가 적혀 있지는 않습니다.

**`application.yml` 에서 눈여겨볼 값**

```yaml
server:
  port: 9070
  shutdown: graceful
  tomcat.threads.max: 500
management:
  server.port: 9071
  endpoints.web.exposure.include: health, info, prometheus, circuitbreakers
spring:
  application.name: funding-api
  profiles:
    default: local          # active 를 안 주면 local 로 뜹니다
    include: infrastructure
  autoconfigure.exclude:
    - HypermediaAutoConfiguration
    - H2ConsoleAutoConfiguration
    - DataSourceAutoConfiguration
    - ElasticsearchRestClientAutoConfiguration
```

> **이름이 `funding` 에서 `funding-api` 로 바뀌었습니다.** 예전 문서가 `funding` 이라고 적었습니다.
> 다만 Consul 에 등록하는 이름은 여전히 `funding` 입니다.
> `application-deploy.yml` 이 `spring.cloud.consul.discovery.service-name: funding` 으로 명시해 덮어씁니다.
> 코드 주석이 이유를 적어 뒀습니다 — 온프렘 Consul 에 기존 `funding` 서비스 아이디로 등록돼 있기 때문입니다.
>
> **Elasticsearch 자동설정을 끈 것도 새로 들어왔습니다**(`RWD-5785`, 2026-07-13, `33dc44a88`).
> 켜 두면 스프링이 `localhost:9200` 을 기본으로 잡고 상태 점검에 끼워 넣습니다.
> Elasticsearch 가 없는 환경에서 상태 점검이 실패해 배포가 막혔습니다.
> 지금은 `DpSearchClient` 가 연결을 직접 관리합니다.

### 4-2. Batch (adapter/batch)

설정 파일 위치: `adapter/batch/src/main/resources/config/`

| 파일 | 활성 조건 | 주요 설정 그룹 |
|---|---|---|
| `application.yml` | 항상 로드 | `spring.profiles.include: infrastructure`, 슬랙 웹훅, 배치 등록자 userId, **스팸 차단 배치 3종 설정** |
| `application-local.yml` | `local` (기본값) | 클라우드 개발 인프라의 MySQL·Redis·MongoDB |
| `application-rc.yml` · `application-rc2.yml` | 각 프로파일 | 사내(온프렘) 검증 환경 |
| `application-live.yml` | `live` | 사내(온프렘) 운영 |
| `application-deploy.yml` | `deploy` | 프로파일 묶음 4종, 지연 초기화 켜짐, 로그 파일 경로 |
| `bootstrap.yml` | 항상 | `spring.application.name: funding-batch` |
| `bootstrap-kubernetes.yml` | `kubernetes` | ConfigMap `common-config` 와 `funding-batch` 를 읽습니다 |

**배치 `application.yml` 에서 새로 생긴 것 — 스팸 차단 배치 3종**

| 설정 키 | 배치 작업 | 무엇을 하나 |
|---|---|---|
| `application.mini-board-spam-guard` | `miniBoardSpamGuardJob` | 미니보드의 피싱·스팸 글을 찾아 지웁니다 |
| `application.personal-message-spam-guard` | `personalMessageSpamGuardJob` | 1:1 메신저의 피싱 메시지를 찾아 지웁니다 |
| `application.signature-spam-guard` | `signatureSpamGuardJob` | 지지서명의 피싱 봇을 찾아 지웁니다 |

세 배치 모두 같은 항목을 가집니다.

| 항목 | 뜻 |
|---|---|
| `enabled` | `false` 면 배치를 건너뜁니다 |
| `dry-run` | `true` 면 찾아서 슬랙으로 알리기만 하고 실제로 지우지는 않습니다 |
| `scan-window-minutes` | 최근 몇 분 안에 들어온 글만 봅니다 (기본 10분) |
| `max-scan` | 한 번에 조회할 상한 (기본 1000건) |

> 미니보드와 지지서명은 `Del=1` 로 표시만 하고, 1:1 메신저는 줄을 실제로 지웁니다.
> 주석에 그렇게 구분해 적혀 있습니다.

**배치 `application.yml` 의 나머지 특이사항**
- `spring.profiles.include: infrastructure` — `adapter/infrastructure` 의 `application-infrastructure.yml` 을 자동으로 붙입니다
- `application.batch.register-user-id: 3890` — 배치가 외부 API 를 부를 때 쓰는 등록자 번호입니다. 주석에 `info@wadiz.kr` 계정이라고 적혀 있습니다
- 배치 전용 데이터소스(`application.datasource.batch.*`)의 접속 옵션 기본값은 `application-infrastructure.yml` 에 있고, 주소·계정·비밀번호는 환경 파일에서 덮어씁니다

### 4-3. Infrastructure 공통 (adapter/infrastructure)

| 파일 | 활성 조건 | 주요 설정 그룹 |
|---|---|---|
| `application-infrastructure.yml` | `spring.profiles.include: infrastructure` | `mybatis.mapper-locations`, `mybatis.configuration-properties.DAMO_ENC_KEY`, 데이터소스 접속 옵션 기본값 |
| `application-test.yml` | `test` 프로파일 | 테스트 전용 (기록 범위 밖) |

> ⚠️ **`application-infrastructure.yml` 이 크게 줄었습니다.**
> 예전 문서는 여기에 "Redis 클러스터 기본값, MongoDB URI 기본값, 외부 클라이언트 기본 URL 그룹"이 있다고 적었습니다.
> 지금은 **58줄뿐이고 그 셋 모두 없습니다.** MyBatis 설정과 데이터베이스 연결 풀 옵션만 남았습니다.
> `RWD-5535`(2026-05-07, `b5128f9d2`)가 정리했습니다. 커밋 제목이 "설정 파일 리팩토링 - 환경 무관 공통값 추출 + infrastructure.yml 슬림화" 입니다.
> 외부 클라이언트 기본값은 `adapter/application/.../application.yml` 로 옮겨 갔습니다.

---

## 5. Security 설정

**클래스**: `adapter/application/.../config/WebSecurityConfig.java`
Spring Boot 2.x 방식: `WebSecurityConfigurerAdapter` 상속.

### 5-1. SecurityFilterChain 규칙

`configure(HttpSecurity http)` 에서 선언된 `authorizeRequests()` 규칙:

| 순서 | 패턴 | 요구 권한 |
|---|---|---|
| 0 | `/static/scalar.html` | `denyAll()` — **API 문서를 끈 환경에서만 걸립니다** |
| 1 | `/api/internal/**`, `/api/global/internal/**` | `hasRole("SYSTEM")` — JWT `rol` 클레임에 `SYSTEM` 역할이 있어야 합니다 |
| 2 | `/api/studio/**`, `/api/global/studio/**`, `/api/admin/**`, `/api/global/admin/**`, **`/api/maker-home/**`**, `/**/preview**` | `authenticated()` — 토큰 인증만 있으면 됩니다 |
| 3 | 나머지 모든 요청 | `permitAll()` — 누구나 접근할 수 있습니다 |

> **`/api/maker-home/**` 가 인증 필요 목록에 새로 들어왔습니다.**

> ⚠️ **라이브에서는 API 문서를 노출하지 않습니다** (`RWD-5875`, 2026-08-05).
> `application-live.yml:169-175` 의 주석이 이유를 적어 뒀습니다 —
> *"admin/internal 경로·스키마가 공개되는 보안 문제"* 때문입니다.
>
> ```yaml
> springdoc:
>   api-docs:
>     enabled: false
>   swagger-ui:
>     enabled: false
> ```
>
> 그런데 정적 뷰어 파일 `static/scalar.html` 은 springdoc 스위치 밖에 있습니다.
> 그래서 `WebSecurityConfig.java:56-59` 가 따로 막습니다.
>
> ```java
> @Value("${springdoc.api-docs.enabled:true}")
> private boolean apiDocsEnabled;
> ...
> if (!apiDocsEnabled) {
>   http.authorizeRequests().antMatchers("/static/scalar.html").denyAll();
> }
> ```
>
> 이 설정은 **같은 jar 가 배포되는 온프렘 IDC 용**입니다.
> 클라우드(`clive`)는 차트 설정맵에서 똑같이 막는다고 주석이 밝히고 있습니다.
> 차트 쪽 값은 이 저장소에 없어 확인하지 못했습니다.

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
- 프로파일별 비밀값: `application.yml` 기본값을 `rc`·`rc2` 가 그대로 쓰고, `live` 만 덮어씁니다.
  `rc3` 은 폐기됐고 `dev` 는 쿠버네티스 ConfigMap 이 값을 넣습니다

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

- `HypermediaAutoConfiguration` — Spring HATEOAS 를 끕니다
- `H2ConsoleAutoConfiguration` — H2 콘솔을 끕니다
- `DataSourceAutoConfiguration` — 스프링 기본 데이터소스 설정을 끄고 `JdbcConfig` 로 직접 만듭니다
- `ElasticsearchRestClientAutoConfiguration` — **신규**(`RWD-5785`, 2026-07-13, `33dc44a88`).
  켜 두면 스프링이 `localhost:9200` 을 기본으로 잡고 상태 점검에 끼워 넣습니다.
  Elasticsearch 가 없는 환경에서 상태 점검이 실패해 rc 배포가 막혔습니다.
  지금은 `DpSearchClient` 가 연결을 직접 관리합니다. 배치 모듈도 같은 항목을 제외합니다

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

**큐가 둘입니다.**

| 설정 키 | local 값 | 받는 리스너 |
|---|---|---|
| `application.aws-sqs.queue-name` | `pay-webhook-funding-api-dev.fifo` | `OrderPaymentSqsListener` — PG 결제 웹훅 |
| `application.aws-sqs.stripe-account-updated-queue-name` | `dev-stripe-account-updated-webhook.fifo` | `StripeAccountUpdatedSqsListener` — Stripe 계정 상태 변경 (**신규**, `RWD-5311`) |

두 리스너 모두 `application.aws-sqs.listener.enabled` 하나로 함께 켜지고 꺼집니다.
설정이 없으면 켜진 것으로 봅니다. `application-local.yml` 만 `false` 로 둡니다.
로컬에서 AWS 자격증명이 없어도 부팅이 실패하지 않게 하려는 장치입니다.

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

## 12. 외부 클라이언트 설정 접두사

`adapter/infrastructure/.../client/` 아래 설정 클래스가 **37개**입니다.
각 클라이언트가 읽는 `application.*` 접두사는 이렇습니다.

| 설정 접두사 | 설정/속성 클래스 |
|---|---|
| `application.ad-payment-client` | `AdPaymentClientConfig` |
| `application.ai-review-client` | `AIReviewClientConfig` |
| `application.alimtalk-client-v2` | `AlimtalkV2ClientConfig` |
| `application.aws-s3` | `AttachConfig` |
| `application.bank-account-client` | `BankAccountConfig` |
| `application.braze-client` | `BrazeClientConfig` |
| `application.business-client` | `BusinessClientConfig` |
| `application.community-client` | `CommunityClientConfig` — **신규** |
| `application.country-client` | `CountryClientConfig` |
| `application.crypto-client` | `CryptoClientConfig` — **신규** (`RWD-5415`) |
| `application.currency-exchange-client` | `CurrencyExchangeClientConfig` — **신규** (`RWD-5375`) |
| `application.dataplus-client` | `DataplusClientConfig` |
| `application.dp-search` | `DpSearchConfig` — **신규** (`RWD-5785`) |
| `application.erp-client` | `ErpClientConfig` |
| `application.exchange-rate-client` | `ExchangeRateClientConfig` |
| `application.friend-talk-client` | `FriendtalkClientConfig` |
| `application.kc-certification` | `KCertificationConfig` |
| `application.mail-normal-client` | `MailNormalClientProperties` (설정 클래스 없이 속성만) |
| `application.membership-client` | `MembershipClientConfig` |
| `application.ocr-client` | `OCRClientConfig` |
| `application.pay-client` | `PayClientConfig` |
| `application.point-client` | `PointClientConfig` |
| `application.project-ai-summary-client` | `ProjectAiSummaryClientConfig` |
| `application.push-client` | `PushClientProperties` (설정 클래스 없이 속성만) |
| `application.reward-bridge-client` | `RewardBridgeClientConfig` |
| `application.reward-client` | `RewardClientConfig` |
| `application.safe-number` | `SafeNumberClientConfig` |
| `application.searcher-client` | `CategorySearchClientConfig` |
| `application.settlement-client` | `SettlementClientConfig` |
| `application.slack-client` | `SlackClientConfig` |
| `application.slack-webhook-client` | `SlackWebhookClientConfig` |
| `application.sms-client-v2` | `SmsV2ClientConfig` |
| `application.startup-client` | `StartupClientConfig` |
| `application.store-client` | `StoreClientConfig` |
| `application.stripe-client` | `StripeClientConfig` — **신규** (`RWD-5311`) |
| `application.translate-ai-client` | `TranslateAiClientConfig` |
| `application.translate-client` | `TranslateClientConfig` |
| `application.user-client` | `UserClientConfig` |

> ⚠️ **예전 문서가 적어 둔 두 항목을 지웠습니다.**
>
> | 지운 항목 | 이유 |
> |---|---|
> | `InboxClientConfig` (`application.inbox-client`) | 그런 클래스가 없습니다. 알림함 발송은 `NotificationClient` 가 맡습니다 |
> | `NotificationClientConfig` (`application.notification-client`) | 클래스는 있지만 **안이 비어 있습니다.** `@Configuration` 선언만 있고 읽는 설정이 없습니다 |
>
> `NotificationClient` 가 실제로 읽는 값은 `application.mail-normal-client` 와 `application.push-client` 입니다.

> 클라이언트별 실제 주소와 엔드포인트는 [`infrastructure.md`](./infrastructure.md) 의 3장을 봅니다.
