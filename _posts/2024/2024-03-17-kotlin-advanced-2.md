---
layout: post
title: "Kotlin - 제네릭스(1): Any, 타입 정보 보존, 제네릭 확장 함수, 타입 파라미터 제약, 타입 소거"
date: 2024-03-17
categories: dev
tags: kotlin generics filterIsInstance() typeParameter typeErasure
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
  * [1.5. 타입 파라미터 제약: `filterIsInstance()`](#15-타입-파라미터-제약-filterisinstance)
    * [1.5.1. 제네릭 타입 파라미터](#151-제네릭-타입-파라미터)
    * [1.5.2. 타입 파라미터 제약으로 지정](#152-타입-파라미터-제약으로-지정)
      * [1.5.2.1. 타입 파라미터에 둘 이상의 제약 지정: `where`](#1521-타입-파라미터에-둘-이상의-제약-지정-where)
    * [1.5.3. 제네릭하지 않은 타입으로 지정](#153-제네릭하지-않은-타입으로-지정)
    * [1.5.4. 다형성 대신 타입 파라미터 제약을 사용하는 이유](#154-다형성-대신-타입-파라미터-제약을-사용하는-이유)
    * [1.5.5. 타입 파라미터를 사용해야 하는 경우](#155-타입-파라미터를-사용해야-하는-경우)
  * [1.6. 타입 소거 (type erasure)](#16-타입-소거-type-erasure)
    * [1.6.1. 실행 시점의 제네릭: 타입 검사와 캐스트](#161-실행-시점의-제네릭-타입-검사와-캐스트)
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

기반 클래스 객체를 파라미터로 받는 함수를 작성하고, 기반 클래스로부터 파생된 클래스의 객체를 사용하여 이 함수를 호출하면 좀 더 일반적인 함수가 된다.

다형적인 함수의 파라미터에 맞는 객체를 만들기 위해서는 클래스 계층을 상속해야하는데, 다형성을 활용하는 경우 단일 계층만 가능하다는 점은 심한 제약이 될 수 있다.  
함수 파라미터가 클래스가 아닌 인터페이스라면 인터페이스를 구현하는 모든 타입을 포함하도록 제약이 약간 완화된다.

이제 기존 클래스와 조합하여 인터페이스를 구현할 수 있고, 이 말을 여러 클래스 계층을 가로질러 인터페이스를 구현하여 사용할 수 있다는 의미이다.

인터페이스는 그 인터페이스만 사용하도록 강제하는데, 이런 제약을 완화하기 위해 코드가 **'미리 정하지 않은 타입' 인 제네릭 타입 파라미터**에 대해 동작하면 더욱 더 일반적인 코드가 될 수 있다.

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
// 타입 파라미터로 T 를 받고, T 를 반환
fun <T> gFunction(arg: T): T = arg

// T 를 저장
class GClass<T>(val x: T) {
    // T 반환
    fun f(): T = x
}

// 클래스 안에서 멤버 함수를 파라미터화함
class GMemberFunction {
    fun <T> f(arg: T): T = arg
}

// interface 가 제네릭 파라미터를 받는 경우
// 이 인터페이스를 구현하는 클래스는 GImplementation 클래스처럼 타입 파라미터를 재정의하거나,
// ConcreteImplementation 클래스처럼 타입 파라미터에 구체적인 타입 인자를 제공해야 함
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

![제네릭 함수 `slice()` 는 `T` 를 타입 파라미터로 받음](/assets/img/dev/2024/0317/type.png)

위를 보면 수신 객체와 반환 타입은 모두 `List<T>` 로, 함수의 타입 파라미터 `T` 가 수신 객체와 반환 타입으로 사용되고 있다.

아래는 `filter()` 의 시그니처이다.

```kotlin
public inline fun <T> Iterable<T>.filter(predicate: (T) -> Boolean): List<T>
```

`filter()` 는 `(T) -> Boolean` 타입의 함수를 파라미터로 받는다.

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

위에서 람다 파라미터에 대해 자동으로 만들어진 변수 `it` 의 타입은 `T` 라는 제네릭 타입이다.  
(여기서 `T` 는 함수 파라미터 타입인 `(T) -> Boolean` 에서 온 타입임)

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
    // 이 호출에서 타입 파라미터 T 는 int 로 추론됨
    println(listOf(1, 2, 3).pre)
}
```

확장이 아닌 일반 프로퍼티는 타입 파라미터를 가질 수 없다.  
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

타입 파라미터를 넣은 꺽쇠 기호 `<>` 를 클래스 혹은 인터페이스 이름 뒤에 붙이면 클래스나 인터페이스를 제네릭하게 만들 수 있다.

타입 파라미터를 이름 뒤에 붙이고 나면 클래스 본문 안에서 타입 파라미터를 다른 일반 타입처럼 사용 가능하다.

**제네릭 클래스를 확장하는 클래스 혹은 제네릭 인터페이스를 구현하는 클래스를 정의하려면 기반 타입의 제네릭 파라미터에 대해 타입 인자를 지정**해야 한다.  
이 때 구체적인 타입을 넘길수도 있고, 만일 하위 클래스도 제네릭 클래스라면 타입 파라미터로 받은 타입을 넘길수도 있다.

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

// ArrayList 의 제네릭 타입 파라미터 T 를 List 의 타입 인자로 넘김
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

위에서 _String1_ 클래스는 제네릭 Comparable 인터페이스를 구현하면서 그 인터페이스의 타입 파라미터 `T` 로 _String1_ 자신을 지정한다.

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

> 클래스로 파라미터를 받는 클래스에 대한 좀 더 상세한 내용은 [5.1. 하나의 타입 파라미터를 받는 클래스](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#51-%ED%95%98%EB%82%98%EC%9D%98-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A5%BC-%EB%B0%9B%EB%8A%94-%ED%81%B4%EB%9E%98%EC%8A%A4) 를 참고하세요.

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

> 제네릭 클래스에 대한 좀 더 상세한 내용은 [5.2. 제네릭 타입 파라미터를 받는 클래스: `<T>`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#52-%EC%A0%9C%EB%84%A4%EB%A6%AD-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A5%BC-%EB%B0%9B%EB%8A%94-%ED%81%B4%EB%9E%98%EC%8A%A4-t) 를 참고하세요.

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

## 1.5. 타입 파라미터 제약: `filterIsInstance()`

**타입 파라미터 제약은 클래스나 함수에 사용할 수 있는 타입 인자를 제한**하는 기능이다.

**타입 파라미터 제약은 제네릭 타입 인자가 다른 클래스를 상속해야 한다고 지정**한다.

예를 들어 \<T: Base\> 는 T 가 Base 타입이거나, Base 에서 파생된 타입이어야 한다는 의미이다.

어떤 타입을 제네릭 타입의 타입 파라미터에 대한 상한으로 지정하면 그 제네릭 타입을 인스턴스화할 때 사용하는 타입 인자는 반드시 그 상한 타입이거나 그 상한 타입의 
하위 타입이어야 한다.

> 하위 타입과 하위 클래스에 대한 차이는 [2.2.1. 클래스, 타입과 하위 타입](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#221-%ED%81%B4%EB%9E%98%EC%8A%A4-%ED%83%80%EC%9E%85%EA%B3%BC-%ED%95%98%EC%9C%84-%ED%83%80%EC%9E%85) 을 참고하세요.

**타입 파라미터 제약으로 Base 를 지정하는 경우**와 **Base 를 상속하는 제네릭하지 않은 타입(= 일반 타입) 의 차이**에 대해 알아보자.

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
> 이에 대한 내용은 [1.1. `reified` 를 사용하여 `is` 를 제네릭 파라미터에 적용](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#11-reified-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%98%EC%97%AC-is-%EB%A5%BC-%EC%A0%9C%EB%84%A4%EB%A6%AD-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EC%97%90-%EC%A0%81%EC%9A%A9) 을 참고하세요.

---

### 1.5.1. 제네릭 타입 파라미터

제네릭스를 사용하면 타입 파라미터를 받는 타입을 정의할 수 있다.  
제네릭 타입의 인스턴스를 만들려면 타입 파라미터를 구체적인 타입 인자로 치환해야 한다.

예를 들어 `Map` 클래스는 key 타입과 value 타입을 타입 파라미터로 받으므로 `Map<K,V>` 가 된다.  
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

### 1.5.2. 타입 파라미터 제약으로 지정

제약을 가하려면 타입 파라미터 이름 뒤에 콜론 `:` 을 붙이고 그 뒤에 상한 타입을 명시하면 된다.

```kotlin
fun <T : Number> List<T>.sum(): T
```

위 코드의 `<T: Number>` 에서 `T` 는 타입 파라미터이고, `Number` 는 상한 타입이다.

타입 파라미터 `T` 에 대한 상한을 정하고 나면 `T` 타입의 값을 그 상한 타입의 값으로 취급할 수 있다.

상한 타입으로 정의된 Number 의 메서드를 `T` 타입의 값에 대해 호출하는 예시

```kotlin
package com.assu.study.kotlin2me.chap09

// Number 를 타입 파라미터 상한으로 정함
fun <T : Number> oneHalf(value: T): Double {
    // Number 클래스에 정의된 메서드 호출
    return value.toDouble() / 2.0
}

fun main() {
    println(oneHalf(3)) // 1.5
}
```

아래는 두 파라미터 사이에서 더 큰 값을 찾는 제네릭 함수이다.  
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

**타입 파라미터 제약을 사용하면 제네릭 함수 안에서 제약이 이뤄진 타입의 프로퍼티와 함수에 접근이 가능**하다.    
만일 제약을 사용하지 않으면 _name_ 을 사용할 수 없다.

```kotlin
// 타입 파라미터 제약 사용
// 타입 파라미터 제약을 사용하지 않으면 name 에 접근 불가
fun <T : Disposable> nameOf(disposable: T) = disposable.name

// 타입 파라미터 제약을 사용한 확장 함수
// 타입 파라미터 제약을 사용하지 않으면 name 에 접근 불가
fun <T : Disposable> T.customName() = name

fun main() {
    val result1 = recyclables.map { nameOf(it) }
    val result2 = recyclables.map { it.customName() }

    println(result1) // [EEE, FFF]
    println(result2) // [EEE, FFF]
}
```

---

#### 1.5.2.1. 타입 파라미터에 둘 이상의 제약 지정: `where`

드물지만 타입 파라미터에 둘 이상의 제약을 가해야 하는 경우도 있다.

아래는 `CharSequence` 의 맨 끝에 마침표 `.` 가 있는지 검사하는 제네릭 함수이다.

```kotlin
package com.assu.study.kotlin2me.chap09

fun <T> ensureTrailingPeriod(seq: T)
        where T : CharSequence, T : Appendable { // 타입 파라미터 제약 목록
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

[1.5.2. 타입 파라미터 제약으로 지정](#152-타입-파라미터-제약으로-지정) 의 코드를 아래와 같이 하면 제네릭스를 사용하지 않고도 같은 결과를 낼 수 있다.

```kotlin
// 타입 파라미터 제약을 사용하지 않음
fun nameOf2(disposable: Disposable) = disposable.name

// 티입 파라미터 제약을 사용하지 않은 확장 함수
fun Disposable.customName2() = name

fun main() {
    val result1 = recyclables.map { nameOf2(it) }
    val result2 = recyclables.map { it.customName2() }

    println(result1) // [EEE, FFF]
    println(result2) // [EEE, FFF]
}
```

---

### 1.5.4. 다형성 대신 타입 파라미터 제약을 사용하는 이유

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

[1.5.2. 타입 파라미터 제약으로 지정](#152-타입-파라미터-제약으로-지정) 과 [1.5.3. 제네릭하지 않은 타입으로 지정](#153-제네릭하지-않은-타입으로-지정) 는 같은 결과를 반환한다.

**다형성 대신 타입 파라미터 제약을 사용하는 이유는 반환 타입 때문**이다.

다형성을 사용하는 경우엔 반환 타입을 기반 타입으로 업캐스트하여 반환해야 하지만, 제네릭스를 사용하면 정확한 타입을 지정할 수 있다.

```kotlin
import kotlin.random.Random

private val rand = Random(47)

// 타입 파라미터 제약을 사용하지 않은 확장 함수
fun List<Disposable>.nonGenericConstrainedRandom(): Disposable = this[rand.nextInt(size)]

// 타입 파라미터 제약을 사용한 확장 함수
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

_genericConstrainedRandom()_ 는 _Disposable_ 의 멤버를 전혀 사용하지 않으므로 T에 걸린 _:Disposable_ 타입 파라미터 제약이 의미가 없어서 결국 
타입 파라미터 제약을 걸지 않은 _genericRandom()_ 과 동일하다. (= 타입 파라미터 제약을 사용할 필요없이 일반 제네릭으로 사용해도 되는 케이스)

---

### 1.5.5. 타입 파라미터를 사용해야 하는 경우

**타입 파라미터를 사용해야 하는 경우는 아래 2가지가 모두 필요할 때 뿐**이다.

- 타입 파라미터 안에 선언된 함수나 프로퍼티에 접근해야 하는 경우
- 결과를 반환할 때 타입을 유지해야 하는 경우

```kotlin
import kotlin.random.Random

private val rand = Random(47)

// 타입 파라미터 제약을 사용하지 않은 확장 함수
// action() 에 접근할 수는 있지만 정확한 타입 반환 불가 (result4 참고)
fun List<Disposable>.nonGenericConstrainedRandom2(): Disposable {
    val d: Disposable = this[rand.nextInt(this.size)]
    d.action()
    return d
}

// 제네릭 확장 함수
// 타입 파라미터 제약이 없어서 action() 에 접근 불가
fun <T> List<T>.genericRandom2(): T {
    val d: T = this[rand.nextInt(this.size)]
    // action() 에 접근 불가
    // d.action()
    return d
}

// 타입 파라미터 제약을 사용한 확장 함수
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

**타입 파라미터 제약을 사용하지 않은 확장 함수**인 _nonGenericConstrainedRandom2()_ 는 _List\<Disposable\>_ 의 확장 함수이기 때문에 
**함수 내부에서 _action()_ 에 접근할 수는 있지만**, 제네릭 함수가 아니므로 _result4: Recyclable_ 가 오류가 나는 것처럼 **기반 타입인 _Disposable_ 로만 값을 반환**할 수 있다.

**제네릭 함수**인 _genericRandom2()_ 는 **T 타입을 반환할 수는 있지만** 타입 파라미터 제약이 없기 때문에 **_Disposable_ 에 정의된 _action()_ 에 접근할 수 없다.**

**타입 파라미터 제약을 사용한 확장 함수**인 _genericConstrainedRandom2()_ 는 **_Disposable_ 에 정의된 _action()_ 에 접근**하면서 _result5_, _result6_ 과 같이 **정확한 
타입을 반환**할 수 있다.

> 타입 파라미터를 null 이 될 수 없는 타입으로 한정하는 부분에 대해서는 [5.2.2. 타입 파라미터를 null 이 될 수 없는 타입으로 한정](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#522-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A5%BC-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%97%86%EB%8A%94-%ED%83%80%EC%9E%85%EC%9C%BC%EB%A1%9C-%ED%95%9C%EC%A0%95) 을 참고하세요.

---

## 1.6. 타입 소거 (type erasure)

최초 자바는 제네릭이 없다가 제네릭스를 도입하면서 기존 코드와 호환될 수 있어야 했기 때문에 **제네릭 타입은 컴파일 시점에만 사용**할 수 있고, 
런타임 바이트코드에는 제네릭 타입 정보가 보존되지 않는다. (=제네릭 클래스나 제네릭 함수의 내부 코드는 T 타입에 대해 알 수 없음)  
즉, **제네릭 타입의 파라미터 타입 정보가 런타임에는 지워져 버린다.**

이것을 **타입 소거** 라고 한다.

아래 코드를 보자.

```kotlin
fun useList(list: List<Any>) {
  // 아래와 같은 오류
  // Cannot check for instance of erased type: List<String>
  // 소거된 타입인 List<String> 의 인스턴스를 검사할 수 없다는 의미
  // 타입 소거 때문에 실행 시점에 제네릭 타입의 타입 파라미터 타입을 검사할 수 없음
    
  // if (list is List<String>) {}
}

fun main() {
    val strings = listOf('a', 'b', 'c')
    val all: List<Any> = listOf(1, 2, 'd')
}
```

아래 오류는 소거된 타입 List\<String\> 의 인스턴스를 검사할 수 없다는 의미로 타입 소거 때문에 실행 시점에 제네릭 타입의 타입 파라미터 타입을 검사할 수 없다는 의미이다.

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
  - 제네릭 객체가 모든 곳에서 타입 파라미터를 실체화하여 저장한다면 제네릭 객체인 Map.Entry 객체로 이루어진 Map 의 경우 Map.Entry 의 모든 키와 값이 부가 타입 정보를 저장해야 함

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