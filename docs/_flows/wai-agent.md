# Flow: WAi (와디즈 AI 에이전트)

> 와디즈의 AI 챗·추천·검토 기능을 모아둔 영역. **`apps/wai-ai-agent-launcher`** 가 에이전트 런처 UI, 서버측은 주로 `app-api` (NestJS BFF) 와 외부 AI 서비스/모델 공급자를 조합.

> 📅 **2026-04-26 보강** — funding pull 결과 AI Review 영역 명확해짐.
>
> ### `com.wadiz.api.funding` AI Review 컨트롤러 위치 확정
> ```
> domain/aireview/
> ├── AIReviewController.java           POST /api/v1/ai-review/story/request/{campaignId}    # 메이커 → AI 심사 요청
> └── AIReviewInternalController.java   POST /api/internal/story/response/{campaignId}        # AI 서비스 → 결과 콜백
> ```
> - AI 서비스 → funding 으로 비동기 결과 반환 (callback 패턴)
> - **batch 재시도**: `domain/aireviewpostapprovalretry/AIReviewPostApprovalRetryJobConfig` — 동시 callback 수신으로 번역 못한 케이스 재처리
>
> ### 번역 관련 신규
> - **batch**: `domain/translationqualitymonitor/TranslationQualityMonitorJobConfig` — 번역 품질 모니터링
> - RWD-5479: AI 심사 RequestKey 에 언어 추가 (동시성 충돌 방지)
> - POST_APPROVAL 심사 결과 수신 시 자동 번역 요청
> - 최종승인 후 AI 심사 요청 시 작성언어/옵션언어 기준
> - 알림톡 Template + payload 다국어 분기
>
> ### 인프라 (`adapter/infrastructure/`)
> - `aireview/AIReviewQueryGatewayImpl.java`
> - `persistence/aireview/AIReviewMapper.java`
> - `mapper/aireview/AIReviewMapper.xml` (MyBatis)
> 즉 funding 자체 MySQL 에 AI 심사 결과·번역 요청 이력을 저장.
>
> ### 영향
> 본 flow 의 § 1.1 "AI Review (메이커 스튜디오)" 부분은 **추정에서 확정**으로 갱신:
> - 정확한 path: `POST /api/v1/ai-review/story/request/{campaignId}` (앞에 `/web/apip/funding/` proxy)
> - Internal callback: `POST /api/internal/story/response/{campaignId}` (AI 서비스 → funding)

> 📅 **2026-09-29 본문 점검** — `com.wadiz.api.funding` `master` `a9fac634f` 기준
>
> **위 2026-04-26 보강 블록의 경로 2개는 지금도 그대로입니다.**
>
> | 경로 | 현재 위치 |
> |---|---|
> | `POST /api/v1/ai-review/story/request/{campaignId}` | `AIReviewController.java:28` |
> | `POST /api/internal/story/response/{campaignId}` | `AIReviewInternalController.java:27` |
>
> 다만 2026-08~09 에 **`RWD-5901`·`RWD-5975` 두 갈래로 AI 심사 알림이 크게 손질됐습니다.**
> 조회 계층(`AIReviewQueryGatewayImpl.java`)이 102줄, 쿼리 XML(`mapper/aireview/AIReviewMapper.xml`)이 70줄 바뀌었습니다.
>
> | 이슈키 | 날짜 | 무엇이 바뀌었나 |
> |---|---|---|
> | `RWD-5901` | 2026-08-26 | 심사 카테고리 조회를 `ScreeningRewardItemCategoryLanguage`(한국어) 조인으로 바꿨습니다 |
> | `RWD-5975` | 2026-09-02 | AI 심사 결과를 **사후심사 이력에 기록**하기 시작했습니다 |
> | `RWD-5975` | 2026-09-03 | 심사 이력에서 스토리 버전 기록을 뺐습니다 |
> | `RWD-5975` | 2026-09-03 | 오픈예정을 적용하지 않은 프로젝트는 심사 요청에서 오픈예정 스토리를 뺍니다 |
> | `RWD-5975` | 2026-09-04 | **비노출 알림을 관리자 알림과 분리**했습니다 (메일 템플릿 1542, 언어별 링크) |
> | `RWD-5975` | 2026-09-07 | 비노출 알림톡을 **신규 템플릿 3231** 로 분리했습니다 |
> | `RWD-5975` | 2026-09-10 | 슬랙 알림의 스튜디오 링크에 심사 언어를 반영했습니다 |
> | `RWD-5975` | 2026-09-15 | 알림톡 앱 링크를 **스킴 없는 경로로 통일**했습니다 |
>
> **알림이 세 갈래로 나뉜 것이 이번 변화의 핵심입니다.**
> 예전에는 심사 결과 알림 하나로 처리하던 것을 지금은 이렇게 나눕니다.
>
> | 갈래 | 받는 사람 | 수단 |
> |---|---|---|
> | 심사 결과 | 메이커 | 알림톡 |
> | 비노출 처리 | 메이커 | 알림톡 템플릿 3231 |
> | 관리자 통보 | 운영자 | 메일 템플릿 1542, 슬랙 |
>
> 앱 링크에서 `wadiz://` 스킴을 뺀 점도 눈에 띕니다.
> 알림톡이 여는 경로를 앱과 웹이 같은 형태로 받게 하려는 것으로 보입니다(추정).
> 커밋에 그 이유가 적혀 있지는 않습니다.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/apps/wai-ai-agent-launcher/` (앱 존재 확인, 세부 코드 미탐색)
  - `docs/app-api.md` (app-api BFF 분석 — webhooks/help-center 자동 번역 등 관련)
  - `com.wadiz.api.funding/adapter/application/src/main/java/com/wadiz/api/funding/domain/` 내부 `aireview`, `projectaisummary` (Phase 2 funding 문서에서 관측)
  - `docs/com.wadiz.api.funding/com.wadiz.api.funding.md` (aireview / projectaisummary 도메인 언급)
- **외부 경계**: 실제 LLM 서비스(OpenAI/Anthropic/Bedrock 등) 및 벡터 DB. 본 레포의 코드 범위 밖. WAi 백엔드 전용 repo 별도 존재 가능성 높음.

---

## 1. WAi 영역 구성 (관측 기반)

### 1.1 FE 앱
- **`apps/wai-ai-agent-launcher/`** — 에이전트 목록·진입 허브 (wadiz-frontend 모노레포)
- **각 소비자 앱** 내부 UI 요소: 메이커 스튜디오, 프로젝트 상세, 서포팅 도우미 등

### 1.2 백엔드
- **`app-api`** (NestJS BFF) — 일부 WAi 관련 호출 프록시 (recommend/story cache 등)
- **`com.wadiz.api.funding`** 내 AI 도메인:
  - `aireview/` — AI 프로젝트 리뷰 (메이커가 올린 스토리/콘텐츠를 AI 가 사전 검토)
  - `projectaisummary/` — AI 프로젝트 요약 (서포터용 긴 스토리 요약)
  - `reaction/` — AI 반응 분석 (추정)
- **외부 AI 서비스** — Wadiz 내부 AI repo 가 별도로 있을 가능성 (repos 내 미포함)

### 1.3 i18n·번역
- `app-api` 의 `webhooks/help-center` — Zendesk 티켓 자동 번역 웹훅(관측). 이 역시 WAi 영역으로 추정.

---

## 2. 관측된 주요 경로 (FE → 서버)

### 2.1 wai-agent-launcher → api.wadiz.io/app
```
GET /app/wai/agents                 # 에이전트 목록 (추정)
POST /app/wai/agents/{id}/invoke    # 에이전트 실행 (추정)
```
(환경변수 `VITE_APP_API_URL` → api.wadiz.io/app = app-api 호스트)

### 2.2 AI Review (메이커 스튜디오)
```
POST /web/apip/funding/aireview/...       # 프로젝트 리뷰 실행 (funding 도메인 내 aireview)
GET  /web/apip/funding/projectaisummary/{projectNo}/summary   # 요약 조회 (추정)
```

### 2.3 Zendesk 번역
[docs/app-api.md](../app-api.md) 의 `webhooks/help-center` 참조. Zendesk 티켓 저장 시 자동 번역 후 회신.

---

## 3. Hub — 분산됨

### 3.1 `api.wadiz.io/app` (app-api NestJS)
- WAi 관련 FE 호출의 1차 진입
- 내부에서 OpenAI/Anthropic/사내 AI 서비스 호출 (추정)
- Zendesk Webhooks 수신 → 번역 후 회신

### 3.2 `www.wadiz.io/web/apip/funding/*` (ApiProxy)
- `aireview`, `projectaisummary` 영역이 funding 도메인 내에 있으므로 일반 ApiProxy 경유
- funding 서비스가 AI 모델 공급자 호출

### 3.3 외부 AI 서비스 (별도)
본 레포에서 직접 관측 불가. 사내 AI repo/서비스로 분리되어 있을 것으로 추정.

---

## 4. 데이터

### 4.1 funding 측
- `aireview` 결과: `Campaign` 에 부속된 스냅샷 테이블 (추정 `CampaignAIReview`)
- `projectaisummary`: `CampaignAISummary` (추정)
- 텍스트 원본 + 모델 응답 + 생성시각

### 4.2 app-api 측
- Zendesk 티켓 원문·번역 캐시 (TypeORM)

### 4.3 외부
- 벡터 임베딩 스토어·프롬프트 로그는 별도.

---

## 엔드투엔드 시퀀스 (3가지 예)

### A. 메이커 — 프로젝트 사전 심사(AI Review)
```
[메이커 스튜디오: 프로젝트 제출 전 "AI 검토" 버튼]
   │ POST /web/apip/funding/aireview/projects/{id}/review
   ▼
[ApiProxy → com.wadiz.api.funding: aireview domain]
   │
   ├─ 프로젝트 텍스트·이미지 수집
   ├─ 외부 AI 모델 호출 (LLM prompt)
   ├─ 응답 파싱 + 가이드라인 위반 항목 추출
   └─ INSERT CampaignAIReview (projectId, reviewerModel, findings, createdAt)

   → 메이커에게 결과 표시: "다음 문구를 수정해 주세요"
```

### B. 서포터 — 프로젝트 요약 보기
```
[FE: 프로젝트 상세 "요약" 탭]
   │ GET /web/apip/funding/projectaisummary/projects/{id}/summary
   ▼
[com.wadiz.api.funding: projectaisummary]
   │
   ├─ CampaignAISummary 캐시 확인
   ├─ 없거나 stale → 외부 AI 호출 → INSERT/UPDATE 캐시
   └─ Response 반환
```

### C. WAi Agent Launcher → Chat
```
[FE: apps/wai-ai-agent-launcher/ 에이전트 선택]
   │ POST /app/wai/agents/{agentId}/invoke
   │   body: { userInput, context }
   ▼
[app-api (NestJS BFF)]
   │
   ├─ 권한·쿼터 확인
   ├─ 외부 AI 서비스 호출 (스트리밍 응답 가능)
   ├─ 세션 저장 (TypeORM)
   └─ SSE/WebSocket 또는 JSON 응답

   → FE: 채팅 UI 에 토큰 단위 렌더
```

### D. Zendesk 티켓 자동 번역
```
[Zendesk 외부 → app-api 웹훅]
   │ POST /app-api/webhooks/help-center/ticket
   ▼
[app-api: HelpCenterController]
   │
   ├─ 티켓 원문 저장 (TypeORM)
   ├─ 외부 번역 API 호출 (플랫폼 번역 API)
   └─ 번역 결과를 Zendesk 에 코멘트로 회신
```
상세: [docs/app-api.md](../app-api.md)

---

## 경계·미탐색
1. **WAi 백엔드 전용 repo** — 본 repos 에 없음. 별도 repo 존재 여부·이름 확인 필요.
2. **LLM 공급자** — OpenAI / Anthropic Claude / 사내 자체 모델 / 혼합 — 프롬프트·로깅 정책.
3. **프롬프트 저장소** — 프롬프트 버저닝·A/B 테스트 구조.
4. **비용·쿼터 관리** — 사용자/메이커/운영별 호출 한도, 요금 체계.
5. **funding 내부 `aireview`/`projectaisummary` 구체 컨트롤러** — Phase 2 funding 문서의 `api-endpoints.md` 에서 확인 권장.
6. **실시간성** — 채팅 스트리밍(SSE/WS) vs 요약(배치) 구분.
7. **안전 장치** — 개인정보·민감정보 필터링, 출력 검증 (guardrails).
8. **앱 측 통합** — wadiz-android/ios 의 `wai` feature 모듈이 app-api 를 호출하는 경로는 Phase 2 앱 분석 영역.
