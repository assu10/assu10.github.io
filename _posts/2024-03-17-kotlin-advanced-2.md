---
layout: post
title: "Kotlin - 제네릭스 (타입 정보 보존, 제네릭 확장 함수, 타입 파라메터 제약, 타입 소거, 'reified', 타입 변성 애너테이션 ('in'/'out'), 공변과 무공변)"
date: 2024-03-17
categories: dev
tags: kotlin generics filterIsInstance() typeParameter typeErasure reified kClass
---

이 포스트에서는 제네릭스에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 제네릭스](#1-제네릭스)
  * [1.1. `Any`](#11-any)
  * [1.2. 제네릭스 정의: `<>`](#12-제네릭스-정의-)
    * [1.2.1. 제네릭 함수와 프로퍼티](#121-제네릭-함수와-프로퍼티)
    * [1.2.2. 제네릭 클래스 선언](#122-제네릭-클래스-선언)
  * [1.3. 타입 정보 보존](#13-타입-정보-보존)
  * [1.4. 제네릭 확장 함수](#14-제네릭-확장-함수)
  * [1.5. 타입 파라메터 제약: `filterIsInstance()`](#15-타입-파라메터-제약-filterisinstance)
    * [1.5.1. 제네릭 타입 파라메터](#151-제네릭-타입-파라메터)
    * [1.5.2. 타입 파라메터 제약으로 지정](#152-타입-파라메터-제약으로-지정)
      * [1.5.2.1. 타입 파라메터에 둘 이상의 제약 지정: `where`](#1521-타입-파라메터에-둘-이상의-제약-지정-where)
    * [1.5.3. 제네릭하지 않은 타입으로 지정](#153-제네릭하지-않은-타입으로-지정)
    * [1.5.4. 다형성 대신 타입 파라메터 제약을 사용하는 이유](#154-다형성-대신-타입-파라메터-제약을-사용하는-이유)
    * [1.5.5. 타입 파라메터를 사용해야 하는 경우](#155-타입-파라메터를-사용해야-하는-경우)
  * [1.6. 타입 소거 (type erasure)](#16-타입-소거-type-erasure)
    * [1.6.1. 실행 시점의 제네릭: 타입 검사와 캐스트](#161-실행-시점의-제네릭-타입-검사와-캐스트)
  * [1.7. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`](#17-함수의-타입-인자에-대한-실체화-reified-kclass)
    * [1.7.1. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용](#171-reified-를-사용하여-is-를-제네릭-파라메터에-적용)
    * [1.7.2. 실체화한 타입 파라메터 활용: `filterIsInstance()`](#172-실체화한-타입-파라메터-활용-filterisinstance)
    * [1.7.3. 인라인 함수에서만 `reified` 키워드를 사용할 수 있는 이유](#173-인라인-함수에서만-reified-키워드를-사용할-수-있는-이유)
    * [1.7.4. 클래스 참조 대신 실체화한 타입 파라메터 사용: `ServiceLoader`, `::class.java`](#174-클래스-참조-대신-실체화한-타입-파라메터-사용-serviceloader-classjava)
    * [1.7.5. 실체화한 타입 파라메터의 제약](#175-실체화한-타입-파라메터의-제약)
  * [1.8. 타입 변성 (type variance)](#18-타입-변성-type-variance)
    * [1.8.1. 타입 변성: `in`/`out` 변성 애너테이션](#181-타입-변성-inout-변성-애너테이션)
    * [1.8.2. 타입 변성을 사용하는 이유](#182-타입-변성을-사용하는-이유)
      * [1.8.2.1. 클래스, 타입과 하위 타입](#1821-클래스-타입과-하위-타입)
      * [1.8.2.2. 공변성(covariant): 하위 타입 관계 유지 (`out`)](#1822-공변성covariant-하위-타입-관계-유지-out)
      * [1.8.2.3. 반공변성(contravariant): 뒤집힌 하위 타입 관계 (`in`)](#1823-반공변성contravariant-뒤집힌-하위-타입-관계-in)
      * [1.8.2.4. 무공변(invariant), 공변(covariant), 반공변(contravariant)](#1824-무공변invariant-공변covariant-반공변contravariant)
    * [1.8.3. 공변(covariant)과 무공변(invariant)](#183-공변covariant과-무공변invariant)
    * [1.8.4. 함수의 공변적인 반환 타입](#184-함수의-공변적인-반환-타입)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 제네릭스

**제네릭스는 나중에 지정할 타입에 대해 작동하는 코드를 의미**한다.

일반 클래스와 함수는 구체적인 타입에 대해 작동하는데 여러 타입에 걸쳐 작동하는 코드를 작성하고 싶을 때는 이런 견고함이 제약이 될 수 있다.

다형성은 객체 지향의 일반화 도구이다.

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

기반 클래스 객체를 파라메터로 받는 함수를 작성하고, 기반 클래스로부터 파생된 클래스의 객체를 사용하여 이 함수를 호출하면 좀 더 일반적인 함수가 된다.

다형적인 함수의 파라메터에 맞는 객체를 만들기 위해서는 클래스 계층을 상속해야하는데, 다형성을 활용하는 경우 단일 계층만 가능하다는 점은 심한 제약이 될 수 있다.  
함수 파라메터가 클래스가 아닌 인터페이스라면 인터페이스를 구현하는 모든 타입을 포함하도록 제약이 약간 완화된다.

이제 기존 클래스와 조합하여 인터페이스를 구현할 수 있고, 이 말을 여러 클래스 계층을 가로질러 인터페이스를 구현하여 사용할 수 있다는 의미이다.

인터페이스는 그 인터페이스만 사용하도록 강제하는데, 이런 제약을 완화하기 위해 코드가 **'미리 정하지 않은 타입' 인 제네릭 타입 파라메터**에 대해 동작하면 더욱 더 일반적인 코드가 될 수 있다.

---

## 1.1. `Any`

자바에서 Object 가 클래스 계층의 최상위 타입이듯 코틀린에서는 **`Any` 타입이 모든 null 이 될 수 없는 타입의 최상위 계층**이다.  
따라서 모든 코틀린 클래스는 `Any` 를 상위 클래스로 가진다.

하지만 자바에서는 wrapper 타입만 Object 를 최상위로 하는 타입 계층만 포함되며, primitive 타입은 그런 계층에 포함되지 않는다.

이 말은 자바에서 Object 타입의 객체가 필요할 경우 int 와 같은 primitive 타입은 java.lang.Integer 와 같은 래퍼 타입으로 감싸야한다는 의미이다.

하지만 **코틀린에서는 `Any` 가 Int 등의 primitive 타입을 포함한 모든 타입의 최상위 계층**이다.

> 원시 타입과 참조 타입은 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

> 코틀린의 primitive 타입은 [4.1. primitive 타입: Int, Boolean 등](https://assu10.github.io/dev/2024/02/04/kotlin-basic/#41-primitive-%ED%83%80%EC%9E%85-int-boolean-%EB%93%B1) 을 참고하세요.

자바처럼 코틀린에서도 primitive 타입 값을 `Any` 타입의 변수에 대입하면 자동으로 값을 객체로 감싼다.

```kotlin
// Any 가 wrapper 타입이므로 1 이 boxing 됨
val answer: Any = 1
```

**`Any` 는 null 이 될 수 없는 타입이므로 만일 null 을 포함하는 모든 값을 대입할 변수를 선언하려면 `Any?` 타입을 사용**해야 한다.

내부에서 `Any` 타입은 java.lang.Object 에 대응한다.

자바 메서드에서 Object 를 인자로 받거나 반환하면 코틀린에서는 `Any` 로 그 타입을 취급한다.  
(더 정확히는 null 이 될 수 있는지 여부를 알 수 없으므로 [플랫폼 타입](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#121-%ED%94%8C%EB%9E%AB%ED%8F%BC-%ED%83%80%EC%9E%85)인 `Any!` 로 취급함)

코틀린 함수가 `Any` 를 사용하면 자바 바이트코드의 Object 로 컴파일된다.

모든 코틀린 클래스에는 `toString()`, `equals()`, `hashCode()` 메서드를 포함하는데 이 3 개의 메서드는 `Any` 에 정의된 메서드를 상속한 것이다.

java.lang.Object 에 있는 다른 메서드 (`wati()`, `notify()`..) 는 `Any` 에서 사용할 수 없다.  
따라서 그런 메서드를 호출하고 싶다면 java.lang.Object 타입으로 값을 캐스트해야 한다.

미리 정해지지 않은 타입을 다루는 방법 중 하나로 `Any` 타입의 인자를 전달하는 방법이 있는데 이를 제네릭스를 사용하는 경우와 혼동하면 안된다.

**`Any` 를 사용하는 방법은 두 가지**가 있다.

- `Any` 에 대해서만 연산을 수행하고, 다른 어느 타입도 요구하지 않는 것 (이런 경우는 극히 제한적임)
  - `Any` 에는 멤버 함수가 `equals()`, `hashCode()`, `toString()` 세 가지 뿐임
  - 확장 함수도 있지만 이런 확장 함수는 `Any` 타입 객체에 대해 직접 연산을 적용할 수는 없음
    - 예) _Any.apply()_ 는 함수 인자를 `Any` 에 적용할 뿐이고, `Any` 타입 객체의 내부 연산을 직접 호출할 수는 없음
- `Any` 타입 객체의 실제 타입을 알 경우 타입을 변환하여 구체적인 타입에 다른 연산 수행
  - 이 과정에서 실행 시점에 타입 정보가 필요(= [다운캐스트](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#2-%EB%8B%A4%EC%9A%B4-%EC%BA%90%EC%8A%A4%ED%8A%B8-downcast-rtti-run-time-type-identification))하므로 타입 변환 시 잘못된 타입을 지정하면 런타임 오류 발생 (성능도 저하됨) 

아래는 의사 소통 기능을 제공하는 3가지 타입이 있으며, 이들은 서로 다른 라이브러리에 속해있어서 같은 클래스 계층 구조안에 그냥 넣을 수 없고, 의사 소통에 사용되는 
함수명도 모두 다른 경우에 대한 예시이다.

`Any` 를 잘못 사용 하는 예시
```kotlin
class Person {
    fun speak() = "Hi!"
}

class Dog {
    fun bark() = "Ruff!"
}

class Robot {
    fun comm() = "Beep!"
}

fun talk(speaker: Any) =
    when (speaker) {
        is Person -> speaker.speak()
        is Dog -> speaker.bark()
        is Robot -> speaker.comm()
        else -> "Not a talker!"
    }

fun main() {
    println(talk(Person())) // Hi!
    println(talk(Dog())) // Ruff!
    println(talk(Robot())) // Beep!
    println(talk(12)) // Not a talker!
}
```

만일 _talk()_ 가 앞으로 다른 타입의 값을 처리할 일이 없다면 괜찮겠지만 새로운 타입이 추가된다면 그 때마다 _talk()_ 함수를 변경해야 한다.

---

## 1.2. 제네릭스 정의: `<>`

**중복된 코드는 제네릭 함수나 타입으로 변환하는 것을 고려**해볼 만 하다.

`<>` 안에 제네릭 플레이스 홀더를 하나 이상 넣으면 제네릭 함수나 타입을 정의할 수 있다.

```kotlin
// 타입 파라메터로 T 를 받고, T 를 반환
fun <T> gFunction(arg: T): T = arg

// T 를 저장
class GClass<T>(val x: T) {
    // T 반환
    fun f(): T = x
}

// 클래스 안에서 멤버 함수를 파라메터화함
class GMemberFunction {
    fun <T> f(arg: T): T = arg
}

// interface 가 제네릭 파라메터를 받는 경우
// 이 인터페이스를 구현하는 클래스는 GImplementation 클래스처럼 타입 파라메터를 재정의하거나,
// ConcreteImplementation 클래스처럼 타입 파라메터에 구체적인 타입 인자를 제공해야 함
interface GInterface<T> {
    val x: T

    fun f(): T
}

class GImplementation<T>(override val x: T) : GInterface<T> {
    override fun f(): T = x
}

class ConcreteImplementation : GInterface<String> {
    override val x: String
        get() = "x~"

    override fun f() = "f()~"
}

fun basicGenerics() {
    gFunction("Red")
    gFunction(1)
    gFunction(Dog())
    gFunction(Dog()).bark()

    GClass("AAA").f()
    GClass(11).f()
    GClass(Dog()).f().bark()

    GMemberFunction().f("AAA")
    GMemberFunction().f(11)
    GMemberFunction().f(Dog()).bark()

    GImplementation("AA").f()
    GImplementation(11).f()
    GImplementation(Dog()).f().bark()

    ConcreteImplementation().f()
    ConcreteImplementation().x
}
```

---

### 1.2.1. 제네릭 함수와 프로퍼티

리스트를 다루는 함수 작성 시 특정 타입을 저장하는 리스트 뿐 아니라 모든 리스트 (= 제네릭 리스트) 를 다룰 수 있는 함수가 더 유용하다.  
이럴 때 제네릭 함수를 사용한다.

**제네릭 함수를 호출할 때는 반드시 구체적 타입으로 타입 인자**를 넘겨야 한다.

대부분의 컬렉션 라이브러리 함수는 제네릭 함수이다.  
아래는 `slice()` 의 시그니처이다.

```kotlin
public fun <T> List<T>.slice(indices: IntRange): List<T>
```

`slice()` 함수는 구체적인 범위 안에 든 원소만을 포함하는 새로운 리스트를 반환한다.

![제네릭 함수 `slice()` 는 `T` 를 타입 파라메터로 받음](/assets/img/dev/2024/0317/type.png)

위를 보면 수신 객체와 반환 타입은 모두 `List<T>` 로, 함수의 타입 파라메터 `T` 가 수신 객체와 반환 타입으로 사용되고 있다.

아래는 `filter()` 의 시그니처이다.

```kotlin
public inline fun <T> Iterable<T>.filter(predicate: (T) -> Boolean): List<T>
```

`filter()` 는 `(T) -> Boolean` 타입의 함수를 파라메터로 받는다.

아래는 제네릭 고차 함수를 호출하는 예시이다.

> 고차 함수에 관한 내용은 [1. 고차 함수 (high-order function)](https://assu10.github.io/dev/2024/02/17/kotlin-funtional-programming-2/#1-%EA%B3%A0%EC%B0%A8-%ED%95%A8%EC%88%98-high-order-function) 를 참고하세요.

```kotlin
package com.assu.study.kotlin2me.chap09

fun main() {
    val authors = listOf("Assu", "Silby")
    val readers = mutableListOf<String>()

    readers.add("Jaehoon")
    readers.add("Assu")

    val result = readers.filter { it !in authors }

    // [Jaehoon]
    println(result)
}
```

위에서 람다 파라메터에 대해 자동으로 만들어진 변수 `it` 의 타입은 `T` 라는 제네릭 타입이다.  
(여기서 `T` 는 함수 파라메터 타입인 `(T) -> Boolean` 에서 온 타입임)

---

제네릭 함수를 정의할 때와 마찬가지 방법으로 **제네릭 확장 프로퍼티**를 선언할 수 있다.

아래는 리스트의 마지막 원소 바로 앞에 있는 원소를 반환하는 확장 프로퍼티 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap09

// 제네릭 확장 프로퍼티
// 모든 리스트 타입에 이 제네릭 확장 프로퍼티 사용 가능
val <T> List<T>.pre: T
    get() = this[size - 2]

fun main() {
    // 제네릭 확장 프로퍼티 사용
    // 이 호출에서 타입 파라메터 T 는 int 로 추론됨
    println(listOf(1, 2, 3).pre)
}
```

확장이 아닌 일반 프로퍼티는 타입 파라메터를 가질 수 없다.  
즉, **확장 프로퍼티만 제네릭하게 만들 수 있다**는 의미이다.

클래스 프로퍼티에 여러 타입의 값을 저장할 수는 없으므로 제네릭한 일반 프로퍼티는 말이 되지 않는다.

확장 프로퍼티가 아닌 일반 프로퍼티를 제네릭하게 선언하면 아래와 같은 오류가 발생한다.

```kotlin
// 컴파일 오류
// Type parameter of a property must be used in its receiver type

// 확장 프로퍼티가 아닌 일반 프로터티는 제네릭하게 만들 수 없음

//val <T> x: T = TODO()
```

---

### 1.2.2. 제네릭 클래스 선언

타입 파라메터를 넣은 꺽쇠 기호 `<>` 를 클래스 혹은 인터페이스 이름 뒤에 붙이면 클래스나 인터페이스를 제네릭하게 만들 수 있다.

타입 파라메터를 이름 뒤에 붙이고 나면 클래스 본문 안에서 타입 파라메터를 다른 일반 타입처럼 사용 가능하다.

**제네릭 클래스를 확장하는 클래스 혹은 제네릭 인터페이스를 구현하는 클래스를 정의하려면 기반 타입의 제네릭 파라메터에 대해 타입 인자를 지정**해야 한다.  
이 때 구체적인 타입을 넘길수도 있고, 만일 하위 클래스도 제네릭 클래스라면 타입 파라메터로 받은 타입을 넘길수도 있다.

제네릭 인터페이스를 구현하는 예시

```kotlin
package com.assu.study.kotlin2me.chap09

interface List<T> {
    operator fun get(index: Int): T
}

// List<T> 인터페이스를 구현하는 클래스
// 구체적인 타입 인자로 String 을 지정하여 List 인터페이스 구현
class StringList: List<String> {
    override fun get(index: Int): String {
        TODO("Not yet implemented")
    }
}

// ArrayList 의 제네릭 타입 파라메터 T 를 List 의 타입 인자로 넘김
class ArrayList<T>: List<T> {
    override fun get(index: Int): T {
        TODO("Not yet implemented")
    }
}
```

---

클래스가 자기 자신을 타입 인자로 참조할 수도 있다.

`Comparable` 인터페이스를 구현하는 클래스가 이런 패턴의 예이다.  
비교 가능한 모든 값은 자신을 같은 타입의 다른 값과 비교하는 방법을 제공한다.

```kotlin
interface Comparable<T> {
    fun compareTo(other: T): Int
}

class String1 : Comparable<String1> {
    override fun compareTo(other: String1): Int {
        TODO("Not yet implemented")
    }
}
```

위에서 _String1_ 클래스는 제네릭 Comparable 인터페이스를 구현하면서 그 인터페이스의 타입 파라메터 `T` 로 _String1_ 자신을 지정한다.

---

## 1.3. 타입 정보 보존

[1.6. 타입 소거 (type erasure)](#16-타입-소거-type-erasure) 에 나오는 내용이지만, **제네릭 클래스나 제네릭 함수의 내부 코드는 T 타입에 대해 알 수 없다.**  
이를 **타입 소거**라고 한다.

**제네릭스는 반환값의 타입 정보를 유지하는 방법으로 반환값이 원하는 타입인지 명시적으로 검사하고 변환할 필요가 없다.**

예를 들어 아래와 같은 코드는 _Car_ 타입에 대해서만 동작한다.

```kotlin
class Car {
    override fun toString() = "Car~"
}

class CarCrate(private var c: Car) {
    override fun toString() = "CarCrate~"

    fun put(car: Car) {
        c = car
    }

    // Car 의 타입만 반환할 수 있음
    fun get(): Car = c
}

fun main() {
    val cc = CarCrate(Car())
    val car: Car = cc.get()

    println(cc) // CarCrate~
    println(car) // Car~
}
```

> 클래스로 파라메터를 받는 클래스에 대한 좀 더 상세한 내용은 [5.1. 하나의 타입 파라메터를 받는 클래스](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#51-%ED%95%98%EB%82%98%EC%9D%98-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A5%BC-%EB%B0%9B%EB%8A%94-%ED%81%B4%EB%9E%98%EC%8A%A4) 를 참고하세요.

위 클래스를 _Car_ 뿐 아니라 다른 타입에 대해서도 활용하려면 _CarCrate_ 클래스를 \<T\> 로 일반화하면 된다.

```kotlin
class Car1 {
    override fun toString() = "Car1~"
}

open class Crate<T>(private var contents: T) {
    fun put(item: T) {
        contents = item
    }

    // T 타입의 값이 결과로 나옴
    fun get(): T = contents
}

fun main() {
    val cc = Crate(Car1())
    val car: Car1 = cc.get()

    println(cc::class.simpleName) // Crate
    println(car) // Car1~
}
```

> 제네릭 클래스에 대한 좀 더 상세한 내용은 [5.2. 제네릭 타입 파라메터를 받는 클래스: `<T>`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#52-%EC%A0%9C%EB%84%A4%EB%A6%AD-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A5%BC-%EB%B0%9B%EB%8A%94-%ED%81%B4%EB%9E%98%EC%8A%A4-t) 를 참고하세요.

---

## 1.4. 제네릭 확장 함수

> 확장 함수에 대한 좀 더 상세한 내용은  
> [1. 확장 함수 (extension function)](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#1-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-extension-function),  
> [4. 확장 함수와 null 이 될 수 있는 타입](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#4-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98%EC%99%80-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%ED%83%80%EC%9E%85),  
> [5. 상속과 확장](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#5-%EC%83%81%EC%86%8D%EA%B3%BC-%ED%99%95%EC%9E%A5) 을 참고하세요.

이제 제네릭 확장 함수로 _Crate_ 에 사용할 수 있는 `map()` 을 정의할 수 있다.

```kotlin
class Car2 {
  override fun toString() = "Car2~"
}

open class Crate2<T>(private var contents: T) {
  fun put(item: T) {
    contents = item
  }

  // T 타입의 값이 결과로 나옴
  fun get(): T = contents
}

// 제네릭 확장 함수
// f() 를 입력 시퀀스의 모든 원소에 적용하여 얻은 값으로 이루어진 List 반환
fun <T, R> Crate2<T>.map2(f: (T) -> (R)): List<R> = listOf(f(get()))

fun main() {
  val result = Crate2(Car2()).map2 { it.toString() + "x" }

  println(result) // [Car2~x]
}
```

---

## 1.5. 타입 파라메터 제약: `filterIsInstance()`

**타입 파라메터 제약은 클래스나 함수에 사용할 수 있는 타입 인자를 제한**하는 기능이다.

**타입 파라메터 제약은 제네릭 타입 인자가 다른 클래스를 상속해야 한다고 지정**한다.

예를 들어 \<T: Base\> 는 T 가 Base 타입이거나, Base 에서 파생된 타입이어야 한다는 의미이다.

어떤 타입을 제네릭 타입의 타입 파라메터에 대한 상한으로 지정하면 그 제네릭 타입을 인스턴스화할 때 사용하는 타입 인자는 반드시 그 상한 타입이거나 그 상한 타입의 
하위 타입이어야 한다.

> 하위 타입과 하위 클래스에 대한 차이는 추후 다룰 예정입니다. (p. 390)

**타입 파라메터 제약으로 Base 를 지정하는 경우**와 **Base 를 상속하는 제네릭하지 않은 타입(= 일반 타입) 의 차이**에 대해 알아보자.

아래는 위 차이에 대해 사용할 타입 계층이다.

```kotlin
interface Disposable {
    val name: String

    fun action(): String
}

class Compost(override val name: String) : Disposable {
    override fun action() = "add to compost~"
}

interface Transport : Disposable

class Donation(override val name: String) : Transport {
    override fun action() = "add to donation~"
}

class Recyclable(override val name: String) : Transport {
    override fun action() = "add to recyclable~"
}

class Landfill(override val name: String) : Transport {
    override fun action() = "add to landfill~"
}

val items =
    listOf(
        Compost("AAA"),
        Compost("BBB"),
        Donation("CCC"),
        Donation("DDD"),
        Recyclable("EEE"),
        Recyclable("FFF"),
        Landfill("GGG"),
    )

val recyclables = items.filterIsInstance<Recyclable>()
```

> 위 코드에서 _recyclables_ 는 `reified` 키워드를 사용하여 좀 더 범용적으로 사용할 수 있음  
> 이에 대한 내용은 [1.7.1. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용](#171-reified-를-사용하여-is-를-제네릭-파라메터에-적용) 을 참고하세요.

---

### 1.5.1. 제네릭 타입 파라메터

제네릭스를 사용하면 타입 파라메터를 받는 타입을 정의할 수 있다.  
제네릭 타입의 인스턴스를 만들려면 타입 파라메터를 구체적인 타입 인자로 치환해야 한다.

예를 들어 `Map` 클래스는 key 타입과 value 타입을 타입 파라메터로 받으므로 `Map<K,V>` 가 된다.  
이런 제네릭 클래스에 `Map<String, Person>` 처럼 구체적인 타입을 인자로 넘기면 타입을 인스턴스화할 수 있다.

코틀린 컴파일러는 보통 타입과 마차가지로 타입 인자도 추론할 수 있다.

```kotlin
val strings = listOf("a", "bb")
```

`listOf()` 에 전달된 두 값이 문자열이므로 컴파일러는 이 리스트가 `List<String>` 임을 추론한다.

반면 빈 리스트를 만들어야 한다면 타입 인자를 추론할 근거가 없으므로 직접 타입 인자를 명시해야 한다.

```kotlin
val strings: MutableList<String> = mutableListOf()

val strings = mutableListOf<String>()
```

---

### 1.5.2. 타입 파라메터 제약으로 지정

제약을 가하려면 타입 파라메터 이름 뒤에 콜론 `:` 을 붙이고 그 뒤에 상한 타입을 명시하면 된다.

```kotlin
fun <T : Number> List<T>.sum(): T
```

위 코드의 `<T: Number>` 에서 `T` 는 타입 파라메터이고, `Number` 는 상한 타입이다.

타입 파라메터 `T` 에 대한 상한을 정하고 나면 `T` 타입의 값을 그 상한 타입의 값으로 취급할 수 있다.

상한 타입으로 정의된 Number 의 메서드를 `T` 타입의 값에 대해 호출하는 예시

```kotlin
package com.assu.study.kotlin2me.chap09

// Number 를 타입 파라메터 상한으로 정함
fun <T : Number> oneHalf(value: T): Double {
    // Number 클래스에 정의된 메서드 호출
    return value.toDouble() / 2.0
}

fun main() {
    println(oneHalf(3)) // 1.5
}
```

아래는 두 파라메터 사이에서 더 큰 값을 찾는 제네릭 함수이다.  
서로 비교할 수 있어야 최대값을 찾을 수 있으므로 함수 시그니처에도 두 인자를 서로 비교할 수 있어야 한다는 사실을 지정해야 하는데 그런 내용을 지정하는 방법에 대해 
보여준다.

```kotlin
package com.assu.study.kotlin2me.chap09

import kotlin.Comparable

// 이 함수의 인자들은 비교가 가능해야 함
fun <T : Comparable<T>> max(
    first: T,
    second: T,
): T =
    if (first > second) {
        first
    } else {
        second
    }

fun main() {
    // bb
    println(max("aa", "bb")) //  문자열은 알파벳 순으로 비교

    // 22
    println(max("22", "11"))

    // 서로 비교할 수 없는 값이므로 컴파일 오류

    // println(max("bb", 1))
}
```

위 코드에서 `T` 의 상한 타입은 `Comparable<T>` 이다.  
String 이 `Comparable<String>` 을 확장하므로 String 은 _max()_ 함수에 적합한 타입 인자이다.

_first > second_ 은 코틀린 연산자 관례에 따라 아래처럼 컴파일된다.

```kotlin
first.compareTo(second) > 0
```

> 비교 연산자 관례에 대한 내용은 [2.3. `Comparable` 인터페이스 구현 후 `compareTo()` 오버라이드: `compareValuesBy()`](https://assu10.github.io/dev/2024/03/23/kotlin-advanced-3/#23-comparable-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4-%EA%B5%AC%ED%98%84-%ED%9B%84-compareto-%EC%98%A4%EB%B2%84%EB%9D%BC%EC%9D%B4%EB%93%9C-comparevaluesby) 를 참고하세요.

**타입 파라메터 제약을 사용하면 제네릭 함수 안에서 제약이 이뤄진 타입의 프로퍼티와 함수에 접근이 가능**하다.    
만일 제약을 사용하지 않으면 _name_ 을 사용할 수 없다.

```kotlin
// 타입 파라메터 제약 사용
// 타입 파라메터 제약을 사용하지 않으면 name 에 접근 불가
fun <T : Disposable> nameOf(disposable: T) = disposable.name

// 타입 파라메터 제약을 사용한 확장 함수
// 타입 파라메터 제약을 사용하지 않으면 name 에 접근 불가
fun <T : Disposable> T.customName() = name

fun main() {
    val result1 = recyclables.map { nameOf(it) }
    val result2 = recyclables.map { it.customName() }

    println(result1) // [EEE, FFF]
    println(result2) // [EEE, FFF]
}
```

---

#### 1.5.2.1. 타입 파라메터에 둘 이상의 제약 지정: `where`

드물지만 타입 파라메터에 둘 이상의 제약을 가해야 하는 경우도 있다.

아래는 `CharSequence` 의 맨 끝에 마침표 `.` 가 있는지 검사하는 제네릭 함수이다.

```kotlin
package com.assu.study.kotlin2me.chap09

fun <T> ensureTrailingPeriod(seq: T)
        where T : CharSequence, T : Appendable { // 타입 파라메터 제약 목록
    if (!seq.endsWith('.')) {   // CharSequence 인터페이스의 확장 함수 호출
        seq.append('.') // Appendable 인터페이스의 메서드 호출
    }
}

fun main() {
    val hello = StringBuilder("Hello world")
    ensureTrailingPeriod(hello)

    // Hello world.
    println(hello)
}
```

위 코드는 타입 인자가 `CharSequence` 와 `Appendable` 인터페이스를 반드시 구현해야 한다는 사실을 표현한다.

이는 데이터에 접근하는 연산인 `endsWith()` 와 데이터를 변환하는 연산인 `append()` 를 `T` 타입의 값에게 수행할 수 있다는 의미이다.

---

### 1.5.3. 제네릭하지 않은 타입으로 지정

[1.5.2. 타입 파라메터 제약으로 지정](#152-타입-파라메터-제약으로-지정) 의 코드를 아래와 같이 하면 제네릭스를 사용하지 않고도 같은 결과를 낼 수 있다.

```kotlin
// 타입 파라메터 제약을 사용하지 않음
fun nameOf2(disposable: Disposable) = disposable.name

// 티입 파라메터 제약을 사용하지 않은 확장 함수
fun Disposable.customName2() = name

fun main() {
    val result1 = recyclables.map { nameOf2(it) }
    val result2 = recyclables.map { it.customName2() }

    println(result1) // [EEE, FFF]
    println(result2) // [EEE, FFF]
}
```

---

### 1.5.4. 다형성 대신 타입 파라메터 제약을 사용하는 이유

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

[1.5.2. 타입 파라메터 제약으로 지정](#152-타입-파라메터-제약으로-지정) 과 [1.5.3. 제네릭하지 않은 타입으로 지정](#153-제네릭하지-않은-타입으로-지정) 는 같은 결과를 반환한다.

**다형성 대신 타입 파라메터 제약을 사용하는 이유는 반환 타입 때문**이다.

다형성을 사용하는 경우엔 반환 타입을 기반 타입으로 업캐스트하여 반환해야 하지만, 제네릭스를 사용하면 정확한 타입을 지정할 수 있다.

```kotlin
import kotlin.random.Random

private val rand = Random(47)

// 타입 파라메터 제약을 사용하지 않은 확장 함수
fun List<Disposable>.nonGenericConstrainedRandom(): Disposable = this[rand.nextInt(size)]

// 타입 파라메터 제약을 사용한 확장 함수
fun <T : Disposable> List<T>.genericConstrainedRandom(): T = this[rand.nextInt(size)]

// 제네릭 확장 함수
fun <T> List<T>.genericRandom(): T = this[rand.nextInt(size)]

fun main() {
  val result1: Disposable = recyclables.nonGenericConstrainedRandom()
  val result2: Disposable = recyclables.genericConstrainedRandom()
  val result3: Disposable = recyclables.genericRandom()

  // 컴파일 오류
  // 기반 클래스인 Disposable 타입만 가능
  // 다형성인 경우 반환 타입을 기반 타입으로 업캐스트해야함
  
  // val result4: Recyclable = recyclables.nonGenericConstrainedRandom()
  
  val result5: Recyclable = recyclables.genericConstrainedRandom()
  val result6: Recyclable = recyclables.genericRandom()

  println(result1.action()) // add to recyclable~
  println(result2.action()) // add to recyclable~
  println(result3.action()) // add to recyclable~

  println(result5.action()) // add to recyclable~
  println(result6.action()) // add to recyclable~
}
```

위 코드에서 제네릭스를 사용하지 않은 _nonGenericConstrainedRandom()_ 는 기반 클래스인 _Disposable_ 만 만들어낼 수 있다.  
제네릭을 사용한 _genericConstrainedRandom()_, _genericRandom()_ 는 파생 클래스인 _Recyclable_ 도 만들 수 있다.

_genericConstrainedRandom()_ 는 _Disposable_ 의 멤버를 전혀 사용하지 않으므로 T에 걸린 _:Disposable_ 타입 파라메터 제약이 의미가 없어서 결국 
타입 파라메터 제약을 걸지 않은 _genericRandom()_ 과 동일하다. (= 타입 파라메터 제약을 사용할 필요없이 일반 제네릭으로 사용해도 되는 케이스)

---

### 1.5.5. 타입 파라메터를 사용해야 하는 경우

**타입 파라메터를 사용해야 하는 경우는 아래 2가지가 모두 필요할 때 뿐**이다.

- 타입 파라메터 안에 선언된 함수나 프로퍼티에 접근해야 하는 경우
- 결과를 반환할 때 타입을 유지해야 하는 경우

```kotlin
import kotlin.random.Random

private val rand = Random(47)

// 타입 파라메터 제약을 사용하지 않은 확장 함수
// action() 에 접근할 수는 있지만 정확한 타입 반환 불가 (result4 참고)
fun List<Disposable>.nonGenericConstrainedRandom2(): Disposable {
    val d: Disposable = this[rand.nextInt(this.size)]
    d.action()
    return d
}

// 제네릭 확장 함수
// 타입 파라메터 제약이 없어서 action() 에 접근 불가
fun <T> List<T>.genericRandom2(): T {
    val d: T = this[rand.nextInt(this.size)]
    // action() 에 접근 불가
    // d.action()
    return d
}

// 타입 파라메터 제약을 사용한 확장 함수
// action() 에 접근하고, 정확한 타입 반환 가능
fun <T : Disposable> List<T>.genericConstrainedRandom2(): T {
    val d: T = this[rand.nextInt(this.size)]
    d.action()
    return d
}

fun main() {
    val result1: Disposable = recyclables.nonGenericConstrainedRandom2()
    val result2: Disposable = recyclables.genericRandom2()
    val result3: Disposable = recyclables.genericConstrainedRandom2()

    // 컴파일 오류
    // 기반 클래스인 Disposable 타입만 가능
    // 다형성인 경우 반환 타입을 기반 타입으로 업캐스트해야함
  
    // val result4: Recyclable = recyclables.nonGenericConstrainedRandom2()
  
    val result5: Recyclable = recyclables.genericRandom2()
    val result6: Recyclable = recyclables.genericConstrainedRandom2()

    println(result1.action()) // add to recyclable~
    println(result2.action()) // add to recyclable~
    println(result3.action()) // add to recyclable~
  
    println(result5.action()) // add to recyclable~
    println(result6.action()) // add to recyclable~
}
```

**타입 파라메터 제약을 사용하지 않은 확장 함수**인 _nonGenericConstrainedRandom2()_ 는 _List\<Disposable\>_ 의 확장 함수이기 때문에 
**함수 내부에서 _action()_ 에 접근할 수는 있지만**, 제네릭 함수가 아니므로 _result4: Recyclable_ 가 오류가 나는 것처럼 **기반 타입인 _Disposable_ 로만 값을 반환**할 수 있다.

**제네릭 함수**인 _genericRandom2()_ 는 **T 타입을 반환할 수는 있지만** 타입 파라메터 제약이 없기 때문에 **_Disposable_ 에 정의된 _action()_ 에 접근할 수 없다.**

**타입 파라메터 제약을 사용한 확장 함수**인 _genericConstrainedRandom2()_ 는 **_Disposable_ 에 정의된 _action()_ 에 접근**하면서 _result5_, _result6_ 과 같이 **정확한 
타입을 반환**할 수 있다.

> 타입 파라메터를 null 이 될 수 없는 타입으로 한정하는 부분에 대해서는 [5.2.2. 타입 파라메터를 null 이 될 수 없는 타입으로 한정](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#522-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A5%BC-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%97%86%EB%8A%94-%ED%83%80%EC%9E%85%EC%9C%BC%EB%A1%9C-%ED%95%9C%EC%A0%95) 을 참고하세요.

---

## 1.6. 타입 소거 (type erasure)

최초 자바는 제네릭이 없다가 제네릭스를 도입하면서 기존 코드와 호환될 수 있어야 했기 때문에 **제네릭 타입은 컴파일 시점에만 사용**할 수 있고, 
런타임 바이트코드에는 제네릭 타입 정보가 보존되지 않는다. (=제네릭 클래스나 제네릭 함수의 내부 코드는 T 타입에 대해 알 수 없음)  
즉, **제네릭 타입의 파라메터 타입 정보가 런타임에는 지워져 버린다.**

이것을 **타입 소거** 라고 한다.

아래 코드를 보자.

```kotlin
fun useList(list: List<Any>) {
  // 아래와 같은 오류
  // Cannot check for instance of erased type: List<String>
  // 소거된 타입인 List<String> 의 인스턴스를 검사할 수 없다는 의미
  // 타입 소거 때문에 실행 시점에 제네릭 타입의 타입 파라메터 타입을 검사할 수 없음
    
  // if (list is List<String>) {}
}

fun main() {
    val strings = listOf('a', 'b', 'c')
    val all: List<Any> = listOf(1, 2, 'd')
}
```

아래 오류는 소거된 타입 List\<String\> 의 인스턴스를 검사할 수 없다는 의미로 타입 소거 때문에 실행 시점에 제네릭 타입의 타입 파라메터 타입을 검사할 수 없다는 의미이다.

```shell
Cannot check for instance of erased type: List<String>
```

만일 타입 소거가 되지 않는다면 실제로는 이렇게 동작하지 않지만 리스트 맨 뒤에 타입 정보가 추가될 수도 있다.  
타입 소거가 된다면 타입 정보는 리스트 안에 저장되지 않고 그냥 아무 타입 정보도 없는 List 일 뿐이다.

![타입 소거된 제네릭스](/assets/img/dev/2024/0317/generics.png)

실행 시점에는 리스트의 모든 원소를 검사하기 전에 List 의 원소 타입을 예상할 수 없으므로 위 그림에서 두 번째 리스트에서 첫 번째 원소만 검사한다면 이 리스트의 타입이 List\<Int\> 라고 
잘못된 결론을 내릴 수도 있다.

<**코틀린에서 타입 소거를 사용하는 이유**>  
- 자바와의 호환성 유지
- 타입 정보를 유지하려면 부가 비용이 많이 듦
  - 제네릭 타입 정보를 저장하면 제네릭 List 나 Map 이 차지하는 메모리가 매우 늘어남
  - 제네릭 객체가 모든 곳에서 타입 파라메터를 실체화하여 저장한다면 제네릭 객체인 Map.Entry 객체로 이루어진 Map 의 경우 Map.Entry 의 모든 키와 값이 부가 타입 정보를 저장해야 함

---

### 1.6.1. 실행 시점의 제네릭: 타입 검사와 캐스트

자바와 마찬가지로 코틀린 제네릭 타입 인자 정보는 런타임에는 지워진다.  
예) `List<String>` 객체를 만들고 그 안에 문자열을 넣더라도 실행 시점에는 그 객체를 오직 `List` 로만 볼 수 있음  
그 `List` 객체가 어떤 타입의 원소를 저장하는지 실행 시점에는 알 수 없음

```kotlin
val list1: List<String> = listOf("a", "b")
val list2: List<Int> = listOf(1, 2)
```

컴파일러는 _list1_ 과 _list2_ 를 서로 다른 타입으로 인식하지만 실행 시점에 _list1_ 과 _list2_ 는 단지 단지 `List` 일 뿐 문자열이나 정수의 리스트로 
선언되었다는 사실은 알 수 없다.  
(= 즉, 실행 시점에 _list1_ 과 _list2_ 는 완전히 같은 타입의 객체임)

제네릭은 타입 인자를 따로 저장하지 않기 때문에 (= 타입 소거) 실행 시점에 타입 인자를 검사할 수 없다.  
예) 특정 리스트가 문자열로 이루어진 리스트인지 다른 객체로 이루어진 객체인지 실행 시점에 검사 불가

실행 시점에 어떤 값이 `List` 인지 여부는 알아낼 수 있지만 그 리스트의 원소 타입은 알 수가 없다.

하지만 타입 소거로 인해 저장해야 하는 타입 정보의 크기가 줄어들어서 전반적으로 메모리 사용량이 줄어든다는 장점이 있다.

---

코틀린에서는 타입 인자를 명시하지 않고 제네릭 타입을 사용할 수 없다.  
그렇다면 어떤 값이 `Set` 이나 `Map` 이 아닌 `List` 라는 사실을 어떻게 확인할 수 있을까?

답은 바로 **스타 프로젝션**을 사용하면 된다.

```kotlin
if (value is List<*>) {
  // ...
}
```

스타 프로젝션은 자바의 `List<?>` 와 비슷하게 인자를 알 수 없는 제네릭 타입을 표현할 때 사용한다.  
위 코드에서 _value_ 가 `List` 임을 알 수는 있지만 그 원소 타입은 알 수 없다.

> 스타 프로젝션에 대한 좀 더 상세한 내용은 [6.3. 스타 프로젝션(star projection): `*`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#63-%EC%8A%A4%ED%83%80-%ED%94%84%EB%A1%9C%EC%A0%9D%EC%85%98star-projection-) 을 참고하세요.

---

[안전하지 않은 캐스트 `as`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#231-%EC%95%88%EC%A0%84%ED%95%98%EC%A7%80-%EC%95%8A%EC%9D%80-%EC%BA%90%EC%8A%A4%ED%8A%B8-as) 와 [안전한 캐스트 `as?`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#232-%EC%95%88%EC%A0%84%ED%95%9C-%EC%BA%90%EC%8A%A4%ED%8A%B8-as) 에도 여전히 제네릭 타입을 사용할 수 있다.

하지만 기반 클래스는 같지만 타입 인자가 다른 타입으로 캐스팅해도 여전히 캐스팅에 성공한다는 점을 유의해야 한다.  
실행 시점에는 제네릭 타입의 타입 인자를 알 수 없으므로 캐스팅은 항상 성공한다.

이런 타입 캐스팅을 사용하면 컴파일러는 `unchecked cast (검사할 수 없는 캐스팅)` 경고를 준다.

```kotlin
package com.assu.study.kotlin2me.chap09

// 제네릭 타입으로 타입 캐스팅
fun printSum(c: Collection<*>) {
    // Unchecked cast: Collection<*> to List<Int> 경고뜸
    // 컴파일은 됨, 즉 캐스팅은 됨
    val intList = c as? List<Int> ?: throw IllegalArgumentException("List is expected")
    
    // 컴파일 오류
    // sum() 이 호출되지 않음
    println(intList.sum())
}

fun main() {
    printSum(listOf(1, 2))
}
```

아래는 알려진 타입 인자를 사용하여 [스마트 캐스트 `is`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#21-%EC%8A%A4%EB%A7%88%ED%8A%B8-%EC%BA%90%EC%8A%A4%ED%8A%B8-is) 를 이용하여 
타입 검사를 하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap09

// 알려진 타입 인자를 사용하여 타입 검사
fun printSum(c: Collection<Int>) {
    // 컴파일 오류
    // Cannot check for instance of erased type: List<Int>

//    if (c is List<Int>) {
//        println(c.sum())
//    }

    if (c is List<*>) {
        println("111")
        println(c.sum())
    } else {
        println("222")
    }
}

fun main() {
    printSum(listOf(1, 2)) // 222
}
```

---

## 1.7. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`

코틀린은 제네릭 함수의 본문에서 그 함수의 타입 인자를 가리킬 수 없지만, `inline` 함수 안에서는 타입 인자를 사용할 수 있다.

코틀린 제네릭 타입의 타입 인자 정보는 실행 시점에 지워지기 때문에 제네릭 클래스의 인스턴스가 있어도 그 인스턴스를 만들 때 사용한 타입 인자를 알아낼 수 없다.  
제네릭 함수의 타입 인자도 마찬가지이다.  
제네릭 함수가 호출되어도 그 함수의 본문에서는 호출 시 사용된 타입 인자를 알 수 없다.

```kotlin
package com.assu.study.kotlin2me.chap09

// 컴파일 오류
// Cannot check for instance of erased type: T
fun <T> isA(value: Any) = value is T
```

**제네릭 함수를 호출할 때도 타입 정보가 소거**되기 때문에 함수 안에서는 제네릭 타입 파라메터를 사용해서 할 수 있는 일이 별로 없다.

**함수 인자의 타입 정보를 보존하려면 `reified` 키워드를 추가**하면 된다.

아래는 `reified` 키워드를 추가하지 않은 상태로 제네릭 함수에서 제네릭 함수를 호출하는 예시이다.

```kotlin
// 코를린 클래스를 표현하는 클래스
import kotlin.reflect.KClass

// 제네릭 함수
fun <T: Any> a(kClass: KClass<T>): T {
    // KClass<T>를 사용함
    return kClass.createInstance()
}

// 제네릭 함수 b() 에서 a() 호출 시 제네릭 인자의 타입 정보를 전달하려고 시도
// 하지만 타입 소거로 인해 컴파일되지 않음
// 아래와 같은 오류
// Cannot use 'T' as reified type parameter. Use a class instead.

//fun <T:Any> b() = a(T::class)
```

제네릭 함수 _b()_ 에서 제네릭 함수 _a()_ 를 호출할 때 제네릭 인자의 타입 정보도 전달하려고 하지만 타입 소거로 인해 컴파일이 되지 않는다.

```shell
Cannot use 'T' as reified type parameter. Use a class instead.
```

**타입 정보 T 가 소거되기 때문에 _b()_ 가 컴파일되지 않는 것**이다.  
즉, 함수 본문에서 함수의 제네릭 타입 파라메터의 클래스를 사용할 수 없다.

아래와 같이 타입 정보를 전달하여 해결할 수는 있다.

```kotlin
// 제네릭 함수
fun <T: Any> a1(kClass: KClass<T>): T {
    // KClass<T>를 사용함
    return kClass.createInstance()
}

fun <T: Any> c1(kClass: KClass<T>) = a1(kClass)

class A

// 명시적으로 타입 정보 전달
val kc = c1(A::class)
```

하지만 컴파일러가 이미 T 의 타입을 알고 있는데 이렇게 명시적으로 타입 정보를 전달하는 것은 불필요한 중복이다.  
이를 해결해주는 것이 `reified` 키워드이다.

**`reified` 는 제네릭 함수를 `inline` 으로 선언**해야 한다.

`KClass<T>` 와 `reified` 를 각각 사용한 예시

```kotlin
import kotlin.reflect.KClass
import kotlin.reflect.full.createInstance

// 제네릭 함수
fun <T : Any> a2(kClass: KClass<T>): T {
    // KClass<T>를 사용함
    return kClass.createInstance()
}

// reified 키워드 사용
// 클래스 참조를 인자로 요구하지 않음
inline fun <reified T: Any> d() = a2(T::class)

class A1

val kd = d<A1>()
```

**`reified` 는 `reified` 가 붙은 타입 인자의 타입 정보를 유지시키라고 컴파일러에 명령**한다.  
따라서 **이제 실행 시점에도 타입 정보를 사용할 수 있기 때문에 함수 본문안에서 함수의 제네릭 타입 파라메터의 클래스를 사용**할 수 있다.

---

### 1.7.1. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용

> `is` 키워드에 대한 좀 더 상세한 내용은 [2.1. 스마트 캐스트: `is`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#21-%EC%8A%A4%EB%A7%88%ED%8A%B8-%EC%BA%90%EC%8A%A4%ED%8A%B8-is) 를 참고하세요.

인라인 함수의 타입 파라메터는 실체화되므로 실행 시점에 인라인 함수의 타입 인자를 알 수 있다.

인라인 함수에 대해 간단히 설명하면 어떤 함수에 `inline` 키워드를 붙이면 컴파일러는 그 함수를 호출한 식을 모두 함수 본문으로 바꾼다.  
함수가 람다를 인자로 사용하는 경우 그 함수를 인라인 함수로 만들면 람다 코드도 함께 인라이닝되고, 그에 따라 무명 클래스 (익명 클래스, Anonymous Class) 와 객체가
생성되지 않아서 성능이 더 좋아질 수 있다.

> `inline` 에 대한 좀 더 상세한 내용은 [Kotlin - 'inline'](https://assu10.github.io/dev/2024/03/16/kotlin-inline/) 를 참고하세요.

이제 인라인 함수가 유용한 다른 이유인 타입 인자 실체화에 대해 알아본다.

[1.7. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`](#17-함수의-타입-인자에-대한-실체화-reified-kclass) 에 나왔던 코드를 보자.

```kotlin
package com.assu.study.kotlin2me.chap09

// 컴파일 오류
// Cannot check for instance of erased type: T
fun <T> isA(value: Any) = value is T
```

위 코드에서 _isA()_ 함수를 인라인 함수로 만들고 타입 파라메터를 `reified` 로 지정하면 _value_ 의 타입이 `T` 의 인스턴스인지 실행 시점에 검사할 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap09

// inline 과 reified 사용
inline fun <reified T> isB(value: Any) = value is T

fun main() {
    println(isB<String>("ab")) // true
    println(isB<String>(123)) // false
}
```

```kotlin
// 타입 정보를 유지하여 어떤 객체가 특정 타입인지 검사 가능
inline fun <reified T> check(t: Any) = t is T

// 컴파일 오류
// reified 가 없으면 타입 정보가 소거되기 때문에 실행 시점에 어떤 객체가 T 의 인스턴스인지 검사 불가
// Cannot check for instance of erased type: T

// fun <T> check2(t: Any) = t is T

fun main() {
    val result1 = check<String>("1")
    val result2 = check<String>(1)

    println(result1) // true
    println(result2) // false
}
```

---

### 1.7.2. 실체화한 타입 파라메터 활용: `filterIsInstance()`

> [1.5. 타입 파라메터 제약: `filterIsInstance()`](#15-타입-파라메터-제약-filterisinstance) 에서 사용한 타입 계층 코드와 함께 보세요.

실체화한 타입 파라메터를 사용하는 간단한 예시 중 하나는 표준 라이브러리 함수인 `filterIsInstance()` 이다.  
`filterIsInstance()` 는 인자로 받은 컬렉션의 원소 중에서 타입 인자로 지정한 클래스의 인스턴스만을 모아서 만든 리스트를 반환한다.

```kotlin
package com.assu.study.kotlin2me.chap09

fun main() {
    val items = listOf("one", 2, "three")

    // [one, three]
    println(items.filterIsInstance<String>())
}
```

`filterIsInstance()` 의 타입 인자로 `String` 을 지정함으로써 문자열만 필요하다는 사실을 기술하였다.  
따라서 위 함수의 반환 타입은 `List<String>` 이다.  
여기서는 타입 인자를 실행 시점에 알 수 있고, `filterIsInstance()` 는 그 타입 인자를 사용하여 리스트의 원소 중 타입 인자와 타입이 일치하는 원소만을 추려낸다.

아래는 `filterIsInstance()` 의 시그니처이다.

```kotlin
public inline fun <reified R> Iterable<*>.filterIsInstance(): List<@kotlin.internal.NoInfer R> {
    return filterIsInstanceTo(ArrayList<R>())
}
```

`filterIsInstance()` 가 `inline` 과 reified` 키워드를 사용하여 정의되어 있는 것을 알 수 있다.

아래는 특정 하위 타입 _Disposable_ 원소의 name 을 반환하는 예시이다.

```kotlin
inline fun <reified T : Disposable> select() = items.filterIsInstance<T>().map { it.name }

fun main() {
    val result1 = select<Compost>()
    val result2 = select<Donation>()

    println(result1) // [AAA, BBB]
    println(result2) // [CCC, DDD]
}
```

인라인 함수에는 실체화한 타입 파라메터가 여러 개 있거나, 실체화한 타입 파라메터와 실체화하지 않은 타입 파라메터가 함께 있을수도 있다.

[1.4. 함수를 `inline` 으로 선언해야 하는 경우](https://assu10.github.io/dev/2024/03/16/kotlin-inline/#14-%ED%95%A8%EC%88%98%EB%A5%BC-inline-%EC%9C%BC%EB%A1%9C-%EC%84%A0%EC%96%B8%ED%95%B4%EC%95%BC-%ED%95%98%EB%8A%94-%EA%B2%BD%EC%9A%B0) 에서 
함수의 파라메터 중 함수 타입인 파라메터가 있고 그 파라메터에 해당하는 인자(람다)를 함께 인라이닝함으로써 얻는 이익이 더 큰 경우에만 함수를 인라인 함수로 만들라고 하였다.

하지만 **이 경우 함수를 인라인 함수로 만드는 이유는 성능 향상이 아닌 실체화한 타입 파라메터를 사용하기 위함**이다.

성능을 좋게 하려면 인라인 함수의 크기를 계속 관찰하여 함수가 커지면 실체화한 타입에 의존하지 않는 부분을 별도의 일반 함수로 뽑아내는 것이 좋다.

---

### 1.7.3. 인라인 함수에서만 `reified` 키워드를 사용할 수 있는 이유

인라인 함수의 경우 컴파일러는 인라인 함수의 본문을 구현한 바이트코드를 그 함수가 호출되는 모든 지점에 삽입한다.

컴파일러는 실체화한 타입 인자를 사용하여 인라인 함수를 호출하는 각 부분의 정확한 타입 인자를 알 수 있다.  
따라서 컴파일러는 타입 인자로 쓰인 구체적인 클래스를 참조하는 바이트코드를 생성하여 삽입할 수 있다.

아래 코드를 다시 보자.

```kotlin
package com.assu.study.kotlin2me.chap09

fun main() {
    val items = listOf("one", 2, "three")

    // [one, three]
    println(items.filterIsInstance<String>())
}
```

위 코드의 `filterIsInstance<String>()` 은 결과적으로 아래와 같은 코드를 만들어낸다.

```kotlin
for (ele in this) {
    if (ele is String) {    // 특정 클래스 참조
        dest.add(ele)        
    }
}
```

타입 파라메터가 아니라 구체적인 타입을 사용하므로 만들어진 바이트코드는 실행 시점에 벌어지는 [타입 소거](#16-타입-소거-type-erasure)의 영향을 받지 않는다.

자바 코드에서는 `reified` 타입 파라메터를 사용하는 인라인 함수를 호출할 수 없다.  
자바에서는 코틀린 인라인 함수를 다른 보통 함수처럼 호출하는데 그런 경우 인라인 함수를 호출해도 실제로 인라이닝되지는 않는다.

---

### 1.7.4. 클래스 참조 대신 실체화한 타입 파라메터 사용: `ServiceLoader`, `::class.java`

**`java.lang.Class` 타입 인자를 파라메터로 받는 API 에 대한 코틀린 Adapter 를 구현하는 경우 실체화한 타입 파라메터를 자주 사용**한다.

`java.lang.Class` 를 사용하는 API 의 예로 JDK 의 `ServiceLoader` 가 있다.

**`ServiceLoader` 는 어떤 추상 클래스나 인터페이스를 표현하는 `java.lang.Class` 를 받아서 그 클래스나 인스턴스를 구현한 인스턴스를 반환**한다.

실체화한 타입 파라메터를 활용해서 이런 API 를 쉽게 호출하는 방법에 대해 알아본다.

표준 자바 API 인 `ServiceLoader` 를 사용하여 서비스를 읽어들이는 예시

```kotlin
package com.assu.study.kotlin2me.chap09

import java.security.Provider.Service
import java.util.ServiceLoader

fun main() {
    val serviceImpl = ServiceLoader.load(Service::class.java)

    // java.util.ServiceLoader[java.security.Provider$Service]
    println(serviceImpl)
}
```

위 코드에서 **`::class.java` 구문은 코틀린 클래스에 대응하는 `java.lang.Class` 참조를 얻는 방법**이다.

코틀린의 `Service::class.java` 는 자바의 `Service.class` 와 같다.

> 위 내용에 대해서는 추후 리플렉션에 대해 다룰 때 좀 더 상세히 다룰 예정입니다. (p. 402)

위 예시를 구체화한 타입 파라메터를 사용하여 작성하면 아래와 같다.

```kotlin
package com.assu.study.kotlin2me.chap09

import java.security.Provider.Service
import java.util.ServiceLoader

// 읽어들일 서비스 클래스를 함수의 타입 인자로 지정
// 타입 파라메터를 reified 로 지정
inline fun <reified T> loadService(): ServiceLoader<T> {
    // T::class 로 타입 파라메터의 클래스를 가져옴
    return ServiceLoader.load(T::class.java)
}

fun main() {
    val serviceImpl2 = loadService<Service>()

    println(serviceImpl2)
}
```

_ServiceLoader.load(Service::class.java)_ 를 _loadService<Service>()_ 로 사용함으로써 코드가 훨씬 짧아진 것을 알 수 있다.

_loadService()_ 에서 읽어들일 서비스 클래스를 타입 인자로 지정하였다.  
클래스를 타입 인자로 지정하면 `::class.java` 라고 쓰는 경우보다 가독성이 더 좋다.

---

### 1.7.5. 실체화한 타입 파라메터의 제약

실체화한 타입 파타메터는 몇 가지 제약이 있다.

<**실체화한 타입 파라메터를 사용할 수 있는 경우**>  
- **타입 검사와 캐스팅**
  - `is`, `!is`, `as`, `as?`
  - [1.7.1. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용](#171-reified-를-사용하여-is-를-제네릭-파라메터에-적용)
- **코틀린 리플렉션 API**
  - `::class`
  - > 해당 내용은 추후 다룰 예정입니다. (p. 403)
- **코틀린 타입에 대응하는 `java.lang.Class` 얻기**
  - `::class.java`
  - [1.7.4. 클래스 참조 대신 실체화한 타입 파라메터 사용: `ServiceLoader`, `::class.java`](#174-클래스-참조-대신-실체화한-타입-파라메터-사용-serviceloader-classjava)
- **다른 함수를 호출할 때 타입 인자로 사용**


<**실체화한 타입 파라메터를 사용할 수 없는 경우**>  
- 타입 파라메터 클래스의 인스턴스 생성
- 타입 파라메터 클래스의 [동반 객체](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#4-%EB%8F%99%EB%B0%98-%EA%B0%9D%EC%B2%B4-companion-object) 메서드 호출
- 실체화한 타입 파라메터를 요구하는 함수를 호출하면서 실체화하지 않은 타입 파라메터로 받은 타입을 타입 인자로 넘기기
- 클래스, 프로퍼티, 인라인 함수가 아닌 함수의 타입 파라메터를 `reified` 로 지정

---

## 1.8. 타입 변성 (type variance)

**변성은 `List<String>` 과 `List<Any>` 와 같이 기반 타입이 같고, 타입 인자가 다른 여러 타입이 서로 어떤 관계가 있는지 설명하는 개념**이다.

제네릭 클래스나 함수를 정의하는 경우 변경에 대해 꼭 알고 있어야 하며, 변성을 잘 활용하면 불편하지 않으면서도 타입 안정성을 보장하는 API 를 만들 수 있다.

제네릭스와 상속을 조합하면 변화가 2차원이 된다.

만일 T 와 U 사이에 상속 관계가 있을 때 _Container\<T\>_ 라는 제네릭 타입 객체를 _Container\<U\>_ 라는 제네릭 타입 컨테이너 객체에 대입하려 한다고 해보자.

이런 경우 _Container_ 타입을 어떤 식으로 쓸 지에 따라 **_Container_ 의 타입 파라메터에 `in` 혹은 `out` 변성 애너테이션(variance annotation)을 붙여서 타입 파라메터를 적용한
_Container_ 타입의 상하위 타입 관계를 제한**해야 한다.

---

### 1.8.1. 타입 변성: `in`/`out` 변성 애너테이션

아래는 기본 제네릭 타입, `in T`, `out T` 를 사용한 예시이다.

```kotlin
// 기본 제네릭 클래스
class Box<T>(private var contents: T) {
    fun put(item: T) {
        contents = item
    }

    fun get(): T = contents
}

class InBox<in T>(private var contents: T) {
    fun put(item: T) {
        contents = item
    }

    // 컴파일 오류
    // Type parameter T is declared as 'in' but occurs in 'out' position in type T
  
    //fun get(): T = contents
}

class OutBox<out T>(private var contents: T) {
    // 컴파일 오류
    // Type parameter T is declared as 'out' but occurs in 'in' position in type T
    
//    fun put(item: T) {
//        contents = item
//    }

    fun get(): T = contents
}
```

`in T` 는 **이 클래스의 멤버 함수가 T 타입의 값을 인자로만 받고, T 타입 값을 반환하지 않는다는 의미**이다.

`out T` 는 **이 클래스의 멤버 함수가 T 타입의 값을 반환하기만 하고, T 타입의 값을 인자로는 받지 않는다는 의미**이다.

---

### 1.8.2. 타입 변성을 사용하는 이유

`List<Any>` 타입의 파라메터를 받는 함수에 `List<String>` 을 넘기는 경우 아래와 같은 오류가 발생한다.

아래는 리스트의 내용을 출력하는 함수 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap09

fun printContents(list: List<Any>) {
    println(list)
}

fun main() {
    // 컴파일 오류
    // Type mismatch.
    // Required: com.assu.study.kotlin2me.chap09.List<Any>
    // Found:kotlin. collections. List<String>
    
    printContents(listOf("a", "b"))
}
```

리스트를 변경하는 예시

```kotlin
package com.assu.study.kotlin2me.chap09

fun addAnswer(list: MutableList<Any>) {
    list.add(1)
}

fun main() {
    // MutableList<String> 타입의 변수 선언
    val strings = mutableListOf("a", "b")

    // 컴파일 오류
    // Type mismatch.
    // Required: MutableList<Any>
    // Found: MutableList<String>
    addAnswer(strings)
}
```

위 예시는 `MutableList<Any>` 가 필요한 곳에 `MutableList<String>` 을 넘기면 안된다는 사실을 보여준다.

즉, 어떤 함수가 리스트의 원소를 추가하거나 변경한다면 타입 불일치가 생길 수 있어서 `List<Any>` 대신 `List<String>` 을 넘길 수 없다.

> 변경이 아닌 단순 조회 시에도 똑같이 컴파일 오류가 남

`in`, `out` 과 같은 제약이 필요한 이유를 알아보기 위해 아래 타입 계층을 보자.

```kotlin
open class Pet

class Rabbit : Pet()

class Cat : Pet()
```

> [1.8.1. 타입 변성: `in`/`out` 변성 애너테이션](#181-타입-변성-inout-변성-애너테이션) 에서 사용된 코드와 함께 보세요.

_Rabbit_ 과 _Cat_ 은 모두 _Pet_ 의 하위 타입이다.

_Box\<Pet\>_ 타입의 변수에 _Box\<Rabbit\>_ 객체를 대입할 수 있을 것처럼 보인다.  
혹은 Any 는 모든 타입의 상위 타입이므로 _Box\<Rabbit\>_ 의 객체를 _Box\<Any\>_ 에 대입하는 것이 가능해야할 것 같다.

하지만 실제 코드를 작성해보면 그렇지 않다.

```kotlin
val rabbitBox = Box<Rabbit>(Rabbit())

// 컴파일 오류
// Type mismatch.
// Required: Box<Pet>
// Found: Box<Rabbit>

//val petBox: Box<Pet> = rabbitBox

// 컴파일 오류
// Type mismatch.
// Required: Box<Any>
// Found: Box<Rabbit>

//val anyBox: Box<Any> = rabbitBox
```

```shell
Type mismatch.
Required: Box<Pet>
Found: Box<Rabbit>
```

_petBox_ 에는 _put(item: Pet)_ 이 있다.

만약 코틀린이 위와 같은 상황에서 오류를 내지 않고 허용한다면 _Cat_ 도 _Pet_ 이므로 _Cat_ 을 _rabbitBox_ 에 넣을 수 있게 되는데 이는 _rabbitBox_ 가 '토끼스러운' 이라는 점을 위반한다.

나아가 _anyBox_ 에도 _put(item: Any)_ 가 있을텐데 _rabbitBox_ 에 Any 타입 객체를 넣으면 이 _rabbitBox_ 컨테이너는 아무런 타입 안전성도 제공하지 못한다.

하지만 `out <T>` 애너테이션을 사용하면 클래스의 멤버 함수가 값을 반환하기만 하고, T 타입의 값을 인자로는 받지 않으므로 _put()_ 을 사용하여 _Cat_ 을 _OutBox\<Rabbit\>_ 에 넣을 수 없다.  
따라서 _rabbitBox_ 를 _petBox_ 나 _anyBox_ 에 대입하는 대입문이 안전해진다.

**_OutBox\<out T\>_ 에 붙은 `out` 애너테이션이 _put()_ 함수 사용을 허용하지 않으므로 컴파일러는 _OutBox\<out Rabbit\>_ 을 _OutBox\<out Pet\>_ 이나 _OutBox\<out Any\>_ 에 
대입하도록 허용**한다.

---

#### 1.8.2.1. 클래스, 타입과 하위 타입

타입과 클래스의 차이에 대해 알아보자.

제네릭 클래스가 아닌 클래스에서는 클래스 이름을 바로 타입으로 사용할 수 있다.

```kotlin
// String 클래스의 인스턴스를 저장하는 변수
val x: String

// String 클래스 이름을 null 이 될 수 있는 타입에도 사용 가능
val x: String?
```

위 코드처럼 모든 코틀린 클래스는 적어도 둘 이상의 타입을 구성할 수 있다.

제네릭 클래스의 경우 올바른 타입을 얻으려면 제네릭 타입의 타입 파라메터를 구체적인 타입 인자로 바꿔주어야 한다.  
예를 들어 `List` 는 클래스이지만 타입은 아니다.  
하지만 타입 인자를 치환한 `List<Int>`, `List<String?>` .. 등은 모두 제대로 된 타입이다.

하위 타입(subtype) 은 **타입 A 의 값이 필요한 모든 장소에 타입 B 를 넣어도 아무런 문제가 없을 경우 '타입 B 는 타입 A 의 하위 타입'**이라고 할 수 있다.  
이는 모든 타입은 자신의 하위 타입이기도 하다는 뜻이다.  
예를 들어 `Int` 는 `Number` 의 하위 타입이지만 `String` 의 하위 타입은 아니다.

**상위 타입(supertype) 은 하위 타입의 반대**이다.

**A 타입이 B 타입의 하위 타입이라면 B 는 A 의 상위 타입**이다.

![A 가 필요한 모든 곳에 B 를 사용할 수 있으면 B 는 A 의 하위 타입](/assets/img/dev/2024/0317/subtype.png)

**컴파일러는 변수 대입이나 함수 인자 전달 시 매번 하위 타입 검사를 수행**한다.

```kotlin
package com.assu.study.kotlin2me.chap09

fun test(i: Int) {
    // Int 는 Number 의 하위 타입이므로 정상적으로 컴파일됨
    val n: Number = i
    
    fun f(s: String) {
        println("f()~")
    }
    
    // 컴파일 오류
    // Int 가 String 의 하위 타입이 아니므로 컴파일되지 않음
    f(i)
}
```

간단한 경우 하위 타입은 하위 클래스와 근본적으로 같다.  
`Int` 클래스는 `Number` 클래스의 파생 클래스이므로 `Int` 는 `Number` 의 하위 타입이다.

`String` 은 `CharSequence` 인터페이스의 하위 타입인 것처럼 **어떤 인터페이스를 구현하는 클래스의 타입은 그 인터페이스 타입의 하위 타입**이다.

아래는 **null 이 될 수 타입은 하위 타입과 하위 클래스가 같지 않는 경우**를 보여준다.

![null 이 될 수 없는 타입](/assets/img/dev/2024/0317/subtype2.png)

**null 이 될 수 없는 타입 A 는 null 이 될 수 있는 타입 A? 의 하위 타입이지만, A? 는 A 의 하위 타입이 아니다.**

null 이 될 수 있는 타입은 null 이 될 수 없는 타입의 하위 타입이 아니지만 두 타입은 같은 클래스에 해당한다.

**제네릭 타입에 대해 다룰 때 특히 하위 클래스와 하위 타입의 차이는 중요**해진다.

_`List<String>` 타입의 값을 `List<Any>` 를 파라메터로 받는 함수에 전달해도 되는가?_ 에 대한 질문을 하위 타입 관계를 써서 다시 보면
_`List<String>` 은 `List<Any>` 의 하위 타입인가?_ 이다.

[1.8.2. 타입 변성을 사용하는 이유](#182-타입-변성을-사용하는-이유) 에서 본 것처럼 `MutableList<String>` 을 `MutableList<Any>` 의 하위 타입으로 
다루면 안되고, 그 반대도 마찬가지이다.  
즉, `MutableList<String>` 을 `MutableList<Any>` 은 서로 하위 타입이 아니다.

**제네릭 타입을 인스턴스화할 때 타입 인자로 서로 다른 타입이 들어가서 인스턴스 타입 사이의 하위 타입 관계가 성립하지 않으면 그 제네릭 타입을 무공변(invariant)** 라고 한다.  
예를 들어 `MutableList` 의 경우 A 와 B 가 서로 다르기만 하면 `MutableList<A>` 는 항상 `MutableList<B>` 의 하위 타입이 아니므로 `MutableList` 는 무공변이다.

예를 들어 **`List` 의 경우 A 가 B 의 하위 타입일 때 `List<A>` 가 `List<B>` 의 하위 타입인데 이런 클래스나 인터페이스를 공변적(covariant)** 이라고 한다.

---

#### 1.8.2.2. 공변성(covariant): 하위 타입 관계 유지 (`out`)

타입 파라메터 `T` 에 붙은 `out` 키워드는 아래를 의미한다.
- **공변성**
  - 하위 타입 관계가 유지됨 (_Producer\<Cat\>_ 은 _Producer\<Animal\>_ 의 하위 타입)
- **사용 제한**
  - `T` 를 `out` 위치에서만 사용 가능

[1.8.1. 타입 변성: `in`/`out` 변성 애너테이션](#181-타입-변성-inout-변성-애너테이션) 에서 `out T` 는 **이 클래스의 멤버 함수가 T 타입의 값을 반환하기만 하고, T 타입의 값을 인자로는 받지 않는다는 의미** 라고 하였다.

_A_ 가 _B_ 의 하위 하입일 때 _Producer\<A\>_ 가 _Producer\<B\>_ 의 하위 타입이면 _Producer_ 는 공변적이다.  
예) _Producer\<Cat\>_ 은 _Producer\<Animal\>_ 의 하위 타입

코틀린에서 제네릭 클래스가 타입 파라메터에 대해 공변적임을 표시하려면 타입 파라메터 이름 앞에 `out` 애너테이션을 넣으면 된다.

```kotlin
// 클래스가 T 에 대해 공변적이라고 선언
interface Producer<out T> {
    fun produce(): T
}
```

**클래스 타입 파라메터를 공변적으로 만들면 함수 정의에 사용한 파라메터 타입과 타입 인자의 타입이 정확히 일치하지 않더라도 그 클래스의 인스턴스를 함수 인자나 
반환값으로 사용할 수 있다.**

아래는 **무공변** 컬렉션 역할을 하는 클래스를 정의하는 예시이다.

```kotlin
// 무공변 컬렉션 역할을 하는 클래스 정의
open class Animal {
    fun feed() = println("feed~")
}

class Herd<T : Animal> { // 이 타입 파라메터를 무공변성으로 지정
    val size: Int
        get() = 1

    operator fun get(i: Int): T  {
        // ...
    }
}

fun feedAll(animals: Herd<Animal>) {
    for (i in 0 until animals.size) {
        animals[i].feed()
    }
}
```

아래는 **무공변** 컬렉션 역할을 하는 클래스를 사용하는 예시이다.

```kotlin
// 무공변 컬렉션 역할을 하는 클래스 사용
// Cat 은 Animal 임
open class Cat : Animal() {
    fun cleanLitter() = println("clean litter~")
}

fun takeCareOfCats(cats: Herd<Cat>) {
    for (i in 0 until cats.size) {
        cats[i].cleanLitter()

        // 컴파일 오류
        // Type mismatch.
        // Required:Herd<Animal>
        // Found:Herd<Cat>
        
        //feedAll(cats)
    }
}
```

_Herd_ 클래스의 T 타입 파라메터에 아무 변성도 지정하지 않았기 때문에 _Cat_ 은 _Animal_ 의 하위 타입이 아니다.  
명시적으로 타입 캐스팅을 사용해서 컴파일 오류를 해결할 수도 있지만 그러면 코드가 장황해지고 실수를 하기 쉽다.  
또한 타입 불일치를 해결하기 위해 강제 캐스팅을 하는 것을 올바른 방법이 아니다.

_Herd_ 클래스는 List 와 비슷한 API 를 제공하며, 동물을 그 클래스에 추가하거나 변경할 수 없다.  
따라서 _Herd_ 를 공변적인 클래스로 만들어서 위 문제를 해결할 수 있다.

아래는 **공변적** 컬렉션 역할을 하는 클래스에 대한 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap09

// 무공변 컬렉션 역할을 하는 클래스 정의
open class Animal2 {
    fun feed() = println("feed~")
}

class Herd2<out T : Animal2> { // T 는 이제 공변적임
    val size: Int
        get() = 1

    operator fun get(i: Int): T {
        // ...
    }
}

fun feedAll2(animals: Herd2<Animal2>) {
    for (i in 0 until animals.size) {
        animals[i].feed()
    }
}

// 무공변 컬렉션 역할을 하는 클래스 사용
// Cat 은 Animal 임
open class Cat2 : Animal2() {
    fun cleanLitter() = println("clean litter~")
}

fun takeCareOfCats2(cats: Herd2<Cat2>) {
    for (i in 0 until cats.size) {
        cats[i].cleanLitter()

        // 캐스팅을 할 필요가 없음
        feedAll2(cats)
    }
}
```

모든 클래스를 공변적으로 만들 수는 없다.

공변적으로 만들면 안전하지 못한 클래스도 있기 때문에 타입 파라메터를 공변적으로 지정하면 클래스 내부에서 그 파라메터를 사용하는 방법을 제한한다.  
**타입 안전성을 보장하기 위해 공변적 파라메터는 항상 `out` 위치**에 있어야 한다.

**즉, 클래스가 `T` 타입의 값을 생산할 수는 있지만 `T` 타입의 값을 소비할 수는 없다는 의미**이다.    
**(= 이 클래스의 멤버 함수가 T 타입의 값을 반환하기만 하고, T 타입의 값을 인자로는 받지 않는다는 의미)**

클래스 멤버를 선언할 때 타입 파라메터를 사용할 수 있는 지점은 모두 `in` 과 `out` 위치로 나뉜다.

`T` 라는 타입 파라메터를 선언하고 `T` 를 사용하는 함수가 멤버로 있는 클래스를 생각해보자.

**`T` 가 함수의 반환 타입으로 쓰인다면 `T` 는 `out` 위치에 있다. (= `T` 타입의 값을 생산함)**  
**`T` 가 함수의 파라메터 타입에 쓰인다면 `T` 는 `in` 위치에 있다. (= `T` 타입의 값을 소비함)**

![in/out 위치](/assets/img/dev/2024/0317/inout.png)

클래스 타입 파라메터 `T` 앞에 `out` 키워드를 붙이면 클래스 안에서 `T` 를 사용하는 메서드가 out 위치에서만 `T` 를 사용하도록 허용한다.  
**`out` 키워드는 `T` 의 사용법을 제한하며, `T` 로 인해 생기는 하위 타입 관계의 타입 안전성을 보장**한다.

바로 위의 코드에서 _Herd_ 클래스를 보자.

```kotlin
class Herd2<out T : Animal2> { // T 는 이제 공변적임
    val size: Int
        get() = 1

    operator fun get(i: Int): T {   // T 를 반환 타입으로 사용
        // ...
    }
}
```

_Herd_ 에서 타입 파라메터 `T` 를 사용하는 곳은 오직 get() 메서드의 반환 타입 뿐이다.  
함수의 반환 타입은 `out` 위치이다.  
따라서 이 클래스를 공변적으로 선언해도 안전하다.

_Cat_ 이 _Animal_ 의 하위 타입이므로 _Herd\<Animal\>_ 의 get() 을 호출하는 모든 코드는 get() 이 _Cat_ 을 반환해도 아무 문제없다.

---

이제 `List<T>` 인터페이스를 보자.  
코틀린 List 는 읽기 전용이므로 `T` 타입의 원소를 반환하는 get() 메서드는 있지만 리스트에 `T` 타입의 값을 추가하거나 변경하는 메서드는 없다.  
**따라서 List 는 공변적**이다.

List\<T\> 시그니처

```kotlin
public interface List<out E> : Collection<E> {
    // ...
    
    // 읽기 전용 메서드로 E 를 반환하는 메서드만 정의함
    // 따라서 E 는 항상 out 위치에 사용됨
    public operator fun get(index: Int): E

    // 여기서도 E 는 out 위치에 있음 
    public fun subList(fromIndex: Int, toIndex: Int): List<E>
}
```

타입 파라메터를 함수의 파라메터 타입이나 반환 타입 뿐 아니라 **다른 타입의 타입 인자**로도 사용할 수 있다.  
예를 들어 위의 subList() 에서 사용된 `T` 도 out 위치에 있다.

---

**`MutableList<T>` 는 타입 파라메터 `T` 에 대해 공변적인 클래스로 선언할 수 없다.**

`MutableList<T>` 에는 `T` 를 인자로 받아서 그 타입의 값을 반환하는 메서드가 있다.  
따라서 `T` 가 in 과 out 위치에 동시에 사용된다.

MutableList\<T\> 의 시그니처

```kotlin
// MutableList 는 E 에 대해 공변적일 수 없음
public interface MutableList<E> : List<E>, MutableCollection<E> {
    // ...
    
    // 이유는 E 가 in 위치에 쓰이기 때문임
    override fun add(element: E): Boolean   
}
```

---

**생성자 파라메터는 `in`, `out` 어느 쪽도 아니다.**

타입 파라메터가 `out` 이라 해도 그 타입을 여전히 생성자 파라메터 선언에 사용할 수 있다.

```kotlin
// 생성자 파라메터는 in, out 어느 쪽도 아님
// 파라메터 타입이 out 이어도 생성자 파라메터에 선언 가능
class Herd3<out T: Animal2>(vararg animals: T) {
    // ...
}
```

변성은 코드에서 코드에서 위험할 여지가 있는 메서드를 호출할 수 없게 만듦으로써 제네릭 타입의 인스턴스 역할을 하는 클래스 인스턴스를 잘못 사용하는 일이 없도록 
방지하는 역할을 한다.  
생성자는 인스턴스를 생성한 뒤 나중에 호출할 수 있는 메서드가 아니므로 생성자는 위험할 여지가 없다.

하지만 val, var 키워드를 생성자 파라메터에 적는다면 getter 나 setter 를 정의하는 것과 같다.  
따라서 읽기 전용 프로퍼티는 out 위치, 변경 가능 프로퍼티는 in/out 위치 모두에 해당한다.

```kotlin
class Herd4<T: Animal2>(var animal1: T, vararg animals: T) {
    // ...
}
```

위 코드에서 `T ` 타입인 _animal1_ 프로퍼티가 in 위치에 사용되었기 때문에 T 를 `out` 으로 표시할 수 없다.

---

**변성 규칙 `in`, `out` 은 오직 외부에서 볼 수 있는 `public`, `protected`, `internal` 클래스 API 에만 적용할 수 있다.**

`private` 메서드의 파라메터는 `in` 도 아니고 `out` 도 아닌 위치이다.  
**변성 규칙은 클래스 외부의 사용자가 클래스를 잘못 사용하는 일을 막기 위한 것이므로 클래스 내부 구현에는 적용되지 않는다.**

> 가시성 변경자에 대한 내용은 [10. 가시성 변경자 (access modifier, 접근 제어 변경자): `public`, `private`, `protected`, `internal`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#10-%EA%B0%80%EC%8B%9C%EC%84%B1-%EB%B3%80%EA%B2%BD%EC%9E%90-access-modifier-%EC%A0%91%EA%B7%BC-%EC%A0%9C%EC%96%B4-%EB%B3%80%EA%B2%BD%EC%9E%90-public-private-protected-internal) 를 참고하세요.

---

따라서 [1.8.2. 타입 변성을 사용하는 이유](#182-타입-변성을-사용하는-이유) 의 코드를 아래와 같이 수정할 수 있다.

```kotlin
val outRabbitBox: OutBox<Rabbit> = OutBox(Rabbit())

// OutBox<Rabbit> 의 객체를 상위 타입에 대입 가능
val outPetBox: OutBox<Pet> = outRabbitBox
val outAnyBox: OutBox<Any> = outRabbitBox

// 같은 수준의 타입으로는 대입 불가
// val outCatBox: OutBox<Cat> = outRabbitBox

fun main() {
    val rabbit: Rabbit = outRabbitBox.get()
    val pet: Pet = outPetBox.get()
    val any: Any = outAnyBox.get()

    println(rabbit) // assu.study.kotlinme.chap07.creatingGenerics.Rabbit@7ef20235
    println(pet) // assu.study.kotlinme.chap07.creatingGenerics.Rabbit@7ef20235
    println(any) // assu.study.kotlinme.chap07.creatingGenerics.Rabbit@7ef20235
}
```

---

#### 1.8.2.3. 반공변성(contravariant): 뒤집힌 하위 타입 관계 (`in`)

[1.8.1. 타입 변성: `in`/`out` 변성 애너테이션](#181-타입-변성-inout-변성-애너테이션) 에서 `in T` 는 **이 클래스의 멤버 함수가 T 타입의 값을 인자로만 받고, T 타입 값을 반환하지 않는다는 의미** 라고 하였다.

> `in` 애너테이션은 상위 타입을 하위 타입에 대입 가능하게 해주고, `out` 애너테이션은 하위 타입을 상위 타입에 대입 가능하게 해줌

[1.8.1. 타입 변성: `in`/`out` 변성 애너테이션](#181-타입-변성-inout-변성-애너테이션) 의 _InBox\<in T\>_ 에는 _get()_ 이 없기 때문에 
_InBox\<Any\>_ 를 _InBox\<Pet\>_ 이나 _InBox\<Pet\>_ 등 하위 타입에 대입할 수 있다.

```kotlin
// InBox<Any> 의 객체를 하위 타입에 대입 가능
val inBoxAny: InBox<Any> = InBox(Any())
val inBoxPet: InBox<Pet> = inBoxAny
val inBoxCat: InBox<Cat> = inBoxAny
val inBoxRabbit: InBox<Rabbit> = inBoxAny

// 같은 수준의 타입으로는 대입 불가
// val inBoxRabbit2: InBox<Rabbit> = inBoxCat

fun main() {
    inBoxAny.put(Any())
    inBoxAny.put(Pet())
    inBoxAny.put(Cat())
    inBoxAny.put(Rabbit())

    // inBoxPet.put(Any())
    inBoxPet.put(Pet())
    inBoxPet.put(Cat())
    inBoxPet.put(Rabbit())

//    inBoxRabbit.put(Any())
//    inBoxRabbit.put(Pet())
//    inBoxRabbit.put(Cat())
    inBoxRabbit.put(Rabbit())

    inBoxCat.put(Cat())
}
```

---

아래는 Box, OutBox, InBox 의 하위 타입 관계이다.
```kotlin
// 기본 제네릭 클래스
class Box<T>(private var contents: T) {
    fun put(item: T) {
        contents = item
    }

    fun get(): T = contents
}

class InBox<in T>(private var contents: T) {
    fun put(item: T) {
        contents = item
    }

    // 컴파일 오류
    // Type parameter T is declared as 'in' but occurs in 'out' position in type T
  
    //fun get(): T = contents
}

class OutBox<out T>(private var contents: T) {
    // 컴파일 오류
    // Type parameter T is declared as 'out' but occurs in 'in' position in type T
    
//    fun put(item: T) {
//        contents = item
//    }

    fun get(): T = contents
}
```

---

#### 1.8.2.4. 무공변(invariant), 공변(covariant), 반공변(contravariant)

![Box, OutBox, InBox 하위 타입 관계](/assets/img/dev/2024/0317/generic2.png)

- **_Box\<T\>_**
  - **무공변(invariant) 임**
  - _Box\<Cat\>_ 과 _Box\<Rabbit\>_ 은 아무런 하위 타입 관계가 없으므로 둘 중 어느 쪽도 반대쪽에 대입 불가
- **_OutBox\<out T\>_**
  - **공변(covariant) 임**
  - _Outbox\<Rabbit\>_ 을 _OutBox\<Pet\>_ 으로 업캐스트하는 방향이 _Rabbit_ 을 _Pet_ 으로 업캐스트하는 방향과 같은 방향으로 변함
- **_InBox\<in T\>_**
  - **반공변(contravariant) 임**
  - _InBox\<Pet\>_ 이 _InBox\<Rabbit\>_ 의 하위 타입임
  - _InBox\<Pet\>_ 을 _InBox\<Rabbit\>_ 으로 업캐스트하는 방향이 _Rabbit_ 을 _Pet_ 으로 업캐스트 하는 방향과 반대 방향으로 변함

---

### 1.8.3. 공변(covariant)과 무공변(invariant)

코틀린 표준 라이브러리의 **읽기 전용 List 는 공변**이므로 _List\<Rabbit\>_ 을 _List\<Pet\>_ 에 대입할 수 있다.  
**반면 MutableList 는 읽기 전용 리스트의 기능에 `add()` 를 추가했기 때문에 무공변**이다.

```kotlin
fun main() {
    val rabbitList: List<Rabbit> = listOf(Rabbit())

    // 읽기 전용 리스트는 공변이므로 List<Rabbit> 을 List<Pet> 에 대입 가능
    val petList: List<Pet> = rabbitList

    var mutablePetList: MutableList<Pet> = mutableListOf(Rabbit())
    mutablePetList.add(Cat())

    // 가변 리스트는 무공변이므로 같은 타입만 대입 가능
    // Type mismatch.
    // Required: MutableList<Pet>
    // Found: MutableList<Cat>

    // mutablePetList = mutableListOf<Cat>(Cat())
}
```

---

### 1.8.4. 함수의 공변적인 반환 타입

함수는 공변적인 반환 타입을 가지기 때문에 오버라이드 하는 함수가 오버라이드 대상 함수보다 더 구체적인 반환 타입을 돌려줘도 된다.

```kotlin
interface Parent
interface Child: Parent

interface X {
    fun f(): Parent
}

interface Y: X {
    // X 의 f() 보다 더 하위 타입을 반환함
    override fun f(): Child
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