---
layout: post
title:  "Spring Boot - 데이터 영속성(6): 엔티티 상태 이벤트 처리, 트랜잭션 생명주기 동기화 작업"
date:   2023-09-17
categories: dev
tags: springboot msa database entity-listeners osiv transaction-lifecycle
---

이 포스팅에서는 트랜잭션 이벤트를 사용하여 애플리케이션 기능을 확장하는 방법에 대해 알아본다. 

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap08) 에 있습니다.

---

**목차**

- [엔티티 상태 이벤트 처리: `@EntityListeners`](#1-엔티티-상태-이벤트-처리-entitylisteners)
- [트랜잭션 생명주기 동기화 작업](#2-트랜잭션-생명주기-동기화-작업)
  - [스프링 부트 프레임워크의 OSIV 설정](#21-스프링-부트-프레임워크의-osiv-설정)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.4
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap08

![Spring Initializer](/assets/img/dev/2023/0902/init.png)

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

  <artifactId>chap08</artifactId>

  <dependencies>
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

    <!--        <dependency>-->
    <!--            <groupId>mysql</groupId>-->
    <!--            <artifactId>mysql-connector-java</artifactId>-->
    <!--            <version>8.0.33</version>-->
    <!--        </dependency>-->

    <!-- 테스트 -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>

    <dependency>
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

</project>
```

---

# 1. 엔티티 상태 이벤트 처리: `@EntityListeners`

JPA 에서는 엔티티 객체의 상태가 변경되면 상황에 맞는 이벤트를 발행한다.  
그리고 이 이벤트를 수신하여 개발자가 새롭게 정의한 콜백 함수를 호출하는 기능을 제공한다.  

이 과정은 자바 클래스와 애너테이션을 적용하여 구현할 수 있으며, JPA 프레임워크에서 제공하는 애너테이션들은 크게 두 가지로 분류할 수 있다.

- 이벤트 종류에 따라 실행할 콜백 메서드를 정의하는 애너테이션
- 이벤트가 발생하는 엔티티 클래스와 콜백 메서드를 포함하는 리스너 클래스를 매핑하는 애너테이션

<**엔티티 상태 이벤트 처리 과정**>  
- 이벤트를 수신하고 처리하는 리스너 클래스 생성
- 처리할 상태 변경 이벤트를 선택하고 이벤트에 따른 애너테이션을 콜백 메서드에 선언  
이벤트가 발생하면 실행할 콜백 메서드들은 리스너 클래스에 정의함
- 이벤트 대상 엔티티와 리스너 클래스 매핑  
대상 엔티티 객체의 상태가 변경되어 이벤트가 발생하면 엔티티 클래스와 매핑된 리스너 클래스가 이벤트를 처리  
결국 리스너 클래스 내부에 정의된 적절한 콜백 메서드가 실행됨

---

영속성 컨텍스트는 엔티티 객체의 생명 주기를 관리하여, 생명 주기에 따라 엔티티 객체의 상태(state) 를 정의할 수 있다.

![영속성 컨텍스트의 엔티티 객체 상태도](/assets/img/dev/2023/0916/persistence_context.png)

엔티티 객체는 비영속 상태, 영속 상태, 준영속 상태, 삭제 상태가 될 수 있고, 이런 상태들은 영속성 컨텍스트의 동작과 관련이 있다.  
엔티티 객체를 로딩/생성/수정/삭제하는 동작이 될 수 있다.

<**생명 주기와 관련된 이벤트를 처리할 수 있는 애너테이션**>  
- `@PrePersist`
  - 엔티티 객체가 영속 상태가 되기 전 발생하는 이벤트를 처리
  - EntityManager 의 `persist()` 메서드가 호출되기 직전에 발생
- `@PostPersist`
  - 엔티티 객체가 영속 상태가 된 후 발생하는 이벤트를 처리
- `@PreRemove`
  - 영속 상태의 엔티티 객체가 삭제 상태가 되기 전 발생하는 이벤트를 처리
  - EntityManager 의 `remove()` 메서드가 호출되기 직전에 발생
- `@PostRemove`
  - 영속 상태의 엔티티 객체가 삭제 상태가 된 후 발생하는 이벤트를 처리
- `@PreUpdate`
  - 영속 상태의 엔티티 객체가 변경되어 영속성 컨텍스트가 데이터베이스에 동기화하기 전 발생하는 이벤트를 처리
  - 즉, UPDATE 쿼리를 실행하기 전에 발생하는 이벤트를 처리
- `@PostUpdate`
  - 영속 상태의 엔티티 객체가 변경되어 영속성 컨텍스트가 데이터베이스에 동기화된 후 발생하는 이벤트를 처리
- `@PostLoad`
  - 영속성 컨텍스트에 엔티티 객체가 로딩되면 발생하는 이벤트를 처리

---

**`@EntityListeners` 애터네이션은 이벤트가 발생하는 엔티티 클래스와 리스너 클래스를 매핑하는 기능**을 제공한다.  

`@EntityListeners` 애너테이션은 엔티티 클래스에 선언하며, `@EntityListeners` 의 `value` 속성에 리스너 클래스를 정의한다.  
`@EntityListeners` 애너테이션이 정의된 엔티티 객체의 상태가 변경되면 `@EntityListeners` 속성값에 정의된 리스너 클래스의 콜백 메서드가 동작한다.

/domain/HotelEntity.java
```java
@Entity(name = "hotels")
@EntityListeners(HotelAuditListener.class)    // 한 개 이상의 리스너 클래스 설정 가능
public class HotelEntity extends AbstractManageEntity {
  // ...
}
```

/service/EventAuditListener.java
```java
package com.assu.stury.chap08.service;

import com.assu.stury.chap08.domain.HotelEntity;
import jakarta.persistence.PostPersist;
import jakarta.persistence.PostRemove;
import jakarta.persistence.PostUpdate;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class HotelAuditListener {
  // HotelEntity 객체가 생성된 후 발생하는 이벤트 처리
  // logWhenCreated() 메서드가 콜백 메서드
  // HotelEntity 객체가 생성되면 logWhenCreated() 메서드가 실행됨
  // 콜백 메서드의 인자는 이벤트가 발생한 HotelEntity 객체를 인자로 주입받을 수 있음
  @PostPersist
  public void logWhenCreated(HotelEntity hotelEntity) {
    log.info("hotel created. id: {}", hotelEntity.getHotelId());
  }

  // 여러 애너테이션을 중복해서 사용할 수도 있음
  @PostUpdate
  @PostRemove
  public void logWhenChanged(HotelEntity hotelEntity) {
    log.info("hotel changed. id: {}, name: {}", hotelEntity.getHotelId(), hotelEntity.getName());
  }
}
```

엔티티 객체의 상태 변경 이벤트를 처리하는 메커니즘은 JPA 프레임워크에서 제공하는 기능이다.  
스프링 프레임워크가 아니므로 ApplicationContext 가 리스너 클래스와 기능을 관리하지 않기 때문에 엔티티 클래스와 매핑되는 리스너 클래스는 스프링 빈으로 정의할 필요가 없다.

---

# 2. 트랜잭션 생명주기 동기화 작업

데이터베이스의 트랜잭션 생명주기는 트랜잭션의 시작/종료로 매우 간단하다.  

스프링 프레임워크는 트랜잭션의 생명주기에 맞춰서 콜백 메서드를 실행할 수 있는 메커니즘을 제공한다.  
즉, 트랜잭션의 생명주기에 맞춰서 개발자가 필요한 기능을 추가할 수 있다.

o.s.transaction.support 패키지의 `TransactionaSynchronizationManager` 와 `TransactionSynchronization` 를 사용하면 
트랜잭션 생명주기에 맞춰서 실행할 수 있는 콜백 메서드를 추가할 수 있다.

`@Transactional` 애너테이션은 [스프링 AOP](https://assu10.github.io/dev/2023/08/26/springboot-aop/) 를 사용하여 트랜잭션 기능을 하기 때문에 애플리케이션이 실행될 때 프록시 객체가 대상 메서드를 감싸서 어드바이스 코드와 함께 
대상 메서드를 실행한다.

대상 메서드 내부에서는 트랜잭션의 종료 시점을 정확하게 판단하기 어렵고, 트랜잭션의 처리 결과를 판단할 수 없기 때문에 트랜잭션의 종료 시점에 특정 작업을 추가해야 할 때 
트랜잭션 대상 메서드 내부에 코드를 추가하기가 어렵다.  

트랜잭션의 종료 시점은 `@Transactional` 애너테이션의 `propagation` 속성과 메서드 호출 구조에 따라 달라진다.  

트랜잭션이 AOP 로 구현되었기 때문에 commit 혹은 rollback 여부도 트랜잭션 대상 메서드 내부에서는 알기 어렵다.  

만일 대상 메서드 내부에 트랜잭션 종료 시점에 실행할 로직을 추가할 수 있다면 코드 응집력을 높일 수 있다.

스프링 프레임워크에서 제공하는 `TransactionaSynchronizationManager` 와 `TransactionSynchronization` 를 사용하면 트랜잭션 대상 메서드 내부에서 
트랜잭션 생명주기에 동기화하여 콜백 함수를 추가할 수 있다.  
즉, **대상 메서드 내부에 트랜잭션의 종료 시점에 실행할 코드를 추가할 수 있다.**

`TransactionSynchronization` 는 트랜잭션의 생명주기에 동기화하여 실행할 수 있는 메서드를 제공하는 추상 클래스이다.  

개발자는 `TransactionSynchronization` 추상 클래스를 상속받는 구현 클래스를 작성하고 필요한 추상 메서드들을 구현하면 된다.  
구현 클래스가 트랜잭션 매니저에 추가된 후 트랜잭션 생명주기에 동기화된 적절한 시점에 콜백 함수들이 실행된다.

아래는 `TransactionSynchronization` 코드이다.
```java
package org.springframework.transaction.support;

public interface TransactionSynchronization extends Ordered, Flushable {

  /** Completion status in case of proper commit. */
  int STATUS_COMMITTED = 0;

  /** Completion status in case of proper rollback. */
  int STATUS_ROLLED_BACK = 1;

  /** Completion status in case of heuristic mixed completion or system errors. */
  int STATUS_UNKNOWN = 2;


  @Override
  default int getOrder() {
    return Ordered.LOWEST_PRECEDENCE;
  }

  default void suspend() {
  }

  default void resume() {
  }

  @Override
  default void flush() {
  }

  // 트랜잭션 종료 시점에서 commit 커맨드를 실행하기 전에 실행하는 콜백 메서드
  default void beforeCommit(boolean readOnly) {
  }

  // 트랜잭션 종료 시점에서 commit 이나 rollback 커맨드를 실행하기 전에 실행하는 콜백 메서드
  default void beforeCompletion() {
  }

  // 트랜잭션 종료 시점에서 commit 커맨드를 실행한 후 실행하는 콜백 메서드
  default void afterCommit() {
  }
  
  // 트랜잭션 종료 시점에서 commit 이나 rollback 커맨드를 실행한 후 실행하는 콜백 메서드
  default void afterCompletion(int status) {
  }
}
```

`beforeCommit()` 과 `afterCommit()` 은 실행 시점의 차이가 있는데 `afterCommit()` 은 트랜잭션의 commit 여부를 보장하는 척도가 된다.

`afterCommit()` 은 트랜잭션 commit 명령어 이후에 실행이 되기 때문에 commit 명령어가 정상적으로 실행됨을 보장한다.  

commit 명령어를 정상적으로 실행하지 못하면 예외가 발생하고 트랜잭션은 롤백되기 때문에 `afterCommit()` 메서드는 실행되지 않는다.  
이는 `beforeCompletion()` 이나 `afterCompletion()` 도 마찬가지이다.

`afterCompletion()` 메서드는 status 인자를 받는데 이 인자를 확인하면 콜백 메서드 내부에서 트랜잭션의 종료 상태를 확인할 수 있다.

```java
/** Completion status in case of proper commit. */
int STATUS_COMMITTED = 0;

/** Completion status in case of proper rollback. */
int STATUS_ROLLED_BACK = 1;

/** Completion status in case of heuristic mixed completion or system errors. */
int STATUS_UNKNOWN = 2;
```

---

`TransactionSynchronizationManager` 의 `registerSynchronization()` 메서드를 사용하면 `TransactionSynchronization` 구현 클래스의 콜백 메서드를 
현재 스레드에 등록할 수 있다.

아래는 `TransactionSynchronization` 익명 클래스로 필요한 메서드만 구현한 예시이다.

/service/HotelService.java
```java
@Transactional(readOnly = false, isolation = Isolation.SERIALIZABLE)
public HotelCreateResponse createHotel(HotelCreateRequest createRequest) {
  //... 

  hotelRepository.save(hotelEntity);

  TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
    @Override
    public void afterCommit() {
      log.info("---afterCommit");
      billingApiAdapter.registerHotelCode(hotelEntity.getHotelId()); // 커밋이 되면 다른 스프링 빈의 regisgerHotelCode() 실행
    }
  });

  return HotelCreateResponse.of(hotelEntity.getHotelId());
}
```

---

MSA 환경에서 데이터를 처리하고 다른 서버와 협업하는 일은 매우 흔하다.  
이 때 데이터를 처리하는 작업과 다른 서버와 협업하는 작업 모두를 100% 동기화하기는 쉽지 않다.  
비즈니스 로직에 따라 두 작업의 우선순위를 결정하면 트랜잭션 동기화 기능을 사용하는 여부를 결정할 수 있다.

예를 들어서 위 코드에서 billingApiAdapter 작업이 더 중요하다면 createHotel() 메서드 안에서 호출한다.  
billingApiAdapter 의 메서드를 실행할 때 예외가 생긴다면 RuntimeException 을 발생하여 트랜잭션을 롤백할 수 있다.  
정상 실행되었더라도 billingApiAdapter 의 메서드의 응답값에 따라 createHotel() 메서드를 종류할 수도 있다.  
createHotel() 트랜잭션을 종료하는 과정에서 예외가 발생하더라도 billingApiAdapter 의 메서드는 트랜잭션 종료 전에 이미 실행을 완료한 상태이므로 적어도 
중요한 작업인 billingApiAdapter 의 실행은 보장할 수 있다.

만일 createHotel() 의 메서드가 더 중요하다면 try-catch 구문을 사용하여 billingApiAdapter 의 메서드를 예외 처리한다.  
그러면 적어도 billingApiAdapter 의 예외나 응답 결과에 상관없이 createHotel() 을 처리할 수 있다.

만일 **createHotel() 메서드가 정상 실행되고 billingApiAdapter 의 메서드를 실행해야 한다면 `TransactionSynchronization` 을 사용하여 트랜잭션 동기화 기능을 사용**하는 것이 좋다.  
물론 콜백 메서드에 추가한 billingApiAdapter 의 메서드가 실패할 수도 있는데 이 때는 스프링 프레임워크에서 제공하는 `@Retryable` 애너테이션 기능을 사용하여 
재시도하면 된다. (혹은 신뢰성이 높은 메시지 큐를 고려하는 것도 좋다.)

---

## 2.1. 스프링 부트 프레임워크의 OSIV 설정

JPA/Hibernate 에서는 영속성 컨텍슽의 생명주기를 트랜잭션 범위를 넘어서 스프링 MVC 의 View 까지 확장하여 사용할 수 있는데 이를 **OSIV (Open Session In View)** 라고 한다.  

> 영속성 컨텍스트 역할을 하는 JPA 의 EntityManager 를 Hibernate 프레임워크에서는 Session 이라고 부르기 때문에 그 약자를 따서 Open Session In View 라고 함

스프링 부트 프레임워크에서는 기본 설정으로 OSIV 가 true 로 설정되어 있다.

application.properties
```properties
spring.jpa.open-in-view=true
```

만일 OSIV 기능을 사용하지 않도록 프레임워크를 설정했다면 영속성 컨텍스트는 아래와 같은 절차로 동작한다.

영속성 컨텍스트 생명주기는 트랜잭션과 함께 한다.  
트랜잭션이 시작하면 영속성 컨텍스트가 생성되고, 트랜잭션이 종료되면 같이 종료된다.  
영속성 컨텍스트는 멀티 스레드에 안전하지 않으므로 스레드마다 새로 생성되고, 새로 생성될 때마다 데이터베이스와 통신을 하기 위한 Connection 객체를 커넥션 풀에서 하나씩 획득한다.  
엔티티 객체를 처리하고 트랜잭션을 종료할 때 영속성 컨텍스트도 같이 종료되며, 이 때 Connection 객체도 커넥션 풀에 반환한다.

먼저 OSIV 가 활성화되었을 때 영속성 컨텍스트의 생명주기를 보자. (굵은 화살표가 영속성 컨텍스트의 생명 주기)  
아래 그림은 OpenEntityManagerInViewFilter 필터가 설정된 상태를 가정한 것이다.

![OSIV 가 활성화되었을 때 영속성 컨텍스트의 생명주기](/assets/img/dev/2023/0917/osiv_true.png)


일반적인 웹 애플리케이션 구조에서 사용자 요청을 가장 먼저 처리하는 것은 스프링 MVC 의 Filter 와 Interceptor 이다.  
위 그림을 보면 영속성 컨텍스트는 필터에서 생성되어 다시 필터에서 종료된다.  
**일반적인 OSIV 설정에서 영속성 컨텍스트는 트랜잭션이 시작되는 서비스 클래스에서 생성되고 View 에서 종료**된다.  
영속성 컨텍스트를 지원하는 필터나 인터셉터를 스프링 MVC 프레임워크에 설정하면 영속성 컨텍스트의 생명주기를 확장할 수 있다.

아래는 영속성 컨텍스트의 생명주기를 확장하는 구현체이다.
- Filter: o.s.orm.jpa.support.OpenEntityManagerInViewFilter
- Interceptor: o.s.orm.jpa.support.OpenEntityManagerInViewInterceptor

먼저 필터에서 영속성 컨텍스트를 생성하고, 트랜잭션이 시작되는 서비스 클래스에서는 이미 생성된 영속성 컨텍스트를 이용한다.  
(영속성 컨텍스트는 스레드마다 하나씩 생성됨)  
서비스 클래스가 종료되면 트랜잭션도 같이 종료되며, 이 때 EntityManager 의 `flush()` 메서드가 실행되어 영속성 컨텍스트의 엔티티 객체들은 데이터베이스에 동기화된다.  
하지만 영속성 컨텍스트는 종료되지 않고 유지되므로 엔티티 객체들은 영속 상태로 유지될 수 있다.  
따라서 컨트롤러 클래스나 View 에서 영속성 컨텍스트를 사용하여 엔티티 객체를 조회할 수 있다.  
또한 지연 로딩 기능을 사용하여 연관 관계에 있는 엔티티 객체를 조회하면 데이터베이스에 추가적으로 SELECT 쿼리를 실행할 수 있다.  
트랜잭션은 종료되었지만 Connection 객체는 영속성 컨텍스트와 그 생명주기를 같이 하기 때문에 조회가 가능하다.  

OSIV 모드에서는 지연 로딩을 컨트롤러 클래스나 View 에서도 사용 가능하다. 영속성 컨텍스트가 아직 종료되지 않았기 때문이다.

OSIV 는 지연 로딩을 컨트롤러 클래스나 View 에서요 사용할 수 있는 장점이 있지만 아래와 같은 단점이 있다.

<**OSIV 단점**>  
- 영속성 컨텍스트의 생명주기가 길어지면서 Connection 객체를 점유하는 시간이 길어짐
  - 따라서 OSIV 모드에서는 평상보다 많은 Connection 객체를 생성하도록 커넥션 풀을 설정해야 함
  - 결국 데이터베이스나 애플리케이션 서버 모두 리소스를 많이 소모함
- 트랜잭션 범위를 벗어난 컨트롤러 클래스나 뷰에서 엔티티 객체를 수정하면 TransactionRequiredException 예외가 발생하거나 수정된 값이 데이터베이스에 저장되지 않음
  
**REST-API 애플리케이션에서는 OSIV 를 비활성화하는 것을 추천**한다.  
OSIV 를 비활성화하면 시스템의 리소스를 절약할 수 있고, 영속성 컨텍스트의 생명주기와 커넥션 객체의 사용 범위, 트랜잭션의 시작과 종료 시점이 일치하기 때문에 애플리케이션의 
복잡성을 주여서 잠재적인 버그를 줄일 수 있다.

아래는 OSIV 를 비활성화했을 때의 영속성 컨텍스트, 트랜잭션, 커넥션 객체의 생명 주기이다.

![OSIV 가 비활성화되었을 때 영속성 컨텍스트의 생명주기](/assets/img/dev/2023/0917/osiv_false.png)

Connection 의 획득 반환 주기가 짧은 것을 확인할 수 있다.

OSIV 사용할 수 없는 컨트롤러 클래스에서는 지연 로딩을 사용하면 안된다.

<**OSIV 를 비활성화했을 때의 주의점**>  
- 컨트롤러 클래스에서는 다른 엔티티 객체를 참조하는 코드를 사용하지 않아아 함
- 서비스 클래스의 메서드가 응답하는 엔티티 객체와 연관 관계에 있는 엔티티들은 즉시 로딩하여 응답
- 서비스 클래스의 메서드가 응답할 때는 엔티티 클래스 타입이 아닌 DTO 나 Value 클래스 타입을 리턴
  - 그래서 컨트롤러 클래스에서 지연 로딩을 할 수 없는 구조로 만듦

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [hibernate 6.2 공홈](https://docs.jboss.org/hibernate/orm/6.2/)
* [트랜잭션 overrideafterCommit, beforeCommit ..](https://kdhyo98.tistory.com/127)