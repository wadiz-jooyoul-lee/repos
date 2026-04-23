# End-to-End Flow 문서

이 폴더는 **"Client(FE/앱) → com.wadiz.web → Service API → DB"** 전체 체인을 기능 단위로 추적한 문서입니다. 개별 repo 분석(`docs/<repo>/`) 은 단일 서비스 내부에 집중하고, 이 폴더는 **기능 하나가 실제로 어떤 시스템들을 거치는지** 보여줍니다.

## 목적
- 특정 페이지/화면을 수정할 때 영향받는 전체 레이어 파악
- 장애 발생 시 호출 체인을 따라 원인 추적
- 새 팀원이 핵심 플로우 하나를 따라가며 시스템 전체 구조 이해

## Phase 구성 (점진 확장)

| Phase | 플로우 | 상태 |
|---|---|---|
| **A1 — 펀딩 코어** | [funding-detail](./funding-detail.md) · [funding-payment](./funding-payment.md) · [funding-reward-select](./funding-reward-select.md) · [my-funding](./my-funding.md) · [funding-refund](./funding-refund.md) · [funding-autopay](./funding-autopay.md) | ✅ |
| A2 — 계정/가치교환 | login · signup · mypage · coupon-use · supporter-signature · comment | ⏸ |
| A3 — 부가/스토어 | search · store-detail · store-order · store-wish · notification · wai-agent | ⏸ |

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
