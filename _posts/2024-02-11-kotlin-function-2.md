---
layout: post
title:  "Kotlin - 함수(2): null 이 될 수 있는 타입, 안전한 호출, 엘비스 연산자, 널 아님 단언, 확장 함수, 제네릭스, 확장 프로퍼티"
date: 2024-02-11
categories: dev
tags: kotlin
---

이 포스트에서는 코틀린 함수 기능에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap03) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. null 이 될 수 있는 타입: `?`](#1-null-이-될-수-있는-타입-)
  * [1.1. nullable 타입의 역참조](#11-nullable-타입의-역참조)
* [2. 안전한 호출(safe call)과 엘비스(Elvis) 연산자](#2-안전한-호출safe-call과-엘비스elvis-연산자)
  * [2.1. 안전한 호출 (safe call): `?.`](#21-안전한-호출-safe-call-)
  * [2.2. 엘비스(Elvis) 연산자: `?:`](#22-엘비스elvis-연산자-)
  * [2.3. 안전한 호출 (`?.`) 로 여러 호출을 연쇄](#23-안전한-호출--로-여러-호출을-연쇄)
* [3. 널 아님 단언: `!!`](#3-널-아님-단언-)
* [4. 확장 함수와 null 이 될 수 있는 타입](#4-확장-함수와-null-이-될-수-있는-타입)
  * [4.1. 확장 함수 사용: `isNullOrEmpty()`, `isNullOrBlank()`](#41-확장-함수-사용-isnullorempty-isnullorblank)
  * [4.2. 비확장 함수 표현](#42-비확장-함수-표현)
  * [4.3. `this` 를 사용한 확장 함수 표현](#43-this-를-사용한-확장-함수-표현)
* [5. 제네릭스](#5-제네릭스)
  * [5.1. 하나의 타입 파라메터를 받는 클래스](#51-하나의-타입-파라메터를-받는-클래스)
  * [5.2. 제네릭 타입 파라메터를 받는 클래스: `<T>`](#52-제네릭-타입-파라메터를-받는-클래스-t)
  * [5.3. universal type: `Any`](#53-universal-type-any)
  * [5.4. 제네릭 함수](#54-제네릭-함수)
  * [5.5. 코틀린에서 제공하는 컬렉션을 위한 제네릭 함수](#55-코틀린에서-제공하는-컬렉션을-위한-제네릭-함수)
* [6. 확장 프로퍼티](#6-확장-프로퍼티)
  * [6.1. 기본 확장 프로퍼티](#61-기본-확장-프로퍼티)
  * [6.2. 제네릭 확장 프로퍼티](#62-제네릭-확장-프로퍼티)
  * [6.3. 스타 프로젝션(star projection): `*`](#63-스타-프로젝션star-projection-)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. null 이 될 수 있는 타입: `?`

```kotlin
fun main() {
    val map = mapOf(0 to "yes", 1 to "no")
    println(map[2]) // null
}
```

위와 같은 경우 null 이 리턴이 되는데 null 을 정상적인 값과 같은 방식으로 다루면 예상치 못한 오류가 발생할 수 있다.  

이 문제의 해법 중 하나는 애초에 null 을 허용하지 않는 것인데 코틀린은 자바와 상호 작용하므로 자바에서 null 이 있기 때문에 애초에 null 을 허용하지 않을 수가 없다.

따라서 애초에 null 을 허용하지 않는 대신 null 이 될 수 있는 타입이라고 선언하여 처리가 가능하다.

코틀린의 모든 타입은 기본적으로 null 이 될 수 없는 타입인데 null 의 결과가 나올 수 있는 변수라면 타입 이름 뒤에 물음표 (`?`) 를 붙영서 결과가 null 이 될 수도 있음을 표시해야 한다.

```kotlin
fun main() {
    // null 참조 아님
    val s1 = "abc"

    // 컴파일 오류 (Null can not be a value of a non-null type String)
    // null 이 될 수 없는 타입인 String 타입의 값으로 null 지정 불가
    // val s2:String = null

    // null 이 될 수 있는 변수들
    val s3: String? = null
    val s4: String? = s1
    
    // 컴파일 오류
    // null 이 될 수 있는 타입의 식별자를 null 이 될 수 없는 타입의 식별자에 대입 불가
    //val s5: String = s4
    
    // 타입 추론을 하면 코틀린이 적당한 타입을 만들어 냄
    // s4 가 nullable 이므로 s6 도 nullable 타입이 됨
    val s6 = s4
}
```

위에서 `String` 과 `String?` 은 서로 다른 타입이다. 

Map 에 각괄호를 사용하여 값을 가져오면 nullable 의 결과를 얻을 수 있다. 각괄호에 해당하는 연산의 기저 구현인 자바 코드가 null 을 돌려주기 때문이다.

```kotlin
fun main() {
    val map = mapOf(0 to "yes", 1 to "no")

    // 컴파일 오류
    // Type mismatch. Required: String  Found:String?
    // val first: String = map[0]

    val first: String? = map[0]
    val second: String? = map[2]

    println(first)  // yes
    println(second) // null
}
```

---

## 1.1. nullable 타입의 역참조

코틀린에서는 nullable 타입을 역참조할 수 없다. (= 멤버 프로퍼티나 멤버 함수에 접근 불가)

```kotlin
fun main() {
    val s1: String = "abc"
    val s2: String? = s1

    println(s1.length) //3

    // 컴파일 오류
    // nullable 타입의 멤버는 참조 불가
    // println(s2.length)
}
```

대부분 타입의 값은 메모리에 있는 객체에 대한 참조로 저장되는데 역참조가 바로 이런 의미이다.  
객체에 접근하기 위해서는 메모리에서 객체를 가져와야 한다.

nullable 타입을 역참조해도 NullPointerException 이 발생하지 않도록 보장하는 가장 단순한 방법은 명시적으로 참조가 null 인지 검사하는 것이다.

바로 위 코드를 아래와 같이 하면 s2 를 역참조할 수 있다.
```kotlin
fun main() {
  val s1: String = "abc"
  val s2: String? = s1
  val s3: String? = null
  val s4: String? = "abc"

  println(s1.length) // 3

  // 컴파일 오류
  // nullable 타입의 멤버는 참조 불가
  // println(s2.length)

  if (s2 != null) {
    println(s2.length) // 3
  }

  // 컴파일 오류
  // Only safe (?.) or non-null asserted (!!.) calls are allowed on a nullable receiver of type String?
  // String? 타입의 nullable 수신 객체에는 안전한 (?.) 호출이나 널이 아닌 단언(!!.) 호출만 가능
  // println(s3.length)

  // 컴파일 오류
  // Only safe (?.) or non-null asserted (!!.) calls are allowed on a nullable receiver of type String?
  // String? 타입의 nullable 수신 객체에는 안전한 (?.) 호출이나 널이 아닌 단언(!!.) 호출만 가능
  // println(s4.length)
}
```

이렇게 명시적으로 if 문 검사를 하고 나면 코틀린은 nullable 객체를 참조하도록 허용하지만 매번 이렇게 검사를 하기엔 코드가 지저분해진다.

이렇게 지저분한 코드를 해결하는 간결한 구문은 [2. 안전한 호출(safe call)과 엘비스(Elvis) 연산자](#2-안전한-호출safe-call과-엘비스elvis-연산자) 를 참고하세요.

---

# 2. 안전한 호출(safe call)과 엘비스(Elvis) 연산자

## 2.1. 안전한 호출 (safe call): `?.`

안전한 호출은 `?.` 와 같이 표기한다.    
**안전한 호출 `?.` 을 사용하면 수신 객체가 null 이 아닐 때만 연산을 수행하기 때문에 nullable 타입의 멤버에 접근하면서 NPE 도 발생하지 않게 해준다.**

```kotlin
// 확장 함수
fun String.echo() {
    println(uppercase())
    println(this)
    println(lowercase())
}

fun main() {
    val s1: String? = "Abcde"

    // 컴파일 오류
    // Only safe (?.) or non-null asserted (!!.) calls are allowed on a nullable receiver of type String?
    // s1.echo()

    // 안전한 호출인 ?. 사용
    s1?.echo()
    // ABCDE
    // Abcde
    // abcde

    val s2: String? = null
    
    // 안전한 호출인 ?. 사용
    // s2 의 수신 객체가 null 이므로 아무 일도 수행하지 않음
    s2?.echo()
}
```

아래 코드를 보면 if 문을 사용할 때보다 안전한 호출인 `?.` 를 이용할 때 좀 더 코드가 깔끔해지는 것을 확인할 수 있다.
```kotlin
fun checkLength(
  s: String?,
  expected: Int?,
) {
  // if 문으로 null 검사
  val length1 =
    if (s != null) s.length else null

  // 안전한 호출 ?. 로 검사
  val length2 = s?.length

  println(length1 == expected)
  println(length2 == expected)
}

fun main() {
  checkLength("abc", 3) // true   true
  checkLength(null, null) // true  true
}
```

---

## 2.2. 엘비스(Elvis) 연산자: `?:`

수신 객체가 null 일 경우 `?.` 로 null 을 리턴하는 것 이상의 일이 필요할 경우엔 Elvis 연산자인 `?:` 를 사용한다.

아래 예시를 보자.

```kotlin
fun main() {
    val s1: String? = "abc"

    // s1 이 null 이 아니므로 abc 출력
    println(s1 ?: "ddd")    // abc

    val s2: String? = null
    
    // s2 가 null 이므로 ddd 출력
    println(s2 ?: "ddd")    // ddd
}
```

**보통은 아래 예시처럼 안전한 호출이 null 수신 객체에 대해 만들어내는 null 대신 디폴트 값을 제공하기 위해 Elvis 연산자 (`?:`) 를 안전한 호출 (`?.`) 다음에 사용**한다.

```kotlin
fun checkLength2(
  s: String?,
  expected: Int,
) {
  // if 문으로 null 검사
  val length1 =
    if (s != null) s.length else 0

  // 안전한 호출 ?. 과 Elvis 연산자 ?: 로 검사
  val length2 = s?.length ?: 0

  println(length1 == expected)
  println(length2 == expected)
}

fun main() {
  checkLength2("abc", 3) // true  true
  checkLength2(null, 0) // true  true
}
```

---

## 2.3. 안전한 호출 (`?.`) 로 여러 호출을 연쇄

연쇄 호출 중간에 null 이 결과로 나올 수도 있는데 최종 결과에만 관심이 있는 경우 `?.` 을 사용하여 여러 호출을 간결하게 연쇄시킬 수 있다.

```kotlin
class Person(
    val name: String,
    var friend: Person? = null,
)

fun main() {
    val assu = Person("Assu")

    // assu.friend 프로퍼티가 null 이므로 나머지 호출도 null 리턴
    println(assu.friend?.friend?.name) // null
    println(assu.friend?.name) // null

    val silby = Person("Silby")
    val kamang = Person("Kamang", silby)

    silby.friend = kamang

    println(silby.friend?.name) // Kamang
    println(silby.friend?.friend?.name) // Silby

    println(assu.friend?.friend?.name ?: "NONO") // NONO
    println(silby.friend?.name ?: "NONO2") // Kamang
    println(silby.friend?.friend?.name ?: "NONO2") // Silby
}
```

---

# 3. 널 아님 단언: `!!`

**null 이 될 수 없는 변수임을 보증할 때는 `!!` 를 변수 뒤에 선언**한다.

**가장 좋은 방법은 항상 안전한 호출(`?.`) 자세한 예외를 반환하는 특별한 함수를 사용**하는 것이다.  
**null 이 아니라는 점을 단언하는 호출인 `!!` 은 꼭 필요할 때만 사용**하는 것이 좋다.

`a!!` 는 a 가 null 이 아니면 a 값을 리턴하고, null 이면 오류를 발생시킨다.

```kotlin
fun main() {
  val x: String? = "abc"

  println(x!!) // abc

  val a: String? = null
  // println(a!!) // NullPointException

  val b: String = a!!
  println(b)  // NPE
}
```

일반적으로 `!!` 를 그냥 쓰는 경우는 거의 없고, 보통 역참조와 함께 사용한다.

```kotlin
fun main() {
    val s: String? = "abc"

    println(s!!.length) // 3
}
```

**`!!` 사용보다는 안전한 호출(`?.`) 이나 명시적인 null 검사를 활용하는 것이 좋다.**  
아래는 Map 에 특정 key 가 꼭 존재해야 하고, key 가 없을 경우 아무 일도 일어나지 않는 것보다 예외를 발생시키는 것이 
좋다고 가정하는 예시이다.  

value 를 일반적인 방법인 각괄호로 읽지 않고 `getValue()` 로 읽으면 key 가 없는 경우 NoSuchElementException 이 발생한다.

```kotlin
fun main() {
    val map = mapOf(1 to "one")

    println(map[1]!!.uppercase()) // ONE
    println(map.getValue(1).uppercase()) // ONE

    // println(map[2]!!.uppercase()) // NPE

    // NoSuchElementException 과 같이 구체적인 예외를 던지는 것이 더 유용한 정보를 얻을 수 있음
    // println(map.getValue(2).uppercase()) // NoSuchElementException
}
```

---

# 4. 확장 함수와 null 이 될 수 있는 타입

## 4.1. 확장 함수 사용: `isNullOrEmpty()`, `isNullOrBlank()`

[안전한 호출](#21-안전한-호출-safe-call-) 을 사용한 _s?.f()_ 는 s 가 null 이 될 수 있는 타입임을 암시한다.  
비슷하게 t.f() 는 t 가 null 이 될 수 없는 타임을 암시하는 것처럼 보이지만 꼭 t 가 null 이 될 수 없는 타입인 것은 아니다.

코틀린 표준 라이브러리는 아래의 String 확장 함수를 제공한다.

- `isNullOrEmpty()`
  - 수신 String 이 null 이거나 빈 문자열인지 검사
- `isNullOrBlank()`
  - `isNullOrEmpty()` 와 같은 검사를 수행
  - 수신 객체 String 이 온전히 공백 문자 (탭인 `\t` 와 새 줄 `\n` 도 포함) 로만 구성되어 있는지도 검사

```kotlin
fun main() {
    val s1: String? = null
    println(s1.isNullOrEmpty()) // true
    println(s1.isNullOrBlank()) // true

    val s2 = ""
    println(s2.isNullOrEmpty()) // true
    println(s2.isNullOrBlank()) // true

    val s3 = "  \t\n"
    println(s3.isNullOrEmpty()) // false
    println(s3.isNullOrBlank()) // true

    val s4 = "abc"
    println(s4.isNullOrEmpty()) // false
    println(s4.isNullOrBlank()) // false
}
```

---

## 4.2. 비확장 함수 표현

위에서 `isNullOrEmpty()` 를 null 이 될 수 있는 String? s 를 받는 비확장 함수로 다시 작성할 수 있다.

```kotlin
// s 가 null 이 될 수 있는 타입이므로 명시적으로 null 여부 확인과 빈 문자열 검사 가능
// || 는 쇼트 쇼킷을 이용한 것으로, 첫 번째 식이 true 이면 전체 식이 true 로 결정되므로 두 번째 식은 아예 검사하지 않음
// 따라서 s 가 null 이어도 NPE 가 발생하지 않음
fun isNullOrEmpty(s: String?): Boolean = s == null || s.isEmpty()

fun main() {
    println(isNullOrEmpty(null))    // true
    println(isNullOrEmpty(""))  // true
}
```

---

## 4.3. `this` 를 사용한 확장 함수 표현

확장 함수는 `this` 를 사용하여 수신 객체 (확장 대상 타입에 속하는 객체) 를 표현하는데, 이 때 수신 객체를 null 이 될 수 있는 타입으로 지정하려면 확장 대상 타입 뒤에 `?` 를 붙이면 된다.

[4.2. 비확장 함수 표현](#42-비확장-함수-표현) 의 함수를 아래와 같이 사용할 수 있다.

```kotlin
// this 를 사용한 확장 함수 표현
fun String?.isNullOrEmpty(): Boolean = this == null || isEmpty()

fun main() {
    println(null.isNullOrEmpty()) // true
    println("".isNullOrEmpty()) // true
}
```

이전에 비해 확장 함수로 표현한 것이 좀 더 가독성이 좋다.

null 이 될 수 있는 타입을 확장할 때는 조심할 부분이 있다.  
**`isNullOrEmpty()` 같이 단순하고 함수 이름에서 수신 객체가 null 일 수 있음을 암시하는 경우에는 null 이 될 수 있는 타입의 확장 함수가 유용**하지만 
**일반적으로는 보통(null 이 될 수 없는)의 확장(=비확장) 을 정의**하는 편이 낫다.

**안전한 호출(`?.`) 과 명시적인 검사는 null 가능성을 명백히 드러내지만 null 이 될 수 있는 타입의 확장 함수는 null 가능성을 감추고 가독성이 떨어지기 때문**이다.

---

# 5. 제네릭스

> 제네릭스에 대한 좀 더 상세한 내용은 [Kotlin - 제네릭스 (타입 정보 보존, 제네릭 확장 함수, 타입 파라메터 제약, 타입 소거, 'reified', 타입 변성 애너테이션 ('in'/'out'), 공변과 무공변)](https://assu10.github.io/dev/2024/03/17/kotlin-advanced-2/) 를 참고하세요.

## 5.1. 하나의 타입 파라메터를 받는 클래스

제네릭스는 파라메터화한 타입을 만들어 여러 타입에 대해 작동할 수 있는 컴포넌트이다.

아래는 객체를 하나만 담는 클래스의 예시이다. 이 클래스는 저장할 원소의 정확한 타입을 지정한다.

> 클래스의 파라메터를 private 로 지정하는 것에 대한 설명은 [9. 프로퍼티 접근자: `field`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90-field) 를 참고하세요.

```kotlin
data class Automobile(val brand: String)

// Automobile 밖에 받지 못하므로 재사용성이 좋지 않음
class RigidHolder(private val a: Automobile) {
    fun getValue() = a
}

fun main() {
    val holder = RigidHolder(Automobile("BMW"))
    println(holder.getValue())  // Automobile(brand=BMW)
}
```

---

## 5.2. 제네릭 타입 파라메터를 받는 클래스: `<T>`

위의 RigidHolder 는 Automobile 밖에 받지 못하기 때문에 재사용성이 좋지 않다.  
여러 다른 타입에 대해 각 타입에 맞는 새로운 타입의 보관소 클래스를 만들면 재사용성이 높아질 수 있다. 이를 위해 Automobile 대신 타입 파라메터를 사용하면 된다.

**제네릭 타입 정의는 클래스 이름 뒤에 내부에 하나 이상의 제네릭 placeholder 가 들어있는 `<>` 를 추가**하면 된다.

```kotlin
class GenericHolder<T>(private val a: T) {
    fun getValue(): T = a
}

fun main() {
    val h1 = GenericHolder(Automobile("BMW"))
    val a1: Automobile = h1.getValue()
    println(a1) // Automobile(brand=BMW)

    val h2 = GenericHolder(1)
    val a2: Int = h2.getValue()
    println(a2) // 1

    val h3 = GenericHolder("Assu")
    val a3: String = h3.getValue()
    println(a3) // Assu
}
```

---

## 5.3. universal type: `Any`

[5.1. 하나의 타입 파라메터를 받는 클래스](#51-하나의-타입-파라메터를-받는-클래스) 의 문제를 제네릭 타입이 아닌 유니버셜 타입(universal type) 인 `Any` 로 해결할 수도 있다.

```kotlin
class AnyHolder(private val a: Any) {
    fun getValue(): Any = a
}

data class Automobile2(val brand: String)

class Dog {
    fun bark() = "Ruff!!"
}

fun main() {
    val h1 = AnyHolder(Automobile2("BMW"))
    val a1 = h1.getValue()
    println(a1) // Automobile2(brand=BMW)

    // Any 로 선언한 클래스 호출
    val h2 = AnyHolder(Dog())
    val a2 = h2.getValue()
    println(a2) // assu.study.kotlinme.chap03.generics.Dog@34c45dca
    // 컴파일 되지 않음
    // println(a2.bark())

    // 제네릭으로 선언한 클래스 호출
    val h3 = GenericHolder(Dog())
    val a3 = h3.getValue()
    println(a3) // assu.study.kotlinme.chap03.generics.Dog@5b6f7412
    println(a3.bark())  // Ruff!!
}
```

간단한 경우엔 `Any` 가 작동하지만 Dog 의 bark() 같이 구체적인 타입이 필요해지면 `Any` 는 제대로 동작하지 않는다.  
객체를 Any 타입으로 대입하면서 객체 타입이 Dog 라는 사실을 더 이상 추적할 수 없기 때문이다.  
Dog 를 Any 로 전달하면 결과는 그냥 Any 이고, Any 는 bark() 를 제공하지 않는다.

하지만 제네릭스를 사용하면 실제 컬렉션에 Dog 를 담고 있는 정보를 유지할 수 있기 때문에 getValue() 가 돌려주는 값에 대하여 bark() 를 적용할 수 있다.

---

## 5.4. 제네릭 함수

**제네릭 함수를 정의하려면 `<>` 로 둘러싼 제네릭 타입 파라메터를 함수 이름 앞에 붙이면 된다.**

```kotlin
fun <T> identity(arg: T): T = arg

fun main() {
    println(identity("AA")) // AA
    println(identity(1))    // 1

    // identity() 가 T 타입의 값을 반환하는 제네릭 함수이기 때문에 d 는 Dog 타입임
    var d: Dog = identity(Dog())
    println(d)  // assu.study.kotlinme.chap03.generics.Dog@27d6c5e0
}
```

---

## 5.5. 코틀린에서 제공하는 컬렉션을 위한 제네릭 함수

코트린 표준 라이브러리는 컬렉션을 위한 여러 제네릭 함수를 제공하는데, 제네릭 확장 함수를 사용하려면 수신 객체 앞에 제네릭 명세(괄호로 둘러싼 타입 파라메터 목록)을 위치시키면 된다.

아래에서 `first()` 와 `firstOrNull()` 의 정의를 살펴보자.

```kotlin
fun <T> List<T>.first(): T {
    if (isEmpty()) {
        throw NoSuchElementException("Empty~")
    }
    return this[0]
}

fun <T> List<T>.firstOrNull(): T? =
    if (isEmpty()) null else this[0]


fun main() {
    println(listOf(1, 2, 3).first())    // 1

    val i: Int? = listOf(1, 2, 3).firstOrNull()
    println(i)  // 1

    // Exception in thread "main" java.util.NoSuchElementException: Empty~
    // val i2: Int? = listOf<Int>().first()
    //  println(i2)

    val s: String? = listOf<String>().firstOrNull()
    println(s)  // null

    // Exception in thread "main" java.util.NoSuchElementException: Empty~
    //val s2: String? = listOf<String>().first()
    // println(s2)
}
```

---

# 6. 확장 프로퍼티

## 6.1. 기본 확장 프로퍼티

[확장 함수](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#1-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-extension-function)를 정의할 수 있는 것처럼 
확장 프로퍼티를 정의할 수도 있다.

프로퍼티라고는 하지만 상태를 저장할 적절한 방법이 없기 때문에 (기존 클래스의 인스턴스 객체에 필드를 추가할 방법은 없으므로) 실제로 확장 프로퍼티는 아무런 상태도 가질 수 없다.  
마찬가지로 초기화 코드에서 계산한 값을 담을 장소가 없으므로 초기화 코드도 사용할 수 없다.

확장 프로퍼티의 수신 객체 타입을 지정하는 방법도 확장 함수와 비슷하게 확장 대상 타입이 함수나 프로퍼티 이름 바로 앞에 온다.

```kotlin
// 확장 함수
fun ReceiveType.extensionFunction() { ... }

// 확장 프로퍼티
val ReceiveType.extentionProperty: PropType
  get() { ... }
```

**확장 프로퍼티에는 커스텀 getter 가 필요**한데, **확장 프로퍼티에 접근할 때마다 프로퍼티 값이 계산**된다.  

val 로 선언되어 getter 만 있는 프로퍼티
```kotlin
// 확장 프로퍼티 선언
val String.indices: IntRange
    get() = 0 until length

fun main() {
    println("abc".indices)  // 0..2
}
```

var 로 선언되어 getter/setter 가 있는 프로퍼티
```kotlin
package com.assu.study.kotlin2me.chap03

var StringBuilder.lastChar: Char
    get() = get(length - 1) // 프로퍼티 게터
    set(value: Char) {
        this.setCharAt(length - 1, value) // 프로퍼티 세터
    }

fun main() {
    var sb = StringBuilder("Hello?")
    sb.lastChar = '!'
    println(sb)
}
```

**파라메터가 없는 확장 함수는 항상 확장 프로퍼티로 변환할 수 있지만, 기능이 단순하고 가독성을 향상시키는 경우에만 프로퍼티를 권장**한다.

[코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html) 에서는 함수가 예외를 던질 경우 프로퍼티보다는 함수를 사용하는 것을 권장한다.

---

## 6.2. 제네릭 확장 프로퍼티

아래는 [5.5. 코틀린에서 제공하는 컬렉션을 위한 제네릭 함수](#55-코틀린에서-제공하는-컬렉션을-위한-제네릭-함수) 에 나온 firstOrNull() 함수를 프로퍼티로 구현한 예시이다.

```kotlin
// 확장 함수
fun <T> List<T>.firstOrNull(): T? =
    if (isEmpty()) null else this[0]

// 확장 프로퍼티
val <T> List<T>.firstOrNull: T?
    get() = if (isEmpty()) null else this[0]

fun main() {
    println(listOf(1, 2, 3))    // [1, 2, 3]
    println(listOf<Int>().firstOrNull()) // 확장 함수, null
    println(listOf<Int>().firstOrNull)  // 확장 프로퍼티, null
}
```

---

## 6.3. 스타 프로젝션(star projection): `*`

제네릭 인자 타입을 사용하지 않는다면 스타 프로젝션(star projection) `*` 로 대신할 수 있다.

```kotlin
val List<*>.indices: IntRange
    get() = 0 until size

fun main() {
    println(listOf(1).indices)  // 0..0
    println(listOf('a', 'b').indices)   // 0..1
    println(emptyList<Int>().indices)   // 0..-1
    println(emptyList<Int>().indices.equals(IntRange.EMPTY))    // true
}
```

List<\*\> 를 사용하면 List 에 담긴 원소의 타입 정보를 모두 잃어버리므로 List<\*\> 에서 얻은 원소는 `Any?` 에만 대입할 수 있다.  
List<\*\> 에 저장된 값이 null 이 될 수 있는지 없는지에 대한 타입 정보가 없기 때문에 `Any?` 타입의 변수에만 대입이 가능하다.

```kotlin
fun main() {
    val list: List<*> = listOf(1, 2, 3)
    val any: Any? = list[0]
    println(any)  // 1

    // Type mismatch. Required:Int  Found:Any?
    //val a: Int = list[0]
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