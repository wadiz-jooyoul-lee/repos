# Batch 모듈 상세 스펙 (`reward-batch`)

Spring Batch 기반 **4개 Job** (3 도메인). 독립 실행 JAR 바이너리(`reward-batch/build/libs/*batch*.jar`)로 빌드되며, 외부(크론/Jenkins)에서 `spring.batch.job.names=<jobName>` 을 지정해 기동한다.

> **기록 범위**: 이 레포의 `reward-batch/src/main/java/com/wadiz/api/reward/job/**` 소스와 `reward-api` (또는 루트 `src/main/`) 의 `com/wadiz/api/reward/coupon/infra/dao/*.java` 인터페이스 및 `src/main/resources/mapper/reward/coupon/*-mapper.xml` 에서 직접 관찰 가능한 것만 기록. `CouponDto`, `ProjectCouponSummaryDto`, `CouponTransactionSummationDto` 등 DTO 본체는 외부 jar(`com.wadiz.api.reward:reward-models`, `gradle/wadiz.gradle:2` 참조)에 존재하므로 내부 필드는 호출부에서 접근하는 시그니처로만 관찰했다. Push / AlimTalk / NormalMail / BackOffice / Funding 클라이언트는 `support/client/**` 까지만 추적(게이트웨이 너머의 외부 시스템 내부 로직은 미탐색).
>
> 모든 Job은 `@Scheduled` 선언 없이(`grep "@Scheduled"` 결과 0건) **외부 트리거**(cron / Jenkins `Jenkinsfile-BATCH`에 명시된 수동 배포 후 OS 스케줄러)로 기동되며, 배치 JAR 는 `SpringApplication.exit(SpringApplication.run(...))` 패턴(`RewardBatchApplication:18-24`)으로 실행 후 즉시 종료한다. 각 `*JobConfig` 에 걸린 `@ConditionalOnProperty(prefix = "spring.batch.job", value = "names", havingValue = "<jobName>")` 에 의해 `spring.batch.job.names` 파라미터와 일치하는 하나의 Job 만 컨텍스트에 로드된다.

---

## 1. 개요

### 1-1. 배치 모듈 책임

| 항목 | 내용 |
|---|---|
| 패키지 | `com.wadiz.api.reward.job.*` |
| 분석 루트 | `reward-batch/src/main/java/com/wadiz/api/reward/job/` |
| Job 수 | 4 (코드상 `@Bean Job` 반환 함수 기준) |
| 도메인 | 쿠폰 만료 알림 / 프로젝트별 쿠폰 요약 / 쿠폰 거래 집계(전일/당일) |
| 동작 방식 | Spring Batch **Job Modular** (`@EnableBatchProcessing(modular = true)`, `RewardBatchApplication:10`) + `@ConditionalOnProperty` 로 1회에 1 Job 만 기동 |
| 진입점 | `com.wadiz.api.reward.RewardBatchApplication.main(...)` — Non-web (`WebApplicationType.NONE`, `RewardBatchApplication:20`) |
| 종료 코드 | `SpringApplication.exit(...)` 반환값을 그대로 `System.exit` (`RewardBatchApplication:23`). 기본 실패 코드 `OPERATION_NOT_PERMITTED = 1` (`RewardBatchApplication:14`). |

### 1-2. `reward-api` 와의 공유

`reward-batch/build.gradle:10-17`:

```gradle
dependencies {
    implementation rootProject                            // 루트(=공용) 모듈의 jar
    testImplementation project(":reward-test")
    implementation platform("org.springframework.cloud:spring-cloud-dependencies:${spring_cloud_version}")
    implementation "org.springframework.boot:spring-boot-starter-batch"
    testImplementation "org.springframework.batch:spring-batch-test"
}
```

| 공유 자원 | 위치 | 사용처 |
|---|---|---|
| MyBatis `*Dao` 인터페이스 | `src/main/java/com/wadiz/api/reward/coupon/infra/dao/` | `CouponQueryDao`, `ProjectCouponSummaryDao`, `CouponTransactionSummationDao` — 배치의 Reader/Tasklet 이 직접 호출 |
| Mapper XML | `src/main/resources/mapper/reward/coupon/*-mapper.xml` | 위 3개 Dao 의 SQL |
| HTTP 클라이언트 | `src/main/java/com/wadiz/api/reward/support/client/**` | `FundingApiClient`, `PushClient`, `AlimTalkMessageClient`, `NormalMailClient`, `BackOfficeApiClient` |
| 속성 | `src/main/java/com/wadiz/api/reward/config/WadizProperties.java` | 딥링크 / 웹 URL 공통값 |
| DTO / Enum | 외부 jar `com.wadiz.api.reward:reward-models` (`gradle/wadiz.gradle:2`) | `CouponDto$ExpectedExpirationResponse`, `ProjectCouponSummaryDto$EventCoupon`, `CouponTransactionSummationDto$*` — 레포 안에서는 MyBatis `resultType` 문자열만 관측 가능 |

즉 `reward-batch` 는 순수하게 "Job/Step/Tasklet/Reader/Writer/외부 Sender" 를 정의하고, 도메인 SQL · HTTP 클라이언트는 루트 모듈에 의존한다.

### 1-3. 실행 인프라

| 인프라 | 설정 |
|---|---|
| Spring Batch JobRepository DB | `wadiz_funding_batch` (`application.yml:5-10`) — `jdbc:mysql://.../wadiz_funding_batch` |
| 테이블 프리픽스 | `RWD_BATCH_` (`application.yml:4`) — JobRepository 메타(`RWD_BATCH_JOB_INSTANCE`, `RWD_BATCH_JOB_EXECUTION`, …) |
| 배치 DataSource | `@BatchDataSource` 로 지정 (`RewardBatchDbConfig:17`) — Hikari 기반, `spring.reward.datasource.batch.hikari` 프로퍼티 매핑 |
| 프로퍼티 스캔 | `@ConfigurationPropertiesScan("com.wadiz.api.reward")` (`RewardBatchApplication:12`) |
| 배포 파이프라인 | `Jenkinsfile-BATCH` — 환경별 서버(`dev/rc/rc2/live`) 에 jar scp → 심링크(`/app/com.wadiz.api.reward.batch/default`). 코멘트에 "Batch will be triggered by scheduler" (Jenkinsfile-BATCH:163) |
| 프로파일 | `application-dev.yml`, `application-rc.yml`, `application-rc2.yml`, `application-rc3.yml`, `application-live.yml` — 외부 호출 대상 endpoint (push, alimtalk, mail, backoffice, funding)만 교체 |

---

## 2. Batch Application 설정

### 2-1. `RewardBatchApplication`

`reward-batch/src/main/java/com/wadiz/api/reward/RewardBatchApplication.java:10-26`:

```java
@EnableBatchProcessing(modular = true)
@SpringBootApplication
@ConfigurationPropertiesScan("com.wadiz.api.reward")
public class RewardBatchApplication {
  private static final int OPERATION_NOT_PERMITTED = 1;

  public static void main(String[] args) {
    int exitCode = OPERATION_NOT_PERMITTED;
    try {
      exitCode = SpringApplication.exit(new SpringApplicationBuilder(RewardBatchApplication.class)
          .web(WebApplicationType.NONE)
          .run(args));
    } finally {
      System.exit(exitCode);
    }
  }
}
```

포인트:
- `modular = true` — Job 마다 별도 `ApplicationContext` 가 생성되는 모듈러 모드. 본 레포에서는 `@ConditionalOnProperty` 로 1 Job 만 조건부 로드하므로 모듈러는 사실상 "다른 Job 빈 누락을 막는 격리" 정도로 기능한다.
- Non-web / 명시적 exit — OS 수준 크론에서 exit code 판정 가능.

### 2-2. `RewardBatchDbConfig`

`reward-batch/src/main/java/com/wadiz/api/reward/config/RewardBatchDbConfig.java:13-30`:

```java
@Configuration
public class RewardBatchDbConfig {

  @Bean
  @BatchDataSource
  @ConfigurationProperties("spring.reward.datasource.batch.hikari")
  public DataSource batchDataSource(
      @Qualifier("batchDataSourceProperties") final DataSourceProperties batchDataSourceProperties) {
    return batchDataSourceProperties.initializeDataSourceBuilder().type(HikariDataSource.class)
        .build();
  }

  @Bean
  @ConfigurationProperties("spring.reward.datasource.batch")
  public DataSourceProperties batchDataSourceProperties() {
    return new DataSourceProperties();
  }
}
```

- `@BatchDataSource` 를 통해 **Spring Batch 메타 DB** 만 이 DataSource 로 매핑.
- 실제 도메인 DB (`wadiz_reward` master/slave) 는 루트 모듈이 제공하는 DataSource 에서 MyBatis 로 접근 — 배치 메타와 도메인 DB 가 **물리적으로 분리**된다.

### 2-3. `PagingItemReaderSupport` — Reader 공통 베이스

`reward-batch/src/main/java/com/wadiz/api/reward/support/PagingItemReaderSupport.java:8-30`:

```java
public abstract class PagingItemReaderSupport<T> extends AbstractPagingItemReader<T> {

  protected PagingItemReaderSupport() {
    setPageSize(Integer.MAX_VALUE);
  }

  @Override
  protected final void doReadPage() {
    if (results == null) {
      results = new CopyOnWriteArrayList<>();
    } else {
      results.clear();
    }
    results.addAll(readPage());
  }

  protected abstract Collection<T> readPage();

  @Override
  protected final void doJumpToPage(final int itemIndex) {
    /* do nothing */
  }
}
```

특징:
- Spring Batch `AbstractPagingItemReader` 를 상속하되 `doReadPage` 를 final 로 고정하고 하위 구현체는 `readPage()` 만 채우면 된다.
- `results` 를 `CopyOnWriteArrayList` 로 초기화 — 멀티스레드 접근 가능성을 고려한 듯하나, 동일 파일 상단에서 `setPageSize(Integer.MAX_VALUE)` 이므로 기본 동작은 "한 번에 전체 로드"에 가깝다. 실제 구현체 `CouponExpirationNotificationReader` 는 생성자에서 `setPageSize(1000)` 으로 재설정한다.
- `doJumpToPage` 는 no-op — 배치 재시작 시 페이지 재위치 기능 비활성.
- 이 베이스를 상속하는 클래스는 현재 레포에서 `CouponExpirationNotificationReader` 단 1종.

### 2-4. 주요 application.yml 설정값

| 키 | dev 값 | live 값 |
|---|---|---|
| `spring.batch.jdbc.table-prefix` | `RWD_BATCH_` | `RWD_BATCH_` |
| `spring.reward.datasource.batch.url` | `jdbc:mysql://192.168.0.162:3306/wadiz_funding_batch` (`application.yml:8`) | `jdbc:mysql://172.31.1.200:3306/wadiz_funding_batch` (`application-live.yml:39`) |
| `spring.reward.datasource.master/slave` | `192.168.0.162/163:3306/wadiz_reward` (`application-dev.yml:25-34`) | `172.31.1.11(master)/172.31.1.65(slave):8450/wadiz_reward` (`application-live.yml:27-36`) |
| `application.push-client.url` | `https://dev-platform.wadizcorp.net/push` (`application-dev.yml:65-66`) | `https://platform.wadiz.kr/push` (`application-live.yml:78-79`) |
| `application.alim-talk-client.url` | `https://dev-platform.wadizcorp.net/alimtalk` | `https://platform.wadiz.kr/alimtalk` |
| `application.normal-mail-client.url` | `https://dev-platform.wadizcorp.net/mail-normal` | `https://platform.wadiz.kr/mail-normal` |
| `application.funding-client.url` | `http://dev-app01:9990/funding` | `http://172.31.1.12:9990/funding` |
| `application.backoffice-client.url` | `https://dev-platform.wadizcorp.net/backoffice` | `https://platform.wadiz.kr/backoffice` |
| `application.wadiz.*` | `dev.wadiz.kr` / `wadiz://` / `dev.wadiz.kr` | `www.wadiz.kr` / `wadiz://` / `www.wadiz.kr` |

---

## 3. Job별 상세

### 3-1. `couponExpirationNotificationJob` — 쿠폰 만료 알림

**JobConfig**: `reward-batch/src/main/java/com/wadiz/api/reward/job/couponexpirationnotification/CouponExpirationNotificationJobConfig.java`

**트리거**: 외부 실행. 기획 문서(`work/features/coupon/expiry-coupon-push-inbox.md:3-13`)상 "만료 당일" 에 알림을 내보내는 배치다. `CouponExpirationNotificationReader.readPage()` 는 `LocalDateTime.now()` ~ 오늘 23:59:59 구간을 `EffectedUntil` 조건으로 조회하므로, 실행 시각부터 당일 24:00 까지 만료 예정 쿠폰을 대상으로 한다.

#### 3-1-1. JobConfig 구성

`CouponExpirationNotificationJobConfig.java:25-83`:

- `@ConditionalOnProperty("spring.batch.job.names"="couponExpirationNotificationJob")` 로 조건부 로드
- 단일 Step: `couponExpirationNotificationStep`
  - Chunk size: **1000** (`JobConfig:34`)
  - Reader: `CouponExpirationNotificationReader`
  - Writer: `CouponExpirationNotificationWriter` (`@StepScope`, 팩토리 메서드 `JobConfig:77-82`)
  - StepExecutionListener (`JobConfig:37-53`):
    - `beforeStep`: `CouponExpirationNotificationWriter.transactionId = UUID.randomUUID()` — 스텝 단위로 전체 발송건을 묶을 tid 생성
    - `afterStep`: `userSkipCount > 0` 이면 `BatchStatus.UNKNOWN` + `ExitStatus("UNKNOWN-FAILED")` — Funding API 에서 돌려받지 못한 사용자가 있으면 **Job 전체를 "실패는 아니나 부분 스킵"** 으로 표시
- Job: `couponExpirationNotificationJob` — `flow(step).end().listener(JobExecutionListener)` 만 수행(재시작 incrementer 없음)

#### 3-1-2. Reader

`CouponExpirationNotificationReader.java:16-32`:

```java
@Component
public class CouponExpirationNotificationReader extends PagingItemReaderSupport<CouponDto.ExpectedExpirationResponse> {

  private final CouponQueryDao couponQueryDao;

  public CouponExpirationNotificationReader(final CouponQueryDao couponQueryDao) {
    setPageSize(1000);
    this.couponQueryDao = couponQueryDao;
  }

  @Override
  protected Collection<CouponDto.ExpectedExpirationResponse> readPage() {
    final LocalDateTime startDateTime = LocalDateTime.now();
    final LocalDateTime endDateTime = LocalDate.now().atTime(LocalTime.of(23, 59, 59));
    final Pageable pages = PageRequest.of(getPage(), getPageSize());
    return couponQueryDao.getAllExpectedExpirationCouponsGroupByUser(startDateTime, endDateTime, pages);
  }
}
```

**접근 SQL** (`src/main/resources/mapper/reward/coupon/coupon-query-mapper.xml:5-17`):

```xml
<select id="getAllExpectedExpirationCouponsGroupByUser"
        resultType="com.wadiz.api.reward.dto.coupon.CouponDto$ExpectedExpirationResponse">
  SELECT CP.OwnerUserId,
         GROUP_CONCAT(distinct CT.CouponName) AS CouponName,
         GROUP_CONCAT(distinct IFNULL(CTL.CouponName, CT.CouponName)) AS CouponNameEn
  FROM Coupon CP USE INDEX(IDX_Coupon__EffectedUntil_IsUsed_OwnerUserId_TemplateNo)
  JOIN CouponTemplate CT ON CT.TemplateNo = CP.TemplateNo
  LEFT JOIN CouponTemplateLanguage CTL ON CTL.TemplateNo = CT.TemplateNo AND CTL.LanguageCode = 'en'
  WHERE CP.EffectedUntil BETWEEN #{effectedStartDateTime} AND #{effectedEndDateTime}
  AND CP.IsUsed = false
  AND CT.IsNotificationAllowed = true
  GROUP BY CP.OwnerUserId
  LIMIT #{pageable.offset}, #{pageable.pageSize}
</select>
```

관찰:
- 인덱스 힌트 `USE INDEX(IDX_Coupon__EffectedUntil_IsUsed_OwnerUserId_TemplateNo)` 명시.
- 유저 1명당 1 row — `CouponName` 은 `GROUP_CONCAT(distinct)` 로 합침 (알림톡 '쿠폰목록' 필드에 그대로 삽입됨, 뒤에서 설명).
- 영어 영문 쿠폰명은 `CouponTemplateLanguage.LanguageCode='en'` 에서 끌어오되, 없으면 `IFNULL` 로 한글 이름 폴백.
- `IsNotificationAllowed = true` — 메이커가 알림 허용으로 설정한 템플릿만 포함.

countSummation 격인 `countExpectedExpirationCouponsGroupByUser` (`coupon-query-mapper.xml:19-26`) 도 정의되어 있으나, Reader 는 호출하지 않는다(조사 범위 안에서는 미사용).

#### 3-1-3. Writer

`CouponExpirationNotificationWriter.java:20-49`:

```java
public class CouponExpirationNotificationWriter implements ItemWriter<CouponDto.ExpectedExpirationResponse> {

  protected static int userSkipCount = 0;
  protected static UUID transactionId;

  private final FundingApiClient fundingApiClient;
  private final CouponExpirationSender couponExpirationSender;

  @Override
  public void write(final List<? extends CouponDto.ExpectedExpirationResponse> items) {
    if (!ObjectUtils.isEmpty(items)) {
      final List<Integer> userIds = items.stream().map(CouponDto.ExpectedExpirationResponse::getOwnerUserId).collect(Collectors.toList());
      final Map<Integer, UserResponse> userMap = getUserMap(userIds);
      updateUserSkipCount(userIds.size() - userMap.size());
      final List<CouponDto.ExpectedExpirationResponse> expiredItems = (List<CouponDto.ExpectedExpirationResponse>) items;
      couponExpirationSender.send(expiredItems, userMap, transactionId);
    }
  }

  private Map<Integer, UserResponse> getUserMap(final List<Integer> userIds) {
    final List<UserResponse> users = fundingApiClient.getAllUser(UserListRequest.builder().userIds(userIds).build());
    return users.stream().collect(Collectors.toMap(UserResponse::getId, Function.identity()));
  }
}
```

흐름:
1. chunk(≤1000) 각 item 에서 `OwnerUserId` 만 뽑아 → `FundingApiClient.getAllUser(...)` 로 일괄 조회 — `POST /api/internal/users` (`FundingApiClient.java:37-42`).
2. 반환된 `UserResponse` 를 userId→UserResponse Map 으로 변환.
3. 요청 유저 수와 응답 유저 수의 차이를 **static userSkipCount** 에 누적. Step 종료 listener 에서 이 값으로 ExitStatus 판정.
4. `CouponExpirationSender.send(items, userMap, transactionId)` 호출 → 실제 구현은 `CompositeCouponExpirationSender`.

⚠ 관찰:
- `userSkipCount`, `transactionId` 모두 `static` — 같은 JVM 내 재실행 시 상태가 누적/덮어써진다(배치는 한 번 돌고 `System.exit` 이므로 현실적 문제는 없음).
- Writer 는 `@StepScope` 로 생성된다(JobConfig:77).

#### 3-1-4. `CouponExpirationSender` / `CompositeCouponExpirationSender`

인터페이스(`CouponExpirationSender.java:10-15`):

```java
public interface CouponExpirationSender {
  void send(
      List<CouponDto.ExpectedExpirationResponse> items,
      Map<Integer, UserResponse> userMap,
      UUID transactionId);
}
```

`CompositeCouponExpirationSender.java:16-36`:

```java
@Component
public class CompositeCouponExpirationSender implements CouponExpirationSender {
  private final List<CouponExpirationSender> senders;

  public CompositeCouponExpirationSender(
       CouponExpirationAlimTalkSender alimTalkSender,
       CouponExpirationNormalMailSender normalMailSender,
       CouponExpirationPushSender pushSender) {
    this.senders = Arrays.asList(alimTalkSender, normalMailSender, pushSender);
  }

  @Override
  public void send(
      List<CouponDto.ExpectedExpirationResponse> items,
      Map<Integer, UserResponse> userMap,
      UUID transactionId) {
    for (CouponExpirationSender sender : senders) {
      sender.send(items, userMap, transactionId);
    }
  }
}
```

- **알림톡 → 메일 → 푸시** 순서로 3채널 순차 호출. 한 쪽이 예외를 던지면 나머지 채널은 전송되지 않는다(try/catch 없음). 각 Sender 내부에서 필터링하여 대상이 없으면 즉시 return.
- `send()` 는 chunk 단위로 호출되므로 Job 당 여러 번 실행 — `transactionId` 는 1 Step 내 공유되는 동일 UUID.

#### 3-1-5. 채널별 외부 Sender

##### (A) `CouponExpirationAlimTalkSender` (한국 유저 전용)

`external/CouponExpirationAlimTalkSender.java:22-71`:

- 템플릿 번호: `TEMPLATE_NO = 3152` (`:24`)
- 우선순위: `AlimTalkMessageRequest.Priority.SLOW` (`:39`)
- 수신 조건(`:52`):
  - `user != null`
  - `user.hasPhoneNumber()` (`StringUtils.hasText(phoneNumber)`, `UserResponse.java:20-22`)
  - `UserStatus == NM` (정상회원, `UserResponse.java:29-30`)
  - `languageCode == "ko"` (한국 유저만 — `!Locale.KOREA.getLanguage().equalsIgnoreCase(...)` 이면 skip)
- 템플릿 변수 매핑(`:57-62`):
  | 변수 | 값 |
  |---|---|
  | `닉네임` | `user.getName()` |
  | `쿠폰목록` | `item.getCouponName()` (SQL의 `GROUP_CONCAT` 한글 쿠폰명들) |
  | `알림발송일` | `LocalDate.now().format("yyyy.MM.dd 23시 59분까지")` |
  | `앱링크` | `web/wmypage/mybenefit/coupon/my?utm_source=wadiz_rs&utm_medium=talk&utm_campaign=coupon_remind&utm_content=supporter` |
  | `웹링크` | `{application.wadiz.domain-url}/web/wmypage/mybenefit/coupon/my?utm_source=...` |
- 빌더 `AlimTalkMessageRequest.builder().tid(transactionId).templateNo(TEMPLATE_NO).priority(SLOW).payloads(payloads).build()` → `AlimTalkMessageClient.sendAlimTalkMessages(...)` 호출.
- `AlimTalkMessageClient.java:23-32` — `POST /api/v2/message/alimtalk` (`Authorization: Bearer <internal-api-token>`, `Content-Type: application/json`).

##### (B) `CouponExpirationNormalMailSender` (해외 유저 전용)

`external/CouponExpirationNormalMailSender.java:24-102`:

- 템플릿 번호: `TEMPLATE_NO = 1429` (`:26`)
- 수신 조건(`:62-75`, 알림톡과 반대):
  - `user != null && user.hasEmail()` (`StringUtils.hasText(email)`)
  - `UserStatus == NM`
  - **비한국 유저** — `!Locale.KOREA.getLanguage().equalsIgnoreCase(user.getLanguageCode())`
- 먼저 `languageCode` 별로 grouping 한 뒤(`:59`), 각 언어 그룹마다 `NormalMailClient.sendNormalMail(request, languageCode)` 호출.
- 템플릿 변수 매핑(`:88-97`):
  | 변수 | 값 |
  |---|---|
  | `nickName` | `user.getName()` |
  | `expiringCouponName` | `item.getCouponNameEn()` (영문/기본 쿠폰명) |
  | `couponAvailableDate` | `ZonedDateTime.now().format("MMM d, yyyy, 11:59:59 'PM' z", Locale.ENGLISH)` |
  | `myCouponUrl` | `{application.wadiz.web-url}/my-wadiz/coupons?utm_source=wadiz_rs&utm_medium=talk&utm_campaign=coupon_remind&utm_content=supporter` |
- 요청 객체(`NormalMailRequest.java:11-19`):
  - `tid = transactionId` / `domainCode = "COUPON_EXPIRED"` / `templateNo = 1429` / `mailInfoList = payloads` / `isAd = false` (기본값)
- `NormalMailClient.java:23-33` — `POST /api/v3/send`, 헤더 `wadiz-Language: <languageCode>` 추가.

##### (C) `CouponExpirationPushSender` (해외 유저 전용: en/ja/zh)

`external/CouponExpirationPushSender.java:19-144`:

- 수신 조건(`:68-81`) — AlimTalk 과 반대, Mail 과 동일:
  - `user != null && UserStatus == NM && languageCode != ko`
- 언어별 grouping: `Collectors.groupingBy(user.languageCode)` (`:65`) → `RequestBodyTranslator` 로 각 언어(en/ja/zh)별 제목·본문 Element 묶음 생성 (`RequestBodyTranslator.java:38-63`).
- `RequestBodyTranslator` 번역 테이블 (`RequestBodyTranslator.java:15-32`):
  | 언어 | PUSH TITLE | PUSH BODY | INBOX TITLE |
  |---|---|---|---|
  | EN | `Coupon Expiration Notice` | `#{nickName}, Your Coupon is About to Expire! Check Before it's Gone!` | `Coupon Expiration Notice<br>\n#{nickName}, Your Coupon is About to Expire! Check Before it's Gone!` |
  | JA | `クーポンの有効期限通知` | `#{nickName}さん、クーポンの有効期限が近づいています！お見逃しなくご確認ください！` | `クーポンの有効期限通知\n#{nickName}さん、クーポンの有効期限が近づいています！お見逃しなくご確認ください！` |
  | ZH | `优惠券到期通知` | `#{nickName}，您的优惠券即将到期！请在失效前查看！` | `优惠券到期通知<br>\n#{nickName}，您的优惠券即将到期！请在失效前查看！` |

- `LocaleConstants.java:7-9` — 언어 상수(`en`, `ja`, `zh`):
  ```java
  public static final String EN_LOCALE = Locale.ENGLISH.getLanguage();
  public static final String JP_LOCALE = Locale.JAPANESE.getLanguage();
  public static final String ZH_LOCALE = Locale.CHINESE.getLanguage();
  ```
  ⚠ 한국어(`ko`) 상수는 없음 — 한국어 유저는 PushSender 에서 명시적으로 제외(알림톡 채널로만 보냄).
- 푸시 딥링크 / 웹링크(`:137-143`):
  - Deep link: `{application.wadiz.deep-link-url}` + `/my-wadiz/coupons` + UTM
  - Web URL: `{application.wadiz.web-url}` + `/my-wadiz/coupons` + UTM
- `PushAndInboxRequest` 빌드(`:96-114`) — 17개 필드(생성자 인자 순서, `PushAndInboxRequest.java:31-50`):
  ```java
  new PushAndInboxRequest(
      userIds,                // List<Long>
      elements.pushTitle,
      elements.pushBody,
      buildDeepLinkUrl(),
      false,                  // isAd
      transactionId.toString(),
      ServiceCode.FUNDING,    // serviceCode
      DomainCode.COUPON_EXPIRED,
      elements.inboxTitle,
      buildWebUrl(),
      0,                      // senderId (SYSTEM 이므로 의미상 미사용)
      SenderType.SYSTEM,
      languageCode,           // EN_LOCALE / JP_LOCALE / ZH_LOCALE
      templateData,           // Map<Long, Map<String, Object>> { userId → { nickName } }
      null,                   // image
      false,                  // isSendDaybreak
      null,                   // projectNo
      null);                  // inboxBody
  ```
- `templateData` 구성(`:117-135`): 유저별 `{ "nickName": user.getName() }` — 푸시 서버가 `#{nickName}` 치환을 수행.
- `PushClient.java:25-41` — `POST /api/v1/push/inbox`, `Content-Type: application/json` (Bearer 헤더는 `PushClient` 에서 추가하지 않음. AlimTalk / NormalMail 과 달리 **Authorization 헤더 없이** RestTemplate `rootUri` 만 설정).

##### (D) 3채널 대상 분리 요약

| 조건 | AlimTalk | NormalMail | Push |
|---|---|---|---|
| `user.userStatus == NM` | ✅ | ✅ | ✅ |
| `hasPhoneNumber()` | ✅ | — | — |
| `hasEmail()` | — | ✅ | — |
| `languageCode == ko` | ✅ | ❌ | ❌ |
| `languageCode in (en/ja/zh)` | ❌ | ✅ (언어별 그룹) | ✅ (en/ja/zh 각각) |

즉 **한국 유저 → AlimTalk 단일 채널**, **해외 유저 → Mail + Push 이중 채널** 이 의도된 설계다.

#### 3-1-6. 종료 상태

`JobConfig:45-51`:

```java
if (CouponExpirationNotificationWriter.userSkipCount > 0) {
  stepExecution.setStatus(BatchStatus.UNKNOWN);
  stepExecution.setExitStatus(new ExitStatus("UNKNOWN-FAILED"));
}
```

— Funding User API 가 반환하지 않은 userId(탈퇴/휴면 등으로 응답에서 누락된 경우)가 하나라도 있으면 Step/Job 종료코드를 `UNKNOWN-FAILED` 로 설정. `System.exit` 값은 Spring Boot 내부 규칙에 따라 "비정상 종료 코드"로 전파된다.

---

### 3-2. `projectCouponSummaryJob` — 프로젝트별 쿠폰 집계

**JobConfig**: `reward-batch/src/main/java/com/wadiz/api/reward/job/projectcouponsummary/ProjectCouponSummaryJobConfig.java`

**트리거**: 외부 실행. 기획 문서 별도 없음(work/features/coupon/ 에 전용 md 없음).

#### 3-2-1. JobConfig 구성

`ProjectCouponSummaryJobConfig.java:22-69`:

- `@ConditionalOnProperty("spring.batch.job.names"="projectCouponSummaryJob")`
- Step 2종:
  - `projectCouponSummaryStep` — `ProjectCouponSummaryTasklet` (단일 Tasklet)
  - `fallbackStep` — `projectCouponSummaryDao.dropNewTable()` 후 종료 (오류 복구용)
- Job 흐름(`:38-43`):
  ```java
  jobBuilderFactory.get("projectCouponSummaryJob")
      .incrementer(new RunIdIncrementer())
      .start(projectCouponSummaryStep).on("FAILED").to(fallbackStep)
      .from(projectCouponSummaryStep).on("*").end()
      .end()
  ```
  — 첫 Step 이 FAILED 면 `fallbackStep` 으로 분기해 `_new` 임시 테이블을 정리. 성공이면 Job 종료.

#### 3-2-2. Tasklet

`ProjectCouponSummaryTasklet.java:27-93`:

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class ProjectCouponSummaryTasklet implements Tasklet {

  private final ProjectCouponSummaryDao projectCouponSummaryDao;
  private final BackOfficeApiClient backOfficeApiClient;

  @Override
  @Transactional
  public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
    log.info("NEW ProjectCouponSummary 생성: date time {}", LocalDateTime.now());
    projectCouponSummaryDao.createNewTable();
    log.info("ProjectCouponSummary 데이터 1차 적재");
    projectCouponSummaryDao.insertDownloadCoupon();
    // 기획전쿠폰 제외
//    final List<ProjectCouponSummaryDto.EventCoupon> eventCoupons = getEventCoupons();
//    if (!CollectionUtils.isEmpty(eventCoupons)) {
//      log.info("ProjectCouponSummary 데이터 2차 적재");
//      projectCouponSummaryDao.insertApiIssueEventCoupon(eventCoupons);
//    }
    log.info("RENAME ProjectCouponSummary");
    projectCouponSummaryDao.renameSwapTable();
    log.info("DROP Old ProjectCouponSummary");
    projectCouponSummaryDao.dropOldTable();
    return RepeatStatus.FINISHED;
  }
```

현재 라이브 흐름:
1. `createNewTable()` — `ProjectCouponSummary_new` 임시 테이블 생성
2. `insertDownloadCoupon()` — 다운로드형 쿠폰 데이터 적재
3. (**주석 처리됨**) 기획전 쿠폰 수집·적재 — `getEventCoupons()` 는 코드상 정의되어 있으나 호출 자체가 주석 처리됨. `BackOfficeApiClient.getCollectionCoupons()` 는 현재 프로덕션에서는 호출되지 않는다.
4. `renameSwapTable()` — `ProjectCouponSummary` ↔ `ProjectCouponSummary_new` 원자적 swap
5. `dropOldTable()` — `ProjectCouponSummary_old` 삭제

전체 실행이 `@Transactional` 이지만 DDL(`CREATE`, `DROP`, `RENAME`)은 MySQL 에서 암시적 커밋을 발생시켜 트랜잭션 범위가 실질적으로 끊어짐 — "문제 발생 시 `fallbackStep` 이 `_new` 임시 테이블을 DROP" 하는 보상(rollback 대용) 전략을 취한다.

#### 3-2-3. 접근 SQL

파일: `src/main/resources/mapper/reward/coupon/project-coupon-summary-mapper.xml`

**`createNewTable`** (`:5-7`):
```sql
CREATE TABLE ProjectCouponSummary_new LIKE ProjectCouponSummary
```

**`dropNewTable`** (`:9-11`):
```sql
DROP TABLE IF EXISTS ProjectCouponSummary_new
```

**`insertDownloadCoupon`** (`:13-59`):
```sql
INSERT INTO ProjectCouponSummary_new (ProjectNo, TemplateNo, TargetType, CouponName, DiscountType, DiscountAmount, DiscountRate, MinFundingAmount, MaxDiscountAmount, LimitQtyPerUser, IssueKey, EffectedFrom, EffectedTo)
SELECT CM.TargetConditionKey AS ProjectNo,
       CT.TemplateNo,
       'FUNDING' AS TargetType,
       CT.CouponName,
       CT.DiscountType,
       CT.DiscountAmount,
       CT.DiscountRate,
       CT.MinFundingAmount,
       CT.MaxDiscountAmount,
       CT.LimitQtyPerUser,
       CI.IssueKey,
       CT.EffectedFrom,
       CT.EffectedTo
FROM CouponTemplate CT
JOIN CouponTargetConditionMapping CM ON CM.TemplateNo = CT.TemplateNo AND CT.TargetConditionType = 'PROJECT'
JOIN CouponIssueSummation CS ON CS.TemplateNo = CT.TemplateNo
JOIN CouponIssue CI ON CI.TemplateNo = CT.TemplateNo AND CI.Times = 1
WHERE CT.IssueType = 'DOWNLOAD'
  AND CT.IssueTargetType = 'ALL'
  AND CT.EffectedFrom <![CDATA[ <= ]]> NOW() + INTERVAL 1 HOUR AND CT.EffectedTo <![CDATA[ >= ]]> NOW()
  AND CT.TotalLimitQty > CS.Qty
-- UNION ALL (아래 블록 주석 처리됨 — COLLECTION/RewardCollectionMapping 조인)
```

관찰:
- **1시간 선행 윈도우** — `EffectedFrom <= NOW() + INTERVAL 1 HOUR` 로 곧 시작될 쿠폰도 포함.
- **잔여 수량 조건** — `CT.TotalLimitQty > CS.Qty` (이미 소진된 쿠폰 제외).
- 원래 하위 쿼리(`UNION ALL`, `TargetConditionType = 'COLLECTION'` 조인으로 `RewardCollectionMapping.CollectionNo` → `CampaignId` 역매핑)가 있었으나 **전부 주석 처리**됨 — Tasklet 의 `getEventCoupons()` 주석 처리와 짝.

**`selectEventCoupon`** (`:61-89`) — Tasklet 에서 **미사용**이지만 XML 에는 그대로 존재:
```sql
SELECT RCM.CampaignId AS ProjectNo, CT.TemplateNo, 'FUNDING' AS TargetType, ...
FROM CouponTemplate CT
JOIN CouponTargetConditionMapping CM ON CM.TemplateNo = CT.TemplateNo AND CT.TargetConditionType = 'COLLECTION'
JOIN RewardCollectionMapping RCM ON RCM.CollectionNo = CAST(CM.TargetConditionKey AS UNSIGNED)
JOIN CouponIssueSummation CS ON CS.TemplateNo = CT.TemplateNo
JOIN CouponIssue CI ON CI.TemplateNo = CT.TemplateNo AND CI.Times = 1
WHERE CT.IssueType = 'API_ISSUE'
  AND CT.IssueTargetType = 'ALL'
  AND CT.EffectedFrom <= NOW() + INTERVAL 1 HOUR AND CT.EffectedTo >= NOW()
  AND CT.TotalLimitQty > CS.Qty
  AND CT.IsNotificationAllowed = true
  AND CT.TemplateNo IN (<foreach>...</foreach>)
```

**`insertApiIssueEventCoupon`** (`:91-112`) — 미사용:
```sql
INSERT INTO ProjectCouponSummary_new (ProjectNo, TemplateNo, TargetType, CouponName, DiscountType, DiscountAmount, DiscountRate, MinFundingAmount, MaxDiscountAmount, LimitQtyPerUser, IssueKey, EventKeyword, EventTargetType, EffectedFrom, EffectedTo)
VALUES <foreach item="projectCoupon" ... separator=",">
  (#{projectCoupon.projectNo}, #{projectCoupon.templateNo}, #{projectCoupon.targetType}, ...)
</foreach>
```

**`renameSwapTable`** (`:114-119`):
```sql
RENAME TABLE
    ProjectCouponSummary TO ProjectCouponSummary_old,
    ProjectCouponSummary_new TO ProjectCouponSummary
```
— MySQL 의 원자적 swap — 서비스 중단 없이 테이블 교체.

**`dropOldTable`** (`:121-123`):
```sql
DROP TABLE IF EXISTS ProjectCouponSummary_old
```

**`selectProjectCouponList`** (`:125-145`) — 배치에서는 호출하지 않음. reward-api (런타임 조회) 용으로 보이는 select 이 같은 파일에 공존.

#### 3-2-4. `getEventCoupons` / `getEventCouponMap` (미사용 주석 경로)

`ProjectCouponSummaryTasklet.java:52-92` 에는 아래 흐름이 작성돼 있으나 현재 `execute()` 에서는 호출하지 않는다:

1. `backOfficeApiClient.getCollectionCoupons()` — `GET /collection/coupon` (`BackOfficeApiClient.java:26-30`)
2. `CollectionCouponListResponse` 트리에서 `CollectionCoupon.apiCouponList[*]` 를 평탄화
3. `actionType == BENEFIT` & `eventCouponList` 비어있지 않은 `ApiCoupon` 만 수집 (`:82-85`)
4. `couponTemplateNo → "eventKeyword,targetType"` 맵 구성
5. `projectCouponSummaryDao.selectEventCoupon(templateNos)` 로 DB 조인 → DTO 의 `eventKeyword/eventTargetType` 채움
6. `projectCouponSummaryDao.insertApiIssueEventCoupon(...)` 로 2차 적재

예외 처리: `BackOfficeApiClientException` 만 `empty map` 반환으로 삼켜 처리(`:88-91`). 다른 예외는 Tasklet 까지 전파되어 Step FAILED → fallback 분기.

---

### 3-3. `couponTransactionSummationJob` / `couponTransactionSummationTodayJob` — 쿠폰 거래 합계

동일 구조의 2 Job 으로 **집계 대상 일자만 다르다**.

| 구분 | JobConfig | Tasklet | 대상 일자 |
|---|---|---|---|
| 전일 | `CouponTransactionSummationJobConfig.java` | `CouponTransactionSummationTasklet.java` | `LocalDate.now().minusDays(1)` |
| 당일 | `CouponTransactionSummationTodayJobConfig.java` | `CouponTransactionSummationTodayTasklet.java` | `LocalDate.now()` |

#### 3-3-1. JobConfig (전일 집계)

`CouponTransactionSummationJobConfig.java:20-54`:

- `@ConditionalOnProperty("spring.batch.job.names"="couponTransactionSummationJob")`
- 단일 Step: `couponTransactionSummationStep` — Tasklet 기반 (Reader/Writer/Chunk 없음)
- Job: `.incrementer(new RunIdIncrementer()).flow(step).end()` — 동일 파라미터 재실행 허용

`CouponTransactionSummationTodayJobConfig.java:20-54` — 이름 / 조건부 값 / Tasklet 참조만 다를 뿐 동일 구조.

**참고**: 집계는 Tasklet 안의 단일 SQL (`INSERT ... SELECT ... GROUP BY`) 로 수행되므로 Spring Batch 의 청크 단위 처리 파이프라인은 사용하지 않는다. 즉 "청크 단위 처리"가 아니라 "DB 에서 한 번에 SUM/GROUP BY 집계".

#### 3-3-2. Tasklet (전일)

`CouponTransactionSummationTasklet.java:19-33`:

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class CouponTransactionSummationTasklet implements Tasklet {

  private final CouponTransactionSummationDao couponTransactionSummationDao;

  @Override
  public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
    final LocalDate targetDate = LocalDate.now().minusDays(1);
    log.info("쿠폰 거래 집계 대상 일자: {}", targetDate);
    final Integer deleteRowCount = couponTransactionSummationDao.deleteAllByTransactionDate(targetDate);
    log.info("쿠폰 거래 집계 delete row count: {}", deleteRowCount);
    final Integer insertRowCount = couponTransactionSummationDao.insertSelectCouponTransactionSummation(targetDate, LocalDateTime.of(targetDate, LocalTime.MIN), LocalDateTime.of(targetDate, LocalTime.MAX));
    log.info("쿠폰 거래 집계 insert row count: {}", insertRowCount);
    return RepeatStatus.FINISHED;
  }
}
```

흐름: **delete-then-insert** (재실행 안전성 확보).
1. `deleteAllByTransactionDate(targetDate)` — 해당 날짜의 기존 집계 행 전체 삭제
2. `insertSelectCouponTransactionSummation(targetDate, startOfDay, endOfDay)` — 새로 집계 INSERT

당일 Tasklet (`CouponTransactionSummationTodayTasklet.java:23-32`) 은 `LocalDate.now().minusDays(1)` 대신 `LocalDate.now()` 만 쓰는 동일 로직.

#### 3-3-3. 접근 SQL

파일: `src/main/resources/mapper/reward/coupon/coupon-transaction-summation-mapper.xml`

**`deleteAllByTransactionDate`** (`:178-180`):
```sql
DELETE FROM wadiz_reward.CouponTransactionSummation WHERE TransactionDate = #{transactionDate}
```

**`insertSelectCouponTransactionSummation`** (`:141-176`):
```sql
INSERT INTO wadiz_reward.CouponTransactionSummation (TemplateNo, TransactionDate, RedeemQty, RedeemAmount, RedeemCancelQty, RedeemCancelAmount, UseQty, UseAmount, FundingAmount, UseCancelQty, UseCancelAmount, RefundQty, RefundAmount, RefundCancelQty, RefundCancelAmount, WithdrawQty, WithdrawAmount, WithdrawCancelQty, WithdrawCancelAmount)
SELECT A.TemplateNo, DATE(#{targetDate}) AS TransactionDate,
    SUM(CASE WHEN CTS.TransactionType = 'REDEEM' THEN 1 ELSE 0 END) AS RedeemQty,
    SUM(CASE WHEN CTS.TransactionType = 'REDEEM' AND CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount ELSE 0 END) AS RedeemAmount,
    SUM(CASE WHEN CTS.TransactionType = 'REDEEM' AND CTS.IsCanceled = TRUE THEN 1 ELSE 0 END) AS RedeemCancelQty,
    SUM(CASE WHEN CTS.TransactionType = 'REDEEM' AND CTS.IsCanceled = TRUE AND DiscountType = 'FIXED_AMOUNT' THEN DiscountAmount ELSE 0 END) AS RedeemCancelAmount,
    SUM(CASE WHEN CTS.TransactionType = 'USE' THEN 1 ELSE 0 END) AS UseQty,
    SUM(CASE WHEN CTS.TransactionType = 'USE' AND CTS.ApplyAmount IS NOT NULL THEN CTS.ApplyAmount ELSE 0 END) AS UseAmount,
    SUM(CASE WHEN CTS.TransactionType = 'USE' AND CTS.FundingAmount IS NOT NULL THEN CTS.FundingAmount WHEN CTS.TransactionType = 'REFUND' AND CTS.FundingAmount IS NOT NULL THEN -CTS.FundingAmount ELSE 0 END) AS FundingAmount,
    SUM(CASE WHEN CTS.TransactionType = 'USE' AND CTS.IsCanceled = TRUE THEN 1 ELSE 0 END) AS UseCancelQty,
    SUM(CASE WHEN CTS.TransactionType = 'USE' AND CTS.IsCanceled = TRUE AND CTS.ApplyAmount IS NOT NULL THEN CTS.ApplyAmount ELSE 0 END) AS UseCancelAmount,
    SUM(CASE WHEN CTS.TransactionType = 'REFUND' THEN 1 ELSE 0 END) AS RefundQty,
    SUM(CASE WHEN CTS.TransactionType = 'REFUND' AND CTS.ApplyAmount IS NOT NULL THEN CTS.ApplyAmount ELSE 0 END) AS RefundAmount,
    SUM(CASE WHEN CTS.TransactionType = 'REFUND' AND CTS.IsCanceled = TRUE THEN 1 ELSE 0 END) AS RefundCancelQty,
    SUM(CASE WHEN CTS.TransactionType = 'REFUND' AND CTS.IsCanceled = TRUE AND CTS.ApplyAmount IS NOT NULL THEN CTS.ApplyAmount ELSE 0 END) AS RefundCancelAmount,
    SUM(CASE WHEN CTS.TransactionType = 'WITHDRAW' THEN 1 ELSE 0 END) AS WithdrawQty,
    SUM(CASE WHEN CTS.TransactionType = 'WITHDRAW' AND CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount ELSE 0 END) AS WithdrawAmount,
    SUM(CASE WHEN CTS.TransactionType = 'WITHDRAW' AND CTS.IsCanceled = TRUE THEN 1 ELSE 0 END) AS WithdrawCancelQty,
    SUM(CASE WHEN CTS.TransactionType = 'WITHDRAW' AND CTS.IsCanceled = TRUE AND CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount ELSE 0 END) AS WithdrawCancelAmount
FROM (
    SELECT    A.TransactionKey, A.TemplateNo
    FROM      wadiz_reward.CouponTransaction A
    WHERE     A.Registered BETWEEN #{startDateTime} AND #{endDateTime}
    AND       A.IsCanceled = FALSE
    UNION ALL
    SELECT    A.TransactionKey, A.TemplateNo
    FROM      wadiz_reward.CouponTransaction A
    WHERE     A.Updated BETWEEN #{startDateTime} AND #{endDateTime}
    AND       A.IsCanceled = TRUE
    AND       DATE(A.Registered) != DATE(A.Updated)
    ) A
    JOIN wadiz_reward.CouponTransaction CTS ON (CTS.TransactionKey = A.TransactionKey)
    JOIN wadiz_reward.CouponTemplate CT on CT.TemplateNo = A.TemplateNo
GROUP BY A.TemplateNo;
```

관찰:
- 대상 거래는 두 갈래를 `UNION ALL` 로 합친 인덱싱 키 집합:
  1. 그날 `Registered` 된 거래 (IsCanceled=FALSE)
  2. 그날 `Updated` 되어 취소된 거래 (IsCanceled=TRUE) — 단, 등록일과 수정일이 다른 날인 경우만(같은 날 등록·즉시 취소는 1번에서 잡힘)
- 4가지 `TransactionType` × `IsCanceled` 매트릭스에 대해 수량/금액 SUM:
  - REDEEM / USE / REFUND / WITHDRAW 각각 Qty, Amount, CancelQty, CancelAmount
  - `FundingAmount` 는 USE(+) 와 REFUND(-) 의 차로 순 펀딩 기여액 계산
  - REDEEM/WITHDRAW 의 금액은 `CT.DiscountAmount` (고정 할인쿠폰만 집계), USE/REFUND 금액은 `CTS.ApplyAmount` (실제 적용액)
- 동일 테이블 `CouponTransactionSummation` 은 런타임 조회 쿼리(`selectSummationQuery`, `countSummationQuery`, `forPagingSummation`, `sumCouponTransactionSummationTable` — XML `:16-91`) 에서 TemplateNo 별로 다시 합산되어 소비된다.

---

## 4. `work/features/coupon/` 기획서 요약

| 파일 | 요약 |
|---|---|
| `work/features/coupon/expiry-coupon-mail.md` | **빈 파일**(0 byte). 원래 해외 유저 쿠폰 만료 메일 사양을 담을 자리로 보이나 작성되지 않음. 실제 구현은 `CouponExpirationNormalMailSender` 의 `TEMPLATE_NO = 1429` 와 파라미터 4종(`nickName`/`expiringCouponName`/`couponAvailableDate`/`myCouponUrl`)으로 관찰 가능. |
| `work/features/coupon/expiry-coupon-push-inbox.md` | **해외 유저** 앱푸시/인박스 사양(en/ja/zh). Title/Body/Inbox 초안 영문 문구 명시(`:3-10`). `DomainCode: COUPON_EXPIRED` 및 "랜딩페이지: 나의쿠폰내역" 지정. TDD 체크리스트(10개 시나리오) + 구현 히스토리(Template Data, languageCode 수정 과정) 포함. |
| `work/features/coupon/push-client.md` | `PushClient` HTTP 스펙. dev/rc/rc2/rc3/live 환경별 endpoint (`https://{env}-platform.wadizcorp.net` / live 는 `platform.wadiz.kr`) 및 inbox-token 명시. 단 현재 `PushClient.java` 구현은 **Authorization 헤더를 주입하지 않음** — 기획서의 `Bearer CDC6CC5A...` 토큰은 문서상 근거만 있고 코드에서는 미적용. API 경로 `/push/api/v1/push/inbox`. `NotificationPushAndInboxReq` 필드 18종 정의. TDD 체크리스트 8개. |
| `work/features/coupon/push-client-request-body.md` | `PushAndInboxRequest` 생성자 검증 테스트 명세(18개 null/empty 시나리오). 구현 히스토리에서 `ServiceCode={FUNDING,INVEST,STARTUP}`, `DomainCode` 에 `COUPON_EXPIRED` 추가, `SenderType` 8종 확장 과정 명시. |
| `work/features/coupon/external/maker-coupon-template-controller.md` | **배치와 직접 무관** — 메이커가 쿠폰 템플릿을 생성/수정/조회하는 런타임 컨트롤러(`/api/v1/rewards/coupons/templates/maker`) 사양. Batch 에서 쓰이는 `ProjectCouponSummary_new` 적재 대상(`CouponTemplate`)의 데이터 원천을 생성하는 상위 파이프라인으로 참고만. |

**의도 요약**:
- 쿠폰 만료 배치는 **언어별 채널 분리** 를 통해 한국(알림톡) / 해외(메일 + 푸시 + 인박스) 알림을 구분한다.
- `PushAndInboxRequest` 는 푸시 + 인박스 메시지를 한 요청에 묶어 보낸다(`inboxTitle`, `inboxLink`, `inboxBody`, `domainCode` 가 인박스 용 필드).
- 해외 3개 언어(en/ja/zh) 문안은 `RequestBodyTranslator` 하드코딩. 더 많은 언어 지원 시 코드 수정 필요.
- 프로젝트 쿠폰 요약 / 거래 집계 기획서는 `work/features/coupon/` 내 별도 md 가 없어 **관찰 코드 기반**으로만 의도 추정 가능(프로젝트 페이지 배너용 캐시 테이블 + 매출/쿠폰 리포트용 일별 집계).

---

## 5. DB 상호작용

### 5-1. Job 별 접근 테이블

| Job | 작업 | 테이블 | 작업 유형 |
|---|---|---|---|
| `couponExpirationNotificationJob` | Reader | `Coupon`, `CouponTemplate`, `CouponTemplateLanguage` | SELECT (JOIN + GROUP_CONCAT, 인덱스 힌트) |
| `projectCouponSummaryJob` | Tasklet | `ProjectCouponSummary`, `ProjectCouponSummary_new`, `ProjectCouponSummary_old` | CREATE/DROP/RENAME/INSERT...SELECT |
| `projectCouponSummaryJob` | Tasklet (1차 적재) | `CouponTemplate`, `CouponTargetConditionMapping`, `CouponIssueSummation`, `CouponIssue` | SELECT (INSERT ... SELECT 내부) |
| `projectCouponSummaryJob` | fallbackStep | `ProjectCouponSummary_new` | DROP |
| `couponTransactionSummationJob` | Tasklet | `wadiz_reward.CouponTransactionSummation` | DELETE (targetDate) + INSERT ... SELECT |
| `couponTransactionSummationJob` | Tasklet (집계 원천) | `wadiz_reward.CouponTransaction`, `wadiz_reward.CouponTemplate` | SELECT (CASE SUM + GROUP BY TemplateNo) |
| `couponTransactionSummationTodayJob` | Tasklet | 동일 | 동일 (targetDate = today) |

### 5-2. Spring Batch 메타 DB

- DB: `wadiz_funding_batch` (별도 서버, live: `172.31.1.200:3306`)
- 접두사: `RWD_BATCH_`
- 테이블: `RWD_BATCH_JOB_INSTANCE`, `RWD_BATCH_JOB_EXECUTION`, `RWD_BATCH_JOB_EXECUTION_CONTEXT`, `RWD_BATCH_JOB_EXECUTION_PARAMS`, `RWD_BATCH_STEP_EXECUTION`, `RWD_BATCH_STEP_EXECUTION_CONTEXT`, sequences — (Spring Batch 표준 스키마, 본 레포에는 DDL 파일 없음)

### 5-3. SQL 요약 표

| 파일:라인 | ID | 유형 | 목적 |
|---|---|---|---|
| `coupon-query-mapper.xml:5-17` | `getAllExpectedExpirationCouponsGroupByUser` | SELECT | 만료 예정 쿠폰 보유 유저 단위 집계 (Reader) |
| `coupon-query-mapper.xml:19-26` | `countExpectedExpirationCouponsGroupByUser` | SELECT | count (미사용) |
| `project-coupon-summary-mapper.xml:5-7` | `createNewTable` | DDL | `_new` 테이블 생성 |
| `project-coupon-summary-mapper.xml:9-11` | `dropNewTable` | DDL | fallback 용 |
| `project-coupon-summary-mapper.xml:13-59` | `insertDownloadCoupon` | INSERT SELECT | 다운로드 쿠폰 적재 (UNION ALL 블록 주석 처리) |
| `project-coupon-summary-mapper.xml:61-89` | `selectEventCoupon` | SELECT | 기획전 쿠폰 조회 (Tasklet 미사용) |
| `project-coupon-summary-mapper.xml:91-112` | `insertApiIssueEventCoupon` | INSERT VALUES | 기획전 쿠폰 2차 적재 (미사용) |
| `project-coupon-summary-mapper.xml:114-119` | `renameSwapTable` | DDL | `_new` ↔ live 원자 swap |
| `project-coupon-summary-mapper.xml:121-123` | `dropOldTable` | DDL | old swap 정리 |
| `project-coupon-summary-mapper.xml:125-145` | `selectProjectCouponList` | SELECT | 런타임 조회 (배치 미사용) |
| `coupon-transaction-summation-mapper.xml:141-176` | `insertSelectCouponTransactionSummation` | INSERT SELECT | 일자별 거래 집계 |
| `coupon-transaction-summation-mapper.xml:178-180` | `deleteAllByTransactionDate` | DELETE | 재실행 안전성을 위한 선삭제 |
| `coupon-transaction-summation-mapper.xml:16-91` | `countSummationQuery`, `selectSummationQuery`, `forPagingSummation`, `sumCouponTransactionSummationTable` | SELECT | 런타임 리포트 조회 (배치 미사용) |

---

## 6. 외부 의존성

### 6-1. Funding API (유저 조회)

- 클라이언트: `FundingApiClient` (`support/client/funding/FundingApiClient.java`)
- 인증: `InternalAuthorizationInterceptor` + `application.funding-client.internal-api-token` (JWT, `application-*.yml`)
- 배치에서 호출: `getAllUser(UserListRequest)` — `POST /api/internal/users`
- 호출처: `CouponExpirationNotificationWriter.getUserMap(...)` (chunk 마다 1회)
- `UserResponse.UserStatus` 값: `NM`(정상), `IA`(휴면), `DO`(탈퇴) — `UserResponse.java:28-35`

### 6-2. Push Gateway (앱 푸시 + 인박스)

- 클라이언트: `PushClient` (`support/client/notification/push/PushClient.java`)
- 인증: **코드상 Authorization 헤더 미적용** (`PushClient.java:26-28` — `Content-Type` 만). 기획서(`push-client.md:19`)는 `Bearer <inbox-token>` 을 명시하지만 구현에 반영되지 않음.
- API: `POST /api/v1/push/inbox`
- 요청 구조: `PushAndInboxRequest` (`support/client/notification/push/PushAndInboxRequest.java:10-83`) — 18개 필드, 생성자 검증(`validateUserIds`, `validateNonEmptyString`, `validateNotNull`)
- 지원 Enum:
  - `ServiceCode`: `FUNDING`, `INVEST`, `STARTUP` (`ServiceCode.java:3-7`)
  - `DomainCode` 11종(`DomainCode.java:3-15`): `COUPON_EXPIRED`, `REWARD_OPEN`, `REWARD_NEWS`, `FOLLOW_MAKER_REWARD_OPEN`, `REWARD_END_REMIND`, `BENEFIT_EVENT`, `PAYMENT_SUCCESS`, `PAYMENT_1ST_FAIL`, `PAYMENT_FINAL_FAIL`, `REWARD_DELIVERY_START`, `REWARD_DELIVERY` (배치에서는 `COUPON_EXPIRED` 만 사용)
  - `SenderType` 8종(`SenderType.java:3-12`): `IVT_MAKER`, `RWD_MAKER`, `STR_MAKER`, `SYSTEM`, `USER`, `MASTER`, `ADMIN`, `EXTERNAL_SYSTEM` (배치에서는 `SYSTEM` 만 사용)

### 6-3. AlimTalk (카카오 알림톡)

- 클라이언트: `AlimTalkMessageClient` (`support/client/notification/alimtalk/AlimTalkMessageClient.java`)
- 인증: `Authorization: Bearer <internal-api-token>` (기본 헤더, `AlimTalkMessageClient.java:19-20`)
- API: `POST /api/v2/message/alimtalk`
- 요청: `AlimTalkMessageRequest{tid, payloads: List<AlimTalkMessagePayload>, templateNo, priority, reserved?}` (`AlimTalkMessageRequest.java:13-39`)
- Priority: `FAST`, `NORMAL`, `SLOW` — 배치는 `SLOW`
- 페이로드: `AlimTalkMessagePayload{maps, phoneNumber}` (`AlimTalkMessagePayload.java:10-14`)
- 배치 고정값: `TEMPLATE_NO = 3152`

### 6-4. NormalMail (이메일 시스템)

- 클라이언트: `NormalMailClient` (`support/client/notification/mail/NormalMailClient.java`)
- 인증: `Authorization: Bearer <internal-api-token>` + `wadiz-Language: <languageCode>` 헤더 추가
- API: `POST /api/v3/send`
- 요청: `NormalMailRequest{tid, domainCode, isAd=false, templateNo, mailInfoList}` (`NormalMailRequest.java:11-19`)
- 페이로드: `NormalMailPayload{toEmail, userId, templateData}` (`NormalMailPayload.java:10-14`)
- 배치 고정값: `TEMPLATE_NO = 1429`, `domainCode = "COUPON_EXPIRED"`

### 6-5. BackOffice API (기획전 쿠폰 맵핑)

- 클라이언트: `BackOfficeApiClient` (`support/client/backoffice/BackOfficeApiClient.java`)
- 인증: Bearer
- API: `GET /collection/coupon`
- 응답: `CollectionCouponListResponse` (`support/client/backoffice/CollectionCouponListResponse.java:12-47`) — `list[*].apiCouponList[*].eventCouponList[*]` 중첩 구조. `EventActionType`: `BENEFIT`, `ENTRY`, `RANDOM_BENEFIT`
- **현재 호출되지 않음** — `ProjectCouponSummaryTasklet.getEventCoupons()` 진입점이 주석 처리됨.

### 6-6. 예외 계층

| 예외 | 위치 | 사용처 |
|---|---|---|
| `FundingApiClientException` | `support/client/funding/FundingApiClientException.java` | `FundingApiClient.exchange` — `@SneakyThrows` |
| `NotificationApiClientException` | `support/client/notification/NotificationApiClientException.java` | Push/AlimTalk/NormalMail 공통 — `catch (Exception) → throw new ...` |
| `BackOfficeApiClientException` | `support/client/backoffice/BackOfficeApiClientException.java` | BackOffice — Tasklet 에서 catch 하여 `empty map` 반환 |
| `ApiClientException` | `support/client/ApiClientException.java` | 공통 루트 |

---

## 7. 경계 및 미탐색 영역

### 7-1. 이 문서가 다루지 않은 것

| 영역 | 이유 |
|---|---|
| `CouponDto$ExpectedExpirationResponse` 등 DTO 내부 필드 | 외부 jar `com.wadiz.api.reward:reward-models` (`gradle/wadiz.gradle:2`) 에 위치. 호출부에서 `getOwnerUserId()`, `getCouponName()`, `getCouponNameEn()` 접근자만 관찰 가능. |
| Push Gateway / AlimTalk / Mail 내부 로직 | HTTP endpoint 너머. 템플릿 엔진 / 발송 큐 / 리트라이 정책은 별도 플랫폼 팀(platform.wadizcorp.net). |
| Spring Batch 메타 테이블 스키마 | DDL 파일 없음 — Spring Batch 표준 스키마(`schema-mysql.sql`) 를 가정. |
| Hazelcast / Redis 관련 동작 | application-dev.yml 에 redis/rabbitmq 설정이 있으나 배치 코드 경로상 직접 사용처 미관찰. `application-live.yml:50-51` 에 `hazelcast.config` 설정이 있음 — 런타임 API 쪽 캐시 의존성일 가능성. |
| 스케줄러 | 레포에 `@Scheduled` 전무. OS crontab 또는 k8s CronJob, 혹은 Jenkins 파이프라인 트리거로 추정(`Jenkinsfile-BATCH:163` 주석 "Batch will be triggered by scheduler"). |

### 7-2. 코드 내 주석 처리된 경로(= 실제로는 미사용)

1. `ProjectCouponSummaryTasklet.execute()` 내 기획전 쿠폰 2차 적재 블록 (`ProjectCouponSummaryTasklet.java:40-44`).
2. `project-coupon-summary-mapper.xml:36-58` 의 `UNION ALL` 로 이어지던 COLLECTION 경로.
3. 결과적으로 `BackOfficeApiClient.getCollectionCoupons()`, `ProjectCouponSummaryDao.selectEventCoupon/insertApiIssueEventCoupon` 도 배치에서는 사용되지 않지만 코드와 XML 에 남아 있음.

### 7-3. 관측된 상태 관리 주의점

- `CouponExpirationNotificationWriter.userSkipCount`, `transactionId` 가 `static` — 여러 Job 이 같은 JVM 에 같이 떠 있으면 상호 간섭 가능. 현재 `@ConditionalOnProperty` 로 1 Job / 1 JVM 이므로 실용상 문제는 없으나 구조적 부채.
- `CouponExpirationAlimTalkSender` 의 `LocalDate.now()` / `CouponTransactionSummationTasklet` 의 `LocalDate.now()` 는 모두 JVM 기본 타임존 기준. `application.yml:8` 의 `serverTimezone=Asia/Seoul` 은 JDBC 연결 시간대이고, JVM TZ 는 별도(`System.setProperty`/`TZ` 환경변수로 설정되어 있을 것으로 추정).

### 7-4. 미탐색 확장 포인트

- `reward-batch/src/test/**` 의 테스트 구현체(`CouponExpirationPushSenderTest`, `CouponExpirationAlimTalkSenderTest`, `CouponExpirationNormalMailSenderTest`, `CouponExpirationNotificationJobTest`, `ProjectCouponSummaryJobConfigTest`, `CouponTransactionSummationJobConfigTest`) 는 TDD 시나리오 확인용으로만 스캔. 통합 테스트가 `@Disabled` (`CouponExpirationNotificationJobTest.java:13`) 처리돼 있음.
- `Jenkinsfile-BATCH` 는 배포만 다룸 — **실행 스케줄은 Jenkins job 외부** 에 존재. 실제 cron 표현식은 본 레포에서 관측 불가.

---

## 8. 참조 위치 요약

| 경로 | 라인 | 설명 |
|---|---|---|
| `reward-batch/src/main/java/com/wadiz/api/reward/RewardBatchApplication.java` | 10-26 | 진입점 / 모듈러 모드 |
| `reward-batch/src/main/java/com/wadiz/api/reward/config/RewardBatchDbConfig.java` | 13-30 | 배치 메타 DataSource |
| `reward-batch/src/main/java/com/wadiz/api/reward/support/PagingItemReaderSupport.java` | 8-30 | Reader 공통 베이스 |
| `reward-batch/src/main/resources/application.yml` | 1-10 | `RWD_BATCH_` 프리픽스 + 배치 DB |
| `reward-batch/src/main/java/com/wadiz/api/reward/job/couponexpirationnotification/CouponExpirationNotificationJobConfig.java` | 25-83 | 쿠폰 만료 Job/Step |
| `reward-batch/.../couponexpirationnotification/CouponExpirationNotificationReader.java` | 16-32 | 페이징 Reader |
| `reward-batch/.../couponexpirationnotification/CouponExpirationNotificationWriter.java` | 20-49 | Writer + userSkipCount |
| `reward-batch/.../couponexpirationnotification/CouponExpirationSender.java` | 10-15 | 인터페이스 |
| `reward-batch/.../couponexpirationnotification/CompositeCouponExpirationSender.java` | 16-36 | 3채널 순차 composition |
| `reward-batch/.../couponexpirationnotification/external/CouponExpirationAlimTalkSender.java` | 22-71 | 한국 알림톡 |
| `reward-batch/.../couponexpirationnotification/external/CouponExpirationNormalMailSender.java` | 24-102 | 해외 메일 |
| `reward-batch/.../couponexpirationnotification/external/CouponExpirationPushSender.java` | 19-144 | 해외 앱푸시+인박스 |
| `reward-batch/.../couponexpirationnotification/external/RequestBodyTranslator.java` | 11-73 | en/ja/zh 하드코딩 문구 |
| `reward-batch/.../couponexpirationnotification/external/LocaleConstants.java` | 5-13 | 언어 코드 상수 |
| `reward-batch/.../projectcouponsummary/ProjectCouponSummaryJobConfig.java` | 22-69 | Tasklet + fallback Step |
| `reward-batch/.../projectcouponsummary/ProjectCouponSummaryTasklet.java` | 27-93 | 5단계 swap 파이프라인 (기획전 적재 주석 처리) |
| `reward-batch/.../transactionsummation/CouponTransactionSummationJobConfig.java` | 20-54 | 전일 집계 Job |
| `reward-batch/.../transactionsummation/CouponTransactionSummationTasklet.java` | 19-33 | delete-then-insert (D-1) |
| `reward-batch/.../transactionsummation/CouponTransactionSummationTodayJobConfig.java` | 20-54 | 당일 집계 Job |
| `reward-batch/.../transactionsummation/CouponTransactionSummationTodayTasklet.java` | 19-32 | delete-then-insert (D0) |
| `src/main/java/com/wadiz/api/reward/coupon/infra/dao/CouponQueryDao.java` | 15-20 | Reader 용 Dao |
| `src/main/java/com/wadiz/api/reward/coupon/infra/dao/ProjectCouponSummaryDao.java` | 13-32 | 요약 Job 용 Dao |
| `src/main/java/com/wadiz/api/reward/coupon/infra/dao/CouponTransactionSummationDao.java` | 15-23 | 집계 Job 용 Dao |
| `src/main/resources/mapper/reward/coupon/coupon-query-mapper.xml` | 5-17 | 만료 쿠폰 SELECT |
| `src/main/resources/mapper/reward/coupon/project-coupon-summary-mapper.xml` | 5-123 | 요약 DDL/DML |
| `src/main/resources/mapper/reward/coupon/coupon-transaction-summation-mapper.xml` | 141-180 | 일별 집계 INSERT + DELETE |
| `src/main/java/com/wadiz/api/reward/support/client/funding/FundingApiClient.java` | 18-56 | Funding User API |
| `src/main/java/com/wadiz/api/reward/support/client/funding/UserResponse.java` | 11-47 | 유저 응답 DTO |
| `src/main/java/com/wadiz/api/reward/support/client/notification/push/PushClient.java` | 12-41 | Push HTTP 클라이언트 |
| `src/main/java/com/wadiz/api/reward/support/client/notification/push/PushAndInboxRequest.java` | 10-107 | Push 요청 본문 + 검증 |
| `src/main/java/com/wadiz/api/reward/support/client/notification/push/DomainCode.java` | 3-15 | 도메인 코드 enum |
| `src/main/java/com/wadiz/api/reward/support/client/notification/push/ServiceCode.java` | 3-7 | 서비스 코드 enum |
| `src/main/java/com/wadiz/api/reward/support/client/notification/push/SenderType.java` | 3-12 | 발송자 타입 enum |
| `src/main/java/com/wadiz/api/reward/support/client/notification/alimtalk/AlimTalkMessageClient.java` | 12-33 | AlimTalk 클라이언트 |
| `src/main/java/com/wadiz/api/reward/support/client/notification/alimtalk/AlimTalkMessageRequest.java` | 13-39 | AlimTalk 요청 + Priority |
| `src/main/java/com/wadiz/api/reward/support/client/notification/alimtalk/AlimTalkMessagePayload.java` | 10-14 | AlimTalk 페이로드 |
| `src/main/java/com/wadiz/api/reward/support/client/notification/mail/NormalMailClient.java` | 12-34 | Mail 클라이언트 |
| `src/main/java/com/wadiz/api/reward/support/client/notification/mail/NormalMailRequest.java` | 11-19 | Mail 요청 |
| `src/main/java/com/wadiz/api/reward/support/client/notification/mail/NormalMailPayload.java` | 10-14 | Mail 페이로드 |
| `src/main/java/com/wadiz/api/reward/support/client/backoffice/BackOfficeApiClient.java` | 12-40 | BackOffice 클라이언트 |
| `src/main/java/com/wadiz/api/reward/support/client/backoffice/CollectionCouponListResponse.java` | 12-47 | 응답 DTO + EventActionType |
| `src/main/java/com/wadiz/api/reward/config/WadizProperties.java` | 13-28 | `application.wadiz.*` 바인딩 |
| `Jenkinsfile-BATCH` | 14-20, 123-167 | 배치 jar 빌드 / 환경별 서버 배포 / 크론 언급 |
| `work/features/coupon/expiry-coupon-push-inbox.md` | 1-135 | 해외 유저 푸시 사양 + TDD 히스토리 |
| `work/features/coupon/push-client.md` | 1-138 | Push API 스펙 (환경별 endpoint/token) |
| `work/features/coupon/push-client-request-body.md` | 1-73 | `PushAndInboxRequest` 검증 테스트 스펙 |
| `work/features/coupon/expiry-coupon-mail.md` | 1 | 빈 파일 (미작성) |
