---
layout: post
title:  "Spring Security - CORS (Cross-Site Resource Sharing, 교차 출처 리소스 공유)"
date: 2024-01-09
categories: dev
tags: spring-security cors cross-origin fors-configurer
---

이 포스트에서는 CORS 에 대해 알아본 후 스프링 시큐리티에 적용하는 법에 대해 알아본다.

- CORS 구성 적용

---

**목차**

<!-- TOC -->
* [1. CORS (Cross-Site Resource Sharing, 교차 출처 리소스 공유)](#1-cors-cross-site-resource-sharing-교차-출처-리소스-공유)
* [2. `@CrossOrigin` 애너테이션으로 CORS 정책 적용](#2-crossorigin-애너테이션으로-cors-정책-적용)
* [3. `CorsConfigurer` 로 CORS 적용](#3-corsconfigurer-로-cors-적용)
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

# 1. CORS (Cross-Site Resource Sharing, 교차 출처 리소스 공유)

기본적으로 브라우저는 사이트가 로드된 도메인 이외의 도메인으로 오는 요청은 허용하지 않지만 이러한 호출이 필요한 경우는 꽤 많다.  
이럴 때 CORS 를 이용하면 애플리케이션이 요청을 허용할 도메인을 지정할 수 있다.

CORS 메커니즘은 HTTP 헤더를 기반으로 동작하며, 헤더 내용은 아래와 같다.
- `Access-Control-Allow-Origin`
  - 도메인의 리소스에 접근할 수 있는 외부 도메인(원본)
- `Access-Control-Allow-Methods`
  - 다른 도메인에 대해 접근을 허용하지만 특정 HTTP 방식만 허용하고 시을 때 지정
- `Access-Control-Allow-Headers`
  - 특정 요청에 이용할 수 있는 헤더에 제한을 추가

---

CORS 를 구성하지 않고 교차 출처 호출을 할 때 어떤 일이 발생하는지 확인해보자.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1004) 에 있습니다.

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
    <artifactId>chap1004</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1004</name>
    <description>chap1004</description>
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
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
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
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-thymeleaf</artifactId>
        </dependency>
        <dependency>
            <groupId>org.thymeleaf.extras</groupId>
            <artifactId>thymeleaf-extras-springsecurity6</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>

</project>
```

이제 메인 페이지 하나와 REST 엔드포인트를 포함하는 컨트롤러를 정의한다.  
일반 MVC `@Controller` 이므로 엔드포인트에 명시적으로 `@ResponseBody` 애너테이션을 명시해주어야 REST API 로 인식이 된다.

/controller/HelloController.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Slf4j
@Controller
public class HelloController {
  @GetMapping("/")
  public String main() {
    return "main.html";
  }

  @PostMapping("/test")
  @ResponseBody
  public String test() {
    log.info("TEST Method");
    return "hello";
  }
}
```

구성 클래스는 아래와 같이 구성한다.
- CORS 메커니즘을 이해하는 것이 목적이므로 CSRF 보호는 비활성화
- 모든 엔드포인트에 대해 인증되지 않은 접근 허용

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(AbstractHttpConfigurer::disable)  // csrf 비활성화
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll());  // 인증되지 않아도 모든 요청 허용

    return http.build();
  }
}
```

/resources/templates/main.html
```html
<!DOCTYPE HTML>
<html lang="en">
    <head>
        <script>
            const http = new XMLHttpRequest();
            const url='http://127.0.0.1:8080/test';
            http.open("POST", url);
            http.send();

            http.onreadystatechange = (e) => {
                document.getElementById("output")
                    .innerHTML =
                    http.responseText;
            }
        </script>
    </head>
    <body>
        <div id="output"></div>
    </body>
</html>
```

브라우저에서 localhost 도메인으로 접속한 후 자바스크립트에서 127.0.0.1 로 호출하면 같은 호스트를 나타내더라도 브라우저는 문자열이 다르므로 서로 다른 도메인이라고 인식하여 교차 호출 효과가 있다.

localhost:8080 으로 접속하면 아래와 같은 오류를 확인할 수 있다.
![CORS 오류](/assets/img/dev/2024/0109/cors.png)

```text
Access to XMLHttpRequest at 'http://127.0.0.1:8080/test' from origin 'http://localhost:8080' has been blocked by 
CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

오류 메시지의 내용은 `Access-Control-Allow-Origin` 헤더가 없어서 응답이 수락되지 않았다는 내용이다.

스프링 부트는 기본적으로 CORS 관련 헤더를 설정하지 않는다. 따라서 위의 오류가 나오는 것이 맞다.

그런데 컨트롤러에서 찍은 로그는 서버 콘솔에 출력되는 것을 확인할 수 있다. 즉, 엔드포인트는 호출이 되었다는 것이다.

이 부분이 CORS 와 CSRF 의 큰 차이점이다.

**CORS 는 제한을 가하기보다 교체 도메인 호출의 엄격한 제약 조건을 완화하도록 도와주는 기능이기 때문에 제한이 적용되어도 일부 상황에서는 엔드포인트 호출이 가능**하다. (이 동작이 항상 수행되는 것은 아님)    

종종 **브라우저는 요청을 허용해야 하는지 확인하기 위해 먼저 HTTP OPTIONS 방식으로 호출을 하는데 이 테스트 요청을 사전 요청 (preflight)** 이라고 한다.  
**preflight 요청이 실패하면 브라우저는 원래 요청을 수락하지 않는다.**

**preflight 요청을 할지 결정하는 것은 브라우저의 책임**이고, **개발자가 이 논리를 구현하는 것은 아니지**만, 특정 도메인에 CORS 정책을 지정하지 않았는데도 교차 출처 호출이 될 때 헤매지 않기 위해 
개념을 알아두는 것이 좋다.

**CORS 메커니즘은 결국 브라우저에 관한 것이지 엔드포인트를 보호하는 방법은 아니다.**    
**CORS 메커니즘이 유일하게 보장하는 것은 허용하는 출처의 도메인만 브라우저의 특정 페이지에서 요청을 수행할 수 있다는 것**이다.

---

# 2. `@CrossOrigin` 애너테이션으로 CORS 정책 적용

> 실제 운영에서는 잘 사용되지 않으니 내용만 알아둘 것

`@CrossOrigin` 애너테이션으로 다른 도메인에서의 요청을 허용하도록 CORS 를 구성해본다.

엔드포인트 바로 위에 `@CrossOrigin` 애너테이션을 선언하여 허용된 출처와 메서드를 구성하면 된다.

**`@CrossOrigin` 의 장점은 각 엔드포인트에 맞게 CORS 를 구성할 수 있다는 점**이다.  
하지만 코드가 반복적으로 구현되어야 하고, 새로운 엔드포인트 추가 시 애너테이션을 추가하는 것을 잊어버릴 수도 있다.

이에 대한 부분은 [3. `CorsConfigurer` 로 CORS 적용](#3-corsconfigurer-로-cors-적용) 에 나옵니다.

```java
@PostMapping("/test")
@ResponseBody
@CrossOrigin("http://localhost:8080")
public String test() {
  log.info("TEST Method");
  return "hello";
}
```

`@CrossOrigin` 은 여러 출처를 정의할 수도 있다.

```java
@CrossOrigin({"test.com", "aaa.co.kr"})
```

애너테이션의 allowedHeaders, methods 특성으로 허용되는 헤더와 메서드도 설정 가능하다.

출처와 헤더에 `*` 를 이용하면 모든 헤너와 출처를 허용할 수 있지만 이렇게 될 경우 XSS (교차 사이트 스크립팅) 요청에 노출되어 결과적으로 DDos 공격에 취약해질 수 있다.

---

# 3. `CorsConfigurer` 로 CORS 적용

CORS 구성은 한 곳에서 정의하는 것이 관리하기가 더 편하다.

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;

import java.util.List;

@Configuration
public class ProjectConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .cors(c -> {
          CorsConfigurationSource source = request -> {
            CorsConfiguration config = new CorsConfiguration();
            config.setAllowedOrigins(List.of("http://localhost:8080", "test.com"));
            config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
            return config;
          };
          c.configurationSource(source);
        })
        .csrf(AbstractHttpConfigurer::disable)  // csrf 비활성화
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll());  // 인증되지 않아도 모든 요청 허용

//    http
//        .csrf(AbstractHttpConfigurer::disable)  // csrf 비활성화
//        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll());  // 인증되지 않아도 모든 요청 허용

    return http.build();
  }
}
```

`CorsConfiguration` 은 허용되는 출처, 메서드, 헤더를 지정하는 객체로 이 방식을 이용하려면 최소한 출처와 메서드를 지정해야 한다.  
`CorsConfiguration` 객체는 기본적으로 아무 메서드도 정의하지 않기 때문에 출처만 지정하면 애플리케이션이 요청을 허용하지 않는다.

---

# 마치며...

- 특정 도메인에서 호스팅되는 웹 애플리케이션이 다른 도메인의 컨텐츠에 접근하려고 할 때 발생하며, 기본적으로 브라우저는 이러한 접근을 허용하지 않음
- CORS 구성을 이용하면 리소스의 일부를 브라우저에서 실행되는 웹 애플리케이션의 다른 도메인에서 호출할 수 있음
- CORS 를 구성하는 방법은 `@CrossOrigin` 애너테이션으로 엔드포인트별로 구성하는 방법과 `HttpSecurity` 의 `cors()` 로 중앙화된 구성 클래스에서 구성하는 방법이 있음

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)