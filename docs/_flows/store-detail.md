# Flow: 스토어 프로젝트 상세

> 와디즈 스토어(상시 판매) 프로젝트의 상세 페이지 렌더링. JSP 페이지 + `ApiProxy` 로 Store API 데이터 로드.

## 기록 범위
- **읽은 파일**:
  - `wadiz-frontend/packages/api/src/web/store/projects.service.ts:22` (`/web/apip/store/projects/my`)
  - `wadiz-frontend/packages/api/src/web/store.service.ts:70-118` (satisfactions/reactions)
  - `com.wadiz.web/src/main/java/.../store/project/controller/StoreProjectUiController.java:21-52`
  - `com.wadiz.web/web/WEB-INF/web.xml:202` (`/web/apip/*` ApiProxy)
- **외부 경계**: Store API 서비스 (이 레포 없음 — `com.wadiz.api.store` 또는 유사 repo 별도).

---

## 1. Client Trigger (FE)
스토어 상세 페이지 URL: `https://www.wadiz.kr/web/store/detail/{projectNo}` (JSP 렌더링).

탭별 데이터는 API 로 로드:
- **스토리** (기본): JSP 템플릿 내 데이터
- **상품 리스트 / 옵션**: `/web/apip/store/...`
- **만족도 평가**: `GET /web/apip/store/satisfactions?...` (store.service.ts:70)
- **댓글 리액션**: `PUT /web/apip/store/reactions`
- **댓글 답글**: `POST /web/apip/store/satisfactions/{commentId}/replies`

## 2. Hub — `com.wadiz.web`

### 2.1 JSP 렌더링
```java
// com.wadiz.web/.../store/project/controller/StoreProjectUiController.java:21
@Controller
@RequestMapping(value = "/web/store/detail/{projectNo:\\d+}")
public class StoreProjectUiController {
    @Autowired private StoreProjectService storeProjectService;

    @RequestMapping(value = {"", "/story", "/satisfaction", "/refund"})  // :30
    public ModelAndView detail(@PathVariable Long projectNo, ...) {
        StoreProjectResponse project = getProject(projectNo);
        ...
        mv.setViewName("store/project/detail");
        return mv;
    }

    private StoreProjectResponse getProject(final Long projectNo) {
        StoreProjectResponse project;
        try {
            return storeProjectService.getProject(projectNo);   // 내부 Adapter 로 Store API 호출
        } catch (Exception e) {
            return new StoreProjectResponse();
        }
    }
}
```
4개 서브 URL (`""`, `/story`, `/satisfaction`, `/refund`) 을 동일 Controller 가 처리, 탭 구분은 내부 분기.

### 2.2 REST 데이터 경로 — ApiProxy
`/web/apip/store/*` 는 ApiProxyServlet 투명 프록시 → 별도 Store API 서비스로 직행. com.wadiz.web 경유하되 Java 로직 통과.

## 3. Backend — Store API (외부)
본 레포(`repos/`)에 store 서비스 없음. 추정 repo: `com.wadiz.api.store`.
- Store 프로젝트 메타·재고·옵션·만족도·리뷰 관리
- 쿠폰·포인트 는 공통 (`com.wadiz.api.reward`)
- 주문은 [store-order.md](./store-order.md) 참조

## 4. DB
외부 서비스 → 미관측. 단 com.wadiz.web 의 SearcherApiAdapter/내부 어댑터 파일로 볼 때 `Campaign` 과 유사한 스토어 전용 테이블(`StoreProject`·`StoreItem` 등) 존재 추정.

## 엔드투엔드 시퀀스
```
[FE] GET /web/store/detail/{projectNo}
   ▼
[www.wadiz.kr — StoreProjectUiController#detail]
   ├─ storeProjectService.getProject(projectNo)  → Store API 어댑터 → 외부 Store 서비스
   └─ JSP "store/project/detail" 렌더링 (탭: story/satisfaction/refund)

[FE: 탭 전환 시 별도 데이터 fetch]
   ├─ GET /web/apip/store/satisfactions?...      → ApiProxy → Store API
   ├─ PUT /web/apip/store/reactions
   └─ POST /web/apip/store/satisfactions/{id}/replies
```

## 경계·미탐색
1. **Store API 서비스** — 본 repos 에 없음. 별도 repo 확인 필요 (ECR/네이밍 추정).
2. **JSP vs SPA** — 상세 페이지가 아직 JSP. wadiz-frontend 로의 이관 상태 미확인.
3. **`StoreProjectService.getProject`** 내부 — 어떤 Adapter 로 외부 Store API 를 호출하는지 (Feign/RestTemplate) 추가 추적.
4. **캐싱** — 재고·가격은 실시간성이 중요, JSP 렌더 시점 vs AJAX 로 분리된 영역.
