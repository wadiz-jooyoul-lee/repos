# wadiz-frontend 기능 이정표 (Feature Signpost)

> **목적**: 이슈 제목·기능 문구를 보고 **어떤 소스를 고쳐야 하는지 역으로 찾는 이정표**.
> **기준**: master @ `4439853b8dd` (2026-07-15)
> **단위**: 기능·컴포넌트 / **경로 표기**: repo 루트(`wadiz-frontend`) 기준 상대경로.

## 사용법

1. **먼저 이 인덱스에서 영역을 고릅니다** → 해당 파일 하나만 엽니다. (파일이 영역별로 나뉘어 있어 필요 없는 내용을 읽지 않습니다.)
2. 파일 안에서 `Ctrl+F`로 **기능명 · 화면 문구 · 이슈키(FE1-xxxx)** 검색.
3. 문구는 대부분 `@wadiz/i18n`의 `useTranslation({ keyPrefix })` + `t('상대키')` 조합입니다. 실제 텍스트는 `packages/i18n/src/supporter/languages/{ko,en,ja,zh}.json` 의 `keyPrefix` 아래에서 확인합니다. 하드코딩(비 i18n) 문구는 표에 **하드코딩** 으로 표기했습니다.
4. 각 파일 하단 **이슈 히스토리** 표로 그 영역을 건드린 Jira 이슈 제목을 확인할 수 있습니다.

## 영역 인덱스

| 영역 | 파일 | 대상 소스 | 상태 |
|---|---|---|---|
| 사용자 서비스 도메인 (글로벌 앱 9개 도메인 + 공유 features/ui/widgets) | [`apps-global.md`](./apps-global.md) | `apps/global` · `packages/features·ui·widgets` | 완료 |
| global 외 앱 (계정·고객센터·IR·파트너스·파트너존·메일·와링크·WAi런처·devtools) | [`apps-others.md`](./apps-others.md) | `apps/{account,help-center,ir,partners,partnerzone,mail-template,walink-generator,wai-ai-agent-launcher,devtools}` | 완료 |
| 인프라 · 디자인시스템 패키지 (UI 문구 없음, 위치·역할 참조) | [`packages-infra.md`](./packages-infra.md) | `packages/{api,core,queries,i18n,tokens,waffle,waffle-icons,artworks,…}` | 완료 |
| 레거시 국내 서비스 (static) | [`static.md`](./static.md) | `static/entries/*` · `static/services/admin` | 완료 |
| 메이커 스튜디오 (funding·store·startup·studio-services) | `studio.md` | `studio/*` | 미작성(예정) |

## 도메인 빠른 이동 (apps-global.md 내부)

`apps-global.md` 파일 안의 앵커입니다.

- [펀딩 상세](./apps-global.md#펀딩-상세-funding-detail) · [결제](./apps-global.md#결제-funding-payment) · [홈/서비스홈](./apps-global.md#홈--서비스홈-home--service-home) · [마이와디즈/위시](./apps-global.md#마이와디즈--위시-my-wadiz--wish) · [메이커/프로젝트 만들기](./apps-global.md#메이커--프로젝트-만들기-maker--create-project) · [소셜/친구추천](./apps-global.md#소셜--친구추천-social--refer-a-friend) · [검색/스토어/소싱클럽](./apps-global.md#검색--스토어--소싱클럽-search--store--sourcing-club) · [정책/WAi/기타](./apps-global.md#정책--wai--알림--이벤트--쿠폰--기타) · [packages 공통](./apps-global.md#packages-공통-ui--widgets--features)

## 이슈키 → 영역 힌트

이슈 접두사로 대략 영역을 좁힐 수 있습니다(정확한 매핑은 각 파일의 이슈 히스토리 표 참조).

- `FE1-*` — 대부분 사용자 서비스(글로벌 앱·펀딩/스토어) → `apps-global.md`
- `FE2-*` — 메이커/스튜디오/WAi 계열이 많음 → `apps-global.md`(메이커 도메인) 또는 `studio.md`(예정)
- `CLIENT-*` — 개발자 도구/메일 등 → `apps-others.md`
- `QA-*` — 버그픽스(영역 다양) → 제목으로 영역 판단

## 유지보수 메모

- 스냅샷 문서입니다. master가 진전되면 갱신이 필요합니다(기준 커밋 갱신 + 변경 영역 파일만 수정).
- 배너·기획전·CMS 데이터 기반 컴포넌트는 고정 문구가 없어 "데이터 기반"으로 표기했습니다.
