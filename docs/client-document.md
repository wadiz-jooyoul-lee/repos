# client-document

## 개요
와디즈 클라이언트(웹/앱/메이커센터) 개발팀의 **기술 분석·설계·VOC 분석 문서 모음**입니다. 코드 저장소가 아니라 Markdown 문서 전용 repo로, 일회성 third-party 분석부터 장기 프로젝트(메이커센터 기획전) 명세까지 보관합니다. Org: `wadiz-client`.

## 디렉터리 구조

```
client-document/
├── README.md
├── 202603-third-party-services-analysis.md
├── 202603-third-party-services-improvement.md
├── 202603-waditag-platform-comparison.md
├── 202604-dollar-coupon.md
├── 202604-voc2172-maker-follow-notification-analysis.md
├── app/                     # 모바일 앱 관련 문서
├── web/                     # 와디즈 웹 관련 문서
└── maker-center-exhibition/ # 메이커센터 기획전 프로젝트 번들
```

## 폴더별 문서

### 루트 (플랫폼 횡단)
| 파일 | 주제 |
|---|---|
| `202603-third-party-services-analysis.md` | 사용 중인 서드파티 서비스 현황 분석 |
| `202603-third-party-services-improvement.md` | 위 분석을 토대로 한 개선안 |
| `202603-waditag-platform-comparison.md` | WadiTag 플랫폼 비교 |
| `202604-dollar-coupon.md` | 달러 쿠폰 기능 설계 |
| `202604-voc2172-maker-follow-notification-analysis.md` | VOC #2172 — 메이커 팔로우 알림 분석 |

### `app/` — 모바일 앱
| 파일 | 주제 |
|---|---|
| `202508-fcm-token.md` | FCM 토큰 관리 |
| `202508-libraries.md` | 사용 라이브러리 정리 |
| `202510-maintain-libraries.md` | 라이브러리 유지보수 가이드 |
| `202603-firebase-appcheck-design.md` | Firebase App Check 도입 설계 |
| `20260318-webview-url-routing-analysis.md` | 웹뷰 URL 라우팅 현행 분석 |
| `20260319-webview-routing-improvement-proposal.md` | 라우팅 개선 제안 |
| `20260319-webview-routing-scenarios.md` | 라우팅 시나리오 케이스 |

### `web/` — 와디즈 웹
| 파일 | 주제 |
|---|---|
| `202603-froala-v4-upgrade-analysis.md` | Froala 에디터 v4 업그레이드 분석 |
| `202603-froala-v5-upgrade-analysis.md` | Froala v5 업그레이드 분석 |
| `202603-funding-ssr-server-design.md` | 펀딩 SSR 서버 설계 |
| `20260312-performance-optimization-home.md` | 홈 성능 최적화 |
| `20260316-performance-optimization-detail.md` | 상세 페이지 성능 최적화 |
| `20260317-review-RWD-5365.md` | RWD-5365 티켓 리뷰 |
| `20260324-node22-upgrade-plan.md` | Node 22 업그레이드 계획 |
| `20260324-seo-improvement-for-CLIENT-29.md` | SEO 개선 (CLIENT-29) |
| `20260401-jsp-app-settings-preload.md` | JSP 앱 설정 프리로드 |
| `funding-payment-integration/` | 펀딩 결제 연동 하위 번들 |

### `maker-center-exhibition/` — 기획전 프로젝트 번들
| 파일 | 역할 |
|---|---|
| `PRD.md` | Product Requirements |
| `ARCHITECTURE.md` | 아키텍처 설계 |
| `PROBLEM_ANALYSIS.md` | 문제 정의 |
| `IMPL-1차.md` | 1차 구현 명세 |

## 컨벤션

- **파일명 prefix**:
  - `YYYYMM-` — 월 단위 분석 (예: `202603-`)
  - `YYYYMMDD-` — 일 단위 (예: `20260318-`)
  - 티켓 코드 포함 (`voc2172-`, `RWD-5365`, `CLIENT-29`) — 출처 추적용
- **장기 프로젝트**는 별도 폴더로 묶음 (`maker-center-exhibition/`, `funding-payment-integration/`).
- **플랫폼 횡단** 문서는 루트, **플랫폼 한정** 문서는 `app/` 또는 `web/` 하위.

## 특이사항

- 일회성 분석(third-party, VOC, performance) 과 장기 PRD/ARCHITECTURE 번들이 한 repo 안에 공존.
- 2026 Q1~Q2 (3-4월) 활동 집중 — 와디즈 플랫폼 모더나이제이션 흐름과 일치 (Node22, SSR, Froala v5, App Check, JSP 프리로드 등).
- README가 한 줄짜리 미니멀 — 실제 구조는 폴더가 자체적으로 설명함.
- 코드 저장소가 아니므로 CI/CD·테스트 없음. 검색·인덱싱은 GitHub 자체 검색이 사실상의 ToC.
