---
layout: post
title:  "DDD - "
date:   2024-04-13
categories: dev
tags: ddd 
---

이 포스트에서는 아래 내용에 대해 알아본다.

- 정렬, 페이징
- 동적 인스턴스, `@Subselect`

> 소스는 [github](https://github.com/assu10/ddd/tree/feature/chap05)  에 있습니다.

> 매핑되는 테이블은 [DDD - ERD](https://assu10.github.io/dev/2024/04/08/ddd-table/) 을 참고하세요.

---

**목차**

<!-- TOC -->
* [1. 스펙 조합](#1-스펙-조합)
  * [1.1. `and()`, `or()`](#11-and-or)
  * [1.2. `not()`, `where()`](#12-not-where)
* [2. 정렬 지정: `Sort`](#2-정렬-지정-sort)
* [3. 페이징 처리: `Pageable`, `PageRequest`, `Sort`](#3-페이징-처리-pageable-pagerequest-sort)
  * [3.1. `Page` 로 개수 구하기](#31-page-로-개수-구하기)
  * [3.2. 스펙을 사용하는 `findAll()` 에서 `Pageable` 사용](#32-스펙을-사용하는-findall-에서-pageable-사용)
  * [3.3. `findFirstN()`, `findFirst()`, `findTop()`](#33-findfirstn-findfirst-findtop)
* [4. 스펙 조합을 위한 스펙 빌더 클래스](#4-스펙-조합을-위한-스펙-빌더-클래스)
* [5. 동적 인스턴스 생성](#5-동적-인스턴스-생성)
* [6. 하이버네이트 `@Subselect` 사용: `@Immutable`, `@Synchronize`](#6-하이버네이트-subselect-사용-immutable-synchronize)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.2.5
- Spring ver: 6.1.6
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven

---

pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.assu</groupId>
    <artifactId>ddd_me</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>ddd</name>
    <description>Demo project for Spring Boot</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <scope>annotationProcessor</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <!-- https://mvnrepository.com/artifact/org.hibernate/hibernate-jpamodelgen -->
        <dependency>
            <groupId>org.hibernate</groupId>
            <artifactId>hibernate-jpamodelgen</artifactId>
            <version>6.5.2.Final</version>
            <type>pom</type>
            <!--            <scope>provided</scope>-->
        </dependency>
        <!-- https://mvnrepository.com/artifact/com.mysql/mysql-connector-j -->
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <version>8.4.0</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
        </dependency>

    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
            <plugin>
                <groupId>org.bsc.maven</groupId>
                <artifactId>maven-processor-plugin</artifactId>
                <version>2.0.5</version>
                <executions>
                    <execution>
                        <id>process</id>
                        <goals>
                            <goal>process</goal>
                        </goals>
                        <phase>generate-sources</phase>
                        <configuration>
                            <processors>
                                <processor>org.hibernate.jpamodelgen.JPAMetaModelEntityProcessor</processor>
                            </processors>
                        </configuration>
                    </execution>
                </executions>
                <dependencies>
                    <dependency>
                        <groupId>org.hibernate</groupId>
                        <artifactId>hibernate-jpamodelgen</artifactId>
                        <version>6.5.2.Final</version>
                    </dependency>
                </dependencies>
            </plugin>
        </plugins>
    </build>
</project>

```

```properties
spring.application.name=ddd
spring.datasource.url=jdbc:mysql://localhost:13306/shop?characterEncoding=utf8
spring.datasource.username=root
spring.datasource.password=
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.hikari.maximum-pool-size=10
spring.jpa.database=mysql
spring.jpa.show-sql=true
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.jpa.open-in-view=false
logging.level.root=INFO
logging.level.com.myshop=DEBUG
logging.level.org.springframework.security=DEBUG
```

---

# 1. 스펙 조합

## 1.1. `and()`, `or()`

스프링 데이터 JPA 가 제공하는 스펙 인터페이스는 스펙을 조합할 수 있는 2개의 디폴트 메서드를 제공한다.

- **`and()`**
  - 두 스펙을 모두 충족하는 조건을 표현하는 스펙 생성
- **`or()`**
  - 두 스펙 중 하나 이상 충족하는 조건을 표현하는 스펙 생성

Specification<T> 인터페이스 시그니처 일부
```java
public interface Specification<T> extends Serializable {
    long serialVersionUID = 1L;

    default Specification<T> and(@Nullable Specification<T> other) {
        return SpecificationComposition.composed(this, other, CriteriaBuilder::and);
    }

    default Specification<T> or(@Nullable Specification<T> other) {
        return SpecificationComposition.composed(this, other, CriteriaBuilder::or);
    }

    @Nullable
    Predicate toPredicate(Root<T> root, CriteriaQuery<?> query, CriteriaBuilder criteriaBuilder);

// ...
}
```

```java
Specification<OrderSummary> spec1 = OrderSummarySpecs.ordererId("user1");
Specification<OrderSummary> spec2 = OrderSummarySpecs.orderDateBetween(
        LocalDateTime.of(2024, 1, 1, 0, 0, 0),
        LocalDateTime.of(2024, 1, 2, 0, 0, 0)
);

// spec1, spec2 를 모두 충족하는 조건을 표현하는 spec3 생성
Specification<OrderSummary> spec3 = spec1.and(spec2);
```

개별 스펙 조건마다 변수 선언없이 아래처럼 바로 `and()` 메서드를 사용할 수도 있다.

/test/../OrderSummaryDaoIT.java
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.test.context.jdbc.Sql;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@Sql("classpath:shop-init-test.sql")
class OrderSummaryDaoIT {

    @Autowired
    private OrderSummaryDao orderSummaryDao;

    @Test
    void findAllSpec() {
        LocalDateTime from = LocalDateTime.of(2022, 1, 1, 0, 0, 0);
        LocalDateTime to = LocalDateTime.of(2022, 1, 2, 0, 0, 0);

        Specification<OrderSummary> spec = OrderSummarySpecs.ordererId("user1")
                .and(OrderSummarySpecs.orderDateBetween(from, to));

        List<OrderSummary> orderSummaryList = orderSummaryDao.findAll(spec);
        assertThat(orderSummaryList).hasSize(1);
    }
}
```

/test/resources/shop-init-test.sql
```sql
truncate table purchase_order;
truncate table order_line;
truncate table category;
truncate table product_category;
truncate table product;
truncate table image;
truncate table member;
truncate table member_authorities;
truncate table article;
truncate table article_content;
truncate table evententry;

insert into member (member_id, name, password, blocked) values ('user1', '사용자1', '1234', false);
insert into member (member_id, name, password, blocked) values ('user2', '사용자2', '5678', false);
insert into member (member_id, name, password, blocked) values ('user3', '사용자3', '5678', true);
insert into member (member_id, name, password, blocked) values ('user4', '사용자4', '5678', true);
insert into member (member_id, name, password, blocked) values ('user5', '사용자5', '5678', false);
insert into member (member_id, name, password, blocked) values ('user6', '사용자6', '5678', false);
insert into member (member_id, name, password, blocked) values ('user7', '사용자7', '5678', false);
insert into member (member_id, name, password, blocked) values ('user8', '사용자8', '5678', false);
insert into member (member_id, name, password, blocked) values ('admin', '운영자', 'admin1234', false);
insert into member_authorities values ('user1', 'ROLE_USER');
insert into member_authorities values ('user2', 'ROLE_USER');
insert into member_authorities values ('admin', 'ROLE_ADMIN');

insert into category values (1001, '전자제품');
insert into category values (2001, '필기구');

insert into product values ('prod-001', '라즈베리파이3 모델B', 56000, '모델B');
insert into image (product_id, list_idx, image_type, image_path, upload_time) values
  ('prod-001', 0, 'II', 'rpi3.jpg', now());
insert into image (product_id, list_idx, image_type, image_path, upload_time) values
  ('prod-001', 1, 'EI', 'http://external/image/path', now());

insert into product_category values ('prod-001', 1001);

insert into product values ('prod-002', '어프로치 휴대용 화이트보드 세트', 11920, '화이트보드');
insert into image (product_id, list_idx, image_type, image_path, upload_time) values
  ('prod-002', 0, 'II', 'wbp.png', now());

insert into product_category values ('prod-002', 2001);

insert into product values ('prod-003', '볼펜 겸용 터치펜', 9000, '볼펜과 터치펜을 하나로!');
insert into image (product_id, list_idx, image_type, image_path, upload_time) values
  ('prod-003', 0, 'II', 'pen.jpg', now());
insert into image (product_id, list_idx, image_type, image_path, upload_time) values
  ('prod-003', 1, 'II', 'pen2.jpg', now());

insert into product_category values ('prod-003', 1001);
insert into product_category values ('prod-003', 2001);

insert into purchase_order values (
'ORDER-001', 1, 'user1', '사용자1', 4000,
'123456', '서울시', '관악구', '메시지',
'사용자1', '010-1234-5678', 'PREPARING', '2022-01-01 15:30:00'
);

insert into order_line values ('ORDER-001', 0, 'prod-001', 1000, 2, 2000);
insert into order_line values ('ORDER-001', 1, 'prod-002', 2000, 1, 2000);

insert into purchase_order values (
'ORDER-002', 2, 'user1', '사용자1', 5000,
'123456', '서울시', '관악구', '메시지',
'사용자1', '010-1234-5678', 'PREPARING', '2022-01-02 09:18:21'
);
insert into order_line values ('ORDER-002', 0, 'prod-001', 1000, 5, 5000);

insert into purchase_order values (
'ORDER-003', 3, 'user2', '사용자2', 5000,
'123456', '서울시', '관악구', '메시지',
'사용자1', '010-1234-5678', 'SHIPPED', '2016-01-03 09:00:00'
);
insert into order_line values ('ORDER-003', 0, 'prod-001', 1000, 5, 5000);

insert into article (title) values ('제목');
insert into article_content values (1, 'content', 'type');

insert into evententry (type, content_type, payload, timestamp) values
  ('com.myshop.eventstore.infra.SampleEvent', 'application/json', '{"name": "name1", "value": 11}', now());
insert into evententry (type, content_type, payload, timestamp) values
  ('com.myshop.eventstore.infra.SampleEvent', 'application/json', '{"name": "name2", "value": 12}', now());
insert into evententry (type, content_type, payload, timestamp) values
  ('com.myshop.eventstore.infra.SampleEvent', 'application/json', '{"name": "name3", "value": 13}', now());
insert into evententry (type, content_type, payload, timestamp) values
  ('com.myshop.eventstore.infra.SampleEvent', 'application/json', '{"name": "name4", "value": 14}', now());
```

---

## 1.2. `not()`, `where()`

- **`not()`**
  - 스펙 인터페이스가 제공하는 정적 메서드
  - 조건을 반대로 적용할 때 사용
- **`where()`**
  - 스펙 인터페이스가 제공하는 정적 메서드
  - null 을 전달하면 아무 조건도 생성하지 않는 스펙 객체 리턴
  - null 이 아니면 인자로 받은 스펙 객체를 그대로 리턴

Specification<T> 인터페이스 시그니처 일부
```java
public interface Specification<T> extends Serializable {
  long serialVersionUID = 1L;

  static <T> Specification<T> not(@Nullable Specification<T> spec) {
    return spec == null ? (root, query, builder) -> {
      return null;
    } : (root, query, builder) -> {
      return builder.not(spec.toPredicate(root, query, builder));
    };
  }

  static <T> Specification<T> where(@Nullable Specification<T> spec) {
    return spec == null ? (root, query, builder) -> {
      return null;
    } : spec;
  }
  
  @Nullable
  Predicate toPredicate(Root<T> root, CriteriaQuery<?> query, CriteriaBuilder criteriaBuilder);

  // ...
}
```

`not()` 을 사용하여 조건을 반대로 적용할 스펙 객체 생성
```java
Specification<OrderSummary> spec = Specification.not(OrderSummarySpecs.ordererId("user1"));
```

null 가능성이 있는 스펙 객체와 다른 스펙을 조합할 때 NEP 방지를 위해 null 여부를 매번 검사해주어야 한다.
```java
Specification<OrderSummary> nullableSpec = createNullableSpec();
Specification<OrderSummary> otherSpec = createOtherSpec();

Specification<OrderSummary> spec = nullableSpec == null ? otherSpec : nullableSpec.and(otherSpec);
```

위처럼 매번 null 여부 검사를 하는 대신 `where()` 을 사용하면 아래와 같이 간단하게 사용할 수 있다.
```java
Specification<OrderSummary> spec = Specificaton.where(createNullableSpec()).and(createOtherSpec());
```

---

# 2. 정렬 지정: `Sort`

스프링 데이터 JPA 는 2 가지 방법으로 정렬을 지정할 수 있다.

- 메서드명에 `OrderBy` 를 사용하여 정렬 지정
- `Sort` 를 인자로 전달

아래는 메서드명에 `OrderBy` 를 사용하여 정렬하는 예시이다.
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.repository.Repository;

import java.util.List;

public interface OrderSummaryDao extends Repository<OrderSummary, String> {
  List<OrderSummary> findByOrdererIdOrderByNumberDesc(String ordererId);
  List<OrderSummary> findByOrdererIdOrderByOrderDateDescNumberAsc(String ordererId);
  // ...
}
```

메서드 이름에 `OrderBy` 를 사용하면 간단하긴 하지만 정렬 기준 프로퍼티가 2개 이상이 되면 메서드 이름이 길어지고, 또한 **메서드 이름으로 정렬 순서가 정해지기 때문에 
상황에 따라 정렬 순서를 변경할 수 없다.**

이럴 땐 스프링 데이터 JPA 가 제공하는 `Sort` 타입을 사용하면 된다.

OrderSummaryDao.java
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.repository.Repository;

import java.util.List;

public interface OrderSummaryDao extends Repository<OrderSummary, String> {

    List<OrderSummary> findByOrdererId(String ordererId, Sort sort);
    List<OrderSummary> findAll(Specification<OrderSummary> spec, Sort sort);
    
    // ...
}
```

/test/.../OrderSummaryDaoIT.java
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.Sort;
import org.springframework.test.context.jdbc.Sql;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@Sql("classpath:shop-init-test.sql")
class OrderSummaryDaoIT {

    @Autowired
    private OrderSummaryDao orderSummaryDao;
    
    // ...

    @Test
    void findByOrdererIdSort() {
        Sort sort = Sort.by("number").descending();
        
        List<OrderSummary> orderSummaryList = orderSummaryDao.findByOrdererId("user1", sort);

        assertThat(orderSummaryList.get(0).getNumber()).isEqualTo("ORDER-002");
        assertThat(orderSummaryList.get(1).getNumber()).isEqualTo("ORDER-001");
    }

    @Test
    void findByOrdererIdSort2() {
        // 2개의 Sort 객체를 연결
      Sort sort1 = Sort.by("number").descending();
      Sort sort2 = Sort.by("orderDate").ascending();
      Sort sort = sort1.and(sort2);
      
      List<OrderSummary> orderSummaryList = orderSummaryDao.findByOrdererId("user1", sort);
  
      assertThat(orderSummaryList.get(0).getNumber()).isEqualTo("ORDER-002");
      assertThat(orderSummaryList.get(1).getNumber()).isEqualTo("ORDER-001");
    }
}
```

---

# 3. 페이징 처리: `Pageable`, `PageRequest`, `Sort`

스프링 데이터 JPA 는 페이징 처리를 위한 `Pageable` 타입을 지원한다.  
`Sort` 타입과 마찬가지로 find() 메서드에 `Pageable` 타입 파라메터를 사용하면 페이징을 자동으로 처리해준다.

MemberDataDao.java
```java
package com.assu.study.member.query;

import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.Repository;

import java.util.List;

public interface MemberDataDao extends Repository<MemberData, String> {
    // 마지막 파라메터로 Pageable 타입을 가짐
    List<MemberData> findByNameLike(String name, Pageable pageable);
}
```

위의 _findByNameLike()_ 는 마지막 파라메터로 `Pageable` 타입을 가진다.  

MemberData.java (조회 모델)
```java
package com.assu.study.member.query;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;

// 회원 (애그리거트 루트), 조회 모델
@Getter
@Entity
@Table(name = "member")
public class MemberData {
    @Id
    @Column(name = "member_id")
    private String id;

    private String name;

    private boolean blocked;

    protected MemberData() {
    }

    public MemberData(String id, String name, boolean blocked) {
        this.id = id;
        this.name = name;
        this.blocked = blocked;
    }
}
```

`Pageable` 타입은 인터페이스로 실제 `Pageable` 타입 객체는 `PageRequest` 클래스를 이용해서 생성한다.

/test/.../MemberDataDaoIT.java
```java
package com.assu.study.member.query;

import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.test.context.jdbc.Sql;

import java.util.List;

@SpringBootTest
@Sql("classpath:shop-init-test.sql")
class MemberDataDaoIT {

  private Logger logger = LoggerFactory.getLogger(getClass());

  @Autowired
  private MemberDataDao memberDataDao;

  @Test
  void findByNameLike() {
    Sort sort = Sort.by("name").descending();
    // (페이지 넘버, 한 페이지의 개수)
    PageRequest pageReq = PageRequest.of(1, 10, sort);   

    List<MemberData> user = memberDataDao.findByNameLike("사용자%", pageReq);
    logger.info("name like result: {}", user.toString());
  }
}
```

`PageRequest.of()` 의 첫 번째 인자는 페이지 번호, 두 번째 인자는 한 페이지의 개수를 의미한다.  
페이지 번호는 0 부터 시작하므로 위 코드는 두 번째 페이지, 즉 11~10번째 데이터를 조회한다.

---

## 3.1. `Page` 로 개수 구하기

`Page` 사용 시 데이터 목록 뿐 아니라 조건에 해당하는 전체 개수도 구할 수 있다.

**`Pageable` 을 사용하는 메서드의 리턴 타입이 `Page` 이면 스프링 데이터 JPA 는 목록 조회쿼리와 함께 COUNT 쿼리도 함께 실행**한다.

> 위의 count 쿼리에 대한 관련 내용은 바로 아래 [3.2. 스펙을 사용하는 `findAll()` 에서 `Pageable` 사용](#32-스펙을-사용하는-findall-에서-pageable-사용) 에 
> 추가 비교 설명이 있습니다.

`Page` 는 전체 데이터 개수, 페이지 개수, 현재 페이지 번호 등 페이징 처리에 필요한 데이터도 함께 제공한다.

MemberDataDao.java
```java
package com.assu.study.member.query;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.Repository;

public interface MemberDataDao extends Repository<MemberData, String> {
    // 리턴 타입이 Page 이면 전체 개수, 페이지 개수 등의 데이터도 제공
    Page<MemberData> findByBlocked(boolean blocked, Pageable pageable);
}
```

/test/.../MemberDataDaoIT.java
```java
package com.assu.study.member.query;

import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.jdbc.Sql;

import java.util.List;

@SpringBootTest
@Sql("classpath:shop-init-test.sql")
class MemberDataDaoIT {

    private Logger logger = LoggerFactory.getLogger(getClass());

    @Autowired
    private MemberDataDao memberDataDao;

    // Page 사용
    @Test
    void findByBlocked() {
        Page<MemberData> page = memberDataDao.findByBlocked(false, PageRequest.of(2, 3));
        logger.info("blocked size: {}", page.getContent().size());

        List<MemberData> content = page.getContent();// 조회 결과 목록

        long totalElements = page.getTotalElements();   // 조건에 해당하는 전체 개수
        int totalPages = page.getTotalPages();  // 전체 페이지 번호
        int number = page.getNumber();  // 현재 페이지 번호
        int numberOfElements = page.getNumberOfElements();  // 조회 결과 개수
        int size = page.getSize();  // 페이지 크기

        logger.info("content.size()={}, totalElements={}, totalPages={}, number={}, numberOfElements={}, size={}",
                content.size(), totalElements, totalPages, number, numberOfElements, size);
    }
}
```

```shell
blocked size: 1
content.size()=1, totalElements=7, totalPages=3, number=2, numberOfElements=1, size=3
```

---

## 3.2. 스펙을 사용하는 `findAll()` 에서 `Pageable` 사용

스펙을 사용하는 `findAll()` 에서도 `Pageable` 사용이 가능하다.

```java
package com.assu.study.member.query;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.repository.Repository;

public interface MemberDataDao extends Repository<MemberData, String> {
    // 스펙 사용시에도 Pageagle 사용 가능
    Page<MemberData> findAll(Specification<MemberData> spec, Pageable pageable);
}
```

**`Pageable` 을 사용하더라도 리턴 타입이 `Page` 이면 COUNT 쿼리를 실행하고, List 이면 COUNT 쿼리를 실행하지 않는다.**    
따라서 **페이징 처리와 관련된 정보가 필요없다면 `Page` 가 아닌 List 로 리턴 타입을 지정하여 불필요한 COUNT 쿼리를 실행하지 않는 것이 좋다.페이징 처리와 관련된 정보가 필요없다면 `Page` 가 아닌 List 로 리턴 타입을 지정하여 불필요한 COUNT 쿼리를 실행하지 않는 것이 좋다.**

```java
// COUNT 쿼리 실행하지 않음
List<MemberData> findByNameLike(String name, Pageable pageable);

// COUNT 쿼리 실행
Page<MemberData> findByBlocked(boolean blocked, Pageable pageable);
```

**반면에 스펙을 사용하는 `findAll()` 메서드는 `Pageable` 타입을 사용하면 리턴 타입이 `Page` 가 아니어도 COUNT 쿼리를 실행**한다.

```java
// 리턴 타입이 List 이지만 스펙을 사용하므로 COUNT 쿼리 실행함
List<MemberData> findAll(Specification<MemberData> spec, Pageable pageable);
```

만일 스펙을 사용하고, 페이징 처리를 하면서 COUNT 쿼리를 실행하고 싶지 않으면 스프링 데이터 JPA 가 제공하는 커스텀 리포지터리 기능을 이용하여 직접 구현해야 한다.  

> 구현 방법은 [스프링 데이터 JPA: Pageable 대신 커스텀 리포지터리 기능을 이용하여 직접 구현](https://javacan.tistory.com/entry/spring-data-jpa-range-query) 을 
> 참고하세요.

---

## 3.3. `findFirstN()`, `findFirst()`, `findTop()`

처음부터 특정 개수의 데이터가 필요하면 `Pageable` 이 아닌 `findFirstN()`, `findFirst()`, `findTop()` 을 사용하면 된다.

```java
// 이름을 Like 로 검색한 결과를 이름 기준으로 오름차순으로 정렬 후 처음 3개 리턴
List<MemberData> findFirst3ByNameLikeOrderByName(String name);
Optional<MemberData> findFirstByNameLikeOrderByName(String name);
Optional<MemberData> findTopByNameLikeOrderByName(String name);
```

First 나 Top 을 사용해도 되며, First 나 Top 뒤에 숫자가 없으면 한 개 결과만 리턴한다.

---

# 4. 스펙 조합을 위한 스펙 빌더 클래스

조건에 따라 여러 스펙을 동적으로 조합할 때 if 문을 써서 조합하다보면 실수하기 쉬운 구조가 된다.

이럴 때 스펙 빌더를 만들어서 사용하면 위의 단점을 보완할 수 있다.

if 문을 사용할 때와 코드양은 비솟하지만 메서드를 사용해서 조건을 표현하고, 메서드 호출 체인으로 연속된 변수 할당을 줄이기 때문에 가독성이 높아지고 구조가 단순해진다.

/test/.../MemberDataDaoIT.java
```java
package com.assu.study.member.query;

import com.assu.study.common.jpa.SpecBuilder;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.test.context.jdbc.Sql;

import java.util.List;

@SpringBootTest
@Sql("classpath:shop-init-test.sql")
class MemberDataDaoIT {

  private Logger logger = LoggerFactory.getLogger(getClass());

  @Autowired
  private MemberDataDao memberDataDao;

  @DisplayName("스펙 빌더 테스트")
  @Test()
  void specBuilder() {
    SearchRequest searchRequest = new SearchRequest();
    searchRequest.setOnlyNotBlocked(true);

    Specification<MemberData> spec = SpecBuilder.builder(MemberData.class)
            .ifTrue(
                    searchRequest.isOnlyNotBlocked(),
                    () -> MemberDataSpecs.nonBlocked()
            )
            .ifHasText(
                    searchRequest.getName(),
                    name -> MemberDataSpecs.nameLike(searchRequest.getName())
            )
            .toSpec();

    List<MemberData> result = memberDataDao.findAll(spec, PageRequest.of(0, 10));

    logger.info("result: {}", result.size());   // 7
  }
}
```

MemberDataSpecs.java
```java
package com.assu.study.member.query;

import org.springframework.data.jpa.domain.Specification;

// MemberData 에 관련된 스펙 생성 기능을 하나로 모은 클래스
public class MemberDataSpecs {
    public static Specification<MemberData> nonBlocked() {
        return (root, query, cb) -> cb.equal(root.get("blocked"), false);
    }

    public static Specification<MemberData> nameLike(String keyword) {
        return (root, query, cb) -> cb.like(root.get("name"), keyword + "%");
    }
}
```


/test/.../SearchRequest.java
```java
package com.assu.study.member.query;

public class SearchRequest {
    private boolean onlyNotBlocked;
    private String name;

    public boolean isOnlyNotBlocked() {
        return onlyNotBlocked;
    }

    public void setOnlyNotBlocked(boolean onlyNotBlocked) {
        this.onlyNotBlocked = onlyNotBlocked;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}
```


SpecBuilder.java (스펙 빌더 코드)
```java
package com.assu.study.common.jpa;

import org.springframework.data.jpa.domain.Specification;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;
import java.util.function.Supplier;

// 스펙 조합 시 사용할 스펙 빌더
public class SpecBuilder {
    public static <T> Builder<T> builder(Class<T> type) {
        return new Builder<T>();
    }

    public static class Builder<T> {
        private List<Specification<T>> specs = new ArrayList<>();

        public Builder<T> and(Specification<T> spec) {
            specs.add(spec);
            return this;
        }

        public Builder<T> ifHasText(String str,
                                    Function<String, Specification<T>> specSupplier) {
            if (StringUtils.hasText(str)) {
                specs.add(specSupplier.apply(str));
            }
            return this;
        }

        public Builder<T> ifTrue(Boolean cond,
                                 Supplier<Specification<T>> specSupplier) {
            if (cond != null && cond.booleanValue()) {
                specs.add(specSupplier.get());
            }
            return this;
        }

        public Specification<T> toSpec() {
            Specification<T> spec = Specification.where(null);
            for (Specification<T> s : specs) {
                spec = spec.and(s);
            }
            return spec;
        }
    }
}
```

> `Function<T,R>: R apply(T)`, `T -> R` 에 대한 좀 더 상세한 설명은 [https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#23-functiontr-r-applyt](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#23-functiontr-r-applyt) 를 
> 참고하세요.

> `Supplier<T>: T get()`, `() -> T` 에 대한 좀 더 상세한 설명은 [1.2. 함수형 인터페이스 (Functional Interface)](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#12-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-functional-interface) 를 참고하세요.

---

# 5. 동적 인스턴스 생성




---

# 6. 하이버네이트 `@Subselect` 사용: `@Immutable`, `@Synchronize`

하이버네이트는 JPA 확장 기능으로 `@Subselet` 를 제공한다.

**`@Subselect` 는 쿼리 결과를 `@Entity` 로 매핑할 수 있는 유용한 기능**이다.

OrderSummary.java
```java
package com.assu.study.order.query.dto;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import lombok.Getter;
import org.hibernate.annotations.Immutable;
import org.hibernate.annotations.Subselect;
import org.hibernate.annotations.Synchronize;

import java.time.LocalDateTime;

@Entity
@Immutable  // 실수로 매핑 필드/프로퍼티가 수정되어도 DB 에 반영하지 않음
@Subselect(
        """
                select o.order_number as number,
                       o.version,
                       o.orderer_id,
                       o.orderer_name,
                       o.total_amounts,
                       o.receiver_name,
                       o.state,
                       o.order_date,
                       p.product_id,
                       p.name         as product_name
                from purchase_order o
                         inner join order_line ol
                                    on o.order_number = ol.order_number
                         cross join product p
                where ol.line_idx = 0
                  and ol.product_id = p.product_id
                                """
)
// 아래 3개 테이블에 변경사항이 있으면 OrderSummary 엔티티 로딩 전에 변경 내역을 먼저 flush 한 후 OrderSummary 엔티티 로
@Synchronize({"purchase_order", "order_line", "product"})
@Getter
public class OrderSummary {
    @Id
    private String number;

    private long version;

    @Column(name = "orderer_id")
    private String ordererId;

    @Column(name = "orderer_name")
    private String ordererName;

    @Column(name = "total_amounts")
    private int totalAmounts;

    @Column(name = "receiver_name")
    private String receiverName;

    private String state;

    @Column(name = "order_date")
    private LocalDateTime orderDate;

    @Column(name = "product_id")
    private String productId;

    @Column(name = "product_name")
    private String productName;

    protected OrderSummary() {
    }
}
```

> **cross join**  
> 
> 한 테이블의 모든 행과 다른 쪽 테이블의 모든 행을 조인시키는 기능  
> cross join 의 결과의 전체 행 개수는 두 테이블의 각 행의 수를 곱한 수만큼 됨  
> 카티션 곱 (cartesian product) 이라고도 함

**`@Immutable`, `@Subselect`, `@Synchronize` 는 하이버네이트의 전용 애너테이션으로 이 태그를 사용하면 테이블이 아닌 쿼리 결과를 `@Entity` 로 매핑**할 수 있다.

**`@Subselect` 는 select 쿼리를 값으로 가지고, 하이버네이트는 이 select 쿼리의 결과를 매핑할 테이블처럼 사용**한다.  

여러 테이블을 조인한 결과를 테이블처럼 사용하는 용도로 뷰를 사용하는 것처럼 `@Subselect` 를 사용하면 쿼리 실행 결과를 매핑할 테이블처럼 사용한다.  

**뷰를 수정할 수 없듯이 `@Subselect` 로 조회한 `@Entity` 역시 수정할 수 없다.**  
실수로 `@Subselect` 를 이용한 `@Entity` 의 매핑 필드를 수정하면 하이버네이트는 변경 내역을 반영하는 update 쿼리를 실행할텐데 매핑한 테이블이 없으므로 에러가 발생한다.  
이런 문제를 방지하기 위해 `@Immutable` 애너테이션을 사용한다.

**`@Immutable` 애너테이션을 사용하면 하이버네이트는 해당 엔티티의 매핑 필드/프로퍼티가 변경되도 DB 에 반영하지 않고 무시**한다.


```java
// purchase_order 테이블에서 조회
Order order = orderRepository.findById(orderNumber);
order.changeShippingInfo(newOrderInfo); // 상태 변경

// 변경 내역이 DB 에 반영되지 않았는데 purchase_order 테이블에서 조회
List<OrderSummary> summaries = orderSummaryRepository.findByOrdererId(userId);
```

위 코드는 _Order_ 의 상태를 변경한 후 _OrderSummary_ 를 조회하고 있다.  
하이버네이트는 트랜잭션을 커밋하는 시점에 변경사항을 DB 에 반영하므로 아직 _Order_ 의 변경 내역이 purchase_order 에 반영되지 않은 상태에서  
purchase_order 테이블을 사용하는 _OrderSummary_ 를 조회하게 된다.  
즉, _OrderSummary_ 는 최신값이 아닌 이전값이 담기게 된다.

이런 문제를 해결하기 위해 `@Synchronize` 애너테이션을 사용한다.

**`@Synchronize` 애너테이션은 해당 엔티티와 관련된 테이블 목록을 명시하는데 하이버네이트는 엔티티를 로딩하기 전에 명시된 테이블과 관련된 변경이 발생하면 flush 를 먼저 한다.**  
위에선 _OrderSummary_ 의 `@Synchronize` 는 purchase_order 테이블을 명시하고 있으므로 **_OrderSummary_ 를 로딩하기 전에 purchase_order 테이블에 
변경사항이 있으면 관련 내역을 먼저 flush 하기 때문에 _OrderSummary_ 를 로딩하는 시점에서는 변경 내역이 반영**된다.

**`@Subselect` 를 사용해도 일반 `@Entity` 와 동일하기 때문에 EntityManager#find(), JPQL, Criteria 를 사용해서 조회할 수 있고, 스펙을 사용**할 수도 있다.

여기서부터 다시 설명~~~~~

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [책 예제 git](https://github.com/madvirus/ddd-start2)
* [cross join](https://hongong.hanbit.co.kr/sql-%EA%B8%B0%EB%B3%B8-%EB%AC%B8%EB%B2%95-joininner-outer-cross-self-join/)
* [Hibernate JPA 2 Metamodel Generator](https://docs.jboss.org/hibernate/stable/jpamodelgen/reference/en-US/html_single/)
* [스프링 데이터 JPA 정적 메타 모델 생성](https://knoc-story.tistory.com/115)
* [스프링 데이터 JPA: Pageable 대신 커스텀 리포지터리 기능을 이용하여 직접 구현](https://javacan.tistory.com/entry/spring-data-jpa-range-query)