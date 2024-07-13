---
layout: post
title:  "DDD - 스펙 구현, 스펙 사용"
date:   2024-04-10
categories: dev
tags: ddd spec specification @staticMetamodel
---

이 포스트에서는 아래 내용에 대해 알아본다.

- 스펙
- JPA 스펙 구현

> 소스는 [github](https://github.com/assu10/ddd/tree/feature/chap05)  에 있습니다.

> 매핑되는 테이블은 [DDD - ERD](https://assu10.github.io/dev/2024/04/08/ddd-table/) 을 참고하세요.

---

**목차**

<!-- TOC -->
* [1. 검색을 위한 스펙 (Specification)](#1-검색을-위한-스펙-specification)
* [2. 스프링 데이터 JPA 를 이용한 스펙 구현](#2-스프링-데이터-jpa-를-이용한-스펙-구현)
  * [2.1. JPA 정적 메타 모델: `@StaticMetamodel`](#21-jpa-정적-메타-모델-staticmetamodel)
  * [2.2. intelliJ 에서 JPA 정적 메타 모델 생성](#22-intellij-에서-jpa-정적-메타-모델-생성)
* [3. 리포지터리/DAO 에서 스펙 사용](#3-리포지터리dao-에서-스펙-사용)
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

---

CQRS(Command Query Responsibility Separation) 는 명령(command) 모델과 조회(query) 모델을 분리하는 패턴이다.

> CQRS 에 대한 좀 더 상세한 설명은 [NestJS - CQRS](https://assu10.github.io/dev/2023/04/16/nest-cqrs/) 을 참고하세요.

명령 모델은 상태를 변경하는 기능을 구현할 때 사용하고, 조회 모델은 데이터를 조회하는 기능을 구현할 때 사용한다.

엔티티, 애그리거트, 리포지터리 등의 모델은 주문 취소, 배송지 변경과 같이 상태를 변경할 때 주로 사용된다.  
즉, **도메인 모델은 명령 모델로 주로 사용**된다.

이 포스트에서 볼 정렬, 페이징, 검색 조건 지정 기능 등은 주문 목록, 상품 상세와 같은 조회 기능에 대해 사용된다.

따라서 이 포스트에서는 **리포지터리(도메인 모델에 속한, 명령 모델)와 DAO(데이터 접근을 의미하는, 조회 모델)** 라는 이름을 혼용해서 사용한다.

---

# 1. 검색을 위한 스펙 (Specification)

검색 조건이 고정되어 있고 단순하다면 아래와 같이 조회 기능을 만들면 된다.
```java
public interface OrderDataDao {
    List<OrderData> findByOrderer(String ordererId, Date date);
}
```

하지만 목록 조회같은 기능은 다양한 검색 조건을 조합하는 경우가 많은데 필요한 조합마다 find 메서드를 정의하는 것은 좋은 방법이 아니다.

이렇게 **검색 조건을 다양하게 조합해야 할 때 사용하는 것이 스펙**이다.

**스펙은 애그리거트가 특정 조건을 충족하는지 검사할 때 사용하는 인터페이스**이다.

스펙 인터페이스 정의는 아래처럼 한다.
```java
public interface Specification<T> {
    public boolean isSatisfiedBy(T agg);
}
```

위에서 **_agg_ 는 검사 대상이 되는 객체**로 **스펙을 리포지터리에 사용하면 _agg_ 는 애그리거트 루트**가 되고, **스펙을 DAO 에 사용하면 _agg_ 는 검색 결과로 리턴할 
데이터 객체**가 된다.

아래는 _Order_ 애그리거트 객체가 특정 고객의 주문인지 확인하는 스펙의 예시이다.
```java
public class OrderSpec implements Specification<Order> {
    private String ordererId;
    
    public OrderSpec(String ordererId) {
        this.ordererId = ordererId;
    }
    
    public boolean isSatisfiedBy(Order agg) {
        return agg.getOrdererId().getMemberId().getId().equals(ordererId);
    }
}
```

**리포지터리나 DAO 는 검색 대상을 걸러내는 용도로 스펙을 사용**한다.

만일 리포지터리가 메모리에 모든 에그리거트를 보관하고 있다면 아래처럼 스펙을 사용할 수 있다.

> 실제로는 아래처럼 사용하지 않으니 참고만 할 것

```java
public class MemoryOrderRepository implements OrderRepository {
    public List<Order> findAll(Specification<Order> spec) {
        List<Order> orders = findAll();
        return orders.stream()
                .filter(order -> spec.isSatisfiedBy(order))
                .toList();
    }
}
```

리포지터리가 스펙을 이용해서 검색 대상을 걸러주기 때문에 특정 조건을 충족하는 애그리거트를 찾고 싶으면 원하는 스펙을 생성한 후 리포지터리에 전달해주기만 하면 된다.

```java
// 검색 조건을 표현하는 스펙 생성
Specification<Order> ordererSpec = new OrderSpec("assu");

// 리포지터리에 전달
List<Order> orders = orderRepository.findAll(orderSpec);
```

하지만 모든 애그리거트 객체를 메모리에 보관하기도 어렵고, 메모리에 다 보관한다 하더라도 조회 성능에 심각한 문제가 발생할 수 있기 때문에 실제 스펙을 위처럼 구현하지는 않는다.

실제 스펙은 사용하는 기술에 맞춰서 구현하면 된다.

---

# 2. 스프링 데이터 JPA 를 이용한 스펙 구현

스프링 데이터 JPA 는 검색 조건을 표현하기 위한 인터페이슨인 `Specification` (= 스펙 인터페이스) 를 제공한다.

스펙 인터페이스 시그니처
```java
package org.springframework.data.jpa.domain;

import java.io.Serializable;
import javax.persistence.criteria.CriteriaBuilder;
import javax.persistence.criteria.CriteriaQuery;
import javax.persistence.criteria.Predicate;
import javax.persistence.criteria.Root;
import org.springframework.lang.Nullable;

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

    default Specification<T> and(@Nullable Specification<T> other) {
        return SpecificationComposition.composed(this, other, CriteriaBuilder::and);
    }

    default Specification<T> or(@Nullable Specification<T> other) {
        return SpecificationComposition.composed(this, other, CriteriaBuilder::or);
    }

    @Nullable
    Predicate toPredicate(Root<T> root, CriteriaQuery<?> query, CriteriaBuilder criteriaBuilder);
}
```

**스펙 인터페이스에서 제네릭 타입 파라메터 T 는 JPA 엔티티 타입**이다.

아래 조건에 해당하는 스펙을 구현해보자.
- 엔티티 타입은 _OrderSummary_
- _ordererId_ 프로퍼티 값이 지정한 값과 동일함

스펙 인터페이스를 구현한 OrdererIdSpec 클래스
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import com.assu.study.order.query.dto.OrderSummary_;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import lombok.AllArgsConstructor;
import org.springframework.data.jpa.domain.Specification;

@AllArgsConstructor
// Specification<OrderSummary> 을 구현하므로 OrderSummary 에 대한 검색 조건을 표현함
public class OrdererIdSpec implements Specification<OrderSummary> {
    private String ordererId;

    @Override
    public Predicate toPredicate(Root<OrderSummary> root,
                                 CriteriaQuery<?> query,
                                 CriteriaBuilder criteriaBuilder) {
        // ordererId 프로퍼티 값이 생성자로 전달받은 ordererId 와 동일한지 비교하는 Predicate 생성
        return criteriaBuilder.equal(root.get(OrderSummary_.ordererId), ordererId);
    }
}
```

> _OrderSummary\__ 클래스에 대한 설명은 바로 다음인 [2.1. JPA 정적 메타 모델: `@StaticMetamodel`](#21-jpa-정적-메타-모델-staticmetamodel) 에 나옵니다.

스펙 구현 클래스를 개별적으로 만들지 않고 별도 클래스에 스펙 생성 기능을 모아둘 수도 있다.

아래는 _OrderSummary_ 와 관련된 스펙 생성 기능을 하나의 클래스에 모아둔 예시이다.

OrderSummarySpecs.java
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import com.assu.study.order.query.dto.OrderSummary_;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Root;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDateTime;

// OrderSummary 에 관련된 스펙 생성 기능을 하나로 모은 클래스
public class OrderSummarySpecs {
    public static Specification<OrderSummary> ordererId(String ordererId) {
        return (Root<OrderSummary> root, CriteriaQuery<?> query, CriteriaBuilder cb) ->
                cb.equal(root.get(OrderSummary_.ordererId), ordererId);
    }

    public static Specification<OrderSummary> orderDateBetween(LocalDateTime from, LocalDateTime to) {
        return (Root<OrderSummary> root, CriteriaQuery<?> query, CriteriaBuilder cb) ->
                cb.between(root.get(OrderSummary_.orderDate), from, to);
    }
}
```

**스펙 인터페이스는 함수형 인터페이스이므로 람다식을 이용하여 객체를 생성**할 수 있다.

> 함수형 인터페이스에 대한 상세한 설명은 [1.2. 함수형 인터페이스 (Functional Interface)](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#12-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-functional-interface) 을 참고하세요.

**이제 스펙 생성이 필요한 곳에서는 스펙 생성 기능을 제공하는 클래스를 이용하여 간결하게 스펙을 생성**할 수 있다.
```java
Specification<OrderSummary> spec = OrderSummarySpecs.orderDateBetween(from, to);
```

---

## 2.1. JPA 정적 메타 모델: `@StaticMetamodel`

바로 위에 나오는 코드를 보면 _OrderSummary\_.ordererId_ 코드가 있다.

_OrderSummary\__ 클래스는 JPA 정적 메타 모델을 정의한 코드이다.

```java
package com.assu.study.order.query.dto;

import jakarta.annotation.Generated;
import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.StaticMetamodel;
import java.time.LocalDateTime;

@StaticMetamodel(OrderSummary.class)
@Generated("org.hibernate.processor.HibernateProcessor")
public abstract class OrderSummary_ {

	public static final String NUMBER = "number";
	public static final String TOTAL_AMOUNTS = "totalAmounts";
	public static final String PRODUCT_ID = "productId";
	public static final String ORDERER_ID = "ordererId";
	public static final String RECEIVER_NAME = "receiverName";
	public static final String STATE = "state";
	public static final String VERSION = "version";
	public static final String ORDERER_NAME = "ordererName";
	public static final String ORDER_DATE = "orderDate";
	public static final String PRODUCT_NAME = "productName";

	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#number
	 **/
	public static volatile SingularAttribute<OrderSummary, String> number;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#totalAmounts
	 **/
	public static volatile SingularAttribute<OrderSummary, Integer> totalAmounts;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#productId
	 **/
	public static volatile SingularAttribute<OrderSummary, String> productId;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#ordererId
	 **/
	public static volatile SingularAttribute<OrderSummary, String> ordererId;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#receiverName
	 **/
	public static volatile SingularAttribute<OrderSummary, String> receiverName;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#state
	 **/
	public static volatile SingularAttribute<OrderSummary, String> state;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary
	 **/
	public static volatile EntityType<OrderSummary> class_;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#version
	 **/
	public static volatile SingularAttribute<OrderSummary, Long> version;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#ordererName
	 **/
	public static volatile SingularAttribute<OrderSummary, String> ordererName;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#orderDate
	 **/
	public static volatile SingularAttribute<OrderSummary, LocalDateTime> orderDate;
	
	/**
	 * @see com.assu.study.order.query.dto.OrderSummary#productName
	 **/
	public static volatile SingularAttribute<OrderSummary, String> productName;

}
```

**정적 메타 모델은 `@StaticMetamodel` 애너테이션을 이용해서 관련 모델을 지정**한다.

위 모드는 _OrderSummary_ 클래스의 메타 모델을 정의하고 있으며, 메타 모델 클래스는 모델 클래스 이름 뒤에 `_` 를 붙인 이름을 갖는다.

**정적 메타 모델 클래스는 대상 모델의 각 프로퍼티와 동일한 이름을 갖는 정적 필드를 정의**하며, 이 정적 필드는 프로퍼티에 대한 메타 모델로서 프로퍼티 타입에 따라 
`SingularAttribute`, `ListAttribute` 등의 타입을 사용해서 메타 모델을 정의한다.

정적 메타 모델 대신에 문자열로 프로퍼티를 지정할 수도 있다.

정적 메타 모델을 사용하는 경우
```java
@Override
public Predicate toPredicate(Root<OrderSummary> root,
                             CriteriaQuery<?> query,
                             CriteriaBuilder criteriaBuilder) {
    // ordererId 프로퍼티 값이 생성자로 전달받은 ordererId 와 동일한지 비교하는 Predicate 생성
    return criteriaBuilder.equal(root.get(OrderSummary_.ordererId), ordererId);
}
```

문자열을 사용하는 경우
```java
@Override
public Predicate toPredicate(Root<OrderSummary> root,
                             CriteriaQuery<?> query,
                             CriteriaBuilder criteriaBuilder) {
    // ordererId 프로퍼티 값이 생성자로 전달받은 ordererId 와 동일한지 비교하는 Predicate 생성
    return criteriaBuilder.equal(root.<String>get("ordererId"), ordererId);
}
```

하지만 문자열은 오타 가능성이 있으며 실행 전까지 오타가 있다는 것을 알 수 없으며, IDE 의 코드 자동 완성 기능을 사용할 수 없어서 입력할 코드가 많아진다.  
이런 이유로 **Criteria 를 사용할 때는 정적 메타 모델 클래스를 사용하는 것이 코드 안정성, 생산성 측면에서 좋다.**

정적 메타 모델 클래스를 직접 작성할 수도 있지만 하이버네이트와 같은 JPA 프로바이더는 정적 메타 모델을 생성하는 도구를 제공하므로 이 도구들을 사용하는 것이 좋다.

---

## 2.2. intelliJ 에서 JPA 정적 메타 모델 생성

pom.xml
```xml
<!-- 아래 dependency 추가 -->
<dependency>
    <groupId>org.hibernate</groupId>
    <artifactId>hibernate-jpamodelgen</artifactId>
    <version>6.5.2.Final</version>
    <type>pom</type>
    <!--            <scope>provided</scope>-->
</dependency>

<build>
<plugins>
    <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
    </plugin>
    <!-- 아래 플러그인 설정 -->
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
```

intelliJ 에서 아래와 같이 셋팅한다.

![intelliJ 셋팅](/assets/img/dev/2024/0410/metamodel.png)

_org.hibernate.jpamodelgen.JPAMetaModelEntityProcessor_

이제 clean 후 compile 을 하면 target/generated-sources 에 언더바가 붙은 정적 메타 모델이 생성된 것을 확인할 수 있다.

---

# 3. 리포지터리/DAO 에서 스펙 사용

**스펙을 충족하는 엔티티를 검색하고 싶다면 `findAll()` 메서드를 사용**한다.

`findAll()` 메서드는 스펙 인터페이스를 파라메터로 가지며, 스펙 구현체를 전달하면 특정 조건을 충족하는 엔티티 검색이 가능하다.

OrderSummaryDao.java
```java
package com.assu.study.order.query.dao;

import com.assu.study.order.query.dto.OrderSummary;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.repository.Repository;

import java.util.List;

public interface OrderSummaryDao extends Repository<OrderSummary, String> {

    // 스펙 인터페이스를 파라메터로 갖는 findAll()
    List<OrderSummary> findAll(Specification<OrderSummary> spec);
}
```

```java
// 스펙 객체 생성
Specification<OrderSummary> sepc = new OrdererIdSpec("user1");

// findAll() 로 검색
List<OrderSummary> results = orderSummaryDao.findAll(spec);
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [책 예제 git](https://github.com/madvirus/ddd-start2)
* [cross join](https://hongong.hanbit.co.kr/sql-%EA%B8%B0%EB%B3%B8-%EB%AC%B8%EB%B2%95-joininner-outer-cross-self-join/)
* [Hibernate JPA 2 Metamodel Generator](https://docs.jboss.org/hibernate/stable/jpamodelgen/reference/en-US/html_single/)
* [스프링 데이터 JPA 정적 메타 모델 생성](https://knoc-story.tistory.com/115)