---
layout: post
title:  "DDD - 리포지터리(1): 엔티티와 JPA 매핑 구현, 엔티티와 밸류 매핑(@Embeddable, @AttributeOverrides, AttributeConverter), 기본 생성자, 필드 접근 방식(@Access), 밸류 컬렉션 매핑"
date: 2024-04-07
categories: dev
tags: ddd jpa @Embeddable @AttributeOverrides @Entity @Embedded protected @Access AttributeConverter @ElementCollection @CollectionTable @OrderColumn @EmbeddedId @SecondaryTable @AttributeOverride @Inheritance @DiscriminatorColumn @DiscriminatorValue @OneToMany Collections.unmodifiableList()
---

이 포스트에서는 아래 내용에 대해 알아본다.

- JPA 를 이용한 리포지터리 구현
- 엔티티와 밸류 매핑
- 밸류 컬렉션 매핑

> 소스는 [github](https://github.com/assu10/ddd/tree/feature/chap04_01)  에 있습니다.

> 매핑되는 테이블은 [DDD - ERD](https://assu10.github.io/dev/2024/04/08/ddd-table/) 을 참고하세요.

---

**목차**

<!-- TOC -->
* [1. JPA 를 이용한 리포지터리 구현](#1-jpa-를-이용한-리포지터리-구현)
  * [1.1. 모듈 위치](#11-모듈-위치)
  * [1.2. 리포지터리 기본 기능 구현](#12-리포지터리-기본-기능-구현)
* [2. 스프링 데이터 JPA 를 이용한 리포지터리 구현](#2-스프링-데이터-jpa-를-이용한-리포지터리-구현)
* [3. 매핑 구현](#3-매핑-구현)
  * [3.1. 엔티티와 밸류 기본 매핑](#31-엔티티와-밸류-기본-매핑)
    * [3.1.1. 밸류 매핑: `@Embeddable`, `@AttributeOverrides`](#311-밸류-매핑-embeddable-attributeoverrides)
    * [3.1.2. 엔티티 매핑: `@Entity`, `@Embedded`](#312-엔티티-매핑-entity-embedded)
  * [3.2. 기본 생성자: `protected`](#32-기본-생성자-protected)
  * [3.3. 필드 접근 방식 사용: `@Access`](#33-필드-접근-방식-사용-access)
  * [3.4. `AttributeConverter` 를 이용한 밸류 매핑 처리](#34-attributeconverter-를-이용한-밸류-매핑-처리)
  * [3.5. 밸류 컬렉션: 별도 테이블 매핑: `@ElementCollection`, `@CollectionTable`, `@OrderColumn`](#35-밸류-컬렉션-별도-테이블-매핑-elementcollection-collectiontable-ordercolumn)
  * [3.6. 밸류 컬렉션: 한 개 컬럼 매핑: `AttributeConverter`, `Collections.unmodifiableSet()`](#36-밸류-컬렉션-한-개-컬럼-매핑-attributeconverter-collectionsunmodifiableset)
  * [3.7. 밸류를 이용한 ID 매핑: `@EmbeddedId`](#37-밸류를-이용한-id-매핑-embeddedid)
  * [3.8. 별도 테이블에 저장하는 밸류 매핑: `@SecondaryTable`, `@AttributeOverride`](#38-별도-테이블에-저장하는-밸류-매핑-secondarytable-attributeoverride)
  * [3.9. 밸류 컬렉션을 `@Entity` 로 매핑: `@Inheritance`, `@DiscriminatorColumn`, `@DiscriminatorValue`](#39-밸류-컬렉션을-entity-로-매핑-inheritance-discriminatorcolumn-discriminatorvalue)
    * [3.9.1. `@Entity` 로 매핑된 밸류를 컬렉션으로 매핑: `@OneToMany`, `cascade`, `orphanRemoval`](#391-entity-로-매핑된-밸류를-컬렉션으로-매핑-onetomany-cascade-orphanremoval)
      * [3.9.1.1 `@OneToMany` 매핑에서 컬렉션의 `clear()` 성능](#3911-onetomany-매핑에서-컬렉션의-clear-성능)
  * [3.10. ID 참조와 조인 테이블을 이용한 단방향 M-N 매핑](#310-id-참조와-조인-테이블을-이용한-단방향-m-n-매핑)
* [4. `ImmutableList`(Guava) 혹은 `List.of()`(java 9) vs `Collections.unmodifiableList()`](#4-immutablelistguava-혹은-listofjava-9-vs-collectionsunmodifiablelist)
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
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>
```

---

# 1. JPA 를 이용한 리포지터리 구현

도메인 모델과 리포지터리를 구현할 때 선호하는 기술 중 하나가 JPA 이다.  
객체 기반의 도메인 모델과 관계형 데이터 모델 간의 매핑을 처리하는 기술로 ORM 만한 것이 없다.

여기서는 자바의 ORM 표준인 JPA 를 이용하여 리포지터리와 애그리거트를 구현하는 방법에 대해 알아본다.

---

## 1.1. 모듈 위치

[3.4. DIP 와 아키텍처](https://assu10.github.io/dev/2024/04/01/ddd-architecture/#34-dip-%EC%99%80-%EC%95%84%ED%82%A4%ED%85%8D%EC%B2%98) 에서 본 것처럼 
리포지터리 인터페이스는 애그리거트와 같이 도메인 영역에 속하고, 리포지터리를 구현한 클래스는 인프라스트럭처 영역에 속한다.

팀 표준에 따라 리포지터리 구현 클래스를 _domain.impl_ 과 같은 패키지에 위치시킬 수도 있지만 이는 리포지터리 인터페이스와 구현체를 분리하기 위한 
타협안이지 좋은 설계는 아니다.

가능하다면 리포지터리 구현 클래스는 인프라스트럭처 영역에 위치 시켜서 인프라스트럭처에 대한 의존을 낮춰야 한다.  
예) 리포지터리 인터페이스: order.domain / 리포지터리 구현체: order.infra 

> 스프링과 JPA 로 구현할 때 대부분 스프링 데이터 JPA 를 사용함  
> 리포지터리 인터페이스만 정의하면 나머지 리포지터리 구현 객체는 스프링 데이터 JPA 가 알아서 만들어주므로 실제로 리포지터리 인터페이스를 구현할 일은 거의 없음

---

## 1.2. 리포지터리 기본 기능 구현

리포지터리가 제공하는 기존 기능은 2가지이다.
- ID 로 애그리거트 조회
- 애그리거트 저장

```java
package com.assu.study.order.command.domain;

import java.util.Optional;

public interface OrderRepository {
  Optional<Order> findById(OrderNo id);
  void save(Order order);
}
```

**인터페이스는 애그리거트 루트를 기준으로 작성**한다.

주문 애그리거트는 _Order_ 루트 엔티티 외 _OrderLine_, _Orderer_ 등의 객체를 포함하는데 이들 중에서 루트 엔티티인 _Order_ 를 기준으로 리포지터리 인터페이스를 작성한다.

**JPA 를 사용하면 트랜잭션 범위에서 변경한 데이터를 자동으로 DB 에 반영하기 때문에 애그리거트를 수정한 결과를 DB 에 저장하는 메서드를 추가할 필요는 없다.**

```java
public class ChangeOrderService {
    @Transactional
    public void changeShippingInfo(OrderNo no, ShippingInfo newShippingInfo) {
        Optional<Order> oOrder = orderRepository.findByid(no);
        Order order = oOrder.orElseThrow(() -> new OrderNotFoundException());

        order.changeShippingInfo(newShippingInfo);
    }
}
```

위 코드의 메서드는 스프링 프레임워크의 트랜잭션관리 기능을 통해 트랜잭션 범위에서 실행된다.  
메서드 실행이 끝나면 트랜잭션을 커밋하는데 이 때 JPA 는 트랜잭션 범위에서 변경된 객체의 데이터를 DB 에 반영하기 위해 UPDATE 쿼리를 실행한다.  
즉, order.changeShippingInfo() 메서드를 실행한 결과로 애그리거트가 변경되면 JPA 는 변경 데이터를 DB 에 반영하기 위해 UPDATE 쿼리를 실행한다.

ID 외의 다른 조건으로 애그리거트를 조회할 때는 JPA 의 Criteria 나 JPQL 을 사용할 수 있다.

아래는 JPQL 을 이용하여 findByOrdererId() 를 구현한 코드이다.

```java
@Override 
public List<Order> findByOrdererId(String ordererId, int startRow, int fetchSize) {
    TypedQuery<Order> query = entityManager.createQuery(
            "select o from Order o " +
                    "where o.orderer.membreId.id = :ordererId " +
                    "order by o.number.number desc",
            Order.class
    );
    query.setParameter("ordererId", ordererId);
    query.setFirstResults(startRow);
    query.setMaxResults(fetchSize);
    
    return query.getResultList();
}
```

애그리거트를 삭제할 때는 애그리거트 객체를 파라메터로 받는다.
```java
public interface OrderRepository {
    public void delete(Order order);
}
```

---

# 2. 스프링 데이터 JPA 를 이용한 리포지터리 구현

> JPA 에 대한 좀 더 상세한 내용은  
> [Spring Boot - 데이터 영속성(1): JPA, Spring Data JPA](https://assu10.github.io/dev/2023/09/02/springboot-database-1/),  
> [Spring Boot - 데이터 영속성(2): 엔티티 클래스 설계](https://assu10.github.io/dev/2023/09/03/springboot-database-2/),  
> [Spring Boot - 데이터 영속성(3): JpaRepository, 쿼리 메서드](https://assu10.github.io/dev/2023/09/09/springboot-database-3/),  
> [Spring Boot - 데이터 영속성(4): 트랜잭션과 @Transactional](https://assu10.github.io/dev/2023/09/10/springboot-database-4/),  
> [Spring Boot - 데이터 영속성(6): 엔티티 상태 이벤트 처리, 트랜잭션 생명주기 동기화 작업](https://assu10.github.io/dev/2023/09/17/springboot-database-6/)  
> 를 참고하세요.

> JPA 를 작성하는 방법에 대한 좀 더 상세한 내용은 [2. 스프링 데이터 JPA 를 이용한 스펙 구현](https://assu10.github.io/dev/2024/04/10/ddd-jpa-spec-1/#2-%EC%8A%A4%ED%94%84%EB%A7%81-%EB%8D%B0%EC%9D%B4%ED%84%B0-jpa-%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EC%8A%A4%ED%8E%99-%EA%B5%AC%ED%98%84) 을 참고하세요.

스프링과 JPA 를 함께 적용할 때는 **스프링 데이터 JPA** 를 사용한다.

스프링 데이터 JPA 는 지정한 규칙에 맞게 리포지터리 인터페이스를 정의하면 리포지터리를 구현한 객체를 알아서 만들어서 스프링 빈으로 등록해준다.

스프링 데이터 JPA 는 아래 규칙에 따라 작성한 인터페이스를 찾아서 인터페이스를 구현한 스프링 빈 객체를 자동으로 등록한다.
- org.springframework.data.repository.Repository<T, ID> 인터페이스 상속
- T 는 엔티티 타입, ID 는 식별자 타입 지정


키 클래스
```java
package com.assu.study.order.command.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;

import java.io.Serializable;

@EqualsAndHashCode  // 밸류 타입
@Getter
@RequiredArgsConstructor
@NoArgsConstructor
@Embeddable // 키 클래스
public class OrderNo implements Serializable {
    @Column(name = "order_number")
    private String number;
}
```

엔티티
```java
package com.assu.study.order.command.domain;

import com.assu.study.common.Money;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.util.List;

// 주문 (애그리거트 루트)
@Entity
@Table(name = "purchase_order")
public class Order {
    // OrderNo 타입 자체로 id 가 주문 번호임을 알 수 있음
    @EmbeddedId
    private OrderNo id; // OrderNo 가 식별자 타입
    
  // ...
}
```

> `@EmbeddedId` 에 대한 좀 더 상세한 설명은 [5.2.1. `@EmbeddedId` 과 `@Embeddable`](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#521-embeddedid-%EA%B3%BC-embeddable) 을 참고하세요.

_Order_ 를 위한 _OrderRepository_ 는 아래와 같다.

```java
package com.assu.study.order.command.domain;

import org.springframework.data.repository.Repository;

import java.util.Optional;

public interface OrderRepository extends Repository<Order, OrderNo> {
    Optional<Order> findById(OrderNo id);

    void save(Order order);
}
```

_OrderRepository_ 가 필요하면 아래와 같이 주입받아 사용한다.

CancelOrderService.java
```java
package com.assu.study.order.command.application;

import com.assu.study.order.NoOrderException;
import com.assu.study.order.command.domain.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
@Service
public class CancelOrderService {
    private final OrderRepository orderRepository;
    private final CancelPolicy cancelPolicy;

    @Transactional
    public void cancel(OrderNo orderNo, Canceller canceller) {
        Order order = orderRepository.findById(orderNo)
                .orElseThrow(() -> new NoOrderException());
        if (!cancelPolicy.hasCancellationPermission(order, canceller)) {
            throw new NoCancellablePermission();
        }
        order.cancel();
    }
}
```

NoCancellablePermission.java
```java
package com.assu.study.order.command.application;

public class NoCancellablePermission extends RuntimeException {
}
```

CancelPolicy.java
```java
package com.assu.study.order.command.domain;

import org.springframework.stereotype.Component;

public interface CancelPolicy {
    boolean hasCancellationPermission(Order order, Canceller canceller);
}
```

Canceller.java
```java
package com.assu.study.order.command.domain;

import lombok.Getter;

@Getter
public class Canceller {
    private String memberId;

    private Canceller(String memberId) {
        this.memberId = memberId;
    }

    public static Canceller of(String memberId) {
        return new Canceller(memberId);
    }
}
```

- **_OrderRepository_ 를 기준으로 엔티티 저장**
  - Order save(Order entity)
  - void save(Order entity)

- **식별자를 이용하여 엔티티 조회**
  - Order findById(OrderNo id)
    - 조회 결과가 없을 경우 null 리턴
  - Optional<Order> findById(OrderNo id)
    - 조회 결과가 없을 경우 Optional 리턴

- **_OrderRepository_ 를 기준으로 엔티티 삭제**
  - void delete(Order order)
  - void deleteById(OrderNo id)

---

# 3. 매핑 구현

---

## 3.1. 엔티티와 밸류 기본 매핑

애그리거트와 JPA 매핑을 위한 기본 규칙은 아래와 같다.
- **애그리거트 루트는 엔티티이므로 `@Entity` 로 매핑** 설정

만일 **한 테이블에 엔티티와 밸류가 같이 있다면** 아래와 같이 매핑한다.
- **밸류는 `@Embeddable` 로 매핑** 설정
- **밸류 타입 프로퍼티는 `@Embedded` 로 매핑** 설정

아래에서 주문 애그리거트를 보자.

![애그리거트로 복잡한 모델을 관리](/assets/img/dev/2024/0406/aggregate_3.png)

주문 애그리거트의 루트 엔티티는 _Order_ 이고, 이 애그리거트에 속한 _Orderer_, _ShippingInfo_ 는 밸류이다.  
그리고 _ShippingInfo_ 에 포함된 _Address_, _Receiver_ 도 밸류이다.

**루트 엔티티와 루트 엔티티에 속한 밸류는 아래처럼 한 테이블에 매핑할 때가 많다.**

![엔티티와 밸류를 한 테이블로 매핑](/assets/img/dev/2024/0407/entity_value.png)

---

### 3.1.1. 밸류 매핑: `@Embeddable`, `@AttributeOverrides`

_Orderer_ 의 _MemberId_ 는 Member 애그리거트를 ID 로 참조한다.  
_Member_ 의 ID 타입으로 사용되는 _MemberId_ 는 아래와 같이 _id_ 프로퍼티와 매핑되는 테이블 컬럼이름으로 _member_id_ 를 지정하고 있다.

MemberId.java
```java
package com.assu.study.member.command.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.io.Serializable;

@EqualsAndHashCode
@Getter
@Embeddable
public class MemberId implements Serializable {
    @Column(name = "member_id")
    private String id;

    protected MemberId() {

    }

    private MemberId(String id) {
        this.id = id;
    }

    public static MemberId of(String id) {
        return new MemberId(id);
    }
}
```

_Order_ 에 속하는 _Orderer_ 는 밸류이므로 `@Embeddable` 로 매핑한다.

_Orderer_ 의 _memberId_ 프로퍼티와 매핑되는 컬럼명은 _orderer_id_ 인데, _MemberId_ 에 설정된 컬럼명은 _member_id_ 이다.  
`@Embeddable` 타입에 설정한 컬렴명과 실제 컬럼명을 맞추기 위해 `@AttributeOverrides` 애너테이션을 사용하여 _Orderer_ 의 _memberId_ 프로퍼티와 매핑할 컬럼명을 변경한다.

Orderer.java
```java
package com.assu.study.order.command.domain;

import com.assu.study.member.command.domain.MemberId;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@EqualsAndHashCode  // 밸류 타입
@Embeddable
public class Orderer {
    // MemberId 에 정의된 멤버 변수 id 를 orderer_id 컬럼명으로 변경
    @AttributeOverrides(
            @AttributeOverride(name = "id", column = @Column(name = "orderer_id"))
    )
    private MemberId memberId;

    @Column(name = "orderer_name")
    private String name;
}
```

_Orderer_ 처럼 _ShippingInfo_ 밸류도 또 다른 밸류인 _Address_, _Receiver_ 를 포함한다.  
_Address_ 의 매핑 설정과 다른 컬럼 이름을 사용하기 위해 여기도 `@AttributeOverride` 애너테이션을 사용한다.

Address.java
```java
package com.assu.study.common;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;

@AllArgsConstructor
@NoArgsConstructor
@EqualsAndHashCode  // 밸류 타입
@Getter
@Embeddable
public class Address {
    @Column(name = "zip_code")
    private String zipCode;

    @Column(name = "address1")
    private String address1;

    @Column(name = "address2")
    private String address2;

}
```

Receiver.java
```java
package com.assu.study.order.command.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;

// 받는 사람
@NoArgsConstructor
@AllArgsConstructor
@Getter
@EqualsAndHashCode  // 밸류 타입
@Embeddable
public class Receiver {
    @Column(name = "receiver_name")
    private String name;
    
    @Column(name = "receiver_phone")
    private String phoneNumber;
}
```

ShippingInfo.java
```java
package com.assu.study.order.command.domain;

import com.assu.study.common.Address;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;

// 배송지 정보
@NoArgsConstructor
@AllArgsConstructor
@Getter
@EqualsAndHashCode  // 밸류 타입
@Embeddable
public class ShippingInfo {
    @Column(name = "shipping_message")
    private String message;

    @Embedded
    private Receiver receiver;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "zipCode", column = @Column(name = "shipping_zip_code")),
            @AttributeOverride(name = "address1", column = @Column(name = "shipping_addr1")),
            @AttributeOverride(name = "address2", column = @Column(name = "shipping_addr2"))
    })
    private Address address;
}
```

---

### 3.1.2. 엔티티 매핑: `@Entity`, `@Embedded`

루트 엔티티인 _Order_ 클래스는 `@Embedded` 애너테이션을 이용하여 밸류 타입 프로퍼티를 설정한다.

Order.java
```java
// 주문 (애그리거트 루트)
@Entity
@Table(name = "purchase_order")
public class Order {
    // OrderNo 타입 자체로 number 가 주문 번호임을 알 수 있음
    @EmbeddedId
    private OrderNo number; // OrderNo 가 식별자 타입

    @Embedded
    private Orderer orderer;    // 주문자

    @Embedded
    private ShippingInfo shippingInfo;  // 배송지 정보
  
    // ...
}
```

---

## 3.2. 기본 생성자: `protected`

엔티티와 밸류의 생성자는 객체를 생성할 때 필요한 것들을 모두 전달받는다.

_Receiver_ 밸류가 불변 타입이면 생성 시점에 필요한 값을 모두 전달받으므로 값을 변경하는 setter 를 제공하지 않는다.  
이 말은 **_Receiver_ 불변 클래스에 파라메터가 없는 기본 생성자는 추가할 필요가 없다는 것을 의미**한다.

**하지만 DB 에서 데이터를 읽어온 후 매핑된 객체를 생성할 때 기본 생성자를 사용해서 객체를 생성하기 때문에 JPA 에서 `@Entity` 와 `@Embeddable` 클래스를 매핑하려면  
기본 생성자를 제공**해야 한다.

이런 기술적인 제약 때문에 **_Receiver_ 와 같은 불변 타입은 기본 생성자가 필요없음에도 불구하고 아래와 같은 기본 생성자를 추가**해야 한다.

```java
@AllArgsConstructor
@Getter
@EqualsAndHashCode  // 밸류 타입
@Embeddable
public class Orderer {
    // MemberId 에 정의된 멤버 변수 id 를 orderer_id 컬럼명으로 변경
    @AttributeOverrides(
            @AttributeOverride(name = "id", column = @Column(name = "orderer_id"))
    )
    private MemberId memberId;

    @Column(name = "orderer_name")
    private String name;

    // JPA 를 적용하기 위해 기본 생성자 추가
    protected Orderer() {
    }
}
```

기본 생성자는 JPA 프로바이더가 객체를 생성할 때만 사용한다.

> `protected` 에 대한 좀 더 상세한 설명은 [2.1.2. 밸류 타입은 불변으로 구현](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#212-%EB%B0%B8%EB%A5%98-%ED%83%80%EC%9E%85%EC%9D%80-%EB%B6%88%EB%B3%80%EC%9C%BC%EB%A1%9C-%EA%B5%AC%ED%98%84) 을 참고하세요.

---

## 3.3. 필드 접근 방식 사용: `@Access`

JPA 는 **필드와 메서드 두 가지 방식으로 매핑**을 처리할 수 있다.

메서드 방식을 사용하려면 아래와 같이 프로퍼티를 위한 getter, setter 를 구현해야 한다.

```java
@Entity
@Access(AccessType.PROPERTY)
public class Order {
    // ...
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
}
```

**엔티티에 프로퍼티를 위한 public getter/setter 를 추가하면 도메인의 의도가 사라지고, 객체가 아닌 데이터 기반으로 엔티티를 구현할 가능성**이 높아진다.  
**특히 setter 는 내부 데이터를 외부에서 변경할 수 있는 수단이 되므로 캡슐화를 깨는 원인**이 된다.

**엔티티가 객체로서 제 역할을 하려면 외부에 setter 대신 의도가 잘 드러나는 기능을 제공**해야 한다.  
예) setShippingInfo() 메서드보다 배송지를 변경한다는 의미를 갖는 changeShippingInfo() 가 도메인을 더 잘 표현함

밸류 타입을 불변으로 구현하려면 setter 가 필요없는데 JPA 의 구현 방식 때문에 setter 를 추가하는 것은 좋지 않다.

**객체가 제공할 기능 중심으로 엔티티를 구현하게끔 유도하려면 JPA 매핑 처리를 프로퍼티 방식이 아닌 필드 방식으로 선택해서 불필요한 getter/setter 를 구현하지 말아야 한다.**

```java
@Entity
@Access(AccessType.FIELD)
public class Order {
  @EmbeddedId
  private OrderNo number; // OrderNo 가 식별자 타입
  
  // ...
  
  // cancel(), changeShippingInfo() 등 도메인 기능 구현
  // 필요한 getter 구현
}
```

**JPA 구현체인 하이버네이트는 `@Access` 를 이용해서 명시적으로 접근 방식을 지정하지 않으면 `@Id` 나 `@EmbeddedId` 가 어디에 위치했느냐에 따라 접근 방식을 결정**한다.  
**`@Id` 나 `@EmbeddedId` 가 필드에 위치하면 필드 접근 방식을 선택**하고, **getter 에 위치하면 메서드 접근 방식을 선택**한다.

---

## 3.4. `AttributeConverter` 를 이용한 밸류 매핑 처리

> `AttributeConverter` 에 대한 좀 더 상세한 내용은 [5. 엔티티 클래스 속성 변환과 `AttributeConverter`: `@Convert`, `@Converter`](https://assu10.github.io/dev/2023/09/03/springboot-database-2/#5-%EC%97%94%ED%8B%B0%ED%8B%B0-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%86%8D%EC%84%B1-%EB%B3%80%ED%99%98%EA%B3%BC-attributeconverter-convert-converter) 를 참고하세요.

밸류 타입의 프로퍼티를 하나의 컬럼에 매핑해야 할 경우가 있다.

예를 들어 아래와 같이 _Length_ 라는 밸류 타입이 DB 에는 하나의 컬럼으로 저장되어야 할 수도 있다.

```java
public class Length {
    private int value;
    private String unit;
}
```

위 내용을 _width varchar(60)_ 에 '10cm' 라는 형식으로, 즉 2개의 프로퍼티를 한 개의 컬럼에 매핑해야 할 때 `@Embeddable` 애너테이션으로는 처리할 수 없다.  
이 때는 `AttributeConverter` 를 이용하면 된다.

**`AttributeConverter` 는 밸류 타입과 컬럼 데이터 간의 변환을 처리하기 위한 기능을 제공`AttributeConverter` 는 밸류 타입과 컬럼 데이터 간의 변환을 처리하기 위한 기능을 제공**한다.

AttributeConverter 시그니처
```java
package jakarta.persistence;

public interface AttributeConverter<X, Y> {
    // 밸류 타입을 DB 컬럼값으로 변환
    Y convertToDatabaseColumn(X var1);

    // DB 컬럼값을 밸류로 변환
    X convertToEntityAttribute(Y var1);
}
```

위에서 **파라메터 X 는 밸류 타입이고, Y 는 DB 타입**이다.

Money 를 위한 AttributeConverter 는 아래와 같이 구현할 수 있다.

Money.java
```java
package com.assu.study.common;

import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.ToString;

@ToString
@AllArgsConstructor
@Getter
@EqualsAndHashCode  // 밸류 타입
public class Money {
    private int value;

    public Money add(Money money) {
        return new Money(this.value + money.value);
    }

    public Money multiply(int multiplier) {
        return new Money(this.value * multiplier);
    }
}
```

MoneyConverter.java
```java
package com.assu.study.common.jpa;

import com.assu.study.common.Money;
import jakarta.persistence.AttributeConverter;

@Converter(autoApply = true)
public class MoneyConverter implements AttributeConverter<Money, Integer> {
    @Override
    public Integer convertToDatabaseColumn(Money money) {
        return money == null ? null : money.getValue();
    }

    @Override
    public Money convertToEntityAttribute(Integer value) {
        return value == null ? null : new Money(value);
    }
}
```

`AttributeConverter` 인터페이스를 구현한 클래스는 `@Converter` 애너테이션을 적용한다.

`@Converter` 의 `autoApply` 를 true 로 설정 시 애플리케이션 전체에 글로벌로 설정이 되므로 모든 Money 타입의 프로퍼티에 대해 MoneyConverter 를 자동으로 적용한다.

예를 들어 _Order_ 의 _totalAmounts_ 프로퍼티가 _Money_ 타입인데 이 프로퍼티를 DB 의 total_amounts 컬럼에 매핑 시 자동으로 MoneyConverter 를 사용한다.

```java
// 주문 (애그리거트 루트)
@Entity
@Table(name = "purchase_order")
public class Order {
    private Money totalAmounts;   // MoneyConverter 를 적용해서 값 변환

    // ...
}
```

만약 특정 엔티티에만 설정하고 싶다면 `@Converter` 애너테이션을 사용하지 말고, `@Convert` 애너테이션을 사용하면 된다.

```java
// 주문 (애그리거트 루트)
@Entity
@Table(name = "purchase_order")
public class Order {
    @Convert(converter = MoneyConverter.class)
    private Money totalAmounts;   // MoneyConverter 를 적용해서 값 변환

    // ...
}
```

---

## 3.5. 밸류 컬렉션: 별도 테이블 매핑: `@ElementCollection`, `@CollectionTable`, `@OrderColumn`

_Order_ 엔티티는 한 개 이상의 _OrderLine_ 을 가질 수 있고, _OrderLine_ 에 순서가 있다면 아래처럼 List 타입의 컬렉션을 프로퍼티로 지정할 수 있다.

```java
public class Order {
    // ...
    private List<OrderLine> orderLines;
}
```

![밸류 컬렉션을 별도 테이블로 매핑](/assets/img/dev/2024/0407/value_collection.png)

order_line 테이블은 밸류 컬렉션을 저장하고 외부키를 이용하여 엔티티에 해당하는 purchase_order 테이블을 참조한다.  
이 외부키는 컬렉션이 속한 엔티티를 의미한다.  
List 타입의 컬렉션은 인덱스 값도 필요하기 때문에 order_line 테이블에 인덱스 값을 지정하는 line_idx 컬럼도 추가하였다.

밸류 컬렉션을 별로 테이블로 매핑할 때는 `@ElementCollection` 과 `@CollectionTable` 을 함께 사용한다.

> `@ElementCollection` 과 `@CollectionTable` 에 대한 좀 더 상세한 설명은 [5.2.2. `@ElementCollection` 과 `@CollectionTable`](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#522-elementcollection-%EA%B3%BC-collectiontable) 을 참고하세요.

Order.java
```java
// 주문 (애그리거트 루트)
@Entity
@Table(name = "purchase_order")
@Access(AccessType.FIELD)
public class Order {
    // OrderNo 타입 자체로 number 가 주문 번호임을 알 수 있음
    @EmbeddedId
    private OrderNo number; // OrderNo 가 식별자 타입

    // ...

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "order_line",
            joinColumns = @JoinColumn(name = "order_number"))
    @OrderColumn(name = "line_idx")
    private List<OrderLine> orderLines; // 주문 항목
  
    // ...
}
```

List 타입 자체가 인덱스를 갖고 있기 때문에 _OrderLine_ 에는 List 의 인덱스 값을 저장하기 위한 프로퍼티가 없다.  
그래서 JPA 는  **`@OrderColumn` 애너테이션을 이용해서 지정한 컬럼에 리스트의 인덳 값을 저장**한다.

**`@CollectionTable` 은 밸류를 저장할 테이블을 지정**한다.  
joinColumns 속성은 외부키로 사용할 컬럼을 지정한다.

OrderLine.java
```java
package com.assu.study.order.command.domain;

import com.assu.study.catalog.command.domain.product.ProductId;
import com.assu.study.common.Money;
import com.assu.study.common.jpa.MoneyConverter;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Embeddable;
import jakarta.persistence.Embedded;
import lombok.EqualsAndHashCode;
import lombok.Getter;

// 주문 항목
@Embeddable
@Getter
@EqualsAndHashCode  // 밸류 타입
public class OrderLine {
    @Embedded
    private ProductId productId;

    @Convert(converter = MoneyConverter.class)
    @Column(name = "price")
    private Money price;

    @Column(name = "quantity")
    private int quantity;

    @Convert(converter = MoneyConverter.class)
    @Column(name = "amounts")
    private Money amounts;

    protected OrderLine() {
    }
    
    public OrderLine(ProductId productId, Money price, int quantity) {
        this.productId = productId;
        this.price = price;
        this.quantity = quantity;
        this.amounts = this.calculateAmounts();
    }

    private Money calculateAmounts() {
        return price.multiply(quantity);
    }
}
```

ProductId.java
```java
package com.assu.study.catalog.command.domain.product;

import jakarta.persistence.Access;
import jakarta.persistence.AccessType;
import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.io.Serializable;

// 밸류 타입
@Embeddable
@Getter
@EqualsAndHashCode
@Access(AccessType.FIELD)
public class ProductId implements Serializable {
  @Column(name = "product_id")
  private String id;

  protected ProductId() {
  }

  private ProductId(String id) {
    this.id = id;
  }

  public static ProductId of(String id) {
    return new ProductId(id);
  }
}
```

---

## 3.6. 밸류 컬렉션: 한 개 컬럼 매핑: `AttributeConverter`, `Collections.unmodifiableSet()`

밸류 컬렉션을 별도의 테이블이 아닌 한 개의 컬럼에 저장해야 하는 경우도 있다.  
예) 도메인 모델에는 이메일 주소 목록을 Set 으로 보관하고, DB 에 저장할 때는 하나의 컬럼에 콤마로 구분하여 저장

이 때 `AttributeConverter` 를 사용하면 밸류 컬렉션을 한 개의 컬럼에 매핑할 수 있는데 단, `AttributeConverter` 를 사용하려면 밸류 컬렉션을 표현하는 
새로운 밸류 타입을 추가해야 한다.

EmailSet.java
```java
package com.assu.study.common.model;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class EmailSet {
    private Set<Email> emails = new HashSet<>();

    public EmailSet(Set<Email> emails) {
        this.emails.addAll(emails);
    }

    public Set<Email> getEmails() {
        return Collections.unmodifiableSet(emails);
    }
}
```

Email.java
```java
package com.assu.study.common.model;

import lombok.EqualsAndHashCode;
import lombok.Getter;

@Getter
@EqualsAndHashCode
public class Email {
    private String address;

    private Email(String address) {
        this.address = address;
    }

    public static Email of(String address) {
        return new Email(address);
    }
}
```

밸류 컬렉션을 위한 타입을 추가했으니 이제 `AttributeConverter` 를 구현한다.

EmailSetConverter.java
```java
package com.assu.study.common.jpa;

import com.assu.study.common.model.Email;
import com.assu.study.common.model.EmailSet;
import jakarta.persistence.AttributeConverter;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

public class EmailSetConverter implements AttributeConverter<EmailSet, String> {
    @Override
    public String convertToDatabaseColumn(EmailSet attribute) {
        if (attribute == null) {
            return null;
        }

        return attribute.getEmails().stream()
                .map(email -> email.getAddress())
                .collect(Collectors.joining(","));
    }

    @Override
    public EmailSet convertToEntityAttribute(String dbData) {
        if (dbData == null) {
            return null;
        }

        String[] emails = dbData.split(",");
        Set<Email> emailSet = Arrays.stream(emails)
                .map(value -> Email.of(value))
                .collect(Collectors.toSet());
        return new EmailSet(emailSet);
    }
}
```

이제 _EmailSet_ 타입 프로퍼티가 Converter 로 EmailSetConverter 를 사용하도록 지정하면 된다.

Member.java
```java
package com.assu.study.member.command.domain;

import com.assu.study.common.jpa.EmailSetConverter;
import com.assu.study.common.model.EmailSet;
import jakarta.persistence.*;

// 회원 (애그리거트 루트)
@Entity
@Table(name = "member")
public class Member {
    @EmbeddedId
    private MemberId id;
  
    @Embedded
    private Password password;
  
    @Column(name = "emails")
    @Convert(converter = EmailSetConverter.class)
    private EmailSet emails;
    
    // ...
}
```

Password.java
```java
package com.assu.study.member.command.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.EqualsAndHashCode;
import lombok.Getter;

@Embeddable
@Getter
@EqualsAndHashCode  // 밸류 타입
public class Password {
  @Column(name = "password")
  private String value;

  protected Password() {
  }

  public Password(String value) {
    this.value = value;
  }

  // 기존 암호와 일치하는지 확인
  public boolean match(String password) {
    return this.value.equals(password);
  }
}
```

---

## 3.7. 밸류를 이용한 ID 매핑: `@EmbeddedId`

식별자 자체를 밸류 타입으로 만들 수도 있는데, _OrderNo_, _MemberId_ 등이 식별자를 표현하기 위한 밸류 타입이다.

**밸류 타입을 식별자로 매핑하면 `@Id` 대신 `@EmbeddedId` 애너테이션을 사용**한다.

```java
// 회원 (애그리거트 루트)
@Entity
@Table(name = "member")
public class Member {
    @EmbeddedId
    private MemberId id;

    // ...
}
```

```java
// 밸류 타입
@EqualsAndHashCode
@Getter
@Embeddable
public class MemberId implements Serializable {
    @Column(name = "member_id")
    private String id;

    // ...
}
```

> `@EmbeddedId` 에 대한 좀 더 상세한 설명은 [5.2.1. `@EmbeddedId` 과 `@Embeddable`](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#521-embeddedid-%EA%B3%BC-embeddable) 을 참고하세요.

JPA 에서 식별자 타입은 `Serializable` 타입이어야 하므로 **식별자로 사용할 밸류 타입은 `Serializable` 인터페이스를 상속**받아야 한다.

**밸류 타입으로 식별자를 구별하면 식별자에 기능을 추가할 수 있다는 장점**이 있다.  
예) 기간에 따라 주문번호의 첫 글자로 시스템 버전을 구분 가능 

```java
@EqualsAndHashCode  // 밸류 타입
@Getter
@AllArgsConstructor
@Embeddable // 키 클래스
public class OrderNo implements Serializable {
    @Column(name = "order_number")
    private String number;

    public boolean is1stGeneration() {
        return number.startsWith("A");
    }
    
    // ...
}
```

---

## 3.8. 별도 테이블에 저장하는 밸류 매핑: `@SecondaryTable`, `@AttributeOverride`

**애그리거트에서 루트 엔티티를 뺀 나머지 구성 요소는 대부분 밸류**이다.

만일 루트 엔티티 외에 다른 엔티티가 있다면 진짜 엔티티인지 확인해봐야한다.

**단지 별도 테이블에 데이터를 저장한다고 해서 엔티티인 것은 아니다**.    
주문 애그리거트로 _OrderLine_ 을 별도 테이블에 저장하지만 _OrderLine_ 자체는 엔티티가 아니라 밸류이다.

**밸류가 아니라 엔티티가 확실하다면 해당 엔티티가 다른 애그리거트는 아닌지 확인**해보아야 한다.

자신만의 라이프 사이클을 갖는다면 다른 애그리거트일 가능성이 높다.  
예) 상품 상세 화면에는 상품 정보와 리뷰가 나오는데 그렇다고 해서 상품 애그리거트에 리뷰가 포함되지는 않음

_Product_ 와 _Review_ 는 함께 생성되거나 변경되지 않으며 변경 주체도 다르다.  
_Review_ 의 변경이 _Product_ 에 영향을 주지 않고, 그 반대도 마찬가지이다.

따라서 _Review_ 는 엔티티는 맞지만 상품 애그리거트가 아닌 리뷰 애그리거트에 속한 엔티티이다.

**애그리거트에 속한 객체가 밸류인지 엔티티인지 구분하는 방법은 고유 식별자를 갖는지 확인**하면 된다.

**주의할 점은 식별자를 찾을 때 매핑되는 테이블의 식별자를 애그리거트 구성 요소의 식별자와 동일한 것으로 착각하면 안된다**는 것이다.  
별도 테이블로 저장하고 테이블에 PK 가 있다고 해서 테이블과 매핑되는 애그리거트 구성 요소가 항상 고유 식별자를 갖는 것은 아니다.

아래는 밸류를 엔티티로 잘못 매핑한 예시이다.

![밸류를 엔티티로 잘못 매핑함](/assets/img/dev/2024/0407/wrong.png)

_ArticleContent_ 는 _Article_ 의 내용을 담고 있는 밸류이다.

_article_content_ 의 _id_ 는 식별자이긴 하지만 이 식별자는 _article_ 테이블의 데이터와 연결하기 위함이지, _article_content_ 를 위한 별도 식별자가 필요해서 있는 것은 아니다.  
즉, 위와 같은 경우는 게시글의 특정 프로퍼티를 별도 테이블에 보관한다는 개념으로 접근해야 한다.

_ArticleContent_ 를 엔티티가 아닌 밸류로 보고 접근하면 모델은 아래와 같이 변경된다.

![별도 테이블로 밸류를 매핑한 모델](/assets/img/dev/2024/0407/right.png)

**_ArticleContent_ 는 밸류이므로 `@Embeddable` 로 매핑**한다.  
_Article_ 과 _ArticleContent_ 가 매핑되는 테이블은 다르다.

밸류를 매핑한 테이블을 지정하기 위해 `@SecondaryTable` 과 `@AttributeOverride` 를 사용한다.

ArticleContent.java
```java
package com.assu.study.board.domain;

import jakarta.persistence.Access;
import jakarta.persistence.AccessType;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
@Embeddable
@Access(AccessType.FIELD)
public class ArticleContent {
    private String content;
    private String contentType;

    protected ArticleContent() {
    }
}
```

Article.java
```java
package com.assu.study.board.domain;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Entity
@AllArgsConstructor
@Getter
@Table(name = "article")
@SecondaryTable(
        name = "article_content",
        pkJoinColumns = @PrimaryKeyJoinColumn(name = "id")
)
public class Article {
    @Id
    private Long id;
    private String title;

    @AttributeOverrides({
            @AttributeOverride(
                    name = "content",
                    column = @Column(table = "article_content", name = "content")),
            @AttributeOverride(
                    name = "contentType",
                    column = @Column(table = "article_content", name = "content_type"))
    })
    @Embedded
    private ArticleContent content;

    protected Article() {
    }

}
```

**`@SecondaryTable` 의 name 속성은 밸류를 저장할 테이블을 지정**하고, **`pkJoinColumns` 속성은 밸류 테이블에서 엔티티 테이블로 조인할 때 사용할 컬럼을 지정**한다.

**`@AttributeOverride` 애너테이션으로는 해당 밸류 데이터가 저장된 테이블 이름을 지정**한다.

**`@SecondaryTable` 애너테이션을 이용하면 아래 코드 실행 시 두 테이블을 조인해서 데이터를 조회**한다.

```java
// @SecondaryTable 로 매핑된 article_content 테이블 조인
Article article = entityManager.find(Article.class, 1L);
```

게시글 목록을 보여주는 곳에서는 article_content 의 내용까지는 필요없다. 하지만 `@SecondaryTable` 을 사용하면 _Article_ 조회 시 _article_content_ 까지 조인해서 데이터를 
읽어오게 된다.  
이 문제를 해소하려면 _ArticleContent_ 를 엔티티로 매핑하고 _Article_ 에서 _ArticleContent_ 를 지연 로딩하면 되는데 그러면 밸류인 모델을 엔티티로 만들게 되므로 
좋은 방식이 아니다.

이럴 경우엔 **조회 전용 기능**을 구현하는 것이 좋다.

> 조회 전용 쿼리를 실행하는 방법에 대해서는  
> [DDD - 스펙(1): 스펙 구현, 스펙 사용](https://assu10.github.io/dev/2024/04/10/ddd-jpa-spec-1/),  
> [DDD - 스펙(2): 스펙 조합, Sort, 페이징(Pageable), 스펙 빌더 클래스, 동적 인스턴스 생성, @Subselect, @Immutable, @Synchronize](https://assu10.github.io/dev/2024/04/13/ddd-jpa-spec-2/) 를 참고하세요.

> 명령 모델과 조회 전용 모델을 구분하는 방법에 대해서는 [DDD - CQRS](https://assu10.github.io/dev/2024/05/05/ddd-cqrs/) 를 참고하세요.

---

## 3.9. 밸류 컬렉션을 `@Entity` 로 매핑: `@Inheritance`, `@DiscriminatorColumn`, `@DiscriminatorValue`

밸류이지만 가금은 `@Entity` 로 매핑해야 하는 경우가 있다.  
예) 이미지 업로드 방식에 따라 이미지 경로와 썸네일 제공 여부가 달라지는 경우 (= 계층 구조를 갖는 밸류 타입)

![계층 구조를 갖는 밸류 타입](/assets/img/dev/2024/0407/value.png)

**JPA 는 `@Embeddable` 타입의 클래스 상속 매핑을 지원하지 않으므로 상속 구조를 갖는 밸류 타입을 사용하기 위해서는 `@Embeddable` 대신 `@Entity` 를 이용**하여 
상속 매핑으로 처리해야 한다.

**밸류 타입이지만 `@Entity` 로 매핑하기 때문에 식별자 매핑을 위한 필드가 추가되어야 하고, 구현 클래스를 구분하기 위한 타입 식별 (Discriminator) 컬럼도 추가**되어야 한다.

![계층 구조를 저장하는 테이블](/assets/img/dev/2024/0407/value_table.png)

**한 테이블에 _Image_ 와 그 하위 클래스를 매핑하므로 _Image_ 엔티티 클래스에 아래와 같은 설정**을 한다.  
- `@Inheritance` 애너테이션 적용
- strategy 로 `SINGLE_TABLE` 사용
- `@DiscriminatorColumn` 애너테이션을 적용하여 타입 구분용으로 사용할 컬럼 지정

**_Image_ 를 `@Entity` 로 매핑하였어도 모델에서 _Image_ 는 밸류이므로 상태를 변경하는 기능은 추가하지 않는다.**

Image.java
```java
package com.assu.study.catalog.command.domain.product;


import jakarta.persistence.*;

import java.time.LocalDateTime;

// 밸류를 @Entity 로 매핑했으므로 상태 변경 메서드는 제공하지 않음
@Entity
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "image_type")
@Table(name = "image")
public abstract class Image {   // 추상 클래스임
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "image_id")
    private Long id;

    @Column(name = "image_path")
    private String path;

    @Column(name = "upload_time")
    private LocalDateTime uploadTime;

    protected Image() {
    }

    public Image(String path) {
        this.path = path;
        this.uploadTime = LocalDateTime.now();
    }

    protected String getPath() {
        return path;
    }

    public LocalDateTime getUploadTime() {
        return uploadTime;
    }

    // 이 클래스를 상속받는 클래스에서 구현할 메서드들
    public abstract String getURL();

    public abstract boolean hasThumbnail();

    public abstract String getThumbnailURL();
}
```

이제 위 _Image_ 밸류 엔티티를 상속받는 클래스를 만든다.  
이 때 `@Entity` 와 `@Discriminator` 를 사용하여 매핑을 설정한다.

InternalImage.java
```java
package com.assu.study.catalog.command.domain.product;

import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;

// Image 를 상속받은 클래스
@Entity
@DiscriminatorValue("II")
public class InternalImage extends Image {
    protected InternalImage() {
    }

    public InternalImage(String path) {
        super(path);
    }

    @Override
    public String getURL() {
        return "/images/original/" + getPath();
    }

    @Override
    public boolean hasThumbnail() {
        return true;
    }

    @Override
    public String getThumbnailURL() {
        return "/images/thumbnail/" + getPath();
    }
}
```

ExternalImage.java
```java
package com.assu.study.catalog.command.domain.product;

import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;

// Image 를 상속받은 클래스
@Entity
@DiscriminatorValue("EI")
public class ExternalImage extends Image {
    protected ExternalImage() {
    }

    public ExternalImage(String path) {
        super(path);
    }

    @Override
    public String getURL() {
        return getPath();
    }

    @Override
    public boolean hasThumbnail() {
        return false;
    }

    @Override
    public String getThumbnailURL() {
        return null;
    }
}
```

---

### 3.9.1. `@Entity` 로 매핑된 밸류를 컬렉션으로 매핑: `@OneToMany`, `cascade`, `orphanRemoval`

_Image_ 가 `@Entity`  이므로 목록을 담고 있는 _Product_ 는 `@OneToMany` 를 이용하여 매핑한다.

_Image_ 는 밸류이므로 독자적인 라이프 사이클을 갖고 있지 않기 때문에 _Product_ 에 완전히 의존한다.  
따라서 **_Product_ 가 저장/삭제될 때 동시에 저장/삭제되도록 `cascade` 속성을 지정**하고, **리스트에서 _Image_ 객체 제거 시 DB 에서도 함께 삭제되도록 `orphanRemoval` 속성도 
true** 로 설정한다.

Product.java
```java
package com.assu.study.catalog.command.domain.product;

import com.assu.study.catalog.command.domain.category.CategoryId;
import com.assu.study.common.jpa.MoneyConverter;
import com.assu.study.common.model.Money;
import jakarta.persistence.*;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "product")
public class Product {
    @EmbeddedId
    private ProductId id;

    @ElementCollection(fetch = FetchType.LAZY)  // 값 타입 컬렉션
    @CollectionTable(name = "product_category",
            joinColumns = @JoinColumn(name = "product_id")) // 테이블명 지정
    private Set<CategoryId> categoryIds;

    private String name;

    @Convert(converter = MoneyConverter.class)
    @Column(name = "price")
    private Money price;

    private String detail;

    @OneToMany(
            cascade = {CascadeType.PERSIST, CascadeType.REMOVE},    // Product 의 저장/삭제 시 함께 저장 삭제
            orphanRemoval = true,   // 리스트에서 Image 객체 제거 시 DB 에서도 함께 삭제
            fetch = FetchType.LAZY
    )
    @JoinColumn(name = "product_id")
    @OrderColumn(name = "list_idx")
    private List<Image> images = new ArrayList<>();

    protected Product() {
    }

    public Product(ProductId id, String name, Money price, String detail, List<Image> images) {
        this.id = id;
        this.name = name;
        this.price = price;
        this.detail = detail;
        this.images.addAll(images);
    }

    public ProductId getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public Money getPrice() {
        return price;
    }

    public String getDetail() {
        return detail;
    }

    public List<Image> getImages() {
        return Collections.unmodifiableList(images);
    }

    // 이미지 변경
    public void changeImages(List<Image> newImages) {
        images.clear();
        images.addAll(newImages);
    }

    public String getFirstImageThumbnailPath() {
        if (images == null || images.isEmpty()) {
            return null;
        }
        return images.get(0).getThumbnailURL();
    }
}
```

> `Collections.unmodifiableList()` 에 대한 설명은 [ 4. `ImmutableList`(Guava) 혹은 `List.of()`(java 9) vs `Collections.unmodifiableList()`](#4-immutablelistguava-혹은-listofjava-9-vs-collectionsunmodifiablelist) 을 참고하세요.

위에서 _changeImages()_ 를 보자.
```java
public void changeImages(List<Image> newImages) {
    images.clear();
    images.addAll(newImages);
}
```

이미지 교체를 위해 `clear()` 메서드를 사용하고 있는데 **`@Entity` 에 대한 `@OneToMany` 매핑에서 컬렉션의 `clear()` 메서드들 호출하면 삭제 과정이 비효율적**이다.  

하이버네이트는 `@Entity` 를 위한 컬렉션 객체의 `clear()` 메서드를 호출하면 select 로 대상 엔티티를 로딩한 후에, 
각 개별 엔티티 삭제를 위한 delete 쿼리를 각각 실행한다.  
예를 들어 _images_ 에 이미지가 4개가 있을 때 위의 _changeImages()_ 를 호출하면 아래처럼 총 5번의 쿼리가 실행된다.

```sql
-- 목록 조회
select * from image where product_id = ?;

-- 삭제
delete from image where image_id = ?;
delete from image where image_id = ?;
delete from image where image_id = ?;
delete from image where image_id = ?;
```

이미지의 변경 빈도가 낮다면 괜찮겠지만, **변경 빈도가 높다면 전체 서비스 성능에 문제**가 될 수 있다.

---

#### 3.9.1.1 `@OneToMany` 매핑에서 컬렉션의 `clear()` 성능

**하이버네이트는 `@Embeddable` 타입에 대한 컬렉션의 `clear()` 메서드를 호출하면 컬렉션에 대한 객체를 로딩하지 않고 한번의 delete 쿼리로 삭제 처리를 수행**한다.  

애그리거트의 특성을 유지하면서 `@OneToMany` 매핑에서 컬렉션의 `clear()` 성능 문제를 해소하려면 결국 상속을 포기하고 `@Embeddable` 로 매핑된 단일 클래스로 구현해야 한다.

성능을 위해 `@Embeddable` 을 사용하여 다형성을 포기하고 if-else 로 구현
```java
@Embeddable
public class Image {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "image_id")
  private Long id;
  
  @Column(name = "image_type")
  private String imageType;

  @Column(name = "image_path")
  private String path;

  @Temporal(TemporalType.TIMESTAMP)
  @Column(name = "upload_time")
  private Date uploadTime;

  // 성능을 위해 다형성을 포기하고 if-else 로 구현
  public boolean hasThumbnail() {
    if (imageType.equals("II")) {
        return true;
    } else {
        return false;
    }
  }
}
```

**즉, 코드의 유지 보수와 성능 두 가지 측면을 고려하여 구현 방식을 선택**해야 한다.

---

## 3.10. ID 참조와 조인 테이블을 이용한 단방향 M-N 매핑

애그리거트 간의 집합 연관은 성능 상의 이유로 피해야 한다.

> 애그리거트 간 집합 연관의 성능 문제에 대한 좀 더 상세한 설명은 [5. 애그리거트 간 집합 연관](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#5-%EC%95%A0%EA%B7%B8%EB%A6%AC%EA%B1%B0%ED%8A%B8-%EA%B0%84-%EC%A7%91%ED%95%A9-%EC%97%B0%EA%B4%80) 을 참고하세요.

하지만 그럼에도 불구하고 요구사항을 구현하는데 집합 연관을 사용하는 것이 유리하다면 ID 참조를 이용하여 단방향 집합 연관을 적용하면 된다.  
아래는 [5.2. 애그리거트 간 M-N 연관 관계: `member of`](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#52-%EC%95%A0%EA%B7%B8%EB%A6%AC%EA%B1%B0%ED%8A%B8-%EA%B0%84-m-n-%EC%97%B0%EA%B4%80-%EA%B4%80%EA%B3%84-member-of) 에서 
본 _Product_ 에서 _Category_ 로의 단방향 M-N 연관을 ID 참조 방식으로 구현한 예시이다.

/catalog/command/domain/product/Product.java
```java
package com.assu.study.catalog.command.domain.product;

import com.assu.study.catalog.command.domain.category.CategoryId;
import jakarta.persistence.*;

import java.util.Set;

@Entity
@Table(name = "product")
public class Product {
@EmbeddedId
private ProductId id;

    @ElementCollection  // 값 타입 컬렉션
    @CollectionTable(name = "product_category",
            joinColumns = @JoinColumn(name = "product_id")) // 테이블명 지정
    private Set<CategoryId> categoryIds;
}
```

**ID 참조를 이용한 애그리거트 간 단방향 M-N 연관은 [3.9.1. `@Entity` 로 매핑된 밸류를 컬렉션으로 매핑: `@OneToMany`, `cascade`, `orphanRemoval`](#391-entity-로-매핑된-밸류를-컬렉션으로-매핑-onetomany-cascade-orphanremoval) 에서 본 것처럼 
밸류 컬렉션 매핑과 동일한 방식으로 설정**하는 것을 알 수 있다.  
**차이점이 있다면 집합의 값에 밸류 대신 연관을 맺는 식별자가 온다는 점**이다.

**ID 참조 방식을 사용하면 `@EllementCollection` 을 이용하기 때문에 _Product_ 삭제 시 매핑에 사용한 조인 테이블의 데이터도 함께 삭제되므로 
애그리거트를 직접 참조하는 방식을 사용할 때 고민해야 하는 영속성 전파나 로딩 전략을 고민할 필요가 없다.**

---

# 4. `ImmutableList`(Guava) 혹은 `List.of()`(java 9) vs `Collections.unmodifiableList()`

`ImmutableList`(Guava) 혹은 `List.of()`(java 9) 는 불변 리스트를 생성할 때 사용한다.  
ImmutableList 객체는 생성 시점부터 불변이다.  
`of()`, `copy()` 등의 정적 팩토리 메서드를 제공한다.  
**실제로 뷰가 아닌 원본 목록의 복사본을 생성**한다.

```java
List<String> s = new ArrayList<>(Arrays.asList("a", "b"));

// 뷰가 아닌 원본 목록의 복사본 생성
List<String> s1 = List.of(s.toArray(new String[]{}));
```

**`Collections.unmodifiableList()` 는 기존 리스트를 불변 뷰로 감싸서 반환**한다.    
**원본 리스트에 대한 참조를 유지하기 때문에 원본 리스트가 변경되면 반환된 불변 뷰도 영향을 받는다.**

```java
List<String> s = new ArrayList<>(Arrays.asList("a", "b"));

// 원본 리스트를 뷰로 감싸서 리턴하며, 원본 리스트가 변경되면 반환된 불변 뷰도 영향을 받음
List<String> s1 = Collections.unmodifiableList(s);
```

<**`ImmutableList`(Guava) 혹은 `List.of()`(java 9) 를 사용하는 경우**>

- 원본 데이터에 대한 참조가 필요하지 않은 경우
- 생성 시점부터 불변을 보장해야 하는 경우

<**`Collections.unmodifiableList()`**>

- 원본 데이터에 대한 참조가 필요하고, 원본 데이터의 변경에 따라 불변 뷰도 같이 변경되어야 하는 경우

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [책 예제 git](https://github.com/madvirus/ddd-start2)
* [ImmutableList vs Collections.unmodifiableList 무엇이 다를까?](https://colevelup.tistory.com/47)