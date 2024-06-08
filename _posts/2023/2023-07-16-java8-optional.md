---
layout: post
title:  "Java8 - Optional 클래스"
date:   2023-07-16
categories: dev
tags: java java8 optional-class optional
---

이 포스트에서는 아래 내용에 대해 알아본다.
- null 레퍼런스의 문제점
- null 대신 Optional: null 로부터 안전한 도메인 모델 재구현
- Optional 활용: null 확인 코드 제거
- Optional 에 저장된 값 확인
- 값이 없을 수도 있는 상황으로 고려하는 프로그래밍

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap10) 에 있습니다.

---

**목차**  

<!-- TOC -->
* [1. null 에서의 기존 처리](#1-null-에서의-기존-처리)
* [2. Optional 클래스](#2-optional-클래스)
* [3. Optional 적용 패턴](#3-optional-적용-패턴)
  * [3.1. Optional 객체 생성](#31-optional-객체-생성)
    * [3.1.1. 빈 Optional 생성: `Optional.empty()`](#311-빈-optional-생성-optionalempty)
    * [3.1.2. null 값을 포함하지 않는 Optional 생성: `Optional.of()`](#312-null-값을-포함하지-않는-optional-생성-optionalof)
    * [3.1.3. null 값으로 Optional 생성: `Optional.ofNullable()`](#313-null-값으로-optional-생성-optionalofnullable)
  * [3.2. map() 으로 Optional 값 추출 후 변환](#32-map-으로-optional-값-추출-후-변환)
  * [3.3. flatMap() 으로 Optional 객체 연결](#33-flatmap-으로-optional-객체-연결)
    * [도메인 모델에 Optional 사용 시 데이터 직렬화 불가능](#도메인-모델에-optional-사용-시-데이터-직렬화-불가능)
  * [3.4. 디폴트 액션과 Optional 언랩](#34-디폴트-액션과-optional-언랩)
    * [`get()`](#get)
    * [`orElse(T other)`](#orelset-other)
    * [`orElseGet(Supplier<? extends T> other)`](#orelsegetsupplier-extends-t-other)
    * [`orElseThrow(Supplier<? extends X> exceptionSupplier)`](#orelsethrowsupplier-extends-x-exceptionsupplier)
    * [`ifPresent(Consumer<? super T> consumer)`](#ifpresentconsumer-super-t-consumer)
  * [3.5. 두 Optional 합치기](#35-두-optional-합치기)
  * [3.6. 필터로 특정값 거르기](#36-필터로-특정값-거르기)
  * [3.7. Optional 클래스의 메서드](#37-optional-클래스의-메서드)
* [4. 기본형 특화 Optional](#4-기본형-특화-optional)
* [5. 정리하며..](#5-정리하며)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. null 에서의 기존 처리

```java
public class Insurance {
  private String name;

  public String getName() {
    return name;
  }
}

public class Car {
  private Insurance insurance;

  public Insurance getInsurance() {
    return insurance;
  }
}

public class Person {
  private Car car;

  public Car getCar() {
    return car;
  }
}
```

```java
public static String getCarInsuranceName(Person person) {
  return person.getCar().getInsurance().getName();
}
```

위 코드 실행 시 아래와 같이 NullPointerException 이 발생한다.

```shell
Exception in thread "main" java.lang.NullPointerException: Cannot invoke "Car.getInsurance()" because the return value of "Person.getCar()" is null
	at PersonMain.getCarInsuranceName(PersonMain.java:10)
	at PersonMain.main(PersonMain.java:6)
```

null 을 방어하기 위한 시도 1: 깊은 의심
```java
public static String getCarInsuranceName2(Person person) {
  if (person != null) {
    Car car = person.getCar();
    if (car != null) {
      Insurance insurance = car.getInsurance();
      if (insurance != null) {
        return insurance.getName();
      }
    }
  }
  return "Null";
}
```

위 코드를 보면 변수의 null 을 체크하느라 코드 들여쓰기 수준이 증가한다. 이러한 반복 패턴 코드를 깊은 의심(deep doubt) 라고 한다.

null 을 방어하기 위한 시도 2: 너무 많은 출구
```java
public static String getCarInsuranceName3(Person person) {
  if (person == null) {
    return "Null";
  }

  Car car = person.getCar();
  if (car == null) {
    return "Null";
  }

  Insurance insurance = car.getInsurance();
  if (insurance == null) {
    return "Null";
  }

  return insurance.getName();
}
```

중첩 if 문은 제거했지만 4개의 출구가 생겼기 때문에 좋은 코드는 아니다. 반복되는 "Null" 문구 또한 복붙을 하면서 오타 등의 실수가 발생할 수 있다.

---

# 2. Optional 클래스

Java8 은 java.util.Optional\<T\> 클래스를 제공한다.

Optional 은 선택형 값을 캡술화하는 클래스로, 값이 있으면 Optional 클래스는 값을 감싸고 값이 없으면 Optional.empty() 로 Optional 을 반환한다.

Optional.empty() 는 Optional 의 싱글턴 인스턴스를 반환하는 정적 팩토리 메서드이다.

이제 위 코드를 Optional 을 이용하여 개선해보자.

```java
public class Insurance {
  // 보험 회사는 반드시 이름이 있음
  private String name;

  public String getName() {
    return name;
  }
}

public class Car {
  // 보험이 있을 수도 있고 없을 수도 있다.
  private Optional<Insurance> insurance;

  public Optional<Insurance> getInsurance() {
    return insurance;
  }
}

public class Person {
  // 차가 있을 수도 있고 없을 수도 있다.
  private Optional<Car> car;

  public Optional<Car> getCar() {
    return car;
  }
}
```

보험의 경우 Optional<String> 이 아닌 String 형식으로 선언하였다. (반드시 이름이 있어야 함을 의미)  
보험회사의 이름이 null 인지 확인하는 코드를 추가할 필요는 없다. 그렇게 되면 오히려 고쳐야 할 문제를 감추는 꼴이 된다.  
이럴 경우 예외를 처리하는 코드를 추가하는 것이 아니라 예외 발생 시 이름이 없는 이유를 밝혀서 문제를 해결해야 한다.

**Optional 을 이용하면 값이 없는 상황이 데이터에 문제가 있는 것인지 아니면 알고리즘의 버그인지 명확하게 구분**할 수 있다.

따라서 **모든 null 레퍼런스를 Optional 로 대치하는 것은 바람직하지 않다. Optional 을 통해 메서드의 시그니처만 보고도 선택형 값인지 여부를 구별**할 수 있다.

---

# 3. Optional 적용 패턴

---

## 3.1. Optional 객체 생성

### 3.1.1. 빈 Optional 생성: `Optional.empty()`

static factory 메서드인 `Optional.empty()` 로 빈 Optional 객체 생성이 가능하다.

```java
// 빈 Optional 생성
Optional<Car> optCar = Optional.empty();
```

---

### 3.1.2. null 값을 포함하지 않는 Optional 생성: `Optional.of()`

static factory 메서드인 `Optional.of()` 로 null 을 포함하지 않는 Optional 객체 생성이 가능하다.

```java
// null 이 아닌 값으로 Optional 생성
Car car = null;
Optional<Car> optCar2 = Optional.of(car);
```

**위 코드를 컴파일하면 NPE 가 발생**한다. (= 컴파일러 에러)  
**만일 Optional 을 사용하지 않았다면 car 프로퍼티에 접근할 때 에러가 발생**한다. (= 런타임 에러)

---

### 3.1.3. null 값으로 Optional 생성: `Optional.ofNullable()`

static factory 메서드인 `Optional.ofNullable()` 로 null 값을 저장할 수 있는 Optional 객체 생성이 가능하다.

```java
// null 값으로 Optional 생성
Optional<Car> optCar3 = Optional.ofNullable(car);
```

만일 car 가 null 이면 빈 객체인 Optional.empty 를 반환한다.

---

Optional 객체에서 값을 꺼낼 때는 `get()` 을 이용해서 값을 꺼낼 수 있다.  
하지만 Optional 이 비어있으면 get() 호출 시 예외가 발생한다. (= Optional 을 잘못 사용하면 결국 null 을 사용했을 때와 같은 문제를 겪을 수 있음)  
따라서 Optional 로 명시적인 검사를 제거할 수 있는 방법에 대해 살펴보자.

---

## 3.2. map() 으로 Optional 값 추출 후 변환

```java
String name = null;
if (insurance != null) {
  name = insurance.getName();
}
```

이런 유형의 패턴에 사용할 수 있도록 Optional 은 map() 메서드를 지원한다.

```java
Insurance insurance = new Insurance();
Optional<Insurance> optInsurance = Optional.ofNullable(insurance);
Optional<String> name = optInsurance.map(Insurance::getName);

// Optional.empty
System.out.println(name);
```

Optional 의 map() 은 Stream 의 map() 과 개념적으로 비슷하다.  
Stream 의 map() 은 스트림 각 요소에 제공된 함수를 적용하는 연산이다. 여기서 Optional 객체를 최대 요소의 개수가 한 개 이하인 데이터 컬렉션으로 생각할 수 있다.

만일 Optional 이 값을 포함하면 map() 의 인수로 제공된 함수가 값을 바꾸고, Optional 이 비어있으면 아무 일도 일어나지 않는다.

---

## 3.3. flatMap() 으로 Optional 객체 연결

이제 아래와 같은 여러 메서드를 안전하게 호출하는 법에 대해 알아보자.
```java
public String getCarInsuranceName(Person person) {
  return person.getCar().getInsurance().getName();
}
```

위 내용은 map() 으로 재구현해보자.

```java
Person person = new Person();
Optional<Person> optPerson = Optional.of(person);
Optional<String> name = optPerson
        .map(Person::getCar)  // Optional<Optional<Car>> 반환
        .map(Car::getInsurance) // Optional<U> 반환
        .map(Insurance::getName);
```

위 코드는 아래와 같은 에러가 뜨면서 컴파일되지 않는다.

```shell
reason: no instance(s) of type variable(s) exist so that Optional<Car> conforms to Car
```

optPerson 의 형식은 Optional<Person> 이므로 map() 을 호출할 수 있다.  
하지만 getCar() 는 Optional<Car> 형식이기 때문에 map() 연산의 결과는 Optional<Optional<Car>> 가 된다. (= 중첩 Optional 객체)

스트림의 [flatMap()](https://assu10.github.io/dev/2023/06/06/java8-stream-2/#22-%EC%8A%A4%ED%8A%B8%EB%A6%BC-%ED%8F%89%EB%A9%B4%ED%99%94-map-%EA%B3%BC-arraysstream-flatmap) 은 
함수를 인수로 받아서 다른 스트림을 반환하는 메서드이다. 즉, 함수를 적용해서 생성된 모든 스트림이 하나의 스트림으로 병합되어 평준화된다.

Optional 도 이차원 Optional 을 일차원 Optional 로 평준화할 때 flatMap() 을 사용할 수 있다.

```java
public static String getCarInsuranceName(Optional<Person> person) {
  return person.flatMap(Person::getCar) // Optional<Car> 반환
          .flatMap(Car::getInsurance) // Optional<Insurance> 반환
          .map(Insurance::getName)  // Optional<String> 반환
          .orElse("Unknown");
}
```

`orElse()` 는 Optional 이 비어있을 때 디폴트값을 제공한다.

```java
Person person = new Person();
Optional<Person> optPerson = Optional.of(person);

String name = getCarInsuranceName(optPerson);
System.out.println(name);
```

---

### 도메인 모델에 Optional 사용 시 데이터 직렬화 불가능

[2. Optional 클래스](#2-optional-클래스) 에서 본 것처럼 Optional 로 도메인 모델에서 값이 꼭 있어야 하는 경우인지 여부를 구체적으로 표현할 수 있었다.

Optional 클래스는 필드 형식으로 사용할 것을 가정하지 않았기 때문에 Serializable 인터페이스를 구현하지 않는다.  
따라서 도메인 모델에 Optional 을 사용한다면 직렬화 모델을 사용하는 도구나 프레임워크에서 문제가 생길 수 있다.  
하지만 이와 같은 단점에도 객체가 null 일 수 있는 상황이라면 Optional 을 사용해서 도메인 모델을 구성하는 것이 바람직하다.

직렬화 모델이 필요하다면 아래처럼 Optional 로 값을 반환받을 수 있는 메서드를 추가하는 방식을 권장한다.

기존
```java
public Optional<Car> getCar() {
  return car;
}
```

직렬화 지원
```java
public Optional<Car> getCarAsOptional() {
  return Optional.ofNullable(car);
}
```

---

## 3.4. 디폴트 액션과 Optional 언랩

Optional 클래스는 Optional 인스턴스에서 값을 읽을 수 있는 다양한 인스턴스 메서드를 제공한다.

### `get()`

- 값을 읽는 가장 간단한 메서드이면서 동시에 가장 안전하지 않은 메서드
- 래핑된 값이 있으면 해당 값을 반환하고, 값이 없으면 NoSuchElementException 발생
- 따라서 Optional 에 반드시 값이 있다고 가정할 수 있는 상황에서만 사용이 가능한데 이건 결국 null 확인 코드를 넣는 상황과 크게 다르지 않음

---

### `orElse(T other)`

- Optional 이 값을 포함하지 않을 때 디폴트값 제공

---

### `orElseGet(Supplier<? extends T> other)`

- orElse() 에 대응하는 게으른 버전의 메서드
- Optional 에 값이 없을 때만 Supplier 가 실행됨
- 디폴트 메서드를 만드는 데 시간이 걸리거나 Optional 이 비어있을 때만 디폴트 값을 생성하고 싶다면(디폴트 값이 반드시 필요한 상황) orElseGet() 사용

---

### `orElseThrow(Supplier<? extends X> exceptionSupplier)`

- Optional 이 비어있을 때 예외를 발생시킨다는 점에서 get() 과 비슷
- 다른 점은 발생시킬 예외의 종류를 선택할 수 있다는 점이 다름

---

### `ifPresent(Consumer<? super T> consumer)`

- 값이 존재할 때 인수로 넘겨준 동작을 실행
- 값이 없으면 아무 일도 일어나지 않음

---

## 3.5. 두 Optional 합치기

예를 들어 Person 과 Car 를 이용하여 가장 저렴한 보험료를 제공하는 보험회사를 찾는 기능을 구현한다고 해보자.

```java
public Insurance findCheapestInsurance(Person person, Car car) {
  ...
  return cheapestCompany;
}
```

두 Optional 을 인수로 받아서 Optional\<Insurance\> 를 반환하는 null-safe 한 메서드를 구현해보자.  
인수들 중 하나라도 비어있으면 비어있는 Optional\<Insurance\> 를 반환한다.

```java
public Optional<Insurance> nullSafeCheapestInsurance(Optional<Person> person, Optional<Car> car) {
  if (person.isPresent() && car.isPresent()) {
    return Optional.of(findCheapestInsurance(person.get(), car.get()));
  } else {
    return Optional.empty();
  }
}
```

> `Optional.isPresent()` 는 Optional 이 값을 포함하는지 여부를 알려줌

위 메서드는 person 과 car 의 시그니처만으로 둘 다 아무값도 반환하지 않을 수 있다는 정보를 명시적으로 보여준다.  
하지만 구현 코드는 null 확인 코드와 크게 다른 점이 없다.

위 코드를 아래와 같이 개선 가능하다.

```java
public Optional<Insurance> nullSafeCheapestInsurance2(Optional<Person> person, Optional<Car> car) {
  return person.flatMap(p -> car.map(c -> findCheapestInsurance(p, c)));
}
```

첫 번째 Optional 에서 flatMap() 을 호출했으므로 첫 번째 Optional 이 비어있다면 인수로 전달한 람다 표현식이 실행되지 않고 그대로 빈 Optional 을 반환한다.  
반면 person 값이 있다면 flatMap() 메서드에 필요한 Optional\<Insurance\> 를 반환하는 Function 의 입력으로 person 을 사용한다.

두 번째 Optional 에 map() 을 호출하므로 Optional 이 car 값을 포함하지 않으면 Function 은 빈 Optional 을 반환하므로 결국 nullSafeCheapestInsurance2() 는 빈 Optional 을 반환한다.

마지막으로 person 과 car 가 모두 존재하면 map() 메서드로 전달한 람다 표현식이 findCheapestInsurance() 메서드를 안전하게 호출한다.

---

## 3.6. 필터로 특정값 거르기

보험회사 이름이 'testCompany' 인지 확인해야 한다고 하면 먼저 Insurance 객체의 null 여부를 체크한 후 getName() 를 호출할 것이다.

```java
Insurance insurance = ..;
if (insurance != null && "testCompany".equals(insurance.getName())) {
  System.out.println("OK");
}
```

이 부분을 filter() 를 사용하여 재구현할 수 있다.
```java
Optional<Insurance> optInsurance = ..;
optInsurance.filter(insurance -> "testCompany".equals(insurance.getName()))
        .ifPresent(x -> System.out.println("OK"));
```

`filter()` 메서드는 Predicate 를 인수로 받는다.  
Optional 객체가 값을 가지면서 Predicate 와 일치하면 그 값을 반환하고, 그렇지 않으면 빈 Optional 객체를 반환한다.  
Optional 이 비어있다면 filter() 는 아무 동작도 하지 않고, Optional 에 값이 있으면 그 값에 Predicate 를 적용한다.

---

## 3.7. Optional 클래스의 메서드

|      메서드      |                                                                                               |
|:-------------:|:----------------------------------------------------------------------------------------------|
|    empty()    | - 빈 Optional 인스턴스 반환                                                                          |
|   filter()    | - 값이 존재하며 Predicate 와 일치하면 값을 포함하는 Optional 반환<br />- 값이 없거나 Predicate 와 일치하지 않으면 Optional 반환 |
|   flatMap()   | - 값이 존재하면 인수로 제공된 함수를 적용한 결과 Optional 반환<br />- 값이 없으면 빈 Optional 반환                          |
|     get()     | - 값이 존재하면 Optional 이 감싸고 있는 값 반환<br />- 값이 없으면 NoSuchElementException 발생                      |
|  ifPresent()  | - 값이 존재하면 지정된 Consumer 실행<br />- 값이 없으면 아무 일도 일어나지 않음                                         |
|  isPresent()  | - 값이 존재하면 true, 값이 없으면 false 반환                                                               |
|     map()     | - 값이 존재하면 제공된 매핑 함수 적용                                                                        |
|     of()      | - 값이 존재하면 값을 감싸는 Optional 반환<br />- 값이 null 이면 NPE 발생                                         |
| ofNullable()  | - 값이 존재하면 값을 감싸는 Optional 반환<br />- 값이 null 이면 빈 Optional 반환                                  |
|   orElse()    | - 값이 존재하면 값 반환<br />- 값이 없으면 디폴트값 반환                                                                                             |
|  orElseGet()  | - 값이 존재하면 값 반환<br />- 값이 없으면 Supplier 에서 제공하는 값 반환                                                                                              |
| orElseThrow() | - 값이 존재하면 값 반환<br />- 값이 없으면 Supplier 에서 생성한 예외 발생                                                                                              |

---

# 4. 기본형 특화 Optional

스트림처럼 Optional 도 기본형으로 특화된 `OptionalInt`, `OptionalLong`, `OptionalDouble` 이 있다.  
스트림의 경우 스트림이 많은 요소를 가질 때 기본형 특화 스트림을 이용해서 성능을 향상시킬 수 있지만 Optional 의 최대 요소 수는 한 개이므로
**Optional 에서는 기본형 특화 Optional 로 성능을 개선할 수 없다.**

또한 **기본형 특화 Optional 은 Optional 클래스의 유용한 메서드인 map(), flatMap(), filter() 등을 지원하지 않으므로 기본형 특화 Optional 은 사용하지
않을 것을 권장**한다.

---

# 5. 정리하며..

- 팩토리 메서드 Optional.empty(), Optional.of(), Optional.ofNullable() 등을 이용해서 Optional 객체 생성 가능
- Optional 클래스는 스트림과 비슷한 연산을 수행하는 map(), flatMap(), filter() 등의 메서드 제공
- Optional 을 활용하면 더 좋은 API 설계 가능
  - 사용자는 메서드의 시그니처만 보고도 Optional 값이 사용되거나 반환되는지 예측 가능

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)