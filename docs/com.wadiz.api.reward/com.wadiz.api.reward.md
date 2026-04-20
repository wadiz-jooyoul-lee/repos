# com.wadiz.api.reward 분석 문서

## 개요
- Wadiz의 **리워드(Reward) 도메인** API 서버. 펀딩 참여자에게 제공되는 "쿠폰(Coupon) 발행/지급/사용", "리워드 컬렉션(기획전 묶음)", "리워드 만족도 평가(Satisfaction)", "리워드 메모"를 담당한다.
- org `com.wadiz.api.reward`, Java package base `com.wadiz.api.reward.*`. Gradle 멀티 모듈(`reward-api`, `reward-batch`, `reward-test`) 구조이며 본 문서는 API 서버(포트 **9050**)를 중심으로 기술한다.
- 주요 사용자: Wadiz 웹/앱 사용자(쿠폰 다운/사용), Wadiz 메이커(메이커부담 쿠폰 발행·만족도 응답), 백오피스/배치(기획전·집계).

## 기술 스택
- 언어/버전: **Java 1.8**, Spring Boot **2.6.7**, Spring Cloud **2021.0.1** (Consul discovery).
- 빌드: Gradle 멀티 프로젝트 (`build.gradle`, `settings.gradle`, `gradle/*.gradle` 모듈별 분리).
- DB: **MySQL** (hikari, master/slave 2-datasource: `wadiz_reward` 기본, `wadiz_db` 보조). 스키마 관리는 `hbm2ddl.auto: validate`.
- ORM: **Spring Data JPA + Hibernate (Envers로 감사 테이블 `_Aud` 자동 생성)** + **MyBatis 2.2.2** (집계/복잡 조회 전용).
- 캐시/클러스터: **Hazelcast** (`hazelcast-spring`, classpath:hazelcast/hazelcast-default.yaml), Redis Cluster(`spring-boot-starter-data-redis`, 192.168.1.240-242:6001-3).
- 메시징: **RabbitMQ** (`spring-boot-starter-amqp`) — `RabbitMqConfig`에서 Jackson2Json 컨버터·ConnectionFactory·RabbitTemplate·ListenerFactory 구성. 실제 Producer/Consumer 호출은 본 레포에선 미탐지(단순 인프라만 준비).
- 기타: modelmapper 2.4.5, joda-time, kryo, commons-collections4, Lombok. API 문서 **springdoc-openapi 1.6.8**, Micrometer+Prometheus.
- 내부 API 토큰 기반 호출 클라이언트: **funding / backoffice / alim-talk / normal-mail / push** (`support/client/**`, `InternalAuthorizationInterceptor` 적용).
- 배포: Jenkinsfile-API (API), Jenkinsfile-BATCH (배치). ExecutableJar + `/etc/init.d` 심볼릭 링크 방식.

## 아키텍처
- README에 명시된 **Layered DDD 스타일** 규약:
  - `presentation` (Controllers, `reward-api/.../rest/**`)
  - `application` (트랜잭션 흐름 제어 Service)
  - `domain` (Aggregate, `domain.service`에 stateless 도메인 서비스)
  - `query` (조회 전용)
  - `infra.repository` (CUD), `infra.dao` (조회, MyBatis/JDBC)
- 트랜잭션: Multiple DataSource 환경. `wadiz_reward` = 기본 Tx Manager, `wadiz_db` 사용 시 `@WadizTx` 또는 `@Transactional(wadizTransactionManager)` 사용.
- 모듈 패키지 트리 (루트 src, domain별 일관 구조):
```
com.wadiz.api.reward
├── config/                            # Spring 구성 (RabbitMqConfig 등)
├── coupon/                            # [쿠폰] 핵심 도메인
│   ├── application/  (CouponService, CouponRedeem/Use/Refund/Withdraw/TemplateService, IssueService, IssueSummation, TransactionSummation, ProjectCouponSummaryService)
│   ├── domain/       (Coupon, CouponTemplate, CouponIssue, CouponCode, CouponTransaction, CouponTemplateLanguage, CouponTransactionSummation, CouponIssueSummation, ProjectCouponSummary, TargetConditionMapping, CouponIssuePurposeType, service/CouponMaker·CouponTransactionBuilder)
│   ├── converter/ validator/ exception/
│   └── infra/        (repository/*, dao/*, dao/external/MakerCouponDao, dto/external/*, repository/specification/*)
├── collection/                         # [리워드 컬렉션] 기획전 묶음
├── satisfaction/                       # [만족도 평가] Satisfaction + Reply + Score + Benefit + Image
├── memo/                               # [메모] Campaign별 카테고리 메모
└── support/                            # 공통 (datasource, cache, hazelcast, hibernate, domain, client/*)
```
- 컨트롤러는 별도 모듈 `reward-api/src/main/java/com/wadiz/api/reward/rest/**`에 두고, Service를 호출한다 (컨트롤러와 서비스가 서로 다른 Gradle 서브모듈).

## API 엔드포인트 목록
17개 컨트롤러. 모두 prefix `/api/v1/rewards/...`.

| Method | Path | Controller.method | 용도 |
|--------|------|-------------------|------|
| GET | /api/v1/rewards/collections | CollectionController.getAll | 컬렉션 목록 |
| GET | /api/v1/rewards/collections/{collectionNo} | CollectionController.get | 컬렉션 상세 |
| GET | /api/v1/rewards/collections/keywords/{keyword} | CollectionController.get(String) | 키워드로 컬렉션 조회 |
| GET | /api/v1/rewards/collections/campaigns/{campaignId} | CollectionController.getAllByCampaignId | 캠페인에 속한 컬렉션들 |
| POST | /api/v1/rewards/collections | CollectionController.create | 컬렉션 등록 |
| PUT | /api/v1/rewards/collections/{collectionNo} | CollectionController.modify | 컬렉션 수정 |
| GET | /api/v1/rewards/collections/{collectionNo}/campaigns | CollectionMappingController.getAll | 컬렉션-캠페인 매핑 조회 |
| GET | /api/v1/rewards/collections/keywords/{keyword}/campaigns | CollectionMappingController.getAllByKeyword | 키워드 컬렉션-캠페인 매핑 |
| POST | /api/v1/rewards/collections/{collectionNo}/campaigns | CollectionMappingController.add | 매핑 등록 |
| POST | /api/v1/rewards/collections/{collectionNo}/campaigns/bulk | CollectionMappingController.bulk | 매핑 Bulk 등록 |
| DELETE | /api/v1/rewards/collections/{collectionNo}/campaigns/{campaignNo} | CollectionMappingController.remove | 매핑 제거 |
| DELETE | /api/v1/rewards/collections/{collectionNo}/campaigns/bulk | CollectionMappingController.bulkRemove | 매핑 Bulk 제거 |
| GET | /api/v1/rewards/coupons | CouponController.getAll | 쿠폰 목록 |
| GET | /api/v1/rewards/coupons/owners/{userId} | CouponController.getAll(user) | 특정 사용자 쿠폰 목록 |
| GET | /api/v1/rewards/coupons/owners/{userId}/qty | CouponController.getQty | 사용자 쿠폰 건수 |
| GET | /api/v1/rewards/coupons/{couponKey} | CouponController.get | 쿠폰 상세 |
| GET | /api/v1/rewards/coupons/{couponKey}/discount-amount | CouponController.getDiscountAmountByCouponKey | 할인 금액 계산 |
| GET | /api/v1/rewards/coupons/expected-expiration | CouponController.getAllExpectedExpirationCouponsGroupByUser | 만료 예정 쿠폰 (User 그룹) |
| GET | /api/v1/rewards/coupons/queries/expected-expiration | CouponQueryController.getAllExpectedExpirationCouponsGroupByUser | @Deprecated 만료 예정 (동일) |
| POST | /api/v1/rewards/coupons/issues | CouponIssueController.create | 쿠폰 발행 생성 |
| GET | /api/v1/rewards/coupons/issues | CouponIssueController.getAll | 발행 목록 |
| GET | /api/v1/rewards/coupons/issues/{issueKey} | CouponIssueController.getOne | 발행 상세 |
| GET | /api/v1/rewards/coupons/issues/{issueKey}/codes | CouponIssueController.getCodes | 쿠폰 코드 목록 |
| GET | /api/v1/rewards/coupons/issues/purpose-types | CouponIssueController.getIssuePurposeTypes | @Deprecated 발행 목적 유형 |
| GET | /api/v1/rewards/coupons/templates/{templateNo} | CouponTemplateController.get | 템플릿 상세 |
| GET | /api/v1/rewards/coupons/templates | CouponTemplateController.getAll | 템플릿 목록 |
| GET | /api/v1/rewards/coupons/templates/qty | CouponTemplateController.getQty | 템플릿 건수 |
| POST | /api/v1/rewards/coupons/templates | CouponTemplateController.create | 템플릿 생성 |
| PUT | /api/v1/rewards/coupons/templates/{templateNo} | CouponTemplateController.modify | 템플릿 수정 |
| GET | /api/v1/rewards/coupons/templates/{templateNo}/coupons | CouponTemplateController.getCoupons | 템플릿별 쿠폰 목록 |
| GET | /api/v1/rewards/coupons/templates/{templateNo}/coupons/qty | CouponTemplateController.getCouponQty | 템플릿별 쿠폰 건수 |
| GET | /api/v1/rewards/coupons/transactions/{transactionKey} | CouponTransactionController.get | 거래 상세 |
| POST | /api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/coupon-code | CouponTransactionController.redeemByCouponCode | coupon-code로 등록(redeem) |
| POST | /api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/{download\|direct\|api} | CouponTransactionController.redeemByIssue | 발행키로 쿠폰 등록 |
| POST | /api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/{download\|direct\|api}/bulk | CouponTransactionController.redeemByIssueList | Bulk 등록 by IssueKeys |
| POST | /api/v1/rewards/coupons/transactions/users/types/redeem/issue-types/{direct\|api}/bulk | CouponTransactionController.bulkRedeemByIssue | Bulk 등록 by userIds |
| POST | /api/v1/rewards/coupons/transactions/users/{userId}/types/withdraw | CouponTransactionController.withdraw | 쿠폰 회수 |
| POST | /api/v1/rewards/coupons/transactions/users/{userId}/types/use | CouponTransactionController.use | 쿠폰 사용 |
| POST | /api/v1/rewards/coupons/transactions/users/{userId}/types/refund | CouponTransactionController.refund | 쿠폰 반환 |
| DELETE | /api/v1/rewards/coupons/transactions/{transactionKey} | CouponTransactionController.cancel | 거래 취소 |
| GET | /api/v1/rewards/coupons/summations/templates | CouponSummationController.getAll | 템플릿별 집계 목록 |
| GET | /api/v1/rewards/coupons/summations/templates/{templateNo} | CouponSummationController.get | 템플릿별 집계 단건 |
| GET | /api/v1/rewards/coupons/summations/issues/{issueKey} | CouponSummationController.getByIssue | 발행별 집계 |
| GET | /api/v1/rewards/coupons/issue-summation | CouponIssueSummationController.getAllByTemplateNos | 템플릿번호들로 발행 집계 |
| GET | /api/v1/rewards/coupons/transaction-summation | CouponTransactionSummationController.getSummationQuery | 거래 집계 |
| GET | /api/v1/rewards/coupons/projects | ProjectCouponSummaryController.getProjectCouponList | 프로젝트 쿠폰 목록 |
| GET | /api/v1/rewards/coupons/projects/{projectNo} | ProjectCouponSummaryController.getProjectOnlyCouponList | 프로젝트 전용 쿠폰 |
| POST | /api/v1/rewards/coupons/makers/{makerUserId}/templates | MakerCouponTemplateController.create | 메이커 부담 쿠폰 템플릿 생성 |
| PUT | /api/v1/rewards/coupons/makers/{makerUserId}/templates/{templateNo} | MakerCouponTemplateController.modify | 메이커 부담 템플릿 수정 |
| GET | /api/v1/rewards/coupons/makers/{makerUserId}/templates | MakerCouponTemplateController.getAll | 메이커 부담 템플릿 목록 + 집계 |
| GET | /api/v1/rewards/coupons/makers/{makerUserId}/templates/{templateNo} | MakerCouponTemplateController.get | 메이커 부담 템플릿 상세 |
| GET | /api/v1/rewards/coupons/makers/braze/project | MakerCouponController.getBoostCouponByProjectId | 프로젝트 부스팅 쿠폰(Braze) |
| POST | /api/v1/rewards/satisfactions | SatisfactionController.create | 만족도 등록 |
| PUT | /api/v1/rewards/satisfactions/{satisfactionNo} | SatisfactionController.modify | 만족도 수정 |
| PUT | /api/v1/rewards/satisfactions/{satisfactionNo}/is-hidden | SatisfactionController.modifyHidden | 숨김 상태 변경 |
| PUT | /api/v1/rewards/satisfactions/{satisfactionNo}/benefit | SatisfactionController.modifyBenefit | 혜택 지급 상태 변경 |
| DELETE | /api/v1/rewards/satisfactions/{satisfactionNo} | SatisfactionController.modify(delete) | 만족도 삭제 |
| GET | /api/v1/rewards/satisfactions/{satisfactionNo} | SatisfactionController.get | 만족도 상세 |
| GET | /api/v1/rewards/satisfactions/campaigns/{campaignId}/users/{userId} | SatisfactionController.getByCampaignIdAndUserId | 캠페인·사용자별 조회 |
| GET | /api/v1/rewards/satisfactions | SatisfactionController.getAll | 만족도 목록 |
| GET | /api/v1/rewards/satisfactions/qty | SatisfactionController.getQty | 만족도 건수 |
| PUT | /api/v1/rewards/satisfactions | SatisfactionController.getAllForBenefitPaid | 목록 조회 + 혜택 지급 |
| GET | /api/v1/rewards/satisfactions/replies/{satisfactionReplyNo} | SatisfactionController.getReply | 댓글 단건 |
| POST | /api/v1/rewards/satisfactions/{satisfactionNo}/replies | SatisfactionController.createReply | 댓글 등록 |
| PUT | /api/v1/rewards/satisfactions/replies/{satisfactionReplyNo} | SatisfactionController.modifyReply | 댓글 수정 |
| DELETE | /api/v1/rewards/satisfactions/replies/{satisfactionReplyNo} | SatisfactionController.deleteReply | 댓글 삭제 |
| GET | /api/v1/rewards/satisfactions/campaigns/bulk | SatisfactionController.getSatisfactionCampaignIdsByUserId | 사용자별 만족도 캠페인ID Bulk |
| POST | /api/v1/rewards/satisfactions/projects/search | SatisfactionController.search | 검색 조건 기반 조회 |
| GET | /api/v1/rewards/satisfactions/aggregates/campaigns/{campaignId} | SatisfactionAggregateController.aggregate | 캠페인 만족도 집계 |
| POST | /api/v1/rewards/satisfactions/aggregates/campaigns/bulk | SatisfactionAggregateController.aggregates | 다중 캠페인 Aggregate |
| GET | /api/v1/rewards/memos/campaigns/{campaignId}/memo-categories/{memoCategory} | MemoController.get | 메모 상세 |
| POST | /api/v1/rewards/memos | MemoController.save | 메모 등록 |
| PUT | /api/v1/rewards/memos/{memoNo} | MemoController.modify | 메모 수정 |

## 주요 API 상세 분석

### 1) POST /api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/coupon-code
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponTransactionController.java:48`
- 입력 DTO `CouponTransactionDto.RedeemByCouponCode`: `couponCode`(대문자화 후 조회), `ownerUserId`.
- 처리 로직 (`coupon/application/CouponRedeemService.redeemByCouponCode`, `src/main/java/com/wadiz/api/reward/coupon/application/CouponRedeemService.java:40`):
  - path userId ≠ request ownerUserId → `NotEqualTransactionUserException`.
  - `CouponCodeRepository.findOneOrElseThrow(code.toUpperCase())` → 존재/미등록 검증 (`CouponRedeemValidator.validate`).
  - `CouponMaker.make(couponCode, request)` 로 `Coupon` 생성 (`couponCode.isRegistered=true` 마킹).
  - `CouponTransactionBuilder.build(request, coupon)` 로 `CouponTransaction(REDEEM)` 생성.
  - `CouponRepository.save` → `CouponCodeRepository.save` → `CouponTransactionRepository.save`. 전체 `@Transactional`.
- DB: 테이블 `Coupon`, `CouponCode`, `CouponTransaction`, `CouponTemplate` / `CouponIssue`. JPA Entity 기반. Envers로 Aud 로그.
- 외부 연동 없음(순수 DB 트랜잭션).

### 2) POST /api/v1/rewards/coupons/transactions/users/{userId}/types/use
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponTransactionController.java:95`
- 입력 DTO `CouponTransactionDto.Use`: `couponKey`, `userId`, `applyAmount`, `fundingAmount`.
- 처리 (`CouponUseService.use`, `src/main/java/com/wadiz/api/reward/coupon/application/CouponUseService.java:30`):
  - `CouponRepository.findOneOrElseThrow(couponKey)` → `CouponUseValidator.validate(coupon, request)` (유효기간/이미사용 여부 등).
  - `couponTransactionBuilder.build(request, coupon)` USE 트랜잭션 생성.
  - `coupon.use()` (`isUsed=true, usedDate=now`) → save coupon/transaction.
- DB: `Coupon.IsUsed`, `Coupon.UsedDate` 업데이트 + `CouponTransaction` insert (TransactionType=USE).
- 외부: 없음 (funding 서비스가 결제 플로우에서 이 API를 호출함; 본 서비스는 `application.funding-client` 를 통해 내부 User 조회만 수행).

### 3) GET /api/v1/rewards/coupons/expected-expiration (MyBatis)
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponController.java:69`
- 입력: `effectedStartDateTime`, `effectedEndDateTime` (yyyy-MM-dd'T'HH:mm:ss), `Pageable`.
- 로직: 컨트롤러가 `CouponQueryDao`를 직접 호출 — service 경유 X (조회 전용 규약).
- DB SQL (`src/main/resources/mapper/reward/coupon/coupon-query-mapper.xml:5`):
  ```sql
  SELECT CP.OwnerUserId,
         GROUP_CONCAT(distinct CT.CouponName) AS CouponName,
         GROUP_CONCAT(distinct IFNULL(CTL.CouponName, CT.CouponName)) AS CouponNameEn
    FROM Coupon CP USE INDEX(IDX_Coupon__EffectedUntil_IsUsed_OwnerUserId_TemplateNo)
    JOIN CouponTemplate CT ON CT.TemplateNo = CP.TemplateNo
    LEFT JOIN CouponTemplateLanguage CTL ON CTL.TemplateNo = CT.TemplateNo AND CTL.LanguageCode = 'en'
   WHERE CP.EffectedUntil BETWEEN #{start} AND #{end}
     AND CP.IsUsed = false
     AND CT.IsNotificationAllowed = true
   GROUP BY CP.OwnerUserId
   LIMIT #{offset}, #{pageSize}
  ```
- 용도: 쿠폰 만료 안내 알림 대상자 추출. 알림 허용 템플릿만 집계.

### 4) GET /api/v1/rewards/coupons/summations/templates[/{templateNo}]
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponSummationController.java:34`
- 로직: `CouponSummationDao` 직접 호출. 결과 `List<CouponSummationDto.ByTemplate>`.
- DB SQL (`src/main/resources/mapper/reward/coupon/coupon-summation-mapper.xml:27`): `CouponTemplate` + 서브쿼리로 `IssueQty / ExpireQty / ExpireAmount / REDEEM/USE/REFUND Qty/Amount / FundingAmount` 을 `|` 구분 문자열로 담아 `SUBSTRING_INDEX` 로 파싱. 쿠폰 별 상태 집계를 한 쿼리로 조립 (정책 변경 시 주의 필요).
- 발행 기준 집계는 `summationByIssue` (`coupon-summation-mapper.xml:5`): `CouponIssue` + `CouponTemplate` JOIN 후 IssueType별 CASE 로 IssueQty 산출.

### 5) POST /api/v1/rewards/coupons/templates
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponTemplateController.java:56`
- 입력 DTO `CouponTemplateDto.Create`: couponName, discountType(FIXED_AMOUNT/RATE), discount*, issueType(DIRECT_ISSUE/DOWNLOAD/COUPON_CODE/API_ISSUE), effectedFrom/To, expirationType, limitQtyPerUser, totalLimitQty, deviceConditionType, minFundingAmount, 외.
- 처리 (`CouponTemplateService.create`): `CouponTemplateDtoValidator.validate` → Entity 매핑(modelmapper) → Repository 저장 → `CouponIssue`(Times=1) 자동 생성 가능.
- DB: `CouponTemplate` + `CouponTemplateLanguage`(다국어) + `CouponTemplateManagementDepartment`, `CouponTemplateResponsibility`, `CouponTargetConditionMapping`. Envers로 `CouponTemplate_Aud` 기록.

### 6) POST /api/v1/rewards/coupons/makers/{makerUserId}/templates (메이커부담 쿠폰)
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/external/MakerCouponTemplateController.java:43`
- 입력: `CreateCouponTemplateRequest` → `MakerCouponTemplateDtoConverter.convert(makerUserId, dto)` 로 `CouponTemplateDto.Create` 변환 (메이커 식별자/targetConditionType 주입).
- 처리: 기존 `CouponTemplateService.create` 경로 재사용. 조회(`getAll`)는 `getAllMakerCouponTemplate` + `CouponTransactionSummationService.getSummationQuery` 를 병합하여 집계와 함께 응답.

### 7) POST /api/v1/rewards/satisfactions
- `reward-api/src/main/java/com/wadiz/api/reward/rest/satisfaction/SatisfactionController.java:35`
- 입력 DTO `SatisfactionDto.Create`: `campaignId`, `userId`, `comment(<=5000)`, `scores[]`(Item→Score), `images[]`.
- 처리 (`SatisfactionService.create`): `(campaignId, userId)` 고유 제약(@UniqueConstraint `UK_Satisfaction__CampaignId_UserId`) 체크 → averageScore 계산 → `Satisfaction` + `SatisfactionScore`(ElementCollection) + `SatisfactionImage` 저장 + 지급 혜택이 있으면 `SatisfactionBenefit` 연결.
- DB: 테이블 `Satisfaction`, `SatisfactionScore` (joinColumn=SatisfactionNo), `SatisfactionImage`, `SatisfactionBenefit`, `SatisfactionReply`. JPA Entity.

### 8) GET /api/v1/rewards/satisfactions/aggregates/campaigns/{campaignId}
- `reward-api/src/main/java/com/wadiz/api/reward/rest/satisfaction/SatisfactionAggregateController.java:24`
- DB SQL (`src/main/resources/mapper/reward/satisfaction/satisfaction-aggregate-mapper.xml:24`):
  ```sql
  SELECT CampaignId,
         (SELECT COUNT(*) FROM Satisfaction WHERE CampaignId=SF.CampaignId AND IsDeleted=FALSE) AS Qty,
         Item, ROUND(AVG(Score),1) AS AverageScore,
         SUM(CASE WHEN Score=1 THEN 1 ELSE 0 END) AS QtyOfOne, ...
    FROM SatisfactionScore SS LEFT JOIN Satisfaction SF ON SS.SatisfactionNo=SF.SatisfactionNo
   WHERE SF.CampaignId=#{campaignId} AND SF.IsDeleted=FALSE AND SF.IsHidden=FALSE
   GROUP BY CampaignId, Item
  ```
- `resultMap=aggregateResult` 에 `<collection property=aggregatesByItem ...>` 로 항목별 집계 구조로 변환.

### 9) POST /api/v1/rewards/collections
- `reward-api/src/main/java/com/wadiz/api/reward/rest/collection/CollectionController.java:54`, `application/CollectionService.create`.
- 입력 DTO `CollectionDto.Create`: `type`(CollectionType enum), `keyword`(unique), `title`, `message1/2`, `photoId1/2`, `campaigns[]`.
- 저장 테이블: **`RewardCollection`** (`@Table(name="RewardCollection", uniqueConstraints=UK_RewardCollection_Keyword)`, `src/main/java/com/wadiz/api/reward/collection/domain/Collection.java:24`) + `RewardCollectionMapping` (ElementCollection, campaignId 저장).
- Hibernate Envers 없음; AbstractRegisterAuditingEntity 상속.

### 10) POST /api/v1/rewards/memos
- `reward-api/src/main/java/com/wadiz/api/reward/rest/memo/MemoController.java:36`, `memo/application/MemoService.create`.
- 입력 DTO `MemoDto.Create`: `campaignId`, `memoCategory`, `content(<=1500)`.
- 테이블 `Memo` (+ `Memo_Aud` Envers 변경이력, `MemoHistory`): UniqueConstraint `UK_Memo__campaignId_memoCategory` — 카테고리별 1행 upsert 형태.

## DB 스키마 요약
JPA Entity + MyBatis 테이블을 종합.

| 테이블 | 용도 |
|-------|------|
| `Coupon` | 발급된 개별 쿠폰(UUID `CouponKey`, OwnerUserId, EffectedUntil, IsUsed, UsedDate, TemplateNo FK, IssueKey FK, CouponCode FK) |
| `CouponTemplate` (+_Aud) | 쿠폰 템플릿 마스터 (할인타입/금액/기간/조건/발행타입 등). Envers 감사. |
| `CouponTemplateLanguage` | 템플릿 다국어 (LanguageCode, 쿠폰명 번역) |
| `CouponTemplateManagementDepartment`, `CouponTemplateResponsibility` | 관리 부서/책임자 메타데이터 |
| `CouponIssue` | 발행 인스턴스 (IssueKey UUID, TemplateNo, Times). 동일 템플릿의 여러 차수 발행 관리 |
| `CouponCode` | 쿠폰 코드(리딤 코드) 마스터 |
| `CouponTransaction` | 거래(REDEEM/USE/REFUND/WITHDRAW) 원장. `TransactionKey`(UUID), IsCanceled, ApplyAmount, FundingAmount |
| `CouponIssuePurposeType` | 발행 목적 enum(@Deprecated) |
| `CouponIssueSummation` | 발행 건수 집계 |
| `CouponTransactionSummation` | 거래 집계 (템플릿별 REDEEM/USE/REFUND 수·금액) |
| `ProjectCouponSummary`(+`ProjectCouponSummary_new`) | 프로젝트(campaign)별 적용 가능 쿠폰 요약 (배치 재생성: `CREATE TABLE _new LIKE ... INSERT ... RENAME`) |
| `CouponTargetConditionMapping` | 템플릿 적용 대상 매핑 (PROJECT/COLLECTION) |
| `RewardCollection` | 리워드 컬렉션/기획전 (keyword unique) |
| `RewardCollectionMapping` | 컬렉션 ↔ 캠페인 매핑 |
| `Satisfaction` (+_Aud via AbstractRegisteredAuditingEntity) | 만족도 평가. (CampaignId, UserId) unique |
| `SatisfactionScore` | 만족도 항목별 점수 (CollectionTable) |
| `SatisfactionImage` | 만족도 첨부 이미지 |
| `SatisfactionBenefit` | 만족도 혜택 지급 상태 |
| `SatisfactionReply` | 만족도 댓글 |
| `Memo` (+_Aud), `MemoHistory` | 캠페인 카테고리 메모 |
| `RevInfo` | Envers 리비전 테이블 |

## 외부 의존성
설정: `src/main/resources/application-default.yml`, `reward-api/src/main/resources/application.yml`.
- 호출 클라이언트 (`support/client/**`, `InternalAuthorizationInterceptor(Bearer token)`):
  - **funding** — `application.funding-client.url` (dev `http://dev-app01:9990/funding`) — `GET /api/internal/users/{id}`, `POST /api/internal/users` (사용자 조회/유효성).
  - **backoffice** — `application.backoffice-client.url` (dev `https://dev-platform.wadizcorp.net/backoffice`) — `GET /collection/coupon` (컬렉션 쿠폰 메타).
  - **alim-talk** — `application.alim-talk-client.url` (dev `https://dev-platform.wadizcorp.net/alimtalk`) — 알림톡 발송(만료 안내 등).
  - **normal-mail** — `application.normal-mail-client.url` (dev `https://dev-platform.wadizcorp.net/mail-normal`) — 메일 발송.
  - **push** — `application.push-client.url` (dev `https://dev-platform.wadizcorp.net/push`) — 앱 푸시/Inbox.
- MQ (`src/main/java/com/wadiz/api/reward/config/RabbitMqConfig.java`): RabbitMQ ConnectionFactory/Template/ListenerFactory bean 구성. Host: `spring.rabbitmq.host` (dev `192.168.0.103:5672`). 기본 bean만 있으며 현재 코드에서 `convertAndSend`/`@RabbitListener` 사용처는 확인되지 않음(미래 확장용 또는 배치에서 사용).
- Redis Cluster: `spring.redis.cluster.nodes` (192.168.1.240-242).
- Hazelcast: `classpath:hazelcast/hazelcast-default.yaml` 분산 캐시/락.
- Consul Discovery: 192.168.1.216:8500, service-name=`reward`.
- 외부 DB: 주 `wadiz_reward`, 보조 `wadiz_db`(캠페인 등) master/slave hikari pool (slave `maximum-pool-size:60`).

## 특이사항
- **Gradle 구조가 비표준**: `build.gradle` 에서 `bootJar.enabled=false`, 공유 소스는 루트 `src/main/java`에, 실행가능 JAR는 `reward-api/` 서브 모듈에 있음. 다른 서비스(batch)와 소스를 공유.
- **Envers 사용** (`spring-data-envers`): `@Audited` 엔티티는 자동으로 `X_Aud` 테이블에 변경 이력이 쌓임. `hbm2ddl.auto: validate` (절대 변경 금지 주석).
- **PascalCase 테이블/컬럼**: `PascalCasePhysicalNamingStrategy` 사용 → DB는 PascalCase.
- **`@Deprecated` 다수**: `CouponQueryController`, `getIssuePurposeTypes`, `CouponController.getAllExpectedExpiration...` (CouponQueryController → CouponController 로 이전 중).
- **레거시 UUID 매핑**: `Coupon.couponKey` 는 `columnDefinition="BINARY(16)"` 로 저장, MyBatis 쪽은 `UuidTypeHandler` 커스텀 타입핸들러 사용.
- **`ProjectCouponSummary_new` 패턴**: 배치/재생성 시 `_new` 테이블을 생성 → INSERT → RENAME 으로 무중단 갱신 (mybatis `createNewTable`/`dropNewTable` 참고).
- **DDD 규약**: README에 "application 레이어에 도메인 로직 금지!!!" 라고 강하게 적혀 있음 — 도메인 로직은 `domain.service` 로 분리.
- **멀티 트랜잭션 매니저**: `@WadizTx` 또는 `@Transactional("wadizTransactionManager")` 를 `wadiz_db` 접근 시 명시해야 함.
- 보안 토큰(알림, funding, backoffice 등)이 `application-default.yml`에 평문으로 포함되어 있음 — 실제 운영 환경은 별도 주입 권장.
- Java 1.8 + Spring Boot 2.6.7 + springdoc 1.x 조합으로, 서비스 중 상대적으로 **중간 연식**의 스택.
