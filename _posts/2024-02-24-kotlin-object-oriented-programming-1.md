---
layout: post
title:  "Kotlin - 객체 지향 프로그래밍(1): 인터페이스, SAM(fun interface), init, 부생성자, 상속, 기반클래스 초기화"
date:   2024-02-24
categories: dev
tags: kotlin SAM init constructor open
---

이 포스트에서는 코틀린의 인터페이스, 복잡한 생성자, 부생성자, 상속, 기반 클래스의 초기화에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 인터페이스: `:`](#1-인터페이스-)
  * [1.1. 프로퍼티를 선언하는 인터페이스](#11-프로퍼티를-선언하는-인터페이스)
  * [1.2. 인터페이스를 구현하는 enum](#12-인터페이스를-구현하는-enum)
  * [1.3. 단일 추상 메서드 (Single Abstract Method, SAM): `fun interface`](#13-단일-추상-메서드-single-abstract-method-sam-fun-interface)
    * [1.3.1. SAM 변환](#131-sam-변환)
* [2. 복잡한 생성자: `init`](#2-복잡한-생성자-init)
* [3. 부생성자 (secondary constructor): `constructor`](#3-부생성자-secondary-constructor-constructor)
  * [3.1. `init` 블록을 사용한 주생성자와 부생성자](#31-init-블록을-사용한-주생성자와-부생성자)
  * [3.2. 프로퍼티 초기화를 사용한 주생성자와 부생성자](#32-프로퍼티-초기화를-사용한-주생성자와-부생성자)
  * [3.3. 디폴트 인자를 사용하여 부생성자를 주생성자 하나로 합치기](#33-디폴트-인자를-사용하여-부생성자를-주생성자-하나로-합치기)
* [4. 상속: `open`, `:`](#4-상속-open-)
  * [4.1. 상속된 클래스의 타입](#41-상속된-클래스의-타입)
  * [4.2. 상속과 오버라이드](#42-상속과-오버라이드)
* [5. 기반 클래스(base class) 초기화](#5-기반-클래스base-class-초기화)
  * [5.1. 생성자 인자가 있는 기반 클래스의 상속](#51-생성자-인자가-있는-기반-클래스의-상속)
  * [5.2. 부생성자가 있는 기반 클래스의 상속](#52-부생성자가-있는-기반-클래스의-상속)
  * [5.3. 부생성자가 있는 파생 클래스](#53-부생성자가-있는-파생-클래스)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 인터페이스: `:`

<**인터페이스**>  
- 타입이라는 개념을 기술
- 그 인터페이스를 구현하는 모든 클래스의 프토로타입
- 클래스가 **무엇**을 하는지는 기술하지만 그 일을 **어떻게** 하는지는 기술하지 않음
- 인터페이스가 목표나 임무를 기술하면, 클래스는 세부적인 구현을 함

특정 인터페이스를 구현하는 클래스를 정의하려면 클랫 이름 뒤에 `:` 과 인터페이스 이름을 넣으면 된다.  
인터페이스 멤버를 구현할때는 반드시 `override` 변경자를 붙여야 한다.

```kotlin
interface Computer {
    fun prompt(): String

    fun calculateAnswer(): Int
}

// Computer 인터페이스를 구현하는 클래스
class DeskTop : Computer {
    override fun prompt() = "Hi"

    override fun calculateAnswer() = 11
}

// Computer 인터페이스를 구현하는 클래스
class DeepThought : Computer {
    override fun prompt() = "Thinking..."

    override fun calculateAnswer() = 12
}

fun main() {
    val computers = listOf(DeskTop(), DeepThought())

    val result1 = computers.map { it.calculateAnswer() }
    val result2 = computers.map { it.prompt() }

    println(result1) // [11, 12]
    println(result2) // [Hi, Thinking...]
}
```

---

## 1.1. 프로퍼티를 선언하는 인터페이스

프로퍼티를 선언하는 인터페이스를 구현하는 클래스는 항상 프로퍼티를 오버라이드 해야 한다.

```kotlin
// 프로퍼티를 선언하는 인터페이스
interface Player {
    val symbol: Char
}

// 항상 인터페이스의 프로퍼티를 오버라이드 해야함
class Food : Player {
    // 프로퍼티 값을 직접 다른 값으로 변경함
    override val symbol = '.'
}

class Robot : Player {
    // 값을 반환하는 커스텀 getter 사용
    override val symbol get() = 'R'
}

// 생성자 인자 목록에서 프로퍼티를 오버라이드함
class Wall(override val symbol: Char) : Player

fun main() {
    val result1 =
        listOf(Food(), Robot(), Wall('|'))

    val result2 =
        listOf(Food(), Robot(), Wall('|'))
            .map { it.symbol }

    println(result1) // [assu.study.kotlinme.chap05.Food@6e2c634b, assu.study.kotlinme.chap05.Robot@37a71e93, assu.study.kotlinme.chap05.Wall@7e6cbb7a]
    println(result2) // [., R, |]
}
```

> 아래 커스텀 getter 를 사용하는 부분은 [9. 프로퍼티 접근자](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90) 를 참고하세요.
```kotlin
class Robot : Player {
  // 값을 반환하는 커스텀 getter 사용
  override val symbol get() = 'R'
}
```

> 아래 생성자 인자 목록에서 프로퍼티를 오버라이드하는 부분은 [1. 생성자](https://assu10.github.io/dev/2024/02/09/kotlin-object/#1-%EC%83%9D%EC%84%B1%EC%9E%90) 을 참고하세요.
```kotlin
// 생성자 인자 목록에서 프로퍼티를 오버라이드함
class Wall(override val symbol: Char) : Player
```

---

## 1.2. 인터페이스를 구현하는 enum

> enum 에 대한 좀 더 상세한 내용은 [5. enum](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#5-enum) 를 참고하세요.

```kotlin
interface Hotness {
    fun feedback(): String
}

// 인터페이스를 구현하는 enum
enum class SpiceLevel : Hotness {
    Mild {
        override fun feedback() = "Mild~"
    },
    Medium {
        override fun feedback() = "Medium~"
    },
}

fun main() {
    val result1 = SpiceLevel.values() // values() 는 Array 를 반환함
    val result2 = SpiceLevel.values().toList() // 따라서 배열을 List 로 만듦
    val result3 = SpiceLevel.values().map { it.feedback() }

    println(result1) // [Lassu.study.kotlinme.chap05.SpiceLevel;@b1bc7ed
    println(result2) // [Mild, Medium]
    println(result3) // [Mild~, Medium~]
}
```

---

## 1.3. 단일 추상 메서드 (Single Abstract Method, SAM): `fun interface`

> SAM 은 자바의 함수형 인터페이스와 비슷한 개념이다.  
> 자바의 함수형 인터페이스는 [2. 함수형 인터페이스 사용](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#2-%ED%95%A8%EC%88%98%ED%98%95-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-%EC%82%AC%EC%9A%A9) 을 참고하세요.

단일 추상 메서드 (SAM) 인터페이스는 자바의 개념으로 자바에서는 멤버 함수를 메서드라고 부른다.  
코틀린에서는 SAM 인터페이스를 정의하는 `fun interface` 라는 문법이 있다.

**`fun interface` 라고 쓰면 컴파일러는 그 안에 멤버 함수가 하나만 들어있는지 확인**한다.

아래는 여러 파라메터 목록을 갖는 SAM 인터페이스이다.

```kotlin
// 단일 추상 메서드(SAM) 인터페이스
fun interface ZeroArg {
    fun f(): Int
}

// 단일 추상 메서드(SAM) 인터페이스
fun interface OneArg {
    fun g(n: Int): Int
}

// 단일 추상 메서드(SAM) 인터페이스
fun interface TwoArg {
    fun h(
        i: Int,
        j: Int,
    ): Int
}
```

---

### 1.3.1. SAM 변환

**SAM 인터페이스**를 클래스를 통해 번거로운 방식으로 구현하기 보다는 **람다는 넘기는 방식으로 구현**하는 것이 좋은데 이렇게 **람다를 사용하는 경우를 SAM 변환**이라고 한다.  
**SAM 변환을 사용하면 람다가 인터페이스의 유일한 메서드를 구현하는 함수**가 된다.

아래는 SAM 인터페이스를 클래스로 구현하는 방식과 SAM 변환으로 구현하는 방식을 비교하는 예시이다.

```kotlin
// 단일 추상 메서드(SAM) 인터페이스
fun interface ZeroArg1 {
    fun f(): Int
}

// 단일 추상 메서드(SAM) 인터페이스
fun interface OneArg1 {
    fun g(n: Int): Int
}

// 단일 추상 메서드(SAM) 인터페이스
fun interface TwoArg1 {
    fun h(
        i: Int,
        j: Int,
    ): Int
}

// 클래스로 SAM 구현
class VerboseZero : ZeroArg1 {
    override fun f() = 11
}

val verboseZero = VerboseZero()

// 람다로 SAM 구현
val samZero = ZeroArg1 { 11 }

// 클래스로 SAM 구현
class VerboseOne : OneArg1 {
    override fun g(n: Int) = n + 11
}

val verboseOne = VerboseOne()

// 람다로 SAM 구현
val samOne = OneArg1 { it + 11 }

// 클래스로 SAM 구현
class VerboseTwo : TwoArg1 {
    override fun h(
        n: Int,
        j: Int,
    ) = n + j
}

val verboseTwo = VerboseTwo()

// 람다로 SAM 구현
val samTwo = TwoArg1 { i, j -> i + j }

fun main() {
    println(verboseZero) // assu.study.kotlinme.chap05.VerboseZero@2f4d3709
    println(verboseZero.f()) // 11

    println(samZero) // assu.study.kotlinme.chap05.SAMImplementationKt$$Lambda$15/0x0000000132003000@4e50df2e
    println(samZero.f()) // 11

    println(verboseOne.g(2)) // 13
    println(samOne.g(2)) // 13

    println(verboseTwo.h(1, 2)) // 3
    println(samTwo.h(1, 2)) // 3
}
```

아래를 보면 SAM 인터페이스를 클래스로 구현하는 것보다 람다로 구현하는 것이 훨씬 간결한 것을 알 수 있다.  
또한 SAM 변환을 사용하면 객체를 한 번만 사용하는 경우 한 번의 객체를 만들기 위해 클래스를 굳이 정의할 필요가 없어진다.
```kotlin
// 클래스로 SAM 구현
class VerboseTwo : TwoArg1 {
    override fun h(
        n: Int,
        j: Int,
    ) = n + j
}

val verboseTwo = VerboseTwo()

// 람다로 SAM 구현
val samTwo = TwoArg1 { i, j -> i + j }
```

람다를 SAM 인터페이스가 필요한 곳에 넘길수도 있다.

```kotlin
// 단일 추상 메서드 (SAM) 인터페이스
fun interface Action {
    fun act()
}

fun delayAction(action: Action) {
    print("Delay..")
    action.act()
}

fun main() {
    // 람다를 SAM 인터페이스가 필요한 곳에 직접 넘김
    // 즉, Action 인터페이스를 구현하는 객체 대신에 람다를 바로 전달함
    val result1 = delayAction { println("hi") } // Delay..hi
    println(result1)    // kotlin.Unit
}
```

위를 보면 Action 인터페이스를 구현하는 객체 대신에 람다를 바로 전달하는 것을 알 수 있다.

---

# 2. 복잡한 생성자: `init`

[1. 생성자](https://assu10.github.io/dev/2024/02/09/kotlin-object/#1-%EC%83%9D%EC%84%B1%EC%9E%90) 에서는 인자만 초기화하는 간단한 생성자만 알아보았다. 

var, val 를 파라메터 목록에 있는 파라메터에 붙이면 그 파라메터를 프로퍼티로 만들면서 객체 외부에서 접근할 수 있다.

```kotlin
class Assu(val name: String)

fun main() {
    val assu = Assu("assu")
    println(assu.name)  // assu
}
```

위의 경우 생성자 코드를 사용하지 않았으며, 코틀린이 생성자 코드를 만들어주게 된다.

만일 **생성 과정을 좀 더 제어하고 싶다면 클래스 본문에 `init` 블록을 이용하여 생성자 코드를 추가**하면 된다.

```kotlin
private var counter = 0

class Message(text: String) {
    private val content: String
    // 생성자 파라메터에 var, val 가 없어도 init 블록에서 사용 가능
    init {
        counter += 10
        content = "[$counter] $text"
    }

    override fun toString() = content
}

fun main() {
    val m1 = Message("Hello World")
    println(m1) // [10] Hello World

    val m2 = Message("AAAAA")
    println(m2) // [20] AAAAA
}
```

위 코드를 보면 _content_ 는 val 로 정의되어 있지만 정의 시점에 초기화하지 않았다.  
이런 경우 코틀린은 **생성자 안의 어느 지점에서 오직 한번 초기화가 일어나도록 보장**한다.  
_content_ 값을 다시 할당하거나 초기화하지 않으면 오류가 발생한다.

**생성자는 생성자 파라메터 목록과 `init` 블록들을 합친 것으로, 이들은 객체를 생성하는 동안 실행**된다.

`init` 블록은 여러 개 정의할 수 있으며, 클래스 본문에 정의된 순서대로 실행된다.

---

# 3. 부생성자 (secondary constructor): `constructor`

객체를 생성하는 방법이 여러 가지 필요한 경우 [이름 붙은 인자](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#21-%EC%9D%B4%EB%A6%84-%EB%B6%99%EC%9D%80-%EC%9D%B8%EC%9E%90)나 
[디폴트 인자](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#21-%EB%94%94%ED%8F%B4%ED%8A%B8-%EC%9D%B8%EC%9E%90-trailing-comma-trimmargin)를 이용하는 것이 가장 쉽지만, 때로는 오버로드한 생성자를 여러 개 만들어야 하는 경우도 있다.

같은 클래스에 속한 객체를 여러 가지 방법으로 만들어내야 하는 경우 생성자를 오버로드해야 한다.

코틀린에서는 **오버로드한 생성자를 부생성자**라고 부른다.

**주생성자는 생성자 파라메터 목록 (클래스 이름 뒤에 오는), 프로퍼티 초기화, `init` 블록을 통한 생성자**를 말한다.

**부생성자는 `constructror` 키워드 다음에 주생성자나 다른 부생성자의 파라메터 리스트와 구별되는 파라메터 목록**을 넣어야 한다.  
**부생성자 안에서는 `this` 키워드를 통해 주생성자나 다른 부생성자를 호출**한다.

---

## 3.1. `init` 블록을 사용한 주생성자와 부생성자

호출할 생성자는 인자 목록이 결정한다.

```kotlin
class WithSecondary(i: Int) {
  init {
    println("Primary constructor: $i")
  }

  // 부생성자에서 다른 생성자를 호출(`this` 사용) 부분은 생성자 로직 앞에 위치해야 함
  // (생성자 본문이 다른 초기화 결과에 영향을 받을 수 있기 때문)
  // 따라서 다른 생성자 호출이 생성자 본문보다 앞에 있어야 함
  constructor(c: Char) : this(c - 'A') {
    println(c - 'A')
    println("Secondary constructor 1: $c")
  }

  constructor(s: String) :
  // 첫 번째 부생성자 호출
          this(s.first()) {
    println(s.first())
    println("Secondary constructor 2: $s")
  }

  // this 를 통해 주생성자를 호출하지 않기 때문에 아래 오류와 함께 컴파일되지 않음
  // Primary constructor call expected
//    constructor(f: Float) {
//        println("Secondary constructor3: $f")
//    }
}

fun main() {
  fun sep() = println("-".repeat(10))

  // 주생성자 호출
  WithSecondary(1)
  // Primary constructor: 1

  sep()

  // 첫 번째 부생성자 호출
  WithSecondary('D')
  // Primary constructor: 3
  // 3
  // Secondary constructor 1: D

  sep()

  // 두 번째 부생성자 호출
  WithSecondary("HiHi")
  // Primary constructor: 7
  // 7
  // Secondary constructor 1: H
  // H
  // Secondary constructor 2: HiHi
}
```

**주생성자는 언제나 부생성자에 의해 직접 호출되거나 다른 부생성자 호출을 통해 간접적으로 호출되어야 한다.**  
**따라서 생성자 사이에 공유되어야 하는 모든 초기화로직은 반드시 주생성자에 위치**해야 한다.

---

## 3.2. 프로퍼티 초기화를 사용한 주생성자와 부생성자

부생성자를 쓸 때 꼭 `init` 블록을 쓸 필요는 없다.

```kotlin
enum class Material {
    Ceramic,
    Metal,
    Plastic,
}

class GardenItem(val name: String) {
    var material: Material = Material.Plastic

    // 부생성자
    constructor(name: String, material: Material) : // 주생성자의 파라메터만 val, var 를 덧붙여서 프로퍼티로 선언 가능
        this(name) { // 부생성자에는 반환 타입 지정 불가
        this.material = material
    }

    // 부생성자
    // 부생성자의 본문을 적지 않아도 되지만, `this()` 호출은 반드시 포함해야 함
    constructor(material: Material) : this("Things", material)

    override fun toString() = "$material $name"
}

fun main() {
    val result1 = GardenItem("AAA").material
    println(result1) // Plastic

    val result2 = GardenItem("AAA").name
    println(result2) // AAA

    // 첫 번째 부생성자를 호출할 때 _material_ 프로퍼티가 두 번 대입됨
    // this(name) 에서 주생성자를 호출하고 모든 클래스 프로퍼티값을 초기화할 때 Plastic 값이 할당됨
    // 이 후 this.material = material 에서 Metal 로 할당됨
    val result3 = GardenItem("Assu", Material.Metal)
    println(result3) // Metal Assu

    val result4 = GardenItem(Material.Ceramic)
    val result5 = GardenItem(material = Material.Ceramic)
    println(result4) // Ceramic Things
    println(result5) // Ceramic Things
}
```

---

## 3.3. 디폴트 인자를 사용하여 부생성자를 주생성자 하나로 합치기

**디폴트 인자를 써서 부생성자를 주생성자 하나로 만들면 위의 GardenItem 클래스를 더 단순**하게 만들 수 있다.

```kotlin
enum class Material1 {
    Ceramic,
    Metal,
    Plastic,
}

class GardenItem1(
    val name: String = "Things",
    val material: Material1 = Material1.Plastic,
) {
    override fun toString() = "$material $name"
}

fun main() {
    val result1 = GardenItem1("AAA").material
    println(result1) // Plastic

    val result2 = GardenItem1("AAA").name
    println(result2) // AAA

    val result3 = GardenItem1("Assu", Material1.Metal)
    println(result3) // Metal Assu

    // 컴파일 오류
    // val result4 = GardenItem1(Material1.Ceramic)
    val result5 = GardenItem1(material = Material1.Ceramic)
    println(result5) // Ceramic Things
}
```

---

# 4. 상속: `open`, `:`

상속 구문은 인터페이스를 구현하는 구문과 비슷하게 상속받는 클래스가 기존 클래스를 상속할 때 `:` 을 붙여주면 된다.

- 기반 클래스(base class) = 부모 클래스(parent class) = 상위 클래스(superclass)
- 파생 클래스(derived class) = 자식 클래스(child class) = 하위 클래스(subclass)

**기반 클래스는 `open`** 이어야 한다.  

**`open` 으로 지정하지 않은 클래스는 상속을 허용하지 않는다.** (= 클래스는 기본적으로 상속에 닫혀있음)  
**코틀린은 `open` 키워드를 사용하여 해당 클래스가 상속을 고려하여 설계되었다는 것을 명시적**으로 드러낸다.

> 자바에서는 `final` 을 사용하여 클래스의 상속을 명시적으로 금지하지 않는 한 클래스는 자동으로 상속이 가능함.  
> 코틀린에서도 `final` 을 사용할 수는 있지만 **모든 클래스가 기본적으로 `final` 이기 때문에 굳이 `final` 로 지정할 필요가 없음**

상속 기본 문법
```kotlin
open class Base

class Derived : Base()
```

상속 가능한 클래스와 상속 불가능한 클래스
```kotlin
// 이 클래스는 상속 가능
open class Parent

class Child: Parent()

// Child 는 `open` 되어 있지 않으므로 아래는 상속이 불가
//class GrandChild: Child()

// 이 클래스는 상속 불가
final class Single

// `final` 을 쓴 선언과 같은 효과
class AnotherSingle
```

---

## 4.1. 상속된 클래스의 타입

아래는 하나의 값이 고정된 프로퍼티 2개가 있는 기반 클래스, 기반 클래스와 똑같은 새로운 타입의 파생 클래스 3개가 있는 예시이다.

```kotlin
open class GreatApe {
    val weight = 100.0
    val age = 12
}

open class AAA : GreatApe()

class BBB : GreatApe()

// 2단계 상속 (GreatApe - AAA - CCC)
class CCC : AAA()

// GreatAge 의 확장 함수
fun GreatApe.info() = "wt: $weight, age: $age"

fun main() {
    println(GreatApe().info())  // wt: 100.0, age: 12
    println(AAA().info())   // wt: 100.0, age: 12
    println(BBB().info())   // wt: 100.0, age: 12
    println(CCC().info())   // wt: 100.0, age: 12
}
```

_info()_ 는 _GreatApe_ 의 확장 함수이지만 _GreatApe_ 를 상속받은 _AAA_, _BBB_, _CCC_ 객체에 대해서도 _info()_ 를 호출할 수 있다.

3개의 파생 클래스는 서로 다른 타입이지만 코틀린은 기반 클래스와 같은 타입인 것처럼 인식한다.  
(= 상속은 기반 클래스를 상속한 모든 파생 클래스가 항상 기반 클래스라고 보장함)

상속을 사용하면 그 클래스를 상속하는 모든 파생 클래스에서 사용할 수 있는 코드(위에서는 _info()_) 를 작성할 수 있으므로 
**상속은 코드를 단순화하고 재사용**할 수 있게 해준다.

---

## 4.2. 상속과 오버라이드

**오버라이드는 기반 클래스의 함수를 파생 클래스에서 재정의**하는 것이다.

```kotlin
open class GreatApe1 {
    // private 로 선언하면 파생 클래스에서 energy 변경 불가
    protected var energy = 0

    open fun call() = "Hoo"

    open fun eat() {
        energy += 10
    }

    fun climb(x: Int) {
        energy -= x
    }

    fun energyLevel() = "Energy: $energy"
}

class AAA1 : GreatApe1() {
     override fun call() = "AAA!"

    override fun eat() {
        // 기반 클래스의 프로퍼티 변경
        energy += 10
        // 기반 클래스의 함수 호출
        super.eat()
    }

    // 햠수 추가
    fun run() = "AAA run"
}

class AAA2 : GreatApe1() {
    override fun call() = "AAA!"

    override fun eat() {
        // 기반 클래스의 프로퍼티 변경
        energy += 10
        // 기반 클래스의 함수를 호출하지 않음
        // super.eat()
    }

    // 햠수 추가
    fun run() = "AAA run"
}

class BBB1 : GreatApe1() {
    // 새로운 프로퍼티 선언
    val addEnergy = 20

    override fun call() = "BBB!"

    override fun eat() {
        energy += addEnergy
        super.eat()
    }

    // 함수 추가
    fun jump() = "BBB jump"
}

fun talk(ape: GreatApe1): String {
    // 둘 다 GreatApe1 의 함수가 아니므로 호출 불가
    // ape.run()
    // ape.jump()

    ape.eat()
    ape.climb(10)

    // 이렇게 리턴하면 객체의 주소가 나옴
    // assu.study.kotlinme.chap05.inheritance.GreatApe1@34c45dca.call() assu.study.kotlinme.chap05.inheritance.GreatApe1@34c45dca.energyLevel()
    // return "$ape.call() $ape.energyLevel()"

    // Hoo Energy: 0
    return "${ape.call()} ${ape.energyLevel()}"
}

fun main() {
    // energy 에 접근 불가
    // println(GreatApe1.energy)

    val result1 = talk(GreatApe1())
    val result2 = talk(AAA1())
    val result3 = talk(AAA2())
    val result4 = talk(BBB1())

    println(result1) // Hoo Energy: 0
    println(result2) // AAA! Energy: 10
    println(result3) // AAA! Energy: 0
    println(result4) // BBB! Energy: 20
}
```

파생 클래스는 기반 클래스의 `private` 멤버에 접근할 수 없다.  
**`protected` 멤버는 외부에 대해서는 닫혀있고, 파생 클래스에게만 접근이나 오버라이드를 허용**한다.  
_GreatApe1_ 의 _energy_ 를 private 로 선언하면 파생 클래스에서도 이 프로퍼티에 접근할 수 없게 된다.  
따라서 이 프로퍼티를 protected 로 선언함으로써 외부에서는 접근이 불가하되, 파생 클래스에서만 접근을 허용하도록 한다.

_AAA1_, _BBB1_ 의 _call()_ 처럼 **파생 클래스에서 기반 클래스와 똑같은 시그니처를 갖는 함수를 정의**하면 기반 클래스에 정의되었던 함수가 
수행하던 동작을 새로 정의한 함수의 동작으로 대체하는데 이를 **오버라이딩**이라고 한다.

**`open` 이 아닌 클래스를 상속할 수 없는 것처럼 기반 클래스의 함수가 `open` 으로 되어있지 않으면 파생 클래스에서 이 함수를 오버라이드할 수 없다.**

위에서 _climb()_, _energyLevel()_ 은 `open` 이 아니기 때문에 파생 클래스에서 오버라이드할 수 없다.

_talk()_ 안에서 _call()_ 은 각 타입에 따라 다른 동작을 수행하는데 이를 **다형성(Polymorphism)** 이라고 한다.

_talk()_ 의 파라메터가 _GreatApe1_ 이므로 본문에서 _GreatApe1_ 의 멤버 함수를 호출할 수 있다.  
_AAA1_, _BBB1_ 에 _run()_, _jump()_ 가 정의되어 있지만 이 두 함수는 _GreatApe1_ 의 멤버가 아니기 때문에 _talk()_ 에서 호출할 수 없다.

함수를 오버라이드할 때 경우에 따라 _eat()_ 에서 한 것처럼 해당 함수의 기반 클래스 버전을 호출해야하는 경우가 있다.  
예) 재사용을 해야하는 경우  
단순히 _eat()_ 를 호출하면 혀재 실행 중인 함수를 다시 호출하는 재귀가 일어나게 되므로 기반 클래스의 _eat()_ 를 호출하기 위해 `super` 키워드를 사용한다.

---

# 5. 기반 클래스(base class) 초기화

## 5.1. 생성자 인자가 있는 기반 클래스의 상속

코틀린은 아래의 생성자가 호출되도록 보장함으로써 올바른 객체를 생성한다.
- 멤버 객체들의 생성자
- 파생 클래스에 추가된 객체의 생성자
- 기반 클래스의 생성자

[4. 상속: `open`, `:`](#4-상속-open-) 에서는 기반 클래스가 생성자 파라메터를 받지 않았다.  

**기반 클래스에 생성자 파라메터가 있다면 파생 클래스가 생성되는 동안 반드시 기반 클래스의 생성자 인자를 제공**해야 한다.

아래는 [4.1. 상속된 클래스의 타입](#41-상속된-클래스의-타입) 을 생성자 파라메터를 사용하도록 수정한 예시이다.

```kotlin
open class GreatApe(
    val weight: Double,
    val age: Int,
)

open class AAA(weight: Double, age: Int) : GreatApe(weight, age)

class BBB(weight: Double, age: Int) : GreatApe(weight, age)

// 2단계 상속 (GreatApe - AAA - CCC)
class CCC(weight: Double, age: Int) : AAA(weight, age)

// GreatApe 의 확장 함수
fun GreatApe.info() = "wt: $weight, age: $age"

fun main() {
    println(GreatApe(100.0, 12).info()) // wt: 100.0, age: 12
    println(AAA(110.1, 13).info()) // wt: 110.1, age: 13
    println(BBB(120.1, 14).info()) // wt: 120.1, age: 14
    println(CCC(130.1, 15).info()) // wt: 130.1, age: 15
}
```

_GreatApe_ 를 상속하는 클래스는 반드시 생성자 인자를 _GreatApe_ 에 전달해야 한다.

코틀린은 객체에 사용할 메모리를 확보한 후 기반 클래스의 생성자를 먼저 호출하고, 다음 번 파생 클래스의 생성자를 호출하며, 맨 나중에 파생된 클래스의 생성자를 호출한다.  
이런 식으로 모든 생성자 호출은 자신 이전에 생성되는 모든 객체의 올바름에 의존한다.

---

## 5.2. 부생성자가 있는 기반 클래스의 상속

**기반 클래스에 부생성자가 있으면 기반 클래스의 주생성자 대신 부생성자를 호출할 수도 있다.**

```kotlin
open class House(
    val addr: String,
    val state: String,
    val zip: String,
) {
    constructor(fullAddr: String) :
        this(
            fullAddr.substringBefore(", "),
            fullAddr.substringAfter(", ").substringBefore(" "),
            fullAddr.substringAfterLast(" "),
        )

    val fullAddr: String
        get() = "$addr,, $state $zip"
}

class VacationHouse(
    addr: String,
    state: String,
    zip: String,
    val startMonth: String, // VacationHouse 만의 파라메터
    val endMonth: String, // VacationHouse 만의 파라메터
) : House(addr, state, zip) { // 기반 클래스의 주생성자 호출
    override fun toString() = "Vacation house at $fullAddr from $startMonth to $endMonth"
}

class TreeHouse(
    val name: String,
) : House("Tree Street, TR 11111") { // 기반 클래스의 부생성자 호출
    override fun toString() = "$name tree house at $fullAddr"
}

fun main() {
    val vacationHouse =
        VacationHouse(
            addr = "Korea Suwon.",
            state = "KS",
            zip = "12345",
            startMonth = "May",
            endMonth = "September",
        )

    // Vacation house at Korea Suwon.,, KS 12345 from May to September
    println(vacationHouse)

    val treeHouse = TreeHouse("ASSU")

    // ASSU tree house at Tree Street,, TR 11111
    println(treeHouse)
}
```

---

## 5.3. 부생성자가 있는 파생 클래스

**파생 클래스의 부생성자는 기반 클래스의 생성자를 호출할 수도 있고, 파생 클래스 자신의 생성자를 호출**할 수도 있다.

```kotlin
open class Base(val i: Int)

class Derived : Base {
    constructor(i: Int) : super(i) // 기반 클래스의 생성자 호출
    constructor() : this(9) // 파생 클래스 자신의 생성자 호출
}

fun main() {
    val d1 = Derived()

    println(d1) // assu.study.kotlinme.chap05.baseClassInit.Derived@4f3f5b24
    println(d1.i) // 9

    val d2 = Derived(11)

    println(d2) // assu.study.kotlinme.chap05.baseClassInit.Derived@15aeb7ab
    println(d2.i) // 11
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