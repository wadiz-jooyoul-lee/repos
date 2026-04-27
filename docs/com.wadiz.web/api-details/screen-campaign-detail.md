# 화면 상세 — 리워드 캠페인 상세 (`/web/campaign/detail/{id}`)

> SPA 쉘 + SEO 서버사이드 하이브리드 화면. 본 화면이 `com.wadiz.web` 의 핵심 페이지.

## 진입 URL
| URL | 메소드 | View | 비고 |
|---|---|---|---|
| `/web/campaign/detail/{campaignId}` | GET | `wlayout/wRewardDetailSPA` | 메인 진입 |
| `/web/campaign/detail/reward-info/{id}` | GET | `wlayout/wRewardDetailSPA` | 리워드 탭 |
| `/web/campaign/detail/fundingInfo/{id}` | GET | `wlayout/wRewardDetailSPA` | 펀딩 정보 탭 |
| `/web/campaign/detail/qa/{id}` | GET | `campaign/detailQASPA` | Q&A 탭 |
| `/web/campaign/detailPost/{id}`, `/{id}/news/{newsId}` | GET | `campaign/detailPostSPA` | 새소식 |
| `/web/campaign/detailBacker/{id}` | GET | `campaign/detailBackerSPA` | 서포터 리스트 |

## 컨트롤러
`web/campaign/controller/WEBCampaignController.java`

| Line | Method | URL |
|---|---|---|
| 67 | `selectCampaign` | `/web/campaign/detail/{id}`, `/reward-info/{id}` |
| 116 | `selectFundingInfo` | `/web/campaign/detail/fundingInfo/{id}` |
| 140 | `selectQA` | `/web/campaign/detail/qa/{id}` |
| 166 | `selectPost` | `/web/campaign/detailPost/{id}` |
| 193 | `selectBacker` | `/web/campaign/detailBacker/{id}` |
| 217 | `ajaxUploadEditorImage` | `/web/campaign/ajaxUploadRewardCampaignEditorImage` (POST multipart) |
| 227 | `ajaxFacebookSignature` | `/web/campaign/ajaxFacebookSignature` (POST) |
| 237 | `getParticipants` | `/web/campaign/{campaignId}/participants` |
| 244 | `getMyParticipants` | `/web/campaign/{campaignId}/participants/my` |
| 253 | `ajaxAskForEncore` | `/web/campaign/ajaxAskForEncore` (POST) |
| 262 | `ajaxCancelEncore` | `/web/campaign/ajaxCancelEncore` (POST) |

## 의존 서비스
| Service | 역할 |
|---|---|
| `CampaignService.getCampaignOverview(id)` | 캠페인 개요 (본 패키지 외 `com.wadiz.core.campaign.service`) |
| `RewardCampaignService.getStatus(id)` | 진행 상태 |
| `CampaignAccessPermitValidator.validate(...)` | 프리뷰/종료 접근 권한 |
| `CampaignService.getCampaignDefaultInfo(id)` | 오픈/종료 시각 |
| `GlobalFundingGateway.getProject(id, "ko")` | **funding-api HTTP 호출** |
| `getAiSummary` (봇 전용) | AI 요약 (`projectaisummary` 도메인) |
| `getProjectProductInfoNotice` | 제품정보 고시 |
| `getProjectStory` | 스토리 본문 |
| `CampaignService.getSignatureRewardOverview` | 지지서명 개요 |
| `CommentService.getComments` | 댓글 |

## DB 접근
DAO: `com.wadiz.core.campaign.dao.CampaignDao` → `campaign/campaign-mapper.xml`
- `selectCampaignDefaultInfo`
- `selectCampaignOverview`
- `selectSignatureRewardOverview`
- `selectCampaignProgressSummary1`
- `selectCampaignRewardList`
- `selectCampaignSocialReach`

대부분 `parameterType="map"` + `<if test>` 동적쿼리. `MyBatis dynamic SQL 의존도 매우 높음`.

## SEO 서버사이드 렌더링 (봇 전용)
JSP `wRewardDetailSPA.jsp` 가 다음을 서버사이드로 출력:
- **OG 메타태그** — Facebook/Slack/Kakao 공유
- **JSON-LD schema.org** — `WebPage`, `Product`, `QAPage`
- **Twitter Card**
- **봇 전용 HTML** (User-Agent 검사 후 텍스트 본문 inline)

If-Modified-Since/304 처리도 컨트롤러 단에서 수행 (`WEBCampaignController.java:81-98`).

## 외부 호출
- `globalFundingGateway` (funding-api HTTP)
- `spring-mobile-device` — 모바일 디바이스 판별

## 인증/권한
- 세션: `SessionUtil.isAdminUser()`, `SessionUtil.isLoggedIn()`
- 비공개 캠페인: `CampaignAccessPermitValidator` → 예외 발생 → `serverError.jsp`

## 참고
- 본 화면의 native(앱 WebView) 통합: `../../_flows/funding-detail-native.md`
- 사용 레이아웃: `wRewardDetailSPA` extends `mainCommon` extends `baseLayout` (3단 chain)
