---
layout: post
title: "Kotlin - 객체 지향 프로그래밍(2): 추상 클래스, 업캐스트, 다형성, 합성, 합성과 상속, 상속과 확장, 어댑터 패턴, 멤버 함수와 확장 함수"
date: 2024-02-25
categories: dev
tags: kotlin abstract-class interface upcast polymorphism composition adapter
---

이 포스트에서는 코틀린의 추상 클래스, 업캐스트, 다형성, 합성, 상속과 확장에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 추상 클래스](#1-추상-클래스)
  * [1.1. 인터페이스와 추상 클래스](#11-인터페이스와-추상-클래스)
  * [1.2. 함수 구현이 있는 인터페이스](#12-함수-구현이-있는-인터페이스)
  * [1.3. 인터페이스 내부의 프로퍼티 접근](#13-인터페이스-내부의-프로퍼티-접근)
  * [1.4. 인터페이스가 필요한 경우](#14-인터페이스가-필요한-경우)
  * [1.5. 인터페이스의 상속: `super`](#15-인터페이스의-상속-super)
* [2. 업캐스트 (upcast)](#2-업캐스트-upcast)
  * [2.1. 상속의 목적](#21-상속의-목적)
* [3. 다형성 (polymorphism)](#3-다형성-polymorphism)
  * [3.1. 바인딩](#31-바인딩)
* [4. 합성 (Composition)](#4-합성-composition)
  * [4.1. 합성과 상속 중 선택](#41-합성과-상속-중-선택)
    * [4.1.1. 합성 객체 감추기](#411-합성-객체-감추기)
    * [4.1.2. 합성 객체 노출하기](#412-합성-객체-노출하기)
* [5. 상속과 확장](#5-상속과-확장)
  * [5.1. 잘못된 상속의 예시](#51-잘못된-상속의-예시)
  * [5.2. 상속 대신 확장 사용](#52-상속-대신-확장-사용)
  * [5.3. 관습에 의한 인터페이스](#53-관습에-의한-인터페이스)
  * [5.4. 어댑터 패턴](#54-어댑터-패턴)
  * [5.5. 멤버 함수와 확장 함수 비교](#55-멤버-함수와-확장-함수-비교)
    * [5.5.1. 멤버 함수의 사용](#551-멤버-함수의-사용)
    * [5.5.2. 멤버 함수를 확장 함수로 변경](#552-멤버-함수를-확장-함수로-변경)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 추상 클래스

추상 클래스는 하나 이상의 프로퍼티나 함수가 불완전하다는 점을 제외하면 일반 클래스와 동일하다.

> 본문이 없는 함수나 초기값 대입을 하지 않은 프로퍼티 정의 = 불완전한 정의

**인터페이스는 추상 클래스와 비슷하지만, 인터페이스는 추상 클래스와 달리 상태(= 프로퍼티 안에 저장된 데이터)가 없다.**

**클래스 멤버에서 본문이나 초기화를 사용하지 않으려면 `abstract` 변경자를 해당 멤버 앞에 붙여야 하며, `abstract` 가 붙은 멤버가 있는 클래스는 반드시 `abstract` 를 붙여야 한다.**

> **정의**  
> 함수 본문이나 변수의 초기값까지 포함하는 선언
>
> **선언**  
본문과 초기값 없이 함수 시그니처와 반환 타입만 적거나, 변수의 타입만 적는 경우

**초기화 코드가 없으면 코틀린이 해당 참조 타입을 추론할 방법이 없기 때문에 `abstract` 참조에는 반드시 타입을 지정**해야 한다.

추상 클래스를 상속하는 상속 관계를 따라가다 보면 궁극적으로 추상 함수와 프로퍼티의 정의가 있는 (= 추상 멤버의 구체화) 클래스가 존재해야 한다.

```kotlin
abstract class WithProperty {
    // 아무 초기값도 없는 변수 선언
    abstract val x: Int
}

abstract class WithFunctions {
    abstract fun f(): Int

    // abstract 함수의 반환 타입을 지정하지 않으면 코틀린은 반환 타입을 Unit 이라고 간주함
    abstract fun g(n: Double)
}
```

위 코드에서 _x_ 에 `abstract` 를 제거하면 아래와 같은 오류가 뜬다.

```shell
Property must be initialized or be abstract
```

위 코드에서 _f()_ 에 `abstract` 를 제거하면 아래와 같은 오류가 뜬다.
```shell
Function 'f' without a body must be abstract
```

위에서 _f()_, _g()_ 두 함수 모두 정의를 제공하지 않으므로 함수 앞에 `abstract` 를 붙여야 한다.

---

## 1.1. 인터페이스와 추상 클래스

> 인터페이스에 대한 좀 더 상세한 내용은 [1. 인터페이스: `:`](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#1-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-) 를 참고하세요.

**인터페이스에 정의된 함수나 프로퍼티는 모두 기본적으로 추상 멤버**이다. (= 추상 클래스와 비슷)  
인터페이스에 함수나 프로퍼티가 선언되어 있을 때는 `abstract` 가 필요없으므로 생략 가능하다.

```kotlin
interface AA {
    abstract val x: Int

    abstract fun f(): Int

    abstract fun g(n: Double)
}

// AA 와 동일
interface BB {
    val x: Int

    fun f(): Int

    fun g(n: Double)
}
```

**인터페이스와 추상 클래스의 차이점은 추상 클래스에는 상태(= 프로퍼티 안에 저장된 데이터)가 있지만, 인터페이스에는 상태가 없다는 점**이다.

**인터페이스에도 프로퍼티를 선언할 수는 있지만, 데이터는 실제 구현하는 클래스 안에서만 저장**될 수 있다.

```kotlin
// name, list 프로퍼티에 저장된 값으로 구성됨
class IntList(val name: String) {
    val list = mutableListOf<Int>()
}

// 인터페이스 안에서 프로퍼티는 선언만 가능하고, 데이터 초기화는 불가함
interface CC {
    val name: String
    
    // 아래와 같은 컴파일 오류
    // Property initializers are not allowed in interfaces
    
    // val list = listOf(1)
}

fun main() {
    val ints = IntList("numbers")

    val result1 = ints.name
    ints.list += 1

    println(result1)    // numbers
    println(ints)   // assu.study.kotlinme.chap05.abstract.IntList@10f87f48
    println(ints.list)  // [1]
}
```

아래는 커스텀 getter 가 있는 프로퍼티와 추상 프로퍼티가 있는 인터페이스의 예시이다.
```kotlin
interface AA {
  val email: String
  val nickname: String
    get() = email.substringBefore('@')  // 매번 결과를 계산하여 돌려줌
}
```

위 인터페이스를 구현하는 클래스는 추상 프로퍼티인 _email_ 을 반드시 오버라이드해야 하지만, _nickname_ 은 오버라이드하지 않고 상속할 수 있다.

---

## 1.2. 함수 구현이 있는 인터페이스

**인터페이스와 추상 클래스 모두 구현이 있는 함수를 포함**할 수 있으며, 이런 함수에서는 다른 `abstract` 멤버 호출이 가능하다.

```kotlin
// ch, f() 는 각각 추상 프로퍼티와 추상 함수이므로 Parent 를 구현하는 클래스는 이 두 멤버를 꼭 오버라이드해야 함
interface Parent {
    // 추상 프로퍼티
    val ch: Char

    // 추상 함수
    fun f(): Int

    // g() 가 정의된 시점에 아무 구현도 없는 추상 멤버 사용
    // 인터페이스와 추상 클래스는 해당 타입의 객체가 생성되기 전에 모든 추상 프로퍼티와 함수가 구현되도록 보장함
    fun g() = "ch = $ch; f() = ${f()}"
}

class Actual(override val ch: Char) : Parent {
    override fun f() = 11
}

class Other : Parent {
    override val ch: Char
        get() = 'B'

    override fun f() = 22
}

fun main() {
    val result1 = Actual('A').g()
    val result2 = Other().g()

    println(result1)    // ch = A; f() = 11
    println(result2)    // ch = B; f() = 22
}
```

인터페이스와 추상 클래스는 해당 타입의 객체가 생성되기 전에 모든 추상 프로퍼티와 함수가 구현되도록 보장하기 때문에 _Parent_ 클래스에서 _g()_ 함수가 정의되는 시점에 아무 구현도 없는 
추상 멤버를 사용할 수 있다.

---

## 1.3. 인터페이스 내부의 프로퍼티 접근

**이렇게 인터페이스가 함수 구현을 포함할 수 있기 때문에 내부에 정의된 프로퍼티가 상태를 바꿀 수 없는 경우 인터페이스도 프로퍼티의 커스텀 getter 를 포함**할 수 있다.

```kotlin
interface PropertyAccessor {
    val a: Int
        get() = 1
}

class Impl : PropertyAccessor

fun main() {
    println(Impl().a)   // 1
}
```

---

## 1.4. 인터페이스가 필요한 경우

추상 클래스가 있는데 **인터페이스가 필요한 이유는 바로 다중 상속** 때문이다.

위에서도 언급이 되었지만 인터페이스와 추상 클래스의 차이점은 아래와 같다.  
**인터페이스와 추상 클래스의 차이점은 추상 클래스에는 상태(= 프로퍼티 안에 저장된 데이터)가 있지만, 인터페이스에는 상태가 없음**

상태(= 프로퍼티 안에 저장된 데이터)가 없는 클래스의 필요성을 위해 다중 상속을 보자면, **코틀린에서는 클래스가 오직 하나의 기반 클래스만 상속**할 수 있다. (자바처럼)  

자바도 다중 상태 상속을 금지하는 대신에 다중 인터페이스 상속은 허용한다.

```kotlin
open class Animal

open class Dog : Animal()

open class Cat : Animal()

// 기반 클래스가 둘 이상이면 아래와 같은 컴파일 오류
// Only one class may appear in a supertype list (상위 타입 목록에는 클래스가 단 하나만 올 수 있다는 의미)
// class Dolphin: Dog(), Cat()

interface A
interface B: A
interface C: A

// 인터페이스는 다중 상속 가능
class Dolphin2: B, C
```

---

## 1.5. 인터페이스의 상속: `super`

인터페이스도 다른 인터페이스를 상속할 수 있는데 여러 인터페이스를 상속하다보면 시그니처가 같은 함수를 동시에 상속할 때가 있는데 이 때는 아래처럼 직접 충돌을 해결해주어야 한다.

> **함수의 시그니처는 함수 이름, 파라메터 목록, 반환 타입**으로 이루어짐

```kotlin
interface AAA {
    fun f() = 1

    fun g() = "A.g"

    val n: Double
        get() = 1.1
}

interface BBB {
    fun f() = 2

    fun g() = "B.g"

    val n: Double
        get() = 2.2
}

// 인터페이스 AAA, BBB 의 함수 f(), g() 와 프로퍼티 n 의 시그니처가 같기 때문에 충돌을 해결해줘야 함
class CCC : AAA, BBB {
    // 멤버 함수를 오버라이드하여 충돌 해결
    override fun f() = 0

    // super 키워드를 사용하여 기반 클래스의 함수 호출
    override fun g() = super<AAA>.g()

    override val n: Double
        get() = super<AAA>.n + super<BBB>.n
}

fun main() {
    val c = CCC()

    println(c.f())
    println(c.g())
    println(c.n)
}
```

_C.g()_ 나 _C.n_ 처럼 기반 클래스의 멤버를 호출할 지 표시하기 위해서는 `super` 뒤에 부등호로 클래스 이름을 지정한다.

---

# 2. 업캐스트 (upcast)

**업캐스트란 객체 참조를 받아서 그 객체의 기반 타입에 대한 참조처럼 취급**하는 것을 의미한다.

> **자바의 상속과 새로운 멤버 함수 추가**  
> 
> 자바는 모든 것이 객체이고, 상속 과정에서 새로운 함수를 추가할 수 있다.

코틀린은 위의 자바와 같은 제약을 없앴다.  
독립적인 함수를 정의할 수 있으므로 모든 것을 클래스 안에 가둘 필요없이 확장 함수를 사용하여 상속을 쓰지 않아도 기능 확장이 가능하다.

**코틀린은 단일 상속 계층 내 여러 클래스에서 코드를 재사용할 수 있는 방식으로만 상속을 사용**하게 한다.

> 이에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](#3-다형성-polymorphism) 을 참고하세요.

이를 위해 업캐스트에 대해 알아보자.

```kotlin
interface Shape {
    fun draw(): String

    fun erase(): String
}

class Circle : Shape {
    override fun draw(): String = "circle.draw"

    override fun erase(): String = "circle.erase"
}

class Square : Shape {
    override fun draw(): String = "square.draw"

    override fun erase(): String = "square.erase"

    fun color() = "Square.color"
}

class Triangle : Shape {
    override fun draw(): String = "triangle.draw"

    override fun erase(): String = "triangle.erase"

    fun rotate() = "Triangle.rotate"
}

// 기반 클래스인 Shape 를 파라메터로 받으므로 show() 는 파생 클래스들의 타입을 모두 허용함
fun show(shape: Shape) {
    println("show: ${shape.draw()}")
}

fun main() {
    val result = listOf(Circle(), Square(), Triangle()).forEach(::show)

    // show: circle.draw
    // show: square.draw
    // show: triangle.draw
    // kotlin.Unit
    println(result)
}
```

> 최상위 수준 함수에 대한 참조인 `::함수명` 은 [3.2. 함수 참조](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#32-%ED%95%A8%EC%88%98-%EC%B0%B8%EC%A1%B0) 참고하세요.

_show()_ 는 기반 클래스인 Shape 를 파라메터로 받으므로 show() 는 파생 클래스들의 타입을 모두 허용한다.  
**각 타입은 모두 기반 Shape 클래스의 객체처럼 취급되는데 이를 구체적인 타입이 기반 타입으로 업캐스트** 되었다고 한다.

_Circle_, _Square_, _Triangle_ 타입의 객체를 _show()_ 의 _Shape_ 타입 인자로 전달할 때 각 객체의 구체적인 타입은 상속 계층 위에 있는 타입으로 변환된다.  
업캐스트가 이루어지면서 각 객체가 _Circle_, _Square_, _Triangle_ 중 어느 타입인지에 대한 구체적인 정보를 사라지고, 모두 그냥 _Shape_ 객체로 취급된다.

---

## 2.1. 상속의 목적

**상속 매커니즘은 오직 기반 타입으로 업캐스트한다는 목적** 때문에 이루어진다.  
이런 추상화(= 모든 것이 Shape)로 인해 구체적인 타입에 따라 매번 _show()_ 함수를 작성하지 않고 단 한번만 작성해도 된다.

즉, **객체를 위해 작성된 코드를 재사용하는 방법이 업캐스트**이다.

만일 업캐스트를 사용하지 않으면서 상속을 사용하는 거의 모든 경우는 상속을 잘못 사용하는 것이다.

**상속이 기반 타입을 파생 타입으로 대신**하는 것이기 때문에 _Square_, _Triangle_ 에 추가된 _color()_, _rotate()_ 처럼 기반 타입에 추가된 함수는 _show()_ 안에서 사용할 수 없다.

**업캐스트를 한 다음에는 파생 타입이 정확히 기반 타입과 똑같이 취급되므로 업캐스트가 파생 클래스에 추가된 멤버 함수를 잘라버리게 된다.**  
즉, 파생 클래스에 추가된 멤버는 여전히 존재하지만, 기반 클래스의 인터페이스에는 속해있지 않으므로 _show()_ 에서는 사용할 수 없다.

```kotlin
fun trim(shape: Shape) {
    println("trim: ${shape.erase()}")
    println("trim: ${shape.draw()}")
    // 컴파일 되지 않음
    //println("trim: ${shape.color()}")
    //println("trim: ${shape.rotate()}")
}
```

위 코드에서 _Square_ 를 _Shape_ 로 업캐스트했기 때문에 _trim()_ 안에서 _color()_ 을 호출할 수 없다.

_trim()_ 안에서 사용할 수 있는 멤버 함수는 모든 Shape 에 공통으로 들어가있는 멤버들, 즉 기반 타입 Shape 에 정의된 멤버들뿐이다.

아래처럼 _Shape_ 하위 타입 값을 직접 일반적인 _Shape_ 타입 변수에 대입해도 마찬가지이다.  
**업캐스트를 한 다음에는 기반 타입의 멤버만 호출 가능**하다.

```kotlin
val result2: Shape = Square()
// 컴파일되지 않음
//println(result2.color())
```

---

# 3. 다형성 (polymorphism)

**다형성은 객체나 멤버의 여러 구현이 있는 것**을 의미한다.

```kotlin
open class Pet {
    open fun speak() = "Pet~"
}

class Dog : Pet() {
    // 멤버 함수 오버라이드
    override fun speak(): String = "Bark!"
}

class Cat : Pet() {
    // 멤버 함수 오버라이드
    override fun speak(): String = "Meow~"
}

fun talk(pet: Pet) = pet.speak()

fun main() {
    println(talk(Dog()))    // Bark!
    println(talk(Cat()))    // Meow~
}
```

_talk()_ 함수의 파라메터는 _Pet_ 이기 때문에 _Dog_, _Cat_ 모두 _Pet_ 으로 업캐스트되지만, 모두 _Pet~_ 이 아닌 _Bark!_ 와 _Meow~_ 가 출력된다.

_talk()_ 는 파라메터로 받는 _Pet_ 객체의 정확한 타입을 모른다. 하지만 기반 클래스인 _Pet_ 의 참조를 이용하여 _speak()_ 를 호출했을 때 올바른 파생 클래스의 구현이 호출된다.

**다형성은 기반 클래스 참조가 파생 클래스의 인스턴스를 가리키는 경우**를 말한다.  
**기반 클래스 참조에 대해 멤버를 호출하면 다형성에 의해 파생 클래스에서 오버라이드한 올바른 멤버가 호출**된다.

---

## 3.1. 바인딩

**함수 호출을 함수 본문과 연결 짓는 작업을 바인딩**이라고 한다.

일반적으로 바인딩은 컴파일 시 일어나기 때문에 신경쓸 일이 없지만 다형성이 사용되는 경우에는 같은 연산이 타입에 따라 다르게 동작해야 한다.  
하지만 컴파일러는 어떤 함수 본문을 사용해야 할 지 미리 알 수 없기 때문에 함수 본문을 동적 바인딩을 사용하여 실행 시점에 동적으로 결정해야 한다.  
이를 **동적 바인딩** 또는 **동적 디스패치** 라고 한다.

코틀린은 런타임 시에만 정확히 어떤 _speak()_ 함수를 호출할 지 알수 있기 때문에 다형적 호출인 _pet.speak()_ 에 대한 바인딩은 동적으로 일어난다.

아래 코드를 보자.
```kotlin
abstract class Character(val name: String) {
    abstract fun play(): String
}

interface Fighter {
    fun fight() = "Fight!"
}

interface Magician {
    fun magic() = "Magic!"
}

class Warrior : Character("Warrior"), Fighter {
    override fun play() = fight()
}

open class Elf(name: String = "Elf") : Character(name), Magician {
    // 여기선 super.play() 가 안됨
    override fun play() = magic()
}

class FightElf : Elf("FightElf"), Fighter {
    override fun play() = super.play() + fight()
}

// 기반 클래스인 Character 의 확장 함수
fun Character.playTurn() =      // [1] 
    println(name + ": " + play())   // [2]

fun main() {
    // 각 객체를 List 에 넣으면서 Character 로 업캐스트됨
    val character: List<Character> = listOf(Warrior(), Elf(), FightElf())

    // List 에 있는 Character() 에 대해 playTurn() 호출 시 캐릭터마다 다른 출력이 나옴
    character.forEach { it.playTurn() }     // [3]
    // Warrior: Fight!
    // Elf: Magic!
    // FightElf: Magic!Fight!
}
```

[3] 에서 _playTurn()_ 을 호출할 때 함수가 정적으로 바인딩된다. 즉, 정확히 어떤 함수를 호출할 지 컴파일 시점에 결정된다.  
컴파일러는 _playTurn()_ 함수의 구현이 [1] 에서 정의한 함수 하나뿐이라고 결정한다.

컴파일러가 [2] 의 _play()_ 함수 호출을 분석할 때는 _Elf_ 의 _play()_ 를 호출할지, _Fighter_ 의 _play()_ 중 어떤 함수를 사용해야 할 지 알 수 없다.  
호출된 함수의 바인딩은 함수 호출 지점마다 달라지고, 컴파일 시점에는 [2] 의 _play()_ 가 _Character_ 의 멤버 함수라는 것만 확실히 알 수 있다.

구체적인 파생 클래스는 실행 시점이 되어야 알 수 있으며, 실제 수신 객체 _Character_ 의 구체적인 타입에 따라 달라진다.

**정적 바인딩을 사용할 때와 비교하면 실행 시점에 타입을 결정해야 하는 추가 로직이 성능에 약간의 부정적인 영향**을 끼친다.


---

# 4. 합성 (Composition)

객체 지향을 사용하는 가장 큰 이유는 바로 코드의 재사용이다.

객체 지향 프로그래밍에서는 새로운 클래스를 이용하여 코드를 재사용하는데 여기서의 핵심은 기존 코드를 오염시키지 않고 클래스를 재사용하는 것이다.  
그 방법 중 하나가 바로 상속이다.

**상속을 하면 기존 클래스 타입에 속하는 새로운 클래스를 만들며, 기존 클래스를 변경하지 않고 기존 클래스의 형식대로 새로운 클래스에 코드를 추가**한다.

또는 **기존 클래스의 객체를 새로운 클래스 <u>안에</u> 생성하는 방법도 있는데, 새로운 클래스가 기존 클래스들을 합성한 객체로 이루어지기 때문**에 이를 **합성**이라고 한다.  
**합성을 사용하는 경우는 기본 코드의 기능(형태가 아닌)을 재사용하는 것**이다.

**합성은 포함(has-a) 관계**이고, **상속은 ~이다(is-a) 관계**이다.

예를 들어 _집은 건물**이며**(is-a), 부엌을 **포함**(has-a) 한다._

```kotlin
interface Building
interface Kitchen

interface House: Building { // 상속
    val kitchen1: Kitchen   // 합성
    val kitchen2: Kitchen
    val kitchens: List<Kitchen> // 합성
}
```

클래스가 성장하면 여러 가지 관련이 없는 요솓ㄹ을 책임져야 한다.  
합성은 각 요소를 서로 분리시킬 때 도움이 된다.  
**합성을 사용하면 클래스의 복잡한 로직을 단순화**할 수 있다.

---

## 4.1. 합성과 상속 중 선택

**합성과 상속 모두 새로운 클래스에 하위 객체를 넣는다는 점은 동일하지만, 합성은 명시적으로 하위 객체를 선언하고 상속은 암시적으로 하위 객체가 생긴다는 점이 다르다.**  

### 4.1.1. 합성 객체 감추기

합성은 기존 클래스의 기능을 제공하지만 인터페이스는 제공하지 않는다.  
새로운 클래스에서 객체의 특징을 사용하기 위해 객체를 포함시키지만, 사용자는 합성으로 포함된 객체의 인터페이스가 아니라 새로운 클래스에서 정의한 인터페이스를 보게 된다.
합성한 객체를 완전히 감추고 싶다면 `private` 로 포함시키면 된다.

```kotlin
class Features {
    fun f1() = "feature1"
    fun f2() = "feature2"
}

class Form {
    // 합성
    private val features = Features()
    fun operation1() = features.f2() + features.f1()
    fun operation2() = features.f1() + features.f2()
}
```

위에서 _Features_ 클래스는 _Form_ 의 연산에 대한 구현을 제공한다.  
하지만 _Form_ 을 사용하는 클라이언트는 _features_ 에 접근할 수 없으며, _Form_ 이 어떻게 구현되었는지 알 수 없다.  
이 말은 _Form_ 을 구현하는 더 나은 방법을 찾아냈을 때 _features_ 를 제거하고 새로운 접근 방법을 택해도 _Form_ 을 사용하는 코드에는 전혀 영향을 미치지 않는다는 점이다.

만약에 _Form_ 이 _Features_ 를 상속한다면 클라이언트가 _Form_ 을 _Features_ 로 업캐스트할 것을 예상할 수 있다.  
그런 경우 연결 관계가 명확해지기 때문에 이 관계를 수정하면 해당 연결 관계에 의존하는 모든 코드가 망가지게 된다.

---

### 4.1.2. 합성 객체 노출하기

경우에 따라 클래스 사용자가 새로운 클래스의 합성에 직접 접근하는 것이 합리적일 때가 있다.  
이럴 때는 멤버 객체를 `public` 으로 포함시키면 된다.  
이렇게 공개를 해도 멤버 객체가 적절히 정보 은닉을 구현하고 있는 한 상대적으로 안전하다.

```kotlin
class Engine {
    fun start() = println("Engine started")
    fun stop() = println("Engine stopped")
}

class Wheel {
    fun inflate(psi: Int) = println("Wheel inflation: $psi")
}

class Window(val side: String) {
    fun up() = println("$side Window up")
    fun down() = println("$side Window down")
}

class Door(val side: String) {
    val window = Window(side) // 합성
    fun open() = println("$side Door open")
    fun close() = println("$side Door close")
}

// 합성으로 이루어짐
class Car {
    var engine = Engine()
    var wheel = List(4) { Wheel() }
    val leftDoor = Door("left")
    val rightDoor = Door("right")
}

fun main() {
    val car = Car()
    car.leftDoor.open() // left Door open
    car.rightDoor.open()    // right Door open
    car.wheel[0].inflate(11)    // Wheel inflation: 11
    car.engine.start()  // Engine started
}
```

이런 식으로 내부를 노출시킨 설계는 클라이언트가 클래스를 사용하는 방법을 이해할 때 도움이 되고, 클래스를 만든 사람의 코드 복잡도를 줄여준다.

만약 위에서 _Car_ 를 _Vehicle_ 클래스의 객체를 사용하여 합성하면 의미가 없다.  
_Car_ 는 _Vehicle_ 을 포함하지 않으며, Vehicle 이다.  

'~이다' 의 관계는 상속으로 표현하고, '포함' 의 관계를 합성으로 표현한다.

**상속을 하게 되면 연결 관계로 인해 불필요하게 복잡해지므로 상속과 합성 중 어느 쪽으로 해야할 지 잘 모르겠다면 합성을 먼저 시도**하는 것이 좋다.

---

# 5. 상속과 확장

기존 클래스를 새로운 목적으로 활용하기 위해 새로운 함수를 추가해야 할 때가 있는데 이 때 기존 클래스를 변경할 수 없으면 새로운 함수를 추가하기 위해 상속을 해야 한다.  
이로 인해 코드의 유지 보수가 어려워지게 된다.

---

## 5.1. 잘못된 상속의 예시

아래처럼 기반 클래스와 기반 클래스 객체에 작용하는 함수가 있다고 하자.

```kotlin
// 기반 클래스
open class Heater {
    fun heat(temperature: Int) = "heat to $temperature"
}

// 기반 클래스 객체에 작용하는 함수
fun warm(heater: Heater) {
    heater.heat(70)
}
```

실제 원하는 기능은 냉난방 시스템(HVAC) 이라고 해보자.   
여기에 만일 _cool()_ 기능을 추가하기 위해서 _Heater_ 를 상속하여 _cool()_ 함수를 추가하면 기존의 _warm()_ 과 다른 모든 함수는 _Heater_ 에 작용할 수 있으므로 새로운 
HVAC 타입에 대해서도 작동한다.

만일 합성을 사용한다면 새로운 HVAC 타입을 기존 함수에 적용할 수 없다.

아래 코드를 보자.
```kotlin
package assu.study.kotlinme.chap05.inheritanceExtensions

open class Heater1 {
    fun heat(temperature: Int) = println("heat to $temperature")
}

// 기반 클래스 객체에 작용하는 함수
fun warm(heater: Heater1) {
    heater.heat(70)
}

// Heater1 이 원하는 기능을 전부 제공하지 못하기 때문에 Heater 를 상속하여 HVAC1 을 만든 후 다른 함수 추가
class HVAC1 : Heater1() {
    fun cool(temperature: Int) = println("cool to $temperature")
}

fun warmAndCool(hvac: HVAC1) {
    hvac.heat(80)
    hvac.cool(10)
}

fun main() {
    val heater1 = Heater1()
    val hvac1 = HVAC1()

    warm(heater1) // heat to 70
    warm(hvac1) // heat to 70

    // heat to 80
    // cool to 10
    warmAndCool(hvac1)
}
```

Heater1 이 원하는 기능을 전부 제공하지 못하기 때문에 Heater 를 상속하여 HVAC1 을 만든 후 다른 함수 추가하였다.

[2.1. 상속의 목적](#21-상속의-목적) 에 언급된 것처럼 객체 지향 언어는 상속을 하는 동안 멤버 함수를 처리하는 메커니즘을 제공하는데, 추가된 함수는 업캐스트를 하면 
잘라나가기 때문에 기반 클래스에서는 사용할 수 없다.  
기반 클래스를 받아들이는 함수는 반드시 파생 클래스의 객체를 받아도 아무런 문제가 없어야 한다.  
그래서 위에서 파생 클래스는 _HVAC1_ 에 대해서도 _warm()_ 은 여전히 잘 동작한다.

**이런 함수 추가는 타당해보이지만 코드 유지보수에는 악영향**을 끼칠 수 있다. 이런 경우를 기술 부채라고 한다.

**상속을 하면서 함수를 추가하는 것은 클래스에 기반 클래스가 있다는 사실을 무시하고 시스템 전반에서 파생 클래스를 엄격하게 실벽하여 취급할 때 유용**하다.  
**기반 클래스 타입의 참조를 통해서 파생 클래스 인스턴스에 접근한다면 파생 클래스에 추가된 함수를 호출할 방법이 없기 때문에 쓸데없이 함수를 추가한 셈**이 되어버린다.

> 상속을 하면서 함수를 추가하는 게 가능한 케이스는 [1. 타입 검사](https://assu10.github.io/dev/2024/03/02/kotlin-object-oriented-programming-4/#1-%ED%83%80%EC%9E%85-%EA%B2%80%EC%82%AC) 를 참고하세요.

---

## 5.2. 상속 대신 확장 사용

위에서 _HVAC1_ 클래스를 만든 이유는 _Heater1_ 클래스에 _cool()_ 을 추가하여 _warmAndCool()_ 에서 _warm()_ 과 _cool()_ 을 모두 쓰기 위함이므로 
확장 함수가 하는 일과 정확히 일치한다.

> 확장 함수에 대한 좀 더 상세한 내용은 [1. 확장 함수 (extension function)](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#1-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-extension-function) 를 참고하세요.

확장 함수를 사용하게 되면 [5.1. 잘못된 상속의 예시](#51-잘못된-상속의-예시) 처럼 상속을 사용할 필요가 없다.

```kotlin
// 기반 클래스
open class Heater2 {
    fun heat(temperature: Int) = println("heat to $temperature")
}

// 기반 클래스 객체에 작용하는 함수
fun warm2(heater: Heater2) {
    heater.heat(70)
}

// 기반 클래스 객체에 작용하는 확장 함수
fun Heater2.cool(temperature: Int) = println("cool to $temperature")

fun warnAndCool2(heater: Heater2) {
    heater.heat(80)
    heater.cool(10)
}

fun main() {
    val heater = Heater2()
    warm2(heater) // heat to 70

    // heat to 80
    // cool to 10
    warnAndCool2(heater)
}
```

**기반 클래스 인터페이스를 확장하기 위해 상속 대신 확장 함수를 사용하면 상속을 하지 않고 기반 클래스의 인스턴스를 직접 확장**할 수 있다.

아래는 위 코드를 좀 더 유연하게 설계한 예시이다.

```kotlin
class TemperatureDelta(
    val current: Double,
    val target: Double,
)

// 확장 함수
fun TemperatureDelta.heat() {
    if (current < target) {
        println("heating to $target")
    }
}

// 확장 함수
fun TemperatureDelta.cool() {
    if (current > target) {
        println("cooling to $target")
    }
}

fun adjust(delta: TemperatureDelta) {
    delta.heat()
    delta.cool()
}

fun main() {
    adjust(TemperatureDelta(50.0, 60.0)) // heating to 60.0
    adjust(TemperatureDelta(90.0, 70.0)) // cooling to 70.0
}
```

---

## 5.3. 관습에 의한 인터페이스

확장 함수를 함수가 하나뿐인 인터페이스를 만드는 것처럼 생각할 수도 있다.

```kotlin
class X

// X 의 확장 함수
fun X.f() = println("X.f()")

class Y

// Y 의 확장 함수
fun Y.f() = println("Y.f()")

// X, Y 두 타입에 대해 올바르게 동작하게 하기 위해 callF() 를 오버로드함 
fun callF(x: X) = x.f()

fun callF(y: Y) = y.f()

fun main() {
    val x = X()
    val y = Y()

    x.f() // X.f()
    y.f() // Y.f()

    callF(x) // X.f()
    callF(y) // Y.f()
}
```

_X_, _Y_ 에 _f()_ 라는 멤버 함수가 있는 것처럼 보이지만 이 둘은 다형적으로 동작하지 않기 때문에 두 타입에 대해 _callF()_ 가 제대로 동작하게 하려면 _callF()_ 를 오버로드해야 한다.

> 다형성은 [3. 다형성 (polymorphism)](#3-다형성-polymorphism) 을 참고하세요.

코틀린 라이브러리에서는 이런 **관습에 의한 인터페이스**를 광범위하게 사용한다.

코틀린 컬렉션은 거의 자바 컬렉션이지만 코틀린 라이브러리는 다수의 확장 함수를 추가해서 자바 컬렉션을 함수형 스타일의 컬렉션으로 변경시켜 준다.

코틀린 표준 라이브러리의 `Sequnece` 인터페이스에는 멤버 함수가 하나만 들어있고, [나머지 Sequence 함수는 모두 확장](https://kotlinlang.org/api/latest/jvm/stdlib/kotlin.sequences/)이다.

> `Sequnece` 의 좀 더 상세한 내용은 [1. 시퀀스 (Sequence)](https://assu10.github.io/dev/2024/02/23/kotlin-funtional-programming-3/#1-시퀀스-sequence-constrainonce) 를 참고하세요.

코틀린은 **필수적인 메서드만 정의하여 포함하는 간단한 인터페이스를 만들고, 모든 부가 함수를 확장으로 정의**하는 것을 철학으로 하고 있다.

---

## 5.4. 어댑터 패턴

**라이브러리에서 타입을 정의한 후 그 타입의 객체를 파라메터로 받는 함수를 제공**하는 경우도 있다.

아래와 같은 라이브러리가 있다고 하자.
```kotlin
// 타입을 정의함
interface LibType {
    fun f1()
    fun f2()
}

// 정의한 타입을 객체의 파라메터로 받음
fun utility1(lt: LibType) {
    lt.f1()
    lt.f2()
}

// 정의한 타입을 객체의 파라메터로 받음
fun utility2(lt: LibType) {
    lt.f2()
    lt.f1()
}
```

위 라이브러리를 사용하려면 기존 클래스를 _LibType_ 으로 변환할 방법이 필요하다.

```kotlin
// --- 라이브러리 시작 ---
// 타입을 정의함
interface LibType1 {
    fun f1()
    fun f2()
}

// 정의한 타입을 객체의 파라메터로 받음
fun utility11(lt: LibType1) {
    lt.f1()
    lt.f2()
}

// 정의한 타입을 객체의 파라메터로 받음
fun utility22(lt: LibType1) {
    lt.f2()
    lt.f1()
}

// --- 라이브러리 끝 ---

open class MyClass1 {
    fun g() = println("g()")
    fun h() = println("h()")
}

 fun useMyClass(mc: MyClass1) {
    mc.g()
    mc.h()
 }

// MyClassAdaptedForLib 를 만들기 위해 MyClass1 을 상속함
// LibType1 을 구현하기 때문에 utility11(), utility22() 에 해당 객체 타입 전달 가능
class MyClassAdaptedForLib : MyClass1(), LibType1 {
    override fun f1() = h()
    override fun f2() = g()
}

fun main() {
    val mc = MyClassAdaptedForLib()
    // h()
    // g()
    utility11(mc)

    // g()
    // h()
    utility22(mc)

    // g()
    // h()
  useMyClass(mc)
}
```

위 코드는 _MyClassAdaptedForLib_ 를 만들기 위해 기존의 _MyClass1_ 을 상속하였다.  
그리고 _LibType1_ 을 구현하기 때문에 _utility11()_ 과 _utility22()_ 에 인자로 해당 타입의 객체를 전달할 수 있다.

하지만 이런 방식은 상속을 하면서 클래스를 확장하긴 하지만 새 멤버 함수는 오직 라이브러리에 연결하기 위해서면 사용된다.  
다른 곳에서는 _useMyClass_ 처럼 _MyClassAdaptedForLib_ 를 그냥 _MyClass1_ 객체로 취급할 수 있다.

위 코드를 보면 기반 클래스 사용자가 파생 클래스에 대해 꼭 알아야 하는 방식으로 _MyClassAdaptedForLib_ 클래스를 사용하는 코드는 없다.

위 코드는 _MyClass1_ 이 상속에 대해 열린 `open` 클래스라는 점에 의존한다.

**만약 _MyClass1_ 을 수정할 수 없고, _MyClass1_ 이 `open` 도 아니라면 이 때 합성을 사용하여 어댑터**를 만들 수 있다.

---

아래는 _MyClassAdaptedForLib_ 안에 _MyClass1_ 필드를 추가한 예시이다.

```kotlin
// --- 라이브러리 시작 ---

// 타입을 정의함
interface LibType2 {
    fun f1()

    fun f2()
}

// 정의한 타입을 객체의 파라메터로 받음
fun utility111(lt: LibType2) {
    lt.f1()
    lt.f2()
}

// 정의한 타입을 객체의 파라메터로 받음
fun utility222(lt: LibType2) {
    lt.f2()
    lt.f1()
}

// --- 라이브러리 끝 ---

// open 된 클래스가 아님 (= 상속 불가)
class MyClass2 {
    fun g() = println("g()")

    fun h() = println("h()")
}

fun useMyClass2(mc: MyClass2) {
    mc.g()
    mc.h()
}

class MyClassAdaptedForLib2 : LibType2 {
    val field = MyClass2() // MyClass2 를 상속하지 않고, 합성을 통해 필드로 추가함

    override fun f1() = field.h()

    override fun f2() = field.g()
}

fun main() {
    val mc = MyClassAdaptedForLib2()
    // h()
    // g()
    utility111(mc)

    // g()
    // h()
    utility222(mc)

    // g()
    // h()
    useMyClass2(mc.field)
}
```

_useMyClass2(mc.field)_ 처럼 명시적으로 _MyClass2_ 객체에 접근한다.  

**위 코드 역시 기존 라이브러리를 새로운 인터페이스에 맞게 전환하여 연결하는 문제를 쉽게 해결**해준다.

---

## 5.5. 멤버 함수와 확장 함수 비교

[5.4. 어댑터 패턴](#54-어댑터-패턴) 에서 본 것처럼 **확장 함수는 어댑터를 생성할 때 유용할 듯 싶지만, 확장 함수를 모아서 인터페이스를 구현할 수는 없다.**

**이럴 땐 확장 함수 대신 멤버 함수를 사용**하면 된다.  
함수가 private 멤버에 접근해야 한다면 멤버 함수를 정의할 수 밖에 없다.

```kotlin
class Z(var i: Int = 0) {
    private var j = 0
    fun incr() {
        i++
        j++
    }
}

fun Z.decr() {
    i--
    // private 멤버 변수이므로 접근 불가
    //j--
}
```

[1.2. 자바에서 확장 함수 호출](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#12-%EC%9E%90%EB%B0%94%EC%97%90%EC%84%9C-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-%ED%98%B8%EC%B6%9C) 에서 본 것처럼 
확장 함수는 정적 메서드와 같은 특징을 갖기 때문에 확장 함수를 파생 클래스에서 오버라이드 할 수 없다.

**확장 함수는 오버라이드를 할 수 없다.**

```kotlin
open class Base {
    // 멤버 함수
    open fun f() = println("Base.f()")
}

class Derived : Base() {
    // 멤버 함수
    override fun f() = println("Derived.f()")
}

// 확장 함수
fun Base.g() = println("Base.g()")

fun Derived.g() = println("Derived.g()")

fun useBase(b: Base) {
    println("useBase: ${b::class.simpleName}")
    println(b.f())
    println(b.g())
}

fun main() {
    // useBase: Base
    // Base.f()
    // kotlin.Unit
    // Base.g()
    // kotlin.Unit
    useBase(Base())

    // useBase: Derived
    // Derived.f()
    // kotlin.Unit
    // Base.g()  --> 멤버 함수인 f() 에서는 다형성이 동작하지만, 확장 함수인 g() 에서는 작동하지 않음
    // kotlin.Unit
    useBase(Derived())
}
```

위 코드를 보면 **멤버 함수인 _f()) 에서는 다형성이 동작하지만, 확장 함수인 _g()_ 에서는 작동하지 않는 것**을 알 수 있다.

함수를 오버라이드할 필요가 없고, 클래스의 공개 멤버만으로 충분할 때는 이를 멤버 함수로 구현하던 확장 함수로 구현하던 상관없다.

<**멤버 함수와 확장 함수를 사용하는 기준**>  
- **멤버 함수**
  - 타입의 핵심을 반영
  - 그 멤버 함수가 없이는 그 타입이 동작하지 않는 경우
- **확장 함수**
  - 타입의 존재에 필수적이지 않을 경우
  - 대상 타입을 지원하고 활용하기 위한 외부 연산이나 편리를 위한 연산

> 어떤 클래스를 확장한 함수와 그 클래스의 멤버 함수의 이름과 시그니처가 같다면 확장 함수가 아니라 멤버 함수가 호출됨  
> (= 멤버 함수의 우선 순위가 더 높음)

---

### 5.5.1. 멤버 함수의 사용

아래 _Device_ 인터페이스에서 _model_, _productionYear_ 프로퍼티는 핵심 특성이므로 _Device_ 의 본질을 의미한다.  
하지만 _overpriced()_, _outdated()_ 는 멤버로도, 확장 함수로도 정의될 수 있다.

아래는 멤버 함수로 정의한 예시이다.

```kotlin
interface Device {
    val model: String
    val productionYear: Int

    // 멤버 함수로 정의
    fun overpriced() = model.startsWith("i")
    fun outdated() = productionYear < 2050
}

class MyDevice(override val model: String, override val productionYear: Int) : Device

fun main() {
    val aa: Device = MyDevice("car", 2000)

    println(aa.overpriced()) // false
    println(aa.outdated()) // true
}
```

---

### 5.5.2. 멤버 함수를 확장 함수로 변경

만일 위 코드에서 _overpriced()_, _outdated()_ 를 파생 클래스에서 오버라이드할 가능성이 없다면 아래와 같이 확장으로 정의할 수 있다.

```kotlin
interface Device1 {
    val model: String
    val productionYear: Int
}

// 확장 함수로 정의
fun Device1.overpriced() = model.startsWith("i")
fun Device1.outdated() = productionYear < 2050

class MyDevice1(override val model: String, override val productionYear: Int) : Device1

fun main() {
    val aa: Device1 = MyDevice1("car", 2000)

    println(aa.overpriced()) // false
    println(aa.outdated()) // true
}
```

바로 위 코드는 인터페이스의 특성을 잘 설명해주는 멤버만 들어있으므로 [5.5.1. 멤버 함수의 사용](#551-멤버-함수의-사용) 보다 더 나은 선택이다.  

**진짜 상속이 필요한 경우가 아니라면 상속보다는 확장 함수와 합성을 선택**하는 것이 좋다!

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