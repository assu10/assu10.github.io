---
layout: post
title: "Kotlin - 함수(1): 확장 함수, 오버로딩, when, enum, data 클래스, 구조 분해 선언"
date: 2024-02-10
categories: dev
tags: kotlin joinToString pair triple with-index
---

이 포스트에서는 코틀린 함수 기능에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap03) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 확장 함수 (extension function)](#1-확장-함수-extension-function)
  * [1.1. import 와 확장 함수: `as`](#11-import-와-확장-함수-as)
  * [1.2. 자바에서 확장 함수 호출](#12-자바에서-확장-함수-호출)
* [2. 이름 붙은 인자와 디폴트 인자, trailing comma](#2-이름-붙은-인자와-디폴트-인자-trailing-comma)
  * [2.1. 이름 붙은 인자](#21-이름-붙은-인자)
  * [2.1. 디폴트 인자, trailing comma: `trimMargin()`](#21-디폴트-인자-trailing-comma-trimmargin)
    * [디폴트 값과 자바: `@JvmOverloads`](#디폴트-값과-자바-jvmoverloads)
  * [2.3. `joinToString()`](#23-jointostring)
  * [2.4. 객체 인스턴스를 디폴트 인자로 전달](#24-객체-인스턴스를-디폴트-인자로-전달)
  * [2.5. 가독성을 고려하여 인자 이름 붙이기](#25-가독성을-고려하여-인자-이름-붙이기)
* [3. 오버로딩](#3-오버로딩)
  * [3.1. 오버로딩 기본](#31-오버로딩-기본)
  * [3.2. 클래스 안의 확장 함수가 있는 경우의 오버로딩](#32-클래스-안의-확장-함수가-있는-경우의-오버로딩)
  * [3.3. 디폴트 인자를 흉내내기 위한 확장 함수](#33-디폴트-인자를-흉내내기-위한-확장-함수)
  * [3.4. 오버로딩과 디폴트 인자를 함께 사용하는 경우](#34-오버로딩과-디폴트-인자를-함께-사용하는-경우)
  * [3.5. 오버로딩이 유용한 이유](#35-오버로딩이-유용한-이유)
* [4. when 식](#4-when-식)
  * [4.1. when 기본](#41-when-기본)
  * [4.2. when 으로 Set 과 Set 을 매치](#42-when-으로-set-과-set-을-매치)
  * [4.3. 인자가 없는 when](#43-인자가-없는-when)
  * [4.4. when 으로 enum 클래스 다루기](#44-when-으로-enum-클래스-다루기)
* [5. enum](#5-enum)
  * [5.1. enum 기본](#51-enum-기본)
  * [5.2. enum 에 멤버 함수나 멤버 프로퍼티 정의](#52-enum-에-멤버-함수나-멤버-프로퍼티-정의)
* [6. data 클래스](#6-data-클래스)
  * [`toString()`: 문자열 표현](#tostring-문자열-표현)
  * [`equals()`: 객체의 동등성](#equals-객체의-동등성)
  * [`hashCode()`: 해시 컨테이너](#hashcode-해시-컨테이너)
  * [6.1. data 클래스 기본](#61-data-클래스-기본)
  * [6.2. 일반 클래스와 data 클래스 비교](#62-일반-클래스와-data-클래스-비교)
  * [6.2. data 클래스의 `copy()`](#62-data-클래스의-copy)
  * [6.3. HashMap, HashSet: `hashCode()`](#63-hashmap-hashset-hashcode)
* [7. 구조 분해 (destructuring) 선언](#7-구조-분해-destructuring-선언)
  * [7.1. `Pair` 클래스와 구조 분해 선언](#71-pair-클래스와-구조-분해-선언)
  * [7.2. data 클래스의 구조 분해](#72-data-클래스의-구조-분해)
  * [7.2. for 문으로 구조 분해값 조회](#72-for-문으로-구조-분해값-조회)
  * [7.3. `withIndex()`](#73-withindex)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 확장 함수 (extension function)

코틀린 확장 함수는 클래스 밖에 선언되지만 기존 클래스에 멤버 함수를 추가하는 것과 같은 효과를 낸다.  
예를 들어 특정 라이브러리를 사용하는데 한 두가지의 기능만 더 추가해야 하는 경우 확장 함수 기능을 이용할 수 있다.

**확장할 대상 타입(클래스)은 수신 객체 타입 (receiver type)** 이라고 하며, **확장 함수를 정의하기 위해서는 함수 이름 앞에 수신 객체 타입**을 붙여야 한다.  
**확장 함수가 호출되는 대상이 되는 값(객체) 는 수신 객체 (receiver object)** 라고 한다.  

**즉, 수신 객체 타입은 확장이 정의될 클래스 타입이고, 수신 객체는 그 클래스에 속한 인스턴스 객체**이다.

`fun 수신객체타입.확장함수() {...}`

```kotlin
fun String.lastChar(): Char = this.get(this.length-1)

// String 이 수신 객체 타입이고, "Kotlin" 이 수신 객체임
println("Kotlin".lastChar())
```

위 코드에서 String 은 수신 객체 타입이고, this 는 수신 객체이다.

위처럼 자바 클래스로 컴파일한 클래스 파일이 있는 한 그 클래스에 원하는대로 확장 함수를 추가할 수 있다.

아래는 String 클래스에 확장 함수 2개를 정의하는 예시이다.    
확장 함수인 singleQuota() 와 doubleQuota() 를 마치 수신 객체 타입인 String 의 멤버 함수인 것처럼 이용할 수 있다.  
즉, 수신 객체의 메서드나 프로퍼티를 바로 사용할 수 있다.  

하지만 확장 함수는 캡슐화를 깨지 않기 때문에 **클래스 안에서 정의한 메서드와 달리 확장 함수 안에서는 클래스 내부에서만 사용 가능한 private, protected 멤버는 사용할 수 없다.**

즉, **확장 함수는 확장 대상 타입(=수신 객체 타입) 의 public 원소에만 접근**할 수 있다.

```kotlin
fun String.singleQuota() = "'$this'"
fun String.doubleQuota() = "\"$this\""

fun main() {
    val single = "Hello".singleQuota()
    val double = "Hello".doubleQuota()

    println(single) // 'Hello'
    println(double) // "Hello"
}
```

`this` 키워드로 멤버 함수나 다른 확장에 접근할 수 있는데, 클래스 내부에서 `this` 를 생략하는 것처럼 확장 함수 안에서도 `this` 를 생략할 수 있다.

```kotlin
// singleQuota 를 2번 적용하여 작은 따옴표 2개 붙임
// this 는 String 수신 객체 타입에 속하는 객체를 가리킴
fun String.twoSingleQuota() = this.singleQuota().singleQuota()

// doubleQuota() 함수 호출 시 수신 객체(this) 생략
fun String.twoDoubleQuota() = doubleQuota().doubleQuota()

fun main() {
    val result1 = "Hello".twoSingleQuota()
    val result2 = "Hello".twoDoubleQuota()

    println(result1)    // ''Hello''
    println(result2)    // ""Hello""
}
```

상황에 따라 클래스에 대해 확장을 정의하는 것이 더 코드가 간결해지기도 한다.

```kotlin
class Book(val title: String)

// 확장 함수
fun Book.categorize(category: String) = """title: "$title", category: $category"""

// 위와 동일한 기능을 함
fun categorize2(book: Book, category: String) = """title: "${book.title}", category: $category"""

fun main() {
    val result = Book("Assu").categorize("Silby")
    val result2 = categorize2(Book("Assu"), "Silby")

    // title: "Assu", category: Silby
    println(result)
    // title: "Assu", category: Silby
    println(result2)
}
```

위에서 Book.categorize(category: String) 은 categorize2(book: Book, category: String) 로 쓸 수 있다.  
하지만 확장 함수를 사용하는 이유는 오로지 `this` 를 사용함 (또는 생략) 으로써 구문의 편의를 얻기 위해서이다.

---

## 1.1. import 와 확장 함수: `as`


```kotlin
// 다른 패키지에서는 임포트해서 사용함
import assu.study.kotlin_me.chap03.singleQuota

fun main() {
    val result = "Single".singleQuota()
    println(result) // 'Single'
}
```

**`as` 키워드를 사용하면 임포트한 클래스나 함수를 다른 이름으로 호출**할 수도 있다.

```kotlin
// 다른 패키지에서는 임포트해서 사용함
import assu.study.kotlin_me.chap03.singleQuota as single

fun main() {
    val result = "Single".single()
    println(result) // 'Single'
}
```

**하나의 파일 안에서 여러 패키지에 속해있는 이름이 같은 함수를 가져와 사용할 때 이름을 바꿔서 import 하면 이름 충돌을 막을 수 있다.**

패키지를 포함한 전체 이름을 써도 되지만 코틀린 문법상 확장 함수는 반드시 짧은 이름을 써야 하므로 import 할 때 이름을 바꾸는 것이 확장 함수 이름 충돌을 해결할 수 있는 
유일한 방법이다.

---

## 1.2. 자바에서 확장 함수 호출

**내부적으로 확장 함수는 수신 객체를 첫 번째 인자로 받는 정적 메서드이므로 확장 함수를 호출한다고 해서 실행 시점에 부가 비용이 들지 않는다.**

이런 내부적인 설계 때문에 자바에서 확장 함수를 사용할 때 단지 정적 메서드를 호출하면서 첫 번째 인자로 수신 객체를 넘기기만 하면 된다.

다른 최상위 함수와 마찬가지로 확장 함수가 들어있는 자바 클래스 이름도 확장 함수가 포함된 파일 이름에 따라 결정된다.

만일 Util.kt 에 확장 함수를 정의했다면 자바에서 아래와 같이 호출하면 된다.

자바
```java
char c = UtilKt.lastChar("java");
```

---

# 2. 이름 붙은 인자와 디폴트 인자, trailing comma

## 2.1. 이름 붙은 인자

함수를 호출하면서 인자의 이름을 지정하면 가독성이 좋아진다.

```kotlin
fun color(red: Int, yellow: Int, blue: Int) = "$red, $yellow, $blue"

fun main() {
    // 가독성이 좋지 못하여 함수를 직접 살펴봐야 함
    val result1 = color(1, 2, 3)

    // 모든 인자의 의미가 명확함
    val result2 = color(
        red = 1,
        yellow = 2,
        blue = 3
    )

    // 모든 인자에 이름을 붙이지 않아도 됨
    val result3 = color(1, 2, blue = 3)

    // 인자에 이름을 붙이면 순서를 변경하여 함수 호출 가능
    val result4 = color(blue = 3, red = 1, yellow = 2)

    // 일부만 인자에 이름을 붙여서 호출 가능
    val result5 = color(red = 1, 2, 3)
    
    //val result6 = color(blue = 3, 1, 2) // 오류, 일부만 이름을 붙이려면 순서를 지켜야 함

    println(result1)    // 1, 2, 3
    println(result2)    // 1, 2, 3
    println(result3)    // 1, 2, 3
    println(result4)    // 1, 2, 3
    println(result5)    // 1, 2, 3
}
```

---

## 2.1. 디폴트 인자, trailing comma: `trimMargin()`

이름 붙은 인자는 디폴트 인자와 사용하면 더 유용하다.  
디폴트 인자는 파라미터의 디폴트 값을 함수 정의에서 지정하는 것이다.  
인자 목록이 긴 경우 **디폴트 인자를 생략하면 코드가 짧아지므로 가독성**이 좋아진다.

일반적인 호출 문법을 사용하려면 함수를 선언할 때와 같은 순서로 인자를 지정하거나 일부를 생략하면 뒷부분의 인자들이 생략되지만 
**이름 붙인 인자를 사용하면 인자 목록의 중간에 있는 인자를 생략하고 지정하고 싶은 인자를 이름을 붙여서 순서와 관계없이 인자 지정이 가능**하다.

```kotlin
// blue 뒤에 덧붙은 콤마(trailing comma) 사용
fun color2(
    red: Int = 0,
    yellow: Int = 0,
    blue: Int = 0,
) = "$red, $yellow, $blue"

fun main() {
    val result1 = color2(1)
    val result2 = color2(blue = 2)
    var result3 = color2(1, 2)
    var result4 = color2(red = 1, blue = 2)

    println(result1)    // 1, 0, 0
    println(result2)    // 0, 0, 2
    println(result3)    // 1, 2, 0
    println(result4)    // 1, 0, 2
}
```

위 코드를 보면 color2() 정의할 때 맨 뒤에 `trailing comma` 를 사용했다.  
trailing comma 는 마지막 파라미터인 blue 뒤에 콤마를 추가로 붙인 것인데, **파라미터 값을 여러 줄에 걸쳐 쓰는 경우 trailing comma 가 유용**하다.  
**trailing comma 가 있으면 콤마를 추가하거나 빼지 않아도 새로운 아이템을 추가하거나 아이템의 순서를 변경**할 수 있다.

**이름 붙은 인자, 디폴트 인자, trailing comma 는 생성자에도 사용 가능**하다.
```kotlin
class Color(
    val red: Int = 0,
    val yellow: Int = 0,
    val blue: Int = 0,
) {
    override fun toString() = "$red, $yellow, $blue"
}

fun main() {
    // 생성자에 이름 붙은 인자와 디폴트 인자 사용
    val result = Color(red = 1).toString()

    println(result) // 1, 0, 0
}
```

디폴트 인자의 다른 예로 여러 줄의 String 형식을 맞춰주는 표준 라이브러리인 `trimMargin()` 예시를 보자.

`trimMargin()`
- 각 줄의 시작 부분을 인식하기 위한 경계를 표현하는 접두사 String 을 파라미터로 받아서 사용
- 소스 String 의 각 줄 맨 앞에 있는 공백들 다음에 지정한 접두사 String 까지를 잘라내서 문자열을 다듬음
- 이 후 여러 줄 문자열의 첫 번째 줄과 마지막 줄 중에 공백으로만 이루어진 줄은 제거함

```kotlin
fun main() {
    val poem = """
        |->첫 번째 줄인데요,
        |->두 번째 줄이에요
    """

    // | 가 marginPrefix 의 디폴트 인자값임
    val result1 = poem.trimMargin()
    // ->첫 번째 줄인데요,
    // ->두 번째 줄이에요
    println(result1)

    // marginPrefix 의 디폴트 인자값인 | 를 |-> 로 변경함
    val result2 = poem.trimMargin(marginPrefix = "|->")
    // 첫 번째 줄인데요,
    // 두 번째 줄이에요
    println(result2)
}
```

---

### 디폴트 값과 자바: `@JvmOverloads`

자바에는 디폴트 파라미터 개념이 없기 때문에 코틀린 함수를 자바에서 호출하는 경우 코틀린 함수가 디폴트 파라미터 값을 제공하더라도 모든 인자를 명시해야 한다.

만일 자바에서 코틀린 함수를 자주 호출한다면 자바쪽에서 코틀린 함수를 좀 더 편하게 호출하도록 `@JvmOverloads` 를 함수에 추가하면 된다.

`@Jvmoverloads` 를 함수에 추가하면 코틀린 컴파일러가 자동으로 맨 마지막 파라미터로부터 파라미터를 하나씩 생략한 오버로딩한 자바 메서드를 추가해준다.

각각의 오버로딩한 함수들은 시그니처에서 생략된 파라미터에 대해 코틀린 함수의 디폴트 파라미터값을 사용한다.

---

## 2.3. `joinToString()`

`joinToString()` 은 디폴트 인자를 사용하는 표준 라이브러리로, 이터레이션이 가능한 객체인 List, Set, Range 등의 내용을 String 으로 합쳐준다. 

이 때 원소 사이에 들어간 구분자나 맨 앞에 붙일 접두사, 맨 뒤에 붙일 접미사를 지정할 수도 있다.

```kotlin
fun main() {
    // 리스트의 toString() 디폴트 구현은 원소를 콤마로 구분하여 반환
    val list = listOf(1, 2, 3)
    println(list)  // [1, 2, 3]

    val result1 = list.joinToString()
    val result2 = list.joinToString(prefix = "(", postfix = ")")
    val result3 = list.joinToString(separator = ":")

    println(result1)    // 1, 2, 3
    println(result2)    // (1, 2, 3)
    println(result3)    // 1:2:3
}
```

---

## 2.4. 객체 인스턴스를 디폴트 인자로 전달

객체 인스턴스를 디폴트 인자로 전달하는 경우 해당 함수를 호출할 때마다 같은 인스턴스가 반복해서 전달된다.  
_예) 아래에서 g() 함수에서 cda 가 디폴트 인자이고, g() 를 호출할 때마다 같은 인스턴스가 반복해서 전달됨_

디폴트 인자로 함수 호출, 생성자 호출 등에 사용하는 경우 해당 함수를 호출할 때마다 해당 객체의 새로운 인스턴스가 생기거나 디폴트 인자에서 호출하는 함수가 호출된다.  
_예) 아래에서 h() 함수에서 CustomDefaultArg() 가 디폴트 인자이고, h() 를 호출할 때마다 새로운 인스턴스가 생성됨_

```kotlin
class CustomDefaultArg

val cda = CustomDefaultArg()

// 디폴트 인자로 객체 인스턴스 전달
fun g(d: CustomDefaultArg = cda) = println(d)

// 디폴트 인자로 함수를 호출
fun h(d: CustomDefaultArg = CustomDefaultArg()) = println(d)

fun main() {
    g()
    g()
    h()
    h()
}
```

```shell
// g() 는 여러 번 호출해도 같은 인스턴스가 반복해서 전달됨
//assu.study.kotlin_me.chap03.CustomDefaultArg@10f87f48
//assu.study.kotlin_me.chap03.CustomDefaultArg@10f87f48

// h() 는 호출할 때마다 새로운 인스턴스가 생성됨
//assu.study.kotlin_me.chap03.CustomDefaultArg@b4c966a
//assu.study.kotlin_me.chap03.CustomDefaultArg@2f4d3709
```

---

## 2.5. 가독성을 고려하여 인자 이름 붙이기

인자 이름을 붙일 때는 가독성이 향상되는 경우에만 붙이는 것이 좋다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3)

    // 각 파라미터가 무엇을 의미하는지 알 수 없어서 비실용적인 코드
    var list1 = list.joinToString(". ", "", "!")

    // 각 파라미터의 의미가 확실하여 실용적인 코드
    var list2 = list.joinToString(separator = ". ", postfix = "!")

    println(list)   // [1, 2, 3]
    println(list1)  // 1. 2. 3!
    println(list2)  // 1. 2. 3!
}
```

---

# 3. 오버로딩

## 3.1. 오버로딩 기본

아래는 오버로딩의 기본 예시이다.

```kotlin
class Overloading {
    fun f1() = 0
    fun f1(n: Int) = n + 2
}

fun main() {
    val o = Overloading()
    val result1 = o.f1()
    val result2 = o.f1(1)

    println(result1)    // 0
    println(result2)    // 3
}
```

**함수의 시그니처는 함수 이름, 파라미터 목록, 반환 타입**으로 이루어진다.  
**함수를 오버로딩 할 때는 함수 파라미터 목록을 다르게 만들어야 하며, 함수의 반환 타입은 오버로딩의 대상이 아니다.**

**함수 시그니처는 함수를 둘러싸고 있는 클래스(확장 함수의 경우 수신 객체 타입)도 포함**된다.

---

## 3.2. 클래스 안의 확장 함수가 있는 경우의 오버로딩

**클래스 안에 확장 함수와 시그니처가 같은 멤버 함수가 있다면 코틀린은 멤버 함수를 우선시** 한다.  
하지만 확장 함수를 통해 멤버 함수를 오버로딩할 수 있다.

```kotlin
class Dog {
    fun foo() = 0
}

// 멤버 함수와 시그니처가 중복되는 확장 함수는 의미없음
fun Dog.foo() = 1

// 다른 파라미터 목록을 제공함으로써 멤버 함수를 확장 함수로 오버로딩함
fun Dog.foo(i: Int) = i + 2

fun main() {
    val result1 = Dog().foo()
    val result2 = Dog().foo(1)

    println(result1)    // 0
    println(result2)    // 3
}
```

---

## 3.3. 디폴트 인자를 흉내내기 위한 확장 함수

**디폴트 인자를 흉내내기 위해 확장 함수를 사용하면 안된다.**

```kotlin
// 추천하지 않는 코드임
// 결국 파라미터가 없는 함수만 호출할 뿐임

fun f(n: Int) = n + 1
fun f() = f(2)

fun main() {
    val result = f()

    println(result) // 3
}
```

아래와 같이 디폴트 인자를 사용해 위의 두 함수를 하나의 함수로 사용할 수 있다.

```kotlin
fun f3(n: Int = 2) = n + 1

fun main() {
    val result = f()

    println(result) // 3
}
```

---

## 3.4. 오버로딩과 디폴트 인자를 함께 사용하는 경우

함수의 오버로딩과 디폴트 인자를 함께 사용하는 경우, 오버로딩한 함수를 호출하면 함수 시그니처와 함수 호출이 **가장 가깝게** 일치되는 함수를 호출한다.

```kotlin
fun foo(n: Int = 1) = println("foo-1-$n")

fun foo() {
    println("foo-2")
    foo(12)
}

fun main() {
    // 디폴트 인자가 있는 foo(n: Int = 1) 을 호출하지 않고, 파라미터가 없는 foo() 함수만 호출하
    foo()
    // foo-2
    // foo-1-12
}
```

위와 같은 경우 foo() 는 항상 두 번째 함수를 호출하기 때문에 디폴트 인자인 1을 활용할 수 없다.

---

## 3.5. 오버로딩이 유용한 이유

오버로딩을 사용하면 '같은 주제를 다르게 사용한다' 라는 개념을 명확히 표현할 수 있다.

아래 예시를 보자.
```kotlin
// 오버로딩하지 않고 각각의 함수를 만든 경우
fun addInt(i: Int, j: Int) = i + j
fun addDouble(i: Double, j: Double) = i + j

// add 함수를 오버로딩한 경우
fun add(i: Int, j: Int) = i + j
fun add(i: Double, j: Double) = i + j

fun main() {
    val result1 = addInt(1, 2)
    val result2 = add(1, 2)

    val result3 = addDouble(1.1, 2.2)
    var result4 = add(1.1, 2.2)

    println(result1)    // 3
    println(result2)    // 3
    println(result3)    // 3.3000000000000003
    println(result4)    // 3.3000000000000003
}
```

이렇게 add() 를 오버로딩하면 훨씬 코드가 깔끔하다.

오버로딩을 사용하면 함수 자체에 대해 설명하는 이름을 써서 추상화 수준을 높일 수 있고, 불필요한 중복을 줄여준다.  
addInt(), addDouble() 는 함수 파라미터에 있는 정보를 함수 이름에 반복하는 것일 뿐이다.

---

# 4. when 식

자바의 switch 를 대치한다.

when 과 if 중 when 이 더 유연하기 때문에 선택의 여지가 있다면 when 을 사용하는 것을 권장한다.

## 4.1. when 기본

```kotlin
val numbers = mapOf(
    1 to "one", 2 to "two",
    3 to "three", 4 to "four"
)

fun ordinal(i: Int): String =
    when (i) {
        1 -> "oneone"
        2 -> "twotwo"
        3 -> "threethree"
        else -> numbers.getValue(i) + "haha"
    }

fun main() {
    val result1 = ordinal(2)
    val result2 = ordinal(4)

    println(result1)    // twotwo
    println(result2)    // fourhaha
}
```

위에서 `else` 가 없으면 컴파일 타입 오류가 발생한다.  
만일 when 식을 문처럼 취급(when 의 결과를 사용하지 않는 경우)에만 else 를 생략할 수 있다.

아래는 when 의 또 다른 예시이다.

```kotlin
class Coordinates {
    var x: Int = 0
        set(value) {
            println("x get $value")
            field = value
        }
    var y: Int = 0
        set(value) {
            println("y get $value")
            field = value
        }

    override fun toString() = "($x, $y)"
}

fun progressInputs(inputs: List<String>) {
    val coordinates = Coordinates()
    for (input in inputs) {
        when (input) {
            "up", "u" -> coordinates.y--    // 콤마를 써서 여러 가지 값 나열 가능, up 혹은 u 가 들어올 때 실행됨
            "down", "d" -> coordinates.y++
            "left", "l" -> coordinates.x--
            "right", "r" -> {
                println("moving right")
                coordinates.x++
            }

            "nowhere" -> {} // 아무일도 하지 않을 경우엔 빈 중괄호 사용
            "exit" -> return
            else -> println("bad input: $input")
        }
    }
}

fun main() {
    val result = progressInputs(listOf("up", "d", "nowhere", "left", "right", "exit", "r"))

    println(result)
    //y get -1
    //y get 0
    //x get -1
    //moving right
    //x get 0
    //kotlin.Unit
}
```

---

## 4.2. when 으로 Set 과 Set 을 매치

```kotlin
fun mixColors(first: String, second: String) =
    when (setOf(first, second)) {
        setOf("red", "blue") -> "one"
        setOf("red", "yellow") -> "two"
        else -> "unknown"
    }

fun main() {
    val result1 = mixColors("red", "blue")
    val result2 = mixColors("red", "red")

    println(result1)    // one
    println(result2)    // unknown
}
```

---

## 4.3. 인자가 없는 when

[4.2. when 으로 Set 과 Set 을 매치](#42-when-으로-set-과-set-을-매치) 의 경우 함수가 호출될 때마다 함수 인자로 주어진 조건을 검사하기 위해 여러 Set 인스턴스를 생성한다.  
이 함수가 자주 호출된다면 불필요한 가비지 객체가 늘어나는 것을 방지하기 위해 인자가 없는 when 식을 사용하는 것이 좋다.  
**인자가 없는 when 식을 사용하면 가독성은 낮아지지만 불필요한 객체 생성을 막을 수 있기 때문에 성능이 향상**된다.

인자가 없는 when 은 각 조건을 Boolean 조건에 따라 검사한다는 의미이다.  
따라서 **인자가 없는 when 에서는 화살표 왼쪽의 식에 항상 Boolean 타입의 식**을 적어야 한다.

아래는 if 문을 사용했을 경우와 인자가 없는 when 을 사용하는 경우의 예시이다.

```kotlin
// if 문 사용
fun ff(kg: Double, height: Double): String {
    val bmi = kg / (height * height)
    return if (bmi < 18.5) "under weight"
    else if (bmi < 25) "normal weight"
    else "over weight"
}

// 인자가 없는 when 사용
fun ffWithWhen(kg: Double, height: Double): String {
    val bmi = kg / (height * height)
    return when {
        bmi < 18.5 -> "under weight"
        bmi < 25 -> "normal weight"
        else -> "over weight"
    }
}

fun main() {
    val result1 = ff(70.1, 1.8)
    val result2 = ffWithWhen(70.1, 1.8)

    println(result1)    // normal weight
    println(result2)    // normal weight
}
```

위와 같이 인자가 없는 when 을 사용하면 추가 객체를 만들지않지만 가독성이 더 떨어진다는 단점이 있다.  

when 식에서 스마트 캐스트를 사용하면 좀 더 효율적인 로직을 짤 수 있다.

> 스마트 캐스트에 대한 좀 더 상세한 내용은 [2.1. 스마트 캐스트: `is`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#21-%EC%8A%A4%EB%A7%88%ED%8A%B8-%EC%BA%90%EC%8A%A4%ED%8A%B8-is) 를 참고하세요.

---

## 4.4. when 으로 enum 클래스 다루기

```kotlin
package com.assu.study.kotlin2me.chap02

enum class Color(val r: Int, val g: Int, val b: Int) {
    // 상수의 프로퍼티 정의
    // 각 상수 생성 시 그에 대한 프로퍼티값 지정
    RED(255, 0, 0),
    ORANGE(255, 165, 0),
    GREEN(0, 255, 0),
    ;

    // 추가 메서드 정의
    fun rgb() = (r * 256 + g) * 256 + b
}

fun getColor(color: Color) =
    // 함수 반환값으로 when 식을 직접 사용
    when (color) { // 특정 enum 상수와 같을 때
        Color.RED, Color.GREEN -> "red green~"
        Color.ORANGE -> "orange~"
    }

fun main() {
    println(getColor(Color.RED)) // red~
}
```

자바와 달리 각 분기의 끝에 break 를 넣지 않아도 된다.

---

# 5. enum

## 5.1. enum 기본

enum 을 만들면 enum 이름에 해당하는 문자열을 돌려주는 toString() 이 생성된다.

```kotlin
enum class Level {
    OVER, HIGH, MEDIUM, LOW, EMPTY
}

fun main() {
    println(Level.MEDIUM)   // MEDIUM
}
```

```kotlin
// * 를 이용하여 Level 의 모든 이름을 임포트하면 사용할 때 Level 이라는 이름을 사용하지 않음
import assu.study.kotlin_me.chap03.enums.Level.*

fun main() {
    println(MEDIUM)
}
```

enum 클래스가 정의된 파일에서 enum 값을 임포트할 수도 있다.

```kotlin
// Size 정의가 들어있는 파일에서 Size 안의 이름을 Size 정의보다 먼저 임포트함
import assu.study.kotlinme.chap03.enums.Size.LARGE
import assu.study.kotlinme.chap03.enums.Size.SMALL

enum class Size {
  TINY,
  SMALL,
  LARGE,
}

fun main() {
  // import 를 하고 나면 enum 이름을 한정시키지 않아도 됨
  println(SMALL)
  // SMALL

  // values() 를 사용하여 enum 의 값을 이터레이션함
  // values() 는 Array 를 반환하기 때문에 toList() 를 호출하여 배열을 List 로 만듬
  println(Size.values())  // [Lassu.study.kotlinme.chap03.enums.Size;@3d494fbf
  println(Size.values().toList()) // [TINY, SMALL, LARGE]
  // [TINY, SMALL, LARGE]

  println(LARGE.ordinal)
  // 2
}
```

---

## 5.2. enum 에 멤버 함수나 멤버 프로퍼티 정의

enum 은 인스턴스 개수가 미리 정해져있고, 클래스 본문 안에 이 모든 인스턴스가 나열되어 있는 특별한 종류의 클래스인데 이 점을 제외하면 일반 클래스와 똑같이 동작한다.  
따라서 멤버 함수나 멤버 프로퍼티를 enum 에 정의할 수도 있다.

만약 추가 멤버를 정의하고 싶다면 마지막 enum 값에 세미콜론을 추가한 후 정의를 포함시키면 된다.

```kotlin
enum class Direction(val notation: String) {    // 상수의 프로퍼티 정의
    // 각 상수를 생성할 때 그에 대한 프로퍼티 값 지정
    North("N"), South("S"); // 세미 콜론이 꼭 필요함

    // 추가 멤버
    val opposite: Direction
        get() = when (this) {
            North -> South
            South -> North
        }
  
}

fun main() {
    // N
    println(Direction.North.notation)
    // South
    println(Direction.North.opposite)
    // South
    println(Direction.South.opposite.opposite)
    // N
    println(Direction.South.opposite.notation)
}
```

```kotlin
enum class Color(val r: Int, val g: Int, val b: Int) {  // 상수의 프로퍼티 정의
    // 각 상수 생성 시 그에 대한 프로퍼티값 지정
    RED(255, 0, 0),
    ORANGE(255, 165, 0),
    ;

    // 추가 메서드 정의
    fun rgb() = (r * 256 + g) * 256 + b
}
```

---

# 6. data 클래스

<**data 클래스 생성 시 추가되는 기능들**>
- `toString()`: 클래스의 각 필드를 선언 순서대로 표시하는 문자열 표현을 만들어 줌
- `equals()`: 모든 프로퍼티 값의 동등성 확인
- `hashCode()`: 모든 프로퍼티의 해시 값을 바탕으로 계산한 해시 값 반환
- `copy()`

data 클래스에 대해 알아보기 전에 먼저 위 함수들에 대해 간략히 살펴본다.

> data 클래스 생성 시 제공되는 메서드가 더 있는데 이에 대한 내용은  
> [7.2. data 클래스의 구조 분해](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#72-data-%ED%81%B4%EB%9E%98%EC%8A%A4%EC%9D%98-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4),  
> [2.4. 구조 분해 연산자: `componentN()`](https://assu10.github.io/dev/2024/03/23/kotlin-advanced-3/#24-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4-%EC%97%B0%EC%82%B0%EC%9E%90-componentn)  
> 를 참고하세요.

---

## `toString()`: 문자열 표현

기본 제공되는 객체의 문자열 표현은 Client@43243 이런 형식인데 이 기본 구현을 변경하려면 `toString()` 메서드를 오버라이드하면 된다.
```kotlin
class Client(
    val name: String,
    val postalCode: Int,
) {
    override fun toString(): String = "Client(name='$name', postalCode=$postalCode)"
}

fun main() {
    val result1 = Client("AA", 123)

    // toString() 이 없을 경우: com.assu.study.kotlin2me.chap04.Client@41629346 이렇게 출력됨
    // toString() 이 있을 경우: Client(name='AA', postalCode=123)
    println(result1)
}
```

---

## `equals()`: 객체의 동등성

예를 들어 서로 다른 두 객체가 내부에 동일한 데이터를 갖는 경우 그 둘을 동등한 객체로 보아야할 때가 있다.

```kotlin
class Client(
    val name: String,
    val postalCode: Int,
) {
    override fun toString(): String = "Client(name='$name', postalCode=$postalCode)"
}

fun main() {
    val client1 = Client("BB", 111)
    val client2 = Client("BB", 111)
  
    println(client1 == client2) // false
}
```

코틀린에서 `==` 연산자는 참조 동일성을 검사하는 것이 아니라 객체의 동등성을 검사한다.  
따라서 `==` 연산은 `equals()` 를 호출하는 식으로 컴파일된다.

따라서 위의 요구사항을 충족시키려면 `equals()` 메서드를 오버라이드하면 된다.

```kotlin
class Client(
    val name: String,
    val postalCode: Int,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Client

        if (name != other.name) return false
        if (postalCode != other.postalCode) return false

        return true
    }

    override fun hashCode(): Int {
        var result = name.hashCode()
        result = 31 * result + postalCode
        return result
    }
}
```

하지만 위와 같이 `equals()` 를 오버라이드해도 두 객체의 값은 동일하다고 나오지 않는데 그 이우는 `hashCode()` 를 오버라이드하지 않았기 때문이다.

> **`==` 과 `equals()`**  
> 
> 자바에서는 `==` 를 primitive 타입과 참조 타입을 비교할 때 사용함  
> primitive 타입의 경우 `==` 는 두 피연산자의 값이 같은지 비교함 (동등성, equality)  
> 반면 참조 타입의 경우 `==` 는 두 피연산자의 주소가 같은지 비교함 (참조 비교, reference comparision)  
> 따라서 자바에서는 두 객체의 동등성을 알려면 `equals()` 를 호출해야 함  
> 자바에서 `equals()` 대신 `==` 를 호출하면 문제가 될 수도 있음
> 
> 코틀린에서는 `==` 연산자가 두 객체를 비교하는 기본적인 방법임  
> `==` 는 내부적으로 `equals()` 를 호출해서 객체를 비교함  
> 따라서 **클래스가 `equals()` 를 오버라이드하면 `==` 를 통해 안전하게 그 클래스의 인스턴스를 비교**할 수 있음  
> **참조 비교를 위해서는 `===` 연산자를 사용**하면 됨

---

## `hashCode()`: 해시 컨테이너

자바에서는 `equals()` 를 오버라이드할 때 반드시 `hashCode()` 도 오버라이드해야 한다.

JVM 언어에서는 아래와 같은 hashCode 가 지켜야하는 제약이 있다.  
> equals() 가 true 를 반환하는 두 객체는 반드시 같은 hashCode() 를 반환해야 한다.

따라서 `hashCode()` 를 오버라이드하면 두 객체의 값이 같은 경우 동등하다고 판단한다.

```kotlin
class Client(
    val name: String,
    val postalCode: Int,
) {
    override fun toString(): String = "Client(name='$name', postalCode=$postalCode)"

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Client

        if (name != other.name) return false
        if (postalCode != other.postalCode) return false

        return true
    }

    override fun hashCode(): Int {
        var result = name.hashCode()
        result = 31 * result + postalCode
        return result
    }
}

fun main() {
    val client1 = Client("BB", 111)
    val client2 = Client("BB", 111)
    println(client1 == client2) // true
}
```

코틀린은 data 클래스를 통해 위의 함수들을 자동으로 생성해준다.

---

## 6.1. data 클래스 기본

데이터 저장만 담당하는 클래스가 필요하면 data 클래스를 사용하여 코드양을 줄이면서 여러 공통 작업을 편하게 수행할 수 있다.  
`data` 라는 키워드를 사용하여 data 클래스를 정의하면 몇 가지 기능이 클래스에 추가가 된다.  

이 때 **모든 생성자 파라미터를 var 나 val 로 선언**해야 한다.

```kotlin
data class Simple(
    val arg1: String,
    var arg2: Int
)

fun main() {
    val s1 = Simple("A", 1)
    val s2 = Simple("A", 1)

    println(s1) // Simple(arg1=A, arg2=1)
    println(s2) // Simple(arg1=A, arg2=1)
    println(s1.equals(s2))  // true
    println(s1 == s2)   // true
}
```

data 클래스는 `toString()` 코드를 추가로 작성하지 않아도 객체를 보기 쉬운 형태로 표현해준다.  

같은 데이터를 포함하는 같은 data 클래스 인스턴스를 2개 만들면 두 인스턴스가 동등하다고 기대할 것이다.  
일반적인 클래스에서 이런 동작을 구현하려면 인스턴스를 비교하는 `equals()` 라는 멤버 함수를 정의해야 하지만 data 클래스는 `equals()` 가 자동으로 생성된다.

---

## 6.2. 일반 클래스와 data 클래스 비교

```kotlin
class Person(val name: String)

data class Contact(val name: String)

fun main() {
  val result1 = Person("Assu")
  val result2 = Person("Assu")

  // 위 2개의 일반 클래스는 같지 않음
  println(result1.equals(result2))    // false
  println(result1)    // assu.study.kotlin_me.chap03.dataclass.Person@10f87f48

  val result3 = Contact("Assu")
  val result4 = Contact("Assu")

  // 위 2개의 data 클래스는 같음
  println(result3.equals(result4))    // true
  println(result3)    // Contact(name=Assu)
}
```

data 클래스와 객체 정보를 디폴트 형태로 보여주는 일반 클래스의 표현 방법에도 차이가 있음을 알 수 있다.

---

## 6.2. data 클래스의 `copy()`

data 클래스의 프로퍼티를 val 가 아닌 var 로 해도 되지만 data 클래스의 모든 프로퍼티를 읽기 전용으로 만들어서 data 클래스를 불변 클래스로 만드는 것을 권장한다.

HashMap 등의 컨테이너에 data 클래스 객체를 담는 경우엔 불변성이 필수적이며, 특히 다중 스레드 프로그램의 경우 불변성은 더욱 중요하다.  
불변 객체를 주로 사용하는 프로그램에서는 스레드가 사용 중인 데이터를 다른 스레드가 변경할 수 없으므로 스레드를 동기화해야 할 필요성이 줄어든다.

data 클래스 인스턴스를 불변 객체로 더 쉽게 활용하기 위해 코틀린 컴파일러는 `copy()` 메서드를 제공한다.

data 클래스 생성 시 `copy()` 함수도 함께 생성된다.  
`copy()` 함수는 현재 객체의 모든 데이터를 포함하는 새로운 객체를 생성해주고, 새로운 객체를 생성할 때 일부 값을 새로 지정할 수도 있다.  
객체를 메모리상에서 직접 바꾸는 대신 복사본을 만드는 편이 낫다.  
복사본은 원본과 다른 생명주기를 가지며, 복사본은 변경하거나 제거해도 원본을 참조하는 다른 부분에 전혀 영향을 끼치지 않는다.

```kotlin
data class Assu(
    val name: String,
    val number: String
)

fun main() {
    val assu = Assu("assu", "010-111-2222")
    val newAssu = assu.copy(name = "silby")

    println(assu)   // Assu(name=assu, number=010-111-2222)
    println(newAssu)    // Assu(name=silby, number=010-111-2222)
}
```

---

## 6.3. HashMap, HashSet: `hashCode()`

data 클래스를 만들면 HashMap 이나 HashSet 에 넣을 때 키로 사용할 수 있는 해시 함수인 `hashCode()` 자동으로 생성해준다.

```kotlin
data class Key(val name: String, val id: Int)

fun main() {
    val aa: Key = Key("assu", 1)
    println(aa.hashCode())  // 93121645

    val map = HashMap<Key, String>()
    map[aa] = "assu1"
    println(map[aa].equals("assu1"))    // true

    val set = HashSet<Key>()
    set.add(aa)
    println(set.contains(aa))   // true
}
```

위 코드에서 HashMap, HashSet 에서는 `hashCode()` 를 `equals()` 와 함께 사용하여 Key 를 빠르게 검색한다.  

> `hashCode()` 를 `equals()` 에 대해서는 [1. 연산자 오버로딩: `operator`](https://assu10.github.io/dev/2024/03/23/kotlin-advanced-3/#1-%EC%97%B0%EC%82%B0%EC%9E%90-%EC%98%A4%EB%B2%84%EB%A1%9C%EB%94%A9-operator) 을 참고하세요.

---

# 7. 구조 분해 (destructuring) 선언

> [2.4. 구조 분해 연산자: `componentN()`](https://assu10.github.io/dev/2024/03/23/kotlin-advanced-3/#24-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4-%EC%97%B0%EC%82%B0%EC%9E%90-componentn) 와 함께 보면 도움이 됩니다.

구조 분해를 사용하면 복합적인 값을 분해해서 여러 다른 변수를 한꺼번에 초기화할 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap07

data class Point7(
    val x: Int,
    val y: Int,
)

fun main() {
    val p = Point7(10, 20)

    // x, y 변수를 선언한 다음 p 의 여러 컴포넌트로 초기화함
    val (x, y) = p

    println(x) // 10
    println(y) // 20
}
```

---

## 7.1. `Pair` 클래스와 구조 분해 선언

표준 라이브러리에 있는 Pair 클래스를 사용하면 2 개의 값을 반환할 수 있다.  
`Pair` 는 List 나 Set 처럼 파라미터화된 타입이다.

```kotlin
fun compute(input: Int): Pair<Int, String> =
    if (input > 5) {
        Pair(input * 2, "High")
    } else {
        Pair(input * 2, "Low")
    }

fun main() {
    println(compute(7)) // (14, High)
    println(compute(3)) // (6, Low)

    // Pair 의 값을 first, second 로 가져옴
    val result = compute(5)
    println(result.first) // 10
    println(result.second) // Low

    // 구조 분해 선언을 사용하여 여러 값을 동시에 가져옴
    val (value, desc) = compute(7)
    println(value) // 14
    println(desc) // High
}
```

위에서 아래와 같은 기능을 구조 분해 선언이라고 한다.

```kotlin
val (value, desc) = compute(7)
```

**코틀린은 Pair 와 3 개의 값을 묶는 Triple 클래스만 지원**한다. 만일 더 많은 값을 저장하고 싶거나 코드에서 Pair 와 Triple 을 많이 사용한다면 
각 상황에 맞는 특별한 클래스를 작성하여 사용한다.

위처럼 Pair\<Int, String\> 을 반환하는 것보다 아래의 예시처럼 Computation 이라는 data 클래스를 반환하는 것이 좋다.

> 이에 대한 내용은 바로 뒤에 나오는 [7.2. data 클래스의 구조 분해](#72-data-클래스의-구조-분해) 를 참고하세요.

```kotlin
data class Computation(
    val data: Int,
    val info: String,
)

fun eval(input: Int) =
    if (input > 5) {
        Computation(input * 2, "High")
    } else {
        Computation(input * 2, "Low")
    }

fun main() {
    val (value, desc) = eval(7)
    println(value)  // 14
    println(desc)   // High
}
```

결과값의 타입에 알맞는 이름을 붙여야 가독성이 좋아진다.    
그리고 Computation 클래스에 정보를 추가하거나 제거하는 것이 Pair 에 정보를 추가/제거하는 것보다 훨씬 쉽다.

> 식의 구조 분해와 구조 분해를 사용하여 여러 변수를 초기화하는 방법에 대한 규칙은  
> [7.2. data 클래스의 구조 분해](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#72-data-%ED%81%B4%EB%9E%98%EC%8A%A4%EC%9D%98-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4),  
> [2.4. 구조 분해 연산자: `componentN()`](https://assu10.github.io/dev/2024/03/23/kotlin-advanced-3/#24-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4-%EC%97%B0%EC%82%B0%EC%9E%90-componentn)  
> 를 참고하세요.

---

## 7.2. data 클래스의 구조 분해

data 클래스의 인스턴스를 구조 분해할 때는 data 클래스 생성자에 각 프로퍼티가 나열된 순서대로 값이 대입된다.

data 클래스의 주 생성자에 들어있는 프로퍼티에 대해서는 컴파일러가 자동으로 `componentN()` 함수를 만들어준다.

data 클래스의 프로퍼티는 이름에 의해 대입되는 것이 아니라 순서대로 대입이 된다.  
**어떤 객체를 구조 분해에 사용했는데 이후에 그 data 클래스에 맨 마지막이 아닌 위치에 프로퍼티를 추가하게 되면 새로운 프로퍼티가 기존에 다른 값을 대입받던 식별자에 대입이 되면서 
예상과 다른 결과**가 나올 수 있다.

```kotlin
data class Tuple(
    val i: Int,
    val d: Double,
    val s: String,
    val b: Boolean,
    val l: List<Int>,
)

fun main() {
    val tuple = Tuple(1, 1.1, "aa", true, listOf())
    val (i, d, s, b, l) = tuple

    println(i) // 1
    println(d) // 1.1
    println(s) // aa
    println(b) // true
    println(l) // []

    // 구조 분해 선언 시 선언할 식별자 중 일부가 필요하지 않으면 밑줄 _ 을 사용할 수 있고, 맨 뒤쪽의 이름들은 아예 생략 가능
    val (_, _, animal) = tuple
    println(animal) // aa
}
```

아래는 data 클래스가 아닌 일반 클래스에서 `componentN()` 함수를 구현하는 예시이다.

```kotlin
class Point(val x: Int, val y: Int) {
    operator fun component1() = x
    operator fun component2() = y
}
```

**구조 분해 선언은 함수에서 여러 값을 반환할 때 유용**하다.

여러 값을 한꺼번에 반환해야 하는 함수가 있다면 반환해야 하는 모든 값이 들어있는 data 클래스를 정의하고, 함수의 반환 타입을 그 data 클래스로 지정한다.

아래는 위의 동작을 보여주기 위해 파일 이름을 이름과 확장자로 나누는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap07

// 값을 저장하기 위한 data 클래스
data class NameComponents(
  val name: String,
  val extension: String,
)

fun splitFilename(fullName: String): NameComponents {
  val (name, ext) = fullName.split(".", limit = 2)
  return NameComponents(name, ext)
}

fun main() {
  val (name, ext) = splitFilename("test.txt")

  println(name) // test
  println(ext) // ext
}
```

---

## 7.2. for 문으로 구조 분해값 조회

for 문을 사용하여 `Pair`, `Triple` 이나 다른 data 클래스의 객체로 이루어진 Map, List 에 대해 이터레이션하면서 값의 각 부분을 구조 분해로 얻을 수 있다.

```kotlin
fun main() {
    var result = ""
    val map = mapOf(1 to "one", 2 to "two")
    for ((key, value) in map) {
        result += "$key = $value,"
    }
    // 1 = one,2 = two,
    println(result)

    result = ""
    val listOfPairs = listOf(Pair(1, "one"), Pair(2, "two"))
    for ((i, s) in listOfPairs) {
        result += "($i, $s),"
    }
    // (1, one),(2, two),
    println(result)
}
```

위에서 Map 에 대한 for 문은 아래의 확장 함수를 사용하는 코드와 동일하다.

```kotlin
for ((key, value) in map) {
    result += "$key = $value,"
}

for (entry in map.entries) {
    val key = entry.component1()
    val value = entry.copmonent2()
}
```

---

## 7.3. `withIndex()`

`withIndex()` 는 표준 라이브러리가 List 에 대해 제공하는 확장 함수이다.  
`withIndex()` 는 컬렉션의 값을 `IndexedValue` 라는 타입의 객체에 담아서 반환하여 이 객체를 구조 분해할 수 있다.

아래는 `withIndex()` 를 구조 분해 선언과 조합하여 컬렉션 원소의 인덱스와 값을 따로 변수에 담는 예시이다.

```kotlin
fun main() {
    val list = listOf('a', 'b', 'c')
    // 0:a
    // 1:b
    // 2:c
    for ((index, value) in list.withIndex()) {
        println("$index:$value")
    }
}
```

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