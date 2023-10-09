---
layout: post
title:  "Spring Boot - 스프링 부트 테스트"
date:   2023-08-27
categories: dev
tags: springboot msa Junit spring-boot-test test-configuration mock-bean web-mvc-test data-jpa-test json-test rest-client-test
---

이 포스팅에서는 스트링 테스트 모듈을 사용하여 테스트 케이스를 작성하는 방법에 대해 알아본다.  
스프링 부트 프레임워크에서 제공하는 애너테이션과 테스트 슬라이스 개념도 함께 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap07) 에 있습니다.

---

**목차**

- [스프링 부트 테스트 설정](#1-스프링-부트-테스트-설정)
- [Junit 사용: `@Test`](#2-junit-사용-test)
- [`@SpringBootTest` 를 이용하여 스프링 부트 테스트](#3-springboottest-를-이용하여-스프링-부트-테스트)
- [`@TestConfiguration` 을 이용하여 테스트 환경 설정](#4-testconfiguration-을-이용하여-테스트-환경-설정)
- [`@MockBean` 을 이용하여 테스트 환경 설정](#5-mockbean-을-이용하여-테스트-환경-설정)
- [테스트 슬라이스 애너테이션](#6-테스트-슬라이스-애너테이션)
- [스프링 부트 웹 MVC 테스트: `@WebMvcTest`](#7-스프링-부트-웹-mvc-테스트-webmvctest)
- [JPA 테스트: `@DataJpaTest`](#8-jpa-테스트-datajpatest)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.4
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap07

![Spring Initializer](/assets/img/dev/2023/0826/init.png)

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

  <artifactId>chap07</artifactId>

  <dependencies>
    <!-- AOP 설정 -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-aop</artifactId>
    </dependency>
    <!-- 테스트 관련 설정 -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
</project>
```

---

Java 는 단위 테스트 프레임워크인 `Junit` 을 사용하여 테스트 케이스를 작성할 수 있다.  

Maven 은 패키지 빌드 과정에 테스트 단계를 포함할 수 있고, Gradle 테스트 태스크를 포함할 수 있어서 JAR 패키지 파일을 만들기 전에 작성한 테스트 케이스들을 자동으로 실행하고, 
실행 겨로가에 따라 패키지 파일 생성 여부를 결정할 수 있다. 이를 **테스트 자동화**라고 한다.

`spring-boot-starter-test` 의존성 추가 시 REST-API 도 테스트할 수 있고, 테스트 대상 클래스가 의존하는 다른 스프링 빈을 주입해서 사용할 수 있다.

테스트 메서드는 `@Test` 애너테이션으로 정의한다.

- **단위 테스트 (Unit Test)**
  - 메서드 단위로 테스트
- **통합 테스트 (Integration Test)**
  - 애플리케이션의 기능이나 API 단위로 테스트
- **회귀 테스트 (Regression Test)**
  - 시스템을 운영하면서 발생한 버그들을 테스트 케이스로 만들어서 이전에 발생한 버그들이 재발하지 않도록 테스트하는 것
  - 버그 수정 시 해당 테스트 케이스는 항상 성공하기 때문에 새로운 기능을 추가하거나 코드 리팩토링을 하더라고 기능에 버그가 있는지 쉽게 확인 가능
  - 과거에 발생한 버그들을 다시 테스트할 수 있으므로 쉽게 검증할 수 있음


단위 테스트 케이스는 `F.I.R.S.T` 원칙에 따라 작성하는 것이 좋다.

- **Fast**
  - 테스트 케이스를 빠르게 동작해야 함
  - 패키지 빌드 과정에 테스트 단계를 포함한다면 패키지 빌드 시간은 테스트 케이스 실행 시간과 비례함
- **Isolated**
  - 테스트 케이스는 다른 외부 요인에 영향을 받지 않도록 격리해야 함
  - 다른 테스트 코드에 의존하거나 상호 동작한다면, 테스트 케이스들을 실행하는 순서에 따라 결과가 달라지거나 테스트 케이스 수정 시 다른 테스트 케이스 결과값에 영향을 줄 수 있음 
- **Repeatable**
  - 테스트 케이스는 반복해서 실행하고, 실행할 때마다 같은 결과를 확인할 수 있어야 함
- **Self-validating**
  - 테스트 케이스 내부에는 결과값을 자체 검증할 수 있는 코드가 필요함
  - 매번 사람이 테스트 결과값을 확인해야 한다면 테스트 과정을 자동화할 수 없음
- **Timely**
  - 실제 코드를 개발하기 전 테스트 케이스를 먼저 작성하는 것을 의미
  - 기능 요구 사항에 따라 테스트 케이스들을 먼저 정의한 후 기능을 개발
  - 테스트 주도 개발 방법론(TDD) 에 적합함
  - 개발이 끝난 코드를 검증하거나 레거시 코드에 테스트 케이스를 작성하는 것도 나쁘지 않음

MSA 는 여러 작은 컴포넌트가 서로 연동하여 서비스를 제공하기 때문에 테스트 케이스가 더욱 유용하게 사용될 수 있다.  
컴포넌트들을 각 기능들에 맞게 테스트 케이스를 작성하고 자동화된 테스트 프로세스를 구축함으로써 신뢰성있는 애플리케이션을 개발할 수 있다.


CI/CD, 즉 지속적으로 애플리케이션을 배포하기 위해서도 테스트 과정이 반드시 필요하며, 자동화된 테스트 과정도 필요하지만 높은 테스트 커버리지도 필요하다.


---

# 1. 스프링 부트 테스트 설정

테스트 환경을 위한 테스트 스타터 의존성을 추가한다.  
테스트 스타터는 테스트 단계에서만 사용되는 라이브러리를 포함하므로 scope 속성을 test 로 설정한다.

pom.xml
```xml
<!-- 테스트 관련 설정 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

`spring-boot-starter-test` 의존성 추가 시 아래 라이브러리들이 포함된다.

- `Junit`
  - 테스트 케이스를 작성하고 실행할 수 있는 기능 제공
  - 테스트 케이스를 정의하는 애너테이션과 테스트 결과값을 예상값과 비교/검증할 수 있는 클래스들 제공
- `Hamcrest`
  - 테스트 케이스의 결과값을 검증하는 클래스와 메서드 제공
  - Junit 에서도 검증 메서드들을 제공하지만, Hamcrest 에서 제공하는 메서드는 서술적으로 작성할 수 있어 가독성이 높음
- `Mockito`
  - 테스트에서 사용할 수 있는 mock 프레임워크
  - Mock 객체는 개발자가 입력값에 따라 출력값을 프로그래밍한 fake 객체임
  - 테스트 대상 클래스가 의존하는 객체를 mock 객체로 바꿀 수 있는 기능과 mock 객체를 만들 수 있는 기능 제공
- `spring-test`
  - 스프링 프레임워크의 기능을 통합 테스트할 수 있는 기능 제공
  - 예) 스프링 웹 MVC 같은 기능 테스트 가능
- `spring-boot-test`
  - 스프링 부트 프레임워크의 기능을 통합 테스트할 수 있는 기능 제공
- `spring-boot-test-autoconfiguration`
  - 스프링 부트 프레임워크 테스트 관련 자동 설정 기능 제공


애플리케이션 클래스와 테스트 클래스의 기본 경로는 다르지만 패키지 경로는 같다.  
예를 들어 com.assu.study.chap07.service 패키지의 TestService.java 클래스를 테스트하는 TestServiceTest.java 클래스도 com.assu.study.chap07.service 패키지에 생성한다.  
테스트 클래스가 코드 베이스 상으로는 src > test 디렉터리에 있지만 패키지 경로는 같으므로 대상 클래스의 protected 메서드에도 접근 및 테스트가 가능하다.


---

# 2. Junit 사용: `@Test`

> 본 포스팅에서는 Junit5 를 기준으로 설명한다.  
> 참고로 Junit5 는 Junit4 와 하위 호환성이 없다. 

`@Test` 애너테이션은 테스트 메서드를 정의할 때 사용한다.

먼저 src > test > java 폴더에 MiscTest.java 를 아래와 같이 작성한다.

MiscTest.java
```java
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

public class MiscTest {

  // HashSet 기능 테스트
  @Test
  public void testHashSetContainsNonDuplicatedValue() {
    // Given
    Integer value = Integer.valueOf(1);
    Set<Integer> set = new HashSet<>();

    // When
    set.add(value);
    set.add(value);
    set.add(value);

    // Then
    Assertions.assertEquals(1, set.size());
    Assertions.assertTrue(set.contains(value));
  }
}
```

위 테스트 메서드 실행 시 테스트 결과를 확인할 수 있다.

<**테스트 메서드 작성 시 주의사항**>  
- 테스트 메서드의 접근 제어자는 public 
- 테스트 메서드의 리턴 타입은 void
- 테스트 메서드명은 'test' 로 시작하는 것이 일반적

---

Junit 은 테스트 케이스의 라이프 사이클을 설정할 수 있는 애너테이션을 제공한다.  
즉 테스트 케이스를 실행하기 전/후로 별도의 작업을 실행할 수 있다.

<**라이브 사이클 애너테이션**>  
- `@BeforeAll`
  - 테스트 클래스 인스턴스를 초기화할 때 가장 먼저 실행됨
  - 테스트 클래스에 포함된 테스트 메서드가 여러 개 있어도 한 번만 실행됨
  - 객체를 생성하기 전에 미리 실행되어야 하므로 메서드는 static 접근 제어자로 정의해야 함
- `@BeforeEach`
  - 모든 테스트 메서드가 실행되기 전 각각 한 번씩 실행됨
  - 테스트 클래스에 포함된 테스트 메서드가 여러 개라면 여러 번 실행됨
- `@AfterEach`
  - 모든 테스트 메서드가 실행되고 난 후 각각 한 번씩 실행됨
  - 테스트 클래스에 포함된 테스트 메서드가 여러 개라면 여러 번 실행됨
- `@AfterAll`
  - 테스트 클래스의 모든 테스트 메서드가 실행을 마치면 마지막으로 한 번만 실행됨
  - 테스트 메서드는 static 접근 제어자로 정의해야 함

아래는 MiscTest.java 의 전체 코드이다.

MiscTest.java
```java
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.*;

import java.util.HashSet;
import java.util.Set;

@Slf4j
public class MiscTest {

  // 테스트 클래스 인스턴스를 초기화할 때 가장 먼저 실행되며 한 번만 실행됨
  @BeforeAll
  public static void setup() {
    log.info("BeforeAll: before all tests in the current test class.");
  }

  // 테스트 클래스의 모든 테스트 메서드가 실행을 마치면 마지막으로 한 번만 실행됨
  @AfterAll
  public static void destroy() {
    log.info("AfterAll: after all tests in the current test class.");
  }

  // 모든 테스트 메서드가 실행되기 전 각각 한 번씩 실행됨
  @BeforeEach
  public void init() {
    log.info("BeforeEach: before each @Test.");
  }

  // HashSet 기능 테스트
  @Test
  public void testHashSetContainsNonDuplicatedValue() {
    log.info("Test: testHashSetContainsNonDuplicatedValue()");

    // Given
    Integer value = Integer.valueOf(1);
    Set<Integer> set = new HashSet<>();

    // When
    set.add(value);
    set.add(value);
    set.add(value);

    // Then
    Assertions.assertEquals(1, set.size());
    Assertions.assertTrue(set.contains(value));
  }

  @Test
  public void testDummy() {
    log.info("Test: testDummy()");
    Assertions.assertTrue(Boolean.TRUE);
  }

  // 모든 테스트 메서드가 실행되고 난 후 각각 한 번씩 실행됨
  @AfterEach
  public void cleanup() {
    log.info("AfterEach: after each @Test");
  }
}
```

```shell
19:09:41.277 [main] INFO MiscTest -- BeforeAll: before all tests in the current test class.
19:09:41.289 [main] INFO MiscTest -- BeforeEach: before each @Test.
19:09:41.290 [main] INFO MiscTest -- Test: testDummy()
19:09:41.294 [main] INFO MiscTest -- AfterEach: after each @Test
19:09:41.301 [main] INFO MiscTest -- BeforeEach: before each @Test.
19:09:41.302 [main] INFO MiscTest -- Test: testHashSetContainsNonDuplicatedValue()
19:09:41.303 [main] INFO MiscTest -- AfterEach: after each @Test
19:09:41.306 [main] INFO MiscTest -- AfterAll: after all tests in the current test class.
```

일반적으로 테스트 메서드는 **Given-When-Then 패턴**을 사용하여 세 파트로 나누어 개발한다.  
- **Given**
  - 테스트 케이스를 준비하는 과정 (=어떤 상황이 주어졌을 때)
  - 예) HashSet 객체를 초기화하고, add() 메서드의 인자로 사용할 value 객체 초기화
- **When**
  - 테스트 실행 (= 대상 코드가 동작한다면)
  - 예) 같은 인자값 value 를 add() 메서드에 넣어서 여러 번 호출
- **Then**
  - 테스트를 검증 (= 기대한 값과 수행 결과가 맞는지)

> 테스트 개념에 대해선 [NestJS - 테스트 자동화](https://assu10.github.io/dev/2023/04/30/nest-test/#3-jest-unit-test) 의 _3. Jest Unit Test_ 를 참고하시면 도움이 됩니다.

테스트 클래스 작성 시 케이스마다 준비 과정(Given) 이 반복된다면 **라이프 사이클 애너테이션**을 고려해보면 좋다.  
보통 테스트 대상 범위가 너무 커서 테스트 대상 범위를 줄이기 위해 **mocking 하는 작업**이나 **테스트 데이터를 초기화하고 종료하는 작업**이 필요할 때 많이 사용한다.

---

검증 메서드의 인자 이름이 expect 이면 예상값을 의미하고, actual 이면 테스트 대상의 실제값을 의미한다.  
예상값과 실제값을 둘 다 인자로 받는 메서드는 순서가 바뀌어도 테스트를 진행할 수는 있다.
하지만 예상값과 실제값이 달라 에러가 발생하면 정확한 테스트 결과 메시지를 받을 수 없다.

아래는 헷갈리기 쉬운 Assertions 클래스에서 제공하는 검증 메서드이다.
- `assertEquals(Object expect, Object actual)`
  - 예상값과 실제값이 같은지 비교
  - 두 값을 비교할 때 `equals()` 메서드 사용
- `assertSame(Object expect, Object actual)`
  - 예상값과 실제값이 같은지 비교
  - 두 값을 비교할 때 `==` 연산자 사용

---

Assertions 클래스의 `assertThrow()` 를 이용하여 테스트 대상 메서드가 예외를 던지는 상황도 검증할 수 있다.  

`assertThrow()` 메서드도 여러 인자를 받도록 오버로딩되어 있으며, 가장 많이 사용하는 타입은 아래 타입이다.
```java
public static <T extends Throwable> T assertThrows(Class<T> expectedType, Executable executable) {
  return AssertThrows.assertThrows(expectedType, executable);
}
```

첫 번째 인자는 테스트 대상 메서드가 던질 것으로 예상하는 예외 클래스 타입이고,  
두 번째 인자는 Junit 프레임워크의 Executable 인터페이스이다.

Executable 인터페이스
```java
@FunctionalInterface
@API(
  status = Status.STABLE,
  since = "5.0"
)
public interface Executable {
  void execute() throws Throwable;
}
```

Executable 은 함수형 인터페이스로, void execute() throws Throwable 추상 메서드를 갖고 있다.  
람다식으로 테스트 대상 클래스의 메서드를 구현(= 람다식으로 작성된 테스트 대상 메서드를 입력)하면 assertThrow() 검증 메서드가 첫 번째 인자와 비교하여 
예외 발생 여부를 검증한다.

IOUtils.copy() 메서드가 입력 조건인 inputStream, outputStream 을 받으면 IOException 예외를 던진다는 것을 검증하는 예시 
```java
Assertions.assertThrows(
    IOException.class, 
        () -> IOUtils.copy(inputStream, outputStream)
);
```

---

# 3. `@SpringBootTest` 를 이용하여 스프링 부트 테스트

스프링 빈 클래스와 일반 자바 클래스를 예시로 테스트 케이스 작성 예시를 보자.

둘 다 모두 Junit 을 사용하여 테스트 케이스를 작성하지만, 테스트 대상 클래스를 생성하는 방법은 다르다.

일반 자바 클래스는 `new` 키워드를 사용하여 객체를 생성하고, 생성된 객체의 메서드를 테스트한다.  
예) 위에서 HashSet 클래스를 `new` 키워드로 생성

스프링 빈 클래스도 POJO 객체이므로 `new` 키워드를 사용하여 객체를 생성 후 테스트해도 되지만 이건 스프링 빈이 다른 스프링 빈에 의존하지 않을 때만 가능하다.  
테스트 대상 클래스가 다른 여러 스프링 빈에 의존한다면 `new` 키워드로 생성하여 테스트할 수 없다. 
ApplicationContext 가 테스트 대상 클래스가 의존하는 적절한 스프링 빈들을 생성하고 스프링 빈을 주입해야 테스트가 가능하다.  

또한 스프링 프레임워크의 기능을 사용한다면 스프링 프레임워크의 기능과 함께 테스트를 해야하는데 이럴 때 스프링 부트 프레임워크는  `@SpringBootTest` 애너테이션을 제공한다.

`@SpringBootTest` 애너테이션을 테스트 클래스에 선언하면 `@SpringBootApplication` 애너테이션이 적용될 클래스를 찾은 후 `@SpringBootTest` 에 설정된 
속성과 함께 애플리케이션에 선언된 스프링 빈들을 스캔/생성한다. 물론 스프링 프레임워크의 기능도 활성화된다.

아래는 HotelDisplayService 클래스를 테스트하는 HotelDisplayServiceTest 클래스이다.

/test/service/HotelDisplayServiceTest.java
```java
package com.assu.study.chap07.service;

import com.assu.study.chap07.controller.HotelRequest;
import com.assu.study.chap07.controller.HotelResponse;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;

import java.util.List;

@SpringBootTest // 스프링 프레임워크의 기능과 함께 대상 클래스 테스트, Junit4는 @Runwith(SpringRunner.class) 설정 필요, Junit5 는 @Runwith 생략 가능
public class HotelDisplayServiceTest {

  private final HotelDisplayService hotelDisplayService;
  private final ApplicationContext applicationContext;

  // 테스트 클래스에 테스트 대상 스프링 빈을 생성자 주입 방식으로 사용 시 반드시 생성자에 @Autowired 정의해야 함
  // (필드 주입 방식을 사용하여 스프링 빈 주입도 가능하긴 함)
  @Autowired
  public HotelDisplayServiceTest(HotelDisplayService hotelDisplayService, ApplicationContext applicationContext) {
    this.hotelDisplayService = hotelDisplayService;

    // 스프링 프레임워크에서 제공하는 모든 스프링 빈을 주입받아 사용할 수 있음
    this.applicationContext = applicationContext;
  }

  @Test
  public void testReturnOneHotelWhenRequestIsHotelName() {
    // Given
    HotelRequest hotelRequest = new HotelRequest("Assu Hotel");

    // When
    // 주입받은 hotelDisplayService 스프링 빈 객체의 메서드를 테스트할 수 있음
    List<HotelResponse> hotelResponses = hotelDisplayService.getHotelsByName(hotelRequest);

    // Then
    Assertions.assertNotNull(hotelResponses);
    Assertions.assertEquals(1, hotelResponses.size());
  }

  @Test
  public void testApplicationContext() {
    // 주입받은 applicationContext 의 getBean() 메서드를 사용하여 DisplayService 타입의 스프링 빈을 받아옴
    DisplayService displayService = applicationContext.getBean(DisplayService.class);

    Assertions.assertNotNull(displayService);
    Assertions.assertTrue(displayService instanceof HotelDisplayService);
  }
}
```

테스트 클래스에 테스트 대상 스프링 빈을 생성자 주입 방식으로 사용 시 반드시 생성자에 @Autowired 정의해야 한다.

---

`@SpringBootTest` 애너테이션 코드를 보자.

@SpringBootTest 애너테이션 시그니처
```java
//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

package org.springframework.boot.test.context;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Inherited;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.core.annotation.AliasFor;
import org.springframework.test.context.BootstrapWith;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@BootstrapWith(SpringBootTestContextBootstrapper.class)
@ExtendWith({SpringExtension.class})
public @interface SpringBootTest {
  @AliasFor("properties")
  String[] value() default {};

  @AliasFor("value")
  String[] properties() default {};

  String[] args() default {};

  Class<?>[] classes() default {};

  WebEnvironment webEnvironment() default SpringBootTest.WebEnvironment.MOCK;

  ...
  
  public static enum WebEnvironment {
    MOCK(false),
    RANDOM_PORT(true),
    DEFINED_PORT(true),
    NONE(false);
    ...
  }
}
```

```java
@AliasFor("properties")
String[] value() default {};

@AliasFor("value")
String[] properties() default {};
```
value, properties 속성은 서로 호환되므로 어떤 속성 이름을 사용해도 상관없다.  
속성값에 사용된 프로퍼티는 해당 테스트 케이스가 실행될 때 사용되며, 테스트에 필요한 실행 환경을 설정할 때 사용한다.


```java
String[] args() default {};
```
스프링 부트 애플리케이션을 실행하는 SpringApplication 클래스의 run() 메서드에 인자를 설정할 때 사용한다.


```java
Class<?>[] classes() default {};
```
테스트 환경을 구축하는데 사용되는 ApplicationContext 객체가 로딩할 자바 설정 클래스들을 설정한다.  
이 속성을 설정하지 않으면 ApplicationContext 는 코드 베이스에 있는 모든 스프링 빈 객체를 로딩한다.


```java
WebEnvironment webEnvironment() default SpringBootTest.WebEnvironment.MOCK;
```
스프링 부트의 웹 테스트 환경을 설정한다.  
기본값은 `WebEnvironment.MOCK` 으로, MOCK 으로 설정된 테스트 케이스를 실제 서블릿 컨테이너를 사용하지 않고 테스트를 실행한다.

`@SpringBootTest` 의 WebEnvironment 속성에 설정할 수 있는 값은 아래와 같다.
- `WebEnvironment.MOCK`
  - 서블릿 컨테이너를 실행하지 않고 서블릿을 Mock 으로 만들어 테스트 실행
  - 테스트 모듈에서 제공하는 MockMvc 객체를 사용하여 스프링 MVC 기능 테스트
- `WebEnvironment.RANDOM_PORT`
  - 서블릿 컨테이너를 실행하여 테스트 실행
  - 이 때 서블릿 컨테이너의 포트를 랜덤값으로 설정
- `WebEnvironment.DEFINED_PORT`
  - 서블릿 컨테이너를 실행하여 테스트 실행
  - 이 때 application.properties 에 정의된 포트를 사용하여 서블릿 컨테이너 실행
- `WebEnvironment.NONE`
  - 서블릿 환경을 구성하지 않고 테스트 실행


`@SpringBootTest` 의 properties 속성에 설정된 값은 해당 테스트 케이스 클래스에서만 유효하다.  
properties 속성을 사용하여 프로퍼티를 사용하는 방법은 2 가지가 있다.

- key-value 속성만 교체하는 방법
  - application.properties 에 같은 key 이름의 value 가 있다면 그 값을 @SpringBootTest 애너테이션에 설정된 값으로 대체
- 테스트 케이스에만 사용하는 프로퍼티 파일을 설정하는 방법
  - 테스트에 필요한 여러 프로퍼티값을 설정한 프로퍼티 파일로 설정
  - 여러 설정값을 테스트 케이스끼리 공용으로 사용할 때 유용

```java
// key-value 속성만 교체하는 방법
@SpringBootTest(properties = {"search.host=127.0.0.1", "search.port=99999"})

// 테스트 케이스에만 사용하는 프로퍼티 파일을 설정하는 방법
@SpringBootTest(properties = {"spring.config.location=classpath:application-test.properties"})
```

---

# 4. `@TestConfiguration` 을 이용하여 테스트 환경 설정

테스트 대상 클래스 내부에 데이터베이스에 쿼리하는 기능이 있거나 원격 서버의 REST-API 를 호출하는 기능이 있다고 하자.  
이를 테스트하려면 테스트를 위한 데이터베이스나 서버를 구축해야 하며, 같은 테스트를 여러 번 실행했을 때 데이터나 서버의 데이터가 훼손되어 매번 같은 결과값을 확인할 수 없다.

이 때 가상의 실행 환경을 만들어주는 것이 `@TestConfiguration` 이다.  
`@TestConfiguration` 을 사용하면 테스트 환경을 쉽게 구축할 수 있다.

`@TestConfiguration` 은 `@Configuration` 애너테이션과 비슷한 기능을 제공하여, 자바 설정 클래스를 정의하는 목적으로 사용한다.

> `@Configuration` 의 자세한 설명은 [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/#21-configuration) 을 참고하세요.

`@TestConfiguration` 애너테이션이 사용된 클래스에는  `@Bean` 으로 정의한 스프링 빈을 하나 이상 포함할 수 있으며, 정의된 스프링 빈은 테스트 환경에서만 유효하다.  
`@TestConfiguration` 애너테이션을 사용하면 기존 애플리케이션에서 이미 정의한 스프링 빈을 테스트에 적합하게 커스터마이징할 수 있다.

테스트 환경에서는 직접 데이터베이스에 연결하지 않고 애플리케이션 내부의 메모리 데이터베이스에 접근하도록 변경하거나, 원격 서버를 호출하지 않고 내부의 Mock 서버를 연결하도록 변경할 수 있다.

커스터마이징된 스프링 빈은 ApplicationContext 에 로딩되고, 이를 의존하는 다른 스프링 빈에 주입된다.

<**`@TestConfiguration` 과 `@Configuration` 차이점**>  
- `@TestConfiguration` 애너테이션은 테스트 환경에서만 유효한 스프링 빈을 추가로 정의
  - 만일 실행 환경에 중복된 스프링 빈이 있으면 `@TestConfiguration` 의 스프링 빈으로 재정의됨
- `@Configuration` 은 `@SpringBootConfiguration` 이 자동으로 스캔한 후 로딩되지만, `@TestConfiguration` 은 테스트 클래스에서 애너테이션을 사용하여 명시적으로 로딩해야 함
  - 예) `Import(value = {ThreadPoolConfigTest.class})` 혹은 `@ContextConfiguration(classes = ThreadPoolConfigTest.class)`
- `@Configuration` 이 정의된 자바 설정 클래스는 src > main 디렉터리에 저장하고, `@TestConfiguration` 이 정의된 테스트 자바 설정 클래스는 src > test 디렉터리에 저장

---

아래 테스트 대상 클래스인 HotelRoomDisplayService.java 와 ThreadPoolTaskExecutor.java 의 관계를 보면 
HotelRoomDisplayService 클래스가 ThreadPoolTaskExecutor 클래스에 의존하는 것을 알 수 있다.

ThreadPoolTaskExecutor 는 ThreadConfig 자바 설정 클래스에 `@Bean` 에너테이션으로 정의된 스프링 빈이다.

> ThreadPoolTaskExecutor 에 대한 다른 예시는 아래를 참고하세요  
> - [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/#21-configuration)
> - [Spring Boot - 웹 애플리케이션 구축 (1): WebMvcConfigurer 를 이용한 설정, DispatcherServlet 설정](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#123-configureasyncsupport)

getHotelRoomById() 메서드 내부에서 ThreadPoolTaskExecutor 의 execute() 메서드를 사용하여 로그를 비동기로 남긴다.  
이 때 `@TestConfiguration` 애너테이션을 사용하여 ThreadPoolTaskExecutor 를 테스트 환경에 적합하게 커스터마이징 해본다.

/controller/HotelController.java
```java
@GetMapping("/hotel/room/{id}")
public void getHotelRoomById(@PathVariable Long id) {
  hotelRoomDisplayService.getHotelRoomById(id);
}
```

/service/HotelRoomDisplayService.java
```java
package com.assu.study.chap07.service;

import com.assu.study.chap07.controller.HotelRoomResponse;
import com.assu.study.chap07.domain.HotelRoomEntity;
import com.assu.study.chap07.repository.HotelRoomRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class HotelRoomDisplayService {
  private final HotelRoomRepository hotelRoomRepository;
  private final ThreadPoolTaskExecutor threadPoolTaskExecutor;

  public HotelRoomDisplayService(HotelRoomRepository hotelRoomRepository, ThreadPoolTaskExecutor threadPoolTaskExecutor) {
    this.hotelRoomRepository = hotelRoomRepository;
    this.threadPoolTaskExecutor = threadPoolTaskExecutor;
  }

  public HotelRoomResponse getHotelRoomById(Long id) {
    HotelRoomEntity hotelRoomEntity = hotelRoomRepository.findById(id);
    threadPoolTaskExecutor.execute(() -> log.warn("entity: {}", hotelRoomEntity.toString()));

    return HotelRoomResponse.from(hotelRoomEntity);
  }
}
```

/repository/HotelRoomRepository.java
```java
package com.assu.study.chap07.repository;

import com.assu.study.chap07.domain.HotelRoomEntity;
import org.springframework.stereotype.Repository;

@Repository
public class HotelRoomRepository {
  public HotelRoomEntity findById(Long id) {
    return new HotelRoomEntity(id, "EAST-111", 9, 2, 1);
  }
}
```

/domain/HotelRoomEntity.java
```java
package com.assu.study.chap07.domain;

import lombok.Getter;
import lombok.ToString;

@Getter
@ToString
public class HotelRoomEntity {
  private final Long id;
  private final String code;
  private final Integer floor;
  private final Integer bedCount;
  private final Integer bathCount;

  public HotelRoomEntity(Long id, String code, Integer floor, Integer bedCount, Integer bathCount) {
    this.id = id;
    this.code = code;
    this.floor = floor;
    this.bedCount = bedCount;
    this.bathCount = bathCount;
  }
}
```

/controller/HotelRoomResponse.java
```java
package com.assu.study.chap07.controller;

import com.assu.study.chap07.domain.HotelRoomEntity;
import lombok.Getter;

// DTO
@Getter
public class HotelRoomResponse {
  private final Long id;
  private final String code;
  private final Integer floor;
  private final Integer bedCount;
  private final Integer bathCount;

  private HotelRoomResponse(Long id, String code, Integer floor, Integer bedCount, Integer bathCount) {
    this.id = id;
    this.code = code;
    this.floor = floor;
    this.bedCount = bedCount;
    this.bathCount = bathCount;
  }

  public static HotelRoomResponse from(HotelRoomEntity hotelRoomEntity) {
    return new HotelRoomResponse(hotelRoomEntity.getId(),
        hotelRoomEntity.getCode(),
        hotelRoomEntity.getFloor(),
        hotelRoomEntity.getBedCount(),
        hotelRoomEntity.getBathCount()
    );
  }
}
```

src > /config/ThreadPoolConfig.java
```java
package com.assu.study.chap07.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration  // ThreadPoolConfig 자바 설정 클래스는 애플리케이션이 실행될 때 클래스 내부에 정의된 스프링 빈들이 생성됨
public class ThreadPoolConfig {

  // 스프링 빈 이름은 threadPoolTaskExecutor 이고, ThreadPoolTaskExecutor 클래스 타입
  @Bean(destroyMethod = "shutdown")
  public ThreadPoolTaskExecutor threadPoolTaskExecutor() {
    ThreadPoolTaskExecutor threadPoolTaskExecutor = new ThreadPoolTaskExecutor();
    // 스레드 풀의 개수는 최대 10개까지 늘어남
    threadPoolTaskExecutor.setMaxPoolSize(10);
    // 스레드 풀의 이름은 AsyncExecutor- 로 시작함
    threadPoolTaskExecutor.setThreadNamePrefix("AsyncExecutor-");
    // 컨테이너가 모든 속성값을 적용한 후 initialize() 호출
    threadPoolTaskExecutor.afterPropertiesSet();

    return threadPoolTaskExecutor;
  }
}
```

**스프링 빈을 재정의하려면 기존에 선언된 스프링 빈의 클래스 타입과 이름을 모두 똑같이 설정**한다.  

test > /config/TestThreadPoolConfig.java
```java
package com.assu.study.chap07.config;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@TestConfiguration  // ThreadPoolConfigTest 자바 설정 클래스는 테스트가 실행될 때 클래스 내부에 정의된 스프링 빈들이 생성됨
public class ThreadPoolConfigTest {

  // 기존의 threadPoolTaskExecutor 스프링 빈을 재정의하려고 타입과 이름이 같은 스프링 빈 정의
  @Bean(destroyMethod = "shutdown")
  public ThreadPoolTaskExecutor threadPoolTaskExecutor() {
    ThreadPoolTaskExecutor threadPoolTaskExecutor = new ThreadPoolTaskExecutor();
    // 스레드 풀의 개수는 최대 1개까지 늘어남
    threadPoolTaskExecutor.setMaxPoolSize(1);
    // 스레드 풀의 이름은 TestExecutor- 로 시작함
    threadPoolTaskExecutor.setThreadNamePrefix("TestExecutor-");
    // 컨테이너가 모든 속성값을 적용한 후 initialize() 호출
    threadPoolTaskExecutor.afterPropertiesSet();

    return threadPoolTaskExecutor;
  }
}
```

이제 생성한 API 를 호출해본다.

```shell
$ curl --location 'http://localhost:18080/hotel/room/5'
```

```shell
WARN 9733 --- [AsyncExecutor-1] c.a.s.c.service.HotelRoomDisplayService  : entity: HotelRoomEntity(id=5, code=EAST-111, floor=9, bedCount=2, bathCount=1)
```

로그를 남기는 스레드명을 보면 `AsyncExecutor-` 로 시작하는 것을 확인할 수 있다.

---

먼저 `@TestConfiguration` 없이 테스트하는 예시를 보자.

test > /service/HotelRoomDisplayServiceTest00.java
```java
package com.assu.study.chap07.service;

import com.assu.study.chap07.controller.HotelRoomResponse;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class HotelRoomDisplayServiceTest00 {

  @Autowired  // 필드 주입 방식
  private HotelRoomDisplayService hotelRoomDisplayService;

  @Test
  void testOriginalGetHotelRoomById() {
    HotelRoomResponse hotelRoomResponse = hotelRoomDisplayService.getHotelRoomById(1L);

    Assertions.assertNotNull(hotelRoomResponse);
    Assertions.assertEquals(1L, hotelRoomResponse.getId());
  }
}
```

```shell
[AsyncExecutor-1] c.a.s.c.service.HotelRoomDisplayService  : entity: HotelRoomEntity(id=1, code=EAST-111, floor=9, bedCount=2, bathCount=1)
```

로그를 실행하는 스레드명이 아직 AsyncExecutor- 로 시작하는 것을 확인할 수 있다.

---

이제 `@TestConfiguration` 를 사용하여 테스트한 예시를 본다.

test > /service/HotelRoomDisplayServiceTest01.java
```java
package com.assu.study.chap07.service;

import com.assu.study.chap07.config.ThreadPoolConfigTest;
import com.assu.study.chap07.controller.HotelRoomResponse;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
// @Import 나 @ContextConfiguration 을 사용하여 명시적으로 테스트 자바 설정 클래스 로딩
//@Import(value = {ThreadPoolConfigTest.class})
@ContextConfiguration(classes = ThreadPoolConfigTest.class)
// 테스트 환경에 맞게 커스터마이징된 프로퍼티 파일 로딩 (application-test.properties 에는 스프링 빈을 재정의할 수 있는 설정값을 포함하고 있음)
@TestPropertySource(locations = "classpath:application-test.properties")
class HotelRoomDisplayServiceTest01 {

  @Autowired  // 필드 주입 방식
  private HotelRoomDisplayService hotelRoomDisplayService;

  @Test
  void testGetHotelRoomById() {
    HotelRoomResponse hotelRoomResponse = hotelRoomDisplayService.getHotelRoomById(1L);

    Assertions.assertNotNull(hotelRoomResponse);
    Assertions.assertEquals(1L, hotelRoomResponse.getId());
  }
}
```

src > resources/application-test.properties
```properties
# Spring bean 이름 덮어쓰기 여부
spring.main.allow-bean-definition-overriding=true
```

`@TestConfiguration` 을 사용하여 스프링 빈을 재정의하려면 스프링 부트 프레임워크에 추가 설정이 필요하다.  
스프링 부트 프레임워크의 기본값은 스프링 빈 재정의를 허용하지 않지만 위 상황에서는 스프링 빈의 재정의가 필요하다.  
이것은 테스트 환경에서만 필요하므로 application-test.properties 에 별도로 정의하는 것이 좋다.


```shell
[ TestExecutor-1] c.a.s.c.service.HotelRoomDisplayService  : entity: HotelRoomEntity(id=1, code=EAST-111, floor=9, bedCount=2, bathCount=1)
```

로그를 실행하는 스레드명이 TestExecutor- 로 시작하는 것을 확인할 수 있다.

---

# 5. `@MockBean` 을 이용하여 테스트 환경 설정

`@TestConfiguration` 은 설정을 재정의하는 방식으로 테스트 대상의 기능에 집중하여 테스트할 수 있다.

`@MockBean` 을 이용하면 테스트 대상이 의존하는 스프링 빈을 모의 객체로 변경하여 테스트할 수 있다.  
여기선 `@MockBean` 와 Mockito 라이브러리를 이용하여 모의 객체의 행동을 정의하여 테스트해본다.

`spring-boot-startet-test` 스타터는 `spring-boot-test` 모듈을 포함한다.  
`spring-boot-test` 모듈은 Mockito 라이브러리와  `@MockBean` 애너테이션을 제공한다.

 Mockito
  - Mock 객체를 쉽게 만들고, Mock 객체의 행동과 결과를 검증할 수 있는 기능 제공
  - 테스트 환경 설정부터 테스트 검증까지 테스트 전체 과정 모두를 처리할 수 있음

`@MockBean` 애너테이션을 사용하여 Mock 객체를 생성/주입하는 방법과 Mock 객체의 행동을 설정해보자.

> Mockito 라이브러리에서 제공하는 `@Mock` 애터네이션도 있음.  
> `@Mock` 은 Junit 과 Mockito 를 사용하여 일반 자바 객체 테스트하는데 사용.  
> `@MockBean` 은 스프링 프레임워크의 ApplicationContext 를 사용하여 주입된 스프링 빈을 Mock 객체로 변경

---

테스트 클래스에 Mock 객체를 만들 대상을 내부 변수로 선언한 후 `@MockBean` 을 정의하면 해당 객체가 Mock 객체로 변경되며, 해당 객체는 테스트 클래스에서만 유효하다.

```java
@MockBean
private HotelRoomRepository hotelRoomRepository;
```

이렇게 `@MockBean` 애너테이션을 정의하고 테스트 케이스를 실행하면 별도의 설정없이 Mock 객체가 생성되며, 생성된 Mock 객체는 ApplicationContext 에 추가된다.  
Mock 객체와 같은 클래스 타입과 이름이 같은 스프링 빈이 있다면 해당 객체는 Mock 객체로 변경된다.

아래 예시에서 HotelRoomDisplayService 는 스프링 빈이고, 테스트 대상 클래스이다.  
내부에서는 HotelRoomRepository 스프링 빈에 의존하고 있는데 이 HotelRoomRepository 를 Mock 객체로 바꾸면 HotelRoomDisplayService 기능에만 집중하여 테스트가 가능하다.

test > service/HotelRoomDisplayServiceTest02.java
```java
package com.assu.study.chap07.service;

import com.assu.study.chap07.controller.HotelRoomResponse;
import com.assu.study.chap07.domain.HotelRoomEntity;
import com.assu.study.chap07.repository.HotelRoomRepository;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;

@SpringBootTest
class HotelRoomDisplayServiceTest02 {

  @Autowired  // 필드 주입 방식
  private HotelRoomDisplayService hotelRoomDisplayService;

  // Mock 객체 생성
  // 테스트 프레임워크가 만든 HotelRoomRepository Mock 객체가 ApplicationContext 에 포함되고,
  // 해당 Mock 객체는 ApplicationContext 로 HotelRoomDisplayService 에 주입됨
  @MockBean
  private HotelRoomRepository hotelRoomRepository;

  @Test
  void testGetHotelRoomById() {
    // Mock 객체의 행동 설정
    // findById() 메서드가 호출되면 아이디가 10L 인 HotelRoomEntity 객체 리턴
    // findById() 메서드에 '어떤 인자' 를 의미하는 any() 를 설정했으므로 인수값에 상관없이
    // willReturn() 메서드에 인자로 설정된 HotelRoomEntity 객체를 무조건 리턴
    given(this.hotelRoomRepository.findById(any()))
        .willReturn(new HotelRoomEntity(10L, "test", 1, 2, 3));


    HotelRoomResponse hotelRoomResponse = hotelRoomDisplayService.getHotelRoomById(1L);

    Assertions.assertNotNull(hotelRoomResponse);
    Assertions.assertEquals(10L, hotelRoomResponse.getId());
  }
}
```

---

위 코드에서 아래 부분을 자세히 보자.
```java
given(this.hotelRoomRepository.findById(any()))
        .willReturn(new HotelRoomEntity(10L, "test", 1, 2, 3));
```

위 부분은 **mockito.BDDMockito** 클래스의 `given()`, `willReturn()` mockito.ArgumentMatchers 의 `any()` 로 구성되어 있다.

- `BDDMockito.given(T methodCall)`
  - Stub 을 만드는 메서드
  - `given()` 의 인자에 스텁으로 만들 대상 메서드 입력
  - 여기선 인자로 입력한 hotelRoomRepository.findById() 메서드를 `given()` 메서드를 사용하여 스텁으로 만들었음
  - HotelRoomDisplayService 객체 내부에서 hotelRoomRepository.findById() 메서드 호출 시 프로그래밍된 스텁 객체가 응답됨
- `ArgumentMatchers.any()`
  - hotelRoomRepository.findById() 가 호출될 때 인자에 다양한 값이 전달될 수 있는데 이 때 인자값에 대한 조건 설정
  - 여기선 모든 타입값을 의미하는 `ArgumentMatchers.any()` 사용
  - 따라서 어떤 인자값을 사용하더라도 `given()` 으로 만들어진 스텁이 동작함
- `BDDMockito.willReturn(T value)`
  - 위의 조건에 맞는 스텁이 호출되면 `willReturn()` 메서드의 인자로 입력된 값을 응답

즉, 위 설명을 조합해보면 '어떤 인자값을 사용하더라도 hotelRoomRepository.findById() 메서드를 호출하면 willReturn() 메서드의 인자인 HotelRoomEntity 
객체를 응답한다' 라는 의미이다.

> dummy, fake, spy, stub, mock 에 대한 차이는 [NestJS - 테스트 자동화](https://assu10.github.io/dev/2023/04/30/nest-test/#3-jest-unit-test) 를 참고하세요.

> Mockito 라이브러리에서는 BDDMockito.java 와 같이 스텁을 만들 수 있는 Mockito.java 클래스를 제공함  
> BDDMockito 클래스가 Mockito 클래스를 상속받기 때문에 두 클래스가 제공하는 메서드는 거의 같음  
> 
> BDDMockito 의 given() 와 Mockito 의 when() 는 같은 기능을 제공함  
> 하지만 BDDMockito 는 행위 주도 개발 (Behavior Driven Development, BDD) 기반의 메서드명을 제공함  
> 
> 행위 주도 개발론은 테스트 케이스를 작성할 때 기대하는 행동과 결과를 처리하는 과정을 자연어에 가깝게 프로그래밍하여 가독성과 유지 보수성을 높이는 것이 목적 

---

이제 ArgumentMatchers 의 기능들을 보자.  

**ArgumentMatchers 는 스텁의 인자 조건을 설정할 수 있는 기능을 제공**한다.

any() 메서드를 사용해도 되지만 아래와 같은 메서드를 사용하여 좀 더 정교하게 조건 설정이 가능하다.

- `public static <T> T any(Class<T> type)`
  - null 을 제외한 type 객체와 일치하는 경우를 의미
- `public static <T> T isA(Class<T> type)`
  - 클래스 type 인자를 구현하는 경우를 의미
- `public static boolean anyBoolean()`
  - Boolean 타입인 어떤 값이라도 일치하는 경우를 의미
- `public static byte anyByte()`
  - byte 혹은 Byte 타입인 어떤 값이라도 일치하는 경우를 의미
- `public static int anyInt()`
  - int 혹은 Integer 타입인 어떤 값이라도 일치하는 경우를 의미
  - 비슷하게 `anyLong()`, `anyFloat()`, `anyDouble()`, `anyShort()`, `anyString()` 등이 있음
- `public static <T> List<T> anyList()`
  - List 타입인 어떤 값이라도 일치하는 경우를 의미
  - 비슷하게 `anySet()`, `anyMap()` 등이 있음
- `public static int eq(int value)`
  - value 값과 일치하는 경우를 의미
  - 이 외에도 여러 인자 타입을 입력받을 수 있는 `eq()` 메서드를 오버로딩하여 제공함

---

**BDDMockito 클래스의 스텁의 응답값을 설정하는 기능** 에 대해 알아보자.

BDDMockito 의 willReturn() 처럼 조건이 충족되면 응답을 프로그래밍할 수 있는 메서드들은 아래와 같다.

- `public static BDDStubber willReturn(Object toBeReturned)`
  - 조건이 충족되면 미리 정해진 값을 응답
  - 고정된 값을 응답하므로 간단하게 구현 가능
- `public static BDDStubber willReturn(Object toBeReturned, Object... toBeReturnedNext)`
  - 조건이 충족되면 미리 정해진 값을 응답하고, 계속해서 스텁 메서드를 호출하면 toBeReturnNext 인자들이 순서대로 응답함
- `public static BDDStubber willDoNothing()`
  - 아무것도 응답하지 않음
- `public static BDDStubber willThrow(Class<? extends Throwable> toBeThrown)`
  - 조건이 충족되면 toBeThrow 예외 응답
- `public static BDDStubber will(Answer<?> answer)`
  - 인자 Answer 인터페이스를 사용하여 개발자가 원하는 응답을 프로그래밍
  - `willReturn()` 은 고정된 값을 리턴하지만 `will()` 은 상황에 따라 동적으로 응답하도록 프로그래밍 가능
- `public static BDDStubber willAnswer(Answer<?> answer)`
  - `will()` 과 같은 역할
  - 바로 아래 예시 참고

---

`willAnswer()` static 메서드는 Answer 인터페이스를 인자로 받는다.  
**Answer 인터페이스는 Mock 객체의 메서드가 리턴하는 값을 동적으로 프로그래밍할 수 있는 기능을 제공**한다.  

추상 메서드인 `answer()` 에서 응답을 프로그래밍하며, `answer()` 의 인자인 InvocationOnMock 객체는 Mock 객체가 응답하는 메서드의 정보를 포함하고 있다.  
따라서 이 둘을 사용하여 `answer()` 메서드를 구현하면 상황에 따라 동적으로 응답하는 Mock 객체를 만들 수 이싿.

Answer 인터페이스
```java
public interface Answer<T> {
  T answer(InvocationOnMock var1) throws Throwable;
}
```

test > service/HotelRoomDisplayServiceTest01.java
```java
@Test
void testWillAnswer() {
  given(this.hotelRoomRepository.findById(any()))
      // 스텁 메서드가 응답하는 클래스의 타입(HotelRoomEntity)을 제네릭으로 입력
      // 즉, hotelRoomRepository.findById() 메서드가 응답하는 클래스 타입은 HotelRoomEntity
      .willAnswer(new Answer<HotelRoomEntity>() {
        @Override
        // InvocationOnMock 은 Mock 메서드의 인자, 메서드명, Mock 객체 정보를 포함하여, 이 정보들을 참조할 수 있는 메서드 제공
        public HotelRoomEntity answer(InvocationOnMock invocationOnMock) throws Throwable {
          // 런타임 시점에서 Mock 메서드의 인자 정보 획득
          Long id = invocationOnMock.getArgument(0);
          if (id != null && id > 10) {
            return new HotelRoomEntity(id, "CODE", 3, 3, 3);
          } else {
            return new HotelRoomEntity(10L, "test", 1, 2, 3);
          }
        }
      });

  HotelRoomResponse hotelRoomResponse = hotelRoomDisplayService.getHotelRoomById(1L);

  Assertions.assertNotNull(hotelRoomResponse);
  Assertions.assertEquals(10L, hotelRoomResponse.getId());
}
```

모든 테스트 메서드마다 같은 Mock 객체를 설정하는 것은 비효율적이므로  `@BeforeAll` 이나 `@BeforeEach` 애너테이션을 사용하여 Mock 객체를 설정하는 부분을 
따로 정의하는 것이 좋다.

---

# 6. 테스트 슬라이스 애너테이션

`@SpringBootTest` 애너테이션으로 테스트 실행 시 ApplicationContext 를 이용하여 스프링 빈을 스캔하고 의존성을 주입하는데, 애플리케이션의 기능이 많다면 
스캔해야 할 대상이 많아지고 그만큼 많은 객체를 생성해야 하기 때문에 테스트 시간이 오래 걸린다. (= 배포 시간이 길어짐)

**스프링 부트 프레임워크는 테스트 시간을 줄이려고 테스트 슬라이스 개념을 제공**한다.  
즉, **기능별로 잘라서 테스트 대상을 좁히는 방법**이다.

테스트 대상이 좁혀지면 ApplicationContext 가 스캔해야 할 스프링 빈의 개수도 줄어들고, 기능도 초기화하지 않아도 된다.  

`@SpringBootTest` 애너테이션은 전체 기능과 스프링 빈을 로딩하므로 아래 테스트 슬라이스 애너테이션과 함께 사용하면 안된다.

- `@WebMvcTest`
  - 스프링 MVC 프레임워크의 기능 테스트
  - `@Controller`, `@ControllerAdvice` 를 스캔하고, Converter, Filter, WebMvcConfigurer 같은 MVC 기능 제공
  - `@Service`, `@Component`, `@Repository` 로 정의된 스프링 빈들은 스캔하지 않음
- `@DataJpaTest`
  - 데이터 영속성 프레임워크인 JPA 기능 테스트
  - `@Repository` 을 스캔하고, JPA 프레임워크에서 사용하는 EntityManager, TestEntityManager, DataSource 같은 기능 제공
  - `@Service`, `@Component`, `@Controller` 로 정의된 스프링 빈들은 스캔하지 않음
- `@JsonTest`
  - Json 직렬화, 역직렬화 테스트
  - `@JsonComponent`, ObjectMapper 와 같은 기능 테스트
  - `@Service`, `@Component`, `@Controller`, `@Repository` 로 정의된 스프링 빈들은 스캔하지 않음
- `@RestClientTest`
  - HTTP 클라이언트의 동작을 테스트
  - MockRestServiceServer, Jackson 자동 설정 기능 제공
  - `@Service`, `@Component`, `@Controller`, `@Repository` 로 정의된 스프링 빈들은 스캔하지 않음
- `@DataMongoTest`
  - MongoDB 를 테스트
  - MongoTemplate, CrudRepository 같은 기능 테스트
  - `@Service`, `@Component`, `@Controller` 로 정의된 스프링 빈들은 스캔하지 않음

---

# 7. 스프링 부트 웹 MVC 테스트: `@WebMvcTest`

스프링 부트 애플리케이션의 웹 기능을 테스트해본다.

HTTP 프로토콜을 사용하여 클라이언트가 요청을 보내고, 서버가 어떤 응답을 하는지 테스트하는 방식이 아닌 `@WebMvcTest` 를 사용한다.  
따라서 서버와 클라이언트 사이의 네트워크 구간은 문제없다고 생각하고, 서버 애플리케이션의 요청, 응답 기능이 정상적으로 동작하는지 확인한다.

여기선 REST-API 애플리케이션에 대해 다루므로 서블릿이나 웹 서비스가 아닌 REST-API 를 처리하는 `@RestController` 클래스를 테스트한다.

주로 요청 조건에 따라 컨트롤러 클래스가 어떤 형식의 JSON 응답 메시지를 리턴하는지에 대해서 테스트하는데, 예를 들어 응답 메시지의 Content-type 헤더값을 검증하거나 
JSON 메시지 값을 검증하는 테스트 케이스를 작성한다.

src > controller/HotelController.java
```java
package com.assu.study.chap07.controller;

import com.assu.study.chap07.service.HotelDisplayService;
import com.assu.study.chap07.service.HotelRoomDisplayService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@Slf4j
public class HotelController {
  private final HotelDisplayService hotelDisplayService;
  private final HotelRoomDisplayService hotelRoomDisplayService;

  public HotelController(HotelDisplayService hotelDisplayService, HotelRoomDisplayService hotelRoomDisplayService) {
    this.hotelDisplayService = hotelDisplayService;
    this.hotelRoomDisplayService = hotelRoomDisplayService;
  }

  @PostMapping("/hotels/name")
  // List<HotelResponse> 객체를 리턴하며, @RestController 가 JSON 으로 변경함, List 객체이므로 마셜링되면 JSON Array 형태로 변환됨
  public ResponseEntity<List<HotelResponse>> getHotelByName(
      @RequestBody HotelRequest hotelRequest) { // POST 요청의 Content-type 헤더값은 application/json 이고, Body 는 JSON 형식의 데이터
    List<HotelResponse> hotelResponse = hotelDisplayService.getHotelsByName(hotelRequest);
    return ResponseEntity.ok(hotelResponse);
  }
}
```

---

`spring-test` 모듈은 WebMVC 를 테스트할 수 있는 o.s.test.web.servlet.MockMvc 클래스를 제공한다.  
이 Mock 객체는 HTTP 클라이언트처럼 서버의 API 에 요청을 하고, 그 응답을 받아올 수 있는 기능을 제공한다.  
즉, 실제로 HTTP 프로토콜을 사용하여 서버의 API 를 호출하지 않고, 요청을 전송하고 응답을 받아올 수 있는 기능을 Mock 객체로 제공한다.

MockMvc 를 사용하여 테스트 케이스를 작성할 때 주로 아래 클래스들을 함께 사용한다.
- `MockMvcRequestBuilders`
  - MockMvc 를 사용하여 HTTP 요청을 전달할 때 HTTP 요청을 Mock 객체로 만들 수 있는 기능 제공
  - 따라서 요청 메시지의 HTTP 헤더나 파라메터, HTTP body 를 설정할 수 있는 메서드 제공
  - HTTP Request 의 역할
- `MockMvcResultMatchers`
  - HTTP 응답 메시지를 검증할 수 있는 기능들 제공
- `ResultActions`
  - 서버에서 처리한 HTTP 응답 메시지의 각 속성에 접근할 수 있는 메서드 제공
  - HTTP Response 의 역할

---

MockMvc 클래스에서 가장 중요한 역할을 하는 메서드는 `perform()` 이다.

`perform()` 메서드는 테스트 대상 REST-API 에 HTTP 메시지를 요청하고, 실행 결과를 ResultActions 에서 확인할 수 있다.

```java
mockMvc.perform(
  post("/hotels/{id}", 11)  // HTTP POST 메서드를 사용하여 요청
  .contentType(MediaType.APPLICATION_JSON)  // 요청 메시지의 Content-type 헤더에 'application/json' 헤더값 설정
  .accept(MediaType.APPLICATION_JSON) // Accept 헤더에 'application/json' 설정
  .content(jsonString)  // 요청 메시지 body 에 문자열값 설정, 인자로 String 이 아닌 byte[] 도 받을 수 있기 때문에 파일 업로드 테스트도 가능
  .header("x-channel-name", "web")  // 요청 메시지의 헤더 영역과 헤더값 설정
);

mockMvc.perform(
  get("/hotles/{id}", 11)
  .queryParam("type", "5Star")
);

mockMvc.perform(
  put("/hotels/{id}", 11)
);

mockMvc.perform(
  delete("/hotels/{id}", 11)
);
```

`queryParam()` 과 비슷한 `param()` 메서드도 제공하는데 `param()` 메서드는 application/x-www-form-urlencoded 콘텐츠 타입의 요청 메시지 body 에 
key-value 데이터를 설정한다.

---

MockMvc 의 `perform()` 메서드는 실행된 결과를 포함하고 있는 `ResultActions` 를 리턴한다.  
`ResultActions` 클래스는 응답 데이터를 검증할 수 있는 `andExpect()` 메서드를 제공한다.  
`andExpect()` 는 `ResultMatcher` 를 인자로 받으며, 메서드 체인 방식으로 계속 연결하여 사용할 수 있다.

`MockMvcResultMatchers` 에서 제공하는 static 메서드들은 `ResultMatcher` 객체를 리턴하며,  
`ResultActions` 의 `andExpect()` 메서드를 사용하여 테스트 결과를 검증할 수 있다.

HTTP 응답 메시지를 검증하기 때문에 HTTP 응답 메시지의 상태 코드, 메시지 바디, 헤더 등을 검증할 수 있다.

---

아래는 **`@SpringBootTest` 애너테이션을 사용한 테스트 케이스 예시**이다. (바로 뒤에 테스트 슬라이스 애너테이션인 `@WebMvcTest` 를 사용하여 테스트 케이스 작성 예시 있음)

test > /controller/ApiControllerTest00.java
```java
package com.assu.study.chap07.controller;

import com.assu.study.chap07.util.JsonUtil;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.result.MockMvcResultHandlers;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

// MockMvcBuilders 클래스를 사용하여 MockMvc 객체 생성도 가능하지만, 스프링 부트에서 제공하는 @AutoConfigureMockMvc 를 정의하면 MockMvc 객체를 스프링 빈으로 주입받을 수 있음
// @SpringBootTest 애너테이션을 사용하여 스프링 MVC 기능 테스트 시 함께 사용함
@AutoConfigureMockMvc
// WebEnvironment.MOCK 을 설정하여 실제 서블릿 컨테이너를 실행하지 않고 Mock 서블릿 컨테이너를 사용하여 테스트 진행
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
class ApiControllerTest00 {

  // @AutoConfigureMockMvc 로 생성된 MockMvc 스프링 빈 주입받음
  @Autowired
  private MockMvc mockMvc;

  @Test
  public void testGetHotelByName() throws Exception {
    HotelRequest hotelRequest = new HotelRequest("Assu Hotel.");
    String jsonRequest = JsonUtil.objectMapper.writeValueAsString(hotelRequest);

    mockMvc.perform(post("/hotels/name")
            .content(jsonRequest)
            .contentType(MediaType.APPLICATION_JSON)
        )
        .andExpect(status().isOk()) // 응답 메시지가 200 인지 검증
        .andExpect(content().contentType(MediaType.APPLICATION_JSON))
        .andExpect(content().string("[{\"hotelId\":1000,\"hotelName\":\"Assu Hotel~\",\"address\":\"Seoul Gangnam\",\"phoneNumber\":\"+821112222\"}]"))
        .andExpect(content().json("[{\"hotelId\":1000,\"hotelName\":\"Assu Hotel~\",\"address\":\"Seoul Gangnam\",\"phoneNumber\":\"+821112222\"}]"))
        .andExpect(jsonPath("$[0].hotelId", Matchers.is(1000)))
        .andExpect(jsonPath("$[0].hotelName", Matchers.is("Assu Hotel~")))
        .andDo(MockMvcResultHandlers.print(System.out));
  }
}
```

src > util/JsonUtil.java
```java
package com.assu.study.chap07.util;

import com.fasterxml.jackson.databind.ObjectMapper;

public class JsonUtil {
  public static final ObjectMapper objectMapper = new ObjectMapper();
}
```

위 예시는 `@SpringBootTest` 애너테이션을 사용하여 테스트했기 때문에 코드 베이스의 모든 스프링 빈이 ApplicationContext 에 로딩되고 의존성 주입이 된다.  
HotelController 와 HotelDisplayService 모두 스프링 빈으로 로딩되고, HotelDisplayService 가 HotelController 에 주입된다.  
(`@WevMvcTest` 와 다른 동작 방식임)

그래서 MockMvc 를 사용하여 REST-API 테스트 시 HotelDisplayService 의 실케 코드가 동작한다.

---

아래는 **`@WebMvcTest` 애너테이션을 사용한 테스트 케이스 예시**이다.

검증 내용은 위의 ApiControllerTest00.java 와 동일하다.  
`@WebMvcTest` 사용 시 어떤 점을 주의하고, 어떤 코드가 변경되는지 확인해보자.

test > controller/ApiControllerTest01.java
```java
package com.assu.study.chap07.controller;

import com.assu.study.chap07.service.HotelDisplayService;
import com.assu.study.chap07.util.JsonUtil;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.invocation.InvocationOnMock;
import org.mockito.stubbing.Answer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.result.MockMvcResultHandlers;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

// @WebMvcTest 의 controllers 속성을 사용하지 않으면 애플리케이션에 포함된 모든 컨트롤러 클래스 스캔
@WebMvcTest(controllers = HotelController.class)
public class ApiControllerTest01 {
  @Autowired
  private MockMvc mockMvc;

  // Mock 객체 생성
  @MockBean
  private HotelDisplayService hotelDisplayService;

  // Mockito 의 given() 과 willAnswer() 를 사용하여 적절한 값을 응답하도록 설정
  @BeforeEach
  public void init() {
    given(hotelDisplayService.getHotelsByName(any()))
        .willAnswer(new Answer<List<HotelResponse>>() {
          @Override
          public List<HotelResponse> answer(InvocationOnMock invocationOnMock) throws Throwable {
            HotelRequest hotelRequest = invocationOnMock.getArgument(0);
            return List.of(new HotelResponse(1L, hotelRequest.getHotelName(), "unknown", "111-222-3333"));
          }
        });
  }

  @Test
  public void testGetHotelByName() throws Exception {
    HotelRequest hotelRequest = new HotelRequest("Assu Hotel.");
    String jsonRequest = JsonUtil.objectMapper.writeValueAsString(hotelRequest);

    mockMvc.perform(post("/hotels/name")
            .content(jsonRequest)
            .contentType(MediaType.APPLICATION_JSON)
        )
        .andExpect(status().isOk()) // 응답 메시지가 200 인지 검증
        .andExpect(content().contentType(MediaType.APPLICATION_JSON))
        .andExpect(jsonPath("$[0].hotelId", Matchers.is(1)))
        .andExpect(jsonPath("$[0].hotelName", Matchers.is("Assu Hotel.")))
        .andDo(MockMvcResultHandlers.print(System.out));
  }
}
```

`@WebMvcTest` 애너테이션을 사용하면 `@Controller` 와 `@ControllerAdvice` 애너테이션이 정의된 스프링 빈만 로딩한다.  
HotelController 가 의존하는 HotelDisplayService 클래스는 `@Service` 로 정의되어 있어 스캔 대상이 되지 않으므로 (`@Component`, `@Repository` 도 마찬가지) 
스프링 스캔에 포함되지 않는 것들에는 Mock 객체를 별도로 생성해야 하며, `@MockBean` 애너테이션으로 생성할 수 있다.

`@WebMvcTest` 애너테이션의 가장 큰 장점을 빠르게 테스트할 수 있다는 것이다.  
`@SpringBootTest` 애너테이션과 다른 점은 `@WebMvcTest` 는 `@AutoConfigureMockMvc` 애너테이션이 없어도 MockMvc 객체를 생성한다.

---

# 8. JPA 테스트: `@DataJpaTest`

`@DataJpaTest` 는 `@Repository` 스프링 빈을 테스트 하는 방법이다.

> `@DataJpaTest` 의 실제 예시는 [Spring Boot - 데이터 영속성(3): JpaRepository, 쿼리 메서드](https://assu10.github.io/dev/2023/09/03/springboot-database-3/#222-datajpatest-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%ED%85%8C%EC%8A%A4%ED%8A%B8-%EC%BC%80%EC%9D%B4%EC%8A%A4) 를 참고하세요.

`@WebMvcTest` 애너테이션이 WebMvc 영역을 구분하여 빠르게 테스트하는 것처럼 `@DataJpaTest` 애너테이션을 사용하여 데이터를 처리하는 영역을 구분함으로써 빠르게 테스트 가능하다.

`@DataJpaTest` 는 JPA 와 관련된 기능만 로딩하기 때문에 `@Repository` 만 스캔하고, `@Service`, `@Component`, `@Controller` 애너테이션은 스캔하지 않는다.

`@SpringBootTest` 애너테이션을 사용하여 테스트 케이스를 작성하면 테스트 케이스마다 `@Transactional` 애너테이션을 정의하고,   
`@DataJpaTest` 는 소스 내부에 `@Transactional` 애너테이션을 포함하고 있어서 별도로 정의하지 않아도 된다.

테스트 케이스에 `@Transactional` 애너테이션을 정의하면 테스트 종료 후 롤백되기 때문에 테스트 도중에 발생한 데이터 생성/수정/삭제 등 변경된 데이터들은 다시 초기화가 된다.

**_하지만 SprintBootTest 의 environment 속성을 WebEnvironment.RANDOM_PORT 나 DEFINED_PORT 로 설정하면 롤백되지 않는다._**  

**위의 설정들로 테스트 케이스 실행 시 별도의 서블릿 컨테이너가 실행되는데, 
테스트 케이스를 실행하는 스레드와 테스크 케이스가 호출한 서블릿 컨테이너의 스레드가 서로 달라 서블릿 컨테이너의 트랜잭션을 테스트 케이스에서 롤백할 수 없기 때문**이다.

---

테스트 케이스는 지속 가능한 애플리케이션을 만들 수 있게 해준다.  
버그가 발생하거나 기능이 추가될 때마다 테스트 케이스를 작성한다면 애플리케이션을 서비스한 기간만큼 테스트 케이스도 많아질 것이다.  
이렇게 많아진 테스트 케이스는 애플리케이션의 대부분 기능을 테스트할 것이고, 버그에 대응한 테스트가 많아지면 별도의 노력없이 자동으로 회귀 테스트가 된다.  
이 정도로 구축이 되면 애플리케이션은 언제든지 리팩터링할 수 있으며, 같은 에러가 다시 발생하지 않는 신뢰성 있는 서비스가 될 것이다.

이제 **직접 REST-API 를 호출해서 기능을 테스트하지 말고 테스트 케이스를 사용하여 기능 테스트**하는 습관을 만들자!

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [tdd 라이브 템플릿](https://ahn3330.tistory.com/128)
* [인텔리제이 (IntelliJ )스마트하게 사용하기 - 테스트 코드 쉽게 만들기 (go to test, live templates 활용)](https://velog.io/@joshuara7235/IntelliJ-%EC%8A%A4%EB%A7%88%ED%8A%B8%ED%95%98%EA%B2%8C-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0-Test-code-%EC%89%BD%EA%B2%8C-%EB%A7%8C%EB%93%A4%EA%B8%B0-go-to-test-live-templates-%ED%99%9C%EC%9A%A9)