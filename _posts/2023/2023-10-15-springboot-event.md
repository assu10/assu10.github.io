---
layout: post
title:  "Spring Boot - 스프링 이벤트"
date:   2023-10-15
categories: dev
tags: springboot msa spring-event event-listener application-event-multicaster application-event application-event-publisher application-listener transactional-event-listener
---

이 포스트에서는 아래와 같은 내용을 다룰 예정이다.
- 애플리케이션에서 필요한 이벤트 메시지를 사용자가 직접 정의한 후, 이를 스프링 이벤트를 이용해서 전파
- 멀티 스레드 비동기 방식을 이용하여 이벤트 메시지를 구독하는 2가지 방법
  - 이벤트 메시지를 전달하는 `ApplicationEventMulticaster` 를 설정
  - `@Async` 애너테이션 사용
- 스프링 애플리케이션에서 미리 정의해서 제공하는 이벤트 메시지의 종류 및 사용
- 트랜잭션이 종료하는 시점(= 커밋, 롤백)에 따라 구독한 이벤트를 실행

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap12) 에 있습니다.

---

**목차**
<!-- TOC -->
* [1. 스프링 이벤트](#1-스프링-이벤트)
* [2. 사용자 정의 이벤트 처리](#2-사용자-정의-이벤트-처리)
  * [이벤트 메시지 클래스](#이벤트-메시지-클래스)
  * [게시 클래스](#게시-클래스)
  * [구독 클래스](#구독-클래스)
  * [실행](#실행)
* [3. 비동기 사용자 정의 이벤트 처리: `ApplicationEventMultiCaster` (참고만)](#3-비동기-사용자-정의-이벤트-처리-applicationeventmulticaster-참고만)
* [4. `@Async` 애너테이션을 사용한 비동기 이벤트 처리: `@Async`, `@EnableAsync`](#4-async-애너테이션을-사용한-비동기-이벤트-처리-async-enableasync)
* [5. `@EventListener` (참고만)](#5-eventlistener-참고만)
  * [이벤트 메시지 클래스](#이벤트-메시지-클래스-1)
  * [게시 클래스](#게시-클래스-1)
  * [구독 클래스](#구독-클래스-1)
  * [실행](#실행-1)
* [6. 스프링 애플리케이션 이벤트](#6-스프링-애플리케이션-이벤트)
  * [이벤트 메시지 클래스](#이벤트-메시지-클래스-2)
  * [게시 클래스](#게시-클래스-2)
  * [구독 클래스](#구독-클래스-2)
  * [실행](#실행-2)
* [7. 트랜잭션 시점에 구독한 이벤트 처리: `@TransactionalEventListener`](#7-트랜잭션-시점에-구독한-이벤트-처리-transactionaleventlistener)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.5
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap12

![Spring Initializer](/assets/img/dev/2023/1015/init.png)

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

    <artifactId>chap12</artifactId>

    <dependencies>
        <!-- Spring Data JPA, Hibernate, aop, jdbc -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
    </dependencies>
</project>
```

스프링 프레임워크는 다양한 타입의 이벤트 메시지를 게시/구독할 수 있는 스프링 이벤트를 제공한다.

**스프링 이벤트와 외부 시스템 메시지 브로커 (RabbitMQ, ActiveMQ 등) 를 사용하는 이벤트 처리 아키텍처는 비슷하지만 그 목적이 다르다.**

- **메시지 브로커 아키텍처**
  - 스프링 이벤트처럼 메시지를 게시하고 구독하지만 프로세스와 프로세스, 인스턴스와 인스턴스 사이에 이벤트 메시지를 게시하고 구독하는 목적임
  - 이 때 메시지 브로커가 중간에서 이벤트 메시지를 전달하는 큐 역할을 함
  - 따라서 프로세스 사이에 서로 데이터를 주고 받을 수 있음
  - 메시지를 게시/구독하는 과정에서 신뢰성을 보장하므로 데이터 누락없이 이벤트 메시지 전파 가능
  - MSA 환경에서 한 컴포넌트에서 다른 여러 컴포넌트에 데이터를 전파하는 목적으로 사용하거나, 메시지 큐에 메시지를 쌓아두고 주기적으로 배치 프로세싱을 하는데 주로 사용
- **스프링 이벤트**
  - 스프링 애플리케이션 내부에서 이벤트를 게시/구독하는 목적으로 사용
  - 이 때 ApplicationContext 는 메시지 큐처럼 이벤트 메시지를 전달하는 역할을 함
  - 애플리케이션 내부에서 객체와 객체 사이에 이벤트 메시지 전달
  - 이 때 싱글 스레드 뿐 아니라 멀티 스레드로 이벤트를 구독/처리 가능
  - 따라서 메시지 큐 아키텍처와 스프링 이벤트는 사용하는 목적이 다름

---

# 1. 스프링 이벤트

<**스프링 이벤트 장점**>  
- 이벤트를 게시하는 클래스와 구독하는 클래스의 의존 관계 분리
- 이벤트를 게시/구독하는 클래스를 비동기로 처리 가능
- 게시한 하나의 이벤트 메시지를 여러 개의 구독 클래스가 수신 가능
- 스프링 이벤트를 이용하여 트랜잭션을 효율적으로 사용 가능

예를 들어 회원 가입 시 쿠폰을 이메일로 발송하는 이벤트를 진행하는데, 이 이벤트의 내용은 다른 이벤트로 변경될 수 있으며 
이미 회원 가입 프로세스는 복잡하여 이벤트 관련 기능을 추가하는 것은 코드의 복잡도를 높일 수 있는 상황일 때 
스프링 이벤트를 사용하여 가입 기능과 쿠폰 발송 이벤트 기능을 분리할 수 있다.

만일 위 기능을 스프링 이벤트 기능을 사용하지 않는다고 하면 아래와 같이 비즈니스 로직이 구성될 것이다.

```java
package com.springtour.example.chapter12.service;

@Slf4j
@Service
public class UserService {

    @Autowired
    private EventService eventService;
    
    public Boolean createUser(String userName, String emailAddress) {
        // 사용자 생성 로직 생략
        eventService.sendEventMail(eventAddress);
        return Boolean.TRUE;
    }
}
```

위 코드에서 UserService 클래스는 주요 기능이고, EventService 클래스는 부가 기능이며, 상황에 따라 EventService 를 사용하지 않을 수도 있지만 사용자를 생성하는 UserService 는 
이벤트 기능에 따라 변경되지 않는다. 즉, 두 기능은 서로 관련이 없으므로 서로 분리하여 결합도를 낮추는 것이 유지 보수에 유리하다.

---

**스레드 풀을 스프링 이벤트에 적용하면 이벤트 처리 부분을 비동기로 처리**할 수 있다.  

즉, 사용자를 가입시키는 createUser() 를 실행하는 스레드와 쿠폰 이메일을 발송하는 sendEventMail() 을 실행하는 스레드를 분리할 수 있다.  
createUser() 메서드가 종료되면 사용자에게 REST-API 응답을 하고, 애플리케이션 내부에서는 sendEventMail() 메서드를 동시에 실행하므로 별도의 스레드에서 동작하는 시간만큼 
사용자에게 빠르게 응답할 수 있다.

---

**스프링 이벤트를 활용하면 시스템 리소스도 효과적으로 사용**할 수 있다.  

예를 들어 createUser() 가 1,2,3 테이블에 트랜잭션과 함께 CRUD 쿼리를 사용하고, sendEventMail() 이 3,4,5 테이블에 트랜젹션과 함께 CRUD 쿼리를 사용한다고 할 때, 
이 두 기능을 하나의 트랜잭션에서 실행하면 트랜잭션 시간이 길어지고, 쿼리하는 데이터가 많아질수록 해당 리소스에 락을 유지하는 시간이 길어서 데드락이 발생할 확률이 높아진다.  

이 두 로직을 두 개의 트랜잭션으로 분리하면 데이터베이스 리소스를 효율적으로 사용할 수 있다.  

또한 sendEventMail() 메서드에 적용된 **트랜잭션도 정교하게 사용**할 수 있다.  
ApplicationContext 는 트랜잭션 종료 시점을 여러 단계로 구분하여 정의된 단계에서 이벤트를 처리할 수 있도록 제공한다.  

예를 들어 sendEventMail() 에 쿼리 기능과 이메일을 전송하는 SMTP 연동 코드가 있을 경우 기본적으로 SMTP 의 API 를 호출하는 시간까지 트랜잭션 처리 시간에 포함되겠지만, 
ApplicationContext 를 이용하면 트랜잭션이 정상적으로 커밋된 후 SMTP 의 API 를 호출하게 함으로써 트랜잭션을 보다 효율적으로 관리할 수 있게 된다.

---

# 2. 사용자 정의 이벤트 처리

이벤트 메시지를 게시/구독하려면 3개의 클래스가 필요하다.

- **이벤트 메시지 클래스**
  - 게시 클래스와 구독 클래스 사이에 공유할 데이터를 포함하는 클래스
- **게시 클래스**
  - 구독 클래스에 전달할 이벤트 메시지를 생산하고 게시하는 클래스
  - 게시: ApplicationContext 에 이벤트 메시지를 전달
- **구독 클래스**
  - ApplicationContext 에서 전달받은 이벤트 메시지를 구독하고 부가 기능을 실행하는 클래스
  - 구독: ApplicationContext 에서 이벤트 메시지를 전달받음

ApplicationContext 에 이벤트를 게시하고 구독하는 메커니즘을 사용하려면 스프링 프레임워크에서 제공하는 기능을 사용해야 한다.

- `o.s.context.ApplicationEvnet`
  - 이벤트 메시지 클래스가 상속받아야 하는 클래스
- `o.s.context.ApplicationEventPublisher`
  - 이벤트 메시지를 게시할 수 있는 `publishEvent()` 메서드 제공
  - 이벤트 메시지를 게시하려면 ApplicationEventPublisher 스프링 빈을 주입받아 `publishEvent()` 메서드를 실행해야 하므로 게시 클래스에서 사용
- `o.s.context.ApplicationListener`
  - 이벤트 메시지를 구독할 수 있는 `onApplicationEvent()` 메서드 제공
  - 구독 클래스가 구현해야 하는 인터페이스
  - 스프링 4.2 버전부터는 `@EventListener` 애너테이션 사용 가능하지만 추천하지 않음 (이유는 [6. 스프링 애플리케이션 이벤트](#6-스프링-애플리케이션-이벤트) 참고)

ApplicationContext 가 이벤트 메시지의 타입을 확인하고 적절한 구독 클래스의 `onApplicationEvent()` 를 찾으며, 이벤트 메시지 객체를 인자로 넣어 실행한다.  
ApplicationContext 가 이 과정을 처리하려면 게시 클래스와 구독 클래스 모두 스프링 빈으로 로딩되어야 한다.

---

## 이벤트 메시지 클래스

event > user > UserEvent.java
```java
import org.springframework.context.ApplicationEvent;

// 이벤트 메시지 클래스
// 불변(immutable) 클래스 이어야 하므로 Setter 는 없음
// 유저를 생성/삭제할 때 게시할 목적으로 사용됨
@Getter
public final class UserEvent extends ApplicationEvent {   // 이벤트 메시지 클래스이므로 ApplicationEvent 상속
    private final Type type;
    private final Long userId;
    private final String email;

    private UserEvent(Object source, Type type, Long userId, String email) {
        // Object source 는 이벤트를 게시하는 클래스의 객체를 의미
        // 예를 들어 UserService 클래스에서 UserEvent 객체를 생성/게시할 때 UserService 객체를 Object source 인자로 넘김
        // ApplicationEvent 객체에 할당된 Object source 는 Object getSource() 로 참조 가능
        super(source);

        this.type = type;
        this.userId = userId;
        this.email = email;
    }

    // 정적 팩토리 메서드
    public static UserEvent created(Object source, Long userId, String email) {
        return new UserEvent(source, Type.CREATE, userId, email);
    }

    public enum Type {
      CREATE, DELETE
    }
}
```

게시 클래스와 구독 클래스는 ApplicationContext 로 분리되어 있으며, 오직 이벤트 메시지 객체로만 서로 주고받을 수 있으므로, 이벤트 메시지 객체는 구독 클래스에서 필요한 정보를 포함하는 것이 좋다.  
UserEvent 이벤트 메시지 객체에 userId 정보가 없다면 구독 클래스에서 필요한 사용자 정보를 DB 에서도 조회할 수 없다.

> 구독 클래스에서 필요한 정보가 있을 때 구독 클래스에서 불필요한 쿼리를 줄이려면 게시 클래스에서 구독 클래스에 필요한 모든 정보를 전달한다.

---

## 게시 클래스

아래는 UserEvent 이벤트 메시지 객체를 게시할 수 있는 UserEventPublisher 게시 클래스이다.

event > user > UserEventPublisher.java
```java
package com.assu.study.chap12.event;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

// 게시 클래스
@Slf4j
@Component
public class UserEventPublisher {
    // ApplicationEventPublisher 스프링 빈 주입받음
    private final ApplicationEventPublisher applicationEventPublisher;

    public UserEventPublisher(ApplicationEventPublisher applicationEventPublisher) {
        this.applicationEventPublisher = applicationEventPublisher;
    }

    // 이벤트가 발생하는 클래스에서 호출
    public void publishUserCreated(Long userId, String email) {
        UserEvent userEvent = UserEvent.created(this, userId, email);
        log.info("Publish user created event.");
        
        // UserEvent 이벤트 메시지 객체 게시
        applicationEventPublisher.publishEvent(userEvent);
    }
}
```

service > UserService.java
```java
import com.assu.study.chap12.event.UserEventPublisher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class UserService {
    private final UserEventPublisher userEventPublisher;

    public UserService(UserEventPublisher userEventPublisher) {
        this.userEventPublisher = userEventPublisher;
    }

    public Boolean createUser(String userName, String email) {
        // 사용자 생성 로직 생략
        log.info("created user. {}, {}", userName, email);

        userEventPublisher.publishUserCreated(11111L, email);
        log.info("done create user event publish.");

        return Boolean.TRUE;
    }
}
```

---

## 구독 클래스

아래는 UserEvent 를 구독하여 이벤트를 처리하는 UserEventListener 구독 클래스이다.

service > EmailService.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class EventService {
    public void sendEventEmail(String email) {
        // 이메일 발송
        log.info("Send Email~, {}", email);
    }
}
```

event > user > UserEventListener.java
```java
import com.assu.study.chap12.service.EventService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationListener;
import org.springframework.stereotype.Component;

// 구독 클래스
@Slf4j
@Component
public class UserEventListener implements ApplicationListener<UserEvent> {  // ApplicationListener 의 제네릭 클래스 타입은 구독할 이벤트의 클래스 타입

    // 기능을 실행할 스프링 빈 주입
    // UserEventListener 구독 클래스는 UserEvent 를 구독하는 기능만 담당하고, 실제 이벤트 처리는 별도의 클래스(EventService)에 위임
    private final EventService eventService;

    public UserEventListener(EventService eventService) {
        this.eventService = eventService;
    }

    @Override
    public void onApplicationEvent(UserEvent event) {
        if (UserEvent.Type.CREATE == event.getType()) {
            log.info("Listen CREATE event. {}, {}", event.getUserId(), event.getEmail());
            // 메일 발송
            eventService.sendEventEmail(event.getEmail());
        } else if (UserEvent.Type.DELETE == event.getType()) {
            log.info("Listen DELETE event.");
        } else {
            log.error("Unsupported event type. {}", event.getType());
        }
    }
}
```

위 코드를 보면 UserService 와 EventService 는 서로 의존성이 없다. 따라서 **이벤트가 변경되어도 UserService 의 코드에는 변경 사항이 발생하지 않는다.**

---

## 실행

event > server > ApplicationEventListener.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.ApplicationListener;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

@Slf4j
public class ApplicationEventListener implements ApplicationListener<ApplicationReadyEvent> {
    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        long timestamp = event.getTimestamp();
        LocalDateTime eventTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(timestamp), ZoneId.systemDefault());

        log.info("Application is Ready. {}", eventTime);
    }
}
```

/Chap12SyncApplication.java
```java
package com.assu.study.chap12;

import com.assu.study.chap12.server.ApplicationEventListener;
import com.assu.study.chap12.service.UserService;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;

@SpringBootApplication
public class Chap12SyncApplication {
  public static void main(String[] args) {
    // SpringApplication 객체와 ApplicationContext 를 설정할 수 있는 메서드를 제공하는 SpringApplicationBuilder 클래스 사용
    SpringApplicationBuilder builder = new SpringApplicationBuilder(Chap12SyncApplication.class);
    // build() 를 호출하여 SpringApplication 객체 생성
    SpringApplication application = builder.build();
    // addListener() 는 하나 이상의 ApplicationListener 객체들을 받음
    application.addListeners(new ApplicationEventListener());

    // run() 을 이용하여 스프링 부트 애플리케이션 실행
    ConfigurableApplicationContext ctxt = application.run(args);

    UserService userService = ctxt.getBean(UserService.class);
    userService.createUser("Assu", "assu@test.com");
  }
}
```

```shell
2023-12-08T15:21:23.661+09:00  INFO 26219 --- [  restartedMain] c.a.s.c.server.ApplicationEventListener  : Application is Ready. 2023-12-08T15:21:23.661
2023-12-08T15:21:23.664+09:00  INFO 26219 --- [  restartedMain] c.assu.study.chap12.service.UserService  : created user. Assu, assu@test.com
2023-12-08T15:21:23.664+09:00  INFO 26219 --- [  restartedMain] c.a.s.chap12.event.UserEventPublisher    : Publish user created event.
2023-12-08T15:21:23.664+09:00  INFO 26219 --- [  restartedMain] c.a.s.chap12.event.UserEventListener     : Listen CREATE event. 11111, assu@test.com
2023-12-08T15:21:23.664+09:00  INFO 26219 --- [  restartedMain] c.a.study.chap12.service.EventService    : Send Email~, assu@test.com
2023-12-08T15:21:23.664+09:00  INFO 26219 --- [  restartedMain] c.assu.study.chap12.service.UserService  : done create user event publish.
```

로그를 보면 모두 하나의 스레드인 restartedMain 으로 실행된 것을 확인할 수 있다.  
UserService → UserEventPublisher → UserEventListener → EventService 순으로 메서드가 실행되고, 메서드의 종료는 역순으로 끝난다.

UserEvent, UserEventPublisher, UserEventListener 클래스는 UserService 와 EventService 의 관계를 느슨하게 만들지만, **모든 클래스가 하나의 공통 스레드에서 실행되기 때문에 리소스 낭비가 발생**할 수 있다.

만일 UserService 의 createUser() 에 `@Transactional` 을 선언하여 트랜잭션이 실행된다면 모든 메서드가 종료되고 createUser() 메서드도 종료되어야 해당 트랜잭션이 종료된다.

`ApplicationEventMultiCaster` 를 설정하여 이러한 문제를 해결할 수 있다. 

---

# 3. 비동기 사용자 정의 이벤트 처리: `ApplicationEventMultiCaster` (참고만)

> 최종적으로는 `@Async`, `@EnableAsync`, `ApplicationListener` 를 사용하므로 해당 내용은 참고만 하자.

ApplicationEventPublisher 의 `publishEvent()` 를 사용하여 이벤트 메시지를 게시하면 ApplicationContext 내부에서는 `ApplicationEventMultiCaster` 로 이벤트 메시지를 게시한다.

만일 이 때 별도의 설정이 없다면 `ApplicationEventMultiCaster` 는 싱글 스레드로 동작하는데 여기선 `ApplicationEventMultiCaster` 를 설정하여 멀티 스레드로 이벤트를 구독하는 법에 대해 알아본다.

AbstractApplicationContext.java
```java
public abstract class AbstractApplicationContext extends DefaultResourceLoader implements ConfigurableApplicationContext {
  public static final String APPLICATION_EVENT_MULTICASTER_BEAN_NAME = "applicationEventMulticaster";
  // ...
  private ApplicationEventMulticaster applicationEventMulticaster;
}
```

AbstractApplicationContext 는 ApplicationEventMulticaster 를 클래스 속성으로 가진다.  
ApplicationEventMulticaster 는 인터페이스이고, 스프링 프레임워크에서는 SimpleApplicationEventMulticaster 구현체를 제공한다.

기본값으로 설정된 ApplicationContext 내부에서는 SimpleApplicationEventMulticaster 객체를 생성 후 사용하는데 이 때 SimpleApplicationEventMulticaster 에 별도의 
스레드 풀이 없다면 ApplicationEventPublisher 의 `publishEvent()` 메서드가 실행된 스레드에서 이벤트 게시/구독이 모두 일어난다. (=하나의 스레드에서 이벤트 게시/구독)

AbstractApplicationContext 내부에서는 APPLICATION_EVENT_MULTICASTER_BEAN_NAME 상수로 정의된 'applicationEventMulticaster' 를 사용하여 스프링 빈을 찾는데, 
만일 찾지 못하면 새로운 SimpleApplicationEventMulticaster 를 생성하고, 스프링 빈이 정의되어 있다면 해당 스프링 빈을 사용한다.

개발자가 직접 스프링 빈 이름을 'applicationEventMulticaster' 로 설정하면 비동기로 이벤트를 구독할 수 있다.

위의 [2. 사용자 정의 이벤트 처리](#2-사용자-정의-이벤트-처리) 에서 구현한 게시/구독 클래스의 수정없이 비동기로 이벤트를 구독할 수 있다.

config > AsyncEventConfig.java
```java
package com.assu.study.chap12.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.ApplicationEventMulticaster;
import org.springframework.context.event.SimpleApplicationEventMulticaster;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
public class AsyncEventConfig {
    @Bean("applicationEventMulticaster")    // 반드시 AbstractApplicationContext 에서 지정한 스프링 빈 이름으로 설정
    public ApplicationEventMulticaster applicationEventMulticaster(TaskExecutor asyncEventTaskExecutor) {
        SimpleApplicationEventMulticaster eventMulticaster = new SimpleApplicationEventMulticaster();
        eventMulticaster.setTaskExecutor(asyncEventTaskExecutor);   // 스레드 풀 설정
        return eventMulticaster;
    }

    @Bean
    public TaskExecutor asyncEventTaskExecutor() {
        ThreadPoolTaskExecutor asyncEventTaskExecutor = new ThreadPoolTaskExecutor();
        // 스레드 풀의 개수는 최대 10개까지 늘어남
        asyncEventTaskExecutor.setMaxPoolSize(10);
        // 스레드 풀의 이름은 eventExecutor- 로 시작함
        asyncEventTaskExecutor.setThreadNamePrefix("eventExecutor-");
        // 컨테이너가 모든 속성값을 적용한 후 initialize() 호출
        asyncEventTaskExecutor.afterPropertiesSet();

        return asyncEventTaskExecutor;
    }
}
```

이제 다시 Chap12SyncApplication 를 실행하면 아래와 같은 로그를 볼 수 있다.
```shell
2023-12-08T16:16:51.662+09:00  INFO 30944 --- [  restartedMain] c.assu.study.chap12.service.UserService  : created user. Assu, assu@test.com
2023-12-08T16:16:51.663+09:00  INFO 30944 --- [eventExecutor-1] c.a.s.c.server.ApplicationEventListener  : Application is Ready. 2023-12-08T16:16:51.662
2023-12-08T16:16:51.663+09:00  INFO 30944 --- [  restartedMain] c.a.s.chap12.event.UserEventPublisher    : Publish user created event.
2023-12-08T16:16:51.664+09:00  INFO 30944 --- [  restartedMain] c.assu.study.chap12.service.UserService  : done create user event publish.
2023-12-08T16:16:51.664+09:00  INFO 30944 --- [eventExecutor-1] c.a.s.chap12.event.UserEventListener     : Listen CREATE event. 11111, assu@test.com
2023-12-08T16:16:51.664+09:00  INFO 30944 --- [eventExecutor-1] c.a.study.chap12.service.EventService    : Send Email~, assu@test.com
```

UserService 를 실행하는 스레드인 restartedMain 은 이벤트를 게시하는 UserPublisher 의 `publishUserCreated()` 메서드까지 실행한다. (스레드 #1)    
그리고 메시지를 구독하는 UserEventListener 와 이벤트를 처리하는 EventService 는 eventExecutor-1 스레드에서 실행된다. (스레드 #2)

스레드 #1 사용자를 생성하는 로직을 담당, 스레드 #2 이벤트 메일을 보내는 로직을 담당한다.

---

# 4. `@Async` 애너테이션을 사용한 비동기 이벤트 처리: `@Async`, `@EnableAsync`

스프링 프레임워크는 비동기 프로그래밍을 위한 `@Async` 와 `@EnableAsync` 애너테이션을 제공한다.

이 둘은 스프링 AOP 로 구현된 메커니즘으로 간단히 애너테이션을 선언하여 사용이 가능하다.

`@EnableAsync` 는 비동기 기능을 활성화하는 역할을 하며, 자바 설정 클래스에 선언한다.  

`@Async` 는 비동기로 실행하고 싶은 스프링 빈의 메서드나 클래스에 선언한다.  
클래스에 선언하면 해당 클래스의 모든 public 메서드는 비동기로 동작한다.

`@Async` 애너테이션이 정상적으로 동작하려면 아래 조건을 만족해야 한다.
- `@Async` 대상은 스프링 빈으로 정의되어 있어야 함
- public 메서드만 비동기로 동작함
- this 키워드가 아닌 자기 주입을 사용하여 자신의 메서드를 호출해야 함

비동기 기능이 활성화된 상태에서 **`@Async` 가 정의된 메서드를 실행하면 매번 새로운 스레드를 생성하여 실행**하므로 **서버의 리소스를 효율적으로 사용하기 위해선 스레드 풀을 생성하여 함께 사용**하는 것이 좋다.  

스레드 풀은 java.util.concurrent 의 Executor 인터페이스 구현체를 사용하면 된다. 

>  [3. 비동기 사용자 정의 이벤트 처리: `ApplicationEventMultiCaster` (참고만)](#3-비동기-사용자-정의-이벤트-처리-applicationeventmulticaster-참고만) 에서 사용한 ThreadPoolExecutor 로 Executor 의 구현체 중 하나임

---

스프링 프레임워크는 비동기 실행 환경을 설정할 수 있는 o.s.scheduling.annotation 패키지의 `AsyncConfigurer` 인터페이스를 제공한다.  
AsyncConfigurer 인터페이스의 `getAsyncExecutor()` 메서드를 구현하면 `@Async` 가 사용하는 스레드 풀을 설정할 수 있다. (=`@Async` 애너테이션과 스레드 풀의 스레드를 사용하려면 `AsyncConfigurer` 인터페이스를 구현하면 됨)

config > AsyncExecutionConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@EnableAsync    // 비동기 기능 활성화
@Configuration
public class AsyncExecutionConfig implements AsyncConfigurer {
    // 프레임워크가 스레드 풀을 설정할 때 사용하는 콜백 메서드
    @Override
    public Executor getAsyncExecutor() {
        return getExecutor();
    }

    private Executor getExecutor() {
        ThreadPoolTaskExecutor threadPoolTaskExecutor = new ThreadPoolTaskExecutor();
        // 기본 개수는 10개
        threadPoolTaskExecutor.setCorePoolSize(10);
        // 최대 10개까지 늘어남
        threadPoolTaskExecutor.setMaxPoolSize(10);
        threadPoolTaskExecutor.setThreadNamePrefix("asyncExecutor-");
        // 컨테이너가 모든 속성값을 적용한 후 initialize() 호출
        threadPoolTaskExecutor.afterPropertiesSet();
        return threadPoolTaskExecutor;
    }

    @Bean("asyncExecutor")
    public Executor asyncExecutor() {
        return getExecutor();
    }
}
```

---

`@Async` 애너테이션 기능을 하용하면 `ApplicationEventMulticaster` 에 스레드 풀을 설정하지 않아도 비동기 이벤트 프로그래밍이 가능하며, 원하는 로직만 비동기로 구현 가능하다.

`ApplicationEventMulticaster` 에 스레드 풀을 설정하면 이벤트를 구독하는 모든 구독 클래스가 비동기로 실행되지만, `@Async` 애너테이션을 사용하면 원하는 이벤트 구독 메서드만 선택적으로 비동기 실행이 가능하다.

[3. 비동기 사용자 정의 이벤트 처리: `ApplicationEventMultiCaster` (참고만)](#3-비동기-사용자-정의-이벤트-처리-applicationeventmulticaster-참고만) 에서 설정한 ApplicationEventMulticaster 기능을 끄기 위해 아래와 같이 스프링 빈 이름을 주석처리한다.

config > AsyncEventConfig.java
```java
//@Configuration
public class AsyncEventConfig {
  //@Bean("applicationEventMulticaster")    // 반드시 AbstractApplicationContext 에서 지정한 스프링 빈 이름으로 설정
  public ApplicationEventMulticaster applicationEventMulticaster(TaskExecutor asyncEventTaskExecutor) {
    SimpleApplicationEventMulticaster eventMulticaster = new SimpleApplicationEventMulticaster();
    eventMulticaster.setTaskExecutor(asyncEventTaskExecutor);   // 스레드 풀 설정
    return eventMulticaster;
  }
  // ...
}
```

그리고 구독 클래스인 UserEventListener 의 `onApplicationEvent()` 에 `@Async` 애너테이션을 적용하면 `onApplicationEvent()` 와 그 메서드가 호출하는 EventService 의 sendEventEmail() 까지 다른 스레드에서 실행된다.

```java
// 구독 클래스
@Slf4j
@Component
public class UserEventListener implements ApplicationListener<UserEvent> {  // ApplicationListener 의 제네릭 클래스 타입은 구독할 이벤트의 클래스 타입

// ...
    @Async
    @Override
    public void onApplicationEvent(UserEvent event) {
        if (UserEvent.Type.CREATE == event.getType()) {
            log.info("Listen CREATE event. {}, {}", event.getUserId(), event.getEmail());
            // 메일 발송
            eventService.sendEventEmail(event.getEmail());
        } else if (UserEvent.Type.DELETE == event.getType()) {
            log.info("Listen DELETE event.");
        } else {
            log.error("Unsupported event type. {}", event.getType());
        }
    }
}
```

```shell
2023-12-08T16:43:03.612+09:00  INFO 33115 --- [  restartedMain] c.assu.study.chap12.service.UserService  : created user. Assu, assu@test.com
2023-12-08T16:43:03.612+09:00  INFO 33115 --- [  restartedMain] c.a.s.chap12.event.UserEventPublisher    : Publish user created event.
2023-12-08T16:43:03.614+09:00  INFO 33115 --- [  restartedMain] c.assu.study.chap12.service.UserService  : done create user event publish.
2023-12-08T16:43:03.615+09:00  INFO 33115 --- [asyncExecutor-1] c.a.s.chap12.event.UserEventListener     : Listen CREATE event. 11111, assu@test.com
2023-12-08T16:43:03.615+09:00  INFO 33115 --- [asyncExecutor-1] c.a.study.chap12.service.EventService    : Send Email~, assu@test.com
```

---

# 5. `@EventListener` (참고만)

> 최종적으로는 `@Async`, `@EnableAsync`, `ApplicationListener` 를 사용하므로 해당 내용은 참고만 하자.

[2. 사용자 정의 이벤트 처리](#2-사용자-정의-이벤트-처리) 에서 구독 클래스인 UserEventListener 는 이벤트를 구독하기 위해 ApplicationListener 인터페이스를 구현하였다.  
스프링 4.2 버전부터는 `@EventListener` 애너테이션을 사용할 수 있다.

---

## 이벤트 메시지 클래스

**이벤트 메시지 객체는 불변 (immutable) 클래스로 설계**해야 한다. (= 한번 생성된 이벤트 메시지 객체의 속성은 변경되면 안됨)

게시 클래스가 게시한 이벤트 메시지 객체는 모든 구독 클래스가 공유하는 데이터이다.  
만일 첫 번째 이벤트 구독 클래스가 이벤트 객체의 데이터를 수정하면, 두 번째 이벤트 구독 클래스에 영향이 가서 버그가 발생할 수 있다.

불변 클래스로 선언하는 법은 [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/) 를 참고하세요.


event > hotel > HotelCreateEvent.java
```java
package com.assu.study.chap12.event.hotel;

import lombok.Getter;
import lombok.ToString;

// 이벤트 메시지 클래스
// 불변(immutable) 클래스 이어야 하므로 Setter 는 없음
@Getter
@ToString
public final class HotelCreateEvent {
    private final Long hotelId;
    private final String hotelAddr;

    private HotelCreateEvent(Long hotelId, String hotelAddr) {
        this.hotelId = hotelId;
        this.hotelAddr = hotelAddr;
    }

    // 정적 팩토리 메서드 패턴
    public static HotelCreateEvent of(Long hotelId, String hotelAddr) {
        return new HotelCreateEvent(hotelId, hotelAddr);
    }
}
```

---

## 게시 클래스

event > hotel > HotelEventPublisher.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

// 게시 클래스
@Slf4j
@Component
public class HotelEventPublisher {
    // ApplicationEventPublisher 스프링 빈 주입받음
    private final ApplicationEventPublisher applicationEventPublisher;

    public HotelEventPublisher(ApplicationEventPublisher applicationEventPublisher) {
        this.applicationEventPublisher = applicationEventPublisher;
    }
    
    // 이벤트가 발생하는 클래스에서 호출
    public void publishHotelCreated(Long hotelId, String addr) {
        HotelCreateEvent event = HotelCreateEvent.of(hotelId, addr);
        log.info("Publish hotel created event.");
        
        // HotelCreateEvent 이벤트 메시지 객체 게시
        applicationEventPublisher.publishEvent(event);
    }
}
```

service > HotelService.java
```java
import com.assu.study.chap12.event.hotel.HotelEventPublisher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class HotelService {
    private final HotelEventPublisher hotelEventPublisher;

    public HotelService(HotelEventPublisher hotelEventPublisher) {
        this.hotelEventPublisher = hotelEventPublisher;
    }

    public Boolean createHotel(String hotelName, String hotelAddr) {
        // 호텔 생성 로직 생략
        log.info("created hotel. {}, {}", hotelName, hotelAddr);
        hotelEventPublisher.publishHotelCreated(2222L, hotelAddr);
        log.info("done create hotel publish.")
        ;
        return Boolean.TRUE;
    }
}
```

---

## 구독 클래스

service > PropagationService.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class PropagationService {
    public void propagateHotelEvent() {
        log.info("propagation of hotel event");
    }

    public void propagateResourceEvent() {
        log.info("propagation of resource event");
    }
}
```

event > hotel > HotelEventListener.java
```java
package com.assu.study.chap12.event.hotel;

import com.assu.study.chap12.service.PropagationService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

// 구독 클래스
@Slf4j
@Component
public class HotelEventListener {

    // 기능을 실행할 스프링 빈 주입
    // HotelEventListener 구독 클래스는 구독만 하고, 실제 이벤트 처리는 별도의 클래스(PropagationService)에 위임
    private final PropagationService propagationService;

    public HotelEventListener(PropagationService propagationService) {
        this.propagationService = propagationService;
    }

    @Async
    @Order(1)
    // 하나 이상의 클래스 타입 설정 가능
    // 정의된 이벤트 메시지가 게시되면 @EventListener 애너테이션이 정의된 메서드가 이벤트를 구독하고 실행함
    @EventListener(value = HotelCreateEvent.class)
    // 구독한 이벤트 객체를 메서드의 인자로 받을 수 있음
    public void handleHotelCreateEvent(HotelCreateEvent hotelCreateEvent) {
        log.info("handle HotelCreatedEvent : {}", hotelCreateEvent);
        propagationService.propagateHotelEvent();
    }

    @Async
    @Order(2)
    @EventListener(value = HotelCreateEvent.class)
    public void handleResourceCreateEvent(HotelCreateEvent hotelCreateEvent) {
        log.info("handle resourceCreatedEvent : {}", hotelCreateEvent);
        propagationService.propagateResourceEvent();
    }
}
```

이벤트 메시지는 한번 발행되지만 두 번 이상 수신할 수 있는데 이런 상황에서는 멀티 스레드 환경에서 이벤트를 구독하는 것을 고려해볼 수 있다.

싱글 스레드에서 여러 구독 클래스를 실행해야 한다면 `@Order` 애너테이션을 사용하여 실행 순서를 설정하는 것도 좋다.

---

## 실행

```java
import com.assu.study.chap12.service.HotelService;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

@SpringBootApplication
public class Chap12ASyncApplication {

    public static void main(String[] args) {
        ConfigurableApplicationContext ctxt =
                SpringApplication.run(Chap12ASyncApplication.class, args);

        HotelService hotelService = ctxt.getBean(HotelService.class);
        hotelService.createHotel("ASSU", "Seoul");
    }

}
```

```shell
2023-12-08T17:32:21.826+09:00  INFO 37137 --- [  restartedMain] c.a.study.chap12.service.HotelService    : created hotel. ASSU, Seoul
2023-12-08T17:32:21.828+09:00  INFO 37137 --- [  restartedMain] c.a.s.c.event.hotel.HotelEventPublisher  : Publish hotel created event.
2023-12-08T17:32:21.830+09:00  INFO 37137 --- [  restartedMain] c.a.study.chap12.service.HotelService    : done create hotel publish.
2023-12-08T17:32:21.830+09:00  INFO 37137 --- [asyncExecutor-1] c.a.s.c.event.hotel.HotelEventListener   : handle HotelCreatedEvent : HotelCreateEvent(hotelId=2222, hotelAddr=Seoul)
2023-12-08T17:32:21.830+09:00  INFO 37137 --- [asyncExecutor-2] c.a.s.c.event.hotel.HotelEventListener   : handle resourceCreatedEvent : HotelCreateEvent(hotelId=2222, hotelAddr=Seoul)
2023-12-08T17:32:21.830+09:00  INFO 37137 --- [asyncExecutor-2] c.a.s.chap12.service.PropagationService  : propagation of resource event
2023-12-08T17:32:21.830+09:00  INFO 37137 --- [asyncExecutor-1] c.a.s.chap12.service.PropagationService  : propagation of hotel event
```

각 구독 클래스가 asyncExecutor-1, asyncExecutor-2 다른 스레드에서 실행되는 것을 확인할 수 있다.

---

# 6. 스프링 애플리케이션 이벤트

[2. 사용자 정의 이벤트 처리 - 실행](https://assu10.github.io/dev/2023/10/15/springboot-event/#%EC%8B%A4%ED%96%89) 을 보면 `ApplicationReadyEvent` 인터페이스를 구현하여 메시지 구독을 하고 있다.

스프링 프레임워크는 스프링 애플리케이션이 시작~실행 가능한 상태까지 발생할 수 있는 여러 이벤트를 미리 정의하고 이를 게시하는 기능을 제공한다.

- `ApplicationStartingEvent`
  - 애플리케이션이 시작하는 시점에 발생하는 이벤트
  - 스프링 빈 스캔 및 로딩 작업 시작 전
  - 단, ApplicationContext 의 리스너나 이니셜라이저를 등록하는 과정은 실행된 상태
- `ApplicationEnvironmentPreparedEvent`
  - ApplicationContext 에서 사용하는 환경 설정 객체인 Environment 가 사용 준비된 시점에 발생하는 이벤트
  - 단, ApplicationContext 객체가 생성되기 전에 발생
- `ApplicationContextInitializedEvent`
  - ApplicationContext 가 준비되고, ApplicationContextInitializer 를 호출한 후 발생하는 이벤트
  - 스프링 빈이 로딩되기 전에 발생
- `ApplicationPreparedEvent`
  - 스프링 빈들이 로딩되고, refresh 되기 전에 발생하는 이벤트
- `ApplicationStartedEvent`
  - refresh 된 후 발생하는 이벤트
  - 단, 애플리케이션과 커맨드 라인 러너가 호출되기 전에 발생
- `AvailabilityChangeEvent`
  - 애플리케이션이 실행 준비됨을 의미하는 LivenessState.CORRECT 다음에 발생하는 이벤트
- `AvailabilityReadyEvent`
  - 모든 애플리케이션과 커맨드 라인 러너가 실행된 후 발생하는 이벤트
- `AvailabilityChangeEvent`
  - 애플리케이션이 서비스 요청을 처리할 수 있음을 의미하는 ReadinessState.ACCEPTING_TRAFFIC 다음에 발생하는 이벤트
- `ApplicationFailedEvent`
  - 예외가 발생하여 애플리케이션이 정상으로 실행되지 못할 때 발생하는 이벤트

---

프레임워크에서 발생한 이벤트를 구독하는 구독 클래스를 작성할 때는 **`@EventListener` 대신 `ApplicationListener` 인터페이스를 구현하는 방법을 권장**한다.

아래는 [2. 사용자 정의 이벤트 처리 - 실행](#실행) 에서 사용했던 
ApplicationEventListener 가 `ApplicationReadyEvent` 메시지를 구독하는 예시이다.

event > server > ApplicationEventListener.java
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.ApplicationListener;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

@Slf4j
public class ApplicationEventListener implements ApplicationListener<ApplicationReadyEvent> {
    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        long timestamp = event.getTimestamp();
        LocalDateTime eventTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(timestamp), ZoneId.systemDefault());

        log.info("Application is Ready. {}", eventTime);
    }
}
```

UserEventListener 와 다른 점은 `@Component` 가 빠져서 스프링 빈이 될 수 없다는 것이다.

`ApplicationStartingEvent` 는 스프링 빈을 스캔하지 않으므로 이 때 이벤트 구독 클래스가 스프링 빈으로 정의되어 있고, `@EventListener` 를 사용하여 
이벤트를 구독한다면 정상적으로 이벤트를 구독할 수 없다.

따라서 스프링 프레임워크에서 게시하는 이벤트를 구독할 때는 아래처럼 개발하는 것이 좋다.

- 구독 클래스는 `ApplicationLister` 인터페이스를 구현하고, `onApplicationEvent()` 추상 메서드를 구현
- 구독 클래스 객체를 생성하고, SpringApplication 의 `addListener()` 를 사용하여 생성한 객체를 직접 추가

`ApplicationReadyEvent` 는 스프링 빈과 `@EventListener` 로 정의된 구독 클래스가 이벤트를 구독할 수 있다. 하지만 각각의 이벤트가 
어느 단계에서 발생하는지 확인해야 하므로 이벤트 게시 시점에 대한 확신이 없다면 `ApplicationListener` 인터페이스를 구현하는 방법을 사용하는 것이 좋다.

위의 ApplicationEventListener 는 아래처럼 SpringApplication 에 등록하여 사용한다.

/Chap12SyncApplication.java
```java
package com.assu.study.chap12;

import com.assu.study.chap12.server.ApplicationEventListener;
import com.assu.study.chap12.service.UserService;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;

@SpringBootApplication
public class Chap12SyncApplication {
  public static void main(String[] args) {
    // SpringApplication 객체와 ApplicationContext 를 설정할 수 있는 메서드를 제공하는 SpringApplicationBuilder 클래스 사용
    SpringApplicationBuilder builder = new SpringApplicationBuilder(Chap12SyncApplication.class);
    // build() 를 호출하여 SpringApplication 객체 생성
    SpringApplication application = builder.build();
    // addListener() 는 하나 이상의 ApplicationListener 객체들을 받음
    application.addListeners(new ApplicationEventListener());

    // run() 을 이용하여 스프링 부트 애플리케이션 실행
    ConfigurableApplicationContext ctxt = application.run(args);

    UserService userService = ctxt.getBean(UserService.class);
    userService.createUser("Assu", "assu@test.com");
  }
}
```

---

[2. 사용자 정의 이벤트 처리](#2-사용자-정의-이벤트-처리) 를 최종적으로 정리하면 아래와 같다.

## 이벤트 메시지 클래스

```java
package com.assu.study.chap12_1.event;

import lombok.Getter;
import org.springframework.context.ApplicationEvent;

// 이벤트 메시지 클래스
// 불변(immutable) 클래스 이어야 하므로 Setter 는 없음
// 유저를 생성/삭제할 때 게시할 목적으로 사용됨
@Getter
public final class UserEvent extends ApplicationEvent {   // 이벤트 메시지 클래스이므로 ApplicationEvent 상속
    private final Type type;
    private final Long userId;
    private final String email;

    private UserEvent(Object source, Type type, Long userId, String email) {
        // Object source 는 이벤트를 게시하는 클래스의 객체를 의미
        // 예를 들어 UserService 클래스에서 UserEvent 객체를 생성/게시할 때 UserService 객체를 Object source 인자로 넘김
        // ApplicationEvent 객체에 할당된 Object source 는 Object getSource() 로 참조 가능
        super(source);

        this.type = type;
        this.userId = userId;
        this.email = email;
    }

    // 정적 팩토리 메서드
    public static UserEvent created(Object source, Long userId, String email) {
        return new UserEvent(source, Type.CREATE, userId, email);
    }

    public enum Type {
        CREATE, DELETE
    }
}
```

---

## 게시 클래스

```java
package com.assu.study.chap12_1.event;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

// 게시 클래스
@Slf4j
@Component
public class UserEventPublisher {
    // ApplicationEventPublisher 스프링 빈 주입받음
    private final ApplicationEventPublisher applicationEventPublisher;

    public UserEventPublisher(ApplicationEventPublisher applicationEventPublisher) {
        this.applicationEventPublisher = applicationEventPublisher;
    }

    // 이벤트가 발생하는 클래스에서 호출
    public void publishUserCreated(Long userId, String email) {
        UserEvent userEvent = UserEvent.created(this, userId, email);
        log.info("Publish user created event.");

        // UserEvent 이벤트 메시지 객체 게시
        applicationEventPublisher.publishEvent(userEvent);
    }
}
```

```java
package com.assu.study.chap12_1.service;

import com.assu.study.chap12_1.event.UserEventPublisher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class UserService {
    private final UserEventPublisher userEventPublisher;

    public UserService(UserEventPublisher userEventPublisher) {
        this.userEventPublisher = userEventPublisher;
    }

    public Boolean createUser(String userName, String email) {
        // 사용자 생성 로직 생략
        log.info("created user. {}, {}", userName, email);

        userEventPublisher.publishUserCreated(11111L, email);
        log.info("done create user event publish.");

        return Boolean.TRUE;
    }
}
```

---

## 구독 클래스

```java
package com.assu.study.chap12_1.event;

import com.assu.study.chap12_1.service.EventService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

// 구독 클래스
@Slf4j
@Component
public class UserEventListener implements ApplicationListener<UserEvent> {  // ApplicationListener 의 제네릭 클래스 타입은 구독할 이벤트의 클래스 타입

    // 기능을 실행할 스프링 빈 주입
    // UserEventListener 구독 클래스는 UserEvent 를 구독하는 기능만 담당하고, 실제 이벤트 처리는 별도의 클래스(EventService)에 위임
    private final EventService eventService;

    public UserEventListener(EventService eventService) {
        this.eventService = eventService;
    }

    @Async
    @Override
    public void onApplicationEvent(UserEvent event) {
        if (UserEvent.Type.CREATE == event.getType()) {
            log.info("Listen CREATE event. {}, {}", event.getUserId(), event.getEmail());
            // 메일 발송
            eventService.sendEventEmail(event.getEmail());
        } else if (UserEvent.Type.DELETE == event.getType()) {
            log.info("Listen DELETE event.");
        } else {
            log.error("Unsupported event type. {}", event.getType());
        }

        eventService.sendEventEmail2(event.getEmail());
    }
}
```

```java
package com.assu.study.chap12_1.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class EventService {
    public void sendEventEmail(String email) {
        // 이메일 발송
        log.info("Send Email~, {}", email);
    }

    public void sendEventEmail2(String email) {
        // 이메일 발송
        log.info("Send Email2~, {}", email);
    }
}
```

## 실행

```java
package com.assu.study.chap12_1.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@EnableAsync    // 비동기 기능 활성화
@Configuration
public class AsyncExecutionConfig implements AsyncConfigurer {
    // 프레임워크가 스레드 풀을 설정할 때 사용하는 콜백 메서드
    @Override
    public Executor getAsyncExecutor() {
        return getExecutor();
    }

    private Executor getExecutor() {
        ThreadPoolTaskExecutor threadPoolTaskExecutor = new ThreadPoolTaskExecutor();
        // 기본 개수는 10개
        threadPoolTaskExecutor.setCorePoolSize(10);
        // 최대 10개까지 늘어남
        threadPoolTaskExecutor.setMaxPoolSize(10);
        threadPoolTaskExecutor.setThreadNamePrefix("asyncExecutor-");
        // 컨테이너가 모든 속성값을 적용한 후 initialize() 호출
        threadPoolTaskExecutor.afterPropertiesSet();
        return threadPoolTaskExecutor;
    }

    @Bean("asyncExecutor")
    public Executor asyncExecutor() {
        return getExecutor();
    }
}
```

```java
package com.assu.study.chap12_1.server;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.ApplicationListener;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

@Slf4j
public class ApplicationEventListener implements ApplicationListener<ApplicationReadyEvent> {
    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        long timestamp = event.getTimestamp();
        LocalDateTime eventTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(timestamp), ZoneId.systemDefault());

        log.info("Application12_1 is Ready. {}", eventTime);
    }
}
```

```shell
2023-12-10T14:48:16.584+09:00  INFO 99438 --- [  restartedMain] c.a.s.c.server.ApplicationEventListener  : Application12_1 is Ready. 2023-12-10T14:48:16.583
2023-12-10T14:48:16.585+09:00  INFO 99438 --- [  restartedMain] .ConditionEvaluationDeltaLoggingListener : Condition evaluation unchanged
2023-12-10T14:48:16.585+09:00  INFO 99438 --- [  restartedMain] c.a.study.chap12_1.service.UserService   : created user. Assu, assu@test.com
2023-12-10T14:48:16.585+09:00  INFO 99438 --- [  restartedMain] c.a.s.chap12_1.event.UserEventPublisher  : Publish user created event.
2023-12-10T14:48:16.586+09:00  INFO 99438 --- [  restartedMain] c.a.study.chap12_1.service.UserService   : done create user event publish.
2023-12-10T14:48:16.586+09:00  INFO 99438 --- [asyncExecutor-1] c.a.s.chap12_1.event.UserEventListener   : Listen CREATE event. 11111, assu@test.com
2023-12-10T14:48:16.587+09:00  INFO 99438 --- [asyncExecutor-1] c.a.study.chap12_1.service.EventService  : Send Email~, assu@test.com
2023-12-10T14:48:16.587+09:00  INFO 99438 --- [asyncExecutor-1] c.a.study.chap12_1.service.EventService  : Send Email2~, assu@test.com
```

---

# 7. 트랜잭션 시점에 구독한 이벤트 처리: `@TransactionalEventListener`

스프링 프레임워크는 트랜잭션 종료 단계와 연계하여 이벤트를 구독하는 기능을 제공한다.

방법은 `@TransactionalEventListener` 애너테이션을 구독 메서드에 정의하면 된다.

`@EventListener` 를 사용한 구독 메서드는 게시하는 즉시 바로 실행되는 반면, `@TransactionalEventListener` 는 게시한 시점이 아닌 트랜잭션이 종료되는 시점에 실행된다.

아래는 트랜잭션의 종료 단계이다.

o.s.transaction.event.TransactionPhase
```java
package org.springframework.transaction.event;

public enum TransactionPhase {
	BEFORE_COMMIT,  // 트랜잭션 커밋 직전에 이벤트 처리
	AFTER_COMMIT, // 트랜잭션을 커밋한 후 이벤트 처리 (디폴트 값)
	AFTER_ROLLBACK, // 트랜잭션을 롤백한 후 이벤트 처리
	AFTER_COMPLETION  // 트랜잭션을 롤백하거나 커밋한 후 이벤트 처리
}
```

`@TransactionalEventListener`
```java
package org.springframework.transaction.event;

@Target({ElementType.METHOD, ElementType.ANNOTATION_TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@EventListener
public @interface TransactionalEventListener {

  // 기본값은 AFTER_COMMIT 이므로 커밋이 정상적으로 실행되면 구독 메서드 실행됨 (롤백에서는 실행안됨)
	TransactionPhase phase() default TransactionPhase.AFTER_COMMIT;

  // 구독 메서드를 실행하는 단계에서 트랜잭션이 없으면 구독 메서드 실행 여부 결정, false 일 경우 실행 중인 트랜잭션이 없을 때에는 구독 메서드 실행안함
	boolean fallbackExecution() default false;

  // 구독할 특정 이벤트 메시지 클래스의 클래스 타입 설정
	@AliasFor(annotation = EventListener.class, attribute = "classes")
	Class<?>[] classes() default {};

  // ...
}
```

pom.xml
```xml
<dependencies>
    <!-- Spring Data JPA, Hibernate, aop, jdbc -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
</dependencies>
```

```java
// 구독 클래스
@Slf4j
@Component
public class HotelEventListener {

  // ...

  @Async
  @Order(1)
  // 하나 이상의 클래스 타입 설정 가능
  // 정의된 이벤트 메시지가 게시되면 @EventListener 애너테이션이 정의된 메서드가 이벤트를 구독하고 실행함
  @TransactionalEventListener(classes = HotelCreateEvent.class, fallbackExecution = true)
  // 구독한 이벤트 객체를 메서드의 인자로 받을 수 있음
  public void handleHotelCreateEvent(HotelCreateEvent hotelCreateEvent) {
    // ...
  }
}
```

위에서 fallbackExecution = true 로 설정했으므로 handleHotelCreateEvent() 메서드를 실행할 때 트랜잭션이 없어도 실행된다.

ApplicationEventMulticaster 에 스레드 풀을 설정하지 않는다면 게시 클래스와 구독 클래스 모두 같은 스레드에서 동작하므로 게시 클래스의 트랜잭션에 포함하여 동작하고,  
ApplicationEventMulticaster 에 스레드 풀을 설정했다면 게시 클래스와 구독 클래스는 각각 다른 스레드에서 동작한다.  
따라서 구독 클래스는 게시 클래스에서 사용된 트랜잭션에 포함될 수 없으므로 `@TransactionalEventListener` 의 `fallbackExecution` 설정을 반드시 true 로 설정해주어야 한다.  
그렇지 않으면 구독 클래스는 동작하지 않는다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)