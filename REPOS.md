# Wadiz Repos 명세서 (git 주소)

이 문서는 `~/work/repos` 하위에 두는 각 저장소의 **폴더명 ↔ git 주소 ↔ GitHub org** 정본(source of truth)입니다.
`repos-setup` 스킬(mentis-docs 플러그인)이 이 표를 읽어 **없으면 clone, 있으면 pull** 로 구조를 구성합니다.

- **폴더명**은 clone 시 생성될 로컬 폴더명입니다(레포명과 다를 수 있어 명시 — 예: QA 레포).
- 스킬은 `Git 주소` 칸에 `github.com`이 포함된 행만 대상으로 파싱합니다(헤더/구분선은 자동 제외).
- 갱신 기준: 2026-07-20 (로컬 remote 수집값).

## 저장소 목록

| 폴더 | Git 주소 | Org |
|---|---|---|
| com.wadiz.api.funding | https://github.com/wadiz-service/com.wadiz.api.funding.git | wadiz-service |
| com.wadiz.api.reward | https://github.com/wadiz-service/com.wadiz.api.reward.git | wadiz-service |
| com.wadiz.api.startup | https://github.com/wadiz-service/com.wadiz.api.startup.git | wadiz-service |
| co.wadiz.api.community | https://github.com/wadiz-service/co.wadiz.api.community.git | wadiz-service |
| com.wadiz.api.friends | https://github.com/wadiz-service/com.wadiz.api.friends.git | wadiz-service |
| com.wadiz.store | https://github.com/wadiz-service/com.wadiz.store.git | wadiz-service |
| com.wadiz.startup.batch | https://github.com/wadiz-batch/com.wadiz.startup.batch.git | wadiz-batch |
| kr.wadiz.backoffice.api | https://github.com/wadiz-backoffice/kr.wadiz.backoffice.api.git | wadiz-backoffice |
| kr.wadiz.backoffice.indexer-cdc | https://github.com/wadiz-backoffice/kr.wadiz.backoffice.indexer-cdc.git | wadiz-backoffice |
| kr.wadiz.backoffice.indexer-schedule | https://github.com/wadiz-backoffice/kr.wadiz.backoffice.indexer-schedule.git | wadiz-backoffice |
| helm-charts-gitops | https://github.com/wadiz-gitops/helm-charts.git | wadiz-gitops |
| platform-admin | https://github.com/wadiz-tech/platform-admin.git | wadiz-tech |
| display-agent | https://github.com/wadiz-tech/display-agent.git | wadiz-tech |
| mail-normal-api | https://github.com/wadiz-tech/mail-normal-api.git | wadiz-tech |
| mail-common-api | https://github.com/wadiz-tech/mail-common-api.git | wadiz-tech |
| notification-log-agent | https://github.com/wadiz-tech/notification-log-agent.git | wadiz-tech |
| main2-batch-api | https://github.com/wadiz-tech/main2-batch-api.git | wadiz-tech |
| main2-api | https://github.com/wadiz-tech/main2-api.git | wadiz-tech |
| kr.wadiz.platform.inbox | https://github.com/wadiz-tech/kr.wadiz.platform.inbox.git | wadiz-tech |
| kr.wadiz.platform.crm | https://github.com/wadiz-tech/kr.wadiz.platform.crm.git | wadiz-tech |
| inbox-agent | https://github.com/wadiz-tech/inbox-agent.git | wadiz-tech |
| mail-fast-api | https://github.com/wadiz-tech/mail-fast-api.git | wadiz-tech |
| kr.wadiz.platform.api.friendtalk | https://github.com/wadiz-tech/kr.wadiz.platform.api.friendtalk.git | wadiz-tech |
| wish-api | https://github.com/wadiz-tech/wish-api.git | wadiz-tech |
| keyword | https://github.com/wadiz-tech/keyword.git | wadiz-tech |
| main2-stream-agent | https://github.com/wadiz-tech/main2-stream-agent.git | wadiz-tech |
| push-api | https://github.com/wadiz-tech/push-api.git | wadiz-tech |
| user-activity-api | https://github.com/wadiz-tech/user-activity-api.git | wadiz-tech |
| com.wadiz.search.indexer-dokdo | https://github.com/wadiz-search/com.wadiz.search.indexer-dokdo.git | wadiz-search |
| com.wadiz.search.indexer-geojedo | https://github.com/wadiz-search/com.wadiz.search.indexer-geojedo.git | wadiz-search |
| main2-batch | https://github.com/wadiz-batch/main2-batch.git | wadiz-batch |
| com.wadiz.wave.statistics | https://github.com/wadiz-batch/com.wadiz.wave.statistics.git | wadiz-batch |
| kr.wadiz.catalogagent | https://github.com/wadiz-service/kr.wadiz.catalogagent.git | wadiz-service |
| com.wadiz.api.main | https://github.com/wadiz-service/com.wadiz.api.main.git | wadiz-service |
| co.wadiz.currency-exchange | https://github.com/wadiz-service/co.wadiz.currency-exchange.git | wadiz-service |
| co.wadiz.fep | https://github.com/wadiz-service/co.wadiz.fep.git | wadiz-service |
| nicepay-api | https://github.com/wadiz-service/nicepay-api.git | wadiz-service |
| kr.wadiz.account | https://github.com/wadiz-service/kr.wadiz.account.git | wadiz-service |
| kr.wadiz.user.link | https://github.com/wadiz-service/kr.wadiz.user.link.git | wadiz-service |
| com.wadiz.wave.searcher | https://github.com/wadiz-service/com.wadiz.wave.searcher.git | wadiz-service |
| com.wadiz.wave.user | https://github.com/wadiz-service/com.wadiz.wave.user.git | wadiz-service |
| app-api | https://github.com/wadiz-client/app-api.git | wadiz-client |
| makercenter-be | https://github.com/wadiz-client/makercenter-be.git | wadiz-client |
| makercenter-fe | https://github.com/wadiz-client/makercenter-fe.git | wadiz-client |
| makercenter-fe-admin | https://github.com/wadiz-client/makercenter-fe-admin.git | wadiz-client |
| client-document | https://github.com/wadiz-client/client-document.git | wadiz-client |
| figma-icon-sync | https://github.com/wadiz-client/figma-icon-sync.git | wadiz-client |
| wadiz-claude-plugins | https://github.com/wadiz-client/wadiz-claude-plugins.git | wadiz-client |
| wadiz-frontend | https://github.com/wadiz-fe/wadiz-frontend.git | wadiz-fe |
| good-wave | https://github.com/wadiz-fe/good-wave.git | wadiz-fe |
| com.wadiz.web | https://github.com/wadiz-web/com.wadiz.web.git | wadiz-web |
| com.wadiz.adm | https://github.com/wadiz-web/com.wadiz.adm.git | wadiz-web |
| co.wadiz.adm | https://github.com/wadiz-web/co.wadiz.adm.git | wadiz-web |
| com.wadiz.embed | https://github.com/wadiz-web/com.wadiz.embed.git | wadiz-web |
| com.wadiz.wtp.admin | https://github.com/wadiz-web/com.wadiz.wtp.admin.git | wadiz-web |
| wadiz-android | https://github.com/wadiz-app/wadiz-android.git | wadiz-app |
| wadiz-ios | https://github.com/wadiz-app/wadiz-ios.git | wadiz-app |
| custom-image-dockerfiles | https://github.com/wa-infrastructure/custom-image-dockerfiles.git | wa-infrastructure |
| helm-charts | https://github.com/wa-infrastructure/helm-charts.git | wa-infrastructure |
| web-test-automation | https://github.com/wadiz-qa/web-test-automation.git | wadiz-qa |
| web-test-automation-global | https://github.com/wadiz-qa/web-test-automation-global.git | wadiz-qa |

## 제외 (clone/pull 대상 아님)

| 폴더 | 이유 |
|---|---|
| docs | 이 `repos` 저장소(`wadiz-jooyoul-lee/repos.git`) 자체의 하위 폴더. 별도 clone 대상 아님 |
| walink | 로컬 전용 폴더(원격 없음, git 저장소 아님) |
| execute_all | 스크립트 파일(폴더 아님) |

> 폴더명이 레포명과 다른 케이스: `web-test-automation`(구 `Regression`), `web-test-automation-global`(구 `Global-Regression-by-Claude`). 이 표의 폴더명 기준으로 clone 됩니다.

> **2026-09-01 추가**: display-platform(전시플랫폼) 팀 저장소 23개를 신규 등록했습니다(`wadiz-tech`·`wadiz-search`·`wadiz-batch`·`wadiz-service`). 기본 브랜치 마지막 커밋이 2026-06-19~06-04 구간에 몰린 `wadiz-tech` 레포 18개와 `com.wadiz.wave.notification`·`com.wadiz.crmgateway` 는 이번 범위에서 제외했습니다.
> `helm-charts` 는 **이름이 같은 저장소가 둘**입니다 — `wa-infrastructure/helm-charts`(차트·템플릿, 폴더 `helm-charts`)와 `wadiz-gitops/helm-charts`(GitOps 배포 상태, 폴더 `helm-charts-gitops`). 폴더명으로 구분합니다.
