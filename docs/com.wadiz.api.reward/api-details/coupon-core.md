# 쿠폰 코어 도메인 상세 스펙

> **기록 범위**
>
> 본 문서는 `com.wadiz.api.reward` repo 안에서 직접 관측 가능한 것만 기록한다.
> - 대상 소스: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/` 의 9개 컨트롤러, 루트 `src/main/java/com/wadiz/api/reward/coupon/` 하위의 application/domain/infra 코드, `src/main/resources/mapper/reward/coupon/` 의 MyBatis XML.
> - **외부 경계**:
>   - `com.wadiz.api.reward.dto.coupon.*`, `com.wadiz.api.reward.coupon.constant.*` 은 외부 의존 jar `com.wadiz.api.reward:reward-models` 에 존재 (`gradle/wadiz.gradle:2`). DTO·enum 내부 필드는 본 repo에서 관측 불가하며, 호출부에서 사용되는 시그니처만 기록한다.
>   - `FundingApiClient`, `BackOfficeApiClient`, 알림톡/메일/푸시 클라이언트는 `support/client/*` 에 존재하나 본 9개 컨트롤러 흐름에서는 호출되지 않는다. (관련 grep 결과: 쿠폰 application 에서 해당 클라이언트 import 없음)
> - **추측 금지**: SQL은 MyBatis XML 본문을 복붙한다. JPA `findAll(Specification)` 은 Criteria API로 런타임 생성되므로 본문 대신 Specification 빌더 메서드를 열거한다. JPQL 메서드(`findAllByWithdrawTarget` 등)는 구현체가 본 repo 범위 외에서 제공될 수 있으므로 "인터페이스 선언" 수준만 기록한다.

---

## 1. 개요

`com.wadiz.api.reward` 는 크라우드펀딩/스토어 쿠폰의 **발급·등록·사용·반환·회수·취소** 와 **템플릿/발행/집계** 를 담당하는 도메인 API. base prefix `/api/v1/rewards/coupons` 하위 9개 컨트롤러가 다음과 같이 책임 분리돼 있다.

| 컨트롤러 | 책임 | 저장 대상 (주) |
|---|---|---|
| `CouponController` | 사용자/쿠폰키 기준 **조회**, 할인금액 계산, 만료예정 그룹 조회 | `Coupon` |
| `CouponIssueController` | **발행(Issue)** 생성/조회, 쿠폰코드 발급 | `CouponIssue`, `CouponCode` |
| `CouponQueryController` | 비정형 조회 (현재 만료예정 Group By User 만, Deprecated) | 조회 전용 |
| `CouponTemplateController` | **템플릿** CRUD, 템플릿 기반 쿠폰 조회 | `CouponTemplate`, `CouponIssue` |
| `CouponTransactionController` | **거래 이벤트**: 등록(Redeem)/사용(Use)/반환(Refund)/회수(Withdraw)/취소(Cancel) | `Coupon`, `CouponTransaction` |
| `CouponSummationController` | **실시간** 집계 (쿠폰/발행 단위 SUM) | 동적 SUM (비저장) |
| `CouponIssueSummationController` | **발행 집계** 조회 by templateNos | `CouponIssueSummation` (비정규화) |
| `CouponTransactionSummationController` | **거래 집계** 조회 (일자별 배치 적재) | `CouponTransactionSummation` (비정규화) |
| `ProjectCouponSummaryController` | **프로젝트 단위 다운로드 가능 쿠폰** 카탈로그 조회 | `ProjectCouponSummary` (비정규화, 스왑테이블) |

**호출자 관찰**: 외부 호출자의 직접 증거는 본 repo 안에 없지만, 다음 방증이 있다.
- `@Tag` 설명이 "사용자 쿠폰 API", "쿠폰 템플릿 관리 API" 등으로 분리되어 있어 소비자가 사용자 웹(`com.wadiz.web`), 어드민(`com.wadiz.adm`), 메이커센터(`makercenter-*`), 내부 배치를 모두 포괄.
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/consumer/CouponTransactionConsumer.java:1-23` 의 RabbitMQ `@RabbitListener(queues = "#{saveCouponQueue.name}")` 가 `CouponRedeemService.redeemByIssue(...)` 를 동일 서비스로 호출 → 타 서비스 비동기 이벤트로 쿠폰 지급을 트리거하는 소비자 존재.
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/external/MakerCouponController.java`, `MakerCouponTemplateController.java` 가 별도로 존재 (본 9개 범위 외) — 메이커센터 백엔드(`makercenter-be`)가 사용한다고 추정 가능하나 본 문서 범위 외.

집계를 3가지 방식으로 분리한 의도 (관측 사실 기준):
- **on-demand**(Summation): `CouponSummation` 은 원본 테이블에 대한 런타임 GROUP BY (SQL 본문 §5 참조).
- **누적 카운터**(IssueSummation): `CouponIssueSummation(templateNo, qty, updated)` 1행 = 템플릿별 누적 발급 수. 본 repo에서는 `findAllById` 만 노출되고 증가 로직은 외부(배치 또는 트리거)에서 반영되는 것으로 보임 (본 repo에서 INSERT/UPDATE 관찰 안됨, §6 참조).
- **일자별 집계**(TransactionSummation): 배치 탱크릿이 `INSERT ... SELECT` 로 `CouponTransactionSummation(templateNo, transactionDate)` 누적.
- **정적 카탈로그**(ProjectCouponSummary): 배치 탱크릿이 스왑테이블 패턴으로 재빌드.

---

## 2. 엔드포인트 전수 테이블

총 **34 endpoints** (9 controllers).

| # | Controller | METHOD | Path | 요약 |
|---|---|---|---|---|
| 1 | CouponController | GET | `/api/v1/rewards/coupons` | 쿠폰 목록 조회 (전역) |
| 2 | CouponController | GET | `/api/v1/rewards/coupons/owners/{userId}` | 사용자 쿠폰 목록 조회 |
| 3 | CouponController | GET | `/api/v1/rewards/coupons/owners/{userId}/qty` | 사용자 쿠폰 건수 조회 |
| 4 | CouponController | GET | `/api/v1/rewards/coupons/{couponKey}` | 쿠폰 상세 조회 |
| 5 | CouponController | GET | `/api/v1/rewards/coupons/{couponKey}/discount-amount` | 쿠폰 할인 금액 계산 |
| 6 | CouponController | GET | `/api/v1/rewards/coupons/expected-expiration` | 만료 예정 쿠폰 목록 GroupBy User |
| 7 | CouponIssueController | POST | `/api/v1/rewards/coupons/issues` | 쿠폰 발행 생성 |
| 8 | CouponIssueController | GET | `/api/v1/rewards/coupons/issues` | 쿠폰 발행 목록 조회 |
| 9 | CouponIssueController | GET | `/api/v1/rewards/coupons/issues/{issueKey}` | 쿠폰 발행 단건 조회 |
| 10 | CouponIssueController | GET | `/api/v1/rewards/coupons/issues/{issueKey}/codes` | 쿠폰 코드 목록 조회 |
| 11 | CouponIssueController | GET | `/api/v1/rewards/coupons/issues/purpose-types` | 쿠폰 발행 목적 유형 목록 (Deprecated) |
| 12 | CouponQueryController | GET | `/api/v1/rewards/coupons/queries/expected-expiration` | 만료 예정 쿠폰 목록 GroupBy User (Deprecated) |
| 13 | CouponTemplateController | GET | `/api/v1/rewards/coupons/templates/{templateNo}` | 쿠폰 템플릿 상세 조회 |
| 14 | CouponTemplateController | GET | `/api/v1/rewards/coupons/templates` | 쿠폰 템플릿 목록 조회 |
| 15 | CouponTemplateController | GET | `/api/v1/rewards/coupons/templates/qty` | 쿠폰 템플릿 건수 조회 |
| 16 | CouponTemplateController | POST | `/api/v1/rewards/coupons/templates` | 쿠폰 템플릿 생성 |
| 17 | CouponTemplateController | PUT | `/api/v1/rewards/coupons/templates/{templateNo}` | 쿠폰 템플릿 수정 |
| 18 | CouponTemplateController | GET | `/api/v1/rewards/coupons/templates/{templateNo}/coupons` | 템플릿별 쿠폰 목록 조회 |
| 19 | CouponTemplateController | GET | `/api/v1/rewards/coupons/templates/{templateNo}/coupons/qty` | 템플릿별 쿠폰 건수 조회 |
| 20 | CouponTransactionController | GET | `/api/v1/rewards/coupons/transactions/{transactionKey}` | 쿠폰 거래 상세 조회 |
| 21 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/coupon-code` | 쿠폰 등록 by coupon-code |
| 22 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/{issueType:download\|direct\|api}` | 쿠폰 등록 by Issue (download/direct/api) |
| 23 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/{userId}/types/redeem/issue-types/{issueType:download\|direct\|api}/bulk` | Bulk 쿠폰 등록 by IssueKeys |
| 24 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/types/redeem/issue-types/{issueType:direct\|api}/bulk` | Bulk 쿠폰 등록 by userIds |
| 25 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/{userId}/types/withdraw` | 쿠폰 회수 |
| 26 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/{userId}/types/use` | 쿠폰 사용 |
| 27 | CouponTransactionController | POST | `/api/v1/rewards/coupons/transactions/users/{userId}/types/refund` | 쿠폰 반환 |
| 28 | CouponTransactionController | DELETE | `/api/v1/rewards/coupons/transactions/{transactionKey}` | 쿠폰 거래 취소 |
| 29 | CouponSummationController | GET | `/api/v1/rewards/coupons/summations/templates` | 쿠폰 통계 목록 (전체 템플릿) |
| 30 | CouponSummationController | GET | `/api/v1/rewards/coupons/summations/templates/{templateNo}` | 쿠폰 통계 단건 (템플릿) |
| 31 | CouponSummationController | GET | `/api/v1/rewards/coupons/summations/issues/{issueKey}` | 쿠폰 통계 by 발행 |
| 32 | CouponIssueSummationController | GET | `/api/v1/rewards/coupons/issue-summation` | 쿠폰 발행 집계 by templateNos |
| 33 | CouponTransactionSummationController | GET | `/api/v1/rewards/coupons/transaction-summation` | 쿠폰 거래 집계 조회 |
| 34 | ProjectCouponSummaryController | GET | `/api/v1/rewards/coupons/projects` | 프로젝트 쿠폰 목록 (all) |
| 35 | ProjectCouponSummaryController | GET | `/api/v1/rewards/coupons/projects/{projectNo}` | 프로젝트 only 쿠폰 목록 |

(35개 endpoint — 두 controller 중복(6 / 12)은 동일 `CouponQueryDao` 를 사용하는 동일 핸들러.)

---

## 3. 컨트롤러별 상세

### 3.1 `CouponController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponController.java:32`
- Base path: `/api/v1/rewards/coupons`
- Produces: `application/json`
- 의존: `CouponService`, `CouponConverter`, `CouponQueryDao`

| 메서드 | HTTP | Path | 입력 | 호출 | 비고 |
|---|---|---|---|---|---|
| `getAll` | GET | `""` | `@Valid CouponDto.Search search`, `Pageable sort` | `couponService.getAll(search, sort.getSort())` → `CouponRepository.findAll(Specification, Sort)` | 사용자 조건 없이 전역 검색. 정렬만 사용 (Page 없음). |
| `getAll` | GET | `/owners/{userId}` | `userId @PathVariable @Min(1)`, `search`, `sort` | `couponService.getAllByUser(userId, search, sort.getSort())` | 응답 매핑에 `search.getFundingAmount()` 전달 → 할인액 선계산. |
| `getQty` | GET | `/owners/{userId}/qty` | 동일 | `couponService.getQtyByUser(userId, search)` → `CouponRepository.count(Specification)` | Integer 반환. |
| `get` | GET | `/{couponKey}` | `UUID couponKey` | `couponService.get(couponKey)` → `couponRepository.findOneOrElseThrow(couponKey)` | `@Transactional` (non-readOnly) — 코드상 그대로. |
| `getDiscountAmountByCouponKey` | GET | `/{couponKey}/discount-amount` | `UUID couponKey`, `CouponDto.DiscountAmountRequest request` | `coupon.calculateDiscountAmount(fundingAmount)` (`CouponTemplate.calculateDiscountAmount`) | FIXED_AMOUNT/FIXED_RATE 분기, `maxDiscountAmount` cap 적용 (`CouponTemplate.java:182-195`). |
| `getAllExpectedExpirationCouponsGroupByUser` | GET | `/expected-expiration` | `LocalDateTime effectedStartDateTime`, `effectedEndDateTime`, `Pageable` | `couponQueryDao.getAllExpectedExpirationCouponsGroupByUser(...)` + `countExpectedExpirationCouponsGroupByUser(...)` | `CouponController.java:70-76`. `CouponQueryController.java:39-45` 이 동일 핸들러를 가지며 `@Deprecated`. |

**`CouponService.getAll(...)` 내부 흐름** (`CouponService.java:50-54`):
1. `new CouponSpecificationBuilder(search).build()` 로 동적 Criteria 생성
2. `couponRepository.findAll(specs, sort)` — JPA 동적 쿼리 (SQL 본문 없음)

Specification 빌더 지원 조건 (`CouponSpecification.java`):
- `equalOwner(userId)` — `Coupon.ownerUserId = ?`
- `lessThanOrEqualToAmount(minFundingAmount)` — `CouponTemplate.minFundingAmount <= ? OR IS NULL`
- `inDeviceCondition(List<DeviceConditionType>)` — `CouponTemplate.deviceConditionType IN (...)`
- `inTargetCondition(List<TargetCondition>)` — `CouponTemplate.targetConditionType + targetConditionMappings.targetConditionKey IN (...)` (distinct)
- `lessThanEqualToDate(date)` — `Coupon.effectedUntil <= ?`
- `equalIsUsedAndGreaterThanDate(bool, date)` — `Coupon.isUsed = ? AND Coupon.effectedUntil > ?` (미사용/유효)
- `equalIsUsedOrLessThanOrEqualToDate(bool, date)` — `Coupon.isUsed = ? OR Coupon.effectedUntil <= ?` (사용됨 또는 만료)
- `equalTemplateNo(templateNo)` — `Coupon.couponTemplate.templateNo = ?`
- `greaterThanOrEqualToEffectedUntil(date)` / `greaterThanOrEqualToUseDate(date)`

---

### 3.2 `CouponIssueController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponIssueController.java:27`
- Base: `/api/v1/rewards/coupons/issues`
- 의존: `CouponIssueService`, 3개 Converter

| 메서드 | HTTP | Path | 핵심 흐름 |
|---|---|---|---|
| `create` | POST | `""` | `CouponIssueService.create(CouponIssueDto.Create)` → `CouponTemplate` 조회 → `CouponIssueBuilder.buildIssue` → `CouponIssueValidator.validate` → `couponIssueRepository.saveAndFlush(couponIssue)` → `@AfterCommit` 에 `couponCode.shouldPublishCouponCode()` 이면 `CouponCodePublisher.publish(...)` 호출 (`CouponIssueService.java:49-68`). |
| `getAll` | GET | `""` | `CouponIssueSpecificationBuilder(search).build()` + 정렬 `REGISTERED ASC` 고정 (`CouponIssueService.java:77-82`). |
| `getOne` | GET | `/{issueKey}` | `couponIssueRepository.findOneOrElseThrow(issueKey)`. |
| `getCodes` | GET | `/{issueKey}/codes` | IssueType이 `COUPON_CODE` 가 아니면 `CouponCodeNotSupportedException`. `couponCodeRepository.findAllByCouponIssue(couponIssue)` (`CouponIssueService.java:85-93`). |
| `getIssuePurposeTypes` | GET | `/purpose-types` | `@Cacheable("CouponIssueService.getIssuePurposeTypes")`. `issuePurposeTypeRepository.findAllIsUsableTrue()`. **`@Deprecated`**. |

**쿠폰 코드 발급 세부** (`CouponCodePublisher.java`):
- **비동기**: `@Async` + `@Transactional(propagation = SUPPORTS)` — 본체 트랜잭션과 분리.
- 문자 집합: `3,4,6,7,8,9,A,B,C,D,E,F,G,H,J,K,L,M,N,P,Q,R,T,U,V,W,X,Y` (0/1/2/5/I/O/S/Z 제외). 길이 10, 최대 10회 재시도.
- 실패 시 `FailedCouponCodePublishException`. 기존 성공 코드는 롤백 안 함 (line 39-43 주석 명시).

---

### 3.3 `CouponQueryController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponQueryController.java:28`
- Base: `/api/v1/rewards/coupons/queries`
- 의존: `CouponQueryDao`

| 메서드 | HTTP | Path | 비고 |
|---|---|---|---|
| `getAllExpectedExpirationCouponsGroupByUser` | GET | `/expected-expiration` | **`@Deprecated`** — `CouponController`의 `/expected-expiration` 로 이관됨 (동일 DAO 호출). |

**MyBatis SQL** (`src/main/resources/mapper/reward/coupon/coupon-query-mapper.xml:5-26`):

```sql
-- namespace: com.wadiz.api.reward.coupon.infra.dao.CouponQueryDao

<!-- getAllExpectedExpirationCouponsGroupByUser -->
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

<!-- countExpectedExpirationCouponsGroupByUser -->
SELECT count(DISTINCT CP.OwnerUserId)
FROM Coupon CP USE INDEX(IDX_Coupon__EffectedUntil_IsUsed_OwnerUserId_TemplateNo)
JOIN CouponTemplate CT ON CT.TemplateNo = CP.TemplateNo
WHERE CP.EffectedUntil BETWEEN #{effectedStartDateTime} AND #{effectedEndDateTime}
  AND CP.IsUsed = false
  AND CT.IsNotificationAllowed = true
```

특징:
- `USE INDEX(IDX_Coupon__EffectedUntil_IsUsed_OwnerUserId_TemplateNo)` 힌트 고정.
- 영문 쿠폰명은 `CouponTemplateLanguage(LanguageCode='en')` 에서 폴백 (IFNULL).
- `IsNotificationAllowed=true` 만 알림 대상.

---

### 3.4 `CouponTemplateController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponTemplateController.java:27`
- Base: `/api/v1/rewards/coupons/templates`
- 의존: `CouponTemplateService`, `CouponTemplateDtoValidator` (Spring `Validator`), 2개 Converter

| 메서드 | HTTP | Path | 핵심 흐름 |
|---|---|---|---|
| `get` | GET | `/{templateNo}` | `CouponTemplateService.get(Integer)` → `couponTemplateRepository.findOneOrElseThrow(templateNo)` |
| `getAll` | GET | `""` | `CouponTemplateSpecificationBuilder(search)` + Pageable. `search.getExcludeRedeemedByUserId() != null` 이면 후처리 필터 `excludeRedeemedByUserId` → `couponRepository.countAllByOwnerUserIdAndCouponTemplate(userId, template)` 이 `limitQtyPerUser` 미만인 템플릿만 남김 (`CouponTemplateService.java:86-99`). |
| `getQty` | GET | `/qty` | 전체 Spec 로드 후 후처리 필터 적용 → `.size()` (`CouponTemplateService.java:121-133`). |
| `create` | POST | `""` | 1) `CouponTemplateDtoValidator.validate(request, errors)` 2) `CouponTemplateBuilder.buildTemplate(request)` 3) `couponTemplateRepository.save(couponTemplate)` 4) `shouldIssueImmediately()` (IssueType = `DOWNLOAD`/`API_ISSUE`) 이면 `CouponIssueBuilder.buildDefaultFirstIssue(template)` 저장 (`CouponTemplateService.java:46-58`). |
| `modify` | PUT | `/{templateNo}` | `couponTemplateRepository.findOneOrElseThrow` → `CouponTemplateValidator.validate(current, request)` → `CouponTemplateBuilder.build(current, request)` → `save(template)` + `couponIssueRepository.save(getCouponIssues())` (`CouponTemplateService.java:60-71`). |
| `getCoupons` | GET | `/{templateNo}/coupons` | `CouponDto.Search.builder().templateNo(templateNo)` + `ownerUserId` → `CouponSpecificationBuilder` → `couponRepository.findAll(specs, pageable)` (`CouponTemplateService.java:142-149`). |
| `getCouponQty` | GET | `/{templateNo}/coupons/qty` | `couponRepository.countAllByCouponTemplate(template)`. |

**Envers audit**: `CouponTemplate` 는 `@Audited(withModifiedFlag=true)` + `@AuditOverride(forClass=AbstractAuditingEntity.class)` (`CouponTemplate.java:26-27`). `couponIssues`, `targetConditionMappings`, `templateResponsibility`, `couponLanguages`, `costBearer` 는 `@NotAudited`. → Hibernate Envers 가 별도 history 테이블을 생성/기록 (schema는 Envers 관례, 본 repo에서 명시 DDL은 없음).

**다국어**: `CouponTemplate.couponLanguages: List<CouponTemplateLanguage>` + `CouponTemplateLanguageId(templateNo, languageCode)`. `createCouponLanguage(languageCode, couponName)` 로 추가 (`CouponTemplate.java:117-122`).

---

### 3.5 `CouponTransactionController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponTransactionController.java:23`
- Base: `/api/v1/rewards/coupons/transactions`
- 의존: 5개 서비스 `CouponRedeemService`, `CouponUseService`, `CouponRefundService`, `CouponTransactionService`, `CouponWithdrawService`

**공통 가드**: `userId @PathVariable` 과 `request` 의 owner/userId 가 일치하지 않으면 `NotEqualTransactionUserException` (대부분 엔드포인트).

| 메서드 | HTTP | Path | Service.method | 저장 |
|---|---|---|---|---|
| `get` | GET | `/{transactionKey}` | `CouponTransactionService.get(transactionKey)` | 없음 |
| `redeemByCouponCode` | POST | `/users/{userId}/types/redeem/issue-types/coupon-code` | `CouponRedeemService.redeemByCouponCode(req)` | `Coupon`, `CouponCode.isRegistered=true`, `CouponTransaction(REDEEM)` |
| `redeemByIssue` | POST | `/users/{userId}/types/redeem/issue-types/{issueType:download\|direct\|api}` | `CouponRedeemService.redeemByIssue(req, issueType)` | `Coupon` + `CouponTransaction(REDEEM)` |
| `redeemByIssueList` | POST | `.../{issueType}/bulk` | `CouponRedeemService.redeemByIssueList(req, issueType)` | 각 issueKey 루프. `isReturnSuccessOnly=true` 이면 실패건 swallow 후 성공만 반환. |
| `bulkRedeemByIssue` | POST | `/users/types/redeem/issue-types/{issueType:direct\|api}/bulk` | `CouponRedeemService.quietlyRedeemByUserList(req, issueType)` | 사용자 루프. 실패 시 빈 `CouponTransaction`(userId만 세팅) 반환. |
| `withdraw` | POST | `/users/{userId}/types/withdraw` | `CouponWithdrawService.withdraw(req)` | `coupon.effectedUntil = now()` (만료 처리) + `CouponTransaction(WITHDRAW)` |
| `use` | POST | `/users/{userId}/types/use` | `CouponUseService.use(req)` | `coupon.isUsed=true, usedDate=now` + `CouponTransaction(USE)` |
| `refund` | POST | `/users/{userId}/types/refund` | `CouponRefundService.refund(req)` | `useTransaction.referenceTransaction = refund`, `coupon.refund()` + `CouponTransaction(REFUND)` |
| `cancel` | DELETE | `/{transactionKey}` | `CouponTransactionService.cancel(transactionKey)` | `CouponTransaction.isCanceled=true` + 역방향 쿠폰 상태 원복 (아래 참조) |

**도메인 상태 전이** (`Coupon.java` + `CouponTransaction.java`):
- `use()` : `isUsed=true`, `usedDate=now`
- `refund()` : `isUsed=false`, `usedDate=null`
- `withdraw()` : `effectedUntil=now` (만료)
- `cancelUse()` : `isUsed=false`, `usedDate=null`
- `cancelRefund(usedDate)` : `isUsed=true`, `usedDate=useTransaction.registered`
- `CouponTransaction.cancel()` 은 `transactionType` 에 따라 `coupon.cancelUse()` 또는 `coupon.cancelRefund(ref.registered)` 호출 (`CouponTransaction.java:66-74`).

**등록 제한 검증** (`CouponRedeemValidator.java`):
- Redis counter (`RedisTemplate<String,Long>`) 키 2종:
  - `REWARD_COUPON_ISSUE_QTY:USER:<templateNo>:<userId>QTY` — 사용자당 한도 `limitQtyPerUser`
  - `REWARD_COUPON_ISSUE_QTY:TEMPLATE:<templateNo>QTY` — 템플릿 총량 `totalLimitQty`
- 각 키 TTL 60초. INCR → 한도 초과 시 롤백 DECR + 예외.
- User 초과 + 전체 초과 시 예외 순서: `LimitQtyPerUserException` → `LimitTotalIssueQtyException` (전체 초과시 user counter도 DECR).
- `validEffected`: `effectedFrom <= now <= effectedTo` 아니면 `CouponRedeemNotEffectedException`.
- `validCouponCode`: `!couponCode.isAvailable()` 시 `CouponCodeAlreadyUsedException`.
- `validEffectedUntil`: `ExpirationType=DEFINE_WHEN_ISSUED` 인데 `effectedUntil=null` 이면 `CouponEffectedUntilNotValidException`.
- `validIssueType`: `couponTemplate.getIssueType().getRedeemIssueType()` 와 path `issueType` 대소문자 무시 불일치 시 `NotEqualIssueTypeException`.

**회수 경로 분기** (`CouponWithdrawService.java`):
- `WithdrawType=COUPON_KEY` : `couponRepository.findOneOrElseThrow(couponKey)` → `CouponWithdrawValidator.validate(coupon, request)` → `withdrawCoupon`.
- 그 외: `issueKeys` 리스트 루프 → `couponRepository.findAllByWithdrawTarget(couponIssue, ownerUserId)` 전부 회수.

---

### 3.6 `CouponSummationController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponSummationController.java:25`
- Base: `/api/v1/rewards/coupons/summations`
- 의존: `CouponSummationDao` (MyBatis)

| 메서드 | HTTP | Path | DAO |
|---|---|---|---|
| `getAll` | GET | `/templates` | `couponSummationDao.summation()` |
| `get` | GET | `/templates/{templateNo}` | `couponSummationDao.summation(templateNo)` — 비어있으면 `CouponTemplateSummationNotFoundException` |
| `getByIssue` | GET | `/issues/{issueKey}` | `couponSummationDao.summationByIssue(issueKey)` — 비어있으면 `CouponIssueSummationNotFoundException` |

**MyBatis SQL — summation by issue** (`coupon-summation-mapper.xml:5-25`):

```sql
<!-- namespace: com.wadiz.api.reward.coupon.infra.dao.CouponSummationDao -->
SELECT CI.IssueKey
     , CASE CT.IssueType
         WHEN 'DIRECT_ISSUE' THEN COUNT(CP.CouponKey)
         WHEN 'DOWNLOAD' THEN CT.TotalLimitQty
         WHEN 'COUPON_CODE' THEN (SELECT COUNT(CouponCode) FROM CouponCode WHERE IssueKey = CI.IssueKey)
         WHEN 'API_ISSUE' THEN CT.TotalLimitQty
         ELSE 0
       END AS IssueQty
     , COUNT(CouponKey) AS RedeemQty
     , IFNULL(SUM(CASE WHEN CP.IsUsed = TRUE THEN 1 ELSE 0 END),0) AS UseQty
FROM CouponIssue CI
JOIN CouponTemplate CT on CI.TemplateNo = CT.TemplateNo
LEFT JOIN Coupon CP on CI.IssueKey = CP.IssueKey
WHERE CI.IssueKey = #{issueKey, javaType=java.util.UUID, jdbcType=BINARY,
                     typeHandler=com.wadiz.api.reward.support.UuidTypeHandler}
GROUP BY CI.issueKey
```

- `UuidTypeHandler` 로 BINARY(16) 바인딩.
- `IssueQty` 계산은 발행 타입별 분기. `DOWNLOAD`/`API_ISSUE` 는 `TotalLimitQty`, `COUPON_CODE` 는 서브쿼리, `DIRECT_ISSUE` 는 실제 `Coupon` 행 수.

**MyBatis SQL — summation by template** (`coupon-summation-mapper.xml:27-76`):

```sql
SELECT A.TemplateNo,
       B.IssueQty,
       CASE WHEN A.DiscountType = 'FIXED_AMOUNT' THEN B.IssueQty * A.DiscountAmount ELSE 0 END AS IssueAmount,
       B.ExpireQty,
       B.ExpireAmount,
       IFNULL(SUBSTRING_INDEX(B.TransactionQty, '|', 1), 0) AS RedeemQty,
       IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(B.TransactionQty, '|', 2), '|', -1), 0) AS UseQty,
       IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(B.TransactionQty, '|', 3), '|', -1), 0) AS RefundQty,
       IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(B.TransactionQty, '|', 4), '|', -1), 0) AS RedeemAmount,
       IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(B.TransactionQty, '|', 5), '|', -1), 0) AS UseAmount,
       IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(B.TransactionQty, '|', 6), '|', -1), 0) AS RefundAmount,
       IFNULL(SUBSTRING_INDEX(B.TransactionQty, '|', -1), 0) AS FundingAmount
FROM CouponTemplate A
INNER JOIN (
    SELECT CT.TemplateNo,
           CASE CT.IssueType
               WHEN 'DIRECT_ISSUE' THEN COUNT(CP.CouponKey)
               WHEN 'DOWNLOAD' THEN CT.TotalLimitQty
               WHEN 'COUPON_CODE' THEN (SELECT COUNT(*) FROM CouponCode WHERE IssueKey = CP.IssueKey)
               WHEN 'API_ISSUE' THEN CT.TotalLimitQty
               ELSE 0
           END AS IssueQty,
           IFNULL(SUM(CASE WHEN CP.IsUsed = FALSE AND CP.EffectedUntil < NOW() THEN 1 ELSE 0 END), 0) as ExpireQty,
           IFNULL(SUM(CASE WHEN CT.DiscountType = 'FIXED_AMOUNT' AND CP.IsUsed = false AND CP.EffectedUntil < NOW() THEN CT.DiscountAmount ELSE 0 END), 0) as ExpireAmount,
           (
               SELECT CONCAT(
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'REDEEM' THEN 1 ELSE 0 END), 0), '|',
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'USE' THEN 1 ELSE 0 END), 0), '|',
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'REFUND' THEN 1 ELSE 0 END), 0), '|',
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'REDEEM' AND CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount ELSE 0 END), 0), '|',
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'USE' THEN CTS.ApplyAmount ELSE 0 END), 0), '|',
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'REFUND' THEN CTS.ApplyAmount ELSE 0 END),0), '|',
                   IFNULL(SUM(CASE WHEN CTS.TransactionType = 'USE' AND CTS.FundingAmount IS NOT NULL THEN CTS.FundingAmount
                                   WHEN CTS.TransactionType = 'REFUND' AND CTS.FundingAmount IS NOT NULL THEN -CTS.FundingAmount
                                   ELSE 0 END), 0))
               FROM      CouponTransaction CTS
               WHERE     CTS.TemplateNo = CT.TemplateNo
               AND       CTS.IsCanceled = false
           ) as TransactionQty
    FROM CouponTemplate CT
    LEFT JOIN Coupon CP ON (CP.TemplateNo = CT.TemplateNo)
    <choose>
        <when test="templateNo != null">WHERE CT.TemplateNo = #{templateNo}</when>
        <otherwise>GROUP BY CT.TemplateNo</otherwise>
    </choose>
) B ON (B.TemplateNo = A.TemplateNo)
```

**주목할 패턴**: 7개 집계값을 `CONCAT('|')` 으로 한 컬럼에 packed → 외부에서 `SUBSTRING_INDEX(..., '|', n)` 로 파싱. 서브쿼리 1회 수행으로 7개 SUM 을 수집하는 최적화 (반복 JOIN 대신).

---

### 3.7 `CouponIssueSummationController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponIssueSummationController.java:30`
- Base: `/api/v1/rewards/coupons/issue-summation`
- 의존: `CouponIssueSummationService`, `CouponIssueSummationConverter`

| 메서드 | HTTP | Path | 입력 | 호출 |
|---|---|---|---|---|
| `getAllByTemplateNos` | GET | `""` | `@RequestParam @Size(min=1,max=10000) Set<Integer> templateNos` | `@Cacheable("CouponIssueSummationService.getAllByTemplateNos")` → JPA `findAllById(templateNos)` |

**엔티티** `CouponIssueSummation` (`domain/CouponIssueSummation.java`):
- `@Id Integer templateNo`
- `Integer qty`
- `Date updated`

**관측**: 본 repo에서는 이 테이블에 대한 INSERT/UPDATE/DELETE 구문을 관측할 수 없다. JPA 어노테이션도 `@Entity` + `@Id` 만 있고 setter/쓰기 경로 없음. 외부(배치·트리거)에서 채워지는 **읽기 전용 비정규화 테이블**로 보이나 본 repo 내 증거는 조회 뿐.
- 사용처 1: 위 API의 조회.
- 사용처 2: MyBatis join (`coupon-summation-mapper.xml` 내 `JOIN CouponIssueSummation CS ON CS.TemplateNo = CT.TemplateNo` / `project-coupon-summary-mapper.xml` 내 동일 join).

---

### 3.8 `CouponTransactionSummationController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/CouponTransactionSummationController.java:26`
- Base: `/api/v1/rewards/coupons/transaction-summation`
- 의존: `CouponTransactionSummationService` + `CouponTransactionSummationDao`

| 메서드 | HTTP | Path | 입력 | 호출 |
|---|---|---|---|---|
| `getSummationQuery` | GET | `""` | `CouponTransactionSummationDto.Search search`, custom `com.wadiz.api.reward.dto.Pageable` | `CouponTransactionSummationService.getSummationQuery` |

**서비스 로직** (`CouponTransactionSummationService.java`):
1. `couponTransactionSummationDao.selectSummationQuery(search, pageable)` 로 페이지 조회.
2. 각 응답에 burnout rate 2종 계산:
   - `burnoutRateByIssueAmount = useAmount / totalIssueAmount * 100` (DecimalFormat `#.##`)
   - `burnoutRateByRedeemAmount = useAmount / redeemAmount * 100`
3. `pageable.size > 0` 이면 `countSummationQuery(search)` 로 total 조회 → `PageImpl`.

**MyBatis SQL — selectSummationQuery** (`coupon-transaction-summation-mapper.xml:28-64`):

```sql
SELECT PS.*,
       CI.Times,
       CI.IssueKey
FROM (<include refid="forPagingSummation"/>) AS PS
LEFT JOIN CouponIssue CI ON PS.TemplateNo = CI.TemplateNo
ORDER BY PS.TemplateNo DESC, CI.Times

<!-- forPagingSummation -->
SELECT CTS.*,
       CTR.DepartmentName,
       CT.RegisterUserId, CT.CouponName, CT.IssueTargetType,
       CT.DiscountType, CT.DiscountAmount, CT.DiscountRate,
       CT.IssueType, CT.Registered, CT.EffectedFrom, CT.EffectedTo,
       CT.ExpirationType, CT.ExpirationDate, CT.ExpirationPeriod,
       CT.TotalLimitQty, CT.TargetConditionType,
       (CASE WHEN CT.DiscountType = 'FIXED_AMOUNT'
             THEN CT.DiscountAmount * CT.TotalLimitQty ELSE NULL END) AS TotalIssueAmount
FROM (<include refid="sumCouponTransactionSummationTable"/>) AS CTS
INNER JOIN CouponTemplate CT ON CTS.TemplateNo = CT.TemplateNo
LEFT JOIN CouponTemplateResponsibility CTR on CT.TemplateNo = CTR.TemplateNo
<include refid="whereClauseByManagementDepartmentCode"/>
ORDER BY CTS.TemplateNo DESC
<if test="pageable != null and pageable.size > 0">
    LIMIT #{pageable.offset}, #{pageable.size}
</if>

<!-- sumCouponTransactionSummationTable -->
SELECT TemplateNo,
       SUM(RedeemQty) RedeemQty, SUM(RedeemCancelQty) RedeemCancelQty,
       SUM(RedeemAmount) RedeemAmount, SUM(RedeemCancelAmount) RedeemCancelAmount,
       SUM(UseQty) UseQty, SUM(UseCancelQty) UseCancelQty,
       SUM(UseAmount) UseAmount, SUM(UseCancelAmount) UseCancelAmount,
       SUM(RefundQty) RefundQty, SUM(RefundCancelQty) RefundCancelQty,
       SUM(RefundAmount) RefundAmount, SUM(RefundCancelAmount) RefundCancelAmount,
       SUM(WithdrawQty) WithdrawQty, SUM(WithdrawCancelQty) WithdrawCancelQty,
       SUM(WithdrawAmount) WithdrawAmount, SUM(WithdrawCancelAmount) WithdrawCancelAmount,
       SUM(FundingAmount) FundingAmount
FROM CouponTransactionSummation
<where>
  <include refid="clauseByTransactionDate"/>  -- TransactionDate >= start, <= end
  <include refid="clauseByTemplateNumbers"/>   -- TemplateNo IN (...)
</where>
GROUP BY TemplateNo
```

필터 `managementDepartmentCode` 처리 특이사항: 빈 문자열이면 `IS NULL`, 아니면 `= #{code}` (NULL 부서 전용 조회 지원).

```sql
<!-- whereClauseByManagementDepartmentCode -->
<where>
    <if test="search != null and search.managementDepartmentCode != null">
        <choose>
            <when test="!search.managementDepartmentCode.isEmpty()">
                AND CT.ManagementDepartmentCode = #{search.managementDepartmentCode}
            </when>
            <otherwise>
                AND CT.ManagementDepartmentCode IS NULL
            </otherwise>
        </choose>
    </if>
</where>
```

> **주의**: 위 SQL은 `CT.ManagementDepartmentCode` 를 사용. 본 repo `CouponTemplate.java` 에는 해당 필드가 엔티티에 선언되어 있지 않다. `CouponTemplateResponsibility` 에 `departmentCode` 가 있는데 SQL은 `CouponTemplate` 의 컬럼을 조회. 물리 테이블에 해당 컬럼이 존재한다고 가정해야 하며, 본 repo 코드만으로는 상세 매핑 근거가 없다. (기록 불가 영역)

**countSummationQuery** (`coupon-transaction-summation-mapper.xml:16-26`):
```sql
SELECT COUNT(CTS.TemplateNo)
FROM (
    SELECT TemplateNo
    FROM CouponTransactionSummation
    <include refid="whereClauseByTransactionDate"/>
    GROUP BY TemplateNo
) AS CTS
LEFT JOIN CouponTemplate CT ON CTS.TemplateNo = CT.TemplateNo
<include refid="whereClauseByManagementDepartmentCode"/>
```

---

### 3.9 `ProjectCouponSummaryController`

- 파일: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/ProjectCouponSummaryController.java:20`
- Base: `/api/v1/rewards/coupons/projects`
- 의존: `ProjectCouponSummaryService`

| 메서드 | HTTP | Path | 입력 | 흐름 |
|---|---|---|---|---|
| `getProjectCouponList` | GET | `""` | `ProjectCouponSummaryDto.Search search` | i18n locale 판정 (ko/en 외 영어로 폴백) → `projectCouponSummaryDao.selectProjectCouponList(projectNo, targetType, languageCode)` + 전체 다운로드쿠폰 merge + `excludeRedeemedByUserId` 후처리. |
| `getProjectOnlyCouponList` | GET | `/{projectNo}` | `CouponTargetType targetType` | `selectProjectCouponList(projectNo, targetType, languageCode)` 만. |

**서비스 merge 로직** (`ProjectCouponSummaryService.java:59-72`):
- 전역 다운로드 쿠폰은 `CouponTemplate` 을 `CouponTemplateSpecificationBuilder` 로 조회:
  - `targetConditionType = ALL` (FUNDING 타겟) 또는 `STORE_ALL` (STORE 타겟)
  - `onlyEffectedDate = true`
  - `onlyEffectedQty = true`
  - `issueType = DOWNLOAD`
- 결과를 `ProjectCouponSummaryConverter.toResponse(template, projectNo, languageCode)` 로 매핑하여 merge.

**MyBatis SQL — selectProjectCouponList** (`project-coupon-summary-mapper.xml:125-145`):

```sql
SELECT PS.ProjectNo,
       PS.TemplateNo AS CouponTemplateNo,
       PS.TargetType AS CouponTargetType,
       IFNULL(CL.CouponName, PS.CouponName) AS CouponName,
       PS.DiscountType, PS.DiscountAmount, PS.DiscountRate,
       PS.MinFundingAmount, PS.MaxDiscountAmount, PS.LimitQtyPerUser,
       PS.IssueKey, PS.EventKeyword, PS.EventTargetType, PS.UpdatedAt
FROM ProjectCouponSummary PS
LEFT JOIN CouponTemplateLanguage CL ON PS.TemplateNo = CL.TemplateNo AND CL.LanguageCode = #{languageCode}
WHERE PS.ProjectNo = #{projectNo}
  AND PS.TargetType = #{targetType}
  AND PS.EffectedFrom <= NOW() AND PS.EffectedTo >= NOW()
```

---

## 4. DB 스키마 요약 (관측 가능한 범위)

> 본 섹션 컬럼명은 JPA 엔티티와 MyBatis SQL 에서 관측된 이름을 혼합. MySQL naming은 PascalCase(쿼리에서 확인). JPA는 기본 camelCase→PascalCase 매핑이 아니므로 Hibernate `PhysicalNamingStrategy` 가 설정되어 있을 것(구체는 `config/` 확인 필요 — 본 문서 범위 외).

### 4.1 `Coupon` (`domain/Coupon.java`)
| 컬럼 | 타입 | 제약 |
|---|---|---|
| CouponSeq | int PK, IDENTITY | |
| CouponKey | BINARY(16) UNIQUE | UUID |
| TemplateNo | FK → CouponTemplate.TemplateNo | FK_Coupon_TemplateNo, NOT NULL |
| IssueKey | FK → CouponIssue.IssueKey | FK_Coupon_IssueKey, NOT NULL |
| CouponCode | FK → CouponCode.CouponCode | FK_Coupon_CouponCode (nullable) |
| EffectedUntil | Date | NOT NULL |
| IsUsed | bit | default 0 NOT NULL |
| UsedDate | Date | nullable |
| OwnerUserId | int | NOT NULL |
| Registered/Updated | Date | AbstractDateAuditingEntity 상속 |
| Index | `IDX_Coupon__EffectedUntil_IsUsed_OwnerUserId_TemplateNo` | MyBatis `USE INDEX` 힌트로 확인 |

### 4.2 `CouponTemplate` (`domain/CouponTemplate.java`)
| 컬럼 | 타입 | 비고 |
|---|---|---|
| TemplateNo | int PK, IDENTITY | |
| CouponName | String NOT NULL | |
| DiscountType | Enum(STRING) NOT NULL | `FIXED_AMOUNT`/`FIXED_RATE` (코드에서 관측) |
| DiscountAmount / DiscountRate / MaxDiscountAmount | int | |
| IssueType | Enum(STRING) NOT NULL | `DIRECT_ISSUE`/`DOWNLOAD`/`COUPON_CODE`/`API_ISSUE` (SUM SQL에서 관측) |
| EffectedFrom / EffectedTo | Date NOT NULL | |
| ExpirationType | Enum(STRING) NOT NULL | `DATE`/`PERIOD`/`DEFINE_WHEN_ISSUED` (코드에서 관측) |
| ExpirationDate | Date | |
| ExpirationPeriod | int | 일수 |
| LimitQtyPerUser / TotalLimitQty | int NOT NULL | |
| MinFundingAmount | int (default 0) | |
| DeviceConditionType | Enum(STRING) NOT NULL | |
| TargetConditionType | Enum(STRING) NOT NULL | `PROJECT`/`COLLECTION`/`ALL`/`STORE_ALL` (코드+SQL 관측) |
| IssueTargetType | Enum(STRING) NOT NULL | `ALL` 외 관측 |
| IsNotificationAllowed | bool NOT NULL | |
| CostBearer | Enum(STRING, length 100) NOT NULL | `MAKER` 외 관측 (`@NotAudited`) |
| RegisterUserId / Registered / UpdateUserId / Updated | | `AbstractAuditingEntity` |
| Envers | — | `@Audited(withModifiedFlag=true)` → 별도 `CouponTemplate_AUD` 계열 history 테이블 (Envers 관례, 정확한 DDL은 Envers 설정에 의존) |

관련:
- `CouponTargetConditionMapping` : `@CollectionTable(name="CouponTargetConditionMapping", joinColumns=@JoinColumn(name="templateNo"))`. 컬럼 `TargetConditionKey` (VARCHAR(32)) — 프로젝트ID/컬렉션No 등 문자열 키.
- `CouponTemplateResponsibility` : PK `TemplateNo`, FK 1:1, `DepartmentCode`/`DepartmentName` NOT NULL. `@Audited`.
- `CouponTemplateLanguage` : PK (TemplateNo, LanguageCode), `CouponName` NOT NULL. `@Audited`.

### 4.3 `CouponIssue` (`domain/CouponIssue.java`)
| 컬럼 | 타입 | 비고 |
|---|---|---|
| IssueKey | BINARY(16) PK | Hibernate `uuid2` generator |
| IssueAlias | VARCHAR(32) UNIQUE | |
| TemplateNo | FK NOT NULL | FK_CouponIssue_TemplateNo |
| Times | int, default 1 NOT NULL | Unique (TemplateNo, Times) — `UK_CouponIssue__TemplateNo_Times` |
| ToBeIssueQty | int | COUPON_CODE/DIRECT_ISSUE 에서 필수 |
| Purpose | String | |
| PurposeTypeCode | FK → CouponIssuePurposeType | FK_Issue_PurposeType |

### 4.4 `CouponCode` (`domain/CouponCode.java`)
| 컬럼 | 타입 | 비고 |
|---|---|---|
| CouponCode | CHAR(10) PK | 문자 집합: `3-9, A-Y` 제외 `I,O,S,Z` |
| IssueKey | FK | FK_CouponCode_IssueKey |
| IsRegistered | bit default 0 NOT NULL | |

### 4.5 `CouponTransaction` (`domain/CouponTransaction.java`)
| 컬럼 | 타입 | 비고 |
|---|---|---|
| CouponTransactionSeq | int PK IDENTITY | |
| TransactionKey | BINARY(16) UNIQUE | UUID |
| TemplateNo | int | 비정규화 (조인 최적화) |
| TransactionType | Enum(STRING) NOT NULL | `REDEEM`/`USE`/`REFUND`/`WITHDRAW` |
| TransactionTypeQuality | int (Formula) | `REDEEM→0, WITHDRAW→1, USE→2, REFUND→3` (정렬 용도) |
| CouponKey | FK → Coupon.CouponKey NOT NULL | |
| ApplyAmount | int | USE/REFUND 시 실제 차감액 |
| FundingAmount | int | USE/REFUND 시 funding 금액 |
| UserId | int NOT NULL | |
| IsCanceled | bit default 0 NOT NULL | |
| ReferenceTransactionKey | FK → CouponTransaction.TransactionKey | `REFUND → USE` 참조 체인 |

### 4.6 `CouponIssuePurposeType`
| PurposeTypeCode (PK) | PurposeTypeName NOT NULL | IsUsable bool NOT NULL |

### 4.7 집계 테이블 (§6 참조)
- `CouponIssueSummation(TemplateNo PK, Qty, Updated)`
- `CouponTransactionSummation(TemplateNo+TransactionDate, 18 Qty/Amount 컬럼, AbstractDateAuditingEntity)`
- `ProjectCouponSummary(TemplateNo+ProjectNo+TargetType PK, 10+ 컬럼, UpdatedAt)` + 스왑 테이블 `ProjectCouponSummary_new` / `ProjectCouponSummary_old`

---

## 5. Gateway / DAO 매핑 표

| Controller | 응용 서비스 | Repository / DAO | 구현 종류 |
|---|---|---|---|
| CouponController | CouponService | CouponRepository (`findAll(Specification, Sort)`, `findOneOrElseThrow`, `count`, …) + CouponQueryDao | JPA (Spec) + MyBatis |
| CouponIssueController | CouponIssueService | CouponTemplateRepository, CouponIssueRepository, CouponCodeRepository, CouponIssuePurposeTypeRepository | JPA |
| CouponQueryController | — | CouponQueryDao | MyBatis |
| CouponTemplateController | CouponTemplateService | CouponTemplateRepository, CouponIssueRepository, CouponRepository | JPA (Spec) |
| CouponTransactionController | CouponRedeemService, CouponUseService, CouponRefundService, CouponWithdrawService, CouponTransactionService | CouponRepository, CouponCodeRepository, CouponIssueRepository, CouponTransactionRepository | JPA + Redis (Validator) |
| CouponSummationController | — | CouponSummationDao | MyBatis |
| CouponIssueSummationController | CouponIssueSummationService | CouponIssueSummationRepository (findAllById) | JPA |
| CouponTransactionSummationController | CouponTransactionSummationService | CouponTransactionSummationDao | MyBatis |
| ProjectCouponSummaryController | ProjectCouponSummaryService | ProjectCouponSummaryDao, CouponTemplateRepository, CouponRepository | MyBatis + JPA |

JPA 구현체: `Jpa*Repository.java` (예: `JpaCouponIssueSummationRepository.java`). 본 문서에서는 `CouponIssueSummationRepository` 구현만 열람 — Spring Data 위임형.

---

## 6. 집계(Summation) 전략 비교

| 구분 | 엔드포인트 | 저장 구조 | 갱신 주기 | 본 repo 내 쓰기 경로 |
|---|---|---|---|---|
| **실시간 GROUP BY** | `/summations/templates[/templateNo\|/issues/{issueKey}]` | **없음** (`Coupon`, `CouponTemplate`, `CouponTransaction`, `CouponCode` 원본을 JOIN + SUM) | on-demand (매 요청) | — (읽기 전용) |
| **카운터 비정규화** | `/issue-summation` | `CouponIssueSummation(templateNo PK, qty, updated)` 1행/템플릿 | 외부 (본 repo 미관측) | **미관측** — JPA save 경로 없음. 외부 갱신으로 추정. |
| **일자별 배치 집계** | `/transaction-summation` | `CouponTransactionSummation(templateNo+transactionDate PK, 18 metric)` | 배치 (일 1회 — §8) | `CouponTransactionSummationDao.insertSelectCouponTransactionSummation(targetDate, startDateTime, endDateTime)` (`reward-batch/.../CouponTransactionSummationTasklet.java:29`) — 전일 (D-1) 을 매번 DELETE 후 INSERT SELECT. |
| **스왑테이블 카탈로그** | `/projects`, `/projects/{projectNo}` | `ProjectCouponSummary(templateNo+projectNo+targetType PK)` | 배치 (`ProjectCouponSummaryTasklet`) | `createNewTable()` → `insertDownloadCoupon()` (INSERT SELECT) → `renameSwapTable()` (`_new` 와 본체 swap) → `dropOldTable()` |

**배치 SQL 요약** (`coupon-transaction-summation-mapper.xml:141-180`):

```sql
INSERT INTO wadiz_reward.CouponTransactionSummation (TemplateNo, TransactionDate, RedeemQty, RedeemAmount, ... FundingAmount, ...)
SELECT A.TemplateNo, DATE(#{targetDate}),
       SUM(CASE WHEN CTS.TransactionType = 'REDEEM' THEN 1 ELSE 0 END) AS RedeemQty,
       SUM(CASE WHEN CTS.TransactionType = 'REDEEM' AND CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount ELSE 0 END) AS RedeemAmount,
       SUM(CASE WHEN CTS.TransactionType = 'REDEEM' AND CTS.IsCanceled = TRUE THEN 1 ELSE 0 END) AS RedeemCancelQty,
       ...
FROM (
    SELECT A.TransactionKey, A.TemplateNo
    FROM   wadiz_reward.CouponTransaction A
    WHERE  A.Registered BETWEEN #{startDateTime} AND #{endDateTime}
    AND    A.IsCanceled = FALSE
    UNION ALL
    SELECT A.TransactionKey, A.TemplateNo
    FROM   wadiz_reward.CouponTransaction A
    WHERE  A.Updated BETWEEN #{startDateTime} AND #{endDateTime}
    AND    A.IsCanceled = TRUE
    AND    DATE(A.Registered) != DATE(A.Updated)
) A
JOIN wadiz_reward.CouponTransaction CTS ON CTS.TransactionKey = A.TransactionKey
JOIN wadiz_reward.CouponTemplate CT     ON CT.TemplateNo = A.TemplateNo
GROUP BY A.TemplateNo;

-- delete 쿼리
DELETE FROM wadiz_reward.CouponTransactionSummation WHERE TransactionDate = #{transactionDate}
```

**주목**: UNION ALL 로 "당일 등록된 비-취소 거래" + "당일 취소된(등록일과 다른) 거래" 둘 다 집계 대상에 포함 → 과거 등록 거래를 오늘 취소해도 오늘 TransactionDate 로 재계산됨.

**ProjectCouponSummary 스왑 배치** (`project-coupon-summary-mapper.xml:5-58`):
```sql
CREATE TABLE ProjectCouponSummary_new LIKE ProjectCouponSummary
DROP TABLE IF EXISTS ProjectCouponSummary_new

INSERT INTO ProjectCouponSummary_new (ProjectNo, TemplateNo, TargetType, CouponName, DiscountType, ...)
SELECT CM.TargetConditionKey AS ProjectNo,
       CT.TemplateNo,
       'FUNDING' AS TargetType,
       CT.CouponName, CT.DiscountType, CT.DiscountAmount, CT.DiscountRate,
       CT.MinFundingAmount, CT.MaxDiscountAmount, CT.LimitQtyPerUser,
       CI.IssueKey, CT.EffectedFrom, CT.EffectedTo
FROM CouponTemplate CT
JOIN CouponTargetConditionMapping CM ON CM.TemplateNo = CT.TemplateNo AND CT.TargetConditionType = 'PROJECT'
JOIN CouponIssueSummation CS ON CS.TemplateNo = CT.TemplateNo
JOIN CouponIssue CI ON CI.TemplateNo = CT.TemplateNo AND CI.Times = 1
WHERE CT.IssueType = 'DOWNLOAD'
  AND CT.IssueTargetType = 'ALL'
  AND CT.EffectedFrom <= NOW() + INTERVAL 1 HOUR AND CT.EffectedTo >= NOW()
  AND CT.TotalLimitQty > CS.Qty

RENAME TABLE
    ProjectCouponSummary TO ProjectCouponSummary_old,
    ProjectCouponSummary_new TO ProjectCouponSummary
DROP TABLE IF EXISTS ProjectCouponSummary_old
```

**COLLECTION 변환 경로** (`selectEventCoupon`, 주석처리 — 현재 호출 X):
- `CouponTargetConditionMapping` 의 `TargetConditionKey` 를 `RewardCollectionMapping.CollectionNo` 와 CAST 조인 → `CampaignId` 로 치환.
- `IssueType = 'API_ISSUE'`, `TemplateNo IN (...)` 조건.
- 탱크릿 현재 상태: `ProjectCouponSummaryTasklet.java:40-44` 에서 `// 기획전쿠폰 제외` 주석으로 **비활성** — 즉 현재는 DOWNLOAD 쿠폰만 적재. `selectEventCoupon` / `insertApiIssueEventCoupon` mapper는 살아있지만 호출부가 주석됨.

---

## 7. 외부 의존성

### 7.1 RabbitMQ (관측 가능)
- `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/consumer/CouponTransactionConsumer.java:1-23`
- 큐: `#{saveCouponQueue.name}` (Spring SpEL). 본 repo 내 bean 정의 위치는 별도 확인 필요(본 문서 범위 외 - config 미탐색).
- 조건부 로드: `@ConditionalOnBean(name = "bindSaveCoupon")` — 해당 바인딩이 존재하는 프로파일에서만 활성.
- 처리: `CouponTransactionDto.RedeemByIssue` 메시지를 받아 `CouponRedeemService.redeemByIssue(request, "direct")` 호출.

### 7.2 Redis (관측 가능)
- `support/cache` 및 `RedisTemplate<String,Long> longRedisTemplate`.
- 사용처: `CouponRedeemValidator` — 쿠폰 등록 race condition 방어용 카운터 (§3.5).
- `CouponIssueSummationService` 에 `@Cacheable` 도 존재 (캐시 매니저 구현은 `support/cache` 또는 Hazelcast — `support/hazelcast/` 디렉터리 존재).

### 7.3 외부 HTTP Client (본 9개 controller 경로에서는 호출 없음)
- `support/client/funding/FundingApiClient` — coupon 도메인에서 import 없음 (grep 결과 0 hits).
- `support/client/backoffice/BackOfficeApiClient` — `reward-batch/.../ProjectCouponSummaryTasklet.java:30` 에서만 사용. API 경로 외. (이벤트 쿠폰 수집이 주석처리 되어 현재는 예외 fallback 을 통한 실효 미사용.)
- `support/client/notification/{alimtalk,mail,push}` — 본 컨트롤러 경로에서는 호출 없음.

### 7.4 JPA + Hibernate Envers
- `CouponTemplate`, `CouponTemplateResponsibility`, `CouponTemplateLanguage` 등이 `@Audited`. history 테이블 생성은 Envers 기본 설정 (`_AUD` suffix 가능성 — 설정 파일 범위 외).

### 7.5 외부 jar / 모델
- `com.wadiz.api.reward:reward-models` — `dto.*`, `coupon.constant.*` (Enum: `IssueType`, `DiscountType`, `ExpirationType`, `TargetConditionType`, `CouponTargetType`, `DeviceConditionType`, `IssueTargetType`, `CostBearer`, `TransactionType`, `DeviceType`).
- 본 repo 내에서는 **Enum 값의 모든 값 나열 불가**. 관측된 값만 §4/§5에 기록.

---

## 8. 배치 접점 (도메인 관련 부분)

`reward-batch` 모듈에서 쿠폰 관련 Job/Tasklet:
- `reward-batch/.../transactionsummation/CouponTransactionSummationJobConfig.java` + `CouponTransactionSummationTasklet.java`
  - 실행일 `LocalDate.now().minusDays(1)` (D-1) 을 `deleteAllByTransactionDate` → `insertSelectCouponTransactionSummation(targetDate, 00:00, 23:59:59)` (§6 SQL).
- `.../transactionsummation/CouponTransactionSummationTodayJobConfig.java` + `CouponTransactionSummationTodayTasklet.java`
  - 클래스 존재만 확인 (본문 열람 생략). 당일용 변형 추정.
- `.../projectcouponsummary/ProjectCouponSummaryJobConfig.java` + `ProjectCouponSummaryTasklet.java`
  - createNewTable → insertDownloadCoupon → renameSwapTable → dropOldTable (§6 SQL).
  - `BackOfficeApiClient.getCollectionCoupons()` 호출 경로는 주석 처리.
- `.../couponexpirationnotification/CouponExpirationNotificationJobConfig.java`
  - 본 문서 범위 외 (쿠폰 만료 알림 Job).

스케줄링 트리거 (cron/Scheduled) 는 `reward-batch` 내 JobConfig 또는 외부 스케줄러에서 기동 — 본 문서 범위 외.

---

## 9. 경계 및 미탐색 영역

- **DTO 내부 필드**: `CouponDto.Search`, `CouponDto.Response`, `CouponTemplateDto.Create`, `CouponIssueDto.Create`, `CouponTransactionDto.{RedeemByCouponCode,RedeemByIssue,RedeemByIssueList,BulkRedeemByIssue,Withdraw,Use,Refund}`, `CouponSummationDto.{ByTemplate,ByIssue}`, `CouponIssueSummationDto.Response`, `CouponTransactionSummationDto.{Search,Response}`, `ProjectCouponSummaryDto.{Search,Response,EventCoupon}`, `CouponCodeDto.Response`, `CouponIssuePurposeTypeDto.Response` 의 모든 필드는 외부 `reward-models` jar — 본 repo 에서 관측 불가.
- **Enum 정의**: 위와 동일.
- **`ManagementDepartmentCode` 컬럼 위치**: `coupon-transaction-summation-mapper.xml` 의 SQL은 `CT.ManagementDepartmentCode` 를 참조하지만 `CouponTemplate` 엔티티에 해당 필드가 없음. 물리 테이블엔 존재하지만 JPA 맵핑이 생략된 컬럼으로 추정 (관측 불가).
- **`CouponIssueSummation` 쓰기 경로**: 본 repo 내에서는 `findAllById` 만 보일 뿐 insert/update 관찰 안됨. DB 트리거 또는 타 모듈에서 관리될 가능성 → 증거 없음.
- **Spring Cache 구현체 선택**: `@Cacheable` 사용처 2개 (`CouponIssueService.getIssuePurposeTypes`, `CouponIssueSummationService.getAllByTemplateNos`). 백엔드는 `support/cache`/`support/hazelcast` 중 하나 — 본 문서 범위 외.
- **RabbitMQ 연결·큐/바인딩 Bean 정의**: `saveCouponQueue` / `bindSaveCoupon` 빈 선언 위치 확인 필요 (아마 `config/` 또는 루트 `support/` 하위) — 본 문서 범위 외.
- **외부 호출자 매핑**: 메이커센터 BE/FE, 와디즈 웹이 어느 endpoint 를 호출하는지에 대한 증거는 본 repo 내에 없다. (앞서 추정 수준으로만 기록)
- **보안/인증**: 컨트롤러에 `@PreAuthorize` 또는 헤더 검증 어노테이션 없음. `support/client/InternalAuthorizationInterceptor.java` 가 인터셉터로 존재하지만 적용 범위(URL pattern) 는 config 확인 필요 — 본 문서 범위 외.
- **이벤트 발행**: `@EventListener` / Kafka producer 는 본 coupon 경로에서 관측되지 않음. `CouponIssueService.create` 의 `TransactionSynchronizationManager.registerSynchronization` 후크는 로컬 메서드(`couponCodePublisher.publish`) 호출에 사용될 뿐 외부 브로커 송신 없음.
- **`com.wadiz.api.reward.dto.Pageable`** (custom, `CouponTransactionSummationController` 에서 사용) vs Spring `Pageable` 혼용: 커스텀 Pageable 필드(page, size)만 서비스 로직에서 사용 관측. 정의는 외부 jar.

---

## 10. 요약: 호출 흐름 다이어그램 (텍스트)

```
[Client]
  │
  ▼
/api/v1/rewards/coupons/...                          (9 controllers, 35 endpoints)
  │
  ├─── CouponService ───► CouponRepository (JPA Spec) ─► MySQL: Coupon
  ├─── CouponQueryDao ───► MyBatis: Coupon + CouponTemplate + CouponTemplateLanguage
  │
  ├─── CouponIssueService ─► CouponTemplateRepo / CouponIssueRepo / CouponCodeRepo
  │       │
  │       └─ [afterCommit, @Async] CouponCodePublisher ─► CouponCode (BASE_CHARS 랜덤, 10자)
  │
  ├─── CouponTemplateService ─► CouponTemplateRepo + CouponIssueBuilder + CouponTemplateBuilder
  │       │                       (Envers 자동 history 기록)
  │
  ├─── CouponRedeem/Use/Refund/Withdraw/TransactionService
  │       │
  │       ├─ CouponRedeemValidator ─► Redis INCR (유저/템플릿 per-60s counter)
  │       └─ CouponTransactionBuilder ─► CouponTransaction(REDEEM/USE/REFUND/WITHDRAW)
  │
  ├─── CouponSummationDao ────► MyBatis: JOIN + SUM (on-demand)
  ├─── CouponIssueSummationService ─► JPA findAllById (비정규화 테이블, 외부 갱신)
  ├─── CouponTransactionSummationDao ─► MyBatis: SELECT from `CouponTransactionSummation` (일자별 배치 적재)
  └─── ProjectCouponSummaryDao ─► MyBatis: SELECT from `ProjectCouponSummary` (스왑테이블 배치 재빌드)

[RabbitMQ]
  └─ saveCouponQueue ─► CouponTransactionConsumer ─► CouponRedeemService.redeemByIssue(req,"direct")

[Batch (reward-batch)]
  ├─ CouponTransactionSummationTasklet (D-1) ─► DELETE + INSERT SELECT on CouponTransactionSummation
  └─ ProjectCouponSummaryTasklet ─► createNew → insertSelect → RENAME swap → dropOld
```
