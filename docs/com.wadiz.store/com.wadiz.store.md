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

> 웹 게이트웨이는 `/web/apip/store/**` 를 store-api 의 `/api/**` 로 프록시합니다. 예: `GET /web/apip/store/studio/projects/213` → `GET /api/studio/projects/213` (cdev 실측).

### 3.1 스토어 프로젝트 생명주기 (개설 → 오픈)

상태 기계는 `store-service/project/.../domain/project/ProjectStatus.java` 에 정의되며, 각 상태가 허용하는 `StatusEvent` 만 받습니다.

```
WRITING ─SUBMIT→ WAITING_FOR_SCREENING ─BEGINNING_SCREENING→ SCREENING
        ─APPROVE→ WAITING_FOR_SALE ─OPEN→ ON_SALE ─END_OF_SALE→ END_OF_SALE
```

| 전이 | 주체 | 엔드포인트 / 위치 |
|---|---|---|
| 개설(펀딩 기반) | 메이커·어드민 | `POST /api/studio/projects/set-up?campaignId={본펀딩}` — **본펀딩 campaignId 가 입구** |
| 개설(비펀딩) | 어드민 | `POST /api/admin/projects/set-up-without-funding` |
| 개설(복사) | 어드민 | `POST /api/admin/projects/set-up-via-copy` — 같은 환경 내 프로젝트만, 최대 10건 |
| 저장 | 메이커·어드민 | `PUT /api/studio/projects/{no}/save[-temporary][-by-admin]` |
| `SUBMIT` | 메이커·어드민 | `POST /api/studio/projects/{no}/submit[-by-admin]` — **본문 필수**, `save` 와 동일 본문 + 전체 검증(`SaveGroup`) |
| `BEGINNING_SCREENING`·`APPROVE` | 어드민 | `PUT /api/admin/project-managements/{no}/events/{eventType}` (`ProgressEventType`) |
| `OPEN` | 메이커·어드민 | `POST /api/studio/projects/{no}/open` — `TERMS_OF_SERVICE` 동의 행 필요 |

`ProgressEventType` 은 `BEGINNING_SCREENING`, `APPROVE`, `CANCEL_APPROVAL`, `END_OF_SALE`, `APPROVE_REOPEN`, `CANCEL_REOPEN_APPROVAL` 6개뿐입니다. **`SUBMIT`·`OPEN` 은 이 경로로 못 바꿉니다.**

> **`APPROVE` 는 곧바로 `WAITING_FOR_SALE` 로 갑니다.** `ProjectStatus.APPROVED` 상태와 `projectApprovedStatusCheckJob` 배치(`StatusEvent.READY_FOR_SALE`)가 코드에 존재하지만, 정상 경로에서는 승인 시점에 바로 오픈 대기로 넘어가 **배치를 기다릴 필요가 없습니다**(2026-08-14 cdev 실측: `SCREENING` → `APPROVE` → `WAITING_FOR_SALE`). 배치는 승인 후 재고가 뒤늦게 채워지는 경우를 위한 보정 경로로 보입니다.

**대표 상품(signature)은 표시용이 아니라 오픈 게이트입니다.** 승인 계열 판정이 대표 상품의 판매가능 재고를 조건으로 겁니다 (`store-batch/.../projectapprovedstatuscheck/ProjectApprovedStatusCheckJobConfig.java:137-150`).

```java
productRepository.findAllSalesUnitProductWithInventoryItem(... .isSignature(true).build());
final boolean isReadyForSale = results.stream()
    .anyMatch(e -> e.isOversellable() || (e.getValidStockQty() != null && e.getValidStockQty() > 0));
```

대표 상품이 없으면 가격 집계도 0이 됩니다 (`ProductAggregation.java:66` — `Optional.ofNullable(signature).map(Product::getPrice).orElse(0L)`). 증상은 상세 상단 가격 `0원`, `product_aggregation.lowest_price` 는 정상인데 `price_of_signature` 만 0.

#### 저장(`save`) 계열의 성질

- **전체 덮어쓰기입니다.** 일부 항목만 보내면 나머지가 지워집니다. 기존 프로젝트를 고칠 때는 `GET /api/studio/projects/{no}` 와 `GET .../products` 로 현재 상태를 읽어 그대로 다시 실어야 합니다.
- **판매중(`ON_SALE`)에는 잠깁니다** — `400 "invalid change project. Project status is ON_SALE"`. 판매중 전용 `save-restricted` 는 상품·배송·교환반품·고시만 담고 **사업자 정보 항목이 없으며**(`StudioSaveRestrictedProjectRequest`) 메이커 본인만 호출할 수 있습니다. 따라서 **사업자·정산 정보는 오픈 전에 확정해야 합니다.**
- `setting.productDisplayType` 이 `IMAGE`(이미지형)면 **모든 상품에 이미지가 있어야** 합니다(`400 "ProductDisplayType이 IMAGE일 경우 Image는 필수입니다."`). 값은 `IMAGE` / `LIST` 두 개뿐입니다.
- 조회 응답의 `categories[].isPrimary` 는 문자열 `"true"` 로 내려오지만 요청은 Boolean 을 받습니다.

#### 3.1.1 ★ 대표자 휴대폰은 본인인증을 통과한 번호만 저장됩니다

`save` 계열에서 대표자 휴대폰이 바뀌면, 그 **프로젝트 번호로 수행된 본인인증 기록**과 대조합니다.

`store-service/project/.../application/project/SaveProjectService.java:175-185`
```java
if (maker.isChangedRepresentativePhoneNumber(changed)) {
  final PersonalVerification verification = personalVerificationService.getStoreRepresentativeVerification(projectNo);
  if (verification == null || !verification.getMobileNumber().equals(changed)) {
    throw new InvalidRepresentativePhoneNumberException(projectNo, changed);
  }
}
```

- 인증 기록은 `wadiz_db.PersonalVerificationResult (PurposeType='STORE_REPRESENTATIVE', TargetKey={projectNo})` 이며 `MobileNumber` 는 **KMS 암호화**입니다. 조회용 내부 API(`/api/internal/personal-verify/{purposeType}/key/{targetKey}`, `com.wadiz.api.funding`)는 외부에서 **403** 입니다.
- **프로젝트마다 1회 필요합니다.** 개설(`set-up-*`)할 때마다 새 `maker` 행이 만들어져 대표자 휴대폰이 비어 있으므로, 같은 번호라도 다른 프로젝트의 인증은 쓸 수 없습니다(실측 확인).
- 인증 수행 위치 — 스토어 메이커 스튜디오의 **"대표자∙정산 정보"** 화면입니다.
  ```
  {webHost}/studio/store/{projectNo}/project/business
  {webHost}/web/personal-verification/mobile/init?purposeType=STORE_REPRESENTATIVE&targetKey={projectNo}&callbackUrl=/web/personal-verification/endpoint/store-representative
  ```
  375×667 팝업으로 나이스(NICE) 휴대폰 본인인증이 뜹니다 (`wadiz-frontend/studio/store/src/pages/project/components/business/MobileVerificationField.tsx:37`). 콜백은 `com.wadiz.web` 의 `PersonalVerificationEndpointController.saveStoreRepresentativeMobileNumber` 가 받습니다.
- ⚠️ 미인증 상태로 번호를 보내면 이 예외에 핸들러가 없어 **`message: null` 인 500** 으로 보입니다. 500 이 나면 이 항목을 먼저 의심하세요.

### 3.2 스토어 메이커 프로필은 ES 색인에 의존합니다

스토어 상세의 메이커 프로필 링크는 DB가 아니라 **Elasticsearch 색인 `fn-store-active`** 를 거쳐 해석됩니다. 조회 주체는 `com.wadiz.api.startup` 입니다.

```
스토어 상세 → GET /web/maker/STORE/{projectNo}          (com.wadiz.web StartupMakerApiController)
            → startup: MakerServiceImpl.findCompanyByStoreProjectNo(projectNo)
            → ES fn-store-active 문서의 searchCorpNo → Company 조회 → corpNo 반환
```

- 색인 문서 모델: `com.wadiz.api.startup/.../domain/maker/model/Store.java` — `@Document(indexName = "fn-store-active")`, 필드 `corpNo`/`searchCorpNo`/`businessRegNumber`(= `original_maker.business_registration_number`).
- **`searchCorpNo` 는 원메이커 사업자등록번호로 `wadiz_db.Corporation` 을 찾아 채워집니다.** 실존하지 않는 번호면 비어 있는 채로 색인됩니다.
- 프론트는 `corpNo` 가 없으면 **빈 `href`** 를 그려, 클릭 시 현재 페이지(스토어 상세)로 되돌아옵니다 (`wadiz-frontend/.../DetailInfoFooter/MakerInfo/MakerInfo.tsx:54,91`). 콘솔 오류가 없어 발견이 늦습니다.

**응답 형태로 원인을 가릅니다** (`MakerApiController.java:79-81` 에 try/catch 가 없어 예외가 그대로 전파되기 때문).

| `GET /web/maker/STORE/{no}` 응답 | 의미 |
|---|---|
| `data` 에 `corpNo` 있음 | 정상 |
| `data: null` | 색인 문서는 **있고**, 회사 매칭만 실패 (`MakerServiceImpl.java:502-505` 의 `return null`) |
| `data: {}` 빈 객체 | 색인 문서 **없음** (`NotFoundException` → 웹 계층 catch) |

색인기는 별도 저장소(외부 indexer)에 있지만 **DB 변경을 감지합니다.** 2026-08-14 cdev 실측: `original_maker.business_registration_number` 한 컬럼만 바꾸고(09:39:44) `project` 는 건드리지 않았는데 **약 2분 뒤(09:41:41) 재색인**되어 `corpNo` 가 채워졌습니다. 색인 대상은 판매중(active) 프로젝트이므로 `WRITING` 상태에서는 문서가 없습니다.

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
| projectApprovedStatusCheckJob / projectStockStatusCheckJob | 프로젝트 승인상태·재고상태 점검. 전자는 대표상품 재고가 있는 승인건을 `READY_FOR_SALE` 로 전이시키는 보정 경로입니다 — 정상 경로에서는 `APPROVE` 가 이미 `WAITING_FOR_SALE` 로 보내므로 개설 자동화에서 이 배치를 기다릴 필요는 없습니다([§3.1](#31-스토어-프로젝트-생명주기-개설--오픈)) |
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
