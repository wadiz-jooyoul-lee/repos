# wadiz-settlement — 정산 시스템 (4 repo)

> `wadiz-settlement` org 소속 4개 저장소. **레거시 정산(Douzone Comet · JEUS · Java 8)** 과 **신규 오케스트레이터(Boot 3.5 · Java 21 · RAG · Qdrant)** 가 병존하는 이관 진행 상태.

## Repo 요약표

| Repo | 유형 | Boot | Java | 특징 |
|---|---|---|---|---|
| `co.wadiz.settlement-orchestrator` | 신규 서비스 | 3.5.0 | 21+ | RAG 정산 Q&A 챗봇 + 준실시간 PG 대사. Qdrant · GCP · AWS SQS · OpenSearch |
| `co.wadiz.settlement` | 레거시 정산 monorepo | 2.3.8 | 8 | Douzone Comet 프레임워크 + JEUS 8. **16 모듈** (`douzone-comet-service-tc-*`, `douzone-comet-ui-tc-*`) |
| `douzone-comet-service-tc-stsacr-x20191` | 위 monorepo 의 개별 모듈 (분리 저장소) | (Maven) | 8 | Douzone GPD framework (`com.douzone.gpd.framework`) |
| `policy-docs` | 문서 저장소 (코드 아님) | N/A | N/A | 정산 정책·마이그레이션 스크립트·챗봇 문서 |

---

## 1. `co.wadiz.settlement-orchestrator` — 신규 오케스트레이터

### 1.1 개요 (README)
- 와디즈 정산 오케스트레이터
- **RAG 기반 정산 Q&A 챗봇** + **준실시간 PG 대사 처리 시스템**
- 사전 요구사항: Java 21+, Docker (Qdrant 벡터 DB), GCP 서비스 계정 키, AWS 자격증명 (SQS, OpenSearch)

### 1.2 스택
- Spring Boot 3.5.0
- Kotlin/Java (build.gradle.kts)
- **JIB** 3.4.5 로 Docker 이미지 빌드
- Asciidoctor JVM Convert 4.0.4 (문서 생성)

### 1.3 진입점
- `src/main/java/co/wadiz/settlement/orchestrator/SettlementOrchestratorApplication.java`

### 1.4 구조
- `src/` — 애플리케이션 코드
- `docs/` — 아키텍처 문서
- `specs/` — 스펙 정의
- `mcp-servers/` — Model Context Protocol 서버 설정 (Claude/AI 통합)
- `credentials/` — GCP 서비스 계정 키 (Git 제외 예상)

### 1.5 환경별 설정
- `application-{local,dev,rc,rc2,rc4,clive,live}.yml` — 7개 프로파일
- `bootstrap.yml`, `bootstrap-kubernetes.yml` — Spring Cloud Kubernetes 설정
- `opensearch/`, `static/`, `templates/`

### 1.6 컨트롤러·MQ
- Controller 5개
- MQ Listener 2개 (SQS 예상)

## 2. `co.wadiz.settlement` — 레거시 정산 monorepo

### 2.1 스택
- **JDK 1.8**, Maven 3.5 이하 (Jenkins 서버 3.3.9), **JEUS 8** 앱서버
- Spring Boot 2.3.8.RELEASE (Maven parent POM)
- **Douzone Comet Framework** (더존 ERP 통합용)

### 2.2 16개 모듈
서비스 계층 (`douzone-comet-service-tc-*-x20191`):
- `stacbl` (STACBL), `staccr` (STACCR), `stacsu` (STACSU), `stbasu` (STBASU), `stsacr` (STSACR)
- `common`, `customcodehelp`

UI 계층 (`douzone-comet-ui-tc-*-x20191`):
- 위와 같은 5개 도메인 UI (DEWS HTML)
- `customcodehelp` UI

앱서버·기타:
- `douzone-comet-webapp-boot` — Spring Boot 부트스트랩
- `douzone/` — Douzone 프레임워크 확장
- `scripts/` — 배포 스크립트

### 2.3 명명 규칙
`stsacr`, `stacbl` 등은 더존 ERP 의 표준 계정과목 코드 (`sacr` = 미수금, `acbl` = 미지급금 등 회계 도메인). Wadiz 정산이 더존 ERP 를 백엔드로 사용하는 구조.

### 2.4 빌드
```bash
mvn clean install -U -DskipTests -s ./.mvn/local-settings.xml
```

## 3. `douzone-comet-service-tc-stsacr-x20191` — 개별 모듈 (분리 저장소)

이 저장소는 위 monorepo (`co.wadiz.settlement/douzone-comet-service-tc-stsacr-x20191/`) 와 **동일 이름 · 별도 저장소**로 존재.

- 스택: Java 8, Maven, `com.douzone.gpd.framework/douzone-gpd-core` 의존
- 관측 한계: monorepo 판 vs 분리 저장소 판이 어떻게 동기화되는지 불명 (release 시 분리 push? sync repo?)

## 4. `policy-docs` — 정산 정책·마이그레이션 문서

코드가 아닌 **문서 전용 저장소**. 최상위 폴더:

| 폴더 | 내용 |
|---|---|
| `diagrams/` | 시퀀스·플로우 다이어그램 |
| `indemend-funding/` | 재청구 펀딩 관련 문서 |
| `issue/` | 이슈 기록 |
| `migration/` | 이관 계획·스크립트 |
| `scripts/` | 운영 스크립트 |
| `settlement-bot/` | 정산 챗봇 (orchestrator 의 RAG 문서 소스로 추정) |
| `stripe-pg-scripts/` | Stripe PG 관련 스크립트 |

→ `settlement-orchestrator` 의 RAG 벡터 DB (Qdrant) 는 이 저장소의 문서를 임베딩할 가능성이 큼.

---

## 아키텍처 관점

### 이관 상태 (레거시 → 신규)

```
[레거시 (JEUS 8 · Java 8 · Douzone ERP)]
      co.wadiz.settlement (16 모듈)
      · Douzone Comet Framework
      · Maven monorepo
      · JEUS 앱서버
      · DEWS HTML UI
             │
             │ 부분 이관
             ▼
[신규 (Boot 3.5 · Java 21)]
      co.wadiz.settlement-orchestrator
      · RAG 챗봇 (Qdrant 벡터 DB)
      · 준실시간 PG 대사 (SQS + OpenSearch)
      · Spring Cloud Kubernetes
      · JIB Docker
             │
             │ 문서 소스
             ▼
      policy-docs (settlement-bot/ 하위 문서 → RAG 벡터화)
```

### 관측 가능한 통합 지점

- **Stripe PG**: `policy-docs/stripe-pg-scripts/` — `co.wadiz.fep`(결제 대외계) 및 `nicepay-api` 와 연결 가능성
- **재청구 (Indemand)**: `policy-docs/indemend-funding/` + `com.wadiz.batch.payment.PaymentIndemandJobConfig` 연동 추정
- **OpenSearch**: orchestrator 가 사용 — `com.wadiz.wave.searcher` (ES 7.x) 와는 별개 인스턴스 가능성

### 관측 한계

- Douzone ERP 실체 (외부 시스템) 는 본 repo 밖
- Qdrant 벡터 DB 인덱스 스키마·임베딩 파이프라인 상세 미확인
- `douzone-comet-service-tc-stsacr-x20191` 분리 저장소의 동기화 방식 (submodule? sync bot?) 불명
- Jenkins Maven 서버 (3.3.9) 는 인프라 팀 소유
