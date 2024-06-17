---
layout: post
title:  "Java - Java 8 ~ Java 17"
date:   2023-07-30
categories: dev
tags: java java-version
---

이 포스트에서는 Java 8~17 의 주요 변경점에 대해 알아본다.

<!-- TOC -->
* [Java 8](#java-8)
  * [인터페이스에 디폴트 메서드와 정적 메서드 포함 가능](#인터페이스에-디폴트-메서드와-정적-메서드-포함-가능)
  * [함수형 인터페이스](#함수형-인터페이스)
  * [람다 표현식](#람다-표현식)
  * [메서드 레퍼런스](#메서드-레퍼런스)
    * [정적 메서드 레퍼런스](#정적-메서드-레퍼런스)
    * [인스턴스 메서드 레퍼런스](#인스턴스-메서드-레퍼런스)
    * [기존 객체의 인스턴스 메서드 레퍼런스](#기존-객체의-인스턴스-메서드-레퍼런스)
    * [생성자 레퍼런스](#생성자-레퍼런스)
  * [스트림 API](#스트림-api)
  * [Date and Time API](#date-and-time-api)
  * [Optional](#optional)
  * [배열 정렬 시 병렬 처리](#배열-정렬-시-병렬-처리)
* [Java 9](#java-9)
  * [모듈화 (`jigsaw`)](#모듈화-jigsaw)
  * [Stream 에 새로운 메서드 추가](#stream-에-새로운-메서드-추가)
  * [Optional 개선](#optional-개선)
  * [인터페이스에 Private 메서드 추가](#인터페이스에-private-메서드-추가)
  * [불변 컬렉션 생성 메서드 제공](#불변-컬렉션-생성-메서드-제공)
  * [`try-with-resources` 개선](#try-with-resources-개선)
  * [Reactive Stream: Flow API 추가](#reactive-stream-flow-api-추가)
  * [CompletableFuture API 개선](#completablefuture-api-개선)
  * [JShell](#jshell)
* [Java 10](#java-10)
  * [`var` 예약어](#var-예약어)
* [Java 11](#java-11)
  * [String 클래스에 새로운 메서드 추가](#string-클래스에-새로운-메서드-추가)
  * [java.nio.file.Files 클래스에 새로운 메서드 추가](#javaniofilefiles-클래스에-새로운-메서드-추가)
  * [컬렉션 인터페이스에 새로운 메서드 추가](#컬렉션-인터페이스에-새로운-메서드-추가)
  * [Predicate 인터페이스에 새로운 메서드 추가](#predicate-인터페이스에-새로운-메서드-추가)
  * [람다에서 로컬 변수 `var` 사용 가능](#람다에서-로컬-변수-var-사용-가능)
  * [자바 파일 실행](#자바-파일-실행)
* [Java 12](#java-12)
  * [Switch 확장](#switch-확장)
* [Java 13](#java-13)
  * [Switch 표현식 (preview)](#switch-표현식-preview)
* [Java 14](#java-14)
  * [Switch 표현식 표준화](#switch-표현식-표준화)
  * [`record` 선언 기능 추가 (preview)](#record-선언-기능-추가-preview)
  * [Pattern matching for `instanceof()` (preview)](#pattern-matching-for-instanceof-preview)
  * [Text Blocks (second preview)](#text-blocks-second-preview)
* [Java 15](#java-15)
  * [Text Blocks 도입](#text-blocks-도입)
  * [Sealed Classes (preview)](#sealed-classes-preview)
* [Java 17](#java-17)
  * [Sealed Classes (finalized)](#sealed-classes-finalized)
  * [Deprecating the security manager](#deprecating-the-security-manager)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# Java 8

## 인터페이스에 디폴트 메서드와 정적 메서드 포함 가능

```java
interface TestInterface {
    default String test1() {
        return "test";
    }
    static String test2() {
        return "test2";
    }
}
```

디폴트 메서드는 구현 클래스에서 재정의 가능하지만, 정적 메서드는 구현 클래스에서 재정의 불가

> [Java8 - 디폴트 메서드](https://assu10.github.io/dev/2023/07/15/java8-default-method/)

---

## 함수형 인터페이스

```java
@FunctionalInterface
public interface BufferedReaderProcess {
  String process(BufferedReader b) throws IOException;
}
```

하나의 추상 메서드를 정의하는 인터페이스  
추상 메서드 외 디폴트 메서드가 정적 메서드는 제한없이 사용 가능  
주요 함수형 인터페이스는 Predicate, Consumer, Supplier, Function, UnaryOperator 등이 있음  

> [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94)

---

## 람다 표현식

정렬 - 일반
```java
// 무게가 큰 순으로 정렬
Comparator<Apple> byWeight = new Comparator<Apple>() {
  @Override
  public int compare(Apple o1, Apple o2) {
    return o2.getWeight().compareTo(o1.getWeight());
  }
};
```

정렬 - 람다식
```java
Comparator<Apple> byWeight = (Apple o1, Apple o2) -> o2.getWeight().compareTo(o1.getWeight());
```

```java
// 외부 반복
for (String value: myCollection) { 
    System.out.println(value); 
}

// 내부 반복
myCollection.forEach(value -> System.out.println(value));
```

익명 클래스처럼 이름이 없는 함수이면서 메서드를 인수로 전달하거나 메서드의 결과로 반환될 수 있음  
즉, 함수를 변수로 다를 수 있음  
메서드를 식으로 나타낸 것이지만 엄밀히 말하면 이 메서드를 가진 객체를 생성해내는 것이므로 주로 함수형 인터페이스의 익명 객체를 대체하기 위해 사용함  
간결하고 직관적인 코드 생성 가능

> [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/)  
> [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](https://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/)

---

## 메서드 레퍼런스

람다식을 좀 더 간결하게 사용하는 것

메서드 참조에는 4가지 방법이 있음

### 정적 메서드 레퍼런스
`ClassName::staticMethod` 으로 사용  

람다식 사용 시
```java
boolean isUser = list.stream().anyMatch(user -> User.isUser(user));
```

메서드 레퍼런스 사용 시
```java
boolean isUser = list.stream.anyMatch(User::isUser);
```
 
### 인스턴스 메서드 레퍼런스

`ClassName::instanceMethod` 으로 사용  
String, BigDecimal 등의 인스턴스 메서드에 대해 사용

```java
BiPredicate<List<String>, String> stringList = (list, ele) -> list.contains(ele);
```

```java
BiPredicate<List<String>, String> stringList = List::contains;
```


### 기존 객체의 인스턴스 메서드 레퍼런스

`ClassName::instanceMethod` 으로 사용

```java
User user = new User();
boolean isFirstName = list.stream().anyMatch(user::isFirstName());
```

### 생성자 레퍼런스

`ClassName::new`

**생성자 인수가 0개인 경우**

람다식
```java
Supplier<Apple> c2 = () -> new Apple(); // 디폴트 생성자 Apple() 의 람다 표현식
        Apple a2 = c2.get();  // Supplier 의 get() 메서드롤 호출하여 새로운 Apple 객체 생성
```

생성자 레퍼런스
```java
Supplier<Apple> c1 = Apple::new;  // 디폴트 생성자 Apple() 의 생성자 레퍼런스
        Apple a1 = c1.get();  // Supplier 의 get() 메서드롤 호출하여 새로운 Apple 객체 생성
```

**생성자 인수가 1개인 경우**

람다식
```java
Function<Integer, Apple> c4 = (weight) -> new Apple(weight);  // Apple(Integer weight) 의 람다 표현식
        Apple a4 = c4.apply(10);  // Function 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성
```

**생성자 레퍼런스**
```java
Function<Integer, Apple> c3 = Apple::new; // Apple(Integer weight) 의 생성자 레퍼런스
Apple a3 = c3.apply(10);  // Function 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성
```

**생성자 인수가 2개인 경우**

람다식
```java
BiFunction<Integer, String, Apple> c6 = (weight, color) -> new Apple(weight, color);  // Apple(Integer weight, String color) 의 람다 표현식
Apple a6 = c6.apply(10, "red"); // BiFunction 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성
```

생성자 레퍼런스
```java
BiFunction<Integer, String, Apple> c5 = Apple::new; // Apple(Integer weight, String color) 의 생성자 레퍼런스
Apple a5 = c5.apply(10, "red"); // BiFunction 의 apply() 메서드롤 호출하여 새로운 Apple 객체 생성
```

> [Java8 - 람다 표현식 (2): 메서드 레퍼런스, 람다 표현식과 메서드의 조합](https://assu10.github.io/dev/2023/06/03/java8-lambda-expression-2/#1-%EB%A9%94%EC%84%9C%EB%93%9C-%EB%A0%88%ED%8D%BC%EB%9F%B0%EC%8A%A4)

---

## 스트림 API

컬렉션의 저장 요소를 하나씩 참조해서 람다식으로 처리할 수 있도록 해주는 내부 반복자

- 조립 가능, 병렬화 있음
- 자바 컬렉션은 외부 반복, 스트림은 내부 반복 사용
- 중간 연산은 파이프라인으로 구성되어 최종 연산에서 한번에 처리됨, 이를 지연 계산된다고 함
- 중간 연산은 Stream 을 반환하고, 최종 연산은 스트림이 아닌 결과를 반환
- 중간 연산의 예시로는 map(), filter(), flatMap 이 있고, 최종 연산의 예시로는 count(), foreach(), collect() 가 있음

컬렉션은 데이터를 어떻게 저장/관리/접근하는지가 목표이지만,  
스트림은 데이터를 직접 접근/조작하는 기능 제공은 하지 않고, 어떻게 계산할지를 목표로 함

> [Java8 - Stream](https://assu10.github.io/dev/2023/06/04/java8-stream-1/)  
> [Java8 - Stream 활용 (1): 필터링, 슬라이싱, 매핑, 검색, 매칭](https://assu10.github.io/dev/2023/06/06/java8-stream-2/)  
> [Java8 - Stream 활용 (2): 리듀싱, 숫자형 스트림, 스트림 생성](https://assu10.github.io/dev/2023/06/10/java8-stream-2-1/)  
> [Java8 - Stream 으로 데이터 수집 (1): Collectors 클래스, Reducing 과 Summary, Grouping](https://assu10.github.io/dev/2023/06/17/java8-stream-3-1/)  
> [Java8 - Stream 으로 데이터 수집 (2): Partitioning, Collector 인터페이스, Custom Collector](https://assu10.github.io/dev/2023/06/18/java8-stream-3-2/)  
> [Java8 - Stream 으로 병렬 데이터 처리 (1): 병렬 스트림, 포크/조인 프레임워크](https://assu10.github.io/dev/2023/06/24/java8-parallel-stream-1/)  
> [Java8 - Stream 으로 병렬 데이터 처리 (2): Spliterator 인터페이스](https://assu10.github.io/dev/2023/06/25/java8-parallel-stream-2/)  

---

## Date and Time API

기존의 Date, Calendar, DateFormat, TimeZone 을 LocalDate, LocalTime, LocalDateTime, DateTimeFormat, ZoneId 등이 대체  
기존보다 훨씬 쉽게 날짜 로직 작성 가능

기존
```java
// 오늘 날짜 구하기
Calendar cal = Calendar.getInstance();
String format = "yyyy-MM-dd";
SimpleDateFormat sdf = new SimpleDateFormat(format);
String date = sdf.format(cal.getTime());
```

Java 8
```java
// 오늘 날짜 rngkrl
LocalDate today = LocalDate.now();
```

> [Java8 - 날짜와 시간](https://assu10.github.io/dev/2023/07/29/java8-datetime/)

---

## Optional

Optional 을 통해 null 에 대한 참조를 안전하게 할 수 있음

기존
```java
public String logic() {
    User user = getUser();
    if (user != null) {
        Address address = user.getAddress();
        if (address != null) {
            String street = address.getStreet();
            if (street != null) {
                return street;
            }
        }
    }
    return "not specified";
}
```

Optional
```java
public String logic() {
    Optional<User> user = Optional.ofNullable(getUser());
    String result = user
      .map(User::getAddress)
      .map(Address::getStreet)
      .orElse("not specified");
    return result;
}
```


> [Java8 - Optional 클래스](https://assu10.github.io/dev/2023/07/16/java8-optional/)

---

## 배열 정렬 시 병렬 처리

기존엔 Arrays.sort() 로 배열을 정렬했는데 이 메서드는 정렬이 순차적으로 실행됨  
Java 8 부터는 Arrays.parallelSort() 를 통해 병렬적으로 배열 정렬 가능

---

# Java 9

## 모듈화 (`jigsaw`)

기존의 jar 패키징으로 모듈화를 진행하지만 jar 에는 문제점이 있음  
Jar Hell 이 있는데 복잡한 ClassLoader 로 정의되었을 때 JVM 컴파일은 성공하지만 런타임 때 ClassNotFoundExeption 발생  
또한 jar 는 무거움

`jigsaw` 라는 새로운 모듈화를 통해 가볍고 복잡하지 않은 java 모듈 시스템 구축 가능  

- jar 기반 모노리틱 방식을 개선하여 모듈 지정 및 모듈별 버전 관리 기능 가능
- 필요한 모듈만 구동하여 크기와 성능 최적화 가능

사용법
```java
// Java 코드 최상위에 module-info.java 파일을 만들고, 아래와 같이 사용함
module java.sql {
        requires public java.logging;
        requires public java.xml;
        exports java.sql;
        exports javax.sql;
        exports javax.transaction.xa;
}
```

자세한 사용법은 [jigsaw start](https://openjdk.org/projects/jigsaw/quick-start) 에서 확인

---

## Stream 에 새로운 메서드 추가

`takeWhile()`, `dropWhile()`, `iterate()`, `ofNullable() 등의 메서드 추가 

iterate()
```java
IntStream
	.iterate(1, i -> i < 20, i -> i * 2)
	.forEach(System.out::println);
```

takeWhile()
```java
//for ordered Stream
Stream.of(1, 2, 3, 4, 5, 6).takeWhile(i -> i <= 3).forEach(System.out::println);
// The result is:
// 1
// 2
// 3
        
// for unordered Stream
Stream.of(1, 6, 5, 2, 3, 4).takeWhile(i -> i <= 3).forEach(System.out::println);
// The result is:
// 1
```

dropWhile()
```java
/for ordered Stream
Stream.of(1, 2, 3, 4, 5, 6).dropWhile(i -> i <= 3).forEach(System.out::println);
// It drops (1,2,3), the result is:
// 4
// 5
// 6
        
//for unordered Stream
Stream.of(1, 6, 5, 2, 3, 4).dropWhile(i -> i <= 3).forEach(System.out::println);
// It drops (1), the result is:
// 6
// 5
// 2
// 3
// 4
```

ofNullable()
```java
// numbers [1,2,3,null]
// mapNumber [1 - one, 2 - two, 3 - three, null - null]
List<String> newstringNumbers = numbers.stream()
        .flatMap(s -> Stream.ofNullable(mapNumber.get(s)))
        .collect(Collectors.toList());
// The result is:
// [one, two, three]
```

---

## Optional 개선

**`Optional::stream`추가** 

Optional::stream 으로 Optional 객체 지연작업 제공하며, 0 또는 하나 이상의 요소 스트림 반환  
또한 빈 요소를 자동으로 확인하고 제거
```java
// streamOptional(): [(Optional.empty(), Optional.of("one"), Optional.of("two"), Optional.of("three")]
List<String> newStrings = streamOptional()
				.flatMap(Optional::stream)
				.collect(Collectors.toList());

// Result: newStrings[one, two, three]
```

**`ifPresentOrElse()` 메서드 추가**

```java
Optional<Integer> result3 = getOptionalEmpty();
result3.ifPresentOrElse(
      x -> System.out.println("Result = " + x),
      () -> System.out.println("return " + result2.orElse(-1) + ": Result not found."));

// return -1: Result not found.
```

**`or()` 메서드 추가**

값이 존재하는지 검사 후 값이 있으면 해당 Optional 반환, 값이 없으면 Suppier Function 에서 생성한 다른 Optional 반환
```java
Optional<Integer> result = getOptionalEmpty() // Empty Optional object
        .or(() -> getAnotherOptionalEmpty()) // Empty Optional object
        .or(() -> getOptionalNormal())  // this return an Optional with real value 42
        .or(() -> getAnotherOptionalNormal());  // this return an Optional with real value 99

// Result: Optional[42]
```

---

## 인터페이스에 Private 메서드 추가

인터페이스에서 private 메서드를 사용한다는 의미는 해당 메서드는 인터페이스 내부에서만 사용하고, 인터페이스를 구현하는 클래스는 해당 메서드를 따로 구현할 수 없다는 의미임

```java
public interface CustomInterface {
     
    public abstract void method1();
     
    public default void method2() {
        method4();  //private method inside default method
        method5();  //static method inside other non-static method
        System.out.println("default method");
    }
     
    public static void method3() {
        method5(); //static method inside other static method
        System.out.println("static method");
    }
     
    private void method4(){
        System.out.println("private method");
    } 
     
    private static void method5(){
        System.out.println("private static method");
    } 
}
```

---

## 불변 컬렉션 생성 메서드 제공

불변 List, Set, Map, Map.Entry 생성 가능

```java
List immutableList = List.of();
List immutableList = List.of(“one”, “two”, “thress”);
Map immutableMap = Map.of(1, "one", 2, "two");
```

---

## `try-with-resources` 개선

```java
void tryWithResourcesByJava7() throws IOException {
     BufferedReader reader1 = new BufferedReader(new FileReader("test.txt"));
     try (BufferedReader reader2 = reader1) {
          // do something
     }
}
```

```java
// final or effectively final이 적용되어 reader 참조를 사용할 수 있음
void tryWithResourcesByJava9() throws IOException {
     BufferedReader reader = new BufferedReader(new FileReader("test.txt"));
     try (reader) {
          // do something
     }
}
```

---

## Reactive Stream: Flow API 추가

상호 통신 가능한 publish-subscribe 프레임워크를 지원하는 java.util.concurrent.Flow 에서 Reactive Stream 추가

```java

java.util.concurrent.Flow
java.util.concurrent.Flow.Publisher
java.util.concurrent.Flow.Subscriber
java.util.concurrent.Flow.Processor
```

```java

@FunctionalInterface
public static interface Publisher<T> {
 public void subscribe(Subscriber<?superT> subscriber);
}
public static interface Subscriber<T> {
 public void onSubscribe(Subscription subscription);
 public void onNext(Titem);
 public void onError(Throwable throwable);
 public void onComplete();
}
public static interface Subscription {
 public void request(long n);
 public void cancel();
}
public static interface Processor<T,R> extends Subscriber<T>, Publisher<R> { }
```

---

## CompletableFuture API 개선

```java
// 50초후에 새로운 Executor 생성
Executor executor = CompletableFuture.delayedExecutor(50L, TimeUnit.SECONDS);
```

---

## JShell

기본 제공툴로 제공  
java 코드를 미리 검증해보는 프로토타이핑 도구이므로 간단한 실습이나 다른 라이브러리 테스트 시 유용함  
cmd 에서 실행

---

# Java 10

## `var` 예약어

var 예약어 사용 시 중복을 줄임으로써 코드를 간결하게 만들 수 있음  
기존의 엄격한 타입 선언 방식에서 탈피하여 컴파일러에게 타입을 추론하게 함  
var 는 지역 변수 타입 추론을 허용하며, 메서드 내부의 변수에만 적용 가능  

var 는 아래 상황에서만 사용 가능
- 초기화된 로컬 변수 선언 시
- 반복문에서 지역 변수 선언 시

```java
var list = new ArrayList<String>();  // infers ArrayList<String>
var stream = list.stream();          // infers Stream<String>
```

```java
var numbers = List.of(1, 2, 3, 4, 5);

for (var number : numbers) {
    System.out.println(number);
}
```

---

# Java 11

## String 클래스에 새로운 메서드 추가

아래 5개 메서드 추가

- `strip()`
  - 앞뒤 공백 제거
- `stripLeading()`
  - 앞 공백 제거
- `stripTrailing()`
  - 뒤 공백 제거
- `isBlank()`
  - 문자열이 비어있거나 공백이 포함되어 있을 경우 true 반환
  - String.trim().isEmpty() 와 동일한 결과
- `repeat(n)`
  - n 개만큼 문자열을 반복하여 붙여서 반복
- `line()`
  - 문자열을 줄 단위로 쪼개서 스트림 반환

---

## java.nio.file.Files 클래스에 새로운 메서드 추가

아래 3개 메서드 추가

- `Path writeString(Path, String, Charset, OpenOption)`
  - 파일에 문자열을 작성하고 Path 로 반환
  - OpenOption 에 따라 작동 방식을 달리하며, Charset 을 지정하지 않으면 UTF-8 사용
- `String readString(Path, Charset)`
  - 파일 전체를 읽어서 String 으로 반환
  - 파일을 모두 읽거나 예외 발생 시 알아서 close 함
  - Charset 을 지정하지 않으면 UTF-8 사용
- `boolean isSameFile(Path, Path)`
  - 두 Path 가 같은 파일을 가리키면 true 반환

---

## 컬렉션 인터페이스에 새로운 메서드 추가

컬렉션의 `toArray()` 메서드를 오버 로딩하는 메서드 추가 (원하는 타입의 배열을 선택하여 반환 가능)

```java
List list = Arrays.asList("java", "test");
String[] strings = list.toArray(String[]::new);
assertTath(list).containsExactly("java", "test");
```

---

## Predicate 인터페이스에 새로운 메서드 추가

`not()` 메서드 추가

```java
List<String> list = Arrays.asList("java", " ", "\n \n", "test");
List withoutBlanks = list.stream()
        .filter(Predicate.not(String::isBlank))
        .collect(Collectors.toList());
assertTath(withoutBlanks).containsExactly("java", "test");
```

---

## 람다에서 로컬 변수 `var` 사용 가능

람다는 타입을 스킵할 수 있는데 로컬 변수를 사용하는 이유는 `@Nullable` 등의 어노테이션을 사용하기 위해 타입을 명시해야 할 때  
var 를 사용하려면 괄호를 써야하고, 모든 파라메터에 사용해야 하며, 다른 타입과 혼용하거나 일부 스킵은 불가능함

```java
List<String> list = Arrays.asList("java", "test");
    String result = list.stream()
    .map((@Nonnull var x) -> x.toUpperCase())
    .collect(Collectors.joining(", "));
```

```java
(var n1, var n2) -> n1 + n2;  // 가능

(var n1, n2) -> n1 + n2;  // 불가능, n2 에도 var 필요
(var n1, String n2) -> n1 + n2; // 불가능, String 과 혼용 불가 
var n1 -> n1; // 불가능, 괄호 필요
```

---

## 자바 파일 실행

javac 를 통해 컴파일하지 않고도 바로 java 파일 실행 가능

기존
```shell
$ javac HelloWorld.java
$ java Helloworld
Hello Java 8!
```

Java 11
```shell
$ java Helloworld
Hello Java 8!
```

---

# Java 12

## Switch 확장

기존
```java
String time;
switch (weekday) {
	case MONDAY:
	case FRIDAY:
		time = "10:00-18:00";
		break;
	case TUESDAY:
	case THURSDAY:
		time = "10:00-14:00";
		break;
	default:
		time = "휴일";
}
```

Java 12
```java
String time = switch (weekday) {
	case MONDAY, FRIDAY -> "10:00-18:00";
	case TUESDAY, THURSDAY -> "10:00-14:00";
	default -> "휴일";
};
```

---

# Java 13

## Switch 표현식 (preview)

> **preview**  
> 향후 변경될 수 있음

Switch 표현식이 값을 반환할 수 있으며, fall-through/break 문제없이 람다 스타일 구문 사용 가능

기존
```java
switch(status) {
  case SUBSCRIBER:
    *// code block*break;
  case FREE_TRIAL:
    *// code block*break;
  default:
    *// code block*
}
```

Java 13
```java
boolean result = switch (status) {
    case SUBSCRIBER -> true;
    case FREE_TRIAL -> false;
    default -> throw new IllegalArgumentException(*"something is murky!"*);
};
```

---

# Java 14

## Switch 표현식 표준화

Java 13 에서 preview 였던 Switch 표현식이 표준화됨
```java
int numLetters = switch (day) {
    case MONDAY, FRIDAY, SUNDAY -> 6;
    case TUESDAY                -> 7;
    default      -> {
      String s = day.toString();
      int result = s.length();
      yield result;
    }
};
```

만일 메서드도 실행하고 값도 반환하고 싶으면 `yield` 키워드 사용
```java
int returnFrom = switch (type) {
    case TYPE_1 -> 3;
    default -> {
        System.out.println("return default value");
        yield 2; // `yield` 키워드를 사용한다.
    }
}
```

```java
int numLetters = switch (day) {
    case MONDAY, FRIDAY, SUNDAY -> 6;
    case TUESDAY                -> 7;
    default      -> {
      String s = day.toString();
      int result = s.length();
      yield result;
    }
};
```

---

## `record` 선언 기능 추가 (preview)

기존
```java
final class Point {
    public final int x;
    public final int y;

    public Point(int x, int y) {
        this.x = x;
        this.y = y;
    }
}
```

Java 14
```java
record Point(int x, int y) {
    // 상속은 불가하다. (마치 final 클래스처럼)

    // 초기화 필드는 `private final`이다. 즉, 수정 불가
    x = 5; // 에러

    // static 필드와 메서드를 가질 수 있다.
    static int LENGTH = 25;

    public static int getDefaultLength() {
        return LENGTH;
    }
}
```

사용할 때는 아래와 같이 사용
```java
Point point = new Point(2, 3);

// getter가 자동 생성
point.x();
```

---

## Pattern matching for `instanceof()` (preview)

instanceof() 연산자가 적용되는 if 블록내에서 지역 변수 사용 가능

기존
```java
// 캐스팅이 들어가게 된다.
if (obj instanceof String) {
    String text = (String) obj;
}
```

Java 14
```java
// 형 변환 과정이 없고, 그 변수를 담을 수 있다.
if (obj instanceof String s) {
    System.out.println(s);
    if (s.length() > 2) {
        // ...
    }
}

// 조건을 중첩해서 넣을 수도 있다.
if (obj instanceof String s && s.length() > 2) {
    // okay!
}
```

지역 변수 개념으로 적용되기 때문에 else 문에서는 instanceof() 에서 적용한 변수가 접근되지 않음
```java
if (obj instanceof String s) {

} else {
    // s가 접근되지 않는다.
}
```

---

## Text Blocks (second preview)

긴 문자열을 `+` 와 `\n` 을 사용하는 것이 아니라 Text block 개념을 사용하면 편함
```java
private void runJEP368() {
    String html = """
            {
                "list": [
                    {
                        "title": "hello, taeng",
                        "author": "taeng"
                    },
                    {
                        "title": "hello, news",
                        "author": "taeng"
                    }
                ]
            }
            """.indent(2);
    // indent 는 자바 12에서 추가된 것인데, 문자열 각 맨 앞 행을 n만큼 띄운다.
    System.out.println(html);
}
```

동적으로 문자열을 다루고 싶을 땐 아래처럼 placeholder 와 같이 사용
```java
// placeholder in textBlocks
String textBlock = """
            {
                "title": "%s"
            }
        """.indent(1);
System.out.println(String.format(textBlock, "Hello Madplay"));
```

```json
# 앞에 한 칸 띄워짐
 {
   "title": "Hello Madplay"
 }
```

`formatted()` 를 사용하여 아래와 같이 사용 가능
```java
String textBlock = """
        {
            "title": "%s",
            "author": "%s",
            "id": %d
        }
        """.formatted("hi", "taeng", 2);

System.out.println(textBlock);
```

```json
{
  "title": "hello World!",
  "author": "taeng",
  "id": 2
}
```

---

# Java 15

## Text Blocks 도입

Java 14 에서 preview 였던 기능이 프로덕션 준비 완료

---

## Sealed Classes (preview)

상속 가능한 클래스를 지정할 수 있는 Sealedclass 제공  
상속 가능한 대상은 상위 클래스 혹은 인터페이스 패키지 내에 속해있어야 함
```java
public abstract sealed class Shape
    permits Circle, Rectangle, Square {...}
```

즉, 클래스가 public 인 동안 하위 클래스로 허용되는 유일한 클래스는 Circle, Rectangle, Square 임

---

# Java 17

## Sealed Classes (finalized)

Java 15 에서 preview 였던 기능이 완료됨

---

## Deprecating the security manager

자바 1.0 이후로 security manager 가 존재해 왔었지만 현재는 더 이상 사용되지 않으며 향후 버전에서는 제거될 예정

---

# 참고 사이트 & 함께 보면 좋은 사이트

* [Java 8 vs Java 11](https://steady-coding.tistory.com/598)
* [Java 8 / Java 11 차이 자바](https://itkjspo56.tistory.com/201)
* [Java17을 왜 고려해야 할까? (Java version(8~17) 별 특징 정리)](https://velog.io/@ililil9482/Java17%EC%9D%84-%EA%B3%A0%EB%A0%A4%ED%95%B4%EC%95%BC%ED%95%A0%EA%B9%8C)
* [Jigsaw](https://www.baeldung.com/project-jigsaw-java-modularity)
* [java9(자바9) 새로운 기능 - 변화와 특징 요약](https://jang8584.tistory.com/258)
* [jigsaw start](https://openjdk.org/projects/jigsaw/quick-start)
* [나만 모르고 있던 - Java 9](https://www.popit.kr/%EB%82%98%EB%A7%8C-%EB%AA%A8%EB%A5%B4%EA%B3%A0-%EC%9E%88%EB%8D%98-java9-%EB%B9%A0%EB%A5%B4%EA%B2%8C-%EB%B3%B4%EA%B8%B0/)
* [java 버전별 차이 & 특징](https://velog.io/@ljo_0920/java-%EB%B2%84%EC%A0%84%EB%B3%84-%EC%B0%A8%EC%9D%B4-%ED%8A%B9%EC%A7%95)
* [JShell](https://docs.oracle.com/javase/9/jshell/introduction-jshell.htm#JSHEL-GUID-630F27C8-1195-4989-9F6B-2C51D46F52C8)
* [자바 14 버전에서는 어떤 새로운 기능이 추가됐을까?](https://madplay.github.io/post/what-is-new-in-java-14)