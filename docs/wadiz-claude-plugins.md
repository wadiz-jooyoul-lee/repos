# wadiz-claude-plugins

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

**분석 갱신일: 2026-06-19** (최초: 2026-04-20)

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
