---
layout: post
title:  "Spring Boot - 데이터 영속성(4): 트랜잭션과 @Transactional"
date:   2023-09-10
categories: dev
tags: springboot msa database transactional propagation isolation dirty-read read-uncommitted read-committed repeatable-read non-repeatable-read phantom-read
---

이 포스트에서는 JPA 에서의 트랜잭션에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap08) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `@Transactional` 애너테이션](#1-transactional-애너테이션)
* [2. `@Transactional` 의 `propagation` 속성](#2-transactional-의-propagation-속성)
* [3. `@Transactional` 의 `isolation` 속성](#3-transactional-의-isolation-속성)
  * [3.1. `Read Uncommitted` 와 `Dirty Read`](#31-read-uncommitted-와-dirty-read)
  * [3.2. `Read Committed` 와 `Non-Repeatable Read`](#32-read-committed-와-non-repeatable-read)
  * [3.3. `Repeatable Read` 와 `Phantom Read`](#33-repeatable-read-와-phantom-read)
  * [3.4. `Serializable`](#34-serializable)
* [4. 트랜잭션 테스트](#4-트랜잭션-테스트)
* [5. `@Transactional` 사용 시 주의점](#5-transactional-사용-시-주의점)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

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

# 1. `@Transactional` 애너테이션

스프링 프레임워크는 `@Transactional` 애너테이션을 제공한다. `@Transactional` 애너테이션은 JPA 가 아닌 스프링 프레임워크에서 제공하는 기능이다.  
트랜잭션은 영속성 프레임워크의 종류와 상관없는 데이터베이스의 기능이기 때문이다.  
다라서 JPA/Hibernate 도 결국 SQL 쿼리로 데이터를 영속하므로 트랜잭션을 사용할 수 있다.

아래는 `@Transactional` 코드 일부이다.
```java
@Target({ElementType.TYPE, ElementType.METHOD}) // 클래스와 메서드 선언부에 @Transactional 선언 가능
@Retention(RetentionPolicy.RUNTIME)
@Inherited
@Documented
@Reflective
public @interface Transactional {
  // ...
}
```

`@Transactional` 을 클래스에 선언하면 클래스에 포함된 모든 메서드에 `@Transactional` 기능이 적용된다.

`@Transactional` 애너테이션은 스프링 AOP 기반으로 동작한다.  
스프링 AOP 에는 CGLIB Proxy 모드와 AspectJ 모드가 있는데 `@Transactional` 은 Proxy 모드가 기본 설정이므로 프록시 객체가 생성되어 트랜잭션을 처리한다.

트랜잭션에서 o.s.transaction.interceptor.TransactionInterceptor 와 o.s.transaction.PlatformTransactionManager 가 중요한 역할을 하는 클래스이다.    
개발자가 PlatformTransactionManager 객체를 사용하여 직접 구현하면 `@Transactional` 애너테이션 없이 트랜잭션을 구현할 수 있지만 트랜잭션 기능 또한 비기능적 요구 사항이므로 
AOP 로 처리하는 것이 편리하다.

`@Transactional` 애너테이션을 사용하면 스프링 프레임워크는 TransactionInterceptor 객체를 생성하여 AOP 프록시 객체로 넘긴다.  
그럼 AOP 프록시 객체는 이 TransactionInterceptor 객체를 사용하여 트랜잭션을 처리한다.

---

아래는 `@Transaction` 속성 코드이다.

```java
package org.springframework.transaction.annotation;

@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
@Documented
@Reflective
public @interface Transactional {
  
  // 스프링 애플리케이션에 여러 개의 TransactionManager 설정이 있따면 사용할 TransactionManager 의 스프링 빈 이름 설정
  // 스프링 애플리케이션에 TransactionManager 가 하나만 있다면 생략해도 됨
  @AliasFor("transactionManager")
  String value() default "";

  @AliasFor("value")
  String transactionManager() default "";

  String[] label() default {};

  // 스프링 애플리케이션 내에서 트랜잭션 전파 설정
  // 디폴트는 Propagation.REQUIRED
  Propagation propagation() default Propagation.REQUIRED;

  // 데이터베이스의 트랜잭션 격리 수준 설정
  // 여러 트랜잭션이 공통된 하나의 데이터를 동시에 조작할 때 어떻게 처리할 지 설정
  Isolation isolation() default Isolation.DEFAULT;

  // 트랜잭션에 대한 타임아웃 (s) 설정
  // 기본값은 무제한이지만 데이터베이스에 타임아웃이 설정되어 있다면 그 값을 따름
  int timeout() default -1;

  String timeoutString() default "";

  // 읽기 전용 설정
  // readonly=true 로 설정하면 읽기 전용 트랜잭션을 시작함
  // 읽기 전용 설정을 하면 JPA/Hibernate 의 EntityManager 가 읽기 전용으로 설정되어 성능 향상
  // 기본값은 false 
  boolean readOnly() default false;

  // 롤백 처리할 예외 클래스를 rollbackFor 속성에 정의 가능
  // 대상 메서드를 실행할 때 발생할 수 있는 예외 클래스를 설정하면 해당 예외 클래스에 대해 롤백함
  Class<? extends Throwable>[] rollbackFor() default {};
  String[] rollbackForClassName() default {};

  // 대상 메서드가 던질 수 있는 예외 메서드 중 설정된 예외 클래스에 대해서는 롤백에서 제외
  // 즉, RuntimeException 을 상속받는 예외 중 롤백 대상에서 제외하고 싶은 경우 사용
  Class<? extends Throwable>[] noRollbackFor() default {};
  String[] noRollbackForClassName() default {};
}
```

`@Transactional` 애너테이션이 선언된 메서드가 `@Transactional` 애너테이션이 선언된 다른 메서드를 호출하면 트랜잭션 설정이 중첩된다.  
이 때 호출된 메서드에서 트랜잭션을 어떻게 사용할지 결정하는 것을 전파(Propagation) 설정이라고 한다.  
전파 설정은 중첩된 경우 말고도 트랜잭션이 없는 경우에도 어떻게 트랜잭션을 시작할 지 설정하는 것도 포함한다.  
`propagation` 속성에는 Propagation 열거형 상수를 설정한다.

---

스프링 프레임워크의 기본 설정으로 **Unchecked Exception (RuntimeException 또는 이를 상속받는 자식 예외 클래스들) 이 발생하면 프레임워크는 진행 중이던 트랜잭션을 
자동으로 롤백**한다.  
따라서 `@Transactional` 애너테이션을 사용할 때마다 `rollbackFor` 속성을 설정하지 않아도 된다.

달리 말하면 **트랜잭션 도중 발생한 Checked Exception 스프링 프레임워크가 롤백하지 않는다.**    
따라서 Checked Exception 이 발생할 때 트랜잭션을 롤백해야 한다면 `rollbackFor` 속성에 예외 클래스를 명시적으로 선언해야 한다.

**_애플리케이션에서 예외 클래스를 생성해야 한다면 RuntimeException 을 상속받은 클래스로 설계_**하자!  
아니면 **_메서드에서 예외를 생성할 때 RuntimeException 이나 그 하위 예외 클래스를 적극적으로 사용_**하는 것이 좋다.  

특별한 경우가 아니라면 `rollbackFor` 속성을 사용하지 않는 것이 좋다. 매번 특정 예외에서 롤백하도록 설정하는 것은 실수를 유발할 수 있다.  
`noRollbackForClassName` 속성 또한 특별한 경우가 아니라면 설정하지 않는 것이 좋다. 규칙에서 벗어난 복잡한 애플리케이션은 유지 보수하기 어렵고 버그가 발생하기 쉽다.

---

`@Transactional` 애너테이션은 Repository 클래스의 메서드에 선언하기보다 서비스 클래스의 메서드나 클래스에 선언하는 것이 일반적이다.  
서비스 클래스에 개발된 메서드 내부는 비즈니스 로직과 여러 레파지토리 클래스의 메서드로 조합되어 있어 결국 하나의 유즈 케이스를 처리하려고 여러 테이블에 데이터를 조작하는 쿼리들이 실행된다.  
따라서 서비스 클래스의 메서드에 `@Transactional` 애너테이션을 설정하여 트랜잭션 단위로 데이터를 처리하기 적합하다.

---

# 2. `@Transactional` 의 `propagation` 속성

호출하는 메서드와 호출되는 메서드 모두 `@Transactional` 애너테이션이 설정되어 있을 경우 트랜잭션에 대해 알아보자.  
호출되는 메서드는 호출한 메서드의 트랜잭션에 포함될 수도 있고, 새로운 트랜잭션을 실행할 수도 있는데 이런 동작은 트랜잭션 전파 설정에 따라 결정된다.

예를 들어 1번 메서드, 2번 메서드 모두 `@Transactional` 애너테이션이 선언되었다고 할 때 전파 설정에 따라 트랜잭션 동작을 살펴본다.
 
- `Propagation.REQUIRED`
  - 디폴트값임
  - 현재 진행하는 트랜잭션이 있으면 이 트랜잭션에 포함하고, 진행하는 트랜잭션이 없으면 새로운 트랜잭션을 시작한 후 해당 메서드 실행
  - 예) 1번 메서드가 2번 메서드 호출 시 2번 메서드는 새로운 트랜잭션을 새로 생성하지 않고 이미 시작된 1번 트랜잭션에 포함되어 메서드 실행  
  만일 2번 메서드를 직접 호출하면 현재 진행 중인 트랜잭션이 없으므로 새로운 트랜잭션을 시작하여 메서드 실행
- `Propagation.REQUIRES_NEW`
  - 항상 새로운 트랜잭션 시작
  - 예) 1번 트랜잭션이 시작되었더라고 2번 트랜잭션을 새로 생성하여 실행  
  이 때 2번 트랜잭션을 시작하기 전에 1번 트랜잭션은 보류되며, 2번 트랜잭션이 종료되면 보류된 1번 트랜잭션을 다시 재개함
- `Propagation.SUPPORT`
  - 현재 진행하는 트랜잭션이 있으면 트랜잭션에 포함하고, 없으면 트랜잭션을 만들지 않고 실행함
  - 예) 2번 메서드는 1번 트랜잭션에 포함되어 실행됨  
  만일 2번 메서드를 직접 호출할 경우 현재 진행 중인 트랜잭션이 없으므로 트랜잭션 없이 쿼리 실행
- `Propagation.NOT_SUPPORT`
  - 현재 진행하는 트랜잭션이 있으면 실행되고 있는 트랜잭션은 보류하고, 트랜잭션 없이 해당 메서드 실행, 이후 보류된 트랜잭션 다시 시작
  - 예) 1번 메서드가 2번 메서드 호출 시 1번 트랜잭션 보류, 그리고 2번 메서드 실행한 후 보류된 1번 트랜잭션 재개  
  만일 2번 메서드를 직접 호출하더라도 트랜잭션 없이 실행
  - 결국 NOT_SUPPORT 로 설정된 메서드는 무조건 트랜잭션 없이 쿼리 실행
- `Propagation.MANDATORY`
  - 현재 진행하는 트랜잭션이 있으면 트랜잭션에 포함하고, 진행하는 트랜잭션이 없으면 javax.persistence.TransactionRequiredException 예외 발생
  - 예) 1번 메서드가 2번 메서드 호출 시 2번 메서드는 1번 트랜잭션에 포함되어 실행됨   
  만일 2번 메서드를 직접 호출하면 진행 중인 트랜잭션이 없으므로 TransactionRequiredException 예외 발생
  - 반드시 트랜잭션이 필요한 메서드에 선언하는 것이 좋음
- `Propagation.NEVER`
  - 현재 진행하는 트랜잭션이 있으면 예외 발생, 진행하는 트랜잭션이 없으면 트랜잭션이 없는 채로 메서드 실행
- `Propagation.NESTED`
  - 현재 진행하는 트랜잭션이 있으면 중첩된 트랜잭션을 실행하고, 진행하는 트랜잭션이 없으면 새로 트랜잭션을 생성하여 실행

특별한 경우는 제외하고는 기본값인 `Propagation.REQUIRED` 를 사용한다.  
**`Propagation.REQUIRED` 는 현재 진행 중인 트랜잭션의 여부와 상관없이 무조건 하나의 트랜잭션에 포함되어 실행**된다.

---

# 3. `@Transactional` 의 `isolation` 속성

데이터베이스의 트랜잭션 격리 수준 설정하는 것으로, 여러 트랜잭션이 공통된 하나의 데이터를 동시에 조작할 때 어떻게 처리할 지 설정할 수 있다.  
즉, `@Transactional` 의 `isolation` 속성을 통해 애플리케이션에서 트랜잭션을 시작할 때 트랜잭션 작업 단위의 격리 수준을 설정할 수 있다.

멀티 스레드 환경에서는 여러 스레드가 공유 데이터에 동시에 접근하고 변경하는 일이 발생한다.  
즉, 하나의 데이터에 여러 스레드가 동시에 접근하여 SELECT, UPDATE, DELETE 와 같은 쿼리를 실행할 수 있는데 동시에 접근하는 스레드의 개수만큼 여러 
트랜잭션이 겹치는 상황이 발생한다.  
이 때 **트랜잭션들을 서로 분리하는 방법을 설정**하여 데이터의 정합성을 유지할 수 있다.  

이를 **트랜잭션의 격리 수준**이라고 하며, `@Transactional` 의 `isolation` 속성으로 설정할 수 있다.

트랜잭션의 격리 수준은 4 단계가 있으며, 격리 수준이 높으면 트랜잭션들은 서로 완전히 분리되고 순서대로 처리하므로 같은 데이터에 동시에 접근할 수 없다.  
반대로 격리 수준이 낮으면 같은 데이터에 동시에 접근할 수 있다.

격리 수준이 낮으면 부작용이 많고 격리 수준이 높으면 부작용이 적지만 그만큼 단위 시간당 처리할 수 있는 쿼리 수가 낮아진다.  
반대로 격리 수준이 낮으면 처리할 수 있는 쿼리 수는 많아진다.

데이터를 관리하는 측면에서는 격리 수준이 높을수록 좋지만 처리량 측면에서는 격리 수준이 낮을수록 좋기 때문에 중간에 타협 지점을 찾아야 하고, 
부작용을 감수하거나 최소화할 수 있는 데이터베이스 설계와 프로그래밍이 필요하다.

---

격리 수준은 데이터베이스 설정을 사용하여 데이터베이스 전체에 설정하는 방법과 애플리케이션의 트랜잭션 설정을 사용하여 매번 설정하는 방법이 있는데 이는 DBA 와 상의하여 결정하는 것이 좋다.  
여기선 `@Transactional` 의 `isolation` 속성을 설정하는 법에 대해 알아보며, 데이터베이스에서 격리 수준을 설정하는 방법은 설명하지 않는다.

아래는 데이터베이스에서 사용할 수 있는 격리 수준이다.

| 격리 수준            | 격리 강도 | Dirty Read | Non-Repeatable Read | Phantom Read |
|:-----------------|:--:|:--:|:--:|:--:|
| Read Uncommitted | 낮음 | O | O | O |
| Read Committed   | 중간 | X | O | O |
| Repeatable Read  | 중간 | X | X | O |
| Serializable     | 높음 | X | X | X |


`@Transactional` 의 `isolation` 속성을 설정하면 트랜잭션의 격리 수준을 설정할 수 있다.

- `Isolation.DEFAULT`
  - `@Transactional` 의 기본값
  - 데이터베이스에 설정된 격리 수준을 따라 동작
- `Isolation.READ_UNCOMMITTED`
  - 커밋되지 않은 데이터를 읽을 수 있는 격리 수준
- `Isolation.READ_COMMITTED`
  - 커밋된 데이터를 읽을 수 있는 격리 수준
- `Isolation.REPEATABLE_READ`
  - 여러 트랜잭션이 동일한 데이터에 접근할 때 동일한 값을 보장하는 격리 수준
  - 단, 다른 트랜잭션이 실행한 INSERT 쿼리에 대해서는 예외임
- `Isolation.SERIALIZABLE`
  - 가장 높은 격리 수준
  - 가장 먼저 실행한 트랜잭션이 우선권을 갖고, 다른 트랜잭션들에서 완전히 격리하여 실행됨

MySQL 데이터베이스의 기본 설정으로 설정된 격리 수준은 `Repeatable Read` 이다.  
스프링 프레임워크에서 `@Transactional(isolation=Isolation.DEFAULT)` 나 속성 설정없이 `@Transactional` 애너테이션으로 트랜잭션을 설정하면 데이터베이스의 설정을 따라간다.

특히 동시성과 관련된 데이터 버그는 Isolation 설정과 관련있으므로 설정값과 사용 전략을 미리 세우는 것이 좋다.

---

## 3.1. `Read Uncommitted` 와 `Dirty Read`

> **`Dirty Read`**
>
> 트랜잭션을 커밋하지 않아 최종 처리가 안된 데이터를 읽을 수 있는 상황

2 개의 스레드가 `Read Uncommitted` 설정으로 트랜잭션을 시작하고, 둘 다 같은 id 가 10 인 데이터의 name 을 조회하여 
만일 이름이 'BEFORE' 이면 'AFTER' 로 변경하는 상황이라고 하자.  

- (스레드 1) 트랜잭션 시작
- (스레드 1) id=10 인 데이터의 name 필드 조회, 이 때 name 은 'BEFORE'
- (스레드 1) id=10 인 데이터의 name 을 'AFTER' 로 변경하는 UPDATE 쿼리 실행, UPDATE 쿼리가 성공적으로 실행되었으나 아직 커밋은 되지 않은 상태
- (스레드 2) 트랜잭션 시작, 이 때 격리 수준은 Read Uncommitted
- (스레드 2) id=10 인 데이터의 name 필드 조회, 이 때 name 은 'AFTER'  
격리 수준이 `Read Uncommitted` 이므로 스레드 1 에서 변경했지만 커밋하지 않은 데이터 조회 가능
- (스레드 1) 다른 작업을 실행하는 도중 예외가 발생하여 트랜잭션 롤백, 결국 id=10 은 'BEFORE' 로 원복
- (스레드 2) 조회한 name 이 'AFTER' 이므로 UPDATE 쿼리 실행하지 않음
- (스레드 2) 트랜잭션을 종료하고 스레드도 작업을 마침

결국 스레드 1과 스레드 2 모두 데이터를 변경하지 못했다.  
스레드 2 가 `Read Uncommitted` 설정으로 트랜잭션을 시작했고, `Dirty Read` 현상으로 커밋되지 못한 데이터를 읽었기 때문이다.  
이런 상황이 자주 발생하지는 않겠지만, 그래도 이러한 `Dirty Read` 상황을 방지하려면 트랜잭션을 `Read Committed` 이상으로 격리 수준을 올리면 된다.

---

## 3.2. `Read Committed` 와 `Non-Repeatable Read`

앞과 동일하게 2 개의 스레드가 `Read Uncommitted` 설정으로 트랜잭션을 시작하고, 둘 다 같은 id 가 10 인 데이터의 name 을 조회하여
만일 이름이 'BEFORE' 이면 'AFTER' 로 변경하는 상황이라고 하자.

> **`Non-Repeatable Read`**  
> 
> 한 트랜잭션 내에서 같은 데이터를 두 번 이상 조회했을 때 매번 다른 값이 조회될 수 있는 상황

격리 수준이 **`Read Committed` 인 트랜잭션은 커밋된 데이터를 조회할 수 있는 격리 수준** 으로 거의 동시에 실행된 스레드 2 는 데이터를 두 번 쿼리하는 작업을 한다고 하자.

`Read Uncommitted` 와 비교하면 커밋된 데이터만 조회하므로 `Dirty Read` 는 막을 수 있지만 한 트랜잭션 내에서 같은 데이터를 두 번 이상 조회했을 때 매번 다른 값이 조회될 수 있다.

- (스레드 1) 트랜잭션 시작
- (스레드 1) id=10 인 데이터의 name 필드 조회, 이 때 name 은 'BEFORE'
- (스레드 1) id=10 인 데이터의 name 을 'AFTER' 로 변경하는 UPDATE 쿼리 실행, UPDATE 쿼리가 성공적으로 실행되었으나 아직 커밋은 되지 않은 상태
- (스레드 2) id=10 인 데이터의 name 필드 조회, 아직 스레드 1이 커밋하지 않은 상태이므로 이 때 name 은 'BEFORE'
- (스레드 1) 커밋, name 이 'AFTER' 로 최종 업데이트됨
- (스레드 2) id=10 인 데이터를 다시 조회, 트랜잭션의 격리 수준이 `Read Committed` 이므로 스레드 1 이 커밋한 'AFTER' 가 조회됨  
 한 트랜잭션 내애서 name 의 조회값이 다르게 조회되므로 데이터 정합성이 깨짐

**한 트랜잭션 안에서 같은 데이터를 조회해도 다른 값을 조회하는 `Non-Repeatable Read` 현상은 `Read Committed` 나 `Read Uncommitted` 격리 수준에서 발생**한다. 

`Non-Repeatable Read` 는 MS-SQL Server, Oracle, PostgreSQL 등 많은 데이터베이스가 기본값으로 사용하는 격리 수준이다.

---

## 3.3. `Repeatable Read` 와 `Phantom Read`

> MySQL 데이터베이스의 기본 설정으로 설정된 격리 수준임

스레드 1 이 status='closed' 인 데이터들을 조회하고, 한 트랜잭션 안에서 이 쿼리를 두 번 실행한다고 하자.  
`Read Committed` 격리 수준보다 높은 `Repeatable Read` 격리 수준으로 두 쿼리의 결과값이 같을 것으로 생각할 수 있지만, 스레드 2 의 트랜잭션이 스레드 1 의 트랜잭션에 
중복되면 다른 현상이 발생할 수 있다.  

스레드 2 가 트랜잭션을 시작하여 id=1 이고 status='closed' 이며, name='AFTER' 인 데이터를 생성하는 INSERT 쿼리를 실행할 때 어떤 현상이 발생할 수 있는지 보자. 

> **Phantom Read**  
> 
> 사용자 예상과 다르게 새로운 데이터가 나타나는 현상

**`Repeatable Read` 격리 수준은 트랜잭션 내에서 조회하는 데이터는 항상 같음을 보장**한다.  

`Read Committed` 격리 수준에서 발생할 수 있는 `Non-Repeatable Read` 현상은 발생하지 않는다.  
중첩된 트랜잭션이 있는 경우 한 트랜잭션이 조회하는 데이터는 다른 트랜잭션이 수정하거나 삭제할 수 없기 때문이다.  
즉, `Repeatable Read` 격리 수준인 스레드 1 이 조회하는 'BEFORE' 는 스레드 2 가 UPDATE, DELETE 할 수 없다.  

하지만 스레드 2 가 데이터를 생성하는 INSERT 를 하는 것은 `Repeatable Read` 에서 막을 수 없다.  
`Repeatable Read` 는 다른 트랜잭션의 수정이나 삭제만 막을 수 있기 때문이다.

**`Repeatable Read` 격리 수준에서는 `Phantom Read` 현상이 발생**할 수 있다.

**`Non-Repeatable Read` 현상과 비교했을 때 `Phantom Read` 는 새로운 데이터가 나타나는 현상**이고, 
**`Non-Repeatable Read` 는 하나의 데이터가 변경되는 현상**을 의미한다.

**의도하지 않는 데이터가 조회되는 `Phantom Read` 는 의도하지 않게 다른 데이터까지 수정/삭제할 수 있는 상황이 발생**할 수 있다.

- (스레드 1) 트랜잭션 시작
- (스레드 1) status='closed' 인 id, name 필드값 조회
여러 개의 레코드를 조회할 수 있는 쿼리이며, 이 때 id=1, name='BEFORE' 인 레코드 하나가 조회됨
- (스레드 2) 트랜잭션 시작
- (스레드 2) id=2, name='AFTER', status='closed' 인 데이터 생성 (INSERT)
- (스레드 2) 커밋하고 스레드 종료
- (스레드 1) status='closed' 인 데이터를 다시 조회  
이 때 id=1, name='BEFORE' 와 id=2, name='AFTER' 인 데이터 2개가 조회됨  
스레드 1 입장에서는 `Repeatable Read` 트랜잭션 안에서 새로운 데이터가 나타난 것이므로 `Phantom Read` 현상이라고 함
- (스레드 1) 트랜잭션을 커밋하고 종료

---

## 3.4. `Serializable`

격리 수준 중에서 가장 높은 값이다.  

여러 트랜잭션이 중복된 경우 가장 먼저 시작한 트랜잭션이 대상 테이블을 점유하고 다른 트랜잭션의 쿼리를 막는다.  
즉, 다른 트랜잭션은 INSERT, UPDATE, DELETE 쿼리를 바로 실행할 수 없다. 미리 시작한 트랜잭션이 테이블에 Lock 을 잡기 때문이다.

따라서 `Dirty Read`, `Non-Repeatable Read`, `Phantom Read` 와 같은 현상이 발생할 수 없다.  

**`Serializable` 은 트랜잭션에서 가장 높은 등급의 고립성을 보장하지만, 다른 트랜잭션들이 무조건 대기해야 하므로 상대적으로 성능은 그만큼 떨어질 수 밖에 없다.**

---

# 4. 트랜잭션 테스트

/service/HotelService.java
```java
package com.assu.stury.chap08.service;

import com.assu.stury.chap08.controller.HotelCreateRequest;
import com.assu.stury.chap08.controller.HotelCreateResponse;
import com.assu.stury.chap08.domain.HotelEntity;
import com.assu.stury.chap08.domain.HotelRoomEntity;
import com.assu.stury.chap08.domain.HotelRoomType;
import com.assu.stury.chap08.repository.HotelRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

@Service
public class HotelService {
  private final HotelRepository hotelRepository;

  public HotelService(HotelRepository hotelRepository) {
    this.hotelRepository = hotelRepository;
  }

  // 메서드 내부에 데이터를 생성하는 save() 가 있으므로 readOnly 를 false 로 설정 (디폴트라 안해도 되긴 함)
  @Transactional(readOnly = false, isolation = Isolation.SERIALIZABLE)
  public HotelCreateResponse createHotel(HotelCreateRequest createRequest) {
    HotelEntity hotelEntity = HotelEntity.of(
        createRequest.getName(),
        createRequest.getAddress(),
        createRequest.getPhoneNumber()
    );

    int roomCount = createRequest.getRoomCount();
    List<HotelRoomEntity> hotelRoomEntitis = IntStream.range(0, roomCount)  // IntStream 반환
        .mapToObj(i -> HotelRoomEntity.of("ROOM-" + i, HotelRoomType.DOUBLE, BigDecimal.valueOf(100)))  // Stream<HotelRoomEntity> 반환
        .collect(Collectors.toList());

    hotelEntity.addHotelRooms(hotelRoomEntitis);

    hotelRepository.save(hotelEntity);
    return HotelCreateResponse.of(hotelEntity.getHotelId());
  }
}
```

/controller/HotelCreateRequest.java
```java
package com.assu.stury.chap08.controller;

import lombok.Getter;
import lombok.Setter;

// DTO
@Getter
@Setter
public class HotelCreateRequest {
  private String name;
  private String address;
  private String phoneNumber;
  private Integer roomCount;
}
```

/controller/HotelCreateResponse.java
```java
package com.assu.stury.chap08.controller;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

// DTO
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class HotelCreateResponse {
  private Long hotelId;

  public static HotelCreateResponse of(Long hotelId) {
    HotelCreateResponse response = new HotelCreateResponse();
    response.hotelId = hotelId;
    return response;
  }
}
```

/domain/HotelEntity.java
```java
package com.assu.stury.chap08.domain;

import com.assu.stury.chap08.domain.converter.HotelStatusConverter;
import jakarta.persistence.*;
import lombok.Getter;

import java.util.ArrayList;
import java.util.List;

//@NoArgsConstructor
// @EqualsAndHashCode
// @ToString
@Getter
@Table(name = "hotels")
@Entity(name = "hotels")
public class HotelEntity extends AbstractManageEntity {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "hotel_id")
  private Long hotelId;

//  @Column(name = "status")
//  private HotelStatus status;

//  @Column
//  @Enumerated(value = EnumType.STRING)
//  private HotelStatusTemp status;

  @Column(name = "status")
  @Convert(converter = HotelStatusConverter.class)
  private HotelStatus status;

  @Column
  private String name;

  @Column
  private String address;

  @Column(name = "phone_number")
  private String phoneNumber;

  @Column(name = "room_count")
  private Integer roomCount;

  @OneToMany(cascade = CascadeType.PERSIST)
  @JoinColumn(name = "hotels_hotel_id", referencedColumnName = "hotel_id")
  private List<HotelRoomEntity> hotelRoomEntities;

  // 반드시 AbstractManageEntity 의 생성자를 호출해야 함
  public HotelEntity() {
    super();
    this.hotelRoomEntities = new ArrayList<>();
  }


  public static HotelEntity of(String name, String address, String phoneNumber) {
    HotelEntity hotelEntity = new HotelEntity();

    hotelEntity.name = name;
    hotelEntity.status = HotelStatus.READY;
    hotelEntity.address = address;
    hotelEntity.phoneNumber = phoneNumber;
    hotelEntity.roomCount = 0;

    return hotelEntity;
  }

  public void addHotelRooms(List<HotelRoomEntity> hotelRoomEntities) {
    this.roomCount += hotelRoomEntities.size();
    this.hotelRoomEntities.addAll(hotelRoomEntities);
  }
//  public enum HotelStatusTemp {
//    OPEN, CLOSED, READY
//  }
}
```

/domain/HotelRoomEntity.java
```java
package com.assu.stury.chap08.domain;

import com.assu.stury.chap08.domain.converter.HotelRoomTypeConverter;
import jakarta.persistence.*;
import lombok.Getter;

import java.math.BigDecimal;

// @EqualsAndHashCode
// @ToString
@Getter
@Entity(name = "hotelRooms")
@Table(name = "hotel_rooms")
public class HotelRoomEntity extends AbstractManageEntity {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "hotel_room_id")
  private Long hotelRoomId;

  @Column(name = "hotels_hotel_id")
  private Long hotelId;

  @Column(name = "room_number")
  private String roomNumber;

  @Column(name = "room_type")
  @Convert(converter = HotelRoomTypeConverter.class)
  private HotelRoomType roomType;

  @Column(name = "original_price")
  private BigDecimal originalPrice;

  // 반드시 AbstractManageEntity 의 생성자를 호출해야 함
  public HotelRoomEntity() {
    super();
  }

  public static HotelRoomEntity of(String roomNumber, HotelRoomType hotelRoomType, BigDecimal originalPrice) {
    HotelRoomEntity hotelRoomEntity = new HotelRoomEntity();
    hotelRoomEntity.roomNumber = roomNumber;
    hotelRoomEntity.roomType = hotelRoomType;
    hotelRoomEntity.originalPrice = originalPrice;

    return hotelRoomEntity;
  }
}
```

/domain/HotelRoomType.java
```java
package com.assu.stury.chap08.domain;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

import java.util.Arrays;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

public enum HotelRoomType {
  SINGLE("single", 0),  // HotelRoomType.SINGLE 열거형 상수의 내부 속성인 param 값은 'single' 문자열
  DOUBLE("double", 1),
  TRIPLE("triple", 2),
  QUAD("quad", 3);

  private final String param;
  private final Integer value;

  // Map 의 key 는 HotelRoomType 열거형의 param 로, Map 의 value 는 HotelRoomType 의 상수로 저장
  // 빠르게 변환하고자 static 구문으로 클래스가 로딩될 때 Map 객체를 미리 생성함
  private static final Map<String, HotelRoomType> parmaMap = Arrays.stream(HotelRoomType.values())
      .collect(Collectors.toMap(
          HotelRoomType::getParam,
          Function.identity())
      );

  private static final Map<Integer, HotelRoomType> valueMap = Arrays.stream(HotelRoomType.values())
      .collect(Collectors.toMap(
          HotelRoomType::getValue,
          Function.identity())
      );

  // 모든 enum 상수 선언 시 JSON 객체 값으로 사용될 값을 인수로 입력
  // SINGLE 상수는 문자열 'single' 이 param 값으로 할당, 0 이 value 값으로 할당
  HotelRoomType(String param, Integer value) {
    this.param = param;
    this.value = value;
  }

  // PARAM 인자를 받아서 paramMap 의 key 와 일치하는 enum 상수 리턴
  // 언마셜링(JSON -> 객체) 과정에서 JSON 속성값이 single 이면 fromValue 메서드가 HotelRoomType.SINGLE 로 변환
  @JsonCreator  // 언마셜링 과정에서 값 변환에 사용되는 메서드 지정
  public static HotelRoomType fromParma(String param) {
    return Optional.ofNullable(param) // Optional<String> 반환
        .map(parmaMap::get) // Optional<HotelRoomType> 반환
        .orElseThrow(() -> new IllegalArgumentException("param is not valid."));
  }

  public static HotelRoomType fromValue(Integer value) {
    return Optional.ofNullable(value) // Optional<Integer> 반환
        .map(valueMap::get) // Optional<HotelRoomType> 반환
        .orElseThrow(() -> new IllegalArgumentException("value is not valid"));
  }

  // enum 상수에 정의된 param 변수값 리턴 (= getParam() 이 리턴하는 문자열이 JSON 속성값으로 사용됨)
  // 마셜링 (객체 -> JSON) 과정에서 HotelRoomType.SINGLE 이 "single" 로 변환됨
  @JsonValue  // 마셜링 과정에서 값 변환에 사용되는 메서드 지정, 이 애너테이션이 있으면 마셜링 때 toString() 이 아닌 getParam() 사용
  public String getParam() {
    return param;
  }

  public Integer getValue() {
    return value;
  }
}
```

/converter/HotelRoomTypeConverter.java
```java
package com.assu.stury.chap08.domain.converter;

import com.assu.stury.chap08.domain.HotelRoomType;
import jakarta.persistence.AttributeConverter;

import java.util.Objects;

// @Component
public class HotelRoomTypeConverter implements AttributeConverter<HotelRoomType, Integer> {

  // 데이터베이스에서 사용할 데이터로 변환
  // HotelRoomType 의 value 값을 리턴하는 getValue() 리턴
  @Override
  public Integer convertToDatabaseColumn(HotelRoomType attribute) {
    if (Objects.isNull(attribute)) {
      return null;
    }

    return attribute.getValue();
  }

  // 데이터베이스에 저장된 값을 HotelRoomType 열거형으로 변환
  // 데이터베이스에 저장된 Integer 값과 매핑되는 HotelRoomType 상수를 리턴하는 fromValue() 리턴
  @Override
  public HotelRoomType convertToEntityAttribute(Integer dbData) {
    if (Objects.isNull(dbData)) {
      return null;
    }

    return HotelRoomType.fromValue(dbData);
  }
}
```

/repository/HotelRoomRepository.java
```java
package com.assu.stury.chap08.repository;

import com.assu.stury.chap08.domain.HotelRoomEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface HotelRoomRepository extends JpaRepository<HotelRoomEntity, Long> {

  List<HotelRoomEntity> findByHotelId(Long hotelId);
}
```

---

이제 위에서 HotelService.java 의 createHotel() 메서드를 테스트하는 테스트 케이스를 작성해본다.

```java
package com.assu.stury.chap08.service;

import com.assu.stury.chap08.controller.HotelCreateRequest;
import com.assu.stury.chap08.controller.HotelCreateResponse;
import com.assu.stury.chap08.domain.HotelEntity;
import com.assu.stury.chap08.domain.HotelRoomEntity;
import com.assu.stury.chap08.repository.HotelRepository;
import com.assu.stury.chap08.repository.HotelRoomRepository;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@SpringBootTest
@Transactional
@TestPropertySource(locations = "classpath:application-test.properties")
class HotelServiceTest {

  @Autowired
  private HotelService hotelService;

  @Autowired
  private HotelRepository hotelRepository;

  @Autowired
  private HotelRoomRepository hotelRoomRepository;

  @Test
  void createHotel() {
    // given
    HotelCreateRequest request = new HotelCreateRequest();
    request.setName("test");
    request.setAddress("test address");
    request.setPhoneNumber("555555");
    request.setRoomCount(10);

    // when
    HotelCreateResponse response = hotelService.createHotel(request);
    HotelEntity hotelEntity = hotelRepository.findById(response.getHotelId()).orElse(null);
    List<HotelRoomEntity> hotelRoomEntities = hotelRoomRepository.findByHotelId(response.getHotelId());

    //Then
    Assertions.assertNotNull(hotelEntity);
    Assertions.assertEquals(request.getName(), hotelEntity.getName());
    Assertions.assertEquals(request.getAddress(), hotelEntity.getAddress());
    Assertions.assertEquals(request.getPhoneNumber(), hotelEntity.getPhoneNumber());
    Assertions.assertEquals(request.getRoomCount(), hotelEntity.getRoomCount());

    Assertions.assertEquals(request.getRoomCount(), hotelRoomEntities.size());
  }
}
```

---

# 5. `@Transactional` 사용 시 주의점

`@Transactional` 애너테이션은 스프링의 AOP 를 사용하여 동작한다.  
AOP 위빙이 되지 않은 채로 대상 메서드가 실행되어도 개발자는 알기 어렵다.  
즉, 대상 메서드는 정상적으로 실행되었지만 어드바이스가 정상적으로 실행되지 않을 수 있다.

<**`@Transactional` 사용 시 주의할 점**>  
- **public 접근 제어자로 선언된 메서드에만 `@Transactional` 애너테이션이 동작함**
  - final 이나 private 접근 제어자로 선언된 메서드는 프록시 객체를 만들 수 없음
  - 따라서 private 메서드에 `@Transactional` 애너테이션을 선언해도 트랜잭션이 정상동작하지 않음
- **스프링 빈으로 주입된 객체의 메서드를 호출해야 함**
  - 스프링 빈으로 주입된 객체의 메서드를 실행하면 ApplicationContext 가 어드바이스를 런타임에 위빙할 수 있음
  - 즉, 하나의 스프링 빈에 있는 메서드들이 `this` 키워드를 사용하여 다른 메서드를 호출하면 어드바이스를 해당 메서드에 위빙할 수 없음
  - `this` 키워드를 사용했으므로 개입할 여지가 없기 때문임
  - 따라서 자기 주입 방식을 사용하여 스프링 빈을 주입해야 함 (자기 주입 방식은 뒤의 예시에 나옵니다)
- **`@Transactional` 의 설정 중 트랜잭션의 격리 수준을 설정하는 `isolation` 속성은 통일하는 것이 좋음**
  - 격리 수준에 따라 `Dirty Read` 나 `Phantom Read` 와 같은 여러 상황이 발생하여 API 가 정상 동작하지 않을 때 격리 수준이 매번 다양하면 디버깅하기 힘듦

---

아래는 `this` 키워드를 사용하여 `@Transactional` 애너테이션이 걸려있는 내부 메서드를 호출하는 예시이다.

```java
@Service
public class HotelService {
  private final HotelRepository hotelRepository;

  public HotelService(HotelRepository hotelRepository) {
    this.hotelRepository = hotelRepository;
  }

  // 메서드 내부에 데이터를 생성하는 save() 가 있으므로 readOnly 를 false 로 설정 (디폴트라 안해도 되긴 함)
  @Transactional(readOnly = false, isolation = Isolation.SERIALIZABLE)
  public HotelCreateResponse createHotel(HotelCreateRequest createRequest) {
    // ...
  }

  // this 키워드를 사용하여 @Transactional 애너테이션이 걸려 있는 내부 메서드 호출하는 예시
  public List<HotelCreateResponse> createHotels(List<HotelCreateRequest> createRequests) {
    return createRequests.stream()
        .map(createRequest -> this.createHotel(createRequest))  // this 를 이용하여 createHotel 호출
        .collect(Collectors.toList());
  }
}
```

createHotel() 메서드에 `@Transactional` 애너테이션이 정의되어 있으며, public 접근 제어자로 선언된 메서드이므로 정상적으로 트랜잭션이 동작할 것으로 예상할 것이다.  

하지만 createHotels() this.createHotel() 을 호출하는 경우 this 는 자신의 객체를 의미하므로 ApplicationContext 가 개입하여 런타임에 
트랜잭션 코드를 프록시하여 생성할 수 없다.  
이 경우에는 createHotel() 메서드에 정의된 `@Transactional` 애너테이션이 정상 동작하지 않는다. 

**_결론은 스프링 빈에서 `this` 키워드를 사용하는 경우 정상적으로 애너테이션이 동작하지 않는다!!_**

`this` 키워드 대신 자기 자신인 HotelService 스프링 빈을 주입받아 호출해야 한다.

---

아래는 스스로 주입하는 자기 주입(Self-injection) 방식에 대한 예시이다.  
단, 생성자 주입 방식으로는 자기 주입을 할 수 없다.  
생성자 주입 방식을 사용하면 스프링 빈 객체를 생성하면서 자신의 객체를 주입해야 하므로 순환 참조(Circular reference)가 발생한다.

`@AutoWired` 를 사용하여 자기 주입
```java
@AutoWired
@Service
public class HotelService {
  @Autowired
  private HotelService hotelService;

  // ...
}
```

`@PostConstruct` 를 사용하여 자기 주입
```java
@Service
public class HotelService {
//  @Autowired
//  private HotelService hotelService;

  @Autowired
  private ApplicationContext applicationContext;

  private HotelService self;

  @PostConstruct
  private void init() {
    self = applicationContext.getBean(HotelService.class);
  }

  // ...
}
```

이제 createHotels() 메서드를 아래와 같이 수정할 수 있다.
```java
public List<HotelCreateResponse> createHotels(List<HotelCreateRequest> createRequests) {
  return createRequests.stream()
      .map(createRequest -> self.createHotel(createRequest))
      .collect(Collectors.toList());
}
```

self 스프링 빈을 사용하여 createHotel() 메서드를 호출하기 때문에 ApplicationContext 가 런타임 시점에 트랜잭션 코드들을 주입할 수 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [hibernate 6.2 공홈](https://docs.jboss.org/hibernate/orm/6.2/)
* [Entity Class의 @NoargsConstructor (access = AccessLevel.PROTECTED)](https://erjuer.tistory.com/106)