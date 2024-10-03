---
layout: post
title:  "Kotlin - 지연 계산 초기화('lazy()'), 늦은 초기화('lateinit', '.isInitialized'), backing field, backing property"
date: 2024-03-30
categories: dev
tags: kotlin lazy() lateinit .isInitialized backing-field backing-property
---

이 포스트에서는 지연 계산 초기화와 늦은 초기화에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 프로퍼티 초기화 지연](#1-프로퍼티-초기화-지연)
  * [1.1. `backing property` 를 통해 지연 초기화를 구현](#11-backing-property-를-통해-지연-초기화를-구현)
  * [1.2. 위임 프로퍼티를 통해 지연 초기화를 구현: `lazy()`](#12-위임-프로퍼티를-통해-지연-초기화를-구현-lazy)
  * [1.3. 3가지 프로퍼티 초기화 방법 비교](#13-3가지-프로퍼티-초기화-방법-비교)
* [2. 늦은(late) 초기화](#2-늦은late-초기화)
  * [2.1. `lateinit`](#21-lateinit)
  * [2.2. `.isInitialized`](#22-isinitialized)
* [3. `backing field` 와 `backing property`](#3-backing-field-와-backing-property)
  * [3.1. `backing field`](#31-backing-field)
  * [3.2. `backing property`](#32-backing-property)
  * [3.3. `backing field` 와 `backing property` 차이](#33-backing-field-와-backing-property-차이)
  * [3.4. `backing property` 를 사용하는 경우](#34-backing-property-를-사용하는-경우)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 프로퍼티 초기화 지연

프로퍼티를 초기화하는 방법은 총 3가지가 있다.

- 프로퍼티를 정의하는 시점이나 생성자 안에서 초기값 저장
- 프로퍼티에 접근할 때마다 값을 계산하는 custom getter() 정의
- 지연 계산 초기화 사용

**지연 계산 초기화는 객체의 일부분을 초기화하지 않고 남겨뒀다가 실제로 그 부분의 값이 필요할 경우 초기화할 때 흔히 쓰이는 패턴**이다.

**초기값을 계산하는 비용이 많이 들지만 프로퍼티를 선언하는 시점에 즉시 필요하지 않거나 아예 필요하지 않을 수도 있는 프로퍼티에 대해 지연 계산 초기화 패턴을 사용**할 수 있다.

- 복잡하고 시간이 오래 걸리는 계산
- 네트워크 요청
- DB 접근

이런 프로퍼티를 생성 시점에 즉시 초기화하면 아래와 같은 문제가 발생할 수 있다.

- 애플리케이션 초기 시작 시간이 길어짐
- 전혀 사용하지 않거나 나중에 계산해도 될 프로퍼티 값을 계산하기 위해 불필요한 작업을 수행

이런 문제를 해결하기 위해 **지연 계산 프로퍼티는 생성 시점이 아닌 처음 사용할 때 초기화**된다.  
지연 계산 프로퍼티를 사용하면 **그 프로퍼티의 값을 읽기 전까지는** 비싼 초기화 계산을 수행하지 않는다.

---

## 1.1. `backing property` 를 통해 지연 초기화를 구현

이메일이 DB 에 들어있고, 조회할 때 시간이 오래 걸리는 상황이라 이메일 프로퍼티 값을 최초로 사용할 때 단 한번만 DB 에서 가져오게 구현한다고 해보자.

아래는 `backing property` 를 통해 지연 초기화를 구현하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap07

data class Email(
  val email: String,
)

// DB 에서 이메일을 조회하는 함수
fun loadEmail(person: PersonByBackingProperty): List<Email> {
  println("${person.name} 의 이메일")
  return listOf()
}

data class PersonByBackingProperty(
  val name: String,
) {
  // 데이터를 저장하고 emails 의 위임 객체 역할을 하는 _emails 프로퍼티
  private var _emails: List<Email>? = null
  val emails: List<Email>
    get() {
      // 최초 접근 시 이메일을 가져옴
      if (_emails == null) {
        _emails = loadEmail(this)
      }

      // 저장해 둔 데이터가 있으면 그 데이터를 반환
      return _emails!!
    }
}

fun main() {
  val p = PersonByBackingProperty("assu")

  // assu 의 이메일  <-- 최초 emails 을 읽을 때 단 한번만 가져옴
  // []
  // []
  println(p.emails)
  println(p.emails)
}
```

위 코드에서는 `backing property` (뒷받침하는 프로퍼티) 기법을 사용하였다.

| _\_emails_<br />(backing property) | _emails_                           |
|:-----------------------------------|:-----------------------------------|
| 값을 저장 (var)                        | _\_emails_ 프로퍼티에 대한 읽기 연산 제공 (val) |
| null 이 될 수 있는 타입                   | null 이 될 수 없는 타입                   |


이런 기법은 자주 사용하는 기법이므로 잘 알아두는 것이 좋다.

하지만 이런 코드를 만드는 것은 좀 성가시다.  
**위와 같은 방식으로 `backing property` 를 사용하면 지연 초기화를 해야하는 프로퍼티가 많아질 경우 가독성도 안 좋아질 뿐더러 이 구현은 스레드에 안전하지 않아서 언제나 제대로 작동한다고 할 수 없다.**

이럴 때 위임 프로퍼티를 사용하면 코드가 훨씬 간단해진다.

> 위임 프로퍼티에 대한 내용은 [Kotlin - 프로퍼티 위임, 'ReadOnlyProperty', 'ReadWriteProperty', 프로퍼티 위임 도구 (Delegates.observable(), Delegates.vetoable(), Delegates.notNull())](https://assu10.github.io/dev/2024/03/24/kotlin-advanced-4/) 를 참고하세요.

**위임 프로퍼티는 데이터를 저장할 때 사용되는 `backing property` 와 값이 오직 한 번만 초기화됨을 보장하는 getter 로직을 함께 캡슐화**해준다.

---

## 1.2. 위임 프로퍼티를 통해 지연 초기화를 구현: `lazy()`

코틀린은 [프로퍼티 위임](https://assu10.github.io/dev/2024/03/24/kotlin-advanced-4/) 을 사용하여
일관성있고 가독성이 좋은 지연 계산 프로퍼티 구문을 제공하는데, `by` 다음에 `lazy()` 를 붙여주면 된다.

**`lazy` 는 위임 객체를 반환하는 코틀린 라이브러리 함수**이다.

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

_helpful_, _idle_ 모두 val 로 선언되어 있다.  
lazy 초기화가 없다면 이 프로퍼티들은 var 로 선언해야 하기 때문에 신뢰성이 덜 한 코드가 된다.

[1.1. `backing property` 를 통해 지연 초기화를 구현](#11-backing-property-를-통해-지연-초기화를-구현) 의 예시를 위임 프로퍼티를 통해 구현하면 아래와 같다.

`backing property` 로 지연 초기화 구현

```kotlin
data class PersonByBackingProperty(
  val name: String,
) {
  // 데이터를 저장하고 emails 의 위임 객체 역할을 하는 _emails 프로퍼티
  private var _emails: List<Email>? = null
  val emails: List<Email>
    get() {
      // 최초 접근 시 이메일을 가져옴
      if (_emails == null) {
        _emails = loadEmail(this)
      }

      // 저장해 둔 데이터가 있으면 그 데이터를 반환
      return _emails!!
    }
}
```

위임 프로퍼티로 지연 초기화 구현

```kotlin
data class PersonByLazy(
    val name: String,
) {
    val emails by lazy { loadEmail(this) }
}
```

코드가 매우 간결해진 것을 볼 수 있다.

`lazy()` 함수는 `getValue()` 메서드가 들어있는 객체를 반환하기 때문에 `lazy()` 를 `by` 키워드와 함께 사용하여 위임 프로퍼티를 만들 수 있다.

**`lazy()` 함수의 인자는 값을 초기화할 때 호출할 람다**이다.

**`lazy()` 함수는 기본적으로 스레드에 안전**하다.

하지만 필요에 따라 동기화에 사용할 lock 을 `lazy()` 함수에 전달할 수도 있고, 다중 스레드 환경에서 사용하지 않을 프로퍼티를 위해 `lazy()` 함수가 동기화를 
하지 못하게 막을수도 있다.

---

## 1.3. 3가지 프로퍼티 초기화 방법 비교

아래는 프로퍼티를 초기화하는 3 가지 방법인 `정의 시점`, `getter()`, `지연 계산`을 비교한 예시이다.

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
(= 객체 인스턴스를 일단 생성한 다음에 나중에 초기화)

예) JUnit 에서는 `@Before` 로 애너테이션된 메서드 안에서 초기화 로직을 수행해야 함

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

> 코틀린에서 클래스 안에 null 이 될 수 없는 프로퍼티를 생성자 안에서 초기화하지 않고 특별한 메서드 안에서 초기화할 수는 없음  
> 코틀린에서는 일반적으로 생성자에서 모든 프로퍼티를 초기화해야 함  
> 또한 프로퍼티 타입이 null 이 될 수 없는 타입이라면 반드시 null 이 아닌 값으로 그 프로퍼티를 초기화해야 하는데 그런 초기화값을 
> 제공할 수 없다면 null 이 될 수 있는 타입을 사용할 수 밖에 없음  
> 하지만 null 이 될 수 있는 타입을 사용하면 모든 프로퍼티 접근에 null 검사를 넣거나 널 아님 단언 `!!` 연산자를 사용해야 함

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

`lateinit` 을 사용한 예시와 사용하지 않은 예시 비교

```kotlin
package com.assu.study.kotlin2me.chap06



class MyService {
  fun action(): String = "foo"
}

// 널 아님 단언 `!!` 을 사용하여 null 이 될 수 있는 프로퍼티 접근
class MyTest {
  // null 로 초기화하기 위해 null 이 될 수 있는 타입인 프로퍼티 선언
  private var myService: MyService? = null

  fun setUp() {
    // setUp() 안에서 진짜 초기값 지정
    myService = MyService()
  }

  fun testAction() {
    // 널 아님 단언 `!!` 이나 안전한 호출 `?.` 을 꼭 사용해야 함
    myService!!.action()
    myService?.action()
  }
}

// 나중에 초기화하는 프로퍼티 사용
class MyTestWithLateInit {
  // 초기화하지 않고 null 이 될 수 없는 프로퍼티 선언
  private lateinit var myService: MyService

  fun setUp() {
    // setUp() 안에서 진짜 초기값 지정
    myService = MyService()
  }

  fun testAction() {
    // null 검사를 수행하지 않고 프로퍼티 사용
    myService.action()
  }
}
```

<**`lateinit` 의 제약 사항**>  
- 클래스 본문과 최상위 영역이나 지역에 정의된 var 에 대해서만 적용 가능
- var 프로퍼티에만 적용 가능
  - val 프로퍼티는 final 필드로 컴파일되며, 생성자 안에서 반드시 초기화해야 함
  - 따라서 생성자 밖에서 초기화해야 하는 나중에 초기화하는 프로퍼티는 항상 var 이어야 함
- 프로퍼티 타입은 null 이 아닌 타입이어야 함
- 프로퍼티가 primitive 타입의 값이 아니어야 함
- 추상 클래스의 추상 프로퍼티나 인스턴스의 프로퍼티에는 적용 불가
- 커스텀 게터 및 세터를 지원하는 프로퍼티에는 적용 불가

만일 나중에 초기화하는 프로퍼티에 대해 그 프로퍼티를 초기화하기 전에 해당 프로퍼티에 접근하면 아래와 같은 예외가 발생한다.

```shell
lateinit property myService has not been initialized
```

_myService_ 라는 `lateinit` 프로퍼티를 아직 초기화하지 않았다는 예외이다.  
단순한 NPE 가 발생하는 것보다 훨씬 낫다.

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

# 3. `backing field` 와 `backing property`

자바에서의 프로퍼티와 코틀린에서의 프로퍼티의 의미를 비교해보자.

<**자바에서의 프로퍼티**>  
- 필드와 접근자 메서드 (getter/setter) 를 묶어서 프로퍼티라 함
- 프로퍼티라는 개념이 생긴 이유는 데이터를 캡슐화하려는 목적과 연관이 있음
- 자바 클래스는 기본적으로 필드를 private 로 설정하고 외부에서 값을 가져오거나 변경할 때 getter/setter 를 제공함
- 이를 통해 캡슐화된 클래스의 고유한 기능은 유지하면서 클라이언트의 요구에 따라 속성값을 확인하거나 변경할 수 있도록 해줌

<**코틀린에서의 프로퍼티**>  
- 코틀린에서는 필드에 대한 기본 접근자 메서드를 자동으로 만들어주기 때문에 필드 대신 프로퍼티라는 말을 사용함
- 원한다면 접근자 메서드를 명시적으로 선언할 수도 있음

---

## 3.1. `backing field`

**`backing field` 는 프로퍼티의 값을 저장하기 위한 필드**이다.

코틀린에서 필드는 메모리에 값을 보관하기 위한 프로퍼티의 일부로서만 사용된다.

**`backing field` 는 `field` 식별자를 사용하여 getter/setter 접근자에서 참조 가능**하다.

코틀린에서는 필드를 바로 선언할 수 없고, 프로퍼티로 선언하면 아래의 경우에 자동으로 `backing field` 가 생긴다.

- **프로퍼티가 적어도 하나의 접근자 (getter/setter) 의 기본 구현을 사용** 하는 경우
- **커스텀 접근자가 `field` 식별자를 통해 해당 접근자를 참조** 하는 경우

> 커스텀 접근자에 대한 좀 더 상세한 내용은 [9. 프로퍼티 접근자: `field`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90-field) 를 참고하세요.

커스텀 setter 에 대한 코틀린 코드

```kotlin
class A {
    var counter = 0 // 
      set(value) {
          if (value > 0) {
              field = value // field 를 사용하여 counter 의 backing field 에 접근
          } 
      }
}
```

위 코드를 보면 _counter_ 프로퍼티를 만들어 0 으로 초기값을 설정하였다.  
setter 에서 값을 검증한 후 _field = value_ 를 통해 _counter_ 의 값을 변경한다.

`field` 식별자는 오직 프로퍼티 접근자인 getter/setter 에서만 사용 가능하다.

자바로 변환한 코드

```java
public final class A {
    private int counter;
    
    public final int getCounter() {
        return this.counter;
    }
    
    public final void setCounter(int value) {
        if (value > 0) {
            this.counter = value;
        }
    }
}
```

자바로 변환한 코드를 보면 _counter_ 필드가 생성되어 있고, getter/setter 가 따로 생성되었다.

즉, 코틀린이 프로퍼티 값을 저장하기 위해서는 자바의 필드가 필요한데 이렇게 **프로퍼티 값을 저장하기 위한 필드를 `backing field`** 라고 한다.

---

아래는 `backing field` 를 사용하지 않는 경우에 대한 예시이다.

`backing field` 를 사용하지 않는 경우 코틀린 코드

```kotlin
class A {
    var size = 0
    var isEmpty: Boolean    // backing field 가 생성되지 않는 경우
        get() = this.size == 0
}
```

자바로 변환한 코드

```java
public final class A {
    private int size;
    
    // isEmpty 에 대한 필드가 생성되지 않음
  
    public final int getSize() {
        return this.size;
    }
    
    public final void setSize(int val1) {
        this.size = val1;
    }
    
    public final boolean isEmpty() {
        return this.size == 0;
    }
}
```

위 코드를 보면 _isEmpty_ 프로퍼티는 메모리에 아무런 값도 저장하지 않는다.  
따라서 _size_ 와 달리 getter 만 존재하며 필드가 생성되지 않는다.

---

## 3.2. `backing property`

`backing field` 는 필요에 따라 커스텀 getter/setter 를 만드는 경우에도 제약이 존재한다.  
getter 는 반환 타입이 반드시 프로퍼티의 타입과 같아야 하기 때문이다.

`backing property` 는 prefix 로 `_` 를 붙인다.

아래 코드에서 _result_ 를 가변이 아닌 불변 리스트로 넘기고 싶어도 반환 타입이 무조건 MutableList 이어야 하기 때문에 불가능하다.

```kotlin
private var result: MutableList<List<String>> = mutableListOf()
    private set
```

이럴 경우 아래와 같이 `backing property` 를 사용하면 _result_ 를 불변 리스트로 반환할 수 있다.

```kotlin
private var _result: MutableList<List<String>> = mutableListOf()

val result: List<List<String>>
  get() = _result
```

이렇게 **`backing field` 타입에 맞지 않는 작업을 수행할 때 `backing property` 를 사용하여 이를 가능**하게 할 수 있다.

---

## 3.3. `backing field` 와 `backing property` 차이

`backing field`

```kotlin
var table: Map<String, Int>? = null 
    private set 
    get() {
      if (field == null) {
          field = HashMap()
      }
      return field ?: throw AssertionError()
  }
```

`backing property`

```kotlin
private var _table: Map<String, Int>? = null 

public val table: Map<String, Int>
  get() {
      if (_table == null) {
          _table = HashMap()
      }
        return _table ?: AssertionError()
  }
```

위 2개의 코드는 근본적으로는 다르지 않다.

`backing property` 를 사용했을 때는 `backing field` 를 사용하지 않을 수 있다.

---

## 3.4. `backing property` 를 사용하는 경우

아래 2개의 코드를 보자.

```kotlin
var count: Int = 0
    private set
```

_count_ 는 값을 반환할 때 추가적인 작업이 필요하지 않기 때문에 
기본 getter 로 바로 값을 반환하는 것과 `backing property` 를 이용하여 getter 를 직접 명시해주는 것에 차이가 없다.

```kotlin
private var _result: MutableList<List<String>> = mutableListOf()

val result: List<List<String>>
  get() = _result
```

반면, _result_ 는 기본 getter 로 값을 반환하면 가변인 mutableList 로 반환된다.

이럴 때 `backing property` 를 만들어서 내부에서는 값이 변경되지만 getter 를 통해 값을 넘겨줄 때는 불변 List 로 변경하여 넘길 수 있다.

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
* [Backing Field와 Backing Properties](https://colour-my-memories-blue.tistory.com/6)
* [Kotlin doc: backing-fields](https://kotlinlang.org/docs/properties.html#backing-fields)
* [Kotlin doc: backing-properties](https://kotlinlang.org/docs/properties.html#backing-properties)