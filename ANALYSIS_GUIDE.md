# Wadiz Repo 분석 작업 가이드

> 이 문서는 `com.wadiz.api.funding` 심층 분석에서 검증된 절차를 재현 가능한 형태로 정리한 것입니다. 다른 백엔드/프론트엔드 repo에 동일한 방식으로 확장할 때 이 가이드를 따르세요.

## 원칙 (가장 중요)

**관측 가능한 것만 기록한다.**
추측하지 않는다. 외부 jar/서비스 내부 로직은 "외부"라고 명시만 하고, 이 repo 안에서 실제로 읽을 수 있는 코드·SQL·설정만 문서화한다.

- 호출 체인 도중 외부 의존성(예: `funding-core` jar, 타 서비스 HTTP 호출, UseCase 구현체)을 만나면 그 지점까지만 적고 "core 내부" / "외부 서비스" 로 표시
- MyBatis XML에 없는 SQL을 소스에서 추측해서 쓰지 말 것
- Gateway 인터페이스에 정의된 메서드만 나열하고, 그 구현이 Redis/MySQL/Mongo 중 무엇을 쓰는지는 infrastructure 모듈을 확인한 뒤에만 단언

위 원칙을 문서 상단 **기록 범위** 블록으로 항상 명시한다.

---

## 2단계 작업 모델

### Phase 1 — 얕은 개요 (1 repo = 1 파일)
repo 하나당 `docs/<repo>.md` 하나. 목표는 **"이 repo가 무엇이고 어떤 스택/역할인가"** 를 3분 안에 파악할 수 있게 만드는 것.

확인 항목:
1. `README.md`, `build.gradle(.kts)` / `pom.xml` / `package.json` — 빌드 도구, 언어, 주요 의존성
2. 최상위 디렉터리 구조 — 모노레포/멀티모듈 여부
3. `src/main/resources/application*.yml` — 포트, DB, Redis, Kafka, 외부 API endpoint
4. `@SpringBootApplication` / `main()` / `next.config.*` — 엔트리포인트
5. 패키지 prefix 관찰 — `com.wadiz.*` (레거시), `kr.wadiz.*` (인프라), `co.wadiz.*` (리라이트) 세대 구분

**출력 템플릿** — 기존 `docs/*.md` 파일 아무거나 참고 (예: `docs/makercenter-be.md`, `docs/kr.wadiz.account.md`).

Phase 1이 끝나면 루트 `CLAUDE.md` 이정표 표에 행을 추가한다.

---

### Phase 2 — 엔드포인트·모듈 심층 분석
`com.wadiz.api.funding` 에서 사용한 방식. **분량이 크면 반드시 도메인별 분할**.

출력 구조:
```
docs/<repo>/
├── <repo>.md                       # overview + 도메인 링크
├── api-endpoints.md                 # 전체 엔드포인트 전수 목록
└── api-details/
    ├── <domain-1>.md
    ├── <domain-2>.md
    └── batch.md                     # 배치 모듈이 있으면
```

---

## Phase 2 세부 절차

### Step 1. 모듈 맵 그리기
```bash
find <repo> -maxdepth 3 -type d -not -path "*/src*" -not -path "*/build*" -not -path "*/.*"
```
- 헥사고날이면 `adapter/{application,infrastructure,batch}` / `core/{domain,support}` / `bootstrap/*` 구조 확인
- 각 모듈의 역할을 overview 파일 상단에 기록

### Step 2. 엔드포인트 전수 추출
```bash
grep -rn "@\(Get\|Post\|Put\|Patch\|Delete\|Request\)Mapping" <repo>/adapter/application/src/main
```
결과를 `api-endpoints.md` 에 **도메인 카테고리별로 그룹핑**. funding의 경우 13개 카테고리(주문·결제, 펀딩참여, 캠페인, 리워드, 정산, 배송, …)로 분류.

### Step 3. 도메인별 문서 작성
`api-details/<domain>.md` 마다 동일한 포맷을 사용:

```markdown
# <도메인> 상세 스펙

> **기록 범위**: adapter/application 컨트롤러와 MyBatis XML에서 직접 관측 가능한
> 호출만 기록. UseCase 구현체는 외부 jar(`funding-core`)에 있어 내부 SQL은 확인 불가.

## 컨트롤러 인벤토리
| Controller | Base Path | Endpoint 수 | Storage |

## 엔드포인트별 상세

### <METHOD> <path>
**권한**: `@PreAuthorize(...)` / `@Impersonatable`

**Request**
| 필드 | 타입 | 필수 | 설명 |

**Response**
| 필드 | 타입 | 설명 |

**컨트롤러 코드 흐름**
1. 입력 검증 (Bean Validation)
2. `XxxGateway.method(...)` 호출
3. 결과 매핑

**관측 가능한 DB/외부호출**
- MySQL `tablename`: `<MyBatis XML에서 추출한 SQL>`
- Redis `HGETALL key`
- 외부 UseCase 호출 (core 내부)

## Gateway/Mapper 매핑 표
## 접근 테이블 요약
## Enum 참조
```

**팁**:
- Jakarta Validation 어노테이션(`@NotNull`, `@Size`, `@Pattern`)을 Request 필수 컬럼(✅/⬜)으로 반영
- SQL은 MyBatis XML에서 **복붙** (요약/의역 금지)
- `${DAMO_ENC_KEY}` 같은 암호화 함수, `IFNULL` 다국어 폴백 패턴은 그대로 보존
- `@Async` / 콜백 / `@EventListener` 는 별도로 표시

### Step 4. 배치 모듈 (있을 경우)
- `*JobConfig.java` 파일 전수 나열
- Job별: 트리거(cron/@Scheduled/외부 기동), Reader-Processor-Writer or Tasklet, 관측 가능한 Reader SQL, Writer 대상
- 외부 `@Scheduled` 스캐너: `grep -rn "@Scheduled" <repo>/adapter/application`

### Step 5. 교차 검증
- `api-endpoints.md` 의 엔드포인트 개수 = `api-details/*.md` 각 문서에 등장하는 엔드포인트 합과 일치하는지 확인
- 각 Gateway 인터페이스가 매핑 표에 모두 등장하는지

### (선택) Step 6. 인프라/도메인/부트스트랩 심화
- `adapter/infrastructure`: 테이블·Redis 키·Mongo 컬렉션·외부 API 클라이언트 전수 조사
- `core/domain`: UseCase 포트 인벤토리, 도메인 이벤트, 상태 전이, exception 계층
- `bootstrap`: SecurityConfig·Kafka/Redis/Mongo/MyBatis 설정, profile별 차이

얻는 효과는 장애 역추적, 타 서비스 연계 파악, 보안 감사, 리팩터링 경계 식별 등.

---

## 문서 스타일 규약

- **언어**: 한국어
- **첫 줄**: `# <도메인명> 상세 스펙` 같은 명확한 h1
- **기록 범위** 블록: `> **기록 범위**: …` blockquote로 문서 상단에 항상 배치
- **코드 참조**: `file_path:line_number` 형식으로 즉시 네비게이션 가능하게
- **표**: 3열 이상은 반드시 마크다운 테이블
- **외부 의존성 표기**: "UseCase 호출 (core 내부)" / "외부 서비스 호출 (XXX)" 로 경계 명시
- 추측 금지 — 모르는 건 그대로 "확인 불가" 라고 쓴다

---

## 출력 결과 관리

### 로컬
모든 문서는 `repos/docs/<repo>/` 하위. Phase 1 단일 파일은 `repos/docs/<repo>.md`.

### GitHub 푸시
이 `repos/` 디렉터리는 자체 git repo (원격: `github.com/wadiz-jooyoul-lee/repos`).

```bash
# 분석 문서가 추가된 뒤
git add docs/
git commit -m "docs: <repo> 분석 추가"
git push origin main
```

`.gitignore` 가 clone 받은 원본 repo들을 제외하므로, 새 repo를 clone 해도 `docs/` 에 분석물만 추적된다. 새 원본 repo를 clone할 때 `.gitignore` 업데이트는 불필요(`/*` 규칙으로 자동 제외).

---

## 체크리스트 (repo 1개 심층 분석 시)

- [ ] Phase 1 개요 문서(`docs/<repo>.md`) 존재 또는 생성
- [ ] 모듈 맵 파악
- [ ] `api-endpoints.md` 전수 추출 및 카테고리 분할
- [ ] 도메인별 `api-details/*.md` 작성
  - [ ] 기록 범위 블록
  - [ ] Request/Response 타입·필수·검증 어노테이션
  - [ ] 컨트롤러 코드 흐름
  - [ ] 관측 가능한 DB/외부 호출 (MyBatis XML SQL 복붙)
  - [ ] Gateway 매핑 표 / 접근 테이블 요약
- [ ] 배치 모듈이 있으면 `batch.md`
- [ ] `<repo>.md` overview 하단 참조 목록에 새 문서 연결
- [ ] 교차 검증 (엔드포인트 카운트 일치)
- [ ] git commit & push

---

## 참고

- 실제 결과물: `docs/com.wadiz.api.funding/` (17개 파일, ~15,000줄)
- 루트 이정표: [`CLAUDE.md`](./CLAUDE.md)
