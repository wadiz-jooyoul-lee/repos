# Wadiz Repos — Clone URL 인벤토리

부모 repo(`wadiz-jooyoul-lee/repos`) 하위 81개 Wadiz repo 의 clone URL 목록입니다. 새 팀원 온보딩·환경 재구축·조직 이동 시 참조하십시오.

각 repo 의 역할·스택·심층 분석 위치는 [`CLAUDE.md`](../CLAUDE.md) 및 [`docs/<repo>/`](./) 를 참조하세요.

## 사용법

전체 clone (부트스트랩):

```bash
cd ~/work/repos
./clone-all.sh              # SSH 기본 (git@github.com:...)
./clone-all.sh --https      # HTTPS (https://github.com/...)
PROTOCOL=https ./clone-all.sh   # env var 방식
```

이미 있는 폴더는 자동 skip. SSH 사용 시 GitHub 에 SSH 키 등록 필요, HTTPS 사용 시 PAT/credential helper 필요.

특정 org 만 필요하면:

```bash
grep "wadiz-service" docs/repos-inventory.md | grep -oE "git@github\.com:\S+\.git" | xargs -I{} git clone {}
```

전 repo 최신화(이미 있는 경우):

```bash
./execute_all git pull
```

---

## 1. `wadiz-service` — 백엔드 도메인 서비스 (11개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| co.wadiz.api.community | `git@github.com:wadiz-service/co.wadiz.api.community.git` | [docs](./co.wadiz.api.community/) |
| co.wadiz.currency-exchange | `git@github.com:wadiz-service/co.wadiz.currency-exchange.git` | [docs](./co.wadiz.currency-exchange.md) |
| co.wadiz.fep | `git@github.com:wadiz-service/co.wadiz.fep.git` | [docs](./co.wadiz.fep.md) |
| com.wadiz.api.funding | `git@github.com:wadiz-service/com.wadiz.api.funding.git` | [docs](./com.wadiz.api.funding/) |
| com.wadiz.api.reward | `git@github.com:wadiz-service/com.wadiz.api.reward.git` | [docs](./com.wadiz.api.reward/) |
| com.wadiz.api.startup | `git@github.com:wadiz-service/com.wadiz.api.startup.git` | [docs](./com.wadiz.api.startup.md) |
| com.wadiz.wave.searcher | `git@github.com:wadiz-service/com.wadiz.wave.searcher.git` | [docs](./com.wadiz.wave.searcher.md) |
| com.wadiz.wave.user | `git@github.com:wadiz-service/com.wadiz.wave.user.git` | [docs](./com.wadiz.wave.user/) |
| kr.wadiz.account | `git@github.com:wadiz-service/kr.wadiz.account.git` | [docs](./kr.wadiz.account/) |
| kr.wadiz.user.link | `git@github.com:wadiz-service/kr.wadiz.user.link.git` | [docs](./kr.wadiz.user.link.md) |
| nicepay-api | `git@github.com:wadiz-service/nicepay-api.git` | [docs](./nicepay-api.md) |

## 2. `wadiz-client` — 클라이언트팀 (7개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| app-api | `git@github.com:wadiz-client/app-api.git` | [docs](./app-api.md) |
| client-document | `git@github.com:wadiz-client/client-document.git` | [docs](./client-document.md) |
| figma-icon-sync | `git@github.com:wadiz-client/figma-icon-sync.git` | [docs](./figma-icon-sync.md) |
| makercenter-be | `git@github.com:wadiz-client/makercenter-be.git` | [docs](./makercenter-be.md) |
| makercenter-fe | `git@github.com:wadiz-client/makercenter-fe.git` | [docs](./makercenter-fe.md) |
| makercenter-fe-admin | `git@github.com:wadiz-client/makercenter-fe-admin.git` | [docs](./makercenter-fe-admin.md) |
| wadiz-claude-plugins | `git@github.com:wadiz-client/wadiz-claude-plugins.git` | [docs](./wadiz-claude-plugins.md) |

## 3. `wadiz-fe` — 신규 FE 모노레포 (1개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| wadiz-frontend | `git@github.com:wadiz-fe/wadiz-frontend.git` | [docs](./wadiz-frontend/) |

## 4. `wadiz-web` — 레거시 코어 (2개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| com.wadiz.web | `git@github.com:wadiz-web/com.wadiz.web.git` | [docs](./com.wadiz.web/) |
| com.wadiz.adm | `git@github.com:wadiz-web/com.wadiz.adm.git` | [docs](./com.wadiz.adm/) |

## 5. `wadiz-app` — 공식 모바일 앱 (2개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| wadiz-android | `git@github.com:wadiz-app/wadiz-android.git` | [docs](./wadiz-android.md) |
| wadiz-ios | `git@github.com:wadiz-app/wadiz-ios.git` | [docs](./wadiz-ios.md) |

## 6. `wa-infrastructure` — CDC / 인프라 (1개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| cdc | `git@github.com:wa-infrastructure/cdc.git` | [docs](./cdc.md) |

## 7. `wadiz-ai` — AI 서비스 (1개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| ai-project-audit | `git@github.com:wadiz-ai/ai-project-audit.git` | [docs](./ai-project-audit.md) |

## 8. `wadiz-batch` — 배치·감사 서버군 (5개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| com.wadiz.batch.payment | `git@github.com:wadiz-batch/com.wadiz.batch.payment.git` | [docs](./wadiz-batch.md#1-comwadizbatchpayment--결제-배치) |
| com.wadiz.startup.batch | `git@github.com:wadiz-batch/com.wadiz.startup.batch.git` | [docs](./wadiz-batch.md#2-comwadizstartupbatch--스타트업투자-배치) |
| com.wadiz.wave.statistics | `git@github.com:wadiz-batch/com.wadiz.wave.statistics.git` | [docs](./wadiz-batch.md#3-comwadizwavestatistics--통계-집계-멀티모듈) |
| main2-batch | `git@github.com:wadiz-batch/main2-batch.git` | [docs](./wadiz-batch.md#4-main2-batch--메인-화면-배치-quartz) |
| com.wadiz.wave.audit | `git@github.com:wadiz-batch/com.wadiz.wave.audit.git` | [docs](./wadiz-batch.md#5-comwadizwaveaudit--앱별-감사-로그-수집기) |

## 9. `wadiz-membership` — 멤버십 API + Gateway (2개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| MemberShip-Api-Server | `git@github.com:wadiz-membership/MemberShip-Api-Server.git` | [docs](./wadiz-membership.md#1-membership-api-server--멤버십-코어-api) |
| User-Api-Gateway | `git@github.com:wadiz-membership/User-Api-Gateway.git` | [docs](./wadiz-membership.md#2-user-api-gateway--spring-cloud-gateway) |

## 10. `wadiz-search` — ElasticSearch Indexer (3개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| com.wadiz.search.indexer-dokdo | `git@github.com:wadiz-search/com.wadiz.search.indexer-dokdo.git` | [docs](./wadiz-search.md#1-comwadizsearchindexer-dokdo--메인-통합-인덱서) |
| com.wadiz.search.indexer-geojedo | `git@github.com:wadiz-search/com.wadiz.search.indexer-geojedo.git` | [docs](./wadiz-search.md#2-comwadizsearchindexer-geojedo--확장-인덱서) |
| indexer-startup | `git@github.com:wadiz-search/indexer-startup.git` | [docs](./wadiz-search.md#3-indexer-startup--스타트업투자-전용) |

## 11. `wadiz-settlement` — 정산 시스템 (4개)

| Repo | Clone URL | 상세 문서 |
|---|---|---|
| co.wadiz.settlement-orchestrator | `git@github.com:wadiz-settlement/co.wadiz.settlement-orchestrator.git` | [docs](./wadiz-settlement.md#1-cowadizsettlement-orchestrator--신규-오케스트레이터) |
| co.wadiz.settlement | `git@github.com:wadiz-settlement/co.wadiz.settlement.git` | [docs](./wadiz-settlement.md#2-cowadizsettlement--레거시-정산-monorepo) |
| douzone-comet-service-tc-stsacr-x20191 | `git@github.com:wadiz-settlement/douzone-comet-service-tc-stsacr-x20191.git` | [docs](./wadiz-settlement.md#3-douzone-comet-service-tc-stsacr-x20191--개별-모듈-분리-저장소) |
| policy-docs | `git@github.com:wadiz-settlement/policy-docs.git` | [docs](./wadiz-settlement.md#4-policy-docs--정산-정책-마이그레이션-문서) |

## 12. `wadiz-tech` — 플랫폼팀 API·Agent 서버군 (42개)

상세 카테고리·역할·Boot 버전은 [`wadiz-tech.md`](./wadiz-tech.md) 참조.

### 12.1 알림 — 메일 (7)
| Repo | Clone URL |
|---|---|
| mail-normal-api | `git@github.com:wadiz-tech/mail-normal-api.git` |
| mail-fast-api | `git@github.com:wadiz-tech/mail-fast-api.git` |
| mail-common-api | `git@github.com:wadiz-tech/mail-common-api.git` |
| mail-ses-agent | `git@github.com:wadiz-tech/mail-ses-agent.git` |
| mail-toast-agent | `git@github.com:wadiz-tech/mail-toast-agent.git` |
| mail-log-agent | `git@github.com:wadiz-tech/mail-log-agent.git` |
| noti-channel | `git@github.com:wadiz-tech/noti-channel.git` |

### 12.2 알림 — 푸시 (4)
| Repo | Clone URL |
|---|---|
| push-api | `git@github.com:wadiz-tech/push-api.git` |
| push-read-api | `git@github.com:wadiz-tech/push-read-api.git` |
| push-agent | `git@github.com:wadiz-tech/push-agent.git` |
| push-postpone (Go) | `git@github.com:wadiz-tech/push-postpone.git` |

### 12.3 알림 — SMS·알림톡·친구톡 (8)
| Repo | Clone URL |
|---|---|
| kr.wadiz.platform.api.sms | `git@github.com:wadiz-tech/kr.wadiz.platform.api.sms.git` |
| kr.wadiz.platform.agent.sms | `git@github.com:wadiz-tech/kr.wadiz.platform.agent.sms.git` |
| kr.wadiz.platform.api.sms.ad | `git@github.com:wadiz-tech/kr.wadiz.platform.api.sms.ad.git` |
| kr.wadiz.platform.agent.sms.ad | `git@github.com:wadiz-tech/kr.wadiz.platform.agent.sms.ad.git` |
| kr.wadiz.platform.api.alimtalk | `git@github.com:wadiz-tech/kr.wadiz.platform.api.alimtalk.git` |
| kr.wadiz.platform.agent.alimtalk | `git@github.com:wadiz-tech/kr.wadiz.platform.agent.alimtalk.git` |
| kr.wadiz.platform.api.friendtalk | `git@github.com:wadiz-tech/kr.wadiz.platform.api.friendtalk.git` |
| kr.wadiz.platform.agent.friendtalk | `git@github.com:wadiz-tech/kr.wadiz.platform.agent.friendtalk.git` |

### 12.4 알림 인프라·인박스·CRM (6)
| Repo | Clone URL |
|---|---|
| notification-log-agent | `git@github.com:wadiz-tech/notification-log-agent.git` |
| inbox-agent | `git@github.com:wadiz-tech/inbox-agent.git` |
| kr.wadiz.platform.inbox | `git@github.com:wadiz-tech/kr.wadiz.platform.inbox.git` |
| ses-event-subscriber (Python) | `git@github.com:wadiz-tech/ses-event-subscriber.git` |
| kr.wadiz.platform.crm | `git@github.com:wadiz-tech/kr.wadiz.platform.crm.git` |
| kr.wadiz.platform.crm-agent | `git@github.com:wadiz-tech/kr.wadiz.platform.crm-agent.git` |

### 12.5 플랫폼 코어 (4)
| Repo | Clone URL |
|---|---|
| kr.wadiz.platform.file | `git@github.com:wadiz-tech/kr.wadiz.platform.file.git` |
| display-agent | `git@github.com:wadiz-tech/display-agent.git` |
| collection-api | `git@github.com:wadiz-tech/collection-api.git` |
| share-api | `git@github.com:wadiz-tech/share-api.git` |

### 12.6 검색·시맨틱 (4)
| Repo | Clone URL |
|---|---|
| keyword | `git@github.com:wadiz-tech/keyword.git` |
| keyword-agent | `git@github.com:wadiz-tech/keyword-agent.git` |
| semantic-search-api (Python) | `git@github.com:wadiz-tech/semantic-search-api.git` |
| semantic-search-fe (Node/React) | `git@github.com:wadiz-tech/semantic-search-fe.git` |

### 12.7 어드민·인프라 (2)
| Repo | Clone URL |
|---|---|
| platform-admin | `git@github.com:wadiz-tech/platform-admin.git` |
| kafka-connect-admin (Python) | `git@github.com:wadiz-tech/kafka-connect-admin.git` |

### 12.8 메인 화면 (4)
| Repo | Clone URL |
|---|---|
| main2-api | `git@github.com:wadiz-tech/main2-api.git` |
| main2-batch-api | `git@github.com:wadiz-tech/main2-batch-api.git` |
| main2-stream-agent | `git@github.com:wadiz-tech/main2-stream-agent.git` |
| main2-stream-scheduler (Go) | `git@github.com:wadiz-tech/main2-stream-scheduler.git` |

### 12.9 유저·위시·메트릭 (3)
| Repo | Clone URL |
|---|---|
| user-activity-api (Boot 4) | `git@github.com:wadiz-tech/user-activity-api.git` |
| wish-api | `git@github.com:wadiz-tech/wish-api.git` |
| project-metric-api | `git@github.com:wadiz-tech/project-metric-api.git` |

---

## 재생성 방법

이 표는 아래 명령으로 실측 갱신할 수 있습니다:

```bash
cd ~/work/repos
for d in */; do
  if [ -d "$d/.git" ]; then
    url=$(git -C "$d" remote get-url origin 2>/dev/null)
    printf "| %s | \`%s\` |\n" "${d%/}" "$url"
  fi
done
```

## 주의

- 부모 repo(`wadiz-jooyoul-lee/repos`) 는 git submodule 로 하위 repo 를 관리하지 **않습니다** (`.gitmodules` 없음). 각 repo 는 독립적으로 clone 되어 있으며, 이 인벤토리 문서가 clone URL 의 유일한 tracked 목록입니다.
- SSH URL 을 기준으로 작성되었습니다. HTTPS 를 선호하면 `git@github.com:` → `https://github.com/` 로 치환하십시오.
