---
layout: post
title:  "Kotlin - 프로퍼티 위임, 'ReadOnlyProperty', 'ReadWriteProperty', 프로퍼티 위임 도구 (Delegates.observable(), Delegates.vetoable(), Delegates.notNull())"
date: 2024-03-24
categories: dev
tags: kotlin KProperty ReadOnlyProperty ReadWriteProperty Delegates.observable() Delegates.vetoable() Delegates.notNull()
---

이 포스트에서는 프로퍼티 위임과 프로퍼티 위임 도구에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 프로퍼티 위임: `by`](#1-프로퍼티-위임-by)
  * [1.1. 프로퍼티가 val 인 경우: `KProperty`](#11-프로퍼티가-val-인-경우-kproperty)
  * [1.2. 프로퍼티가 var 인 경우](#12-프로퍼티가-var-인-경우)
  * [1.3. `ReadOnlyProperty` 인터페이스 상속](#13-readonlyproperty-인터페이스-상속)
  * [1.4. `ReadWriteProperty` 인터페이스 상속](#14-readwriteproperty-인터페이스-상속)
  * [1.5. 위임자 객체의 private 멤버에 접근](#15-위임자-객체의-private-멤버에-접근)
  * [1.6. 위임자 객체의 `getValue()`, `setValue()` 를 확장 함수로 만들기](#16-위임자-객체의-getvalue-setvalue-를-확장-함수로-만들기)
  * [1.7. 위임받는 클래스를 좀 더 일반적으로 사용](#17-위임받는-클래스를-좀-더-일반적으로-사용)
* [2. 프로퍼티 위임 도구](#2-프로퍼티-위임-도구)
  * [2.1. 프로퍼티 위임 도구로 사용되는 Map](#21-프로퍼티-위임-도구로-사용되는-map)
  * [2.2. `Delegates.observable()`](#22-delegatesobservable)
  * [2.3. `Delegates.vetoable()`](#23-delegatesvetoable)
  * [2.4. `Delegates.notNull()`](#24-delegatesnotnull)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 프로퍼티 위임: `by`

프로퍼티는 접근자 로직을 위임할 수 있는데, `by` 키워드를 사용하여 프로퍼티를 위임과 연결할 수 있다.

`val (또는 var) 프로퍼티명 by 위임할 객체`

프로퍼티가 val (읽기 전용) 인 경우는 위임 객체의 클래스에 `getValue()` 함수 정의가 있어야 하고, 
프로퍼티가 var (쓰기 가능) 인 경우는 위임 객체의 클래스에 `getValue()`, `setValue()` 함수 정의가 있어야 한다.

> 클래스 위임에 대한 좀 더 상세한 내용은 [1. 클래스 위임 (class delegation)](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#1-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%9C%84%EC%9E%84-class-delegation) 을 참고하세요.

---

## 1.1. 프로퍼티가 val 인 경우: `KProperty`

> 이 방식보다는 `ReadOnlyProperty` 인터페이스를 상속하는 방법을 추천함  
> 해당 내용은 바로 뒤인 [1.3. `ReadOnlyProperty` 인터페이스 상속](#13-readonlyproperty-인터페이스-상속) 에 나옴

아래는 읽기 전용 프로퍼티인 _val value_ 가 _BasicRead_ 객체에 의해 위임되는 예시이다.

```kotlin
import kotlin.reflect.KProperty

// 위임자 클래스
class Readable(val i: Int) {
    // value 프로퍼티는 BasicRead() 객체에 의해 위임됨
    // 프로퍼티 뒤에 by 라고 지정하여 BasicRead 객체를 by 앞의 프로퍼티인 value 와 연결
    // 이 때 BasicRead 의 getValue() 는 Readable 의 i 에 접근 가능
    // getValue() 가 String 을 반환하므로 value 프로퍼티의 타입도 String 이어야 함
    val value: String by BasicRead()

    // val value by BasicRead() // 이렇게 써도 됨
}

// 위임받는 클래스
class BasicRead {
    // Readable 에 대한 접근을 가능하게 하는 Readable 파라메터를 얻음
    operator fun getValue(
        r: Readable,
        property: KProperty<*>,
    ) = "getValue: ${r.i}~"
}

fun main() {
    val x = Readable(1)
    val y = Readable(2)

    println(x.value) // getValue: 1~
    println(y.value) // getValue: 2~
}
```

위의 _Readable_ 의 _value_ 프로퍼티는 _BasicRead_ 객체에 의해 위임된다.

_BasicRead_ 의 `getValue()` 는 _Readable_ 에 대한 접근을 가능하게 하는 _Readable_ 파라메터 (_r_) 을 얻는다.  
**프로퍼티 뒤에 `by` 라고 지정하여 _BasicRead_ 객체를 `by` 앞의 프로퍼티와 연결**한다.  
**이 때 _BasicRead_ 의 `getValue()` 는 _Readable_ 의 _i_ 에 접근**할 수 있다.

`getValue()` 가 String 을 반환하므로 위임 받는 프로퍼티인 _value_ 의 타입도 String 이어야 한다.

`getValue()` 의 두 번째 파라메터는 `KProperty` 라는 타입인데 이 타입의 객체는 위임 프로퍼티에 대한 reflection 정보를 제공한다.

> **reflection**  
> 
> 실행 시점에 코틀린 언어의 다양한 요소에 대한 정보를 얻을 수 있게 해주는 기능  
> 
> refection 에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다.

---

## 1.2. 프로퍼티가 var 인 경우

> 이 방식보다는 `ReadWriteProperty` 인터페이스를 상속하는 방법을 추천함  
> 해당 내용은 바로 뒤인 [1.4. `ReadWriteProperty` 인터페이스 상속](#14-readwriteproperty-인터페이스-상속) 에 나옴


아래는 쓰기 가능한 프로퍼티인 _var value_ 가 _BasicReadWrite_ 객체에 의해 위임되는 예시이다.

```kotlin
import kotlin.reflect.KProperty

// 위임자 클래스
class ReadWriteable(var i: Int) {
    var msg = ""
    // value 프로퍼티는 BasicReadWrite 객체에 의해 위임됨
    var value: String by BasicReadWrite()
}

// 위임받는 클래스
class BasicReadWrite {
    operator fun getValue(
        rw: ReadWriteable,
        property: KProperty<*>,
    ) = "getValue: ${rw.i}~"
    // ) = "getValue: ${rw.value}, ${rw.i}~" // 여기서 rw.value 에 접근하면 stackoverflow 발생

    operator fun setValue(
        rw: ReadWriteable,
        property: KProperty<*>,
        s: String,
    ) {
        rw.i = s.toIntOrNull() ?: 0
        rw.msg = "setValue to ${rw.i}~"
        // rw.value = "test~ ${rw.value}"   // 런타임 에러
        // rw.msg = "setValue to $rw.i~"   // 이렇게 하면 ReadWritable 에 메모리 주소가 출력됨
    }
}

fun main() {
    val x = ReadWriteable(1)
    println("1: " + x.value) // 1: getValue: 1~
    println("2: " + x.msg) // 2:
    println("3: " + x.i) // 3: 1

    x.value = "99"
    println("4: " + x.value) // 4: getValue: 99~
    println("5: " + x.msg) // 5: setValue to 99~
    println("6: " + x.i) // 6: 99
}
```

> 엘비스 연산자 `?:` 에 대한 좀 더 상세한 내용은 [2.2. 엘비스(Elvis) 연산자: `?:`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#22-%EC%97%98%EB%B9%84%EC%8A%A4elvis-%EC%97%B0%EC%82%B0%EC%9E%90-) 를 참고하세요.

`setValue()` 의 앞의 두 파라메터는 `getValue()` 의 파라메터와 동일하고, 마지막 파라메터는 프로퍼티에 설정하려는 값이다.

`getValue()` 의 반환 타입과 `setValue()` 의 세 번째 파라메터 값의 타입은 해당 위임 객체가 적용된 프로퍼티인 _var value_ 의 타입과 일치해야 한다.

**또한, `setValue()` 도 _ReadWriteable_ 의 _value_ 뿐 아니라 _i_, _msg_ 모두에 접근 가능**하다.

---

## 1.3. `ReadOnlyProperty` 인터페이스 상속

[1.1. 프로퍼티가 val 인 경우: `KProperty`](#11-프로퍼티가-val-인-경우-kproperty) 에서 
**위임 클래스인 _BasicRead_, _BasicReadWrite_ 모두 어떤 인터페이스도 구현할 필요없이, 단순이 필요한 함수 이름과 시그니처만 만족하면 위임 역할을 수행**할 수 있다.

하지만 원한다면 `ReadOnlyProperty` 인터페이스를 상속할 수도 있다.

**`ReadOnlyProperty` 를 구현하면 코드를 읽는 사람에게 _BasicRead2_ 를 위임으로 사용할 수 있다는 사실을 알리고, `getValue()` 정의가 제대로 들어있도록 보장**할 수 있다.

> **`SAM` (`fun interface`)**  
> 
> 단일 추상 메서드인 SAM (fun interface) 에 대한 좀 더 상세한 내용은 [1.3. 단일 추상 메서드 (Single Abstract Method, SAM): `fun interface`](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#13-%EB%8B%A8%EC%9D%BC-%EC%B6%94%EC%83%81-%EB%A9%94%EC%84%9C%EB%93%9C-single-abstract-method-sam-fun-interface) 를 참고하세요.

아래는 [1.1. 프로퍼티가 val 인 경우: `KProperty`](#11-프로퍼티가-val-인-경우-kproperty) 의 예시를 `ReadOnlyProperty` 인터페이스를 구현하여 재작성한 예시이다.
```kotlin
import kotlin.properties.ReadOnlyProperty
import kotlin.reflect.KProperty

// 위임자 클래스
class Readable2(val i: Int) {
    val value: String by BasicRead2()

    // SAM 변환
    val value2: String by ReadOnlyProperty { _, _ -> "getValue: $i~~" }
}

// 위임받는 클래스
class BasicRead2 : ReadOnlyProperty<Readable2, String> {
    override operator fun getValue(
        thisRef: Readable2,
        property: KProperty<*>,
    ) = "getValue: ${thisRef.i}~"
}

fun main() {
    val x = Readable2(1)
    val y = Readable2(2)

    println(x.value) // getValue: 1~
    println(x.value2) // getValue: 1~~
    println(y.value) // getValue: 2~
    println(y.value2) // getValue: 2~~
}
```

`ReadOnlyProperty` 인터페이스는 멤버 함수가 `getValue()` 하나이고, 인터페이스가 `fun interface` 로 선언되어 있기 때문에 SAM 변환을 사용해서 _value2_ 를 훨씬
간결하게 작성하였다.

---

## 1.4. `ReadWriteProperty` 인터페이스 상속

**`ReadWriteProperty` 를 구현하면 코드를 읽는 사람에게 _ReadWritable2_ 를 위임으로 사용할 수 있다는 사실을 알리고, `getValue()` 와 `setValue()` 의 정의가 제대로 들어있도록 보장**할 수 있다.

아래는 [1.2. 프로퍼티가 var 인 경우](#12-프로퍼티가-var-인-경우) 의 예시를 `ReadWriteProperty` 인터페이스를 구현하여 재작성한 예시이다.
```kotlin
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

// 위임자 클래스
class ReadWritable2(var i: Int) {
    var msg = ""

    // value 프로퍼티는 BasicReadWrite2 객체에 의해 위임됨
    var value: String by BasicReadWrite2()
}

// 위임받는 클래스
class BasicReadWrite2 : ReadWriteProperty<ReadWritable2, String> {
    override fun getValue(
        rw: ReadWritable2,
        property: KProperty<*>,
    ) = "getValue: ${rw.i}~"

    override fun setValue(
        rw: ReadWritable2,
        property: KProperty<*>,
        s: String,
    ) {
        rw.i = s.toIntOrNull() ?: 0
        rw.msg = "setValue to ${rw.i}~"
    }
}

fun main() {
    val x = ReadWritable2(1)
    println("1: " + x.value) // 1: getValue: 1~
    println("2: " + x.msg) // 2:
    println("3: " + x.i) // 3: 1

    x.value = "99"
    println("4: " + x.value) // 4: getValue: 99~
    println("5: " + x.msg) // 5: setValue to 99~
    println("6: " + x.i) // 6: 99
}
```

---

프로퍼티 위임 클래스에 대해 정리하자면 아래와 같다.

**위임 클래스는 아래 2개의 함수를 모두 포함하거나, 하나만 포함**할 수 있다.  
**위임 프로퍼티에 접근하면 읽기와 쓰기에 따라 아래 두 함수가 호출**된다.

- **프로퍼티가 읽기 전용인 경우**

```kotlin
operator fun getValue(thisRef: T, property: KProperty<*>): V
```
이 경우 `ReadOnlyProperty` 인터페이스와 SAM 변환을 통해 구현할 수도 있다.

- **프로퍼티가 쓰기도 가능한 경우**

```kotlin
operator fun getValue(thisRef: T, property: KProperty<*>): V

operator fun setValue(thisRef: T, property: KProperty<*>, value: V)
```

위 두 함수의 파라메터는 아래와 같다.
- _thisRef_
  - T 는 위임자 개체(= 다른 객체에 처리를 맡기는 주체) 의 클래스임
  - _thisRef_ 가 아닌 `Any?` 를 사용하여 위임자 객체의 내부를 보기 어렵게 할 수도 있음
- _property_
  - `KProperty<*>` 는 위임 프로퍼티에 대한 정보를 제공
  - 가장 일반적으로 사용하는 정보는 `name` (위임 프로퍼티의 필드명) 임
- _value_
  - `setValue()` 로 위임 프로퍼티에 저장할 값
  - V 는 위임 프로퍼티의 타입

---

## 1.5. 위임자 객체의 private 멤버에 접근

**위임자 객체의 private 멤버에 접근하려면 위임 클래스를 내포**시켜야 한다.

> 내포된 클래스에 대한 좀 더 상세한 내용은 [2. 내포된 클래스 (nested class)](https://assu10.github.io/dev/2024/03/02/kotlin-object-oriented-programming-4/#2-%EB%82%B4%ED%8F%AC%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-nested-class) 를 참고하세요.

```kotlin
import kotlin.properties.ReadOnlyProperty

class Person(
    private val first: String,
    private val last: String,
) {
    val name by // SAM 변환
        ReadOnlyProperty<Person, String> { _, _ -> "$first $last~" }
}

fun main() {
    val assu = Person("A", "B")

    println(assu.name) // A B~
}
```

---

## 1.6. 위임자 객체의 `getValue()`, `setValue()` 를 확장 함수로 만들기

위임자 객체의 멤버에 대한 접근이 된다면 `getValue()`, `setValue()` 를 확장 함수로 만들 수 있다.

```kotlin
import kotlin.reflect.KProperty

// 위임자 클래스
class Add(val a: Int, val b: Int) {
    // sum 프로퍼티는 Sum() 객체에 의해 위임됨
    val sum by Sum()
}

// 위임받는 클래스
class Sum

// getValue() 를 확장 함수로 만듬
operator fun Sum.getValue(
    thisRef: Add,
    property: KProperty<*>,
): Int = thisRef.a + thisRef.b

fun main() {
    val add = Add(1, 2)

    println(add.sum) // 3
}
```

이렇게 **`getValue()`, `setValue()` 를 확장 함수로 만들면 변경하거나 상속할 수 없는 기존 클래스에 `getValue()`, `setValue()` 를 추가함으로써 
_Sum_ 클래스의 인스턴스를 위임 객체로 사용**할 수 있게 된다.

---

## 1.7. 위임받는 클래스를 좀 더 일반적으로 사용

위 코드들에서는 `getValue()`, `setValue()` 의 첫 번째 파라메터의 타입을 구체적으로 받았는데, 이런 식으로 정의한 위임은 그 구체적인 타입에 얽매이게 될 수가 있다.  

상황에 따라서는 **첫 번째 파라메터를 `Any?` 로 지정함으로써 더 일반적인 목적의 위임**을 만들 수 있다.

아래는 String 타입의 위임 프로퍼티가 있고, 이 프로퍼티의 내용은 해당 프로퍼티 이름에 대응하면 텍스트 파일인 예시이다.

```kotlin
import java.io.File
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

var targetDir = File("DataFiles")

class DataFile(val fileName: String) : File(targetDir, fileName) {
    init {
        if (!targetDir.exists()) {
            targetDir.mkdir()
        }
    }

    fun erase() {
        if (exists()) {
            delete()
        }
    }

    fun reset(): File {
        erase()
        createNewFile()
        return this
    }
}

// 위임받는 클래스
class FileDelegate : ReadWriteProperty<Any?, String> {
    override fun getValue(
        thisRef: Any?,
        property: KProperty<*>,
    ): String {
        println("getValue(): ${property.name}")
        val file = DataFile(property.name + ".txt")
        return if (file.exists()) file.readText() else ""
    }

    override fun setValue(
        thisRef: Any?,
        property: KProperty<*>,
        value: String,
    ) {
        println("setValue(): ${property.name}, $value")
        DataFile(property.name + ".txt").writeText(value)
    }
}

// 위임자 클래스
class Configuration {
    var user by FileDelegate()
    var id by FileDelegate()
    var project by FileDelegate()
}

fun main() {
    val config = Configuration()

    // 여기서 setValue() 호출
    config.user = "Assu" // setValue(): user, Assu
    config.id = "test_11" // setValue(): id, test_11
    config.project = "KotlinProject" // setValue(): project, KotlinProject

    val result1 = DataFile("user.txt").readText()
    val result2 = DataFile("id.txt").readText()
    val result3 = DataFile("project.txt").readText()

    println(config.user) // getValue(): user   ASSU
    println(config.id) // getValue(): id   test_11
    println(config.project) // getValue(): project   KotlinProject

    println(result1) // Assu
    println(result2) // test_11
    println(result3) // KotlinProject
}
```

위 예시에서의 위임은 파일과 상호 작용만 할 수 있으면 되고, 위임받는 클래스에서 _thisRef_ 의 내부 정보는 필요없으므로 _thisRef_ 의 타입은 `Any?` 로 지정하여 무시한다.

위에선 _property.name_ 에만 관심이 있고, 이 값은 위임 필드(= 위임 프로퍼티) 의 이름이다.

---

# 2. 프로퍼티 위임 도구

## 2.1. 프로퍼티 위임 도구로 사용되는 Map

표준 라이브러리에는 몇 가지 프로퍼티 위임 연산이 들어있는데 Map 도 위임 프로퍼티의 위임 객체로 사용될 수 있도록 미리 설정된 코틀린 표준 라이브러리 타입 중 하나이다.

어떤 클래스의 모든 프로퍼티를 저장하게 위해 Map 을 하나만 써도 되는데, 이 Map 에서 각 프로퍼티는 String 타입의 key 가 되고, 저장한 값은 value 가 된다.

```kotlin
// 위임자 클래스
// MutableMap 이 위임받는 객체
class Driver(
    iMap: MutableMap<String, Any?>,
) {
    // name 프로퍼티는 iMap 객체에 의해 위임됨
    var name: String by iMap
    var age: Int by iMap
    var coord: Pair<Double, Double> by iMap
}

fun main() {
    val info =
        mutableMapOf<String, Any?>(
            "name" to "assu",
            "age" to 20,
            "coord" to Pair(1.1, 2.2),
            "ddd" to "aa",
        )

    val driver = Driver(info)

    // {name=assu, age=20, coord=(1.1, 2.2)}
    println(info)

    // assu
    println(driver.name)
    driver.name = "silby"   // 원본인 info Map 이 변경됨

    // {name=silby, age=20, coord=(1.1, 2.2)}
    println(info)
}
```

코틀린 표준 라이브러리에서 Map 의 확장 함수로 프로퍼티 위임을 가능하게 해주는 `getValue()`, `setValue()` 를 제공하기 때문에 
위에서 _driver.name = "silby"_ 로 설정하면 원본 Map 이 변경된다. 

---

## 2.2. `Delegates.observable()`

**`Delegates.observable()` 은 가변 프로퍼티의 값을 변경되는지 확인하는 함수**이다.

```kotlin
package assu.study.kotlinme.chap07.delegationTools

import kotlin.properties.Delegates

class Team {
  var msg = ""
  var captain: String by Delegates.observable("INIT임 ") { prop, old, new ->
    msg += "${prop.name} : $old to $new ~\n"
  }
}

fun main() {
  val team = Team()
  team.captain = "assu"
  team.captain = "silby"
  team.captain = "silby2"

  // captain : INIT임  to assu ~
  // captain : assu to silby ~
  // captain : silby to silby2 ~
  println(team.msg)
}
```

`Delegates.observable()` 는 2개의 인자를 받는다.
- **첫 번째 인자**
  - 프로퍼티의 초기값
  - 위에서는 "INIT임"
- **두 번째 인자**
  - 프로퍼티가 변경될 때 실행할 동작을 지정하는 함수
  - 위에서는 람다를 사용함
  - 함수의 인자는 변경 중인 프로퍼티, 프로퍼티의 현재값, 프로퍼티에 저장될 새로운 값

---

## 2.3. `Delegates.vetoable()`

**`Delegates.vetoable()` 은 새로운 프로퍼티의 값이 Predicate 를 만족하지 않으면 프로퍼티가 변경되는 것을 방지하는 함수**이다.

아래의 _aName()_ 은 _captain_ 의 이름이 A 로 시작하도록 강제한다.

```kotlin
package assu.study.kotlinme.chap07.delegationTools

import kotlin.properties.Delegates
import kotlin.reflect.KProperty

fun aName(
  property: KProperty<*>,
  old: String,
  new: String,
) = if (new.startsWith("A")) {
  println("$old to $new ~")
  true
} else {
  println("11 name must start with 'A' ~")
  false
}

interface Captain {
  var captain: String
}

class TeamWithTraditions1 : Captain {
  override var captain: String by Delegates.vetoable("Assu", ::aName)
}

// Delegates.vetoable() 를 aName() 대신 람다를 사용하여 정의
class TeamWithTraditions2 : Captain {
  override var captain: String by Delegates.vetoable("Assu") { _, old, new ->
    if (new.startsWith("A")) {
      println("$old to $new ~~")
      true
    } else {
      println("22 name must start with 'A' ~~")
      false
    }
  }
}

fun main() {
  // Assu to ASSU1 ~
  // 11 name must start with 'A' ~
  // ASSU1
  // Assu to ASSU1 ~~
  // 22 name must start with 'A' ~~
  // ASSU1
  listOf(
    TeamWithTraditions1(),
    TeamWithTraditions2(),
  ).forEach {
    it.captain = "ASSU1"
    it.captain = "BSSU"

    println(it.captain)
  }
}
```

`Delegates.vetoable()` 는 2개의 인자를 받는다.
- **첫 번째 인자**
  - 프로퍼티의 초기값
  - 위에서는 "Assu"
- **두 번째 인자**
  - `onChange()` 함수
  - 위에서는 _aName()_ 과 람다를 사용함

`onChange()` 는 3개의 파라메터를 받는다.
- **첫 번째 파라메터**
  - `KProperty<*>` 타입의 위임 프로퍼티의 대한 정보를 얻음
- **두 번째 파라메터**
  - 위임 프로퍼티의 현재 값을 나타내는 old 값
- **세 번째 파라메터**
  - 위임 프로퍼티에 저장하려는 new 값

---

## 2.4. `Delegates.notNull()`

**`Delegates.notNull()` 은 읽기 전에 꼭 초기화해줘야 하는 프로퍼티를 정의하는 함수**이다.

```kotlin
import kotlin.properties.Delegates

class NeverNull {
    var nn: Int by Delegates.notNull()
}

fun main() {
    val non = NeverNull()

    // java.lang.IllegalStateException: Property nn should be initialized before get.
    // println(non.nn)

    non.nn = 1
    println(non.nn) // 1
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