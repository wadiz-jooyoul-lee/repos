# wadiz-tech — 플랫폼팀 API·Agent 서비스군 (12 repo)

> `wadiz-tech` org 소속 12개 서비스. 대부분 **Spring Boot 3.x · Java 17 · Gradle** (일부 Boot 2.7 · Java 17). 알림·메일·푸시·위시·메트릭·메인 화면 API 등 플랫폼 인프라 API 를 담당합니다.
>
> 하나(`user-activity-api`) 는 **Boot 4.0.2** 로 이미 최신 세대.

각 repo 는 표면 분석 단계로, 진입점·컨트롤러 수·주요 도메인 위주로 기록.

## Repo 요약표 (12개)

| Repo | Boot | 컨트롤러 | 카테고리 | 역할 |
|---|---|---|---|---|
| `user-activity-api` | **4.0.2** | 4 | 사용자 활동 | 유저 활동 API (Boot 4 세대) |
| `mail-normal-api` | 2.7.1 | 4 | 알림 | 일반 메일 API |
| `mail-toast-agent` | 2.7.1 | 0 | 알림 (agent) | Toast(네이버) 메일 발송 agent |
| `push-api` | 3.1.1 | 2 | 알림 | 앱 푸시 API |
| `notification-log-agent` | 2.7.1 | 0 | 알림 (agent) | 알림 발송 로그 수집 |
| `kr.wadiz.platform.api.friendtalk` | 3.1.2 | 3 | 알림 | 카카오 친구톡 API |
| `platform-admin` | 3.0.4 | 17 | 플랫폼 어드민 | 알림·컨텐츠 등 통합 어드민 |
| `main2-api` | 3.0.4 | 6 | 메인 화면 | 메인 화면 조회 API (Ehcache 사용) |
| `main2-batch-api` | 3.1.3 | 3 | 메인 화면 | 메인 배치 트리거 API (MapStruct) |
| `main2-stream-agent` | 3.0.2 | 0 | 메인 화면 | Kafka Streams 기반 스트리밍 |
| `wish-api` | 3.3.0 | 2 | 위시 | 위시(찜) API |
| `project-metric-api` | 3.2.2 | 1 | 메트릭 | 프로젝트 메트릭 조회 |

---

## 1. 알림 도메인 (5개)

`com.wadiz.wave.audit` 의 `ApplicationName.NOTIFICATION` 항목이 이 그룹을 가리키는 것으로 추정.

### 1.1 `mail-normal-api`
- **메인**: `kr/wadiz/api/mail/MailNormalApiApplication.java`
- Boot 2.7.1 / Java 17
- 일반 메일 API — 컨트롤러 4개
- `consts/ApplicationConstant.java` 로 설정값 관리

### 1.2 `mail-toast-agent`
- **메인**: `kr/wadiz/agent/mail/toast/MailToastAgentApplication.java`
- Boot 2.7.1 / Java 17
- Toast (NHN 클라우드 이메일 SaaS) 를 통한 메일 발송 agent
- 컨트롤러 없음 — MQ 기반 소비자로 추정

### 1.3 `push-api`
- **메인**: `kr/wadiz/api/pushapi/PushApiApplication.java`
- Boot 3.1.1 / Java 17
- 앱 푸시 API — 컨트롤러 2개
- `json-simple` 사용 (레거시 JSON 라이브러리)

### 1.4 `notification-log-agent`
- **메인**: `kr/wadiz/agent/notificationlogagent/NotificationLogAgentApplication.java`
- Boot 2.7.1 / Java 17
- 알림 발송 이력 수집 agent — 컨트롤러 없음

### 1.5 `kr.wadiz.platform.api.friendtalk`
- **메인**: `kr/wadiz/platform/api/friendtalk/FriendtalkApplication.java`
- Boot 3.1.2 / Java 17
- 카카오 친구톡 API — 컨트롤러 3개

## 2. 플랫폼 어드민 (1개)

### 2.1 `platform-admin`
- **메인**: `kr/wadiz/platform/admin/PlatformAdminApplication.java`
- Boot 3.0.4 / Java 17
- **컨트롤러 17개** (본 org 최대)
- 이 org 12개 서비스의 통합 운영 화면으로 추정
- 위치 힌트: `kr/wadiz/platform/admin/collection/constant/ApplicationConst.java` — 상수 클래스

## 3. 메인 화면 (3개)

### 3.1 `main2-api`
- **메인**: `kr/wadiz/api/main2api/Main2ApiApplication.java`
- Boot 3.0.4 / Java 17
- 컨트롤러 6개
- `ehcache 3.10.1` — 인메모리 캐시
- 메인 화면 조회 API (배너·큐레이션 등)

### 3.2 `main2-batch-api`
- **메인**: `kr/wadiz/api/main2batchapi/Main2BatchApiApplication.java`
- Boot 3.1.3 / Java 17
- 컨트롤러 3개
- `mapstruct 1.5.3.Final` — DTO 매핑
- 배치 트리거 API (`main2-batch` 배치 잡과 페어)

### 3.3 `main2-stream-agent`
- **메인**: `kr/wadiz/stream/Main2StreamAgentApplication.java`
- Boot 3.0.2 / Java 17 / **Kafka Streams**
- 컨트롤러 없음, `infra/` 폴더 존재
- 메인 화면용 실시간 스트리밍 데이터 처리
- README: "spring boot 2.7, kafka streams" (Boot 버전 표기 낡음 — 실제 3.0.2)

## 4. 유저/위시/메트릭 (3개)

### 4.1 `user-activity-api`
- **메인**: `kr/wadiz/useractivity/UserActivityApiApplication.java`
- **Boot 4.0.2** / Java 17 (본 org 최신 세대)
- 컨트롤러 4개
- `co.wadiz.api.community` 와 함께 Boot 4 채택

### 4.2 `wish-api`
- **메인**: `kr/wadiz/api/wishapi/WishApiApplication.java`
- Boot 3.3.0 / Java 17
- 컨트롤러 2개
- 위시(찜) API — CDC 토픽 `user-wish-project` 의 소스 서비스일 가능성

### 4.3 `project-metric-api`
- **메인**: `kr/wadiz/api/projectmetricapi/ProjectMetricApiApplication.java`
- Boot 3.2.2 / Java 17
- 컨트롤러 1개
- 프로젝트 메트릭 조회 (통계 서브셋)

---

## 아키텍처 관점

### 패키지 컨벤션 정리
- **`kr.wadiz.api.*`** (7개): API 서버 — mail-normal, push, main2, main2-batch, wish, project-metric
- **`kr.wadiz.agent.*`** (2개): Agent (MQ 소비자·데몬) — mail-toast, notification-log
- **`kr.wadiz.platform.*`** (2개): 플랫폼 코어 — friendtalk, admin
- **`kr.wadiz.stream`** (1개): 스트림 — main2-stream
- **`kr.wadiz.useractivity`** (1개): 예외적 명명 — 신규 Boot 4 세대

### 알림 도메인 매트릭스

`com.wadiz.wave.audit.ApplicationName.NOTIFICATION` 이 통합해서 audit 대상으로 삼는 알림 계열:

```
[상위 서비스: com.wadiz.web / makercenter-be / funding 등]
        │
        │ HTTP API 호출
        ▼
[API layer]
  · push-api           — 앱 푸시
  · mail-normal-api    — 이메일
  · friendtalk         — 카카오 친구톡
        │
        │ (MQ 또는 직접 호출)
        ▼
[Agent layer]
  · mail-toast-agent          — NHN Toast 메일 발송
  · notification-log-agent    — 발송 이력 저장

[Admin]
  · platform-admin — 위 서비스들의 운영 콘솔 (17 controller)
```

### 메인 화면 처리 흐름
```
                  [main2-stream-agent]
                       (Kafka Streams)
                            │
                            ▼
[MySQL/DB] → [main2-batch-api] → [main2-api] → [Ehcache] → [FE]
                       ↑
                [main2-batch (wadiz-batch org)]
                  실제 배치 잡 실행
```

## 관측 한계
- 대부분 repo 에 README 부재 (mail-normal, push, notification, main2-* 는 이름만 있음) → 실제 스펙은 코드 직접 열람 필요
- Kafka Streams 처리 토픽 목록 미확인 (`main2-stream-agent/infra/` 재검 필요)
- `platform-admin` 17 컨트롤러의 담당 도메인 매트릭스 미작성
- `user-activity-api` 가 Boot 4 로 리라이트한 목적(성능? 새 도메인?) 미확인
- Toast 메일 인증 정보·인프라 매트릭스 (본 repo 외부)
