---
layout: post
title:  "Java8 - 람다 테스팅, 디버깅"
date:   2023-07-02
categories: dev
tags: java java8 lambda-testing stream-testing lambda-debugging stream-debugging peek
---

이 포스트에서는 람다 표현식과 스트림 API 를 사용하는 코드를 테스트하고 디버깅하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap08) 에 있습니다.

---

**목차**  

<!-- TOC -->
* [1. 람다 테스팅](#1-람다-테스팅)
  * [1.1. 일반적인 단위 테스트](#11-일반적인-단위-테스트)
  * [1.2. 람다 표현식의 동작 테스트](#12-람다-표현식의-동작-테스트)
  * [1.3. 람다를 사용하는 메서드의 동작을 테스트](#13-람다를-사용하는-메서드의-동작을-테스트)
* [2. 디버깅](#2-디버깅)
  * [2.1. 스택 트레이스 확인](#21-스택-트레이스-확인)
  * [2.2. 로깅: `peek()`](#22-로깅-peek)
* [3. 정리하며..](#3-정리하며)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 람다 테스팅

## 1.1. 일반적인 단위 테스트

아래는 Point 클래스가 있고, 기능이 의도대로 동작하는 확인하는 단위 테스트이다.

```java
public class Point {
  private final int x;
  private final int y;

  public Point(int x, int y) {
    this.x = x;
    this.y = y;
  }

  public int getX() {
    return x;
  }

  public int getY() {
    return y;
  }

  public Point moveRightBy(int x) {
    return new Point(this.x + x, this.y);
    }
}
```

단위 테스트 코드
```java
import org.junit.*;

import static org.junit.Assert.assertEquals;

public class Testing {

  @Test
  public void testMoveRightBy() {
    Point p1 = new Point(5,5);
    Point p2 = p1.moveRightBy(10);

    assertEquals(15, p2.getX());
    assertEquals(5, p2.getY());
  }
}
```

`@Test` 사용 시 `junit` dependency 를 추가해주어야 한다.
```xml
<dependency>
    <groupId>junit</groupId>
    <artifactId>junit</artifactId>
    <version>4.12</version>
</dependency>
```

---

## 1.2. 람다 표현식의 동작 테스트

위의 moveRightBy() 메서드는 public 이기 때문에 문제없이 동작하지만 람다는 익명(=익명 함수) 이므로 테스트 코드 이름을 호출할 수 없다.  
따라서 필드에 람다를 저장해서 재사용하는 방법으로 람다 로직 테스트가 가능하다.

예를 들어 compareByXAndThenY 라는 정적 필드를 추가하고, 여기에 람다 표현식을 저장한다.

```java
public final static Comparator<Point> compareByXAndThenY =
          Comparator.comparing(Point::getX).thenComparing(Point::getY);
```

> `thenComparing()` 를 이용하여 첫 번째 비교자가 같을 때 두 번째 비교자에 객체를 전달하여 비교할 수 있다.

람다 표현식을 함수형 인터페이스의 인스턴스를 생성하기 때문에 생성된 인스턴스의 동작으로 람다 표현식을 테스트할 수 있다.

```java
@Test
public void testComparingTowPoints() {
  Point p1 = new Point(10, 5);
  Point p2 = new Point(5, 10);

  int result = Point.compareByXAndThenY.compare(p1, p2); // 1

  // compare(): 첫 번째 인자가 작으면 -1, 같으면 0, 첫 번째 인자가 더 크면 1

  assertEquals(1, result);
}
```

---

## 1.3. 람다를 사용하는 메서드의 동작을 테스트


**람다의 목표는 정해진 동작을 다른 메서드에서 사용할 수 있도록 하나의 조각으로 캡슐화**하는 것이므로 세부 구현을 포함하는 람다 표현식은 공개하지 않아야 한다.  
**람다 표현식을 사용하는 메서드의 동작을 테스트함으로써 람다를 공개하지 않으면서도 람다 표현식을 검증**할 수 있다.

```java
public static List<Point> moveAllPointsRightBy(List<Point> point, int x) {
  return point.stream()
          .map(p -> new Point(p.getX()+x, p.getY()))
          .collect(Collectors.toList());
}
```

이제 moveAllPointsRightBy() 메서드의 동작을 확인함으로써 p -> new Point(p.getX()+x, p.getY()) 를 테스트할 수 있다.

```java
@Test
public void testMoveAllPointsRightBy() {
  List<Point> points = Arrays.asList(new Point(5,5), new Point(10,5));
  List<Point> expectedPoints = Arrays.asList(new Point(15, 5), new Point(20,5));

  List<Point> newPoints = Point.moveAllPointsRightBy(points, 10);

  assertEquals(expectedPoints, newPoints);
}
```

```shell
java.lang.AssertionError: 
Expected :[com.assu.study.mejava8.chap08.Point@233c0b17, com.assu.study.mejava8.chap08.Point@63d4e2ba]
Actual   :[com.assu.study.mejava8.chap08.Point@7bb11784, com.assu.study.mejava8.chap08.Point@33a10788]
```

두 객체를 값이 아닌 주소로 비교하기 때문에 위와 같은 오류가 뜬다.

두 객체를 값으로 비교하기 위해 Point 클래스에 `equals()` 와 `hashCode()` 를 오버라이딩 해주면 두 객체가 같은 객체(값으로 비교)로 판별되어 Test pass 된다.
```java
@Override
public boolean equals(Object o) {
  if (this == o) return true;
  if (o == null || getClass() != o.getClass()) return false;
  Point point = (Point) o;
  return getX() == point.getX() && getY() == point.getY();
}

@Override
public int hashCode() {
  return Objects.hash(getX(), getY());
}
```

---

# 2. 디버깅

디버깅 시 스택 스페이스와 로그를 먼저 확인하게 되는데 람다 표현식과 스트림은 사실 디버깅이 어려운 편이다.

---

## 2.1. 스택 트레이스 확인

아래와 같은 Point 클래스가 있고, 고의적으로 문제를 일으켜보자.

```java
private static class Point {
  private int x;
  private int y;

  public Point(int x, int y) {
    this.x = x;
    this.y = y;
  }

  public int getX() {
    return x;
  }

  public void setX(int x) {
    this.x = x;
  }
}
```

```java
public class Debugging {
  public static void main(String[] args) {
    List<Point> points = Arrays.asList(new Point(3, 2), null);
    points.stream().map(p -> p.getX()).forEach(System.out::println);
  }
}
```

```shell
3
Exception in thread "main" java.lang.NullPointerException: Cannot invoke "com.assu.study.mejava8.chap08.Debugging$Point.getX()" because "p" is null
	at com.assu.study.mejava8.chap08.Debugging.lambda$main$0(Debugging.java:9)
	at java.base/java.util.stream.ReferencePipeline$3$1.accept(ReferencePipeline.java:197)
	at java.base/java.util.Spliterators$ArraySpliterator.forEachRemaining(Spliterators.java:992)
	at java.base/java.util.stream.AbstractPipeline.copyInto(AbstractPipeline.java:509)
	at java.base/java.util.stream.AbstractPipeline.wrapAndCopyInto(AbstractPipeline.java:499)
	at java.base/java.util.stream.ForEachOps$ForEachOp.evaluateSequential(ForEachOps.java:150)
	at java.base/java.util.stream.ForEachOps$ForEachOp$OfRef.evaluateSequential(ForEachOps.java:173)
	at java.base/java.util.stream.AbstractPipeline.evaluate(AbstractPipeline.java:234)
	at java.base/java.util.stream.ReferencePipeline.forEach(ReferencePipeline.java:596)
	at com.assu.study.mejava8.chap08.Debugging.main(Debugging.java:9)

Process finished with exit code 1
```

의도한대로 points 리스트의 두 번째 인수가 null 이기 때문에 스트림 파이프라인에서 에러가 발생하여 스트림 파이프라인 작업과 관련된 전체 메서드 호출 리스트가 출력되었다.

```shell
at com.assu.study.mejava8.chap08.Debugging.lambda$main$0(Debugging.java:9)
```

이런 코드는 람다 표현식 내부에서 에러가 발생했음을 가리킨다.  
람다 표현식은 이름이 없기 때문에 컴파일러가 람다를 참조하는 이름을 만들어 낸 것이다. (lambda$main$0)

메서드 레퍼런스를 사용해도 스택 트레이스에 메서드명이 나오지는 않는다.

위 코드에서 람다 표현식 p -> p.getX() 를 Point::getX() 로 변경 후 로그는 아래와 같다.

```java
points.stream().map(Point::getX).forEach(System.out::println);
```

```shell
3
Exception in thread "main" java.lang.NullPointerException
	at java.base/java.util.stream.ReferencePipeline$3$1.accept(ReferencePipeline.java:197)
	at java.base/java.util.Spliterators$ArraySpliterator.forEachRemaining(Spliterators.java:992)
	at java.base/java.util.stream.AbstractPipeline.copyInto(AbstractPipeline.java:509)
	at java.base/java.util.stream.AbstractPipeline.wrapAndCopyInto(AbstractPipeline.java:499)
	at java.base/java.util.stream.ForEachOps$ForEachOp.evaluateSequential(ForEachOps.java:150)
	at java.base/java.util.stream.ForEachOps$ForEachOp$OfRef.evaluateSequential(ForEachOps.java:173)
	at java.base/java.util.stream.AbstractPipeline.evaluate(AbstractPipeline.java:234)
	at java.base/java.util.stream.ReferencePipeline.forEach(ReferencePipeline.java:596)
	at com.assu.study.mejava8.chap08.Debugging.main(Debugging.java:10)

Process finished with exit code 1
```

단, 메서드 레퍼런스를 사용하는 클래스와 같은 곳에 선언되어 있는 메서드를 참조할 때는 메서드 레퍼런스의 이름이 스택 트레이스에 나타난다.

```java
List<Integer> numbers = Arrays.asList(1,2,3);
numbers.stream().map(Debugging::divideByZero).forEach(System.out::println);
```

```shell
Exception in thread "main" java.lang.ArithmeticException: / by zero
	at com.assu.study.mejava8.chap08.Debugging.divideByZero(Debugging.java:17)
	at java.base/java.util.stream.ReferencePipeline$3$1.accept(ReferencePipeline.java:197)
	at java.base/java.util.Spliterators$ArraySpliterator.forEachRemaining(Spliterators.java:992)
	at java.base/java.util.stream.AbstractPipeline.copyInto(AbstractPipeline.java:509)
	at java.base/java.util.stream.AbstractPipeline.wrapAndCopyInto(AbstractPipeline.java:499)
	at java.base/java.util.stream.ForEachOps$ForEachOp.evaluateSequential(ForEachOps.java:150)
	at java.base/java.util.stream.ForEachOps$ForEachOp$OfRef.evaluateSequential(ForEachOps.java:173)
	at java.base/java.util.stream.AbstractPipeline.evaluate(AbstractPipeline.java:234)
	at java.base/java.util.stream.ReferencePipeline.forEach(ReferencePipeline.java:596)
	at com.assu.study.mejava8.chap08.Debugging.main(Debugging.java:13)

Process finished with exit code 1
```

---

## 2.2. 로깅: `peek()`

```java
List<Integer> numbers = Arrays.asList(2,3,4,5);

// 20 22
numbers.stream()
        .map(x -> x + 17)
        .filter(x -> x%2 == 0)
        .limit(3)
        .forEach(System.out::println);
```

위 코드의 결과는 아래와 같다.
```shell
20
22
```

forEach 를 호출하는 순간 전체 스트림이 소비된다.  
`peek()` 을 활용하여 스트림 파이프라인에 적용된 각각의 연산인 map, filter, limit 이 어떤 결과를 도출하는지 확인해보자.

`peek()` 은 스트림의 각 요소를 소비한 것처럼 동작하지만 실제로 스트림의 요소를 소비하지는 않는다.  
`peek()` 은 자신이 확인한 요소를 파이프라인의 다음 연산으로 그대로 전달한다.

```java
List<Integer> result = numbers.stream()
        .peek(x -> System.out.println("from stream: " + x)) // 소스에서 처음 소비한 요소 출력
        .map(x -> x + 17)
        .peek(x -> System.out.println("after map: " + x)) // map() 실행 결과 출력
        .filter(x -> x%2 == 0)
        .peek(x -> System.out.println("after filter: " + x))  // filter() 실행 결과 출력
        .limit(3)
        .peek(x -> System.out.println("after limit: " + x)) // limit() 실행 결과 출력
        .collect(Collectors.toList());

System.out.println(result); // [20, 22]
```

```shell
from stream: 2
after map: 19
from stream: 3
after map: 20
after filter: 20
after limit: 20
from stream: 4
after map: 21
from stream: 5
after map: 22
after filter: 22
after limit: 22
```

---

# 3. 정리하며..

- 람다 표현식으로 가독성이 좋고 더 유연한 코드를 만들 수 있음
- 익명 클래스는 람다 표현식으로 바꾸는 것이 좋음  
단, 이 때 this, 변수 섀도 등 미묘하게 의미상 다른 내용이 있음을 주의해야 함   
메서드 레퍼런스로 람다 표현식보다 더 가독성이 좋은 코드 구현 가능
- 반복적으로 컬렉션을 처리하는 루틴은 스트림 API 로 대체 가능한지 고려
- 람다 표현식도 단위 테스트 수행 가능  
단, 람다 표현식 자체를 테스트하는 것보다는 람다 표현식이 사용되는 메서드의 동작을 테스트하는 것이 바람직함
- 람다 표현식을 사용하면 스택 트레이스를 이해하기 어려워짐
- 스트림 파이프라인에서 요소를 처리할 때 `peek()` 메서드로 중간값 확인 가능

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)