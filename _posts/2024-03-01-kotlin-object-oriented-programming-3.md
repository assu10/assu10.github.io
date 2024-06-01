---
layout: post
title:  "Kotlin - 객체 지향 프로그래밍(3): 클래스 위임, 상속/합성/클래스 위임, 다운 캐스트('is', 'as'), 봉인된 클래스('sealed')"
date:   2024-03-01
categories: dev
tags: kotlin 
---

이 포스트에서는 코틀린의 클래스 위임, 다운 캐스트, 봉인된 클래스에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 클래스 위임 (class delegation)](#1-클래스-위임-class-delegation)
  * [1.1. 수동으로 위임](#11-수동으로-위임)
  * [1.2. 자동으로 위임: `by`](#12-자동으로-위임-by)
  * [1.3. 클래스 위임을 이용하여 다중 클래스 상속 흉내](#13-클래스-위임을-이용하여-다중-클래스-상속-흉내)
  * [1.4. 상속의 제약과 상속/합성/클래스 위임](#14-상속의-제약과-상속합성클래스-위임)
* [2. 다운 캐스트 (downcast, RTTI, Run-Time Type Identification)](#2-다운-캐스트-downcast-rtti-run-time-type-identification)
  * [2.1. 스마트 캐스트: `is`](#21-스마트-캐스트-is)
  * [2.2. 변경 가능한 참조](#22-변경-가능한-참조)
  * [2.3. `as` 키워드](#23-as-키워드)
    * [2.3.1. 안전하지 않은 캐스트: `as`](#231-안전하지-않은-캐스트-as)
    * [2.3.2. 안전한 캐스트: `as?`](#232-안전한-캐스트-as)
  * [2.4. 리스트 원소의 타입 알아내기: `filterIsInstance()`](#24-리스트-원소의-타입-알아내기-filterisinstance)
* [3. 봉인된 클래스: `sealed`](#3-봉인된-클래스-sealed)
  * [3.1. 봉인된 클래스 사용](#31-봉인된-클래스-사용)
  * [3.2. `sealed` 와 `abstract` 비교](#32-sealed-와-abstract-비교)
  * [3.2. 파생 클래스 열거: `::class`, `sealedSubclasses`](#32-파생-클래스-열거-class-sealedsubclasses)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 클래스 위임 (class delegation)

합성은 내포된 객체의 기능을 사용하지만 인터페이스를 노출하지는 않는다.

**클래스가 기존의 구현을 재사용하면서 동시에 인터페이스도 구현해야 하는 경우 상속과 클래스 위임 둘 중 하나**를 선택할 수 있다.

- **클래스 위임**
  - 합성과 마찬가지로 새로운 클래스 안에 멤버 객체를 심음
  - 상속과 마찬가지로 심겨진 하위 객체의 인터페이스 노출
  - 새로운 클래스를 하위 객체의 타입으로 업캐스트 가능

위와 같은 이유로 코드를 재사용하기 위해 클래스 위임은 합성을 상속만큼 강력하게 만들어준다.

---

## 1.1. 수동으로 위임

> 코틀린에서는 클래스는 자동으로 위임해주는 기능이 있으므로 아래 코드는 참고만 할 것

아래 코드에서 _SpaceShip_ 이 _Controls_ 가 필요한 상황이라고 해보자.

```kotlin
interface Controls {
    fun up(velocity: Int): String
    fun down(velocity: Int): String
}

class SpaceShipControls : Controls {
    override fun up(velocity: Int): String = "up $velocity"
    override fun down(velocity: Int): String = "down $velocity"
}
```

여기서 _Controls_ 의 기능을 확장하거나 함수를 변경하려 한다면 _SpaceShipControls_ 를 상속하려 하겠지만, _SpaceShipControls_ 는 `open` 이 아니라서 상속할 수 없다.

**_Controls_ 의 멤버 함수를 노출하려면 _SpaceShipControls_ 의 인스턴스를 프로퍼티로 하고, _Controls_ 의 모든 멤버 함수를 명시적으로 _SpaceShipControls_ 에 위임**해야 한다.

```kotlin
interface Controls1 {
    fun up(velocity: Int): String
    fun down(velocity: Int): String
}

class SpaceShipControls1 : Controls1 {
    override fun up(velocity: Int): String = "up $velocity"
    override fun down(velocity: Int): String = "down $velocity"
}

class ExplicitControls : Controls1 {
    // SpaceShipControls1 의 인스턴스를 프로퍼티로 함
    private val controls = SpaceShipControls1()

    // 수동으로 위임 구현
    override fun up(velocity: Int): String = controls.up(velocity)

    // 변형한 구현
    override fun down(velocity: Int): String = controls.down(velocity) + "...!!!"
}

fun main() {
    val controls = ExplicitControls()

    val result1 = controls.up(1)
    val result2 = controls.down(2)
  
    println(result1) // up 1
    println(result2) // down 2...!!!
}
```

위 코드를 보면 모든 함수를 내부에 있는 _controls_ 객체에 바로 전달하였다.  
이 클래스가 제공하는 인터페이스는 일반적인 상속에서 사용하는 인터페이스와 동일하며, 원한다면 일부 변경한 구현을 제공할 수도 있다.

---

## 1.2. 자동으로 위임: `by`

코틀린은 이런 클래스 위임 과정을 자동화해준다.  
위의 _ExplicitControls_ 처럼 직접 함수 구현을 하는 대신 위임에 사용할 객체를 지정하기만 하면 된다.

**클래스를 위임하려면 `by` 키워드를 인터페이스 이름 뒤에 넣고, `by` 뒤에 위임할 멤버 프로퍼티의 이름**을 넣으면 된다.

```kotlin
interface A1

class A : A1

// 클래스 B 는 A1 인터페이스를 a 멤버 객체를 사용(by)하여 구현함
class B(val a: A) : A1 by a
```

**인터페이스에만 위임을 적용**할 수 있고, **위임 객체(_a_) 는 생성자 인자로 지정한 프로퍼티**이어야 한다.

이제 `by` 를 사용하여 [1.1. 수동으로 위임](#11-수동으로-위임) 의 _ExplicitControls_ 을 재작성해해본다.

```kotlin
interface Controls2 {
    fun up(velocity: Int): String
    fun down(velocity: Int): String
}

class SpaceShipControls2 : Controls2 {
    override fun up(velocity: Int): String = "up $velocity"
    override fun down(velocity: Int): String = "down $velocity"
}

// 클래스 DelegatedControls 는 Controls2 인터페이스를 controls 를 사용(by) 하여 구현함
class DelegatedControls(private val controls: SpaceShipControls2 = SpaceShipControls2()) : Controls2 by controls {
    override fun down(velocity: Int): String = controls.down(velocity) + "...!!!"
}

fun main() {
    val controls = DelegatedControls()

    val result1 = controls.up(1)
    val result2 = controls.down(2)

    println(result1) // up 1
    println(result2) // down 2...!!!
}
```

위임을 하면 별도로 작성하지 않아도 멤버 객체의 함수를 외부 객체를 통해 접근할 수 있다. (위에서 _controls.up(1)_ 을 호출한 것처럼)

---

## 1.3. 클래스 위임을 이용하여 다중 클래스 상속 흉내

코틀린은 다중 클래스 상속을 허용하지 않지만, 클래스 위임을 사용하여 다중 클래스 상속을 흉내낼 수 있다.

```kotlin
package assu.study.kotlinme.chap05.classDelegation

interface Rectangle {
    fun paint(): String
}

class ButtonImage(val width: Int, val height: Int) : Rectangle {
    override fun paint() = "painting button image($width, $height)"
}

interface Mouse {
    fun clicked(): Boolean
    fun hover(): Boolean
}

class UserInput : Mouse {
    override fun clicked() = true
    override fun hover() = true
}

// ButtonImage 와 UserInput 을 open 으로 정의해도 하위 타입을 정의할 때는
// 상위 타입 목록에 클래스를 하나만 넣을 수 있기 때문에 아래와 같이 사용 불가
// class Button: ButtonImage(), UserInput()

// 클래스 Button 은 Rectangle 인터페이스를 image 를 사용(by) 하여 구현하고, Mouse 인터페이스를 input 을 사용(by) 하여 구현함
class Button(
    val width: Int,
    val height: Int,
    var image: Rectangle = ButtonImage(width, height), // public 이면서 var 임
    private var input: Mouse = UserInput(),
) : Rectangle by image, Mouse by input

fun main() {
    val button = Button(10, 5)

    // 동적으로 ButtonImage 변경 가능
    button.image = ButtonImage(1, 2)

    val result1 = button.paint()
    val result2 = button.clicked()
    val result3 = button.hover()

    println(result1) // painting button image(10, 5)
    println(result2) // true
    println(result3) // true

    // 위임한 2개의 타입으로 업캐스트 가능
    val rectangle: Rectangle = button
    val mouse: Mouse = button

    val result4 = rectangle.paint()
    val result5 = mouse.clicked()
    val result6 = mouse.hover()

    println(result4) // painting button image(10, 5)
    println(result5) // true
    println(result6) // true
}
```

_Button_ 클래스는 _Rectangle_, _Mouse_ 두 개의 인터페이스를 모두 구현한다.    
_Button_ 클래스가 _ButtonImage_, _UserInput_ **두 개의 클래스의 구현을 모두 상속할 수는 없지만, 이 두 개의 클래스를 모두 위임할 수는 있다.** 

_Button_ 클래스의 생성자 인자 목록 중 _image_ 의 정의가 public 이면서 var 이기 때문에 프로그래머가 동적으로 _ButtonImage_ 를 변경할 수 있다.

위 코드에서 아래 내용은 _Button_ 이 자신을 위임한 2개의 타입으로 업캐스트할 수 있음을 보여준다.  
이것이 **바로 다중 상속의 목표**이다.

이렇게 **위임은 다중 상속의 필요성을 해결**해준다.

```kotlin
val button = Button(10, 5)

...

val rectangle: Rectangle = button
val mouse: Mouse = button
```

---

## 1.4. 상속의 제약과 상속/합성/클래스 위임

상위 클래스가 `open` 이 아니거나, 새 클래스가 다른 클래스를 이미 상속하고 있으면 다른 클래스를 상속할 수 없다는 점에서 상속은 제약이 될 수 있다.  
이러한 제약을 클래스 위임이 해결해준다.

**합성, 상속, 클래스 위임이라는 선택지가 있을 때는 합성을 먼저 시도**하는 것이 좋다.  

> 합성에 대한 좀 더 상세한 내용은 [4. 합성 (Composition)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#4-%ED%95%A9%EC%84%B1-composition) 을 참고하세요.

**즉, 합성 → 상속 → 클래스 위임**의 순으로 고려를 하는 것이 좋다.  
합성은 가장 단순한 방법이며 대부분의 케이스를 해결해준다.  

**타입 계층과 이 계층에 속한 타입 사이의 관계가 필요할 때는 상속이 필요**하다.  

상속, 합성이 모두 적합하지 않을 경우 위임을 사용한다.

---

# 2. 다운 캐스트 (downcast, RTTI, Run-Time Type Identification)

다운 캐스트는 업캐스트했던 객체의 구체적인 타입을 발견한다.

**기반 클래스가 파생 클래스보다 더 큰 인터페이스를 가질 수 없으므로 업캐스트는 항상 안전**하다.  
모든 기반 클래스 멤버가 존재한다고 보장할 수 있기 때문에 멤버를 호출해도 안전하다.

하지만 상황에 따라 다운 캐스트가 유용할 때가 있다.

다운 캐스트는 실행 시점에 일어나며 **실행 시점 타입 식별** (**RTTI**, Run-Time Type Identification) 이라고도 한다.

객체를 기반 타입으로 업캐스트하면 컴파일러는 그 객체의 구체적인 타입을 더 이상 알 수 없으며, 하위 타입에 추가된 함수 중에 어떤 함수를 호출해도 안전한지 결정할 수 없다.

```kotlin
interface Base {
    fun f()
}

class Derived1: Base {
    override fun f() {}
    fun g() {}
}

class Derived2: Base {
    override fun f() {}
    fun h() {}
}

fun main() {
    // 업캐스트
    val b1: Base = Derived1()
    
    b1.f()  // 기반 클래스의 멤버 함수
    //b1.g()    // 기반 클래스에 없는 함수
    
    // 업캐스트
    val b2: Base = Derived2()
    b2.f()  // 기반 클래스의 멤버 함수
    //b2.h()  // 기반 클래스에 없는 함수
}
```

위와 같은 문제를 해결하려면 다운 캐스트가 올바른지 보장하는 방법이 필요하다.

---

## 2.1. 스마트 캐스트: `is`

스마트 캐스트는 타입 검사, 타입 캐스트, 타입 강제 변환을 합친 것이다.

**스마트 캐스트는 자동 다운 캐스트**이다.  
**`is` 키워드는 어떤 객체가 특정 타입인지 검사**하는데, 이 **검사 영역 안에서는 해당 객체를 검사에 성공한 타입으로 간주**한다.  

`is` 는 자바의 `instanceof` 와 비슷한데 자바에서는 타입을 `instanceof` 로 확인한 후에 그 타입에 속한 멤버에 접근하기 위해 명시적으로 타입 캐스팅을 해야 한다.  
하지만 **코틀린은 `is` 로 검사하고 나면 컴파일러가 캐스팅을 수행해준다. (= 스마트 캐스트**)

**스마트 캐스트는 `is` 로 변수에 든 값의 타입을 검사한 후 그 값이 바뀔 수 없는 경우에만 동작**한다.  
**만일 클래스의 프로퍼티에 대해 스마트 캐스트를 사용한다면 그 프로퍼티는 반드시 val 이어야 하며, 커스텀 접근자를 사용한 것이어도 안된다.**    
val 가 아니거나, val 이지만 커스텀 접근자를 사용하는 경우 해당 프로퍼티에 대한 접근이 항상 같은 값을 내놓는다고 확신할 수 없기 때문이다.

> 커스텀 접근자에 대한 좀 더 상세한 내용은 [9. 프로퍼티 접근자](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90) 를 참고하세요.

**원하는 타입으로 명시적으로 타입 캐스팅을 하려면 `as` 키워드를 사용**한다.

> `as` 키워드에 대한 좀 더 상세한 내용은 [2.3. `as` 키워드](#23-as-키워드) 를 참고하세요.

```kotlin
interface Base11 {
    fun f()
}

class Derived11 : Base11 {
    override fun f() {}
    fun g() {}
}

class Derived22 : Base11 {
    override fun f() {}
    fun h() {}
}

fun main() {
    val b1: Base11 = Derived11() // 업캐스트
    // b1.g()   // 호출 불가
    if (b1 is Derived11) {
        b1.g()  // 호출 가능 `is` 검사의 영역 내부
    }
    
    val b2: Base11 = Derived22()    // 업캐스트
    // b2.h();  // 호출 불가
    if (b2 is Derived22) {
        b2.h()  // 호출 가능, `is` 검사의 영역 내부
    }
}
```

> intelliJ 는 스마트 캐스트가 된 변수의 배경색을 다르게 표시해줌 

스마트 캐스트는 `is` 를 통해 when 의 인자가 어떤 타입인지 검색하는 when 식 내부에서 매우 유용하다.

아래는 각각의 구체적인 타입을 먼저 _Creature_ 로 업캐스트한 후에 _what()_ 에 전달했다.

```kotlin
interface Creature

class Human : Creature {
    fun greeting(): String = "Human~"
}

class Dog : Creature {
    fun bark() = "Bark~"
}

class Cat : Creature {
    fun yaong() = "yaong~"
}

// 이미 업캐스트된 Creature 를 받아서 정확한 타입을 찾음
// 이 후 Creature 객체를 상속 계층에서 정확한 타입, 정확한 파생 클래스로 다운 캐스트함
fun what(c: Creature): String =
    when (c) {
        is Human -> c.greeting()
        is Dog -> c.bark()
        is Cat -> c.yaong()
        else -> "WHAT?"
    }

fun main() {
    val c: Creature = Human() // 업캐스트

    val result1 = what(c)
    val result2 = what(Dog())   // 업캐스트가 일어남
    val result3 = what(Cat())   // 업캐스트가 일어남

    class Who : Creature    // 업캐스트

    val result4 = what(Who())

    println(result1) // Human~
    println(result2) // Bark~
    println(result3) // yaong~
    println(result4) // WHAT?
}
```

---

## 2.2. 변경 가능한 참조

**자동 다운 캐스트는 대상이 상수일때만 제대로 동작**한다.

대상 객체를 가리키는 기반 클래스 타입의 참조가 변경 가능(`var`) 할 때 타입을 검증한 시점과 다운 캐스트한 객체에 대해 함수를 호출한 시점 사이에 참조가 가리키는 객체가 
바뀔 가능성이 있다. 즉, **타입 검사와 사용 시점 사이에 객체의 구체적인 타입이 달라질 수 있다는 의미**이다.

```kotlin
interface Creature1

class Human1 : Creature1 {
    fun greeting(): String = "Human~"
}

class Dog1 : Creature1 {
    fun bark() = "Bark~"
}

class Cat1 : Creature1 {
    fun yaong() = "yaong~"
}

// 인자가 val (불변) 임
class SmartCast1(val c: Creature1) {
    fun contact(): String =
        when (c) {
            is Human1 -> c.greeting()
            is Dog1 -> c.bark()
            is Cat1 -> c.yaong()
            else -> "WHAT?"
        }
}

// 인자가 var(변경 가능) 임
class SmartCast2(var c: Creature1) {
    fun contact(): String =
        when (val c = c) { // 편의상 이렇게 했지만 추천하지 않음
            is Human1 -> c.greeting()
            is Dog1 -> c.bark()
            is Cat1 -> c.yaong()
            else -> "WHAT?"
        }

        // 모두 아래와 같은 컴파일 오류
        // Smart cast to 'Human1' is impossible,
        // because 'c' is a mutable property that could have been changed by this time
        // c 가 이 시점에서 변했을 수 있는 가변 프로퍼티이기 때문에 Human 으로 스마트 캐스트할 수 없다는 의미
        
    //    when (c) { // 편의상 이렇게 했지만 추천하지 않음
    //        is Human1 -> c.greeting()
    //        is Dog1 -> c.bark()
    //        is Cat1 -> c.yaong()
    //        else -> "WHAT?"
    //    }
}

fun main() {
    val c: Creature1 = Human1() // 업캐스트

    val result1 = SmartCast1(c).contact()
    val result2 = SmartCast1(Dog1()).contact() // 업캐스트가 일어남
    val result3 = SmartCast1(Cat1()).contact() // 업캐스트가 일어남

    val result4 = SmartCast2(c).contact()
    val result5 = SmartCast2(Dog1()).contact() // 업캐스트가 일어남
    val result6 = SmartCast2(Cat1()).contact() // 업캐스트가 일어남

    println(result1) // Human~
    println(result2) // Bark~
    println(result3) // yaong~
  
    println(result4) // Human~
    println(result5) // Bark~
    println(result6) // yaong~
}
```

위에서 _SmartCast2_ 의 주석 처리되어 있는 _when_ 절을 주석 해제하면 아래와 같은 오류가 나면서 컴파일이 되지 않는다.

```shell
Smart cast to 'Human1' is impossible,
because 'c' is a mutable property that could have been changed by this time
```

c 가 이 시점에서 변했을 수 있는 가변 프로퍼티이기 때문에 Human 으로 스마트 캐스트할 수 없다는 의미이다.

**코틀린은 `is` 로 위의 _c_ 타입을 검사하는 시점과 _c_ 를 다운 캐스트한 타입으로 사용하는 시점 사이에 _c_ 의 값이 변하지 않도록 강제**한다.

위 코드에서 _SmartCast1_ 은 _c_ 프로퍼티를 `val` 로 만들어서 변화를 막고, _SmartCast2_ 는 지역 변수 `val c` 를 이용하여 변화를 막고 있다.

<**스마트 캐스트가 되지 않는 경우**>  
- 특정 식이 재계산 될 수 있는 경우
- 상속을 위해 `open` 된 프로퍼티도 파생 클래스에서 오버라이드를 할 수 있고, 그로 인해 프로퍼티에 접근할 때마다 항상 같은 같은 내놓는다고 보장할 수 없으므로 스마트 캐스트가 안됨

---

## 2.3. `as` 키워드

### 2.3.1. 안전하지 않은 캐스트: `as`

**`as` 키워드는 일반적인 타입을 구체적인 타입으로 강제 변환**한다.

```kotlin
interface Creature2

class Dog2 : Creature2 {
    fun bark() = "Bark~"
}

class Cat2 : Creature2 {
    fun yaong() = "yaong~"
}

fun dogBarkUnsafe(c: Creature2) = (c as Dog2).bark()

fun dogBarkUnsafe2(c: Creature2): String {
    c as Dog2 // `as` 로 선언해준 이후부터는 c 를 Dog2 객체처럼 사용 가능
    c.bark()

    return c.bark() + c.bark()
}

fun main() {
    val result1 = dogBarkUnsafe(Dog2())
    val result2 = dogBarkUnsafe2(Dog2())

    val result3 = dogBarkUnsafe(Cat2())
    val result4 = dogBarkUnsafe2(Cat2())

    println(result1)
    println(result2)

    println(result3)
    println(result4)
}
```

위 코드를 실행하면 컴파일 시점이 아닌 런타임 시점에 아래와 같은 오류가 발생한다.

```shell
java.lang.ClassCastException: class assu.study.kotlinme.chap05.downcasting.Cat2 cannot be cast to class assu.study.kotlinme.chap05.downcasting.Dog2
```

```kotlin
fun dogBarkUnsafe(c: Creature2) = (c as Dog2).bark()    // 이 부분에서 캐스트 실패

...

val result3 = dogBarkUnsafe(Cat2())
```

`as` 가 실패하면 `ClassCastException` 이 발생한다.  
**일반 `as` 를 안전하지 않은 캐스트**라고 한다.

---

### 2.3.2. 안전한 캐스트: `as?`

안전한 캐스트는 `as?` 는 실패 시 예외를 던지지 않고 null 을 반환하기 때문에 NPE 를 방지하기 위해 적절한 조취가 필요하다.

[2. 안전한 호출(safe call)과 엘비스(Elvis) 연산자](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#2-%EC%95%88%EC%A0%84%ED%95%9C-%ED%98%B8%EC%B6%9Csafe-call%EA%B3%BC-%EC%97%98%EB%B9%84%EC%8A%A4elvis-%EC%97%B0%EC%82%B0%EC%9E%90) 에서 본 엘비스 연산자가 가장 간단하고 적합하다.

```kotlin
interface Creature3

class Dog3 : Creature3 {
    fun bark() = "Bark~"
}

class Cat3 : Creature3 {
    fun yaong() = "yaong~"
}

fun dogBarkSafe(c: Creature3) = (c as? Dog3)?.bark() ?: "Not a dog"

fun main() {
    val result1 = dogBarkSafe(Dog3())
    val result2 = dogBarkSafe(Cat3())

    println(result1)    // Bark~
    println(result2)    // Not a dog
}
```

위에서 아래 코드를 보자.
```kotlin
(c as? Dog3)?.bark() ?: "Not a dog"
```

_(c as? Dog3)_ 은 null 이 될 수 있는 식이며, _bark()_ 를 호출할 때는 안전한 호출 연산자인 `?.` 를 사용해야 한다.  
`as?` 이 null 을 반환하면 전체 식인 _(c as? Dog3)?.bark()_ 도 null 을 반환하기 때문에 이 값을 엘비스 연산자인 `?:` 가 받아서 null 일 경우의 조치를 취한다. 

---

## 2.4. 리스트 원소의 타입 알아내기: `filterIsInstance()`

Predicate 에서 `is` 를 사용하면 List 나 다른 iterable (이터레이션을 할 수 있는 대상 타입) 의 원소가 주어진 타입의 객체인지 알 수 있다.

````kotlin
interface Creature4

class Human4 : Creature4 {
    fun greeting(): String = "Human~"
}

class Dog4 : Creature4 {
    fun bark() = "Bark~"
}

class Cat4 : Creature4 {
    fun yaong() = "yaong~"
}

val group: List<Creature4> =
    listOf(
        Human4(),
        Human4(),
        Dog4(),
        Cat4(),
        Dog4(),
    )

fun main() {
    // group 에 Creature4 가 들어있으므로 find() 는 Creature4 를 반환함
    // 이 객체를 Dog4 로 다루려고 아래처럼 명시적으로 타입을 변환함
    // group 안에 Dog4 가 하나도 없으면 find() 가 null 을 반환하므로 결과를 null 이 될 수 있는 타입인 Dog4? 로 변환
    val result = group.find { it is Dog4 } as Dog4?

    // result 가 null 이 될 수 있는 타입이므로 안전한 호출 연산자를 사용
    println(result?.bark()) // Bark~
}
````

---

보통은 지정한 타입에 속하는 모든 원소를 돌려주는 `filterIsInstance()` 를 사용하기 때문에 위에서 _group.find { it is Dog4 } as Dog4?_ 과 같은 코드는 거의 사용하지 않는다. 

```kotlin
interface Creature5

class Human5 : Creature5 {
    fun greeting(): String = "Human~"
}

class Dog5 : Creature5 {
    fun bark() = "Bark~"
}

class Cat5 : Creature5 {
    fun yaong() = "yaong~"
}

val group2: List<Creature5> =
    listOf(
        Human5(),
        Human5(),
        Dog5(),
        Dog5(),
        Dog5(),
    )

fun main() {
    // 반환값의 모든 원소가 Dog5 임에도 불구하고 Creature5 의 List 를 반환함
    val result1: List<Creature5> = group2.filter { it is Dog5 }
    println(result1.size) // 3

    val result2: List<Creature5> = group2.filter { it is Cat5 }
    println(result2.size) // 0

    // 대상 타입인 Dog5 의 리스트를 반환
    val result3: List<Dog5> = group2.filterIsInstance<Dog5>()
    println(result3.size) // 3

    val result4: List<Cat5> = group2.filterIsInstance<Cat5>()
    println(result4.size) // 0

    // mapNotNull() 사용
    val result5: List<Creature5> = group2.mapNotNull { it as? Dog5 }
    println(result5.size) // 3

    val result6: List<Cat5> = group2.mapNotNull { it as? Cat5 }
    println(result6.size) // 0
}
```

`filter()` 는 반환값의 모든 원소가 Dog5 임에도 불구하고 Creature5 의 List 를 반환하는 반면 `filterIsInstance()` 는 대상 타입인 Dog5 의 리스트를 반환한다.  

---

# 3. 봉인된 클래스: `sealed`

## 3.1. 봉인된 클래스 사용

클래스 계층을 제한하려면 기반 클래스를 `sealed` 로 선언하면 된다.

```kotlin
open class Transport

data class Train(val line: String) : Transport()

data class Bus(val number: String, val capacity: Int) : Transport()

fun travel(transport: Transport) =
    when (transport) {
        is Train -> "Train ${transport.line}"
        is Bus -> "Bus ${transport.number}: size ${transport.capacity}"
        else -> "$transport is in limbo~"   // // else 구문이 없으면 컴파일 오류
    }

fun main() {
    val result =
        listOf(Train("AA"), Bus("BB", 5))
            .map(::travel)

    println(result) // [Train AA, Bus BB: size 5]
}
```

위 코드의 when 에서 else 문이 없으면 아래와 같은 오류가 나면서 컴파일이 되지 않는다.
```shell
'when' expression must be exhaustive, add necessary 'else' branch
```

위에서 _travel()_ 은 다운 캐스트가 근본적인 문제가 될 수 있는 지점이다.  
만일 _Transport_ 를 상속한 _Tram_ 이라는 클래스가 새로 정의되면 _travel()_ 은 여전히 컴파일 되고 실행도 되지만, _Tram_ 추가에 맞춰서 when 을 바꾸어야 한다는 아무런 단서가 없다.  

이렇게 코드에서 다운 캐스트가 여기저기 흩어져 있다면 이로 인해 유지보수가 힘들어진다.

이런 상황을 `sealed` 키워드로 개선할 수 있다.  
`sealed` 클래스를 직접 상속한 파생 클래스는 반드시 기반 클래스와 같은 패키지와 모듈 안에 있어야만 하기 때문에 다운 캐스트가 여기저기 흩어지는 문제가 없다.

> **코틀린에서 모듈**  
> 
> 한 번에 같이 컴파일되는 모든 파일을 묶어서 부르는 개념

**`sealed` 키워드로 상속을 제한한 클래스를 봉인된 클래스**라고 부른다.  
위 코드의 `open` 을 `sealed` 로만 변경해주면 된다.

```kotlin
sealed class Transport1

data class Train1(val line: String) : Transport1()

data class Bus1(val number: String, val capacity: Int) : Transport1()

fun travel1(transport: Transport1) =
  when (transport) {
    is Train1 -> "Train ${transport.line}"
    is Bus1 -> "Bus ${transport.number}: size ${transport.capacity}"
    // else 구문이 없어도 됨
  }

fun main() {
  val result =
    listOf(Train1("AA"), Bus1("BB", 5))
      .map(::travel1)

  println(result) // [Train AA, Bus BB: size 5]
}
```

코틀린의 when 식은 모든 경우를 검사하도록 강제하기 때문에 else 문을 요구하지만 위 코드에서 _Transport1_ 은  `sealed` 라서 다른 _Transport1_ 의 
파생 클래스가 존재할 수 없다는 사실은 확신할 수 있으므로 위 코드에서는 else 문을 요구하지 않는다.

만일 위 코드에서 새로운 파생 클래스를 선언하면 when 식에서 아래와 같은 오류가 나면서 컴파일이 되지 않는다.
```kotlin
data class Bus2(val number: String, val capacity: Int) : Transport1()
```

```shell
'when' expression must be exhaustive, add necessary 'is Bus2' branch or 'else' branch instead
```

새로운 파생 클래스를 도입하면 기존 타입 계층을 사용하던 모든 코드를 수정해야 한다.

`sealed` 키워드는 다운 캐스트를 좀 더 쓸만하게 만들어준다.  
하지만 보통 `sealed` 가 아닌 다형성을 이용하여 코드를 좀 더 깔끔하게 작성할 수 있다.

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

---

## 3.2. `sealed` 와 `abstract` 비교

아래는 `abstract`, `sealed` 클래스가 타입이 똑같은 함수, 프로퍼티, 생성자를 제공하는 케이스이다.

```kotlin
abstract class CustomAbstract(val av: String) {
    open fun concreteFunction() {}
    open val concreteProperty = ""
    abstract fun abstractFunction(): String
    abstract val abstractProperty: String
    // 주생성자
    init {}
    // 부생성자
    constructor(c: Char) : this(c.toString())
}

open class Concrete() : CustomAbstract("") {
    override fun concreteFunction() {}
    override val concreteProperty = ""
    override fun abstractFunction() = ""
    override val abstractProperty = ""
}

sealed class Sealed(val av: String) {
    open fun concreteFunction() {}
    open val concreteProperty = ""
    abstract fun abstractFunction(): String
    abstract val abstractProperty: String
    // 주생성자
    init {}
    // 부생성자
    constructor(c: Char) : this(c.toString())
}

open class SealedSubclass() : Sealed("") {
    override fun concreteFunction() {}
    override val concreteProperty = ""
    override fun abstractFunction() = ""
    override val abstractProperty = ""
}

fun main() {
    Concrete()
    SealedSubclass()
}
```

코드를 보면 알겠지만 `sealed` 클래스는 기본적으로 파생 클래스가 모두 같은 파일 안에 정의되어야 한다는 제약이 가해진 `abstract` 클래스이다.

`sealed` 클래스의 간접적인 파생 클래스는 별도의 파일에 정의 가능하다.

다른 파일에 정의한 클래스
```kotlin
class ThirdLevel : SealedSubclass()
```

위의 _ThirdLevel_ 클래스는 직접 _Sealed_ 클래스를 상속하지 않으므로 다른 파일에 위치할 수 있다.

> 주생성자 `init` 에 관한 좀 더 상세한 내용은 [2. 복잡한 생성자: `init`](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#2-%EB%B3%B5%EC%9E%A1%ED%95%9C-%EC%83%9D%EC%84%B1%EC%9E%90-init) 를 참고하세요.

> 부생성자 `constructor()` 에 관한 좀 더 상세한 내용은 [3. 부생성자 (secondary constructor): `constructor`](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#3-%EB%B6%80%EC%83%9D%EC%84%B1%EC%9E%90-secondary-constructor-constructor) 를 참고하세요.


`sealed` interface 도 유용하다.

---

## 3.2. 파생 클래스 열거: `::class`, `sealedSubclasses`

어떤 클래스가 `sealed` 인 경우 모든 파생 클래스를 쉽게 이터레이션할 수 있다.

```kotlin
sealed class Top

class Middle1 : Top()

class Middle2 : Top()

open class Middle3 : Top()

class Bottom2 : Middle3()

fun main() {
    val result =
        Top::class.sealedSubclasses
            .map { it.simpleName }

    // Bottom2 은 나오지 않음   
    println(result) // [Middle1, Middle2, Middle3]
}
```

클래스를 생성하면 클래스 객체가 생성된다.  
이 클래스 객체의 프로퍼티와 멤버 함수에 접근해서 클래스에 대한 정보를 얻고, 클래스에 속한 객체를 생성/조작할 수 있다.

**`::class` 가 클래스 객체를 돌려주기 때문에 _Top::class_ 는 _Top_ 에 대한 클래스 객체**를 만들어준다.

_Top::class_ 로 얻은 클래스 객체에 `sealedSubclasses` 클래스 객체의 프로퍼티를 적용하면 이 프로퍼티는 _Top_ 이 `sealed` 된 클래스이길 기대한다.  
따라서 _Top_ 이 `sealed` 가 아니면 빈 List 를 반환한다.

**`sealedSubclass` 는 이런 봉인된 클래스의 모든 파생 클래스를 반환**하는데, 이 때 봉인된 클래스의 직접적인 파생 클래스만 반환한다.  
위 코드를 보면 _Bottom2_ 는 이터레이션 결과에 포함되지 않는 것을 확인할 수 있다.

---

`sealedSubclasses` 는 다형적인 시스템을 만들 때 중요한 도구가 됟ㄹ 수 있는데, 새로운 클래스가 모든 적합한 연산에 자동으로 포함되도록 보장할 수 있다.  
하지만 `sealedSubclasses` 는 파생 클래스를 실행 시점에 찾아내므로 시스템 성능에 영향을 미칠 수 있기 때문에, 만일 성능 문제가 발생한다면 프로파일러를 사용하여
`sealedSubclasses` 가 문제의 원인인지 확실히 검토해보아야 한다.

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