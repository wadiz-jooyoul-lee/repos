# helm-charts (wa-infrastructure/helm-charts)

> 와디즈 마이크로서비스를 쿠버네티스에 배포하기 위한 **공용 Helm 차트 저장소**입니다. Org: `wa-infrastructure` (remote: `https://github.com/wa-infrastructure/helm-charts.git`).
> 차트는 `service` **하나뿐**이고, 109개 서비스가 이 차트 하나를 공유하면서 values 파일로만 동작을 달리합니다(2026-09-03 기준).
>
> ⚠️ **이름이 같은 저장소가 둘입니다.** 이미지 태그(`imageVersion`)와 애플리케이션 설정(`configmap.data`)은 이 저장소가 아니라 GitOps 저장소 [`helm-charts-gitops`](./helm-charts-gitops.md)(`wadiz-gitops/helm-charts`)에 있습니다. 이 문서는 **차트·템플릿·배포 스펙** 쪽만 다룹니다.

> 📅 분석 기준: 2026-08-27 `main` 브랜치(`21b9ba2`). 저장소 전체 535개 파일 중 467개가 서비스별 values 파일입니다.

---

> 📅 **2026-09-03 main pull 보강** (12 커밋)
>
> ### ⚠️ `rc1` 환경이 전 플랫폼에서 삭제됐습니다
> - 커밋 `5470844` **"rc1 밸류 제거"** 로 `values/{플랫폼}/rc1/` 디렉터리가 통째로 사라졌습니다(**57개 파일**, −1,505줄). 직전 동기화에서 `live`·`rc2` 가 지워진 데 이어진 정리입니다.
> - **이제 이 저장소의 환경은 `clive` · `dev` · `rc4` 세 개뿐입니다** (+ display-platform 만 `stage` 1건). 짝이 되는 [`helm-charts-gitops`](./helm-charts-gitops.md) 에서도 같은 날 rc1 57개 파일이 함께 지워져 두 저장소가 계속 맞물려 있습니다.
> - 최상위 환경 values `live.yaml`·`rc2.yaml` 에 이어 **`rc1.yaml` 도 참조하는 서비스 없이 남았습니다** — 고아 파일이 3개로 늘었습니다.
> - **`deep-link-bridge` 서비스가 저장소에서 사라졌습니다.** rc1 에만 values 가 있던 유일한 서비스였기 때문입니다(`client/rc1/deep-link-bridge.yaml`). 다른 환경에 없으므로 이 차트로는 더 이상 배포되지 않습니다.
> - 통계 재측정: 서비스 values **357 → 302개**, 고유 서비스명 **109개 유지**(deep-link-bridge 1개 삭제 · order-api 1개 신설).
>
> ### 신규 서비스 `order-api` 등록
> - `core/dev/order-api.yaml` · `core/rc4/order-api.yaml` 2건이 생겼습니다. 소스 저장소는 `wadiz-service/io.wadiz.order`(RWD-5804 — 환불 로직 일원화, OpenAPI/Swagger UI, jib 도입)입니다.
> - **`core/clive/order-api.yaml` 은 이 저장소에 아직 없고 [`helm-charts-gitops`](./helm-charts-gitops.md) 쪽에만 추가됐습니다.** 두 저장소의 서비스 집합이 어긋난 상태입니다.
>
> ### 차트 템플릿 변경 — 롤링 업데이트 전략과 종료 유예시간을 열었습니다
> - `templates/deployment.yaml` · `templates/rollout.yaml` 에 두 가지 선택 설정이 추가됐습니다(`2ae298d`).
>   - **`strategy.enabled`** — `maxSurge` · `maxUnavailable` 을 서비스별로 덮어쓸 수 있습니다.
>   - **`terminationGracePeriodSeconds`** — 파드 종료 유예시간을 지정할 수 있습니다.
> - 값을 주지 않으면 쿠버네티스 기본값(25%/25%, 30초)이 그대로 유지됩니다.
> - 첫 적용 대상은 **`funding-api`(dev·rc4·clive)** 로 `maxSurge=1` · `maxUnavailable=0` · `terminationGracePeriodSeconds=90` 입니다. 즉 배포 중 **가용 파드를 줄이지 않고**(unavailable 0) 한 개씩 늘려 교체하며, 종료 유예를 90초로 크게 늘렸습니다. 같은 서비스에 이미 걸려 있는 preStop 훅과 함께 무중단 배포를 노린 설정으로 읽힙니다.
> - 나머지 커밋은 제목이 전부 `small change` 이며, dev `web-server` 등 개별 values 조정입니다.
>
> ---

> 📅 **2026-09-02 main pull 보강** (12 커밋)
>
> ### ⚠️ `live`·`rc2` 환경의 서비스 values 가 전 플랫폼에서 삭제됐습니다
> - 커밋 `470f891` **"live, rc2 밸류 제거"** 로 `values/{플랫폼}/live/` 와 `values/{플랫폼}/rc2/` 디렉터리가 통째로 사라졌습니다(총 −3,429줄). 삭제 규모: display-platform live 38·rc2 38, core live 9·rc2 8, backoffice live 8·rc2 7, client live 5·rc2 3, user-platform live 2·rc2 2 등.
> - **이제 이 저장소의 환경은 [`helm-charts-gitops`](./helm-charts-gitops.md) 와 일치합니다** — `clive` · `dev` · `rc1` · `rc4` (+ display-platform 만 `stage`). 온프레미스 라이브(`live`)와 `rc2` 는 더 이상 이 차트로 관리되지 않습니다.
> - 다만 **최상위 환경 values 파일 `live.yaml`·`rc2.yaml` 은 남아 있습니다**(서비스 values 만 지워짐). 참조하는 서비스가 없어 사실상 고아 파일입니다.
> - 통계 재측정: 서비스 values **467 → 357개**, 고유 서비스명 **108 → 109개**.
>
> ### 기타
> - `d0c06e4` — clive `funding-api` 에 **preStop 적용**(2026-08-27 보강에서 추가한 훅의 첫 실사용).
> - `dfb3405` — **Prometheus 메트릭 Datadog 수집 목록 옵션** 추가.
> - rc4 `main2-api`·`share-api`, web rc4 `web-server` 등 개별 values 조정.
>
> ---
>
> 📅 **2026-08-27 main pull 보강** (39 커밋)
>
> 커밋 제목이 대부분 `small change` 라 제목만으로는 내용을 알 수 없어, 실제 diff 를 읽어 정리했습니다. 차트 템플릿 변경 3건과 values 대량 정리(74파일 수정, 2파일 삭제)입니다.
>
> ### 차트 템플릿 변경
> - **`preStop` 훅 추가** (`templates/_tpl_deployment.yaml:138-143`) — 컨테이너에 `lifecycle.preStop.exec` 로 `sleep {{ .Values.preStop.sleepSeconds }}` 를 겁니다. 파드 종료 시 Istio 가 엔드포인트에서 빼기 전에 들어온 요청이 끊기는 것을 막기 위한 유예입니다. 기본값은 `preStop.enabled: false` · `sleepSeconds: 5` (`values.yaml:96-98`).
> - **VirtualService CORS 를 `defaultAllowOrigins` + `allowOrigins` 2단으로 분리** (`templates/virtualservice.yaml:90-96`) — 두 목록을 각각 조건부로 렌더합니다. 차트 기본값에 있던 `allowOrigins: [regex: .*.wadiz.kr]` 을 **삭제**하고, 환경 values 가 `defaultAllowOrigins` 를 주는 구조로 바꿨습니다(예: `values/dev.yaml` 에 `exact: https://dev.wadiz.io`·`https://local.wadiz.io`). 목록이 비었을 때 빈 배열이 렌더돼 YAML 문법 오류가 나던 문제를 이 조건 분기로 해결했습니다(`4d2e2e9`).
> - **Rollout ConfigMap 키 오타 수정** (`templates/rollout.yaml:66,72`) — `configFromVolume` 마운트 시 참조하는 키를 `application-kubernetes.yml` → **`application-kubernetes.yaml`** 로 고쳤습니다(`7ea406c`).
>
> ### Datadog 환경 라벨 변경 (주의)
> - `values/clive.yaml` 의 `datadog.env` 가 `clive` → **`live`** 로, `values/live.yaml` 의 `datadog.env` 가 `live` → **`olive`** 로 바뀌었습니다. 즉 **Datadog 상에서 `live` 는 이제 클라우드 라이브(clive)를 가리키고, 기존 온프레미스 라이브는 `olive`(old live 로 추정)** 로 표기됩니다. 대시보드·모니터 필터를 이 기준으로 읽어야 합니다.
>
> ### 서비스 values 대량 정리
> - **AuthorizationPolicy 의 FE 허용 대역 확대** — 개별 `/24` 대역 나열(23줄 삭제)을 걷어내고 `0.0.0.0/0  # FE` 와 `"::/0"  # FE`(IPv6 포함)로 바꾼 파일이 24건입니다. 임시 대역 주석 `# wabiz dev nat, 임시, 오픈후 제거 FIXME` 14건도 함께 제거됐습니다.
> - **VirtualService URI 매치 규칙 정리** — 개별 URI 나열을 주석 처리(`# - uri:` 34건)하거나 `prefix: /api/internal/` 하나로 합쳤습니다(예: `core/clive/funding-api.yaml` 에서 `/api/internal/wishes/users/.+`·`/api/internal/story/response/.+` 등 6개 규칙 → `prefix: /api/internal/` 1개).
> - **서비스별 `allowOrigins` 를 환경 values 로 이관** — 서비스 파일에 박혀 있던 `exact: https://dev.wadiz.io`(18건)·`exact: https://local.wadiz.io`(12건)를 지우고 위의 `defaultAllowOrigins` 로 옮겼습니다.
> - 메모리 상향(`requestsMemory: 1.5Gi` 4건, `2Gi` 3건), `authPolicy` 신규 설정 3건.
> - **삭제**: `values/backoffice/dev/sobaek.yaml`, `values/backoffice/dev/taebaek.yaml` — dev 환경에서 두 서비스가 빠졌습니다(clive 에는 남아 있습니다).

---

## 개요

- 저장소 최상위에는 `charts/` 하나만 있고, 그 아래 차트도 **`service` 하나뿐**입니다 (`charts/service/`).
- 서비스마다 차트를 만들지 않고, **차트 1개 + values 파일 N개** 로 전 서비스를 배포합니다. 서비스별 차이(이미지·포트·메모리·라우팅·인가 규칙)는 전부 values 로 표현됩니다.
- 의존성은 Bitnami Common 라이브러리 차트 하나입니다 (`Chart.yaml`, `common` v2.13.3, `charts/common-2.13.3.tgz` 로 vendoring).
- 차트 버전 `0.1.0`, appVersion `1.0.0` — 둘 다 초기값 그대로이고 갱신되지 않습니다.

## 저장소 구조

```
charts/service/
├── Chart.yaml                  # name: service, dependencies: common 2.13.3
├── README.md                   # 저장소 자체 안내 (아래 "레포 README 와의 차이" 참조)
├── values.yaml                 # 전 서비스 공통 기본값 (115줄)
├── charts/common-2.13.3.tgz    # Bitnami common 서브차트
├── templates/                  # 쿠버네티스 리소스 템플릿 17개
└── values/
    ├── {env}.yaml              # 환경별 공통 오버라이드 — dev, rc1, rc2, rc4, clive, live, stage
    └── {platform}/{env}/
        ├── values.yaml         # 플랫폼×환경 공통 (대부분 0바이트 빈 파일)
        └── {service}.yaml      # 서비스별 오버라이드
```

- **플랫폼(팀) 7종**: `backoffice`, `client`, `core`, `display-platform`, `sre`, `user-platform`, `web`
- **환경 7종**: `dev`, `rc1`, `rc2`, `rc4`, `clive`, `live`, `stage`
- 플랫폼×환경 `values.yaml` 은 **39개 중 37개가 0바이트 빈 파일**입니다. 내용이 있는 것은 둘뿐입니다 — `client/live/values.yaml`(`replicas: 1`), `sre/rc1/values.yaml`(rc 프로파일·게이트웨이 호스트·CORS 전체 허용). 이 층은 사실상 쓰이지 않습니다.

> ⚠️ 이 저장소에는 `.github/` 나 ArgoCD Application 정의가 **없습니다**. 세 층(`values.yaml` → `values/{env}.yaml` → `values/{platform}/{env}/{service}.yaml`)이 디렉터리 구조상 그 순서로 덮어쓴다고 보는 것이 자연스럽지만, 조합을 실행하는 주체는 다른 곳에 있습니다.
>
> 여기에 더해 **네 번째 층이 다른 저장소에 있습니다.** `wadiz-gitops/helm-charts` 가 같은 경로 규약(`charts/service/values/{platform}/{env}/{service}.yaml`)으로 **이미지 태그(`imageVersion`)와 애플리케이션 설정(`configmap.data`)** 을 따로 관리합니다. 두 저장소는 같은 서비스에 대해 서로 겹치지 않는 내용을 담습니다 — 이 저장소는 *배포 스펙*(이미지 리포지터리·리소스·라우팅·인가), gitops 저장소는 *배포 상태*(무슨 태그로, 무슨 설정으로). 자세한 내용은 [`helm-charts-gitops.md`](./helm-charts-gitops.md) 를 보세요.

## 환경별 공통 설정 (`values/{env}.yaml`)

> ⚠️ **2026-09-02 갱신**: `live`·`rc2` 는 **서비스 values 가 전 플랫폼에서 삭제**됐습니다(커밋 `470f891`). 아래 표의 두 행은 최상위 `live.yaml`·`rc2.yaml` 파일이 남아 있어 기록을 유지하지만, **참조하는 서비스가 없는 고아 설정**입니다. 현행 환경은 `clive`·`dev`·`rc1`·`rc4`(+display-platform `stage`)입니다.

| 환경 | `gatewayHosts` | `activeProfiles` | `datadog.env` | `sbaLabel` | 비고 |
|---|---|---|---|---|---|
| `dev` | `api.dev.wadiz.io` | `dev` | `dev` | `dev` | CORS 기본 허용 `dev.wadiz.io`·`local.wadiz.io` |
| `rc1` | `rc-platform.wadizcorp.net` | `rc` | `rc` | `rc` | `allowOrigins` 로 rc·local·rc-account 허용 |
| `rc2` | `rc2-platform.wadizcorp.net` | `rc2` | `rc2` | `rc2` | |
| `rc4` | `api.rc4.wadiz.io` | `rc4` | `rc4` | `rc4` | |
| `clive` | `api.wadiz.io` | `clive` | **`live`** | `live` | `replicas: 2`, 모니터링 채널 `서비스_모니터링`, `MaxRAMPercentage: 60.0` |
| `live` | `platform.wadiz.kr` | `live` | **`olive`** | `live` | `replicas: 2`, 모니터링 채널 `서비스_모니터링` |
| `stage` | `stage-platform.wadiz.kr` | `stage` | `stage` | `stage` | 유일하게 4개 모드를 명시하나 **값이 차트 기본값과 완전히 동일**해 실질 효과가 없습니다 |

- 도메인이 환경에 따라 **`wadiz.io`(클라우드: dev·rc4·clive) 와 `wadizcorp.net`/`wadiz.kr`(기존: rc1·rc2·live·stage)** 로 갈립니다.
- `clive` 는 클라우드 라이브, `live` 는 기존(온프레미스) 라이브입니다. 위 "Datadog 환경 라벨 변경" 주의사항을 함께 보세요.
- GitOps 저장소(`wadiz-gitops/helm-charts`)에는 **`live`·`rc2` 가 없고 `odev` 가 있습니다.** 즉 기존 온프레미스 라이브는 GitOps 흐름을 타지 않고, 이 저장소에서만 관리됩니다.

## 플랫폼별 서비스 목록 (clive 기준)

`clive`(클라우드 라이브)에 정의된 서비스입니다. 고유 서비스명은 전체 **109개**, 서비스 values 파일은 **357개**입니다(2026-09-02 기준).

| 플랫폼 | 서비스 |
|---|---|
| **backoffice** (10) | `backoffice-api` `backoffice-file-api` `erp` `erp-scm-batch` `indexer-cdc01` `indexer-cdc02` `indexer-schedule` `salesforce` `sobaek` `taebaek` |
| **client** (5) | `app-api` `app-api-kr` `good-wave-anyone-can-challenge` `makercenter` `makercenter-api` |
| **core** (26) | `audit-api` `community-api` `content-profiler` `currency-exchange-api` `fep-agent` `fep-api` `fulfillment-agent` `fulfillment-api` `fulfillment-batch` `funding-api` `funding-batch` `funding-settlement-api` `global-api` `kr-payment-agent` `kr-payment-api` `nicepay-api` `nicepay-log-agent` `payment-batch` `point-api` `reward-api` `reward-batch` `reward-bridge-api` `settlement-orchestrator-api` `store-api` `store-batch` `wave-batch` |
| **display-platform** (51) | `alimtalk-agent` `alimtalk-api` `catalog-agent` `collection-api` `crm` `crm-agent` `crm-gateway-api` `display-agent` `file-api` `friends-api` `friends-api-service` `friendtalk-agent` `friendtalk-api` `inbox` `inbox-agent` `indexer-dokdo` `indexer-geojedo` `keyword-agent` `keyword-api` `mail-common-api` `mail-fast-api` `mail-log-agent` `mail-normal-api` `mail-ses-agent` `mail-toast-agent` `main1-api` `main1-api-opencrm` `main1-api-public-api` `main1-batch-agent` `main2-api` `main2-batch` `main2-batch-api` `main2-stream-agent` `noti-channel` `notification-api` `notification-log-agent` `platform-admin` `platform-admin-ui` `project-metric-api` `push-agent` `push-api` `push-read-api` `searcher-api` `searcher-api-service` `share-api` `sms-ad-agent` `sms-ad-api` `sms-agent` `sms-api` `user-activity-api` `wish-api` |
| **sre** (2) | `crypto-api` `service-admin` |
| **user-platform** (8) | `account-server` `indexer-startup` `link` `membership-api` `membership-batch` `startup-api` `startup-batch` `user-api` |
| **web** (2) | `admin-server` `web-server` |

**환경별 서비스 수**

| 플랫폼 | dev | rc1 | rc2 | rc4 | clive | live | stage |
|---|---:|---:|---:|---:|---:|---:|---:|
| backoffice | 8 | 7 | 6 | 7 | 10 | 7 | – |
| client | 7 | 2 | 2 | 3 | 5 | 4 | – |
| core | 26 | 9 | 7 | 26 | 26 | 8 | – |
| display-platform | 47 | 37 | 37 | 47 | 51 | 37 | 1 |
| sre | 2 | 1 | – | 1 | 2 | 1 | – |
| user-platform | 8 | 1 | 1 | 8 | 8 | 1 | – |
| web | 2 | – | – | 2 | 2 | – | – |

- `core`·`user-platform`·`web` 은 **clive/rc4/dev 에만 서비스가 갖춰져 있고 live(기존)에는 훨씬 적습니다** — 클라우드로 옮겨간 쪽에 무게가 실려 있음을 보여줍니다.
- `stage` 는 `display-platform` 1개뿐이라 사실상 거의 쓰이지 않습니다.
- clive 에는 없고 다른 환경에만 있는 서비스: `client` 의 `ai-hub`·`app-api-2`·`deep-link-bridge`·`makercenter-delegate`.

## 차트가 만드는 리소스와 실제 게이트 조건

`templates/` 17개 파일의 **최상위 조건을 직접 읽어** 정리한 것입니다. 조건이 중첩돼 있어 플래그 하나만 봐서는 판단할 수 없습니다.

| 리소스 | 템플릿 | 실제 렌더 조건 |
|---|---|---|
| Deployment | `deployment.yaml` (+`_tpl_deployment.yaml` 284줄) | `template.deployment.enabled` |
| Service | `service.yaml` | `type == "api"` **AND** `template.service.enabled` |
| VirtualService | `virtualservice.yaml` | `ingressMode` **AND** `type == "api"` **AND** `template.virtualservice.enabled` |
| VirtualService(delegate) | `virtualservice-delegate.yaml` | `ingressMode` **AND** `template.virtualserviceDelegate.enabled` |
| DestinationRule | `destinationrule.yaml` | `ingressMode` **AND** `type == "api"` **AND** `template.destinationrule.enabled` |
| AuthorizationPolicy | `authz-policy.yaml` | `ambientMode` **AND** `template.authPolicy` 가 비어 있지 않을 것 |
| AuthorizationPolicy(sidecar) | `authz-policy-sidecar-mode.yaml` | `sidecarMode` (규칙은 `template.authPolicy` 를 순회해 생성) |
| HTTPRoute (Gateway API) | `httproute.yaml` | `gatewayMode` **AND** `type == "api"` **AND** `template.httproute.enabled` |
| ConfigMap | `configmap.yaml` | `template.configmap.enabled` |
| HPA | `hpa.yaml` | `template.hpa.enabled` |
| Rollout (Argo Canary) | `rollout.yaml` | `template.rollout.enabled` |
| CronJob / Job | `cronjob.yaml` / `job.yaml` | `template.cronjob.enabled` / `template.job.enabled` |
| StatefulSet | `statefulset.yaml` | `template.statefulset.enabled` |
| PVC | `pvc.yaml` | `template.pvc.enabled` |
| EnvoyFilter(헤더 주입) | `envoyfilter-header-injection.yaml` | `template.envoyFilterHeaderInjection.enabled` |

**꼭 알아둘 동작 2가지**

- `template.authzPolicy.enabled` 라는 값이 `values.yaml` 에 있지만, **AuthorizationPolicy 렌더 조건에는 쓰이지 않습니다.** 실제 게이트는 `ambientMode` 와 `template.authPolicy`(규칙 목록) 두 개입니다. 즉 규칙 목록을 비워 두면 `authzPolicy.enabled: true` 여도 리소스가 생기지 않습니다.
- Deployment 는 **HPA 가 켜져 있으면 `replicas` 를 아예 렌더하지 않습니다** (`deployment.yaml:7-9`). HPA 와 `replicas` 를 같이 적어도 `replicas` 는 무시됩니다.

## 서비스 타입(`type`)의 실제 의미

`type` 은 `api`(기본)와 `agent` 두 값을 씁니다. 실측 분포는 `agent` **129개**, 미지정(=`api`) **338개** 입니다.

- `type` 이 실제로 가르는 것은 **인바운드 라우팅 3종**(Service·VirtualService·DestinationRule)뿐입니다. `agent` 면 이 셋이 만들어지지 않습니다.
- **`agent` 라고 해서 Deployment 가 꺼지지는 않습니다.** Deployment 게이트는 `template.deployment.enabled` 하나이고 기본값이 `true` 이므로, `type: agent` 만 적은 서비스는 여전히 Deployment 로 상주합니다. 예: `values/display-platform/live/push-agent.yaml` 은 `type: agent` + HPA(min/max 2)만 지정하고 Deployment 를 끄지 않습니다 — 즉 "인바운드 없는 상주 워커"입니다.

## 실사용 통계 (values 실측 — 아래 수치는 467개 시점 기준, `live`·`rc2` 삭제 전)

| 항목 | 건수 | 메모 |
|---|---:|---|
| `type: agent` | 129 | 나머지 338개는 미지정(=api) |
| `template.deployment.enabled: false` | 49 | 대부분 StatefulSet·Job 계열로 대체 |
| `template.service.enabled: false` | 40 | |
| `template.destinationrule.enabled: false` | 40 | |
| `template.virtualservice.enabled: false` | 27 | |
| `template.configmap.enabled: false` | 14 | |
| `template.statefulset.enabled: true` | 9 | |
| `template.hpa.enabled: true` | 9 | 별도로 `false` 명시 2건 |
| `template.authPolicy` 설정 | 209 | 절반 가까운 서비스가 인가 규칙을 둠 |
| `template.rollout.enabled: true` | **0** | `false` 명시만 2건 |
| `template.cronjob.enabled` | **0** | 어느 서비스도 쓰지 않음 |

- **차트에 구현돼 있으나 실제로는 아무도 쓰지 않는 기능이 4가지**입니다. 기능 소개만 보고 "쓰고 있다"고 판단하면 안 됩니다.
  - **Canary(Argo Rollout)** — `rollout.enabled: true` 0건(`false` 명시만 2건)
  - **CronJob** — `cronjob.enabled` 설정 0건
  - **Istio sidecar 모드** — `sidecarMode` 를 `true` 로 둔 곳이 values 전체에 **0건**이라 `authz-policy-sidecar-mode.yaml` 은 렌더된 적이 없습니다
  - **Gateway API(HTTPRoute)** — `gatewayMode` 를 `true` 로 둔 곳도 **0건**이라 `httproute.yaml` 역시 렌더되지 않습니다
- 4개 네트워킹 모드(`ambientMode`·`sidecarMode`·`ingressMode`·`gatewayMode`)를 **서비스 values 에서 덮어쓰는 곳은 한 군데도 없습니다.** 전 서비스가 차트 기본값(ambient + ingress)으로만 돕니다.
- 컨테이너 이미지 ECR 레지스트리는 **`843734097580`(클라우드 계열)** 과 **`393290902814`(기존 계열)** 두 계정으로 갈립니다. 리포지터리 네임스페이스는 `platform`·`core`·`notification`·`display-platform`·`backoffice` 등입니다.

## ⚠️ 주의: values 에 평문 자격증명이 들어 있습니다

서비스 values 파일에 **Bearer 토큰·API 키·JWT 가 평문으로 커밋돼 있습니다**(`Bearer ` 문자열을 포함한 파일 52개). Istio AuthorizationPolicy 의 `when.key: request.headers[Authorization]` 조건과 VirtualService 헤더 주입에 쓰입니다.

- 이 문서에는 값을 옮기지 않았습니다. **이 저장소 내용을 인용하거나 공유할 때 토큰 값이 딸려 나가지 않도록 주의하세요.**
- 값 자체가 필요하면 저장소를 직접 보고, 외부(문서·티켓·메신저)로는 옮기지 않는 것이 안전합니다.

## 레포 README 와의 차이

저장소에 `charts/service/README.md`(132줄)가 이미 있습니다. 다만 아래 항목은 현재 코드와 어긋나므로, 이 문서를 우선으로 보세요.

| README 서술 | 실제 |
|---|---|
| "총 서비스 수: 305개" | 서비스 values 파일 **357개**, 고유 서비스명 **109개** (2026-09-02 기준. `live`·`rc2` 삭제 전에는 467/108). 305 는 어느 쪽과도 맞지 않습니다 |
| `agent` = "Deployment 비활성화, Job/CronJob 사용" | `type` 은 Deployment 를 끄지 않습니다. 인바운드 3종만 끕니다. CronJob 사용처는 0건입니다 |
| Service 는 `template.service.enabled` 로 제어 | `type == "api"` 조건이 먼저 걸립니다 |
| VirtualService/DestinationRule 은 `template.*.enabled` 로 제어 | `ingressMode` 와 `type == "api"` 가 함께 걸립니다 |
| AuthorizationPolicy 는 `template.authzPolicy.enabled` | 실제 게이트는 `ambientMode` + `template.authPolicy` 목록입니다 |
| 예시 파일 `values/core/live/funding-api.yaml` | `core/live` 에 그 파일은 없습니다(`core/clive` 에 있습니다). 예시는 실재 파일이 아닙니다 |
| `datadog.monitoring.channel` 기본 `dev_cloud_monitoring` | 차트 기본값은 맞으나, `clive`·`live`·`stage` 는 `서비스_모니터링` 으로 덮어씁니다 |

## 미확인 항목

- 배포를 실행하는 주체(ArgoCD Application, CI 워크플로)와 values 조합 순서 — 이 저장소 밖입니다.
- ~~`imageVersion` 값이 어디서 주입되는지~~ → **해소(2026-09-01)**: 템플릿은 `{{ .Values.containerImage }}:{{ .Values.imageVersion }}` 로 참조하지만(`_tpl_deployment.yaml:136`, `_tpl_job.yaml:11`) 이 저장소의 467개 values 파일 어디에도 `imageVersion` 이 없습니다. 값은 **`wadiz-gitops/helm-charts` 의 같은 경로 values 파일**에 있고(예: `imageVersion: main-202608241952-a960c2b2`), 각 서비스 배포 워크플로가 호출하는 `wadiz-gitops/workflows-container-image-build-push` 의 `update_image_tag` 잡이 자동 갱신합니다.
- `sobaek`·`taebaek`·`geojedo`·`dokdo` 같은 지명 코드네임 서비스의 역할 — 차트에는 이미지·포트만 있어 용도를 알 수 없습니다.
