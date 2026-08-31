# com.wadiz.search.indexer-geojedo 분석 문서

> 와디즈 **친구·피드 색인기**입니다. 회원·팔로우·서포터 활동 피드·리액션·푸시 이력을 색인해 친구 서비스([`com.wadiz.api.friends`](./com.wadiz.api.friends.md))가 읽는 인덱스를 만듭니다.
> Org: `wadiz-search` (`https://github.com/wadiz-search/com.wadiz.search.indexer-geojedo.git`). 배포 이름 `indexer-geojedo`, 플랫폼 `display-platform`.

> 📅 분석 기준: 2026-09-01, **`master` 브랜치**(`e26ac9b`, 2026-08-22). Java 155개. README 없음.

---

## dokdo 와 geojedo 의 역할 분담 — 인덱스로 갈립니다

이름이 지명 코드네임이라 역할을 알 수 없었는데, **각자 다루는 인덱스 이름으로 확인됐습니다.**

| | [**indexer-dokdo**](./com.wadiz.search.indexer-dokdo.md) | **indexer-geojedo** (이 문서) |
|---|---|---|
| 성격 | **검색·전시 카탈로그 색인** | **친구·피드 색인** |
| 주요 인덱스 | `reward_project` · `store_project` · `integrate_search` · `funding_category` · `store_category` · `maker_hashtag_alternative` · `supporter_hashtag_alternative` | `integrate_feeds` · `supporter_activity_feeds` · `maker_activity_feeds` · `last_entered_feeds` · `push_history_feeds` |
| 소비처 | [`com.wadiz.wave.searcher`](./com.wadiz.wave.searcher.md) (검색 서버) | [`com.wadiz.api.friends`](./com.wadiz.api.friends.md) (친구 서비스) |
| 기준 브랜치 | `main` | **`master`** |
| Java 파일 | 173 | 155 |
| 메모리(clive) | 2Gi | **4Gi** (display-platform 최대) |
| 컨트롤러 | 2개 · EP 12 (수동 색인 6 + 검색홈 6) | 1개 · **EP 1** |

> ✅ 이 대조로 **친구 서비스 문서의 미확인 항목("누가 `integrate_feeds` 인덱스에 색인하는지")이 해소**됩니다 — geojedo 입니다. `com.wadiz.api.friends` 는 조회와 `last_entered`·`push_history` 색인만 하고, 나머지 피드 인덱스는 geojedo 가 채웁니다.

## 구조

```
com/wadiz/search/indexer/geojedo/
├── service/     65  ← 색인 로직 본체
├── model/       37
├── repository/  19
├── config/      11  ← 검색엔진 구성
├── schedule/    10  ← 스케줄러
├── client/       5
├── util/         4
├── controller/   1
├── listener/     1
└── analyzer/     1
```

dokdo 와 계층 구조가 거의 같습니다(`service`/`model`/`repository`/`config`/`schedule`). 형제 프로젝트로 만들어진 것으로 보입니다.

## 색인 스케줄러 14종

`@Scheduled` 14개 이상이며, dokdo 와 마찬가지로 **주기·cron 을 전부 설정(`index.scheduler.*`)으로 뺐습니다.**

| 묶음 | 설정 키 |
|---|---|
| **회원(user)** | `user.create` · `user.create-all` · `user.change-status` · `user.update-profile` · `user.update-membership` · `user.update-dvcSession` |
| **통합 피드** | `integrate-feed.follow` · `integrate-feed.follow-status` |
| **피드** | `feed.last-entered` · `feed.push-history` |
| **리액션** | `reaction.reaction-all` · `reaction.reaction-part` |
| **서포터 활동 피드** | `supporter-activity-feed.feed-all` · `supporter-activity-feed.feed` |

- `-all` / `-part`·증분 쌍이 반복되는 패턴입니다 — **전량 재색인과 증분 색인을 분리**해 운영합니다.
- 이벤트 소비: `listener/` 1개.

## API 엔드포인트

| 컨트롤러 | base | EP | 용도 |
|---|---|---:|---|
| `IndexingTriggerController` | `/api/admin/indexing` | 1 | 색인 수동 트리거 |

- dokdo(12개)와 달리 **엔드포인트가 1개뿐**입니다. 거의 순수 배치성 서비스입니다.
- 경로에 `/admin/` 이 들어가 있어 dokdo 의 `/api/indexing/manual` 보다 의도가 명확합니다.

## 배포

| 환경 | 트리거 브랜치 | 갱신 대상 values |
|---|---|---|
| **clive** | **`master`** | `display-platform/clive/indexer-geojedo.yaml` |

- `cloud_live`·`clive` 브랜치가 없고 `master` 가 현행선입니다.
- helm values: `type: api` · `requestsMemory: **4Gi**` — display-platform 51개 서비스 중 가장 큽니다. 전량 재색인 배치 때문으로 보입니다(추정).

## 최근 변경

- 2026-08-22 `hotfix/v20260821` 머지가 최신입니다. 90일 커밋 19개로 dokdo(32개)보다 조용합니다.

## 미확인 항목

- **OpenSearch 이관 상태** — dokdo 는 2026-07 부터 활발히 이관 중인데 geojedo 도 같은 작업을 하는지 확인하지 못했습니다.
- 지명 코드네임(`dokdo`·`geojedo`)의 명명 규칙 — 다른 색인기가 더 있는지.
- `listener/` 가 소비하는 이벤트 소스.
- clive 실제 운영 설정 — [`helm-charts-gitops`](./helm-charts-gitops.md) 의 `display-platform/clive/indexer-geojedo.yaml` 참조.
- README 가 없어 저장소 안에 참고 문서가 없습니다(dokdo 도 동일).
