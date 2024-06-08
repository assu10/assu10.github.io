---
layout: post
title:  "Spring Boot - 웹 애플리케이션 구축 (4): application.properties, Profile 설정"
date:   2023-08-12
categories: dev
tags: springboot msa spring-profiles-active configuration-properties configuration-properties-scan 
---

이 포스트에서는 실행 환경(dev, prod) 에 따라 스프링 애플리케이션 설정에 대해 알아본다.  

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap06) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. Application.properties](#1-applicationproperties)
  * [1.1. `@Value` 애너테이션](#11-value-애너테이션)
  * [1.2. `@ConfigurationProperties`, `@ConfigurationPropertiesScan`](#12-configurationproperties-configurationpropertiesscan)
* [2. Profile 설정](#2-profile-설정)
  * [2.1. Profile 변수값 설정: `spring.profiles.active`](#21-profile-변수값-설정-springprofilesactive)
  * [2.2. 프로파일별 application.properties 설정](#22-프로파일별-applicationproperties-설정)
  * [2.3. `@Profile` 애너테이션과 스프링 빈 설정](#23-profile-애너테이션과-스프링-빈-설정)
  * [2.4. `@Profile` 애너테이션과 인터페이스를 사용한 확장](#24-profile-애너테이션과-인터페이스를-사용한-확장)
  * [2.5. Environment 인터페이스](#25-environment-인터페이스)
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

# 1. Application.properties

스프링 프레임워크는 아래 순서로 정해진 경로에서 application.properties 혹은 application.yaml 파일을 찾아서 로딩한다.

- classpath 루트 패스
- classpath 에 /config 경로
- 패키징된 애플리케이션이 위치한 현재 디렉터리
- 패이징된 애플리케이션이 위치한 현재 디렉터리의 /config 경로
- /config 의 하위 디렉터리

src > main > resources 경로에 위치한 application.properties 파일은 classpath 최상위 경로에 있는 것이다.

---

## 1.1. `@Value` 애너테이션

application.properties 파일에 정의된 데이터를 스프링 빈에 주입하려면 `@Value` 애너테이션을 사용한다.  
`@Value` 애너테이션을 정의하여 데이터를 주입할 수 있는 대상은 클래스 필드와 메서드, 그리고 파라메터이다.

메서드에 `@Value` 애너테이션을 정의할 때 해당 메서드는 setter 패턴으로 정의되어 있어야 하기 때문에 메서드에 인자가 필요하며,  
`@Value` 애너테이션은 프로퍼티 키와 매칭된 데이터를 주입한다.

application.properties 파일이 아래와 같이 정의되어 있다고 하자.
```properties
#spring.main.allow-bean-definition-overriding=true
server.port=18080

## Custom configuration
springtour.domain.name=https://springtour.io
springtour.kafka.bootstrap-servers=10.1.1.100,10.1.1.101,10.1.1.102
springtour.kafka.topic.checkout=springtour-hotel-event-checkout
springtour.kafka.topic.reservation=springtour-hotel-event-reservation
springtour.kafka.ack-level=1

## MessageSource Configuration
spring.messages.basename=messages/messages

## logging
logging.file.path=~/logs
```

아래는 클래스 필드에 프로퍼티 데이터를 주입하는 예시이다.
```java
@Value("${springtour.domain.name:springtour.io}")
private String springtourDomain;
```

SpEL(Spring Expression Language) 표현식을 의미하는 기호는 `#` 과 `$` 이다.    
`${}` 는 프로퍼티를 의미하고, `#{}` 은 스프링 빈을 의미한다.

`${springtour.domain.name:springtour.io}` 은 프로퍼티에 springtour.domain.name 키가 정의되어 있지 않으면 기본값인 "springtour.io" 를 대신 사용한다는 의미이다. 

/domain/PropertiesComponent.java
```java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class PropertiesComponent {
  private final List<String> bootStrapServers;
  private final String checkoutTopic;
  private final String reservationTopic;
  private final Integer ackLevel;

  public PropertiesComponent(
      @Value("${springtour.kafka.bootstrap-servers}") List<String> bootStrapServers,
      @Value("${springtour.kafka.topic.checkout}") String checkoutTopic,
      @Value("${springtour.kafka.topic.reservation}") String reservationTopic,
      @Value("${springtour.kafka.ack-level}") Integer ackLevel) {
    this.bootStrapServers = bootStrapServers;
    this.checkoutTopic = checkoutTopic;
    this.reservationTopic = reservationTopic;
    this.ackLevel = ackLevel;

    System.out.println("---" + this.bootStrapServers);  // [10.1.1.100, 10.1.1.101, 10.1.1.102]
    System.out.println("---" + this.checkoutTopic);
    System.out.println("---" + this.reservationTopic);
    System.out.println("---" + this.ackLevel);  // 1
  }
}
```

```shell
-----defaultCharacterEncodingFilter
-----defaultLoggingFilter
--- LoggingFilter init()
--- LoggingFilter init() filterConfig: ApplicationFilterConfig[name=defaultLoggingFilter, filterClass=com.assu.study.chap06.server.LoggingFilter]

---[10.1.1.100, 10.1.1.101, 10.1.1.102]
---springtour-hotel-event-checkout
---springtour-hotel-event-reservation
---1

--- Interceptor addInterceptors()
```

콤마(`,`) 로 구분된 프로퍼티 값은 리스트 형태로 변경되어 저장된다. 이 때 주입 대상의 클래스 타입을 List 로 선언하면 자동으로 변환된다.  
문자열 데이터를 바인딩하는 과정에서도 형변환이 되는데 문자열 `1` 은 Integer 값으로 변경되어 주입된다.


> `@Component` 는 [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/#3-%EC%8A%A4%ED%85%8C%EB%A0%88%EC%98%A4-%ED%83%80%EC%9E%85-spring-bean-%EC%82%AC%EC%9A%A9) 를 참고하세요.


---

## 1.2. `@ConfigurationProperties`, `@ConfigurationPropertiesScan`

스프링 부트 프레임워크는 프로퍼티에 선언된 값들을 좀 더 편리하게 사용하기 위해 `@ConfigurationProperties` 와 `@ConfigurationPropertiesScan` 을 제공한다.

```properties
#spring.main.allow-bean-definition-overriding=true
server.port=18080

## Custom configuration
springtour.domain.name=https://springtour.io
springtour.kafka.bootstrap-servers=10.1.1.100,10.1.1.101,10.1.1.102
springtour.kafka.topic.checkout=springtour-hotel-event-checkout
springtour.kafka.topic.reservation=springtour-hotel-event-reservation
springtour.kafka.ack-level=1

## MessageSource Configuration
spring.messages.basename=messages/messages

## logging
logging.file.path=~/logs
```

spring.kafka 라는 네임 스페이스에 여러 데이터를 정의하고 있는데 **카프카와 관련된 정보들을 하나의 자바 빈 객체로 만들어 관리하면 편리하게 사용**할 수 있다.  
이 네임 스페이스를 기준으로 데이터들을 그룹지어 자바 빈 객체에 주입하는 기능이 바로 `@ConfigurationProperties` 이다.

`@ConfigurationProperties` 애너테이션은 자바 빈 클래스에 정의하고, 애너테이션의 prefix 속성에 네임 스페이스를 설정하면 된다.  
그러면 프레임워크는 네임 스페이스와 자바 빈의 속성명을 결합하여 프로퍼티의 키 이름을 유추하여 값을 주입한다.

/domain/KafkaProperties.java
```java
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ToString
@Getter
@Setter
@ConfigurationProperties(prefix = "springtour.kafka") // springtour.kafka 로 시작하는 모든 키는 KafkaProperties 자바 빈에 주입됨
public class KafkaProperties {
  // 프로퍼티 키 이름에 포함된 하이픈은 카멜 표기법으로 변경
  private List<String> bootStrapServers;
  private Integer ackLevel;
  // . 으로 구분된 프로퍼티 키를 주입하려면 하위 클래스로 구분
  private Topic topic;

  @ToString
  @Getter
  @Setter
  public static class Topic {
    private String checkout;
    private String reservation;
  }
}
```

`@ConfigurationProperties` 를 정의했으면 `@ConfigurationProperties` 가 정의된 자바 빈 클래스를 스캔해야 한다.  

```java
@SpringBootApplication
@ConfigurationPropertiesScan("com.assu.study.chap06")
public class Chap06Application {
  ...
}
```

```java
@RestController
public class HotelRoomController {

  KafkaProperties kafkaProperties;

  public HotelRoomController(KafkaProperties kafkaProperties) {
    this.kafkaProperties = kafkaProperties;
  }

  @GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
  public HotelRoomResponse getHotelRoomByPeriod(
          ClientInfo clientInfo,
          @PathVariable Long hotelId,
          @PathVariable HotelRoomNumber roomNumber,
          @RequestParam(value = "fromDate", required = false) @DateTimeFormat(pattern = "yyyyMMdd") LocalDate fromDate,
          @RequestParam(value = "toDate", required = false) @DateTimeFormat(pattern = "yyyyMMdd") LocalDate toDate
  ) {

    System.out.println("--------" + kafkaProperties.getAckLevel());
    System.out.println("--------" + kafkaProperties.getTopic().getCheckout());
    System.out.println("--------" + kafkaProperties.getTopic().getReservation());
    System.out.println("--------" + kafkaProperties.getBootstrapServers());
  }
}
```

```shell
--- LoggingFilter doFilter: 선처리 작업
--------1
--------springtour-hotel-event-checkout
--------springtour-hotel-event-reservation
--------[10.1.1.100, 10.1.1.101, 10.1.1.102]
--- LoggingFilter doFilter: 후처리 작업
```

---

# 2. Profile 설정

---

## 2.1. Profile 변수값 설정: `spring.profiles.active`

스프링 프로파일 값은 `spring.profiles.active` 시스템 환경 변수 값으로 관리 가능하다.

프로파일 변수값은 크게 두 가지 방법으로 설정 가능하다.
- 애플리케이션을 실행할 때 JVM 파라메터를 사용하여 설정
- `export` 를 사용하여 설정

JVM 파라메터를 추가하려면 `-D` 와 함께 파라메터명과 값을 추가한다.  
파라메터명은 spring.profiles.active 이므로 `java -jar ./application.jar -Dspring.profiles.active=dev` 이런 식으로 추가한다.

리눅스 계열 OS 에서 java 애플리케이션을 실행할 때는 쉘 스크립트를 사용하는데 이 때 `export` 키워드를 사용하여 환경 변수를 정의할 수 있다.

start.sh
```shell
export spring_profiles_active = dev

java -jar ./application.jar
```

---

## 2.2. 프로파일별 application.properties 설정

스프링 부트 애플리케이션에서 사용하는 기본 프로퍼티 파일명은 application.properties 이다.  
스프링 부트 애플리케이션은 profile 명에 따라 `application-[profile명].properties` 와 `application.properties` 를 찾아 로딩한다.  

`application-[profile명].properties` 와 `application.properties` 를 동시에 로딩하는 이유는 `application-[profile명].properties` 의 
프로퍼티 값을 `application.properties` 에 덮어쓰기 때문이다.  

따라서 기본 설정값은 `application.properties` 에 정의하고, `application-[profile명].properties` 에 다시 한번 정의하는 것이 좋다.  
예를 들어 spring.datasource.url 프로퍼티값이 application-dev.properties 에 없다면 application.properties 에 선언된 프로퍼티는 참조한다.

---

## 2.3. `@Profile` 애너테이션과 스프링 빈 설정

`@Profile` 애너테이션을 스프링 빈과 함께 사용하면 프로파일값에 따라 스프링 빈을 생성할 수 있다.  
또는 `@Profile` 애너테이션을 자바 설정 클래스와 함께 사용하면 프로파일 값에 따라 자바 설정 클래스에 포함된 스프링 빈들을 생성할 수 있다.

이를 반대로 생각하면 프로파일 값에 따라 스프링 빈을 생성하지 않을 수도 있고, 하나의 인터페이스를 구현하는 여러 구현체를 스프링 빈으로 생성할 수 있다.

아래 예시를 보면 쉽게 이해가 갈 것이다.

`@Profile` 애너테이션은 클래스 선언부와 메서드 선언부에 사용 가능하다.
 
**자바 설정 클래스에 선언 / dev, stage, prod 환경에서 모두 스프링 빈 생성 예시**
```java
@Profile(value={"dev", "stage", "local"})
@Configuration  // 자바 설정 클래스
public class Test {
  @Bean
  public String testName() {
    return "test";
  }
}
```

`@Configuration` 애너테이션이 설정되어 있으므로 자바 설정 클래스이며, `@Profile` 속성값은 dev, stage, local 이다.  
따라서 애플리케이션에 설정된 프로파일 값이 셋 중 하나라도 일치하면 동작한다.  
즉, active 에 설정된 값이 dev, stage, local 중 하나이면 Test 클래스에 포함된 모든 스프링 빈이 생성된다.  
여기선 String 타입의 testName 빈이 생성된다.

**운영 환경에서만 스프링 빈 생성 예시**
```java
@Bean
@Profile("prod")
public String testName() {
  return "test";
}
```

**운영 환경이 아닐 때만 스프링 빈 생성 예시**
```java
@Bean
@Profile("!prod")
public String testName() {
  return "test";
}
```

`@Profile` 애너테이션을 정의하지 않은 스프링 빈들은 프로파일과 상관없이 모두 생성된다.  
따라서 **환경에 따라 생성할 스프링 빈들만 `@Profile` 애너테이션을 사용**하면 된다.

---

## 2.4. `@Profile` 애너테이션과 인터페이스를 사용한 확장

`@Profile` 은 클래스나 메서드 선언부에 정의할 수 있으므로 `@Bean` 뿐만 아니라 `@Component` 와 같은 스테레오 타입 애너테이션을 사용한 클래스도 `@Profile` 을 사용할 수 있다.

`@Profile` 과 스프링 빈을 결합하면 외부 설정(Profile 값 설정) 만으로 애플리케이션 기능을 자유롭게 설정할 수 있다.

예를 들어 EmailService 인터페이스와 이를 구현한 DummyEmailService, AWSEmailService 클래스가 각각 dev, prod 환경에 동작한다고 하자.

어떤 구현 클래스가 EmailService 인터페이스에 주입될지는 외부 설정이 결정한다. 즉, 프로파일 값을 설정하여 실행하면 애플리케이션은 실행 환경과 목적에 맞게 동작한다.

DummyEmailService 에는 `@Profile("dev")` 를, AWSEmailService 에는 `@Profile("prod")` 를 설정할 때 문제점은 DEV 환경에서 테스트할 때 
실제 AWS SES 서비스를 사용하는 AWSEmailService 기능을 확인할 수 없다는 것이다.

이 때 스프링 프로파일의 기능을 애플리케이션 실행 환경에만 한정하지 말고 애플리케이션 기능 설정까지 확장해보자.

프로파일 값을 dev, prod 로 정의하듯이 이메일 기능을 의미하는 프로파일 값을 email 로 정의하여 이메일 기능을 활성화할 때는 이메일 프로파일 값을 email 로 설정하고, 
기능을 비활성화할 때는 이메일 프로파일 값을 생략한다.

```shell
// 애플리케이션 실행환경은 prod, email 기능 활성화
java -jar ./application.jar -Dspring.profiles.active=prod,email
```

```shell
// 애플리케이션 실행환경은 prod, email 기능 비활성화
java -jar ./application.jar -Dspring.profiles.active=prod
```

프로파일 값에 email 이 설정되어 있으면 AWSEmailService 를 주입하고, email 이 설정되어 있지 않으면 DummyEmailService 를 주입한다.

/domain/email/EmailAddress 
```java
public interface EmailService {
  boolean sendEmail(EmailAddress emailAddress);
}
```

/domain/email/EmailAddress
```java
package com.assu.study.chap06.domain.email;

import lombok.Getter;

import java.util.Objects;

// DTO
@Getter
public class EmailAddress {
  private static final String AT = "@";

  private final String name;
  private final String domainPart;
  private final String localPart;

  public EmailAddress(String name, String domainPart, String localPart) {
    this.name = name;
    this.domainPart = domainPart;
    this.localPart = localPart;
  }

  @Override
  public String toString() {
    StringBuilder sb = new StringBuilder();
    if (Objects.nonNull(name)) {
      sb.append(name).append(" ");
    }
    return sb.append("<").append(localPart).append(AT).append(domainPart).append(">").toString();
  }
}
```

/domain/email/DummyEmailService.java
```java
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("!email")  // 프로파일 중 email 값이 없는 애플리케이션에서는 DummyEmailService 구현체를 스프링 빈으로 생성
public class DummyEmailService implements EmailService {
  @Override
  public boolean sendEmail(EmailAddress emailAddress) {
    System.out.println("dummy email: " + emailAddress.toString());
    return true;
  }
}
```

/domain/email/AWSEmailService.java
```java
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("email")  // 프로파일 중 email 값이 있는 애플리케이션에서는 AwsEmailService 구현체를 스프링 빈으로 생성
public class AWSEmailService implements EmailService {
  @Override
  public boolean sendEmail(EmailAddress emailAddress) {
    System.out.println("aws email: " + emailAddress.toString());
    return true;
  }
}
```

/controller/EmailController.java
```java
@RestController
public class EmailController {
  private final EmailService emailService;

  public EmailController(EmailService emailService) {
    this.emailService = emailService;
  }

  @PostMapping("/hotels/{hotelId}/rooms/{roomNumber}/reservations/{reservationId}/send-email")
  public ResponseEntity<Void> sendEmail(@PathVariable Long hotelId,
                                        @PathVariable String roomNumber,
                                        @PathVariable Long reservationId) {
    emailService.sendEmail(new EmailAddress("Assu", "assu", "google.com"));
    return new ResponseEntity<>(HttpStatus.OK);
  }
}
```

이제 각각 intelliJ 에서 Active Profiles 를 아래와 같이 설정한 후 결과를 확인해보자.
```shell
spring.profile.active=dev,email
spring.profile.active=dev
```

```shell
curl --location --request POST 'http://localhost:18080/hotels/111/rooms/ocean-222/reservations/333/send-email' \
--header 'Accept: application/json'
```

```shell
aws email: Assu <google.com@assu>
dummy email: Assu <google.com@assu>
```

---

## 2.5. Environment 인터페이스

스프링 프레임워크는 실행 중인 애플리케이션의 환경 변수를 관리하려고 Environment 인터페이스를 제공한다.

Environment 에서 관리하는 환경 변수는 크게 두 가지로 나뉠 수 있는데 프로파일을 의미하는 실행 환경과 프로퍼티를 의미하는 설정이다.  
그래서 프로파일에서 설정한 spring.profiles.active 환경 변수값과 application.properties 에 정의된 프로퍼티 값을 조회할 수 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)