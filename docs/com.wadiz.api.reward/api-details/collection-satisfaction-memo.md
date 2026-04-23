# Collection / Satisfaction / Memo 상세 스펙

> **기록 범위**
>
> - `com.wadiz.api.reward` 레포 안에서 직접 관측 가능한 5개 컨트롤러(`reward-api/src/main/java/com/wadiz/api/reward/rest/{collection,satisfaction,memo}/`)와
>   그 뒤에 위치한 Service / Repository / JPA Entity / MyBatis XML(`src/main/resources/mapper/reward/satisfaction/satisfaction-aggregate-mapper.xml`)만을 근거로 작성.
> - DTO/Request/Response · Enum(`SatisfactionItem`, `SatisfactionRequestAction`, `CollectionType` 등)은 본 레포에 소스가 없으며, Gradle `wadiz.gradle`
>   선언에 따라 외부 jar **`com.wadiz.api.reward:reward-models`** 에서 api 의존으로 들어온다
>   (`gradle/wadiz.gradle`, `reward-api/build.gradle`). 따라서 DTO 필드의 Validation 어노테이션·타입 등은 본 레포에서 직접 확인 불가이며,
>   테스트 코드(`reward-api/src/test/...ControllerTest.java`)에서 builder로 채워지는 속성과 `jsonPath` 로 검증되는 응답 필드만 나열한다.
> - `Bean Validation`(`@Valid`) 은 컨트롤러 서명에만 존재하고, 실제 제약(`@NotNull`, `@Size` 등)은 reward-models jar 내부이므로 문서에서는 "(외부 jar, 관측 불가)" 로 명시한다.
> - 집계(Aggregate) 쿼리를 제외하면 모두 Spring Data JPA + Hibernate Envers 감사 기반이므로, 레포지토리 메서드명으로 생성되는 JPQL 은 메서드 시그니처만 기록한다.
> - 외부 서비스 호출(HTTP/Kafka/Redis publish 등) 은 본 세 도메인에서는 관측되지 않았다. 캐시는 Spring `@Cacheable`/`@CacheEvict`(프로젝트 전체가 Hazelcast 클러스터링 — `application.yml:82`)이며,
>   단일 서비스 내부 캐시에 한해 기록한다.

---

## 0. 개요

세 도메인은 "리워드 API"(`reward-api`, port 9050) 내에서 쿠폰과 별개로 제공되는 **리워드 부속 도메인** 이다. 프로젝트/캠페인 단위의 편성·응답·운영 노트를 담당하며, 구조적으로 공통점이 많다.

| 도메인 | 책임 | 핵심 엔티티 | 저장소 |
|---|---|---|---|
| **Collection (컬렉션)** | 프로젝트 "기획전(큐레이션 묶음)" — 여러 캠페인을 한 keyword 아래 묶고 타이틀·문구·대표 이미지를 관리하는 소프트 그룹. "주문 후 리워드 취합" 과는 무관 (주문 관련 로직 없음). | `Collection` + `ElementCollection CollectionCampaign` | JPA / MySQL 테이블 `RewardCollection`, `RewardCollectionMapping` |
| **Satisfaction (만족도)** | 리워드 수령 후 유저가 남기는 **만족도 평가** (`campaignId` + `userId` 당 1건, 여러 항목별 1~5점 + 코멘트 + 사진 + 메이커 답글 + 혜택 지급 상태 추적). | `Satisfaction`(+`SatisfactionScore`, `SatisfactionImage`, `SatisfactionReply`, `SatisfactionBenefit`) | JPA(JpaRepository 상속 `SatisfactionRepository`) + MyBatis(집계 전용 `SatisfactionDao`) |
| **Memo (메모)** | 내부 운영용 **프로젝트(캠페인)별 메모** — `memoCategory` 라는 자유 문자열로 구분되는 단문 노트. 수정 시 이력(`MemoHistory`)을 append. 테스트 코드에서 사용되는 category 값은 `firstScreening`, `SCREENING` 등 심사/운영 용도. | `Memo`, `MemoHistory` | JPA / MySQL |

### 왜 컨트롤러가 나뉘어 있는가

- **`CollectionController` vs `CollectionMappingController`** : 기본 path (`/api/v1/rewards/collections`) 는 같지만, OpenAPI(Swagger) 태그와 책임 경계를 분리했다.
  - `CollectionController` 는 "컬렉션 자체(메타데이터: type/keyword/title/message/photo/isUsed)" CRUD.
  - `CollectionMappingController` 는 "컬렉션 ↔ campaignId 매핑 목록" CRUD (같은 Aggregate 루트 `Collection` 엔티티의 `@ElementCollection campaigns` 를 조작하지만, `/{collectionNo}/campaigns` 하위 서브 리소스로 분리).
- **`SatisfactionController` vs `SatisfactionAggregateController`** : 집계(평균·분포) 는
  - (1) SQL 성격이 완전히 다르고(`SatisfactionScore` 와 `Satisfaction` 을 `LEFT JOIN` + `GROUP BY item` + `ROUND(AVG)` — JPA Specification 으로 표현 곤란),
  - (2) 저장소가 달라 MyBatis `SatisfactionDao`/`satisfaction-aggregate-mapper.xml` 로 구현된다.
  - (3) Swagger group 태그도 `만족도 평가 Aggregate API` 로 별도 분리.

---

## 1. Collection 도메인

### 1.1. 엔드포인트 인벤토리 (12개)

| Method | Path | 컨트롤러.메서드 | 용도 |
|---|---|---|---|
| GET | `/api/v1/rewards/collections` | `CollectionController.getAll` (`CollectionController.java:30`) | 컬렉션 목록 검색 (Pageable) |
| GET | `/api/v1/rewards/collections/{collectionNo}` | `CollectionController.get` (`CollectionController.java:37`) | 상세 (by PK) |
| GET | `/api/v1/rewards/collections/keywords/{keyword}` | `CollectionController.get(String)` (`CollectionController.java:43`) | 상세 (by 고유 keyword) |
| GET | `/api/v1/rewards/collections/campaigns/{campaignId}` | `CollectionController.getAllByCampaignId` (`CollectionController.java:49`) | 해당 campaignId 가 속한 모든 컬렉션 |
| POST | `/api/v1/rewards/collections` | `CollectionController.create` (`CollectionController.java:55`) | 컬렉션 신규 등록 |
| PUT | `/api/v1/rewards/collections/{collectionNo}` | `CollectionController.modify` (`CollectionController.java:61`) | 컬렉션 메타 수정 |
| GET | `/api/v1/rewards/collections/{collectionNo}/campaigns` | `CollectionMappingController.getAll` (`CollectionMappingController.java:30`) | 컬렉션 → campaignIds 매핑 조회 |
| GET | `/api/v1/rewards/collections/keywords/{keyword}/campaigns` | `CollectionMappingController.getAllByKeyword` (`CollectionMappingController.java:36`) | keyword 로 매핑 조회 |
| POST | `/api/v1/rewards/collections/{collectionNo}/campaigns` | `CollectionMappingController.add` (`CollectionMappingController.java:42`) | 매핑 1건 추가 |
| POST | `/api/v1/rewards/collections/{collectionNo}/campaigns/bulk` | `CollectionMappingController.bulk` (`CollectionMappingController.java:49`) | 매핑 Bulk 추가(옵션으로 전체 교체) |
| DELETE | `/api/v1/rewards/collections/{collectionNo}/campaigns/{campaignNo}` | `CollectionMappingController.remove` (`CollectionMappingController.java:55`) | 매핑 1건 제거 |
| DELETE | `/api/v1/rewards/collections/{collectionNo}/campaigns/bulk` | `CollectionMappingController.bulkRemove` (`CollectionMappingController.java:63`) | `?campaignIds=1,2,3` Bulk 제거 |

### 1.2. 컨트롤러 상세

#### `CollectionController`
`CollectionController.java:20` · Base `/api/v1/rewards/collections`
- 모두 `ResponseWrapper.success(...)` 래핑 (프로젝트 공통 응답 포맷).
- `@ModelAttribute` 로 `CollectionDto.Search` 바인딩 (reward-models 의 Search DTO — 관측 가능한 필드는 테스트 코드에서 `collectionNos`, `campaignId`, `titleOrKeyword`, `keyword`, `title`, `type`, `isUsed` 로 확인됨 — `CollectionSpecificationBuilder.java:23-43`).
- `@Valid` 는 `Create`/`Modify` 에만 적용. 실제 제약은 reward-models jar 내부.

`CollectionService` (`src/main/java/com/wadiz/api/reward/collection/application/CollectionService.java`) 의 흐름:
1. `get(collectionNo)` → `CollectionRepository.findOneOrElseThrow` → `JpaCollectionEntityRepository.findById(..).orElseThrow(CollectionNotFoundException)` (`JpaCollectionRepository.java:32`)
2. `getAll(search, pageable)` → `CollectionSpecificationBuilder.build()` 로 JPA Specification 생성 → `findAll(spec, pageable)` → `converter.toPageResponse` (`CollectionService.java:52-61`, `CollectionSpecification.java:12-40`)
3. `create(request)` → `CollectionCreateValidator.validate` (중복 keyword 검사 — `CollectionCreateValidator.java:19-26`) → `converter.toCollection(request)` (ModelMapper) → `save`
4. `modify(collectionNo, request)` → `CollectionBuilder.build(collectionNo, request)` 가 기존 엔티티 로드 후 title/message1/message2/photoId1/photoId2/isUsed 만 갱신 (`CollectionBuilder.java:16-25`)
5. `getByKeyword(keyword)` → `findByKeywordOrElseThrow` (`JpaCollectionRepository.java:48`)
6. `getAllByCampaignId(campaignId)` → `findByCampaignsCampaignId(campaignId)` — JPA Derived query (spec 이 `@ElementCollection campaigns.campaignId` 를 탐색)

캐시: 6개 캐시 키 (`GET_CACHE_KEY`, `GET_ALL_CACHE_KEY`, `GET_BY_KEYWORD_CACHE_KEY`, `GET_ALL_BY_CAMPAIGN_ID_CACHE_KEY`, `GET_MAPPING_CACHE_KEY`, `GET_MAPPING_BY_KEYWORD_CACHE_KEY`). CRUD 발생 시 `allEntries = true` 로 전체 무효화 (`CollectionService.java:63-77`).

#### `CollectionMappingController`
`CollectionMappingController.java:18` · Base `/api/v1/rewards/collections` (위와 동일 prefix, 세부 path 로 분리).
- Bulk 등록은 `CollectionMappingDto.Bulk` 의 `campaignIds` + `registerUserId` + `shouldClear` 를 받음(테스트 빌더 확인, `CollectionMappingControllerTest.java:69-72`).
  `shouldClear=true` 일 경우 기존 매핑을 `campaigns.clear()` 후 전부 재등록 (`Collection.java:97-104`).
- Bulk 제거는 쿼리파라미터 `?campaignIds=` 리스트 수신.

`CollectionMappingService` (`src/main/java/com/wadiz/api/reward/collection/application/CollectionMappingService.java`):
- 모든 변경 작업은 **Aggregate 루트 `Collection` 을 로드 → 메서드 호출 → save** 패턴.
  - `add` (`:34`) → `collection.addCampaign(campaignId, registerUserId)`, 중복 검사 시 `DuplicateCollectionCampaignException` (`Collection.java:61-63`).
  - `bulk` (`:44`) → `addCampaigns(...)` (optional `removeCampaigns()` 선행).
  - `remove` (`:54`) → `collection.removeCampaign(campaignNo)`, 리스트 비어있으면 `CampaignNotFoundException` (`Collection.java:72-78`).
  - `bulkRemove` (`:82`) → 리스트를 순회하며 `removeCampaign`; 입력 `campaignIds` 가 빈 리스트면 save 생략.
- 조회 2개는 `@Cacheable` 로 캐싱.

### 1.3. 도메인 모델

#### Table `RewardCollection` (JPA 엔티티 `Collection` — `src/main/java/com/wadiz/api/reward/collection/domain/Collection.java`)
- 상속: `AbstractRegisterAuditingEntity` (`support/AbstractRegisterAuditingEntity.java`) → `registerUserId` (nullable=false, updatable=false), `registered` (CreatedDate).
- `@Entity @Table(name="RewardCollection", uniqueConstraints=@UniqueConstraint(name="UK_RewardCollection_Keyword", columnNames={"keyword"}))`.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `collectionNo` | INT PK AUTO_INCREMENT | `@GeneratedValue(IDENTITY)` |
| `type` | VARCHAR(32) NOT NULL | `@Enumerated(STRING)` — `CollectionType` (값은 reward-models jar. 테스트 코드에서 `CollectionType.CAMPAIGN` 확인) |
| `keyword` | VARCHAR(32) NOT NULL UNIQUE | Unique constraint `UK_RewardCollection_Keyword` |
| `title` | VARCHAR(128) |  |
| `message1` / `message2` | TEXT/VARCHAR | (길이 명시 없음 — DDL 확인 불가, `validate` 모드라 DB 정의 우선) |
| `photoId1` / `photoId2` | INT |  |
| `isUsed` | BOOLEAN |  |
| `registerUserId` | INT NOT NULL updatable=false | (상속) |
| `registered` | DATETIME NOT NULL updatable=false | (상속) |

#### Table `RewardCollectionMapping` (CollectionCampaign — `src/main/java/com/wadiz/api/reward/collection/domain/CollectionCampaign.java`)
`@ElementCollection(fetch=EAGER) @CollectionTable(name="RewardCollectionMapping", joinColumns=@JoinColumn(name="collectionNo", foreignKey=@ForeignKey(name="FK_RewardCollectionMapping_CollectionNo")))`.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `collectionNo` | INT FK → `RewardCollection.collectionNo` | Composite join column |
| `campaignId` | INT |  |
| `registerUserId` | INT NOT NULL updatable=false |  |
| `registered` | DATE NOT NULL updatable=false | `Date.from(Instant.now())` default |

### 1.4. 접근 쿼리 요약 (관측 가능한 것만)

- 모두 Spring Data JPA (repository 메서드명 → JPQL). MyBatis SQL **없음**.
- 관측 메서드:
  - `JpaCollectionEntityRepository` (`JpaCollectionRepository.java:16-20`): `findAll(Specification, Pageable)`, `findByKeyword(String)`, `findByCampaignsCampaignId(Integer)`, `findById(Integer)`, `save(Collection)`.
  - Specification 조합자 8개: `equalCampaignId`, `inCollectionNos`, `likeTitleOrKeyword`, `likeKeyword`, `likeTitle`, `equalType`, `isUsed` (`CollectionSpecification.java:12-40`).
  - `likeTitleOrKeyword` 는 `cb.or(like("%keyword%"), like("%title%"))` → 양쪽 LIKE OR 결합(`CollectionSpecification.java:20-23`).

### 1.5. Exception 매핑

`src/main/java/com/wadiz/api/reward/collection/exception/`:
- `CollectionNotFoundException` → `NotFoundException` (404)
- `CampaignNotFoundException` → `NotFoundException`
- `DuplicateCollectionKeywordException` → `BadRequestException` (400, keyword 중복)
- `DuplicateCollectionCampaignException` → `BadRequestException` (매핑 중복 추가)

### 1.6. 외부 연동

- **없음 (관측 불가)**. Controller → Service → JPA Repository → MySQL `wadiz_reward` 까지만. Kafka/Redis publish/HTTP 호출 없음.
- 캐시는 Spring `@Cacheable` (Hazelcast 기반, 프로젝트 전체 설정 — `application.yml:81-82`).

---

## 2. Satisfaction 도메인

### 2.1. 엔드포인트 인벤토리 (16개)

`SatisfactionController` (14) + `SatisfactionAggregateController` (2).

| Method | Path | 컨트롤러.메서드 | 용도 |
|---|---|---|---|
| POST | `/api/v1/rewards/satisfactions` | `SatisfactionController.create` (`:36`) | 만족도 1건 등록 (유저→캠페인) |
| PUT | `/api/v1/rewards/satisfactions/{satisfactionNo}` | `SatisfactionController.modify` (`:42`) | 코멘트·점수·이미지 수정 |
| PUT | `/api/v1/rewards/satisfactions/{satisfactionNo}/is-hidden` | `SatisfactionController.modifyHidden` (`:49`) | 숨김 토글 |
| PUT | `/api/v1/rewards/satisfactions/{satisfactionNo}/benefit` | `SatisfactionController.modifyBenefit` (`:56`) | 혜택(포인트) 지급 상태·거래키 기록 |
| DELETE | `/api/v1/rewards/satisfactions/{satisfactionNo}` | `SatisfactionController.modify(delete)` (`:63`) | 논리 삭제 |
| GET | `/api/v1/rewards/satisfactions/{satisfactionNo}` | `SatisfactionController.get` (`:70`) | 상세 |
| GET | `/api/v1/rewards/satisfactions/campaigns/{campaignId}/users/{userId}` | `SatisfactionController.getByCampaignIdAndUserId` (`:76`) | 유저·캠페인별 상세(유니크 키 조회) |
| GET | `/api/v1/rewards/satisfactions` | `SatisfactionController.getAll` (`:82`) | 목록(Spec+Pageable) |
| GET | `/api/v1/rewards/satisfactions/qty` | `SatisfactionController.getQty` (`:89`) | 건수 |
| PUT | `/api/v1/rewards/satisfactions` | `SatisfactionController.getAllForBenefitPaid` (`:95`) | 목록 조회하면서 동시에 `paid()` 호출 (action=`BENEFIT_PAID` 일 때) |
| GET | `/api/v1/rewards/satisfactions/replies/{satisfactionReplyNo}` | `SatisfactionController.getReply` (`:111`) | 답글 단건 |
| POST | `/api/v1/rewards/satisfactions/{satisfactionNo}/replies` | `SatisfactionController.createReply` (`:117`) | 답글 등록 |
| PUT | `/api/v1/rewards/satisfactions/replies/{satisfactionReplyNo}` | `SatisfactionController.modifyReply` (`:124`) | 답글 수정 |
| DELETE | `/api/v1/rewards/satisfactions/replies/{satisfactionReplyNo}` | `SatisfactionController.deleteReply` (`:131`) | 답글 논리 삭제 |
| GET | `/api/v1/rewards/satisfactions/campaigns/bulk` | `SatisfactionController.getSatisfactionCampaignIdsByUserId` (`:139`) | 유저가 평가한 campaignIds 벌크(GET) |
| POST | `/api/v1/rewards/satisfactions/projects/search` | `SatisfactionController.search` (`:145`) | 위와 동일 (POST body; 긴 campaignIds 수용) |
| GET | `/api/v1/rewards/satisfactions/aggregates/campaigns/{campaignId}` | `SatisfactionAggregateController.aggregate` (`:25`) | 캠페인 1건 집계 |
| POST | `/api/v1/rewards/satisfactions/aggregates/campaigns/bulk` | `SatisfactionAggregateController.aggregates` (`:31`) | 캠페인 Bulk 집계 |

> 중복 라우트: `GET /satisfactions/campaigns/bulk` 과 `POST /satisfactions/projects/search` 가 **동일한 서비스 메서드** `SatisfactionService.getSatisfactionCampaignIdsByUserId(search)` 를 호출한다 (`SatisfactionController.java:140,146`).

### 2.2. 컨트롤러 상세

#### `SatisfactionController` (`SatisfactionController.java:23`)
세 개의 서비스를 주입:
- `SatisfactionService`: 평가 CRUD + 검색/카운트.
- `SatisfactionReplyService`: 답글 CRUD.

주요 분기 로직은 `PUT /satisfactions` (`:95`):
```java
if (action == SatisfactionRequestAction.BENEFIT_PAID) {
  satisfactions = satisfactionService.getAllForBenefitPaid(search, pageable);
} else {
  satisfactions = satisfactionService.getAll(search, pageable);
}
```
→ `getAllForBenefitPaid` 는 결과 각 엔티티에 `Satisfaction.paid()` 를 호출하여 `SatisfactionBenefit.isPaid=true`, `updated=now()` 로 세팅한 뒤 `saveAll` (`SatisfactionService.java:154-163`). 즉 "조회 + 일괄 지급 처리" 가 하나의 PUT 트랜잭션으로 묶여 있다.

#### `SatisfactionService` (`src/main/java/com/wadiz/api/reward/satisfaction/application/SatisfactionService.java`)
- `create` (`:55`): `SatisfactionValidator.validate(create)` (모든 `SatisfactionItem` 값이 scores 에 포함되어 있는지 — `SatisfactionValidator.java:32-40`) → `SatisfactionBuilder.build(create)` (ModelMapper → `calculateAverageScore` → `createBenefit`) → `addImages(imageKeys)` (선택) → `save`.
- `modify` (`:68`): `satisfactionValidator.validate(satisfactionNo, modify)` → 엔티티 로드(isDeleted=false 조건) → `changeCommentAndScores(...)` → `deleteAllImage()` → `setImages(imageKeys)` 로 이미지 덮어쓰기(기존 imageKey 가 재등장하면 재활성화/순번 갱신, 신규는 추가 — `Satisfaction.java:139-157`).
- `modifyHidden` (`:83`): `changeHidden(isHidden)` — `hiddenUpdated` 도 갱신.
- `modifyBenefit` (`:92`): `SatisfactionValidator.validBenefitPaid` 로 `isPaid=true` 일 때 `pointTransactionKey`·`updated` 필수 체크 (`SatisfactionValidator.java:46-56`).
- `delete` (`:110`): `isDeleted=true`, `updated=now`, 이미지도 논리 삭제 (`Satisfaction.java:106-113`).
- `get` (`:120`): `SatisfactionRepository.findById`.
- `getAll` (`:132`): Spec 기반 Page 조회 (cacheable 주석은 현재 주석처리됨 — `SatisfactionService.java:127-131`).
- `getByCampaignIdAndUserId` (`:143`): `findOneByCampaignIdAndUserId` (유니크 키).
- `getAllForBenefitPaid` (`:154`): 위 분기 참조.
- `getQty` (`:170`): `userId` 가 있으면 JPA count, 없으면 MyBatis `satisfactionDao.countById(search)`.
- `getSatisfactionCampaignIdsByUserId` (`:186`): `SELECT campaignId FROM Satisfaction WHERE userId = :userId AND campaignId IN (:campaignIds)` (`SatisfactionRepository.java:22-23`).

캐시: 5개 (`GET_CACHE_KEY`, `GET_ALL_CACHE_KEY`, `GET_BY_CAMPAIGN_ID_AND_USER_ID_CACHE_KEY`, `GET_QTY_CACHE_KEY`, `AGGREGATE_CACHE_KEY`). 쓰기 시 전면 무효화.

#### `SatisfactionReplyService` (`src/main/java/com/wadiz/api/reward/satisfaction/application/SatisfactionReplyService.java`)
- `create` (`:37`): `SatisfactionReplyBuilder.build(satisfactionNo, req)` (ModelMapper 매핑 → `satisfactionNo` 주입 — `SatisfactionReplyBuilder.java:16-22`) → save.
- `modify` (`:45`): `findOneBySatisfactionReplyNoAndIsDeletedFalse` → `change(comment)` → save.
- `delete` (`:53`): `findById(..).get()` (Optional.get — 존재하지 않으면 NoSuchElementException; 방어 로직 없음) → `delete()` → save.
- `get` (`:70`): 캐시된 단건 조회.

> 코드 관찰: `delete` 는 `Optional.get()` 직접 호출, `modify` 와 달리 `IsDeletedFalse` 조건도 없다. 이미 삭제된 답글을 다시 delete 호출하면 `isDeleted=true`, `whenDeleted=now` 만 갱신된다 (`SatisfactionReply.java:53-56`).

#### `SatisfactionAggregateController` / `SatisfactionAggregateService`
- 집계 조회만. `@Cacheable` 로 결과 캐싱 (`AGGREGATE_CACHE_KEY` 단건 / `AGGREGATE_BULK_CACHE_KEY` bulk).
- 실제 SQL 은 MyBatis `SatisfactionDao` 가 담당 (아래 2.4 절).

### 2.3. 도메인 모델

#### Table `Satisfaction` (`Satisfaction.java`)
- 상속 `AbstractRegisteredAuditingEntity` (`registered` 만).
- `@UniqueConstraint(columnNames={"campaignId","userId"}, name="UK_Satisfaction__CampaignId_UserId")` — 유저·캠페인 당 1건.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `satisfactionNo` | INT PK AUTO_INCREMENT |  |
| `campaignId` | INT NOT NULL |  |
| `userId` | INT NOT NULL |  |
| `comment` | VARCHAR(5000) NOT NULL |  |
| `averageScore` | DECIMAL | `Math.round(avg(score) * 10) / 10.0f` (소수 1자리) |
| `isHidden` | BOOLEAN NOT NULL DEFAULT false |  |
| `hiddenUpdated` | DATETIME NOT NULL | 숨김 상태 변경 시각 |
| `isDeleted` | BOOLEAN NOT NULL DEFAULT false | 논리 삭제 |
| `updated` | DATETIME NOT NULL | `delete`/`modify` 시 현재시각 |
| `registered` | DATETIME NOT NULL updatable=false |  |

연관:
- `List<SatisfactionScore> scores` @ElementCollection `SatisfactionScore` 테이블.
- `List<SatisfactionImage> images` @OneToMany (`@Where(clause="IsDeleted = false")`) `@OrderBy("orderNo")`.
- `List<SatisfactionReply> commentReplies` @OneToMany (`@Where(clause="IsDeleted = false")`) `@OrderBy("registered desc, satisfactionReplyNo desc")`.
- `SatisfactionBenefit benefit` @OneToOne (cascade ALL).

#### Table `SatisfactionScore` (`SatisfactionScore.java`)
`@CollectionTable(name="SatisfactionScore", joinColumns=@JoinColumn(name="SatisfactionNo"))`.
UniqueConstraint `UK_SatisfactionScore__SatisfactionNo_Item` on `{satisfactionNo, item}`.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `satisfactionNo` | INT FK |  |
| `item` | VARCHAR NOT NULL | `@Enumerated(STRING)` `SatisfactionItem` enum (관측 값: `REWARD`, `MAKER` — reward-models jar) |
| `score` | TINYINT NOT NULL | 1~5 |

#### Table `SatisfactionImage` (`SatisfactionImage.java`)
`@Entity` (독립 테이블).

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `uploadImageSeq` | INT PK AUTO_INCREMENT |  |
| `satisfactionNo` | INT insertable=false updatable=false | `@ManyToOne` 조인 컬럼 |
| `imageKey` | VARCHAR NOT NULL | CDN key |
| `orderNo` | INT NOT NULL |  |
| `isDeleted` | BOOLEAN NOT NULL DEFAULT false |  |

Transient 필드 `url` 은 `SatisfactionConverter.toResponse` 가 `baseUrl + imageKey` 로 세팅 — `baseUrl` 은 `${application.cdn.base-url}` (`SatisfactionConverter.java:22-23`, `:42`).

#### Table `SatisfactionReply` (`SatisfactionReply.java`)
상속 `AbstractRegisteredAuditingEntity`.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `satisfactionReplyNo` | INT PK AUTO_INCREMENT |  |
| `satisfactionNo` | INT NOT NULL |  |
| `comment` | VARCHAR(5000) NOT NULL |  |
| `userId` | INT NOT NULL |  |
| `isMaker` | BOOLEAN NOT NULL | 메이커 답글 여부 |
| `depth` | INT DEFAULT 0 |  |
| `isDeleted` | BOOLEAN NOT NULL DEFAULT false |  |
| `whenDeleted` | DATETIME |  |
| `registered` | DATETIME NOT NULL updatable=false |  |

#### Table `SatisfactionBenefit` (`SatisfactionBenefit.java`)
`@OneToOne @MapsId` — PK 가 `Satisfaction.satisfactionNo` 와 동일.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `satisfactionNo` | INT PK (shared) |  |
| `isPaid` | BOOLEAN DEFAULT false |  |
| `pointTransactionKey` | CHAR(36) | 포인트 거래 UUID (예: `000042d0-2b28-4087-8002-00a6542a7d32` — `SatisfactionBenefitModifyControllerTest.java:38`) |
| `updated` | DATETIME |  |
| `isUploadedImage` | `@Transient` | 응답 시 계산 (`setIsUploadedImage()`) |

### 2.4. MyBatis SQL — `satisfaction-aggregate-mapper.xml`

파일: `src/main/resources/mapper/reward/satisfaction/satisfaction-aggregate-mapper.xml`
네임스페이스: `com.wadiz.api.reward.satisfaction.infra.dao.SatisfactionDao` (`SatisfactionDao.java:3`).

#### `<select id="aggregate">` — 캠페인 1건 집계
```xml
<resultMap id="aggregateResult" type="com.wadiz.api.reward.dto.satisfaction.SatisfactionDto$Aggregate"
           autoMapping="true">
    <id property="campaignId" column="campaignId"/>
    <collection property="aggregatesByItem" javaType="java.util.ArrayList"
                ofType="com.wadiz.api.reward.dto.satisfaction.SatisfactionDto$AggregateByItem" columnPrefix="item_"
                autoMapping="true"/>
</resultMap>

<sql id="baseAggregateSatisfactionColumnList">
    CampaignId
     , (SELECT COUNT(*) FROM Satisfaction WHERE CampaignId = SF.CampaignId AND IsDeleted = FALSE) AS Qty
     , Item AS item_Item
     , ROUND(AVG(Score), 1) AS item_AverageScore
     , SUM(CASE WHEN Score = 1 THEN 1 ELSE 0 END) AS item_QtyOfOne
     , SUM(CASE WHEN Score = 2 THEN 1 ELSE 0 END) AS item_QtyOfTwo
     , SUM(CASE WHEN Score = 3 THEN 1 ELSE 0 END) AS item_QtyOfThree
     , SUM(CASE WHEN Score = 4 THEN 1 ELSE 0 END) AS item_QtyOfFour
     , SUM(CASE WHEN Score = 5 THEN 1 ELSE 0 END) AS item_QtyOfFive
</sql>

<select id="aggregate" resultMap="aggregateResult">
    SELECT
    <include refid="baseAggregateSatisfactionColumnList"></include>
      FROM SatisfactionScore SS
 LEFT JOIN Satisfaction SF ON SS.SatisfactionNo = SF.SatisfactionNo
     WHERE SF.CampaignId = #{campaignId}
       AND SF.IsDeleted = FALSE
       AND SF.IsHidden = FALSE
  GROUP BY CampaignId, Item
</select>
```

#### `<select id="aggregates">` — Bulk (campaignIds IN (...))
```xml
<select id="aggregates" resultMap="aggregateResult">
    SELECT
    <include refid="baseAggregateSatisfactionColumnList"></include>
     FROM SatisfactionScore SS
LEFT JOIN Satisfaction SF ON SS.SatisfactionNo = SF.SatisfactionNo
    WHERE SF.CampaignId IN
    <foreach collection="campaignIds" item="item" separator="," open="(" close=")">
        #{item}
    </foreach>
     AND SF.IsDeleted = FALSE
     AND SF.IsHidden = FALSE
GROUP BY CampaignId, Item
</select>
```

#### `<select id="countById">` — 삭제되었어도 답글이 남아있으면 카운트
```xml
<select id="countById" resultType="long">
    SELECT COUNT(*)
    FROM (SELECT S.SatisfactionNo
            FROM Satisfaction S
                   LEFT JOIN wadiz_reward.SatisfactionReply SR
                             ON S.SatisfactionNo = SR.SatisfactionNo AND SR.IsDeleted = FALSE
           WHERE S.CampaignId = #{search.campaignId}
             AND S.IsDeleted = #{search.isDeleted} OR
               (S.CampaignId = #{search.campaignId} AND (S.IsDeleted = TRUE AND SR.SatisfactionReplyNo IS NOT NULL))
           GROUP BY S.SatisfactionNo
          ) AS C
</select>
```
> 주석 없음의 관찰: `AND ... OR ...` 에 괄호가 없어 `AND search.campaignId OR (...)` 순서로 해석되어 "isDeleted=true + 답글존재" 분기가 campaignId 필터를 따로 반복하는 구조(`campaignId=X AND isDeleted=Y` OR `campaignId=X AND (isDeleted=TRUE AND 답글존재)`). 테스트 고정 케이스(`SatisfactionFindControllerTest.java`) 만 존재하므로 실행 환경에서의 정확한 의도는 단언 불가.

### 2.5. 접근 쿼리 요약 — JPA Specification

`SatisfactionSpecification.java:12-63` 제공 조합자:

| 조합자 | 조건 |
|---|---|
| `equalCampaignId(Integer)` | `campaignId = ?` |
| `equalUserId(Integer)` | `userId = ?` |
| `isHidden(Boolean)` | `isHidden = ?` |
| `isDeleted(Boolean)` | `isDeleted = ?` |
| `betweenRegistered(Date,Date)` | `registered BETWEEN ? AND ?` |
| `greaterThanOrEqualToRegistered(Date)` | `registered >= ?` |
| `lessThanOrEqualToRegistered(Date)` | `registered <= ?` |
| `equalSatisfactionItemAndScore(item, score)` | INNER JOIN `scores` + `item=? AND score=?` |
| `isBenefitPaid(Boolean)` | INNER JOIN `benefit` + `isPaid=?` |
| `equalFloorAverageScore(Integer)` | `averageScore >= ? AND averageScore < ?+1` (소수 1자리 점수를 정수 버킷으로) |
| `isUploadedImage()` | `query.distinct(true)` + INNER JOIN `images` (존재 행) |

`SatisfactionSpecificationBuilder.java:18-61` — 검색 DTO의 null 필드를 건너뛰며 조합.

### 2.6. Exception 매핑
`src/main/java/com/wadiz/api/reward/satisfaction/exception/`:
- `SatisfactionNotFoundException` → `NotFoundException`
- `SatisfactionReplyNotFoundException` → `NotFoundException`
- `NotIncludedSatisfactionItemException` → `BadRequestException` (Validator: 모든 `SatisfactionItem` 이 score 목록에 들어있지 않은 경우)
- `MissingRequiredTransactionKeyException` → `BadRequestException` (isPaid=true & pointTransactionKey 누락)
- `MissingRequiredPaidUpdatedException` → `BadRequestException` (isPaid=true & updated 누락)

### 2.7. 외부 연동

- **포인트 지급 자체는 본 레포에서 수행되지 않음**. `modifyBenefit` 은 클라이언트(예: 백오피스, 배치, 다른 서비스)가 외부 포인트 시스템 호출 후 `pointTransactionKey` 를 들고 와서 기록만 하는 API. `getAllForBenefitPaid` (PUT) 도 `isPaid=true` 를 설정하지만 외부 호출은 없다 — 즉 "장부 마킹" 책임만.
- CDN: 이미지 응답 URL 은 `application.cdn.base-url` + `imageKey` 조합 (`SatisfactionConverter.java:22-23, :42`).
- MySQL: 기본 DataSource(`wadiz_reward` — application.yml:18-54). 집계 쿼리 `countById` 는 동일 스키마의 `wadiz_reward.SatisfactionReply` 를 명시적으로 `schema.table` 참조.

---

## 3. Memo 도메인

### 3.1. 엔드포인트 인벤토리 (3개)

| Method | Path | 컨트롤러.메서드 | 용도 |
|---|---|---|---|
| GET | `/api/v1/rewards/memos/campaigns/{campaignId}/memo-categories/{memoCategory}` | `MemoController.get` (`:29`) | 캠페인+카테고리 조합 조회(단건) |
| POST | `/api/v1/rewards/memos` | `MemoController.save` (`:37`) | 메모 등록 (중복 방지) |
| PUT | `/api/v1/rewards/memos/{memoNo}` | `MemoController.modify` (`:44`) | 메모 내용 수정 + History 추가 |

### 3.2. 컨트롤러 상세

`MemoController` (`MemoController.java:17`)
- 3개 엔드포인트 모두 `MemoService` + `MemoConverter` 조합.
- POST/PUT 은 `@Valid`; 실제 제약은 reward-models.
- 응답은 `MemoConverter.toMemoResponse(Memo)` (ModelMapper).

`MemoService` (`src/main/java/com/wadiz/api/reward/memo/application/MemoService.java`)
- `get(campaignId, memoCategory)` (`:28`): `memoRepository.findByCampaignIdAndMemoCategory(...)` (JPA Derived). 없으면 null 반환 (테스트 `메모_상세조회_NULL` 은 HTTP 200 + null 을 기대 — `MemoControllerTest.java:49-57`).
- `create(memoCreate)` (`:33`): `memoValidation` → `memoRepository.save(toMemo(create))` → `memoHistoryRepository.save(toMemoHistory(memo))`.
- `modify(memoNo, modify)` (`:45`): 기존 `Memo.findByMemoNo` 로드 → `setContent`, `setUpdateUserId` → `save` → `memoHistoryRepository.save(toMemoHistory(memo))`.
- `memoValidation` (`:62`): 동일 `(campaignId, memoCategory)` 가 이미 있으면 `MemoRegistException("이미 등록 된 메모입니다.")`.

`MemoConverter.toMemoHistory` (`MemoConverter.java:30-42`)
```java
MemoHistory memoHistory = new MemoHistory();
memoHistory.setMemoNo(memo.getMemoNo());
memoHistory.setContent(memo.getContent());
if(memo.getUpdateUserId() != memo.getRegisterUserId()) {
  memoHistory.setRegisterUserId(memo.getUpdateUserId());
} else {
  memoHistory.setRegisterUserId(memo.getRegisterUserId());
}
```
> 관찰: `Integer != Integer` 참조 비교(박싱 캐시 밖 값은 항상 "불일치" 로 판정) → 의도대로 "최종 수정자 기록" 이 되지만 Integer 언박싱 누락 케이스가 존재한다. 본 레포 내에서 수정 없음.

`MemoValidator` (`src/main/java/com/wadiz/api/reward/memo/validator/MemoValidator.java`): **빈 클래스** (`public class MemoValidator {}`).  Bean 도 아님. 미사용 placeholder.

### 3.3. 도메인 모델

#### Table `Memo` (`Memo.java`)
상속 `AbstractAuditingEntity` → `registerUserId`, `registered`(CreatedDate), `updateUserId`, `updated`(LastModifiedDate).
`@UniqueConstraint(name="UK_Memo__campaignId_memoCategory", columnNames={"campaignId","memoCategory"})`.

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `memoNo` | INT PK AUTO_INCREMENT |  |
| `campaignId` | INT NOT NULL |  |
| `memoCategory` | VARCHAR NOT NULL | 자유 문자열 키 (관측 값: `firstScreening`, `SCREENING`, `ACCOUNT` — `MemoControllerTest.java`) |
| `content` | VARCHAR(1500) NOT NULL |  |
| `registerUserId` | INT NOT NULL updatable=false | (상속) |
| `registered` | DATETIME NOT NULL updatable=false | (상속) |
| `updateUserId` | INT NOT NULL | (상속) |
| `updated` | DATETIME NOT NULL | (상속) |

#### Table `MemoHistory` (`MemoHistory.java`)
상속 `AbstractRegisterAuditingEntity` (`registerUserId`, `registered` 만).

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `seq` | INT PK AUTO_INCREMENT |  |
| `memoNo` | INT NOT NULL |  |
| `content` | TEXT/VARCHAR | 수정 당시 본문 스냅샷 |
| `registerUserId` | INT NOT NULL updatable=false | 변경 수행자(최종 수정자 우선) |
| `registered` | DATETIME NOT NULL updatable=false | 변경 시각 |

→ `Memo` 가 "현재값" 을, `MemoHistory` 가 "누적 이력" 을 보관. create/modify 각각에서 1행씩 `MemoHistory` 에 append.

### 3.4. 접근 쿼리 요약 — JPA Derived

- `MemoRepository.findByCampaignIdAndMemoCategory(Integer, String)` (`MemoRepository.java:9`)
- `MemoRepository.findByMemoNo(Integer)` (`MemoRepository.java:10`) — `findById` 와 동일 의미지만 반환 타입이 `Memo` (Optional 아님).
- `MemoHistoryRepository` 는 기본 `JpaRepository<MemoHistory, Integer>` 메서드만 사용(`save` 뿐).

MyBatis SQL **없음**.

### 3.5. Exception 매핑
- `MemoRegistException` → `BadRequestException` ("이미 등록 된 메모입니다.")

### 3.6. 외부 연동

- **없음 (관측 불가)**. Memo 는 `reward-api` 외부 (예: 어드민/심사 도구) 가 호출하여 "내부 운영용 메모" 를 남기는 용도로만 읽기/쓰기 한다. Kafka/Redis publish/HTTP 호출 없음.
- `MemoController` 는 `@PreAuthorize` 등 인가 어노테이션이 없으며, 본 레포에 SecurityFilter 도 관측되지 않음 → 보호는 상위 게이트웨이/내부 네트워크 경계에 위임된 것으로 추정(확인 불가).

---

## 4. 통합 외부 의존성 관점

세 도메인 묶음을 관통하는 외부 의존성은 **매우 제한적**이다. 쿠폰 도메인과 달리 상호 서비스 호출, Kafka/RabbitMQ publish 가 관측되지 않는다.

| 항목 | Collection | Satisfaction | Memo | 위치 |
|---|---|---|---|---|
| MySQL `wadiz_reward` (기본 DataSource) | o | o | o | `application.yml:18-54` (master/slave hikari) |
| MySQL `wadiz_db` (`@WadizTx`) | x | x | x | — |
| JPA + Hibernate Envers 감사(`*_Aud` 자동 생성) | o | o | o | `application.yml:60-63` |
| MyBatis (집계) | x | o (`SatisfactionDao` + `satisfaction-aggregate-mapper.xml`) | x | `src/main/resources/mapper/reward/satisfaction/...` |
| `@Cacheable` / `@CacheEvict` (Hazelcast) | o (6 keys) | o (5 keys + Aggregate 2 keys) | x | Spring cache via Hazelcast cluster (`hazelcast/hazelcast-default.yaml`) |
| Spring Data JPA Specification | o | o | x | `*SpecificationBuilder.java` |
| ModelMapper(DTO ↔ Entity) | o | o | o | converter 클래스들 |
| Jakarta Validation (`@Valid`) | o | o | o | 실제 제약은 reward-models jar |
| CDN base URL (`application.cdn.base-url`) | x | o (이미지 URL 조립) | x | `SatisfactionConverter.java:22-23` |
| 외부 HTTP / Kafka / RabbitMQ publish | x | x | x | (프로젝트 전체에 `RabbitMqConfig` 존재하지만 본 도메인에서는 사용 관측 없음) |
| reward-models jar (DTO/Enum 제공) | o | o | o | `gradle/wadiz.gradle`: `api "com.wadiz.api.reward:reward-models:${reward_models_version}"` |

### OpenAPI / Swagger 그룹
`application.yml:106-122` 에서 네 도메인(`coupon`, `collection`, `satisfaction`, `memo`) 이 별도 group 으로 분리 게시된다. Swagger 접근 경로 `/swagger-ui.html`, primary group 은 `coupon`.

```yaml
springdoc:
  swagger-ui:
    path: /swagger-ui.html
    urls-primary-name: coupon
  group-configs:
    - group: collection       paths-to-match: ["/api/v1/rewards/collections/**"]
    - group: satisfaction     paths-to-match: ["/api/v1/rewards/satisfactions/**"]
    - group: memo             paths-to-match: ["/api/v1/rewards/memos/**"]
```

---

## 5. 경계 및 미탐색 영역

### 5.1. 본 레포 안에서도 직접 관측이 불가능한 것

- **Request/Response DTO 실체** (`CollectionDto.Create/Modify/Search/Response`, `CollectionMappingDto.Add/Bulk/Response`, `SatisfactionDto.Create/Modify/Hidden/ModifyBenefit/Search/BulkSearch/Response/Aggregate/AggregateByItem/SatisfactionScore`, `SatisfactionReplyDto.Create/Modify/Response`, `MemoDto.Create/Modify/Response`) — 모두 `reward-models` 외부 jar.
  - Validation 어노테이션(`@NotNull`, `@Size`, `@Pattern` 등) 및 필드 타입, JsonProperty 매핑 등은 본 레포에서 확인 불가.
  - 단 테스트 builder (`CollectionControllerTest.java`, `SatisfactionCreateControllerTest.java`, `SatisfactionFindControllerTest.java`, `SatisfactionBenefitModifyControllerTest.java`, `SatisfactionAggregateControllerTest.java`, `MemoControllerTest.java`, `CollectionMappingControllerTest.java`) 에서 사용된 builder 필드명 및 `jsonPath` 검증 키가 사실상의 "관측 가능한 응답 필드" 목록으로 이용 가능.
- **Enum 값**: `CollectionType`(관측: `CAMPAIGN`), `SatisfactionItem`(관측: `REWARD`, `MAKER`), `SatisfactionRequestAction`(관측: `BENEFIT_PAID`) — 나머지 상수는 외부 jar.
- **DTO.Search.OrderProperty** (예: `SatisfactionDto.Search.OrderProperty.AVERAGE_SCORE`) — sort 에 사용 가능한 필드 집합 — 외부 jar.
- **OAuth/인증 가드**: 컨트롤러에 `@PreAuthorize`, `@Impersonatable` 등 권한 어노테이션 없음. Security Filter Chain 이 본 레포에 존재하는지 여부는 타 도메인(쿠폰) 문서에 위임.

### 5.2. 본 문서 범위를 벗어나는 항목

- **쿠폰(coupon) 도메인** 및 배치(reward-batch). 이 문서에서는 다루지 않음.
- `reward-batch` 모듈이 Satisfaction/Collection/Memo 관련 스케줄러를 갖는지는 미조사. `api-details/batch.md` 참조.
- Admin/Maker 화면에서 이 API 를 호출하는 지점(호출자 식별) — FE 레포들(`makercenter-fe`, `com.wadiz.adm` 등) 기준으로 별도 추적 필요.

### 5.3. 잠재적 위험/관찰

1. `SatisfactionReplyService.delete` (`SatisfactionReplyService.java:53-58`) 의 `findById(..).get()` — 존재하지 않는 `satisfactionReplyNo` 로 호출 시 `NoSuchElementException` (전역 ExceptionHandler 없을 경우 500).
2. `MemoConverter.toMemoHistory` (`MemoConverter.java:35`) 의 `Integer != Integer` 참조 비교 — Integer 캐시(`-128..127`) 밖 값은 항상 `!=` 참 → 실질적으로 "수정자 있으면 수정자, 없으면 등록자" 로 동작하지만 코드 의도와 구현이 불일치. 본 레포에 수정 흔적 없음.
3. `satisfaction-aggregate-mapper.xml:55-57` `countById` 의 `AND ... OR ...` 괄호 누락 — 의도 확인 불가.
4. `Collection.addCampaigns` (`Collection.java:97-104`) 에서 `shouldClear=true` 시 기존 매핑을 전부 비우고 재등록 — 내부적으로 `@ElementCollection` 의 insert/delete 가 대량 발생, `rewriteBatchedStatements: true` (application.yml:32) 로 완화.
5. `CollectionService` 와 `CollectionMappingService` 는 **같은 6개 캐시 키** 를 `allEntries=true` 로 비워낸다 — 쓰기 1회마다 컬렉션 관련 모든 캐시가 리셋된다.
6. `Satisfaction.getAllForBenefitPaid` (HTTP `PUT /api/v1/rewards/satisfactions`) 는 "조회" 가 아니라 "조회+지급" 을 하나의 트랜잭션으로 수행. 의도치 않은 호출 시 전체 페이지의 `SatisfactionBenefit.isPaid` 가 true 로 갱신됨. 호출자가 반드시 `action=BENEFIT_PAID` 쿼리파라미터 의미를 인지하고 있어야 한다.

### 5.4. 교차 검증 — 엔드포인트 합산

- Collection: 6 (CollectionController) + 6 (CollectionMappingController) = 12.
- Satisfaction: 14 (SatisfactionController) + 2 (SatisfactionAggregateController) = 16.
- Memo: 3 (MemoController).
- **세 도메인 합계: 31 엔드포인트**. 상위 overview `com.wadiz.api.reward.md` 의 "Collection · Satisfaction · Memo 5 컨트롤러" 항목과 일치.
