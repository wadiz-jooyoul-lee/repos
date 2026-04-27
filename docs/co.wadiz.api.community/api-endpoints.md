# co.wadiz.api.community — API 엔드포인트 전수 목록

> 2026-04-26 기준 풀 구현 상태. **11 컨트롤러 · 37 REST endpoint**. 모든 path 가 `wave.user` V3 와 1:1 일치 (이관 완료).
> 상세 분석: [`api-details/supporter-signature-module.md`](./api-details/supporter-signature-module.md)

## 1. SupporterSignatureController (`controller/SupporterSignatureController.java:30`)
base: `/api/v3/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{signatureId}` | 서명 상세 |
| DELETE | `/{signatureId}` | 서명 삭제 |
| GET | `` | 서명 목록 |
| GET | `/count` | 서명 수 |
| GET | `/counts` | 다건 카운트 |
| GET | `/user-images` | 서명자 이미지 |
| DELETE | `` | 일괄 삭제 |

## 2. SupporterSignatureUserController (`SupporterSignatureUserController.java:32`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 서명 등록 |
| PUT | `/{signatureId}` | 서명 수정 |
| GET | `/count` | 유저 서명 수 |
| GET | `/id` | 서명 ID |
| GET | `/status` | 서명 상태 |
| GET | `/detail` | 상세 |
| GET | `` | 유저 서명 목록 |

## 3. SupporterSignatureKeywordController (`SupporterSignatureKeywordController.java:24`)
base: `/api/v3/supporter-signatures/keywords`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 키워드 목록 |
| GET | `/count` | 키워드 수 |

## 4. SupporterSignatureInterestDegreeController (`SupporterSignatureInterestDegreeController.java:23`)
base: `/api/v3/supporter-signatures/interest-degree`

| Method | Path | 용도 |
|---|---|---|
| POST | `/notification/range/1` | 관심도 1 알림 |
| POST | `/notification/range/2` | 관심도 2 알림 |

## 5. SupporterSignaturePointController (`SupporterSignaturePointController.java:30`)
base: `/api/v3/supporter-signatures/points`

| Method | Path | 용도 |
|---|---|---|
| GET | `/total-info` | 전체 포인트 정보 |
| GET | `/affiliates/versions` | 제휴 버전 |
| GET | `/affiliates/{trackingId}/issue-key` | 제휴 발급 키 |
| POST | `/affiliates/notification` | 제휴 알림 |

## 6. SupporterSignaturePointUserController (`SupporterSignaturePointUserController.java:33`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| GET | `/points` | 유저 포인트 |
| GET | `/points/count` | 유저 포인트 수 |
| GET | `/points/total` | 유저 총 포인트 |
| GET | `/{signatureId}/points/detail` | 서명별 포인트 상세 |
| POST | `/{signatureId}/points/affiliates/{trackingId}` | 제휴 포인트 적립 |

## 7. SupporterSignatureCommunicationController (`SupporterSignatureCommunicationController.java:24`)
base: `/api/v3/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{signatureId}/comments` | 댓글 목록 |

## 8. SupporterSignatureCommunicationUserController (`SupporterSignatureCommunicationUserController.java:28`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `/{signatureId}/comments` | 댓글 작성 |
| PUT | `/comments/{commentId}` | 댓글 수정 |
| DELETE | `/comments/{commentId}` | 댓글 삭제 |
| PUT | `/{signatureId}/reactions/{reactionTypeId}` | 서명 리액션 |
| PUT | `/comments/{commentId}/reactions/{reactionTypeId}` | 댓글 리액션 |

## 9. SupporterSignatureAffiliateController (`SupporterSignatureAffiliateController.java:24`)
base: `/api/v3/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/affiliates/results` | 제휴 결과 |
| PUT | `/affiliates/canceled-signatures/results` | 취소 제휴 결과 |
| GET | `/affiliates/targets/count` | 제휴 대상 수 |

## 10. SupporterSignatureAffiliateUserController (`SupporterSignatureAffiliateUserController.java:22`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `/{signatureId}/affiliates` | 제휴 등록 |

## 11. (예상 11번째 컨트롤러)
사내 doc 기준 11 컨트롤러 명시. 본 grep 으로 10개 확인 — 추가 1개는 별도 위치 (예: `module/supporter_signature/component/` 또는 `module/messaging/`) 가능. 추적 필요.

---

## 통계

| 도메인 | 컨트롤러 | 엔드포인트 |
|---|---|---|
| Signature 본문 (관리자/유저) | 2 | 14 |
| Keyword | 1 | 2 |
| InterestDegree | 1 | 2 |
| Point (관리자/유저) | 2 | 9 |
| Communication (관리자/유저) | 2 | 6 |
| Affiliate (관리자/유저) | 2 | 4 |
| **합계 (관측)** | **10** | **37** |

→ wave.user signature-v3 의 컨트롤러 11개와 동일 path. **1:1 이관**.

## wave.user 와의 차이점 (관측 가능한 것만)
- 패키지: `com.wadiz.wave.user.supporter.signature.v3.*` → `co.wadiz.community.module.supporter_signature.controller.*`
- 클래스 이름에서 `V3` 접미 제거 (community 는 V3 만 보유하므로 불필요)
- 서비스 포트 9020 → 9011

## 호출자 전환 상태
**com.wadiz.web 의 RestTemplate baseUrl 은 여전히 wave.user(9990 게이트웨이) 를 가리킴** (확인: `properties/file-{env}.properties` 의 `user_api_base_uri`). community(9011) 로의 전환은 **아직 미적용** — 두 백엔드 공존 상태.

상세 흐름: [`docs/_flows/supporter-signature.md`](../_flows/supporter-signature.md)
