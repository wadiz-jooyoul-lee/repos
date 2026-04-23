# Account 도메인 상세 스펙

> **기록 범위**: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/*` 9개 컨트롤러와 해당 `service/*`, 그리고 `src/main/resources/mapper/wadiz/account/*`, `src/main/resources/mapper/wadiz/user/*` (user-locale*, user-timezone, user-settings, user-age-verification), `mapper/wadiz/privacy/*`, `mapper/privacy/dropAccountByWadiz-mapper.xml`, `mapper/wadiz/bank-mapper.xml`, `mapper/wadiz/verification-mapper.xml`, `mapper/wadiz/shinhan-mapper.xml` 에서 직접 관측 가능한 호출만 기록.
>
> - `wave_client`, `wave_data`, `wave_crypto` 등 사내 외부 jar (`com.wadiz.wave.user.account.drop.domain.DropAccountRequest`, `com.wadiz.wave.user.account.find.domain.RealName`, `com.wadiz.wave.user.account.common.domain.CommonAccountResponse`, `com.wadiz.wave.user.account.join.*`, `com.wadiz.wave.user.privacy.*`, `com.wadiz.wave.crypto.*` 등) 는 본 repo의 `src/main/java` 아래에 존재하지 않는다. 소스에서 직접 확인할 수 없는 내부 로직은 "외부 jar" 로 표시한다.
> - DropAccountService가 의존하는 `UserAppContactService.dropData`, `BlockCommandService.unblockAll`, `RecommendationUserInfoService.dropRecommendationRejectionData`, `TermsService.rejectByDropOut`, `SourcingClubService.deleteSourcingClubMember` 는 본 도메인 외 서비스이므로 호출 사실과 전달 인자까지만 기록.
> - 실제 테이블 DDL은 `ddl/` 디렉터리에 있지만 본 문서는 mapper XML에 나타나는 컬럼만 근거로 삼는다.

## 1. 개요

### 책임
`account` 도메인은 회원의 **메타 정보 / 프로필 이미지 / 로케일 / 시간대 / 설정 / 투자형(Equity) 가입 진행 상태 / 실명 조회 / 탈퇴** 를 담당한다. 9개 컨트롤러 604 LOC 는 다음 카테고리로 나뉜다.

| 카테고리 | 컨트롤러 | 설명 |
|---|---|---|
| 계정 정보 허브 | `UserAccountInfosController` | 다른 서비스가 user 메타를 한 번에 가져가는 핵심 API (verifyPassword, detail, SNS link, provider profile, birthDay 관리) |
| 실명 조회 | `FindAccountController` | 투자(equity)서비스용 `TbPersonalUserInfo.RealName` 조회 |
| 투자 가입 상태 | `JoinEquityAccountController` | 증권형 펀딩 가입 단계/프로모션/가상계좌/적격 여부 단계별 조회 |
| 탈퇴 | `DropAccountController` | 회원 탈퇴 원자적 처리 (11단계 연쇄) |
| 프로필 이미지 | `ProfileImageController` | 기본(랜덤) 프로필 이미지 URL 생성 |
| 로케일 | `UserLocaleController` | `LanguageCode`, `CountryCode` 조회/저장 + bulk |
| 타임존 | `UserTimeZoneController` | TimeZone 조회/저장 + 자동 설정 + bulk |
| 사용자 설정 | `UserSettingsController` | 생일 노출 여부 설정 (UserSettings SettingType=1) |
| 성인 인증 | `UserAgeVerificationController` | UserAgeVerification Expired 기준 조회 + bulk |

### `kr.wadiz.account` (OAuth2 IdP) 와의 역할 차이
- `kr.wadiz.account` (Boot 3.1 / Kotlin) = **OAuth2 인가서버 + 계정 핵심** (Auth 2.0). 인증/토큰 발급, 패스워드, 가입/로그인 흐름 담당 (CLAUDE.md 이정표).
- `com.wadiz.wave.user/account` = **레거시 모놀리식 User Platform 내부의 "계정 메타" 엔드포인트들**. 인증이 끝난 뒤 유저의 프로필·로케일·설정·탈퇴·투자 가입 단계·성인 인증 여부 등 **계정 상태를 읽고 쓰는 주변부 API**.
- `UserAccountInfosController.verifyPassword`(POST `/accounts/{userId}/password/verification`) 는 Auth 2.0 로 넘어가지 않은 레거시 호출자(예: 메이커센터·레거시 web)를 위해 `webpages_Membership.Password` 를 여전히 여기서 매칭한다.

### wave.user가 account 도메인을 계속 보유하는 이유 (관측 기반 추정)
- `webpages_Membership`, `webpages_OAuthMembership`, `UserProfile`, `TbPersonalUserInfo`, `TbProviderProfile`, `VirtualAccountPublished`, `UserJoinStepStatus`, `UserAgeVerification`, `UserSettings`, `TimeZoneInfo`, `GlobalCountry` 등 **레거시 wadiz_db 테이블 30여 개**를 직접 MyBatis로 참조하고, 이 테이블들은 다른 레거시 서비스(`com.wadiz.web`, `com.wadiz.adm`, `makercenter-be`, 투자 전용 API) 가 공유한다.
- 탈퇴는 `dropAccount` 하나에서 `UserDropOutLog`, `DestructionPrivacyManager`, `UserProfile`, `webpages_Membership`, `webpages_OAuthMembership`, `InactiveAccountManager`, Kakao/Line Gateway(연동 해제), `crmGatewayExchange` RabbitMQ 발행, `TermsService.rejectByDropOut`, 소싱클럽/차단/친구추천 정보 삭제를 원자적으로 수행해야 하므로, 타 서비스 분리가 비용이 크다.
- overview 문서도 "Signature V3 → `co.wadiz.api.community` 이관 중. 나머지는 유지보수 중심" 으로 명시 (`docs/com.wadiz.wave.user/com.wadiz.wave.user.md:62-123`).

---

## 2. 엔드포인트 전수 테이블

| # | Method | Path | Controller | Service 메서드 | 주 테이블 / 외부 |
|---|---|---|---|---|---|
| 1 | POST | `/api/v1/users/accounts/find/realname/list` | `FindAccountController.findRealNameForList` | `FindAccountRealNameService.findRealNameForList` | `TbPersonalUserInfo` |
| 2 | POST | `/api/v1/users/accounts/find/realname/unit` | `FindAccountController.findRealNameForUnit` | `FindAccountRealNameService.findRealNameForUnit` | `TbPersonalUserInfo` |
| 3 | POST | `/api/v1/users/accounts/{userId}/password/verification` | `UserAccountInfosController.verifyPassword` | `UserAccountInfosService.verifyPasswordByUserId` | `webpages_Membership` |
| 4 | GET | `/api/v1/users/accounts/type/{accountType}/count` | `UserAccountInfosController.findByAccountTypeCount` | `findByAccntType` | `UserProfile` |
| 5 | GET | `/api/v1/users/accounts/detail/{userId}` | `UserAccountInfosController.detail` | `UserAccountInfosService.detail` | `UserProfile` ⨯ `PhotoCommon` ⨯ `webpages_Membership` |
| 6 | GET | `/api/v1/users/accounts/type/{accountType}` | `UserAccountInfosController.findByAccountTypePage` | `findByAccntType(Pageable)` | `UserProfile` |
| 7 | GET | `/api/v1/users/accounts/type/{accountType}/all` | `UserAccountInfosController.findByAccountType` | `findByAccntType` | `UserProfile` |
| 8 | GET | `/api/v1/users/accounts/type/initRealNameAuth` | `UserAccountInfosController.initRealNameAuth` | `UserAccountInfosService.initRealName` | `TbPersonalUserInfo` |
| 9 | GET | `/api/v1/users/accounts/type/joinLimitClear` | `UserAccountInfosController.joinLimitClear` | `UserAccountInfosService.joinLimitClear` | `UserDropOutLog` |
| 10 | GET | `/api/v1/users/accounts/type/initMarketingParticipationHistory` | `UserAccountInfosController.initMarketingParticipationHistory` | `UserAccountInfosService.initMarketingParticipationHistory` | `MarketingParticipationHistory` |
| 11 | GET | `/api/v1/users/accounts/{userId}/linkedSNS` (Deprecated) | `UserAccountInfosController.getLinkedSNS` | `UserAccountInfosService.getLinkedSNS` | `webpages_OAuthMembership` |
| 12 | GET | `/api/v1/users/accounts/{userId}/social/link` | `UserAccountInfosController.getLinkedSocial` | `UserAccountInfosService.getLinkedSNS` | `webpages_OAuthMembership` |
| 13 | POST | `/api/v1/users/accounts/{userId}/social/{provider}` | `UserAccountInfosController.unLinkSocial` | `UserAccountInfosService.unLinkSns` | Kakao/Line HTTP |
| 14 | PUT | `/api/v1/users/accounts/{userId}/social/friends-count` | `UserAccountInfosController.putSocialFriendsCount` | `upsertProviderProfileFriendsCount` | `TbProviderProfile`, `TbProviderProfileLog` |
| 15 | PUT | `/api/v1/users/accounts/{userId}/social/profile` | `UserAccountInfosController.putProviderProfile` | `putProviderProfile` | `TbProviderProfile`, `TbProviderProfileLog` |
| 16 | GET | `/api/v1/users/accounts/{userId}/social/profile` | `UserAccountInfosController.getProviderProfile` | `getProviderProfile` | `TbProviderProfile` |
| 17 | PUT | `/api/v1/users/accounts/{userId}/birth-day` | `UserAccountInfosController.putBirthDay` | `putBirthDay` | `TbProviderProfile`, `TbProviderProfileLog` |
| 18 | GET | `/api/v1/users/accounts/{userId}/birth-day` | `UserAccountInfosController.getBirthDay` | `getBirthDay` | `TbProviderProfile` |
| 19 | DELETE | `/api/v1/users/accounts/{userId}/birth-day` | `UserAccountInfosController.deleteBirthDay` | `removeBirthDay` | `TbProviderProfile`, `TbProviderProfileLog` |
| 20 | GET | `/api/v1/users/equity/join/{encUserId}/mobile` | `JoinEquityAccountController.findPhoneNumber` | `JoinEquityAccountService.findPhoneNumber` | `UserProfile` |
| 21 | GET | `/api/v1/users/equity/join/{encUserId}/promotion` | `JoinEquityAccountController.findPromotion` | `findPromotion` | `TbUserRecordingInfo`, `TbPromotionCodeMaster` |
| 22 | GET | `/api/v1/users/equity/join/{encUserId}/virtual` | `JoinEquityAccountController.findVirtualAccount` | `findVirtualAccount` | `VirtualAccountPublished` |
| 23 | GET | `/api/v1/users/equity/join/{encUserId}/type` | `JoinEquityAccountController.findProfessionalAccount` | `findProfessionalAccount` | `UserProfile.AccntType` |
| 24 | GET | `/api/v1/users/equity/join/{encUserId}/step` | `JoinEquityAccountController.findSignUpStep` | `findSignUpStep(_,false)` | `UserJoinStepStatus` |
| 25 | GET | `/api/v1/users/equity/join/{encUserId}/status` | `JoinEquityAccountController.findCurrentStatus` | `findSignUpStep(_,true)` | `UserJoinStepStatus` |
| 26 | GET | `/api/v1/users/{userId}/age-verification` | `UserAgeVerificationController.getUserAgeVerification` | `UserProfileService.getUserAgeVerification` | `UserProfile` ⨯ `UserAgeVerification` |
| 27 | POST | `/api/v1/users/age-verifications/bulk` | `UserAgeVerificationController.getUserAgeVerifications` | `getUserAgeVerifications` | `UserProfile` ⨯ `UserAgeVerification` |
| 28 | PUT | `/api/v1/users/{userId}/location` (= `/locale`) | `UserLocaleController.saveUserLocale` | `UserProfileService.saveUserLocale` | `UserProfile`, `user_locale_history`, `TimeZoneInfo`, `GlobalCountry` |
| 29 | GET | `/api/v1/users/{userId}/location` (= `/locale`) | `UserLocaleController.getUserLocale` | `UserProfileService.getUserLocale` | `UserProfile` |
| 30 | POST | `/api/v1/users/locales` (= `/locales/bulk`) | `UserLocaleController.getUserLocales` | `UserProfileService.getUserLocales` | `UserProfile` ⨯ `TimeZoneInfo` |
| 31 | GET | `/api/v1/users/{userId}/time-zone` | `UserTimeZoneController.getUserTimeZone` | `UserProfileService.getUserTimeZone` | `UserProfile` ⨯ `TimeZoneInfo` |
| 32 | PUT | `/api/v1/users/{userId}/time-zone` | `UserTimeZoneController.saveUserTimeZone` | `saveUserTimeZone` | `UserProfile`, `TimeZoneInfo` |
| 33 | PUT | `/api/v1/users/{userId}/time-zone/by-country` | `UserTimeZoneController.saveUserTimeZoneByCountry` | `saveUserTimeZoneByCountry` | `GlobalCountry` ⨯ `TimeZoneInfo` |
| 34 | GET | `/api/v1/users/{userId}/time-zone/auto` | `UserTimeZoneController.getAutoTimeZoneSetting` | `UserSettingsService.isAutoTimeZoneEnabled` | `UserSettings` (SettingType=2) |
| 35 | PUT | `/api/v1/users/{userId}/time-zone/auto` | `UserTimeZoneController.putAutoTimeZoneSetting` | `setAutoTimeZoneSetting` + `getUserTimeZone` | `UserSettings`, `UserProfile`, `TimeZoneInfo` |
| 36 | POST | `/api/v1/users/time-zones` | `UserTimeZoneController.getUserTimeZones` | `getUserTimeZones` | `UserProfile` ⨯ `TimeZoneInfo` |
| 37 | GET | `/api/v1/users/profileImage/random` | `ProfileImageController.getRandomDefaultProfileImageUrl` | `getRandomDefaultProfileImageUrl` | (메모리: `DefaultProfileImage.defaultProfileImageUrls`) |
| 38 | GET | `/api/v1/users/profileImage/random/user/{userId}` | `ProfileImageController.getRandomDefaultProfileImageUrl(int)` | `getFixedRandomDefaultProfileImageUrl` | (메모리) |
| 39 | GET | `/api/v1/users/profileImage/random/bulk?num=` | `ProfileImageController.getRandomDefaultProfileImageUrls` | `getRandomDefaultProfileImageUrls` | (메모리, max 1000) |
| 40 | GET | `/api/v1/users/profileImage/random/all` | `ProfileImageController.getAllDefaultProfileImageUrls` | `getAllDefaultProfileImageUrls` | (메모리, 6개) |
| 41 | PUT | `/api/v1/users/settings/{userId}/birth-day-display` | `UserSettingsController.putBirthDayDisplaySetting` | `UserSettingsService.setNotShowBirthDaySetting` | `UserSettings`, `UserSettingsLog` |
| 42 | GET | `/api/v1/users/settings/{userId}/birth-day-display` | `UserSettingsController.getBirthDayDisplaySetting` | `getBirthDayDisplaySetting` | `UserSettings` |
| 43 | POST | `/api/v1/users/dropAccount/drop` | `DropAccountController.dropAccount` | `DropAccountService.dropAccount` | `UserDropOutLog`, `DestructionPrivacyManager`, `UserProfile`, `webpages_Membership`, `webpages_OAuthMembership`, `InactiveAccountManager`, RabbitMQ, Kakao/Line |

**합계: 43개**. (UserLocaleController의 `/location`·`/locale` 매핑은 같은 메서드가 두 경로를 받으므로 1개로 센다.)

---

## 3. 컨트롤러별 상세

### 3.1 `FindAccountController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/FindAccountController.java:17` — Base path `/api/v1/users/accounts/find`.

#### POST `/realname/list`
- 입력: `List<Integer> userIds` (JSON body)
- 응답: `List<RealName>` (외부 jar `com.wadiz.wave.user.account.find.domain.RealName`, Builder: `userId`, `decRealName`)
- 컨트롤러 `FindAccountController.java:24` → `FindAccountRealNameService.findRealNameForList` (`service/FindAccountRealNameService.java:27`):
  - userId 하나씩 순회하며 `mapper.selectByUserRealName(userId)` 호출. **동일 userId에 대해 SELECT 2회** 호출 (blank 체크용, 결과 매핑용 — `service/FindAccountRealNameService.java:33-36`).
  - 실패 시 `ServerSideException("투자회원실명 조회실패")`.

#### POST `/realname/unit`
- 입력: `Integer userId` (JSON body, 단일 정수)
- 응답: `RealName`
- 조회 SQL (MySQL, `mapper/wadiz/account/account-find-mapper.xml:6`):
```xml
<select id="selectByUserRealName" resultType="String">
    SELECT RealName
    FROM TbPersonalUserInfo
    WHERE UserId = #{userId}
</select>
```
- `RealName`의 Builder 메서드명이 `decRealName` 이므로 **외부 jar 안에서 복호화** 되는 것으로 추정되나, 본 repo 내에서는 확인 불가.

---

### 3.2 `UserAccountInfosController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/UserAccountInfosController.java:31` — Base path `/api/v1/users/accounts`. **가장 많은 엔드포인트(17개)를 포함하며 다른 서비스의 주요 호출 지점**.

#### POST `/{userId}/password/verification`
- 입력: path `userId:Integer`, body `String password` (평문으로 추정)
- 응답: `boolean`
- `userAccountInfosMapper.selectUserEncPasswordByUserId(userId)` 로 암호화된 패스워드 조회 후 `WadizPassWordUtils.matches(password, enc)` 비교 (`service/UserAccountInfosService.java:45-47`).
- SQL (`account-infos-mapper.xml:19`):
```xml
<select id="selectUserEncPasswordByUserId" parameterType="int" resultType="String">
    SELECT Password
    FROM webpages_Membership
    WHERE UserId = #{userId}
</select>
```

#### GET `/type/{accountType}/count`
- 서비스가 `findByAccntType(accntType)` 로 리스트를 받아 `.size()` 반환 (`UserAccountInfosController.java:43`). 즉 **COUNT 전용 쿼리가 있어도 사용되지 않음** (`account-infos-mapper.xml:25` 의 `countByAccountType` 존재하지만 컨트롤러에서 미사용).
- SQL (`account-infos-mapper.xml:44`):
```xml
<select id="selectByAccountType" resultMap="UserAccount">
    SELECT UserId, UserName, NickName, AccntType
    FROM UserProfile
    WHERE AccntType = #{accntType}
    AND UserStatus = 'NM'
    ORDER BY UserId
    <if test="size != null">
        LIMIT #{offset}, #{size}
    </if>
</select>
```

#### GET `/detail/{userId}?useDefaultRandomImage=true`
- 응답: `UserAccountDetail` (`account/model/UserAccountDetail.java:11`) — `userId`, `userName`, `nickName`, `accntType`, `mobileNumber`, `ValidEmailFirstCheck`, `validMobileNumber`, `whenCreated`(Asia/Seoul), `profileImageUrl`, `hasPassword`.
- 주: `useDefaultRandomImage=true` 일 때 `ProfileImageService.getProfileImageUrlWithFixedRandomDefault` 로 fallback. 코멘트 "Deprecate가 목표, Random image 정책은 장기적으로 FE에서 가져가기로 합의" (`UserAccountInfosController.java:49`).
- SQL (`account-infos-mapper.xml:56`):
```xml
<select id="detailByUserId" resultType="com.wadiz.wave.user.account.model.UserAccountDetail">
    SELECT UP.UserId, UP.UserName, UP.NickName, UP.AccntType, UP.MobileNumber, UP.WhenCreated,
           if(UP.ValidEmailFirstCheck = 'Y', true, false) as ValidEmailFirstCheck,
           if(UP.ValidMobileNumber = 'Y', true, false) as ValidMobileNumber,
           P.PhotoUrl as ProfileImageUrl,
           if(WM.Password is not null AND UP.JoinAuthType='EMAIL_AUTH', true, false) as HasPassword
    FROM UserProfile UP
             LEFT JOIN PhotoCommon P on P.PhotoId = UP.PhotoId
             LEFT JOIN webpages_Membership WM ON WM.UserId = UP.UserId
    WHERE UP.UserId = #{userId}
      AND UP.UserStatus = 'NM'
</select>
```

#### GET `/type/{accountType}` / `/type/{accountType}/all`
- 전자는 `@ModelAttribute Pageable`(`page`, `size`) 페이징, 후자는 전체.
- 같은 `selectByAccountType` SQL 사용 (size null이면 LIMIT 생략).

#### GET `/type/initRealNameAuth?user=`
- 실명 인증 데이터 초기화. UserName 기준 사용자 찾아 `TbPersonalUserInfo.SSN1/SSN2` 를 `'init'` 으로 덮어씀 (`account-infos-mapper.xml:105`):
```xml
<update id="updateInitRealNameAuth">
    UPDATE TbPersonalUserInfo A
    SET A.SSN1='init',
        A.SSN2='init'
    where A.UserId = (select UserId from UserProfile where UserName = #{user})
</update>
```
- **QA/운영 툴 성격의 엔드포인트** (권한 체크 코드 없음, Controller/Service 코드에서 관측되지 않음).

#### GET `/type/joinLimitClear?user=`
- `UserDropOutLog.UserName = UserId` 로 강제 변경하여 재가입 제한을 해제하는 것으로 보임 (`account-infos-mapper.xml:112`):
```xml
<update id="updateJoinLimitClear">
    UPDATE UserDropOutLog
    SET UserName = UserId
    WHERE UserId = (select UserId from UserProfile where UserName = #{user})
</update>
```

#### GET `/type/initMarketingParticipationHistory?number=`
- `WadizSecurityEncodeUtil.convertEncodeData(number, 1)` 로 hashing 후 (`service/UserAccountInfosService.java:107`):
```xml
<update id="initMarketingParticipationHistory">
    update MarketingParticipationHistory
    set IsDelete     = true,
        DeleteReason = 'TEST_QA'
    where HashingByKey = #{key}
      and IsDelete is false
</update>
```
- `DeleteReason='TEST_QA'` 하드코딩에서 QA 용 툴 엔드포인트임이 드러난다.

#### GET `/{userId}/linkedSNS` (Deprecated)
- `Map<String, Boolean>` 형태 (KAKAO/FACEBOOK/GOOGLE/NAVER/APPLE/LINE) — `LinkedSNS.toMap()`.

#### GET `/{userId}/social/link`
- Deprecated 대체. `UserAccountInfos.SocialLink`(`facebook`, `apple`, `naver`, `kakao`, `google`, `line` boolean) 필드 리턴.
- SQL (`account-infos-mapper.xml:32`):
```xml
<select id="selectProviderByUserId" resultType="String">
    SELECT Provider
    FROM webpages_OAuthMembership
    WHERE UserId = #{userId};
</select>
```

#### POST `/{userId}/social/{provider}`
- `provider` 는 enum `SocialProviderType` (kakao, naver, google, facebook, apple, line, user — `constant/SocialProviderType.java:6-15`).
- body `UnlinkSocialRequest { providerUserId, accessToken }`.
- Service는 `@Async` 로 Kakao/Line 외부 API 호출. case로 `kakao` 이면 `KakaoGateway.unlink(providerUserId)`, `line` 이면 `LineGateway.unlink(accessToken)`. 그 외는 무동작 (`service/UserAccountInfosService.java:74-88`).
- **DB 업데이트는 `unLinkSns` 메서드 안에서 이루어지지 않는다** — `webpages_OAuthMembership` 에서 행을 지우는 것은 `DropAccountService` 의 `deleteProviderInfo` 뿐. SNS unlink API 단독 호출은 외부 IdP 연동 해지만 수행하고 DB 행 삭제는 따로 하지 않는다 (관측 가능한 범위에서는 그렇다).
- 주석: `// Delete Method의 경우 Body 사용에 제약이 되는 경우가 있어서 Post로 수정` (`UserAccountInfosController.java:100`).

#### PUT `/{userId}/social/friends-count`
- body: `FriendsCountRequest { provider:SocialProviderType(NotNull), friendsCount:Integer(NotNull) }` (`model/UserAccountInfos.java:59`).
- SQL (`account-infos-mapper.xml:158`):
```xml
<insert id="upsertProviderProfileFriendsCount">
    INSERT INTO wadiz_db.TbProviderProfile (userId, provider, friendscount)
    VALUES (#{userId}, #{provider}, #{friendsCount})
    ON DUPLICATE KEY
    UPDATE provider = #{provider}, friendscount = #{friendsCount}
</insert>
```
- 결과 > 0이면 `insertProviderProfileFriendsCountLog` 로 `TbProviderProfileLog` 에 이력 (`account-infos-mapper.xml:165`).

#### PUT `/{userId}/social/profile`, GET, DELETE via birth-day
- Request: `ProviderProfileRequest { provider:NotNull, gender:nullable, birthYear:nullable, birthDay:nullable }` (`model/UserAccountInfos.java:36`).
- `gender` enum `SocialGenderType` (M/F/U, `constant/SocialGenderType.java:6-10`).
- Upsert SQL with conditional columns (`account-infos-mapper.xml:137-151`):
```xml
<insert id="upsertProviderProfile" parameterType="com.wadiz.wave.repository.wadiz.entity.ProviderProfileEntity">
    INSERT INTO wadiz_db.TbProviderProfile (userId, provider, gender, birthday, birthyear)
    VALUES (#{userId}, #{provider}, #{gender}, #{birthDay}, #{birthYear})
    ON DUPLICATE KEY
    UPDATE provider = #{provider}
    <if test='gender != null and (gender.name() == "M" or gender.name() == "F")'>
        , gender = #{gender}
    </if>
    <if test='birthDay != "" and birthDay != null'>
        , birthday = #{birthDay}
    </if>
    <if test='birthYear != "" and birthYear != null'>
        , birthYear = #{birthYear}
    </if>
</insert>
```

#### PUT `/{userId}/birth-day`
- body: `BirthDayRequest { birthDay }` — `@Size(min=4,max=4)`, `@Pattern` `MMDD` (`model/UserAccountInfos.java:69-75`).
- `putBirthDay` 는 `SocialProviderType.user` 로 고정해서 upsert (`service/UserAccountInfosService.java:148-155`):
```xml
<insert id="upsertBirthDay">
    INSERT INTO wadiz_db.TbProviderProfile(userId, provider, birthday)
    VALUES (#{userId}, #{provider}, #{birthDay})
    ON DUPLICATE KEY
    UPDATE provider = #{provider}, birthday=#{birthDay}
</insert>
```
- `SocialProviderType.user` 값은 주석에도 "생일관련 작업 하면서 추가" 로 명시 (`constant/SocialProviderType.java:13`).

#### GET `/{userId}/birth-day`
- `SELECT birthday FROM TbProviderProfile WHERE userId = #{userId}` (`account-infos-mapper.xml:201`).

#### DELETE `/{userId}/birth-day`
- `UPDATE TbProviderProfile SET birthday=null WHERE userId=#{userId}` (`account-infos-mapper.xml:207`). 결과가 >0 이면 `insertBirthDayLog(userId, "user", null)`.

#### 예외 처리
- `@ExceptionHandler` 로 `MethodArgumentNotValidException`/`HttpMessageNotReadableException` → 400 + `ExceptionErrorVo`, 그 외 → 500 (`UserAccountInfosController.java:149-182`).

---

### 3.3 `UserLocaleController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/UserLocaleController.java:21` — Base `/api/v1/users`.

#### PUT `/{userId}/location` (= `/locale`)
- body: `UserLocale { language, country, source(nullable) }` (`repository/wadiz/entity/UserLocale.java:10-17`).
- `saveUserLocale` 흐름 (`service/UserProfileService.java:40-70`):
  1. `source` 누락 시 `"WEB_API"` 주입.
  2. `source == "KR_APP_AUTO_UPDATE"` 이면 `findRecentUserLocaleHistoryByUserId` 로 최근 이력과 동일하면 건너뜀 (`user-locale-history-mapper.xml:9-15`, `LIMIT 0, 1` 로 최근 1건). **이 분기는 하위호환용 주석 표기**.
  3. 자동 타임존 설정(`userSettingsService.isAutoTimeZoneEnabled`)이 켜져 있으면 `findMainTimeZoneInfoByCountry` 결과의 `TimeZoneCode`를 함께 업데이트.
  4. `updateLocale` (LanguageCode/CountryCode/[TimeZoneCode if null]/Updated=NOW) → `insertUserLocaleHistory` → `crm.sendUserLocale(userId, language, country, timeZone)` (Braze 연동; `CrmApiGateway.sendUserLocale` `@Async`).
- Update SQL (`user-locale-mapper.xml:9`):
```xml
<update id="updateLocale">
    UPDATE UserProfile
    SET
        LanguageCode = #{language},
        CountryCode = #{country},
    <if test="timeZoneCode != null">
        TimeZoneCode = #{timeZoneCode},
    </if>
        Updated = NOW()
    WHERE
        UserId = #{userId}
</update>
```
- History insert (`user-locale-history-mapper.xml:4`):
```xml
<insert id="insertUserLocaleHistory">
    INSERT INTO wadiz_user_stat.user_locale_history (user_id, language_code, country_code, source)
    VALUES (#{user_id}, #{language}, #{country}, #{source})
</insert>
```
- 주: 이력 테이블은 **`wadiz_user_stat`** schema 사용. 메인 데이터 테이블은 `wadiz_db`.

#### GET `/{userId}/location` (= `/locale`)
- `SELECT LanguageCode, CountryCode FROM UserProfile WHERE UserId=#{userId}` → `UserLocale`(language/country) (`user-locale-mapper.xml:22`).

#### POST `/locales` (= `/locales/bulk`)
- body: `UserTimeZoneDto.BulkRequest { userIds: List<Integer> @NotNull @Size(min=1,max=1000) }` (`dto/UserTimeZoneDto.java:43-47`). **요청 DTO가 TimeZone 네임스페이스에 재사용됨** (주의).
- SQL (`user-locale-mapper.xml:28`):
```xml
<select id="findUserLocaleByUserIds" resultType="UserLocaleBulk">
    SELECT UP.UserId,
           UP.LanguageCode AS Language,
           UP.CountryCode AS Country,
           TZI.TimezoneIANAId AS TimeZone
    FROM wadiz_db.UserProfile UP
             LEFT OUTER JOIN TimeZoneInfo TZI ON UP.TimeZoneCode = TZI.TimeZoneCode
    WHERE UP.UserId IN
    <foreach item="userId" collection="userIds" open="(" separator="," close=")">
        #{userId}
    </foreach>
</select>
```
- Service(`getUserLocales`, `UserProfileService.java:78-86`)가 **순서 보장**을 위해 결과 Map으로 만들어 요청 userIds 순서로 매핑. 없는 userId 는 `UserLocaleBulk(userId)` (language=country=timeZone=null) 로 채움.

---

### 3.4 `JoinEquityAccountController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/JoinEquityAccountController.java:16` — Base `/api/v1/users/equity/join`.

- 모든 엔드포인트가 `@PathVariable Long encUserId` 를 받고, Service 내부에서 `decryptUserIdForLong` 으로 복호화 (`service/JoinEquityAccountService.java:318-321`):
```java
private int decryptUserIdForLong(long number) {
    long day = number % 100L;
    return (int) ((number - day) / (day * 100L));
}
```
코멘트에 `// TODO : WadizCryptoUtil 버그 수정될 때 같이 원복되어야 할 수도 있음` (`JoinEquityAccountService.java:313`) — 외부 jar `WadizCryptoUtil.decryptUserIdForLong` 의 버그 우회.
- 응답은 모두 `ResponseEntity<ResponseWrapper>` 공통 포맷. `JoinResponseCode` / `JoinEquityStatus` / `JoinEquity.*` 및 `EnumMapperValue` 는 외부 jar.

#### GET `/{encUserId}/mobile` (전화번호인증여부)
- SQL (`account-join-equity-mapper.xml:5`):
```xml
<select id="selectToPhoneNumber" resultType="com.wadiz.wave.repository.wadiz.entity.JoinStatusByPhoneNumber">
    SELECT CASE
               WHEN up.MobileNumber is not null and length(trim(up.MobileNumber)) > 0 THEN true
               ELSE false END as isVerify
         , up.MobileNumber
    FROM UserProfile up
    WHERE up.UserId = #{userId};
</select>
```

#### GET `/{encUserId}/promotion`
- 서비스가 `selectToPromotionCode` → 코드 존재 시 `isPromotionByPromotionCode` 로 설명 조회 (`service/JoinEquityAccountService.java:60-87`). `isFriendsByPromotionCode` 도 mapper에는 정의되어 있으나 이 엔드포인트에서는 호출되지 않음.
- SQL (`account-join-equity-mapper.xml:14-32`):
```xml
<select id="selectToPromotionCode" resultType="String">
    SELECT ri.RecordData as promotionCode
    FROM UserProfile up
             INNER JOIN TbUserRecordingInfo ri on up.UserId = ri.TargetUserId and RecordType = 'UIREC00007'
    WHERE up.UserId = #{userId};
</select>

<select id="isFriendsByPromotionCode" resultType="String">
    SELECT up.NickName as promotionValue
    FROM TbCompensationCodeMaster cm
             INNER JOIN UserProfile up on cm.IssueId = up.UserId
    WHERE cm.CompensationCode = #{promotionCode};
</select>

<select id="isPromotionByPromotionCode" resultType="String">
    SELECT pc.PromotionDesc as promotionValue
    FROM TbPromotionCodeMaster pc
    WHERE pc.PromotionCode = #{promotionCode}
</select>
```

#### GET `/{encUserId}/virtual` (와디즈계좌발급여부)
```xml
<select id="selectToVirtualAccountIssue"
        resultType="com.wadiz.wave.repository.wadiz.entity.JoinStatusByVirtualAccount">
    SELECT CASE WHEN vt.VirtualAccount is not null THEN true ELSE false END as isIssued
         , vt.VirtualAccount
    FROM UserProfile up
             LEFT OUTER JOIN VirtualAccountPublished vt on up.UserId = vt.UserId
    WHERE up.UserId = #{userId};
</select>
```

#### GET `/{encUserId}/type` (적격/전문회원)
- `AccntType IN ('NP200','NP300')` 를 적격/전문으로 판정 (`account-join-equity-mapper.xml:43`):
```xml
<select id="selectToProfessionalAccount"
        resultType="com.wadiz.wave.repository.wadiz.entity.JoinStatusByAccountType">
    SELECT CASE WHEN up.AccntType = 'NP200' or up.AccntType = 'NP300' THEN true ELSE false END as isProfessional
         , up.AccntType                                                                        as accountType
    FROM UserProfile up
    WHERE up.UserId = #{userId};
</select>
```

#### GET `/{encUserId}/step` & `/status`
- 같은 `findSignUpStep` 메서드를 `isCurrent` 플래그 차이로 호출 (`JoinEquityAccountController.java:47, 53`).
- Controller step은 Map<String, Boolean> (전체 단계 bool), status는 현재 `currentStatus` 단일 값.
- SQL (`account-join-equity-mapper.xml:51`):
```xml
<select id="selectToSignUpStep" resultType="com.wadiz.wave.repository.wadiz.entity.JoinStatusBySignUpStep">
    SELECT js.IsIdCardVerified
         , js.IsConfirmPennyTransfer
         , js.IsEquityJoinDone
         , js.IsVirtualAccountPublished
    FROM UserProfile up
             LEFT OUTER JOIN UserJoinStepStatus js on up.UserId = js.UserId
    WHERE up.UserId = #{userId};
</select>
```
- 단계 매핑 (`JoinEquityAccountService.getStatusInfoMap`, `JoinEquityAccountService.java:184-236`):
  - `EQUITY_STATUS_VERIFY_MOBILE` ← `selectToPhoneNumber.isVerify`
  - `EQUITY_STATUS_VERIFY_LICENSE` ← `IsIdCardVerified`
  - `EQUITY_STATUS_VERIFY_TRANSFER` ← `IsConfirmPennyTransfer`
  - `EQUITY_STATUS_VERIFY_ADDRESS` ← `IsEquityJoinDone`
  - `EQUITY_STATUS_VERIFY_VIRTUALACCOUNT` ← 복합 조건 (이미 발급되었거나 선행 단계 미완료면 false)
  - `EQUITY_STATUS_VERIFY_DONE` ← `IsVirtualAccountPublished`

---

### 3.5 `UserAgeVerificationController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/UserAgeVerificationController.java:21` — Base `/api/v1/users`.

#### GET `/{userId}/age-verification`
- Swagger notes: "UserStatus가 'NM'인 사용자만 조회되며, Expired 날짜를 기준으로 성인인증 여부를 판단합니다. 데이터가 없는 경우 userId만 포함된 객체(verified=false, dates=null)가 반환됩니다." (`UserAgeVerificationController.java:30`).
- Response: `UserAgeVerificationBulk { userId, verified, verifiedDate, expiredDate }` (timezone `Asia/Seoul`, format `yyyy-MM-dd'T'HH:mm:ss'+09:00'` — `entity/UserAgeVerificationBulk.java:19-23`).
- SQL (`mapper/wadiz/user/user-age-verification-mapper.xml:5`):
```xml
<select id="findUserAgeVerificationByUserId" resultType="UserAgeVerificationBulk">
    SELECT UP.UserId,
           IF(UAV.Expired IS NOT NULL AND UAV.Expired > NOW(), true, false) AS Verified,
           UAV.Verified AS VerifiedDate,
           UAV.Expired AS ExpiredDate
    FROM wadiz_db.UserProfile UP
    LEFT JOIN wadiz_db.UserAgeVerification UAV ON UP.UserId = UAV.UserId
    WHERE UP.UserStatus = 'NM'
      AND UP.UserId = #{userId}
</select>
```
- Service는 result가 null이면 `new UserAgeVerificationBulk(userId)` 반환 (`UserProfileService.java:141-145`).

#### POST `/age-verifications/bulk`
- body: `UserAgeVerificationDto.BulkRequest { userIds:List<Integer> @NotNull @Size(min=1,max=1000) }` (`dto/UserAgeVerificationDto.java:11`).
- SQL: 위 쿼리의 `IN (...)` 버전 (`user-age-verification-mapper.xml:16`).
- Service는 순서 보장 + 없는 userId 는 `UserAgeVerificationBulk(userId)` 기본값 (`UserProfileService.java:153-161`).

---

### 3.6 `UserTimeZoneController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/UserTimeZoneController.java:27` — Base `/api/v1/users`.

#### GET `/{userId}/time-zone` / PUT
- Response: `UserTimeZoneDto.Response { timeZoneCode, timeZone, displayName, utcOffset, autoTimeZoneEnabled }` (`dto/UserTimeZoneDto.java:27`).
- `displayName` 은 Accept-Language 기반 `locale.getLanguage()` 로 `TimeZoneInfo.getdisplayNameByLanguage` 선택 (`entity/TimeZoneInfo.java:17-19`): `ko` 이면 `DisplayNameKo`, 아니면 `DisplayNameEn`.
- `autoTimeZoneEnabled` 는 `UserSettingsService.isAutoTimeZoneEnabled` (자동=설정 row 없음).
- SQL (`user-timezone-mapper.xml:4-31`):
```xml
<update id="updateUserTimeZone">
    UPDATE wadiz_db.UserProfile
    SET
        TimeZoneCode = #{timeZoneCode}
    WHERE
        UserId = #{userId}
</update>

<select id="findUserTimeZoneInfoByUserId" resultType="TimeZoneInfo">
    SELECT TZI.TimeZoneCode,
           TZI.TimezoneIANAId AS TimeZone,
           TZI.DisplayNameEn,
           TZI.DisplayNameKo,
           TZI.UtcOffset
    FROM wadiz_db.UserProfile UP
        LEFT OUTER JOIN TimeZoneInfo TZI ON UP.TimeZoneCode = TZI.TimeZoneCode
    WHERE UP.UserId = #{userId}
</select>

<select id="findTimeZoneInfoByTimeZoneCode" resultType="TimeZoneInfo">
    SELECT TZI.TimeZoneCode,
           TZI.TimezoneIANAId AS TimeZone,
           TZI.DisplayNameEn,
           TZI.DisplayNameKo,
           TZI.UtcOffset
    FROM wadiz_db.TimeZoneInfo TZI
    WHERE TZI.TimeZoneCode =  #{timeZoneCode}
</select>
```
- `saveUserTimeZone` 은 잘못된 `timeZoneCode` 면 `IllegalArgumentException` (`UserProfileService.java:97`). 컨트롤러 `@ExceptionHandler` 가 400 `INPUT_VALIDATION_ERROR` 반환 (`UserTimeZoneController.java:118-127`). 저장 후 `CrmApiGateway.sendUserTimeZone` (Braze 전송).

#### PUT `/{userId}/time-zone/by-country`
- body: `ByCountryRequest { country }`.
- SQL (`user-timezone-mapper.xml:33`):
```xml
<select id="findMainTimeZoneInfoByCountry" resultType="TimeZoneInfo">
    SELECT TZI.TimeZoneCode,
           TZI.TimezoneIANAId AS TimeZone,
           TZI.DisplayNameEn,
           TZI.DisplayNameKo,
           TZI.UtcOffset
    FROM wadiz_db.GlobalCountry GC
        INNER JOIN wadiz_db.TimeZoneInfo TZI
            ON GC.TimeZoneCode = TZI.TimeZoneCode
    WHERE GC.CountryCode =  #{country}
</select>
```
- 컨트롤러 주석: "web을 통해 public 하게 열려 있지는 않은 상태. 현재로서는 가입시등을 위한 내부 API" (`UserTimeZoneController.java:65`).

#### GET/PUT `/{userId}/time-zone/auto`
- GET: `UserSettings.AutoTimeZone { autoTimeZoneEnabled }`.
- PUT body: `AutoTimeZoneRequest { enable }`.
- `setAutoTimeZoneSetting(enable=true)` 시 (`UserSettingsService.java:66-84`):
  1. `UserSettings` 에서 `MANUAL_TIME_ZONE` (타입2) row 삭제
  2. `UserSettingsLog.DELETE` 기록
  3. `UserLocale.country` → `findMainTimeZoneInfoByCountry` → 해당 code로 `updateUserTimeZone` + `crmApiGateway.sendUserTimeZone`.
- `enable=false` 시 `upsertUserSettings` 로 MANUAL 설정 삽입 + `INSERT` 로그.
- 주석: "SettingType은 manual이지만, 사용자 측면에서는 auto로 전환해서 사용하고 있음. 기본값이 자동인데 데이터가 없고, 수동일 경우에만 데이터가 존재" (`UserSettingsService.java:53-55`).

#### POST `/time-zones`
- body: `BulkRequest { userIds @NotNull @Size(min=1,max=1000) }`.
- SQL (`user-timezone-mapper.xml:45`):
```xml
<select id="findUserTimeZoneByUserIds" resultType="UserTimeZoneBulk">
    SELECT UP.UserId,
           TZI.TimezoneIANAId AS TimeZone
    FROM wadiz_db.UserProfile UP
             LEFT OUTER JOIN TimeZoneInfo TZI ON UP.TimeZoneCode = TZI.TimeZoneCode
    WHERE UP.UserId IN
    <foreach item="userId" collection="userIds" open="(" separator="," close=")">
        #{userId}
    </foreach>
</select>
```
- 없는 userId 는 기본값 `Asia/Seoul` (`UserProfileService.java:131-133`).

---

### 3.7 `ProfileImageController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/ProfileImageController.java:14` — Base `/api/v1/users/profileImage`. **DB 미사용**.

- 기본 이미지 파일명 6개 하드코딩 (`constant/DefaultProfileImage.java:4`):
  `/assets/icon/profile-icon-1.png` ~ `profile-icon-6.png`.
- Base URL: property `wadiz.user.profile.default-image.url` (default `https://static.wadiz.kr`) (`common/ProfileImageUrlComponent.java:26`).
- `/random`: 완전 랜덤.
- `/random/user/{userId}`: `userId % 6` (고정; `ProfileImageUrlComponent.java:42`).
- `/random/bulk?num=`: 최대 1000개 (`ProfileImageService.java:15`).
- `/random/all`: 6개 전체.

---

### 3.8 `UserSettingsController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/UserSettingsController.java:15` — Base `/api/v1/users/settings`.

- 생일 노출 설정 (`SettingType=1 NOT_SHOW_BIRTH_DAY`, `UserSettingsConst.java:9-13`). **"기본값=노출, row 존재=비노출"** 규칙으로 표시 제어.
- SQL (`userSettings-mapper.xml:4-47`):
```xml
<insert id="upsertUserSettings">
    INSERT INTO UserSettings(UserId, SettingType)
    VALUES (#{userId}, #{settingType})
    -- 불필요한 예외 방지 (Client에서는 단시간에 중복 호출하지 않도록 처리 필요)
    ON DUPLICATE KEY UPDATE Registered=NOW()
</insert>

<select id="findUserSettings" resultType="com.wadiz.wave.repository.wadiz.entity.UserSettingsEntity">
    SELECT UserId, SettingType, Registered
    FROM UserSettings
    WHERE UserId=#{userId}
      AND SettingType=#{settingType}
</select>

<delete id="deleteUserSettingsBySettingType">
    DELETE
    FROM UserSettings
    WHERE UserId=#{userId}
        AND SettingType=#{settingType}
</delete>

<delete id="deleteUserSettings">
    DELETE
    FROM UserSettings
    WHERE UserId=#{userId}
</delete>

<insert id="insertUserSettingsLog">
    INSERT INTO UserSettingsLog(UserId, SettingType, QueryType)
    VALUES (#{userId}, #{settingType}, #{queryType})
</insert>

<delete id="deleteUserSettingsLog">
    DELETE
    FROM UserSettingsLog
    WHERE UserId=#{userId}
</delete>
```
- `setNotShowBirthDaySetting(true)` → `DELETE (type=1) + log(DELETE)`; `(false)` → `UPSERT + log(INSERT)` (`UserSettingsService.java:31-42`).
- `getBirthDayDisplaySetting` 은 `findUserSettings` 결과가 null 이면 `isAllowed=true` (`UserSettingsService.java:44-51`).

---

### 3.9 `DropAccountController`
파일: `com.wadiz.wave.user/src/main/java/com/wadiz/wave/user/account/DropAccountController.java:25` — Base `/api/v1/users/dropAccount`.

#### POST `/drop`
- body: `DropAccountRequest { userId, userName, isDeleteSH?, reasonText?, nickName? }` (외부 jar `com.wadiz.wave.user.account.drop.domain.DropAccountRequest` — 필드는 dropAccountByWadiz-mapper.xml의 parameter로 확인).
- 응답: `CommonAccountResponse { isSuccess }` (외부 jar).
- `@Transactional(propagation = REQUIRED)` 로 아래 11단계를 원자 처리 (`service/DropAccountService.java:86-159`). 단, 내부에 섞인 `@Async` 호출(`unLinkSns`, `dropSettings`) 은 트랜잭션 외부에서 별도 실행.

단계:
1. 입력 검증 (`userId`, `userName` null/blank 체크). 실패 시 `Exception` → catch 에서 `ServerSideException`.
2. `dropMapper.insertUserDropOutLog(request)` 로 탈퇴 로그 기록:
```xml
<insert id="insertUserDropOutLog" parameterType="com.wadiz.wave.user.account.drop.domain.DropAccountRequest">
    INSERT INTO wadiz_db.UserDropOutLog (UserName, UserId, IsDeleteSH, ReasonText, WhenCreated)
    VALUES (#{userName}, #{userId}, #{isDeleteSH}, #{reasonText}, NOW()) ON DUPLICATE KEY
    UPDATE WhenCreated = NOW();
</insert>
```
3. 모든 `RetentionGroup` enum 상수(외부 jar) 를 순회하면서 `registerDestructionPrivacy` (`mapper/privacy/dropAccountByWadiz-mapper.xml:89` 및 `mapper/wadiz/privacy/destructionPrivacy-mapper.xml:86` — 동일 네임스페이스 이중 정의):
```xml
<insert id="registerDestructionPrivacy"
        parameterType="com.wadiz.wave.user.privacy.domain.DestructionPrivacyRequest">
    INSERT INTO wadiz_db.DestructionPrivacyManager (DestructionDueDate, UserId, IsDestruct, RetentionGroupName, Registered)
    SELECT DATE_ADD(NOW(), INTERVAL ${destructionPeriod} DAY)
         , DR.UserId
         , FALSE
         , #{retentionGroupName}
         , DR.WhenCreated
    FROM wadiz_db.UserDropOutLog AS DR
    WHERE DR.UserId = #{destructionUserId}
    ORDER BY DR.WhenCreated DESC LIMIT 1
    ON DUPLICATE KEY
    UPDATE Updated = NOW();
</insert>
```
4. `NickName="탈퇴계정"` 하드코딩 후 `updateUserProfile`:
```xml
<update id="updateUserProfile" parameterType="com.wadiz.wave.user.account.drop.domain.DropAccountRequest">
    UPDATE wadiz_db.UserProfile
    SET UserName   = #{userId}
      , NickName   = #{nickName}
      , UserStatus = 'DO'
      , PhotoId    = null
    WHERE UserId = #{userId};
</update>
```
   - `UserName` 을 `userId` 로 덮어써서 원래 이메일/아이디 제거. `UserStatus='DO'` (Drop Out).
5. `deletePasswordInfo` → `DELETE FROM webpages_Membership WHERE UserId=#{userId}` (`dropAccountByWadiz-mapper.xml:23`).
6. 소셜 정보 삭제 전 `selectSNSInfoByUserId` 로 entity 리스트 조회 (주석: "Data가 삭제되기 전에 데이터를 가져와야 한다."):
```xml
<select id="selectSNSInfoByUserId" resultType="com.wadiz.wave.repository.wadiz.entity.UserSNSInfoEntity">
    SELECT UserId, Provider, ProviderUserId, Token, RefreshToken
    FROM webpages_OAuthMembership
    WHERE UserId = #{userId};
</select>
```
7. `deleteProviderInfo` → `DELETE FROM webpages_OAuthMembership WHERE UserId=#{userId}` (`dropAccountByWadiz-mapper.xml:30`).
8. `userAccountInfosService.unLinkSns(snsInfoEntities)` (`@Async`, 비동기) — provider 별 Kakao/Line 외부 API (`service/UserAccountInfosService.java:68-88`).
9. `inactiveAccountMapper.updateDropAccount(InactiveAccountRequest{lastStatus:"DO", userId})`:
```xml
<update id="updateDropAccount" parameterType="com.wadiz.wave.user.privacy.domain.InactiveAccountRequest">
    UPDATE InactiveAccountManager
    SET LastStatus = #{lastStatus}
    WHERE UserId = #{userId};
</update>
```
10. 연쇄 도메인 정리 (`DropAccountService.java:133-150`):
    - `userAppContactService.dropData(userId)` — 주소록
    - `blockCommandService.unblockAll(userId)` — 서포터 차단
    - `userSettingsService.dropSettings(userId)` — `@Async` 로 `UserSettings` + `UserSettingsLog` 전체 삭제 (`UserSettingsService.java:86-97`) + 실패 시 `UserMonitoringSlackChannel.send()` (웹훅; `slack.user-dev-monitoring.url`)
    - `recommendationUserInfoService.dropRecommendationRejectionData(userId)` — 친구 추천 거부 데이터
    - `userAccountInfosService.deleteProviderProfile(userId)` — `TbProviderProfile`/`TbProviderProfileLog` 직접 DELETE (`account-infos-mapper.xml:176, 180`)
    - `termsService.rejectByDropOut(userId)` — 약관 동의 reject
    - `sourcingClubService.deleteSourcingClubMember(userId, "회원 탈퇴")`
11. `crmGatewayPublisher.publishDropOutInfo(userId.toString())` — RabbitMQ `crmGatewayExchange` 에 `ROUTING_KEY_DELETE` ("DELETE_USER") 로 발행 (`publisher/CrmGatewayPublisher.java:30`). Braze 연동.

**주의사항 (관측 기반)**:
- `DropAccountRequest.isDeleteSH` 필드가 DropOutLog에 저장됨 — "SH=신한" 대외계 플래그로 추정(외부 jar 코드 확인 불가).
- `@Transactional(REQUIRED)` 내부에서 `@Async` 호출을 섞는 구조 — 비동기 작업은 별도 스레드에서 새 트랜잭션으로 처리.
- `insertUserDropOutLog` 의 `ON DUPLICATE KEY UPDATE WhenCreated=NOW()` — 같은 userId가 탈퇴 → 부활 → 재탈퇴 시 로그 row가 갱신되는 구조.

---

## 4. DB 스키마 (관측 가능한 컬럼만)

### wadiz_db
| 테이블 | 컬럼 (mapper 관측) | 용도 |
|---|---|---|
| `UserProfile` | `UserId`, `UserName`, `NickName`, `AccntType`, `MobileNumber`, `CallingCode`, `WhenCreated`, `ValidEmailFirstCheck`, `ValidMobileNumber`, `JoinAuthType`, `UserStatus`('NM'/'IA'/'DO'), `PhotoId`, `LanguageCode`, `CountryCode`, `TimeZoneCode`, `Updated`, `Birth`, `AllowDM`, `WhenLastLogon`, 기타 | 회원 기본 테이블 |
| `TbPersonalUserInfo` | `UserId`, `RealName`, `SSN1`, `SSN2`, `Location1/2`, `JobCode1/2/3`, `ScrtCpCode`, `ScrtAccountNo`, `RegDate`, `UpdateDate`, `Birth`, `Sex`, `DI`, `CI` | 투자(실명) 전용 |
| `webpages_Membership` | `UserId`, `Password` | 레거시 비밀번호 (해시) |
| `webpages_OAuthMembership` | `UserId`, `Provider`, `ProviderUserId`, `Token`, `RefreshToken`, `TokenSecret` | SNS 연동 |
| `TbProviderProfile` | `userId`, `provider`, `gender`, `birthday`, `birthYear`, `friendscount` | 소셜/사용자 입력 생일·성별 메타 |
| `TbProviderProfileLog` | 위와 동일 (append-only log) | 변경 이력 |
| `PhotoCommon` | `PhotoId`, `PhotoUrl` | 프로필 이미지 매핑 |
| `UserDropOutLog` | `UserId`, `UserName`, `IsDeleteSH`, `ReasonText`, `WhenCreated`, `DropOutId` | 탈퇴 이력 |
| `DestructionPrivacyManager` | `DestructionId`, `DestructionDueDate`, `UserId`, `IsDestruct`, `RetentionGroupName`, `Updated`, `UpdatedBy`, `Registered` | 개인정보 파기 스케줄 |
| `InactiveAccountManager` | `InactiveId`, `UserId`, `UserName`, `Password`, `IsPassword`, `Provider`, `Inactivated`, `Reactivated`, `LastStatus`, `ArchivalDataForUserInfo`(JSON), `ArchivalDataForEquityInfo`(JSON) | 휴면 계정 |
| `UserAgeVerification` | `UserId`, `Verified`, `Expired` | 성인 인증 (Expired>NOW() 이면 유효) |
| `UserSettings` | `UserId`, `SettingType`(1/2), `Registered` | 사용자 설정 row 기반 플래그 |
| `UserSettingsLog` | `UserId`, `SettingType`, `QueryType`('INSERT'/'DELETE') | 설정 변경 이력 |
| `TimeZoneInfo` | `TimeZoneCode`, `TimezoneIANAId`, `DisplayNameEn`, `DisplayNameKo`, `UtcOffset` | 타임존 마스터 |
| `GlobalCountry` | `CountryCode`, `TimeZoneCode` | 국가 → 대표 타임존 매핑 |
| `UserJoinStepStatus` | `UserId`, `IsIdCardVerified`, `IsConfirmPennyTransfer`, `IsEquityJoinDone`, `IsVirtualAccountPublished` | 투자 가입 단계 |
| `VirtualAccountPublished` | `UserId`, `VirtualAccount`, `VirtualAccountNo` | 가상계좌 |
| `TbUserRecordingInfo` | `TargetUserId`, `RecordType`('UIREC00007'=투자 프로모션), `RecordData` | 유저별 기록 |
| `TbPromotionCodeMaster` | `PromotionCode`, `PromotionDesc` | 프로모션 마스터 |
| `TbCompensationCodeMaster` | `CompensationCode`, `IssueId` | 친구 추천 코드 |
| `MarketingParticipationHistory` | `HashingByKey`, `IsDelete`, `DeleteReason` | 마케팅 참여 이력 (QA용 init) |
| `webpages_UsersInRoles` | `UserId`, `RoleId` | 관리자 역할 (account-session-mapper만 참조, account 컨트롤러 직접 미사용) |
| `DvcSessionInfo` | `UserId`, `AuthKey`, `UpdateDate` | 앱 세션 (탈퇴 시 kick/cleanup) |
| `IdCardVerifyLog` | `UserId`, `VerifyType` (=3 이면 외국인) | 신분증 인증 로그 (verification-mapper) |
| `ShinhanTransactionNo` | `sequence` (auto-increment) | 신한 연동 트랜잭션 번호 생성 |
| `PennyTransfer`, `PennyTransferUserSummation`, `PennyTransferResponseLog`, `PennyTransferSummationResetLog` | bank-mapper.xml 참조 — 1원이체 인증 | (투자 가입 단계 중 `IsConfirmPennyTransfer` 과 연결) |
| `BankCode`, `UserWithdrawAccount`, `UserWithdrawAccountLog` | bank-mapper.xml | 은행 마스터 / 출금계좌 (account 직접 API는 없고 `JoinEquity` 단계 상태로만 간접 관측) |
| `TbBusinessLicenseInfo` | `RegUserId` | 사업자 회원 여부 |
| `InviteEvent`, `InviteOwner`, `InviteApplicant` | account-event-invite-mapper.xml | 초대 이벤트 (account 9개 컨트롤러에서 직접 호출 관측 안 됨) |

### wadiz_user_stat
| 테이블 | 컬럼 | 용도 |
|---|---|---|
| `user_locale_history` | `user_locale_history_id`, `user_id`, `language_code`, `country_code`, `source`, (registered 암묵) | 로케일 변경 이력 (append) |

---

## 5. 외부 의존성

### HTTP / PG
- **Kakao 연동 해제**: `KakaoGateway` (`infrastructure/kakao/KakaoGateway.java:23`). endpoint `https://kapi.kakao.com/v1/user/unlink`, property `kakao.admin_key`. `RestTemplate` qualifier `SNSRestTemplate`. 실패 시 `DecodingAccountDropoutKakaoUnlinkFailException`. error `-101`/`-103` 은 이미 해지된 상태로 간주.
- **LINE 연동 해제**: `LineGateway` (`infrastructure/line/LineGateway.java:32`). endpoints:
  - `https://api.line.me/oauth2/v3/token` (STATELESS, TTL 840s)
  - `https://api.line.me/v2/oauth/accessToken` (SHORT_LIVED, TTL 2,588,400s)
  - `https://api.line.me/user/v1/deauthorize`
  - `https://api.line.me/v2/oauth/verify`
  - properties `line.client_id`, `line.client_secret`. Channel token은 Redis 캐시(`CacheManagerService` + `RedisLockManager`).
- **신한은행 연동** (bank/shinhan mapper): `ShinhanTransactionNo` 시퀀스 생성 쿼리(`shinhan-mapper.xml:5`)만 관측됨. 실제 API 호출 코드는 본 9개 컨트롤러/서비스에서 직접 관측되지 않음 — **개요 문서가 언급한 "신한은행 API 연동" 은 `BankController` 도메인 쪽**. Account 도메인은 **`UserProfile.AccntType`, `VirtualAccountPublished`, `UserJoinStepStatus.IsConfirmPennyTransfer`** 등 결과 테이블만 읽는다.
- **실명 인증**: `FindAccountController` 는 `TbPersonalUserInfo.RealName` 을 읽기만 하며, 실제 본인인증/KISA 연동은 이 repo의 account 도메인 외부.

### 메시징
- **RabbitMQ**: `CrmGatewayPublisher` (`publisher/CrmGatewayPublisher.java:14`) — `crmGatewayExchange` TopicExchange, `wadizTextRabbitTemplate`. `ROUTING_KEY_DELETE="DELETE_USER"` 로 탈퇴 이벤트 발행. `ROUTING_KEY_DEACTIVATE`/`ROUTING_KEY_REACTIVATE` 도 존재하지만 account 9개 컨트롤러에서 직접 호출은 `publishDropOutInfo` 뿐.

### 내부 REST (Braze Gateway)
- **CRM API**: `CrmApiGateway` (`infrastructure/crm/CrmApiGateway.java:33`). base URL property `wadiz.crm-api.base-url` + `/braze/users`, Bearer `wadiz.crm-api.internal-token`. Account 도메인에서 호출되는 메서드:
  - `sendUserLocale(userId, language, country, timeZone)` — `@Async`, `UserProfileService.saveUserLocale` 내
  - `sendUserTimeZone(userId, timeZone)` — `@Async`, `saveUserTimeZone` / `saveUserTimeZoneByCountry` / `setAutoTimeZoneSetting(true)` 내

### Slack Webhook
- **`UserMonitoringSlackChannel`** (`infrastructure/slack/UserMonitoringSlackChannel.java:10`) — properties `slack.enable`, `slack.user-dev-monitoring.url`, `slack.user-dev-monitoring.channel`. `DropAccountService` 경로의 `userSettingsService.dropSettings` 실패 시 호출.

### 파일/이미지
- **정적 이미지 CDN**: `wadiz.user.profile.default-image.url` (default `https://static.wadiz.kr`) + 하드코딩된 6개 파일 경로. **S3/MinIO 업로드 로직은 account 도메인 컨트롤러에 존재하지 않음** (검색 결과). 업로드는 다른 도메인.
- `WadizCDNUtil.cdnURL(photoUrl)` — `ProfileImageService.getProfileImageUrlWithRandomDefault` 내부에서 호출 (`service/ProfileImageService.java:31`). 9개 컨트롤러 직접 API에서 업로드/삭제는 없고, `/accounts/detail/{userId}` 의 `profileImageUrl` 래핑용으로만 사용.

### 암호화 유틸 (외부 jar)
- `WadizPassWordUtils.matches` — 패스워드 해시 검증 (`verifyPassword`).
- `WadizCryptoUtil.decryptUserIdForLong` — 버그로 현재 미사용, 수동 구현으로 대체 (`JoinEquityAccountService.java:313-321`).
- `WadizSecurityEncodeUtil.convertEncodeData(value, 1)` — 마케팅 키 해싱용.

---

## 6. Mapper / Namespace 매핑

| Java 인터페이스 (Namespace) | XML | 사용 Service |
|---|---|---|
| `FindAccountRealNameMapper` | `mapper/wadiz/account/account-find-mapper.xml` | `FindAccountRealNameService` |
| `UserAccountInfosMapper` | `mapper/wadiz/account/account-infos-mapper.xml` | `UserAccountInfosService`, `DropAccountService` |
| `JoinEquityAccountMapper` | `mapper/wadiz/account/account-join-equity-mapper.xml` | `JoinEquityAccountService` |
| `SessionManagerMapper` | `mapper/wadiz/account/account-session-mapper.xml` | (account 9개 컨트롤러에서 직접 호출 관측 안 됨) |
| `InviteEventMapper` | `mapper/wadiz/account/account-event-invite-mapper.xml` | (account 9개 컨트롤러에서 직접 호출 관측 안 됨 — `event` 하위 도메인) |
| `UserAgeVerificationMapper` | `mapper/wadiz/user/user-age-verification-mapper.xml` | `UserProfileService` |
| `UserLocaleMapper` | `mapper/wadiz/user/user-locale-mapper.xml` | `UserProfileService`, `UserSettingsService` |
| `UserLocaleHistoryMapper` | `mapper/wadiz/user/user-locale-history-mapper.xml` | `UserProfileService` |
| `UserTimeZoneMapper` | `mapper/wadiz/user/user-timezone-mapper.xml` | `UserProfileService`, `UserSettingsService` |
| `UserSettingsMapper` | `mapper/wadiz/user/userSettings-mapper.xml` | `UserSettingsService` |
| `DropAccountMapper` | `mapper/privacy/dropAccountByWadiz-mapper.xml` | `DropAccountService` |
| `DestructionPrivacyMapper` | `mapper/wadiz/privacy/destructionPrivacy-mapper.xml` | `DropAccountService` (`registerDestructionPrivacy` 만) |
| `InactiveAccountByPrivacyMapper` | `mapper/privacy/inactiveAccount-mapper.xml` | `DropAccountService` (`updateDropAccount` 만) |

---

## 7. 경계 및 미탐색 영역

### 외부 jar 블랙박스 (본 repo 소스 내 확인 불가)
- `com.wadiz.wave.user.account.drop.domain.DropAccountRequest` — 필드 목록은 mapper 파라미터로만 유추(userId, userName, isDeleteSH, reasonText, nickName).
- `com.wadiz.wave.user.account.find.domain.RealName` — Builder 체인(`.userId`, `.decRealName`)만 관측.
- `com.wadiz.wave.user.account.common.domain.CommonAccountResponse` — `.Builder().isSuccess(true)` 만 관측.
- `com.wadiz.wave.user.account.join.constant.JoinEquityStatus`, `JoinResponseCode`, `com.wadiz.wave.user.account.join.domain.JoinEquity.*`, `com.wadiz.wave.user.account.join.vo.EnumMapperValue` — Builder/enum 사용 패턴만.
- `com.wadiz.wave.user.privacy.constant.RetentionGroup` — `getGroupItemKey`, `getGroupPeriod`, `getKey()` 만 관측. 실제 그룹 수/보관 일수는 이 repo에 없음.
- `com.wadiz.wave.user.privacy.domain.{DestructionPrivacyRequest, InactiveAccountRequest}` — Builder.
- `com.wadiz.wave.crypto.WadizCryptoUtil`, `WadizPassWordUtils`, `com.wadiz.wave.util.WadizSecurityEncodeUtil` — 외부 `wave_crypto` 버전.
- `com.wadiz.wave.exceptions.ServerSideException`, `com.wadiz.wave.user.privacy.exception.DecodingAccountDropoutKakaoUnlinkFailException`.

### 본 9개 컨트롤러 범위 외 (관측 가능하지만 분석 대상 아님)
- `com.wadiz.wave.user.privacy.*` 컨트롤러 5개 (`PrivacyDropoutController`, `InactiveAccountController`, `DecodingAccountReactivateController`, `CommonPrivacyController`, `DestructionPrivacyController`) — **휴면/재활성/파기 배치/관리자 관점** 담당. account 도메인의 `DropAccount` 와 기능적으로 맞물리지만 본 문서 범위 외.
- `BankController`(verification/bankaccount) — 1원이체·출금계좌 등 `bank-mapper.xml` 전체를 직접 쓰는 컨트롤러.
- 사용되지 않는 mapper 쿼리 여럿: `countByAccountType`, `selectMobileNumberInfoByUserId`, `selectNickNameByUserIds`, `selectByUserId`, `clearMobileNumberByUserId`, `detailByUserName`, `validUserId` (`account-infos-mapper.xml`) 는 account 9개 컨트롤러에서 호출되지 않음 (다른 도메인에서 참조 가능성).
- `SessionManagerMapper.selectToAdminRole`, `InviteEventMapper.*` — 같은 `account/` 매퍼 디렉터리 밑에 있지만 account 9개 컨트롤러 호출 대상 아님.

### 확인되지 않은 결합
- `DropAccountService` 내 `@Async` 메서드(`unLinkSns`, `dropSettings`) — 메인 트랜잭션이 롤백되어도 외부 IdP unlink 는 이미 호출되었을 가능성 존재. 재시도/보상 로직은 관측되지 않음.
- `CrmGatewayPublisher.publishDropOutInfo` — 내부 `sendMessage` 는 `RabbitMqPublisher` 기반클래스 (본 repo 포함 가능성 있으나 account 문서 범위 외). 발행 실패 시 로그만 남는지 예외로 올라가는지는 base class 확인 필요.
- `DropAccountRequest.isDeleteSH` 의 "SH" 의미 — 신한 관련 플래그로 추정되나 해당 값 사용부는 외부 jar 내에 있음.
- 실명/본인인증 단계(`IdCardVerifyLog.VerifyType`, `TbPersonalUserInfo` upsert) 는 `UserJoinStepStatus.IsIdCardVerified` 결과로만 관측. 실제 쓰기 주체는 이 repo의 다른 도메인(verification) 또는 외부 서비스.
- 권한/인증: 9개 컨트롤러에 `@PreAuthorize`, Spring Security 필터 관측 없음. `@Impersonatable` 같은 커스텀 어노테이션도 미사용. 일부 엔드포인트(`/type/initRealNameAuth`, `/type/joinLimitClear`, `/type/initMarketingParticipationHistory`) 는 **운영/QA 목적의 보호 없는 업데이트 API** 로 관측됨 — 운영 환경에서 IP/인증 제어가 별도 네트워크 레이어에서 이루어진다고 가정해야 함.

### 누락된 기술 사실
- Spring Boot 1.5.8 / Java 1.8 (`gradle.properties:11-12`) — `javax.validation` / `javax.annotation` 네임스페이스 사용.
- `@Transactional(value = "wadizTxManager")` — 다중 DataSource 전제(`wadiz_db`, `wadiz_user_stat`, `privacy` 등). MyBatis SQL 중 `FROM wadiz_db.UserProfile`, `INSERT INTO wadiz_user_stat.user_locale_history` 처럼 스키마 접두를 명시한 쿼리가 혼재 — 트랜잭션 매니저 구성은 본 문서 범위에서 확인 안 함.
