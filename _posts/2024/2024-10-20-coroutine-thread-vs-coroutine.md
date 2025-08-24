---
layout: post
title:  "Coroutine - 기존 스레드의 한계와 코루틴"
date: 2024-10-20
categories: dev
tags: kotlin coroutine
---

이 포스트에서는 JVM 의 프로세스와 스레드에 대해 다룬다.  
기존 멀티 스레드 프로그래밍이 어떤 방식으로 변화했고, 코루틴의 기존 멀티 스레드 프로그래밍의 한계를 어떻게 극복했는지에 대해 알아본다.

- JVM 프로세스와 스레드
- 단일 스레드의 한계와 멀티 스레드 프로그래밍
- 기존 멀티 스레드 프로그래밍의 한계와 코루틴이 이를 극복한 방법

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap01) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. JVM 프로세스와 스레드](#1-jvm-프로세스와-스레드)
* [2. 단일 스레드의 한계와 멀티 스레드 프로그래밍](#2-단일-스레드의-한계와-멀티-스레드-프로그래밍)
  * [2.1. 단일 스레드 애플리케이션의 한계](#21-단일-스레드-애플리케이션의-한계)
  * [2.2. 멀티 스레드 프로그래밍을 통한 단일 스레드 한계 극복](#22-멀티-스레드-프로그래밍을-통한-단일-스레드-한계-극복)
* [3. 스레드와 스레드풀을 사용한 멀티 스레드 프로그래밍](#3-스레드와-스레드풀을-사용한-멀티-스레드-프로그래밍)
  * [3.1. `Thread` 클래스를 사용하는 방법과 한계](#31-thread-클래스를-사용하는-방법과-한계)
    * [3.1.1. `Thread` 클래스로 스레드 다루기: `thread()`](#311-thread-클래스로-스레드-다루기-thread)
    * [3.1.2. `Thread` 클래스를 직접 다룰 때의 한계](#312-thread-클래스를-직접-다룰-때의-한계)
  * [3.2. `Executor` 프레임워크를 통한 스레드풀 사용](#32-executor-프레임워크를-통한-스레드풀-사용)
    * [3.2.1. `Executor` 프레임워크 사용](#321-executor-프레임워크-사용)
    * [3.2.2. `Executor` 프레임워크 내부 구조](#322-executor-프레임워크-내부-구조)
    * [3.2.3. `Executor` 프레임워크 한계: 스레드 블로킹](#323-executor-프레임워크-한계-스레드-블로킹)
* [4. 기존 멀티 스레드 프로그래밍의 한계와 코루틴](#4-기존-멀티-스레드-프로그래밍의-한계와-코루틴)
  * [4.1. 멀티 스레드 프로그래밍의 한계](#41-멀티-스레드-프로그래밍의-한계)
  * [4.2. 코루틴의 스레드 블로킹 문제 극복: 경량 스레드](#42-코루틴의-스레드-블로킹-문제-극복-경량-스레드)
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

# 1. JVM 프로세스와 스레드

멀티 스레드 프로그래밍의 변천사를 이해하려면 JVM 의 프로세스와 스레드에 대한 이해가 선행되어야 한다.  
코틀린 코드를 실행했을 때 JVM 에서 어떻게 프로세스가 생성되고 종료되는지부터 알아본다.

애플리케이션 실행 → JVM 이 프로세스 시작 → 메인 스레드 생성 → main 함수 내부 코드 실행 → 애플리케이션 종료

```kotlin
package chap01

fun main() {
    println("hello world")
}
```

```shell
# 메인 스레드가 println("hello world") 실행
hello world

# 프로세스가 정상 종료됨
Process finished with exit code 0
```

일반적으로 메인 스레드는 프로세스의 시작과 끝을 함께 하며, 예외로 인해 메인 스레드가 강제 종료되면 프로세스도 강제 종료된다.

```kotlin
package chap01

fun main() {
    println("start")
    throw Exception("test exception")
    println("end")
}
```

```shell
# 메인 스레드 시작
start

# 예외 발생
Exception in thread "main" java.lang.Exception: test exception
	at chap01.Code1Kt.main(Code1.kt:5)
	at chap01.Code1Kt.main(Code1.kt)

# 프로세스 비정상 종료
Process finished with exit code 1
```

위처럼 JVM 프로세스는 기본적으로 메인 스레드를 단일 스레드로 해서 실행되며, 메인 스레드가 종료되면 프로세스도 종료된다.

> **메인 스레드가 항상 프로세스의 끝을 함께 하는 것은 아님**
> 
> JVM 프로세스는 사용자 스레드가 모두 종료될 때 프로세스가 종료되며, 메인 스레드는 사용자 스레드 중 하나임  
> 멀티 스레드 환경에서 사용자 스레드가 여러 개라면 메인 스레드에서 예외가 발생하여 전파되더라도 프로세스는 강제 종료되지 않음
> 
> 이에 대한 상세한 내용은 [3.1.1. `Thread` 클래스로 스레드 다루기](#311-thread-클래스로-스레드-다루기) 을 참고하세요.

---

# 2. 단일 스레드의 한계와 멀티 스레드 프로그래밍

main 함수를 통해 애플리케이션을 실행하면 메인 스레드를 단일 스레드로 사용하여 실행되는데, 단일 스레드에서 실행되는 애플리케이션에는 몇 가지 문제가 있다.

---

## 2.1. 단일 스레드 애플리케이션의 한계

스레드는 하나의 작업을 수행할 때 다른 작업을 동시에 수행하지 못하므로 메인 스레드에서 실행하는 작업이 오래 걸리면 해당 작업이 처리되는 동안 다른 작업을 수행하지 못해 
응답성에 문제가 생길 수 있다.  
즉, 단일 스레드만 사용해 작업하면 해야 할 작업이 다른 작업에 의해 방해받거나 작업 속도가 느려질 수 있다.

예를 들어 서버사이드에서 DB1, DB2, DB3 을 조회한 후 그 결과를 병합해야 할 때 단일 스레드라면 각 작업이 순차적으로 진행되므로 처리 속도와 응답 속도가 늦어진다.

---

## 2.2. 멀티 스레드 프로그래밍을 통한 단일 스레드 한계 극복

멀티 스레드 프로그래밍은 스레드를 여러 개 사용하여 작업을 처리한다.  
각 스레드가 한 번에 하나의 작업을 처리할 수 있으므로 여러 작업을 동시에 처리하는 것이 가능해진다.

안드로이드의 경우 메인 스레드에 오래 걸리는 작업이 요청되었을 때 이 작업을 백그라운드 스레드에서 처리하도록 하면 메인 스레드는 오래 걸리는 작업을 하지 않아도 되기 때문에 
UI 가 멈추거나 사용자 입력을 받지 못하는 현상을 방지할 수 있다.

이렇게 여러 스레드가 동시에 작업을 처리하는 것을 병렬 처리라고 한다.

> 단, 모든 작업을 작은 단위로 나눠서 병렬로 실행할 수 있는 것은 아님  
> 작은 작업 간에 독립성이 있을 때만 병렬 실행이 가능함  
> 만일 큰 작업을 작은 작업으로 분할했을 때 작은 작업 간에 의존성이 있다면 이 작은 작업들은 순차적으로 진행되어야 함  
> 예) DB1 을 조회한 결과가 DB2 를 조회할 때 필요하다면 이 두 DB 를 조회하는 일은 순차적으로 실행되어야 함

---

# 3. 스레드와 스레드풀을 사용한 멀티 스레드 프로그래밍

코루틴은 기존의 멀티 스레드 프로그래밍 문제를 해결한 토대 위에서 만들어졌기 때문에 멀티 스레드 프로그래밍의 변화 과정을 이해하는 것은 중요하다.

여기서는 코루틴이 등장하기 이전에 만들어진 스레드와 스레드풀을 활용한 멀티 스레드 프로그래밍 방식에 대해 알아본다.  
스레드를 직접 다루는 가장 간단한 방법인 `Thread` 클래스를 활용한 방법부터 알아본다.

---

## 3.1. `Thread` 클래스를 사용하는 방법과 한계

### 3.1.1. `Thread` 클래스로 스레드 다루기: `thread()`

아래는 오래 걸리는 작업이 별도 스레드에서 실행될 수 있도록 `Thread` 클래스를 상속하는 클래스이다.

```kotlin
class TestThread : Thread() {
  override fun run() {
    println("[${currentThread().name}] 새로운 스레드 start")
    sleep(3000) // 3초 동안 대기
    println("[${currentThread().name}] 새로운 스레드 end")
  }
}
```

`Thread` 클래스의 `run()` 을 override 하면 새로운 스레드에서 실행할 코드를 작성할 수 있다.

이제 main 함수에서 위의 클래스를 인스턴스화하여 실행해보자.

```kotlin
fun main() {
    println("[${Thread.currentThread().name}] 메인 스레드 start")
    TestThread().start()
    Thread.sleep(1000) // 1초 동안 대기
    println("[${Thread.currentThread().name}] 메인 스레드 end")
}
```

```shell
[main] 메인 스레드 start
[Thread-0] 새로운 스레드 start
// 메인 스레드 시작 후 1초 대기 후 출력
[main] 메인 스레드 end
// 새로운 스레드 시작 후 2초 대기 후 출력
[Thread-0] 새로운 스레드 end
```

---

코틀린은 `thread()` 함수를 사용하여 새로운 스레드에서 실행할 코드를 바로 작성할 수 있다.

```kotlin
package chap01

import java.lang.Thread.currentThread
import java.lang.Thread.sleep
import kotlin.concurrent.thread

fun main() {
    println("[${currentThread().name}] 메인 스레드 start")
    thread(isDaemon = false) {
        println("[${currentThread().name}] 새로운 스레드 start")
        sleep(3000) // 3초 동안 대기
        println("[${currentThread().name}] 새로운 스레드 end")
    }
    println("[${currentThread().name}] 메인 스레드 end")
}
```

위와 같이 하면 새로운 스레드에서 실행해야 하는 작업이 있을 때마다 `Thread` 클래스를 상속받아 새로운 클래스를 만들 필요가 없다.

```shell
[main] 메인 스레드 start
[Thread-0] 새로운 스레드 start
[main] 메인 스레드 end
[Thread-0] 새로운 스레드 end
```

> **사용자 스레드와 데몬 스레드**
> 
> JVM 은 스레드를 사용자 스레드와 데몬 스레드로 구분함  
> 사용자 스레드는 우선도가 높은 스레드이고, 데몬 스레드는 우선도가 낮은 스레드임  
> JVM 프로세스가 종료되는 시점은 우선도가 높은 사용자 스레드가 모두 종료될 때임  
> 따라서 멀티 스레드를 사용하는 프로세스에서는 스레드 중 사용자 스레드가 모두 종료되는 시점에 프로세스가 종료됨  
> 
> `Thread` 클래스를 상속한 클래스를 사용하여 스레드를 생성하면 기본적으로 사용자 스레드로 생성됨  
> 만일 생성되는 스레드를 데몬 스레드로 변경하고 싶다면 아래와 같이 isDemon = true 속성을 적용하면 됨

```kotlin
TestThread().apply {
   isDeamon = true
}.start()
```

사용자 스레드가 종료되면 데몬 스레드는 강제 종료됨
```kotlin
fun main() {
    println("[${Thread.currentThread().name}] 메인 스레드 start")
    TestThread().apply {
        isDaemon = true
    }.start()
    Thread.sleep(1000) // 1초 동안 대기
    println("[${Thread.currentThread().name}] 메인 스레드 end")
}
```

아래와 같이 메인 스레드가 종료되면 데몬 스레드는 실행 중에 강제 종료된다.  
데몬 스레드는 중요한 스레드가 아니기 때문에 강제 종료되더라도 프로세스가 정상 종료된다.

```shell
[main] 메인 스레드 start
[Thread-0] 새로운 스레드 start
[main] 메인 스레드 end
```

> **데몬 스레드**
> 
> 주로 백그라운드 작업이나 보조 작업을 수행할 때 사용함  
> 예) Garbage Collector, 스케줄러, 리소스 모니터링  
> 사용자 스레드와 달리 모든 사용자 스레드가 종료되면 자동으로 종료되므로 반드시 사용자 스레드가 동작하는 동안에만 실행됨
> 
> 데몬 스레드는 작업이 완료되기 않더라도 프로그램이 종료될 수 있으므로 중요하거나, 긴 작업은 맡기면 안됨  
> 주로 리소스 정리, 주기적 체크, 백그라운드 로깅 등에 사용함

---

### 3.1.2. `Thread` 클래스를 직접 다룰 때의 한계

`Thread` 클래스를 직접 다뤄서 새로운 스레드로 작업을 실행하는 방법에는 두 가지 문제점이 있다.
- **`Thread` 클래스를 상속한 클래스를 인스턴스화하여 실행할 때마다 매번 새로운 스레드가 생성됨**
  - 스레드는 생성 비용이 비싸기 때문에 매번 새로운 스레드를 생성하는 것은 성능상 불리함
- **스레드 생성과 관리에 대한 책임이 개발자에게 있음**
  - 프로그램의 복잡성이 증가하고, 실수로 인해 메모리 누수가 발생할 수 있음

이를 해결하려면 한 번 생성한 스레드를 간편히 재사용할 수 있어야 하고, 스레드의 관리를 미리 구축한 시스템에서 책임질 수 있도록 해야하는데 이런 역할을 위해 
`Executor` 프레임워크가 만들어졌다.

---

## 3.2. `Executor` 프레임워크를 통한 스레드풀 사용

`Executor` 프레임워크는 개발자가 스레드를 직접 관리하는 문제를 해결하고, 생성된 스레드의 재사용성을 높이기 위해 등장했다.  
**`Executor` 프레임워크는 스레드풀을 관리하여 사용자로부터 요청작은 작업을 각 스레드에 할당하는 방식**이다.

스레드풀을 미리 생성해놓고, 작업을 요청받으면 쉬는 스레드에 작업을 분배하며, 각 스레드가 작업을 끝내더라도 스레드를 종료하지 않고 다음 작업이 들어오면 재사용한다.

이렇게 스레드풀에 속한 스레드의 생성과 관리 및 작업 분배에 대한 책임은 `Executor` 프레임워크가 담당하고, 
개발자는 스레드풀에 속한 스레드의 개수 설정만 하면 된다.

---

### 3.2.1. `Executor` 프레임워크 사용

`Executor` 프레임워크에서 사용자가 사용할 수 있는 함수는 크게 2가지가 있다.
- 스레드풀을 생성하고 생성된 스레드풀을 관리하는 객체를 반환받는 함수
- 스레드풀을 관리하는 객체에 작업을 제출하는 함수

```kotlin
package chap01

import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

fun main() {
    val startTime = System.currentTimeMillis()
    // ExecutorService 생성(스레드 개수는 2로 설정)
    val executorService: ExecutorService = Executors.newFixedThreadPool(2)

    // 작업 1 제출
    executorService.submit {
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 1 시작~")
        Thread.sleep(1000L) // 1초간 대기
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 1 완료~")
    }

    // 작업 2 제출
    executorService.submit {
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 2 시작~")
        Thread.sleep(1000L) // 1초간 대기
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 2 완료~")
    }

    // ExecutorService 종료
    executorService.shutdown()
}

fun getElapsedTime(startTime: Long): String = "지난 시간: ${System.currentTimeMillis() - startTime} ms"
```

```shell
[pool-1-thread-1][지난 시간: 3 ms] 작업 1 시작~
[pool-1-thread-2][지난 시간: 3 ms] 작업 2 시작~
[pool-1-thread-1][지난 시간: 1015 ms] 작업 1 완료~
[pool-1-thread-2][지난 시간: 1015 ms] 작업 2 완료~
```

작업 1과 작업 2는 각각 다른 스레드에서 수행되었고, 각 작업이 끝난 시간이 1015ms 인 것으로 보아 병렬 실행되었음을 확인할 수 있다.  
이제 추가로 작업 3을 추가해보자.

```kotlin
package chap01

import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

fun main() {
    val startTime = System.currentTimeMillis()
    // ExecutorService 생성(스레드 개수는 2로 설정)
    val executorService: ExecutorService = Executors.newFixedThreadPool(2)

    // 작업 1 제출
    executorService.submit {
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 1 시작~")
        Thread.sleep(1000L) // 1초간 대기
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 1 완료~")
    }

    // 작업 2 제출
    executorService.submit {
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 2 시작~")
        Thread.sleep(1000L) // 1초간 대기
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 2 완료~")
    }

    // 작업 3 제출
    executorService.submit {
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 3 시작~")
        Thread.sleep(1000L) // 1초간 대기
        println("[${Thread.currentThread().name}][${getElapsedTime(startTime)}] 작업 3 완료~")
    }

    // ExecutorService 종료
    executorService.shutdown()
}

fun getElapsedTime(startTime: Long): String = "지난 시간: ${System.currentTimeMillis() - startTime} ms"
```

```shell
[pool-1-thread-2][지난 시간: 3 ms] 작업 2 시작~
[pool-1-thread-1][지난 시간: 3 ms] 작업 1 시작~
[pool-1-thread-1][지난 시간: 1016 ms] 작업 1 완료~
[pool-1-thread-2][지난 시간: 1016 ms] 작업 2 완료~
[pool-1-thread-1][지난 시간: 1017 ms] 작업 3 시작~
[pool-1-thread-1][지난 시간: 2023 ms] 작업 3 완료~
```

작업 1과 2는 병렬로 실행되었지만 작업 3은 작업 1이 완료된 후에 작업 1이 사용하던 스레드에서 실행되었다.  
작업 3이 실행되었을 때 스레드풀에 있는 2개의 스레드가 이미 작업 1과 2를 처리하고 있었기 때문이다.

---

### 3.2.2. `Executor` 프레임워크 내부 구조

![ExecutorService 내부 구조](/assets/img/dev/2024/1020/executor.png)

작업 대기열은 할당받은 작업을 적재하고, 스레드풀은 작업을 수행하는 스레드의 집합이다.  
`ExecutorService` 객체는 사용자로부터 요청받은 작업을 작업 대기열에 적재한 후 쉬고 있는 스레드에 작업을 할당한다.  
모든 스레드가 작업을 실행 중인데 추가로 작업 3을 요청하면 이 작업은 작업 대기열에 적재되어 머물게 되고, 스레드 중 작업이 완료된 스레드가 있으면 해당 스레드로 할당되어 
작업을 실행한다.

개발자는 스레드풀을 구성할 스레드의 개수를 지정하고, `ExecutorService` 에 작업을 제출하기만 하면 된다.

---

### 3.2.3. `Executor` 프레임워크 한계: 스레드 블로킹

`Executor` 프레임워크의 대표적인 문제점 중 하나는 바로 스레드 블로킹이다.

스레드 블로킹은 스레드가 아무것도 하지 못하고 사용될 수 없는 상태에 있는 것이다.  
스레드는 비싼 자원이기 때문에 사용될 수 없는 상태에 놓이는 것이 반복되면 애플리케이션의 성능이 떨어지게 된다.

<**스레드 블로킹을 발생시키는 원인**>
- 여러 스레드가 동기화 블록에 동시에 접근하는 경우 하나의 스레드만 동기화 블록에 접근이 허용되기 때문에 발생
- [뮤텍스(Mutex) 나 세마포어(Semaphore)](https://assu10.github.io/dev/2024/10/20/mutex-semaphore/) 로 인해 공유되는 자원에 접근할 수 있는 스레드가 제한되는 경우

`ExecutorService` 객체에 제출한 작업에서 결과를 전달받을 때는 언제 올 지 모르는 값을 기다리는데 사용하는 `Future` 객체를 사용한다.  
`Future` 객체는 미래에 언제 올지 모르는 값을 기다리는 함수인 `get()` 함수가 있는데, 이 함수를 호출하면 `get()` 함수를 호출한 스레드가 결과값이 반환될 
때까지 블로킹된다.

`Future` 의 `get()` 함수가 스레드를 블로킹하는 예시
```kotlin
package chap01

import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

fun main() {
    val executorService: ExecutorService = Executors.newFixedThreadPool(2)
    val future: Future<String> = executorService.submit<String> {
        Thread.sleep(1000L)
        return@submit "작업1 완료"
    }
    val result = future.get() // 메인 스레드가 블로킹됨
    println(result)
    executorService.shutdown()
}
```

위 코드는 `ExecutorService` 객체를 생성한 후 문자열을 반환받는 작업을 제출한다.  
`Future` 객체의 `get()` 함수를 호출하면 `get()` 함수를 호출한 스레드는 `Future` 객체가 결과값을 반환할 때까지 스레드 블로킹하며 결과를 기다린다.  
위에선 메인 스레드가 future.get() 을 호출하고 있기 때문에 제출한 작업의 결과가 반환될 때까지 메인 스레드가 블로킹된다.

![스레드 블로킹](/assets/img/dev/2024/1020/thread_blocking.png)

스레드 블로킹을 일으키는 가장 대표적인 함수는 `Thread.sleep()` 이다.  
`Thread.sleep()` 은 스레드가 대기하도록 명령받은 시간 동안 해당 스레드를 블로킹시킨다.  
즉, 실제로 해당 스레드가 사용되고 있지 않음에도 불구하고 해당 스레드에서 다른 작업이 진행되지 못하게 된다.

---

# 4. 기존 멀티 스레드 프로그래밍의 한계와 코루틴

## 4.1. 멀티 스레드 프로그래밍의 한계

`Executor` 프레임워크 등장 이후에도 기존의 문제점을 보완하기 위해 다양한 방법이 나왔다.
- `CompletetableFuture` 객체 등장
  - java 1.8 에서 기존의 `Future` 객체의 단점을 보완하기 위해 스레드 블로킹을 줄이고 작업을 체이닝하는 기능을 제공함
- `RxJava` 등장
  - 리액티브 프로그래밍 패러다임 지원
  - 결과값을 데이터 스트림으로 전환함으로써 스레드 블로킹을 방지하고, 작업이 실행되는 스레드풀을 손쉽게 전환할 수 있음

코루틴과 관련하여 이들 모두 근본적인 한 가지 문제점을 갖고 있는데 그 문제점에 대해 알아보자.

**멀티 스레드 프로그래밍은 스레드 기반으로 작업한다는 한계**를 갖고 있다.  
여기서는 멀티 스레드 프로그래밍에서 스레드 기반으로 작업할 때 생기는 문제에 대해 알아본다.

스레드는 생성 비용과 전환 비용이 비싸기 때문에 스레드가 아무 작업을 하지 못하고 기다려야 한다면 이는 자원 낭비가 된다.

![스레드 블로킹](/assets/img/dev/2024/1020/thread_blocking_2.png)

위 상황에서 스레드 1은 스레드 2 작업이 완료될 때까지 아무것도 하지 못하고 대기하게 되는데 이렇게 하나의 스레드가 다른 스레드에서 수행하는 작업이 완료될 때까지 사용할 수 
없게 되는 것이 스레드 블로킹이다.  
스레드 블로킹은 스레드라는 비싼 자원을 사용할 수 없게 만든다는 점에서 성능에 매우 치명적인 영향을 준다.

스레드 블로킹은 스레드 기반 작업을 하는 멀티 스레드 프로그래밍에서 피할 수 없는 문제이다.  
간단한 작업은 콜백을 사용하거나 [체이닝 함수](https://assu10.github.io/dev/2024/10/26/chaining/)를 사용하여 스레드 블로킹을 피할 수 있지만, 실제 애플리케이션은 작업 간의 종속성이 복잡하기 때문에 스레드 블로킹이 발생할 수 밖에 없다.

---

## 4.2. 코루틴의 스레드 블로킹 문제 극복: 경량 스레드

**코루틴은 작업 단위 코루틴을 통해 스레드 블로킹 문제를 극복**한다.

작업 단위 코루틴은 스레드에서 작업 실행 도중 일시 중단할 수 있는 작업 단위로, 작업이 일시 중단되면 더 이상 스레드 사용이 필요하지 않으므로 스레드의 사용 권한을 양보하고 
양보된 스레드는 다른 작업을 실행하는데 사용되기 때문에 스레드 블로킹이 일어나지 않게 된다.  
일시 중단된 코루틴은 재개 시점에 다시 스레드에 할당되어 실행된다.  
이렇게 스레드에 코루틴을 붙였다 뗐다 할 수 있기 때문에 코루틴을 **경량 스레드**라고 부른다.

[4.1. 멀티 스레드 프로그래밍의 한계](#41-멀티-스레드-프로그래밍의-한계) 에서는 작업 1이 작업 2의 결과가 필요하여 중간에 스레드 블로킹이 발생했는데 여기에 추가로 
독립적인 작업 3이 발생했을 때의 상황을 멀티 스레드 프로그래밍 방식과 코루틴을 사용하여 스레드 블로킹을 방지하는 경우로 비교해보자.

![스레드 블로킹이 발생할 때 작업 순서](/assets/img/dev/2024/1020/thread_blocking_3.png)

![코루틴을 사용하여 스레드 블로킹 방지](/assets/img/dev/2024/1020/coroutine.png)

코루틴은 자신이 스레드를 사용하지 않을 때 스레드 사용 권한을 반납하고, 사용 권한이 반납되면 그 스레드에서는 다른 코루틴이 실행될 수 있다.

위 그림을 보면 코루틴 1 실행 중에 코루틴 2의 결과가 필요해져서 코루틴 1은 결과가 반환될 때까지 스레드 1 의 사용 권한을 반납하고 일시 중단한다.  
그러면 스레드 1 이 사용 가능해지기 때문에 코루틴 3이 스레드 1에서 실행될 수 있다.  
이 후 코루틴 2 의 실행이 완료된 시점에 스레드 1 도 사용 가능하고 스레드 2도 사용 가능하므로 코루틴의 남은 작업을 스레드 1이나 2가 할당받아서 진행하게 된다.

코루틴은 이런 방식으로 스레드를 효율적으로 사용한다.

---

**작업 단위로서의 코루틴이 스레드를 사용하지 않을 때 스레드 사용 권한을 양보하는 방식으로 스레드 사용을 최적화하고, 스레드가 블로킹되는 상황을 방지**한다.  
또한 코루틴은 스레드에 비해 생성과 전환 비용이 적게 들고, 스레드에 자유롭게 붙였다 뗐다 할 수 있어서 작업을 생성하고 전환하는데 필요한 리소스와 시간이 매우 줄어든다.  
이것이 코루틴이 **경량 스레드**라고 불리는 이유이다.

이 뿐 아니라 코루틴은 구조화된 동시성을 통해 비동기 작업을 안전하게 하고, 예외 처리를 효과적으로 처리하며, 코루틴이 실행 중인 스레드를 손쉽게 전환할 수 있는 장점이 있다.

---

# 정리하며..

- JVM 에서 실행되는 코틀린 애플리케이션은 실행 시 메인 스레드를 생성하고, 메인 스레드를 사용하여 코드를 실행함
- 단일 스레드 애플리케이션은 한 번에 하나의 작업만 수행이 가능하기 때문에 응답성이 떨어질 수 있음
- 멀티 스레드 프로그래밍을 사용하면 여러 작업을 동시에 실행할 수 있어서 단일 스레드 프로그래밍의 문제점을 해결할 수 있음
- 직접 `Thread` 클래스를 상속하여 스레드를 생성하고 관리할 수 있지만, 생성된 스레드의 재사용이 어려워 리소스 낭비가 발생할 수 있음
- `Executor` 프레임워크는 스레드풀을 사용하여 스레드의 생성과 관리를 최적화하고, 스레드 재사용을 용이하게 함
- `Executor` 프레임워크를 비롯하여 기존의 멀티 스레드 프로그래밍 방식들은 스레드 블로킹 문제를 근복적으로 해결하지 못함
- 스레드 블로킹은 스레드가 작업을 기다리면서 리소스를 소비하지만 아무 일도 하지 않는 상태를 말함
- 코루틴은 스레드 블로킹을 해결하기 위해 등장함
  - 필요할 때 스레드 사용 권한을 양보하고 일시 중단하면 다른 작업이 스레드를 사용할 수 있음
  - 일시 중단 후 재개된 코루틴은 재개 시점에 사용 가능한 스레드에 할당되어 실행됨
- 코루틴은 스레드와 비교했을 때 생성과 전환 비용이 적게 들고, 스레드에 자유롭게 붙였다 뗐다 할 수 있어서 경량 스레드라고 불림
- 코루틴을 사용하면 스레드 블로킹없이 비동기적으로 작업 처리가 가능하여 애플리케이션의 응답성을 크게 향상시킬 수 있음

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)