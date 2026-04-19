# Settlement API 상세 스펙

정산(수수료·정산내역서·요금제·미수금) 관련 24개 엔드포인트. 외부 **ERP 시스템**(Douzone)과의 연동이 핵심.

- **대상 컨트롤러**:
  - `SettlementStudioController` (`/api/studio/campaigns/{campaignId}`) — 7개, `@PreAuthorize("isMaker or isAdmin")`
  - `SettlementInternalController` (`/api/internal/settlement`) — 11개
  - `SettlementAdminController` (`/api/admin/settlement`) — 6개, `@PreAuthorize("isAdmin()")`
  - `StudioPricingController` (`/api/studio/pricing`) — 3개
  - `OutstandingAdmController` (`/api/admin/outstandings`) — 1개, `@PreAuthorize("isAdmin()")`

- **저장소 / 외부 연동**:
  - MySQL: `RewardSettlementRate`, `RewardSettlement`, `CampaignPackagePlan`, `SettlementSystem`, `CampaignAdditionalService`, `CampaignPackagePlanHistory`
  - **ERP** (외부 API, Douzone 기반): 수수료·정산진행/결과·정산내역서·광고비용·수수료 버전·정산금액
  - **Spring Data JDBC** Repository + **MyBatis** Mapper 혼용

> **기록 범위**: 이 레포의 Controller/Proxy/Gateway/Mapper XML 에서 직접 관찰 가능한 호출만 기록. UseCase 구현체(`CampaignSettlementStatusUseCase`, `ErpSettlementUseCase`, `StatementUsecase`, `OutstandingUsecase`, `StudioPricingUsecase` 등)는 외부 jar(`funding-core`)에 있어 Usecase 내부 호출 순서/분기는 확인 불가. **단 ErpSettlementGatewayImpl이 이 레포에 존재**하므로 ERP API 요청 구조는 관찰 가능.

---

## 1. GET `/api/studio/campaigns/{campaignId}/settlement` — 프로젝트 정산 진행 상태 (Studio)

- **Method**: `SettlementStudioController.getCampaignSettlementStatus`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`
- **Cache**: `@Cacheable(cacheNames="settlement", key="'campaingSettlementStatus: '+#campaignId")`

### Response — `CampaignSettlementStatusResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `status` | `String` | 정산 진행 상태 |
| `updated` | `LocalDateTime` | 최근 변경 일자 |

### DB 호출 (`SettlementGatewayImpl.getRewardSettlementRate`)

`RewardSettlementRateRepository.getById(campaignId)` (Spring Data JDBC):
```sql
SELECT * FROM RewardSettlementRate WHERE CampaignId = ?
```
(정확한 SQL은 Spring Data JDBC 런타임 생성)

**접근 테이블**: `RewardSettlementRate`

---

## 2. GET `/api/studio/campaigns/{campaignId}/settlement-statement/download` — 정산 내역서 PDF 다운로드 (Studio)

- **Method**: `SettlementStudioController.downloadSettlementStatement`
- **Query**: `title`, `settlementLevelName` (필수)
- **Produces**: `application/octet-stream`

### Response
HTTP 200, `Content-Disposition: attachment; filename="{settlementLevelName}.pdf"`, `application/pdf`

### DB/외부 호출
`StatementUsecase.downloadSettlementStatement(query)` — funding-core.  
PDF 파일 자체는 ERP 또는 외부 스토리지에서 불러올 것으로 추정 (이 레포에서는 외부 저장소 Gateway 구체 미확인).

---

## 3. GET `/api/studio/campaigns/{campaignId}/settlement-statement` — 정산 내역서 정보 (Studio)

- **Method**: `SettlementStudioController.getSettlementStatement`
- **Query Params**: `projectType` (✅ `ProjectType` enum, required)

### Response — `List<StatementResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `paymentStandardDate` | `String` | 결제 기준 일 |
| `settlementLevelCode` | `String` | 정산 단계 코드 |
| `settlementLevelName` | `String` | 정산 단계 명 |
| `fileName` | `String` | 정산내역서 파일명 |
| `code` | `String` | — |

### DB/외부 호출
`StatementUsecase.getSettlementStatement(StatementQuery)` — funding-core. 내부적으로 **ERP API** 호출로 보임.

---

## 4. GET `/api/studio/campaigns/{campaignId}/fees` — 수수료 조회 (Studio)

- **Method**: `SettlementStudioController.fee`
- **Query Params**: `projectType` (✅)
- 빈 결과 시 응답 바디 `null`로 통째 반환

### Response — `FeeResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `brokerageChargeList[]` | `List<FeeDetail>` | 중개 수수료 상세 |
| `extraChargeList[]` | `List<FeeDetail>` | 추가 수수료 |
| `defaultChargeList[]` | `List<FeeDetail>` | 기본 수수료 |
| `totalBrokerageChargeRate` | `BigDecimal` | 중개 수수료율 합계 |
| `totalFeeAmount` | `BigDecimal` | 총 수수료 금액 |
| `totalFeeRate` | `BigDecimal` | 총 수수료율 |

### 외부 API 호출 (`ErpSettlementGatewayImpl.findSettlement`)

**ERP `getProjectSettlementInfo`** 호출:
```
POST {erp-host}/project-settlement-info
Headers: { Authorization: Bearer {accessToken} }
Body (ErpSettlementRequest):
  {
    "projectType": "FUNDING|PREORDER|...",
    "projectId": <campaignId>,
    "startDate": "yyyyMMdd",
    "endDate": "yyyyMMdd"
  }
```

- 토큰 획득: `erpSettlementClient.getTokens(ErpEncryptUtil.encrypt(keys))` (2단계: keys → encrypt → getAccessToken)
- 응답 파싱해 `Settlement` 도메인 객체로 변환 (projectType, businessNumber, packagePlan, settlementResultStep/State, settlementProposals[], feeBySettlements[] 등)

### DB 호출
이 엔드포인트 자체는 MySQL 조회 없음. 전부 ERP 외부 API.

---

## 5. GET `/api/studio/campaigns/{campaignId}/settlement-system` — 정산 시스템 조회 (Studio)

- **Method**: `SettlementStudioController.getSettlementSystem`

### Response — `SettlementSystemResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `systemType` | enum `SystemType` | 정산 시스템 타입 (`WADIZ_ADM` 등) |

### DB 호출 (`SettlementGatewayImpl.getSettlementSystem`)

`SettlementSystemRepository.findById(campaignId)` (Spring Data JDBC):
```sql
SELECT * FROM SettlementSystem WHERE CampaignId = ?
```

- 미존재 시 기본값 `SystemType.WADIZ_ADM`으로 응답

**접근 테이블**: `SettlementSystem`

---

## 6. GET `/api/studio/campaigns/{campaignId}/fee-version` — 수수료 버전 조회 (Studio)

- **Method**: `SettlementStudioController.getFeeVersion`
- **Cache**: `@Cacheable(key="'feeVersion: '+#campaignId")`

### Response — `FeeVersionResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `status` | `String` ("OK" / "NOT_FOUND") | ✅ |
| `feeVersion` | `Integer` | ✅ 버전 번호 |

### 외부 API 호출 (`ErpSettlementGatewayImpl.findSettlementVersion`)

**ERP `getVersion`** 호출:
```
POST {erp-host}/settlement-version
Headers: Authorization Bearer
Body: { "projectId": <campaignId>, "projectType": <type> }
→ Response: { version, status }
```

---

## 7. GET `/api/studio/campaigns/{campaignId}/v2/fees` — 수수료 조회 v2 (Studio)

신규 버전 수수료 조회. **campaignId만으로** 호출 (projectType 생략).

- **Method**: `SettlementStudioController.getFee`
- **Cache**: `@Cacheable(key="'fee: '+#campaignId")`

### Response — `FeeInfoResponse`
이 DTO는 ERP의 `FeeInfo { version, fees[...] }` 를 변환한 형태.

### 외부 API 호출 (`ErpSettlementGatewayImpl.findFee(campaignId, projectType)`)

**ERP `getFee`** 호출:
```
GET {erp-host}/fee?campaignId=?&projectType=?
Headers: Authorization Bearer
→ Response: { version, fees: [...] }
```

---

## 8. GET `/api/internal/settlement/{campaignId}/maker-info` — 프로젝트 정산 메이커 정보 (Internal)

- **Method**: `SettlementInternalController.getCampaignSettlementMaker`
- **Cache**: `@Cacheable(key="'campaingSettlementMakerInfo: '+#campaignId")`

### Response — `CampaignSettlementMakerInfoResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `idNo` | `String` | 메이커 주민번호 또는 사업자번호 (복호화) |

### DB 호출 (`SettlementGatewayImpl.getRewardSettlementMakerInfo`)

`RewardSettlementRepository.getById(campaignId)` — **MyBatis** (`CampaignSettlementMapper.xml`):
```sql
SELECT damo.DEC_B64('${DAMO_ENC_KEY}', ResidentRegistrationNumber) AS idNo
FROM CampaignContractInfo
WHERE CampaignId = ?
```

- `damo.DEC_B64` DB 함수로 주민/사업자번호 복호화 (민감정보 암호화 저장)
- 응답 필드명은 `idNo` 단일. UseCase에서 주민/사업자 판단은 추가 조회가 필요할 가능성 있음 (확인 불가).

**접근 테이블**: `CampaignContractInfo`

---

## 9. GET `/api/internal/settlement/{campaignId}/package-plan` — 요금제 조회 (Internal)

- **Method**: `SettlementInternalController.getCampaignPackagePlan`
- **Cache**: `@Cacheable(key="'campaingPackagePlan: '+#campaignId")`

### Response — `CampaignPackagePlan` (core/domain DTO)
이 레포에 payload 없음 — 도메인 DTO 그대로 직렬화.

### DB 호출 (`SettlementGatewayImpl.getPackagePlan`)

`CampaignPackagePlanRepository.getById(campaignId)` (Spring Data JDBC):
```sql
SELECT * FROM CampaignPackagePlan WHERE CampaignId = ?
```

**접근 테이블**: `CampaignPackagePlan`

---

## 10. GET `/api/internal/settlement/fee-proposals` — 수수료 품의 진행상태 (Internal, 페이징)

- **Method**: `SettlementInternalController.feeProposalProgressStatus`

### Request (Query, `@Valid FeeProposalRequest`)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `projectId` | `Integer` | ✅ `@NotNull` | — |
| `projectType` | `ProjectType` enum | ✅ `@NotNull` | — |
| `feeProposalStatus` | `FeeProposalStatus` enum | ⬜ | 상태 필터 |
| `proposalSubmitted` | `Boolean` | ⬜ | 품의 제출 여부 |
| `startDate / endDate` | `LocalDate` (ISO) | ⬜ | — |
| `page / size` | `Integer` | ⬜ | 페이징 |

### Response — `PageResult<FeeProposalsResponse>` (Spring Data Pages 형태)

### 외부 API 호출 (`ErpSettlementUseCase.getFeeProposalStatusList`)
ERP API로 품의 상태 조회. 세부 요청/응답은 funding-core 확인 필요.

---

## 11. GET `/api/internal/settlement/fees` — 수수료 조회 (Internal, 날짜 필터 가능)

- **Method**: `SettlementInternalController.fee`

### Request (Query, `@Valid FeeRequest`)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `projectId` | `Integer` | ✅ | — |
| `projectType` | `ProjectType` enum | ✅ | — |
| `searchStartDate / searchEndDate` | `LocalDate` (ISO) | ⬜ | 수수료 검색 기간 |

### Response — `FeeResponse` (4번과 동일 구조, totalBrokerageCharge/Amount/Rate는 null)

### 외부 API 호출
`ErpSettlementGatewayImpl.findSettlement(SettlementQuery)` — 날짜 범위 포함 ERP 호출. SQL 4번과 동일 외부 API.

---

## 12. GET `/api/internal/settlement/settlement-statement` — 정산 내역서 조회 (Internal)

- **Method**: `SettlementInternalController.getSettlementStatement`

### Request (Query, `@Valid StatementRequest`)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `projectId` | `Integer` | ✅ | — |
| `projectType` | `ProjectType` enum | ✅ | — |
| `businessNumber` | `String` | ⬜ | — |
| `startDate / endDate` | `String` | ⬜ | — |

### Response — `List<StatementResponse>` (3번과 동일)

### 외부 API 호출
`StatementUsecase.getSettlementStatement(StatementQuery)` — funding-core (ERP 호출 추정).

---

## 13. GET `/api/internal/settlement/settlement-statement/download` — 정산 내역서 PDF (Internal)

- **Method**: `SettlementInternalController.downloadSettlementStatement`
- **Query**: `title`

2번과 동일 로직. Content-Disposition 파일명은 `settlement-statement.pdf` 고정.

---

## 14. GET `/api/internal/settlement/settlement-result-state` — 정산지급상태 조회 (Internal)

- **Method**: `SettlementInternalController.getSettlementResultState`

### Request (Query, `@Valid SettlementResultRequest`)
`SettlementRequest`와 유사 (`projectId`, `projectType`, 기간).

### Response — `SettlementResultStateResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `settlementResultState` | enum `SettlementResultState` | 지급 상태 |

### 외부 API 호출 (`ErpSettlementGatewayImpl.findSettlementResult`)

**ERP `getSettlementResult`** 호출:
```
POST {erp-host}/settlement-result
Body: { "projectType": ..., "projectId": ... }
→ Response: [SettlementResultResponse{... settlementResultDetailResponses[...]}]
```

- 응답을 `SettlementResult`로 변환: `settlementResultStep`(Step code), `settlementResultState`(Status), `paymentStandardDate`, `settlementConfirmDate`, `settelmentResultDetailList[]`(settlementResultCode, actionAmount, feeCategory)

---

## 15. GET `/api/internal/settlement/is-split` — 분할 정산 여부 (Internal)

- **Method**: `SettlementInternalController.isSplitSettlement`

### Request (Query, `@Valid SettlementRequest`) — 11번과 동일

### Response
`ResponseWrapper<Boolean>`

### 외부 API 호출
`ErpSettlementUseCase.isSplitSettlement(query)` — funding-core가 ERP에서 받아온 데이터로 판정.

---

## 16. GET `/api/internal/settlement/{campaignId}/settlement-system` — 정산 시스템 (Internal)
5번과 동일한 Gateway 경로 (`SettlementGatewayImpl.getSettlementSystem`). 인증 경계만 다름.

---

## 17. GET `/api/internal/settlement/{campaignId}/fee-version` — 수수료 버전 (Internal)
6번과 동일한 외부 호출 (ERP `getVersion`).

---

## 18. GET `/api/internal/settlement/{campaignId}/v2/fees` — 수수료 조회 v2 (Internal)
7번과 동일한 외부 호출 (ERP `getFee`).

---

## 19. GET `/api/admin/settlement/fees` — 수수료 조회 (Admin)
11번과 동일 구조 (`FeeRequest` 쿼리). 단, 기간(`searchStartDate/EndDate`)은 Admin에서는 Proxy로 전달 안 됨.

---

## 20. GET `/api/admin/settlement/fee-proposals` — 수수료 품의 (Admin)
10번과 동일. 단, `status`가 null일 때 `FeeProposalStatus.ALL` 기본값 적용.

---

## 21. GET `/api/admin/settlement` — 정산 정보 조회 (Admin)

- **Method**: `SettlementAdminController.getSettlementProgress`

### Request (Query, `@Valid SettlementRequest`)

### Response — `SettlementProgressResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `projectType` | enum `ProjectType` | — |
| `settlementStep` | enum `SettlementResultStep` | 정산 단계 |
| `settlementState` | enum `SettlementResultState` | 상태 |
| `settlementHold` | `Boolean` | 정산 보류 여부 |
| `ratioList[]` | `List<SettlementRatioResponse{name, ratio}>` | 분할 정산 비율 |

### 외부 API 호출
`ErpSettlementUseCase.findSettlementProgress(query)` → ERP `getProjectSettlementInfo` 호출 (4번과 동일 API, 해석만 다름).

---

## 22. GET `/api/admin/settlement/adCost` — 광고 비용 조회 (Admin)

- **Method**: `SettlementAdminController.getADCost`

### Request (Query, `@Valid FeeRequest`)

### Response — `AdCostResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `costResponses[].productName` | `String` | 광고 상품명 |
| `costResponses[].productCost` | `long` | 비용 |

### 외부 API 호출
`ErpSettlementUseCase.findAdCost(query)` — ERP API (상세 엔드포인트는 funding-core 확인 필요).

---

## 23. GET `/api/admin/settlement/campaigns/{campaignId}/fee-version` — 수수료 버전 (Admin)
6번과 동일.

## 24. GET `/api/admin/settlement/campaigns/{campaignId}/v2/fees` — 수수료 v2 (Admin)
7번과 동일.

---

## 25. GET `/api/studio/pricing/{projectNo}` — 캠페인 요금 정보 조회

캠페인의 **요금제(Package Plan) + 부가서비스** 통합 조회.

- **Method**: `StudioPricingController.getCampaignPricing`
- **Security**: `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`
- **설명**: "요금제 판단 후 판단 결과 기준 응답. DB 저장 안 함."

### Response — `CampaignPricingResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `packagePlan.type` | enum `PackagePlanType` | 요금제 타입 |
| `additionalServices[]` | `List<CampaignAdditionalServiceResponse>` | 부가서비스 목록 |
| `additionalServices[].projectNo / additionalServiceCode / isRequested / requested / status / additionalServiceData` | — | 서비스별 상세 |

### DB 호출 (`StudioPricingGatewayImpl.getCampaignPricing`)

**① 요금제 조회** (`CampaignPackagePlanMapper.findByProjectNo`)
```sql
SELECT PackagePlanType FROM CampaignPackagePlan WHERE CampaignId = ?
```
- 없으면 `PackagePlanType.STARTER`로 기본 설정
- 존재 시 `.toDisplayType()` 변환

**② 부가서비스 목록** (`CampaignAdditionalServiceMapper.findByProjectNo`)
```sql
SELECT CampaignId, AdditionalServiceCode, IsRequested, Requested, RequestedUserId,
       Status, AdditionalServiceData, Registered, Updated
FROM CampaignAdditionalService
WHERE CampaignId = ?
ORDER BY Requested DESC
```

**접근 테이블**: `CampaignPackagePlan`, `CampaignAdditionalService`

---

## 26. POST `/api/studio/pricing/{projectNo}` — 요금제 + 부가서비스 저장

- **Method**: `StudioPricingController.savePricing`
- **Security**: `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`

### Request Body — `AdditionalServicesRequest`
부가서비스 신청 정보. 구체 필드는 core/domain 소스 확인 필요.

### Response — `CampaignPricingResponse` (25번과 동일)

### 컨트롤러 코드 흐름

1. `SecurityUtils.currentUserId()` 획득
2. `studioPayloadLogProxy.logging(userId, projectNo, StudioSectionType.PLAN, request)` — 요청 본문 로깅(감사 로그)
3. `studioPricingProxy.savePricing(userId, projectNo, request)` → `StudioPricingUsecase.savePricing` (funding-core)

### DB 호출 (`StudioPricingGatewayImpl` 가능 경로)

**① 요금제 저장** (`CampaignPackagePlanMapper.upsertPackagePlan`)
```sql
INSERT INTO CampaignPackagePlan (CampaignId, PackagePlanType)
VALUES (?, ?)
ON DUPLICATE KEY UPDATE
  PackagePlanType = ?,
  Updated = CURRENT_TIMESTAMP
```

**② 부가서비스 저장** (`CampaignAdditionalServiceMapper.upsertCampaignService`)
```sql
INSERT INTO CampaignAdditionalService
  (CampaignId, AdditionalServiceCode, IsRequested, Requested, RequestedUserId, Status, AdditionalServiceData)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  IsRequested = ?,
  Requested = ?,
  RequestedUserId = ?,
  Status = ?,
  AdditionalServiceData = ?,
  Updated = CURRENT_TIMESTAMP
```

**③ 부가서비스 취소** (`updateIsRequested`)
```sql
UPDATE CampaignAdditionalService
SET IsRequested = ?, Status = ?, AdditionalServiceData = NULL, Updated = CURRENT_TIMESTAMP
WHERE CampaignId = ? AND AdditionalServiceCode = ?
```

**④ 변경 이력** (`savePricingHistory` → `CampaignPackagePlanHistoryMapper.insertHistory`) — 이력 INSERT

**⑤ StudioPayloadLog** — `studioPayloadLogProxy.logging()` 경유 (studio/log 도메인의 별도 테이블에 감사 로그 기록)

**접근 테이블**: `CampaignPackagePlan`, `CampaignAdditionalService`, `CampaignPackagePlanHistory`, `StudioPayloadLog`(추정)

---

## 27. POST `/api/studio/pricing/{projectNo}/determine` — 요금제 판단 및 저장

부가서비스 제외, 요금제만 판단해 변경 있으면 저장.

- **Method**: `StudioPricingController.determineAndSavePackagePlan`

### 컨트롤러 코드 흐름
`studioPricingProxy.determineAndSavePackagePlan(userId, projectNo)` → `StudioPricingUsecase.determineAndSavePackagePlan` (funding-core)

### DB 호출
26번의 ① + ④만 실행될 가능성. 부가서비스 관련 쿼리는 생략.

---

## 28. GET `/api/admin/outstandings/{campaignId}` — 미수금 조회 (Admin)

- **Method**: `OutstandingAdmController.getOutstanding`
- **Security**: `@PreAuthorize("isAdmin()")`
- **Cache**: `@CacheConfig(cacheNames="erpSettlement")` (단, 실제 `@Cacheable` 없음)

### Response — `List<OutstandingResponse>`
| 필드 | 타입 | 설명 |
|---|---|---|
| `corpType` | enum `CorpType` | 개인/법인 구분 |
| `residentRegistrationNumber` | `String` | 주민번호 (복호화) |
| `businessRegistrationNumber` | `String` | 사업자번호 |
| `amount` | `long` | 미수금 총액 |

### 컨트롤러 코드 흐름
`outstandingProxy.getOutstandings(campaignId)` → `OutstandingUsecase.getOutstandings` (funding-core)

### 외부 API 호출 (`OutstandingGatewayImpl.getOutstanding`)

`OutstandingUsecase`는 먼저 `CampaignContractInfo`에서 사업자/주민번호를 조회(3번 `maker-business-info`와 동일 SQL 경로로 추정) 후 다음을 호출:

**ERP `getOutstanding`**
```
POST {erp-host}/outstanding
Headers: Authorization Bearer
Body (OutStandingRequest):
  {
    "businessRegistrationNumber": "...",
    "residentRegistrationNumber": "..."
  }
→ Response: [OutStandingResponse{amount: "..."}, ...]
```

- 여러 응답 항목의 amount를 합산해 반환
- 빈 응답이면 0

---

## 29. 참고 — 이 문서의 Gateway / Mapper / Repository

### Gateway 구현체 (이 레포)

| 구현체 | 메서드 → 대상 |
|---|---|
| `SettlementGatewayImpl` | `getRewardSettlementRate` → `RewardSettlementRateRepository`, `getRewardSettlementMakerInfo` → `RewardSettlementRepository`(MyBatis), `getPackagePlan` → `CampaignPackagePlanRepository`, `getSettlementSystem` → `SettlementSystemRepository` |
| `ErpSettlementGatewayImpl` | `findSettlement` / `findSettlementResult` / `findSettlementVersion` / `findFee` → `ErpSettlementClient` (외부 ERP API) |
| `OutstandingGatewayImpl` | `getOutstanding` → `ErpClient.getOutstanding` (외부 ERP API) |
| `StudioPricingGatewayImpl` | `CampaignPackagePlanMapper` + `CampaignPackagePlanHistoryMapper` + `CampaignAdditionalServiceMapper` |

### Spring Data JDBC Repositories
- `RewardSettlementRateRepository` — `getById(campaignId)` 파생
- `RewardSettlementRepository` — MyBatis 매핑 (XML에 `getById`)
- `CampaignPackagePlanRepository` — `getById`
- `SettlementSystemRepository` — `findById`

### MyBatis Mapper XML
- `settlement/CampaignSettlementMapper.xml` — `getById` (복호화된 idNo)
- `studio/pricing/CampaignPackagePlanMapper.xml` — 요금제 UPSERT + 조회
- `studio/pricing/CampaignPackagePlanHistoryMapper.xml` — 이력 INSERT
- `additionalservice/CampaignAdditionalServiceMapper.xml` — 부가서비스 UPSERT + 조회 + 취소 UPDATE

### UseCase 중 이 레포에 직접 **Gateway 구현체 없음**
- `CampaignSettlementStatusUseCase` (대부분 SettlementGatewayImpl + ErpSettlementGatewayImpl 경유지만 내부 호출 순서는 funding-core)
- `StatementUsecase` (정산 내역서 PDF/JSON — ERP 또는 외부 스토리지)
- `ErpSettlementUseCase` 내부의 `isSplitSettlement`, `findAdCost`, `findSettlementProgress` — 구체 외부 엔드포인트는 funding-core 확인 필요
- `OutstandingUsecase` (미수금 — Gateway는 있으나 UseCase 로직 미관찰)

### ERP 외부 API 호출 패턴

모든 ERP 호출은 공통 토큰 획득 로직:
```java
String accessToken = erpSettlementClient.getTokens(
    ErpEncryptUtil.encrypt(ErpConverter.INSTANCE.map(erpSettlementClient.getKeys()))
).getAccessToken();
```

1. `getKeys()` — 키 세트 조회
2. `ErpEncryptUtil.encrypt()` — 암호화
3. `getTokens(encryptedKeys)` — 토큰 발급
4. 이후 모든 호출에 `Authorization: Bearer {accessToken}`

### 접근 테이블 합계

`RewardSettlementRate`, `RewardSettlement`/`CampaignContractInfo`, `CampaignPackagePlan`, `CampaignPackagePlanHistory`, `SettlementSystem`, `CampaignAdditionalService`, `StudioPayloadLog`(추정) + 외부 ERP(Douzone) API (수수료/정산진행/결과/버전/미수금/광고비)

### 주요 enum (core/domain, funding-core)
- `ProjectType`: FUNDING / PREORDER / ...
- `FeeProposalStatus`: 품의 상태
- `SettlementResultStep`: 정산 단계 코드
- `SettlementResultState`: 지급 상태
- `SettlementResultCode`: 결과 카테고리
- `SettlementResultFeeCategory`: 수수료 분류
- `PackagePlanType`: STARTER / PRO / ... (표시용 `toDisplayType()` 변환)
- `SystemType`: WADIZ_ADM / ...
- `FeeFormat`: 수수료 형식 코드
- `EnteredType`: 입력 유형
