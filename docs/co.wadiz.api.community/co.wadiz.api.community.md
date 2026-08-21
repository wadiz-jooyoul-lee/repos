# co.wadiz.api.community

> 📅 **2026-08-21 master pull 보강** (18 커밋)
>
> 직전 갱신(2026-07-31) 이후 변경은 **QMT(2차 콘텐츠 심사) 파이프라인 신설(RWD-5823)** 과 **어드민 '실시간 콘텐츠 검사' 조회 API 신설(RWD-5823·RWD-5879)** 이 핵심이다. 신규 REST 컨트롤러 1개(`RealtimeContentAdminController`, endpoint 3) + 기존 `SupporterSignatureAdminController` 에 endpoint 1개 추가.
>
> ### RWD-5823 — QMT(콘텐츠 심사) 트리거·발행·결과 저장
> - 1차 프로파일링 결과의 메타 점수로 2차 심사(QMT) 후보를 거르는 파이프라인 신설. 신규 `config/properties/QmtProperties.java`(record) — 트리거는 **OR 조건**(`sentiment <= maxSentiment` OR `toxicity >= minToxicity` OR `riskScore >= minRiskScore`)이고 운영값 단일 출처는 `application.yml` 의 `qmt.trigger.*`(3축 모두 **0.5**). 클래스 상수 `DEFAULT_THRESHOLD`(0.5)는 yml 키 누락 시에만 쓰는 방어 기본값이라 운영값과 별개다.
> - 감정(sentiment) 임계는 0.5 → 0.60 으로 올렸다가 rc 피드백으로 **0.5 로 원복**(2026-08-11)했다.
> - 신규 Kafka 배선: `QmtRequestProducer`(요청 발행) · `QmtResultConsumer`(결과 수신) · `QmtScreenDispatcher`(발화 판정·디스패치), 결과 저장 매퍼 `mapper/content_profiler/QmtScreenMapper.xml`, DTO `dto/QmtRequest.java`·`dto/QmtResult.java`, 심각도 enum `model/constant/CmtSeverity.java`. 발행 on/off 는 `middleware.kafka.qmt-publish-enabled` 이며 **live 를 `true` 로 활성**했다(`application-live.yml`).
> - 위협탐지 웹훅을 신뢰안전팀 채널로 교체(live). 프로파일 테이블에 `is_maker` 컬럼 추가 및 reuse(재사용) 판정을 sha·화자·promptVersion 조합으로 강화. 새소식 댓글의 `campaignId` 해석을 단건에서 **bulk 2-hop** 으로 바꿔 단건↔bulk 결과 불일치를 해소하고, 캠페인 단위 조회에 새소식 댓글을 편입했다.
>
> ### RWD-5823 / RWD-5879 — 어드민 '실시간 콘텐츠 검사' 조회 API 신설
> - **신규 컨트롤러 `module/content_profiler/admin/controller/RealtimeContentAdminController.java:62`** — base `/api/v3/admin/realtime-content`, endpoint 3개.
>   - `GET /findings` — 실시간 콘텐츠 검사 목록·판정 집계(KST 하루 단위) (`:77`)
>   - `GET /campaigns/{campaignId}/findings` — 프로젝트 단위·전체 기간 목록·판정 집계 (`:117`, RWD-5879)
>   - `GET /thread-verdicts` — 스레드 항목 판정·점수 조회 (`:279`, RWD-5879)
> - 조회 계층 신설: `admin/service/`(`RealtimeContentAdminService`·`RealtimeContentReader`·`RealtimeContentQuery`·`RealtimeContentCampaignQuery`·`RealtimeContentPage`·`RealtimeContentLookups`), `admin/repository/`(`RealtimeContentMapper` + `mapper/content_profiler/RealtimeContentMapper.xml` 497줄, `RealtimeContentFilter`·`RealtimeContentRow`·`RealtimeThreadVerdictRow`·`RealtimeVerdictCount`), 응답 DTO 3종·`RealtimeSourceType`·`RealtimeVerdict`. 판정 규칙 SQL 을 XML 한 곳으로 단일 출처화하고 조회는 Replica 로 라우팅한다.
> - **`SupporterSignatureAdminController` 에 `GET /comments/{commentId}` 추가**(RWD-5879) — 답글 번호만 아는 호출자가 부모 서명을 되짚을 수 있도록 하는 답글 단건 조회. 삭제된 답글도 돌려주고(조사 경로가 삭제 답글에서 시작될 수 있음), 없는 번호는 200 + 빈 본문이 아니라 **404** 로 답한다.
>
> ### RWD-5879 — 1:1 문의 본문 숫자 마스킹 + 모니터링 MCP 2차 심사(CMT) 노출
> - **신규 `shared/util/BodyMasker.java`** — 콘텐츠 타입 이름이 `PERSONAL_MESSAGE` 로 시작할 때만(즉 1:1 문의) 본문의 **모든 숫자**(반각·전각 유니코드 십진 숫자)를 `*` 로 치환한다. 전화·계좌 패턴을 쫓지 않는 이유는 구분자로 쪼개 적으면 패턴이 뚫리기 때문이고, 공개 콘텐츠는 오탐 분석 재현을 위해 원문을 유지한다.
>   - **적용 지점(sink)**: 위협 탐지 Slack 알림(신규·reuse) · 룰 차단 Slack 알림 · 도배 정리 Slack 알림 · `content-rule-audit` 감사 로그 · 모니터링 MCP 의 본문 3도구와 `cmt.reason`.
>   - **의도적 제외**: `content_rule_block_log` DB 적재(ML 라벨·오탐 분석 소스), 어드민 실시간 콘텐츠 조회 응답의 `body`·`qmt.reason`(본문 판독이 기능 자체). `QmtResultConsumer` 로그는 마스킹 대신 `reason` 을 아예 찍지 않는다.
> - 모니터링 MCP(`mcp/ProfileMonitoringTools`)에 2차 심사(CMT) 결과를 노출하도록 확장.
>
> ### RWD-5885 — rc4 배포 워크플로 master 반영
> - rc4 환경 배포 워크플로를 master 브랜치에도 반영(코드 변경 아님).
>
> ---
>
> 📅 **2026-07-31 pull 보강** (9 커밋)
>
> 직전 갱신(2026-07-21) 이후 변경은 전부 **content-profiler(RWD-5818) 내부 보강**과 **모니터링 MCP 확장(RWD-5841)** 이다. 신규 `@RestController`·REST endpoint 는 없다(총 13 컨트롤러 · 47 endpoint 유지). MCP 도구는 Spring AI `@Tool` 이라 REST 목록과 무관.
>
> ### RWD-5818 — content-profiler 위협탐지·재사용·크로스DB 정합
> - **maker corpNo 강화**: 전 CDC startup 통합 + startup 게이트웨이 신설(`integration/startup/StartupApiGateway` + `StartupApiProperties` + DTO `StartupApiResponse`/`StartupMember`/`StartupProjectType`) + Redis 멤버 캐시(`a20ecf2`).
> - **위협탐지 Slack 알림 신설**(`module/content_profiler/integration/notification/ProfileThreatAlertNotifier`): 최고 심각 조합(`PHISHING ∧ DELETE_SUGGEST`) 시 위협탐지 전용 채널(`SlackWebhookClient#sendThreatAlert`)로 분리 발송, 고심각 메시지 개편, dedup reuse 재등장 알림 추가(`bc9af91`).
> - **위협탐지 후속**: reuse self-guard + reuse 재등장 알림 스로틀을 Redis `SETNX`(`CacheService#setIfAbsent`)로 — 원본 contentId 단위 fleet-wide 1회 수렴, Redis 오류 시 skip(폭주 억제 우선)(`e185268`).
> - **크로스DB 매퍼 원자화 + `ContentBodyResolver` 디스패치 일원화** + `NEWS_COMMENT` campaignId 2-hop 해석. 신규 `CampaignContentResolver`/`crossdb/CampaignContentMapper`(+XML)/`ParentCampaignId`(`835b3aa`).
> - **reuse 평가 보완**: 동일 `contentId`·동일 `sha`(본문 무변경)면 재평가·발행 skip(`07f8ccb`).
> - **라이브 파싱 오류 수정**: `SatisfactionData` 의 미사용 `AverageScore` 필드 제거(`6defcc9`).
> - `ContentType` enum 에 사용자 노출 한글 `label`(알림·로그 표기) 부여 — 정의 시점 강제로 파생 map 드리프트 방지.
>
> ### RWD-5841 — 임시 모니터링 MCP 확장 (T&S read-only)
> - **campaignId 필터 + 캠페인 단위 판정 요약 도구**(`campaignProfileSummary`) 신규(원 테이블 역조회 `CampaignContentResolver`), **sentiment 집계 보강**, **'판정 완료(DONE)만 제공' 원칙**(`a94a9bc`).
> - **기간(`from`/`to`, KST) 조회 모드** 추가(기존 `sinceHours` 최근 모드와 2모드 운용) + 분포 도구에서 **0건·미판정 제외**(`7ec13ad`).
> - STATELESS 전송 전환 완료 후 **keep-alive 설정 제거** 정리(`8c0b587`).
>
> ---
>
> 📅 **2026-07-21 master pull 보강** (47 커밋)
>
> 직전 갱신(2026-07-10) 이후 **content-profiler 2차 대개편**, **모니터링 MCP 서버 신설**, **메이커 의견 알림(RWD-5754) 발송 파이프라인 정합화**가 핵심이다.
>
> ### RWD-5761 — content-profiler 2차 (CDC 파이프라인 대개편)
> - produce/result 파이프라인 정비 + `PERSONAL_MESSAGE` split, CDC consumer 상속→조합(composition) 전환(`38fec0f`), URL 평판 이원화(계약 §5.2), `meta_prompt_version`·MiniBoard 타입 세분화. dedup 옵션 D로 **중앙 `profile_content_hash` 폐지**(`b069437`), 빈글 메타 전 타입 미저장(계약 §5). 결과 DLT Slack 알림 + 고심각(PHISHING/DELETE_SUGGEST) Slack 알림. Kafka 토픽 설정 외부화, 요청 토픽 개명 `content-profiler-requested-v1`.
> - 신규 매퍼/저장소: `mapper/content_profiler/ContentProfileMapper.xml`, `ContentThreatUrlMapper.xml`, `shared/contentrule/normalize/TextHasher.java`, `shared/lock/RedisDistributedLock.java`. H2 통합테스트·프로파일러 IT(`profiler-it/`) 대거 추가.
> - MiniBoard CommentType bulk 전환 + 소스값(SUPPORT/SUGGESTION) 버그수정(`79391a4`).
>
> ### RWD-5761 / RWD-5814 / RWD-5815 — 임시 모니터링 MCP 서버 (T&S read-only)
> - 프로필 메타·원문 조회용 read-only MCP 서버 신설(`mcp/ProfileMonitoringTools`). 인증 헤더를 `X-Mcp-Token`으로 분리해 게이트웨이 `Authorization` 충돌 회피(`McpBearerTokenFilter`), `listActionTargets`(조치 권고 통합 조회) 도구 추가, 세션 방식 → **STATELESS 전송 전환**(세션·리스닝 스트림 제거), `sinceHours` 필터 TZ 정합(DB NOW() 기준).
>
> ### RWD-5754 — 메이커 의견 알림 발송 파이프라인 정합화
> - 발송 윈도우 판정을 status 기반(오픈예정 포함)·`batchDate` KST 날짜 기준으로 전환, 중단(일시중지) 프로젝트 제외, 코호트 분리·keyset·chunk batch·언어기준 정교화, 이력 적재 제거. `OpinionPostMapper.xml` 추가.
> - 메이커 판별 bulk API 전환으로 `getCampaignMakerInfo` N+1 제거, external-api base-url을 서비스 라우팅으로 통일 + internal-token을 cloud secret env 참조로 이관, **`wadiz.domain.kr`를 host-only로 통일**(알림 URL 이중 scheme 수정). push 실패 로그 상세화(HTTP status·PushResponse), 앱푸시 ja/zh 영문화. 랜딩 URL을 funding 커뮤니티 댓글 경로로 변경. 답글 유도 알림 배치 추가.
>
> ### RWD-5806 — 의견 알림 배치 조회 튜닝
> - 배치 조회 쿼리 statement timeout을 환경별 설정으로 분리, 메일 `domainCode` 반영 + cron base default 일원화.
>
> ---
>
> 📅 **2026-07-10 master pull 보강** (24 커밋)
>
> 직전 갱신(2026-06-17, endpoint 44) 이후 **콘텐츠 룰 차단(Content Rule)** 신규 도메인이 추가됐다. 생성 시점 결정론적 룰(ML/외부DB/LLM 0)로 피싱·홍보를 동기 평가·차단하는 1차 게이트 + CDC(Kafka) 기반 URL 평판 후처리 차단. 2개 신규 모듈(`module/content_rule`, `module/content_profiler`) + 무의존 코어(`shared/contentrule`). **신규 컨트롤러 1개 · endpoint 3개 추가 → 총 13 컨트롤러 · 47 endpoint**.
>
> ### RWD-5712 — content-rule 생성 시점 Rulebase 1차 차단 게이트
> - **`module/content_rule/controller/ContentRuleController.java:32,41`** REST 진입점 신설(`@RequestMapping("/api/v1/content-rule")`). `POST /{contentType}/{userId}/evaluations`(룰 평가 → `{status:OK|BLOCK}`), `DELETE /blocked-users/{userId}`(확정 차단 사용자 해제, 멱등). 내부망/서비스 토큰 전제 — 공개 금지, 부작용 없는 평가만.
> - **`module/content_rule/dto/EvaluationStatus.java:17`** 내부 4-state `Action`(ALLOW/HOLD/BLIND/BLOCK)을 호출자 관점 2-state(OK/BLOCK)로 축약. 점수·verdict·firedRules 는 감사 로그에만 적재.
> - **`module/content_rule/dto/EvaluateRequest.java:11`** body 는 `content` 만. 계정 신호(D군)는 호출자가 넘기지 않고 community 가 contentType+userId 로 내부 조회.
> - `shared/contentrule` 무의존 코어(JDK + Guava(PSL) + ICU4J(confusable), Spring 비의존): `ContentRuleEngine`/`ContentRulePolicy`(임계값 90/70/40)/`ContentRuleEvaluator`(신호구성→평가→감사로그→차단적재). REST 진입점과 community 내부 in-process guard(지지서명·댓글 생성·수정 4경로, 차단 시 `ForbiddenApiException`(403) 롤백)가 동일 정책 공유.
> - 차단 적재 Redis+DB 분리: Redis 활성 차단(TTL 1주)+사전차단 fast-path, DB `wadiz_community.content_rule_block_log` append 이력(전용 `@CommunityDbTransactional`). 확정 차단 시 Slack 실시간 알림(`module/content_rule/notify/ContentRuleBlockNotifier`).
>
> ### RWD-5713 — content-profiler CDC 기반 URL 평판 후처리 차단
> - **`module/content_profiler/integration/kafka/`** Kafka CDC 컨슈머 신설(`AbstractCdcThreatConsumer` 베이스 + Signature/SupporterSignatureComment/MiniBoard/PersonalMessage/Satisfaction/SatisfactionReply 6종). 영속화된 콘텐츠를 CDC 로 후처리 평가해 URL 평판 악성 시 차단.
> - **`module/content_rule/controller/ContentRuleController.java:48`** `DELETE /url-reputations?url=` 신규 — 공유 URL 평판 캐시 항목 제거(관리/오탐 정정, 저장 시점과 동일 정규화 후 제거, 멱등).
> - **`shared/contentrule/model/ContentType.java:25`** `SATISFACTION`/`SATISFACTION_COMMENT` 편입 → enum **12종**. 만족도는 생성 경로가 없어 생성시점 차단 제외, **CDC 경로에서만** 평가(soft-delete=`wadiz_reward.{Satisfaction,SatisfactionReply}.IsDeleted`).
>
> ### RWD-5731 — 1:1 문의(PERSONAL_MESSAGE) 위협 탐지 추가 + ContentType rename
> - **`shared/contentrule/model/ContentType.java:24`** `PERSONAL_MESSAGE`(1:1 메신저형 게시판, 메시지 단위 단일 타입) 추가.
> - **`shared/contentrule/model/ContentType.java:22`** `SIGNATURE`/`SIGNATURE_COMMENT` → `SUPPORTER_SIGNATURE`/`SUPPORTER_SIGNATURE_COMMENT` 리네임(in-process 전용이라 REST/wire 영향 없음). 호출부(`SupporterSignatureUserService`, `SupporterSignatureCommunicationUserService`)·테스트·코퍼스 JSON 동기화.
> - **`module/content_rule/repository/crossdb/SpamCleanupMapper.java` / `cleanup/SpamDuplicateDeleter.java`** 도배 정리에 1:1 문의 추가. soft-delete 컬럼 부재로 **hard delete**(root=`UpperMessageNo -1` 보존, child 만).
>
> ### RWD-5762 — 1:1 문의 메이커 발신 메시지 URL 평판 평가 bypass (오탐 완화)
> - **`module/content_profiler/integration/kafka/dto/PersonalMessageData.java:47`** `isFromMaker()` 추가 — 작성자(`RegisterUserId`)가 대화방 주인(`ClientUserId`)과 다르면 메이커 발신(null 가드 fail-safe).
> - **`module/content_profiler/integration/kafka/PersonalMessageCdcConsumer.java:54`** 메이커 발신 시 평가 skip. IPQS 90점(확정 악성) 판정이 실제 메이커 자사 홈페이지였던 오탐 케이스 대응.
>
> ### RWD-5797 — live inbox 링크 이중 scheme 복구 (hotfix)
> - **`src/main/resources/application-live.yml:204`** `wadiz.domain.kr` 에서 `https://` 제거(`https://www.wadiz.kr` → `www.wadiz.kr`). 알림 URL 템플릿(`supporter.signature.*`)이 `https://{0}` 형식이라 domain 에 scheme 포함 시 `https://https://...` 이중 scheme 로 live inbox/push 링크 깨짐. live 한정 hotfix(전 프로파일 정합화는 RWD-5754 정식 배포).
>
> ---
>
> 📅 **2026-05-29 갱신** (최초 분석: 2026-04-26 master pull, 36 커밋) — 본 분석 baseline 시점에는 Phase 0~1 스캐폴드 였으나, 현재는 **Phase 6 v1.3.0 풀 구현 완료 + Live 배포 완료**. 이 문서 본문은 baseline 기준 (구버전). 현재 구현은 아래 박스 참조.
>
> ### 현재 상태 (2026-05-29)
> - **202+ Java 파일**, **44 REST endpoint** (공개 37 + adm 관리자 7, RWD-5698), 12 컨트롤러
> - 서비스 포트 `9380` (이전 9011 → 2026-04 변경)
> - **Java 21 LTS** (Eclipse Temurin, 2026-04 Java 25 → 21 다운그레이드), Virtual Thread, Jackson 3 + 2.x annotations 호환, RestClient 단일화
> - **root package**: `co.wadiz.api.community` (이전 `co.wadiz.community` → RWD-5550 리네임)
> - 모듈 구조:
>   ```
>   src/main/java/co/wadiz/api/community/
>   ├── config/{middleware, properties, db}
>   ├── integration/{mail, user, push, campaign, points, event}
>   ├── module/supporter_signature/   # ★ wave.user V3 11 컨트롤러 풀 이관
>   │   ├── controller/ service/ repository/{entity,mapper,param}
>   │   ├── dto/{request,response}/{signature,point,affiliate,communication,keyword}
>   │   ├── integration/{cache, notification}
>   │   ├── component/, model/{constant, domain}, event/
>   └── shared/{wadiz, response, cache, util, common, error}
>   ```
> - **공개 API 11 컨트롤러** (V3, wave.user 와 동일 경로):
>   `/api/v3/supporter-signatures{,/keywords,/points,/interest-degree}`,
>   `/api/v3/users/{userId}/supporter-signatures`, `/api/v3/supporter-signatures/{comments,affiliates}` 등
> - **추가된 API**: `GET /api/v3/supporter-signatures/affiliates/targets` (포인트 적립 대상 조회, RWD-5453)
> - **추가된 adm 관리자 API (RWD-5698)**: `/api/v3/admin/supporter-signatures/**` + `/api/v3/admin/users/{userId}/supporter-signatures/**` — 다중조건 검색(삭제 포함), 답글 목록, 개별 삭제/복구, 답글 생성/삭제/복구 (2 컨트롤러 · 7 endpoint). Swagger '지지서명' 그룹에 함께 노출
> - **제거된 API**: 지지서명 ID 조회 API 제거 (dangling 체인 cascade 삭제, RWD-5532)
> - 사내 `ARCHITECTURE.md` 추가 — Modular Monolith 설계 철학
> - **EKS 배포 인프라** 도입 — jib 컨테이너 빌드 + k8s ConfigMap bootstrap + GitHub Actions (RC1/RC2/Live)
> - **Consul Discovery** 연동 (rc1/localdev 프로파일)
> - **logback-spring.xml** 로깅 레이어 도입 (live 로그 정책 funding 서비스와 동치, RWD-5598)
> - **DB**: 전용 community-api DB 계정으로 분리 (main/replica), MySQL 5.7 호환 SQL 컨벤션 정착
> - **mysql-connector-j 8.0.33** 고정 (RWD-5598)
> - **@ConditionalOnBean** production 에서 제거 — dev/test 환경 가드는 autoconfigure.exclude 로만 유지
>
> ### 분석 영향
> - **`docs/_flows/supporter-signature.md`** — 기존엔 `com.wadiz.web → RestTemplate → wave.user`. 현재 community 가 동일 V3 경로 풀 구현 상태이므로 **RestTemplate target 이 community(9011)로 전환됐는지 / 라우팅 분기 중인지 검증 필요**.
> - **Phase 2 승격 권장**: 단일 파일 → `docs/co.wadiz.api.community/api-details/` 폴더로 분할 (module/integration/shared 별 심화).

---

## 개요
`com.wadiz.wave.user` 의 **Supporter Signature V3** 모듈을 독립 서비스로 포팅하며, 신규 커뮤니티 기능(messaging, points, campaign 등)을 함께 개발 중인 신규 서비스입니다. **(baseline 시점 Phase 0~1 스캐폴드)** — 현재는 풀 구현 (위 박스 참조). Org: `wadiz-service`.

## 기술 스택 (현 시점)
- **Java 21 LTS** (Eclipse Temurin; 초기 Java 25에서 RWD-5508 에서 다운그레이드)
- **Spring Boot 4.0.5**
- **Gradle 9.4.1 Kotlin DSL**
- **MyBatis 4.0.1** + **QueryDSL 7.0** (`io.github.openfeign.querydsl` fork)
- **MapStruct 1.6.3**
- **SpringDoc 3.0.0** (OpenAPI, GroupedOpenApi + @Tag 통합)
- **mysql-connector-j 8.0.33** (고정, RWD-5598)
- Redis, RabbitMQ, JPA(예정)
- 가장 신스택 — 회사 내 미래 표준 검증용 성격.

## 아키텍처 (계획)
- 모듈형 레이어드 + CQRS 유사 패턴 추정 (도메인 미구현 상태).
- 패키지 prefix: `co.wadiz.community.*`.
- 도메인 후보: `signature` (서명/펀딩 응원), `campaign`, `points`, `messaging`.
- Hexagonal/DDD 구조는 community.signature.repository 매퍼 패키지 참조로 보아 layered + repository pattern 으로 시작 추정.

## 현재 코드 구성

```
src/main/java/co/wadiz/community/
├── CommunityApplication.java        ← @MapperScan("co.wadiz.community.domain.signature.repository.mapper")
└── config/
    ├── AsyncConfig.java             ← signatureTaskExecutor (core 4 / max 8 / queue 50, prefix sig-async-)
    ├── DdlAutoSafetyGuard.java      ← non-embedded JDBC URL일 때 ddl-auto 위험값 차단
    ├── HttpClientConfig.java        ← campaign/campaignShort/point RestClient 3종
    ├── MybatisConfig.java
    ├── RabbitMqConfig.java          ← DirectExchange("community.signature.exchange")
    ├── RedisConfig.java
    ├── SecurityConfig.java          ← 현재 .anyRequest().permitAll() (OAuth2 JWT 활성화는 Phase 6 예정)
    └── WebConfig.java

src/main/resources/
├── application.yml
├── application-dev.yml
└── META-INF/spring.factories         ← DdlAutoSafetyGuard EnvironmentPostProcessor 등록

src/test/java/co/wadiz/community/
├── CommunityApplicationTests.java
└── DdlAutoSafetyGuardTest.java
```

## API 엔드포인트 목록
- **현재 0개** — `@RestController` 가 아직 정의되지 않음.
- `@MapperScan` 이 가리키는 `co.wadiz.community.domain.signature.repository.mapper` 패키지도 미존재.
- Phase 진행 시 signature/campaign/points/messaging 도메인 추가 예정.

## 주요 설정 분석

### `HttpClientConfig.java`
3개의 `RestClient` Bean — community 가 외부 점수/캠페인 서비스를 호출하는 구조 사전 정의:

| Bean | connect / read | 용도 |
|---|---|---|
| `campaignRestClient` | 5s / 10s | 캠페인 일반 호출 |
| `campaignShortRestClient` | 1s / 2s | 캠페인 빠른 응답용 (two-tier SLA) |
| `pointRestClient` | 5s / 10s | 포인트 적립/차감 호출 |

### `RabbitMqConfig.java`
- DirectExchange: `community.signature.exchange` (레거시 `userApiExchange` 와 명시적으로 단절 — 새 네이밍 채택).

### `AsyncConfig.java`
- `signatureTaskExecutor` (core 4 / max 8 / queue 50, thread prefix `sig-async-`) — 서명 후속 처리(이벤트 발행, 알림 등) 비동기 디스패치용.

### `DdlAutoSafetyGuard.java`
- `EnvironmentPostProcessor` 로 등록.
- prod/stage 환경(임베드 JDBC URL 아님)에서 `spring.jpa.hibernate.ddl-auto` 가 `create`/`create-drop`/`update` 면 부팅 차단.
- 운영 사고 방지용 가드. `META-INF/spring.factories` 통해 자동 활성.

### `SecurityConfig.java`
- 현재 `.anyRequest().permitAll()` — Phase 6 에 OAuth2 Resource Server JWT 검증 활성화 예정 (주석으로 코드 보존).

### dev/test 프로파일
- `spring.autoconfigure.exclude` 로 `RedisAutoConfiguration` / `RabbitAutoConfiguration` 제외.
- 각 Config 에도 `@ConditionalOnBean` 추가로 더블 가드.

## DB 스키마 요약
- 미정 (Entity 0개, Mapper XML 0개).
- 향후 `signature` 도메인부터 테이블 정의 예정 — 레거시 `wave.user` 의 supporter signature 테이블 마이그레이션 또는 신규 설계.

## 외부 의존성 (사전 정의)
- HTTP: campaign 서비스, point 서비스 (RestClient Bean).
- MQ: RabbitMQ exchange `community.signature.exchange` (publisher 역할 추정).
- Cache: Redis (도메인 캐시 예정).
- Auth: OAuth2 Resource Server (Phase 6 활성).

## 특이사항

- **회사 내 최첨단 스택** — Java 25 + Spring Boot 4 + Gradle 9 + QueryDSL 7. 다른 어떤 wadiz repo보다 새로움. 신기술 검증 + 표준 정립 의도.
- **DdlAutoSafetyGuard** 가 `EnvironmentPostProcessor` + `spring.factories` 로 자동 작동 — 사고 방지 패턴 모범 사례.
- **이중 방어 (autoconfigure exclude + ConditionalOnBean)** — dev/test 환경에서 외부 인프라 부재로 부팅 실패 방지.
- **two-tier SLA RestClient** (`campaignShortRestClient` 1s/2s) — 빠른 fallback 용도 사전 마련.
- **Phase 6 OAuth2 활성** 주석 처리 — 인증 통합 시점이 도메인 구현 이후로 잡혀 있음.
- 도메인 코드는 비어 있어 분석 가치는 **설정 패턴** 위주. 진행도 추적은 git log로 확인 권장.

---

## 최근 변경사항

**분석 갱신일: 2026-06-17** (직전: 2026-05-29)

| 변경 내용 | 관련 이슈 | 비고 |
|---|---|---|
| adm 관리자 지지서명 API 신설 — 2 컨트롤러 (`SupporterSignatureAdminController` / `SupporterSignatureAdminUserController`) + `SupporterSignatureAdminService` | RWD-5698 | base `/api/v3/admin/supporter-signatures`, `/api/v3/admin/users/{userId}/supporter-signatures` |
| 새 API: `GET /admin/supporter-signatures/search` (다중조건 검색, 삭제 포함) | RWD-5698 | param `includeDeleted`/`commentIncludeDeleted`/`includeEmptyContent`/`statusType` 등 |
| 새 API: 관리자 답글 목록 `GET /{signatureId}/comments`, 개별 삭제/복구, 답글 생성/삭제/복구 | RWD-5698 | userId scope 컨트롤러로 분리 (소유자 검증) |
| `includeEmptyContent` / `commentIncludeDeleted` 검색 파라미터 추가 | RWD-5698 | 검색 commentCount 삭제포함 기본화 |
| admin API Swagger '지지서명' 그룹 노출 (`/api/v3/admin/**` pathsToMatch 추가) | RWD-5698 | `OpenApiConfig` |
| 단건 삭제 API 삭제상태 일원화 + `DELETED_BY_ISSUE` 유형 추가 | RWD-5697 | `delete(signatureId, statusType)` 단일 위임, `isDeleteStatus()` helper (비삭제 상태 403) |
| 트래킹 생성 요청 `affiliateType` 필수값 검증 (`@NotNull` + Schema REQUIRED) | RWD-5548 | `CreateTrackingRequest` |
| clive(IDC live ECR) GitHub Actions workflow 추가 | RWD-5613 | `aws_deploy_ecr_clive.yml` |
| APM/관측 agent 정책 — Elastic 1.55.6 + WhaTap weaving live 정상 동작 확인 | RWD-5607 | CLAUDE.md (코드 변경 0) |

**분석 갱신일: 2026-05-29** (이전: 2026-04-26)

| 변경 내용 | 관련 이슈 | 비고 |
|---|---|---|
| Java 25 → Java 21 LTS (Eclipse Temurin) 다운그레이드 | RWD-5508 | EKS 인프라 정렬 |
| 서비스 포트 9011 → 9380 | RWD-5466/5508 | |
| root package `co.wadiz.community` → `co.wadiz.api.community` | RWD-5550 | 전체 패키지 리네임 |
| EKS 배포 인프라 도입 (jib + k8s ConfigMap + GitHub Actions) | RWD-5509 | RC1/RC2/Live |
| Consul Discovery 연동 | RWD-5466 | rc1/localdev 프로파일 |
| 새 API: `GET /affiliates/targets` (포인트 적립 대상 조회) | RWD-5453/5466 | |
| 지지서명 ID 조회 API 제거 | RWD-5532 | dangling chain cascade 삭제 |
| Swagger UI GroupedOpenApi + @Tag 통합 | RWD-5532 | 그룹 dropdown, cloud prefix |
| Cache 레이어 JSON 직렬화 재설계 | RWD-5509 | |
| @ConditionalOnBean production 제거 | RWD-5509 | dev/test는 autoconfigure.exclude 유지 |
| DB community-api 전용 계정 분리 (main/replica) | RWD-5550 | |
| logback-spring.xml 로깅 레이어 도입 | RWD-5598 | live 로그 정책 funding 동치 |
| mysql-connector-j 8.0.33 고정 | RWD-5598 | |
| HTTP pool keep-alive validate 30s → 1s (race 회피) | RWD-5577 | |
| BIT(1) IS TRUE 술어 일괄 치환 | RWD-5577 | MySQL 5.7 호환 |
| application-dev.yml → application-odev.yml 리네임 | RWD-5509 | |
