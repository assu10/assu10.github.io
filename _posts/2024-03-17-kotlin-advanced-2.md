---
layout: post
title:  "Kotlin - 제네릭스 (타입 정보 보존, 제네릭 확장 함수, 타입 파라메터 제약, 타입 소거, 'reified', 타입 변성 애너테이션 ('in'/'out'), 공변과 무공변)"
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
  * [1.3. 타입 정보 보존](#13-타입-정보-보존)
  * [1.4. 제네릭 확장 함수](#14-제네릭-확장-함수)
  * [1.5. 타입 파라메터 제약: `filterIsInstance()`](#15-타입-파라메터-제약-filterisinstance)
    * [1.5.1. 타입 파라메터 제약으로 지정](#151-타입-파라메터-제약으로-지정)
    * [1.5.2. 제네릭하지 않은 타입으로 지정](#152-제네릭하지-않은-타입으로-지정)
    * [1.5.3. 다형성 대신 타입 파라메터 제약을 사용하는 이유](#153-다형성-대신-타입-파라메터-제약을-사용하는-이유)
    * [1.5.4. 타입 파라메터를 사용해야 하는 경우](#154-타입-파라메터를-사용해야-하는-경우)
  * [1.6. 타입 소거 (type erasure)](#16-타입-소거-type-erasure)
  * [1.7. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`](#17-함수의-타입-인자에-대한-실체화-reified-kclass)
  * [1.8. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용](#18-reified-를-사용하여-is-를-제네릭-파라메터에-적용)
  * [1.9. 타입 변성 (type variance)](#19-타입-변성-type-variance)
    * [1.9.1. 타입 변성: `in`/`out` 변성 애너테이션](#191-타입-변성-inout-변성-애너테이션)
    * [1.9.2. 타입 변성을 사용하는 이유](#192-타입-변성을-사용하는-이유)
      * [1.9.2.1. `out` 애너테이션 사용](#1921-out-애너테이션-사용)
      * [1.9.2.2. `in` 애너테이션 사용](#1922-in-애너테이션-사용)
    * [1.9.3. 공변(covariant)과 무공변(invariant)](#193-공변covariant과-무공변invariant)
    * [1.9.4. 함수의 공변적인 반환 타입](#194-함수의-공변적인-반환-타입)
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

인터페이스는 그 인터페이스만 사용하도록 강제하는데, 이런 제약을 완화하기 위해 코드가 **'미리 정하지 않은 타입' 인 제네릭 타입 파라메터**에 대해 동작하면 더욱 더 일반적인 코드가 될 수 이싿. 

---

## 1.1. `Any`

`Any` 는 코틀린 클래스 계층의 root 이다.  
모든 코틀린 클래스는 `Any` 를 상위 클래스로 가진다.

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

`Any` 를 잘못사용 하는 예시
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

## 1.3. 타입 정보 보존

[1.6. 타입 소거 (type erasure)](#16-타입-소거-type-erasure) 에 나오는 내용이지만, **제네릭 클래스나 제네릭 함수의 내부 코드는 T 타입에 대해 알 수 없다.**  
이를 **타입 소거**라고 한다.

**제네릭스는 반환값의 타입 정보를 유지하는 방법으로, 반환값이 원하는 타입인지 명시적으로 검사하고 변환할 필요가 없다.**

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

**타입 파라메터 제약은 제네릭 타입 인자가 다른 클래스를 상속해야 한다고 지정**한다.

예를 들어 \<T: Base\> 는 T 가 Base 타입이거나, Base 에서 파생된 타입이어야 한다는 의미이다.

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
> 이에 대한 내용은 [1.8. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용](#18-reified-를-사용하여-is-를-제네릭-파라메터에-적용) 을 참고하세요.

---

### 1.5.1. 타입 파라메터 제약으로 지정

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

### 1.5.2. 제네릭하지 않은 타입으로 지정

[1.5.1. 타입 파라메터 제약으로 지정](#151-타입-파라메터-제약으로-지정) 의 코드를 아래와 같이 하면 제네릭스를 사용하지 않고도 같은 결과를 낼 수 있다.

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

### 1.5.3. 다형성 대신 타입 파라메터 제약을 사용하는 이유

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

[1.5.1. 타입 파라메터 제약으로 지정](#151-타입-파라메터-제약으로-지정) 과 [1.5.2. 제네릭하지 않은 타입으로 지정](#152-제네릭하지-않은-타입으로-지정) 는 같은 결과를 반환한다.

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

### 1.5.4. 타입 파라메터를 사용해야 하는 경우

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

---

## 1.6. 타입 소거 (type erasure)

최초 자바는 제네릭이 없다가 제네릭스를 도입하면서 기존 코드와 호환될 수 있어야 했기 때문에 **제네릭 타입은 컴파일 시점에만 사용**할 수 있고, 
런타임 바이트코드에는 제네릭 타입 정보가 보존되지 않는다. (=제네릭 클래스나 제네릭 함수의 내부 코드는 T 타입에 대해 알 수 없음)  
즉, **제네릭 타입의 파라메터 타입이 런타임에는 지워져 버린다.**  

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

## 1.7. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`

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

**타입 정보 T 가 소거되지 때문에 _b()_ 가 컴파일되지 않는 것**이다.  
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

> `inline` 에 대한 좀 더 상세한 내용은 [2.5. 영역 함수의 인라인: `inline`](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#25-%EC%98%81%EC%97%AD-%ED%95%A8%EC%88%98%EC%9D%98-%EC%9D%B8%EB%9D%BC%EC%9D%B8-inline) 을 참고하세요.

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

## 1.8. `reified` 를 사용하여 `is` 를 제네릭 파라메터에 적용

> `is` 키워드에 대한 좀 더 상세한 내용은 [2.1. 스마트 캐스트: `is`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#21-%EC%8A%A4%EB%A7%88%ED%8A%B8-%EC%BA%90%EC%8A%A4%ED%8A%B8-is) 를 참고하세요.

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

> [1.5. 타입 파라메터 제약: `filterIsInstance()`](#15-타입-파라메터-제약-filterisinstance) 에서 사용한 타입 계층 코드와 함께 보세요.

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

참고로 `filterIsInstance()` 도 `reified` 키워드를 사용하여 정의되어 있다.

---

## 1.9. 타입 변성 (type variance)

제네릭스와 상속을 조합하면 변화가 2차원이 된다.

만일 T 와 U 사이에 상속 관계가 있을 때 _Container\<T\>_ 라는 제네릭 타입 객체를 _Container\<U\>_ 라는 제네릭 타입 컨테이너 객체에 대입하려 한다고 해보자.

이런 경우 _Container_ 타입을 어떤 식으로 쓸 지에 따라 **_Container_ 의 타입 파라메터에 `in` 혹은 `out` 변성 애너테이션(variance annotation)을 붙여서 타입 파라메터를 적용한
_Container_ 타입의 상하위 타입 관계를 제한**해야 한다.

---

### 1.9.1. 타입 변성: `in`/`out` 변성 애너테이션

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

### 1.9.2. 타입 변성을 사용하는 이유

`in`, `out` 과 같은 제약이 필요한 이유를 알아보기 위해 아래 타입 계층을 보자.

```kotlin
open class Pet

class Rabbit : Pet()

class Cat : Pet()
```

> [1.9.1. 타입 변성: `in`/`out` 변성 애너테이션](#191-타입-변성-inout-변성-애너테이션) 에서 사용된 코드와 함께 보세요.

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

_petBox_ 에 있는 _put(item: Pet)_ 이 있다.

만약 코틀린이 위와 같은 상황에서 오류를 내지 않고 허용한다면 _Cat_ 도 _Pet_ 이므로 _Cat_ 을 _rabbitBox_ 에 넣을 수 있게 되는데 이는 _rabbitBox_ 가 '토끼스러운' 이라는 점을 위반한다.

나아가 _anyBox_ 에도 _put(item: Any)_ 가 있을텐데 _rabbitBox_ 에 Any 타입 객체를 넣으면 이 _rabbitBox_ 컨테이너는 아무런 타입 안전성도 제공하지 못한다.

하지만 `out <T>` 애너테이션을 사용하면 클래스의 멤버 함수가 값을 반환하기만 하고, T 타입의 값을 인자로는 받지 않으므로 _put()_ 을 사용하여 _Cat_ 을 _OutBox\<Rabbit\>_ 에 넣을 수 없다.  
따라서 _rabbitBox_ 를 _petBox_ 나 _anyBox_ 에 대입하는 대입문이 안전해진다.

**_OutBox\<out T\>_ 에 붙은 `out` 애너테이션이 _put()_ 함수 사용을 허용하지 않으므로 컴파일러는 _OutBox\<out Rabbit\>_ 을 _OutBox\<out Pet\>_ 이나 _OutBox\<out Any\>_ 에 
대입하도록 허용**한다.

---

#### 1.9.2.1. `out` 애너테이션 사용

따라서 [1.9.2. 타입 변성을 사용하는 이유](#192-타입-변성을-사용하는-이유) 의 코드를 아래와 같이 수정할 수 있다.

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

#### 1.9.2.2. `in` 애너테이션 사용

> `in` 애너테이션은 상위 타입을 하위 타입에 대입 가능하게 해주고, `out` 애너테이션은 하위 타입을 상위 타입에 대입 가능하게 해줌

[1.9.1. 타입 변성: `in`/`out` 변성 애너테이션](#191-타입-변성-inout-변성-애너테이션) 의 _InBox\<in T\>_ 에는 _get()_ 이 없기 때문에 
_InBox<\Any\>_ 를 _InBox\<Pet\>_ 이나 _InBox\<Pet\>_ 등 하위 타입에 대입할 수 있다.

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

![Box, OutBox, InBox 하위 타입 관계](/assets/img/dev/2024/0317/generic2.png)

- **_Box\<T\>_**
  - **무공변(invariant) 임**
  - _Box\<Cat\>_ 과 _Box\<Rabbit\>_ 은 아무런 하위 타입 관계가 없으므로 둘 중 어느 쪽도 반대쪽에 대입 불가
- **_OutBox\<out T\>_**
  - **공변(covariant) 임**
  - _Outbox\<Rabbit\>_ 을 _OutBox\<Pet\>_ 으로 업캐스트하는 방향이 _Rabbit_ 을 _Pet_ 으로 업캐스트하는 방향과 같은 방향으로 변함
- **_InBox<\in T\>_**
  - **반공변(contravariant) 임**
  - _InBox\<Pet\>_ 이 _InBox\<Rabbit\>_ 의 하위 타입임
  - _InBox\<Pet\>_ 을 _InBox\<Rabbit\>_ 으로 업캐스트하는 방향이 _Rabbit_ 을 _Pet_ 으로 업캐스트 하는 방향과 반대 방향으로 변함

---

### 1.9.3. 공변(covariant)과 무공변(invariant)

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

### 1.9.4. 함수의 공변적인 반환 타입

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

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [아토믹 코틀린 예제 코드](https://github.com/gilbutITbook/080301)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)