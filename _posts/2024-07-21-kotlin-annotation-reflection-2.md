---
layout: post
title: "Kotlin - 애너테이션과 리플렉션(2): 리플렉션 API, 리플렉션으로 직렬화 구현"
date: 2024-07-21
categories: dev
tags: kotlin reflection
---

이 포스트에서는 리플렉션에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin-2/tree/feature/chap10) 에 있습니다.

여기서는 리플렉션 API 에 어떤 내용들이 있는지 살펴본 후 제이키드에서 리플렉션 API 를 사용하는 방법에 대해 알아본다.  
직렬화를 살펴본 후 JSON 파싱과 역직렬화에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 리플렉션: 실행 시점에 코틀린 객체 내부 관찰](#1-리플렉션-실행-시점에-코틀린-객체-내부-관찰)
* [2. 리플렉션 API](#2-리플렉션-api)
  * [2.1. `KClass`](#21-kclass)
  * [2.2. `KCallable`, `KFunction`: `call()`, `invoke()`](#22-kcallable-kfunction-call-invoke)
    * [2.2.1. `KFunctionN` 인터페이스가 생성되는 시기와 방법](#221-kfunctionn-인터페이스가-생성되는-시기와-방법)
  * [2.3. `KProperty`](#23-kproperty)
  * [2.4. 리플렉션 API 인터페이스 계층 구조](#24-리플렉션-api-인터페이스-계층-구조)
* [3. 리플렉션을 사용하여 객체 직렬화 구현](#3-리플렉션을-사용하여-객체-직렬화-구현)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 리플렉션: 실행 시점에 코틀린 객체 내부 관찰

**리플렉션은 실행 시점에 동적으로 객체의 프로퍼티와 메서드에 접근**할 수 있게 해주는 방법이다.

보통 객체의 메서드나 프로퍼티에 접근할 때는 소스 코드 안에 구체적인 선언이 있는 메서드나 프로퍼티 이름을 사용하며, 컴파일러는 그런 이름이 실제로 가리키는 
선언을 컴파일 시점에 **정적**으로 찾아낸다.

하지만 **타입과 상관없이 객체를 다뤄야하거나 객체가 제공하는 메서드나 프로퍼티를 오직 실행 시점에만 알 수 있는 경우**가 있는데 JSON 직렬화 라이브러리가 그런 경우이다.  
직렬화 라이브러리는 어떤 객체든 JSON 으로 변환할 수 있어야 하며, 실행 시점이 되기 전까지는 라이브러리가 직렬화할 프로퍼티나 클래스에 대한 정보를 알 수 없다.

이럴 때 리플렉션을 사용한다.

코틀린에서 리플렉션을 사용하려면 2가지 서로 다른 리플렉션 API 를 사용해야 한다.

- **자바가 java.lang.reflect 패키지를 통해 제공하는 표준 리플렉션 API**
  - 코틀린 클래스는 일반 자바 바이트코드로 컴파일되므로 자바 리플렉션 API 도 코틀린 클래스를 컴파일한 바이트코드를 완벽히 지원함
  - 이는 리플렉션을 사용하는 자바 라이브러와 코틀린 코드가 완전히 호환된다는 의미임
- **코틀린이 kotlin.reflect 패키지를 통해 제공하는 코틀린 리플렉션 API**
  - 코틀린 리플렉션 API 는 자바에는 없는 프로퍼티나 null 이 될 수 있는 타입과 같은 코틀린 고유 개념에 대한 리플렉션을 제공함
  - 하지만 아직 코틀린 리플렉션 API 는 자바 리플렉션 API 를 완전히 대체할 수 있는 복잡한 기능을 제공하지는 않음
  - 따라서 자바 리플렉션을 대안으로 사용해야 하는 경우가 생김
  - 또한 코틀린 리플렉션 API 가 코틀린 클래스만 다룰 수 있는게 아니라 다른 JVM 언어에서 생성한 바이트코드를 충분히 다룰 수 있다는 점도 알아두면 좋음

> 안드로이드와 같이 런타임 라이브러리 크기가 문제가 되는 플랫폼을 위해 코틀린 리플렉션 API 는 kotlin-reflect.jar 라는 별도의 .jar 파일에 담겨 제공됨  
> 새로운 프로젝트 생성 시 리플렉션 패키지 .jar 파일에 대한 의존 관계가 자동으로 추가되지 않으므로 코틀린 리플렉션 API 를 사용한다면 직접 프로젝트 의존 관계에 
> .jar 파일을 추가해야 함
> 
> intelliJ 는 리플렉션 API 를 사용한 경우에 빠진 의존 관계를 자동으로 인식해서 관련 .jar 파일을 추가하도록 도와줌
> 
> 코틀린 리플렉션 패키지의 메이븐 그룹/아티팩트 ID 는 org.jetbrains.kotlin:kotlin-reflect 임

---

# 2. 리플렉션 API

## 2.1. `KClass`

코틀린 리플렉션 API 사용 시 처음 접하게 되는 것은 클래스를 표현하는 `KClass` 이다.

> `KClass` 대해 좀 더 다양한 내용을 알기 위해  
> [1. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#1-%ED%95%A8%EC%88%98%EC%9D%98-%ED%83%80%EC%9E%85-%EC%9D%B8%EC%9E%90%EC%97%90-%EB%8C%80%ED%95%9C-%EC%8B%A4%EC%B2%B4%ED%99%94-reified-kclass),  
> [6. 애너테이션 파라미터로 클래스 사용: KClass](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#6-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A1%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%82%AC%EC%9A%A9-kclass)  
> 와 함께 보면 도움이 됩니다.

java.lang.Class 에 해당하는 `KClass` 를 사용하면 클래스 안에 있는 모든 선언을 열거하고, 각 선언에 접근하거나 클래스의 상위 클래스를 얻는 등의 작업이 가능하다.

**_MyClass::class_ 라는 식을 이용하면 `KClass` 의 인스턴스**를 얻을 수 있다.

**실행 시점에 객체의 클래스를 얻으려면 먼저 객체의 `javaClass` 프로퍼티를 사용하여 객체의 자바 클래스**를 얻어야 한다.  
**`javaClass` 는 자바의 java.lang.Object.getClass()** 와 같다.

**자바 클래스를 얻었으면 .kotlin 확장 프로퍼티를 통해 자바에서 코틀린 리플렉션 API 로 옮겨올 수 있다.**

아래는 `KClass` 를 이용하여 클래스명과 클래스에 선언된 프로퍼티명을 가져오는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

import kotlin.reflect.KClass
import kotlin.reflect.full.memberProperties // memberProperties 확장 함수 임포트

class Person(
    val name: String,
    val age: Int,
)

fun main() {
    val person = Person("Assu", 20)
    val clazz: Class<Person> = person.javaClass
    val kClazz: KClass<Person> = person.javaClass.kotlin

    // Person
    println(clazz.simpleName)

    // Person
    println(kClazz.simpleName)

    // memberProperties 를 통해 클래스와 모든 조상 클래스 내부에 정의된 비확장 프로퍼티를 가져옴
    // age
    // name
    kClazz.memberProperties.forEach { println(it.name) }
}
```

[`KClass` 선언](https://github.com/JetBrains/kotlin/blob/1.1.3/core/builtins/src/kotlin/reflect/KClass.kt)을 보면 클래스의 내부를 살펴볼 때 사용할 수 있는 다양한 메서드를 볼 수 있다.

`KClass` 시그니처

```kotlin
package kotlin.reflect

public actual interface KClass<T : Any> : KDeclarationContainer, KAnnotatedElement, KClassifier {
    public actual val simpleName: String?
    public actual val qualifiedName: String?
    override val members: Collection<KCallable<*>>
    public val constructors: Collection<KFunction<T>>
    public val nestedClasses: Collection<KClass<*>>
    
    // ...
}
```

`memberProperties` 를 비롯해서 `KClass` 에 대해 사용할 수 있는 다양한 기능은 실제로는 `kotlin-reflect` 라이브러리를 통해서 제공하는 확장 함수이다.

이런 확장 함수를 사용하려면 `import kotlin.reflect.full.*` 로 확장 함수 선언을 임포트해야 한다.

`KClass` 에 정의된 확장 함수를 포함한 메서드 목록은 [표준 라이브러리 참조 문서](https://kotlinlang.org/api/latest/jvm/stdlib/kotlin.reflect/-k-class/)에서 볼 수 있다.

---

## 2.2. `KCallable`, `KFunction`: `call()`, `invoke()`

`KClass` 클래스의 모든 멤버 목록은 `KCallable` 인스턴스의 컬렉션이다.

**`KCallable` 은 함수와 프로퍼티를 아우르는 공통 상위 인터페이스**로 `call()` 메서드를 포함하고 있다.  
**`call()` 메서드를 사용하면 함수나 프로퍼티의 getter 를 호출**할 수 있다.

- **`KCallable.call()`**
  - 해당 함수 호출
- **`KProperty.call()`**
  - 해당 프로퍼티의 getter 호출

`KCallable` 인터페이스 시그니처

```kotlin
package kotlin.reflect

public actual interface KCallable<out R> : KAnnotatedElement {
  public fun call(vararg args: Any?): R
  
  // ...
}
```

`call()` 을 사용할 때는 함수 인자를 [`vararg`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#41-%EA%B0%80%EB%B3%80-%EC%9D%B8%EC%9E%90-%EB%AA%A9%EB%A1%9D-vararg) 리스트로 전달한다.

리플렉션이 제공하는 `call()` 을 사용하여 함수를 호출하는 예시

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

fun foo(x: Int): Unit = println(x)

fun foo2(
  x: Int,
  y: Int,
): Unit = println(x + y)

fun main() {
  // KFunction1<Int, Unit> 타입 리턴
  val kFunctionFoo1 = ::foo
  
  // 2
  kFunctionFoo1.call(2)

  // 런타임 오류
  // Callable expects 1 arguments, but 2 were provided.
}
```

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

fun foo3(
  x: Int,
  y: Int,
  z: Int,
): Unit = println(x + y + z)

fun main() {
  // KFunction3<Int, Int, Int, Unit> 타입 리턴
  val kFunctionFoo2 = ::foo3

  // 런타임 오류
  // Callable expects 3 arguments, but 1 were provided.

  // kFunctionFoo2.call(1)

  // 3
  kFunctionFoo2.call(1, 2, 3)
}

```

[멤버 참조 `::`](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#3-%EB%A9%A4%EB%B2%84-%EC%B0%B8%EC%A1%B0-) 인 _::foo_ 식의 
값 타입은 리플렉션 API 에 있는 `KFunction` 클래스의 인스턴스이다.

이 함수 참조가 가리키는 함수를 호출하려면 `KCallable.call()` 메서드를 호출한다.

`call()` 에 넘기는 인자 개수와 원래 함수에 정의된 파라미터 개수가 틀리면 _Callable expects 1 arguments, but 2 were provided._ **런타임 에러**가 발생한다.

함수 호출을 위해 더 구체적인 메서드를 사용할 수도 있다.

위에서 **_::foo_ 의 타입 _KFunction1\<Int, Unit\>_ 에는 파라미터와 반환값 타입 정보**가 들어있다.  
여기서 **`1` 은 이 함수의 파라미터가 1개라는 의미**이다.

`KFunction1` 인터페이스를 통해 함수를 호출하려면 `invoke()` 메서드를 사용해야 한다.  
**`invoke()` 메서드는 정해진 개수의 인자만을 받아들이며 (`KFunction1` 은 1개), 인자 타입은 `KFunction1` 제네릭 인터페이스의 첫 번째 타입 파라미터**와 같다.  
또한 `invoke()` 를 명시적으로 호출하는 대신 _kFunctionFoo1_ 을 직접 호출할 수도 있다.

> `invoke()` 를 명시적으로 호출하지 않고도 직접 _kFunctionFoo1_ 을 호출할 수 있는 이유에 대해서는 [1. `invoke()` 관례를 사용한 블록 중첩](https://assu10.github.io/dev/2024/08/03/kotlin-dsl-2/#1-invoke-%EA%B4%80%EB%A1%80%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EB%B8%94%EB%A1%9D-%EC%A4%91%EC%B2%A9) 을 참고하세요.

`invoke()` 를 통해 함수를 호출하는 예시

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

fun sum(
    x: Int,
    y: Int,
) = x + y

fun main() {
    // KFunction<Int, Int, Int> 타입 리턴
    val kFunction = ::sum

    // 10
    println(kFunction.invoke(1, 2) + kFunction(3, 4))

    // 컴파일 오류
    // No value passed for parameter 'y'

    // kFunction(1)
}
```

`KFunction` 의 `invoke()` 메서드를 호출할 때는 인자 개수나 타입이 맞아떨어지지 않으면 컴파일 오류가 발생한다.  
따라서 **`KFunction` 의 인자 타입과 반환 타입을 모두 안다면 `call()` 메서드보다는 `invoke()` 메서드를 호출**하는 것이 좋다.

**`call()` 메서드는 모든 타입의 함수에 적용할 수 있는 메서드이지만 타입의 안전성을 보장해주지는 않는다. (= 컴파일 오류가 아닌 런타임 오류 발생)**

---

### 2.2.1. `KFunctionN` 인터페이스가 생성되는 시기와 방법

`KFunction1` 과 같은 타입은 파라미터 개수가 다른 여러 함수를 표현한다.  
각 `KFunctionN` 타입은 `KFunction` 을 확장하며, N 과 파라미터 개수가 같은 `invoke()` 메서드를 추가로 포함한다.

예를 들어 `KFunction2<P1, P2, R>` 에는 `operator fun invoke(p1: P1, p2: P2): R` 선언이 있다.

이런 함수 타입들은 **컴파일러가 생성한 합성 타입**(synthetic compiler-generated type) 이다.

**따라서 kotlin.reflect 패키지에서 이런 타입의 정의를 찾을수는 없다.**

코틀린에서는 컴파일러가 생성한 합성 타입을 사용하기 때문에 원하는 수만큼 많은 파라미터를 갖는 함수에 대한 인터페이스를 사용할 수 있다.

합성 타입을 사용하기 때문에 코틀린은 `kotlin-runtime.jar` 의 크기를 줄일 수 있고, 함수 파라미터 개수에 대한 제약을 피할 수 있다.

---

## 2.3. `KProperty`

**`KProperty` 의 `call()` 메서드를 호출하면 프로퍼티의 getter 를 호출**한다.  
**하지만 프로퍼티 인터페이스는 프로퍼티 값을 얻는 더 좋은 방법으로 `get()` 메서드를 제공**한다.

**최상위 프로퍼티는 `KProperty0` 인터페이스의 인터페이스로 표현되며, `KProperty0` 안에는 인자가 없는 `get()` 메서드**도 있다.

최상위 프로퍼티에 대해 setter 와 call() 을 사용하여 프로퍼티 값을 가져오는 예시

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

import kotlin.reflect.KMutableProperty0

var counter = 0

fun main() {
    val kProperty: KMutableProperty0<Int> = ::counter

    // 리플렉션 기능을 통해 setter 를 호출하면서 21 을 인자로 넘김
    kProperty.setter.call(21)

    // 21
    // get() 을 호출하여 프로퍼티값을 가져옴
    println(kProperty.get())
}
```

멤버 프로퍼티는 `KProperty1` 인스턴스로 표현되며, 그 안에는 인자가 1개인 `get()` 메서드가 들어있다.  
**멤버 프로퍼티는 어떤 객체에 속해 있는 프로퍼티이므로 멤버 프로퍼티의 값을 가져오려면 `get()` 메서드에 프로퍼티를 얻고자 하는 객체 인스턴스를 넘겨야 한다.**

멤버 프로퍼티에 대해 `KProperty.get()` 을 사용하여 프로퍼티 값을 가져오는 예시

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

import kotlin.reflect.KProperty1

class People(
    val name: String,
    val age: Int,
)

fun main() {
    val people = People("Assu", 20)

    // memberProperty 변수에 프로퍼티 참조 저장
    val memberProperty: KProperty1<People, Int> = People::age

    // people 인스턴스의 프로퍼티값 가져옴
    // 20
    println(memberProperty.get(people))
}
```

`KProperty1` 은 제네릭 클래스이다.

위에서 _memberProperty_ 변수는 **`KProperty1<People, Int>` 타입으로 첫 번째 타입 파라미터는 수신 객체 타입, 두 번째 타입 파라미터는 프로퍼티 타입**이다.  
따라서 수신 객체를 넘길 때는 `KProperty1` 의 타입 파라미터와 일치하는 타입의 객체만을 넘길 수 있고, _memberProperty.get("aa")_ 와 같은 호출은 컴파일이 되지 않는다.

`KPeoperty` 인터페이스 시그니처

```kotlin
@file:Suppress("IMPLEMENTING_FUNCTION_INTERFACE")
package kotlin.reflect

public actual interface KProperty<out V> : KCallable<V> {
  @SinceKotlin("1.1")
  public val isLateinit: Boolean
 
  @SinceKotlin("1.1")
  public val isConst: Boolean

  public val getter: Getter<V>
  
  public interface Accessor<out V> {
    public val property: KProperty<V>
  }

  public interface Getter<out V> : Accessor<V>, KFunction<V>
}

public actual interface KMutableProperty<V> : KProperty<V> {
  public val setter: Setter<V>

  public interface Setter<V> : KProperty.Accessor<V>, KFunction<Unit>
}


public actual interface KProperty0<out V> : KProperty<V>, () -> V {
  public actual fun get(): V

  @SinceKotlin("1.1")
  public fun getDelegate(): Any?

  override val getter: Getter<V>

  public interface Getter<out V> : KProperty.Getter<V>, () -> V
}

public actual interface KMutableProperty0<V> : KProperty0<V>, KMutableProperty<V> {
  public actual fun set(value: V)

  override val setter: Setter<V>

  public interface Setter<V> : KMutableProperty.Setter<V>, (V) -> Unit
}


public actual interface KProperty1<T, out V> : KProperty<V>, (T) -> V {
  public actual fun get(receiver: T): V

  @SinceKotlin("1.1")
  public fun getDelegate(receiver: T): Any?

  override val getter: Getter<T, V>

  public interface Getter<T, out V> : KProperty.Getter<V>, (T) -> V
}

public actual interface KMutableProperty1<T, V> : KProperty1<T, V>, KMutableProperty<V> {
  public actual fun set(receiver: T, value: V)

  override val setter: Setter<T, V>

  public interface Setter<T, V> : KMutableProperty.Setter<V>, (T, V) -> Unit
}


public actual interface KProperty2<D, E, out V> : KProperty<V>, (D, E) -> V {
  public actual fun get(receiver1: D, receiver2: E): V

  @SinceKotlin("1.1")
  public fun getDelegate(receiver1: D, receiver2: E): Any?

  override val getter: Getter<D, E, V>

  public interface Getter<D, E, out V> : KProperty.Getter<V>, (D, E) -> V
}

public actual interface KMutableProperty2<D, E, V> : KProperty2<D, E, V>, KMutableProperty<V> {
  public actual fun set(receiver1: D, receiver2: E, value: V)

  override val setter: Setter<D, E, V>

  public interface Setter<D, E, V> : KMutableProperty.Setter<V>, (D, E, V) -> Unit
}
```

---

**최상위 수준이나 클래스 안에 정의된 멤버 프로퍼티에만 리플렉션으로 접근할 수 있고, 로컬 변수에는 접근할 수 없다.**

로컬 변수에 대해 리플렉션으로 접근 시도 시 컴파일 오류나는 예시

```kotlin
package com.assu.study.kotlin2me.chap10.reflection

fun main() {
    val x: Int = 1

    // 최상위 수준이나 클래스 안에 정의된 멤버 프로퍼티만 리플렉션으로 접근 가능
    // 컴파일 오류
    // References to variables and parameters are unsupported
    // (변수와 파라미터에 대한 참조는 지원하지 않음)
  
    // val memberProperty = ::x
}
```

---

## 2.4. 리플렉션 API 인터페이스 계층 구조

아래는 실행 시점에 소스 코드 요소에 접근하기 위해 사용할 수 있는 인터페이스의 계층 구조이다.

![코틀린 리플렉션 API 계층 구조](/assets/img/dev/2024/0721/reflection.png)

`KClass`, `KCallable`, `KParameter` 모두 `KAnnotatedElement` 를 확장한다.

`KClass` 는 클래스와 객체를 표현할 때 사용되고, `KProperty` 는 모든 프로퍼티를 표현할 때 사용한다.  
`KProperty` 의 하위 인터페이스인 `KMutableProperty` 는 var 로 정의한 변경 가능한 프로퍼티를 표현한다.

`KProperty` 와 `KMutableProperty` 에 선언된 `Getter` 와 `Setter` 인터페이스로 프로퍼티 접근자를 함수처럼 다룰 수 있다.  
따라서 접근자 메서드 getter/setter 에 붙어있는 애너테이션을 알아내려면 `Getter` 와 `Setter` 인터페이스를 통해야 한다.

`Getter` 와 `Setter` 는 모두 `KFunction` 을 확장한다.

---

# 3. 리플렉션을 사용하여 객체 직렬화 구현

먼저 제이키드의 직렬화 함수 선언을 보자.

```kotlin
fun serialize(obj: Any): String = buildString { serializeObject(obj) }
```

이 함수는 객체를 받아서 그 객체에 대한 JSON 표현을 문자열로 돌려준다.  
이 함수는 객체의 프로퍼티와 값을 직렬화하면서 `StringBuilder` 객체 뒤에 직렬화한 문자열을 추가한다.  
이 `append()` 호출을 더 간결하게 하기 위해 직렬화 기능을 `StringBuilder` 의 확장 함수로 구현하였다.  
이렇게 구현함으로서 `StringBuilder` 객체를 지정하지 않아도 `append()` 메서드를 편하게 사용할 수 있다.

> `StringBuilder` 와 `buildString()` 에 대한 설명은 [1.8. 확장 람다와 사용하는 `StringBuilder` 와 `buildString()`](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#18-%ED%99%95%EC%9E%A5-%EB%9E%8C%EB%8B%A4%EC%99%80-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-stringbuilder-%EC%99%80-buildstring) 을 참고하세요.

```kotlin
private fun StringBuilder.serializeObject(obj: Any) {
    obj.javaClass.kotlin.memberProperties
            .filter { it.findAnnotation<JsonExclude>() == null }
            .joinToStringBuilder(this, prefix = "{", postfix = "}") {
                serializeProperty(it, obj)
            }
}
```

위처럼 함수 파라미터를 확장 함수의 수신 객체로 바꾸는 방식은 코틀린에서 흔히 사용하는 패턴이다.

> 함수 파라미터를 확장 함수의 수신 객체로 바꾸는 방식은 코틀린에서 흔히 사용하는 패턴으로 이에 대한 내용은 [2. 구조화된 API: DSL 에서 수신 객체 지정 DSL 사용](https://assu10.github.io/dev/2024/07/28/kotlin-dsl-1/#2-%EA%B5%AC%EC%A1%B0%ED%99%94%EB%90%9C-api-dsl-%EC%97%90%EC%84%9C-%EC%88%98%EC%8B%A0-%EA%B0%9D%EC%B2%B4-%EC%A7%80%EC%A0%95-dsl-%EC%82%AC%EC%9A%A9) 을 참고하세요.

_StringBuilder.serializeObject()_ 는 `StringBuilder` API 를 확장하지 않는다는 점에 유의하자.    
_StringBuilder.serializeObject()_ 가 수행하는 연산은 외부에선 전혀 쓸모가 없기 때문에 private 가시성을 지정하여 다른 곳에서는 사용할 수 없게 하였다.  
_StringBuilder.serializeObject()_ 를 확장 함수로 만든 이유는 이 코드 블록에서 주로 사용하는 객체가 어떤 것인지 명확히 보여주고 그 객체를 더 쉽게 다루기 위함이다.

이렇게 확장 함수를 정의한 결과 _serialize()_ 는 대부분의 작업을 _StringBuilder.serializeObject()_ 에 위임한다.

`buildString()` 은 `StringBuilder` 를 생성하여 인자로 받은 람다에 넘긴다.  
람다 안에서는 `StringBuilder` 인스턴스를 `this` 로 사용할 수 있다.

```kotlin
fun serialize(obj: Any): String = buildString { serializeObject(obj) }
```

따라서 위 코드는 람다 본문에서 _serializeObject(obj)_ 를 호출해서 _obj_ 를 직렬화한 결과를 `StringBuilder` 에 추가한다.

---

이제 직렬화 함수에 대해 좀 더 알아본다.

직려로하 함수는 객체의 모든 프로퍼티를 직렬화한다.  
primitive 타입이나 문자열은 적절한 숫자, boolean, string 값으로 JSON 변환되고, 컬렉션은 JSON 배열로 직렬화된다.

primitive 타입이나 문자열, 컬렉션이 아닌 다른 타입인 프로퍼티는 중첩된 JSON 객체로 직렬화된다.  
[3. 애너테이션을 활용한 JSON 직렬화 제어](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#3-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98%EC%9D%84-%ED%99%9C%EC%9A%A9%ED%95%9C-json-%EC%A7%81%EB%A0%AC%ED%99%94-%EC%A0%9C%EC%96%B4) 에서 본 것처럼 이런 동작은 애너테이션을 통해 변경할 수 있다.

이제 제이키드의 _StringBuilder.serializeObject()_ 를 좀 더 자세히 보자.

```kotlin
// 결과 JSON 은 { prop1: value1, prop2: value2 } 와 같은 형태임
private fun StringBuilder.serializeObject(obj: Any) {
    // obj.javaClass.kotlin 은 객체의 KClass 를 얻음
    // kClass.memberProperties 는 클래스의 모든 프로퍼티를 얻음 (Collection<KProperty1<Any, *>>
  obj.javaClass.kotlin.memberProperties
    .filter { it.findAnnotation<JsonExclude>() == null }
    .joinToStringBuilder(this, prefix = "{", postfix = "}") {   // 프로퍼티를 콤마 , 로 분리해줌
      serializeProperty(it, obj)
    }
}

private fun StringBuilder.serializeProperty(
  prop: KProperty1<Any, *>, obj: Any
) {
  val jsonNameAnn = prop.findAnnotation<JsonName>()
  val propName = jsonNameAnn?.name ?: prop.name
  serializeString(propName) // 프로퍼티의 이름을 얻음
  append(": ")

  val value = prop.get(obj)
  val jsonValue = prop.getSerializer()?.toJsonValue(value) ?: value
  serializePropertyValue(jsonValue) //  프로퍼티의 값을 얻음
}

// 어떤 값이 primitive 타입, 문자열, 컬렉션, 중첩된 객체 중 어떤 것인지 판단하여 그에 따라 적절히 그 값을 직렬화
private fun StringBuilder.serializePropertyValue(value: Any?) {
  when (value) {
    null -> append("null")
    is String -> serializeString(value)
    is Number, is Boolean -> append(value.toString())
    is List<*> -> serializeList(value)
    else -> serializeObject(value)
  }
}

// JSON 명세에 따라 특수 문자를 이스케이프해줌
private fun StringBuilder.serializeString(s: String) {
  append('\"')
  s.forEach { append(it.escape()) }
  append('\"')
}
```

[2.3. `KProperty`](#23-kproperty) 에서 `KProperty` 인스턴스의 값을 얻는 방법인 `get()` 메서드에 대해 알아보았다.  
그 때는 _KProperty1\<People, Int\>_ 타입인 _People::age_ 프로퍼티를 처리했기 때문에 컴파일러가 수신 객체와 프로퍼티 값의 타입을 정확히 알 수 있었다.

하지만 지금은 어떤 객체의 클래스에 정의된 모든 프로퍼티를 열거하기 때문에 각 프로퍼티가 어떤 타입인지 알 수 없다.  
따라서 _StringBuilder.serializeProperty()_ 를 호출할 때 _prop_ 변수의 타입은 _KProperty1\<Any, *\>_ 이며, 
_prop.get(obj)_ 의 호출은 `Any?` 타입을 반환한다.

이 경우 수신 객체 타입을 컴파일 시점에 검사할 방법이 없다.  
하지만 지금 코드에서는 어떤 프로퍼티의 `get()` 에 넘기는 객체가 바로 그 프로퍼티를 얻어온 객체(_obj_) 이기 때무넹 항상 프로퍼티값이 제대로 반환된다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 드리트리 제메로프, 스베트라나 이사코바 저자의 **Kotlin In Action** 을 기반으로 스터디하며 정리한 내용들입니다.*

* [Kotlin In Action](https://www.yes24.com/Product/Goods/55148593)
* [Kotlin In Action 예제 코드](https://github.com/AcornPublishing/kotlin-in-action)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)
* [KClass 표준 라이브러리 doc](https://kotlinlang.org/api/latest/jvm/stdlib/kotlin.reflect/-k-class/)
* [jkid 예제 코드](https://github.com/yole/jkid)