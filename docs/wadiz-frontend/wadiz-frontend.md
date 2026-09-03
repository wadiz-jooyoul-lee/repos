# wadiz-frontend

> 📅 **2026-09-03 cloud_live pull 보강** (23 커밋)
>
> **스토리 이미지 변환의 클라우드 CDN 대응(FE1-1733)** 과 **메이커 문의하기 버튼 추가(FE1-1768)** 가 핵심이고, E2E 대상 환경을 rc2 → rc4 로 옮기는 작업이 이어집니다.
>
> ### FE1-1733 — 스토리 GIF → mp4 변환을 CDN 매핑 기준으로 정리
> - 스토리 본문의 GIF 를 mp4 로 바꿔 내보내는 로직이 **클라우드 CDN 호스트를 알아보지 못했습니다.** 인식 대상 호스트를 넓히고, **같은 주소에 변환이 두 번 적용되는 경로를 막았습니다** (`packages/features/src/store/detail/lib/hooks/storyHelper.js`).
> - 판정 기준 자체를 **CDN 매핑 표 기준**으로 정리했고, 주소가 비어 있을 때의 예외도 막았습니다. 이후 **레거시 `wadiz.kr` 이미지 주소는 변환 대상에서 제외**했습니다.
> - `app-api` 의 CLIENT-235(클라우드 CDN 호스트 매핑 신설)와 같은 시기·같은 주제입니다.
>
> ### FE1-1768 — 참여 내역에서 메이커에게 바로 문의
> - 펀딩 참여 내역 카드와 구매 내역 상세의 메이커 줄에 **문의하기 버튼**을 추가했습니다 (`PurchaseInfoContainer.jsx`). 버튼명은 후속 커밋에서 "메이커 문의하기" 로 확정됐습니다.
>
> ### FE1-1771 / FE1-1724 — 원링크 action 파라미터 정리
> - 원링크의 웹 목적지 URL 에서 **`action` 파라미터를 제거**했고(FE1-1724), 이어서 **국내 알림신청의 로그인 복귀 URL 에는 action 파라미터가 붙지 않도록** 고쳤습니다(FE1-1771, `packages/features/src/onelink/onelink.ts`). 앱의 FE1-1726(안드로이드)·FE1-1722(iOS) "알림신청 URL 액션 글로벌 한정 게이트" 와 짝인 작업입니다.
>
> ### 죽은 코드 정리
> - **FE1-1752** — 사용하지 않는 펀딩 결제 실패 지면을 삭제했습니다(`PaymentFail.jsx` 등). [`com.wadiz.web`](../com.wadiz.web.md) 의 URL 매핑 제거와 짝입니다.
> - **FE1-1753** — static 메인의 컬렉션 관련 죽은 코드를 지웠습니다(`Collection.tsx`·`CollectionShareButton.tsx`·라우트·`storyHelper.js` 중복본).
>
> ### E2E 정비 (FE2-1035 · FE2-1177 · FE2-1174)
> - E2E 대상 환경을 **`cdev`·`rc4`·`stage`·`clive` 4종으로 정리**했습니다(기존 rc2 기준에서 이동). 문서도 함께 맞췄습니다.
> - 프로젝트 상태나 배포본 차이로 전제를 만들 수 없는 시나리오에는 **스킵 가드**를 붙였습니다(FE2-1174). 글로벌 앱 E2E 워크플로(`app-global-e2e.yml`·`schedule-app-global-e2e.yml`)를 여러 차례 손봤습니다.
> - 스토어 E2E 헬퍼(`helpers/project.ts` +66줄)와 스펙 다수가 함께 보강됐습니다.
>
> ### FE2-1178 — ESLint 에 아키텍처 경계 규칙 추가
> - `studio/funding/eslint.config.js` 에 **의존 방향 규칙과 `React.FC` 금지 규칙**을 넣었습니다(+257줄). 레이어를 넘나드는 import 를 린트 단계에서 막는 구조입니다.
>
> ### 기타
> - **FE1-1746** — 스토리 추천 리뷰 카드 본문에 위글롯(Weglot) 번역을 적용했습니다.
> - i18n 서포터 사전 동기화 2회(`en`·`ja`·`ko`·`zh` 각 235줄 추가).
>
> ---

> 📅 **2026-09-02 cloud_live pull 보강** (144 커밋)
>
> **펀딩 상세 개편(FE1-1320, 49커밋)** 이 압도적 최대 테마입니다. i18n 동기화 커밋 다수는 생략합니다.
>
> ### FE1-1320 — 펀딩 상세 디자인 QA (49커밋)
> - 커밋 대부분이 `PD-xxxx` 디자인 지적 반영입니다(예: PD-2058 모바일 목록 이동 버튼을 아웃라인 버튼으로, PD-2044 PC 추천 리뷰 아이콘 24px). 지면 개편 후 **디자인 QA 라운드**로 보입니다.
>
> ### FE1-1544 — 캐치업(따라잡기) 튜토리얼·포인트
> - 캐치업 **튜토리얼 초기 상태를 비노출**로 변경, 포인트 버튼 문구 가운데 정렬 등. 백엔드의 따라잡기 글로벌 확대(main1 DISPLAY-1691 · main2 DISPLAY-1688)와 같은 시기입니다.
>
> ### FE2-1159 — 글로벌 리워드 화면 다국어
> - 글로벌 리워드 **빈 화면 안내 문구를 4개 국어 버전으로 교체**하고, 프로젝트 정보 이동 안내 팝퍼를 제거했습니다.
>
> ### FE2-1030 — 최종정산 예정일 배너
> - 최종정산 예정일 배너를 **저장 전 폼 기준으로 노출**하도록 하고, 훅 인자명을 통일했습니다.
>
> ### FE2-1108 — 이전 리뷰 안내
> - 이전 리뷰 공통 설명을 **항목별 설명으로 변경**하고, 확인 링크를 만족도 탭 대신 **상세 기본 경로**로 바꿨습니다.
>
> ### FE1-1488 — 계정 라우트 정리와 되돌림
> - `account.tsx`·`web.tsx` 를 `auth.tsx` 로 인라인해 라우트 파일을 정리했습니다(라우트·페이지는 동일).
> - ⚠️ 친구초대 '포인트 받기'·아이디찾기의 앱 분기 링크를 `account.wadiz.io/signup` 으로 바꿨다가 **`/account/signup` 으로 원복**했습니다. **앱이 `REGISTER_INTRO` 로 네이티브 가로채기를 하므로 도메인 변경이 불필요하고 위험**하다는 이유입니다.
>
> ---
>
> 📅 **2026-08-27 cloud_live pull 보강** (77 커밋)
>
> 매출업 유사 프로젝트 광고 효율 조회(FE2-799)와 프로젝트 만들기 E2E 의 배포환경 모델 전환(FE2-1035)이 각각 24커밋으로 최대 테마입니다. i18n 동기화 커밋 다수는 생략합니다.
>
> ### FE2-799 — 매출업 유사 프로젝트 광고 효율 조회 섹션
> - 유사 프로젝트의 광고 효율을 조회하는 섹션을 신설했습니다. 조회 API 는 `packages/api` 로 이관하고, `ad-benchmarks` 도메인은 하드코딩 대신 환경변수 **`VITE_AIDATA_API_URL`** 로 뺐습니다. 요청에 `wadiz-language` 헤더를 추가했습니다.
> - **통화·금액 처리**: KRW 입력을 **언어와 무관하게 만원 단위로 환산**하고, KR/US/JP/CN 외 국가의 디폴트 통화를 **USD** 로 바꿨습니다. `toRequestAmount` 주석도 통화 기준으로 정정했습니다.
> - 카테고리 조회를 **펀딩·프리오더로 제한(스토어 제외)** 했습니다. 모바일 로딩 스켈레톤을 반응형으로 고치고 결과 메시지에 markdown 렌더를 적용했으며, 조회 결과가 없을 때의 문구를 변경했습니다. 결과 테이블 컬럼 너비도 조정했습니다.
> - sparkle 로티를 공통 `SparkleLottie` 컴포넌트로 분리하고, 에셋 URL 을 `CDN_STATIC_URL` 로 환경별 분기했습니다. `adProducts.adAmount` 는 optional 키로 타입을 정정했습니다.
>
> ### FE2-1035 / FE2-1125 / AC-7 — 프로젝트 만들기 E2E 를 배포환경(.io) 모델로 전환
> - `create-project` 글로벌·국내(korea) E2E 를 로컬이 아닌 **배포환경(`.io`) 모델**로 전환하고, 각각 배포환경 잡을 `app-global-e2e.yml` 에 추가했습니다(글로벌은 언어·국가 설정 포함). 프로젝트 만들기 소개 화면(글로벌) E2E 회귀 검증을 새로 넣었습니다.
> - 글로벌 로그인 project 가 korea 스펙을 끌어오지 않도록 파일명 앵커를 수정하고, `grep` 범위를 `create-project` project 로 한정해 `auth-setup` 이 보존되게 했습니다. 로케일 쿠키 도메인은 호스트 기준으로 바꿨습니다.
> - FE2-1125: 메이커 E2E 도 클라우드 환경으로 전환하고 스위트 태그를 도입했습니다(`studio/maker-e2e`).
>
> ### FE2-1113 / FE2-1112 / FE2-1109 — 만들기 지면·요금제·소재 제작기
> - FE2-1113: 만들기 페이지에서 영상 재생시간을 숨기고 카드 이미지를 조정했습니다. PC 전용 이미지(`pcImage`) 분기를 넣고, `object-position` 분기(`imageCropAdjust`)는 제거했습니다.
> - FE2-1112: 메이커 스튜디오 요금제에서 **로컬 요금제인 경우 안내 문구**를 추가했습니다.
> - FE2-1109: 광고 소재 제작기 HTML 과 README 를 갱신했습니다 (`static/markup`). 서빙은 `com.wadiz.web` 의 `/tools/{name}` 컨트롤러가 담당합니다.
>
> ### FE1-1627 / FE1-1564 / WSR-3461 — 트래킹·표시 수정
> - FE1-1627: 스토어 `add_payment_info` 의 `coupon` 타입 위반을 고치고, `view_item` 의 `currency` 누락과 전자상거래 앱 릴레이의 순서 의존을 수정했습니다 (`packages/event-tracker`).
> - FE1-1564: 배포에서 누락됐던 `minimumFractionDigits` 기본값을 복구했습니다.
> - WSR-3461: 국내 소개 지면에서 사전예약 카드가 빠진 것을 반영해 카드 5종 → **4종**으로 테스트를 맞췄습니다.
>
> ---
>
> 📅 **2026-08-25 cloud_live pull 보강** (직전 갱신 2026-07-31 이후 574 커밋, 이슈키 90여 종)
>
> ⚠️ **기준 브랜치가 `master` → `cloud_live` 로 바뀌었습니다.** master 기준(357커밋)에 더해 **클라우드 이관 작업 217커밋**이 포함됩니다 — 정적 엔트리(`static/entries` 592파일)·메일 템플릿(`apps/mail-template` 304)·`static/packages`(296) 변경이 그 몫입니다. i18n 동기화 커밋 다수는 생략합니다.
>
> ### FE1-1421 / FE1-1485 / FE2-1089 — 클라우드 도메인·CDN 전환 (cloud_live 전용)
> - 클라우드 CDN 주소를 **`cdn-static.wadiz.io`** 로 통합하고 파트너스 clive CDN 도 같은 주소로 맞췄으며, 푸터 회사정보를 i18n 전환했습니다(FE1-1421).
> - FE1-1485: 정적 HTML 도메인을 클라우드(`wadiz.io`)로 정리하고, link 도메인 io 전환·CDN 최적화를 통일했으며, admin 퀵메뉴 테스트 데이터의 CDN 을 국내/해외로 변환했습니다.
> - FE2-1089: 광고 전략탭 썸네일 CDN 을 `CDN_STATIC_URL` 환경변수로 바꿨다가 **되돌렸습니다** — `LIVE_CDN_STATIC_URL` 환경변수를 제거하고 기존 `CDN_STATIC_URL` 로 복원한 상태입니다.
>
> ### FE1-1366 / FE1-1322 — 투자·W9 지면 정리 (cloud_live 전용)
> - 메인 이동 처리된 투자·W9 지면의 앱 타이틀 매핑을 정리하고, 제거된 W9 결제 지면의 매핑도 걷어냈습니다. 그 과정에서 **메이커 등록 지면(`startup-registration`)이 함께 사라진 것을 복원**했습니다(FE1-1366).
> - 웹(`com.wadiz.web`)의 FE1-1322 투자 진입구 제거와 짝을 이루는 프론트 정리가 함께 들어왔습니다.
>
> ### FE1-1316 / FE1-1318 / FE1-1497 — 와디즈 에디션 지면(홈·기획전)
> - 홈 모바일에 에디션 섹션을 붙이고 카드 4종 렌더·썸네일 색 추출·카운트다운·랜덤 노출을 구현했습니다. 카드 노출 개수는 서버 응답을 그대로 따르고, 카드+MD 합산 높이를 고정한 뒤 320~359px 반응형 분기를 추가했습니다(분기 훅은 공용 `useMediaQuery` 로 대체) (`apps/global/src/pages/home/HomeMobilePage.tsx`, `packages/features/src/home/ui/WadizEditionSection/`, `packages/api/src/main2/main2.service.ts`).
> - 카드 CTA·타이틀을 어드민 입력값으로 통일하고 알림신청은 공통 컴포넌트를 재사용, 중복 다국어 키를 정리했습니다(FE1-1318).
> - FE1-1497: 에디션 기획전 헤더를 일반 기획전과 동일하게 맞추고, 에디션 배지 count 는 진입마다 조회하도록 `staleTime` 을 해제했습니다.
>
> ### FE1-1317 / FE1-1342 / FE1-1319 — 에디션·기획전 어드민
> - 어드민에 에디션 카드 타입 4종 등록·미리보기·리뷰 팝업·랜덤 노출을 추가하고, 카드 CTA·타이틀 입력과 다국어 번역 편입, 웹 API 호스트 해석을 정리했습니다(FE1-1342).
> - AD1 리워드 불러오기(수동), 타입 교체 시 콘텐츠 초기화, 스토어 리워드 메뉴 숨김. 메이커 기획전 미리보기에 쿠폰 winner·노출조건 미만족 표시를 넣고 미리보기 API 실패를 격리했습니다(FE1-1317).
> - FE1-1319: 통합 기획전 어드민 타입 지정 프로젝트 영역 UX 개편 + 지면 미리보기 카드 추가. FE1-1573 에서 프로젝트 카드에 영역 데이터가 중첩 저장되는 버그를 고치고 제출값 보충 범위를 `projects` 제외로 축소했습니다. FE1-1531: 기획전 부스터 쿠폰을 `hasCoupon` 이 true 일 때만 노출.
>
> ### FE2-840 / FE2-881 / FE2-832 — 메이커 스튜디오 요금·리워드 금액 정책
> - GMV 구간별 컨설팅 수수료율 고지(2026년 8월 10일 시행)를 **제출일 정책에 따라 조건부 노출**합니다. 판정 재료는 `com.wadiz.api.funding` 의 `GET /api/studio/campaigns/{projectNo}/submission` 응답 정책값 `GMV_TIERED_FEE_NOTICE` 입니다.
> - FE2-832: 후원·캠페인 카테고리의 리워드 금액 초과(500만원 상한) 예외 처리 추가.
>
> ### FE2-947 / FE1-1399 — 재결제 4회 전환 (예약결제 회차 개편)
> - FE2-947: **재결제 4회 전환** 관련 메일 템플릿을 추가하고 템플릿 번호를 갱신했습니다(`apps/mail-template/src`).
> - FE1-1399: 결제 예정 일시를 `backing-payments` 응답 값으로 참조하도록 바꾸고, 결제 실패 안내 시간 표시를 `formatIntlDateTime` 으로 통일했으며 결제 정보 변경 마감 시간 표시를 수정했습니다. (백엔드 RWD-5862 와 짝입니다.)
>
> ### RWD-5879 / RWD-5836 — 어드민 실시간 콘텐츠 검사 화면
> - 어드민에 실시간 콘텐츠 검사 화면을 신설하고 프로젝트 단위 탭·상세 모달·삭제/블라인드 조치를 추가했습니다. 상세 스레드 테이블을 판정·코드·사유·점수 컬럼으로 개편하고 점수 셀 렌더러를 공용 모듈로 이관했습니다. 백엔드는 `co.wadiz.api.community` 의 `/api/v3/admin/realtime-content` 3 endpoint 입니다.
>
> ### FE2-899 / FE2-902 / FE2-445 — 매출업·데이터인사이트·메이커 추천
> - FE2-899: 매출업의 `MakerClassList → SchoolList` 리네임에 맞춰 트래킹 카테고리·라벨·함수명을 GA 명세(`광고_와디즈스쿨`·`광고_펀딩인사이트`)와 정합시키고 팁 컴포넌트를 `FundingInsightList` 로 리네임.
> - FE2-902: 데이터·인사이트 현황 메인 배너를 상시 노출로 바꾸고, GA 카테고리 접두사(`펀/프스튜디오_`) 제거를 시도했다가 **롤백해 접두사를 유지**합니다.
> - FE2-445: 메이커 추천 프로그램 디자인 QA. FE2-991: 메이커 추천 프로그램의 공유 문구·심사 혜택 삭제 및 미사용 에셋 정리.
>
> ### CLIENT-203 / CLIENT-206 / CLIENT-209 / FE2-808 / FE2-714 — WAi 채팅 위젯
> - CLIENT-206: 스토리 생성 상태·탭 타이틀 관리를 `StoryGeneration` 클래스로 분리하고 `useWAiWebSocket` 이 위임하도록 리팩터링.
> - CLIENT-209: 모바일에서 WAi Tip·`A2uiChip` 의 스크롤 터치가 클릭으로 동작하던 문제 수정.
> - CLIENT-203: A2UI 개발 지침(`CLAUDE.md`·`NAMING_CONVENTIONS.md`·카탈로그 프롬프트) 정비. FE2-808: 스토리 생성 배너와 워크스루 모달 로직 신설. FE2-714: WAi 런처 스크립트 로드 실패 Sentry 노이즈 개선.
>
> ### FE1-1400 / FE1-1406 — 웹접근성
> - 클릭 요소를 `button`/`link` 로 전환하고 SNSToggle 이벤트를 위임, ImageEditor 접근성 버그 수정과 샘플 삭제 키보드 지원 추가(FE1-1406). account 아이콘 버튼 `aria-label`·외부 링크 `rel`, Avatar 대체 텍스트 추가(FE1-1400).
>
> ### FE1-1403 / FE1-1478 / FE1-1372 / FE1-1368 — GA·전자상거래 트래킹
> - FE1-1403: 와디태그 색인용 최상위 `item_list_id` 추가. FE1-1478: 프로젝트 카드에 찜 여부 `is_interested` 속성을 추가하고 스토어·레거시 카드까지 확장(앱 FE1-1467/1474 와 짝).
> - FE1-1372: 스토어 카드 GA `price` 에 `signaturePrice` 우선 적용, 홈 퀵메뉴 GA 속성 변경. FE1-1368: 최근본·유사추천 섹션 `ecommerceSectionName` 전달 누락 복구.
>
> ### FE1-1277 / QA-22868 / FE2-1002 — 결제·주문·E2E
> - FE1-1277: 스토어 결제 에러 응답 파싱을 fetch 구조에 맞게 수정(4곳)하고 참여 제한 안내 문구 정정.
> - QA-22868: 주문 세션 리워드의 배송지 필요 여부 필드명을 **`isAddressRequired`** 로 맞추고, 배송지 불필요 리워드 주문의 배송지 영역 비노출·주문 국가 코드 유실을 수정.
> - FE2-1002: 스튜디오 E2E 전제 판정을 환경·잠금 상태 기준으로 보정하고 워크플로에 suite 태그 선택 옵션 추가, mock 상태 저장이 실서버로 나가지 않도록 차단.
>
> ### 기타
> - FE2-906: 일정 페이지 광고 유도 배너·저장완료 모달 광고 추천 영역 추가. FE2-849: 광고 결제 완료 다국어 메일 템플릿 추가. FE2-871: 스튜디오 펀딩 다국어에 일본어·중국어 추가.
> - FE1-1517: 한국 참여완료 타이틀·참여내역 버튼 다국어 키 전환, 해외배송 관세·수입세 안내 문구 복원. FE1-1418: 글로벌 룰렛 결과 모달 자동 이동 개선·닫기 버튼 제거. FE1-1553: 스토어 상세 첫 결제 쿠폰 배너 노출 제외.
> - FE1-1396: 글로벌 CI CHANGELOG 단계의 태그 전체 fetch 제거로 멈춤 해소. FE1-1373: fetch JSON 파싱 오류 처리 개선(SSR 대응).
> - 클라우드 환경 확장: `studio/store`·`studio/startup` 에 `.env.{development,production}.{cdev,clive,rc4}` 추가, ir 앱 cdev·clive 배포에 dev·live S3 버킷 사용.
>
> ---
>
> 📅 **2026-07-31 master pull 보강** (직전 갱신 2026-07-21 이후 197 커밋, 이슈키 20여 종)
>
> WAi(와디즈 AI 에이전트) 채팅 위젯을 A2UI 프로토콜 기반으로 대개편한 CLIENT-* 계열이 최대 테마입니다. 메이커홈 WAi 첫 진입 경험 재설계(FE2-669/709~712), 정적 리소스 CDN 도메인 전환(FE1-1302/1303), 헤더·기획전 정비가 뒤를 잇습니다. i18n 동기화 커밋 다수는 생략합니다.
>
> ### CLIENT-55 / CLIENT-160 / CLIENT-144 / CLIENT-196 / CLIENT-200 / CLIENT-202 / CLIENT-1 — WAi 채팅 위젯 A2UI 대개편
> - `apps/global/src/features/wai/` 아래 WAi 채팅을 **A2UI(Agent-to-UI) 프로토콜** 기반으로 전면 재구성. A2UI PoC 모듈 도입(v0.8→v0.9 정리) 후 서버 스트림을 카탈로그 스키마로 렌더링. 카탈로그 컴포넌트 basic(Button·Text·Chip·Icon·Row·Column)·custom(NextActionBlock)과 차트 3종(A2uiBarChart·A2uiLineChart·A2uiPieChart, visx 의존성 추가)을 등록하고 `catalogs/`에 추출 스크립트·`catalog.json`을 둡니다 (`apps/global/src/features/wai/ui/A2ui/`).
> - 소켓 수명주기·타임아웃·자동 재연결을 관리하는 `WAiWebSocket` 클래스와 턴 상태 관리 `TurnStore`를 신설하고, `useWAiWebSocket`을 1레벨 messages·turnStatus 기반으로 전환. 채팅 메시지 모델을 type 기반 판별 union(`chatMessage.types.ts`)으로 정리하고 A2UI 답변을 별도 메시지(`ChatA2uiStreamMessage`)로 분리, 히스토리 변환·`fallbackText` 처리 추가 (`apps/global/src/features/wai/lib/`, `packages/api/src/wai/chatHistory.service.ts`).
> - A2UI capabilities 핸드셰이크, 인라인 카탈로그 협상, 사용자 말풍선 `UserMessage`·상태 메시지 `StatusMessage`·`AnimatedDotGroup` 추가. A2UI 작업용 개발 지침(`CLAUDE.md`·`NAMING_CONVENTIONS.md`)도 함께 정비.
>
> ### PD-1874 / PO-1207 / PO-1208 / PO-1211 / PO-1212 — WAi 채팅 렌더링·스크롤 개선
> - A2UI를 별도 메시지로 분리해 실시간/히스토리 표시 위치를 통일하고, 도착 순서대로 렌더링·중복 답변 생성 문제 수정. 질문칩 타이틀·줄바꿈·입력창 활성 조건, 새 사용자 메시지 상단 정렬 스크롤 보정, 세션 재연결 시 인트로 질문칩 중복 노출·소켓 끊김 시 무반응 문제 수정.
>
> ### FE2-669 / FE2-709 / FE2-710 / FE2-711 / FE2-712 — 메이커홈 WAi 첫 진입 경험 재설계
> - WAi 지침 개선(P1) — `PromptInput` 컴포넌트 적용·인풋 케이스 추가, 스크롤 버튼, WAi 배경 제거, 메뉴 순서 변경, A2UI 넥스트액션 컴포넌트 도입·디자인 QA (`packages/waffle/src/WAi/PromptInput/`).
>
> ### FE1-1302 / FE1-1303 — 정적 리소스 CDN 도메인 전환
> - account·global 앱에 `VITE_CDN_STATIC_URL` 환경변수를 도입하고 정적 리소스 도메인 하드코딩(`static.wadiz.kr`)을 `STATIC_URL`/`CDN_STATIC_URL` 참조로 전환. apps/global SCSS 배경 이미지를 TSX 인라인 스타일로 이전하며 도메인을 `cdn-static.wadiz.io` 계열로 교체 (`apps/account/.env-cmdrc`, `apps/global/.env-cmdrc`, `apps/global/vite.config.ts`).
>
> ### FE1-1367 / FE1-1389 / FE1-1379 — 헤더·기획전 정비
> - FE1-1367: 데스크탑 헤더 서비스 홈 메뉴에서 **프리오더 제거·와디즈에디션 추가**, 통합기획전 에디션 랜딩의 기획전 이동 동선 제거·PC GNB 클릭 수집 (`packages/ui/src/Header/Header.constants.ts`, `packages/ui/src/Header/lib/useKoreaDesktopMenu.ts`).
> - FE1-1389: 메이커 기획전 불러오기 시 "진행 중·오픈 프로젝트만 노출" on/off 옵션 추가 (`static/services/admin/pages/event/pages/BigUniqueBrand/`).
> - FE1-1379: indemand 여부 조회를 제거하고 안내문구 비노출 조건을 발송예정일 기반으로 일원화.
>
> ### FE2-812 / FE2-863 / FE2-472 / QA-22892 — 메일템플릿·스튜디오·광고
> - FE2-812: 기획전 관련 CRM 발송용 메일템플릿 신규(`makerExhibitionBenefit/Faq/Open/Teaser.hbs`, `makerExhibitionCoupon/Marketing` partial) 및 치환자 변경 (`apps/mail-template/`).
> - FE2-863: 일정 변경 마감일을 서버 신규 필드 기준으로 수정. FE2-472: 메이커소식 목록 검증 재시도 대기 보강. QA-22892: 광고 상품 소개서 PDF 호스트를 환경변수로 분리.
>
> ---
>
> 📅 **2026-07-21 master pull 보강** (직전 갱신 2026-07-10 이후 약 80 커밋, 이슈키 30여 종)
>
> 메이커 스튜디오 스토리/인트로 가이드 고도화(FE2-734), 스튜디오 클라우드 이전(FE2-763), 통합기획전·리워드 상세 정비가 핵심입니다. QA-22xxx 버그픽스·i18n 동기화 커밋 다수는 생략합니다.
>
> ### FE2-734 — 메이커 스튜디오(펀딩) 스토리·인트로 가이드 고도화
> - 스토리 작성 가이드·기본 템플릿을 **카테고리 유형별**로 노출(빈 스토리에만 노출해 작성 본문 덮어쓰기 방지), 리워드 설계 가이드·툴팁 보강, 목표금액 가이드 카테고리별 노출, 지역 선택 placeholder 사업자 유형별 분기, WAi 랜덤 질문칩 추가. 만들기 모달·인트로에 **모두의펀딩 캠페인 배너**·뱃지·FAQ 추가(배너 이미지를 메이커 이용 언어 기준으로 분기) (`studio/funding/.../StoryEditorField/`, `CorporationRegistration.tsx`).
>
> ### FE2-763 / FE2-764 — 스튜디오 클라우드 이전·환경 정리
> - 스튜디오(store·startup) 환경별 패스 대응, `VITE_AI_CHATDATA_HOST`·`VITE_AD_CENTER_HOST`·`AD_CENTER_URL` 등 미사용 환경 변수/상수 제거, 광고 상품 카드 섹션을 LLM 메시지 영역 위로 이동, E2E 펀딩 프로젝트 ID 시크릿 변경.
>
> ### FE1-1287 / FE1-1294 / FE1-1283 — 통합기획전
> - FE1-1287: 오픈예정→진행중 전환 프로젝트 뒤로가기 시 기획전 상세 복귀. FE1-1294: 섹션 타이틀 비면 `IntroductionText` 미렌더로 여백 제거. FE1-1276: 기획전 상세 unload 이벤트를 pagehide로 교체. FE1-1283: 컬렉션 페이지 카드를 `CurationProjectCard`로 교체.
>
> ### QA-22718 / FE1-1188 — 리워드 상세·카드 정비
> - QA-22718: 리워드 정보 제공 고시 펼치기/접기(국내·글로벌), 정보 탭 중복 노출 제거, 블록 간격 조정. FE1-1188(PD-1943): AD1 카드 DOM 재구성·리워드 설명 1줄 말줄임·높이 hug 처리.
>
> ### Sentry / 검색 — FE1-1291·FE1-1293·FE1-1284·FE1-714
> - FE1-1291: global Sentry 사용자 식별(setUser)을 isolation scope로 설정(후속 Revert 포함). FE1-1293/FE1-1284: 찜/위시 빈 응답·encUserId 누락 원인 수집 Sentry 로그 추가. FE1-714: 큐레이션 피드 offset 전진·무한 페칭 가드, encUserId `-1`·식별자 부재 시 최근검색어 요청 차단.
>
> ---
>
> 📅 **2026-07-10 master pull 보강** (직전 갱신 2026-06-18 이후 약 684 커밋, 이슈키 60여 종)
>
> 상위 net-new 테마만 추립니다. QA-22xxx 계열 버그픽스 37종 다수는 개별 나열 생략.
>
> ### FE2-670 — apps/global E2E 테스트 앱 신규 추가
> - `apps/global`(글로벌 SPA) 전용 Playwright E2E 프로젝트를 별도 앱으로 신설. 메이커 홈 시나리오부터 시작하며 rc·rc2 환경 스케줄과 브랜치 체크아웃 매핑 포함 (`apps/global-e2e/` — `playwright.config.ts`, `auth.setup.ts`, `maker/`, `helpers/env.ts`)
>
> ### FE2-423 / FE2-648 / FE2-649 / FE2-567 — 매출UP 메이커 광고 페이지 신설
> - 글로벌 앱에 메이커 광고 제안 페이지 신규 구현. WAi greeting instruction(인사말 지침·천 단위 컴마·80자 요약·`<br />` 전용 줄바꿈 규칙), 단계별 전략, 광고 상품 카드 섹션 리뉴얼, 지면별 GA 데이터 수집 (`apps/global/src/pages/maker/ad/` — `MakerAdPage.tsx`, `_lib/salesUpGreetingInstruction.ts`, `_lib/salesUpStrategy.constants.ts`, `_lib/salesUpFallbackCopy.ts`, `_ui/SalesUpOpeningSection/`, `_ui/AdServiceCardSection/`)
> - 메이커홈 WAi greeting 본문 지침 분리·고도화 (FE2-567)
>
> ### FE1-1060 / FE1-1061 / FE2-634 — 클라우드 도메인 wadiz.co → wadiz.io 전환
> - 클라우드 환경 도메인을 `wadiz.co` 에서 `wadiz.io` 로 교체하는 전역 설정 변경. 게이트웨이·스토리 이미지 클라우드 판별과 WAi WebSocket 호스트를 `.io` 기준으로 통일, cdev 환경 교체, `getCloudTld` 제거로 `.io` 전용화 (`static/packages/fetch-api/src/utils/fetchUrl.ts`, `apps/global/src/features/wai/lib/useWAiWebSocket.ts`, `static/services/admin/proxyInfo.js`)
> - clive 웹 호스트 `clive.wadiz.io` → `www.wadiz.io`, 스튜디오 클라우드 도메인 `.co` → `.io` (FE2-634)
> - 로컬 인증서를 `wadiz.io`·`wadiz.com` 포함 4개 TLD로 갱신 (FE1-1061)
>
> ### FE1-988 — GNB 친구 탭 → 와디즈 에디션 탭 교체
> - 하단 네비게이션(BottomNavigationBar) 친구 탭을 "와디즈 에디션" 탭으로 교체, 데스크탑에서 에디션 기획전 네비게이션·목록 노출, 신규 에디션 아이콘 추가 (`packages/ui/src/BottomNavigationBar/BottomNavigationBar.constants.tsx`, `packages/waffle-icons/src/components/EditionIcon.ts`·`EditionOIcon.ts`, `assets/edition.svg`)
>
> ### FE1-927 — 펀딩 상세 E2E testid 대량 추가 (regression 대비)
> - 펀딩 상세의 탭바(탭별), 커뮤니티 필터·섹션·CTA·팔로우·모달, 리워드 선택 모달 Continue to Checkout 버튼 등에 E2E testid 부여. 셀렉터가 아닌 검증용 testid 정리 포함
>
> ### FE2-461 — 모두의 펀딩 자동 랜덤처리
> - 메인 파인딩 배너의 "모두의 펀딩" 자동 랜덤 처리 및 GA label 정비, 스토어 스튜디오 검색 서비스 연동 (`packages/widgets/src/home/ui/MainFindingBanner/MainFindingBanner.tsx`, `studio/store/src/services/serviceApi/search.ts`)
>
> ### FE2-472 — 스토어/입고 스튜디오 E2E 보강
> - 입고 진입 등 스토어 스튜디오 E2E 테스트 추가와 라이브 환경 실행 차단 가드·부재 시 스킵 가드 도입
>
> ### FE1-1110 — 국내 결제수단 뱃지 복원
> - 국내 결제 화면 간편결제·토스 뱃지 복원. 결제 페이지 데이터·campaigns 서비스 응답 반영 (`apps/global/src/pages/funding/payment/_api/usePaymentPageData.ts`, `packages/api/src/web/funding/campaigns.service.ts`)
>
> ### FE1-1042 / FE1-978 — 메이커 기획전 쿠폰·정렬 개편
> - 쿠폰 범위 min/max 개방 구간 입력 지원, 정렬 기준 enum화(최근 오픈순 추가)·정렬 위치 이동, 쿠폰 입력을 정렬과 무관하게 항상 노출/저장 (FE1-1042)
> - dev 환경에서 `maker-projects` 쿼리 파라미터로 메이커 기획전 응답 오버라이드 (FE1-978)
>
> ### FE1-1012 — 기획전 Framer 카드 data-ec 수집
> - 기획전 Framer 카드에 표준 `data-ec` 오버레이 수집 구현. 오버레이 렌더 전 iframe 클릭 차단으로 수집 오차 방지, `data-ec-list` 프레이머 구분값을 framer URL path 기준으로 변경
>
> ### FE1-1097 — 위시/로그인 EncUserId 수집·Sentry 관측
> - static main 라우터 errorElement에 Sentry 관측 추가, 위시 목록 `encUserId` 미존재 대응 및 로그인 EncUserId 누락 수집(`useLoginStatus` 반환값 기준)
>
> ### FE1-1089 / CLIENT-177 — 메일 템플릿
> - 개인정보 이용내역 메일 템플릿 개편 (FE1-1089)
> - `mail-template` 워크플로에 cdev 환경 추가·`build:cdev` 스크립트 도입, `build:dev` 제거 (CLIENT-177)
>
> ### FE1-1032 — account 앱 검색/alias 정비
> - account 앱에 `@wadiz/format`·`@wadiz/queries` alias 추가, `useSearchHelper`의 `@wadiz/queries` 의존을 `AccountSettings`로 교체, 최근 검색어 API `encUserId` 타입을 string 허용으로 확장
>
> ### FE1-973 — 리워드 보유기간/배송지
> - 보유기간 경과·취소 건 배송지 미노출 처리 및 목록 보유기간 안내 문구 추가
>
> ---

> **Phase 2 심층 분석 진행 중**. 도메인별 상세는 `api-details/` 하위 참조.
>
> | 영역 | 파일 |
> |---|---|
> | 사용자 지향 apps (account/global/help-center/ir/partners/partnerzone) | [`api-details/apps-user-facing.md`](./api-details/apps-user-facing.md) |
> | 메이커/스튜디오 apps (studio/*/ wai/walink/mail/devtools) | [`api-details/apps-maker-studio.md`](./api-details/apps-maker-studio.md) |
> | static/entries/ (레거시 호환 진입점 13개) | [`api-details/static-entries.md`](./api-details/static-entries.md) |
> | static/services/admin (와디즈 어드민 SPA) | [`api-details/admin-spa.md`](./api-details/admin-spa.md) |
> | packages/ (공유 패키지 20+) | [`api-details/packages.md`](./api-details/packages.md) |
> | **모든 페이지 전수 카탈로그** (270+ 페이지) | [`api-details/pages-catalog.md`](./api-details/pages-catalog.md) |
> | **기능 이정표** (기능·문구 → 소스 역탐색, 영역별 폴더) | [`api-details/feature-signpost/`](./api-details/feature-signpost/README.md) |

## 개요
와디즈의 **신규 프론트엔드 모노레포**. "모든 FE 서비스를 단일 저장소에서 운영"이라는 목표로 다수의 앱(account, global, partners, ir, partnerzone, help-center, mail-template, wai-ai-agent-launcher, walink-generator)을 한 곳에 묶었습니다. `com.wadiz.web` (Spring 3.2 + JSP) 의 점진적 후계. Org: `wadiz-fe`.

## 기술 스택
- **빌드/패키지**: pnpm + turbo (모노레포), 일부 `static/` 영역에 yarn workspace 잔존.
- **프레임워크**: React 18, Vite 6, Next.js 14·16 혼재(앱별).
- **상태/데이터**: TanStack Query, Zustand, Recoil(잔존), 자체 Custom Hooks.
- **스타일**: SCSS Modules, Tailwind, Emotion 일부.
- **테스트**: Vitest, Storybook, Playwright (앱별).

## 앱/패키지 구성

### `apps/`
| 앱 | 역할 | 호출 Upstream |
|---|---|---|
| `account` | 글로벌 회원 (로그인/회원가입/프로필) | `account.wadiz.kr`, `app.wadiz.kr` |
| `global` | 글로벌 사이트 | `public-api.wadiz.kr`, `app.wadiz.kr` |
| `partners` | 파트너 소개 | `public-api.wadiz.kr` |
| `partnerzone` | 파트너존 (입점·운영) | `app.wadiz.kr`, `platform.wadiz.kr` |
| `ir` | IR (투자자 정보) | static + 일부 API |
| `help-center` | 고객센터 | `app.wadiz.kr` |
| `mail-template` | 이메일 템플릿 빌더 | n/a |
| `wai-ai-agent-launcher` | WAi AI 에이전트 런처 | `app.wadiz.kr` (WAi) |
| `walink-generator` | 와링크(단축 URL) 생성기 | `app.wadiz.kr/links` |
| `devtools/*` | 개발자 도구 | n/a |

### `studio/`
- `funding`, `startup`, `store` — 메이커/스튜디오 작성 도구.

### `static/entries/` (15개)
- 레거시 호환용 정적 진입점들. 기존 `com.wadiz.web` 의 페이지 단위로 분리되어 점진 이관됨.

### `static/services/`
- `admin` — 와디즈 어드민 SPA(webpack 4). PROXY_TARGET 환경변수로 `devadm/rcadm/rc2adm.wadiz.kr` 또는 `adm.dev.wadiz.co` 로 프록시.

### `packages/` / `libraries/`
- 공통 UI, API 클라이언트, 디자인 토큰, 유틸 등.

## 서버 연결 설정 (핵심)

### 환경 변수 주입
- 빌드: `env-cmd --environments {local|dev|rc|rc2|rc3|stage|live}` + `.env-cmdrc` → Vite `define` 에서 `process.env.*` 로 치환.
- 주요 환경변수:

| 변수 | 의미 |
|---|---|
| `VITE_ACCOUNT_URL` | 회원 IdP (`account.wadiz.kr`) |
| `VITE_APP_API_URL` | NestJS BFF (`app.wadiz.kr`) |
| `VITE_PLATFORM_API_URL` | 플랫폼 API (쪽지/알림/Nicepay/share/marketing) |
| `VITE_PUBLIC_API_URL` | 비로그인 공개 API (`public-api.wadiz.kr`) |
| `VITE_SERVICE_API_URL` | 레거시 서비스(`www.wadiz.kr` `/web/*`, `/web/apip/funding/*`) |
| `VITE_PLATFORM_GLOBAL_API_URL` | 플랫폼 글로벌 |

### Upstream 서버 매핑
| 도메인 | 실체 |
|---|---|
| `account.wadiz.kr` | `kr.wadiz.account` (OAuth2 IdP) |
| `www.wadiz.kr` | `com.wadiz.web` (레거시 Spring 3.2) |
| `app.wadiz.kr` | `app-api` (NestJS BFF) |
| `platform.wadiz.kr` | 플랫폼 서비스 군 (쪽지·알림·Nicepay·share·marketing) |
| `public-api.wadiz.kr` | 비로그인 공개 API |
| `api.makercenter.wadiz.kr` | `makercenter-be` (메이커센터 공지 임베드용) |
| `analytics.wadiz.kr` / `datasvc.wadiz.kr` | 데이터/애널리틱스 |

### Fetch 래퍼
- 위치: `packages/api/src/fetch.ts:22-105`
- HTTP 메서드: GET/POST/PUT/PATCH/DELETE.
- 기본 헤더: `wadiz-country`, `wadiz-language` (i18n 라우팅용).
- Credentials: `same-origin` (쿠키 세션 기반 인증, 와디즈 통합 도메인 전략).
- 인터셉터: 401/403 시 `account.wadiz.kr` 재로그인 리다이렉트.

## 기능별 API 호출 매핑 (대표)

| 기능/화면 | Method + Path | 용도 | Upstream |
|---|---|---|---|
| 로그인 | POST `/account/oauth/...` | 세션 발급 | account.wadiz.kr |
| 세션 → 토큰 교환 | GET `/session2token` | API 호출용 토큰 발급 | app.wadiz.kr |
| 펀딩 메인 피드 | GET `/web/main` | 메인 카탈로그 | www.wadiz.kr (레거시) |
| 펀딩 프로젝트 상세 | GET `/web/apip/funding/projects/:id` | 프로젝트 정보 | www.wadiz.kr |
| 서포터 목록 | GET `/web/apip/funding/projects/:id/supporters` | 서포터 리스트 | www.wadiz.kr |
| 마이펀딩 | GET `/web/myfunding` | 내가 후원한 프로젝트 | www.wadiz.kr |
| 리워드 정보 | GET `/web/apip/funding/reward/...` | 리워드 옵션 | www.wadiz.kr |
| Nicepay 결제 | POST `/platform/nicepay/...` | PG 결제 인증/승인 | platform.wadiz.kr → nicepay-api |
| 쪽지함 (Inbox) | GET `/platform/inbox/...` | 쪽지 조회 | platform.wadiz.kr |
| 마케팅 알림 | POST `/platform/marketing/...` | 알림 옵트인 | platform.wadiz.kr |
| 공유 링크 | POST `/platform/share/...` | 공유 링크 발급 | platform.wadiz.kr |
| 회원 가입 | POST `/account/signup` | 가입 | account.wadiz.kr |
| WAi 에이전트 | POST `/app/wai/...` | AI 에이전트 호출 | app.wadiz.kr |
| 와링크 생성 | POST `/app/links/...` | 단축 URL 생성 | app.wadiz.kr |
| 검색 | GET `/web/search?q=...` | 통합 검색 | www.wadiz.kr |
| 멤버십 | GET `/web/membership/...` | 멤버십 정보 | www.wadiz.kr |
| 메이커센터 공지 임베드 | GET `/api/makercenter/notices/...` | 공지 임베드 | api.makercenter.wadiz.kr |

> Bearer 토큰: `packages/api/src/platform/inbox.service.ts:8-10` 와 `.env-cmdrc` 에 platform inbox/marketing 용 토큰이 하드코딩되어 있음 — **보안 점검 필요 항목**.

## 빌드·배포

- 명령: `pnpm install`, `pnpm dev:<app>`, `pnpm build:<app> --env <env>`.
- turbo pipeline 으로 의존 패키지 우선 빌드.
- 배포: 앱별 S3 + CloudFront 또는 Next 서버. GitHub Actions로 환경별(`dev`, `rc`, `stage`, `live`) 배포.
- `static/services/admin` 은 webpack 4 단독 빌드 (PROXY_TARGET 분기).

## 특이사항

- 모노레포지만 **앱별 빌드 도구가 다름** (Vite 6 vs Next 14 vs Next 16). 점진 통일 진행 중.
- `static/entries/` 는 레거시 JSP에서 직접 import 하던 정적 번들의 후계 — `com.wadiz.web` 이관의 흔적.
- `account.wadiz.kr` 도메인 분리 IdP 전략으로 모든 와디즈 서비스가 단일 OAuth2 세션 공유.
- 환경별 토큰·URL이 `.env-cmdrc` 에 모여 있어 한 파일로 다환경 관리.
- 어드민(static/services/admin)은 아직 webpack 4 — 모더나이제이션 후순위.

---

## 최근 변경사항

**분석 갱신일: 2026-07-10** (최초: 2026-04-20 / 직전: 2026-06-18 — 최신 net-new는 문서 상단 2026-07-10 보강 블록 참조)

### 계정 / 로그인 (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 와디즈 앱 웹뷰에서 구글/페이스북 SNS 로그인·가입 차단(임베디드 웹뷰 OAuth 정책 대응). 차단 시 안내 알럿 노출, `isWadizAndroidApp`/`isWadizIosApp` UA 플래그로 앱 웹뷰 판별 | 2026-06-17 | FE1-846 |
| 인앱 SNS 차단 로직(`inAppBlacklist`/`isInAppBlock`/`inAppBlackHandler`)을 `apps/account/src/shared/oauth/inAppBlock.js` 단일 모듈로 공통화(기존 import는 re-export 유지). 차단 표시명을 `WADIZ_APP` 상수로 통합 | 2026-06-17 | FE1-846 |
| JSP 문서 캐싱으로 인한 로그인 갱신 이슈 수정 — `AccountSettings` 생성자에서 `window.wadiz.globals` 기반 초기화 제거, 항상 `initialize()` 호출로 세션 확인하도록 변경 | 2026-06-16 | FE1-950 |

### 개발자 도구 — 앱 설정 콘솔(app-settings-console) 전면 개편 (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| FSD(Feature-Sliced Design) 구조로 재구성(app/pages/entities/shared), axios→네이티브 fetch 전환, CSS Modules + WDS 토큰 도입, Button·Select·AppSettingCard 컴포넌트 분리 | 2026-06-15~16 | CLIENT-104 |
| `local` 환경 + `platform`(web/web-server) 선택 추가, 환경·플랫폼 선택값을 URL 쿼리 파라미터로 유지, 우측 상단 환경 워터마크 표시, app-settings API 네임스페이스 방식 호출 | 2026-06-15~16 | CLIENT-104 |
| 상세는 [`api-details/apps-maker-studio.md` §8-A](./api-details/apps-maker-studio.md) 참조 | | |

### 글로벌 / 펀딩 상세 (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 직접 입력 옵션 안내문구 노출 — by-country 리워드 응답의 `optionGuide` 필드 정합 및 안내문구 폰트/색상/간격 디자인 대응 | 2026-06-18 | FE1-979 |
| 마이와디즈 공지 배너 여백 보정(PC 16px/MO 10px) + 서포터 클럽 혜택 가로 스크롤 페이드 그라데이션 오버레이 추가 | 2026-06-16 | FE1-952 |

### 스튜디오 / 스토리 AI (2026-06)
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 스토리 생성 AI 진입구 확대 — 프로젝트 만들기 페이지·펀딩 스튜디오에 StoryGenerationBanner/StoryGenerationSection·AITextButton 등 진입 UI 추가 | 2026-06-15 | FE2-532 |
| 펀딩 스튜디오 시작·종료일 기간 표기 오류 수정 — 기간 계산 유틸(`helpers/date.ts`) 추가 후 일정/오픈예정 현황 페이지에 적용 | 2026-06-16 | FE2-543 |
| 스튜디오 e2e schedule GitHub Action 추가(시크릿 키 inputs 선언 포함) | 2026-06-17 | FE2-549 |

### studio-services 신규 API 클라이언트 (2026-06)
| 변경 내용 | 관련 이슈 |
|---|---|
| `funding/campaign-markers.services.ts` — 인디맨드 펀딩 여부 조회(`/web/apip/funding/campaign-markers/{id}/indemand-funding`) | |
| `funding/studio-stripe-accounts.services.ts` — Stripe Connect 계정 상태 조회(`PayoutMethodType` NICE/PINGPONG/STRIPE, `StripeKycStatus` 10종) | |
| `reward/maker-communications.services.ts` — 언어별 메이커 피드백 최신/히스토리·추가 질문 조회(`/web/reward/api/v2/maker-communications/...`) | |
| `reward/studio-campaigns.services.ts` — 사후심사 재제출(`revival-re-submit`) 및 스튜디오 캠페인 상태/배너 응답 타입 | |

### 글로벌 / 결제
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 글로벌 결제 화면 통화 표기·멤버십 배지 노출 정비 | 2026-05-22 | FE1-743 |
| 글로벌 선정산 도입 — 이용약관·메이커 이용약관·메일 템플릿 다국어 | 2026-05-21~22 | FE2-401/402 |
| 스트라이프 커넥트 메일 템플릿 핑퐁 영역 수정 | 2026-05-27 | FE2-270 |

### 서포터클럽
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| CurationSupporterClubCard 컴포넌트 추가 및 카드 교체 | 2026-05-26 | FE1-762 |
| 서포터클럽 인트로 페이지 디자인 수정, 해지방어 페이지 카드 너비 분리 | 2026-05-26 | FE1-762 |

### 스튜디오 / 스튜디오 e2e
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 스튜디오 Sentry 소스맵 빌드 추가 | 2026-05-27 | FE2-422 |
| 펀딩 스튜디오·스토어 스튜디오 e2e 테스트 코드 추가 | 2026-05-22~27 | FE2-408/409 |
| 클라우드 이전 — 스튜디오 동적 URL 생성, PostMessage origin 검증, Sentry URL 정규식 | 2026-04-21 | FE2-193/194/195 |

### 기능 추가 / 변경
| 변경 내용 | 날짜 | 관련 이슈 |
|---|---|---|
| 기획전 캐시 저장 웹 환경 활성화 | 2026-05-22 | FE1-737 |
| 플랫폼별 타임아웃 분기 (펀딩 상세) | 2026-05-21 | FE1-712 |
| 브레이즈 이벤트 필드 Number 강제 변환 가드 | 2026-05-21 | FE1-728 |
| 리워드 다중 펼침 지원 | 2026-04-20 | FE1-444 |
| 협력기관 배너 디자인 모드 지원 | 2026-04-21 | FE1-428 |
| Readable한 스토리 구조화 (메이커 사이드) | 2026-04-20~21 | FE2-272 |
