# ai-project-audit — AI 콘텐츠 검수 서비스

> `wadiz-ai` org 소속. 펀딩 프로젝트의 텍스트·이미지 콘텐츠를 자동 검수하는 FastAPI 기반 Python 서비스. 키워드 정책(Elasticsearch) + AI 문맥 정책(OpenAI) + OCR(Google Cloud Vision) 을 결합해 정책 위반을 탐지하고, 위반 영역을 이미지 bbox 마킹 후 S3 에 업로드합니다.
>
> 기존 `docs/CLAUDE.md` 및 flow 문서들에서 "AI Review" 로 언급되던 서비스의 실체입니다.

- Clone URL: `git@github.com:wadiz-ai/ai-project-audit.git`
- 로컬 경로: `/Users/casvallee/work/repos/ai-project-audit/`
- 관리 org: `wadiz-ai`
- 언어·프레임워크: **Python 3.11+ / FastAPI / Poetry / DDD (헥사고날 유사)**

---

## 1. 아키텍처 레이어

```
src/
├── api/web/                # FastAPI 라우터·요청/응답 모델·백그라운드 태스크
├── application/            # 검수·로깅 유스케이스, Job 엔티티
├── domain/                 # 정책·콘텐츠·아이템 모델, 서비스 인터페이스
│   ├── model/{policy,content,project,types,item/{text,image}}
│   ├── repository/{audit,policy,image_content,image,prompt}
│   └── service/{audit,policy,converter}
├── infrastructure/         # 어댑터: ES(정책) / OpenAI(문맥) / GCV(OCR) / S3
│   └── repository/{es_policy, inmemory_policy, openai_audit, ocr_image_content, s3_image, s3_log, prompt/*}
├── container.py            # dependency-injector DI 컨테이너
├── settings.py             # pydantic-settings 환경 설정
└── main.py                 # 진입점 (Google credential JSON 로드 검증 포함)
```

DDD 스타일: domain 이 인터페이스(`repository/`)를 정의하고 infrastructure 가 실체 구현.

## 2. API 엔드포인트

파일: `src/api/web/routers.py`, `app.py`

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/` | 루트 |
| GET | `/health` | 헬스체크 |
| POST | `/genai/v2/maker/content-review` (kr) | **백그라운드 검수** → 콜백 URL 로 결과 전송 |
| POST | `/genai/v3/maker/content-review` (io) | 동일 핸들러, ALB path 로 kr/io ECS 분기 |
| POST | `/genai/v2/maker/content-review/direct` (kr) | 즉시 검수 결과 반환 (테스트용) |
| POST | `/genai/v3/maker/content-review/direct` (io) | 동일 핸들러 io 버전 |

Swagger UI: `/genai/v2/maker/content-review/docs`  ·  ReDoc: `/genai/v2/maker/content-review/docs/redoc`

## 3. 검수 프로세스 (요약)

1. **콘텐츠 변환** — `TextItem` → `TextContent`, `ImageItem` → `ImageContent` (GCV OCR 로 이미지 내 텍스트 추출)
2. **정책 로드** — ES 에서 카테고리·언어별 키워드 정책 + 로컬 파일에서 문맥 정책
3. **검수 수행**
   - 키워드 검수: 정책 패턴 ↔ 콘텐츠 매칭
   - 문맥 검수: OpenAI API 로 AI 분석 (2 pool 병렬 처리, 중복 위반 제거)
4. **위반 처리** — 콘텐츠별 결과 병합, ImageContent 는 bbox 마킹 후 S3 업로드
5. **응답** — 비동기: 백그라운드 처리 후 콜백 URL POST / 동기: 즉시 반환
6. **이벤트 로깅** — 요청·응답·에러를 S3 에 JSON 저장

## 4. 정책 모델

```python
class PolicyLevel(StrEnum):
    GOOD = "GOOD"      # 사용 가능
    WARNING = "WARNING"# 조건부 (담당자 알림)
    BAD = "BAD"        # 사용 불가

class Violation(BaseModel):
    text: str          # 실제 위반 표현
    description: str   # 안내 메시지

class Policy(BaseModel):
    target_pattern: str
    alert_message: Violation | None = None
    level: PolicyLevel
```

정책 종류 두 가지:

| 종류 | 저장소 | 특징 |
|---|---|---|
| 키워드 정책 | Elasticsearch (`keyword_policies_{lang}_v2.1_{yyyymmdd}`) | 정확 매칭, 언어별 인덱스 (ko/en/ja/zh) |
| 문맥 정책 | 로컬 JSON (`data/policies.json`) | OpenAI 기반 문맥 분석, 카테고리별 |

## 5. 정책 갱신 워크플로우

### 5.1 문맥 정책
```
policy_data_raw/category_policy/*.json
   ↓ python policy_data_raw/generate_policies.py
policy_data_raw/output/{yyyymmdd}/policies.json
   ↓ (검토 후 수동 복사)
data/policies.json
   ↓ (앱 재시작)
운영 반영
```

카테고리 매핑 (`generate_policies.py`):
- beauty → 뷰티, 화장품/미용
- food → 푸드, 식품
- tech → 테크가전
- home_living → 패션·잡화, 패션잡화, 홈리빙패션잡화
- class_consulting → 도서(전자책), 클래스컨설팅

### 5.2 키워드 정책
```
Google Sheets 원본 (신뢰안전팀 관리)
   ↓ CSV 다운로드
policy_data_raw/keyword_policy_indexing/sheet_data/*.csv
   ↓ python indexing_keyword_policy.py --target_file ... --index_name_prefix ...
policy_data_raw/keyword_policy_indexing/es_document/*.csv (백업)
   ↓ Elasticsearch bulk index (신규 인덱스 생성, 기존 유지)
Elasticsearch keyword_policies_{lang}_v2.1_{yyyymmdd}
   ↓ .env 의 INDEX_PREFIX 변경 + 재배포
운영 반영
```

Google Sheets 링크: `https://docs.google.com/spreadsheets/d/17njWltBXrnuprGQoWDW7-jzj9f23x4mbdu65wyBgFwU/edit`

### 5.3 Claude Code Skill `/policy-update DP-XXXX`

repo 자체가 `.claude/skills/policy-update` 를 포함해 정책 업데이트 Jira 티켓 처리를 자동화합니다.

- 티켓 조회 → BAD/WARNING/GOOD 분류 확인
- `policy_data_raw/v3_source/DP-XXXX_*.md` 감사 아티팩트 생성
- `data/policies.json` 공통(depth1="공통") 항목 전체 교체
- `pytest tests/ -k "policy or audit"` 실행
- 커밋 (`DP-XXXX 문맥검수 정책 vN 전체 교체 — ...`)

## 6. 배포 (DP-4573 kr/io 도메인 분리)

**동일 이미지 · 두 컨테이너 · ALB path 분기** 원칙. 코드에 kr/io 분기 없음, env 만 다름.

- kr Target Group ← `POST /genai/v2/maker/content-review*`
- io Target Group ← `POST /genai/v3/maker/content-review*`

### 환경별 CDN·콜백 매트릭스
| env 항목 | kr (v2) | io (v3) |
|---|---|---|
| `INFRA__S3__CDN_BASE_URL` | live=`https://cdnai.wadiz.kr` / dev·rc=미설정 | live=`https://cdn-aidata.wadiz.io` |
| `INFRA__CDN__RETRY_HOSTS` | `cdn/cdn1~4/cdnai.wadiz.kr` | `cdn-funding/business/store/funding-public/display, ai-cdn .wadiz.io` |
| `INFRA__CDN__RETRY_TRIGGER_HOSTS` | `www.wadiz.kr, ai-cdn.wadiz.kr` | `www.wadiz.io, www.clive.wadiz.io, ai-cdn.wadiz.io` |
| `CALLBACK__LIVE` | `https://gateway.wadiz.kr/funding/api/internal/story/response` (기본) | `api.wadiz.io` 계열 |

Task 정의 파일: `.aws/ai_project_audit_task_{dev,rc,live,dev_io,rc_io,live_io}.json`
상세 문서: `docs/specs/DP-4573-domain-migration.md`, `docs/specs/DP-4573-deploy-env-sample.md`

### ECR & ECS
| 환경 | Cluster | Service | ECR |
|---|---|---|---|
| dev | `dev-aidata-wadiz-kr-cluster` | `ai_project_audit_service_dev` | `811660421358.dkr.ecr.ap-northeast-2.amazonaws.com/ai/ai-project-audit-dev` |
| live | `aidata-wadiz-kr-cluster` | `ai_project_audit_service_live` | `210738424164.dkr.ecr.ap-northeast-2.amazonaws.com/ai/ai-project-audit-live` |

플랫폼: `linux/amd64`, uvicorn workers 2개.

## 7. 인프라 리소스

| 리소스 | 용도 | 위치 |
|---|---|---|
| Elasticsearch | 키워드 정책 저장 | `dev-search.es.ap-northeast-2.aws.elastic-cloud.com:443` |
| S3 (CDN) — dev/rc | 마킹 이미지 | `wadiz-ai-cdn` |
| S3 (CDN) — live | 마킹 이미지 | `wadiz-ai-cdn-live` |
| S3 (로그) — dev/rc | 요청/응답 JSON | `wadiz-ai-story-service` |
| S3 (로그) — live | 요청/응답 JSON | `wadiz-ai-story-service-live` |
| Google Cloud Vision | 이미지 OCR | credentials via `/app/google/credentials.json` |
| OpenAI | 문맥 검수 | API key 환경변수 |
| Region | 전체 | `ap-northeast-2` (서울) |

## 8. 콜백 → funding 도메인

기본 콜백 URL: `https://gateway.wadiz.kr/funding/api/internal/story/response/{project_id}` (kr) / `api[.env].wadiz.io/...` (io).

- 이는 `com.wadiz.api.funding` (`/api/internal/story/response`) 의 콜백 엔드포인트로 이어짐
- `docs/_concepts/kafka-cdc-and-user-link.md` 6장 통신 방식 표에서 "Internal Callback (`/api/internal/...`)" 로 언급된 그 패턴의 실제 사례

## 9. 기술 스택

- **Web**: FastAPI 0.116+, uvicorn 0.35+
- **DI**: dependency-injector 4.48+
- **Validation**: pydantic 2.11+, pydantic-settings 2.10+
- **Serialization**: msgspec 0.19+ (성능)
- **Logging**: loguru 0.7+
- **HTTP**: aiohttp 3.12+ (비동기 요청)
- **AI**: openai 1.108+, google-cloud-vision 3.10+
- **Storage**: elasticsearch 8.x, boto3 1.40+ + mypy-boto3-s3
- **Image**: imagehash 4.3+ (dedup)
- **Test/Lint**: pytest, pytest-asyncio, ruff, mypy(strict), pylint

## 10. 관측 한계

- 실제 프롬프트 텍스트(`infrastructure/repository/prompt/*`) 는 별도 분석 필요
- Elasticsearch 인덱스의 실제 문서 수·매핑은 운영 환경 접속 필요
- `main.py` 의 Google credentials 파일 읽기 검증 로직은 배포 시 자동 검증되며, 로컬 개발은 별도 credential 파일 요구
- OpenAI API 비용은 정책 개수·콘텐츠 크기에 비례 (2 pool 병렬 처리로 조정)

## 11. 다른 문서와의 연결

- 이 서비스가 호출하는 콜백 대상: [`docs/com.wadiz.api.funding/`](./com.wadiz.api.funding/) (`/api/internal/story/response`)
- 통신 패턴 개요: [`docs/_concepts/kafka-cdc-and-user-link.md`](./_concepts/kafka-cdc-and-user-link.md) 6장 (Internal Callback)
- 펀딩 프로젝트 개설 플로우에서 AI Review 호출 지점: [`docs/_flows/funding-create.md`](./_flows/funding-create.md)
