---
layout: post
title:  "Spring Security - 전역 메서드 보안: 사전/사후 권한 필터"
date:   2024-02-03
categories: dev
tags: spring-security pre-filter post-filter
---

이 포스트에서는 메서드의 입출력을 나타내는 필터값에 권한 부여 구성을 적용하는 법에 대해 알아본다.

- 사전 필터링으로 메서드가 매개 변수 값으로 받을 내용 필터링
- 사후 필터링으로 메서드가 반환할 내용 필터링
- 스프링 데이터에 필터링 통합

권한 부여 시 엔드포인트 수준이 아닌 메서드 수준에서 권한을 부여할 수 있다. 이 방법으로 웹 애플리케이션과 웹이 아닌 애플리케이션의 권한 부여를 구성할 수 있는데 이를 
**전역 메서드 보안** 이라고 한다.

---

**목차**

<!-- TOC -->
* [1. 메서드 권한 부여를 위한 사전 필터링 적용: `@PreFilter`](#1-메서드-권한-부여를-위한-사전-필터링-적용-prefilter)
* [2. 메서드 권한 부여를 위한 사후 필터링 적용: `@PostFilter`](#2-메서드-권한-부여를-위한-사후-필터링-적용-postfilter)
* [3. 스프링 데이터 레파지토리에 필터링 적용](#3-스프링-데이터-레파지토리에-필터링-적용)
  * [3.1. `@PreFilter`, `@PostFilter` 애너테이션 적용](#31-prefilter-postfilter-애너테이션-적용)
  * [3.2. 쿼리에 직접 필터링 적용](#32-쿼리에-직접-필터링-적용)
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

[Spring Security - 전역 메서드 보안: 사전/사후 권한 부여](https://assu10.github.io/dev/2024/01/28/springsecurity-global-auth/)  에서 본 
사전/사후 권한 부여인 `@PreAuthorize`, @PostAuthorize` 는 권한 규칙에 맞지 않으면 메서드를 아예 호출하지 않거나 예외를 발생시킨다.

**사전/사후 필터링은 메서드를 메서드 호출을 허용하면서도 메서드로 보내는 매개 변수에 대해 규칙에 맞는 매개 변수만 메서드로 전달하거나, 
메서드를 호출한 후 호출자가 반환된 값의 승인된 부분만 받을 수 있도록 한다.**

- **사전 필터링**
  - 메서드를 호출하기 전에 매개 변수의 값을 필터링
- **사후 필터링**
  - 메서드를 호출하고 난 후 반환된 값을 필터링

![사전 권한 부여와 사전 필터링 차이](/assets/img/dev/2024/0203/filter_1.png)

**필터링을 적용하면 프레임워크는 매개 변수나 반환된 값이 권한 부여 규칙을 준수하지 않아도 메서드를 호출하고, 예외를 발생시키지 않는다.** 대신 **지정한 조건에 준수하는 요소를 필터링**한다.

**필터링은 컬렉션과 배열에만 적용**할 수 있다.

사전 필터링은 메서드가 객체의 배열이나 컬렉션을 받아야 적용할 수 있고, 사후 필터링은 메서드가 컬렉션이나 배열을 반환해야 적용할 수 있다.

---

# 1. 메서드 권한 부여를 위한 사전 필터링 적용: `@PreFilter`

**사전 필터링은 메서드를 호출할 때 메서드 매개 변수로 전송된 값을 검증하여, 주어진 기준을 충족하지 않는 값을 필터링하고 기준에 충족하는 값으로만 메서드를 호출**한다. 

사전 필터링을 사용하면 **메서드가 구현하는 비즈니스 논리와 권한 부여 규칙을 분리**할 수 있어서 실제 운영 시에도 많이 사용된다.

예) 인증된 사용자가 소유한 특정 세부 정보만 처리하는 기능을 구현하며, 이 기능이 여러 위치에서 호출이 될 때 누가 이 기능을 호출하든 관계없이 인증된 사용자의 세부 정보만 처리해야 함

물론 메서드 안에서 처리할 수도 있지만, 권한 부여 논리와 비즈니스 논리를 분리하면 코드 유지 보수가 편해진다.

`@PreFilter` 애너테이션을 이용하며, SpEL 식으로 제공하는 규칙에서 `filterObject` 로 메서드의 매개 변수로 제공하는 컬렉션, 배열 내의 모든 요소를 참조한다.

<**사전 필터링 시나리오**>  
- 유저는 _events_ 엔드포인트 호출
- 유저는 본인이 등록한 이벤트만 검색 가능

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1701) 에 있습니다.

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
    <artifactId>chap1701</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1701</name>
    <description>chap1701</description>
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

@Configuration
@EnableMethodSecurity(prePostEnabled = true)  // 전역 메서드 보안 활성화
public class ProjectConfig {
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

/model/Event.java
```java
package com.assu.study.chap1701.model;

public record Event(String name, String owner) {
  public Event {
  }
}
```

/service/EventService.java
```java
import com.assu.study.chap1701.model.Event;
import org.springframework.security.access.prepost.PreFilter;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class EventService {

  // Event 의 owner 특성이 로그인한 사용자의 이름과 같은 값만 반환
  @PreFilter("filterObject.owner == authentication.name")
  public List<Event> getEvents(List<Event> events) {
    return events;
  }
}
```

`@PreFilter("filterObject.owner == authentication.name")` SpEL 식을 보자.

Event 의 owner 특성이 로그인한 사용자의 이름과 같은 값만 허용한다는 의미이다.  
등호 연산자의 왼쪽에 `filterObjct` 를 이용하며, `filterObject` 는 목록의 객체를 매개 변수로 참조하므로 여기서는 Event 형식이다.  
등호 연산자의 오른쪽에는 `authentication` 객체를 이용하며, 인증응ㄹ 수행한 후 `SecurityContext` 에서 이용 가능한 `authentication` 객체를 곧바로 참조할 수 있다.

/controller/EventController.java
```java
import com.assu.study.chap1701.model.Event;
import com.assu.study.chap1701.service.EventService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;

@RequiredArgsConstructor
@RestController
public class EventController {
  private final EventService eventService;

  @GetMapping("/events")
  public List<Event> getEvents() {
    List<Event> events = new ArrayList<>();

    events.add(new Event("assuEvent1", "assu"));
    events.add(new Event("assuEvent2", "assu"));
    events.add(new Event("silbyEvent1", "silby"));

    return eventService.getEvents(events);
  }
}
```

여기선 엔드포인트에서 리스트를 만들었지만 실제 운영 시엔 클라이언트가 요청의 본문으로 리스트를 제공해야 한다.  

또한 리턴 데이터의 변형이 있지만 `@PutMapping` 이 아닌 `@GetMapping` 을 이용하였는데 이는 테스트를 위해 CSRF 보호를 피하기 위함이다. 

이제 실제 인증된 사용자의 정보만 리턴이 되는지 확인해본다.

```shell
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/events
[{"name":"assuEvent1","owner":"assu"},{"name":"assuEvent2","owner":"assu"}]
200%

$  curl -w %{http_code} -u silby:1111 http://localhost:8080/events
[{"name":"silbyEvent1","owner":"silby"}]
200%
```

---

**필터링 사용 시 주의할 점은 주어진 컬렉션을 필터링 에스펙트가 변경하기 때문에 제공하는 컬렉션이 변경 불가능하면 필터링 에스펙트가 예외를 발생시킨다는 점**이다.  

새로운 List 인스턴스가 반환되는 것이 아니라 필터링 에스펙트가 같은 인스턴스에서 기준에 맞지 않는 요소를 제거하는 것이다.

만일 _List.of()_ 로 변경 불가능한 인스턴스를 제공할 때 어떤 오류가 발생하는지 보자.

```java

@GetMapping("/events")
public List<Event> getEvents() {
//    List<Event> events = new ArrayList<>();
//
//    events.add(new Event("assuEvent1", "assu"));
//    events.add(new Event("assuEvent2", "assu"));
//    events.add(new Event("silbyEvent1", "silby"));

  // 변경 불가능한 인스턴스
  List<Event> events = List.of(
      new Event("assuEvent1", "assu"),
      new Event("assuEvent2", "assu"),
      new Event("silbyEvent1", "silby")
  );

  return eventService.getEvents(events);
}
```

```shell
$ curl -w %{http_code} -u silby:1111 http://localhost:8080/events
{"timestamp":"2024-03-01T05:46:39.732+00:00","status":500,"error":"Internal Server Error","path":"/events"}
500%
```

```shell
java.lang.UnsupportedOperationException: null
	at java.base/java.util.ImmutableCollections.uoe(ImmutableCollections.java:142) ~[na:na]
```

---

# 2. 메서드 권한 부여를 위한 사후 필터링 적용: `@PostFilter`

**사후 필터링은 메서드가 값을 반환할 때 반환된 값이 정의된 규칙을 준수하는지 확인 후 규칙에 준수하는 값만 필터링**한다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1702) 에 있습니다.

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
    <artifactId>chap1702</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1702</name>
    <description>chap1702</description>
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

/model/Event.java
```java
public record Event(String name, String owner) {
  public Event {
  }
}
```

/service/EventService.java
```java
import com.assu.study.chap1702.model.Event;
import org.springframework.security.access.prepost.PostFilter;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class EventService {
  // Event 의 owner 특성이 로그인한 사용자의 이름과 같은 값만 허용
  @PostFilter("filterObject.owner == authentication.principal.username")
  public List<Event> getEvents() {
    List<Event> events = new ArrayList<>();

    events.add(new Event("assuEvent1", "assu"));
    events.add(new Event("assuEvent2", "assu"));
    events.add(new Event("silbyEvent1", "silby"));
    return events;
  }
}
```

/controller/EventController.java
```java
import com.assu.study.chap1702.model.Event;
import com.assu.study.chap1702.service.EventService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RequiredArgsConstructor
@RestController
public class EventController {
  private final EventService eventService;

  @GetMapping("/events")
  public List<Event> getEvents() {
    return eventService.getEvents();
  }
}
```

이제 엔드포인트 호출 시 인증한 사용자의 정보만 필터링하여 검색하는 것을 확인할 수 있다.
```shell
$ curl -w %{http_code} -u silby:1111 http://localhost:8080/events
[{"name":"silbyEvent1","owner":"silby"}]
200%

$ curl -w %{http_code} -u assu:1111 http://localhost:8080/events
[{"name":"assuEvent1","owner":"assu"},{"name":"assuEvent2","owner":"assu"}]
200%
```

---

# 3. 스프링 데이터 레파지토리에 필터링 적용

스프링 부트 애플리케이션에서는 SQL, NoSQL 과 같은 DB 에 연결하기 위해 상위 계층으로 스프링 데이터가 자주 사용된다.

**<스프링 데이터를 이용할 때 레파지토리 수준에 필터를 적용하는 방식**>
- `@PreFilter`, `@PostFilter` 애너테이션 적용
- 쿼리에 직접 필터링 적용

레파지토리에 `@PreFilter` 애너테이션을 적용하는 사전 필터링은 다른 계층에 적용하는 것과 같지만 `@PostFilter` 는 성능 관점에서 불리하다.  
조회 결과가 많을 때 OutOfMemory 가 발생할 수도 있으므로 처음부터 필요한 것만 DB 에서 검색하는 것이 결과 레코드를 필터링하는 것보다 성능면에서 유리하다.

Service 수준에서는 앱에서 레코드를 필터링하는 것 외에 다른 옵션이 없지만, 레파지토리 수준에서는 필요한 데이터만 조회하도록 쿼리를 구현하는 것이 좋다.

---

## 3.1. `@PreFilter`, `@PostFilter` 애너테이션 적용

<**테스트 시나리오**>  
- _events/{text}_ 의 엔드포인트
- 인증된 유저와 이벤트 소유자가 동일하면서, 엔드포인트의 매개 변수로 넘어온 문자열을 이벤트명이 포함하는 결과 리턴

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1703) 에 있습니다.

> 아래 예시는 `@PostFilter` 를 사용하므로 좋지 않은 예시임

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
    <artifactId>chap1703</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1703</name>
    <description>chap1703</description>
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

application.properties
```properties
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.url=jdbc:mysql://localhost:13306/security?serverTimezone=UTC
spring.datasource.username=root
spring.datasource.password=<YOUR_PASSWORD>
spring.jpa.show-sql=true
#spring.jpa.defer-datasource-initialization=true
```

```sql
CREATE TABLE `event` (
   `id` int NOT NULL AUTO_INCREMENT,
   `name` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
   `owner` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
   PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `security`.`event` (`name`, `owner`) VALUES ('assuEvent1', 'assu');
INSERT IGNORE INTO `security`.`event` (`name`, `owner`) VALUES ('assuEvent2', 'assu');
INSERT IGNORE INTO `security`.`event` (`name`, `owner`) VALUES ('silbyEvent1', 'silby');
```

/entity/Event.java
```java
package com.assu.study.chap1703.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class Event {

  @Id
  private Integer id;

  private String name;

  private String owner;
}
```

/repository/EventRepository.java
```java
import com.assu.study.chap1703.entity.Event;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.security.access.prepost.PostFilter;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EventRepository extends JpaRepository<Event, Integer> {

  @PostFilter("filterObject.owner == authentication.principal.username")
  List<Event> findByNameContaining(String text);
}
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

/controller/EventController.java
```java
import com.assu.study.chap1703.entity.Event;
import com.assu.study.chap1703.repository.EventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RequiredArgsConstructor
@RestController
public class EventController {
  private final EventRepository eventRepository;

  @GetMapping("/events/{text}")
  public List<Event> findEventsContaining(@PathVariable String text) {
    return eventRepository.findByNameContaining(text);
  }
}
```

```shell
# 이벤트 소유자가 assu 이면서 이벤트명에 event 가 포함되는 이벤트 검색
$ curl -w %{http_code} -u assu:1111 http://localhost:8080/events/event
[{"id":1,"name":"assuEvent1","owner":"assu"},{"id":2,"name":"assuEvent2","owner":"assu"}]
200%

# 이벤트 소유자가 silby 이면서 이벤트명에 event 가 포함되는 이벤트 검색
$ curl -w %{http_code} -u silby:1111 http://localhost:8080/events/event
[{"id":3,"name":"silbyEvent1","owner":"silby"}]
200
```

---

## 3.2. 쿼리에 직접 필터링 적용

리포지토리에 `@PostFilter` 를 적용하면 필요엇는 데이터까지 조회하기 때문에 권장하지 않는다.  
처음부터 필요한 데이터만 선택하려면 쿼리에 직접 SpEL 식을 지정하면 된다.

- 스프링 컨텍스트에 `SecurityEvaluationContextExtension` 형식의 객체 추가
- 리토지토리 클래스 쿼리 수정

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1704) 에 있습니다.

> ProjectConfig.java, EventRepository.java, pom.xml 를 제외하고 [3.1. `@PreFilter`, `@PostFilter` 애너테이션 적용](#31-prefilter-postfilter-애너테이션-적용) 과 모두 동일함

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
    <artifactId>chap1704</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1704</name>
    <description>chap1704</description>
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
        <!-- https://mvnrepository.com/artifact/org.springframework.security/spring-security-data -->
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-data</artifactId>
            <version>6.2.2</version>
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
import org.springframework.security.data.repository.query.SecurityEvaluationContextExtension;

@EnableMethodSecurity(prePostEnabled = true)
@Configuration
public class ProjectConfig {
  // 스프링 컨텍스트에 SecurityEvaluationContextExtension 추가
  @Bean
  public SecurityEvaluationContextExtension securityEvaluationContextExtension() {
    return new SecurityEvaluationContextExtension();
  }

  //  ...
}

```

/repository/EventRepository.java
```java
import com.assu.study.chap1704.entity.Event;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EventRepository extends JpaRepository<Event, Integer> {

  @Query("SELECT e FROM Event e WHERE e.name LIKE %:text% AND e.owner=?#{authentication.principal.username}")
  List<Event> findByNameContaining(String text);
}
```

호출 결과는 [3.1. `@PreFilter`, `@PostFilter` 애너테이션 적용](#31-prefilter-postfilter-애너테이션-적용) 과 동일하지만 필요한 데이터만 가져오므로 성능 상 유리하다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.yes24.com/Product/Goods/112200347)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [Security Deprecated](https://velog.io/@bigquann97/TIL-13-Security-Deprecated)