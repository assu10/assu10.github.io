---
layout: post
title:  "Coroutine - 코루틴 개발환경 셋팅"
date: 2024-11-02
categories: dev
tags: kotlin coroutine
---

코틀린은 언어 수준에서 코루틴을 지원하지만 저수준 API 만을 제공하므로 실제 애플리케이션에 사용하기에는 무리가 있다.  
따라서 코루틴을 사용하기 위해서는 젯브레인스에서 만든 코루틴 라이브러리(kotlinx.coroutines) 을 사용하는 것이 일반적이다.  
이 라이브러리는 `async`, `await` 같은 고수준 API 를 제공한다.

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap02) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 코루틴 실행: `runBlocking()`](#1-코루틴-실행-runblocking)
* [2. 코루틴 디버깅 환경 설정](#2-코루틴-디버깅-환경-설정)
  * [2.1. `launch` 를 사용하여 코루틴 추가 실행](#21-launch-를-사용하여-코루틴-추가-실행)
  * [2.2. `CoroutineName` 을 사용하여 코루틴에 이름 추가](#22-coroutinename-을-사용하여-코루틴에-이름-추가)
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

# 1. 코루틴 실행: `runBlocking()`

```kotlin
package chap02

import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    println("Hello~")
}
```

`runBlocking()` 함수는 해당 함수를 호출한 스레드를 사용해 실행되는 코루틴을 만든다.  
main() 를 통해 실행되는 프로세스는 기본적으로 메인 스레드상에서 실행되기 때문에 `runBlocking` 함수는 메인 스레드를 점유하는 코루틴을 만든다.

`runBlocking()` 가 '차단하고 실행한다' 는 이름이 붙은 이유는 `runBlocking()` 로 생성된 코루틴이 실행 완료될 때까지 이 코루틴과 관련없는 다른 작업이 
스레드를 점유하지 못하게 막기 때문이다.  
즉, 위 코드에서 `runBlocking()` 함수는 코루틴이 람다식을 모두 실행할 때까지 호출부의 스레드인 메인 스레드를 점유하는 코루틴을 만들어내고, 코루틴이 실행 
완료되어야 코루틴의 메인 스레드의 점유가 종료된 후 프로세스가 종료된다.

---

# 2. 코루틴 디버깅 환경 설정

코루틴은 작업 단위이다.  
코루틴은 일시 중단이 가능하지만 **일시 중단 후 작업 재개 시 실행 스레드가 바뀔 수 있기 때문에 어떤 코루틴이 어떤 스레드에서 실행되고 있는지를 알아야 디버깅이 가능**해진다.

여기서는 작업을 실행 중인 스레드와 코루틴을 함께 출력하기 위한 환경 설정 방법에 대해 알아본다.

`Thread.currentThread().name` 은 **현재 실행 중인 스레드의 이름**을 출력한다.

```kotlin
package chap02

import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    // 현재 실행 중인 스레드 출력
    println("[${Thread.currentThread().name}] Start")
}
```

```shell
[main] Start
```

**실행 중인 코루틴의 이름을 출력**하려면 JVM 의 VM options 에 `-Dkotlinx.coroutines.debug` 를 넣어주면 된다.

```shell
[main @coroutine#1] Start
```

_coroutine_ 은 실행 중인 코루틴의 이름이고, #1, #2.. 는 코루틴 구분을 위해 코루틴 생성 때마다 자동으로 증가하는 숫자이다.

---

## 2.1. `launch` 를 사용하여 코루틴 추가 실행

`runBlocking()` 함수의 람다식에서는 수신 객체인 `CoroutineScope` 에 접근할 수 있고, `CoroutineScope` 객체의 확장 함수로 정의된 **`launch()` 함수를 
사용하면 코루틴을 추가로 생성**할 수 있다.

아래는 `runBlocking()` 함수의 람다식 내부에서 `launch()` 를 호출하는 예시이다.

```kotlin
package chap02

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> { // this: CoroutineScope
    println("[${Thread.currentThread().name}] Start")
    launch { // this: CoroutineScope
        println("[${Thread.currentThread().name}] Start")
    }
    launch { // this: CoroutineScope
        println("[${Thread.currentThread().name}] Start")
    }
}
```

```shell
[main @coroutine#1] Start
[main @coroutine#2] Start
[main @coroutine#3] Start
```

위 코드를 보면 `launch()` 함수가 두 번 실행되어 총 3개의 코루틴이 생성된 것을 알 수 있다.  
하지만 자동으로 증가하는 숫자만으로는 여전히 무엇이 어떤 코루틴인지 알 기 어렵다.  
이를 위해 코루틴은 `CoroutineName` 객체를 사용하여 사용자가 직접 이름을 부여할 수 있도록 하고 있다.

---

## 2.2. `CoroutineName` 을 사용하여 코루틴에 이름 추가

`CoroutineName` 은 코루틴의 이름을 구분하는 객체이다.

```kotlin
package chap02

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>(context = CoroutineName("Main")) {
    println("[${Thread.currentThread().name}] Start")
    launch { // this: CoroutineScope
        println("[${Thread.currentThread().name}] Start")
    }
    launch(context = CoroutineName("Coroutine1")) {
        println("[${Thread.currentThread().name}] Start")
    }
    launch(context = CoroutineName("Coroutine2")) {
        println("[${Thread.currentThread().name}] Start")
    }
}
```

위처럼 `CoroutineName` 객체를 코루틴을 생성하는 `runBlocking()` 이나 `launch()` 에 context 인자로 넘기면 해당 함수로 생성되는 코루틴은 `CoroutineName` 객체에 
설정된 이름을 갖게 된다.

```shell
[main @Main#1] Start
[main @Main#2] Start
[main @Coroutine1#3] Start
[main @Coroutine2#4] Start
```

---

# 정리하며..

- 코틀린은 언어 레벨에서 코루틴을 지원하지만 저수준 API 만을 지원함
- 실제 개발에 필요한 고수준 API 는 코루틴 라이브러리를 통해 제공받을 수 있음
- `runBlocking()`, `launch()` 함수를 통해 코루틴을 실행할 수 있음
- 현재 실행 중인 스레드명은 `Thread.currentThread().name` 을 통해 출력할 수 있음
- 스레드의 이름을 출력할 때 코루틴명을 추가로 출력하려면 JVM 의 VM options 에 `-Dkotlinx.coroutines.debug` 를 추가하면 됨
- `CoroutineName` 객체를 통해 코루틴 이름을 지정할 수 있음

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)