# web-test-automation-global 분석 문서

> 와디즈 **글로벌 서비스의 회귀(Sanity) 테스트 자동화** 저장소입니다. Playwright 로 PC·모바일 웹을 동시에 검증합니다. 저장소 제목은 *"Global Regression by AI"* 입니다.
> Org: `wadiz-qa` (`https://github.com/wadiz-qa/web-test-automation-global.git`). 서비스가 아니라 **QA 도구**라 helm 배포 대상이 아닙니다.

> 📅 분석 기준: 2026-09-15, **`main` 브랜치**(`431376c`, 2026-09-14). TypeScript 125개 · 테스트 스펙 **90개**.

> ℹ️ 국내용 짝이 되는 저장소가 따로 있습니다 — `web-test-automation`(이번 범위 밖, 문서 없음).

---

## 개요

- **검증 대상은 실제 배포된 웹사이트**입니다. 코드를 빌드하지 않고 브라우저로 직접 들어가 시나리오를 밟습니다.
- 기본 대상 환경은 **stage(`https://stage.wadiz.io`)** 이며, `TEST_ENV` 환경 변수로 갈아탑니다.
- **CI 워크플로가 없습니다**(`.github/workflows` 부재). 현재는 **로컬에서 수동 실행**하는 도구입니다.

## 실행 환경

| 항목 | 값 |
|---|---|
| 프레임워크 | **Playwright 1.x** + TypeScript |
| 브라우저 | Chromium 단일 |
| 프로젝트(뷰포트) | **PC 1280×720** · **Mobile iPhone 15(390×844)** |
| 병렬 | `workers: 3`, `fullyParallel` |
| 재시도 | 1회 |
| 리포트 | HTML (`html-report/`) |

### 환경 매핑 (`helpers/constants/env.ts`)

환경마다 **웹 도메인·쿠키 도메인·계정(로그인) 호스트가 모두 다릅니다.** 이 파일이 그 단일 출처입니다.

| `TEST_ENV` | 웹 URL | 쿠키 도메인 | 계정 호스트 |
|---|---|---|---|
| `rc` · `rc2` | `rc.wadiz.kr` · `rc2.wadiz.kr` | `.wadiz.kr` | `account.wadiz.kr` |
| **`stage`**(기본) | **`stage.wadiz.io`** | `.wadiz.io` | **`account.stage.wadiz.io`** |
| `live` | `www.wadiz.kr` | `.wadiz.kr` | `account.wadiz.kr` |
| `clive` | `www.wadiz.io` | `.wadiz.io` | `account.wadiz.io` |

- 파일 머리에 **왜 한곳에 모았는지**가 적혀 있습니다 — 도메인이 여러 spec·helper 에 하드코딩돼 있어서 **클라우드 환경으로 옮기면 영어 UI 강제와 로그인 검증이 깨지기** 때문입니다.
- stage 는 **2026-09-11 에 `stage.wadiz.kr` → `stage.wadiz.io`** 로, 계정도 `stage-account.wadiz.kr` → `account.stage.wadiz.io` 로 옮겨졌습니다(주석에 날짜 기재). [`com.wadiz.web`](./com.wadiz.web.md) 의 RWD-6044·[`wadiz-frontend`](./wadiz-frontend/wadiz-frontend.md) 의 CLIENT-258 과 같은 이전입니다.

## 구조

```
playwright.config.ts     # PC/Mobile 프로젝트 정의
global-setup.ts          # 로그인 + 테스트 대상 프로젝트 동적 수집
storageState.json        # 인증 세션 (자동 생성)
discoveredProjects.json  # 수집된 펀딩/오픈예정 URL (자동 생성)
fixtures/                # 테스트 계정
helpers/                 # auth · payment · funding · wish · mywadiz · home · maker · gmail · reporters · constants
page_objects/            # Page Object Model — home · funding · launching-soon · search · wish · mywadiz · account · payment · layout
docs/                    # page-object-guide.md · scenario-writing-guide.md · ai-context/
test/                    # 8개 카테고리 · 90 스펙
```

### 테스트 스펙 90개 (카테고리별)

| 카테고리 | 스펙 | TC 범위(README) |
|---|---:|---|
| home | 25 | TC_003~043 |
| mywadiz | 22 | TC_083~114 |
| funding | 18 | TC_051~068 (067·069 삭제) |
| launching-soon | 7 | TC_044~050 |
| wish | 6 | TC_077~082 |
| search | 5 | TC_020~024 |
| payment | 4 | TC_070~076 |
| account | 3 | TC_009·016·017 (010~015 삭제) |

## 눈에 띄는 설계

### ① 테스트 대상 프로젝트를 매번 새로 찾습니다 (`global-setup.ts`)

- 펀딩·오픈예정 프로젝트 URL 을 **하드코딩하지 않고 실행 시점에 홈에서 수집**해 `discoveredProjects.json` 에 씁니다. 프로젝트는 마감되면 사라지므로 고정 URL 이 금방 썩기 때문입니다.
- **결제 TC 용 폴백**까지 준비합니다 — 첫 프로젝트에서 배송지 영역을 만나지 못하면(무형·투자형 리워드는 배송지 영역 자체가 렌더링되지 않음) 두 번째 후보로 한 번 더 시도합니다.
- 국내 UI 로 잘못 들어갔는지 **본문 텍스트(`오픈예정|펀딩\+|프리오더|로그인/회원가입`)로 판별**합니다.

### ② 부하 경합을 병렬도 조절로 다룹니다 (`playwright.config.ts`)

설정 파일의 주석이 실측 근거를 남겨 두었습니다.

- 병렬 부하가 커지면 **SSR 응답 지연으로 timeout 이 다발**합니다. 그래서 무거운 spec 은 별도 project 로 떼고 타임아웃을 늘립니다(`HEAVY_TIMEOUT`).
- **결제 TC 는 30초 기본 타임아웃에서 TC_071·073·074 가 전부 실패**해, 폴백 1회까지 들어갈 여유를 줬습니다.
- **wish·auth 계열은 경합을 원천 차단하려고 별도 project 로 분리**하고 실행 시 `--workers=1` 로 직렬화합니다. Playwright 의 `workers` 는 전역값이라 project 단위로 못 박을 수 없어, **직렬화를 실행 명령으로 보장**하는 구조입니다(`package.json` 의 `test:wish:*`·`test:auth:*`, `run-tests.sh`).

### ③ 회원가입 TC 가 실제 메일을 읽습니다

- 이메일 회원가입(TC_009)은 가입 중 발송되는 **인증번호 메일을 Gmail API 로 읽어 자동 입력**합니다 (`helpers/gmail/`).
- 이를 위해 `GMAIL_CLIENT_ID`·`GMAIL_CLIENT_SECRET`·`GMAIL_REFRESH_TOKEN` 세 값이 필요하고, README 에 **Google Cloud OAuth 클라이언트 발급 절차가 스크린 단위로** 적혀 있습니다.
- refresh token 은 OAuth 동의 화면이 **Testing 상태면 7일 후 만료**되므로 `Internal`(또는 게시됨) 상태를 권장한다는 주의까지 있습니다.

## 최근 변경 (2026-09-10 · 09-14)

| 커밋 | 내용 |
|---|---|
| `a8db599` | 모바일 **국가 변경 TC 의 시간 예산을 올리고**, TC_065 의 CTA 라벨 대기를 완화 |
| `85b1d1b` | **stage 클라우드 도메인 이전 검증** + `global-setup` 의 홈 수집 보강 (`global-setup.ts` +225/−?, `helpers/constants/env.ts`) |

- 직전(2026-09-08)에는 **새소식 있음/없음 분기 오작동**(TC_049·TC_059)과 **결제 배송지 TC 를 배송비 있는 프로젝트 우선 진입으로 안정화**하는 수정이 있었습니다.
- 즉 최근 변경은 전부 **깨진 시나리오를 다시 붙이는 유지보수**이며, 그 원인은 대체로 **대상 환경 이전(클라우드·도메인 변경)과 데이터 변동**입니다.

## 미확인 항목

- **실행 주체와 주기** — CI 워크플로가 없어 누가 언제 돌리는지 저장소만으로는 알 수 없습니다. 수동 실행으로 보이나 미확인입니다.
- **국내용 `web-test-automation`(문서 없음)과의 관계** — 시나리오·헬퍼를 공유하는지, 완전히 별도인지.
- `docs/ai-context/` 의 용도 — 이름으로 보아 AI 에이전트가 참조하는 맥락 문서로 보이나 내용은 확인하지 않았습니다.
- 테스트 계정(`fixtures/`)과 `.env` 의 자격증명 관리 방식 — `.env` 는 커밋되지 않는다고만 적혀 있습니다.
