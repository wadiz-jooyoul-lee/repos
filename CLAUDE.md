# Wadiz Repos 이정표

이 디렉터리는 Wadiz(와디즈, 한국 크라우드펀딩) 개발 repo들을 모아둔 루트 폴더입니다. 각 repo의 소속 GitHub org과 역할은 아래와 같으며, 상세 분석은 [`docs/<repo>.md`](./docs/) 에 있습니다.

## Org 지도

| Org | 성격 | 비고 |
|---|---|---|
| `wadiz-service` | 백엔드 도메인 서비스 (JVM/Spring) | 펀딩·리워드·스타트업·결제·계정 등 코어 |
| `wadiz-client` | 클라이언트팀 (BFF / 메이커센터 / 도구) | NestJS, CRA/Vite 중심 |
| `wadiz-fe` | 신규 프론트엔드 모노레포 | Next.js + pnpm/turbo |
| `wadiz-web` | 레거시 코어 웹 + 어드민 | Spring 3.2 + JSP |
| `wadiz-app` | 공식 모바일 앱 | Kotlin / Swift |

---

## 1. `wadiz-service` — 백엔드 서비스

| Repo | 역할 | 스택 |
|---|---|---|
| [com.wadiz.api.funding](./docs/com.wadiz.api.funding/) | 크라우드펀딩 코어 API (주문·서포터·리워드결제·자동결제·스토어) — **심층 분석 (11파일, 6.5K줄)** | Boot 2.7 / Java 8 / Hexagonal + MyBatis + Mongo + Redis |
| [com.wadiz.api.reward](./docs/com.wadiz.api.reward.md) | 리워드 수집·쿠폰·만족도·메모 | Boot 2.x / Java 8 / MyBatis |
| [com.wadiz.api.startup](./docs/com.wadiz.api.startup.md) | 투자형(증권형) 스타트업 투자 API | Boot 2.3 / Java 8 / JPA+MyBatis+ES |
| [co.wadiz.api.community](./docs/co.wadiz.api.community.md) | `wave.user`의 Signature V3 신규 리라이트 + 커뮤니티 | **Boot 4.0 / Java 25** (최신) |
| [co.wadiz.currency-exchange](./docs/co.wadiz.currency-exchange.md) | 환전 서버 (OpenSearch 기반, dev 브랜치) | Boot 3.4 / Java 21 / OpenSearch |
| [co.wadiz.fep](./docs/co.wadiz.fep.md) | ⚠️ Front-End *Processor* (결제·Stripe 대외계, FE 아님!) | Boot 3.4 / Java 21 / Hexagonal |
| [nicepay-api](./docs/nicepay-api.md) | 나이스페이·Stripe·Alipay+ PG 연동 | Boot 3 / Java 17 / WebFlux + R2DBC |
| [kr.wadiz.account](./docs/kr.wadiz.account.md) | OAuth2 인가서버 + 계정 (Auth 2.0) | Boot 3.1 / Kotlin + Java 17 |
| [kr.wadiz.user.link](./docs/kr.wadiz.user.link.md) | Neo4j 기반 유저 관계 그래프 (userplatform/link) | Boot 3 / Java 17 / Neo4j + Kafka |
| [com.wadiz.wave.user](./docs/com.wadiz.wave.user/) | 레거시 Wave User 모놀리식 API — **심층 분석 진행 중 (57 컨트롤러)** | Boot 구버전 / Java 8 / MyBatis |

## 2. `wadiz-client` — 클라이언트팀

| Repo | 역할 | 스택 |
|---|---|---|
| [app-api](./docs/app-api.md) | 앱용 BFF (와링크·프로젝트 스토리 캐시·프록시) | NestJS 11 / TS / TypeORM |
| [makercenter-be](./docs/makercenter-be.md) | 메이커센터 백엔드 (프로젝트 관리·정산·엑셀) | Boot 2.7 / Java 8 / MyBatis |
| [makercenter-fe](./docs/makercenter-fe.md) | 메이커(프로젝트 개설자) 포털 | React + Vite / MUI / RTK |
| [makercenter-fe-admin](./docs/makercenter-fe-admin.md) | 메이커센터 어드민 (admin.makercenter) | React + CRA / MUI / RTK |
| [client-document](./docs/client-document.md) | 클라이언트팀 기술/분석 문서 저장소 | Markdown |
| [wadiz-claude-plugins](./docs/wadiz-claude-plugins.md) | 사내 Claude Code 플러그인 마켓 (shared/fe1/fe2/client) | CC plugin spec |
| [figma-icon-sync](./docs/figma-icon-sync.md) | Figma WDS → Android/iOS 아이콘 자동 PR | Python + GH Actions |

## 3. `wadiz-fe` — 신규 FE 모노레포

| Repo | 역할 | 스택 |
|---|---|---|
| [wadiz-frontend](./docs/wadiz-frontend.md) | 전(全) FE 통합 모노레포 (account/global/help-center/ir/partners/…) | Next.js + Vite / pnpm + turbo |

## 4. `wadiz-web` — 레거시 코어

| Repo | 역할 | 스택 |
|---|---|---|
| [com.wadiz.web](./docs/com.wadiz.web.md) | www.wadiz.kr 본체 (레거시 FE+BE) — `wadiz-frontend`로 점진 이관 중 | Spring 3.2 / Java 8 / WAR |
| [com.wadiz.adm](./docs/com.wadiz.adm.md) | 전사 레거시 어드민 (JSP) | Spring 3.2 / JSP / Maven WAR |

## 5. `wadiz-app` — 모바일

| Repo | 역할 | 스택 |
|---|---|---|
| [wadiz-android](./docs/wadiz-android.md) | 공식 Android 앱 | Kotlin / Compose / 멀티모듈 |
| [wadiz-ios](./docs/wadiz-ios.md) | 공식 iOS 앱 (Android와 feature 1:1 매핑) | Swift / Tuist / iOS 16.1+ |

---

## 네이밍·세대 관찰

- **Java 패키지 prefix가 repo 이름**: `com.wadiz.*`(레거시 상용 플랫폼) / `kr.wadiz.*`(국내 인프라) / `co.wadiz.*`(신규 리라이트).
- **백엔드 세대**: Boot 2.x + Java 8 + MyBatis(레거시) → Boot 3 + Java 17/21 + Kotlin → **Boot 4 + Java 25**(community).
- **FE 세대**: JSP/Spring(`com.wadiz.web`, `com.wadiz.adm`) → CRA SPA(`makercenter-fe*`) → Next.js 모노레포(`wadiz-frontend`).
- **⚠️ 주의**: `co.wadiz.fep`는 프론트엔드가 아니라 Front-End *Processor* (결제 대외계 백엔드).
