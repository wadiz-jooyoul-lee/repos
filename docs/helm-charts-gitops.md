# helm-charts-gitops (wadiz-gitops/helm-charts)

> 와디즈 클라우드 배포의 **GitOps 상태 저장소**입니다. 차트나 템플릿은 없고 **values 파일만** 있습니다 — 각 서비스가 지금 어떤 이미지 태그로, 어떤 애플리케이션 설정(ConfigMap)으로 떠 있는지를 기록합니다.
> Org: `wadiz-gitops` (`https://github.com/wadiz-gitops/helm-charts.git`). 로컬 폴더명 `helm-charts-gitops`.

> 📅 분석 기준: 2026-09-01 clone, `main` 브랜치. 커밋 **13,079개**(2024-10-17 ~ 2026-08-31), 파일 373개.

> ⚠️ **이름이 같은 저장소가 둘입니다.** 차트 템플릿과 기본 values 는 [`helm-charts`](./helm-charts.md)(`wa-infrastructure/helm-charts`)에 있습니다. 아래 "두 저장소의 관계"를 먼저 보세요.

---

> 📅 **2026-09-03 main pull 보강** (77 커밋)
>
> 직전 보강과 마찬가지로 **대부분(약 77%)이 CI 자동 이미지 태그 갱신**입니다. 다만 이번에는 사람이 만든 구조 변경이 셋 있습니다.
>
> ### ⚠️ `rc1` · `odev` 환경 삭제
> - `values/{플랫폼}/rc1/` **57개 파일**이 통째로 삭제됐습니다(`87c3dbb18` "rc1 밸류 제거"). 짝이 되는 [`helm-charts`](./helm-charts.md) 에서도 같은 날 같은 57개가 지워졌습니다.
> - `core/odev/currency-exchange-api.yaml` 이 지워지면서 **`odev` 환경도 완전히 사라졌습니다**.
> - **현재 환경은 `clive` · `dev` · `rc4` 뿐입니다** (+ display-platform `stage` 1건). values 파일 **361 → 304개**.
>
> ### RWD-5996 — admin-server 의 AWS 액세스 키를 values 에서 제거
> - `web/{dev,rc4,clive}/admin-server.yaml` 세 파일에서 **평문 AWS access key / secret key 를 삭제**하고 **EKS IRSA**(파드에 IAM 역할을 직접 붙이는 방식) 주입으로 전환했습니다. 애플리케이션은 키가 비면 `DefaultCredentialsProvider` 로 넘어갑니다. RWD-5920(`store-api`·`store-batch`)과 같은 방식입니다.
> - 커밋에 **선행 조건이 명시돼 있습니다** — IAM 정책 `eks-service-admin-server` 의 private 버킷 statement 에 `s3:DeleteObject` 를 추가해야 합니다. 현행 IAM 사용자에는 있지만 IRSA 역할에는 없어서, 먼저 반영하지 않으면 **서류 승인·반려 시 원본 삭제(move)가 AccessDenied** 로 실패합니다.
> - 이 문서가 앞서 기록한 "values 에 평문 자격증명이 들어 있다"는 관측이 실제로 정리되기 시작했습니다. **AWS 키가 남은 파일은 이제 `client/dev/makercenter-api.yaml` 1건**입니다(dev 환경).
>
> ### `clive/order-api` 추가
> - `core/clive/order-api.yaml` 이 새로 생겼습니다(`5ddc0ca73`). 소스는 `wadiz-service/io.wadiz.order` 이고, 같은 기간에 **환불 로직 일원화·OpenAPI 문서·힙/메타스페이스 예산(1Gi 기준)·플랫폼 토큰 정합** 커밋이 이어졌습니다. `live` 프로파일에서는 springdoc 을 끄도록 설정했습니다.
> - 반대로 [`helm-charts`](./helm-charts.md) 에는 `core/{dev,rc4}/order-api.yaml` 만 있고 clive 가 없어, **두 저장소의 서비스 집합이 어긋나 있습니다.**
>
> ### 기타 수동 커밋
> - `core-mcp` 의 configmap 이 6회 연속 수정됐고(DB 커넥션 오류 수정 포함), audit API 의 MongoDB URI 가 3회 수정됐습니다. 짧은 간격의 반복 수정이라 **설정을 맞춰 가는 중**으로 보입니다(추정).
> - `order-api` 의 connect-timeout 조정, RC4 환경의 키 prefix·프로파일 갱신.
>
> ---

> 📅 **2026-09-02 main pull 보강** (68 커밋)
>
> 예상대로 **거의 전부 CI 자동 이미지 태그 갱신**입니다(`[org/repo] {작성자} - Merge …` 형식). 문서에 반영할 구조 변경은 없습니다.
>
> - 갱신이 잦았던 소스 레포: `wadiz-tech/kr.wadiz.platform.{api,agent}.friendtalk`(워크플로 정규화 `feature/update_workflow_20260901183520` 반영), `wadiz-service/com.wadiz.store`(RWD-5974) 등.
> - 수동 커밋은 소수이며 개별 서비스 설정 조정입니다(예: `fix(ai-hub): 공유 도구 링크 로그인 복귀 수정`).
> - 짝이 되는 [`helm-charts`](./helm-charts.md) 에서 **`live`·`rc2` 서비스 values 가 삭제**돼, 두 저장소의 환경 집합이 이제 일치합니다(이 저장소에는 원래 `live`·`rc2` 가 없었습니다).
>
> ---
>
## 두 저장소의 관계

| | `wa-infrastructure/helm-charts` | `wadiz-gitops/helm-charts` (이 문서) |
|---|---|---|
| 문서 | [`helm-charts.md`](./helm-charts.md) | 이 문서 |
| 크기 | 590KB · 파일 535 · 커밋 376 | 10.9MB · 파일 373 · 커밋 **13,079** |
| 담는 것 | `Chart.yaml` · `templates/` 17개 · 기본 `values.yaml` · **배포 스펙**(이미지 리포지터리·리소스·라우팅·인가 규칙) | **이미지 태그(`imageVersion`)** · **애플리케이션 설정(`configmap.data`)** |
| 누가 고치나 | 사람 (커밋 제목 대부분 `small change`) | **CI 봇 `devops` 가 자동 갱신**(전체의 약 77%) |
| 이력 시작 | 2026-04-06 (클라우드 이관기) | 2024-10-17 |

두 저장소의 디렉터리 구조는 `charts/service/values/{플랫폼}/{환경}/{서비스}.yaml` 로 **동일**하고, 같은 서비스에 대해 **서로 겹치지 않는 내용**을 담습니다. 예: `display-platform/clive/friends-api.yaml`

```
wa-infrastructure 판                    wadiz-gitops 판 (이 저장소)
─────────────────────────────           ─────────────────────────────
appLabel: friends-api                   imageVersion: main-202608241952-a960c2b2
containerImage: …/friends-api           configmap:
containerPort: 9000                       data:
requestsMemory: 1Gi                         server: { port: 9000 }
virtualService: { subPath: friends }        search: { engine: opensearch }
template:                                   spring: { … }
  authPolicy: [ … ]                         user-api: { … }
```

> ⚠️ 두 저장소의 values 가 **실제로 어떤 순서로 합쳐지는지**는 어느 쪽 저장소에서도 확인할 수 없습니다. ArgoCD 의 multi-source Application 으로 두 repo 를 함께 참조한다고 보는 것이 자연스럽지만, 그 정의는 두 저장소 밖에 있습니다.

## 저장소 구조

```
charts/
├── service/values/{플랫폼}/{환경}/{서비스}.yaml   # 361개 — 배포 상태의 본체
└── infra/connect/                                # Kafka Connect 전용 별도 차트
    ├── Chart.yaml · values.yaml
    ├── templates/  (connect, connector, service, virtualservice, httproute, authz-policy 등)
    └── values/{플랫폼}/{환경}.yaml
```

- 서비스 values 파일 **361개**, 고유 서비스명 **111개**.
- `charts/infra/connect` 는 이 저장소에만 있는 **Kafka Connect 배포 차트**입니다(`wa-infrastructure` 판에는 없습니다). CDC 파이프라인 관련으로 보입니다.

## 환경 — 두 저장소가 다릅니다

| 저장소 | 환경 |
|---|---|
| `wadiz-gitops` (이 문서) | `clive` · `dev` · `rc1` · `rc4` · **`odev`**(core 만) · `stage`(display-platform 만) |
| `wa-infrastructure` | `clive` · `dev` · `rc1` · `rc4` · **`rc2`** · **`live`** · `stage` |

- 이 저장소에 **`live` 와 `rc2` 가 없습니다.** 즉 기존(온프레미스) 라이브는 이 GitOps 흐름을 타지 않습니다 — 클라우드로 옮겨간 환경만 여기서 관리됩니다.
- 반대로 **`odev`(old dev)** 는 이 저장소에만 있고 `core` 플랫폼에서만 씁니다.

## 플랫폼별 서비스 수 (clive 기준)

| 플랫폼 | clive 서비스 수 |
|---|---:|
| display-platform | 51 |
| core | 27 |
| backoffice | 10 |
| user-platform | 8 |
| client | 5 |
| web | 2 |
| sre | 1 |

display-platform 은 dev 47 · rc1 37 · rc4 47 · clive 51 · stage 1 로 `wa-infrastructure` 판과 수가 정확히 일치합니다(두 저장소가 같은 서비스 집합을 다룬다는 뜻).

## 커밋 패턴 — 대부분 CI 자동 갱신

| 유형 | 최근 2,000커밋 중 |
|---|---:|
| `[org/repo] {작성자} - Merge pull request …` (자동 이미지 태그 갱신) | 1,618 |
| Merge branch/remote-tracking | 41 |
| `feat:` / `chore:` / `fix:` 등 수동 | 55 |

- 최근 1년(2025-09-01~) 커밋 **8,735개 중 6,693개(77%)** 가 자동 갱신입니다. 작성자도 `devops` 봇이 1,067회로 압도적입니다.
- 자동 커밋 메시지에는 **`[org/repo]` 형태로 소스 저장소가 찍힙니다**(예: `[wadiz-service/com.wadiz.api.friends]`). 이 덕분에 **서비스 → 소스 레포 매핑과 배포 시점**을 이 저장소 이력만으로 역추적할 수 있습니다 — 어떤 서비스가 실제로 살아 움직이는지 판단할 때 가장 확실한 신호입니다.
- 갱신 주체는 각 소스 레포의 배포 워크플로가 호출하는 `wadiz-gitops/workflows-container-image-build-push` 의 `update_image_tag` 잡입니다. 대상 파일은 워크플로의 `value_file_path`(예: `display-platform/clive/friends-api.yaml`)로 지정됩니다.

## 이미지 태그 규약

`imageVersion` 값은 `{브랜치}-{yyyyMMddHHmm}-{커밋해시}` 형태입니다.

```yaml
imageVersion: main-202608241952-a960c2b2
```

브랜치 부분이 그 서비스의 **실제 배포 브랜치**를 알려줍니다(예: friends-api 는 `main` 이 아니라 소스 레포의 `master` 를 쓰지만 태그는 `main-` 으로 시작 — 워크플로 설정에 따르므로 태그 접두사만으로 단정하지 말고 소스 레포의 워크플로를 함께 확인하세요).

## 애플리케이션 설정 규약 (`configmap.data`)

서비스의 Spring 설정이 그대로 들어갑니다. 값은 두 종류의 치환자를 씁니다.

**① 공통 설정 참조 `${commonConfig.*}`** — 환경별 공통값을 가리킵니다. 사용 빈도 상위:

| 치환자 | 용도 | 빈도 |
|---|---|---:|
| `${commonConfig.rds.url}` | MySQL 접속 | 276 |
| `${commonConfig.docdb.uri}` | DocumentDB | 180 |
| `${commonConfig.cache.url}` / `.port` | Redis | 151 / 141 |
| `${commonConfig.rabbitmq.*}` | RabbitMQ 4종 | 127·127·93·93 |
| `${commonConfig.web-host.web}` | 웹 호스트 | 83 |
| `${commonConfig.service.user-api}` / `.startup-api` / `.funding-api` | 내부 서비스 주소 | 80·62·62 |

**② 시크릿 치환자 `${소문자_스네이크}`** — 비밀번호·토큰을 이름으로만 참조합니다.

```
${es_pw_backoffice_indexer}  ${mysql_wadiz_backoffice_dev_password}  ${merchant_key}
${funding_api_auth_token}    ${docdb_wadiz_platform_admin_dev_password}  ${toast_app_key}  …
```

주입 주체는 이 저장소 밖입니다(External Secrets·SealedSecrets 등 추정, 미확인).

## ⚠️ 주의: 치환자를 쓰지 않은 평문 값이 남아 있습니다

시크릿 치환자 규약이 있는데도 **일부 파일에는 값이 그대로 박혀 있습니다.**

- `Bearer` 뒤에 실제 토큰이 오는 파일 **13개**
- `password:` 에 치환자가 아닌 리터럴이 오는 줄 **31개**(`cancel-password`·`customer-id-password` 등 포함)

이 문서에는 값을 옮기지 않았습니다. 저장소 내용을 인용·공유할 때 딸려 나가지 않도록 주의하고, 치환자로 정리할 대상으로 볼 수 있습니다.

## 이 저장소를 읽는 실전 요령

- **"이 서비스 지금 쓰나?"** → 해당 values 파일의 최근 커밋 날짜를 봅니다. `git log -1 --format='%ci' -- charts/service/values/{플랫폼}/clive/{서비스}.yaml`
- **"이 서비스 소스 레포가 어디지?"** → 같은 파일의 커밋 메시지에서 `[org/repo]` 를 뽑습니다.
- **"운영에서 이 설정이 뭘로 떠 있지?"** → `configmap.data` 를 봅니다. 소스 레포의 `application.yml` 기본값이 아니라 **여기가 실제 운영값**입니다. (예: `friends-api` 는 소스 기본값이 `search.engine: elasticsearch` 인데 clive 에서는 `opensearch` 로 떠 있습니다.)

## 미확인 항목

- 두 helm-charts 저장소를 합치는 ArgoCD Application 정의의 위치와 `-f` 순서.
- 시크릿 치환자(`${es_pw_*}` 등)를 실제로 채우는 주체.
- `charts/infra/connect` 로 배포되는 Kafka Connect 클러스터·커넥터의 목록과 용도.
- `odev`(core 전용) 환경의 성격 — 이름상 old dev 로 보이나 근거는 미확인.
