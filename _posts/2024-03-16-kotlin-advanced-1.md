---
layout: post
title: "Kotlin - 확장 람다, StringBuilder, buildString(), 영역 함수, 'inline'"
date: 2024-03-16
categories: dev
tags: kotlin filterIndexed() toCharArray() stringBuilder buildString() buildList() buildMap() forEachIndexed() let() run() with() apply() also() removeSuffix() takeUnless() inline
---

이 포스트에서는 확장 람다와 영역 함수에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 확장 람다](#1-확장-람다)
  * [1.1. 여러 파라메터를 받는 확장 람다](#11-여러-파라메터를-받는-확장-람다)
  * [1.2. 함수의 파라메터로 확장 람다 사용](#12-함수의-파라메터로-확장-람다-사용)
  * [1.3. 확장 람다의 반환 타입이 Unit 인 경우](#13-확장-람다의-반환-타입이-unit-인-경우)
  * [1.4. 일반 람다를 파라메터로 받는 위치에 확장 람다 전달: `filterIndexed()`, `toCharArray()`](#14-일반-람다를-파라메터로-받는-위치에-확장-람다-전달-filterindexed-tochararray)
  * [1.5. 확장 람다 대신 함수 참조(`::`) 전달](#15-확장-람다-대신-함수-참조-전달)
  * [1.6. 일반 확장 함수와 확장 람다에서의 다형성](#16-일반-확장-함수와-확장-람다에서의-다형성)
  * [1.7. 확장 람다 대신 익명 함수 구문 사용](#17-확장-람다-대신-익명-함수-구문-사용)
  * [1.8. 확장 람다와 사용하는 `StringBuilder` 와 `buildString()`](#18-확장-람다와-사용하는-stringbuilder-와-buildstring)
  * [1.9. `buildList()`, `buildMap()`: `forEachIndexed()`](#19-buildlist-buildmap-foreachindexed)
  * [1.10. 확장 람다로 빌더 작성 (빌더 패턴)](#110-확장-람다로-빌더-작성-빌더-패턴)
* [2. 영역 함수 (Scope Function): `let()`, `run()`, `with()`, `apply()`, `also()`](#2-영역-함수-scope-function-let-run-with-apply-also)
  * [2.1. `with()`](#21-with)
  * [2.2. `apply()`](#22-apply)
  * [2.3. `let()`](#23-let)
  * [2.4. 안전한 호출(`?.`) 로 영역 함수 사용: `Random.nextBoolean()`, `removeSuffix()`](#24-안전한-호출-로-영역-함수-사용-randomnextboolean-removesuffix)
  * [2.5. Map 을 검색한 결과에 영역 함수 적용](#25-map-을-검색한-결과에-영역-함수-적용)
  * [2.6. 연쇄 호출에서 null 이 될 수 있는 타입에 영역 함수 사용: `takeUnless()`](#26-연쇄-호출에서-null-이-될-수-있는-타입에-영역-함수-사용-takeunless)
  * [2.7. 영역 함수와 자원 해제 `use()`](#27-영역-함수와-자원-해제-use)
  * [2.8. 영역 함수의 인라인: `inline`](#28-영역-함수의-인라인-inline)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 확장 람다

확장 람다는 확장 함수와 비슷하다.

> 확장 함수에 대한 좀 더 상세한 내용은 [1. 확장 함수 (extension function)](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#1-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-extension-function) 를 참고하세요.

```kotlin
val va: (String, Int) -> String = { str, n ->
    str.repeat(n) + str.repeat(n)
}

// 확장 람다
// String 파라메터를 괄호 밖으로 옮겨서 String.(Int) 처럼 확장 함수 구문 사용
// 확장 대상 객체(여기서는 String) 이 수신 객체가 되고, this 를 통해서 수신 객체에 접근 가능
val vb: String.(Int) -> String = {
    this.repeat(it) + repeat(it)
}

fun main() {
    val result1 = va("Assu", 2)
    val result2 = "Assu".vb(2)
    val result3 = vb("Assu", 2)

    // 컴파일되지 않음
    // val result4 = "Assu".va(2)

    println(result1) // AssuAssuAssuAssu
    println(result2) // AssuAssuAssuAssu
    println(result3) // AssuAssuAssuAssu
}
```

위 코드에서 va() 의 호출은 _(String, Int) -> String_ 을 보고 예상할 수 있는 호출 형태이다.

아래 확장 함수 구문을 보자.  
다른 람다와 마찬가지로 파라메터가 하나(여기서는 Int) 뿐이면 확장 함수에서도 `it` 으로 그 유일한 파라메터를 가리킬 수 있다.
```kotlin
// String 파라메터를 괄호 밖으로 옮겨서 String.(Int) 처럼 확장 함수 구문 사용
// 확장 대상 객체(여기서는 String) 이 수신 객체가 되고, this 를 통해서 수신 객체에 접근 가능
val vb: String.(Int) -> String = {
    this.repeat(it) + repeat(it)
}
```

확장 람다인 위 함수에서 String 을 확장하는 건 파라메터 목록인 (Int) 가 아니라 전체 람다인 _(Int) -> String_ 이다.  
따라서 확장 람다는 _String.(Int) -> String_ 에서 _(Int) -> String_ 이 부분이다. 

코틀린에서는 **확장 람다를 수신 객체가 지정된 함수 리터럴** 이라고 한다.  
**함수 리터럴은 람다와 익명 함수 모두를 포함**한다.  
따라서 수신 객체가 암시적 파라메터로 추가 지정된 람다라는 사실을 강조하고 싶을 때는 **수신 객체가 지정된 람다**를 **확장 람다**의 동의어로 더 자주 사용한다.

---

## 1.1. 여러 파라메터를 받는 확장 람다

확장 함수처럼 확장 람다도 여러 파라메터를 받을 수 있다.

```kotlin
// Int 의 확장 람다
// 파라메터는 아무것도 받지 않고 Boolean 리턴 () -> Boolean
val zero: Int.() -> Boolean = {
    this == 0
}

// 파라메터에 이름을 붙이는 대신 `it` 사용
val one: Int.(Int) -> Boolean = {
    this % it == 0
}

val two: Int.(Int, Int) -> Boolean = { arg1, arg2 ->
    this % (arg1 + arg2) == 0
}

val three: Int.(Int, Int, Int) -> Boolean = { arg1, arg2, arg3 ->
    this % (arg1 + arg2 + arg3) == 0
}

fun main() {
    val result1 = 0.zero()
    val result2 = 10.one(10)
    val result3 = 20.two(10, 10)
    val result4 = 30.three(10, 10, 10)

    println(result1) // true
    println(result2) // true
    println(result3) // true
    println(result4) // true
}
```

---

## 1.2. 함수의 파라메터로 확장 람다 사용

위에선 val 를 선언하여 확장 람다를 이용했지만 아래의 _f2()_ 처럼 **함수의 파라메터로 확장 람다를 사용하는 것이 일반적**이다.

_f1()_ 보다 _f2()_ 가 람다가 더 간결해진다.

```kotlin
class A {
    fun af() = 1
}

class B {
    fun bf() = 2
}

fun f1(lambda1: (A, B) -> Int) = lambda1(A(), B())

// 함수의 파라메터로 확장 람다 사용
fun f2(lambda2: A.(B) -> Int) = A().lambda2(B())

fun main() {
    val result1 = f1 { aa, bb -> aa.af() + bb.bf() }
    val result2 = f2 { af() + it.bf() }

    println(result1) // 3
    println(result2) // 3
}
```

---

## 1.3. 확장 람다의 반환 타입이 Unit 인 경우

**확장 람다의 반환 타입이 Unit 이면 람다 본문이 만들어 낸 결과는 무시**된다.  
람다 본문의 마지막 식의 값을 무시한다는 의미로써 return 으로 Unit 이 아닌 값을 반환하면 타입 오류가 발생한다.

```kotlin
class A1 {
    fun af() = 1
}

fun unitReturn(lambda1: A1.() -> Unit) = A1().lambda1()

fun nonUnitReturn(lambda1: A.() -> String) = A().lambda1()

fun main() {
    val result1 = unitReturn { "Unit 은 리턴값을 무시하기 때문에 이건 아무것도 할 수 없음" }
    val result2 = unitReturn { 1 } // 임의의 타입
    val result3 = unitReturn { } // 아무 값도 만들어내지 않는 경우
    val result4 = nonUnitReturn { "적절한 타입을 넣어주세요" }

    // 컴파일 오류
    // val result5 = nonUnitReturn { }

    println(result1) // kotlin.Unit
    println(result2) // kotlin.Unit
    println(result3) // kotlin.Unit
    println(result4) // 적절한 타입을 넣어주세요
}
```

---

## 1.4. 일반 람다를 파라메터로 받는 위치에 확장 람다 전달: `filterIndexed()`, `toCharArray()`

**일반 람다를 파라메터로 받는 위치에 확장 람다를 전달**할 수도 있는데 **이 때 두 람다의 파라메터 목록을 서로 호환**되어야 한다.

```kotlin
// 일반 람다를 파라메터로 받는 String 의 확장 함수
fun String.transform1(
    n: Int,
    lambda: (String, Int) -> String,
) = lambda(this, n)

// 확장 람다를 파라메터로 받는 String 의 확장 함수
fun String.transform2(
    n: Int,
    lambda: String.(Int) -> String,
) = lambda(this, n)

// val 를 선언하여 String 의 확장 람다 이용
val duplicate: String.(Int) -> String = { repeat(it) }

// val 를 선언하여 String 의 확장 람다 이용
val alternate: String.(Int) -> String = {
    toCharArray()
        .filterIndexed { i, _ -> i % it == 0 }
        .joinToString(separator = "")
}

fun main() {
    val result1 = "hello".transform1(5, duplicate).transform2(3, alternate)
    val result2 = "hello".transform2(5, duplicate).transform1(3, alternate)

    println(result1) // hleolhleo
    println(result2) // hleolhleo
}
```

확장 람다인 _duplicate_ 와 _alternate_ 를 _transform1()_ 에 넘긴 경우, 두 람다의 내부에서 수신 객체 this 는 첫 번째 인자로 받은 String 객체가 된다.


`filterIndexed()` 는 element 의 값과 인덱스 값을 이용할 수 있다.

`filterIndexed()` 시그니처
```kotlin
inline fun <T> Array<out T>.filterIndexed(predicate: (index: Int, T) -> Boolean): List<T>
```

> **`toCharArray()`**  
> 
> 문자열을 한 글자씩 분리할 때 `문자열.toCharArray()` 를 사용하면 문자열을 charArray 로 변환함  
> 
> `문자열.toList()` 를 사용하여 List\<Char\> 를 반환받아서 사용해도 무방함 


> `joinToString()` 에 대한 좀 더 상세한 내용은 [2.3. `joinToString()`](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#23-jointostring) 을 참고하세요.


---

## 1.5. 확장 람다 대신 함수 참조(`::`) 전달

**`::` 을 사용하여 확장 람다가 필요한 곳에 함수 참조를 넘길 수도 있다.**

```kotlin
fun Int.d1(f: (Int) -> Int) = f(this) * 10

fun Int.d2(f: Int.() -> Int) = f(this) * 10

fun f1(n: Int) = n + 3

fun Int.f2() = this + 3

fun main() {
    val result1 = 11.d1(::f1)
    val result2 = 11.d2(::f1)
    val result3 = 11.d1(Int::f2)
    val result4 = 11.d2(Int::f2)

    println(result1) // 140
    println(result2) // 140
    println(result3) // 140
    println(result4) // 140
}
```

확장 함수에 대한 참조를 확장 람다의 타입과 같다.

위 예시에서 _Int::f2_ 는 _Int.() -> Int_ 이다.

_11.d1(Int::f2)_ 호출을 보면 일반 람다 파라메터를 요구하는 _d1()_ 에 확장 함수를 넘기고 있다.

---

## 1.6. 일반 확장 함수와 확장 람다에서의 다형성

아래는 일반 확장 함수인 _Base.g()_ 와 확장 람다인 _Base.h()_ 모두에서 (수신 객체의 _f_ 호출 시) 다형성이 동작함을 알 수 있다.

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

```kotlin
open class Base {
    open fun f() = 1
}

class Derived : Base() {
    override fun f() = 2
}

// 일반 확장 함수
fun Base.g() = f()

// 확장 람다
fun Base.h(x: Base.() -> Int) = x()

fun main() {
    val b: Base = Derived() // 업캐스트

    val result1 = b.g()
    val result2 = b.h { f() }

    println(result1) // 2
    println(result2) // 2
}
```

---

## 1.7. 확장 람다 대신 익명 함수 구문 사용

> 익명 함수에 대한 좀 더 상세한 내용은 [2.3. 익명 함수](https://assu10.github.io/dev/2024/02/23/kotlin-funtional-programming-3/#23-%EC%9D%B5%EB%AA%85-%ED%95%A8%EC%88%98) 를 참고하세요.

아래는 익명 람다 위치에 익명 확장 함수를 사용한 예시이다.

```kotlin
fun exec(
    arg1: Int,
    arg2: Int,
    f: Int.(Int) -> Boolean,
) = arg1.f(arg2)

fun main() {
    val result =
        exec(
            10,
            2,
            fun Int.(d: Int): Boolean { // 익명 람다 위치에 익명 확장 함수를 사용
                println("---$this") // 10
                return this % d == 0
            },
        )

    println(result) // true
}
```

---

## 1.8. 확장 람다와 사용하는 `StringBuilder` 와 `buildString()`

코틀린 표준 라이브러리는 확장 람다와 함께 사용하는 함수가 많이 있다.

`StringBuilder` 는 `toString()` 을 적용하여 불변 String 을 만들어낼 수 있는 가변 객체이다.

더 개선된 방법으로는 **확장 람다를 인자로 받는 `buildString()`** 이 있는데 **`buildString()` 은 자체적으로 `StringBuilder` 객체를 생성**하고, 
**확장 람다를 생성한 `StringBuilder` 객체에 적용한 후 `toString()` 을 호출하여 문자열**을 얻는다.

즉, `buildString()` 은 `StringBuilder` 객체를 만드는 일과 `toString()` 을 호출해주는 작업을 알아서 해준다.  
`buildString()` 의 인자는 수신 객체 지정 람다이며, 수신 객체는 항상 `StringBuilder` 가 된다.

`buildString()` 함수는 `StringBuilder` 를 활용하여 String 을 만드는 경우 사용할 수 있는 우아한 해법이다.

```kotlin
// StringBuilder 로 문자열 생성
private fun messy(): String {
    // StringBuilder 생성
    val built = StringBuilder()

    built.append("ABCs: ")

    // a~x 까지의 문자열을 덧붙임
    ('a'..'x').forEach { built.append(it) }

    // 결과 생성
    return built.toString()
}

// buildString() 으로 문자열 생성
// append() 호출의 수신 책게를 직접 만들고 관리할 필요가 없음
private fun clean(): String =
    buildString {
        append("ABCs: ")
        ('a'..'x').forEach { append(it) }
    }

// joinToString() 으로 문자열 생성
private fun cleaner(): String = ('a'..'x').joinToString(separator = "", prefix = "ABCs: ")

fun main() {
    val result1 = messy()
    val result2 = clean()
    val result3 = cleaner()

    // 모두 동일한 결과
    // ABCs: abcdefghijklmnopqrstuvwx
    println(result1)
    println(result2)
    println(result3)
}
```

---

## 1.9. `buildList()`, `buildMap()`: `forEachIndexed()`

`buildString()` 처럼 확장 람다를 사용하여 읽기 전용(=불변) List 와 Map 을 만들어주는 `buildList()`, `buildMap()` 함수도 있다.

확장 람다 안에서의 List 와 Map 은 가변이지만, **`buildList()`, `buildMap()` 의 결과는 불변**이다.

```kotlin
val characters: List<String> =
    buildList {
        add("Chars: ")
        ('a'..'d').forEach { add("$it") }
    }

val charMap: Map<Char, Int> =
    buildMap {
        ('a'..'d').forEachIndexed { n, ch -> put(ch, n) }
    }

fun main() {
    println(characters) // [Chars: , a, b, c, d]
    println(charMap) // {a=0, b=1, c=2, d=3}
}
```

---

## 1.10. 확장 람다로 빌더 작성 (빌더 패턴)

이론적으로는 필요한 모든 설정의 객체 생성자를 모두 선언할 수 있지만, 경우의 수가 너무 많으면 생성자만으로는 코드가 너무 복잡해진다.

**빌더 패턴의 장점**은 아래와 같다.  
- 여러 단계에 걸쳐 객체를 생성하므로 객체 생성이 복잡할 때 유용함
- 동일한 기본 생성 코드를 사용하여 다양한 조합의 객체 생성 가능

**확장 람다를 사용하여 빌더를 구현하면 도메인 특화 언어(DSL: Domain Specific Language) 를 만들 수 있다는 장점**도 있다.

DSL 의 목표는 프로그래머가 아닌 도메인 전문가에게 더 편하고 이해하기 쉬운 문법을 제공하는 것이다.  
이를 통해 DSL 을 둘러싼 언어의 아주 일부분만 알아도 도메인 전문가가 직접 잘 동작하는 해법을 만들어낼 수 있다.

아래는 여러 종류의 샌드위치를 조리하기 위한 재료와 절차를 담는 시스템의 예시이다.

```kotlin
// ArrayList<RecipeUnit> 을 상속
open class Recipe : ArrayList<RecipeUnit>()

open class RecipeUnit {
    override fun toString() = "${this::class.simpleName}"
}

open class Operation : RecipeUnit()
class Toast : Operation()
class Grill : Operation()
class Cut : Operation()

open class Ingredient : RecipeUnit()
class Bread : Ingredient()
class Ham : Ingredient()
class Swiss : Ingredient()
class PeanutButter : Ingredient()
class Mustard : Ingredient()

open class Sandwich : Recipe() {
    fun action(op: Operation): Sandwich {
        add(op)
        return this
    }

    fun grill() = action(Grill())
    fun toast() = action(Toast())
    fun cut() = action(Cut())
}

// fillings 확장 람다는 호출자가 Sandwich 를 여러 가지 설정으로 준비할 수 있도록 해줌
fun sandwich(fillings: Sandwich.() -> Unit): Sandwich {
    val sandwich = Sandwich()
    sandwich.add(Bread())
    sandwich.toast()
    sandwich.fillings()
    sandwich.cut()
    return sandwich
}

fun main() {
    val result1 =
        sandwich {
            add(Ham())
            add(Mustard())
        }

    val result2 =
        sandwich {
            add(Swiss())
            add(PeanutButter())
            grill()
        }

    println(result1)
    println(result2)
}
```

_fillings()_ 확장 람다는 호출자가 _Sandwich_ 를 여러 가지 설정으로 준비할 수 있도록 해주며, 사용자는 각각의 설정을 만들어내는 생성자에 대해서는 알 필요가 없다.

_result1_, _result2_ 를 보면 이 코드가 어떻게 DSL 로 사용되는지 알 수 있다.  
사용자는 _sandwich()_ 를 사용해서 _Sandwich_ 를 만드는 문법만 이해하면 된다.

---

# 2. 영역 함수 (Scope Function): `let()`, `run()`, `with()`, `apply()`, `also()`

**영역 함수**는 **객체의 이름을 사용하지 않아도 그 객체에 접근할 수 있는 임시 영역을 만들어주는 함수**로 **오로지 코드의 가독성을 위해 사용**되며, **다른 추가 기능은 제공하지 않는다.**

즉, **수신 객체를 명시하지 않고 람다의 본문 안에서 다른 객체의 메서드를 호출**할 수 있게 해준다.  
**그런 람다를 수신 지정 람다(Lambda with receiver)** 라고 한다.

**영역 함수는 단지 가독성을 높이려는 목적으로 만들어진 것이므로 영역 함수를 내포시키는 것은 좋지 않는 방식**이다.

영역 함수는 `let()`, `run()`, `with()`, `apply()`, `also()`, 총 5개로 각각 람다와 함께 사용된다.

각 영역 함수는 **문맥 객체**를 **`it` 으로 다루는지 `this` 로 다루는지**와 **각 함수가 어떤 값을 반환하는지에 따라 달라진다.**  

`with()` 만 다른 호출 문법을 사용하고, 나머지는 모두 동일한 호출 문법을 사용한다.

|                            |    `this` 문맥 객체     |  `it` 문맥 객체  |
|:---------------------------|:-------------------:|:------------:|
| 람다의 마지막 식의 값을 반환           |  `with()`, `run()`  |   `let()`    |
| 수신 객체를 반환 (변경된 객체를 다시 반환)  |      `apply()`      |   `also()`   |


**`run()` 은 확장 함수이고, `with()` 는 일반 함수**인 부분을 제외하면 두 함수는 같은 일을 한다.    
**수신 객체가 null 이 될 수 있거나, 연쇄 호출이 필요한 경우엔 `run()` 을 사용하는 것을 권장**한다.

문맥 객체를 `this` 로 접근 가능한 영역 함수인 `run()`, `with()`,`apply()` 를 사용하면 영역 블록 안에서 가장 깔끔한 구문 사용이 가능하고, 
문맥 객체를 `it` 으로 접근할 수 있는 영역 함수인 `let()`, `also()` 는 람다 인자에 이름을 붙일 수 있다.

<**각 영역 함수는 아래와 같은 상황에 따라 골라서 사용**>  
- **결과를 만들어야 하는 경우** 람다의 마지막 식의 값을 돌려주는 영역 함수인 `let()`, `run()`, `with()` 사용
- **객체에 대한 호출 식을 연쇄적으로 사용해야 하는 경우** 변경한 객체를 돌려주는 영역 함수인 `apply()`, `also()` 사용


```kotlin
data class Tag(var n: Int = 0) {
  var s: String = ""

  fun incr() = ++n
}

fun main() {
  // let() 사용 (this 로 객체 접근 불가)
  // 객체를 it 으로 접근하고, 람다의 마지막 식의 값을 반환
  val result1 =
    Tag(1).let {
      it.s = "let: ${it.n}"
      it.incr()
    }

  // let() 을 사용하면서 람다 인자에 이름을 붙임
  val result2 =
    Tag(2).let { tag ->
      tag.s = "let: ${tag.n}"
      tag.incr()
    }

  // run() 사용 (it 으로 객체 접근 불가)
  // 객체를 this 로 접근하고, 람다의 마지막 식의 값을 반환
  val result3 =
    Tag(3).run {
      s = "run: $n" // 암시적 this
      incr()
    }

  // with() 사용 (it 으로 객체 접근 불가)
  // 객체를 this 로 접근하고, 람다의 마지막 식을 반환
  val result4 =
    with(Tag(4)) {
      s = "with: $n"
      incr()
    }

  // apply() 사용 (it 으로 객체 접근 불가)
  // 객체를 this 로 접근하고, 변경된 객체를 다시 반환
  val result5 =
    Tag(5).apply {
      s = "apply: $n"
      incr()
    }

  // also() 사용 (this 로 객체 접근 불가)
  // 객체를 it 으로 접근하고, 변경된 객체를 다시 반환
  val result6 =
    Tag(6).also {
      it.s = "also: $it.n"
      it.incr()
    }

  // also() 에서도 람다의 인자에 이름을 붙일 수 있음
  val result7 =
    Tag(7).also { tag ->
      tag.s = "also: $tag.n"
      tag.incr()
    }

  println(result1) // 2
  println(result2) // 3
  println(result3) // 4
  println(result4) // 5
  println(result5) // Tag(n=6)
  println(result6) // Tag(n=7)
  println(result7) // Tag(n=8)
}
```

---

## 2.1. `with()`

`with()` 를 비롯한 다른 영역 함수들은 어떤 객체의 이름을 반복하지 않고도 그 객체에 대해 다양한 연산을 수행할 수 있도록 해준다.

아래는 `with()` 를 사용하지 않고 알파벳을 생성하는 방법의 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap05

// StringBuilder() 를 사용하여 알파벳 생성
fun alphabetWithStringBuilder(): String {
    val result = StringBuilder()
    for (letter in 'A'..'Z') {
        result.append(letter)
    }
    result.append("\nEnd~")
    return result.toString()
}

// BuildString 을 사용하여 알파벳 생성
fun alphabetWithBuildString(): String {
    val result = buildString {
        ('A'..'Z').forEach { append(it) }
        append("\nEnd~")
    }
    return result
}

// joinToString() 을 사용하여 알파벳 생성
fun alphabetWithJoinToString(): String = ('A'..'Z').joinToString(separator = "", postfix = "\nEnd~")

fun main() {
    // 결과는 모두 동일
    // ABCDEFGHIJKLMNOPQRSTUVWXYZ
    //End~
    
    println(alphabetWithStringBuilder())
    println(alphabetWithBuildString())
    println(alphabetWithJoinToString())
}
```

위 코드를 보면 매번 _result_ 를 반복하여 사용하고 있다.

아래는 `with()` 를 사용하여 알파벳을 생성하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap05

fun alphabetWith(): String {
    val result = StringBuilder()
    return with(result) {   // 메서드를 호출하려는 수신 객체 지정
        for (letter in 'A'..'Z') {
            this.append(letter) // this 를 명시해서 앞에서 지정한 수신 객체의 메서드 호출
        }
        append("\nEnd~")    // this 를 생략하고 메서드 호출
        this.toString() // 람다에서 값 반환
    }
}

fun main() {
    // ABCDEFGHIJKLMNOPQRSTUVWXYZ
    //End~
    println(alphabetWith())
}
```

위에서 `with()` 는 파라메터가 2개 있는 함수이다.  
첫 번째 파라메터는 _result_ 이고, 두 번째 파라메터는 람다이다.    
람다를 괄호 밖으로 빼내는 관례를 기억하자.

`with()` 함수는 첫 번째 인자로 받은 객체를 두 번째 인자로 받은 람다의 수신 객체로 만든다.  
인자로 받은 람다 본문에서는 `this` 를 사용하여 그 수신 객체에 접근할 수 있다.

위 예시에서 `this` 는 첫 번재 인자로 전달된 _result_ 이다.  
_result_ 의 메서드를 _this.append(letter)_ 처럼 `this` 참조를 통해 접근할 수도 있고, _append("\nEnd~")_ 처럼 바로 호출할 수도 있다.

아래는 바로 위 코드를 `with()` 와 식을 본문으로 하는 함수로 리팩토링하여 불필요한 _result_ 변수를 없애는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap05

fun alphabetWith() = with(StringBuilder()) {
    ('A'..'Z').forEach { append(it) }
    append("\nEnd~")
    toString()
}

fun main() {
    // ABCDEFGHIJKLMNOPQRSTUVWXYZ
    // End~
    println(alphabetWith())
    println(alphabetWith2())
}
```

불필요한 _result_ 변수를 없애면 _alphabetWith()_ 함수가 식의 결과를 바로 반환하게 되므로 식을 본문으로 하는 함수로 표현할 수 있다.  
`StringBuilder()` 의 인스턴스를 만들어 즉시 `with()` 에게 인자로 넘기고, 람다에서 `this` 를 사용하여 그 인스턴스를 참조한다.

만일 `with()` 에게 인자로 넘긴 객체의 클래스와 `with()` 를 사용하는 코드가 들어있는 클래스 안에 이름이 같은 메서드가 있을 경우(**= 메서드명 충돌**)엔 **`this` 참조 앞에 레이블을 붙이고 호출**하면 된다.  
예를 들어 아래와 같다.

`this` 참조 앞에 레이블을 붙이고 호출하는 예시

```kotlin
fun alphabetWith() = with(StringBuilder()) {
  ('A'..'Z').forEach { append(it) }
  append("\nEnd~")
  toString()
}

fun alphabetWith() = with(StringBuilder()) {
  ('A'..'Z').forEach { append(it) }
  append("\nEnd~")
  this@with.toString()      // this@레이블 사용
}
```

---

## 2.2. `apply()`

**`with()` 가 반환하는 값은 람다 코드를 실행한 결과이며, 그 결과는 람다 식의 본문에 있는 마지막 식의 값**이다.

만일 **람다의 결과 대신 수신 객체가 필요한 경우엔 `apply()` 나 `also()` 를 사용**하면 된다.

`apply()` 함수는 `with()` 와 거의 비슷하며, 유일한 차이는 `apply()` 는 항상 자신에게 전달된 객체 (= 수신 객체)를 반환한다는 점 뿐이다.

위에서 `with()` 를 써서 알바벳을 만드는 함수를 `apply()` 로 리팩토링하면 아래와 같다.

```kotlin
package com.assu.study.kotlin2me.chap05

// with() 사용
fun alphabetWith() = with(StringBuilder()) {
    ('A'..'Z').forEach { append(it) }
    append("\nEnd~")
    toString()
}

// apply() 사용
fun alphabetApply() = StringBuilder().apply {
  ('A'..'Z').forEach { append(it) }
  append("\nEnd~")
}.toString()

// apply() 와 buildString 사용
fun alphabetApplyWithBuildString() = buildString {
  ('A'..'Z').forEach { append(it) }
  append("\nEnd~")
}

fun main() {
    // ABCDEFGHIJKLMNOPQRSTUVWXYZ
    // End~
    println(alphabetWith())
    println(alphabetApply())
    println(alphabetApplyWithBuildString())
}
```

`with()` 와 `apply()` 는 수신 객체 지정 람다를 사용하는 일반적인 함수 중 하나이다.

수신 객체 지정 람다는 DSL (Domain Specific Language, 영역 특화 언어) 을 만들 때 매우 유용하다.

> 수신 객체 지정 람다를 DSL 정의에 사용하는 방법과 함께 수신 객체 지정 람다를 호출하는 함수를 직접 작성하는 방법에 대해서는 추후 다룰 예정입니다. (p. 241)

---

## 2.3. `let()`

null 이 될 수 있는 값을 null 이 아닌 값만 인자로 받는 함수로 넘기려면 어떻게 해야 할까?

그런 호출은 안전하지 않기 때문에 컴파일러는 그런 호출을 허용하지 않는다.

`let()` 이러한 케이스에 잘 활용할 수 있다.

`let()` 함수를 사용하면 null 이 될 수 있는 식을 쉽게 다룰 수 있다.

`let()` 함수를 안전한 호출 연산자 `?.` 와 함께 사용하면 _원하는 식을 평가 → 결과가 null 인지 검사 → 그 결과를 변수에 넣는 작업_ 을 간단한 식을 이용하여 
한꺼번에 처리할 수 있다.

`let()` 의 가장 흔한 사용 패턴은 null 이 될 수 있는 값을 null 이 아닌 값만 인자로 받는 함수에 넘기는 경우이다.

아래 에시에서 안전한 호출 연산자 `?.` 와 함께 사용된 `let()` 함수는 이메일 주소가 null 이 아닌 경우에만 호출되므로, 람다 안에서 null 이 될 수 없는 타입으로 
_email_ 을 사용할 수 있다.

`let()` 와 안전한 호출 연산자 `?.` 를 함께 사용하는 예시

```kotlin
package com.assu.study.kotlin2me.chap06

fun sendToEmail(email: String) = println("Sending email to $email")

fun main() {
  val email1: String? = "assu@test.com"

  // Sending email to assu@test.com
  email1?.let { sendToEmail(it) }

  val email2: String? = null

  // 아무일도 일어나지 않음
  email2?.let { sendToEmail(it) }
}
```

여러 값이 null 인지 검사해야 할 경우 `let()` 호출을 중첩시켜서 처리할 수 있지만 그렇게 `let()` 을 중첩시켜서 처리하면 가독성이 안 좋아진다.

이런 경우엔 일반적인 if 를 사용하여 모든 값을 한꺼번에 검사하는 것이 좋다.

---

## 2.4. 안전한 호출(`?.`) 로 영역 함수 사용: `Random.nextBoolean()`, `removeSuffix()`

> 안전한 호출(`?.`) 에 대한 좀 더 상세한 내용은 [2.1. 안전한 호출 (safe call): `?.`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#21-%EC%95%88%EC%A0%84%ED%95%9C-%ED%98%B8%EC%B6%9C-safe-call-) 을 참고하세요.

안전한 호출인 `?.` 을 사용하면 영역 함수를 null 이 될 수 있는 수신 객체에도 적용할 수 있다.  
**안전한 호출을 사용하면 수신 객체가 null 이 아닌 경우에만 영역 함수가 호출**된다.

```kotlin
import kotlin.random.Random

fun gets(): String? = if (Random.nextBoolean()) "str!" else null

fun main() {
    val result =
        gets()?.let {   // gets() 의 반환값이 null 이 아닐 때만 let 이 호출됨
            // let 에서 null 이 될 수 없는 수신 객체는 람다 내부에서 null 이 될 수 없는 it 이 됨
            it.removeSuffix("!") + it.length
        }

    println(result) // str4 or null
}
```

문맥 객체에 대해 안전한 호출 `?.` 을 적용하면 영역 함수의 영역에 들어가기에 앞서 null 검사를 수행하는데, 
만일 안전한 호출을 하지 않는다면 영역 함수 안에서 개별적으로 null 검사를 해야한다.

```kotlin
class Gnome(val name: String) {
    fun who() = "Gnome $name"
}

fun whatGnome(gnome: Gnome?) {
    gnome?.let { it.who() }
    gnome.let { it?.who() } // 영역 함수 안에서 개별적으로 null 검사

    gnome?.run { this.who() }
    gnome.run { this?.who() } // 영역 함수 안에서 개별적으로 null 검사

    gnome?.apply { who() }
    gnome.apply { this?.who() } // 영역 함수 안에서 개별적으로 null 검사

    gnome?.also { it.who() }
    gnome.also { it?.who() } // 영역 함수 안에서 개별적으로 null 검사

    // 문맥 객체인 gnome 이 null 인지 검사할 방법이 없음
    with(gnome) { this?.who() } // 영역 함수 안에서 개별적으로 null 검사
}
```

---

`let()`, `run()`, `apply()`, `also()` 에 대해 안전한 호출 `?.` 을 사용하면 수신 객체가 null 인 경우 전체 영역이 무시된다.

```kotlin
class Gnome1(val name: String) {
    fun who() = "Gnome $name"
}

fun whichGnome(gnome: Gnome1?) {
    println(gnome?.name)
    gnome?.let { println(it.who()) }
    gnome?.run { println(who()) }
    gnome?.apply { println(who()) }
    gnome?.also { println(it.who()) }
}

fun main() {
    // Assu
    // Gnome Assu
    // Gnome Assu
    // Gnome Assu
    // Gnome Assu
    whichGnome(Gnome1("Assu"))

    // null
    whichGnome(null)
}
```

---

## 2.5. Map 을 검색한 결과에 영역 함수 적용

Map 의 key 에 해당하는 원소를 찾을 수 있다는 보장이 없기 때문에 Map 에서 객체를 읽어오는 함수의 반환값도 null 이 될 수 있다.

아래는 Map 을 검색한 결과에 대해 다양한 영역 함수를 적용한 예시이다.

```kotlin
data class Toy(var id: Int)

fun display(iMap: Map<String, Toy>) {
    println("display: $iMap")

    val toy1: Toy =
        iMap["main"]?.let {
            it.id += 10
            it
        } ?: return // map 의 key 에 main 이 없으면 display() 함수를 종료시키므로 아래 로직을 실행되지 않음
    println("toy1: $toy1")

    val toy2: Toy? =
        iMap["main"]?.run {
            id += 10
            this
        }
    println("toy2: $toy2")

    val toy3: Toy? =
        iMap["main"]?.apply {
            id += 10
            this // 변경된 객체를 다시 반환하므로 의미없는 구문
        }
    println("toy3: $toy3")

    val toy4: Toy? =
        iMap["main"]?.apply {
            id += 10
        }
    println("toy4: $toy4")

    val toy5: Toy? =
        iMap["main"]?.also {
            it.id += 10
        }
    println("toy5: $toy5")
}

fun main() {
    // display: {main=Toy(id=1)}
    // toy1: Toy(id=11)
    // toy2: Toy(id=21)
    // toy3: Toy(id=31)
    // toy4: Toy(id=41)
    // toy5: Toy(id=51)
    display(mapOf("main" to Toy(1)))

    // display: {none=Toy(id=1)}
    display(mapOf("none" to Toy(1)))
}
```

> 엘비스 연산자 `?:` 에 대한 좀 더 상세한 내용은 [2.2. 엘비스(Elvis) 연산자: `?:`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#22-%EC%97%98%EB%B9%84%EC%8A%A4elvis-%EC%97%B0%EC%82%B0%EC%9E%90-)  를 참고하세요.

---

## 2.6. 연쇄 호출에서 null 이 될 수 있는 타입에 영역 함수 사용: `takeUnless()`

영역 함수는 연쇄 호출에서 null 이 될 수 있는 타입과 함께 사용할 수 있다.

```kotlin
val functions =
    listOf(
        // 익명 함수
        fun(name: String?) {
            name
                ?.takeUnless { it.isBlank() } // name 이 빈 값이 아니면 name 리턴
                ?.let { println("$it in let()") }
        },
        fun(name: String?) {
            name
                ?.takeUnless { it.isBlank() }
                ?.run { println("$this in run()") }
        },
        fun(name: String?) {
            name
                ?.takeUnless { it.isBlank() }
                ?.apply { println("$this in apply()") }
        },
        fun(name: String?) {
            name
                ?.takeUnless { it.isBlank() }
                ?.also { println("$it in also()") }
        },
    )

fun main() {
    // 아무것도 출력되지 않음
    functions.forEach { it(null) }

    // 아무것도 출력되지 않음
    functions.forEach { it(" ") }

    // AHAHAHA in let()
    // AHAHAHA in run()
    // AHAHAHA in apply()
    // AHAHAHA in also()
    functions.forEach { it("AHAHAHA") }
}
```

> 익명 함수에 대한 좀 더 상세한 내용은 [2.3. 익명 함수](https://assu10.github.io/dev/2024/02/23/kotlin-funtional-programming-3/#23-%EC%9D%B5%EB%AA%85-%ED%95%A8%EC%88%98) 를 참고하세요.

`takeUnless()` 는 predicate 가 true 이면 null 을 반환하고, false 이면 자기 자신인 this 를 반환한다.

`takeUnless()` 시그니처
```kotlin
public inline fun <T> T.takeUnless(predicate: (T) -> Boolean): T? {
    return if (!predicate(this)) this else null
}
```

---

## 2.7. 영역 함수와 자원 해제 `use()`

> 자원 해제에 대한 좀 더 상세한 내용은 [1. 자원 해제: `use()`](https://assu10.github.io/dev/2024/03/10/kotlin-error-handling-2/#1-%EC%9E%90%EC%9B%90-%ED%95%B4%EC%A0%9C-use) 를 참고하세요.

영역 함수는 자원 해제 `use()` 와 비슷한 자원 해제를 제공하지는 못한다.

```kotlin
// AutoCloseable 인터페이스 구현
data class Blob(val id: Int) : AutoCloseable {
    override fun toString() = "Blob($id)"

    override fun close() = println("Close $this")

    fun show() = println("$this")
}

fun main() {
    Blob(1).let { it.show() } // Blob(1)
    Blob(2).run { show() } // Blob(2)
    with(Blob(3)) { show() } // Blob(3)
    Blob(4).apply { show() } // Blob(4)
    Blob(5).also { it.show() } // Blob(5)

    // Blob(6)
    // Close Blob(6)
    Blob(6).use { it.show() }

    // 영역 함수를 사용하면서 자원 해제를 보장하고 싶다면 영역 함수를 use() 람다 안에 사용해야 함
    // Blob(7)
    // Close Blob(7)
    Blob(7).use { it.run { show() } }

    // 명시적으로 close() 호출
    // Blob(8)
    // Close Blob(8)
    Blob(8).apply { show() }.also { it.close() }

    // 명시적으로 close() 호출
    // Blob(9)
    // Close Blob(9)
    Blob(9).also { it.show() }.apply { close() }

    // apply() 를 사용하고 그 결과를 use() 에 전달
    // 결과를 전달받은 use() 를 람다가 끝날 때 close() 호출
    // Blob(10)
    // Close Blob(10)
    Blob(10).apply { show() }.use {}
}
```

> `use()` 는 `it` 문맥 객체를 사용하는 `let()`, `also()` 와 비슷하지만, `let()`, `also()` 와 달리 람다에서 반환을 허용하지 않음


---

## 2.8. 영역 함수의 인라인: `inline`

람다를 인자로 전달하면 람다 코드를 외부 객체에 넣기 때문에 일반 함수 호출에 비해 실행 시점의 부가 비용이 좀 더 발생하지만, 람다가 주는 신뢰성과 코드 구조 개선에 비하면 
이런 부가 비용은 크게 문제가 되지 않는다.

**영역 함수를 `inline` 으로 만들면 모든 실행 시점의 부가 비용을 없앨 수 있다.**  

**컴파일러는 `inline` 함수 호출을 보면 함수 호출 식을 함수의 본문으로 치환**하며, 이 때 함수의 모든 파라메터를 실제 제공된 인자로 바꿔준다.

**함수 실행 비용보다 함수 호출 비용이 큰, 작은 함수의 경우 `inline` 이 효과적**이다.  

반면, **함수가 커질수록** 전체 호출을 실행하는데 걸리는 시간에서 함수 호출이 차지하는 비중이 줄어들기 때문에 **`inline` 의 가치가 하락**하고, 
**함수가 크면 모든 함수 호출 지점에 함수 본문이 삽입되므로 컴파일된 전체 바이트 코드의 크기도 늘어난다.**

**인라인 함수가 람다를 인자로 받으면 컴파일러는 인라인 함수의 본문과 함께 람다 본문을 인라인**해준다.  
**따라서 인라인 함수에 람다를 전달하는 경우 클래스나 객체가 추가로 생기지 않는다.**

원하는 모든 함수에 `inline` 을 적용할 수 있지만, **일반적으로 `inline` 의 목적**은 아래와 같다.

- **함수 인자로 전달되는 람다를 인라이닝(예-영역 함수) 하거나 실체화한 제네릭스를 정의하는 것**

> 제네릭스 정의에 대한 내용은 좀 더 상세한 내용은 [Kotlin - 제네릭스 (타입 정보 보존, 제네릭 확장 함수, 타입 파라메터 제약, 타입 소거, 'reified', 타입 변성 애너테이션 ('in'/'out'), 공변과 무공변)](https://assu10.github.io/dev/2024/03/17/kotlin-advanced-2/) 을 참고하세요.

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
* [Collections 함수 2 — 필터, 조건, 검색, 맵, 플랫](https://medium.com/depayse/kotlin-collections-%ED%95%A8%EC%88%98-2-%ED%95%84%ED%84%B0-%EC%A1%B0%EA%B1%B4-%EA%B2%80%EC%83%89-%EB%A7%B5-%ED%94%8C%EB%9E%AB-f83890d21c56)
* [Collections : Filtering](https://iosroid.tistory.com/88)
* [코틀린 의 takeIf, takeUnless 는 언제 사용하는가?](https://medium.com/@limgyumin/%EC%BD%94%ED%8B%80%EB%A6%B0-%EC%9D%98-takeif-takeunless-%EB%8A%94-%EC%96%B8%EC%A0%9C-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94%EA%B0%80-f6637987780)