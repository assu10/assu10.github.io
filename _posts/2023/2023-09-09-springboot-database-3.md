---
layout: post
title:  "Spring Boot - 데이터 영속성(3): JpaRepository, 쿼리 메서드"
date:   2023-09-03
categories: dev
tags: springboot msa database spring-data-jpa query-method data-jpa-test jpa-repository
---

이 포스트에서는 Spring Data JPA 에서 제공하는 리포지터리와 쿼리 메서드 전략으로 데이터를 쉽게 사용하는 법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap08) 에 있습니다.

---

**목차**

- [리포지토리 개발과 JpaRepository](#1-리포지토리-개발과-jparepository)
- [Spring Data JPA 의 쿼리 메서드](#2-spring-data-jpa-의-쿼리-메서드)
  - [메서드명으로 쿼리 생성](#21-메서드명으로-쿼리-생성)
  - [테스트 케이스](#22-테스트-케이스)
    - [`@SpringBootTest` 를 사용한 테스트 케이스](#221-springboottest-를-사용한-테스트-케이스)
    - [`@DataJpaTest` 를 사용한 테스트 케이스](#222-datajpatest-를-사용한-테스트-케이스)
  - [`@Query` 를 사용한 쿼리 사용](#23-query-를-사용한-쿼리-사용)

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

# 1. 리포지토리 개발과 JpaRepository

JPA/Hibernate 와 Spring Data JPA 를 사용하여 영속성을 개발할 때 엔티티 클래스와 리포지토리 클래스를 생성하고 개발한다.  

**엔티티 클래스는 테이블과 자바 객체를 매핑하는 목적**으로 사용한다.    
**이 엔티티 객체를 사용하여 데이터베이스에 저장/조회/수정/삭제하는 기능을 제공하는 클래스가 리포지토리 클래스**이다.  

<**리포지토리 클래스의 메서드를 구현하는 방법**>  
- **Spring Data JPA 에서 제공하는 JpaRepository 인터페이스와 쿼리 메서드 기능을 사용하여 구현**
- JPA/Hibernate 의 EntityManager 의 메서드를 사용하여 구현
- Criteria, QueryDSL 같은 쿼리를 생성할 수 있는 '쿼리 도메인' 에 특화된 언어를 사용하여 구현

이 포스트에서는 **Spring Data JPA 에서 제공하는 JpaRepository 인터페이스와 쿼리 메서드 기능을 사용하여 구현** 에 대해 알아본다.

---

우선 리포지토리 클래스와 DAO 클래스가 개념적으로 어떻게 다른지 먼저 알아본다.

영속성 프레임워크에 따라 데이터를 영속하는 기능을 제공하는 클래스를 JPA/Hibernate 에서는 Repository 라고 하고, MyBatis 에서는 DAO (Data Access Object) 라고 한다.  

- Repository
  - 도메인 주도 개발(DDD) 방법론에서 사용하는 패턴
  - 데이터 저장소를 캡슐화하여 데이터 저장소 종류에 상관없이 객체들을 검색/저장
  - 그래서 Repository 클래스는 일관된 형태의 메서드들을 제공
  - JPA/Hibernate 프레임워크는 데이터베이스를 한 단계 추상화한 프레임워크이므로 데이터베이스 종류에 상관없이 일관된 개발 방법으로 데이터 영속 가능
- DAO
  - MyBatis 는 개발 단계에서 데이터베이스를 미리 선정하고, 그 데이터베이스에 맞는 쿼리문을 작성
  - 직접 SQL 쿼리를 작성해야 하는 MyBatis 는 데이터베이스에 깊게 의존하는 형태이므로 Repository 라고 할 수 없음
  - Mapper.xml 에 SQL 구문을 정의하고, 이를 DAO 자바 클래스에서 호출하는 패턴임

---

Spring Data JPA 는 o.s.data.jps.repository.JpaRepository 인터페이스와 이를 구현한 SimpleJpaRepository 구현체를 제공한다.  
SimpleJpaRepository 내부를 보면 JPA/Hibernate 의 EntityManager 클래스를 사용하여 리포지토리 클래스의 CRUD 를 구현한다.  
참고로 EntityManager 는 JPA/Hibernate 에서 엔티티 객체를 영속하는 기능을 담당하며, SimpleJpaRepository 가 EntityManager 에 의존하는 형태이다.

JpaRepository 는 데이터를 저장하는 `save()`, 데이터를 조회하는 `findAll()` 같은 일반적인 메서드를 제공하며,  
개발자가 Repository 를 생성할 때 JpaRepository 를 상속받으면 기본 CRUD 메서드들을 상속받을 수 있다. 

---

/repository/HotelRepository.java
```java
package com.assu.stury.chap08.repository;

import com.assu.stury.chap08.domain.HotelEntity;
import com.assu.stury.chap08.domain.HotelStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository // HotelRepository 를 스프링 빈으로 등록하여 다른 스프링 빈 객체에 주입할 수 있도록 함
// JpaRepository<T, ID> 는 두 가지 제네릭 타입을 받음
// 첫 번째 인자는 영속할 대산인 엔티티 클래스이고, 두 번째 인자는 엔티티 클래스에 정의한 기본키의 클래스 타입
public interface HotelRepository extends JpaRepository<HotelEntity, Long> {
  List<HotelEntity> findByStatus(HotelStatus status);
}
```

JpaRepository 의 가장 최상위 부모 Repository 인터페이스는 마킹 클래스이다.  
즉, 이를 구현하는 클래스는 Repository 라는 것을 표현하기 위함이며, 마킹 클래스이므로 내부에 정의된 메서드는 없다.

JpaRepository<T, ID> 는 두 가지 제네릭 타입을 받는데, 
첫 번째 인자는 영속할 대산인 엔티티 클래스이고, 두 번째 인자는 엔티티 클래스에 정의한 기본키의 클래스 타입이다.

<**JpaRepository 인터페이스에서 제공하는 몇 가지 메서드들**>
- `<S extends T> S save(S entity)`
  - 인자로 넘긴 엔티티 객체를 데이터베이스에 저장
  - 데이터베이스에서 조회한 엔티티 객체를 수정 후 이를 인자로 넘기면 레코드 값 업데이트
- `<S extends T> List<S> saveAll(Iterable<S> entities)`
  - 인자로 넘긴 엔티티 객체를 모두 저장
- `boolean existsById(ID id)`
  - 엔티티 객체의 기본키를 인자로 넘기면 이와 매핑되는 엔티티 객체가 존재하는지 여부 확인
- `Optional<T> findById(ID id)`
  - 기본키를 인자로 전달하면 매핑되는 엔티티 객체를 리턴
  - 데이터가 없으면 빈 값을 저장한 Optional 객체 리턴
- `List<T> findAllById(Iterable<ID> ids)`
  - 기본키값들과 매핑되는 엔티티 객체들을 리턴
  - 엔티티 객체들이 없으면 리스트 크기가 0인 리스트 객체 리턴
- `Page<T> findAll(Pageable pageable)`
  - 페이지 번호와 페이지 크기, 정렬 조건 같은 정보를 담고 있는 Pageable 의 조건과 매칭되는 엔티티 객체들을 응답
  - 이 때 응답하는 클래스는 엔티티 객체들을 포함할 수 있는 Page 임
- `long count()`
  - 저장소에 저장된 전체 엔티티 객체의 개수 리턴
- `void deleteById(ID id)`
  - 기본키와 매핑되는 엔티티 객체를 삭제
- `void deleteAll(Iterable<? extends T> entities)`
  - 조회한 엔티티들을 인자로 넘기면 저장소에서 삭제

---

# 2. Spring Data JPA 의 쿼리 메서드

Spring Data JPA 는 JpaRepository 와 SimpleJpaRepository 에서 미리 구현된 기능을 제공하는 것 외에 **사용자가 필요한 쿼리를 직접 구현할 수 있는 
쿼리 메서드** 기능을 제공한다.

<**쿼리 메서드가 제공하는 기능**>  
- [메서드명으로 쿼리 생성](#21-메서드명으로-쿼리-생성)
- [`@Query` 애너테이션으로 쿼리 실행](#23-query-를-사용한-쿼리-사용)
- JPA Named Query 실행

본 포스트에선 메서드명으로 쿼리 생성, `@Query` 애너테이션으로 쿼리 실행, 이 두 가지 방법에 대해 알아본다.

JPA Named Query 는 SQL 쿼리를 엔티티 클래스에 정의한 후 이를 리포지토리에서 불러 실행하는 방식이고,  
`@Query` 애너테이션은 리포지터리 클래스에 SQL 쿼리를 정의해서 실행하는 방식이다.

리포지토리 클래스는 데이터베이스에서 데이터를 처리하는 기능을 담당한다.  
따라서 SQL 쿼리를 엔티티 클래스에 정의하는 JPA Named Query 는 로직이 엔티티 클래스와 리포지토리 클래스에 분산이 된다.  
`@Query` 애너테이션을 사용한 방법이 코드 응집력 면에서 더 좋다.

---

## 2.1. 메서드명으로 쿼리 생성

아래와 같이 HotelRepository 에 추상 메서드를 선언하면 애플리케이션이 시작할 때 규칙에 맞는 쿼리가 생성된다.

```java
List<HotelEntity> findByStatus(HotelStatus status);
```

```mysql
SELECT * FROM hotels WHERE status = :status
```

findByStatus() 는 `By` 를 기준으로 2 개의 파트로 볼 수 있다.  
첫 번째 파트는 SQL 쿼리의 종류를 설정할 수 있는 키워드이고, 두 번째 파트는 쿼리의 WHERE 절을 생성할 수 있는 조합니다.

쿼리 종류를 설정할 수 있는 키워드는 아래와 같다.

- `findBy...`
  - SELECT 쿼리와 매핑
  - 리턴 타입: 엔티티 클래스, Optional 클래스, 리스트 클래스 형태
- `deleteBy...`
  - DELETE 쿼리와 매핑
  - 리턴 타입: void
- `countBy...`
  - SELECT count(*) FROM 쿼리와 매핑
  - 리턴 타입: long
- `existBy...`
  - SELECT * FROM 쿼리와 매핑
  - 리턴 타입: boolean

INSERT 쿼리와 매핑되는 `save()` 와 `saveAll()` 는 WHERE 절이 없기 때문에 `By` 키워드와 사용할 수 없다.  
UPDATE 쿼리와 매핑되는 메서드명은 없으며, 데이터베이스에서 조회한 엔티티 객체를 수정한 후 `save()`, `saveAll()` 메서드의 인자로 넘기면 update 쿼리가 실행된다.

`By` 키두의 뒤에는 조건들을 조합하여 메서드에 추가할 수 있는데, 엔티티 클래스의 속성 이름을 사용하여 쿼리의 WHERE 조건에 추가할 수 있다.  
엔티티 클래스의 속성을 이용하여 조건절에 사용하는 것을 **속성 표현식** 이라고 한다.

**쿼리의 조건절에 하나 이상의 조건을 조합할 때 사용하는 키워드**들은 아래와 같다.

- `And`
  - findByStatusAndName(HotelStatus status, String name)
  - where status = :status and name = :name
- `Or`
  - findByStatusOrName(HotelStatus status, String name)
   where status = :status or name = :name
- `Is`, `Equals`
  - findByStatus(HotelStatus status), findByStatusIs(HotelStatus status), findByStatusEquals(HotelStatus status)
  - 3 개의 쿼리 모두 변환된 쿼리가 동일함, `Is`, `Equals` 는 생략 가능하지만 의도를 명확하게 넣고 싶을 때 사용
  - where status = :status
- `Between`
  - findByCreatedAtBetween(ZonedDateTime beginAt, ZonedDateTie endAt)
  - where created_at between :beginAt and :endAt
- `LessThan`
  - findByCreatedAtLessThan(ZonedDateTime createdAt)
  - where created_at < :createdAt
- `LessThanEquals`
  - findByCreatedAtLessThanEquals(ZonedDateTime createdAt)
  - where created_at <= :createdAt
- `GreaterThan`
  - findByCreatedAtGreaterThan(ZonedDateTime createdAt)
  - where created_at > :createdAt
- `GreaterThanEquals`
  - findByCreatedAtGreaterThanEquals(ZonedDateTime createdAt)
  - where created_at >= :createdAt
- `IsNull`, `Null`
  - findByStatusIsNull()
  - where status is null
- `IsNotNull`, `NotNull`
  - findByStatusIsNotNull()
  - where status not null
- `OrderBy`
  - findByStatusOrderByName(HotelStatus status)
  - where status = :status order by name asc
  - findByStatusOrderByNameDesc(HotelStatus status)
  - where status = :status order by name desc
- `Not`
  - findByStatusNot(HotelStatus status)
  - where status <> :status
- `In`
  - findByStatusIn(Collection<HotelStatus> statuses)
  - where status in (?, ?,...?)
- `NotIn`
  - findByStatusNotIn(Collection<HotelStatus> statuses)
  - where status not in (?, ?,...?)

위의 키워드를 조합하여 아래와 같은 복잡한 쿼리도 쿼리 메서드로 생성 가능하다.
```java
void deleteByStatusInAndCreatedAtBetweenAndNameIsNull(HotelStatus status, ZonedDateTime beginCreatedAt, ZonedDateTime endCreatedAt);
```

```mysql
DELETE FROM hotels WHERE status = :status AND created_at BETWEEN :beginCreatedAt AND :endCreatedAt AND name is null
```

이 외에도 더 복잡한 쿼리를 만들어야 할 때는 `@Query` 나 `@NamedQuery` 애너테이션을 사용하여 네이티브 쿼리를 작성할 수 있다.  
혹은 JPQL, QueryDSL 과 같은 도메인 특화 언어를 사용한다.

---

## 2.2. 테스트 케이스

이제 리포지토리 쿼리 메서드를 테스트한다.

`@SpringBootTest` 애너테이션을 사용한 테스트와 테스트 슬라이드 애너테이션인 `@DataJpaTest` 을 사용하여 테스트한다.

`@SpringBootTest` 애너테이션은 모든 스프링 빈을 로딩하여 테스트하는 반면에 `@DataJpaTest` 는 JPA 관련 설정과 `@Repository` 애너테이션이 선언된 
스프링 빈만 로딩하여 테스트한다.

---

### 2.2.1. `@SpringBootTest` 를 사용한 테스트 케이스

먼저 아래 의존성을 추가한다.

pom.xml
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

아래 HotelRepositoryTest00.java 는 HotelRepository 의 findByStatus() 메서드의 기능을 테스트한다.

test > /repository/HotelRepositoryTest00.java
```java
package com.assu.stury.chap08.repository;

import com.assu.stury.chap08.domain.HotelEntity;
import com.assu.stury.chap08.domain.HotelStatus;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest // 모든 스프링 빈 로딩
@Transactional  // 테스트케이스에 `@Transactional` 을 선언하면 테스트가 끝난 후 해당 작업 롤백
//@TestPropertySource(locations = "classpath:application-test.properties")
class HotelRepositoryTest00 {

  private static HotelEntity testHotelEntity;

  // 테스트 대상 클래스인 HotelRepository 스프링 빈을 주입받음
  @Autowired
  private HotelRepository hotelRepository;

  // 모든 테스트 케이스들을 실행할때마다 초기값 설정
  @BeforeEach
  void setUp() {
    testHotelEntity = HotelEntity.of("ASSU HOTEL", "SEOUL", "+8201011112222", 100);
  }

  @Test
  void testFindByStatus() {
    // Given (테스트 케이스를 준비하는 과정 (=어떤 상황이 주어졌을 때), 객체 초기화)
    hotelRepository.save(testHotelEntity);

    // When (테스트 실행 (= 대상 코드가 동작한다면))
    HotelEntity hotelEntity = hotelRepository.findByStatus(HotelStatus.READY)
        .stream()
        .filter(entity -> entity.getHotelId().equals(testHotelEntity.getHotelId()))
        .findFirst()
        .get();

    // Then (테스트를 검증 (= 기대한 값과 수행 결과가 맞는지))
    Assertions.assertNotNull(hotelEntity);
    Assertions.assertEquals(testHotelEntity.getAddress(), hotelEntity.getAddress());
    Assertions.assertEquals(testHotelEntity.getName(), hotelEntity.getName());
    Assertions.assertEquals(testHotelEntity.getPhoneNumber(), hotelEntity.getPhoneNumber());
  }
}
```

```shell
Hibernate: 
    /* insert for
        com.assu.stury.chap08.domain.HotelEntity */insert 
    into
        hotels (address,created_at,created_by,modified_at,modified_by,name,phone_number,room_count,status) 
    values
        (?,?,?,?,?,?,?,?,?)
Hibernate: 
    /* <criteria> */ select
        h1_0.hotel_id,
        h1_0.address,
        h1_0.created_at,
        h1_0.created_by,
        h1_0.modified_at,
        h1_0.modified_by,
        h1_0.name,
        h1_0.phone_number,
        h1_0.room_count,
        h1_0.status 
    from
        hotels h1_0 
    where
        h1_0.status=?
```
---

### 2.2.2. `@DataJpaTest` 를 사용한 테스트 케이스

애플리케이션 실행 환경이 여러개라면 각각의 실행 환경에서 독립적인 데이터베이스가 필요하다.  
이런 상황이라면 애플리케이션에서 동작하는 메모리 기반의 H2 데이터베이스를 사용하는 것도 좋다.  
테스트 애플리케이션이 실행되면 H2 데이터베이스가 해당 애플리케이션과 같이 실행되어 테스트 애플리케이션마다 독립된 데이터베이스에 테스트할 수 있다.  
즉, 테스트 인스턴스마다 독립된 테스트 케이스를 실행할 수 있다는 장점이 있다.

아래의 테스트 전략은 `@DataJpaTest` 애너테이션과 잘 어울린다.
- prod 환경에서는 MySQL 을 사용하고, 테스트 환경에서는 H2 메모리 데이터베이스를 사용하여 테스트를 진행
- 애플리케이션을 실행하는 환경에서는 JPA/Hibernate 의 DDL 자동 생성 기능을 사용하지 않지만, 테스트 환경에서는 자동으로 DDL 을 생성하고 실행하는 기능을 사용하여 H2 데이터베이스에 테이블을 설정함

pom.xml 에 메모리 기반의 데이터 베이스 의존성을 포함하면 자동으로 DataSource 를 생성하여 기존 애플리케이션에서 생성한 DataSource 를 재정의한다.

`@DataJpaTest` 와 함께 사용할 수 있는 메모리 데이터베이스는 H2, Derby, HSQL 이다.  
이들 의존성을 pom.xml 에 추가한 후 `@DataJpaTest` 애너테이션이 설정된 테스트 케이스를 실행하기만 하면 자동으로 모두 설정된다.

pom.xml
```xml
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>test</scope>
</dependency>
```

/resources/application-test-h2.properties
```properties
# 웹 관련 스프링 빈이나 컴포넌트들을 생성하지 않음
spring.main.web-application-type=none

## JPA configuration
spring.jpa.open-in-view=false
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.generate_statistics=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect
# ddl-auto 속성을 create 로 하여 테스트 케이스 실행 시 @Entity 가 설정된 엔티티 클래스로 DDL 구문 자동 생성
spring.jpa.hibernate.ddl-auto=create    
```

test > /repository/HotelRepositoryTest01.java
```java
@DataJpaTest
//@Transactional  // @DataJpaTest 에 @Transactional 이 이미 포함되어 있음
@TestPropertySource(locations = "classpath:application-test-h2.properties")
class HotelRepositoryTest01 {
  // ...
}
```

```shell
Hibernate: 
    drop table if exists hotels cascade 
Hibernate: 
    create table hotels (
        room_count integer,
        status integer,
        created_at timestamp(6) with time zone,
        hotel_id bigint generated by default as identity,
        modified_at timestamp(6) with time zone,
        address varchar(255),
        created_by varchar(255),
        modified_by varchar(255),
        name varchar(255),
        phone_number varchar(255),
        primary key (hotel_id)
    )
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
Hibernate: 
    /* insert for
        com.assu.stury.chap08.domain.HotelEntity */insert 
    into
        hotels (address,created_at,created_by,modified_at,modified_by,name,phone_number,room_count,status,hotel_id) 
    values
        (?,?,?,?,?,?,?,?,?,default)
Hibernate: 
    /* <criteria> */ select
        h1_0.hotel_id,
        h1_0.address,
        h1_0.created_at,
        h1_0.created_by,
        h1_0.modified_at,
        h1_0.modified_by,
        h1_0.name,
        h1_0.phone_number,
        h1_0.room_count,
        h1_0.status 
    from
        hotels h1_0 
    where
        h1_0.status=?
```

---

## 2.3. `@Query` 를 사용한 쿼리 사용

Spring Data JPA 에서 제공하는 `@Query` 애너테이션을 사용하면 원하는 쿼리를 작성해서 실행할 수 있다.  

`@Query` 는 JPQL 과 SQL 을 실행할 수 있다.

> **JPQL**    
> 
> JPA 표준에 정의된 Java Persistence Query Language 의 약어  
> SQL 문법을 기반으로 개발되어 SQL 문법과 매우 흡사함    
> 하지만 관계형 데이터베이스에서 직접 실행되지 않으므로 데이터베이스에 독립적임  
> 즉, JPA 처럼 데이터베이스에 의존하지 않는 쿼리를 작성할 수 있는 장점이 있음

JPQL 에서 사용할 수 있는 구문은 SELECT, UPDATE, DELETE 이다. (INSERT 는 안됨)

JPQL 구문
```jpaql
SELECT h FROM hotels AS h WHERE h.status = 1;
DELETE FROM hotels AS h WHERE h.hotelId = 2;
UPDATE hotels AS h SET h.name = 'ASSU' WHERE h.hotelId = 3;
```

JPQL 은 데이터베이스에 저장된 '엔티티 객체' 를 다루기 위한 것이므로, 여기서 hotels 는 데이터베이스의 테이블명이 아닌 엔티티 클래스명이다.  
따라서 INSERT 구문도 없으며, hotels 라는 이름의 엔티티 객체를 쿼리한다.

아래처럼 `@Entity` 애너테이션에 name 를 설정한다.

/entity/HotelEntity.java
```java
@Getter
@Table(name = "hotels")
@Entity(name = "hotels")
public class HotelEntity extends AbstractManageEntity {
  // ...
}
```

`@Query` 애너테이션은 메서드에 선언할 수 있다.

`@Query` 애너테이션의 주요 속성은 아래와 같다.
- `value`
  - 실행할 JPQL 또는 쿼리를 설정
- `nativeQuery`
  - true/false
  - value 에 설정된 쿼리가 실제 쿼리라면 true 로 설정


아래는 `@Query` 애너테이션과 JPQL 을 사용하여 개발자가 직접 만든 쿼리를 실행하는 예시이다.

/repository/HotelRepository.java
```java
package com.assu.stury.chap08.repository;

import com.assu.stury.chap08.domain.HotelEntity;
import com.assu.stury.chap08.domain.HotelStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository // HotelRepository 를 스프링 빈으로 등록하여 다른 스프링 빈 객체에 주입할 수 있도록 함
// JpaRepository<T, ID> 는 두 가지 제네릭 타입을 받음
// 첫 번째 인자는 영속할 대상인 엔티티 클래스이고, 두 번째 인자는 엔티티 클래스에 정의한 기본키의 클래스 타입
public interface HotelRepository extends JpaRepository<HotelEntity, Long> {
  List<HotelEntity> findByStatus(HotelStatus status);

  @Query(value = "SELECT h FROM hotels AS h WHERE h.hotelId = ?1 AND h.status = 0")
  HotelEntity findReadyOne(Long hotelId);

  @Query("SELECT h FROM hotels AS h WHERE h.hotelId = :hotelId AND h.status = :status")
  HotelEntity findOne(@Param("hotelId") Long hotelId, @Param("status") HotelStatus status);
}
```


test > HotelRepositoryTest02.java
```java
package com.assu.stury.chap08.repository;

import com.assu.stury.chap08.domain.HotelEntity;
import com.assu.stury.chap08.domain.HotelStatus;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.TestPropertySource;


@DataJpaTest
//@Transactional  // @DataJpaTest 에 @Transactional 이 이미 포함되어 있음
@TestPropertySource(locations = "classpath:application-test-h2.properties")
class HotelRepositoryTest02 {

  private static HotelEntity testHotelEntity;

  // 테스트 대상 클래스인 HotelRepository 스프링 빈을 주입받음
  @Autowired
  private HotelRepository hotelRepository;

  // 모든 테스트 케이스들을 실행할때마다 초기값 설정
  @BeforeEach
  void setUp() {
    testHotelEntity = HotelEntity.of("ASSU HOTEL", "SEOUL", "+8201011112222", 100);
  }

  @Test
  void testFindOne() {
    // Given (테스트 케이스를 준비하는 과정 (=어떤 상황이 주어졌을 때), 객체 초기화)
    hotelRepository.save(testHotelEntity);

    // When (테스트 실행 (= 대상 코드가 동작한다면))
    HotelEntity hotelEntity = hotelRepository.findOne(testHotelEntity.getHotelId(), HotelStatus.READY);

    // Then (테스트를 검증 (= 기대한 값과 수행 결과가 맞는지))
    Assertions.assertEquals(testHotelEntity, hotelEntity);
  }

  @Test
  void testFindReadyOne() {
    // Given
    hotelRepository.save(testHotelEntity);

    // When
    HotelEntity hotelEntity = hotelRepository.findReadyOne(testHotelEntity.getHotelId());

    // Then
    Assertions.assertEquals(testHotelEntity, hotelEntity);
  }
}
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [hibernate 6.2 공홈](https://docs.jboss.org/hibernate/orm/6.2/)
* [JPA에서 @Transient 애노테이션이 존재하는 이유](https://gmoon92.github.io/jpa/2019/09/29/what-is-the-transient-annotation-used-for-in-jpa.html)