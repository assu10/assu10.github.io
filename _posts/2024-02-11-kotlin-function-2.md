---
layout: post
title:  "Kotlin - 함수(2)"
date:   2024-02-11
categories: dev
tags: kotlin
---

이 포스트에서는 코틀린 

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
* [3. 널 아님 단언](#3-널-아님-단언)
* [4. 확장 함수와 null 이 될 수 있는 타입](#4-확장-함수와-null-이-될-수-있는-타입)
* [5. 제네릭스](#5-제네릭스)
* [6. 확장 프로퍼티](#6-확장-프로퍼티)
* [7. break, continue](#7-break-continue)
  * [7.1. 레이블](#71-레이블)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle

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

# 3. 널 아님 단언

---

# 4. 확장 함수와 null 이 될 수 있는 타입

---

# 5. 제네릭스

---

# 6. 확장 프로퍼티

---

# 7. break, continue

---

## 7.1. 레이블

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)