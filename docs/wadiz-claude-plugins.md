# wadiz-claude-plugins

> 📅 **2026-08-21 main pull 보강** (10 커밋)
>
> ### [Shared] `cloud-db-query` 스킬 신설 — 클라우드 DB 접속 정보 단일 원천
> - 클라우드 환경(cdev / rc4)의 MySQL RDS 에 쿼리를 실행하는 스킬을 새로 만들고, **클라우드 DB 접속 정보의 단일 원천**으로 삼았습니다 (`plugins/shared/skills/cloud-db-query/SKILL.md` 210줄). 참고 문서로 AWS SSO 설정(`references/aws_sso_setup.md` 121줄), 클라우드 스키마 차이(`references/cloud_schema_delta.md` 49줄), 접속 정보(`references/connections.json` 84줄)를 동봉했습니다.
> - `create-project-v2` 가 이 스킬에 DB 접속을 위임하도록 정리했습니다 (`plugins/shared/skills/create-project-v2/SKILL.md`).
>
> ### [FE2] `commit` + `review-to-pr` → `commit-pr` 통합 (FE2-851)
> - 기존 `commit`(250줄)·`review-to-pr`(253줄 + `references/review-process.md` 104줄) 두 스킬을 삭제하고 **`commit-pr`(499줄) 하나로 통합**했습니다. `references/pr-creation.md` 는 새 스킬 아래로 이동·정리. fe2 플러그인 매니페스트 버전과 `hooks/hooks.json` 도 함께 갱신.
>
> ### [Client] `regular-release` 문서 정비 (0.5.11 → 0.5.12)
> - 배포 담당자 cc 정책과 인수 시 `deployer` 갱신 규칙을 정리하고, CI/CD 트리거에 `environment` 인자를 명시하는 규칙을 강조했습니다. 배포 시작 메시지 문구를 개선하고 강조 표현을 중립 톤으로 정리했습니다 (`plugins/client/skills/regular-release/SKILL.md` 대폭 개정, `README.md`, `release-branch-check/SKILL.md`).
>
> ### [FE1] `figma-node-index` 에 Dev Mode 주석·숨김 노드 처리 추가 (0.1.2)
> - Figma Dev Mode 주석과 숨김 노드를 다루는 절차를 스킬에 추가했습니다 (`plugins/fe1/skills/figma-node-index/SKILL.md`).
>
> ### 저장소 공통
> - `WRITING_CONVENTIONS.md`·`CLAUDE.md` 작성 컨벤션을 정비하고 client 플러그인 문서에 적용했습니다. `marketplace.json` 항목도 함께 갱신.
>
> ---
>
> 📅 **2026-07-31 main pull 보강** (4 커밋)
>
> ### [Shared] `create-store-project` 스킬 신설
> - 라이브(`www.wadiz.kr`) **스토어 프로젝트**를 공개 API로 수집해 대상 환경(dev/rc1/rc2)의 `wadiz_store` DB에 직접 INSERT하여 **판매중(ON_SALE) 스토어 프로젝트**를 만드는 테스트 데이터 스킬. 기존 펀딩 스킬 `create-project`의 "API 수집 → DB 적재(FK 순서·LAST_INSERT_ID·트랜잭션)" 패턴을 스토어로 이식했다. RC2 정상 프로젝트 852(MARKETPLACE, ON_SALE)를 역설계한 시그니처와 1:1 동일 생성을 목표로 한다 (`plugins/shared/skills/create-store-project/SKILL.md` 341줄 + `references/config.json` 46줄).
> - **이전 펀딩 연결/미연결** 선택(미연결=MARKETPLACE·`campaign_id` NULL / 연결=대상 환경 캠페인 존재 확인 후 `project_base_funding` 채움). 상세는 URL 직접 진입 시 정상이나 목록/검색/기획전은 ES 색인 기반이라 직접 INSERT는 미노출될 수 있음을 결과에 안내. 이미지는 상대 key만 저장(환경별 CDN 상이)하고 presign 업로드에 메이커 로그인 세션 필요. DB 접속정보는 글로벌 `~/.claude/CLAUDE.md` 참조(파일 미저장).
>
> ### [Shared] `create-project` 라이브 복제 누락 데이터 보완
> - 리워드 조회 엔드포인트 파라미터 정정: `country` → **`shippingCountry`** + `isPreview=false` 필수, host 는 `www`(=`stage` 는 400). `RewardImage`(리워드 대표 이미지 `featuredImageUrl`)·`CampaignAutoOpen`(coming-soon 오픈 예정일 소스 `Scheduled`) INSERT 블록과 `categoryCode` 매핑 추가. `imageUrls` 는 모든 state 에서 `liveThumbnailUrl` 을 0번 인덱스로 통일해 카드 썸네일이 인트로 첫 장(GIF 등)으로 잘못 노출되는 문제 방지.
>
> ### [Client·Shared] 버전 bump 및 매니페스트 경로 정리
> - `wadiz-client` 플러그인 버전 0.5.8 → **0.5.9**, 존재하지 않는 `"commands": "./commands/"` 경로 제거(`plugins/client/.claude-plugin/plugin.json`). `wadiz-shared` 매니페스트 0.4.2 → **0.4.4**, marketplace 의 shared 항목 0.2.0 → **0.2.2**.
>
> ---

> 📅 **2026-07-10 pull 보강** (2 커밋, feature/supporter-e2e-testid-skill)
>
> ### [FE1] `supporter-e2e-testid` 스킬 신설
> - 와디즈 서포터 E2E용 `data-testid` 추가·전환·동기화 스킬. 기능을 받아 FE 코드에서 요소를 찾아 testid를 부여하고 그 testid로 Page Object를 작성하며, 신규 PO의 취약 셀렉터(class·text·role)를 testid로 전환한다. testid SSOT는 FE(`wadiz-frontend`)이며 국내(`web-test-automation`)·글로벌(`web-test-automation-global`) 3개 repo를 동일 문자열로 동기화한다. `disable-model-invocation: true`로 `/supporter-e2e-testid` 수동 호출 전용 (`plugins/fe1/skills/supporter-e2e-testid/SKILL.md`).
> - 진입 모드 3종(A 엘리먼트 명시 / B 기능 기술 / C 신규 PO 전환)과 Phase 0 3개 repo 존재 확인 절차를 정의. references/에 작명 규칙(`naming-convention.md`), 라우터 분리 기반 FE 소스 판정(`serving-map.md`), strict mode 중복 점검(`strict-mode-audit.md`), FE1-927 전수 전환 선례(`conversion-history/` — 도메인별 섹션 12개 + 와플 prop 주입 가이드) 동봉 (총 16파일 약 2,086줄).
> - fe1 플러그인 매니페스트 버전 0.1.1 → **0.3.0** bump (`plugins/fe1/.claude-plugin/plugin.json`).
>
> ---

## 개요
와디즈 **클라이언트개발팀(FE개발1팀, FE개발2팀, 클라이언트 직속)**이 Claude Code 플러그인을 공유·배포·재사용하는 마켓플레이스 저장소입니다. Org: `wadiz-client`.

설치 흐름:
```
/plugin marketplace add https://github.com/wadiz-client/wadiz-claude-plugins
/plugin install <plugin-name>@wadiz-claude-plugins
/plugin marketplace update
```

## 저장소 구조

```
.claude-plugin/marketplace.json   # 마켓플레이스 진입점 (pluginRoot=./plugins)
plugins/
├── shared/   # wadiz-shared (공통)
├── fe1/      # wadiz-fe1 (FE개발1팀)
├── fe2/      # wadiz-fe2 (FE개발2팀)
└── client/   # wadiz-client (클라이언트 직속)
templates/
└── plugin-template/   # 새 플러그인 부트스트랩 템플릿
```

각 팀 폴더에는 `.claude-plugin/plugin.json` 매니페스트 + `skills/` `commands/` `agents/` `hooks/` 가 자유롭게 배치됩니다.

## 플러그인 카탈로그

### `wadiz-shared` (공통)
| 종류 | 이름 | 목적 |
|---|---|---|
| skill | `dev-db-query` | 개발 DB 직접 조회 (사내 DB 접속 헬퍼) |
| skill | `create-project` | 펀딩 프로젝트 생성 — 라이브 캠페인을 API로 수집해 대상 환경 DB에 직접 INSERT (진행중/오픈예정/종료 테스트 데이터) |
| skill | `create-store-project` | 스토어 프로젝트 생성 — 라이브 스토어 프로젝트를 API로 수집해 대상 환경 `wadiz_store` 에 직접 INSERT (판매중 ON_SALE, 이전 펀딩 연결/미연결 선택) |
| skill | `example` | 템플릿 예제 |

### `wadiz-fe1` (FE개발1팀)
| 종류 | 이름 | 목적 |
|---|---|---|
| skill | `generate-exhibition-content` | 기획전 콘텐츠 자동 생성 |
| skill | `figma-node-index` | Figma REST API 직접 호출로 노드/레이어 계층을 스파스 JSON 인덱스 추출 + 디자인 가이드 MD 자동 생성 (`scripts/fetch_nodes.sh`, `parse_nodes.py`, MCP get_metadata보다 빠름) |
| skill | `prd-diagnose` | PRD 정보 충분성 진단 (Why/What/Verify/Risk 4축, 진단 결과를 원본 PRD 자식 페이지로 생성·본문 미수정) |
| skill | `example` | 템플릿 예제 |

### `wadiz-fe2` (FE개발2팀) — 가장 풍부
| 종류 | 이름 | 목적 |
|---|---|---|
| skill | `a11y` | 웹접근성(WCAG) 검토 |
| skill | `analytics-verifier` | GA/Analytics 이벤트 누락 검증 |
| skill | `architecture` | 아키텍처 리뷰 |
| skill | `critic` | 코드/계획 비평 |
| skill | `e2e-verifier` | E2E 시나리오 누락 점검 |
| skill | `grill-me` | 자가 코드 인터뷰 (취약점 발굴) |
| skill | `lint-review` | 린트 위반 정리 |
| skill | `planner` | 구현 플랜 수립 |
| skill | `semantic-html` | 시맨틱 HTML 점검 |
| skill | `seo-geo-optimizer` | SEO + 지역화 최적화 |
| skill | `tdd` | 테스트 주도 개발 가이드 |
| skill | `commit` | Git 커밋 메시지 작성 (한국어 명령형, `이슈번호 type: 제목` 형식) |
| skill | `review-to-pr` | 리뷰 → 커밋 → PR 올인원 (각 단계에서 `/simplify`+`/review` 자동 수행) |
| skill | `jira-markdown-format` | Jira 본문을 표준 마크다운+`contentFormat:"markdown"`으로 작성해 wiki 마크업 깨짐 방지 (FE2-506) |
| skill | `meta-harness` | 하네스(CLAUDE.md/SKILL.md/agents/commands/hooks) 결함을 full-trace experience store로 진단·개선하는 메타 오케스트레이터 (FE2-475) |
| skill | `causal-diagnosis` / `pareto-refinement` / `session-signal-capture` | meta-harness 보조 스킬 (인과 진단·Pareto 개선·세션 신호 캡처) |
| command | `analytics-test` | 애널리틱스 테스트 실행 |
| command | `check-release` | 릴리즈 사전 점검 |
| command | `scheduled-deploy` | 예약 배포 |
| command | `meta-harness` | meta-harness 진입 커맨드 (FE2-475) |
| command (sub) | `workflow/*` | 워크플로우 묶음 (5개 하위 커맨드 + scripts/) |
| agent | `experience-historian` / `failure-diagnostician` / `pareto-refiner` / `trace-capturer` | meta-harness 전용 서브에이전트 (FE2-475) |
| hook | `jira-format-guard.py` | PreToolUse 가드 — Jira 이슈/댓글 wiki 마크업 차단 (FE2-506) |
| hook | `incremental-lint.sh` | PostToolUse 훅 — Edit/Write 직후 해당 파일만 lint (전체 재lint 중복 제거) |

### `wadiz-client` (클라이언트 직속, 모바일)
| 종류 | 이름 | 목적 |
|---|---|---|
| skill | `regular-release` | 정기 릴리즈 절차 자동화 (진행 중 배포를 다른 담당자에게 넘기는 **인계/인수(take-over)** 기능 포함 — 인계자는 멈추지 않고 진행하다 인수 완료 메시지 감지 시 자동 중단) |
| skill | `release-branch-check` | 릴리즈 브랜치 상태 점검 |
| skill | `example` | 템플릿 예제 |

## 플러그인 추가 방법

1. `templates/plugin-template/` 복사 → `plugins/<team>/` 하위 적절한 폴더에 배치 또는 새 컴포넌트 추가.
2. 각 팀의 `.claude-plugin/plugin.json` 의 `skills`/`commands` 경로 갱신.
3. 루트 `.claude-plugin/marketplace.json` 에 신규 플러그인 등록(필요 시 — 보통 팀 단위 단일 플러그인이므로 추가 컴포넌트만 추가).
4. 팀 독립 변경은 팀 내부 승인, `shared/` 변경은 2팀 이상 승인 권장.

## 팀별 특화 분석

- **fe2** 가 압도적으로 많은 skill 보유 — *품질·기획·검증* 영역을 모두 스킬화: 기획(planner) → 구현(tdd, semantic-html) → 검증(a11y, e2e-verifier, analytics-verifier, lint-review) → 자가비평(critic, grill-me) → 운영(seo-geo-optimizer, architecture) → 협업 자동화(commit, review-to-pr, jira-markdown-format). 최근에는 **하네스 자체를 진단·개선하는 메타 도구(meta-harness)** 까지 추가되어, *프로세스뿐 아니라 도구화 인프라 자체를 코드화* 하는 단계로 진화 중.
- **fe1** 은 디자인·기획 단계 도구로 확장 — 기획전 콘텐츠 생성에 더해 Figma 노드 인덱스 추출(`figma-node-index`), PRD 충분성 진단(`prd-diagnose`)으로 *개발 착수 전 단계* 를 보강.
- **client (모바일)** 은 릴리즈 운영 자동화에 집중 (regular-release, release-branch-check).
- **shared** 의 `dev-db-query` 는 모든 팀이 데이터 조회를 자주 한다는 신호.

## 특이사항

- 마켓플레이스 진입점은 `.claude-plugin/marketplace.json`, `pluginRoot: "./plugins"` 이라 `source: "./shared"` ↔ 실제 `./plugins/shared`.
- 플러그인 매니페스트(`plugin.json`)는 `commands` `agents` `hooks` `mcpServers` `lspServers` 모두 선택 — 팀 자유도가 높음.
- 모바일(`client/`)에 `commands/` 가 없는 이유: 릴리즈 워크플로를 skill로 내장.
- 신규 플러그인은 `templates/plugin-template/` 복사 → 명세 갱신만으로 등록 가능.

---

## 최근 변경사항

**분석 갱신일: 2026-07-31** (최초: 2026-04-20)

| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| [Shared] create-project 통합 스킬 신설 (3개 스킬 통합) | 2026-04-29 | - |
| [Client] regular-release 스킬 대규모 개선 (체크포인트·이어하기·시간기반 CI·자동대기) | 2026-05-07 | - |
| [FE2] FE 개발 workflow 스킬 추가 (Review·Verify 단계 분리) | 2026-05-06~12 | FE2-180 |
| [Shared] create-project 정상 프로젝트 시그니처 1:1 일치 (submit-approval 보강) | 2026-05-13 | - |
| [Client] regular-release 서비스 식별자 수정 (com.wadiz.adm → co.wadiz.adm) | 2026-05-07 | - |
| [FE2] `commit`·`review-to-pr` 스킬 추가 (커밋 메시지 작성 + 리뷰→커밋→PR 올인원) | 2026-05-12 | FE2-371 |
| [FE1] `figma-node-index` 스킬 추가 (Figma REST API 노드 인덱스 추출) + fe1 플러그인 0.1.1 bump | 2026-06-10 | - |
| [FE1] `prd-diagnose` 스킬 추가 (PRD 정보 충분성 진단) | 2026-06-10 | FE1-874 |
| [FE2] `meta-harness` 하네스 엔지니어링 플러그인 추가 (스킬 4 + 커맨드 + 에이전트 4) | 2026-06-08 | FE2-475 |
| [FE2] `jira-markdown-format` 스킬 + Jira 포맷 가드 훅(`jira-format-guard.py`) 추가 | 2026-06-11 | FE2-506 |
| [FE2] 플러그인 경로·MCP 도구·훅·문구 정합성 보정 + `incremental-lint.sh` 훅 / marketplace fe2 버전 라벨 0.3.0 동기화 | 2026-06-15 | FE2-534 |
| [Client] regular-release **인계/인수(take-over)** 기능 추가 | 2026-06-16 | - |
| [Shared] `create-store-project` 스킬 신설 (라이브 스토어 프로젝트 API 수집 → `wadiz_store` 직접 INSERT, ON_SALE) | 2026-07-31 | - |
| [Shared] `create-project` 라이브 복제 누락 데이터 보완 (RewardImage·CampaignAutoOpen·categoryCode·rewards 엔드포인트 파라미터 정정) | 2026-07-31 | - |
| [Client] wadiz-client 0.5.8 → 0.5.9 + 매니페스트 미존재 `commands` 경로 제거 | 2026-07-31 | - |
