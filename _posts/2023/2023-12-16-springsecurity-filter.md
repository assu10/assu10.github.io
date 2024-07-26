---
layout: post
title:  "Spring Security - 필터"
date: 2023-12-16
categories: dev
tags: spring-security filter once-per-request-filter
---

이 포스트에서는 스프링 시큐리티의 인증과 권한 부여 아키텍처의 일부인 필터를 맞춤 구성하는 법에 대해 알아본다.

- 필터 체인
- 맞춤형 필터 정의
- Filter 인터페이스를 구현하는 스프링 시큐리티 클래스 이용

---

**목차**

<!-- TOC -->
* [1. 스프링 시큐리티 아키텍처의 필터 개념](#1-스프링-시큐리티-아키텍처의-필터-개념)
* [2. 기존 필터 앞에 필터 추가](#2-기존-필터-앞에-필터-추가)
* [3. 기존 필터 뒤에 필터 추가](#3-기존-필터-뒤에-필터-추가)
* [4. 필터 체인의 다른 필터 위치에 필터 추가](#4-필터-체인의-다른-필터-위치에-필터-추가)
* [5. `OncePerRequestFilter`](#5-onceperrequestfilter)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.2.2
- Spring ver: 6.1.3
- Spring Security ver: 6.2.1
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven

![Spring Initializer Sample](/assets/img/dev/2023/1112/init.png)

---

스프링 시큐리티에는 인증 책임을 `AuthenticationProvider` 에게 위임하는 `AuthenticationFilter` 도 있고, 인증 성공 후 권한 부여 구성을 처리하는 
`AuthorizationFilter` 도 있다.

> `AuthorizationFilter` 에 대한 내용은 [Spring Security - 권한 부여(1): 권한과 역할에 따른 액세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-1/), 
> [Spring Security - 권한 부여(2): 경로, HTTP Method 에 따른 엑세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-2/) 을 참고하세요.

HTTP 필터는 일반적으로 요청에 적용해야 하는 각 책임을 관리하고 책임의 체인을 형성한다.  

**필터는 요청을 수신하고, 논리 실행 후 최종적으로 체인의 다음 필터에게 요청을 위임**한다.

스프링 시큐리티는 맞춤 구성을 통해 필터 체인에 추가할 수 있는 필터 구현을 제공하지만 맞춤형 필터를 정의할 수도 있다.  
실제 운영 시엔 다양한 요구사항이 있기 때문에 기본 구성으로는 부족한 경우가 많으므로 체인에 구성 요소를 추가하거나, 기존 구성 요소를 대체해야 한다.

필터를 맞춤형 구성해야 하는 경우의 예는 아래와 같다.  
- 이메일 주소 검사 추가
- OTP 검증 단계 추가
- 인증 감사와 관련된 기능 추가
- 다른 인증 전략 구현 (기본 구현에서는 HTTP Basic 인증 방식 이용)
- 추적에 필요한 로깅

![기존 필터의 앞이나 뒤에 새로운 필터를 추가하여 필터 체인 맞춤 구성](/assets/img/dev/2023/1216/filter.png)

---

# 1. 스프링 시큐리티 아키텍처의 필터 개념

여기서는 스프링 시큐리티 아키텍처에서 필터와 필터 체인이 동작하는 방식에 대해 알아본다.

`AuthenticationFilter` (인증 필터) 는 요청을 가로채서 인증 책임을 `AuthorizationFilter` (권한 부여 필터) 에게 위임한다.

![권한 부여 흐름](/assets/img/dev/2023/1209/authorization.png)

만약에 인증 이전에 특정 논리를 실행하려면 `AuthenticationFilter` 앞에 필터를 추가하면 된다.

**스프링 시큐리티 아키텍처의 필터는 일반적인 HTTP 필터**이다. 따라서 필터를 만들려면 jakarta.servlet.Filter 인터페이스를 구현한다.
다른 HTTP 필터와 마찬가지로 `doFilter()` 메서드를 재정의해 논리를 구현한다.

> **`OncePerRequestFilter`**  
> 
> 동일한 request 안에서 한번만 실행되는 필터  
> 인증/인가, 인증/인가를 거친 후 특정 URL 로 포워딩될 때 등과 같이 한 번만 거쳐야 할 때 사용됨  
> 예) 일반 Filter 사용할 때 API /aa 처리 후 API /bb 로 리다이렉트 시 클라이언트는 한 번의 요청을 했지만 필터는 두 번 실행됨  
> 만일 Filter 가 한 번만 실행되어야 하는 로직이 있는 Filter 인 경우 `Filter` 가 아닌 `OncePerRequestFilter` 사용으로 해결

`Filter` 인터페이스
```java
package jakarta.servlet;

import java.io.IOException;

public interface Filter {
  default void init(FilterConfig filterConfig) throws ServletException {
  }

  void doFilter(ServletRequest var1, ServletResponse var2, FilterChain var3) throws IOException, ServletException;

  default void destroy() {
  }
}
```

- `ServletRequest`
  - HTTP 요청을 나타냄
- `ServletResponse`
  - HTTP 응답을 나타냄
  - 이 객체를 이용하여 응답을 클라이언트로 다시 보내기 전, 혹은 필터 체인에서 응답을 변경함
- `FilterChain`
  - 체인의 다음 필터로 요청을 전달

**필터 체인은 필터가 작동하는 순서가 정의된 필터의 모음**이다.

아래는 스프링 시큐리티에서 제공하는 필터 구현 중 일부이다.  
- `BasicAuthenticationFilter`
  - HTTP Basic 인증 처리
- `CsrfFilter`
  - CSRF (사이트 간 요청 위조) 처리
- `CorsFilter`
  - CORS (교차 출처 리소스 공유) 권한 부여 규칙 처리

> CSRF, CORS 에 대한 상세한 내용은  
> [Spring Security - CSRF (Cross-Site Request Forgery, 사이트 간 요청 위조)](https://assu10.github.io/dev/2023/12/17/springsecurity-csrf/),  
> [Spring Security - CORS (Cross-Site Resource Sharing, 교차 출처 리소스 공유)](https://assu10.github.io/dev/2024/01/09/springsecurity-cors/) 를 참고하세요.

필터 체인에 모든 필터가 인스턴스를 반드시 가질 필요는 없다. 예를 들어 HTTP Basic 인증 방식을 이용하려면 HttpSecurity.httpBasic() 을 호출해야 하는데 
이 메서드를 호출하면 필터 체인에 `BasicAuthenticationFilter` 가 추가된다.

```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
http
    .authorizeHttpRequests(authz -> {
      authz.requestMatchers(RegexRequestMatcher.regexMatcher(".*/(us|uk|ca)+/(en|fr).*")).authenticated();
      authz.anyRequest().hasRole("SUPER");
    })
    .httpBasic(Customizer.withDefaults());  // BasicAuthenticationFilter 추가
return http.build();
}
```

새로운 필터는 기존 필터 위치의 앞이나 뒤에 추가할 수 있으며, 각 위치는 숫자로 된 index (순서) 를 의미한다.
이 순서 번호에 따라 필터가 적용되는 순서가 결정된다.  

같은 위치에 필터를 2개 이상 추가할 수도 있는데 이럴 경우 필터가 호출되는 순서가 보장받지 못하므로 권장하지 않는다.

> 같은 위치에 여러 개의 필터가 추가되어 혼란을 일으키는 예시는 [4. 필터 체인의 다른 필터 위치에 필터 추가](#4-필터-체인의-다른-필터-위치에-필터-추가) 에 있음 

---

# 2. 기존 필터 앞에 필터 추가

필터 체인에서 기존 필터 앞에 맞춤형 HTTP 필터를 추가해본다.

아래와 같은 요구사항에 맞게 필터를 구현해보자.
- 모든 요청에는 필수로 요청을 추적하는 Request-id 가 있음
- 인증을 수행하기 전에 이 헤더가 있는지 검증

인증 프로세스에는 DB나 다른 리소스를 소비하는 작업이 포함될 수 있기 때문에 요청이 유효하지 않을 경우엔 인증 프로세스를 실행할 필요가 없다.

아래의 순서로 진행해보자.
- 필터 구현
  - 요청에 필요한 헤더가 있는지 확인
- 필터 체인에 필터 추가
  - 구성 클래스에서 필터 체인에 필터 추가

![인증 필터 앞에 RequestValidationFilter 추가](/assets/img/dev/2023/1216/add_filter.png)

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0901) 에 있습니다.

/filter/RequestValidationFilter.java
```java
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

public class RequestValidationFilter implements Filter {
  /**
   * 필터의 논리 작성
   * <p>
   * 헤더에 Request-id 가 있는지 확인 후 있으면 doFilter() 를 호출하여 체인의 다음 필터로 요청 전달
   * 없으면 다음 필터로 요청을 전달하지 않고 HTTP 400 반환
   */
  @Override
  public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
    HttpServletRequest httpRequest = (HttpServletRequest) servletRequest;
    HttpServletResponse httpResponse = (HttpServletResponse) servletResponse;

    String requestId = httpRequest.getHeader("Request-id");

    if (requestId == null || requestId.isBlank()) {
      httpResponse.setStatus(HttpServletResponse.SC_BAD_REQUEST); // 400 response
      return; // 요청이 다음 필터로 전달되지 않음
    }

    filterChain.doFilter(servletRequest, servletResponse);
  }
}
```

/config/ProjectConfig.java
```java
import com.assu.study.chap0901.filter.RequestValidationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.www.BasicAuthenticationFilter;

@Configuration
public class ProjectConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

    http
        .addFilterBefore(new RequestValidationFilter(), BasicAuthenticationFilter.class)  // 인증 필터 앞에 맞춤형 필터 추가
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll()) // 인증없이 모든 요청 접근 가능
        .httpBasic(Customizer.withDefaults());
    return http.build();
  }
}
```

이제 엔드포인트를 호출해보면 헤더가 없을 경우 401 응답이 내려오는 것을 확인할 수 있다

```shell
$ curl -w "%{http_code}" http://localhost:8080/hello
400%

$ curl -w "%{http_code}" --header 'Request-id: 1111'  http://localhost:8080/hello
Hello!200%
```
---

# 3. 기존 필터 뒤에 필터 추가

필터 체인에서 기존 필터 뒤에 맞춤형 HTTP 필터를 추가해본다.

아래와 같은 요구사항에 맞게 필터를 구현해보자.
- 인증을 수행한 후 헤더에 있는 Request-id 로깅

/filter/AuthenticationLoggingFilter.java
```java
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.logging.Logger;

// request 당 한번만 실행하기 위해 Filter 가 아닌 OncePerRequestFilter 구현
public class AuthenticationLoggingFilter extends OncePerRequestFilter {

  private final Logger logger = Logger.getLogger(AuthenticationLoggingFilter.class.getName());

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
    String requestId = request.getHeader("Request-id");

    logger.info("logging request-id: " + requestId);

    // 요청을 필터 체인의 다음 필터에 전달
    filterChain.doFilter(request, response);
  }
}
```

/config/ProjectConfig.java
```java
@Configuration
public class ProjectConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .addFilterBefore(new RequestValidationFilter(), BasicAuthenticationFilter.class)  // 인증 필터 앞에 맞춤형 필터 추가
        .addFilterAfter(new AuthenticationLoggingFilter(), BasicAuthenticationFilter.class) // 인증 필터 뒤에 맞춤형 필터 추가
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll()) // 인증없이 모든 요청 접근 가능
        .httpBasic(Customizer.withDefaults());
    return http.build();
  }
}
```

---

# 4. 필터 체인의 다른 필터 위치에 필터 추가

필터 체인에서 다른 필터 위치에 맞춤형 필터를 추가하는 법에 대해 알아본다.

스프링 시큐리티의 기존 필터가 수행하는 책임에 대해 다른 필터 구현을 제공할 때 사용한다.  
일반적으로 인증에서 많이 사용되는 접근법이다.

예) HTTP Basic 인증 대신 다른 인증법을 적용할 때

- 인증을 위한 정적 헤더값에 기반을 둔 식별
  - 인증 보안 수준은 낮지만 단순하다는 장점이 있어 [백엔드 간 통신 시 데이터를 보호하고자 할 때 자주 사용됨](https://assu10.github.io/dev/2023/11/11/springsecurity-basic/#24-api-%ED%82%A4-%EC%95%94%ED%98%B8%ED%99%94-%EC%84%9C%EB%AA%85-ip-%EA%B2%80%EC%A6%9D%EC%9D%84-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EC%9A%94%EC%B2%AD-%EB%B3%B4%EC%95%88)
  - 클라이언트 ͍ 백엔드 간 통신 시에도 클라이언트는 HTTP 요청의 헤더에 항상 동일한 문자열을 넣어 백엔드로 전달 후 이 값을 식별하여 통신함
- 대칭키를 이용하여 인증 요청 서명
  - [백엔드 간 통신 시 데이터를 보호하고자 할 때 사용됨](https://assu10.github.io/dev/2023/11/11/springsecurity-basic/#24-api-%ED%82%A4-%EC%95%94%ED%98%B8%ED%99%94-%EC%84%9C%EB%AA%85-ip-%EA%B2%80%EC%A6%9D%EC%9D%84-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EC%9A%94%EC%B2%AD-%EB%B3%B4%EC%95%88)  
  > [1.4. 인코딩, 암호화, 해싱](https://assu10.github.io/dev/2023/11/19/springsecurity-password/#14-%EC%9D%B8%EC%BD%94%EB%94%A9-%EC%95%94%ED%98%B8%ED%99%94-%ED%95%B4%EC%8B%B1) 에 대칭키, 비대칭키 내용 참고
  - 대칭키로 요청에 서명/검증하며, 클라이언트와 서버가 모두 키의 값을 아는 상태 (= 클라이언트와 서버가 키를 공유)
  - 클라이언트는 이 키로 요청의 일부에 서명하고(예를 들어 특정 헤더의 값에 서명), 서버는 같은 키로 서명이 유효한지 확인
  - 서버는 각 클라이언트의 개별키를 DB 나 Vault 에 저장
  - 비슷하게 비대칭 키 쌍을 이용할 수도 있음
- OTP 이용

여기서는 간단하게 정적 헤더값에 기반을 둔 식별값을 이용하는 인증법을 선택한다.

구현할 내용은 아래와 같다.
- 모든 요청에 대해 같은 정적 키 값 이용
- 사용자는 인증을 받으려면 Authorization 헤더에 정적 키 값을 추가해야 함

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0902) 에 있습니다.

/filter/StaticKeyAuthenticationFilter.java
```java
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component  // 속성 파일에서 값을 주입할 수 있도록 스프링 컨텍스트에 클래스 인스턴스 추가
public class StaticKeyAuthenticationFilter extends OncePerRequestFilter {

  @Value("${authorization.key}")
  private String AUTHORIZATION_KEY;

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
    String staticKey = request.getHeader("Authorization");

    if (AUTHORIZATION_KEY.equals(staticKey)) {
      filterChain.doFilter(request, response);
    } else {
      // 다음 필터로 요청을 전달하지 않고 401 응답
      response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); // 401
    }
  }
}
```

이제 `addFilterAt()` 을 이용하여 기존의 BasicAuthenticationFilter 가 있던 위치에 새로 구현한 필터를 추가한다.

/config/ProjectConfig.java
```java
import com.assu.study.chap0902.filter.StaticKeyAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.www.BasicAuthenticationFilter;

@Configuration
@RequiredArgsConstructor
public class ProjectConfig {

  private final StaticKeyAuthenticationFilter filter;

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .addFilterAt(filter, BasicAuthenticationFilter.class)
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll()); // 인증없이 모든 요청 접근 가능
    //.httpBasic(Customizer.withDefaults());  // HTTP Basic 인증 대신 정적키 필터를 사용하므로 호출하지 않음
    return http.build();
  }
}
```

**addFilterAt() 사용 시 주의점**  
특정 위치에 필터를 추가하면 기존의 필터가 대체되는 것이 아니라, 같은 위치에 필터가 추가되기 때문에 스프링 시큐리티는 필터가 실행되는 순서를 보장하지 않는다.  
필터 체인에 필요없는 필터는 아예 추가하지 말아야 하며, 체인의 같은 위치에 여러 필터를 추가하지 않는게 좋다.  
그래서 이번 내용에서도 HTTP Basic 인증 대신 정적 키 인증을 사용하기 때문에 .httpBasic() 메서드는 호출하지 않는다.

아래와 같이 올바른 키를 넣었을 때만 인증이 되는 것을 확인할 수 있다.
```shell
$ curl -w "%{http_code}" --header 'Authorization: 2222'  http://localhost:8080/hello
Hello!200%

$ curl -w "%{http_code}" --header 'Authorization: 2221'  http://localhost:8080/hello
401%
```

이 경우 `UserDetailsService` 를 구성하지 않았기 때문에 스프링 부트가 자동으로 구성하지만 위와 같이 사용자의 개념이 없는 시나리오에서는 `UserDetailsService` 필요없이 
서버의 엔드포인트 호출을 요청하는 사용자만 검증한다. (실제 운영 시에 이런 경우는 거의 없긴 하다)

만일 `UserDetailsService` 구성 요소가 필요하지 않아서 기본 `UserDetailsService` 를 비활성화하려면 아래와 같이 부트 스트랩 클래스에 설정해주면 된다.

```java
@SpringBootApplication(exclude = {UserDetailsServiceAutoConfiguration.class})
```

---

# 5. `OncePerRequestFilter`

`OncePerRequestFilter` 클래스는 아래와 같은 특징이 있다.

- **HTTP 요청만 지원함**
  - 하지만 사실 항상 HTTP 요청만 처리하기 때문에 오히려 장점이 될 수도 있음
  - `Filter` 와 `OncePerRequestFilter` 의 매개변수를 보면 `OncePerRequestFilter` 는 HttpServletRequest, HttpServletResponse 로 직접 수신하기 때문에 요청과 응답을 형변환할 필요가 없음
  
```java 
// Filter
doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain)

// OncePerRequestFilter
doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
```

- **필터가 적용될 지 결정하는 논리 구현 가능**
  - `shouldNotFilter(HttpServletRequest)` 를 재정의하여 필터 체인에 추가한 필터가 특정 요청에는 적용되지 않게 결정 가능
  - 기본적으로 필터는 모드느 요청에 적용됨
- **기본적으로 비동기 요청이나 오류 발송 요청에는 적용되지 않음**
  - 이 동작을 변경하려면 `shouldNotFilterAsyncDispatch()`, `shouldNotFilterErrorDispatch()` 메서드를 재정의하면 됨

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [OncePerRequestFilter vs GenericFilterBean](https://velog.io/@jmjmjmz732002/Springboot-OncePerRequestFilter-vs-GenericFilterBean)
* [OncePerRequestFilter](https://junyharang.tistory.com/378)
