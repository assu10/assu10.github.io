---
layout: post
title:  "Java8 - 동작 파라메터화"
date:   2023-05-27
categories: dev
tags: java java8 behavior-parameterization
---

이 포스팅에서는 Java8 에 추가된 기능 중 하나인 동작 파라메터화에 대해 알아본다.  

- 동작 파라메터화
- 익명 클래스
- 람다 표현식
- Comparator, Runnable

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap02) 에 있습니다.

---

**목차**  
- [동작 파라메터화](#1-동작-파라메터화)
- [코드 개선](#2-코드-개선)
  - [동작 파라메터화로 개선](#21-동작-파라메터화로-개선)
  - [익명 클래스로 개선](#22-익명-클래스로-개선)
  - [람다 표현식으로 개선](#23-람다-표현식으로-개선)
  - [리스트 형식으로 추상화하여 개선](#24-리스트-형식으로-추상화하여-개선)
- [Comparator 로 정렬](#3-comparator-로-정렬)
- [Runnable 로 코드 블록 실행](#4-runnable-로-코드-블록-실행)

---

# 1. 동작 파라메터화

동작 파라메터화란 **아직 어떻게 실행할 지 결정하지 않은 코드 블록**을 의미한다.  
이 코드 블록은 나중에 프로그램에서 호출한다.(=코드 블록의 실행이 나중으로 미뤄짐) 
**나중에 실행될 메서드의 인수로 코드 블록을 전달함으로써 코드 블록에 따라 메서드의 동작이 파라메터화**된다.

따라서 동작 파라메터화를 사용하면 자주 변경되는 요구사항에 효과적으로 대응이 가능하다.

동작 파라메터화를 추가하기 위해 부가 코드들이 늘어나는데 이것은 람다 표현식으로 해결이 가능하다.

> 람다 표현식에 대한 자세한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/) 과
> [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](http://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/) 을 참고해주세요.

---

# 2. 코드 개선

[Java8 - Java8 이란?](https://assu10.github.io/dev/2023/05/21/java8-intro/) 의 _2.1. 메서드 레퍼런스: `::`_ 에서 보았던 예시를 다시 보자.  

기존 자바
```java
// 1. 기존 자바에서 red 사과 필터링 시
public static List<Apple> filterRedApples(List<Apple> inventory) {
  List<Apple> result = new ArrayList<>();
  for (Apple apple: inventory) {
    if ("red".equals(apple.getColor())) {
      result.add(apple);
    }
  }
  return result;
}

// 1. 기존 자바에서 100 이상 필터링 시
public static List<Apple> filterWeightApples(List<Apple> inventory) {
  List<Apple> result = new ArrayList<>();
  for (Apple apple: inventory) {
    if (apple.getWeight() >= 100) {
      result.add(apple);
    }
  }
  return result;
}

// 호출 시

// 1. 기존 자바에서 red 사과 필터링 시
List<Apple> redApples = filterRedApples(inventory);
// [Apple{weight=10, color='red'}, Apple{weight=150, color='red'}]
System.out.println(redApples);

// 1. 기존 자바에서 100 이상 필터링 시 (filterRedApples() 와 중복)
List<Apple> weightApples = filterWeightApples(inventory);
// [Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
System.out.println(weightApples);
```

이러한 상황에서 녹색 사과를 필터링하려면 filterRedApples() 과 비슷한 메서드를 만들어야 하기 때문에 변화에 잘 대응할 수 없다.

***<u>비슷한 코드를 구현한 후 추상화하자!</u>***

---

## 2.1. 동작 파라메터화로 개선

인수를 값으로 받아서 boolean 값을 반환하는 Predicate 를 사용해보자.

아래처럼 선택 조건을 결정하는 대표 인터페이스를 정의한 후 해당 인터페이스를 구현하여 다양한 선택 조건을 구현할 수 있다.

```java
// 2. 동작 파라메터화를 위해 선택 조건을 결정하는 인터페이스
public interface ApplePredicate {
  boolean test(Apple apple);
}

// 2. 동작 파라메터화로 red 사과 필터링 시
static class AppleRedColorPredicate implements ApplePredicate {
  @Override
  public boolean test(Apple apple) {
    return "red".equals(apple.getColor());
  }
}

// 2. 동작 파라메터화로 100 이상 필터링 시
static class AppleWeightPredicate implements ApplePredicate {
  @Override
  public boolean test(Apple apple) {
    return apple.getWeight() >= 100;
  }
}
```

위 코드를 보면 ApplePredicate 는 사과 선택 전략을 캡슐화하고 있다.  

이러한 전략을 [전략 디자인 패턴](https://en.wikipedia.org/wiki/Strategy_pattern) 이라고 한다.

> **전략 디자인 패턴**  
> 각 알고리즘(=전략)을 캡슐화하는 알고리즘 패밀리를 정의한 후 런타임에 알고리즘 선택

위에선 ApplePredicate 가 알고리즘 패밀리이고, AppleRedColorPredicate 와 AppleWeightPredicate 가 전략이다.

이제 호출하는 곳에서 ApplePredicate 객체를 받아서 조건을 검사하도록 해보자.  
이 말인 즉슨 **메서드가 다양한 동작(=전략)을 받아서 내부적으로 다양한 동작을 할 수 있다는 의미(=동작 파라메터화)**이다.

```java
// 2. 동작 파라메터화로 사과 필터링
public static List<Apple> filterApples(List<Apple> inventory, ApplePredicate p) {
  List<Apple> result = new ArrayList<>();
  for (Apple apple: inventory) {
    if (p.test(apple)) {  // Predicate 객체로 검사 조건 캡슐화
      result.add(apple);
    }
  }
  return result;
}
```

만일 필터링할 다른 조건이 생긴다면 AppleWeightPredicate() 처럼 ApplePredicate 인터페이스를 구현하는 클래스만 만들면 된다. (=변화에 유연하게 대응!)

호출하는 곳은 아래와 같다.
```java
// 2. 동작 파라메터화로 red 사과 필터링 시
List<Apple> redApples2 = filterApples(inventory, new AppleRedColorPredicate());
// [Apple{weight=10, color='red'}, Apple{weight=150, color='red'}]
System.out.println(redApples2);

// 2. 동작 파라메터화로 100 이상 필터링 시
List<Apple> weightApples2 = filterApples(inventory, new AppleWeightPredicate());
// [Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
System.out.println(weightApples2);
```

위에서 말한 것과 같이 전달된 ApplePredicate 객체에 의해 filterApples() 의 동작이 결정된다. (= 동작 파라메터화)

---

## 2.2. 익명 클래스로 개선

이제 알고리즘 패밀리를 구현하는 전략 클래스를 다시 보자.

```java
static class AppleWeightPredicate implements ApplePredicate {
  @Override
  public boolean test(Apple apple) {
    return apple.getWeight() >= 100;
  }
}
```

메서드는 객체만 인수로 받기 때문에 실제로 필요한 코드는 `return apple.getWeight() >= 100;` 이지만 이 부분을 ApplePredicate 객체로 감싸서 전달하였다.  
위 코드에서 `return apple.getWeight() >= 100;` 를 제외하고는 불필요한 코드이다.

또한 filterApples() 로 새로운 동작을 전달하려면 ApplePredicate 를 구현하는 새로운 클래스를 정의해야 한다.

이제 익명 클래스를 이용해서 여러 개의 ApplePredicate 를 정의하지 않고도 `return apple.getWeight() >= 100;` 를 filterApples() 로 전달해보자.

**익명 클래스는 클래스의 선언과 인스턴스화를 동시에 수행**할 수 있다.

ApplePredicate 인터페이스와 filterApples() 는 위와 동일하게 사용하고, 호출하는 곳만 아래와 같이 바뀐다.
```java
// 3. 익명 클래스로 red 사과 필터링 시
List<Apple> redApples3 = filterApples(inventory, new ApplePredicate() {
  @Override
  public boolean test(Apple apple) {
    return "red".equals(apple.getColor());
  }
});
// [Apple{weight=10, color='red'}, Apple{weight=150, color='red'}]
System.out.println(redApples3);

// 3. 익명 클래스로 100 사과 필터링 시
List<Apple> weightApples3 = filterApples(inventory, new ApplePredicate() {
  @Override
  public boolean test(Apple apple) {
    return apple.getWeight() >= 100;
  }
});
// [Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
System.out.println(weightApples3);
```

익명 클래스를 사용하면 새로운 조건이 들어왔을 때 ApplePredicate 인터페이스를 구현하는 새로운 클래스를 생성할 필요없다.

하지만 결국 객체를 만들고 명시적으로 새로운 동작을 정의하는 메서드를 구현해야 하는 부분은 개선되지 않는다.

---

## 2.3. 람다 표현식으로 개선

위 코드를 람다 표현식으로 개선할 수 있다.

```java
// 4. 람다 표현식으로 red 사과 필터링 시
List<Apple> redApples4 = filterApples(inventory, (Apple apple) -> "red".equals(apple.getColor()));
// [Apple{weight=10, color='red'}, Apple{weight=150, color='red'}]
System.out.println(redApples4);

// 4. 람다 표현식으로 100 사과 필터링 시
List<Apple> weightApples4 = filterApples(inventory, (Apple apple) -> apple.getWeight() >= 100);
// [Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
System.out.println(weightApples4);
```

---

## 2.4. 리스트 형식으로 추상화하여 개선

위의 filterApples() 는 Apple 과 관련한 동작만 수행하는데 Apple 이외에 다양한 곳에서 필터링이 되도록 리스트 형식을 추상화할 수 있다.

```java
// 5. 리스트 추상화
public static <T> List<T> filter(List<T> list, Predicate<T> p) {  // 형식 파라메터 T
  List<T> result = new ArrayList<>();
  for (T e: list) {
    if (p.test(e)) {
      result.add(e);
    }
  }
  return result;
}
```

이제 호출하는 곳에서 리스트의 종류가 Apple 에서 다른 모든 리스트로 확대되었다.
```java
// 5. 리스트 추상화로 red 사과 필터링 시
List<Apple> redApples5 = filter(inventory, (Apple apple) -> "red".equals(apple.getColor()));
// [Apple{weight=10, color='red'}, Apple{weight=150, color='red'}]
System.out.println(redApples5);

// 5. 리스트 추상화로 짝수 필터링 시
List<Integer> numbers = Arrays.asList(10, 11, 12, 13, 14);
List<Integer> evenNumbers = filter(numbers, (Integer i) -> i % 2 == 0);
// [10, 12, 14]
System.out.println(evenNumbers);
```

---

# 3. Comparator 로 정렬

Java8 List 인터페이스에는 sort 메서드가 디폴트 메서드로 정의되어 있다.

List 인터페이스
```java
default void sort(Comparator<? super E> c) {
    Object[] a = this.toArray();
    Arrays.sort(a, (Comparator) c);
    ListIterator<E> i = this.listIterator();
    for (Object e : a) {
        i.next();
        i.set((E) e);
    }
}
```

`Comparator<T>` 인터페이스를 구현해서 sort 메서드의 동작을 파라메터화(=다양화)할 수 있다.

`Comparator<T>` 인터페이스
```java
public interface Comparator<T> {
  int compare(T o1, T o2);
}
```

```java
// 6. Comparator 의 compare() 로 List 의 sort() 동작 파라메터화
// 무게가 큰 순으로 정렬

// [Apple{weight=10, color='red'}, Apple{weight=100, color='green'}, Apple{weight=150, color='red'}]
System.out.println(inventory);

inventory.sort(new Comparator<Apple>() {
  @Override
  public int compare(Apple o1, Apple o2) {
    return o2.getWeight().compareTo(o1.getWeight());
  }
});

// [Apple{weight=150, color='red'}, Apple{weight=100, color='green'}, Apple{weight=10, color='red'}]
System.out.println(inventory);
```

위 코드를 람다 표현식을 사용하면 더 간단히 표현할 수 있다.
```java
inventory.sort((Apple a1, Apple a2) -> a2.getWeight().compareTo(a1.getWeight()));
```

---

# 4. Runnable 로 코드 블록 실행

Runnable 인터페이스를 이용하여 다양한 동작을 스레드로 실행할 수 있다.
```java
// Runnable 로 코드 블록 실행
 Thread t = new Thread(new Runnable() {
   @Override
   public void run() {
     System.out.println("hello~");
   }
 });
```

위 코드를 람다 표현식으로 표현하면 아래와 같다.
```java
Thread t2 = new Thread(() -> System.out.println("hello2~"));
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)
* [전략 디자인 패턴](https://en.wikipedia.org/wiki/Strategy_pattern)