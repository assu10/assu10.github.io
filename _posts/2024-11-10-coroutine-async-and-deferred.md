---
layout: post
title:  "Coroutine - async(), Deferred"
date: 2024-11-10
categories: dev
tags: kotlin coroutine async withContext deferred awaitAll
---

**목차**

<!-- TOC -->
* [1. `async()`](#1-async)
  * [1.1. `async()` 로 `Deferred` 만들기](#11-async-로-deferred-만들기)
  * [1.2. `await()` 로 결과값 수신](#12-await-로-결과값-수신)
* [2. `Deferred`](#2-deferred)
* [3. 복수의 코루틴으로부터 결과값 수신](#3-복수의-코루틴으로부터-결과값-수신)
  * [3.1. `await()` 로 복수의 코루틴으로부터 결과값 수신](#31-await-로-복수의-코루틴으로부터-결과값-수신)
  * [3.2. `awaitAll()` 로 결과값 수신](#32-awaitall-로-결과값-수신)
  * [3.3. 컬렉션에 대해 `awaitAll()` 사용](#33-컬렉션에-대해-awaitall-사용)
* [4. `withContext()`](#4-withcontext)
  * [4.1. `withContext()` 로 async-await 대체](#41-withcontext-로-async-await-대체)
  * [4.2. `withContext()` 동작 방식](#42-withcontext-동작-방식)
    * [4.2.1. async-await 의 코루틴](#421-async-await-의-코루틴)
    * [4.2.2. `withContext()` 의 코루틴](#422-withcontext-의-코루틴)
  * [4.3. `withContext()` 주의점](#43-withcontext-주의점)
  * [4.4. `withContext()` 를 사용한 코루틴 스레드 전환](#44-withcontext-를-사용한-코루틴-스레드-전환)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

이 포스트에서는 `async()` 코루틴 빌더에 대해 알아본다.  
`async()`, `await` 를 사용하여 코루틴으로부터 반환값을 받는 방법과 코루틴을 실행 중인 스레드의 변경을 위해 `withContext` 를 사용하는 방법에 대해 알아본다.

launch() 코루틴 빌더를 통해 생성되는 코루틴은 기본적으로 작업 실행 후 결과를 반환하지 않는다.  
하지만 작업을 하다보면 코루틴으로부터 결과를 수신해야 하는 경우가 빈번하다.  
예) 네크워크 통신 실행 후 응답을 처리해야 하는 경우에 네트워크 통신을 실행하는 코루틴으로부터 결과를 수신받아야 함

코틀린 라이브러리는 `async()` 코루틴 빌더를 통해 코루틴으로부터 결과값을 수신받을 수 있도록 한다.  
launch() 함수를 사용하면 결과값이 없는 코루틴 객체인 Job 이 반환되지만, `async()` 함수를 사용하면 결과값이 있는 코루틴 객체인 `Deferred` 가 반환되며, 
`Deferred` 객체를 통해서 코루틴으로부터 결과값을 수신할 수 있다.

여기서는 `async()` 함수와 그로부터 반환되는 `Deferred` 객체를 사용하여 코루틴으로부터 결과값을 수신하는 방법에 대해 알아본다.

- async-await 로 코루틴으로부터 결과값 수신
- `awaitAll()` 로 복수의 코루틴으로부터 결과값 수신
- `withContext` 로 실행 중인 코루틴의 CoroutineContext 변경

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap05) 에 있습니다.

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

# 1. `async()`

---

## 1.1. `async()` 로 `Deferred` 만들기

아래는 `launch()` 와 `async()` 함수의 시그니처이다.

`launch()` 시그니처
```kotlin
public fun kotlinx.coroutines.CoroutineScope.launch(
  context: kotlin.coroutines.CoroutineContext = COMPILED_CODE,
  start: kotlinx.coroutines.CoroutineStart = COMPILED_CODE,
  block: suspend kotlinx.coroutines.CoroutineScope.() -> kotlin.Unit
): kotlinx.coroutines.Job { /* compiled code */ }
```

`async()` 시그니처
```kotlin
public fun <T> kotlinx.coroutines.CoroutineScope.async(
  context: kotlin.coroutines.CoroutineContext = COMPILED_CODE, 
  start: kotlinx.coroutines.CoroutineStart = COMPILED_CODE, 
  block: suspend kotlinx.coroutines.CoroutineScope.() -> T
): kotlinx.coroutines.Deferred<T> { /* compiled code */ }
```

둘 다 context 인자로 CoroutineDispatcher 를 설정할 수 있고, start 인자로 CoroutineStart.LAZY 를 설정해 지연 코루틴을 만들 수 있으며, 
코루틴에서 실행할 코드를 작성하는 block 람다식을 가진다.

`launch()` 와 `async()` 의 차이점은 `launch()` 는 코루틴이 결과값을 직접 반환할 수 없는 반면, **`async()` 는 코루틴이 결과값을 직접 반환**할 수 있다는 것이다.

`launch()` 코루틴 빌더는 코루틴에서 결과값을 반환하지 않고 Job 객체를 반환하며, **`async()` 코루틴 빌더는 결과값을 담아 반환하기 위해 `Deferred<T>` 타입의 객체를 반환**한다.

`Deferred` 는 Job 과 같이 코루틴을 추상화한 객체이지만 코루틴으로부터 생성된 결과값을 감싸는 기능을 추가로 가지며, 이 결과값의 타입은 제네릭 타입인 T 로 표현한다.

`Deferred` 제네릭 타입을 지정하기 위해서는 `Deferred` 에 명시적으로 타입을 설정하거나, `async()` 블록의 반환값으로 반환할 결과값을 설정하면 된다.

```kotlin
val call: Deferred<String> = async(context = Dispatchers.IO) {
    return@async "Test"
}
```

---

## 1.2. `await()` 로 결과값 수신

`Deferred` 객체는 미래의 어느 시점에 결과값이 반환되는 코루틴 객체로 언제 결과값이 반환될 지 정확히 알 수 없다.

`Deferred` 객체는 결과값 수신을 위해 `await()` 함수를 제공한다.  
`await()` 함수는 await 대상이 된 Deferred 코루틴이 실행 완료될 때까지 `await()` 함수를 호출한 코루틴을 일시 중단하며, Deferred 코루틴이 실행 완료되면 결과값을 
반환하고 호출부의 코루틴을 재개한다.

아래는 `await()` 함수를 통해 _networkDeferred_ 코루틴으로부터 결과값 수신을 기다리는 예시이다.

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    val networkDeferred: Deferred<String> = async(Dispatchers.IO) {
        delay(1000L)
        return@async "Test"
    }
    val result = networkDeferred.await() // 결과값이 반환될 때까지 runBlocking 일시 중단
    println(result)
}
```

위의 코드는 _networkDeferred.await()_ 를 호출한 runBlocking 코루틴(메인 스레드)이 일시 중단되며, _networkDeferred_ 코루틴이 결과를 반환하면 
runBlocking 코루틴이 재개된다.

```shell
Test
```

---

# 2. `Deferred`

모든 코루틴 빌더는 Job 객체를 생성한다. 그리고 async 코루틴 빌더는 `Deferred` 객체를 생성하여 반환한다.  
`Deferred` 객체는 Job 객체의 특수한 형태로 `Deferred` 인터페이스는 Job 인터페이스의 서브타입으로 선언된 인터페이스이다.  
즉, `Deferred` 객체는 코루틴으로부터 결과값 수신을 위해 Job 객체에서 몇 가지 기능이 추가된 Job 객체의 일종이다.  
이러한 특성 때문에 `Deferred` 객체는 Job 객체의 모든 함수와 프로퍼티를 사용할 수 있다.

`Deferred` 인터페이스 시그니처

```kotlin
@kotlin.SubclassOptInRequired public interface Deferred<out T> : kotlinx.coroutines.Job {
    public abstract val onAwait: kotlinx.coroutines.selects.SelectClause1<T>

    public abstract suspend fun await(): T

    @kotlinx.coroutines.ExperimentalCoroutinesApi public abstract fun getCompleted(): T

    @kotlinx.coroutines.ExperimentalCoroutinesApi public abstract fun getCompletionExceptionOrNull(): kotlin.Throwable?
}
```

아래는 `Deferred` 객체에 대해 `join()` 함수를 사용해서 순차 처리를 하고, Job 객체가 올 자리에 `Deferred` 객체를 사용하는 예시이다.

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val networkDeferred: Deferred<String> = async(Dispatchers.IO) {
        delay(1000L)
        return@async "Test"
    }
    networkDeferred.join() // networkDeferred 가 완료될 때까지 대기
    printJobState(networkDeferred) // Job 이 와야할 자리에 Deferred 입력
}

fun printJobState(job: Job) {
    println("🔍 Job 상태 확인:")
    println("- isActive: ${job.isActive}     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태")
    println("- isCancelled: ${job.isCancelled} // 취소가 요청된 상태")
    println("- isCompleted: ${job.isCompleted} // 정상 완료되었거나 예외 또는 취소로 종료된 상태")
}
```

---

# 3. 복수의 코루틴으로부터 결과값 수신

여기서는 복수의 코루틴으로부터 결과값을 효율적으로 수신하는 방법에 대해 알아본다.

---

## 3.1. `await()` 로 복수의 코루틴으로부터 결과값 수신

아래는 2 군데에서 결과를 받는 코드 예시이다.

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis() // 시작 시간
    val deferred1: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        return@async arrayOf("111", "222")
    }
    val result1 = deferred1.await() // deferred1 결과가 수신될 때까지 대기

    val deferred2: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        return@async arrayOf("333", "444")
    }
    val result2 = deferred2.await() // deferred2 결과가 수신될 때까지 대개

    println("${getElapsedTime(startTime)} - 결과: ${listOf(*result1, *result2)}")
    println("${getElapsedTime(startTime)} - 결과: ${listOf(result1, result2)}")
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

```shell
지난 시간: 2017ms - 결과: [111, 222, 333, 444]
지난 시간: 2035ms - 결과: [[Ljava.lang.String;@60215eee, [Ljava.lang.String;@4ca8195f]
```

위 코드는 서로 연관없는 _deferred1_, _deferred2_ 가 동시 처리가 아닌 순차적으로 처리되어 비효율적인 코드이다.

이 문제를 해결하기 위해서는 _deferred1_ 이 `await()` 를 호출하는 위치를 _deferred2_ 코루틴이 실행된 이후로 만들어야 한다.

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis() // 시작 시간
    val deferred1: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        return@async arrayOf("111", "222")
    }
    val deferred2: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        return@async arrayOf("333", "444")
    }

    val result1 = deferred1.await() // deferred1 결과가 수신될 때까지 대기
    val result2 = deferred2.await() // deferred2 결과가 수신될 때까지 대기

    println("${getElapsedTime(startTime)} - 결과: ${listOf(*result1, *result2)}")
}
```

위 코드는 _deferred1.await()_ 가 호출되기 전에 _deferred2_ 코루틴이 실행되기 때문에 _deferred1_, _deferred2_ 코루틴 2개가 동시에 실행된다.  
코루틴 하나는 DefaultDispatcher-worker-1 에서 실행되고, 다른 하나는 DefaultDispatcher-worker-2 스레드에서 실행된다.

```shell
지난 시간: 1020ms - 결과: [111, 222, 333, 444]
```

---

## 3.2. `awaitAll()` 로 결과값 수신

바로 위에선 2개의 코루틴에 대해 결과값을 받아야 했지만 만일 10개의 코루틴으로부터 결과를 받아야할 때 `await()` 함수를 사용한다면 `await()` 를 10번 써야 한다.  
코루틴 라이브러리는 복수의 `Deferred` 객체로부터 결과값을 수신하기 위한 `awaitAll()` 함수를 제공한다.  
`awaitAll()` 함수는 가변 인자로부터 `Deferred` 타입의 객체를 받아 인자로 받은 모든 `Deferred` 코루틴으로부터 결과가 수신될 때까지 호출부의 코루틴을 일시 중단하고, 
결과가 모두 수신되면 `Deferred` 코루틴으로부터 수신한 결과값을 List 로 만들어거 반환한다. 그리고 호출부의 코루틴을 재개한다.

`awaitAll()` 시그니처
```kotlin
public suspend fun <T> awaitAll(vararg deferreds: kotlinx.coroutines.Deferred<T>): kotlin.collections.List<T>
```

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis() // 시작 시간
    val deferred1: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        return@async arrayOf("111", "222")
    }

    val deferred2: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        return@async arrayOf("333", "444")
    }

    val result: List<Array<String>> = awaitAll(deferred1, deferred2) // 요청이 끝날 때까지 대기

    println("${getElapsedTime(startTime)} - 결과: ${listOf(*result[0], *result[1])}")
}
```

```shell
지난 시간: 1010ms - 결과: [111, 222, 333, 444]
```

코루틴 하나는 DefaultDispatcher-worker-1 에서 실행되고, 다른 하나는 DefaultDispatcher-worker-2 스레드에서 실행된다.  
_result[0]_ 은 _deferred1_ 의 결과이고, _result[1]_ 은 _deferred2_ 의 결과이다.

---

## 3.3. 컬렉션에 대해 `awaitAll()` 사용

코루틴 라이브러리는 `awaitAll()` 함수를 Collection 인터페이스에 대한 확장 함수로도 제공한다.

```kotlin
public suspend fun <T> Collection<Deferred<T>>.awaitAll(): List<T>
```

`Collection<Deferred<T>>` 에 대해 `awaitAll()` 함수를 호출하면 컬렉션에 속한 `Deferred` 들이 모두 완료되어 결과값을 반환할 때까지 대기한다.

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis() // 시작 시간
    val deferred1: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        arrayOf("111", "222")
    }

    val deferred2: Deferred<Array<String>> = async(Dispatchers.IO) {
        delay(1000L)
        arrayOf("333", "444")
    }

    listOf(deferred1, deferred2).awaitAll()

    val result: List<Array<String>> = listOf(deferred1, deferred2).awaitAll()

    println("${getElapsedTime(startTime)} - 결과: ${listOf(*result[0], *result[1])}")
}
```

```shell
지난 시간: 1013ms - 결과: [111, 222, 333, 444]
```

이 코드는 바로 위의 가변 인자를 받는 `awaitAll()` 함수를 사용한 것과 완전히 같게 동작한다.

---

# 4. `withContext()`

---

## 4.1. `withContext()` 로 async-await 대체

`withContext()` 함수를 사용하면 async-await 작업을 대체할 수 있다.

```kotlin
public suspend fun <T> withContext(context: CoroutineContext, block: suspend CoroutineScope.() -> T): T
```

`withContext()` 함수가 호출되면 함수의 이자로 설정된 CoroutineContext 객체를 사용하여 block 람다식을 실행하고, 완료되면 그 결과를 반환한다.  
`withContext()` 함수를 호출한 코루틴은 인자로 받은 CoroutineContext 객체를 사용하여 block 람다식을 실행하며, block 람다식을 모두 실행하면 다시 기존의 CoroutineContext 
객체를 사용하여 코루틴을 재개한다.

먼저 async-await 를 사용한 코드를 보자.

```kotlin
package chap05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val result: String = async(context = Dispatchers.IO) {
    delay(1000L)
    return@async "test"
  }.await()

  println(result)
}
```

`async()` 함수를 호출하여 `Deferred` 객체를 만들고, 곧바로 `Deferred` 객체에 대해 `await()` 함수를 호출한다.  
이렇게 **`async()` 함수를 호출한 후 연속적으로 `await()` 함수를 호출하여 결과값 수신을 대기하는 코드는 아래와 같이 `withContext()` 함수로 대체**될 수 있다.

```shell
test
```

```kotlin
package chap05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

fun main() = runBlocking<Unit> {
    val result: String = withContext(context = Dispatchers.IO) {
        delay(1000L)
        return@withContext "test"
    }
    println(result)
}
```

---

## 4.2. `withContext()` 동작 방식

`withContext()` 함수는 async-await 를 연속적으로 호출하는 것과 비슷하게 동작하지만 내부적으로는 다르게 동작한다.  
async-await 쌍은 새로운 코루틴을 생성하여 작업을 처리하지만, `withContext()` 함수는 실행 중이던 코루틴은 그대로 유지한 채 코루틴의 실행 환경만 변경하여 작업을 처리한다.

|   항목   | async { ... }.await()       | withContext { ... }        |
|:------:|:----------------------------|:---------------------------|
| 코루틴 생성 | 새로운 코루틴 생성                  | 기존 코루틴 유지                  |
| 사용 목적  | 병렬 실행이 필요한 작업               | 컨텍스트(Dispatcher) 전환        |
| 리소스 사용 | 상대적으로 더 큼                   | 상대적으로 적음                   |
| 실행 흐름  | 별도 코루틴 생성 후 await() 에서 일시정지 | 현재 코루틴 내에서 Dispatcher 만 전환 |
| 적합한 상황 | 여러 작업을 동시에 실행해야 할 때         | 특정 블록에서만 Dispatcher 전환 시   |

async-await 와 `withContext()` 가 각각 필요한 상황을 코드로 한번 보자.

**async-await: 병렬 작업용**

```kotlin
val a = async(Dispatchers.IO) { loadA() }
val b = async(Dispatchers.IO) { loadB() }

val resultA = a.await()
val resultB = b.await()
```

위 코드를 보면 각각의 작업이 **동시에 실행**되며, `await()` 시점에 결과를 기다린다. 즉, **병렬 처리가 필요할 때 적합**하다.

**`withContext()`: 컨텍스트 전환용**

```kotlin
val result = withContext(Dispatchers.IO) {
    loadSomething()
}
```

위 코드에서는 새로운 코루틴을 만들지 않고 **현재 코루틴을 유지**한 채 **실행 환경(Dispatcher) 만 변경**한다.  
따라서 불필요한 코루틴 생성을 방지할 수 있다.

따라서 **즉시 await 할 거라면 `withContext()` 로 대체하는 것이 효율적**이고, **병렬 실행이 목적이라면 `async()` 를 사용하여 코루틴을 따로 생성**해야 한다.  
**동시성이 필요없는 상황에서 굳이 새로운 코루틴을 생성하는 것은 오버헤드만 추가**하는 꼴이 될 수 있으니 정말 병렬 처리가 필요한지 판단한 후 필요없다면 `withContext()` 로 대체하는 것이 좋다.

---

### 4.2.1. async-await 의 코루틴

```kotlin
package chap05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit >{
    println("[${Thread.currentThread().name}] runBlocking 블록 실행~")

    async(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] async-await  블록 실행~")
    }.await()

    println("[${Thread.currentThread().name}] runBlocking 블록 실행~")
}
```

```shell
[main @coroutine#1] runBlocking 블록 실행~
[DefaultDispatcher-worker-1 @coroutine#2] async-await  블록 실행~
[main @coroutine#1] runBlocking 블록 실행~
```

위 결과를 보면 runBlocking 함수의 block 람다식을 실행하는 코루틴은 각각 _coroutine#1_, _coroutine#2_ 으로 다른 것을 확인할 수 있다.  
async-await 쌍을 사용하면 새로운 코루틴을 만들지만 **`await()` 함수가 호출되어 순차 처리가 되어 동기적으로 실행**된다.

**async-await 쌍과 `withContext()` 모두 결과를 기다린 뒤 다음 코드가 실행되므로 표면적으로는 동기적으로 보이지만 내부 동작과 목적은 완전히 다르다**.  
- **`withCotext()` 의 동기적 실행**
  - 새로운 코루틴을 생성하지 않음
  - 현재 코루틴을 유지한 채, 실행 컨텍스트(Dispatchers.IO) 만 변경함
  - block 실행이 끝날 때까지 코루틴이 일시 중단(suspend) 되며, 결과를 기다린 뒤 이어서 다음 코드 실행
  - 따라서 실행 흐름이 순차적이고 동기적으로 보임
  - 즉, **컨텍스트만 전환된 동일한 코루틴의 흐름**임
- **async-await 의 동기적 실행**
  - async { ... } 는 새로운 코루틴을 생성함
  - `await()` 를 호출해야 해당 작업의 결과를 사용할 수 있으며, 이 또한 suspend 함수이므로 결과를 기다리며 일시 중단됨
  - `await()` 를 호출한 시점부터는 마찬가지로 순차 처리처럼 보임
  - 즉, **새로운 코루틴으로 분기했다가 await 시점에서 합류**

`withContext()` 는 진짜 같은 코루틴에서 Dispatcher 만 바꾸는 것이고, async 는 새로운 코루틴을 만들어 병렬 처리할 수 있는 기반을 만드는 것이다.  
따라서 **`withContext()` 는 구조적 동시성 안에서 스레드만 전환하는 동기적 실행**이고, **async-await 는 병렬성을 만들 수 있지만 `await()` 에 의해 순차 흐름처럼 
보이는 비동기 실행**이다.  
즉, 둘 다 겉보기 흐름이 순차적이라고 해서 내부 동작까지 본다면 `withContext()` 만 동기적이라고 할 수 있다.

아래 그림처럼 coroutine#1 은 유지한 채로 coroutine#2 가 새로 만들어져 실행된다.

![async() 동작](/assets/img/dev/2024/1110/async_await.png)

---

### 4.2.2. `withContext()` 의 코루틴

```kotlin
package chap05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

fun main() = runBlocking<Unit >{
    println("[${Thread.currentThread().name}] runBlocking 블록 실행~")

    withContext(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] withContext 블록 실행~")
    }

    println("[${Thread.currentThread().name}] runBlocking 블록 실행~")
}
```

```shell
[main @coroutine#1] runBlocking 블록 실행~
[DefaultDispatcher-worker-1 @coroutine#1] withContext 블록 실행~
[main @coroutine#1] runBlocking 블록 실행~
```

위 결과를 보면 runBlocking 함수의 block 람다식을 실행하는 코루틴이 모두 _coroutine#1_ 으로 같은 것을 볼 수 있다.  
즉, `withContext()` 함수는 새로운 코루틴을 만드는 대신 기존의 코루틴에서 CoroutineContext 객체만 바꿔서 실행한다.  
위 코드에서는 CoroutineContext 객체가 Main 에서 Dispatchers.IO 로 바뀌었기 때문에 백그라운드 스레드(DefaultDispatcher-worker-1)에서 실행된다.  
(Dispatcher 가 다르면 스레드가 바뀔 가능성이 있는 것이고, Dispatcher 가 같거나 내부 스레드풀이 동일 ㅅ레드를 재상용하는 경우엔 스레드가 안 바뀔 수도 있음)
`withContext()` 함수가 block 람다식을 벗어나면 원래의 CoroutineContext 객체를 사용하여 실행된다. (위 코드에서는 다시 main 스레드를 사용하는 것을 볼 수 있음)

`withContext()` 함수가 호출되면 코루틴의 실행 환경이 `withContext()` 함수의 context 인자값으로 변경되어 실행되며, 이를 **컨텍스트 스위칭**이라고 한다.  
만일 context 인자로 CoroutineDispatcher 객체가 넘어오면 코루틴은 해당 CoroutineDispatcher 객체를 사용해 다시 실행된다.  
따라서 위 코드에서 `withContext(Dispatchers.IO)` 가 호출되면 해당 코루틴은 다시 Dispatchers.IO 의 작업 대기열로 이동한 후 Dispatchers.IO 가 사용할 수 있는 
스레드 중 하나로 보내져서 실행된다.

![withContext() 동작](/assets/img/dev/2024/1110/withContext.png)

즉, **`withContext()` 함수는 함수의 block 람다식이 실행되는 동안 코루틴의 실행 환경을 변경**시킨다.

> CoroutineContext 객체에 대한 설명은 추후 다룰 예정입니다. (p. 165)

---

## 4.3. `withContext()` 주의점

`withContext()` 는 새로운 코루틴을 만들지 않기 때문에 하나의 코루틴 안에서 `withContext()` 함수를 여러 번 호출하면 순차적으로 실행된다.  
즉, 복수의 독립적인 작업이 병렬로 실행되어야 하는 상황에 `withContext()` 를 사용할 경우 성능에 문제를 일으킬 수 있다.

따라서 복수의 독립적인 작업을 동시에 실행하고 싶다면 `withContext()` 가 아닌 `async()` 를 사용해야 한다.

```kotlin
val a = async(Dispatchers.IO) { taskA() }
val b = async(Dispatchers.IO) { taskB() }

val resultA = a.await()
val resultB = b.await()
```

위 코드에서 두 작업은 각각 새로운 코루틴으로 분기되기 때문에 두 작업이 병렬로 실행된다.

아래는 실무에서 할 수 있는 흔한 실수 중 하나이다.

```kotlin
val users = listOf("user1", "user2", "user3")

users.forEach { user ->
    withContext(Dispatchers.IO) {
        loadProfile(user) // 순차 실행됨
    }
}
```

위 코드는 각 작업이 순차 실행되어 전체 실행 시간이 느려질 수 있다.  
이럴 땐 async 를 조합해서 병렬 처리를 하는 것이 좋다.

```kotlin
val deferreds = users.map { user ->
    async(Dispatchers.IO) {
        loadProfile(user)
    }
}
val results = deferreds.awaitAll()
```

아래 병렬로 실행해야 하는 작업에 `withContext()` 를 사용한 코드를 보자.
```kotlin
package chap05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()

    val hello:String = withContext(context = Dispatchers.IO) {
        delay(1000L)
        return@withContext "hello"
    }

    val world: String = withContext(context = Dispatchers.IO) {
        delay(1000L)
        return@withContext "world"
    }

    println("[${getElapsedTime(startTime)}] ${hello} ${world}")
}
```

```shell
[지난 시간: 2017ms] hello world
```

위 코드는 `withContext()` 가 새로운 생성하지 않기 때문에(= runBlocking 함수에 의한 하나의 코루틴만 있음) 순차적으로 처리되어 총 2초의 시간이 걸리게 된다.

이 문제를 해결하기 위해서는 `withContext()` 를 async-await 쌍으로 대체하고, `Deferred` 객체에 대한 `await()` 함수 호출을 모든 코루틴이 실행된 뒤에 하도록 변경하면 된다.

```kotlin
package chap05

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()

    val hello: Deferred<String> = async(context = Dispatchers.IO) {
        delay(1000L)
        return@async "hello"
    }

    val world: Deferred<String> = async(context = Dispatchers.IO) {
        delay(1000L)
        return@async "world"
    }

    val result = awaitAll(hello, world
    )
    println("[${getElapsedTime(startTime)}] ${result[0]} ${result[1]}")
}
```

```shell
[지난 시간: 1012ms] hello world
```

위 코드에서 코루틴은 총 3개가 사용된다. (runBlocking 코루틴, hello 코루틴, world 코루틴)

---

## 4.4. `withContext()` 를 사용한 코루틴 스레드 전환

`withContext()` 를 사용하여 코루틴의 스레드를 전환할 수도 있다.

```kotlin
package chap05

import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

private val dispatcher1 = newSingleThreadContext("myThread1")
private val dispatcher2 = newSingleThreadContext("myThread2")

fun main() = runBlocking<Unit> {
    println("[${Thread.currentThread().name}] 코루틴 실행~")

    withContext(context = dispatcher1) {
        println("[${Thread.currentThread().name}] dispatcher1 코루틴 실행~")
        withContext(context = dispatcher2) {
            println("[${Thread.currentThread().name}] dispatcher2 코루틴 실행~")
        }
        println("[${Thread.currentThread().name}] dispatcher1 코루틴 실행~")
    }
    println("[${Thread.currentThread().name}] 코루틴 실행~")
}
```

위 코드는 _myThread1_ 스레드를 사용하는 CoroutineDispatcher 객체인 _dispatcher1_ 과 _myThread2_ 스레드를 사용하는 CoroutineDispatcher 객체인 _dispatcher2_ 가 있다.  
main 함수에서는 runBlocking() 함수를 호출하여 runBlocking 코루틴을 생성하고 다른 코루틴은 생성하지 않으며, withContext(dispatcher1) 과 withContext(dispatcher2) 를 
사용하여 runBlocking 코루틴의 실행 스레드를 전환한다.

```shell
[main @coroutine#1] 코루틴 실행~
[myThread1 @coroutine#1] dispatcher1 코루틴 실행~
[myThread2 @coroutine#1] dispatcher2 코루틴 실행~
[myThread1 @coroutine#1] dispatcher1 코루틴 실행~
[main @coroutine#1] 코루틴 실행~
```

모든 코루틴이 runBlocking 코루틴(coroutine#1) 인데 스레드가 메인 스레드에서 myThread1, myThread2 로 전환되고 다시 메인 스렐드로 돌아온다.  
이렇게 `withContext()` 함수를 CoroutineDispatcher 객체와 함께 사용하면 코루틴이 자유롭게 스레드를 전환할 수 있다.  
좀 더 정확히 말하면 코루틴이 실행되는데 사용하는 CoroutineDispatcher 객체를 자유롭게 변경할 수 있다.

---

# 정리하며..

- `async()` 함수를 사용하여 코루틴을 실행하면 코루틴의 결과를 감싸는 `Deferred` 객체를 반환받음
- `Deferred` 는 `Job` 의 서브타입으로 `Job` 객체에 결과값을 감싸는 기능이 추가된 객체임
- `Deferred` 객체에 대해 `await()` 함수를 호출하면 결과값을 반환받을 수 있음
  - `await()` 함수를 호출한 코루틴은 `Deferred` 객체가 결과값을 반환할 때까지 일시 중단 후 대기함
- `awaitAll()` 함수로 복수의 `Deferred` 코루틴이 결과값을 반환할 때까지 대기할 수 있음
  - `awaitAll()` 은 컬렉션에 대한 확장 함수로도 제공됨
- `withContext()` 함수는 async-await 쌍을 대체할 수 있음
- `withContext()` 함수는 코루틴을 새로 생성하지 않음
  - 코루틴의 실행 환경을 담는 CoroutineContext 만 변경하여 코루틴을 실행하므로 이를 활용하여 코루틴이 실행되는 스레드를 변경할 수 있음
  - 코루틴을 새로 생성하지 않으므로 병렬로 실행되어야 하는 복수의 작업을 `withContext()` 로 실행하면 순차적으로 실행됨
  - 이 때는 `withContext()` 대신 `async()` 를 사용하여 작업이 병렬로 실행될 수 있도록 해야함
- `withContext()` 로 인해 실행 환경이 변경되어 실행되는 코루틴은 `withContext()` 작업을 모두 실행하면 다시 이전의 실행 환경으로 돌아옴

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)