---
layout: post
title: "Kotlin - 함수(2): null 이 될 수 있는 타입, 안전한 호출, 널 아님 단언, 엘비스 연산자, 널 아님 단언, 확장 함수, 제네릭스, 확장 프로퍼티"
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
  * [1.2. null 가능성과 자바](#12-null-가능성과-자바)
    * [1.2.1. 플랫폼 타입](#121-플랫폼-타입)
    * [1.2.2. 자바와 코틀린 간의 혼합 상속](#122-자바와-코틀린-간의-혼합-상속)
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
    * [5.2.1. 타입 파라메터의 null 가능성](#521-타입-파라메터의-null-가능성)
    * [5.2.2. 타입 파라메터를 null 이 될 수 없는 타입으로 한정](#522-타입-파라메터를-null-이-될-수-없는-타입으로-한정)
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
즉, NPE (NullPointerException) 이 발생할 수 있는 시점을 runtime 시점에서 compile 시점으로 옮기는 것이다.

코틀린의 모든 타입은 기본적으로 null 이 될 수 없는 타입인데 null 의 결과가 나올 수 있는 변수라면 타입 이름 뒤에 물음표 (`?`) 를 붙여서 
결과가 null 이 될 수도 있음을 표시해야 한다.

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

## 1.2. null 가능성과 자바

null 가능성의 특별한 경우로 자바에서 가져온 타입의 null 가능성에 대해 알아본다.

코틀린은 자바와 상호 운용된다. 하지만 자바는 null 가능성을 지원하지 않는다.

그렇다면 자바와 코틀린을 조합하면 어떻게 될까?

자바에도 애너테이션으로 표시된 null 가능성 정보가 있다.  
이런 정보가 콛에 있으면 코틀린은 그 정보를 활용한다.

예를 들어 자바의 `@Nullable String` 은 코틀린에서 `String?` 이고, 자바의 `@NotNull String` 은 코틀린에서 `String` 이다.

이런 null 가능성 애너테이션이 코드에 없을 경우 자바의 타입은 코틀린의 플랫폼 타입 (platform type) 이 된다.

---

### 1.2.1. 플랫폼 타입

자바 타입을 코틀린에서 가져와 사용할 때 null 가능성을 어떻게 다루는지에 대해 알아보자.

**플랫폼 타입은 코틀린이 null 관련 정보를 알 수 없는 타입**을 말한다.

그 타입을 null 이 될 수 있는 타입으로 처리해도 되고, null 이 될 수 있는 타입으로 처리해도 된다.

코틀린은 보통 null 이 될 수 없는 타입의 값에 대해 null 안전성을 검사하는 연산을 수행하면 경고를 표시하지만 플랫폼 타입의 값에 대해 null 안전성 검사를 
중복 수행해도 아무런 경고도 표시하지 않는다.

자바로 선언된 _Person5_ 클래스가 있다고 하자.

```java
package com.assu.study.kotlin2me.chap06;

public class Person5 {
  private final String name;

  public Person5(String name) {
    this.name = name;
  }

  public String getName() {
    return name;
  }
}
```

코틀린 컴파일러는 위 코드에서 _getName()_ 이 리턴하는 String 타입의 null 가능성에 대해 전혀 알지 못한다.  
따라서 null 가능성을 개발자가 직접 처리해야 한다.

이 변수가 null 이 아님을 확신할 수 있다면 자바와 마찬가지로 추가 검사 없이 이를 참조할 수 있지만, 추가 검사를 하지 않을 경우 예외가 발생할 수도 있다.

null 검사 없이 자바 클래스 접근

```kotlin
package com.assu.study.kotlin2me.chap06

// uppercase() 의 수신 객체 person.name 이 null 이면 예외 발생
fun yellAt(person: Person5) = println(person.name.uppercase())

fun main() {
    yellAt(Person5("!1"))
}
```

코틀린 컴파일러는 public 가시성인 코틀린 함수의 null 이 아닌 타입인 파라메터와 수신 객체에 대한 null 검사를 추가해준다.  
따라서 public 가시성 함수에 null 값을 사용하면 즉시 예외가 발생한다.

이런 파라메터 값 검사는 함수 내부에서 파라메터를 사용하는 시점이 아니라 함수 호출 시점에 이루어지기 때문에 잘못된 인자로 함수를 호출하자마자 예외가 발생해서 
원인을 쉽게 파악할 수 있다.

물론 위의 _getName()_ 의 반환 타입을 null 이 될 수 있는 타입으로 해석해서 null 안전성 연산을 활용해도 된다.

null 검사를 통해서 자바 클래스 접근

```kotlin
package com.assu.study.kotlin2me.chap06

fun yellAtSafe(person: Person5) = println((person.name ?: "Anyone").uppercase())

fun main() {
    yellAtSafe(Person5(null))
}
```

위 예시에서는 null 값을 제대로 처리하므로 실행 시점에 예외가 발생하지 않는다.

자바 API 를 다룰 때는 조심해야 한다.

대부분의 라이브러리는 null 관련 애너테이션을 사용하지 않으므로 모든 타입을 null 이 아닌 것처럼 다루기 쉽지만 그렇게 하면 오류가 발생할 수 있다.

오류를 피하려면 사용하려는 자바 메서드의 문서를 살펴본 후 그 메서드가 null 을 반환할지 알아낸 후 null 을 반환하는 메서드에 대한 null 검사를 추가해야 한다.

> **코틀린이 플랫폼 타입을 도입한 이유**
> 
> 모든 자바 타입을 null 이 될 수 있는 타입으로 다루게 되면 더 안전할 거라고 생각될 수도 있겠지만 모든 타입을 null 이 될 수 있는 타입으로 다루면 
> 결코 null 이 될 수 없는 값에 대해서도 불필요한 null 검사를 해야 함
> 
> 특히 제네릭을 다루게 될 때 예를 들어 모든 자바 _ArrayList\<String\>_ 을 코틀린에서 _ArrayList\<String?\>?_ 처럼 다루게 되면 이 배열의 원소에 
> 접근할 때마다 null 검사를 수행하거나 안전한 캐스트 `as?` 를 수행해야 함
> 
> 이런 식으로 처리하게 되면 null 안전성으로 얻는 이익보다 검사에 드는 비용이 훨씬 더 커지게 됨
> 
> 그래서 코틀린 설계자들은 자바의 타입을 가져온 경우 프로그래머에게 그 타입을 제대로 처리할 책임을 부여하는 접근 방법을 택함

코틀린에서 플랫폼 타입을 선언할 수는 없다.  
자바 코드에서 가져온 타입만 플랫폼 타입이 된다.

하지만 컴파일러 오류 메시지에서는 플랫폼 타입을 볼 수 있다.

```kotlin
val i: Int = person.name
```

```shell
ERROR: Type mismatch: inferred type is String! but Int was expected
```

코틀린 컴파일러가 표시한 `String!` 타입은 자바 코드에서 온 타입이다.

`!` 표시는 `String!` 타입의 null 가능성에 대해 아무 정보도 없다는 의미이다.

---

### 1.2.2. 자바와 코틀린 간의 혼합 상속

여기서는 코틀린과 자바를 혼합한 클래스 계층을 선언할 때 주의할 점에 대해 알아본다.

코틀린에서 자바 메서드를 오버라이드할 때 그 메서드의 파라메터와 반환 타입을 null 이 될 수 있는 타입으로 선언할 지 null 이 될 수 없는 타입으로 선언할 지 결정해야 한다.

아래는 자바의 한 인터페이스 예시이다.

```java
interface JavaInterface {
  void action(String input);
}
```

코틀린 컴파일러는 아래와 같은 2 가지 구현을 다 받아들인다.

```kotlin
package com.assu.study.kotlin2me.chap06

class KtClass1 : JavaInterface {
    override fun action(input: String) {
        println(input)
    }
}

class KtClass2 : JavaInterface {
    override fun action(input: String?) {
        if (input != null) {
            println(input)
        }
    }
}
```

자바 클래스나 인터페이스를 코틀린에서 구현할 경우 null 가능성을 제대로 처리하는 것은 중요하다.

코틀린 컴파일러는 null 이 될 수 없는 타입으로 선언한 모든 파라메터에 대해 null 이 아님을 검사하는 단언문을 만들어준다.  
자바 코드가 그 메서드에 null 을 넘기면 이 단언문에 의해 예외가 발생한다.  
만일 파라메터를 메서드 안에서 사용하지 않더라도 이 예외는 피할 수 없다.

---

# 2. 안전한 호출(safe call)과 엘비스(Elvis) 연산자

## 2.1. 안전한 호출 (safe call): `?.`

안전한 호출은 `?.` 와 같이 표기한다.

안전한 호출 연산자인 `?.` 은 null 검사와 메서드 호출을 한 번의 연산으로 수행한다.

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

앨비스 연산자인 `?:` 는 null 대신 디폴트 값을 지정할 때 사용한다.

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

아래는 엘비스 연산자를 이용하여 예외를 던지는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap06

class Address(val streetAddr: String, val zipCode: Int, val city: String, val country: String)

class Company(val name: String, val addr: Address?)

class Person(val name: String, val company: Company?)

fun shippingLabel(person: Person) {
    // 주소가 없으면 예외 발생
    val address = person.company?.addr ?: throw IllegalArgumentException("No Addr.")

    // address 는 null 이 아님
    with (address) {
        println(this.streetAddr)
        println("$zipCode, $city, $country")
    }
}

fun main() {
    val addr = Address("Aaa", 111, "Bbb", "Ccc")
    val jetbrains = Company("JetBrains", addr)
    val person = Person("Assu", jetbrains)

    // Aaa
    // 111, Bbb, Ccc
    shippingLabel(person)
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

**가장 좋은 방법은 항상 안전한 호출(`?.`) 후에 자세한 예외를 반환하는 특별한 함수를 사용**하는 것이다.  
**null 이 아니라는 점을 단언하는 호출인 `!!` 은 꼭 필요할 때만 사용**하는 것이 좋다.

`!!` 을 사용하면 어떤 값이든 null 이 될 수 없는 타입으로 강제로 바꿀 수 있다.

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

**`!!` 사용보다는 안전한 호출 `?.` 이나 명시적인 null 검사를 활용하는 것이 좋다.**  
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

때로는 널 아님 단언문 `!!` 이 더 나은 해법이 되는 경우가 있다.

어떤 함수가 null 인지 검사한 다음에 다른 함수를 호출한다고 해도 컴파일러는 호출된 함수 안에서 안전하게 그 값을 사용할 수 있음을 인식할 수 없다.

이런 경우 호출된 함수가 언제나 다른 함수에서 null 이 아닌 값을 전달받는다는 사실이 분명하다면 굳이 null 검사를 다시 수행하고 싶지 
않을 것이다. 이럴 때 널 아님 단언문 `!!` 을 사용한다.

널 아님 단언 `!!` 을 사용할 때의 주의점은 null 에 대해 사용해서 발생하는 예외의 스택 트레이스에는 어떤 파일의 몇 번째 줄인지는 나오지만 어떤 식에서 
예외가 발생했는지에 대한 정보는 들어있지 않다.

```kotlin
package com.assu.study.kotlin2me.chap06

class Address2(val streetAddr: String, val zipCode: Int, val city: String, val country: String)

class Company2(val name: String, val addr: Address2?)

class Person2(val name: String, val company: Company2?)

fun main() {
    val person = Person2("AA", null)

    // 아래와 같이 어느 파일의 몇 번째 줄인지에 대한 정보만 나오고 어느 식에서 에러가 발생했는지에 대한 정보는 
    // 출력되지 않음
    
    // Exception in thread "main" java.lang.NullPointerException
    // at com.assu.study.kotlin2me.chap06.NotNullAssertionKt.main(NotNullAssertion.kt:12)
    println(person.company!!.addr!!.city)
}
```

따라서 _person.company!!.addr!!.city_ 이런 식의 코드를 작성하는 것은 좋지 않다.

---

# 4. 확장 함수와 null 이 될 수 있는 타입

null 이 될 수 있는 타입에 확장 함수를 정의하면 null 값을 편리하게 다룰 수 있다.

어떤 메서드를 호출하기 전에 수신 객체 역할을 하는 변수가 null 이 될 수 없다고 보장하는 대신, **직접 변수에 대해 메서드를 호출해도 확장 함수인 메서드가 
알아서 null 을 처리**해준다.

**이런 처리는 확장 함수에서만 가능**하다.

일반 멤버 호출은 객체 인스턴스를 통해 dispatch 되기 때문에 그 인스턴스가 null 인지 여부를 검사하지 않는다.

> **디스패치 (dispatch)**
> 
> - 동적 디스패치
>   - 객체의 동적 타입에 따라 적절한 메서드를 호출해주는 방식
> - 직접 디스패치
>   - 컴파일러가 컴파일 시점에 어떤 메서드가 호출될 지 결정해서 코드를 생성하는 방힉

---

## 4.1. 확장 함수 사용: `isNullOrEmpty()`, `isNullOrBlank()`

[안전한 호출](#21-안전한-호출-safe-call-) 을 사용한 _s?.f()_ 는 s 가 null 이 될 수 있는 타입임을 암시한다.  
비슷하게 t.f() 는 t 가 null 이 될 수 없는 타임을 암시하는 것처럼 보이지만 꼭 t 가 null 이 될 수 없는 타입인 것은 아니다.

코틀린은 String 을 확장하여 정의된 `isEmpty()` 와 `isBlank()` 함수를 제공한다.

- `isEmpty()`
  - 문자열이 빈 문자열인지 검사
- `isBlank()`
  - 문자열이 모두 공백으로 이루어졌는지 검사

비슷하게 코틀린 표준 라이브러리는 아래의 String 확장 함수도 제공한다.

- `isNullOrEmpty()`
  - 수신 String 이 null 이거나 빈 문자열인지 검사
- `isNullOrBlank()`
  - `isNullOrEmpty()` 와 같은 검사를 수행
  - 수신 객체 String 이 온전히 공백 문자 (탭인 `\t` 와 새 줄 `\n` 도 포함) 로만 구성되어 있는지도 검사

`isNullOrBlank()` 함수는 아래와 같이 정의되어 있다.

```kotlin
@kotlin.internal.InlineOnly
public inline fun CharSequence?.isNullOrBlank(): Boolean {
    contract {
        returns(false) implies (this@isNullOrBlank != null)
    }
  
    // null 을 검사하여 null 이면 true 를 리턴하고, 아니면 isBlank() 호출
    // isBlank() 는 null 이 아닌 문자열 타입의 값에 대해서만 호출 가능
    return this == null || this.isBlank()
}
```

null 이 될 수 있는 타입에 대한 확장을 정의하면 null 이 될 수 있는 값에 대해 그 확장 함수를 호출할 수 있다.  
그 함수의 내부에서 `this` 는 null 이 될 수 있으므로 명시적으로 null 여부를 검사해야 한다.

> **null의 관점에서 메서드 안에서의 `this` 에 대한 자바와 코틀린 차이**
> 
> 자바에서는 메서드 안의 `this` 는 그 메서드가 호출된 수신 객체를 가리키므로 항상 null 이 아님    
> 수신 객체가 null 이었다면 NPE 가 발생해서 메서드 안으로 들어가지도 못함  
> 따라서 자바에서 메서드가 정상 실행된다면 그 메서드의 `this` 는 항상 null 이 아님
> 
> 반면 코틀린에서는 null 이 될 수 있는 타입의 확장 함수 안에서는 `this` 가 null 이 될 수 있음

```kotlin
fun main() {
    val s1: String? = null
  
    // 안전한 호출 `?.` 없이 메서드 호출
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

[`let()`](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#23-let) 함수도 null 이 될 수 있는 타입의 값에 대해 호출할 수는 있지만
`let()` 은 `this` 가 null 인지 검사하지 않는다.  
null 이 될 수 있는 타입의 값에 대해 안전한 호출 `?.` 을 사용하지 않고 `let()` 을 호출하면 람다의 인자는 null 이 될 수 있는 타입으로 추론된다.

```kotlin
val email3: String? = "assu@test"

// Type mismatch.
// Required: String
// Found: String?
email3.let { sendToEmail(it) }
```

따라서 `let()` 을 사용할 때 수신 객체가 null 인지 검사하고 싶다면 안전한 호출 `?.` 과 함께 사용해야 한다.

```kotlin
val email3: String? = "assu@test"

email3?.let { sendToEmail(it) }
```

**확장 함수를 만들 때 처음에는 null 이 될 수 없는 타입에 대해 확장 함수를 정의**하는 것이 좋다.  
나중에 대부분 null 이 될 수 있는 타입에 대해 그 함수를 호출하게 되었을 때 확장 함수 안에서 null 을 제대로 처리하게 되면 안전하게 그 확장 함수를 null 이 될 수 있는 
타입에 대한 확장 함수로 변경할 수 있다.

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

> 제네릭스 정의에 대한 내용은 좀 더 상세한 내용은  
> [Kotlin - 제네릭스(1): Any, 타입 정보 보존, 제네릭 확장 함수, 타입 파라메터 제약, 타입 소거](https://assu10.github.io/dev/2024/03/17/kotlin-advanced-2/),  
> [Kotlin - 제네릭스(2): 'reified', 타입 변성 'in'/'out', 공변과 무공변, 타입 프로젝션](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/)  
> 을 참고하세요.
## 5.1. 하나의 타입 파라메터를 받는 클래스

`List<Int>` 에서 `<>` 를 타입 파라메터라고 한다.

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

### 5.2.1. 타입 파라메터의 null 가능성

물음표가 붙어있지 않은 타입 파라메터가 null 이 될 수 있는 타입일 수도 있다.

코틀린에서는 함수나 클래스의 모든 타입 파라메터는 기본적으로 null 이 될 수 있다.  
null 이 될 수 있는 타입을 포함하는 어떤 타입이라도 타입 파라메터를 대신할 수 있으므로 타입 파라메터 `T` 를 클래스나 함수 안에서 타입 이름으로 사용하면 
이름 끝에 물음표가 없더라도 `T` 가 null 이 될 수 있는 타입이다.

즉, **아무런 상한을 정하지 않은 타입 파라메터는 결과적으로 `Any?` 를 상한으로 정한 파라메터**와 같다.

null 이 될 수 있는 타입 파라메터

```kotlin
package com.assu.study.kotlin2me.chap06

// t 가 null 이 될 수 있으므로 안전한 호출 `?.` 을 사용함
fun <T> printCode(t: T) = println(t?.hashCode())

fun <T> printCode2(t: T) = println(t.hashCode())

fun main() {
    printCode("1") // 49

    printCode2("1") // 49

    // T 의 타입은 Any? 로 추론됨
    printCode(null) // null

    printCode2(null) // 0
}
```

위 코드의 _printCode()_ 호출에서 타입 파라메터 `T` 에 대해 추론한 타입은 null 이 될 수 있는 Any? 타입이다.  
t 파라메터의 타입 이름 `T` 에 물음표가 붙어있지는 않지만 t 는 null 을 받을 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap09

class Processor<T> {
    fun process1(value: T) {
        // value 는 null 이 될 수 있으므로 안전한 호출 사용
        println(value?.hashCode())
    }

    fun process2(value: T) {
        println(value.hashCode())
    }
}

fun main() {
    // Processor 클래스를 null 이 될 수 있는 타입을 사용하여 인스턴스화함
    val nullableStringProcessor = Processor<String?>()

    nullableStringProcessor.process1(null) // null
    nullableStringProcessor.process2(null) // 0
}
```

위의 _process1()_ 메서드에서 _value_ 파라메터의 타입 `T` 에는 `?` 가 없지만 실제로는 `T` 에 해당하는 타입 인자로 null 이 될 수 있는 타입을 넘길 수도 있다.

**타입 파라메터가 null 이 아님을 확실히 하려면 null 이 될 수 없는 타입 상한 (upper bound) 를 지정**해야 한다.

---

### 5.2.2. 타입 파라메터를 null 이 될 수 없는 타입으로 한정

타입 파라메터에 대해 null 이 될 수 없는 상한을 적용한 예시
```kotlin
package com.assu.study.kotlin2me.chap06

// 이제 T 는 null 이 될 수 없는 타입임
fun <T : Any> printCode4(t: T) = println(t.hashCode())

fun <T : Any> printCode3(t: T) = println(t?.hashCode())

fun main() {
    // 컴파일 오류
    // Null can not be a value of a non-null type TypeVariable(T)
    
    // printCode3(null)

    // 컴파일 오류
    // Null can not be a value of a non-null type TypeVariable(T)
    
    // printCode4(null)

    printCode3("1") // 49
    printCode4("1") // 49
}
```

```kotlin
package com.assu.study.kotlin2me.chap09

// null 이 될 수 없는 타입 상한 지정
class Processor2<T : Any> {
    fun process2(value: T) {
        // T 타입의 value 는 null 이 될 수 없으므로 안전한 호출 사용안함
        println(value.hashCode())
    }
}

fun main() {
    // Processor 클래스를 null 이 될 수 있는 타입을 사용하여 인스턴스화함
    val nullableStringProcessor = Processor2<String>()

    // 컴파일 오류
    // nullableStringProcessor.process2(null)

    nullableStringProcessor.process2("ABC") // 64578
}
```

위에서 `<T: Any>` 라는 제약은 `T` 타입이 항상 null 이 될 수 없는 타입이 되도록 보장한다.

`Any` 뿐 아니라 다른 null 이 될 수 없는 타입을 사용하여 상한을 정해도 된다.  
예) `<T: String>`

타입 파라메터는 null 이 될 수 있는 타입을 표시하기 위해 반드시 물음표를 타임 이름 뒤에 붙여야 한다는 규칙의 유일한 예외이다.

---

## 5.3. universal type: `Any`

[5.1. 하나의 타입 파라메터를 받는 클래스](#51-하나의-타입-파라메터를-받는-클래스) 의 문제를 제네릭 타입이 아닌 유니버셜 타입(universal type) 인 `Any` 로 해결할 수도 있다.

> `Any` 에 대한 좀 더 상세한 내용은 [1.1. `Any`](https://assu10.github.io/dev/2024/03/17/kotlin-advanced-2/#11-any) 를 참고하세요.

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
  
    // Hello!
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

List<\*\> 를 사용하면 List 에 담긴 원소의 타입 정보를 모두 잃어버리므로 원소가 null 이 될 수 있는지 없는지에 대한 타입 정보가 없기 때문에 
List<\*\> 에서 얻은 원소는 `Any?` 타입의 변수에만 대입할 수 있다.

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