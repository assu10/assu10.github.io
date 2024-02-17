---
layout: post
title:  "Spring Security - 권한 부여(1): 권한과 역할에 따른 액세스 제한"
date:   2023-12-09
categories: dev
tags: spring-security permit-all deny-all role authority
---

이 포스트에서는 HTTP 요청 인증 후 수행되는 프로세스인 권한 부여 구성에 대해 알아본다.

- 권한에 대해 알아본 후 사용자 권한에 따라 모든 엔드포인트에 엑세스 규칙 적용
- 권한을 역할로 그룹화
- 사용자 역할에 따라 권한 부여 규칙을 적용

---

**목차**

<!-- TOC -->
* [1. 권한과 역할에 따라 접근 제한](#1-권한과-역할에-따라-접근-제한)
  * [1.1. 사용자 '권한'을 기준으로 모든 엔드포인트에 접근 제한](#11-사용자-권한을-기준으로-모든-엔드포인트에-접근-제한)
  * [1.2. 사용자 '역할'을 기준으로 모든 엔드포인트에 접근 제한](#12-사용자-역할을-기준으로-모든-엔드포인트에-접근-제한)
  * [1.3. 모든 엔드포인트에 대한 접근 제한: `denyAll()`](#13-모든-엔드포인트에-대한-접근-제한-denyall)
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

**권한 부여 (Authorization) 는 식별된 클라이언트가 요청된 리소스에 액세스할 권한이 있는지 결정하는 프로세스**이다.

![권한 부여 흐름](/assets/img/dev/2023/1209/authorization.png)

권한 부여의 흐름은 아래와 같다.
- `AuthenticationFilter` 가 사용자를 인증함
- 인증이 완료되면 `AuthenticationFiler` 가 사용자 세부 정보를 `SecurityContext` 에 저장하고, 요청을 `AuthorizationFilter` 에게 위임함
- `AuthorizationFilter` 는 `SecurityContext` 로부터 사용자 정보를 조회한 후 요청에 권한을 부여/거부에 대해 결정함

---

# 1. 권한과 역할에 따라 접근 제한

권한과 역할은 애플리케이션의 모든 엔드포인트를 보호하는데 이용된다.

[1. 스프링 시큐리티 인증 구현](https://assu10.github.io/dev/2023/11/18/springsecurity-user-management/#1-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EC%9D%B8%EC%A6%9D-%EA%B5%AC%ED%98%84) 에 
잠깐 봤던 것처럼 스프링 시큐리티는 `GrantedAuthority` 계약으로 권한을 나타낸다.

![사용자 관리를 수행하는 구성 요소 간 종속성](/assets/img/dev/2023/1118/user_manage.png)

- 사용자는 하나 이상의 권한을 갖음
- 인증 프로세스 도중 `UserDetailsService` 는 사용자의 권한을 포함한 모든 세부 정보를 얻음
- 애플리케이션은 사용자를 성공적으로 인증한 후 `GrantedAuthority` 인터페이스로 나타내는 권한으로 권한 부여 수행

`GrantedAuthority` 인터페이스
```java
package org.springframework.security.core;

import java.io.Serializable;

public interface GrantedAuthority extends Serializable {
  String getAuthority();
}
```

`UserDetails` 인터페이스 일부
```java
public interface UserDetails extends Serializable {
  Collection<? extends GrantedAuthority> getAuthorities();
  
  // ...
}
```

사용자를 나타내는 `UserDetails` 는 `GrantedAuthority` 인스턴스의 컬렉션을 갖는다.  
사용자에게 허가된 모든 권한을 반환하도록 `getAuthorities()` 를 구현해야 한다.  
인증이 완료되면 사용자의 세부 정보에 권한이 포함되며, 애플리케이션은 이를 바탕으로 권한 부여를 한다.

---

## 1.1. 사용자 '권한'을 기준으로 모든 엔드포인트에 접근 제한

> 실제 운영 시엔 권한 보다는 역할로 제어를 하므로 아래 내용은 참고만 하자.

권한을 기반으로 엔드포인트에 대한 액세스는 3가지 방법으로 구성할 수 있다.

- `hasAuthority()`
  - 제한을 구성하는 하나의 권한만 매개변수로 받음
  - 해당 권한이 있는 사용자만 엔드포인트 호출 가능
- `hadAnyAuthority()`
  - 제한을 구성하는 권한을 하나 이상 받음
  - 해당 권한들 중 하나라도 있으면 엔드포인트 호출 가능
- `access()`
  - SpEL (Spring Expression Language) 를 기반으로 권한 부여 규칙을 구축하기 때문에 액세스를 구성하는 무한한 가능성이 있음
  - 하지만 코드 가독성 및 디버그가 어려워 추천하지 않음
  - 위의 2가지 메서드를 적용할 수 없을 때만 이용하는 것이 좋음  
  예) 낮 12~1시까지만 요청 허용 등..

이제 구성 클래스에 `InMemoryUserDetailsManager` 를 `UserDetailsService` 로 등록하고, 이 인스턴스에서 관리할 사용자를 2명 등록해본다.  
그리고 권한 부여 구성을 추가한다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0701) 에 있습니다.

/config/ProjectConfig.java
```java
package com.assu.study.chap0701.config;

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
  @Bean // 이 메서드가 반환하는 UserDetailsService 가 스프링 컨텍스트에 추가됨
  public UserDetailsService userDetailsService() {
    InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();

    // UserDetailsService 에서 관리하도록 사용자 추가
    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .authorities("READ")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("2222")
        .authorities("WRITE")
        .build();

    manager.createUser(user1);
    manager.createUser(user2);

    return manager;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }

  // HTTP Basic 방식을 명시적으로 설정
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

//    http.authorizeHttpRequests(authz ->
//            authz.anyRequest()  // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
//                .authenticated()) // 인증된 유저만 접근 허용
//        .httpBasic(Customizer.withDefaults());

    http.authorizeHttpRequests(authz ->
            authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
                .hasAuthority("WRITE"))   // WRITE 권한이 있는 유저만 접근 허용
        .httpBasic(Customizer.withDefaults());


//    http.authorizeHttpRequests(authz ->
//            authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
//                .hasAnyAuthority("WRITE", "READ"))   // WRITE, READ 권한 중 하나라도 있는 유저만 접근 허용
//        .httpBasic(Customizer.withDefaults());

//    http.authorizeHttpRequests(authz ->
//            authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
//            .permitAll())   // 인증 여부과 관계없이 모든 요청에 인증 없이 요청 가능
//        .httpBasic(Customizer.withDefaults());

    return http.build();
  }
}
```

위와 같은 상태에서 assu 로 요청하면 403 Forbidden 응답이 내려온다.

```shell
# 비밀번호가 틀리면 401 Unauthorized
$ curl -w "%{http_code}" -u assu:1112 http://localhost:8080/hello
401%

# 정상 요청할 경우 403 Forbidden
 $ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/hello
403%

# 인증이 없을 경우 401 Unauthorized 
 $ curl -w "%{http_code}"  http://localhost:8080/hello
401%
```

- `authorizedRequests()`
  - 엔드포인트에 권한 부여 규칙 지정
- `anyRequest()`
  - 이용된 URL 이나 HTTP 방식에 관계없이 모든 요청에 대해 규칙 적용
- `permitAll()`
  - 인증 여부와 관계없이 모든 요청에 대해 접근 허용
- `hasAuthority()`, `hasAnyAuthority()`
  - 조건에 해당하는 권한이 있는 유저만 접근 허용

---

## 1.2. 사용자 '역할'을 기준으로 모든 엔드포인트에 접근 제한

위에서 모든 엔드포인트에 권한에 따라 제약 조건을 적용해보았다. (아직 경로나 HTTP 방식에 따라 선택적으로 제한하지는 않음)

이제 사용자 역할에 따라 같은 구성을 적용해본다.

![역할과 권한 차이](/assets/img/dev/2023/1209/role.png)

**역할은 사용자가 수행할 수 있는 작업의 그룹**을 의미한다.

애플리케이션에서 역할을 이용하면 권한을 정의할 필요가 없다.  
이 때 권한은 개념상으로만 존재하며, 애플리케이션에서는 하나 이상의 작업을 포함하는 역할만 정의하면 된다.

역할도 권한처럼 같은 `GrantedAuthority` 계약으로 나타낸다.

**역할을 정의할 때 역할 이름은 `ROLE_` 접두사로 시작**해야 한다.  
**구현할 때 이 접두사로 역할과 권한 간의 차이**를 나타낸다.

아래는 사용자 역할에 따라 엔드포인트 접근을 제한하는 예시이다.

assu 는 ADMIN 역할이고, silby 는 MANAGER 역할이다. 

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0702) 에 있습니다.

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
  @Bean // 이 메서드가 반환하는 UserDetailsService 가 스프링 컨텍스트에 추가됨
  public UserDetailsService userDetailsService() {
    InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();

    // UserDetailsService 에서 관리하도록 사용자 추가
    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .authorities("ROLE_ADMIN")  // ROLE_ 접두사가 있으면 GrantedAuthority 는 역할을 나타냄
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("2222")
        .roles("MANAGER") // roles() 로 지정시엔 ROLE_ 접두사를 붙이지 않음
        .build();

    manager.createUser(user1);
    manager.createUser(user2);

    return manager;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }

  // HTTP Basic 방식을 명시적으로 설정
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

//    http.authorizeHttpRequests(authz ->
//            authz.anyRequest()  // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
//                .authenticated()) // 인증된 유저만 접근 허용
//        .httpBasic(Customizer.withDefaults());

    http.authorizeHttpRequests(authz ->
            authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
                .hasRole("ADMIN"))   // ADMIN 역할이 있는 유저만 접근 허용
        .httpBasic(Customizer.withDefaults());


//    http.authorizeHttpRequests(authz ->
//            authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
//                .hasAnyRole("ADMIN", "MANAGER"))   // ADMIN, MANAGER 역할 중 하나라도 있는 유저만 접근 허용
//        .httpBasic(Customizer.withDefaults());


//    http.authorizeHttpRequests(authz ->
//            authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
//            .permitAll())   // 인증 여부과 관계없이 모든 요청에 인증 없이 요청 가능
//        .httpBasic(Customizer.withDefaults());

    return http.build();
  }
}
```

권한으로 정의할 때와 달라진 부분은 아래와 같다.

```java
@Configuration
public class ProjectConfig {
  @Bean 
  public UserDetailsService userDetailsService() {
    UserDetails user1 = User.withUsername("assu")
            .password("1111")
            .authorities("ROLE_ADMIN")  // ROLE_ 접두사가 있으면 GrantedAuthority 는 역할을 나타냄
            .build();
    
    UserDetails user2 = User.withUsername("silby")
            .password("2222")
            .roles("MANAGER") // roles() 로 지정시엔 ROLE_ 접두사를 붙이지 않음
            .build();
    // ...
  }

  // ...
  
  // HTTP Basic 방식을 명시적으로 설정
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(authz ->
                    authz.anyRequest()
                            .hasRole("ADMIN"))   // ADMIN 역할이 있는 유저만 접근 허용
            .httpBasic(Customizer.withDefaults());
    // ...
  }
}
```

주의할 점은 **역할은 선언할 때만 `ROLE_` 접두사를 쓰고, 이용할 때는 접두사를 제외한 이름만 지정**한다는 점이다.

위와 같은 상황에서 엔드포인트를 호출하면 역할에 따라 접근이 제한된다.

```shell
# ADMIN 역할이 아니므로 403 Forbidden
$ curl -w "%{http_code}" -u silby:2222 http://localhost:8080/hello
403%

# 정상
$ curl -w "%{http_code}" -u assu:1111 http://localhost:8080/hello
hello200%

# 역할이 있지만 비밀번호가 틀린 경우 401 Unauthorized 
$ curl -w "%{http_code}" -u assu:1112 http://localhost:8080/hello
401%

# 인증이 없는 경우 401 Unauthorized 
$ curl -w "%{http_code}"  http://localhost:8080/hello
401%
```

---

## 1.3. 모든 엔드포인트에 대한 접근 제한: `denyAll()`

`permitAll()` 은 인증에 상관없이 모든 요청에 대한 접근을 허용한다.  
반대로 `denyAll()` 은 모든 요청에 대한 접근을 제한한다.

```java
http.authorizeHttpRequests(authz ->
        authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
        .permitAll())   // 인증 여부과 관계없이 모든 요청에 인증 없이 요청 가능
    .httpBasic(Customizer.withDefaults());


http.authorizeHttpRequests(authz ->
        authz.anyRequest()    // 이용된 URL 이나 HTTP 방식과 관계없이 모든 요청에 대해 규칙 적용
        .permitAll())   // 인증 여부과 관계없이 모든 요청 거부
    .httpBasic(Customizer.withDefaults());
```

`denyAll()` 은 아래와 같은 상황에서 필요할 수 있다.

pathParameter 로 이메일 주소를 받는 엔드포인트가 있을 때 _@aassuCompany.com_ 으로 끝나는 요청만 허용하고, 다른 이메일 주소 형식은 거부할 때 `denyAll()` 을 사용할 수 있다.  

> 경로와 HTTP 방식, pathParameter 를 기준으로 액세스 제한을 하는 방법은 [https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-2/](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-2/) 을 참고하세요.

혹은 아래와 같이 여러 게이트웨이로 구성된 경우에도 사용할 수 있다.

![denyAll() 이 필요한 경우](/assets/img/dev/2023/1209/denyall.png)

Gateway 2 에서는 서비스 B 에 접근이 가능하지만, 서비스 B 안에 있는 /sales 엔드포인트는 Gateway 1 을 통해서만 받아야하는 경우 `denyAll()` 을 활용하여 요청을 거부할 수 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.jetbrains.com/help/idea/markdown.html#floating-toolbar)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [권한 설정 메서드](https://velog.io/@dailylifecoding/spring-security-authorize-api-basic)
* [AuthorizationFilter로 HttpServletRequests 인증하기 (Authorize HttpServletRequests..)](https://tech-monster.tistory.com/217)