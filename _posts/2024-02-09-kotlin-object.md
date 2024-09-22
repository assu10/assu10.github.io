---
layout: post
title:  "Kotlin - 객체: 생성자, 패키지, 리스트, 배열, 스프레드 연산자('*'), Set, Map, 클래스, 프로퍼티 접근자, 가시성 변경자"
date: 2024-02-09
categories: dev
tags: kotlin
---

이 포스트에서는 코틀린 객체에 대해 알아본다.

객체 지향 언어는 '명사'를 찾아내고, 이 명사를 객체로 변환한다.  
객체는 데이터를 저장하고, 동작을 수행하므로 객체 지향 언어는 객체를 만들고 사용하는 언어이다.

코틀린은 객체 지향만 지원하는 것이 아니라 함수형 언어이기도 하다.  
함수형 언어는 수행할 동작인 '동사'에 초점을 맞춘다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap02) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 생성자](#1-생성자)
* [2. 패키지](#2-패키지)
* [테스트](#테스트)
* [3. 리스트](#3-리스트)
  * [3.1. 파라메터화한 타입](#31-파라메터화한-타입)
  * [3.2. 읽기 전용과 가변 List: `listOf()`, `mutableListOf()`](#32-읽기-전용과-가변-list-listof-mutablelistof)
  * [3.3. `+=`](#33-)
* [4. 배열](#4-배열)
  * [4.1. 가변 인자 목록: `vararg`](#41-가변-인자-목록-vararg)
  * [4.2. 스프레드 연산자: `*`](#42-스프레드-연산자-)
  * [4.3. 명령줄 인자](#43-명령줄-인자)
  * [4.4. 객체의 배열과 primitive 타입의 배열](#44-객체의-배열과-primitive-타입의-배열)
    * [4.4.1. `toTypedArray()`, `toIntArray()`](#441-totypedarray-tointarray)
    * [4.4.2. primitive 타입의 배열](#442-primitive-타입의-배열)
* [5. Set](#5-set)
* [6. Map](#6-map)
  * [6.1. `getValue()`, `getOrDefault()`](#61-getvalue-getordefault)
  * [6.2. Class Instance 를 Map 으로 저장](#62-class-instance-를-map-으로-저장)
* [7. 클래스](#7-클래스)
* [8. 프로퍼티](#8-프로퍼티)
* [9. 프로퍼티 접근자: `field`](#9-프로퍼티-접근자-field)
* [10. 가시성 변경자 (access modifier, 접근 제어 변경자): `public`, `private`, `protected`, `internal`](#10-가시성-변경자-access-modifier-접근-제어-변경자-public-private-protected-internal)
  * [10.1. `pulic`](#101-pulic)
  * [10.2. `private`](#102-private)
  * [10.3. `protected`](#103-protected)
  * [10.4. `internal`](#104-internal)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 생성자

코를린에서는 객체 생성 시 `new` 키워드를 사용하지 않는다.

생성자 파라메터를 `val`, `var` 로 정의하면 해당 식별자가 프로퍼티로 바뀌며, 생성자 밖에서도 이 식별자에 접근할 수 있게 된다.

`val` 로 정의한 생성자 파라메터는 변경할 수 없고, `var` 로 정의한 생성자 파라메터는 가변 프로퍼티가 되어 변경 가능하다.

```kotlin
class Assu(name: String)
class MutableNameAssu(var name: String)
class ImmutableNameAssu(val name: String)

fun main() {
    val assu1 = Assu("assu")
    val assu2 = MutableNameAssu("assu")
    val assu3 = ImmutableNameAssu("assu")

    //assu1.name = "silby"  // 오류
    assu2.name = "silby"
    //assu3.name = "sibly"  // 오류

    //println(assu1.name)   // 오류
    println(assu2.name) // silby
    println(assu3.name) // assu
}
```

아래는 toString() 함수를 오버라이딩하는 예시이다.
```kotlin
class OverrideSample(val name: String) {
    override fun toString(): String {
        return "OverrideSample('$name')"
    }
}

fun main() {
    val overrideSample = OverrideSample("assu")
    println(overrideSample) // OverrideSample('assu')
}
```

> 생성자에 대한 좀 더 상세한 내용은 [2. 복잡한 생성자: `init`](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#2-%EB%B3%B5%EC%9E%A1%ED%95%9C-%EC%83%9D%EC%84%B1%EC%9E%90-init) 를 참고하세요.

---

# 2. 패키지

`as` 키워드를 사용하여 import 시 이름을 변경할 수 있다.  
라이브러리의 이름이 너무 길 때 유용하다.

```kotlin
import kotlin.math.PI
import kotlin.math.cos as cosine

fun main() {
    println(PI)
    println(cosine(PI))
}
```

---

# 테스트

- JUnit
  - 자바에서 가장 많이 사용되는 테스트 프레임워크로 코틀린에서도 유용함
- [코테스트(Kotest)](https://github.com/kotest/kotest)
  - 코틀린 전용 테스트 프레임워크
- [스펙(Spek) 프레임워크](https://www.spekframework.org/)
  - 명세 테스트라는 다른 형태의 테스트 제공

> 아래는 그냥 코드만 참조하자

```kotlin
// AtomicTest/AtomicTest.kt
// (c)2021 Mindview LLC. See Copyright.txt for permissions.
import kotlin.math.abs
import kotlin.reflect.KClass

const val ERROR_TAG = "[Error]: "

private fun <L, R> test(
    actual: L,
    expected: R,
    checkEquals: Boolean = true,
    predicate: () -> Boolean
) {
    println(actual)
    if (!predicate()) {
        print(ERROR_TAG)
        println(
            "$actual " +
                    (if (checkEquals) "!=" else "==") +
                    " $expected"
        )
    }
}

/**
 * this 객체의 문자열 표현을
 * `rval` 문자열과 비교한다
 */
infix fun Any.eq(rval: String) {
    test(this, rval) {
        toString().trim() == rval.trimIndent()
    }
}

/**
 * this 객체가 `rval`과 같은지 검증한다
 */
infix fun <T> T.eq(rval: T) {
    test(this, rval) {
        this == rval
    }
}

/**
 * this != `rval` 인지 검증한다
 */
infix fun <T> T.neq(rval: T) {
    test(this, rval, checkEquals = false) {
        this != rval
    }
}

/**
 * 어떤 Double 값이 rval에 지정된 Double 값과 같은지 비교한다
 * 두 값의 차이가 작은 양숫값(0.0000001)보다 작으면 두 Double을 같다고 판정한다
 */
infix fun Double.eq(rval: Double) {
    test(this, rval) {
        abs(this - rval) < 0.0000001
    }
}

/**
 * 포획한 예외 정보를 저장하는 클래스
 */
class CapturedException(
    private val exceptionClass: KClass<*>?,
    private val actualMessage: String
) {
    private val fullMessage: String
        get() {
            val className =
                exceptionClass?.simpleName ?: ""
            return className + actualMessage
        }

    infix fun eq(message: String) {
        fullMessage eq message
    }

    infix fun contains(parts: List<String>) {
        if (parts.any { it !in fullMessage }) {
            print(ERROR_TAG)
            println("Actual message: $fullMessage")
            println("Expected parts: $parts")
        }
    }

    override fun toString() = fullMessage
}

/**
 * 예외를 포획해 CapturedException에 저장한 후 돌려준다
 * 사용법
 * capture {
 * // 실패가 예상되는 코드
 * } eq "예외클래스이름: 메시지"
 */
fun capture(f: () -> Unit): CapturedException =
    try {
        f()
        CapturedException(
            null,
            "$ERROR_TAG Expected an exception"
        )
    } catch (e: Throwable) {
        CapturedException(e::class,
            (e.message?.let { ": $it" } ?: ""))
    }

/**
 * 다음과 같이 여러 trace() 호출의 출력을 누적시켜준다
 * trace("info")
 * trace(object)
 * 나중에 누적된 출력을 예상값과 비교할 수 있다
 * trace eq "expected output"
 */
object trace {
    private val trc = mutableListOf<String>()
    operator fun invoke(obj: Any?) {
        trc += obj.toString()
    }

    /**
     * trc의 내용을 여러 줄 String과 비교한다
     * 비교할 때 공백은 무시한다
     */
    infix fun eq(multiline: String) {
        val trace = trc.joinToString("\n")
        val expected = multiline.trimIndent()
            .replace("\n", " ")
        test(trace, multiline) {
            trace.replace("\n", " ") == expected
        }
        trc.clear()
    }
}
```

`a.함수(b)` 를 `a 함수 b` 로 사용할 수 있는데 이를 중위(infix) 표기법이라고 한다.  
`infix` 키워드를 붙인 함수만 중위 표기법을 사용하여 호출할 수 있다.

---

# 3. 리스트

```kotlin
import eq

fun main() {
    val ints = listOf(1, 3, 2, 4, 5)
    ints eq "[1, 3, 2, 4, 5]"

    // 각 원소 이터레이션
    var result = ""
    for (i in ints) {
        result += "$i "
    }
    result eq "1 3 2 4 5"

    // List 원소 인덱싱
    ints[4] eq 5
}
```

List 에 **`sorted()` 를 호출하면 원본의 요소들을 정렬한 새로운 List 를 리턴하고 원래의 List 는 그대로 남아있다.**    
**`sort()` 를 호출하면 원본 리스트를 변경**한다.  
reversed() 등도 마찬가지이다.
```kotlin
val strings = listOf("a", "c", "b")
println(strings)    // [a, c, b]
println(strings.sorted())   // [a, b, c]
println(strings.reversed()) // [b, c, a]
println(strings.first())    // a
println(strings.takeLast(2))    // [c, b]
```

이 외에 `take(n)` 은 리스트의 맨 앞의 n 개의 원소가 포함된 새로운 List 를 만들고, `slice(1..6)` 은 인자로 전달된 범위에 속하는 인덱스와 일치하는 위치의 원소로 이루어진 
새로운 List 를 생성한다.

---

## 3.1. 파라메터화한 타입

타입 추론은 코드를 더 깔끔하고 읽기 쉽게 만들어주기 때문에 타입 추론을 사용하는 것은 좋은 습관이지만 코드를 더 이해하기 쉽게 작성하고 싶은 경우엔 직접 타입을 명시한다.

아래는 List 타입에 저장한 원소의 타입을 지정하는 방법이다.

```kotlin
// 타입을 추론함
val numbers = listOf(1, 2, 3, "a")

// 타입을 명시함
// val numbers2: List<Int> = listOf(1, 2, 3, "a") //오류
```

위에서 `List<Int>` 에서 `<>` 를 타입 파라메터라고 한다.

---

## 3.2. 읽기 전용과 가변 List: `listOf()`, `mutableListOf()`

`listOf()` 는 불변의 리스트를 만들어 내고, `mutableListOf()` 는 가변의 리스트를 만들어 낸다.

```kotlin
// 처음에 아무 요소도 없게 정의할 때는 어느 타입의 원소를 담을 지 정의해야 함
val list = mutableListOf<Int>()

list.add(1)
list.addAll(listOf(2, 3))

println(list)   // [1, 2, 3]

list += 4
list += listOf(5, 6)    // [1, 2, 3, 4, 5, 6]

println(list)
```

List 는 읽기 전용으로 아래와 같은 상황을 유의하자.
```kotlin
// 내부적으로는 가변의 리스트를 리턴하도록 되어있지만 결과 타입이 List<Int> 로 바뀔 때 읽기 전용으로 다시 변경됨
fun getList(): List<Int> {
    return mutableListOf(1,2)
}

fun main() {
  val list = getList()
  // list += 5    // 오류
}
```

---

## 3.3. `+=`

아래와 같은 상황을 보자.
```kotlin
var list = listOf('x')  // 불변 리스트
list += 'Y' // 가변 리스트처럼 보임
println(list)   // [x, Y]
```

`listOf()` 를 통해 리스트를 생성했지만 `+=` 는 생성한 리스트를 변경하는 것처럼 보인다.  
이는 list 가 `var` 로 선언되었기 때문에 가능하다.

아래는 각각 읽기 전용 리스트와 가변 리스트를 var / val 로 선언했을 때이다.
```kotlin
var list1 = listOf('a')
list1 += 'b'
//list1.add('c')    // 오류
println(list1)  // [a, b]


val list2 = listOf('a')
//    list2 += 'b'    // 오류
//    list2.add('c')  // 오류

var list3 = mutableListOf('a')
list3 += 'b'
list3.add('c')
println(list3)  // [a, b, c]

val list4 = mutableListOf('a')
list4 += 'b'
list4.add('c')
println(list4)  // [a, b, c]
```

---

# 4. 배열

## 4.1. 가변 인자 목록: `vararg`

`vararg` 키워드는 길이가 변할 수 있는 인자의 목록을 만든다.

함수 정의에 `vararg` 로 선언된 인자는 최대 1개만 가능하며, 보통 마지막 파라메터를 `vararg` 로 선언한다.  
`vararg` 를 사용하면 함수에 0을 포함한 임의의 갯수만큼 인자를 전달할 수 있고, 이 때 **파라메터는 Array 로 취급**된다.

```kotlin
fun getList(s: String, vararg a: Int) {}

fun main() {
    getList("abc", 1, 2, 3)
    getList("abc")
    getList("abc", 1)
}
```

```kotlin
fun sum(vararg numbers: Int): Int {
    var total = 0
    for (n in numbers) {
        total += n
    }
    return total
}

println(sum(1, 2))  // 3
println(sum(1, 2, 3))   // 6
```

Array 와 List 는 비슷하지만 다르게 구현이 된다.  
List 는 일반적인 라이브러리 클래스인 반면, Array 는 자바같은 다른 언어와 호환되어야 하기 때문에 생겨난 코틀린 타입이다.

**간단한 시퀀스가 필요하면 List 를 사용하고, 서드파트 API 가 Array 를 요구하거나 `vararg` 를 다룰 때만 Array 를 쓰는 것이 좋다.**

아래는 `vararg` 가 Array 로 취급된다는 사실을 무시한 채 List 로 다룰 때의 예시이다.

```kotlin
package assu.study.kotlinme.chap02

fun evaluate(vararg ints: Int) =
  "Size: ${ints.size}\n" +
          "Sum: ${ints.sum()}\n" +
          "Average: ${ints.average()}\n"

fun evaluate2(ints: List<Int>) =
  "Size: ${ints.size}\n" +
          "Sum: ${ints.sum()}\n" +
          "Average: ${ints.average()}\n"

fun main() {
  val result1 = evaluate(1, -1, 1, 2, 3)

  // Size: 5
  // Sum: 6
  // Average: 1.2
  println(result1)

  // 컴파일 오류
//    val result2 = evaluate2(1, -1, 1, 2, 3)
//    println(result2)

  // 컴파일 오류
//    val result3 = evaluate(listOf(1, -1, 1, 2, 3))
//    println(result3)

  val result4 = evaluate2(listOf(1, -1, 1, 2, 3))

  // Size: 5
  // Sum: 6
  // Average: 1.2
  println(result4)
}
```

> 음.. 사실 이걸로 봐서는 차이를 잘 모르겠는데?

---

## 4.2. 스프레드 연산자: `*`

Array 를 만들기 위해서 `listOf()` 처럼 `arrayOf()` 를 사용한다.  
**Array 는 항상 가변 객체**이다.  


배열에 들어있는 원소를 `vararg` 로 넘길 때 코틀린과 자바의 구문이 다르다.  
자바는 배열을 그냥 넘기면 되지만, 코틀린에서는 배열을 명시적으로 풀어서 배열의 각 원소가 인자로 전달되게 해야 한다.

만일, Array 타입의 인자 하나로 넘기지 않고, 인자 목록으로 변환하고 싶으면 스프레드 연산자(`*`) 를 사용한다.  
**스프레드 연산자는 배열에만 적용**할 수 있다.

```kotlin
fun sum(vararg numbers: Int): Int {
  var total = 0
  for (n in numbers) {
    total += n
  }
  return total
}

fun main() {
    val array = intArrayOf(1, 2)
    val result = sum(1, 2, 3, *array, 6)
    println(result) // 15

//    val result2 = sum(1,2,3,array,6)  // 오류

    val list = listOf(1, 2)
    // List 를 인자 목록으로 전달하고 싶을 경우 먼저 Array 로 변환한 다음 스프레드 연산자 사용
    val result2 = sum(*list.toIntArray())
    println(result2)    // 3
    //val result3 = sum(list.toIntArray())  // 오류
}
```

JVM 에서 primitive 타입은 byte, char, short, int, long, float, boolean 이다.  
primitive 타입은 `IntArray`, `ByteArray` 등과 같은 특별한 배열 타입을 지원한다.  

반면, **Array\<Int\> 는 정수값이 담긴 Int 객체에 대한 참조를 모아둔 배열로써, IntArray 보다 훨씬 더 많은 메모리를 차지하고, 처리 속도도 늦다.**

> primitive 타입의 배열은 [4.4.2. primitive 타입의 배열](#442-primitive-타입의-배열) 에 좀 더 자세히 나옵니다.

> JVM 의 원시 타입과 참조 타입은 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

> 자바에 대응하는 코틀린이 primitive 타입은 [4.1. primitive 타입: Int, Boolean 등](https://assu10.github.io/dev/2024/02/04/kotlin-basic/#41-primitive-%ED%83%80%EC%9E%85-int-boolean-%EB%93%B1) 을 참고하세요.

만일 위 코드에서 `intArrayOf()` 가 아닌 `arrayOf()` 를 사용하면 Array\<Int\> 타입이 추론되어 오류가 발생한다.

```kotlin
val array2 = arrayOf(1, 2)
val result5 = sum(1, 2, 3, *array2, 6)  // 오류
```

```shell
Type mismatch.
Required: IntArray
Found: Array<Int>
```

따라서 **primitive 타입(Int, Double...) 의 Array 를 전달할 때는 구체적인 타입이름이 지정된 Array 생성 함수를 사용**해야 한다.

---

**스프레드 연산자는 `vararg` 로 받은 파라메터를 다시 다른 `vararg` 가 필요한 함수에 전달할 때 특히 유용**하다.

```kotlin
fun first(vararg numbers: Int): String {
    var result = ""
    for (i in numbers) {
        result += i
    }
    return result
}

//fun second(vararg numbers: Int) = first(numbers) 오류
fun second(vararg numbers: Int) = first(*numbers)


fun main() {
    val result = second(1, 2, 3)

    println(result) // 123
}
```

---

## 4.3. 명령줄 인자

명령줄 인자를 받을 땐 main() 에 지정하며, 이 때 파라메터의 타입은 꼭 Array\<String\> 이어야 한다.

```kotlin
fun main(args: Array<String>) {
    if (args.size < 3) return
    val first = args[0]
    val second = args[1].toInt()
    val third = args[2].toFloat()
    println("$first $second $third")    // dd 1 3.1
}
```

---

## 4.4. 객체의 배열과 primitive 타입의 배열

[4.1. 가변 인자 목록: `vararg`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#41-%EA%B0%80%EB%B3%80-%EC%9D%B8%EC%9E%90-%EB%AA%A9%EB%A1%9D-vararg) 에서 본 것처럼 
기본적으로는 배열보다는 컬렉션을 먼저 사용해야 한다.

하지만 자바 API 가 여전히 배열을 사용하므로 코틀린에서도 배열을 써야할 때가 있는데 여기서는 코틀린에서 배열을 다루는 방법에 대해 알아본다.

아래는 코틀린 배열의 기본적인 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

fun main() {
    val arr: Array<String> = arrayOf("a", "b")

// 배열의 인덱스 값 범위에 대해 이터레이션 하기 위해 array.indices 확장 함수 사용
    for (i in arr.indices) {
        println("arg $i is : ${arr[i]}")
    }

    // arg 0 is : a
    // arg 1 is : b
}
```

코틀린 배열은 타입 파라메터를 받는 클래스이다.

배열의 원소 타입은 바로 그 타입 파라메터에 의해 정해진다.

<**코틀린에서 배열 생성하는 법**>  
- `arrayOf()` 에 원소를 넘김
- `arrayOfNulls()` 함수에 정수값을 인자로 넘기면 모든 원소가 null 이고, 인자로 넘긴 값과 크기가 같은 배열 생성 가능
  - 원소 타입이 null 이 될 수 있는 타입인 경우에만 이 함수 사용 가능
- `Array` 생성자는 배열 크기와 람다를 인자로 받아서 람다를 호출하여 각 배열 원소를 초기화함
  - `arrayOf()` 를 사용하지 않고 각 원소가 null 이 아닌 배열을 만들어야 하는 경우 이 생성자를 사용함
  - 예) _Array\<String\>(2) { // ... }_

아래는 `Array` 생성자를 이용하여 a~z 까지 알파벳 소문자에 해당하는 문자열이 원소인 배열을 생성하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

fun main() {
    val letters = Array<String>(26) { i -> ('a' + i).toString() }

    // [Ljava.lang.String;@3b07d329
    println(letters)

    // abcdefghijklmnopqrstuvwxyz
    println(letters.joinToString(""))
}
```

람다는 배열 원소의 인덱스를 인자로 받아서 배열의 해당 위치에 들어갈 원소를 반환한다.

---

### 4.4.1. `toTypedArray()`, `toIntArray()`

코틀린은 배열을 인자로 받는 자바 함수를 호출하거나 `vararg` 파라메터를 받는 코틀린 함수를 호출하기 위해 배열을 만드는 경우가 많다.  
하지만 이 때 데이터가 이미 컬렉션에 들어있다면 컬렉션을 배열로 변환해야 한다.

이 때 **`toTypedArray()` 를 사용하면 쉽게 컬렉션을 배열**로 바꿀 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap06

fun sum(vararg numbers: Int): Int {
    var total = 0
    for (n in numbers) {
        total += n
    }
    return total
}

fun main() {
    val strings = listOf("a", "b", "c")
    val numbers = listOf(1, 2, 3)

    // vararg 인자를 넘기기 위해 스프레드 연산자 * 사용
    println("%s %s %s".format(*strings.toTypedArray()))

    println("%s %s %s".format(*numbers.toTypedArray()))

    // 컴파일 오류
    // println("%d %d %d".format(*numbers.toIntArray()))

    // 컴파일 오류
    // Type mismatch.
    // Required: IntArray
    // Found: Array<Int>
    
    //sum(*numbers.toTypedArray())

    sum(*numbers.toIntArray())
}
```

원소의 타입이 Int 일 경우 `toTypedArray()` 는 Array\<Int\> 를 반환하고, `toIntArray()` 는 `IntArray` 를 반환한다.

---

### 4.4.2. primitive 타입의 배열

다른 제네릭 타입처럼 배열 타입의 타입 파라메터도 항상 객체 타입이다.

따라서 Array\<Int\> 와 같은 타입은 선언하면 그 배열은 boxing 된 정수의 배열이다.  
(자바 타입은 java.lang.Integer[])

boxing 하지 않은 primitive 타입의 배열이 필요하면 그런 타입을 위한 특별한 배열 클래스를 사용해야 한다.

> boxing 과 unboxing 에 대해서는 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

코틀린은 primitive 타입의 배열을 표현하는 별도 클래스를 각 primitive 타입마다 하나씩 제공한다.  
예) `IntArray`, `ByteArray`, `CharArray`, `BooleanArray` ..

이런 **primitive 타입 배열은 자바의 primitive 타입 배열인 int[], byte[], char[] 등으로 컴파일되기 때문에 boxing 하지 않고 가장 효율적인 방식으로 저장**된다.

<**primitive 배열 생성하는 법**>  
- 각 배열 타입의 생성자는 size 인자를 받아서 해당 primitive 타입의 디폴트 값 (보통은 0) 으로 초기화된 size 크기의 배열 반환
- 팩토리 함수 (`IntArray` 를 생성하는 `intArrayOf()` 등) 는 여러 값을 가변 인자로 받아서 그런 값이 들어간 배열을 반환
- (일반 배열처럼) 크기와 람다를 인자로 받는 생성자를 사용

아래는 위의 3 가지 방법으로 primitive 배열을 생성하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

fun main() {
    // 각 배열 타입의 생성자는 size 인자를 받아서 해당 primitive 타입의 디폴트 값 (보통은 0) 으로 초기화된 size 크기의 배열 반환
    val fiveZeros: IntArray = IntArray(5)

    // 팩토리 함수 intArrayOf() 사용
    val fiveZeros2: IntArray = intArrayOf(0, 0, 0, 0, 0)

    // 크기와 람다를 인자로 받는 생성자를 사용
    val fiveZeros3: IntArray = IntArray(5) { i -> i + 1 }

    println(fiveZeros) // [I@53d8d10a
    println(fiveZeros2) // [I@e9e54c2
    println(fiveZeros3) // [I@65ab7765

    println(fiveZeros.joinToString()) // 0, 0, 0, 0, 0
    println(fiveZeros2.joinToString()) // 0, 0, 0, 0, 0
    println(fiveZeros3.joinToString()) // 1, 2, 3, 4, 5
}
```

**boxing 된 값이 들어있는 컬렉션이나 배열이 있다면 `toIntArray()` 등의 변환 함수를 사용하여 unboxing 된 값이 들어있는 배열로 변환**할 수 있다.

코틀린 표준 라이브러리는 배열의 기본 연산 (배열 길이 구하기, 원소 설정 등) 에 더해 컬렉션에 사용할 수 있는 모든 확장 함수를 배열에도 제공한다.

따라서 `filter()`, `map()` 등을 배열에서도 사용할 수 있다.

primitive 배열로 이루어진 배열에도 이런 확장 함수를 동일하게 사용할 수 있다.

**단, 이런 확장 함수가 반환하는 값은 배열이 아니라 리스트**이다.

이제 [4.4. 객체의 배열과 primitive 타입의 배열](#442-primitive-타입의-배열) 에서 만들어 본 알파벳을 `forEachIndexed()` 와 람다를 사용하여 출력해보자.

4.4. 객체의 배열과 primitive 타입의 배열 에서 만들어 본 알파벳

```kotlin
package com.assu.study.kotlin2me.chap06

fun main() {
    val letters = Array<String>(26) { i -> ('a' + i).toString() }

    // [Ljava.lang.String;@3b07d329
    println(letters)

    // abcdefghijklmnopqrstuvwxyz
    println(letters.joinToString(""))
}
```

`forEachIndexed()` 는 배열의 모든 원소를 갖고 인자로 받은 람다를 호출해주는데 이 때 배열의 원소와 그 원소의 인덱스를 람다에게 인자로 전달한다.

```kotlin
package com.assu.study.kotlin2me.chap06

fun main() {
    val letters = Array<String>(26) { i -> ('a' + i).toString() }

    letters.forEachIndexed { index, s -> println("$index is $s") }
}
```

---

# 5. Set

`Set` 은 각각의 값이 중복되지 않는 컬렉션이다.

immutable Set 이 필요하면 `setOf()` 를 사용하면 되고, mutable Set 이 필요하면 `mutableSetOf()` 를 사용하면 된다.

일반적인 Set 연산은 `in` 이나 `contains()` 를 사용하여 원소 포함 여부를 검사하는 것이다.

```kotlin
fun main() {
    // 중복이 제거됨
    val set1 = setOf(1, 1, 2, 2, 3, 3)
    println(set1)   // [1,2,3]

    var set2 = setOf(2, 2, 1, 1, 3, 3)
    println(set2)   // [2,3,1]

    // 원소의 순서는 중요하지 않음
    val setEq = set1 == set2
    println(setEq)  // true

    // 원소인지 검사
    val containsSet1 = 1 in set1
    val containsSet2 = 7 in set1

    println(containsSet1)   // true
    println(containsSet2)   // false

    // 한 집합이 다른 집합을 포함하는지 여부 확인
    val containsSet3 = set1.containsAll(setOf(1, 3))
    println(containsSet3)   // true

    // 합집합
    val unionSet = set1.union(setOf(3, 4))
    println(unionSet)   // [1,2,3,4]

    // 교집합
    val intersectSet = set1.intersect(setOf(3, 4))
    println(intersectSet)   // [3]

    // 차집합
    val subtractSet = set1.subtract(setOf(3, 4))
    println(subtractSet)    // [1,2]
  
    val subtractSet2 = set1 - setOf(3, 4)
    println(subtractSet2)   // [1,2]
}
```

**List 에서 중복을 제거하려면 Set 으로 변환**하면 된다.

```kotlin
fun main() {
    val list = listOf(2, 2, 1, 1, 3)
    val set2 = list.toSet()
    println(list)   // [2,2,1,1,1]
    println(set2)   // [2,1,3]

    val list2 = list.distinct()
    println(list2)  // [2,1,3]

    val set3 = "baacc".toSet();
    val set4 = setOf('b', 'a', 'c')
    val result = set3 == set4
    println(result) // true
}
```

List 와 마찬가지로 +=, -= 연산자를 이용해서 Set 에 원소를 추가/삭제 가능하다.

```kotlin
fun main() {
    val mutableSet = mutableSetOf<Int>()
    mutableSet += 1
    mutableSet += 3
    println(mutableSet) // [1,3]
    mutableSet -= 1
    println(mutableSet) // [1]
}
```

---

# 6. Map

key-value 쌍을 `mapOf()` 에 전달하여 Map 을 생성할 수 있다. key 와 value 를 분리하려면 `to` 를 사용한다. 

immutable Map 이 필요하면 `mapOf()` 를 사용하면 되고, mutable Map 이 필요하면 `mutableMapOf()` 를 사용하면 된다.

```kotlin
fun main() {
    // map 생성
    val constantMap = mapOf(
        "one" to 1,
        "two" to 2,
        "three" to 3
    )

    println(constantMap)    // {one=1, two=2, three=3}

    println(constantMap["two"]) // 2

    // Map 에서 key 는 유일하기 때문에 keys 를 호출하면 Set 이 생성됨
    println(constantMap.keys == setOf("one", "two", "three"))   // true
    println(constantMap.keys == setOf("one", "three", "two"))   // true
    println(constantMap.values) // [1,2,3]
    println(constantMap.values == listOf(1, 2, 3))  // false
    println(constantMap.values == arrayOf(1, 2, 3)) // false
    //println(constantMap.values == [1, 2, 3])  // 오류, Unsupported [Collection literals outside of annotations]

    // map iteration
    var string = ""
    for (entry in constantMap) {
        string += "${entry.key}:${entry.value}"
    }
    println(string) // one:1 two:2 three:3

    // map 을 iteration 하면서 키와 값을 분리
    var string2 = ""
    for ((key, value) in constantMap) {
        string2 += "${key}:${value} "
    }
    println(string2)    // one:1 two:2 three:3
}
```

아래는 += 를 통해 Map 에 원소를 추가하는 예시이다.
```kotlin
fun main() {
    val mutableMap = mutableMapOf(1 to "one", 2 to "two")

    println(mutableMap[2])  // two

    mutableMap[2] = "twotwo"
    println(mutableMap[2])  // twotwo

    mutableMap += 3 to "three"
    println(mutableMap) // {1=one, 2=twotwo, 3=three}

    val result = mutableMap == mapOf(1 to "one", 2 to "twotwo", 3 to "three")
    val result2 = mutableMap == mapOf(1 to "one", 3 to "three", 2 to "twotwo")
    println(result) // true
    println(result2)    // true
}
```

아래는 immutable Map 에 대한 예시이다.
```kotlin
fun main() {
    val immutableMap = mapOf(1 to "one", 2 to "two")

    // immutableMap[1] = "oneone"   // 오류

    // immutableMap += (3 to "three)"    // 오류

    // immutableMap 을 바꾸지 않음
    immutableMap + (3 to "three")
    println(immutableMap)   // {1=one, 2=two}

    val immutableMap2 = immutableMap + (3 to "three")
    // immutableMap2[3] = "dd" 오류
    println(immutableMap2)  // {1=one, 2=two, 3=three}
}
```

## 6.1. `getValue()`, `getOrDefault()`

주어진 key 에 포함되어 있지 않은 원소를 조회하면 Map 은 null 을 반환한다.  
null 이 될 수 없는 값을 원하면 `getValue()` 를 사용하는 것이 좋다.  
`getValue()` 를 사용할 때 key 가 맵에 없으면 _NoSuchElementException_ 이 런타임에 발생한다.

하지만 이 오류는 런타임에 발생하므로 `getOrDefault()` 를 이용하여 null 혹은 예외를 던지지 않도록 하는 것이 좋다.

```kotlin
fun main() {
    val map = mapOf('a' to "aaa")
    println(map['b'])   // null
    //println(map.getValue('b'))  // runtime error: NoSuchElementException

    println(map.getOrDefault('a', "bb"))    // aaa
    println(map.getOrDefault('b', "bb"))    // bb
}
```

---

## 6.2. Class Instance 를 Map 으로 저장

아래는 클래스 인스턴스를 Map 으로 저장하는 예시이다.
```kotlin
class Contact(val name: String, val phone: String) {
    override fun toString(): String {
        return "Contact('$name', '$phone')"
    }
}

fun main() {
    val assu = Contact("Assu", "111-2222-3333")
    val silby = Contact("Silby", "555-6666-7777")

    val contacts = mapOf(
        assu.phone to assu,
        silby.phone to silby
    )

    println(contacts["111-2222-3333"])  // Contact('Assu', '111-2222-3333')
    println(contacts["555-6666-7777"])  // Contact('Silby', '555-6666-7777')
    println(contacts["000-0000-0000"])  // null
}
```

---

# 7. 클래스

아래와 같은 java 파일의 클래스가 있다.
```java
package com.assu.study.kotlin2me.chap02;

public class Person {
  private final String name;

  public Person(String name) {
    this.name = name;
  }

  public String getName() {
    return name;
  }
}
```

intelliJ 의 `[Code] > [Convert Java File to Kotlin File]` 를 사용하여 위 클래스를 코틀린으로 변경하면 아래와 같다.
```kotlin
package com.assu.study.kotlin2me.chap02

class Person(val name: String)
```

위처럼 **코드없이 데이터만 저장하는 클래스를 값 객체** 라고 한다.

자바 코드와 비교해보면 클래스에 public 가시성 변경자가 없음을 확인할 수 있다.  
**코틀린의 기본 가시성은 public 이므로 이럴 경우 변경자 생략이 가능**하다.

> 인터페이스, 복잡한 생성자 `init`, 부생성자 `constructor`, 상속, 기반 클래스 초기화에 대한 내용은 [Kotlin - 객체 지향 프로그래밍(1): 인터페이스, SAM(fun interface), init, 부생성자, 상속, 기반클래스 초기화](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/) 를 참고하세요.
> 
> 클래스 위임 `by`, 캐스트 `is`/`as`/`as?`, 봉인된 클래스 `sealed` 에 대한 내용은 [Kotlin - 객체 지향 프로그래밍(3): 클래스 위임, 상속/합성/클래스 위임, 다운 캐스트('is', 'as'), 봉인된 클래스('sealed')](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/) 를 참고하세요.
> 
> 내부 클래스에 대한 내용은 [2. 내부 클래스 (inner class)](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#2-%EB%82%B4%EB%B6%80-%ED%81%B4%EB%9E%98%EC%8A%A4-inner-class) 를 참고하세요.
> 
> 내부 클래스와 내포된 클래스에 대한 내용은 [3. 내부 클래스 (inner class) 와 내포된 클래스 (nested class)](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#3-%EB%82%B4%EB%B6%80-%ED%81%B4%EB%9E%98%EC%8A%A4-inner-class-%EC%99%80-%EB%82%B4%ED%8F%AC%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-nested-class) 를 참고하세요.
> 
> 추상 클래스, 업캐스트, 합성, 상속과 확장에 대한 내용은 [Kotlin - 객체 지향 프로그래밍(2): 추상 클래스, 업캐스트, 다형성, 합성, 합성과 상속, 상속과 확장, 어댑터 패턴, 멤버 함수와 확장 함수](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/) 를 참고하세요.

> 가시성에 대한 내용은 [10. 가시성 변경자 (access modifier, 접근 제어 변경자): `public`, `private`, `protected`, `internal`](#10-가시성-변경자-access-modifier-접근-제어-변경자-public-private-protected-internal) 에 나옵니다.

---

# 8. 프로퍼티

클래스의 목적은 데이터를 캡슐화하는 것이다.

자바에서는 데이터를 필드에 저장하고, 그 데이터에 접근하는 통로로 사용하는 접근자 메서드를 제공한다.

이 **필드와 접근자를 프로퍼티**라고 한다.

```kotlin
package com.assu.study.kotlin2me.chap02

class Person2(
  val name: String, // 읽기 전용 프로퍼티, 비공개 필드와 getter 생성
  var isMarried: Boolean, // 쓰기 가능 프로퍼티, 비공개 필드와 공개 getter/setter 생성
)

fun main(args: Array<String>) {
  // new 키워드를 사용하지 않음
  val person = Person2("Assu", true)

  // 프로퍼티 이름을 직접 사용해도 코틀린이 자동으로 getter 를 호출해줌
  println(person.name)    // Assu
  println(person.isMarried)   // true
}
```

위 코드를 보면 getter 를 호출하는 대신 프로퍼티를 직접 사용하였다.

**대부분의 프로퍼티에는 그 프로퍼티 값을 저장하기 위한 필드**가 있는데 이를 **backing field** 라고 한다.  
원한다면 커스텀 getter 를 작성하여 프로퍼티 값을 그때그때 계산할 수도 있다.

> `lateinit` 변경자를 널이 될 수 없는 프로퍼티에 지정하면 프로퍼티를 생성자가 호출된 다음에 초기화한다는 의미이다.  
> 이에 대한 상세한 내용은 [2.1. `lateinit`](https://assu10.github.io/dev/2024/03/30/kotlin-advanced-5/#21-lateinit) 을 참고하세요.

> 요청이 들어오면 비로소 초기화되는 지연 초기화 (lazy initialized) 프로퍼티는 더 일반적인 위임 프로퍼티의 일종이다.  
> 위임 프로퍼티 및 지연 초기화 프로퍼티에 대해서는 추후 다룰 예정입니다. (p. 171)

> 자바 프레임워크와의 호환성을 위해 자바의 특징을 코틀린에서 에뮬레이션하는 애너테이션을 활용할 수 있다.
> 
> 예를 들어 `@JvmField` 애너테이션을 프로퍼티에 붙이면 접근자가 없는 public 필드를 노출시켜 준다.  
> 애너테이션에 대해서는 추후 다룰 예정입니다. (p. 171)

> `const` 변경자를 사용하면 애너테이션을 더 편하게 다룰 수 있고, primitive 타입이나 String 타입인 값을 애너테이션의 인자로 활용할 수 있다.  
> 이에 대해서는 추후 다룰 예정입니다. (p. 171)

---

# 9. 프로퍼티 접근자: `field`

아래와 같은 방식으로 프로퍼티에 접근할 수도 있지만, 여기서는 getter, setter 를 정의하여 프로퍼티 읽기와 쓰기를 커스텀화해본다.

```kotlin
class Data(var i: Int)

fun main() {
    val data = Data(1)
    println(data.i) // 1
    data.i = 2
    println(data.i) // 2
}
```

getter, setter 는 정의한 프로퍼티 바로 뒤에 `get()`, `set()` 를 정의하여 사용할 수 있다.  
getter, setter 안에서는 `field` 라는 이름을 사용하여 저장된 값에 직접 접근할 수 있으며, 이 `field` 라는 이름은 getter, setter 안에서만 접근할 수 있는 이름이다.

```kotlin
class Default {
    var i: Int = 0
        get() { // 프로퍼티 getter 선언
            println("get()")
            return field
        }
        set(value) {
            println("set()")
            field = value
        }
}

fun main() {
    val d = Default()
    d.i = 2 // set() 찍힘
    println(d.i)    // get(), 2 찍힘

}
```

아래는 getter 는 디폴트 구현, setter 는 값의 변화를 추적하는 예시이다.

```kotlin
class LogChanges {
    var n: Int = 0
        set(value) {
            println("$field becomes $value")    // 0 becomes 2
            field = value
        }
}

fun main() {
    val lc = LogChanges()
    println(lc.n)   // 0

    lc.n = 2
    println(lc.n)   // 2
}
```

```shell
0
0 becomes 2
2
```

**아래는 getter 는 public, setter 는 private 로 지정**하는 예시이다.  
그러면 프로퍼티값을 변경하는 일은 클래스 내부에서만 할 수 있다.

```kotlin
class Counter {
    var value: Int = 0
        private set

    fun inc() = value++
}

fun main() {
    val counter = Counter()
    repeat(10) {
        counter.inc()
    }
    println(counter.value)  // 10
}
```

일반적으로 프로퍼티는 값을 필드에 저장하지만, 필드가 없는 프로퍼티를 정의할 수도 있다.

```kotlin
class Hamster(val name: String)

class Cage(private val maxCapacity: Int) {
    private val hamsters = mutableListOf<Hamster>()
  // 내부에 저장된 상태가 없고 접근이 이루어질 때 결과를 계산해서 돌려줌
    val capacity: Int
        get() = maxCapacity - hamsters.size
  // 내부에 저장된 상태가 없고 접근이 이루어질 때 결과를 계산해서 돌려줌
    val full: Boolean
        get() = hamsters.size == maxCapacity

    fun put(hamster: Hamster): Boolean =
        if (full)
            false
        else {
            hamsters += hamster
            true
        }

    fun take(): Hamster = hamsters.removeAt(0)
}

fun main() {
    val cage = Cage(2)
    println(cage.full)  // false

    println(cage.put(Hamster("Assu")))  // true
    println(cage.put(Hamster("Silby")))  // true
    println(cage.full)  // true

    println(cage.capacity)  // 0

    println(cage.put(Hamster("ddd")))   // false

    println(cage.take())

    println(cage.capacity)  // 1
}
```

---

# 10. 가시성 변경자 (access modifier, 접근 제어 변경자): `public`, `private`, `protected`, `internal`

소프트웨어를 설계할 때 우선적으로 고려해야 할 내용은 **변화해야 하는 요소와 동일하게 유지되어야 하는 요소를 분리**하는 것이다.

`public`, `private`, `protected`, `internal` 가시성 변경자는 클래스, 함수, 프로퍼티 정의 앞에 사용하며 접근할 수 있는 범위에 대해 결정한다.

|       변경자        | 클래스 멤버             | 최상위 선언            |
|:----------------:|:-------------------|:------------------|
| `public` (기본 가시성) | 모든 곳에서 볼 수 있음      | 모든 곳에서 볼 수 있음     |
|     `internal`     | 같은 모듈 안에서만 볼 수 있음  | 같은 모듈 안에서만 볼 수 있음 |
|    `protected`     | 하위 클래스 안에서만 볼 수 있음 | (최상위 선언에 적용 불가)   |
|     `private`      | 같은 클래스 안에서만 볼 수 있음 | 같은 파일 안에서만 볼 수 있음 |


> 자바에서는 같은 패키지 안에서 `protected` 멤버에 접근 가능하지만, 코틀린은 패키지가 아닌 하위 클래스에서만 접근 가능함

> 코틀린과 자바 가시성 규칙의 또 다른 차이는 코틀린에서는 외부 클래스가 내부 클래스(inner class)나 중첩(내포)된 클래스의 `private`, `protected` 멤버에 접근할 수 없다는 점임  
> 
> 내부 클래스(inner class) 에 대한 상세한 내용은 [2. 내부 클래스 (inner class)](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#2-%EB%82%B4%EB%B6%80-%ED%81%B4%EB%9E%98%EC%8A%A4-inner-class) 를 참고하세요.  
> 
> 내포(중첩)된 클래스에 대한 상세한 내용은 [2. 내포된 클래스 (nested class)](https://assu10.github.io/dev/2024/03/02/kotlin-object-oriented-programming-4/#2-%EB%82%B4%ED%8F%AC%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-nested-class) 를 참고하세요.

아래는 가시성 규칙을 위반하여 컴파일 오류가 발생하는 예시이다.
```kotlin
interface Focusable1 {
    fun setFocus(b: Boolean) = println("I ${if (b) "got" else "lost"} focus.")

    // 디폴트 구현이 있는 메서드
    fun showOff() = println("I'm focusable!")
}

// 같은 모듈 안에서만 볼 수 있는 클래스
internal open class TalkActiveButton: Focusable1 {
    // 같은 클래스 안에서만 볼 수 있는 멤버
    private fun yell() = println("yell~")
    
    // 하위 클래스 안에서만 볼 수 있는 멤버
    protected fun whisper() = println("whisper~")
}

// 오류: 'public' member exposes its 'internal' receiver type TalkActiveButton
// 오류: public 멤버가 자신의 internal 수신 타입인 TalkActiveButton 을 노출
fun TalkActiveButton.giveSpeech() { 
    // 오류: Cannot access 'yell': it is private in 'TalkActiveButton'
    // 오류: yell() 은 TalkActiveButton 의 private 멤버임
    yell()
    
    // 오류: Cannot access 'whisper': it is protected in 'TalkActiveButton'
    // 오류: whisper() 는 TalkActiveButton 의 protected 멤버임
    whisper()
}
```

위 코드에서 public 함수인 _giveSpeech()_ 안에서 그보다 가시성이 더 낮은 internal 타입인 _TalkActiveButton_ 을 참조하지 못하기 때문에 오류가 발생한다.  
이 말은 **어떤 클래스의 기반 타입 목록에 들어있는 타입이나 제네릭 클래스의 타입 파라메터에 들어있는 타입의 가시성은 그 클래스 자신의 가시성과 같거나 더 높아야 하고, 
메서드의 시그니처에 사용된 모든 타입의 가시성은 그 메서드의 가시성과 같거나 더 높아야 한다는 의미**이다.

위에서 오류를 해결하려면 _giveSpeech()_ 의 가시성을 `internal` 로 변경하거나, _TalkActiveButton_ 클래스의 가시성을 `public` 으로 변경하면 된다.

---

## 10.1. `pulic`

`public` 으로 선언하면 직접적으로 접근이 가능하기 때문에 `public` 으로 선언된 정의를 변경하면 이를 이용하는 코드에도 직접적으로 영향을 끼친다.

**변경자를 지정하지 않으면 정의한 대상은 자동으로 `public`** 이 되므로 `public` 변경자를 불필요한 중복이다.

---

## 10.2. `private`

`private` 로 선언하면 같은 클래스에 속한 다른 멤버들만 접근이 가능하므로 정의를 변경하거나 심지어 삭제하더라도 이를 이용하는 코드에 직접적인 영향이 없다.

`private` 이 붙은 클래스, 최상위 함수, 최상위 프로퍼티는 그 정의가 들어있는 파일 내부에서만 접근이 가능하다.

`private` 클래스, 최상위 함수, 최상위 프로퍼티의 예시 코드
```kotlin
// 다른 파일에서 접근 불가
private var index = 0

// 다른 파일에서 접근 불가
private class Animal(
    val name: String,
)

// 다른 파일에서 접근 불가
private fun recordAnimal(animal: Animal) {
    println("Animal #$index: ${animal.name}~")
    index++
}

fun recordAnimals() {
    recordAnimal(Animal("AA"))
    recordAnimal(Animal("BB"))
}

fun recordAnimalsCount() {
    println("$index here~")
}

fun main() {
    // Animal #0: AA~
    // Animal #1: BB~
    recordAnimals()

    // 2 here~
    recordAnimalsCount()
}
```

클래스 내부에서 `private` 를 사용할 경우 예시 코드
```kotlin
class Cookie(
    private var isReady: Boolean,   // private 프로퍼티로 클래스 밖에서는 접근 불가
) {
    // private 멤버 함수
    private fun crumble() = println("crumble~")

    // public 멤버 함수로 public 은 불필요한 중복
    public fun bite() = println("bite")

    // 접근 변경자가 없으면 public
    fun eat() {
        isReady = true  // 같은 클래스의 멤버만 private 멤버에 접근 가능
        crumble()
        bite()
    }
}
```

`private` 를 사용하면 같은 패키지 안의 다른 클래스에 영향을 주지 않으면서 코드 변경이 가능하다.

클래스 내의 `private` 프로퍼티 측면에서도 내부 구현을 노출시켜야 하는 경우를 제외하고는 프로퍼티를 `private` 로 만드는 것이 좋다.  
(내부 프로퍼티를 외부로 노출시켜야 하는 경우는 매우 드뭄)

클래스 내부에 있는 참조를 `private` 로 정의한다해도 그 참조가 가리키는 객체에 대한 `public` 참조가 없다는 사실을 보장해주지 못하는 예시 코드
```kotlin
class Counter(
    var start: Int,
) {
    fun incr() {
        start += 1
    }

    override fun toString() = start.toString()
}

class CounterHolder(
    counter: Counter,
) {
    private val ctr = counter

    override fun toString() = "CounterHolder: $ctr~"
}

fun main() {
    // 아랫줄의 CountHolder 객체 생성을 둘러싸고 있는 영역 안에 정의됨
    val c = Counter(11)
    
    // c 를 CounterHolder 생성자의 인자로 전달하는 것은 새로 생긴 CountHolder 객체가 c 가 가리키는 Counter 객체와 
    // 똑같은 객체를 참조할 수 있다는 의미임
    val ch = CounterHolder(c)

    // CounterHolder: 11~
    println(ch)

    // ch 안에서는 여전에 private 로 인식되는 Counter 를 여전히 c 를 통해 조작 가능
    c.incr()

    // CounterHolder: 12~
    println(ch)

    // CounterHolder 안에 있는 ctr 외에는 Counter(9) 를 가리키는 참조가 존재하지 않으므로 
    // ch2 를 제외한 그 누구도 이 객체를 조작할 수 없음
    val ch2 = CounterHolder(Counter(9))

    // CounterHolder: 9~
    println(ch2)
}
```

위처럼 **한 객체에 대해 참조를 여러 개 유지하는 경우를 에일리어싱(aliasing)** 이라고 한다.

---

## 10.3. `protected`

> `protected` 에 대한 내용은 [4.2. 상속과 오버라이드](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#42-%EC%83%81%EC%86%8D%EA%B3%BC-%EC%98%A4%EB%B2%84%EB%9D%BC%EC%9D%B4%EB%93%9C) 를 참고하세요.

---

## 10.4. `internal`

대부분의 프로젝트는 모듈로 분리되어 있다.  
모듈은 코드 기반상에서 논리적으로 독립적인 각 부분을 뜻하며 코드를 모듈로 나누는 방법은 빌드 시스템(Gradle, Maven..) 에 따라 달라진다.

**`internal` 은 그 정의가 포함된 모듈 내부에서만 접근 가능**하다.

요소를 `private` 로 정의하기엔 제약이 너무 심하고, `public` 으로 정의하여 공개 API 의 일부분으로 포함시키기 애매할 경우 `internal` 을 사용하면 된다.

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
* [Kotest](https://github.com/kotest/kotest)
* [Spek Framework](https://www.spekframework.org/)