---
layout: post
title:  "DDD - "
date:   2024-04-07
categories: dev
tags: ddd 
---

이 포스트에서는 아래 내용에 대해 알아본다.

- JPA 를 이용한 리포지터리 구현
- 엔티티와 밸류 매핑
- 밸류 컬렉션 매핑

> 소스는 [github](https://github.com/assu10/ddd/tree/feature/chap04_01)  에 있습니다.

---

**목차**

<!-- TOC -->
* [1. JPA 를 이용한 리포지터리 구현](#1-jpa-를-이용한-리포지터리-구현)
  * [1.1. 모듈 위치](#11-모듈-위치)
  * [1.2. 리포지터리 기본 기능 구현](#12-리포지터리-기본-기능-구현)
* [2. 스프링 데이터 JPA 를 이용한 리포지터리 구현](#2-스프링-데이터-jpa-를-이용한-리포지터리-구현)
* [3. 매핑 구현](#3-매핑-구현)
  * [3.1. 엔티티와 밸류 기본 매핑](#31-엔티티와-밸류-기본-매핑)
  * [3.2. 기본 생성자](#32-기본-생성자)
  * [3.3. 필드 접근 방식 사용](#33-필드-접근-방식-사용)
  * [3.4. `AttributeConverter` 를 이용한 밸류 매핑 처리](#34-attributeconverter-를-이용한-밸류-매핑-처리)
  * [3.5. 밸류 컬렉션: 별도 테이블 매핑](#35-밸류-컬렉션-별도-테이블-매핑)
  * [3.6. 밸류 컬렉션: 한 개 컬럼 매핑](#36-밸류-컬렉션-한-개-컬럼-매핑)
  * [3.7. 밸류를 이용한 ID 매핑](#37-밸류를-이용한-id-매핑)
  * [3.8. 별도 테이블에 저장하는 밸류 매핑](#38-별도-테이블에-저장하는-밸류-매핑)
  * [3.9. 밸류 컬렉션을 `@Entity` 로 매핑](#39-밸류-컬렉션을-entity-로-매핑)
  * [3.10. ID 참조와 조인 테이블을 이용한 단방향 M-N 매핑](#310-id-참조와-조인-테이블을-이용한-단방향-m-n-매핑)
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
> [Spring Boot - 데이터 영속성(3): JpaRepository, 쿼리 메서드](https://assu10.github.io/dev/2023/09/03/springboot-database-3/), 
> [Spring Boot - 데이터 영속성(4): 트랜잭션과 @Transactional](https://assu10.github.io/dev/2023/09/10/springboot-database-4/), 
> [Spring Boot - 데이터 영속성(6): 엔티티 상태 이벤트 처리, 트랜잭션 생명주기 동기화 작업](https://assu10.github.io/dev/2023/09/17/springboot-database-6/) 
> 를 참고하세요.

스프링과 JPA 를 함께 적용할 때는 스프링 데이터 JPA 를 사용한다.

스프링 데이터 JPA 는 지정한 규칙에 맞게 리포지터리 인터페이스를 정의하면 리포지터리를 구현한 객체를 알아서 만들어서 스프링 빈으로 등록해준다.

---

# 3. 매핑 구현

---

## 3.1. 엔티티와 밸류 기본 매핑

---

## 3.2. 기본 생성자

---

## 3.3. 필드 접근 방식 사용

---

## 3.4. `AttributeConverter` 를 이용한 밸류 매핑 처리

---

## 3.5. 밸류 컬렉션: 별도 테이블 매핑

---

## 3.6. 밸류 컬렉션: 한 개 컬럼 매핑

---

## 3.7. 밸류를 이용한 ID 매핑

---

## 3.8. 별도 테이블에 저장하는 밸류 매핑

---

## 3.9. 밸류 컬렉션을 `@Entity` 로 매핑

---

## 3.10. ID 참조와 조인 테이블을 이용한 단방향 M-N 매핑

- 애그리거트 로딩 전략
- 애그리거트의 영속성 전파
- 식별자 생성 기능
- 도메인 구현과 DIP


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [책 예제 git](https://github.com/madvirus/ddd-start2)