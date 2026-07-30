# com.wadiz.store — 스토어(커머스) 서비스

와디즈 **스토어(커머스)** 백엔드 서비스입니다. org `wadiz-service`. 펀딩이 끝난(또는 비펀딩) 상품을 상시 판매하는 스토어의 주문·결제·상품·프로젝트·정산·배송·만족도를 담당합니다.

> **기록 범위**: `store-api`/`store-batch`/`store-service`/`store-shared` 소스를 직접 관측한 사실만 기록합니다. 사내 아티팩트(`reward-*`, `notification-client`, `wave-crypto` 등) 내부 구현과 Kafka 스키마 원본(Schema Registry), 배치 스케줄 주기(외부 스케줄러)는 저장소 밖이라 확인 불가입니다.

- **엔드포인트 전수**: [`api-endpoints.md`](./api-endpoints.md) — 73개 컨트롤러 × **252 엔드포인트**
- **API 진입점**: `store-api/src/main/java/com/wadiz/store/api/ApiApplication.java`, 서버 포트 **9080**

---

## 최근 변경사항 (2026-07-31 pull 기준)

- **SCOUT-123 — 배송 추적 level 0 유효 처리**: `store-service/misc/.../tracker/TrackerService.java`가 리워드브리지(`rewardBridgeApiClient.getTrackingInfo`) 응답의 tracking `level`이 0이면서 `result="Y"`(송장 등록/집하 전 상태)인 경우를 오류 대신 정상으로 판정해 `TRACKING_LEVEL_MIN`을 반환하도록 변경했습니다. 함께 `store-shared/external/.../rewardbridge/payload/TrackingInfoResponse.java`에 `result` 필드를 추가했고, 기존 level 0 예외 메시지는 `String.format`으로 치환했습니다. 엔드포인트 시그니처 변경은 없습니다.

---

## 1. 기술 스택

| 항목 | 내용 | 근거 |
|---|---|---|
| 빌드 | Gradle 7.6.1 Kotlin DSL 멀티모듈, `buildSrc` convention plugin(`sto.*`) | `gradle/wrapper/...`, `buildSrc/src/main/kotlin/sto.*.gradle.kts` |
| 프레임워크 | **Spring Boot 2.6.4** | `buildSrc/build.gradle.kts:15` |
| 언어 | **Java 8** (애플리케이션 소스). Kotlin은 빌드 스크립트 전용 | `sto.java-common-conventions.gradle.kts:8` |
| Cloud | Spring Cloud 2021.0.1 — Consul discovery + Sleuth | `store-api/build.gradle.kts:26-27` |
| DB | **MySQL 8** (`wadiz_store`), master/slave 데이터소스 분리, log4jdbc 프록시, 커스텀 `MySQL57CustomDialect` | `application.yml:55,86-129` |
| ORM | **JPA + QueryDSL + MyBatis 병용**, Envers(감사) | `sto.persistence-conventions.gradle.kts:5-19` |
| 메시징 | Kafka + **Confluent Avro**(Schema Registry) — consumer 중심 | `store-api/build.gradle.kts:13,28` |
| 캐시/락 | **Hazelcast**(`spring.cache.type: hazelcast`), **Redis**(분산 락·재고·주문 세션) | `application.yml:62-63`, `store-shared/persistence/.../DataRedisConfig.java` |
| 인증 | **OAuth2 Resource Server (JWT, HS256 대칭키)**, STATELESS | `store-api/.../config/WebSecurityConfig.java` |
| 문서화 | Spring REST Docs(`sto.restdocs-conventions`) | `store-api/build.gradle.kts` |
| 기타 | MapStruct, Lombok, Vavr, Apache POI(엑셀), iText(정산 PDF), Zalando Problem, Jasypt(설정 암호화) | `sto.persistence-conventions`, `store-service/settlement` |

사내 아티팩트는 GitHub Packages(`maven.pkg.github.com/wadiz-repo/maven-releases`)에서 가져옵니다: `wave-crypto`, `reward-http-client`, `reward-models`, `notification-client`, `point-client` 등.

## 2. 모듈 구조 (헥사고날 / 포트-어댑터)

`settings.gradle.kts` 기준 4개 상위 모듈 + `buildSrc`.

| 모듈 | 성격 | 역할 |
|---|---|---|
| `store-api` | 실행형 Spring Boot 앱 | REST API. 모든 service·shared 모듈 의존. 진입점 `ApiApplication` |
| `store-batch` | 실행형 앱(웹 없음) | Spring Batch 잡. `reaction` 제외 service 전부 + shared 의존. Mongo·별도 배치 JDBC 사용 |
| `store-service` | 라이브러리 그룹 | 도메인 서비스: `misc / project / order / settlement / satisfaction / reaction`, 각각 `infrastructure` 서브모듈로 구현 분리 |
| `store-shared` | 공용 라이브러리 | `external`(외부 클라이언트), `persistence`(영속·Redis 설정), `test`(테스트 지원). 본체는 Avro/Kafka 스키마 생성 담당 |
| `buildSrc` | 빌드 로직 | convention plugin 6종 정의 |

service 내부 의존: `order` → `misc`·`project`; `satisfaction` → `misc`·`order`·`project`; `settlement` → `order`·`project`·`misc`. 각 `infrastructure`는 상위 service + `store-shared:persistence`를 의존합니다. 도메인/애플리케이션과 구현(infrastructure)을 분리한 헥사고날 구조입니다. 루트 `build.gradle.kts`는 JaCoCo 커버리지 집계 전용입니다.

## 3. 도메인 지도

컨트롤러 상위 패키지는 `com.wadiz.store.api.rest`이며 도메인별 하위 폴더로 구성됩니다. 도메인별 엔드포인트 상세는 [`api-endpoints.md`](./api-endpoints.md) 참조.

| 도메인 | 컨트롤러 | 엔드포인트 | 비고 |
|---|---|---|---|
| 주문/결제 | 9 | 49 | 주문 세션→주문서→결제 승인(나이스페이/와디즈간편/0원), 선물, 분쟁 |
| 상품/재고/카테고리 | 7 | 15 | 판매 상품, 재입고 구독, FMS 재고 동기화 |
| 프로젝트 | 12 | 54 | 공개 조회 / 스튜디오 개설·저장·제출 / 어드민 진행 관리 |
| 정산/수수료/출금 | 12 | 44 | 판매·셀러 정산, 마감·재정산, 수수료율, 나이스페이 지급대행, 주문 철회 |
| 스튜디오/메이커 | 10 | 26 | 입고(FMS), 발송, 사업자·약관·기능정책, 메이커 대시보드 |
| 배송/만족도/리액션 | 10 | 30 | 송장 확인, 와배송, 만족도·답글, 리액션, 배송지 |
| 컬렉션/큐레이션/프로모션/연동 | 13 | 34 | 컬렉션·큐레이션, 할인 프로모션, 첨부, SCM, 외부 카탈로그 피드, Linkprice CPS |
| **합계** | **73** | **252** | |

경로 접두 규약: 공개 `/api/...`, 스튜디오(메이커) `/api/studio/...`, 어드민 `/api/admin/...`, 내부 `/api/internal/...`, 외부 `/api/external/...`.

## 4. 영속 계층

- **JPA**: `@Entity` 약 96개, `JpaRepository` 계열 약 191개. QueryDSL 병행. 예: `store-service/order/.../domain/order/Order.java`.
- **MyBatis**: 매퍼 XML 11개 (`mybatis.mapper-locations: classpath*:mapper/**/*.xml`). 주로 통계/복잡 조회(정산·SCM·집계)에 사용. 예: `store-service/order/infrastructure/.../mapper/order/SalesOrderMapper.xml`.
- **DB**: MySQL `wadiz_store`, master(`192.168.0.162`)/slave(`192.168.0.163`) 분리. 배치는 별도 `wadiz_store_batch` 스키마.

## 5. 메시징·캐시·외부 연동

- **Kafka(consumer)**: `store-api/.../listener/KafkaInboundConsumer.java`에 `@KafkaListener` 5개. **fulfillment(입고/재고) 도메인 이벤트**를 Avro로 소비(`inbound-order-processing-completed`, `inbound-completed`, `inventory-item-stock-changed` 등). Producer 코드는 미관측(확인 불가).
- **Redis**: 분산 락(`RedisLockRegistry`, prefix `wadiz:store:distributed-lock`), 재고 수량(`wadiz:store:inventory:...`), 주문 세션류(`OrderSession`/`OrderSheet`/`ClosedOrderSession`/`LinkpriceAccessSession`, `@RedisHash` 휘발성). 여러 서비스 공유 클러스터. 마이그레이션 기록은 저장소 자체 `docs/redis-migration-guide.md`.
- **외부 서비스 호출**: **RestTemplate 중심**(일부 WebClient), **Feign 미사용**. 클라이언트는 `store-shared/external/.../client/*`: payment, funding, reward, notification(alimtalk/sms/mail/push), point, user, membership, startup, searcher, braze, fulfillment, linkprice, virtualnumber(SafeNumber) 등. 대상 URL·토큰은 `application.yml`의 `external.*`.

## 6. 보안·인증

- `WebSecurityConfig` (`WebSecurityConfigurerAdapter`, SB 2.6 스타일). **STATELESS**, CSRF 비활성.
- **OAuth2 Resource Server(JWT)**: HS256 대칭키(`NimbusJwtDecoder.withSecretKey`), 시크릿 `application.jwt.secret`. 권한 클레임 `rol`, prefix `ROLE_`, 커스텀 `WadizJwtAuthenticationConverter`.
- **URL 인가 규칙**: `/api/internal/**`→`ROLE_SYSTEM`, `/api/linkprice/performances`→ADMIN 또는 허용 IP, `/api/studio|admin|attachments|settlement/**`→인증 필요, 나머지 permitAll.
- **커스텀 메서드 보안(SpEL)**: `@EnableGlobalMethodSecurity` + `WadizMethodSecurityExpressionRoot`. `isAdmin()`, `isMakerByProjectNo()`, `isMakerByCampaignId()`, `isMakerAccessibleOrderBy*()`, `isMakerHandleableOrderBy*()`, `isSupporterByOrderNo()` 등을 `@PreAuthorize`에서 호출. 실제 판정은 도메인별 `*SecurityExpression`에 위임.
- **Impersonation(대리 접근)**: `@Impersonatable` + `ImpersonationInterceptor`.
- 조회 정합성: 스튜디오 계열 다수 컨트롤러에 `@ForceMasterDataSource`(마스터 DB 강제).

## 7. store-batch 배치 잡

`@EnableBatchProcessing`, 외부 스케줄러가 프로세스를 기동해 실행(웹 없음). 주요 잡:

| 잡 | 용도 |
|---|---|
| deliveryTrackingJob / deliveredNotificationJob | 배송 추적 / 배송완료 알림 |
| disputeRequestAlertJob / approveDisputeJob | 분쟁 요청 알림 / 분쟁 승인 |
| orderConfirmationJob | 구매확정 |
| giftAutoOrderCancelJob | 선물 주문 자동 취소 |
| satisfactionBenefitJob | 만족도(리뷰) 혜택 |
| prevMonthReceivableExistingSellerSettlementInsertJob | 전월 미수금 셀러 정산 데이터 생성 |
| inventorySyncJob | 재고 동기화 |
| invoiceVerificationJob | 송장 검증(다단계 스텝) |
| orderQtyReminderNotificationJob | 주문수량 리마인더 알림 |
| virtualPhoneNumberReleaseJob | 가상 전화번호 해제 |
| projectApprovedStatusCheckJob / projectStockStatusCheckJob | 프로젝트 승인상태·재고상태 점검 |
| signatureDiscountPromotionSetJob | 시그니처 할인 프로모션 세팅 |
| automatedCollectionsJob | 자동 컬렉션 수집 |
| makerClubJob | 메이커클럽 |
| expirePurgeJob / cancelShippingPurgeJob | 개인정보 만료·취소배송 정보 파기(Mongo 연계) |

## 8. 배포 (Jenkins)

env × 서비스 × 잡타입 매트릭스로 분리됩니다.

- **API**: `Jenkinsfile-{dev,rc,rc2,live}-API`. 예 `./gradlew clean :store-api:bootJar -x test`, 헬스포트 9080. 공통 `jenkins/api-common.groovy`.
- **BATCH**: `Jenkinsfile-BATCH` 외 env별. jar 복사→`default` 심링크→서비스 재시작, 헬스체크 없음(스케줄러 트리거). 공통 `jenkins/batch-common.groovy`.
- live·rc는 배포 전 수동 승인. GitHub Packages 자격증명(`gpr-user-wadiz-dev`) 주입.

## 9. 확인 불가 / 외부 경계

- Kafka **Producer** 발행 코드(consumer만 관측), Avro 스키마 원본(Schema Registry 서버).
- 배치 잡의 스케줄 주기(cron): 저장소 내 정의 미발견, 외부 스케줄러.
- 사내 아티팩트(`wave-crypto`, `reward-*`, `notification-client`, `point-client`) 내부 구현.
- 도메인별 입력 DTO / Service / SQL 상세는 미작성(향후 `api-details/*.md` 확장 대상).
