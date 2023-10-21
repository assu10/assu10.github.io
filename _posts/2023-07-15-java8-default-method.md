---
layout: post
title:  "Java8 - 디폴트 메서드"
date:   2023-07-15
categories: dev
tags: java java8 default-method
---

이 포스팅에서는 아래의 내용에 대해 알아본다.
- 디폴트 메서드
- 변화하는 인터페이스가 호환성을 유지하는 방법
- 디폴트 메서드의 활용 패턴
- 해결 규칙

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap09) 에 있습니다.

---

**목차**  

- [인터페이스가 변경되면서 발생하는 문제들](#1-인터페이스가-변경되면서-발생하는-문제들)
  - [인터페이스 버전 1](#11-인터페이스-버전-1)
  - [인터페이스 버전 2](#12-인터페이스-버전-2)
- [디폴트 메서드](#2-디폴트-메서드)
- [디폴트 메서드 활용 패턴](#3-디폴트-메서드-활용-패턴)
  - [선택형 메서드](#31-선택형-메서드)
  - [동작 다중 상속](#32-동작-다중-상속)
    - [다중 상속 형식](#321-다중-상속-형식)
    - [기능이 중복되지 않는 최소의 인터페이스](#322-기능이-중복되지-않는-최소의-인터페이스)
    - [인터페이스 조합](#323-인터페이스-조합)
- [해석 규칙](#4-해석-규칙)
  - [디폴트 메서드를 제공하는 서브 인터페이스](#41-디폴트-메서드를-제공하는-서브-인터페이스)
  - [충돌과 명시적인 문제 해결](#42-충돌과-명시적인-문제-해결)
- [정리하며..](#5-정리하며)

---

# 1. 인터페이스가 변경되면서 발생하는 문제들

인터페이스를 구현하는 클래스는 인터페이스에서 정의하는 모든 메서드 구현을 제공하거나 슈퍼클래스의 구현을 상속받아야 한다.  
만일 인터페이스에 새로운 메서드를 추가하는 등 인터페이스를 바꾸게 된다면 해당 인터페이스를 구현했던 모든 클래스의 구현도 고쳐야 하는 불상사가 발생한다.

Java8 에서는 이 문제를 해결하기 위해 기본 구현을 포함하는 인터페이스를 정의하는 두 가지 방법을 제공한다.
- **인터페이스 내부에 static method 사용**
- **인터페이스의 기본 구현을 제공할 수 있도록 디폴트 메서드 사용**

즉, **Java8 에서는 메서드 구현을 포함하는 인터페이스를 정의할 수 있기 때문에 기존의 코드 구현을 변경하지 않으면서도 인터페이스를 변경**할 수 있다.

List 인터페이스의 sort() 메서드는 Java8 에서 추가된 디폴트 메서드이다.
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

`default` 키워드는 해당 메서드가 디폴트 메서드임을 가리킨다.  
이 디폴트 메서드 덕분에 리스트에 직접 sort() 를 호출할 수 있다.

```java
List<Integer> numbers = Arrays.asList(1,3,5,2,4);
// sort() 는 디폴트 메서드
// naturalOrder() 는 static 메서드
numbers.sort(Comparator.naturalOrder());

// [1, 2, 3, 4, 5]
System.out.println(numbers);
```

`Comparator.naturalOrder()` 는 표준 알파멧 순서로 요소를 정렬할 수 있도록 Comparator 객체를 반환하는 Comparator 인터페이스에 추가된 static 메서드이다.

---

### 추상 클래스와 인터페이스

그렇다면 결국 인터페이스가 아니라 추상 클래스와 다른 건 무엇이 있을까?

둘 다 추상 메서드와 바디를 포함하는 메서드를 정의할 수 있다.

- 클래스는 하나의 추상 클래스만 상속받을 수 있지만, 인터페이스를 여러 개 구현할 수 있음
- 추상 클래스는 인스턴스 변수(필드)를 공통 상태로 가질 수 있지만, 인터페이스는 인스턴스 변수를 가질 수 없음

---

### 디폴트 메서드를 사용하는 이유

위에서 말했다시피 디폴트 메서드를 사용하면 자바 API 의 호환성을 유지하면서 라이브러리를 변경할 수 있다.  
디폴트 메서드가 없을 때는 인터페이스에 메서드를 추가하면 해당 인터페이스를 구현하는 기존 클래스를 모두 고쳐야 했지만, 
디폴트 메서드를 이용하면 인터페이스의 기본 구현을 그대로 상속하면서 자유롭게 새로운 메서드를 추가할 수 있다.

디폴트 메서드는 뒤에서 볼 [3.2. 동작 다중 상속](#32-동작-다중-상속) 처럼 다중 상속 동작이라는 유연성을 제공하기도 한다. (클래스는 여러 디폴트 메서드를 상속받을 수 있음)

---

### static 메서드와 인터페이스

보통 Java 는 인터페이스와 인터페이스의 인스턴스를 활용할 수 있는 다양한 static 메서드를 정의하는 유틸리티 클래스를 활용한다.  
Collections 는 Collection 객체를 활용할 수 있는 유틸리티 클래스이다.

Java8 에서는 인터페이스에 직접 static 메서드를 선언할 수 있으므로 유틸리티 클래스를 없애고 직접 인터페이스 내부에 static 메서드를 구현할 수 있다.  
그럼에도 불구하고 과거 버전과의 호환성을 유지하기 위해 Java API 에 아직 유틸리티 클래스가 남아있다.

---

이제 API 가 변경되면서 어떤 문제가 발생하고, 그 문제를 디폴트 메서드로 어떻게 해결하는지에 대해 알아본다.  
그리고 디폴트 메서드를 만들어 다중 상속을 하는 방법을 알아본 후, 같은 시그니처를 갖는 여러 디폴트 메서드를 상속받으면서 발생하는 모호성 문제를
자바 컴파일러가 어떻게 해결하는지 알아본다.

---

## 1.1. 인터페이스 버전 1

Drawable 이라는 인터페이스가 있고, Resizable 이란 인터페이스의 초기 버전이 아래와 같다고 치자. 


Drawable 이라는 인터페이스
```java
public interface Drawable {
  void draw();
}
```

Resizable 인터페이스의 초기 버전
```java
public interface Resizable extends Drawable {
  int getWidth();
  int getHeight();
  void setWidth(int width);
  void setHeight(int height);
  void setAbsoluteSize(int width, int height);
}
```

이 Resizable 인터페이스를 구현하는 Ellipse 클래스는 아래와 같다.
```java
package com.assu.study.mejava8.chap09;

public class Ellipse implements Resizable {
  @Override
  public void draw() { }

  @Override
  public int getWidth() {
    return 0;
  }

  @Override
  public int getHeight() {
    return 0;
  }

  @Override
  public void setWidth(int width) { }

  @Override
  public void setHeight(int height) { }

  @Override
  public void setAbsoluteSize(int width, int height) { }
}
```

Ellipse 와 동일하게 Square 클래스도 있다고 치고, 이제 다양한 모양을 처리하는 Game 이라는 클래스가 아래와 같다고 치자.

```java
public class Game {
  public static void main(String[] args) {
    List<Resizable> resizables = Arrays.asList(new Square(), new Ellipse());
    Utils.paint(resizables);
  }
}
```

Utils 클래스
```java
public class Utils {
  public static void paint(List<Resizable> lr) {
    lr.forEach(r -> {
      r.setAbsoluteSize(10, 10);
      r.draw();
    });
  }
}
```

---

## 1.2. 인터페이스 버전 2

시간이 흘러 Resizable 인터페이스에 새로운 메서드가 아래처럼 추가되었다.

```java
public interface Resizable extends Drawable {
  int getWidth();
  int getHeight();
  void setWidth(int width);
  void setHeight(int height);
  void setAbsoluteSize(int width, int height);
  void setRelativeSize(int wFactor, int hFactor); // 버전2에 추가된 메서드
}
```

Resizable 인터페이스에 setRelativeSize() 메서드가 추가되었기 때문에 Redizable 인터페이스를 구현하는 Ellipse, Square 클래스는 setRelativeSize() 를 구현해야 한다.  

같은 저장소에 예전 버전과 새로운 버전 라이브러리를 모두 사용해도 되지만, 로딩해야 할 클래스 파일이 많아지면서 메모리 사용과 로딩 시간 문제가 발생한다.

디폴트 메서드를 이용해서 API 를 변경하면 새롭게 바뀐 인터페이스에서 자동으로 기본 구현을 제공하기 때문에 기존 코드를 수정하지 않아도 된다.

---

# 2. 디폴트 메서드

디폴트 메서드는 호환성을 유지하면서 API 를 변경할 수 있도록 해준다. 즉, 인터페이스는 자신을 구현하는 클래스에서 메서드를 구현하지 않을 수 있는 새로운 메서드 시그니처를 제공한다.

디폴트 메서드는 `default` 라는 키워드로 시작하며, 다른 클래스에 선언된 메서드처럼 메서드 바디를 포함한다.

```java
public interface Sized {
  int size(); // 추상 메서드
  
  // 디폴트 메서드
  default boolean isEmpty() {
    return size() == 0;
  }
}
```

따라서 Resizable 인터페이스에 디폴트 메서드로 메서드를 추가하면 해당 인터페이스를 구현하는 클래스를 수정할 필요가 없다.
```java
default void setRelativeSize(int wFactor, int hFactor) {
  setAbsoluteSize(getWidth() / wFactor, getHeight()/hFactor);
}
```

인터페이스가 구현을 가질 수 있고, 클래스는 여러 인터페이스를 동시에 구현가능하니까 결국 자바도 다중 상속을 지원하는 걸까?  
인터페이스를 구현하는 클래스가 디폴트 메서드와 같은 메서드 시그니처를 정의하거나 디폴트 메서드를 오버라이드 한다면 어떻게 될까?  
이 부분은 [4. 해석 규칙](#4-해석-규칙) 에서 설명한다.

---

# 3. 디폴트 메서드 활용 패턴

디폴트 메서드를 사용하면 라이브러리를 변경해도 호환성을 유지할 수 있는 부분을 위에서 확인했다.

이제 디폴트 메서드를 다른 방식으로 활용하는 상황에 대해 알아본다.

<**디폴트 메서드를 이용하는 두 가지 방식**>  
- 선택형 메서드
- 동작 다중 상속

---

## 3.1. 선택형 메서드

Iterator 인터페이스의 경우 hasNext(), next() 뿐 아니라 remove() 도 제공하는데 remove() 기능은 잘 사용하지 않기 때문에 Java8 이전엔 사용자들이
remove() 기능을 무시했고, 결과적으로 Iterator 인터페이스를 구현하는 클래스에서는 remove() 에 빈 구현을 제공했다.

Java8 이후부터는 remove() 를 디폴트 메서드를 이용해서 기본 구현을 제공하기 때문에 인터페이스를 구현하는 클래스에서 빈 구현을 제공할 필요가 없어져서 불필요한
코드를 줄일 수 있게 되었다.

```java
default void remove() {
  throw new UnsupportedOperationException("remove");
}
```

---

## 3.2. 동작 다중 상속

디폴트 메서드를 이용하면 **기존에는 불가능했던 동작 다중 상속 기능도 구현 가능**하다.

자바는 클래스는 한 개의 클래스만 상속할 수 있지만 인터페이스는 여러 개 구현할 수 있다.


아래는 ArrayList 클래스이다.

```java
public class ArrayList<E> extends AbstractList<E>
        implements List<E>, RandomAccess, Cloneable, java.io.Serializable {
  ...
}
```

한 개의 클래스를 상속받고, 4개의 인터페이스를 구현한다.

---

### 3.2.1. 다중 상속 형식

Java8 에서는 **인터페이스가 구현을 포함할 수 있기 때문에 여러 인터페이스에서 동작(구현 코드)을 상속**받을 수 있다.

다중 동작 상속을 이용하면 중복되지 않는 최소한의 인터페이스를 유지할 때 쉽게 재사용하고 조합할 수 있다.

---

### 3.2.2. 기능이 중복되지 않는 최소의 인터페이스

예를 들어 어떤 모양은 회전할 수 없지만 크기는 조절 가능하고, 어떤 모양은 회전도 가능하고 움직일 수도 있지만 크기는 조절 불가한 기능을 구현할 때
최대한 기존 코드를 재사용해서 기능을 구현한다고 해보자.

아래는 setRotationAngle(), getRotationAngle() 두 개의 추상 메서드와 한 개의 디폴트 메서드를 포함하는 Rotatable 인터페이스이다.

Rotatable 인터페이스
```java
public interface Rotatable {
  void setRotationAngle(int angleInDegrees);
  int getRotationAngle();

  // 기본 구현
  default void rotateBy(int angleInDegrees) {
    setRotationAngle((getRotationAngle() + angleInDegrees) % 360);
  }
}
```

Rotatable 인터페이스를 구현하는 클래스는 setRotationAngle(), getRotationAngle() 의 구현을 제공해야 하지만 rotateBy() 는 기본 구현이 제공되므로
따로 구현을 제공하지 않아도 된다.


Movable 인터페이스
```java
public interface Movable {
  int getX();
  int getY();
  void setX(int x);
  void setY(int y);

  default void moveHorizontally(int distance) {
    setX(getX() + distance);
  }

  default void moveVertically(int distance) {
    setX(getY() + distance);
  }
}
```

Resizable 인터페이스
```java
public interface Resizable {
  int getWidth();
  int getHeight();
  void setWidth(int width);
  void setHeight(int height);
  void setAbsoluteSize(int width, int height);
  //void setRelativeSize(int wFactor, int hFactor); // 버전2에 추가된 메서드

  default void setRelativeSize(int wFactor, int hFactor) {
    setAbsoluteSize(getWidth() / wFactor, getHeight()/hFactor);
  }
}
```

---

### 3.2.3. 인터페이스 조합

이제 위 3개의 인터페이스를 조합하여 다양한 클래스를 만들어본다.

아래는 움직일 수 있고, 회전할 수 있고, 크기를 조절할 수 있는 클래스이다.

```java
public class Monster implements Rotatable, Movable, Resizable {
  ... // 모든 추상 메서드의 구현은 제공해야 하지만 디폴트 메서드의 구현은 제공할 필요 없음
}
```

Monster 클래스는 rotateBy(), moveHorizontally(), moveVertically(), setRelativeSize() 의 구현을 자동으로 상속받는다.

```java
Monster m = new Monster();
m.rotateBy(180);
m.moveVertically(10);
```

인터페이스에 디폴트 메서드를 포함시킬 경우 예를 들어 rotateBy() 를 더 효율적으로 수정해야 하는 경우 인터페이스에서 직접 수정할 수 있고,
**해당 인터페이스를 구현하는 모든 클래스도 자동으로 변경한 코드를 상속**받을 수 있다.  
(단, 구현 클래스에서 해당 메서드를 정의하지 않은 상황에 한해서이다.)

---

# 4. 해석 규칙

어떤 클래스가 같은 디폴트 메서드 시그니처를 포함하는 두 인터페이스를 구현하는 상황일 때 클래스는 어떤 인터페이스의 디폴트 메서드를 사용할까?

Java8 에는 디폴트 메서드가 추가되었기 때문에 같은 시그니처를 같은 디폴트 메서드를 상속받는 상황이 생길 수 있다.  
이 때 자바 컴파일러가 충돌을 어떻게 해결하는지 확인해보자.

아래와 같은 상황에서 클래스 C 는 어느 hello() 를 호출할지 예상해보자.

```java
public interface A {
  default void hello() {
    System.out.println("hello from A");
  }
}
```

```java
public interface B extends A {
  default void hello() {
    System.out.println("hello from B");
  }
}
```

```java
public class C implements A, B {
  public static void main(String[] args) {
    // hello from B
    new C().hello();
  }
}
```

---

### 다른 클래스나 인터페이스로부터 같은 시그니처를 같은 메서드를 상속받을 때 규칙

1) **클래스가 우선**
  - 클래스나 슈퍼 클래스에서 정의한 메서드가 디폴트 메서드보다 우선권을 가짐

2) **위 규칙 이외의 상황에서는 서브 인터페이스가 우선**
  - 상속 관계를 갖는 인터페이스에서 같은 시그니처를 같은 메서드 정의 시 서브 인터페이스가 우선권을 가짐
  - 예를 들어 B 가 A 를 상속받는다면 B 가 우선권을 가짐

3) **여전히 디폴트 메서드의 우선 순위가 결정되지 않았다면 여러 인터페이스를 구현하는 클래스가 명시적으로 디폴트 메서드를 오버라이드한 후 호출해야 함**

---

## 4.1. 디폴트 메서드를 제공하는 서브 인터페이스

이번엔 아래와 같이 E 클래스가 D 클래스를 상속받는 경우이다.

```java
public class D implements A {
}
```

```java
public class E extends D implements A, B {
  public static void main(String[] args) {
  // hello from B
    new E().hello();
  }
}
```

1번 규칙은 클래스의 메서드 구현이 우선권을 갖는다고 했지만 D 는 hello() 를 오버라이드하지 않고 단순히 인터페이스 A 를 구현했으므로 D 는 A 인터페이스의 디폴트 메서드 구현을 상속받는다.    
2번 규칙은 클래스나 슈퍼 클래스에 메서드 정의가 없을 때는 디폴트 메서드를 정의하는 서브 인터페이스가 우선권을 갖는다고 했기 때문에 컴파일러는 인터페이스 A 혹은 B 의 hello() 중 하나를 선택해야 한다.  
여기서 B 가 A 를 상속받는 관계이기 때문에 B 의 hello() 가 출력된다.

---

## 4.2. 충돌과 명시적인 문제 해결

아래와 같이 인터페이스 A 와 B_1 (A 를 상속받지 않음) 가 있을 경우를 생각해보자.

```java
public interface A {
  default void hello() {
    System.out.println("hello from A");
  }
}

```

```java
public interface B_1 {
  default void hello() {
    System.out.println("hello from B");
  }
}
```



인터페이스로부터 같은 시그니처를 같은 메서드를 상속받으면서 인터페이스 간의 상속 관계가 없으므로 1, 2 번의 규칙으로는 해결이 되지 않는다.

```java
public class C_1 implements A, B_1 {
  public static void main(String[] args) {
    new C_1().hello();
  }
}
```

위와 같이 클래스 생성 후 컴파일 시 아래와 같은 에러가 발생한다.
```shell
class C_1 inherits unrelated defaults for hello() from types A and B_1
```

이렇게 클래스와 메서드의 관계로 디폴트 메서드를 선택할 수 없는 상황에서는 직접 클래스에 메서드를 명시적으로 오버라이드 하여 선택해야 한다.

```java
public class C_1 implements A, B_1 {
  public static void main(String[] args) {
    new C_1().hello();
  }

  @Override
  public void hello() {
    B_1.super.hello();
  }
}
```

---

# 5. 정리하며..

- Java8 의 인터페이스는 구현 코드를 포함하는 디폴트 메서드, 정적 메서드를 정의할 수 있음
- 디폴트 메서드의 정의는 `default` 키워드로 시작하며, 일반 클래스 메서드처럼 바디를 가짐
- 공개된 인터페이스에 추상 메서드를 추가하면 소스 호환성이 깨짐
- 디폴트 메서드를 사용하면 설계자가 API 를 수정해도 기존 버전과 호환성 유지 가능
- 클래스가 갖은 시그니처를 갖는 여러 디폴트 메서드를 상속하면서 발생하는 충돌 문제를 해결하는 규칙이 있음

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)