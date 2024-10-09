---
layout: post
title: "Kotlin - 코틀린 기본 - 데이터 타입, 문자열, 반복문, `in` 키워드, 자바-코틀린 변환"
date: 2024-02-04
categories: dev
tags: kotlin
---

이 포스트에서는 코틀린 기초에 대해 알아본다. 

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap01) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 코틀린](#1-코틀린)
  * [1.1. 코틀린 특성](#11-코틀린-특성)
    * [1.1.1. 정적 타입 지정 언어](#111-정적-타입-지정-언어)
    * [1.1.2. 함수형 프로그래밍](#112-함수형-프로그래밍)
  * [1.2. 코틀린 응용](#12-코틀린-응용)
  * [1.3. 코틀린 철학](#13-코틀린-철학)
    * [1.3.1. 간결성](#131-간결성)
    * [1.3.2. 안전성](#132-안전성)
    * [1.3.3. 상호운용성](#133-상호운용성)
* [2. Hello, World](#2-hello-world)
* [3. `var`, `val`](#3-var-val)
  * [3.1. 읽기 전용 컬렉션과 변경 가능한 컬렉션: `Collection`, `MutableCollection`](#31-읽기-전용-컬렉션과-변경-가능한-컬렉션-collection-mutablecollection)
  * [3.2. 코틀린 컬렉션과 자바 컬렉션](#32-코틀린-컬렉션과-자바-컬렉션)
  * [3.3. 컬렉션을 플랫폼 타입으로 다루기](#33-컬렉션을-플랫폼-타입으로-다루기)
* [4. 데이터 타입](#4-데이터-타입)
  * [4.1. primitive 타입: Int, Boolean 등](#41-primitive-타입-int-boolean-등)
  * [4.2. null 이 될 수 있는 primitive 타입: Int?, Boolean? 등](#42-null-이-될-수-있는-primitive-타입-int-boolean-등)
  * [4.3. 코틀린의 void: `Unit`](#43-코틀린의-void-unit)
* [5. 함수](#5-함수)
* [6. if](#6-if)
* [7. 문자열 템플릿](#7-문자열-템플릿)
  * [7.1. 문자열 나누기: `split()`, `toRegex()`](#71-문자열-나누기-split-toregex)
  * [7.2. 정규식과 3중 따옴표로 묶은 문자열: `substringBeforeLast()`, `substringAfterLast()`, `matchEntire()`, `matchResult.destructured`](#72-정규식과-3중-따옴표로-묶은-문자열-substringbeforelast-substringafterlast-matchentire-matchresultdestructured)
  * [7.3. 여러 줄 3중 따옴표 문자열: `trimMargin()`](#73-여러-줄-3중-따옴표-문자열-trimmargin)
* [8. number 타입](#8-number-타입)
  * [8.1. 숫자 변환](#81-숫자-변환)
  * [8.2. 문자열을 숫자로 변환](#82-문자열을-숫자로-변환)
* [9. `for`, `until`, `downTo`, `step`, `repeat`](#9-for-until-downto-step-repeat)
* [10. `in` 키워드](#10-in-키워드)
* [11. 식(expression), 문(statement)](#11-식expression-문statement)
* [Gradle 로 코틀린 빌드](#gradle-로-코틀린-빌드)
* [Java-Kotlin 변환](#java-kotlin-변환)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 코틀린

코틀린은 자바 플랫폼에서 돌아가는 새로운 프로그래밍 언어이다.

[http://try.kotl.in](http://try.kotl.in) 에 접속하면 코틀린 코드를 실행해볼 수 있다.

---

## 1.1. 코틀린 특성

---

### 1.1.1. 정적 타입 지정 언어

자바처럼 코틀린도 **정적 타입 지정 언어**이다.  

<**정적 타입과 동적 타입**>  
- 정적 타입
  - 모든 프로그램 구성 요소의 타입을 컴파일 시점에 알 수 있고, 프로그램 안에서 객체의 필드나 메서드를 사용할 때마다 컴파일러가 타입을 검증해 줌
- 동적 타입
  - JVM 에서 그루비나 JRuby 가 대표적인 동적 타입 지정 언어임
  - 메서드나 필드 접근에 대한 검증이 컴파일 시점이 아닌 실행 시점에 일어남
  - 따라서 코드가 더 짧아지고, 데이터 구조를 더 유연하게 사용 가능
  - 반대로 컴파일 시 오류를 잡아내지 못하여 실행 시점에 오류가 발생

자바와 달리 코틀린에서는 모든 변수의 타입을 직접 명시할 필요가 없다.  
대부분 코틀린의 컴파일러가 문맥으로부터 변수 타입을 자동으로 추론하는데 이를 **타입 추론**이라고 한다.

<**정적 타입 지정 언어의 장점**>  
- 성능
  - 실행 시점에 어떤 메서드를 호출할 지 알아내는 과정이 없으므로 메서드 호출이 더 빠름
- 신뢰성
  - 컴파일 시점에 오류가 검증되므로 실행 시 프로그램이 오류로 중단될 가능성이 더 적음
- 유지 보수성
  - 코드에서 다루는 객체가 어떤 타입에 속하는지 알 수 있기 때문에 처음 보는 코드도 쉽게 알 수 있음

코틀린의 중요한 특성들 중 하나는 **null 이 될 수 있는 타입을 지원**한다는 점이다.  
null 이 될 수 있는 타입을 지원함에 따라 컴파일 시점에 Null Pointer Exception 이 발생할 수 있는지 여부를 검사할 수 있어서 신뢰성을 높일 수 있다.  

> null 이 될 수 있는 타입 `?` 에 대한 좀 더 상세한 설명은 [1. null 이 될 수 있는 타입: `?`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#1-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%ED%83%80%EC%9E%85-) 을 참고하세요.

코틀린 타입 시스템에 있는 또 다른 새로운 내용은 **함수 타입에 대한 지원**이다.

> 함수 타입에 대한 좀 더 상세한 내용은 [1. 고차 함수 (high-order function)](https://assu10.github.io/dev/2024/02/17/kotlin-funtional-programming-2/#1-%EA%B3%A0%EC%B0%A8-%ED%95%A8%EC%88%98-high-order-function) 를 참고하세요.

---

### 1.1.2. 함수형 프로그래밍

<**함수형 프로그래밍의 핵심 개념**>  
- **일급 시민인 함수**
  - 함수를 일반 값처럼 변수에 저장할 수도 있고, 함수를 다른 함수의 인자로 전달할 수 있으며, 함수에서 새로운 함수를 만들어서 반환 가능
- **불변성 (immutable)**
  - 함수형 프로그래밍에서는 일단 만들어지고 나면 내부 상태가 절대로 바뀌지 않는 불변 객체를 사용
- **side-effect 없음**
  - 함수형 프로그래밍에서는 입력이 같으면 항상 같은 출력을 내놓음
  - 다른 객체의 상태를 변경하지 않음
  - 함수 외부나 다른 바깥 환경과 상호작용하지 않는 순수 함수 (pure function) 사용

> 순수 함수에 대한 좀 더 상세한 설명은 [3.1. 순수 함수](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/#31-%EC%88%9C%EC%88%98-%ED%95%A8%EC%88%98) 를 참고하세요.

<**함수형 프로그래밍의 장점**>  
- **간결성**
  - 순수 함수를 값처럼 활용할 수 있으면 강력한 추상화를 할 수 있고, 강력한 추상화를 통해 코드 중복을 막을 수 있음
- **다중 스레드에 안전**
  - 불변 데이터 구조를 사용하고, 순수 함수를 그 데이터 구조에 적용하면 다중 스레드 환경에서 같은 데이터를 여러 스레드가 변경할 수 없음
  - 따라서 복잡한 동기화를 적용하지 않아도 됨
- **쉬운 테스트**
  - side-effect 가 있는 함수는 그 함수를 실행할 때마다 전체 환경을 구성하는 준비 코드가 필요하지만 순수 함수는 그런 준비 코드없이 독립적으로 테스트 가능

<**코틀린이 지원하는 함수형 프로그래밍**>  
- 함수 타입을 지원하여 어떤 함수가 다른 함수를 파라메터로 받거나 함수가 새로운 함수 반환 가능
- 람다식을 지원하여 코드 블록을 쉽게 정의하고, 전달 가능
- 데이터 클래스는 불변적인 값 객체(Value Object) 를 간편하게 만들 수 있는 구문을 제공함
- 코틀린 표준 라이브러리는 객체와 컬렉션을 함수형 스타일로 다룰 수 있는 API 를 제공

---

## 1.2. 코틀린 응용

대부분의 코틀린 표준 라이브러리 함수는 인자로 받은 람다 함수를 인라이닝한다.

> `inline` 에 대한 좀 더 상세한 내용은 [3. `inline`: 람다의 부가 비용 없애기](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#3-inline-%EB%9E%8C%EB%8B%A4%EC%9D%98-%EB%B6%80%EA%B0%80-%EB%B9%84%EC%9A%A9-%EC%97%86%EC%95%A0%EA%B8%B0) 를 참고하세요.

따라서 람다를 사용해도 새로운 객체가 만들어지지 않으므로 객체 증가로 인한 가비지 컬렉션이 늘어나서 프로그램이 자주 멈추는 일이 없다.

---

## 1.3. 코틀린 철학

코틀린은 다른 프로그래밍 언어가 채택한 이미 성공적으로 검증된 해법과 기능에 의존한다.

---

### 1.3.1. 간결성

코틀린은 프로그래머가 작성하는 코드에서 의미없는 부분을 줄이고, 언어가 요구하는 구조를 만족시키기 위해 별 뜻은 없지만 프로그램에 꼭 넣어야 하는 부수적인 요소를 줄여준다.  
예를 들어 getter, setter 등 자바에 존재하는 여러 가지 번거로운 준비 코드를 코틀린은 묵시적으로 제공한다.

코틀린은 람다를 지원하기 때문에 일반적인 기능을 라이브러리 안에 캡슐화하고, 작업에 따라 달라져야 하는 개별적인 내용을 사용자가 작성한 코드 안에 남겨둘 수 있다.

---

### 1.3.2. 안전성

코틀린을 JVM 에서 실행한다는 사실은 이미 상당한 안전성을 보장할 수 있다는 의미이다.

JVM 을 사용하면 메모리 안전성을 보장하고, 버퍼 오버플로를 방지하며, 동적으로 할당한 메모리를 잘못 사용함으로써 발생하는 다양한 문제를 예방할 수 있다.  
JVM 에서 실행되는 정적 타입 지정 언어로서 코틀린은 자바보다 더 적은 비용으로 애플리케이션의 타입 안전성을 보장한다.

코틀린의 **타입 시스템은 null 이 될 수 없는 값을 추적하여 실행 시점에 NPE 가 발생할 수 있는 연산을 사용하는 코드를 금지**시킨다.

```kotlin
val s: String? = null // null 이 될 수 있음
val s: String = ""  // null 이 될 수 없음
```

코틀린이 방지해주는 다른 예외로는 `ClassCastException` 이다.  
어떤 객체를 다른 타입으로 캐스트하기 전에 타입 검사를 하지 않으면 `ClassCastException` 이 발생할 수도 있는데 자바에서는 타입 검사와 타입 캐스트를 각각 해야한다.    
하지만 **코틀린은 타입 검사와 캐스트가 한 연산자에 의해 이루어진다.**

따라서 타입 검사를 생략할 이유도 없고, 검사를 생략함으로서 생기는 오류가 발생할 일도 없다.

 ```kotlin
if (value is String) {  // 타입 검사
    println(value.upperCase())  // 해당 타입의 메서드 사용
}
```

---

### 1.3.3. 상호운용성

코틀린은 자체 컬렉션 라이브러리를 제공하지 않고 자바 표준 라이브러리 클래스에 의존한다.  
다만, 코틀린에서 컬렉션을 더 쉽게 사용할 수 있는 몇 가지 기능을 더할 뿐이다.

> 이런 식으로 기존 라이브러리를 확장하는 방법에 대한 좀 더 상세한 내용은 [1. 확장 함수 (extension function)](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#1-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-extension-function) 를 참고하세요.

---

# 2. Hello, World

`fun` 은 function 의 줄임말이다.  

코틀린은 식 뒤에 세미콜론을 붙이지 않아도 된다.

```kotlin
fun main() {
    println("Hello, world")
}
```

---

# 3. `var`, `val`

코틀린에서는 타입 지정을 생략하는 경우가 흔하다.

식이 본문인 함수처럼 변수 선언 시 타입을 지정하지 않으면 컴파일러가 초기화 식을 분석하여 변수 타입을 지정한다.

만일 초기화 식을 사용하지 않고 변수를 선언하려면 변수 타입을 반드시 명시해야 한다.

```kotlin
// 초기화 식에 의해 타입 추론됨
val str = "abc"

// 초기화 식이 없는 변수 선언 시 반드시 타입 명시
val str: String
str1 = "abc"
```

- `val`
  - 변경 불가능한 참조를 저장하는 변수
- `var`
  - 변경 가능한 참조를 저장하는 변수

```kotlin
fun main() {
    // var 는 가변
    var tmp1 = 11
    var tmp2 = 1.4
    var tmp3 = "hello world"

    tmp1 += 2

    println(tmp1)
    println(tmp2)
    println(tmp3)

    // val 는 불변
    val tmp11 = 11
    val tmp22 = 1.4

    //tmp11 += 2  // 오류, Val cannot be reassigned
}
```

val 변수는 블록을 실행할 때 정확히 한 번만 초기화되어야 한다.  
하지만, 어떤 블록이 실행될 때 오직 한 번만 초기화 문장이 실행됨을 컴파일러가 확인할 수 있다면 조건에 따라 val 의 값을 여러 값으로 초기화 가능하다.

```kotlin
val message: String

// val 로 선언되었지만 초기화 문장이 오직 한 번만 실행됨
if (str.length > 1) {
    message = "aa"
} else {
    message = "bb"
}
```

**val 참조 자체는 불변이지만, 그 참조가 가리키는 객체의 내부 값은 변경**될 수 있다.  

**`val` 와 `var` 의 차이점은 재할당 가능 여부**이다.

```kotlin
val lang = arrayListOf("Kotlin", "Java")    // 불변 참조 선언
lang.add("HTML")    // 참조가 가리키는 객체 내부 변경
```

> 변경 가능한 객체와 불변 객체에 대해서는 바로 뒤인 [3.1. 읽기 전용 컬렉션과 변경 가능한 컬렉션: `Collection`, `MutableCollection`](#31-읽기-전용-컬렉션과-변경-가능한-컬렉션-collection-mutablecollection) 을 참고하세요.

만일, 어떤 타입의 변수에 다른 타입의 값을 저장하고 싶다면 변환 함수를 써서 값을 변수의 타입으로 변환하거나, 값을 변수에 대입할 수 있는 타입으로 
강제 형 변환을 해야 한다.

> primitive 타입의 변환에 대해서는 [8. number 타입](#8-number-타입) 을 참고하세요.  
> 코틀린의 primitive 타입에 대해서는 [4.1. primitive 타입: Int, Boolean 등](#41-primitive-타입-int-boolean-등) 을 참고하세요.

---

## 3.1. 읽기 전용 컬렉션과 변경 가능한 컬렉션: `Collection`, `MutableCollection`

코틀린 컬렉션과 자바 컬렉션을 나누는 가장 중요한 특성 중 하나는 **코틀린에서는 컬렉션 안의 "데이터에 접근하는 인터페이스"와 "데이터를 변경하는 인터페이스"를 
분리**했다는 점이다.

- **컬렉션 데이터에 접근하는 인터페이스**
  - kotlin.collections.Collection
  - 컬렉션 안의 원소에 대해 이터레이션 가능
  - 컬렉션의 크기 조회 가능
  - 특정 값이 컬렉션에 포함되어 있는지 검사 가능
  - 컬렉션의 데이터 조회 가능
- **컬렉션 데이터를 변경하는 인터페이스**
  - kotlin.collections.MutableCollection
  - kotlin.collections.Collection 을 확장하였음
  - 원소 추가/삭제 가능

가능하면 읽기 전용 인터페이스를 사용하되, 컬렉션을 변경할 필요가 있을 때만 변경 가능한 버전을 사용하는 것이 좋다.

어떤 컴포넌트의 내부 상태에 컬렉션이 포함된다면, 그 컬렉션을 MutableCollection 을 인자로 받는 함수에 전달할 때에 원본의 변경을 막기 위해 컬렉션을 
복사해야 할 수도 있다. (= 방어적 복사, defensive copy)

아래는 src 컬렉션은 변경하지 않지만, target 컬렉션은 변경한다는 사실을 알 수 있는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

// src 컬렉션은 변경하지 않지만, target 컬렉션은 변경한다는 사실을 알 수 있음
fun <T> copyElements(
    src: Collection<T>,
    target: MutableCollection<T>,
) {
    for (item in src) {
        target.add(item)
    }
}

fun main() {
    val src: Collection<Int> = listOf(1, 2, 3)
    val target: MutableCollection<Int> = mutableListOf(4, 5)

    copyElements(src, target)

    println(src) // [1, 2, 3]
    println(target) // [4, 5, 1, 2, 3]
}
```

---

## 3.2. 코틀린 컬렉션과 자바 컬렉션

[2. 컬렉션 연산: `hashSetOf()`, `arrayListOf()`, `listOf()`, `hashMapOf()`](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#2-%EC%BB%AC%EB%A0%89%EC%85%98-%EC%97%B0%EC%82%B0-hashsetof-arraylistof-listof-hashmapof) 에서 본 것처럼 
모든 코틀린 컬렉션은 그에 상응하는 자바 컬렉션 인터페이스의 인스턴스이다.

따라서 코틀린과 자바를 오갈 때 아무 변환도 필요없다.

하지만 코틀린은 모든 자바 인터페이스마다 읽기 전용 인터페이스와 변경 가능한 인터페이스, 2 가지 표현을 제공한다.

![코틀린 컬렉션 인터페이스 계층 구조](/assets/img/dev/2024/0204/interface.png)

위 그림을 보면 자바 클래스 ArrayList 와 HashSet 은 코틀린의 변경 가능 인터페이스를 확장하는 것을 알 수 있다.

코틀린의 읽기 전용과 변경 가능 인터페이스의 기본 구조는 java.util 패키지에 있는 자바 컬렉션 인터페이스의 구조를 그대로 옮겨놓았다.  
추가로 변경 가능한 각 인터페이스는 자신과 대응하는 읽기 전용 인터페이스를 확장 (상속) 한다.

변경 가능한 인터페이스는 java.util 패키지에 있는 인터페이스와 직접적으로 연관되지만, 읽기 전용 인터페이스에는 컬렉션을 변경할 수 있는 모든 요소가 빠져있다.

위 그림에서 자바 표준 클래스를 코틀린에서 어떻게 취급하는지 보기 위해 java.util.ArrayList, java.util.HashSet 클래스를 예시로 들었는데, 코틀린은 
이들이 마치 각각 코틀린의 `MutableList` 와 `MutableSet` 인터페이스를 상속한 것처럼 취급한다.

LinkedList, SortedSet 등 자바 컬렉션 라이브러리에 있는 다른 구현도 마찬가지로 코틀린 상위 타입을 갖는 것처럼 취급한다.

**이런 방식을 통하여 코틀린은 자바 호환성을 제공하는 한편 읽기 전용 인터페이스와 변경 가능 인터페이스를 분리**한다.

위의 컬렉션처럼 Map 클래스도 코틀린에서 `Map` 과 `MutableMap`, 2 가지 버전을 보여준다.  
(Map 은 `Collection` 이나 `Iterable` 을 확장하지 않음)

<**컬렉션 생성 함수 모음**>  

| 컬렉션 타입 | 읽기 전용 타입   | 변경 가능 타입                                                          |
|:------:|:-----------|:------------------------------------------------------------------|
|  List  | `listOf()` | `mutableListOf()`, `arrayListOf()`                                |
|  Set   | `setOf()`  | `mutableSetOf()`, `hashSetOf()`, `linkedSetOf()`, `sortedSetOf()` |
|  Map   | `mapOf()`   | `mutableMapOf()`, `hashMapOf()`, `linkedMapOf()`, `sortedMapOf()`  |

자바 메서드를 호출할 때 컬렉션을 인자로 넘겨야 한다면 따로 변환하거나 복사하는 등의 추가 작업 없이 직접 컬렉션을 넘기면 된다.  
예) java.util.Collection 을 파라메터로 받는 자바 메서드가 있다면 `Collection`, `MutableCollection` 모두 인자로 넘길 수 있음

이런 성질로 인해 컬렉션의 변경 가능성과 관련하여 중요한 문제가 생긴다.

자바는 읽기 전용 컬렉션과 변경 가능 컬렉션을 구분하지 않으므로 코틀린에서 읽기 전용 `Collection` 으로 선언된 객체라도 자바 코드에서는 그 컬렉션 객체의 내용을 변경할 수 있다.

따라서 **컬렉션을 자바로 넘기는 코틀린 코드를 작성한다면 호출하려는 자바 코드가 컬렉션을 변경할 지 여부에 따라 올바른 파라메터 타입을 사용**해야 한다.

**즉, 변경 불가능한 컬렉션 타입을 넘겨도 자바 쪽에서 내용을 변경할 수 있으므로 자바 쪽에서 컬렉션을 변경할 여지가 있다면 아예 코틀린 쪽에서도 변경 가능한 컬렉션 타입을 
사용하여 자바 코드 수행 후 컬렉션 내용이 변할 수 있음을 코드에 남겨두어야 한다.**

null 이 아닌 원소로 이루어진 컬렉션 타입도 비슷하다.  
null 이 아닌 원소로 이루어진 컬렉션을 자바 메서드에 넘겼는데 자바 메서드가 null 을 컬렉션에 넣을 수도 있다.

따라서 **컬렉션을 자바 코드에게 넘길 때는 특별히 주의해야 하며, 코틀린 쪽 타입이 자바 쪽에서 컬렉션에게 가할 수 있는 변경의 내용 (null 가능성, 불변성 등..) 을 반영**하게 해야 한다.

---

## 3.3. 컬렉션을 플랫폼 타입으로 다루기

자바에서 정의한 타입을 코틀린에서는 [플랫폼 타입](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#121-%ED%94%8C%EB%9E%AB%ED%8F%BC-%ED%83%80%EC%9E%85)으로 본다.

플랫폼 타입의 경우 코틀린 쪽에서는 null 관련 정보가 없다.  
따라서 컴파일러는 코틀린 코드가 그 타입을 null 이 될 수 있는 타입이나 null 이 될 수 없는 타입 어느 쪽이든 사용할 수 있도록 허용한다.

플랫폼 타입인 컬렉션은 기본적으로 변경 가능성에 대해 알 수 없기 때문에 코틀린 코드는 그 타입을 읽기 전용 컬렉션과 변경 가능한 컬렉션 어느 쪽이로든 다룰 수 있다.

보통은 원하는 대로 동작이 잘 수행될 가능성이 높기 때문에 문제가 되진 않지만 컬렉션 타입이 시그니처에 들어간 자바 메서드 구현을 오버라이드 하는 경우 읽기 전용 컬렉션과 
변경 가능한 컬렉션의 차이가 문제가 된다.

플랫폼 타입에서 null 가능성을 다룰 때처럼 오버라이드하려는 메서드의 자바 컬렉션 타입을 어떤 코틀린 컬렉션 타입으로 표현할 지 결정해야 한다.

보통 아래와 같은 상황을 고려해야 한다.

- 컬렉션이 null 이 될 수 있는가?
- 컬렉션의 원소가 null 이 될 수 있는가?
- 오버라이드하는 메서드가 컬렉션을 변경할 수 있는가?

아래와 같이 컬렉션 파라메터가 있는 자바 인터페이스가 있다고 하자.

```java
package com.assu.study.kotlin2me.chap06;

import java.io.File;
import java.util.List;

// 파일에 들어있는 텍스트를 처리하는 인터페이스
public interface FileContent {
  void process(File path, byte[] binary, List<String> text);
}
```

이 인터페이스를 코틀린으로 구현하려면 아래의 내용을 고민 후 적절히 선택해야 한다.

- 일부 파일은 binary 파일이며, binary 파일 안의 내용은 텍스트로 표현할 수 없는 경우가 있으므로 리스트는 null 이 될 수 있음
- 파일의 각 줄은 null 일 수 없으므로 이 리스트의 원소는 null 이 될 수 없음
- 이 리스트는 파일의 내용을 표현하며, 그 내용을 바꿀 필요가 없으므로 읽기 전용임

아래는 코틀린으로 구현한 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

import java.io.File

class FileIndexer : FileContent {
    override fun process(
        path: File,
        binary: ByteArray?,
        text: MutableList<String>?,
    ) {
        TODO("Not yet implemented")
    }
}
```

아래는 컬렉션 파라메터가 있는 다른 자바 인터페이스이다.

```java
package com.assu.study.kotlin2me.chap06;

import java.util.List;

// 인터페이스를 구현한 클래스가 아래의 내용들을 처리함
// - 텍스트 폼에서 읽은 데이터를 파싱하여 객체 리스트를 만듦
// - 그 리스트의 객체들을 출력 리스트 뒤에 추가함
// - 데이터를 파싱하는 과정에서 발생한 오류 메시지를 별도의 리스트에 넣음
public interface DataParser<T> {
  void parseData(String input, List<T> output, List<String> errors);
}
```

이 인터페이스를 코틀린으로 구현하려면 아래의 내용을 적절히 고민 후 선택해야 한다.

- 호출하는 쪽에서 항상 오류 메시지를 받아야 하므로 List\<String\> 은 null 이 될 수 없음
- errors 의 원소는 null 이 될 수도 있음 (데이터를 파싱하는 과정에서 오류가 발생하지 않을수도 있으므로)
- 구현 코드에서 원소를 추가할 수 있어야 하므로 List\<T\> 는 변경 가능해야 함

아래는 코틀린으로 구현한 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

class PersonParser : DataParser<Person> {
    override fun parseData(
        input: String,
        output: MutableList<Person>,
        errors: MutableList<String?>,
    ) {
        TODO("Not yet implemented")
    }
}
```

위 2개의 자바 인터페이스에 사용된 List\<String\> 을 코틀린으로 구현 시 각각 List\<String\>? 과 MutableList\<String?\> 으로 구현하였다.

이러한 선택을 제대로 하려면 자바 인터페이스나 클래스가 어떤 맥락에서 사용되는지 알아야 한다.  
자바에서 가져온 컬렉션에 대해 코틀린 구현에서 어떤 작업을 수행해야 할 지 검토하면 쉽게 결정할 수 있다.

---

# 4. 데이터 타입

`var 식별자: 타입 = 초기화`

타입을 적지 않아도 코틀린이 변수의 타입을 알아내서 대입하는데 이를 **타입 추론**이라고 한다.

```kotlin
var n: Int = 1
var p: Double = 1.2
```

코틀린의 기본 타입들 일부
```kotlin
fun main() {
    val tmp1: Int = 1
    val tmp2: Double = 1.1
    val tmp3: Boolean = true
    val tmp4: String = "hello world"
    val tmp5: Char = 'a'
    val tmp6: String = """aa
        bb
        cc
    """

    println(tmp1)
    println(tmp2)
    println(tmp3)
    println(tmp4)
    println(tmp5)
    println(tmp6)
}
```

```shell
1
1.1
true
hello world
a
aa
        bb
        cc
```

여러 줄의 문자열은 `"""` 로 감싸는데 이를 삼중 큰 따옴표 혹은 raw string 이라고 한다.

---

## 4.1. primitive 타입: Int, Boolean 등

코틀린의 primitive 타입을 내부에서 어떻게 표현하는지에 대해 알아본다.

[null 가능성](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#12-null-%EA%B0%80%EB%8A%A5%EC%84%B1%EA%B3%BC-%EC%9E%90%EB%B0%94) 관련 내용은 
코틀린이 자바의 boxed type (boxing type) 을 처리하는 방법을 이해하는데 중요하다.

**코틀린은 primitive 타입과 wrapper 타입을 구분하지 않는다.**

그 이유와 코틀린 내부에서 어떻게 primitive 타입에 대한 래핑이 작동하는지에 대해 알아본다.

자바는 primitive 타입 (원시 타입) 과 wrapper 타입 (참조 타입) 을 구분한다.

> 자바의 원시 타입과 참조 타입은 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

primitive 타입의 변수에는 그 값이 직접 들어가지만, wrapper 타입의 변수에는 메모리 상의 객체 위치가 들어간다.

primitive 타입의 값에 대해 메서드를 호출하거나, 컬렉션에 primitive 타입이 값을 담을 수 없기 때문에 자바는 wrapper 타입이 필요한 경우 래퍼 타입 (java.lang.Integer..) 으로 primitive 타입 값을 감싸서 
사용한다. (= boxing)

따라서 정수의 컬렉션을 정의하려면 _Collection\<int\>_ 가 아니라 _Collection\<Integer\>_ 를 사용해야 한다.

> boxing 과 unboxing 에 대해서는 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

**코틀린은 primitive 타입과 wrapper 타입을 구분하지 않는다.**

따라서 코틀린에서 정수를 표현하는 Int 타입을 아래와 같이 사용할 수 있다.

```kotlin
val i: Int = 1
val list: List<Int> = listOf(1, 2, 3)
```

코틀린 타입에서는 primitive 타입의 값에 대해 메서드를 호출할 수도 있다.

```kotlin
val progress: Int = 170
val percentage = progress.coerceIn(0, 100)
println(percentage) // 100
```

- `coerceIn()`
  - 값이 범위 안에 있으면 해당 값을 리턴하고, 범위 안에 없으면 경계값을 리턴함
```kotlin
val range = 3..8
5.coerceIn(range) //5
1.coerceIn(range) // 3
9.coerceIn(range) //8
5.coreceIn(3,6) //5
```

primitive 타입과 wrapper 타입이 같다고해서 코틀린이 그들을 항상 객체로 표현하는 것은 아니다.

실행 시점에 숫자 타입은 가능한 가장 효율적인 방식으로 표현된다.

대부분의 경우 (변수, 프로퍼티, 파라메터, 반환 타입 등) 코틀린의 Int 타입은 자바의 int 타입으로 컴파일된다.  
이런 컴파일이 불가능한 경우는 컬렉셔과 같은 제네릭 클래스를 사용하는 경우 뿐이다.

예) Int 타입을 컬렉션의 타입 파라메터로 넘기면 그 컬렉션에는 Int 의 래퍼 타입에 해당하는 java.lang.Integer 객체가 들어감

**자바의 primitive 타입에 해당하는 코틀린 타입**은 아래와 같다.

- **정수 타입**
  - Byte, Short, Int, Long
- **부동소수점 타입**
  - Float, Double
- **문자 타입**
  - Char
- **불리언 타입**
  - Boolean

Int 와 같은 코틀린 타입에는 null 참조가 들어갈 수 없기 때문에 쉽게 그에 상응하는 자바 primitive 타입으로 컴파일 할 수 있다.

마찬가지로 자바 primitive 타입의 값은 결코 null 이 될 수 없으므로 자바의 primitive 타입을 코틀린에서 사용할 때도 [플랫폼 타입이](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#121-%ED%94%8C%EB%9E%AB%ED%8F%BC-%ED%83%80%EC%9E%85) 아닌 null 이 될 수 없는 타입으로 
취급할 수 있다.

---

## 4.2. null 이 될 수 있는 primitive 타입: Int?, Boolean? 등

null 참조를 자바의 wrapper 타입의 변수에만 대입할 수 있기 때문에 null 이 될 수 있는 코틀린 타이은 자바의 primitive 타입으로 표현할 수 없다.

따라서 코틀린에서 null 이 될 수 있는 primitive 타입을 사용하면 그 타입은 자바의 래퍼 타입으로 컴파일된다.

예) 코틀린의 Int? 타입은 자바에서 java.lang.Integer 로 저장됨

제네릭 클래스의 경우 래퍼 타입을 사용한다.  
자바에서 어떤 클래스의 타입 인자로 primitive 타입을 넘기면 코틀린은 그 타입에 대한 box 타입 (primitive 타입을 wrapper 타입으로 변환) 을 사용한다.

> boxing 과 unboxing 에 대해서는 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

예를 들어 아래 코드에서는 null 값이나 null 이 될 수 있는 타입을 전혀 사용하지 않았지만 만들어지는 리스트는 래퍼 파입인 Integer 타입으로 이루어진 리스트이다.

```kotlin
val list = listOf(1, 2, 3)
```

잉렇게 컴파일하는 이유는 JVM 에서 제네릭을 구현하는 방법 때문이다.

JVM 은 타입 인자로 primitive 타입을 허용하지 않기 때문에 자바와 코틀린 모두 제네릭 클래스는 항상 box 타입을 사용해야 한다.

primitive 타입으로 이루어진 대규모 컬렉션을 효율적으로 저장해야 한다면 primitive 타입으로 이뤄진 효율적인 컬렉션을 제공하는 서드파티 라이브러리를 사용하거나 배열을 사용해야 한다.

> 코틀린 배열에 대한 상세한 내용은 [4. 배열](https://assu10.github.io/dev/2024/02/09/kotlin-object/#4-%EB%B0%B0%EC%97%B4) 를 참고하세요.

---

## 4.3. 코틀린의 void: `Unit`

코틀린 `Unit` 타입은 자바의 void 와 같은 기능을 한다.

아래 2 개는 같은 기능을 한다.
```kotlin
// 관심을 가질만한 내용을 전혀 반환하지 않는 함수의 반환 타입으로 Unit 사용
fun f(): Unit { // ... }
    
// 반환 타입을 명시하지 안음
fun f() { // ... }    
```

코틀린 함수의 반환 타입이 `Unit` 이고, 그 함수가 제네릭 함수를 오버라이드하지 않는다면 그 함수는 내부에서 자바 void 함수로 컴파일된다.  
그런 코틀린 함수를 자바에서 오버라이드하는 경우 void 를 반환 타입으로 해야 한다.

<**코틀린의 `Unit` 과 자바의 void 차이점**>  
- `Unit` 은 모든 기능을 갖는 일반적인 타입이며, void 와 달리 `Unit` 을 타입 인자로 사용 가능
- `Unit` 타입에 속한 값은 단 하나 뿐이며, 그 이름도 `Unit` 임
- `Unit` 타입의 함수는 `Unit` 값을 묵시적으로 반환함

이 특성은 제네릭 파라메터를 반환하는 함수를 오버라이드하면서 반환 타입으로 `Unit` 을 사용할 때 유용하다.

```kotlin
package com.assu.study.kotlin2me.chap06

// 인터페이스의 시그니처는 process() 가 어떤 값을 반환하도록 명세됨
interface Processor<T> {
    fun process(): T
}

class NoResultProcessor : Processor<Unit> {
    // Unit 을 반환하지만 타입을 지정할 필요는 없음
    override fun process() {
        // ...
        // 여기서 return 을 지정할 필요없음
    }
}
```

`Unit` 타입도 `Unit` 값을 제공하기 때문에 메서드에서 `Unit` 값을 반환하는데 아무 문제가 없다.

하지만 컴파일러가 묵시적으로 _return Unit_ 을 넣어주므로 _NoResultProcessor_ 에서 명시적으로 `Unit` 을 반환할 필요는 없다.

타입 인자로 '값 없음' 을 표현하는 문제를 자바에서는 2 가지로 해결할 수 있다.

- 별도의 인터페이스 (`Callable`, `Runnable` 등과 비슷하게) 를 사용하여 값을 반환하는 경우와 반환하지 않는 경우를 분리
- 타입 파라메터로 java.lang.Void 타입 사용
  - 여전히 Void 타입에 대응할 수 있는 유일한 값인 null 을 반환하기 위해 _return null_ 을 명시해야 함
  - 반환 타입이 void 가 아니므로 함수를 반환할 때 _return_ 을 사용할 수 없고 항상 _return null_ 을 사용해야 함

> **코틀린에서 Void 가 아니라 `Unit` 이라는 이름을 택한 이유**  
> 
> 함수형 프로그래밍에서 전통적으로 `Unit` 은 '단 하나의 인스턴스만 갖는 타입' 을 의미해왔고, 바로 그 유일한 인스턴스의 유무가 자바 void 와 코틀린 `Unit` 을 
> 구분짓는 가장 큰 차이임

> `Any` 에 대한 내용은 [1.1. `Any`](https://assu10.github.io/dev/2024/03/17/kotlin-advanced-2/#11-any) 를 참고하세요.

코틀린에는 `Nothing` 이라는 타입도 있는데 Void 와 `Nothing` 이라는 두 이름은 의미가 비슷해서 혼란을 야기하기 쉽다.

> `Nothing` 에 대한 내용은 [3. `Nothing` 타입: `TODO()`](https://assu10.github.io/dev/2024/03/09/kotlin-error-handling-1/#3-nothing-%ED%83%80%EC%9E%85-todo) 을 참고하세요.

---

# 5. 함수

함수의 기본적인 형태
```kotlin
fun 함수 이름(p1: 타입1, p2: 타입2, ...): 반환 타입 {
    코드들
    return 결과
}
```

**파라메터는 전달할 정보를 넣을 장소**이고, **인자(argument) 는 파라메터를 통해 함수에 전달하는 실제 값**이다.

**함수 이름, 파라메터, 반환 타입을 합쳐서 함수 시그니처** 라고 한다.

```kotlin
fun multiple(x: Int): Int {
    println("multiple~")
    return x*2
}
fun main() {
    val result = multiple(5)
    println("result: $result")
}
```

```shell
multiple~
result: 10
```

의미있는 결과를 제공하지 않는 함수의 반환 타입은 `Unit` 이다. `Unit` 는 생략 가능하다.

```kotlin
fun meaningless() {
    println("meaningless~")
}

fun main() {
    meaningless()
}
```

함수 본문이 하나의 식으로만 이루어진 경우 아래처럼 함수를 짧게 작성할 수 있다.
```kotlin
fun 함수이름(p1: 타입1, p2: 타입2, ... ): 반환 타입 = 식
```

**함수 본문이 중괄호로 둘러싸여 있으면 블록 본문(block body)** 라고 하고, **등호 뒤에 식이 본문으로 지정되면 식 본문(expression body)** 라고 한다.

```kotlin
// 식 본문
fun multiple2(x: Int): Int = x*2

// 블록 본문
fun main() {
    val result2 = multiple2(5)
    println("result2: $result2")
}
```

코틀린에서는 식 본문이 더 자주 사용된다.  
식이 본문인 함수는 반환 타입을 생략해도 코틀린이 타입 추론을 해준다.

**단, 식이 본문인 함수의 반환 타입 생략이 가능**하다.

```kotlin
fun max(a: Int): Int = if (a > 0) a else 1

// 식이 본문인 함수에서는 반환 타입 생략 가능
fun max1(a: Int) = if (a > 0) a else 1
```

> intelliJ 에서 식 본문으로 전환(Convert to expression body) 와 블록 본문으로 전환(Convert to block body) 로 각각 변환 가능

---

# 6. if

코틀린은 if 가 값을 만들어내기 때문에 자바와 달리 3항 연산자가 없다.

```kotlin
fun trueOrFalse(exp: Boolean): String {
    if (exp)
        return "TRUE~"
    else
        return "FALSE~"
}

fun main() {
    val a = 1

    println(trueOrFalse(a < 3))
    println(trueOrFalse(a > 3))
}
```

하나의 식 본문인 경우 return 값 없이 아래와 같이 사용 가능하다.
```kotlin
fun trueOrFalse2(exp: Boolean): String =
    if (exp)
        "TRUE~"
    else
        "FALSE~"
```

---

# 7. 문자열 템플릿

아래 코드는 _a_ 라는 변수를 선언한 후 그 다음 줄에 있는 문자열 리터럴 안에서 _a_ 변수를 사용하는 예시이다.
```kotlin
fun main() {
    val a = 42
    println("Found $a") // Found 42
    println("Found \$a") // Found $a
    println("Fount $1") // Found $1
    //println("Fount $b")   // 오류
}
```

**`${}` 의 중괄호 안에 식을 넣으면 그 식을 평가하여 결과값을 String 으로 변환**한다.
```kotlin
val condition = true
println(
    "${if (condition) 'a' else 'b'}"
)   // a
val x = 11
println("$x + 4 = ${x+4}")  // 11 + 4 = 15
```

```shell
a
11 + 4 = 15
```

String 안에 큰 따옴표같은 특수 문자를 넣을 때는 역슬래시 혹은 큰따옴표 3개를 쓰는 String 리터럴을 이용해야 한다.
```kotlin
val s = "my apple"
println("s = \"$s\"~")  // s = "my apple"~
println("""s = "$s"~""")  // s = "my apple"~
```

만일, 문자열 템플릿 안에서 변수와 다른 문자가 바로 붙어있으면 컴파일 오류가 난다.  
이 때는 중괄호를 사용하여 변수명을 감싸면 된다.  
중괄호를 쓴 경우가 일괄 변환할 때 좀 더 편하고 가독성도 더 좋아지므로 문자열 템플릿 안에서 변수명만 사용하는 경우라도 _${name}_ 처럼 
중괄호로 변수명을 감싸는 습관을 들이는 것이 좋다.

```kotlin
val name = "assu"
println("Hello $name") // Hello assu
// println("Hello $name님") // 컴파일 오류
println("Hello ${name}님") // Hello assu님
```

중괄호로 둘러싼 식 안에서 큰 따옴표 사용도 가능하다.
```kotlin
// 중괄호로 둘러싼 식 안에서 큰 따옴표도 사용 가능
println("hello, ${if (str.length > 1) str else "hoho~"}")   // hello, abc
println("hello, ${if (str.length > 10) str else "hoho~"}")  // hello, hoho~
```

---

## 7.1. 문자열 나누기: `split()`, `toRegex()`

자바의 `split()` 메서드의 구분 문자열은 정규식이기 때문에 마침표 (`.`) 를 사용하여 문자열을 분리할 때 마침표가 모든 문자를 나타내는 정규식으로 해석된다.

코틀린에서는 자바의 `split()` 대신 **여러 다른 조합의 파라메터를 받는 `split()` 확장 함수를 제공**한다.  
정규식을 파라메터로 받는 함수는 String 이 아닌 Regex 타입의 값을 받는다.  
따라서 **코틀린에서는 `split()` 함수에 전달하는 값의 타입에 따라 정규식이나 일반 텍스트 중 어느 것으로 문자열을 분리하는지 쉽게 알 수 있다.**

```kotlin
package com.assu.study.kotlin2me.chap03

fun main() {
    val str = "12.456-6.A"

    // 정규식을 이용한 문자열 분리
    val regex = "\\.|-".toRegex()

    // [12, 456, 6, A]
    println(str.split(regex))

    // 구분 문자열을 이용한 문자열 분리
    // [12, 456, 6, A]
    println(str.split(".", "-"))    // 여러 개의 구분 문자열 지정
}
```

---

## 7.2. 정규식과 3중 따옴표로 묶은 문자열: `substringBeforeLast()`, `substringAfterLast()`, `matchEntire()`, `matchResult.destructured`

파일의 전체 경로명을 디렉터리, 파일명, 확장자로 구분하는 기능을 각각 String 을 확장한 함수와 정규식을 이용하여 구해보자.

_/Users/assu/kotlin-book/aaa.txt_

여기서 마지막 슬래시 전까지인 _/Users/assu/kotlin-book/_ 는 디렉터리이고, 마지막 마침표부터 마지막 문자까지는 확장자이다.

String 확장 함수 사용하여 경로 파싱
```kotlin
package com.assu.study.kotlin2me.chap03

fun parsePath(path: String) {
    val dir = path.substringBeforeLast("/")
    val fullName = path.substringAfterLast("/")
    val filename = fullName.substringBeforeLast(".")
    val ext = fullName.substringAfterLast(".")

    println("dir: $dir, filename: $filename, ext: $ext")
}

fun main() {
    val path = "/Users/assu/kotlin-book/aaa.txt"

    // dir: /Users/assu/kotlin-book, filename: aaa, ext: txt
    parsePath(path)
}
```

정규식을 이용하여 경로 파싱
```kotlin
package com.assu.study.kotlin2me.chap03

fun parsePathWithRegex(path: String) {
    // 삼중 따옴표를 사용하여 정규식을 사용하면 역슬래시를 포함한 어떤 문자도 이스케이프할 필요 없음
    val regex = """(.+)/(.+)\.(.+)""".toRegex()
    val matchResult = regex.matchEntire(path)
    if (matchResult != null) {
        val (dir, filename, extension) = matchResult.destructured
        println("dir: $dir, filename: $filename, extension: $extension")
    }
}

fun main() {
    val path = "/Users/assu/kotlin-book/aaa.txt"

    // dir: /Users/assu/kotlin-book, filename: aaa, extension: txt
    parsePathWithRegex(path)
}
```

3중 따옴표 문자열을 사용하여 정규식을 작성하면 역슬래시를 포함한 어떤 문자도 이스케이프할 필요가 없다.  
예) 일반 문자열을 이용해서 정규식 작성 시 마침표 기호를 이스케이프하려면 `\\.` 로 쓰지만, 3중 따옴표 문자열에서는 `\.` 로 사용함

`matchEntire()` 의 결과가 성공(= null 이 아님)하면 그룹별로 분해한 매치 결과를 의미하는 `destructured` 프로퍼티를 각 변수에 대입한다.  
바로 구조 분해 선언을 사용한 것이다.

> 이 구조 분해 선언에 대해서는 추후 좀 더 상세히 다룰 예정입니다. (p. 133)

---

## 7.3. 여러 줄 3중 따옴표 문자열: `trimMargin()`

3중 따옴표 문자열은 문자열 이스케이프를 피할 때도 사용하지만 줄바꿈을 표현하는 아무 문자열이나 이스케이프없이 그대로 사용할 때도 이용한다.

3중 따옴표를 사용하면 줄바꿈이 들어있는 텍스트를 쉽게 문자열로 만들 수 있다.

```kotlin
fun main() {
    val str =
        """|  //
                .| //
                .|/\
        """

    //  //
    //                .| //
    //                .|/\
    println(str.trimMargin())

    // |  //
    // | //
    // |/\
    println(str.trimMargin("."))

    // |  //
    // //
    // /\
    println(str.trimMargin(".|"))
}
```

> `trimMargin()` 에 대한 좀 더 상세한 설명은 [2.1. 디폴트 인자, trailing comma: `trimMargin()`](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#21-%EB%94%94%ED%8F%B4%ED%8A%B8-%EC%9D%B8%EC%9E%90-trailing-comma-trimmargin) 를 참고하세요.

**여러 줄의 문자열을 가독성이 좋게 하고 싶다면 들여쓰기를 하되 들여쓰기의 끝부분을 특별한 문자열로 표시하고, `trimMargin()` 을 사용하여 그 문자열과 
그 직전의 공백을 제거**한다.

**여러 줄의 문자열에는 줄바꿈이 들어가지만 줄바꿈을 `\n` 과 같은 특수 문자를 사용하여 넣을 수는 없다.**  

**여러 줄의 문자열에 `\` 을 넣을 때 이스케이프를 할 필요가 없다.**    
예) 일반 문자열로 `"C:\\Users\\assu\\book"` 이라고 쓴 경로를 3중 따옴표 문자열로 쓰면 `"""C:\Users\assu\book"""` 이다.

3중 따옴표 문자열 안에서 문자열 템플릿을 사용할 수도 있다.  
하지만 3중 따옴표 문자열 안에서는 이스케이프를 할 수 없기 때문에 문자열 템플릿의 시작을 표현하는 `$` 을 문자열로 넣기 위해서는 아래와 같이 해야 한다.

```kotlin
val price = """${'$'}9.99"""
println(price)  // $9.99
```

---

# 8. number 타입

## 8.1. 숫자 변환

코틀린과 자바의 가장 큰 차이점 중 하나는 숫자를 변환하는 방식이다.

**코틀린은 한 타입의 숫자를 다른 타입의 숫자로 자동 변환하지 않는다.**

```kotlin
val i = 1

// 컴파일 오류
// Type mismatch.
// Required: Long
// Found: Int
val l: Long = i
```

아래처럼 변환 메서드를 호출해야 한다.

```kotlin
val i = 1

// 변환 메서드 호출
val l: Long = i.toLong()
```

코틀린은 Boolean 을 제외한 모든 primitive 타입에 대한 변환 함수를 제공한다.

변환 함수의 이름은 `toByte()`, `toShort()`, `toChar()` 등과 같다.

어떤 타입을 표현 범위가 더 넓은 타입으로 변환할 수도 있고, 범위가 더 좁은 타입으로 변환하면서 값을 벗어나는 경우 일부를 잘라내는 `Long.toInt()` 와 같은 변환 함수도 있다.

코틀린은 개발자의 혼란을 피하기 위해 **타입 변환을 명시**하도록 한다.

특히 box 타입을 비교하는 경우에 문제가 많다.

> boxing 과 unboxing 에 대해서는 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.


두 box 타입 간의 `equals()` 메서드는 그 안에 들어있는 값이 아니라 box 타입 객체를 비교한다.

예) 자바에서 _new Integer(1).equals(new Long(1))_ 은 false 임

숫자 타입에 명시적 변환을 사용하지 않은 예시와 사용한 예시

```kotlin
val x = 1
val list = listOf(1L, 2L)

// 컴파일 오류
// println(x in list)

// 타입을 명시적으로 변환하여 같은 타입의 값으로 만든 후 비교
println(x.toLong() in list) // true
```

**동시에 여러 숫자 타입을 사용하려면 예상치 못한 동작을 피하기 위해 각 변수를 명시적으로 변환**해야 한다.

> **primitive 타입 리터럴 (Literal)**
> 
> 코틀린은 10진수 외에 아래와 같은 숫자 리터럴을 허용함
> 
> - **Long 타입 리터럴**
>   - `L` 접미사 사용
>   - 예) 12L
> - **Double 타입 리터럴**
>   - 표준 부동소수짐 표기법 사용
>   - 예) 1.12, 1.1e10, 1.1e-10
> - **Float 타입 리터럴**
>   - `f`, `F` 접미사 사용
>   - 예) 12.3f, 12.3F
> - **16진 리터럴**
>   - `0x`, `0X` 접두사 사용
>   - 예) 0xCAFEBABE, 0XxbcdL
> - **2진 리터럴**
>   - `0b`, `0B` 접두사 사용
>   - 예) 0b0000000101

> **상수 (Constant) vs 리터럴 (Literal)**
> 
> - **상수**
>   - 변하지 않는 변수
> - **리터럴**
>   - 데이터(= 값) 그 자체를 의미함
>   - 즉, 변수에 넣는 변하지 않는 데이터를 의미
>   - _val a = 10_ 에서 _a_ 는 상수이고, _10_ 은 리터럴임
> - **리터럴 표기법**
>   - 변수를 선언함과 동시에 그 값을 지정해주는 표기법
>   - 문자열 리터럴: _val string = "test"_
>   - 불리언 리터럴: _val boolean = true_

**숫자 리터럴을 사용할 때는 변환 함수를 호출할 필요가 없다.**    
즉, 11L 이나 1.1f 처럼 상수 뒤에 타입을 표현하는 문자를 붙이면 변환이 필요없다.

```kotlin
val aa = 1000   // Int
val bb = 1000L  // Long
val cc = 1000.0 // Double
```

코틀린 산술 연산자에도 자바처럼 숫자 연산 시 overflow 가 발생할 수 있다.  
코틀린은 overflow 를 검사하느라 추가 비용을 들이지 않는다.

overflow 현상
```kotlin
fun main() {
    val i: Int = Int.MAX_VALUE
    val l: Long = Long.MAX_VALUE
    val a: Int = 2_147_483_647  // 가독성을 위해
    
    println(i)  // 2147483647
    println(i + 1)  // -2147483648
    println(l + 1)  // -9223372036854775808
}
```

---

## 8.2. 문자열을 숫자로 변환

코틀린은 문자열을 primitive 타입으로 변환하는 여러 함수를 제공한다.

예) `toInt()`, `toByte()`, `toBoolean()`..

```kotlin
println("1".toInt()) // 1

// 런타임 오류
// java.lang.NumberFormatException: For input string: "1L"

// println("1L".toLong())
```

---

# 9. `for`, `until`, `downTo`, `step`, `repeat`

코틀린의 for 는 아래와 같은 형식이다.

```kotlin
for (<아이템> in <원소들>) {
    // ...
}
```

1~3 까지 루프

```kotlin
// 1~3 까지 루프
for (i in 1..3) {
    println(i)
}
```

1~10 까지 루프 (10 포함): `..` (닫힌 범위)

```kotlin
val range1 = 1..10
println(range1) // 1..10
```
1~10 까지 루프 (10 미포함): `until` (열린 범위)

```kotlin
val range2 = 1..<10
val range3 = 1 until 10
println(range2) // 1..9
println(range3) // 1..9
```

`until`, `downTo`, `step`

```kotlin
fun showRange(r: IntProgression) {
    for (i in r) {
        print("$i ")
    }
    print(" // $r")
    println()
}

showRange(1..5)
showRange(0 until 5)
showRange(5 downTo 1)
showRange(0..9 step 2)
showRange(0 until 10 step 3)
showRange(9 downTo 2 step 3)
```

```shell
1 2 3 4 5  // 1..5
0 1 2 3 4  // 0..4
5 4 3 2 1  // 5 downTo 1 step 1
0 2 4 6 8  // 0..8 step 2
0 3 6 9  // 0..9 step 3
9 6 3  // 9 downTo 3 step 3
```

`IntProgression` 은 Int 범위를 포함하며, 코틀린이 기본 제공하는 타입이다.

문자열 이터레이션

```kotlin
for (c in 'a'..'z') {
    print(c)    // abcdefghijklmnopqrstuvwxyz
}
```

`lastIndex`

```kotlin
val str = "abc"
for (i in 0..str.lastIndex) {
    print(str[i] + 1)   // bcd
}
```

각 문자 이터레이션

```kotlin
for (ch in "Jnskhm  ") {
    print(ch + 1)   // Kotlin!!
}
```

`repeat`

```kotlin    
// repeat
repeat(3) {
    print("hello")  // hellohellohello
}
```

---

# 10. `in` 키워드

**`in` 키워드는 어떤 값이 주어진 범위 안에 들어있는지 검사하거나, 이터레이션** 을 한다.

for 문 안에 있는 `in` 만 이터레이션을 뜻하고, 나머지 `in` 은 모두 원소인지 여부를 검사한다.  
반대로 `!in` 을 사용하면 어떤 값이 범위에 속하지 않는지 검사한다.

```kotlin
val a = 11
println(a in 1..10) // false
println(a in 1..12) // true
```

```kotlin
val b = 35

// 아래 2개는 같은 의미
println(0 <= b && b <= 100) // true
println(b in 0..100)    // true
```

이터레이션의 `in` 과 원소검사 `in`
```kotlin
val values = 1..3
for (v in values) {
    println("iteration $v")
}

val v = 2
if (v in values)
    println("$v is a member of $values")    // 2 is a member of 1..3
```

```shell
iteration 1
iteration 2
iteration 3
2 is a member of 1..3
```

`!in`
```kotlin
fun isDigit(ch: Char) = ch in '0'..'9'
fun notDigit(ch: Char) = ch !in '0'..'9'

println(isDigit('a'))   // false
println(isDigit('5'))   // true
println(notDigit('z'))  // true
```

```kotlin
fun recognize(c: Char) =
    when (c) {
        in '0'..'9' -> "Digit"
        in 'a'..'z', in 'A'..'Z' -> "Letter"    // 여러 조건의 범위 함께 사용
        else -> "Unknown"
    }

fun main() {
  println(recognize('8')) // Digit
  println(recognize('d')) // Letter
}
```

Comparable 을 사용하는 범위의 경우 그 범위 내의 모든 객체를 항상 이터레이션할 수는 없다.  
예를 들어 'java' 와 'kotlin' 사이의 문자열을 이터레이션 할 수는 없다.  
하지만 `in` 을 사용하여 값이 밤위 안에 들어가는지 결정은 할 수 있다.

```kotlin
// "java" <= "kotlin" && "kotlin" <= "scala" 와 동일
println("kotlin" in "java".."scala") // true
```

컬렉션에도 `in` 연산을 할 수 있다.
```kotlin
println("kotlin" in setOf("java", "scala")) // false
```

> 범위, 수열, 직접 만든 데이터 타입을 함께 사용하는 방법과 `in` 검사를 적용할 수 있는 객체에 대한 일반 규칙에 대해서는 추후 좀 더 상세히 다룰 예정입니다. (p. 95)

---

# 11. 식(expression), 문(statement)

**식(expression) 은 값을 표현**하고, **문(statement) 는 상태를 변경**한다.  
따라서 statement 는 효과는 발생시키지만 결과를 내놓지는 않고, expression 은 항상 결과를 만들어낸다.

**if 식도 식이기 때문에 결과를 만들어내고**, 이 결과를 val, var 에 저장 가능하다.  
단, if 가 식으로 사용될 때는 반드시 else 가 있어야 한다.
```kotlin
val result = if (1 < 2) 'a' else 'b'
println(result) // a
```

> 코틀린에서 if 는 식이지 문이 아님  
> 식은 값을 만들어내고, 문은 상태를 변경함  
> 
> 자바는 모든 제어 구조가 문인 반면에 코틀린은 루프를 제외한 대부분의 제어 구조가 식임

---

# Gradle 로 코틀린 빌드

코틀린 프로젝트를 빌드할 때는 Gradle 사용을 권장한다.  
Gradle 은 안드로이드 프로젝트의 표준 빌드 시스템이며, 코틀린을 사용할 수 있는 모든 유형의 프로젝트를 지원한다.

Gradle 은 코틀린으로 **Gradle 빌드 스크립트**를 작성하게 하는 작업을 진행중인데, 코틀린 스크립트를 사용할 수 있다면 애플리케이션을 작성하는 언어로 
빌드 스크립트도 작성한다는 장점이 있다.

Gradle 빌드 스크립트에 대한 좀 더 상세한 내용은 [Kotlin-Tools](https://kotlinlang.org/docs/get-started-with-jvm-gradle-project.html#specify-a-gradle-version-for-your-project) 에서 확인 가능하다.

다중 플랫폼 지원 Gradle 스크립트에 대한 좀 더 상세한 내용은 [Kotlin Multiplatform](https://kotlinlang.org/docs/multiplatform-get-started.html) 을 참고하세요.

코틀린 프로젝트를 JVM 을 타겟으로 빌드하는 표준 Gradle 빌드 스크립트는 아래와 같다.

```groovy
group "com.assu.study"
version "0.0.1-SNAPSHOT"

buildscript {
	ext.kotlin_version = "8.7"    // 사용할 코틀린 버전

	repositories {
		mavenCentral()
	}
	dependencies {
		// 코틀린 Gradle 플러그인에 대한 빌드 스크립트 의존관계 추가
		classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
	}
}

// 코틀린 Gradle 플러그인 적용
apply plugin: 'kotlin'

repositories {
	mavenCentral()
}

dependencies {
	compile "org.jetbrains.kotlin:kotlin-stdlib-jre7:$kotlin_version"
	//compile "org.jetbrains.kotlin:kotlin-reflect:$kotlin_version"
	//compile "junit:junit:4.12"
}

//sourceSets {
//	main.kotlin.srcDirs += 'src'
//}
```

# Java-Kotlin 변환

java 를 kotlin 으로 변환하고 싶을 때는 java 코드를 복사하여 kotlin 파일에 붙여 넣으면 된다.

만일 java 파일 하나를 통채로 변환하고 싶다면 `[Code] > [Convert Java File to Kotlin File]` 을 선택하면 된다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린** 과 드리트리 제메로프, 스베트라나 이사코바 저자의 **Kotlin In Action** 을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [아토믹 코틀린 예제 코드](https://github.com/gilbutITbook/080301)
* [Kotlin In Action](https://www.yes24.com/Product/Goods/55148593)
* [Kotlin In Action 예제 코드](https://github.com/AcornPublishing/kotlin-in-action)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)
* [코틀린 코드 실행](http://try.kotl.in)
* [공식 코틀린 포럼](https://discuss.kotlinlang.org/)
* [페이스북 한국 코틀린 사용자 그룹](https://www.facebook.com/groups/kotlinkr)
* [Gradle-Kotlin](https://gradle.org/kotlin/)
* [코틀린 빌드 스크립트 공홈](https://kotlinlang.org/docs/get-started-with-jvm-gradle-project.html#specify-a-gradle-version-for-your-project)
* [코틀린 다중 플랫폼 지원 Gradle 스크립트 공홈](https://kotlinlang.org/docs/multiplatform-get-started.html)
* [우당탕탕 Kotlin 전환기](https://dealicious-inc.github.io/2022/08/29/kotlin-converting.html)
* [리터럴(Literal)이란?](https://velog.io/@me2designer/%EB%A6%AC%ED%84%B0%EB%9F%B4Literal%EC%9D%B4%EB%9E%80)
* [Kotlin v2.0.20 Maps.kt](https://github.com/JetBrains/kotlin/blob/v2.0.20/libraries/stdlib/src/kotlin/collections/Maps.kt)