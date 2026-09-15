# good-wave 분석 문서

> 와디즈 사내 TF **팀 굿웨이브**가 만드는 캠페인 웹사이트입니다. 서비스 본체와 무관한 **별도 프론트엔드 제품**이며, 기수(期)마다 새 캠페인 페이지를 만들어 한 저장소에 쌓아 갑니다.
> Org: `wadiz-fe` (`https://github.com/wadiz-fe/good-wave.git`). 배포 이름 **`good-wave-anyone-can-challenge`**, 플랫폼 `client`.

> 📅 분석 기준: 2026-09-15, **`cloud_live` 브랜치**(`9f80221`, 2026-09-10). TypeScript 836개 · TSX 170개 · SCSS 29개.

> ℹ️ 저장소의 `README.md` 가 소개·기술스택·구조·실행법을 잘 정리해 두었습니다. 이 문서는 그것과 겹치지 않게 **배포선·환경 매핑·라우트 구조·관측 사항**을 담습니다.

---

## 개요

- 저장소 설명은 이렇습니다 — *"팀 굿웨이브는 와디즈가 만드는 선한 임팩트를 모아 더 널리 알리기 위해 자발적으로 모인 사내 TF"* 입니다.
- **기수별 캠페인 페이지가 한 저장소에 누적**됩니다. 지금까지 4기입니다.

| 기수 | 캠페인 | 라우트 |
|---|---|---|
| 1기 | 굿 메시지 | `/good-message` |
| 2기 | 누구나 도전할 수 있는 세상 | `/` (route group `(anyone-can-challenge)`) |
| 3기 | 진국이 이야기 | `/zingugi-story` |
| 4기 | 찰떡궁합 동료 테스트 | `/best-buddy` |

- **2기가 루트 경로(`/`)를 차지**하고 있습니다. 배포 이름이 `good-wave-anyone-can-challenge` 인 것도 2기 기준으로 붙은 이름으로 보입니다(추정) — 이후 기수가 늘었는데도 이름은 그대로입니다.
- 모노레포 이유는 README 에 적혀 있습니다 — 기수별 페이지의 **공통 코드 재사용과 일관성** 때문이며, **단일 빌드 파이프라인으로 전부 함께 빌드·배포**합니다.

## 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 언어/프레임워크 | TypeScript · **Next.js 16.3.3** · React 19 | `apps/good-wave/package.json` |
| 스타일 | Sass Modules · StyleX · Emotion (3종 혼용) | README |
| 인증 | **NextAuth.js 4.24**(Google) | `package.json`, `src/app/api/auth/[...nextauth]/` |
| DB / ORM | **RDS(MySQL 8.0)** + **TypeORM 0.3** + mysql2 | `package.json`, `src/app/api/dataSource.ts` |
| 패키지·빌드 | **pnpm 워크스페이스** + **Turbo** + Docker | `pnpm-workspace.yaml`, `turbo.json` |
| 레지스트리 | AWS ECR | CI 워크플로 |
| 컨테이너 포트 | **3000** | helm values |

> ⚠️ **1기(굿 메시지)만 데이터베이스가 Google Sheets** 입니다(README 기재). 이후 기수는 RDS 를 씁니다.

## 모노레포 구성

```
apps/good-wave/          # Next.js 앱 (유일한 app)
packages/
├── waffle/              #   4 파일 — styles · useMediaQuery 만 (사실상 껍데기)
├── waffle-icons/        # 278 파일 — 아이콘 컴포넌트 268개
└── artworks/            # 492 파일 — 아트웍 자산
```

- **`packages/waffle` 는 이름만 같을 뿐 `wadiz-frontend` 의 waffle 과 다릅니다.** 여기서는 `styles`·`useMediaQuery` 둘뿐입니다.
- `waffle-icons`·`artworks` 는 **`wadiz-frontend` 의 현행 자산을 복사해 오는 구조**입니다 — 2026-09-10 커밋 `509c1d7` 의 제목이 "waffle-icons·artworks를 wadiz-frontend 현행으로 교체" 입니다. 즉 **수동 동기화**이며, 자동 반영 장치는 확인되지 않았습니다.

## API 엔드포인트

Next.js Route Handler **9개**입니다 (`apps/good-wave/src/app/api/`).

| 경로 | 용도 |
|---|---|
| `auth/[...nextauth]` | NextAuth 인증 |
| `health` | 상태 확인 — helm 의 liveness·readiness probe 가 `/api/health` 를 봅니다 |
| `good-message/messages` · `good-message/message-count` | 1기 굿 메시지 |
| `best-buddy/questions` | 4기 문항 |
| `best-buddy/buddies` · `best-buddy/buddies/[buddyNo]` | 동료 목록·상세 |
| `best-buddy/buddy-groups` | 동료 그룹 |
| `best-buddy/statistics` | 통계 |
| `best-buddy/user/[userId]/buddy/[buddyNo]` | 사용자별 결과 |

- 페이지는 14개이고 그중 **9개가 4기(`best-buddy`)** 입니다. 최근 기수에 기능이 집중돼 있습니다.

### 인증 게이트 (`src/middleware.ts`)

- 보호 대상은 **`/best-buddy/buddy/:buddyNo/statistics` 한 경로뿐**입니다.
- 판정은 **`app.user` 쿠키의 존재 여부**로만 합니다. 없으면 `/best-buddy/auth/sign-in` 으로 `callbackUrl` 을 달아 리다이렉트합니다.
- 경로 매칭은 `:param` → `[^/]+`, `*` → `.*` 로 바꾼 정규식으로 직접 구현했습니다.

## 배포

### 브랜치 ↔ 환경 매핑

CI 워크플로가 **브랜치 이름을 환경 이름으로 번역**합니다 (`.github/workflows/event-good-wave-ci.yml`).

| 브랜치 | 환경(`environment`) | ECR 계정 |
|---|---|---|
| `cloud_dev` | **`cdev`** | `843734097580` |
| `cloud_live` | **`clive`** | `393290902814` |
| `dev` | `dev` | `843734097580` |
| `main` | **`live`** | `393290902814` |

- 이미지 태그는 `{환경}-{short sha 8자리}` 형식이고, AWS 인증은 **ECR 계정 번호로 role 을 골라 OIDC** 로 받습니다.
- 체크아웃은 **sparse-checkout**(`.github`·`apps/good-wave`·`packages`)으로 필요한 부분만 받습니다.
- ⚠️ **README 의 배포 안내가 현행과 어긋납니다.** README 는 "환경(dev/main) 브랜치에 병합하면 CI 를 트리거" 라고만 적었는데, 실제 워크플로는 **`cloud_dev`·`cloud_live` 두 클라우드 브랜치를 더 받습니다.** 기준 브랜치도 `cloud_live` 입니다.

### 쿠버네티스 배포 (helm)

| 환경 | 호스트 | 접근 허용 |
|---|---|---|
| dev | `good-wave.dev.wadiz.io` | **`192.168.200.0/24`(FE) 사내 대역만** |
| rc4 | `good-wave.rc4.wadiz.io` | **`192.168.200.0/24`(FE) 사내 대역만** |
| clive | `good-wave.wadiz.io` | `0.0.0.0/0`·`::/0` — **외부 공개** |

- 공통: `requestsMemory: 0.2Gi`(전 서비스 중 가장 작은 축) · `containerPort: 3000` · `rewriteUri: false` · `subPath: /` · probe 는 `/api/health`.
- 배포 스펙은 [`helm-charts`](./helm-charts.md), 이미지 태그·설정은 [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `client/{env}/good-wave-anyone-can-challenge.yaml` 에 있습니다.

> 🔎 **README 에 ArgoCD 콘솔 주소가 적혀 있습니다** — `https://argocd.dev.wadiz.io/applications` · `https://argocd.wadiz.io/applications`. 그리고 **"CI 이후 ArgoCD 에서 수동으로 배포"** 한다고 명시돼 있습니다. [`helm-charts`](./helm-charts.md)·[`helm-charts-gitops`](./helm-charts-gitops.md) 문서에 남긴 "ArgoCD Application 정의의 위치" 미확인 항목을 풀 실마리입니다(콘솔 접근 권한이 있으면 확인 가능).

## 최근 변경 (2026-09-10 · 6커밋)

전부 **도메인·환경을 클라우드(`wadiz.io`)로 옮기는 정리**입니다. 기능 변경은 없습니다.

| 커밋 | 내용 |
|---|---|
| `1bb9144` | **clive 데이터베이스 호스트를 `rds.wadiz.io` 로** 전환 |
| `35327eb` | CI 배포 환경 기본값을 **`cdev`** 로 변경 |
| `2c1c090` | 로컬 개발 호스트를 `wadiz.io` 로 전환 |
| `59be109` | 지면의 하드코딩 도메인을 `wadiz.io` 로 전환 |
| `509c1d7` | `waffle-icons`·`artworks` 를 `wadiz-frontend` 현행으로 교체 |
| `9f80221` | 문서·스토리북 설정의 도메인을 `wadiz.io` 로 전환 |

- 직전(2026-09-02)에는 **Next.js 16.3.3 업그레이드**가 있었습니다 — AVIF Image RCE 취약점(`GHSA-2xp9-vwfh-vxw4`) 대응으로, [`makercenter-fe`](./makercenter-fe.md) 의 FE2-1168 과 같은 건입니다.

## 저장소 안의 문서

| 파일 | 내용 |
|---|---|
| `README.md` | 소개·기술스택·기수별 구조와 URL·설치/실행·빌드/배포 |
| `CLAUDE.md` | 작업·탐색·코드·커밋 메시지·토큰 최적화 지침 |
| `GLOSSARY.md` · `NAMING_CONVENTIONS.md` | 용어 사전·네이밍 컨벤션 |

## 미확인 항목

- **각 기수 페이지가 지금도 살아 있는지** — 1~3기 캠페인이 종료됐는데 코드만 남아 있는지, 계속 서비스되는지는 코드로 알 수 없습니다.
- **`packages/waffle-icons`·`artworks` 의 동기화 주기** — `wadiz-frontend` 에서 복사해 오는 구조인데 언제·누가 맞추는지 자동 장치가 없습니다.
- 1기의 Google Sheets 연동이 **아직 동작하는지** — README 에 시트 링크만 있고 코드 경로는 이번 범위에서 확인하지 않았습니다.
- 테스트가 없습니다(루트 `package.json` 의 `test` 스크립트가 `exit 1`).
- clive 의 실제 DB 접속·NextAuth Google 자격증명 등 운영 설정 — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `client/clive/good-wave-anyone-can-challenge.yaml` `configmap.data` 참조.
