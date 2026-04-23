# `com.wadiz.adm` — 프로모션 · 배너 · 팝업 · 메일 · 푸시 · 알림 · 이벤트 컨트롤러

> **기록 시각**: 2026-04-20
> **대상 repo**: `com.wadiz.adm` (레거시 전사 어드민, Spring 3.2 / Java 8 / JSP / WAR)
> **대상 레이어**: `com.wadiz.web.**.controller` (프로모션/마케팅/알림 운영 계열만)

---

## 1. 기록 범위

이 문서는 **운영자가 마케팅·알림·이벤트를 발송·관리하는 관리자 화면·API**만 다룬다.
일반 쿠폰 발급, 포인트, 스타트업 투자 IR 등은 다른 문서에서 다룬다.
각 컨트롤러는 대부분 `ModelAndView`(JSP 화면) + `@ResponseBody` ajax 혼합형이고, DB는 MyBatis(`com.wadiz.core.*` 패키지), 외부 호출은 `wave.notification`/`wave.user`/`api.reward` 지원 모듈을 통해 이루어진다.

---

## 2. 개요 — 운영 마케팅 전반

`com.wadiz.adm`은 와디즈 운영팀이 **프로모션/배너/팝업/메일/푸시/알림/이벤트/제휴**를 관리하는 **통합 관제 대시보드** 역할을 한다. 구조적 특징:

- **세 계층의 "프로모션" 혼재**
  - `/promotion/api` (`PromotionController`): **리워드 쿠폰 ↔ 이벤트 프로모션** 매핑용 신형 JSON API (`api.reward.support.ResponseWrapper`)
  - `/wbenefit/*` (`WEBPromotionController`): **프로모션 코드(`PromotionCode`) 발급·엑셀·참여자 관리** 구형 JSP/ajax
  - `wbenefit`과 `waccount/marketingparticipation`이 **MarketingParticipation** 엔티티를 공유 (`com.wadiz.core.waccount.model.MarketingParticipation`)

- **배너는 지면 개념**
  - `WEBBannerSectionController` = **지면(BannerSection) + 배너(BannerCommon) + 와디즈캐스트 진입구** 통합. PC·모바일 공용
  - `WEBCampaignController` = **구(舊) 메인 배너** (PC 메인/모바일 메인/앱 메인 3종) + 메인 검색어 키워드 (구형; 대부분 `WEBBannerSectionController`와 `wadiz-frontend` 쪽으로 이관 중)
  - `WEBMobileBannerController` = **앱 이벤트 배너** (`MobileBannerEvent`, 독립 테이블)

- **팝업은 JSON API**
  - `PopupMainController`(`/popup/*`)는 **`NoticePopup`** (NPA 태그 기반) 한 종만 관리하며, `EquityW9ContentsOrder` import가 남아 있어 투자형 W9 팝업 연관이 있음

- **메일은 6개 컨트롤러로 분리**
  1. `WEBMailController` — 루트 진입 + GroupType/UsersType enum 제공
  2. `WEBMailLogController` — **발송 이력·오픈/클릭 통계** (`wave.notification.model.mails`)
  3. `WEBMailReservationController` — **예약 발송** (회원/엑셀 대상)
  4. `WEBMailSendingController` — **즉시 발송** (테스트/배치/엑셀) + Slack 알림 병행 + `AtomicBoolean` 중복발송 잠금
  5. `WEBMailTemplateController` — **템플릿 CRUD + 이미지 업로드**
  6. `WEBMarketingMailController` — **구형 마케팅 메일 목록·상세** (`@Deprecated`)

- **푸시는 3개 컨트롤러로 분리**
  1. `AppPushController`(`/appPush`) — **서포터 푸시 예약** (조건형/파일형/타깃그룹형 3종), `PushTargetApiAdapter`/`EquityServiceAdapter` 연동 (광고성 플래그 `isAds=true` 고정)
  2. `MobilePushController`(`/mobile`) — **일반 모바일 푸시 메시지**(MobilePushMessage) CRUD·진행상태
  3. `WEBAppController` — **레거시 app push**(`AppPush`) CRUD + 관리자 웹앱 엔트리포인트 (`/app/mailsystem/`, `/app/store/**`, `-/**`)

- **알림(Notification)은 프록시**
  - `NotificationController`(`/api/notification/*`)는 **사용자 인증(`@CheckUserLogin`) 후 `/api/v1/notification/*`로 단순 릴레이**하는 BFF 역할 (→ `wave.notification` 또는 `co.wadiz.api.community` 쪽 서버)
  - `NotificationViewController` = `front/main` SPA 진입 라우트만

- **이벤트**
  - `EventViewController` + `InviteEventViewController` = **React SPA 진입 라우터**(`front/main` JSP 재사용)
  - `InviteEventController`(`/event/api/invite`) = **친구초대 이벤트** 등록·조회 API (이미지 2종 업로드 + 리워드 템플릿 매핑, `wave.user.support.ResponseWrapper`)

- **마케팅 수신동의·조회**
  - `WEBMarketingParticipationController`(`/waccount/marketingparticipation`) — **프로모션 키별 참여자 조회/삭제** (수신동의 이력)
  - `WEBDmAccountController`(`@Deprecated`) — DM 수신동의 이력(`SubscriberAllowAdsLog`) 조회. `wSidebar.jsp` 메뉴에서는 이미 제거됨
  - `UserMarketingInfoController`(`/account/marketingInfo/*`) — 설문조사(`MCD_SURVEY0001`) 기반 **마케팅활용정보·소득 문항**(INCOME_QUESTION_NO=2) 조회
  - `WEBMailController`의 GroupType/UsersType enum이 **수신그룹 UI 기준**을 정의

- **제휴 광고**
  - `CriteoController`(`/affiliation/*`) — **Criteo 동적 리타겟팅 피드**에서 특정 캠페인 숨김/복원 (`CriteoFeedExcludeDto`)

---

## 3. 컨트롤러 목록

| # | 컨트롤러 | 경로 | 형태 | 파일 |
|---|---|---|---|---|
| 1 | `PromotionController` | `/promotion/api/**` | JSON API (Swagger) | `com/wadiz/web/promotion/controller/PromotionController.java` |
| 2 | `WEBPromotionController` | `wbenefit/promotion*` | JSP + ajax | `com/wadiz/web/wbenefit/controller/WEBPromotionController.java` |
| 3 | `WEBCampaignController` | `campaign/**` | JSP + ajax | `com/wadiz/web/campaign/controller/WEBCampaignController.java` |
| 4 | `WEBCampaignCommentController` | `/wcampaign/*` | JSP + 엑셀 | `com/wadiz/web/campaign/controller/WEBCampaignCommentController.java` |
| 5 | `WEBCampaignInvestInSideController` | `campaign/*InvestInSide*` | ajax | `com/wadiz/web/campaign/controller/WEBCampaignInvestInSideController.java` |
| 6 | `UploadFileController` | `campaign/upload*` | ajax | `com/wadiz/web/campaign/controller/UploadFileController.java` |
| 7 | `WEBBannerSectionController` | `campaign/banner*, campaign/bannerSection*, campaign/wadizCastIntro*` | JSP + ajax | `com/wadiz/web/campaign/controller/WEBBannerSectionController.java` |
| 8 | `PopupMainController` | `/popup/**` | JSON API | `com/wadiz/web/popup/controller/PopupMainController.java` |
| 9 | `WEBMobileBannerController` | `/app/banner/*` | JSP + ajax | `com/wadiz/web/app/banner/controller/WEBMobileBannerController.java` |
| 10 | `AppPushController` | `appPush/**` | JSP + ajax | `com/wadiz/web/app/push/controller/AppPushController.java` |
| 11 | `MobilePushController` | `mobile/push*` | JSP + ajax | `com/wadiz/web/app/push/controller/MobilePushController.java` |
| 12 | `WEBAppController` | `app/**, -/**` | JSP + ajax | `com/wadiz/web/app/push/controller/WEBAppController.java` |
| 13 | `WEBMailController` | `/mail/**` (루트/enum) | JSP + JSON | `com/wadiz/web/mail/controller/WEBMailController.java` |
| 14 | `WEBMailLogController` | `/mail/log/**` | JSP + JSON | `com/wadiz/web/mail/controller/WEBMailLogController.java` |
| 15 | `WEBMailReservationController` | `/mail/reservation/**` | JSP + ajax | `com/wadiz/web/mail/controller/WEBMailReservationController.java` |
| 16 | `WEBMailSendingController` | `/mail/send/**` | ajax | `com/wadiz/web/mail/controller/WEBMailSendingController.java` |
| 17 | `WEBMailTemplateController` | `/mail/template/**` | ajax | `com/wadiz/web/mail/controller/WEBMailTemplateController.java` |
| 18 | `WEBMarketingMailController` (`@Deprecated`) | `/marketing/mailService/**` | JSP + ajax | `com/wadiz/web/mail/controller/WEBMarketingMailController.java` |
| 19 | `NotificationController` | `/api/notification/**` | JSON 프록시 | `com/wadiz/web/notification/controller/NotificationController.java` |
| 20 | `NotificationViewController` | `/notification/send-result/**` | SPA 라우트 | `com/wadiz/web/notification/controller/NotificationViewController.java` |
| 21 | `WEBSendController` | `send/*` | JSP + ajax | `com/wadiz/web/send/controller/WEBSendController.java` |
| 22 | `EventViewController` | `/event/big-unique-brand-v2/**` | SPA 라우트 | `com/wadiz/web/event/controller/EventViewController.java` |
| 23 | `InviteEventController` | `/event/api/invite/**` | JSON API (Swagger) | `com/wadiz/web/wevent/invite/controller/InviteEventController.java` |
| 24 | `InviteEventViewController` | `event/invitation/**` | SPA 라우트 | `com/wadiz/web/wevent/invite/controller/InviteEventViewController.java` |
| 25 | `WEBMarketingParticipationController` | `/waccount/marketingparticipation/**` | JSP + ajax | `com/wadiz/web/waccount/controller/WEBMarketingParticipationController.java` |
| 26 | `WEBDmAccountController` (`@Deprecated`) | `/waccount/dm/**` | JSP + ajax | `com/wadiz/web/waccount/controller/WEBDmAccountController.java` |
| 27 | `UserMarketingInfoController` | `/account/marketingInfo/*` | JSP | `com/wadiz/web/account/controller/UserMarketingInfoController.java` |
| 28 | `CriteoController` | `/affiliation/**` | JSP + ajax | `com/wadiz/web/affiliation/criteo/controller/CriteoController.java` |

---

## 4. 도메인 섹션

### 4.1 Promotion / wCampaign (`PromotionController`, `WEBPromotionController`, `WEBCampaign*Controller`)

- **리워드 쿠폰 프로모션** (`PromotionController.java:34~126`)
  - `POST /promotion/api/templates/{templateNo}` — 쿠폰(`templateNo`)에 이벤트 프로모션 **생성 + 바로 적용**
  - `POST /promotion/api/templates/{templateNo}/events/{eventNo}` — 기존 이벤트를 쿠폰에 **추가 매핑** (`SaveRewardEventBenefitMappingQuery.benefitKey = templateNo`)
  - `PUT /promotion/api/events/{eventNo}` — 이벤트 수정
  - `DELETE /promotion/api/templates/{templateNo}/events/{eventNo}` — 쿠폰↔이벤트 연결 해제
  - `GET /promotion/api/templates/{templateNo}` — 쿠폰에 걸린 프로모션 목록 / `GET /promotion/api/{keyword}` — 키워드 단건 조회
  - 예외는 **`IllegalArgumentException → 400`, `Exception → 500`** 으로 직접 매핑하고 `ResponseWrapper.success(null)` 쉘에 상태만 얹는 관용 패턴 사용

- **프로모션 코드 발급·엑셀** (`WEBPromotionController.java:74~215`)
  - `wbenefit/promotionList` — 참여자(`PromotionJoinUserInfoDto`) 페이징 조회 + `siteUrl` 주입
  - `wbenefit/promotionListExcel`, `wbenefit/promotionPartListDown` — 엑셀 다운로드 (`CCI.DWLD_EXCEL_*` 컬럼 스키마), 후자는 `@Auditable(OperationType.EXCEL_DOWNLOAD)` 감사 로그 기록
  - `wbenefit/popPromotionPartDetail`, `wbenefit/promotionPartInfoList` — jqGrid 기반 부분 목록
  - `wbenefit/promotionCode`, `wbenefit/ajaxRegisterPromotionCode` — **프로모션 코드 발급** (`PROMOTION_EVENT_TYPE = {"REWARD","EQUITY"}` 2종)

- **캠페인 댓글·피드백 감사** (`WEBCampaignCommentController.java:63~180`, `/wcampaign/*`)
  - `equityFeedback`, `equityUpdateComment` — **투자형** 피드백·새소식 댓글 페이지 (페이지당 15)
  - `downloadExcelEquityFeedback`, `downloadExcelEquityUpdateComment` — 실명 보강(`accountService.getRealName`) 후 엑셀 다운로드
  - 운영자가 **커뮤니티 모니터링 + 발언자 본인확인**용으로 쓰는 뷰

- **인사이드·업로드·기타** (`WEBCampaignController`, `WEBCampaignInvestInSideController`, `UploadFileController`)
  - `campaign/search` — 캠페인 타이틀 검색(UTF-8 URL decode)
  - `campaign/keyword/search` / `campaign/keyword/regist` — **메인 검색어 키워드** 등록 (`MainSearchKeyword` 단건)
  - `campaign/banner`, `.../mobile/banner`, `.../app/banner` — 구형 PC/모바일/앱 메인 배너 3종 등록·수정 (`ajaxRegistBanner`/`ajaxRegistMobileMain`/`ajaxRegistAppMain` + `banner` MultipartFile)
  - `campaign/campaignInvestInSideMngr`, `campaign/ajaxRegisterInSide`, `campaign/ajaxUploadInsideImg` — 투자 인사이드 등록·이미지 변경
  - `campaign/uploadImage`, `campaign/uploadAttachFile` — 프로젝트 무관 단순 업로드 (`FTFileService`, 첨부는 다운로드 URL `/{site_url}/web/ftcampaign/download/attach?encFileId=...` 생성)

### 4.2 Banner / Popup (`WEBBannerSectionController`, `WEBMobileBannerController`, `PopupMainController`)

- **지면(BannerSection) 관리** (`WEBBannerSectionController.java:54~150`)
  - `campaign/bannerSectionList` — 지면 목록 + `codeService.getCommonCodeList("BannerSectionCategory")` 카테고리 주입
  - `popRegistBannerSection`/`popModifyBannerSection` — 등록·수정 팝업 + `ajaxRegistBannerSection`/`ajaxModifyBannerSection`/`ajaxRemoveBannerSection`

- **배너(BannerCommon) 관리** (`WEBBannerSectionController.java:158~407`)
  - `campaign/bannerCommonList` — 지면별 **노출/비노출** 배너 쿼리(`searchSelect3=Y|N`) 분리 조회, `translateUrl`·`translateToken` 주입(번역 서비스 연동)
  - 이미지/동영상: `ajaxRegistBannerImage`, `ajaxRegisterBannerClip`, `ajaxModifyBannerImage`, `ajaxModifyBannerClip`
  - `ajaxGetRewardTitle`, `ajaxGetInvestCoreMessage` — 배너에 연결할 **리워드 제목 / 투자 코어메시지** 조회
  - `ajaxModifyBannerOrderNo(bannerSeqArr[], orderNoArr[])` — 순서 일괄 변경
  - `campaign/wadizCastIntroList`, `ajaxModifyWadizCastList` — **와디즈 캐스트 진입구 P1/P2/P3** 3존(bannerType) 일괄 순서 갱신

- **앱 이벤트 배너** (`WEBMobileBannerController.java:33~95`, `/app/banner/*`)
  - `list`, `{seq}/modify`, `POST modify`, `modify/upload` — CRUD + 이미지 업로드, `LinkType` enum을 뷰에 주입(딥링크/외부링크)

- **공지 팝업(NPA)** (`PopupMainController.java:33~67`, `/popup/*`)
  - `GET /popup/list`, `GET /popup/detail?id=`, `POST /popup/update`
  - `updateNoticePopup`에서 `createNew=true`인 경우 **NPA 태그 자동 생성**: `targetSection + "_" + yyyyMMddHHmi` (`PopupMainController.java:62~65`)
  - BindingResult 검증 블록은 주석 처리되어 있음 → 실질적으로 **서버 측 유효성 검사 없음**

### 4.3 Mail (6종)

모든 컨트롤러가 공통적으로 `wave.notification.model.mails.*` 모델과 `CommonAjaxResDto` 래퍼를 사용.

- **`WEBMailController`** (`/mail/*`, 파일:`mail/controller/WEBMailController.java`)
  - `GET /mail/v2` → `marketing/marketingMailServiceVer2.0`, `GET /mail/builder` → `marketing/marketingMailServiceBuilder`
  - `GET /mail/group` / `GET /mail/group/users` — **수신그룹·사용자유형 enum** JSON 제공 (`GroupType`, `UsersType`)

- **`WEBMailLogController`** (`/mail/log/**`)
  - `GET /mail/log` — 정책코드(`NotificationPolicyCode` 기본 `DM00`)별 발송 목록, `MailSentWholeInfo`
  - `GET /mail/log/transactionKey/{key}` — 상세 페이지
  - 4종 JSON 통계: `mailsQty`, `readQtyStatistics` (30분 단위 오픈), `elapsedTime`, `linkTrackingList`
  - `GET /mail/log/priority/fast` — **fast priority** 발송내역 (기간·수신자 필터, 기본 오늘, `MailLogJoinMailLogTitleMapping`)

- **`WEBMailReservationController`** (`/mail/reservation/**`)
  - `POST /mail/reservation/` — 회원 기준 배치 예약(`MailBatchInfo` + `reservationDateTime` "yyyy-MM-dd HH mm")
  - `GET /mail/reservation/list` — 예약 목록. `MailReservationTargetType` 이 `USERS` 또는 `NEWS_MAKER` 인 경우만 타깃 이름을 **`CCI.accntType.get(targetKey)` / "리워드 뉴스레터" / "투자 뉴스레터"** 로 치환, 그 외엔 "엑셀 업로드"
  - `POST /mail/reservation/ajaxReservationCancel` — 예약 취소
  - `POST /mail/reservation/excel` — 엑셀 업로드 기반 예약 (`reserveExcel(templateNo, excel, isInfoExcel, date)`)

- **`WEBMailSendingController`** (`/mail/send/**`)
  - `POST /mail/send/test` — 테스트 메일 + Slack 알림(`host_slack_mail_marketing`)
  - `POST /mail/send/batch` — 와디즈 회원 대상 배치; **`AtomicBoolean isInvokeBatch`** 로 중복 발송 방어 (`WEBMailSendingController.java:56~109`); 실패 시 `host_slack_service_monitoring` Slack 경고
  - `GET /mail/send/batch/counts` — `selectTargetUserProfile(subscriber)` 로 사전 카운팅
  - `POST /mail/send/excel` — 엑셀 업로드 발송 (`isInvokeExcel` 별도 잠금)
  - 모든 엔드포인트가 `WEBSessionUtil.getUserInfo()` 로 로그인 강제

- **`WEBMailTemplateController`** (`/mail/template/**`)
  - `GET /mail/template/list`, `GET /mail/template/{no}` — 조회
  - `POST /mail/template/create`, `POST /mail/template/update`, `GET /mail/template/delete/{no}` — CRUD (삭제가 **GET**인 점 주의)
  - `POST /mail/template/images`, `POST /mail/template/assetsUpload` — 이미지 업로드 (두 엔드포인트가 동일한 `uploadImages()` 호출, 파라미터 이름만 `images` vs `files` 로 상이)

- **`WEBMarketingMailController`** (`@Deprecated`, `/marketing/**`)
  - `getHistory`, `/mailService/history/{pageNo}` — 구(舊) 마케팅 메일 발송 목록·상세
  - `/mailService/history/details/{infoNo}` — **링크별 클릭 + 발송 실패 상세** (`MarketingMailService.getLinkClickStatistics`, `getSendingFailedList`)

### 4.4 Push (`AppPushController`, `MobilePushController`, `WEBAppController`)

- **서포터 푸시 예약** (`AppPushController.java:42~238`, `/appPush/**`)
  - `GET /appPush` — 예약 목록 페이지(`Page<SupporterPushReservation>`)
  - `GET /appPush/popAppPushDetail?transactionKey=` — 상세 팝업
  - `POST /appPush` — 신규 예약. **세 분기**: (1) condition 기반 조건 쿼리, (2) `hasTargetGroup + targetFile` 파일 업로드, (3) 일반; `setIsAds(true)` **광고성 플래그 강제 고정** (`AppPushController.java:72`)
  - `POST /appPush/{txKey}` — 수정, `DELETE /appPush/{txKey}` — 취소
  - `GET /appPush/{txKey}/stats`, `.../stats/errors` — 전송 결과·실패 상세
  - `POST /appPush/checkFileTarget`, `GET /appPush/checkTarget/{groupKey}`, `GET /appPush/checkTargetConditional` — **사전 대상수 검증**
  - `GET /appPush/checkEquityComingSoonCampaigns?comingSoonCampaigns=` — 쉼표 리스트로 들어온 캠페인ID 중 실제로 투자 오픈 예정인 것만 남기고 **누락된 ID** 반환 (`equityServiceAdapter.getEquityCampaigns` 연동)

- **모바일 푸시 메시지** (`MobilePushController.java:30~108`, `/mobile/**`)
  - `GET /mobile/push` + `popMessageInfo`, `popRegistMessage` 팝업, `GET /mobile/push/{no}` — 조회
  - `POST /mobile/push/register` — 등록 (`setConfirm(true)` 자동 승인)
  - `POST /mobile/push/modify`, `DELETE /mobile/push/{no}/delete`, `GET /mobile/push/{no}/progress` — 수정/삭제/진행상태

- **레거시 푸시 + 관리자 웹앱** (`WEBAppController.java:38~127`)
  - `GET -/**`, `GET /app/store/**`, `GET /app/mailsystem/` — **관리자 웹앱 진입점** (SPA 라우팅용, JSP `webapp/*` 뷰 재사용)
  - `/app/push` + `/app/popMessageInfo` + `/app/popRegistMessage` + 4종 ajax(`ajaxCountMessageByStatus`, `ajaxRegistMessageInfo`, `ajaxRemoveMessageInfo`, `ajaxModifyMessageInfo`, `ajaxConfirmMessageStatus`) — `AppPush`(구 모델) CRUD
  - 삭제는 `status="D"` 소프트 삭제

### 4.5 Notification (`NotificationController`, `NotificationViewController`)

- **단순 GET 프록시 5종** (`NotificationController.java:19~63`, `/api/notification/**`)
  - `/list`, `/summary/result`, `/push/detail`, `/message/detail`, `/mail/detail`
  - 모두 `@CheckUserLogin` + `notificationService.getRequest("/api/v1/notification/<path>", requestParamMap)` 로 **v1 서버(wave.notification or co.wadiz.api.community)** 에 그대로 릴레이
  - 본 컨트롤러는 비즈 로직 없이 **CSRF/세션 정합성 확보 + 경로 매핑**만 담당

- **SPA 라우트** (`NotificationViewController.java:9~18`)
  - `/notification/send-result`, `/notification/send-result/*` → `front/main` JSP만 반환 (React 라우팅에 위임)

### 4.6 Event (`EventViewController`, `InviteEventViewController`, `InviteEventController`)

- **이벤트 SPA 라우트**
  - `EventViewController` — `/event/big-unique-brand-v2`·`/event/big-unique-brand-v2/*` → `front/main`
  - `InviteEventViewController` — `event/invitation/manager`, `event/invitation/detail`, `event/invitation/detail/{id}` → `front/main` (단일 JSP 재사용, 경로만 매핑)

- **친구초대 이벤트 API** (`InviteEventController.java:25~63`, `/event/api/invite/**`)
  - `GET /detail` — 현재 진행 이벤트 단건
  - `GET /list` — 이벤트 리스트
  - `POST /register` — `InviteEventVo.Register` + **메인 이미지 / 공유 이미지 2종** MultipartFile 업로드
  - `GET /rewardTemplate/{rewardType}` — `InviteEventVo.RewardType` enum 기준 리워드 템플릿 풀
  - 응답 래퍼가 `wave.user.support.ResponseWrapper` (다른 API가 쓰는 `api.reward.support.ResponseWrapper` 와 **다름**)

### 4.7 Marketing consent (`WEBMarketingParticipationController`, `WEBDmAccountController`, `UserMarketingInfoController`)

- **프로모션 참여 이력** (`WEBMarketingParticipationController.java:43~95`, `/waccount/marketingparticipation/**`)
  - `GET /home` — 홈 페이지
  - `GET /?key=` — **프로모션 키**로 참여자 목록 조회. `ModelMapper STRICT` + 수동 매핑으로 중첩 `UserInfo.userName/userId` · `Promotion.id/desc/registered` 를 flat `MarketingParticipationVo` 로 평탄화
  - `PUT /{id}?isDelete=&deleteReason=` — 수신동의 참여 **상태 변경** (삭제 사유 필수, 0건 → 204, 1건 → 201, 그 외 → 500 으로 분기)

- **DM 이력 조회** (`WEBDmAccountController.java:19~56`, `@Deprecated`, `/waccount/dm/**`)
  - `GET /home` — JSP 뷰만
  - `POST /user/list` — 검색(`searchType`, `searchValue`) 기반 페이징
  - `POST /user/dm/list` — 대상 사용자 + 채널(`channel`) + allow 여부 + 기간 필터 (`PageDateSearch<SubscriberAllowAdsLog, SubscriberAllowAdsLogSearch>`)

- **사용자 마케팅 정보** (`UserMarketingInfoController.java:44~68`, `/account/marketingInfo/view`)
  - 설문조사 마스터 `MCD_SURVEY0001` (관심 키워드) + `INCOME_QUESTION_NO=2` (소득 구간 답안지) 함께 뷰에 주입
  - `isOpenSearch=true` 일 때만 실제 조회 — **초기 로딩 방어**

### 4.8 Send / Affiliation (`WEBSendController`, `CriteoController`)

- **관리자 발송 툴** (`WEBSendController.java:31~99`, `send/*`)
  - `send/emailSend`, `send/smsSend` — 발송 팝업 JSP
  - `send/ajaxExcelFileUpload` — 엑셀 수신자 일괄 등록
  - `send/ajaxAddEmail`, `send/ajaxAddSms` — 단건 메일·SMS 큐 등록 (내부 `WEBSendService` 에만 의존; 실제 GW 호출은 서비스 하위)

- **Criteo 피드 제외 관리** (`CriteoController.java:20~43`, `/affiliation/**`)
  - `GET /affiliation/criteoList?campaignType=REWARD|EQUITY` — 현재 피드 / 숨김 대상 / 이력 3종 주입
  - `POST /affiliation/hide` / `POST /affiliation/show` — `CriteoFeedExcludeDto` + **세션 유저ID** 로 감사 로그 남기며 숨김/복원

---

## 5. 외부 연동

| 연동 | 통로 | 엔드포인트 / 키 | 비고 |
|---|---|---|---|
| 이메일 GW (`wave.notification`) | `MailSendingService`/`MailReservationService`/`MailLogService` | 내부 DTO `MailBatchInfo`, `MailExcelInfo`, `MailTestInfo` | 회원/엑셀/테스트 세 경로, 30분 단위 오픈 통계 |
| Slack Webhook | `MailSendingService.sendSlack` | `file['host_slack_mail_marketing']`, `file['host_slack_service_monitoring']` | 메일 발송 시작·실패 알림, 발송자 닉네임 포함 |
| 푸시 GW | `AppPushService` + `PushTargetApiAdapter` | `transactionKey` 기반 예약·상태 조회 | `isAds=true` 고정(`AppPushController`), 조건형/파일형/그룹키형 3분기 |
| 푸시 — 투자 오픈 캠페인 검증 | `EquityServiceAdapter.getEquityCampaigns` | 쉼표 리스트 → `List<EquityCampaign>` | Coming Soon 캠페인 필터 |
| 모바일 푸시 | `MobilePushService` | `MobilePushMessage` | 확정 플래그 자동 true |
| 알림 서버 | `NotificationService.getRequest` | `/api/v1/notification/{list,summary/result,push/detail,message/detail,mail/detail}` | 어드민 → v1 서버 GET 릴레이, `@CheckUserLogin` 강제 |
| 번역 서비스 | `WEBBannerSectionController` | `file['translateUrl']`, `file['translateToken']` | 배너 공용 목록 페이지에서 JSP로 전달 |
| Criteo 피드 | `CriteoService.{getFeed,getAll,getHistory,save,delete}` | `CriteoFeedExcludeDto` | 리타겟팅 광고 피드 제외 목록 관리 |
| 파일 업로드 | `FTFileService.{photoFileWrite,fileWrite}` | `FTUploadPhotoInfo`, `FTUploadFileInfo` | 프로젝트 무관 단일 업로드, 다운로드 URL `/web/ftcampaign/download/attach?encFileId=` |
| 실명 조회 | `AccountService.selectMember`, `getRealName` | 유저ID → 닉네임/실명 | 메일 예약 목록·캠페인 댓글 엑셀에서 사용 |
| 투자형 연동 | `EquityService.getCoreMessage` | 배너 코어 메시지 | `WEBBannerSectionController` |

---

## 6. 엔드포인트 레퍼런스 (도메인별 상세)

### 6.1 `/promotion/api/**` — 리워드 쿠폰 프로모션 (`PromotionController`)

| Method | Path | 입력 | 출력 | 서비스 호출 |
|---|---|---|---|---|
| POST | `/promotion/api/templates/{templateNo}` | `SaveEvent` (body) + `templateNo` (path) | `ResponseWrapper<Void>` | `createPromotionEvent(converter.toSaveEventQuery(saveEvent), templateNo)` |
| POST | `/promotion/api/templates/{templateNo}/events/{eventNo}` | path 2개 | `ResponseWrapper<Void>` | `getPromotionEventByEventNo(eventNo)` → `createPromotionEventBenefit(query)` |
| PUT | `/promotion/api/events/{eventNo}` | `ModifyEvent` (body) | `ResponseWrapper<Void>` | `modifyPromotionEvent(ModifyEventQuery)` |
| DELETE | `/promotion/api/templates/{templateNo}/events/{eventNo}` | path 2개 | `ResponseWrapper<Void>` | `deletePromotionEvent(DeleteRewardEventBenefitMappingQuery.builder()...)` |
| GET | `/promotion/api/templates/{templateNo}` | path | `ResponseWrapper<List<RewardEvent>>` | `getPromotionEventsByTemplateNo` → `converter.toRewardEvent` |
| GET | `/promotion/api/{keyword}` | path | `ResponseWrapper<RewardEvent>` | `getPromotionEventByKeyword` |

`PromotionController.java:37~54` 의 예외 처리 관용구는 나머지 4개 핸들러에도 동일하게 복붙되어 있음 — 공통 @ExceptionHandler 나 `fail()` 헬퍼가 없기 때문.

### 6.2 `wbenefit/**` — 프로모션 코드·참여자 (`WEBPromotionController`)

| Method | Path | 목적 |
|---|---|---|
| GET | `wbenefit/promotionList` | 참여자 페이징 + `siteUrl` 주입 |
| GET | `wbenefit/promotionListExcel` | 참여자 전체 엑셀 다운로드 (`DWLD_EXCEL_FILE_NM_PROMOTION_DETAIL`) |
| GET | `wbenefit/promotionPartListDown` | 부분 참여자 엑셀 (`@Auditable(EXCEL_DOWNLOAD)`) |
| GET | `wbenefit/popPromotionPartDetail` | 부분 상세 팝업 (`param` 필수 — 없으면 예외) |
| GET | `wbenefit/promotionPartInfoList` | jqGrid용 페이징 JSON (`page`, `rows`) |
| GET | `wbenefit/promotionCode` | 코드 발급 팝업 (`PROMOTION_EVENT_TYPE = {REWARD, EQUITY}` 주입) |
| POST | `wbenefit/ajaxRegisterPromotionCode` | 코드 발급 실행 (`wEBPromotionService.ajaxRegisterPromotionCode`) |

### 6.3 `campaign/**` — 캠페인·배너·검색 (`WEBCampaignController`)

| Method | Path | 목적 |
|---|---|---|
| GET/POST | `campaign/search` | 타이틀 검색(`searchText1` UTF-8 디코딩) |
| GET | `campaign/keyword/search` | 메인 검색어 키워드 조회 (`MainSearchKeyword`) |
| POST | `campaign/keyword/regist` | 키워드 등록 (ajax string 반환) |
| GET | `campaign/banner` | PC 메인 배너 관리 페이지 |
| GET | `campaign/banner/detail` | 배너 상세 (`imageOrder`) |
| POST | `campaign/banner/regist` | PC 배너 등록(`banner` MultipartFile) |
| GET | `campaign/mobile/banner` | 모바일 메인 배너 페이지 |
| POST | `campaign/mobile/banner/regist` | `viewStatus=on → view=1` 토글 후 업데이트 |
| GET | `campaign/app/banner` | 앱 메인 배너 페이지 |
| GET | `campaign/app/banner/edit` | 등록/수정 (`subNo=0` 이면 등록 모드) |
| POST | `campaign/app/banner/update` / `regist` / `img/regist` | `MobileAppMainCampaign` 3종 CRUD |

### 6.4 `campaign/**` — 지면·공통배너·와디즈캐스트 (`WEBBannerSectionController`)

| 섹션 | 엔드포인트 | 비고 |
|---|---|---|
| 지면 목록/CRUD | `bannerSectionList`, `popRegistBannerSection`, `ajaxRegistBannerSection`, `popModifyBannerSection`, `ajaxModifyBannerSection`, `ajaxRemoveBannerSection` | `codeService.getCommonCodeList("BannerSectionCategory")` 카테고리 공통 주입 |
| 배너 목록/CRUD | `bannerCommonList`, `popRegistBanner`, `ajaxRegistBanner`, `popModifyBanner`, `ajaxModifyBanner`, `ajaxRemoveBanner` | 노출/비노출 목록은 `searchSelect3=Y|N` 로 2회 쿼리 |
| 배너 미디어 | `ajaxRegistBannerImage` / `ajaxRegisterBannerClip` / `ajaxModifyBannerImage` / `ajaxModifyBannerClip` | 이미지·동영상 분리 업로드 |
| 유틸 | `ajaxGetRewardTitle`, `ajaxGetInvestCoreMessage`, `ajaxGetSectionByPage`, `ajaxModifyBannerOrderNo` | 캠페인 타이틀·코어메시지 조회, 순서 일괄 변경 |
| 와디즈 캐스트 | `wadizCastIntroList`, `ajaxModifyWadizCastList` | 3존(P1/P2/P3) bannerType 별 노출 |

요청 파라미터 주요 필드 (BannerCommonInfo): `bannerSeq`, `sectionCode`, `campaignId`, `viewYn`, `orderNo`, `startDate`, `endDate`, `linkUrl`, `imgPath`.

### 6.5 `/popup/**` — 공지 팝업 NPA (`PopupMainController`)

| Method | Path | 비고 |
|---|---|---|
| GET | `/popup/main` | `front/main` JSP 셸 |
| GET | `/popup/list` | 활성 팝업 리스트 |
| GET | `/popup/detail?id=` | 단건 조회 |
| POST | `/popup/update` | `@Valid` + `createNew=true` 시 NPA 태그 자동 `targetSection_yyyyMMddHHmi` 생성 |

### 6.6 `/mail/**` — 전체 (6개 컨트롤러)

| 컨트롤러 | 대표 엔드포인트 | 핵심 인자 |
|---|---|---|
| `WEBMailController` | `/mail/v2`, `/mail/builder`, `/mail/group`, `/mail/group/users` | enum JSON (GroupType, UsersType) |
| `WEBMailLogController` | `/mail/log?notificationPolicyCode=DM00`, `/mail/log/transactionKey/{key}`, `/mail/log/transactionKey/{k}/{mailsQty \| readQtyStatistics \| elapsedTime \| linkTrackingList}`, `/mail/log/priority/fast` | `NotificationPolicyCode`, `cPage/pageSize`, 기간 필터 |
| `WEBMailReservationController` | `POST /mail/reservation/`, `GET /mail/reservation/list`, `POST /mail/reservation/ajaxReservationCancel`, `POST /mail/reservation/excel` | `MailBatchInfo`, `MailExcelInfo`, `reservationDateTime="yyyy-MM-dd HH mm"` |
| `WEBMailSendingController` | `POST /mail/send/{test\|batch\|excel}`, `GET /mail/send/batch/counts?subscriber=` | `LoginUserInfo` 강제, Slack 이중 알림 |
| `WEBMailTemplateController` | `/mail/template/list`, `/{no}`, `/create`, `/update`, `/delete/{no}`, `/images`, `/assetsUpload` | `MailTemplate`, `MultipartFile` |
| `WEBMarketingMailController`(`@Deprecated`) | `/marketing/mailService/getHistory`, `/marketing/mailService/history/{pageNo}`, `/marketing/mailService/history/details/{infoNo}` | `MarketingMailService` |

**MailReservation 타깃타입 매핑** (`WEBMailReservationController.java:82~96`):
```
USERS        → CCI.accntType.get(targetKey)
NEWS_MAKER   → "reward" ? "리워드 뉴스레터" : "투자 뉴스레터"
그 외        → "엑셀 업로드"
```

### 6.7 `/appPush/**` + `/mobile/**` + `/app/**` — 푸시

**AppPush (서포터 대상 푸시 예약)**

| Method | Path | 비고 |
|---|---|---|
| GET | `/appPush` | 예약 리스트 페이지 |
| GET | `/appPush/popAppPushDetail?transactionKey=` | 상세 팝업 |
| GET | `/appPush/{txKey:.+}` | 단건 JSON |
| POST | `/appPush` | 등록 (isAds=true 고정, targetFile 또는 condition 중 하나 필수) |
| POST | `/appPush/{txKey:.+}` | 수정 (condition 여부로 분기) |
| DELETE | `/appPush/{txKey:.+}` | 취소 |
| GET | `/appPush/{txKey}/stats`, `.../stats/errors` | 결과 / 실패 내역 |
| POST | `/appPush/checkFileTarget` | 파일 업로드 사전 체크 (`isValid`) |
| GET | `/appPush/checkTarget/{groupKey:.+}` | 그룹키 기반 사전 체크 |
| GET | `/appPush/checkTargetConditional` | 조건 기반 대상자 수 |
| GET | `/appPush/checkEquityComingSoonCampaigns?comingSoonCampaigns=` | 투자 오픈 예정 캠페인 교차검증 |

**MobilePush (일반 모바일 푸시)**

| Method | Path | 비고 |
|---|---|---|
| GET | `mobile/push` | 리스트 |
| GET | `mobile/popMessageInfo?messageNo=` | 상세 팝업 |
| GET | `mobile/popRegistMessage` | 등록 팝업 |
| GET | `mobile/push/{no}` | JSON 단건 |
| POST | `mobile/push/register` | 등록 (`setConfirm(true)`) |
| POST | `mobile/push/modify` | 수정 |
| DELETE | `mobile/push/{no}/delete` | 삭제 |
| GET | `mobile/push/{no}/progress` | 진행 상태 리스트 |

**WEBAppController (관리자 웹앱 + 레거시 AppPush)**

| Method | Path | 비고 |
|---|---|---|
| GET | `-/**` | `webapp/index` (SPA 진입) |
| GET | `app/store/**` | `webapp/store-app` |
| GET | `app/mailsystem/` | `webapp/mailsystem` |
| GET/POST | `app/push`, `app/popMessageInfo`, `app/popRegistMessage` | 레거시 AppPush JSP |
| POST | `app/ajaxCountMessageByStatus`, `app/ajaxRegistMessageInfo`, `app/ajaxRemoveMessageInfo` (status=D), `app/ajaxModifyMessageInfo`, `app/ajaxConfirmMessageStatus` | `AppPush` CRUD |

### 6.8 `/api/notification/**` — 알림 프록시

공통 시그니처: `ResponseEntity<Object> xxx(@RequestParam Map<String,Object> request)` → `notificationService.getRequest("/api/v1/notification/<suffix>", request)`

| 경로 | 하위 서버 경로 |
|---|---|
| `/api/notification/list` | `/api/v1/notification/list` |
| `/api/notification/summary/result` | `/api/v1/notification/summary/result` |
| `/api/notification/push/detail` | `/api/v1/notification/push/detail` |
| `/api/notification/message/detail` | `/api/v1/notification/message/detail` |
| `/api/notification/mail/detail` | `/api/v1/notification/mail/detail` |

모든 엔드포인트에 `@CheckUserLogin` AOP 적용.

### 6.9 `/event/**`, `event/invitation/**` — 이벤트

| 컨트롤러 | 경로 | 역할 |
|---|---|---|
| `EventViewController` | `/event/big-unique-brand-v2`, `/event/big-unique-brand-v2/*` | SPA 라우트 (front/main) |
| `InviteEventViewController` | `event/invitation/{manager,detail,detail/{id}}` | SPA 라우트 |
| `InviteEventController` | `/event/api/invite/detail`, `/list`, `/register`, `/rewardTemplate/{rewardType}` | JSON API (Swagger 노출) |

InviteEvent `register` 입력: `InviteEventVo.Register` + `mainImageFile`(optional) + `shareImageFile`(optional). 예외는 `ResponseWrapper.fail(null, 400, e.getMessage())`.

### 6.10 `/waccount/**`, `/account/marketingInfo/*` — 마케팅 동의

| 경로 | 비고 |
|---|---|
| `GET /waccount/marketingparticipation/home` | JSP 홈 |
| `GET /waccount/marketingparticipation?key=` | `key` 필수(blank 시 IllegalArgumentException) |
| `PUT /waccount/marketingparticipation/{id}?isDelete=&deleteReason=` | deleteReason blank → 400, 0건 → 204, 1건 → 201, else 500 |
| `GET /waccount/dm/home` (`@Deprecated`) | JSP 홈 |
| `POST /waccount/dm/user/list` | 검색 페이징 |
| `POST /waccount/dm/user/dm/list` | 사용자·채널·allow·기간 필터 |
| `GET /account/marketingInfo/view` | 초기 진입 시 `isOpenSearch=false` 이면 빈 리스트 |

### 6.11 `send/*` — 메일/SMS 발송 툴 (`WEBSendController`)

| Method | Path | 비고 |
|---|---|---|
| GET | `send/emailSend` | 팝업 JSP |
| GET | `send/smsSend` | 팝업 JSP |
| POST | `send/ajaxExcelFileUpload` | 엑셀 → 수신자 리스트 변환 (`excel` MultipartFile) |
| POST | `send/ajaxAddEmail` | 메일 큐 등록 |
| POST | `send/ajaxAddSms` | SMS 큐 등록 |

### 6.12 `/affiliation/**` — Criteo

| Method | Path | 비고 |
|---|---|---|
| GET | `/affiliation/criteoList?campaignType=` | 피드 + 제외목록 + 이력 3종 |
| POST | `/affiliation/hide` | 제외 추가 (`WEBSessionUtil.getUserId()` 기록) |
| POST | `/affiliation/show` | 제외 해제 |

---

## 7. 경계 (Out of Scope / 주의)

- **리워드 쿠폰 본체·자동발급·대량발급**: `kr.wadiz.coupon` 패키지의 `CouponController` 계열(다른 문서). 본 문서는 **쿠폰↔이벤트 매핑** 구간만 다룬다.
- **스타트업 투자형 프로모션**: `equity/*`, `wcoupon/*` 는 별도. 여기서는 구분 지점만 언급 (PROMOTION_EVENT_TYPE = {"REWARD","EQUITY"}; `EquityCampaign`, `EquityW9ContentsOrder` 등은 참고용 import).
- **구형/Deprecated**
  - `WEBMarketingMailController` — 전체 `@Deprecated`. 신규 작업은 `/mail/**` 6종으로.
  - `WEBDmAccountController` — 사이드바 메뉴에서 이미 제거, JSP(`waccount/dm/home.jsp`) 삭제 대기 상태.
  - `WEBCampaignController` 의 PC/모바일/앱 메인 배너 3종 — `WEBBannerSectionController` 통합 지면 관리로 이관 중. 신규 개발 시 후자 사용.
- **검증 미흡 지점**
  - `PopupMainController.updateNoticePopup` — `BindingResult` 검증이 주석 처리됨 → 서버 측 검증 없음
  - `WEBMailTemplateController.delete` — HTTP GET 으로 삭제 수행 (RESTful 규약 위반)
  - `UploadFileController` — `e.printStackTrace()` 후 실패 메시지 노출 (운영상 스택트레이스 노출 가능성)
- **수신동의/광고성 플래그**
  - 푸시(`AppPushController`)는 무조건 `isAds=true`; 정보성 푸시는 이 API 경로가 아님
  - 메일은 `MailBatchInfo.isAds()` / `MailExcelInfo.isInfoExcel()` 로 플래그 분기, Slack 메시지도 "마케팅/정보성" 구분
- **인증/세션**
  - 대부분 `WEBSessionUtil.getUserId()` / `getUserInfo()` 기반 JSP 세션
  - `NotificationController`만 AOP `@CheckUserLogin` 사용 (`com.wadiz.core.notification.aop`)
- **동시성**
  - `WEBMailSendingController` 의 `AtomicBoolean isInvokeBatch/isInvokeExcel` 는 **단일 JVM 스코프 락**이다 → 멀티 인스턴스 환경에서는 중복 발송 방어가 완벽하지 않음. 실제 방어는 하위 `MailSendingService` 레벨에서 한 번 더 체크 필요.
- **SPA 전환 중인 라우트**
  - `EventViewController`, `NotificationViewController`, `InviteEventViewController` — 모두 `front/main` JSP 한 개를 React 라우터에 넘기는 얇은 쉘. 실제 UI 로직은 `wadiz-frontend` 또는 어드민 번들로 이관됨.
