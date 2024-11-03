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
* [3. 최종 역직렬화 단계: `callBy()`, 리플렉션을 사용하여 객체 생성](#3-최종-역직렬화-단계-callby-리플렉션을-사용하여-객체-생성)
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

[3. 애너테이션을 활용한 JSON 직렬화 제어](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#3-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98%EC%9D%84-%ED%99%9C%EC%9A%A9%ED%95%9C-json-%EC%A7%81%EB%A0%AC%ED%99%94-%EC%A0%9C%EC%96%B4) 와 [7. 애너테이션 파라메터로 제네릭 클래스 받기](https://assu10.github.io/dev/2024/07/14/kotlin-annotation-reflection-1/#7-%EC%95%A0%EB%84%88%ED%85%8C%EC%9D%B4%EC%85%98-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A1%9C-%EC%A0%9C%EB%84%A4%EB%A6%AD-%ED%81%B4%EB%9E%98%EC%8A%A4-%EB%B0%9B%EA%B8%B0) 에서
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

위 함수는 [1.4. 클래스 참조 대신 실체화한 타입 파라메터 사용: `ServiceLoader`, `::class.java`](https://assu10.github.io/dev/2024/03/18/kotlin-advanced-2-1/#14-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%B0%B8%EC%A1%B0-%EB%8C%80%EC%8B%A0-%EC%8B%A4%EC%B2%B4%ED%99%94%ED%95%9C-%ED%83%80%EC%9E%85-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0-%EC%82%AC%EC%9A%A9-serviceloader-classjava) 에서 
설명한 패턴을 사용하여 타입 파라메터를 `reified` 로 만들어서 애너테이션 클래스를 타입 인자로 전달한다.

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

---

# 3. 최종 역직렬화 단계: `callBy()`, 리플렉션을 사용하여 객체 생성

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