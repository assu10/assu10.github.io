---
layout: post
title:  "Coroutine - 일시 중단 함수"
date: 2025-06-07
categories: dev
tags: kotlin coroutine suspend coroutine-scope supervisor-scope
---

일시 중단 함수(suspending function) 의 개념과 사용 시 주의점, 특히 코루틴 실행과 호출 위치에 대해 상세히 정리해본다.  
일시 중단 함수는 비동기 코드와 구조화를 동시에 다루기 위한 필수 개념이다.  
CoroutineScope 를 사용하는 방식에 따라 코루틴의 예외 처리, 취소 처리, 구조화된 흐름이 결정되므로 반드시 주의가 필요하다.

- 일시 중단 함수의 개념
- 일시 중단 함수 사용법
- 일시 중단 함수에서 코루틴을 실행하는 법
- 일시 중단 함수의 호출 지점

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap09) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 일시 중단 함수(`suspend`)와 코루틴](#1-일시-중단-함수suspend와-코루틴)
  * [1.1. 일시 중단 함수를 별도의 코루틴 상에서 실행](#11-일시-중단-함수를-별도의-코루틴-상에서-실행)
* [2. 일시 중단 함수의 사용](#2-일시-중단-함수의-사용)
  * [2.1. 일시 중단 함수의 호출 가능 지점](#21-일시-중단-함수의-호출-가능-지점)
    * [2.1.1. 코루틴 내부에서 일시 중단 함수 호출](#211-코루틴-내부에서-일시-중단-함수-호출)
    * [2.1.2. 일시 중단 함수에서 다른 일시 중단 함수 호출](#212-일시-중단-함수에서-다른-일시-중단-함수-호출)
  * [2.2. 일시 중단 함수에서 코루틴 실행](#22-일시-중단-함수에서-코루틴-실행)
    * [2.2.1. 일시 중단 함수에서 코루틴 빌더 호출 시 생기는 문제](#221-일시-중단-함수에서-코루틴-빌더-호출-시-생기는-문제)
    * [2.2.2. `coroutineScope()` 를 사용해 일시 중단 함수에서 코루틴 실행](#222-coroutinescope-를-사용해-일시-중단-함수에서-코루틴-실행)
    * [2.2.3. `supervisorScope()` 를 사용해 일시 중단 함수에서 코루틴 실행](#223-supervisorscope-를-사용해-일시-중단-함수에서-코루틴-실행)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 일시 중단 함수(`suspend`)와 코루틴

코툴린에서 `suspend` 키워드로 선언된 함수는 일시 중단(suspending) 함수라고 한다.  
이 함수는 코루틴 내에서만 호출 가능하며, 내부에 `delay()`, [`withContext()`](https://assu10.github.io/dev/2024/11/10/coroutine-async-and-deferred/#4-withcontext), [`yield()`](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#52-yield-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%B7%A8%EC%86%8C-%ED%99%95%EC%9D%B8) 등 일시 중단 가능한 함수를 포함할 수 있다.

<**일반 함수와의 차이점**>
- 일반 함수는 호출되면 즉시 실행되며, **일시 중단 지점을 가질 수 없다.**
- 일시 중단 함수는 중단과 재개가 가능한 함수이며, **코루틴 실행 컨텍스트에서만 동작**한다.

일반 코드 예시
```kotlin
package chap09

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    delay(1000L)
    println("Hello world!")
  
    delay(1000L)
    println("Hello world!")
}
```

- 동일한 delay + print 블록이 반복됨
- 하지만 delay() 는 일시 중단 함수이기 때문에 일반 함수로 묶을 수 없음

일시 중단 함수로 추출한 예시
```kotlin
package chap09

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    delayAndPrint()
    delayAndPrint()
}

suspend fun delayAndPrint() {
    delay(1000L)
  println("[${Thread.currentThread().name}] Hello world!")
}
```

```shell
[main @coroutine#1] Hello world!
[main @coroutine#1] Hello world!

Process finished with exit code 0
```

- `suspend fun` 으로 정의된 함수는 **중복된 비동기 코드 블록을 재사용 가능**하게 만들어준다.
- 내부에 **일시 중단 지점을 포함**할 수 있다.
- 일반 함수와 목적은 같지만, 실행 맥락이 다르다.
  - 일반 함수는 어디서나 호출 가능하지만, 일시 중단 함수는 **코루틴 내에서만 호출 가능**하다.

---

많은 개발자들이 코루틴을 처음 접할 때 하는 실수 중 하나는 'suspend 함수는 코루틴이다.' 라고 오해하는 것이다.  
하지만 **일시 중단 함수는 코루틴이 아니다.**  
정확히는, **코루틴 내부에서 실행되는 '중단 가능한 코드 블록'일 뿐**, 그것 자체가 코루틴을 생성하거나 독립 실행되지는 않는다.


```kotlin
package chap09

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val startTime = System.currentTimeMillis()
  delayAndPrint()
  delayAndPrint()
  println(getElapsedTime(startTime))
}

suspend fun delayAndPrint() {
  delay(1000L)
  println("[${Thread.currentThread().name}] Hello world!")
}

fun getElapsedTime(startTime: Long): String {
  return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

- 위 코드에서 **생성된 코루틴은 runBlocking 이 만든 코루틴 단 하나**이다.
- 그 안에서 호출된 delayAndPrint() 함수는 **순차적으로 2번 실행된 것일 뿐(실행에 소요시간 2초)**, 별도의 코루틴을 만들지 않는다.
- 즉, suspend fun 은 **중단 가능한 함수일 뿐, 병렬로 실행되거나 백그라운드에서 동작하지 않는다.**

즉, 일시 중단 함수는 코루틴이 아니다.

```shell
[main @coroutine#1] Hello world!
[main @coroutine#1] Hello world!
지난 시간: 2015ms

Process finished with exit code 0
```

---

## 1.1. 일시 중단 함수를 별도의 코루틴 상에서 실행

일시 중단 함수(suspend fun) 은 **일반 함수처럼 재사용이 가능한 코드 블록**이다.  
하지만 일시 중단 지점을 포함하고 있기 때문에, **코루틴 안에서만 호출**될 수 있는 특징이 있다.

그렇다면 suspend 함수를 **각기 다른 코루틴에서 병렬로 실행**하고 싶다면 어떻게 해야 할까?  
답은 **코루틴 빌더 함수(`launch()`, `async()` 등) 로 감싸는 것**이다.

suspend 함수를 `launch()` 로 감싸서 병렬 실행하는 예시
```kotlin
package chap09

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    launch {
        delayAndPrint()
    }
    launch {
        delayAndPrint()
    }
    println(getElapsedTime(startTime))
}

suspend fun delayAndPrint() {
    delay(1000L)
    println("Hello world!")
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

- runBlocking 내부에서 `launch()` 를 두 번 호출하면 **두 개의 새로운 자식 코루틴이 생성**됨
- 이 코루틴들은 각각 delay() 를 만나자마자 **일시 중단되고 스레드를 양보**함
- 스레드가 자유로워졌기 때문에, 곧바로 getElapsedTime() 함수가 실행되고, println() 이 호출됨

```shell
지난 시간: 2ms
[main @coroutine#2] Hello world!
[main @coroutine#3] Hello world!

Process finished with exit code 0
```

따라서 실행 결과를 보면 지난 시간이 0초에 가깝운 것을 확인할 수 있다.
이후 1초 정도가 지나서 재개된 코루틴들에 의해 hello world 문자열이 거의 연달아서 두 번 출력된다.

이렇게 각 **일시 중단 함수를 서로 다른 코루틴에서 병렬로 실행되도록 하고 싶다면 코루틴 빌더 함수로 감싸면 된다.**

---

# 2. 일시 중단 함수의 사용

일시 중단 함수는 내부에 일시 중단 지점을 포함할 수 있기 때문에 일시 중단을 할 수 있는 곳에서만 호출할 수 있다.
코틀린에서 일시 중단이 가능한 지점은 두 가지이다.
- 코루틴 내부
- 일시 중단 함수

---

## 2.1. 일시 중단 함수의 호출 가능 지점

### 2.1.1. 코루틴 내부에서 일시 중단 함수 호출

일시 중단 함수는 코루틴의 일시 중단이 가능한 작업을 재사용이 가능한 블록으로 구조화할 수 있도록 만들어진 함수로, 코루틴은 언제든지 일시 중단 함수를 호출할 수 있다.

```kotlin
package chap09

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    // runBlocking 코루틴이 일시 중단 함수 호출
    delayAndPrint(keyword = "Parent Coroutine")
    launch {
        // launch 코루틴이 일시 중단 함수 호출
        delayAndPrint(keyword = "Child Coroutine")
    }
}

suspend fun delayAndPrint(keyword: String) {
    delay(1000L)
    println("[${Thread.currentThread().name}] $keyword")
}
```

각 코루틴이 일시 중단 함수를 정상적으로 실행한 것을 확인할 수 있다.

```shell
[main @coroutine#1] Parent Coroutine
[main @coroutine#2] Child Coroutine

Process finished with exit code 0
```

---

### 2.1.2. 일시 중단 함수에서 다른 일시 중단 함수 호출

일시 중단 함수는 내부에서 또 다른 일시 중단 함수를 호출할 수 있다.

일시 중단 함수 안에서 다른 일시 중단 함수를 순차적으로 호출하는 예시
```kotlin
package chap09

import kotlinx.coroutines.delay

suspend fun searchByKeyword(keyword: String): Array<String> {
    val dbResults = searchFromDB(keyword)
    val serverResults = searchFromServer(keyword)
    return arrayOf(*dbResults, *serverResults)
}

suspend fun searchFromDB(keyword: String): Array<String> {
    delay(1000L)
    return arrayOf("[DB] ${keyword} 1", "[DB] ${keyword} 2")
}

suspend fun searchFromServer(keyword: String): Array<String> {
    delay(1000L)
    return arrayOf("[Server] ${keyword} 1", "[Server] ${keyword} 2")
}
```

- 이 코드는 전체적으로 약 2초의 실행 시간이 소요되며, **두 작업이 순차적으로 실행**된다.

> 스프레드 연산자 `*` 에 대한 설명은 [4.2. 스프레드 연산자: `*`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#42-%EC%8A%A4%ED%94%84%EB%A0%88%EB%93%9C-%EC%97%B0%EC%82%B0%EC%9E%90-) 를 참고하세요.

만일 두 작업을 동시에 병렬로 처리하고 싶다면 아래와 같이 `async()` 를 사용할 수 있다.

```kotlin
suspend fun searchByKeywordParallel(scope: CoroutineScope, keyword: String): Array<String> {
    val dbDeferred = scope.async { searchFromDB(keyword) }
    val serverDeferred = scope.async { searchFromServer(keyword) }
    return arrayOf(*dbDeferred.await(), *serverDeferred.await())
}
```

---

## 2.2. 일시 중단 함수에서 코루틴 실행

### 2.2.1. 일시 중단 함수에서 코루틴 빌더 호출 시 생기는 문제

앞서 작성한 searchByKeyword() 함수는 아래와 같은 구조이다.
- searchFromDB() → 1초 소요
- searchFromServer() → 1초 소요

이 두 함수가 **동시에 실행되지 않고, 하나의 코루틴에서 순차적으로 실행**되기 때문에 총 2초가 소요된다.

그래서 아래와 같이 `async()` 를 사용하여 병렬로 실행(= 서로 다른 코루틴에서 실행)하려고 시도할 수 있다.

```kotlin
suspend fun searchByKeyword2(keyword: String): Array<String> {
    val dbResults = async {
        searchFromDB(keyword)
    }
    val serverResults = async {
        searchFromServer(keyword)
    }
    return arrayOf(*dbResults.await(), *serverResults.await())
}
```

하지만 이 코드는 컴파일 오류가 발생한다.

```shell
Suspension functions can be called only within coroutine body
```

원인은
- `launch()`, `async()` 같은 코루틴 빌더 함수는 [CoroutineScope](https://assu10.github.io/dev/2024/12/14/coroutine-structured-concurrency-2/#1-coroutinescope-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%98%EC%97%AC-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EA%B4%80%EB%A6%AC) 의 확장 함수이다.
- 즉, **CoroutineScope 가 있어야 사용할 수 있는 함수들**이다.
- 하지만 suspend fun 내부에서는 기본적으로 **CoroutineScope 에 접근할 수 없다.**

일시 중단 함수는 코루틴 내부에서 실행되지만, **자체적으로 Scope 를 보유하지는 않는다.**

일시 중단 함수에서 `launch()` 나 `async()` 같은 코루틴 빌더 함수를 호출하기 위해서는 일시 중단 함수 내부에서 CoroutineScope 객체에 접근할 수 있도록 해야 한다.
이제 그 방법에 대해 알아보자.

---

### 2.2.2. `coroutineScope()` 를 사용해 일시 중단 함수에서 코루틴 실행

> `coroutineScope()` 를 사용해 일시 중단 함수에서 코루틴 실행하는 방법은 예외 전파가 제한되지 않는 이슈가 있음  
> 따라서 `supervisorScope` 를 사용해 일시 중단 함수에서 코루틴 실행하는 방법을 사용해야 함
> 
> 아래 내용은 참고만 할 것

suspend fun 내부에서 코루틴을 실행하려면 **`coroutineScope()` 일시 중단 함수를 사용**해야 한다.  
`coroutineScope()` 함수는 구조화된 동시성을 지키는 CoroutineScope 를 생성해주며, **생성된 CoroutineScope 객체는 `coroutineScope()` 의 block 람다식에서 
수신 객체 this 로 접근**할 수 있다. 따라서 **해당 블록 안에서는 `launch()`, `async()` 와 같은 코루틴 빌더 함수를 사용**할 수 있다.

```kotlin
public suspend fun <R> coroutineScope(block: suspend CoroutineScope.() -> R): R
```

즉, `coroutineScope()` 의 블록 내부는 **CoroutineScope 가 this 로 바인딩된 환경이기 때문에 코루틴 빌더 함수가 정상적으로 동작**한다.

`coroutineScope()` 로 일시 중단 함수를 병렬 실행하는 예시
```kotlin
package chap09

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val results = searchByKeyword("하하하")
    println("[${Thread.currentThread().name}] 결과: ${results.toList()}")
    println(getElapsedTime(startTime))
}

suspend fun searchByKeyword(keyword: String): Array<String> = coroutineScope { // this: CoroutineScope
    val dbResultsDeferred: Deferred<Array<String>> = async {
        searchFromDB(keyword)
    }
    val serverResultsDeferred: Deferred<Array<String>> = async {
        searchFromServer(keyword)
    }
    return@coroutineScope arrayOf(*dbResultsDeferred.await(), *serverResultsDeferred.await())
}

suspend fun searchFromDB(keyword: String): Array<String> {
    delay(1000L)
    return arrayOf("[DB] ${keyword} 1", "[DB] ${keyword} 2")
}

suspend fun searchFromServer(keyword: String): Array<String> {
    delay(1000L)
    return arrayOf("[Server] ${keyword} 1", "[Server] ${keyword} 2")
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

- `async()` 코루틴 빌더를 사용하여 searchFromDB() 를 실행하는 코루틴인 dbResultsDeferred 와 searchFromServer() 를 실행하는 코루틴인 serverResultsDeferred 를 생성함
- 이 두 작업은 각각 개별 코루틴에서 병렬 실행됨
- 결과는 `await()` 를 통해 수집되어 하나의 배열로 반환됨

여기서 중요한 것은 searchByKeyword() 일시 중단 함수가 호출되었을 때 코루틴이 어떻게 구조화되는지 아는 것이다.

![coroutineScope 호출 시 코루틴의 구조화](/assets/img/dev/2025/0607/coroutineScope.webp)

- runBlocking → coroutineScope → async 코루틴(DB/서버)
- runBlocking 코루틴에서 searchByKeyword() 일시 중단 함수를 호출하면 내부에서 coroutineScope() 함수를 통해 새로운 Job 객체를 가진 CoroutineScope 객체가 생성되고, 그 자식으로 DB 와 서버로부터 데이터를 가져오는 코루틴이 각각 생성된다.
- **모든 코루틴이 계층적으로 연결되어 있어 부모가 취소되면 자식도 함께 취소**된다.

```shell
[main @coroutine#1] 결과: [[DB] 하하하 1, [DB] 하하하 2, [Server] 하하하 1, [Server] 하하하 2]
지난 시간: 1023ms

Process finished with exit code 0
```

두 비동기 작업이 병렬로 실행(= 서로 다른 코루틴에서 실행)되었기 때문에 전체 실행 시간은 약 1초이다.

---

하지만 여기에는 문제가 하나 있다.
만일 DB 를 조회하는 코루틴에서 예외가 발생하면, 해당 예외는 coroutineScope 를 통해 상위 코루틴으로 전파된다.  
이로 인해 서버를 조회하는 코루틴도 취소된다.  
심지어 일시 중단 함수를 호출한 코루틴까지 예외가 전파되어 호출부의 코루틴까지 모두 취소되어 버린다.

![예외 발생 시 생기는 문제](/assets/img/dev/2025/0607/coroutineScope2.webp)

- 하나의 자식 코루틴에서 예외 발생 시, 다른 자식 코루틴도 함께 취소됨
- runBlocking 까지 예외가 전파되어 호출부 전체가 중단됨

이런 문제를 해결하기 위해 `coroutineScope()` 일시 중단 함수 대신 **자식 간의 실패를 독립적으로 처리할 수 있는 `supervisorScope()`** 일시 중단 함수를 사용해야 한다.

---

### 2.2.3. `supervisorScope()` 를 사용해 일시 중단 함수에서 코루틴 실행

위에서 `coroutineScope()` 일시 중단 함수를 사용하면 자식 코루틴 중 하나에서 예외가 발생할 경우, 다른 자식 코루틴들도 함께 취소되고 예외가 부모 코루틴까지 
전파된다는 문제를 확인했다.

이를 해결하기 위해 코틀린은 [`supervisorScope()`](https://assu10.github.io/dev/2025/05/30/coroutine-exeption-handling-1/#23-supervisorscope-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%98%88%EC%99%B8-%EC%A0%84%ED%8C%8C-%EC%A0%9C%ED%95%9C) 일시 중단 함수를 
제공한다.

`supervisorScope()` 는 `coroutineScope()` 와 거의 동일하지만 내부적으로 Job 대신 [SupervisorJob](https://assu10.github.io/dev/2025/05/30/coroutine-exeption-handling-1/#22-supervisorjob-%EA%B0%9D%EC%B2%B4%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%98%88%EC%99%B8-%EC%A0%84%ED%8C%8C-%EC%A0%9C%ED%95%9C) 을 사용한다.  
그 외엔 `coroutineScope()` 일시 중단 함수와 동일하게 동작한다.  
`supervisorScope()` 는 **자식 코루틴 간 예외 전파를 막고, 구조화된 동시성은 유지할 수 있도록 설계된 스코프**이다.

```kotlin
public suspend fun <R> supervisorScope(block: suspend CoroutineScope.() -> R): R
```

따라서 searchByKeyword() 일시 중단 함수 내부에서 아래처럼 coroutineScope() 를 supervisorScope() 로 변경하면 dbResultsDeferred 나 serverResultsDeferred 에서 
예외가 발생하더라도 부모 코루틴으로 예외가 전파되지 않는다.

Deferred 객체는 await 함수 호출 시 예외를 노출하므로 try-catch 을 통해 예외 발생 시 빈 결과가 반환되도록 한다.

```kotlin
package chap09

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val results = searchByKeyword("하하하")
    println("[${Thread.currentThread().name}] 결과: ${results.toList()}")
    println(getElapsedTime3(startTime))
}

suspend fun searchByKeyword(keyword: String): Array<String> = supervisorScope { // this: CoroutineScope
    val dbResultsDeferred: Deferred<Array<String>> = async {
        throw Exception("dbResultsDeferred 에서 예외 발생")
        searchFromDB(keyword)
    }
    val serverResultsDeferred: Deferred<Array<String>> = async {
        searchFromServer(keyword)
    }

    val dbResults = try {
        dbResultsDeferred.await()
    } catch (e: Exception) {
        arrayOf() // 예외 발생 시 빈 결과 반환
    }

    val serverResults = try {
        serverResultsDeferred.await()
    } catch (e: Exception) {
        arrayOf() // 예외 발생 시 빈 결과 반환
    }

    return@supervisorScope arrayOf(*dbResults, *serverResults)
}

suspend fun searchFromDB(keyword: String): Array<String> {
    delay(1000L)
    return arrayOf("[DB] ${keyword} 1", "[DB] ${keyword} 2")
}

suspend fun searchFromServer(keyword: String): Array<String> {
    delay(1000L)
    return arrayOf("[Server] ${keyword} 1", "[Server] ${keyword} 2")
}

fun getElapsedTime3(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

```shell
[main @coroutine#1] 결과: [[Server] 하하하 1, [Server] 하하하 2]
지난 시간: 1042ms

Process finished with exit code 0
```

- DB 조회는 실패했지만, 서버 조회는 영향을 받지 않고 성공했다.
- 이는 supervisorScope 가 자식 간의 예외 전파를 막았기 때문이다.

dbResultsDeferred 는 부모로 supervisorScope 를 통해 생성되는 SupervisorJob 객체를 가지므로 dbResultsDeferred 에서 발생한 예외는 
부모 코루틴으로 전파되지 않는다.

![일시 중단 함수에서 supervisorScope 사용](/assets/img/dev/2025/0607/supervisorScope.webp)

예외가 발생해도 다른 코루틴이 취소되지 않도록 하려면 supervisorScope 를 사용하자.

---

# 정리하며..

- 일시 중단 함수는 일시 중단 지점이 포함된 코드를 **재사용 가능한 단위로 추출**하는데 사용된다.
- suspend fun 은 **코루틴이 아니라**, 코루틴 안에서 실행되는 **중단 가능한 코드 블록**일 뿐이다.
- suspend fun 은 반드시 **코루틴이나 다른 일시 중단 함수 내부에서만 호출 가능**하다.
- 일시 중단 함수 내부에서 새로운 코루틴을 실행하려면 `coroutineScope()` 를 사용해 **구조화된 CoroutineScope 객체**를 만들어 사용할 수 있다.
  - 이 객체를 통해 `launch()`, `async()` 와 같은 **코루틴 빌더를 호출**할 수 있다.
  - 이를 통해 **여러 비동기 작업을 병렬로 실행**할 수 있다.
- 자식 코루틴 중 하나에서 예외가 발생해도 **다른 자식 코루틴을 취소하지 않으려면**, `coroutineScope()` 가 아닌 `supervisorScope()` 를 사용하면 된다.
  - 내부적으로 SupervisorJob 을 사용하여 **자식 간의 예외 전파를 차단**하면서도 구조화된 동시성을 유지한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)