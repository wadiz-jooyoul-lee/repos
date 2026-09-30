# End-to-End Flow 문서

이 폴더는 **"Client(FE/앱) → com.wadiz.web → Service API → DB"** 전체 체인을 기능 단위로 추적한 문서입니다. 개별 repo 분석(`docs/<repo>/`) 은 단일 서비스 내부에 집중하고, 이 폴더는 **기능 하나가 실제로 어떤 시스템들을 거치는지** 보여줍니다.

## 목적
> 🔍 **2026-09-22 도메인 일괄 정정**
>
> 본문의 `wadiz.kr` 표기를 `wadiz.io` 로 바꿨습니다. 근거는 두 곳입니다.
>
> | 출처 | 무엇 |
> |---|---|
> | `wadiz-frontend/packages/core/src/env/environments.ts` | `ENV_DOMAINS` — 도메인 단일 출처 |
> | `wadiz-frontend/studio/startup/.env.production.clive` | 앱별 실제 환경변수 값 |
>
> 환경 이름도 바뀌었습니다. **`local` · `dev` · `rc4` · `stage` · `clive` 5개**입니다.
> `rc` · `rc2` · `rc3` 는 없어졌습니다.
>
> 주요 대응입니다.
>
> | 종전 | 지금 |
> |---|---|
> | `www.wadiz.kr` | `https://www.wadiz.io` |
> | `account.wadiz.kr` | `https://account.wadiz.io` |
> | `platform.wadiz.kr` · `service.wadiz.kr` | **`https://api.wadiz.io`** (한곳으로 모임) |
> | `app.wadiz.kr` | `https://api.wadiz.io/app` |
> | `public-api.wadiz.kr` | `https://api.wadiz.io` |
> | `static.wadiz.kr` | `https://cdn-static.wadiz.io` |
> | `datasvc.wadiz.kr` | `https://datasvc.aidata.wadiz.io` |
>
> ⚠️ **확인하지 못해 그대로 둔 호스트**가 있습니다.
> `cdn3.wadiz.kr` · `ws.ai.wadiz.kr` · `ad.wadiz.kr` · `studio.wadiz.kr` · `aidata.wadiz.kr` 입니다.
> 프런트엔드 코드에서 대응하는 `wadiz.io` 주소를 찾지 못했습니다. **추측으로 바꾸지 않았습니다.**
>
> 변경 로그 블록(`>` 로 시작하는 과거 기록)은 그대로 두었습니다.
>
> ---
>

- 특정 페이지/화면을 수정할 때 영향받는 전체 레이어 파악
- 장애 발생 시 호출 체인을 따라 원인 추적
- 새 팀원이 핵심 플로우 하나를 따라가며 시스템 전체 구조 이해

## Phase 구성 (점진 확장)

| Phase | 플로우 | 상태 |
|---|---|---|
| **A1 — 펀딩 코어** | [funding-detail](./funding-detail.md) · [funding-detail-native](./funding-detail-native.md) (✨ Android·iOS·Web 하이브리드) · [funding-payment](./funding-payment.md) · [funding-reward-select](./funding-reward-select.md) · [my-funding](./my-funding.md) · [funding-refund](./funding-refund.md) · [funding-autopay](./funding-autopay.md) | ✅ |
| **A2 — 계정/가치교환** | [login](./login.md) · [signup](./signup.md) · [mypage](./mypage.md) · [coupon-use](./coupon-use.md) · [supporter-signature](./supporter-signature.md) · [comment](./comment.md) | ✅ |
| **A3 — 부가/스토어** | [search](./search.md) · [store-detail](./store-detail.md) · [store-order](./store-order.md) · [store-wish](./store-wish.md) · [notification](./notification.md) · [wai-agent](./wai-agent.md) | ✅ |

## 앱(Android/iOS) 통합 매핑

각 flow 의 "wadiz-android / wadiz-ios" 섹션을 보완하는 전용 레퍼런스: [`app-mapping.md`](./app-mapping.md)

- 앱과 웹의 **API host·path 차이**, **WebView 위임 영역**, **순수 네이티브 영역** 구분
- 18개 flow × Android(Retrofit) + iOS(RequestBuilder) 호출 위치 매핑

## 추가 절차

1. [_template.md](./_template.md) 복사
2. Phase 테이블에 행 추가
3. 각 레이어별로 실제 코드·설정·SQL을 `path:line` 포맷으로 인용
4. PR 생성 후 리뷰

## 작성 원칙 (ANALYSIS_GUIDE.md 준수)

- **관측 가능한 것만** — 추측 금지
- **Path:line 인용** — 독자가 바로 소스로 이동 가능
- **외부 경계 명시** — 이 repo 안에서 볼 수 없는 부분은 "외부"로 표시
- **SQL 본문 인용** — MyBatis XML 발췌

## 관련 문서

- [이정표 `CLAUDE.md`](../../CLAUDE.md) — repo 전체 지도
- [분석 작업 가이드 `ANALYSIS_GUIDE.md`](../../ANALYSIS_GUIDE.md) — Phase 1/2 절차
- 서비스별 상세: [`docs/com.wadiz.api.funding/`](../com.wadiz.api.funding/), [`docs/com.wadiz.api.reward/`](../com.wadiz.api.reward/), [`docs/com.wadiz.wave.user/`](../com.wadiz.wave.user/), [`docs/kr.wadiz.account/`](../kr.wadiz.account/)
