# com.wadiz.web — MyBatis Mapper 카탈로그

> **264 XML / 47 도메인 / 1,082 statement / 917 `<if>` 동적쿼리 / 130 `<sql>` fragment / 147 typeAlias / 19 Stored Procedure**
> 위치: `src/main/resources/sqls/`, `sp/`, `datasource/mybatis-config.xml`

## 1. 도메인별 통계

### 1.1 TOP 15 (volume)
| 도메인 | XML | select | insert | update | delete | total | `<if>` | 비고 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **waccount** | 12 | 107 | 36 | 28 | 5 | 176 | 13 | 회원·소셜·휴면·비밀번호 |
| **ftdashboard** | 2 | 53 | 20 | 23 | 10 | 106 | 9 | 펀딩 담당자 대시보드 |
| **startup** | 14 | 57 | 20 | 21 | 8 | 106 | 10 | 스타트업 IR |
| **ftboard** | 5 | 24 | 16 | 14 | 5 | 59 | **230** | 증권형 게시판 (최고 동적쿼리) |
| **wcampaign** | 8 | 43 | 8 | 3 | 1 | 55 | **179** | 투자 캠페인 검색·기본정보 |
| **community** | 2 | 28 | 12 | 4 | 5 | 49 | **145** | 커뮤니티 (대부분 makercenter 이관) |
| **wpurchase** | 7 | 24 | 10 | 7 | 0 | 41 | 0 | 결제 (정적쿼리 위주) |
| **wpoint** | 2 | 21 | 11 | 4 | 0 | 36 | 3 | 포인트·쿠폰 |
| **wmypage** | 4 | 21 | 5 | 3 | 1 | 30 | 13 | 마이페이지 |
| **campaign** | 4 | 26 | 4 | 1 | 1 | 32 | 4 | 일반 캠페인 |
| **progress** | 3 | 21 | 3 | 2 | 0 | 26 | 9 | 진행 |
| **wboard** | 2 | 11 | 7 | 6 | 0 | 24 | **76** | 지지서명 게시판 |
| **board** | 4 | 18 | 3 | 2 | 0 | 23 | 4 | 일반 게시판 |
| **shipment** | 4 | 13 | 4 | 2 | 0 | 19 | 22 | 배송 |
| **code** | 5 | 17 | 1 | 0 | 0 | 18 | 0 | 공통 코드 |
| (나머지 32개 소그룹) | ~90 | 287 | 77 | 35 | 13 | 412 | 219 | — |
| **합계** | **264** | **632** | **233** | **168** | **49** | **1,082** | **917** | — |

### 1.2 동적쿼리 hot files (TOP 5)
| XML | `<if>` | namespace | 비고 |
|---|---:|---|---|
| `ftboard/ftboardArticle-mapper.xml` | 230 | `ftBoardArticle` | 검색 조건(제목/본문/작성자/게시판/상태) 모두 `<if>` 분기 |
| `wcampaign/WInvestCampaignBaseInfo-mapper.xml` | 107 | `com.wadiz.core.wcampaign.dao.WInvestCampaignBaseInfo` | LONGVARCHAR BLOB 필드 분리 |
| `community/communityArticle-mapper.xml` | 145 | `communityArticle` | 다중 resultMap (Article/Comment/Tag/HeadWord/Editor/Attach/Detail) |
| `ftboard/ftboardArticleComment-mapper.xml` | 74 | `ftboardArticleComment` | 댓글 |
| `wboard/wBoardComment-mapper.xml` | 52 | `wBoardComment` | 지지서명 댓글 |

## 2. typeAlias 등록 — 147개 (mybatis-config.xml)

| 카테고리 | 개수 | 대표 alias |
|---|---:|---|
| **Equity/FT (증권형)** | 35 | `FTCampaignDefaultInfo`, `FTCampaignBaseInfo`, `FTCampaignArticleInfo`, `FTCampaignUpdateInfo`, `FTCampaignFeedbackInfo`, `FTCampaignEvaluationInfo`, `FTInvest`, `FTInvestCampaignSearchInfo` 등 |
| **Campaign** | 16 | `CampaignSignatureParamInfo`, `CampaignSearchInfo`, `CampaignInsertInfo`, `CampaignInfoStep1~5`, `CampaignNPhotoInfo`, `CampaignMemberInfo`, `CampaignStatusChangeInfo`, `CampaignTag` |
| **Payment** | 14 | `REQBCreditPaymentInfo`, `CancelPaymentInfo`, `VacctinputVO`, `BondInfo`, `BwInfo`, `CbInfo`, `EquityInfo`, `InvContractInfo`, `FTPaymentDefaultInfo`, `FTInvestResultInfo` |
| **Account/User** | 8 | `UserInfo`, `DropOutInfo`, `JurorInfo`, `FTUserSmsConfirmInfo`, `FTPersonalUserInfo`, `FTUserAccntAuth`, `WPersonalUserInfo`, `WUserAccntAuth`, `WUserSmsConfirmInfo` |
| **Notification** | 4 | `DvcTokenInfo`, `CellularMessageServiceInfo`, `MailMessageServiceInfo`, `FtCampaignSender` |
| **Reward** | 3 | `CampaignTag`, `CampaignInterestedKeywordInfo`, `UserInterestedInCampaignInfo` |
| **Feedback** | 3 | `FeedbackArticleInfo`, `FEBFeedbackQuestion`, `FeedbackArticleEvaluationInfo`, `FeedbackTalkArticleInfo` |
| **File** | 2 | `PhotoCommonInfo`, `FTUploadPhotoInfo`, `FTUploadFileInfo` |
| **Common (Search/Code/Help/Statistics)** | 58 | `SearchParamInfo`, `CommonSearchInfo`, `FTCommonCodeVO`, `HelpCenterInfo`, `MenuPagesHisInfo`, `MainSearchKeyword` |
| **typeHandler (3)** | — | `WInvestAmountHandler`, `UuidTypeHandler`, `RewardOptionTypeHandler` |

## 3. DataSource 구성

`spring/application/datasource-context.xml`

```
[기본 DB — 크라우드펀딩/결제/계정]
  basicDataSource         (Master Write, 20 init / 1500 maxActive)
  basicDataSourceRepl     (Slave  Read, 20 init / 1000 maxActive)
  routingDataSource       → ReplicationRoutingDataSource → LazyConnectionDataSourceProxy

[Wave User DB — 별도]
  basicDataSourceWave     (Master, 0 init / 300 maxActive)
  basicDataSourceWaveRepl (Slave,  0 init / 300 maxActive)
  routingDataSourceWave   → ReplicationRoutingDataSource → LazyConnectionDataSourceProxy

[SqlSessionFactory]
  sqlSessionFactory       → mapperLocations: classpath:/sqls/**/*.xml
                          → configLocation:  classpath:/datasource/mybatis-config.xml
  sqlSessionFactoryWave   → mapperLocations: classpath:/sqls/wave/**/*.xml
                          → 별도 transactionManager
```

- **MySQL connector 5.1.48** + **InnoDB** (가정)
- **DB2 병용**: `sqls_db2/**/*.xml` 일부 — 과거 IBM DB2 통계용 (사용 여부는 빌드 include 에서만 확인)
- **암호화**: `org.jasypt jasypt-spring31 1.9.2` (encKey=`!wadiz@`) — JDBC URL/패스워드 보호

## 4. Stored Procedure — 19개 (`sp/`)

| 분류 | 파일 | 용도 |
|---|---|---|
| **캠페인 처리** | `ProcCampaignContributionInsert.sql` | 캠페인 펀딩액 집계 (일배치) |
|  | `ProcCampaignContributionInsertForAllProjects.sql` | 전체 프로젝트 펀딩액 |
|  | `ProcCampaignPopScoreInsert.sql` | 인기도 점수 |
|  | `ProcCampaignRandomInit.sql` | 추천 캠페인 초기화 |
|  | `ProcEqCampaingStatus.sql` | 증권형 캠페인 상태 |
|  | `ProcInvestCampaignStartProcessing.sql` | 투자형 시작 |
|  | `ProcInvestCampaignFinishProcessing.sql` | 투자형 종료 |
| **통계 일배치** | `ProcStatsDailyFundingPerformanceInsert.sql` | 일일 펀딩 성과 |
|  | `ProcStatsDailyInvestPerformanceInsert.sql` | 일일 투자 성과 |
|  | `ProcStatsDailyRewardPerformanceInsert.sql` | 일일 리워드 성과 |
|  | `ProcStatsUserPerformanceInsert.sql` | 사용자 성과 |
| **유저 추출** | `getCampaignAllUsers.sql` | 캠페인 전체 사용자 |
|  | `getCampaignFinishSignatureUsers.sql` | 투자 완료 사용자 |
|  | `getCampaignInterestedUsers.sql` | 관심 사용자 |
|  | `getInvestPremiumCampaignFinishInvestUsers.sql` | 프리미엄 투자 완료 |
| **기타** | `InitCouponNo.sql` | 쿠폰 번호 초기화 |
|  | `ProcSetSummationSignature.sql` | 투자 서명 집계 |
|  | `ProcCancelInvestCoupon.sql` | 투자 쿠폰 취소 |
|  | `wadiz_raise_err.sql` | 오류 발생 유틸 |

**호출 위치 (CALLABLE)**:
- `sqls/code/ftcommon-mapper.xml` — `<select id="execureCampaignStatusProcedure" statementType="CALLABLE">`
- `sqls/wpoint/wcoupon-mapper.xml` — `<select id="callProcCancelInvestCoupon" statementType="CALLABLE">`

## 5. 공통 SQL Fragment

| 통계 | 값 |
|---|---:|
| `<sql>` 정의 | 130 |
| `<include refid>` 사용 | 130 (1:1 재사용도) |

**패턴**:
1. **Column List**: `<sql id="Base_Column_List">id, name, ...</sql>` + `<include refid="Base_Column_List"/>`
2. **WHERE 조건**: 검색 필터 공통화
3. **JOIN 부분**: 다중 SELECT 에서 같은 JOIN 재사용

대표 (waccount/, startup/, wcampaign/ 12+14+8 = 34개)에서 컬럼 리스트 재사용 집중.

## 6. 동적쿼리 패턴 — 917개 `<if>` 의 용도

```xml
<!-- 1. 검색 조건 동적화 -->
<select id="selectArticles">
  SELECT * FROM TbArticle
  WHERE 1=1
  <if test="searchText != null">AND Title LIKE CONCAT('%', #{searchText}, '%')</if>
  <if test="boardId != null">AND BoardId = #{boardId}</if>
  <if test="authorId != null">AND UserId = #{authorId}</if>
</select>

<!-- 2. 날짜 범위 -->
<if test="startDate != null and endDate != null">
  AND RegDate BETWEEN #{startDate} AND #{endDate}
</if>

<!-- 3. 정렬 분기 -->
<choose>
  <when test="sort == 'latest'">ORDER BY RegDate DESC</when>
  <when test="sort == 'popular'">ORDER BY ViewCount DESC</when>
  <otherwise>ORDER BY RegDate DESC</otherwise>
</choose>

<!-- 4. 권한 기반 -->
<if test="isAdmin == false">
  AND PublishedYn = 'Y' AND DelYn = 'N'
</if>

<!-- 5. 페이징 -->
<if test="offset != null and limit != null">
  LIMIT #{offset}, #{limit}
</if>
```

## 7. resultMap — 다중·중첩 매핑 hotspot

**파일별 resultMap 개수 TOP 5**:
| 파일 | 개수 | 대표 매핑 |
|---|---:|---|
| `ftcampaign/ftcampaign-mapper.xml` | 26 | `FTCampaignDefaultInfo`, `FTCampaignArticleInfo`, `FTCampaignUpdateVO`, `FTInvest` |
| `campaign/campaign-mapper.xml` | 9 | `CampaignInfo`, `CampaignMemberInfo`, `CampaignInterestedInfo` |
| `wboard/wBoard-mapper.xml` | 9 | `WBoardArticle`, `WBoardComment`, `UserInfo` |
| `ftboard/ftboardArticle-mapper.xml` | 9 | `FTBoardArticle`, `FTBoardComment`, `FTBoardViewUser` |
| `rewarditem/reward-mapper.xml` | 8 | `RewardInfo`, `RewardOptionInfo` |

**중첩 association 예시** (`community/communityArticle-mapper.xml`):
```xml
<resultMap id="ArticleResultMap" type="WBoardArticle">
  <id column="ArticleSeq" property="articleSeq" />
  <result column="Title" property="title" />
  <association property="headWord" columnPrefix="headWord_"
               resultMap="HeadWordResultMap"/>
</resultMap>
<resultMap id="HeadWordResultMap" type="WBoardHeadWord">
  <id column="HeadWordId" property="headWordId" />
  <result column="HeadWord" property="headWord" />
</resultMap>
```

## 8. 도메인별 매퍼 카탈로그 (47 개 도메인)

### 8.1 사용자·인증
- `account/` — `account-mapper.xml`, `userageverification-mapper.xml`, `userprofile-mapper.xml`
- `waccount/` (12 XML) — `waccount-mapper.xml`, `waccountCommon-mapper.xml`, `waccountEquity-mapper.xml`, `waccountSocial-mapper.xml`, `waccountHistory-mapper.xml`

### 8.2 캠페인 도메인
- `campaign/` — `campaign-mapper.xml` (9 resultMap), `campaignInfo-mapper.xml`, `campaignCongratulation-mapper.xml`, `maker-studio-mapper.xml`, `campaign-marker-mapper.xml`
- `wcampaign/` (8 XML) — `WInvestCampaignBaseInfo-mapper.xml`(107 if), `WInvestSearchDao-mapper.xml`(30), `WInvest-mapper.xml`(20), `winvestsearch-mapper.xml`(43), `wrewardsearch-mapper.xml`(11)
- `ftcampaign/` — `ftcampaign-mapper.xml` (26 resultMap, 최대), `equityCamapign-mapper.xml`

### 8.3 리워드·결제·환불
- `reward/funding/` — `funding-mapper.xml`
- `reward/payment/` — `payment-mapper.xml`, `payment-refund-mapper.xml`
- `reward/coupon/` — `coupon-mapper.xml`
- `reward/comment/` — `comment-mapper.xml`, `comment-image-mapper.xml`
- `reward/story/` — `story-mapper.xml`
- `reward/rewarditem/` — `reward-mapper.xml` (8 resultMap)
- `reward/screening/` — `screening-mapper.xml`
- `reward/settlement/` — `settlement-mapper.xml`
- `reward/refund/` — `refund-mapper.xml`
- `reward/comingsoon/` — `comingsoon-mapper.xml`
- `reward/category/` — `category-mapper.xml`
- `reward/shipment/` — (4 XML) `shipment-mapper.xml`, ...
- `reward/openreservation/` — `openreservation-mapper.xml`
- `reward/makercommunication/` — `makercommunication-mapper.xml`

### 8.4 투자형(증권형)
- `equity/payment/` — `wpayment-mapper.xml`, `ftpayment-mapper.xml`
- `equity/premium/` — `premiumMembership.xml`, `wpremiummain-mapper.xml`, `premiumContentsBoard.xml`
- `equity/news/` — `equityNews-mapper.xml`
- `equity/investor/` — `equityInvestor-mapper.xml`, `equityMember-mapper.xml`
- `equity/dashboard/` — `equityDashboard-mapper.xml`
- `ftdashboard/` (2 XML) — 53 select, 23 update — 펀딩 담당자 대시보드 hot

### 8.5 게시판·커뮤니티
- `community/` (2 XML) — `communityArticle-mapper.xml` (145 if, 7 resultMap)
- `board/` (4) — `boardMaster-mapper.xml`, `boardArticle-mapper.xml`, `boardComment-mapper.xml`, `supportSignature-mapper.xml`
- `wboard/` (2) — `wBoard-mapper.xml`, `wBoardComment-mapper.xml` (52 if)
- `ftboard/` (5) — `ftboardArticle-mapper.xml` (230 if 최대), `ftboardArticleComment-mapper.xml` (74)

### 8.6 마이페이지
- `mywadiz/dashboard/` — `maker-dashboard-mapper.xml`
- `wmypage/` (4 XML) — `winvest-mapper.xml`, `wreward-mapper.xml`

### 8.7 메인·검색
- `wmain/` — `wiosmain-mapper.xml`

### 8.8 비즈니스 보조
- `progress/` (3) — `progress-tip-mapper.xml`, `progress-mapper.xml`
- `notification/` — `app-mapper.xml` (푸시토큰), `newsletterSubscriber-mapper.xml`, `message-mapper.xml`, `sts-temp-mapper.xml`
- `statistics/` — `wadizexception-mapper.xml`, `wOpinion-mapper.xml`, `MenuPagesHis-mapper.xml`, `RefererHis-mapper.xml`
- `startup/` (14) — `corporationContract-mapper.xml`, `irRequest-mapper.xml`, `corporation-mapper.xml`, `corporationInvestor-mapper.xml`, `corporationInquiry-mapper.xml`, `corporationTeamMember-mapper.xml`
- `wsub/` — `weasycard-mapper.xml`, `wevent-mapper.xml`
- `wpartner/` — `wpartner-mapper.xml` (91 if)
- `popup/` — `popup-mapper.xml`
- `wcoming/` — `wcomingSoon-mapper.xml`, `comingSoon-mapper.xml`
- `wevent/` — `eventInfo-mapper.xml`, `eventCompensation-mapper.xml`
- `letz/` — 마케팅
- `follow/` — 팔로우
- `feedback/` — 피드백
- `membership/` — 멤버십
- `code/` (5) — `ftcommon-mapper.xml` (CALLABLE), 공통 코드
- `ftcommon/` — 투자형 공통
- `country/` — 국가코드
- `school/` — 와디즈 스쿨 (레거시)
- `userreport/` — 신고
- `rest/` — REST 공통
- `wpoint/` (2) — `wcoupon-mapper.xml` (CALLABLE)
- `wpurchase/` (7) — JSP+AJAX 결제 변형 (정적 쿼리)

## 9. DAO Interface ↔ Mapper Namespace 매핑

| DAO | Namespace | XML |
|---|---|---|
| `WInvestCampaignBaseInfoDao` | `com.wadiz.core.wcampaign.dao.WInvestCampaignBaseInfo` | `wcampaign/WInvestCampaignBaseInfo-mapper.xml` |
| `WInvestDao` | `com.wadiz.core.wcampaign.dao.WInvest` | `wcampaign/WInvest-mapper.xml` |
| `FTBoardArticleDao` | `ftBoardArticle` | `ftboard/ftboardArticle-mapper.xml` |
| `FTBoardArticleCommentDao` | `ftboardArticleComment` | `ftboard/ftboardArticleComment-mapper.xml` |
| `CampaignDao` | `com.wadiz.core.campaign.dao.CampaignDao` | `campaign/campaign-mapper.xml` |
| `WaccountDao` | `waccount` | `waccount/waccount-mapper.xml` |
| `CommunityArticleDao` | `communityArticle` | `community/communityArticle-mapper.xml` |
| ... 250+ 매핑 | — | — |

## 10. 운영 인사이트

### 10.1 hot domain (마이그레이션 대기 1순위)
- `community` — co.wadiz.api.community 로 일부 이관 진행 중 (Signature V3 부터)
- `ftboard` — 230 `<if>` 단일 파일, 증권형 게시판 풀 동적쿼리
- `ftdashboard` — 펀딩 담당자 대시보드 hot
- `wcampaign` — 투자 캠페인 검색 동적쿼리 누적
- `waccount` — 계정 12 XML 다소 분산

### 10.2 LONGVARCHAR/BLOB 분리 패턴
`WInvestCampaignBaseInfo-mapper.xml` 의 `<sql id="Base_Column_List">` vs `Blob_Column_List` 분리:
- `Base_Column_List`: id, name, status, createdAt 등 메타
- `Blob_Column_List`: `CompanyProfile`, `BusinessDetail`, `MarketAnalysis`, `Milestone`, `Plan`, `FinPos`, `StrategyAndRisk` 등 LONGVARCHAR
- 목록 조회시는 Base 만, 상세 조회시 Blob 까지 — N+1 회피용

### 10.3 routingDataSource 의 read/write 자동 분기
- `@Transactional(readOnly=true)` → slave 라우팅
- 그 외 → master
- write 후 즉시 read 시 replication lag 위험 — `LazyConnectionDataSourceProxy` 로 일부 완화

### 10.4 sqls_db2/ 별도
일부 통계는 IBM DB2 (구 BI 시스템) — 빌드 include 확인 필요. 일상 트래픽에는 영향 없음.

## 11. 외부 참조

- 컨트롤러 → DAO/Mapper 호출: `../api-endpoints.md`
- 화면별 DB 흐름: `screen-*.md`
