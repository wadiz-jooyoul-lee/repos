# wadiz-claude-plugins

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
| command | `analytics-test` | 애널리틱스 테스트 실행 |
| command | `check-release` | 릴리즈 사전 점검 |
| command | `scheduled-deploy` | 예약 배포 |
| command (sub) | `workflow/*` | 워크플로우 묶음 (5개 하위 커맨드 + scripts/) |

### `wadiz-client` (클라이언트 직속, 모바일)
| 종류 | 이름 | 목적 |
|---|---|---|
| skill | `regular-release` | 정기 릴리즈 절차 자동화 |
| skill | `release-branch-check` | 릴리즈 브랜치 상태 점검 |
| skill | `example` | 템플릿 예제 |

## 플러그인 추가 방법

1. `templates/plugin-template/` 복사 → `plugins/<team>/` 하위 적절한 폴더에 배치 또는 새 컴포넌트 추가.
2. 각 팀의 `.claude-plugin/plugin.json` 의 `skills`/`commands` 경로 갱신.
3. 루트 `.claude-plugin/marketplace.json` 에 신규 플러그인 등록(필요 시 — 보통 팀 단위 단일 플러그인이므로 추가 컴포넌트만 추가).
4. 팀 독립 변경은 팀 내부 승인, `shared/` 변경은 2팀 이상 승인 권장.

## 팀별 특화 분석

- **fe2** 가 압도적으로 많은 skill 보유 (11개) — *품질·기획·검증* 영역을 모두 스킬화: 기획(planner) → 구현(tdd, semantic-html) → 검증(a11y, e2e-verifier, analytics-verifier, lint-review) → 자가비평(critic, grill-me) → 운영(seo-geo-optimizer, architecture). FE2 팀이 *프로세스 자체를 도구로 코드화* 하는 문화로 추정.
- **fe1** 은 도메인 특화(기획전 콘텐츠 생성) 1개 — 더 좁은 책임.
- **client (모바일)** 은 릴리즈 운영 자동화에 집중 (regular-release, release-branch-check).
- **shared** 의 `dev-db-query` 는 모든 팀이 데이터 조회를 자주 한다는 신호.

## 특이사항

- 마켓플레이스 진입점은 `.claude-plugin/marketplace.json`, `pluginRoot: "./plugins"` 이라 `source: "./shared"` ↔ 실제 `./plugins/shared`.
- 플러그인 매니페스트(`plugin.json`)는 `commands` `agents` `hooks` `mcpServers` `lspServers` 모두 선택 — 팀 자유도가 높음.
- 모바일(`client/`)에 `commands/` 가 없는 이유: 릴리즈 워크플로를 skill로 내장.
- 신규 플러그인은 `templates/plugin-template/` 복사 → 명세 갱신만으로 등록 가능.
