---
layout: post
title:  "Spring Boot - AOP"
date:   2023-08-26
categories: dev
tags: springboot msa aop
---

이 포스팅에서는 객체 지향 프로그래밍과 관점 지향 프로그래밍(AOP) 가 어떻게 다른지 알아본다.  
관점 지향 프로그래밍의 핵심은 **'관심의 분리'** 이며, 관심의 분리를 최소화할 수 있는 사용자 정의 애너테이션을 사용하는 법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap07) 에 있습니다.

---

**목차**

- [AOP 용어](#1-aop-용어)
- [어드바이스: `@Before`, `@After`, `@AfterReturning`, `@AfterThrowing`, `@Around`](#2-어드바이스-before-after-afterreturning-afterthrowing-around)
- [스프링 AOP 와 프록시 객체](#3-스프링-aop-와-프록시-객체)
- [포인트 컷과 표현식](#4-포인트-컷과-표현식)
  - [포인트 컷 표현식으로 포인트 컷 지정](#41-포인트-컷-표현식으로-포인트-컷-지정)
    - [`@PointCut` 애너테이션과 포인트 컷 표현식을 사용하여 별도의 포인트 컷 정의](#411-pointcut-애너테이션과-포인트-컷-표현식을-사용하여-별도의-포인트-컷-정의)
    - [어드바이스 애너테이션의 value 속성 사용](#412-어드바이스-애너테이션의-value-속성-사용)
  - [특정 애너테이션으로 포인트 컷 지정: `@annotation`](#42-특정-애너테이션으로-포인트-컷-지정-annotation)
- [`JoinPoint`, `ProceedingJoinPoint`](#5-joinpoint-proceedingjoinpoint)
- [관점 클래스: `@Aspect`](#6-관점-클래스-aspect)
- [애너테이션을 이용한 AOP: `@annotation`, `@Order`](#7-애너테이션을-이용한-aop-annotation-order)

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
  </dependencies>
</project>
```

---

스프링 프레임워크의 3 가지 핵심 기술은 의존성 주입(DI), 서비스 추상화, 관점 지향 프로그래밍(AOP) 이다.

**AOP (Aspect Oriented Programming) 는 프로그램의 구조를 관점 (Aspect) 기준으로 공통된 모듈로 분리하는 방법**이다.

객체 지향 프로그래밍에서 모듈 단위는 '클래스' 이고, 관점 지향 프로그래밍에서 모듈 단위는 '관점' 이다.  
두 프로그래밍 방식은 상호 보완적으로 동작한다.

**관점은 여러 클래스에 걸쳐 공통으로 실행되는 기능을 모듈로 분리**한 것이다.

관점 지향 프로그래밍은 의존으로 발생하는 복잡도를 낮출 수 있다.  
**객체 지향 프로그래밍은 의존하는 클래스의 메서드를 직접 호출**해야 하지만, **관점 지향 프로그래밍은 프레임워크의 도움을 받아 코드를 조립**할 수 있다.  

즉, 개발자가 코드 작성 시 명시적으로 관점 객체(클래스)를 생성하지 않으며, 메서드도 직접 호출하지 않는다.  
단지 **관점이 구현된 클래스에서는 대상 클래스의 특정 부분에 기능을 추가하거나 관여할 수 있는 설정이 있을 뿐**이다.

이렇게 클래스 밖에서 관점의 기능이 실행되므로 서로 완전히 분리된 형태를 '관심의 분리' 라고 한다.

**관점 지향 프로그래밍을 할 때 고려할 사항**은 아래와 같다.

- **기능의 분류**
  - 애플리케이션의 기능을 기능적 요구 사항과 비기능적 요구 사항으로 분류
  - 기능적 요구 사항 = 비즈니스 핵심 로직
  - 비기능적 요구 사항 = 비즈니스 로직은 아니지만 애플리케이션의 기능을 실행하는데 반드시 필요한 기능
- **공통 기능의 분류**
  - 공통 기능을 모듈화하는 과정이 필요
  - 일반적으로 비기능적 요구 사항은 애플리케이션 전반에 걸쳐 공통으로 사용됨. 예) 캐싱, 로깅, 인증, 인가, 트랜잭션...
  - 단, 공통 기능으로 분류된 기능적 요구 사항은 관점 지향 프로그래밍으로 작성하면 안됨  
  비즈니스 로직은 응집력이 있어야 하기 때문에 분리되어 처리되면 안됨
- **공통 기능의 적용**
  - 어떤 클래스/메서드에 어떤 공통 기능을 적용할지 설계
  - 적용 대상을 결정하고 어떤 관점을 적용할 지 설명
  - 적용 대상은 클래스의 메서드이며, 메서드의 시작과 끝에 관점 기능 추가 가능


![핵심 관심사와 횡단 관심사](/assets/img/dev/2023/0826/aop1.png)

**기능적 요구 사항들은 객체 지향 프로그래밍의 클래스로 작성**하고, **비기능적 요구 사항들은 관점 지향 프로그래밍 관점 클래스**로 작성한다.

관심의 분리 측면에서 위 그림을 다시 보자.  

조회, 예약, 결제는 핵심 기능이며 이를 핵심 관심사라고 한다.  
조회, 예약, 결제의 관심은 요구사항에 맞게 해당 기능을 실행하는 것이다.

비기능적 요구 사항들의 관심은 핵심 관심사와 그 목적이 다르다.  
예를 들어 트랜잭션의 기능은 트랜잭션을 관리하는 것이 관심이다.

이렇게 **각각의 관심이 다르므로 코드에서도 각자 관심을 분리해야 한다는 것이 AOP 의 주목적**이다.

하지만 각각의 관심이 달라서 코드상으로 분리가 되어있어도 실행될 때는 필요한 곳에 필요한 기능이 추가되어야 한다.

**비기능적 요구 사항**은 공통적으로 실행되는 특성이 있는데 일반적으로 이런 기능은 **핵심 기능을 실행하기 전에 먼저 실행되거나, 핵심 기능의 종료 시점에 실행**된다.  
이렇게 공통 로직이 핵심 비즈니스 로직들을 횡단하고 있는 형태를 띄고 있어서 **횡단 관심사**라고 한다.

test() 라는 메서드 실행 시 횡단 관심사인 로깅, 인증, 트랜잭션 로직이 먼저 실행된 후 test() 메서드 내부의 코드가 실행된다.  
이 때 **횡단 관심사의 코드가 test() 메서드 내부에 있는 것이 아니라, 횡단 관심사의 코드 블록을 실행하기 위해 프록시 방식이 사용**되는데 
이 부분은 [1. AOP 용어](#1-aop-용어)와 [3. 스프링 AOP 와 프록시 객체](#3-스프링-aop-와-프록시-객체) 에서 설명한다.

스프링 프레임워크는 관점 지향 프로그래밍을 제공하기 위해 스프링 AOP 모듈을 제공하는데 대표적인 예시는 트랜잭션 관리, 캐시 추상화 등이 있다.  
`@Transactional`, `@Cacheable` 같은 애너테이션을 정의만 하면 되며, 개발자는 관심이 완전히 분리되어 어떻게 트랜잭션을 관리하고 캐시를 관리하는지 알 수 없다.

---

# 1. AOP 용어

A 클래스의 test() 메서드에 실행 시간을 추적하는 Logging 관점을 추가해야 하는 상황일 때 실행 시간을 추적하는 로깅 로직은 메서드의 시작 시간과 종료 시간을 측정하고, 
이 두 시간의 간격을 이용하여 실행 시간을 구할 수 있다.  
test() 메서드가 실행되기 전의 시간과 메서드 종료 시의 시간을 구하는 방식으로 실행 시간을 구할 수 있다.  
이 때 실행 시간을 구하는 로직은 ElapseLoggingAspect.java 에 있다.

아래 AOP 용어를 위의 상황에 대입하여 살펴본다.

- **대상 객체**
  - 공통 모듈을 적용할 대상
  - A 클래스가 대상 객체이고, 공통 모듈은 ElapseLoggingAspect.java
- **관점 (Aspect)**
  - AOP 프로그래밍으로 작성한 공통 모듈과 적용될 위치 정보의 조합
  - 관점은 **어드바이스와 포인트 컷을 합친 것**을 의미
  - ElapseLoggingAspect.java 클래스를 관점이라고 하며, 이 클래스는 로깅 공통 모듈인 어드바이스와 test() 메서드 위치 정보가 있는 포인트 컷을 포함하고 있음
- **어드바이스**
  - 애플리케이션의 **공통 로직이 작성된 모듈로 메서드 형태**임
  - 메서드의 실행 시간을 구하는 로깅 로직을 의미
  - 관점과 어드바이스의 차이점은 어드바이스가 적용될 위치 정보인 포인트 컷의 유무임 (= 관점은 포인터 컷의 정보를 포함)
- **포인트 컷 (Point cut)**
  - **어드바이스를 적용할 위치(=조인 포인트)를 선정하는 설정**
  - 어드바이스는 포인트 컷으로 적용될 위치가 결정되고, 그 시점에 어드바이스가 실행됨
  - **포인트 컷 표현식으로 설정, 특정 애너테이션으로 지정 가능**
    - 포인트 컷 표현식으로 지정: `@Around(value="execution(* com.assu.study.chap07.*.*(..))")`
    - 특정 애너테이션으로 지정: `@Around("@annotation(ElapseLoggable)")`
    - [4. 포인트 컷과 표현식](#4-포인트-컷과-표현식) 에 좀 더 상세한 설명 있음
  - A 클래스의 test() 메서드를 선정하는 설정을 포인트 컷이라고 함
- **조인 포인트 (Join Points)**
  - **어드바이스가 적용된 위치**
  - 즉, Logging 어드바이스를 적용할 A 클래스의 test() 메서드가 조인 포인트임
  - 포인트 컷은 조인 포인트를 선정하는 것을 의미
- **위빙 (Weaving)**
  - **조인 포인트에 실행할 코드인 어드바이스를 끼워넣는 과정**
- **프록시 객체**
  - 스프링 AOP 는 관점 클래스와 대상 클래스의 기능을 조합하기 위해 동적으로 프록시 객체를 생성함
  - 이 프록시 객체가 관점 클래스와 대상 클래스의 기능을 실행함 (= 대상 클래스의 메서드를 호출하는 클래스는 결국 프록시 객체의 메서드를 실행)
  - 즉, 생성된 프록시 객체는 ElapseLoggingAspect.java 의 어드바이스 코드를 실행하고, 다시 test() 메서드를 실행하는 순서임

---

# 2. 어드바이스: `@Before`, `@After`, `@AfterReturning`, `@AfterThrowing`, `@Around`

어드바이스는 관점의 일부이자 공통 로직이 작성된 모듈이다.  
프록시 객체는 어드바이스 종류에 따라 호출된 대상 메서드의 앞뒤에 어드바이스 로직을 추가한다.

- 서버 클래스
  - 객체 지향 프로그래밍에서 메서드를 제공하는 클래스
- 클라이언트 클래스
  - 메서드를 호출하는 클래스

<**AOP 의 어드바이스 로직을 적용할 수 있는 위치**>  
- 클라이언트 클래스가 서버 클래스의 메서드를 실행하기 전
- 실행된 서버 클래스의 메서드가 성공적으로 기능을 실행하고 메서드를 리턴한 후
- 실행된 서버 클래스의 메서드 내부에 예외가 발생하여 메서드가 예외를 던진 후


<**어드바이스 종류**>  
- `@Before`
- `@After`
- `@AfterReturning`
- `@AfterThrowing`
- `@Around`

![Before 어드바이스와 After 어드바이스의 실행 시점](/assets/img/dev/2023/0826/before_after.png)

`@Before` 어드바이스는 서버 클래스의 메서드를 실행하기 전에 실행되며 어드바이스 모듈인 메서드 선언부에  `@Before` 애너테이션을 정의하여 사용한다.

`@After` 어드바이스는 서버 클래스의 메서드를 실행한 후 실행되며 어드바이스 모듈인 메서드 선언부에  `@After` 애너테이션을 정의하여 사용한다.  
`@After` 어드바이스는 메서드가 성공적으로 리턴될 때와 에러가 발생하여 예외를 발생할 때 모두 실행된다.  
이 `@After` 어드바이스를 좀 더 세분화하면 아래의 `@AfterReturning` 과 `@AfterThrowing` 으로 분류할 수 있다.

![AfterReturning 어드바이스와 AfterThrowing 어드바이스의 실행 시점](/assets/img/dev/2023/0826/after_two.png)


![Around 어드바이스의 실행 시점](/assets/img/dev/2023/0826/around.png)

서버 클래스의 메서드를 실행 전 후 모든 시점에 공통 모듈을 포함할 때  `@Around` 어드바이스를 사용한다.  
`@Around` 는 위의 모든 어드바이스의 실행 시점을 합친 기능이다.

아래는 `@Around` 애너테이션을 정의한 어드바이스 모듈의 예시이다.

pom.xml
```xml
<!-- AOP 설정 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
```

/aspect/ElapseLoggingAspect.java
```java
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import org.springframework.util.StopWatch;

@Slf4j
@Component
@Aspect
public class ElapseLoggingAspect {

  @Around("execution(* com.assu.study.chap07.*.*(..))") // 어드바이스를 적용할 위치(=조인 포인트)를 선정하는 포인트 컷 설정
  public Object loggingPerformance(ProceedingJoinPoint proceedingJoinPoint) throws Throwable {

    // 대상 객체의 메서드가 실행되기 전 실행될 로직
    StopWatch stopWatch = new StopWatch();
    stopWatch.start();

    log.info("start time clock.");

    Object result;
    try {
      // 대상 객체의 메서드 실행
      result = proceedingJoinPoint.proceed();
    } finally {
      // 대상 객체의 메서드가 실행된 후 실행될 로직
      stopWatch.stop();
      String methodName = proceedingJoinPoint.getSignature().getName();
      long elapsedTime = stopWatch.getLastTaskTimeMillis();
      log.info("{}, elapsed time: {} ms. ", methodName, elapsedTime);
    }

    // 대상 객체의 메서드가 실행된 후 실행될 로직
    return result;
  }
}
```

---

# 3. 스프링 AOP 와 프록시 객체

**클라이언트 클래스가 AOP 어드바이스 모듈이 적용된 서버 클래스 메서드를 호출하면 스프링 AOP 프레임워크는 대상 객체를 감싸는 프록시 객체를 동적으로 생성**한다.  
그리고 클라이언트 클래스와 서버 클래스 사이에서 **프록시 객체가 클라이언트 클래스의 요청을 가로챈 후 어드바이스 타입에 따라 어드바이스 모듈과 대상 객체의 메서드를 실행**한다.  
(= 개발자가 직접 코딩하지 않아도 자동으로 어드바이스 로직이 대상 객체에 추가되어 실행됨)  
이렇게 동작할 수 있는 것은 바로 **동적 프록시 객체** 덕분이다.

스프링 AOP 모듈은 ApplicationContext 객체의 메서드가 호출되면 IoC 컨테이너가 이를 감지하여 대상 각체를 감싸는 프록시 객체를 생성한다. 
즉, **런타임에 프록시 객체가 생성**된다.

클라이언트 클래스가 프록시 객체의 메서드를 호출하면 어드바이스 로직과 함께 대상 객체의 메서드가 동작하는데 AOP 에서는 이것을 **위빙** 이라고 한다.

스프링 AOP 는 IoC 컨테이너가 동적으로 프록시 객체를 생성하여 어드바이스 로직을 추가하므로 AOP 대상 객체와 어드바이스는 IoC 컨테이너로 관리되어야 한다.  
**IoC 컨테이너로 관리되려면 어드바이스를 포함하는 관점 클래스와 대상 클래스는 스프링 빈으로 정의**되어야 한다.    
**둘 중 하나라도 스프링 빈으로 정의되지 않으면 AOP 위빙이 되지 않는다.**

---

# 4. 포인트 컷과 표현식

포인트 컷은 어드바이스를 적용할 위치(=조인 포인트) 를 선정하는 설정, 즉 어떤 클래스의 어떤 메서드에 어드바이스 로직을 적용할 지 표현식으로 설정하는 것이다.

<**포인트 컷을 적용하는 2가지 방식**>  

- 포인트 컷 표현식으로 지정
  - `@Around(value="execution(* com.assu.study.chap07.*.*(..))")`
- 특정 애너테이션으로 지정
  - `@Around("@annotation(ElapseLoggable)")`


<**포인트 컷 표현식을 설정하는 2가지 방식**>  
- `@PointCut` 애너테이션과 포인트 컷 표현식을 사용하여 별도의 포인트 컷 정의
- 어드바이스 애너테이션의 value 속성 사용

---

## 4.1. 포인트 컷 표현식으로 포인트 컷 지정

포인트 컷의 표현식은 아래와 같다.

`execution (* com.assu.study.chap07.HotelService.getHotels(..))`

com.assu.study.chap07 패키지에 포함된 HotelService 클래스의 getHotels() 메서드이면서, 오버로딩된 모든 getHotels() 메서드 (인자가 0 개 이상이므로) 이고,
리턴 타입이 `*` 이므로 특정 클래스 타입을 지정하지 않음.

- `execution`
  - 포인트 컷 지정자
  - `execution` 외에 `within`, `@annotation` 등 설정 가능
- `*`
  - 대상 객체의 메서드가 리턴하는 클래스 타입
- `com.assu.study.chap07`
  - 패키지 경로
- `HotelService`
  - 클래스명
- `getHotels`
  - 메서드명
- `(..)`
  - 메서드 인자

위와 같이 정확한 패키지, 클래스, 메서드명을 지정해도 되지만 와일드 패턴을 이용하여 좀 더 유연하게 표현식 작성이 가능하다.

- `*`
  - 모든 클래스 타입 포함
- `..`
  - 0 개 이상의 타입 의미
- `&&`, `||`, `!`
  - AND, OR, NOT 조건

아래는 다양한 포인트 컷 표현식이다.

- `execution(* com.assu.study.chap07.HotelService.*(..))`
  - c.a.s.chap07 패키지의 HotelService 클래스에 포함된 모든 메서드
- `execution(* com.assu.study.chap07.*.*(..))`
  - c.a.s.chap07 패키지에 포함된 모든 메서드
- `execution(public * * (..))`
  - 코드베이스에 있는 모든 public 메서드들
- `execution(* *.get*(..))`
  - 코드베이스에 있는 모든 메서드 중 get 으로 시작하는 메서드들
- `execution(* *(com.assu.study.chap07.controller.HotelRequest, ..))`
  - 코드베이스에 있는 모든 메서드 중 c.a.s.chap07.controller.HotelRequest.class 를 인자로 받는 모든 메서드들
  - 패키지 경로, 클래스명, 메서드명을 지정하는 대신 모든 경로를 의미하는 `*` 지정
  - 인자 위치에 HotelRequest 클래스를 넣어서 메서드에 HotelRequest 인자가 있는 메서드만 포인트 컷으로 정의


---

### 4.1.1. `@PointCut` 애너테이션과 포인트 컷 표현식을 사용하여 별도의 포인트 컷 정의

```java
@PointCut("execution (* com.assu.study.chap07.service.*.getHotels(..))")
public void pointGetHotels() {}

@Before("pointGetHotels()") // 포인트 컷 시그니처를 사용한 `@Before` 애너테이션
public void advice(JoinPoint joinPoint) {
  ...
}
```

위에서 `@PointCut` 애너테이션이 정의된 pointGetHotels() 를 포인트 컷 시그니처 라고 하며, 다른 어드바이스에서도 사용 가능하다.

이렇게 포인트 컷을 별도로 정의하면 포인트 컷을 재사용할 수 있다는 장점이 있다.

---

### 4.1.2. 어드바이스 애너테이션의 value 속성 사용

```java
@Around("execution(* com.assu.study.chap07.*.*(..))")
public Object loggingPerformance(ProceedingJoinPoint proceedingJoinPoint) throws Throwable {
  ...
}
```

---

## 4.2. 특정 애너테이션으로 포인트 컷 지정: `@annotation`

```java
@Around("@annotation(ElapseLoggable)")
public Object printElapseTime(ProceedingJoinPoint proceedingJoinPoint) throws Throwable {
  ...
}
```

> [7. 애너테이션을 이용한 AOP](#7-애너테이션을-이용한-aop-annotation-order) 에 예시가 있습니다.

---

# 5. `JoinPoint`, `ProceedingJoinPoint`

**포인트 컷은 어드바이스 적용 대상을 선정하여, 그 선정된 위치를 조인 포인트**라고 한다.  
스프링 AOP 에서 **조인 포인트는 대상 객체의 메서드**가 된다.  

`execution (* com.assu.study.chap07.HotelService.getHotels(..))`

여기선 getHotels() 메서드가 조인 포인트이다.

스프링 프레임워크는 조인 포인트가 되는 메서드를 추상화한 org.aspectj.lang 패키지의 `JoinPoint` 와 `ProceedingJoinPoint` 인터페이스를 제공한다.

이 두 인터페이스는 대상 객체, 대상 객체의 메서드 선언부, 메서드의 인자 등을 조회할 수 있는 기능을 제공한다. (= 런타임 도중 실행되는 getHotels() 메서드 정보 조회 가능)

<**JoinPoint 인터페이스가 제공하는 주요 메서드**>  
- `Object getThis()`
  - 대상 객체를 감싸고 있는 프록시 객체 리턴
- `Object getTarget()`
  - 대상 객체 리턴
- `Object[] getArgs()`
  - 런타임 시점에서 대상 객체의 메서드에 인자를 리턴
- `Signature getSignature()`
  - 대상 객체의 메서드 시그니처 리턴
  - 리턴 객체 타입은 Signature 이며, 메서드명을 리턴하는 getName(), 메서드가 포함된 클래스 타입을 리턴하는 getDeclaringType() 등의 기능을 제공

`JoinPoint` 나 `ProceedingJoinPoint` 를 어드바이스 메서드에 인자로 선언하면 프레임워크에서 그에 맞는 적절한 객체를 주입한다.

```java
@Around("execution(* com.assu.study.chap07.*.*(..))")
public Object loggingPerformance(ProceedingJoinPoint proceedingJoinPoint) throws Throwable {
  ...
}
```

`ProceedingJoinPoint` 는 `JoinPoint` 를 상속하기 때문에 `JoinPoint` 에서 제공하는 모든 메서드를 `ProceedingJoinPoint` 에서 사용할 수 있다.  
둘 의 차이점은 **`ProceedingJoinPoint` 은 대상 객체의 메서드를 실행할 수 있는 `proceed()` 메서드를 추가로 제공**한다는 점이다.  
`proceed()` 에서드가 리턴하는 Object 는 대상 객체의 메서드가 리턴하는 객체이다. 

만일 대상 객체의 메서드에 인자를 가공하여 전달해야 한다면 `Object[] args` 인자를 사용하면 된다.

- public Object proceed() throws Throwable;
- public Object proceed(Object[] args) throws Throwable;

예를 들어 어드바이스 모듈에서 ProceedingJoinPoint 의 proceed() 메서드를 사용하면 대상 객체의 메서드인 getHotels() 메서드를 실행할 수 있다.

---

- `@Before`, `@After`, `@AfterReturning`, `@AfterThrowing` 어드바이스는 개발자가 직접 대상 객체의 메서드를 호출하지 않아도 됨  
스프링 AOP 에서 만든 프록시 객체가 대상 객체의 메서드 호출
- `@Around` 어드바이스는 개발자가 반드시 직접 대상 객체의 메서드를 호출해야 함  
Around 어드바이스가 대상 객체의 메서드를 감싸고 있는 형태라 프레임워크가 관여할 수 없음
- 따라서 `@Before`, `@After`, `@AfterReturning`, `@AfterThrowing` 어드바이스는 `JoinPoint` 객체가 필요할 때만 주입받아서 사용하면 되지만  
`@Around` 어드바이스는 반드시 `ProceedingJoinPoint` 를 주입받은 후 proceed() 메서드를 호출해야 함
- 어드바이스 메서드의 첫 번째 인자에 `JoinPoint` 혹은 `ProceedingJoinPoint` 인자 선언


---

# 6. 관점 클래스: `@Aspect`

관점 클래스는 어드바이스와 포인트 컷을 포함하고 있다.  
관점 클래스를 정의할 때는  `@Aspect` 애너테이션을 사용하며, 스프링 AOP 를 사용하므로 스프링 빈으로 정의해야 한다.

아래는 `@Before` 어드바이스를 사용하여 대상 메서드의 인자를 로그로 출력하는 예시이다.  
프록시 객체가 어드바이스의 코드를 실행한 후 대상 객체의 메서드를 호출하므로 어드바이스에 `ProceedingJoinPoint` 를 주입받을 필요가 없다. (`JoinPoint` 주입 받음)  
예시에서 조인 포인트 대상은 HotelRequest.class 를 인자로 받는 모든 메서드이다.

/aspect/ArgumentLoggingAspect.java
```java
import com.assu.study.chap07.controller.HotelRequest;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.springframework.stereotype.Component;

import java.util.Arrays;

@Slf4j
@Aspect // 관점 클래스임을 선언
@Component  // 스프링 빈으로 정의, 스프링 AOP 를 사용하여 프록시 객체를 생성하기 때문에 관점 클래스도 스프링 빈이어야 함
public class ArgumentLoggingAspect {

  // 포인트 컷은 HotelRequest 인자를 받는 모든 메서드들
  // 그래서 포인트 컷 표현식에 리턴 타입, 패키지 경로, 클래스명, 메서드명을 지정하는 대신 * 지정
  // 메서드에 HotelRequest 인자가 있는 메서드만 포인트 컷으로 정의해야 하므로 인자 위치에 HotelRequest 클래스 사용
  @Before("execution(* *(com.assu.study.chap07.controller.HotelRequest, ..))")
  public void printHotelRequestArgument(JoinPoint joinPoint) {
    
    log.info("class: {}, method: {}", joinPoint.getSignature().getDeclaringTypeName(), joinPoint.getSignature().getName());

    String argumentValue = Arrays.stream(joinPoint.getArgs()) // Stream<Object> 리턴, 조인 포인트의 인자를 배열로 응답
            .filter(obj -> HotelRequest.class.equals(obj.getClass())) // Stream<Object> 리턴, 인자들 중에서 HotelRequest.class 와 같은 클래스 타입인 객체만 필터링
            .findFirst()  // Optional<Object> 리턴
            .map(HotelRequest.class::cast)  // Optional<HotelRequest> 리턴
            .map(hotelRequest -> hotelRequest.toString()) // Optional<String> 리턴
            .orElseThrow();

    log.info("argument info: {}", argumentValue);
  }
}
```

/controller/HotelRequest.java
```java
import lombok.Getter;
import lombok.ToString;

// DTO
@Getter
@ToString
public class HotelRequest {
  private String hotelName;

  public HotelRequest() {
  }

  public HotelRequest(String hotelName) {
    this.hotelName = hotelName;
  }
}
```

/service/DisplayService.java
```java
import com.assu.study.chap07.controller.HotelRequest;
import com.assu.study.chap07.controller.HotelResponse;

import java.util.List;

public interface DisplayService {
  List<HotelResponse> getHotelsByName(HotelRequest hotRequest);
}
```

/service/HotelDisplayService.java
```java
import com.assu.study.chap07.controller.HotelRequest;
import com.assu.study.chap07.controller.HotelResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.concurrent.TimeUnit;

@Service
@Slf4j
public class HotelDisplayService implements DisplayService {
  @Override
  public List<HotelResponse> getHotelsByName(HotelRequest hotRequest) {
    try {
      TimeUnit.SECONDS.sleep(5);
    } catch (InterruptedException e) {
      log.error("error!", e);
    }

    return List.of(
        new HotelResponse(1_000L, "Assu Hotel~", "Seoul Gangnam", "+821112222")
    );
  }
}
```


/controller/HotelResponse.java
```java
import lombok.Getter;
import lombok.ToString;

// DTO
@ToString
@Getter
public class HotelResponse {
  private final Long hotelId;
  private final String hotelName;
  private final String address;
  private final String phoneNumber;

  public HotelResponse(Long hotelId, String hotelName, String address, String phoneNumber) {
    this.hotelId = hotelId;
    this.hotelName = hotelName;
    this.address = address;
    this.phoneNumber = phoneNumber;
  }
}
```

/controller/HotelController.java
```java
import com.assu.study.chap07.service.HotelDisplayService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@Slf4j
public class HotelController {
  private final HotelDisplayService hotelDisplayService;

  public HotelController(HotelDisplayService hotelDisplayService) {
    this.hotelDisplayService = hotelDisplayService;
  }

  @PostMapping("/hotels/name")
  public ResponseEntity<List<HotelResponse>> getHotelByName(@RequestBody HotelRequest hotelRequest) {
    List<HotelResponse> hotelResponse = hotelDisplayService.getHotelsByName(hotelRequest);
    return ResponseEntity.ok(hotelResponse);
  }
}
```

이제 /hotels/name API 를 호출해보자.

```shell
$ curl --location 'http://localhost:18080/hotels/name' \
--header 'Content-Type: application/json' \
--data '{
    "hotelName": "hahaha"
}' | jq

[
  {
    "hotelId": 1000,
    "hotelName": "Assu Hotel~",
    "address": "Seoul Gangnam",
    "phoneNumber": "+821112222"
  }
]
```

```shell
c.a.s.c.aspect.ArgumentLoggingAspect     : class: com.assu.study.chap07.controller.HotelController, method: getHotelByName
c.a.s.c.aspect.ArgumentLoggingAspect     : argument info: HotelRequest(hotelName=hahaha)

c.a.s.c.aspect.ArgumentLoggingAspect     : class: com.assu.study.chap07.service.HotelDisplayService, method: getHotelsByName
c.a.s.c.aspect.ArgumentLoggingAspect     : argument info: HotelRequest(hotelName=hahaha)
```

HotelRequest 를 인자로 받는 HotelController.getHotelByName() 와 HotelDisplayService.getHotelsByName() 호출 시 로그가 출력되는 것을 알 수 있다.

---

아래는 `@AfterReturning`, `@AfterThrowing` 어드바이스를 사용하여 대상 메서드의 리턴값과 예외를 로그로 남기는 예시이다.

/aspect/ReturnValueLoggingAspect.java
```java
import com.assu.study.chap07.controller.HotelResponse;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.AfterReturning;
import org.aspectj.lang.annotation.AfterThrowing;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;

import java.util.List;

@Slf4j
@Component
@Aspect
public class ReturnValueLoggingAspect {
  // 대상 객체의 메서드가 리턴하는 객체를 어드바이스 메서드의 인자로 받을 수 있도록 변수명 설정
  // Object 클래스 타입으로 받아 메서드 내부에서 타입 변환을 할 수도 있지만 List<HotelResponse> 처럼 클래스 타입을 정의하여 받아도 됨
  @AfterReturning(pointcut = "execution(* getHotelsByName(..))", returning = "customReturnValues")
  public void printReturnObject(JoinPoint joinPoint, List<HotelResponse> customReturnValues) { 
    customReturnValues.stream()
        .forEach(response -> log.info("return value: {}", response));
  }

  // 대상 객체의 메서드가 던지는 예외 객체를 어드바이스 메서드의 인자로 받을 수 있도록 변수명 설정
  @AfterThrowing(pointcut = "execution(* getHotelsByName(..))", throwing = "customThrowable")
  public void printThrowable(JoinPoint joinPoint, Throwable customThrowable) {
    log.error("error processing", customThrowable);
  }
}
```

```shell
$ curl --location 'http://localhost:18080/hotels/name' \
--header 'Content-Type: application/json' \
--data '{
    "hotelName": "hahaha"
}'
```

`@AfterReturning` 가 동작한 예시
```shell
c.a.s.c.aspect.ReturnValueLoggingAspect  : return value: HotelResponse(hotelId=1000, hotelName=Assu Hotel~, address=Seoul Gangnam, phoneNumber=+821112222)
```

`@AfterThrowing` 가 동작한 예시
```shell
2023-09-29T19:10:23.602+09:00 ERROR 62778 --- [io-18080-exec-1] c.a.s.c.aspect.ReturnValueLoggingAspect  : error processing

java.lang.RuntimeException: test exception
	at com.assu.study.chap07.service.HotelDisplayService.getHotelsByName(HotelDisplayService.java:16) ~[classes/:na]
```

---

# 7. 애너테이션을 이용한 AOP: `@annotation`, `@Order`

아래와 같은 상황을 보자.  

성능이 나쁜 API 의 성능 저하 원인 분석 중 스카우터의 메서드 프로파일링 탭을 통해 API 코드에서는 확인할 수 없는 다른 클래스의 코드가 실행 시간 대부분을 차지하고 
있다고 하자. 이 때는 AOP 관점 클래스가 잘못 개발되었을 가능성이 높다.  
이 때 포인트 컷 표현식으로 작성된 관점 클래스를 찾기는 매우 힘들다.

위와 같은 상황은 핵심 관심사와 종단 관심사가 완전히 분리되어 오히려 유지 보수에 어려움이 있는 케이스이다. 이것은 관점 지향 프로그래밍의 단점이기도 하다.

**포인트 컷 표현식이 아닌 사용자 정의 애너테이션을 사용하여 포인트 컷을 지정하면 유지 보수할 때 빠르게 관점 클래스를 찾을 수 있다.**

아래는 개발자가 직접 생성한 ElapseLoggable 애너테이션과 해당 애너테이션을 사용하여 `@Around` 어드바이스를 사용한 예시이다.  
이 때 대상 객체의 메서드는 HotelDisplayService 클래스의 getHotelsByName() 이다.  
ElapseLoggable 애너테이션을 getHotelsByName() 메서드에 정의하여 조인 포인트로 설정할 수 있다.

/aspect/ElapseLoggable.java
```java
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
public @interface ElapseLoggable {  // 포인트 컷을 지정하는 마킹 애너테이션이므로 별도의 속성값을 설정하지 않음
}
```

/service/HotelDisplayService.java
```java
@Service
@Slf4j
public class HotelDisplayService implements DisplayService {
  @Override
  @ElapseLoggable // 메서드 처리 시간을 로깅하기 위해 @ElapseLoggable 애너테이션 정의, 해당 애너테이션의 @Target 설정은 ElementType.METHOD 이므로 메서드에만 사용 가능
  public List<HotelResponse> getHotelsByName(HotelRequest hotRequest) {

    //  throw new RuntimeException("test exception");

    try {
      TimeUnit.SECONDS.sleep(5);
    } catch (InterruptedException e) {
      log.error("error!", e);
    }

    return List.of(
        new HotelResponse(1_000L, "Assu Hotel~", "Seoul Gangnam", "+821112222")
    );
  }
}
```

/aspect/ElapseLoggingAspect.java
```java
package com.assu.study.chap07.aspect;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.util.StopWatch;

@Slf4j
@Component
@Aspect
@Order(2) // 다른 여러 관점 클래스의 위빙 순서 결정
public class ElapseLoggingAspect {

  //@Around("execution(* com.assu.study.chap07.*.*(..))") // 어드바이스를 적용할 위치(=조인 포인트)를 선정하는 포인트 컷 설정
  @Around("@annotation(ElapseLoggable)")
  public Object loggingPerformance(ProceedingJoinPoint proceedingJoinPoint) throws Throwable {

    // 대상 객체의 메서드가 실행되기 전 실행될 로직
    StopWatch stopWatch = new StopWatch();
    stopWatch.start();

    log.info("start time clock.");

    Object result;
    try {
      // 대상 객체의 메서드 실행
      result = proceedingJoinPoint.proceed();
    } finally {
      // 대상 객체의 메서드가 실행된 후 실행될 로직
      stopWatch.stop();
      String methodName = proceedingJoinPoint.getSignature().getName();
      long elapsedTime = stopWatch.getLastTaskTimeMillis();
      log.info("{}, elapsed time: {} ms. ", methodName, elapsedTime);
    }

    // proceedingJoinPoint.proceed() 의 결과값을 반드시 리턴해야 함
    return result;
  }
}
```

**_어드바이스 작성 시 조인 포인트에서 발생하는 예외를 어드바이스 내부에서 직접 처리하는 것은 위험_**하다.

ElapseLoggingAspect 에서도 try-finally 구문만 사용하여 메서드의 실행 시간 로그를 남기고, 대상 객체의 메서드인 getHotelsByName() 에서드에서 발생하는 예외를 
그대로 다시 던지도록 loggingPerformance() 메서드 시그니처에 throws Throwable 로 선언되어 있다.

스프링 프레임워크는 RuntimeException 이 발생하면 프레임워크 내부에서 이를 이용하여 처리하는 로직들이 있다.  
예를 들어 트랜잭션 기능을 제공하는 `@Transactional` 은 RuntimeException 이 발생하면 진행 중인 트랜잭션을 롤백하여 사용하던 커넥션 객체를 
커넥션 풀에 다시 반환한다.

근데 만일 loggingPerformance() **_어드바이스가 예외를 다시 던지지 않고 직접 처리한다면 트랜잭션 매니저의 예외 처리 부분이 정상적으로 동작하지 않고, 
커넥션 객체도 정상적으로 커넥션 풀에 반환되지 않아 커넥션 객체가 고갈_**될 수 있다.

대상 객체에 하나 이상의 어드바이스 코드를 위빙하는 경우 `@Order` 애너테이션으로 스프링 빈의 순서를 조정할 수 있다.

만일 `@Order(2)`, `@Order(1)` 이 있다면 2 → 1 의 순으로 진행된다. 

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)