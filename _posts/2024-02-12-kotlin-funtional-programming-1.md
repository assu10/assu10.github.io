---
layout: post
title:  "Kotlin - 함수형 프로그래밍(1): 람다, 컬렉션 연산, 멤버 참조"
date:   2024-02-12
categories: dev
tags: kotlin lambda mapIndexed() indices() run() filter() closure, filter() filterNotNull() any() all() none() find() firstOrNull() lastOrNull() count() filterNot() partition() sumof() sortedBy() minBy() take() drop(), sortedWith() compmareBy() times()
---

코틀린 여러 함수 기능에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 람다](#1-람다)
  * [1.1. 함수 파라메터가 하나인 경우](#11-함수-파라메터가-하나인-경우)
  * [1.2. 함수 파라메터가 여러 개인 경우](#12-함수-파라메터가-여러-개인-경우)
  * [1.3. 람다 파라메터가 여러 개인 경우: `mapIndexed()`](#13-람다-파라메터가-여러-개인-경우-mapindexed)
  * [1.4. 람다가 특정 인자를 사용하지 않는 경우: `List.indices()`](#14-람다가-특정-인자를-사용하지-않는-경우-listindices)
  * [1.5. 람다에 파라메터가 없는 경우: `run()`](#15-람다에-파라메터가-없는-경우-run)
  * [1.6. 람다를 통해 코드 재사용: `filter()`](#16-람다를-통해-코드-재사용-filter)
  * [1.7. 람다를 변수에 담기](#17-람다를-변수에-담기)
  * [1.8. 클로저 (Closure)](#18-클로저-closure)
* [2. 컬렉션 연산](#2-컬렉션-연산)
  * [2.1. List 연산](#21-list-연산)
  * [2.2. 여러 컬렉션 함수들: `filter()`, `filterNotNull()`, `any()`, `all()`, `none()`, `find()`, `firstOrNull()`, `lastOrNull()`, `count()`](#22-여러-컬렉션-함수들-filter-filternotnull-any-all-none-find-firstornull-lastornull-count)
  * [2.3. `filterNot()`, `partition()`](#23-filternot-partition)
  * [2.4. 커스텀 함수의 반환값에 구조 분해 선언 사용](#24-커스텀-함수의-반환값에-구조-분해-선언-사용)
  * [2.5. `sumOf()`, `sortedBy()`, `minBy()`, `take()`, `drop()`](#25-sumof-sortedby-minby-take-drop)
  * [2.6. Set 의 연산](#26-set-의-연산)
* [3. 멤버 참조: `::`](#3-멤버-참조-)
  * [3.1. 프로퍼티 참조: `sortedWith()`, `compareBy()`](#31-프로퍼티-참조-sortedwith-compareby)
  * [3.2. 함수 참조](#32-함수-참조)
  * [3.3. 생성자 참조: `mapIndexed()`](#33-생성자-참조-mapindexed)
  * [3.4. 확장 함수 참조: `times()`](#34-확장-함수-참조-times)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle

---

# 1. 람다

람다는 함수 리터럴이라고도 부르며, 이름이 없고 함수 생성에 필요한 최소한의 코드만 필요하며, 다른 코드에 람다를 직접 삽입할 수 있다.

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

---

## 1.1. 함수 파라메터가 하나인 경우

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

## 1.4. 람다가 특정 인자를 사용하지 않는 경우: `List.indices()`

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

위 코드는 람다가 가변 함수는 sum 을 capture 하여 변경했지만, 보통은 상태를 변경하지 않는 형태로 코드를 사용한다.

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

---

# 2. 컬렉션 연산

함수형 언어는 `map()`, `filter()`, `any()` 처럼 컬렉션을 다룰 수 있는 여러 수단을 제공한다.

여기선 List 와 그 외 컬렉션에 사용되는 다른 연산에 대해 알아본다.

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

위의 List 생성자는 인자가 2개인데 첫 번째 인자는 생성할 List 의 크기이고, 두 번째는 생성한 List 의 각 원소를 초기화하는 람다이다.  
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

- `filter()`
  - 주어진 predicate 가 true 를 리턴하는 모든 원소가 들어있는 새로운 리스트 반환
  - 모든 원소에 predicate 적용
- `filterNotNull()`
  - null 을 제외한 원소들로 이루어진 새로운 List 반환
- `any()`
  - 원소 중 어느 하나에 대해 predicate 가 true 를 반환하면 true 반환
  - 결과를 찾자마자 이터레이션 중단
- `all()`
  - 모든 원소가 predicate 와 일치하는지 검사
- `none()`
  - predicate 와 일치하는 원소가 하나도 없는지 검사
- `find()`
  - predicate 와 일치하는 첫 번째 원소 검사
  - 원소가 없으면 예외를 던짐
  - 결과를 찾자마자 이터레이션 중단
- `firstOrNull()`
  - predicate 와 일치하는 첫 번째 원소 검사
  - 원소가 없으면 null 반환
- `lastOrNull()`
  - predicate 와 일치하는 마지막 원소를 반환하며, 일치하는 원소가 없으면 null 반환
- `count()`
  - predicate 와 일치하는 원소의 개수 반환
  - 모든 원소에 predicate 적용

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

## 2.5. `sumOf()`, `sortedBy()`, `minBy()`, `take()`, `drop()`

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

`take()`, `drop()` 은 각각 첫 번째 원소를 취하거나 제거하고, `takeLast()`, `dropLast()` 는 각각 마지막 원소를 위하거나 제거한다.

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
**최상위 수준 함수에 대한 참조를 만들 때는 클래스 이름이 없기 때문에 `::함수명`** 처럼 쓴다.

```kotlin
ata class Message3(
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
    val result2 = message.filter(::ignore).size
    println(result1) // [Message3(sender=Assu, text=gogo!, isRead=false, attachments=[])]
    println(result2) // 1

    val result3 = message.filterNot(::ignore)
    val result4 = message.filterNot(::ignore).size
    println(result3) // [Message3(sender=Assu, text=gogo!, isRead=false, attachments=[Attachment3(type=image, name=cute dog)])]
    println(result4) // 1
}
```

---

## 3.3. 생성자 참조: `mapIndexed()`

클래스 명을 이용하여 생성자에 대한 참조를 만들수도 있다.

아래에서 _names.mapIndexed()_ 는 생성자 참조인 `::Student` 를 받는다.

> `mapIndexed()` 는 [1.3. 람다 파라메터가 여러 개인 경우: `mapIndexed()`](#13-람다-파라메터가-여러-개인-경우-mapindexed) 를 참고하세요.

```kotlin
data class Student(
    val id: Int,
    val name: String,
)

fun main() {
    val names = listOf("Assu", "Silby")
    
    // mapIndexed() 에 인덱스와 원솔ㄹ 명시적으로 생성자에 넘김
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
    val result2 = goDog(Dog(), Dog::speak)

    println(result1) // 132 (11*12 이므로)
    println(result2) // Bow!
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)