# Flow: <기능명>

> 요약 한 줄 — 이 기능이 무엇인지, 사용자가 어느 시점에 트리거하는지.

## 기록 범위
- 읽은 파일·경로·버전
- 외부 경계 (외부 jar, 외부 서비스, 관측 불가 영역 명시)

---

## 1. Client Trigger (FE/App)

### 1.1 `wadiz-frontend` (웹)
- **화면 파일**: `packages/ui/...` 또는 `apps/.../pages/...` (`path:line`)
- **훅/서비스**: `packages/queries/src/...` 또는 `apps/.../hooks/...`
- **호출 API**:
  - `GET /web/apip/funding/...` → upstream `www.wadiz.kr` (com.wadiz.web)
  - `GET /api/...` → upstream `app.wadiz.kr` 또는 `platform.wadiz.kr`
- **상태·캐싱**: TanStack Query `queryKey`, stale time

### 1.2 `wadiz-android` / `wadiz-ios` (앱)
- **화면 모듈**: `feature/...` 또는 `Projects/Features/...`
- **Retrofit/Endpoint**: 인터페이스 path:line
- **호출 API**: (위와 동일하거나 앱 전용 경로)

---

## 2. Hub — `com.wadiz.web`
웹 레거시 hub. FE/앱 요청을 받아 내부 서비스 API로 fan-out.

- **Controller**: `com/wadiz/web/.../XxxController.java:NN` (`@GetMapping(...)`)
- **처리 흐름**:
  1. 요청 파라미터·세션·쿠키 파싱
  2. 인증/권한 체크 (Interceptor: `path:line`)
  3. **Upstream 호출** (RestTemplate/Feign/WebClient) — 어떤 서비스 어떤 endpoint
  4. 응답 변환 · JSP 렌더링 또는 JSON 반환
- **JSP 뷰** (해당 시): `web/WEB-INF/jsp/.../xxx.jsp`
- **캐싱** (해당 시): EhCache · Redis key pattern

---

## 3. Backend Service API
실제 비즈니스 로직 수행 레이어.

### 예: `com.wadiz.api.funding`
- **Controller** → UseCase → Repository → SQL
- 상세: [`docs/com.wadiz.api.funding/api-details/<domain>.md`](../com.wadiz.api.funding/api-details/)

### (추가 upstream, 해당 시)
- `com.wadiz.api.reward` — 쿠폰·만족도
- `com.wadiz.wave.user` — 유저·서포터 정보
- `kr.wadiz.account` — 인증
- `nicepay-api` — 결제

---

## 4. DB

| 테이블 | 역할 | 접근 서비스 |
|---|---|---|
| `t_xxx` | ... | funding |
| `t_yyy` | ... | reward |
| ...

- 주요 SQL 본문 (MyBatis XML 발췌)

---

## 엔드투엔드 시퀀스 (ASCII)

```
[FE: pages/xxx.tsx]
     │ GET /web/apip/funding/xxx
     ▼
[com.wadiz.web: XxxController#method]
     │ fundingClient.call(...)
     ▼
[com.wadiz.api.funding: XxxController → UseCase → Repository]
     │ SELECT ... FROM t_xxx WHERE ...
     ▼
[MySQL: t_xxx, t_yyy]
```

---

## 경계·미탐색
- 외부 jar 내부 로직
- 별도 문서 참조
- 추후 확장 포인트
