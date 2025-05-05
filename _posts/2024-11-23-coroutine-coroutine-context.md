---
layout: post
title:  "Coroutine - CoroutineContext 구조, 접근, 제거"
date: 2024-11-23
categories: dev
tags: kotlin coroutine
---

**목차**

<!-- TOC -->
* [1. CoroutineContext 구성 요소](#1-coroutinecontext-구성-요소)
* [2. CoroutineContext 구성](#2-coroutinecontext-구성)
  * [2.1. CoroutineContext 구성](#21-coroutinecontext-구성)
  * [2.2. CoroutineContext 구성 요소 덮어씌우기](#22-coroutinecontext-구성-요소-덮어씌우기)
  * [2.3. CoroutineContext 에 Job 생성하여 추가](#23-coroutinecontext-에-job-생성하여-추가)
* [3. CoroutineContext 구성 요소 접근](#3-coroutinecontext-구성-요소-접근)
  * [3.1. CoroutineContext 구성 요소의 키](#31-coroutinecontext-구성-요소의-키)
  * [3.2. 키를 사용하여 CoroutineContext 구성 요소에 접근](#32-키를-사용하여-coroutinecontext-구성-요소에-접근)
    * [3.2.1. 싱글톤 키를 사용하여 CoroutineContext 구성 요소에 접근: _CoroutineName.Key_](#321-싱글톤-키를-사용하여-coroutinecontext-구성-요소에-접근-_coroutinenamekey_)
    * [3.2.2. 구성 요소 자체를 키로 사용하여 구성 요소에 접근: _CoroutineName_](#322-구성-요소-자체를-키로-사용하여-구성-요소에-접근-_coroutinename_)
    * [3.2.3. 구성 요소의 Key 프로퍼티를 사용하여 구성 요소에 접근: _myCoroutineName.key_](#323-구성-요소의-key-프로퍼티를-사용하여-구성-요소에-접근-_mycoroutinenamekey_)
* [4. CoroutineContext 구성 요소 제거](#4-coroutinecontext-구성-요소-제거)
  * [4.1. `minusKey()` 함수로 구성 요소 제거](#41-minuskey-함수로-구성-요소-제거)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

이 포스트에서는 `Job`, `CoroutineDispatcher`, `CoroutineName` 이 CoroutineContext 의 구성 요소라는 것을 이해하고, CoroutineContext 의 구성 요소를
결합하거나 분리하는 방법에 대해 알아본다.

대표적인 코루틴 빌더 함수인 `launch()` 와 `async()` 의 시그니처를 보자.

```kotlin
public fun CoroutineScope.launch(
    context: CoroutineContext = EmptyCoroutineContext,
    start: CoroutineStart = CoroutineStart.DEFAULT,
    block: suspend CoroutineScope.() -> Unit
): Job

public fun <T> CoroutineScope.async(
  context: CoroutineContext = EmptyCoroutineContext,
  start: CoroutineStart = CoroutineStart.DEFAULT,
  block: suspend CoroutineScope.() -> T
): Deferred<T>
```

두 함수 모두 context, start, block 매개변수를 갖는다.

- **context**
  - CoroutineContext
- **start**
  - CoroutineStart
- **block**
  - launch(): Unit 을 반환하는 람다식
  - async(): 제네릭 타입 T 를 반환하는 람다식

[2.2. `CoroutineName` 을 사용하여 코루틴에 이름 추가](https://assu10.github.io/dev/2024/11/02/coroutine-setup/#22-coroutinename-%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EC%97%AC-%EC%BD%94%EB%A3%A8%ED%8B%B4%EC%97%90-%EC%9D%B4%EB%A6%84-%EC%B6%94%EA%B0%80) 에서
context 자리에 CoroutineName 을 사용하였고, [4.1. `launch()` 의 파라미터로 `CoroutineDispatcher` 사용](https://assu10.github.io/dev/2024/11/03/coroutine-dispatcher/#41-launch-%EC%9D%98-%ED%8C%8C%EB%9D%BC%EB%A9%94%ED%84%B0%EB%A1%9C-coroutinedispatcher-%EC%82%AC%EC%9A%A9) 에서는
context 자리에 CoroutineDispatcher 객체가 사용되었다.

CoroutineName 과 CoroutineDispatcher 는 각각 다른 목적을 가지지만 **공통적으로 CoroutineContext 의 구성 요소**라는 점에서 `launch()` 나 `withContext()` 등의
코루틴 빌더에서 context 파라미터로 함께 사용될 수 있다.

```kotlin
launch(CoroutineName("MyCoroutine"))
launch(Dispatchers.IO)
launch(Dispatchers.Default + CoroutineName("IOCoroutine")) // 이름과 디스패처를 함께 지정하여 코루틴의 실행환경과 디버깅 편의덩을 동시에 챙김
```

CoroutineName 은 코루틴에 식별용 이름을 부여할 수 있고, CoroutineDispatcher 는 코루틴이 실행될 스레드/스레드풀을 결정하며 이 둘 모두 CoroutineContext 를
구성하는 요소이므로 `launch()`, `async()`, `withContext()` 등에서 context 인자로 직접 전달할 수 있다.

**CoroutineContext 는 코루틴을 실행하는 실행 환경을 설정하고 관리하는 인터페이스**로 CoroutineDispatcher, CoroutineName, Job 등의 객체를 조합하여 코루틴이
어떤 스레드에서 실행될지, 어떤 이름으로 구분될지, 어떤 생명 주기를 가질지를 설정할 수 있다.  
즉, **코루틴의 실행과 관련된 모든 설정은 CoroutineContext 를 통해 이루어지며**, 이는 코루틴의 생성, 실행, 취소 등 전반적인 제어에 관여한다.

이 포스트에서는 Coroutine 객체를 사용하여 코루틴의 실행 환경을 설정하고 관리하는 방법에 대해 알아본다.

- CoroutineContext 구성 요소
- CoroutineContext 구성 방법
- CoroutineContext 구성 요소에 접근
- CoroutineContext 구성 요소 제거

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap06) 에 있습니다.

---

**개발 환경**

- mac os
- openjdk 17.0.14

build.gradle.kts

```kotlin
plugins {
  kotlin("jvm") version "2.1.10"
  application
}

group = "com.assu.study"
version = "0.0.1-SNAPSHOT"

repositories {
  mavenCentral()
}

dependencies {
//    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.10")
  // 코루틴 라이브러리
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.1")
  // JUnit5 테스트 API(테스트 코드 작성용)
  testImplementation("org.junit.jupiter:junit-jupiter-api:5.12.0")
  // JUnit5 테스트 엔진(테스트 실행 시 필요)
  testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.12.0")
  // 코루틴 테스트 라이브러리
  testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
}

// JUnit5 를 사용하기 위한 옵션
tasks.test {
  useJUnitPlatform()
}

kotlin {
  jvmToolchain(17)
}

application {
  mainClass.set("MainKt")
}
```

gradle.properties

```properties
kotlin.code.style=official
```

---

# 1. CoroutineContext 구성 요소

CoroutineContext는 여러 요소들의 집합이며, 그중 코루틴 실행 시 가장 자주 사용되는 핵심 구성 요소는 다음의 4가지이다.
- [**CoroutineName**](https://assu10.github.io/dev/2024/11/02/coroutine-setup/#22-coroutinename-%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EC%97%AC-%EC%BD%94%EB%A3%A8%ED%8B%B4%EC%97%90-%EC%9D%B4%EB%A6%84-%EC%B6%94%EA%B0%80)
  - 코루틴에 이름을 부여하여 디버깅이나 로그 분석 시 식별을 용이하게 함
- [**CoroutineDispatcher**](https://assu10.github.io/dev/2024/11/03/coroutine-dispatcher/)
  - 코루틴이 어느 스레드 혹은 어느 스레드풀에서 실행될 지 결정함
  - 대표적으로 Dispatchers.Default, Dispatchers IO, Dispatchers.Main 등이 있음
- [**Job**](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/)
  - 코루틴의 생명 주기를 관리하는 핵심 요소
  - 취소나 완료 상태 추적, 자식 코루틴의 계충 구조 관리 등에 사용됨
- **CoroutineExceptionHandler**
  - 코루틴 내부에서 발생한 예외를 처리하는 핸들러

> CoroutineExceptionHandler 에 대한 내용은 추후 다룰 예정입니다.

이제 CoroutineContext 객체가 위의 구성 요소들을 어떻게 관리하고 사용하는지에 대해 알아본다.

---

# 2. CoroutineContext 구성

CoroutineContext 객체는 **키-값의 구조로 구성 요소들을 관리**한다.  
각 구성 요소는 고유한 키를 가지며, **같은 키에 대해 중복된 값은 허용하지 않는다.**  
따라서 하나의 CoroutineContext 객체는 하나의 CoroutineName, 하나의 CoroutineDispatcher, 하나의 Job, 하나의 CoroutineExceptionHandler 만 존재할 수 있다.

---

## 2.1. CoroutineContext 구성

CoroutineContext 객체는 키-쌍으로 구성 요소를 관리하지만 키에 값을 직접 대입하는 방식이 아니라 **`+` 연산자를 통해 여러 CoroutineContext 요소를 조합**하는 방식으로 사용된다.

아래는 CoroutineDispatcher 객체인 newSingleThreadContext("myThread") 와 CoroutineName 객체인 CoroutineName("myCoroutine") 으로 구성된
CoroutineContext 객체를 만드는 예시이다.

```kotlin
val coroutineContext: CoroutineContext = newSingleThreadContext("myThread") + CoroutineName("myCoroutine")
```

이렇게 만들어진 CoroutineContext 객체는 아래와 같은 형태가 된다.

|              키              |                 값                  |
|:---------------------------:|:----------------------------------:|
|       CoroutineName 키       |    CoroutineName("myCoroutine")    |
|    CoroutineDispatcher 키    | newSingleThreadContext("myThread") |
|            Job 키            |              설정되지 않음               |
| CoroutineExceptionHandler 키 |              설정되지 않음               |


만들어진 CoroutineContext 객체는 코루틴 빌더 함수의 context 인자로 넘겨 코루틴을 실행하는데 사용할 수 있다.

```kotlin
package chap06

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking
import kotlin.coroutines.CoroutineContext

fun main() = runBlocking<Unit> {
    val myCoroutineContext: CoroutineContext = newSingleThreadContext("myThread") + CoroutineName("myCoroutine")

    launch(context = myCoroutineContext) {
        println("[${Thread.currentThread().name}] 실행")
    }
}
```

```shell
[myThread @myCoroutine#2] 실행
```

구성 요소가 없는 CoroutineContext 는 `EmptyCoroutineContext` 를 통해 만들 수 있다.

```kotlin
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.EmptyCoroutineContext

val emptyCoroutineContext: CoroutineContext = EmptyCoroutineContext
```

---

## 2.2. CoroutineContext 구성 요소 덮어씌우기

만일 같은 키를 가진 요소를 추가하면 기존값이 새로운 값으로 덮어쓰기 된다.

```kotlin
val context = CoroutineName("First") + CoroutineName("Second")
```

위 코드에서 context 에는 _First_ 가 무시되고, _Second_ 라는 이름만 남게 된다.

이러한 구조 덕분에 **CoroutineContext 는 불변성과 타입 안전성을 유지**하면서도 유연하게 여러 요소를 조합할 수 있다.

아래 코드를 보자.

```kotlin
package chap06

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking
import kotlin.coroutines.CoroutineContext

fun main() = runBlocking<Unit> {
    val myCoroutineContext: CoroutineContext = newSingleThreadContext("myThread") + CoroutineName("myCoroutine")
    val newMyCoroutineContext: CoroutineContext = myCoroutineContext + CoroutineName("newMyCoroutine")

    launch(context = newMyCoroutineContext) {
        println("[${Thread.currentThread().name}] 실행")
    }
}
```

```shell
[myThread @newMyCoroutine#2] 실행
```

---

## 2.3. CoroutineContext 에 Job 생성하여 추가

> Job 객체를 직접 생성해 추가하면 코루틴의 구조화가 깨지기 때문에(= 부모-자식 관계가 끊어짐) 새로운 Job 객체를 생성하여 CoroutineContext 객체에 추가하는 것은 
> 주의가 필요함
> 
> 이에 대한 상세한 내용은 추후 다룰 예정입니다. (p. 181)

Job 객체는 기본적으로 `launch()` 나 `runBlocking()` 과 같은 코루틴 빌더 함수를 통해 자동으로 생성되지만, `Job()` 을 호출해 생성할 수도 있다.

```kotlin
package chap06

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlin.coroutines.CoroutineContext

fun main() = runBlocking<Unit> {
    val myJob = Job()
    val coroutineContext: CoroutineContext = Dispatchers.IO + myJob

    launch(context = coroutineContext) {
        println("[${Thread.currentThread().name}] 실행")
    }
}
```

위 코드는 아무것도 출력되지 않는다.  
이유는 `runBlocking()` 은 내부의 모든 자식 코루틴이 **자신의 자식일 때만** 끝날 때까지 기다려준다. 하지만 위의 `Job()` 을 통해 만들어진 _myJob_ 은 **runBlocking() 의 
자식이 아니라 독립적인 Job** 이다.  
즉, _launch(context = Dispatchers.IO + Job())_ 은 runBlocking 과는 무관한 별도의 코루틴에서 실행되며, runBlocking 은 해당 Job 의 완료를 
기다려주지 않기 때문에 **`launch()` 가 실행되기 전에 main() 이 종료**되어 버린다.

---

# 3. CoroutineContext 구성 요소 접근

CoroutineContext 객체의 구성 요소에 접근하기 위해서는 각 구성 요소가 가진 고유한 키가 필요하다.  
여기서는 각 구성 요소의 키를 얻는 방법에 대해 알아본다.

---

## 3.1. CoroutineContext 구성 요소의 키

CoroutineContext 는 여러 구성 요소들의 모음이며, 각 구성 요소는 고유한 키(CoroutineContext.Key\<T\>) 를 통해 관리된다.  
이 **Key 는 중복을 허용하지 않으며**, 특정 구성 요소를 CoroutineContext 에서 가져올 때 사용하는 식별자 역할을 한다.

CoroutineName, Job, CoroutineDispatcher, CoroutineExceptionHandler 등의 코루틴 구성 요소들은 **자신의 내부에 Key 를 동반 객체(companion object)(= 싱글톤 객체로 구현) 로 
선언**하여 자신을 CoroutineContext 에 등록하거나 검색할 수 있도록 한다.

아래는 CoroutineName 클래스 구현체이다.

```kotlin
public data class CoroutineName(
    val name: String
) : AbstractCoroutineContextElement(CoroutineName) {
    public companion object Key : CoroutineContext.Key<CoroutineName>

    // ...
}
```

위 구조의 핵심 포인트는 아래와 같다.
- CoroutineName 클래스는 AbstractCoroutineContextElement 를 상속함
- 생성자에서 CoroutineName 키를 부모 클래스에 전달
- 동반 객체 Key 는 CoroutineContext.Key\<CoroutineName\> 를 구현한 싱글톤

이 덕분에 `CoroutineContext[CoroutineName]` 의 형태로 손쉽게 CoroutineName 값을 가져올 수 있다.

<details markdown="1">
<summary>생성자에서 CoroutineName 키를 부모 클래스에 전달 (Click!)</summary>

_생성자에서 CoroutineName 키를 부모 클래스에 전달_ 이라는 부분들 보자.  

위 코드의 _AbstractCoroutineContextElement(CoroutineName)_ 에서 _CoroutineName_ 은 [동반 객체](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#4-%EB%8F%99%EB%B0%98-%EA%B0%9D%EC%B2%B4-companion-object) _companion object Key_ 의 이름이 생략된 표현이다.

```kotlin
public companion object Key : CoroutineContext.Key<CoroutineName>
```

이렇게 동반 객체에 이름을 _Key_ 라고 명시했어도, 클래스 내부에서는 _CoroutineName_ 이라는 클래스 이름으로도 접근할 수 있다.

쉽게 이해하기 위해 아래 예시를 보자.
```kotlin
class MyClass {
  companion object MyCompanion {
    val x = 10
  }
}

fun main() {
  println(MyClass.MyCompanion.x)  // 명시적 접근
  println(MyClass.x)              // 클래스 이름으로도 접근 가능 (동반 객체 이름 생략 가능)
}
```

즉, 동반 객체의 이름이 _Key_ 여도 클래스 이름으로 접근할 수 있다.

따라서 _AbstractCoroutineContextElement(CoroutineName)_ 에서 괄호 안의 _CoroutineName_ 은 타입이 아니라 동반 객체 `CoroutineName.Key` 를 의미한다.  
이는 코클린 문법상 클래스 내부에서는 동반 객체를 클래스 이름으로도 자동 참조할 수 있기 때문에 가능한 표현이다.

> 좀 더 상세한 내용은 [3.2.2. 구성 요소 자체를 키로 사용하여 구성 요소에 접근](#322-구성-요소-자체를-키로-사용하여-구성-요소에-접근) 을 참고하세요.

</details>
<br />

다른 구성 요소들도 동일한 패턴을 따른다.

|  CoroutineContext 구성 요소   |           내부에 선언된 키           |
|:-------------------------:|:-----------------------------:|
|       CoroutineName       |       CoroutineName.Key       |
|            Job            |            Job.Key            |
|    CoroutineDispatcher    |    CoroutineDispatcher.Key    |
| CoroutineExceptionHandler | CoroutineExceptionHandler.Key |


예시로 Job 인터페이스의 선언도 아래와 같다.

```kotlin
public interface Job : CoroutineContext.Element {
    public companion object Key : CoroutineContext.Key<Job>
    
    // ...
}
```

---

CoroutineDispatcher.Key 는 코틀린 버전 2.1.10 기준으로 아직 실험 중인 API 이며, 사용할 경우 아래처럼 명시적으로 `opt-in` 해야 한다.

```kotlin
@OptIn(ExperimentalStdlibApi::class)
val dispatcherKey = CoroutineDispatcher.Key
```

> **Opt-in**
> 
> 명시적으로 동의하거나 참여 의사를 표시해야만 어떤 서비스나 기능이 활성화되는 방식  
> 즉, 기본적으로는 꺼져 있거나 제외된 상태이고, 사용자가 자발적으로 '예' 라고 선택해야만 참여되는 방식

실험적 API 는 향후 변경될 가능성이 있으므로, 안정적인 코드에서는 사용을 피하는 것이 좋다.  
따라서 실험적인 API 를 피하려면 **직접 dispatcher 객체의 key 프로퍼티를 사용**하면 된다.

```kotlin
package chap06

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlin.coroutines.CoroutineContext

fun main() = runBlocking<Unit> {
  val dispatcherKey1: CoroutineContext.Key<*> = Dispatchers.IO.key
  val dispatcherKey2: CoroutineContext.Key<*> = Dispatchers.Default.key

  println("${dispatcherKey1 === dispatcherKey2}") // true
}
```

Dispatchers.IO.key 와 Dispatchers.Default.key 는 서로 다른 디스패터이지만, 그들이 가진 .key 는 모두 동일한 CoroutineDispatcher.Key 객체를 가리킨다.  
이유는 간단한다. **CoroutineDispatcher 라는 타입의 Context 요소는 모두 하나의 고유한 키로 식별**되기 때문이다.

CoroutineContext 입장에서 Dispatcher.IO, Dispatcher.Default, Dispatchers.Unconfined 등은 **모두 같은 타입(CoroutineDispatcher) 를 공유**하므로, 
그 키도 동일한 객체를 참조한다.

즉, **서로 다른 디스패처라도 같은 CoroutineDispatcher.Key 를 사용하므로 .key 는 항상 동일한 객체를 반환**한다.

---

## 3.2. 키를 사용하여 CoroutineContext 구성 요소에 접근

### 3.2.1. 싱글톤 키를 사용하여 CoroutineContext 구성 요소에 접근: _CoroutineName.Key_

CoroutineName.Key 를 사용하여 CoroutineContext 객체의 CoroutineName 구성 요소에 접근하는 예시아다.

```kotlin
package chap06

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
  val myCoroutineContext = CoroutineName("MyCoroutine") + Dispatchers.IO

  // myCoroutineContext 에 대해 get() 의 인자로 CoroutineName.Key 를 넘김으로써
  // myCoroutineContext 를 구성하는 CoroutineName 객체만 가져옴
  val nameFromContext1 = myCoroutineContext.get(CoroutineName.Key)

  // get() 은 연산자 함수(operator fun) 이므로 대괄호로 대체 가능
  val nameFromContext2 = myCoroutineContext[CoroutineName.Key]

  println(nameFromContext1)
  println(nameFromContext2)
}
```

```shell
CoroutineName(MyCoroutine)
CoroutineName(MyCoroutine)
```

---

### 3.2.2. 구성 요소 자체를 키로 사용하여 구성 요소에 접근: _CoroutineName_

CoroutineContext 의 주요 구성 요소인 CoroutineName, Job, CoroutineDispatcher, CoroutineExceptionHandler, 이들은 모두 클래스 내부에 
companion object 로 **`CoroutineContext.Key<T>` 를 구현한 Key 객체**를 가지고 있다.  
덕분에 context.get(CoroutineName.Key) 처럼 명시적으로 **.Key 를 지정하지 않아도, context.get(CoroutineName) 처럼 클래스 자체를 키로 사용**할 수 있다.

```kotlin
package chap06

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val myCoroutineContext = CoroutineName("MyCoroutine") + Dispatchers.IO

  // 내부적으로 CoroutineName.Key 사용
    val nameFromContext1 = myCoroutineContext.get(CoroutineName) // .Key 제거

    // get() 은 연산자 함수(operator fun) 이므로 대괄호로 대체 가능
    val nameFromContext2 = myCoroutineContext[CoroutineName] // .Key 제거

    println(nameFromContext1)
    println(nameFromContext2)
}
```

위 코드에서는 `CoroutineName.Key` 를 키로 사용하는 대신 _.Key_ 를 제거한 CoroutineName 클래스를 키로 사용했지만 결과는 동일하다.

코틀린에서는 CoroutineContext.Element 를 구현한 클래스가 내부에 다음처럼 Key 를 정의해두는 방식이 일반적이다.

```kotlin
public companion object Key : CoroutineContext.Key<CoroutineName>
```

이렇게 정의된 키를 클래스 이름으로도 접근이 가능하기 때문에 CoroutineName 자체를 키로 사용할 수 있는 것이다.  
즉, 아래 두 표현은 완전히 동일한 의미이다.
```kotlin
context.get(CoroutineName) == context.get(CoroutineName.Key)
context[CoroutineName] == context[CoroutineName.Key]
```

그 이유는 키가 들어갈 자리에 CoroutineName 을 사용하면 자동으로 CoroutineName.Key 를 사용하여 연산을 처리하기 때문이다.

---

### 3.2.3. 구성 요소의 Key 프로퍼티를 사용하여 구성 요소에 접근: _myCoroutineName.key_

CoroutineContext 의 구성 요소 인스턴스에서 .key 프로퍼티로 접근한 키를 해당 클래스의 companion object 로 선언된 Key 객체와 동일한 참조를 가진다.


```kotlin
package chap06

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlin.coroutines.CoroutineContext

fun main() = runBlocking<Unit> {
    val myCoroutineName: CoroutineName = CoroutineName("MyCoroutine")
    val myDispatcher: CoroutineDispatcher = Dispatchers.IO
    val myCoroutineContext: CoroutineContext = myCoroutineName + myDispatcher

    println(myCoroutineContext[myCoroutineName.key])
    println(myCoroutineContext[myDispatcher.key])
}
```

```shell
CoroutineName(MyCoroutine)
Dispatchers.IO
```

위 코드에서 보면 각 구성 요소의 .key 프로퍼티를 통해 CoroutineContext 에서 해당 요소를 가져온다.

중요한 점은 **구성 요소의 key 프로퍼티는 동반 객체로 선언된 Key 와 동일한 객체를 가리킨다는 것**이다.  
즉, 각 구성 요소는 내부적으로 **companion object 로 선언된 Key 객체를 공유**하고 있으며, .key 프로퍼티는 항상 이 Key 를 반환한다.
예를 들어 CoroutineName.Key 와 myCoroutineName.key 는 같은 객체를 참조하며, 모든 CoroutineName 인스턴스는 같은 Key 객체를 공유한다.

```kotlin
package chap06

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.runBlocking

fun main() = runBlocking{
    val myCoroutineName: CoroutineName = CoroutineName("MyCoroutine")

    if (myCoroutineName.key === CoroutineName.Key) {
        println("myCoroutineName.key와 CoroutineName.Key 는 동일함")
    }
}
```

```shell
myCoroutineName.key와 CoroutineName.Key 는 동일함
```

이처럼 모든 **CoroutineName 인스턴스는 같은 Key 객체를 공유**하며, 이를 통해 CoroutineContext 내부 요소를 안전하고 효율적으로 조회할 수 있다.

---

# 4. CoroutineContext 구성 요소 제거

---

## 4.1. `minusKey()` 함수로 구성 요소 제거

```kotlin
package chap06

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlin.coroutines.CoroutineContext

fun main() = runBlocking{
  val myCoroutineName = CoroutineName("myCoroutineName")
  val myDispatcher = Dispatchers.IO
  val myJob = Job()
  val myCoroutineContext: CoroutineContext = myCoroutineName + myDispatcher + myJob

  val deletedCoroutineContext = myCoroutineContext.minusKey(CoroutineName)

  println("===== deletedCoroutineContext =====")
  println(deletedCoroutineContext[CoroutineName]) // or CoroutineName.Key
  println(deletedCoroutineContext.get(Dispatchers.IO.key))
  println(deletedCoroutineContext[Job]) // or Job.Key

  println("===== myCoroutineContext =====")
  println(myCoroutineContext[CoroutineName]) // or CoroutineName.Key
  println(myCoroutineContext.get(Dispatchers.IO.key))
  println(myCoroutineContext[Job]) // or Job.Key
}
```

_myCoroutineContext_ 에서 CoroutineName 이 제거되어 반환된 CoroutineContext 가 _deletedCoroutineContext_ 에 할당된다.  
주의할 점은 `minusKey()` 를 호출한 CoroutineContext 객체(위에서는 myCoroutineContext)는 그대로 유지된다는 점이다.

```shell
===== deletedCoroutineContext =====
null
Dispatchers.IO
JobImpl{Active}@368239c8

===== myCoroutineContext =====
CoroutineName(myCoroutineName)
Dispatchers.IO
JobImpl{Active}@368239c8
```

---

# 정리하며..

- CoroutineContext 객체는 코루틴의 실행 환경을 설정하고 관리하는 객체로 CoroutineDispatcher, CoroutineName, Job, CoroutineExceptionHandler 등의 객체를 조합하여 코루틴 실행 환경을 정의함
- CoroutineContext 의 4가지 주요 구성 요소는 아래와 같음
  - CoroutineName 객체
    - 코루틴의 이름 설정
  - CoroutineDispatcher 객체
    - 코루틴을 스레드로 보내 실행
  - Job 객체
    - 코루틴을 조작하는데 사용
  - CoroutineExceptionHandler 객체
    - 코루틴의 예외 처리
- CoroutineContext 객체는 키-값 쌍으로 구성 요소를 관리하며, 동일한 키에 중복된 값을 허용하지 않으므로 각 구성 요소는 한 개씩만 가질 수 잇음
- 구성 요소의 동반 객체로 선언된 key 프로퍼티를 사용하여 키 값에 접근할 수 있음
  - 예) CoroutineName 의 키 값은 CoroutineName.Key 를 통해 접근할 수 있음
- 키를 연산자 함수인 `get()` 과 함께 사용하여 CoroutineContext 객체에 설정된 구성 요소에 접근할 수 있음
  - 예) myCoroutineContext 의 CoroutineName 구성 요소에 접근 시 myCoroutineContext.get(CoroutineName.Key) 로 접근 가능
- `get()` 연산자는 대괄호 `[]` 로 대체할 수 있음
  - 예) myCoroutineContext.get(CoroutineName.Key) 이것은 myCoroutineContext\[CoroutineName.Key\] 로 대체 가능
- CoroutineName, CoroutineDispatcher, Job, CoroutineExceptionHandler 는 companion object 인 Key 를 통해 CoroutineContext.Key 를 구현하기 때문에 그 자체를 키로 사용할 수 있음
  - 예) myCoroutineContext\[CoroutineName.Key\] 이것은 myCoroutineContext\[CoroutineName\] 로 대체 가능
- CoroutineContext 객체에 `minusKey()` 함수를 사용하면 CoroutineContext 객체에서 특정 구성 요소를 제거한 객체를 반환받음


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)