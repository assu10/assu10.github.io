---
layout: post
title:  "Coroutine - CoroutineDispatcher"
date: 2024-11-03
categories: dev
tags: kotlin coroutine coroutineDispatcher dispatchers.default dispatchers.io dispatchers.main newSingleThreadContext newFixedThreadPoolContext
---

이 포스트에서는 `CoroutineDispatcher` 에 대해 알아본다.  
제한된 디스패처를 만드는 방법과 제한된 디스패처를 사용해서 코루틴을 실행시키는 방법에 대해 알아본다.  
미리 정의된 `CoroutineDispatcher` 에는 어떤 것이 있고, 언제 사용해야하는지에 대해서도 알아본다.

- `CoroutineDispatcher` 객체의 역할
- 제한된 디스패처와 무제한 디스패처의 차이
- 제한된 디스패처 생성
- `CoroutineDispatcher` 로 코루틴 실행
- 코루틴 라이브러리에 미리 정의된 디스패처의 종류와 사용처

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap03) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `CoroutineDispatcher` 란?](#1-coroutinedispatcher-란)
* [2. 제한된 디스패처(Confined Dispatcher)와 무제한 디스패처(Unconfined Dispatcher)](#2-제한된-디스패처confined-dispatcher와-무제한-디스패처unconfined-dispatcher)
* [3. 제한된 디스패처 생성](#3-제한된-디스패처-생성)
  * [3.1. 단일 스레드 디스패처 생성: `newSingleThreadContext()`](#31-단일-스레드-디스패처-생성-newsinglethreadcontext)
  * [3.2. 멀티 스레드 디스패처 생성: `newFixedThreadPoolContext()`](#32-멀티-스레드-디스패처-생성-newfixedthreadpoolcontext)
* [4. `CoroutineDispatcher` 로 코루틴 실행](#4-coroutinedispatcher-로-코루틴-실행)
  * [4.1. `launch()` 의 파라미터로 `CoroutineDispatcher` 사용](#41-launch-의-파라미터로-coroutinedispatcher-사용)
    * [4.1.1. 단일 스레드 디스패처로 코루틴 실행](#411-단일-스레드-디스패처로-코루틴-실행)
    * [4.1.2. 멀티 스레드 디스패처로 코루틴 실행](#412-멀티-스레드-디스패처로-코루틴-실행)
  * [4.2. 부모 코루틴의 `CoroutineDispatcher` 로 자식 코루틴 실행](#42-부모-코루틴의-coroutinedispatcher-로-자식-코루틴-실행)
* [5. 미리 정의된 `CoroutineDispatcher`](#5-미리-정의된-coroutinedispatcher)
  * [5.1. `Dispatchers.IO`](#51-dispatchersio)
  * [5.2. `Dispatchers.Default`](#52-dispatchersdefault)
  * [5.3. `limitedParallelism()` 으로 `Dispatchers.Default` 스레드 사용 제한](#53-limitedparallelism-으로-dispatchersdefault-스레드-사용-제한)
  * [5.4. 공유 스레드풀을 사용하는 `Dispatchers.IO` 와 `Dispatchers.Default`](#54-공유-스레드풀을-사용하는-dispatchersio-와-dispatchersdefault)
  * [5.5. `Dispatchers.Main`](#55-dispatchersmain)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

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

# 1. `CoroutineDispatcher` 란?

dispatcher 는 '무언가는 보내는 주체'라는 뜻이다.  
따라서 `CoroutineDispatcher` 는 코루틴을 보내는 주체이다.

`CoroutineDispatcher` 객체는 코루틴을 스레드로 보낸다.  
코루틴은 일시 중단이 가능한 ‘작업’이며, 반드시 스레드 위에서 실행되어야 한다.  
`CoroutineDispatcher` 는 이러한 코루틴을 어떤 스레드나 스레드 풀에서 실행할지를 결정해주는 역할을 한다.
`CoroutineDispatcher` 는 코루틴을 스레드로 보내는 데 사용할 수 있는 스레드나 스레드풀을 가지며, 코루틴을 실행 요청한 스레드에서 코루틴이 실행되도록 한다.

> 코루틴 자체는 스레드가 아니며, 경량 스레드처럼 동작하는 작업 단위임  
> 코루틴은 스레드 위에서 실행되며, 필요에 따라 일시 중단(suspend) 되었다가, 다시 재개(resume) 됨  
> 이 때 **어떤 스레드에서 실행시킬지를 지정해주는 역할을 하는 것이 `CoroutineDispatcher`** 임

코루틴을 실행시키는 데 2개의 스레드로 구성된 스레드풀을 사용할 수 있는 `CoroutineDispatcher` 객체가 있고, 2개의 스레드 중 하나의 스레드에서 이미 _coroutine1_ 이 
실행중이라고 하자.

![CoroutineDispatcher](/assets/img/dev/2024/1103/coroutine.png)

`CoroutineDispatcher` 객체는 실행되어야 하는 작업을 저장하는 작업 대기열을 가지고 있으며, `CoroutineDispatcher` 객체에 _coroutine2_ 코루틴 실행 요청이 
들어오면 `CoroutineDispatcher` 객체는 실행 요청을 받은 코루틴을 작업 대기열에 먼저 적재한다.  
이후 사용할 수 있는 스레드가 있으면 해당 코루틴을 사용할 수 있는 스레드로 보내 실행시킨다.  
위 그림에서는 _Thread-2_ 로 _coroutine2_ 를 보내 실행시킨다.

만일 이 때 _coroutine3_ 코루틴이 추가로 실행 요청이 들어오면 작업 대기열에 적재되어 있다가 사용할 수 있는 스레드가 생기면 그 때 해당 스레드로 보내진다.  
즉, _coroutine3_ 코루틴이 스레드로 보내지는 시점은 스레드풀의 스레드 중 하나가 자유로워졌을 때이다.

**`CoroutineDispatcher` 객체는 코루틴의 실행을 관리하는 주체로, 자신에게 실행 요청된 코루틴을 먼저 작업 대기열에 적재한 후, 사용할 수 있는 스레드가 생기면 그 때 스레드로 보내는 방식**으로 동작한다.

> 코루틴의 실행 옵션에 따라 작업 대기열에 적재되지 않고 즉시 실행될 수도 있고, 작업 대기열이 없는 `CoroutineDispatcher` 구현체도 있음  
> 이에 대한 상세한 내용은 추후 다룰 예정입니다. (p. 90)

---

# 2. 제한된 디스패처(Confined Dispatcher)와 무제한 디스패처(Unconfined Dispatcher)

`CoroutineDispatcher` 는 2가지 종류가 있다.

- **제한된 디스패처**
  - 사용할 수 있는 스레드나 스레드풀이 제한된 디스패처
- **무제한 디스패처**
  - 사용할 수 있는 스레드나 스레드풀이 제한되지 않은 디스패처

아래 그림처럼 제한된 디스패처는 사용할 수 있는 스레드가 제한적이다.

![제한된 디스패처](/assets/img/dev/2024/1103/coroutine.png)

일반적으로 `CoroutineDispatcher` 객체별로 어떤 작업을 처리할 지 미리 역할을 부여하고 그에 맞춰 실행을 요청하는 것이 효율적이기 때문에 운영에 
사용하는 `CoroutineDispatcher` 객체는 대부분 제한된 디스패처이다.

실행할 수 있는 스레드가 제한되지 않았다고 해서 실행 요청된 코루틴이 아무 스레드에서나 실행되는 것은 아니다.  
무제한 디스패처는 실행 요청된 코루틴이 **재개를 호출한 시점의 그 스레드**에서 계속해서 실행되도록 한다.  
이 때문에 실행되는 스레드가 매번 달라질 수 있고, 특정 스레드로 제한되어 있지 않아 무제한 디스패처라는 이름을 갖게 되었다.

즉,  (= delay 이후 resume 할 때 )

<**일시 중단 후 재개 시 실행되는 스레드 차이**>
- **제한된 디스패처**
  - 제한된 디스패처는 항상 자신이 관리하는 스레드풀로 강제 스케쥴링 함
    - 예) delay 이후 resume 할 때 Default 디스패처가 선택한 스레드에서 반드시 재개됨  
    **resume 이 어떤 스레드에서 호출되든 상관없이** 본인의 스레드풀로 다시 디스패치함
  - **resume → Default 디스패처가 받음 → 자기 스레드풀로 넘김 (= 디스패처가 스레드 선택)**
- **무제한 디스패처**
  - **디스패처에서 디스패치하지 않고, resume 을 호출한 스레드에서 바로 이어서 실행함**
    - 예) resume 이 호출되면 그냥 그 자리에서 바로 재개함  
    즉, **dispatcher dispatch 호출조차 하지 않음**
  - **resume → 그 스레드에서 바로 재개**


| 항목                        | 제한된 디스패처                                   | 무제한 디스패처                            |
|:--------------------------|:-------------------------------------------|:------------------------------------|
| resume 호출한 스레드와 재개 실행 스레드 | 다를 수 있음<br />(디정된 디스패처의 스레드 또는 스레드풀에서 재개됨) | 같음<br />(재개를 트리거한 호출 스레드에서 그대로 재개됨) |
| 디스패처가 디스패치 과정 개입?         | O                                          | X                                   |
| 특정 스레드풀 제어                | 있음                                         | 없음                                  |
| 예측 가능성                    | 높음<br />디스패처가 관리하는 스레드 중 하나에서만 실행됨         | 낮음<br />누가 resume 을 호출했는지에 따라 달라짐   |
| 안전성                       | 높음                                         | 낮음                                  |

> 어떤 경우에 무제한 디스패처를 사용하는지에 대해서는 추후 다룰 예정입니다. (p. 91)

---

# 3. 제한된 디스패처 생성

코루틴 라이브러리는 사용자가 직접 제한된 디스패처를 만들 수 있도록 함수를 제공한다.

---

## 3.1. 단일 스레드 디스패처 생성: `newSingleThreadContext()`

단일 스레드 디스패처는 사용할 수 있는 스레드가 하나인 `CoroutineDispatcher` 객체이며, `newSingleThreadContext()` 를 통해 만들 수 있다.  
인자로 받은 name 은 디스패처에서 관리하는 이름이 되며, 반환 타입은 `CoroutineDispatcher` 이다.

```kotlin
package chap03

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.newSingleThreadContext

val dispatcher: CoroutineDispatcher = newSingleThreadContext(name = "Single~")
```

![단일 스레드 디스패처](/assets/img/dev/2024/1103/single.png)

---

## 3.2. 멀티 스레드 디스패처 생성: `newFixedThreadPoolContext()`

멀티 스레드 디스패처는 사용할 수 있는 스레드가 2개 이상인 `CoroutineDispatcher` 객체이며, `newFixedThreadPoolContext()` 를 통해 만들 수 있다.

```kotlin
package chap03

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.newFixedThreadPoolContext

val multiThreadDispatcher: CoroutineDispatcher = newFixedThreadPoolContext(
    nThreads = 2,
    name = "multiThread",
)
```

![멀티 스레드 디스패처](/assets/img/dev/2024/1103/multi.png)

`newSingleThreadContext()` 는 내부적으로 `newFixedThreadPoolContext()` 을 사용하도록 구현되어 있다.  
즉, 두 함수는 같은 함수라고 봐도 무방하다.

`newSingleThreadContext()` 함수 구현체

```kotlin
public fun newSingleThreadContext(name: String): CloseableCoroutineDispatcher =
    newFixedThreadPoolContext(1, name)
```

---

# 4. `CoroutineDispatcher` 로 코루틴 실행

여기서는 `CoroutineDispatcher` 객체에 코루틴을 실행 요청하는 방법에 대해 알아본다.

---

## 4.1. `launch()` 의 파라미터로 `CoroutineDispatcher` 사용

### 4.1.1. 단일 스레드 디스패처로 코루틴 실행

`launch()` 함수를 호출하여 만든 코루틴을 `CoroutineDispatcher` 객체로 실행 요청하기 위해서는 `launch()` 함수의 context 인자로 `CoroutineDispatcher` 
객체를 넘기면 된다.

```kotlin
package chap03

import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val singleDispatcher = newSingleThreadContext(name = "Single~")
    launch(context = singleDispatcher) {
        println("[${Thread.currentThread().name}] 실행")
    }
}
```

```shell
[Single~ @coroutine#2] 실행
```

새로운 스레드의 이름을 _Single~_ 로 설정했기 때문에 `launch()` 를 통해 생성된 코루틴이 실행되는 스레드가 _Single~_ 로 출력되는 것을 확인할 수 있다.

> 코루틴 이름을 출력하는 법은 [2. 코루틴 디버깅 환경 설정](https://assu10.github.io/dev/2024/11/02/coroutine-setup/#2-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EB%94%94%EB%B2%84%EA%B9%85-%ED%99%98%EA%B2%BD-%EC%84%A4%EC%A0%95) 을 참고하세요.

---

### 4.1.2. 멀티 스레드 디스패처로 코루틴 실행

멀티 스레드 디스패처로 코루틴을 실행하는 방법은 단일 스레드 디스패처로 코루틴을 실행하는 방법과 동일하며, `launch()` 함수의 context 인자로 멀티 스레드 디스패처 객체를 넘기면 된다.

아래는 코루틴 3개가 멀티 스레드 디스패처로 실행 요청되며, 각 코루틴은 스레드명을 출력한 후 실행 완료되는 예시이다.

```kotlin
package chap03

import kotlinx.coroutines.launch
import kotlinx.coroutines.newFixedThreadPoolContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val testMultiThreadDispatcher = newFixedThreadPoolContext(
    nThreads = 2,
    name = "TestMultiThreadDispatcher",
  )
  launch(context = testMultiThreadDispatcher) {
    println("[${Thread.currentThread().name}] 실행")
  }
  launch(context = testMultiThreadDispatcher) {
    println("[${Thread.currentThread().name}] 실행")
  }
  launch(context = testMultiThreadDispatcher) {
    println("[${Thread.currentThread().name}] 실행")
  }
}
```

```shell
[TestMultiThreadDispatcher-2 @coroutine#3] 실행
[TestMultiThreadDispatcher-1 @coroutine#2] 실행
[TestMultiThreadDispatcher-2 @coroutine#4] 실행
```

---

## 4.2. 부모 코루틴의 `CoroutineDispatcher` 로 자식 코루틴 실행

코루틴은 구조화를 통해 코루틴 내부에서 새로운 코루틴을 생성할 수 있으며, 자식 코루틴에 `CoroutineDispatcher` 객체가 설정되어 있지 않으면 부모 코루틴의 
`CoroutineDispatcher` 객체를 사용할 수 있다.

```kotlin
package chap03

import kotlinx.coroutines.launch
import kotlinx.coroutines.newFixedThreadPoolContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val testMultiThreadDispatcher = newFixedThreadPoolContext(
    nThreads = 2,
    name = "testMultiThread",
  )
  launch(context = testMultiThreadDispatcher) { // 부모 코루틴
    println("[${Thread.currentThread().name}] 부모 코루틴 실행-0")
    launch { // 자식 코루틴 실행
      println("[${Thread.currentThread().name}] 부모 코루틴 실행-1")
      println("[${Thread.currentThread().name}] 자식 코루틴 실행-1")
      println("[${Thread.currentThread().name}] 자식 코루틴 실행-1")
    }
    launch { // 자식 코루틴 실행
      println("[${Thread.currentThread().name}] 자식 코루틴 실행-2")
    }
  }
}
```

위 코드에서 부모 코루틴은 전용 스레드가 2개인 _testMultiThreadDispatcher_ 를 사용한다.  
이 부모 코루틴의 `launch()` 함수 람다식 내부에서 다시 2개의 `launch()` 함수가 호출되어 2개의 자식 코루틴이 추가로 생성되고, 이 자식 코루틴들에는 별도로 
`CoroutineDispatcher` 객체가 설정되어 있지 않아 자동으로 부모 코루틴에 설정된 `CoroutineDispatcher` 객체를 사용한다.  
아래 결과를 보면 부모 코루틴과 자식 코루틴 모두 같은 `CoroutineDispatcher` 인 _testMultiThread-1, 2_ 를 공용으로 사용하는 것을 확인할 수 있다.

```shell
[testMultiThread-1 @coroutine#2] 부모 코루틴 실행-0
[testMultiThread-2 @coroutine#3] 부모 코루틴 실행-1
[testMultiThread-2 @coroutine#3] 자식 코루틴 실행-1
[testMultiThread-1 @coroutine#4] 자식 코루틴 실행-2
[testMultiThread-2 @coroutine#3] 자식 코루틴 실행-1
```

---

# 5. 미리 정의된 `CoroutineDispatcher`

`newFixedThreadPoolContext()` 함수로 `CoroutineDispatcher` 객체를 생성하면 아래와 같은 경고가 뜬다.

> This is a delicate API and its use requires care. Make sure you fully read and understand documentation of the declaration that is marked as a delicate API.
> 
> _이는 섬세하게 다뤄져야 하는 API 이다. 섬세하게 다뤄져야 하는 API 는 문서를 모두 읽고 제대로 이해한 후 사용해야 한다._


이러한 경고를 하는 이유는 **사용자가 `newFixedThreadPoolContext()` 함수를 통해 `CoroutineDispatcher` 객체를 만드는 것이 비효율적일 가능성이 높기 때문**이다.  
`newFixedThreadPoolContext()` 함수로 `CoroutineDispatcher` 객체를 생성하게 되면 특정 `CoroutineDispatcher` 객체에서만 사용되는 스레드풀이 생성되며, 
스레드풀에 속한 스레드 수가 너무 적거나 많아서 비효율적으로 동작할 수 있다.  
또한 여러 명이 개발할 경우 특정 용도를 위해 만들어진 `CoroutineDispatcher` 객체가 이미 메모리상에 있음에도 불구하고 이 존재를 몰라 다시 `CoroutineDispatcher` 객체를 
만들어서 리소스를 낭비하게 될 수도 있다.  
스레드의 생성 비용은 비싸기 때문에 이는 매우 비효율적이다.

코루틴 라이브러리는 이러한 문제를 방지하기 위해 미리 정의된 `CoroutineDispatcher` 목록을 제공한다.

- **`Dispatchers.IO`**
  - 네트워크 요청이나 파일 입출력 등의 입출력 작업을 위한 `CoroutineDispatcher`
- **`Dispatchers.Default`**
  - CPU 를 많이 사용하는 연산 작업을 위한 `CoroutineDispatcher`
- **`Dispatchers.Main`**
  - 메인 스레드를 사용하기 위한 `CoroutineDispatcher`

따라서 **개발자들은 매번 새로운 `CoroutineDispatcher` 객체를 만들 필요없이 제공되는 `CoroutineDispatcher` 객체를 사용하여 코루틴을 실행**하면 된다.

---

## 5.1. `Dispatchers.IO`

멀티 스레드 프로그래밍에 가장 많이 사용되는 작업은 입출력이다.  
예) 네트워크 통신을 위해 HTTP 요청을 함, DB 작업 등과 같은 입출력 작업을 동시에 여러 개 수행

이런 요청을 동시에 수행하기 위해서는 많은 수의 스레드가 필요하며, 이 때 사용되는 `CoroutineDispatcher` 객체가 `Dispatchers.IO` 이다.

코루틴 라이브러리의 `Dispatchers.IO` 가 최대로 사용할 수 있는 스레드의 수는 JVM 에서 사용 가능한 프로세스의 수와 64 중 큰 값으로 설정되어 있다.
이 동작은 시스템 프로퍼티인 `kotlinx.coroutines.io.parallelism` 을 통해 조정 가능하다.

즉, `Dispatchers.IO` 를 사용하면 여러 입출력 작업을 동시에 수행할 수 있다.

`Dispatchers.IO` 는 싱글톤 인스턴스이므로 매번 new IO Dispatcher() 처럼 만들 필요없이, `launch()` 함수의 인자로 곧바로 넘겨서 사용할 수 있다.

- **"`Dispatchers.IO` 는 싱글톤 인스턴스이므로"**  
`Dispatchers.IO` 는 코루틴에서 I/O 작업에 최적화된 `CoroutineDispatcher` 객체이며, **`Dispatchers.IO` 애플리케이션 전체에서 하나만 생성되어 재사용**하게 된다.  
즉, **`Dispatchers.IO` 는 어디서든 동일한 인스턴스를 참조**하게 된다.

```kotlin
val a = Dispatchers.IO
val b = Dispatchers.IO

println(a === b) // true -> 같은 인스턴스
```

- **"`launch()` 함수의 인자로 곧바로 넘겨서 사용할 수 있다."**  

아래는 `launch()` 함수의 시그니처이다.
```kotlin
fun CoroutineScope.launch(
    context: CoroutineContext = EmptyCoroutineContext,
    block: suspend CoroutineScope.() -> Unit
): Job
```

여기서 context 는 `CoroutineContext` 타입이다.  
`Dispatchers.IO` 는 `CoroutineDispatcher` 이지만, `CoroutineDispatcher` 는 `CoroutineContext` 를 구현한 클래스이다.  
즉, `Dispatchers.IO` 는 `CoroutineContext` 처럼 사용할 수 있는 객체이기 때문에 `launch()` 함수에서 `CoroutineContext` 객체가 들어갈 자리에 바로 넣을 수 있다.
(= `Dispatchers.IO` 가 `CoroutineContext` 를 구현해서 launch() 에 넘길 수 있음)

```kotlin
public abstract class CoroutineDispatcher : AbstractCoroutineContextElement, ContinuationInterceptor
```

아래 코드를 보자.

```kotlin
package chap03

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#2] 코루틴 실행
```

코루틴이 실행된 스레드명이 _DefaultDispatcher-worker-1_ 인 것을 볼 수 있다.  
이름 앞에 _DefaultDispatcher-worker_ 가 붙은 스레드는 코루틴 라이브러리에서 제공하는 공유 스레드풀에 속한 스레드로, `Dispatchers.IO` 는 공유 스레드풀의 
스레드를 사용할 수 있도록 구현되었기 때문에 _DefaultDispatcher-worker-1_ 스레드에 코루틴이 할당되어 실행된다.

> 공유 스레드풀에 대한 좀 더 상세한 내용은 [5.4. 공유 스레드풀을 사용하는 `Dispatchers.IO` 와 `Dispatchers.Default`](#54-공유-스레드풀을-사용하는-dispatchersio-와-dispatchersdefault) 를 참고하세요.

---

## 5.2. `Dispatchers.Default`

대용량 데이터를 처리해야 하는 작업처럼 CPU 연산이 필요한 작업을 **CPU 바운드 작업**이라고 한다.

`Dispatchers.Default` 는 CPU 바운드 작업이 필요할 때 사용하는 `CoroutineDispatcher` 이며, `Dispatchers.Default` 도 그 자체로 싱글톤 인스턴스이기 때문에 
new Default Dispatcher() 처럼 인스턴스를 만들 필요없이 아래와 같이 바로 사용할 수 있다.

```kotlin
package chap03

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>   {
    launch(context = Dispatchers.Default) {
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#2] 코루틴 실행
```

> **입출력 작업과 CPU 바운드 작업**
> 
> 입출력 작업과 CPU 바운드 작업의 중요한 차이는 작업이 실행되었을 때 스레드를 지속적으로 사용하는지 여부임
> 
> 입출력 작업(네트워크 요청, DB 조회 요청 등) 은 실행한 후 결과를 반환받을 때까지 스레드를 사용하지 않지만, CPU 바운드 작업은 작업을 하는 동안 스레드를 지속적으로 사용함
> 
> 이 차이로 인해 입출력 작업과 CPU 바운드 작업을 스레드 기반으로 실행했을 때와 코루틴을 사용해서 실행했을 때 효율성에서 차이가 생김
> 
> 입출력 작업을 코루틴을 사용하여 실행하면 입출력 작업 실행 후 스레드가 대기하는 동안 해당 스레드에서 다른 입출력 작업을 동시에 실행할 수 있기 때문에 효율적임  
> 반면, CPU 바운드 작업은 코루틴을 사용하여 실행하더라도 스레드가 지속적으로 사용되기 때문에 스레드 기반 작업을 사용해서 실행했을 때와 처리 속도에 큰 차이가 없음
> 
> 즉 입출력 작업은 스레드 기반 작업으로 작업할 때보다 코루틴으로 작업할 때가 효율성이 높고, CPU 바운드 작업은 큰 차이가 없음

---

## 5.3. `limitedParallelism()` 으로 `Dispatchers.Default` 스레드 사용 제한

`Dispatchers.Default` 를 사용해서 무겁고 오래 걸리는 연산을 처리하면 특정 연산을 위해 `Dispatchers.Default` 의 모든 스레드가 사용될 수 있는데, 
그렇게 되면 해당 연산이 모든 스레드를 사용하므로 `Dispatchers.Default` 를 사용하는 다른 연산이 실행되지 못하는 경우가 발생한다.

이를 방지하기 위해 코루틴 라이브러리는 `Dispatchers.Default` 의 일부 스레드만 사용하여 특정 연산을 실행할 수 있는 `limitedParallelism()` 함수를 제공한다.

```kotlin
package chap03

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = Dispatchers.Default.limitedParallelism((2))) {
        repeat(5) {
            launch {
                println("[${Thread.currentThread().name}] 코루틴 실행")
            }
        }
    }
}
```

위 코드는 `limitedParallelism(2)` 를 통해 `Dispatchers.Default` 의 스레드를 2개만 사용해서 5개의 코루틴을 실행시킨다.  
따라서 결과를 보면 _DefaultDispatcher-worker-1_, _DefaultDispatcher-worker-2_ 만 사용된 것을 알 수 있다.

```shell
[DefaultDispatcher-worker-2 @coroutine#3] 코루틴 실행
[DefaultDispatcher-worker-1 @coroutine#4] 코루틴 실행
[DefaultDispatcher-worker-2 @coroutine#6] 코루틴 실행
[DefaultDispatcher-worker-1 @coroutine#5] 코루틴 실행
[DefaultDispatcher-worker-2 @coroutine#7] 코루틴 실행
```

---

## 5.4. 공유 스레드풀을 사용하는 `Dispatchers.IO` 와 `Dispatchers.Default`

`Dispatchers.IO` 와 `Dispatchers.Default` 를 사용한 코드를 보면 코루틴을 실행시킨 스레드명이 _DefaultDispatcher-worker-n_ 이다.  
이는 `Dispatchers.IO` 와 `Dispatchers.Default` 가 같은 스레드풀을 사용한다는 것을 의미한다.  
이 둘은 코루틴 라이브러리의 공유 스레드풀을 사용한다.

코루틴 라이브러리는 스레드의 생성과 관리를 효율적으로 할 수 있도록 애플리케이션 레벨의 공유 스레드풀을 제공하며, 코루틴 라이브러리는 공유 스레드풀에 스레드를 
생성하고 사용할 수 있도록 하는 API 를 제공한다.  
`Dispatchers.IO` 와 `Dispatchers.Default` 모두 이 API 를 사용하여 구현되었기 때문에 같은 스레드풀을 사용하는 것이다.

![공유 스레드풀](/assets/img/dev/2024/1103/shared.png)

`Dispatchers.IO` 와 `Dispatchers.Default` 가 사용하는 스레드는 구분되며, `Dispatchers.Default.limitedParallelism(2)` 는 `Dispatchers.Default` 의 
스레드 중 2개의 스레드만 사용한다.

`newFixedThreadPoolContext()` 로 만들어지는 디스패처는 자신만 사용할 수 있는 전용 스레드풀을 생성하는 것과 다르게 `Dispatchers.IO` 와 `Dispatchers.Default` 
는 공유 스레드풀의 스레드를 사용한다.

`Dispatchers.Default.limitedParallelism()` 가 `Dispatchers.Default` 가 사용할 수 있는 스레드 중 일부를 사용하는 것과는 다르게 
`Dispatchers.IO.limitedParallelism()` 는 공유 스레드풀의 스레드로 구성되는 새로운 스레드풀을 만든다.

`Dispatchers.IO.limitedParallelism()` 는 특정한 작업이 다른 작업에 영향을 받지 않아야 해서 별도 스레드 풀에서 실행되는 것이 필요할 때 사용한다.  
이 함수는 공유 스레드풀에서 새로운 스레드를 만들어내고, 새로운 스레드를 만들어내는 것은 비싼 작업이므로 남용하면 안된다.

---

## 5.5. `Dispatchers.Main`

`Dispatchers.Main` 은 UI 가 있는 애플리케이션에서 메인 스레드의 사용을 위해 사용되는 특별한 `CoroutineDiapatcher` 이기 때문에 코루틴 라이브러리만 추가하면 
사용할 수 있는 `Dispatchers.IO` 와 `Dispatchers.Default` 와 다르게 별도의 라이브러리(예- kotlinx-coroutines-android 등) 을 추가해야 사용할 수 있다.

코틀린 라이브러리만 있는 프로젝트에서 `Dispatchers.Main` 은 참조는 가능하지만 사용하면 오류가 발생한다.

---

# 정리하며..

- `CoutineDispatcher` 객체는 코루틴을 스레드로 보내 실행하는 객체임
  - 코루틴을 작업 대기열에 적재하나 후 사용 가능한 스레드로 보내 실행함
- 제한된 디스패처는 코루틴을 실행하는데 사용할 수 있는 스레드가 특정 스레드나 특정 스레드풀로 제한되지만, 무제한 디스패처는 코루틴을 실행하는데 사용할 수 있는 스레드가 제한되어 있지 않음
- `newSingleThreadContext()` 나 `newFixedThreadPoolContext()` 를 통해 제한된 디스패처 객체 생성이 가능함
- `launch()` 함수를 사용하여 코루틴을 실행할 때 context 인자로 `CoroutineDispatcher` 객체를 넘기면 해당 객체를 사용하여 코루틴이 실행됨
- 자식 코루틴은 기본적으로 부모 코루틴의 `CoroutineDispatcher` 객체를 상속받아 사용함
- 코루틴 라이브러리는 미리 정의된 `CoroutineDispatcher` 객체인 `Dispatchers.IO`, `Dispatchers.Default`, `Dispatchers.Main` 을 제공함
- `Dispatchers.IO` 는 입출력 작업을 위한 `CoroutineDispatcher` 객체로 네트워크 요청이나 파일 I/O 등에 사용됨
- `Dispatchers.Default` 는 CPU 바운드 작업을 위한 `CoroutineDispatcher` 객체로 데용량 데이터 처리 등에 사용됨
- `limitedParallelism()` 을 통해 특정 연산을 위해 사용되는 `Dispatchers.Default` 스레드 수를 제한할 수 있음
- `Dispatchers.IO` 와 `Dispatchers.Default` 는 코루틴 라이브러리에서 제공하는 공유 스레드풀을 사용함
- `Dispatchers.Main` 은 메인 스레드에서 실행되어야 하는 작업을 위한 `CoroutineDispatcher` 객체로 별도의 라이브러리를 추가해야 함
  - 일반적으로 UI 가 있는 애플리케이션에서 UI 업데이트를 위해 사용함

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)