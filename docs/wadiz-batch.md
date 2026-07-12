# wadiz-batch — 배치·감사 서버군 (5 repo)

> `wadiz-batch` org 소속 5개 Spring Boot 배치·감사 서비스. 모두 **Java 8 / Gradle**, Boot 버전은 2.1 ~ 2.7 범위(각 repo 마다 다름). 결제·스타트업·통계·메인·감사(audit) 도메인별로 배치 잡을 스케줄·수행한다.

각 repo 는 표면 분석 단계로, 잡 목록·데이터소스·의존성 관점의 개요만 기록한다. 심층 분석은 향후 개별 폴더로 승격(`docs/<repo>/`).

## Repo 요약표

| Repo | Boot | 잡·태스크 규모 | 데이터 저장소 | 특기 |
|---|---|---|---|---|
| `com.wadiz.batch.payment` | 2.4.3 | 14 Job / 4 Tasklet | MyBatis (MySQL) | 결제 배치 (환불·취소·재시도) |
| `com.wadiz.startup.batch` | 2.1.1 | 2 Job / 4 Tasklet | JPA + MyBatis · dual DS (`wadiz`, `wadizUserFollow`) | 스타트업/투자 정산 |
| `com.wadiz.wave.statistics` | (ext var) | 17 Job / 14 Tasklet / 1 `@Scheduled` | JPA + MongoDB + MyBatis | 통계 집계·랭킹. **멀티모듈** |
| `main2-batch` | 2.7.2 | 5 Job / 1 `@Scheduled` | JPA · dual DS (`wadizdb`, `wadizstore`) | 메인 화면용 배치 (WebFlux + Quartz) |
| `com.wadiz.wave.audit` | 2.7.10 | (배치 아님, RabbitMQ Receiver) | RabbitMQ + MongoDB + 파일 | 앱별 audit 로그 파일 적재 |

---

## 1. `com.wadiz.batch.payment` — 결제 배치

**메인 클래스**: `com/wadiz/batch/payment/PaymentApplication.java`

**대표 Job** (`src/main/java/com/wadiz/batch/payment/**/JobConfig.java`):

- `CancelShippingPurgeJobConfig` — 취소 배송 정리
- `ExpirePurgeJobConfig` — 만료 데이터 정리
- `PaymentJob` — 결제 처리 (config + mapper 조합)
- `PaymentIndemandJobConfig` / `PaymentIndemandSpecificJobConfig` — 결제 재청구
- `NPaymentCancelFailRetryJobConfig` — 나이스페이 결제 취소 실패 재시도
- `PaymentJobMakerNotificationConfig` — 메이커 알림

**의존성**:
- Spring Boot 2.4.3
- Spring Cloud (`spring-cloud-dependencies`)
- MyBatis Spring Boot Starter 2.1.4
- JIB (`com.google.cloud.tools.jib` 3.3.1) — Docker 이미지 빌드

**Group**: `com.wadiz.batch` / **Java 8**

## 2. `com.wadiz.startup.batch` — 스타트업(투자) 배치

**메인 클래스**: `com/wadiz/batch/StartupBatchApplication.java`

**Job**: `BatchJobConfiguration.java` + `JobUuidListener.java` (2 Job, 4 Tasklet)

**데이터소스 (2개)**:
- `repository/wadiz/` — 메인 스타트업 DB
- `repository/wadizUserFollow/` — 팔로우 DB (`wave.user` 의 `wadiz_wave_follow` 와 연결 추정)

**의존성**:
- Spring Boot 2.1.1 (가장 오래된 버전, 업그레이드 대상 후보)
- Java 8, JPA + MyBatis (하이브리드)
- MySQL Connector, Lombok

## 3. `com.wadiz.wave.statistics` — 통계 집계 (멀티모듈)

**메인 클래스**: `com/wadiz/wave/statistics/StatisticsApplication.java`

**모듈 구조** (`settings.gradle`):
- `statistics-load-campaign` — 캠페인 로드 서비스
- `statistics-query-campaign` — 캠페인 쿼리 API
- `statistics-model` — 공용 모델

**대표 Job** (17개, `src/main/java/.../job/config/*JobConfig.java`):
- `StoreOrderHistoryJobConfig` — 스토어 주문 이력
- `PreorderRankingJobConfig` — 프리오더 랭킹
- `CampaignComingSoonRankingJobConfig`, `CampaignComingSoonEarlyBirdJobConfig` — 오픈예정
- `CampaignStatisticsJobConfig`, `CampaignRankingJobConfig` — 캠페인 통계·랭킹
- `UserActivityDailyJobConfig`, `UserHistoryJobConfig` — 유저 활동·히스토리
- `CollectionJobConfig` — 컬렉션 집계
- 외 8종

**진입점 컨트롤러**: `JobExecuteController.java` — 잡 수동 실행 API 로 추정

**저장소**: `docker/mongo/` 폴더가 존재 — MongoDB 를 통계 저장소로 사용

**의존성**:
- Spring Batch, Spring Data JPA, Spring Cloud
- Gson 2.9.0
- 버전 관리: `gradle.properties` 또는 shared configuration

## 4. `main2-batch` — 메인 화면 배치 (Quartz)

**패키지**: `kr.wadiz.batch.quartz`  (org.wadiz 가 아니라 kr.wadiz)
**메인 클래스**: `Main2BatchApplication.java`

**Job** (5개, `src/main/java/kr/wadiz/batch/quartz/**/`):
- `CollectionJob`, `CurationJob` — 컬렉션·큐레이션
- `AdJob` — 광고
- `StoreJob`, `CampaignJob` — 스토어·캠페인

**데이터소스 (2개)**:
- `repository/wadizdb/`
- `repository/wadizstore/`

**특징**:
- **Spring Boot 2.7.2** (5개 배치 중 최신)
- **WebFlux** starter 포함 (관리 API 비동기)
- Quartz 스타일 배치 (`kr.wadiz.batch.quartz` 패키지명)
- `spring-boot-starter-data-jpa` (MongoDB reactive 는 주석 처리됨)

## 5. `com.wadiz.wave.audit` — 앱별 감사 로그 수집기

**메인 클래스**: `com/wadiz/wave/AuditApplication.java`

**동작 방식** (README 발췌):
- `com.wadiz.wave.audit-client` (별도 클라이언트 라이브러리, 본 repo 밖) 의 `AuditSender` 가 RabbitMQ 에 audit 정보를 적재
- 본 서비스가 `@RabbitListener` 로 수신 (`audit/adapter/event/receiver/AuditReceiver.java`)
- `AuditWriter` 구현체가 파일로 적재 (`persistence/AuditFileWriter.java`)

**등록 앱** (`ApplicationName.java`, 8개):
```java
enum ApplicationName { WEB, ADMIN, ANALYTICS, NOTIFICATION, POINT, GATEWAY, PAY, USER }
```

**신규 앱 추가 절차** (README):
1. `ApplicationName` enum 추가
2. `ReceiverConfig` 에 Queue/Binding 추가
3. `AuditReceiver` 에 `@RabbitListener` 추가
4. `audit-client` 리포에도 동일 enum 추가

**Writer 확장**:
- `AuditWriter` 인터페이스 구현
- `WriterConfig.auditWriters` 에 등록

**의존성**:
- Spring Boot 2.7.10
- Spring AMQP (RabbitMQ)
- Spring Data MongoDB
- Actuator, Validation, Web Services

---

## 인프라 관점 종합

### 배치 스케줄러 분포
- **@Scheduled 사용**: `com.wadiz.wave.statistics` (1건), `main2-batch` (1건)
- **Quartz 스타일 명명**: `main2-batch` (`kr.wadiz.batch.quartz`)
- **외부 스케줄러(Kubernetes CronJob·Airflow 등) 가정**: 명시적 `@Scheduled` 없이 잡 정의만 있는 나머지 3개는 외부에서 실행되는 것으로 추정 (본 repo 내에서는 관측 불가)

### 데이터소스 매트릭스
| Repo | MySQL | MongoDB | JPA | MyBatis |
|---|---|---|---|---|
| batch.payment | ✓ | | | ✓ |
| startup.batch | ✓ (dual) | | ✓ | ✓ |
| wave.statistics | ✓ | ✓ | ✓ | ✓ (추정) |
| main2-batch | ✓ (dual) | | ✓ | |
| wave.audit | | ✓ | | |

### 다른 시스템과의 연결
- `com.wadiz.batch.payment` → **nicepay-api** (NPaymentCancelFailRetryJobConfig 이름으로 유추)
- `com.wadiz.startup.batch/repository/wadizUserFollow/` → **`wave.user`** MySQL 스키마 (`wadiz_wave_follow`)
- `com.wadiz.wave.audit` ← 8개 앱(WEB, ADMIN, ANALYTICS, NOTIFICATION, POINT, GATEWAY, PAY, USER)의 audit 이벤트를 RabbitMQ 로 수신

### 관측 한계
- 각 잡의 실제 실행 스케줄 (cron, Kubernetes CronJob 매니페스트, Jenkins 스케줄) 은 본 repo 에 없음
- audit-client 라이브러리 코드는 별도 repo (미클론)
- `com.wadiz.wave.statistics` 의 3개 서브모듈 상세는 심층 분석 필요
