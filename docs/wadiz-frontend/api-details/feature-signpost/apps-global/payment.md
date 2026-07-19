> 상위 인덱스 [`../README.md`](../README.md) · 도메인 목록 [`./README.md`](./README.md). 기준 master `4439853b8dd`. i18n 원문은 `packages/i18n/src/supporter/languages/{ko,en}.json`.

# 결제 (Funding Payment)

> 소스: `apps/global/src/pages/funding/payment/**`(결제·완료·대기 페이지), `packages/features/src/funding-payment`(할부 안내), `packages/features/src/simple-pay`(간편결제).
> 국내/글로벌 분기: 결제수단·결제금액 섹션이 국내(NicePay·간편결제 등)와 글로벌(Stripe·Alipay·USD 표기)로 나뉩니다.

## 결제 페이지 (레이아웃 · 헤더)

관련 이슈: `FE1-42`(한국/글로벌 결제 동선 통합 · 에픽), `FE1-469`(달러 결제 Phase 3 — 결제 페이지/결제수단 분기)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 페이지 헤더 — `header.title`="주문 및 결제" / EN "Order and Payment" | `apps/global/src/pages/funding/payment/FundingPaymentDesktopPage.tsx` |
| 결제 페이지 모바일 진입 · 실패 모달 트리거 (`payment_failure_modal.*`, `invalid_order_message`="유효하지 않은 주문이에요.") | `apps/global/src/pages/funding/payment/FundingPaymentPage.tsx` |
| 데스크톱/모바일 레이아웃 분기 (구조 파일) | `apps/global/src/pages/funding/payment/FundingPaymentLayout.tsx` |
| 결제 체크아웃 상태/컨텍스트 (상태 모델) | `apps/global/src/pages/funding/payment/_model/useFundingCheckout.tsx` |

## 리워드 · 배송지 · 서포터 정보

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 선택한 리워드 — `reward_section.title`="선택한 리워드", `option_label`="옵션", `shipping_fee_label`="배송비", `optional_tip_label`="추가 후원금" | `apps/global/src/pages/funding/payment/_ui/RewardsSection/RewardsSection.tsx` |
| 리워드 배송지 — `shipping_address_section.title`="리워드 배송지", `customs_code_label`="개인통관고유부호", `new_address_button_label`="신규 배송지 추가" | `apps/global/src/pages/funding/payment/_ui/ShippingAddressSection/ShippingAddressSection.tsx` |
| 서포터 정보 — `supporter_section.title`="서포터 정보", `phone_label`="휴대폰 인증", `newsletter_label`="펀딩 새소식 및 결제 관련 안내를 받습니다. (필수)" | `apps/global/src/pages/funding/payment/_ui/SupporterSection/SupporterSection.tsx` |
| 서포터클럽 특별가 프로모션 — **하드코딩** "서포터클럽 올인원 특별 금액", "할인 금액" | `apps/global/src/pages/funding/payment/_ui/SupporterClubPromotion/SupporterClubPromotion.tsx` |

## 할인 (쿠폰 · 포인트)

관련 이슈: `FE1-644`(달러 쿠폰 — 서포터 쿠폰 다운로드 지면)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 쿠폰·포인트 적용 — `discount_section.title`="쿠폰,포인트 적용", `coupon_label`="쿠폰", `points_label`="포인트", `use_all_button_label`="모두 사용", `current_point_text`="보유 포인트: {{arg_0}}P" | `apps/global/src/pages/funding/payment/_ui/DiscountSection/DiscountSection.tsx` |
| 쿠폰 선택 메뉴 — `coupon_enabled_placeholder`="쿠폰을 선택해 주세요", `coupon_empty_option_label`="쿠폰 사용 안 함", `coupon_available_until_text`="{{arg_0}}까지 사용 가능" | `apps/global/src/pages/funding/payment/_ui/DiscountSection/components/CouponSelectMenu/CouponSelectMenu.tsx` |

## 결제수단

관련 이슈: `FE1-469`(결제수단 분기), `FE1-611`(iOS 26 간편결제 비밀번호 가상키패드 핫픽스), `FE1-1057`(토스페이 혜택 문구 수정)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 수단 섹션 (국내/글로벌 분기) — `payment_method_section.title`="결제 수단" / EN "Payment method", `pay_now_label`="지금 결제"/"Pay now", `scheduled_payment_label`="예약 결제"/"Pay later", 글로벌은 Stripe/Alipay 렌더 | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/PaymentMethodSection.tsx` |
| 국내 결제수단 목록 컨테이너 (신용/체크카드·간편결제·카카오/네이버/토스/애플페이 조합) | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/KoreaPaymentOptions.tsx` |
| 신용/체크카드(NicePay) + 장기할부 옵션 — **하드코딩** "신용/체크카드" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/NicePayOption.tsx` |
| 카드 할부 개월 선택 — **하드코딩** "일시불", "2개월"~"11개월" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/DirectPayOption.tsx` |
| 와디즈 간편결제 선택 — **하드코딩** "와디즈 간편결제" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/SimplePayOption.tsx` |
| 카카오페이 (로고 아트웍) | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/KakaoPayOption.tsx` |
| 네이버페이 (카드/포인트 서브옵션) — **하드코딩** "카드 결제", "포인트 결제", "복합결제(카드+포인트)는 지원하지 않아요…" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/NaverPayOption.tsx` |
| 토스페이 (프로모션 배너) — **하드코딩** "최대 3천원", "생애 첫 결제 시 : 5만원 이상 결제 시 3,000원 할인…" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/TossPayOption.tsx` |
| 애플페이 (로고 아트웍) | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/ApplePayOption.tsx` |
| 현금영수증 신청 폼 — **하드코딩** "현금영수증", "신청", "미신청", "소득공제용" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/options/CashReceiptForm.tsx` |
| 참여 공개여부 선택 — **하드코딩** "프로젝트 참여 공개여부 (선택)", "이름 비공개", "금액 비공개" | `apps/global/src/pages/funding/payment/_ui/PaymentMethod/PublicitySection.tsx` |

## 결제 금액

관련 이슈: `FE1-388`(글로벌 달러 결제 도입 · 에픽), `FE1-743`(결제금액 섹션 표시통화 기본 노출)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 금액 요약 — `payment_amount_section.title`="결제 금액" / EN "Payment amount", `total_payment_amount_label`="총 결제 금액", `reward_label`="리워드 금액", `shipping_label`="배송비", `coupon_label`="쿠폰 할인", `point_label`="포인트 할인" | `apps/global/src/pages/funding/payment/_ui/PaymentAmountSection/PaymentAmountSection.tsx` |
| 글로벌 결제 금액(USD/현지통화) — `usd_payment_notice`="결제는 USD로 처리됩니다.", `view_local_currency_button_label`="현지 통화 보기", `krw_billing_notice`="표시된 금액은 대략적인 환산 금액이며, 실제로는 {{arg_0}}으로 청구됩니다." | `apps/global/src/pages/funding/payment/_ui/PaymentAmountSection/GlobalPaymentAmount.tsx` |

## 약관 동의 · 결제하기(체크아웃)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 약관 동의 + 결제하기 버튼 — `button_section.submit_button_label`="결제하기" / EN "Submit Payment", `submit_button_label_v2`="{{arg_0}}원 결제하기", `terms_and_conditions_section.title`="주문을 제출함으로써 다음 사항에 동의하는 것으로 간주합니다." | `apps/global/src/pages/funding/payment/_ui/TermsAndCheckout/TermsAndCheckout.tsx` |
| 국내 필수 약관 체크리스트 — **하드코딩** "결제 진행 필수 동의", "구매조건, 결제 진행 및 결제 대행 서비스 동의(필수)", "개인정보 제3자 제공 동의 (필수)" | `apps/global/src/pages/funding/payment/_ui/TermsAndCheckout/RewardPaymentTerms.tsx` |
| 환율(FX) 조회 실패 처리 — `funding_payment_page` 프리픽스 에러 안내 | `apps/global/src/pages/funding/payment/_ui/BillingFxErrorHandler/BillingFxErrorHandler.tsx` |

## 간편결제 (`packages/features/src/simple-pay`)

> 이 폴더는 `useTranslation` 미사용 — 문구 전부 **하드코딩**(국제화 후보).

관련 이슈: `FE1-611`(iOS 26 간편결제 비밀번호 모달 핫픽스)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 간편결제 카드 등록 모달(2스텝) — "간편결제 등록하기" / "간편결제 비밀번호 입력", "카드 등록하고 빠르게 결제해요." | `packages/features/src/simple-pay/ui/CardRegistrationModal/CardRegistrationModal.tsx` |
| 카드 정보 입력 폼 — "신용/체크카드", "유효기간", "카드 비밀번호", "생년월일", "스캔으로 자동 등록하기" | `packages/features/src/simple-pay/ui/CardInfoForm/CardInfoForm.tsx` |
| 결제 비밀번호 설정 폼 — "결제 비밀번호", "결제 비밀번호 재입력", "비밀번호 6자리" | `packages/features/src/simple-pay/ui/CardPasswordForm/CardPasswordForm.tsx` |
| 카드 등록 완료 모달 — "간편결제 정보가 안전하게 등록되었습니다.", "참여 중인 프로젝트 결제도 변경할게요", "확인" | `packages/features/src/simple-pay/ui/CardRegisterSuccessModal/CardRegisterSuccessModal.tsx` |
| 간편결제 비밀번호 확인 모달 — "결제 비밀번호 입력", "…결제 비밀번호 6자리를 입력하세요.", "비밀번호를 잊어버리셨나요?" | `packages/features/src/simple-pay/ui/SimplePayPasscodeConfirmModal/SimplePayPasscodeConfirmModal.tsx` |
| 등록 카드 표시 UI (삭제/유효기간 만료 안내) — "유효기간", "해당 카드의 유효기간이 만료 되었습니다.", "결제 정보를 삭제하시겠어요?" | `packages/features/src/simple-pay/ui/SimplePayCard/SimplePayCard.tsx` |
| 비밀번호 입력 숫자패드 — "전체 삭제", "삭제" | `packages/features/src/simple-pay/ui/NumPad/NumPad.tsx` |
| 참여 중 프로젝트 결제정보 일괄 변경 — 토스트 "선택한 프로젝트의 결제 정보가 변경되었습니다." / "결제정보 변경 중 오류가 발생했습니다…" | `packages/features/src/simple-pay/lib/changePaymentReservation.tsx` |
| 간편결제 데이터 조회 훅 | `packages/features/src/simple-pay/api/useSimplePay.ts` |

## 할부 안내 (`packages/features/src/funding-payment`)

> 문구 전부 **하드코딩**.

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 무이자/장기 할부 안내 모달 — 탭 "무이자 할부 안내", "장기 할부 안내", "부분 무이자할부 안내…", "[유의사항]" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/InterestFreeInfoModal.tsx` |
| 할부 안내 진입 버튼 — "신용/체크 카드 할부 안내" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/InstallmentInfoButton.tsx` |
| 무이자 할부 안내 버튼 — "무이자 할부 안내" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/InterestFreeInfoButton.tsx` |
| 장기 할부 안내 버튼 — "장기 할부 안내" | `packages/features/src/funding-payment/ui/InterestFreeInfoModal/LongTermInstallmentInfoButton.tsx` |

## 결제 완료 화면

관련 이슈: `FE1-470`(달러 결제 Phase 4 — 결제 완료 + 마이와디즈 결제 상세)

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 주문 완료 헤더/요약 — `funding_payment_completed_page.header.title`="주문 완료" / EN "Your order is complete", `header.description`="프로젝트 성공 시 결제가 처리되고 결제 성공 시 리워드를 발송해요.", `content.view_my_orders_button_label`="참여 내역 보기", `back_to_details_button_label`="상세 페이지 보기" | `apps/global/src/pages/funding/payment/completed/_ui/OrderCompletedSection/OrderCompletedSection.tsx` |
| 완료 페이지 컨테이너 + AI 추천/구매 이벤트 트래킹 — **하드코딩(트래킹명)** "결제완료_AI추천" | `apps/global/src/pages/funding/payment/completed/FundingPaymentCompletedPage.tsx` |
| 메이커 팔로우 유도 — `maker_following_section.description`="메이커 소식을 받아보고 싶다면?" | `apps/global/src/pages/funding/payment/completed/_ui/OrderCompletedSection/MakerFollowingSection.tsx` |
| 해외배송 유의사항 박스 — `international_shipping_message_box.title`="유의 사항", `description_1`="해외배송 프로젝트의 경우 배송이 시작된 이후 단순변심 환불은 거절될 수 있어요…" | `packages/features/src/funding-payment/ui/PaymentCompleteInternationalShippingSection/PaymentCompleteInternationalShippingSection.tsx` |
| 배송지 국가 변경 확인 모달 — `country_change_confirm_modal.title`="국가 변경", `description`="방금 선택한 배송지 국가로 회원 정보를 업데이트 할까요?", `confirm_button_label`="국가 변경하기" | `apps/global/src/pages/funding/payment/completed/_ui/CountryChangeConfirmModal/CountryChangeConfirmModal.tsx` |

## 결제 진행 중 (pending) · 결제 실패 안내

| 기능 / 화면 문구 | 소스 위치 |
|---|---|
| 결제 진행 중 화면 — `funding_payment_pending_page.header.title`="결제 진행 중", `header.description`="처리 중이니 잠시만 기다려 주세요.", 지연 모달 `pending_failure_modal.title`="결제가 지연되고 있어요" | `apps/global/src/pages/funding/payment/pending/FundingPaymentPendingPage.tsx` |
| 결제 실패 모달 문구 모음 (i18n, 트리거는 `FundingPaymentPage.tsx`) — `payment_failure_modal.title`="결제를 진행할 수 없어요", `out_of_stock_message`="품절된 상품이 있어요…", `expired_order_session_message`="결제 유효 시간이 초과됐어요…" | `packages/i18n/src/supporter/languages/ko.json` (키 `funding_payment_page.payment_failure_modal`) |

## 이슈 히스토리 (결제 경로를 건드린 Jira 이슈)

| 이슈키 | 유형 | 제목 |
|---|---|---|
| FE1-42 | 에픽 | [FE1][프로젝트클렌징] 한국/글로벌 결제 동선 통합 |
| FE1-388 | 에픽 | [FE] 글로벌 달러 결제 도입 |
| FE1-469 | 작업 | [FE] 글로벌 달러 결제 - Phase 3: 결제 페이지 금액 표시 + 결제수단 분기 |
| FE1-470 | 작업 | [FE] 글로벌 달러 결제 - Phase 4: 결제 완료 + 마이와디즈 결제 상세 |
| FE1-611 | 버그 | [iOS 26] 간편결제 비밀번호 모달 가상키패드 터치 미동작 핫픽스 |
| FE1-644 | 스토리 | [FE] 달러 쿠폰 - 서포터 쿠폰 다운로드 지면 |
| FE1-664 | 작업 | [QA] 글로벌 달러 결제 도입 - QA 이슈 수정 |
| FE1-743 | 작업 | [Web] 글로벌 결제 페이지 결제금액 섹션에서 표시통화 기본 노출로 변경 |
| FE1-800 | 작업 | [Web] 글로벌 달러 결제 - 환불 동선 관련 후속 대응 |
| FE1-1057 | 작업 | [Web] 토스페이 혜택 문구 수정 |
| FE1-927 | 작업 | [Web] E2E 테스트를 위한 attribute 추가 |
| FE1-1110 | 작업 | [Web] 상세 통합으로 인한 Regression 기능 확인 |

---
