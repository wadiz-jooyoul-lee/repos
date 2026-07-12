# wadiz-membership — 멤버십 API + User 게이트웨이 (2 repo)

> `wadiz-membership` org 소속 2개 Spring Boot 서비스. 유료 멤버십(플랜·바우처·혜택) 관리 API 서버와 그 앞단의 Spring Cloud Gateway 로 구성된다.

## Repo 요약표

| Repo | Boot | 구조 | 역할 |
|---|---|---|---|
| `MemberShip-Api-Server` | 2.5.3 | **7 모듈 멀티프로젝트** | 멤버십 상품·혜택·회원 관리 API + 배치 |
| `User-Api-Gateway` | 2.5.4 | 단일 모듈 (Spring Cloud Gateway) | `/membership/**` 라우팅 |

두 서비스 모두 **Java 8 · Gradle · QueryDSL JPA · logback-access**.

---

## 1. `MemberShip-Api-Server` — 멤버십 코어 API

### 1.1 모듈 구성 (`settings.gradle`)

```
application              — 공통 애플리케이션 설정
web_api                  — REST 컨트롤러 (public API)
web_application          — MemberShipApplication (main web 진입점)
batch_application        — MemberShipRenewalBatchApplication (별도 배치 진입점)
infrastructure           — 외부 시스템 어댑터
infrastructure_batch     — 배치 전용 인프라
database_jpa             — JPA 엔티티·리포지토리
```

**두 개의 진입점**:
- `web_application/src/main/java/com/wadiz/api/membership/MemberShipApplication.java` — REST API 서버
- `batch_application/src/main/java/com/wadiz/api/membership/MemberShipRenewalBatchApplication.java` — 멤버십 자동갱신 배치

### 1.2 컨트롤러 (`web_api/src/main/java/com/wadiz/api/membership/controller/`)

| 컨트롤러 | 담당 도메인 |
|---|---|
| `MemberShipController` | 멤버십 조회·가입·해지 |
| `ProductController` | 멤버십 상품(플랜) |
| `BenefitController` | 혜택 |
| `UserController` | 회원 정보 |
| `admin/AdminController` | 어드민 |
| `admin/voucher/RegisterVoucherController` | 바우처 등록 |
| `admin/voucher/GetVoucherController` | 바우처 조회 |

### 1.3 의존성
- Spring Boot 2.5.3 · Java 8
- QueryDSL JPA (annotationProcessor 로 `Q*` 클래스 생성)
- logback-access-spring-boot-starter 2.7.1

### 1.4 문서 아티팩트
- `docs/src/SequenceDiagram/` — 시퀀스 다이어그램 (수동 관리)

---

## 2. `User-Api-Gateway` — Spring Cloud Gateway

### 2.1 진입점
- `src/main/java/gateway/UserApiGatewayApplication.java` (**패키지가 그냥 `gateway`** — 짧게 유지)
- 필터 설정: `gateway/filter/FilterConfig.java`

### 2.2 환경별 설정 (`src/main/resources/{dev,rc,rc2,rc3,live,local}/application.yml`)

6개 환경 프로파일 모두 존재. **라우팅 대상은 로컬 loopback (`http://127.0.0.1:9150/`)** — 사이드카 패턴으로 같은 호스트의 다른 컨테이너와 통신.

### 2.3 라우트 (`live/application.yml` 발췌)

| Order | Path | Method | Upstream |
|---:|---|---|---|
| 2 | `/membership/user/*/product/*/benefit/*` | POST | `http://127.0.0.1:9150/` |
| 1 | `/membership/user/*/product/*/benefit/*` | DELETE | `http://127.0.0.1:9150/` |
| 0 | `/membership/**` | (all) | `http://127.0.0.1:9150/` (기본 라우트) |

→ `/membership/**` 요청을 전부 로컬 `9150` 포트로 넘김. **`9150` 은 `MemberShip-Api-Server` 의 web_application 포트로 추정** (application.yml 확인 필요).

`benefit` 관련 POST/DELETE 는 `membership-aync-bridge` 라는 이름의 별도 라우트로 order 를 낮게 잡아 우선 매칭.

### 2.4 의존성
- Spring Boot 2.5.4 · Java 8
- Spring Cloud Gateway (starter-webflux 기반)
- Actuator

---

## 3. 아키텍처 관점

### 3.1 배치·게이트웨이·API 3층 구조

```
[클라이언트]
    │
    ▼
[User-Api-Gateway (Spring Cloud Gateway)]
    │ /membership/** → 127.0.0.1:9150
    ▼
[MemberShip-Api-Server (web_application)]
    │
    ├─ REST 컨트롤러 (ProductController, BenefitController, ...)
    ├─ JPA/QueryDSL → MySQL
    └─ [MemberShipRenewalBatchApplication] — 자동갱신 배치 (별도 배포)
```

### 3.2 org 이름·역할 정합성
- org 이름은 `wadiz-membership` (멤버십)
- 하지만 gateway 는 `User-Api-Gateway` — "user" 브랜드로 명명
- 라우팅은 `/membership/**` 만 담당 (범용 유저 게이트웨이가 아니라 멤버십 전용 사이드카 게이트웨이)

### 3.3 다른 org 와의 관계
- **`kr.wadiz.account`** (OAuth2 인가서버) 과의 인증 통합은 이 repo 에서 관측 안됨 (필터 설정 실제 코드 확인 필요)
- **`com.wadiz.wave.user`** 의 `/api/v1/users/{userId}/social/friends-count`, `feedUserInfo-mapper` SQL 에서 `wadiz_membership.member` 조인이 있음 — 이 스키마가 `MemberShip-Api-Server` 의 것으로 추정

## 4. 관측 한계
- `MemberShip-Api-Server/web_application/src/main/resources/application.yml` 에서 실제 서비스 포트 확인 필요 (게이트웨이 대상 9150 매칭)
- 배치 실행 스케줄 (Kubernetes CronJob 등) 위치 불명
- `docs/src/SequenceDiagram/` 의 실제 diagram 파일 개수·내용 미확인
- User-Api-Gateway 필터 로직 (인증·헤더 변환·rate limit) 상세 미확인
