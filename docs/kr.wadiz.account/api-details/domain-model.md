# kr.wadiz.account — Domain Model (DDD Aggregates)

> Core domain layer of the OAuth2 Authorization Server + Account service.
> Hexagonal (Ports & Adapters) + light DDD. Aggregates live under
> `src/main/java/kr/wadiz/oauth2/domain/`, ports under `.../oauth2/port/`.

---

## 1. 기록 범위 (Recording Scope)

**입력**
- `src/main/java/kr/wadiz/oauth2/domain/**` — 전체 서브패키지 (user, terms, email, authenticationcode, event, service, applicationservice, userrecording, exception, test) + `AgreementToTermsConverter.java` (도메인 루트).
- `src/main/java/kr/wadiz/oauth2/port/inbound/**` — 11개 UseCase/Command 파일.
- `src/main/java/kr/wadiz/oauth2/port/outbound/**` — 20개 Port 인터페이스 + `DomainCode` enum.
- 보조: `oauth2/common/{Provider, JoinAuth, AccountType, DeviceType, EmailValidationCode, SignUpInformation}` — 도메인에서 참조되는 공통 enum/VO.
- 확인용 참조: `oauth2/adapters/outbound/externalservice/terms/TermsAdapter.java` (TermsPort 구현체), `oauth2/application/authentication/*AuthenticationSuccessHandler.java` (UserLoggedEvent publish 지점), `oauth2/application/authentication/SessionCleanerService.java` (UserLoggedEvent 구독자).

**제외**
- adapters 계층 세부(JPA/MyBatis/Redis/외부 HTTP 클라이언트 등) — 별도 문서 필요.
- `application/authentication/**` (Spring Security filter/handler chain) — 이 문서는 "도메인/유스케이스" 경계까지만 서술.
- `common/` 전반, `adapters/inbound/controller/**` — 컨트롤러 계층 및 DTO 매핑 세부.
- `src/main/kotlin/kr/wadiz/oauth2/common/**` 내용물 — 현재 존재 확인만 (목록 확인용).

**분석 대상 버전**
- `build.gradle` 기준 Spring Boot 3.x / Kotlin + Java 17 혼합 (CLAUDE.md 요약 근거).
- 파일 라인 주소는 현 워킹 트리 스냅샷 기준.

**관측 원칙**
- 관측 가능한 필드·메서드·invariant만 기술. 주관적 해석/TODO 추론은 원문 인용 범위에서만.
- `path:line` 인용을 기본 단위로 사용 (예: `User.java:126`).

---

## 2. 개요 (Overview)

`kr.wadiz.account` 는 Wadiz 전사 **OAuth2 Authorization Server** + **계정(Account)** 서비스를 Hexagonal + 경량 DDD 스타일로 재작성 중인 리라이트(legacy `com.wadiz.wave.user` 후속). 도메인 계층은 두 축으로 나뉜다.

- **Aggregates / Value Objects** — `domain/user`, `domain/terms`, `domain/userrecording` (+ `email`, `authenticationcode` 는 Aggregate라기보다 도메인 서비스가 소유한 리소스).
- **Application Service (UseCase)** — `domain/applicationservice/*ApplicationService` 가 inbound port (`port/inbound/*Usecase`) 를 구현하면서 트랜잭션 경계를 가짐. 도메인 이벤트를 Spring `ApplicationEventPublisher` 로 발행.

구성 요약:

```
oauth2/
├── domain/
│   ├── user/                     ← User Aggregate (+ SocialAccount 하위타입)
│   ├── terms/                    ← Terms VO + TermsPort(inbound-ish)
│   ├── email/                    ← EmailService + FastEmail/NormalEmail VO
│   ├── authenticationcode/       ← 인증코드 생성 도메인 서비스
│   ├── event/                    ← UserCreatedEvent, UserLoggedEvent, DomainEvent
│   ├── service/                  ← @Deprecated ServiceType/ServiceTypeManager
│   ├── applicationservice/       ← UseCase 구현 (트랜잭션 경계)
│   │   └── dto/                  ← Command / AgreedTerms / WithAgreedTerms
│   ├── userrecording/            ← UserDataChangeRecord + 기록 서비스
│   ├── exception/                ← 도메인 예외 (WadizException 상속)
│   ├── test/                     ← 테스트용 스텁(Person/Car/Mammal, MapStruct 실험)
│   └── AgreementToTermsConverter.java
└── port/
    ├── inbound/                  ← UseCase + Command 자료구조
    └── outbound/                 ← 외부 시스템/영속 계층 port 인터페이스
```

명시적 "Aggregate Root" 애노테이션은 없다. 경계는 코드 구조와 접근 경로(`User → SocialAccount*`, `User → List<Terms>`, `User → List<UserDataChangeRecord>`)로만 식별된다.

---

## 3. Aggregate 별 상세

### 3.1 User Aggregate

**루트 클래스**: `domain/user/User.java` (375 lines). `@Data @NoArgsConstructor @AllArgsConstructor @Builder @Slf4j` + `Serializable` (serialVersionUID 고정) — `User.java:27-33`.

클래스 주석(`User.java:21-26`) 의 의도:

```
/**
 * Core Domain Class
 * Don't Use Any Library except standard java library
 * ...
 */
```

→ 그러나 실제로는 `lombok`, `org.apache.commons.lang3.StringUtils`, `com.fasterxml.jackson.annotation.JsonIgnore`, 그리고 **어댑터 패키지** `adapters.outbound.persistence.wadiz.user.util.PhoneNumberInfo` 를 import (`User.java:4`) — 선언적 의도와 실제가 어긋난 지점. 도메인이 adapter로 역방향 의존한다는 구조적 냄새가 있음.

#### 3.1.1 필드 (User.java:44-114)

| 필드 | 타입 | 의미 (주석 원문) | 파일:line |
|---|---|---|---|
| `userId` | `Long` | "DB저장 시 생성되는 id(primary key)" | `User.java:45` |
| `password` | `String` | "암호" | `User.java:50` |
| `username` | `String` | "사용자의 아이디 개념 / email을 사용해야 하며 변경될 수 있다" | `User.java:56` |
| `nickname` | `String` | "Wadiz에서 사용하는 이름" | `User.java:61` |
| `callingCode` | `Integer` | "전화번호 국가코드" | `User.java:66` |
| `mobilePhoneNumber` | `String` | "휴대폰 번호" | `User.java:71` |
| `accountType` | `AccountType` | "N1000은 가상계좌가 없음이며 처음 회원가입시 부여되는 타입" | `User.java:76` |
| `joinAuth` | `JoinAuth` | "회원가입 시 인증한 방법" | `User.java:81` |
| `status` | `Status` | "사용자의 상태(Normal, InActive, DropOut)" | `User.java:86` |
| `country` | `String` | "사용자가 선택한 국가" | `User.java:91` |
| `language` | `String` | "사용자가 선택한 언어" | `User.java:96` |
| `agreedTerms` | `List<Terms>` | "Agreed Terms" (`@Builder.Default = new ArrayList<>()`) | `User.java:101-102` |
| `linkedSocials` | `List<SocialAccount>` | "Social Account로 사용자 생성 / Linked SocialAccount: kakao, naver, google, facebook, apple" | `User.java:108` |
| `changeRecords` | `List<UserDataChangeRecord>` | "관리되는 사용자 data의 변경 기록 data" | `User.java:114` |

주: `provider` 필드는 주석 처리됨 (`User.java:40`). `linkedSocials` 로 대체 — 단일 → 다중 연결을 가정하는 모델.

#### 3.1.2 상태(Status) — `User.java:352-364`

```java
@Getter
public enum Status {
  Normal("NM", "활성회원"),
  InActive("IA", "휴면회원"),
  DropOut("DO", "탈퇴회원");
  private String value;
  private String description;
}
```

**invariant / 상태 전이**:
- **생성 시 status는 항상 `Normal`** — `User.createUserWithEmail(...)` (`User.java:165`), `User.createUserWithSocialAccount(...)` (`User.java:136`) 양쪽 모두 `.status(Status.Normal)` 지정. InActive/DropOut 으로 가는 도메인 메서드는 본 패키지 내에 존재하지 않음(관측 범위 밖 — 아마 레거시 `com.wadiz.wave.user` 또는 어드민이 담당).
- 활성 여부 판단: `isActive()` → `this.status == Status.Normal` (`User.java:269-271`).
- **탈퇴 이력 체크**는 도메인 내부가 아닌 repository port: `UserRepositoryPort.hasDropoutHistory(username)` — "check whether user has dropped out within 90 days" (`UserRepositoryPort.java:93-98`). → 90 일 재가입 제한 invariant는 repository(DB 쿼리) 에 위임.

#### 3.1.3 생성 규칙 (Factory methods)

**이메일 가입** — `User.java:160-173`:
```java
public static User createUserWithEmail(String email, String nickname, String password, DeviceType deviceType, Locale locale) {
  User user = User.builder()
          .accountType(AccountType.N1000)
          .username(email)
          .nickname(nickname)
          .status(Status.Normal)
          .password(password)
          .joinAuth(JoinAuth.EMAIL_AUTH)
          .country(getCountry(locale))
          .language(getLanguage(locale))
          .build();
  user.addDeviceTypeRecord(deviceType);
  return user;
}
```

**소셜 가입** — `User.java:126-148`:
```java
public static User createUserWithSocialAccount(
        String email, String nickname, SocialAccount socialAccount,
        DeviceType deviceType, Locale locale) {
  User user = User.builder()
          .accountType(AccountType.N1000)
          .username(email)
          .nickname(nickname)
          .status(Status.Normal)
          .language(getLanguage(locale))
          .country(getCountry(locale))
          .joinAuth(JoinAuth.SNS_AUTH)
          .linkedSocials(Arrays.asList(socialAccount))
          .build();
  if (socialAccount.hasPhoneNumber()) {
    user.setMobilePhoneNumber(socialAccount.getPhoneNumber());
  }
  user.addDeviceTypeRecord(deviceType);
  return user;
}
```

**관측된 불변식(invariant)**:
- 이메일 가입: `password != null`, `joinAuth == EMAIL_AUTH`, `linkedSocials == null` (builder default).
- 소셜 가입: `password == null`, `joinAuth == SNS_AUTH`, `linkedSocials = [socialAccount]` (정확히 1개).
- 공통: `accountType == N1000`, `status == Normal`, `country/language = locale 기반`, 생성 시점의 `DeviceType` 은 `changeRecords` 에 "DEVICE_TYPE_NM" 레코드로 남음 (`User.java:315-317` → `UserDataChangeRecord.changeDeviceType`).

#### 3.1.4 주요 동작(Methods)

| 메서드 | 규칙 / 부수효과 | 파일:line |
|---|---|---|
| `hasMobilePhoneNumber()` | `mobilePhoneNumber != null && trim().length() > 0` | `User.java:191-193` |
| `getEmail()` | `return this.username;` — username ≡ email alias | `User.java:195-197` |
| `getServiceWithMarketingAgreement()` | `agreedTerms` 에서 `termsType == marketing` 만 필터 → `ServiceCode` 리스트 | `User.java:200-205` |
| `hasPassword()` | `!StringUtils.isEmpty(password)` | `User.java:207-209` |
| `isLinkedToSocial()` | `linkedSocials != null && size() > 0` | `User.java:211-213` |
| `getKakaoAccount()` | `linkedSocials` 에서 `isKakao()` 첫 매칭 → `Optional<KakaoAccount>` (cast) | `User.java:220-225` |
| `getLineAccount()` | 위와 동일, `LineAccount` | `User.java:232-237` |
| `addSocialAccount(SocialAccount)` | `linkedSocials == null` 이면 새 `ArrayList`, 그 뒤 add | `User.java:244-249` |
| `isLinkedToProvider(Provider)` | `linkedSocials.anyMatch(a -> a.provider == provider)` — **null 방어 없음** | `User.java:258-261` |
| `getProviders()` | `linkedSocials.map(provider)` — **null 방어 없음** | `User.java:263-267` |
| `isActive()` | `status == Status.Normal` | `User.java:269-271` |
| `getFirstSocialAccount()` | null/empty → `Optional.empty`; 그 외 `linkedSocials.get(0)` | `User.java:279-287` |
| `setMobilePhoneNumber(String)` | 변경 시 `PhoneNumberInfo.create` 로 검증·포맷 → 유효하면 `callingCode` + 표준 포맷 저장 + `UserDataChangeRecord.changeMobileNumber` 추가 | `User.java:295-307` |
| `addDeviceTypeRecord(DeviceType)` | `changeRecords` 에 device 변경 기록 추가 | `User.java:314-317` |
| `setAccessToken(String)` | `getFirstSocialAccount().orElseThrow(...).setAccessToken(...)` — 실제 저장은 TokenStorable 구현체(Kakao/Line)에서만 (`User.java:322-326`) |
| `setRefreshToken(String)` | 위와 동일 | `User.java:328-332` |
| `getChangeRecords()` | null 방어 하에 리스트 반환 | `User.java:334-339` |
| `getLocale()` | `new Locale(language, country)` (`@JsonIgnore`) | `User.java:346-349` |
| `isKakaoUser()` | `firstSocialAccount instanceof KakaoAccount` | `User.java:366-370` |
| `toString()` | `"userId: " + userId` 만 — 민감정보 누락 방어 | `User.java:372-374` |

#### 3.1.5 SocialAccount 계층 (domain/user)

추상화 도식:
```
SocialAccount (Provider provider, providerUserId, accessToken, refreshToken, email, name, originalData)
 ├── AppleAccount                (Provider.apple)
 ├── GoogleAccount               (Provider.google) + pictureUrl
 ├── FacebookAccount             (Provider.facebook, via SocialAccountWithAdditionalInfo)
 ├── SocialAccountWithAdditionalInfo (abstract-ish) implements WithAdditionalInfo
 │    + gender, birthday, birthyear, friendscount, phoneNumber
 │    ├── KakaoAccount           (Provider.kakao) implements TokenStorable
 │    │    + agreeToFriendsScope, Agreement agreement
 │    ├── LineAccount            (Provider.line)  implements TokenStorable
 │    └── NaverAccount           (Provider.naver)
```

**SocialAccount** (`SocialAccount.java`):
- 필드 가시성: `protected provider`, `private providerUserId`, `protected accessToken/refreshToken`, `private email/name/originalData` (`:16-25`).
- `isKakao()` / `isLine()` — provider 상수 비교 (`:31-37`).
- `hasPhoneNumber()` → **false by default** (`:39-41`). Kakao/Naver/Line 등 추가 정보 계열은 `SocialAccountWithAdditionalInfo.hasPhoneNumber()` 에서 `StringUtils.isBlank(phoneNumber)` 로 override (`SocialAccountWithAdditionalInfo.java:29-31`).
- `setAccessToken/setRefreshToken` — **기본 구현이 비어있다** (`:62-73`). 주석: "Don't save access token". → 토큰 저장은 `TokenStorable` 명시 구현(Kakao, Line)만 실제로 저장. Kakao: `KakaoAccount.java:29-41`, Line: `LineAccount.java:20-32`. ⇒ **invariant**: 토큰이 도메인 객체에 유지되는 provider 는 kakao/line 뿐.
- `clearOriginalData()` / `getOriginalData()` — "TODO remove this" 로 표기 (`:43-89`). OAuth2User 를 담는 임시 용도로 관측됨(`CreateUserWithSocialAccountApplicationService.login()` — `:134-138`).

**WithAdditionalInfo** — marker interface (`WithAdditionalInfo.java:1-7`).
**TokenStorable** — `void setAccessToken(String)`, `void setRefreshToken(String)` (`TokenStorable.java:1-15`).

**SocialAccountFactory** — `createSocialAccount(Provider)` switch expression, Provider → 해당 구현체 (`SocialAccountFactory.java:6-16`). 허용된 값: kakao, naver, apple, facebook, google, line. 그 외 Provider(wadiz/email/rememberme/user) 는 `RuntimeException("Unreachable Code")`. → Provider 중 SocialAccount 로 취급되는 것은 6종만.

#### 3.1.6 PasswordResetToken (동반 엔티티)

`PasswordResetToken.java:1-13`:
```java
@Getter @Setter @AllArgsConstructor
public class PasswordResetToken {
  private String tokenHash;
  private Long userId;
}
```

User 와는 `userId` 참조로만 연결되는 분리된 엔티티. 저장소는 `PasswordResetTokenRespositoryPort` (outbound). 운용 규칙은 `PasswordService` 에서 관측됨 (§5).

---

### 3.2 Terms Aggregate / Value Object

경계가 얇다. Aggregate 라기보다 **Value Object + 외부 API 호출**.

#### 3.2.1 구성 파일

- `domain/terms/Terms.java:1-15` — `@Data @NoArgsConstructor @AllArgsConstructor @Builder` + 필드 2개:
  ```java
  private ServiceCode serviceCode;
  private TermsType termsType;
  ```
  → 순수 VO. 식별자 없음.

- `domain/terms/ServiceCode.java:9-27` — enum 3종:
  | code | description | notificationApiName |
  |---|---|---|
  | `funding` | 펀딩﹒회원 | `FUNDING` |
  | `equity` | 투자 | `INVEST` |
  | `startup` | 스타트업 찾기 | `STARTUP` |

- `domain/terms/TermsType.java:9-40` — enum 11종: membership, use, privacy, electronic_finance_transaction, funding_offer, virtual_deposit_account, marketing, maker_use, maker_privacy, maker_3rd_offer, user_age_check. 각각 displayName + code.
  - `user_age_check` 는 "14세 이상(필수)" 로, **Terms API 에 보내기 전에 제거**된다 — `AgreedTerms.removeUserAgeCheck()` 참조 (§3.2.3).
  - `private boolean hasTermsType(String code)` 는 `private` 로 선언되어 외부에서 미사용(dead-ish code) — `:36-39`.

#### 3.2.2 TermsPort (domain/terms 안에 위치)

`domain/terms/TermsPort.java:1-7`:
```java
public interface TermsPort {
  void acceptTerms(Long userId, AgreedTerms terms);
}
```

특이하게 `port/outbound` 가 아닌 `domain/terms` 에 배치됨. **구현체**는 `adapters/outbound/externalservice/terms/TermsAdapter.java` — `@Component` 가 `terms.removeUserAgeCheck()` 선처리 후 `TermsClient.createTerms(userId, ...)` HTTP 호출 (`TermsAdapter.java:15-25`). 동일한 역할의 또 다른 port 로 `port/outbound/TermsApiPort.java:1-13` 가 있음: `void updateAgreement(Long userId, AgreedTerms termsRequest);` — **두 개의 API 가 공존**(관측 범위 내에서 TermsPort 만 실제 호출 경로 확인).

#### 3.2.3 AgreedTerms (DTO/VO)

`domain/applicationservice/dto/AgreedTerms.java:14-32`:
```java
@Data @NoArgsConstructor @AllArgsConstructor
public class AgreedTerms {
  private List<Terms> termsList;

  public void removeUserAgeCheck() {
    termsList.removeIf(terms -> terms.getTermsType() == TermsType.user_age_check);
  }

  public static AgreedTerms testData() { ... }
}
```

- **부수효과 invariant**: `removeUserAgeCheck()` 는 주석 "This method has side effect of removing element in the list" (`:23-24`). → Terms API 호출 직전(`TermsAdapter.acceptTerms`)에 자기 상태를 변이.
- `WithAgreedTerms` (`dto/WithAgreedTerms.java:3-5`) — `AgreedTerms getAgreedTerms();` marker 인터페이스. `EmailSignUpCommand`, `SocialSignUpCommand` 가 구현 → `AbstractCreateUserService.signUp(T extends WithAgreedTerms, ...)` 가 제네릭으로 수용.

#### 3.2.4 Terms ↔ User 관계

- `User.agreedTerms : List<Terms>` 필드 (`User.java:101-102`).
- 가입 흐름에서 `AbstractCreateUserService.saveTerms(User, AgreedTerms)` 가 외부 Terms API 저장 + in-memory User 에도 `setAgreedTerms(termsList)` 복사 (`AbstractCreateUserService.java:68-74`).
- 마케팅 동의 서비스 조회: `User.getServiceWithMarketingAgreement()` — §3.1.4 참조.

#### 3.2.5 AgreementToTermsConverter

`domain/AgreementToTermsConverter.java` (도메인 루트). `@Service` (`:12`). Kakao `Agreement` 객체(`allowed_service_terms` 태그 리스트) → `List<Terms>` 변환:

```java
public List<Terms> convert(Agreement agreement){
  return agreement.getAllowed_service_terms().stream()
    .filter(x -> !"user_age_check".equals(x.getTag()))
    .map(x -> Terms.builder()
            .serviceCode(ServiceCode.fromString(x.getTag().split("_")[0]))
            .termsType(TermsType.fromString(x.getTag().substring(x.getTag().indexOf("_")+1)))
            .build())
    .collect(Collectors.toList());
}
```
- **@precondition** 주석: "all tags should have \"_\"" (`:14-18`). 즉 태그 규칙: `{serviceCode}_{termsType}` — 예: `funding_marketing`, `equity_privacy`.
- `user_age_check` 태그는 변환 전 단계에서 제거 (AgreedTerms 단계에서도 한 번 더 제거 → 이중 방어).

---

### 3.3 Email 도메인

Aggregate 는 아니며, **도메인 서비스 1 + Kotlin VO 2** 로 구성된 얇은 바운디드 컨텍스트.

#### 3.3.1 EmailService — `domain/email/EmailService.java`

`@Service @Slf4j` — `:26-28`. 필드 및 주입:
- `@Qualifier("notificationAdapterV2") NotificationPort port` — `:78`.
- `MailTemplateProcessorPort mailTemplateProcessorPort` — `:79`.
- `@Value("${wadiz.authorization.server.address}") String accountServerUrl` → `resetPasswordUrl = accountServerUrl + "/reset-password"` — `:80, 84-85`.
- `@Value("${wadiz.api.mail.normal.template.signup-complete}") int signUpWelcomeTemplateNo` — `:81, 86`.

**내부 enum Template** (`:30-71`): 두 가지 템플릿 고정.
- `RESET_PASSWORD_TEMPLATE("accountResetPassword", MessageCode.EMAIL_FROM, MessageCode.EMAIL_PASSWORD_RESET_TITLE)`
- `AUTHORIZATION_CODE_TEMPLATE("accountSignupVerificationCode", MessageCode.EMAIL_FROM, MessageCode.EMAIL_AUTHORIZATION_CODE_TITLE)`

정적 `MessageSource` 주입 패턴을 `@Component DependencyInitializer` 로 우회 (`:42-50`) — enum 이 Spring bean 과 통신하기 위한 관용구.

**공개 메서드**:

| 메서드 | 용도 | 구현 요점 | 파일:line |
|---|---|---|---|
| `handleEvent(UserCreatedEvent)` | `@Async @EventListener` — 가입 축하 메일 | `sendSignUpCelebrationMail(email, nickname, locale)` 호출, 예외 시 로그만 | `:89-99` |
| `sendEmailAuthenticationCode(String, String, Locale)` | 회원가입 인증 코드 메일 | `FastEmail` 로 전송 (`AUTHORIZATION_CODE_TEMPLATE`), 제목 파라미터로 `code` 포함 | `:101-105` |
| `sendSignUpCelebrationMail(...)` | `@Async` 가입 축하 (NormalMail) | "2025.09.24: 반송률 제한 방어를 위해 Normal mail로 변경" 주석 (`:113`) | `:110-118` |
| `sendResetPasswordMail(String, String, Locale)` | 비밀번호 재설정 링크 메일 | `linkURL = resetPasswordUrl + "/" + URLEncoder.encode(token, UTF_8)` → `FastEmail` | `:122-128` |

**내부 전송 메서드**:
- `sendFastEmail(Template, email, locale, templateData, ...titleParams)` — `MailTemplateProcessorPort.processTemplateFile` 로 본문 랜더링 → `FastEmail.fromWadizMail(...)` → `port.sendFastMail(fastEmail)`. 실패 시 `EmailNotSentException` (`:130-142`).
- `sendNormal(locale, emailAddress, domainCode, templeteNo, templateData)` — `NormalEmail.fromWadizMail(...)` → `port.sendNormalMail(lang, normalEmail)` (`:144-152`).

#### 3.3.2 FastEmail / NormalEmail — Kotlin VO

`domain/email/FastEmail.kt`:
```kotlin
class FastEmail(val from: String, val to: String, val title: String, val body: String) {
  companion object {
    @JvmStatic fun fromWadizMail(from, emailAddress, title, body): FastEmail = ...
  }
}
```
→ `from/to/title/body` 4-field 불변 VO.

`domain/email/NormalEmail.kt`:
```kotlin
class NormalEmail(val to: String, val domainCode: String?, val templateNo: Int, val templateData: Map<String, Object>)
```
→ 템플릿 번호와 바인딩 데이터를 가진 VO. `domainCode` nullable.

**도메인 검증**: 이메일 형식 검증은 도메인 내부가 아닌 `port/inbound/*Command` 에서 Bean Validation 으로 처리 — 예: `SendCodeCommand.java:16-17` 의 `@Email @NotBlank`.

---

### 3.4 AuthenticationCode

#### 3.4.1 AuthenticationCodeService — `domain/authenticationcode/AuthenticationCodeService.java`

`@Service` (`:10`). 매우 얇다.

```java
Random random = new Random();
@Value("${wadiz.authentication.code.size}")
private int authenticationCodeSize = 6;

public String generateCode() {
  return IntStream.generate(() -> random.nextInt(10))
          .limit(authenticationCodeSize)
          .mapToObj(Integer::toString)
          .collect(Collectors.joining());
}

public void checkValidity(String authenticationCode) throws RuntimeException {
  // 본문 비어있음
}
```

**관측된 규칙**:
- 코드 길이는 `wadiz.authentication.code.size` (기본 6자리 숫자). `Random` 인스턴스 1개를 필드로 공유.
- `checkValidity(...)` 는 **비어있다** (`:29-31`). TODO 주석 "change Exception type". → 실제 일치 검사는 `EmailValidationCode.checkCode(String)` (`common/EmailValidationCode.java:21-23`) 에서 수행, 상위 `AuthenticationCodeApplicationService.isValid(sessionId, code)` 가 조합.

#### 3.4.2 EmailValidationCode (common VO로 발급·소진 연결)

`common/EmailValidationCode.java` (도메인 밖 `common` 패키지지만 도메인에서 직접 사용):
```java
@AllArgsConstructor @NoArgsConstructor @Data @Builder
public class EmailValidationCode {
  private String sessionId;
  private String email;
  private String code;
  public boolean checkCode(String code)   { return code.equals(this.code); }
  public boolean checkEmail(String email) { return this.email.equals(email); }
}
```

**발급/소진 플로우** — `AuthenticationCodeApplicationService`:
- **발급** (`:36-48`):
  1. `checkEmailAvailability(email)` — `countByUsername > 0` → `EmailAlreadyExistsException`; `hasDropoutHistory` → `DropoutHistoryExistsException`.
  2. `codeService.generateCode()` → `emailService.sendEmailAuthenticationCode(email, code, locale)`.
  3. `EmailValidationRepositoryPort.saveEmailValidation(EmailValidationCode)` 저장 (Redis — adapters/outbound 확인 범위 밖이지만 adapter 파일명으로 추정).
- **검증** (`:28-34`):
  1. `repo.loadEmailValidation(sessionId)` → 없으면 `AuthenticationCodeExpiredException`.
  2. `emailCode.checkCode(code)` 반환. → 실패 시 false, **명시적 삭제 로직은 관측되지 않음** (TTL 기반 만료에 위임).

---

### 3.5 UserRecording (User Data Change Records)

#### 3.5.1 UserDataChangeRecord — `domain/userrecording/UserDataChangeRecord.java:9-24`

```java
@AllArgsConstructor @Data
public class UserDataChangeRecord {
  private User user;
  private String type;
  private String data;

  public static UserDataChangeRecord changeMobileNumber(User user, String mobilePhoneNumber) {
    return new UserDataChangeRecord(user, CCI.USERINFO_RECORDING_TYPE_MOBILENO, mobilePhoneNumber);
  }
  public static UserDataChangeRecord changeDeviceType(User user, DeviceType deviceType) {
    return new UserDataChangeRecord(user, CCI.USERINFO_RECORDING_TYPE_DEVICE_TYPE_NM,
            Integer.toString(deviceType.getValue()));
  }
}
```

- `type` 은 `CCI.*` 상수(code/tag). 관측된 종류: `MOBILENO`, `DEVICE_TYPE_NM` 두 종.
- 생성 지점: `User.setMobilePhoneNumber(...)` (`User.java:303`), `User.addDeviceTypeRecord(...)` (`User.java:316`). → 즉 User Aggregate 내부 변경 시 자동 append.

#### 3.5.2 UserDataChangeRecordingService — `domain/userrecording/UserDataChangeRecordingService.java`

```java
@Slf4j @RequiredArgsConstructor @Service
public class UserDataChangeRecordingService {
  private final UserDataChangeRecordRepositoryPort port;

  @EventListener
  public void handleEvent(UserCreatedEvent event) {
    User user = event.getUser();
    recordUserCreationData(user);
  }

  private void recordUserCreationData(User user) {
    port.save(user.getChangeRecords());       // 데이터 변경
    port.createEmailCreationRecord(user);     // email 변경
  }
}
```

- `@EventListener` (동기) — `UserCreatedEvent` 수신 시 두 저장 호출 (`:17-33`).
- 포트 계약은 `UserDataChangeRecordRepositoryPort.java:9-15`:
  - `save(List<UserDataChangeRecord> records)`
  - `createEmailCreationRecord(User user)` — 이메일 최초 생성 기록을 별도로.

---

### 3.6 보조/Deprecated — domain/service

**전부 `@Deprecated`** (관측됨).

- `Service.java:9` — `@Deprecated @Value` VO, `name` 한 필드. `fromName(String)` 정적 생성자.
- `ServiceType.java:13` — `@Deprecated`, `name + requiredServices + paths + requiredTerms`. `isSatisfiedWith(Collection<Service>)` — 요구 서비스 모두 포함 여부.
- `ServiceTypeManager.java:8` — `@Component @Deprecated`. 생성자에서 4 개 서비스타입 등록:
  - `funding` (paths: reward, rwd)
  - `startup` (paths: wstartup) — funding+startup
  - `corporation` (paths: corporation) — funding+equity
  - `union` (paths: union) — funding+equity
- `getServiceTypeForPath(url)` — url 에 `pathKey` ∈ {reward, rwd, wstartup, corporation, union} 하나라도 포함되면 매핑된 ServiceType 반환, 아니면 `RuntimeException("unreachable code")` (`:42-49`).

→ 레거시 서비스 분류 체계. 현 가입/약관 흐름에서는 `ServiceCode` enum 이 실사용. 의존을 끊지 못한 잔존 코드.

---

### 3.7 domain/test — 테스트 지원/실험

MapStruct 실험용. 프로덕션 경로 없음.

- `Mammal.java` (빈 클래스), `Person extends Mammal` (`name`), `Car` (`make, numberOfSeats, person, language`, 오버로드된 `run(Person)/run(Mammal)`).
- `CarMapper` — `@Mapper(componentModel = "spring")`, `Car→CarDto`, `Person→PersonDto` 매핑.
- `CarDto`, `PersonDto` — `@Data` 풀필드.

→ 도메인 모델과 무관한 스캐폴드. 제거 후보.

---

## 4. Domain Service (여러 Aggregate 횡단)

"도메인 서비스" 라고 명명된 클래스가 별도로 많지는 않음. 횡단 로직은 주로 **Application Service** 에 섞여 있음. 관측되는 순수 domain-only 협력 지점:

| 파일 | 위치 | 역할 |
|---|---|---|
| `AuthenticationCodeService` | `domain/authenticationcode` | 인증 코드 문자열 생성(Aggregate 아님) |
| `EmailService` | `domain/email` | 메일 발송(포트 위임); `UserCreatedEvent` 청취 |
| `AgreementToTermsConverter` | `domain/` (루트) | Kakao `Agreement` → `List<Terms>` 변환 |
| `UserDataChangeRecordingService` | `domain/userrecording` | `UserCreatedEvent` → 변경기록 저장 |
| `ServiceTypeManager` | `domain/service` | **@Deprecated** path → ServiceType 분류 |
| `SocialAccountFactory` | `domain/user` | `Provider` → 적절한 `SocialAccount` 하위타입 인스턴스화 |

※ `EmailService` 와 `UserDataChangeRecordingService` 는 Spring `@EventListener` 를 쓰므로 엄밀히는 infrastructure 인접이지만, 도메인 패키지에 배치되어 있다.

---

## 5. Application Service (UseCase 구현)

`domain/applicationservice/` 아래에 `@Service` 로 등록. 모두 트랜잭션 경계를 갖거나 inbound port 를 구현한다.

### 5.1 AbstractCreateUserService — `applicationservice/AbstractCreateUserService.java`

공통 signUp template method. 생성자 주입:
```
UserRepositoryPort, TermsPort, CrmPort, SubscribeNotificationPort,
MarketingConsentPort, UserCouponPort, UserApiPort, ApplicationEventPublisher
```

**signUp template** (`:29-39`):
```java
public <T extends WithAgreedTerms> User signUp(T object, DeviceType deviceType, Locale locale) {
  User savedUser = createUser(object, deviceType, locale);
  savedUser = saveTerms(savedUser, object.getAgreedTerms());
  registerNotification(savedUser);
  registerUnsubscribeKeyForBraze(savedUser);
  giveAwaySignupCouponsAndNotifyCRM(savedUser, locale);
  return savedUser;
}
```

단계별:
1. **createUser (abstract)** — 서브클래스에서 `User.createUserWith*` + `userRepositoryPort.create`.
2. **saveTerms** — `termsPort.acceptTerms(userId, agreedTerms)` + `user.setAgreedTerms(termsList)` (`:68-74`).
3. **registerNotification** — `subscribeNotificationPort.registerNotification(user)` + `user.getServiceWithMarketingAgreement().forEach(sc -> platformApiPort.updateMarketingConsent(sc, userId))` (`:51-60`).
4. **registerUnsubscribeKeyForBraze** — `crmPort.setUnsubscribeKey(userId)` (`:62-66`).
5. **giveAwaySignupCouponsAndNotifyCRM** (`:76-88`) — 조건부 쿠폰 발급:
   - `isGlobal(locale)` (locale.country ≠ "KR") **또는** `isAgreedFundingMarketingTerms(user)` (funding+marketing 동의) 인 경우 `userCouponPort.giveAwaySignupCoupons(user)` 호출.
   - 그 뒤 `crmPort.sendSignUpInformationWithCoupon(user, issuedCoupon)`. 예외는 warn 로그만.
6. **updateUserTimeZone** (`:90-92`) — `userApiPort.updateUserTimeZoneByCountry(userId, country)` — 호출 위치는 서브클래스 책임.
7. **doRemainingWork (abstract)** — `@Async` 후속 작업.

### 5.2 CreateUserApplicationService — `applicationservice/CreateUserApplicationService.java`

`implements CreateUserUseCase` (inbound). 추가 의존: `ServletPort`, `UserAppContactApiPort`.

```java
@Transactional("wadizTransactionManager")
public User signUpWithEmail(EmailSignUpCommand dto, DeviceType deviceType, Locale locale) {
  User savedUser = this.signUp(dto, deviceType, locale);
  eventPublisher.publishEvent(new UserCreatedEvent(savedUser));
  servletPort.login(savedUser, dto.getPassword());
  return savedUser;
}
```
- `createUser` 구현(`:74-81`): `User.createUserWithEmail(...)` → `userRepositoryPort.create(user)` → `userAppContactApiPort.asyncReconnectContactsByMyMobileNumber(userId, mobilePhoneNumber)`.
- `doRemainingWork(User)` — **비어있음** (`@Async`, `:83-85`).

### 5.3 CreateUserWithSocialAccountApplicationService — `applicationservice/CreateUserWithSocialAccountApplicationService.java`

`implements CreateUserWithSocialAccountUsecase`. 추가 의존: `KakaoPort, AlimTalkPort, ServletPort, UserAppContactApiPort, Push2Port, MessageSource`.

```java
@Transactional("wadizTransactionManager")
public User signUpWithSocial(SocialSignUpCommand dto, DeviceType deviceType, Locale locale) {
  User savedUser = this.signUp(dto, deviceType, locale);
  eventPublisher.publishEvent(new UserCreatedEvent(savedUser));
  servletPort.loginSocialUser(savedUser);
  return savedUser;
}
```

- `createUser` (`:84-91`): `User.createUserWithSocialAccount(...)` → `userRepositoryPort.create(user)` → `userAppContactApiPort.asyncReconnectContactsByMyMobileNumber(...)`.
- `doRemainingWork(User)` (`:93-105`, `@Async`):
  - Kakao 연결 시: `sendAlarmForKakaoLink(userId, nickname)` — Push2Port 로 `DomainCode.ACCOUNT_KAKAO` 푸시 (제목/본문/인박스/타겟링크 MessageSource 에서 로드).
  - `hasMobilePhoneNumber()` 이면: `alimTalkPort.sendSignUpNotificationTo(user)`.
- `login(User)` (`:133-139`) — OAuth2AuthenticationToken 으로 `SecurityContextHolder` 세팅. 주석상 `servletPort.loginSocialUser` 로 대체됨 (미호출 private 메서드).
- `updateKakaoAccountAboutAgreement(...)` — `@Deprecated` 명시(주석) (`:107-116`), 현재 호출 없음.

### 5.4 AuthenticationCodeApplicationService — `applicationservice/AuthenticationCodeApplicationService.java`

`implements SendAuthenticationCodeViaEmailUsecase, CheckAuthenticationCodeValidityUsecase`. 두 유스케이스 동시 구현.

```java
public boolean isValid(String sessionId, String code) {
  EmailValidationCode emailCode = authenticationCodeRepository
          .loadEmailValidation(sessionId)
          .orElseThrow(AuthenticationCodeExpiredException::new);
  return emailCode.checkCode(code);
}

public void sendAuthenticationCode(String sessionId, String email, Locale locale) {
  checkEmailAvailability(email);              // 중복/탈퇴이력 검사
  String code = codeService.generateCode();
  emailService.sendEmailAuthenticationCode(email, code, locale);
  authenticationCodeRepository.saveEmailValidation(EmailValidationCode.builder()
          .sessionId(sessionId).email(email).code(code).build());
}
```

**invariant 체크 순서**: 이메일 사용 가능성(중복·탈퇴이력) → 코드 생성 → 메일 발송 → 저장.
중복이면 `EmailAlreadyExistsException`, 탈퇴 이력이면 `DropoutHistoryExistsException` (다른 패키지 `application.authentication.social.exception`).

### 5.5 GetSignUpInformationApplicationService — `applicationservice/GetSignUpInformationApplicationService.java`

`implements GetSignUpInformationUsecase, NicknameMapper` (NicknameMapper 는 adapter 매퍼 인터페이스 — `adapters/inbound/mapper/NicknameMapper`). 소셜 로그인 후 가입 화면에 내려줄 정보 구성.

```java
public SignUpInformation getSignUpInformation(Locale locale) {
  SocialAccount socialAccount = this.socialUserRepository.loadSocialAccount();
  String email = socialAccount.getEmail();
  if (StringUtils.isBlank(email)) email = null;
  return SignUpInformation.builder()
          .joinType("reward")               // TODO check this and remove
          .providerType(socialAccount.getProvider())
          .social(SignUpInformation.Social.builder()
                  .userName(email)
                  .nickName(socialAccount.getName())
                  .existUserName(checkEmailExistence(email))
                  .build())
          .fromTheLoginPage(false)          // TODO check how to do this
          .build();
}

private boolean checkEmailExistence(String email) {
  if (email == null) return false;
  return userRepositoryPort.findActiveUserByUsername(email).isPresent()
      || userRepositoryPort.hasDropoutHistory(email);
}
```

### 5.6 LinkUserToSocialUserApplicationService — `applicationservice/LinkUserToSocialUserApplicationService.java`

`implements LinkSocialUserUseCase`. 어댑터 패키지의 `SocialUserRepository` 를 직접 주입(Port 우회 — 구조적 냄새).

**link(cmd)** (`:19-35`):
- precondition:
  1. `socialUserRepository.findById(SocialUserId(provider, providerUserId))` 존재 시 → `RuntimeException("Already Linked")`.
  2. `findByUserIdAndProvider(userId, provider)` 존재 시 → `RuntimeException("Current User Already linked ... with another email")`.
- 통과 시: `userRepositoryPort.findSimpleUserByUserId(userId)` 로 User 로드 → `user.addSocialAccount(cmd.socialAccount)` → `userRepositoryPort.createSocial(user)`.

**linkWithoutCheck(cmd)** (`:38-44`) — 선행 조건 없이 동일한 저장 경로.

### 5.7 PasswordService — `applicationservice/PasswordService.kt`

Kotlin. `@Service` (`:20`). 세 개 UseCase 동시 구현:
`ResetPasswordUsecase, SendResetPasswordMailUsecase, FindIdUsecase`.

```kotlin
@Transactional("wadizTransactionManager")
override fun resetPassword(token: String, newPassword: String) {
  val hashedToken = hash(token)
  val user: User = getUserWithToken(hashedToken).orElseThrow { RuntimeException("User not found") }
  if (WadizPassWordUtils.matches(newPassword, user.password)) {
    throw SamePasswordException()
  }
  user.password = newPassword
  userRepository.updatePassword(user)
  passwordResetTokenRepository.deleteByTokenHash(hashedToken)
}
```

- **invariant**: 동일 비밀번호 변경 금지(`SamePasswordException`); 재설정 후 토큰 즉시 삭제(`deleteByTokenHash`).

```kotlin
@Transactional("wadizTransactionManager")
override fun sendResetPasswordMail(username: String, locale: Locale) {
  val user = userRepository.findUserByUsername(username).orElseThrow { EmailNotFoundException() }
  val token = genereateToken()
  passwordResetTokenRepository.save(PasswordResetToken(hash(token), user.userId))
  emailService.sendResetPasswordMail(username, token, Locale(user.language, user.country))
}
```
- 저장되는 것은 **해시**(SHA-256 Base64, `hash()` — `:49-54`). 메일엔 원본 토큰 전달. → token 자체는 DB 미저장.

```kotlin
@Transactional(readOnly = true)
override fun findUsername(userName: String): UsernameStatus {
  val optionalUser = userRepository.findUserByUsername(userName)
  return if (optionalUser.isPresent) {
    val user = optionalUser.get()
    if (user.hasPassword()) UsernameStatus(userName, Status.EMAIL_LOGIN_OK)
    else                    UsernameStatus(userName, Status.SNS_LOGIN_OK)
  } else {
    if (userRepository.hasDropoutHistory(userName)) UsernameStatus(userName, Status.DROPOUT_HISTORY_EXISTS)
    else                                           UsernameStatus(userName, Status.NOT_REGISTERED)
  }
}
```
- 4 상태: `EMAIL_LOGIN_OK, SNS_LOGIN_OK, DROPOUT_HISTORY_EXISTS, NOT_REGISTERED` — `port/inbound/FindIdUsecase.kt:9-11`.

`genereateToken()` (오타 그대로) — `WadizPassWordUtils.temporaryToken(30)` (`:81-85`).

---

## 6. Domain Event

### 6.1 기반 클래스 — `domain/event/DomainEvent.java:1-11`

```java
public class DomainEvent {
  private final LocalDateTime created;
  public DomainEvent() { this.created = LocalDateTime.now(); }
}
```
→ 생성 시각만. getter 없음(노출 안 함).

### 6.2 구체 이벤트

| 이벤트 | 페이로드 | 발행 지점 | 구독자(`@EventListener`) |
|---|---|---|---|
| `UserCreatedEvent` (`event/UserCreatedEvent.java:7-12`) | `User user` (getter) | `CreateUserApplicationService.signUpWithEmail` — `:68`<br>`CreateUserWithSocialAccountApplicationService.signUpWithSocial` — `:78` | `EmailService.handleEvent(UserCreatedEvent)` `@Async @EventListener` → 가입축하 메일 (`EmailService.java:89-99`)<br>`UserDataChangeRecordingService.handleEvent(UserCreatedEvent)` `@EventListener` → 변경기록 저장 (`UserDataChangeRecordingService.java:17-22`) |
| `UserLoggedEvent` (`event/UserLoggedEvent.java:6-12`) | `String principalName` (getter) | `EmailAuthenticationSuccessHandler` — `:27`<br>`SocialAuthenticationSuccessHandler` — `:99`<br>`RememberMeAuthenticationSuccessHandler` — `:33` | `SessionCleanerService.cleanUpExpiredSessionIdInIndexedRepository(UserLoggedEvent)` `@Async @EventListener` — `:64-66` |

전송 채널: Spring **in-process `ApplicationEventPublisher`**. 카프카/아웃박스 패턴은 도메인 계층엔 없음 (관측 범위 내).

### 6.3 관측된 이벤트 흐름 특징

- `UserCreatedEvent` 는 **트랜잭션 커밋 전**에 publish (same thread). `@Async` 리스너(EmailService)는 별도 스레드로 이탈. `UserDataChangeRecordingService.handleEvent` 는 **동기** (`@Async` 미부여) — `User.changeRecords` 에 담겨있던 레코드가 같은 트랜잭션 경계 안에서 Repository 로 flush 될 가능성이 높음 (구현체 확인 필요).
- `UserLoggedEvent` 는 인증 성공 핸들러 3 종에서 통일 발행.
- 도메인 aggregate(`User`)가 자체적으로 이벤트를 "raise" 해 두고 나중에 flush 하는 패턴은 사용되지 않음 — 모두 Application Service 에서 직접 `eventPublisher.publishEvent(...)`.

---

## 7. Port 인터페이스 카탈로그

### 7.1 Inbound (UseCase + Command)

11개 파일. UseCase 는 12 개 공개 메서드로 정리.

| 인터페이스 | 시그니처 | 구현체 | 파일:line |
|---|---|---|---|
| `CreateUserUseCase` | `User signUpWithEmail(EmailSignUpCommand, DeviceType, Locale)` | `CreateUserApplicationService` | `CreateUserUseCase.java:8-10` |
| `CreateUserWithSocialAccountUsecase` | `User signUpWithSocial(SocialSignUpCommand, DeviceType, Locale)` | `CreateUserWithSocialAccountApplicationService` | `CreateUserWithSocialAccountUsecase.java:9-11` |
| `CheckAuthenticationCodeValidityUsecase` | `boolean isValid(String sessionId, String code)` | `AuthenticationCodeApplicationService` | `CheckAuthenticationCodeValidityUsecase.java:3-5` |
| `SendAuthenticationCodeViaEmailUsecase` | `void sendAuthenticationCode(String sessionId, String email, Locale)` | 동 | `SendAuthenticationCodeViaEmailUsecase.java:5-7` |
| `GetSignUpInformationUsecase` | `SignUpInformation getSignUpInformation(Locale)` | `GetSignUpInformationApplicationService` | `GetSignUpInformationUsecase.java:7-9` |
| `LinkSocialUserUseCase` | `void link(LinkUserToSocialAccountCommand)` / `void linkWithoutCheck(...)` | `LinkUserToSocialUserApplicationService` | `LinkSocialUserUseCase.java:3-18` |
| `ResetPasswordUsecase` | `fun resetPassword(token, password)` | `PasswordService` | `ResetPasswordUsecase.kt:7-13` |
| `SendResetPasswordMailUsecase` | `fun sendResetPasswordMail(username, Locale)` | 동 | `SendResetPasswordMailUsecase.kt:5-7` |
| `FindIdUsecase` | `fun findUsername(userName): UsernameStatus` | 동 | `FindIdUsecase.kt:3-5` |

**Command 자료구조 (inbound port 의 입력 VO)**:

- `EmailSignUpCommand` — `email, nickname, password, agreedTerms` (`:14-19`). `implements WithAgreedTerms`.
- `LinkUserToSocialAccountCommand` — `UserId(Long)` (대문자 필드명 주의), `socialAccount` (`:6-11`).
- Command-like DTO 가 applicationservice/dto 밑에도 공존: `SocialSignUpCommand`, `SendCodeCommand`, `ReconnectionContactsCommand`, `UserTimeZoneUpdateByCountryRequest`, `AgreedTerms`, `WithAgreedTerms`.

### 7.2 Outbound (외부 시스템 / 영속 / 세션 / 부가)

`port/outbound/` 아래 20 파일.

**Persistence (도메인 저장소)**
| 포트 | 핵심 메서드 | 파일:line |
|---|---|---|
| `UserRepositoryPort` | `User create(User)` / `void update(User)` / `void createSocial(User)` / `findActiveUserByUsername` / `findUserByUserId` / `findSimpleUserByUserId` / `findUserDTOByUserId` / `findUserDTOByUsername` / `findUserByUsername` / `findUserWithPictureByUsername` / `countByUsername` / `findUserByProviderAndProviderUserId` / `boolean hasDropoutHistory(String)` / `findUserByProviderAndProviderUserIdAnother` / `updatePassword(User)` | `UserRepositoryPort.java:10-106` |
| `SocialAccountRepositoryPort` | `SocialAccount loadSocialAccount()` / `saveSocialAccount(SocialAccount)` / `SocialAccount removeSocialUser()` — 세션 기반 | `SocialAccountRepositoryPort.java:10-16` |
| `EmailValidationRepositoryPort` | `void saveEmailValidation(EmailValidationCode)` / `Optional<EmailValidationCode> loadEmailValidation(String sessionId)` | `EmailValidationRepositoryPort.java:7-12` |
| `PasswordResetTokenRespositoryPort` | `save(PasswordResetToken)` / `Optional<PasswordResetToken> findByTokenHash(String)` / `deleteByTokenHash(String)` | `PasswordResetTokenRespositoryPort.java:8-14` |
| `UserDataChangeRecordRepositoryPort` | `save(List<UserDataChangeRecord>)` / `createEmailCreationRecord(User)` | `UserDataChangeRecordRepositoryPort.java:8-15` |

**External services**
| 포트 | 시그니처 요약 | 파일:line |
|---|---|---|
| `NotificationPort` | `sendFastMail(FastEmail): String` / `sendNormalMail(languageCode, NormalEmail): String` | `NotificationPort.java:6-9` |
| `MailTemplateProcessorPort` | `processTemplateFile(templateName, languageCode, context)` / `processTemplateString(string, context)` | `MailTemplateProcessorPort.java:5-12` |
| `AlimTalkPort` | `sendSignUpNotificationTo(User)` | `AlimTalkPort.java:5-7` |
| `CrmPort` | `setUnsubscribeKey(Long userId)` / `sendSignUpInformationWithCoupon(User, Boolean issuedCoupon)` | `CrmPort.java:5-9` |
| `KakaoPort` | `Agreement getAgreement(String accessToken)` / `boolean isFriendsScopeAgreed(providerUserId)` / `TokenDto renewToken(refreshToken)` | `KakaoPort.java:6-10` |
| `Push2Port` | `push(userId, title, body, inboxTitle, targetLink, DomainCode, Locale)` | `Push2Port.java:5-7` |
| `SubscribeNotificationPort` | `registerNotification(User)` | `SubscribeNotificationPort.java:5-7` |
| `MarketingConsentPort` | `updateMarketingConsent(ServiceCode, Long userId)` | `MarketingConsentPort.java:5-7` |
| `TermsApiPort` | `updateAgreement(Long userId, AgreedTerms)` (※ 본 문서 범위에선 호출 경로 미관측) | `TermsApiPort.java:5-13` |
| `UserApiPort` | `updateUserTimeZoneByCountry(Long userId, String country)` | `UserApiPort.java:3-5` |
| `UserAppContactApiPort` | `asyncReconnectContactsByMyMobileNumber(Long userId, String mobileNumber)` | `UserAppContactApiPort.java:3-5` |
| `UserCouponPort` | `Boolean giveAwaySignupCoupons(User)` | `UserCouponPort.java:5-7` |
| `GetCountryFromIPPort` | `String getCountry(String ip)` — "KR" 폴백 주석 | `GetCountryFromIPPort.java:4-11` |

**Infrastructure / Adapter 브리지**
| 포트 | 시그니처 요약 | 파일:line |
|---|---|---|
| `ServletPort` | `login(User, String password)` / `login(Authentication, boolean checkRememberMe)` / `loginSocialUser(User)` | `ServletPort.java:6-13` |

**도메인 패키지에 위치한 port** (비전형)
- `domain/terms/TermsPort.java` — `void acceptTerms(Long userId, AgreedTerms)` (`:5-7`). outbound port 이지만 `domain/terms` 에 선언.

**보조 enum**
- `port/outbound/DomainCode.java` — `NEWS, FOLLOW, KEYWORD, STORE_RESTOCK, LETZ, M_RETENTION_FOLLOW, M_RETENTION_REOPEN, ACCOUNT_KAKAO` (`:3-6`). Push2Port 에서 분류로 사용.

### 7.3 구조 관찰

- **outbound port 수가 inbound 보다 훨씬 많다** (20 vs 9). Account 서비스가 많은 외부 시스템(메일/알림톡/푸시/CRM/쿠폰/마케팅동의/약관API/앱컨택트/국가IP…)과 연동하는 허브라는 특성.
- **port 명과 실제 의미가 엇갈리는 경우**:
  - `TermsPort` (domain) vs `TermsApiPort` (outbound) 중복 — 하나는 HTTP adapter 로 이미 구현됨, 다른 하나는 관측 범위 내 호출처 없음.
  - `SocialAccountRepositoryPort` — 이름과 다르게 세션 저장소(주석: "In our case save in session" — `:7`).
  - `PasswordResetTokenRespositoryPort` — typo ("Respository").

---

## 8. 경계 및 미탐색 영역

### 8.1 확인된 경계 침범/스멜

- `domain/user/User.java:4` — `import adapters.outbound.persistence.wadiz.user.util.PhoneNumberInfo;` 도메인 → adapter 역방향 의존. "Don't Use Any Library except standard java library" 주석(`:23`)과 충돌.
- `CreateUserWithSocialAccountApplicationService.login(...)` 는 `OAuth2User, OAuth2AuthenticationToken, SecurityContextHolder` 를 직접 참조(`:133-138`). 도메인/application service 가 Spring Security 에 결합 — `ServletPort` 로 이미 추상화가 있는데 중복.
- `LinkUserToSocialUserApplicationService` 가 `port/outbound` 가 아닌 `adapters/outbound/persistence/wadiz/socialuser/SocialUserRepository` 를 직접 주입(`:3-4`, `:15-16`) — 포트 우회.
- `domain/terms/TermsPort` 가 `domain` 에 위치 — Hexagonal 규약과 배치 혼선.
- `domain/service/*` 전체 `@Deprecated`: 레거시 ServiceType 체계가 제거되지 못하고 남음.
- `AuthenticationCodeService.checkValidity(...)` 빈 구현 (`:29-31`) — 실질 검증은 Application Service 에서 수행.
- `EmailService.Template` 이 enum 에 Spring `MessageSource` 를 static 주입 (`:42-50`) — 테스트/교체 난이도 상승.
- `SocialAccount.setAccessToken/setRefreshToken` 기본 no-op (`:62-73`) + `TokenStorable` 만 저장 — Liskov 치고 의도적이지만 런타임 silent drop. `KakaoAccount/LineAccount` 만 실질 토큰 저장.
- `AgreedTerms.removeUserAgeCheck()` 는 입력 리스트를 **mutate** 해 외부 호출 이후에도 상태 변화(`dto/AgreedTerms.java:22-27`, `TermsAdapter.java:17`).
- Command 필드명 typo: `LinkUserToSocialAccountCommand.UserId` (PascalCase 필드) — `:8`.
- `PasswordService.genereateToken()` 메서드명 오타(`:81`). 외부 클라이언트 시그니처 의존 가능.

### 8.2 본 문서 범위 밖으로 넘긴 영역

- **Adapters 세부**:
  - `adapters/outbound/persistence/wadiz/**` (MyBatis/Mapper/SQL) — User 저장 스키마, SocialUserRepository 구현 세부.
  - `adapters/outbound/persistence/redis/**` — `EmailValidationCodeEntity*` Redis 매핑 + TTL.
  - `adapters/outbound/externalservice/**` — Kakao / Notification / Braze CRM / Coupon / Terms / UserApi / Push2 HTTP 클라이언트 시그니처와 에러 매핑.
- **Authentication / SecurityConfig**:
  - `application/authentication/*AuthenticationSuccessHandler.java` — 성공 핸들러 체인, `UserLoggedEvent` 발행 컨텍스트.
  - `SessionCleanerService` 내부의 Redis Indexed Session 정리 로직.
  - `OAuth2` 토큰 엔드포인트 / introspection / JWKS 설정 (authorizationserver 구성).
- **Dormant/DropOut 전이**:
  - `User.Status.InActive`, `Status.DropOut` 로의 전이 코드는 본 repo 도메인 계층에 없음. `UserRepositoryPort.hasDropoutHistory` 로만 참조. → legacy `com.wadiz.wave.user` 또는 배치/어드민 담당 가능성.
- **이메일 인증 코드 만료/중복 발급 정책**:
  - `EmailValidationRepositoryPort` 계약엔 TTL/덮어쓰기 정책 없음. Redis adapter 에 위임.
- **약관 버전 관리**:
  - `Terms` 는 `serviceCode + termsType` 2필드만. 약관 버전(version)·본문·동의시각은 외부 Terms API 담당(미탐색).
- **Kotlin common 패키지 내용**: `src/main/kotlin/kr/wadiz/oauth2/common/**` 파일 목록 확인만.
- **오류 처리 공통**: `WadizException`, `ErrorCode`, `MessageCode` 정의 본문 (common 패키지).
- **Bean Validation 규칙 상세**: `SendCodeCommand` 외 Command 들의 검증 제약, i18n messages.
- **테스트 커버리지**: `src/test/**` 는 본 분석 대상 아님.

### 8.3 관측된 Aggregate 경계 결론

- **User Aggregate**: root = `User`, 하위 = `List<SocialAccount>` (1:N, 다형성), `List<Terms>`(값 컬렉션), `List<UserDataChangeRecord>`. 생명주기는 `userRepositoryPort.create/createSocial/update/updatePassword` 를 통해 영속.
- **Terms** 는 **자체 Aggregate 아님** — VO 컬렉션 + 외부 API. 식별자 없음.
- **PasswordResetToken** 은 User 와 분리된 단순 엔티티(비즈니스 규칙 소수).
- **UserDataChangeRecord** 는 User 의 child collection 이자 동시에 별도 포트(`UserDataChangeRecordRepositoryPort`)로 영속 — aggregate 경계가 flex 됨. `UserCreatedEvent` 리스너가 별도 flush.
- **EmailValidationCode** 는 Aggregate 아님, Redis VO — 세션 단위.

---

## 참고 파일 인덱스 (본 문서에서 인용한 주요 경로)

- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/User.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/SocialAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/KakaoAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/LineAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/NaverAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/AppleAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/FacebookAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/GoogleAccount.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/SocialAccountWithAdditionalInfo.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/WithAdditionalInfo.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/TokenStorable.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/SocialAccountFactory.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/user/PasswordResetToken.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/terms/Terms.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/terms/ServiceCode.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/terms/TermsType.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/terms/TermsPort.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/email/EmailService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/email/FastEmail.kt`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/email/NormalEmail.kt`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/authenticationcode/AuthenticationCodeService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/common/EmailValidationCode.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/event/DomainEvent.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/event/UserCreatedEvent.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/event/UserLoggedEvent.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/exception/AuthenticationCodeExpiredException.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/exception/EmailAlreadyExistsException.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/exception/EmailNotSentException.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/exception/InvalidAuthenticationCodeException.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/service/Service.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/service/ServiceType.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/service/ServiceTypeManager.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/userrecording/UserDataChangeRecord.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/userrecording/UserDataChangeRecordingService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/AgreementToTermsConverter.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/AbstractCreateUserService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/CreateUserApplicationService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/CreateUserWithSocialAccountApplicationService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/AuthenticationCodeApplicationService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/GetSignUpInformationApplicationService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/LinkUserToSocialUserApplicationService.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/PasswordService.kt`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/dto/AgreedTerms.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/dto/WithAgreedTerms.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/dto/SocialSignUpCommand.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/dto/SendCodeCommand.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/dto/ReconnectionContactsCommand.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/domain/applicationservice/dto/UserTimeZoneUpdateByCountryRequest.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/port/inbound/*` (10 files)
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/port/outbound/*` (20 files)
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/adapters/outbound/externalservice/terms/TermsAdapter.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/application/authentication/EmailAuthenticationSuccessHandler.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/application/authentication/SocialAuthenticationSuccessHandler.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/application/authentication/RememberMeAuthenticationSuccessHandler.java`
- `kr.wadiz.account/src/main/java/kr/wadiz/oauth2/application/authentication/SessionCleanerService.java`
