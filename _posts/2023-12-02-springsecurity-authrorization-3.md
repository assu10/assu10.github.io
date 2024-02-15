---
layout: post
title:  "Spring Security - 인증 구현(3): HTTP Basic 인증"
date:   2023-12-02
categories: dev
tags: spring-security http-basic
---

`HTTP Basic` 인증 방식과 양식 기반 로그인 인증 방식에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0504) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `HTTP Basic` 인증](#1-http-basic-인증)
* [2. 양식 기반 로그인으로 인증](#2-양식-기반-로그인으로-인증)
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

# 1. `HTTP Basic` 인증

HTTP Basic 은 기본 인증 방식으로써, 일부 설정을 맞춤 구성하는 방법에 대해 알아보자.

예를 들어 인증 프로세스가 실패할 때는 위한 특정한 논리를 구현하거나, 클라이언트로 반환되는 응답의 일부값을 설정하는 등의 작업을 의미한다.

아래는 HTTP Basic 인증 방식을 명시적으로 설정하는 예시이다.

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  // HTTP Basic 방식을 명시적으로 설정
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    // 모든 요청에 인증이 필요
    http.authorizeHttpRequests(authz -> authz.anyRequest().authenticated()).httpBasic(Customizer.withDefaults());

    // 모든 요청에 인증 없이 요청 가능
    //http.authorizeHttpRequests(authz -> authz.anyRequest().permitAll()).httpBasic(Customizer.withDefaults());

    return http.build();
  }
}
```

아래는 realm (영역) 처럼 인증 방식과 관련된 일부 구성을 변경하는 예시이다.  
realm 은 특정 인증 방식을 이용하는 보호 공간으로 생각하면 된다.

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  // HTTP Basic 방식을 명시적으로 설정
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    // 모든 요청에 인증이 필요
    //http.authorizeHttpRequests(authz -> authz.anyRequest().authenticated()).httpBasic(Customizer.withDefaults());

    // 모든 요청에 인증 없이 요청 가능
    //http.authorizeHttpRequests(authz -> authz.anyRequest().permitAll()).httpBasic(Customizer.withDefaults());

    // 인증 방식과 관련한 일부 구성 중 영역 이름을 설정하는 예시
    http.authorizeHttpRequests(authz -> authz.anyRequest().authenticated()).httpBasic(c -> {
      c.realmName("OTHER");
    });

    return http.build();
  }
}
```

사용된 람다식은 `Customizer<HttpBasicConfigurer<HttpSecurity>>` 형식의 객체인데, `HttpBasicConfigurer<HttpSecurity>` 형식의 
매개 변수로 realName() 을 호출하여 영역 이름을 변경할 수 있게 해준다.

이제 curl 에 `-v` 플래그를 지정한 후 응답을 보면 영역 이름이 변경된 것을 확인할 수 있다.

참고로 WWW-Authenticate 헤더는 응답에서 HTTP 응답 상태가 401 일 때만 있고, 200 일 때는 없다.

```shell
$ curl -v -w "%{http_code}" -u user:ccee5f2d-8a4f-4cdf-bcd3-753d328e6ae2 http://localhost:8080/hello

* Authentication problem. Ignoring this.
< WWW-Authenticate: Basic realm="OTHER"
```

아래는 인증이 실패했을 때 응답을 맞춤 구성하는 예시이다.

/config/CustomEntryPoint.java
```java
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;

import java.io.IOException;

public class CustomEntryPoint implements AuthenticationEntryPoint {
  // 응답이 실패했을 때 응답에 헤더를 추가하고, HTTP 상태를 401 로 변경하는 예시
  @Override
  public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException authException) throws IOException, ServletException {
    response.addHeader("message", "ASSU, Welcome");
    response.sendError(HttpStatus.UNAUTHORIZED.value());
  }
}
```

/config/ProjectConfig.java
```java
package com.assu.study.chap0504.config;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  // HTTP Basic 방식을 명시적으로 설정
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    // 모든 요청에 인증이 필요
    //http.authorizeHttpRequests(authz -> authz.anyRequest().authenticated()).httpBasic(Customizer.withDefaults());

    // 모든 요청에 인증 없이 요청 가능
    //http.authorizeHttpRequests(authz -> authz.anyRequest().permitAll()).httpBasic(Customizer.withDefaults());

    http.authorizeHttpRequests(authz -> authz.anyRequest().authenticated()).httpBasic(c -> {
      c.realmName("OTHER"); // 인증 방식과 관련한 일부 구성 중 영역 이름을 설정
      c.authenticationEntryPoint(new CustomEntryPoint()); // 맞춤형 진입점 등록 
    });

    return http.build();
  }
}
```

이제 응답이 실패하도록 엔드포인트를 호출하면 위에서 추가한 헤더가 나타나는 것을 확인할 수 있다.
```shell
$ curl -v -w "%{http_code}" http://localhost:8080/hello

< message: ASSU, Welcome
```

---

# 2. 양식 기반 로그인으로 인증

> 양식 기반 로그인의 경우 `SecurityContext` 를 관리하는데 있어서 서버 쪽 세션을 사용함  
> scale-out 이 필요한 대형 애플리케이션에서 `SecurityContext` 를 관리하는데 서버 쪽 세션을 이용하는 것은 좋지 않음  
> 
> 그래서 이 부분은 필요 시 알아볼 예정

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.jetbrains.com/help/idea/markdown.html#floating-toolbar)