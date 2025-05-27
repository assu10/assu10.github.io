---
layout: post
title:  "DDD - 표현/응용/도메인/인프라스트럭처 영역, DIP, 도메인 영역의 주요 구성 요소, 애그리거트, 모듈 구성"
date: 2024-04-01
categories: dev
tags: ddd dip entity value rootEntity
---

- 표현/응용/도메인/인프라스트럭처 영역
- DIP
- 도메인 영역의 주요 구성 요소
- 인프라스트럭처
- 모듈 구성

---

**목차**

<!-- TOC -->
* [1. 4개의 영역](#1-4개의-영역)
  * [1.1. 표현 영역 (Presentation)](#11-표현-영역-presentation)
  * [1.2. 응용 영역 (Application)](#12-응용-영역-application)
  * [1.3. 도메인 영역 (Domain)](#13-도메인-영역-domain)
  * [1.4. 인프라스트럭처 영역 (Infrastructure)](#14-인프라스트럭처-영역-infrastructure)
* [2. 계층 구조 아키텍처](#2-계층-구조-아키텍처)
* [3. DIP (Dependency Inversion Principle, 의존관계 역전 원칙)](#3-dip-dependency-inversion-principle-의존관계-역전-원칙)
  * [3.1. DIP 를 적용하여 해결한 기능 확장의 어려움 문제](#31-dip-를-적용하여-해결한-기능-확장의-어려움-문제)
  * [3.2. DIP 를 적용하여 해결한 테스트의 어려움 문제](#32-dip-를-적용하여-해결한-테스트의-어려움-문제)
  * [3.3. DIP 주의사항](#33-dip-주의사항)
  * [3.4. DIP 와 아키텍처](#34-dip-와-아키텍처)
* [4. 도메인 영역의 주요 구성 요소](#4-도메인-영역의-주요-구성-요소)
  * [4.1. 엔티티와 밸류](#41-엔티티와-밸류)
    * [4.1.1 DB 관계형 모델의 엔티티와 도메인 모델의 엔티티의 차이점](#411-db-관계형-모델의-엔티티와-도메인-모델의-엔티티의-차이점)
      * [4.1.1.1. 도메인 모델의 엔티티는 데이터와 함께 도메인 기능을 함께 제공](#4111-도메인-모델의-엔티티는-데이터와-함께-도메인-기능을-함께-제공)
      * [4.1.1.2. 도메인 모델의 엔티티는 2개 이상의 데이터가 개념적으로 하나인 경우 밸류 타입을 이용해서 표현 가능](#4112-도메인-모델의-엔티티는-2개-이상의-데이터가-개념적으로-하나인-경우-밸류-타입을-이용해서-표현-가능)
    * [4.1.2. 밸류 타입](#412-밸류-타입)
  * [4.2. 애그리거트 (Aggregate)](#42-애그리거트-aggregate)
    * [4.2.1. 루트 엔티티](#421-루트-엔티티)
  * [4.3. 리포지터리](#43-리포지터리)
  * [4.4. 애그리거트, 엔티티, 밸류 타입 차이](#44-애그리거트-엔티티-밸류-타입-차이)
* [5. 요청 처리 흐름](#5-요청-처리-흐름)
* [6. 인프라스트럭처 개요](#6-인프라스트럭처-개요)
* [7. 모듈 구성](#7-모듈-구성)
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

# 1. 4개의 영역

[2. 도메인 모델 패턴](https://assu10.github.io/dev/2024/03/31/ddd-basic/#2-%EB%8F%84%EB%A9%94%EC%9D%B8-%EB%AA%A8%EB%8D%B8-%ED%8C%A8%ED%84%B4) 에 나왔던 일반적인 
애플리케이션의 아키텍처는 아래와 같다.

표현, 응용, 도메인, 인프라스트럭처는 아키텍처를 설계하는 전형적인 4가지 영역이다.

![아키텍처 구성](/assets/img/dev/2024/0331/architecture.png)

- Presentation
  - 사용자의 요청 처리하고, 정보를 보여줌
- Application
  - 사용자가 요청한 기능 실행
  - 업무 로직을 직접 구현하지 않으며 도메인 계층을 조합하여 기능 실행
- Domain
  - 시스템이 제공할 도메인 규칙 구현
- Infrastructure
  - DB, Messaging 시스템과 같은 외부 시스템과의 연동 처리

---

## 1.1. 표현 영역 (Presentation)

표현 영역은 사용자의 요청을 받아 응용 영역에 전달 후 응용 영역의 처리 결과를 다시 사용자에게 보여준다.

![표현 영역](/assets/img/dev/2024/0401/presentation.png)

표현 영역은 HTTP 요청을 응용 영역이 필요로 하는 형식으로 변환하여 응용 영역에 전달 후, 응용 영역의 응답을 HTTP 응답으로 변환하여 전송한다.

---

## 1.2. 응용 영역 (Application)

**응용 영역은 시스템이 사용자에게 제공해야 할 기능을 구현**한다.  
예를 들면 '주문 취소', '상세 조회' 등의 기능 구현이 있다.

이런 **기능을 구현하기 위해 도메인 영역의 도메인 모델을 사용**한다. (= **실제 도메인 로직 구현은 도메인 모델에 위임함**)

![응용 영역](/assets/img/dev/2024/0401/application.png)

예를 들어 주문 취소 기능을 제공하는 응용 서비스는 아래와 같이 주문 도메인 모델을 사용하여 기능을 구현한다.

```java
public class CancelOrderService {
  @Transactional
  public void cancelOrder(String orderId) {
      Order order = findOrderById(orderId);
      if (order == null) {
          throw new OrderNotFoundException(orderId);
      }
      order.cancel();   // 주문 도메인 모델을 이용하여 주문 취소 (= Order 객체에 취소 처리를 위임함)
    }
}
```

위처럼 응용 서비스는 로직을 직접 수행하기 보다 도메인 모델에 로직 수행을 위임한다.

---

## 1.3. 도메인 영역 (Domain)

**도메인 영역은 도메인 모델을 구현**한다.

**도메인 모델은 도메인의 핵심 로직을 구현**한다.  
예) 주문 도메인은 '배송지 변경', '결제 완료' 등과 같은 핵심 로직을 도메인 모델에서 구현함

---

## 1.4. 인프라스트럭처 영역 (Infrastructure)

인프라스트럭처 영역은 구현 기술에 대한 것을 다룬다.  
예를 들면 RDBMS 연동을 처리하거나, 메시징 큐에 메시지를 전송/수신하는 기능을 구현한다.

![인프라스트럭처 영역](/assets/img/dev/2024/0401/infrastructrue.png)

---

# 2. 계층 구조 아키텍처

도메인의 복잡도에 따라 응용과 도메인을 분리하기도 하고, 한 계층으로 합치기도 하지만 전체적인 아키텍처는 아래의 계층 구조를 따른다.

![아키텍처 구성](/assets/img/dev/2024/0331/architecture.png)

**계층 구조는 상위 계층에서 하위 계층으로의 의존만 존재하고, 하위 계층은 상위 계층에 의존하지 않는다.**  
예) 표현 계층은 응용 계층에 의존하지만, 응용 계층이 표현 계층에 의존하지는 않음

계층 구조를 엄격하게 적용하면 상위 계층은 바로 아래의 계층에만 의존해야 하지만 구현의 편리함을 위해 계층 구조를 유연하게 적용하기도 한다.  
예) 응용 계층이 바로 아래 계층인 도메인 계층에 의존하기도 하지만, 외부 시스템과의 연동을 위해 인프라스트럭처 계층에 의존하기도 함

예를 들어 도메인의 가격 계산 규칙에서 할인 금액을 계산하기 위해 _Drools_ 이라는 룰 엔진을 사용하여 계산 로직을 수행하는 인프라스트럭처의 영역의 코드가 있다고 하자.  
그리고 응용 영역은 가격 계산을 위해 인프라스트럭처 영역의 _DroolsRuleEngine_ 을 사용한다고 하자.

인프라스프럭처 영역의 코드
```java
public class DroolsRuleEngine {
    private aContainer aContainer;
    
    public DroolsRuleEngine() {
        aService as = AServices.Factory.get();
        aContainer = as.getAClasspathContainer();
    }
    
    public void evaluate(String sessionName, List<?> facts) {
        ASession aSession = aContainer.newASession(sessionName);
        try {
            facts.forEach(x -> aSession.insert(x));
            aSession.fireAllRules();
        } finally {
            aSession.dispose();
        }
    }
}
```

응용 영역에서 인프라스트럭처 영역에 의존하는 코드
```java
public class CalculateDiscountService {
    private DroolsRuleEngine droolsRuleEngine;
    
    public CalculateDiscountService() {
        droolsRuleEngine = new DroolsRuleEngine();
    }
    
    public Money calculateDiscount(Orderline orderLines, String customerId) {
        Customer customer = findCustomer(customerId);
        
        // Engine 에 특화된 코드임, 연산 결과를 받기 위해 추가한 타입
        MutableMoney money = new MutableMoney(0);
        
        // Engine 에 특화된 코드임, rule 에 필요한 데이터
        List<?> facts = Arrays.asList(customer, money);
        facts.addAll(orderLines);
        
        // Engine 에 특화된 코드임, Engine 의 세션 이름이 들어감
        droolsRuleEngine.evaluate("discountCalculation", facts);
        return money.toImmutableMoney();
    }
}
```

**이렇게 응용 영역이 인프라스트럭처 영역에 바로 의존하게 되었을 경우 동작은 하겠지만 2가지 문제점**이 있다.

- **테스트가 어려움**
  - 응용 영역의 기능을 테스트하기 위해선 인프라스트럭처 영역의 _DroolsRuleEngine_ 이 완벽하게 동작해야 함
  - _DroolsRuleEngine_ 과 관련된 설정 파일을 모두 만든 이후에 비로소 응용 영역의 기능이 정상 동작하는지 확인 가능
- **기능 확장의 어려움**
  - _DroolsRuleEngine_ 의 기능을 변경하면 이를 이용하고 있는 응용 영역의 기능도 함께 변경해야 함
    - 예를 들어 'discountCalculation' 문자열은 _DroolsRuleEngine_ 의 세션이름인데, 만일 _DroolsRuleEngine_ 의 세션 이름을 변경하면 이를 호출하는 응용 영역의 코드도 함께 변경해야 함 
  - 만일 _DroolsRuleEngine_ 이 아닌 다른 구현 기술을 이용하려면 코드의 많은 부분을 수정해야 함

이러한 문제점을 해소해주는 것이 바로 DIP 이다.

---

# 3. DIP (Dependency Inversion Principle, 의존관계 역전 원칙)

[2. 계층 구조 아키텍처](#2-계층-구조-아키텍처) 에서 나온 가격 할인 계산을 위해선 아래와 같이 고수준 모듈과 저수준 모듈를 이용해야 한다.

![고수준 모듈과 저수준 모듈](/assets/img/dev/2024/0401/dip.png)

고수준 모듈이 정상 동작하려면 저수준 모듈을 이용해야 하는데, 고수준 모듈이 저수준 모듈을 사용하면 [2. 계층 구조 아키텍처](#2-계층-구조-아키텍처) 에 언급된 것처럼 테스트의 어려움과 
구현의 어려움 문제가 발생한다.

**DIP 는 이 문제를 해결하기 위해 추상화한 인터페이스를 통해 저수준 모듈이 고수준 모듈에 의존**하도록 한다.

고수준 모듈인 _CalculateDiscountService_ 입장에서는 룰 적용을 _Drools_ 으로 구현했는지 다른 것으로 구현했는지는 중요하지 않고, 고객 정보와 구매 정보에 rule 을 적용해서 
할인 금액을 구하기만 하면 된다.

이를 추상화한 인터페이스는 아래와 같다.

```java
public interface RuleDiscounter {
    Money applyRules(Customer customer, List<OrderLine> orderLines);
}
```

이제 고수준 모듈인 _CalculateDiscountService_ 가 추상화된 인터페이스인 _RuleDiscounter_ 를 이용하도록 해보자.

응용 영역이 인프라스트럭처 영역에 의존하지 않고, 추상화된 인터페이스에 의존하는 코드
```java
public class CalculateDiscountService {
  private RuleDiscounter ruleDiscounter;

  public CalculateDiscountService(RuleDiscounter ruleDiscounter) {
    this.ruleDiscounter = ruleDiscounter;
  }

  public Money calculateDiscount(Orderline orderLines, String customerId) {
    Customer customer = findCustomer(customerId);
    return ruleDiscounter.applyRules(customer, orderLines); 
  }
}
```

위 코드를 보면 응용 영역에서 인프라스트럭처 영역인 _Drools_ 에 의존하는 코드없이 단지 _RuleDiscounter_ 가 룰을 적용받는 다는 사실만 안다.  
그리고 **추상화된 인터페이스인 _RuleDiscounter_ 의 구현 객체는 생성자를 통해 전달**받는다.

룰 적용을 구현한 클래스는 추상화된 인터페이스인 _RuleDiscounter_ 를 구현한다.

추상화된 인터페이스를 구현하는 코드
```java
public class DroolsRuleDiscounter implements RuleDiscounter {
    private aContainer aContainer;
    
    public DroolsRuleDiscounter() {
        aService as = AService.Factory.get();
        aContainer = as.getAClasspathContainer();
    }
    
    @Override
    public Money applyRules(Customer customer, List<OrderLine> orderLines) {
        ASession aSession = aContainer.newASession("discountSession");
        try {
          facts.forEach(x -> aSession.insert(x));
          aSession.fireAllRules();
        } finally {
          aSession.dispose();
        }
        return money.toImmutableMoney();
    }
}
```

**고수준 모듈인 _CalculateDiscountService_ 가 저수준 모듈인 _Drools_ 에 의존하지 않고 추상화된 인터페이스에 의존**함으로써 아래와 같은 구조로 변경되었다.

![DIP 를 적용한 구조](/assets/img/dev/2024/0401/dip_2.png)

고수준 모듈인 _CalculateDiscountService_ 가 저수준 모듈인 _Drools_ 에 의존하지 않고 '룰을 이용한 할인 금액 계산' 을 추상화한 _RuleDiscounter_ 인터페이스에 의존한다.  
**'룰을 이용한 할인 금액 계산' 은 고수준 모듈의 개념이므로 _RuleDiscounter_ 인터페이스는 고수준 모듈**이다.  
**인터페이스를 구현한 _DroolsRuleDiscounter_ 는 고수준의 하위 기능인 _RuleDiscounter_ 를 구현한 것이므로 저수준 모듈**에 속한다.

**DIP 를 적용하면 위 그림처럼 저수준 모듈이 고수준 모듈의 의존**하게 된다.  

**고수준 모듈이 저수준 모듈을 이용하려면 고수준 모듈 → 저수준 모듈로 의존해야 하는데 이 방향을 뒤집기 때문에 이러한 것을 DIP (Dependency Inversion Principle, 의존관계 역전 원칙)** 이라고 한다.

이렇게 **DIP 를 적용하면 다른 영역이 인프라스트럭처 영역에 의존할 때 발생하는 구현 교체와 테스트 어려움의 문제를 해소**할 수 있다.

---

## 3.1. DIP 를 적용하여 해결한 기능 확장의 어려움 문제

고수준 모듈은 더 이상 저수준 모듈에 의존하지 않고 구현을 추상화한 인터페이스에 의존하며, 실제 사용할 저수준 구현 객체는 아래 코드처럼 의존 주입을 통해 전달받는다.

```java
// 사용할 저수준 객체 생성
RuleDiscounter ruleDiscounter = new DroolsRuleDiscounter();

// 생성자 방식으로 주입받음
CalculateDiscountService disService = new CalculateDiscountService(ruleDiscounter);
```

따라서 **만일 구현 기술을 변경하더라도 응용 영역인 _CalculateDiscountService_ 는 변경할 필요없이, 저수준 구현 객체를 생성하는 코드만 변경**하면 된다.

```java
// 사용할 저수준 구현 객체 변경
RuleDiscounter ruleDiscounter = new OtherRuleDiscounter();

// 사용한 저수준 모듈이 변경되어도 고수준 모듈을 수정할 필요없음
CalculateDiscountService disService = new CalculateDiscountService(ruleDiscounter);
```

---

## 3.2. DIP 를 적용하여 해결한 테스트의 어려움 문제

테스트에 대해 알아보기 전에 DIP 가 적용된 _CalculateDiscountService_ 코드를 다시 보자.  

응용 영역이 인프라스트럭처 영역에 의존하지 않고, 추상화된 인터페이스에 의존하는 코드
```java
public class CalculateDiscountService {
  private RuleDiscounter ruleDiscounter;

  public CalculateDiscountService(RuleDiscounter ruleDiscounter) {
    this.ruleDiscounter = ruleDiscounter;
  }

  public Money calculateDiscount(Orderline orderLines, String customerId) {
    Customer customer = findCustomer(customerId);
    return ruleDiscounter.applyRules(customer, orderLines); 
  }
}
```

_CalculateDiscountService_ 가 정상 동작하려면 _Customer_ 를 찾는 기능이 구현되어야 한다.  
이 기능은 **고수준 인터페이스인 _CustomerRepository_ 를 이용**한다.

따라서 _CalculateDiscountService_ 는 아래 2개의 고수준 인터페이스를 사용하게 된다.
- _RuleDiscounter_ : '룰을 이용한 할인 금액 계산' 을 추상화한 고수준 인터페이스
- _CustomerRepository_ : 고객 정보를 찾는 고수준 인터페이스

응용 영역이 인프라스트럭처 영역에 의존하지 않고, 추상화된 인터페이스에 의존하는 코드 (CustomerRepository 추가)
```java
public class CalculateDiscountService {
  private RuleDiscounter ruleDiscounter;
  private CustomerRepository customerRepository;    // 추가

  public CalculateDiscountService(RuleDiscounter ruleDiscounter, CustomerRepository customerRepository) {
    this.ruleDiscounter = ruleDiscounter;
    this.customerRepository = customerRepository;   // 추가
  }

  public Money calculateDiscount(Orderline orderLines, String customerId) {
    Customer customer = findCustomer(customerId);
    return ruleDiscounter.applyRules(customer, orderLines); 
  }
  
  // 추가
  public Customer findCustomer(String customerId) {
      Customer customer = customerRepository.findById(customerId);
      if (customer == null) {
          throw new NoCustomerException();
      }
      return customer;
  }
}
```

_CalculateDiscountService_ 의 동작 확인을 위해서는 _RuleDiscounter_ 와 _CustomerRepository_ 의 구현 객체가 필요하다.  
만일 **_CalculateDiscountService_ 가 저수준 모듈에 직접 의존했다면 저수준 모듈이 만들어지기 전까지 테스트를 할 수 없겠지만,**
**_RuleDiscounter_ 와 _CustomerRepository_ 는 인터페이스이므로 대역 객체를 사용하여 테스트를 진행**할 수 있다.

대역 객체를 사용하여 _Customer_ 가 존재하지 않는 경우 예외가 발생하는지 검증하는 테스트 코드
```java
public class CalculateDiscountServiceTest { 
  @Test
  public void noCustomer_thenExceptionShouldBeThrown() {
        // 테스트 목적의 대역 객체 (테스트를 수행하는데 필요한 기능만 수행)
       CustomerRepository stubRepo = mock(CustomerRepository.class);
       when(stubRepo.findById("noCustId")).thenReturn(null);
       
       RuleDiscounter stubRule = (cust, lines) -> null;
       
       // 대역 객체를 주입받아 테스트 진행
       CalculateDiscountService calDisSvc = new CalculateDiscountService(stubRepo, stubRule);
      
       assertThrows(NoCustomerException.class,
              () -> calDisSvc.calculateDiscount(someLines, "noCustId"));
    }
}
```

**위의 코드는 _RuleDiscounter_ 와 _CustomerRepository_ 의 실제 구현 클래스가 없어도 _CalculateDiscountService_ 를 테스트**할 수 있음을 보여준다.

이렇게 **실제 구현없이 테스트를 할 수 있는 이유는 DIP 를 적용해서 고수준 모듈이 저수준 모듈에 의존하지 않도록 했기 때문**이다.

---

## 3.3. DIP 주의사항

**DIP 를 잘못 생각하면 단순히 인터페이스와 구현 클래스를 분리하는 정도로 이해할 수 있는데, DIP 의 핵심은 고수준 모듈이 저수준 모듈에 의존하지 않도록 하는 것**이다.

아래는 DIP 를 정상 적용한 예시와 잘못 적용한 예시이다.

![DIP 를 잘 적용한 구조](/assets/img/dev/2024/0401/dip_2.png)

![DIP 를 잘못 적용한 구조](/assets/img/dev/2024/0401/dip_3.png)

DIP 를 잘못 적용한 구조를 보면 여전히 고수준 모듈이 저수준 모듈에 의존하고 있다.  
_RuleEngine_ 인터페이스를 고수준 모듈인 도메인 관점이 아니라 룰 엔진이라는 저수준 모듈 관점에서 도출했기 때문이다.

**DIP 를 적용할 때 하위 기능을 추상화한 인터페이스는 고수준 모듈 관점에서 도출**해야 한다.

**_CalculateDiscountService_ 입장에서 할인 금액을 구하기 위해 룰 엔진을 사용하던 다른 엔진을 사용하던지는 중요하지 않고, 오직 규칙에 따라 
할인 금액을 계산한다는 것이 중요**하다.  
즉, '할인 금액 계산' 을 추상화한 인터페이스를 도출해야 저수준 모듈이 아닌 고수준 모듈에 위치할 수 있다.

---

## 3.4. DIP 와 아키텍처

**인프라스트럭처 영역은 구현 기술을 다루는 저수준 모듈**이고, **응용 영역과 도메인 영역은 고수준 모듈**이다.

![아키텍처 구성](/assets/img/dev/2024/0331/architecture.png)

DIP 를 적용하면 인프라스트럭처 영역이 응용 혹은 도메인 영역에 의존하게 되고, 응용 영역은 도메인 영역에 의존하게 된다.

![DIP 를 적용한 아키텍처 구성](/assets/img/dev/2024/0401/dip_architecture.png)

이처럼 **인프라스트럭처에 위치한 클래스가 도메인이나 응용 영역에 정의한 인터페이스를 상속받아 구현하는 구조**가 되기 때문에 
**도메인과 응용 영역에 대한 영향을 주지 않거나, 최소화하면서 구현 기술을 변경하는 것이 가능**하다.

![DIP 를 적용한 구조](/assets/img/dev/2024/0401/dip_4.png)

![DIP 를 적용하여 응용,도메인 영역에 영향을 최소화하면서 구현체 변경](/assets/img/dev/2024/0401/dip_5.png)

---

# 4. 도메인 영역의 주요 구성 요소

도메인 영역은 도메인의 핵심 모델을 구현하며 [엔티티와 밸류 타입](https://assu10.github.io/dev/2024/03/31/ddd-basic/#4-%EC%97%94%ED%8B%B0%ED%8B%B0%EC%99%80-%EB%B0%B8%EB%A5%98)은 도메인 영역의 주요 구성 요소 중 하나이다.

<**도메인 영역의 주요 구성 요소**>  

|              요소              | 설명                                                                                                                                   |
|:----------------------------:|:-------------------------------------------------------------------------------------------------------------------------------------|
|       엔티티<br >(Entity)       | - 고유의 식별자를 갖는 객체로 자신의 라이프 사이클을 가짐<br >- Order, Member 와 같이 도메인의 고유한 개념을 포함함<br >- 도메인 모델의 데이터를 포함하며, 해당 데이터와 관련된 기능을 함께 제공함          |
|        밸류<br >(Value)        | - 고유의 식별자를 갖지 않는 객체<br >- 개념적으로 하나인 값을 표현할 때 사용<br >- Address, Money 등과 같은 타입이 밸류 타입임<br >- 엔티티의 속성으로 사용할 뿐만 아니라 다른 밸류 타입의 속성으로도 사용함 |
|    애그리거트<br >(Aggregate)     | - 연관된 엔티티와 밸류 객체를 개념적으로 하나로 묶은 것<br >- 주문과 관련된 Order 엔티티, OrderLine 밸류, Orderer 밸류 객체를 '주문' 애그리거트로 묶을 수 있음                           |
|    리포지터리<br >(Repository)    | - 도메인 모델의 영속성 처리                                                                                                                     |
| 도메인 서비스<br >(Domain Service) | - 특정 엔티티에 속하지 않은 도메인 로직 제공<br >- '할인 금액 계산' 은 상품, 쿠폰 등 다양한 조건을 이용해서 구현하게 되는데 이렇게 **도메인 로직이 여러 엔티티와 밸류를 필요로 하면 도메인 서비스에서 로직을 구현**함        |

---

## 4.1. 엔티티와 밸류

**DB 관계형 모델의 엔티티와 도메인 모델의 엔티티는 동일한 것이 아니다.**

---

### 4.1.1 DB 관계형 모델의 엔티티와 도메인 모델의 엔티티의 차이점

DB 관계형 모델의 엔티티와 도메인 모델의 엔티티의 차이점은 크게 2가지가 있다.
- 도메인 모델의 엔티티는 데이터와 함께 도메인 기능을 함께 제공
- 도메인 모델의 엔티티는 2개 이상의 데이터가 개념적으로 하나인 경우 밸류 타입을 이용해서 표현 가능

---

#### 4.1.1.1. 도메인 모델의 엔티티는 데이터와 함께 도메인 기능을 함께 제공

이 둘의 가장 큰 차이점은 **도메인 모델의 엔티티는 데이터와 함께 도메인 기능을 함께 제공**한다는 점이다.  
예) 주문을 표현하는 엔티티는 주문과 관련된 데이터 뿐 아니라 배송지 주소 변경을 위한 기능을 함께 제공

주문 엔티티
```java
// 주문
public class Order {
    // 주문 도메인 모델의 데이터
    private OrderNo id;
    private Orderer orderer;
    
    // ...
  
    // 도메인 모델의 엔티티는 도메인 기능도 함께 제공 
    // 배송지 변경
    public void changeShippingInfo(ShippingInfo newShipping) {
      // ...
    }
}
```

---

#### 4.1.1.2. 도메인 모델의 엔티티는 2개 이상의 데이터가 개념적으로 하나인 경우 밸류 타입을 이용해서 표현 가능

[4.1.1.1. 도메인 모델의 엔티티는 데이터와 함께 도메인 기능을 함께 제공](#4111-도메인-모델의-엔티티는-데이터와-함께-도메인-기능을-함께-제공) 의 코드 중 주문자를 표현하는 
_Orderer_ 는 밸류 타입으로 주문자 이름과 이메일 데이터를 포함할 수 있다.

주문자 밸류 타입
```java
@RequiredArgsConstructor
@Getter
@EqualsAndHashCode  // 밸류 타입
public class Orderer {
    private final String name;
    private final String email;
}
```

---

### 4.1.2. 밸류 타입

**밸류는 불변으로 구현**할 것을 권장하며, 이는 **엔티티의 밸류 타입 데이터를 변경할 때는 객체 자체를 완전히 교체한다는 것을 의미**한다.

아래는 배송지 정보를 변경할 때 기존 객체의 값을 변경하지 않고 새로운 객체를 필드에 할당하는 예시이다.
```java
// 주문
public class Order {
    private ShippingInfo shippingInfo;

    // ...
  
    // 배송지 정보 검사 후 배송지 값 설정
    private void setShippingInfo(ShippingInfo newShippingInfo) {
        // 배송지 정보는 필수임
        if (newShippingInfo == null) {
            throw new IllegalArgumentException("no shippingInfo");
        }
        // 밸류 타입의 데이터를 변경할 때는 새로운 객체로 교체함
        this.shippingInfo = newShippingInfo;
    }

    // 도메인 모델의 엔티티는 도메인 기능도 함께 제공
    // 배송지 변경
    public void changeShippingInfo(ShippingInfo newShipping) {
        verifyNotYetShipped();
        setShippingInfo(newShipping);
    }
    
    // ...
}
```

> 밸류 타입에 대한 좀 더 상세한 내용은 [4.3. 밸류 타입](https://assu10.github.io/dev/2024/03/31/ddd-basic/#43-%EB%B0%B8%EB%A5%98-%ED%83%80%EC%9E%85) 을 참고하세요.

---

## 4.2. 애그리거트 (Aggregate)

도메인이 커질수록 모델은 복잡해지고, 엔티티와 밸류 타입의 수는 점점 많아진다.  
이 때 **하나하나의 객체만 보는 것이 아니라, 상위 수준에서 모델을 이해하고 관리할 수 있는 단위**가 필요한데 바로 그 역할을 하는 것이 애그리거트이다.  
애그리거트는 하나의 비즈니스 개념 단위로 **트랜잭션, 일관성, 동시성 이슈를 해결**하는데 중심 역할을 한다.  
올바르게 설계된 애그리거트는 **전체 모델의 이해도와 유지보수성**을 높여준다.

<**애그리거트**>
- 비즈니스 규칙에 따라 **일관성을 유지**해야 하는 객체들의 집합
- 하나의 애그리거트는 루트 엔티티를 중심으로, 여러 개의 엔티티와 값 객체들로 구성됨
- 이들은 **항상 함께 변경되고, 함께 저장**되며, 하나의 트랜잭션 안에서 일관성을 유지해야 함
- 즉, 애그리거트는 복잡한 도메인 모델을 상위 수준에서 이해하고 관리하기 위한 구조적 단위이자 트랜잭션 경계임

<br />
<**애그리거트가 필요한 이유**>
- 모델이 커질수록 각 객체의 관계와 경계가 모호해지기 쉬움
- 개별 객체만 바라보면 전체 비즈니스 흐름을 파악하기 어려움
- **애그리거트는 도메인 객체들을 그루핑하여 의미있는 단위로 추상화**해줌
- 즉, **"도메인 모델의 큰 그림을 잡아주는 설계 도구"**임

<br />
<**애그리거트 구성요소**>
- 루트 엔티티
  - 외부에서 접근 가능한 유일한 진입점
  - 전역적으로 고유한 ID 를 가짐
- 내부 구성
  - 관련된 엔티티, 값 객체 등
- 예) Order(주문)는 하나의 애그리거트이며, 그 안에는 OrderItem, ShippingInfo 등이 포함될 수 있다.

<br />
외부에서는 **항상 루트를 통해서만 내부 객체에 접근**해야 한다. 이는 설계를 단순화하고, **불필요한 데이터 변경을 방지**하기 위함이다.

<**트랜잭션 경계와 원자성**>
- 애그리거트는 단일 트랜잭션으로 처리되도록 설계된다.
- 즉, **하나의 애그리거트는 하나의 원자적 비즈니스 작업 단위**이다.
- 이 원자성은 DB 관점에서도 중요하며, **내부 데이터가 외부 간섭없이 일관성 있게 저장**되도록 보장한다.
- 즉, **"비즈니스 작업은 애그리거트 루트를 중심으로 설계해야 한다"**

<br />

<**설계 기준**>
- **애그리거트는 최소 하나의 엔티티로 구성**되어야 하며, 보통 하나 이상의 값 객체를 포함한다.
- 내부 구성요소는 도메인의 비즈니스 로직 경계 안에 있을때만 포함되어야 한다.
- **하나의 트랜잭션 범위 내에서 함께 관리되는 모든 객체는 하나의 애그리거트에 포함**된다.

일반적으로 어떤 비즈니스 규칙은 단일 부모 객체 안의 특정 데이터가 부모 객체의 수명 동안 일관서을 유지하도록 요구하는데,
이것은 부모 객체 A 가 있을 때 같은 일관성 경계 안에서 관리되는 데이터 항목을 동시에 변경하는 동작을 A 에 위치시켜서 달성할 수 있다.
이런 종류의 동작 연산을 원자성이라고 한다.

원자적 데이터베이스 변환은 A 의 원자적 행동 연산과 유사하게 저장되어야 하는 데이터 주위에 격리 영역을 생성해서 데이터가 격리 영역 외부의 어떤 방해나 변경 없이
데이터가 항상 디스크에 기록되게 하기 위한 것이다.

애그리거트는 부모 객체의 데이터 주위로 트랜잭션 경계를 유지하고자 사용된다.
애그리거트는 최소 하나의 엔티티 모델로 모델링되고, 그 엔티티는 0개 이상의 다른 엔티티와 최소 하나의 값 객체를 가진다.
애그리거트는 전체 도메인 개념을 구성한다.
루트라고 불리는 외부 엔티티는 전역적으로 고유한 ID를 가져야 한다. 그것이 애그리거트는 최소 하나의 값 객체를 가져야하는 이유이다.
엔티티의 모든 규칙은 애그리거트에도 적용된다.

---

애그리거트의 대표적인 예시가 주문(_Order_)이다.

주문이라는 도메인 개념은 '주문', '배송지 정보', '주문자', '주문 목록', '총 결제금액' 의 하위 모델로 구성되며, 이 하위 개념을 표현한 모델을 하나로 묶어서 
'주문' 이라는 상위 개념으로 표현하였다.

```java
import java.util.List;

// 주문
public class Order {
    // OrderNo 타입 자체로 id 가 주문 번호임을 알 수 있음
    private OrderNo id;
    private Orderer orderer;

    private OrderState state;
    private List<OrderLine> orderLines;
    private ShippingInfo shippingInfo;
    private Money totalAmounts;

    // ...
}
```

애그리거트를 사용하면 개별 객체가 아닌 관련 객체를 묶어서 객체 군집 단위로 모델을 바라볼 수 있으며, 개별 객체 간의 관계가 아닌 애그리거트 간의 관계로 도메인 모델을 
이해하고 구현하게 된다.

---

### 4.2.1. 루트 엔티티

애그리거트는 군집에 속한 객체를 관리하는 루트 엔티티를 갖는다.

**루트 엔티티는 애그리거트에 속해 있는 엔티티와 밸류 객체를 이용해서 애그리거트가 구현해야 할 기능을 제공**한다.

**애그리거트를 사용하는 코드는 애그리거트 루트가 제공하는 기능을 실행**하고, **애그리거트 루트를 통해서 간접적으로 애그리거트 내부의 다른 엔티티나 밸류 객체에 접근**한다.  
이를 통해 애그리거트의 내부 구현을 숨겨서 애그리거트 단위로 구현을 캡슐화할 수 있다.

![애그리거트 루트인 Order 가 애그리거트에 속한 객체를 관리함](/assets/img/dev/2024/0401/aggregate.png)

**애그리거트 루트인 Order 는 주문 도메인 로직에 맞게 애그리거트의 상태를 관리**한다.  
예) Order 의 배송지 정보 변경 기능은 배송지를 변경할 수 있는지 확인한 후 배송지 정보를 변경함

애그리거트 루트가 도메인 로직에 맞게 애그리거트 상태를 관리하는 코드
```java
// 주문
public class Order {
    // ...

    // 배송지 변경
    public void changeShippingInfo(ShippingInfo newShipping) {
      // 배송지 변경 가능 여부 확인
      verifyNotYetShipped();
      setShippingInfo(newShipping);
    }
  
    // 출고 전 상태인지 검사
    private void verifyNotYetShipped() {
      // 결제 전 이 아니고, 상품 준비중이 아니면 이미 출고된 상태임
      if (state != OrderState.PAYMENT_WAITING && state != OrderState.PREPARING) {
        throw new IllegalArgumentException("already shipped");
      }
    }

    // 배송지 정보 검사 후 배송지 값 설정
    private void setShippingInfo(ShippingInfo newShippingInfo) {
      // 배송지 정보는 필수임
      if (newShippingInfo == null) {
        throw new IllegalArgumentException("no shippingInfo");
      }
      // 밸류 타입의 데이터를 변경할 때는 새로운 객체로 교체함
      this.shippingInfo = newShippingInfo;
    }
}
```

주문 애그리거트는 _Order_ 를 통하지 않고 _ShippingInfo_ 를 변경할 수 있는 방법을 제공하지 않으므로, 배송지를 변경하려면 루트 엔티티인 _Order_ 를 사용해야 한다. 
따라서 배송지 정보를 변경할 때엔 _Order_ 가 구현한 도메인 로직을 항상 따르게 된다.

애그리거트를 구현할 때는 고려할 점이 많다.  
애그리거트를 어떻게 구성했느냐에 따라 구현이 복잡해지기도 하고, 트랜잭션 범위가 달라지기도 하고, 선택한 구현 기술에 따라 애그리거트 구현에 제약이 생기기도 한다.

> 애그리거트 구현에 대한 좀 더 상세한 내용은 [DDD - 애그리거트, 애그리거트 루트, 애그리거트 참조, 애그리거트 간 집합 연관, 애그리거트를 팩토리로 사용](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/) 을 참고하세요.

---

## 4.3. 리포지터리

> 소스는
> [github](https://github.com/assu10/ddd/tree/feature/chap02_02),
> [변경 내역](https://github.com/assu10/ddd/commit/5fa37b7c05d23cd09e84cc20aed9e9faf13909a2) 에 있습니다.

**도메인 객체를 지속적으로 사용하려면 RDBMS, NoSQL 과 같은 물리적인 저장소에 도메인 객체를 보관**해야 하는데, **이를 위한 도메인 모델이 리포지터리**이다.

**엔티티나 밸류가 요구사항에서 도출되는 도메인 모델**이라면 **리포지터리는 구현을 위한 도메인 모델**이다.

**리포지터리는 애그리거트 단위로 도메인 객체를 저장하고 조회하는 기능을 정의**한다.

주문 애그리거트를 위한 리포지터리
```java
package com.assu.study.order.domain;

public interface OrderRepository {
    Order findByNumber(OrderNo number);
    void save(Order order);
}
```

위 코드의 메서드를 보면 대상을 찾고 저장하는 단위가 애그리거트 루트인 _Order_ 인 것을 알 수 있다.  
**_Order_ 는 애그리거트에 속한 모든 객체를 포함하고 있으므로 결과적으로 애그리거트 단위로 저장하고 조회**한다.

도메인 모델을 사용해야 하는 코드는 리포지터리를 통해서 도메인 객체를 구한 후 도메인 객체의 기능을 실행한다.

아래는 주문 취소 기능을 제공하는 응용 서비스가 리포지터리를 이용해서 _Order_ 객체를 구하고, 해당 기능을 실행하는 예시이다.
```java
package com.assu.study.order.command.application;

import com.assu.study.order.NoOrderException;
import com.assu.study.order.domain.Order;
import com.assu.study.order.domain.OrderNo;
import com.assu.study.order.domain.OrderRepository;

public class CancelOrderService {
  private OrderRepository orderRepository;

  public void cancel(OrderNo orderNo) {
    Order order = orderRepository.findByNumber(orderNo);
    if (order == null) {
      throw new NoOrderException();
    }
    order.cancel();;
  }
}
```

```java
package com.assu.study.order;

public class NoOrderException extends RuntimeException {
}
```

도메인 모델 관점에서 **_OrderRepository_ 는 도메인 객체를 영속화하는데 필요한 기능을 추상화한 것으로 고수준 모듈**에 속한다.  
그리고 **_OrderRepository_ 를 구현한 클래스는 저수준 모듈로 인프라스트럭처 영역**에 속한다.

![리포지터리 인터페이스는 도메인 모델 영역, 구현 클래스는 인프라스트럭처 영역](/assets/img/dev/2024/0401/repository.png)

> 리포지터리 구현에 대한 상세한 내용은 [DDD - 리포지터리(1): 엔티티와 JPA 매핑 구현, 엔티티와 밸류 매핑(@Embeddable, @AttributeOverrides, AttributeConverter), 기본 생성자, 필드 접근 방식(@Access), 밸류 컬렉션 매핑](https://assu10.github.io/dev/2024/04/07/ddd-repository-1/) 을 참고하세요.

---

## 4.4. 애그리거트, 엔티티, 밸류 타입 차이

| 항목    | 설명                                        |
|-------|-------------------------------------------|
| 애그리거트 | - 엔티티와 밸류 타입을 묶은 상위 개념<br />- 트랜잭션 경계를 형성 |
| 엔티티   | - 고유한 식별자를 가진 객체로, 애그리거트 내부 구성 요소         |
| 밸류 타입 | - 불변 객체로, 엔티티 또는 애그리거트 내부에서 의미있는 값을 구성    |


---

# 5. 요청 처리 흐름

응용 서비스는 도메인 모델을 이용해서 기능을 구현한다.  
이 때 기능 구현에 필요한 도메인 객체는 응용 서비스가 직접 리포지터리에서 가져와서 실행하거나, 신규 도메인 객체를 생성해서 리포지터리에 저장한다.

예매 취소와 같은 기능을 제공하는 응용 서비스는 도메인의 상태를 변경하므로 변경 상태가 물리 저장소에 올바르게 반영되도록 트랜잭션을 관리한다.

즉, **응용 서비스는 트랜잭션을 관리**한다.

> 응용 서비스 구현에 대한 좀 더 상세한 설명은 [3. 응용 서비스 구현](https://assu10.github.io/dev/2024/04/14/ddd-application-presentation-layer/#3-%EC%9D%91%EC%9A%A9-%EC%84%9C%EB%B9%84%EC%8A%A4-%EA%B5%AC%ED%98%84) 을 참고하세요.

---

# 6. 인프라스트럭처 개요

인프라스트럭처는 표현 영역, 응용 영역, 도메인 영역을 지원한다.

DIP 에서 언급한 것처럼 **도메인 영역과 응용 영역에서 인프라스트럭처의 기능을 직접 사용하는 것보다 이 두 영역에 정의한 인터페이스를 인프라스트럭처 영역에서 구현하는 것이 
시스템을 더 우연하고 테스트하기 쉽게** 만들어준다.

**하지만 무조건 인프라스트럭처에 대한 의존을 없앨 필요는 없다.**

예를 들어 **스프링을 사용한다면 응용 서비스는 트랜잭션 처리를 위해 스프링이 제공하는 `@Transactional` 을 사용하는 것이 편리**하다.  
**영속성 처리를 위해 JPA 를 사용한다면 `@Entity`, `@Table` 과 같은 JPA 전용 애너테이션을 도메인 모델 클래스에 사용하는 것이 XML 매핑 설정보다 편리**하다.

구현의 편리함을 위해 인프라스트럭처에 대한 의존을 일부 도메인에 넣은 코드
```java
package com.assu.study.order.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.util.List;

// 주문
@Entity
@Table(name = "TBL_ORDER")
public class Order {
    // ...
}
```

위 코드는 JPA 의 `@Table` 애너테이션을 이용하여 엔티티를 저장할 테이블 이름을 지정함으로써 XML 설정을 하는 것보다 편리하게 테이블 이름을 지정하였다.

구현의 편리함은 DIP 가 주는 변경의 우연함, 쉬운 테스트 와 같은 장점만큼 중요하므로 **DIP 의 장점을 해치지 않는 범위에서 응용 영역과 도메인 영역에서 구현 기술에 대한 
의존을 가져가는 것**도 좋다.  
응용 영역과 도메인 영역이 인프라스트럭처에 대한 의존을 완전히 갖지 않게 하는 것이 오히려 구현을 더 복잡하고 어렵게 만들 수 있다.

좋은 예가 바로 `@Transactional` 이다.  
`@Transactional` 을 이용하면 한 줄로 트랜잭션을 처리할 수 있는데 응용 영역에서 스프링에 대한 의존을 없애려면 복잡한 스프링 설정을 사용해야 한다.

---

# 7. 모듈 구성

아키텍처의 각 영역은 별도 패키지에 위치한다.

보통은 아래와 같은 형태로 모듈이 위치할 패키지를 구성할 수 있다.

![영역별로 별도 패키지로 구성한 모듈 구조](/assets/img/dev/2024/0401/module_1.png)

만일 도메인이 크면 하위 도메인 별로 모듈을 나눌 수 있다.

![도메인이 클 경우 하위 도메인 별로 모듈 분리](/assets/img/dev/2024/0401/module_2.png)

**하위 도메인별로 분리한 모듈에서 도메인 모듈은 도메인에 속한 애그리거트를 기준으로 다시 패키지를 구성**한다.

![하위 도메인을 하위 패키지로 구성한 모듈 구조](/assets/img/dev/2024/0401/module_3.png)

애그리거트, 모델, 리포지터리는 같은 패키지에 위치시킨다.  
예) 주문과 관련된 _Order_, _OrderLine_, _OrderRepository_ 는 _com.assu.study.order.domain_ 패키지에 위치

만일 도메인이 복잡하면 도메인 모델과 도메인 서비스를 아래와 같이 별도 패키지로 분리해도 좋다.
- com.assu.study.order.domain.order: 애그리거트 위치
- com.assu.study.order.domain.service: 도메인 서비스 위치

모듈 구조를 얼마나 세분화할 지 정해진 규칙은 없지만 한 패키지에 너무 많은 타입이 몰려서 코드를 찾을 때 불편하면 안된다.  
가능하면 한 패키지에 15개 미만으로 타입 개수를 유지하는 것이 좋다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기** 와 블라드 코노노프 저자의 **도메인 주도 설계 첫걸음**과 반 버논, 토마스 야스쿨라 저자의 **전략적 모놀리스와 마이크로서비스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [도메인 주도 설계 첫걸음](https://www.yes24.com/Product/Goods/109708596)
* [전략적 모놀리스와 마이크로서비스](https://www.yes24.com/product/goods/144267386)
* [책 예제 git](https://github.com/madvirus/ddd-start2)