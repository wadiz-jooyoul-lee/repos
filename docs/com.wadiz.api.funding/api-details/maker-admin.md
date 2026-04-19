# Maker / Manager / Employee / Business / BankAccount / Contract / MakerInvitation API 상세 스펙

메이커·담당자·사원·사업자·은행계좌·계약정보·초대 관련 **21개 엔드포인트**.

- **대상 컨트롤러**:
  - `MakerController` (`/api/maker`) — 1개
  - `MakerClubController` (`/api/maker-club`) — 1개, `isAdmin`
  - `MyProjectController` (`/api/makers/my`) — 2개, 로그인 + `@Impersonatable`
  - `ManagerAdminController` (`/api/admin/managers`) — 1개, `isAdmin`
  - `ManagerInternalController` (`/api/internal/managers`) — 1개
  - `DepartmentAdminController` (`/api/v1/admin/departments`) — 1개
  - `EmployeeAdminController` (`/api/v1/admin/employees`) — 2개
  - `BusinessVerifyController` (`/api/v1/campaigns/{campaignId}/business-licenses`) — 2개
  - `BankAccountController` (`/api/v1/campaigns/{campaignId}/bank-accounts`) — 1개
  - `ContractInfoStudioController` (`/api/studio/campaigns/{campaignId}/contract-info`) — 1개, `isMaker or isAdmin`
  - `MakerInvitationController` (`/api/maker-invitations`) — 7개
  - `AdminMakerInvitationController` (`/api/admin/maker-invitations`) — 1개, `isAdmin`

- **저장소**: MySQL 중심. 일부는 외부 API 연동(사업자 OCR, 사업자 진위검증, 계좌 실명확인).
- **주요 테이블**: `Campaign`, `UserProfile`, `PhotoCommon`, `webpages_UsersInRoles`, `Department`, `Employee`, `MakerInvitation`, `MakerInvitationCode`, `MakerInvitationBenefit`, `CampaignContractInfo`, `CampaignContractRepresentative`

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록. 외부 OCR/검증/계좌실명 API는 funding-core가 호출하므로 구체 엔드포인트는 확인 불가.

---

## 1. GET `/api/maker/{campaignId}` — 메이커 정보 조회

- **Method**: `MakerController.makerDetail`

### Response — `MakerDetailResponse`
(userId, nickName, profileImage, websiteA/B, SNS urls, answerTime, `isLoginUserMaker`)

### MySQL 쿼리 (`MakerMapper.getMakerDetail`)

```sql
SELECT C.UserId, C.SocialUrlFb, C.SocialUrlTw, C.SocialUrlIg,
       IFNULL(C.HostName, UP.NickName) AS NickName,
       PC.PhotoUrl AS ProfileImage,
       C.WebsiteA, C.WebsiteB,
       PMBAT.AnswerTime
FROM Campaign C
     INNER JOIN UserProfile UP ON C.UserId = UP.UserId
     LEFT OUTER JOIN PhotoCommon PC ON C.PhotoIdHost = PC.PhotoId
     LEFT JOIN PersonalMessageBoardAnswerTime PMBAT
            ON PMBAT.ProjectId = C.CampaignId AND PMBAT.ProjectType = 'R'
WHERE C.CampaignId = ?
```

### 컨트롤러 후처리
`isLoginUserMaker = SecurityUtils.isLogin() && makerDetail.userId == SecurityUtils.currentUserId()`

**접근 테이블**: `Campaign`, `UserProfile`, `PhotoCommon`, `PersonalMessageBoardAnswerTime`

---

## 2. GET `/api/maker-club/campaign-grade` — 캠페인 등급 수집 (Admin)

- **Method**: `MakerClubController.getCollectionCampaignGrade`
- **Security**: `@PreAuthorize("isAdmin()")`

### Response
항상 `Boolean.TRUE` (배치 트리거성 API)

### DB 호출
`makerClubProxy.getCollectionCampaignGrade()` → `MakerClubQueryGatewayImpl` 경유. 수집 로직은 funding-core.

---

## 3. GET `/api/makers/my/projects` — 내 프로젝트 목록 (메이커, 페이징)

- **Method**: `MyProjectController.getProjects`
- **Security**: `@PreAuthorize("isAuthenticated()")` + `@Impersonatable`

### Request (Query)
| 필드 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `phase` | enum `ProjectPhase` | ⬜ | 단계 필터 |
| `only` | enum `ProjectFilter` | ⬜ | 해당 조건만 |
| `except` | enum `ProjectFilter` | ⬜ | 해당 조건 제외 |
| `timezone` | `String` (IANA) | ⬜ | 유저 타임존 (기본 서버 TZ) |

### 컨트롤러 코드 흐름
1. `userZone = ZoneId.of(timezone)` (없으면 `systemDefault()`)
2. `userToday = LocalDate.now(userZone)`
3. `todayStart/End`를 서버 타임존으로 변환
4. `MyProjectQuery{userId, phase, only, except, todayStart, todayEnd}` 구성
5. `myProjectProxy.getProjects(query, pages)` 호출

### DB 호출
`CampaignQueryGatewayImpl.findMyProjects` — `CampaignMapper.findMyProjects` (campaign-admin.md 6번과 유사 SQL).

### Response — `PageResult<MyProjectResponse>`

---

## 4. GET `/api/makers/my/project-summary` — 내 프로젝트 요약

- **Query**: `timezone` (IANA)

### Response — `MyProjectSummaryResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `todayWishCount` | `int` | 오늘 찜 수 |
| `todayFundingCount` | `int` | 오늘 결제 건수 |
| `todaySignatureCount` | `int` | 오늘 지지서명 |
| `todayAskForEncoreCount` | `int` | 오늘 앵콜 요청 |

### DB 호출
`myProjectProxy.getSummary(MyProjectSummaryQuery{userId, todayStart, todayEnd})` — UseCase 내부에서 `UserWishProject`, `BackingPayment`, `Signature`, `CampaignAskForEncore` 집계.

관련 Gateway 메서드로 관찰된 것:
- `FundingQueryGateway.countByMakerAndPeriod(userId, from, to)` (from funding.md)
- `SignatureQueryGateway.countByMakerAndPeriod(userId, from, to)` (같은 형태)

---

## 5. GET `/api/admin/managers` — 관리자 목록 조회

- **Method**: `ManagerAdminController.managerList`
- **Security**: `@PreAuthorize("isAdmin()")`
- **Query**: `name` (관리자명)

### Response — `List<ManagerResponse>`

### MySQL 쿼리 (`ManagerMapper.searchManager`)

```sql
SELECT DISTINCT UR.UserId, U.NickName, U.UserName
FROM webpages_UsersInRoles UR
     JOIN UserProfile U ON U.UserId = UR.UserId
WHERE 1=1
  -- query.userId != null: OR UR.UserId = ?
  -- query.name != null: OR U.NickName = ?
```

> ⚠️ **SQL 주의**: `<where>` 블록 내부가 `OR` 접두사로만 구성되어 있어 첫 조건 앞 `OR`는 `<where>` 태그가 자동 제거. 의도한 동작은 `userId` 또는 `name` 매칭으로 보인다.

**접근 테이블**: `webpages_UsersInRoles`, `UserProfile`

---

## 6. GET `/api/internal/managers/{userId}` — 관리자 userId 조회

### DB 호출
`ManagerQueryGatewayImpl.getManager(userId)` — 동일 `searchManager` SQL을 `userId` 조건으로 호출.

---

## 7. GET `/api/v1/admin/departments` — 부서 목록 (페이징)

- **Method**: `DepartmentAdminController.getDepartmentList`

### Request (Query)
| 필드 | 타입 | 설명 |
|---|---|---|
| `departmentName` | `String` | 부서명 필터 |

### Response — `PageResult<DepartmentListResponse>`

### DB 호출
`DepartmentProxy.getDepartmentList` → UseCase(funding-core) → `DepartmentMapper` 또는 `Department` 테이블 조회 (구체는 funding-core).

---

## 8. GET `/api/v1/admin/employees` — 사원 목록 (페이징)

- **Method**: `EmployeeAdminController.getEmployeeList`

### Request (Query)
| 필드 | 타입 | 설명 |
|---|---|---|
| `employeeName` | `String` | 사원명 필터 |

### Response — `PageResult<EmployeeResponse>`

---

## 9. GET `/api/v1/admin/employees/{employee-code}` — 사원 상세

- **Path**: `employee-code` (String)
- **Query**: `employeeName` (옵션, 추가 식별)

### Response — `EmployeeResponse`

---

## 10. POST `/api/v1/campaigns/{campaignId}/business-licenses` — 사업자등록증 OCR 업로드

- **Method**: `BusinessVerifyController.upload`

### Request Body — `BusinessOCRRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `data` | `String` | Base64 이미지 데이터 |
| `originalFileName` | `String` | — |

### Response — `BusinessOCRResponse`
OCR 추출 결과 (사업자명, 번호, 대표자명, 개업일 등)

### DB 호출
OCR 추출은 **외부 OCR API** 호출 (funding-core에서 관리). 이 레포에선 요청 전달만.

---

## 11. GET `/api/v1/campaigns/{campaignId}/business-licenses/verify` — 사업자 진위 검증

- **Method**: `BusinessVerifyController.verify`

### Request (Query) — `BusinessVerifyRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `businessName` | `String` | — |
| `businessNumber` | `String` | — |
| `representativeName` | `String` | — |
| `openingDate` | `String` | — |

### Response — `BusinessVerifyResponse` (유효 여부 + 상태)

### DB 호출
외부 **국세청 사업자 진위확인 API** 호출 (funding-core). 결과를 `CampaignContractInfo` 에 반영할 수 있으나 이 엔드포인트 자체는 조회 검증만.

---

## 12. GET `/api/v1/campaigns/{campaignId}/bank-accounts/verify` — 은행 계좌 실명 확인

- **Method**: `BankAccountController.verify`

### Request (Query) — `BankAccountVerifyRequest`
| 필드 | 타입 | 설명 |
|---|---|---|
| `bankCode` | `String` | 은행 코드 |
| `accountHolder` | `String` | 예금주명 |
| `accountNumber` | `String` | 계좌번호 |

### Response — `BankAccountVerifyResponse` (일치 여부)

### DB 호출
**외부 계좌 실명확인 API** 호출 (NICE 또는 은행 연동, funding-core). 일치 시 `CampaignContractInfo`에 계좌 저장.

---

## 13. GET `/api/studio/campaigns/{campaignId}/contract-info` — 프로젝트 대표자/정산 정보

- **Method**: `ContractInfoStudioController.getCampaignContractInfo`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`

### Response — `CampaignContractInfoResponse`
(BusinessRegistrationType/Number, 주민등록번호(복호화), 대표자명, 계좌 정보(복호화), 세금계산서 이메일, 개인인증 정보)

### MySQL 쿼리 (`ContractInfoQueryGatewayImpl.getCampaignContractInfo` → `CampaignContractMapper.campaignContractInfo`)

이미 `campaign-admin.md` 3번에서 다룬 쿼리와 유사하지만 단일 프로젝트용:
```sql
SELECT CCI.CampaignId, CCI.BusinessNumber, CCI.BusinessName,
       CCI.AccountBankCode, BC.BankName AS AccountBankName,
       damo.DEC_B64('${DAMO_ENC_KEY}', CCI.AccountNumber) AS AccountNumber,
       CCI.AccountHolder, CCI.InvoiceRecipient, CCI.Registered, CCI.Updated
FROM CampaignContractInfo CCI
     LEFT JOIN BankCode BC ON BC.BankCode = CCI.AccountBankCode
WHERE CCI.CampaignId = ?
```

`damo.DEC_B64` DB 함수로 계좌번호 복호화.

**접근 테이블**: `CampaignContractInfo`, `BankCode`

---

## 14. GET `/api/maker-invitations/inviters/my` — 추천인 상세 (나의 추천 현황)

- **Method**: `MakerInvitationController.getMyInvitation`

### Response — `InviterDetailResponse`

### DB 호출
`MakerInvitationQueryGatewayImpl.get(userId)` → `MakerInvitationMapper`.

---

## 15. GET `/api/maker-invitations/inviters/my/is-expected-benefit` — 추천인 혜택 예상 여부

- **Query**: `type` (`MakerInvitationBenefitType`), `targetId` (String)

### Response
`ResponseWrapper<Boolean>` — 혜택 대상 여부

---

## 16. GET `/api/maker-invitations/invitees/validity` — 피추천인 유효성 확인

### Response — `InviteeValidityResponse`

---

## 17. POST `/api/maker-invitations` — 추천 코드 등록

- **Method**: `MakerInvitationController.register`
- **Security**: `@PreAuthorize("isMaker(#request.campaignId)")`

### Request Body — `RegisterMakerInvitationRequest{code, campaignId}`

### DB 호출
`MakerInvitationGatewayImpl.save(MakerInvitation{code, campaignId, inviterUserId, ...})`

```sql
INSERT INTO MakerInvitation (Code, CampaignId, InviterUserId, InviteeUserId, ...) VALUES (...)
```

---

## 18. GET `/api/maker-invitations/codes/{code}/validity-for-invitee` — 피추천인 코드 유효성

- **Path**: `code`
- **Query**: `campaignId`

### Response — `CodeValidityForInviteeResponse`

### DB 호출
`MakerInvitationCodeGatewayImpl` 경유 — `MakerInvitationCode` 테이블 조회 + 유효 기간/사용 여부 검증.

---

## 19. GET `/api/maker-invitations/codes/{code}` — 추천 코드 정보

### Response — `InvitationCodeResponse`

### DB 호출
`MakerInvitationCode` 테이블 단건 조회:
```sql
SELECT * FROM MakerInvitationCode WHERE Code = ?
```

---

## 20. GET `/api/maker-invitations/by-campaign` — 프로젝트별 추천 등록 조회

- **Query**: `campaignId`

### Response — `Optional<InvitationByCampaignResponse>`

### MySQL 쿼리 (`MakerInvitationMapper.findByCampaignId`)

공통 SQL 블록 `find` 사용 + campaignId 조건 추가. `MakerInvitation` + `MakerInvitationCode` + `MakerInvitationBenefit` 조인.

---

## 21. GET `/api/admin/maker-invitations/by-campaign` — 관리자 프로젝트별 추천 등록 조회

- **Security**: `@PreAuthorize("isAdmin()")`

20번과 동일한 Proxy 메서드 호출. 응답 DTO만 관리자용 `AdminInvitationByCampaignResponse`로 변환.

---

## 22. 참고 — 이 문서의 Gateway / Repository / Mapper

### Gateway 구현체 (이 레포)

| 구현체 | 대상 |
|---|---|
| `MakerQueryGatewayImpl` | `MakerMapper.getMakerDetail` |
| `MakerFollowQueryGatewayImpl` | 팔로우 관련 |
| `MakerClubQueryGatewayImpl` | Maker Club 등급 |
| `MakerUserGatewayImpl` | 메이커-유저 연계 |
| `ManagerQueryGatewayImpl` | `ManagerMapper.searchManager` |
| `MakerInvitationGatewayImpl` | `MakerInvitation*Repository` + `MakerInvitationMapper` |
| `MakerInvitationCodeGatewayImpl` | `MakerInvitationCode` 관련 |
| `MakerInvitationQueryGatewayImpl` | `MakerInvitationMapper.findAllByCode/findByCampaignId` |
| `MakerInvitationBenefitGatewayImpl` / `...BenefitPaymentGatewayImpl` | 혜택 및 지급 |
| `ContractInfoQueryGatewayImpl` | `CampaignContractMapper` (campaign-admin.md 3번 참조) |

### MyBatis Mapper XML
- `MakerMapper.xml` — `getMakerDetail`
- `ManagerMapper.xml` — `searchManager` (웹페이지 역할 테이블 조회)
- `MakerInvitationMapper.xml` — `findAllByCode`, `findByCampaignId` (공통 `find` SQL 블록)

### 외부 API (이 레포에선 미관찰, funding-core 경유)
- 사업자 등록증 OCR 서비스
- 국세청 사업자 진위확인 API
- 은행 계좌 실명 확인 API (NICE 등)

### 접근 테이블 합계
`Campaign`, `UserProfile`, `PhotoCommon`, `PersonalMessageBoardAnswerTime`, `webpages_UsersInRoles`, `Department`(추정), `Employee`(추정), `MakerInvitation`, `MakerInvitationCode`, `MakerInvitationBenefit`, `CampaignContractInfo`, `CampaignContractRepresentative`, `BankCode`, `PersonalVerificationResult`

### 주요 enum
- `ProjectPhase`, `ProjectFilter` — My Project 필터
- `MakerInvitationBenefitType` — 초대 혜택 유형
- `MakerInvitationUserType` — INVITER / INVITEE
