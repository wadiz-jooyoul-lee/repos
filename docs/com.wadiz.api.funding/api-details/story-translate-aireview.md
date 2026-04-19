# Story / Translate / AI Review API 상세 스펙

프로젝트 스토리 조회·번역·AI 심사 관련 **16개 엔드포인트**.

- **대상 컨트롤러**:
  - `StoryController` (`/api/story`) — 2개 (Public 조회)
  - `StoryCopyInternalController` (`/api/internal/story-copy`) — 1개 (Admin, 스토리 복사)
  - `StoryTranslationRequestController` (`/api/v1/translate/request`) — 1개 (메이커/관리자)
  - `StoryTranslationInternalController` (`/api/internal/story-translation`) — 1개 (Admin)
  - `StoryTranslationController` (`/api/internal/translation`) — 3개 (외부 번역 서비스 콜백)
  - `InternalTranslateController` (`/api/internal/translate`) — 6개 (번역 엔진 추상화 API)
  - `AIReviewController` (`/api/v1/ai-review`) — 1개 (메이커/관리자)
  - `AIReviewInternalController` (`/api/internal/story/response`) — 1개 (외부 AI 서비스 콜백)

- **저장소**: MySQL + **외부 번역/AI 서비스** (비동기 callback 패턴)
- **주요 테이블**: `CampaignUpdate`(스토리 = 새소식과 같은 스키마 또는 별도), `StoryTranslation`, `AIReviewManagement`

> **기록 범위**: 이 레포에서 직접 관찰 가능한 호출만 기록. 번역/AI UseCase는 외부 jar(`funding-core`)에 위치하며 외부 번역·AI 서비스 연동 세부는 확인 불가.

---

## 1. GET `/api/story/{campaignId}/funding` — 펀딩 스토리 조회

- **Method**: `StoryController.funding`

### Response — `StoryDetailResponse`
프로젝트 스토리 HTML 본문 + 이미지/동영상 등

### DB 호출
`storyProxy.getFundingStoryDetail(campaignId)` — funding-core UseCase.

관련 테이블: `Campaign.IntroDetails`(HTML 본문), `CampaignPhotoCommon`(이미지), `CampaignUpdateLanguage`(번역) 등 — 상세는 campaign-public.md 5번의 `campaignBaseInfo` 쿼리 구조와 유사.

---

## 2. GET `/api/story/{campaignId}/comingsoon` — 오픈예정 스토리 상세

- **Method**: `StoryController.comingsoon`

### Response — `StoryDetailResponse` (1번과 동일 DTO)

### DB 호출
`storyProxy.getComingsoonStoryDetail(campaignId)` — `RewardComingSoonLanguage.Story` 조회 추정 (campaign-global-native.md 4번 `findComingSoonStory`와 유사).

**접근 테이블**: `Campaign`, `RewardComingSoon`, `RewardComingSoonLanguage`

---

## 3. POST `/api/internal/story-copy/{projectNo}` — 스토리 복사 (Admin)

작성된 스토리(임시)를 진행중 스토리로 복사.

- **Method**: `StoryCopyInternalController.copyStoryToOngoing`

### Request Body — `StoryCopyRequest{adminUserId}`

### Response — `ServiceOperationResponse`
- 성공: `"스토리 복사가 완료되었습니다."`
- `StoryCopyFailedException` → errorCode `STORY_COPY_FAILED`
- 기타 Exception → `INTERNAL_ERROR`

### DB 호출
`storyCopyProxy.copyStoryToOngoing(projectNo, adminUserId)` — funding-core. `Campaign.IntroDetails` UPDATE + 관련 언어/이미지 복사.

---

## 4. POST `/api/v1/translate/request/{projectNo}` — 스토리 번역 요청

- **Method**: `StoryTranslationRequestController.postStoryTranslationRequest`
- **Security**: `@PreAuthorize("isMaker(#projectNo) or isAdmin()")`

### Request Body — `StoryTranslationApiRequest`
(번역 대상 언어, 번역할 스토리 내용 등)

### Response — `StoryTranslationApiResponse`

### DB 호출
`storyTranslationRequestProxy.saveTranslationRequest(projectNo, userId, request)` — funding-core.

일반적 흐름:
1. `StoryTranslation` 엔티티 INSERT (상태: REQUESTED)
2. 외부 번역 서비스(AI/기계번역)에 비동기 요청
3. 결과는 추후 `/api/internal/translation/...` 콜백으로 수신 (7-9번)

---

## 5. POST `/api/internal/story-translation/{projectNo}/final-review` — 최종 심사 번역 요청 (Admin)

- **Method**: `StoryTranslationInternalController.requestFinalReviewTranslation`

### Request Body — `FinalReviewTranslationRequest{adminUserId, translationStatus}`

### Response — `ServiceOperationResponse`
- `InvalidTranslationStatusException` → `INVALID_TRANSLATION_STATUS`
- `TranslationAlreadyExistsException` → `TRANSLATION_ALREADY_EXISTS`
- 기타 → `INTERNAL_ERROR`

### DB 호출
`storyTranslationRequestProxy.requestFinalReviewTranslation(projectNo, adminUserId, status)` — 4번과 유사하나 최종 심사 콘텍스트 전용.

---

## 6. POST `/api/internal/translation/{campaignId}/{languageCode}/{translationTaskType}` — AI 번역 결과 수신

외부 AI 번역 서비스가 번역 완료 시 이 엔드포인트로 콜백.

- **Method**: `StoryTranslationController.receiveStoryAiTranslation`

### Path
| 파라미터 | 타입 | 설명 |
|---|---|---|
| `campaignId` | `Integer` | — |
| `languageCode` | enum `LanguageCode` | 번역 언어 |
| `translationTaskType` | enum `TranslationTaskType` | 태스크 유형 |

### Request Body — `AiTranslationCallbackRequest`
AI 번역 결과 (번역된 텍스트 등)

### DB 호출
`storyTranslationProxy.responseAiTranslation(campaignId, languageCode, taskType, translatedAi)` — funding-core.
`CampaignUpdateLanguage` 또는 `RewardComingSoonLanguage` UPDATE (번역 저장).

---

## 7. POST `/api/internal/translation/{campaignId}/{languageCode}/{translationTaskType}/{orderNo}` — 이미지 번역 결과 수신

이미지 내 텍스트 번역 결과 콜백.

- **Method**: `StoryTranslationController.receiveStoryImageTranslation`

### Path
6번 + `orderNo` (이미지 순번)

### Request Body — `ImageTranslationCallbackRequest{translatedMediaItems[]}`

### DB 호출
`storyTranslationProxy.responseImageTranslation(campaignId, languageCode, taskType, orderNo, translatedImage)` — funding-core.
`CampaignPhotoLanguage` UPDATE (번역 이미지 URL 저장).

---

## 8. POST `/api/internal/translation/request/{translationRequestKey}` — 키 기반 번역 결과 수신

- **Method**: `StoryTranslationController.receiveStoryAiTranslationByTranslationRequestKey`

### Path
`translationRequestKey`: `StoryTranslation.TranslationRequestKey` 식별자

### Request Body — `AiTranslationCallbackRequest`

### DB 호출
`storyTranslationProxy.responseAiTranslation(translationRequestKey, translatedAi)` — request 키로 직접 찾아 UPDATE.

---

## 9. POST `/api/internal/translate/text` — 텍스트 번역 (동기)

- **Method**: `InternalTranslateController.translate`

### Request — `TextTranslationRequest` (source language, target language, text)

### Response — `TextTranslationResponse` (번역된 텍스트)

### 흐름
`translator.translateText(request)` — `com.wadiz.api.funding.support.translate.Translator` 빈 직접 호출.

**외부 의존**: 실시간 번역 API (구체 공급사 — funding-core config)

### DB 호출: 없음 (동기 호출, 저장 없음)

---

## 10. POST `/api/internal/translate/html` — HTML 번역 (동기)

- **Method**: `InternalTranslateController.translateHtml`

9번과 동일 패턴, HTML 태그 보존.

---

## 11. POST `/api/internal/translate/ai` — AI 번역 비동기 요청

### Request — `AiTranslationRequest`

### 흐름
`translator.translateAi(request)` — 결과는 추후 콜백으로 수신(`/callback`). DB 저장 여부는 funding-core.

### Response: `Void` (즉시 200)

---

## 12. POST `/api/internal/translate/image` — 이미지 번역 비동기 요청

`translator.translateImage(request)` — 결과는 `/image/callback`으로 수신.

---

## 13. POST `/api/internal/translate/callback` — AI 번역 콜백 테스트

### 컨트롤러 코드 흐름
```java
log.info("callback : {}", request);
return ResponseWrapper.ok();
```

**테스트/디버그용** — 실제 저장 로직은 없음.

---

## 14. POST `/api/internal/translate/image/callback` — 이미지 번역 콜백 테스트

13번과 동일 (테스트/디버그).

---

## 15. POST `/api/v1/ai-review/story/request/{campaignId}` — 스토리 AI 심사 요청

- **Method**: `AIReviewController.postStoryAIReviewRequest`
- **Security**: `@PreAuthorize("isMaker(#campaignId) or isAdmin()")`

### Request Body — `AIReviewStoryRequest`

### Response — `AIReviewResponse`

### DB 호출
`aiReviewProxy.saveRequestAiReview(campaignId, userId, request)` — funding-core.

일반적 흐름:
1. `AIReviewManagement` INSERT (status: RQ = Requested)
2. 외부 AI 심사 서비스에 비동기 요청

관련 SQL (다른 문서에서 관찰된 것, campaign-admin.md 8번 `getSlackMessageData`):
```sql
-- 가장 최근 AI 심사 승인 (조회 예시)
SELECT ARM.UpdatedAt
FROM AIReviewManagement ARM
WHERE ARM.CampaignId = ?
  AND ARM.AIReviewStatus = 'AP'
ORDER BY ARM.AIReviewManagementId DESC
LIMIT 1
```

**접근 테이블**: `AIReviewManagement`

---

## 16. POST `/api/internal/story/response/{campaignId}` — AI 심사 결과 수신 (콜백)

외부 AI 심사 서비스가 완료 시 이 엔드포인트로 콜백.

- **Method**: `AIReviewInternalController.postStoryAIReviewResponse`

### Request Body — `AIReviewStoryResponse`
AI 판정 결과 (승인/반려, 사유 등)

### Response — `AIReviewResponse`

### DB 호출
`aiReviewProxy.saveResponseAiReview(campaignId, response)` — funding-core.

`AIReviewManagement` UPDATE (status: AP/RJ) 또는 새 record INSERT.

---

## 17. 참고 — 이 문서의 Gateway / Repository

### Controller → Proxy / Service 매핑

| Controller | Proxy / Service |
|---|---|
| `StoryController` | `StoryProxy` — funding-core UseCase |
| `StoryCopyInternalController` | `StoryCopyProxy` — funding-core |
| `StoryTranslationRequestController` | `StoryTranslationRequestProxy` |
| `StoryTranslationInternalController` | `StoryTranslationRequestProxy` |
| `StoryTranslationController` (callback) | `StoryTranslationProxy` |
| `InternalTranslateController` | `Translator` (support 레이어 직접 빈) |
| `AIReviewController` / `AIReviewInternalController` | `AIReviewProxy` |

### 외부 서비스 연동
- **Translator 빈** (`com.wadiz.api.funding.support.translate.Translator`) — 텍스트/HTML 동기 번역, AI/이미지 비동기 번역
- **외부 AI 번역 서비스** — `/api/internal/translation/...` 콜백 수신
- **외부 AI 심사 서비스** — `/api/internal/story/response/...` 콜백 수신

### 주요 enum (funding-core)
- `LanguageCode` — 지원 언어 코드 (ko/en/ja/zh 등)
- `TranslationTaskType` — FUNDING_STORY / COMING_SOON_STORY 등 태스크 분류
- `TranslationStatus` — REQUESTED / IN_PROGRESS / COMPLETED / FAILED 등
- `AIReviewStatus` — RQ(요청) / AP(승인) / RJ(반려) 등

### 패턴
- **요청-콜백 비동기**: 번역·AI 심사 모두 `요청 → 외부 서비스 → 콜백 수신 → DB UPDATE` 패턴
- **Exception → ServiceOperationResponse**: `StoryCopyFailedException`, `InvalidTranslationStatusException`, `TranslationAlreadyExistsException` 등 구체 예외를 errorCode로 매핑
- **캠페인 단위 외에 request key 기반** 콜백 라우팅 (8번) — 여러 campaignId에 걸친 요청 묶음 대응

### 접근 테이블 합계 (관찰 + 추정)
`Campaign`, `CampaignUpdate`, `CampaignUpdateLanguage`, `CampaignPhotoLanguage`, `RewardComingSoon`, `RewardComingSoonLanguage`, `StoryTranslation`(추정), `AIReviewManagement`
