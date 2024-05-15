---
layout: post
title:  "Kotlin - 지연 계산 초기화('lazy()'), 늦은 초기화('lateinit', '.isInitialized')"
date:   2024-03-30
categories: dev
tags: kotlin laze() lateinit .isInitialized
---

이 포스트에서는 지연 계산 초기화와 늦은 초기화에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 지연(lazy) 계산 초기화: `lazy()`](#1-지연lazy-계산-초기화-lazy)
  * [1.1. 3가지 프로퍼티 초기화 방법 비교](#11-3가지-프로퍼티-초기화-방법-비교)
* [2. 늦은(late) 초기화](#2-늦은late-초기화)
  * [2.1. `lateinit`](#21-lateinit)
  * [2.2. `.isInitialized`](#22-isinitialized)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle

---

# 1. 지연(lazy) 계산 초기화: `lazy()`

프로퍼티를 초기화하는 방법은 총 3가지가 있다.

- 프로퍼티를 정의하는 시점이나 생성자 안에서 초기값 저장
- 프로퍼티에 접근할 때마다 값을 계산하는 custom getter() 정의
- 지연 계산 초기화 사용

초기값을 계산하는 비용이 많이 들지만 프로퍼티를 선언하는 시점에 즉시 필요하지 않거나 아예 필요하지 않을 수도 있는 경우가 있다ㅣ.

- 복잡하고 시간이 오래 걸리는 계산
- 네트워크 요청
- DB 접근

이런 프로퍼티를 생성 시점에 즉시 초기화하면 아래와 같은 문제가 발생할 수 있다.

- 애플리케이션 초기 시작 시간이 길어짐
- 전혀 사용하지 않거나 나중에 계산해도 될 프로퍼티 값을 계산하기 위해 불필요한 작업을 수행

이런 문제를 해결하기 위해 **지연 계산 프로퍼티는 생성 시점이 아닌 처음 사용할 때 초기화**된다.  
지연 계산 프로퍼티를 사용하면 **그 프로퍼티의 값을 읽기 전까지는** 비싼 초기화 계산을 수행하지 않는다.

코틀린은 [프로퍼티 위임](https://assu10.github.io/dev/2024/03/24/kotlin-advanced-4/#1-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%9C%84%EC%9E%84-by) 을 사용하여 
일관성있고 가독성이 좋은 지연 계산 프로퍼티 구문을 제공하는데, `by` 다음에 `lazy()` 를 붙여주면 된다.

```kotlin
val lazyProp by lazy { 초기화 코드 }
```

**`lazy()` 는 초기화 로직이 들어있는 람다**로, 항상 그랬듯 **람다의 마지막 식이 결과값이 되고, 프로퍼티에 저장**된다.

```kotlin
// 이 프로퍼티를 읽는 곳이 없으므로 결코 초기화되지 않음
val idle: String by lazy {
    println("initializing idle lazy~")
    "I'm never used~"
}

val helpful: String by lazy {
    println("initializing helpful lazy~")
    "I'm helpful~"
}

fun main() {
    // initializing helpful lazy~
    // I'm helpful~
    println(helpful)
}
```

_helpful_, _idle_ 모두 val 로 선언되어 있다. lazy 초기화가 없다면 이 프로퍼티들은 var 로 선언해야 하기 때문에 신뢰성이 덜 한 코드가 된다.

---

## 1.1. 3가지 프로퍼티 초기화 방법 비교

아래는 프로퍼티를 초기화하는 3 가지 방법인 정의 시점, getter(), 지연 계산을 비교한 예시이다.

```kotlin
fun compute(i: Int): Int {
    println("compute $i")
    return i
}

object Properties {
    val atDefinition = compute(1)
    val getter
        get() = compute(2)
    val lazyInit by lazy { compute(3) }
    val never by lazy { compute(4) }
}

fun main() {
    // atDefinition 은 Properties 의 인스턴스를 생성할 때 초기화됨

    // compute 1  - atDefinition: 보다 먼저 출력이 되었다는 건 초기화가 프로퍼티 접근 이전에 발생했다는 의미
    // atDefinition:
    // 1:
    // 1::

    // getter 는 프로퍼티에 접근할 때마다 getter 가 계산되므로 compute 가 2번 출력됨

    // getter:
    // compute 2
    // 2:
    // compute 2
    // 2::

    // lazyInit 프로퍼티에 처음 접근할 때 한번만 초기화가 계산됨

    // lazyInit:
    // compute 3
    // 3:
    // 3::
    listOf(
        Properties::atDefinition,
        Properties::getter,
        Properties::lazyInit,
    ).forEach {
        println("${it.name}:")
        println("${it.get()}:")
        println("${it.get()}::")
    }
}
```

> object 에 대한 좀 더 상세한 내용은 [1. object](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#1-object) 를 참고하세요.

---

# 2. 늦은(late) 초기화

상황에 따라 지연 계산 초기화 `by lazy()` 를 사용하지 않고 별도의 멤버 함수에서 클래스의 인스턴스가 생성된 후에 프로퍼티를 초기화해야 하는 경우도 있다.

예를 들어 라이브러리가 특별한 함수 안에서 초기화를 해야한다고 요구할 수도 있다.  
이런 라이브러리의 클래스를 확장하는 경우 개발자가 직접 특별한 함수의 자체 구현을 제공할 수 있다.

아래와 같이 인스턴스를 초기화하는 _setUp()_ 메서드가 정의된 인터페이스가 있다고 해보자.

```kotlin
interface Bag {
    fun setUp()
}
```

위의 _Bag_ 을 초기화하고 조작하면서 _setUp()_ 의 호출을 보장해주는 라이브러리가 있고, 이 라이브러리를 재사용해야 하는 상황에서 
이 라이브러리는 _Bag_ 의 생성자에서 프로퍼티를 초기화하지 않기 때문에 파생 클래스가 반드시 _setUp()_ 안에서 초기화를 해야한다고 요구한다고 가정해보자.

```kotlin
interface Bag {
    fun setUp()
}

class SuiteCase : Bag {
    private var items: String? = null

    // setUp() 을 오버라이드하여 items 초기화
    override fun setUp() {
        items = "aaa, bbb, ccc"
    }

    fun ckeckItems(): Boolean = items?.contains("aaa") ?: false
}
```

_SuiteCase_ 에서 _setUp()_ 을 오버라이드하여 _items_ 를 초기화하는데 **_items_ 를 그냥 String 으로 정의할 수는 없다.**    
**_items_ 를 String 타입으로 정의한다면 생성자에서 null 이 아닌 초기값으로 _items_ 를 초기화**해야 하는데 
**빈 문자열 같은 특별한 값으로 초기화하는 것은 진짜 초기화가 되었는지 알 수 없기 때문에 나쁜 방식**이다.  
null 은 _items_ 가 초기화되지 않았음을 표시한다.

**_items_ 를 null 이 될 수 있는 String? 으로 선언하면 _checkItems()_ 처럼 모든 멤버 함수에서 null 검사**를 해야한다.  
여기서 재사용중인 라이브러리를 _setUp()_ 을 호출하여 _items_ 를 초기화해주기 때문에 **매번 null 검사를 하는 것은 불필요한 작업**이다.

---

## 2.1. `lateinit`

`lateinit` 프로퍼티는 위와 같이 매번 null 검사를 해야하는 문제를 해결해준다.

아래는 _BatterSuiteCase_ 의 **인스턴스를 생성한 후에 _items_ 를 초기화**한다.

**`lateinit` 을 사용한다는 말을 프로퍼티를 안전하게 null 이 아닌 프로퍼티로 선언해도 된다는 의미**이다.

```kotlin
interface Bag1 {
    fun setUp()
}

class BetterSuitcase : Bag1 {
    // String? 이 아닌 String 타입으로 정의
    lateinit var items: String

    override fun setUp() {
        items = "aaa, bbb, ccc"
    }

    // null 검사를 하지 않음
    fun checkItems(): Boolean = "aaa" in items
}

fun main() {
    val suitcase = BetterSuitcase()
    suitcase.setUp()

    println(suitcase.checkItems()) // true
}
```

<**`lateinit` 의 제약 사항**>  
- 클래스 본문과 최상위 영역이나 지역에 정의된 var 에 대해서만 적용 가능
- var 프로퍼티에만 적용 가능
- 프로퍼티 타입은 null 이 아닌 타입이어야 함
- 프로퍼티가 원시 타입의 값이 아니어야 함
- 추상 클래스의 추상 프로퍼티나 인스턴스의 프로퍼티에는 적용 불가
- 커스텀 게터 및 세터를 지원하는 프로퍼티에는 적용 불가

> **primitive (원시) 타입**
> 
> JVM 에서 primitive 타입은 byte, char, short, int, long, float, boolean 이다.  
> 원시 타입과 참조 타입은 [2.4. 기본형(primitive type) 특화](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 참고하세요.

---

## 2.2. `.isInitialized`

만일 `lateinit` 이 선언된 프로퍼티를 초기화하지 않아도 컴파일 시점에는 오류나 경고 메시지가 뜨지 않는다.

이럴 경우 **`.isInitailized` 를 사용하면 `lateinit` 프로퍼티가 초기화되었는지 판단**할 수 있다.

**프로퍼티가 현재 영역 안에 있어야 하고, `::` 연산자를 통해 프로퍼티에 접근할 수 있어야만 `.isInitialized` 에 접근**할 수 있다.

```kotlin
class WithLate {
    lateinit var x: String

    fun status() = "${::x.isInitialized}"
}

lateinit var y: String

fun main() {
    println("${::y.isInitialized}") // false

    y = "aaa"
    println("${::y.isInitialized}") // true

    val withLate = WithLate()
    println(withLate.status()) // false
    println(withLate::status) // fun assu.study.kotlinme.chap07.lateInitialization.withLate.status(): kotlin.String

    withLate.x = "bb"
    println(withLate.status()) // true
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)