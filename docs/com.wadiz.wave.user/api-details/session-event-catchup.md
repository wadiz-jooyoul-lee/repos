# Session / Event Invite / CatchUp 상세 스펙

> **기록 범위**: `com.wadiz.wave.user` 리포 내부에서 관측 가능한 소스 코드(컨트롤러·서비스·JPA 엔티티·MyBatis XML·DDL)만 근거로 기술한다.
> - `com.wadiz.wave.session.WadizAdmHttpSession` / `com.wadiz.wave.lock.RedisLockManager` / `com.wadiz.wave.user.cache.CacheManagerService` / `com.wadiz.wave.crypto.WadizCryptoUtil` / `com.wadiz.wave.infrastructure.crm.CrmApiGateway` 같은 **공통 wave 라이브러리**는 타입·메서드 시그니처만 관측 가능하며, 내부 구현(Redis 키 스킴, 세션 저장소, Kafka 토픽 등)은 외부 의존성으로 표시한다.
> - Point Save / Product Catalog API는 외부 마이크로서비스이며 이 repo에서는 URL 규칙·요청 DTO·응답 JSON 파싱만 확인 가능하다.
> - MyBatis SQL 본문은 XML에서 그대로 인용하며, 추론한 SQL은 기록하지 않는다.

---

## 컨트롤러 인벤토리

| Controller | Base Path | Endpoint 수 | Storage / 외부 |
|---|---|---|---|
| `SessionManagerController` (`session/SessionManagerController.java:16`) | `/api/v1/users/session` | 2 | MyBatis (`webpages_UsersInRoles`) + 외부 Wave 세션 |
| `InviteEventManagerController` (`event/controller/InviteEventManagerController.java:17`) | `/api/v1/users/event/invite` | 3 | MyBatis master + replication |
| `InviteEventInfoController` (`event/controller/InviteEventInfoController.java:20`) | `/api/v1/users/event/invite` | 5 | MyBatis replication |
| `InviteEventUserController` (`event/controller/InviteEventUserController.java:17`) | `/api/v1/users/event/invite` | 3 | MyBatis master + replication + Crypto |
| `InviteEventRewardController` (`event/controller/InviteEventRewardController.java:17`) | `/api/v1/users/event/invite/reward` | 2 | MyBatis master |
| `InviteEventV2Controller` (`event/v2/controller/InviteEventV2Controller.java:24`) | `/api/v2/users/event/invite` | 1 | `InviteEventUserService` 재사용 |
| `CatchUpController` (`catchup/adapter/in/CatchUpController.java:30`) | `/api` (헥사고날 adapter/in) | 12 | JPA (`wadiz_user` 스키마) + Redis + 외부 Point/Product/CRM |

**총 28 endpoints** (task 명세와 일치).

---

## 1. Session 도메인

### 배경
`SessionManagerController`는 `JSESSIONID`를 path variable로 받아 Wave 어드민 계정(관리자) 권한등급을 조회한다. `WEBSessionUtil.getSession(jsessionid)` → `WadizAdmHttpSession.getSession(jsessionid)` 경로로 **외부 wave 세션 스토어**(공용 라이브러리 `com.wadiz.wave.session`)에서 로그인 유저 정보를 복원한다. 이 repo 안에서는 저장소 구현을 관측할 수 없다 — Redis 여부는 확인 불가.

### 1.1. `GET /api/v1/users/session/{JSESSIONID}/role`
- **코드**: `SessionManagerController.java:22` → `SessionManagerService.findUserRole(jsessionid, false)` (`session/service/SessionManagerService.java:22`)
- **흐름**:
  1. `validation(JSESSIONID)`: 공백 검사 후 `WEBSessionUtil.getUserInfo(jsessionid).getUserId()` 확보 (`SessionManagerService.java:63-83`).
  2. 유효하면 `mapper.selectToAdminRole(userId)` 호출 → `SessionManager.UserRole` 빌드 (`SessionManagerService.java:40-44`).
  3. `refreshSession(JSESSIONID)`: `WadizAdmHttpSession.refreshSession()` 호출해 세션 TTL 연장 (`SessionManagerService.java:56-61`, 주석상 기본 30분).
  4. `ResponseWrapper.success(userRole)` 반환.
- **검증 실패**: `ResponseWrapper.fail(..., HttpStatus.BAD_REQUEST, ...)`를 **HTTP 200**로 감싸 반환 (`SessionManagerService.java:36`). 예외 시에도 200 + 에러 메시지.
- **Response 바디**: `ResponseWrapper` + `SessionManager.UserRole {userId, userRole, roleDesc}` (빌더 관측: `SessionManagerService.java:26-30`).

### 1.2. `GET /api/v1/users/session/{JSESSIONID}/role/bypass`
- **코드**: `SessionManagerController.java:29` → `findUserRole(jsessionid, true)`
- 테스트 우회용. 세션 검증을 건너뛰고 `userId=-1, userRole=2, roleDesc="bypass"` 고정 응답 (`SessionManagerService.java:25-32`).

### 관측 가능한 DB/외부호출
- **MySQL** `webpages_UsersInRoles` — `account-session-mapper.xml:5-9`:
  ```xml
  <select id="selectToAdminRole" resultType="Integer">
      SELECT RoleId
      FROM webpages_UsersInRoles
      WHERE UserId = #{userId}
  </select>
  ```
  Mapper namespace: `com.wadiz.wave.repository.wadiz.SessionManagerMapper`. 단일 쿼리만 정의되어 있음.
- **외부 wave 세션** (`com.wadiz.wave.session.WadizAdmHttpSession`): `.getSession(jsessionid)`, `.getAttribute(ADM_USER_INFO)`, `.refreshSession()` 메서드만 호출. 저장 백엔드 확인 불가.

### 용도 추정
컨트롤러 주석(`어드민등급정보 조회`)과 테이블명(`webpages_UsersInRoles`) 관찰로 보아, 레거시 ASP.NET WebPages 권한 모델을 그대로 공유하는 wadiz 어드민의 role 조회 용도. JSESSIONID 값을 path에 넣는 비표준 API 형태는 서버 간 role-check 내부 호출 용도로 추정되지만 caller는 이 repo에 없음.

---

## 2. Event Invite 도메인

### 구조
- **컨트롤러**: `controller/` 하위 4개 (v1) + `v2/controller/` 1개.
- **서비스**: `event/service/` 하위 5개 (`InviteEventManagerService`, `InviteEventInfoService`, `InviteEventUserService`, `InviteEventRewardService`, `InviteCodeService`).
- **모델**: `event/model/` 하위 11개 DTO + `InviteCodeValidType` enum.
- **두 개의 Mapper namespace**:
  - Master (쓰기): `com.wadiz.wave.repository.wadiz.InviteEventMapper` → `mapper/wadiz/account/account-event-invite-mapper.xml`
  - Replication (읽기): `com.wadiz.wave.repository.wadizReplication.account.SelectInviteEventMapper` → `mapper/wadizReplication/account/account-event-invite-mapper.xml`
- **Slave 지연 폴백**: `InviteEventUserService.isValidUserId(userId)`는 replication 조회 실패 시 `userAccountInfosMapper.validUserId(userId)` (master)로 재조회 (`InviteEventUserService.java:230-241`).

### 2.1. 이벤트 관리 (`InviteEventManagerController`)

#### `PUT /api/v1/users/event/invite/`
- **코드**: `InviteEventManagerController.java:22` → `InviteEventManagerService.registerInviteEvent(Object)` (`InviteEventManagerService.java:34`)
- **Request**: `Object inviteEventJson` (어떤 JSON이든 `ModelMapper`를 통해 `InviteEventDto`로 매핑 — `InviteEventConvert.java:16-18`).
- **InviteEventDto 필드** (`InviteEventDto.java`): `inviteEventKey, image, shareImage, shareImageUrlToKakao, mainTitle, backgroundColor, subTitle, rewardTemplateToOwner, rewardTypeToOwner, rewardTemplateToApplicant, rewardTypeToApplicant, notice, effectedFrom, effectedTo, inviteLink, isActive, registerUserId, registered`.
- **흐름**: `@Transactional` — `insertInviteEvent` 후 `updateInviteEventToIsActive`로 이전 활성 이벤트를 비활성화 (`InviteEventManagerService.java:40-45`).
- **SQL** (`account-event-invite-mapper.xml:7-33`):
  ```xml
  <insert id="insertInviteEvent" useGeneratedKeys="true" ...>
      INSERT INTO InviteEvent (Image, ShareImage, ShareImageUrlToKakao, BackgroundColor, MainTitle, SubTitle,
      RewardTemplateToOwner, RewardTypeToOwner, RewardTemplateToApplicant, RewardTypeToApplicant, Notice,
      EffectedFrom, EffectedTo, InviteLink, RegisterUserId, Registered)
      VALUES ( #{image} ,#{shareImage} ,#{shareImageUrlToKakao} ,#{backgroundColor} ,#{mainTitle} ,#{subTitle}
      ,#{rewardTemplateToOwner} ,#{rewardTypeToOwner} ,#{rewardTemplateToApplicant} ,#{rewardTypeToApplicant}
      ,#{notice} ,#{effectedFrom} ,#{effectedTo} ,#{inviteLink} ,#{registerUserId} ,#{registered} )
      <selectKey keyProperty="inviteEventKey" resultType="Integer" order="AFTER">
          SELECT LAST_INSERT_ID()
      </selectKey>
  </insert>
  ```
  (`account-event-invite-mapper.xml:36-41`):
  ```xml
  <update id="updateInviteEventToIsActive" ...>
      UPDATE InviteEvent SET IsActive = false
      WHERE InviteEventKey <![CDATA[<>]]> #{inviteEventKey}
        AND IsActive = true;
  </update>
  ```
- **실패 시**: `ExternalSideException("failed putInviteEvent!!")`.

#### `GET /api/v1/users/event/invite/list`
- **코드**: `InviteEventManagerController.java:29` → `InviteEventManagerService.findEventList()` (`InviteEventManagerService.java:61`)
- **SQL** (`wadizReplication/...:5-9`):
  ```xml
  <select id="selectInviteEventList" resultType="...InviteEventDto">
      <include refid="inviteEvent"/>
      ORDER BY IsActive DESC, InviteEventKey DESC
      LIMIT 15;
  </select>
  ```
- `inviteEvent` SQL 프래그먼트(`wadizReplication/...:17-37`): `InviteEvent` 테이블의 모든 표시 컬럼을 SELECT.

#### `GET /api/v1/users/event/invite/`
- **코드**: `InviteEventManagerController.java:35` → `InviteEventManagerService.findEvent()` (`InviteEventManagerService.java:78`)
- **SQL** (`wadizReplication/...:12-16`):
  ```xml
  <select id="selectInviteEvent" resultType="...InviteEventDto">
      <include refid="inviteEvent"/>
      WHERE IsActive = true
      ORDER BY InviteEventKey DESC LIMIT 1;
  </select>
  ```
  현재 활성 이벤트 1건 반환.

### 2.2. 이벤트 코드/페이지 정보 (`InviteEventInfoController`)

#### `GET /valid/{inviteCode}`
- **코드**: `InviteEventInfoController.java:25` → `InviteEventInfoService.validEventCode(...)` (`InviteEventInfoService.java:25`)
- **판정 로직** (`InviteEventInfoService.java:28-41`):
  - row 없음 → `NOT_EXIST`
  - 오늘 < `EffectedFrom` → `BEFORE_START`
  - 오늘 > `EffectedTo` → `AFTER_TERMINATE`
  - 그 외 → `VALID`
  - enum 정의: `InviteCodeValidType.java` = `NOT_EXIST, BEFORE_START, AFTER_TERMINATE, VALID`
- **SQL** (`wadizReplication/...:70-77`):
  ```xml
  <select id="selectInviteEventValidInfo" parameterType="String" ...>
      SELECT ie.EffectedFrom , ie.EffectedTo
      FROM InviteEvent ie
               INNER JOIN InviteOwner io ON ie.InviteEventKey = io.InviteEventKey
      WHERE io.InviteCode = #{inviteCode};
  </select>
  ```

#### `GET /find/{inviteCode}`
- **코드**: `InviteEventInfoController.java:32` → `InviteEventInfoService.findEventInfo(...)` (`InviteEventInfoService.java:58`)
- **SQL** (`wadizReplication/...:80-91`):
  ```xml
  <select id="selectInviteEventInfo" resultType="...InviteEventRewardInfo">
      SELECT iu.InviteOwnerKey , iu.OwnerUserId , ie.RewardTemplateToOwner
           , ie.RewardTypeToOwner , ie.RewardTemplateToApplicant , ie.RewardTypeToApplicant
           , #{inviteCode} AS inviteCode
      FROM InviteOwner iu
               INNER JOIN InviteEvent ie on iu.InviteEventKey = ie.InviteEventKey
      WHERE iu.InviteCode = #{inviteCode};
  </select>
  ```

#### `GET /page/apply/{inviteCode}`
- **코드**: `InviteEventInfoController.java:38` → `InviteEventInfoService.findApplyPageInfo(...)` (`InviteEventInfoService.java:76`)
- **SQL** (`wadizReplication/...:163-176`): 소유자 닉네임 + 응모자에게 지급될 리워드 템플릿 조회.
  ```xml
  <select id="selectApplicantPageInfo" parameterType="String" resultType="...InviteApplyPageInfo">
      SELECT ev.RewardTemplateToApplicant AS rewardTemplate,
             ev.RewardTypeToApplicant     AS rewardTemplateType,
             ev.Notice,
             up.NickName
      FROM (
               select io.OwnerUserId, ie.RewardTemplateToApplicant, ie.RewardTypeToApplicant, ie.Notice
               from InviteOwner io
                        inner join InviteEvent ie on io.InviteEventKey = ie.InviteEventKey
               where io.InviteCode = #{inviteCode}
           ) AS ev
               INNER JOIN UserProfile up ON ev.OwnerUserId = up.UserId;
  </select>
  ```

#### `GET /page/view`
- **코드**: `InviteEventInfoController.java:44` → `InviteEventInfoService.findEventPageViewInfo()` (`InviteEventInfoService.java:97`)
- **SQL** (`wadizReplication/...:128-147`): 현재 활성 이벤트의 **메인/공유 이미지 URL**, 카카오 공유 이미지, 배경색, 타이틀, 소유자 리워드 템플릿, 공지.
  ```xml
  <select id="selectEventPageViewInfo" resultType="...InviteEventViewInfo">
      SELECT ma.PhotoId AS mainImageId , ma.PhotoUrl AS mainImageUrl
      , sh.PhotoId AS shareImageId , sh.PhotoUrl AS shareImageUrl
      , ShareImageUrlToKakao , BackgroundColor , MainTitle , SubTitle
      , RewardTemplateToOwner as rewardTemplate , RewardTypeToOwner as rewardType
      , Notice , InviteLink
      FROM (
      <include refid="inviteEvent"/>
      where IsActive = true order by InviteEventKey desc LIMIT 1
      ) AS ie
      LEFT OUTER JOIN TbUploadPhoto ma on ie.Image = ma.PhotoId
      LEFT OUTER JOIN TbUploadPhoto sh on ie.ShareImage = sh.PhotoId;
  </select>
  ```

#### `GET /page/image`
- **코드**: `InviteEventInfoController.java:50` → `InviteEventInfoService.findEventPageImageInfo()` (`InviteEventInfoService.java:118`)
- **SQL** (`wadizReplication/...:149-159`): `TbUploadPhoto` 조인으로 메인/공유 이미지 url + 카카오 공유 이미지만 반환.

### 2.3. 이벤트 소유자/응모자 (`InviteEventUserController`)

> 모든 엔드포인트 `userId`는 **long형 encrypted** (`@PathVariable long encUserId`). `WadizCryptoUtil.decryptUserIdForLong(encUserId)`로 복호화 (`InviteEventUserService.java:127, 223`).

#### `GET /owner/{encUserId}`
- **코드**: `InviteEventUserController.java:22` → `InviteEventUserService.findInviteOwnerInfo(...)` (`InviteEventUserService.java:45`)
- **흐름** (`InviteEventUserService.java:45-76`):
  1. `getValidEncUserId(encOwnerUserId)` — 복호화 + Slave→Master 폴백 유효성 체크.
  2. `getInviteEventKey()` — 현재 활성 이벤트 key 획득 (없으면 예외) (`InviteEventUserService.java:244-250`).
  3. `inviteEventMapper.selectInviteCode(userId, inviteEventKey)` — 소유자가 이미 코드를 발급받았는지 조회.
  4. 이미 있으면 `selectApplicantTotalInfo(inviteCode)`로 응모자 6명 미리보기 수집.
- **SQL** (`account-event-invite-mapper.xml:74-80`):
  ```xml
  <select id="selectInviteCode" resultType="String">
      SELECT iu.InviteCode
      FROM InviteOwner iu
               INNER JOIN InviteEvent ie on iu.InviteEventKey = ie.InviteEventKey
      WHERE iu.OwnerUserId = #{ownerUserId}
        AND iu.InviteEventKey = #{inviteEventKey};
  </select>
  ```
- **SQL** (`wadizReplication/...:50-66`):
  ```xml
  <select id="selectApplicantTotalInfo" ...>
      SELECT up.UserId AS ApplicantUserId
           , up.NickName AS applicantNickName
           , pt.PhotoId
           , IFNULL(pt.PhotoUrl, '/resources/static/img/common/img_blank.png') AS PhotoUrl
      FROM (
               SELECT ia.ApplicantUserId
               FROM InviteApplicant ia
                        INNER JOIN InviteOwner io
                                   ON ia.InviteOwnerKey = io.InviteOwnerKey AND io.InviteCode = #{inviteCode}
               ORDER BY ia.ApplicantDate DESC LIMIT 300
           ) AS invite
               INNER JOIN UserProfile up ON invite.ApplicantUserId = up.UserId AND up.UserStatus = 'NM'
               LEFT OUTER JOIN PhotoCommon pt ON up.PhotoId = pt.PhotoId
      ORDER BY up.WhenCreated DESC LIMIT 6;
  </select>
  ```
- **Response**: `InviteOwnerInfo { inviteCode, alreadyOwner, applicantTotalInfos[] }` (`InviteEventUserService.java:64-69`).

#### `PUT /owner/{encUserId}`
- **코드**: `InviteEventUserController.java:28` → `InviteEventUserService.registerInviteOwner(...)` (`InviteEventUserService.java:85`, `@Transactional`).
- **흐름**:
  1. 유효 userId → 활성 event key 조회.
  2. 이미 코드가 있으면 예외 ("이미 등록 된 이벤트가 있습니다") (`InviteEventUserService.java:94-97`).
  3. `generateInviteCode(userId)` — `InviteCodeService.generateInvitationCode()`로 **10자리 [A-Z0-9] 랜덤** 문자열 생성 (`InviteCodeService.java:64-71`). `validInviteCode`로 중복 확인, 최대 **5회 재시도** (`InviteEventUserService.java:190-206`).
  4. `saveInviteEventCode(userId, inviteEventKey, inviteCode)` → `insertInviteOwner`.
- **SQL** (`account-event-invite-mapper.xml:45-56`):
  ```xml
  <insert id="insertInviteOwner" parameterType="...InviteOwnerDto">
      INSERT INTO InviteOwner (InviteEventKey, InviteCode, OwnerUserId, Registered)
      VALUES ( #{inviteEventKey} , #{inviteCode} , #{ownerUserId} , #{registered} )
      <selectKey keyProperty="inviteOwnerKey" resultType="Integer" order="AFTER">
          SELECT LAST_INSERT_ID()
      </selectKey>
  </insert>
  ```
- **SQL** 중복 확인 (`wadizReplication/...:120-124`):
  ```xml
  <select id="validInviteCode" resultType="Boolean">
      SELECT (CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END)
      FROM InviteOwner WHERE InviteCode = #{inviteCode};
  </select>
  ```

#### `PUT /apply/{encUserId}` (body: `int inviteOwnerKey`)
- **코드**: `InviteEventUserController.java:35` → `InviteEventUserService.registerInviteApplicant(...)` (`InviteEventUserService.java:124`)
- **흐름**:
  1. `WadizCryptoUtil.decryptUserIdForLong(encApplicantUserId)`로 복호화.
  2. `selectInviteEventMapper.validInviteOwnerKey(inviteOwnerKey)` 확인.
  3. `selectInviteApplicantKey(inviteOwnerKey, applicantUserId)`로 기존 참여 기록 확인 — 있으면 그대로 반환(재발급 방지) (`InviteEventUserService.java:135-141`).
  4. `insertInviteApplicant` 실행.
- **SQL** (`account-event-invite-mapper.xml:60-71`):
  ```xml
  <insert id="insertInviteApplicant" useGeneratedKeys="true" ...>
      INSERT INTO InviteApplicant (InviteOwnerKey, ApplicantUserId, ApplicantDate)
      VALUES ( #{inviteOwnerKey} , #{applicantUserId} , #{applicantDate} )
      <selectKey keyProperty="inviteApplicantKey" resultType="Integer" order="AFTER">
          SELECT LAST_INSERT_ID()
      </selectKey>
  </insert>
  ```
- **SQL** (`wadizReplication/...:94-101`):
  ```xml
  <select id="selectInviteApplicantKey" resultType="...InviteApplicantDto">
      SELECT InviteApplicantKey , IsRewardToOwner , IsRewardToApplicant
      FROM InviteApplicant
      WHERE InviteOwnerKey = #{inviteOwnerKey}
        AND ApplicantUserId = #{applicantUserId}
  </select>
  ```

### 2.4. 리워드 지급 (`InviteEventRewardController`)

두 엔드포인트 모두 `@RequestBody Integer inviteApplicantKey`를 받아 해당 row의 리워드 지급 플래그/일자만 업데이트한다. **실제 포인트/쿠폰 발급 로직은 이 repo에 없다** — 단순히 지급 "완료 기록"만 남긴다. 호출자가 별도로 외부 쿠폰/포인트 서비스를 호출한 뒤 이 API로 체크-인한다고 추정된다 (caller 확인 불가).

#### `PUT /api/v1/users/event/invite/reward/owner`
- **코드**: `InviteEventRewardController.java:22` → `InviteEventRewardService.rewardToOwner(...)` (`InviteEventRewardService.java:26`)
- **SQL** (`account-event-invite-mapper.xml:83-88`):
  ```xml
  <update id="updateRewardDateToOwner" ...>
      UPDATE InviteApplicant
      SET IsRewardToOwner   = true
        , RewardDateToOwner = #{rewardDateToOwner}
      WHERE InviteApplicantKey = #{inviteApplicantKey}
  </update>
  ```

#### `PUT /api/v1/users/event/invite/reward/applicant`
- **코드**: `InviteEventRewardController.java:28` → `InviteEventRewardService.rewardToApplicant(...)` (`InviteEventRewardService.java:54`)
- **SQL** (`account-event-invite-mapper.xml:91-96`):
  ```xml
  <update id="updateRewardDateToApplicant" ...>
      UPDATE InviteApplicant
      SET IsRewardToApplicant   = true
        , RewardDateToApplicant = #{rewardDateToApplicant}
      WHERE InviteApplicantKey = #{inviteApplicantKey}
  </update>
  ```

### 2.5. V2 (`InviteEventV2Controller`)

#### `GET /api/v2/users/event/invite/user/{userId}/code`
- **코드**: `InviteEventV2Controller.java:34` → `InviteEventUserService.getCurrentOrNewInviteEventCode(userId)` (`InviteEventUserService.java:170`)
- **V1과의 차이점** (관측):
  - `userId`가 **plain int** (암호화 X). 0 이하이면 `NotActiveUserException` → 404.
  - 활성 이벤트가 없으면 `NoActiveInviteEventException` → 500 + `ErrorVo { message }` (컨트롤러 내 `@ExceptionHandler` — `InviteEventV2Controller.java:53-60`).
  - 초대코드 생성 실패 시 `UnavailableInviteCodeException` → 500 (`InviteEventUserService.java:203`).
  - V1 `/owner` 엔드포인트는 이미 발급되어 있으면 에러를 내지만, V2는 **이미 있으면 그대로 반환, 없으면 생성 후 반환** (`InviteEventUserService.java:180-186`).
- **활성 판정 SQL (V1과 다름)** — `wadizReplication/...:40-46`:
  ```xml
  <select id="selectActiveInviteEvent" resultType="...InviteEventDto">
      <include refid="inviteEvent"/>
      WHERE IsActive = true
          AND EffectedFrom <![CDATA[ <= ]]> NOW()
          AND EffectedTo <![CDATA[ >= ]]> NOW()
      ORDER BY InviteEventKey DESC LIMIT 1;
  </select>
  ```
  V1 `selectInviteEvent`는 `EffectedFrom/EffectedTo` 체크 없이 `IsActive = true`만 본다 — V2는 기간 필터가 추가된 버전.
- **Response**: `InviteEventCodeDto { inviteCode }` (`event/v2/dto/InviteEventCodeDto.java`).

### 2.6. 초대코드 생성 알고리즘 (`InviteCodeService`)

- `generateInvitationCode()` (`InviteCodeService.java:64-71`): `SecureRandom`으로 `[A-Z0-9]` 36문자 중 10자 뽑음 (현재 v2에서 사용).
- `generationInviteCode(int userId)` (`InviteCodeService.java:37-62`): userId 각 자리수를 `BASE_STRINGS={H,3,E,F,G,6,8,T,V,X}`로 매핑 + 분기문자 `Q` + `RANDOM_STRINGS={4,7,9,A,B,C,D,J,K,L,M,N,P,R,U,W,Y}`로 10자 패딩. **현재 서비스 코드에서는 주석 처리되어 미사용** (`InviteEventUserService.java:193`). 역변환용 `decInviteCode(String)` (`InviteCodeService.java:79-94`)도 존재하나 호출처 없음.

### 2.7. Event Invite DTO/enum 인벤토리

| 파일 | 역할 |
|---|---|
| `InviteEventDto.java` | `InviteEvent` row 전체 매핑 |
| `InviteOwnerDto.java` | `InviteOwner` row (inviteOwnerKey, inviteEventKey, inviteCode, ownerUserId, registered) |
| `InviteApplicantDto.java` | `InviteApplicant` row (inviteApplicantKey, ownerKey, applicantUserId, applicantDate, isRewardToApplicant/Owner, rewardDateToApplicant/Owner) |
| `InviteEventValidInfo.java` | valid 판정용 (effectedFrom/To) |
| `InviteEventRewardInfo.java` | `/find` 응답 (소유자키, 리워드 템플릿) |
| `InviteApplicantTotalInfo.java` | 응모자 6명 미리보기 |
| `InviteOwnerInfo.java` | `/owner` 응답 wrapper |
| `InviteApplyPageInfo.java` | `/page/apply` 응답 |
| `InviteEventViewInfo.java` | `/page/view` 응답 |
| `InviteEventPageImageInfo.java` | `/page/image` 응답 |
| `InviteCodeValidType.java` | `NOT_EXIST, BEFORE_START, AFTER_TERMINATE, VALID` |
| `event/v2/dto/InviteEventCodeDto.java` | `{inviteCode}` |
| `event/v2/exception/*` | `NoActiveInviteEventException`, `NotActiveUserException`, `UnavailableInviteCodeException` |
| `event/v2/model/ErrorVo.java` | v2 에러 응답 |

---

## 3. CatchUp 도메인 (따라잡기)

### 헥사고날 구조
`catchup/` 패키지는 이 repo 내에서 유일한 헥사고날 adapter/core 레이아웃:

```
catchup/
├── adapter/
│   ├── in/CatchUpController.java                      (inbound adapter)
│   └── outbound/
│       ├── persistence/
│       │   ├── JPACatchUpRepository.java              ← CatchUpRepository 구현
│       │   ├── JPACatchUpPointRepository.java         ← CatchUpPointRepository 구현
│       │   ├── JPACatchUpEventRepository.java         ← CatchUpEventRepository 구현 + Redis 캐시
│       │   ├── JPANotificationRepository.java         ← NotificationRepository 구현
│       │   ├── RedisCacheAdapter.java                 ← CachePort 구현
│       │   ├── CatchUpEntityRepository.java           (Spring Data CrudRepository)
│       │   ├── CatchUpEventEntityRepository.java      (Spring Data JpaRepository)
│       │   ├── CatchUpPointEntityRepository.java
│       │   ├── CatchUpNotificationEntityRepository.java
│       │   ├── LocalDateToYyyyMMddConverter.java
│       │   └── entity/ (CatchUpEntity, ProductEntity, CatchUpPointEntity, CatchUpNotificationEntity,
│       │                 CatchUpEventEntity, CatchUpEvent, NullCatchUpEvent, BaseEntity)
│       └── external/
│           ├── point/PointAdapter.java                ← PointPort 구현 (외부 REST)
│           ├── product/ProductAdapter.java            ← ProductPort 구현 (외부 REST)
│           └── braze/BrazeAdapter.java                ← MarketingPort 구현 (CRM/Braze)
├── application/
│   ├── service/
│   │   ├── CatchUpService.java                        (핵심 오케스트레이션)
│   │   ├── NotificationService.java
│   │   ├── CatchUpTransactionService.java             (고차 함수 트랜잭션 래퍼)
│   │   └── PointResult.java, CatchUpCompleteRequest.java
│   └── config/ (RedisTemplateForPlatform, RestTemplateConfig)
├── domain/
│   ├── port/
│   │   ├── inbound/ (5 usecase 인터페이스 — 현재 미구현, 향후 리팩토링 대상)
│   │   └── outbound/ (CachePort, CatchUpRepository, CatchUpEventRepository,
│   │                   CatchUpPointRepository, NotificationRepository, ProductPort,
│   │                   PointPort, MarketingPort, PointSaveResult)
│   ├── model/CatchUpEvents.java
│   ├── exception/ (CatchUpException, CatchUpNotExistsException, ProductNotExistsException,
│   │              PointNotSavedException, ProductPortException)
│   └── (ProductId, ProductType {COMING_SOON, STORE, REWARD, PREORDER},
│         ProductAction {NO_ACTION, PASS, WISH, NOTIFICATION}, CatchUpPointType {DAILY})
└── dto/request, dto/response
```

**inbound port 인터페이스 존재 여부** (관측): `GetDaysStatusUsecase`, `GetDayStatusUsecase`, `GetCatchUpProjectsUsecase`, `CompleteProjectUsecase`, `ManageCatchUpNotificationUsecase` 파일이 존재하지만, 컨트롤러는 **application 서비스를 직접 주입**(`CatchUpService`, `NotificationService`)해 usecase 포트를 우회한다. 현시점 inbound port는 "선언은 있으나 미적용" 상태.

### 용도 (기능 요약, 주석·네이밍 기반)
- **"일일 찜/알림/패스 체크 & 포인트 지급 게임"**. 유저가 하루에 노출된 상품 목록(product) 각각에 대해 `WISH`/`NOTIFICATION`/`PASS` 액션을 찍으면 하루치 catchup 완료 처리, 포인트 지급, Braze CRM 이벤트 송신.
- **Streak(연속일)**: `getStreakNumber()` — 어제 complete 여부 체크해서 연속일 +1 (`CatchUpService.java:142-150`).
- **Multiplier**: streak 6일마다 6배, 3일마다 3배, 그 외 1배 (`CatchUpService.java:129-137`). 기본 포인트 `NORMAL_POINT = 50` (`CatchUpService.java:28`). 추가로 현재 활성화된 `CatchUpEvent`의 multiplier가 곱해짐.

### 3.1. 엔드포인트 인벤토리 (12개)

| # | Method Path | 설명 | Service |
|---|---|---|---|
| 1 | `GET /v1/users/{userId}/catchup/today/status` | 오늘 catchup 완료 여부·지급 포인트·남은 초 | `catchUpService.getTodayCatchUp(userId, LocalDate.now())` |
| 2 | `GET /v1/users/{userId}/catchup/today` | 오늘 상품 리스트 조회(없으면 생성) — Redis lock 내부 | `getCatchUpProductsWithLock(...)` |
| 3 | `POST /v1/users/{userId}/catchup/today` | 상품 하나 완료 (action: WISH/NOTIFICATION/PASS) | `completeProduct(userId, today, request)` |
| 4 | `GET /v1/users/{userId}/catchup/days` | 오늘 포함 3일 현황 | `get3DaysCatchUpStatus(...)` |
| 5 | `GET /v2/users/{userId}/catchup/days` | 3일치 엔티티로 6일 응답 빌드 | `get6DaysCatchUpStatus(...)` |
| 6 | `GET /v3/users/{userId}/catchup/days` | **6일치 엔티티로 6일 응답 + 전체 CatchUpEvent 목록 동봉** | `get6DaysCatchUpStatusForPhase2(...)` |
| 7 | `GET /v1/users/{userId}/catchup/history?date=yyyy-MM-dd` | 지정일로부터 9일 전 기록 | `getNDaysCatchUpStatusFrom(userId, date, 9)` |
| 8 | `PUT /v1/users/{userId}/catchup/notification` | 알림 신청 on/off | `notificationService.registerNotification(...)` |
| 9 | `GET /v1/users/{userId}/catchup/notification` | 알림 신청 여부 | `notificationService.getNotification(...)` |
| 10 | `POST /v1/users/bulk/catchup/complete` | 여러 userId에 대해 bulk complete (이미 product complete 전제) | `completeBulkCatchUps(userIds, today)` |
| 11 | `GET /v1/catchup/event/active` | 현재 활성 이벤트 1건 (Redis 캐시 TTL 1h) | `getActiveEvent()` |
| 12 | `POST /v1/catchup/event/cache/evict` | 관리자용 Redis 캐시 강제 갱신 | `evictEventCache()` |

### 3.2. 엔드포인트 세부

#### `GET /v1/users/{userId}/catchup/today/status`
(`CatchUpController.java:35`)
- `catchUpRepository.findCatchUpByUserIdAndDay(userId, today)` → `CatchUpEntityRepository.findByUserIdAndDate(...)` (products 미페치, `JPACatchUpRepository.java:37-39`).
- Response `GetTodayCatchUpStatusResponse {date, completed, point, remainingTimeInSecond}` (`GetTodayCatchUpStatusResponse.java`). row 없으면 `incompleteStatus(today)`.

#### `GET /v1/users/{userId}/catchup/today`
(`CatchUpController.java:45`) — 오늘치 상품 목록 생성 or 갱신.
- **Redis lock**: `cachePort.lock(userId + today)` (`CatchUpService.java:159-168`). `RedisCacheAdapter`가 `RedisLockManager.trySpinLock(LockType.CATCHUP, key, "Locking", 60, 15, 5000)` 호출 (`RedisCacheAdapter.java:19-27`). — wave 공통 Redis Lock 라이브러리.
- **흐름** (`CatchUpService.java:177-192`):
  1. `!catchUpRepository.existsUser(userId)` → `firstTime` 판정.
  2. 오늘 엔티티 없으면: `productPort.getProductsOfToday(userId)` 호출 → `/catchup/{userId}` 외부 API — `ProductAdapter.java:42-57` — 응답 `code==2000`이면 `data` 추출 후 `createCatchupWithProducts(...)`로 `catch_up` + `catch_up_product` 저장.
  3. 이미 있으면: `getProductsByProductIds([...])` 로 상품 최신 상태 동기화 (블록된 상품 마킹) `POST /products` 외부 API — `ProductAdapter.java:60-75`.
  4. 모두 complete 상태이면 `completeCatchUp()` (포인트 지급) 실행.
  5. `previousCatchUp` 로드 후 `CatchUpProductListResponse` 생성.

#### `POST /v1/users/{userId}/catchup/today`
(`CatchUpController.java:56`)
- `Request CompleteProductRequest {productId, productType, action}` (`dto/request/CompleteProductRequest.java`).
- `CatchUpEntity.completeProduct(productId, type, action)` — idempotent, PASS은 다른 action으로 덮어쓸 수 있음 (`CatchUpEntity.java:117-129`).
- 모든 product 완료 시 `completeCatchUp(userId, today, catchUp)` 호출.

#### `completeCatchUp` 내부 (`CatchUpService.java:78-104`)
1. `getPointForTodayNew(userId, today)`:
   - `streakNumber = getStreakNumber(userId, today)` — 어제 엔티티 `streak` + 1 (`CatchUpService.java:142-150`).
   - `streakMultiplier = getStreakMultiplier(streakNumber)` — 6배/3배/1배.
   - `CatchUpEvent event = catchUpEventRepository.findByDateTime(now)` — Redis 캐시된 이벤트 중 현재 활성 이벤트 조회 or `NullCatchUpEvent`.
   - `point = NORMAL_POINT * streakMultiplier * eventMultiplier` (`CatchUpService.java:113-121`).
2. `pointPort.savePoint(userId, point)` — 외부 Point API 호출 `POST {signature.points.api.url}/issues/with-save`. 500 에러 시 1회 재시도 (500ms delay) (`PointAdapter.java:43-70`). Request `SavePointRequest.forCatchUp(userId, point)` — `{templateIdType=TEMPLATE_ALIAS, templateAlias=CATCHUP_POINT, accountIdType=USER_ID, amount, userId}` (`SavePointRequest.java:24-32`). 응답에서 `issue.issueKey`, `saveTransaction.transactionKey` 추출.
3. `marketingPort.sendCompleteness(userId, point)` — `@Async`, `CrmApiGateway.sendCompleteness(userId, "catchup_complete", {catchup_complete_point: point})` (`BrazeAdapter.java:21-25`).
4. `CatchUpPointEntity.createDailyPoint(userId, today, point, multiplier, issueKey, transactionKey)` 저장.
5. `catchUp`의 `completed=true`, `point`, `multiplier`, `streak`, `pointIssueKey`, `pointTransactionKey`, `pointId` 세팅.

> 순서상 `marketingPort.sendCompleteness`는 `@Async` (`BrazeAdapter.java:21`). 포인트가 저장된 후 즉시 호출되며, 실패해도 트랜잭션에 영향 없음.

#### `GET /v1/users/{userId}/catchup/days`
(`CatchUpController.java:66`, `CatchUpService.java:248`)
- `findCatchUpByUserIdAndBetweenStartDayAndEndDay(userId, today.minusDays(2), today)` → 3일 엔티티.
- `DayCatchUpResponseCollectionBuilder.fromDay(today.minusDays(2)).set(catchUps).build()` — 3일 응답.

#### `GET /v2/users/{userId}/catchup/days`
(`CatchUpController.java:76`, `CatchUpService.java:258`)
- size=3 days (today 포함), `findNPreviousDaysMapByUserIdAndBetweenDays(userId, today, 3)`. 빈 날짜는 빈 엔티티로 채움(`JPACatchUpRepository.java:47-59`).
- `DayCatchUpResponseV2CollectionBuilder.fromPreviousCatchUps(catchUps).setEvent(currentEvent).buildNDays(6)` — 결과는 **6일** 응답(과거 3 + 미래 3 빈칸인지는 builder 내부 — 관측 불가).

#### `GET /v3/users/{userId}/catchup/days`
(`CatchUpController.java:86`, `CatchUpService.java:272`)
- size=6 (V2 대비 엔티티 조회 범위 확대). 전체 이벤트 `catchUpEventRepository.findAll()`을 `CatchUpEvents`로 감싸 전달.
- `builder.buildNDaysNewer(6, new CatchUpEvents(catchUpEvents))` 호출.
- V2→V3 차이: 참조하는 과거 catchup 엔티티 수가 3→6, 이벤트 전체 목록 동봉(여러 이벤트를 클라이언트 앞단에서 참조 가능).

#### `GET /v1/users/{userId}/catchup/history?date=yyyy-MM-dd`
(`CatchUpController.java:96`)
- `yyyy-MM-dd` 파싱 실패 시 `DateTimeParseException` → 글로벌 `@ExceptionHandler(Exception.class)`에서 500.
- `getNDaysCatchUpStatusFrom(userId, date, 9)` — 지정일 포함 9일 맵을 `PreviousCatchUpData.fromMap(map, catchUpEvents)` 로 반환.

#### `PUT /v1/users/{userId}/catchup/notification`
(`CatchUpController.java:110`)
- Request `NotificationRequest {boolean on}`.
- `NotificationService.registerNotification(userId, request)` (`NotificationService.java:21-33`):
  - entity 없으면 생성 후 저장. `on=true` 이면 즉시 `marketingPort.sendCatchUpNotification(userId, true)` 호출.
  - entity 있고 상태가 바뀐 경우에만 `marketingPort.sendCatchUpNotification(userId, on)` (Braze 이벤트: `catchup_subscribe_agree` or `catchup_subscribe_disagree`, `BrazeAdapter.java:15-18, 29-33`).
- `CatchUpNotificationEntity` row는 `user_id` = PK, `is_requested` (`catch_up_notification` 테이블, `CatchUpNotificationEntity.java:11-18`).

#### `GET /v1/users/{userId}/catchup/notification`
(`CatchUpController.java:120`)
- entity 없으면 `NotificationResponse(false)`.
- 있으면 `NotificationResponse(entity.isOn())`.

#### `POST /v1/users/bulk/catchup/complete`
(`CatchUpController.java:130`)
- Request `List<Integer> userIds`.
- 각 userId 에 대해 오늘 catchUp 엔티티를 조회해, **상품이 모두 complete 됐다면** `completeCatchUp()`를 호출 (`CatchUpService.java:53-67`). 즉 "상품 완료까지는 클라이언트에서 했고, 포인트/CRM만 서버 배치로 정리"하는 용도. 존재하지 않으면 skip. 반환은 성공한 userId의 응답 리스트.

#### `GET /v1/catchup/event/active`
(`CatchUpController.java:145`, `CatchUpService.java:319`)
- `JPACatchUpEventRepository.findActiveEventEntity(now)` → JPA `@Query` `WHERE isActive=true AND startTime <= :now AND endTime >= :now ORDER BY id DESC` 첫 row (`CatchUpEventEntityRepository.java:23-39`).
- Response `ActiveCatchUpEventResponse.fromCatchUpEventEntity(activeEvent)`.
- 참고: 이 엔드포인트는 JPA 직접 조회로 **Redis 캐시 경유 X** (`getActiveEvent` 주석은 TTL 1h라 하나, 구현은 JpaRepository 직접 호출 — `JPACatchUpEventRepository.java:120-122`).

#### `POST /v1/catchup/event/cache/evict`
(`CatchUpController.java:154`)
- `JPACatchUpEventRepository.evictCache()` — Redis 키 `catchup:events:all` 재 set (DB에서 reload 후 TTL 1h로 set) (`JPACatchUpEventRepository.java:128-147`).

### 3.3. Redis 캐시 / 락

- **Lock** (`RedisCacheAdapter`): `RedisLockManager.LockType.CATCHUP`, 만료 60초, 15회 스핀, 5000ms 대기. `GET /today` 동시성 보호용.
- **Event 캐시** (`JPACatchUpEventRepository`): 키 `catchup:events:all`, TTL 60 * 60 = 3600초, 값 `List<CatchUpEvent>` (`JPACatchUpEventRepository.java:26-27`). `CacheManagerService<List<CatchUpEvent>>` (공통 lib)로 set/get. `findByDateTime(now)`는 전체를 캐시에서 받아 `isOn(now)` 필터.

### 3.4. 트랜잭션 매니저

`CatchUpService`의 `@Transactional(transactionManager = "wadizJpaTransactionManager")` (`CatchUpService.java:39, 52, 223, 247, 257, 271, 285, 318`). MyBatis 트랜잭션 매니저와 분리된 JPA 전용 매니저가 bootstrap 설정에 있을 것으로 추정(확인 불가 — `application/config` 디렉터리엔 `RedisTemplateForPlatform`, `RestTemplateConfig` 2개만 관측).

---

## 4. DB 스키마

### 4.1. Event Invite (MyBatis 기반, 기존 wadiz 레거시 DB)

| 테이블 | 관측 가능한 컬럼 (XML에 등장한 것만) |
|---|---|
| `InviteEvent` | `InviteEventKey`, `Image`, `ShareImage`, `ShareImageUrlToKakao`, `BackgroundColor`, `MainTitle`, `SubTitle`, `RewardTemplateToOwner`, `RewardTypeToOwner`, `RewardTemplateToApplicant`, `RewardTypeToApplicant`, `Notice`, `EffectedFrom`, `EffectedTo`, `InviteLink`, `IsActive`, `RegisterUserId`, `Registered` |
| `InviteOwner` | `InviteOwnerKey`, `InviteEventKey`, `InviteCode`, `OwnerUserId`, `Registered` |
| `InviteApplicant` | `InviteApplicantKey`, `InviteOwnerKey`, `ApplicantUserId`, `ApplicantDate`, `IsRewardToOwner`, `RewardDateToOwner`, `IsRewardToApplicant`, `RewardDateToApplicant` |
| `UserProfile` (외부 테이블, 조회만) | `UserId`, `NickName`, `UserStatus` ('NM'), `WhenCreated`, `PhotoId` |
| `PhotoCommon`, `TbUploadPhoto` | `PhotoId`, `PhotoUrl` (프로필/이벤트 이미지) |
| `webpages_UsersInRoles` (Session) | `UserId`, `RoleId` |

DDL은 `com.wadiz.wave.user` repo의 `ddl/` 에 별도 제공되지 않음 — 레거시 테이블. **스키마는 wadiz core DB에 있고 이 repo는 read/write만 수행**.

### 4.2. CatchUp (`wadiz_user` 스키마, JPA)

DDL: `ddl/create-catchup.sql`.

| 테이블 | 컬럼 (관측) | 인덱스/FK |
|---|---|---|
| `catch_up` | `catch_up_id` (PK, AI), `user_id`, `catch_up_date` (VARCHAR(8) DDL / LocalDate JPA), `is_completed`, `point`, `point_multiplier`, `streak`, `point_issue_key`, `point_transaction_key`, `point_id`, `registered_at`, `updated_at` | unique `UK_catch_up__user_id_date (user_id, catch_up_date)` |
| `catch_up_product` | `catch_up_product_id` (PK, AI), `catch_up_id` (FK), `product_id`, `product_type` (COMING_SOON/STORE/REWARD/PREORDER), `action_type` (NO_ACTION/PASS/WISH/NOTIFICATION), `is_completed`, `is_blocked`, `order_no`, `registered_at`, `updated_at` | FK `FK_PRODUCT_CATCHUP → catch_up(catch_up_id)` |
| `catch_up_notification` | `user_id` (PK), `is_requested`, `registered_at`, `updated_at` | — |
| `catch_up_point` (DDL 없음, JPA 엔티티만 관측) | `point_id` (PK, AI), `user_id`, `point_type` (DAILY), `point_issue_base_date` (yyyyMMdd), `point_amount`, `point_multiplier`, `point_issue_key` (FK→외부 point 서비스), `point_transaction_key` | idx `IDX_catch_up_point__user_type_date(user_id, point_type, point_issue_base_date)` |
| `catch_up_event` (DDL 없음, JPA 엔티티만 관측) | `catch_up_event_id` (PK, AI), `event_name`, `event_start_time` (TIMESTAMP), `event_end_time` (TIMESTAMP), `event_multiplier`, `is_active` | idx `IDX_catch_up_event__is_active_event_date(is_active, event_start_time, event_end_time)` |

> `catch_up_point`/`catch_up_event` 테이블은 `ddl/create-catchup.sql`엔 없지만 JPA 엔티티 (`CatchUpPointEntity.java`, `CatchUpEventEntity.java`) 의 `@Table`/`@Index` 애너테이션에서 관측 가능. `ddl/streak-update.sql` / `change_20250110.sql`에 추가 ALTER가 있을 것으로 추정되나 본 문서에서는 다루지 않음.

---

## 5. 외부 의존성

| 영역 | 어디에서 쓰이나 | 바인딩 방식 |
|---|---|---|
| Wave 공용 세션 (`com.wadiz.wave.session.WadizAdmHttpSession`) | Session — JSESSIONID 검증 | 컴파일 타임. 저장소 백엔드 확인 불가 |
| Wave 암호 유틸 (`com.wadiz.wave.crypto.WadizCryptoUtil`) | Event Invite v1 — `long encUserId ↔ int userId` 복호화 | `decryptUserIdForLong(long)` |
| Wave Redis Lock (`com.wadiz.wave.lock.RedisLockManager`) | CatchUp — `GET /today` 동시성 보호 | `LockType.CATCHUP`, 60s expire |
| Wave CacheManagerService (`com.wadiz.wave.user.cache.CacheManagerService`) | CatchUp — 이벤트 목록 캐시 | key `catchup:events:all`, TTL 3600s |
| Wave CRM Gateway (`com.wadiz.wave.infrastructure.crm.CrmApiGateway`) | CatchUp — `BrazeAdapter` 내부 | `sendCompleteness`, `sendCatchupNotificationAgreement` — Braze 이벤트 전송 |
| **Point Service** (외부) | CatchUp — 하루치 포인트 지급 | `POST {signature.points.api.url}/issues/with-save`, `Bearer {signature.points.api.internal-token}`, `@Qualifier("fundingStoreRestTemplate")` RestTemplate. 재시도 2회 (500ms delay). 응답: `{issue:{issueKey}, saveTransaction:{transactionKey}}` |
| **Product/Catchup API** (외부) | CatchUp — 오늘 상품 목록, 상품 정보 조회 | `GET {wadiz.platform.catchup.base-url}/catchup/{userId}`, `POST {base-url}/products` body=List<ProductId>. `@Qualifier("catchUpRestTemplate")`. 응답 `{code:2000, data:[...]}` |
| 쿠폰/포인트 시스템 (Event Invite 리워드) | InviteEventRewardService 는 **DB 플래그만 갱신**. 실제 리워드 지급은 caller가 별도 호출 (caller 확인 불가) | 관측 불가 |
| 푸시 | 관측 없음 | Catchup은 Braze CRM 이벤트 (in-app/email), Event Invite는 푸시 호출 관측 안 됨 |
| `wadiz` 마스터 DB | Event Invite 쓰기, Session role 조회 | Mapper namespace `com.wadiz.wave.repository.wadiz.*` |
| `wadizReplication` 슬레이브 DB | Event Invite 읽기 (핫패스) + Session 없음 | Mapper namespace `com.wadiz.wave.repository.wadizReplication.*`. Slave 지연시 master로 폴백하는 케이스 존재 (`InviteEventUserService.java:232-240`) |
| `wadiz_user` DB + JPA (`wadizJpaTransactionManager`) | CatchUp 전용 스키마 | JPA / Hibernate. 헥사고날 adapter 에서만 사용 |

### 애플리케이션 프로퍼티 키 (관측)
- `signature.points.api.url`, `signature.points.api.internal-token` (`PointAdapter.java:30-31`)
- `wadiz.platform.catchup.base-url` (`ProductAdapter.java:36`)
- RestTemplate bean 이름: `fundingStoreRestTemplate`, `catchUpRestTemplate` (`@Qualifier` 지점만 관측)

---

## 6. 경계 및 미탐색 영역

- **Session 저장소 실체**: `WadizAdmHttpSession` 내부(Redis? Tomcat? 분산 세션?)는 이 repo에 없다.
- **Event Invite 리워드 실지급 파이프라인**: `InviteEventRewardService`는 `IsRewardToOwner/Applicant` 플래그만 세팅한다. "쿠폰·포인트·푸시"는 이 repo에서 관측되지 않음 — 외부 caller(가령 레거시 `com.wadiz.web` 배치, 또는 별도 리워드 배치)가 이 API로 체크인만 하는 구조로 추정되나 확인 불가.
- **V1 path `/`, `/list`, `/owner/`, `/apply/` 컨벤션**: 모든 path가 trailing slash를 가진 v1 스타일. Spring MVC 디폴트 매칭에 의존.
- **Hexagonal inbound port 미사용**: `catchup/domain/port/inbound/*Usecase.java`는 선언만 있고 컨트롤러가 application 서비스에 직접 결합. usecase 기반 재구성은 **예정된 리팩토링 신호**로 보이나 진행 여부 확인 불가.
- **CatchUp 배치 경로**: `POST /v1/users/bulk/catchup/complete`가 어떤 caller(크론/스케줄러/수동)에 의해 호출되는지 repo 내부에 없음. 추정: 전일 23:59 ~ 24:00 사이 진행 중 데이터 확정을 위한 내부 호출.
- **엔드포인트 3.1의 V2 builder 동작(3일→6일 변환)**: `DayCatchUpResponseV2CollectionBuilder`, `DayCatchUpResponseCollectionBuilder` 세부 로직은 응답 DTO 내부 — 본 문서에서는 엔드포인트 계약만 다루고 빌더 내부 계산식은 깊게 파지 않음.
- **`catch_up.catch_up_date` 컬럼 타입 불일치**: DDL은 `varchar(8)`, JPA 엔티티는 `LocalDate` + `length=8`. 읽기/쓰기 시 `LocalDateToYyyyMMddConverter`가 JPA AttributeConverter로 작동할 가능성이 높으나 이 문서에서는 상세 분석 생략.
- **`/v1/catchup/event/active` 엔드포인트 캐시 여부**: API 주석에는 "Redis 캐싱 TTL 1시간"이라 쓰여 있으나, 실제 호출 경로는 `JpaRepository`를 직접 질의하는 `findActiveEventEntity(now)` — 캐시 미사용. 캐시를 쓰는 경로는 `findByDateTime(now)` (`CatchUpService.getPointForTodayNew`에서만 사용)이다. 주석과 구현 불일치 관측.
- **`change_20250110.sql`, `streak-update.sql`, `drop-catchup.sql`** 의 DDL 변경 내역은 본 문서 범위 밖.

---

## 참고: 교차 검증

| 도메인 | 컨트롤러 수 | 엔드포인트 수 |
|---|---|---|
| Session | 1 | 2 |
| Event Invite (v1) | 4 | 3 + 5 + 3 + 2 = 13 |
| Event Invite (v2) | 1 | 1 |
| CatchUp | 1 | 12 |
| **합계** | **7** | **28** |

태스크 명세와 일치.
