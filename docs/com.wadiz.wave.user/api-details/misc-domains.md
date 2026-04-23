# 잡다 도메인 상세 스펙 (privacy · terms · message · coupon · verification/bank · push · maker · link · sourcingclub)

> **기록 범위**: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/<domain>/controller` 와 `src/main/resources/mapper` 하위에서 직접 관측 가능한 호출만 기록. `com.wadiz.wave.infrastructure.*`, `com.wadiz.wave.publisher.*`, `com.wadiz.wave.crypto.*`, `com.wadiz.wave.repository.wadiz.UserAccountInfosMapper` 등 공용 repository/gateway 모듈의 내부 구현은 이 repo 소스만으로 확인 불가하므로 "외부" 또는 "공용 모듈"로 표시. MyBatis XML 본문은 있는 그대로 인용한다.

---

## 문서 목차

1. [privacy](#1-privacy) — 휴면/탈퇴/정보파기 라이프사이클
2. [terms](#2-terms) — 약관 동의/철회/이력, V2 signup 조회
3. [message](#3-message) — 알림톡 발송 (회원가입)
4. [coupon](#4-coupon) — 회원가입 쿠폰 발급
5. [verification/bankaccount](#5-verificationbankaccount) — 신한은행 1원이체 & 출금계좌
6. [push](#6-push) — 타게팅 푸시 대상 조회
7. [maker](#7-maker) — 메이커 언어 설정
8. [link](#8-link) — 친구추천/최근행동 기반 추천
9. [sourcingclub](#9-sourcingclub) — 소싱 클럽 회원 관리
10. [통합 외부 의존성](#통합-외부-의존성)
11. [경계 및 미탐색 영역](#경계-및-미탐색-영역)

---

## 1. privacy

### 개요
개인정보 보호 라이프사이클 5단계를 구성한다.

1. **휴면 전환** (`InactiveAccountController`): `UserProfile.UserStatus = 'NM'` → `'IA'`.
2. **휴면 해제 (복호화)** (`DecodingAccountReactivateController`, `@Deprecated`): `DecodingUserProfile` 에서 복호화된 값을 이용해 `UserProfile` 복원 후 `InactiveAccountManager.LastStatus = 'RA'`. "복원 테이블도 삭제되었음" 주석 기준 deprecated 상태.
3. **강제 탈퇴** (`PrivacyDropoutController`): `UserProfile.UserStatus = 'DO'`, 관련 데이터 삭제, CRM Publish.
4. **정보 파기 관리** (`DestructionPrivacyController`): `DestructionPrivacyManager` 에 파기 예정/완료 스케줄 관리.
5. **계정 상태 공통 조회** (`CommonPrivacyController`): 휴면/탈퇴 여부 통합 조회 + 전화번호 강제 초기화.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| POST | `/api/v1/users/commonPrivacy/findAccountStatus` | CommonPrivacyController | 계정상태 조회 (userId) |
| POST | `/api/v1/users/commonPrivacy/isInactivated/userName` | CommonPrivacyController | 휴면여부 by UserName |
| POST | `/api/v1/users/commonPrivacy/isInactivated/connectingInfo` | CommonPrivacyController | 휴면여부 by CI |
| POST | `/api/v1/users/commonPrivacy/findAccountStatus/type/{findType}/value/{findValue}` | CommonPrivacyController | 휴면여부 by Type/Value |
| DELETE | `/api/v1/users/commonPrivacy/mobile-number` | CommonPrivacyController | 모바일번호 강제 초기화 |
| POST | `/api/v1/users/destructionPrivacy/find/schedule` | DestructionPrivacyController | 파기대상 조회 (스케줄) |
| GET | `/api/v1/users/destructionPrivacy/find/overdue` | DestructionPrivacyController | 파기 Overdue 대상 |
| POST | `/api/v1/users/destructionPrivacy/find/keywords` | DestructionPrivacyController | 파기대상 조회 (관리) |
| POST | `/api/v1/users/destructionPrivacy/register` | DestructionPrivacyController | 파기대상 등록 |
| PUT | `/api/v1/users/destructionPrivacy/modify` | DestructionPrivacyController | 파기여부 등록 |
| PUT | `/api/v1/users/destructionPrivacy/destruct` | DestructionPrivacyController | 파기 실행 |
| POST | `/api/v1/users/inactiveAccount/isInactivated` | InactiveAccountController | 휴면상태조회 |
| POST | `/api/v1/users/inactiveAccount/find/inactiveAccounts` | InactiveAccountController | 휴면예정자 조회 |
| POST | `/api/v1/users/inactiveAccount/find/inactiveAccounts/drop` | InactiveAccountController | 탈퇴처리대상 조회 |
| POST | `/api/v1/users/inactiveAccount/inactivate` | InactiveAccountController | 휴면처리 |
| POST | `/api/v1/users/inactiveAccount/reactivate` | InactiveAccountController | 휴면해제 |
| POST | `/api/v1/users/inactiveAccount/isDuplicateUserName` | InactiveAccountController | 휴면상태 계정 중복 |
| POST | `/api/v1/users/inactiveAccount/isValidForInactiveAccount` | InactiveAccountController | 휴면처리불가 여부 |
| POST | `/api/v1/users/inactiveAccount/modifyPassword` | InactiveAccountController | 휴면계정 패스워드 변경 |
| GET | `/api/v1/users/inactiveAccount/retroactive/{referenceTime}` | InactiveAccountController | 소급 대상 조회 |
| POST | `/api/v1/users/inactiveAccount/retroactive/{userId}` | InactiveAccountController | 소급 휴면처리 |
| POST | `/api/v1/users/privacy/decoding/reactivate` | DecodingAccountReactivateController | 휴면해제 (복호화) — **@Deprecated** |
| DELETE | `/api/v1/users/privacy/dropout/manual` | PrivacyDropoutController | 강제 탈퇴 |
| DELETE | `/api/v1/users/privacy/dropout/manual/user` | PrivacyDropoutController | 강제 탈퇴 (회원정보) |
| DELETE | `/api/v1/users/privacy/dropout/inactivated` | PrivacyDropoutController | 휴면 강제 탈퇴 (IA 한정) |
| DELETE | `/api/v1/users/privacy/dropout/leftover-inactivated` | PrivacyDropoutController | 휴면해제 불가 휴면회원 탈퇴 |

### CommonPrivacyController — `CommonPrivacyController.java:27`
`CommonPrivacyService` (privacy/service/CommonPrivacyService.java:37) 를 위임.

- **POST `/findAccountStatus`**: `@RequestBody Integer userId` → `findCurrentAccountStatus(userId)` → `findInactivateAccountInfo(targetUserId)` — 다음 순서로 상태 판정.
  1. `destructionPrivacyMapper.selectDestructionAccountByUserId` → `SELECT DropOutId as DestructionId FROM wadiz_db.UserDropOutLog WHERE UserId = #{userId}` (mapper/wadiz/privacy/destructionPrivacy-mapper.xml:122).
  2. `inactiveAccountMapper.selectInactiveAccountByUserId` → `SELECT ... FROM InactiveAccountManager WHERE UserId = #{userId}` (mapper/privacy/inactiveAccount-mapper.xml:73).
  3. 활성회원이면 `wadizMapper.selectArchivalDataForUserInfo` + `selectArchivalDataForEquityInfo` (mapper/wadiz/privacy/inactiveAccountByWadiz-mapper.xml:66,106).
  4. `AES256Util.decWadizKey` 로 실명 복호화 (공용 crypto 모듈).
- **POST `/isInactivated/userName`**: `String userName` → `AES256Util.encWadizKey(userName)` 후 `selectInactiveAccountByUserName('IA', encUserName)` (mapper/privacy/inactiveAccount-mapper.xml:12).
- **POST `/isInactivated/connectingInfo`**: `String connectingInfo` → `isInactivatedByConnectingInfo` — `SELECT count(*) FROM InactiveAccountManager WHERE JSON_EXTRACT(ArchivalDataForEquityInfo, '$.CI') = #{connectingInfo} AND LastStatus = #{lastStatus}` (mapper/privacy/inactiveAccount-mapper.xml:109). JSON_EXTRACT 로 CI 를 휴면 아카이브에서 검색.
- **POST `/findAccountStatus/type/{findType}/value/{findValue}`**: `isInactivatedByFindType` — `SELECT UserId FROM InactiveAccountManager WHERE LastStatus = 'IA' AND (JSON_EXTRACT(ArchivalDataForUserInfo, '$.${findType}') = #{findValue} or JSON_EXTRACT(ArchivalDataForEquityInfo, '$.${findType}') = #{findValue})` (mapper/privacy/inactiveAccount-mapper.xml:117). `${findType}` 이 **문자열 치환**이라는 점 주의.
- **DELETE `/mobile-number`**: `ClearMobileNumberType`(BY_USER_NAME/BY_USER_ID) + userNames/userIds 택1. `@Transactional("privacyTxManager")` (CommonPrivacyService.java:352/388). 흐름: `userAccountInfosMapper.detailByUser{Name,Id}` → `clearMobileNumberByUserId` (공용 mapper) → `userAppContactMapper.deleteConnectedUsersByConnectedUserId` → `subscriberGateway.getSubscriberInfo(userId).ifPresent(sub -> subscriberGateway.deleteSubscriberPhone(sub.getSubscriberKey()))` (infrastructure/notification, 외부 구독자 시스템).

### DestructionPrivacyController — `DestructionPrivacyController.java:29`
`DestructionPrivacyService` (privacy/service/DestructionPrivacyService.java:33) 위임.

- **POST `/find/schedule`**: `selectPrivacyDestructionInfoBySchedule` — `DestructionPrivacyManager` × `UserDropOutLog` JOIN, `DestructionDueDate = #{destructionDueDate} AND IsDestruct = FALSE` (mapper/wadiz/privacy/destructionPrivacy-mapper.xml:12).
- **GET `/find/overdue`**: `selectOverduePrivacyDestructionInfo` — `DestructionDueDate < #{dueDate} AND IsDestruct = FALSE LIMIT 0, #{size}` (destructionPrivacy-mapper.xml:34).
- **POST `/find/keywords`**: `selectPrivacyDestructionInfoByKeywords` — 관리자용 조회 (destructionPrivacy-mapper.xml:53).
- **POST `/register`**: `registerDestructionPrivacy(Integer targetUserId)` — `RetentionGroup` enum 전체에 대해 `INSERT INTO DestructionPrivacyManager (DestructionDueDate = DATE_ADD(NOW(), INTERVAL ${destructionPeriod} DAY), UserId, IsDestruct=FALSE, RetentionGroupName, Registered = UserDropOutLog.WhenCreated) ... ON DUPLICATE KEY UPDATE Updated = NOW()` (destructionPrivacy-mapper.xml:86).
- **PUT `/modify`**: `updateDestructInfo` — `UPDATE DestructionPrivacyManager SET IsDestruct = true, Updated = NOW(), UpdatedBy = #{updatedBy} WHERE DestructionId = #{destructionId}` (destructionPrivacy-mapper.xml:102).
- **PUT `/destruct`**: `destructDestructionPrivacy` — 동적 테이블/컬럼 SQL. `UPDATE ${destructionTable} SET <foreach>${data.keyword} = #{data.value}</foreach> WHERE ${destructionKeyWords} = #{destructionKeyValue}` (destructionPrivacy-mapper.xml:111). `SERIAL` keyword 는 `BankMapper.getUserSerial` + `CryptUtil.hashSHA256` 으로 해시 생성 (DestructionPrivacyService.java:154). `TransactionLogNo` keyword 는 `getVirtualAccountNo(UserId)` → `selectTransactionLogNo(VirtualAccountNo)` 로 여러 건 반복 (DestructionPrivacyService.java:172).

### InactiveAccountController — `InactiveAccountController.java:27`
`InActiveAccountService` (privacy/service/InActiveAccountService.java:43) 위임. 협력: `InactiveAccountByPrivacyMapper`, `InactiveAccountByWadizMapper`, `CrmGatewayPublisher`(publisher), `TermsService`.

- **POST `/inactivate`**: 휴면 처리. `insertInactiveAccount`(`InactiveAccountManager UPSERT`, mapper/privacy/inactiveAccount-mapper.xml:46) + `updateArchivalDataForUserInfo`/`ForEquityInfo`(mapper/wadiz/privacy/inactiveAccountByWadizMapper.xml:152/162, 동적 컬럼 Update) + `kickAppUserInfo`(`UPDATE DvcSessionInfo SET UserId = -1, AuthKey = '__NON_LOGIN' WHERE UserId = #{userId}`, inactiveAccountByWadiz-mapper.xml:214). 이후 `crmGatewayPublisher.publishInactiveInfo` (외부 퍼블리셔) + `termsService.rejectByInactive(userId)` (terms 참조).
- **POST `/reactivate`**: 휴면 해제. `updateReactiveAccount`(LastStatus='RA', inactiveAccount-mapper.xml:64) + `updateArchivalDataForUserInfo`/`ForEquityInfo` 로 `UserProfile`/`TbPersonalUserInfo` 복원.
- **POST `/find/inactiveAccounts`**: `selectInactiveAccountByPeriod` — `referenceTime` 기준 `inactivePeriod` 일 전 마지막 로그인 시점 계산 (inactiveAccountByWadiz-mapper.xml:12). `UserProfile.WhenLastLogon` 과 `DvcSessionInfo.UpdateDate(max)` 중 큰 값을 `lastLogOnDate` 로 삼는다.
- **POST `/find/inactiveAccounts/drop`**: `selectInactiveAccountForDrop` — IA 상태 + `Inactivated <= date_sub(referenceTime, interval inactivePeriod day)` (inactiveAccount-mapper.xml:28).
- **POST `/isValidForInactiveAccount`**: 3개 SELECT count(*) — `isReward` (BackingPayment/Shipping/RewardRefund 조합으로 미반환/미발송 여부, inactiveAccountByWadiz-mapper.xml:174), `isEquity` (투자펀딩 정산 대기, 173+), `isWNine` (`TbPremiumMembershipUser` 유효 기간 체크, 205).
- **POST `/modifyPassword`**: `updateInactiveAccountPassword` — `WadizPassWordUtils` 로 해시 후 `UPDATE InactiveAccountManager SET Password WHERE InactiveId AND UserId` (inactiveAccount-mapper.xml:126).
- **GET `/retroactive/{referenceTime}`**: `selectInactiveAccountByRetroactive` — 365일 고정 (inactiveAccountByWadiz-mapper.xml:39).
- **POST `/retroactive/{userId}`**: 지정 userId 하나만 휴면 처리 + 아카이빙.

### DecodingAccountReactivateController — `DecodingAccountReactivateController.java:29` (@Deprecated)
복호화된 `DecodingUserProfile` 테이블을 이용한 휴면 해제. 컨트롤러에서 loop 돌며 실패 목록 분리 수집.

- **POST `/reactivate`**: `DecodingInactivateAccountDto` 리스트 루프:
  1. `reactivateProcessing(inactiveId)` (propagation=REQUIRES_NEW) — `reactivateMapper.updateUserProfile` (reactiveAccount-mapper.xml:45) → `updateInactiveAccountManager`(LastStatus='RA', reactiveAccount-mapper.xml:69) → `updateTbPersonalUserInfo` (복호화된 SSN/CI/DI 복원, reactiveAccount-mapper.xml:30) → `updateDecodingUserProfile`(`reactivated = DATE_FORMAT(CURDATE(), '%Y%m%d')`, reactiveAccount-mapper.xml:76).
  2. `revertMarketingTermsProcessing(userId, revertMarketingTerms)` — `selectTermsAcceptHistory` (최근 전전 이력, `ORDER BY Id DESC LIMIT 1,1`, reactiveAccount-mapper.xml:83) → `updateTermsAccept` (REJECT→ACCEPT, reactiveAccount-mapper.xml:92) → `deleteTermsAcceptHistory` (reactiveAccount-mapper.xml:102).
  3. `progressingAsyncTasks` — `@Async` 3종 (ProgressingAsyncTasksService.java:46/63/73/86):
     - `modifySubscriberInfo`: `subscriberGateway.getSubscriberInfo`, 없으면 `createSubscriberInfo`, 있으면 `reactiveSubscriberInfo`.
     - `sendMQToReactivatedUserId`: `crmGatewayPublisher.publishReactivateInfo(userId.toString())` (공용 publisher, braze?).
     - `sendMailToReactivatedUserId`: `normalMailV2Gateway.sendReactivateCommentMail(transactionId, userName, templateData)` (외부 메일 게이트).
     - `sendAlimTalkToReactivatedUserId`: `messageService.sendAlimTalkForReactivate` — 알림톡 템플릿 `wadiz.alim-talk.template.code.reactivate: B_WD_004_02_53808` (MessageServiceImpl.java:43).

### PrivacyDropoutController — `PrivacyDropoutController.java:26`
`PrivacyDropoutService` (privacy/service/PrivacyDropoutService.java:20) 위임. 내부적으로 `PrivacyDropoutProcessingService` (PrivacyDropoutProcessingService.java:43) 호출.

- **DELETE `/manual`**: `List<PrivacyDropoutDto>` 직접 수신 → `dropout(list, isInactivated=false)`.
- **DELETE `/manual/user`**: `List<PrivacyUserIdAndUserNameDropoutDto>` → `selectPrivacyDropoutDto` (mapper/privacy/dropAccountByWadiz-mapper.xml:57): `UserProfile LEFT JOIN webpages_OAuthMembership social ON provider='kakao'` + `CASE WHEN accntType = 'N1000' THEN false ELSE true END AS hasShinHanAccount` → `dropout(list, false)`.
- **DELETE `/inactivated`**: IA 상태 필수 (`validExistInactiveUserStatus` → `hasInactivatedUserStatus` `WHERE UserStatus = 'IA'`, mapper/privacy/dropAccountByWadiz-mapper.xml:43).
- **DELETE `/leftover-inactivated`**: `selectPrivacyDropoutDtoForLeftoverInactivatedUser` — `reasonText='휴면계정강제탈퇴'` 고정 (dropAccountByWadiz-mapper.xml:73).

**`dropout` 공통 흐름** (PrivacyDropoutService.java:45):
1. `validParameters`: (inactivated 한정)`validExistInactiveUserStatus`, `validExistDropoutStatus`(`UserStatus='DO'` 중복 체크), `validExistMembership` (`membershipGateway.getMembershipAvailableList` 현재 유효 멤버십 있으면 skip), `validSHinHanAccountDelete` (`payApiGateway.getVirtualAccount` → `realBalance > 0` 이면 skip, 아니면 `payApiGateway.deleteShinHanAccount`).
2. `userAccountInfosMapper.selectSNSInfoByUserId` (공용 mapper) — 삭제 **전** 에 SNS 정보 미리 확보.
3. `dropoutProcessor` (REQUIRES_NEW, `privacyTxManager`):
   - `insertUserDropOutLog` (dropAccountByWadiz-mapper.xml:6)
   - `updateUserProfile` (UserName=#{userId}, NickName='탈퇴계정', UserStatus='DO', PhotoId=null, dropAccountByWadiz-mapper.xml:13)
   - `deletePasswordInfo` (`DELETE FROM webpages_Membership WHERE UserId`, :23)
   - `deleteProviderInfo` (`DELETE FROM webpages_OAuthMembership WHERE UserId`, :30)
   - `deleteDvcSessionInfo` (`DELETE FROM DvcSessionInfo WHERE UserId`, :37)
   - `registerDestructionLog` — `RetentionGroup` enum 전체에 대해 `INSERT DestructionPrivacyManager ... SELECT ... FROM UserDropOutLog ORDER BY WhenCreated DESC LIMIT 1 ON DUPLICATE KEY UPDATE Updated = NOW()` (dropAccountByWadiz-mapper.xml:89).
   - `modifyInactiveAccountManager` — `updateDropAccount` LastStatus='DO' (inactiveAccount-mapper.xml:135).
   - `userAppContactService.dropData`, `blockCommandService.unblockAll`, `recommendationUserInfoService.dropRecommendationRejectionData`, `termsService.rejectByDropOut`.
4. `doRemainingWork`: `crmGatewayPublisher.publishDropOutInfo`, `followV3Service.dropUser`, `userAccountInfosService.unLinkSns(snsInfoEntities)`, `subscriberGateway.deleteSubscriberInfo`.

### DB 테이블 (privacy)
- `wadiz_db.UserProfile` — UserStatus 전이 (NM/IA/DO) 핵심.
- `wadiz_db.UserDropOutLog` — 탈퇴 사유/일자 기록.
- `wadiz_db.DestructionPrivacyManager` — 파기 스케줄 (DestructionId, DestructionDueDate, IsDestruct, RetentionGroupName).
- `wadiz_wave_privacy.InactiveAccountManager` — 휴면 아카이브 (`ArchivalDataForUserInfo` / `ArchivalDataForEquityInfo` JSON 컬럼).
- `wadiz_wave_privacy.DecodingUserProfile`, `DecodingTbPersonalUserInfo` — 복호화된 스냅샷 (deprecated 경로).
- `wadiz_db.webpages_Membership`, `webpages_OAuthMembership`, `DvcSessionInfo` — 탈퇴 시 삭제.
- `wadiz_db.TbPersonalUserInfo` — 복호화 복원 대상.
- `VirtualAccountPublished`, `VirtualAccountTransactionLog` — `destruct` 커스텀 로직에서 조회.

### 특이사항
- **`${findType}` 문자열 치환** (`isInactivatedByFindType`) 은 JSON path 를 직접 SQL 에 삽입한다. 호출자 측 입력 검증 필수.
- **`UserStatus = 'DO'` 탈퇴 시 `UserName = #{userId}` 로 덮어쓰기** — UserName 컬럼이 숫자 문자열이 된다 (dropAccountByWadiz-mapper.xml:15).
- **@Deprecated** `DecodingAccountReactivateController` 는 테이블 삭제됐다는 클래스 Javadoc 기준 실제 호출 불가 상태. 여전히 `ProgressingAsyncTasksService` 의 재사용 가능한 `@Async` 작업들(알림톡/메일/MQ/Subscriber) 때문에 소스는 남아있음.
- `destruct` PUT 은 동적 SQL (`${destructionTable}`, `${destructionKeyWords}`). 위험도 높음.
- `RetentionGroup` enum 은 소스에서 직접 확인 가능 (privacy/constant/RetentionGroup.java) — 본 문서 범위 외.

---

## 2. terms

### 개요
약관 동의/철회/이력. 두 컨트롤러 `TermsController` (v1) 와 `TermsV2Controller` (v2, signup 플로우 전용). 스토리지는 모두 `terms_db` 스키마.

`ServiceCode`: funding, equity, startup (ServiceCode.java:12).
`TermsType`: membership, use, privacy, marketing, maker_use, maker_privacy, maker_3rd_offer, funding_offer, virtual_deposit_account (TermsType 열거 확인 필요).
`Acceptance`: ACCEPT, REJECT.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| GET | `/api/v1/users/terms/service` | TermsController | ServiceCode↔TermsType 맵 (TEST ONLY) |
| GET | `/api/v1/users/terms/accepter/{userId}` | TermsController | 동의 약관 조회 (사용자) |
| GET | `/api/v1/users/terms/service/{serviceCode}/accepter/{userId}` | TermsController | 이용약관 조회 (서비스별) |
| POST | `/api/v1/users/terms/accepter/{userId}` | TermsController | 약관 추가 동의 |
| POST | `/api/v1/users/terms/reject/{userId}` | TermsController | 이벤트/혜택 철회 |
| DELETE | `/api/v1/users/terms/accepter/{userId}` | TermsController | 전체 약관 철회 (TEST ONLY) |
| GET | `/api/v1/users/terms/marketing/accepter/{userId}` | TermsController | 마케팅 동의 상태 (ADMIN) |
| GET | `/api/v1/users/terms/marketing/{serviceCode}/accepter/{userId}` | TermsController | 마케팅 서비스별 |
| GET | `/api/v1/users/terms/marketing/accepter/{userId}/history` | TermsController | 마케팅 이력 (ADMIN, Pageable) |
| GET | `/api/v2/terms/{flowType:signup}` | TermsV2Controller | signup 플로우 약관 목록 |

### TermsController 상세 — `terms/controller/TermsController.java:26`
`TermsService` → `TermsServiceImpl` (terms/service/TermsServiceImpl.java:26).

- **공통**: 모든 userId 가 `<= 0` 이면 `UnauthorizedException` (HTTP 401). `EMPTY_USER_ID_LOGGING` 포맷 사용.
- **GET `/accepter/{userId}`**: `getAcceptedTerms` → `termsAcceptMapper.getListByAcceptance(userId, 'ACCEPT')` (mapper/wadiz/terms/termsAccept-mapper.xml:40). 결과를 `TermsAcceptConverter.toServiceAndTerms` 로 변환.
- **GET `/service/{serviceCode}/accepter/{userId}`**: `getTerms(userId, serviceCode, TermsType.use)` → `getTermsByServiceCodeAndTermsType` (termsAccept-mapper.xml:54).
- **POST `/accepter/{userId}`** (약관 추가 동의): `TermsUpdateRequest` 수신.
  1. `checkUpdatableRequest`: `TermsAcceptRequestValidator.isOptionChangeRequest` 참이면 이미 mandatory 약관을 동의한 상태인지 검증 (`serviceCode.isSubscribe(acceptList)`) — 미가입이면 `PreconditionFailException` (412).
     아니면 `isServiceJoinRequest` 검증 실패 시 `InvalidRequestException` (400).
  2. `upsert(userId, ACCEPT, request)`:
     - `termsAcceptMapper.upsert(list)` — `INSERT INTO terms_db.TermsAccept (UserId, ServiceCode, TermsType, Acceptance, Updated) VALUES ... ON DUPLICATE KEY UPDATE Updated = IF(Acceptance = values(Acceptance), Updated, now()), Acceptance = values(Acceptance)` (termsAccept-mapper.xml:5).
     - `termsAcceptHistoryMapper.saveChanges(list)` — `INSERT ... WHERE IFNULL((SELECT Acceptance FROM TermsAcceptHistory ... ORDER BY Created DESC LIMIT 1), '') <> #{acceptance}` (mapper/wadiz/terms/termsAcceptHistory-mapper.xml:5). 즉 직전 값과 다를 때만 히스토리 적재.
     - marketing + ACCEPT 만 추려 `termsAcceptMapper.upsertNotified(list)` — `INSERT INTO terms_db.AcceptNotification ... ON DUPLICATE KEY UPDATE Notified = now()` (termsAccept-mapper.xml:16).
- **POST `/reject/{userId}`**: 동일 로직이나 `Acceptance.REJECT` 로 upsert + history.
- **DELETE `/accepter/{userId}`** (전체 철회): `rejectByDropOut(userId)`:
  - `getListByAcceptance(ACCEPT)` 으로 현재 동의 목록 조회.
  - `termsAcceptMapper.rejectByDropOut` — `UPDATE TermsAccept SET Updated = IF(Acceptance=#{acceptance},Updated,now()), Acceptance = #{acceptance} WHERE UserId = #{userId}` (termsAccept-mapper.xml:26).
  - 위 목록을 history 로 전환 저장.
- **GET `/marketing/accepter/{userId}`**: `getTermsList(userId, marketing)` → `getListByTermsType` (termsAccept-mapper.xml:47).
- **GET `/marketing/accepter/{userId}/history`**: `getMarketingHistory` (Pageable) — `SELECT Id, UserId, ServiceCode, TermsType, Acceptance, Created FROM terms_db.TermsAcceptHistory WHERE UserId = ${userId} and TermsType = 'marketing' order by Created desc LIMIT ${offset}, ${size}` (termsAcceptHistory-mapper.xml:24). `${userId}` 문자열 치환 주의.

### TermsV2Controller 상세 — `terms/controller/TermsV2Controller.java:27`
`TermsV2Service` (TermsV2Service.java:13).

- **GET `/{flowType:signup}`** (path variable 이 literally `signup` 만 허용): `platformType` (WEB/IOS/ANDROID, default WEB), `Locale` → `getSignupTerms(flowType, country, language, platformType)`.
- `countryCode` 변환: `KR` 는 그대로, 그 외는 전부 `US` 로 매핑 (TermsV2Service.java:23).
- SQL (termsAccept-mapper.xml:63) — WEB 기본 플랫폼 설정을 사용하되 IOS/ANDROID 는 `TermsConfigCountry` 를 한 번 더 JOIN 하여 `COALESCE(TCC.IsRequired, TCC_DEFAULT.IsRequired)` 식으로 오버라이드:
  ```
  FROM terms_db.TermsConfigCountry TCC_DEFAULT
    INNER JOIN terms_db.TermsContentLanguage TCL
      ON TCL.ServiceCode = TCC_DEFAULT.ServiceCode AND TCL.TermsType = TCC_DEFAULT.TermsType AND TCL.LanguageCode = #{language}
    LEFT OUTER JOIN terms_db.TermsConfigCountryLanguage TCCL
      ON TCCL.CountryCode = TCC_DEFAULT.CountryCode AND TCCL.ServiceCode = TCC_DEFAULT.ServiceCode AND TCCL.TermsType = TCC_DEFAULT.TermsType AND TCCL.LanguageCode = TCL.LanguageCode
    [WEB가 아닐 때만] LEFT OUTER JOIN TermsConfigCountry TCC ON ... AND TCC.PlatformType = #{platformType} AND TCC.IsEnabled = true
  WHERE TCC_DEFAULT.PlatformType = 'WEB' AND TCC_DEFAULT.FlowType = #{flowType} AND TCC_DEFAULT.CountryCode = #{country} AND TCC_DEFAULT.IsEnabled = true
  ORDER BY COALESCE(TCC.DisplayOrder, TCC_DEFAULT.DisplayOrder)
  ```
- 허용되지 않은 platformType 은 HTTP 400 + `ExceptionErrorVo.code = HttpStatus.BAD_REQUEST.name()`.

### DB 테이블 (terms)
- `terms_db.TermsAccept` (UserId, ServiceCode, TermsType, Acceptance, Updated)
- `terms_db.AcceptNotification` (UserId, ServiceCode, TermsType, Notified) — marketing 동의 시 알림 트리거
- `terms_db.TermsAcceptHistory` (Id, UserId, ServiceCode, TermsType, Acceptance, Created) — 변경 이력
- `terms_db.TermsConfigCountry` (CountryCode, FlowType, ServiceCode, TermsType, PlatformType, IsRequired, IsVisible, IsEnabled, DisplayOrder)
- `terms_db.TermsContentLanguage` (ServiceCode, TermsType, LanguageCode, Name, Description)
- `terms_db.TermsConfigCountryLanguage` (CountryCode, ServiceCode, TermsType, LanguageCode, DetailsUrl)

### 특이사항
- V1 경로 (`/api/v1/users/terms/...`) 는 **AuthN/AuthZ 가 컨트롤러 레벨에 없음** — userId PathVariable 만으로 판단, Spring Security 설정 의존. (실제 Security 체인은 이 문서 범위 외.)
- V2 는 `flowType:signup` 정규식으로 signup 만 허용. 향후 확장 시 변경 예정으로 보이는 구조.
- `rejectByInactive` 는 외부에서 호출되는 서비스 메서드만 존재하고 public 엔드포인트가 없음. `InActiveAccountService` 의 `inactivate` 흐름에서 호출 (privacy 도메인 참조).

---

## 3. message

### 개요
카카오 알림톡 발송 전용 서비스. 외부 `AlimTalkGateway` (infrastructure/notification) 위임, 템플릿 코드 기반.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| POST | `/api/v1/users/message/alim-talk/receiver/{userId}/sign-up` | MessageController | 회원가입 알림톡 발송 |

### MessageController 상세 — `message/MessageController.java:21`
- **POST `/alim-talk/receiver/{userId}/sign-up`**: `@PathVariable @Valid Integer userId` → `messageService.sendAlimTalkForSignUp(userId)` → ResponseEntity.ok (body = 코드 String).
- 예외 핸들러:
  - `AlimTalkUserInfoEmptyException` → 400 + MessageErrorVo(code, message).
  - `SendAlimTalkFailException` → 502 + MessageErrorVo.
  - 기타 Exception → 500 + 빈 MessageErrorVo.

### MessageService 동작 — `message/service/MessageServiceImpl.java:27`
`sendAlimTalkForSignUp(userId)`:
1. `userAccountInfosMapper.selectMobileNumberInfoByUserId(userId)` (공용 mapper, SQL 이 repo 외부) → `UserAccountMobileNumberInfo`.
2. `userId < 0` 이거나 mobileNumber 공백이면 `AlimTalkUserInfoEmptyException`.
3. `AlimTalkRequestDto.builder()`:
   - `tid = UUID.randomUUID().toString()`
   - `priority = "NORMAL"`
   - `templateCode = TEMPLATE_CODE_JOIN` (`wadiz.alim-talk.template.code.join`, default `B_WD_004_02_51517`)
   - `templateNo = TEMPLATE_NUM_JOIN` (default `3100`)
   - `payloads[0].phoneNumber` + `maps` (`MessageBodyProfile.getBodyProfile(templateCode).getPropertyMap()` + `nickName` 덮어쓰기).
4. `alimTalkGateway.sendSingleAlimTalk(request).orElseThrow(SendAlimTalkFailException)`.
5. `responseDto.getCode()` 가 `"SUCCESS"` 가 아니면 `SendAlimTalkFailException`.

### 외부 의존 (관측 가능 범위)
- `com.wadiz.wave.infrastructure.notification.AlimTalkGateway` — 외부 알림톡 제공사 (NHN Cloud Toast/카카오 비즈메시지 등) 호출. 실제 HTTP 호출 코드는 공용 infrastructure 모듈 내부.
- 템플릿 코드 네이밍 규칙 `B_WD_004_02_NNNNN` — 외부 코드 체계.

### 별도 메서드 (엔드포인트 없음)
`sendAlimTalkForReactivate(mobileNumber, templateData)` — privacy 의 `ProgressingAsyncTasksService.sendAlimTalkToReactivatedUserId` 에서 호출되지만 deprecated 경로. 템플릿 `wadiz.alim-talk.template.code.reactivate` (default `B_WD_004_02_53808`).

---

## 4. coupon

### 개요
회원가입 축하 쿠폰 1종 발급 (UserCouponType.signup). 외부 `CouponGateway` 로 위임.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| POST | `/api/v1/users/coupon/user/{userId}/type/{couponType}` | IssueCouponController | 쿠폰 발급 |

### IssueCouponController 상세 — `coupon/controller/IssueCouponController.java:20`
- **POST `/user/{userId}/type/{couponType}`** : `couponType` 은 `UserCouponType` enum (현재 `signup("SIGN_UP")` 만 존재, UserCouponType.java:7). `issueCouponService.issueCoupon(userId, couponType.getValue())` 호출 후 200.
- 예외:
  - `IssueCouponFailException` → **HTTP 202 Accepted** 로 반환 (비즈니스 실패 시그널).
  - 기타 Exception → 500.

### IssueCouponService — `coupon/service/IssueCouponService.java:17`
```java
Locale locale = LocaleContextHolder.getLocale();
IssueCouponInfoDto dto = userCouponMapper.selectIssueCouponInfoByCouponTypeAndCountryCode(couponType, locale.getCountry());
couponGateway.issueCoupon(IssueCouponInfo.issue(userId, dto));
```

### DB & SQL
`UserCouponMapper` (mapper/user/account-coupon-mapper.xml:3):
- `selectIssueCouponInfoByCouponType` (구, 예약된 구 테이블):
  ```sql
  SELECT templates, periodUntil as period
    FROM wadiz_user.UserCouponTemplate
   WHERE couponType = #{couponType} AND openOrNot is true
  ```
- `selectIssueCouponInfoByCouponTypeAndCountryCode` (현재 서비스 사용):
  ```sql
  SELECT templates, period_until as period
    FROM wadiz_user.user_coupon_template
   WHERE coupon_type = #{couponType}
     AND (country_code = #{countryCode} OR country_code IS NULL)
     AND open_or_not = 1
   ORDER BY (CASE WHEN country_code = #{countryCode} THEN 1 ELSE 2 END) ASC,
            registered_at DESC
   LIMIT 1
  ```
  즉 국가 매칭 row 가 있으면 우선, 없으면 `country_code IS NULL` 기본값 fallback.

### DB 테이블
- `wadiz_user.user_coupon_template` (coupon_type, country_code, templates, period_until, open_or_not, registered_at) — 다국가 지원.
- (legacy) `wadiz_user.UserCouponTemplate` — 쿼리 존재하나 현재 서비스 경로에서는 호출되지 않음.

### 외부 의존
- `com.wadiz.wave.infrastructure.coupons.CouponGateway.issueCoupon(IssueCouponInfo)` — 외부 쿠폰 시스템 호출. 실제 발급 트랜잭션은 쿠폰 도메인 내부.

### 특이사항
- 실패 시 HTTP 2xx 로 응답 (202 Accepted). 호출자는 body 의 `code`/`message` 로 판정 필요.

---

## 5. verification/bankaccount

### 개요
신한은행 Open API 를 호출하여 **수취계좌 조회 + 1원이체 + 출금계좌 등록** 을 처리. 서비스 대부분 `@Transactional` + `AuthInfo` (세션 기반 `AuthUtil.getAuthInfo`).

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| GET | `/api/v1/users/verifications/bankaccounts/banklist` | BankController | 은행코드 조회 (신한 동기화 + cache) |
| GET | `/.../bankCode/{bankCode}/bankAccount/{bankAccount}` | BankController | 수취계좌 확인 |
| POST | `/.../transfer/penny` | BankController | 1원이체 실행 |
| POST | `/.../transfer/penny/answer` | BankController | 1원이체 메모 확인 |
| GET | `/.../transfer/penny/summation/userId/{userId}` | BankController | 유저 1원이체 상태 |
| GET | `/.../transfer/penny/answerLog/pennyTransferNo/{pennyTransferNo}` | BankController | 1원이체 응답로그 |
| PUT | `/.../transfer/penny/reset` | BankController | 1원이체 리셋 |
| GET | `/.../bankAccount/withdrawAccount/userId/{userId}` | BankController | 사용자 출금계좌 조회 |
| POST | `/.../bankAccount/withdrawAccount` | BankController | 개인 출금계좌 등록 |
| POST | `/.../bankAccount/corpWithdrawAccount` | BankController | 법인/투자조합 출금계좌 등록 |

### BankController 상세 — `verification/bankaccount/BankController.java:39`
`BankService` (verification/bankaccount/service/BankService.java:52) + `ShinhanClient` (…/client/ShinhanClient.java:44) + `Converter` (DTO→도메인).

- **GET `/banklist`** (`@Cacheable("banklist")`):
  1. `ShBankListRequest` → `client.execute(req, ShBankList.class)` (Shinhan HTTP).
  2. `mapper.removeUnusedBankCode(banks)` — `UPDATE BankCode SET IsDeleted = TRUE WHERE BankCode NOT IN (...)` (mapper/wadiz/bank-mapper.xml:41).
  3. `mapper.insertBankCode(banks)` — `INSERT ... ON DUPLICATE KEY UPDATE IsDeleted = FALSE` (bank-mapper.xml:30).
  4. `mapper.selectBankList()` — `SELECT BankCode AS code, BankName AS name FROM BankCode WHERE IsDeleted = FALSE ORDER BY OrderNo ASC` (bank-mapper.xml:51).
  5. 신한 호출 실패해도 로컬 `BankCode` 테이블로 fallback.

- **GET `/bankCode/{bankCode}/bankAccount/{bankAccount}`**: `getBankAccount` — `ShBankAccountRequest(bankCode, account, transactionIdGenerator.next())` → 신한 호출 → `Converter.convert(ShBankAccount)`.

- **POST `/transfer/penny`** (@Transactional):
  1. `getSessionUserSummation` — `AuthUtil.getAuthInfo().userId` → `mapper.getUserSerial(userId)` → `SELECT UserId, ssn1, ssn2 FROM TbPersonalUserInfo` (bank-mapper.xml:64) → `serial = CryptUtil.hashSHA256(ssn1+ssn2, ssn1)` → `getPennyTransferUserSummationForUpdate(serial)` (`SELECT ... FROM PennyTransferUserSummation WHERE Serial = ... FOR UPDATE`, bank-mapper.xml:75).
  2. 기존 transferNo 있으면 `userSummation.validateTransfer()` (도메인 검증).
  3. `getBankAccount(bankCode, account)` — 신한 수취계좌 확인.
  4. `mapper.getUserName(userId)` → `SELECT RealName FROM TbPersonalUserInfo` (bank-mapper.xml:58) → `AES256Util.decWadizKey` 로 실명 복호화.
  5. 실명 ≠ 수취인명 이면 `verificationMapper.checkForeigner(userId)` (`SELECT (CASE WHEN COUNT(*) = 1 THEN TRUE ELSE FALSE END) FROM IdCardVerifyLog WHERE UserId AND VerifyType = 3`, mapper/wadiz/verification-mapper.xml:4) 이 true 이면 10자 앞부분 부분일치 허용.
  6. `memo = memoGenerator.generate()` → `ShPennyTransferRequest` 신한 호출 → `insertPennyTransfer` (`INSERT INTO PennyTransfer (Serial, DepositBankCode, DepositBankAccount, DepositMemo) VALUES (..., SHA1(#{depositMemo}))`, bank-mapper.xml:81) → `increaseTransferCount` (`INSERT ... ON DUPLICATE KEY UPDATE TransferCount = TransferCount + 1, Updated = NOW()`, bank-mapper.xml:86).

- **POST `/transfer/penny/answer`** (@Transactional):
  1. `getSessionUserSummation` + `userSummation.validateResponse()`.
  2. `insertPennyTransferResponseLog` (`INSERT ... VALUES (#{summation.pennyTransferNo}, SHA1(#{memo}))`, bank-mapper.xml:94).
  3. `getPennyTransferMemo` (`... IF(STRCMP(DepositMemo, SHA1(#{memo})) = 0, 1, 0) AS correct ...`, bank-mapper.xml:99) — SHA1 비교.
  4. 맞으면 `ResponseCount=0, TransferCount=0, IsConfirmed=true`, 틀리면 `ResponseCount++` 후 `setResponseCount` (bank-mapper.xml:112).

- **GET `/transfer/penny/summation/userId/{userId}`**: `mapper.getUserSerial` → `hashSHA256` → `getPennyTransferUserSummation` (FOR UPDATE 없음, bank-mapper.xml:70).

- **GET `/transfer/penny/answerLog/pennyTransferNo/{pennyTransferNo}`**: `getAnswerLog` — `... LIMIT 0, 200` (bank-mapper.xml:134).

- **PUT `/transfer/penny/reset`** (@Transactional): `resetPennyTransfer` (bank-mapper.xml:170, `TransferCount=0, ResponseCount=0`) + `insertResetPennyTransferLog` (bank-mapper.xml:178).

- **GET `/bankAccount/withdrawAccount/userId/{userId}`**: `getUserWithdrawAccount` (bank-mapper.xml:121) + `getBankName(bankCode)` (bank-mapper.xml:128) 조합.

- **POST `/bankAccount/withdrawAccount`** (@Transactional):
  1. 신한 `getBankAccount` 로 예금주명 실조회.
  2. `validateRegisterUserWithdrawAccount` — 세션 serial 조회 → 직전 `PennyTransfer` + `LastAnswerLog` 검증 (bankCode/bankAccount/memo 일치).
  3. 기등록 계좌 있으면 `updateUserWithdrawAccount` (bank-mapper.xml:156), 없으면 `registerUserWithdrawAccount` (bank-mapper.xml:151) + `registerUserWithdrawAccountLog` (bank-mapper.xml:165).

- **POST `/bankAccount/corpWithdrawAccount`** (@Transactional): 법인·투자조합.
  1. 신한 `getBankAccount` → 예금주명 일치 검증.
  2. `mapper.getUserAccntType(userId)` (bank-mapper.xml:183):
     - `N1000` (개인) 이면 `getCorpInfoCount(userId)` (`SELECT COUNT(*) FROM TbBusinessLicenseInfo WHERE RegUserId`, bank-mapper.xml:189) > 0 이어야 한다 (사업자 등록).
     - `NC300`/`NA300` 외 타입은 `UnauthorizedException`.
  3. `setUserWithdrawAccount` 로 저장.

### DB 테이블 (bank)
- `BankCode` — 신한 은행 목록 캐시.
- `TbPersonalUserInfo` — 실명/주민번호(SSN) 보관.
- `PennyTransfer` (PennyTransferNo, Serial, DepositBankCode, DepositBankAccount, DepositMemo=SHA1, Registered) — 1원이체 기록.
- `PennyTransferUserSummation` (SummationNo, PennyTransferNo, Serial, IsConfirmed, TransferCount, ResponseCount) — 사용자별 요약.
- `PennyTransferResponseLog` (ResponseLogNo, PennyTransferNo, ResponseMemo=SHA1, Registered) — 메모 응답 로그.
- `PennyTransferSummationResetLog` (SummationNo, ResetUserId, Description) — 리셋 이력.
- `UserWithdrawAccount` / `UserWithdrawAccountLog` — 출금계좌 본판/이력.
- `IdCardVerifyLog` — 외국인 여부 체크 (VerifyType=3).
- `TbBusinessLicenseInfo` — 법인 사업자 확인.
- `ShinhanTransactionNo` — 신한 transaction id 시퀀스 생성 (mapper/wadiz/shinhan-mapper.xml:5, `INSERT INTO ShinhanTransactionNo VALUES ()` auto increment).

### 외부 의존 (신한 API)
`ShinhanClient` (ShinhanClient.java:44):
- `@Value("${shinhan.url}")`, `${shinhan.apiKey}`, `${shinhan.secret}`, `${shinhan.encoding}`.
- `HMAC` 서명 (Mac, SecretKeySpec, Base64) — 구체 알고리즘은 나머지 코드 확인 필요.
- 전용 RestTemplate `ShinhanApiConfig.ShinhanRestTemplate` qualifier.
- 로거 두 개: `rcode` (응답 코드 전용), `tlog` (transaction 로그 전용).
- ObjectMapper 로 JSON 직렬화.

### 특이사항
- **DepositMemo/ResponseMemo 는 SHA1** — 원문 저장 안 함 (SQL 에 `SHA1(#{memo})`). 
- **`FOR UPDATE`** 로 userSummation 락 획득 (bank-mapper.xml:75).
- **AES256Util** 과 **CryptUtil(SHA256)** 은 공용 `com.wadiz.wave.crypto` 모듈.
- `banklist` 엔드포인트가 `@Cacheable` + 신한 동기화 동시 수행 — 캐시 워밍과 RDB 동기화가 한 번에 일어난다.

---

## 6. push

### 개요
타게팅 푸시 대상 `UserId` 리스트 조회. wadizReplication DB(투자 투자·회원가입·계정타입·오픈예정) 읽기 전용.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| POST | `/api/v1/users/pushTarget/count` | PushTargetController | 대상 카운트 (list size) |
| POST | `/api/v1/users/pushTarget/list` | PushTargetController | 대상 userId 리스트 (Pageable) |

### PushTargetController 상세 — `push/PushTargetController.java:18`
- **POST `/count`**: `getByPushTarget(request, null).size()` — 페이징 없이 전체 조회 후 size. 카운트 쿼리가 별도로 존재하지 않음.
- **POST `/list`**: `getByPushTarget(request, new Pageable(page, size))`.

### PushTargetService — `push/service/PushTargetService.java:23`
`setParameter` 에서 다음 플래그를 동적으로 세팅 (converter → `PushTargetConverter.toPushTarget`):
- `isAccountType` = accountTypes 배열 존재.
- `isAccountCreated` = startdateForCreated OR enddateForCreated 존재.
- `isAccountInvestment` = numberOfInvestment + rangeType 지정 + investment 기간 존재.
- `isComingSoonAll` = 전 캠페인 대상.
- `isComingSoon` = 캠페인ID 선택.

조건이 하나도 없으면 `ServerSideException("조회조건이 누락되었습니다.")`.

### SQL 구조 (mapper/wadizReplication/push/push-target-mapper.xml)
선택 브랜치가 **4가지 `<sql>` 조각** 으로 분기:
1. `_COMING_SOON` — `TbComingSoonApplicant` INNER JOIN `TbComingSoonMain ON CampaignType='I' AND ProgressStatusCode='CSPS000010'`, `up.AccntType = 'N1000'` 개인회원 한정.
2. `_NUMBER_OF_INVESTMENT_IS_NOT_ZERO` — `TbInvest INNER JOIN UserProfile` GROUP BY UserId HAVING `count ${pushTarget.rangeTypeValue} #{pushTarget.numberOfInvestment}` (즉 `>=`, `<=`, `=` 등 비교 연산자를 `${...}` 문자열 치환으로 주입).
3. `_NUMBER_OF_INVESTMENT_IS_ZERO` — `UserProfile LEFT OUTER JOIN (투자자 집계) WHERE ivt.UserId IS NULL`.
4. `_NUMBER_OF_INVESTMENT_IS_NULL` — 투자 조건 없음, 계정타입 + 가입일만.

최종:
```sql
SELECT E.UserId
FROM (
  <choose>...</choose>
) E
LIMIT ${offset}, ${size}
```

### DB 테이블
- `wadizReplication.UserProfile`, `TbInvest`, `TbComingSoonApplicant`, `TbComingSoonMain` — 모두 읽기 복제본.
- `UserIvstSt = 'ID10'` 조건 = 정상 투자완료.

### 특이사항
- **`rangeTypeValue` 가 `${...}` 치환** (`HAVING count ${pushTarget.rangeTypeValue} #{pushTarget.numberOfInvestment}`) — SQL 주입 위험. `RangeType` enum 에서 검증되는 것으로 보임(코드 확인 필요).
- count 엔드포인트가 list 조회 후 size 를 반환 — 대량 조회 시 메모리 부담.
- 페이징 미설정 시 `LIMIT 0, 0` 이 될 가능성(PushTargetService.java:111).

---

## 7. maker

### 개요
메이커(프로젝트 개설자)의 기본 언어 설정. `wadiz_maker.maker_info` 테이블을 `wadiz_db.UserProfile.LanguageCode` 와 병합 조회.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| PUT | `/api/v1/makers/{userId}/language` | MakerInfoController | 메이커 언어 저장 |
| GET | `/api/v1/makers/{userId}/language` | MakerInfoController | 메이커 언어 조회 |
| POST | `/api/v1/makers/languages` \| `/languages/bulk` | MakerInfoController | 메이커 언어 bulk 조회 |

### MakerInfoController 상세 — `maker/MakerInfoController.java:19`
- **PUT `/{userId}/language`**: `MakerLanguageDto.Request{language}` → `makerInfoService.saveMakerLanguage(userId, language)` → `upsertLanguage` (mapper/wadiz/maker/maker-info-mapper.xml:5):
  ```sql
  INSERT INTO wadiz_maker.maker_info (user_id, language_code)
  VALUES (#{userId}, #{language})
  ON DUPLICATE KEY UPDATE language_code = #{language}
  ```
- **GET `/{userId}/language`**: `findLanguageByUserId` (maker-info-mapper.xml:11):
  ```sql
  SELECT COALESCE(MI.language_code, UP.LanguageCode) as language
    FROM wadiz_db.UserProfile UP
    LEFT OUTER JOIN wadiz_maker.maker_info MI ON UP.UserId = MI.user_id
   WHERE UP.UserId = #{userId}
  ```
  결과를 `MakerLanguageUtil.toSupportedLanguage` 로 정규화 (enum `SupportedMakerLanguage` 기반).
- **POST `/languages`** / **`/languages/bulk`** (path alias): `BulkRequest{userIds}` → `findLanguagesByUserIds` (maker-info-mapper.xml:19):
  ```sql
  SELECT UP.UserId as userId,
         COALESCE(MI.language_code, UP.LanguageCode) as language
    FROM wadiz_db.UserProfile UP
    LEFT OUTER JOIN wadiz_maker.maker_info MI ON UP.UserId = MI.user_id
   WHERE UP.UserId IN <foreach ...>
  ```

### DB 테이블 (maker)
- `wadiz_maker.maker_info` (user_id, language_code) — PK = user_id.
- `wadiz_db.UserProfile.LanguageCode` — 유저 기본 언어 fallback.

### 특이사항
- `maker_info` 가 없으면 `UserProfile.LanguageCode` 로 fallback — 메이커 전용 언어가 별도 저장되기 전까지 기본값 채움.
- `@Transactional(value = "wadizTxManager", readOnly = true)` — 별도 tx manager 지정.
- `MakerLanguageProperties`, `SupportedMakerLanguage` enum 은 application.yml 의 프로퍼티와 연동되는 것으로 보임 (maker/config, maker/enums 경로) — 구체 매핑은 본 문서 범위 외.

---

## 8. link

### 개요
"친구가 팔로우하는 사람", "팔로워 추천", "친구가 활동한 프로젝트 추천" 을 조회. 외부 **UserLinkGateway** (infrastructure/link — Neo4j 기반 `kr.wadiz.user.link` 서비스 연동 추정) 을 호출해 원시 추천을 받은 뒤, MyBatis 로 프로필·사진을 조립하고 Redis 에 캐싱한다.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| GET | `/api/v1/link/me/{me}/follow` | UserLinkController | 친구추천 (팔로우) |
| GET | `/api/v1/link/action/recently` | UserLinkController | 최근 행동 기반 팔로워 추천 |
| GET | `/api/v1/link/action/{userId}/follow/project` | UserLinkController | 친구가 활동한 프로젝트 추천 |

### UserLinkController 상세 — `link/UserLinkController.java:29`
- **GET `/me/{me}/follow`**: query `target` (default `FOLLOW_OF_FOLLOW`), `size` (30), `cached` (true).
  - `target = FOLLOW_YOU` 이면 `userLinkFollowService.getFollowMeFriends(me, target, size, cached)`.
  - 그 외(`FOLLOW_OF_FOLLOW`, `FOLLOWER_OF_FOLLOW`) 는 `getFriendsOfFriends(me, target, size, cached)`.
  `UserLinkTarget` enum (link/constant/UserLinkTarget.java:8) — `(depth, linkType)`: FOLLOW_OF_FOLLOW(2,"END_USER"), FOLLOWER_OF_FOLLOW(1,"FOLLOWER_OF_END"), FOLLOW_YOU(1,"FOLLOW_YOU").
- **GET `/action/recently`**: `me` (optional), `contentSortType` (default `PERFORMED`). `userLinkActionService.getRecommendationRecentlyFollower(me, contentSortType)`.
- **GET `/action/{userId}/follow/project`**: `isRandom`(true), `sortType`("DESC"), `minActionCount`(5), `actionSize`(6), `projectSize`(1), `size`(1). `userLinkActionService.getFollowActionProjectLink(...)`.

예외 처리:
- `UserLinkGatewayException` → 502 + `UserLinkErrorVo`.
- `UserLinkRecentlyServiceException` → 200 + 빈 list (조용히 실패).
- Exception → 500.

### UserLinkFollowServiceImpl — `link/service/UserLinkFollowServiceImpl.java:28`
`getFriendsOfFriends(userId, target, size, cached)`:
1. `infrastructureService.getRecommendationFollowerToLinkApi(userId, target.linkType, target.depth, size, false)` — 외부 UserLinkGateway 호출.
2. `cached==true` 이면 Redis 조회. 키: `user-link:<activeProfile>:<type lower>:<userId>:<size>[:<renewalTimestamp>]` (UserLinkCacheServiceImpl.java:32). 키 패턴 검증은 split ":" 길이 5 또는 6.
3. `integrationFriendsOfFriends`:
   - `userLinkMapper.selectUserInfoForFollower(me, targetUserIds)` — `UserProfile` + `PhotoCommon` 조인. Block/RecommendationRejection/Follow 필터 + `_FOLLOWER_COUNT` subquery:
     ```sql
     , (SELECT COUNT(*) FROM wadiz_wave_follow.Follow F1 WHERE F1.FollowingUserId = up.UserId AND F1.OptIn = true) AS followerCount
     ```
   - 필터 SQL(`_NOT_BLOCK_AND_FOLLOWER`):
     - 추천 거절 안 한 User (`URR.IsRejected = FALSE` 또는 row 없음).
     - 이미 팔로우 안 한 User.
     - 블락 안 한 User.
     DBA 성능 테스트 주석 포함 (DB-1968).
   - `infrastructureService.getFundingCountInfo(userIds)` → `campaignGateway.getFundingCountByUserIds` (외부).
   - `getStoreCountInfo(userIds)` → `storeGateway.getFundingCountByUserIds` (외부 store 서비스).
   - `getMembershipAvailableInfo(userIds)` → `membershipGateway.getMembershipAvailableList` (외부 membership 서비스 — `MembershipGateway`).
   - profile photo 기본이미지 랜덤 매핑 (`userLinkConvert.convertProfileImageUrlToRandomDefault`).
4. Redis `set` + `get` 후 반환. 실패 시 `UserLinkServiceException(FAIL_CACHING)`.

`getFollowMeFriends`:
- `userLinkMapper.selectUserInfoForFollowMe(me)` (userLinkInfo-mapper.xml:57) — `Follow fo INNER JOIN UserProfile up` 으로 **나를 팔로우하는데 내가 팔로우 안 하는** 사용자만 선별 (`LEFT OUTER JOIN Follow ft ... ft.FollowerUserId is null`). `_COMMON_FOLLOW_COUNT` 서브쿼리로 공통 팔로워 수 계산.
- 외부 gateway 호출 없이 DB 조회만으로 처리.

### UserLinkActionServiceImpl — `link/service/UserLinkActionServiceImpl.java:27`
- `getRecommendationRecentlyFollower(me, contentSortType)`:
  - `infrastructureService.getRecommendationRecentlyFollowerToLinkApi(userId, contentSortType.linkType)` — 외부.
  - `userLinkMapper.selectUserInfoForRecentlyFollower(userIds)` (userLinkInfo-mapper.xml:75).
  - `membershipGateway.getMembershipAvailableList` 로 멤버십 여부.
  - `UserLinkRecommendationType.findRecommendationTypeByLinkType` 으로 추천 타입별 메시지 생성.
- `getFollowActionProjectLink(userId, isRandom, sortType, minActionCount, actionSize, projectSize, size)`:
  - `infrastructureService.getFollowActionProject(...)` — 외부.
  - `userLinkMapper.selectUserPhotoInfo(userIds)` (userLinkInfo-mapper.xml:90) — 프로필 사진 맵.
  - `action.isShowNickName` false 이면 `WadizRuleUtil.getCustomNickName(null)` 로 마스킹.
  - `profileImageService.getProfileImageUrlWithFixedRandomDefault` 로 기본이미지 선정.

### DB & Redis
- `wadiz_db.UserProfile`, `wadiz_db.PhotoCommon` — 마스터 (타 도메인과 공유).
- `wadiz_wave_follow.Follow` (FollowerUserId, FollowingUserId, OptIn, Updated), `UserBlocking`, `UserRecommendationRejection` — 팔로우 그래프.
- Redis key prefix `user-link:<profile>:...`.

### 외부 의존 (관측 가능)
- `com.wadiz.wave.infrastructure.link.UserLinkGateway` — Neo4j 기반 link 서비스 프록시 (`kr.wadiz.user.link` 로 추정되나 본 repo 에서는 gateway 인터페이스만 관측).
- `CampaignGateway`, `StoreGateway`, `MembershipGateway` — 각 도메인 서비스 HTTP 호출 (infrastructure 모듈).
- `ProfileImageService` — `com.wadiz.wave.user.account.service` (본 repo 내 account 도메인).

### 특이사항
- `UserLinkRecentlyServiceException` 은 **200 + 빈 배열** 반환 — 컨트롤러에서 정책적으로 삼켜 버림.
- 캐시 키에 `activeProfile` (local/rc/live) 이 들어가 환경 격리.
- Follow/Block/Rejection 필터는 LEFT JOIN 방식이 아닌 **이중 NOT EXISTS/EXISTS** 패턴 (성능 최적화 주석).
- `getFriendsOfFriends` 는 gateway 응답이 비어있으면 즉시 빈 결과 반환 (캐시 갱신 없음).

---

## 9. sourcingclub

### 개요
"소싱 클럽" (제조사·벤더 사전 등록) 회원 관리. 가입/조회 2 엔드포인트 + CRM 연동.

### 엔드포인트 테이블

| Method | Path | Controller | Description |
|---|---|---|---|
| GET | `/api/v1/sourcing-club/members/{userId}` | SourcingClubController | 회원 조회 |
| POST | `/api/v1/sourcing-club/members/{userId}` | SourcingClubController | 회원 가입 |

### SourcingClubController 상세 — `sourcingclub/controller/SourcingClubController.java:30`
- **GET `/members/{userId}`**: `sourcingClubService.getMemberInfo(userId)` → 없으면 `SourcingClubMemberNotFoundException` (404).
- **POST `/members/{userId}`**: `@Valid SourcingClubJoinRequest`:
  ```java
  @NotBlank @Size(max=50)  firstName
  @NotBlank @Size(max=50)  lastName
  @NotBlank @Email @Size(max=200)  email
  @NotBlank @Size(max=150) companyName
  @NotBlank @Size(max=100) jobTitle
  Boolean marketingConsent
  ```
  `sourcingClubService.joinSourcingClub(userId, request)` 호출 후 `201 Created` + `Location` 헤더.

예외 핸들러 (도메인 코드 반환):
- `MethodArgumentNotValidException` → 400 + `INPUT_VALIDATION_ERROR`.
- `SourcingClubMemberNotFoundException` → 404.
- `SourcingClubAlreadyJoinedException` → 409.
- `SourcingClubSameUserEmailRequiredException` → 400 + `SAME_USER_EMAIL_REQUIRED`.
- Exception → 500.

### SourcingClubService 동작 — `sourcingclub/service/SourcingClubService.java:21`
`getMemberInfo(userId)`:
- `sourcingClubMapper.findByUserId(userId)` (mapper/wadiz/sourcingclub/sourcing-club-mapper.xml:6):
  ```sql
  SELECT user_id as userId, first_name as firstName, last_name as lastName, email,
         company_name as companyName, job_title as jobTitle,
         marketing_consent as marketingConsent, registered_at as registeredAt
    FROM wadiz_user.sourcing_club
   WHERE user_id = #{userId}
  ```
- null 이면 NotFoundException.

`joinSourcingClub(userId, request)` (@Transactional wadizTxManager):
1. `userAccountInfosMapper.selectByUserId(userId)` (공용 mapper) → UserAccount 의 `email` 과 request.email 이 다르면 `SourcingClubSameUserEmailRequiredException`.
2. `marketingConsent == null` 이면 `true` 로 강제 세팅 (주석: "현재 marketingConsent는 항상 true로 설정").
3. `sourcingClubMapper.insertSourcingClubMember(...)` (sourcing-club-mapper.xml:20):
   ```sql
   INSERT INTO wadiz_user.sourcing_club
     (user_id, first_name, last_name, email, company_name, job_title, marketing_consent)
   VALUES (#{userId}, #{firstName}, #{lastName}, #{email}, #{companyName}, #{jobTitle}, #{marketingConsent})
   ```
   `DuplicateKeyException` 잡으면 `SourcingClubAlreadyJoinedException`.
4. 가입 성공 후 `crmApiGateway.sendSourcingClubInfo(userId, request)` — 외부 CRM 시스템 전송.

`deleteSourcingClubMember(userId, deletedReason)` (엔드포인트 없음, 내부 호출용):
- `deleteSourcingClubMember` (sourcing-club-mapper.xml:26):
  ```sql
  UPDATE wadiz_user.sourcing_club
     SET first_name='', last_name='', email='', company_name='', job_title='',
         is_deleted = TRUE, deleted_reason = #{deletedReason}
   WHERE user_id = #{userId}
  ```
  즉 **soft delete + PII 필드 blank-out**. 탈퇴 플로우에서 호출될 것으로 보이나, 본 도메인에서는 public 호출 경로 없음.

### DB 테이블
- `wadiz_user.sourcing_club` (user_id, first_name, last_name, email, company_name, job_title, marketing_consent, registered_at, is_deleted, deleted_reason) — PK user_id.

### 외부 의존
- `com.wadiz.wave.infrastructure.crm.CrmApiGateway.sendSourcingClubInfo(userId, request)` — 외부 CRM (Braze/HubSpot 등 — 본 repo 에서는 확인 불가).

### 특이사항
- 이메일이 `UserAccount.email` 과 일치해야 가입 가능 — 본인 이메일로만 신청 가능.
- `marketingConsent` 는 클라이언트 값 무시하고 true 고정 (코드 주석에 명시).
- `deleteSourcingClubMember` 는 soft delete 이면서 PII 를 blank 로 덮어써 탈퇴 시 데이터 보존 불가. 호출 경로는 `privacy` 탈퇴 플로우와 연계 가능성이 있으나 코드상 직접 연결은 확인되지 않음.

---

## 통합 외부 의존성

소스에서 `import com.wadiz.wave.infrastructure.*` 또는 `import com.wadiz.wave.publisher.*` 로 드러난 외부 의존성:

| 도메인 | 게이트웨이 | 사용 위치 | 비고 |
|---|---|---|---|
| privacy | `SubscriberGateway` | CommonPrivacyService (모바일번호 초기화), PrivacyDropoutProcessingService (탈퇴), ProgressingAsyncTasksService | 구독자(Subscriber) 관리 외부 API |
| privacy | `PayApiGateway` | PrivacyDropoutProcessingService (가상계좌 잔액/삭제) | `com.wadiz.wave.infrastructure.pays` — 결제/가상계좌 |
| privacy | `MembershipGateway` | PrivacyDropoutProcessingService | 멤버십 유효 여부 |
| privacy | `NormalMailV2Gateway` | ProgressingAsyncTasksService (휴면해제 메일) | 메일 외부 게이트웨이 |
| privacy | `CrmGatewayPublisher` | InActiveAccountService, PrivacyDropoutProcessingService, ProgressingAsyncTasksService | Kafka/MQ publisher (reactivate / dropout / inactive) |
| message | `AlimTalkGateway` | MessageServiceImpl | 알림톡 — 템플릿 코드 기반 (`B_WD_004_02_NNNNN`) |
| coupon | `CouponGateway` | IssueCouponService | 외부 쿠폰 발급 시스템 |
| verification | 신한은행 Open API | ShinhanClient | `shinhan.url`/`apiKey`/`secret` — HMAC 서명, 전용 RestTemplate |
| link | `UserLinkGateway` | UserLinkInfrastructureServiceImpl | Neo4j link 서비스 (별도 backend) |
| link | `CampaignGateway` | UserLinkInfrastructureServiceImpl | 펀딩 건수 조회 |
| link | `StoreGateway` | UserLinkInfrastructureServiceImpl | 스토어 건수 조회 |
| link | `MembershipGateway` | UserLinkInfrastructureServiceImpl, UserLinkActionServiceImpl | 멤버십 가용 여부 |
| sourcingclub | `CrmApiGateway` | SourcingClubService | CRM 회원 정보 전송 |

모든 Gateway 인터페이스 구현체와 실제 HTTP/Kafka 호출은 `com.wadiz.wave.infrastructure.*` 공용 모듈에 있어 이 repo 안에서는 확인 불가.

### 공용 mapper / crypto / publisher (확인 가능한 이름만)
- `com.wadiz.wave.repository.wadiz.UserAccountInfosMapper` — privacy/sourcingclub 에서 공통 사용 (detailByUserName, detailByUserId, clearMobileNumberByUserId, selectByUserId, selectSNSInfoByUserId, selectMobileNumberInfoByUserId). SQL 정의는 본 repo 외.
- `com.wadiz.wave.crypto.AES256Util` / `CryptUtil` / `WadizPassWordUtils` — 공용 암호화 모듈.
- `com.wadiz.wave.publisher.CrmGatewayPublisher` — Kafka publisher 추정 (publishInactiveInfo / publishReactivateInfo / publishDropOutInfo 메서드 관측).

---

## 경계 및 미탐색 영역

### 1. 배치/스케줄러 위치
- `DestructionPrivacyController.POST /find/schedule` 은 **외부 스케줄러가 호출하는 엔드포인트** 로 보이나, cron 트리거가 이 repo 소스에는 없다. `@Scheduled` annotation 은 privacy 도메인에 존재하지 않음.
- `InactiveAccountController.POST /find/inactiveAccounts{,drop}`, `POST /inactivate`, `POST /reactivate` 도 동일하게 외부 스케줄러가 REST 호출하는 구조. 배치 주체는 별도 repo 로 추정 (미확인).
- 본 repo 에서 `@Scheduled` 검색 범위 외 결과는 본 문서에 반영하지 않음.

### 2. 휴면 전환 규칙 (period/referenceTime)
`selectInactiveAccountByPeriod` (mapper/wadiz/privacy/inactiveAccountByWadiz-mapper.xml:12) 은 `referenceTime` 과 `inactivePeriod` 를 파라미터로 받는다. `retroactive` 경로는 **365일 고정** (mapper:39). "1년 미접속 = 휴면" 규칙이 하드코딩된 위치. 정책 변경 시 XML 수정 필요.

### 3. `${}` 문자열 치환 사용 지점 (보안)
- `destructionPrivacy-mapper.xml:112` `UPDATE ${destructionTable} SET ${data.keyword} = ... WHERE ${destructionKeyWords} = ...`
- `inactiveAccount-mapper.xml:121` `JSON_EXTRACT(..., '$.${findType}')`
- `push-target-mapper.xml:38` `HAVING count ${pushTarget.rangeTypeValue} ...`
- `termsAcceptHistory-mapper.xml:27` `WHERE UserId = ${userId}`
- `bank-mapper.xml` 내부 페이징 조각 `LIMIT ${startNum}, ${pageSize}`

이 치환들은 호출 측 (서비스/컨트롤러) 에서 enum / int 검증 전제로 설계되어 있으나, 실제 주입 방어는 각 서비스 코드에서 개별 확인 필요.

### 4. `@Deprecated` 경로와 잔존 의존성
`DecodingAccountReactivateController` 가 deprecated 지만, 그 서비스 클래스(`DecodingAccountReactivateProcessingService`, `ProgressingAsyncTasksService`) 는 여전히 존재하며 `sendAlimTalkToReactivatedUserId` / `sendMailToReactivatedUserId` / `sendMQToReactivatedUserId` 가 유효한 `@Async` 메서드. 다른 컨트롤러에서도 재사용 가능성이 있음 (본 repo 내 재호출 지점은 확인되지 않음).

### 5. Link 도메인의 Redis vs Neo4j 경계
- Redis: 최종 응답 `UserLinkVo` 캐싱 (TTL 은 `CacheManagerService` 내부 — 본 repo 외).
- Neo4j: `UserLinkGateway` 내부. 이 repo 는 gateway 포트만 관측.
- 두 계층 사이에 "renewalTimestamp" 일치 여부로 캐시 무효화 — gateway 가 이 값을 내려주는 구조.

### 6. 신한은행 API 의 응답 파싱 / 에러코드
`ShinhanClient.execute` 는 본 조사에서 상단만 확인. 응답 파싱(`ShResponseDataHeader`), 실패 케이스 매핑, 재시도 로직은 미탐색. `rcode`/`tlog` 별도 logger 존재.

### 7. sourcing_club 테이블의 탈퇴 연결
`deleteSourcingClubMember` 는 service 에만 존재하고 privacy 의 `dropoutProcessor` 에서 호출되지 않는다. 소싱 클럽 탈퇴가 회원 탈퇴 시 자동으로 일어나는지는 본 repo 소스만으로는 확인되지 않음 — 다른 서비스에서 호출하거나, 별도 batch 에서 처리할 가능성이 있다.

### 8. Shinhan/nicepay 결제 도메인과의 경계
`DestructionPrivacyService.destruct` 에서 `TransactionLogNo` keyword 로 `VirtualAccountPublished`/`VirtualAccountTransactionLog` 을 건드리고, `PrivacyDropoutProcessingService.validSHinHanAccountDelete` 에서 `payApiGateway.deleteShinHanAccount` 를 호출한다 — 결제 도메인(pay-api, nicepay-api) 에 대한 간접 의존. 실제 가상계좌 생성·해지는 **결제 도메인** 소유.

### 9. TermsAcceptHistory 의 `ORDER BY Id DESC LIMIT 1,1` (재활성화)
`selectTermsAcceptHistory` (reactiveAccount-mapper.xml:83) 가 **가장 최근이 아니라 그 이전** 이력(LIMIT 1,1 = offset=1)을 가져온다. 이는 "휴면 진입 시 기록된 REJECT 이력" 이 가장 최근이라 그 직전 동의 이력을 가져오는 구조로 해석되나, 실제 보존 규약은 확인되지 않음.

### 10. V1 terms 엔드포인트의 권한
userId 가 PathVariable 에 있고 `userId <= 0` 만 막는 구조. 실제 "본인의 userId 인지" 확인은 Spring Security 필터/인터셉터에서 수행될 것으로 보이나 이 범위는 본 문서 밖.
