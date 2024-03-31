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
* [1. null 이 될 수 있는 타입](#1-null-이-될-수-있는-타입)
* [2. 안전한 호출과 엘비스 연산자](#2-안전한-호출과-엘비스-연산자)
* [3. 널 아님 단언](#3-널-아님-단언)
* [4. 확장 함수와 null 이 될 수 있는 타입](#4-확장-함수와-null-이-될-수-있는-타입)
* [5. 제네릭스](#5-제네릭스)
* [6. 확장 프로퍼티](#6-확장-프로퍼티)
* [7. break, continue](#7-break-continue)
  * [7.1.  레이블](#71-레이블)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle

---

# 1. null 이 될 수 있는 타입

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

    println(s1.length) // 3

    // 컴파일 오류
    // nullable 타입의 멤버는 참조 불가
    // println(s2.length)

    if (s2 != null) {
        println(s2.length)  // 3
    }
}
```

이렇게 명시적으로 if 문 검사를 하고 나면 코틀린은 nullable 객체를 참조하도록 허용하지만 매번 이렇게 검사를 하기엔 코드가 지저분해진다.

> 이렇게 지저분한 코드를 해결하는 간결한 구문이 있는데 이는 추후 다룰 예정입니다.

---

# 2. 안전한 호출과 엘비스 연산자

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