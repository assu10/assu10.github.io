---
layout: post
title:  "Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사"
date:   2023-05-28
categories: dev
tags: java java8 lambda-expression functional-interface
---

이 포스트에서는 Java8 에 추가된 기능 중 하나인 람다 표현식에 대해 알아본다.  

람다 표현식을 어떻게 만들고 사용하는지와 어떻게 간결한 코드를 만드는 지에 대해 알아본다.  

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap03) 에 있습니다.

---

**목차**  

<!-- TOC -->
* [1. 람다 표현식](#1-람다-표현식)
  * [1.1. 람다 표현식 사용](#11-람다-표현식-사용)
  * [1.2. 함수형 인터페이스 (Functional Interface)](#12-함수형-인터페이스-functional-interface)
  * [1.3. 함수 디스크립터](#13-함수-디스크립터)
  * [1.4. 람다 표현식 활용: 실행 어라운드 패턴](#14-람다-표현식-활용-실행-어라운드-패턴)
* [2. 함수형 인터페이스 사용](#2-함수형-인터페이스-사용)
  * [2.1. Predicate\<T\>: `boolean test(T)`](#21-predicatet-boolean-testt)
  * [2.2. Consumer\<T\>: `void accept(T)`](#22-consumert-void-acceptt)
  * [2.3. Function<T,R>: `R apply(T)`](#23-functiontr-r-applyt)
  * [2.4. 기본형(primitive type) 특화](#24-기본형primitive-type-특화)
* [3. 형식 검사, 형식 추론, 제약](#3-형식-검사-형식-추론-제약)
  * [3.1. 형식 검사](#31-형식-검사)
  * [3.2. 지역 변수 사용과 제약](#32-지역-변수-사용과-제약)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 람다 표현식

람다 표현식은 익명 클래스처럼 이름이 없는 함수이면서 메서드를 인수로 전달할 수 있다. 

> **함수와 메서드**  
> 함수는 독립적으로 존재하며, 특정 작업을 수행하는 코드 조각  
> 메서드는 클래스,구조체,열거형에 포함되어 있는 함수로 클래스 함수라고도 함 (클래스에 대한 객체가 생성되어야 사용이 가능하니까)

람다는 아래와 같은 특징을 갖는다.
- 익명
- 함수
  - 메서드처럼 특정 클래스에 종속되지 않기 때문에 함수라고 부름
  - 하지만 메서드처럼 파라메터 리스트, 바디, 반환형식, 가능한 예외 리스트를 포함함
- 전달
  - 람다 표현식을 메서드 인수로 전달하거나 변수로 저장 가능
- 간결
  - 익명 클래스처럼 자질구레한 코드를 구현할 필요없음

람다 표현식을 사용하면 코드를 훨씬 간결하게 표현할 수 있다.

```java
// 무게가 큰 순으로 정렬
Comparator<Apple> byWeight = new Comparator<Apple>() {
  @Override
  public int compare(Apple o1, Apple o2) {
    return o2.getWeight().compareTo(o1.getWeight());
  }
};
```

```java
Comparator<Apple> byWeight = (Apple o1, Apple o2) -> o2.getWeight().compareTo(o1.getWeight());
```

아래는 Java8 에서 지원하는 람다 표현식 예시이다.

```java
// String 형식의 파라메터 하나를 가지며, int 형 반환
(String s) -> s.length()

// Apple 형식의 파라메터 하나를 가지며, boolean 형 반환
(Apple a) -> a.getWeight() > 100

// int 형식의 파라메터 2개를 가지며, void 리턴
(int a, int b) -> {
  System.out.println("a: " +a); 
  System.out.println("b: " +b); 
}

// 파라메터가 없으며 int 형 반환
() -> 11

// Apple 형식의 파라메터를 2개 가지며 int 형 반환
(Apple a1, Apple a2) -> a1.getWeight().compareTo(a2.getWeight())
```

---

## 1.1. 람다 표현식 사용

람다 표현식은 **함수형 인터페이스라는 문맥에서 사용 가능**하다. 

람다 표현식은 변수에 할당하거나, 함수형 인터페이스를 인수로 받는 메서드로 전달할 수 있으며, 함수형 인터페이스의 추상 메서드와 같은 시그니처를 갖는다.

`Comparator<Apple>` 형식의 변수에 람다 할당한 예시
```java
inventory.sort((Apple a1, Apple a2) -> a2.getWeight().compareTo(a1.getWeight()));
```

`Predicate<T>` 형식을 기대하는 두 번째 인수에 람다 할당한 예시
```java
public static <T> List<T> filter(List<T> list, Predicate<T> p) {  // 형식 파라메터 T
  List<T> result = new ArrayList<>();
  for (T e: list) {
    if (p.test(e)) {
      result.add(e);
    }
  }
  return result;
}

List<Apple> redApples5 = filter(inventory, (Apple apple) -> "red".equals(apple.getColor()));
```

---

## 1.2. 함수형 인터페이스 (Functional Interface)

함수형 인터페이스는 **오직 1개의 추상 메서드를 갖는 인터페이스로 추상 메서드가 하나만 존재한다면 default method, static method 는 여러 개** 있어도 된다.

> 함수형 인터페이스에는 `@FunctionalInterface` 어노테이션이 선언되어 있음

함수형 인터페이스를 사용하는 이유는 Java 의 람다 표현식은 함수형 인터페이스로만 접근이 가능하기 때문이다.

람다 표현식으로 함수형 인터페이스의 추상 메서드 구현을 직접 전달할 수 있기 때문에 전체 표현식을 함수형 인터페이스의 인스턴스로 취급할 수 있다.

함수형 인터페이스는 크게 5가지로 나뉘고, 각 인터페이스는 또 여러 개의 인터페이스로 나뉜다.
- `Predicate<T>`
  - 매개값은 있고, 반환 타입은 boolean 
  - 매개값을 받아 검사한 후 true/false 반환
  - `boolean test(T t)` 추상 메서드 가짐
  - 함수 디스크립터: T -> boolean
- `Consumer<T>`
  - 매개값은 있고, 반환값은 없음
  - 리턴이 되지 않고 함수 내에서 사용 후 끝
  - `void accept(T)` 추상 메서드 가짐
  - 함수 디스크립터: T -> void
- `Function<T,R>`
  - 매개값과 리턴값 있음
  - 주로 매개값을 반환값으로 매핑할 때 (=타입 변환이 목적일 때) 사용
  - `R apply(T)` 추상 메서드 가짐
  - 함수 디스크립터: T -> R
- `Supplier<T>`
  - 매개값은 없고, 반환값은 있음
  - 데이터를 공급해주는 역할
  - `T get()` 추상 메서드 가짐
  - 함수 디스크립터: () -> T
- `Operator`
  - 매개값과 리턴값 있음
  - 주로 매개값을 연산하여 동일한 타입의 결과를 반환할 때 사용
  - 입력을 연산하여 동일 타입의 출력으로 리턴
  - Function 처럼 `T apply(T)` 추상 메서드 가짐

아래는 각각 람다 사용, 익명 클래스 사용, 람다 표현식 직접 전달 의 예시이다.
```java
public static void process(Runnable r) {
  r.run();
}
        
// 람다 사용
Runnable r1 = () -> System.out.println("Runnable 1~");


// 익명 클래스 사용
Runnable r2 = new Runnable() {
  @Override
  public void run() {
    System.out.println("Runnable 2~");
  }
};

process(r1);
process(r2);


// 람다 표현식 직접 전달
process(() -> System.out.println("Runnable 3~"));
```

---

## 1.3. 함수 디스크립터

함수 디스크립터는 람다 표현식의 시그니처를 서술하는 메서드를 말한다. (**람다 표현식의 시그니처 = 함수형 인터페이스의 추상 메서드의 시그니처**)

뒤의 [2.4. 기본형(primitive type) 특화](#24-기본형--primitive-type--특화) 에서 다양한 함수 디스크립터가 나온다.

---

## 1.4. 람다 표현식 활용: 실행 어라운드 패턴

실행 어라운드 패턴은 실제 로직을 처리하는 코드를 초기화/준비 코드와 정리/마무리 코드가 앞 뒤로 둘러싼 형태를 말한다.  
예를 들어 아래와 같은 형태이다.
- 초기화/준비 코드 - 작업 A - 정리/마무리 코드
- 초기화/준비 코드 - 작업 B - 정리/마무리 코드

---

아래는 파일을 한 줄씩 읽는 메서드이다.
```java
// 최초 코드
public static String processFile() throws IOException {
  try (BufferedReader reader =
               new BufferedReader(new FileReader("data.txt"))) {
    return reader.readLine();
  }
}
```

> `try-with-resources` 구문은 직접 찾아보세요.

---

만일 한 번에 한 줄이 아닌 두 줄을 읽게 하는 등 동작을 다양화하려면 위 코드에 동작 파라메터화 적용한다.
processFile() 메서드가 BufferedReader 를 이용해서 다른 동작을 수행할 수 있도록 processFile() 메서드에 동작 전달하는 방식이다.
```java
// 한 번에 두 줄 읽기
String result = processFile((BufferedReader reader) -> reader.readLine() + reader.readLine());
```

---

함수형 인터페이스 자리에 람다를 사용할 수 있으므로 함수형 인터페이스를 이용해서 동작을 전달한다.  
따라서 BufferedReader -> String 과 IOException 을 throw 할 수 있는 시그니처와 일치하는 함수형 인터페이스를 만든다.

```java
// 함수형 인터페이스 생성
@FunctionalInterface
public interface BufferedReaderProcess {
  String process(BufferedReader b) throws IOException;
}
```

이제 위에서 정의한 인터페이스를 processFile() 메서드의 인수로 전달할 수 있다.  
BufferedReaderProcess 함수형 인터페이스에 정의된 process 메서드의 시그니처 `BufferReader -> String` 와 일치하는 람다를 전달할 수 있다.
```java
public static String processFile(BufferedReaderProcess b) throws IOException {
  try (BufferedReader reader =
          new BufferedReader(new FileReader("data.txt"))) {
    return b.process(reader);
  }
}
```

---

이제 람다를 통해 다양한 동작을 processFile() 로 전달할 수 있다.

```java
String result1 = processFile();

String oneLine = processFile((BufferedReader reader) -> reader.readLine());
String twoLine = processFile((BufferedReader reader) -> reader.readLine() + reader.readLine());
```

---

# 2. 함수형 인터페이스 사용

위에서 본 것처럼 **함수형 인터페이스는 오직 하나의 추상 메서드를 지정**하고, **함수형 인터페이스의 추상 메서드는 람다 표현식의 시그니처**를 묘사한다.
**함수형 인터페이스의 추상 메서드 시그니처를 함수 디스크립터**라고 한다.

---

## 2.1. Predicate\<T\>: `boolean test(T)`
Predicate 는 논리 판단을 해주는 함수형 인터페이스이다.  
`java.util.function.Predicate<T>` 인터페이스는 `boolean test(T t)` 추상 메서드를 가지며, `test()` 의 시그니처는 아래와 같다.

Predicate 함수형 인터페이스 시그니처
```java
@FunctionalInterface
public interface Predicate<T> {
  boolean test(T t);
}
```

**Predicate 계열 함수형 인터페이스**

| 인터페이스            | 메서드                        |
|:-----------------|:---------------------------|
| Predicate\<T\>  | boolean test(T t)          |
| BiPredicate<T,U> | boolean test(T t, U u)     |
| IntPredicate     | boolean test(int value)    |
| LongPredicate    | boolean test(long value)   |
| DoublePredicate  | boolean test(double value) |


> Predicate 의 `and`, `or`, `negate` 등의 디폴트 메서드의 좀 더 자세한 내용은 [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](https://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/#32-predicate-%EC%99%80-%EC%A1%B0%ED%95%A9) 의
> _3.2. Predicate 와 조합_ 을 참고해주세요.

```java
public static <T> List<T> filter(List<T> list, Predicate<T> p) {
  List<T> results = new ArrayList<>();
  for (T t: list) {
    if (p.test(t)) {
      results.add(t);
    }
  }
  return results;
}

String[] strings = {"a", "", "b"};
List<String> listOfStrings = Arrays.asList(strings);

Predicate<String> nonEmptyStringPredicate = (String s) -> !s.isEmpty();
List<String> nonEmptyStrings = filter(listOfStrings, nonEmptyStringPredicate);

// [a, b]
System.out.println(nonEmptyStrings);
```

---

## 2.2. Consumer\<T\>: `void accept(T)`
Consumer 는 입력을 받아서 함수 내에서 사용 후 별도로 리턴하지 않는다.  
`java.util.function.Consumer<T>` 인터페이스는 `void accept(T)` 추상 메서드를 가지며, `accept()` 의 시그니처는 아래와 같다.

Consumer 함수형 인터페이스 시그니처
```java
public interface Consumer<T> {
  void accept(T t);
}
```

**Consumer 계열 함수형 인터페이스**

| 인터페이스             | 메서드                           |
|:------------------|:-------------------------------|
| Consumer\<T\>     | void accept(T t)               |
| BiConsumer<T,U>   | void accept(T t, U u)          |
| IntConsumer       | void accept(int value)         |
| LongConsumer      | void accept(long value)        |
| DoubleConsumer    | void accept(double value)      |
| ObjIntConsumer    | void accept(T t, int value)    |
| ObjLongConsumer   | void accept(T t, long value)   |
| ObjDoubleConsumer | void accept(T t, double value) |

리스트를 받아서 출력(소비)하는 예시
```java
public static <T> void forEach(List<T> list, Consumer<T> c) {
  for (T t: list) {
    c.accept(t);
  }
}

// a
//
//b
forEach(listOfStrings, (String s) -> System.out.println(s));
```

---

## 2.3. Function<T,R>: `R apply(T)`
Function 은 입력과 출력을 연결하는 함수형 인터페이스이다. (예 - 무게를 도출하거나 문자열을 길이와 매핑)  
java.util.function.Function<T,R> 인터페이스는 제네릭 형식 T 를 입력받아서 제네릭 형식 R 객체를 반환하는 `R apply(T t)` 추상 메서드를 가지며, 
`apply()` 의 시그니처는 아래와 같다.

Function 함수형 인터페이스 시그니처
```java
public interface Function<T, R> {
  R apply(T t);
}
```
**Function 계열 함수형 인터페이스**

| 인터페이스               | 메서드                  |
|:--------------------|:---------------------|
| Function<T,R>       | R apply(T t)         |
| BiFunction<T,U,R>   | R apply(T t, U u)    |
| PFunction           | R apply(p value)     |
| PtoQFunction        | q applyAsQ(p value)  |
| toPFunction         | p applyAsP(T t)      |
| toPBiFunction       | p applyAsP(T t, U u) |

> P, Q, p, q 는 기본자료형

- 참조형(reference type): Integer, Boolean, String, Byte, Object, List...
- 기본형(primitive type): boolean, char, byte, short, int, long, float, double


String list 를 인수로 받아서 String 길이를 포함하는 Integer 리스트로 변환하는 map 이라는 메서드 정의
```java
public static <T, R> List<R> map(List<T> list, Function<T, R> f) {
  List<R> results = new ArrayList<>();
  for (T s: list) {
    results.add(f.apply(s));
  }
  return results;
}

List<Integer> stringLengths = map(Arrays.asList("abcde", "", "ddd"),
                                  (String s) -> s.length());

// [5, 0, 3]
System.out.println(stringLengths);
```

---

**Supplier 계열 함수형 인터페이스**

| 인터페이스           | 메서드                    |
|:----------------|:-----------------------|
| Supplier\<T\>   | T get()                |
| BooleanSupplier | boolean getAsBoolean() |
| IntSupplier     | int getAsInt()         |
| LongSupplier    | long getAsLong()       |
| DoubleSupplier  | double getAsDouble()   |

**Operator 계열 함수형 인터페이스**

| 인터페이스                | 메서드                                                |
|:---------------------|:---------------------------------------------------|
| UnaryOperator        | T apply(T t)                                       |
| BinaryOperator\<T\>  | T apply(T t1, T t2)                                |
| IntUnaryOperator     | int applyAsInt(int value)                          |
| LongUnaryOperator    | long applyAsLong(long value)                       |
| DoubleUnaryOperator  | double applyAsDouble(double value)                 |
| IntBinaryOperator    | int applyAsInt(int value1, int value2)             |
| LongBinaryOperator   | Long applyAsLong(long value1, long value2)         |
| DoubleBinaryOperator | double applyAsDouble(double value1, double value2) |

---

## 2.4. 기본형(primitive type) 특화

**제네릭 파라미터(`<T>` 에서 `T`) 는 참조형만 사용이 가능**하다.

<**기본형과 참조형**>
- **기본형(primitive type)**
  - boolean, char, byte, short, int, long, float, double
  - `int n = 1;`
  - 실제 값을 저장
  - 산술 연산 가능
  - null 로 초기화 불가
  - stack 에 실제 값 저장
  - 매개 변수로 사용 시 변수의 실제 값만 가져오는 것이기 때문에 **읽기만 가능**
- **참조형(reference type)**
  - Integer, Boolean, String, Byte, Object, List...(기본형 8개를 제외한 모든 타입)
  - `Integer n = new Integer(1);`
  - 어떤 값이 저장되어 있는 주소를 값으로 가짐
  - 산술 연산 불가
  - null 로 초기화 가능 (DB 와 연동 시 DTO 객체에 null 이 필요한 경우 사용 가능)
  - heap 에 실제 값을 저장하고, 해당 주소를 stack 에 저장
  - 매개 변수로 사용 시 변수의 값을 **읽고 변경 가능**

기본형을 사용하는 것이 메모리나 속도 측면에서 유리하지만 아래와 같은 경우는 참조형 변수를 사용한다.
- DB 와 연동되는 데이터나 null 값이 들어가는 변수일 경우
- 여러 메서드를 거치면서 값이 변할 수 있는 경우

---

<**boxing 과 unboxing**>
- `boxing`
  - 기본형을 참조형으로 변환
- `unboxing`
  - 참조형을 기본형으로 변환
- `auto-boxing`
  - 박싱과 언박싱이 자동으로 이루어짐

아래는 기본형 int 가 참조형 Integer 로 boxing(오토)되는 예시이다.
```java
List<Integer> list = new ArrayList<>();
for (int i=0; i<10; i++) {
  list.add(i);
}
```

즉, 이렇게 함수형 인터페이스는 제네릭을 사용하기 때문에 primitive type 사용이 불가하여 primitive type 을 사용하게 되면 auto boxing 이 이 수행되는데
다량의 배치 작업 시 auto-boxing 으로 인한 오버 헤드가 발생한다.

이러한 오버 헤드를 없애기 위해 Java8 에서는 primitive type 을 입출력으로 사용하는 상황에서 auto-boxing 을 피할 수 있도록 primitive type 에 특화된
함수형 인터페이스를 제공한다.

```java
IntPredicate evenNumbers = (int i) -> i % 2 == 0;
// primitive type(2) 을 reference type 으로 변환하는 boxing 없음
System.out.println(evenNumbers.test(2));  // true

Predicate<Integer> evenNumbers2 = (Integer i) -> i % 2 == 0;
// primitive type(2) 을 reference type 으로 변환하는 boxing 발생
System.out.println(evenNumbers2.test(2)); // true
```

| 함수형 인터페이스         | 함수 디스크립터 (=람다 표현식의 시그니처) | 기본형 특화                                                                                                                                                                                                                                                                    |
|:------------------|:------------------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Predicate<T>`      |       T -> boolean       | - `IntPredicate`<br />- `LongPredicate`<br />- `DoublePredicate`                                                                                                                                                                                                          |
| `Consumer<T>`       |        T -> void         | - `IntConsumer`<br />- `LongConsumer`<br />- `DoubleConsumer`                                                                                                                                                                                                             |
| `Function<T,R>`     |          T -> R          | - `IntFunction<R>`<br />- `IntToDoubleFunction`<br />- `IntToLongFunction`<br />- `LongFunction<R>`<br />- `LongToDoubleFunction`<br />- `LongToIntFunction`<br />- `DoubleFunction<R>`<br />- `ToIntFunction<T>`<br />- `ToDoubleFunction<T>`<br />- `ToLongFunction<T>` |
| `Supplier<T>`       |         () -> T          | - `BooleanSupplier`<br />- `IntSupplier`<br />- `LongSupplier`<br />- `DoubleSupplier`                                                                                                                                                                                    |
| `UnaryOperator<T>`  |          T -> T          | - `IntUnaryOperator`<br />- `LongUnaryOperator`<br />- `DoubleUnaryOperator`                                                                                                                                                                                              |
| `BinaryOperator<T>` |        (T,T) -> T        | - `IntBinaryOperator`<br />- `LongBinaryOperator`<br />- `DoubleBinaryOperator`                                                                                                                                                                                           |                                                                                                                                                                     
| `BiPredicate<T,U>` |     (T,U) -> boolean     |                                                                                                                                                                                                                                                                           |
| `BiConsumer<T,U>` |      (T,U) -> void       | - `ObjIntConsumer<T>`<br />- `ObjLongConsumer<T>`<br />- `ObjDoubleConsumer<T>`                                                                                                                                                                                           |
| `BiFunction<T,U,R>` |        (T,U) -> R        | - `ToIntBiFunction<T,U>`<br />- `ToLongBiFunction<T,U>`<br />- `ToDoubleBiFunction<T,U>`                                                                                                                                                                                  |


아래는 람다 표현식을 사용할 수 있는 사용 예시이다.

|   사용 예시    | 람다 예시                                                        | 사용 가능한 함수형 인터페이스                                           |
|:----------:|:-------------------------------------------------------------|:-----------------------------------------------------------|
| boolean 표현 | (List\<String\> list) -> list.isEmpty()                      | `Predicate<List<String>>`                                    |
|   객체 생성    | () -> new Car("red")                                         | `Supplier<Car>`                                              |
|  객체에서 소비   | (Car a) -> System.out.println(a.getName())                   | `Consumer<Car>`                                              |
| 객체에서 선택/추출 | (String s) -> s.length()                                     | `Function<String, Integer>` 혹은 `ToIntFunction<String>`         |
|  두 값을 조합   | (int a, int b) -> a * b                                      | `IntBinaryOperator`                                          |
|  두 객체를 비교  | (Car a1, Car a2) -> c1.getWeight().compareTo(c2.getWeight()) | `BiFunction<Car, Car, Integer>` 혹은 `ToIntBiFunction<Car, Car>` |


---
함수형 인터페이스는 확인된 예외를 던지는 동작을 허용하지 않기 때문에 **예외를 던지는 람다 표현식을 만들려면 확인된 예외를 선언하는 함수형 인터페이스를 직접 정의하거나 람다를 try/catch 블록으로 감싸야 한다.**

아래는 [1.4. 람다 표현식 활용: 실행 어라운드 패턴](#14-람다-표현식-활용--실행-어라운드-패턴) 에서 예외를 던지는 함수형 인터페이스를 직접 정의한 예시이다.

```java
// 함수형 인터페이스 생성
@FunctionalInterface
public interface BufferedReaderProcess {
  String process(BufferedReader b) throws IOException;
}

String result = processFile((BufferedReader reader) -> reader.readLine() + reader.readLine());
```

만일 Function<T,R> 처럼 이미 정의된 함수형 인터페이스를 사용하고 있어서 직접 함수형 인터페이스를 만들기 어려우면 아래처럼 try/catch 문으로 감싸서 확인된 예외를 잡을 수 있다.
```java
Function<BufferedReader, String> f = 
        (BufferedReader b) -> {
          try {
            return b.readLine();  
          } catch (IOException e) {
            throw new RuntimeException(e);
          }
        }
```

---

# 3. 형식 검사, 형식 추론, 제약

## 3.1. 형식 검사

어떤 context(람다가 전달될 메서드 파라메터나 람다가 할당되는 변수 등) 에서 기대되는 람다 표현식의 형식을 **대상 형식**이라고 한다. 대상 형식은 함수형 인터페이스이어야 한다.

아래와 같은 람다 표현식을 사용할 때 컴파일러는 아래와 같은 순서로 람다 표현식의 유효성을 확인한다.

람다 표현식 사용
```java
List<Apple> redApples = filter(inventory, (Apple apple) -> "red".equals(apple.getColor()));
```

filter() 메서드 선언
```java
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

- filter() 메서드의 선언 확인
- filter() 는 두 번째 파라메터로 `Predicate<T>` 형식(=대상 형식) 을 기대함
- `Predicate<T>` 는 boolean test() 라는 한 개의 추상 메서드를 정의하는 함수형 인터페이스
- test() 는 T 를 받아 boolean 을 반환하는 함수 디스크립터 묘사(T -> boolean)
- filter() 메서드로 전달된 람다 표현식은 T -> boolean 을 만족해야 함


---

**람다 body 에 일반 표현식이 있으면 void 를 반환하는 함수 디스크립터와 호환**된다.  
예를 들면 boolean 을 반환하는 List 의 add() 메서드는 Consumer context (T -> void) 에서 void 대신 boolean 을 반환하지만 유효하다.

```java
Predicate<String> p = s -> listOfStrings.add(s);  // 유효함
Consumer<String> b = s -> listOfStrings.add(s); // 유효함
```

위 코드에서 람다 표현식의 context 는 `Predicate<String>` (대상 형식) 이다. (= 함수형 인터페이스)

---

## 3.2. 지역 변수 사용과 제약

바로 위 코드 람다 표현식은 인수를 람다 자신의 body 안에서만 사용했지만, 람다 표현식 사용 시 익명 함수가 하는 것처럼 자유 변수(파라메터로 넘겨진 변수가 아닌 외부에 정의된 변수)를
활용할 수 있다. 이를 **람다 캡처링** 이라고 한다.

람다는 인스턴수 변수와 정적 변수를 자유롭게 캡처(=자신의 body 에서 참조)할 수 있지만 그러기 위해서 지역 변수는 명시적으로 final 이 선언되어 있거나 final 처럼 한 번만 값 할당이 되어야 한다.  
즉, 람다 표현식은 한 번만 할당할 수 있는 지역 변수를 캡처할 수 있다.

유효한 코드
```java
int a = 1;
Runnable r4 = () -> System.out.println(a);
```

오류, Variable used in lambda expression should be final or effectively final 발생
```java
int a = 1;
Runnable r4 = () -> System.out.println(a);  // 오류, Variable used in lambda expression should be final or effectively final
a = 2;
```

인스턴스 변수는 Heap 에 저장되는 반면 지역 변수는 Stack 에 저장된다. 따라서 자신을 정의한 스레드와 생존을 같이 해야하므로 지역 변수는 final 이어야 한다.

람다가 지역 변수에 접근하는 상황에서 람다가 스레드에서 실행된다면 변수를 할당한 스레드가 사라져서 변수 할당이 해제되었음에도 불구하고 람다를 실행하는 스레드에서는 해당 변수에 접근하려 할 수 있다.
따라서 람다는 원래 변수에 접근하는 것이 아니라 자유 지역 변수의 복사본에 접근하게 된다.  
그렇기 때문에 복사본의 값이 바뀌면 안되므로 지역 변수에는 한 번만 값을 할당해야 한다는 제약이 생긴다.


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)
* [함수와 메서드의 차이점](https://velog.io/@goyou123/%ED%95%A8%EC%88%98%EC%99%80-%EB%A9%94%EC%86%8C%EB%93%9C%EC%9D%98-%EC%B0%A8%EC%9D%B4%EC%A0%90)
* [함수형 인터페이스](https://velog.io/@donsco/Java-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4)
* [표준 함수형 인터페이스](https://velog.io/@im_joonchul/%ED%91%9C%EC%A4%80-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4)
* [자바 8 표준 API의 함수형 인터페이스 (Consumer, Supplier, Function, Operator, Predicate)](https://hudi.blog/functional-interface-of-standard-api-java-8/)
* [기본형 변수와 참조형 변수](https://velog.io/@yh20studio/Java-%EA%B8%B0%EB%B3%B8%ED%98%95-%EB%B3%80%EC%88%98%EC%99%80-%EC%B0%B8%EC%A1%B0%ED%98%95-%EB%B3%80%EC%88%98)