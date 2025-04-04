---
layout: post
title:  "DDD - 도메인 서비스"
date: 2024-04-20
categories: dev
tags: ddd 
---

이 포스트에서는 도메인 영역에 위치한 도메인 서비스에 대해 알아본다. (도메인 영역의 애그리거트, 밸류가 아님)

---

**목차**

<!-- TOC -->
* [1. 여러 애그리거트가 필요한 기능](#1-여러-애그리거트가-필요한-기능)
* [2. 도메인 서비스](#2-도메인-서비스)
  * [2.1. 계산 로직과 도메인 서비스](#21-계산-로직과-도메인-서비스)
  * [2.2. 외부 시스템 연동과 도메인 서비스](#22-외부-시스템-연동과-도메인-서비스)
  * [2.3. 도메인 서비스의 패키지 위치](#23-도메인-서비스의-패키지-위치)
  * [2.4. 도메인 서비스의 인터페이스와 클래스](#24-도메인-서비스의-인터페이스와-클래스)
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

# 1. 여러 애그리거트가 필요한 기능

도메인 영역의 코드를 작성하다보면 하나의 애그리거트로 기능을 구현할 수 없을 때가 있다.

대표적인 예로 실제 결제 금액을 계산하는 경우이다.

- 상품 애그리거트
  - 상품의 가격, 배송비
- 주문 애그리거트
  - 상품별 구매 갯수
- 할인 쿠폰 애그리거트
  - 쿠폰별로 지정한 할인 금액이나 비율에 따라 주문 촘 금액 할인
  - 조건에 따라 할인 쿠폰 중복 사용 가능
  - 지정한 카테고리의 상품에만 할인 쿠폰 적용
- 회원 애그리거트
  - 회원 등급에 따라 추가 할인

이런 상황에서 실제 결제 금액을 계산해야 하는 주체를 생각해볼 때 총 주문 금액을 계산하는 것은 주문 애그리거트라 주문 애그리거트로 생각할 수도 있다.  
하지만 실제 결제 금액은 총 주문 금액에서 할인 금액을 계산해야 하는데 그러면 할인 쿠폰 애그리거트가 총 주문 금액을 계산해야 할까?  
만일 할인 쿠폰을 2개 이상 적용 가능하다면 단일 할인 쿠폰 애그리거트로는 총 결제 금액을 계산할 수 없다.

안 좋은 예시로 주문 애그리거트에 필요한 데이터를 모두 가지도록 한 뒤 할인 금액 계산 책임을 주문 애그리거트에 할당할 수도 있다.

주문 애그리거트에 할인 금액 계산 책임을 넣은 안 좋은 예시
```java
public class Order {
    private Orderer orderer;
    private List<OrderLine> orderLines;
    private List<Coupon> usedCoupons;
    
    private Money calculatePayAmounts() {
      // 쿠폰별로 할인 금액 구함
      
      // 회원에 따른 추가 할인 구함
      
      // 실제 결제 금액 계산
    }
    
    private Money calculateDiscount(Coupon coupon) {
      // orderLines 의 각 상품에 대해 쿠폰을 적용하여 할인 금액 계산
      // 쿠폰의 적용 조건 확인
    }
    
    private Money calculateDisCount(MemberGrade grade) {
      // 회원 등급에 따라 할인 금액 계산
    }
}
```

위 예시에서 결제 금액 계산 로직이 주문 애그리거트의 책임이 맞을지 한번 생각해 볼 필요가 있다.

예를 들어 특정 세일로 전 품목에 대해 특정 기간동안 추가 할인을 한다고 했을 때 이 할인 정책은 주문 애그리거트가 갖고 있는 구성 요소와는 관련이 없음에도 불구하고 
결제 금액 계산 책임이 주문 애그리거트에 있다는 이유로 주문 애그리거트의 코드를 수정해야 한다.

이렇게 **한 애그리거트에 넣기 애매한 도메인 기능을 억지로 넣으면 자신의 책임 범위를 넘어서는 기능을 구현하기 때문에 코드가 길어지고 외부에 대한 의존이 높아져서 유지 보수가 어렵게 된다.**

이러한 문제를 해소하는 가장 쉬운 방법은 바로 **도메인 기능을 별도 서비스로 구현**하는 것이다.

애그리거트나 밸류에도 속하지 않거나 복수의 애그리거트에 관련된 비즈니스 로직을 다룰 때는 도메인 서비스로 로직을 구현하면 된다.

---

# 2. 도메인 서비스

**도메인 서비스는 비즈니스 로직을 구현한 상태가 없는 객체(stateless object)로, 도메인 영역에 위치한 도메인 로직을 표현할 때 사용**한다.


주로 아래와 같은 상황에서 도메인 서비스를 사용한다.
- **계산 로직**
  - 여러 애그리거트가 필요한 계산 로직이나, 한 애그리거트에 넣기에 다소 복잡한 계산 로직
- **외부 시스템 연동이 필요한 도메인 로직**
  - 구현을 위해 타 시스템을 사용해야 하는 도메인 로직

[DDD - 도메인 모델 패턴](https://assu10.github.io/dev/2024/08/31/ddd-domain-model-pattern/)의 예시를 보자.

할당된 엔지니어는 제한된 시간 내에 고객에서 솔루션을 제시해야 한다.  
이 제한된 시간은 아래의 영향을 받는다.
- 티켓의 데이터(우선 순위와 상부 보고 상태)
- 에이전트 소속 부서의 우선 순위별 SLA 정책
- 에이전트의 스케쥴(교대 시간이거나 퇴근 시간 이후에는 에이전트가 응답할 수 없음)

이렇게 응답 시간을 계산하는 로직은 티켓, 할당된 에이전트의 부서, 업무 스케쥴 등 다양한 출처의 정보를 필요로 하는데 이런 경우 도메인 서비스로 구현되는 것이 이상적이다.

도메인 서비스는 여러 애그리거트의 작업을 쉽게 조율할 수 있지만 하나의 DB 트랜잭션에서는 하나의 애그리거트 인스턴스만 수정할 수 있는 한계가 있다.  
도메인 서비스가 이런 한계를 극복해주지는 못한다.

**한 개의 트랜잭션이 한 개의 인스턴스를 갖는 규칙은 여전히 유효하며, 도메인 서비스는 여러 애그리거트의 데이터를 <u>읽는 것</u>이 필요한 계산 로직을 구현하는 것**을 도와준다.

---

## 2.1. 계산 로직과 도메인 서비스

**한 애그리거트에 넣기 애매한 도메인 개념을 구현하기 위해 애그리거트에 억지로 기능을 넣기 보다는 도메인 서비스를 이용하여 도메인 개념을 명시적으로 드러내는 것**이 좋다.

**응용 영역의 서비스가 응용 로직을 다룬다면 도메인 서비스는 도메인 로직**을 다룬다.

도메인 영역의 애그리거트나 밸류와 같은 구성 요소와 도메인 서비스를 비교하자면 다른 점은 **도메인 서비스는 상태없이 로직만 구현**한다는 점이다.

할인 금액 계산 로직을 위한 도메인 서비스는 _DiscountCalculationService.java_, _calculateDiscountAmounts()_ 처럼 도메인의 의미가 드러나는 용어를 타입과 메서드를 같는다.

할인 금액 계산 로직을 위한 도메인 서비스 예시
```java
public class DiscountCalculationService {
    public Money calculateDiscountAmounts(
            List<OrderLine> orderLines,
            List<Coupon> coupons,
            MemberGrade grade
    ) {
      // 쿠폰별로 할인 금액 구함

      // 회원에 따른 추가 할인 구함

      // 실제 결제 금액 계산
    }
}
```

할인 금액 계산 서비스를 사용하는 주체는 애그리거트가 될 수도 있고 응용 서비스가 될 수도 있다.

위의 할인 금액 계산 로직을 위한 도메인 서비스인 _DiscountCalculationService_ 를 아래처럼 애그리거트의 결제 금액 계산 기능에 전달하면 사용 주체는 애그리거트가 된다.

도메인 서비스를 이용하는 애그리거트 예시
```java
public class Order {
    public void calculateAmounts(DiscountCalculationService discountCalculationService, MemberGrade grade) {
        Money totalAmounts = getTotalAmounts();
        
        Money discountAmounts = discountCalculationService.calculateDiscountAmounts(this.orderLines, this.coupons, grade);
        
        this.paymentAmounts = totalAmounts.minus(discountAmounts);
    }
}
```

**애그리거트 객체에 도메인 서비스를 전달하는 것은 응용 서비스의 책임**이다.

애그리거트 객체에 도메인 서비스를 전달하는 응용 서비스 예시
```java
public class OrderService {
    // 도메인 서비스
    private DiscountCalculationService discountCalculationService;
    
    @Transactional
    public OrderNo placeOrder(OrderRequest orderRequest) {
        OrderNo orderNo = orderRepository.nextId();
        Order order = createOrder(orderNo, orderRequest);
        orderRepository.save(order);
        
        // 응용 서비스 실행 후 표현 영역에서 필요한 값 리턴
        return orderNo;
    }
    
    private Order createOrder(OrderNo orderNo, OrderRequest orderRequest) {
        Member member = findMember(orderRequest.getOrdererId());
        Order order = new Order(ornerNo, orderRequest.getOrderLines(), 
                orderRequest.getCoupons(), createOrderer(member), orderRequest.getShippingInfo());
        
        // 애그리거트 객체에 도메인 서비스 전달
        order.calculateAmounts(this.discountCalculationService, member.getGrade());
        
        return order;
    }
}
```

> **도메인 서비스 객체를 애그리거트에 주입하지 않기**  
> 
> 애그리거트의 메서드를 실행할 때 도메인 서비스 객체를 애그리거트에 주입하면 안됨
> 
```java
// 애그리거트
public class Order {
  // 애그리거트에 도메인 서비스 객체를 주입함
  @Autowired
  private DiscountCalculationService discountCalculationService;
}
```
> 만일 위처럼 애그리거트 루트 엔티티에 도메인 서비스에 대한 참조를 필드로 추가하게 되면 아래와 같은 문제점들이 발생함
> - 도메인 객체는 필드(프로퍼티)로 구성된 데이터와 메서드를 이용하여 개념적으로 하나의 모델을 표현함
> - 모델의 필드는 데이터를 담는데 _discountCalculationService_ 필드는 데이터 자체와는 관련이 없음
> - _Order_ 객체를 DB 에 저장할 때 다른 필드와는 달리 저장 대상도 아님
> - _Order_ 가 제공하는 모든 기능에서 _discountCalculationService_ 를 필요로하는 것이 아니라 일부 기능한 필요로 함
> - 일부 기능을 위해 굳이 애그리거트에 도메인 서비스 객체를 의존 주입할 필요는 없음

위처럼 **애그리거트 메서드를 실행할 때 도메인 서비스를 인자로 전달할 수도 있지만 반대로 도메인 서비스의 기능을 실행할 때 애그리거트를 전달**하기도 한다.

그 예시 중 하나가 계좌 이체 기능이다.  
계좌 이체 시 2개의 계좌 애그리거트가 관여하는데 한 애그리거트는 금액을 출금하고 한 애그리거트는 금액을 입금한다.  

이를 위한 도메인 서비스는 아래와 같이 구현할 수 있다.

도메인 서비스의 기능을 실행할 때 애그리거트를 전달하는 예시
```java
// 도메인 서비스
public class TransferService {
    // 도메인 서비스로 애그리거트 전달
    public void transfer(Account fromAcc, Account toAcc, Money amounts) {
        fromAcc.withdraw(amounts);
        toAcc.crdit(amounts);
    }
}
```

위 코드에서 응용 서비스는 두 개의 Account 애그리거트를 구한 뒤 해당 도메인 영역의 _TransferService_ 를 이용하여 계좌 이체 도메인 기능을 실행하는 예시이다.

도메인 서비스는 도메인 로직만 수행하고 응용 로직을 수행하진 않으므로 **트랜잭션 처리와 같은 로직은 응용 로직에 속하기 때문에 도메인 서비스에서 처리하지 않는다.**

> **특정 기능이 응용 서비스인지 도메인 서비스인지 애매한 경우**  
> 
> 이럴 땐 해당 로직이 애그리거트의 상태를 변경하거나 애그리거트의 상태값을 계산하는지 보면 됨    
> 만일 둘 중 하나에 해당하면 도메인 서비스임  
> 예를 들어 계좌 이체 로직은 계좌 애그리거트의 상태를 변경하고, 결제 금액 로직은 주문 애그리거트의 주문 금액을 계산하므로 도메인 로직임
> 
> **도메인 로직이면서 한 애그리거트에 넣기 적합하지 않으므로 이 두 개의 로직은 도메인 서비스로 구현하는 것이 좋음**

---

## 2.2. 외부 시스템 연동과 도메인 서비스

외부 시스템이나 타도메인과의 연동 기능도 도메인 서비스가 될 수 있다.

예를 들어 *설문 시스템*과 *사용자 역할 관리 시스템*이 분리되어 있을 경우 설문 조사 시스템은 설문 조사 생성 시 사용자가 생성 권한을 가진 역할인지 확인하기 위해 역활 관리 시스템과 연동해야 한다.

시스템 간 연동은 HTTP API 호출로 이루어 질 수도 있지만 설문 조사 도메인 입장에서는 사용자가 설문 조사 생성 권한을 가졌는지 확인하는 도메인 로직으로 볼 수 있다.  
이 도메인 로직을 아래와 같은 도메인 서비스로 표현할 수 있다.

타 시스템을 연동하는 도메인 서비스 예시
```java
// 도메인 서비스
public interface SurveyPermissionChecker {
    boolean hasUserCreationPermission(String userId);
}
```

위 코드에서 중요한 점은 **역할 관리 시스템과 연동한다는 관점이 아닌 도메인 로직 관점에서 인터페이스를 작성**했다는 점이다.

응용 서비스는 이 도메인 서비스를 이용하여 생성 권한을 검사한다.

도메인 서비스를 이용하는 응용 서비스 예시
```java
// 응용 서비스
public class CreateSurveyService {
    private SurveyPermissionChecker permissionChecker;
    
    public Long createSurvey(CreateSurveyRequest req) {
      validate(req);
        
      // 도메인 서비스를 이용하여 외부 시스템 연동을 표현
      if (!permissionChecker.hasUserCreationPermission(req.getRequestorId())) {
          throw new NoPermissionException();
      }
      
      // ...
    }
}
```

타 시스템 연동을 구현한 도메인 서비스인 **_SurveyPermissionChecker_ 인터페이스를 구현한 클래스는 인프라스트럭처 영역에 위치하여 연동을 포함한 권한 검사 기능을 구현**한다.

---

## 2.3. 도메인 서비스의 패키지 위치

도메인 서비스는 도메인 로직을 포현하므로 도메인 서비스의 위치는 다른 도메인 구성 요소와 동일한 패키지에 위치한다.

![도메인 영역에 위치한 도메인 서비스](/assets/img/dev/2024/0420/domain_service.png)

만일 도메인 서비스 갯수가 많거나 엔티티, 밸류와 같은 다른 구성 요소와 명시적으로 구분하고 싶다면 domain 패키지 아래 domain.model, domain.service, domain.repository 와 같이 
하위 패키지를 구분하여 위치시켜도 된다.

---

## 2.4. 도메인 서비스의 인터페이스와 클래스

**도메인 서비스의 로직이 고정되어 있지 않은 경우 도메인 서비스 자체를 인터페이스로 구현하고 이를 구현한 클래스**를 둔다.

특히 도메인 로직이 외부 시스템을 이용하거나 특정 기술에 종속되면 인터페이스와 클래스를 분리하게 된다.

예를 들어 할인 금액 계산 로직을 특정 방식(예를 들어 룰 엔진)을 이용하여 구현한다면 도메인 영역에는 도메인 서비스 인터페이스가 위치하고 이를 구현한 클래스는 
인프라스트럭처 영역에 위치한다.

![도메인 서비스 구현이 특정 기술에 종속되면 인터페이스와 구현 클래스로 분리](/assets/img/dev/2024/0420/domain_service_2.png)

이렇게 **도메인 서비스의 구현이 특정 구현 기술에 의존하거나 외부 시스템의 API 를 실행한다면 도메인 영역의 도메인 서비스는 인터페이스로 추상화**해야 **도메인 영역이 
특정 구현에 종속되는 것을 방지할 수 있고, 도메인 영역에 대한 테스트도 쉬워진다.**


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기** 와 블라드 코노노프 저자의 **도메인 주도 설계 첫걸음**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [도메인 주도 설계 첫걸음](https://www.yes24.com/Product/Goods/109708596)
* [책 예제 git](https://github.com/madvirus/ddd-start2)