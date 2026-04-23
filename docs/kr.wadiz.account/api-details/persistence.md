# `kr.wadiz.account` — Outbound Persistence 계층 (DB + Redis + IAM)

> `oauth2/adapters/outbound/persistence/` 하위 어댑터를 전수 분석한다.
> 이 서비스는 Wadiz 계정/OAuth2 인증서버로, **별도 스키마 두 벌(RDB)** 과 **Redis** 를 동시에 소유한다.

---

## 1. 기록 범위

**직접 읽은 파일** (총 103 파일 중 Java 파일 전수):

- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/common/BooleanToYNConverter.java`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/BaseEntity.java`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/user/` (21 파일: Entity, Repository, Mapper, util)
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/socialuser/` (Entity, Repository, Mapper)
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/photo/`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/marketingagreement/`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/marketingparticipation/`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/recommend/`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/userrecording/`
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/iam/authorization/` (7 파일)
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/iam/client/` (3 파일)
- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/redis/` (HttpSession, emailvalidationcode, passwordreset)

**보조로 읽은 설정/컨텍스트 파일**:

- `src/main/java/kr/wadiz/oauth2/application/config/DatasourceConfig.java`
- `src/main/java/kr/wadiz/oauth2/application/config/WadizDbJpaConfig.java`
- `src/main/java/kr/wadiz/oauth2/application/config/IamDbJpaConfig.java`
- `src/main/java/kr/wadiz/oauth2/application/config/RedisConnectionFactoryBeanPostProcessor.java`
- `src/main/java/kr/wadiz/oauth2/application/RememberMeConfig.java`
- `src/main/java/kr/wadiz/oauth2/application/authentication/SessionCleanerService.java`
- `src/main/resources/application.yml`, `application-dev.yml`
- `schema/mysql_ddl.sql` (IAM 스키마 초기본)

**미탐색 영역**:

- `src/main/java/kr/wadiz/oauth2/adapters/outbound/persistence/wadiz/user/util/` 하위 암호화 유틸 구현부 (`WadizPassWordUtils`, `Rfc2898DeriveBytes`, `WadizCryptoUtil` 등) — 암호화 로직 자체는 영역 외.
- `*.sql` 파일들 (각 엔티티와 동명의 참고용 SQL) — 스키마 샘플이나 코드 경로에서 주입되지는 않음.
- MyBatis XML 매퍼는 이 repo에 **존재하지 않음** (Spring Data JPA 만 사용).
- 테스트 코드 (`src/test/groovy/...`)는 분석 대상 외.

---

## 2. 개요 — 두 개의 RDB + Redis

### 2.1 Multi DataSource / 두 개의 JPA 영속 컨텍스트

이 서비스는 같은 MySQL 서버 내 **두 개의 별도 DB**(`wadiz_db`, `wadiz_iam`)를 각각의 `DataSource` / `EntityManagerFactory` / `TransactionManager` 로 분리한다.
Redis는 세션/임시토큰 저장소로 추가된다.

관찰된 구조 (`DatasourceConfig.java`):

```java
// application/config/DatasourceConfig.java:14-44
@Primary
@Bean(name = "iamConfig")
@ConfigurationProperties("spring.datasource.iam")
public DataSourceProperties iamProperties() { ... }

@Primary
@Bean(name = "iamDataSource")
public HikariDataSource iamDataSource(...) {
  hikariConfig.setPoolName("iam-db-pool");
  ...
}

@Bean(name = "wadizConfig")
@ConfigurationProperties("spring.datasource.wadiz")
public DataSourceProperties wadizProperties() { ... }

@Bean(name = "wadizDataSource")
public HikariDataSource wadizDataSource(...) {
  hikariConfig.setPoolName("wadiz-db-pool");
  ...
}
```

- **iamDataSource** 가 `@Primary`. Spring Security의 `JdbcTokenRepositoryImpl` (Remember-Me `persistent_logins`) 가 이 DataSource 를 쓴다 (`RememberMeConfig.java:40-46`).
- Hikari `maximum-pool-size: 10` (`application.yml:255`).

### 2.2 JPA Repository 스캔 경로 분리

`WadizDbJpaConfig.java:20-27` → `kr.wadiz.oauth2.adapters.outbound.persistence.wadiz` 패키지만 스캔.
`IamDbJpaConfig.java:22-33` → `kr.wadiz.oauth2.adapters.outbound.persistence.iam` 패키지만 스캔.

- `iamEntityManagerFactory` 는 `@Primary` (`IamDbJpaConfig.java:36-50`).
- `iamTransactionManager` 도 `@Primary` (`IamDbJpaConfig.java:52-57`).
- iam 쪽은 Hibernate `physical_naming_strategy` 를 `CamelCaseToUnderscoresNamingStrategy` 로 추가 적용 (`IamDbJpaConfig.java:68-75`).
  → Entity 필드 `registeredClientId` 가 `registered_client_id` 컬럼에 매핑된다.
- wadiz 쪽은 별도 naming strategy 지정 없음 → `@Column(name=...)` 로 개별 지정.

### 2.3 DB URL (dev 프로파일, `application-dev.yml:15-24`)

```yaml
spring.datasource:
  iam:
    url: jdbc:mysql://192.168.0.162:3306/wadiz_iam?...&connectionCollation=utf8mb4_unicode_ci&allowMultiQueries=true...
  wadiz:
    url: jdbc:mysql://192.168.0.162:3306/wadiz_db?...
```

→ 두 스키마는 **같은 MySQL 인스턴스** 안의 두 DB (`wadiz_iam`, `wadiz_db`).
`UserDropOutLogEntityRepository` 네이티브 쿼리가 `wadiz_db.UserDropOutLog` JOIN `wadiz_iam.persistent_logins` 로 두 DB를 물리적으로 크로스-DB JOIN 함 (`UserDropOutLogEntityRepository.java:19-28`).

### 2.4 책임 분리 개념표

| 스토리지 | 주 책임 | 소유 엔티티 |
|---|---|---|
| `wadiz_db` (RDB) | 회원 프로필, 비밀번호, 소셜 계정, 사진, 마케팅 동의, 사용자 변경 기록, 친구추천 | `UserProfile`, `webpages_Membership`(Password), `webpages_OAuthMembership`, `TbProviderProfile`, `UserDropOutLog`, `MarketingAgreement*`, `PhotoCommon`, `LoginHis`, `UserToken*`, `TbRecommendJoinEvent`, 외부 catalog `wadiz_maker.maker_info`, `wadiz_user_stat.user_locale_history` |
| `wadiz_iam` (RDB) | OAuth2 Authorization Server 상태 (RFC6749 + Spring Authorization Server 스키마) | `Authorization`, `AuthorizationConsent`, `RegisteredClient`, `persistent_logins` (JdbcTokenRepository) |
| Redis | 세션, 이메일 인증코드, 비밀번호 재설정 토큰, Remember-Me 캐시, 로그인 실패 카운터 | `spring:session`, `account:email:validation:code:*`, `account:user:password:reset:token:*`, custom rememberMe keys |
| HttpSession (서버측, Redis 백업) | 소셜 최초 로그인 중간 상태 | `HttpSessionSocialAccountRepository` (`SCOPE_SESSION` 속성) |

---

## 3. `wadiz_db` (wadiz DB) 스키마 — JPA 엔티티 전수 목록

> 공통 규약:
> - `BaseEntity` (wadiz/BaseEntity.java) 가 공통 `Updated` / `WhenCreated` 컬럼을 제공.
> - 일부 엔티티는 Lombok 대소문자 + `@Column(name="`...`")` 백틱으로 레거시 MS-SQL 풍 CamelCase 컬럼을 보존.
> - `BooleanToYNConverter` (common/BooleanToYNConverter.java:7-17) 로 `'Y'`/`'N'` char ↔ `Boolean` 변환.

### 3.1 `UserProfile` (Table: `UserProfile`) — 회원 코어

`wadiz/user/UserProfile.java:17-82`

```java
@Entity
@Table(name = "UserProfile")
public class UserProfile extends BaseEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "`UserId`") private Long userId;
  @Column(name = "UserName") private String username;
  @Column(name = "NickName") private String nickname;
  @Column(name = "Grade")                    @Builder.Default private String grade = "f";
  @Column(name = "AccntType") @Enumerated(EnumType.STRING) @Builder.Default
      private AccountType accountType = AccountType.N1000;
  @Column(name = "PhotoId") private Long photoId;
  @Column(name = "Birth") private String birth;
  @Convert(converter = BooleanToYNConverter.class)
  @Column(name = "ValidMobileNumber") private Boolean validMobileNumber;
  @Column(name = "CallingCode") private Integer callingCode;
  @Column(name = "MobileNumber") private String mobileNumber;
  @Column(name = "ValidEmail") private Boolean validEmail;
  @Convert(converter = BooleanToYNConverter.class)
  @Column(name = "ValidEmailFirstCheck") private Boolean validEmailFirstCheck;
  @Column(name = "AllowDM") private boolean allowDM;
  @Column(name = "JoinAuthType") @Enumerated(EnumType.STRING) private JoinAuth joinAuth;
  @Column(name = "UserStatus")   @Enumerated(EnumType.STRING) private UserStatus userStatus;
  @Column(name = "WhenLastLogon") private LocalDateTime lastLogonTime;
  @Column(name = "LanguageCode") private String language;
  @Column(name = "CountryCode")  private String country;
}
```

- 상속 `BaseEntity` → `Updated`, `WhenCreated` 자동.
- `UserStatus` (wadiz/user/UserStatus.java) 는 enum `NM(활성)/IA(휴면)/RA(활성Re)/DO(탈퇴)/USER_STATUS_EMPTY`.
- 관계: 물리 FK 없음. `photoId` → `PhotoCommon.photoId`, `userId` ← `Password.userId`, `SocialUser.userId`, `UserProvider.userId` 가 동일 PK 를 재사용 (식별 관계를 JPA 수준에서는 풀지 않음).

**`UserProfileRepository`** (wadiz/user/UserProfileRepository.java:14-60)

```java
@Repository @Transactional
public interface UserProfileRepository extends CrudRepository<UserProfile, Long> {
  Optional<UserProfile> findByUsername(String username);

  @Modifying
  @Query("update UserProfile user set user.lastLogonTime = current_timestamp() where user.userId = ?1")
  int updateLoginInfo(Long userId);

  int countByUsername(String username);

  @Query("SELECT new kr.wadiz.oauth2.adapters.outbound.persistence.wadiz.user.UserDTO(" +
         "user.userId, password.password, user.nickname, photo.photoUrl, user.username, " +
         "user.validEmail, user.mobileNumber, user.validMobileNumber, user.country, " +
         "user.language, maker.language) " +
         "FROM UserProfile user " +
         "LEFT JOIN PhotoEntity photo    ON user.photoId = photo.photoId " +
         "LEFT JOIN Password    password ON user.userId = password.userId " +
         "LEFT JOIN MakerInfo   maker    ON user.userId = maker.userId " +
         "where user.username = :username and user.userStatus = 'NM'")
  Optional<UserDTO> findUserDTOByUsername(@Param("username") String username);

  @Query(...) // userId 기준 동일 JOIN
  Optional<UserDTO> findUserDTOByUserId(@Param("userId") Long userId);
}
```

- JPQL JOIN 은 **관계 없는 엔티티** 를 `ON` 절로 조인 (비식별 연관) — Hibernate 6 의 non-related JOIN 지원.
- `UserStatus = 'NM'` 활성 회원만 반환 → 탈퇴/휴면은 로그인 경로에서 제외.

### 3.2 `Password` (Table: `webpages_Membership`)

`wadiz/user/Password.java:22-38` (레거시 `webpages_` 접두사 — MS-SQL 시절의 ASP.NET Membership 스키마 잔재).

```java
@Entity @Table(name = "webpages_Membership")
public class Password {
  @Id @Column(name = "`UserId`") private Long userId;
  @Column(name = "`Password`")   private String password;
  @CreationTimestamp @Column(name = "`CreateDate`", updatable = false)
      private LocalDateTime createdAt;
  @UpdateTimestamp   @Column(name = "`PasswordChangedDate`")
      private LocalDateTime updatedAt;
}
```

- PK `UserId` = `UserProfile.userId` (1:1 공유 PK).
- Password 해시 자체는 `UserToUserProfileMapper.encryptPassword` 에서 `WadizPassWordUtils.encode(...)` 로 생성 (`UserToUserProfileMapper.java:81-84`).

**`PasswordRepository`** (wadiz/user/PasswordRepository.java)

```java
@Repository
public interface PasswordRepository extends CrudRepository<Password, Long> {}
```

→ `findById`(userId), `save` 만 사용. 메서드 추가 없음.

### 3.3 `SocialUser` (Table: `webpages_OAuthMembership`) — 소셜 연결

`wadiz/socialuser/SocialUser.java:20-46` (역시 `webpages_` 접두사).

```java
@IdClass(value = SocialUserId.class)
@Entity @Table(name = "webpages_OAuthMembership")
public class SocialUser {
  @Id @Column(name = "`Provider`")       @Enumerated(EnumType.STRING) private Provider provider;
  @Id @Column(name = "`ProviderUserId`") private String providerUserId;
  @Column(name = "`UserId`")             private Long userId;
  @Column(name = "Token")                private String accessToken;
  @Column(name = "RefreshToken")         private String refreshToken;
  @UpdateTimestamp   @Column(name = "Updated")    private LocalDateTime lastUpdatedAt;
  @CreationTimestamp @Column(name = "Registered", updatable = false) private LocalDateTime createdAt;
}
```

- 복합키 (`SocialUserId` = `{Provider provider, String providerUserId}`).
- `Provider` enum (별도 `kr.wadiz.oauth2.common.Provider`): `kakao, google, naver, facebook, apple, line, email`.

**`SocialUserRepository`** (wadiz/socialuser/SocialUserRepository.java:11-15)

```java
public interface SocialUserRepository extends CrudRepository<SocialUser, SocialUserId> {
  List<SocialUser>     findByUserId(Long userId);
  Optional<SocialUser> findByUserIdAndProvider(Long userId, Provider provider);
}
```

### 3.4 `ProviderProfile` (Table: `TbProviderProfile`) — 소셜 부가정보

`wadiz/socialuser/ProviderProfile.java:19-71`

```java
@Entity @Table(name = "TbProviderProfile")
public class ProviderProfile {
  @Id @Column(name = "`userId`") private Long userId;
  @Column(name = "`provider`")    @Enumerated(EnumType.STRING) private Provider provider;
  @Column(name = "`gender`")      @Enumerated(EnumType.STRING) private Gender gender;
  @Column(name = "`birthday`")    private String birthday;
  @Column(name = "`birthyear`")   private String birthyear;
  @Column(name = "`friendscount`")private Integer friendscount;
  @CreationTimestamp @Column(name = "`created`", updatable = false) private LocalDateTime created;
  @UpdateTimestamp   @Column(name = "`updated`")                    private LocalDateTime updated;

  public boolean updateWith(ProviderProfile src) { /* gender/birthday/birthyear 차분 갱신 */ }
  public boolean hasUpdatingData()                { /* 비어 있으면 skip */ }
}
```

- PK = `userId` (소셜 공급자 정보의 대표값만 저장).
- `SocialAccountWithAdditionalInfoRepository.update` 에서 `updateWith(...)` 호출, 변경된 경우에만 save + log (`SocialAccountWithAdditionalInfoRepository.java:58-77`).

### 3.5 `ProviderProfileLog` (Table: `TbProviderProfileLog`) — 소셜 정보 변경 이력

`wadiz/socialuser/ProviderProfileLog.java:18-47`

```java
@Entity @Table(name = "TbProviderProfileLog")
public class ProviderProfileLog {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "`id`")        private Long id;
  @Column(name = "`userId`")    private Long userId;
  @Column(name = "`provider`")  @Enumerated(EnumType.STRING) private Provider provider;
  @Column(name = "`gender`")    @Enumerated(EnumType.STRING) private Gender gender;
  @Column(name = "`birthday`")   private String birthday;
  @Column(name = "`birthyear`")  private String birthyear;
  @Column(name = "`friendscount`") private Integer friendscount;
  @Column(name = "`created`")    private LocalDateTime created;
}
```

**Repository** (`ProviderProfileLogRepository.java:11-14`): `List<ProviderProfileLog> findProviderProfileLogByUserId(Long userId);`

### 3.6 `ProviderScope` (Table: `TbProviderScopes`) — 제공자 스코프 동의

`wadiz/socialuser/ProviderScope.java:19-71`

```java
@Entity @IdClass(ProviderScopeId.class) @Table(name = "TbProviderScopes")
public class ProviderScope {
  @Id @Column(name = "`userId`")    private Long userId;
  @Id @Column(name = "`provider`")  @Enumerated(EnumType.STRING) private Provider provider;
  @Id @Column(name = "`scope`")     private String scope;
  @Column(name = "`agreed`")        private boolean agreed;
  @CreationTimestamp @Column(name = "`created`", updatable = false) private LocalDateTime createdAt;
  @UpdateTimestamp   @Column(name = "`updated`")                    private LocalDateTime updatedAt;

  public static ProviderScope fromKakaoFriendsScope(Long userId, boolean agree) { ... }
}
```

- 복합키 `{userId, provider, scope}`. 카카오 친구 스코프(`scope="friends"`) 를 `KakaoAccountRepository.updateScope` 가 저장 (`KakaoAccountRepository.java:57-65`).

### 3.7 `UserProvider` (Table: `TbUserProviderInfo`) — 최초 가입 수단

`wadiz/user/UserProvider.java:13-27`

```java
@Entity @Table(name = "TbUserProviderInfo")
public class UserProvider {
  @Id @Column(name = "`userId`") private Long userId;
  @Column(name = "`provider`")   @Enumerated(EnumType.STRING) private Provider provider;
  @CreationTimestamp @Column(name = "`created`", updatable = false) private LocalDateTime createdAt;
}
```

- `UserToUserProviderMapper` (`UserToUserProviderMapper.java:19-25`) 는 첫 소셜 계정의 provider 를 저장, 없으면 `Provider.email` 로 저장.

### 3.8 `UserDropOutLogEntity` (Table: `UserDropOutLog`) — 탈퇴 이력

`wadiz/user/UserDropOutLogEntity.java:14-29`

```java
@Entity @Table(name = "UserDropOutLog")
public class UserDropOutLogEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
  @Column(name = "`DropOutId`") private Long dropOutId;
  @Column(name = "`UserId`")    private Long userId;
  @Column(name = "UserName")     private String username;
  @Column(name = "WhenCreated")  private LocalDateTime createdAt;
}
```

**Repository** (`UserDropOutLogEntityRepository.java:15-28`)

```java
@Repository @Transactional
public interface UserDropOutLogEntityRepository extends CrudRepository<UserDropOutLogEntity, Long> {
  Optional<UserDropOutLogEntity> findTop1ByUsernameAndCreatedAtIsGreaterThanEqual(String username, LocalDateTime nowMinus90Days);
  Optional<UserDropOutLogEntity> findTop1ByOrderByCreatedAtDesc();

  @Query(value = """
         SELECT u.* FROM wadiz_db.UserDropOutLog u 
         WHERE u.WhenCreated BETWEEN :startDate AND :endDate 
           AND EXISTS (SELECT 1 
                       FROM wadiz_iam.persistent_logins p 
                       WHERE p.username = CAST(u.UserId AS CHAR) COLLATE utf8mb4_unicode_ci)
         """, nativeQuery = true)
  List<UserDropOutLogEntity> findDroppedUsersWithPersistentTokens(@Param("startDate") String startDate, 
                                                                   @Param("endDate") String endDate);
}
```

- 유일한 **크로스-DB 네이티브 쿼리**: `wadiz_db.UserDropOutLog` × `wadiz_iam.persistent_logins`.
- 최근 90일 내 탈퇴 이력 조회는 `JpaUserRepository.hasDropoutHistory` 에서 사용 (`JpaUserRepository.java:208-211`). 90일 내 재가입 차단 정책.

### 3.9 `UserTokenEntity` + `UserTokenStandbyEntity` — 이메일 변경 인증

`wadiz/user/UserTokenEntity.java:14-49`

```java
@Entity @Table(name = "UserToken")
public class UserTokenEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "`TokenId`")    private Long tokenId;
  @Column(name = "`UserId`")     private Long userId;
  @Column(name = "`Unavailable`")private Boolean unavailable;
  @Column(name = "`TokenValue`") private String tokenValue;

  @OneToOne(mappedBy = "userToken", cascade = {CascadeType.PERSIST})
  private UserTokenStandbyEntity userTokenStandbyEntity;

  @Column(name = "`Expired`")    private LocalDateTime expiredAt;
  @CreationTimestamp @Column(name = "`Registered`", updatable = false)
                                 private LocalDateTime createdAt;
}
```

`wadiz/user/UserTokenStandbyEntity.java:11-43`

```java
@Entity @Table(name = "TbUserTokenStandby")
public class UserTokenStandbyEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "`StandbyId`") private Long standbyId;
  @OneToOne @JoinColumn(name = "TokenId") private UserTokenEntity userToken;
  @Column(name = "`UserId`")              private Long userId;
  @Column(name = "`StandbyUserName`")     private String standbyUserName; // 신규 이메일
  @Column(name = "`StandbyUserType`")     private String standbyUserType; // "D"
}
```

- **관측된 유일한 JPA 연관관계**: `UserTokenEntity` ↔ `UserTokenStandbyEntity` (양방향 `@OneToOne`, FK=`TokenId`, cascade PERSIST).
- 이메일 변경/재등록 시 새 이메일을 Standby에 담아두는 패턴. `UserDataChangeRecordRepositoryAdapter.createEmailCreationRecord` 에서 생성 (`UserDataChangeRecordRepositoryAdapter.java:31-35`).
- 두 Repository 모두 CRUD + `findByUserId(Long)` 만 (테스트용 주석).

### 3.10 `LoginHistory` (Table: `LoginHis`)

`wadiz/user/LoginHistory.java:15-32`

```java
@Entity @Table(name = "LoginHis") @Builder
public class LoginHistory {
  @GeneratedValue(strategy = GenerationType.IDENTITY) @Id
  @Column(name = "`HisNo`")       Long   id;
  @Column(name = "`ClientType`")  String clientType;
  @Column(name = "`UserId`")      Long   userId;
  @Column(name = "`SessionId`")   String sessionId;
  @Column(name = "`ReqDate`")     LocalDateTime requestDate;
  @Column(name = "`ReqIP`")       String requestIp;
  @Column(name = "`WaId`")        String waId;
}
```

**Repository** (빈 `CrudRepository`). 주입처 grep → 실제 사용처 없음. 레거시 포팅 엔티티로 보이며, 현재 기록 주체는 미탐색.

### 3.11 `PhotoEntity` (Table: `PhotoCommon`)

`wadiz/photo/PhotoEntity.java:16-66`

```java
@Entity @Table(name = "PhotoCommon")
public class PhotoEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "`PhotoId`")    private Long   photoId;
  @Column(name = "`UserId`")     private Long   userId;
  @Column(name = "`PhotoUrl`")   private String photoUrl;
  @Column(name = "`Thumbnail`")  private boolean existsThumbnail;
  @Column(name = "`WhenCreated`")private LocalDateTime createdAt;
  @Column(name = "`IsPublic`")   private boolean isPublic;
  @Column(name = "`ThumbnailUrl`") private String thumbnailUrl;
  @Column(name = "`AvgRgbHex`")  private String averageRgbHex;
  @Column(name = "`CharacterColor`") @Enumerated(EnumType.STRING) private CharacterColor characterColor; // R/G/B
  @Column(name = "`ThumbnailProc`")  @Enumerated(EnumType.STRING) private ThumbnailStatus thumbnailStatus; // N/R/P/Y/E/S
  @Column(name = "`ThumbnailCreated`") private LocalDateTime thumbnameCreatedAt;
}
```

- UserProfile 과 ID로만 연결 (JPA 연관 매핑 없음). `findUserDTOByUsername` JPQL 에서 `LEFT JOIN PhotoEntity photo ON user.photoId = photo.photoId` (UserProfileRepository:36).
- `PhotoEntityRepository` 는 빈 `CrudRepository`.

### 3.12 `MarketingAgreementEntity` (Table: `MarketingAgreement`) + History

`wadiz/marketingagreement/MarketingAgreementEntity.java:17-33`

```java
@Entity @Table(name = "MarketingAgreement")
public class MarketingAgreementEntity {
  @Id @Column(name = "`UserId`")   private Long userId;
  @Column(name = "`IsAgree`")      private boolean isAgree;
  @Column(name = "`Registered`")   private LocalDateTime createdAt;
  @Column(name = "`Updated`")      private LocalDateTime updatedAt;
  @Column(name = "`NotiDate`")     private LocalDate     notifiedAt;
}
```

`wadiz/marketingagreement/MarketingAgreementHistoryEntity.java:13-36`

```java
@Entity @Table(name = "MarketingAgreementHistory")
public class MarketingAgreementHistoryEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
  @Column(name = "`HistoryNo`")       private Long   historyNo;
  @Column(name = "`UserId`")          private Long   userId;
  @Column(name = "`IsAgree`")         private boolean isAgree;
  @Column(name = "`Registered`")      private LocalDateTime createdAt;
  @Column(name = "`Ip`")              private String ipAddress;
  @Column(name = "`Extra`")           private String additionalInformation;
  @Column(name = "`IsAutoExtended`")  private boolean isAutoExtended;
}
```

두 Repository 모두 빈 `CrudRepository`. 최신 상태 + 이력 분리 패턴.

### 3.13 `MarketingParticipationHistoryEntity` (Table: `MarketingParticipationHistory`)

`wadiz/marketingparticipation/MarketingParticipationHistoryEntity.java:12-37`

```java
@Entity @Table(name = "MarketingParticipationHistory")
public class MarketingParticipationHistoryEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
  @Column(name = "`HistoryNo`")    private Long    historyNo;
  @Column(name = "`HashingByKey`") private String  hash;
  @Column(name = "`KeyType`")      private String  keyType;
  @Column(name = "`UserId`")       private Long    userId;
  @Column(name = "`IsDelete`")     private boolean deleted;
  @Column(name = "`DeleteReason`") private String  deletedReason;
  @Column(name = "`Registered`")   private LocalDateTime createdAt;
}
```

Repository 역시 비어 있음. 해시 기반 식별.

### 3.14 `UserRecordingEntity` (Table: `TbUserRecordingInfo`)

`wadiz/userrecording/UserRecordingEntity.java:16-37`

```java
@Entity @Table(name = "TbUserRecordingInfo") @Builder
public class UserRecordingEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
  @Column(name = "`RecordNo`")      private Long   recordNo;
  @Column(name = "`RecordUserId`")  private Long   recordUserId;
  @Column(name = "`RecordType`")    private String recordType;
  @Column(name = "`RecordData`")    private String recordData;
  @CreationTimestamp @Column(name = "`Recorded`", updatable = false)
                                    private LocalDateTime recordedAt;
  @Column(name = "`TargetUserId`")  private Long   targetUserId;
}
```

**Repository** (`UserRecordingEntityRepository.java:11-18`)

```java
@Repository @Transactional
public interface UserRecordingEntityRepository extends CrudRepository<UserRecordingEntity, Long> {
  List<UserRecordingEntity> findByTargetUserIdOrderByRecordTypeDesc(Long targetUserId); // test only
}
```

**Adapter** (`UserDataChangeRecordRepositoryAdapter.java:17-36`) 가 `UserDataChangeRecordRepositoryPort` 를 구현.
`save(List<UserDataChangeRecord>)` → `saveAll` 로 Batch.
`createEmailCreationRecord(User)` → `UserTokenEntity.fromUserId(userId)` 생성 + standby 연결 → 양방향 cascade 로 저장.

### 3.15 `UserLocaleHistory` (Table: `user_locale_history`, Catalog: `wadiz_user_stat`)

`wadiz/user/UserLocaleHistory.java:11-28`

```java
@Entity @Table(name = "user_locale_history", catalog = "wadiz_user_stat")
public class UserLocaleHistory {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "`user_locale_history_id`") private Long    userLocaleHistoryId;
  @Column(name = "`user_id`")                 private Integer userId;
  @Column(name = "`language_code`")           private String  language;
  @Column(name = "`country_code`")            private String  country;
  @Column(name = "`source`")                  private String  source;
}
```

- `catalog = "wadiz_user_stat"` 로 **세 번째 DB 스키마**를 참조. `JpaUserRepository.create(...)` 가 회원 생성 시 기본값 `WEB_SIGNUP` 으로 기록 (`UserToUserLocaleHistoryMapper.java:10-11`).

### 3.16 `MakerInfo` (Table: `maker_info`, Catalog: `wadiz_maker`)

`wadiz/user/MakerInfo.java:18-26`

```java
@Entity @Table(name = "maker_info", catalog = "wadiz_maker")
public class MakerInfo {
  @Id @Column(name = "user_id")        private Long   userId;
  @Column(name = "language_code")      private String language;
}
```

- **네 번째 DB 스키마** `wadiz_maker`. JPA 읽기 전용(직접 저장 Repository 없음). JPQL `LEFT JOIN MakerInfo maker ON user.userId = maker.userId` 로 `UserDTO.makerLanguage` 에만 사용 (`UserProfileRepository.java:38`).

### 3.17 `RecommendJoinEventEntity` (Table: `TbRecommendJoinEvent`) — 추천 가입 이벤트

`wadiz/recommend/RecommendJoinEventEntity.java:14-27`

```java
@Entity @IdClass(RecommendJoinEventEntityId.class) @Table(name = "TbRecommendJoinEvent")
public class RecommendJoinEventEntity {
  @Id @Column(name = "`RecommendUserId`") private Long recommedingUserId;
  @Id @Column(name = "`JoinUserId`")      private Long joinedUserId;
  @Column(name = "`RegDate`")             private LocalDateTime createdAt;
}
```

복합키 `{recommedingUserId, joinedUserId}`. Repository 는 빈 `CrudRepository`.

### 3.18 다표 JPA 상호작용 — `JpaUserRepository` (Adapter)

`wadiz/user/JpaUserRepository.java:25-242` 는 도메인 포트 `UserRepositoryPort` 를 구현하는 **총 집합 Adapter**.
생성/조회의 트랜잭션 경계가 여기 있음 (Spring Data 단일 `@Transactional` 어노테이션은 interface 레벨에 선언된 것에 의존 — class 자체는 `@Service` 만).

핵심 흐름 `create(User)` (:42-66):
1. `userMapper.toUserProfile(user)` → `userProfileRepository.save(...)` → autogen `UserId` 회수.
2. 필요 시 `passwordRepository.save(Password)`.
3. `userProviderRepository.save(...)` (TbUserProviderInfo).
4. `userLocaleHistoryRepository.save(...)` (user_locale_history).
5. 소셜연결돼 있으면 `socialAccountRepositoryMap.getRepository(provider).create(user)` 위임 → 공급자별 추가처리.

조회 분기 (`fromUserProfileAndPassword`, `fromUserProfileAndSocialUser`, `fromUserProfile`): 호출 경로별로 동반 테이블을 선택적으로 로드.

### 3.19 Provider별 `SocialAccountRepository` 상속 트리

```
SocialAccountRepository (기본: socialUser 저장만)
└── SocialAccountWithAdditionalInfoRepository  (ProviderProfile 저장 + 로그)
    ├── KakaoAccountRepository   (accessToken/refreshToken + kakao friends scope 업데이트)
    ├── NaverAccountRepository   (추가 동작 없음)
    ├── FacebookAccountRepository(추가 동작 없음)
    └── LineAccountRepository    (accessToken/refreshToken 업데이트)
```

- `SocialAccountRepositoryMap` (`socialuser/SocialAccountRepositoryMap.java`) 가 `@PostConstruct` 로 Provider → Repository 매핑을 구축.
- google, apple 은 기본 `SocialAccountRepository` 재사용 (부가 정보 없음).

---

## 4. `wadiz_iam` (IAM DB) 스키마 — Spring Authorization Server 저장소

> `IamDbJpaConfig` 가 `CamelCaseToUnderscoresNamingStrategy` 를 적용하므로, Entity 필드 `registeredClientId` 가 실제 DB 컬럼 `registered_client_id` 에 매핑된다 (스네이크 케이스).

### 4.1 `Authorization` (Table: `` `Authorization` ``, 실제 DB: `authorization`)

`iam/authorization/Authorization.java:14-85`

```java
@Entity
@Table(name = "`Authorization`")
public class Authorization {
  @Id @Column private String id;
  private String registeredClientId;
  private String principalName;
  private String authorizationGrantType;
  @Column(columnDefinition = "BLOB") private String authorizedScopes;
  @Column(columnDefinition = "BLOB") private String attributes;
  @Column(length = 500)              private String state;

  @Column(columnDefinition = "BLOB") private String authorizationCodeValue;
  private LocalDateTime authorizationCodeIssuedAt;
  private LocalDateTime authorizationCodeExpiresAt;
  private String        authorizationCodeMetadata;

  @Column(columnDefinition = "BLOB") private String accessTokenValue;
  private LocalDateTime accessTokenIssuedAt;
  private LocalDateTime accessTokenExpiresAt;
  @Column(columnDefinition = "BLOB") private String accessTokenMetadata;
  private String                     accessTokenType;
  @Column(columnDefinition = "BLOB") private String accessTokenScopes;

  @Column(columnDefinition = "BLOB") private String refreshTokenValue;
  private LocalDateTime refreshTokenIssuedAt;
  private LocalDateTime refreshTokenExpiresAt;
  @Column(columnDefinition = "BLOB") private String refreshTokenMetadata;

  @Column(columnDefinition = "BLOB") private String oidcIdTokenValue;
  private LocalDateTime oidcIdTokenIssuedAt;
  private LocalDateTime oidcIdTokenExpiresAt;
  @Column(columnDefinition = "BLOB") private String oidcIdTokenMetadata;
  @Column(columnDefinition = "BLOB") private String oidcIdTokenClaims;

  // added
  @Column(columnDefinition = "BLOB") private String userCodeValue;
  private LocalDateTime userCodeIssuedAt;
  private LocalDateTime userCodeExpiresAt;
  @Column(columnDefinition = "BLOB") private String userCodeMetadata;
  @Column(columnDefinition = "BLOB") private String deviceCodeValue;
  private LocalDateTime deviceCodeIssuedAt;
  private LocalDateTime deviceCodeExpiresAt;
  @Column(columnDefinition = "BLOB") private String deviceCodeMetadata;
}
```

- Spring Authorization Server의 `OAuth2Authorization` → 엔티티 직렬화 (토큰 값/메타/스코프가 BLOB JSON으로 영속).
- `schema/mysql_ddl.sql` 에는 `device_code_*` / `user_code_*` 칼럼이 빠져 있어 (초기 DDL), 운영 스키마와 엔티티 사이에 마이그레이션 차이가 존재 가능.

**`AuthorizationRepository`** (iam/authorization/AuthorizationRepository.java:14-56)

```java
@Repository
public interface AuthorizationRepository extends JpaRepository<Authorization, String> {
  Optional<Authorization> findByState(String state);
  Optional<Authorization> findByAuthorizationCodeValue(String authorizationCode);
  Optional<Authorization> findByAccessTokenValue(String accessToken);
  Optional<Authorization> findByRefreshTokenValue(String refreshToken);
  Optional<Authorization> findByOidcIdTokenValue(String idToken);
  Optional<Authorization> findByUserCodeValue(String userCode);
  Optional<Authorization> findByDeviceCodeValue(String deviceCode);

  @Query("select a from Authorization a where a.accessTokenValue = :token" +
         " or a.refreshTokenValue = :token")
  Optional<Authorization> findByAccessTokenValueOrRefreshTokenValue(@Param("token") String token);

  @Transactional @Modifying
  @Query(value = "DELETE FROM authorization" +
         " WHERE (authorization_code_expires_at < :time AND access_token_expires_at is null)", nativeQuery = true)
  int deleteAuthorizationByAuthorizationCodeExpiresAtBeforeAndAccessTokenIsNull(@Param("time") LocalDateTime time);

  @Transactional @Modifying
  @Query(value = "DELETE FROM authorization WHERE principal_name = :principalName" +
         " AND (access_token_expires_at > NOW() OR refresh_token_expires_at > NOW())", nativeQuery = true)
  int deleteAuthorizationByPrincipalName(@Param("principalName") String principalName);

  @Transactional @Modifying
  @Query(value = "DELETE FROM authorization" +
         " WHERE (access_token_expires_at < :time AND refresh_token_expires_at is null)" +
         " OR (access_token_expires_at < :time and refresh_token_expires_at < :time)" +
         " LIMIT :batchSize", nativeQuery = true)
  int deleteAuthorizationByAccessTokenExpiresAtBeforeWithLimit(
      @Param("time") LocalDateTime time,
      @Param("batchSize") int batchSize);
}
```

- `@Modifying` + native SQL 로 배치 만료 삭제 (스케줄러가 호출).
- 토큰 값 조회 메서드 (`findByAccessTokenValue` 등) → Spring Authz Server의 `OAuth2AuthorizationService#findByToken` 구현을 위한 인덱스.

**`JpaOAuth2AuthorizationService`** (iam/authorization/JpaOAuth2AuthorizationService.java:38-277)

- Spring의 `OAuth2AuthorizationService` 를 구현. Jackson 으로 `attributes`, `metadata`, `oidcIdTokenClaims` 를 JSON 직렬화/역직렬화.
- `ObjectMapper` 에 등록되는 Mixin:
  - `SecurityJackson2Modules.getModules(...)` — Spring Security 표준.
  - `OAuth2AuthorizationServerJackson2Module` — authz 서버 표준.
  - `LongMixin` (빈 추상 클래스 `iam/authorization/LongMixin.java`) — Long 타입 deserializer 허용.
  - `WadizUserMixin`, `UserMixin`, `SocialAccountMixin`, `AgreementMixin`, `KakaoTermsMixin` — Wadiz 도메인 객체 직렬화 허용 (Spring Security의 allowlist 우회).
- `findByToken(token, tokenType)` 에서 tokenType 에 따라 state / code / access_token / refresh_token / id_token / user_code / device_code 로 분기.
- `save(OAuth2Authorization)` → `toEntity` 로 변환 후 JPA save. `remove` → `deleteById`.

### 4.2 `AuthorizationConsent` (Table: `` `AuthorizationConsent` ``, 실제 DB: `authorization_consent`)

`iam/authorization/AuthorizationConsent.java:11-76`

```java
@Entity
@Table(name = "`AuthorizationConsent`")
@IdClass(AuthorizationConsent.AuthorizationConsentId.class)
public class AuthorizationConsent {
  @Id private String registeredClientId;
  @Id private String principalName;
  @Column(length = 1000) private String authorities;

  public static class AuthorizationConsentId implements Serializable {
    private String registeredClientId;
    private String principalName;
    // equals/hashCode
  }
}
```

**Repository** (`AuthorizationConsentRepository.java:9-13`)

```java
public interface AuthorizationConsentRepository
        extends JpaRepository<AuthorizationConsent, AuthorizationConsent.AuthorizationConsentId> {
  Optional<AuthorizationConsent> findByRegisteredClientIdAndPrincipalName(String registeredClientId, String principalName);
  void                           deleteByRegisteredClientIdAndPrincipalName(String registeredClientId, String principalName);
}
```

**Service** (`JpaOAuth2AuthorizationConsentService.java:18-82`) — Spring의 `OAuth2AuthorizationConsentService` 구현.
`authorities` 컬럼은 comma-delimited `GrantedAuthority.getAuthority()` 문자열 (`toEntity` 78 라인).

### 4.3 `Client` (Table: `` `RegisteredClient` ``, 실제 DB: `registered_client`)

`iam/client/Client.java:12-38`

```java
@Entity @Table(name = "`RegisteredClient`")
public class Client {
  @Id private String id;
  private String clientId;
  private LocalDateTime clientIdIssuedAt;
  private String clientSecret;
  private LocalDateTime clientSecretExpiresAt;
  private String clientName;
  @Column(length = 1000) private String clientAuthenticationMethods;
  @Column(length = 1000) private String authorizationGrantTypes;
  @Column(length = 1000) private String redirectUris;
  @Column(length = 1000) private String scopes;
  @Column(length = 2000) private String clientSettings;
  @Column(length = 2000) private String tokenSettings;
  @Column(length = 1000, name="post_logout_redirect_uris") private String postLogoutRedirectUris;
}
```

- `post_logout_redirect_uris` 만 컬럼명 수동 지정(네이밍 전략이 이미 스네이크 케이스로 바꿨지만 하위 호환을 명시).
- clientSettings, tokenSettings 는 JSON 문자열.

**Repository** (`ClientRepository.java:9-11`)
```java
public interface ClientRepository extends JpaRepository<Client, String> {
  Optional<Client> findByClientId(String clientId);
}
```

**Service** (`JpaRegisteredClientRepository.java:25-164`) — Spring의 `RegisteredClientRepository` 구현.
- `clientAuthenticationMethods`, `authorizationGrantTypes`, `redirectUris`, `postLogoutRedirectUris`, `scopes` 모두 comma-delimited 직렬화.
- `clientSettings` / `tokenSettings` 는 Jackson JSON (역시 `SecurityJackson2Modules` + `OAuth2AuthorizationServerJackson2Module` 등록).
- `resolveClientAuthenticationMethod` / `resolveAuthorizationGrantType` 로 커스텀 타입 지원.

### 4.4 `persistent_logins` — Spring Security Remember-Me (JDBC)

- 엔티티 파일 없음. `RememberMeConfig.java:40-46` 에서 `JdbcTokenRepositoryImpl` 를 `iamDataSource` 에 바인딩 → Spring 표준 `persistent_logins(username, series, token, last_used)` 테이블 자동 사용.
- `WadizPersistentTokenBasedRememberMeServices` 가 이 JDBC 저장소를 감싸고, Redis 에 추가 캐싱(아래 5.4 참조).
- `SchedulingService.cleanUpDroppedUserData` (`application/authentication/SchedulingService.java:185`~) 가 **wadiz_db.UserDropOutLog × wadiz_iam.persistent_logins** JOIN으로 탈퇴 회원 토큰을 소거.

---

## 5. Redis 사용 패턴

### 5.1 Redis Cluster 연결

- Lettuce Cluster. `application-dev.yml:79-89` 에 9노드(192.168.1.240~242 × 6001~6003).
- `RedisConnectionFactoryBeanPostProcessor` (`config/RedisConnectionFactoryBeanPostProcessor.java:17-45`) 가 `LettuceConnectionFactory` 를 `LettuceClusterKeyspaceMessageListenableConnectionFactory` 로 래핑 — 클러스터 키스페이스 이벤트 구독 가능하게.
- 추가로 `rememberMeRedisTemplate` 빈 (`...:38-44`) — String Key + `GenericJackson2JsonRedisSerializer` Value.

### 5.2 Spring Session (서버측 HttpSession 저장소)

- `application.yml:239-246`
  ```yaml
  spring.session:
    store-type: redis
    redis:
      namespace: account      # 프로파일별 prefix: "account", "stage-account", ...
      repository-type: indexed
      configure-action: none
      cleanup-cron: '-'
  ```
- 키 포맷 (`SessionCleanerService.java:38-45`에서 직접 조합):
  - `account:sessions:{sessionId}` — 세션 본체 해시.
  - `account:index:PRINCIPAL_NAME_INDEX_NAME:{principalName}` — principal→sessionId 인덱스 셋.
- `SessionCleanerService` 가 `UserLoggedEvent` 리스너에서 만료 sessionId 를 인덱스에서 제거(async).
- `cleanup-cron: '-'` → Spring 기본 세션 청소 cron 비활성. 자체 이벤트 기반 청소.

### 5.3 Email 인증 코드 (TTL 300초)

`redis/emailvalidationcode/EmailValidationCodeEntity.java:12-20`

```java
@RedisHash(value = "account:email:validation:code", timeToLive = 300)
public class EmailValidationCodeEntity {
  @Id private String id;     // sessionId 기반 (mapper)
  private String email;
  private String code;
}
```

- Key: `account:email:validation:code:{id}` (Spring Data Redis `@RedisHash` 규약).
- TTL: 300s = 5분.
- Repository: `EmailValidationCodeRepository extends CrudRepository<EmailValidationCodeEntity, String>` (`EmailValidationCodeRepository.java`).
- Port adapter `RedisEmailValidationRepository` (`RedisEmailValidationRepository.java:14-30`) — `mapper` 로 도메인 `EmailValidationCode` ↔ entity 변환 (mapper.id ↔ domain.sessionId, `EmailValidationCodeEntityMapper.java:9-14`).

### 5.4 Password Reset Token (TTL 1800초 = 30분)

`redis/passwordreset/PasswordResetTokenEntity.java:13-19`

```java
@RedisHash(value = "account:user:password:reset:token", timeToLive = 1800)
public class PasswordResetTokenEntity {
  @Id private String tokenHash;
  private Long      userId;
}
```

- Key: `account:user:password:reset:token:{tokenHash}`.
- Repository `PasswordResetTokenEntityRepository extends CrudRepository<_, String>` (`PasswordResetTokenEntityRepository.java`).
- Adapter `RedisPasswordResetTokenRepository` (`RedisPasswordResetTokenRepository.java:13-32`) — `save / findByTokenHash / deleteByTokenHash` 만.

### 5.5 Remember-Me 쿠키 캐시 (TTL 15초)

- `WadizPersistentTokenBasedRememberMeServices` 가 `rememberMeRedisTemplate` 를 이용해 쿠키 시리즈/토큰 조합을 Redis에 스핀락 캐시함 (`application/authentication/WadizPersistentTokenBasedRememberMeServices.java`):
  - Key 포맷: `cookieTokens[0] + "_" + cookieTokens[1]` (series_token). 이 키에 username 값을 저장.
  - 상수: `CHECK_TOKEN_DEFAULT_VALUE="LOCK"`, `CHECK_TOKEN_LOCK_TTL_SEC=15`, `CHECK_TOKEN_LOCK_SPIN_MILLIS=5000`.
- 목적: 동일 쿠키로 동시 요청이 들어올 때 DB 토큰 rotation 경합을 억제.
- 쿠키 이름: `WRMAT` (`application/RememberMeConfig.java:21`).

### 5.6 HttpSession 기반 소셜 임시 저장 (Redis 백업)

`redis/HttpSessionSocialAccountRepository.java:10-45`

```java
@Component
public class HttpSessionSocialAccountRepository implements SocialAccountRepositoryPort {
  private static final String DEFAULT_SOCIAL_USER_ATTR_NAME =
      HttpSessionSocialAccountRepository.class.getName() + ".SOCIAL_USER";
  private final String sessionAttributeName = DEFAULT_SOCIAL_USER_ATTR_NAME;

  @Override public SocialAccount loadSocialAccount() {
    RequestAttributes requestAttributes = RequestContextHolder.currentRequestAttributes();
    Object attribute = requestAttributes.getAttribute(sessionAttributeName, RequestAttributes.SCOPE_SESSION);
    if (attribute != null) return (SocialAccount) attribute;
    return null;
  }
  @Override public void saveSocialAccount(SocialAccount socialUser) { ... setAttribute ... }
  @Override public SocialAccount removeSocialUser()                 { ... removeAttribute ... }
}
```

- `SCOPE_SESSION` 속성 → Spring Session(Redis) 에 자동 지속.
- 패키지가 `persistence/redis` 아래에 있어 분류상 Redis 어댑터지만, **직접 Redis API 를 쓰지 않고 HttpSession API 만 사용** — 실제 저장은 Spring Session-Redis에 위임.
- 용도: 소셜 최초 콜백 직후, 가입 완료 전의 임시 SocialAccount (닉네임, gender 등) 세션 보관.

### 5.7 Redis 키 네임스페이스 요약

| Key 패턴 | 저장 주체 | TTL | 직렬화 |
|---|---|---|---|
| `account:sessions:{sid}` | Spring Session (Redis indexed) | `server.servlet.session.timeout: 1440m` (1일) | Spring Session 기본 (JdkSerializationRedisSerializer) |
| `account:index:PRINCIPAL_NAME_INDEX_NAME:{principal}` | Spring Session index | 자동 만료 | Set of sessionIds |
| `account:email:validation:code:{id}` | `EmailValidationCodeEntity` | 300s | `@RedisHash` 해시 (필드별 저장) |
| `account:user:password:reset:token:{tokenHash}` | `PasswordResetTokenEntity` | 1800s | `@RedisHash` 해시 |
| `{series}_{token}` | Remember-Me 캐시 | 15s (LOCK) | `GenericJackson2JsonRedisSerializer` (rememberMeRedisTemplate) |

---

## 6. 공통 어댑터 / Mapper / 트랜잭션 경계

### 6.1 `common/BooleanToYNConverter`

```java
// persistence/common/BooleanToYNConverter.java:7-17
@Converter
public class BooleanToYNConverter implements AttributeConverter<Boolean, String> {
  public String convertToDatabaseColumn(Boolean value) {
    return (value != null && value) ? "Y" : "N";
  }
  public Boolean convertToEntityAttribute(String value) {
    return "Y".equals(value);
  }
}
```

- `UserProfile.validMobileNumber`, `validEmailFirstCheck` 에서 사용.
- `@Converter` 만 선언하고 `autoApply=false` — 필드마다 `@Convert(converter=...)` 필요.

### 6.2 `wadiz/BaseEntity`

```java
// persistence/wadiz/BaseEntity.java:11-21
@MappedSuperclass @Data
public class BaseEntity {
  @UpdateTimestamp   @Column(name = "Updated")     private LocalDateTime updatedAt;
  @CreationTimestamp @Column(name = "WhenCreated", updatable = false)
                                                   private LocalDateTime createdAt;
}
```

- `UserProfile` 만 실제 상속 (그 외 엔티티들은 자체적으로 `@CreationTimestamp`/`@UpdateTimestamp` 선언).

### 6.3 MapStruct Mappers (componentModel = "spring")

| Mapper | 경로 | 역할 |
|---|---|---|
| `UserToUserProfileMapper` | `wadiz/user/mapper/UserToUserProfileMapper.java` | Domain `User` ↔ `UserProfile`, `UserDTO` ↔ `User`, `User` → `Password` (encryptPassword 포함). `UserStatusMapper` 를 uses. |
| `UserToUserProviderMapper` | `wadiz/user/mapper/UserToUserProviderMapper.java` | `User` → `UserProvider`. 소셜 없으면 `Provider.email` 기본값. |
| `UserToUserLocaleHistoryMapper` | `wadiz/user/mapper/UserToUserLocaleHistoryMapper.java` | `User` → `UserLocaleHistory` (source = `"WEB_SIGNUP"` 상수). |
| `UserStatusMapper` | `wadiz/user/mapper/UserStatusMapper.java` | `"NM"/"IA"/"DO"` ↔ `User.Status` enum 수동 매핑. |
| `SocialAccountToSocialUserMapper` | `wadiz/user/mapper/SocialAccountToSocialUserMapper.java` | `SocialAccount` ↔ `SocialUser`. `SocialAccountFactory` 로 Provider 별 도메인 객체 생성. |
| `ProviderProfileMapper` | `wadiz/socialuser/mapper/ProviderProfileMapper.java` | `SocialAccountWithAdditionalInfo` → `ProviderProfile`. |
| `ProviderProfileLogMapper` | `wadiz/socialuser/mapper/ProviderProfileLogMapper.java` | `SocialAccountWithAdditionalInfo` → `ProviderProfileLog`. |
| `UserRecordMapper` | `wadiz/userrecording/UserRecordMapper.java` | `UserDataChangeRecord` → `UserRecordingEntity` (List 지원). |
| `EmailValidationCodeEntityMapper` | `redis/emailvalidationcode/EmailValidationCodeEntityMapper.java` | Redis entity ↔ 도메인 (id ↔ sessionId). |

### 6.4 암호 유틸 (util 패키지 — 암호화 로직 자체는 범위 외)

`wadiz/user/util/` 에 `WadizPassWordUtils`, `Rfc2898DeriveBytes`, `WadizCryptoUtil`, `WadizMobileNumberRuleUtil`, `PhoneNumberInfo`, `ValidationUtils`.
`encryptPassword` (`UserToUserProfileMapper.java:81-84`) 가 `WadizPassWordUtils.encode(...)` 를 호출. 내부 구현(Rfc2898 PBKDF2)은 별도 분석 대상.

### 6.5 트랜잭션 경계 관찰

- `WadizDbJpaConfig` / `IamDbJpaConfig` 각각 `@EnableTransactionManagement`.
- 두 TransactionManager (`wadizTransactionManager`, `iamTransactionManager`, `iam` 이 `@Primary`). **분산 2PC 없음** — 두 DB를 한 트랜잭션으로 묶는 코드 경로는 관측되지 않음.
- `@Transactional` 위치:
  - 대부분의 JPA 인터페이스: `jakarta.transaction.Transactional` (interface 레벨) — propagation 관찰 안 함.
  - `AuthorizationRepository` 의 `@Modifying` 쿼리들은 `org.springframework.transaction.annotation.Transactional` 을 메서드에 개별 지정.
- `JpaUserRepository` 는 클래스 자체에 `@Transactional` 없음. 내부에서 호출되는 각 repository 의 트랜잭션 어노테이션이 개별로 적용됨 → 단일 `create(User)` 호출은 **복수의 독립 트랜잭션**으로 쪼개질 가능성 (동일 `wadizTransactionManager` 내 동일 연결 재사용 여부는 Hikari/propagation 기본에 맡김).
- 주의: `OAuth2AuthorizationService.save` (`JpaOAuth2AuthorizationService.save`) 자체는 `@Transactional` 미지정. 기본 AUTO_COMMIT 으로 동작 → JPA save 의 flush 시점에 쓰기.

### 6.6 Auditing

- JPA Auditing 어노테이션(`@EntityListeners(AuditingEntityListener)`, `@CreatedDate` 등) 사용 **없음** (`SocialUser` 에는 주석 처리된 리스너 라인이 있을 뿐).
- 대신 Hibernate의 `@CreationTimestamp`, `@UpdateTimestamp` 를 엔티티 별 개별 지정.
- 변경 이력은 `UserRecordingEntity`, `ProviderProfileLog`, `MarketingAgreementHistory`, `UserDropOutLog`, `MarketingParticipationHistory` 등 **전용 이력 테이블** 로 기록.

---

## 7. 경계 및 미탐색 영역

### 7.1 본 문서의 경계

- `persistence/` 하위 순수 어댑터/Entity/Repository 만 대상. 도메인 객체(`domain/`), 포트 (`port/outbound/`), 서비스 오케스트레이션(`application/`) 은 범위 외 — 다만 문맥 보조로 일부 참조.
- 테스트 (`src/test/groovy/...`) 는 포함하지 않음.
- Jasypt 암호화 비밀번호(`application-dev.yml:19` `ENC(...)`) 복호 메커니즘은 `PropertyEncryptionConfig` 참조(범위 외).

### 7.2 관측되지 않은 / 불명확한 것

- `LoginHistory` (`LoginHis` 테이블) 엔티티는 정의되었지만 Repository 에 파생 메서드 없음. `loginHistoryRepository` 주입처 grep 결과 없음 → 실제 쓰기 경로는 확인되지 않음 (다른 서비스에서 write할 가능성).
- `PhotoEntity`, `MarketingAgreement*`, `MarketingParticipationHistoryEntity`, `RecommendJoinEventEntity` 역시 Repository 는 단순 CRUD; 쓰기 주체 서비스는 범위 외.
- 스키마 파일 (`schema/mysql_ddl.sql`) 은 IAM 3개 테이블만 포함. `wadiz_db` 테이블의 DDL은 별도 repo / migration 도구에 있을 것으로 추정 (본 repo 안 미확인).
- `co.wadiz.fep` 나 `com.wadiz.wave.user` 가 같은 `wadiz_db` 를 읽는지(공유 DB) 여부는 이 repo 정보만으론 불명.
- 스케줄링 삭제 쿼리의 실행 cron: `application.yml:212` `deletion.cron.expression: "${random.int[1,59]} ${random.int[1,58]} ${random.int[1,6]} * * *"` — 무작위 분/초로 샤드별 차등 실행(추정).

### 7.3 레거시/이행 흔적

- 테이블 네이밍이 섞여 있음:
  - MS-SQL ASP.NET Membership 잔재: `webpages_Membership`, `webpages_OAuthMembership`.
  - Wadiz 레거시 CamelCase: `UserProfile`, `LoginHis`, `PhotoCommon`, `UserDropOutLog`, `UserToken`.
  - `Tb*` 접두사: `TbUserTokenStandby`, `TbUserProviderInfo`, `TbProviderProfile`, `TbProviderProfileLog`, `TbProviderScopes`, `TbRecommendJoinEvent`, `TbUserRecordingInfo`.
  - snake_case (외부 카탈로그): `wadiz_maker.maker_info`, `wadiz_user_stat.user_locale_history`.
  - IAM 쪽은 Hibernate 네이밍 전략으로 snake_case (Authorization/AuthorizationConsent/RegisteredClient 백틱 대소문자 ↔ 실제 `authorization`, `authorization_consent`, `registered_client`).
- `UserProfile` 이 1) `BaseEntity` 상속(`Updated/WhenCreated`) + 2) 엔티티 내부 `WhenLastLogon` 필드를 모두 가짐 → 역사적 중첩.
- `UserTokenEntity.fromUserId(...)` 가 `tokenValue("123456")` 고정값을 쓰며 주석: `// value is not used any more` — 토큰 값 필드는 더 이상 쓰지 않지만 컬럼은 유지.
- 네이티브 크로스-DB 쿼리(`wadiz_db.UserDropOutLog × wadiz_iam.persistent_logins`)는 두 DB가 **같은 인스턴스** 이기 때문에 가능. 장기적으로 분리 시 깨질 수 있음.
