# kr.wadiz.backoffice.indexer-schedule 분석 문서

> 백오피스(사내 업무 시스템)가 쓰는 **기반 데이터를 스케줄로 색인하는 배치 애플리케이션**입니다. 저장소 설명 그대로 *"스케쥴 방식으로 기반데이터를 색인하는 어플리케이션"* 입니다.
> Org: `wadiz-backoffice` (`https://github.com/wadiz-backoffice/kr.wadiz.backoffice.indexer-schedule.git`). 배포 이름 `indexer-schedule`, 플랫폼 `backoffice`.

> 📅 분석 기준: 2026-09-15, **`main` 브랜치**(`1700443`, 2026-09-10). Java 306개.

> ℹ️ 같은 org 에 짝이 되는 색인기가 둘 더 있습니다 — `kr.wadiz.backoffice.indexer-cdc`(helm 상 `indexer-cdc01`·`indexer-cdc02`)와 `kr.wadiz.backoffice.api`. **둘 다 아직 문서가 없습니다.**
> 이름이 비슷한 `com.wadiz.search.indexer-{dokdo,geojedo}` 는 **전시·검색용 색인기로 팀·용도가 다릅니다** — 이쪽은 백오피스(정산·광고·회계) 전용입니다.

---

## 개요

- **CDC(변경 데이터 캡처)가 아니라 스케줄(cron)** 로 도는 색인기입니다. 짝이 되는 `indexer-cdc` 가 실시간 변경을 잡고, 이쪽은 **주기적으로 모아서 넣는 쪽**입니다(추정 — 이름과 역할 분담 기준).
- **`@Scheduled` 가 37개**, 스케줄러 클래스가 20개입니다. cron 값은 모두 **설정 키로 빼 두었습니다**(`index.scheduler.*`) — 코드 수정 없이 주기를 바꿀 수 있습니다.
- 헥사고날(포트·어댑터) 구조를 씁니다 — `adapter/{도메인}/port/in`(스케줄러) · `port/out`(조회·적재 어댑터).

## 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 언어/런타임 | **Java 17** | `build.gradle` (`sourceCompatibility = '17'`) |
| 프레임워크 | **Spring Boot 3.2.0** (웹 없음 — `spring-boot-starter`) | `build.gradle` |
| 색인 대상 | **OpenSearch**(`opensearch-java 2.8.1`) + Spring Data Elasticsearch 설정 | `build.gradle`, README |
| DB | **MySQL 8.0** + MyBatis | `build.gradle` |
| **데이터 웨어하우스** | **Snowflake**(`snowflake-jdbc 3.22.0`) | `build.gradle` |
| 알림 | **Slack**(`slack-api-client 1.44.1`) — 봇·웹훅 2종 구현 | `global/util/NotificationServiceSlack*.java` |
| 파일 전송 | **SFTP**(`jsch`) | `global/util/SFTPUtil.java` |
| 쿠버네티스 설정 | `spring-cloud-starter-kubernetes-client-config` + bootstrap | `build.gradle` |
| 기타 | Apache Commons CSV · commons-io · spring-retry · AWS SDK apache-client · JAXB | `build.gradle` |
| 빌드/이미지 | Gradle + **Jib 3.5.2** | `build.gradle` |

> 🔎 **Snowflake 를 직접 조회합니다.** 도서관에 등록된 저장소 중 Snowflake JDBC 를 쓰는 것은 현재 이 저장소뿐입니다. 광고·정산 데이터를 웨어하우스에서 읽어 색인하는 경로가 있다는 뜻입니다(`SearchERPSettlementSnowflakeAdapter`·`SearchAdvertiseDataSnowflakeAdapter`).

## 계층 구조

| 패키지 | Java 파일 | 역할 |
|---|---:|---|
| `application` | 87 | 유스케이스 |
| `adapter` | 64 | 스케줄러(`port/in`)와 조회·적재 어댑터(`port/out`) |
| `infrastructure` | 68 | OpenSearch·MySQL·Snowflake·외부 API 연동 |
| `domain` | 31 | 도메인 모델 |
| `global` | 20 | 공통 — Slack 알림·SFTP·유틸 |

## 색인 도메인 16종

`adapter` 하위가 곧 색인 대상입니다.

| 도메인 | 스케줄러 | 다루는 것 |
|---|---|---|
| **funding** | `FundingSchedule` · `FundingGradeSchedule` · `FundingByCountryMetricSchedule` · `RestoreFundingSchedule` | 펀딩 기본·등급·**국가별 지표**·복구 |
| **settlement** | `ERPSettlementSchedule` | ERP 정산(펀딩·스토어 수수료율) |
| **sales** | `ERPSalesSchedule` | ERP 매출(세금 발생분·복구) |
| **adcenter** | `AdCenterSchedule` | 광고센터 — 광고 이력·결제 이력 |
| **advertise** | `AdvertiseFeeSchedule` | 광고 수수료 — 광고/비즈 캠페인 |
| **affiliate** | `AffiliateSchedule` | 제휴 — 체결·연장·해지·신규주문·재기재 등 6종 |
| **company** | `CompanySchedule` · `RestoreCompanyScheduleTemporary` | 기업 정보(등급 포함) |
| **store** | `RestoreStoreSchedule` | 스토어 복구 |
| **membership** | `MembershipSchedule` | 멤버십(인덱스 `membership_sales`) |
| **comingsoon** | `ComingSoonSchedule` | 오픈예정 성과 |
| **event** | `EventSchedule` | 리워드 이벤트 |
| **currency** | `ExchangeRateSchedule` | 환율(내부) |
| **holiday** | `HolidayCalendarSchedule` | 휴일 달력 |
| **waditag** | `TagViewSchedule` | 와디태그 조회수 |
| **notification** | `NotificationSchedule` · `ERPBatchNotificationSchedule` | 알림·**ERP 배치 파일 점검** |
| **user** | — | 사용자 |

- `Restore*` 스케줄러가 4개(funding·company·store·sales) 있습니다 — **색인이 어긋났을 때 되메우는 경로**를 도메인마다 따로 둔 구조입니다.
- `RestoreCompanyScheduleTemporary` 는 이름에 **`Temporary`** 가 붙어 있습니다. 임시로 넣어 둔 뒤 남은 것으로 보이나 미확인입니다.

## 저장소 안의 설계 문서

`src/main/java/.../documents/` 에 **PlantUML 시퀀스 다이어그램 8개**가 코드와 함께 들어 있습니다.

`FundingGradeSequence` · `FundingPerformanceSequence` · `IndexGlobalFundingDataSF` · `IndexPushBannerAdFeeSF` · `MembershipSequence` · `RestoreEmptyFundingMakerSequence` · `RestoreFundingSequence` · `SalesTaxAccrualsSequence`

> 파일명의 **`SF` 는 Snowflake** 로 보입니다(`IndexGlobalFundingDataSF`·`IndexPushBannerAdFeeSF`) — 글로벌 펀딩 데이터와 푸시 배너 광고비를 웨어하우스에서 읽는 흐름입니다(추정).

## 배포

2026-09-10 에 **환경별로 흩어져 있던 워크플로 4개를 하나로 합쳤습니다**(`aws_deploy_ecr.yml`, 47줄). 이전에는 `dev`·`rc`·`rc2`·`live` 워크플로가 따로 있었습니다(157줄 삭제).

| 트리거 브랜치 | ECR 계정 | 갱신 대상 values |
|---|---|---|
| `dev` | `843734097580` | `backoffice/dev/indexer-schedule.yaml` |
| `rc` · **`rc4`** | `843734097580` | `backoffice/rc4/indexer-schedule.yaml` |
| **`main`** | `393290902814` | `backoffice/clive/indexer-schedule.yaml` |

- 합치는 과정이 4커밋에 걸쳐 단계적으로 진행됐습니다 — **① odev·rc1·rc2·live values 갱신 제거 → ② 단일 워크플로로 통합 → ③ 대상을 dev·rc·main 으로 한정 → ④ rc4 추가.**
- `workflow_dispatch` 로 수동 실행도 가능합니다.
- 공용 워크플로 `wadiz-gitops/workflows-container-image-build-push` 의 `build_push_container_image` · `update_image_tag` 를 호출합니다.
- 같은 형태의 정리가 같은 날 [`co.wadiz.currency-exchange`](./co.wadiz.currency-exchange.md) 에도 적용됐습니다.

## 최근 변경 (2026-09-10 · 4커밋)

전부 배포 워크플로 통합입니다(위 "배포" 참조). **애플리케이션 코드 변경은 없습니다.**

- 직전(2026-09-10 이전)에는 `SCOUT-150` 으로 **멤버십 상태에 `GRACE_PERIOD`(결제 유예)를 추가**했습니다 — 2026-09-10 회차에 기록한 **8개 저장소 동시 반영**의 하나입니다. 색인기가 새 상태값을 모르면 역직렬화가 깨지기 때문입니다.

## 로컬 실행

README 에 절차가 있습니다 — `application-local.yml`(gitignore 대상)을 만들어 **OpenSearch 호스트·인증 정보**, `index.prefix`(예 `dev-`), **ERP 정산 시스템 자격증명**(`settlement.wadizcorp.kr`)을 직접 넣어야 합니다.

> ⚠️ ERP 정산 호스트가 **`wadizcorp.kr`**(사내 도메인)입니다. 서비스 도메인(`wadiz.kr`·`wadiz.io`)과 별개의 사내 시스템을 직접 호출합니다.

## 미확인 항목

- **`indexer-cdc`(01·02)와의 역할 분담** — 어떤 데이터가 CDC 로, 어떤 것이 스케줄로 들어가는지. 두 저장소를 함께 봐야 확인됩니다.
- **인덱스 이름 전수** — 코드 문자열로 잡힌 것은 `erp-settlement`·`membership_sales`·`cjevent` 정도이고, 나머지는 설정(`index.prefix` + 키)으로 조립되는 것으로 보입니다. 전수 목록은 [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `backoffice/clive/indexer-schedule.yaml` `configmap.data` 를 봐야 합니다.
- **cron 실제 값** — 전부 설정 키라 코드에는 없습니다. 위와 같은 values 파일 참조.
- `RestoreCompanyScheduleTemporary` 의 존치 여부.
- 테스트 유무는 이번 스캔 범위 밖입니다.
