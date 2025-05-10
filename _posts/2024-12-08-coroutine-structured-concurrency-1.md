---
layout: post
title:  "Coroutine - 구조화된 동시성과 부모-자식 관계(1): 실행 환경 상속, 코루틴의 구조화"
date: 2024-12-08
categories: dev
tags: kotlin coroutine
---

**구조화된 동시성(Structured Concurrency)** 은 코루틴을 안정적으로 관리하고 예측 가능한 방식으로 동작하게 만드는 핵심 원칙이다. 
이 원칙은 **부모-자식 관계를 기반으로 코루틴을 계층적으로 구조화**하고, 이를 통해 취소/예외 처리/자원 해제 등의 문제를 체계적으로 해결할 수 있게 한다.

<**구조화된 동시성 원칙**>
- 코루틴은 반드시 유효한 생명 주기를 가진 범위(CoroutineScope) 내에서 실행된다.
- CoroutineScope 를 사용하여 코루틴이 실행되는 범위를 제한할 수 있다.
- 부모 코루틴의 실행 환경은 자식 코루틴에게 상속된다.
- 부모 코루틴은 자식 코루틴이 완료될 때까지 종료되지 않는다.
- 부모가 취소되면 자식들도 함께 취소된다.

코루틴을 부모-자식 관계로 구조화하는 방법은 부모 코루틴을 만드는 코루틴 빌더의 람다식 속에서 새로운 코루틴 빌더를 호출하면 된다.

아래는 `runBlocking()` 함수의 람다식 내부에서 `launch()` 코루틴을 중첩하여 부모-자식 관계로 구조화하는 예시이다.

```kotlin
fun main() = runBlocking<Unit> {
    launch { // 부모 코루틴
        launch { // 자식 코루틴
            println("자식 코루틴 실행")
        }
    }
}
```

위 코드에서 `runBlocking()` 은 최상위 코루틴이며, 첫 번째 `launch()` 는 그 자식 코루틴이다. 안쪽의 `launch()` 는 그 자식의 자식, 즉 손자 코루틴이 된다. 
부모 코루틴이 종료되기 전까지 모든 자식 코루틴이 완료되어야 한다.

<**구조화된 코루틴 특징**>
- **상속**
  - 부모의 CoroutineContext (Dispatcher 등) 를 자식이 자동 상속
- **제어**
  - 부모에서 자식 작업을 취소하거나 대기 가능
- **취소 전파**
  - 부모가 `cancel()` 되면 자식들도 자동으로 취소
- **완료 대기**
  - 부모는 자식 코루틴이 모두 완료될 때까지 대기

각 코루틴을 구조화하면 아래 그림과 같다.

![구조화된 코루틴](/assets/img/dev/2024/1208/structured_coroutine.png)

이 포스트에서는 아래에 대해 알아본다.
- 코루틴의 실행 환경 상속
- 구조화를 통한 작업 제어
- CoroutineScope 를 사용한 코루틴 관리
- 코루틴의 구조화에서의 Job 역할

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 실행 환경 상속: CoroutineContext 의 전파 방식](#1-실행-환경-상속-coroutinecontext-의-전파-방식)
  * [1.1. 부모 코루틴의 실행 환경 상속](#11-부모-코루틴의-실행-환경-상속)
  * [1.2. 실행 환경 덮어씌우기](#12-실행-환경-덮어씌우기)
  * [1.3. 상속되지 않는 Job](#13-상속되지-않는-job)
  * [1.4. 구조화에 사용되는 Job](#14-구조화에-사용되는-job)
* [2. 코루틴의 구조화와 작업 제어](#2-코루틴의-구조화와-작업-제어)
  * [2.1. 취소의 전파(Cancellation Propagation)](#21-취소의-전파cancellation-propagation)
  * [2.2. 부모 코루틴의 자식 코루틴에 대한 완료 의존성](#22-부모-코루틴의-자식-코루틴에-대한-완료-의존성)
    * [2.2.1. `실행 완료 중` 상태](#221-실행-완료-중-상태)
    * [2.2.2. `실행 완료 중` 상태의 Job 상태값](#222-실행-완료-중-상태의-job-상태값)
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

# 1. 실행 환경 상속: CoroutineContext 의 전파 방식

[Coroutine - CoroutineContext 구조, 접근, 제거](https://assu10.github.io/dev/2024/11/23/coroutine-coroutine-context/) 에서는 CoroutineContext 를 
사용하여 코루틴 실행 환경을 설정하는 방법에 대해 알아보았다.

코루틴은 생성 시점에 **CoroutineContext** 를 기반으로 실행 환경을 설정한다. 이 실행 환경은 부모 코루틴으로부터 자식 코루틴에게 **자동으로 상속**되며, 이를 통해 
**동일한 Dispatcher, CoroutineName, Job 등의 컨텍스트 요소를 공유**하게 된다.

---

## 1.1. 부모 코루틴의 실행 환경 상속

아래는 부모 코루틴에서 명시적으로 설정한 CoroutineContext 가 자식 코루틴에게 자동으로 상속되는 예시이다.
```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val myCoroutineContext = newSingleThreadContext("MyThread") + CoroutineName("CoroutineA")
    launch(context = myCoroutineContext) { // 부모 코루틴 생성
        println("[${Thread.currentThread().name}] 부모 코루틴 실행")
        launch { // 자식 코루틴 생성
            println("[${Thread.currentThread().name}] 자식 코루틴 실행")
        }
    }
}
```

- 부모 코루틴은 _MyThread_ 라는 이름의 단일 스레드와 _CoroutineA_ 라는 이름을 갖는 CoroutineContext 에서 실행됨
- 자식 코루틴은 별도의 context 를 지정하지 않았음에도 **동일한 스레드(_MyThread_) 와 CoroutineName(_CoroutineA_)** 를 사용함
- 이는 자식 코루틴이 **부모의 CoroutineContext 를 자동 상속받기 때문**임

```shell
[MyThread @CoroutineA#2] 부모 코루틴 실행
[MyThread @CoroutineA#3] 자식 코루틴 실행
```

myCoroutineContext 는 아래와 같은 형태로 이루어져 있다.

| 키                     | 값                                  |
|-----------------------|------------------------------------|
| CoroutineDispatcher 키 | newSingleThreadContext("MyThread") |
| CoroutineName 키       | CoroutineName("CoroutineA")        |

※ Job 은 자동으로 포함되어 있으며, 구조화된 동시성에서 핵심 역할을 함

하지만 **항상 모든 실행 환경을 상속하는 것은 아니다.** 어떤 경우에 실행 환경이 상속되지 않는지 알아보자.

---

## 1.2. 실행 환경 덮어씌우기

위에서 본 것처럼 자식 코루틴은 기본적으로 부모 코루틴의 CoroutineContext 를 상속한다.  
하지만, **자식 코루틴을 생성할 때 별도의 CoroutineContext 를 명시하면 해당 항목은 부모의 설정을 덮어씌운다.**

이로 인해 자식 코루틴은 부분적으로는 **부모의 실행 환경을 상속**하면서도, **필요한 부분만 독립적으로 설정**할 수 있다.

```kotlin
package chap07

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val myCoroutineContext = newSingleThreadContext("MyThread") + CoroutineName("ParentCoroutine")
    launch(context = myCoroutineContext) {// 부모 코루틴 생성
        println("[${Thread.currentThread().name}] 부모 코루틴 실행")
        launch(CoroutineName("ChildCoroutine")) { // 자식 코루틴 생성
            println("[${Thread.currentThread().name}] 자식 코루틴 실행")
        }
    }
}
```

```shell
[MyThread @ParentCoroutine#2] 부모 코루틴 실행
[MyThread @ChildCoroutine#3] 자식 코루틴 실행
```

|         항목          | 부모 코루틴          | 자식 코루틴              |
|:-------------------:|:----------------|:--------------------|
| CoroutineDispatcher | MyThread(동일)    | MyThread(상속)        |
|    CoroutineName    | ParentCoroutine | ChildCoroutine(덮어씀) |

- CoroutineDispatcher 는 명시하지 않았기 때문에 부모로부터 상속
- CoroutineName 은 명시적으로 설정했기 때문에 부모의 값을 덮어씀
즉, 자식 코루틴은 **명시한 항목만 재정의하고, 나머지는 부모로부터 상속**받는다.

---

## 1.3. 상속되지 않는 Job

주의할 점은 다른 CoroutineContext 구성 요소와는 다르게 Job 객체는 상속되지 않는다. `launch()` 나 `async()` 같은 코루틴 빌더는 
호출할 때마다 새로운 Job 객체를 생성한다.

이유는 **모든 코루틴은 독립적으로 취소, 완료 등을 제어할 수 있어야 하므로, 서로 다른 Job 인스턴스를 가져야 하기 때문**이다.

```kotlin
package chap07

import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 부모 코루틴 생성
    // 부모 코루틴의 CoroutineContext 로부터 부모 코루틴의 Job 추출
    val myRunBlockingJob: Job? = coroutineContext[Job] // coroutineContext[Job.Key] 와 동일
    launch { // 자식 코루틴 생성
        // 자식 코루틴의 CoroutineContext 로부터 자식 코루틴의 Job 추출
        val myLaunchJob: Job? = coroutineContext[Job]
        if (myRunBlockingJob === myLaunchJob) {
            println("runBlocking 으로 생성된 Job 과 launch 로 생성된 Job 은 동일함")
        } else {
            println("runBlocking 으로 생성된 Job 과 launch 로 생성된 Job 은 동일하지 않음")
        }
    }
}
```

```shell
runBlocking 으로 생성된 Job 과 launch 로 생성된 Job 은 동일하지 않음
```

이처럼 각각의 코루틴은 서로 다른 Job 객체를 가지고 실행된다.

> coroutineContext\[Job\] 은 현재 코루틴의 Job 객체를 가져오는 표현이다.  
> Job 은 구조화된 동시성의 핵심 요소이므로, 상속 대신 **새로 생성되지만 부모-자식 관계로 연결**된다.
>
> [coroutineContext\[Job\] == coroutineContext\[Job.Key\] 임](https://assu10.github.io/dev/2024/11/23/coroutine-coroutine-context/#322-%EA%B5%AC%EC%84%B1-%EC%9A%94%EC%86%8C-%EC%9E%90%EC%B2%B4%EB%A5%BC-%ED%82%A4%EB%A1%9C-%EC%82%AC%EC%9A%A9%ED%95%98%EC%97%AC-%EA%B5%AC%EC%84%B1-%EC%9A%94%EC%86%8C%EC%97%90-%EC%A0%91%EA%B7%BC-coroutinename)

그렇다면 부모 코루틴의 Job 객체는 자식 코루틴의 Job 객체와 아무런 관계도 없는 것일까? 그렇지 않다. 
**자식 코루틴이 부모 코루틴으로부터 전달받은 Job 객체는 코루틴을 구조화하는데 사용**된다.

---

## 1.4. 구조화에 사용되는 Job

코루틴 빌더에 의해 생성된 Job 객체는 단순히 독립적인 인스턴스로 끝나는 것이 아니다.  
**각 Job 은 parent 와 children 프로퍼티를 통해 상하 관계를 구성**하며, 이 구조를 통해 **구조화된 동시성이** 구현된다.

구조화의 의미는 부모가 취소되면 자식도 함께 취소되며, 생명 주기를 함께 관리한다는 의미이다.  
이 구조화는 실전에서 코루틴의 취소 전파, 완료 대기, 예외 처리 등에 필수적으로 사용된다.

코루틴 빌더가 호출되면 Job 객체는 새롭게 생성되거나 생성된 Job 객체는 아래 그림과 같이 내부에 정의된 parent 프로퍼티를 통해 부모 코루틴의 Job 객체에 대한 참조를 가진다.
또한 부모 코루틴의 Job 객체는 Sequence 타입의 children 프로퍼티를 통해 자식 코루틴의 Job 객체에 대한 참조를 가져 자식 코루틴의 Job 객체와 부모 코루틴의 Job 객체는 
양방향 참조를 가진다.

![구조화에 사용되는 Job](/assets/img/dev/2024/1208/job.png)

<Job 의 parent, children 프로퍼티>

| Job 프로퍼티 |       타입        | 설명                                            |
|:--------:|:---------------:|:----------------------------------------------|
|  `parent`  |      Job?       | 부모 Job (없을 수도 있으므로 nullable)                  |
|  `child`   | Sequence\<Job\> | 자식 Job 목록 (0개 이상) |

하나의 코루틴은 **부모는 최대 1개, 자식은 여러 개** 가질 수 있다. 또한 **양방향 참조 구조**로 코루틴 간 의존성을 표현한다.

아래는 parent 프로퍼티와 children 프로퍼티가 어떤 객체를 참조하는지 확인하는 예시이다.

```kotlin
package chap07

import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // 부모 코루틴
    // 부모 코루틴의 CoroutineContext 로부터 부모 코루틴의 Job 추출
    val parentJob: Job? = coroutineContext[Job]
    launch { // 자식 코루틴
        // 자식 코루틴의 CoroutineContext 로부터 자식 코루틴의 Job 추출
        val childJob: Job? = coroutineContext[Job]
        println("부모 코루틴과 자식 코루틴의 Job 이 같은가? ${parentJob === childJob}")
        println("자식 코루틴의 Job 이 가지고 있는 parent 는 부모 코루틴의 Job 인가? ${childJob?.parent === parentJob}")
        println("부모 코루틴의 Job 은 자식 코루틴의 Job 을 참조를 가지는가? ${parentJob?.children?.contains(childJob)}")
    }
}
```

```shell
부모 코루틴과 자식 코루틴의 Job 이 같은가? false
자식 코루틴의 Job 이 가지고 있는 parent 는 부모 코루틴의 Job 인가? true
부모 코루틴의 Job 은 자식 코루틴의 Job 을 참조를 가지는가? true
```

위 코드를 보면
- `launch()` 로 생성된 자식 코루틴은 새로운 Job 을 가지며, 부모의 Job 과는 다른 객체이다.
- 하지만 자식의 Job.parent 는 부모의 Job 을 참조하고,
- 부모의 Job.children 은 자식 Job 을 포함한다.

이처럼 Job 간 연결을 통해 코루틴이 **계층 구조로 구조화**된다.

> 이렇게 Job 은 코루틴의 구조화에서 핵심적인 역할을 하는데 이에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다. (p. 202)

---

# 2. 코루틴의 구조화와 작업 제어

구조화된 동시성의 핵심은 단지 코루틴을 부모-자식 관계로 구성하는데 그치지 않는다.  
진짜 목적은 **복잡한 비동기 작업을 안전하게 제어**하고, **명확한 생명 주기와 취소 전략을 제공**하는데 있다.

> 코루틴 구조화는 네트워크 요청, 파일 처리, UI 상태 관리 등에서 자주 활용함

하나의 **큰 비동기 작업은 작은 비동기 작업들로 구조화**할 수 있다.  
예를 들어 아래와 같은 시나리오를 생각해보자.  
예) 여러 서버에서 데이터를 다운로드하고, 다운로드된 데이터를 합치는 작업

아래는 이 작업을 코루틴으로 구조화한 예시이다.
- 최상위 코루틴: 전체 데이터를 다운로드하고 변환하는 작업
- 중간 단계 코루틴: 여러 서버로부터 데이터를 다운로드
- 하위 단계 코루틴: 개별 서버로부터 데이터를 다운로드

![구조화된 코루틴](/assets/img/dev/2024/1208/structured_coroutine2.png)

이처럼 **큰 작업을 작은 코루틴 단위로 분할**하고, 이들을 **부모-자식 관계로 계층화**하면 코루틴을 안전하게 관리하고 제어할 수 있다.

<**구조화된 코루틴의 특징**>
- **취소 전파**
  - 부모 코루틴이 취소되면 자식 코루틴도 자동으로 취소됨
- **완료 대기**
  - 부모 코루틴은 자식 코루틴이 모두 완료될 때까지 종료되지 않음
- **예외 전파**
  - 자식 코루티니에서 예외가 발생하면, 그 예외는 부모로 전파되어 전체 작업을 중단시킬 수 있음
- **자원 관리 용이**
  - 자식 코루틴의 생명 주기를 부모가 함께 관리하기 때문에 누수없이 자원을 해제할 수 있음

아래 코드를 보자.
```kotlin
runBlocking {
    launch {
        val deferred1 = async { downloadFromServer1() }
        val deferred2 = async { downloadFromServer2() }

        val combined = deferred1.await() + deferred2.await()
        launch { transform(combined) }
    }
}
```

위 코드는 구조화된 동시성 하에 아래를 보장한다.
- runBlocking() 이 끝나기 전까지 모든 작업이 완료됨
- 어느 하나라도 실패하면 전체 취소됨
- 예외 및 취소 처리가 부모 코루틴 수준에서 통제 가능함

---

## 2.1. 취소의 전파(Cancellation Propagation)

구조화된 코루틴에서 가장 중요한 제어 중 하나는 **취소 전파(Cancellation Propagation)** 이다.  
부모 코루틴이 취소되면 **하위의 모든 자식 코루틴도 함께 취소**되어, 불필요한 작업이 중단되고 리소스 낭비를 방지할 수 있다.  
자식 코루틴은 부모 코루틴의 작업 일부로 간주되므로, **부모가 종료되면 자식도 의미가 없어진다.**

<**코루틴의 취소 전파**>
- **자식 방향으로만 전파됨**
  - 부모 코루틴이 취소되면 자식 코루틴도 취소됨
- **역방향 전파 없음**
  - 자식이 취소되더라도 부모는 계속 실행될 수 있음
- **리소스 낭비 방지**
  - 부모가 더 이상 필요없는 작업을 미리 중단

예를 들어 3개의 DB 로부터 데이터를 가져와 합치는 작업을 하는 코루틴인 parentJob 이 있다고 해보자.

```kotlin
package chap07

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
  val parentJob = launch(context = Dispatchers.IO) { // 부모 코루틴
    val dbResultsDeferred: List<Deferred<String>> = listOf("db1", "db2", "db3").map {
      async { // 자식 코루틴 생성
        delay(1000L) // DB 로부터 데이터를 가져오는데 걸리는 시간
        println("${it} 으로부터 데이터 가져옴")
        return@async "(${it}) Data~"
      }
    }
    // 모든 코루틴이 완료될 때까지 대기
    val dbResults: List<String> = dbResultsDeferred.awaitAll()
    println(dbResults)
  }
}
```

```shell
db1 으로부터 데이터 가져옴
db3 으로부터 데이터 가져옴
db2 으로부터 데이터 가져옴
[(db1) Data~, (db2) Data~, (db3) Data~]
```

![구조화된 코루틴](/assets/img/dev/2024/1208/structured_coroutine3.png)

`launch()` 함수를 통해 생성되는 부모 코루틴은 `async()` 함수를 사용하여 각 db 로부터 데이터를 가져오는 작업을 하는 자식 코루틴을 3개 생성한다.  
만일 작업 중간에 부모 코루틴이 취소된다면 자식 코루틴이 하던 작업은 더 이상 진행될 필요가 없다. 부모 코루틴이 취소됐는데도 자식 코루틴이 계속해서 실행된다면 
자식 코루틴이 반환하는 결과를 사용할 곳이 없기 때문에 리소스 낭비가 될 것이다.

이런 상황을 방지하기 위해 부모 코루틴에 취소를 요청하면 자식 코루틴으로 취소가 전파된다.

아래는 부모 코루틴 parentJob 에 취소를 요청하는 예시이다.

```kotlin
package chap07

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val parentJob = launch(context = Dispatchers.IO) { // 부모 코루틴
        val dbResultsDeferred: List<Deferred<String>> = listOf("db1", "db2", "db3").map {
            async { // 자식 코루틴 생성
                delay(1000L) // DB 로부터 데이터를 가져오는데 걸리는 시간
                println("${it} 으로부터 데이터 가져옴")
                return@async "(${it}) Data~"
            }
        }
        // 모든 코루틴이 완료될 때까지 대기
        val dbResults: List<String> = dbResultsDeferred.awaitAll()
        println(dbResults)
    }

    // 부모 코루틴에 취소 요청
    parentJob.cancel()
}
```

parentJob.cancel() 호출 직후 부모 코루틴과 자식 코루틴이 모두 취소되는데 이 시점은 println() 이 호출되기 전이므로 아무것도 출력되지 않는다.

---

## 2.2. 부모 코루틴의 자식 코루틴에 대한 완료 의존성

구조화된 코루틴에서 부모-자식 관계 코루틴은 단순한 호출 관계가 아니라, **완료 시점까지도 밀접하게 연결**된다.  
즉, **부모 코루틴은 모든 자식 코루틴이 완료되어야만 종료**될 수 있다.  
이 관계를 **완료 의존성**이라고 한다.  
이는 코루틴 구조화의 핵심 원칙 중 하나로, **전체 작업이 부분 작업의 완료에 의존함**을 의미한다.

부모가 자식의 완료를 기다리는 예시
```kotlin
package chap07

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking <Unit>{
    val startTime = System.currentTimeMillis()
    val parentJob = launch {// 부모 코루틴 실행
        launch { // 자식 코루틴 실행
            delay(1000L) // 1초간 대기
            println("[${getElapsedTime(startTime)}] 자식 코루틴 실행 완료")
        }
        println("[${getElapsedTime(startTime)}] 부모 코루틴이 실행하는 마지막 코드")
    }
    parentJob.invokeOnCompletion { // 부모 코루틴이 종료될 시 호출되는 콜백 등록
        println("[${getElapsedTime(startTime)}] 부모 코루틴 실행 완료")
    }
}

fun getElapsedTime(startTime: Long): String = "지난 시간: ${System.currentTimeMillis() - startTime} ms"
```

```shell
[지난 시간: 5 ms] 부모 코루틴이 실행하는 마지막 코드
[지난 시간: 1014 ms] 자식 코루틴 실행 완료
[지난 시간: 1014 ms] 부모 코루틴 실행 완료
```

- 부모 코루틴의 마지막 코드를 즉시 실행됨
- 하지만 부모는 **자식 코루틴의 완료를 기다린 뒤 종료**됨
- 이 사이 부모는 **`실행 완료 중`** 상태에 머물게 됨

`invokeOnCompletion()` 은 코루틴이 실행 완료되거나 취소 완료됐을 때 실행되는 콜백을 등록하는 함수이다.

---

### 2.2.1. `실행 완료 중` 상태

코루틴 상태 다이어그램 중 `실행 완료 중` 은 부모 코루틴이 모든 자체 코드를 실행했지만, **자식 코루틴이 아직 완료되지 않아 종료를 유예하는 상태**이다.

[6. 코루틴의 상태와 Job 의 상태 변수](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#6-%EC%BD%94%EB%A3%A8%ED%8B%B4%EC%9D%98-%EC%83%81%ED%83%9C%EC%99%80-job-%EC%9D%98-%EC%83%81%ED%83%9C-%EB%B3%80%EC%88%98) 에서 본 
코루틴의 상태를 다시 보자.

![코루틴의 상태](/assets/img/dev/2024/1109/state.png)

부모 코루틴은 더 이상 실행한 코드가 없더라도 자식 코루틴들이 모두 완료될 때가지 실행 완료될 수 없어 `실행 완료 중` 상태에 머물다가 자식 코루틴이 모두 실행 완료되면 
자동으로 `실행 완료` 상태로 바뀐다.

---

### 2.2.2. `실행 완료 중` 상태의 Job 상태값

`실행 완료 중`인 코루틴의 Job 객체는 어떤 상태값을 가질까?

```kotlin
package chap07

import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking <Unit>{
    val startTime = System.currentTimeMillis()
    val parentJob = launch {// 부모 코루틴 실행
        launch { // 자식 코루틴 실행
            delay(1000L) // 1초간 대기
            println("[${getElapsedTime(startTime)}] 자식 코루틴 실행 완료")
        }
        println("[${getElapsedTime(startTime)}] 부모 코루틴이 실행하는 마지막 코드")
    }
    parentJob.invokeOnCompletion { // 부모 코루틴이 종료될 시 호출되는 콜백 등록
        println("[${getElapsedTime(startTime)}] 부모 코루틴 실행 완료")
    }
    delay(500L) // 500ms 대기
    
    printJobState(parentJob)
}

fun getElapsedTime(startTime: Long): String = "지난 시간: ${System.currentTimeMillis() - startTime} ms"

fun printJobState(job: Job) {
    println("🔍 Job 상태 확인:")
    println("- isActive: ${job.isActive}     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태")
    println("- isCancelled: ${job.isCancelled} // 취소가 요청된 상태")
    println("- isCompleted: ${job.isCompleted} // 정상 완료되었거나 예외 또는 취소로 종료된 상태")
}
```

부모 코루틴인 _parentJob_ 은 부모 코루틴이 실행하는 마지막 코드를 출력하는 시점과 부모 코루팀 실행 완료를 출력하는 시점 사이에 `실행 완료 중` 상태를 가진다. 
이 범위는 대략 0초에서 1초 사이이므로 500ms 정도 대기 후에 _parentJob_ 의 상태를 출력하면 `실행 완료 중`일 때 Job 객체의 상태값을 출력할 수 있다.

```shell
[지난 시간: 6 ms] 부모 코루틴이 실행하는 마지막 코드
🔍 Job 상태 확인:
- isActive: true     // 실행 중이며, 완료되지 않았고, 취소되지 않은 상태
- isCancelled: false // 취소가 요청된 상태
- isCompleted: false // 정상 완료되었거나 예외 또는 취소로 종료된 상태
[지난 시간: 1017 ms] 자식 코루틴 실행 완료
[지난 시간: 1017 ms] 부모 코루틴 실행 완료
```

출력된 Job 의 상태값은 보면 '실행 완료 중'인 코루틴이 아직 완료되지 않았으므로 isActive 는 true, 취소 요청을 받거나 실행 완료되지 않았으므로 isCancelled 와 
isCompleted 는 모두 false 가 된다.

<코루틴 상태별 Job 상태표>

| 코루틴 상태  | isActive | isCancelled | isCompleted |
|:--------|:--------:|:-----------:|:-----------:|
| 생성      |  false   |    false    |    false    |
| 실행 중    |   true   |    false    |    false    |
| **실행 완료 중** |   true   |    false    |    false    |
| 실행 완료   |  false   |    false    |    true     |
| 취소 중    |  false   |    true     |    false    |
| 취소 완료   |  false   |    true     |    true     |


`실행 완료 중`과 `실행 중` Job 상태값은 동일하므로 API 상으로는 구분되지 않고, 일반적으로 둘의 상태를 구분없이 사용한다.  
하지만 구조적 이해를 위해선 **자식이 끝나야 부모가 끝난다는 의존성**을 명확히 인지하는 것이 중요하다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)