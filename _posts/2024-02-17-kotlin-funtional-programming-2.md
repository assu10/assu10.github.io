---
layout: post
title:  "Kotlin - 함수형 프로그래밍(2): 고차 함수, 리스트 조작, Map 생성"
date: 2024-02-17
categories: dev
tags: kotlin toIntOrNull() mapNotNull() zip() zipWithNext() flatten() flatMap() groupBy() associateWith() associateBy() getOrElse() getOrPut() toMutableMap() filter() filterKeys() filterValues() map() mapKeys() mapValues() any() all() maxByOrNull()
---

코틀린 여러 함수 기능에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 고차 함수 (high-order function)](#1-고차-함수-high-order-function)
  * [1.1. 함수 인자로 람다나 함수 참조 전달](#11-함수-인자로-람다나-함수-참조-전달)
  * [1.2. 함수의 반환 타입이 null 인 타입: `toIntOrNull()`, `mapNotNull()`](#12-함수의-반환-타입이-null-인-타입-tointornull-mapnotnull)
  * [1.3. 반환 타입이 nullable 타입 vs 함수 전체의 타입이 nullable](#13-반환-타입이-nullable-타입-vs-함수-전체의-타입이-nullable)
* [2. 리스트 조작](#2-리스트-조작)
  * [2.1. 묶기 (Zipping): `zip()`, `zipWithNext()`](#21-묶기-zipping-zip-zipwithnext)
  * [2.2. 평평하게 하기 (Flattening)](#22-평평하게-하기-flattening)
    * [2.2.1. `flatten()`](#221-flatten)
    * [2.2.2. `flatMap()`](#222-flatmap)
* [3. Map 생성](#3-map-생성)
  * [3.1. `groupBy()`](#31-groupby)
  * [3.2. `associateWith()`, `associateBy()`](#32-associatewith-associateby)
  * [3.3. `getOrElse()`, `getOrPut()`, `toMutableMap()`](#33-getorelse-getorput-tomutablemap)
  * [3.4. `filter()`, `filterKeys()`, `filterValues()`](#34-filter-filterkeys-filtervalues)
  * [3.5. `map()`, `mapKeys()`, `mapValues()`](#35-map-mapkeys-mapvalues)
  * [3.6. `any()`, `all()`, `maxByOrNull()`](#36-any-all-maxbyornull)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 고차 함수 (high-order function)

**함수를 다른 함수의 인자로 넘길 수 있거나, 함수가 반환값으로 함수를 돌려줄 수 있으면 언어가 고차 함수를 지원**하는 것이다.

예를 들어 `filter()`, `map()`, `any()` 등이 고차 함수이다.

람다는 참조에 저장할 수 있다.

```kotlin
// 람다를 저장한 변수의 타입이 함수 타입임
val isPlus: (Int) -> Boolean = { it > 0 }

fun main() {
    // isPlus 는 함수를 반환값으로 돌려줌
    val result = listOf(1, 2, -3).any(isPlus)
    println(result) // true
}
```

위에서 _(Int) -> Boolean_ 은 함수 타입이다.  
**함수 타입은 0 개 이상의 파라메터 타입 목록을 둘러싼 괄호로 시작하고, 화살표 `->` 가 따라오며, 화살표 뒤엔 반환 타입**이 온다. 

참조를 통해 함수를 호출하는 구문은 일반 함수를 호출하는 구문과 동일하다.

```kotlin
val hello: () -> String = { "Hello~" }
val sum: (Int, Int) -> Int = { x, y -> x + y }

fun main() {
    println(hello()) // Hello~
    println(sum(1, 2)) // 3
}
```

---

## 1.1. 함수 인자로 람다나 함수 참조 전달

함수가 함수 파라메터를 받는 경우 인자로 람다나 함수 참조를 전달할 수 잇다.

아래는 표준 라이브러리의 `any()` 를 직접 구현하는 예시이다.

```kotlin
// 여러 타입의 List 에 대해 호출할 수 있도록 제네릭 List<T> 타입의 확장 함수 정의
fun <T> List<T>.customAny(
    customPredicate: (T) -> Boolean, // customPredicate 함수를 리스트의 원소에 적용할 수 있어야 하므로 이 함수는 파라메터 타입 T 를 인자로 받는 함수이어야 함
): Boolean {
    for (ele in this) {
        if (customPredicate(ele)) { // customPredicate 함수를 적용하면 선택 기준을 ele 가 만족하는지 알 수 있음
            return true
        }
    }
    return false
}

fun main() {
    val ints = listOf(1, 2, 3)
    val result1 = ints.customAny { it > 0 }
    println(result1) // true

    val strings = listOf("abc", " ")
  
    // 함수 인자로 람다 전달
    val result2 = strings.customAny { it.isBlank() }

    // 함수 인자로 함수 참조 전달
    val result3 = strings.customAny(String::isNotBlank)
    println(result2) // true
    println(result3) // true
}
```

아래는 `repeat()` 의 사용 예시이다.

```kotlin
fun main() {
    val result = repeat(3) { println("hi") }

    //hi
    //hi
    //hi
    println(result)
}
```

위의 `repeat()` 을 직접 구현해본다.

```kotlin
fun customRepeat(
    times: Int,
    action: (Int) -> Unit, // (Int) -> Unit 타입의 함수를 action 파라메터로 받음
) {
    for (index in 0 until times) {
        action(index) // 현재의 반복 횟수를 index 를 사용하여 호출
    }
}

fun main() {
    val result = customRepeat(3, { println("#$it") })
    val result2 = customRepeat(3) { println("#$it") }

    // #0
    // #1
    // #2
    println(result)
    // #0
    // #1
    // #2
    println(result2)
}
```

---

## 1.2. 함수의 반환 타입이 null 인 타입: `toIntOrNull()`, `mapNotNull()`

```kotlin
fun main() {
    // 리턴값이 null 이 될 수도 있음
    val trans: (String) -> Int? =
        { s: String -> s.toIntOrNull() }

    val result1 = trans("123")
    val result2 = trans("abc")

    println(result1) // 123
    println(result2) // null

    val x = listOf("123", "abc")
    val result3 = x.mapNotNull(trans)
    val result4 = x.mapNotNull { it.toIntOrNull() }
    println(result3) // [123]
    println(result4) // [123]
}
```

- `toIntOrNull()`
  - null 을 반환할 수 있음
- `mapNotNull()`
  - List 의 각 원소를 null 이 될 수 있는 값으로 변환 후 변환 결과에서 null 을 제외시킴
  - `map()` 을 호출하여 얻은 결과 리스트에서 `filterNotNull()` 을 호출한 것과 동일함

---

## 1.3. 반환 타입이 nullable 타입 vs 함수 전체의 타입이 nullable

```kotlin
fun main() {
    // 반환 타입을 nullable 타입으로 만듦
    val returnTypeNullable: (String) -> Int? = { null }

    // 함수 전체의 타입을 nullable 타입으로 만듦
    val mightBeNull: ((String) -> Int)? = null

    val result1 = returnTypeNullable("abc")

    // 컴파일 오류, Reference has a nullable type '((String) -> Int)?', use explicit '?.invoke()' to make a function-like call instead
    // val result2 = mightBeNull("abc")

    // if 문을 통해 명시적으로 null 검사를 한 것과 같음
    // mightBeNull 에 저장된 함수를 호출하기 전에 함수 참조 자체가 null 이 아닌지 반드시 검사해야 함
    val result2 = mightBeNull?.let { it("abc") }

    println(result1) // null
    println(result2) // null
}
```

---

# 2. 리스트 조작

zipping 과 flattening 은 List 를 조작할 때 흔히 쓰는 연산이다.

---

## 2.1. 묶기 (Zipping): `zip()`, `zipWithNext()`

**`zip()` 은 두 List 의 원소를 하나씩 짝짓는 방식**으로 묶는다.

```kotlin
fun main() {
    val left = listOf('a', 'b', 'c', 'd')
    val right = listOf('q', 'r', 's')

    // left 와 right 를 zipping 하면 Pair 로 이루어진 List 가 반환됨
    val result1 = left.zip(right)

    // [(a, q), (b, r), (c, s)]
    println(result1)

    val result2 = left.zip(0..5)

    // [(a, 0), (b, 1), (c, 2), (d, 3)]
    println(result2)

    val result3 = (10..100).zip(right)

    // [(10, q), (11, r), (12, s)]
    println(result3)
}
```

---

`zip()` 함수는 만들어진 Pair 에 대해 연산을 할 수도 있다.

```kotlin
data class Person(
    val name: String,
    val id: Int,
)

fun main() {
    val names = listOf("Assu", "Silby")
    val ids = listOf(777, 888)

    val result1 = names.zip(ids)

    // [(Assu, 777), (Silby, 888)]
    println(result1)

    val result2 =
        // name.zip(ids) { ... } 는 name, id Pair 를 만든 후 람다를 각 Pair 에 적용
        names.zip(ids) { name, id ->
            Person(name, id)
        }

    // [Person(name=Assu, id=777), Person(name=Silby, id=888)]
    println(result2)
}
```

---

한 List 에서 특정 원소와 그 원소에 인접한 다음 원소를 묶을 때는 `zipWithNext()` 를 사용한다.

```kotlin
fun main() {
    val list = listOf('a', 'b', 'c', 'd')

    val result1 = list.zipWithNext()

    // [(a, b), (b, c), (c, d)]
    println(result1)

    // 원소를 zipping 한 후 연산을 추가로 적용함
    val result2 = list.zipWithNext { a, b -> "$a$b" }

    // [ab, bc, cd]
    println(result2)
}
```

---

## 2.2. 평평하게 하기 (Flattening)

### 2.2.1. `flatten()`

**`flatten()` 은 각 원소가 List 인 List 를 인자로 받아서 원소가 따로따로 들어있는 List 를 반환**한다.

```kotlin
fun main() {
    val list =
        listOf(
            listOf(1, 2),
            listOf(3, 4),
            listOf(5, 6),
        )

    val result = list.flatten()
    
    // [1, 2, 3, 4, 5, 6]
    println(result)
}
```

---

### 2.2.2. `flatMap()`

`flatMap()` 은 컬렉션에서 자주 사용되는 함수이다.

아래는 특정 범위에 속한 Int 로부터 가능한 모든 Pair 를 생성하는 예시이다.

```kotlin
fun main() {
    val intRange = 1..3

    // map() 은 intRange 에 속한 각 원소에 대응하는 3가지 List 의 정보를 유지
    val result1 =
        intRange.map { a ->
            intRange.map { b -> a to b }
        }

    // [[(1, 1), (1, 2), (1, 3)], [(2, 1), (2, 2), (2, 3)], [(3, 1), (3, 2), (3, 3)]]
    println(result1)

    // flatten() 을 이용하여 결과를 펼처서 단일 List 생성
    // 하지만 이런 작업을 해야 하는 경우가 빈번하므로 코틀린은 한번 호출하면 map() 과 flatten() 을 모두 수행해주는 flatMap() 이라는 합성 연산을 제공함
    val result2 =
        intRange.map { a ->
            intRange.map { b -> a to b }
        }.flatten()

    // [(1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (2, 3), (3, 1), (3, 2), (3, 3)]
    println(result2)

    // flatMap() 사용
    val result3 =
        intRange.flatMap { a ->
            intRange.map { b -> a to b }
        }

    // [(1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (2, 3), (3, 1), (3, 2), (3, 3)]
    println(result3)
}
```

**`flatMap()` 은 `map()` 에 `flatten()` 을 적용한 결과 (= 단일 List) 를 반환**한다.

아래는 또 다른 예시이다.

```kotlin
class Book(
    val title: String,
    val author: List<String>,
)

fun main() {
    val books =
        listOf(
            Book("Harry", listOf("aa", "bb")),
            Book("Magic", listOf("cc", "dd")),
        )

    // map() 과 flatten() 사용
    val result1 = books.map { it.author }.flatten()

    // [aa, bb, cc, dd]
    println(result1)

    // flatMap() 사용
    val result2 = books.flatMap { it.author }

    // [aa, bb, cc, dd]
    println(result2)
}
```

아래는 map(), flatMap() 을 사용하는 예시이다.

```kotlin
import kotlin.random.Random

enum class Suit {
    Spade,
    Club,
    Hear,
    Diamond,
}

enum class Rank(val faceValue: Int) {
    Ace(1),
    Two(2),
    Three(3),
}

class Card(val rank: Rank, val suit: Suit) {
    override fun toString() = "$rank of ${suit}s."
}

val deck: List<Card> =
    // flatMap() 이 아닌 map() 으로 하면 아래와 같은 컴파일 오류남
    // Type mismatch. Required: List<Card>  Found: List<List<Card>>
    
    // 따라서 deck 이 List<Card> 가 되기 위해서는 여기서 map() 이 아닌 flatMap() 을 사용해야 함
    Suit.values().flatMap { suit ->
        Rank.values().map { rank ->     // map() 은 List 4개를 생성하며, 각 List 는 각 Suit 에 대응함
            Card(rank, suit)
        }
    }

fun main() {
    val rand = Random(26)
    
    // 코틀린 Random 은 seed 가 같으면 항상 같은 난수 시퀀스를 내놓으므로 결과는 항상 동일함
    repeat(7) { println("'${deck.random(rand)}'") }
}
```

---

# 3. Map 생성

Map 을 사용하면 key 를 사용하여 value 에 빠르게 접근할 수 있다.

---

## 3.1. `groupBy()`

**`groupBy()` 는 Map 을 생성하는 방법 중 하나**이다.  
**`groupBy()` 의 파라메터는 원본 컬렉션의 원소를 분류하는 키를 반환하는 람다**이다.  
원본 컬렉션의 각 원소에 이 람다를 적용하여 key 값을 얻은 후 Map 에 넣어준다.  
이 때 **key 가 같은 값이 둘 이상 있을 수 있으므로 Map 의 value 는 원본 컬렉션의 원소 중 key 에 해당하는 값의 List** 가 되어야 한다.

```kotlin
data class Person(
    val name: String,
    val age: Int,
)

val names = listOf("Assu", "Sibly", "JaeHoon")
val ages = listOf(20, 2, 20)

fun people(): List<Person> = names.zip(ages) { name, age -> Person(name, age) }

fun main() {
    // groupBy() 로 Map 생성
    val map: Map<Int, List<Person>> =
        people().groupBy(Person::age)

    // {20=[Person(name=Assu, age=20), Person(name=JaeHoon, age=20)], 2=[Person(name=Sibly, age=2)]}
    println(map)

    // [Person(name=Assu, age=20), Person(name=JaeHoon, age=20)]
    println(map[20])

    // null
    println(map[9])
}

```

---

## 3.2. `associateWith()`, `associateBy()`

**List 에 `associateWith()` 를 사용하면 List 원소를 key 로 하고, `associateWith()` 에 전달된 함수 (혹은 람다) 를 List 에 원소에 적용한 
반환값을 value 로 하는 Map 을 생성**한다.

**`associateBy()` 는 `associateWith()` 가 생성하는 연관 관계를 반대 방향으로 하여 Map 을 생성**한다.  
즉, **셀렉터가 반환한 값이 key** 가 된다.

**`associateBy()` 의 셀렉터는 유일한 key 값을 만들어 내야 한다.** 만일 key 값이 유일하지 않으면 원본값 중 일부가 사라진다.  
만일 key 값이 유일하지 않으면 같은 key 를 가진 value 중 컬렉션에서 맨 나중에 나타나는 원소가 Map 에 포함된다.

```kotlin
data class Person1(
    val name: String,
    val age: Int,
)

val names1 = listOf("Assu", "Sibly", "JaeHoon")
val ages1 = listOf(20, 2, 20)

fun people1(): List<Person1> = names1.zip(ages1) { name, age -> Person1(name, age) }

fun main() {
    // associateWith() 사용
    val map: Map<Person1, String> = people1().associateWith { it.name }

    // {Person1(name=Assu, age=20)=Assu, Person1(name=Sibly, age=2)=Sibly, Person1(name=JaeHoon, age=20)=JaeHoon}
    println(map)

    // associateBy() 사용, key 값이 유일함
    val map2: Map<String, Person1> = people1().associateBy { it.name }

    // {Assu=Person1(name=Assu, age=20), Sibly=Person1(name=Sibly, age=2), JaeHoon=Person1(name=JaeHoon, age=20)}
    println(map2)

    // associateBy() 사용, key 값이 중복되서 원본이 사라짐
    val map3: Map<Int, Person1> = people1().associateBy { it.age }

    // {20=Person1(name=JaeHoon, age=20), 2=Person1(name=Sibly, age=2)}
    println(map3)
}
```

---

## 3.3. `getOrElse()`, `getOrPut()`, `toMutableMap()`

**`getOrElse()` 는 Map 에서 value 를 찾는다.**    
**key 가 없을 때 디폴트 value 를 계산하는 방법이 담긴 람다를 인자**로 받는데, 이 파라메터가 람다이기 때문에 필요할 때만 디폴트 value 를 계산할 수 있다.

**`getOrPut()` 은 MutableMap 에만 적용 가능**하다.  
**`getOrPut()` 은 key 가 있으면 연관된 value 를 반환하고, key 가 없으면 value 를 계산한 후 그 value 를 key 와 연관시켜서 Map 에 저장한 후, 저장한 value 를 반환**한다.

```kotlin
fun main() {
    val map = mapOf(1 to "one", 2 to "two")

    val result1 = map.getOrElse(0) { "zero" }
    val result2 = map.getOrElse(1) { "zero" }

    println(result1) // zero
    println(result2) // one

    // immutableMap 을 mutableMap 으로 변환
    val mutableMap = map.toMutableMap()
    
    // 0 이라는 key 가 없으므로 Map 에 {0=zero} 추가 후 zero 라는 value 반환
    var result3 = mutableMap.getOrPut(0) { "zero" }
    
    // 1 이라는 key 가 있으므로 1에 해당하는 value 인 one 반환
    var result4 = mutableMap.getOrPut(1) { "zero" }

    println(result3) // zero
    println(result4) // one

    println(mutableMap) // {1=one, 2=two, 0=zero}
}
```

---

## 3.4. `filter()`, `filterKeys()`, `filterValues()`

Map 의 여러 연산은 List 가 제공하는 연산과 겹친다.

```kotlin
fun main() {
    val map = mapOf(1 to "one", 2 to "two", 3 to "three", 4 to "four")

    // filterKeys() 사용
    val result1 = map.filterKeys { it % 2 == 1 }

    // {1=one, 3=three}
    println(result1)

    // filterValues() 사용
    val result2 = map.filterValues { it.contains('o') }

    // {1=one, 2=two, 4=four}
    println(result2)

    // Map 에 filter() 사용
    val result3 =
        map.filter { entry ->
            entry.key % 2 == 1 && entry.value.contains('o')
        }

    // {1=one}
    println(result3)
}
```

---

## 3.5. `map()`, `mapKeys()`, `mapValues()`

Map 에 `map()` 을 적용한다는 말은 동어 반복인 듯 하지만 'map' 은 두 가지를 뜻한다.
- 컬렉션 변환
- key-value 쌍을 저장하는 데이터 구조

```kotlin
fun main() {
    val even = mapOf(2 to "two", 4 to "four")

    // map() 사용, List 반환
    // map() 은 Map.Entry 인자를 받는 람다를 파라메터로 받음
    // Map.Entry 의 내용을 it.key, it.value 로 접근 가능
    val result1 = even.map { "${it.key}=${it.value}" }

    // [2=two, 4=four]
    println(result1)

    // 구조 분해 사용
    val result2 = even.map { (key1, value1) -> "$key1=$value1" }

    // [2=two, 4=four]
    println(result2)

    // 파라메터를 사용하지 않을 때는 밑줄을 사용하여 컴파일러 경고를 막음
    // mayKeys(), mapValues() 는 모든 key 나 value 가 변환된 새로운 Map 을 반환함
    val result3 =
        even.mapKeys { (num, _) -> -num }
            .mapValues { (_, str) -> "minus $str" }

    // {-2=minus two, -4=minus four}
    println(result3)

    // map() 사용
    // map() 은 List 를 반환하므로 새로운 Map 을 생성하려면 명시적으로 toMap() 을 호출해야 함
    val result4 =
        even.map { (key, value) -> -key to "minus $value" }
            .toMap()

    // {-2=minus two, -4=minus four}
    println(result4)
}
```

---

## 3.6. `any()`, `all()`, `maxByOrNull()`

- `any()`
  - Map 의 원소 중 주어진 Predicate 를 만족하는 원소가 하나라도 있으면 true 반환
- `all()`
  - Map 의 모든 원소가 Predicate 를 만족해야 true 반환
- `maxByOrNull()`
  - 주어진 Predicate 에 따라 가장 큰 원소를 반환
  - 가장 큰 원소가 없으면 null 반환

```kotlin
fun main() {
    val map = mapOf(1 to "one", -2 to "minus two")

    val result1 = map.any { (key, _) -> key < 0 }
    val result2 = map.all { (key, _) -> key < 0 }
    val result3 = map.maxByOrNull { it.key }?.value

    println(result1) // true
    println(result2) // false
    println(result3) // one
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [아토믹 코틀린 예제 코드](https://github.com/gilbutITbook/080301)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)