---
layout: post
title:  "Java8 - 리팩토링, 디자인 패턴"
date:   2023-07-01
categories: dev
tags: java java8 refactoring design-pattern strategy-pattern template-pattern observer-pattern chain-of-responsibility-pattern factory-method-pattern factory-pattern
---

이 포스트에서는 람다 표현식을 이용하여 가독성과 유연성을 높이려면 기존 코드를 어떻게 리팩토링해야 하는지 알아본다.  
또한 람다 표현식으로 전략 패턴, 템플릿 메서드 패턴, 옵저버 패턴, 의무 체인 패턴, 팩토리 패턴 등 객체지향 디자인 패턴을 어떻게 간소화할 수 있는지 알아본다.


> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap08) 에 있습니다.

---

**목차**  

<!-- TOC -->
* [1. 가독성과 유연성을 개선하는 리팩토링](#1-가독성과-유연성을-개선하는-리팩토링)
  * [1.1. 익명 클래스를 람다 표현식으로 리팩토링](#11-익명-클래스를-람다-표현식으로-리팩토링)
  * [1.2. 람다 표현식을 메서드 레퍼런스로 리팩토링](#12-람다-표현식을-메서드-레퍼런스로-리팩토링)
  * [1.3. 명령형 데이터 처리를 스트림으로 리팩토링](#13-명령형-데이터-처리를-스트림으로-리팩토링)
  * [1.4. 코드 유연성 개선](#14-코드-유연성-개선)
* [2. 람다로 객체지향 디자인 패턴 리팩토링](#2-람다로-객체지향-디자인-패턴-리팩토링)
  * [2.1. 전략 패턴 (Strategy Pattern)](#21-전략-패턴-strategy-pattern)
    * [2.1.1 람다 표현식](#211-람다-표현식)
  * [2.2. 템플릿 메서드 패턴 (Template Method Pattern)](#22-템플릿-메서드-패턴-template-method-pattern)
    * [2.2.1. 람다 표현식](#221-람다-표현식)
  * [2.3. 옵저버 패턴 (Observer Pattern)](#23-옵저버-패턴-observer-pattern)
    * [2.3.1. 람다 표현식](#231-람다-표현식)
  * [2.4. 의무 체인 패턴 (Chain of Responsibility Pattern)](#24-의무-체인-패턴-chain-of-responsibility-pattern)
    * [2.4.1. 람다 표현식](#241-람다-표현식)
  * [2.5. 팩토리 패턴 (Factory Pattern)](#25-팩토리-패턴-factory-pattern)
    * [2.5.1. 람다 표현식](#251-람다-표현식)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 가독성과 유연성을 개선하는 리팩토링

---

## 1.1. 익명 클래스를 람다 표현식으로 리팩토링

익명 클래스를 람다 표현식으로 리팩토링하면 간결하고 가독성 좋은 코드를 구현할 수 있다.

[Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#12-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-functional-interface) 의 _1.2. 함수형 인터페이스 (Functional Interface)_ 에서 본
Runnable 객체를 각각 익명 클래스와 람다를 사용하여 비교한 코드를 다시 보자.

```java
public static void process(Runnable r) {
  r.run();
}
```

```java
// 익명 클래스 사용
Runnable r1 = new Runnable() {
  @Override
  public void run() {
    System.out.println("익명 클래스 사용");
  }
};

// 람다 사용
Runnable r2 = () -> System.out.println("람다 사용");

process(r1);
process(r2);

// 람다 표현식을 직접 전달
process(() -> System.out.println("람다 표현식 직접 전달"));
```

람다를 사용하면 익명 클래스를 사용할 때보다 코드가 훨씬 간결해지는 것을 알 수 있다.

---

하지만 모든 익명 클래스를 람다 표현식으로 변환할 수 있는 것은 아니다.

- **익명 클래스에서 사용하는 this / super 는 람다 표현식에서는 다른 의미를 가짐**  

익명 클래스에서의 this 는 클래스 자신을 가리키지만 람다에서의 this 는 람다를 감싸는 클래스를 가리킨다.

- **익명 클래스는 감싸고 있는 클래스의 변수를 가릴 수 있지만(섀도우 변수) 람다 표현식은 변수를 가릴 수 없음**  

```java
// 익명 클래스는 감싸고 있는 클래스의 변수를 가릴 수 있음 (섀도우 변수)
int a = 11;
Runnable r1 = new Runnable() {
  @Override
  public void run() {
    int a = 10;
    System.out.println(a);
  }
};
```

```java
// 10
r1.run();
```

```java
// 람다는 변수를 가릴 수 없음
int b = 22;
Runnable r2 = () -> {
  int b = 20; // 이 부분때문에 컴파일되지 않음
  System.out.println(b);
};
```

```java
// 오류
r2.run();
```

- **익명 클래스를 람다 표현식으로 변경 시 context 오버로딩에 따른 모호함이 발생할 수 있음**  

익명 클래스는 인스턴스화할 때 명시적으로 형식이 정해지는 반면, 람다의 형식은 context 에 따라 달라지기 때문이다.

아래 Runnable() 과 같은 시그니처인 `() -> void` 를 갖는 Task 라는 함수형 인터페이스를 선언했다고 하자.

```java
interface Task {
  public void execute();
}

public static void Run(Runnable r) {
  r.run();
}

public static void Run(Task t) {
  t.execute();
}
```

익명 클래스로 전달 시
```java
// Task 를 구현하는 익명 클래스 전달
Run(new Task() {
  @Override
  public void execute() {
    System.out.println("Task 를 구현하는 익명 클래스 전달");
  }
});
```

출력
```shell
Task 를 구현하는 익명 클래스 전달
```

익명 클래스를 람다로 변경하여 전달 시
```java
// 익명 클래스를 람다로 바꾸어 메서드 호출
Run(() -> System.out.println("Task 를 구현하는 익명 클래스 전달")); // 오류 발생
```

```shell
Error

Ambiguous method call. Both
Run (Runnable) in AnonymousClassToLambdaExpression and
Run (Task) in AnonymousClassToLambdaExpression match
```

명시적으로 형변환을 하여 모호함 제거
```java
// 명시적 형변환으로 모호함 제거
Run((Task) () -> System.out.println("Task 를 구현하는 익명 클래스 전달"));
```

출력
```shell
Task 를 구현하는 익명 클래스 전달
```

---

## 1.2. 람다 표현식을 메서드 레퍼런스로 리팩토링

> 메서드 레퍼런스는 [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](https://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/#1-%EB%A9%94%EC%84%9C%EB%93%9C-%EB%A0%88%ED%8D%BC%EB%9F%B0%EC%8A%A4) 의 _1. 메서드 레퍼런스_ 를 참고하세요.

아래는 [Java8 - Stream 으로 데이터 수집 (1): Collectors 클래스, Reducing 과 Summary, Grouping](https://assu10.github.io/dev/2023/06/17/java8-stream-3-1/#3-%EA%B7%B8%EB%A3%B9%ED%99%94-groupingby) 의 _3. 그룹화: `groupingby()`_ 에 나온 코드이다.  

람다 표현식 사용
```java
public static Map<CaloricLevel, List<Dish>> groupByCaloricLevel() {
  return Dish.menu.stream()
          .collect(
                  groupingBy(dish -> {
                    if (dish.getCalories() <= 400) {
                      return CaloricLevel.DIET;
                    } else if (dish.getCalories() <= 700) {
                      return CaloricLevel.NOMAL;
                    } else {
                      return CaloricLevel.FAT;
                    }
                  })
          );
}
```

```java
// 람다 표현식 사용
Map<Dish.CaloricLevel, List<Dish>> dishesByCaloricLevel = groupByCaloricLevel();

// {NORMAL=[beef, french fries, pizza, salmon], DIET=[chicken, rice, season fruit, prawns], FAT=[pork]}
System.out.println(dishesByCaloricLevel);
```

위의 람다 표현식을 별도의 메서드로 추출한 후 groupingBy() 에 인수로 전달할 수 있다.

Dish 클래스에 아래와 같은 메서드를 추가한다.
```java
enum CaloricLevel { DIET, NORMAL, FAT }
  
public CaloricLevel getCaloricLevel() {
  if (this.getCalories() <= 400) {
    return Dish.CaloricLevel.DIET;
  } else if (this.getCalories() <= 700) {
    return Dish.CaloricLevel.NORMAL;
  } else {
    return Dish.CaloricLevel.FAT;
  }
}
```

```java
// 메서드 레퍼런스 사용
Map<Dish.CaloricLevel, List<Dish>> dishByCaloricLevel2 = Dish.menu.stream()
        .collect(
                groupingBy(Dish::getCaloricLevel)
        );

// {NORMAL=[beef, french fries, pizza, salmon], DIET=[chicken, rice, season fruit, prawns], FAT=[pork]}
System.out.println(dishByCaloricLevel2);
```

---

`Comparator.comparing()` 이나 `Collectors.maxBy()` 같은 정적 헬퍼 메서드를 이용하는 것도 좋다.

아래는 [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](https://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/#1-%EB%A9%94%EC%84%9C%EB%93%9C-%EB%A0%88%ED%8D%BC%EB%9F%B0%EC%8A%A4) 의 _1. 메서드 레퍼런스_ 에서 보았던 코드이다.

```java
List<Apple> inventory = Arrays.asList(new Apple(10, "red"),
            new Apple(100, "green"),
            new Apple(150, "red"));
```

람다 표현식으로 정렬
```java
inventory.sort((Apple a1, Apple a2) -> a1.getWeight().compareTo(a1.getWeight()));
```

```shell
[Apple{weight=10, color='red'}, Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
```


메서드 레퍼런스로 정렬
```java
inventory.sort(comparing(Apple::getWeight));
```

메서드 레퍼런스로 정렬 시 코드의 의도를 더 명확하게 알 수 있다.

```shell
[Apple{weight=10, color='red'}, Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
```

---

`Collectors.summingInt()` 나 `Collectors.maxBy()` 같이 자주 사용하는 리듀싱 연산은 메서드 레퍼런스와 함께 사용할 수 있는 내장 헬퍼 메서드를 제공한다.

람다 + 저수준 리듀싱 조합
```java
// 람다 + 저수준 리듀싱 조합
int totalCalories = Dish.menu.stream()
        .map(Dish::getCalories)
        .reduce(0, (c1, c2) -> c1+c2);
```

```java
// 4300
System.out.println(totalCalories);
```

메서드 레퍼런스 + Collectors API 조합
```java
// 메서드 레퍼런스 + Collectors API 조합
int totalCalories2 = Dish.menu.stream().collect(summingInt(Dish::getCalories));
```

```java
// 4300
System.out.println(totalCalories2);
```

---

## 1.3. 명령형 데이터 처리를 스트림으로 리팩토링

반복자를 이용한 거의 모든 컬렉션 처리 코드는 스트림 API 로 변경하는 것이 좋다.

스트림 API 는 데이터 처리 파이프 라인의 의도를 명확하게 보여주고, 쇼트 서킷/게으름 이라는 최적화 뿐 아니라 멀티코어 아키텍처를 쉽게 활용할 수 있도록 해준다.

> 쇼트 서킷에 대한 좀 더 자세한 내용은 [Java8 - Stream 활용 (1): 필터링, 슬라이싱, 매핑, 검색, 매칭](https://assu10.github.io/dev/2023/06/06/java8-stream-2/) 의
> _3.3. Predicate\<T\> 가 모든 요소와 일치하지 않는지 확인: `noneMatch()`_ 를 참고하세요.

아래는 필터링과 추출을 각각 명령형 코드와 스트림 API 로 구현한 예시이다.

필터링과 추출을 명령형 코드로 구현
```java
// 필터링과 추출을 명령형 코드로 구현
List<String> dishNames = new ArrayList<>();
for (Dish dish: Dish.menu) {
  if (dish.getCalories() > 300) {
    dishNames.add(dish.getName());
  }
}
```

```java
// [pork, beef, chicken, french fries, rice, pizza, prawns, salmon]
System.out.println(dishNames);
```

필터링과 추출을 스트림 API 로 구현
```java
// 필터링과 추출을 스트림 API 로 구현
List<String> dishNames2 = Dish.menu.stream()
        .filter(d -> d.getCalories() > 300)
        .map(Dish::getName)
        .collect(Collectors.toList());
```

```java
// [pork, beef, chicken, french fries, rice, pizza, prawns, salmon]
System.out.println(dishNames2);
```

---

## 1.4. 코드 유연성 개선

코드의 유연성은 [동작 파라메터화](https://assu10.github.io/dev/2023/05/27/java8-behavior-parameterization/)를 통해 개선할 수 있다.

즉, 다양한 람다를 전달하여 동작을 다양하게 표현할 수 있다.

또한 [실행 어라운트 패턴](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#14-%EB%9E%8C%EB%8B%A4-%ED%91%9C%ED%98%84%EC%8B%9D-%ED%99%9C%EC%9A%A9-%EC%8B%A4%ED%96%89-%EC%96%B4%EB%9D%BC%EC%9A%B4%EB%93%9C-%ED%8C%A8%ED%84%B4) 을 통해
코드를 재사용함으로써 중복되는 코드를 제거할 수 있다.

---

# 2. 람다로 객체지향 디자인 패턴 리팩토링

디자인 패턴은 다양한 패턴을 유형별로 정리한 것으로 공통적인 소프트웨어 문제를 설계할 때 재사용할 수 있는 검증된 청사진이다.

람다를 이용하면 이전에 디자인 패턴으로 해결하던 문제를 더 쉽고 간단하게 해결할 수 있으며, 기존의 객체지향 디자인 패턴을 제거하거나 간결하게 재구현할 수 있다.

---

## 2.1. 전략 패턴 (Strategy Pattern)

전략 패턴은 **한 유형의 알고리즘을 보유한 상태에서 런타임에 적절한 알고리즘을 선택하는 디자인 패턴**이다.  

즉, 전략을 쉽게 바꿀 수 있게 해주는 디자인 패턴으로 같은 문제를 해결하는 여러 알고리즘(방식) 이 클래스별로 캡슐화되어 있고, 이들이 필요할 때 교체할 수 있도록
함으로써 동일한 문제를 다른 알고리즘으로 해결할 수 있게 하는 디자인 패턴이다.

![전략 디자인 패턴](/assets/img/dev/2023/0701/strategy.png)

- **Strategy**
  - 인터페이스나 추상 클래스로 외부에서 동일한 방식으로 알고리즘을 호출하는 방법 명시
  - 예) StrategyValidation, MovingStrategy, AttackStrategy
- **ConcreteStrategyA,B**
  - 알고리즘을 구현한 클래스
  - 예) StrategyIsAllLowerCase, StrategyIsNumeric, FlyingStrategy
- **Context**
  - 전략 패턴을 이용하는 역할 수행
  - 예) StrategyValidator, Robot, Atom extends Robot

---

입력에 대해 다양한 포맷을 검증하는 기능을 구현해보자.

먼저 입력을 검증하는 인터페이스(Strategy) 를 정의한다.

Strategy (인터페이스)
```java
// 검증 인터페이스
public interface StrategyValidation {
  boolean execute(String s);
}
```

ConcreteStrategyA,B (인터페이스를 구현하는 클래스)
```java
// 모두 숫자인지 확인하는 구현 클래스
public class StrategyIsNumericValidation implements StrategyValidation {
  @Override
  public boolean execute(String s) {
    return s.matches("\\d+");
  }
}

// 모두 소문자인지 확인하는 구현 클래스
public class StrategyIsAllLowerCaseValidation implements StrategyValidation {
  @Override
  public boolean execute(String s) {
    return s.matches("[a-z]+");
  }
}
```

Context (전략 패턴을 이용하는 클래스)
```java
// 검증 전략 활용
public class StrategyValidator {
  private final StrategyValidation strategy;

  public StrategyValidator(StrategyValidation v) {
    this.strategy = v;
  }

  public boolean validate(String s) {
    return strategy.execute(s);
  }
}
```

검증 활용
```java
StrategyValidator v1 = new StrategyValidator(new StrategyIsNumericValidation());
System.out.println("isNumeric: " + v1.validate("aaa")); // false

StrategyValidator v2 = new StrategyValidator(new StrategyIsAllLowerCaseValidation());
System.out.println("isAllLowerCase: " + v2.validate("aaa")); // true
```

---

### 2.1.1 람다 표현식

StrategyValidation 인터페이스는 [함수형 인터페이스](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#12-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-functional-interface)이며, Predicate\<String\> 과 같은 함수 디스크립터(String -> boolean) 를 갖는다.

따라서 StrategyIsNumericValidation, StrategyIsAllLowerCaseValidation 와 같은 구현 클래스(ConcreteStrategyA,B)를 생성할 필요없이 바로 람다 표현식을 전달하면 코드가 간결해진다.

검증 활용
```java
// 구현 클래스 없이 람다 표현식 바로 사용
StrategyValidator v3 = new StrategyValidator(s -> s.matches("\\d+"));
System.out.println("isNumeric: " + v3.validate("aaa")); // false

StrategyValidator v4 = new StrategyValidator(s -> s.matches("[a-z]+"));
System.out.println("isAllLowerCase: " + v4.validate("aaa")); // false
```

---

## 2.2. 템플릿 메서드 패턴 (Template Method Pattern)

템플릿 메서드 패턴은 **알고리즘의 개요를 제시한 다음 알고리즘의 일부를 고칠 수 있는 유연함을 제공하는 디자인 패턴**이다.  

전체적으로는 동일하면서 부분적으로는 다른 구문으로 구성된 메서드의 코드 중복을 최소화할 때 유용하다.  
**동일한 기능을 상위 클래스에서 정의하면서 확장/변화가 필요한 부분만 서브 클래스에서 구현**할 수 있도록 한다.

전체적인 알고리즘 코드를 재사용하는데 유용하다.

![템플릿 메서드 디자인 패턴](/assets/img/dev/2023/0701/tempate_method.png)

- **AbstractClass**
  - 템플릿 메서드(공통 기능)를 정의하는 추상 클래스
  - 공통 알고리즘을 정의하고 하위 클래스에서 구현될 기능을 primitive 메서드 또는 hook 메서드로 정의하는 클래스
  - 예) TemplateAbstract, TemplateAbstractLambda
- **ConcreteClass**
  - 물려받은 primitive 메서드나 hook 메서드를 구현하는 클래스
  - 상위 클래스에 구현된 템플릿 메서드의 일반적인 알고리즘에서 하위 클래스에 맞게 primitive 메서드나 hook 메서드를 오버라이드하는 클래스

---

은행마다 다양한 뱅킹 시스템을 사용하고 동작 방법도 다른 부분을 이용하여 템플릿 메서드 패턴을 구현해본다.

AbstractClass (추상 클래스)
```java
// 템플릿 메서드를 정의하는 추상 클래스
abstract class TemplateAbstract {

  // 템플릿 메서드
  public void processCustomer(int id) {
    Customer c = Database.getCustomerWithId(id);
    makeCustomerHappy(c);
  }

  // primitive 메서드
  abstract void makeCustomerHappy(Customer c);

  // dummy class
  static private class Customer { }

  // dummy database
  static private class Database {
    static Customer getCustomerWithId(int id) {
      return new Customer();
    }
  }
}
```

이제 은행의 각 지점의 위 추상 클래스를 상속받아 makeCustomerHappy() 메서드가 원하는 동작을 수행하도록 구현할 수 있다.

---

### 2.2.1. 람다 표현식

위 템플릿 메서드 클래스를 람다 표현식으로 변경해보자.

makeCustomerHappy() 메서드 시그니처와 일치하도록 Consumer\<Customer\> 형식을 갖는 두 번째 인수를 processCustomer() 에 추가한다.

> `void makeCustomerHappy(Customer c)` 의 시그니처 `Customer -> void` 는 Consumer\<T\> 의 메서드인 void accept(T t) 의 시그니처 `T -> void` 와 동일하다.  
> 
> Consumer\<T\> 에 대한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#22-consumert-void-acceptt) 의
> _2.2. Consumer\<T\>: `void accept(T)`_ 를 참고하세요.

추상 클래스가 아님
```java
public class TemplateAbstractLambda { // 추상 클래스가 아님
  // 템플릿 메서드
  public void processCustomer(int id, Consumer<Customer> makeCustomerHappy) {
    Customer c = Database.getCustomerWithId(id);
    makeCustomerHappy.accept(c);
  }

  // dummy class
  static public class Customer { }

  // dummy database
  static public class Database {
    static Customer getCustomerWithId(int id) {
      return new Customer();
    }
  }
}
```

TemplateAbstractLambda 클래스를 상속받지 않고도 직접 람다 표현식을 전달해서 다양한 동작을 추가할 수 있다.

```java
public static void main(String[] args) {
  new TemplateAbstractLambda().processCustomer(111, (TemplateAbstractLambda.Customer c) -> System.out.println("hello"));
}
```

---

## 2.3. 옵저버 패턴 (Observer Pattern)

옵저버 패턴은 **어떤 이벤트가 발생했을 때 한 객체(subject) 가 다른 객체 리스트(observer) 에 자동으로 알림을 보내야 하는 상황에서 사용하는 디자인 패턴**이다.

데이터 변경이 발생했을 경우 상태 클래스나 객체에 의존하지 않으면서 데이터 객체를 통보하고자 할 때 유용하다.  
새로운 파일이 추가되거나 삭제되었을 때 탐색기는 이를 즉시 표시해야 하는 경우를 예로 들 수 있다.

옵저버 패턴은 **통보 대상 객체의 관리를 Subject 클래스와 Observer 인터페이스로 일반화**하는데 그러면 데이터 변경을 통보하는 클래스(ConcreteSubject) 는
통보 대상 클래스나 객체(ConcreteObserver) 에 대한 의존성을 없앨 수 있다.  
결과적으로 **통보 대상 클래스나 객체(ConcreteObserver) 의 변경에도 데이터 변경을 통보하는 클래스(ConcreteSubject) 를 수정없이 그대로 사용**할 수 있도록 한다.


![옵저버 디자인 패턴](/assets/img/dev/2023/0701/observer.png)

- **Observer** 
  - 데이터의 변경을 통보받는 인터페이스
  - Subject 는 Observer 인터페이스의 notify() 메서드를 호출함으로써 ConcreteSubject 의 데이터 변경을 ConcreteObserver 에게 통보함
  - 예) Observer
- **Subject** 
  - ConcreteObserver 객체를 관리하는 추상 클래스 혹은 인터페이스
  - Observer 인터페이스를 참조해서 ConcreteObserver 를 관리하므로 ConcreteObserver 의 변화에 독립적일 수 있음
  - 예) ObserverSubject
- **ConcreteSubject** 
  - 변경 관리 대상이 되는 데이터가 있는 클래스
  - 데이터 변경을 위한 메서드인 registerObserver() 가 있으며, registerObserver() 에서는 자신의 데이터인 observers 를 변경하고, Subject 의 notifyObservers() 를 호출해서 ConcreteObserver 객체에 변경을 통보함
  - 예) ObserverFeed
- **ConcreteObserver**
  - ConcreteSubject 의 변경을 통보받는 클래스
  - Observer 인터페이스의 notify() 를 구현함으로써 변경을 통보받음
  - 변경된 데이터는 ConcreteSubject 의 notifyObservers() 를 호출함으로써 변경을 조회함
  - 예) ObserverNYTimes, ObserverLeMonde

예) 주식의 가격(Subject) 변동에 반응하는 다수의 거래자(Observer) 

---

옵저버 패턴으로 트위터 같은 커스터마이즈된 알람 시스템을 설계하고 구현할 수 있다.  
예를 들어 다양한 매체가 뉴스 트윗을 구독하고 있고, 특정 키워드를 포함하는 트윗이 등록되면 알람을 받는 기능을 구현해보자.

먼저 다양한 옵저버를 그룹화할 Observer 인터페이스를 구현한다.  
Observer 인터페이스는 새로운 트윗이 있을 때 Feed(Subject) 가 호출할 수 있도록 notify() 메서드를 제공한다.

Observer (데이터의 변경을 통보받는 인터페이스)
```java
// Observer
// 새로운 트윗이 있을 때 Feed(Subject) 가 호출할 수 있도록 notify() 메서드를 제공
public interface Observer {
  void notify(String tweet);
}
```

이제 트윗에 포함된 다양한 키워드에 다른 동작을 수행할 수 있는 여러 옵저버를 정의한다.  
ConcreteObserver (ConcreteSubject 의 변경을 통보받는 클래스)
```java
public class ObserverLeMonde implements Observer {
  @Override
  public void notify(String tweet) {
    if (tweet != null && tweet.contains("wine")) {
      System.out.println("LeMonde: " + tweet);
    }
  }
}

public class ObserverNYTimes implements Observer {
  @Override
  public void notify(String tweet) {
    if (tweet != null && tweet.contains("money")) {
      System.out.println("NYTimes: " + tweet);
    }
  }
}
```

Subject 는 registerObserver() 로 새로운 옵저버 등록 후 notifyObservers() 로 트윗을 옵저버에 알린다.  
Subject (ConcreteObserver 객체를 관리하는 추상 클래스 혹은 인터페이스)
```java
// ConcreteObserver 객체를 관리하는 추상 클래스 혹은 인터페이스
// registerObserver() 로 새로운 옵저버 등록 후 notifyObservers() 로 트윗을 옵저버에 알림
public interface ObserverSubject {
  void registerObserver(Observer o);
  void deregisterObserver(Observer o);
  void notifyObservers(String tweet);
}
```

ConcreteSubject (변경 관리 대상이 되는 데이터가 있는 클래스)
```java
// ConcreteSubject (변경 관리 대상이 되는 데이터가 있는 클래스)
public class ObserverFeed implements ObserverSubject {
  private final List<Observer> observers = new ArrayList<>();

  @Override
  public void registerObserver(Observer o) {
    this.observers.add(o);
  }

  @Override
  public void deregisterObserver(Observer o) {
    this.observers.remove(o);
  }

  @Override
  public void notifyObservers(String tweet) {
    observers.forEach(o -> o.notify(tweet));
  }
}
```

구현
```java
ObserverFeed observer = new ObserverFeed();
observer.registerObserver(new ObserverNYTimes());
observer.registerObserver(new ObserverLeMonde());

observer.notifyObservers("money!!");  // NYTimes: money!!
```

ConcreteSubject 인 ObserverFeed 는 트윗을 받았을 때 알람을 보낼 옵저버 리스트를 유지한다.

---

### 2.3.1. 람다 표현식

위 코드를 보면 Observer 인터페이스를 구현하는 ConcreteObserver 인 ObserverNYTimes, ObserverLeMonde 는 하나의 메서드인 notify() 를 구현한다.  
트윗이 도착했을 때 어떤 동작을 수행할 지 감싸는 코드를 구현한 것인데 이 2개의 옵저버를 명시적으로 인스턴스화하지 않고 람다 표현식으로 실행할 동작을 직접 전달하면
ConcreteObserver 들을 구현하지 않아도 된다.

```java
// 람다 표현식으로
ObserverFeed observerLambda = new ObserverFeed();

observerLambda.registerObserver((String tweet) -> {
  if (tweet != null && tweet.contains("money")) {
    System.out.println("NYTimes: " + tweet);
  }
});

observerLambda.registerObserver((String tweet) -> {
  if (tweet != null && tweet.contains("wine")) {
    System.out.println("LeMonde: " + tweet);
  }
});

observerLambda.notifyObservers("money!!");  // NYTimes: money!!
```

---

## 2.4. 의무 체인 패턴 (Chain of Responsibility Pattern)

의무 체인 패턴은 **작업처리 객체의 체인을 만들 때 사용하는 디자인 패턴**이다.  
한 객체가 어떤 작업을 처리한 후 다른 객체로 결과를 전달하고, 다른 객체도 작업을 처리한 후 또 다른 객체로 전달하는 방식이다.

![의무 체인 디자인 패턴](/assets/img/dev/2023/0701/chain.png)

[2.2. 템플릿 메서드 패턴 (Template Method Pattern)](#22-템플릿-메서드-패턴-template-method-pattern) 의 디자인 패턴과 동일하다.  
handle() 메서드는 일부 작업을 어떻게 처리할 지 전체적으로 기술하고, 추상 클래스 (ChainProcessingObject) 를 상속받아 handleWork() 메서드를 구현하여
다양한 종류의 작업처리 객체를 만든다.

---

다음에 처리할 객체 정보를 유지하는 필드를 포함하는 작업처리 추상 클래스로 의무 체인 패턴을 구성한다.

AbtractClass
```java
public abstract class ChainProcessingObject<T> {
  protected ChainProcessingObject<T> successor;

  public void setSuccess(ChainProcessingObject<T> successor) {
    this.successor = successor;
  }

  public T handle(T input) {
    T r = handleWork(input);
    if (successor != null) {
      return successor.handle(r);
    }
    return r;
  }

  abstract protected T handleWork(T input);
}
```

ConcreteClass
```java
public class ChainText extends ChainProcessingObject<String>{
  @Override
  protected String handleWork(String input) {
    return "This is Text" + input + " hi!";
  }
}
```

ConcreteClass
```java
public class ChainSpellingCheck extends ChainProcessingObject<String>{
  @Override
  protected String handleWork(String input) {
    return input.replaceAll("labda", "lambda");
  }
}
```

이제 이 2개의 작업처리 객체를 연결해서 작업 체인을 만들 수 있다.

```java
ChainProcessingObject<String> p1 = new ChainText();
ChainProcessingObject<String> p2 = new ChainSpellingCheck();

// 2개의 작업처리 객체 연결
p1.setSuccess(p2);

String result = p1.handle("test labdas.");

// result: This is Texttest lambdas. hi!
System.out.println("result: " + result);
```

---

### 2.4.1. 람다 표현식

> 람다 표현식의 조합은 [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](https://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/#3-%EB%9E%8C%EB%8B%A4-%ED%91%9C%ED%98%84%EC%8B%9D%EC%9D%84-%EC%A1%B0%ED%95%A9%ED%95%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%EB%A9%94%EC%84%9C%EB%93%9C) 의
> _3. 람다 표현식을 조합할 수 있는 메서드_ 을 참고하세요. 

> `UnaryOperator<T>` (T -> T) 에 대한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 의
> _2.4. 기본형(primitive type) 특화_ 를 참고하세요.

아래와 같이 람다 표현식을 사용하면 ConcreteClass 인 ChainText 와 ChainSpellingCheck 을 구현하지 않아도 된다.

```java
// 람다 표현식으로
UnaryOperator<String> textProcessing = (String text) -> "This is Text" + text + " hi!";
UnaryOperator<String> spellingCheckProcessing = (String text) -> text.replaceAll("labda", "lambda");

Function<String, String> pipeline = textProcessing.andThen(spellingCheckProcessing);
String result2 = pipeline.apply("test labdas.");

// result2: This is Texttest lambdas. hi!
System.out.println("result2: " + result2);
```

---

## 2.5. 팩토리 패턴 (Factory Pattern)

팩토리 패턴(팩토리 메서드 패턴)은 **인스턴스화 로직을 클라이언트에 노출하지 않고 객체를 만들 때 사용하는 디자인 패턴**이다.  

객체의 생성 코드를 별도의 클래스/메서드로 분리함으로써 객체 생성의 변화에 대비하는데 유용하다.

---

은행에서 취급하는 대출, 채권 등 다양한 상품을 만드는 경우에 대해 팩토리 패턴을 적용해본다.

먼저 다양한 상품을 생성하는 Factory 클래스를 생성한다.

팩토리 클래스
```java
// 팩토리 클래스
public class FactoryProduct {

  // 생성자가 외부로 노출되지 않음
  public static Product createProduct(String s) {
    switch (s) {
      case "loan":
        return new Loan();
      case "stock":
        return new Stock();
      default:
        throw new RuntimeException("No such product: " + s);
    }
  }

  public interface Product { }
  static private class Loan implements Product { }
  static private class Stock implements Product { }
}
```

```java
FactoryProduct.Product p = FactoryProduct.createProduct("loan");

// class com.assu.study.mejava8.chap08.FactoryProduct$Loan
System.out.println(p.getClass());
```

생성자가 외부로 노출되지 않아 클라이언트가 단순하게 생성할 수 있다.

---

### 2.5.1. 람다 표현식

```java
// 팩토리 클래스
public class FactoryProduct {
  public static Product createProductLambda(String s) {
    Supplier<Product> p = map.get(s);
    if (p != null) {
      return p.get();
    }
    throw new RuntimeException("No such product: " + s);
  }


  public interface Product { }
  static private class Loan implements Product { }
  static private class Stock implements Product { }

  final static private Map<String, Supplier<Product>> map = new HashMap<>();
  static {
    map.put("loan", Loan::new); // 메서드 레퍼런스
    map.put("stock", Stock::new);
  }
}
```

> Supplier\<T\>,  `() -> T` 에 관한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 의
> _2.4. 기본형(primitive type) 특화_ 를 참고하세요.

```java
// 람다 표현식으로
FactoryProduct.Product p2 = FactoryProduct.createProductLambda("loan");

// class com.assu.study.mejava8.chap08.FactoryProduct$Loan
System.out.println(p2.getClass());
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)
* [자바 객체지향 디자인 패턴](https://www.yes24.com/Product/Goods/12501269)