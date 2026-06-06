---
layout: post
title:  "Coroutine - 구조화된 동시성과 부모-자식 관계(2): CoroutineScope 와 Job 의 계층"
date: 2024-12-14
categories: dev
tags: kotlin coroutine
---

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. CoroutineScope 를 사용하여 코루틴 관리](#1-coroutinescope-를-사용하여-코루틴-관리)
  * [1.1. CoroutineScope 생성](#11-coroutinescope-생성)
    * [1.1.1. `CoroutineScope` 인터페이스 구현을 통한 사용자 정의 스코프 생성](#111-coroutinescope-인터페이스-구현을-통한-사용자-정의-스코프-생성)
    * [1.1.2. `CoroutineScope()` 함수를 사용한 생성](#112-coroutinescope-함수를-사용한-생성)
  * [1.2. CoroutineScope 로부터 실행 환경 상속 받기](#12-coroutinescope-로부터-실행-환경-상속-받기)
    * [1.2.1. 코루틴 빌더 함수 내부에서의 상속 흐름](#121-코루틴-빌더-함수-내부에서의-상속-흐름)
    * [1.2.2. 람다식 내부의 `this` 로 CoroutineScope 접근](#122-람다식-내부의-this-로-coroutinescope-접근)
  * [1.3. CoroutineScope 에 속한 코루틴의 범위](#13-coroutinescope-에-속한-코루틴의-범위)
    * [1.3.1. CoroutineScope 에 속하는 코루틴의 범위](#131-coroutinescope-에-속하는-코루틴의-범위)
    * [1.3.2. CoroutineScope 를 새로 생성하여 기존 CoroutineScope 범위에서 벗어나기](#132-coroutinescope-를-새로-생성하여-기존-coroutinescope-범위에서-벗어나기)
  * [1.4. CoroutineScope 취소: `cancel()`](#14-coroutinescope-취소-cancel)
  * [1.5. CoroutineScope 활성화 상태 확인: `isActive`](#15-coroutinescope-활성화-상태-확인-isactive)
* [2. 구조화와 Job](#2-구조화와-job)
  * [2.1. runBlocking 과 루트 Job](#21-runblocking-과-루트-job)
  * [2.2. 구조화 깨기: Job 계층에서 벗어나기](#22-구조화-깨기-job-계층에서-벗어나기)
    * [2.2.1. CoroutineScope 를 사용해 구조화 깨기](#221-coroutinescope-를-사용해-구조화-깨기)
    * [2.2.2. Job 을 사용해 구조화 깨기](#222-job-을-사용해-구조화-깨기)
  * [2.3. Job 으로 일부 코루틴만 취소되지 않게 하기](#23-job-으로-일부-코루틴만-취소되지-않게-하기)
  * [2.4. 생성된 Job 의 부모 지정과 구조화 유지](#24-생성된-job-의-부모-지정과-구조화-유지)
  * [2.5. 생성된 Job 은 자동으로 실행 완료되지 않음](#25-생성된-job-은-자동으로-실행-완료되지-않음)
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

# 1. CoroutineScope 를 사용하여 코루틴 관리

CoroutineScope 은 코루틴이 실행될 수 있는 **논리적 생명 주기와 실행 환경**을 정의하는 객체이다.  
모든 코루틴은 반드시 CoroutineScope 내에서 실행되어야 하며, **이 Scope 가 취소되거나 종료되면 그 내부의 모든 코루틴도 함께 종료**된다.

여기서는 CoroutineScope 을 생성하고 사용하는 2가지 방법과, 코루틴 실행 환경(CoroutineContext) 를 어떻게 제공하는지에 대해 알아본다.

---

## 1.1. CoroutineScope 생성

### 1.1.1. `CoroutineScope` 인터페이스 구현을 통한 사용자 정의 스코프 생성

CoroutineScope 인터페이스
```kotlin
public interface CoroutineScope {
    public val coroutineContext: CoroutineContext
}
```

CoroutineScope 인터페이스는 코루틴의 실행 환경인 CoroutineContext 를 가진 인터페이스로, 이 인터페이스를 구현한 클래스를 사용하면 CoroutineScope 객체를
생성할 수 있다.

아래는 클래스를 통해 Scope 를 직접 정의하는 예시이다.
```kotlin
package chap07

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlin.coroutines.CoroutineContext

class CustomCoroutineScope: CoroutineScope {
  // Job 객체와 CoroutineDispatcher 객체를 CoroutineContext 로 가짐
  override val coroutineContext: CoroutineContext = Job() + newSingleThreadContext("CustomScopeThread")
}

fun main() {
  val coroutineScope: CoroutineScope = CustomCoroutineScope()
  // CustomCoroutineScope 객체로부터 실행 환경을 제공받는 코루틴 실행
  coroutineScope.launch {
    delay(100L) // 100ms 대기
    println("[${Thread.currentThread().name}] 코루틴 실행 완료")
  }
  Thread.sleep(1000L) // 코드 종료 방지
}
```

```shell
[CustomScopeThread @coroutine#1] 코루틴 실행 완료
```

- _CustomCoroutineScope_ 객체가 코루틴에서 **Thread + Job 이 포함된 CoroutineContext 제공**
- `launch()` 로 생성된 코루틴은 **해당 Scope 의 실행 환경**을 따름

---

위 코드에 `Thread.sleep(1000L) // 코드 종료 방지` 부분을 보자.  
이 코드는 메인 함수가 너무 일찍 종료되지 않도록 일시 정지 해주는 역할을 한다.

코루틴이 완료되기 전에 main() 이 끝나면 코루틴도 강제 종료된다.  
CoroutineScope.launch() 는 비동기 실행이기 때문에 main() 함수가 먼저 끝나버리면 코루틴이 아직 실행 중이어도 JVM 프로세스가 종료되어 버린다.  
따라서 `Thread.sleep(1000L)` 를 통해 main 스레드를 잠시 붙잡아 주는 역할을 한다.

위와 같은 방법보다는 아래처럼 [`join()`](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#1-join-%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EC%88%9C%EC%B0%A8-%EC%B2%98%EB%A6%AC) 으로 코루틴 완료를 기다리는 방식이 일반적이다.

```kotlin
fun main() = runBlocking {
    val coroutineScope = CoroutineScope(Dispatchers.IO)

    val job = coroutineScope.launch {
        delay(100L)
        println("코루틴 실행 완료")
    }

    job.join() // 코루틴이 끝날 때까지 기다림
}
```

---

### 1.1.2. `CoroutineScope()` 함수를 사용한 생성

더 간단한 방식은 함수형으로 Scope 를 만드는 것이다.

`CoroutineScope()` 함수의 시그니처
```kotlin
public fun CoroutineScope(context: CoroutineContext): CoroutineScope =
    ContextScope(if (context[Job] != null) context else context + Job())
```

`CoroutineScope()` 함수는 CoroutineContext 를 인자로 입력받아 CoroutineScope 객체를 생성하며, 인자로 입력된 CoroutineContext 에 
Job 객체가 포함되어 있지 않으면 새로운 Job() 생성하여 CoroutineContext 에 포함한다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

fun main() {
  // Dispatchers.IO 와 새로운 Job 객체로 구성된 CoroutineContext 를 가진 CoroutineScope 객체 생성
  val coroutineScope = CoroutineScope(Dispatchers.IO)
  coroutineScope.launch {
    delay(100L) // 100ms 대기
    println("[${Thread.currentThread().name}] 코루틴 실행 완료")
  }
  Thread.sleep(1000L) // 코드 종료 방지
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#1] 코루틴 실행 완료
```

- `launch()` 는 Scope 에 포함된 CoroutineContext 를 사용하여 코루틴 실행
- 이 경우 백그라운드 스레드인 `DefaultDispatcher-worker-1`에서 실행됨

CoroutineScope 객체를 만드는 2가지 방법을 살펴보는 과정에서 CoroutineScope 내부에서 실행되는 코루틴이 CoroutineScope 로부터 코루틴 실행 환경인 
CoroutineContext 를 제공받는다는 중요한 사실을 알았다.

<**인터페이스 구현 vs 함수형 생성**>

|       | 인터페이스 구현                      | 함수형 생성                         |
|:-----:|:------------------------------|:-------------------------------|
| 사용 예시 | class MyScope: CoroutineScope | CoroutineScope(Dispatchers.IO) |
|  특징   | 실행 환경을 클래스 단위로 명확하게 관리 가능     | 간단하고 유연한 임시 스코프 생성 가능          |

둘 다 CoroutineContext 를 제공하고, `launch()`/`async()` 에 해당 context 를 자동 상속한다는 공통점이 있다.

---

## 1.2. CoroutineScope 로부터 실행 환경 상속 받기

CoroutineScope 는 코루틴이 실행되는 **범위(Scope) 와 실행 환경(Context)** 을 함께 정의한다.  
여기서는 구체적으로 **코루틴 빌더 함수(`launch()`, `async()`, `runBlocking()`) 가 CoroutineScope 로부터 어떤 방식으로 실행 환경을 상속받는지** 확인해본다.

---

### 1.2.1. 코루틴 빌더 함수 내부에서의 상속 흐름

대표적인 코루틴 빌더 함수인 `launch()` 는 CoroutineScope 의 확장 함수로 정의되어 있으며, 아래와 같은 방식으로 실행 환경이 구성된다.

`launch()` 빌더 함수 시그니처
```kotlin
public fun CoroutineScope.launch(
    context: CoroutineContext = EmptyCoroutineContext,
    start: CoroutineStart = CoroutineStart.DEFAULT,
    block: suspend CoroutineScope.() -> Unit
): Job {
    // ...
}
```

- 수신 객체인 CoroutineScope 가 가진 CoroutineContext 를 기반으로
- `launch()` 에 전달된 CoroutineContext 인자를 덧붙이고 (+)
- 그 위에 새로 생성된 자식 Job 을 추가하여 최종 CoroutineContext 를 구성한다.

이 과정이 어떻게 동작하는지 코드로 보자.

CoroutineScope → `launch()` 로 실행 환경 상속 예시
```kotlin
package chap07

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

@OptIn(ExperimentalStdlibApi::class)
fun main() {
  val newScope: CoroutineScope = CoroutineScope(CoroutineName("MyCoroutine") + Dispatchers.IO) // 1
  newScope.launch(context = CoroutineName("LaunchCoroutine")) { // 2
    println(this.coroutineContext[CoroutineName])
    println(this.coroutineContext[CoroutineDispatcher])

    val launchJob: Job? = this.coroutineContext[Job]
    val newScopeJob: Job? = newScope.coroutineContext[Job]
    println("launchJob?.parent === newScopeJob >> ${launchJob?.parent === newScopeJob}")
  }
  Thread.sleep(1000L)
}
```

```shell
CoroutineName(LaunchCoroutine)
Dispatchers.IO
launchJob?.parent === newScopeJob >> true
```


1. CoroutineName("MyCoroutine"), Dispatchers.IO, 새로운 Job 객체로 구성된 CoroutineContext 객체를 포함하는 CoroutineScope 객체가 생성됨
2. newScope 를 사용해 실행되는 `launch()` 함수의 context 인자로 CoroutineName("LaunchCoroutine") 이 넘어왔으므로 CoroutineName("MyCoroutine") 를 덮어씀  
   `launch()` 코루틴 빌더 함수는 새로운 Job 을 생성하고, 이 Job 은 반환된 CoroutineContext 의 Job 을 부모로 설정함

따라서 `launch()` 코루틴이 사용할 CoroutineContext 는 최종적으로 아래와 같다.

| `launch()` 코루틴이 사용한 CoroutineContext 구성요소 | 설명              |
|:-----------------------------------------:|:----------------|
|      CoroutineName("LaunchContext")       | 자식이 override 함  |
|              Dispatchers.IO               | 부모 Scope 로부터 상속 |
|       새로운 Job (부모는 newScope 의 Job)        | 구조화 관계 형성       |


---

### 1.2.2. 람다식 내부의 `this` 로 CoroutineScope 접근

`launch { ... }` 의 람다식 내부에서는 **암시적으로 CoroutineScope 가 수신 객체(this)** 로 주어진다.  
이 덕분에 내부 코루틴에서도 `this.coroutineContext` 를 사용하여 상속된 실행 환경에 접근할 수 있다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

fun main() {
    val newScope: CoroutineScope = CoroutineScope(CoroutineName("MyCoroutine"))
    newScope.launch(context = CoroutineName("LaunchCoroutine")) { // this: CoroutineScope (launch 코루틴의 실행 환경을 담은 CoroutineScope)
        this.coroutineContext[CoroutineName] // LaunchCoroutine 의 실행 환경을 CoroutineScope 를 통해 접근
        this.launch {  // CoroutineScope 로부터 LaunchCoroutine 의 실행 환경을 제공받아 코루틴 제공
            // ..
        }
    }
}
```

`launch()` 함수 뿐 아니라 `runBlocking()` 이나 `async()` 같은 모든 코루틴 빌더 함수의 람다식은 수신 객체로 CoroutineScope 를 제공한다.

```kotlin
package chap07

import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // this: CoroutineScope (runBlocking 코루틴의 실행 환경을 담은 CoroutineScope)
    this.launch { // this: CoroutineScope (launch 코루틴의 실행 환경을 담은 CoroutineScope)
        this.async { // this: CoroutineScope (async 코루틴의 실행 환경을 담은 CoroutineScope)
            // 모두 CoroutineScope 를 수신 객체로 가지며, 부모 코루틴의 실행 환경이 자동 상속됨
        }
    }
}
```

(위 코드에서 this 는 생략할 수 있다.)

지금까지 `launch()` 함수의 람다식에서 `this.coroutineContext` 를 통해 `launch()` 함수로 생성된 코루틴의 실행 환경에 접근할 수 있었던 이유는 CoroutineScope 가
수신 객체로 제공되었기 때문이다. 자식 코루틴에 실행 환경이 상속될 수 있었던 이유 또한 이 CoroutineScope 객체로부터 부모 코루틴의 실행 환경을 삼속받았기 때문이다.

---

## 1.3. CoroutineScope 에 속한 코루틴의 범위

코루틴은 항상 **어떤 CoroutineScope 에 속해서 실행**된다.  
각 코루틴 빌더 함수(`launch()`, `async()`, `runBlocking()` 등) 의 **람다식은 CoroutineScope 를 수신 객체(this)** 로 갖고, 그 범위 안에서 생성된 
모든 코루틴은 해당 Scope 에 **종속된 생명 주기**를 가진다.

여기서는 CoroutineScope 가 **어떤 범위의 코루틴을 관리**하고, 그 **범위를 벗어나는 방법과 주의사항**에 대해 알아본다.

---

### 1.3.1. CoroutineScope 에 속하는 코루틴의 범위

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{ // 1 this: CoroutineScope
  launch(context = CoroutineName("Coroutine1")) { // 2 this: CoroutineScope
    launch(context = CoroutineName("Coroutine3")) {
      println("[${Thread.currentThread().name}] Coroutine3 코루틴 실행")
    }
    launch(context = CoroutineName("Coroutine4")) {
      println("[${Thread.currentThread().name}] Coroutine4 코루틴 실행")
    }
  }
  launch(context = CoroutineName("Coroutine2")) {
    println("[${Thread.currentThread().name}] Coroutine2 코루틴 실행")
  }
}
```

```shell
[main @Coroutine2#3] Coroutine2 코루틴 실행
[main @Coroutine3#4] Coroutine3 코루틴 실행
[main @Coroutine4#5] Coroutine4 코루틴 실행
```

- `runBlocking()` 은 최상위 CoroutineScope 를 제공하며 그 안에서 생성된 모든 `launch()` 코루틴은 해당 Scope 의 자식이 됨
- Coroutine1 의 범위 안에서 실행된 Coroutine3, 4 는 Coroutine1 에 속한 자식이 됨

즉, 코루틴은 **자신이 속한 Scope 내에서 생성된 다른 코루틴과 구조화된 관계를 형성**한다.

---

### 1.3.2. CoroutineScope 를 새로 생성하여 기존 CoroutineScope 범위에서 벗어나기

만일 위 코드에서 Coroutine4 코루틴이 runBlocking 람다식의 CoroutineScope 객체의 범위에서 벗어나야 한다고 해보자.  
이럴 경우 `CoroutineScope()` 를 직접 생성하여 **새로운 Job** 을 포함한 독립적인 Scope 를 만들 수 있다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = CoroutineName("Coroutine1")) {
        launch(context = CoroutineName("Coroutine3")) {
            println("[${Thread.currentThread().name}] Coroutine3 코루틴 실행")
        }
        // CoroutineScope(Dispatchers.IO) 로 생성되는 CoroutineScope 로 관리되는 범위
        CoroutineScope(Dispatchers.IO).launch(context = CoroutineName("Coroutine4")) { // this: Coroutine
            println("[${Thread.currentThread().name}] Coroutine4 코루틴 실행")
        }
    }
    launch(context = CoroutineName("Coroutine2")) {
        println("[${Thread.currentThread().name}] Coroutine2 코루틴 실행")
    }
}
```

```shell
[main] Coroutine2 코루틴 실행
[DefaultDispatcher-worker-1] Coroutine4 코루틴 실행
[main] Coroutine3 코루틴 실행
```

- Coroutine4 는 `runBlocking()` 과 연결된 Job 계층에 속하지 않음
- 따라서 `runBlocking()` 이 먼저 종료되더라도 Coroutine4 는 백그라운드에서 독립적으로 실행됨

어떻게 Coroutine4 코루틴이 기존 CoroutineScope 객체의 범위에서 벗어날 수 있는 것일까?
코루틴은 Job 객체를 사용하여 구조화되는데 CoroutineScope 함수를 사용해 새로운 CoroutineScope 객체를 생성하면 기존의 계층 구조를 다르지 않는 새로운 Job 객체가 생성되어 
새로운 계층 구조를 만들게 된다.

CoroutineScope 를 직접 생성하면 구조화가 깨져서 자식-부모 관계가 끊어진다.

<**구조화가 깨질 시 문제점**>
- **생명 주기 분리**
  - 부모 Scope 가 취소되어도 자식 코루틴이 계속 실행될 수 있음
- **자원 누수 가능**
  - 명시적으로 취소하지 않으면 실행이 계속됨
- **예외 전파 안됨**
  - 부모 코루틴으로 예외가 전달되지 않음

이러한 이유로 별도의 Scope 를 만드는 방식은 최대한 피하고, 구조화된 CoroutineScope 안에서 코루틴을 실행하는 것을 권장한다.

> 더 자세한 구조화 깨짐의 위험성은 추후 다룰 예정입니다. (p. 229)

지금까지 CoroutineScope 객체에 의해 관리되는 코루틴의 범위와 범위를 만드는 것은 Job 객체라는 것을 살펴보았다.

일반적으로 Job 객체는 코루틴 빌더 함수를 통해 생성되는 코루틴을 제어하는데 사용되지만, CoroutineScope 객체 또한 Job 객체를 통해 하위에 생성되는 코루틴을 제어한다.
따라서 코루틴은 Job 객체를 갖지만, Job 객체가 꼭 코루틴이 아닐 수 있다.

---

## 1.4. CoroutineScope 취소: `cancel()`

`CoroutineScope.cancel()` 함수는 **해당 스코프 범위 내의 모든 코루틴을 한꺼번에 취소**할 수 있게 해준다.  
구조화된 동시성 원칙에 따라 Scope 에 속한 코루틴들은 모두 **해당 Scope 의 생명 주기에 따라 관리**되며, `cancel()` 이 호출되면 **그 Scope 에 속한 모든 
코루틴에 취소가 전파**된다.

CoroutineScope 인터페이스는 확장 함수로 `cancel()` 함수를 지원하며, 이 `calcel()` 함수는 CoroutineScope 객체의 범위에 속한 모든 취소한다.
이 함수가 호출되면 범위에서 실행 중인 모든 코루틴에 취소가 요청된다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = CoroutineName("Coroutine1")) {
        launch(context = CoroutineName("Coroutine3")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행 완료")
        }
        launch(context = CoroutineName("Coroutine4")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행 완료")
        }

        // Coroutine1 의 CoroutineScope 에 취소 요청
        this.cancel()
    }
    launch(context = CoroutineName("Coroutine2")) {
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행 완료")
    }
}
```

```shell
[main @Coroutine2#3] 코루틴 실행 완료
```

- Coroutine3, Coroutine4 는 취소되어 실행되지 않음
- Coroutine2는 Coroutine1 과 다른 Scope 에 속하므로 영향받지 않음

어떻게 CoroutineScope 객체의 `calcel()` 함수가 범위에 속한 모든 코루틴을 취소하는 것일까?  
`CoroutineScope.cancel()` 함수는 내부적으로 Scope 의 coroutineContext 에서 Job 을 찾아서 그 `Job.cancel()` 을 호출하는 방식으로 동작한다.

`cancel()` 함수 시그니처
```kotlin
public fun CoroutineScope.cancel(cause: CancellationException? = null) {
    val job = coroutineContext[Job] ?: error("Scope cannot be cancelled because it does not have a job: $this")
    job.cancel(cause)
}
```

- this.cancel() 호출 → 현재 Scope 의 Job 추출
- `Job.cancel()` 호출 → 해당 Job 에 속한 모든 자식 Job(코루틴) 취소
- 구조화된 범위 내에서 하위 코루틴까지 전파

---

## 1.5. CoroutineScope 활성화 상태 확인: `isActive`

> [5.3. `CoroutineScope.isActive` 를 사용한 취소 확인](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#53-coroutinescopeisactive-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%B7%A8%EC%86%8C-%ED%99%95%EC%9D%B8) 
> 을 참고하세요.

---

# 2. 구조화와 Job

앞에서 살펴봤듯이 CoroutineScope 를 통해 코루틴을 생성하고 관리하는 과정은 내부적으로 **CoroutineContext 내에 있는 Job 객체를 제어**하는 것과 동일하다.

여기서는 코루틴 구조화의 핵심인 **Job 계층 구조**를 좀 더 자세히 보고, 구조화가 깨지는 경우 어떤 일이 발생하는지도 함께 살펴본다.

---

## 2.1. runBlocking 과 루트 Job

```kotlin
fun main() = runBlocking<Unit> { // 루트 Job 생성
 // ...
}
```

runBlocking 은 **가장 상위 Scope** 를 정의하며, 내부적으로 **부모 Job 이 없는 루트 Job** 이 생성된다.  
이 루트 Job 은 해당 runBlocking 범위 내에서 생성된 모든 코루틴의 부모 역할을 하며, 그 **코루틴이 완료되기 전까지 블로킹 상태로 대기**한다.

runBlocking 은 main() 함수나 테스트 코드에서 코루틴을 동기적으로 제어할 때 유용하게 사용된다.

---

## 2.2. 구조화 깨기: Job 계층에서 벗어나기

### 2.2.1. CoroutineScope 를 사용해 구조화 깨기

`CoroutineScope()` 를 통해 새로운 Scope 를 생성하면, 이 Scope 는 기존의 **Job 계층과는 완전히 분리된 새로운 루트 Job** 을 가지게 된다.


구조화 깨기 예시
```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 루트 Job 생성
    val newScope: CoroutineScope = CoroutineScope(Dispatchers.IO) // 새로운 루트 Job 생성
    newScope.launch(context = CoroutineName("Coroutine1")) { // Coroutine1 실행
        launch(CoroutineName("Coroutine3")) { // Coroutine3 실행
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
        launch(CoroutineName("Coroutine4")) { // Coroutine4 실행
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    newScope.launch(context = CoroutineName("Coroutine2")) { // Coroutine2 실행
        launch(CoroutineName("Coroutine5")) { // Coroutine5 실행
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
}
```

```shell
Process finished with exit code 0
```

위 코드의 결과는 왜 아무것도 출력되지 않을까?
- runBlocking 은 **자기 Scope 내부의 코루틴만 대기**한다.
- _newScope_ 는 **runBlocking 과 관계없는 새로운 루트 Job**을 가졌기 때문에,
- runBlocking 이 종료되면 **_newScope_ 의 코루틴들은 아직 실행중이더라도 기다리지 않고 프로세스가 종료**된다.

즉, 위 코드에서 _newScope_ 는 새로운 Job 트리를 생성하므로 부모가 없다.

좋은 방법은 아니지만 위 출력을 보기 위해 제일 마지막에 delay() 를 넣으면 아래와 같이 출력된다.
```kotlin

// ...

    newScope.launch(context = CoroutineName("Coroutine2")) { // Coroutine2 실행
        launch(CoroutineName("Coroutine5")) { // Coroutine5 실행
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    delay(1000L)
}
```

```shell
[DefaultDispatcher-worker-4 @Coroutine3#4] 코루틴 실행
[DefaultDispatcher-worker-3 @Coroutine5#6] 코루틴 실행
[DefaultDispatcher-worker-8 @Coroutine4#5] 코루틴 실행
```

<**구조화를 깨는 것은 위험하다**>  
코루틴을 구조화된 방식으로 사용해야 하는 이유는 아래와 같다.
- 취소 전파가 되지 않음 → 자식 코루틴을 종료할 수 없음
- 예외 전파가 안됨 → 예외가 부모로 전파되지 않아 앱 크래시 방지 불가
- 자원 누수 가능성 → 더 이상 필요없는 코루틴이 계속 실행될 수 있음

따라서 특별한 이유가 없다면 CoroutineScope() 를 직접 생성하기 보다는 기존 Scope를 활용해 구조화된 코루틴을 작성하는 것이 안전하다.

---

### 2.2.2. Job 을 사용해 구조화 깨기

코틀린 구조화는 일반적으로 **부모 Job → 자식 Job** 구조로 연결되며, 상위 Job 이 취소되면 자식 Job 도 취소된다.  
하지만 **명시적으로 루트 Job 을 따로 생성**하여 구조화를 의도적으로 깨뜨릴 수 있다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val newRootJob = Job() // 루트 Job 생성
    launch(context = CoroutineName("Coroutine1") + newRootJob) {
        launch(context = CoroutineName("Coroutine3")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
        launch(context = CoroutineName("Coroutine4")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    launch(context = CoroutineName("Coroutine2") + newRootJob) {
        launch(context = CoroutineName("Coroutine5")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    // 메인 스레드가 끝나지 않도록 지연
    delay(1000L)
}
```

```shell
[main @Coroutine3#4] 코루틴 실행
[main @Coroutine4#5] 코루틴 실행
[main @Coroutine5#6] 코루틴 실행
```

- _newRootJob_ 은 runBlocking 과는 무관한 새로운 Job 계층을 만듦
- Coroutine1,2 는 이 Job 에 속하고, 그 하위 코루틴들도 연결됨

---

## 2.3. Job 으로 일부 코루틴만 취소되지 않게 하기

기존 구조화된 Job 계층 안에 있던 일부 코루틴만 **독립**시켜, **부모 Job 이 취소되어도 실행**될 수 있게 만들 수 있다.

Coroutine5 만 구조화에서 분리는 예시
```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val newRootJob = Job() // 루트 Job 생성
    launch(context = CoroutineName("Coroutine1") + newRootJob) {
        launch(context = CoroutineName("Coroutine3")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
        launch(context = CoroutineName("Coroutine4")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    launch(context = CoroutineName("Coroutine2") + newRootJob) {
        launch(context = CoroutineName("Coroutine5") + Job()) { // Job() 을 넘김
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    delay(50L) // Coroutine5 생성 시점 확보
    newRootJob.cancel() // Coroutine3,4 는 취소됨
    delay(1000L)
}
```

```shell
[main @Coroutine5#6] 코루틴 실행
```
- Coroutine5 는 명시적으로 **새로운 Job()** 을 넘겼기 때문에
- 상위 Job(_newRootJob_) 과 **구조화 연결이 끊어짐**
- 상위 Job 이 취소되더라도 **독립적으로 실행 가능**

부모-자식 관계가 끊어진 코루틴은 책임 주체가 사라지기 때문에 자원 해제 누락, 예외 전파 실패 등의 문제가 생길 수 있다.  
실전에서는 `SupervisorJob` 이나 별도 생명주기 관리 도구를 사용하는 것이 더 안전하다.

---

## 2.4. 생성된 Job 의 부모 지정과 구조화 유지

`Job()` 시그니처
```kotlin
public fun Job(parent: Job? = null): CompletableJob = JobImpl(parent)
```

- `Job()` 생성자에 parent 를 넘기지 않으면(= parent 가 null) 부모가 없는 **루트 Job** 이 생성된다.
- parent 인자로 Job 을 넘기면 **그 Job 을 부모로 지정한 새로운 Job** 이 생성된다.

`Job()` 만 사용하여 구조화가 깨지는 예시
```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    launch(context = CoroutineName("Coroutine1")) {
        val newJob = Job()
        launch(context = CoroutineName("Coroutine2") + newJob) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    delay(1000L)
}
```

```shell
[main @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

![코루틴의 계층을 끊는 Job](/assets/img/dev/2024/1214_1/job.png)

Job() 을 통해 생성되는 새로운 Job 객체인 newJob 을 사용해 Coroutine1 과 Coroutine2 의 구조화를 끊었다.

부모를 명시적으로 설정하여 구조화를 유지하는 예시
```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    launch(context = CoroutineName("Coroutine1")) {
        val coroutine1Job = this.coroutineContext[Job] // Coroutine1 의 Job
        val newJob = Job(parent = coroutine1Job)
        launch(context = CoroutineName("Coroutine2") + newJob) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    delay(1000L)
}
```

```shell
[main @Coroutine2#3] 코루틴 실행

// 프로세스 종료 로그가 출력되지 않는다.
```

![Job 객체를 생성하면서 계층 구조 유지](/assets/img/dev/2024/1214_1/job2.png)

- 구조화 유지: Coroutine1 의 Job 이 _newJob_ 의 부모가 되므로 구조화가 깨지지 않음

다만 이렇게 Job 객체를 생성할 경우 문제가 생길 수 있는데 어떤 점을 주의해야 하는지 알아보자.

---

## 2.5. 생성된 Job 은 자동으로 실행 완료되지 않음

`launch()` 또는 `async()` 로 생성된 Job 은 자식 코루틴이 종료되면 자동으로 완료 처리된다.  
하지만 `Job()` 으로 직접 생성한 Job 은 **명시적으로 `complete()` 를 호출하지 않으면 실행 완료 상태가 되지 않는다.**

바로 위의 코드를 다시 보자.

위 코드는 프로세스가 종료되지 않고 계속해서 실행된다.
Job(parent = coroutine1Job) 으로 생성된 newJob 이 자동으로 실행 완료 처리되지 않기 때문이다.
자식 코루틴이 실행 완료되지 않으면 부모 코루틴도 실행 완료될 수 없으므로 아래 그림과 같이 부모 코루틴들이 실행 완료 중 상태에서 대기하게 된다.

![자동으로 종료되지 않는 newJob](/assets/img/dev/2024/1214_1/job3.png)

이 문제를 해결하기 위해서는 아래와 같이 Job 객체의 `complete()` 함수를 명시적으로 호출하여 _newJob) 의 실행이 완료될 수 있도록 해야한다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    launch(context = CoroutineName("Coroutine1")) {
        val coroutine1Job = this.coroutineContext[Job] // Coroutine1 의 Jo
        val newJob = Job(parent = coroutine1Job)
        launch(context = CoroutineName("Coroutine2") + newJob) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
        newJob.complete() // 명시적으로 완료 호출
    }
    delay(1000L)
}
```

```shell
[main @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

newJob 의 complete 함수를 호출하면 newJob 은 `실행 완료 중` 상태로 바뀌며, 자식 코루틴인 Coroutine2 가 실행 완료되면 자동으로 `실행 완료` 상태로 바뀐다.
연쇄적으로 Coroutine1, runBlocking 코루틴도 `실행 완료` 상태로 변경되어 프로세스가 정상적으로 종료된다.

---

# 정리하며..

- **코루틴 빌더가 호출될 때마다 새로운 Job 객체가 생성**되며, Job 객체는 아래와 같은 구조화 계층을 형성한다.
  - 부모 Job 은 `parent: Job?`, 자식 Job 들은 `children: Sequence<Job>` 프로퍼티로 연결된다.
  - 부모 Job 은 자식 Job 이 완료될 때까지 종료되지 않으며, 부모가 취소되면 자식 Job 모두에게 취소가 전파된다.
- **CoroutineScope 는 코루틴 실행 환경(CoroutineContext) 를 제공**하는 인터페이스며, 확장 함수인 `launch()`, `async()` 등을 통해 코루틴을 실행할 수 있다.
  - `CoroutineScope.cancel()` 을 호출하면 해당 범위 내 모든 코루틴이 취소되며, 이는 CoroutineContext 내의 `Job.cancel()` 호출과 동일하다.
  - CoroutineScope 의 활성 상태는 `isActive` 확장 프로퍼티로 확인할 수 있다.
- **코루틴 구조화는 명확한 책임과 생명 주기 관리에 핵심적**이다.
  - `Job()` 또는 `CoroutineScope()` 를 통해 별도의 루트 Job 을 만들면 구조화가 깨질 수 있다.
    - 구조화가 깨지면 부모-자식 관계가 사라져, 상위 코루틴이 하위 코루틴의 완료를 기다리지 않게 된다.
  - 특별한 이유가 없다면 구조화된 계층 내에서 코루틴을 생성하는 것을 권장한다.
- J**ob 객체는 생성 시 부모를 명시하여 구조화 계층을 유지**할 수 있다.
  - `Job(parent = someJob)` 형태로 계층을 지정할 수 있다.
  - 단, `Job()` 으로 직접 생성한 Job 은 자동으로 완료되지 않기 때문에 `complete()` 호출이 필요하다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)