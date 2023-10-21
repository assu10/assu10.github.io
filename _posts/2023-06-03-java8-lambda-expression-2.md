---
layout: post
title:  "Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합"
date:   2023-06-03
categories: dev
tags: java java8 lambda-expression method-reference
---

이 포스팅에서는 Java8 API 에 추가된 인터페이스와 형식 추론과 람다 표현식과 함께 사용하면 좋은 메서드 레퍼런스에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap03) 에 있습니다.

---

**목차**  
- [메서드 레퍼런스](#1-메서드-레퍼런스)
  - [생성자 레퍼런스](#11-생성자-레퍼런스)
- [람다 표현식과 메서드 레퍼런스 활용](#2-람다-표현식과-메서드-레퍼런스-활용)
  - [동작 파라메터화](#21-동작-파라메터화)
  - [익명 클래스 사용](#22-익명-클래스-사용)
  - [람다 표현식 사용](#23-람다-표현식-사용)
  - [메서드 레퍼런스 사용](#24-메서드-레퍼런스-사용)
- [람다 표현식을 조합할 수 있는 메서드](#3-람다-표현식을-조합할-수-있는-메서드)
  - [Comparator 와 조합](#31-comparator-와-조합)
  - [Predicate 와 조합](#32-predicate-와-조합)
  - [Function 과 조합](#33-function-과-조합)
- [정리하며..](#정리하며)

---

# 1. 메서드 레퍼런스

[Java8 - Java8 이란?](https://assu10.github.io/dev/2023/05/21/java8-intro/) 의 _2.1. 메서드 레퍼런스: `::`_ 에서 메서드 레퍼런스에 대해 잠시 살펴보았다.

메서드 레퍼런스는 하나의 메서드를 참조하는 람다를 편리하게 표현할 수 있는 문법으로 `::` 를 사용한다.

메서드 레퍼런스를 사용하면 람다 표현식보다 가독성이 더 좋은 경우가 있다.

> [람다 표현식과 메서드 레퍼런스 활용](#2-람다-표현식과-메서드-레퍼런스-활용) 에서 좀 더 자세한 설명이 있습니다.


아래는 [Java8 - 동작 파라메터화](https://assu10.github.io/dev/2023/05/27/java8-behavior-parameterization/) 의 _3. Comparator 로 정렬_ 에 나왔던 예시이다.

람다 표현식으로 정렬
```java
inventory.sort((Apple a1, Apple a2) -> a2.getWeight().compareTo(a1.getWeight()));
```

위 코드를 메서드 레퍼런스와 java.util.Comparator.comparing 을 활용하면 아래와 같다.
```java
// 메서드 레퍼런스 사용
inventory.sort(comparing(Apple::getWeight));
```

_Apple::getWeight_ 는 Apple 클래스에 정의된 getWeight 의 메서드 레퍼런스이다.  
_Apple::getWeight_ 는 _(Apple a) -> a.getWeight()_ 람다 표현식과 동일하다.

| 람다                                       | 메서드 레퍼런스                          |
|:-----------------------------------------|:----------------------------------|
| () -> Thread.currentThread().dumpStack() | Thread.currentThread()::dumpStack |
| (str, i) -> str.substring(i)             | String::substring                 |
| (String s) -> System.out.println(s)      | System.out::println                 |


---

메서드 레퍼런스는 3 가지 유형으로 구분하여 표현할 수 있다.

- `static 메서드 레퍼런스`
  - class 내부에 존재하는 static 메서드
  - 람다 표현식 `(args) -> ClassName::staticMethod(args)` 를 메서드 레퍼런스로 표현하면 `ClassName:staticMethod`
  - 예) 람다 표현식 Function<String, Integer> stringToInteger = (String s) -> Integer.parseInt(s) 를 메서드 레퍼런스로 표현하면 Function<String, Integer> stringToInteger = Integer::parseInt
- `instance 메서드 레퍼런스`
  - class 내부에 존재하는 일반 함수
  - 람다 표현식 (arg0, rest) -> arg0.instanceMethod(rest) 를 메서드 레퍼런스로 표현하면 ClassName::instanceMethod
  - 예) 람다 표현식 `BiPredicate<List<String>, String> stringList = (list, ele) -> list.contains(ele)` 를 메서드 레퍼런스로 표현하면 `BiPredicate<List<String>, String> stringList2 = List::contains`
- `기존 객체의 instance 메서드 레퍼런스`
  - 외부 객체의 메서드 호출 시 사용
  - 람다 표현식 `(args) -> expr.instanceMethod(args)` 를 메서드 레퍼런스로 표현하면 `expr::instanceMethod`
  - 예) 람다 표현식 () -> testTransaction.getValue() 를 메서드 레퍼런스로 표현하면 testTransaction::getValue


아래는 List 의 문자열을 대소문자 구분없이 정렬 시 람다 표현식과 메서드 레퍼런스를 사용한 예시이다.
```java
List<String> str = Arrays.asList("a", "b", "A", "B");

// List 의 sort 메서드는 인수로 Comparator 기대함
// Comparator 는 (T, T) -> int 라는 함수 디스크립터를 가짐

// 대소문자 구별을 람다 표현식으로
str.sort((s1, s2) -> s1.compareToIgnoreCase(s2)); // String 클래스에 정의된 compareToIgnoreCase 메서드로 람다 표현식 정의
// [a, A, b, B]
System.out.println(str);

// 대소문자 구별을 메서드 레퍼런스로
str.sort(String::compareToIgnoreCase);
// [a, A, b, B]
System.out.println(str);
```

---

## 1.1. 생성자 레퍼런스

생성자 레퍼런스는 `static 메서드 레퍼런스` 를 만드는 방법과 비슷하게 `ClassName::new` 로 만들 수 있다.

### 1.1.1. 생성자 인수가 0개인 경우

인수가 없는 생성자는 Supplier 의 함수 디스크립터(=람다 표현식의 시그니처) 와 같은 `() -> Apple` 의 람다 시그니처를 갖는다.

> Supplier 의 함수 디스크립터는 `() -> T`

> Supplier 함수형 인터페이스의 좀 더 자세한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/) _Supplier 계열 함수형 인터페이스_ 와
> _2.4. 기본형(primitive type) 특화_ 를 참고하세요.

```java
// 생성자 인수가 0개인 경우 - 생성자 레퍼런스 사용
Supplier<Apple> c1 = Apple::new;  // 디폴트 생성자 Apple() 의 생성자 레퍼런스
Apple a1 = c1.get();  // Supplier 의 get() 메서드롤 호출하여 새로운 Apple 객체 생성

// 생성자 인수가 0개인 경우 - 람다 표현식 사용
Supplier<Apple> c2 = () -> new Apple(); // 디폴트 생성자 Apple() 의 람다 표현식
Apple a2 = c2.get();  // Supplier 의 get() 메서드롤 호출하여 새로운 Apple 객체 생성
```

---

### 1.1.2. 생성자 인수가 1개인 경우

Apple(Integer weight) 시그니처를 갖는 생성자는 Function<T,R> 의 함수 디스크립터와 같은 `Integer -> Apple` 의 람다 시그니처를 갖는다.

> Function<T,R> 의 함수 디스크립터는 `T -> R`

> Function 함수형 인터페이스의 좀 더 자세한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/) _2.3. Function<T,R>: R apply(T t)_ 와
> _2.4. 기본형(primitive type) 특화_ 를 참고하세요.

```java
// 생성자 인수가 1개인 경우 - 생성자 레퍼런스 사용
Function<Integer, Apple> c3 = Apple::new; // Apple(Integer weight) 의 생성자 레퍼런스
Apple a3 = c3.apply(10);  // Function 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성

// 생성자 인수가 1개인 경우 - 람다 표현식 사용
Function<Integer, Apple> c4 = (weight) -> new Apple(weight);  // Apple(Integer weight) 의 람다 표현식
Apple a4 = c4.apply(10);  // Function 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성
```

[Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/) 의 _2.3. Function<T,R>: R apply(T t)_ 에서 만들었던 map() 을 이용하면
다양한 무게 리스트를 만들 수 있다.

```java
public static <T, R> List<R> map(List<T> list, Function<T, R> f) {
  List<R> results = new ArrayList<>();
  for (T s: list) {
    // 생성자 레퍼런스를 사용하면 객체의 생성이 delay 됨 (=lazy initialize 가능)
    // 실제 객체는 get() 이나 apply() 같은 메서드가 호출될 때 생성됨
    // factory method pattern 에 유용히 사용
    results.add(f.apply(s));
  }
  return results;
}

// map() 을 이용하여 다양한 무게 리스트 만들기
List<Integer> weights = Arrays.asList(1,5,9,7);
List<Apple> apples = map(weights, Apple::new);  // map() 메서드로 생성자 레퍼런스 전달
```

생성자 레퍼런스를 사용하면 객체의 생성이 delay 되기 때문에 lazy initialize 가 가능하다. 실제 객체는 get() 이나 apply() 같은 메서드가 호출될 때 생성된다. (=factory method pattern 에 유용히 사용 가능)

> **Factory Method Pattern (팩토리 메서드 패턴)**  
> 객체의 생성 코드를 별도의 클래스/메서드로 분리함으로써 객체 생성의 변화에 대비하는데 유용  
> Factory Method 패턴의 좀 더 상세한 내용은 [Java8 - 리팩토링, 디자인 패턴](https://assu10.github.io/dev/2023/07/01/java8-refactoring/#25-%ED%8C%A9%ED%86%A0%EB%A6%AC-%ED%8C%A8%ED%84%B4-factory-pattern) 의 _2.5. 팩토리 패턴 (Factory Pattern)_ 를 참고하세요.

---

### 1.1.3. 생성자 인수가 2개인 경우

Apple(Integer weight, String color) 시그니처를 갖는 생성자는 BiFunction<T,U,R> 의 함수 디스크립터와 같은 `(Integer, String) -> Apple` 의 람다 시그니처를 갖는다.

> BiFunction<T,U,R> 의 함수 디스크립터는 `(T,U) -> R`

> BiFunction 함수형 인터페이스의 좀 더 자세한 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/) _2.4. 기본형(primitive type) 특화_ 를 참고하세요.

```java
// 생성자 인수가 2개인 경우 - 생성자 레퍼런스 사용
BiFunction<Integer, String, Apple> c5 = Apple::new; // Apple(Integer weight, String color) 의 생성자 레퍼런스
Apple a5 = c5.apply(10, "red"); // BiFunction 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성

// 생성자 인수가 2개인 경우 - 람다 표현식 사용
BiFunction<Integer, String, Apple> c6 = (weight, color) -> new Apple(weight, color);  // Apple(Integer weight, String color) 의 람다 표현식
Apple a6 = c6.apply(10, "red"); // BiFunction 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성
```

---

객체를 인스턴스화하지 않고도 생성자에 접근할 수 있는 생성자 레퍼런스는 다양하게 활용되는데 아래처럼 Map 으로 생성자와 문자열을 연관시킬 수 있다.

```java
static Map<String, Function<Integer, Fruit>> map = new HashMap<>();
static {
  map.put("apple", Apple::new);
  map.put("mango", Mango::new);
}

public static Fruit getFruit(String fruit, Integer weight) {
  return map.get(fruit.toLowerCase()) // map 에서 Function<Integer, Fruit> 얻음
          .apply(weight); // Fruit 생성
}
```

```java
Fruit f1 = getFruit("apple", 2);
Fruit f2 = getFruit("mango", 5);

System.out.println(f1); // Apple{weight=2, color='null'}
System.out.println(f2); // Mango{weight=5, color='null'}
```

---

# 2. 람다 표현식과 메서드 레퍼런스 활용

이제 정렬에 대해 코드가 개선되는 과정을 다시 한번 되짚어 본다.

## 2.1. 동작 파라메터화

> [Java8 - 동작 파라메터화](https://assu10.github.io/dev/2023/05/27/java8-behavior-parameterization/#3-comparator-%EB%A1%9C-%EC%A0%95%EB%A0%AC) 의 _3. Comparator 로 정렬_ 에 과정이 있습니다.

List 의 sort() 메서드 시그니처는 아래와 같다.
```java
void sort(Comparator<? super E> c)
```

Comparator 객체를 인수로 받기 때문에 객체 안에 동작을 포함시키는 방식으로 다양한 정렬 전략을 전달할 수 있다. (=sort() 의 동작이 파라메터화됨)  

```java
// 1 - 동작 파라메터화
public static class AppleComparator implements Comparator<Apple> {
  @Override
  public int compare(Apple o1, Apple o2) {
    return o1.getWeight().compareTo(o2.getWeight());
  }
}
```

```java
// 1 - 동작 파라메터화
inventory.sort(new AppleComparator());

// [Apple{weight=10, color='red'}, Apple{weight=100, color='red'}, Apple{weight=150, color='green'}]
System.out.println(inventory);
```

---

## 2.2. 익명 클래스 사용

자주 사용하지 않는 정렬이라면 클래스를 만드는 것보다 익명 클래스를 사용하는 것이 좋다.

```java
// 2 - 익명 클래스
inventory.sort(new Comparator<Apple>() {
  @Override
  public int compare(Apple o1, Apple o2) {
    return o1.getWeight().compareTo(o2.getWeight());
  }
});
```

> [Java8 - 동작 파라메터화](https://assu10.github.io/dev/2023/05/27/java8-behavior-parameterization/#22-%EC%9D%B5%EB%AA%85-%ED%81%B4%EB%9E%98%EC%8A%A4%EB%A1%9C-%EA%B0%9C%EC%84%A0) 의 _2.2. 익명 클래스로 개선_ 과 함께 보면 도움이 됩니다.

---

## 2.3. 람다 표현식 사용

코드가 복잡하므로 람다 표현식으로 간략히 표현한다.  
함수형 인터페이스를 기대하는 곳이면 람다 표현식을 사용할 수 있고, 함수형 인터페이스는 오직 하나의 추상 메서드를 정의하는 인터페이스이다.  
추상 메서드의 시그니처(=함수 디스크립터) 는 람다 표현식의 시그니처를 정의한다.

`Comparator<T>` 함수형 인터페이스의 함수 디스크립터는 `(T,T) -> int` 이다.

```java
int compare(T o1, T o2);
```

```java
// 3 - 람다 표현식 사용
inventory.sort((Apple a1, Apple a2) -> a1.getWeight().compareTo(a2.getWeight()));

// [Apple{weight=10, color='red'}, Apple{weight=100, color='red'}, Apple{weight=150, color='green'}]
System.out.println(inventory);
```

자바 컴파일러는 람다 표현식이 사용된 콘텍스트를 활용하여 람다의 파라메터 형식을 추론하므로 아래처럼 더 간략히 할 수 있다.
```java
inventory.sort((a1, a2) -> a1.getWeight().compareTo(a2.getWeight()));

// [Apple{weight=10, color='red'}, Apple{weight=100, color='red'}, Apple{weight=150, color='green'}]
System.out.println(inventory);
```

`Comparator<T>` 함수형 인터페이스는 Comparable 키를 추출해서 Comparator 객체를 만드는 Function 함수를 인수로 받는 static 메서드인 comparing 을 포함한다.
```java
public static <T, U extends Comparable<? super U>> Comparator<T> comparing(
        Function<? super T, ? extends U> keyExtractor)
{
    Objects.requireNonNull(keyExtractor);
    return (Comparator<T> & Serializable)
        (c1, c2) -> keyExtractor.apply(c1).compareTo(keyExtractor.apply(c2));
}
```

```java
// Comparator<T> 의 comparing() static 메서드 사용
Comparator<Apple> c = Comparator.comparing((Apple a) -> a.getWeight());
inventory.sort(c);
```

위 코드를 좀 더 간략히 표현하면 아래와 같다.
```java
import static java.util.Comparator.comparing;

inventory.sort(comparing((a) -> a.getWeight()));
```

> [Java8 - 동작 파라메터화](https://assu10.github.io/dev/2023/05/27/java8-behavior-parameterization/#23-%EB%9E%8C%EB%8B%A4-%ED%91%9C%ED%98%84%EC%8B%9D%EC%9C%BC%EB%A1%9C-%EA%B0%9C%EC%84%A0) 의 _2.3. 람다 표현식으로 개선_ 과 함께 보면 도움이 됩니다.

---

## 2.4. 메서드 레퍼런스 사용

이제 메서드 레퍼런스를 사용하여 인수를 좀 더 깔끔히 정리해보자.

```java
// 4 - 메서드 레퍼런스
inventory.sort(comparing(Apple::getWeight));

// [Apple{weight=10, color='red'}, Apple{weight=100, color='red'}, Apple{weight=150, color='green'}]
System.out.println(inventory);
```

---

# 3. 람다 표현식을 조합할 수 있는 메서드

Java8 API 의 일부 함수형 인터페이스는 람다 표현식을 조합할 수 있는 유틸리티 메서드를 제공한다. (Comparator, Function, Predicate 등)

간단한 여러 개의 람다 표현식을 조합하여 복잡한 람다 표현식을 만드는 것을 의미하는데 예를 들면 2개의 Predicate 를 조합하여 두 Predicate 의 or 연산을 수행하는 Predicate 를 만들거나
한 함수의 결과가 다른 함수의 입력이 되도록 두 함수를 조합할 수 있다.

함수형 인터페이스의 정의는 오직 하나의 추상 메서드를 지정하는데 이렇게 유틸리티 메서드 제공이 가능한 이유는 바로 디폴트 메서드로 제공하기 때문이다.

> 디폴트 메서드의 간단한 내용은 [Java8 - Java8 이란?](https://assu10.github.io/dev/2023/05/21/java8-intro) 의 _4. 디폴트 메서드: `default`_ 를 참고해주세요.  
> 디폴트 메서드에 대한 자세한 내용은 [Java8 - 디폴트 메서드](https://assu10.github.io/dev/2023/07/15/java8-default-method/) 를 참고하세요.

---

## 3.1. Comparator 와 조합

[2.3. 람다 표현식 사용](#23-람다-표현식-사용) 에서 본 것과 같이 static 메서드인 Comparator.comparing 을 이용해서 비교에 사용할 키를 추출하는 Function 기반의 Comparator 를 반환할 수 있다.

```java
Comparator<Apple> c = Comparator.comparing(Apple::getWeight);
```

---

### Comparator: reversed()

만일 **역정렬**을 하려면 다른 Comparator 인스턴스를 만드는 것이 아니라 `Comparator<T>` 의 디폴트 메서드인 `reversed()` 를 사용하면 된다.
```java
default Comparator<T> reversed() {
    return Collections.reverseOrder(this);
}
```

```java
inventory.sort(comparing(Apple::getWeight).reversed());

// [Apple{weight=150, color='green'}, Apple{weight=10, color='red'}, Apple{weight=10, color='blue'}]
System.out.println(inventory);
```

---

### Comparator: thenComparing()

`thenComparing()` 를 이용하여 첫 번째 비교자가 같을 때 두 번째 비교자에 객체를 전달하여 비교할 수 있다.
```java
default <U extends Comparable<? super U>> Comparator<T> thenComparing(
        Function<? super T, ? extends U> keyExtractor)
{
    return thenComparing(comparing(keyExtractor));
}
```

```java
// 첫 번째 비교자가 같을 경우 두 번째 비교자로 정렬
inventory.sort(comparing(Apple::getWeight)
        .reversed()
        .thenComparing(Apple::getColor)); // 무게가 같으면 색깔로 내림차순 정렬

// [Apple{weight=150, color='green'}, Apple{weight=10, color='blue'}, Apple{weight=10, color='red'}]
System.out.println(inventory);
```

---

## 3.2. Predicate 와 조합

`Predicate<T>` 함수형 인터페이스는 `negate()`, `and()`, `or()` 세 가지 디폴트 메서드를 제공한다.

아래 분홍색인 사과를 선택하는 Predicate 가 있다.
```java
public static <T> Apple filterApple(Apple apple, Predicate<Apple> p) {
  if (p.test(apple)) {
    return apple;
  }
  return null;
}
```

```java
BiFunction<Integer, String, Apple> biFunction = Apple::new;
Apple pinkApple = biFunction.apply(100, "pink");
Apple yellowApple = biFunction.apply(100, "yellow");
Apple blueApple = biFunction.apply(100, "blue");

Predicate<Apple> pinkPredicate = (Apple a) -> "pink".equals(a.getColor());

Apple apple1 = filterApple(pinkApple, pinkPredicate);
Apple apple2 = filterApple(yellowApple, pinkPredicate);

System.out.println(apple1); // Apple{weight=100, color='pink'}
System.out.println(apple2); // null
```

---

### Predicate: negate()

만일 분홍색이 아닌 사과처럼 특정 Predicate 를 반전시킬 때 `negate()` 를 사용한다.
```java
Predicate<Apple> notPinkPredicate = pinkPredicate.negate();

Apple apple3 = filterApple(pinkApple, notPinkPredicate);
Apple apple4 = filterApple(yellowApple, notPinkPredicate);

System.out.println(apple3); // null
System.out.println(apple4); // Apple{weight=100, color='yellow'}
```

---

### Predicate: and()

분홍색이면서 50 이상인 사과를 선택하도록 `and()` 를 통해 람다를 조합할 수 있다.

```java
Predicate<Apple> pinkAndHeavyPredicate = pinkPredicate.and(a -> a.getWeight() > 50);

Apple apple5 = filterApple(pinkApple, pinkAndHeavyPredicate);

// Apple{weight=100, color='pink'}
System.out.println(apple5); // Apple{weight=100, color='pink'}
```

---

### Predicate: or()

분홍색이면서 50 이상이거나 그냥 노란색 사과를 선택하도록 `or()` 를 통해 람다를 조합할 수 있다.

```java
Predicate<Apple> pinkAndHeavyOrYellowPredicate =
        pinkPredicate.and(a -> a.getWeight() > 50)
                     .or(a -> "yellow".equals(a.getColor()));

Apple apple6 = filterApple(pinkApple, pinkAndHeavyOrYellowPredicate);
Apple apple7 = filterApple(yellowApple, pinkAndHeavyOrYellowPredicate);
Apple apple8 = filterApple(blueApple, pinkAndHeavyOrYellowPredicate);

System.out.println(apple6); // Apple{weight=100, color='pink'}
System.out.println(apple7); // Apple{weight=100, color='yellow'}
System.out.println(apple8); // null
```

---

## 3.3. Function 과 조합

`Function<T,R>` 함수형 인터페이스는 `compose()`, `andThen()` 디폴트 메서드를 제공한다.

### Function: andThen()

`andThen()` 은 주어진 함수를 먼저 적용한 결과를 다른 함수의 입력으로 전달하는 함수를 반환한다.

```java
Function<Integer, Integer> f = x -> x+1;
Function<Integer, Integer> g = x -> x*2;

Function<Integer, Integer> h = f.andThen(g);  // g(f(x))

int result = h.apply(1);
System.out.println(result); // 4
```

---

### Function: compose()

`compose()` 는 인수로 주어진 함수를 먼저 실행한 후 그 결과를 외부 함수의 인수로 제공한다.  
f.andThen(g) 에서 andThen 대신 compose 를 사용하면 g(f(x)) 가 아닌 f(g(x)) 가 된다.

```java
Function<Integer, Integer> f = x -> x+1;
Function<Integer, Integer> g = x -> x*2;

Function<Integer, Integer> z = f.compose(g);  // f(g(x))

int result2 = z.apply(1);
System.out.println(result2); // 3
```

---

# 정리하며..

- 람다 표현식은 익명 함수의 일종임, 이름은 없지만 파라메터 리스트/바디/반환 형식을 가지며 예외를 던질 수 있음
- 함수형 인터페이스는 오직 하나의 추상 메서드만을 정의하는 인터페이스
- 함수형 인터페이스를 기대하는 곳에서만 람다 표현식 사용 가능
- java.util.function 패키지는 `Predicate<T>`, `Function<T,R>`, `Supplier<T>`, `Consumer<T>`, `BinaryOperator<T>` 등 자주 사용하는 함수형 인터페이스를 제공함
- Java8 은 `Predicate<T>` 같은 제네릭 함수형 인터페이스와 관련한 박싱 동작을 피할 수 있도록 IntPredicate 등의 기본형 특화 인터페이스를 제공함
- 실행 어라운드 패턴을 람다와 활용하면 유연성과 재사용성을 추가로 얻을 수 있음
- 메서드 레퍼런스를 이용하면 기존의 메서드 구현을 재사용하며, 직접 전달 가능
- `Comparator<T>`, `Predicate<T>`, `Function<T,R>` 과 같은 함수형 인터페이스는 람다 표현식을 조랍할 수 있는 다양한 디폴트 메서드를 제공

---


## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)
* [함수와 메서드의 차이점](https://velog.io/@goyou123/%ED%95%A8%EC%88%98%EC%99%80-%EB%A9%94%EC%86%8C%EB%93%9C%EC%9D%98-%EC%B0%A8%EC%9D%B4%EC%A0%90)
* [함수형 인터페이스](https://velog.io/@donsco/Java-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4)
* [자바 8 표준 API의 함수형 인터페이스 (Consumer, Supplier, Function, Operator, Predicate)](https://hudi.blog/functional-interface-of-standard-api-java-8/)