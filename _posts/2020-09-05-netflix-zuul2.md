---
layout: post
title:  "Spring Cloud - Netflix Zuul(2/2)"
date:   2020-09-05 10:00
categories: dev
tags: msa hystrix zuul ribbon
---

이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Netflix Zuul 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2. Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3. Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br /><br />
>***4. Zuul - Proxy & API Gateway (2/2)***<br />
>   - 필터
>   - 사전 필터
>       - Zuul 로 통신하는 모든 마이크로서비스 호출에 상관관계 ID 확인 및 생성
>       - 서비스 호출 시 상관관계 ID 사용
>   - 사후 필터
>   - Zuul 의 고가용성

Spring Cloud Config Server 와 Eureka, Zuul(1) 에 대한 자세한 내용은 위 목차에 걸려있는 링크를 참고 바란다.

*[Spring Cloud - Netflix Zuul(Ribbon) Retry](https://assu10.github.io/dev/2020/12/06/netflix-zuul-retryable/)* 와 함께 보면 도움이 됩니다.

---

## 1. 필터
앞에서 말했다시피 Zuul 은 사전 필요, 라우팅 필터, 사후 필터, 에러 필터 등을 제공하여 서비스 호출의 서로 다른 여러 단계에 적용할 수 있도록 지원한다. 
또한 추상 클래스인 ZuulFilter 를 상속하여 자체 필터를 작성할 수도 있다.

Zuul 은 프록시 기능 외 Zuul 을 통과하는 모든 서비스 호출에 대해 사용자 정의 로직을 작성할 때 더욱 효과가 있다.
예를 들면 **모든 서비스에 대한 보안이나 로깅, 추적처럼 일관된 정책을 시행**하는 것을 말한다.
<br /><br />

Zuul 은 4가지 타입의 필터를 지원한다.

- **PRE Filter (이후 사전 필터)**
    - 라우팅 되기 전에 실행되는 필터
    - <U>서비스의 일관된 메시지 형식(예-주요 HTTP 헤더의 포함 여부 등)을 확인하는 작업이나 인증(본인 인증), 
    인가(수행 권한 부여 여부)를 확인</U>하는 게이트키퍼 역할
- **ROUTING Filter (이후 라우팅 필터)**
    - 요청에 대한 라우팅을 하는 필터
    - 동적 라우팅 필요 여부를 결정하는데 사용<br />
      예를 들어 <U>동일 서비스의 다른 두 버전을 라우팅할 수 있는 경로 단위의 필터</U> 역할
- **POST Filter (이후 사후 필터)**
    - 라우팅 후에 실행되는 필터
    - 대상 서비스의 <U>응답 로깅, 에러 처리, 민감한 정보에 대한 응답 감시</U> 수행
- **ERROR Filter (이후 에러 필터)**
    - 에러 발생 시 실행되는 필터

![Zuul 라이프사이클](/assets/img/dev/2020/0905/lifecycle.png)

- 요청이 Zuul 로 들어오면 사전 필터가 실행된다.
- 라우팅 필터는 서비스가 향하는 목적지를 라우팅한다.
    - 동적 경로 : Zuul 서버에 구성된 경로가 아닌 다른 외부의 서비스로도 동적 라우팅(redirection)이 가능<br />
    대신 HTTP 리다이렉션이 아니라 유입된 HTTP 요청을 종료한 후 원래 호출자를 대신해 그 경로를 호출하는 방식
    - 대상 경로 : 라우팅 필터가 새로운 경로로 동적 리다이렉션을 하지 않는 경우 원래 대상 서비스의 경로로 라우팅
- 대상 서비스가 호출된 후의 응답은 사후 필터로 유입된다. 이때 서비스 응답 수정 및 검사가 가능하다.
    
이번 포스팅에서는 아래와 같은 필터를 구성할 예정이다.

![구현할 필터 역할과 흐름](/assets/img/dev/2020/0905/filters.png)

---

## 2. 사전 필터
*PreFilter* 라는 사전 필터를 만들어 Zuul 로 들어오는 모든 요청을 검사하고, 
요청 안에 *'assu-correlation-id'* 라는 상관관계 ID가 HTTP 헤더가 있는지 판별할 것이다.

>**상관관계 ID(correlation ID)**<br />
>   한 트랜잭션 내 여러 서비스 호출을 추적할 수 있는 고유 GUID(Globally Unique ID)

HTTP 헤더에 *'assu-correlation-id'* 가 없다면 이 사전 필터는 상관관계 ID 를 생성하여 헤더에 설정한다.<br />
만일 이미 있다면 Zuul 은 상관관계 ID 에 대해 아무런 행동도 하지 않는다.
(상관관계 ID 가 있다는 건 해당 호출이 사용자 요청을 수행하는 일련의 서비스 호출 중 일부임을 의미)

Zuul 에서 필터를 구현하려면 `ZuulFilter` 클래스를 상속받은 후 `filterType()`, `filterOrder()`, `shouldFilter()`, `run()` 
이 4개의 메서드는 반드시 오버라이드 해야 한다.

- **filterType()**<br />
구축하려는 필터의 타입 지정 (사전, 라우팅, 사후)
- **filterOrder()**<br />
해당 타입의 다른 필터와 비교해 실행되어야 하는 순서
- **shouldFilter()**<br />
필터 활성화 여부
- **run()**<br />
필터의 비즈니스 로직 구현

---

### 2.1. Zuul 로 통신하는 모든 마이크로서비스 호출에 상관관계 ID 확인 및 생성

>상관관계 ID 로 로그를 추적하는 방법은 나중에 Spring Cloud Sleuth 와 Open Zipkin 으로 대체하여 사용 예정입니다.<br />
>[Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (3/3) - 로그 추적](https://assu10.github.io/dev/2021/01/04/spring-cloud-log-tracker3/) 에
>포스팅되어 있지만 아래 내용도 한번씩 해보세요~

![사전필터 디렉토리 구조](/assets/img/dev/2020/0905/prefilter.png)


우선 로그 확인을 위해 컨피그 원격 저장소에 로그 레벨을 셋팅한다.

**config-repo > zuulserver > zuulserver.yaml**
```yaml
logging:
  level:
    com.netflix: WARN
    org.springframework.web: WARN
    com.assu.cloud.zuulserver: DEBUG
```

아래 2개의 클래스는 Zuul 서비스에 생성되는 클래스이다.
자세한 설명은 각 소스의 주석을 참고하기 바란다.

**zuulserver > utils > FilterUtils.java**
```java
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
            // Zuul 은 유입되는 요청에 직접 HTTP 요청 헤더를 추가하거나 수정하지 않음
            return ctx.getZuulRequestHeaders().get(CORRELATION_ID);
        }
    }

    /**
     * HTTP 요청 헤더에 상관관계 ID 추가
     *      이때 RequestContext 에 addZuulRequestHeader() 메서드로 추가해야 함
     *
     *      이 메서드는 Zuul 서버의 필터를 지나는 동안 추가되는 별도의 HTTP 헤더 맵을 관리하는데
     *      ZuulRequestHeader 맵에 보관된 데이터는 Zuul 서버가 대상 서비스를 호출할 때 합쳐짐
     * @param correlationId 
     */
    public void setCorrelationId(String correlationId) {
        RequestContext ctx = RequestContext.getCurrentContext();
        ctx.addZuulRequestHeader(CORRELATION_ID, correlationId);
    }
}
```
<br />

**zuulserver > filters > PreFilter.java**
```java
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
 *      Zuul 로 들어오는 모든 요청을 검사하고, 요청에 상관관계 ID 가 HTTP 헤더에 있는지 판별.
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
     *      서비스가 필터를 통과할 때마다 실행되는 메서드
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

실제 Zuul 을 통해 API 를 호출하여 상관관계 ID 가 정상적으로 생성되는지 확인해보자.

- 회원 서비스 API 호출 : [http://localhost:5555/api/mb/member/name/hyori](http://localhost:5555/api/mb/member/name/hyori) 

```text
2020-09-06 20:40:12.467 DEBUG 23336 --- [io-5555-exec-10] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id generated in pre filter: 3edcd250-7f1c-4459-9aa3-7190d62f3c52.
2020-09-06 20:40:12.468 DEBUG 23336 --- [io-5555-exec-10] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/mb/member/name/hyori.
```

- 회원 서비스 중 이벤트 서비스의 API 를 조회하는 API 호출 : [http://localhost:5555/api/mb/member/gift/flower](http://localhost:5555/api/mb/member/gift/flower) 

```text
2020-09-06 20:40:50.566 DEBUG 23336 --- [nio-5555-exec-2] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id generated in pre filter: 2c965f0d-58d6-4797-a9bd-75cd7b6efb51.
2020-09-06 20:40:50.566 DEBUG 23336 --- [nio-5555-exec-2] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/mb/member/gift/flower.
2020-09-06 20:40:50.587 DEBUG 23336 --- [nio-5555-exec-3] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id generated in pre filter: 86ca377e-9246-48ce-a25f-409723458227.
2020-09-06 20:40:50.587 DEBUG 23336 --- [nio-5555-exec-3] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/evt/event/gift/flower.
```

하나의 API 를 호출했지만 실제로 Zuul 엔 2번의 요청이 오게 된다.
- 이벤트 서비스의 */api/evt/event/member/{nick}* 호출 시 Zuul 통과
- 위 API 내에서 회원 서비스의 */api/mb/member/name/{nick}* API 호출 시 Zuul 통과

하나의 트랜잭션이므로 동일한 상관관계 ID가 나와야 할 것 같지만 다른 상관관계 ID 가 생성됨을 알 수 있다.<br />
이 부분은 다음 단계에서 알아보도록 한다. (마이크로서비스가 호출하는 하위 서비스 호출에도 상관관계 ID 전파)

---

### 2.2. 서비스 호출 시 상관관계 ID 사용

이제 실제 상관관계 ID를 활용하기 위해서 아래 2개의 기능이 필요하다.

- 호출되는 마이크로서비스(=회원 서비스)에서 상관관계 ID 에 접근
- 마이크로서비스가 호출하는 하위 서비스 호출에도 상관관계 ID 전파

위 작업을 위해 총 4개의 클래스를 작성할 텐데 해당 클래스들은 HTTP 요청에서 상관관계 ID 를 읽어와 접근할 수 있는 클래스에 매핑한 후
하위 서비스에 전파하는데 사용된다.

![사전필터 내의 상관관계 ID 흐름](/assets/img/dev/2020/0905/prefilter2.png)


CustomContextFilter 는 HTTP ServletFilter 이고, 상관관계 ID 를 CustomContext 클래스에 매핑한다.
여기서 CustomContext 클래스는 나중에 사용할 수 있도록 ThreadLocal 에 저장된 값이다.<br />
RestTemplate 는 사용자 정의된 Spring 인터셉터 클래스 (CustomContextInterceptor) 로 상관관계 ID 를 아웃바운드 호출의 HTTP 헤더에 삽입한다.


> **공통의 라이브러리**<br /><br />
> 마이크로서비스는 본래 서비스 간의 의존성이 없는 것을 추구하기 때문에 서비스 전반에 걸쳐 영향을 미치는 공통 기능은 없어야 한다는 의견도
> 맞지만, 실제 실무를 하다 보면 모든 서비스가 공유해야 하는 기능이 반드시 존재하고 각각 마이크로서비스에 각각 구현하기엔 코드 중복 및
> 수정사항 발생 시 모든 마이크로서비스의 동일한 부분을 수정해주어야 하는 운영상의 편의성도 고려를 해야 한다.<br /><br />
> 공통의 라이브러리는 모두 사용할 수 있도록 하되 비즈니스 로직이 들어가는 기능은 분리하는 것이 좋을 것 같다.  

- 클래스에 대한 설명
    - **CustomContextFilter**<br />
      유입되는 HTTP 요청을 가로채서 필요한 헤더값을 CustomContext 에 매핑<br />
      REST 서비스에 대한 모든 HTTP 요청을 가로채서 컨텍스트 정보(상관관계 ID 등)를 추출해 CustomContext 클래스에 매핑하는 HTTP 서블릿 필터<br />
      REST 서비스 호출 시 코드에서 CustomContext 액세스가 필요할 때마다 ThreadLocal 변수에서 검색해 읽어올 수 있음
      
    - **CustomContext**<br />
      서비스가 쉽게 액세스할 수 있는 HTTP 헤더를 만들어 저장하는 클래스<br />
      HTTP 요청에서 추출한 값을 보관하는 POJO

    - **CustomContextHolder**<br />
      ThreadLocal 저장소에 CustomContext 를 저장하는 클래스<br />
      CustomContext 가 ThreadLocal 저장소에 저장되면 요청으로 실행된 모든 코드에서 CustomContextHolder 의 CustomContext 객체 사용 가능<br />
      
    - **CustomContextInterceptor**<br />
      RestTemplate 인스턴스에서 실행되는 모든 HTTP 기반 서비스 발신 요청에 상관관계 ID 삽입

>**ThreadLocal 변수**<br />
>사용자 요청을 처리하는 해당 스레드에서 호출되는 모든 메서드에서 액세스 가능한 변수

**각 마이크로서비스 > CustomContextFilter.java**
```java
/**
 * 유입되는 HTTP 요청을 가로채서 필요한 헤더값을 CustomContext 에 매핑
 * 
 * REST 서비스에 대한 모든 HTTP 요청을 가로채서 컨텍스트 정보(상관관계 ID 등)를 추출해 CustomContext 클래스에 매핑하는 HTTP 서블릿 필터
 * REST 서비스 호출 시 코드에서 CustomContext 액세스가 필요할 때마다 ThreadLocal 변수에서 검색해 읽어올 수 있음
 */
@Component
public class CustomContextFilter implements Filter {

    private static final Logger logger = LoggerFactory.getLogger(CustomContextFilter.class);

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        HttpServletRequest httpServletRequest = (HttpServletRequest) servletRequest;

        // HTTP 호출 헤더에서 상관관계 ID 를 검색하여 CustomContextHolder 의 CustomContext 클래스에 설정
        CustomContextHolder.getContext().setCorrelationId(httpServletRequest.getHeader(CustomContext.CORRELATION_ID));
        // 그 외 필요한 항목 넣을 수 있음 (인증 토큰 등...)

        logger.debug("상관관계 ID {} 로 실행된 동적 라우팅", CustomContextHolder.getContext().getCorrelationId());

        filterChain.doFilter(httpServletRequest, servletResponse);
    }

    @Override
    public void init(FilterConfig filterConfig) {}

    @Override
    public void destroy() {}
}
```

**각 마이크로서비스 > CustomContext.java**
```java
/**
 * 서비스가 쉽게 액세스할 수 있는 HTTP 헤더를 만들어 저장하는 클래스
 * HTTP 요청에서 추출한 값을 보관하는 POJO
 */
@Component
public class CustomContext {
    public static final String CORRELATION_ID = "assu-correlation-id";

    private String correlationId = new String();

    // 그 외 필요한 항목 넣을 수 있음 (인증 토큰 등...)

    public String getCorrelationId() {
        return correlationId;
    }

    public void setCorrelationId(String correlationId) {
        this.correlationId = correlationId;
    }
}
```

**각 마이크로서비스 > CustomContextHolder.java**
```java
/**
 * ThreadLocal 저장소에 CustomContext 를 저장하는 클래스
 *      * ThreadLocal 변수: 사용자 요청을 처리하는 해당 스레드에서 호출되는 모든 메서드에서 액세스 가능한 변수
 *
 * CustomContext 가 ThreadLocal 저장소에 저장되면 요청으로 실행된 모든 코드에서 CustomContextHolder 의 CustomContext 객체 사용 가능
 */
public class CustomContextHolder {

    /** 정적 ThreadLocal 변수에 저장되는 CustomContext */
    private static final ThreadLocal<CustomContext> customContext = new ThreadLocal<>();

    /**
     * CustomContext 객체를 사용하기 위해 조회해오는 메서드
     */
    public static final CustomContext getContext() {
        CustomContext ctx = customContext.get();

        if (ctx == null) {
            ctx = createEmptyContext();
            customContext.set(ctx);
        }
        return customContext.get();
    }

    public static final void setContext(CustomContext ctx) {
        Assert.notNull(ctx, "customcontxt is null.");
        customContext.set(ctx);
    }

    public static final CustomContext createEmptyContext() {
        return new CustomContext();
    }
}
```

**각 마이크로서비스 > CustomContextInterceptor.java**
```java
/**
 * RestTemplate 인스턴스에서 실행되는 모든 HTTP 기반 서비스 발신 요청에 상관관계 ID 삽입
 */
public class CustomContextInterceptor implements ClientHttpRequestInterceptor {
    /**
     * RestTemplate 로 실제 HTTP 서비스 호출 전 intercept 메서드 호출
     */
    @Override
    public ClientHttpResponse intercept(HttpRequest httpRequest, byte[] bytes, ClientHttpRequestExecution clientHttpRequestExecution) throws IOException {
        HttpHeaders headers = httpRequest.getHeaders();

        headers.add(CustomContext.CORRELATION_ID, CustomContextHolder.getContext().getCorrelationId());
        // 그 외 필요한 항목 넣을 수 있음 (인증 토큰 등...)

        return clientHttpRequestExecution.execute(httpRequest, bytes);
    }
}
```

CustomContextInterceptor 를 사용하려면 RestTemplate 빈 생성 시 함께 설정을 해주어야 한다.

**member-service > MemberServiceApplication.java**
```java
@LoadBalanced       // 스프링 클라우드가 리본이 지원하는 RestTemplate 클래스 생성하도록 지시
@Bean
public RestTemplate getRestTemplate() {
    // return new RestTemplate();
    RestTemplate template = new RestTemplate();
    List interceptors = template.getInterceptors();

    if (interceptors == null) {
        template.setInterceptors(Collections.singletonList(new CustomContextInterceptor()));
    } else {
        interceptors.add(new CustomContextInterceptor());
        template.setInterceptors(interceptors);
    }
    return template;
}
```

이제 하나의 트랜잭션이 같은 상관관계 ID를 갖는지 확인해보자.<br />
회원 서비스 내의 메서드(내부적으로 이벤트 REST API 호출) : [http://localhost:5555/api/mb/member/gift/flower](http://localhost:5555/api/mb/member/gift/flower)

위 API 호출 후 Zuul 의 로그를 보면 아래와 같이 상관관계 ID 가 *216c365d-7842-45b9-a300-51f6272a5e4b* 로 두 번의 호출 모두 동일한 것을 알 수 있다.
 
```text
2020-09-06 23:24:47.730 DEBUG 52636 --- [nio-5555-exec-1] c.a.c.z.utils.CustomContextFilter        : 상관관계 ID null 로 실행된 동적 라우팅
2020-09-06 23:24:47.761 DEBUG 52636 --- [nio-5555-exec-1] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id generated in pre filter: 216c365d-7842-45b9-a300-51f6272a5e4b.
2020-09-06 23:24:47.761 DEBUG 52636 --- [nio-5555-exec-1] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/mb/member/gift/flower.
2020-09-06 23:24:48.459 DEBUG 52636 --- [nio-5555-exec-2] c.a.c.z.utils.CustomContextFilter        : 상관관계 ID 216c365d-7842-45b9-a300-51f6272a5e4b 로 실행된 동적 라우팅
2020-09-06 23:24:48.460 DEBUG 52636 --- [nio-5555-exec-2] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id found in pre filter: 216c365d-7842-45b9-a300-51f6272a5e4b. 
2020-09-06 23:24:48.460 DEBUG 52636 --- [nio-5555-exec-2] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/evt/event/gift/flower.
```

이제 상관관계 ID 가 각 서비스에 전달되기 때문에 호출과 연관된 모든 서비스를 관통하는 트랜잭션 추적이 가능하다.
좀 더 원활한 추적을 위해선 중앙 집중식 로그 지점으로 모든 로그를 보내야 한다.
나중에 알아보긴 할 텐데 Sleuth는 PreFilter 를 사용하진 않아도 상관관계 ID 를 추적하고 모든 호출에 삽입 여부를 확인하는데 동일한 개념을 사용한다.

---

## 3. 사후 필터
Zuul 은 사후 필터를 이용하여 대상 서비스 호출에 대한 응답을 검사한 후 수정하거나 추가 정보를 삽입할 수 있다.
여기선 서비스 호출자에게 다시 전달될 HTTP 응답 헤더에 상관관계 ID 를 삽입하여 사용자 트랜잭션과 연관된 로깅을 연결 지을 것이다.

zuulserver > filters > PostFilter.java****
```java
/**
 * 사후 필터
 *      서비스 호출자에게 다시 전달될 HTTP 응답 헤더에 상관관계 ID 를 삽입하여 사용자 트랜잭션과 연관된 로깅을 연결 지음
 */
@Component
public class PostFilter extends ZuulFilter {
    /** 해당 타입의 다른 필터와 비교해 실행되어야 하는 순서 */
    private static final int FILTER_ORDER = 1;

    /** 필터 활성화 여부 */
    private static final boolean SHOULD_FILTER = true;
    private static final Logger logger = LoggerFactory.getLogger(PostFilter.class);

    private final FilterUtils filterUtils;

    public PostFilter(FilterUtils filterUtils) {
        this.filterUtils = filterUtils;
    }

    /**
     * 구축하려는 필터의 타입 지정 (사전, 라우팅, 사후)
     */
    @Override
    public String filterType() {
        return FilterUtils.POST_FILTER_TYPE;
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
     * 필터의 비즈니스 로직 구현
     *      원래 HTTP 요청에서 전달된 상관관계 ID 를 가져와 응답에 삽입
     */
    @Override
    public Object run() {
        RequestContext ctx = RequestContext.getCurrentContext();

        logger.debug("============ Adding the correlation id to the outbound headers. {}", filterUtils.getCorrelationId());
        // 원래 HTTP 요청에서 전달된 상관관계 ID 를 가져와 응답에 삽입
        ctx.getResponse().addHeader(FilterUtils.CORRELATION_ID, filterUtils.getCorrelationId());
        logger.debug("============ Completing outgoing request for {}.", ctx.getRequest().getRequestURI());

        return null;
    }
}
```

이제 실제 응답 헤더에 상관관계 ID 가 삽입되는지 확인해보자.<br />
회원 서비스 내의 메서드(내부적으로 이벤트 REST API 호출) : [http://localhost:5555/api/mb/member/gift/flower](http://localhost:5555/api/mb/member/gift/flower)

```text
2020-09-11 23:29:26.714 DEBUG 71032 --- [nio-5555-exec-9] c.a.c.z.utils.CustomContextFilter        : 상관관계 ID null 로 실행된 동적 라우팅
2020-09-11 23:29:26.717 DEBUG 71032 --- [nio-5555-exec-9] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id generated in pre filter: c0ece664-d1bc-4b76-b031-c2fab3597727.
2020-09-11 23:29:26.717 DEBUG 71032 --- [nio-5555-exec-9] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/mb/member/gift/flower.
2020-09-11 23:29:26.732 DEBUG 71032 --- [io-5555-exec-10] c.a.c.z.utils.CustomContextFilter        : 상관관계 ID c0ece664-d1bc-4b76-b031-c2fab3597727 로 실행된 동적 라우팅
2020-09-11 23:29:26.733 DEBUG 71032 --- [io-5555-exec-10] c.a.cloud.zuulserver.filters.PreFilter   : ============ assu-correlation-id found in pre filter: c0ece664-d1bc-4b76-b031-c2fab3597727. 
2020-09-11 23:29:26.734 DEBUG 71032 --- [io-5555-exec-10] c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/evt/event/gift/flower.
2020-09-11 23:29:26.746 DEBUG 71032 --- [io-5555-exec-10] c.a.cloud.zuulserver.filters.PostFilter  : ============ Adding the correlation id to the outbound headers. c0ece664-d1bc-4b76-b031-c2fab3597727
2020-09-11 23:29:26.746 DEBUG 71032 --- [io-5555-exec-10] c.a.cloud.zuulserver.filters.PostFilter  : ============ Completing outgoing request for /api/evt/event/gift/flower.
2020-09-11 23:29:26.752 DEBUG 71032 --- [nio-5555-exec-9] c.a.cloud.zuulserver.filters.PostFilter  : ============ Adding the correlation id to the outbound headers. c0ece664-d1bc-4b76-b031-c2fab3597727
2020-09-11 23:29:26.752 DEBUG 71032 --- [nio-5555-exec-9] c.a.cloud.zuulserver.filters.PostFilter  : ============ Completing outgoing request for /api/mb/member/gift/flower.
```

![사후필터를 통해 응답 헤더에 상관관계 ID 삽입](/assets/img/dev/2020/0905/postfilter.png)
 
---

## 4. Zuul 의 고가용성

모든 트래픽이 Zuul 을 통해 들어오기 때문에 Zuul 의 고가용성은 매우 중요하며, 반드시 필요하다.

Zuul 의 고가용성 아키텍처는 유레카를 사용할 수 있는지 없는지에 따라 나뉜다.

- **클라이언트가 Eureka Client 이기도 할 때**<br />
클라이언트가 Eureka Client 이기도 하면 Zuul 은 다른 마이크로서비스와 마찬가지로 자신의 서비스 ID 를 유레카 레지스트리에 자신을 등록하고,
클라이언트는 유레카 레지스트리에 등록된 서비스 ID 를 통해 Zuul 인스턴스에 접근할 수 있다.

![클라이언트가 Eureka Client 이기도 할 때의 Zuul 고가용성 아키텍처](/assets/img/dev/20200826/config_eureka_zuul.png)


- **클라이언트가 Eureka Client 가 아닐 때**<br />
클라이언트가 Eureka Client 가 아니면 Eureka Server 에 의한 부하 분산 처리를 쓸 수 없음으로 로드 밸런서를 사용해야 한다.<br />
클라이언트와 Zuul 사이에 로드 밸런서를 두어서 클라이언트는 로드 밸런서로 요청을 보내고 로드 밸런서가 사용할 Zuul 인스턴스를 식별해내는 방법이다.

---

## 덧붙임
사실 라우팅 필터를 구현하려다 더 좋은 솔루션을 발견하여 그 부분을 먼저 진행하려 라우팅 필터는 다루지 않았다.<br />
정확히 말하면 라우팅 필터를 대신하는 솔루션이 아니라 내가 구현하고자 하는 기능을 라우팅 필터로 구현하려 했는데
마라톤이라는 더 적합한 솔루션이 있다는 것을 알았다.
(시도해보고 안 되면 다시 라우팅 필터 내용 채울 예정...)

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/](https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/)
* [https://spring.io/guides/gs/routing-and-filtering/](https://spring.io/guides/gs/routing-and-filtering/)
* [https://github.com/Netflix/zuul/wiki/How-it-Works](https://github.com/Netflix/zuul/wiki/How-it-Works)
