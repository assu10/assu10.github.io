---
layout: post
title:  "Spring Security - OAuth 2(3): JWT 와 암호화 서명"
date:   2024-01-27
categories: dev
tags: spring-security oauth2 jwt
---

이 포스트에서는 토큰을 검증하는 방법 중에 하나인 JWT 와 암호화 서명에 대해 알아본다.

- 암호화 서명으로 토큰 검증
- 대칭키와 비대칭키로 토큰 서명

토큰을 검증하는 방법은 크게 3가지가 있다.
- 리소스 서버와 권한 부여 서버 간의 직접 호출
- 토큰을 저장하는 공유된 DB 를 이용
- 암호화 서명 이용

암호화 서명으로 토큰을 검증하면 권한 부여 서버를 호출하거나, 공유된 DB 를 이용하지 않아도 토큰 검증이 가능하다. 

---

**목차**

<!-- TOC -->
* [1. JWT 의 대칭키로 서명된 토큰 이용](#1-jwt-의-대칭키로-서명된-토큰-이용)
  * [1.1. JWT 이용](#11-jwt-이용)
  * [1.2. JWT 를 발행하는 권한 부여 서버 구현](#12-jwt-를-발행하는-권한-부여-서버-구현)
  * [1.3. JWT 를 이용하는 리소스 서버 구현](#13-jwt-를-이용하는-리소스-서버-구현)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.2.3
- Spring ver: 6.1.4
- Spring Security ver: 6.2.2
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven

![Spring Initializer Sample](/assets/img/dev/2023/1112/init.png)

---

# 1. JWT 의 대칭키로 서명된 토큰 이용

토큰에 서명하는 가장 직관적인 방법은 대칭키를 이용하는 것이다.

> 대칭키와 비대칭키에 대한 상세한 내용은 [1.4. 인코딩, 암호화, 해싱](https://assu10.github.io/dev/2023/11/19/springsecurity-password/#14-%EC%9D%B8%EC%BD%94%EB%94%A9-%EC%95%94%ED%98%B8%ED%99%94-%ED%95%B4%EC%8B%B1) 을 참고하세요.

대칭키 방식은 같은 키로 토큰에 서명하고, 그 서명을 검증할 수 있어서 간단하고 속도가 빠르다.

---

## 1.1. JWT 이용

> JWT 에 대한 좀 더 상세한 내용은 [2.1. JSON 웹 토큰 (JWT)](https://assu10.github.io/dev/2024/01/13/springsecurity-second-app/#21-json-%EC%9B%B9-%ED%86%A0%ED%81%B0-jwt) 을 참고하세요.

토큰은 헤더와 본문, 서명으로 구성되는데 헤더와 본문의 세부 정보는 JSON 으로 표기되며, Base64 로 인코딩된다.  
세 번째 부분인 서명은 헤더와 본문을 입력으로 이용하는 암호화 알고리즘으로 생성된다. 따라서 **암호화 알고리즘을 이용한다는 것은 키가 필요하다는 의미**이다.

**서명된 JWT 를 JWS (JSON Web Token Signed)** 라고 한다.

토큰이 서명되면 키가 암호가 없이도 그 내용을 볼 수 있지만, 변경은 불가능하다. 내용은 변경하면 서명이 무효화되기 때문이다.  
따라서 해커가 토큰을 탈취하여도 권한을 변경한다던지의 변경은 불가하다.

---

## 1.2. JWT 를 발행하는 권한 부여 서버 구현

> 토큰 발급을 위해 spring-boot 2 를 사용했지만, spring-boot 3 을 이용할 예정  
> 따라서 이 소스는 발급된 JWT 를 리소스 서버에서 검증하기 위해 만들었을 뿐 세부 내용은 알 필요없음

> 소스는 [github](https://github.com/assu10/spring-security-authorization-server) 에 있습니다.

_oauth/token_ 엔드포인트를 호출하여 액세스 토큰 획득
```shell
$ curl -v -XPOST -u client:secret http://localhost:8080/oauth/token?grant_type=password&username=assu&password=1111&scope=read
```

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MDg5NjUyNDMsInVzZXJfbmFtZSI6ImFzc3UiLCJhdXRob3JpdGllcyI6WyJyZWFkIl0sImp0aSI6IjI4YWRiNTY2LTY0ZmUtNGY4My04ZWRmLTUyMzMwZjQ1ZDI3YSIsImNsaWVudF9pZCI6ImNsaWVudCIsInNjb3BlIjpbInJlYWQiXX0.VBjAJJ1ejv2Ko_H3jWO7wv-RwbvA2MVcqnam4toym7w",
  "token_type": "bearer",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX25hbWUiOiJhc3N1Iiwic2NvcGUiOlsicmVhZCJdLCJhdGkiOiIyOGFkYjU2Ni02NGZlLTRmODMtOGVkZi01MjMzMGY0NWQyN2EiLCJleHAiOjE3MTE1MTQwNDMsImF1dGhvcml0aWVzIjpbInJlYWQiXSwianRpIjoiZmMyOTViY2QtOTI5MS00NjMzLThlNzItYTgwOTBmMGE3NTVmIiwiY2xpZW50X2lkIjoiY2xpZW50In0.vNm6S3vzXGOyToYnnK-wG-WdoaPahVwSx27hLAxbRtk",
  "expires_in": 43199,
  "scope": "read",
  "jti": "28adb566-64fe-4f83-8edf-52330f45d27a"
}
```

토큰의 값
```json
{
  "exp":1708968623, // 토큰이 만료되는 타임스탬프
  "user_name":"assu", // 클라이언트가 리소스 접근을 허용한 인증된 사용자
  "authorities":[ // 사용자에게 허가된 권한
    "read"
  ],
  "jti":"d68f64e1-e002-492f-ac2a-e8a3fd17f1d9", // 토큰의 고유 식별자
  "client_id":"client", // 토큰을 요청한 클라이언트
  "scope":[ // 클라이언트에게 허가된 사용 권한
    "read"
  ]
}
```

---

## 1.3. JWT 를 이용하는 리소스 서버 구현

이제 토큰을 대칭키로 검증하는 리소스 서버를 구현한다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1501-rs-mig) 에 있습니다.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.3</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.assu.study</groupId>
    <artifactId>chap1501-rs-mig</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1501-rs-mig</name>
    <description>chap1501-rs-mig</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
        </dependency>
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

보호할 엔드포인트를 하나 정의한다.
/controller/HelloController.java
```java
@RestController
public class HelloController {

  @GetMapping("/hello")
  public String hello() {
    return "hello";
  }
}
```

이제 구성 클래스를 선언하여 JWT 를 검증한다.
/config/ResourceServerConfig.java
```java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

/**
 * 대칭키를 이용한 JWT 인증 구성
 */
@Configuration
public class ResourceServerConfig {

  @Value("${jwt.key}")
  private String JWT_KEY;


  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .authorizeHttpRequests(authz -> authz.anyRequest().authenticated()) // 모든 요청은 인증이 있어야 함
        .oauth2ResourceServer(c -> c.jwt(jwt -> {
          jwt.decoder(jwtDecoder());
        }));

    return http.build();
  }

  @Bean
  public JwtDecoder jwtDecoder() {
    byte[] key = JWT_KEY.getBytes();
    SecretKey originalKey = new SecretKeySpec(key, 0, key.length, "AES");

    NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder.withSecretKey(originalKey).build();

    return jwtDecoder;
  }
}
```

/resources/application.properties
```properties
server.port=9090
jwt.key=ymLTU8rq83j4fmJZj60wh4OrMNuntIj4fmJ
```

대칭 암호화나 서명에 이용되는 키는 임의의 바이트 문자열이며, 랜덤 알고리즘으로 생성할 수 있다.  
실제 운영 시엔 가급적 258 바이트 이상의 임의로 생성된 값을 이용하는 것이 좋다.

이제 리소스 서버를 시작하고, _/hello_ 엔드포인트에 액세스 토큰값을 넣어서 호출해본다.

```shell
$ curl --location 'http://localhost:9090/hello' \
--header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MDg5NjgzMjUsInVzZXJfbmFtZSI6ImFzc3UiLCJhdXRob3JpdGllcyI6WyJyZWFkIl0sImp0aSI6ImY5ZTc5MmY2LTJjNDUtNDAzYS1iOTAwLThlNTZkM2VhZDBkMiIsImNsaWVudF9pZCI6ImNsaWVudCIsInNjb3BlIjpbInJlYWQiXX0.vCFIMq8W7wg4MMwv7EwhQJvjrv5Yg9HPYUkVZ-I4Nic'
200%
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [스프링 시큐리티 OAuth 2 종속성 지원 중단](https://spring.io/projects/spring-security-oauth#overview)
* [Spring Cloud 와 Spring Boot 호환 버전](https://spring.io/projects/spring-cloud)
* [No Authorization Server Support](https://spring.io/blog/2019/11/14/spring-security-oauth-2-0-roadmap-update#no-authorization-server-support)
* [새로운 권한 부여 서버를 개발 중이라는 공지](https://spring.io/blog/2020/04/15/announcing-the-spring-authorization-server)