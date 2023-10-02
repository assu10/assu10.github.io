---
layout: post
title:  "Spring Boot - Spring bean, Spring bean Container, 의존성"
date:   2023-05-07
categories: dev
tags: springboot msa spring-bean spring-bean-container application-context 
---

이 포스팅에서는 스프링 애플리케이션을 설정하고 비즈니스 로직을 효율적으로 개발할 수 있도록 해주는 Spring bean 의 생성, 사용법, 설정법에 대해 알아본다.  

Spring 프레임워크의 3 가지 핵심 기술은 의존성 주입, 관점 지향 프로그래밍, 서비스 추상화인데 이 중 의존성 주입은 객체 간 결합 정도를 낮추는 유용한 방법이다.
Spring bean 을 선언하고 Spring bean Container 를 사용하여 Spring bean 들 사이에 의존성 주입을 할 수 있는 클래스와 애너테이션에 대해 알아볼 것이다.

- Spring bean 과 Spring bean Container 를 사용하는 방법
- Spring bean 이 왜 의존성 주입과 연관되어 있는가?
- `@Bean` 과 스테레오 타입 애너테이션으로 Spring bean 생성
- Spring bean 의 Scope 와 LifeCycle

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap03) 에 있습니다.

---

**목차**

- [Spring bean 사용](#1-spring-bean-사용)
  - [`@Bean` 애너테이션으로 Spring bean 생성](#11-bean-애너테이션으로-spring-bean-생성)
- [자바 설정](#2-자바-설정)
  - [`@Configuration`](#21-configuration)
  - [`@ComponentScan`](#22-componentscan)
  - [`@Import`](#23-import)
- [스테레오 타입 Spring bean 사용](#3-스테레오-타입-spring-bean-사용)
- [의존성 주입](#4-의존성-주입)
  - [애너테이션 기반의 의존성 주입: `@Autowired`, `@Qualifier`](#41-애너테이션-기반의-의존성-주입--autowired--qualifier)
  - [자바 설정의 의존성 주입](#42-자바-설정의-의존성-주입)
- [ApplicationContext](#5-applicationcontext)
- [Spring bean Scope: `@Scope`](#6-spring-bean-scope-scope)
- [Spring bean LifeCycle 관리](#7-spring-bean-lifecycle-관리)
- [Spring bean 고급 정의](#81-primary)
  - [`@Primary`](#81-primary)
  - [`@Lazy`](#82-lazy)
- [Spring bean, Java bean, DTO, VO](#9-spring-bean-java-bean-dto-vo)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap03

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

	<artifactId>chap03</artifactId>

</project>
```

---


# 1. Spring bean 사용

**Spring bean 은 Spring bean Container 가 관리하는 순수 자바 객체(POJO)** 이다.  

Spring bean Container 는 Spring bean definition 설정을 읽은 후 Spring bean 객체를 생성하고, 서로 의존성 있는 Spring bean 객체들을 주입한다.
이후 애플리케이션 종료 전 관리하고 있던 Spring bean 들의 종료 작업을 실행하는데 이렇게 Spring bean 생성부터 주입, 소멸하는 전체 과정을 Spring bean LifeCycle 이라고 하고, 
**Spring bean Container 는 이 Spring bean LifeCycle 을 관리**한다.

Spring bean Container 는 애플리케이션 실행 시 가장 먼저 실행되기 때문에 모든 Spring bean 의 LifeCycle 을 관리할 수 있다.

Spring bean 은 생성 주체와 정의 방법에 따라 아래와 같이 나뉜다.

- **Spring 프레임워크의 기능을 Spring bean 으로 정의**
  - 개발자의 개입없이 생성
  - 예) Spring bean Container 역할을 하는 ApplicationContext
- **Spring bean Container 가 로딩하는 설정 파일에 정의**
  - 개발자가 Spring 프레임워크 기능을 설정하거나 애플리케이션에서 공통으로 사용하는 Spring bean 설정 시 활용
  - 설정 파일에 `@Bean` 애너테이션을 사용하여 Spring bean 정의
  - > `@Bean` 에너테이션을 사용하여 정의하는 법은 [1.1. `@Bean`](#11-bean-애너테이션으로-spring-bean-생성) 을 참고하세요.
- **Spring bean Container 가 설정된 패키지 경로를 스캔하여 Spring bean 으로 정의되어 생성되는 Spring bean**
  - 개발자가 애플리케이션 로직 구현 시 활용  
  (자바 설정 기반의 `@Bean` 애너테이션을 사용하여 Spring bean 을 정의할 수도 있지만 수많은 클래스들을 모두 그렇게 정의하는 건 비효율적)
  - Spring bean 들은 애너테이션들을 사용하여 정의하며 이를 애너테이션 기반 설정이라고 함
  - > 애너테이션 기반 설정에 대한 내용은 [4.1. 애너테이션 기반의 의존성 주입: `@Autowired`, `@Qualifier`](#41-애너테이션-기반의-의존성-주입--autowired--qualifier) 을 참고하세요.

Spring bean Container 는 이렇게 생성된 Spring bean 들의 의존성을 주입한다.  
> 의존성 주입은 [4. 의존성 주입](#4-의존성-주입) 을 참고하세요.

**Spring bean 은 크게 2 가지 방식으로 정의**할 수 잇다.

- 자바 설정 클래스에서 `@Bean` 에너테이션으로 정의
- 스테레오 타입 애너테이션으로 정의

---

## 1.1. `@Bean` 애너테이션으로 Spring bean 생성

자바 설정 클래스에서 Spring bean 정의 시 `@Bean` 애너테이션을 사용한다.

`@Bean` 애너테이션 코드
```java 
// @Bean 애너테이션을 정의할 수 있는 타깃은 메서드와 다른 애너테이션
@Target({ElementType.METHOD, ElementType.ANNOTATION_TYPE})
// 런타임 시점까지 @Bean 애너테이션이 코드에 존재
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Bean {
    // @Bean 애너테이션은 value or name 속성을 가지며 서로 참조하므로 둘 중 하나만 설정해도 됨, 필수 속성 아님
    @AliasFor("name")
    String[] value() default {};

    @AliasFor("value")
    String[] name() default {};

    boolean autowireCandidate() default true;

    String initMethod() default "";

    String destroyMethod() default "(inferred)";
}
```

**Spring bean 을 정의할 때 필요한 요소는 이름, 클래스 타입, 객체** 이다.  
Spring bean 의 이름값을 설정하지 않으면 `@Bean` 애너테이션이 정의된 메서드명이 Spring bean 이름이 된다.  
Spring bean 의 클래스 타입은 `@Bean` 애너테이션이 정의된 메서드의 리턴 타입이 클래스 타입으로 사용된다.  
Spring bean 의 객체는 `@Bean` 애너테이션이 정의된 메서드가 리턴하는 객체가 된다.

그럼 `@Bean` 애너테이션을 사용하여 Spring bean 을 정의하여 사용하는 코드를 보도록 하자.

/SpringBean01Application.java
```java
package com.assu.study.chap03;

@Slf4j
@SpringBootApplication
public class SpringBean01Application {
    public static void main(String[] args) {
        // SpringApplication.run() 메서드가 리턴하는 ApplicationContext 를 ctxt 변수에 대입
        // ApplicationContext 는 Spring bean Container 이며, SpringBean01Application 클래스를 설정 파일로 로딩함
        // ApplicationContext 는 자바 설정 클래스를 스캔하며, SpringBean01Application 도 자바 설정 클래스이므로 로딩됨
        // 따라서 아래 설정된 Spring bean 을 로딩할 수 있음
        ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean01Application.class, args);

        // Spring bean 객체를 defaultPriceUnit 변수에 저장
        // Spring bean Container 는 이름이 'priceUnit' 이고, 타입이 PriceUnit.class 인 Spring bean 객체를 찾아서 리턴함
        PriceUnit defaultPriceUnit = ctxt.getBean("priceUnit", PriceUnit.class);
        log.info("Price #1: {}", defaultPriceUnit.format(BigDecimal.valueOf(10,2)));    // Price #1: $0.10

        // Spring bean 이름이 wonPriceUnit 이고, 타입이 PriceUnit.class 인 Spring bean 을 찾아 wonPriceUnit 변수에 주입
        PriceUnit wonPriceUnit = ctxt.getBean("wonPriceUnit", PriceUnit.class);
        log.info("Price #1: {}", wonPriceUnit.format(BigDecimal.valueOf(10000)));   // Price #1: ₩10,000
    }

    // Spring bean 이름은 priceUnit
    @Bean(name = "priceUnit")
    public PriceUnit dollarPriceUnit() {    // 이 메서드의 리턴 타입인 PriceUnit 클래스가 Spring bean 의 클래스 타입으로 설정됨
        // 이 메서드가 리턴하는 new PriceUnit(Locale.US) 가 Spring bean 객체로 설정됨
        return new PriceUnit(Locale.US);
    }

    // Spring bean name 이 생략되었으므로 메서드명인 wonPriceUnit 이 Spring bean 이름으로 설정됨
    @Bean
    public PriceUnit wonPriceUnit() {
        return new PriceUnit(Locale.KOREA);
    }
}
```

/domain/PriceUnit.java
```java
package com.assu.study.chap03.domain;

@Slf4j
@Getter
public class PriceUnit {
    private final Locale locale;

    public PriceUnit(Locale locale) {
        if (Objects.isNull(locale)) {
            throw new IllegalArgumentException("locale is null");
        }
        this.locale = locale;
    }

    public String format(BigDecimal price) {
        NumberFormat nf = NumberFormat.getCurrencyInstance(locale);
        return nf.format(Optional.ofNullable(price).orElse(BigDecimal.ZERO));
    }

    public void validate() {
        if (Objects.isNull(locale)) {
            throw new IllegalArgumentException("local is null2");
        }
        log.info("locale is [{}]", locale);
    }
}
```

---

# 2. 자바 설정

애플리케이션에서 공통으로 사용할 기능이 있다면 Spring bean 으로 설정해야 한다. 예를 들면 이메일 발송 기능이 있는 JavaMailSender 객체를 애플리케이션 공통으로 사용한다면
Spring bean 으로 설정하여 공통으로 사용할 수 있다.

이런 설정은 별도의 설정 파일에서 관리하며, 이 포스트에선 자바 설정 방법으로 진행한다. (xml 은 구방식)

ApplicationContext 가 실행될 때 애플리케이션 설정을 위해 가장 먼저 설정 파일을 로딩하고, 이 설정 파일이 자바인 경우 자바 설정이라고 한다.  

자바 설정을 위해 사용되는 4가지 애너테이션이 있는데 `@Bean`, `@Configuration`, `@ComponentScan`, `@Import` 이다. 

`@Bean` 애너테이션을 이용한 Spring bean 정의 방법은 바로 위 [1.1. `@Bean` 애너테이션으로 Spring bean 생성](#11-bean-애너테이션으로-spring-bean-생성) 에 있고, 
나머지 애너테이션에 대해 알아보도록 한다. 그 중 `@Configuration` 은 개발자가 주로 사용하게 될 애너테이션이니 주목해서 보도록 하자.

---

## 2.1. `@Configuration`

**`@Configuration` 애너테이션은 자바 설정 클래스를 정의**하는 데 사용한다.  
일반 클래스와 구분하려고 사용하는 애너테이션으로 Spring bean Container 는 `@Configuration` 애너테이션으로 설정된 클래스들을 메타 정보로 간주하고 로딩한다.

/config/ThreadPoolConfig.java
```java 
@Configuration
public class ThreadPoolConfig {

    @Bean
    public ThreadPoolTaskExecutor threadPoolTaskExecutor() {
        ThreadPoolTaskExecutor taskExecutor = new ThreadPoolTaskExecutor();
        taskExecutor.setCorePoolSize(10);
        taskExecutor.setMaxPoolSize(10);
        taskExecutor.setQueueCapacity(500);

        return taskExecutor;
    }
}
```

만일 `@Configuration` 애너테이션이 없으면 ApplicationContext 가 로딩되지 않기 때문에 `@Bean` 으로 선언된 threadPoolTaskExecutor() Spring bean 설정은 Spring bean 이 되지 않는다.  
(=**`@Configuration` 애너테이션으로 자바 설정 클래스 선언을 해주어야 내부의 `@Bean` 으로 Spring bean 정의 포함 가능**)

Spring 애플리케이션에는 여러 개의 자바 설정 클래스를 만들 수 있다.  
여러 자바 설정 클래스를 스캔하는 `@ComponentScan` 과 자바 설정 클래스를 임포트하는 `@Import` 애너테이션에 대해 알아보자.  
참고로 Spring Boot 는 이런 기능들도 미리 설정해서 제공하기 때문에 어떻게 동작하는지만 이해하면 된다.

---

## 2.2. `@ComponentScan`

`@ComponentScan` 애너테이션은 Spring 프레임워크를 설정하는 애너테이션 중 하나이다.  
`@ComponentScan` 은 설정된 패키지 경로에 포함된 자바 설정 클래스들과 스테레오 타입 애너테이션들이 선언된 클래스들을 스캔한 후 스캔한 클래스에 Spring bean 설정이 있으면
Spring bean 으로 생성한다.

> 스테레오 타입 애너테이션은 [3. 스테레오 타입 Spring bean 사용](#3-스테레오-타입-spring-bean-사용) 을 참고하세요.

`@ComponentScan` 일부
```java
public @interface ComponentScan {
    // value 와 basePackages 는 서로 참조하고 있기 때문에 둘 중 하나만 설정해도 됨
    // 스캔할 패키지 경로를 설정하는 속성, 속성값이 String 임
    @AliasFor("basePackages")
    String[] value() default {};

    @AliasFor("value")
    String[] basePackages() default {};

    // 스캔할 패키지 경로를 입력함, 속성값이 클래스임
    Class<?>[] basePackageClasses() default {};
    ...
}
```

만일 value, basePackages, basePackageClasses 속성들을 설정하지 않으면 `@ComponentScan` 이 정의된 클래스가 위치한 패키지가 기본값이 되어
해당 패키지와 하위 패키지에 포함된 모든 클래스를 스캔한다.

아래는 `@ComponentScan` 사용 예시이며, `@ComponentScan` 는 자바 설정 클래스를 의미하는 `@Configuration` 과 함께 사용해서 정상 동작한다.

/config/ServerConfiguration.java
```java 
package com.assu.study.chap03.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@ComponentScan(basePackages = {"com.assu.study.chap03.config", "com.assu.study.chap03.domain"},
basePackageClasses = {ThreadPoolConfig.class})
public class ServerConfiguration {
    // TODO ...
}
```

사실 Spring Boot 에서는 `@SpringBootApplication` 애너테이션 내부에 `@ComponentScan` 애너테이션이 선언되어 있기 때문에 개발자가 직접 설정할 필요는 없다.  
또한 스캔 경로를 설정하는 속성들이 없기 때문에 `@SpringBootApplication` 이 정의된 클래스의 패키지부터 하위 패키지들까지 스캔한다.  
이러한 이유로 Spring 애플리케이션의 패키지 구조에서 최상위에 `@SpringBootApplication` 이 정의된 메인 클래스를 생성하는 것이 관례이다.

---

## 2.3. `@Import`

`@Import` 도 Spring 프레임워크를 설정하는 애너테이션이다. 

```java
package com.assu.study.chap03.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

@Configuration
@Import(value = {ThreadPoolConfig.class, ServerConfig.class})
public class ServerConfiguration {
    // TODO ...
}
```

`@ComponentScan` 과 차이점이 있다면 `@ComponentScan` 은 패키지 경로를 스캔하는 반면 `@Import` 는 대상 자바 설정 클래스들을 명시적으로 지정한다는 점이다.
자바 설정 클래스를 추가할 때마다 직접 `@Import` 정의를 수정하는 것보다는 `@ComponentScan` 을 사용하는 것이 더 편리하다. 그리고 이미 `@SpringBootApplication` 내부에
`@ComponentScan` 이 정의되어 있으므로 개발자는 해당 애너테이션을 사용할 일이 거의 없다.

---

# 3. 스테레오 타입 Spring bean 사용

의존성 주입이나 Spring 프레임워크에서 제공하는 기능을 사용하려면 Spring bean 으로 등록해야 한다.  
`@Bean` 애너테이션으로 Spring bean 을 정의할 수도 있지만 수많은 클래스를 자바 설정을 통해 하나씩 정의하여 관리하는 것은 어려운 일이다.

애플리케이션 개발 작업 시 애플리케이션 설정 영역과 비즈니스 로직 영역, 이렇게 두 가지로 용도를 나누어 각각 다른 방식으로 Spring bean 을 정의한다.

- **애플리케이션 설정 시**
  - 자바 설정을 이용한 `@Bean` 사용 (=자바 설정 방식)
- **비즈니스 로직 개발 시**
  - 스테레오 타입 애너테이션 사용 (=애너테이션 기반 설정)

스테레오 타입 애너테이션으로 정의된 클래스들은 `@ComponentScan` 으로 스캔되어 Spring bean 으로 생성된다.

스테레오 애너테이션의 종류는 아래와 같다.

- `@Component`
  - 클래스를 Spring bean 으로 정의하는 가장 일반적인 애너테이션
  - 애플리케이션 내부에서 공통으로 사용하는 기능들을 정의할 때 사용 (타서비스의 REST-API 를 호출하는 클래스 혹은 암호화 모듈같은 공통 로직)
  - 다른 스테레오 타입 애너테이션들은 `@Component` 파생되었으며, 클래스의 목적에 따라 적절한 애너테이션 선택해서 사용하면 됨
- `@Controller`
  - 사용자의 요청 메시지를 검증하는 로직도 포함
- `@Service`
  - 트랜잭션 단위로 분리된 메서드를 포함하는 클래스에 사용
- `@Repository`

위 애너테이션들은 기능은 모두 같지만 클래스 목적에 따라 명확하게 정의해서 사용하기 위해 분리해서 사용한다.

---

Spring bean 정의 시 이름, 클래스 타입, 객체가 필요한 것처럼 스테레오 타입 애너테이션들도 `@Bean` 처럼 3 가지 정보가 필요하다.

아래는 `@Component` 스테레오 타입 애너테이션을 사용하여 Spring bean 을 정의하고 사용하는 예시이다.

/domain/format/Formatter.java
```java 
public interface Formatter<T> {
    // 제네릭 T 를 인자로 받아 인수를 적절한 형태로 포맷팅하는 메서드
    String of(T target);
}
```

/domain/format/LocalDateTimeFormatter.java
```java 
package com.assu.study.chap03.domain.format;

import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Optional;

@Component  // Formatter 인터페이스를 구현한 LocalDateTimeFormatter 클래스를 Spring bean 으로 정의
public class LocalDateTimeFormatter implements Formatter<LocalDateTime> {

    private final DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    @Override
    public String of(LocalDateTime target) {
        return Optional.ofNullable(target).map(formatter::format).orElse(null);
    }
}
```

`@Component` 의 value 속성에 Spring bean 이름을 설정하지 않으면 클래스의 이름이 Spring bean 이름이 되며 이 때 클래스 이름의 첫 글자는 소문자로 변경된다.

```javascript
@Component(value = "test")
``` 

SpringBean02Application.java
```java 
package com.assu.study.chap03;

import com.assu.study.chap03.domain.format.Formatter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.time.LocalDateTime;

@Slf4j
@SpringBootApplication
public class SpringBean02Application {
    public static void main(String[] args) {
        ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean02Application.class, args);

        // Spring bean 이름이 localDateTimeFormatter, 클래스 타입은 Formatter.class 인 Spring bean 을 받아서 Formatter.class 타입의 객체 리턴
        // Formatter.class 대신 자식 클래스인 LocalDateTimeFormatter.class 를 넣어도 됨
        Formatter<LocalDateTime> formatter = ctxt.getBean("localDateTimeFormatter", Formatter.class);
        String date = formatter.of(LocalDateTime.of(2023,05,9,23,59,59));

        log.info("date: {}", date); // date: 2023-05-09T23:59:59

        ctxt.close();
    }
}
```

---

# 4. 의존성 주입

위에서 Spring bean 을 정의하고 사용할 때 ApplicationContext 의 getBean() 메서드를 이용하여 Spring bean 객체를 변수에 넣어 실행했다.
하지만 이런 식으로 개발하는 것은 매우 힘들기 때문에 Spring 프레임워크는 의존성 주입 기능을 제공한다.

의존성 주입은 아래처럼 외부에서 객체를 생성하여 대상 객체에 넣어주는 것을 의미한다. 

```java 
public class NotificationService {
  private Sender messageSender;
  
  // NotificationService 객체 생성 시 외부에서 Sender 객체 생성 후 NotificationService 생성자를 통해 주입
  public NotificationService(Sender messageSender) {
    this.messageSender = messageSender;
  }
  
  public boolean sendNotification(User user, String message) {
    return messageSender.send(user.getPhoneNumber(), message);
  }
}
```

의존성 주입은 낮은 결합도와 높은 응집도를 설계하는데 큰 도움이 된다.  
또한 좀 더 유연한 프로그래밍을 위해 클래스보다는 **인터페이스나 추상 클래스와 의존 관계를 맺는 것이 유연한 설계**이다.

![의존성](/assets/img/dev/2023/0507/dependency.png)

SmsSender 에 추가 기능이 생겨도 NotificationService 코드의 수정 사항은 없다.  
새로운 방식의 메시지를 보내야 하면 Sender 인터페이스를 구현하는 다른 구현 클래스를 작성한 후 그 구현 클래스 객체를 NotificationService 생성자에 주입만 하면 된다.  

그럼 자바 설정과 애너테이션 기반 설정에서 ApplicationContext 의 getBean() 메서드없이 의존성을 주입하는 방법에 대해 알아본다.

---

## 4.1. 애너테이션 기반의 의존성 주입: `@Autowired`, `@Qualifier`

애너테이션 기반 의존성 주입은 의존성 대상 객체를 주입받을 클래스 내부의 객체를 저장할 변수에 **`@Autowired` 와 `@Qualifier` 애터네이션을 조합하여 정의**하면 된다.

Spring bean Container 는 두 애너테이션의 속성 값을 파악하여 적절한 의존성 대상 객체를 찾아 주입한다. 즉, 의존성 주입 시 의존성을 주입받을 객체와 의존성 대상 객체 모두 Spring bean 객체이어야 한다.


`@Autowired` 정의
```java
@Target({ElementType.CONSTRUCTOR, ElementType.METHOD, ElementType.PARAMETER, ElementType.FIELD, ElementType.ANNOTATION_TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Autowired {
    boolean required() default true;
}
```

`@Autowired` 는 생성자, 메서드, 파라메터, 필드, 애너테이션에 정의 가능하다.  
`@Autowired` 는 의존성을 주입받는 곳에 표시한다.


`@Qualifier` 정의
```java 
@Target({ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER, ElementType.TYPE, ElementType.ANNOTATION_TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
@Documented
public @interface Qualifier {
    String value() default "";
}
```

`@Qualifier` 는 메서드, 파라메터, 필드, 애너테이션에 정의 가능하다. value 속성값은 Spring bean 의 이름이 된다.  
`@Qualifier` 는 의존성을 주입할 Spring bean 이름을 정의한다. 
**클래스 타입은 같지만 이름이 다른 여러 Spring bean 이 있을 경우 이 중 정의된 이름의 Spring bean 을 주입받기 위해 사용**한다.  
(`@Qualifier` 애너테이션이 아닌 [`@Primary`](#81-primary) 로도 처리 가능)  
따라서 이런 경우가 아니라면 `@Qualifier` 는 생략 가능하다.

/service/OrderPrinter.java
```java 
package com.assu.study.chap03.service;

import com.assu.study.chap03.domain.format.Formatter;
import com.assu.study.chap03.lifecycle.ProductOrder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.OutputStream;
import java.util.StringJoiner;

@Slf4j
@Service    // 의존성 주입을 위해 스테레오 타입 애너테이션으로 Spring bean 으로 정의
public class OrderPrinter implements Printer<ProductOrder> {

    // 1. 필드 주입 (추천하지 않음)
    // 의존성 주입 대상인 Formatter 도 Spring bean 으로 정의되어 있어야 함
    @Autowired
    @Qualifier("localDateTimeFormatter")    // 주입된 Spring bean 이름을 localDateTimeFormatter 로 설정
    private Formatter formatter01;


    // 2. Setter 메서드 주입 (추천하지 않음)
    private Formatter formatter02;

    @Autowired
    public void setFormatter02(@Qualifier("localDateTimeFormatter") Formatter formatter) {
        this.formatter02 = formatter;
    }

    // 3. 생성자 주입 (추천)
    private Formatter formatter03;

    @Autowired
    public OrderPrinter(@Qualifier("localDateTimeFormatter") Formatter formatter) {
        this.formatter03 = formatter;
    }

    @Override
    public void print(OutputStream out, ProductOrder productOrder) throws IOException {
        StringJoiner joiner = new StringJoiner("\r\n");
        joiner.add(productOrder.getBuyerName());
        joiner.add(productOrder.getOrderAmount().toPlainString());
        joiner.add(formatter03.of(productOrder.getOrderAt()));

        out.write(joiner.toString().getBytes());
    }
}
```

> 필드 주입을 추천하지 않는 이유는 `Field injection is not recommended ` 로 찾아보세요.

/service/Printer.java
```java 
package com.assu.study.chap03.service;

import java.io.IOException;
import java.io.OutputStream;

public interface Printer<T> {
    void print(OutputStream out, T t) throws IOException;
}
```

/lifecycle/ProductOrder.java
```java 
package com.assu.study.chap03.lifecycle;

import lombok.Getter;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
public class ProductOrder {
    private BigDecimal orderAmount;
    private LocalDateTime orderAt;
    private String buyerName;

    public ProductOrder(BigDecimal orderAmount, LocalDateTime orderAt, String buyerName) {
        if (orderAmount == null || orderAt == null || StringUtils.isEmpty(buyerName)) {
            throw new IllegalArgumentException("args is null~");
        }

        this.orderAmount = orderAmount;
        this.orderAt = orderAt;
        this.buyerName = buyerName;
    }
}
```

---

의존성 주입 시 `@Autowired` 애너테이션을 사용해야 하지만 생성자 주입 방식을 사용할 때 아래와 같은 경우는 `@Autowired` 애너테이션을 생략할 수 있다.

- 스테레오 타입 애너테이션이 정의된 클래스에 public 생성자가 하나만 있을 경우 `@Autowired` 가 없어도 생성자 주입 방식으로 의존성 주입 실행 가능

아래는 `@Autowired` 가 생략된 생성자 주입 예시이다.

/service/OrderPrinter2
```java
package com.assu.study.chap03.service;

import com.assu.study.chap03.domain.format.Formatter;
import com.assu.study.chap03.lifecycle.ProductOrder;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.OutputStream;
import java.util.StringJoiner;

@Service
public class OrderPrinter2 implements Printer<ProductOrder> {
    private Formatter formatter;

    // 해당 클래스에 public 생성자가 하나만 있으므로 @Autowired 가 없어도 의존성 주입
    public OrderPrinter2(@Qualifier("localDateTimeFormatter") Formatter formatter) {
        this.formatter = formatter;
    }

    @Override
    public void print(OutputStream out, ProductOrder productOrder) throws IOException {
        StringJoiner joiner = new StringJoiner("\r\n");
        joiner.add(productOrder.getBuyerName());
        joiner.add(productOrder.getOrderAmount().toPlainString());
        joiner.add(formatter.of(productOrder.getOrderAt()));

        out.write(joiner.toString().getBytes());
    }
}
```

필드 주입이나 Setter 메서드 주입과 달리 **생성자 주입을 사용하게 되면 테스트 케이스 작성 시 mock 객체 주입이 편리하다는 큰 장점**이 있다.

SpringBean03Application.java
```java
package com.assu.study.chap03;

import com.assu.study.chap03.lifecycle.ProductOrder;
import com.assu.study.chap03.service.OrderPrinter2;
import com.assu.study.chap03.service.Printer;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Slf4j
@SpringBootApplication
public class SpringBean03Application {
  public static void main(String[] args) {
    ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean03Application.class, args);

    Printer printer = ctxt.getBean(OrderPrinter2.class);
    ProductOrder order = new ProductOrder(BigDecimal.valueOf(1000), LocalDateTime.now(), "assu");

    try (OutputStream os = System.out){
      printer.print(os, order);
//            assu
//            1000
//            2023-05-06T14:14:44
    } catch (IOException e) {
      log.error("error: ", e);
    }

    ctxt.close();
  }
}
```


---

## 4.2. 자바 설정의 의존성 주입

자바 설정에서는 대부분 **Spring bean 사이의 참조** 를 이용하여 의존성 주입 설정을 한다.

Spring bean 사이의 참조 는 한 개의 설정 클래스 안에서 정의된 Spring bean 들끼리 의존성을 주입하는 경우 `@Bean` 애너테이션이 선언된 메서드를 그대로 사용하는 것을 말한다.

아래는 같은 자바 설정 클래스 안에서 정의된 Spring bean 끼리 Spring bean 사이의 참조를 이용하여 의존성을 주입하는 예시이다.

/config/ServerConfig.java
```java
package com.assu.study.chap03.config;

import com.assu.study.chap03.domain.format.DateFormatter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration  // 자바 설정 클래스임, 따라서 내부에 @Bean Spring bean 정의 가능
public class ServerConfig {
    @Bean   // String 타입이고, 이름이 'datePattern' 인 Spring bean 정의, 날짜 패턴을 의미하는 문자열 객체 리턴 
    public String datePattern() {
        return "yyyy-MM-dd'T'HH:mm:ss.XXX";
    }

    @Bean   // DateFormatter 타입이고 이름이 'defaultDateFormatter` 인 Spring bean 정의
    public DateFormatter defaultDateFormatter() {
        // datePattern 에 의존성이 있음
        // datePattern() 메서드를 바로 사용하면 Spring bean 참조를 통해 Spring bean 주입이 됨 
        return new DateFormatter(datePattern());
    }
}
```

/domain/format/DateFormatter.java
```java
package com.assu.study.chap03.domain.format;

import org.springframework.util.StringUtils;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

public class DateFormatter implements Formatter<Date> { // Formatter 인터페이스 구현
  private SimpleDateFormat sdf;

  public DateFormatter(String pattern) {
    if (StringUtils.isEmpty(pattern)) {
      throw new IllegalArgumentException("pattern is null.");
    }

    this.sdf = new SimpleDateFormat(pattern);
  }

  @Override
  public String of(Date target) {
    return sdf.format(target);
  }

  public Date parse(String dateString) throws ParseException {
    return sdf.parse(dateString);
  }
}
```

---

자바 설정을 하는 경우 하나의 애플리케이션에 여러 개의 자바 설정 클래스가 있을 수 있고 이 때는 `@ComponentScan` 이나 `@Import` 를 사용하면 된다.

아래는 다른 자바 설정 클래스에 정의된 Spring bean 을 참조하는 예시이다.

/config/DividePatternConfig.java
```java
package com.assu.study.chap03.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration  // 자바 설정 파일 선언
public class DividePatternConfig {
    @Bean   // String 타입이고, 이름이 localDatePattern 인 Spring bean 선언
    public String localDatePattern() {
        return "yyyy-MM-dd'T'HH:mm:ss";
    }
}
```

---

# 5. ApplicationContext

ApplicationContext 는 인터페이스이고 다양한 구현 클래스가 기본으로 제공된다.

예를 들어 Spring bean Container 기능은 BeanFactory 인터페이스에 정의되고 있고, ApplicationContext 은 BeanFactory 인터페이스를 상속한다. 
그래서 ApplicationContext 도 Spring bean Container 의 기능을 제공한다.

ApplicationContext 는 이 외에도 여러 인터페이스를 상속받기 때문에 여러 가지 다른 기능을 제공하기 때문에 대부분 ApplicationContext 를 기본 Spring bean Container 로 사용한다.

ApplicationContext
```java
public interface ApplicationContext extends 
        EnvironmentCapable,     // 환경 변수를 추상화한 Environment 객체 제공 (환경 변수 관리)
        ListableBeanFactory,    // Bean Container 인 BeanFactory 상속받음
        HierarchicalBeanFactory, 
        MessageSource,  // 국제화(i18n) 메시지 처리
        ApplicationEventPublisher,  // 이벤트 생성 (이벤트 기반 프로그래밍)
        ResourcePatternResolver // 패턴을 이용해서 Resource 다룰 수 있음 (리소스 관리)
{
```

---

# 6. Spring bean Scope: `@Scope`

모든 Spring bean 객체는 ApplicationContext 로 생성되고 소멸되는데 그 기간을 Spring bean Scope 라고 한다.

Spring 프레임워크는 6 개의 Scope 를 제공하며, 이 Scope 설정에 따라 Spring bean 이 생성되는 시점과 소멸되는 시점이 결정된다.

- `singleton`
  - default 값 (별도의 Scope 설정을 하지 않으면 기본 설정은 singleton)
  - Spring bean Container 에서 대상 Spring bean 을 하나만 생성하고, 하나의 bean 객체를 여러 곳에 의존성 주입함
- `prototype`
  - Spring bean Container 에서 대상 Spring bean 을 여러 bean 객체를 생성함
  - 의존성 주입을 할 때마다 새로운 객체를 생성하여 주입
- `request`
  - 웹 기능 한정 Scope
  - Spring bean Container 는 HTTP 요청을 처리할 때마다 새로운 객체 생성
  - `@RequestScope` 애너테이션과 함께 사용하여 정의
  - 예) @RequestScope, @Scope("request")
- `session`
  - 웹 기능 한정 Scope
  - HTTP Session 과 대응하는 새로운 객체 생성
  - `@SessionScope` 애너테이션과 함께 사용하여 정의
  - 예) @SessionScope, @Scope("session")
- `application`
  - 웹 기능 한정 Scope
  - Servlet Context 와 대응하는 새로운 객체 생성
  - `@ApplicationScope` 애너테이션과 함께 사용하여 정의
  - 예) @ApplicationScope, @Scope("application")
- `websocket`
  - 웹 기능 한정 Scope
  - Web Socket Session 과 대응하는 새로운 객체 생성
  - 예) @Scope("websocket")

> 대부분 singleton Scope 를 사용하므로 `@Scope` 를 사용하는 일은 드물다.

---

아래는 스레드에 안전하지 않은 코드를 singleton Scope 로 Spring bean 설정 후 멀티 스레드에서 실행해서 문제가 발생하는 예시이다.

/domain/format/DateFormatter.java
```java
package com.assu.study.chap03.domain.format;

import org.springframework.util.StringUtils;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

public class DateFormatter implements Formatter<Date> { // Formatter 인터페이스 구현
    
    // SimpleDateFormat 은 멀티 스레드에 안전하지 않으므로 클래스 속성으로 사용하면 안되는 대표적인 클래스임
    private SimpleDateFormat sdf;

    public DateFormatter(String pattern) {
        if (StringUtils.isEmpty(pattern)) {
            throw new IllegalArgumentException("pattern is null.");
        }

        this.sdf = new SimpleDateFormat(pattern);
    }

    @Override
    public String of(Date target) {
        return sdf.format(target);
    }

    // 클래스 변수인 SimpleDateFormat sdf 의 parse() 를 실행하므로 멀티 스레드 환경에 안전하지 않음
    public Date parse(String dateString) throws ParseException {
        return sdf.parse(dateString);
    }
}
```

SpringBean05Application.java
```java
package com.assu.study.chap03;

import com.assu.study.chap03.domain.format.DateFormatter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.TimeUnit;

@Slf4j
@SpringBootApplication
public class SpringBean05Application {
    public static void main(String[] args) throws InterruptedException {

        ConfigurableApplicationContext applicationContext = SpringApplication.run(SpringBean05Application.class, args);

        // ThreadPoolConfig.java 설정에 따라 스레드 개수는 10개, 큐 크기는 500이다.
        ThreadPoolTaskExecutor taskExecutor = applicationContext.getBean(ThreadPoolTaskExecutor.class);

        final String dateString = "2023-05-05T23:59:59.-08:00";
        for (int i=0; i<100; i++) {
            taskExecutor.submit(() -> {
                try {
                    // ThreadPoolTaskExecutor 에 의해 실행되는 스레드 내부에서 singletonDateFormatter Spring bean 을 ApplicationContext 로부터 가져옴
                    // 따라서 멀티스레드로 동작함
                    DateFormatter formatter = applicationContext.getBean("singletonDateFormatter", DateFormatter.class);

                    // parse() 가 멀티 스레드에 안전하다면 출력되는 모든 값은 동일한 날짜가 출력될 것임
                    log.info("Date: {}, hashCode: {}", formatter.parse(dateString), formatter.hashCode());

                } catch(Exception e) {
                    log.error("error to parse", e);
                }
            });
        }
        TimeUnit.SECONDS.sleep(5);
        applicationContext.close();
    }

    // 이름이 singletonDateFormatter, 타입이 DateFormatter 인 Spring bean 설정
    // Scope 는 기본값인 singleton
    // 따라서 여러 곳에 의존성 주입되어도 동일한 하나의 Spring bean 임
    @Bean
    public DateFormatter singletonDateFormatter() {
        return new DateFormatter("yyyy-MM-dd'T'HH:mm:ss");
    }
}
```

실행 결과는 아래와 같다.

```shell
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 541189335
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 541189335
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 541189335
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 541189335
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:00 KST 2023, hashCode: 541189335
∂c.a.s.chap03.SpringBean05Application     : error to parse

java.lang.NumberFormatException: For input string: "E592"
	at java.base/jdk.internal.math.FloatingDecimal.readJavaFormatString(FloatingDecimal.java:2054) ~[na:na]
	at java.base/jdk.internal.math.FloatingDecimal.parseDouble(FloatingDecimal.java:110) ~[na:na]
	at java.base/java.lang.Double.parseDouble(Double.java:651) ~[na:na]
	at java.base/java.text.DigitList.getDouble(DigitList.java:169) ~[na:na]
	at java.base/java.text.DecimalFormat.parse(DecimalFormat.java:2202) ~[na:na]
	at java.base/java.text.SimpleDateFormat.subParse(SimpleDateFormat.java:1937) ~[na:na]
	at java.base/java.text.SimpleDateFormat.parse(SimpleDateFormat.java:1545) ~[na:na]
	at java.base/java.text.DateFormat.parse(DateFormat.java:397) ~[na:na]
	at com.assu.study.chap03.domain.format.DateFormatter.parse(DateFormatter.java:29) ~[classes/:na]
	at com.assu.study.chap03.SpringBean05Application.lambda$main$0(SpringBean05Application.java:32) ~[classes/:na]
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539) ~[na:na]
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264) ~[na:na]
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136) ~[na:na]
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635) ~[na:na]
	at java.base/java.lang.Thread.run(Thread.java:833) ~[na:na]
```

singletonDateFormatter 객체의 해시 코드 값이 항상 일정한 것을 볼 수 있다. 이는 멀티 스레드 환경에서 getBean() 메서드를 사용하여 Spring bean 을 가져와서 
formatter 변수에 주입해도 Spring bean 객체는 변함없이 하나임을 의미한다.

이렇게 오류가 발생하는 이유는 DateFormatter.java 가 의존하는 SimpleDateFormatter 가 멀티 스레드에 안전하지 않은 클래스이기 때문이다.  

이럴 때는 아래 3가지 방법 중 하나를 적용하여 해결 가능하다.

- DateFormatter 클래스의 SimpleDateFormatter sdf 를 클래스 변수에서 제거하고 parse() 내부에서 new 키워드를 사용하도록 리팩터링  
parse() 메서드가 호출될 때마다 매번 SimpleDateFormatter 객체를 생성하므로 멀티 스레드에 안전해짐
- SimpleDateFormatter 가 아닌 스레드에 안전한 DateTimeFormatter 를 클래스 변수로 사용
- DateFormatter Spring bean 의 Scope 를 `prototype` 으로 변경하여 getBean() 를 호출할 때마다 DateFormatter 객체가 새로 생성되도록 함

3번째 방법으로 적용 후 실행 시 정상 동작하는 것을 확인할 수 있다.
```java
@Bean
@Scope("prototype")
public DateFormatter singletonDateFormatter() {
    return new DateFormatter("yyyy-MM-dd'T'HH:mm:ss");
}
```

```shell
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 1061053455
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 997304909
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 971515891
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 378089175
∂c.a.s.chap03.SpringBean05Application     : Date: Fri May 05 23:59:59 KST 2023, hashCode: 561895882
```

---

# 7. Spring bean LifeCycle 관리

Spring bean 을 생성/소멸하는 과정에서 개발자가 작성한 코드를 특정 시점에 호출할 수 있는데 이를 callback 함수라고 한다. 
Spring bean 을 생성/소멸하는 과정에서 호출되는 callback 함수들을 지정함으로써 Spring bean LifeCycle 에 개발자가 관여할 수 있다.

개발자가 Spring bean LifeCycle 에 관여해야 하는 이유는 여러 가지가 있겠지만 스레드 풀의 한 종류인 ThreadPoolTaskExecutor 클래스를 Spring bean 으로 정의하는 경우를 예로 보자.

스레드 풀이므로 여러 스레드를 생성하는 비용이 크기 때문에 애플리케이션 런타임 도중에 생성하는 것보다 애플리케이션 실행 전에 미리 생성하는 것이 유리하다.

Spring bean 은 Spring bean Container 로 생성되므로 애플리케이션이 시작 가능한 상태가 되기 전에 스레드 풀은 초기화되어야 하고, 애플리케이션이 종료되기 전에
작업 중인 스레드 풀이 있다면 작업이 끝날 때까지 정리하는 작업이 필요하다.

이 때 개발자가 스레드 풀을 초기화하고 정리하는 코드를 각각 함수로 만들어서 Spring bean LifeCycle 에 실행하면 된다.

**Spring bean LifeCycle 에 callback 을 실행하는 방법**은 인터페이스의 추상 메서드를 구현하거나 애너테이션으로 callback 함수를 지정하는 방법, 두 가지가 있다.

- 인터페이스의 추상 메서드 구현
  - BeanPostProcessor 인터페이스의 **postProcessBeforeInitialization()**, **postProcessAfterInitialization()** 추상 메서드
    - BeanPostProcessor 의 2개의 추상 메서드는 애플리케이션 전체 Spring bean 에 모두 일괄적으로 적용됨 (나머지는 각각의 Spring bean 에만 적용)
    - 적용방법은 BeanPostProcessor 를 구현한 구현 클래스를 `@Bean` 이나 `@Component` 애너테이션을 사용하여 Spring bean 으로 정의하면 됨
  - InitializingBean 인터페이스의 **afterPropertiesSet()** 추상 메서드
  - DisposableBean 인터페이스의 **destroy()** 추상 메서드
- 사용자가 직접 선언한 callback 함수 지정
  - `@PostConstruct`, `@PreDestroy` 를 사용자가 만든 함수에 정의
  - `@Bean` 애너테이션의 **initMethod**, **destroyMethod** 속성에 사용자가 만든 함수 이름 정의

`@Bean` 을 사용한 Spring bean 은 initMethod 속성을 사용하고, 스테레오 타입 애너테이션을 사용한 Spring bean 은 `@PostConstruct` 사용한다.  
InitializingBean 은 둘 다 사용 가능하다.

![Spring bean LifeCycle 과 callback 메서드](/assets/img/dev/2023/0507/lifecycle.png)


아래는 각각의 callback 함수를 사용하는 예시이다. 위 그림과 결과를 비교해서 보자.

SpringBean06Application.java
```java
package com.assu.study.chap03;

import com.assu.study.chap03.lifecycle.LifeCycleComponent;
import com.assu.study.chap03.lifecycle.PrintableBeanPostProcessor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;

@Slf4j
@SpringBootApplication
public class SpringBean06Application {
    public static void main(String[] args) {
        ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean06Application.class, args);
        ctxt.close();
    }

    // Spring bean 생성 후 customInit() 실행, 애플리케이션 종류 전 customClear() 실행
    @Bean(initMethod = "customInit", destroyMethod = "customClear")
    public LifeCycleComponent lifeCycleComponent() {
        return new LifeCycleComponent();
    }

    @Bean   // PrintableBeanPostProcessor 을 Spring bean 으로 사용
    public BeanPostProcessor beanPostProcessor() {
        return new PrintableBeanPostProcessor();
    }
}
```

/domain/lifecycle/LifeCycleComponent.java
```java
package com.assu.study.chap03.lifecycle;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.DisposableBean;
import org.springframework.beans.factory.InitializingBean;

@Slf4j
public class LifeCycleComponent implements InitializingBean, DisposableBean {

    // Spring bean 생성 후 실행
    @Override
    public void afterPropertiesSet() throws Exception {
        log.info("[LifeCycleComponent] - afterPropertiesSet() from InitializingBean");
    }

    // 애플리케이션 종료 전 실행
    @Override
    public void destroy() throws Exception {
        log.info("[LifeCycleComponent] - destroy() from DisposableBean:");
    }

    public void customInit() {
        log.info("[LifeCycleComponent] - customInit()");
    }

    public void customClear() {
        log.info("[LifeCycleComponent] - customClear()");
    }
}
```

/domain/lifecycle/PrintableBeanPostProcessor.java
```java
package com.assu.study.chap03.lifecycle;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanPostProcessor;

@Slf4j
public class PrintableBeanPostProcessor implements BeanPostProcessor {
    // Spring bean 생성 후 실행
    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        if ("lifeCycleComponent".equals(beanName)) {
            log.info("[PrintableBeanPostProcessor] - Called postProcessBeforeInitialization() from BeanPostProcessor for : {}", beanName);
        }
        return bean;
    }

    // Spring bean 생성 후 실행
    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        if ("lifeCycleComponent".equals(beanName)) {
            log.info("[PrintableBeanPostProcessor] - Called postProcessAfterInitialization() from BeanPostProcessor for : {}", beanName);
        }
        return bean;
    }
}
```

실행 결과는 아래와 같다.
```shell
trationDelegate$BeanPostProcessorChecker : Bean 'springBean06Application' of type [com.assu.study.chap03.SpringBean06Application$$SpringCGLIB$$0] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
c.a.s.c.l.PrintableBeanPostProcessor     : [PrintableBeanPostProcessor] - Called postProcessBeforeInitialization() from BeanPostProcessor for : lifeCycleComponent
c.a.s.c.lifecycle.LifeCycleComponent     : [LifeCycleComponent] - afterPropertiesSet() from InitializingBean
c.a.s.c.lifecycle.LifeCycleComponent     : [LifeCycleComponent] - customInit()
c.a.s.c.l.PrintableBeanPostProcessor     : [PrintableBeanPostProcessor] - Called postProcessAfterInitialization() from BeanPostProcessor for : lifeCycleComponent
o.s.b.d.a.OptionalLiveReloadServer       : LiveReload server is running on port 35729
c.a.s.chap03.SpringBean06Application     : Started SpringBean06Application in 0.776 seconds (process running for 1.336)
c.a.s.c.lifecycle.LifeCycleComponent     : [LifeCycleComponent] - destroy() from DisposableBean:
c.a.s.c.lifecycle.LifeCycleComponent     : [LifeCycleComponent] - customClear()
```


---

# 8. Spring bean 고급 정의

## 8.1. `@Primary`

클래스 타입이 같은 여러 Spring bean 이 있는 경우 Spring 프레임워크는 `NoUniqueBeanDefinitionExeption` 를 내뱉는다.

`@Autowired` 와 함께 `@Qualifier` 를 사용하여 이 예외를 피할 수 있지만 여기서는 `@Primary` 를 사용하여 같은 클래스 타입인 여러 Spring bean 중
`@Primary` 애너테이션이 선언된 Spring bean 이 의존성 주입되도록 하는 방법에 대해 알아본다.

개발을 하다보면 Spring Boot 프레임워크에서 자동 설정한 Spring bean 중 일부를 변경해야할 때가 있는데 이 때 `@Primary` 를 사용하면 된다.

SpringBean07Application.java
```java
package com.assu.study.chap03;

import com.assu.study.chap03.lifecycle.PriceUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;

import java.util.Locale;

@Slf4j
@SpringBootApplication
public class SpringBean07Application {
    public static void main(String[] args) {
        ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean07Application.class, args);

        // Spring bean 이름을 따로 지정하지 않고 클래스 타입으로만 매칭되는 Spring bean 을 가져옴
        PriceUnit priceUnit = ctxt.getBean(PriceUnit.class);
        log.info("Locale in PriceUnit: {}", priceUnit.getLocale().toString());

        ctxt.close();
    }

    @Bean
    // 클래스 타입이 PriceUnit 이고, 이름이 primaryPriceUnit 인 Spring bean 정의
    public PriceUnit primaryPriceUnit() {
        return new PriceUnit(Locale.US);
    }

    @Bean
    // 클래스 타입이 PriceUnit 이고, 이름이 secondPriceUnit 인 Spring bean 정의
    public PriceUnit secondaryPriceUnit() {
        return new PriceUnit(Locale.KOREA);
    }
}
```

/domain/lifecycle/PriceUnit.java
```java
package com.assu.study.chap03.lifecycle;

import lombok.Getter;
import lombok.extern.slf4j.Slf4j;

import java.math.BigDecimal;
import java.text.NumberFormat;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;

@Slf4j
@Getter
public class PriceUnit {
    private final Locale locale;

    public PriceUnit(Locale locale) {
        if (Objects.isNull(locale)) {
            throw new IllegalArgumentException("locale is null");
        }
        this.locale = locale;
    }

    public String format(BigDecimal price) {
        NumberFormat nf = NumberFormat.getCurrencyInstance(locale);
        return nf.format(Optional.ofNullable(price).orElse(BigDecimal.ZERO));
    }

    public void validate() {
        if (Objects.isNull(locale)) {
            throw new IllegalArgumentException("locale is null");
        }
        log.info("locale is {}", locale);
    }
}
```

실행 결과는 아래와 같다.
```shell
Exception in thread "restartedMain" java.lang.reflect.InvocationTargetException
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:77)
	at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.base/java.lang.reflect.Method.invoke(Method.java:568)
	at org.springframework.boot.devtools.restart.RestartLauncher.run(RestartLauncher.java:49)
Caused by: org.springframework.beans.factory.NoUniqueBeanDefinitionException: No qualifying bean of type 'com.assu.study.chap03.lifecycle.PriceUnit' available: expected single matching bean but found 2: primaryPriceUnit,secondaryPriceUnit
	at org.springframework.beans.factory.support.DefaultListableBeanFactory.resolveNamedBean(DefaultListableBeanFactory.java:1299)
	at org.springframework.beans.factory.support.DefaultListableBeanFactory.resolveBean(DefaultListableBeanFactory.java:484)
	at org.springframework.beans.factory.support.DefaultListableBeanFactory.getBean(DefaultListableBeanFactory.java:339)
	at org.springframework.beans.factory.support.DefaultListableBeanFactory.getBean(DefaultListableBeanFactory.java:332)
	at org.springframework.context.support.AbstractApplicationContext.getBean(AbstractApplicationContext.java:1174)
	at com.assu.study.chap03.SpringBean07Application.main(SpringBean07Application.java:18)
	... 5 more

Process finished with exit code 0
```

이제 `@Primary` 애너테이션 적용 후 실행해보자.
```java
@Bean
@Primary
// 클래스 타입이 PriceUnit 이고, 이름이 primaryPriceUnit 인 Spring bean 정의
public PriceUnit primaryPriceUnit() {
    return new PriceUnit(Locale.US);
}
```

```shell
c.a.s.chap03.SpringBean07Application     : Locale in PriceUnit: en_US
c.a.s.c.lifecycle.LifeCycleComponent     : [LifeCycleComponent] - destroy() from DisposableBean:
c.a.s.c.lifecycle.LifeCycleComponent     : [LifeCycleComponent] - customClear()
```

---

이렇게 클래스 타입이 중복되면 `NoUniqueBeanDefinitionException` 예외가 발생하고, 반대로 Spring bean 이름이 중복되면 `BeanDefinitionOverrideException` 이 발생한다.

Spring 프레임워크는 Spring bean 이름이 중복되어 선언되는 경우 덮어쓰는데 속성 변경을 통해 이름 덮어쓰기 여부를 설정할 수 있다.

/resources/application.properties
```properties
# Spring bean 이름 덮어쓰기 여부
spring.main.allow-bean-definition-overriding=false
```

SpringBean08Application.java
```java
package com.assu.study.chap03;


import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Slf4j
@SpringBootApplication
public class SpringBean08Application {
    public static void main(String[] args) {
        ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean08Application.class, args);

        // Spring bean 이름으로 Spring bean 을 전달받아 obj 에 저장
        Object obj = ctxt.getBean("systemId");
        log.info("Bean info. type: {}, value: {}", obj.getClass(), obj);

        ctxt.close();
    }

    @Configuration
    class SystemConfig1 {
        // 클래스 타입이 Long 클래스 타입이고, 이름이 systemId 인 Spring bean 정의
        @Bean
        public Long systemId() {
            return 1L;
        }
    }

    @Configuration
    class SystemConfig2 {
        // 클래스 타입이 String 클래스 타입이고, 이름이 systemId 인 Spring bean 정의
        @Bean
        public String systemId() {
            return new String("hahaha");
        }
    }
}
```

실행 결과는 아래와 같다.
```shell
***************************
APPLICATION FAILED TO START
***************************

Description:

The bean 'systemId', defined in com.assu.study.chap03.SpringBean08Application$SystemConfig1, could not be registered. A bean with that name has already been defined in com.assu.study.chap03.SpringBean08Application$SystemConfig2 and overriding is disabled.

Action:

Consider renaming one of the beans or enabling overriding by setting spring.main.allow-bean-definition-overriding=true


Process finished with exit code 0
```

`spring.main.allow-bean-definition-overriding` 를 true 로 변경 후 실행하면 아래와 같이 정상 동작한다.

```shell
Bean info. type: class java.lang.Long, value: 1
```

하지만 오류가 발생할 때 어떤 Spring bean 이 중복되었는지 자세히 알려주므로 가능하면 **default 인 false 값을 유지**하고, 오류가 발생하면 Spring bean 이름을 변경하여
중복되지 않도록 하는 것이 좋다.

만일 테스트 시 `@TestConfiguration` 을 통해 스프링 빈을 재정의해야 할 경우엔 `spring.main.allow-bean-definition-overriding` 를 true 로 
설정해주어야 하는 경우는 application-test.properties 파일에 설정한다.

> `spring.main.allow-bean-definition-overriding=true` 로 해야하는 경우에 대한 예시는 
> [Spring Boot - 스프링 부트 테스트](https://assu10.github.io/dev/2023/08/27/springboot-test/#4-testconfiguration-을-이용하여-테스트-환경-설정) 를 참고하세요.

---

## 8.2. `@Lazy`

`@Lazy` 애너테이션은 Spring bean 생성을 지연한다.  

Spring bean Container 는 일반적으로 Spring bean 설정을 읽고 Spring bean 객체를 생성하고(Scope 가 singleton 이라고 가정), 생성된 Spring bean 객체를 
의존성 주입하지만, `@Lazy` 가 선언된 Spring bean 은 설정만 로딩한다. 그리고 의존성을 주입하는 시점에 Spring bean 객체를 생성한다.

아래는 `@Lazy` 애너테이션이 적용된 Spring bean 이 초기화되는 시점을 알 수 있는 예시이다.

SpringBean08Application.java
```java
package com.assu.study.chap03;

import com.assu.study.chap03.lifecycle.PriceUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Lazy;

import java.util.Locale;

@Slf4j
@SpringBootApplication
public class SpringBean09Application {
    public static void main(String[] args) {
        ConfigurableApplicationContext ctxt = SpringApplication.run(SpringBean09Application.class);

        log.info("---------------- Done to initialize spring beans.");

        PriceUnit priceUnit = ctxt.getBean("lazyPriceUnit", PriceUnit.class);

        log.info("Locale in PriceUnit: {}", priceUnit.getLocale().toString());

        ctxt.close();
    }

    @Bean
    @Lazy   // 클래스 타입은 PriceUnit 이고, 이름은 lazyPriceUnit 인 Spring bean 에 Lazy 적용
    public PriceUnit lazyPriceUnit() {
        log.info("initialize lazyPriceUnit");   // lazyPriceUnit Spring bean 이 생성될 때 로그 출력
        return new PriceUnit(Locale.KOREA);
    }
}
```

실행 결과는 아래와 같다.
```shell
c.a.s.chap03.SpringBean09Application     : ---------------- Done to initialize spring beans.
c.a.s.chap03.SpringBean09Application     : initialize lazyPriceUnit
c.a.s.chap03.SpringBean09Application     : Locale in PriceUnit: ko_KR
```

만일 `@Lazy` 선언이 없다면 _initialize lazyPriceUnit_ 로그가 먼저 출력된 후 _---------------- Done to initialize spring beans._ 가 출력될 것이다.

[6. Spring bean Scope: `@Scope`](#6-spring-bean-scope--scope) 에서 나온 `prototype` 과 혼동하기 쉬운데 `@Lazy` 는 singleton 이므로
의존성 주입 시점에 Spring bean 이 생성되고 이후 다른 Spring bean 에 의존성을 주입할 때 기존 객체를 그대로 주입하는 반면,
prototype 은 의존성 주입을 할 때마다 새로운 객체가 생겨난다는 차이점이 있다.

- `singleton`
  - default 값 (별도의 Scope 설정을 하지 않으면 기본 설정은 singleton)
  - Spring bean Container 에서 대상 Spring bean 을 하나만 생성하고, 하나의 bean 객체를 여러 곳에 의존성 주입함
- `prototype`
  - Spring bean Container 에서 대상 Spring bean 을 여러 bean 객체를 생성함
  - 의존성 주입을 할 때마다 새로운 객체를 생성하여 주입

---

# 9. Spring bean, Java bean, DTO, VO

- `Spring bean`
  - 객체와 이름, 클래스 타입 정보가 Spring Container 로 관리되는 객체
- `Java bean`
  - 기본 생성자가 선언되어 있고, getter/setter 패턴으로 클래스 내부 속성에 접근 가능해야 함
  - Serializable 을 구현하고 있어야 함
- `DTO` (Data Transfer Object)
  - 데이터를 전달하는 객체
  - 데이터를 전달하므로 DTO 내부에 비즈니스 로직이 없어야 함
  - 클래스 내부 속성에 접근 가능한 getter 메서드는 필요
- `VO` (Value Object)
  - 특정 데이터를 추상화하여 데이터를 표현하는 객체
  - 그래서 equals 메서드를 재정의하여 클래스가 표현하는 값을 서로 비교하면 좋음
  - 바로 아래 Money 클래스는 VO 임
  - DDD(Domain Driven Development) 에서 VO 는 immutable (불변) 해야함 

Java bean 은 Spring bean 이 될 수 있지만, Spring bean 이 Java bean 이 될 수 없다.
즉, Java bean 으로 설계된 클래스를 Spring bean 으로 선언할 수 있지만 그 반대는 될 수 없다는 의미이다.

VO 설계 시 getter/setter 를 의미없이 선언하면 객체의 immutable 속성이 깨진다.  
immutable 속성은 DTO 나 VO 생성 시 필요하며, 멀티 스레드에 안전하므로 멀티 스레드 환경에서 안전하게 사용할 수 있다. 그리고 immutable 객체는 하나의 상태만
갖고 있으므로 데이터를 안전하게 사용 가능하다.

---

<**immutable class 설계하는 법**>  
- class 는 반드시 final 로 선언
  - final 로 선언하지 않으면 상속이 발생하여 메서드들이 오버라이드되어 immutable 하지 못하게 됨
- 멤버 변수들은 반드시 final 로 선언
- 생성자를 직접 선언하여 기본 생성자가 존재하지 않도록 함
  - 기본 생성자가 있으면 여러 상태가 있는 객체를 생성할 수 있으므로 immutable 하지 못함
- setter 는 만들지 말고 getter 만 존재해야 함

아래는 immutable class 로 설계된 VO 이다.

```java
package com.assu.study.chap02;

import java.io.Serializable;
import java.util.Currency;

public final class Money implements Serializable {  // class 는 반드시 final 로 선언
  // 멤버 변수들은 반드시 final 로 선언
  private final Long value;
  private final Currency currency;

  // 생성자를 직접 선언하여 기본 생성자가 존재하지 않도록 함
  public Money(Long value, Currency currency) {
    if (value == null || value < 0) {
      throw new IllegalArgumentException("invalid value");
    }

    if (currency == null) {
      throw new IllegalArgumentException("invalid currency");
    }

    this.value = value;
    this.currency = currency;
  }

  // setter 는 만들지 말고 getter 만 존재해야 함
  public Long getValue() {
    return value;
  }

  public Currency getCurrency() {
    return currency;
  }

  // equals 메서드를 재정의하여 클래스가 표현하는 값을 서로 비교
  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    Money money = (Money) o;
    return getValue().equals(money.getValue()) && getCurrency().equals(money.getCurrency());
  }
}
```
---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [Java Optional 바르게 쓰기](https://homoefficio.github.io/2019/10/03/Java-Optional-%EB%B0%94%EB%A5%B4%EA%B2%8C-%EC%93%B0%EA%B8%B0/)
* [Java, BigDecimal 사용법 정리](https://jsonobject.tistory.com/466)