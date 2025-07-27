---
layout: post
title:  "Spring Security - CSRF (Cross-Site Request Forgery, 사이트 간 요청 위조)"
date: 2023-12-17
categories: dev
tags: spring-security csrf csrf-filter csrf-token csrf-token-repository
---

이 포스트에서는 스프링 시큐리티가 필터 체인에 추가하는 자체 필터인 CSRF 보호를 적용하는 필터에 대해 알아본다.

- CSRF 보호 구현
- CSRF 보호 맞춤 구성

---

**목차**

<!-- TOC -->
* [1. 스프링 시큐리티에서의 CSRF (Cross-Site Request Forgery): `CsrfFilter`](#1-스프링-시큐리티에서의-csrf-cross-site-request-forgery-csrffilter)
* [2. 실제 운영에서의 CSRF 보호 적용: 프론트엔드와 백엔드가 하나의 서버로 구성된 경우](#2-실제-운영에서의-csrf-보호-적용-프론트엔드와-백엔드가-하나의-서버로-구성된-경우)
* [3. CSRF 보호 맞춤 구성: `CsrfToken`, `CsrfTokenRepository`](#3-csrf-보호-맞춤-구성-csrftoken-csrftokenrepository)
  * [3.1. 특정 엔드포인트만 CSRF 보호 비활성화](#31-특정-엔드포인트만-csrf-보호-비활성화)
  * [3.2. CSRF 토큰 관리를 HTTP 세션 관리에서 DB 관리로 맞춤 구성: `CsrfToken`, `CsrfTokenRepository`](#32-csrf-토큰-관리를-http-세션-관리에서-db-관리로-맞춤-구성-csrftoken-csrftokenrepository)
* [마치며...](#마치며)
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

스프링 시큐리티가 적용된 애플리케이션에서 HTTP POST 로 직접 엔드포인트를 호출할 때 기본적으로는 CSRF 보호를 비활성화해주어야 호출이 가능하다.

아래 순서대로 CSRF 에 대해 알아볼 예정이다.
- CSRF 보호가 무엇이고, 애플리케이션에서 언제 사용해야하는지?
- 스프링 시큐리티가 CSRF 취약성을 완화하는데 이용하는 CSRF 토큰 메커니즘
- 토큰을 얻고 이를 이용해 HTTP POST 방식으로 엔드포인트 호출
- 스프링 시큐리티에서 CSRF 토큰 메커니즘을 맞춤 구성하는 방법

---

# 1. 스프링 시큐리티에서의 CSRF (Cross-Site Request Forgery): `CsrfFilter`

스프링 시큐리티 CSRF 보호를 구현하는 방법에 대해 알아본다.

CSRF 공격은 사용자가 웹 애플리케이션에 로그인했다고 가정하며, 사용자가 작업 중인 브라우저에서 다른 탭으로 위조 스크립트가 삽입된 페이지를 열었을 경우 공격이 시작된다.
사용자가 이미 웹 애플리케이션에 로그인했기 때문에 위조 코드는 이제 사용자를 가장하여 사용자 대신 작업을 수행할 수 있다.

**CSRF 보호는 웹 애플리케이션 프런트엔드만 변경 작업(GET, HEAD, TRACE, OPTIONS 외의 HTTP Method)을 수행할 수 있도록 보장**한다.

> CSRF 보호의 좀 더 상세한 예시는 [1.4. CSRF (Cross-Site Request Forgery, 사이트 간 요청 위조)](https://assu10.github.io/dev/2023/11/11/springsecurity-basic/#14-csrf-cross-site-request-forgery-%EC%82%AC%EC%9D%B4%ED%8A%B8-%EA%B0%84-%EC%9A%94%EC%B2%AD-%EC%9C%84%EC%A1%B0) 를 참고하세요.

CSRF 보호가 동작하는 방식은 아래와 같다.
- 데이터를 변경하기 전에 먼저 한 번은 HTTP GET 으로 웹 페이지를 호출하게 되어있음
- 이 때 애플리케이션은 고유한 토큰(=CSRF 토큰) 생성
- 변경 작업을 포함하는 모든 페이지는 응답을 통해 CSRF 토큰을 받고, 변경 호출을 할 때 이 토큰을 이용함
- 이제부터 애플리케이션은 헤더에 이 고유한 값이 들어있는 요청에 대해서만 변경 작업 (POST, PUT, DELETE..) 을 수행함
- 애플리케이션은 토큰의 값을 안다는 것은 외부가 아닌 애플리케이션 자체가 변경 요청을 보낸 것이라고 봄

CSRF 보호는 필터 체인의 `CsrfFilter` 에서 시작한다.

**`CsrfFilter` 는 요청을 가로채서 GET, HEAD, TRACE, OPTIONS 를 포함하는 HTTP 방식의 요청은 허용하고, 다른 모든 요청에는 토큰이 포함된 헤더가 있는지 확인**한다.
이 헤더가 없거나 잘못된 토큰값이 포함된 경우 요청을 거부하고 403 Forbidden 응답을 내린다.

![CsrfFilter](/assets/img/dev/2023/1217/csrf.png)

`CsrfFilter` 는 `CsrfTokenRepository` 구성 요소를 이용하여 토큰 생성, 저장, 검증에 필요한 CSRF 토큰값을 관리한다.  
기본적으로는 `CsrfTokenRepository` 는 토큰을 HTTP 세션에 저장하고, 랜덤 UUID 로 토큰을 생성한다.

대부분 이것으로 충분하지만 이것으로도 해결이 되지 않으면 `CsrfTokenRepository` 를 직접 구현하는 방법이 있다.

> `CsrfTokenRepository` 를 직접 구현하는 방법은 [3.2. CSRF 토큰 관리를 HTTP 세션 관리에서 DB 관리로 맞춤 구성: `CsrfToken`, `CsrfTokenRepository`](#32-csrf-토큰-관리를-http-세션-관리에서-db-관리로-맞춤-구성-csrftoken-csrftokenrepository) 를 참고하세요.

이제 간단한 프로젝트로 CSRF 에 대해 알아본다.

요구사항은 아래와 같다.
- HTTP GET, POST 의 엔드포인트 생성
- CSRF 토큰을 이용하여 CSRF 보호를 비활성화하지 않고 POST 엔드포인트 호출 (기본적으로는 CSRF 보호를 비활성하지 않으면 POST 로 직접 엔드포인트 호출이 불가함)

**`CsrfFilter` 는 생성된 CSRF 토큰을 `CsrfToekn` 클래스의 인스턴스로서 요청 특성 _csrf 에 저장**한다.  
따라서 `CsrfFilter` 뒤에 필터를 추가하여 `CsrfToken` 인스턴스의 getToken() 을 호출하여 토큰값을 가져올 수 있다.

CSRF 토큰값을 가져올 수 있도록 `CsrfFilter` 뒤에 맞춤형 필터를 추가한다.  
이 맞춤형 필터는 HTTP GET 으로 엔드포인트 호출 시 서버가 생성하는 CSRF 토큰을 콘솔에 출력한다. 그러면 콘솔에 출력된 토큰값일 복사하여 HTTP POST 엔드포인트 호출이 가능하다.

![CsrfFilter 뒤에 CsrfTokenLogger 맞춤형 필터 추가](/assets/img/dev/2023/1217/csrf_filter.png)

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1001) 에 있습니다.

/controller/HelloController.java
```java
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
  @GetMapping("/hello")
  public String getHello() {
    return "Get Hello!";
  }

  @PostMapping("/hello")
  public String postHello() {
    return "Post Hello!";
  }
}
```

/filter/CsrfTokenLogger.java
```java
import jakarta.servlet.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.web.csrf.CsrfToken;

import java.io.IOException;

@Slf4j
public class CsrfTokenLogger implements Filter {
  @Override
  public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
    
    // _csrf 요청 특성에서 토큰값을 얻어 콘솔에 출력
    Object object = servletRequest.getAttribute("_csrf");
    CsrfToken token = (CsrfToken) object;

    log.info("CSRF Token: " + token.getToken());

    filterChain.doFilter(servletRequest, servletResponse);
  }
}
```

/config/ProjectConfig.java
```java
import com.assu.study.chap1001.filter.CsrfTokenLogger;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.csrf.CsrfFilter;

@Configuration
public class ProjectConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .addFilterAfter(new CsrfTokenLogger(), CsrfFilter.class)
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll()); // 인증없이 모든 요청 접근 가능
    //.httpBasic(Customizer.withDefaults());  // HTTP Basic 인증 대신 정적키 필터를 사용하므로 호출하지 않음
    // .csrf(AbstractHttpConfigurer::disable)  // cstf 비활성화를 하지 않음
    return http.build();
  }
}
```

이제 엔드포인트를 호출하여 테스트해보자.

먼저 GET 엔드포인트를 호출한다.  
`CsrftokenRepository` 인터페이스의 기본 구현은 HTTP 세션을 이용하여 서버 쪽에 토큰값을 저장하므로 세션 ID 도 알아놔야 한다. 따라서 curl 에 `-v` 플래그를 붙여 응답에서 
세션 ID 도 확인한다.

```shell
$ curl -w "%{http_code}" -v http://localhost:8080/hello

< Set-Cookie: JSESSIONID=1B45BB088E4731216A271BA8BCAA0F3C; Path=/; HttpOnly
...
Get Hello!200%
```

콘솔에 찍힌 CSRF 토큰값도 확인한다.
```text
CSRF Token: AZH_iStaXLBoNolOBJY6FLuLEDpBI3yn-g_yxB7p9rvCC3tiMfCd6kpiaohFAOh9PLsOIoO-PVsjRR2Knj-R_SbfwIjwaE1Q
```

CSRF 토큰을 지정하지 않고 POST 엔드포인트를 호출하면 403 Forbidden 응답이 내려오는 것을 확인할 수 있다.

```shell
$ curl -w "%{http_code}" --request POST http://localhost:8080/hello
{"timestamp":"2024-02-17T09:35:26.623+00:00","status":403,"error":"Forbidden","path":"/hello"}403%
```

그럼 이제 CSRF 토큰값을 지정하여 POST 엔드포인트롤 호출한다.  
이 때 `CsrfTokenRepository` 의 기본 구현은 CSRF 토큰의 값을 세션에 저장하므로 세션 ID 도 지정해야 한다.

```shell
$ curl -w "%{http_code}" --request POST http://localhost:8080/hello \
--header 'Cookie: JSESSIONID=1B45BB088E4731216A271BA8BCAA0F3C' \
--header 'X-CSRF-TOKEN: AZH_iStaXLBoNolOBJY6FLuLEDpBI3yn-g_yxB7p9rvCC3tiMfCd6kpiaohFAOh9PLsOIoO-PVsjRR2Knj-R_SbfwIjwaE1Q'

Post Hello!200% 
```

> 위의 예시에서 토큰을 콘솔에 출력했다.  
> 클라이언트와 통신하는 경우, 클라이언트가 사용할 HTTP 응답에 CSRF 토큰값을 추가할 책임은 백엔드에 있다.

---

# 2. 실제 운영에서의 CSRF 보호 적용: 프론트엔드와 백엔드가 하나의 서버로 구성된 경우

**CSRF 는 실제 운영 시 아래와 같은 상황일 때 사용**되어야 한다.
- 브라우저에서 실행되는 웹 앱
- 앱의 표시된 콘텐츠를 로드하는 브라우저가 변경 작업을 수행할 수 있다고 예상될 때

기본 로그인의 경우 스프링 시큐리티는 CSRF 보호를 올바르게 적용해주고, 프레임워크가 CSRF 토큰을 로그인 요청에 추가하는 작업을 처리해준다.

이제 로그인이 있는 프로젝트를 구축하면서 웹 페이지 양식에 CSRF 토큰을 적용하는 방법에 대해 알아본다.

- 로그인 양식을 이용하여 웹 애플리케이션 구축
- 로그인의 기본 구현이 CSRF 토큰을 이용하는 방법 확인
- 메인 페이지에서 HTTP POST 호출 구현

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1002) 에 있습니다.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.2</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.assu.study</groupId>
    <artifactId>chap1001</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1001</name>
    <description>chap1001</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <scope>annotationProcessor</scope>
        </dependency>
    </dependencies>

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

이제 구성 클래스에 `UserDetailsService` 를 정의하여 사용자를 추가하고, 인증 방식을 `formLogin()` 메서드를 호출하여 양식 기반 로그인으로 설정해준다.

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  @Bean
  public UserDetailsService customUserDetailsService() {
    InMemoryUserDetailsManager uds = new InMemoryUserDetailsManager();

    UserDetails user = User.withUsername("assu")
        .password("1111")
        .roles("ADMIN")
        .build();

    uds.createUser(user);

    return uds;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .authorizeHttpRequests(authz -> authz.anyRequest().authenticated()) // 인증된 사용자만 엔드포인트에 접근 가능
        .formLogin(f -> f.defaultSuccessUrl("/main", true));  // 양식 기반 로그인 인증 방식을 사용하고, 인증 성공 시 /main 으로 이동

    return http.build();
  }
}
```

이제 _/main_ 으로 이동할 수 있도록 html 페이지와 GET 엔드포인트가 있는 컨트롤러를 만든다.

/resources/templates/main.html
```html
MAIN 임

// ...
```

/controller/MainController.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@Slf4j
public class MainController {
  @GetMapping("/main")
  public String main() {
    return "main.html";
  }

  // ...
}
```

애플리케이션 실행 후 localhost:8080 으로 접근 시 기본 로그인 페이지에 접근할 수 있다.  
_F12_ 로 개발자 도구를 연 후 폼 양식을 검사하면 로그인 양식의 기본 구현이 CSRF 토큰을 보내는 것을 확인할 수 있다. 
따라서 HTTP POST 요청을 해도 CSRF 보호가 적용된 로그인이 작동한다.

![hidden type 으로 보내지는 CSRF 토큰](/assets/img/dev/2023/1217/hidden_csrf.png)

로그인 통과 후 HTTP POST, PUT, DELETE 를 이용하는 엔드포인트를 호출하려면 CSRF 보호가 활성화 상태일 때 CSRF 토큰을 전송하는 작업을 추가해주어야 한다.

이 부분을 테스트하기 위해 POST 엔드포인트를 하나 만들고, 메인 페이지에서 이 엔드포인트를 호출하도록 해본다.

/controller/MainController.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@Slf4j
public class MainController {
  @GetMapping("/main")
  public String main() {
    return "main.html";
  }

  @PostMapping("/product/add")
  public String add(@RequestParam String name) {
    log.info("Adding: " + name);
    return "main.html";
  }
}
```

이제 main.html 에 POST 엔드포인트를 호출하는 양식을 넣는다.

/resources/templates/main.html
```html
<!DOCTYPE HTML>
<html lang="en" xmlns:th="http://www.thymeleaf.org">
<head>
</head>
<body>
<form action="/product/add" method="post">
    <span>Name:</span>
    <span><input name="name" type="text"/></span>
    <span><button type="submit">Add</button></span>
    <input th:name="${_csrf.parameterName}"
           th:value="${_csrf.token}"
           type="hidden"/>
</form>
</body>
</html>
```

이제 다시 애플리케이션을 실행 → 로그인 → 메인 페이지를 확인해보면 _csrf 로 토큰값이 들어가있는 것을 확인할 수 있다.

![hidden type 으로 보내지는 CSRF 토큰](/assets/img/dev/2023/1217/hidden_csrf_2.png)

add 버튼을 통해 POST 엔드포인트 호출 시 정상적으로 호출이 되는 것을 확인할 수 있다.

---

CSRF 토큰은 프론트엔드와 백엔드가 하나의 서버로 구성된 아키텍처에서는 잘 동작하지만 클라이언트와 백엔드가 독립적일때는 CSRF 토큰이 잘 동작하지 않는다.  
이런 종류의 설계에 관해서는 다른 방식으로 접근해야 한다.

> 프론트엔드와 백엔드가 분리된 구조에서의 CSRF 보호와 토큰을 적용하는 방법은 [Spring Security - BE, FE 분리된 설계의 애플리케이션 구현](https://assu10.github.io/dev/2024/01/13/springsecurity-second-app/) 을 참고하세요.

> OAuth 2 는 구성 요소를 분리하기에 매우 좋다. OAuth 2 를 이용하면 클라이언트에 권한을 부여하는 리소스에서 애플리케이션 인증을 진행한다.  
> 이에 대한 상세한 내용은   
> [Spring Security - OAuth 2(1): Grant 유형](https://assu10.github.io/dev/2024/01/14/springsecurity-oauth2-1/),
> [Spring Security - OAuth 2: 승인 코드 그랜트 유형을 이용한 간단한 SSO App 구현](https://assu10.github.io/dev/2024/01/20/springsecurity-oauth2-2/),
> [Spring Security - OAuth 2(2): 권한 부여 서버 구현](https://assu10.github.io/dev/2024/01/21/springsecurity-oauth2-auth-server/),
> [Spring Security - OAuth 2(3): JWT 와 암호화 서명](https://assu10.github.io/dev/2024/01/27/springsecurity-oauth2-jwt/)  
> 을 참고하세요.

> **절대 데이터를 변경하는 동작을 구현하고 HTTP GET 엔드포인트를 호출할 수 있도록 허용해서는 안된다.**  
> **HTTP GET 엔드포인트를 호출할 때는 CSRF 토큰이 필요하지 않다는 부분을 잊지 말자!!**

---

# 3. CSRF 보호 맞춤 구성: `CsrfToken`, `CsrfTokenRepository`

스프링 시큐리티가 제공하는 CSRF 보호를 맞춤 구성하는 방법에 대해 알아본다.

실제 운영 시 CSRF 보호를 맞춤 구성해야 하는 요구사항들은 아래와 같다.
- CSRF 가 적용되는 경로 설정 (특정 엔드포인트만 CSRF 보호 비활성화)
- CSRF 토큰 관리 (토큰을 HTTP 세션이 아닌 DB 로 관리)

**CSRF 보호는 서버에서 생성된 리소스를 이용하는 페이지가 같은 서버에서 생성된 경우에만 이용**한다.  
이 페이지는 [2. 실제 운영에서의 CSRF 보호 적용: 프론트엔드와 백엔드가 하나의 서버로 구성된 경우](#2-실제-운영에서의-csrf-보호-적용-프론트엔드와-백엔드가-하나의-서버로-구성된-경우) 에서 본 것처럼 엔드포인트가 다른 출처로 노출되는 웹 애플리케이션일 수도 있고, 모바일 애플리케이션일수도 있다.

> 모바일 애플리케이션의 경우 OAuth 2 흐름을 이용할 수 있는데 OAuth 2 에 대한 내용은  
> [Spring Security - OAuth 2(1): Grant 유형](https://assu10.github.io/dev/2024/01/14/springsecurity-oauth2-1/),
> [Spring Security - OAuth 2: 승인 코드 그랜트 유형을 이용한 간단한 SSO App 구현](https://assu10.github.io/dev/2024/01/20/springsecurity-oauth2-2/),
> [Spring Security - OAuth 2(2): 권한 부여 서버 구현](https://assu10.github.io/dev/2024/01/21/springsecurity-oauth2-auth-server/),
> [Spring Security - OAuth 2(3): JWT 와 암호화 서명](https://assu10.github.io/dev/2024/01/27/springsecurity-oauth2-jwt/)  
> 을 참고하세요.


---

## 3.1. 특정 엔드포인트만 CSRF 보호 비활성화

기본적으로 CSRF 보호는 GET, HEAD, TRACE, OPTIONS 를 제외한 HTTP 방식으로 호출되는 모든 엔드포인트 경로에 적용된다.

아래는 POST 엔드포인트 경로 중 일부 경로에만 CSRF 를 비활성화하는 예시이다.

요구사항은 아래와 같다.

- HTTP POST /hello, HTTP POST /world 2개의 엔드포인트가 있음
- POST /world 에만 CSRF 보호 비활성화 적용

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1003) 에 있습니다.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.2</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.assu.study</groupId>
    <artifactId>chap1003</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1003</name>
    <description>chap1003</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <scope>annotationProcessor</scope>
        </dependency>
    </dependencies>

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

/controller/HelloController.java
```java
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
  @GetMapping("/hello")
  public String hello() {
    return "get hello";
  }

  @PostMapping("/hello")
  public String hello2() {
    return "post hello";
  }

  @GetMapping("/world")
  public String world() {
    return "get world";
  }

  @PostMapping("/world")
  public String world2() {
    return "post world";
  }
}
```

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(c -> c.ignoringRequestMatchers("/world")) // /world 경로는 CSRF 보호 제회
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll());  // 그 외의 경로는 인증없이 모두 허용

    return http.build();
  }
}
```

이제 인증없이 GET /hello, POST /hello, POST /world 를 호출하면 GET /hello 는 정상 응답, POST /hello 는 403 Forbidden, POST /world 는 정상 응답하는 것을 확인할 수 있다.

```shell
curl -w "%{http_code}"  http://localhost:8080/hello
get hello200%

$ curl -w "%{http_code}"  http://localhost:8080/world
get world200%

$ curl -w "%{http_code}" --request POST http://localhost:8080/hello
{"timestamp":"2024-02-17T13:14:30.667+00:00","status":403,"error":"Forbidden","path":"/hello"}403%

# POST /world 는 csrf 에서 제외했으므로 정상 응답
$ curl -w "%{http_code}" --request POST http://localhost:8080/world
post world200%
```

---

## 3.2. CSRF 토큰 관리를 HTTP 세션 관리에서 DB 관리로 맞춤 구성: `CsrfToken`, `CsrfTokenRepository`

> Spring Security 6.X 는 기본적으로 BREACH 공격으로부터 보호하도록 설계되었기 되었고, 이는 CSRF 토큰이 HTML 양식 요청으로 인코딩될 것으로 예상하기 때문에 
> CSRF 토큰이 요청 헤더를 통해 전송되는 REST-API 에는 적합하지 않음  
> 
> The root of the issue stems from a lack of knowledge of the default CSRF configuration in Spring Security 6.x. Specifically,  
> the default implementation uses , which is designed to protect against BREACH attacks.  
> This handler expects CSRF tokens to be encoded in HTML form requests,  
> making it unsuitable for typical REST API use-cases where CSRF tokens are sent via request headers.
> 
> [Solving the "Invalid CSRF token found" Error in Spring Security 6.x](https://www.linkedin.com/pulse/solving-invalid-csrf-token-found-error-spring-security-oyeleye)  
> 
> 따라서 아래 내용은 참고만 하자.

애플리케이션에서 **CSRF 토큰 관리 방식을 맞춤 구성**해야 하는 경우도 많다.

기본적으로 애플리케이션은 서버 쪽의 HTTP 세션에 CSRF 토큰을 저장하는데, scale-out 이 필요한 애플리케이션에는 적합하지 않다. 
HTTP 세션은 상태 저장형이며, 애플리케이션의 확장성을 떨어뜨린다.

따라서 이제 **애플리케이션이 HTTP 세션이 아닌 DB 로 토큰을 관리**하도록 해본다.

스프링 시큐리티는 이를 위해 2가지 계약을 제공한다.
- `CsrfToken`
  - CSRF 토큰 자체를 기술함
- `CsrfTokenRepository`
  - CSRF 토큰을 생성/저장/로드하는 객체를 기술함

**`CsrfToken` 객체에는 계약을 구현할 때 지정해야 하는 3가지가** 있다.
- 요청에서 CSRF 토큰값을 포함하는 헤더의 이름 (기본값은 X-CSRF-TOKEN)
- 토큰값을 저장하는 요청의 특성 이름 (기본값은 _csrf)
- 토큰값

`CsrfToken` 인터페이스
```java
package org.springframework.security.web.csrf;

import java.io.Serializable;

public interface CsrfToken extends Serializable {
  String getHeaderName();
  String getParameterName();
  String getToken();
}
```

**스프링 시큐리티는 `DefaultCsrfToken` 구현을 제공하는데, `DefaultCsrfToken` 은 `CsrfToken` 계약을 구현하고, 위의 필요한 3가지 값을 포함하는 불변 인스턴스**를 만든다.

**`CsrfTokenRepository` 인터페이스는 CSRF 토큰을 관리하는 구성 요소를 나타내는 계약**이다.

애플리케이션의 토큰 관리 방법을 변경하려면 `CsrfTokenRepository` 인터페이스를 구현한 후 이 맞춤형 구현을 프레임워크에 연결해주면 된다.

이제 `CsrfTokenRepository` 의 구현을 추가해본다.

![맞춤형 CsrfTokenRepository](/assets/img/dev/2023/1217/csrf_token_repository.png)

여기서 해 볼 토큰 관리 전략은 아래와 같다.
- DB 테이블에 CSRF 토큰을 저장하고, 클라이언트에서 토큰을 식별하기 위한 ID 가 있다고 가정함
- 백엔드가 CSRF 토큰을 얻은 후 검증하려면 이 ID 가 필요함
- 이 고유 ID 는 로그인할 때마다 달라져야 하며, 로그인 중에 얻을 수 있음

위의 토큰 전략은 토큰을 메모리에 저장하는 것과 비슷하며, 단순히 고유 ID 가 세션 ID 의 역할을 대체한다.

대안으로 수명이 정의된 CSRF 토큰을 이용할 수 있다. 토큰을 특정 사용자 ID 에 연결하지 않고 DB 에 저장한 후 요청 여부 결정 시에 제공된 토큰의 존재 여부와 만료여부를 확인하면 된다. 

아래 종속성을 출가로 넣는다.

```xml
<!-- Spring Data JPA, Hibernate, aop, jdbc -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<!-- mysql 관련 jdbc 드라이버와 클래스들 -->
<!-- https://mvnrepository.com/artifact/com.mysql/mysql-connector-j -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <version>8.0.33</version>
</dependency>
```

application.properties
```properties
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.url=jdbc:mysql://localhost:13306/security?serverTimezone=UTC
spring.datasource.username=root
spring.datasource.password=
spring.jpa.show-sql=true
#spring.jpa.defer-datasource-initialization=true
```

```sql
CREATE TABLE IF NOT EXISTS `security`.`token` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(45) NULL COMMENT '클라이언트 식별자',
    `token` TEXT NULL,
PRIMARY KEY (`id`));
```

/entity/Token.java
```java
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class Token {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Integer id;

  private String identifier;

  private String token;
}
```

/repository/JpaTokenRepository.java
```java
import com.assu.study.chap1003.entity.Token;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface JpaTokenRepository extends JpaRepository<Token, Integer> {
  Optional<Token> findByIdentifier(String identifier);
}
```

이제 `CsrfTokenRepository` 인터페이스를 구현한다.

CSRF 보호 메커니즘은 아래와 같다.
- `generateToken()`
  - 애플리케이션이 새 토큰을 생성해야 할 때 호출
- `saveToken()`
  - 특정 클라이언트를 위해 생성된 토큰을 저장
- `loadToken()`
  - 토큰의 세부 정보 조회

CSRF 보호의 기본 구현에서 애플리케이션은 CSRF 토큰을 식별하기 위해 HTTP 세션을 이용하는데, 지금은 클라이언트 고유의 식별자 (_X_IDENTIFIER_) 가 있다고 가정하고, 
클라이언트는 이 고유 ID 값을 헤더에 실어보낸다.  
만일 해당 식별자로 이미 저장된 값이 있으면 새로운 토큰값으로 업데이트하고, 저장된 값이 없으면 CSRF 토큰값을 이용하여 새로운 데이터를 추가한다.

/csrf/CustomCsrfTokenRepository.java
```java
import com.assu.study.chap1003.entity.Token;
import com.assu.study.chap1003.repository.JpaTokenRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.security.web.csrf.CsrfTokenRepository;
import org.springframework.security.web.csrf.DefaultCsrfToken;

import java.util.Optional;
import java.util.UUID;

/**
 * CsrfTokenRepository 구현
 */
@Slf4j
@RequiredArgsConstructor
public class CustomCsrfTokenRepository implements CsrfTokenRepository {

  private final JpaTokenRepository jpaTokenRepository;

  /**
   * CSRF 토큰 생성
   */
  @Override
  public CsrfToken generateToken(HttpServletRequest request) {
    String uuid = UUID.randomUUID().toString();
    return new DefaultCsrfToken("X-CSRF-TOKEN", "_csrf", uuid);
  }

  /**
   * CSRF 토큰을 DB 에 저장
   */
  @Override
  public void saveToken(CsrfToken csrfToken, HttpServletRequest request, HttpServletResponse response) {
    String identifier = request.getHeader("X-IDENTIFIER");
    Optional<Token> existingToken = jpaTokenRepository.findByIdentifier(identifier);

    log.info("existingToken: " + existingToken);

    // 해당 클라이언트 식별자로 토큰이 이미 저장되어 있으면 새로 받은 토큰으로 저장함
    if (existingToken.isPresent()) {
      Token token = existingToken.get();
      token.setToken(csrfToken.getToken());
    } else {
      // 해당 클라이언트 식별자로 토큰이 없을 경우 신규로 저장
      Token token = new Token();
      token.setToken(csrfToken.getToken());
      token.setIdentifier(identifier);
      jpaTokenRepository.save(token);
    }
  }

  /**
   * CSRF 토큰 조회
   */
  @Override
  public CsrfToken loadToken(HttpServletRequest request) {
    String identifier = request.getHeader("X-IDENTIFIER");
    Optional<Token> existingToken = jpaTokenRepository.findByIdentifier(identifier);

    // 해당 클라이언트 식별자로 저장된 토큰이 있을 경우 토큰을 조회하여 DefaultCsrfToken 형태로 토큰 리턴
    if (existingToken.isPresent()) {
      Token token = existingToken.get();
      return new DefaultCsrfToken("X-CSRF-TOKEN", "_csrf", token.getToken());
    }

    return null;
  }
}
```

이제 위에서 만든 `CsrfTokenRepository` 인터페이스의 구현체를 구성 클래스에 등록하여 CSRF 보호 메커니즘에 연결한다.

/config/ProjectConfig.java
```java
import com.assu.study.chap1003.csrf.CustomCsrfTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.csrf.CsrfTokenRepository;

@Configuration
@RequiredArgsConstructor
@Slf4j
public class ProjectConfig {

  // CsrfTokenRepository 를 컨텍스트 빈으로 정의
  @Bean
  public CsrfTokenRepository customTokenRepository() {
    return new CustomCsrfTokenRepository();
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    //XorCsrfTokenRequestAttributeHandler requestHandler = new XorCsrfTokenRequestAttributeHandler();
    // POST /world 는 CSRF 보호 제외
    http
        .csrf(c -> {
          c.csrfTokenRepository(customTokenRepository()); // 맞춤 구성한 CsrfTokenRepository 연결
          c.ignoringRequestMatchers("/world");  // /world 경로는 CSRF 보호 제외
        })
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll());  // 그 외의 경로는 인증없이 모두 허용


    return http.build();
  }
}
```

> Spring Security 6 으로 되면서 CSRF 에 대해 변경사항이 있다.  
> 
>   - 더 이상 모든 요청에 대해 세션을 로드할 필요가 없으므로 성능 향상을 위해 CsrfToken의 로드가 기본적으로 지연됩니다.   
>   - 이제 CsrfToken은 BREACH 공격으로부터 CSRF 토큰을 보호하기 위해 기본적으로 모든 요청에 임의성을 포함합니다.  
> 
> When migrating from Spring Security 5 to 6, there are a few changes that may impact your application. The following is an overview of the aspects of CSRF protection that have changed in Spring Security 6:    
>   - Loading of the `CsrfToken` is now deferred by default to improve performance by no longer requiring the session to be loaded on every request.  
>   - The `CsrfToken` now includes randomness on every request by default to protect the CSRF token from a BREACH attack.  
> 
> [Migrating to Spring Security 6](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html#migrating-to-spring-security-6)
> 
> 따라서 브라우저를 통해 실행하면 정상 실행되지만, IDE Test 혹은 curl 로 진행하면 403 Forbidden 오류가 발생한다.

위와 같은 이유로 curl 로 확인 불가...

---

# 마치며...

- CSRF 는 사용자를 속여 위조 스크립트가 포함된 페이지에 접근하도록 하는 공격 유형임
- 이 스크립트는 애플리케이션에 로그인한 사용자를 가장하여 사용자 대신 작업 실행이 가능
- CSRF 보호는 스프링 시큐리티에서 기본적으로 활성화됨
- 스프링 시큐리티에서 CSRF 보호의 진입점은 HTTP 필터임

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Cross Site Request Forgery (CSRF)](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [How to override csrf generation in spring security with spring boot 3?](https://stackoverflow.com/questions/76024935/how-to-override-csrf-generation-in-spring-security-with-spring-boot-3)
* [인증 시 토큰값 저장 구현](https://www.inflearn.com/questions/742088/csrftokenrepo-%EA%B4%80%EB%A0%A8-%EC%A7%88%EB%AC%B8%EC%9E%85%EB%8B%88%EB%8B%A4)
* [Controller test 403 Forbidden 에러(feat. csrf)](https://velog.io/@shwncho/Spring-security-6-Controller-test-403-Forbidden-%EC%97%90%EB%9F%ACfeat.-csrf)
* [CSRF 로 인해서, 403에러가 발생했을 때](https://kang-james.tistory.com/entry/%EB%B3%B4%EC%95%88%EC%9D%B8%EC%A6%9D-CSRF-%EB%A1%9C-%EC%9D%B8%ED%95%B4%EC%84%9C-403%EC%97%90%EB%9F%AC%EA%B0%80-%EB%B0%9C%EC%83%9D%ED%96%88%EC%9D%84-%EB%95%8C)
* [Solving the "Invalid CSRF token found" Error in Spring Security 6.x](https://www.linkedin.com/pulse/solving-invalid-csrf-token-found-error-spring-security-oyeleye)