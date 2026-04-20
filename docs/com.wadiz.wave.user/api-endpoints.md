# com.wadiz.wave.user — API 엔드포인트 전수 목록

> 소스 기준: 57개 `*Controller.java` (src/main/java/com/wadiz/wave/user/) 클래스 레벨 `@RequestMapping` + 메서드 레벨 `@{Get,Post,Put,Delete,Patch}Mapping`. 약 **220+ 엔드포인트**.
> 각 도메인 상세 (입력 DTO / Service / SQL) 는 `api-details/<domain>.md` 참조.

---

## 1. Supporter Signature V1 (6 컨트롤러, ≈37 endpoints)
**상세**: [`api-details/signature-v1.md`](./api-details/signature-v1.md)

### SupporterSignatureOldController (`supporter/signature/v1/SupporterSignatureOldController.java:28`)
base: `/api/v1/users/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `/supporter/{userId}/signatures` | 서명 등록 |
| PUT | `/supporter/{userId}/signatures` | 서명 수정 |
| PUT | `/signatures/{signatureId}/hiding` | 서명 숨김 처리 |
| DELETE | `/signatures` | 서명 삭제 |
| GET | `/supporter/{userId}/signed-id` | 서명 ID 조회 |
| GET | `/supporter/{userId}/signatures/count` | 유저 서명 수 |
| GET | `/signatures/count` | 전체 서명 수 |
| GET | `/signatures/counts` | 다건 카운트 |
| GET | `/supporter/{userId}/is-signed` | 서명 여부 |
| GET | `/signatures/{signatureId}` | 서명 상세 |
| GET | `/supporter/{userId}` | 서포터 정보 |
| GET | `/supporter/{userId}/signatures` | 유저의 서명 목록 |
| GET | `/signatures` | 서명 목록 |
| GET | `/signatures/keywords` | 키워드 집계 |
| GET | `/signatures/keywords/count` | 키워드 수 |
| GET | `/signatures/user-images` | 서명자 이미지 목록 |

### SupporterSignatureTrackingController (`supporter/signature/v1/SupporterSignatureTrackingController.java:24`)
base: `/api/v1/users/supporter-signatures/event/tracking`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 트래킹 이벤트 생성 |
| PUT | `/results` | 결과 업데이트 |
| PUT | `/canceled-signatures/results` | 취소된 서명 결과 |
| GET | `/point-targets/count` | 포인트 대상 수 |
| POST | `/point` | 포인트 적립 |
| GET | `/point/issue-key` | 적립 키 발급 |
| GET | `/point/infos` | 포인트 정보 |
| POST | `/point/push` | 포인트 푸시 |

### SupporterSignaturePointController (`supporter/signature/v1/SupporterSignaturePointController.java:29`)
base: `/api/v1/users/supporter-signatures/points`

| Method | Path | 용도 |
|---|---|---|
| GET | `/supporter/{userId}/count` | 유저 포인트 적립 수 |
| GET | `/supporter/{userId}` | 유저 포인트 이력 |
| GET | `/signatures/{signatureId}/total` | 서명별 총 포인트 |
| GET | `/supporter/{userId}/total` | 유저 총 포인트 |
| GET | `` | 포인트 목록 |

### SupporterSignatureInterestDegreeController (`supporter/signature/v1/SupporterSignatureInterestDegreeController.java:25`)
base: `/api/v1/users/supporter-signatures/interest-degree`

| Method | Path | 용도 |
|---|---|---|
| POST | `/notification/range/1` | 관심도 1단계 알림 |
| POST | `/notification/range/2` | 관심도 2단계 알림 |

### SupporterSignatureCommunicationController (`supporter/signature/v1/SupporterSignatureCommunicationController.java:29`)
base: `/api/v1/users/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `/supporter/{userId}/signatures/{signatureId}/comments` | 댓글 작성 |
| PUT | `/supporter/{userId}/signatures/{signatureId}/comments/{commentId}` | 댓글 수정 |
| GET | `/signatures/{signatureId}/comments` | 댓글 목록 |
| DELETE | `/comments/{commentId}` | 댓글 삭제 |
| PUT | `/supporter/{userId}/signatures/{signatureId}/reactions/{reactionTypeId}` | 서명 리액션 |
| PUT | `/supporter/{userId}/comments/{commentId}/reactions/{reactionTypeId}` | 댓글 리액션 |

### SupporterSignatureShareController (`supporter/signature/v1/share/SupporterSignatureShareController.java:21`)
base: `/api/v1/users/supporter-signatures/share`

| Method | Path | 용도 |
|---|---|---|
| POST | `/supporter/{userId}/signatures/{signatureId}` | 공유 등록 |
| GET | `/points/supporter/{userId}/signatures/{signatureId}` | 공유 포인트 조회 |

---

## 2. Supporter Signature V3 (11 컨트롤러, ≈37 endpoints)
**상세**: [`api-details/signature-v3.md`](./api-details/signature-v3.md)

### SupporterSignatureV3Controller (`supporter/signature/v3/SupporterSignatureV3Controller.java:29`)
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

### SupporterSignatureV3UserController (`supporter/signature/v3/SupporterSignatureV3UserController.java:30`)
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

### SupporterSignatureKeywordV3Controller (`supporter/signature/v3/SupporterSignatureKeywordV3Controller.java:24`)
base: `/api/v3/supporter-signatures/keywords`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 키워드 목록 |
| GET | `/count` | 키워드 수 |

### SupporterSignatureInterestDegreeV3Controller (`supporter/signature/v3/SupporterSignatureInterestDegreeV3Controller.java:23`)
base: `/api/v3/supporter-signatures/interest-degree`

| Method | Path | 용도 |
|---|---|---|
| POST | `/notification/range/1` | 관심도 1 알림 |
| POST | `/notification/range/2` | 관심도 2 알림 |

### SupporterSignaturePointV3Controller (`supporter/signature/v3/SupporterSignaturePointV3Controller.java:28`)
base: `/api/v3/supporter-signatures/points`

| Method | Path | 용도 |
|---|---|---|
| GET | `/total-info` | 전체 포인트 정보 |
| GET | `/affiliates/versions` | 제휴 버전 |
| GET | `/affiliates/{trackingId}/issue-key` | 제휴 발급 키 |
| POST | `/affiliates/notification` | 제휴 알림 |

### SupporterSignaturePointV3UserController (`supporter/signature/v3/SupporterSignaturePointV3UserController.java:29`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| GET | `/points` | 유저 포인트 |
| GET | `/points/count` | 유저 포인트 수 |
| GET | `/points/total` | 유저 총 포인트 |
| GET | `/{signatureId}/points/detail` | 서명별 포인트 상세 |
| POST | `/{signatureId}/points/affiliates/{trackingId}` | 제휴 포인트 적립 |

### SupporterSignatureCommunicationV3Controller (`supporter/signature/v3/SupporterSignatureCommunicationV3Controller.java:24`)
base: `/api/v3/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{signatureId}/comments` | 댓글 목록 |

### SupporterSignatureCommunicationV3UserController (`supporter/signature/v3/SupporterSignatureCommunicationV3UserController.java:22`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `/{signatureId}/comments` | 댓글 작성 |
| PUT | `/comments/{commentId}` | 댓글 수정 |
| DELETE | `/comments/{commentId}` | 댓글 삭제 |
| PUT | `/{signatureId}/reactions/{reactionTypeId}` | 서명 리액션 |
| PUT | `/comments/{commentId}/reactions/{reactionTypeId}` | 댓글 리액션 |

### SupporterSignatureAffiliateV3Controller (`supporter/signature/v3/SupporterSignatureAffiliateV3Controller.java:24`)
base: `/api/v3/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/affiliates/results` | 제휴 결과 |
| PUT | `/affiliates/canceled-signatures/results` | 취소 제휴 결과 |
| GET | `/affiliates/targets/count` | 제휴 대상 수 |

### SupporterSignatureAffiliateV3UserController (`supporter/signature/v3/SupporterSignatureAffiliateV3UserController.java:23`)
base: `/api/v3/users/{userId}/supporter-signatures`

| Method | Path | 용도 |
|---|---|---|
| POST | `/{signatureId}/affiliates` | 제휴 등록 |

---

## 3. Social (11 컨트롤러, ≈47 endpoints)
**상세**: [`api-details/social.md`](./api-details/social.md)

### 3.1 Follow (5 컨트롤러)

#### FollowV3Controller (`social/follow/FollowV3Controller.java:27`)
base: `/api/v3/social/{userId}/follows`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 팔로우 생성 |
| POST | `/{tgtUserId}` | 특정 유저 팔로우 |
| DELETE | `/{tgtUserId}` | 언팔로우 |

#### FollowV3UserController (`social/follow/FollowV3UserController.java:22`)
base: `/api/v3/users/{userId}/follows`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 팔로우 생성 |
| POST | `/{tgtUserId}` | 특정 유저 팔로우 |
| DELETE | `/{tgtUserId}` | 언팔로우 |

#### FollowOldController (`social/follow/FollowOldController.java:39`)
base: `/api/v1/users/followers` — 레거시

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 팔로우 생성 |
| POST | `/following` | following 등록 |
| POST | `/following/multi` | 다건 following |
| DELETE | `/{followNo}` | followNo로 삭제 |
| DELETE | `/drop/{targetUserId}` | target으로 드롭 |
| GET | `` | 팔로우 조회 |
| GET | `/getFollowUserIdsHavingActivityWithinDays` | 활동 있는 팔로우 userIds |
| GET | `/user/{userId}/{type}/recent-active` | 최근 활동 |
| GET | `/user/{userId}/following/user-id` | following userIds |
| GET | `/user/{userId}/following/user-info` | following 정보 |
| GET | `/user/{userId}/following/count` | following 수 |
| GET | `/user/{userId}/following/is-full` | 팔로잉 상한 |
| GET | `/user/{userId}/follower/user-id` | follower userIds |
| GET | `/user/{userId}/follower/user-info` | follower 정보 |
| GET | `/user/{userId}/follower/count` | follower 수 |
| GET | `/follower/{followerUserId}/following/{followingUserId}/follow-no` | 팔로우 번호 |
| GET | `/user/{userId}/follower/is-following` | is-following 확인 |
| GET | `/user/{userId}/following/birth-day/user-info` | 생일 팔로우 정보 |

#### DeprecatedRecommendController (`social/follow/DeprecatedRecommendController.java:16`) ⚠️ deprecated
base: `/api/v1/users/followers/recommendations`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 추천 목록 |
| POST | `/find/activate` | 활성 찾기 |

#### EventController (`social/follow/EventController.java:21`)
base: `/api/v1/users/followers/events`

| Method | Path | 용도 |
|---|---|---|
| POST | `` | 팔로우 이벤트 등록 |
| GET | `/{targetUserId}` | 타깃 이벤트 조회 |
| GET | `` | 이벤트 목록 |
| PUT | `` | 이벤트 수정 |

### 3.2 Block (2 컨트롤러)

#### UserBlockingController (`social/block/controller/UserBlockingController.java:22`)
base: `/api/v1/social/block`

| Method | Path | 용도 |
|---|---|---|
| GET | `` | 차단 목록 |
| GET | `/all` | 전체 |
| GET | `/userinfo` | 차단 유저 정보 |
| GET | `/userinfo/count` | 차단 수 |

#### BlockCommandController (`social/block/controller/BlockCommandController.java:19`)
base: `/api/v1/social`

| Method | Path | 용도 |
|---|---|---|
| POST | `/block` | 차단 |
| POST | `/unblock` | 차단 해제 |

### 3.3 Contact (2 컨트롤러)

#### UserAppContactV3UserController (`social/contact/UserAppContactV3UserController.java:21`)
base: `/api/v3/users/{userId}/contacts`

| Method | Path | 용도 |
|---|---|---|
| GET | `/information` | 연락처 정보 |

#### UserAppContactOldController (`social/contact/UserAppContactOldController.java:29`)
base: `/api/v1/users/contacts`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/{userId}/sync-allow` | 동기화 허용 |
| GET | `/{userId}/information` | 연락처 정보 |
| PUT | `/{userId}` | 연락처 업데이트 |
| DELETE | `/{userId}` | 연락처 삭제 |
| PUT | `/{userId}/my-number/reconnection` | 번호 재연결 |

### 3.4 Recommendation

#### RecommendationUserController (`social/recommendation/controller/RecommendationUserController.java:31`)
base: `/api/v1/social/recommendation/user`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/{userId}/allow-info` | 추천 허용 설정 |
| GET | `/{userId}/allow-info` | 추천 허용 조회 |
| POST | `/kakao/has-user` | 카카오 가입 여부 |
| POST | `/kakao/user-info` | 카카오 유저 정보 |
| POST | `/wadiz/user-info` | 와디즈 유저 정보 |
| POST | `/contacts/count` | 연락처 수 |
| POST | `/contacts/user-info` | 연락처별 유저 정보 |

### 3.5 Feed

#### FeedUserInfoController (`social/feed/controller/FeedUserInfoController.java:19`)
base: `/api/v1/users/feed/userInfo`

| Method | Path | 용도 |
|---|---|---|
| POST | `/get` | 피드용 유저 정보 배치 조회 |

---

## 4. Account (9 컨트롤러, ≈43 endpoints)
**상세**: [`api-details/account.md`](./api-details/account.md)

### UserAccountInfosController (`account/UserAccountInfosController.java:30`)
base: `/api/v1/users/accounts`

| Method | Path | 용도 |
|---|---|---|
| POST | `/{userId}/password/verification` | 비밀번호 검증 |
| GET | `/type/{accountType}/count` | 계정 유형별 수 |
| GET | `/detail/{userId}` | 상세 |
| GET | `/type/{accountType}` | 유형별 |
| GET | `/type/{accountType}/all` | 유형별 전체 |
| GET | `/type/initRealNameAuth` | 실명인증 초기화 |
| GET | `/type/joinLimitClear` | 가입 제한 해제 |
| GET | `/type/initMarketingParticipationHistory` | 마케팅 이력 초기화 |
| GET | `/{userId}/linkedSNS` | SNS 연동 조회 |
| GET | `/{userId}/social/link` | 소셜 링크 |
| POST | `/{userId}/social/{provider}` | 소셜 연결 |
| PUT | `/{userId}/social/friends-count` | 친구수 업데이트 |
| PUT | `/{userId}/social/profile` | 소셜 프로필 업데이트 |
| GET | `/{userId}/social/profile` | 소셜 프로필 조회 |
| PUT | `/{userId}/birth-day` | 생일 수정 |
| GET | `/{userId}/birth-day` | 생일 조회 |
| DELETE | `/{userId}/birth-day` | 생일 삭제 |

### FindAccountController (`account/FindAccountController.java:16`)
base: `/api/v1/users/accounts/find`

| Method | Path | 용도 |
|---|---|---|
| POST | `/realname/list` | 실명 기반 계정 목록 |
| POST | `/realname/unit` | 실명 단건 |

### UserLocaleController (`account/UserLocaleController.java:20`)
base: `/api/v1/users`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/{userId}/location`, `/{userId}/locale` | 로케일 설정 |
| GET | `/{userId}/location`, `/{userId}/locale` | 로케일 조회 |
| POST | `/locales`, `/locales/bulk` | 로케일 bulk |

### UserTimeZoneController (`account/UserTimeZoneController.java:26`)
base: `/api/v1/users`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{userId}/time-zone` | 시간대 조회 |
| PUT | `/{userId}/time-zone` | 시간대 설정 |
| PUT | `/{userId}/time-zone/by-country` | 국가로 설정 |
| GET | `/{userId}/time-zone/auto` | 자동 조회 |
| PUT | `/{userId}/time-zone/auto` | 자동 설정 |
| POST | `/time-zones` | bulk |

### UserAgeVerificationController (`account/UserAgeVerificationController.java:20`)
base: `/api/v1/users`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{userId}/age-verification` | 연령 인증 조회 |
| POST | `/age-verifications/bulk` | bulk 인증 |

### JoinEquityAccountController (`account/JoinEquityAccountController.java:15`)
base: `/api/v1/users/equity/join`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{encUserId}/mobile` | 모바일 가입 |
| GET | `/{encUserId}/promotion` | 프로모션 |
| GET | `/{encUserId}/virtual` | 가상 |
| GET | `/{encUserId}/type` | 유형 |
| GET | `/{encUserId}/step` | 단계 |
| GET | `/{encUserId}/status` | 상태 |

### ProfileImageController (`account/ProfileImageController.java:13`)
base: `/api/v1/users/profileImage`

| Method | Path | 용도 |
|---|---|---|
| GET | `/random` | 랜덤 프로필 |
| GET | `/random/user/{userId}` | 유저 랜덤 |
| GET | `/random/bulk` | 랜덤 bulk |
| GET | `/random/all` | 전체 |

### UserSettingsController (`account/UserSettingsController.java:14`)
base: `/api/v1/users/settings`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/{userId}/birth-day-display` | 생일 노출 설정 |
| GET | `/{userId}/birth-day-display` | 생일 노출 조회 |

### DropAccountController (`account/DropAccountController.java:24`)
base: `/api/v1/users/dropAccount`

| Method | Path | 용도 |
|---|---|---|
| POST | `/drop` | 탈퇴 |

---

## 5. Privacy (5 컨트롤러, ≈25 endpoints)
**상세**: [`api-details/misc-domains.md#privacy`](./api-details/misc-domains.md)

### CommonPrivacyController (`privacy/CommonPrivacyController.java:27`)
base: `/api/v1/users/commonPrivacy`

| Method | Path | 용도 |
|---|---|---|
| POST | `/findAccountStatus` | 계정 상태 조회 |
| POST | `/isInactivated/userName` | 휴면 여부 (이름) |
| POST | `/isInactivated/connectingInfo` | 휴면 여부 (CI) |
| POST | `/findAccountStatus/type/{findType}/value/{findValue}` | 타입별 조회 |
| DELETE | `/mobile-number` | 휴대폰 삭제 |

### DestructionPrivacyController (`privacy/DestructionPrivacyController.java:28`)
base: `/api/v1/users/destructionPrivacy`

| Method | Path | 용도 |
|---|---|---|
| POST | `/find/schedule` | 파기 스케줄 |
| GET | `/find/overdue` | 기한 초과 |
| POST | `/find/keywords` | 키워드 조회 |
| POST | `/register` | 파기 등록 |
| PUT | `/modify` | 수정 |
| PUT | `/destruct` | 파기 실행 |

### InactiveAccountController (`privacy/InactiveAccountController.java:27`)
base: `/api/v1/users/inactiveAccount`

| Method | Path | 용도 |
|---|---|---|
| POST | `/isInactivated` | 휴면 여부 |
| POST | `/find/inactiveAccounts` | 휴면 목록 |
| POST | `/find/inactiveAccounts/drop` | 휴면 드롭 대상 |
| POST | `/inactivate` | 휴면 전환 |
| POST | `/reactivate` | 재활성 |
| POST | `/isDuplicateUserName` | 이름 중복 |
| POST | `/isValidForInactiveAccount` | 휴면 검증 |
| POST | `/modifyPassword` | 비밀번호 수정 |
| GET | `/retroactive/{referenceTime}` | 소급 조회 |
| POST | `/retroactive/{userId}` | 소급 처리 |

### DecodingAccountReactivateController (`privacy/DecodingAccountReactivateController.java:26`)
base: `/api/v1/users/privacy/decoding`

| Method | Path | 용도 |
|---|---|---|
| POST | `/reactivate` | 디코딩 후 재활성 |

### PrivacyDropoutController (`privacy/PrivacyDropoutController.java:23`)
base: `/api/v1/users/privacy/dropout`

| Method | Path | 용도 |
|---|---|---|
| DELETE | `/manual` | 수동 탈퇴 |
| DELETE | `/manual/user` | 수동(user) |
| DELETE | `/inactivated` | 휴면자 탈퇴 |
| DELETE | `/leftover-inactivated` | 잔여 휴면 정리 |

---

## 6. Terms (2 컨트롤러, ≈10 endpoints)

### TermsController (`terms/controller/TermsController.java:25`)
base: `/api/v1/users/terms`

| Method | Path | 용도 |
|---|---|---|
| GET | `/service` | 서비스 약관 |
| GET | `/accepter/{userId}` | 동의 이력 |
| GET | `/service/{serviceCode}/accepter/{userId}` | 서비스별 동의 |
| POST | `/accepter/{userId}` | 약관 동의 |
| POST | `/reject/{userId}` | 약관 거부 |
| DELETE | `/accepter/{userId}` | 동의 취소 |
| GET | `/marketing/accepter/{userId}` | 마케팅 동의 |
| GET | `/marketing/{serviceCode}/accepter/{userId}` | 서비스별 마케팅 |
| GET | `/marketing/accepter/{userId}/history` | 마케팅 이력 |

### TermsV2Controller (`terms/controller/TermsV2Controller.java:26`)
base: `/api/v2/terms`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{flowType:signup}` | 가입 플로우 약관 |

---

## 7. Coupon · Message · Push · Verification · Maker · Link · SourcingClub · Session · Event · CatchUp

### IssueCouponController (`coupon/controller/IssueCouponController.java:17`)
base: `/api/v1/users/coupon`

| Method | Path | 용도 |
|---|---|---|
| POST | `/user/{userId}/type/{couponType}` | 쿠폰 발급 |

### MessageController (`message/MessageController.java:18`)
base: `/api/v1/users/message`

| Method | Path | 용도 |
|---|---|---|
| POST | `/alim-talk/receiver/{userId}/sign-up` | 알림톡 수신자 등록 |

### PushTargetController (`push/PushTargetController.java:17`)
base: `/api/v1/users/pushTarget`

| Method | Path | 용도 |
|---|---|---|
| POST | `/count` | 푸시 대상 수 |
| POST | `/list` | 푸시 대상 목록 |

### BankController (`verification/bankaccount/BankController.java:38`)
base: `/api/v1/users/verifications/bankaccounts`

| Method | Path | 용도 |
|---|---|---|
| GET | `/banklist` | 은행 목록 |
| GET | `/bankCode/{bankCode}/bankAccount/{bankAccount}` | 계좌 정보 |
| POST | `/transfer/penny` | 1원 송금 |
| POST | `/transfer/penny/answer` | 1원 인증 답변 |
| GET | `/transfer/penny/summation/userId/{userId}` | 1원 집계 |
| GET | `/transfer/penny/answerLog/pennyTransferNo/{pennyTransferNo}` | 1원 로그 |
| PUT | `/transfer/penny/reset` | 1원 리셋 |
| GET | `/bankAccount/withdrawAccount/userId/{userId}` | 출금계좌 조회 |
| POST | `/bankAccount/withdrawAccount` | 출금계좌 등록 |
| POST | `/bankAccount/corpWithdrawAccount` | 법인 출금계좌 |

### MakerInfoController (`maker/MakerInfoController.java:18`)
base: `/api/v1/makers`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/{userId}/language` | 언어 설정 |
| GET | `/{userId}/language` | 언어 조회 |
| POST | `/languages`, `/languages/bulk` | bulk |

### UserLinkController (`link/UserLinkController.java:27`)
base: `/api/v1/link`

| Method | Path | 용도 |
|---|---|---|
| GET | `/me/{me}/follow` | 내 팔로우 링크 |
| GET | `/action/recently` | 최근 활동 |
| GET | `/action/{userId}/follow/project` | 팔로우 기반 프로젝트 |

> ℹ️ `kr.wadiz.user.link` (Neo4j 서비스)로 proxy되는 성격. 자세한 호출 체인은 `docs/kr.wadiz.user.link.md` 참조.

### SourcingClubController (`sourcingclub/controller/SourcingClubController.java:29`)
base: `/api/v1/sourcing-club`

| Method | Path | 용도 |
|---|---|---|
| GET | `/members/{userId}` | 멤버 조회 |
| POST | `/members/{userId}` | 멤버 등록 |

### SessionManagerController (`session/SessionManagerController.java:15`)
base: `/api/v1/users/session`

| Method | Path | 용도 |
|---|---|---|
| GET | `/{JSESSIONID}/role` | 세션 역할 |
| GET | `/{JSESSIONID}/role/bypass` | 역할 bypass |

### 초대 이벤트 (Event/Invite, 5 컨트롤러, ≈14 endpoints)

#### InviteEventManagerController (`event/controller/InviteEventManagerController.java:16`)
base: `/api/v1/users/event/invite`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/` | 이벤트 갱신 |
| GET | `/list` | 이벤트 리스트 |
| GET | `/` | 이벤트 정보 |

#### InviteEventInfoController (`event/controller/InviteEventInfoController.java:19`)
base: `/api/v1/users/event/invite`

| Method | Path | 용도 |
|---|---|---|
| GET | `/valid/{inviteCode}` | 코드 유효성 |
| GET | `/find/{inviteCode}` | 코드로 조회 |
| GET | `/page/apply/{inviteCode}` | 신청 페이지 |
| GET | `/page/view` | 뷰 페이지 |
| GET | `/page/image` | 이미지 |

#### InviteEventUserController (`event/controller/InviteEventUserController.java:16`)
base: `/api/v1/users/event/invite`

| Method | Path | 용도 |
|---|---|---|
| GET | `/owner/{encUserId}` | owner 조회 |
| PUT | `/owner/{encUserId}` | owner 수정 |
| PUT | `/apply/{encUserId}` | 신청 |

#### InviteEventRewardController (`event/controller/InviteEventRewardController.java:16`)
base: `/api/v1/users/event/invite/reward`

| Method | Path | 용도 |
|---|---|---|
| PUT | `/owner` | owner 보상 |
| PUT | `/applicant` | 신청자 보상 |

#### InviteEventV2Controller (`event/v2/controller/InviteEventV2Controller.java:23`)
base: `/api/v2/users/event/invite`

| Method | Path | 용도 |
|---|---|---|
| GET | `/user/{userId}/code` | 초대 코드 |

### CatchUp (1 컨트롤러, 12 endpoints)

#### CatchUpController (`catchup/adapter/in/CatchUpController.java:27`)
base: `/api` — 헥사고날 adapter, v1/v2/v3 혼재

| Method | Path | 용도 |
|---|---|---|
| GET | `/v1/users/{userId}/catchup/today/status` | 오늘 캐치업 상태 |
| GET | `/v1/users/{userId}/catchup/today` | 오늘 캐치업 |
| POST | `/v1/users/{userId}/catchup/today` | 오늘 캐치업 기록 |
| GET | `/v1/users/{userId}/catchup/days` | 캐치업 일수 (v1) |
| GET | `/v2/users/{userId}/catchup/days` | v2 |
| GET | `/v3/users/{userId}/catchup/days` | v3 |
| GET | `/v1/users/{userId}/catchup/history` | 이력 |
| PUT | `/v1/users/{userId}/catchup/notification` | 알림 설정 |
| GET | `/v1/users/{userId}/catchup/notification` | 알림 조회 |
| POST | `/v1/users/bulk/catchup/complete` | bulk 완료 |
| GET | `/v1/catchup/event/active` | 활성 이벤트 |
| POST | `/v1/catchup/event/cache/evict` | 캐시 무효화 |

---

## 통계

| 도메인 | 컨트롤러 | 엔드포인트 (약) | 상세 파일 |
|---|---|---|---|
| Supporter Signature V1 | 6 | 37 | signature-v1.md |
| Supporter Signature V3 | 11 | 37 | signature-v3.md |
| Social (follow/block/contact/recommendation/feed) | 11 | 47 | social.md |
| Account | 9 | 43 | account.md |
| Privacy | 5 | 25 | misc-domains.md |
| Terms | 2 | 10 | misc-domains.md |
| Coupon·Message·Push·Bank·Maker·Link·SourcingClub | 7 | 22 | misc-domains.md |
| Session | 1 | 2 | (미할당, Phase 2 추가 대상) |
| Event Invite | 5 | 14 | (미할당, Phase 2 추가 대상) |
| CatchUp | 1 | 12 | (미할당, Phase 2 추가 대상) |
| **합계** | **58** | **≈249** | — |

> ⚠️ **Phase 2 미할당 영역**: `session/`, `event/invite/`, `catchup/` 은 초기 도메인 분류에서 빠졌습니다. 별도 detail 파일(`session-event-catchup.md`)을 추후 추가 예정.
