# display-platform 서비스 묶음 ③ — 발송 채널 (메일·푸시·친구톡·CRM)

> 전시플랫폼(display-platform) 팀의 **발송 채널 서비스 7개**를 묶었습니다. 개별로는 작고 구조가 서로 닮아, 비교해서 보는 편이 유용합니다.
> 같은 팀 다른 묶음: [`묶음 ②`(메인 배치·위시·인박스·활동·통계)](./display-platform-services-2.md) · [`묶음 ④`(스트림 에이전트·키워드)](./display-platform-services-4-agents.md)
> 이 채널들의 **운영 화면은 [`platform-admin`](./platform-admin.md)** 입니다(메일·메시지·푸시 도메인 모듈).

> 📅 분석 기준: 2026-09-01. 각 저장소 `main` 브랜치.

---

## 한눈에 보기

| 서비스 | 저장소(`wadiz-tech/…`) | Boot | 컨트롤러/EP | 메시지 브로커 | 저장소 계층 |
|---|---|---|---|---|---|
| **mail-common-api** | `mail-common-api` | 2.7.1 | 5 / 5 | RabbitMQ | MongoDB |
| **mail-normal-api** | `mail-normal-api` | 2.7.1 | 4 / 4 | RabbitMQ | Redis(reactive) |
| **mail-fast-api** | `mail-fast-api` | 2.7.1 | 3 / 2 | RabbitMQ | — |
| **push-api** | `push-api` | **3.1.1** | 2 / 5 | RabbitMQ + **Kafka** | — |
| **friendtalk-api** | `kr.wadiz.platform.api.friendtalk` | **3.1.2** | 4 / 4 | RabbitMQ | MongoDB |
| **crm** | `kr.wadiz.platform.crm` | 2.7.3 | 4 / **18** | **Kafka** | **JPA(RDB)** |
| **notification-log-agent** | `notification-log-agent` | 2.7.1 | **0 / 0** | RabbitMQ | MongoDB + Redis(reactive) |

**공통 패턴**: 발송 계열은 전부 **RabbitMQ** 로 큐잉합니다. 반면 데이터 파이프라인 계열(→ [묶음 ④](./display-platform-services-4-agents.md))은 Kafka 를 씁니다. `push-api` 와 `crm` 만 Kafka 를 함께 씁니다.

---

## 메일 3종 — 등급별로 나뉜 발송 경로

메일이 **하나가 아니라 세 서비스**로 갈려 있습니다. 이름이 곧 성격입니다.

| | 역할(추정) | 엔드포인트 |
|---|---|---|
| **mail-common-api** | 공통 기반 — 템플릿·첨부·수신·SES 이벤트 | `TemplateController` · `AttachmentController` · `MailReceiptController` · `SesEventController` |
| **mail-normal-api** | 일반 발송 | `MailSendController`(2) · `CodeController`(`/api/v1/code`) · `CacheController`(`/api/v1/cache`) |
| **mail-fast-api** | 빠른 발송 | `MailSendControllerV2`(`/api/v2/send`) · `CodeController`(`/api/v1/code`) |

- `mail-common-api` 만 **MongoDB** 를 쓰고 템플릿·첨부·수신 이벤트를 관리합니다. 나머지 둘은 발송에만 집중합니다.
- `mail-fast-api` 는 발송 API 가 **v2 뿐**입니다(`/api/v2/send`). normal 은 v 표기 없는 경로를 씁니다.
- **AWS SES** 를 씁니다(`SesEventController` + 별도 서비스 `mail-ses-agent`). 그 밖에 `mail-toast-agent`(NHN Toast) · `mail-log-agent` 가 있으나 이번 범위 밖입니다.
- **최근 변경**: `DISPLAY-1679`(2026-08) — **메일 발송 허용 도메인에 `wadiz.io` 추가**. 도메인 전환(`wadiz.kr`→`wadiz.io`) 작업의 메일 쪽 몫입니다.

## push-api — 앱 푸시

- 컨트롤러 1개(`PushController`, EP 5). 이 묶음에서 가장 단순합니다.
- **RabbitMQ + Kafka 둘 다** 사용. Boot 3.1.1 로 메일 3종(2.7.1)보다 최신입니다.
- 짝이 되는 에이전트 `push-agent`·`push-read-api` 가 따로 있습니다(이번 범위 밖, 소스 레포 미상 포함).
- **최근 변경**: `DISPLAY-1635` — 도메인 코드 `MAKER_OPINION_REPLY` → `M_OPINION_REPLY` 로 변경. 메이커 의견 답글 알림 관련입니다.

## friendtalk-api — 카카오 친구톡

- 컨트롤러 3개: `SendController`(발송) · `TemplateController`(템플릿 2) · `ImageUploadController`(이미지 업로드).
- 알림톡(`kr.wadiz.platform.api.alimtalk`)·SMS(`…api.sms`)와 형제 구조이나, 그쪽은 이번 등록 범위에서 제외됐습니다(기본 브랜치 커밋이 2026-06-04 에 멈춘 그룹).
- **최근 변경**: 기능 변경 없이 **`RWD-5632` live 워크플로 정리**(`cdev` → `clive` 명칭 정정, `update-image-tag-cdev` 통합)뿐입니다.

## crm — CRM (Braze 연동)

- 이 묶음에서 **엔드포인트가 가장 많습니다(18개)**. `UserController` 가 13개로 대부분을 차지합니다.
- 유일하게 **JPA(RDB)** 를 씁니다. Kafka 도 사용.
- `ToastController`(NHN Toast) · `NewsletterSubscriberController`(뉴스레터 구독) 보유.
- 짝: `crm-agent`(`kr.wadiz.platform.crm-agent`) · `crm-gateway-api`(`wadiz-service/com.wadiz.crmgateway`) — 둘 다 이번 범위 밖.
- ⚠️ **기본 브랜치(`main`) 코드가 조용합니다** — 1년간 3커밋이고 전부 워크플로 정리입니다. 반면 `dev` 브랜치에는 2026-08-24 작업이 있고 clive 배포도 8/22 에 있었습니다. **개발선이 `main` 이 아닌 것으로 보입니다**(미확인).
- [`makercenter-be`](./makercenter-be.md) 의 CLIENT-216(기획전 CRM BENEFIT 회차를 Braze 커스텀 이벤트로 전환)과 같은 Braze 도메인이지만, 저장소·팀이 다릅니다.

## notification-log-agent — 발송 로그 수집

- **컨트롤러 0개**, helm `type: agent`(인바운드 라우팅 없음). 순수 백그라운드 워커입니다.
- RabbitMQ + MongoDB + reactive Redis. 패키지에 `message`·`push` repository 가 있어 **채널별 발송 로그를 모으는 역할**로 보입니다.
- **최근 변경**: `DISPLAY-1624` — **수신 미동의 발송 모니터링 오탐 수정**. 즉 "수신 동의하지 않은 사용자에게 발송됐다"는 경보가 잘못 뜨던 문제를 고쳤습니다. 이 에이전트가 **컴플라이언스 모니터링** 역할도 한다는 뜻입니다.

---

## ⚠️ 관측 — 워크플로 정리가 팀 전반에 진행 중

이 묶음 7개 중 **4개의 최신 커밋이 기능이 아니라 배포 워크플로 정리**입니다.

| 서비스 | 정리 내용 |
|---|---|
| `mail-normal-api` · `mail-common-api` | `[update_workflow_20260827]` rc4 추가 |
| `mail-common-api` · `friendtalk-api` · `crm` | `RWD-5637`·`RWD-5632`·`RWD-5627` — **live 워크플로의 `cdev` → `clive` 명칭 정정**, `update-image-tag-cdev` 통합 |

RWD-56xx 3건은 **같은 작업을 서비스별로 나눠 단 것**입니다. 클라우드 환경 명칭이 `cdev`/`clive` 로 혼용되던 것을 정리한 흔적입니다.

## 미확인 항목

- 메일 3종의 정확한 분기 기준 — "normal" 과 "fast" 를 무엇으로 나누는지(발송량·우선순위·SLA 추정, 근거 미확보).
- `crm` 의 실제 개발 브랜치 — `main` 이 조용한데 배포는 최신입니다.
- 이번 범위에서 빠진 형제 서비스들(`alimtalk-*`·`sms-*`·`mail-ses-agent`·`mail-toast-agent`·`mail-log-agent`·`push-agent`·`push-read-api`·`crm-agent`·`noti-channel`)과의 전체 발송 파이프라인 그림.
- 각 서비스의 clive 실제 운영 설정 — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/{svc}.yaml` `configmap.data` 참조.
- 테스트 코드 규모는 이번 스캔 범위 밖입니다.
