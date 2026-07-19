# 기능 이정표 — global 외 앱

> 전체 인덱스는 [`README.md`](./README.md) 참조. 이 파일은 `apps/global` 을 제외한 앱들입니다. 기준: master `4439853b8dd`.
> 계정(account)은 supporter i18n 사용. 랜딩(ir/partners/partnerzone/help-center)은 API가 거의 없고 정적/CDN JSON·Zendesk 데이터 기반. 도구(mail/walink/devtools)는 대부분 하드코딩.

## 이 파일의 앱

| 앱 |
|---|
| [계정 (apps/account)](#계정-appsaccount) |
| [IR (apps/ir)](#ir-appsir) |
| [파트너스 (apps/partners)](#파트너스-appspartners) |
| [파트너존 (apps/partnerzone)](#파트너존-appspartnerzone) |
| [고객센터 (apps/help-center)](#고객센터-appshelp-center) |
| [메일 템플릿 (apps/mail-template)](#메일-템플릿-appsmail-template) |
| [와링크 생성기 (apps/walink-generator)](#와링크-생성기-appswalink-generator) |
| [WAi 런처 (apps/wai-ai-agent-launcher)](#wai-런처-appswai-ai-agent-launcher) |
| [개발자 도구 (apps/devtools)](#개발자-도구-appsdevtools) |

---

# 계정 (apps/account)

> Vite 6 + React 18 SPA, FSD 구조. React Router v6, 경로 앞 `:languageCode?`로 다국어, `isMobile`로 Desktop/Mobile 분기. i18n은 `@wadiz/i18n`(supporter) 공유 — 실제 문구는 `packages/i18n/src/supporter/languages/{ko,en,ja,zh}.json`. 키 접두사: `account_login_page`·`account_signup_page`·`account_delete_page`·`terms_agreement_modal` 등. 구버전 앱 웹뷰용 레거시 흐름은 `(auth-app)` 하위(수정 주의).

## 로그인

관련 이슈: `FE1-274`(소셜 로그인 에러 메시지), `FE1-846`(앱 웹뷰 SNS 로그인 차단), `FE1-684`(메이커센터 로그인 시 앱 버튼 숨김), `FE1-1017`(로그인 화면 로케일 우선 적용)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 통합 로그인 화면(`/login`) | `apps/account/src/pages/(auth)/login/AuthLoginPage.tsx` |
| 이메일 로그인 폼 + 소셜 버튼 — `account_login_page.email_login_section.email_button_label`="이메일로 로그인하기", `content.keep_logged_in_checkbox_label`="로그인 유지" | `apps/account/src/pages/(auth)/login/_ui/LoginFormAndSocialButtons.tsx` |
| 이메일 입력·검증 — `email_login_section.email_field_placeholder`="이메일 입력", `email_field_valid_error_message`="올바른 이메일 주소를 입력해 주세요." | `apps/account/src/pages/(auth)/login/_ui/EmailValidationForm.tsx` |
| SNS 로그인(카카오/네이버/구글/애플/페북/라인) — `social_login_section.kakao_button_label`="카카오로 시작하기" | `apps/account/src/pages/(auth)/login/_ui/LoginFormAndSocialButtons.tsx` |
| 로그인 실패 문구 — `email_login_section.password_field_match_error_message`="와디즈에 등록되지 않은 아이디거나…" | `packages/i18n/src/supporter/languages/ko.json` (`account_login_page`) |
| 앱으로 시작하기 유도 버튼 + 쿠폰 팝오버 — `app_login_section.app_button_label`="편하게 앱으로 시작하기", "로그인하고 최대 4,000원 혜택 받기 🎁" | `apps/account/src/widgets/app-launch-button/ui/AppLaunchButton.tsx` |

## 회원가입

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 이메일 회원가입 화면(`/signup`) | `apps/account/src/pages/(auth)/signup/AuthSignupPage.tsx` |
| 이메일 인증 + 가입 폼 — `account_signup_page.header.title`="회원가입", `signup_section.signup_button_label`="약관 동의 후 가입 완료하기", `nickname_field_placeholder`="닉네임 입력" | `apps/account/src/pages/(auth)/signup/_ui/SignupForm.tsx` |
| 이메일 인증 단계(코드 발송/입력) — `signup_section.verification_code_field_send_button_label`="인증하기", `..._match_error_message`="인증 번호가 일치하지 않아요." | `apps/account/src/pages/(auth)/signup/_ui/EmailSignup.tsx` |
| 회원가입 완료 — `account_signup_completed_page.content.title`="{{arg_0}} 서포터님, 와디즈에 오신 걸 환영해요!" | `apps/account/src/pages/(auth)/account/signup/completed/_ui/SignupCompleted.tsx` |
| 가입완료 친구초대 코드 입력 — `code_section.title`="친구 초대 코드 입력", `join_now_button_label`="참여하기" | `apps/account/src/pages/(auth)/account/signup/completed/_ui/SignUpPromotionApplication.tsx` |

## 비밀번호 · 아이디 찾기

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 비밀번호 찾기(재설정 링크 발송, `/find-password`) — `account_find_password_page.header.title`="이메일을 입력해 주세요", `content.send_email_button_label`="링크 발송" | `apps/account/src/pages/(auth)/(find)/_ui/FindPassword.tsx` |
| 비밀번호 재설정(`/reset-password/:token`) — `account_reset_password_page.header.title`="비밀번호 재설정", 완료 모달 `reset_password_completed_dialog_modal.header.title`="비밀번호 변경 완료" | `apps/account/src/pages/(auth)/reset-password/_ui/ResetPassword.tsx` |
| 아이디(가입 여부) 확인(`/find-id`) — `account_find_id_page.content.title`="이메일을 입력해 주세요", 결과 "회원으로 등록된 이메일이에요"/"소셜 계정입니다." | `apps/account/src/pages/(auth)/(find)/_ui/FindID.tsx` |

## SNS 연동 · 본인(이메일) 인증

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 소셜 계정 연동(`/social-link`) — `account_social_link_page.header.title`="가입된 회원 정보가 있어요", `content.login_and_link_account_button_label`="로그인하고 계정 연동하기" | `apps/account/src/pages/(auth)/social-link/_ui/SocialLink.tsx` |
| 소셜 간편가입(`/social-signup`) — `account_social_signup_page.header.title`="간편가입" | `apps/account/src/pages/(auth)/social-signup/_ui/SocialSignup.tsx` |
| OAuth 소셜 로그인 처리(카카오 등) / SNS SDK 로딩 | `apps/account/src/entities/oauth/api/social.js`, `apps/account/src/entities/sns/kakao.js` |
| 이메일 인증 코드(가입 시) — `account_signup_page._default.email_verification_code_toast_message_markdown`="인증 번호를 전송했어요…" | `apps/account/src/pages/(auth)/_ui/EmailAuth/EmailAuthCodeField.tsx` |

## 탈퇴 · 약관 · 공통

관련 이슈: `FE1-900`(braze 초기화), `FE1-909`(auth header bearer token 삭제)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 회원 탈퇴(`/account/delete`) — `account_delete_page.header.title`="회원 탈퇴", `reason_select.placeholder`="탈퇴 사유는 무엇인가요?", `important_checklist.title`="탈퇴 전, 꼭 확인해 주세요!" | `apps/account/src/pages/(auth)/account/delete/_ui/AccountDropOutContainer/AccountDropOutContainer.jsx` |
| 탈퇴 확인/완료 모달 — `account_delete_dialog_modal.header.account_delete_title`="정말 탈퇴하시겠어요?", `account_delete_complete_title`="탈퇴를 정상적으로 처리했어요" | `packages/i18n/src/supporter/languages/ko.json` (`account_delete_dialog_modal`) |
| 약관 동의 모달(가입 시) — `terms_agreement_modal.content.all_terms_agreement_field_label`="전체 동의", `age_agreement_field_label`="만 14세 이상입니다.", `footer.confirm_button_label`="회원가입 완료" | `apps/account/src/pages/(auth)/_ui/TermsConfirmModal/TermsConfirmModal.tsx` |
| 하단 정책 안내 — `account_login_page.footer.terms_of_use_button_label`="공통 정책·약관", `privacy_policy_button_label`="개인정보 처리방침" | `apps/account/src/pages/(auth)/_ui/PolicyGuide/PolicyGuide.tsx` |
| 구버전 앱 웹뷰 전용 레거시 흐름(`/account/*`·`/web/*`) — 신규 `(auth)`와 중복이나 앱 웹뷰 대상 | `apps/account/src/pages/(auth-app)/**` |

## 이슈 히스토리 (apps/account)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-274 | 작업 | [Web] 소셜 회원가입/로그인 시도시 provider 정보를 보여주도록 에러 메시지 수정 |
| FE1-846 | 작업 | 앱 웹뷰 SNS 로그인 차단 대응 — inAppBlacklist에 와디즈 앱 추가 (구글/페이스북) |
| FE1-684 | 작업 | 메이커센터에서 로그인할 경우 "앱으로 시작하기" 버튼 숨김 |
| FE1-1017 | 작업 | [Web][account] 로그인 화면 표시 로케일(uiLocales) 우선 적용 |
| FE1-900 | 작업 | [Web] braze 초기화 문제 수정 |
| FE1-909 | 작업 | [app-api] auth header 의 bearer token 삭제 |
| FE1-387 | 스토리 | [Web] axios 보안 이슈 대응 |
| FE1-708 | 에픽 | [Web] Cloud 작업 |

---

# IR (apps/ir)

> Next.js App Router지만 대부분 `'use client'` + `useEffect` fetch. **자체 API 없음** — 모든 텍스트/목록은 외부 CDN JSON(`NEXT_PUBLIC_DATA_URL=https://cdn3.wadiz.kr/app/*.json`)에서 받아 렌더하고, 실패 시 리포 내 동봉 JSON(mock/fallback)으로 대체. 본문은 `ContentRenderer`가 `contents.json`의 키로 렌더. 메뉴만 로컬 `menu.json`.

관련 이슈: `CLIENT-26`(코드 콘텐츠 → Google Sheets 관리), `CLIENT-23`(공고 본문 마크다운), `CLIENT-180`(홈 감사보고서 최신일자 동적), `FE1-685`(일본 IR 공시)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 전역 헤더/GNB (회사정보/재무정보/IR정보/뉴스룸) — 로컬 `menu.json` | `apps/ir/src/shared/api/menu.json` |
| 홈(비주얼 슬라이더 + 소개/IR/주요뉴스) — 데이터 기반(CDN contents.json 등) | `apps/ir/src/views/(home)/HomePage.tsx` |
| 회사 소개(대표 프로젝트/집계지표/서비스) — 데이터 기반 | `apps/ir/src/views/information/about/AboutPage.tsx` |
| CEO 인사말 — 데이터 기반 | `apps/ir/src/views/information/ceo-message/_ui/CeoMessageSection/CeoMessageSection.tsx` |
| 연혁 및 수상 — 섹션 제목 **하드코딩** "와디즈가 걸어온 길", 목록은 CDN history-list.json | `apps/ir/src/views/information/history/_ui/HistoryListSection/HistoryListSection.tsx` |
| 지속가능경영(ESG) / 기업지배구조(이사회·위원회·주주총회·자회사) — 데이터 기반 | `apps/ir/src/views/information/{esg/EsgPage,corporate-governance/*}.tsx` |
| 재무(연결재무제표·손익계산서·감사보고서) — 데이터 기반 | `apps/ir/src/entities/statement/api/getStatements.ts`, `apps/ir/src/views/financial-information/audit-report/AuditReportPage.tsx` |
| IR 자료실 / 공시 정보 / 공고 목록·상세 — 데이터 기반 | `apps/ir/src/views/ir-information/{reference-room,disclosure-information,announcement}/` |
| 일본어 IR 공시 페이지(/jp/ir) — 데이터 기반 | `apps/ir/src/views/jp/ir/Page.tsx` |

# 파트너스 (apps/partners)

> Next.js, API 없음. 문구/목록 전부 리포 내 **하드코딩**(로컬 TS/JSON + JSX 인라인), 이미지는 `NEXT_PUBLIC_STATIC_URL` CDN. 단일 원페이지(`page.tsx`)에 섹션 나열.

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 원페이지 조립/스크롤 섹션 구성 | `apps/partners/src/app/page.tsx` |
| GNB (Company/Invest/Portfolio/News) — 로컬 JSON | `apps/partners/src/app/data/menu.json` |
| 키비주얼 히어로 — **하드코딩** "와디즈파트너스는 도전을 통해 새로운 가치를 증명하고…" | `apps/partners/src/app/components/KeyVisualSection/KeyVisualSection.tsx` |
| 누적 실적 현황 — **하드코딩** "누적 운용 자산 / 누적 투자 유치 규모 / 누적 포트폴리오" | `apps/partners/src/app/components/StatusSection/StatusSection.tsx` |
| 대표/투자사 소개 — **하드코딩** "펀딩으로 시작해서 투자까지…벤처투자회사입니다." | `apps/partners/src/app/components/{PartnerSection,InvestSection}/` |
| 넥스트 브랜드 프로그램/IR Day/지원 신청 — **하드코딩** | `apps/partners/src/app/components/{NextBrandSection,IRDaySection,RegisterSection}/` |
| 연혁·포트폴리오·로고·혜택 데이터 — 로컬 **하드코딩** | `apps/partners/src/app/data/{history,portfolio,logo}.ts` |

# 파트너존 (apps/partnerzone)

> Vite SPA, iframe 임베드용(`index.html` `<title>메인</title>`). API 없음, 문구 전부 **하드코딩**(로컬 `src/data/*` + 인라인). 신청은 외부 typeform, 에셋은 `static.wadiz.kr/partnerzone` CDN.

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| iframe 임베드 진입 HTML | `apps/partnerzone/index.html` |
| 메인 섹션 조립 + typeform 신청 링크 | `apps/partnerzone/src/pages/main/Main.tsx` |
| 키비주얼 — **하드코딩** "전문가는 다릅니다", "나에게 필요한 서비스만 골라…맞춤 패키지" | `apps/partnerzone/src/pages/main/components/KeyVisual/KeyVisual.tsx` |
| 스티키 탭 내비 / 패키지·키비주얼 데이터 / FAQ — 로컬 **하드코딩** | `apps/partnerzone/src/data/{navigation,data.js,faq}.ts` |
| 이용 가능 서비스/패키지 선택 — **하드코딩** "필요한 서비스를 모두 선택하세요" | `apps/partnerzone/src/pages/main/components/Partner/Partner.tsx` |
| 서비스 소개/진행 프로세스 — **하드코딩** "검증된 전문가와 함께하세요.", "파트너 무료 상담 → 서비스 신청 → 작업 시작!" | `apps/partnerzone/src/pages/main/components/WhyWadiz/WhyWadiz.tsx`, `apps/partnerzone/src/components/Usage/Usage.tsx` |

# 고객센터 (apps/help-center)

> Zendesk Guide 테마(Handlebars `.hbs`), `zcli` 배포. 앱 번들 없음. 문구 3원천 — ① Zendesk 지식베이스 데이터(`{{#each categories/sections/articles}}`), ② 다이나믹 콘텐츠 `{{dc '키'}}`, ③ 테마 번역 `{{t '키'}}`·`{{settings.*}}`. **리포에는 최종 텍스트가 아닌 키/템플릿만** 존재.

관련 이슈: `FE1-131`(문의 채널 일원화), `FE1-231`(도움말센터 푸터 링크·WAi·문의 일원화)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 공통 head/헤더/푸터 | `apps/help-center/src/templates/{document_head,header,footer}.hbs` |
| 홈(히어로 검색 + FAQ 카테고리 탭) — dc `home_page_key_visual_section_title`·`faq_title` | `apps/help-center/src/templates/home_page.hbs` |
| 카테고리/섹션/문서(아티클) 상세 — Zendesk 데이터 | `apps/help-center/src/templates/{category_page,section_page,article_page}.hbs` |
| 검색 결과 / 요청(문의) 목록·상세·작성 | `apps/help-center/src/templates/{search_results,requests_page,request_page,new_request_page}.hbs` |
| 커뮤니티 토픽/글 목록·상세·작성 | `apps/help-center/src/templates/community_*.hbs` |
| 테마 설정/기본값·번역키(색상/히어로/블록 문구 원천) | `apps/help-center/src/manifest.json` |
| 티켓/설문 메일 템플릿 | `apps/help-center/mail-template/ticket_status_requested_mail_template.html` |

## 이슈 히스토리 (랜딩/고객센터 앱)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| CLIENT-26 | 작업 | 와디즈 IR 웹사이트 - 코드 기반 콘텐츠를 Google Sheets 기반 콘텐츠로 관리 |
| CLIENT-23 | 버그 | 와디즈 IR 웹사이트 - IR 정보 - 공고 - 본문에 마크다운 스타일 추가 |
| CLIENT-180 | 작업 | 와디즈 IR 웹사이트 - 홈 감사보고서 참조를 최신 일자 기준 동적 주입 |
| FE1-685 | 에픽 | 일본 IR 공시 페이지 구현 |
| FE1-1031 | 작업 | 앱스토어 링크를 디바이스 플랫폼별로 노출 분기 |
| FE1-231 | 작업 | 도움말센터 - 푸터 링크 및 WAi 변경 및 문의 등록 일원화 |
| FE2-359 | 작업 | [FE2] 젠데스크 문의 연결 링크 교체 - 파트너 존 |
| FE1-131 | 에픽 | [WAi/상담원 Agent P2] 문의 채널 일원화 |

---

# 메일 템플릿 (apps/mail-template)

> Vite + Handlebars(hbs). `prebuild`로 main.json·asset-list 생성 → `vite build` + `export-preview-html.js`로 HTML 산출(S3 배포). 사내 관리 이메일 템플릿 빌드/미리보기/다운로드. 문구 대부분 **하드코딩**.

관련 이슈: `FE2-270`(Stripe Connect 메일 10종), `FE2-286`(광고센터 가부킹 메일), `FE2-317`(정산내역서 메일), `FE2-365`(어드민 계정 발급 메일), `FE2-679`(커뮤니티 댓글 알림 메일), `FE1-784`(글로벌 알림 메일), `FE1-835`(wadiz.ai 도메인 제거), `FE1-1089`(개인정보 처리방침 개정 메일)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 메일 템플릿 목록 페이지(검색·정렬·언어 선택·미리보기·다운로드) — **하드코딩** "메일 템플릿 목록", "Search in mail templates!" | `apps/mail-template/src/pages/index.hbs` (+ `index.js`) |
| 전체 언어 ZIP 다운로드 / 단일 HTML 다운로드 | `apps/mail-template/src/pages/index.js` |
| 개별 메일 템플릿 본문(실제 발송 템플릿) — 템플릿별 **하드코딩** | `apps/mail-template/src/pages/templates/*.hbs` |
| 공통 헤더/푸터/레이아웃 파셜 | `apps/mail-template/src/partials/*.hbs` |
| 목록 데이터 생성 스크립트(main.json) | `apps/mail-template/scripts/generate-main-data.js` |

# 와링크 생성기 (apps/walink-generator)

> Vite + React(FSD). 와디즈 단축 URL("와링크") 생성 사내 도구. 문구 전부 **하드코딩**(한국어).

관련 이슈: `FE1-857`(walink-generator wadiz.io 도메인 전환·cdev 추가)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 앱 셸(헤더+본문+푸터) | `apps/walink-generator/src/pages/(home)/HomePage.tsx` |
| 헤더 타이틀 — **하드코딩** "와링크 생성기" | `apps/walink-generator/src/pages/(home)/_ui/Header/Header.tsx` |
| 원본 URL 입력 + 도메인 검증 — **하드코딩** "원본 URL", "생성하기", "*.wadiz.kr 또는 *.wadiz.io 도메인만 입력할 수 있어요." | `apps/walink-generator/src/pages/(home)/_ui/URLFieldSection/URLInputField.tsx` |
| 와링크 생성 API 호출 / 결과 출력·복사 — **하드코딩** "와링크 URL", "복사하기", "URL을 복사했어요." | `apps/walink-generator/src/pages/(home)/_ui/URLFieldSection/{URLFieldSection,URLOutputField}.tsx` |

# WAi 런처 (apps/wai-ai-agent-launcher)

> Vite + React(FSD). 각 와디즈 서비스에 임베드되는 "AI Agent WAi" 진입 버튼/모달 런처(iframe/새 창). i18n `@wadiz/i18n/wai-ai-agent-launcher`(keyPrefix `wai_ai_agent_launcher_component`).

관련 이슈: `FE2-441`(WAi io 도메인 대응)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 플로팅 런처 컨테이너(위치 고정·스크롤 제어) | `apps/wai-ai-agent-launcher/src/features/WAiAIAgentContainer/WAiAIAgentContainer.tsx` |
| WAi 진입 버튼(데스크톱/모바일, 서포터용 분기) — i18n `header.description`, **하드코딩** "AI Agent WAi" | `apps/wai-ai-agent-launcher/src/entities/WAiAIAgentButton/WAiAIAgentButton.tsx` (+ `...SupporterButton.tsx`) |
| WAi 모달 + iframe(로그인/링크 postMessage 브릿지) — **하드코딩** title "WAi AI Agent" | `apps/wai-ai-agent-launcher/src/widgets/WAiAIAgentModal/WAiAIAgentModal.tsx` (+ `ui/WAiAIAgentIframe.tsx`) |
| WAi 창/모달 오픈 로직(환경별 도메인·returnUrl·앱 웹뷰 분기) | `apps/wai-ai-agent-launcher/src/shared/lib/useWAiAIAgentWindowOpen.tsx` |
| i18n 문구 정의 — `header.description`="안녕하세요, 무엇을 도와드릴까요?" 등 | `packages/i18n/src/wai-ai-agent-launcher/languages/ko.json` |

> 참고: `apps/wai/` 는 `node_modules`만 있고 소스가 없어 실질 앱이 아닙니다.

# 개발자 도구 (apps/devtools)

> 하위에 `component-playground`(packages/ui 컴포넌트 테스트)와 `app-settings-console`(환경/플랫폼별 앱 설정 JSON CRUD 콘솔 + Express 프록시) 두 도구. 문구 전부 **하드코딩**.

관련 이슈: `CLIENT-104`(GEO/SEO robots noindex를 앱 설정 API로 구성 — app-settings-console)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 컴포넌트 플레이그라운드 셸(사이드바 자동 라우팅) — **하드코딩** "Component Playground", "packages/ui 컴포넌트를 테스트할 수 있는 공간입니다." | `apps/devtools/component-playground/src/app/App.tsx` (+ `src/pages/index.tsx`) |
| 앱 설정 콘솔 헤더 + 환경/플랫폼 선택 — **하드코딩** "앱 설정 콘솔", "environment"/"platform" | `apps/devtools/app-settings-console/src/app/ui/Header.tsx` |
| 설정 목록 조회/삭제 — **하드코딩** "설정 추가", "조회된 목록이 없어요.", "{id} 설정을 삭제할까요?" | `apps/devtools/app-settings-console/src/pages/settings/SettingsPage.tsx` |
| 설정 카드(feature/settingId/JSON 표시) / 추가·수정(Monaco JSON 에디터) — **하드코딩** "settingId:", "JSON 정렬", "저장", placeholder "예: browser-reload" | `apps/devtools/app-settings-console/src/entities/app-settings/ui/AppSettingCard.tsx`, `src/pages/settings/[settingId]/SettingsDetailPage.tsx` |
| API 프록시 서버 | `apps/devtools/app-settings-console/server.ts` |

## 이슈 히스토리 (도구 앱)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| CLIENT-104 | 작업 | GEO/SEO(www.wadiz.kr) robots noindex를 앱 설정 API 기반 구성 |
| FE2-270 | 작업 | Stripe Connect 메이커 안내 이메일 템플릿 10종 제작 |
| FE2-286 | 작업 | [광고센터-가부킹] 메일 템플릿 작업 |
| FE2-317 | 작업 | [정산 어드민] 정산내역서 관련 메일템플릿 |
| FE2-365 | 에픽 | [통합광고센터 관리자] 어드민 계정 발급 완료 메일 템플릿 생성 |
| FE2-679 | 에픽 | [FE][메이커 알림] 커뮤니티 댓글 관리 알림 메일 템플릿 |
| FE1-784 | 작업 | [FE] 글로벌 알림 이메일 템플릿 |
| FE1-835 | 작업 | [Web] 메일 템플릿 wadiz.ai 도메인 제거 |
| FE1-857 | 작업 | [Web] walink-generator wadiz.io 도메인 전환 및 cdev 환경 추가 |
| FE1-1089 | 작업 | 26/06 wadiz.kr_개인정보 처리방침 개정 |
