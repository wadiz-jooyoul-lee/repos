# Flow: 스토어 프로젝트 상세

> 와디즈 스토어(상시 판매) 상품의 상세 화면입니다. 사용자가 `/web/store/detail/{projectNo}` 로 들어오면 열립니다.
> **서버는 빈 껍데기만 내려주고 실제 화면은 리액트가 그립니다.** 검색엔진 크롤러에게만 서버가 내용을 채워 보냅니다.

## 기록 범위

- **분석 기준**: 2026-09-22. 세 저장소 모두 `cloud_live` 브랜치 최신입니다.

| 저장소 | 커밋 | 날짜 |
|---|---|---|
| `com.wadiz.web` | `fed6ce861c` | 2026-09-21 |
| `wadiz-frontend` | 최신 `cloud_live` | 2026-09-21 |
| `com.wadiz.store` | `3f3c59f97` | 2026-09-18 |

- **읽은 파일**
  - `com.wadiz.web/src/main/java/com/wadiz/web/globalkorea/controller/GlobalKoreaStoreDetailController.java`
  - `com.wadiz.web/src/main/java/com/wadiz/web/store/client/StoreClient.java`
  - `com.wadiz.web/src/main/java/com/wadiz/web/store/project/service/StoreProjectService.java`
  - `com.wadiz.web/src/main/java/com/wadiz/core/httpproxy/ApiProxyServlet.java`
  - `com.wadiz.web/src/main/resources/proxy/proxy-clive.xml`
  - `wadiz-frontend/apps/global/src/app/korea-routes/store.tsx`
  - `wadiz-frontend/apps/global/src/pages/store/[projectNo]/_api/storeDetailLayoutLoader.ts`
  - `wadiz-frontend/packages/features/src/store/detail/lib/hooks/queries/useStoreDetail.js`
  - `wadiz-frontend/packages/api/src/web/store/projects.service.ts`
  - `com.wadiz.store/store-api/src/main/java/com/wadiz/store/api/rest/project/ProjectController.java`

- **외부 경계**: 스토어 상품 데이터베이스 내부 구조는 `com.wadiz.store` 문서로 넘깁니다. 이 문서는 호출 체인만 다룹니다.

> ⚠️ **이 문서는 2026-09-22 에 전면 갱신했습니다.**
> 2026-04-23 최초 작성본은 상세 화면을 JSP 로 설명했습니다. 그 전제가 2026-05-22 에 무너졌습니다.
> 커밋 `61fcb1731e`(FE1-688)가 `StoreProjectUiController` 를 지우고 리액트 화면으로 옮겼습니다.

---

## 1. Client Trigger

### 1.1 `wadiz-frontend` (웹)

**라우트 정의** — `apps/global/src/app/korea-routes/store.tsx:42-53`

```tsx
{
  path: 'detail/:projectNo',
  element: <StoreDetailLayout isMobile={isMobile} />,
  loader: storeDetailLayoutLoader(queryClient),
  shouldRevalidate: ({ currentParams, nextParams }) => currentParams.projectNo !== nextParams.projectNo,
  children: [
    { index: true, element: <StoreDetailPage /> },
    { path: 'story', element: <StoreDetailPage /> },
    { path: 'satisfaction', element: <StoreDetailPage /> },
    { path: 'refund', element: <StoreDetailPage /> },
  ],
},
```

- 탭 네 개가 모두 **같은 화면 컴포넌트**(`StoreDetailPage`)를 씁니다. 탭 구분은 컴포넌트 안에서 합니다.
- `shouldRevalidate` 가 있어 **프로젝트 번호가 바뀔 때만** 데이터를 다시 받습니다. 탭만 옮기면 다시 받지 않습니다.

**화면 파일**

| 파일 | 역할 |
|---|---|
| `apps/global/src/pages/store/[projectNo]/StoreDetailLayout.tsx` | 바깥 틀. PC 와 모바일 레이아웃을 가릅니다 |
| `apps/global/src/pages/store/[projectNo]/StoreDetailDesktopLayout.tsx` | PC 레이아웃 |
| `apps/global/src/pages/store/[projectNo]/StoreDetailMobileLayout.tsx` | 모바일 레이아웃 |
| `apps/global/src/pages/store/[projectNo]/StoreDetailMeta.tsx` | 화면 메타 정보 |
| `packages/features/src/store/detail/DetailWithProvider` | 실제 상세 화면 본체 |

**화면에 들어가기 전 미리 받는 데이터 12가지**

`packages/features/src/store/detail/lib/hooks/queries/useStoreDetail.js` 의 `getStoreDetailQueries` 입니다.
라우터의 `loader` 가 이 목록을 전부 미리 받아 둡니다. 유효 시간은 3분입니다.

| 받는 데이터 | 호출 |
|---|---|
| 프로젝트 기본 정보 | `projectsService.getStoreProjectQuery` |
| 스토리 본문 | `projectsService.getStoreProjectContentQuery` |
| 프로젝트 설정 | `projectsService.getStoreProjectSettingQuery` |
| 메이커 연락처 | `projectsService.getStoreProjectMakerContactQuery` |
| 판매자 정보 | `projectsService.getStoreProjectSellerInfoQuery` |
| 원본 펀딩 | `projectsService.getStoreProjectBaseFundingQuery` |
| 배송 정보 | `projectsService.getStoreProjectShippingQuery` |
| 상품 목록 | `projectsService.getStoreProjectProductsQuery` |
| 상품 집계 | `projectsService.getStoreAggregationQuery` |
| 주문 집계 | `ordersService.getOrdersAggregationQuery` |
| 만족도 집계 | `storeService.getStoreSatisfactionsAggregationQuery` |
| 기획전 배너 | `collectionService.getExhibitionBannersQuery('STORE', projectNo)` |

**성인 인증 게이트** — `apps/global/src/pages/store/[projectNo]/_api/storeDetailLayoutLoader.ts`

```ts
const isAdultVerificationRequired =
  LocaleSettings.isKorea && projectData?.isAdultContent
    ? await getIsAdultVerificationRequired(projectData.category?.code ?? '')
    : false;
```

- **국내 접속이면서 성인 콘텐츠일 때만** 판정합니다. 글로벌 접속은 아예 판정하지 않습니다.
- 인증이 필요하면 `goToAdultVerificationPage` 로 보내고 화면을 열지 않습니다.
- 예외가 셋 있습니다. 비로그인 상태, 미리보기 모드, 와디즈 앱 안에서는 보내지 않습니다.
- 프로젝트 번호가 숫자가 아니면 `/web/store/main` 으로 되돌립니다.

**호출 경로** — `packages/api/src/web/store/projects.service.ts`

모두 `/web/apip/store/...` 로 나갑니다. 같은 출처(same-origin) 상대 경로입니다.

| 경로 | 줄 |
|---|---|
| `GET /web/apip/store/projects/{projectNo}` | 93 |
| `GET /web/apip/store/projects/{projectNo}/content` | 117 |
| `GET /web/apip/store/projects/{projectNo}/setting` | 129 |
| `GET /web/apip/store/projects/{projectNo}/products` | 105 |
| `GET /web/apip/store/projects/{projectNo}/products/aggregation` | 51 |
| `GET /web/apip/store/projects/{projectNo}/shipping-info` | 141 |
| `GET /web/apip/store/projects/{projectNo}/claim-as-guide` | 153 |
| `GET /web/apip/store/projects/{projectNo}/product-info-notice` | 165 |
| `GET /web/apip/store/projects/{projectNo}/maker-contact` | 177 |
| `GET /web/apip/store/projects/{projectNo}/base-funding` | 189 |
| `GET /web/apip/store/projects/{projectNo}/maker-business-info` | 201 |
| `GET /web/apip/store/projects/by-funding?campaignId=` | 74 |
| `GET /web/apip/store/projects/my` | 22 |

만족도와 댓글은 `packages/api/src/web/store.service.ts` 입니다.

| 경로 | 줄 | 용도 |
|---|---|---|
| `GET /web/apip/store/satisfactions` | 72 | 만족도 목록 |
| `GET /web/apip/store/satisfactions/aggregation` | 191 | 만족도 집계 |
| `PUT /web/apip/store/reactions` | 76 | 리액션 등록 |
| `POST /web/apip/store/satisfactions/{commentId}/replies` | 81 | 답글 작성 |
| `GET /web/apip/store/satisfactions/{commentId}/replies` | 85 | 답글 목록 |
| `PUT /web/apip/store/satisfactions/replies/{replyId}` | 96 | 답글 수정 |
| `DELETE /web/apip/store/satisfactions/replies/{replyId}` | 102 | 답글 삭제 |

같은 파일 69번째 줄 주석에 이유가 적혀 있습니다.
`/web/apip/*` 는 **웹과 어드민 양쪽에 프록시가 있어서** 상대 경로로 부른다고 합니다.

### 1.2 `wadiz-android` / `wadiz-ios` (앱)

**두 앱 모두 웹뷰로 엽니다.** 네이티브 화면이 아닙니다.

| 앱 | 경로 상수 |
|---|---|
| Android | `core/model/src/main/java/com/markmount/wadiz/model/web/UrlKey.kt:63` — `STORE_DETAIL` |
| Android | `core/legacy/wadiz-common/src/main/java/com/markmount/wadiz/common/constant/WadizConstant.kt:156` |
| iOS | `Projects/App/Sources/Common/Constants/URLConstant.swift:18` — `storeDetail` |

앱에서 여는 주소도 웹과 같은 `/web/store/detail/{projectNo}` 입니다.
그래서 **앱 화면도 이 문서의 흐름을 그대로 탑니다.**

---

## 2. Hub — `com.wadiz.web`

### 2.1 화면 껍데기를 내려주는 컨트롤러

`src/main/java/com/wadiz/web/globalkorea/controller/GlobalKoreaStoreDetailController.java`

```java
@RequestMapping(value = {
  "/store/detail/{projectNo:\\d+}",          // :53
  "/store/detail/{projectNo:\\d+}/story",
  "/store/detail/{projectNo:\\d+}/satisfaction",
  "/store/detail/{projectNo:\\d+}/refund",
}, method = RequestMethod.GET)
public ModelAndView getStoreDetailPage(@PathVariable("projectNo") Long projectNo, HttpServletRequest request) {
    ...
    mv.setViewName("global-korea/index");    // :89
    return mv;
}
```

- **뷰 이름이 `global-korea/index` 입니다.** 리액트 앱을 띄우는 껍데기 화면입니다.
- 클래스 이름에 `GlobalKorea` 가 붙은 이유는 2026-05-22 커밋 `61fcb1731e`(FE1-688) 때문입니다.
  펀딩 상세와 스토어 상세의 컨트롤러를 `globalkorea` 묶음으로 합쳤습니다.

**서버가 화면에 넘기는 값**

| 값 | 내용 | 줄 |
|---|---|---|
| `canonicalUrl` | `{site_url}/web/store/detail/{projectNo}` | 63 |
| `conditionalCacheable` | 항상 `true` | 64 |
| `storeProject` | 스토어 API 에서 받은 프로젝트 정보 | 67 |
| `meta` | 제목·설명·OG 이미지·트위터 이미지 | 82 |

메타 정보는 다국어 메시지에서 만듭니다.

```java
meta.put("title", htmlMetadataMessageResolver.resolve(
    "store_detail_{project_no}_page.meta.title", Locale.KOREAN,
    storeProject.getTitle(), storeProject.getMaker().getName()));   // :76
```

메시지 정의는 `src/main/resources/messages/html-metadata_ko.properties:39-40` 입니다.

```
store_detail_{project_no}_page.meta.title={{ arg_0 }} by {{ arg_1 }} | 와디즈
store_detail_{project_no}_page.meta.description=펀딩을 성공적으로 마치며 600만의 앞선 만족을 이끌어낸 성공 프로젝트를 지금 바로 구매해 보세요.
```

이 구조는 2026-09 의 `CLIENT-229` 작업으로 들어왔습니다.
JSP 안에서 국내와 글로벌을 가르던 것을 메시지 파일로 옮긴 것입니다.

### 2.2 검색엔진 크롤러에게는 서버가 내용을 채워 보냅니다

리액트 화면은 크롤러가 읽지 못합니다. 그래서 봇이면 별도 처리를 합니다.

```java
if (Boolean.TRUE.equals(request.getAttribute("isBot"))) {   // :85
    addBotAttribute(projectNo, mv);
}
```

`addBotAttribute` 가 담는 데이터는 다섯 가지입니다. 각각 따로 `try-catch` 로 감쌉니다.
**하나가 실패해도 나머지는 담깁니다.**

| 담는 값 | 호출 | 줄 |
|---|---|---|
| `productAggregation` | `storeClient.getProductAggregation` | 106 |
| `projectStory` | `storeClient.getContent` | 112 |
| `satisfactionAggregation` | `storeClient.getSatisfactionAggregation` | 118 |
| `satisfactions` | `storeClient.getSatisfactions` | 124 |
| `productInfoNotice` | `storeClient.getProductInfoNotice` | 133 |

만족도 목록은 **삭제된 것과 숨겨진 것을 걸러냅니다**(126번째 줄).

```java
.filter(satisfaction -> !Boolean.TRUE.equals(satisfaction.getIsDeleted())
                     && !Boolean.TRUE.equals(satisfaction.getIsHidden()))
```

### 2.3 접근 거부는 따로 골라냅니다

```java
private StoreProjectResponse getProject(Long projectNo) {
    try {
        return storeProjectService.getProject(projectNo);
    } catch (StoreAccessDeniedException e) {                       // :96
        throw new NotPermittedStoreException(NotPermittedType.STORE_PROJECT_ACCESS_DENIED);
    } catch (Exception e) {                                        // :98
        log.error("[스토어 프로젝트 조회 오류] projectNo={}, error={}", projectNo, e.getMessage());
        return new StoreProjectResponse();
    }
}
```

- **접근 거부만 전용 예외로 올립니다.** 사용자에게 권한 없음을 알려야 하기 때문입니다.
- 나머지 오류는 빈 응답으로 삼키고 로그만 남깁니다. 화면 자체는 뜹니다.

### 2.4 스토어 API 호출 — `StoreClient`

`src/main/java/com/wadiz/web/store/client/StoreClient.java`

호출 방식은 **RestTemplate 두 개**입니다.

```java
private final RestTemplate restTemplate = new RestTemplate();        // :25
private final RestTemplate shortTimeoutRestTemplate;                 // :26

public StoreClient() {
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(1000);
    factory.setReadTimeout(1000);
    shortTimeoutRestTemplate = new RestTemplate(factory);            // :33
}
```

- 기본 것은 타임아웃을 지정하지 않습니다.
- 1초짜리는 **`getMakerProjectStatusCounts` 한 곳에서만** 씁니다(189번째 줄).
  메이커 화면의 곁가지 정보라 빨리 포기하도록 둔 것으로 보입니다. 이 판단은 추측입니다. 호출 지점이 하나뿐이라는 사실에서 유추했습니다.

주소는 환경별 설정에서 옵니다(`@Value("#{file['store_api_base_uri']}")`, 36번째 줄).

| 환경 | 설정 파일 | 값 |
|---|---|---|
| clive(클라우드 운영) | `properties/file-clive.properties:249` | `http://store-api.core-live.svc.cluster.local` |
| stage | `properties/file-stage.properties:257` | `http://store-api.core-live.svc.cluster.local` |
| rc4 | `properties/file-rc4.properties:235` | `http://store-api.core-rc4.svc.cluster.local` |
| local | `properties/file-local.properties:248` | `https://api.dev.wadiz.io/store` |
| real(온프레미스) | `properties/file-real.properties:314` | `http://172.31.1.12:9990/store` |

`StoreProjectService` 는 껍데기입니다. `StoreClient.getProject` 를 그대로 부릅니다.

### 2.5 데이터 경로 — `ApiProxyServlet`

`/web/apip/*` 요청은 자바 로직을 거치지 않고 그대로 넘깁니다.

```xml
<!-- web/WEB-INF/web.xml:196-204 -->
<servlet>
    <servlet-name>api-proxy</servlet-name>
    <servlet-class>com.wadiz.core.httpproxy.ApiProxyServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>api-proxy</servlet-name>
    <url-pattern>/web/apip/*</url-pattern>
</servlet-mapping>
```

**경로의 첫 조각이 곧 서비스 이름입니다.**

```java
// com/wadiz/core/httpproxy/ApiProxyServlet.java:63
private static final Pattern SERVICE_URI_PATTERN =
    Pattern.compile("^/(?<serviceName>[^/]*)(?<pathInfo>/.*)$");
```

`/web/apip/store/projects/123` 이면 서비스 이름은 `store`, 나머지 경로는 `/projects/123` 입니다.
서비스 이름을 실제 주소로 바꾸는 표는 환경별 XML 에 있습니다.

```xml
<!-- src/main/resources/proxy/proxy-clive.xml -->
<entry key="funding" value="http://funding-api.core-live.svc.cluster.local/api"/>
<entry key="order"   value="http://order-api.core-live.svc.cluster.local/api"/>
<entry key="store"   value-ref="storeHost"/>

<bean id="storeHost" class="com.wadiz.core.httpproxy.ApiProxyProperties$Host">
    <property name="uri" value="http://store-api.core-live.svc.cluster.local/api"/>
    <property name="allowedCookies">
        <set>
            <value>LPINFO</value>
            <value>JSESSIONID</value><!-- for test -->
        </set>
    </property>
</bean>
```

- `store` 만 `Host` 객체를 씁니다. **넘길 쿠키를 골라내야 하기 때문**입니다.
- `funding` 과 `order` 는 주소 문자열만 있습니다.
- 넘기지 않는 헤더가 따로 있습니다(`ApiProxyServlet.java:64`). `Cookie`, `Set-Cookie`, `Authorization` 셋입니다.

### 2.6 자동 로그인 대상 경로

스토어 상세는 자동 로그인을 적용하는 경로 목록에 들어 있습니다.

```java
// src/main/java/com/wadiz/web/fw/filter/rememberme/AutoLoginWebPageMatcher.java:45-47
"/web/store/detail/*",
"/web/store/detail/*/satisfaction",
"/web/store/detail/*/refund",
```

글로벌 쪽(`AutoLoginGlobalPageMatcher.java:50-52`)에는 같은 세 줄이 **주석 처리**돼 있습니다.
즉 자동 로그인은 국내 지면에만 적용됩니다.

---

## 3. Backend — `com.wadiz.store`

> 2026-04-23 최초 작성본은 이 서비스를 "본 레포에 없음, 추정 repo `com.wadiz.api.store`" 로 적었습니다.
> **실제 이름은 `com.wadiz.store` 이고 지금은 도서관에 있습니다.** 분석 문서는 [`docs/com.wadiz.store/`](../com.wadiz.store/com.wadiz.store.md) 입니다.

| 항목 | 값 |
|---|---|
| 저장소 | `wadiz-service/com.wadiz.store` |
| 배포 이름 | `store-api` (플랫폼 `core`) |
| 규모 | 73개 컨트롤러 · 254개 엔드포인트 |
| 서버 포트 | 9080 |

### 상세 화면이 부르는 컨트롤러 셋

**`store-api/src/main/java/com/wadiz/store/api/rest/project/ProjectController.java`** — `/api/projects`

| 메서드 | 경로 | 줄 |
|---|---|---|
| GET | `/{projectNo}` | 33 |
| GET | `/{projectNo}/content` | 44 |
| GET | `/{projectNo}/shipping-info` | 55 |
| GET | `/{projectNo}/setting` | 65 |
| GET | `/{projectNo}/claim-as-guide` | 75 |
| GET | `/{projectNo}/product-info-notice` | 85 |
| GET | `/{projectNo}/base-funding` | 95 |

**`.../rest/product/ProductController.java`** — `/api/projects/{projectNo}/products`

| 메서드 | 경로 | 줄 |
|---|---|---|
| GET | `` (상품 목록) | 34 |
| GET | `/aggregation` | 47 |

**`.../rest/satisfaction/SatisfactionController.java`** — `/api/satisfactions`

| 메서드 | 경로 | 줄 |
|---|---|---|
| GET | `` (목록) | 67 |
| GET | `/aggregation` | 106 |
| POST | `` (작성) | 127 |
| PUT | `{satisfactionNo}` | 150 |
| DELETE | `{satisfactionNo}` | 172 |

메이커 정보는 `.../rest/project/ProjectMakerController.java` 가 맡습니다.
`/{projectNo}/maker-contact`(29번째 줄)와 `/{projectNo}/maker-business-info`(39번째 줄)입니다.

---

## 4. DB

| 항목 | 값 | 근거 |
|---|---|---|
| 데이터베이스 | **MySQL 8** · 스키마 `wadiz_store` | `com.wadiz.store` 문서 |
| 연결 | master 와 slave 데이터소스를 나눠 씁니다 | 〃 |

상세 화면과 직접 관련된 JPA 엔티티 테이블입니다.

| 테이블 | 담는 것 |
|---|---|
| `projectContent` | 스토리 본문 |
| `projectSetting` | 프로젝트 설정 |
| `projectShippingInfo` | 배송 정보 |
| `projectProductInfoNotice` | 상품정보 고시 |
| `projectClaimAsGuide` | 교환·반품 안내 |
| `projectBaseFunding` | 원본 펀딩 연결 |
| `StoreCollectionProject` | 기획전 묶음 |

> ℹ️ **메이커 프로필만 데이터베이스가 아닙니다.**
> 상세 화면의 메이커 프로필 링크는 **Elasticsearch 색인 `fn-store-active`** 를 거칩니다.
> 조회 주체는 `com.wadiz.api.startup` 입니다. 자세한 내용은 [`com.wadiz.store` 문서](../com.wadiz.store/com.wadiz.store.md)에 있습니다.

---

## 엔드투엔드 시퀀스

### 일반 사용자

```
[브라우저] GET https://www.wadiz.io/web/store/detail/{projectNo}
   │
   ▼
[com.wadiz.web — GlobalKoreaStoreDetailController#getStoreDetailPage]
   ├─ storeProjectService.getProject(projectNo)
   │     └─ StoreClient(RestTemplate) → store-api /api/projects/{projectNo}
   ├─ meta 생성 (HtmlMetadataMessageResolver + html-metadata_ko.properties)
   └─ 뷰 "global-korea/index" 렌더 — 리액트 껍데기만 내려감
   │
   ▼
[리액트 — korea-routes/store.tsx: detail/:projectNo]
   ├─ storeDetailLayoutLoader
   │     ├─ getStoreDetailQueries 12가지 미리 받기 (유효시간 3분)
   │     └─ 국내 + 성인 콘텐츠면 성인 인증 페이지로 보냄
   └─ StoreDetailPage 렌더 (탭: 기본 / story / satisfaction / refund)
   │
   ▼
[데이터 요청] GET /web/apip/store/projects/{projectNo}/...
   │
   ▼
[com.wadiz.web — ApiProxyServlet]
   ├─ 경로 첫 조각 "store" 로 대상 결정 (proxy-clive.xml)
   ├─ 쿠키는 LPINFO·JSESSIONID 만 넘김
   └─ Cookie·Set-Cookie·Authorization 헤더는 제거
   │
   ▼
[com.wadiz.store — store-api]
   ProjectController · ProductController · SatisfactionController
   │
   ▼
[MySQL 8 — wadiz_store]
   projectContent · projectSetting · projectShippingInfo · …
```

### 검색엔진 크롤러

```
[크롤러] GET https://www.wadiz.io/web/store/detail/{projectNo}
   │
   ▼
[com.wadiz.web — GlobalKoreaStoreDetailController]
   ├─ request.getAttribute("isBot") == true
   └─ addBotAttribute — 5가지를 서버가 직접 받아 화면에 담음
         productAggregation · projectStory · satisfactionAggregation
         satisfactions(삭제·숨김 제외) · productInfoNotice
   │
   ▼
[뷰 "global-korea/index"] — 내용이 채워진 상태로 내려감
```

---

## 경계·미탐색

| # | 내용 |
|---|---|
| 1 | **`conditionalCacheable` 의 실제 동작** — 컨트롤러가 항상 `true` 로 넣습니다(64번째 줄). 이 값을 읽어 캐시를 거는 쪽은 확인하지 못했습니다. 이름으로 보아 조건부 캐시 허용 표시로 보이나 추측입니다 |
| 2 | **`collectionService.getExhibitionBannersQuery`** — 기획전 배너를 어느 서비스에서 받는지 이번 범위에서 확인하지 않았습니다 |
| 3 | **탭별 데이터 차이** — 네 탭이 같은 컴포넌트를 쓰는데, 탭마다 추가로 받는 데이터가 있는지 확인하지 않았습니다 |
| 4 | **앱 웹뷰의 차이** — 앱도 같은 주소를 열지만, 웹뷰 전용 분기가 화면 안에 있는지 확인하지 않았습니다. [`app-mapping.md`](./app-mapping.md) 의 14번 항목 참조 |
| 5 | **주문·결제** — 이 문서 범위 밖입니다. [`store-order.md`](./store-order.md) 를 보세요 |

## ⚠️ 확인이 필요해 보이는 점

문서화 과정에서 눈에 띈 것입니다. **원본은 수정하지 않았고 기록만 합니다.**

| # | 내용 |
|---|---|
| ① | **프록시 공유 비밀값이 저장소에 평문으로 있습니다.** `src/main/resources/proxy/proxy-{env}.xml` 의 `apiProxyProperties` 와 `makerApiProxyProperties` 가 32자 문자열을 `constructor-arg` 로 직접 받습니다. `proxy-common.xml` 을 뺀 **9개 환경 파일 전부**에 있습니다.<br>값은 두 종류로 갈려 있습니다. **운영 계열 3개**(`clive`·`real`·`stage`)가 하나를 공유하고, **개발·검증 계열 6개**(`dev`·`local`·`rc1`·`rc2`·`rc3`·`rc4`)가 다른 하나를 공유합니다. 한 파일 안에서는 두 빈이 같은 값을 씁니다.<br>⚠️ **운영 값이 `local` 과 갈려 있는 점은 다행이나, 운영 값 자체가 저장소에 그대로 있습니다.** |
| ② | **`StoreClient` 의 기본 `RestTemplate` 에 타임아웃이 없습니다**(25번째 줄). 스토어 API 가 응답하지 않으면 상세 화면 요청이 계속 기다립니다. 1초 타임아웃은 곁가지 호출 한 곳에만 걸려 있습니다 |

## 관련 문서

| 문서 | 관계 |
|---|---|
| [`com.wadiz.store`](../com.wadiz.store/com.wadiz.store.md) | 스토어 서비스 내부 분석 |
| [`com.wadiz.web`](../com.wadiz.web.md) | 허브 저장소 분석 |
| [`store-order.md`](./store-order.md) | 스토어 주문·결제 흐름 |
| [`store-wish.md`](./store-wish.md) | 스토어 찜 흐름 |
| [`funding-detail.md`](./funding-detail.md) | 펀딩 상세. 같은 `globalkorea` 묶음으로 합쳐졌습니다 |
| [`app-mapping.md`](./app-mapping.md) | 앱의 호출 위치 매핑 |
