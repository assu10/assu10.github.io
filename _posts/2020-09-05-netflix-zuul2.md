---
layout: post
title:  "Spring Cloud(3) - Netflix Zuul(2/2)"
date:   2020-09-05 10:00
categories: dev
tags: web MSA hystrix zuul ribbon
---

## 시작하며
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Netflix Zuul 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고바란다.

>[1.Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2.Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3.Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>***3.Zuul - Proxy & API Gateway (2/2)***<br />
 >>   - 게이트 웨이
  >   - Zuul Proxy
  >   - 주울 구축
  >       - 유레카 클라이언트 구축 (유레카 서버에 서비스 동적 등록)
  >       - 서비스 검색 (Feign 사용)
  >   - 주울 경로 구성
  >       - 서비스 디스커버리를 이용한 자동 경로 매핑
  >       - 서비스 디스커버리를 이용한 수동 경로 매핑
  >   - 서비스 타임 아웃<br />
>
> 4.Ribbon - Load Balancer<br />

Spring Cloud Config Server 와 Eureka, Zuul(1) 에 대한 자세한 내용은 위 목차에 걸려있는 링크를 참고바란다.

---

## 1. 필터
앞에서 말했다시피 주울은 사전 필요, 라우팅 필터, 사후 필터, 에러 필터 등을 제공하여 서비스 호출의 서로 다른 여러 단계에 적용할 수 있도록 지원한다. 
또한 추상 클래스인 ZuulFilter 를 상속하여 자체 필터를 작성할 수도 있다.

주울은 프록시 기능 외 주울을 통과하는 모든 서비스 호출에 대해 사용자 정의 로직을 작성할 때 더욱 효과가 있다.
예를 들면 **모든 서비스에 대한 보안이나 로깅, 추적처럼 일관된 정책을 시행**하는 것을 말한다.
<br /><br />

주울은 4가지 타입의 필터를 지원한다.

- **PRE Filter (이후 사전 필터)**
    - 라우팅 되기 전에 실행되는 필터
    - <U>서비스의 일관된 메시지 형식(예-주요 HTTP 헤더의 포함 여부 등)을 확인하는 작업이나 인증(본인 인증), 
    인가(수행 권한 부여 여부)을 확인</U>하는 게이트키퍼 역할
- **ROUTING Filter (이후 라우팅 필터)**
    - 요청에 대한 라우팅을 하는 필터
    - 동적 라우팅 필요 여부를 결정하는데 사용<br />
      예를 들어 <U>동일 서비스의 다른 두 버전을 라우팅할 수 있는 경로 단위의 필터</U> 역할
- **POST Filter (이후 사후 필터)**
    - 라우팅 후에 실행되는 필터
    - 대상 서비스의 <U>응답 로깅, 에러 처리, 민감한 정보에 대한 응답 감시</U> 수행
- **ERROR Filter (이후 에러 필터)**
    - 에러 발생 시 실행되는 필터

![주울 라이프사이클](/assets/img/dev/20200905/lifecycle.png)

- 요청이 주울로 들어오면 사전 필터가 실행된다.
- 라우팅 필터는 서비스가 향하는 목적지를 라우팅한다.
    - 동적 경로 : 주울 서버에 구성된 경로가 아닌 다른 외부의 서비스로도 동적 라우팅(redirection)이 가능<br />
    대신 HTTP 리다이렉션이 아니라 유입된 HTTP 요청을 종료한 후 원래 호출자를 대신해 그 경로를 호출하는 방식
    - 대상 경로 : 라우팅 필터가 새로운 경로로 동적 리다이렉션을 하지 않는 경우 원래 대상 서비스의 경로로 라우팅
- 대상 서비스가 호출된 후의 응답은 사후 필터로 유입된다. 이 때 서비스 응답 수정 및 검사가 가능하다.
    
이번 포스팅에서는 아래와 같은 필터를 구성할 예정이다.

![구현할 필터 역할과 흐름](/assets/img/dev/20200905/filters.png)

---

## 2. 사전 필터
*PreFilter* 라는 사전 필터를 만들어 주울로 들어오는 모든 요청을 검사하고, 
요청 안에 *'assu-correlation-id'* 라는 상관관계 ID가 HTTP 헤더가 있는지 판별할 것이다.

>상관관계 ID(correlation ID)<br />
>   한 트랜잭션 내 여러 서비스 호출을 추적할 수 있는 고유 GUID(Globally Unique ID)

HTTP 헤더에 *'assu-correlation-id'* 가 없다면 이 사전 필터는 상관관계 ID 를 생성하여 헤더에 설정한다.<br />
만일 이미 있다면 주울은 상관관계 ID 에 대해 아무런 행동도 하지 않는다.
(상관관계 ID 가 있다는 건 해당 호출이 사용자 요청을 수행하는 일련의 서비스 호출 중 일부임을 의미)

주울에서 필터를 구현하려면 `ZuulFilter` 클래스를 상속받은 후 `filterType()`, `filterOrder()`, `shouldFilter()`, `run()` 
이 4개의 메서드는 반드시 오버라이드 해야한다.

- **filterType()**<br />
구축하려는 필터의 타입 지정 (사전, 라우팅, 사후)
- **filterOrder()**<br />
해당 타입의 다른 필터와 비교해 실행되어야 하는 순서
- **shouldFilter()**<br />
필터 활성화 여부
- **run()**<br />
필터의 비즈니스 로직 구현

---

### 2.1. 주울로 통신하는 모든 마이크로서비스 호출에 상관관계 ID 확인 및 생성

![사전필터 디렉토리 구조](/assets/img/dev/20200905/prefilter.png)


우선 로그 확인을 위해 컨피그 원격 저장소에 로그 레벨을 셋팅한다.

```yaml
# config-repo > zuulserver > zuulserver.yaml

logging:
  level:
    com.netflix: WARN
    org.springframework.web: WARN
    com.assu.cloud.zuulserver: DEBUG
```

아래 2 개의 클래스는 주울 서비스에 생성되는 클래스이다.
자세한 설명은 각 소스의 주석을 참고하기 바란다.

```java
// zuulserver > utils > FilterUtils.java

package com.assu.cloud.zuulserver.utils;

import com.netflix.zuul.context.RequestContext;
import org.springframework.stereotype.Component;

/**
 * 필터에서 사용되는 공통 기능
 */
@Component
public class FilterUtils {
    public static final String CORRELATION_ID = "assu-correlation-id";
    public static final String PRE_FILTER_TYPE = "pre";
    public static final String POST_FILTER_TYPE = "post";
    public static final String ROUTING_FILTER_TYPE = "route";

    /**
     * HTTP 헤더에서 assu-correlation-id 조회
     */
    public String getCorrelationId() {
        RequestContext ctx = RequestContext.getCurrentContext();

        if (ctx.getRequest().getHeader(CORRELATION_ID) != null) {
            // assu-correlation-id 가 이미 설정되어 있다면 해당값 리턴
            return ctx.getRequest().getHeader(CORRELATION_ID);
        } else {
            // 헤더에 없다면 ZuulRequestHeaders 확인
            // 주울은 유입되는 요청에 직접 HTTP 요청 헤더를 추가하거나 수정하지 않음
            return ctx.getZuulRequestHeaders().get(CORRELATION_ID);
        }
    }

    /**
     * HTTP 요청 헤더에 상관관계 ID 추가
     *      이 때 RequestContext 에 addZuulRequestHeader() 메서드로 추가해야 함
     *
     *      이 메서드는 주울 서버의 필터를 지나는 동안 추가되는 별도의 HTTP 헤더 맵을 관리하는데
     *      ZuulRequestHeader 맵에 보관된 데이터는 주울 서버가 대상 서비스를 호출할 때 합쳐짐
     * @param correlationId 
     */
    public void setCorrelationId(String correlationId) {
        RequestContext ctx = RequestContext.getCurrentContext();
        ctx.addZuulRequestHeader(CORRELATION_ID, correlationId);
    }
}
```
<br />

```java
// zuulserver > filters > PreFilter.java

package com.assu.cloud.zuulserver.filters;

import com.assu.cloud.zuulserver.utils.FilterUtils;
import com.netflix.zuul.ZuulFilter;
import com.netflix.zuul.context.RequestContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * 사전 필터
 *      주울로 들어오는 모든 요청을 검사하고, 요청에 상관관계 ID 가 HTTP 헤더에 있는지 판별.
 *      상관관계 ID가 없으면 생성
 *      상관관계 ID가 있으면 아무 일도 하지 않음
 */
@Component
public class PreFilter extends ZuulFilter {

    private FilterUtils filterUtils;

    public PreFilter(FilterUtils filterUtils) {
        this.filterUtils = filterUtils;
    }

    /** 해당 타입의 다른 필터와 비교해 실행되어야 하는 순서 */
    private static final int FILTER_ORDER = 1;

    /** 필터 활성화 여부 */
    private static final boolean SHOULD_FILTER = true;
    private static final Logger logger = LoggerFactory.getLogger(PreFilter.class);

    /**
     * 구축하려는 필터의 타입 지정 (사전, 라우팅, 사후)
     */
    @Override
    public String filterType() {
        return FilterUtils.PRE_FILTER_TYPE;
    }

    /**
     * 해당 타입의 다른 필터와 비교해 실행되어야 하는 순서
     */
    @Override
    public int filterOrder() {
        return FILTER_ORDER;
    }

    /**
     * 필터 활성화 여부
     */
    @Override
    public boolean shouldFilter() {
        return SHOULD_FILTER;
    }

    /**
     * 헤더에 assu-correlation-id 가 있는지 확인
     */
    private boolean isCorrelationIdPresent() {
        if (filterUtils.getCorrelationId() != null) {
            return true;
        }
        return false;
    }

    private String generateCorrelationId() {
        return UUID.randomUUID().toString();
    }

    /**
     * 필터의 비즈니스 로직 구현
     *      서비스가 필터를 통과할때마다 실행되는 메서드
     *      상관관계 ID의 존재 여부 확인 후 없다면 생성하여 헤더에 설정
     */
    @Override
    public Object run() {
        if (isCorrelationIdPresent()) {
            // 헤더에 assu-correlation-id 가 있다면
            logger.debug("============ assu-correlation-id found in pre filter: {}. ", filterUtils.getCorrelationId());
        } else {
            // 헤더에 assu-correlation-id 가 없다면 상관관계 ID 생성하여 RequestContext 의 addZuulRequestHeader 로 추가
            filterUtils.setCorrelationId(generateCorrelationId());
            logger.debug("============ assu-correlation-id generated in pre filter: {}.", filterUtils.getCorrelationId());
        }

        RequestContext ctx = RequestContext.getCurrentContext();
        logger.debug("============ Processing incoming request for {}.",  ctx.getRequest().getRequestURI());

        return null;
    }
}
```

실제 주울을 통해 API 를 호출하여 상관관계 ID 가 정상적으로 생성 및 확인되는지 확인해보자
[http://localhost:5555/api/evt/event/name/hyori](http://localhost:5555/api/evt/event/name/hyori) (이벤트 서비스 호출)

```text
2020-09-06 00:49:38.130 DEBUG 253736 --- [nio-5555-exec-9] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id generated in pre filter: 40cd5e88-2b1d-454d-af87-02ce74b022f2.
2020-09-06 00:49:38.146 DEBUG 253736 --- [nio-5555-exec-9] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/evt/event/name/hyori.
```

---

### 2.2. 서비스 호출 시 상관관계 ID 사용
 

 
## 참고 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/](https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/)
* [https://spring.io/guides/gs/routing-and-filtering/](https://spring.io/guides/gs/routing-and-filtering/)
* [https://github.com/Netflix/zuul/wiki/How-it-Works](https://github.com/Netflix/zuul/wiki/How-it-Works)
