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
| [com.wadiz.api.reward](./docs/com.wadiz.api.reward/) | 리워드 수집·쿠폰·만족도·메모 — **심층 분석 (6파일, 2.7K줄)** | Boot 2.x / Java 8 / MyBatis |
| [com.wadiz.api.startup](./docs/com.wadiz.api.startup.md) | 투자형(증권형) 스타트업 투자 API | Boot 2.3 / Java 8 / JPA+MyBatis+ES |
| [co.wadiz.api.community](./docs/co.wadiz.api.community/) | `wave.user`의 Signature V3 신규 리라이트 + 커뮤니티 — **Phase 6 v1.3.0 풀 구현 (37 endpoint, 포트 9011)** | **Boot 4.0 / Java 25** (최신) |
| [co.wadiz.currency-exchange](./docs/co.wadiz.currency-exchange.md) | 환전 서버 (OpenSearch 기반, dev 브랜치) | Boot 3.4 / Java 21 / OpenSearch |
| [co.wadiz.fep](./docs/co.wadiz.fep.md) | ⚠️ Front-End *Processor* (결제·Stripe 대외계, FE 아님!) | Boot 3.4 / Java 21 / Hexagonal |
| [nicepay-api](./docs/nicepay-api.md) | 나이스페이·Stripe·Alipay+ PG 연동 | Boot 3 / Java 17 / WebFlux + R2DBC |
| [kr.wadiz.account](./docs/kr.wadiz.account/) | OAuth2 인가서버 + 계정 (Auth 2.0) — **심층 분석 (7파일, 4.5K줄)** | Boot 3.1 / Kotlin + Java 17 |
| [kr.wadiz.user.link](./docs/kr.wadiz.user.link.md) | Neo4j 기반 유저 관계 그래프 (userplatform/link) | Boot 3 / Java 17 / Neo4j + Kafka |
| [com.wadiz.wave.searcher](./docs/com.wadiz.wave.searcher.md) | `service.wadiz.kr` 검색 서버 (`/api/search/v2/*`, 카테고리/통합/탭별 검색) | Boot 2.1 / Java 8 / **ElasticSearch 7.x + JPA**(MySQL master/slave) |
| [com.wadiz.wave.user](./docs/com.wadiz.wave.user/) | 레거시 Wave User 모놀리식 API — **심층 분석 (8파일, 4.9K줄, 58 컨트롤러)** | Boot 구버전 / Java 8 / MyBatis |

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
| [wadiz-frontend](./docs/wadiz-frontend/) | 전(全) FE 통합 모노레포 (account/global/help-center/ir/partners/…) — **심층 분석 (6파일, 3.9K줄)** | Next.js + Vite / pnpm + turbo |

## 4. `wadiz-web` — 레거시 코어

| Repo | 역할 | 스택 |
|---|---|---|
| [com.wadiz.web](./docs/com.wadiz.web/) | www.wadiz.kr 본체 (레거시 FE+BE) — `wadiz-frontend`로 점진 이관 중 — **심층 분석 (8파일, 447 JSP / 303 controller / 264 mapper)** | Spring 3.2 / Java 8 / WAR |
| [com.wadiz.adm](./docs/com.wadiz.adm/) | 전사 레거시 어드민 (JSP) — **심층 분석 (7파일, 1.8K줄, 197 컨트롤러)** | Spring 3.2 / JSP / Maven WAR |

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

---

## ⚠️ 분석 시 주의사항 — 필드/응답 사용처 추적 가이드

BE 응답 필드(예: `userStatus`, `payStatus`, `state` 코드)가 FE/타 BE에서 어떻게 쓰이는지 추적할 때, **도메인 폴더와 raw 타입명만으로 grep하면 사용처를 놓치는 경우가 많습니다.** 다음 5가지를 반드시 함께 검색합니다.

### 1. 검색 범위를 도메인 폴더로 한정하지 말 것
- 응답 도메인(예: `signature/`, `support-share/`)에서만 grep하면, **다른 피처 폴더가 그 응답을 소비**하는 경우 누락됨.
- 예: 지지서명 댓글 응답(`/api/v3/supporter-signatures/{id}/comments`)의 `userStatus` 가 `packages/features/src/comments/lib/adapter/rewardSignatureCommentAdapter.js` 에서 변환됨 — `signature` 폴더 안에는 없음.
- **방어법**: 한 응답에 여러 엔드포인트가 있으면 응답별로 컨슈머 폴더가 다를 수 있다고 가정. 첫 grep은 repo 루트에서 전역으로.

### 2. 어댑터/변환 레이어가 raw 타입을 가린다
- FE는 응답을 어댑터에서 **파생 플래그**로 변환해 UI에 흘림. 코드 코드(NM/IA/DO, A10/B10 등)는 거의 항상 boolean 또는 enum 으로 1단계 변환됨.
- 흔한 변환 패턴:
  - `userStatus === 'NM'` → `isNormal`
  - `userStatus !== 'NM'` → `isWithdrawn` / `isInactive`
  - `payStatus === 'A10' || 'B10'` → `isRequiredMasking`
- **방어법**: 타입명(`SignatureUserV3` 등)으로 컨슈머를 찾았으면, **그 타입을 import하지 않는 어댑터 파일**까지 후속 grep. 어댑터 디렉터리(`*/adapter/`, `*/lib/`) 별도 스캔.

### 3. 값 자체와 파생 플래그명도 grep 키워드에 포함
- 필드명 `userStatus` 만으로는 부족. 다음을 모두 한 번씩:
  - 값 리터럴: `'NM'`, `'IA'`, `'DO'`, `'A10'`, `'B10'`
  - 흔한 파생명: `isNormal`, `isWithdrawn`, `isDormant`, `isMasked`
  - 한국 서비스 도메인 코드의 변환 관행: NM=정상, IA=휴면(Inactivated), DO=탈퇴(DropOut), A10=결제예약, B10=결제실패.
- **방어법**: 값 리터럴 grep을 1차로 돌려 사용처 군집을 먼저 본 뒤, 그 군집 안에서 필드명 검색.

### 4. spec/매퍼 문서의 "조인 포함" 힌트를 응답 식별 단서로 사용
- `docs/<repo>/api-details/*.md` 의 SQL 발췌에서 `LEFT JOIN UserProfile` / `UP.UserStatus` 같은 표현이 보이면 **그 엔드포인트 응답에도 userStatus 가 포함**된다는 신호.
- 본 응답 DTO뿐 아니라 **댓글·리스트·서브엔티티 응답** 도 같은 필드를 들고 나갈 수 있음.
- **방어법**: spec 문서의 SQL 섹션에서 조인되는 외부 컬럼을 먼저 훑고, 해당 컬럼이 채워지는 모든 엔드포인트를 후보 목록에 올림.

### 5. Subagent 보고는 같은 가정으로 재검증하지 말 것
- Subagent가 "사용처 없음" 이라고 답하면, **다른 검색 전략**(다른 키워드, 다른 폴더 범위)으로 재검증. 같은 grep을 직접 다시 돌리는 건 동일 사각지대를 그대로 둠.
- **방어법**: Subagent의 검색 키워드와 다른 축(파생 플래그 / 값 리터럴 / 어댑터 폴더) 으로 한 번 더 확인.

### 체크리스트 (응답 필드 사용처 추적 시)
- [ ] BE: 해당 필드가 포함된 **모든 응답 DTO/엔드포인트** 식별 (단일 DTO라고 가정 금지)
- [ ] FE: 응답 타입명 grep + **값 리터럴 grep** + **파생 플래그명 grep** 3종 모두 실행
- [ ] 어댑터 레이어(`*/adapter/`, `*/transform/`, `*/mapper/`) 별도 확인
- [ ] 도메인 폴더 외부 (`comments/`, `feed/`, `profile/` 등 횡단 피처)도 스캔
- [ ] BE 내부의 entity/helper 단계 가공도 확인 (예: `*Entity.getPhotoUrl()` 같은 getter 안 분기)
