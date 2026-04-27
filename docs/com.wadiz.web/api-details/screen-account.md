# 화면 상세 — 회원가입·로그인 (`/web/waccount/*`, `/web/account/*`)

> 16 컨트롤러 · 3,930 라인. React `iam` 번들로 부분 이관 진행 — JSP는 SPA 쉘 + AJAX 엔드포인트 잔존.

## 1. 컨트롤러 매트릭스

| 컨트롤러 | 라인 | 메소드 수 | 핵심 URL |
|---|---:|---:|---|
| `WAccountRegistController` | 665 | 18 | `/wAccountRegistIntro`, `/register/type/v2`, `/wAccountRegistCorp`, `/wAccountRegistFinish`, `/register/personal`(POST) + ajax |
| `WAccountCommonController` | 800+ | 23 | `/wAccountLogin`, 로그아웃, SMS 토큰, 아이디/비밀번호 찾기, 휴면해제 |
| `WAccountSocialController` | — | 6 | 카카오/구글/페이스북/애플/네이버 OAuth callback |
| `WAccountUpdateController` | — | 10 | 개인정보·비밀번호·이메일·전화 수정 |
| `WAccountAdultController` | — | 4 | 성인인증 (NICE) |
| `WAccountMyController` | 56+ | (큼) | `/web/account/my`, 쿠폰 ajax |
| `WAccountEquityController` | — | (큼) | 투자 계정 (modify/personal, modify/corporation) |
| `WAccountJoinEquityController` | — | — | 투자형 가입 (개인/법인/전문투자자) |
| `WAccountPlusController` | — | — | 와디즈 플러스 (구 멤버십) |
| `WAccountDropOutController` | — | — | 회원 탈퇴 |
| `WAccountInfoController` | — | — | 계정 정보 |
| `WAccountFindController` | — | — | 아이디/비밀번호 찾기 |
| `WAccountNotificationSettingController` | — | — | 알림 설정 |
| `WAccountAffiliateController` | — | — | 어필리에이트 코드 |
| `WAccountPasswordController` | — | — | 비밀번호 변경 |
| `WAccountVerificationController` | — | — | 본인인증 진입 |

## 2. 회원가입 플로우 (`WAccountRegistController`)

| Line | URL | Method | 비고 |
|---|---|---|---|
| 72 | (class mapping) | — | `/web/waccount/*` |
| 141 | `/wAccountRegistIntro` | GET | 가입 인트로 |
| 188 | `/register/type/v2` | GET/POST | 가입 타입 선택 (개인/법인) |
| 259 | `/wAccountRegistCorp` | GET | 법인 가입 |
| 442 | `/wAccountRegistFinish` | GET | 가입 완료 |
| 460 | `/register/personal` | POST | 개인 가입 처리 |
| 278 | `/ajaxValidBusinessRegNum` | GET | 사업자번호 검증 |
| 287 | `/ajaxSendSmsTokenByMarketing` | POST | 마케팅 SMS 발송 |
| 297 | `/ajaxValidTokenByMarketing` | POST | 마케팅 SMS 확인 |
| 322 | `/ajaxAddPassword` | POST | 비밀번호 추가 |
| 404 | `/ajaxRequestSendEmailConfirm` | POST | 이메일 인증 발송 |
| 414 | `/ajaxRequestConfirmEmail` | POST | 이메일 인증 확인 |
| 423 | `/ajaxValidPromotioncode` | POST | 프로모션 코드 |

## 3. React 이관 — `iam` 번들

`/WEB-INF/jsp/react/entries/iam.jsp` (line 18: `<layout:extends name="account" />`):
- `__staticPath_iam_main_js` async 로드
- 회원가입·로그인·아이디찾기·비밀번호찾기 화면이 React `iam` 번들로 통합 이관
- JSP는 세션 인증·이메일 검증·SMS 인증 AJAX 엔드포인트만 남음

## 4. Mapper

| XML | Namespace | 비고 |
|---|---|---|
| `sqls/account/account-mapper.xml` | `account` | 일반 계정 |
| `sqls/account/userageverification-mapper.xml` | `userageverification` | 성인인증 |
| `sqls/account/userprofile-mapper.xml` | `userprofile` | 프로필 |
| `sqls/waccount/waccount-mapper.xml` | `waccount` | 신 계정 |
| `sqls/waccount/waccountCommon-mapper.xml` | `waccountCommon` | 공통 |
| `sqls/waccount/waccountEquity-mapper.xml` | `waccountEquity` | 투자 계정 |
| `sqls/waccount/waccountSocial-mapper.xml` | `waccountSocial` | 소셜 연동 |
| `sqls/waccount/waccountHistory-mapper.xml` | `waccountHistory` | 히스토리 |

총 12 XML / 176 statement / 13 `<if>`.

## 5. 외부 의존

| 외부 시스템 | 용도 |
|---|---|
| **NICE 본인인증** (`NiceID.Check 1.0`) | SMS·휴대폰 본인인증 |
| **Facebook OAuth** (App ID `190622721088710`) | 페이스북 로그인 |
| **Kakao OAuth** | 카카오 로그인 |
| **Naver OAuth** | 네이버 로그인 |
| **Google OAuth** (`com.google.api-client 1.32.1`) | 구글 로그인 |
| **Apple Sign In** (`bcpkix-jdk15on 1.60` JWT 검증) | 애플 로그인 |
| **LINE OAuth** | 라인 로그인 |
| **Braze** | CRM 마케팅 |

## 6. OAuth 플로우

```
[FE: /web/waccount/wAccountLogin]
   │ "카카오로 로그인" 클릭
   ▼
[Kakao OAuth 동의 화면]
   │ 사용자 승인
   ▼
[Callback /web/oauth/callback/kakao]
   │ oauth2LoginFilter (DelegatingFilterProxy)
   │ → access_token 교환
   │ → 사용자 정보 조회
   ▼
[WAccountSocialController]
   ├─ 신규 사용자 → /register/type/v2 (개인/법인 분기)
   └─ 기존 사용자 → 자동 로그인 → /web/main
```

## 7. 본인인증 (NICE)

```
[/web/waccount/ajaxRequestSendEmailConfirm]
  POST { email }
  → AccountService.sendEmailConfirm()
  → NICE 또는 자체 SMTP 발송
  → DB: account-mapper#insertEmailVerifyToken

[/web/waccount/ajaxRequestConfirmEmail]
  POST { email, token }
  → AccountService.confirmEmail()
  → DB: account-mapper#updateEmailVerified
```

## 8. 인증 필터 체인 (web.xml)

| 필터 | URL | 비고 |
|---|---|---|
| `oauth2LoginFilter` | `/web/oauth/callback/*` | 소셜 로그인 콜백 |
| `oauth2RedirectFilter` | `/*` | 로그인 진입 redirect |
| `bearerTokenAuthenticationFilter` | `/web/v1/maker/*`, `/web/v2/membership`, `/web/apip/funding/**`, `/web/apip/store/**` | API 키 인증 |
| `autoLoginFilter` | `/*` | 쿠키 기반 자동 로그인 |

## 9. urlrewrite 동작

| FROM | TO |
|---|---|
| `/web/account/my?viewType=backed` | `/web/wmypage/participation` |
| `/web/account/my?viewType=history` | `/web/wmypage/participation` |
| `/web/account/my?viewType=my` | `/web/wmypage/myfunding/makinglist` |
| `/web/account/my?viewType=int` | `/web/wmypage/myfunding/likelist` |
| `/web/account/my?viewType=point` | `/web/wmypage/mybenefit/pointlist` |
| `/web/account/my?viewType=coupon` | `/web/wmypage/mybenefit/coupon/my` |
| `/web/waccount/wAccountUpdatePlusInvest` | `/web/waccount/equity/modify/personal` (301) |
| `/web/ftaccount/login` | `/web/waccount/wAccountLogin` (301) |

## 10. 외부 참조
- 사용 레이아웃: `account` (waccount root 27, oauth, iam react), `wAccount` (waccount 14)
- account.wadiz.kr 경계 (kr.wadiz.account 와의 분리): `../../kr.wadiz.account/`
- 회원가입 native(앱) 통합: `../../_flows/auth-and-login.md` (있다면)
