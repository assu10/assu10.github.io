---
layout: post
title:  "Coroutine - 스레드 양보: 서브루틴과 실행 스레드 전환"
date: 2025-06-08
categories: dev
tags: kotlin coroutine thread subroutine delay yield await thread-switching-concurrency
---

코루틴을 처음 접하면 종종 **서브루틴(subroutine)**과의 차이부터 헷갈리기 시작한다.  
여기서는 **서브루틴과 코루틴의 구조적 차이**를 짚고, 코루틴이 **협력적(concurrent)**으로 동작하기 위해 **어떻게 스레드를 양보**하는지, 그리고 일시 중단된 코루틴이 **재개될 때 
어떤 스레드에서 실행**되는지 살펴본다.

- 루틴과 서브루틴의 개념 정리
- 코루틴의 스레드 양보: `delay()`, `yield()`, `await()`
- 고정적이지 않은 코루틴의 실행 스레드 동작 원리

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap10) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 서브루틴(subroutine)과 코루틴](#1-서브루틴subroutine과-코루틴)
  * [1.1. 서브루틴(subroutine)과 코루틴의 차이](#11-서브루틴subroutine과-코루틴의-차이)
* [2. 코루틴의 스레드 양보](#2-코루틴의-스레드-양보)
  * [2.1. `delay()` 일시 중단 함수의 스레드 양보](#21-delay-일시-중단-함수의-스레드-양보)
  * [2.2. `join()` 과 `await()` 의 동작 방식](#22-join-과-await-의-동작-방식)
  * [2.3. `yield()` 의 스레드 양보](#23-yield-의-스레드-양보)
* [3. 코루틴의 실행 스레드](#3-코루틴의-실행-스레드)
  * [3.1. 코루틴의 실행 스레드는 고정이 아니다](#31-코루틴의-실행-스레드는-고정이-아니다)
  * [3.2. 스레드를 양보하지 않으면 실행 스레드가 바뀌지 않는다.](#32-스레드를-양보하지-않으면-실행-스레드가-바뀌지-않는다)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 서브루틴(subroutine)과 코루틴

---

루틴은 특정 작업을 수행하는 명령의 집합으로 함수나 메서드를 뜻한다.  
그 중에서도 **서브루틴은 다른 함수 내부에서 호출되는 함수**를 의미하며, 호출한 함수(루틴)은 서브루틴의 실행이 끝날 때까지 **스레드를 양보하지 않고 기다린다.**  
즉, **서브루틴은 실행이 완료되기 전까지 실행 흐름을 다른 곳에 넘기지 않는다.**

---

## 1.1. 서브루틴(subroutine)과 코루틴의 차이

**서브루틴:**
- 호출되면 반환 전까지 **스레드를 점유**
- 중단없이 끝까지 실행

**코루틴:**
- 함께(co) 실행되는 루틴
- 실행 중이라도 **스스로 스레드 사용 권한을 양보**할 수 있음
- `yield()`, `delay()` 등으로 **일시 중단 → 다른 코루틴에게 스레드 양보**
- 이렇게 스레드 사용 권한을 양보하며 함께 실행되기 때문에 코루틴은 서로 간에 협력적으로 동작한다고 함

```kotlin
package chap10

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield

fun main() = runBlocking<Unit>{
  launch {
    while (true) {
      println("[${Thread.currentThread().name}] 자식 코루틴에서 작업 실행 중")
      yield() // 스레드 사용 권한 양보
    }
  }

  while (true) {
    println("[${Thread.currentThread().name}] 부모 코루틴에서 작업 실행 중")
    yield() // 스레드 사용 권한 양보
  }
}
```

- runBlocking 은 메인 스레드를 사용하여 부모 코루틴을 실행하고,
- `launch()` 로 자식 코루틴을 동일한 메인 스레드에서 실행함
- 두 코루틴이 [`yield()`](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#52-yield-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%B7%A8%EC%86%8C-%ED%99%95%EC%9D%B8) 를 통해 스레드 사용 권한을 양보할 때마다 스레드가 필요한 다른 코루틴이 스레드 사용 권한을 가져가 실행함

![코루틴이 실행되는 방법](/assets/img/dev/2025/0608/coroutine.webp)

```shell
[main @coroutine#1] 부모 코루틴에서 작업 실행 중
[main @coroutine#2] 자식 코루틴에서 작업 실행 중
[main @coroutine#1] 부모 코루틴에서 작업 실행 중
[main @coroutine#2] 자식 코루틴에서 작업 실행 중
[main @coroutine#1] 부모 코루틴에서 작업 실행 중

Process finished with exit code 130 (interrupted by signal 2:SIGINT)
```

<**서브루틴 vs 코루틴**>

|   항목   | 서브루틴         | 코루틴                    |
|:------:|:-------------|:-----------------------|
| 실행 방식  | 호출되면 완료까지 실행 | 실행 중에도 중단 가능           |
| 스레드 점유 | 반환 전까지 점유    | 필요 시 `yield()` 로 양보 가능 |
|   특징   | 동기적, 직선적 흐름  | 협력적, 동시적 흐름            |

코루틴은 **서로 협력적으로 실행되기 위해 명시적으로 스레드를 양보**하며, 이런 동작은 비동기 작업을 효율적으로 처리하는 기반이 된다. 
따라서 코루틴이 협력적으로 동작하기 위해서는 코루틴이 작업을 하지 않는 시점에 스레드 사용 권한을 양보하고 일시 중단해야 한다.

이제 코루틴의 스레드 양보에 대해 좀 더 깊게 알아보자.

---

# 2. 코루틴의 스레드 양보

코루틴은 작업 도중 스레드가 더 이상 필요하지 않은 시점이 오면 **스스로 스레드를 양보**할 수 있다.  
양보된 스레드는 **다른 코루틴의 실행에 재사용**되며, 이것이 코루틴이 **적은 수의 스레드로 많은 작업을 처리할 수 있는 비결**이다.

- **스레드를 할당하는 주체 vs 양보하는 주체**
  - **CoroutineDispatcher**: 코루틴을 어느 스레드에서 실행시킬지를 결정하는 역할
  - **코루틴 자신**: 실행 중인 스레드를 **양보할지 말지를 스스로 결정함**

즉, Dispatcher 는 코루틴에게 "스레드를 양보하라"고 **강제할 수 없다.**  
**코루틴 내부에서 명시적으로 스레드 양보를 요청하는 코드**가 있어야만 실제 양보가 발생한다.

코루틴이 스레드를 양보하도록 만드는 대표적인 일시 중단 함수(suspend) 는 아래와 같다.
- **`delay()`**
  - 일정 시간 동안 **일시 중단** 후, 다시 실행 가능한 상태로 진입함
- **`join()`**
  - 다른 Job(코루틴)의 완료를 **기다리며 스레드를 양보**함
- **`await()`**
  - Deferred 결과가 준비될 때까지 **대기하면서 스레드를 양보**함
- **`yield()`**
  - **즉시 스레드를 양보**하고 다른 코루틴에 실행 기회 제공

각 함수는 모두 스레드 사용을 잠시 멈추고 다른 코루틴이 실행될 수 있도록 기회를 제공한다.

---

## 2.1. `delay()` 일시 중단 함수의 스레드 양보

`delay()` 는 **일정 시간 동안 코루틴을 일시 중단(suspend)** 시키는 함수이다.  
이 함수가 호출되면 **코루틴은 현재 점유 중인 스레드를 즉시 반환**하고, 지정된 시간이 지나면 다시 **스레드를 할당받아 작업을 재개**한다.  
즉, `delay()` 는 스레드를 점유하지 않고 기다릴 수 있게 해주는 대표적인 스레드 양보 함수이다.

코루틴의 스레드 양보 기능은 여러 코루틴이 동시에 실행되는 상황에서 더욱 강력하게 작동한다.

아래는 메인 스레드에서 동일한 코루틴을 10번 실행하는 예시이다.

```kotlin
package chap10

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val startTime: Long = System.currentTimeMillis()
  repeat(10) {
    launch {
      delay(1000L) // 1초 동안 코루틴 일시 중단
      println("[${Thread.currentThread().name}] [${getElapsedTime(startTime)}] 코루틴 $it 실행 완료")
    }
  }
}

fun getElapsedTime(startTime: Long): String = "지난 시간: ${System.currentTimeMillis() - startTime} ms"
```

```shell
[main @coroutine#2] [지난 시간: 1010 ms] 코루틴 0 실행 완료
[main @coroutine#3] [지난 시간: 1017 ms] 코루틴 1 실행 완료
[main @coroutine#4] [지난 시간: 1017 ms] 코루틴 2 실행 완료
[main @coroutine#5] [지난 시간: 1017 ms] 코루틴 3 실행 완료
[main @coroutine#6] [지난 시간: 1017 ms] 코루틴 4 실행 완료
[main @coroutine#7] [지난 시간: 1017 ms] 코루틴 5 실행 완료
[main @coroutine#8] [지난 시간: 1018 ms] 코루틴 6 실행 완료
[main @coroutine#9] [지난 시간: 1018 ms] 코루틴 7 실행 완료
[main @coroutine#10] [지난 시간: 1018 ms] 코루틴 8 실행 완료
[main @coroutine#11] [지난 시간: 1018 ms] 코루틴 9 실행 완료

Process finished with exit code 0
```

- 모든 코루틴은 시작하자마자 `delay()` 호출로 스레드를 양보한다.
- 덕분에 하나의 코루틴이 실행된 후 바로 다음 코루틴이 실행될 수 있으며, 10개의 코루틴의 거의 동시에 시작된다.
- 실행 완료 출력은 메인 스레드를 잠깐씩만 점유하면서 순차 출력된다.
- 총 실행 시간은 약 1초로, 10개의 코루틴이 거의 동시에 처리된다.

만일 스레드 양보가 일어나지 않았다면 작업을 모두 실행하는데 10초가 걸렸을 것이다.
아래는 `delay()` 대신 `Thread.sleep()` 으로 스레드를 양보하지 않는 예시이다.

```kotlin
package chap10

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime: Long = System.currentTimeMillis()
    repeat(10) {
        launch {
            Thread.sleep(1000L) // 1초 동안 스레드 블로킹 (코루틴의 스레드 점유 유지)
            println("[${Thread.currentThread().name}] [${getElapsedTime(startTime)}] 코루틴 $it 실행 완료")
        }
    }
}

fun getElapsedTime(startTime: Long): String = "지난 시간: ${System.currentTimeMillis() - startTime} ms"
```

```shell
[main @coroutine#2] [지난 시간: 1008 ms] 코루틴 0 실행 완료
[main @coroutine#3] [지난 시간: 2019 ms] 코루틴 1 실행 완료
[main @coroutine#4] [지난 시간: 3020 ms] 코루틴 2 실행 완료
[main @coroutine#5] [지난 시간: 4024 ms] 코루틴 3 실행 완료
[main @coroutine#6] [지난 시간: 5030 ms] 코루틴 4 실행 완료
[main @coroutine#7] [지난 시간: 6035 ms] 코루틴 5 실행 완료
[main @coroutine#8] [지난 시간: 7040 ms] 코루틴 6 실행 완료
[main @coroutine#9] [지난 시간: 8046 ms] 코루틴 7 실행 완료
[main @coroutine#10] [지난 시간: 9051 ms] 코루틴 8 실행 완료
[main @coroutine#11] [지난 시간: 10052 ms] 코루틴 9 실행 완료

Process finished with exit code 0
```

- `Thread.sleep()` 은 스레드를 블로킹(= 각 코루틴이 대기 시간 동안 스레드를 계속 점유)되므로
- 하나의 코루틴이 대기 중이면 스레드가 다른 코루틴에 할당될 수 없다.
- 결국 코루틴들이 순차적으로 실행되어 총 소요 시간이 10초 가량이다.

<**`delay()` vs `Thread.sleep()`**>

|    항목     | `delay()`           | `Thread.sleep()`   |
|:---------:|:--------------------|:-------------------|
| 일시 중단 방식  | 비동기 일시 중단 (suspend) | 스레드 블로킹 (blocking) |
|  스레드 점유   | 일시 중단 중 스레드 반납      | 스레드 계속 점유          |
| 병렬 실행 가능성 | 높음 (다른 코루틴이 실행됨)    | 낮음 (직렬 처리됨)        |
| 성능 및 확장성  | 매우 우수               | 낮음                 |

`delay()` 는 코루틴이 **스레드 양보를 통해 비동기적으로 대기**하게 만들어 준다.  
이는 **적은 수의 스레드로 많은 작업을 동시에 처리할 수 있는 핵심 메커니즘**이다.  
반면, `Thread.sleep()` 은 코루틴의 장점을 무력화시키는 **동기 블로킹 호출**이므로 피하는 것이 좋다.

---

## 2.2. `join()` 과 `await()` 의 동작 방식

코틀린에서 [`join()`](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#1-join-%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EC%88%9C%EC%B0%A8-%EC%B2%98%EB%A6%AC) 과 [`await()`](https://assu10.github.io/dev/2024/11/10/coroutine-async-and-deferred/#12-await-%EB%A1%9C-%EA%B2%B0%EA%B3%BC%EA%B0%92-%EC%88%98%EC%8B%A0) 는 모두 **다른 코루틴의 완료를 기다리는 일시 중단 함수**이다.
- **`join()`**: Job 타입의 코루틴이 **모두 종료될 때까지 대기**
- **`await()`**: Deferred 타입의 코루틴이 **결과를 반환할 때까지 대기**

이 함수들이 호출되면 **해당 함수를 호출한 코루틴은 스레드를 양보하고 일시 중단**되며, `join()` 과 `await()` 의 **대상 코루틴이 완료된 후에야 다시 실행**된다.

`join()` 함수를 사용한 스레드 양보 예시 코드
```kotlin
package chap10

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val job = launch {
        println("[${Thread.currentThread().name}] 1. launch 코루틴 작업 시작")
        delay(1000L) // 1초간 대기
        println("[${Thread.currentThread().name}] 2. launch 코루틴 작업 완료")
    }
    println("[${Thread.currentThread().name}] 3. runBlocking 코루틴이 곧 일시 중단되고 메인 스레드가 양보됨")
    job.join() // job 내부의 코드가 모두 실행될 때까지(= launch 코루틴이 끝날 때까지) 메인 스레드 일시 중단
    println("[${Thread.currentThread().name}] 4. runBlocking 메인 스레드에 분배되어 작업이 다시 재개됨")
}
```

runBlocking 코루틴은 내부에서 launch 함수를 호출해 launch 코루틴을 생성하는데 1,2번은 launch 코루틴에서 출력되고, 3,4 번은 runBlocking 코루틴에서 출력한다.

- **runBlocking 코루틴이 `launch()` 를 호출**하여 launch 코루틴을 실행함
- 하지만 launch 코루틴은 **스케쥴만 되고 실행되지 않음**(스레드 점유 중인 runBlocking 이 계속 실행 중이므로)
- runBlocking 코루틴이 3번 로그를 출력한 뒤, `job.join()` 을 호출하면 **스레드를 양보하며 일시 중단됨**
- 양보된 메인 스레드는 이제 **launch 코루틴에게 분배**되어 실행됨
- launch 코루틴이 `delay()`일시 중단 함수를 만나 메인 스레드를 양보하고 일시 중단됨
- 하지만 runBlocking 코루틴은 `job.join()` 에 의해 launch 코루틴이 실행 완료될 때까지 재개되지 못하므로 실행되지 못함
- 1초 후 launch 코루틴이 재개되어 2번 로그가 출력되고 실행 완료됨
- 이제야 runBlocking 코루틴이 재개되어 4번 로그 출력

```shell
[main @coroutine#1] 3. runBlocking 코루틴이 곧 일시 중단되고 메인 스레드가 양보됨
[main @coroutine#2] 1. launch 코루틴 작업 시작
[main @coroutine#2] 2. launch 코루틴 작업 완료
[main @coroutine#1] 4. runBlocking 메인 스레드에 분배되어 작업이 다시 재개됨

Process finished with exit code 0
```

위 코드에서 `job.join()` 이 없다면 아래와 같이 결과가 출력된다.
```shell
[main @coroutine#1] 3. runBlocking 코루틴이 곧 일시 중단되고 메인 스레드가 양보됨
[main @coroutine#1] 4. runBlocking 메인 스레드에 분배되어 작업이 다시 재개됨
[main @coroutine#2] 1. launch 코루틴 작업 시작
[main @coroutine#2] 2. launch 코루틴 작업 완료

Process finished with exit code 0
```

`job.join()` 을 호출하지 않으면 runBlocking 코루틴은 스레드 양보없이 바로 4번 로그를 출력한다.  
즉, launch 코루틴의 작업이 끝나기 전에 runBlocking 이 먼저 종료되는 흐름이다.

이렇게 `join()`, `await()` 가 호출되면 호출부의 코루틴은 스레드를 양보하고 일시 중단하며, `join()`, `await()` 의 대상이 된 코루틴이 실행 완료될 때까지 재개되지 않는다.  
이는 **코루틴 간 정확한 실행 순서를 제어**하거나, **동기화된 흐름을 만들고 싶을 때 유용**하다.

이렇게 코루틴은 개발자가 직접 스레드 양보를 호출하지 않아도 스레드 양보를 자동으로 처리한다.
하지만 종종 스레드 양보를 직접 호출해야 하는 경우가 있다. `yield()` 를 통해 스레드 양보를 직접 호출할 수 있다.

---

## 2.3. `yield()` 의 스레드 양보

`delay()`, `join()` 같은 일시 중단 함수들은 **내부적으로 스레드 양보를 자동으로 수행**한다.  
하지만 **명시적으로 스레드를 양보해야 하는 상황**도 있다.  
그 대표적인 예가 무한 루프와 같은 코드에서 **직접 `yield()` 를 호출**해야 하는 경우이다.

문제가 되는 상황 예시 코드
```kotlin
package chap10

import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val job = launch {
        while (this.isActive) {
            println("작업 중")
        }
    }
    delay(100) // 100ms 대기(스레드 양보)
    job.cancel() // 코루틴 취소
}
```

기대한 동작은 아래와 같다.
- runBlocking 코루틴이 100ms 동안 대기(`delay()`로 스레드 양보)
- 그 동안 launch 실행되어 "작업 중" 출력
- 100ms 후 `job.cancel()` 이 호출되어 launch 코루틴은 코루틴이 활성화되어 있는지를 체크하는  `isActive` 체크로 종료

하지만 실제 동작은 아래처럼 launch 코루틴이 취소되지 않고 "작업 중"이 무한히 출력된다.
```shell
작업 중
작업 중
작업 중
...
```

문제의 원인은
- launch 코루틴은 while 루프에서 계속 실행되며 **한 번도 스레드를 양보하지 않음**
- runBlocking 코루틴은 `delay()` 후 다시 스케쥴되기를 기다리지만, **launch 코루틴이 스레드를 계속 점유하고 있어 재개되지 못함**
- 결국 runBlocking 의 나머지 코드인 `job.cancel()` 이 호출되지 않아 코루틴이 무한 실행됨


이 문제를 해결하려면 아래처럼 launch 코루틴이 while 문 내부에서 직접 스레드 양보를 위해 yield() 함수를 호출해야 한다.
```kotlin
package chap10

import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield

fun main() = runBlocking<Unit> {
    val job = launch {
        while (this.isActive) {
            println("작업 중")
            yield() // 스레드 양보
        }
    }
    delay(100) // 100ms 대기(스레드 양보)
    job.cancel() // 코루틴 취소
}
```

```shell
...
작업 중
작업 중
작업 중

Process finished with exit code 0
```

- launch 코루틴은 반복문 내에서 `yield()` 를 호출하여 **스레드를 잠시 반납함**
- 반납된 스레드를 runBlocking 코루틴이 재획득하여 `job.cancel()` 실행
- 이후 `isActive` 는 false 가 되어 launch 코루틴 정상 종료

즉, 100ms 후에 작업이 정상적으로 취소된다.

지금까지 스레드 양보가 어떻게 동작하는지 쉽게 이해할 수 있도록 단일 스레드에서만 사용했지만, 실제로는 멀티 스레드 상에서 코루틴이 동작한다.
이제 멀티 스레드 환경에서 코루틴이 스레드를 양보한 후 실행이 재개될 때 실행 스레드에 어떤 변화가 일어날 수 있는지 알아본다.

---

# 3. 코루틴의 실행 스레드

---

## 3.1. 코루틴의 실행 스레드는 고정이 아니다

코루틴은 `delay()` 같은 일시 중단 함수 호출 후, 다시 실행되면서 **처음 실행되던 스레드가 아닌 다른 스레드에서 재개될 수 있다.**

이는 코루틴을 실행하는 CoroutineDispatcher 가 **사용 가능한 스레드 중 하나에 코루틴을 분배**하기 때문이다.  
즉, **코루틴의 실행 스레드는 고정되지 않으며, 재개 시마다 바뀔 수 있다.**

```kotlin
package chap10

import kotlinx.coroutines.ExecutorCoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.newFixedThreadPoolContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    val dispatcher: ExecutorCoroutineDispatcher = newFixedThreadPoolContext(2, "MyThread")
    launch(dispatcher) {
        repeat(5) {
            // launch 코루틴의 실행 중인 스레드 출력
            println("[${Thread.currentThread().name}] 코루틴 실행 일시 중단")
            delay(100L) // 코루틴 일시 중단 (= 스레드 양보)
            // launch 코루틴이 재개되면 코루틴을 실행 중인 스레드 출력
            println("[${Thread.currentThread().name}] 코루틴 실행 재개")
        }
    }
}
```

- `newFixedThreadPoolContext(2, "MyThread")` 로 **2개의 스레드를 가진 Dispatcher 생성**
- launch(dispatcher) 를 통해 해당 Dispatcher 상에서 코루틴 실행
- `delay(100)` 로 인해 매 반복마다 **코루틴은 일시 중단되었다가 재개됨**

```shell
[MyThread-1 @coroutine#2] 코루틴 실행 일시 중단
[MyThread-2 @coroutine#2] 코루틴 실행 재개
[MyThread-2 @coroutine#2] 코루틴 실행 일시 중단
[MyThread-1 @coroutine#2] 코루틴 실행 재개
[MyThread-1 @coroutine#2] 코루틴 실행 일시 중단
[MyThread-2 @coroutine#2] 코루틴 실행 재개
[MyThread-2 @coroutine#2] 코루틴 실행 일시 중단
[MyThread-1 @coroutine#2] 코루틴 실행 재개
[MyThread-1 @coroutine#2] 코루틴 실행 일시 중단
[MyThread-2 @coroutine#2] 코루틴 실행 재개

Process finished with exit code 0
```

- 모든 로그는 같은 코루틴인 coroutine#2 에서 출력됨
- 하지만 **실행되는 스레드는 MyThread-1, MyThread-2 로 계속 바뀜**
- 이는 **CoroutineDispatcher 가 일시 중단된 코루틴을 재개할 때, 사용 가능한 스레드 중 하나에 재할당**하기 때문
- **스레드가 변경되는 시점은 `delay()` 이후, 즉 "재개" 시점뿐임**

이렇게 **Dispatcher 가 코루틴을 실행 가능한 스레드에 분배**하는 방식은 **스레드 풀의 효율적인 활용**, **비동기 작업 처리의 유연성**을 가능하게 한다.

---

## 3.2. 스레드를 양보하지 않으면 실행 스레드가 바뀌지 않는다.

> 코루틴이 스레드를 양보하지 않으면 코루틴을 사용하는 이점이 모두 사라지게 되므로 이렇게 코드를 만드는 것은 지양해야 한다.

코루틴은 **일시 중단(suspend) 지점이 있을 때만 재개 시점에 다른 스레드로 옮겨갈 수 있다.**  
즉, `delay()`, `yield()`, `withContext()` 등 일시 중단 함수를 사용해서 스레드를 양보하고, 이후 CoroutineDispatcher 가 적절한 스레드에 
재할당할 수 있다.

반면, `Thread.sleep()` 은 **일시 중단 함수가 아니라 블로킹 함수**로, 코루틴을 스레드에 붙잡아두는 역할은 한다.

`Thread.sleep()` 사용 시 스레드 고정
```kotlin
package chap10

import kotlinx.coroutines.ExecutorCoroutineDispatcher
import kotlinx.coroutines.launch
import kotlinx.coroutines.newFixedThreadPoolContext
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    val dispatcher: ExecutorCoroutineDispatcher = newFixedThreadPoolContext(2, "MyThread")
    launch(dispatcher) {
        repeat(5) {
            // launch 코루틴의 실행 중인 스레드 출력
            println("[${Thread.currentThread().name}] 스레드를 점유한 채로 대기")
            Thread.sleep(100L) // 스레드를 점유한 채로 100ms 대기
            // launch 코루틴이 재개되면 코루틴을 실행 중인 스레드 출력
            println("[${Thread.currentThread().name}] 점유한 스레드에서 마저 실행")
        }
    }
}
```

```shell
[MyThread-1 @coroutine#2] 스레드를 점유한 채로 대기
[MyThread-1 @coroutine#2] 점유한 스레드에서 마저 실행
[MyThread-1 @coroutine#2] 스레드를 점유한 채로 대기
[MyThread-1 @coroutine#2] 점유한 스레드에서 마저 실행
[MyThread-1 @coroutine#2] 스레드를 점유한 채로 대기
[MyThread-1 @coroutine#2] 점유한 스레드에서 마저 실행
[MyThread-1 @coroutine#2] 스레드를 점유한 채로 대기
[MyThread-1 @coroutine#2] 점유한 스레드에서 마저 실행
[MyThread-1 @coroutine#2] 스레드를 점유한 채로 대기
[MyThread-1 @coroutine#2] 점유한 스레드에서 마저 실행

Process finished with exit code 0
```

- 코루틴은 **매 반복마다 같은 스레드(MyThread-1) 에서 실행**됨
- 이는 `Thread.sleep()` 이 **스레드를 점유한 채 대기**하기 때문이며, 일시 중단 없이 재개 지점이 없으므로 스레드가 바뀌지 않음

즉, 코루틴은 `Thread.sleep()` 이 아니라 `delay()` 같은 suspend 함수를 사용했을 때 진정한 효율을 발휘한다.


코루틴의 핵심 이점 중 하나는 **스레드를 점유하지 않고도 병렬 처리처럼 동작**할 수 있다는 점이다.  
하지만 `Thread.sleep()` 을 사용할 경우, 코루틴은 스레드를 양보하지 않고 점유한 채로 대기하게 되어 스레드 전환의 이점이 사라지므로 위와 같은 코드를 지양해야 한다.  
`Thread.sleep()` 은 코루틴의 장점인 **비동기 처리**와 **스레드 효율성**을 해친다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)