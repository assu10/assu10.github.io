---
layout: post
title:  "Coroutine - 구조화된 동시성과 부모-자식 관계(3): `runBlocking()` 과 `launch() 차이`"
date: 2025-05-23
categories: dev
tags: kotlin coroutine run-blocking launch
---

`runBlocking()` 함수의 `launch()` 함수는 모두 코루틴 빌더 함수이지만 호출부의 스레드를 사용하는 방법에 차이가 있다.

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `runBlocking()` 함수의 동작 방식](#1-runblocking-함수의-동작-방식)
* [2. runBlocking 코루틴의 하위에 생성된 코루틴의 동작](#2-runblocking-코루틴의-하위에-생성된-코루틴의-동작)
* [3. `runBlocking()` 함수와 `launch()` 함수의 동작 차이](#3-runblocking-함수와-launch-함수의-동작-차이)
* [4. `runBlocking()` vs `launch()`](#4-runblocking-vs-launch)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. `runBlocking()` 함수의 동작 방식

`runBlocking()` 은 코루틴을 시작하면서 호출 스레드를 차단(blocking) 한다는 특징을 가진 코루틴 빌더 함수이다.  
(= 코루틴을 시작하면서 현재 스레드를 차단함)

`runBlocking()` 함수가 호출되면 새로운 코루틴인 runBlocking 코루틴이 실행되는데, 이 코루틴은 실행이 완료될 때까지 호출부의 스레드를 차단(block) 하고 사용한다.

기본 동작: 호출부 스레드(main) 를 점유하는 예시
```kotlin
package chap07

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    delay(1000L)
    println("[${Thread.currentThread().name}] 코루틴 종료")
}
```

```shell
[main @coroutine#1] 코루틴 종료
```
- `runBlocking()` **호출 시 호출 스레드인 메인 스레드(main) 에서 실행**되는 runBlocking 코루틴이 생성됨
- 이 코루틴은 1초 간 대기 후 실행 스레드를 출력하고 실행이 완료됨
- **runBlocking 이 실행되는 동안 해당 스레드는 차단(blocking)** 되어 다른 작업을 수행할 수 없음
- 코루틴이 완료되면 메인 스레드도 종료되며, 이는 일반적인 프로그램 종료 흐름임

![runBlocking 동작 방식](/assets/img/dev/2025/0523/runBlocking.webp)

---

위 코드에서 runBlocking 코루틴은 실행되는 동안 메인 스레드를 점유하고 사용한다.  
하지만 runBlocking 코루틴은 작업 실행 시 호출부의 스레드를 사용하지 않고, **차단만** 할 수도 있다.

Dispatcher 를 지정하면 실행되는 스레드는 변경되지만, 호출한 스레드는 여전히 차단된다.

Dispatcher 지정 시: 실행 스레드는 다르지만 호출부 스레드는 여전히 차단되는 예시
```kotlin
package chap07

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>(Dispatchers.IO) {
    delay(1000L)
    println("[${Thread.currentThread().name}] 코루틴 종료")
}
```

```shell
[DefaultDispatcher-worker-1 @coroutine#1] 코루틴 종료
```

- Dispatchers.IO 를 지정했기 때문에 runBlocking 코루틴은 Dispatchers.IO 를 사용해 별도의 백그라운드 스레드(DefaultDispatcher-worker-1) 에서 실행됨
- 하지만 `runBlocking()` 함수를 호출한 스레드인 메인 스레드는 여전히 차단되어 runBlocking 코루틴이 완료될 때까지 대기함


![runBlocking 의 호출 스레드 차단](/assets/img/dev/2025/0523/runBlocking2.webp)

위 그림에서 일시 중단과 재개 실행 시에 실행 스레드가 변할 수 있지만 여기서는 runBlocking 코루틴이 DefaultDispatcher-worker-1 스레드만 사용하여 실행되는 상황을 가정한다.

- `runBlocking()` 함수가 호출된 스레드와 다른 스레드에서 runBlocking 코루틴이 실행되더라도 해당 코루틴이 실행되는 동안 `runBlocking()` 함수를 호출한 스레드는 차단됨
- 차단이 풀리는 시점은 runBlocking 코루틴이 실행 완료될 때임


runBlocking 함수의 차단은 
[스레드 블로킹](https://assu10.github.io/dev/2024/10/20/coroutine-thread-vs-coroutine/#323-executor-%ED%94%84%EB%A0%88%EC%9E%84%EC%9B%8C%ED%81%AC-%ED%95%9C%EA%B3%84-%EC%8A%A4%EB%A0%88%EB%93%9C-%EB%B8%94%EB%A1%9C%ED%82%B9)에서의 차단과 다르다.
- **스레드 블로킹**
  - 스레드가 어떤 작업에도 사용할 수 없도록 차단되는 것을 의미
- **`runBlocking()` 함수의 차단**
  - runBlocking 코루틴과 그 자식 코루틴을 제외한 다른 작업이 스레드를 사용할 수 없음을 의미
  - 즉, runBlocking 코루틴과 그 자식만 스레드를 사용할 수 있도록 제한

---

# 2. runBlocking 코루틴의 하위에 생성된 코루틴의 동작

runBlocking 코루틴은 **호출한 스레드를 블로킹하면서 점유**한다.  
이 말은 곧 **그 하위에서 생성된 코루틴들도 해당 스레드를 공유**할 수 있다는 뜻이다.

```kotlin
package chap07

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val startTime = System.currentTimeMillis() // 시작 시간
  launch {
    delay(1000L)
    println("[${Thread.currentThread().name}] launch 코루틴 종료")
  }
  delay(2000L)
  println("[${Thread.currentThread().name}] runBlocking 코루틴 종료")
  println("${getElapsedTime(startTime)}")
}

fun getElapsedTime(startTime: Long): String {
  return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

```shell
[main @coroutine#2] launch 코루틴 종료
[main @coroutine#1] runBlocking 코루틴 종료
지난 시간: 2009ms
```

- launch 코루틴은 runBlocking 코루틴의 자식 코루틴으로 생성됨
- 두 코루틴 모두 **메인 스레드(main)** 을 사용하고 있음
- launch 코루틴은 1초 후에 실행되고, runBlocking 코루틴은 전체 2초 대기 후 종료되며, 출력 결과에 스레드 이름이 main 으로 동일하게 표시됨
- 즉, runBlocking 이 호출한 **메인 스레드를 자식 코루틴도 사용**할 수 있음

![runBlocking 코루틴 하위에 생성된 코루틴 동작](/assets/img/dev/2025/0523/runBlocking3.webp)

- `runBlocking()` 이 호출되면 메인 스레드가 블로킹됨
- 그 안에서 생성된 launch 코루틴도 메인 스레드에서 실행됨
- 전체 실행 시간은 약 2초로, runBlocking 실행 시간과 일치함

---

# 3. `runBlocking()` 함수와 `launch()` 함수의 동작 차이

`runBlocking()` 과 `launch()` 는 모두 코루틴을 시작할 수 있는 함수이다.  
하지만 **스레드 차단 여부**와 **실행 타이밍**에서 큰 차이가 있다.

---

**`runBlocking()` 은 실행 시 호출부 스레드를 차단한다.**

> `runBlocking()` 은 블로킹을 일으키는 일반적인 코드와 코루틴 사이의 연결점 역할을 하기 위해 만들어졌기 때문에, 
> main 함수 또는 테스트 코드에서만 사용하는 것을 권장한다.  
> **코루틴 안에서 다시 `runBlocking()` 을 호출하는 것은 지양**하는 것이 좋다.
> 
> 아래는 예시를 위한 코드일 뿐이다.

아래는 runBlocking 코루틴 내부에서 runBlocking 함수가 호출되는 경우이다.
```kotlin
package chap07

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    // 하위 runBlocking 코루틴
    // 바깥쪽 runBlocking 코루틴이 차단한 스레드를 사용할 수 있기 때문에 메인 스레드 상에서 실행되며,
    // 실행되는 동안 메인 스레드를 차단함
    runBlocking {
        delay(1000L)
        println("[${Thread.currentThread().name}] 하위 코루틴 종료")
    }
    println(getElapsedTime(startTime)) // 지난 시간 출력
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

```shell
[main @coroutine#2] 하위 코루틴 종료
지난 시간: 1013 ms
```

![runBlocking 코루틴 하위에 생성된 runBlocking 코루틴 동작](/assets/img/dev/2025/0523/runBlocking4.webp)

- runBlocking 코루틴은 **호출부의 스레드(여기서는 메인 스레드)를 차단하고 점유**한다.
- 따라서 하위 runBlocking 이 실행되는 동안 메인 스레드는 다른 작업을 할 수 없다.
- 하위 코루틴이 모두 완료된 뒤에서 "지난 시간"이 출력되며, 약 1초가 소요된 것을 확인할 수 있다.

---

**`launch()` 은 실행 시 호출부 스레드를 차단하지 않는다.**

따라서 launch 코루틴이 delay 와 같은 작업으로 실제로 스레드를 사용하지 않는 동안 스레드를 다른 작업에 사용될 수 있다.

위 코드의 하위 runBlocking 을 launch 로 변경해보자.
```kotlin
package chap07

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val startTime = System.currentTimeMillis()
    // 하위 launch 코루틴
    // 호출부의 스레드를 차단하고 실행되는 것이 아니기 때문에 즉시 실행되지 않고,
    // runBlocking 코루틴이 메인 스레드를 양보하고 나서야 메인 스레드로 보내져서 실행됨
    launch {
        delay(1000L)
        println("[${Thread.currentThread().name}] 하위 코루틴 종료")
    }
    println(getElapsedTime(startTime)) // 지난 시간 출력
}

fun getElapsedTime(startTime: Long): String {
    return "지난 시간: ${System.currentTimeMillis() - startTime}ms"
}
```

```shell
지난 시간: 0 ms
[main @coroutine#2] 하위 코루틴 종료
```

![runBlocking 코루틴 하위에 생성된 launch 코루틴 동작](/assets/img/dev/2025/0523/launch.webp)

- launch 는 **호출부의 스레드를 차단하지 않기 때문에** 바로 "지난 시간" 이 출력된다.
- 이후 launch 코루틴이 스레드를 사용할 수 있을 때(여기서는 메인 스레드가 자유로워 졌을 때) 실행된다.
- launch 코루틴이 delay 로 인해 1초간 대기하는 동안 메인 스레드는 다른 작업이 자유롭게 사용할 수 있다.

---

# 4. `runBlocking()` vs `launch()`

|    구분     | `runBlocking()` | `launch()`       |
|:---------:|:----------------|:-----------------|
| 스레드 차단 여부 | O (blocking)    | X (non-blocking) |
|   사용 목적   | 일반 코드와 코루틴 간 연결 | 비동기 작업 실행        |
|   사용 위치   | main 함수, 테스트 코드 | 코루틴 컨텍스트 어디서나    |
| 하위 코루틴 실행 | 즉시 실행 & 차단      | 예약 실행 & 비차단      |

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)