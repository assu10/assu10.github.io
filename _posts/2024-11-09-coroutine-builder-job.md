---
layout: post
title:  "Coroutine - 코루틴 빌더, Job"
date: 2024-11-09
categories: dev
tags: kotlin coroutine
---

이 포스트에서는 코루틴 빌더 함수인 `launch()` 와 `launch()` 호출 시 반환되는 Job 객체에 대해 알아본다.  
코루틴은 일시 중단이 가능하므로 작업 간의 순차 처리가 매우 중요하다.  
Job 객체의 `join()` 함수를 통해 코루틴 간의 순차 처리 방법과 Job 객체를 통해 코루틴의 상태를 조작하고, 상태값을 확인하는 방법에 대해 알아본다.

`runBlocking()` 과 `launch()` 는 코루틴을 생성하는 함수이며, 이런 함수를 **코루틴 빌더 함수**라고 한다.  
코루틴 빌더 함수가 호출되면 새로운 코루틴이 생성되고, 코루틴을 추상화한 Job 객체를 반환한다.  
반환된 Job 객체는 코루틴의 상태를 추적하고 제어하는데 사용된다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val job: Job = launch(context = Dispatchers.Default) { // Job 객체 반환
        // ...
    }
}
```

코루틴은 일시 중단할 수 있는 작업으로, 실행 도중 일시 중단된 후 나중에 다시 이어서 실행될 수 있다.  
코루틴을 추상화한 Job 객체는 이에 대응해서 코루틴을 제어할 수 있는 함수와 코루틴의 상태를 나타내는 상태값들을 노출한다.

여기서는 **Job 객체를 사용해서 코루틴 간 순차 처리하는 방법과 코루틴의 상태 확인 후 조작하는 방법**에 대해 알아본다.
- `join()`, `joinAll()` 함수를 사용한 코루틴 간 순차 처리
- `CoroutineStart.LAZY` 를 사용한 코루틴 지연 시작
- 코루틴 실행 취소
- 코루틴 상태

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `join()` 을 사용한 코루틴 순차 처리](#1-join-을-사용한-코루틴-순차-처리)
  * [1.1. 순차 처리가 안될 경우의 문제](#11-순차-처리가-안될-경우의-문제)
  * [1.2. `join()` 으로 순차 처리](#12-join-으로-순차-처리)
* [2. `joinAll()` 을 사용한 코루틴 순차 처리](#2-joinall-을-사용한-코루틴-순차-처리)
* [3. `CoroutineStart.LAZY` 로 코루틴 지연 시작: `Job.start()`](#3-coroutinestartlazy-로-코루틴-지연-시작-jobstart)
* [4. 코루틴 취소](#4-코루틴-취소)
  * [4.1. `cancel()` 을 사용한 Job 취소](#41-cancel-을-사용한-job-취소)
  * [4.2. `cancelAndJoin()` 을 사용한 순차 처리](#42-cancelandjoin-을-사용한-순차-처리)
* [5. 코루틴 취소 확인](#5-코루틴-취소-확인)
  * [5.1. `delay()` 를 사용한 취소 확인](#51-delay-를-사용한-취소-확인)
  * [5.2. `yield()` 를 사용한 취소 확인](#52-yield-를-사용한-취소-확인)
    * [5.2.1. `delay()` 와 `yield()` 차이점](#521-delay-와-yield-차이점)
  * [5.3. `CoroutineScope.isActive` 를 사용한 취소 확인](#53-coroutinescopeisactive-를-사용한-취소-확인)
* [6. 코루틴의 상태와 Job 의 상태 변수](#6-코루틴의-상태와-job-의-상태-변수)
  * [6.1. 생성(New) 상태의 코루틴](#61-생성new-상태의-코루틴)
  * [6.2. 실행 중(Active) 상태의 코루틴](#62-실행-중active-상태의-코루틴)
  * [6.3. 실행 완료(Completed) 상태의 코루틴](#63-실행-완료completed-상태의-코루틴)
  * [6.4. 취소 중(Cancelling)인 코루틴](#64-취소-중cancelling인-코루틴)
  * [6.5. 취소 완료(Cancelled)된 코루틴](#65-취소-완료cancelled된-코루틴)
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

# 1. `join()` 을 사용한 코루틴 순차 처리

코루틴 간에는 순차 처리가 필요한 경우가 종종 있다.  
예) DB 작업을 순차적으로 처리, 캐싱된 토큰값이 업데이트된 이후에 네트워크 요청

Job 객체는 순차 처리가 필요한 상황을 위해 `join()` 을 제공하여 먼저 처리되어야 하는 코루틴의 실행이 완료될 때까지 호출부의 코루틴이 일시 중단하도록 만들 수 있다.

---

## 1.1. 순차 처리가 안될 경우의 문제

네트워크 요청 시 인증 토큰이 필요한 상황일 때 인증 토큰이 업데이트되기 전에 네트워크 요청이 실행된다면 문제가 발생할 것이다.

아래는 토큰 업데이트 작업과 네트워크 요청 작업 간에 순차 처리가 되지 않은 케이스이다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val updatedTokenJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 토큰 업데이트 시작")
        delay(100L)
        println("[${Thread.currentThread().name}] 토큰 업데이트 완료")
    }
    val networkCallJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 네트워크 요청")
    }
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#2] 토큰 업데이트 시작
[DefaultDispatcher-worker-3 @coroutine#3] 네트워크 요청
[DefaultDispatcher-worker-1 @coroutine#2] 토큰 업데이트 완료
```

위 결과를 보면 토큰 업데이트가 끝나기 전에 네트워크 요청이 실행되는 것을 알 수 있다.

> **`delay()` 와 `Thread.sleep()`**
>
> `delay()` 함수는 `Thread.sleep()` 함수와 비슷하게 작업의 실행을 일정시간 지연시키는 역할을 함
> 
> `Thread.sleep()` 으로 지연을 실행하면 해당 함수가 실행되는 동안 스레드가 블로킹되어 사용할 수 없는 상태가 됨  
> 반면, `delay()` 로 지연을 실행하면 해당 함수가 실행되는 동안 스레드는 다른 코루틴이 사용할 수 있는 상태가 됨
> 
> 이에 관한 좀 더 상세한 내용은 추후 다룰 예정입니다. (p. 115)

![순차 처리 안된 코루틴](/assets/img/dev/2024/1109/not_ordered.png)

`runBlocking` 코루틴은 메인 스레드에서 실행되는 코루틴으로, `runBlocking` 코루틴에서 `launch()` 함수를 호출하여 _updatedTokenJob(coroutine#2)_ 를 생성하고, 
Dispatchers.IO 에 해당 코루틴을 실행 요청한다.  
그러면 Dispatchers.IO 는 _DefaultDispatcher-worker-1_ 스레드에 해당 코루틴을 할당하여 실행시킨다.  
이어서 `runBlocking` 코루틴은 `launch()` 함수를 한번 더 호출하여 _networkCallJob(coroutine#3)_ 을 생성하고, 이를 Dispatchers.IO 에 실행 요청한다.  
Dispatchers.IO 는 이미 _updatedTokenJob(coroutine#2)_ 가 점유하고 있는 _DefaultDispatcher-worker-1_ 대신에 _DefaultDispatcher-worker-3_ 스레드에
_networkCallJob(coroutine#3)_ 를 보내 실행시킨다.

즉, 위 코드에서는 인증 토큰 업데이트 작업과 네트워크 요청 작업이 병렬로 실행된다.

이러한 문제를 해결하기 위해 Job 객체는 순차 처리를 할 수 있는 `join()` 를 제공한다.

---

## 1.2. `join()` 으로 순차 처리

아래는 순차 처리가 된 예시이다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val updatedTokenJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 토큰 업데이트 시작")
        delay(100L)
        println("[${Thread.currentThread().name}] 토큰 업데이트 완료")
    }
    updatedTokenJob.join() // updatedTokenJob 이 완료될 때까지 일시 중단
    val networkCallJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 네트워크 요청")
    }
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#2] 토큰 업데이트 시작
[DefaultDispatcher-worker-1 @coroutine#2] 토큰 업데이트 완료
[DefaultDispatcher-worker-1 @coroutine#3] 네트워크 요청
```

Job 객체의 `join()` 함수를 호출하면 join 의 대상이 된 코루틴의 작업이 완료될 때까지 **`join()` 을 호출한 코루틴이 일시 중단**된다.  
여기서는 `runBlocking` 코루틴이 _updatedTokenJob.join()_ 을 호출하면 `runBlocking` 코루틴은 _updatedTokenJob_ 코루틴이 완료될 때까지 일시 중단되었다가, 
해당 작업이 완료되면 `runBlocking` 코루틴이 재개되어 _networkCallJob_ 코루틴을 실행한다.

![순차 처리된 코루틴](/assets/img/dev/2024/1109/ordered.png)

`join()` 함수를 호출한 코루틴은 join 의 대상이 된 코루틴이 완료될 때까지 일시 중단되기 때문에 **`join()` 함수는 일시 중단이 가능한 지점(코루틴 등) 에서만 호출 가능**하다.

---

**`join()` 함수는 `join()` 함수를 호출한 코루틴을 제외하고 이미 실행중인 다른 코루틴은 일시 중단하지 않는다.**  
바로 위의 코드에서 _updatedTokenJob.join()_ 이 호출되기 전에 _independentJob_ 이라는 다른 코루틴을 추가로 실행시켜 보자.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val updatedTokenJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 토큰 업데이트 시작")
        delay(100L)
        println("[${Thread.currentThread().name}] 토큰 업데이트 완료")
    }
    val independentJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 독립적인 작업 실행")
    }
    updatedTokenJob.join() // updatedTokenJob 이 완료될 때까지 일시 중단
    val networkCallJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 네트워크 요청")
    }
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#2] 토큰 업데이트 시작
[DefaultDispatcher-worker-3 @coroutine#3] 독립적인 작업 실행
[DefaultDispatcher-worker-1 @coroutine#2] 토큰 업데이트 완료
[DefaultDispatcher-worker-1 @coroutine#4] 네트워크 요청
```

_independentJob_ 은 _updatedTokenJob.join()_ 이 호출되더라도 _updatedTokenJob_ 이 끝날 때까지 기다리지 않고 실행되는 것을 확인할 수 있다.

`runBlocking` 코루틴은 _updatedTokenJob.join()_ 을 호출하기 전에 이미 `launch()` 함수를 호출해서 _independentJob(coroutine#3)_ 을 실행한다.  
`join()` 을 호출한 코루틴은 `runBlocking` 코루틴이기 때문에 `runBlocking` 코루틴만 일시 중단이 된다.  
즉, 다른 스레드인 _DefaultDispatcher-worker-3_ 에서 이미 실행이 시작된 _independentJob(coroutine#3)_ 은 일시 중단에 영향을 받지 않는다.

---

# 2. `joinAll()` 을 사용한 코루틴 순차 처리

`joinAll()` 은 가변 인자(varargs) 로 Job 타입의 객체를 받은 후 각 Job 객체에 대해 모두 `join()` 을 호출하는 방식이다.  
따라서 **`joinAll()` 의 대상이 된 코루틴들의 실행이 모두 끝날 때까지 호출부의 코루틴을 일시 중단**한다.

`joinAll()` 시그니처
```kotlin
public suspend fun joinAll(vararg jobs: kotlinx.coroutines.Job): kotlin.Unit = jobs.forEach {
    it.join()
}
```

아래와 같이 이미지 2개를 변환한 후 변환된 이미지를 서버에 올리는 상황이라고 해보자.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val convertImageJob1: Job = launch(context = Dispatchers.Default) {
        Thread.sleep(1000L) // 이미지 변환 작업 실행 시간
        println("[${Thread.currentThread().name}] 이미지1 변환 완료")
    }

    val convertImageJob2: Job = launch(context = Dispatchers.Default) {
        Thread.sleep(1000L) // 이미지 변환 작업 실행 시간
        println("[${Thread.currentThread().name}] 이미지2 변환 완료")
    }

    // 둘 다 변환될 때까지 대기
    joinAll(convertImageJob1, convertImageJob2)

    val uploadImageJob: Job = launch(context = Dispatchers.IO) {
        println("[${Thread.currentThread().name}] 이미지 업로드")
    }
}
```

```shell
[DefaultDispatcher-worker-2 @coroutine#3] 이미지2 변환 완료
[DefaultDispatcher-worker-1 @coroutine#2] 이미지1 변환 완료
[DefaultDispatcher-worker-1 @coroutine#4] 이미지 업로드
```

이미지 업로드 작업은 CPU 바운드 작업이므로 코루틴을 Dispatchers.Default 에 실행 요청하고, 업로드는 입출력 작업이므로 코루틴을 Dispatchers.IO 에 실행 요청한다.

이미지 업로드 시 `delay()` 가 아닌 `Thread.sleep()` 을 사용한 이유는 실제 이미지 변환처럼 CPU 를 사용하는 블로킹 작업을 흉내내기 위해서이다.  
`delay()` 를 사용한다면 비동기적이고 비블로킹한 코루틴 정지 상태가 되서 스레드에서 동시 실행되는 블로킹 작업 시뮬레이션과는 다르게 표현될 것이다.

---

# 3. `CoroutineStart.LAZY` 로 코루틴 지연 시작: `Job.start()`

`launch()` 함수를 사용하여 코루틴을 생성하면 사용할 수 있는 스레드가 있는 경우 바로 실행된다. 하지만 나중에 실행되어야 할 코루틴을 미리 생성해야 하는 경우도 있다.  
여기서는 코루틴을 생성한 후 원하는 시점에 실행할 수 있도록 지연 시작할 수 있는 방법에 대해 알아본다.

지연 시작 기능이 적용된 코루틴은 생성 후 대기 상태에 놓이며, 실행을 요청하지 않으면 시작되지 않는다.

**`launch()` 함수의 start 인자로 `CoroutineStart.LAZY` 를 넘겨서 생성된 코루틴은 지연 코루틴으로 생성**되며, 별도 실행 요청이 있을 때까지 실행되지 않는다.

```kotlin
package chap04

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val lazyJob: Job = launch(start = CoroutineStart.LAZY) {
        println("[${getElapsedTime(startTime)}] 지연 실행")
    }
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

위 코드를 실행하면 지연 코루틴인 _lazyJob_ 을 생성만 하고 실행 요청을 하지 않았기 때문에 아무런 로그도 나오지 않는다.

**지연 코루틴을 실행하기 위해서는 Job 객체의 `start()` 함수를 명시적으로 호출**해야 한다.

```kotlin
package chap04

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val lazyJob: Job = launch(start = CoroutineStart.LAZY) {
        println("[${getElapsedTime(startTime)}] 지연 실행")
    }
    delay(1000L) // 1초간 대기
    lazyJob.start() // 코루틴 실행
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

```shell
[지난 시간: 1011ms] 지연 실행
```

---

# 4. 코루틴 취소

코루틴 실행 도중에 코루틴을 실행할 필요가 없어지면 즉시 취소해야 한다.  
계속해서 실행되도록 두면 코루틴은 계속해서 스레드를 사용하며, 이는 한정적인 리소스를 의미없는 작업에 사용하는 것이기 때문에 애플리케이션의 성능 저하로 이어진다.  
예) 사용자가 이미지 업로드 작업을 요청해서 코루틴이 실행된 후 작업이 취소된 경우, 사용자가 특정 페이지를 열어서 해당 페이지의 데이터를 로드하기 위한 코루틴이 실행되었는데 
이후에 페이지가 닫힌 경우

---

## 4.1. `cancel()` 을 사용한 Job 취소

5.5초 뒤에 코루틴을 취소하는 예시

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val longJob: Job = launch(context = Dispatchers.Default) {
        repeat(10) { repeatTime ->
            delay(1000) // 1초간 대기
            println("[${getElapsedTime(startTime)}] 반복횟수 ${repeatTime}")
        }
    }
    delay(5500) // 5.5초간 대기
    longJob.cancel() // 코루틴 취소
}
```

```shell
[지난 시간: 1012ms] 반복횟수 0
[지난 시간: 2016ms] 반복횟수 1
[지난 시간: 3022ms] 반복횟수 2
[지난 시간: 4024ms] 반복횟수 3
[지난 시간: 5030ms] 반복횟수 4
```

---

## 4.2. `cancelAndJoin()` 을 사용한 순차 처리

`cancel()` 함수를 호출한 후 바로 다른 작업을 실행하면 해당 작업은 코루틴이 취소되기 전에 실행될 수 있다.

코루틴이 취소되기 전에 다른 코루틴이 실행되는 예시

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val longJob: Job = launch(context = Dispatchers.Default) {
        repeat(10) { repeatTime ->
            delay(1000) // 1초간 대기
            println("[${getElapsedTime(startTime)}] 반복횟수 ${repeatTime}")
        }
    }
    delay(5500) // 5.5초간 대기
    longJob.cancel() // 코루틴 취소
    afterJobCancelled()
}

fun afterJobCancelled() {
    println("다른 작업")
}
```

**Job 객체에 `cancel()` 을 호출하면 코루틴은 즉시 취소되는 것이 아니라 Job 객체 내부의 취소 확인용 플래그를 '취소 요청됨' 으로 변경함으로써 코루틴이 취소되어야 한다는 것만 
알리고, 미래 어느 시점에 코루틴의 취소가 요청되었는지 체크 후 취소**된다.  
즉, `calcel()` 함수를 사용하면 `cancel()` 대상이 된 Job 객체는 곧바로 취소되는 것이 아니라 미래의 어느 시점에 취소되기 때문에 `cancel()` 로 코루틴이 
취소된 "이후"에 다른 작업이 실행된다는 것을 보장할 수 없다.

**취소에 대한 순차성을 보장하기 위해 Job 객체는 `cancelAndJoin()` 함수를 제공**한다.

`cancelAndJoin()` 함수를 호출하면 `cancelAndJoin()` 의 대상이 된 코루틴의 취소가 완료될 때까지 호출부의 코루틴(여기서는 runBlocking) 이 일시 중단된다.  
따라서  _longJob_ 코루틴이 취소된 이후에 _afterJobCancelled()_ 함수가 실행되는 것을 보장할 수 있다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val longJob: Job = launch(context = Dispatchers.Default) {
        repeat(10) { repeatTime ->
            delay(1000) // 1초간 대기
            println("[${getElapsedTime(startTime)}] 반복횟수 ${repeatTime}")
        }
    }
    delay(5500) // 5.5초간 대기
    longJob.cancelAndJoin() // longJob 이 취소될 때까지 runBlocking 코루틴 일시 중단
    afterJobCancelled()
}

fun afterJobCancelled() {
    println("다른 작업")
}
```

---

# 5. 코루틴 취소 확인

`cancel()` 이나 `cancelAndJoin()` 함수를 사용했다고 해서 코루틴이 즉시 취소되는 것이 아니다.  
이 함수들은 Job 객체 내부에 있는 취소 확인용 플래그를 바꾸기만 하고, 코루틴이 이 플래그를 확인하는 시점에 비로소 취소된다.  
만일 코루틴이 취소를 확인할 수 있는 시점이 없다면 취소는 일어나지 않는다.

**코루틴이 취소를 확인하는 시점은 일반적으로 일시 중단 지점이나 코루틴이 실행을 대기하는 시점이며, 이 시점들이 없다면 코루틴은 취소되지 않는다.**

`cancel()` 을 호출했지만 코루틴이 취소되지 않는 예시

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    val whileJob: Job = launch(context = Dispatchers.Default) {
        while(true) {
            println("작업 중...")
        }
    }
    delay(100L) // 100ms 대기
    whileJob.cancel() // 코루틴 취소
}
```

```shell
작업 중...
작업 중...
작업 중...
작업 중...
작업 중...
```

위에서 코드 블록 내부에 코루틴의 취소를 확인할 수 있는 시점이 없기 때문에 _whileJob_ 코루틴은 취소되지 않는다.  
_whileJob_ 코루틴은 **while 문에서 코드가 반복 신행되고 있어 while 문을 벗어날 수 없다.**  
또한 **while 문 내부에도 일시 중단 지점이 없기 때문에** 일시 중단이 일어날 수 없다.  
즉, _whileJob_ 코루틴은 코루틴의 취소를 확인할 수 있는 시점이 없기 때문에 취소를 요청했음에도 불구하고 계속해서 실행된다.

[4.2. `cancelAndJoin()` 을 사용한 순차 처리](#42-cancelandjoin-을-사용한-순차-처리) 의 코드를 다시 보자.

코루틴이 취소를 확인하는 시점은 일시 중단 지점이나 코루틴이 실행을 대기하는 시점이라고 했다.  
아래 코드에서 `repeat(10)` 내부에 있는 `delay(1000)` 가 코루틴을 일시 중단 시키기 때문에, 즉 일시 중단 지점이 있기 때문에 아래 코드는 코루틴 취소가 정상적으로 이루어진다.  
만일 `repeat(10)` 내부에 있는 `delay(1000)` 가 없다면 코루틴은 취소되지 않고 계속 진행된다.

```kotlin
fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    val longJob: Job = launch(context = Dispatchers.Default) {
        repeat(10) { repeatTime ->
            delay(1000) // 1초간 대기 -> 이 부분이 없으면 코루틴 취소 안됨
            println("[${getElapsedTime(startTime)}] 반복횟수 ${repeatTime}")
        }
    }
    delay(5500) // 5.5초간 대기
    longJob.cancel() // 코루틴 취소
}
```

이제 _whileJob_ 으로 다시 돌아가서 해당 코루틴을 취소할 수 있도록 만드는 방법, 3가지에 대해 알아보자.

- `delay()` 를 사용한 취소 확인
- `yield()` 를 사용한 취소 확인
- `CoroutineScope.isActive` 를 사용한 취소 확인

위 3가지 방법은 취소 확인 시점(일시 중단 지점 혹은 코루틴이 실행을 대기하는 시점)을 만들어서 취소 요청 시 취소가 되도록 할 수 있다.

---

## 5.1. `delay()` 를 사용한 취소 확인

`delay()` 함수는 일시 중단 함수(`suspend fun`) 로 선언되어 특정 시간만큼 호출부의 코루틴을 일시 중단시킨다.  
코루틴은 일시 중단되는 시점에 코루틴의 취소를 확인하기 때문에 아래와 같이 작업 중간에 _delay(1L)_ 을 넣어주면 while 문이 반복될 때마다 일시 중단 후 취소를 확인할 수 있다.

하지만 이 방법은 **while 문이 반복될 때마다 강제로 1ms 동안 일시 중단을 시킨다는 점에서 불필요하게 작업을 지연시켜 성능 저하를 유발**한다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    val whileJob: Job = launch(context = Dispatchers.Default) {
        while(true) {
            println("작업 중...")
            delay(1L) // 일시 중단 지점 추가
        }
    }
    delay(100L) // 100ms 대기
    whileJob.cancel() // 코루틴 취소
}
```

---

## 5.2. `yield()` 를 사용한 취소 확인

`yield()` 는 직역하면 '양보' 라는 뜻으로 `yield()` 함수가 호출되면 코루틴은 자신이 사용하던 스레드를 양보한다.  
스레드 사용을 양보한다는 것은 스레드 사용을 중단한다는 뜻이므로 `yield()` 를 호출한 코루틴이 일시 중단되며 이 시점에 취소되었는지 체크가 일어난다.

하지만 이 작업도 결국 **while 문이 반복될 때마다 강제로 1ms 동안 일시 중단을 시킨다는 점에서 불필요하게 작업을 지연시켜 성능 저하를 유발**한다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield

fun main() = runBlocking<Unit>{
    val whileJob: Job = launch(context = Dispatchers.Default) {
        while(true) {
            println("작업 중...")
            yield()
        }
    }
    delay(100L) // 100ms 대기
    whileJob.cancel() // 코루틴 취소
}
```

---

### 5.2.1. `delay()` 와 `yield()` 차이점

|    항목    | `delay()`                            | `yield()`                       |
|:--------:|:-------------------------------------|:--------------------------------|
|    역할    | 지정한 시간만큼 코루틴 중단                      | 즉시 중단하고 다른 코루틴에게 실행 기회 양보       |
|    인자    | delay(100L) 처럼 시간(ms) 지정             | 인자없음                            |
|   쓰임새    | 일정 시간 코루틴 정지                         | 반복문 중간에 취소 체크하거나 컨텍스트 전환을 유도할 때 |
|    동작    | 내부에서 Dispatcher 에게 '1초 쉼' 하고 스케쥴링 위임 | 다른 코루틴에게 CPU 를 양보하고 나중에 다시 실행   |
|  CPU 사용  | 거의 0, 비동기로 쉼                         | 매우 짧게 멈췄다가 다시 실행, CPU 양보 효과     |
|  취소 체크   | 취소 가능                                | 취소 가능                           |
| 일시 중단 시간 | 명시한 시간(예-1초)                         | 거의 즉시                           |

즉, `delay()` 는 일시 중단 후 기다리지만, `yield()` 는 일시 중단하지만 기다리지는 않는다.

언제 어떤 함수를 써야할지는 아래와 같다.

- **`delay()`**
  - 시간 지연이 필요할 때
- **`yield()`**
  - 무한 루프나 반복 중 취소 가능하게 만들고 싶을 때
  - CPU 를 계속 점유하지 않도록 잠깐 비워줄 때
  - 스케쥴러에게 여유를 주고 싶을 때

---

## 5.3. `CoroutineScope.isActive` 를 사용한 취소 확인

`CoroutineScope` 는 코루틴이 활성화됐는지 확인할 수 있는 Boolean 타입의 프로퍼티닌 `isActive` 를 제공한다.  
코루틴에 취소가 요청되면 `isActive` 프로퍼티값은 false 로 변경되며, while 문의 인자로 this.isActive 를 넘김으로써 코루틴이 취소 요청되면 while 문이 취소되도록 
할 수 있다.

이 방법은 **코루틴이 잠시 멈추지도 않고, 스레드를 양보하지도 않으면서 계속해서 작업을 할 수 있어서 효율적**이다.

만일 코루틴 내부의 작업이 일시 중단 지점 없이 계속 된다면 명시적으로 코루틴이 취소되었는지 확인하는 코드를 넣어줌으로써 코드를 취소할 수 있도록 해야 한다.

```kotlin
package chap04

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    val whileJob: Job = launch(context = Dispatchers.Default) {
        while(this.isActive) {
            println("작업 중...")
        }
    }
    delay(100L) // 100ms 대기
    whileJob.cancel() // 코루틴 취소
}
```

---

# 6. 코루틴의 상태와 Job 의 상태 변수

코루틴은 아래 그림과 같이 `생성`, `실행 중`, `실행 완료 중`, `실행 완료`, `취소 중`, `취소 완료`, 총 6가지의 상태가 있다.  
여기서는 코루틴이 어떤 경우에 각 상태로 전이되는지에 대해 알아본다.

![코루틴의 상태](/assets/img/dev/2024/1109/state.png)

> `실행 완료 중`은 [2.2. 부모 코루틴의 자식 코루틴에 대한 완료 의존성](https://assu10.github.io/dev/2024/12/08/coroutine-structured-concurrency-1/#22-%EB%B6%80%EB%AA%A8-%EC%BD%94%EB%A3%A8%ED%8B%B4%EC%9D%98-%EC%9E%90%EC%8B%9D-%EC%BD%94%EB%A3%A8%ED%8B%B4%EC%97%90-%EB%8C%80%ED%95%9C-%EC%99%84%EB%A3%8C-%EC%9D%98%EC%A1%B4%EC%84%B1) 을 참고하세요.

- **생성(New)**
  - 코루틴 빌더를 통해 코루틴을 생성하면 기본적으로 생성 상태에 놓이며, 자동으로 실행 중 상태로 넘어감
  - 코루틴 빌더의 start 인자로 CoroutineStart.LAZY 를 넘겨 지연 코루틴을 만들면 실행 중 상태로 자동 변경되지 않음
- **실행 중(Active)**
  - 지연 코루틴이 아닌 코루틴을 생성하면 자동으로 실행 중 상태로 변경됨
  - 코루틴이 실제로 실행 중일 때 뿐 아니라 실행된 후에 일시 중단된 때로 실행 중 상태로 봄
- **실행 완료(Completed)**
  - 코루틴의 모든 코드가 실행 완료된 경우
- **취소 중(Cancelling)**
  - Job.cancel() 등을 통해 코루틴에 취소가 요청된 경우
  - 아직 취소된 상태가 아니기 때문에 코루틴은 계속해서 실행됨
- **취소 완료(Cancelled)**
  - 코루틴의 취소 확인 시점(일시 중단 등)에 취소가 확인된 경우
  - 이 때 코루틴은 더 이상 실행되지 않음

Job 객체에서 외부로 공개하는 코루틴의 상태 변수는 `isActive`, `isCancelled`, `isCompleted` 총 3가지이다.

- **isActive**
  - 코루틴이 활성화되어 있는지 여부
  - 실행 중이며, 취소도 안되고, 완료도 안된 상태
  - 활성화는 코루틴이 실행된 후 완료되지 않았고, 취소도 요청되지 않은 상태
- **isCancelled**
  - 코루틴이 취소 요청되었는지 여부
  - 취소 요청이 들어온 상태
  - 취소 요청이 되기만 하면 true 가 반환되므로, isCancelled 가 true 이더라도 즉시 취소된 것은 아님
- **isCompleted**
  - 코루틴이 실행 완료되었는지 여부
  - 실행이 끝났거나, 취소나 예외로 종료된 상태
  - 코루틴의 모든 코드가 실행 완료되거나, 예외로 인해 종료되거나, 취소 완료(취소로 인해 종료)된 상태


| 코루틴 상태 | isActive | isCancelled | isCompleted |
|:-------|:--------:|:-----------:|:-----------:|
| 생성     |  false   |    false    |    false    |
| 실행 중   |   true   |    false    |    false    |
| 실행 완료  |  false   |    false    |    true     |
| 취소 중   |  false   |    true     |    false    |
| 취소 완료  |  false   |    true     |    true     |


---

## 6.1. 생성(New) 상태의 코루틴

![코루틴 생성 상태](/assets/img/dev/2024/1109/new.png)

생성 상태의 코루틴을 만들기 위해서는 코루틴 빌더의 start 인자로 CoroutineStart.LAZY 를 넘겨 지연 시작이 적용된 코루틴을 생성하면 된다.

```kotlin
package chap04

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val job: Job = launch(start = CoroutineStart.LAZY) { // 생성 상태의 Job 새엇ㅇ
        delay(1000)
    }
    printJobState(job)
}

fun printJobState(job: Job) {
    println("🔍 Job 상태 확인:")
    println("- isActive: ${job.isActive}     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태")
    println("- isCancelled: ${job.isCancelled} // 취소가 요청된 상태")
    println("- isCompleted: ${job.isCompleted} // 정상 완료되었거나 예외 또는 취소로 종료된 상태")
}
```

```shell
🔍 Job 상태 확인:
- isActive: false     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태
- isCancelled: false // 취소가 요청된 상태
- isCompleted: false // 정상 완료되었거나 예외 또는 취소로 종료된 상태
```

---

## 6.2. 실행 중(Active) 상태의 코루틴

![코루틴 실행 중 상태](/assets/img/dev/2024/1109/active.png)

코루틴을 생성하면 CoroutineDispatcher 에 의해 스레드로 보내져서 실행되는데, 이렇게 코루틴이 실행되고 있는 상태이다.

```kotlin
import chap04.printJobState
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 실행 중 상태의 Job 생성
    val job: Job = launch {
        delay(1000)
    }
    printJobState(job)
}
```

```shell
🔍 Job 상태 확인:
- isActive: true     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태
- isCancelled: false // 취소가 요청된 상태
- isCompleted: false // 정상 완료되었거나 예외 또는 취소로 종료된 상태
```

---

## 6.3. 실행 완료(Completed) 상태의 코루틴

![코루틴 실행 완료 상태](/assets/img/dev/2024/1109/completed.png)

1초간 실행되는 코루틴 생성 후 2초 대기후에 Job 상태를 출력해보면 1초간 실행되는 코루틴이 실행 완료된 상태이기 때문에 실행 완료된 코루틴의 상태를 볼 수 있다.

```kotlin
package chap04

import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 실행 중 상태의 Job 생성
    val job: Job = launch {
        delay(1000) // 1초간 대기
    }
    delay(2000) // 2초간 대기, 500ms 로 하면 실행 중인 상태임
    printJobState(job)
}
```

```shell
🔍 Job 상태 확인:
- isActive: false     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태
- isCancelled: false // 취소가 요청된 상태
- isCompleted: true // 정상 완료되었거나 예외 또는 취소로 종료된 상태
```

---

## 6.4. 취소 중(Cancelling)인 코루틴

![코루틴 취소 중 상태](/assets/img/dev/2024/1109/cancelling.png)

취소가 요청됐으나 취소되지 않은 상태인 취소 중 코루틴의 상태는 취소를 확인할 수 있는 시점이 없는 코루틴을 생성한 후 취소를 요청하면 된다.

```kotlin
package chap04

import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 실행 중 상태의 Job 생성
    val job: Job = launch {
        while(true) {
            // to do..
        }
    }
    job.cancel() // 코루틴 취소 요청
    printJobState(job)
}
```

```shell
🔍 Job 상태 확인:
- isActive: false     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태
- isCancelled: true // 취소가 요청된 상태
- isCompleted: false // 정상 완료되었거나 예외 또는 취소로 종료된 상태
```

---

## 6.5. 취소 완료(Cancelled)된 코루틴

![코루틴 취소 완료 상태](/assets/img/dev/2024/1109/cancelled.png)

코루틴 취소가 요청되고, 취소 요청이 확인 되는 시점(일시 중단 등)에 취소가 완료된다.

```kotlin
package chap04

import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 실행 중 상태의 Job 생성
    val job: Job = launch {
        delay(2000)
    }
    job.cancelAndJoin() // 코루틴 취소 요청 + 취소가 완료될 때까지 대기
    printJobState(job)
}
```

```shell
🔍 Job 상태 확인:
- isActive: false     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태
- isCancelled: true // 취소가 요청된 상태
- isCompleted: true // 정상 완료되었거나 예외 또는 취소로 종료된 상태

```

---

# 정리하며..

- runBlocking() 과 launch() 는 코루틴을 만들기 위한 코루틴 빌더 함수임
- launch() 를 호출하면 Job 객체가 반환되며, Job 객체는 코루틴의 상태를 추적하고 제어하는데 사용됨
- Job.join() 은 함수를 호출한 코루틴이 Job 객체의 실행이 완료될 때까지 일시 중단함
- Job.joinAll() 은 복수의 코루틴이 실행 완료될 때까지 대기함
- Job.cancel() 은 코루틴에 취소 요청을 함
  - 이 때 코루틴이 바로 취소되는 것이 아니라 코루틴의 취소 플래그의 상태가 바뀌고, 취소 확인이 될 때 비로소 취소됨
  - Job.cancel() 을 호출하더라도 코루틴이 취소를 확인할 수 없는 상태에서는 계속해서 실행될 수 있음
- 코루틴에 취소 요청을 한 후 취소가 완료될 때까지 대기하고 나서 다음 코드를 실행할 때는 Job.cancelAndJoin() 을 이용하면 됨
- delay(), yield(), isActive 프로퍼티를 사용하여 코루틴이 취소를 확인할 수 있도록 할 수 있음
- Job 객체는 isActive, isCancelled, isCompleted 프로퍼티를 통해 코루틴의 상태를 나타냄

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)