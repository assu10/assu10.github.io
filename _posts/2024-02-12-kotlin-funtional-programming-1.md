---
layout: post
title: "Kotlin - 함수형 프로그래밍(1): 람다, 컬렉션 연산, 멤버 참조, 최상위 함수와 프로퍼티"
date: 2024-02-12
categories: dev
tags: kotlin lambda mapIndexed() indices() run() filter() closure, filter() filterNotNull() any() all() none() find() firstOrNull() lastOrNull() count() filterNot() partition() sumof() sortedBy() minBy() take() drop() sortedWith() compareBy() times()
---

코틀린 여러 함수 기능에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 람다](#1-람다)
  * [1.1. 함수 파라메터가 하나인 경우: `it`](#11-함수-파라메터가-하나인-경우-it)
  * [1.2. 함수 파라메터가 여러 개인 경우](#12-함수-파라메터가-여러-개인-경우)
  * [1.3. 람다 파라메터가 여러 개인 경우: `mapIndexed()`](#13-람다-파라메터가-여러-개인-경우-mapindexed)
  * [1.4. 람다가 특정 인자를 사용하지 않는 경우: `_`, `List.indices()`](#14-람다가-특정-인자를-사용하지-않는-경우-_-listindices)
  * [1.5. 람다에 파라메터가 없는 경우: `run()`](#15-람다에-파라메터가-없는-경우-run)
  * [1.6. 람다를 통해 코드 재사용: `filter()`](#16-람다를-통해-코드-재사용-filter)
  * [1.7. 람다를 변수에 담기](#17-람다를-변수에-담기)
  * [1.8. 클로저 (Closure)](#18-클로저-closure)
  * [1.9. 람다와 `this`](#19-람다와-this)
  * [1.10. 람다의 `return`](#110-람다의-return)
    * [1.10.1. 람다 안의 `return`: 람다를 둘러싼 함수로부터 반환](#1101-람다-안의-return-람다를-둘러싼-함수로부터-반환)
    * [1.10.2. 람다로부터 반환: 레이블을 이용한 `return`](#1102-람다로부터-반환-레이블을-이용한-return)
    * [1.10.3. 무명 함수: 기본적으로 로컬 `return`](#1103-무명-함수-기본적으로-로컬-return)
* [2. 컬렉션 연산: `hashSetOf()`, `arrayListOf()`, `listOf()`, `hashMapOf()`](#2-컬렉션-연산-hashsetof-arraylistof-listof-hashmapof)
  * [2.1. List 연산](#21-list-연산)
  * [2.2. 여러 컬렉션 함수들: `filter()`, `filterNotNull()`, `any()`, `all()`, `none()`, `find()`, `firstOrNull()`, `lastOrNull()`, `count()`](#22-여러-컬렉션-함수들-filter-filternotnull-any-all-none-find-firstornull-lastornull-count)
  * [2.3. `filterNot()`, `partition()`](#23-filternot-partition)
  * [2.4. 커스텀 함수의 반환값에 구조 분해 선언 사용](#24-커스텀-함수의-반환값에-구조-분해-선언-사용)
  * [2.5. `sumOf()`, `sortedBy()`, `minBy()`, `takeXX()`, `dropXX()`](#25-sumof-sortedby-minby-takexx-dropxx)
  * [2.6. Set 의 연산](#26-set-의-연산)
* [3. 멤버 참조: `::`](#3-멤버-참조-)
  * [3.1. 프로퍼티 참조: `sortedWith()`, `compareBy()`](#31-프로퍼티-참조-sortedwith-compareby)
  * [3.2. 함수 참조](#32-함수-참조)
  * [3.3. 생성자 참조: `mapIndexed()`](#33-생성자-참조-mapindexed)
  * [3.4. 확장 함수 참조: `times()`](#34-확장-함수-참조-times)
* [4. 최상위 함수와 프로퍼티 (정적인 유틸리티 클래스 없애기)](#4-최상위-함수와-프로퍼티-정적인-유틸리티-클래스-없애기)
  * [4.1. 최상위 함수: `@JvmName`](#41-최상위-함수-jvmname)
  * [4.2. 최상위 프로퍼티: `const`](#42-최상위-프로퍼티-const)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 람다

람다는 함수 리터럴이라고도 부르며, 이름이 없고 함수 생성에 필요한 최소한의 코드만 필요하며, 다른 코드에 람다를 직접 삽입할 수 있다.

코틀린은 보통 람다를 무명 클래스로 컴파일하지만 그렇다고 람다식을 사용할 때마다 새로운 클래스가 만들어지지 않는다.

`map()` 을 보면 원본 List 의 모든 원소에 변환 함수를 적용해 얻은 새로운 원소로 이루어진 새로운 List 를 반환한다.

아래는 List 의 각 원소를 `[]` 로 둘러싼 String 으로 변환하는 예시이다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    // {} 안의 내용이 람다
    val result = list.map { n: Int -> "[$n]" }

    println(list)   // [1, 2, 3, 4]
    println(result) // [[1], [2], [3], [4]]
}
```

코틀린은 람다의 타입을 추론할 수 있기 때문에 람다가 필요한 위치에 바로 람다를 적을 수 있다.

바로 위의 코드를 아래처럼 더 간단히 할 수도 있다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    // {} 안의 내용이 람다
    val result = list.map { n: Int -> "[$n]" }
    
    // 람다의 타입을 추론
    // 람다를 List<Int> 타입에서 사용하고 있기 때문에 코틀린은 n 의 타입이 Int 라는 사실을 알 수 있음
    var result2 = list.map { n -> "[$n]" }

    println(list)   // [1, 2, 3, 4]
    println(result) // [[1], [2], [3], [4]]
    println(result2)    // [[1], [2], [3], [4]]
}
```

아래는 람다를 간결하게 표현하는 단계이다.

```kotlin
people.maxBy({ p: Person -> p.age })

// 함수 호출 시 맨 뒤에 있는 인자가 람다식이므로 그 람다를 괄호 밖으로 빼낼 수 있음
people.maxBy() { p: Person -> p.age }

// 람다가 어떤 함수의 유일한 인자이고, 괄호 뒤에 람다를 썼다면 호출 시 빈 괄호 생략 가능
people.maxBy { p: Person -> p.age }

// 파라메터 타입 생략
people.maxBy { p -> p.age }

// 람다의 파라메터가 하나뿐이고, 그 타입을 컴파일러가 추론할 수 있으면 it 으로 변경 간ㅇ
people.maxBy { it.age }
```

실행 시점에 람다 호출에는 아무런 부가 비용이 들지 않는다.

> 실행 시점에 람다 호출에 아무런 부가 비용이 들지 않는 이유에 대해서는 추후 다룰 예정입니다. (p. 203)

---

## 1.1. 함수 파라메터가 하나인 경우: `it`

파라메터가 하나일 경우 코틀린은 자동으로 파라메터 이름을 `it` 으로 만들기 때문에 더 이상 위처럼 _n ->_ 을 사용할 필요가 없다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    val result = list.map { "[$it]" }
    println(result) // [[1], [2], [3], [4]]

    val stringList = listOf("a", "b", "c")
    val result2 = stringList.map({ "${it.uppercase()}" })

    // 함수의 파라메터가 람다뿐이면 람다 주변의 괄호를 없앨 수 있음
    val result3 = stringList.map { "${it.uppercase()}" }
    println(result2)    // [A, B, C]
    println(result3)    // [A, B, C]
}
```

---

## 1.2. 함수 파라메터가 여러 개인 경우

함수가 여러 파라메터를 받고 람다가 마지막 파라메터인 경우엔 람다를 인자 목록을 감싼 괄호 다음에 위치시킬 수 있다.

예를 들어 [joinToString()](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#23-jointostring) 의 마지막 인자로 람다를 지정하면 
이 람다로 컬렉션의 각 원소를 String 으로 변환 후 변환한 모든 String 은 구분자와 prefix/postfix 를 붙여서 하나로 합쳐준다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)

    // 람다를 이름없는 인자로 호출
    val result = list.joinToString(" ") { "[$it]" }
    println(result) // [1] [2] [3] [4]

    // 람다를 이름 붙은 인자로 호출할 때는 인자 목록을 감싸는 괄호 안에 람다를 위치시켜야 함
    val result2 = list.joinToString(
        separator = " ",
        transform = { "[$it]" }
    )
    println(result2)    // [1] [2] [3] [4]
}
```

---

## 1.3. 람다 파라메터가 여러 개인 경우: `mapIndexed()`

```kotlin
fun main() {
    val list = listOf('a', 'b', 'c')
    val result = list.mapIndexed { index, ele -> "[$index:$ele]" }
    println(result) // [[0:a], [1:b], [2:c]]
}
```

`mapIndexed()` 는 List 의 원소와 원소의 인덱스를 함께 람다에 전달하면서 각 원소를 반환한다.  
`mapIndexed()` 에 전달할 람다는 인덱스와 원소를 파라메터로 받아야 한다.

---

## 1.4. 람다가 특정 인자를 사용하지 않는 경우: `_`, `List.indices()`

람다가 특정 인자를 사용하지 않으면 밑줄 `_` 을 사용하여 람다가 어떤 인자를 사용하지 않는다는 컴파일러 경고를 무시할 수 있다.

```kotlin
fun main() {
    val list = listOf('a', 'b', 'c')
    val result = list.mapIndexed { index, _ -> "($index)" }
    val result2 = List(list.size) { index -> "($index)" }
    println(result) // [(0), (1), (2)]
    println(result2)    // [(0), (1), (2)]
}
```

위 함수의 경우 `mapIndexed()` 에 전달한 람다가 원소값은 무시하고 인덱스만 사용했기 때문에 `indices` 에 `map()` 을 적용하여 다시 나타낼 수 있다.

```kotlin
fun main() {
    val list = listOf('a', 'b', 'c')

    // List.indices() 사용
    val result3 = list.indices.map {
        "($it)"
    }
    println(result3)    // [(0), (1), (2)]
}
```

---

## 1.5. 람다에 파라메터가 없는 경우: `run()`

람다에 파라메터가 없는 경우 파라메터가 없다는 것을 강조하기 위해 화살표를 남겨둘 수도 있지만 코틀린 스타일 가이드에서는 화살표를 사용하지 않는 것을 권장한다.

```kotlin
fun main() {
    // 파라메터가 없는 람다의 경우 화살표만 넣은 경우
    run({ -> println("haha") })  // haha

    // 파라메터가 없는 람다의 경우 화살표를 생략한 경우
    run({ println("haha2") })    // () -> kotlin.String

    println({ "haha2" })   //() -> kotlin.String
    println({ "haha2" }.invoke())   // haha2
}
```

`run()` 은 단순히 자신에게 인자로 전달된 람다를 호출하기만 한다.

> `run()` 은 실제로 다른 용도에서 쓰이는데 `run()` 에 대한 좀 더 상세한 내용은 [2. 영역 함수 (Scope Function): `let()`, `run()`, `with()`, `apply()`, `also()`](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#2-%EC%98%81%EC%97%AD-%ED%95%A8%EC%88%98-scope-function-let-run-with-apply-also) 를 참고하세요.

---

## 1.6. 람다를 통해 코드 재사용: `filter()`

아래는 리스트에서 짝수와 홀수를 선택하는 예시이다.

```kotlin
// 짝수 필터
fun filterEven(nums: List<Int>): List<Int> {
    val result = mutableListOf<Int>();
    for (i in nums) {
        if (i % 2 == 0) {
            result += i
        }
    }
    return result
}

// 2보다 큰 수만 필터
fun filterGreaterThanTwo(nums: List<Int>): List<Int> {
    val result = mutableListOf<Int>();
    for (i in nums) {
        if (i > 2) {
            result += i
        }
    }
    return result
}

fun main() {
    val list = listOf(1, 2, 3, 4)
    val evens = filterEven(list)
    val greaterThanTwo = filterGreaterThanTwo(list)

    println(evens)  // [2, 4]
    println(greaterThanTwo) // [3, 4]
}
```

위에서 짝수 필터와 2보다 큰 수를 필터하는 함수가 거의 동일하다.  
이 경우 람다를 사용하여 하나의 함수를 사용할 수 있다.

표준 라이브러리 함수인 `filter()` 는 보존하고 싶은 원소를 선택하는 Predicate (Boolean 값을 돌려주는 함수) 를 인자로 받는데, 이 Predicate 를 람다로 지정하면 된다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)

    val even = list.filter { it % 2 == 0 }
    val greaterThenTwo = list.filter { it > 2 }

    println(even)   // [2, 4]
    println(greaterThenTwo) // [3, 4]
}
```

함수가 훨씬 간결해진 것을 확인할 수 있다.

[함수 타입](https://assu10.github.io/dev/2024/02/17/kotlin-funtional-programming-2/#11-%ED%95%A8%EC%88%98-%ED%83%80%EC%9E%85)과 람다식은 재활용하기 좋은 코드를 만들 때 매우 유용하다.

예를 들어 웹 사이트 방문 기록의 경우 사이트 경로, 사용자 OS 등등의 정보가 있고 여기서 필요한 통계를 추출해야 하는 경우를 보자.

아래는 하드 코딩한 필터를 사용하여 데이터를 분석하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap08

data class SiteVisit(
    val path: String,
    val duration: Double, // 사이트에 머문 시간
    val os: OS,
)

enum class OS {
    WINDOWS,
    LINUX,
    MAC,
    IOS,
    ANDROID,
}

val log =
    listOf(
        SiteVisit("/", 34.0, OS.WINDOWS),
        SiteVisit("/", 22.0, OS.MAC),
        SiteVisit("/login", 12.0, OS.WINDOWS),
        SiteVisit("/signup", 8.0, OS.IOS),
        SiteVisit("/", 16.3, OS.ANDROID),
    )

// 윈도우 사용자에 대해 머문 시간의 평균을 하드 코딩한 필터를 사용하여 분석
val averageWindowsDuration =
    log
        .filter { it.os == OS.WINDOWS }
        .map(SiteVisit::duration)
        .average()

fun main() {
    // 23.0
    println(averageWindowsDuration)
}
```

MAC 운영 체제 사용자에 대해서도 같은 통계를 구하려면 _averageWindowsDuration_ 와 비슷한 필터를 또 만들어야 한다.

아래는 중복을 피하기 위해 일반 함수를 통해 중복을 제거한 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap08

data class SiteVisit1(
    val path: String,
    val duration: Double, // 사이트에 머문 시간
    val os: OS1,
)

enum class OS1 {
    WINDOWS,
    LINUX,
    MAC,
    IOS,
    ANDROID,
}

val log1 =
    listOf(
        SiteVisit1("/", 34.0, OS1.WINDOWS),
        SiteVisit1("/", 22.0, OS1.MAC),
        SiteVisit1("/login", 12.0, OS1.WINDOWS),
        SiteVisit1("/signup", 8.0, OS1.IOS),
        SiteVisit1("/", 16.3, OS1.ANDROID),
    )

// 중복 코드를 별도 함수로 추출하여 확장 함수 선언
fun List<SiteVisit1>.averageDurationFor(os: OS1) =
    filter { it.os == os }
        .map(SiteVisit1::duration)
        .average()

fun main() {
    // 22.0
    println(log1.averageDurationFor(OS1.MAC))
}
```

확장 함수로 불필요한 중복을 제거하여 가독성이 훨씬 좋아졌다.

하지만 만일 모바일 디바이스 사용자의 평균 방문 시간을 구하고 싶다면 아래와 같이 또 하드코딩한 필터를 사용해야 한다.

```kotlin
package com.assu.study.kotlin2me.chap08

data class SiteVisit2(
    val path: String,
    val duration: Double, // 사이트에 머문 시간
    val os: OS2,
)

enum class OS2 {
    WINDOWS,
    LINUX,
    MAC,
    IOS,
    ANDROID,
}

val log2 =
    listOf(
        SiteVisit2("/", 34.0, OS2.WINDOWS),
        SiteVisit2("/", 22.0, OS2.MAC),
        SiteVisit2("/login", 12.0, OS2.WINDOWS),
        SiteVisit2("/signup", 8.0, OS2.IOS),
        SiteVisit2("/", 16.3, OS2.ANDROID),
    )

// 모바일 디바이스 사용자의 평균 방문 시간 (하드 코딩이 들어감)
val averageMobileDuration =
    log2
        .filter { it.os in setOf(OS2.IOS, OS2.ANDROID) }
        .map(SiteVisit2::duration)
        .average()

fun main() {
    // 12.15
    println(averageMobileDuration)
}
```

만일 여기서 IOS 사용자의 '/signup' 페이지의 방문 시간 구하기 와 같은 복잡한 질의를 사용하려면 또 그에 맞는 함수를 만들어야 한다.

이럴 때 람다가 유용하다.

함수 타입을 사용하면 필요한 조건을 파라메터로 뽑아낼 수 있다.

아래는 고차 함수를 사용하여 중복을 제거한 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap08

data class SiteVisit3(
    val path: String,
    val duration: Double, // 사이트에 머문 시간
    val os: OS3,
)

enum class OS3 {
    WINDOWS,
    LINUX,
    MAC,
    IOS,
    ANDROID,
}

val log3 =
    listOf(
        SiteVisit3("/", 34.0, OS3.WINDOWS),
        SiteVisit3("/", 22.0, OS3.MAC),
        SiteVisit3("/login", 12.0, OS3.WINDOWS),
        SiteVisit3("/signup", 8.0, OS3.IOS),
        SiteVisit3("/", 16.3, OS3.ANDROID),
    )

// 고차 함수를 이용하여 중복 제거
fun List<SiteVisit3>.averageDurationFor(predicate: (SiteVisit3) -> Boolean) = filter(predicate).map(SiteVisit3::duration).average()

fun main() {
    // 12.15
    println(log3.averageDurationFor { it.os in setOf(OS3.IOS, OS3.ANDROID) })

    // 8.0
    println(log3.averageDurationFor { it.os == OS3.IOS && it.path == "/signup" })
}
```

---

## 1.7. 람다를 변수에 담기

람다를 `var`, `val` 에 담아 사용하면 여러 함수에 같은 람다를 넘기면서 로직을 재사용할 수 있다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    
    // 람다를 변수에 담아서 사용
    val isEven = { e: Int -> e % 2 == 0 }

    val result = list.filter(isEven)

    // any() 는 주어진 Predicate 를 만족하는 원소가 List 에 하나라도 있는지 검사함
    val result2 = list.any(isEven)

    println(result) // [2, 4]
    println(result2)    // true
}
```

---

## 1.8. 클로저 (Closure)

람다는 자신의 영역 밖에 있는 요소를 참조할 수 있다.  
**함수가 자신이 속한 환경의 요소를 포획(capture) 하거나 닫아버리는(close up) 것을 클로저**라고 한다.  
(람다를 함수에 정의할 때 함수의 파라메터 뿐 아니라 람다 정의의 앞에 선언된 로컬 변수까지 람다에서 사용 가능)

람다가 변수를 포획하면 람다가 생성되는 시점마다 새로운 무명 클래스 객체가 생기는데 이런 경우 실행 시점에 무명 클래스 생성에 따른 부가 비용이 발생한다.

> 이런 경우 람다를 사용하는 구현은 똑같은 작업을 수행하는 일반 함수를 사용하는 구현보다 덜 효율적임  
> 이럴 때 `inline` 변경자를 함수에 붙이면 컴파일러는 그 함수를 호출하는 모든 문장을 함수 본문에 해당하는 바이트코드로 변경해 줌
> 
> 따라서 `inline` 을 사용하면 반복되는 코드를 별도의 라이브러리 함수로 빼내되 컴파일러가 자바의 일반 명령문만큼 효율적인 코드를 생성하게 할 수 있음
> 
> `inline` 에 대해서는 추후 다룰 예정입니다.

자바와 다른 점 중 하나는 코틀린 람다 안에서는 final 변수가 아닌 변수에도 접근 가능할 수 있고, 람다 안에서 바깥의 변수 변경도 된다.

람다 안에서 사용하는 외부 변수를 _람다가 포획(capture) 한 변수_ 라고 한다.

> 람다 실행 시 표현해야 하는 데이터 구조는 람다에서 시작하는 모든 참조가 포함된 닫힌 (closed) 객체 그래프를 람다 코드와 함께 저장해야 함  
> 그런 데이터 구조를 클로저 (closure) 라고 함
> 
> 함수를 1급 시민으로 만들려면 포획한 변수를 제대로 처리해야 하고, 포획한 변수를 제대로 처리하려면 클로저가 꼭 필요함  
> 그래서 람다를 클로저 라고 부르기도 함

기본적으로 함수 안에 정의된 로컬 변수의 생명 주기는 함수가 반환되면 끝나지만 어떤 함수가 자신의 로컬 변수를 포획한 람다를 반환하거나 다른 변수에 저장하면 로컬 변수의 
생명주기와 함수의 생명주기가 달라질 수 있다.  
포획한 변수가 있는 람다를 저장하여 함수가 끝난 뒤에 실행해도 람다의 본문 코드는 여전히 포획한 변수를 읽거나 쓸 수 있다.

클로저가 없는 람다가 있을 수도 있고, 람다가 없는 클로저가 있을 수도 있다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    val divider = 2

    // 람다가 자신의 밖에 정의된 divider 를 포획(capture) 함
    // 람다는 capture 한 요소를 읽거나 변경 가능
    val result = list.filter { it % divider == 0 }

    println(result) // [2, 4]
}
```

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    var sum = 0
    var divider = 2

    // 람다가 capture 한 요소인 sum 을 변경함
    val result = list.filter { it % divider == 0 }.forEach { sum += it }

    println(result) // kotlin.Unit
    println(sum)    // 6
}
```

위 코드는 람다가 가변 함수인 sum 을 capture 하여 변경했지만, 보통은 상태를 변경하지 않는 형태로 코드를 사용한다.

```kotlin
fun main() {
    val list = listOf(1, 2, 3, 4)
    var sum = 0
    var divider = 2

    // 람다가 capture 한 요소인 sum 을 변경함
    val result = list.filter { it % divider == 0 }.forEach { sum += it }
    
    // 람다가 capture 한 요소인 sum 을 변경하지 않고 결과를 얻음
    var result2 = list.filter { it % divider == 0 }.sum()

    println(result) // kotlin.Unit
    println(result2) // 6
    println(sum)    // 6
}
```

아래는 람다가 아닌 일반 함수가 함수 밖의 요소를 capture 하는 예시이다.

```kotlin
var x = 100

// 일반 함수가 함수 밖에 요소를 capture 함
fun useX() {
    x++
}

fun main() {
    useX()
    println(x)  // 101
}
```

람다를 이벤트 핸들러나 비동기적으로 실행되는 코드로 활용하는 경우엔 함수 호출이 끝난 다음에 로컬 변수가 변경될 수 있다.

예를 들어 아래 코드는 버튼 클릭 횟수를 제대로 셀 수 없다.
```kotlin
fun tryToCountButtonClicks(button: Button): Int {
    var clicks = 0
    button.onClick = { clicks++ }
    return clicks;
}
```

onClick 핸들러는 호출될 때마다 _clicks_ 의 값을 증가시키지만 그 값의 변경을 관찰할 수 없으므로 위 함수는 항상 0을 반환한다.  
위 함수를 제대로 구현하려면 클릭 횟수를 세는 변수를 함수 내부가 아니라 클래스의 프로퍼티나 전역 프로퍼티 등의 위치로 빼내서 나중에 변수의 변화를 살펴볼 수 있도록 해야한다.

---

## 1.9. 람다와 `this`

람다에는 무명 객체와 달리 인스턴스 자신을 가리키는 `this` 가 없다.

따라서 람다를 변환한 무명 클래스의 인스턴스를 참조할 방법이 없다.

컴파일러 입장에서 보면 람다는 코드 블록일 뿐이고, 객체가 아니므로 람다를 참조할 수는 없는 것이다.  
**람다 안에서 `this` 는 그 람다를 둘러싼 클래스의 인스턴스를 가리킨다.**

이벤트 리스너가 이벤트를 처리하다가 자기 자신의 리스너 등록을 해제해야 한다면 람다를 사용할 수 없다.  
이런 경우 람다 대신 무명 객체를 사용하여 리스너를 구현해야 한다.  
무명 객체 안에서는 `this` 가 그 무명 객체 인스턴스 자신을 가리키기 때문에 리스너를 해제하는 API 함수에서 `this` 를 넘길 수 있다.

---

## 1.10. 람다의 `return`

루프와 같은 명령형 코드를 람다로 바꾸면 `return` 문제에 부딪히게 된다.  

루프 중간에 있는 `return` 문의 의미를 이해하기는 쉽다.

하지만 그 루프를 `filter()` 와 같이 람다를 호출하는 함수로 변경하고 인자로 전달하는 람다 안에서 `return` 을 사용하게 되면 혼란에 빠지게 된다.

이제 그 부분에 대해 알아본다.

---

### 1.10.1. 람다 안의 `return`: 람다를 둘러싼 함수로부터 반환

아래 코드에서 이름이 _Assu_ 이면 _lookForAssu()_ 함수로부터 반환된다는 사실을 분명히 알 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap08

data class Person3(
    val name: String,
    val age: Int,
)

val person3 = listOf(Person3("Assu", 20), Person3("Silby", 25))

fun lookForAssu(person: List<Person3>) {
    for (p in person) {
        if (p.name == "Assu") {
            println("Found!")
            return
        }
    }
    println("Not Found!")
}

fun main() {
    lookForAssu(person3)    // Found!
}
```

위의 for 문을 forEach 로 변경해도 forEach 에 넘긴 람다 안에 있는 `return` 도 위와 동일한 결과이다.

```kotlin
package com.assu.study.kotlin2me.chap08

data class Person3(
    val name: String,
    val age: Int,
)

val person3 = listOf(Person3("Assu", 20), Person3("Silby", 25))

fun lookForAssu(person: List<Person3>) {
    person.forEach {
        if (it.name == "Assu") {
            println("Found!")
            return
        }
    }
    println("Not Found!")
}

fun main() {
    lookForAssu1(person3) // Found!
}
```

**람다 안에서 `return` 을 사용하면 람다로부터만 반환되는 것이 아니라 그 람다를 호출하는 함수가 실행을 끝내고 반환**된다.

이렇게 **자신을 둘러싸고 있는 블록보다 더 바깥에 있는 다른 블록을 반환하게 만드는 `return` 문을 `non-local return`** 이라고 한다.

**`return` 이 바깥쪽 함수를 반환시킬 수 있을 때는 람다를 인자로 받는 함수가 인라인 함수일 경우일 뿐**이다.  
위의 forEach 는 인라인 함수이므로 람다 본문과 함께 인라이닝되므로 `return` 식이 바깥쪽 함수인 _lookForAssu()_ 를 반환시키도록 컴파일된다.

> `inline` 에 대한 내용은 [Kotlin - 'inline'](https://assu10.github.io/dev/2024/03/16/kotlin-inline/) 을 참고하세요.

하지만 **인라이닝되지 않는 함수에 전달되는 람다 안에서 `return` 을 사용할 수는 없다.**

인라이닝되지 않는 함수에 전달되는 람다를 변수에 저장할 수 있고, 바깥쪽 함수로부터 반환된 뒤에 저장해 둔 람다가 호출될 수도 있다.  
이런 경우 람다 안의 `return` 이 실행되는 시점이 바깥쪽 함수를 반환시키기에 너무 늦은 시점일 수가 있다.

---

### 1.10.2. 람다로부터 반환: 레이블을 이용한 `return`

---

### 1.10.3. 무명 함수: 기본적으로 로컬 `return`

---

# 2. 컬렉션 연산: `hashSetOf()`, `arrayListOf()`, `listOf()`, `hashMapOf()`

코틀린으로 아래와 같이 컬렉션을 만들 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap03

fun main() {
    val set = hashSetOf(1, 1, 2)
    val list = arrayListOf(1, 1, 2)
    val list2 = listOf(1, 1, 2)
    val hashmap = hashMapOf(1 to "one", 2 to "two")

    println(set) // [1, 2]
    println(list) // [1, 1, 2]
    println(list2) // [1, 1, 2]
    println(hashmap) // {1=one, 2=two}

    // javaClass 는 자바에서 getClass() 와 동일
    println(set.javaClass) // class java.util.HashSet
    println(list.javaClass) // class java.util.ArrayList
    println(list2.javaClass) // class java.util.Arrays$ArrayList
    println(hashmap.javaClass) // class java.util.HashMap


    println(list.last()) // 2
    println(set.max()) // 2
}
```

`.javaClass` 는 자바의 `getClass()` 와 동일하며, 해당 객체가 어떤 클래스에 속하는지 알 수 있다.  
위 코드는 코틀린이 자신만의 컬렉션 기능을 제공하지 않는다는 의미이다.

코틀린의 컬렉션은 자바 컬렉션과 똑같은 클래스이지만, 자바보다 더 많은 기능을 사용할 수 있다.  
예) 리스트의 마지막 원소를 가져오거나 최대값 찾기

> 코틀린 타입 시스템 안에서 자바 컬렉션 클래스가 어떻게 표현되는지 추후 상세히 다룰 예정입니다. (p. 105)


함수형 언어는 `map()`, `filter()`, `any()` 처럼 컬렉션을 다룰 수 있는 여러 수단을 제공한다.

여기선 List 와 그 외 컬렉션에 사용되는 다른 연산에 대해 알아본다.

---

## 2.1. List 연산

아래는 List 를 생성하는 여러 방법이다.

```kotlin
fun main() {
    // 람다는 인자로 추가할 원소의 인덱스를 받음
    val list1 = List(10) { it }
    println(list1) // [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    // 하나의 값으로 이루어진 리스트
    val list2 = List(10) { 1 }
    println(list2) // [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]

    // 글자로 이루어진 리스트
    val list3 = List(10) { 'a' + it }
    println(list3) // [a, b, c, d, e, f, g, h, i, j]

    // 정해진 순서를 반복
    val list4 = List(10) { list3[it % 3] }
    val list5 = List(10) { list3[it % 2] }

    println(list4) // [a, b, c, a, b, c, a, b, c, a]
    println(list5) // [a, b, a, b, a, b, a, b, a, b]
}
```

위의 **List 생성자는 인자가 2개**인데 **첫 번째 인자는 생성할 List 의 크기**이고, **두 번째는 생성한 List 의 각 원소를 초기화하는 람다**이다.  
이 람다는 원소의 인덱스를 전달받는다.  
람다가 함수의 마지막 원소인 경우 람다를 인자 목록 밖으로 빼내도 된다.

---

MutableList 도 위의 방법으로 초기화가 가능하다.

```kotlin
fun main() {
    val mutableList1 = MutableList(5, { 10 * (it + 1) })
    
    // 람다가 함수의 마지막 원소이면 람다를 인자 목록 밖으로 빼내도 됨
    val mutableList2 = MutableList(5) { 10 * (it + 1) }
    
    println(mutableList1) // [10, 20, 30, 40, 50]
    println(mutableList2) // [10, 20, 30, 40, 50]
}
```

---

## 2.2. 여러 컬렉션 함수들: `filter()`, `filterNotNull()`, `any()`, `all()`, `none()`, `find()`, `firstOrNull()`, `lastOrNull()`, `count()`

다양한 컬렉션 함수들이 predicate 를 받아서 컬렉션의 원소를 검사한다.

- **`filter()`**
  - 주어진 predicate 가 true 를 리턴하는 모든 원소가 들어있는 새로운 리스트 반환
  - 모든 원소에 predicate 적용
- **`filterNotNull()`**
  - null 을 제외한 원소들로 이루어진 새로운 List 반환
- **`any()`**
  - 원소 중 어느 하나에 대해 predicate 가 true 를 반환하면 true 반환
  - 결과를 찾자마자 이터레이션 중단
- **`all()`**
  - 모든 원소가 predicate 와 일치하는지 검사
- **`none()`**
  - predicate 와 일치하는 원소가 하나도 없는지 검사
- **`find()`**
  - predicate 와 일치하는 첫 번째 원소 반환
  - 원소가 없으면 null 리턴
  - 결과를 찾자마자 이터레이션 중단
- **`firstOrNull()`**
  - `find()` 와 동일
  - predicate 와 일치하는 첫 번째 원소 검사
  - 원소가 없으면 null 반환
  - 조건에 만족하는 원소가 없을 경우 null 을 리턴한다는 사실을 더 명확히 하고 싶으면 `find()` 대신 `firstOrNull()` 사용
- **`lastOrNull()`**
  - predicate 와 일치하는 마지막 원소를 반환하며, 일치하는 원소가 없으면 null 반환
- **`count()`**
  - predicate 와 일치하는 원소의 개수 반환
  - 모든 원소에 predicate 적용

`all()` 과 `any()` 의 예시
```kotlin
package com.assu.study.kotlin2me.chap05

data class Person5(
    val name: String,
    val age: Int,
)

fun main() {
    val persons = listOf(Person5("assu", 20), Person5("silby", 2), Person5("jaehun", 22))

    val canBeOrder20 = { p: Person5 -> p.age >= 20 }

    // all(): 모든 원소가 만족하는지 확인
    // false
    println(persons.all(canBeOrder20))

    // any(): 하나의 원소라도 만족하는지 확인
    // true
    println(persons.any(canBeOrder20))
}
```

어떤 조건에 대해 `!all()` 을 수행한 결과와 그 조건에 대한 부정에 대해 `any()` 를 수행한 결과는 같다.  
가독성을 높이려면 `any()` 와 `all()` 앞에 `!` 를 붙이지 않는 것이 좋다.

아래는 그 예시이다.
```kotlin
package com.assu.study.kotlin2me.chap05

fun main() {
    val list = listOf(1, 2, 3)

    // 모든 원소 중 적어도 하나는 3이 아닌지 확인

    // ! 를 보지 못할수도 있으므로 아래 식 보다는 any() 사용 추천
    // true
    println(!list.all { it == 3 })

    // 가독성을 위해 아래를 권장
    // true
    println(list.any { it != 3 })
}
```

`count()` 를 이용하여 조건에 만족하는 원소 갯수 구하는 예시
```kotlin
package com.assu.study.kotlin2me.chap05

data class Person6(
  val name: String,
  val age: Int,
)

fun main() {
  val persons = listOf(Person6("assu", 20), Person6("silby", 2), Person6("jaehun", 22))

  // `count()` 를 이용하여 조건에 만족하는 원소 갯수 구하기
  // 2
  println(persons.count { p: Person6 -> p.age >= 20 })
}
```

**`count()` 를 사용할 수 있는 조건에서 `size` 를 사용하여 컬렉션을 필터링한 결과를 크기를 가져오는 실수**를 할 때가 있다.  
`size` 를 사용하면 조건을 만족하는 모든 원소가 포함된 중간 컬렉션이 생긴다.  
반면, `count()` 는 조건에 만족하는 원소의 갯수만을 추적하므로 조건을 만족하는 원소를 따로 저장하지 않기 때문에 `count()` 가 훨씬 효율적이다.

아래는 그 예시이다.
```kotlin
package com.assu.study.kotlin2me.chap05

data class Person7(
    val name: String,
    val age: Int,
)

fun main() {
    val persons = listOf(Person7("assu", 20), Person7("silby", 2), Person7("jaehun", 22))
    val canBeOrder20 = { p: Person7 -> p.age >= 20 }

    // `count()` 대신 size 를 사용하는 비효율적인 코드
    // 2
    println(persons.filter(canBeOrder20).size)
    
    // `count()` 를 이용한 효율적인 코드
    // 2
    println(persons.count(canBeOrder20))
}
```

`find()` 와 `firstOrNull()` 의 예시
```kotlin
package com.assu.study.kotlin2me.chap05

data class Person8(
    val name: String,
    val age: Int,
)

fun main() {
    val persons = listOf(Person8("assu", 20), Person8("silby", 2), Person8("jaehun", 22))
    val canBeYounger30 = { p: Person8 -> p.age <= 30 }
    val canBeYounger1 = { p: Person8 -> p.age <= 1 }

    // find() 를 사용하여 조건에 만족하는 원소가 있을 경우 첫 번째 원소 리턴
    // Person8(name=assu, age=20)
    println(persons.find(canBeYounger30))

    // firstOrNull() 을 사용하여 조건에 만족하는 원소가 있을 경우 첫 번째 원소 리턴
    // Person8(name=assu, age=20)
    println(persons.firstOrNull(canBeYounger30))

    // 조건에 만족하는 원소가 없을 경우
    // null
    println(persons.find(canBeYounger1))

    // null
    println(persons.firstOrNull(canBeYounger1))
}
```

`filterNotNull()` 을 사용하여 컬렉션 안에 null 이 없음을 보장하는 예시

```kotlin
package com.assu.study.kotlin2me.chap06

// null 인 원소 걸러내기
fun addValidNumbers(numbers: List<Int?>): List<Int> {
    val validNumbers = numbers.filterNotNull()
    return validNumbers
}

fun main() {
    val numbers = addValidNumbers(listOf(1, 2, null, 5))

    // [1, 2, 5]
    println(numbers)
}
```


```kotlin
fun main() {
    val list = listOf(-3, -1, 0, 3, 5, 9)

    // filter(), count()
    val result1 = list.filter { it > 0 }
    val result2 = list.count { it > 0 }

    println(result1) // [3, 5, 9]
    println(result2) // 3

    // filterNotNull()
    val list2 = listOf(1, 2, null)
    println(list2.filterNotNull())  // [1, 2]
    
    // find(), firstOrNull(), lastOrNull()
    val result3 = list.find { it > 0 }

    val result4 = list.firstOrNull { it > 0 }
    val result5 = list.lastOrNull { it > 0 }
    val result6 = list.firstOrNull { it < 0 }
    val result7 = list.lastOrNull { it < 0 }

    println(result3) // 3

    println(result4) // 3
    println(result5) // 9
    println(result6) // -3
    println(result7) // -1

    // any()
    val result8 = list.any { it > 0 }
    val result9 = list.any { it != 0 }

    println(result8) // true
    println(result9) // true

    // all()
    val result10 = list.all { it > 0 }
    val result11 = list.all { it != 0 }

    println(result10) // false
    println(result11) // false

    // none()
    val result12 = list.none { it > 0 }
    val result13 = list.none { it == 0 }

    println(result12) // false
    println(result13) // false
}
```

---

## 2.3. `filterNot()`, `partition()`

`filter()` 는 predicate 를 만족하는 원소들을 반환하는 반면, `filterNot()` 은 predicate 를 만족하지 않는 원소들을 반환한다.

`partition()` 은 동시에 양쪽 (predicate 를 만족하는 원소와 만족하지 않는 원소) 을 생성한다.  
`partition()` 은 List 가 들어있는 `Pair` 객체를 생성한다. 


```kotlin
fun main() {
    val list = listOf(-3, -1, 0, 5, 7)
    val isPositive = { i: Int -> i > 0 }

    // filter(), filterNot()
    val result1 = list.filter(isPositive)
    val result2 = list.filterNot(isPositive)

    println(result1) // [5, 7]
    println(result2) // [-3, -1, 0]

    // partition()
    val (pos, neg) = list.partition(isPositive)
    val (pos1, neg1) = list.partition { it > 0 }

    println(pos) // [5, 7]
    println(neg) // [-3, -1, 0]
    println(pos1) // // [5, 7]
    println(neg1) // [-3, -1, 0]
}
```

---

## 2.4. 커스텀 함수의 반환값에 구조 분해 선언 사용

[7. 구조 분해 (destructuring) 선언](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#7-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4-destructuring-%EC%84%A0%EC%96%B8) 에서 본 것처럼 
구조 분해 선언을 사용하면 동시에 Pair 원소로 초기화할 수 있다.

```kotlin
fun createPair() = Pair(1, "one")

fun main() {
    val (i, s) = createPair()

    println(i) // 1
    println(s)  // one
}
```

---

## 2.5. `sumOf()`, `sortedBy()`, `minBy()`, `takeXX()`, `dropXX()`

[3. 리스트](https://assu10.github.io/dev/2024/02/09/kotlin-object/#3-%EB%A6%AC%EC%8A%A4%ED%8A%B8) 에서 수 타입으로 정의된 리스트에 대해 
`sum()` 이나 비교 가능한 원소로 이루어진 리스트에 적용할 수 있는 `sorted()` 를 보았다.

만약 리스트의 원소가 숫자가 아니거나, 비교 가능하지 않으면 `sum()`, `sorted()` 대신 `sumBy()`, `sortedBy()` 를 사용할 수 있다.  
이 함수들은 덧셈, 정렬 연산에 사용할 특성값을 돌려주는 함수(보통 람다)를 인자로 받는다.

`sorted()`, `sortedBy()` 는 컬렉션을 오름차순으로 정렬하고, `sortedDescending()`, `sortedByDescending()` 은 컬렉션을 내림차순으로 정렬한다.

`minBy()` 는 주어진 비교 기준에 따라 최소값을 돌려주며, 리스트가 비어있으면 null 을 리턴한다.

> `sumBy()` 는 코틀린 1.5 부터 deprecated 예고됨  
> `sumBy()`, `sumByDouble()` 은 컬렉션에 있는 값을 모두 더했을 때 overflow 가 발생할 수 있기 때문에 코틀린 1.5 부터는 deprecated 예고를 하고, `sumOf()` 를 권장함  
> 
> `sumOf()` 의 경우 `sumBy()` 와 마찬가지로 람다를 인자로 받지만 이 람다가 반환하는 값의 타입을 이용하여 합계를 계산하기 때문에 overflow 가 발생할 여지가 있는 경우 
> 람다가 값을 BigInteger, BigDecimal 로 변환하여 돌려주면 됨
> 
> 예를 들어 **_list.sumByDouble { it.price }_ 가 너무 커질 경우 _list.sumOf { it.price.toBigDecimal() }_ 이라고 하면 큰 범위의 실수로 합계를 구할 수 있음**

```kotlin
data class Product(
    val desc: String,
    val price: Double,
)

fun main() {
    val products =
        listOf(
            Product("paper", 2.0),
            Product("pencil", 7.0),
        )

    val result1 = products.sumOf { it.price }
    println(result1) // 9.0

    val result2 = products.sortedByDescending { it.price }
    println(result2) // [Product(desc=pencil, price=7.0), Product(desc=paper, price=2.0)]

    val result3 = products.minByOrNull { it.price }
    println(result3) // Product(desc=paper, price=2.0)
}
```

`take()`, `drop()` 은 각각 첫 번째 원소를 취하거나 제거하고, `takeLast()`, `dropLast()` 는 각각 마지막 원소를 취하거나 제거한다.

4개 함수 모두 취하거나 제거할 대상을 지정하는 람다를 받는 버전도 있다.

```kotlin
fun main() {
    val list1 = listOf('a', 'b', 'c', 'X', 'z')
    val list2 = listOf('a', 'b', 'c', 'X', 'Z')

    var result1 = list1.takeLast(3)
    println(result1) // [c, X, z]

    var result2 = list1.takeLastWhile { it.isUpperCase() }
    var result3 = list2.takeLastWhile { it.isUpperCase() }
    println(result2) // []
    println(result3) // [X, Z]

    var result4 = list1.drop(1)
    println(result4) // [b, c, X, z]

    var result5 = list1.dropWhile { it.isUpperCase() }
    var result6 = list2.dropWhile { it.isUpperCase() }
    println(result5) // [a, b, c, X, z]
    println(result6) // [a, b, c, X, Z]

    var result7 = list1.dropWhile { it.isLowerCase() }
    var result8 = list2.dropWhile { it.isLowerCase() }
    println(result7) // [X, z]
    println(result8) // [X, Z]
}
```

---

## 2.6. Set 의 연산

위에서 본 List 연산들 중 대부분은 Set 에도 사용이 가능하다.

단, **`findByFirst()` 처럼 컬렉션에 저장된 원소 순서에 따라 결과가 달라질 수 있는 연산을 Set 에 적용하면 실행할 때마다 다른 결과를 내놓을 수 있는 점에 유의**해야 한다.

```kotlin
fun main() {
  val set = setOf("a", "ab", "ac")

  // maxByOrNull()
  // 컬렉션이 비어있으면 null 을 반환하기 때문에 결과 타입이 null 이 될 수 있는 타입임
  val result1 = set.maxByOrNull { it.length }?.length
  println(result1) // 2

  // filter()
  val result2 =
    set.filter {
      it.contains('b')
    }
  println(result2) // [ab]

  // map()
  val result3 = set.map { it.length }
  println(result3) // [1, 2, 2]
}
```

**`filter()`, `map()` 을 Set 에 적용하면 List 로 결과를 반환**받는다.


---

# 3. 멤버 참조: `::`

함수 인자로 멤버 참조 `::` 를 전달할 수 있다.

멤버 함수나 프로퍼티 이름 앞에 그들이 속한 클래스 이름과 `::` 를 위치시켜서 멤버 참조를 만들 수 있다.

멤버 참조는 프로퍼티나 메서드를 단 하나만 호출하는 함수값을 만들어준다.

```kotlin
// 멤버 참조 예시
val getAge = Person::age

// 람다식 예시
val getAge = { person: Person -> person.age }
```

멤버 참조는 그 멤버를 호출하는 람다와 같은 타입이므로 아래처럼 자유롭게 바꿔서 사용할 수 있다.    
이런 것을 에타 변환이라고 한다.
```kotlin
people.maxBy { Person::age }
people.maxBy { p -> p.age }
people.maxBy { it.age }
```

> **에타 변환 (Eta conversion)**  
> 
> 함수 `f` 와 람다 `{ x -> f(x) }` 를 서로 바꿔서 사용하는 것을 의미함

---

## 3.1. 프로퍼티 참조: `sortedWith()`, `compareBy()`

인자로 넘길 predicate 에 대해 람다를 넘길 수도 있지만, _Message::isRead_ 라는 프로퍼티 참조를 넘길 수도 있다.

아래는 프로퍼티에 대한 멤버 참조 예시이며, _Message::isRead_ 가 멤버 참조이다.

```kotlin
data class Message(
    val sender: String,
    val text: String,
    val isRead: Boolean,
)

fun main() {
    val message =
        listOf(
            Message("Assu", "Hello", true),
            Message("Silby", "Bow!", false),
        )

    val unread = message.filterNot(Message::isRead)
    println(unread) // [Message(sender=Silby, text=Bow!, isRead=false)]
    println(unread.size) // 1
    println(unread.single().text) // Bow!
}
```

객체의 기본적인 대소 비교를 따르지 않도록 정렬 순서를 지정해야 하는 경우 프로퍼티 참조가 유용하다.

위에서 `single()` 은 원소가 하나일 경우에만 사용 가능하다.

```kotlin
package assu.study.kotlinme.chap04.memberReference

data class Message(
    val sender: String,
    val text: String,
    val isRead: Boolean,
)

fun main() {
    val message =
        listOf(
            Message("Assu", "Hello", true),
            Message("Silby", "Bow!", false),
            Message("Silby2", "Bow2!", false),
        )

    val unread = message.filterNot(Message::isRead)
    println(unread) // [Message(sender=Silby, text=Bow!, isRead=false), Message(sender=Silby2, text=Bow2!, isRead=false)]
    println(unread.size) // 2
  
    // 런타임 오류
    // java.lang.IllegalArgumentException: List has more than one element.
    println(unread.single().text)
}
```

> **`sorted()` 를 호출하면 원본의 요소들을 정렬한 새로운 List 를 리턴하고 원래의 List 는 그대로 남아있다.**    
**`sort()` 를 호출하면 원본 리스트를 변경**한다.

```kotlin
data class Message1(
    val sender: String,
    val text: String,
    val isRead: Boolean,
)

fun main() {
    val messages =
        listOf(
            Message1("Assu", "AAA", true),
            Message1("Assu", "CCC", false),
            Message1("Silby", "BBB", false),
        )

    // isRead 가 false 순으로 정렬 후 text 순으로 정렬
    val result1 =
        messages.sortedWith(
            compareBy(
                Message1::isRead,
                Message1::text,
            ),
        )

    // [Message1(sender=Silby, text=BBB, isRead=false), Message1(sender=Assu, text=CCC, isRead=false), Message1(sender=Assu, text=AAA, isRead=true)]
    println(result1)
}
```

`sortedWith()` 는 `comparator` 를 사용하여 리스트를 정렬하는 라이브러리 함수이다.

---

## 3.2. 함수 참조

List 에 복잡한 기준으로 요소를 추출해야 할 경우 이 기준을 람다로 넘길수도 있지만, 그러면 람다가 복잡해진다.  
이럴 때 람다를 별도의 함수로 추출하면 가독성이 좋아진다.

**코틀린은 함수 타입이 필요한 곳에 바로 함수를 넘길수는 없지만 대신 그 함수에 대한 참조를 넘길 수 있다.**

```kotlin
data class Message2(
    val sender: String,
    val text: String,
    val isRead: Boolean,
    val attachments: List<Attachment>,
)

data class Attachment(
    val type: String,
    val name: String,
)

// Message2.isImportant() 라는 확장 함수
fun Message2.isImportant(): Boolean =
    text.contains("Money") ||
        attachments.any {
            it.type == "image" && it.name.contains("dog")
        }

fun main() {
    val messages =
        listOf(
            Message2(
                "Assu",
                "gogo",
                false,
                listOf(Attachment("image", "cute dog")),
            ),
        )
    // any() 에 확장 함수에 대한 참조를 전달
    val result = messages.any(Message2::isImportant)
    println(result) // true
}
```

Message2 를 유일한 파라메터로 받는 최상위 수준 함수가 있다면 이 함수를 참조로 전달할 수 있다.  
최상휘에 선언된 함수 뿐 아니라 프로퍼티도 참조 가능하다.  
**최상위 수준 함수에 대한 참조를 만들 때는 클래스 이름이 없기 때문에 `::함수명`** 처럼 쓴다.

최상위 함수를 참조하는 예시
```kotlin
fun hello() = println("hello~")

fun main() {
    // 최상위 함수 참조
    run(::hello) // run() 은 인자로 받은 람다를 호출함
  
    // hello~
}
```

```kotlin
package assu.study.kotlinme.chap04.memberReference

data class Message3(
  val sender: String,
  val text: String,
  val isRead: Boolean,
  val attachments: List<Attachment3>,
)

data class Attachment3(
  val type: String,
  val name: String,
)

// Message2.isImportant() 라는 확장 함수
fun Message3.isImportant(): Boolean =
  text.contains("Money") ||
          attachments.any {
            it.type == "image" && it.name.contains("dog")
          }

fun ignore(message: Message3): Boolean = !message.isImportant() && message.sender in setOf("Assu", "Silby")

fun main() {
  val message =
    listOf(
      Message3("Assu", "gogo!", false, listOf()),
      Message3("Assu2", "gogo!2", false, listOf()),
      Message3(
        "Assu",
        "gogo!",
        false,
        listOf(
          Attachment3("image", "cute dog"),
        ),
      ),
    )

  // 최상위 수준 함수에 대한 참조 전달
  val result1 = message.filter(::ignore)

  // `count()` 대신 size 를 사용하는 비효율적인 코드
  val result2 = message.filter(::ignore).size
  val result3 = message.count(::ignore)

  println(result1) // [Message3(sender=Assu, text=gogo!, isRead=false, attachments=[])]
  println(result2) // 1
  println(result3) // 1

  val result4 = message.filterNot(::ignore)
  val result5 = message.filterNot(::ignore).size

  println(result4) // [Message3(sender=Assu, text=gogo!, isRead=false, attachments=[Attachment3(type=image, name=cute dog)])]
  println(result5) // 1
}
```

> `count()` 대신 size 를 사용하는 비효율적인 코드인 이유는 [2.2. 여러 컬렉션 함수들: `filter()`, `filterNotNull()`, `any()`, `all()`, `none()`, `find()`, `firstOrNull()`, `lastOrNull()`, `count()`](#22-여러-컬렉션-함수들-filter-filternotnull-any-all-none-find-firstornull-lastornull-count) 를 참고하세요.

---

## 3.3. 생성자 참조: `mapIndexed()`

클래스명을 이용하여 생성자에 대한 참조를 만들수도 있다.

**생성자 참조를 사용하면 클래스 생성 작업을 연기하거나 저장**해둘 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap05

class Person(
    private val name: String, // 읽기 전용 프로퍼티, 비공개 필드와 getter 생성
    private var age: Int, // 쓰기 가능 프로퍼티, 비공개 필드와 공개 getter/setter 생성
) {
    override fun toString(): String = "Person(name='$name', age=$age)"
}

fun main() {
    // Person 의 인스턴스를 만드는 동작을 값으로 저장
    val createPersonInstance = ::Person

    val p = createPersonInstance("ASSU", 20)

    // Person(name='ASSU', age=20)
    println(p)
}
```

아래에서 _names.mapIndexed()_ 는 생성자 참조인 `::Student` 를 받는다.

> `mapIndexed()` 는 [1.3. 람다 파라메터가 여러 개인 경우: `mapIndexed()`](#13-람다-파라메터가-여러-개인-경우-mapindexed) 를 참고하세요.

```kotlin
data class Student(
    val id: Int,
    val name: String,
)

fun main() {
    val names = listOf("Assu", "Silby")
    
    // mapIndexed() 에 인덱스와 원소를 명시적으로 생성자에 넘김
    val students =
        names.mapIndexed { index, name -> Student(index, name) }

    println(students) // [Student(id=0, name=Assu), Student(id=1, name=Silby)]

    // mapIndexed() 에 생성자 참조를 인자로 넘김
    val result = names.mapIndexed(::Student)
    println(result) // [Student(id=0, name=Assu), Student(id=1, name=Silby)]
}
```

위처럼 함수와 생성자 참조를 사용하면 단순히 람다로 전달해야 하는 긴 파라메터 리스트를 지정하지 않아도 되기 때문에 람다를 사용할 때보다 가독성이 좋아진다.

---

## 3.4. 확장 함수 참조: `times()`

**확장 함수에 대한 참조는 참조 앞에 확장 대상 타입 이름을 붙이면 된다.**

```kotlin
fun Int.times12() = times(12)

class Dog

fun Dog.speak() = "Bow!"

fun goInt(
    n: Int,
    g: (Int) -> Int,
) = g(n)

fun goDog(
    dog: Dog,
    g: (Dog) -> String,
) = g(dog)

fun main() {
    val result1 = goInt(11, Int::times12)
    val result2 = goDog(Dog(), Dog::speak)  // 확장 함수도 멤버 함수와 동일한 방식으로 참조 가능

    println(result1) // 132 (11*12 이므로)
    println(result2) // Bow!
}
```

> **바운드 멤버 참조**  
> 
> 코틀린 1.0 에서는 클래스의 메서드나 프로퍼티에 대한 참조를 얻은 후 그 참조를 호출할 때 항상 인스턴스 객체를 제공해야 했음
> 
> 코틀린 1.1 부터는 바운드 멤버 참조를 지원하는데, 바운드 멤버 참조를 사용하게 되면 멤버 참조를 생성할 때 클래스 인스턴스를 함께 저장한 다음 나중에 그 인스턴스에 대해 
> 멤버를 호출함  
> 따라서 호출 시 수신 대상 객체를 별도로 지정해 줄 필요가 없음

바운드 멤버 참조 예시
```kotlin
class Person2(
val name: String, // 읽기 전용 프로퍼티, 비공개 필드와 getter 생성
var age: Int, // 쓰기 가능 프로퍼티, 비공개 필드와 공개 getter/setter 생성
) {
override fun toString(): String = "Person(name='$name', age=$age)"
}

fun main() {
val p = Person2("Assu", 30)

    // 인자가 하나(인자로 받은 사람의 나이를 반환)임
    val personAgeFunction = Person2::age

    println(personAgeFunction(p)) // 30

    // 코틀린 1.1 부터 사용 가능한 바운드 멤버 참조
    // 인자가 없는(참조를 만들 때 p 가 가리키던 사람의 나이를 반환) 함수임
    val boundMemberReferenceAgeFunction = p::age
    println(boundMemberReferenceAgeFunction())  // 30
}
```


---

# 4. 최상위 함수와 프로퍼티 (정적인 유틸리티 클래스 없애기)

## 4.1. 최상위 함수: `@JvmName`

> 정적 유틸리티 함수를 사용하고 싶을 경우 최상위 함수를 사용하면 됨

객체지향 언어인 자바에서는 모든 코드를 클래스의 메서드로 작성해야 한다.  
그럴 경우 특정 연산을 객체의 인스턴스 API 에 추가해서 사용해야 한다.

그 결과 다양한 정적 메서드를 모아두는 역할만 담당하며, 특별한 상태나 인스턴스 메서드는 없는 클래스들이 생겨났다.  
JDK 의 `Collections` 클래스가 그 전형적인 예시이다.

코틀린에서는 이런 무의미한 클래스가 필요없다.  
대신 **함수를 소스 파일의 최상위 수준, 클래스의 밖에 위치**시키면 된다.  
이런 함수들은 여전히 그 파일의 맨 앞에 정의된 패키지의 멤버 함수이므로 **다른 패키지에서 그 함수를 사용하고 싶을 때는 그 함수가 정의된 패키지를 
임포트해야 하지만 임포트 시 유틸리티 클래스의 이름이 추가로 들어갈 필요는 없다.**

_test()_ 라는 함수를 Join.kt 라는 파일에 최상위에 정의해보자.
```kotlin
package com.assu.study.kotlin2me.chap03

fun test(): String = "TEST"
```

JVM 은 클래스 안에 있는 코드만을 실행할 수 있기 때문에 컴파일러는 이 파일을 컴파일할 때 새로운 클래스를 정의해준다.

만일 위의 _test()_ 함수를 자바 등 다른 JVM 언어에서 호출하고 싶다면 코드가 어떻게 컴파일되는지 알아야 _test()_ 같은 최상위 함수를 사용할 수 있으므로 
코틀린이 위의 파일을 컴파일한 결과를 자바 코드로 한번 보자.

```java
package com.assu.study.kotlin2me.chap03;

public class JoinKt {
  public static String test() {
      return "TEST";
  }    
}
```

코틀린 컴파일러가 생성하는 클래스 이름은 최상위 함수가 들어있던 코틀린 소스 파일의 이름과 동일하며, 코틀린 파일의 모든 최상위 함수는 이 클래스의 정적인 메서드가 된다.

따라서 자바에서 _test()_ 를 호출할 때는 아래와 같이 호출하면 된다.
```java
import com.assu.study.kotlin2me.chap03.JoinKt;

// ...

JoinKt.test();
```

만일 코틀린 최상위 함수가 포함되는 클래스의 이름을 변경하고 싶으면 파일에 `@JvmName` 애너테이션을 파일의 맨 앞, 패키지 이름 선언 이전에 위치시키면 된다.

코틀린
```kotlin
@file:JvmName("StringFunctions")    // 클래스 이름을 지정하는 애너테이션

package com.assu.study.kotlin2me.chap03 // @file:JvmName 애너테이션 뒤에 패키지 문이 와야 함

fun test(): String = "TEST"
```

그러면 자바에서 아래와 같이 호출할 수 있다.

자바
```java
import com.assu.study.kotlin2me.chap03.StringFunctinos;

// ...

StringFunctions.test();
```

> `@JvmName` 애너테이션 문법에 대한 상세한 설명은 추후 다룰 예정입니다. (p. 113)

---

## 4.2. 최상위 프로퍼티: `const`

함수와 마찬가지로 프로퍼티도 파일의 최상위 수준에 놓을 수 있다. 이런 프로퍼티 값은 정적 필드에 저장된다.

어떤 데이터를 클래스 밖에 위치시키는 경우는 흔치 않지만 가끔은 유용한 경우가 있다.  
예) 연산을 수행하는 횟수를 지정하는 var 프로퍼티

```kotlin
package com.assu.study.kotlin2me.chap03

var opCount = 0 // 최상위 프로퍼티

fun performOperation() {
    opCount++ // 최상위 프로퍼티 값 변경
}

fun readOperation() {
    println("opCount: $opCount") // 최상위 프로퍼티 값 읽음
}

fun main() {
    performOperation()
    performOperation()
    readOperation() // opCount: 2
}
```

> 최상위 프로퍼티의 또 다른 사용 예시는 [1.1. 소수의 특별한 타입을 위한 확장 함수 이용](https://assu10.github.io/dev/2024/03/02/kotlin-object-oriented-programming-4/#11-%EC%86%8C%EC%88%98%EC%9D%98-%ED%8A%B9%EB%B3%84%ED%95%9C-%ED%83%80%EC%9E%85%EC%9D%84-%EC%9C%84%ED%95%9C-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-%EC%9D%B4%EC%9A%A9) 의 `Any.name` 을 참고하세요.

최상위 프로퍼티 값으로 상수를 추가할 수도 있다.

```kotlin
val UNIX_LINE_SEPARATOR = "\n"
```

최상위 프로퍼티도 다른 프로퍼티처럼 접근자 메서드를 통해 자바 코드에 노출된다.  
**val 는 getter 가 생성되고, var 는 getter/setter 가 생성**된다.

상수인데 getter 를 사용하면 자연스럽지 못하므로 이 **상수를 public static final 필드로 컴파일하려면 `const` 변경자를 추가**하면 된다.  
단, primitive 타입과 String 타입의 프로퍼티만 const 지정이 가능하다.

```kotlin
// const 변경자 추가 시 컴파일하면 public static final 로 컴파일됨
const val UNIX_LINE_SEPARATOR = "\n"
```

위 코드가 컴파일되면 아래와 같이 된다.
```java
public static final String UNIX_LINE_SEPARATOR = "\n";
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