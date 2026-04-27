# Flow: 댓글 (펀딩 프로젝트 댓글·답글)

> 펀딩 프로젝트 상세 페이지의 댓글/답글 체인. com.wadiz.web 자체 `@Controller` + MyBatis 로 `MiniBoardCommon` 테이블 직접 접근.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/reward/comments.service.ts:1-30` (신규 FE)
  - `wadiz-frontend/static/packages/reward-update-news-app/src/actions/index.js:74-255` (레거시 static bundle)
  - `com.wadiz.web/src/main/java/.../reward/comment/controller/CommentApiController.java:24-80`
  - `com.wadiz.web/src/main/java/.../reward/comment/service/CommentService.java:196-240` (`create`, `modify`, `insertComment`, `insertReply`)
  - `com.wadiz.web/src/main/resources/sqls/reward/comment/comment-mapper.xml:11-260`
  - `com.wadiz.web/src/main/resources/sqls/reward/comment/comment-image-mapper.xml:1-40`
- **외부 경계**: `sendCommentReplyNotification` 내부 (알림 서비스 호출 — Notification/push 구현), `backingPaymentAdapter.isSupport` 호출(`BackingPayment` 조회 adapter — funding 쪽 가능성), 메이커 뉴스 댓글(`MakerNewsCommentApiController`) 은 별도.
- **범위 제한**: 본 문서는 "**펀딩 프로젝트 댓글**" 에 집중. 서포터 서명 댓글은 [supporter-signature.md](./supporter-signature.md) 참조, 메이커 뉴스 댓글은 별도.

---

## 1. Client Trigger (FE)

### 1.1 주요 API — `packages/api/src/web/reward/comments.service.ts`
```ts
export const createComment = (payload) =>
  POST('/web/reward/api/comments', payload);                       // :6   생성 (댓글/답글 공용)

export const getComments = (campaignId, params) =>
  GET(`/web/reward/api/comments/campaigns/${campaignId}`, { params });  // :12  목록

export const modifyComment = (commentId, payload) =>
  POST(`/web/reward/api/comments/${commentId}`, payload);          // :18  수정

export const deleteComment = (commentId) =>
  POST(`/web/reward/api/comments/${commentId}/delete`, {});        // :24  삭제
```

### 1.2 레거시 static entry (`static/packages/reward-update-news-app`)
```js
// :74  GET /web/reward/api/comments/campaigns/{campaignId}{qString}
// :141 GET /web/reward/api/comments/campaigns/{campaignId}/replys{qString}
// :181 POST /web/reward/api/comments
// :217 POST /web/reward/api/comments/{boardId}
// :253 POST /web/reward/api/comments/{boardId}/delete
```
동일 엔드포인트를 두 FE 번들이 공유. 이관 과도기로 신구 UI 가 병존하는 영역이다.

---

## 2. Hub — `com.wadiz.web` (자체 처리)

### 2.1 Controller
```java
// com.wadiz.web/.../reward/comment/controller/CommentApiController.java:24
@Controller
@RequestMapping(value = "/web/reward/api/comments")
public class CommentApiController {
    @Autowired private CommentService commentService;

    // :32  캠페인 댓글 목록 조회
    @GetMapping("/campaigns/{campaignId}")
    public ResponseWrapper<Page<CommentVo>> getCommentList(@PathVariable Integer campaignId,
                                                           @ModelAttribute CommentSearch search,
                                                           @ModelAttribute Pageable pageable) {
        int currentUserId = SessionUtil.getUserId();
        boolean isLocaleKorea = Locale.KOREA.getCountry().equals(LocaleContextHolder.getLocale().getCountry());
        return ResponseWrapper.success(commentService.getComments(campaignId, search, pageable,
                                                                  currentUserId, isLocaleKorea));
    }

    // :43  캠페인 답글 조회
    @GetMapping("/campaigns/{campaignId}/replys")
    public ResponseWrapper<List<CommentVo>> getCommentReplys(...) { ... }

    // :52  댓글/답글 등록
    @PostMapping("")
    @RequiredLogin
    public ResponseWrapper<CommentVo> createComment(@RequestBody CommentCreate create) {
        int userId = SessionUtil.getUserId();
        return ResponseWrapper.success(commentService.create(create, userId));
    }

    // :61  수정
    @PostMapping("/{boardId}")
    @RequiredLogin
    public ResponseWrapper<CommentVo> modifyComment(@PathVariable Integer boardId,
                                                    @RequestBody CommentModify modify) {
        modify.setBoardId(boardId);
        int userId = SessionUtil.getUserId();
        boolean isLocaleKorea = /* ... */;
        return ResponseWrapper.success(commentService.modify(modify, userId, isLocaleKorea));
    }

    // :73  삭제
    @PostMapping("/{boardId}/delete")
    @RequiredLogin
    public ResponseWrapper<Void> removeComment(@PathVariable Integer boardId) {
        commentService.remove(boardId);
        return ResponseWrapper.success(null);
    }
}
```

### 2.2 Service — `CommentService.create`
```java
// service/CommentService.java:196
@Transactional
public CommentVo create(CommentCreate create, int userId) {
    create.setUserId(userId);
    create.setIp(WebUtils.getClientIP());
    create.setCommonId(create.getUpdateId(), create.getCampaignId());

    if (create.getDepth() == 0) {               // 댓글
        insertComment(create);
        insertCommentImage(create);
    } else {                                     // 답글
        insertReply(create);
        sendCommentReplyNotification(create);   // ★ 답글 수신자에게 알림
    }

    Comment comment = getCommentInfoSimple(create.getBoardId());
    // ★ 서포터 여부 표시 (BackingPayment 조회 — 댓글 UI에 "서포터" 뱃지)
    comment.setSupport(backingPaymentAdapter.isSupport(create.getCampaignId(), userId));
    return commentConvert.toComment(comment, userId);
}

// :215
@Transactional
public void insertComment(CommentCreate create) {
    commentRepository.create(create);
    if (create.getGroupId() == CommentGroupType.COMMENT) {
        // 댓글 타입(일반/업데이트/공지 등) 매핑
        commentRepository.createCommentMapping(
            new CommentMapping(create.getBoardId(), create.getCommentType()));
    }
}

@Transactional
public void insertReply(CommentCreate create) {
    commentRepository.createCommentReply(create);
}
```

### 2.3 수정 시 소유자 검증
```java
@Transactional
public CommentVo modify(CommentModify modify, int userId, boolean isLocaleKorea) {
    int boardId = modify.getBoardId();
    Comment comment = getCommentInfoSimple(boardId);
    isOwner(comment.getUserId(), boardId, userId);   // ★ 다른 사용자 댓글 수정 방어

    commentRepository.modify(modify);
    if (modify.getCommentType() != null) {
        commentRepository.modifyCommentMappingType(
            new CommentMapping(boardId, modify.getCommentType()));
    }
    // + 이미지 갱신 로직
}
```

---

## 3. Backend 없음 — com.wadiz.web 이 직접 DB 접근
댓글 도메인은 com.wadiz.api.funding / reward 를 거치지 않고 **com.wadiz.web 이 직접 `MiniBoardCommon` 테이블을 조작**한다. 따라서 본 flow 는 3번째 노드가 없는 2-hop 체인 (FE → web → DB).

---

## 4. DB

### 4.1 핵심 테이블

| 테이블 | 역할 |
|---|---|
| `MiniBoardCommon` | 댓글·답글 본문 (`BoardId`, `UserId`, `CommonId`, `GroupId`, `Depth`, `WhenCreated`, `Body`, `Ip`, `ParentBoardId`, `DEL`, `WhenEdited`, `WhenDeleted`) |
| `MiniBoardCommonCommentTypeMapping` | 댓글 타입(`COMMENT`/`NEWS` 등) 매핑 (`BoardId`, `CommentType`) |
| `CommentImage` (추정 `MiniBoardCommonImage`) | 댓글 첨부 이미지 (`BoardId` ↔ `ImageUrl`) |

### 4.2 INSERT SQL (`comment-mapper.xml`)
```xml
<!-- :144  댓글 -->
<insert id="insertComment" useGeneratedKeys="true">
    INSERT INTO MiniBoardCommon (UserId, CommonId, GroupId, Depth, WhenCreated, Body, Ip)
    VALUES (#{userId}, #{commonId}, #{groupId}, #{depth}, NOW(), #{body}, #{ip})
    <selectKey keyProperty="boardId" resultType="java.lang.Integer" order="AFTER">
        SELECT LAST_INSERT_ID() AS boardId
    </selectKey>
</insert>

<!-- :152  답글 -->
<insert id="insertCommentReply" useGeneratedKeys="true">
    INSERT INTO MiniBoardCommon (UserId, CommonId, GroupId, Depth, WhenCreated, Body, Ip, ParentBoardId)
    VALUES (#{userId}, #{commonId}, #{groupId}, #{depth}, NOW(), #{body}, #{ip}, #{parentBoardId})
    <selectKey keyProperty="boardId" resultType="java.lang.Integer" order="AFTER">
        SELECT LAST_INSERT_ID() AS boardId
    </selectKey>
</insert>

<!-- :161  타입 매핑 -->
<insert id="insertCommentMappingType">
    INSERT INTO MiniBoardCommonCommentTypeMapping (BoardId, CommentType)
    VALUES (#{boardId}, #{commentType})
</insert>
```

### 4.3 UPDATE/DELETE (soft delete)
```xml
<!-- :166  수정 -->
<update id="updateComment">
    UPDATE MiniBoardCommon
       SET Body = #{body}, WhenEdited = NOW()
     WHERE BoardId = #{boardId}
</update>

<!-- :172  삭제 (soft delete) -->
<update id="removeComment">
    UPDATE MiniBoardCommon
       SET DEL = TRUE, WhenDeleted = NOW()
     WHERE BoardId = #{boardId}
</update>
```

### 4.4 목록 조회 (관측된 ID만)
- `selectCommentList` (:11) — 댓글 목록 (페이징)
- `selectCommentReplyList` (:101) — 답글 목록
- `selectCountComments` (:74) — 댓글 수
- `selectCommentInfoSimple` (:184) — 단건 조회
- `selectMakerProjectComments` / `countMakerProjectComments` (:217,255) — 메이커 대시보드용

### 4.5 이미지 (`comment-image-mapper.xml`)
- `findAllById` (:13), `insert` (:21), `update` (:26), `remove` (:34)

---

## 엔드투엔드 시퀀스

### 댓글 등록
```
[FE: 프로젝트 상세 → 댓글 입력 → 등록]
   │ POST /web/reward/api/comments
   │    body: { campaignId, body, depth: 0, commentType: 'COMMENT', images: [...] }
   │    (쿠키 세션)
   ▼
[www.wadiz.kr — com.wadiz.web]
   │
   ├─ CommentApiController#createComment                [reward/comment/controller/:52]
   │     @RequiredLogin
   │     userId = SessionUtil.getUserId()
   │
   └─ CommentService#create(create, userId)             [service/:196]
        │  @Transactional
        │  IP 추출 (WebUtils.getClientIP), commonId 조립
        │
        ├─ if (depth == 0) 댓글
        │   ├─ INSERT MiniBoardCommon (UserId, CommonId, GroupId, Depth=0, Body, Ip)
        │   ├─ LAST_INSERT_ID → boardId
        │   ├─ INSERT MiniBoardCommonCommentTypeMapping (boardId, commentType)
        │   └─ INSERT CommentImage (boardId, imageUrl) [이미지 있을 때]
        │
        ├─ else 답글
        │   ├─ INSERT MiniBoardCommon (... ParentBoardId=<원댓글 boardId>)
        │   └─ sendCommentReplyNotification(create)     → 원댓글 작성자에게 알림 (외부 서비스)
        │
        └─ SELECT MiniBoardCommon WHERE BoardId = boardId  (getCommentInfoSimple)
        └─ backingPaymentAdapter.isSupport(campaignId, userId)
              └─ (BackingPayment 조회 — 서포터 뱃지 표시용)

   → Response: CommentVo { boardId, body, writer, isSupport, createdAt, ... }
   → FE: 목록 프런트단 prepend / 쿼리 invalidate
```

### 댓글 수정
```
[FE]
   │ POST /web/reward/api/comments/{boardId}
   │    body: { body, commentType?, images? }
   ▼
[CommentApiController#modifyComment (:61)] @RequiredLogin
   └─ CommentService#modify(modify, userId, isLocaleKorea)
        │  @Transactional
        │
        ├─ SELECT WHERE BoardId=? (getCommentInfoSimple)
        ├─ isOwner(comment.userId, boardId, userId)  → 불일치 시 예외 (소유자 방어)
        ├─ UPDATE MiniBoardCommon SET Body=?, WhenEdited=NOW() WHERE BoardId=?
        ├─ (commentType 변경 시) UPDATE MiniBoardCommonCommentTypeMapping
        └─ CommentImage UPDATE/INSERT/REMOVE (이미지 diff)
```

### 댓글 삭제 (소프트 삭제)
```
[FE]
   │ POST /web/reward/api/comments/{boardId}/delete
   ▼
[CommentApiController#removeComment (:73)] @RequiredLogin
   └─ CommentService#remove(boardId)
        └─ UPDATE MiniBoardCommon SET DEL=TRUE, WhenDeleted=NOW() WHERE BoardId=?
             (물리 삭제 하지 않음 — 감사 추적 + 관련 답글 관계 보존)
```

### 목록 조회
```
[FE]
   │ GET /web/reward/api/comments/campaigns/{id}?page=&size=&sort=...
   │     (비로그인도 허용)
   ▼
[CommentApiController#getCommentList (:32)]
   └─ commentService.getComments(campaignId, search, pageable, userId, isLocaleKorea)
        ├─ SELECT COUNT → selectCountComments
        ├─ SELECT 리스트 → selectCommentList
        │   (CommonId·GroupId 로 campaignId 필터, DEL=FALSE, 페이징·정렬)
        └─ 각 행에 isSupport (BackingPaymentAdapter) · isMine 플래그 조립
```

---

## 경계·미탐색

1. **`CommonId`·`GroupId` 의미** — `MiniBoardCommon` 는 범용 게시판 테이블 (뉴스/댓글/리뷰 공용). `GroupId` 로 COMMENT/NEWS/REPLY 타입 구분, `CommonId` 는 상위 참조(예: 캠페인 ID + 업데이트 ID 조합). 정확한 조합 로직은 `CommentCreate.setCommonId` 구현에서 확인.
2. **`backingPaymentAdapter.isSupport`** — 댓글마다 "서포터 여부" 배지를 붙이기 위해 댓글 등록 시에도 BackingPayment 를 조회. 목록 조회 시 N+1 방지(caching) 여부 확인 필요.
3. **답글 알림** — `sendCommentReplyNotification` 구현체가 어느 알림 서비스(platform notification / wave.user push)에 의존하는지 추적 필요.
4. **이미지 저장 경로** — CommentImage 의 `ImageUrl` 이 S3/CloudFront 인지, FE 가 사전에 프리사인드 URL 로 업로드한 결과를 저장하는 방식인지 확인.
5. **XSS/HTML 방어** — `Body` 저장 시 sanitize 여부 (어디 계층에서) 별도.
6. **메이커 뉴스 댓글** (`MakerNewsCommentApiController`) — 동일 `MiniBoardCommon` 를 공유하지만 엔드포인트·권한 다름. 별도 flow 대상.
7. **신고/블라인드** — 부적절 댓글 신고·블라인드 처리 경로. `DEL` 외 별도 플래그(예: `BlockReason`) 컬럼 여부는 `MiniBoardCommon` 전체 스키마 확인 후.
8. **서포터 서명 댓글(V2)** 는 `/web/v2/supporter-signatures/*/comments` 경로로 wave.user 를 거침([supporter-signature.md](./supporter-signature.md)). 펀딩 댓글(본 문서) 과는 완전히 다른 저장소.
