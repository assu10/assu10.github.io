---
layout: post
title: "Kotlin - 애너테이션과 리플렉션(1): 애너테이션"
date: 2024-07-14
categories: dev
tags: kotlin annotation
---

이 포스트에서는 애너테이션에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin-2/tree/feature/chap10) 에 있습니다.

어떤 함수를 호출하려면 그 함수가 정의된 클래스의 이름과 함수 이름, 파라메터 이름 등을 알아야만 한다.

하지만 애너테이션과 리플렉션을 사용하면 그런 제약을 벗어나서 미리 알지 못하는 임의의 클래스를 다룰 수 있다.

**애너테이션을 사용하면 라이브러리가 요구하는 의미를 클래스에 부여**할 수 있고, **리플렉션을 사용하면 실행 시점에 컴파일러 내부 구조를 분석**할 수 있다.

여기서는 실전 프로젝트에 준하는 JSON 직렬화와 역직렬화 라이브러리인 JKid(제이키드)를 구현해본다.  
제이키드는 실행 시점에 코틀린 객체의 프로퍼티를 읽거나 JSON 파일에서 읽은 데이터를 코틀린 객체로 만들기 위해 리플렉션을 사용한다.  
그리고 애너테이션을 통해 제이키드 라이브러리가 클래스와 프로퍼티를 직렬화/역직렬화하는 방식을 변경한다.

---

**목차**

<!-- TOC -->
* [1. 애너테이션 적용](#1-애너테이션-적용)
* [2. 애너테이션 대상: 사용 지점 대상](#2-애너테이션-대상-사용-지점-대상)
* [3. 애너테이션을 활용한 JSON 직렬화 제어](#3-애너테이션을-활용한-json-직렬화-제어)
* [4. 애너테이션 선언: `annotation`](#4-애너테이션-선언-annotation)
* [5. 메타 애너테이션: 애너테이션을 처리하는 방법 제어 `@Target`](#5-메타-애너테이션-애너테이션을-처리하는-방법-제어-target)
  * [5.1. `@Retention`](#51-retention)
* [6. 애너테이션 파라메터로 클래스 사용: `KClass`](#6-애너테이션-파라메터로-클래스-사용-kclass)
* [7. 애너테이션 파라메터로 제네릭 클래스 받기](#7-애너테이션-파라메터로-제네릭-클래스-받기)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 애너테이션 적용

코틀린도 자바처럼 메타데이터를 선언에 추가하면 애너테이션을 처리하는 도구가 컴파일 시점이나 실행 시점에 적절한 처리를 해준다.

`@Deprecated` 애너테이션을 예로 들면 코틀린에서는 `replaceWith` 파라메터를 통해 옛 버전을 대신할 수 있는 패턴을 제시하여, API 사용자는 그 패턴을 보고 
지원이 종료될 API 기능을 더 쉽게 새로운 버전으로 포팅할 수 있다.

```kotlin
package com.assu.study.kotlin2me.chap10.annotation

@Deprecated("Use removeNew(index) instead", ReplaceWith("removeNew(index)"))
fun remove(index: Int) {
    // ...
}

fun removeNew(index: Int) {
    // ...
}

fun main() {
    remove(1)
}
```

![@Deprecated 시 ReplaceWith 로 자동 경고 및 변경](/assets/img/dev/2024/0714/remove.png)

만일 `@Deprecated` 로 선언된 함수를 호출하는 곳이 있다면 intelliJ 는 해당 코드에 대해 경고 메시지인 _Use removeNew(index) instead_ 를 띄워줄 뿐 아니라 
자동으로 그 코드를 새로운 API 버전에 맞는 코드로 변경해주는 quick fix 도 제시해준다.

위 그림에서 _Replace with 'removeNew(index)`_ 를 누르면 intelliJ 가 바로 새로운 함수로 코드를 변경해준다.

---

**애너테이션 인자**로는 아래와 값들이 들어갈 수 있다.
- primitive 타입의 값
- 문자열
- enum
- 클래스 참조
- 다른 애너테이션 클래스
- 위 요소들로 이루어진 배열들

---

코틀린에서 **애너테이션 인자를 지정하는 문법**은 자바와 약간 다르다.
- **클래스를 인자로 지정할 때는 `::class` 를 클래스 이름 뒤에 넣어야 함**
  - 예) @MyAnnotation(MyClass::class)
- **다른 애너테이션을 인자로 지정할 때는 인자로 들어가는 애너테이션의 이름 앞에 `@` 를 넣지 않음**
  - 바로 위 코드에서 사용한 `ReplaceWith` 는 애너테이션이지만 `Deprecated` 애너테이션의 인자로 들어가므로 `ReplaceWith` 앞에 `@` 를 사용하지 않음
  - 예) @Deprecated("Use removeNew(index) instead", ReplaceWith("removeNew(index)"))
- **배열을 인자로 지정하려면 `arrayOf()` 사용**
  - 예) @RequestMapping(path=arrayOf("/foo", "/bar")) 처럼 `arrayOf()` 사용

---

애너테이션 인자는 컴파일 시점에 알 수 있어야 하므로 임의의 프로퍼티를 인자로 지정할 수는 없다.  
프로퍼티를 애너테이션 인자로 사용하려면 그 앞에[`const`](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#42-%EC%B5%9C%EC%83%81%EC%9C%84-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-const) 변경자를 붙여서 컴파일러가 해당 프로퍼티를 컴파일 시점에 상수로 취급할 수 있도록 해야 한다.

jUnit 의 `@Test` 애너테이션에 `timeout` 파라메터를 사용하여 ms 단위로 타임아웃 시간을 정하는 예시

```kotlin
const val TEST_TIMEOUT = 100L

@Test(timeout = TEST_TIMEOUT)
fun testMethod() {
    // ...
}
```

---

# 2. 애너테이션 대상: 사용 지점 대상

코틀린 소스코드에서 한 선언을 컴파일한 결과가 여러 자바 선언과 대응하는 경우는 자주 있는데 이 때 코틀린 선언과 대응하는 여러 자바 선언에 각각 애너테이션을 붙여야 할 때가 있다.

예를 들어 코틀린 프로퍼티는 기본적으로 자바 필드와 getter 메서드 선언과 대응하고, 프로퍼티가 변경 가능하면 setter 에 대응하는 자바 setter 메서드와 setter 파라메터가 추가된다.  
만일 주 생성자에서 프로퍼티를 선언하면 이런 접근자 메서드(getter/setter) 와 파라메터 외에 자바 생성자 파라메터와도 대응된다.

따라서 **애너테이션을 붙일 때 이런 요소 중에서 어떤 요소에 애너테이션을 붙일 지 표시**할 필요가 있다.

**사용 지점 대상(use-site target) 선언으로 애너테이션을 붙일 요소를 정할 수 있다.**

지점 대상은 `@` 와 애너테이션 이름 사이에 넣으며, 애너테이션 이름과는 `:` 으로 분리한다.

아래 get 은 @Rule 애너테이션을 프로퍼티 게터에 적용하라는 의미이다.

![사용 지점 대상 지정 문법](/assets/img/dev/2024/0714/annotation.png)

> `@Rule` 은 jUnit 5 부터는 사용되지 않으니 문법만 참고하자.

자바에 선언된 애너테이션을 사용하여 프로퍼티에 애너테이션을 붙이는 경우 기본적으로 프로퍼티의 필드에 그 애너테이션이 붙는다.

하지만 코틀린으로 애너테이션을 선언하면 프로퍼티에 직접 적용할 수 있는 애너테이션을 만들 수 있다.

<**사용 지점 대상을 지정할 때 지원하는 대상 목록**>  
- **`property`**
  - 프로퍼티 전체
  - 자바에서 선언된 애너테이션에는 이 사용 자점 대상을 사용할 수 없음
- **`field`**
  - 프로퍼티에 의해 생성되는 [backing field](https://assu10.github.io/dev/2024/03/30/kotlin-advanced-5/#3-backing-field-%EC%99%80-backing-property)
- **`get`**
  - 프로퍼티 getter
- **`set`**
  - 프로퍼티 setter
- **`receiver`**
  - 확장 함수나 프로퍼티의 수신 객체 파라메터
- **`param`**
  - 생성자 파라메터
- **`setparam`**
  - setter 파라메터
- **`delegate`**
  - [위임 프로퍼티](https://assu10.github.io/dev/2024/03/24/kotlin-advanced-4/)의 위임 인스턴스를 담아둔 필드
- **`file`**
  - 파일 안에 선언된 최상위 함수와 프로퍼티를 담아두는 클래스

file 대상을 사용하는 애너테이션은 package 선언 앞에서 파일의 최상위 수준에만 적용 가능하다.  
파일에 적용하는 흔한 애너테이션으로는 파일에 있는 최상위 선언을 담는 클래스의 이름을 바꿔주는 `@JvmName` 이 있다.

[4.1. 최상위 함수: `@JvmName`](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#41-%EC%B5%9C%EC%83%81%EC%9C%84-%ED%95%A8%EC%88%98-jvmname) 에서 
아래와 같은 예시를 한 번 다룬 적 있다.

```kotlin
@file:JvmName("StringFunctions")    // 클래스 이름을 지정하는 애너테이션

package com.assu.study.kotlin2me.chap03 // @file:JvmName 애너테이션 뒤에 패키지 문이 와야 함

fun test(): String = "TEST"
```

---

자바와 달리 코틀린에서는 애너테이션 인자로 클래스나 함수 선언이나 타입 외에 임의의 식을 허용한다.

가장 흔히 사용되는 예로는 컴파일러 경고를 무시하기 위한 `@Suppress` 애너테이션이 있다.

안전하지 못한 캐스팅 경고를 무시하는 로컬 변수 선언 예시

```kotlin
fun test(list: List<*>) {
    @Suppress("UNCHECKED_CAST")
    val strings = list as List<String>
}
```

> **자바 API 를 애너테이션으로 제어하기**
> 
> 코틀린은 코틀린으로 선언한 내용을 자바 바이트코드로 컴파일하는 방법과 코틀린 선언을 자바에 노출하는 방벙을 제어하기 위한 애너테이션을 많이 제공하고 있음  
> 코틀린 선언을 자바에 노출시키는 방법을 변경하는 애너테이션들
> - **`@JvmName`**
>   - 코틀린 선언이 만들어내는 자바 필드나 메서드명 변경
> - **`@JvmStatic`**
>   - 메서드, 객체 선언, 동반 객체에 적용 시 그 요소가 자바 정적 메서드로 노출됨
> - [**`@JvmOverloads`**](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#%EB%94%94%ED%8F%B4%ED%8A%B8-%EA%B0%92%EA%B3%BC-%EC%9E%90%EB%B0%94-jvmoverloads)
>   - 디폴트 파라메터 값이 있는 함수에 대해 컴파일러가 자동으로 오버로딩한 함수 생성
> - **`@JvmField`**
>   - 프로퍼티에 사용하면 getter 나 setter 가 없는 public 자바 필드로 프로퍼티를 노출시킴

---

# 3. 애너테이션을 활용한 JSON 직렬화 제어

직렬화는 객체를 저장 장치에 저장하거나 네트워크를 통해 전송하기 위해 텍스트나 이진 형식으로 변환하는 것이다.  
역직렬화는 반대로 텍스트나 이진 형식응로 저장된 데이터를 원래의 객체로 변환하는 것이다.

직렬화에 자주 쓰이는 형식으로 JSON 있는데 Jackson 과 GSON 라이브러리를 많이 사용한다.

여기서는 JSON 직렬화를 위한 제이키드라는 순수 코틀린 라이브러리를 구현하는 과정에 대해 알아본다.

```kotlin
package com.assu.study.kotlin2me.chap10.jkid.examples

import org.junit.jupiter.api.Test
import ru.yole.jkid.deserialization.deserialize
import ru.yole.jkid.serialization.serialize
import kotlin.test.assertEquals

data class Person(
    val name: String,
    val age: Int,
)

class PersonTest {
    @Test
    fun test() {
        val person = Person("Alice", 29)
        val json = """{"age": 29, "name": "Alice"}"""

        // {"age": 29, "name": "Alice"}
        println(serialize(person))

        // JSON 에는 객체의 타입이 저장되지 않으므로 JSON 으로부터 인스턴스를 만들려면 타입 인자로
        // 클래스를 명시해야 함 (아래에서는 Person 클래스를 타입 인자로 넘김)
        // Person(name=Alice, age=29)
        println(deserialize<Person>(json))

        assertEquals(json, serialize(person))
        assertEquals(person, deserialize(json))
    }
}
```

_Person("Alice", 29)_ 을 직렬화하면 String 타입의 _{"age": 29, "name": "Alice"}_ 를 얻을 수 있고,  
_{"age": 29, "name": "Alice"}_ 를 역직렬화하면 Person 타입의 _Person("Alice", 29)_ 를 얻을 수 있다.

---

애너테이션을 활용하여 객체를 직렬화하거나 역직렬화하는 방법을 제어할 수 있다.

객체를 JSON 으로 직렬화할 때 제이키드 라이브러리는 기본적으로 모든 프로퍼티를 직렬화하며, 프로퍼티 이름을 key 로 사용하는데, 애너테이션을 사용하면 
이런 동작을 변경할 수 있다.

- @JsonExclude
  - 직렬화나 역직렬화 시 그 프로퍼티 무시
- @JsonName
  - 프로퍼티를 표현하는 key/value 쌍의 key 로 프로퍼티 이름 대신 애너테이션이 지정한 이름 사용

```kotlin
package com.assu.study.kotlin2me.chap10.jkid.examples

import org.junit.jupiter.api.Test
import ru.yole.jkid.JsonExclude
import ru.yole.jkid.JsonName
import ru.yole.jkid.deserialization.deserialize
import ru.yole.jkid.serialization.serialize
import kotlin.test.assertEquals

data class Person2(
  @JsonName("alias")
  val firstName: String,
  @JsonExclude
  val age: Int? = null,
)
class PersonTest {

    @Test
    fun test2() {
        val person2 = Person2("Lee", 20)
        val json = """{"alias": "Lee"}"""
        val json2 = """{"alias": "Lee", "age": 20}"""

        // {"alias": "Lee"}
        println(serialize(person2))

        // Person2(firstName=Lee, age=null)
        println(deserialize<Person2>(json))

        assertEquals(json, serialize(person2))
        assertEquals(person2, deserialize(json2))
    }
}
```

---

# 4. 애너테이션 선언: `annotation`

위에서 사용한 @JsonExclude 는 아무 파라메터도 없는 가장 단순한 애너테이션이다.

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class JsonExclude
```

일반 클래스와 차이점은 `class` 키워드 앞에 `annotation` 변경자가 붙은 것 외엔 없어보이지만 **애너테이션 클래스는 오직 선언이나 식과 관련있는 메타데이터의 구조를 
정의하기 때문에 내부에 아무 코드도 들어있을 수 없다.**  
따라서 컴파일러는 애너테이션 클래스에서 본문을 정의하지 못하게 막는다.

**파라메터가 있는 애너테이션을 정의하려면 애너테이션 클래스의 주생성자에 파라메터를 선언**해야 한다.

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class JsonName(val name: String)
```

일반 클래스의 [주생성자 선언 구문](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#14-%EC%A3%BC%EC%83%9D%EC%84%B1%EC%9E%90%EC%99%80-%EC%B4%88%EA%B8%B0%ED%99%94-%EB%B8%94%EB%A1%9D)과 똑같지만 **애너테이션 클래스에서는 모든 파라메터 앞에 `val` 를 붙여야 한다.**

---

# 5. 메타 애너테이션: 애너테이션을 처리하는 방법 제어 `@Target`

애너테이션 사용을 제어하는 방법과 애너테이션을 다른 애너테이션에 적용하는 방법에 대해 알아본다.

자바와 마찬가지로 코틀린 애너테이션 클래스에도 애너테이션을 붙일 수 있는데 이렇게 **애너테이션 클래스에 적용할 수 있는 애너테이션을 메타 애너테이션**이라고 한다.

표준 라이브러리에 있는 메타 애너테이션 중 가장 흔하게 사용되는 메타 애너테이션은 `@Target` 이다.

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class JsonExclude
```

`@Target` 은 적용 가능 대상을 지정하는 메타 애너테이션으로, 애너테이션을 적용할 수 있는 요소의 유형을 지정한다.

**애너테이션 클래스에 대해 구체적인 `@Target` 을 지정하지 않으면 모든 선언에 적용**할 수 있는 애너테이션이 된다.

애너테이션이 붙을 수 있는 대상이 정의된 enum 은 `AnnotationTarget` 에 있다.

```kotlin
package kotlin.annotation

import kotlin.annotation.AnnotationTarget.*

public enum class AnnotationTarget {
    /** Class, interface or object, annotation class is also included */
    CLASS,
    /** Annotation class only */
    ANNOTATION_CLASS,
    /** Generic type parameter */
    TYPE_PARAMETER,
    /** Property */
    PROPERTY,
    /** Field, including property's backing field */
    FIELD,
    /** Local variable */
    LOCAL_VARIABLE,
    /** Value parameter of a function or a constructor */
    VALUE_PARAMETER,
    /** Constructor only (primary or secondary) */
    CONSTRUCTOR,
    /** Function (constructors are not included) */
    FUNCTION,
    /** Property getter only */
    PROPERTY_GETTER,
    /** Property setter only */
    PROPERTY_SETTER,
    /** Type usage */
    TYPE,
    /** Any expression */
    EXPRESSION,
    /** File */
    FILE,
    /** Type alias */
    @SinceKotlin("1.1")
    TYPEALIAS
}

/**
 * Contains the list of possible annotation's retentions.
 *
 * Determines how an annotation is stored in binary output.
 */
public enum class AnnotationRetention {
    /** Annotation isn't stored in binary output */
    SOURCE,
    /** Annotation is stored in binary output, but invisible for reflection */
    BINARY,
    /** Annotation is stored in binary output and visible for reflection (default retention) */
    RUNTIME
}

// ...

```

필요하다면 아래처럼 둘 이상의 대상을 한꺼번에 선언할 수도 있다.

```kotlin
@Target(AnnotationTarget.CLASS,AnnotationTarget.PROPERTY)
```

**메타 애너테이션을 직접 만들어야 한다면 `AnnotationTarget.ANNOTATION_CLASS` 를 대상으로 지정**하면 된다.

```kotlin
@Target(AnnotationTarget.ANNOTATION_CLASS)
annotation class BindingAnnotation

@BindingAnnotation
annotation class MyBinding
```

대상을 `AnnotationTarget.PROPERTY` 로 지정한 애너테이션을 자바 코드에서 사용할 수는 없다.  
자바에서 그런 애너테이션을 사용해야 한다면 `AnnotationTarget.FIELD` 를 두 번째 대상으로 추가해야 한다.  
그러면 애너테이션을 코틀린 프로퍼티와 자바 필드에 적용할 수 있다.

---

## 5.1. `@Retention`

`@Retention` 은 정의 중인 애너테이션 클래스를 소스 수준에서만 유지할지(`SOURCE`), `.class` 파일에 저장할 지(`BINARY`), 실행 시점에 리플렉션을 사용하여 접근할 지(`RUNTIME`)를 지정하는 
메타 애너테이션이다.

자바 컴파일러는 기본적으로 애너테이션을 `.class` 파일에는 저장(`BINARY`)하지만 런타임에는 사용할 수 없게 한다.

하지만 대부분의 애너테이션은 런타임에도 사용할 수 있어야 하므로 코틀린에서는 기본적으로 애너테이션의 `@Retention` 을 `RUNTIME` 으로 지정한다.

---

# 6. 애너테이션 파라메터로 클래스 사용: `KClass`

[5. 메타 애너테이션: 애너테이션을 처리하는 방법 제어 `@Target`](#5-메타-애너테이션-애너테이션을-처리하는-방법-제어-target) 에서 정적인 데이터를 인자로 유지하는 에너테이션을 정의하는 방법에 대해 알아보았다.

하지만 **어떤 클래스를 선언 메타데이터로 참조할 수 있는 기능이 필요할 때**가 있는데, 이럴 때 **클래스 참조를 파라메터로 하는 애너테이션 클래스를 선언**하면 된다.

제이키드의 @DeserializeInterface 는 인터페이스 타입인 프로퍼티에 대해 역직렬화를 제어할 때 사용하는 애너테이션이다.  
인터페이스의 인스턴스를 직접 만들 수는 없으므로 역직렬화 시 어떤 클래스를 사용하여 인터페이스를 구현할 지 지정할 수 있어야 한다.

@DeserializeInterface 사용 예시

```kotlin
package com.assu.study.kotlin2me.chap10.jkid.examples

import ru.yole.jkid.DeserializeInterface
import ru.yole.jkid.deserialization.deserialize
import ru.yole.jkid.serialization.serialize
import kotlin.test.Test
import kotlin.test.assertEquals

interface Company {
    val name: String
}

data class CompanyImpl(
    override val name: String,
) : Company

data class Person3(
    val name: String,
    @DeserializeInterface(CompanyImpl::class)
    val company: Company,
)

inline fun <reified T : Any> testJsonSerializer(
    value: T,
    json: String,
) {
    assertEquals(json, serialize(value))
    assertEquals(value, deserialize(json))
}

class DeserializeInterfaceTest {
    @Test
    fun test() {
        testJsonSerializer(
            value = Person3("Assu", CompanyImpl("Silby")),
            json = """{"company": {"name": "Silby"}, "name": "Assu"}""",
        )
    }
}
```

직렬화된 _Person3_ 인스턴스를 역직렬화하는 과정에서 _company_ 프로퍼티를 표현하는 JSON 을 읽으면 그 프로퍼티 값에 해당하는 JSON 을 역직렬화하면서 _CompanyImpl_ 의 
인스턴스를 만들어서 _Person3_ 인스턴스의 _company_ 프로퍼티에 설정한다.

이렇게 역직렬화를 사용할 클래스를 지정하기 위해 @DeserializeInterface 애너테이션의 인자로 _CompanyImpl::class_ 를 넘긴다.

**일반적으로 클래스를 가리키려면 클래스 이름 뒤에 `::class` 키워드**를 붙인다.

클래스 참조를 인자로 받는 애너테이션 정의

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class DeserializeInterface(val targetClass: KClass<out Any>)
```

**`KClass` 는 자바 java.lang.Class 타입과 같은 역할을 하는 코틀린 타입**이다.  
코틀린 클래스에 대한 참조를 저장할 때 `KClass` 타입을 사용한다.

> `KClass` 에 대한 좀 더 상세한 내용은 [2.1. `KClass`](https://assu10.github.io/dev/2024/07/21/kotlin-annotation-reflection-2/#21-kclass) 를 참고하세요.

> 이렇게 저장한 클래스 참조로 어떤 기능을 수행할 수 있는지는 추후 다룰 예정입니다. (p. 444)

**`KClass` 의 타입 파라메터는 이 `KClass` 의 인스턴스가 가리키는 코틀린 타입을 지정**한다.  
예) _CompanyImpl::class_ 의 타입은 _KClass\<CompanyImpl\>_ 이며, 이 타입은 DeserializeInterface 의 파라메터 타입인 _KClass\<out Any\>_ 의 하위 타입임

![KClass 하위 타입 관계](/assets/img/dev/2024/0714/kclass.png)

애너테이션에 인자로 전달한 _CompanyImpl::class_ 의 타입인 _KClass\<CompanyImpl\>_ 은 애너테이션의 파라메터 타입인 _KClass\<out Any\>_ 의 하위 타입이다.

`KClass` 의 타입 파라메터를 쓸 때 `out` 변경자없이 _KClass\<Any\>_ 라고 쓰면 DeserializeInterface 에게 _CompanyImpl::class_ 를 인자로 넘길 수 없고, 
오직 _Any::class_ 만 넘길 수 있다.

반면 `out`  키워드가 있으면 모든 코틀린 타입 `T` 에 대해 _KClass\<T\>_ 가 _KClass\<out Any\>_ 의 하위 타입이 되므로(= 공변성) DeserializeInterface 의 
인자로 Any 뿐 아니라 Any 를 확장하는 모든 클래스에 대한 참조를 전달할 수 있다.

---

# 7. 애너테이션 파라메터로 제네릭 클래스 받기

기본적으로 제이키드는 'primitive 타입이 아닌 프로퍼티'를 중첩된 객체로 직렬화하는데 이런 **기본 동작을 변경하고 싶으면 값을 직렬화하는 로직을 직접 제공**하면 된다.

```kotlin
package ru.yole.jkid

import kotlin.reflect.KClass

// ...

interface ValueSerializer<T> {
  fun toJsonValue(value: T): Any?
  fun fromJsonValue(jsonValue: Any?): T
}

@Target(AnnotationTarget.PROPERTY)
annotation class CustomSerializer(val serializerClass: KClass<out ValueSerializer<*>>)
```

위의 @CustomSerializer 애너테이션은 커스텀 직렬화 클래스에 대한 참조를 인자로 받는다.  
이 직렬화 클래스는 ValueSerializer 인터페이스를 구현해야 한다.

ValueSerializer 클래스는 제네릭 클래스라서 타입 파라메터가 있다.  
따라서 ValueSerializer 타입을 참조하려면 항상 타입 인자를 제공해야 한다.  
하지만 이 애너테이션이 어떤 타입에 대해 사용될 지 모르므로 여기서는 [스타 프로젝션 `*`](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#26-%EC%8A%A4%ED%83%80-%ED%94%84%EB%A1%9C%EC%A0%9D%EC%85%98)을 사용할 수 있다.

위 코드에서 아래 부분을 보자.
```kotlin
KClass<out ValueSerializer<*>>
```

- `<out ValueSerializer<*>>`
  - DateSerializer::class 는 올바른 인자로 받아들이지만 Date::class 는 거부함
  - CustomSerializer 가 ValueSerializer 를 구현하는 클래스만 인자로 받아들여야 함을 명시
  - 예를 들어 Date 는 ValueSerializer 를 구현하지 않으므로 _@CustomSerializer(Date::class)_ 는 거부함
- `out`
  - ValueSerializer::class 뿐 아니라 ValueSerializer 를 구현하는 모든 클래스를 받아들임
- `<*>`
  - ValueSerializer 를 사용하여 어떤 타입의 값이든 직렬화할 수 있도록 허용함

아래는 날짜를 직렬화하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap10.jkid.examples

import ru.yole.jkid.CustomSerializer
import ru.yole.jkid.ValueSerializer
import ru.yole.jkid.deserialization.deserialize
import ru.yole.jkid.serialization.serialize
import java.text.SimpleDateFormat
import java.util.Date
import kotlin.test.Test
import kotlin.test.assertEquals

object DateSerializer : ValueSerializer<Date> {
    private val dateFormat = SimpleDateFormat("dd-mm-yyyy")

    override fun toJsonValue(value: Date): Any? = dateFormat.format(value)

    override fun fromJsonValue(jsonValue: Any?): Date = dateFormat.parse(jsonValue as String)
}

data class Person5(
    val name: String,
    @CustomSerializer(DateSerializer::class)
    val birthDate: Date,
)

inline fun <reified T : Any> testJsonSerializer2(
    value: T,
    json: String,
) {
    assertEquals(json, serialize(value))
    assertEquals(value, deserialize(json))
}

class DateSerializerTest {
    @Test
    fun test() {
        testJsonSerializer2(
            value = Person5("Assu", SimpleDateFormat("dd-mm-yyyy").parse("01-10-1984")),
            json = """{"birthDate": "01-10-1984", "name": "Assu"}""",
        )
    }
}
```

클래스를 애너테이션 인자로 받아야 할 때마다 위와 같은 패턴을 사용할 수 있다.

**클래스를 인자로 받아야 하면 애너테이션 파라메터 타입에 `KClass<out 허용할 클래스 이름>`** 을 쓴다.

**제네릭 클래스를 인자로 받아야 하면 `KClass<out 허용할 클래스 이름<*>>` 처럼 허용할 클래스의 이름 뒤에 스타 프로젝션**을 덧붙인다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 드리트리 제메로프, 스베트라나 이사코바 저자의 **Kotlin In Action** 을 기반으로 스터디하며 정리한 내용들입니다.*

* [Kotlin In Action](https://www.yes24.com/Product/Goods/55148593)
* [Kotlin In Action 예제 코드](https://github.com/AcornPublishing/kotlin-in-action)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)
* [jkid 예제 코드](https://github.com/yole/jkid)