# Flow: 위시(Wish) — 펀딩·스토어 공통

> 프로젝트 찜하기 기능. **펀딩/스토어 모두 동일 엔드포인트** 를 `projectType` 필드로 분기. 서포터 서명과 달리 단순 즐겨찾기 성격.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/funding/wishes.service.ts:22-30`
  - `kr.wadiz.user.link/.../kafka/KafkaUserWishProjectConsumer.java` (Kafka 구독자)
- **외부 경계**: 위시 원장이 저장되는 서비스(com.wadiz.api.funding 또는 별도) 구체 — 본 레포에서는 `KafkaUserWishProjectConsumer` 가 이벤트를 구독하여 Neo4j 에 `:WISH` 관계로 적재한다는 사실만 확인.

---

## 1. Client Trigger (FE)

### 1.1 단일 API (`packages/api/src/web/funding/wishes.service.ts`)
```ts
export interface WishesRequest {
  projectType: 'FUNDING' | 'STORE' | ...;
  projectNo: number;
  sourceType?: 'WISH' | null;
}

export const postWish = (params: WishesRequest) =>
  POST<WishesRequest, Response<WishesResponse>>('/web/apip/funding/wishes', params);   // :22

export const deleteWish = ({ projectType, projectNo }) =>
  DELETE(`/web/apip/funding/wishes?projectType=${projectType}&projectNo=${projectNo}`);  // :29
```
네임스페이스가 `funding/wishes` 이지만 `projectType` 으로 스토어 포함 모든 프로젝트 타입을 커버.

### 1.2 UI 트리거
- 프로젝트 카드/상세의 하트 아이콘 토글
- 로그인 필요 (비로그인 시 로그인 리다이렉트)

## 2. Hub — `com.wadiz.web`
`/web/apip/funding/wishes` 는 **ApiProxyServlet** 투명 프록시 → `com.wadiz.api.funding` 의 Wish 컨트롤러로 직행.

## 3. Backend — `com.wadiz.api.funding`

### 3.1 컨트롤러 (추정)
funding 서비스 내 `/api/wishes` 엔드포인트로 도달. 상세는 [docs/com.wadiz.api.funding/](../com.wadiz.api.funding/) Phase 2 문서 (campaign/public 또는 별도 wishes 섹션) 참조.

### 3.2 데이터 처리
1. INSERT/DELETE `UserWishProject` 테이블 (추정 컬럼: userId, projectNo, projectType, createdAt)
2. **Kafka 이벤트 발행**: `user-wish-project` 토픽 (또는 유사)
3. Campaign/StoreProject 의 wishCount 증가·감소 집계 (배치 or 즉시)

## 4. Event Fan-out — Kafka

### 4.1 `kr.wadiz.user.link` 가 구독
```java
// kr.wadiz.user.link/.../kafka/KafkaUserWishProjectConsumer.java
// 관측: KafkaUserWishProjectConsumer 존재 (kr.wadiz.user.link.md 참조)
```
→ Neo4j 그래프에 `:WISH` 관계 INSERT/DELETE (User → Project)
→ 이후 추천 쿼리에서 팔로우·위시 기반 추천에 활용

### 4.2 추가 구독자 (추정)
- `com.wadiz.api.funding` 내부 집계 (캠페인 위시수)
- 푸시·알림 시스템 (리워드 오픈일 임박 알림 등)
- 만료/마감 알림 배치 (funding batch: `WishProjectDeadlineNotificationJob` — com.wadiz.api.funding 배치 모듈에 관측)

## 5. DB

| 저장소 | 저장 데이터 | 역할 |
|---|---|---|
| `com.wadiz.api.funding` MySQL | `UserWishProject(userId, projectNo, projectType, createdAt)` | 원장 |
| `kr.wadiz.user.link` Neo4j | `(User)-[:WISH]->(Project)` 관계 | 추천·소셜 |

## 엔드투엔드 시퀀스

### 위시 등록
```
[FE: 하트 클릭]
   │ POST /web/apip/funding/wishes
   │   body: { projectType: 'FUNDING', projectNo: 12345 }
   ▼
[www.wadiz.kr — ApiProxyServlet 투명 프록시]
   ▼
[com.wadiz.api.funding — Wish 컨트롤러 (/api/wishes)]
   │
   ├─ INSERT INTO UserWishProject (userId, projectNo, projectType, createdAt)
   ├─ (옵션) UPDATE Campaign/StoreProject SET WishCount = WishCount + 1  (또는 배치)
   └─ Kafka publish: { event: 'WISH_ADDED', userId, projectNo, projectType }

[Kafka Consumers]
   ├─ kr.wadiz.user.link.KafkaUserWishProjectConsumer
   │    └─ MERGE (u:User {id: $userId}) -[:WISH {at: $ts}]-> (p:Project {id: $projectNo})
   │
   └─ (추정) 기타 구독자 — 리워드 오픈 알림 대상 등록

   → FE: 하트 상태 토글
```

### 위시 해제
```
[FE: 하트 다시 클릭]
   │ DELETE /web/apip/funding/wishes?projectType=FUNDING&projectNo=12345
   ▼
[com.wadiz.api.funding]
   ├─ DELETE FROM UserWishProject WHERE ...
   └─ Kafka publish: WISH_REMOVED

[Kafka]
   └─ user.link: MATCH (u)-[w:WISH]->(p) WHERE u.id=? AND p.id=? DELETE w
```

### 마감일 알림 배치 (오픈예정 위시)
```
[funding 배치: WishProjectDeadlineNotificationJob (매일)]
   │ SELECT 위시 달린 프로젝트 중 곧 오픈·마감 도래
   ▼
[알림 서비스 호출 (platform notification)]
   └─ 푸시·이메일 발송: "찜하신 프로젝트가 3일 후 마감됩니다"
```

## 경계·미탐색
1. **위시 저장소 소유 서비스** — `com.wadiz.api.funding` 내 Wish 컨트롤러 존재 여부 Phase 2 문서에서 확인 필요. 또는 별도 wishes 서비스 가능성.
2. **스토어 전용 처리** — `projectType='STORE'` 일 때도 동일 테이블인지, Store API 의 별도 Wishlist 인지 경계 불명. `kr.wadiz.user.link` 의 Store Consumer(`KafkaStoreWishItemConsumer`) 는 별도로 존재.
3. **WishCount 집계 타이밍** — 즉시 트랜잭션 vs 배치. 동시성 경합 방지 로직.
4. **Kafka 토픽 이름** — consumer 이름은 관측되나 실제 topic 명은 wave/funding 측 publish 코드 추적 필요.
5. **리워드 오픈 알림 대상 등록** — `CampaignWishItem` 과 `KafkaCampaignWishItemConsumer` (kr.wadiz.user.link 관측) 관계.
