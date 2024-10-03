---
layout: post
title:  "Kotlin - 프로퍼티 위임, 'ReadOnlyProperty', 'ReadWriteProperty', 프로퍼티 위임 도구 (Delegates.observable(), Delegates.vetoable(), Delegates.notNull()), 위임 프로퍼티 컴파일"
date: 2024-03-24
categories: dev
tags: kotlin KProperty ReadOnlyProperty ReadWriteProperty Delegates.observable() Delegates.vetoable() Delegates.notNull()
---

이 포스트에서는 프로퍼티 위임과 프로퍼티 위임 도구에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 프로퍼티 위임: `by` (프로퍼티 접근자 로직 재활용)](#1-프로퍼티-위임-by-프로퍼티-접근자-로직-재활용)
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
    * [2.2.1. 위임 프로퍼티 없이 값 추적](#221-위임-프로퍼티-없이-값-추적)
      * [2.2.1.1. `value-parameter`](#2211-value-parameter)
    * [2.2.2. 위임 프로퍼티를 사용하여 값 추적](#222-위임-프로퍼티를-사용하여-값-추적)
    * [2.2.3. 위임 프로퍼티 `by` 를 사용하여 값 추적](#223-위임-프로퍼티-by-를-사용하여-값-추적)
    * [2.2.4. 위임 프로퍼티 `by` 와 `Delegates.observable()` 를 사용하여 값 추적](#224-위임-프로퍼티-by-와-delegatesobservable-를-사용하여-값-추적)
  * [2.3. `Delegates.vetoable()`](#23-delegatesvetoable)
  * [2.4. `Delegates.notNull()`](#24-delegatesnotnull)
* [3. 위임 프로퍼티 컴파일 규칙](#3-위임-프로퍼티-컴파일-규칙)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 프로퍼티 위임: `by` (프로퍼티 접근자 로직 재활용)

> [9. 프로퍼티 접근자: `field`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90-field) 를 참고하세요.

> 클래스 위임에 대한 좀 더 상세한 내용은 [1. 클래스 위임 (class delegation)](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#1-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%9C%84%EC%9E%84-class-delegation) 을 참고하세요.

위임 프로퍼티를 사용하면 값을 뒷받침하는 필드 (= backing field) 에 단순히 저장하는 것보다 더 복잡한 방식으로 동작하는 프로퍼티를 쉽게 구현 가능하다.

또한 그 과정에서 접근자 로직을 매번 재구현할 필요도 없다.

예) 프로퍼티는 위임을 사용하여 자신의 값을 필드가 아니라 DB, 브라우저 세션, 맵 등에 저장 가능

> **backing field**
> 
> 대부분의 프로퍼티에는 그 프로퍼티 값을 저장하기 위한 필드가 있는데 그 필드를 backing field 라고 함

**위임은 객체가 직접 작업을 수행하지 않고 다른 도우미 객체가 그 작업을 처리하게 맡기는 디자인 패턴**이다.

여기서 **작업을 처리하는 도우미 객체를 위임 객체**라고 한다.

도우미 객체를 직접 작성할 수도 있지만 더 좋은 방법은 코틀린 언어가 제공하는 기능을 활용하는 것이다.

**프로퍼티는 접근자 로직을 위임할 수 있는데, `by` 키워드를 사용하여 프로퍼티를 위임과 연결**할 수 있다.

`val (또는 var) 프로퍼티명 by 위임할 객체`

위임 프로퍼티의 일반적인 문법

```kotlin
class Foo {
    var p: String by Delegate()
}
```

위 코드에서 p 프로퍼티는 접근자 로직을 다른 객체에게 위임한다.  
여기서는 Delegate 클래스의 인스턴스를 위임 객체(= 작업을 처리하는 도우미 객체)로 사용한다.  
`by` 뒤에 있는 식을 계산하여 위임에 쓰일 객체를 얻는다.

컴파일러는 위 코드를 아래와 같이 숨겨진 도우미 프로퍼티를 만든 후 그 프로퍼티를 위임 객체의 인스턴스로 초기화한다.  
_p_ 프로퍼티는 바로 그 위임 객체에게 자신의 작업을 위임한다.  
아래에서는 숨겨진 도우미 프로퍼티가 _delegate_ 이다.

컴파일러가 생성한 코드

```kotlin
class Foo {
    // 컴파일러가 생성한 도우미 프로퍼티
    private val delegate = Delegate()
  
    // p 프로퍼티를 위해 컴파일러가 생성한 접근자는 delegate 의 getValue() 와 setValue() 메서드를 호출함
    var p: String 
      set(value: String) = delegate.setValue(..., value)
      get() = delegate.getValue(...)
}
```

프로퍼티가 val (읽기 전용) 인 경우는 위임 객체의 클래스에 `getValue()` 함수 정의가 있어야 하고, 
프로퍼티가 var (쓰기 가능) 인 경우는 위임 객체의 클래스에 `getValue()`, `setValue()` 함수 정의가 있어야 한다.

이 때 getValue(), setValue() 는 멤버 함수이거나 확장 함수일 수 있다.

위임 객체인 Delegate 클래스를 단순화하면 아래와 같다.

```kotlin
class Delegate {
    operator fun getValue(...) { ... }
    operator fun setValue(..., value: Type) { ... }
}

class Foo {
    var p: Type by Delegate()
}

fun main() {
    val foo = Foo()
  
    // foo.p 라는 프로퍼티 호출은 내부에서 delegate.getValue(...) 를 호출함
    val oldValue = foo.p
  
    // 프로퍼티 값을 변경하는 문장은 내부에서 delegate.setValue(..., newValue) 를 호출함
    foo.p = newValue
}
```

_p_ 의 getter, setter 는 _Delegate_ 타입의 위임 프로퍼티 객체에 있는 메서드를 호출한다.

위임 프로퍼티의 강력함을 보여주는 예 중 하나가 프로퍼티 위임을 사용하여 프로퍼티 초기화를 지연시키는 것이다.

> 위임을 사용하여 프로프티 초기화를 지연시키는 예시는 [1.2. 위임 프로퍼티를 통해 지연 초기화를 구현: lazy()](https://assu10.github.io/dev/2024/03/30/kotlin-advanced-5/#12-%EC%9C%84%EC%9E%84-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0%EB%A5%BC-%ED%86%B5%ED%95%B4-%EC%A7%80%EC%97%B0-%EC%B4%88%EA%B8%B0%ED%99%94%EB%A5%BC-%EA%B5%AC%ED%98%84-lazy) 를 참고하세요.

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
  var captain: String by Delegates.observable("INIT임") { prop, old, new ->
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

### 2.2.1. 위임 프로퍼티 없이 값 추적

어떤 객체의 프로퍼티가 변경될 때마다 리스너에게 변경 통지를 보내야하는 경우를 생각해보자.

자바에서는 `PropertyChangeSupport` 와 `PropertyChangeEvent` 클래스를 사용하여 이런 통지를 처리하는 경우가 자주 있다.

여기서는 위 기능을 아래와 같은 순서로 리팩토링 해본다.

- 위임 프로퍼티 없이 값 추적
- 위임 프로퍼티를 이용하여 값 추적
- `Delegates.observable()` 을 사용하여 값 추적

`PropertyChangeSupport` 클래스는 리스너의 목록을 관리하고, `PropertyChangeEvent` 이벤트가 들어오면 모든 리스너에게 이벤트를 통지한다.  
보통 자바 빈 클래스의 필드에 `PropertyChangeSupport` 인스턴스를 저장하고, 프로퍼티 변경 시 그 인스턴스에게 처리를 위임하는 방식으로 통지 기능을 구현한다.

필드를 모든 클래스에 추가하고 싶지는 않으므로 `PropertyChangeSupport` 인스턴스를 _changeSupport_ 라는 필드에 저장하고 프로퍼티 변경 리스너를 추적해주는 
도우미 클래스를 만든다.  
리스너 지원이 필요한 클래스는 이 도우미 클래스를 확장하여 _changeSupport_ 에 접근 가능하다.

PropertyChangeSupport 를 사용하기 위한 도우미 클래스

```kotlin
package com.assu.study.kotlin2me.chap07

import java.beans.PropertyChangeListener
import java.beans.PropertyChangeSupport

// PropertyChangeSupport 를 사용하기 위한 도우미 클래스
open class PropertyChangeAware {
    protected val changeSupport = PropertyChangeSupport(this)

    fun addPropertyChangeListener(listener: PropertyChangeListener) {
        changeSupport.addPropertyChangeListener(listener)
    }

    fun removePropertyChangeListener(listener: PropertyChangeListener) {
        changeSupport.removePropertyChangeListener(listener)
    }
}
```

> `protected` 가시성 변경자에 대한 내용은 [10. 가시성 변경자 (access modifier, 접근 제어 변경자): `public`, `private`, `protected`, `internal`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#10-%EA%B0%80%EC%8B%9C%EC%84%B1-%EB%B3%80%EA%B2%BD%EC%9E%90-access-modifier-%EC%A0%91%EA%B7%BC-%EC%A0%9C%EC%96%B4-%EB%B3%80%EA%B2%BD%EC%9E%90-public-private-protected-internal) 를 참고하세요.

이제 _People_ 클래스를 작성한다.

읽기 전용 프로퍼티 (이름) 와 변경 가능한 프로퍼티 (나이, 급여) 를 정의한다.  
이 클래스는 나이가 급여가 변경되면 그 사실을 리스너에게 통지한다.

프로퍼티 변경 통지를 직접 구현한 _People_ 클래스

```kotlin
// 프로퍼티 변경 통지를 직접 구현
class People(
    val name: String, // public final val name: String
    age: Int, // value-parameter val age: Int
    salary: Int,
) : PropertyChangeAware() {
    var age: Int = age
        set(newValue) {
            // field 를 사용하여 age 프로퍼티의 backing field 에 접근
            val oldValue = field
            field = newValue

            // 프로퍼티 변경을 리스너에게 통지
            changeSupport.firePropertyChange("age", oldValue, newValue)
        }

    var salary: Int = salary
        set(newValue) {
            val oldValue = field
            field = newValue
            changeSupport.firePropertyChange("salary", oldValue, newValue)
        }
}
```

main 에서 실행

```kotlin
fun main() {
    val p = People("Assu", 20, 100)

    // 프로퍼티 변경 리스너 추가
    p.addPropertyChangeListener { event ->
        println("Property ${event.propertyName} changed from ${event.oldValue} to ${event.newValue}")
    }

    p.age = 25 // Property age changed from 20 to 25
    p.salary = 200 // Property salary changed from 100 to 200
}
```

_People_ 코드에서 `field` 키워드를 사용하여 _age_, _salary_ 프로퍼티의 `backing-field` 에 접근한다.

> 프로퍼티 접근자 `field` 에 대한 내용은 [9. 프로퍼티 접근자: `field`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90-field) 를 참고하세요.

setter 코드에 중복이 많이 보이는 것을 알 수 있다.

이제 프로퍼티의 값을 저장하고 필요에 따라 통지를 보내주는 클래스를 추출해보자.

---

#### 2.2.1.1. `value-parameter`

클래스 생성 시 `val` 혹은 `var` 가 없다면 `value-parameter` 이다.

**`val`, `var` 파라메터는 클래스의 멤버**로 들어가지만, **`val` 가 없다면 단지 생성자 초기화에 사용되는 파라메터**이다.

즉, 2 개의 목적은 아래와 같다.

- `val`, `var` 파라메터를 생성자 안에 사용
  - 이를 클래스의 멤버로써 정의하고 초기화까지 바로 진행
- `val` 나 `var` 가 없는 파라메터를 생성자 안에 사용
  - 단지 생성자 초기화에 사용

아래와 같은 코드가 있다고 하자.

val 가 있는 경우의 코틀린

```kotlin
class Foo(val bar: String)
```

이에 대응하는 자바 코드

```java
class Foo {
  String bar;
  public Foo(String bar) {
    this.bar = bar;
  }
}
```

val 가 없는 경우의 코틀린 (= `value-parameter`)

```kotlin
class Foo(bar: String)
```

이에 대응하는 자바 코드

```java
class Foo {

  public Foo(String bar) {

  }
}
```

`val` 가 없다면 클래스 내부에서 해당 변수에 접근할 수 없다.

```kotlin
class Foo(a: String, val b: Int)
```

위와 같은 코드가 있을 때 _Foo_ 클래스 내부에서 _b_ 변수에는 접근 가능하지만 _a_ 변수에는 접근이 불가하다.

> 관련하여 [Kotlin doc: Classes](https://kotlinlang.org/docs/classes.html),  
> [Why do I need a parameter in a primary constructor without val/var modifier in Kotlin?](https://stackoverflow.com/questions/49610775/why-do-i-need-a-parameter-in-a-primary-constructor-without-val-var-modifier-in-k),   
> [stackoverflow: value-parameter](https://stackoverflow.com/questions/60409838/difference-between-val-parameter-or-without-val)  
> 를 참고하면 도움이 됩니다.

---

### 2.2.2. 위임 프로퍼티를 사용하여 값 추적

아래는 [2.2.1. 위임 프로퍼티 없이 값 추적](#221-위임-프로퍼티-없이-값-추적) 구현한 _People_ 클래스의 불필요한 중복 로직 제거를 위해 2개로 분리하는 예시이다.

- 프로퍼티 값을 저장하고 필요에 따라 통지를 보내주는 클래스 추출
- _People_ 클래스

도우미 클래스를 사용하여 프로퍼티 변경 통지 구현

```kotlin
package com.assu.study.kotlin2me.chap07

import java.beans.PropertyChangeListener
import java.beans.PropertyChangeSupport

// PropertyChangeSupport 를 사용하기 위한 도우미 클래스 (이건 그대로 사용)
open class PropertyChangeAware2 {
    protected val changeSupport = PropertyChangeSupport(this)

    fun addPropertyChangeListener(listener: PropertyChangeListener) {
        changeSupport.addPropertyChangeListener(listener)
    }

    fun removePropertyChangeListener(listener: PropertyChangeListener) {
        changeSupport.removePropertyChangeListener(listener)
    }
}

// 프로퍼티의 값을 저장하고 필요에 따라 통지를 보내주는 클래스
class ObservableProperty(val propName: String, var propValue: Int, val changeSupport: PropertyChangeSupport) {
    fun getValue(): Int = propValue
    fun setValue(newValue: Int) {
        val oldValue = propValue
        propValue = newValue
        changeSupport.firePropertyChange(propName, oldValue, newValue)
    }
}
```

```kotlin
class People2(
    val name: String,
    age: Int,
    salary: Int,
) : PropertyChangeAware2() {
    val _age = ObservableProperty("age", age, changeSupport)
    var age: Int
        get() = _age.getValue()
        set(value) {
            _age.setValue(value)
        }

    val _salary = ObservableProperty("salary", salary, changeSupport)
    var salary: Int
        get() = _salary.getValue()
        set(value) {
            _salary.setValue(value)
        }
}
```

프로퍼티 값을 저장하고 그 값이 변경되면 변경 통지를 전달해주는 클래스를 통해 로직 중복을 많이 제거했다.

하지만 아직도 각 프로퍼티마다 _ObservableProperty_ 를 만들고, getter/setter 에서 _ObservableProperty_ 에게 작업을 위임하는 준비 코드가 상당 부분 필요하다.

코틀린의 위임 프로퍼티 기능을 사용하면 이런 준비 코드를 없앨 수 있다.

```kotlin
fun main() {
    val p = People2("Assu", 20, 100)

    // 프로퍼티 변경 리스너 추가
    p.addPropertyChangeListener { event ->
        println("Property ${event.propertyName} changed from ${event.oldValue} to ${event.newValue}")
    }

    p.age = 25 // Property age changed from 20 to 25
    p.salary = 200 // Property salary changed from 100 to 200
}
```

---

### 2.2.3. 위임 프로퍼티 `by` 를 사용하여 값 추적

코틀린의 위임 프로퍼티를 사용하기 위해 위에서 작성한 _ObservableProperty_ 에 있는 _getValue()_, _setValue()_ 를 코틀린의 관례에 맞게 수정해준다.

```kotlin
package com.assu.study.kotlin2me.chap07

import java.beans.PropertyChangeListener
import java.beans.PropertyChangeSupport
import kotlin.reflect.KProperty

// PropertyChangeSupport 를 사용하기 위한 도우미 클래스 (이건 그대로 사용)
open class PropertyChangeAware3 {
    protected val changeSupport = PropertyChangeSupport(this)

    fun addPropertyChangeListener(listener: PropertyChangeListener) {
        changeSupport.addPropertyChangeListener(listener)
    }

    fun removePropertyChangeListener(listener: PropertyChangeListener) {
        changeSupport.removePropertyChangeListener(listener)
    }
}

// 프로퍼티의 값을 저장하고 필요에 따라 통지를 보내주는 클래스
// 위임 프로퍼티를 사용하기 위해 getValue(), setValue() 를 코틀린 관례에 맞게 수정
class ObservableProperty3(
    var propValue: Int,
    val changeSupport: PropertyChangeSupport,
) {
    operator fun getValue(
        p: People3,
        prop: KProperty<*>,
    ): Int = propValue

    operator fun setValue(
        p: People3,
        prop: KProperty<*>,
        newValue: Int,
    ) {
        val oldValue = propValue
        propValue = newValue
        changeSupport.firePropertyChange(prop.name, oldValue, newValue)
    }
}
```

_ObservableProperty3_ 가 달라진 점은 아래와 같다.

- 코틀린 관례에 사용하는 다른 함수들처럼 [`operator`](https://assu10.github.io/dev/2024/03/23/kotlin-advanced-3/#1-%EC%97%B0%EC%82%B0%EC%9E%90-%EC%98%A4%EB%B2%84%EB%A1%9C%EB%94%A9-operator) 변경자를 붙임
- _getValue()_, _setValue()_ 는 2개의 인자를 밭음
  - 프로퍼티가 포함된 객체 (위에서는 People3 타입인 p)
  - 프로퍼티를 표현하는 객체 (`KProperty`)
    - `KProperty.name` 을 통해 메서드가 처리할 프로퍼티명을 알 수 있음
- `KProperty` 를 통해 프로퍼티 이름을 전달받으므로 주 생성자에서 _name_ 프로퍼티는 없앰

> `KProperty` 에 대해서는 추후 다룰 예정입니다. (p. 338)

이제 위임 프로퍼티를 사용할 수 있다.

```kotlin
class People3(
    val name: String,
    age: Int,
    salary: Int,
) : PropertyChangeAware3() {
    var age: Int by ObservableProperty3(age, changeSupport)
    var salary: Int by ObservableProperty3(salary, changeSupport)
}
```

`by` 키워드를 이용하여 위임 객체를 사용하면 위에서 직접 코드를 짜야했던 부분들을 코틀린 컴파일러가 자동으로 처리해준다.

**`by` 오른쪽에 오는 객체를 위임 객체**라고 한다.

코틀린은 위임 객체를 감춰진 프로퍼티에 저장하고, 주 객체의 프로퍼티를 읽거나 쓸 때마다 위임 객체의 getValue(), setValue() 를 호출해준다.

```kotlin
fun main() {
    val p = People3("Assu", 20, 100)

    // 프로퍼티 변경 리스너 추가
    p.addPropertyChangeListener { event ->
        println("Property ${event.propertyName} changed from ${event.oldValue} to ${event.newValue}")
    }

    p.age = 25 // Property age changed from 20 to 25
    p.salary = 200 // Property salary changed from 100 to 200
}
```

---

### 2.2.4. 위임 프로퍼티 `by` 와 `Delegates.observable()` 를 사용하여 값 추적

코틀린에는 이미 위의 _ObservableProperty_ 와 비슷한 역할 (= 프로퍼티를 관찰) 을 하는 함수인 `Delegates.observable()` 를 제공하고 있다.

다만 `Delegates.observable()` 는 `PropertyChangeSupport` 와는 연결되어 있지 않으므로 프로퍼티 값의 변경을 통지할 때 `PropertyChangeSupport` 를 
사용하는 방법을 알려주는 람다를 함께 넘겨주어야 한다.

위임 프로퍼티 `by` 와 `Delegates.observable()` 사용

```kotlin
package com.assu.study.kotlin2me.chap07

import java.beans.PropertyChangeListener
import java.beans.PropertyChangeSupport
import kotlin.properties.Delegates
import kotlin.reflect.KProperty

// PropertyChangeSupport 를 사용하기 위한 도우미 클래스 (이건 그대로 사용)
open class PropertyChangeAware4 {
  protected val changeSupport = PropertyChangeSupport(this)

  fun addPropertyChangeListener(listener: PropertyChangeListener) {
    changeSupport.addPropertyChangeListener(listener)
  }

  fun removePropertyChangeListener(listener: PropertyChangeListener) {
    changeSupport.removePropertyChangeListener(listener)
  }
}

// 위임 프로퍼티 `by` 와 `Delegates.observable()` 사용
class People4(
  val name: String,
  age: Int,
  salary: Int,
) : PropertyChangeAware4() {
  private val observer = { prop: KProperty<*>, oldValue: Int, newValue: Int ->
    changeSupport.firePropertyChange(prop.name, oldValue, newValue)
  }

  var age: Int by Delegates.observable(age, observer)
  var salary: Int by Delegates.observable(salary, observer)
}
```

`by` 의 오른쪽에 있는 식을 계산한 결과인 객체는 컴파일러가 호출할 수 있는 올바른 타입의 `getValue()` 와 `setValue()` 를 반드시 제공해야 한다.

```kotlin
fun main() {
    val p = People4("Assu", 20, 100)

    // 프로퍼티 변경 리스너 추가
    p.addPropertyChangeListener { event ->
        println("Property ${event.propertyName} changed from ${event.oldValue} to ${event.newValue}")
    }

    p.age = 25 // Property age changed from 20 to 25
    p.salary = 200 // Property salary changed from 100 to 200
}
```

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

# 3. 위임 프로퍼티 컴파일 규칙

여기서는 위임 프로퍼티가 어떤 방식으로 동작하는지에 대해 알아본다.

위임 프로퍼티가 있는 클래스

```kotlin
class C {
    var prop: Type by MyDelegate()
}

val c = C()
```

컴파일러는 _MyDelegate_ 클래스의 인스턴스를 감춰진 프로퍼티에 저장하고, 그 감춰진 프로퍼티를 `<delegate>` 라고 한다.

또한 프로퍼티를 표현하기 위해 `KProperty` 타입의 객체를 사용하여, 그 객체를 `<property>` 라고 한다.

위의 클래스에 대해 컴파일러는 아래의 코드를 생성한다.

```kotlin
class C {
    private var <delegate> = MyDelegate()
    var prop: Type
        get() = <delegate>.getValue(this, <property>)
        set(value: Type) = <delegate>.setValue(this, <property>, value)
}
```

즉, 컴파일러는 모든 프로퍼티 접근자에 대해 `getValue()`, `setValue()` 호출 코드를 생성해준다.

```kotlin
val x = c.prop

// 아래의 getValue() 호출코드 생성
val x = <delegate>.getValue(c, <property>)
```

```kotlin
c.prop = x 

// 아래의 setValue() 호출코드 생성
<delegate>.setValue(c, <property>, x)
```

위의 메커니즘을 이용하여 프로퍼티 값이 저장될 장소를 바꿀 수도 있고 (맵, DB, 쿠키 등), 프로퍼티를 읽거나 쓸 때 벌어지는 일을 변경할 수도 있다. (값 검증, 변경 통지 등)

이 모든 일을 간결한 코드로 달성할 수 있다.

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
* [Kotlin doc: backing-fields](https://kotlinlang.org/docs/properties.html#backing-fields)
* [Kotlin doc: backing-properties](https://kotlinlang.org/docs/properties.html#backing-properties)
* [stackoverflow: value-parameter](https://stackoverflow.com/questions/60409838/difference-between-val-parameter-or-without-val)
* [Why do I need a parameter in a primary constructor without val/var modifier in Kotlin?](https://stackoverflow.com/questions/49610775/why-do-i-need-a-parameter-in-a-primary-constructor-without-val-var-modifier-in-k)