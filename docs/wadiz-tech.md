# wadiz-tech — 플랫폼팀 API·Agent 서비스군 (42 repo)

> `wadiz-tech` org 소속 42개 서비스. 대부분 **Spring Boot 3.x · Java 17 · Gradle** (일부 Boot 2.5~2.7, 일부 Go/Python/Node). 알림·메일·푸시·SMS·알림톡·위시·검색·파일·CRM 등 플랫폼 전반의 API·Agent 를 커버합니다.
>
> 특이 지점:
> - `user-activity-api` — **Boot 4.0.2** 신규 세대
> - `push-postpone` — **Go**
> - `main2-stream-scheduler` — **Go** (Kafka Streams 스케줄러)
> - `ses-event-subscriber`, `kafka-connect-admin`, `semantic-search-api` — **Python**
> - `semantic-search-fe` — **Node/React**

## 카테고리 요약

| 카테고리 | Repo 수 | 대표 |
|---|---:|---|
| [1. 알림 채널·메일 (7)](#1-알림--메일-도메인-7) | 7 | mail-{normal,common,fast,ses,log}-*, noti-channel, mail-toast-agent |
| [2. 알림 채널·푸시 (4)](#2-푸시-도메인-4) | 4 | push-api, push-read-api, push-agent, push-postpone (Go) |
| [3. 알림 채널·SMS/알림톡/친구톡 (8)](#3-sms--알림톡--친구톡-도메인-8) | 8 | api.sms(+.ad), agent.sms(+.ad), api.alimtalk, agent.alimtalk, api.friendtalk, agent.friendtalk |
| [4. 알림 인프라·인박스·CRM (6)](#4-알림-인프라-인박스-crm-6) | 6 | inbox-agent, kr.wadiz.platform.inbox, notification-log-agent, ses-event-subscriber (Python), platform.crm(+agent) |
| [5. 플랫폼 코어 API·Agent (4)](#5-플랫폼-코어-api-agent-4) | 4 | platform.file, display-agent, collection-api, share-api |
| [6. 검색 (3)](#6-검색-3) | 3 | keyword, keyword-agent, semantic-search-{api(Python), fe(Node)} |
| [7. 어드민·인프라 (2)](#7-어드민-인프라-2) | 2 | platform-admin, kafka-connect-admin (Python) |
| [8. 메인 화면 (4)](#8-메인-화면-도메인-4) | 4 | main2-api, main2-batch-api, main2-stream-agent, main2-stream-scheduler (Go) |
| [9. 유저·위시·메트릭 (3)](#9-유저위시메트릭-3) | 3 | user-activity-api (Boot 4), wish-api, project-metric-api |
| [10. Semantic 별도 (1)](#10-semantic-검색-1) | 1 | semantic-search-api (Python) |

**총 42 repo** (알림 계열 25, 검색 관련 4, 플랫폼 코어 4, 어드민 2, 메인 4, 유저·위시 3)

---

## 1. 알림 — 메일 도메인 (7)

`ApplicationName.NOTIFICATION` 산하 이메일 계열. 발송 채널별로 agent 분리.

| Repo | Boot | 컨트롤러 | 역할 |
|---|---|---:|---|
| `mail-normal-api` | 2.7.1 | 4 | 일반 메일 API |
| `mail-fast-api` | 2.7.1 | 3 | 빠른 발송 메일 API (트랜잭션형) |
| `mail-common-api` | 2.7.1 | 4 | 공용 메일 API (공통 로직 통합) |
| `mail-ses-agent` | 2.7.1 | 0 | **AWS SES** 발송 agent |
| `mail-toast-agent` | 2.7.1 | 0 | **NHN Toast** 발송 agent |
| `mail-log-agent` | 2.7.1 | 0 | 메일 발송 로그 수집 |
| `noti-channel` | 2.7.1 | 7 | 알림 채널 관리 (수신 채널 · 사용자별 구독) |

**메일 발송 파이프라인**:
```
API layer  ─────────────────────►  Agent layer
   ├─ mail-normal-api                ├─ mail-ses-agent (AWS)
   ├─ mail-fast-api                  ├─ mail-toast-agent (NHN)
   └─ mail-common-api                └─ mail-log-agent (로깅)
           ▲
           │
    [ses-event-subscriber (Python)] — AWS SES 이벤트 수신 (bounce, complaint 등)
```

## 2. 푸시 도메인 (4)

| Repo | 언어 | Boot | 컨트롤러 | 역할 |
|---|---|---|---:|---|
| `push-api` | Java 17 | 3.1.1 | 2 | 앱 푸시 발송 API |
| `push-read-api` | Java 17 | 2.7.1 | 3 | 푸시 읽음/미읽음 조회 (별도 서비스 분리) |
| `push-agent` | Java 17 | 2.5.6 | 1 | 푸시 발송 agent (FCM/APNs 실체 전송) |
| `push-postpone` | **Go** | (Go 1.x) | — | 푸시 지연 발송 스케줄러 (Go 로 별도 구현) |

## 3. SMS · 알림톡 · 친구톡 도메인 (8)

카카오 알림톡·친구톡·SMS 각각 **API + Agent 페어** 구조. **광고성 SMS 는 별도 페어** (심의·발송 규정 다름).

| Repo | Boot | 컨트롤러 | 유형 |
|---|---|---:|---|
| `kr.wadiz.platform.api.sms` | 3.1.2 | 4 | 일반 SMS API |
| `kr.wadiz.platform.agent.sms` | 3.1.2 | 0 | 일반 SMS 발송 agent |
| `kr.wadiz.platform.api.sms.ad` | 3.1.1 | 2 | **광고성** SMS API (별도 심의·수신동의 관리) |
| `kr.wadiz.platform.agent.sms.ad` | 3.0.2 | 0 | 광고성 SMS 발송 agent |
| `kr.wadiz.platform.api.alimtalk` | 3.1.2 | 2 | 카카오 알림톡 API |
| `kr.wadiz.platform.agent.alimtalk` | 3.1.2 | 0 | 카카오 알림톡 발송 agent |
| `kr.wadiz.platform.api.friendtalk` | 3.1.2 | 3 | 카카오 친구톡 API |
| `kr.wadiz.platform.agent.friendtalk` | 3.1.5 | 0 | 카카오 친구톡 발송 agent |

카카오 알림톡 vs 친구톡: 알림톡=트랜잭션(주문·배송), 친구톡=마케팅(수신동의 필요).

## 4. 알림 인프라 · 인박스 · CRM (6)

| Repo | 언어 | Boot | 역할 |
|---|---|---|---|
| `notification-log-agent` | Java 17 | 2.7.1 | 알림 발송 이력 수집 (통합 로그) |
| `inbox-agent` | Java 17 | 3.0.2 | 인박스 큐/이벤트 처리 agent |
| `kr.wadiz.platform.inbox` | Java 17 | 2.7.3 | 인박스 조회 API (3 controller) — 사용자별 알림함 |
| `ses-event-subscriber` | **Python** | — | AWS SES 이벤트(bounce/complaint) 구독 후 처리 |
| `kr.wadiz.platform.crm` | Java 17 | 2.7.3 | CRM 도메인 API (3 controller) — Braze 등 CRM 툴 통합 지점 |
| `kr.wadiz.platform.crm-agent` | Java 17 | 2.7.12 | CRM 이벤트 발송 agent |

## 5. 플랫폼 코어 API·Agent (4)

| Repo | Boot | 컨트롤러 | 역할 |
|---|---|---:|---|
| `kr.wadiz.platform.file` | 3.1.5 | 6 | 파일 업로드·다운로드·CDN 관리 API |
| `display-agent` | 3.3.1 | 0 (Kafka Streams 2) | 디스플레이(노출) 데이터 처리 agent |
| `collection-api` | 3.2.2 | 2 | 컬렉션(모음) 관리 |
| `share-api` | 3.1.7 | 2 | 공유(공유 링크·SNS) API |

## 6. 검색 (3)

| Repo | 언어 | Boot | 컨트롤러 | 특이 |
|---|---|---|---:|---|
| `keyword` | Java 17 | 3.0.2 | 3 | 키워드 관리 API |
| `keyword-agent` | Java 17 | 3.0.2 | 0 (Kafka listener 1) | 키워드 이벤트 처리 agent |
| `semantic-search-fe` | Node/React | — | — | 시맨틱 검색 프론트 (자연어 검색 채팅 UI, "Watcher Front") |

## 7. 어드민·인프라 (2)

| Repo | 언어 | 역할 |
|---|---|---|
| `platform-admin` | Java 17 / Boot 3.0.4 | 위 wadiz-tech 서비스들의 통합 운영 콘솔 (17 controller) |
| `kafka-connect-admin` | **Python** | Kafka Connect 커넥터 관리 어드민 (auto_failover.py + github_adaptor.py). `wa-infrastructure/cdc` 의 커넥터 설정과 연동 추정 |

## 8. 메인 화면 도메인 (4)

| Repo | 언어 | Boot | 역할 |
|---|---|---|---|
| `main2-api` | Java 17 | 3.0.4 | 메인 화면 조회 API (Ehcache 3.10.1) |
| `main2-batch-api` | Java 17 | 3.1.3 | 배치 트리거 API (MapStruct 1.5.3) |
| `main2-stream-agent` | Java 17 | 3.0.2 | Kafka Streams 스트리밍 처리 |
| `main2-stream-scheduler` | **Go 1.21** | — | Kafka Streams 스케줄러 (avro 스키마 지원) |

## 9. 유저·위시·메트릭 (3)

| Repo | Boot | 컨트롤러 | 특이 |
|---|---|---:|---|
| `user-activity-api` | **4.0.2** | 4 | Boot 4 세대 (본 org 최신) |
| `wish-api` | 3.3.0 | 2 | 위시(찜) API. CDC 토픽 `user-wish-project` 의 소스 서비스로 추정 |
| `project-metric-api` | 3.2.2 | 1 | 프로젝트 메트릭 조회 |

## 10. Semantic 검색 (1)

| Repo | 언어 | 역할 |
|---|---|---|
| `semantic-search-api` | **Python** (FastAPI 추정) | 자연어(임베딩) 기반 시맨틱 검색 API. `semantic-search-fe` (React 채팅 UI) 의 백엔드 |

`co.wadiz.settlement-orchestrator` 의 RAG 접근과 유사한 벡터 검색 아키텍처로 추정 (별도 확인 필요).

---

## 아키텍처 관점

### 패키지 컨벤션
- **`kr.wadiz.api.*`**: API 서버 (mail-normal/fast/common, push, main2, main2-batch, wish, project-metric, collection, share, keyword)
- **`kr.wadiz.agent.*`**: MQ Consumer 데몬 (mail-toast, mail-ses, mail-log, notification-log, inbox, push, keyword-agent)
- **`kr.wadiz.platform.api.*`**: 플랫폼 API (sms, sms.ad, alimtalk, friendtalk, file)
- **`kr.wadiz.platform.agent.*`**: 플랫폼 Agent (sms, sms.ad, alimtalk)
- **`kr.wadiz.platform.*`**: 코어 (crm, admin)
- **`kr.wadiz.stream`**: 스트림 (main2-stream-agent)
- **`kr.wadiz.useractivity`**: 예외 명명 (신규 Boot 4)
- **Go**: push-postpone, main2-stream-scheduler
- **Python**: ses-event-subscriber, kafka-connect-admin, semantic-search-api
- **Node/React**: semantic-search-fe

### API-Agent 페어 패턴
플랫폼 알림 계열은 **API 서버(수신) + Agent(실제 발송)** 페어 구조.

```
[상위 서비스: com.wadiz.web / makercenter-be / funding 등]
        │
        │ HTTP
        ▼
[API layer — kr.wadiz.api.* / kr.wadiz.platform.api.*]
   · push-api, push-read-api
   · mail-normal-api, mail-fast-api, mail-common-api
   · sms(+ad)-api, alimtalk-api, friendtalk-api
   · noti-channel, kr.wadiz.platform.file
        │
        │ MQ (RabbitMQ / Kafka)
        ▼
[Agent layer — kr.wadiz.agent.* / kr.wadiz.platform.agent.*]
   · push-agent (FCM/APNs)
   · mail-ses-agent (AWS SES) / mail-toast-agent (NHN Toast)
   · sms(+ad)-agent (통신사 게이트웨이)
   · alimtalk-agent (카카오)
   · mail-log-agent, notification-log-agent, inbox-agent (로깅)

[Admin]
   · platform-admin (17 controller) — 통합 운영 콘솔
   · kafka-connect-admin (Python, wa-infrastructure/cdc 커넥터 관리)
```

### 광고성 vs 트랜잭션
SMS 는 `sms` (트랜잭션) 와 `sms.ad` (광고) 로 분리. 수신동의·심의 규정이 다르기 때문.
카카오 채널도 유사: `alimtalk` (트랜잭션) vs `friendtalk` (마케팅).

### 다른 시스템과의 연결
- `com.wadiz.wave.audit.ApplicationName.NOTIFICATION` ← 알림 계열 22개 서비스가 여기서 audit 수집됨
- `kafka-connect-admin` ↔ `wa-infrastructure/cdc` (Debezium 커넥터 REST API 관리)
- `main2-stream-agent` + `main2-stream-scheduler` (Go) ↔ Kafka Streams 파이프라인
- `wish-api` ↔ CDC 토픽 `user-wish-project` (source)
- `semantic-search-api` ↔ `co.wadiz.settlement-orchestrator` 의 벡터 검색과 유사 (별도 인스턴스 추정)

## 관측 한계
- 대다수 README 부재 (mail-*, push-*, sms-*, alimtalk-* 은 이름만) → 실제 스펙은 코드 직접 열람 필요
- `platform-admin` 17 컨트롤러의 담당 도메인 매트릭스 미작성
- `noti-channel` 7 컨트롤러의 실제 채널 정의 미확인
- `semantic-search-api` 의 벡터 DB (Qdrant? Pinecone? OpenSearch k-NN?) 미확인
- `kafka-connect-admin` 이 `wa-infrastructure/cdc` 저장소의 커넥터 파일을 어떻게 GitHub 로부터 가져오는지 (github_adaptor.py) 상세 미확인
- `push-postpone` (Go) 의 실제 스케줄링 로직 (delay 큐? cron? persistent job store?) 미확인
