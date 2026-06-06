---
layout: post
title:  "Spring Security - 권한 부여(2): 경로, HTTP Method 에 따른 엑세스 제한"
date: 2023-12-09
categories: dev
tags: spring-security
---

이 포스트에서는 HTTP 요청 인증 후 수행되는 프로세스인 권한 부여 구성 시 권한 부여 규칙을 적용할 엔드포인트를 선택하는 방법에 대해 알아본다.

- 선택기 메서드로 요청 제한
- 각 선택기 메서드에 맞는 시나리오

---

**목차**

<!-- TOC -->
* [1. 선택기 (`matcher`) 메서드로 엔드포인트 선택](#1-선택기-matcher-메서드로-엔드포인트-선택)
* [2. MVC 선택기로 권한을 부여할 요청 선택](#2-mvc-선택기로-권한을-부여할-요청-선택)
  * [2.1. 특정 엔드포인트에 접근 제한 적용](#21-특정-엔드포인트에-접근-제한-적용)
  * [2.2. HTTP Method 에 따라 접근 제한 적용](#22-http-method-에-따라-접근-제한-적용)
  * [2.3. 정규식으로 접근 제한 적용](#23-정규식으로-접근-제한-적용)
* [3. 정규식 선택기로 권한을 부여할 요청 선택](#3-정규식-선택기로-권한을-부여할-요청-선택)
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

[Spring Security - 권한 부여(1): 권한과 역할에 따른 액세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-1/) 에서는 권한과 
역할을 기준으로 접근을 구성하였는데, 그 구성을 모든 엔드포인트에 적용하였다.

이번엔 엔드포인트에 따라 접근을 제한하는 방법에 대해 알아본다.

권한 부여 구성을 적용할 요청을 선택할 때는 선택기 메서드를 사용한다.  
스프링 시큐리티에서는 3가지 유형의 선택기 메서드를 제공한다.

- **MVC 선택기**
  - 경로에 MVC 식을 이용하여 엔드포인트 선택
- **앤트 선택기**
  - 경로에 앤트 식을 이용하여 엔드포인트 선택
- **정규식 선택기**
  - 경로에 정규식을 이용하여 엔드포인트 선택

---

# 1. 선택기 (`matcher`) 메서드로 엔드포인트 선택

MVC/앤트/정규식 선택기를 이해할 수 있기 선택기 메서드를 사용하는 법에 대해 알아본다.

아래는 /hello, /bye, /see 이렇게 3개의 엔드포인트가 있고 각 접근 제한은 아래와 같다.
- /hello 는 ADMIN 만 접근 가능
- /bye 는 MANAGER 만 접근 가능
- 그 외의 엔드포인트는 접근 제한 없음

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0801) 에 있습니다.

/controller/HelloController.java
```java
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
  // ADMIN 만 접근 가능
  @GetMapping("/hello")
  public String hello() {
    return "Hello!";
  }

  // MANAGER 만 접근 가능
  @GetMapping("/bye")
  public String bye() {
    return "Bye!";
  }

  // 별도의 접근 제한 없음
  @GetMapping("/see")
  public String see() {
    return "See!";
  }
}
```

이제 구성 클래스에 `InMemoryUserDetailsManager` 를 `UserDetailsService` 인스턴스로 등록하고, 다른 역할을 가진 두 사용자를 추가한다.  
요청에 권한을 부여할 때는 ADMIN 역할이 있는 사용자만 /hello 엔드포인트를 호출할 수 있도록 `requestMatchers()` 를 이용한다.

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
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
  @Bean   // 이 메서드가 반환하는 UserDetailsService 가 스프링 컨텍스트에 추가됨
  public UserDetailsService userDetailsService() {
    InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();

    // UserDetailsService 가 관리하도록 사용자 추가
    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .roles("ADMIN")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("2222")
        .roles("MANAGER")
        .build();

    manager.createUser(user1);
    manager.createUser(user2);

    return manager;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야 함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(authz -> {
          authz.requestMatchers("/hello").hasRole("ADMIN"); // /hello 는 ADMIN 역할만 접근 가능
          authz.requestMatchers("/bye").hasRole("MANAGER"); // /bye 는 MANAGER 역할만 접근 가능
          authz.anyRequest().permitAll(); // 그 외의 엔드포인트는 인증없이 접근 가능
          //authz.anyRequest().authenticated(); // 그 외의 엔드포인트는 인증만 성공하면 접근 가능
          //authz.anyRequest().denyAll(); // 그 외의 엔드포인트는 접근 불가
        })
        .httpBasic(Customizer.withDefaults());

    return http.build();
  }
}
```

> `HttpSecurity.authorizeHttpRequests()` 안에 들어갈 수 있는 람다 함수는 org.springframework.security.config.annotation.web.AbstractRequestMatcherRegistry 클래스 참고

이제 각 호출의 결과는 아래와 같다.
```shell
# 인증없이 /hello 호출 시 401 Unauthorized 
$ curl -w "%{http_code}"  http://localhost:8080/hello
401%

# ADMIN 인 assu 가 /hello 호출 시 정상 응답
$ curl -w "%{http_code}" -u assu:1111  http://localhost:8080/hello
Hello!200%

# MANAGER 인 silby 가 /hello 호출 시 403 Forbidden
$ curl -w "%{http_code}" -u silby:2222  http://localhost:8080/hello
403%

# 인증없이 /see 호출 시 정상 응답
$ curl -w "%{http_code}"   http://localhost:8080/see
See!200%
```

---

# 2. MVC 선택기로 권한을 부여할 요청 선택

권한 부여 구성을 적용할 요청을 지정할 때 가장 일반적으로 많이 사용하는 방식이 경로에 **MVC 식** 을 이용하는 것이다.

이제 HTTP Method 에 따라 접근 권한을 부여해본다.

스프링 시큐리티는 기본적으로 CSRF (사이트 간 요청 위조) 에 대한 보호를 적용한다.

> 스프링 시큐리티가 CSRF 토큰 탈취로 인한 CSRF 취약성을 완화하는 법은 [Spring Security - CSRF (Cross-Site Request Forgery, 사이트 간 요청 위조)](https://assu10.github.io/dev/2023/12/17/springsecurity-csrf/) 를 참고하세요.

일단 지금은 권한 부여를 이해하는 것이 목적이니 PUT, POST 등 모든 엔드포인트를 호출할 수 있게 CSRF 보호를 비활성화한다.

---

## 2.1. 특정 엔드포인트에 접근 제한 적용

테스트를 위한 엔드포인트는 아래와 같다.

- GET /aa
- POST /aa
- GET /aa/bb
- GET /aa/bb/cc

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0802) 에 있습니다.

/controller/HelloController.java
```java
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
  @GetMapping("/aa")
  public String hello() {
    return "get aa";
  }

  @PostMapping("/aa")
  public String bye() {
    return "post aa";
  }

  @GetMapping("/aa/bb")
  public String see() {
    return "get aa/bb";
  }

  @GetMapping("/aa/bb/cc")
  public String see2() {
    return "get aa/bb/cc";
  }
}
```

아래 조건에 맞게 접근 제한을 구성해본다.

- GET /a: 사용자 인증 필요
- POST /a: 인증 필요 없이 모두 접근 허용
- 그 외 나머지는 모두 요청 거부

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  @Bean   // 이 메서드가 반환하는 UserDetailsService 가 스프링 컨텍스트에 추가됨
  public UserDetailsService userDetailsService() {
    InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();

    // UserDetailsService 가 관리하도록 사용자 추가
    UserDetails user1 = User.withUsername("assu")
            .password("1111")
            .roles("ADMIN")
            .build();

    UserDetails user2 = User.withUsername("silby")
            .password("2222")
            .roles("MANAGER")
            .build();

    manager.createUser(user1);
    manager.createUser(user2);

    return manager;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야 함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
            .csrf(AbstractHttpConfigurer::disable)  // cstf 비활성화
            .authorizeHttpRequests(authz -> {
              authz.requestMatchers(HttpMethod.GET, "/aa").authenticated(); // GET /aa 인증 필요
              authz.requestMatchers(HttpMethod.POST, "/aa").permitAll(); // POST /aa 는 인증 필요 없이 모두 접근 허용
              authz.anyRequest().denyAll(); // 그 외의 엔드포인트는 모두 요청 거부
            })
            .httpBasic(Customizer.withDefaults());
//    http.authorizeHttpRequests(authz -> {
//          authz.requestMatchers("/hello").hasRole("ADMIN"); // /hello 는 ADMIN 역할만 접근 가능
//          authz.requestMatchers("/bye").hasRole("MANAGER"); // /bye 는 MANAGER 역할만 접근 가능
//          authz.anyRequest().permitAll(); // 그 외의 엔드포인트는 인증없이 접근 가능
//          //authz.anyRequest().authenticated(); // 그 외의 엔드포인트는 인증만 성공하면 접근 가능
//          //authz.anyRequest().denyAll(); // 그 외의 엔드포인트는 접근 불가
//        })
//        .httpBasic(Customizer.withDefaults());

    return http.build();
  }
}

```

이제 curl 로 확인해보자.

```shell
# 인증없이 GET /aa 호출 시 401 Unauthorized 
$ curl -w "%{http_code}"  http://localhost:8080/aa
401%

# 인증 후 GET /aa 호출 시 정상 응답
$ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/aa
get aa200%

# 인증없이 POST /aa 호출 시 정상 응답
$ curl --request POST 'http://localhost:8080/aa'
post aa%

# 인증 후 GET /aa/bb 호출 시 403 Forbidden
$ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/aa/bb
403%
```

---

## 2.2. HTTP Method 에 따라 접근 제한 적용

이제 여러 경로에 같은 권한 부여 규칙을 적용해보자.

엔드포인드들  
- GET /aa
- POST /aa
- GET /aa/bb
- GET /aa/bb/cc

아래 조건에 맞게 접근 제한을 구성해본다.

- /aa/bb 로 시작하는 모든 경로: 사용자 인증 필요
  - GET /aa/bb, GET /aa/bb/cc 해당
- 그 외 나머지는 모두 인증없이 접근 가능
  - GET /aa, POST /aa 해당

이럴 때는 `**` 연산자를 사용한다.  
`**` 연산자는 제한없이 경로 이름을 나타내내고, `*` 연산자는 하나의 경로만 나타낸다.

예를 들어 _/aa/*/cc_ 로 표현하면 _/aa/bb/cc_ 는 해당하지만, _/aa/bb/bb/cc_ 는 해당하지 않는다.

/config/ProjectConfig.java
```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
  http
      .csrf(AbstractHttpConfigurer::disable)  // cstf 비활성화
      .authorizeHttpRequests(authz -> {
        authz.requestMatchers("/aa/bb/**").authenticated(); // /aa/bb 로 시작하는 모든 경로는 인증 필요
        authz.anyRequest().permitAll(); // 그 외의 엔드포인트는 모두 인증 필요 없이 접근 가능
      })
      .httpBasic(Customizer.withDefaults());
  return http.build();
}
```

인증을 하지 않고 모든 엔드포인트 호출
```shell
# 정상 응답
$ curl -w "%{http_code}"  http://localhost:8080/aa
get aa200%

# 정상 응답
$ curl -w "%{http_code}" --request POST  http://localhost:8080/aa
post aa200%

# 401 Unauthorized
$ curl -w "%{http_code}"  http://localhost:8080/aa/bb
{"timestamp":"2024-02-16T10:38:47.975+00:00","status":401,"error":"Unauthorized","path":"/aa/bb"}401

# 401 Unauthorized
$ curl -w "%{http_code}"  http://localhost:8080/aa/bb/cc
{"timestamp":"2024-02-16T10:38:54.646+00:00","status":401,"error":"Unauthorized","path":"/aa/bb/cc"}401%
```

인증을 하고 모든 엔드포인트 호출
```shell
# 정상 응답
$ curl -w "%{http_code}" -u assu:1111  http://localhost:8080/aa
get aa200%

# 정상 응답
  ~  curl -w "%{http_code}" --request POST -u assu:1111  http://localhost:8080/aa
post aa200%
```

---

## 2.3. 정규식으로 접근 제한 적용

경로 변수를 활용한 엔드포인트에서 숫자 이외의 다른 값을 포함한 경로 변수가 들어올 경우는 요청을 제한해보자.

```java
@GetMapping("product/{code}")
public String see5(@PathVariable String code) {
  return code;
}
```

```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
  http
      .csrf(AbstractHttpConfigurer::disable)  // cstf 비활성화
      .authorizeHttpRequests(authz -> {
        authz.requestMatchers("/product/{code:^[0-9]*$}").permitAll(); // 숫자로 구성된 엔드포인트는 모두 요청 허용
        authz.anyRequest().denyAll(); // 그 외의 엔드포인트는 모두 요청 거부
      })
      .httpBasic(Customizer.withDefaults());
  return http.build();
}
```

```shell
# 401 Unauthorized
$ curl -w "%{http_code}" http://localhost:8080/aa/bb/cc
401%

# /product/숫자 형태이므로 접근 가능
$ curl -w "%{http_code}" http://localhost:8080/product/121
121200%

# 문자가 들어갔으므로 401 Unauthorized
$ curl -w "%{http_code}" http://localhost:8080/product/121d
401%
```

- _/aa/{param}_
  - param 경로 매개변수를 포함한 /a 경로에 적용
- _/aa/{param:regex}_
  - 매개 변수와 정규식이 일치할 때만 주어진 경로 매개 변수를 포함한 /a 경로에 적용

> 앤트 선택기도 있는데 앤트 선택기보다 MVC 선택기를 사용하는 것이 좋으므로 앤트 선택기는 따로 다루지 않음

---

# 3. 정규식 선택기로 권한을 부여할 요청 선택

하나의 경로 변수를 이용하는 조건이라면 [2.3. 정규식으로 접근 제한 적용](#23-정규식으로-접근-제한-적용) 에서 본 것처럼 MVC 선택기를 이용하여 
바로 정규식을 사용할 수 있다.

하지만 **두 개 이상의 경로 변수를 이용한다거나, 경로에 특정 기호가 들어가면 요청을 거부하는 등의 좀 더 복잡한 경우는 정규식 선택기를 사용**할 수 밖에 없다.  

> 정규식의 경우 가독성이 어렵다는 단점이 있으니 MVC 선택기를 우선적으로 적용하고, 다른 대안이 없을때만 정규식 선택기를 사용하는 것을 권장함

아래는 /user/{국가}/{언어} 형태의 엔드포인트를 갖고 있으며, 아래의 조건대로 요청을 제한하는 예시이다.
- 국가가 미국/영국/캐나다 이면서 영어를 사용하는 인증된 유저만 해당 엔드포인트에 접근 가능
- 만일 "SUPER" 권한이 있으면 위의 조건없이 해당 엔드포인트에 접근 가능

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0803) 에 있습니다.

```java
@RestController
public class HelloController {
  @GetMapping("user/{country}/{lang}")
  public String test(@PathVariable String country, @PathVariable String lang) {
    return "Country: " + country + ", lang: " + lang;
  }
}
```

/config/ProjectConfig.java
```java
package com.assu.study.chap0803.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.util.matcher.RegexRequestMatcher;

@Configuration
public class ProjectConfig {
  @Bean   // 이 메서드가 반환하는 UserDetailsService 가 스프링 컨텍스트에 추가됨
  public UserDetailsService userDetailsService() {
    InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();

    // UserDetailsService 가 관리하도록 사용자 추가
    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .roles("NORMAL")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("2222")
        .roles("NORMAL", "SUPER")
        .build();

    manager.createUser(user1);
    manager.createUser(user2);

    return manager;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야 함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

    http
        .authorizeHttpRequests(authz -> {
          authz.requestMatchers(RegexRequestMatcher.regexMatcher(".*/(us|uk|ca)+/(en|fr).*")).authenticated();  // 미국,영국,캐나다이면서 영어권인 경우 인증 후 접근 가능
          authz.anyRequest().hasRole("SUPER"); // 그 외 엔드포인트는 SUPER 권한이 있으면 모두 다 접근 가능
        })
        .httpBasic(Customizer.withDefaults());
    return http.build();
  }
}
```

인증없이 호출 시 모두 401 Unauthorized
```shell
$ curl -w "%{http_code}" http://localhost:8080/user/ko/kr
401%

$ curl -w "%{http_code}" http://localhost:8080/user/us/kr
401%

$ curl -w "%{http_code}" http://localhost:8080/user/us/en
```

NORMAL 역할이 있는 assu 로 인증 시 /user/us/en 은 접근 가능하지만 그 외엔 403 Forbidden
```shell
$ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/user/ko/kr
403%

$ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/user/us/kr
403%

$ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/user/us/en
Country: us, lang: en200%
```

SUPER 권한이 있는 silby 로 인증 시 모두 접근 가능
```shell
$ curl -w "%{http_code}" -u silby:2222 http://localhost:8080/user/ko/kr
Country: ko, lang: kr200%

$  curl -w "%{http_code}" -u silby:2222 http://localhost:8080/user/us/kr
Country: us, lang: kr200%

$  curl -w "%{http_code}" -u silby:2222 http://localhost:8080/user/us/en
Country: us, lang: en200%
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)