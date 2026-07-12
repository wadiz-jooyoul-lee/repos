# Wadiz Repos — Clone URL 인벤토리

부모 repo(`wadiz-jooyoul-lee/repos`) 하위 32개 Wadiz repo 의 clone URL 목록입니다. 새 팀원 온보딩·환경 재구축·조직 이동 시 참조하십시오.

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
