# figma-icon-sync

## 개요
Figma 디자인 시스템(WDS)의 **시스템 아이콘** + **아트웍 아이콘** 두 파일을 매일 1회 자동으로 끌어와 SVG/PDF/XML(Android Vector Drawable)로 변환·저장하고, `wadiz-android` / `wadiz-ios` 두 앱 repo에 자동 PR을 생성하는 동기화 도구입니다. Org: `wadiz-client`.

소스 Figma 파일:
- WDS / 마스터(시스템 아이콘) — `kpBfu27ikBmdNzUWpcg2v4`
- WDS / 아트웍 — `Jlat3mPH5ADTVaSEOLSuxU`

## 아키텍처

```
[Figma API]
   │  (REST, FIGMA_PAT 인증)
   ▼
fetch_figma_icons.py  (Python aiohttp + requests)
   │
   ├── assets/svg/  ──► (Android Vector 변환) android/ 서브프로젝트(Gradle)
   │                         │
   │                         ▼
   │                   assets/xml/   ──rsync──► wadiz-android (core/design-system/.../res/drawable)
   │                                                   │
   │                                                   ▼  gh pr create  ──►  PR  ──► develop
   │
   └── assets/pdf/  ──rsync──► wadiz-ios (Assets.xcassets/Images/{system,artwork}.imageset)
                                          (Contents.json 자동 생성, preserves-vector-representation: true)
                                                   │
                                                   ▼  gh pr create  ──►  PR
```

## 워크플로 상세

| 워크플로 | 트리거 | 역할 |
|---|---|---|
| `fetch-figma-icon.yml` | cron `0 23 * * 0-4` (한국시간 평일 08시) + workflow_dispatch | Figma → `assets/svg`, `assets/pdf` 다운로드, 변경된 파일 목록을 `GITHUB_ENV` 로 전달 |
| `convert-svg-to-drawable.yml` | `workflow_run` (fetch 성공 후) | `android/` Gradle `convertSvgToVector` 실행, SVG → `assets/xml` 생성 |
| `create-android-pr.yml` | `workflow_run` (convert 성공 후) | `wadiz-app/wadiz-android` 의 `core/design-system/.../res/drawable/` 로 rsync, `icon/add-system-icon` 브랜치 생성 후 base `develop` 으로 PR |
| `ios-icon-update.yml` | `workflow_run` 또는 수동 | `wadiz-app/wadiz-ios` 의 `Projects/Core/Sources/UI/Resources/Assets.xcassets/Images/{system,artwork}` 로 PDF + Contents.json 배포 후 PR |
| `test.yml` | PR/커밋 검증용 | 스크립트 sanity check |

> 모든 워크플로는 **self-hosted macOS arm64 러너**에서 동작합니다 (Android Gradle/Vector 변환과 iOS xcassets 처리 모두 macOS 기반이라).

## Consumer 경로

| Consumer Repo | 경로 | 브랜치 |
|---|---|---|
| `wadiz-app/wadiz-android` | `core/design-system/src/main/res/drawable/` | base: `develop`, head: `icon/add-system-icon` |
| `wadiz-app/wadiz-ios` | `Projects/Core/Sources/UI/Resources/Assets.xcassets/Images/{system,artwork}.imageset` | PR로 변경 적용 |

## 스크립트 상세 — `fetch_figma_icons.py`

- **환경변수**: `FIGMA_PAT`(개인 토큰), `GITHUB_WORKSPACE`, `GITHUB_ENV`(변경 목록 export).
- **figma_assets** 데이터: 두 개 fileKey + 각각의 노드 ID/태그 매핑.
- **흐름**:
  1. Figma `GET /v1/files/{key}/nodes` 로 메타 조회 (requests, 동기).
  2. 노드별 `GET /v1/images/{key}?ids=...&format=svg|pdf` 로 다운로드 URL 획득.
  3. `aiohttp` 비동기로 이미지 일괄 다운로드.
  4. 파일 해시/직전 버전 비교 → 변경분만 `assets/{svg,pdf}/` 에 덮어쓰기.
  5. 변경 파일 목록을 `GITHUB_ENV` 로 export → 다음 워크플로가 PR 생성 여부 판단.
- **알림**: 실패 시 Slack webhook으로 통지 (운영 가시성).

## `android/` 서브프로젝트

- 단독 Gradle 프로젝트(루트 `build.gradle`).
- `com.android.ide.common.vectordrawable.Svg2Vector` 를 호출하는 `convertSvgToVector` 태스크를 구현.
- `<image>` 태그가 포함된 raster-embedded SVG 는 변환 스킵 (Vector Drawable 비호환).
- 아트웍 아이콘은 prefix(`ic_artwork_*`) 부여 후 별도 폴더 출력.

## 운영 팁

- **재실행**: 실패 시 GitHub Actions UI에서 `fetch-figma-icon` 또는 `ios-icon-update` 를 `workflow_dispatch` 로 수동 트리거.
- **러너 점검**: self-hosted macOS 러너가 죽어 있으면 모든 워크플로가 큐잉 → 호스트 상태 우선 확인.
- **iOS preserves-vector-representation**: `Contents.json` 에 자동 설정되어 PDF가 벡터로 보존됨 (raster 변환 방지).
- **XML은 커밋 제외**: 매 실행마다 `convertSvgToVector` 가 SVG로부터 재생성하므로 `assets/xml`을 git 추적하지 않음(중복 변경 방지).

## 특이사항

- **artwork ↔ system 분기**: 두 Figma 파일이라 fetch 단계에서 분기, Android/iOS 모두 다른 폴더로 배포.
- **PDF는 iOS, SVG/XML은 Android** — 플랫폼 네이티브 벡터 포맷 차이 때문.
- `version.json` 으로 마지막 동기화 메타데이터 추적.
- 모든 PR은 자동 생성이라 머지·검토 책임은 각 앱 팀에게.
