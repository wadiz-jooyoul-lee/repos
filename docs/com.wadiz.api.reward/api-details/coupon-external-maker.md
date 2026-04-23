# 메이커용 외부 쿠폰 API (Braze 연동 · 메이커 부담 쿠폰 템플릿)

> **기록 범위**: `com.wadiz.api.reward` repo 안 `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/external/` 두 컨트롤러와 그 호출 체인(서비스/DAO/MyBatis XML/JPA Specification)에서 직접 관측 가능한 코드만 기록한다.
> - 도메인 DTO (`com.wadiz.api.reward.dto.coupon.*`), 엔티티 Repository, JPA Specification helper(`CouponTemplateSpecification`)와 그 SQL은 외부 jar `com.wadiz.api.reward:reward-models:${reward_models_version}` (build.gradle.kts `gradle/wadiz.gradle:2`)에 있어 이 repo에서 읽을 수 없다 → "외부 모델" 표기.
> - `reward-models` 안 `CouponTemplateDto.Search`/`.Create`/`.ModifyAll`/`.Response`, `CouponTemplateLanguageDto`, `CouponTransactionSummationDto`, `CouponSummationDto` 등 필드는 컨트롤러·컨버터·Validator·Specification Builder에서 실제로 호출되는 getter 기준으로만 나열한다.
> - **Braze 연동**: repo 전체에서 `braze` 라는 문자열은 `MakerCouponController.java:15, 17` 두 줄뿐이다 (`@Tag(name = "부스팅쿠폰 braze API")`, URL prefix `/api/v1/rewards/coupons/makers/braze`). Braze SDK/HTTP 클라이언트/웹훅 서명검증/Braze 전용 설정(YML) 은 이 repo에 존재하지 않는다. 따라서 Braze 와의 통합은 "인바운드 엔드포인트 제공" 수준으로만 관측된다.

---

## 1. 개요

`reward-api/.../rest/coupon/external/` 는 쿠폰 도메인 컨트롤러 중 **repo 외부(제3자/타 서비스)에서 직접 호출하는 API** 를 모아둔 패키지다. 내부 운영/어드민용 컨트롤러는 `rest/coupon/` 바로 아래(`CouponController`, `CouponTemplateController`, `CouponIssueController`, …)에 위치하며, 내부 대비 다음과 같이 분리되어 있다.

| 구분 | 위치 | 베이스 경로 | 호출자(관측) |
|---|---|---|---|
| 내부 | `rest/coupon/*Controller.java` | `/api/v1/rewards/coupons/*` | 사내(어드민/백오피스 등) |
| 외부 (메이커/마케팅) | `rest/coupon/external/Maker*Controller.java` | `/api/v1/rewards/coupons/makers/*` | Braze, 메이커 채널(추정 외부) |

본 문서 대상은 `external/` 패키지의 **컨트롤러 2개** 다:

1. `MakerCouponController` — `/api/v1/rewards/coupons/makers/braze` 하위. Braze(마케팅 자동화 도구) 발송 시 캠페인별 "메이커 부담 부스팅 쿠폰" 목록을 조회하기 위한 인바운드 조회 API. 단일 `GET` 엔드포인트 1개.
2. `MakerCouponTemplateController` — `/api/v1/rewards/coupons/makers/{makerUserId}/templates` 하위. 메이커 본인이 자신의 **부담 쿠폰 템플릿(CostBearer=MAKER)** 을 생성/수정/목록/상세 조회하는 관리 API. 4개 엔드포인트.

**Braze 와 "내부"의 분리 근거 (관측 가능한 것만)**

- `MakerCouponController`는 응답 DTO가 `reward-models` 공용이 아니라 **이 repo 안에 직접 정의된** `com.wadiz.api.reward.coupon.infra.dto.external.MakerCouponDto` (9 필드) 이다(`src/main/java/.../coupon/infra/dto/external/MakerCouponDto.java:13`). 즉 내부 DTO(`CouponTemplateDto.Response`)가 아니라 외부 소비자 맞춤 스키마.
- Mapper XML 도 별도 하위 디렉터리 `mapper/reward/coupon/external/maker-coupon-mapper.xml` 로 분리.
- `MakerCouponTemplateController` 역시 요청 DTO를 외부용(`rest/coupon/external/dto/CreateCouponTemplateRequest.java`, `ModifyCouponTemplateRequest.java`)으로 별도로 만들고, `MakerCouponTemplateDtoConverter` 에서 내부 `CouponTemplateDto.Create`/`ModifyAll` 로 매핑하며 고정값(`CostBearer.MAKER`, `IssueType.DOWNLOAD`, `TargetConditionType.PROJECT`, `ExpirationType.DATE`) 을 주입한다 → **메이커 채널에서 허용되는 쿠폰 형태를 코드로 제한**하기 위한 분리로 관측된다.

---

## 2. 엔드포인트 전수 테이블

| # | Method | Path | 컨트롤러:line | Operation summary | 주 저장소 |
|---|---|---|---|---|---|
| 1 | GET | `/api/v1/rewards/coupons/makers/braze/project` | `MakerCouponController.java:27` | 프로젝트 별 부스팅쿠폰 | MyBatis → MySQL |
| 2 | POST | `/api/v1/rewards/coupons/makers/{makerUserId}/templates` | `MakerCouponTemplateController.java:43` | 메이커 부담 쿠폰 템플릿 생성 | JPA (CouponTemplate, CouponIssue) |
| 3 | PUT | `/api/v1/rewards/coupons/makers/{makerUserId}/templates/{templateNo}` | `MakerCouponTemplateController.java:54` | 메이커 부담 쿠폰 템플릿 수정 | JPA (CouponTemplate, CouponIssue) |
| 4 | GET | `/api/v1/rewards/coupons/makers/{makerUserId}/templates` | `MakerCouponTemplateController.java:66` | 메이커 부담 쿠폰 템플릿 목록 조회 | JPA Specification + MyBatis 집계 |
| 5 | GET | `/api/v1/rewards/coupons/makers/{makerUserId}/templates/{templateNo}` | `MakerCouponTemplateController.java:94` | 메이커 부담 쿠폰 상세 조회 | JPA (CouponTemplateRepository) |

합계 2 컨트롤러 / 5 엔드포인트.

---

## 3. 컨트롤러별 상세

### 3.1 `MakerCouponController` — Braze 인바운드 조회

**파일**: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/external/MakerCouponController.java`
**Base**: `/api/v1/rewards/coupons/makers/braze` (line 17)
**의존**: `MakerCouponDao` (단일)

```java
@Tag(name = "부스팅쿠폰 braze API")
@RestController
@RequestMapping("/api/v1/rewards/coupons/makers/braze")
public class MakerCouponController {
    private final MakerCouponDao makerCouponDao;
    ...
}
```

#### 3.1.1 `GET /project` — 캠페인별 메이커 부담 부스팅 쿠폰 목록

위치: `MakerCouponController.java:27-31`

**Request (query string)**

| 필드 | 타입 | 필수 | Validation | 설명 |
|---|---|---|---|---|
| `campaignId` | `int` | ✅ | 없음 (primitive) | 대상 프로젝트(=campaign) ID |

**Response**

`List<MakerCouponDto>` — 래퍼 없이 배열 반환 (`ResponseWrapper` 미사용).

`MakerCouponDto` 필드 (`src/main/java/.../coupon/infra/dto/external/MakerCouponDto.java:15-28`):

| 필드 | 타입 | 비고 |
|---|---|---|
| `campaignId` | Integer | `CouponTargetConditionMapping.TargetConditionKey` 를 숫자로 해석 |
| `templateNo` | Integer | `CouponTemplate.TemplateNo` |
| `registered` | Date (`yyyy-MM-dd` Asia/Seoul) | 쿠폰 템플릿 등록일 |
| `discountType` | String | `FIXED_RATE` / `FIXED_AMOUNT` (DB raw) |
| `appliedDiscountValue` | Integer | 할인율 또는 할인금액 (SQL CASE) |
| `effectedFrom` | Date (`yyyy-MM-dd`) | 발행 가능 시작 |
| `effectedTo` | Date (`yyyy-MM-dd`) | 발행 가능 종료 |
| `expirationDate` | Date (`yyyy-MM-dd`) | 쿠폰 만료 일자 |
| `totalLimitQty` | Integer | 총 발행 가능 수량 |
| `qty` | Integer | `CouponIssueSummation.Qty` (누적 발행량) |

**컨트롤러 흐름**
1. `@RequestParam int campaignId` 수신
2. `makerCouponDao.getBoostCouponByProjectId(campaignId)` 호출 → List 반환
3. 그대로 body 로 직렬화 (변환/권한검사/로그 어노테이션 없음)

**관측 가능한 DB 호출**

MyBatis: `src/main/resources/mapper/reward/coupon/external/maker-coupon-mapper.xml:5-27`

```xml
<select id="getBoostCouponByProjectId" resultType="com.wadiz.api.reward.coupon.infra.dto.external.MakerCouponDto">
    SELECT
        CM.TargetConditionKey AS CampaignId,
        CT.TemplateNo,
        CT.Registered,
        CT.DiscountType,
        CASE
            WHEN CT.DiscountType = 'FIXED_RATE' THEN CT.DiscountRate
            WHEN CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount
            ELSE 0
        END AS AppliedDiscountValue,
        CT.EffectedFrom,
        CT.EffectedTo,
        CT.ExpirationDate,
        CT.TotalLimitQty,
        CS.Qty
    FROM CouponTemplate CT
    JOIN CouponTargetConditionMapping CM ON CM.TemplateNo = CT.TemplateNo AND CT.TargetConditionType = 'PROJECT'
    JOIN CouponIssueSummation CS ON CS.TemplateNo = CT.TemplateNo
    WHERE CT.IssueType = 'DOWNLOAD'
    AND CT.CostBearer = 'MAKER'
    AND CAST(CM.TargetConditionKey AS UNSIGNED) = #{campaignId};
</select>
```

**필터 고정조건 (SQL)**
- `CouponTemplate.IssueType = 'DOWNLOAD'`
- `CouponTemplate.CostBearer = 'MAKER'`
- `CouponTemplate.TargetConditionType = 'PROJECT'`
- `CAST(CM.TargetConditionKey AS UNSIGNED) = :campaignId` — `TargetConditionKey` 는 VARCHAR 로 추정되어 정수 캐스팅 필요

**DAO 선언**: `src/main/java/.../coupon/infra/dao/external/MakerCouponDao.java:11-18`

```java
@Mapper
@Repository
public interface MakerCouponDao {
    @Transactional(readOnly = true)
    List<MakerCouponDto> getBoostCouponByProjectId(@Param("campaignId") int campaignId);
}
```

---

### 3.2 `MakerCouponTemplateController` — 메이커 채널 쿠폰 템플릿 CRUD

**파일**: `reward-api/src/main/java/com/wadiz/api/reward/rest/coupon/external/MakerCouponTemplateController.java`
**Base**: `/api/v1/rewards/coupons/makers/{makerUserId}/templates` (line 31)

**주입 의존**:
- `CouponTemplateDtoValidator` (`src/main/java/.../coupon/validator/CouponTemplateDtoValidator.java`)
- `CouponTemplateConverter` (`src/main/java/.../coupon/converter/CouponTemplateConverter.java`)
- `CouponTemplateService` (`src/main/java/.../coupon/application/CouponTemplateService.java`)
- `MakerCouponTemplateDtoConverter` (`rest/coupon/external/MakerCouponTemplateDtoConverter.java`)
- `CouponTransactionSummationService` (`src/main/java/.../coupon/application/CouponTransactionSummationService.java`)
- `CouponSummationConverter` (`src/main/java/.../coupon/converter/CouponSummationConverter.java`)

응답은 전부 `ResponseWrapper.success(...)` 로 감싸 반환(Line 50, 62, 83, 100).

#### 3.2.1 `POST /` — 메이커 부담 쿠폰 템플릿 생성

위치: `MakerCouponTemplateController.java:43-52`

**Request Body**: `CreateCouponTemplateRequest` (`rest/coupon/external/dto/CreateCouponTemplateRequest.java`)

| 필드 | 타입 | 필수 | Validation | 설명 |
|---|---|---|---|---|
| `couponName` | String | ✅ | `@NotEmpty @Size(min=1,max=17)` | 쿠폰명 |
| `couponLanguage` | `List<CouponTemplateLanguageDto.Create>` | ⬜ | — | 국가 언어별 쿠폰명 (외부 모델) |
| `discountType` | `DiscountType` (enum) | ✅ | `@NotNull` | `FIXED_AMOUNT` / `FIXED_RATE` |
| `discountAmount` | Integer | 조건부 | `@Min(1)` | 정액 할인 시 필수(Validator) |
| `discountRate` | Integer | 조건부 | `@Min(1) @Max(100)` | 정률 할인 시 필수 |
| `maxDiscountAmount` | Integer | ⬜ | `@Min(1)` | 정액 시 설정 불가 |
| `effectedFrom` | Date | ✅ | `@NotNull`, `yyyy-MM-dd HH:mm:ss` Asia/Seoul | 발행 시작 |
| `effectedTo` | Date | ✅ | `@NotNull` | 발행 종료 (≥ from) |
| `expirationDate` | Date | ⬜ | — | Validator 상 DATE 타입이면 필수 |
| `limitQtyPerUser` | Integer | ✅ | `@NotNull @Min(1)` | 유저당 수령 제한 |
| `totalLimitQty` | Integer | ✅ | `@NotNull @Min(1)` | 총 발행 수량 |
| `minFundingAmount` | Integer | ⬜ | `@Min(1)` | 정액 시 discountAmount 이상 |
| `targetConditionKeys` | `List<String>` | ⬜ | — | PROJECT 타입일 때 프로젝트 ID 목록 |
| `deviceConditionType` | `DeviceConditionType` | ✅ | `@NotNull` | `ALL` / `ONLY_APP` |
| `issueTargetType` | `IssueTargetType` | ⬜ | — | 발행 대상(멤버십 등). `MEMBERSHIP`은 `DEFINE_WHEN_ISSUED` 만 허용(Validator) — 본 컨버터는 `ExpirationType.DATE` 고정이므로 사실상 MEMBERSHIP 불가 |
| `isNotificationAllowed` | Boolean | ✅ | `@NotNull` | 알림 발송 여부 |
| `managementDepartmentCode` | String | ✅ | `@NotEmpty` | 관리 부서 번호 |
| `managementDepartmentName` | String | ✅ | `@NotEmpty` | 관리 부서 이름 |

**컨트롤러 흐름**
1. `MakerCouponTemplateDtoConverter.convert(makerUserId, dto)` → `CouponTemplateDto.Create` 구축
   - 고정 주입 (컨버터 `line 15-43`):
     - `expirationType = ExpirationType.DATE`
     - `expirationPeriod = null`
     - `targetConditionType = TargetConditionType.PROJECT`
     - `issueType = IssueType.DOWNLOAD`
     - `costBearer = CostBearer.MAKER`
     - `registerUserId = makerUserId`, `updateUserId = makerUserId`
2. `couponTemplateDtoValidator.validate(request, errors)` — 위반 시 `NotValidException` throw
   - `validTargetCondition` / `validDiscount` / `validEffectedDate` / `validExpiration` / `validMaxDiscountAmount` / `validMinFundingAmount` / `validIssueTargetType`
3. `couponTemplateService.create(request)` (`CouponTemplateService.java:47-58`)
   - `couponTemplateBuilder.buildTemplate(request)` → `CouponTemplate` 엔티티 구축 (외부 builder)
   - `couponTemplateRepository.save(couponTemplate)` (외부 Repository → JPA, 관측 불가)
   - `createdCouponTemplate.shouldIssueImmediately()` 가 true 면 `couponIssueBuilder.buildDefaultFirstIssue(...)` → `CouponIssue` 추가 및 저장
4. `couponTemplateConverter.toResponse(...)` → 응답 DTO 변환 (`CouponTemplateConverter.java:31-42`)
   - `exposeCouponName`: `LocaleContextHolder` 언어가 `ko` 가 아니면 영어 `CouponLanguage` 로 폴백
   - `targetConditionMappings → targetConditionKeys` 평탄화
   - `couponIssues → issues` 변환

**관측 가능한 DB/외부호출**
- JPA: `CouponTemplateRepository.save(...)` (외부 jar — SQL 확인 불가)
- JPA: `CouponIssueRepository.save(...)` (외부 jar)
- 도메인 엔티티: `CouponTemplate` (`src/main/java/.../coupon/domain/CouponTemplate.java:28` `@Entity`, `@Audited` — Envers 사용 → `CouponTemplate_AUD` 테이블 자동 생성)
- **Braze 호출 없음**.

#### 3.2.2 `PUT /{templateNo}` — 메이커 부담 쿠폰 템플릿 수정

위치: `MakerCouponTemplateController.java:54-64`

**Request Body**: `ModifyCouponTemplateRequest` (`rest/coupon/external/dto/ModifyCouponTemplateRequest.java`)

Create 요청 대비 차이:
- `templateNo` 필드 존재하지만 컨트롤러 `@PathVariable` 이 우선 사용됨
- `managementDepartmentCode/Name` 없음 (수정 불가)
- `issueTargetType` 수정 가능 여부는 converter 에서 제외 → 실 반영 안 됨

컨버터 (`MakerCouponTemplateDtoConverter.java:45-63`) 출력 `CouponTemplateDto.ModifyAll` 고정 주입:
- `targetConditionType = TargetConditionType.PROJECT`
- `updateUserId = makerUserId`
- `couponName`, `couponLanguage`, `discountType`, `discountAmount`, `discountRate`, `maxDiscountAmount`, `minFundingAmount`, `expirationDate`, `isNotificationAllowed`, `effectedFrom`, `effectedTo`, `totalLimitQty`, `targetConditionKeys` 만 전달.

**컨트롤러 흐름**
1. converter 로 `CouponTemplateDto.ModifyAll` 생성
2. `couponTemplateDtoValidator.validate(request, errors)` (ModifyAll 버전, `Validator.java:41-52`)
   - `validExpiration` 은 `ExpirationType.DATE`, `IssueType.DOWNLOAD` 고정 전달(`Validator.java:185-190`)
3. `couponTemplateService.modifyAll(templateNo, request)` (`CouponTemplateService.java:74-84`)
   - `couponTemplateRepository.findOneOrElseThrow(templateNo)` (외부)
   - `couponTemplateValidator.validate(currentCouponTemplate, request)` (외부 — 리얼 도메인 정책 재검증)
   - `couponTemplateBuilder.build(current, request)` (외부)
   - `couponTemplateRepository.save(couponTemplate)` (외부)
   - `couponIssueRepository.save(modifiedCouponTemplate.getCouponIssues())` (외부)
4. `couponTemplateConverter.toResponse(...)` → 응답

#### 3.2.3 `GET /` — 메이커 부담 쿠폰 템플릿 목록 + 집계

위치: `MakerCouponTemplateController.java:66-84`

**Query Parameters**: `CouponTemplateDto.Search` (외부 모델 — 컨트롤러에서 `@ModelAttribute @Valid`). Specification Builder(`MakerCouponTemplateSpecificationBuilder.java:25-85`)에서 참조되는 getter 로 관측 가능한 항목:

| 필드 | 효과 |
|---|---|
| `issueType` | `CouponTemplateSpecification.equalIssueType(...)` |
| `searchDateItem` (`REGISTERED`/`EFFECTED_FROM`/`EFFECTED_TO`/`EXPIRATION_DATE`) + `searchStartDate`/`searchEndDate` | between 조건 |
| `couponName` | likeCouponName |
| `templateNo` | equalTemplateNo |
| `templateNos` | inTemplateNos |
| `onlyEffectedDate` | isEffectedDate |
| `onlyEffectedQty` | isEffectedQty |
| `targetConditionType` | equalTargetConditionType |
| `issueTargetType` | equalIssueTargetType |
| `isNotificationAllowed` | equalIsNotificationAllowed |
| `targetConditions` | inTargetCondition |
| `excludeRedeemedByUserId` | 후처리 필터 (`CouponTemplateService.java:112-116,135-140`) |

**고정 조건 (makerUserId 기반, SpecificationBuilder 28-29):**
- `CouponTemplateSpecification.registerBy(makerUserId)`
- `CouponTemplateSpecification.equalCostBearerType(CostBearer.MAKER)`

`Pageable` 은 Spring Data `@ParameterObject` 로 수신.

**Response**: `ResponseWrapper<Page<CouponTemplateWithSummationResponse>>`

`CouponTemplateWithSummationResponse` (`rest/coupon/external/dto/CouponTemplateWithSummationResponse.java:15-28`):
- `couponTemplate`: `CouponTemplateDto.Response` (외부 모델)
- `summation`: `CouponSummationDto.ByTemplate` (외부 모델) — `templateNo`, `useAmount`, `useQty`, `redeemAmount`, `redeemQty`, `expireAmount`, `expireQty`, `fundingAmount`, `refundAmount`, `refundQty` (`CouponSummationConverter.java:18-46` 에서 빌더로 구성)

**컨트롤러 흐름 (line 66-84)**
1. `couponTemplateService.getAllMakerCouponTemplate(makerUserId, search, pageable)` (`CouponTemplateService.java:102-119`)
   - `MakerCouponTemplateSpecificationBuilder` 로 `Specification<CouponTemplate>` 생성
   - `couponTemplateRepository.findAll(specs, pageable)` → `Page<CouponTemplate>` (외부 JPA)
   - `search.getExcludeRedeemedByUserId()` 가 있으면 `couponRepository.countAllByOwnerUserIdAndCouponTemplate(...)` 로 사후 필터링 후 `new PageImpl<>(...)` 재구성
2. 페이지 내용의 `templateNo` 만 뽑아 `List<Integer>` 생성
3. `getSummations(templateNumbers)` (private, line 86-92):
   - `CouponTransactionSummationDto.Search` 에 `templateNumbers` 만 설정 (`managementDepartmentCode`, `transactionStartDate/End` 미지정)
   - `new com.wadiz.api.reward.dto.Pageable(0, 0)` — **size=0** 으로 전달 → 서비스는 "페이지 미적용" 분기 사용
   - `couponTransactionSummationService.getSummationQuery(query, page)`
4. 각 템플릿별로 `couponSummationConverter.convert(templateNo, summation or null)` — 집계 없으면 0-초기값(`CouponSummationConverter.init`)
5. `ResponseWrapper.success(responses)` 반환

**관측 가능한 DB 호출 (집계)**

`CouponTransactionSummationService.getSummationQuery` (`.../application/CouponTransactionSummationService.java:24-31`)는 내부적으로 `CouponTransactionSummationDao` 를 호출한다. 본 컨트롤러 경로(page.size == 0)에서는 `getSummationQueryWithoutPage` 가 실행되고 (`line 38-40`), `countSummationQuery` 는 호출되지 않는다 — 즉 `SELECT COUNT(...)` 쿼리는 생략.

MyBatis: `src/main/resources/mapper/reward/coupon/coupon-transaction-summation-mapper.xml:28-35` (실제 실행되는 select)

```xml
<select id="selectSummationQuery" resultMap="couponTransactionSummationResult">
    SELECT PS.*,
           CI.Times,
           CI.IssueKey
    FROM (<include refid="forPagingSummation"/>) AS PS
    LEFT JOIN CouponIssue CI ON PS.TemplateNo = CI.TemplateNo
    ORDER BY PS.TemplateNo DESC, CI.Times
</select>
```

내부 `forPagingSummation` sql fragment (`coupon-transaction-summation-mapper.xml:37-64`):

```xml
<sql id ="forPagingSummation">
    SELECT CTS.*,
    CTR.DepartmentName,
    CT.RegisterUserId,
    CT.CouponName,
    CT.IssueTargetType,
    CT.DiscountType,
    CT.DiscountAmount,
    CT.DiscountRate,
    CT.IssueType,
    CT.Registered,
    CT.EffectedFrom,
    CT.EffectedTo,
    CT.ExpirationType,
    CT.ExpirationDate,
    CT.ExpirationPeriod,
    CT.TotalLimitQty,
    CT.TargetConditionType,
    (CASE WHEN CT.DiscountType = 'FIXED_AMOUNT' THEN CT.DiscountAmount * CT.TotalLimitQty ELSE NULL END) AS TotalIssueAmount
    FROM (<include refid="sumCouponTransactionSummationTable"/>) AS CTS
    INNER JOIN CouponTemplate CT ON CTS.TemplateNo = CT.TemplateNo
    LEFT JOIN CouponTemplateResponsibility CTR on CT.TemplateNo = CTR.TemplateNo
    <include refid="whereClauseByManagementDepartmentCode"/>
    ORDER BY CTS.TemplateNo DESC
    <if test="pageable != null and pageable.size > 0">
        LIMIT #{pageable.offset}, #{pageable.size}
    </if>
</sql>
```

집계 서브쿼리 `sumCouponTransactionSummationTable` (`coupon-transaction-summation-mapper.xml:66-91`) — TemplateNo 별 `SUM(RedeemQty), SUM(RedeemAmount), SUM(UseQty), SUM(UseAmount), SUM(RefundQty), SUM(RefundAmount), SUM(WithdrawQty), SUM(WithdrawAmount), SUM(FundingAmount), ...` 집계하고 `clauseByTemplateNumbers` 로 이 컨트롤러가 넘긴 templateNo IN (...) 조건 걸림 (line 108-119).

서비스 후처리 (`CouponTransactionSummationService.java:44-48`): `burnoutRateByIssueAmount`, `burnoutRateByRedeemAmount` 를 `DecimalFormat("#.##")` 로 계산해 설정.

#### 3.2.4 `GET /{templateNo}` — 메이커 부담 쿠폰 상세

위치: `MakerCouponTemplateController.java:94-101`

**Request**: `@PathVariable Integer makerUserId`, `@PathVariable Integer templateNo`

**주의**: 컨트롤러는 `couponTemplateService.get(templateNo)` 만 호출하며 (`CouponTemplateService.java:42-44` → `couponTemplateRepository.findOneOrElseThrow(templateNo)`), **`makerUserId` 에 의한 소유권 검증은 관측되지 않는다** (코드상 비교 없음). 상위 인증/라우팅 단에서 걸러진다고 가정되어야 하나 이 repo 내에서는 확인 불가.

**Response**: `ResponseWrapper<CouponTemplateDto.Response>` — `CouponTemplateConverter.toResponse(...)` 경유.

---

## 4. Braze 연동 패턴 (관측 가능한 범위)

**요약: 이 repo 는 Braze 의 "조회 콜백 수신자" 역할만 한다. Braze 로의 outbound 호출 코드는 존재하지 않는다.**

| 항목 | 관측 결과 | 근거 |
|---|---|---|
| URL 분리 | `/api/v1/rewards/coupons/makers/braze` 전용 prefix | `MakerCouponController.java:17` |
| Swagger 태그 | `부스팅쿠폰 braze API` | `MakerCouponController.java:15` |
| 인증/권한 | `@PreAuthorize`/`@Secured`/기타 필터 어노테이션 **없음** (컨트롤러 파일 32줄 전체 확인) | `MakerCouponController.java` 전체 |
| 인증 헤더 검증 | 수동 `HttpServletRequest`/토큰/HMAC 검증 로직 **없음** | 동 |
| Braze API key / Braze endpoint 설정 | application*.yml 및 전체 repo 에서 `braze` 문자열 2 건(컨트롤러 내부)뿐 | Grep `-i braze` 결과 |
| Braze SDK / 전용 WebClient/RestTemplate | 없음 (`WebClient|RestTemplate|FeignClient` grep 결과 `rest/coupon` 전체 0 건) | Grep 결과 |
| Webhook 서명/멱등 처리 | 없음 | 동 |
| 외부로의 통신 | 없음 — 내부 MySQL 조회만 수행 | `MakerCouponDao` + mapper |

**해석 (관측 기반)**: Braze 가 고객 세그먼트에게 "캠페인 XXX 쿠폰 발행됨" 메시지를 발송할 때, Braze Connected Content 등으로 이 엔드포인트를 호출해 해당 캠페인의 메이커 부담 부스팅 쿠폰 목록/할인가/종료일 등을 끌어다 쓰는 용도로 추정된다. 그러나 Braze 호출이 맞는지, 인증을 어디서 보완하는지는 이 repo 안에서는 단정 불가 → "미탐색 영역"에 기록.

**실패 처리**: 예외 어드바이스는 컨트롤러 내부에 없음. 공통 `@ControllerAdvice` 또는 `ResponseWrapper` 에러 경로는 본 문서 범위 밖(다른 도메인 문서 참조).

---

## 5. DB 테이블 (관측 가능한 것)

MyBatis XML (이 repo 관측 가능) 및 JPA 엔티티(`CouponTemplate.java` 확인 가능) 기준.

| 테이블 | 경로/용도 | 문서 내 용처 |
|---|---|---|
| `CouponTemplate` | 쿠폰 템플릿 본체(JPA `@Entity` + Envers 감사 `@Audited` → `CouponTemplate_AUD` 자동 생성) | GET /braze/project (JOIN), 모든 `Template` 엔드포인트 |
| `CouponTargetConditionMapping` | 쿠폰 템플릿 ↔ 적용 대상 키 매핑 (프로젝트ID 저장) | GET /braze/project JOIN `mapper:22` |
| `CouponIssueSummation` | 템플릿별 누적 발행량(`Qty`) | GET /braze/project JOIN `mapper:23` |
| `CouponIssue` | 쿠폰 발행 회차 | POST/PUT/GET 목록 (JPA save) |
| `CouponTransactionSummation` | 일자별 템플릿 트랜잭션 집계 | GET /templates 목록 — `selectSummationQuery` |
| `CouponTransaction` | 원천 트랜잭션 | 본 컨트롤러에서 직접 조회 없음, 배치 적재 경로에서만 사용(본 문서 범위 밖) |
| `CouponTemplateResponsibility` | 템플릿 관리 부서(`DepartmentName` 등) | 집계 select LEFT JOIN `mapper:58` |

**`CouponTemplate` 에서 본 컨트롤러 체인이 읽고/쓰는 컬럼 (JPA 엔티티 필드 기준, `CouponTemplate.java:31-80`)**:
`TemplateNo`, `CouponName`, `DiscountType`, `DiscountAmount`, `DiscountRate`, `MaxDiscountAmount`, `IssueType`, `EffectedFrom`, `EffectedTo`, `ExpirationType`, `ExpirationDate`, `ExpirationPeriod`, `LimitQtyPerUser`, `TotalLimitQty`, `MinFundingAmount`, `DeviceConditionType`, (외부 모델의 `CostBearer`, `TargetConditionType`, `IssueTargetType`, `IsNotificationAllowed`, `RegisterUserId`, `UpdateUserId`, `ManagementDepartmentCode/Name` 등 — 부분 관측).

---

## 6. 외부 의존성

| 대상 | 이 repo 에서 보이는 형태 | 실체 위치(이 repo 밖) |
|---|---|---|
| `com.wadiz.api.reward.dto.coupon.*` (CouponTemplateDto, CouponTransactionSummationDto, CouponSummationDto, CouponIssueDto, CouponTemplateLanguageDto, CouponDto) | import 만 | `reward-models` jar (`gradle/wadiz.gradle:2`) |
| `com.wadiz.api.reward.coupon.infra.repository.CouponTemplateRepository / CouponIssueRepository / CouponRepository` | 주입만 | 외부 jar 추정 — 이 repo 내 파일 없음 |
| `com.wadiz.api.reward.coupon.domain.service.CouponTemplateBuilder / CouponIssueBuilder` | 주입만 | 외부 jar |
| `com.wadiz.api.reward.coupon.validator.CouponTemplateValidator` (Dto 가 아닌 도메인 Validator) | 주입만 (Dto Validator 와 별개 — `CouponTemplateService.java:39`) | 외부 jar |
| `com.wadiz.api.reward.coupon.infra.repository.specification.CouponTemplateSpecification` | `MakerCouponTemplateSpecificationBuilder.java` 에서 static 호출 | 외부 jar — 메서드명만 관측 |
| Braze | URL prefix + Swagger Tag 이외 통합 코드 없음 | 외부 서비스 |
| `ResponseWrapper`, `AbstractSpecificationBuilder`, `NotValidException` | 이 repo 안 (`coupon.support` / `support`) | 동일 repo |
| MySQL | MyBatis XML 2개 (`external/maker-coupon-mapper.xml`, `coupon-transaction-summation-mapper.xml`) | DB |

---

## 7. 경계 및 미탐색 영역

1. **Braze 실제 호출 주체**: Braze Connected Content 인지, 중간 BFF(예: `app-api`)가 프록시하는지 이 repo 안에서는 확인 불가. 다만 엔드포인트가 Swagger 에 `braze` 로 태깅되어 있고 응답 DTO 가 별도 분리된 간단 스키마라는 점은 "외부 제3자 직접 호출용" 가설과 일관.
2. **인증/권한**: `MakerCouponController`, `MakerCouponTemplateController` 두 컨트롤러 모두 메서드 레벨 권한 어노테이션 없음. 실제 보호는 `SecurityConfig`(이 repo 안에 미탐색, 별도 도메인 문서 영역), API Gateway, 또는 사내 L7/ACL 중 어디서 일어나는지 단정 불가.
3. **소유권 검증**: `GET/PUT /makers/{makerUserId}/templates/{templateNo}` 에서 `makerUserId` 와 `CouponTemplate.registerUserId` 의 매칭 검증이 컨트롤러/서비스 레벨에서 **관측되지 않는다** (GET 상세는 단순 `findOneOrElseThrow`, PUT 은 core jar 내부 Validator 에 맡김). core jar 내부에서 처리할 가능성 있으나 확인 불가.
4. **`CouponTemplateValidator` vs `CouponTemplateDtoValidator`**: 후자는 이 repo 에 있으나(`validator/CouponTemplateDtoValidator.java`), 전자는 외부 jar 에 있어(동일 패키지 하위) 실제 도메인 검증 룰은 확인 불가.
5. **`shouldIssueImmediately()` 분기**: `CouponTemplate` 엔티티 메서드 `shouldIssueImmediately()` 는 외부 모델/도메인 로직에 의존하므로 MAKER/DOWNLOAD 조합에서 true/false 여부는 이 repo 만으로 판정 불가.
6. **Braze 호출 실패 처리**: outbound 호출이 없으므로 재시도/서킷브레이커/DLQ 모두 해당 없음. 반대로 Braze 가 호출에 실패해도(= 4xx/5xx 응답) 이 서비스는 단순 조회 실패이므로 상태가 오염되지 않는다.
7. **`MakerCouponDto.qty`**: `CouponIssueSummation.Qty` 로 매핑되나 이 컬럼이 "발행된 수량"인지 "잔여 수량"인지는 SQL 만으로 단정 불가.
8. **`TargetConditionKey` 타입**: `CAST(... AS UNSIGNED)` 사용으로 미뤄 VARCHAR 로 저장되며 프로젝트 ID 아닌 다른 타입(예: 카테고리 코드)도 들어갈 수 있어 보이지만, 본 엔드포인트는 `CT.TargetConditionType = 'PROJECT'` 필터로 숫자 캐스팅 전제 충족.

---

## 8. 요약 표 (엔드포인트 ↔ 저장소/외부)

| Endpoint | JPA Save | MyBatis Select | Redis/Mongo/Kafka | 외부 HTTP |
|---|---|---|---|---|
| GET /braze/project | — | `MakerCouponDao.getBoostCouponByProjectId` | — | — |
| POST /templates | CouponTemplate, CouponIssue(조건부) | — | — | — |
| PUT /templates/{no} | CouponTemplate, CouponIssue(s) | — | — | — |
| GET /templates | — (Specification findAll) | `CouponTransactionSummationDao.selectSummationQuery` | — | — |
| GET /templates/{no} | — (findOneOrElseThrow) | — | — | — |

Redis/Mongo/Kafka/외부 HTTP 호출은 이 두 컨트롤러의 호출 체인에서 관측되지 않는다.
