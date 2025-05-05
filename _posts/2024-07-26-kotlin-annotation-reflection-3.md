---
layout: post
title: "Kotlin - 애너테이션과 리플렉션(3): 애너테이션으로 직렬화 제어, 리플렉션으로 역직렬화 구현"
date: 2024-07-26
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
* [1. 애너테이션을 이용한 직렬화 제어](#1-애너테이션을-이용한-직렬화-제어)
  * [1.1. @JsonExclude](#11-jsonexclude)
  * [1.2. @JsonName](#12-jsonname)
  * [1.3. @CustomSerializer](#13-customserializer)
* [2. JSON 파싱과 객체 역직렬화](#2-json-파싱과-객체-역직렬화)
  * [2.1. Tokenizer, Lexer, Parser](#21-tokenizer-lexer-parser)
  * [2.2. 제이키드의 역직렬화 과정](#22-제이키드의-역직렬화-과정)
  * [2.3. 객체의 상태 저장: _ObjectSeed_ 인터페이스](#23-객체의-상태-저장-_objectseed_-인터페이스)
* [3. 최종 역직렬화 단계: 리플렉션을 사용하여 객체 생성](#3-최종-역직렬화-단계-리플렉션을-사용하여-객체-생성)
  * [3.1. `KCallable.callBy()`](#31-kcallablecallby)
  * [3.2. 값 타입에 따른 직렬화기](#32-값-타입에-따른-직렬화기)
  * [3.3. 프로퍼티 검색 결과 캐시: _ClassInfoCache_](#33-프로퍼티-검색-결과-캐시-_classinfocache_)
  * [3.4. 대상 클래스의 인스턴스 생성, 필요 정보 캐시: _ClassInfo_](#34-대상-클래스의-인스턴스-생성-필요-정보-캐시-_classinfo_)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 애너테이션을 이용한 직렬화 제어

직렬화를 제어하는 애너테이션을 어떻게 구현하는지 알아본다.

[3. 애너테이션을 활용한 JSON 직렬화 제어](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#3-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98%EC%9D%84-%ED%99%9C%EC%9A%A9%ED%95%9C-json-%EC%A7%81%EB%A0%AC%ED%99%94-%EC%A0%9C%EC%96%B4) 와 [7. 애너테이션 파라미터로 제네릭 클래스 받기](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#7-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A1%9C-%EC%A0%9C%EB%84%A4%EB%A6%AD-%ED%81%B4%EB%9E%98%EC%8A%A4-%EB%B0%9B%EA%B8%B0) 에서
JSON 직렬화 과정을 제어하는 애너테이션에 대해 알아보았다.

특히 @JsonExclude, @JsonName, @CustomSerializer 애너테이션에 대해 알아봤는데 여기서는 이런 애너테이션을 _StringBuilder.serializeObject()_ 가 
어떻게 처리하는지 알아본다.

---

## 1.1. @JsonExclude

제이키드에서는 어떤 프로퍼티를 직렬화에서 제외하고 싶을 때 @JsonExclude 애너테이션을 사용한다.

@JsonExclude 시그니처

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class JsonExclude
```

@JsonExclude 사용 예시

```kotlin
data class Person(
        @JsonName(name = "first_name") val firstName: String,
        @JsonExclude val age: Int? = null
)
```

_StringBuilder.serializeObject()_ 에서 이 애너테이션을 지원하는 방법에 대해 알아본다.

_StringBuilder.serializeObject()_ 구현

```kotlin
private fun StringBuilder.serializeObject(obj: Any) {
    obj.javaClass.kotlin.memberProperties
            .filter { it.findAnnotation<JsonExclude>() == null }
            .joinToStringBuilder(this, prefix = "{", postfix = "}") {
                serializeProperty(it, obj)
            }
}
```

`KClass` 인스턴스의 [`memberProperties` 프로퍼티](https://assu10.github.io/dev/2024/07/21/kotlin-annotation-reflection-2/)를 사용하면 클래스의 모든 멤버 프로퍼티를 가져올 수 있다.  
이제 @JsonExclude 애너테이션이 붙은 프로퍼티는 직렬화 대상에서 제외하는 부분에 대해 알아보자.

`KAnnotatedElement` 인터페이스에는 `annotations` 프로퍼티가 있다.

**`annotations` 는 소스 코드 상에서 해당 요소에 적용된 `@Retention` 을 `RUNTIME` 으로 지정한 모든 애너테이션 인스턴스의 컬렉션**이다.

`KAnnotatedElement` 시그니처

```kotlin
package kotlin.reflect

public interface KAnnotatedElement {
    public val annotations: List<Annotation>
}
```

`KProperty` 는 `KAnnotatedElement` 를 확장하므로 _property.annotations_ 를 통해 프로퍼티의 모든 애너테이션을 얻을 수 있다.

지금은 모든 애너테이션이 아닌 하나의 애터테이션만 찾으면 되므로 아래와 같은 _findAnnotation()_ 확장 함수를 정의해서 사용하면 유용하다.

```kotlin
// 인자로 전달받은 타입에 해당하는 애너테이션이 있으면 그 애너테이션 반환
inline fun <reified T> KAnnotatedElement.findAnnotation(): T?
        = annotations.filterIsInstance<T>().firstOrNull()
```

위 함수는 [1.4. 클래스 참조 대신 실체화한 타입 파라미터 사용: `ServiceLoader`, `::class.java`](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#14-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%B0%B8%EC%A1%B0-%EB%8C%80%EC%8B%A0-%EC%8B%A4%EC%B2%B4%ED%99%94%ED%95%9C-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0-%EC%82%AC%EC%9A%A9-serviceloader-classjava) 에서 
설명한 패턴을 사용하여 타입 파라미터를 `reified` 로 만들어서 애너테이션 클래스를 타입 인자로 전달한다.

> `reified` 에 대한 내용은 [1. 함수의 타입 인자에 대한 실체화: `reified`, `KClass`](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#1-%ED%95%A8%EC%88%98%EC%9D%98-%ED%83%80%EC%9E%85-%EC%9D%B8%EC%9E%90%EC%97%90-%EB%8C%80%ED%95%9C-%EC%8B%A4%EC%B2%B4%ED%99%94-reified-kclass) 를 참고하세요.

---

## 1.2. @JsonName

@JsonName 시그니처

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class JsonName(val name: String)
```

@JsonName 사용 예시

```kotlin
data class Person(
        @JsonName(name = "first_name") val firstName: String,
        @JsonExclude val age: Int? = null
)
```

사용 예시를 보면 @JsonName 애너테이션의 존재 여부 뿐 아니라 애너테이션에 전달할 인자도 알아야 한다.

아래 _StringBuilder.serializeObject()_ 와 _findAnnotation()_ 의 정의를 다시 보자.

```kotlin
private fun StringBuilder.serializeObject(obj: Any) {
    obj.javaClass.kotlin.memberProperties
            .filter { it.findAnnotation<JsonExclude>() == null }
            .joinToStringBuilder(this, prefix = "{", postfix = "}") {
                serializeProperty(it, obj)
            }
}

private fun StringBuilder.serializeProperty(
  prop: KProperty1<Any, *>, obj: Any
) {
  // @JsonName 애너테이션이 있으면 그 인스턴스를 얻음
  val jsonNameAnn = prop.findAnnotation<JsonName>()
  
  // 애너테이션에서 name 인자를 찾고, 그런 인자가 없으면 prop.name 을 사용
  val propName = jsonNameAnn?.name ?: prop.name
  serializeString(propName)
  append(": ")

  val value = prop.get(obj)
  val jsonValue = prop.getSerializer()?.toJsonValue(value) ?: value
  serializePropertyValue(jsonValue)
}
```

```kotlin
inline fun <reified T> KAnnotatedElement.findAnnotation(): T?
        = annotations.filterIsInstance<T>().firstOrNull()
```

위 코드에서 @JsonName 애너테이션이 없다면 _jsonNameAnn_ 은 null 이다.  
그런 경우 여전히 _prop.name_ 을 JSON 의 프로퍼티 이름으로 사용할 수 있다.  
만일 프로퍼티에 @JsonName 애너테이션이 있으면 애너테이션이 지정하는 이름을 대신 사용한다.

_Person_ 클래스 인스턴스를 직렬화하는 과정을 살펴보자.

_firstName_ 프로퍼티를 직렬화하는 동안 _jsonNameAnn_ 에는 JsonName 애너테이션 클래스에 해당하는 인스턴스가 들어있으므로 _jsonNameAnn?.name_ 은 
null 이 아닌 _first_name_ 이며, 직렬화 시 이 이름을 key 로 사용한다.

_age_ 프로퍼티를 직렬화할 때는 @JsonName 애너테이션이 없으므로 프로퍼티 이름인 _age_ 를 key 로 사용한다.

---

## 1.3. @CustomSerializer

@CustomSerializer 시그니처

```kotlin
@Target(AnnotationTarget.PROPERTY)
annotation class CustomSerializer(val serializerClass: KClass<out ValueSerializer<*>>)
```

@JsonName 사용 예시

```kotlin
object DateSerializer : ValueSerializer<Date> {
  private val dateFormat = SimpleDateFormat("dd-mm-yyyy")

  override fun toJsonValue(value: Date): Any? =
    dateFormat.format(value)

  override fun fromJsonValue(jsonValue: Any?): Date =
    dateFormat.parse(jsonValue as String)
}

data class Person(
  val name: String,
  @CustomSerializer(DateSerializer::class) val birthDate: Date
)
```

@CustomSerializer 는 _KProperty\<*\>.getSerializer()_ 함수에 기초한다.  
_KProperty\<*\>.getSerializer()_ 는 @CustomSerializer 를 통해 등록한 _ValueSerializer_ 인스턴스를 반환한다.

```kotlin
// 프로퍼티의 값을 직렬화하는 직렬화기 가져오기
fun KProperty<*>.getSerializer(): ValueSerializer<Any?>? {
    // @CustomSerializer 애너테이션이 있는지 찾음
    val customSerializerAnn: CustomSerializer = findAnnotation<CustomSerializer>() ?: return null
  
    // @CustomSerializer 애너테이션이 있다면 그 애너테이션의 serializerClass 가 직렬화기 인스턴스를 얻기 위해 사용해야 할 클래스임
    val serializerClass: KClass<out ValueSerializer<*>> = customSerializerAnn.serializerClass

    // 직렬화할 클래스가 object 로 선언하여 싱글턴인 경우 objectInstance 를 통해 싱글턴 인스턴스를 얻어서 모든 객체를 직렬화하면 되므로 
    // createInstance() 를 호출할 필요가 없음
    val valueSerializer: ValueSerializer<*> = serializerClass.objectInstance
            ?: serializerClass.createInstance()
    
  return valueSerializer as ValueSerializer<Any?>
}

interface ValueSerializer<T> {
  fun toJsonValue(value: T): Any?
  fun fromJsonValue(jsonValue: Any?): T
}
```

_KProperty\<*\>.getSerializer()_ 가 주로 다루는 객체가 `KProperty` 인스턴스이므로 `KProperty` 의 확장 함수로 정의한다.

위 코드에서 @CustomSerializer 의 값으로 클래스와 객체(코틀린의 싱글턴 객체)를 처리하는 방식을 보자.

클래스와 객체 모두 `KClass` 클래스로 표현된다.

다만 객체에는 `object` 선언에 의해 생성된 싱글턴이 가리키는 `objectInstance` 라는 프로퍼티가 있다는 점이 클래스와 다른 점이다.

예를 들어 _DateSerializer_ 를 `object` 로 선언한 경우 `objectInstance` 프로퍼티에 _DateSerializer_ 의 싱글턴 인스턴스가 들어있다.  
따라서 그 싱글턴 인스턴스를 사용하여 모든 객체를 직렬화하면 되므로 `createInstance()` 를 호출할 필요가 없다.

만일 `KClass` 가 객체인 `object` 가 아닌 일반 클래스를 표현한다면 `createInstance()` 를 호출하여 새 인스턴스를 만들어야 한다.

아래는 _StringBuilder.serializeProperty()_ 에서 _KProperty\<*\>.getSerializer()_ 를 사용하는 코드이다.

```kotlin
// getSerializer() 를 통해 커스텀 직렬화기를 얻은 후 커스텀 직렬화기의 _toJsonValue()_ 를 호출하여 프로퍼티값을 JSON 형식으로 직렬화함
// 만일 프로퍼티에 커스텀 직렬화기가 지정되어 있지 않다면 프로퍼티값을 그대로 사용함
private fun StringBuilder.serializeProperty(
        prop: KProperty1<Any, *>, obj: Any
) {
    val jsonNameAnn = prop.findAnnotation<JsonName>()
    val propName = jsonNameAnn?.name ?: prop.name
    serializeString(propName)
    append(": ")

    val value = prop.get(obj)
  
    // 프로퍼티에 대해 정의된 커스텀 직렬화기가 있으면 그 커스텀 직렬화기를 사용하고,  
    // 커스텀 직렬화기가 없으면 일반적인 방법으로 프로퍼티 직렬화함
    val jsonValue = prop.getSerializer()?.toJsonValue(value) ?: value
    serializePropertyValue(jsonValue)
}
```

---

# 2. JSON 파싱과 객체 역직렬화

이제 제이키드에서 역직렬화하는 부분의 전체적인 구조를 살펴보고, 객체를 역직렬화할 때 리플렉션을 어떻게 사용하는지 알아본다.

제이키드에서 역직렬화하는 API 정의는 아래와 같이 되어있다.

```kotlin
inline fun <reified T: Any> deserialize(json: Reader): T {
    return deserialize(json, T::class)
}
```

_deserialize()_ 사용 예시

```kotlin
package com.assu.study.kotlin2me.chap10.jkid.examples.deserialization

import ru.yole.jkid.deserialization.deserialize

data class Author(
  val name: String,
)

data class Book(
  val title: String,
  val author: Author,
)

fun main() {
  val json = """{"title": "TEST1", "author": {"name": "Assu"}}"""

  // 역직렬화할 객체의 타입을 실체화한 타입 파라미터로 deserialize() 에 넘겨서 새로운 객체 인스턴스를 얻음
  val book: Book = deserialize<Book>(json)

  // Book(title=TEST1, author=Author(name=Assu))
  println(book)
}
```

역직렬화는 JSON 문자열 입력을 파싱하고, 리플렉션을 사용하여 객체의 내부에 접근하여 새로운 객체와 프로퍼티를 생성한다.

---

## 2.1. Tokenizer, Lexer, Parser

- **Tokenizer**
  - 어떤 대상의 의미있는 요소들을 토큰으로 쪼개는 역할
  - 여기서 토큰은 '어휘 분석의 단위'로, 단어, 문자열 등 의미있는 단위임

- **Lexer**
  - Tokenizer 에 의해 쪼갠 토큰의 의미를 분석하는 역할

- **Lexical Analyze**
  - Tokenizer + Lexer = Lexical Analyze
  - Lexical Analyze 는 의미있는 조각을 검출하여 토큰을 생성하는 것을 의미함

- **Parser**
  - Lexical Analyze 되어 tokenize 된 데이터를 구조적으로 나타냄
  - 데이터를 구조적으로 바꾸는 과정에서 데이터가 올바른지 검증하는 역할도 수행함

Tokenizer → Lexer → Parser 간단한 예시

```text
## 입력값
[1, [2,[3]], "he is tall"]

## Tokenizer 결과 
[ "1", "[2,[3]]", "['he', 'is', 'tall']"]

## Lexer 결과 
[
	{type: 'number', value:"1" },
	{type: 'array', value: "[2, [3]]"},
	{type: 'array', value: "['he', 'is', 'tall']"},
]

## Parser 결과  
{
	type: 'array',
	child: [
		{type: 'number', value:'1', child:[] },
		{type: 'array', 
			child: [
			{ type: 'number', value: '2', child:[] },
			{ type: 'array', 
				child:[ {type:'number', value:'3', child:[]}
			]
		}]
		},
		{type: 'array', 
			child:[
			{ type: 'string', value: 'he', child:[] },
			{ type: 'string', value: 'is', child:[] },
			{ type: 'string', value: 'tall', child:[] },
			]
		}]
}
```

---

## 2.2. 제이키드의 역직렬화 과정

제이키드의 JSON 역직렬화기는 흔히 사용되는 방법에 따라 3단계로 구현되어 있다.

- **어휘 분석기 (Lexical Analyzer**)
  - 여러 문자로 이루어진 입력 문자열을 토큰 리스트로 변환 (Tokenizer)
  - 토큰에는 2가지 종류가 있음
    - **문자 토큰**
      - 문자를 표현
      - JSON 문법에서 중요한 의미가 있음 (콤마, 콜론, 중괄호, 각괄호가 문자 토큰임)
    - **값 토큰**
      - 문자열, 수, boolean 값, null 상수
- **Parser**
  - 토큰의 리스트를 구조화된 표현으로 변환
  - 어휘 분석기가 만든 토큰 리스트를 분석하면서 의미 단위를 만날 때마다 _JsonObject_ 의 메서드를 적절히 호출
  - 제이키드에서 Parser 는 JSON 의 상위 구조를 이해하고, 토큰을 JSON 에서 지원하는 의미 단위로 변환함
  - 의미 단위로는 key/value 쌍과 배열이 있음
- **Deserializer**
  - _JsonObject_ 에 상응하는 코틀린 타입의 인스턴스를 점차 만들어내는 _JsonObject_ 구현 제공
  - 이런 구현은 클래스 프로퍼티와 JSON key(_title_, _author_, _name_) 사이의 대응 관계를 찾아내고, 중첩된 객체값(_Author_ 의 인스턴스) 를 만들어냄
  - 이렇게 모든 중첩 객체 값을 만들고 난 뒤에는 필요한 클래스(_Book_) 의 인스턴스를 새로 만듦

_JsonObject_ 인터페이스의 시그니처를 보자.

```kotlin
package ru.yole.jkid.deserialization

// ...

// JSON Parser 콜백 인터페이스
interface JsonObject {
    fun setSimpleProperty(propertyName: String, value: Any?)

    fun createObject(propertyName: String): JsonObject

    fun createArray(propertyName: String): JsonObject
}
```

_JsonObject_ 인터페이스는 현재 역직렬화하는 중인 객체나 배열을 추적한다.  
Parser 는 현재 객체의 새로운 프로퍼티를 발견할 때마다 그 프로퍼티의 유형 (간단한 값, 복합 프로퍼티, 배열) 에 해당하는 _JsonObject_ 의 함수를 호출한다.

각 메서드의 _propertyName_ 은 JSON key 를 받는다.  
따라서 Parser 가 객체를 값으로 하는 _author_ 프로퍼티를 만나면 위에서 _createObject("author")_ 메서드가 호출된다.

간단한 프로퍼티 값은 _setSimpleProperty()_ 를 호출하면서 실제 값을 _value_ 에 넘기는 방식으로 등록한다.

_JsonObject_ 인터페이스를 구현하는 클래스는 새로운 객체를 생성하고 새로 생성한 객체를 외부 객체에 등록하는 역할을 해야 한다.

아래 그림은 문자열을 역직렬화하는 과정에서 어휘 분석기, Parser, Deserializer 단계의 입력과 출력이다.

![JSON 파싱: Lexer, Parser, Deserializer](/assets/img/dev/2024/0726/json_parsing.png)

---

제이키드는 데이터 클래스와 함께 사용하려는 의도로 만든 라이브러리이므로 JSON 에서 가져온 key/value 쌍을 역직렬화하는 클래스의 생성자에 넘긴다.

제이키드는 객체를 생성한 후 프로퍼티를 설정하는 것은 지원하지 않으므로 제이키드의 역직렬화기는 JSON 에서 데이터를 읽는 과정에서 중간에 만든 프로퍼티 객체들을 
어딘가에 저장해 두었다가 나중에 생성자를 호출할 때 사용해야 한다.

객체를 생성하기 전에 그 객체의 하위 요소를 저장해야 한다는 요구 사항은 전통적인 빌더 패턴과 비슷하다.  
물론 빌더 패턴은 타입이 미리 정해진 객체를 만들기 위한 도구라는 차이점이 있지만, 이 요구사항은 만족시키기 위한 해법은 객체 종류와 상관없이 일반적인 해법이어야 한다.

제이키드에서는 빌더 라는 대신 seed 라는 용어를 사용하였다.

JSON 에서는 객체, 컬렉션, 맵과 같은 복합 구조를 만들 필요가 있다.

_ObjectSeed_, _ObjectListSeed_, _ValueListSeed_ 는 각각 객체, 복합 객체로 이루어진 리스트, 간단한 값을 만드는 일을 한다.  
(맵을 만드는 seed 구현은 각자 알아서...)

```kotlin
class ObjectSeed<out T : Any>(
    targetClass: KClass<T>,
    override val classInfoCache: ClassInfoCache,
) : Seed {
    private val classInfo: ClassInfo<T> = classInfoCache[targetClass]

    private val valueArguments = mutableMapOf<KParameter, Any?>()
    private val seedArguments = mutableMapOf<KParameter, Seed>()

    private val arguments: Map<KParameter, Any?>
        get() = valueArguments + seedArguments.mapValues { it.value.spawn() }

    override fun setSimpleProperty(
        propertyName: String,
        value: Any?,
    ) {
        val param = classInfo.getConstructorParameter(propertyName)
        valueArguments[param] = classInfo.deserializeConstructorArgument(param, value)
    }

    override fun createCompositeProperty(
        propertyName: String,
        isList: Boolean,
    ): Seed {
        val param = classInfo.getConstructorParameter(propertyName)
        val deserializeAs = classInfo.getDeserializeClass(propertyName)
        val seed =
            createSeedForType(
                deserializeAs ?: param.type.javaType,
                isList,
            )
        return seed.apply { seedArguments[param] = this }
    }

    // 생성된 객체 반환
    override fun spawn(): T = classInfo.createInstance(arguments)
}

class ObjectListSeed(
    val elementType: Type,
    override val classInfoCache: ClassInfoCache,
) : Seed {
    private val elements = mutableListOf<Seed>()

    override fun setSimpleProperty(
        propertyName: String,
        value: Any?,
    ): Unit = throw JKidException("Found primitive value in collection of object types")

    override fun createCompositeProperty(
        propertyName: String,
        isList: Boolean,
    ) = createSeedForType(elementType, isList).apply { elements.add(this) }

    // 생성된 리스트 반환
    override fun spawn(): List<*> = elements.map { it.spawn() }
}

class ValueListSeed(
    elementType: Type,
    override val classInfoCache: ClassInfoCache,
) : Seed {
    private val elements = mutableListOf<Any?>()
    private val serializerForType = serializerForBasicType(elementType)

    override fun setSimpleProperty(
        propertyName: String,
        value: Any?,
    ) {
        elements.add(serializerForType.fromJsonValue(value))
    }

    override fun createCompositeProperty(
        propertyName: String,
        isList: Boolean,
    ): Seed = throw JKidException("Found object value in collection of primitive types")

    // 생성된 리스트 반환
    override fun spawn() = elements
}
```

기본 _Seed_ 인터페이스는 _JsonObject_ 인터페이스를 확장하면서 객체 생성 과정이 끝난 후 결과 인스턴스를 얻기 위한 _spawn()_ 메서드를 추가 제공한다.

또한 _Seed_ 안에는 중첩된 객체나 중첩된 리스트를 만들 때 사용할 _createCompositeProperty()_ 메서드가 있다.

```kotlin
interface JsonObject {
    fun setSimpleProperty(
        propertyName: String,
        value: Any?,
    )

    fun createObject(propertyName: String): JsonObject

    fun createArray(propertyName: String): JsonObject
}

interface Seed : JsonObject {
    val classInfoCache: ClassInfoCache

    // 객체 생성 과정이 끝난 후 결과 인스턴스를 얻음
    fun spawn(): Any?

    fun createCompositeProperty(
        propertyName: String,
        isList: Boolean,
    ): JsonObject

    override fun createObject(propertyName: String) = createCompositeProperty(propertyName, false)

    override fun createArray(propertyName: String) = createCompositeProperty(propertyName, true)
}
```

_spawn()_ 은 build 와 비슷하게 만들어낸 객체를 돌려주는 메서드이다.  
단, _spawn()_ 은 _ObjectSeed_ 인터페이스의 경우 생성된 객체를 반환하고, _ObjectListSeed_ 인터페이스나 _ValueListSeed_ 인터페이스의 경우 
생성된 리스트를 반환한다.

아래는 최상위 역직렬화 함수 코드이다.

```kotlin
fun <T : Any> deserialize(
    json: Reader,
    targetClass: KClass<T>,
): T {
    // 파싱을 시작하기 위해 직렬화할 객체의 프로퍼티를 담을 ObjectSeed 하나 생성
    val seed = ObjectSeed(targetClass, ClassInfoCache())
    
    // 파서를 호출하면서 입력 스트림 reader 인 json 과 seed 를 인자로 전달
    Parser(json, seed).parse()
    
    // 결과 객체 생성
    return seed.spawn()
}
```

---

## 2.3. 객체의 상태 저장: _ObjectSeed_ 인터페이스

```kotlin
// 지금 만들고 있는 객체의 상태 저장
class ObjectSeed<out T : Any>(
  targetClass: KClass<T>, // 결과 클래스의 참조
  // 결과 클래스 안의 프로퍼티에 대한 정보를 저장하는 캐시
  // 나중에 이 캐시 정보를 사용해서 클래스의 인스턴스 생성
  override val classInfoCache: ClassInfoCache,
) : Seed {
  // targetClass 의 인스턴스를 만들 때 필요한 정보 캐싱
  private val classInfo: ClassInfo<T> = classInfoCache[targetClass]

  // 생성자 파라미터와 값을 연결해주는 맵 생성
  // 이를 위해 아래의 변경 가능한 맵 사용

  // 간단한 값 프로퍼티 저장
  private val valueArguments = mutableMapOf<KParameter, Any?>()

  // 복합 프로퍼티 저장
  private val seedArguments = mutableMapOf<KParameter, Seed>()

  // 생성자 파라미터와 그 값을 연결하는 맵 생성
  private val arguments: Map<KParameter, Any?>
    get() = valueArguments + seedArguments.mapValues { it.value.spawn() }

  // 결과를 만들여서 valueArguments 맵에 새 인자 추가
  override fun setSimpleProperty(
    propertyName: String,
    value: Any?,
  ) {
    val param = classInfo.getConstructorParameter(propertyName)

    // 생성자 파라미터 값이 간단한 경우 그 값을 기록
    valueArguments[param] = classInfo.deserializeConstructorArgument(param, value)
  }

  // seedArguments 맵에 새 인자 추가
  override fun createCompositeProperty(
    propertyName: String,
    isList: Boolean,
  ): Seed {
    val param = classInfo.getConstructorParameter(propertyName)

    // 프로퍼티에 대한 DeserializeInterface 애너테이션이 있다면 그 값을 가져옴
    val deserializeAs = classInfo.getDeserializeClass(propertyName)

    // 파라미터 타입에 따라 ObjectSeed, CollectionSeed 생성 (1)
    val seed =
      createSeedForType(  // 파타메터의 타입을 분석하여 적절히 ObjectSeed, ObjectListSeed, ValueListSeed 중 하나 새엇ㅇ
        deserializeAs ?: param.type.javaType,
        isList,
      )

    // (1) 에서 만든 Seed 객체를 seedArguments 맵에 기록
    return seed.apply { seedArguments[param] = this }
  }

  // 인자 맵을 넘겨서 targetClass 타입의 인스턴스 생성
  // 내부에 중첩된 모든 Seed 의 spawn() 을 재귀적으로 호출하여 내부 객체 계층 구조 생성
  // 재귀적으로 복합 (Seed) 인자 만드는 과정: arguments 의 커스텀 getter 안에서 mapValues() 를 사용하여 seedArguments 각 원소에 대해 spawn() 호출
  override fun spawn(): T = classInfo.createInstance(arguments)
}
```

> _ClassInfoCache_ 와 _ClassInfo_ 는 도우미 클래스로  
> [3.3. 프로퍼티 검색 결과 캐시: _ClassInfoCache_](#33-프로퍼티-검색-결과-캐시-_classinfocache_),  
> [3.4. 대상 클래스의 인스턴스 생성, 필요 정보 캐시: _ClassInfo_](#34-대상-클래스의-인스턴스-생성-필요-정보-캐시-_classinfo_)  
> 를 참고하세요.

```kotlin
// 파타메터의 타입을 분석하여 적절히 ObjectSeed, ObjectListSeed, ValueListSeed 중 하나 생성
fun Seed.createSeedForType(
    paramType: Type,
    isList: Boolean,
): Seed {
    val paramClass = paramType.asJavaClass()

    if (List::class.java.isAssignableFrom(paramClass)) {
        if (!isList) throw JKidException("An array expected, not a composite object")
        val parameterizedType =
            paramType as? ParameterizedType
                ?: throw UnsupportedOperationException("Unsupported parameter type $this")

        val elementType = parameterizedType.actualTypeArguments.single()
        if (elementType.isPrimitiveOrString()) {
            return ValueListSeed(elementType, classInfoCache)
        }
        return ObjectListSeed(elementType, classInfoCache)
    }
    if (isList) throw JKidException("Object of the type ${paramType.typeName} expected, not an array")
    return ObjectSeed(paramClass.kotlin, classInfoCache)
}
```

---

# 3. 최종 역직렬화 단계: 리플렉션을 사용하여 객체 생성

여기서는 _ClassInfo.createInstance()_ 가 _targetClass_ 의 인스턴스를 어떻게 만드는지에 대해 알아본다.

최종 결과인 객체 인스턴스를 생성하고, 생성자 파라미터 정보를 캐시하는 _ClassInfo_ 클래스에 대해 알아볼 것이다.

그 전에 리플렉션을 통해 객체를 만들 때 사용하는 API 들을 몇 가지 살펴본다.

---

## 3.1. `KCallable.callBy()`

[2.2. `KCallable`, `KFunction`: `call()`, `invoke()`](https://assu10.github.io/dev/2024/07/21/kotlin-annotation-reflection-2/#22-kcallable-kfunction-call-invoke) 에서 
인자 리스트를 받아서 함수나 생성자를 호출해주는 `KCallable.call()` 에 대해 알아보았다.

**`KCallable.call()` 은 유용하지만 디폴트 파라미터 값을 지원하지 않는다.**

만일 역직렬화 시 생성해야 하는 객체에 디폴트 생성자 파라미터 값이 있고, 그 값을 활용할 수 있다면 JSON 에서 관련 프로퍼티를 꼭 지정하지 않아도 된다.

디폴트 파라미터 값이 있다면 `KCallable.call()` 대신 `KCallable.callby()` 를 사용하는 것이 편리하다.

```kotlin
package kotlin.reflect

public actual interface KCallable<out R> : KAnnotatedElement {

    // ...
    
    public fun call(vararg args: Any?): R
    public fun callBy(args: Map<KParameter, Any?>): R
}
```

`KCallable.callby()` 는 파라미터와 파라미터에 해당하는 값을 연결해주는 맵을 인자로 받는다.  
인자로 받은 맵에서 파라미터를 찾을 수 없을 때 파라미터 디폴트 값이 정의되어 있다면 그 디폴트 값을 사용한다.

**`KCallable.callby()` 를 사용하면 파라미터의 순서를 지킬 필요가 없으므로 객체 생성자에 원래 정의된 파라미터 순서에 신경쓰지 않고 JSON 에서 key/value 쌍을 읽어서 
key 와 일치하는 파라미터를 찾을 후 맵에 파라미터 정보와 값**을 넣을 수 있다.

이 때 타입 처리에 주의해야 한다.

인자로 받는 _args_ 맵에 들어있는 각 value 의 타입이 생성자의 파라미터 타입과 일치하지 않으면 _IllegalArgument Exception_ 이 발생한다.

특히 숫자의 경우 파라미터가 Int, Long, Double 등의 타입 중 어떤 것인지 확인하여 JSON 에 있는 숫자값을 적절한 타입으로 변환해야만 한다.  
**`KParameter.type` 프로퍼티를 활용하면 파라미터의 타입**을 알 수 있다.

---

## 3.2. 값 타입에 따른 직렬화기

타입 변환에는 [7. 애너테이션 파라미터로 제네릭 클래스 받기](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#7-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A1%9C-%EC%A0%9C%EB%84%A4%EB%A6%AD-%ED%81%B4%EB%9E%98%EC%8A%A4-%EB%B0%9B%EA%B8%B0) 에서 사용한 
_ValueSerializer_ 인스턴스를 똑같이 사용한다.  
프로퍼티에 @CustomSerializer 애너테이션이 없다면 프로퍼티 타입에 따라 표준 구현을 불러와 사용한다

값 타입에 따라 직렬화기 가져오는 코드

```kotlin
fun serializerForType(type: Type): ValueSerializer<out Any?>? =
        when (type) {
            Byte::class.java, Byte::class.javaObjectType -> ByteSerializer
            Short::class.java, Short::class.javaObjectType -> ShortSerializer
            Int::class.java, Int::class.javaObjectType -> IntSerializer
            Long::class.java, Long::class.javaObjectType -> LongSerializer
            Float::class.java, Float::class.javaObjectType -> FloatSerializer
            Double::class.java, Double::class.javaObjectType -> DoubleSerializer
            Boolean::class.java, Boolean::class.javaObjectType -> BooleanSerializer
            String::class.java -> StringSerializer
            else -> null
        }
```

타입별 _ValueSerializer_ 의 구현은 필요한 타입 검사와 변환을 수행한다.

Int, Boolean 값을 위한 직렬화기

```kotlin
object IntSerializer : ValueSerializer<Int> {
  override fun fromJsonValue(jsonValue: Any?) = jsonValue.expectNumber().toInt()
  override fun toJsonValue(value: Int) = value
}


object BooleanSerializer : ValueSerializer<Boolean> {
    override fun fromJsonValue(jsonValue: Any?): Boolean {
        if (jsonValue !is Boolean) throw JKidException("Expected boolean, was: $jsonValue")
        return jsonValue
    }

    override fun toJsonValue(value: Boolean) = value
}
```

_ClassInfo_ 클래스 안에 인스턴스를 생성해주는 메서드가 있다.

```kotlin
class ClassInfo<T : Any>(
  cls: KClass<T>,
) {
    // ...
    private val constructor =
      cls.primaryConstructor
        ?: throw JKidException("Class ${cls.qualifiedName} doesn't have a primary constructor")
  
    fun createInstance(arguments: Map<KParameter, Any?>): T {
        ensureAllParametersPresent(arguments)
        return constructor.callBy(arguments)
    }
}
```

`callBy()` 에서드에 생성자 파라미터와 그 값을 연결해주는 맵을 넘기면 객체의 주 생성자를 호출할 수 있다.

---

## 3.3. 프로퍼티 검색 결과 캐시: _ClassInfoCache_

위에서 만든 _ValueSerializer_ 를 호출하는 부분을 보자.

_ClassInfoCache_ 는 리플렉션 연산을 줄이기 위한 클래스이다.

직렬화와 역직렬화에 사용하는 애너테이션들(@JsonName, @CustomSerializer) 은 파라미터가 아니라 프로퍼티에 적용된다.  
하지만 객체를 역직렬화할 때는 프로퍼티가 아니라 생성자 파라미터를 다뤄야 하므로 애너테이션을 꺼내려면 파라미터에 해당하는 프로퍼티를 찾아야 한다.

JSON 에서 key/value 쌍을 읽을 때마다 이런 검색을 수행하면 코드가 아주 느려질 수 있으므로 클래스 별로 한 번만 검색을 수행하고 검색 결과를 캐시에 넣어둔다.

```kotlin
class ClassInfoCache {
  private val cacheData = mutableMapOf<KClass<*>, ClassInfo<*>>()

  @Suppress("UNCHECKED_CAST")
  operator fun <T : Any> get(cls: KClass<T>): ClassInfo<T> =
  // cls 에 대한 항목이 cacheData 맵에 있으면 그 항목을 반환
    // 그런 항목이 없다면 전달받은 람다를 호출하여 key 에 대한 값을 계산한 후 그 결과값을 맵에 저장한 다음 반환함
    cacheData.getOrPut(cls) { ClassInfo(cls) } as ClassInfo<T>
}
```

[2.6.1. 스타 프로젝션 주의점](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#261-%EC%8A%A4%ED%83%80-%ED%94%84%EB%A1%9C%EC%A0%9D%EC%85%98-%EC%A3%BC%EC%9D%98%EC%A0%90) 에서 사용한 패턴을 사용한다.

안전하지 못한 로직은 private 로 클래스 내부로 숨김으로써 외부에서 그 부분을 잘못 사용하지 않음을 보장한다.  
맵에 값을 저장할 때는 타입 정보가 사라지지만, 맵에서 돌라받은 값의 타입인 _ClassInfo\<T\>_ 의 타입 인자가 항상 올바른 값이 되도록 get() 메서드 구현이 보장한다.

---

## 3.4. 대상 클래스의 인스턴스 생성, 필요 정보 캐시: _ClassInfo_

_ClassInfo_클래스는 대상 클래스의 새 인스턴스를 생성하고, 필요한 정보를 캐시한다.

```kotlin
class ClassInfo<T : Any>(
  cls: KClass<T>,
) {
  private val className = cls.qualifiedName
  private val constructor: KFunction<T> =
    cls.primaryConstructor
      ?: throw JKidException("Class ${cls.qualifiedName} doesn't have a primary constructor")

  // JSON 파일의 각 key 에 해당하는 파라미터 저장
  private val jsonNameToParamMap = hashMapOf<String, KParameter>()

  // 각 파라미터에 대한 직렬화기 저장
  private val paramToSerializerMap = hashMapOf<KParameter, ValueSerializer<out Any?>>()

  // @DeserializeInterface 애너테이션 인자로 지정한 클래스 저장
  private val jsonNameToDeserializeClassMap = hashMapOf<String, Class<out Any>?>()

  // 초기화 시 각 생성자 파라미터에 해당하는 프로퍼티를 찾아서 애너테이션을 가져옴
  init {
    constructor.parameters.forEach { cacheDataForParameter(cls, it) }
  }

  private fun cacheDataForParameter(
    cls: KClass<*>,
    param: KParameter,
  ) {
    val paramName =
      param.name
        ?: throw JKidException("Class $className has constructor parameter without name")

    val property = cls.declaredMemberProperties.find { it.name == paramName } ?: return
    val name = property.findAnnotation<JsonName>()?.name ?: paramName
    jsonNameToParamMap[name] = param

    val deserializeClass = property.findAnnotation<DeserializeInterface>()?.targetClass?.java
    jsonNameToDeserializeClassMap[name] = deserializeClass

    val valueSerializer =
      property.getSerializer()
        ?: serializerForType(param.type.javaType)
        ?: return
    paramToSerializerMap[param] = valueSerializer
  }

  fun getConstructorParameter(propertyName: String): KParameter =
    jsonNameToParamMap[propertyName]
      ?: throw JKidException("Constructor parameter $propertyName is not found for class $className")

  fun getDeserializeClass(propertyName: String) = jsonNameToDeserializeClassMap[propertyName]

  fun deserializeConstructorArgument(
    param: KParameter,
    value: Any?,
  ): Any? {
    val serializer = paramToSerializerMap[param]
    if (serializer != null) return serializer.fromJsonValue(value)

    validateArgumentType(param, value)
    return value
  }

  private fun validateArgumentType(
    param: KParameter,
    value: Any?,
  ) {
    if (value == null && !param.type.isMarkedNullable) {
      throw JKidException("Received null value for non-null parameter ${param.name}")
    }
    if (value != null && value.javaClass != param.type.javaType) {
      throw JKidException(
        "Type mismatch for parameter ${param.name}: " +
                "expected ${param.type.javaType}, found ${value.javaClass}",
      )
    }
  }

  fun createInstance(arguments: Map<KParameter, Any?>): T {
    ensureAllParametersPresent(arguments)
    return constructor.callBy(arguments)
  }

  // 생성자에 필요한 필수 파라미터가 맵에 모두 있는지 검증
  // 리플렉션 캐시를 사용하면 이 함수에서 수행하는 과정(역직렬화를 제어하는 애너테이션을 찾는 과정) 을 JSON 데이터에서 발견한
  // 모든 프로퍼티에 대해 반복할 필요없이 프로퍼티 이름별로 단 한번만 수행 가능
  private fun ensureAllParametersPresent(arguments: Map<KParameter, Any?>) {
    for (param in constructor.parameters) {
      // 파라미터에 디폴트 값이 있으면 param.isOptional 이 true 이므로 그런 파라미터에 대한 인자가 인자 맵에 없어도 문제없음
      // 파라미터가 null 이 될 수 있는 값이라면 type.isMarkedNullable 이 true 이므로 디폴트 파라미터 값으로 null 을 사용함
      // 이 두 가지 경우가 모두 아니라면 예외 발생
      if (arguments[param] == null && !param.isOptional && !param.type.isMarkedNullable) {
        throw JKidException("Missing value for parameter ${param.name}")
      }
    }
  }
}
```

---

# 정리하며..

- 코틀린에서는 자바보다 더 넓은 대상에 애너테이션 적용이 가능함
  - 그런 대상으로는 파일과 식이 있음
- 애너테이션 인자로 primitive 타입 값, 문자열, enum, 클래스 참조, 다른 애너테이션 클래스의 인스턴스, 그리고 지금까지 말한 여러 유형의 값으로 이루어진 배열 사용 가능
- 애너테이션 클래스를 정의할 때는 본문이 없고, 주 생성자의 모든 파라미터를 val 프로퍼티로 표시한 코틀린 클래스를 사용함
- 메타 애너테이션을 사용하여 대상, 애너테이션 유지 방식 등 여러 애너테이션 특성 지정 가능
- 리플렉션 API 를 통해 실행 시점에 객체의 메서드와 프로퍼티를 열거하고 접근 가능
- 리플렉션 API 에는 클래스(`KClass`), 함수(`KFunction`) 등 여러 종류의 선언을 표현하는 인터페이스가 있음
- 클래스를 컴파일 시점에 알고 싶다면 `KClass` 인스턴스를 얻기 위해 `ClassName::class` 사용
- 하지만 실행 시점에 obj 변수에 담긴 객체로부터 `KClass` 인스턴스를 얻기 위해서는 `obj.javaClass.kotlin` 사용
- `KFunction`과 `KProperty` 인터페이스는 모두 `KCallable` 을 확장하고, `KCallable` 은 제네릭 `call()` 메서드를 제공함
- `KFunction0`, `KFunction1` 등의 인터페이스는 모두 파라미터 수가 다른 함수를 표현하며, `invoke()` 메서드를 사용하여 함수를 호출할 수 있음
- `KProperty0` 은 최상위 프로퍼티나 변수에 접근할 때 사용하는 인터페이스임
- `KProperty1` 은 수신 객체가 있는 프로퍼티에 접근할 때 사용하는 인터페이스임
- `KMutableProperty0`, `KMutableProperty1` 은 각각 `KProperty0`, `KProperty1` 을 확장하며, `set()` 메서드를 통해 프로퍼티 값을 변경할 수 있음

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
* [토크나이저, 렉서, 파서 (Tokenizer, Lexer, Parser)](https://gobae.tistory.com/94)