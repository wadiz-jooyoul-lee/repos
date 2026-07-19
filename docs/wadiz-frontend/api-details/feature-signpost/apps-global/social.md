> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

# 소셜 / 친구추천 (Social / Refer-a-Friend)

> 친구 초대 이벤트(`refer-a-friend`), 소셜 친구 관리(`social/friends`), 지지서명(`social/support-share` + `packages/features/src/support-share`), 초대 코드, OneLink 공유 유틸. 소셜 공유 공통 문구는 i18n `social_share_section_component`, 소셜 모달은 대부분 **하드코딩**.

## 친구 초대 / 친구 추천 (Refer-a-Friend)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 친구 초대하기 메인 — `refer_a_friend_page.content.title`="친구 초대하면 나도 친구도 {n}원 포인트" / EN "Earn {n}P for Every Referral", header "친구 초대하기" | `apps/global/src/pages/refer-a-friend/ReferAFriendPage.tsx` |
| 초대 링크 공유 섹션 — `share_section`: "지금 친구 초대하기", "복사하기", "문자", 토스트 "초대 링크를 복사했어요!" | `apps/global/src/pages/refer-a-friend/_ui/ShareButtonSection/ShareButtonSection.tsx` |
| 이벤트 유의사항 — `guideline_article.title`="꼭 읽어 주세요!" | `apps/global/src/pages/refer-a-friend/_ui/NoticeSection/NoticeSection.tsx` |
| 초대받은 친구 랜딩 — `refer_a_friend_invitation_page.content.title`="{name} 님이 와디즈에 초대하셨어요", "지금 포인트 받기" | `apps/global/src/pages/refer-a-friend/invitation/ReferAFriendInvitationPage.tsx` |
| 초대 랜딩 액션 — "초대 코드 복사하기", "와디즈 둘러보기" / 와디즈 소개 "펀딩하기 🎁" | `apps/global/src/pages/refer-a-friend/invitation/_ui/{PageActions,AboutWadizSection}/` |

## 초대 코드 (Invitation Code)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 초대 코드 입력 섹션 — `invitation_code_section_component.header.title`="친구 초대 코드 입력", placeholder "초대 코드 입력", "참여하기", 성공 "포인트 지급을 완료했어요." | `packages/features/src/invitation-code/ui/InvitationCode.tsx` |
| 이벤트/광고 배너 (ADS 응답 동적 title, "AD" 뱃지) | `packages/features/src/invitation-code/ui/event-banner/EventBanner.tsx` |

## 소셜 친구 — 팔로잉/팔로워/차단

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 팔로잉 통합 화면 — `social_friends_page.header.title`="팔로잉" | `apps/global/src/pages/social/friends/_ui/MyFriends.tsx` |
| 팔로잉 메이커 목록 — `social_friends_following_makers_page`: "팔로잉 메이커", "팔로우한 메이커가 없어요" | `apps/global/src/pages/social/friends/following/makers/_ui/FollowingMaker.tsx` |
| 팔로잉 서포터/팔로워 목록 (`social_friends_following_supporters_page`, `social_friends_followers_page`) | `apps/global/src/pages/social/friends/{following/supporters,followers}/_ui/` |
| 차단 서포터 관리 — `social_friends_blocked_page`: "차단 서포터", "차단"/"차단 해제", 토스트 "차단했어요." | `apps/global/src/pages/social/friends/blocked/_ui/BlockedSupporterCard.tsx` |

## 소셜 모달 — 친구 찾기 (하드코딩)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 연락처 친구 찾기 모달 — **하드코딩** "연락처로 친구 찾기", "'연락처로 친구 찾기' 선택시 연락처가 저장되고 친구 추천에 사용됩니다." | `packages/features/src/social-modal/ui/SocialModal.jsx` |
| 전체화면 친구 찾기 모달 — **하드코딩** "와디즈를 이용하는 친구를 찾아보세요!" | `packages/features/src/social-modal/ui/SocialModalFull.jsx` |
| 지지서명 유입용 친구 찾기 모달 — **하드코딩** "내 지지서명으로 친구가 참여하면 결제 금액의 1%를 포인트로 받아요." | `packages/features/src/social-modal/ui/SignatureSocialModal.jsx` |

## 지지서명 (Support Share)

관련 이슈: `FE1-291`(레거시 정리·api 버전 교체), `FE1-311`(포인트 조회 api 제한), `FE1-452`(비로그인 returnURL 수정), `FE1-519`(공유 링크 UTM 프로젝트 ID)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 지지서명 포인트 가이드 — `social_support_share_guide_page`: "포인트 받는 방법", "지지서명 공유하고 포인트 받으세요", "지지서명하러 가기" | `apps/global/src/pages/social/support-share/guide/_ui/SupportShareGuide.tsx` |
| 나의 지지서명 활동 (포인트 요약/카드) — `social_support_share_activity_page`: "나의 지지서명", "총 {n}P 누적", "내 공유로 {n}명이 구매했어요", "지급 완료/예정" | `apps/global/src/pages/social/support-share/activity/_ui/{MyPointSummarySection,PointCard}.tsx` |
| 지지서명 상세 — `social_support_share_detail_page`: "지지서명 상세", "프로젝트 참여하기"/"URL 공유하기", "이 링크로 친구가 결제하면 결제금액의 {n}%가 적립돼요." | `apps/global/src/pages/social/support-share/[supportShareNo]/_ui/SupportShareDetail.tsx` (+ `MySupportShareCount.tsx`) |
| 펀딩 상세 지지서명 배너 — `funding_detail_page.support_and_share_section`: "{n}명이 지지서명했어요", "나의 지지서명 공유하기"/"지지서명 하기" | `packages/features/src/support-share/ui/SupportShareBanner.tsx` (+ `SupportShareIconButton.tsx`) |
| 지지서명 공유 모달 (SNS/링크 복사) — `support_share_share_modal`: "이 링크로 결제하면 {n}% 적립", "링크 복사가 완료되었어요!" | `packages/features/src/support-share/ui/SupportShare/ui/SupportShareModal.tsx` (+ `lib/useSupportShareSnsList.ts`) |
| 결제완료 지지서명 유도 섹션 — `funding_payment_completed_page.support_and_share_section`: "나만 알고 있기 아까운 프로젝트라면?", "포인트를 받아보세요" | `packages/features/src/support-share/ui/SupportShare/ui/OrderCompleteSupportShareSection.tsx` |
| 지지서명 작성/수정 모달 — `support_share_write_modal`: "친구에게 소개하고 1% 포인트 받기", "응원의 글을 남겨주세요.", "작성 완료" | `packages/features/src/support-share/ui/SupportShareRegister.tsx` (+ `Edit/SupportShareEditForm.tsx`) |
| 지지서명 포인트 적립 배너 — **하드코딩** "지지서명 공유로 {n}P 적립중", "지지서명으로 최대 50,000P 받는 방법" | `packages/features/src/support-share/ui/SupportSharePointBanner/SupportSharePointBanner.tsx` |

## 공유 유틸 (OneLink)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| AppsFlyer OneLink 공유 URL 생성 / 조회 훅 / 앱 미설치 리다이렉트 (UI 문구 없음) | `packages/features/src/onelink/{onelink.ts,useOnelink.ts,useAppInstallRedirect.ts}` |

## 이슈 히스토리 (소셜/친구추천 경로)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-291 | 작업 | [Web] 지지서명 관련 레거시 코드 정리 및 api 버전 교체 |
| FE1-311 | 작업 | [Web] 나의 지지서명 상세가 아닌 경우 지지서명 포인트 조회 api 호출 제한 |
| FE1-452 | 버그 | [Web] 지지서명 비로그인시 로그인 시도할때 returnURL이 잘못 들어가는 부분 수정 |
| FE1-519 | 작업 | [Web] 지지서명 공유 링크 UTM에 프로젝트 ID(utm_content) 추가 |
| FE1-716 | 버그 | [Web] platform > share API 이용해 생성한 원링크가 동작하지 않는 문제 |
| FE2-178 | 작업 | [FE2] WAi for Supporter P2 - 메이커센터 |

---
