---
layout: post
title:  "Spring Security - 전역 메서드 보안: 사전/사후 권한 부여"
date: 2024-01-28
categories: dev
tags: spring-security enable-method-security pre-authorize post-authorize has-permission permission-evaluator
---

이 포스트에서는 메서드 수준의 권한 부여 규칙을 적용하는 법에 대해 알아본다.

- 애플리케이션 전역 메서드 보안
- 권한, 역할, 사용 권한 기반의 메서드 사전 권한 부여
- 권한, 역할, 사용 권한 기반의 메서드 사후 권한 부여

권한 부여 시 엔드포인트 수준이 아닌 메서드 수준에서 권한을 부여할 수 있다. 이 방법으로 웹 애플리케이션과 웹이 아닌 애플리케이션의 권한 부여를 구성할 수 있는데 이를 
**전역 메서드 보안** 이라고 한다.

---

**목차**

<!-- TOC -->
* [1. 전역 메서드 보안](#1-전역-메서드-보안)
  * [1.1. 호출 권한 부여](#11-호출-권한-부여)
    * [사전 권한 부여](#사전-권한-부여)
    * [사후 권한 부여](#사후-권한-부여)
  * [1.2. 전역 메서드 보안 활성화: `@EnableMethodSecurity`](#12-전역-메서드-보안-활성화-enablemethodsecurity)
* [2. 권한, 역할에 사전 권한 부여: `@PreAuthorize`](#2-권한-역할에-사전-권한-부여-preauthorize)
  * [2.1. 메서드 매개 변수의 값으로 권한 부여 규칙 정의](#21-메서드-매개-변수의-값으로-권한-부여-규칙-정의)
* [3. 사후 권한 부여: `@PostAuthorize`](#3-사후-권한-부여-postauthorize)
* [4. 메서드의 사용 권한 부여: `hasPermission()`, `PermissionEvaluator`](#4-메서드의-사용-권한-부여-haspermission-permissionevaluator)
  * [4.1. 객체, 사용 권한을 받는 메서드로 사용 권한 부여](#41-객체-사용-권한을-받는-메서드로-사용-권한-부여)
  * [4.2. 객체 ID, 객체 형식, 사용 권한을 받는 메서드로 사용 권한 부여](#42-객체-id-객체-형식-사용-권한을-받는-메서드로-사용-권한-부여)
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

# 1. 전역 메서드 보안

메서드 수준에서 권한 부여를 활성화하는 방법과 다양한 권한 부여 규칙을 적용하기 위해 스프링 시큐리티가 제공하는 옵션에 대해 알아본다.  
이런 옵션들도 유연하게 권한 부여를 적용하여 엔드포인트 수준의 권한 부여만으로 해결할 수 없는 상황을 해결할 수 있다.

예) 엔드포인트가 아닌 송장 작성 프록시에서 송장 작성 권한 부여 규칙 적용 가능

전역 메서드 보안은 여러 방식으로 권한 부여를 적용할 수 있도록 해주는데, 이러한 방식들에 대해 알아본다.

전역 메서드 보안은 기본적으로 비활성화 상태이므로 활성화 상태로 변경이 필요하다.

전역 메서드 보안으로 할 수 있는 일은 크게 2 가지가 있다.
- 호출 권한 부여
  - 사전 권한 부여: 이용 권리 규칙에 따라 특정 사용자가 메서드를 호출할 수 있는지
  - 사후 권한 부여: 메서드가 실행된 후 메서드가 반환하는 것에 액세스할 수 있는지
- 필터링
  - 사전 필터링: 메서드가 매개 변수를 통해 받을 수 있는 것
  - 사후 필터링: 메서드가 실행된 후 호출자가 메서드에서 다시 받을 수 있는 것

전역 메서드 보안은 애플리케이션의 어떤 계층에도 적용할 수 있다.  
서비스 클래스, 레파지토리, 매니저, 프록시 등 어떤 부분에도 전역 메서드 보안으로 권한 부여를 적용할 수 있다.

> 필터링에 대해서는 [Spring Security - 전역 메서드 보안: 사전/사후 권한 필터](https://assu10.github.io/dev/2024/02/03/springsecurity-global-filter/) 를 참고하세요.

---

## 1.1. 호출 권한 부여

**호출 권한 부여는 전역 메서드 보안과 함께 이용하는 권한 부여 규칙을 구성하기 위한 접근 방식 중 하나**로, **메서드를 호출할 수 있는지 결정하거나 메서드에서 반환된 값에 호출자가 액세스할 수 
있는지를 결정하는 권한 부여 규칙을 적용하는 것**을 말한다.

메서드에 제공된 매개 변수나 그 결과에 따라 접근 권한을 결정하는 것은 엔드포인트 수준의 보안으로는 할 수 없다.

애플리케이션에서 전역 메서드 보안을 활성화하면 스프링 에스펙트 하나가 활성화되는데, 이 AOP 에스펙트는 권한 부여 규칙을 적용하는 메서드에 대한 호출을 가로채서 
권한 부여 규칙을 바탕으로 가로챈 메서드로 호출을 전달할 지 결정한다.

![전역 메서드 보안](/assets/img/dev/2024/0128/global_method.png)

호출 권한 부여는 아래와 같이 나눌 수 있다.
- **사전 권한 부여 (Preauthorization)**
  - 메서드 호출 전에 권한 부여 규칙을 검사
- **사후 권한 부여 (Postauthorization)**
  - 메서드 호출 후에 권한 부여 규칙을 검사

---

### 사전 권한 부여

_findInfoByUser(String username)_ 메서드는 인증된 사용자만 본인의 정보를 볼 수 있을 때 인증된 사용자의 이름을 매개 변수로 전달해야 메서드 호출이 가능하다.  
이러한 것을 사전 권한 부여로 할 수 있다.

정의해놓은 권한 부여 규칙에 따른 사용자 권한이 없으면 보안 에스펙트는 메서드에 대한 호출을 위임하지 않고 대신 예외를 발생시킨다.

---

### 사후 권한 부여


**메서드를 호출하도록 허용하지만 메서드가 반환하는 결과를 얻기 위해 권한 부여가 필요한 방식을 사후 권한 부여**라고 한다.

사후 권한 부여를 이용할 때 주의할 점이 있는데 만일 메서드가 실행 중에 데이터 변경 등 무엇인가를 변경하면 사후 권한 부여의 성공 여부와 상관없이 변경은 진행된다.  

**`@Transactional` 애너테이션 이용과 무관하게 사후 권한 부여가 실패해도 변경이 롤백되지 않는다.**  
**사후 권한 부여 기능에서 발생하는 예외는 트랜잭션 관리자가 트랜잭션을 커밋한 후에 발생하기 때문**이다.

---

## 1.2. 전역 메서드 보안 활성화: `@EnableMethodSecurity`

전역 메서드 보안은 기본적으로 활성화되어 있지 않아서 활성화를 먼저 해주어야 한다.

전역 메서드 보안은 권한 부여 규칙을 정의하는 세 가지 방법이 있다.

- 사전/사후 권한 부여 애너테이션
- JSR 250 애너테이션 (`@RolesAllowed`)
- `@Secured` 애너테이션

대부분 사전/사후 권한 부여 애너테이션을 이용하기 때문에 사전/사후 권한 부여 애너테이션을 이용하는 방법에 대해 알아본다.  
사전/사후 권한 부여 애너테이션을 활성화하려면 `@EnableMethodSecurity` 의 `prePostEnable` 특성을 이용하면 된다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1601) 에 있습니다.

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
    <artifactId>chap1601</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1601</name>
    <description>chap1601</description>
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

```java
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

@Configuration

//@EnableGlobalMethodSecurity(prePostEnabled = true)  // deprecated
@EnableMethodSecurity(prePostEnabled = true)
public class ProjectConfig {
}
```

HTTP Basic 인증, OAuth 2 인증 등 모든 인증 방식에 전역 메서드 보안을 함께 사용할 수 있으며, 종속성은 `spring-boot-starter-security` 만 있으면 된다.

---

# 2. 권한, 역할에 사전 권한 부여: `@PreAuthorize`

사전 권한 부여하는 방법과 실제 동작을 확인해본다.

<**사전 권한 부여 적용 시나리오**>  
- _hello_ 엔드포인트 노출, 이 엔드포인트는 인증된 사용자만 호출 가능
- 보안 에스펙트는 인증된 사용자에게 쓰기 권한이 있는지 확인 후 쓰기 권한이 없으면 Service 에 호출을 위임하지 않음
- 권한 부여가 실패하면 보안 에스펙트는 Controller 에 예외 전달

위 내용을 확인하기 위해 쓰기 권한이 있는 유저와 없는 유저 2명을 정의하고, 인증된 사용자를 준비하기 위해 `UserDetailsService` 와 `PasswordEncoder` 를 재정의한다.

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;

@Configuration

//@EnableGlobalMethodSecurity(prePostEnabled = true)  // deprecated
@EnableMethodSecurity(prePostEnabled = true)
public class ProjectConfig {
  @Bean
  public UserDetailsService userDetailsService() {
    // UserDetailsService 로써 InMemoryUserDetailsManager 선언
    InMemoryUserDetailsManager uds = new InMemoryUserDetailsManager();

    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .authorities("read")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("1111")
        .authorities("write")
        .build();

    uds.createUser(user1);
    uds.createUser(user2);

    return uds;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }
}
```

이제 권한 부여 규칙을 정의할 Service 에 권한 뷰여 규칙을 적용한다.

/service/HelloService.java
```java
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;

@Service
public class HelloService {

  @PreAuthorize("hasAuthority('write')")  // 권한 부여 규칙 정의
  public String getName() {
    return "testName";
  }
}
```

> `hasAuthority()` 에 대한 다른 예시는 [1.1. 사용자 ‘권한’을 기준으로 모든 엔드포인트에 접근 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-1/#11-%EC%82%AC%EC%9A%A9%EC%9E%90-%EA%B6%8C%ED%95%9C%EC%9D%84-%EA%B8%B0%EC%A4%80%EC%9C%BC%EB%A1%9C-%EB%AA%A8%EB%93%A0-%EC%97%94%EB%93%9C%ED%8F%AC%EC%9D%B8%ED%8A%B8%EC%97%90-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C) 을 참고하세요.

`hasAuthority()` 외에도 `hasAnyAuthority()`, `hasRole()`, `hasAnyRole()` 등이 있다.

/controller/HelloController.java
```java
import com.assu.study.chap1601.service.HelloService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RequiredArgsConstructor
@RestController
public class HelloController {

  private final HelloService helloService;

  @GetMapping("/hello")
  public String hello() {
    // 사전 권한 부여 규칙을 적용한 메서드 호출
    return "Hello, " + helloService.getName();
  }
}
```

이제 각각 write 권한이 있는 유저와 없는 유저로 엔드포인트를 호출해본다.
```shell
# write 권한이 있는 유저
$ curl -w %{http_code} -u silby:1111 http://localhost:8080/hello
Hello, testName
200%

# write 권한이 없는 유저는 403 Forbidden
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/hello
{"timestamp":"2024-02-29T01:48:45.711+00:00","status":403,"error":"Forbidden","path":"/hello"}
403%
```

---

## 2.1. 메서드 매개 변수의 값으로 권한 부여 규칙 정의

이제 메서드 매개 변수의 값으로 권한 부여 규칙을 정의해본다.

<**사전 권한 부여 적용 시나리오**>
- _hello_ 엔드포인트 노출, 이 엔드포인트는 인증된 사용자만 호출 가능
- 보안 에스펙트는 매개 변수로 제공된 이름이 인증된 사용자의 이름과 같은지 검증 후 해당 유저의 비밀 이름 목록 리턴
- 검증이 실패하면 보안 에스펙트는 Controller 에 예외 전달

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1602) 에 있습니다.

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
    <artifactId>chap1602</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1602</name>
    <description>chap1602</description>
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

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;

@EnableMethodSecurity(prePostEnabled = true)
@Configuration
public class ProjectConfig {
  @Bean
  public UserDetailsService userDetailsService() {
    // UserDetailsService 로써 InMemoryUserDetailsManager 선언
    InMemoryUserDetailsManager uds = new InMemoryUserDetailsManager();

    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .authorities("read")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("1111")
        .authorities("write")
        .build();

    uds.createUser(user1);
    uds.createUser(user2);

    return uds;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }
}
```

/service/HelloService.java
```java
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class HelloService {

  private final Map<String, List<String>> secretNames = Map.of(
      "assu", List.of("assu1", "assu2"),
      "silby", List.of("silby1", "silby2")
  );

  // name 매개변수값을 #name 으로 참조하여 인증 개체에 직접 접근해서 현재 인증된 사용자를 참조
  // 인증된 사용자의 이름이 매서드의 매개 변수로 지정된 값과 같아야 메서드 호출 가능
  // 즉, 사용자는 자신의 비밀 이름만 검색 가능
  @PreAuthorize("#name == authentication.principal.username")
  public List<String> getSecretNames(String name) {
    return secretNames.get(name);
  }
}
```

/controller/HelloController.java
```java
import com.assu.study.chap1602.service.HelloService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RequiredArgsConstructor
@RestController
public class HelloController {
  private final HelloService helloService;

  @GetMapping("/secret/names/{name}")
  public List<String> hello(@PathVariable String name) {
    return helloService.getSecretNames(name);
  }
}
```

이제 인증된 사용자 본인의 정보만 조회할 수 있음을 확인할 수 있다.
```shell
# 본인의 정보 조회
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/secret/names/assu
["assu1","assu2"]
200%

# 본인 정보가 아닐 경우 403 Forbidden
$  curl -w %{http_code} -u assu:1111 http://localhost:8080/secret/names/silby
{"timestamp":"2024-02-29T03:08:20.916+00:00","status":403,"error":"Forbidden","path":"/secret/names/silby"}
403%
```

---

# 3. 사후 권한 부여: `@PostAuthorize`

사후 권한 부여는 메서드 호출은 허용하지만 조건이 충족하지 못하면 호출자가 반환된 값을 받지 못하게 할 때 사용한다.  
즉, **메서드 실행은 허용하지만 반환되는 내용을 검증한 후 기준이 충족되지 않으면 호출자가 반환값에 접근하지 못하게 한다.**

<**사후 권한 부여 적용 시나리오**>
- _book_ 엔드포인트 노출, 이 엔드포인트는 인증된 사용자만 호출 가능
- Service 메서드는 엔드포인트로 넘어온 name 의 세부 정보를 리턴하며, 그 세부 정보의 user 에게 읽기 권한이 있어야 엔드포인트를 호출한 클라이언트에게 세부 정보 리턴
- 보안 에스펙트는 Service 메서드를 호출하기 전까지는 권한을 알 수 없음 (인증된 유저의 권한이 아닌 리턴되는 세부 정보에 해당하는 유저의 권한을 체크하므로)
- 따라서 보안 에스펙트는 메서드로 호출을 위임하고 호출 후 권한 부여 규칙을 적용
- Service 메서드 호출 후 세부 정보 리턴 시 보안 에스펙트는 해당 유저에게 읽기 권한이 있는지 확인
- 검증이 실패하면 보안 에스펙트는 Controller 에 예외 전달

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1603) 에 있습니다.

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
    <artifactId>chap1603</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1603</name>
    <description>chap1603</description>
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

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;

@EnableMethodSecurity(prePostEnabled = true)
@Configuration
public class ProjectConfig {
  @Bean
  public UserDetailsService userDetailsService() {
    // UserDetailsService 로써 InMemoryUserDetailsManager 선언
    InMemoryUserDetailsManager uds = new InMemoryUserDetailsManager();

    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .authorities("read")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("1111")
        .authorities("write")
        .build();

    uds.createUser(user1);
    uds.createUser(user2);

    return uds;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }
}
```

/model/Book.java
```java
package com.assu.study.chap1603.model;

import java.util.List;

/**
 * 이름, 책 목록, 역할 목록이 들어있는 객체
 */
public record Employee(String name, List<String> books, List<String> roles) {
}
```

/service/BookService.java
```java
import com.assu.study.chap1603.model.Employee;
import org.springframework.security.access.prepost.PostAuthorize;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class BookService {
  private final Map<String, Employee> records =
      Map.of("assu",
          new Employee("assu1",
              List.of("assubook1", "assubook2"),
              List.of("manager", "reader")),
          "silby",
          new Employee("silby",
              List.of("silbybook1", "silbybookk2"),
              List.of("resercher")));

  // 사후 권한 부여를 위한 식
  // returnObject 메서드가 반환한 값을 참조하며, 메서드가 실행된 후 제공되는 메서드 반환값을 이용
  @PostAuthorize("returnObject.roles.contains('reader')")
  public Employee getBooks(String name) {
    return records.get(name);
  }
}
```

/controller/BookController.java
```java
import com.assu.study.chap1603.model.Employee;
import com.assu.study.chap1603.service.BookService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RequiredArgsConstructor
@RestController
public class BookController {
  private final BookService bookService;

  @GetMapping("/book/details/{name}")
  public Employee getBook(@PathVariable String name) {
    return bookService.getBooks(name);
  }
}
```

이제 누구로 인증을 하던 reader 권한이 있는 assu 의 세부 정보를 조회가 가능하지만, reader 권한이 없는 silby 의 세부 정보는 조회가 불가능하다.
```shell
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/book/details/assu
{"name":"assu1","books":["assubook1","assubook2"],"roles":["manager","reader"]}
200%

# reader 권한이 없는 유저의 정보 조회 시 403 Forbidden
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/book/details/silby
{"timestamp":"2024-03-01T02:32:52.009+00:00","status":403,"error":"Forbidden","path":"/book/details/silby"}
403%
```

같은 메서드에 사전 권한 부여와 사후 권한 부여가 모두 필요하면 `@PreAuthorize` 와 `@PostAuthorize` 를 함께 사용하면 된다.

---

# 4. 메서드의 사용 권한 부여: `hasPermission()`, `PermissionEvaluator`

만일 권한 부여 논리가 복잡해서 식을 한 줄로 작성할 수 없을 경우 SpEL 식을 길게 써야하는데 이는 권장하지 않으며 가독성을 떨어뜨린다.  

복잡한 권한 부여 규칙을 적용해야 할 때는 긴 SpEL 식을 작성하는 것이 아니라 그 논리를 별도의 클래스로 만드는 것이 좋다.

사용 권한 논리를 구현하기 위해 `PermissionEvaluator` 계약을 구현한다.

`PermissionEvaluator` 인터페이스 (사용 권한 평가기)
```java
package org.springframework.security.access;

import java.io.Serializable;
import org.springframework.aop.framework.AopInfrastructureBean;
import org.springframework.security.core.Authentication;

public interface PermissionEvaluator extends AopInfrastructureBean {
  // 객체, 사용 권한 (여기서 사용할 메서드)
  // 두 객체 (권한 부여 규칙의 주체가 되는 객체와 사용 권한 논리를 구현하기 위한 추가 세부 정보를 제공하는 객체) 를 받음
  boolean hasPermission(Authentication authentication, Object targetDomainObject, Object permission);

  // 객체 ID, 객체 형식, 사용 권한
  // 필요한 객체를 얻는데 이용할 수 있는 객체 ID 를 받음
  // 같은 권한 평가기가 여러 객체 형식에 적용될 때 이용할 수 있는 객체 형식과 사용 권한을 평가하기 위한 추가 세부 정보를 제공하는 객체를 받음
  boolean hasPermission(Authentication authentication, Serializable targetId, String targetType, Object permission);
}
```

스프링 시큐리티는 `hasPermission()` 메서드를 호출할 때 자동으로 Authentication 객체를 매개 변수값으로 제공하므로, Authentication 객체는 전달할 필요가 없다.  
Authentication 객체는 이미 SecurityContext 에 있기 때문이다.

---

## 4.1. 객체, 사용 권한을 받는 메서드로 사용 권한 부여

<**`PermissionEvaluator` 적용 시나리오**>
- 모든 문서엔 해당 문서의 작성자인 소유자가 있음
- 문서의 세부 정보를 조회하려면 사용자는 manager 이거나, 해당 문서의 소유자이어야 함

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1604) 에 있습니다.

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
    <artifactId>chap1604</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1604</name>
    <description>chap1604</description>
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


/model/Document.java
```java
public record Document(String owner) {
  public Document {
  }
}
```

/repository/DocumentRepository.java
```java
import com.assu.study.chap1604.model.Document;
import org.springframework.stereotype.Repository;

import java.util.Map;

@Repository
public class DocumentRepository {
  private final Map<String, Document> documents =
      Map.of("assuDoc", new Document("assu"),
          "coolDoc", new Document("assu"),
          "silbyDoc", new Document("silby")
      );

  public Document findDocument(String code) {
    return documents.get(code);
  }
}
```

/service/DocumentService.java
```java
import com.assu.study.chap1604.model.Document;
import com.assu.study.chap1604.repository.DocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PostAuthorize;
import org.springframework.stereotype.Service;

@RequiredArgsConstructor
@Service
public class DocumentService {
  private final DocumentRepository documentRepository;

  // hasPermission() 메서드는 추가로 구현할 외부 권한 부여식을 참조할 수 있게 함
  // hasPermission() 메서드의 매개 변수는 메서드에서 반환된 값을 나타내는 returnObject 와
  // 접근을 허용하는 역할의 이름인 ROLE_manager 임
  @PostAuthorize("hasPermission(returnObject, 'ROLE_manager')")
  public Document getDocument(String code) {
    return documentRepository.findDocument(code);
  }
}
```

/security/DocumentPermissionEvaluator.java
```java
import com.assu.study.chap1604.model.Document;
import org.springframework.security.access.PermissionEvaluator;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

import java.io.Serializable;

/**
 * 권한 부여 규칙의 구현
 */
@Component
public class DocumentPermissionEvaluator implements PermissionEvaluator {
  @Override
  public boolean hasPermission(Authentication authentication, Object targetDomainObject, Object permission) {
    // targetDomainObject 객체를 Document 형식으로 변환
    Document document = (Document) targetDomainObject;
    // 이 경우에 permission 객체는 역할 이름이므로 String 형식으로 변환
    String p = (String) permission;

    // 사용자에게 매개 변수로 받은 역할이 있는지 검증
    boolean manager =
            authentication.getAuthorities()
                    .stream()
                    .anyMatch(a -> a.getAuthority().equals(p));

    return manager || document.owner().equals(authentication.getName());
  }

  @Override
  public boolean hasPermission(Authentication authentication, Serializable targetId, String targetType, Object permission) {
    // 사용하지 않으므로 구혀하지 않음
    return false;
  }
}
```

이제 스프링 시큐리티가 `PermissionEvaluator` 구현을 인식할 수 있도록 구성 클래스에 `MethodSecurityExpressionHandler` 를 정의한다.

/config/ProjectConfig.java
```java
import com.assu.study.chap1604.security.DocumentPermissionEvaluator;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler;
import org.springframework.security.access.expression.method.MethodSecurityExpressionHandler;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;

@Configuration
@EnableMethodSecurity(prePostEnabled = true)
@RequiredArgsConstructor
public class ProjectConfig {
  private final DocumentPermissionEvaluator documentPermissionEvaluator;

  @Bean
  protected MethodSecurityExpressionHandler methodSecurityExpressionHandler() {
    DefaultMethodSecurityExpressionHandler handler = new DefaultMethodSecurityExpressionHandler();
    handler.setPermissionEvaluator(documentPermissionEvaluator);
    return handler;
  }

  @Bean
  public UserDetailsService userDetailsService() {
    // UserDetailsService 로써 InMemoryUserDetailsManager 선언
    InMemoryUserDetailsManager uds = new InMemoryUserDetailsManager();

    UserDetails user1 = User.withUsername("assu")
        .password("1111")
        .roles("manager")
        .build();

    UserDetails user2 = User.withUsername("silby")
        .password("1111")
        .roles("admin")
        .build();

    uds.createUser(user1);
    uds.createUser(user2);

    return uds;
  }

  // UserDetailsService 를 재정의하면 PasswordEncoder 도 재정의해야함
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }
}
```

/controller/DocumentController.java
```java
import com.assu.study.chap1604.model.Document;
import com.assu.study.chap1604.service.DocumentService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RequiredArgsConstructor
@RestController
public class DocumentController {
  private final DocumentService documentService;

  @GetMapping("/documents/{code}")
  public Document getDocuments(@PathVariable String code) {
    return documentService.getDocument(code);
  }
}
```

이제 manager 권한이 있는 assu 는 모든 정보 조회가 가능하지만, admin 권한이 있는 sibly 는 본인의 정보만 조회 가능한 것을 알 수 있다.

```shell
# manager 권한이 있는 assu 가 본인의 정보 조회
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/documents/assuDoc
{"owner":"assu"}
200%

# manager 권한이 있는 assu 가 silby 의 정보 조회
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/documents/silbyDoc
{"owner":"silby"}
200%

# admin 권한이 있는 silby 가 본인의 정보 조회
$ curl -w %{http_code} -u silby:1111 http://localhost:8080/documents/silbyDoc
{"owner":"silby"}
200%

# admin 권한이 있는 silby 가 assu 의 정보 조회 시 403 Forbidden
$ curl -w %{http_code} -u silby:1111 http://localhost:8080/documents/assuDoc
{"timestamp":"2024-03-01T03:45:21.173+00:00","status":403,"error":"Forbidden","path":"/documents/assuDoc"}
403%
```

---

## 4.2. 객체 ID, 객체 형식, 사용 권한을 받는 메서드로 사용 권한 부여

이제 [4.1. 객체, 사용 권한을 받는 메서드로 사용 권한 부여](#41-객체-사용-권한을-받는-메서드로-사용-권한-부여) 을 메서드가 실행 되기 전에 
인증된 유저가 manager 이거나 본인의 정보를 조회하는 경우만 정보 조회가 가능하도록 해본다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1605) 에 있습니다.

> [4.1. 객체, 사용 권한을 받는 메서드로 사용 권한 부여](#41-객체-사용-권한을-받는-메서드로-사용-권한-부여) 에서 DocumentPermissionEvaluator, DocumentService 만 빼고 모두 동일함

/security/DocumentPermissionEvaluator.java
```java
import com.assu.study.chap1605.model.Document;
import com.assu.study.chap1605.repository.DocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.PermissionEvaluator;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

import java.io.Serializable;

@RequiredArgsConstructor
@Component
public class DocumentPermissionEvaluator implements PermissionEvaluator {
  private final DocumentRepository documentRepository;

  @Override
  public boolean hasPermission(Authentication authentication, Object targetDomainObject, Object permission) {
    // 사용하지 않으므로 구현하지 않음
    return false;
  }

  @Override
  public boolean hasPermission(Authentication authentication, Serializable targetId, String targetType, Object permission) {
    // 객체는 없지만 객체 ID 가 있으므로 ID 로 객체를 얻음
    String code = targetId.toString();
    Document document = documentRepository.findDocument(code);

    // 이 경우에 permission 객체는 역할 이름이므로 String 형식으로 변환
    String p = (String) permission;

    // 사용자에게 매개 변수로 받은 역할이 있는지 검증
    boolean manager = authentication.getAuthorities()
        .stream()
        .anyMatch(a -> a.getAuthority().equals(p));

    return manager || document.owner().equals(authentication.getName());
  }
}
```

/service/DocumentService.java
```java
package com.assu.study.chap1605.service;

import com.assu.study.chap1605.model.Document;
import com.assu.study.chap1605.repository.DocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;

@RequiredArgsConstructor
@Service
public class DocumentService {
  private final DocumentRepository documentRepository;

  @PreAuthorize("hasPermission(#code, 'document', 'ROLE_manager')")
  public Document getDocument(String code) {
    return documentRepository.findDocument(code);
  }
}
```

테스트 결과는 [4.1. 객체, 사용 권한을 받는 메서드로 사용 권한 부여](#41-객체-사용-권한을-받는-메서드로-사용-권한-부여) 와 동일하다. 

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [Security Deprecated](https://velog.io/@bigquann97/TIL-13-Security-Deprecated)
* [GlobalMethodSecurityConfiguration Deprecated](https://docs.spring.io/spring-security/site/docs/current/api/org/springframework/security/config/annotation/method/configuration/GlobalMethodSecurityConfiguration.html)
* [GlobalMethodSecurityConfiguration is deprecated in spring boot 3, how to create Custom Expresion handler in 3?](https://stackoverflow.com/questions/74926313/globalmethodsecurityconfiguration-is-deprecated-in-spring-boot-3-how-to-create)