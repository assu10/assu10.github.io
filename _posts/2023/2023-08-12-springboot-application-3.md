---
layout: post
title:  "Spring Boot - 웹 애플리케이션 구축 (3): Interceptor, ServletFilter"
date: 2023-08-12
categories: dev
tags: springboot msa interceptor servletFilter
---

이 포스트에서는 인터셉터와 서블릿 필터에 대해 알아본다. 

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap06) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. Interceptor, ServletFilter 설정](#1-interceptor-servletfilter-설정)
* [2. HandlerInterceptor 인터페이스](#2-handlerinterceptor-인터페이스)
* [3. Filter 인터페이스](#3-filter-인터페이스)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap06

![Spring Initializer](/assets/img/dev/2023/0805/init.png)

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>com.assu</groupId>
    <artifactId>study</artifactId>
    <version>1.1.0</version>
  </parent>

  <artifactId>chap06</artifactId>

  <packaging>jar</packaging><!-- 패키징 타입 추가 -->

  <dependencies>
    <dependency>
      <groupId>com.fasterxml.jackson.dataformat</groupId>
      <artifactId>jackson-dataformat-xml</artifactId>
    </dependency>
  </dependencies>

  <!-- 이 플러그인은 메이븐의 패키지 단계에서 실행되며, 컴파일 후 표준에 맞는 디렉터리 구조로 변경하여 JAR 패키지 파일을 생성함 -->
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

---

# 1. Interceptor, ServletFilter 설정

스프링 MVC 프레임워크는 [Front Controller Pattern](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/#21-dispatcherservlet) 으로 구현된
DispatcherServlet 이 클라이언트의 모든 요청과 응답을 처리한다.

DispatcherServlet 이 모든 요청과 응답을 처리하기 때문에 여기에 공통 기능을 추가한다면 웹 애플리케이션에 쉽게 공통 기능을 구현할 수 있다.

이러한 목적으로 스프링 웹 MVC 프레임워크는 o.s.web.servlet.HandlerInterceptor 인터페이스를 제공하는데, 개발자가 **HandlerInterceptor 를 구현하여 설정하면
웹 애플리케이션 전체에 공통 기능으로 확장**할 수 있다.

비슷하게 **서블릿 스펙에서도 서블릿 전체에 공통 기능을 추가할 수 있는 ServletFilter 를 제공**한다.

![서블릿 필터와 인터셉터](/assets/img/dev/2023/0812/filter_and_interceptor.png)

- **서블릿 필터**
  - 서블릿 스펙에서 제공
  - DispatcherServlet 앞에서 요청과 응답을 처리
  - WAS 에서 사용할 수 있는 기술이며, 기능을 웹 애플리케이션에 추가할 때도 WAS 에 설정해야 함
  - 서블릿 필터는 여러 개 등록 가능하며, 설정을 하면 특정 URI 에만 필터 기능 적용 가능
  - 서블릿 스펙에서 제공하는 `HttpServletRequest`, `HttpServletResponse` 객체에 포함된 스트림 객체를 직접 다룰 수 있음
  - 이를 활용하면 REST-API 의 최초 요청 메시지나 최종 응답 메시지의 바디를 로그로 남길 수 있음
  - 물론 HttpServletRequest 나 HttpServletResponse 의 바디는 IO 스트림이기 때문에 휘발성이므로 서블릿 필터에서 바디 내용을 읽으면 애플리케이션에서는 바디 내용이 날아가고 없음
  - 그래서 별도의 버퍼를 사용하거나 java.io.lPipedInputStream, PipedOutputStream 객체를 사용해야 함 
- **인터셉터**
  - 스프링 웹 MVC 프레임워크에서 제공하므로 표준 스펙이 아님 (스프링 프레임워크에서만 사용 가능)
  - 스프링 프레임워크 내부에서 동작하는 기능
  - 인터셉터를 스프링 애플리케이션에 추가하려면 서블릿 필터와 달라 WebMvcConfigurer 인터페이스에서 제공하는 `addInterceptor()` 메서드를 오버라이드하여 설정
  - 컨트롤러 클래스의 핸들러 메서드와 같이 처리되므로 핸들러 메서드의 메서드 시그니처나 메서드 파라메터와 같은 정보들을 중간에 가로챌 수 있음
  - 비즈니스 로직에서 발생한 예외 객체를 받아 처리 가능
  - 서블릿 필터와 마찬가지로 특정 URI 에만 적용 가능


---

# 2. HandlerInterceptor 인터페이스

HandlerInterceptor 은 3 개의 디폴트 메서드를 제공하며, 각 메서드는 실행 시점이 다르다.

HandlerInterceptor 
```java
public interface HandlerInterceptor {
	default boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
			throws Exception {
		return true;
	}
	default void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler,
			@Nullable ModelAndView modelAndView) throws Exception {
	}
	default void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler,
			@Nullable Exception ex) throws Exception {
	}
}
```

- `preHandle()`
  - DispatcherServlet 이 컨트롤러의 핸들러 메서드를 실행하기 전에 먼저 실행됨
  - HttpServletRequest, HttpServletResponse 를 사용하여 요청/응답 메시지의 데이터를 참조하거나 변경 가능
  - Object 인자는 컨트롤러 클래스의 핸들러 메서드를 참조하는 HandlerMethod 객체이므로 메서드 정보를 참조할 수 있음
- `postHandle()`
  - 컨트롤러의 핸들러 메서드가 비즈니스 로직을 실행 완료한 후 실행됨
- `afterCompletion()`
  - 뷰가 실행완료된 후 최종적으로 DispatcherServlet 이 사용자에게 응답하기 전에 실행됨
  - 비즈니스 로직 실행 과정에서 예외 발생 시 예외 객체는 afterCompletion() 의 인자로 주입됨
  - 예외 객체를 사용하여 예외 정보를 참조하거나 처리할 수 있음

스프링 프레임워크는 HandlerInterceptor 인터페이스를 구현하는 여러 구현체를 제공하는데 [LocaleResolver](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#12-webmvcconfigurer-%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EC%84%A4%EC%A0%95) 와 비슷한 역할을 하는 
`LocaleChangeInterceptor` 는 요청 HTTP 메시지의 URI 에 포함된 파라메터 값을 사용하여 현재 설정된 Locale 객체를 변경하는 역할을 한다.  
Locale 값을 변경하는 기본 파라메터명은 'locale' 이다.

파라메터값는 언어 태그나 지역 코드를 합친 언어 태그를 사용하고 보통 java.util.Locale 객체의 toString() 값을 사용한다.

> en_US 에서 en 은 언어 태그, US 는 지역 태그  

> 국제화(i18n) 의 좀 더 자세한 내용은 [Spring Boot - 웹 애플리케이션 구축 (5): 국제화 메시지 처리, 로그 설정, 애플리케이션 패키징과 실행](https://assu10.github.io/dev/2023/08/19/springboot-application-5/#1-rest-api-%EC%99%80-%EA%B5%AD%EC%A0%9C%ED%99%94-%EB%A9%94%EC%8B%9C%EC%A7%80-%EC%B2%98%EB%A6%AC) 의 _1. REST-API 와 국제화 메시지 처리_ 를 참고하세요.

`LocaleResolver` 와 `LocaleChangeInterceptor` 는 Locale 을 처리하는 역할은 같지만 그 기능은 다르다.

- **LocaleResolver**
  - 사용자 요청 메시지에서 Locale 정보를 분석하여 Locale 객체 생성(resolveLocale()) 하고, Locale 객체를 저장(setLocale())
  - Locale 객체는 사용자마다 다른 값이 될 수 있고, 저장 대상이 쿠키, 세션 등이 될 수 있음
- **LocaleChangeInterceptor**
  - 저장된 Locale 객체를 HTTP 파라메터를 사용하여 변경함

따라서 두 클래스는 기능을 서로 보완하는 관계이며, LocaleResolver 없이 LocaleChangeInterceptor 혼자 동작하지 않는다.

인터페이스 구현체를 스프링 프레임워크에 추가하기 위해 `WebMvcConfigurer` 인터페이스에  `addInterceptor()` 를 설정한다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    LocaleChangeInterceptor localeChangeInterceptor = new LocaleChangeInterceptor();
    // locale 파라메터값을 Locale 객체로 변경
    localeChangeInterceptor.setParamName("locale");
    // 인터셉터 추가
    registry.addInterceptor(localeChangeInterceptor)
        // 인터셉터 기능을 제외한 URI 패턴 입력
        .excludePathPatterns("favicon.ico")
        // 인터셉터가 동작할 경로
        .addPathPatterns("/**");
  }
}
```

---

# 3. Filter 인터페이스

서블릿 필터 구현체를 만들려면 javax.servlet.Filter 인터페이스를 구현해야 한다.

Filter 인터페이스는 2개의 디폴트 메서드와 1개의 추상 메서드가 선언되어 있다.

Filter 인터페이스
```java
public interface Filter {
  default void init(FilterConfig filterConfig) throws ServletException {
  }

  void doFilter(ServletRequest var1, ServletResponse var2, FilterChain var3) throws IOException, ServletException;

  default void destroy() {
  }
}
```

- `init()`
  - 웹 애플리케이션이 시작하면 서블릿 필터를 초기화하는데 이 때 init() 메서드가 실행됨
  - 따라서 애플리케이션을 실행하면서 내부 로직을 초기화하는 기능을 구현하면 됨
- `doFilter()`
  - 서블릿 필터의 필터링 역할
  - 서블릿 필터와 매핑된 사용자 요청마다 실행됨
  - ServletRequest, ServletResponse 인자를 사용하여 요청/응답 메시지의 데이터를 참조하거나 가공 가능
  - FilterChain 인자는 서블릿 필터의 묶음을 의미함
  - FilterChain 클래스에서 제공하는 doFilter() 메서드(서블릿 필터에서 제공하는 doFilter() 가 아님)를 호출하면 다음 로직을 계속해서 실행할 수 있음
- `destroy()`
  - 웹 애플리케이션이 종료될 때 서블릿 필터도 종료되는대 이 때 destroy() 메서드가 실행됨

특정 URI 에 한 개 이상의 서블릿 필터를 설정할 수 있고, 각 서블릿 필터들은 설정된 실행 순서에 다라 doFilter() 메서드를 실행한다.  
이렇게 순서대로 객체들을 설정하고 차례로 자신의 기능을 실행하는 디자인 패턴을 역할 체인 패턴(chain of responsibility) 라고 한다.  
서블릿 필터는 **역할 체인 패턴**으로 구현된 대표적인 기능이다.


체인에 포함된 서블릿 필터는 자신이 체인의 마지막인지 중간인지 알 수 없기 때문에 FilterChain 인자의 doFilter() 를 호출하여 다음 필터에 전달해야 한다.  
다음 필터가 없다면 DispatcherServlet 이 실행되고 컨트롤러 클래스의 핸들러 메서드가 실행된다.

/server/LoggingFilter.java
```java
import jakarta.servlet.*;

import java.io.IOException;

public class LoggingFilter implements Filter {
  @Override
  public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
    System.out.println("--- LoggingFilter doFilter: 선처리 작업");
    filterChain.doFilter(servletRequest, servletResponse);
    System.out.println("--- LoggingFilter doFilter: 후처리 작업");
  }

  @Override
  public void init(FilterConfig filterConfig) throws ServletException {
    System.out.println("--- LoggingFilter init()");
    System.out.println("--- LoggingFilter init() filterConfig: " + filterConfig);
    Filter.super.init(filterConfig);
  }

  @Override
  public void destroy() {
    System.out.println("--- LoggingFilter destroy()");
    Filter.super.destroy();
  }
}
```

스프링 부트 프레임워크는 서블릿 필터를 스프링 빈으로 등록할 수 있는 o.s.boot.web.servlet.FilterRegistrationBean 클래스를 제공한다.  
자바 설정 클래스에 서블릿 필터를 FilterRegistrationBean 객체로 감싸고 스프링 빈으로 생성하면 된다.

아래는 스트링 브레임워크에서 제공하는 서블릿 필터 구현체 중 하나인 `CharacterEncodingFilter` 와 `FilterRegistrationBean` 을 사용하여 설정한 것이다.

`CharacterEncodingFilter` 는 사용자의 요청/응답 메시지를 특정 문자셋으로 인코딩하는 기능을 제공한다.  
클라이언트에 따라 다른 문자셋으로 데이터를 전송할 수 있으므로 UTF-8 문자셋으로 변경하여 데이터를 처리할 때 주로 사용한다.


/config/WebConfig.java
```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    LocaleChangeInterceptor localeChangeInterceptor = new LocaleChangeInterceptor();
    // locale 파라메터값을 Locale 객체로 변경
    localeChangeInterceptor.setParamName("locale");
    System.out.println("--- Interceptor addInterceptors()");
    // 인터셉터 추가
    registry.addInterceptor(localeChangeInterceptor)
            // 인터셉터 기능을 제외한 URI 패턴 입력
            .excludePathPatterns("favicon.ico")
            // 인터셉터가 동작할 경로
            .addPathPatterns("/**");
  }

  @Bean
  public FilterRegistrationBean<CharacterEncodingFilter> defaultCharacterEncodingFilter() {
    System.out.println("-----defaultCharacterEncodingFilter");
    CharacterEncodingFilter encodingFilter = new CharacterEncodingFilter();
    // CharacterEncodingFilter 의 기본 문자셋을 UTF-8 로 설정
    encodingFilter.setEncoding("UTF-8");
    // CharacterEncodingFilter 서블릿 필터가 적용되는 요청/응답 메시지 모두 설정된 문자셋으로 인코딩
    encodingFilter.setForceEncoding(true);

    FilterRegistrationBean<CharacterEncodingFilter> filterBean = new FilterRegistrationBean<>();
    // 새로 생성한 FilterRegistrationBean 객체에 setFilter() 를 사용하여 CharacterEncodingFilter 서블릿 필터 객체 설정
    filterBean.setFilter(encodingFilter);
    // 초기 파라메터 설정
    // 이 때 파라메터 명과 값을 넣으면 서블릿 필터 인터페이스인 Filter 의 init() 메서드 인자인 FilterConfig 객체에서 사용할 수 있음
    filterBean.addInitParameter("paramName", "paramValue");
    // 필터를 적용할 URL 패턴 설정
    filterBean.addUrlPatterns("*");
    // 두 개 이상의 서블릿 필터를 설정하여 서블릿 필터 체인으로 동작할 때 실행 순서 설정
    filterBean.setOrder(1);

    return filterBean;
  }

  @Bean
  public FilterRegistrationBean<LoggingFilter> defaultLoggingFilter() {
    System.out.println("-----defaultLoggingFilter");
    LoggingFilter loggingFilter = new LoggingFilter();
    FilterRegistrationBean<LoggingFilter> filterBean = new FilterRegistrationBean<>();
    filterBean.setFilter(loggingFilter);
    // 초기 파라메터 설정
    // 이 때 파라메터 명과 값을 넣으면 서블릿 필터 인터페이스인 Filter 의 init() 메서드 인자인 FilterConfig 객체에서 사용할 수 있음
    filterBean.addInitParameter("paramName", "paramValue");
    // 필터를 적용할 URL 패턴 설정
    filterBean.addUrlPatterns("*");
    // 두 개 이상의 서블릿 필터를 설정하여 서블릿 필터 체인으로 동작할 때 실행 순서 설정
    filterBean.setOrder(2);

    return filterBean;
  }
}
```

애플리케이션 기동 시
```shell
-----defaultCharacterEncodingFilter
-----defaultLoggingFilter
--- LoggingFilter init()
--- LoggingFilter init() filterConfig: ApplicationFilterConfig[name=defaultLoggingFilter, filterClass=com.assu.study.chap06.server.LoggingFilter]
--- Interceptor addInterceptors()
```

핸들러 메서드 호출 시
```shell
--- LoggingFilter doFilter: 선처리 작업
--- LoggingFilter doFilter: 후처리 작업
```

애플리케이션 종료 시
```shell
--- LoggingFilter destroy()
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)