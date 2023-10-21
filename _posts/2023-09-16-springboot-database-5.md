---
layout: post
title:  "Spring Boot - 데이터 영속성(5): EntityManager"
date:   2023-09-16
categories: dev
tags: springboot msa database entity-manager persistence-context
---

이 포스팅에서는 트랜잭션과 EntityManager 의 관계에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap08) 에 있습니다.

---

**목차**

- [EntityManager](#1-entitymanager)
- [EntityManager 와 영속성 컨텍스트](#2-entitymanager-와-영속성-컨텍스트)
  - [비영속 상태 (NEW)](#21-비영속-상태-new)
  - [영속 상태 (MANAGED)](#22-영속-상태-managed)
  - [준영속 상태 (DETACHED)](#23-준영속-상태-detached)
  - [삭제 상태 (REMOVED)](#24-삭제-상태-removed)
- [영속성 컨텍스트의 특징](#3-영속성-컨텍스트의-특징)
  - [1차 캐시](#31-1차-캐시)
  - [동일성 보장](#32-동일성-보장)
  - [지연 쓰기와 변경 감지](#33-지연-쓰기와-변경-감지)

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

# 1. EntityManager

Spring Data JPA 프레임워크에서 제공하는 JpaRepository 인터페이스를 상속만 해도 이미 만들어진 `save()`, `delete()` 와 같은 메서드들을 상속하여 사용할 수 있다.  
Spring Data JPA 프레임워크는 JpaRepository 에 정의된 메서드들을 내부에서 미리 구현했으며, 구현 클래스는 SimpleJpaRepository 이다.  

이 SimpleJpaRepository 클래스는 Hibernate 프레임워크에서 제공하는 클래스와 메서드를 사용하여 CRUD 메서드들을 제공한다.  
따라서 개발자들은 Hibernate 프레임워크의 기능을 사용하는 것이다.

데이터베이스에서 데이터를 처리하는 CURD 기능들은 Hibernate 프레임워크가 처리하고 있기 때문에 Hibernate 의 기능을 모르면 개발자 의도와 상관없이 
비효율적으로 데이터베이스를 사용할 수 있다.  
Hibernate 의 내부 구조에 대한 이해없이는 성능 튜닝이나 장애 대응에 어려움이 있을 수 있다.

Hibernate 프레임워크에서 사장 중요한 역할을 하는 것은 `EntityManager` 클래스이다.

**`EntityManager` 클래스는 데이터를 처리하는 메서드와 영속성 컨텍스트 기능을 제공**한다. 즉, **데이터베이스에서 엔티티 객체를 처리하는 기능**을 제공한다.

아래는 SimpleJpaRepository 클래스이다.

SimpleJpaRepository.java 일부
```java
package org.springframework.data.jpa.repository.support;

@Repository
@Transactional(
        readOnly = true
)
public class SimpleJpaRepository<T, ID> implements JpaRepositoryImplementation<T, ID> {
  private final EntityManager entityManager;

  public SimpleJpaRepository(JpaEntityInformation<T, ?> entityInformation, EntityManager entityManager) {
    this.escapeCharacter = EscapeCharacter.DEFAULT;
    Assert.notNull(entityInformation, "JpaEntityInformation must not be null");
    Assert.notNull(entityManager, "EntityManager must not be null");
    this.entityInformation = entityInformation;
    this.entityManager = entityManager;
    this.provider = PersistenceProvider.fromEntityManager(entityManager);
  }

  @Transactional
  public void delete(T entity) {
    Assert.notNull(entity, "Entity must not be null");
    if (!this.entityInformation.isNew(entity)) {
      Class<?> type = ProxyUtils.getUserClass(entity);
      T existing = this.entityManager.find(type, this.entityInformation.getId(entity));
      if (existing != null) {
        this.entityManager.remove(this.entityManager.contains(entity) ? entity : this.entityManager.merge(entity));
      }
    }
  }
  
  // ...
  
}
```

엔티티 객체를 삭제하는 JpaRepository 의 delete() 메서드는 EntityManager 클래스에서 제공하는 여러 메서드를 사용하여 데이터를 삭제한다.

Spring Data JPA 프레임워크는 JPA/Hibernate 프레임워크를 추상화한 계층으로 실제로 엔티티 객체들을 영속하는 과정은 모두 JPA/Hibernate 의 `EntityManager` 클래스의 
메서드를 사용한다.  
그래서 개발자가 JpaRepository 에서 상속받은 `save()`, `findOne()` 같은 메서드를 사용해도 결국 `EntityManager` 의 메서드를 호출한다.

스프링 부트 프레임워크는 `EntityManager` 를 자동 설정하고, 설정된 `EntityManager` 는 스프링 빈으로 관리된다.  
따라서 애플리케이션을 개발하면서 `EntityManager` 가 필요하면 생성자 주입, Setter 메서드 주입 방식으로 의존성을 주입받으면 된다.  

아니면 `@PersistenceContext` 로 주입받아도 된다.  
`@PersistenceContext` 는 `EntityManager` 를 주입하는 기능한 제공한다.

> `@PersistenceContext` 는 과거 버전의 스프링 프레임워크에서 제공하는 기능임

---

# 2. EntityManager 와 영속성 컨텍스트

데이터베이스에 엔티티 객체를 삭제하려고 JpaRepository 의 `delete()` 메서드를 호출하면 SimpleJpaRepository 내부에서는 EntityManager 클래스의 `remove()` 메서드를 호출한다.

JPA/Hibernate 는 데이터는 삭제하는 과정은 아래와 같다.

- 엔티티 객체를 관리하고 있는 영속성 컨텍스트에서 해당 엔티티 객체 제외
- 그리고 특정 시점이 되면 엔티티 객체와 매핑되는 레코드를 삭제하는 DELETE 쿼리를 데이터베이스에 실행

EntityManager 의 remove() 메서드를 호출하는 시점과 DELETE 쿼리가 실행되는 시점이 다를 수 있는데 이를 **영속성 컨텍스트의 지연 쓰기** 라고 한다.

영속성 컨텍스트(Persistence context) 는 영속하려는 엔티티 객체의 집합을 의미하며, 엔티티 객체의 생명 주기를 관리하는 컨텍스트 객체이다.  
스프링 프레임워크의 스프링 빈을 관리하는 ApplicationContext 와 비슷한 개념이다.

**영속성 컨텍스트는 엔티티 객체를 보관하고 상태를 관리하는 역할을 하며, 엔티티 객체의 상태에 따라 적절한 쿼리를 데이터베이스에 실행**한다.  

**EntityManager 클래스는 엔티티 객체를 영속성 컨텍스트로 조회하거나 저장/삭제하는 기능을 제공**한다.

<**EntityManager 의 특징**>  
- 생명주기를 관리하는 영속성 컨텍스트에 엔티티 객체를 관리할 수 있는 메서드들을 제공
  - EntityManager 가 제공하는 `persist()`, `remove()`, `flush()`, `getReferencce()` 와 같은 메서드를 사용하면 엔티티 객체를 영속성 컨텍스트에 저장/삭제/조회할 수 있음
- EntityManager 는 멀티 스레드에 안전하지 않으므로 스레드마다 하나씩 생성해야 함
  - 따라서 JPA/Hibernate 프레임워크는 EntityManagerFactory 클래스를 사용하여 스레드별로 EntityManager 를 생성함
- EntityManager 는 내부적으로 Connection 객체를 사용하여 데이터베이스에 쿼리를 실행함

---

영속성 프레임워크는 엔티티 객체를 아래 4 가지 상태로 정의한다.  
그리고 엔티티 객체의 최종 상태에 따라 데이터베이스에 적절한 INSERT, UPDATE, SELECT, DELETE 쿼리를 실행한다.

- **비영속 상태 (NEW)**
  - 엔티티 객체가 영속성 컨텍스트에 포함되지 않은 상태
  - 엔티티 클래스를 `new` 키워드로 생성한 객체는 비영속 상태
- **영속 상태 (MANAGED)**
  - 엔티티 객체가 영속성 컨텍스트에 포함되어 영속성 컨텍스트가 관리하는 상태
- **준영속 상태 (DETACHED)**
  - 엔티티 객체가 영속성 컨텍스트에 포함되었다가 분리된 상태
  - 준영속 상태의 객체는 언제든 다시 영속 상태로 돌아갈 수 있다는 부분에서 처음부터 영속성 컨텍스트에 포함되지 않은 비영속 상태와는 다름
- **삭제 상태 (REMOVED)**
  - 영속성 컨텍스트에서 삭제된 상태

아래는 영속성 컨텍스트의 4 가지 상태와 상태 천이를 나타낸 것이다.  
보면 비영속 상태의 엔티티 객체는 바로 삭제 삭태로 갈 수 없고, 영속 상태로 이동한 후 삭제 상태로 이동할 수 있다.

![영속성 컨텍스트의 엔티티 객체 상태도](/assets/img/dev/2023/0916/persistence_context.png)

---

## 2.1. 비영속 상태 (NEW)

**애플이케이션에서 엔티티 객체를 생성하면 바로 비영속 상태**가 된다.  
엔티티 객체의 상태도에서 가장 초기 단계이다.  

**비영속 상태는 EntityManager 의 관리 범위에 포함되지 않는다.** 따라서 비영속 상태의 엔티티 객체는 데이터베이스에 저장되거나 조회될 수 없는 상태이다.  
영속성 컨텍스트에 관리된 상태에서만 베이터베이스에 저장/수정/삭제가 가능하다.

비영속 상태가 될 수 있는 객체는 `@Entity` 애너테이션이 선언된 엔티티 클래스 타입만 가능하다.

엔티티 객체를 생성하는 코드
```java
HotelEntity hotelEntity = new HotelEntity();
```

---

## 2.2. 영속 상태 (MANAGED)

**영속 상태는 엔티티 객체가 영속성 컨텍스트에 포함되어 관리되는 상태**이다.  

엔티티 객체가 영속 상태로 될 수 있는 상태는 2 가지이다.

- 비영속 상태에서 영속 상태로 변경
  - `new` 키워드를 사용하여 비영속 상태가 된 엔티티 객체를 EntityManager 클래스의 `persist()` 메서드를 사용하여 영속 상태로 변경
- 데이터베이스에 저장된 데이터를 조회하여 바로 영속 상태의 객체를 생성
  - 이미 데이터베이스에 저장된 데이터를 조회하는 것이므로 바로 영속 상태가 됨

아래는 영속 상태의 엔티티 객체를 생성하려고 `persist()` 와 `find()` 메서드를 사용한 예시이다.
```java
HotelEntity hotelEntity = entityManager.persist(new HotelEntity);
HotenEntity hotelEntity = entityManager.find(HotelEntity.class, 10L);
```

---

## 2.3. 준영속 상태 (DETACHED)

**준영속 상태는 영속 상태의 엔티티 객체가 엔티티 컨텍스트의 관리 밖으로 빠진 상태**이다.  

영속성 컨텍스트는 더 이상 준영속 상태의 엔티티 객체를 관리하지 않기 때문에 데이터베이스에 변경된 값이 저장/생성/삭제되지 않는다.

영속 상태의 객체는 EntityManager 의 `detach()`, `clear()`, `close()` 와 같은 메서드로 준영속 상태로 변경되고,  
준영속 상태의 객체를 데이터베이스에 영속할 때는 `merge()` 메서드를 사용하여 영속 상태로 변경해야 한다.

아래는 데이터베이스에서 조회한 영속 상태의 엔티티 객체를 `detach()` 메서드를 사용하여 준영속 상태로 변경하는 예시이다.
```java
HotelEntity hotelEntity = entityManager.find(HotelEntity.class, 1L);
entityManager.detach(hotelEntity);
```

준영속 상태로 변경하는 EntityManager 의 메서드는 아래와 같다.
- `public void detach(Object entity)`
  - 인자로 받는 엔티티 객체만 준영속 상태로 변경
- `public void clear()`
  - 영속성 컨텍스트를 초기화함
  - 따라서 영속성 컨텍스트에서 관리하는 모든 엔티티 객체는 모두 준영속 상태로 변경됨
- `public void close()`
  - 영속성 컨텍스트를 종료함
  - `clear()` 와 마찬가지로 관리되던 모든 엔티티 객체는 모두 준영속 상태로 변경됨
  - 컨텍스트가 종료되었으므로 더 이상 준영속 상태의 객체는 같은 영속성 컨텍스트에 영속 상태로 변경될 수 없음

아래는 영속 상태의 엔티티 객체를 준영속 상태로 변경하고 다시 영속 상태로 변경하는 예시이다.
```java
HotelEntity hotelEntity = entityManager.find(HotelEntity.class, 10L); // 영속 상태
entityManager.detach(hotelEntity);  // 준영속 상태
entityManager.merge(hotelEntity); // 영속 상
```

---

## 2.4. 삭제 상태 (REMOVED)

**영속 상태의 엔티티 객체를 영속성 컨텍스트에서 삭제한 상태**이다.  
삭제 상태는 오직 영속 상태의 엔티티 객체만 변경 가능하다.

삭제 상태로 변경하려면 EntityManager 의 `remove()` 메서드를 사용한다.

**삭제 상태는 데이터베이스에서 삭제 상태의 엔티티 객체와 매핑되는 레코드를 지울 때 사용**한다.  

아래는 EntityManager 의 `remove()` 메서드를 사용하시는 예시이다.
```java
HotelEntity hotelEntity = entityManager.find(HotelEntity.class, 2L);
entityManager.remove(hotelEntity);
```

---

# 3. 영속성 컨텍스트의 특징

새로 만들어진 엔티티 객체는 INSERT 쿼리를 사용하고, 데이터베이스에 저장된 엔티티 객체의 속성이 변경되었으면 UPDATE 쿼리를 사용하고, 삭제된 엔티티 객체는 
DELETE 쿼리를 사용한다.    
**`flush()` 메서드를 실행할 때 INSERT, UPDATE, DELETE 쿼리들이 데이터베이스에 실행되는데 이것이 영속성 컨텍스트의 변경 감지와 쓰기 지연 특성**이다.

애플리케애션 영역에 포함된 영속성 컨텍스트는 비즈니스 로직과 데이터베이스 사이에 끼어있는 모습이다.

애플리케이션에서는 **쿼리와 관련된 모든 일련의 작업을 영속성 컨텍스트가 담당**한다.

쿼리를 직접 작성하는 SQL Mapper 프레임워크는 데이터베이스에 실행하는 쿼리를 최적화하는 것을 중요하게 생각한다.  
쿼리 수를 줄이고 최적화하며, 쿼리의 실행속도를 빠르게 하고자 쿼리 튜닝도 한다.  
쿼리 숫자가 많으면 데이터베이스와 애플리케이션 사이에 I/O 가 발생하는데 이 때 네트워크 지연때문에 전반적인 성능 하락이 발생한다.  
또한 쿼리를 실행하는 동안 쿼리를 실행하는 스레드를 블록킹상태가 되기 때문에, 애플리케이션은 쿼리 중심으로 로직이 변경되고 클래스의 코드를 쿼리를 최적화하는데 집중되어 
더 이상 비즈니스 로직을 이해하게 어렵게 된다.

JPA/Hibernate 프레임워크를 도입해도 성능 이슈들은 항상 발생할 수 있다.  
JPA/Hibernate 는 애플리케이션 성능 향상을 위해 1차 캐시 개념을 사용한다.  

영속성 컨텍스트가 1차 캐시 역할을 하면서 영속 상태의 객체를 빠르게 처리할 수 있도록 아래 기능을 제공한다.

- **1차 캐치**
  - 애플리케이션의 메모리에 영속성 컨텍스트가 엔티티를 저장하므로 빠른 응답 가능
- **동일성 보장**
  - 영속성 컨텍스트는 식별자를 사용하여 엔티티 객체를 구분
- **쓰기 지연**
  - INSERT, DELETE 같은 동작을 매번 데이터베이스에 반영하는 것이 아니라 EntityManager 의 `flush()` 메서드가 실행될 때 한 번에 반영 
- **변경 감지(더티 체크)**
  - 영속 상태에 있는 엔티티 객체의 수정 여부를 관리하고, UPDATE 쿼리를 데이터베이스에 반영
  - 쓰기 지연 특성으로 UPDATE 쿼리도 한 번에 실행됨
- **지연 로딩**
  - 연관 관계에 있는 엔티티 객체들은 지연 로딩 설정에 따라 참조될 때 로딩할 수 있음

---

## 3.1. 1차 캐시

**JPA/Hibernate 프레임워크의 영속성 컨텍스트는 1차 캐시 역할**을 한다.  
애플리케이션은 영속성 컨텍스트에서 데이터를 조회/수정/삭제하는 등의 작업을 하고, 영속성 컨텍스트는 데이터베이스에 동기화한다.

영속성 컨텍스트는 영속 상태의 엔티티 객체를 메모리에 관리한다. (= 영속 상태의 객체는 캐시된 형태로 저장됨)

**한 트랜잭션 안에서 같은 데이터를 여러 번 조회할 때 첫 번째 조회때는 데이터베이스에 쿼리해서 영속성 컨텍스트에 저장하지만 두 번째 요청부터는 영속성 컨텍스트에서 보관하는 
엔티티 객체를 응답**한다.  
마찬가지로 같은 엔티티 객체를 여러 번 삭제하거나 수정해도 영속성 컨텍스트는 매번 쿼리를 실행하지 않는다.  
EntityManager 의 `flush()` 메서드가 실행되면 변경 사항들을 종합하여 최종 결과만 데이터베이스에 동기화한다.  

그래서 이를 **1차 캐시**라고 한다.

일반적인 캐시 프레임워크는 공유 자원으로 사용 가능하며, 멀티 스레드 환경에서 사용할 수 있지만 영속성 컨텍스트는 멀티 스레드에 안전하지 않아서 스레드마다 새로 생성된다.  
그래서 일반적인 캐시 프레임워크의 성능 향상을 기대해서는 안된다.  

**JPA/Hibernate 의 1차 캐시는 하나의 스레드에서 같은 데이터를 여러 번 조회/수정/삭제하는 경우에만 유효**하다.  
멀티 스레드에서 같은 데이터를 조회하더라도 캐시처럼 동작할 수 없다.

1차 캐시로서의 영속성 컨텍스트 예시
```java
HotelEntity hotelEntity1 = hotelRepository.findById(10L);
HotelEntity hotelEntity2 = hotelRepository.findById(10L);
```

영속성 컨텍스트는 hotelEntity1 객체를 조회할 때는 데이터베이스에 SELECT 쿼리를 실행하지만, hotelEntity2 객체를 조회할때는 hotelEntity1 과 같은 객체를 응답한다.  
이미 같은 레코드 값을 가진 영속 상태의 엔티티 객체를 관리하고 있기 때문에 다시 쿼리할 필요가 없다.

---

## 3.2. 동일성 보장

**영속성 컨텍스트는 엔티티 객체들을 구분하고자 엔티티 객체의 `@Id` 값을 식별자로 사용**한다.  
영속성 컨텍스트의 모든 영속 상태 엔티티 객체들은 고유한 식별자를 갖고 있고, 같은 식별자로 영속성 컨텍스트에서 조회하면 같은 객체를 리턴하므로 동일성을 보장한다.

예를 들어 HotelEntity 클래스는 `@Id` 애너테이션이 정의된 Long 타입의 hotelId 가 식별자이다.  
따라서 **같은 hotelId 를 사용하여 영속성 컨텍스트에서 조회하면 같은 엔티티 객체를 리턴하므로 자바 객체도 동일**하다.  
`equals()` 나 `==` 연산자를 사용하여 두 객체를 비교하면 항상 true 값을 리턴한다.

동일성을 보장하는 영속성 컨텍스트 예시
```java
HotelEntity hotelEntity1 = hotelRepository.findById(10L);
HotelEntity hotelEntity2 = hotelRepository.findById(10L);

Assertions.assertTrue(hotelEntity1.equals(hotelEntity2));   // true
Assertions.assertTrue(hotelEntity1 == hotelEntity2);   // true
```

---

## 3.3. 지연 쓰기와 변경 감지

**영속성 컨텍스트는 영속 상태의 엔티티 객체의 생셩/변경 여부를 관리**한다.    
그래서 엔티티 객체의 변경 여부와 신규 생성 여부를 확인하여 UPDATE 와 INSERT 쿼리를 실행할 수 있다.  
이는 **영속성 컨텍스트의 변경 감지 기능** 덕분이다.

데이터베이스에 엔티티 객체를 동기화되는 과정은 EntityManager 의 `flush()` 메서드가 호출되는 시점이다.  
JPA/Hibernate 는 트랜잭션을 정상 종료할 때 EntityManager 의 `flush()` 메서드를 실행하고 커밋 명령어를 실행한다.  
그래서 코드에서 실행한 EntityManager 의 `persist()` 메서드 시점과 실제 데이터베이스에 동기화되어 쿼리가 실행되는 시점이 다른데 이렇게 **실제 쿼리가 지연되어 
실행되므로 지연 쓰기**라고 한다.

아래는 쓰기 지연과 변경 감지 예시이다.  

```java
@Transactional    // 트랜잭션 시작, 영속성 컨텍스트 생성
public void updateHotelName(Long hotelId, String hotelName) {
  // hotelId 와 식별자가 일치하는 hotelEntity 를 데이터베이스에서 조회
  // 데이터베이스에 데이터가 있으면 hotelEntity 객체를 영속 상태로 관리함
  HotelEntity hotelEntity = hotelRepository.findById(hotelId);
  if (Objects.isNull(hotelEntity)) {
    return;
  }
  
  // 영속성 컨텍스트가 변경 여부 감지
  hotelEntity.updateHotelName(hotelName);
} 
// @Transactional 애너테이션은 AOP 방식의 메커니즘으로 트랜잭션을 관리하므로 메서드가 종료되는 시점에 트랜잭션을 커밋하고 종료함, 이 때 호텔명이 변경되었으므로 영속 상태의 호텔 엔티티는 UPDATE 쿼리를 실행하고 데이터베이스와 동기화됨
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [hibernate 6.2 공홈](https://docs.jboss.org/hibernate/orm/6.2/)