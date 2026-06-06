---
layout: post
title:  "Coroutine - 실행 제어와 공유 상태의 동시성 문제(2): Unconfined 디스패처, `Continuation`"
date: 2025-08-09
categories: dev
tags: kotlin coroutine concurrency dispatcher UnconfinedDispatcher CoroutineStart UNDISPATCHED Continuation CPS suspend resume deadlock blocking non-blocking suspendCancellableCoroutine
---

이번 포스트에서는 코루틴의 내부 동작 원리에 대해 알아본다.

- CoroutineStart 옵션을 활용해 코루틴의 실행 시점과 방식을 정교하게 제어하는 방법
- `무제한 디스패처(Unconfined Dispatcher)`의 독특한 동작 방식
- 일시 중단(suspend)과 재개(resume)가 가능한 원리인 `Continuation`
 
> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap11) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 무제한 디스패처(Unconfined Dispatcher)](#1-무제한-디스패처unconfined-dispatcher)
  * [1.1. 무제한 디스패처 특징](#11-무제한-디스패처-특징)
    * [1.1.1. 코루틴이 자신을 생성한 스레드에서 즉시 실행된다.](#111-코루틴이-자신을-생성한-스레드에서-즉시-실행된다)
    * [1.1.2. 실행 흐름 비교: `Unconfined` vs `Confined` 디스패처](#112-실행-흐름-비교-unconfined-vs-confined-디스패처)
    * [1.1.3. 중단 후에는 스레드가 바뀔 수 있다.](#113-중단-후에는-스레드가-바뀔-수-있다)
  * [1.2. `CoroutineStart.UNDISPATCHED` vs `Dispatchers.Unconfined`](#12-coroutinestartundispatched-vs-dispatchersunconfined)
* [2. 코루틴의 동작 방식과 `Continuation`](#2-코루틴의-동작-방식과-continuation)
  * [2.1. CPS(Continuation-Passing Style)](#21-cpscontinuation-passing-style)
  * [2.2. 코루틴의 일시 중단과 재개로 알아보는 `Continuation`](#22-코루틴의-일시-중단과-재개로-알아보는-continuation)
  * [2.3. 다른 작업의 결과를 받아 코루틴 재개](#23-다른-작업의-결과를-받아-코루틴-재개)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 무제한 디스패처(Unconfined Dispatcher)

코루틴을 어떤 스레드에서 실행할지 결정하는 디스패처 중에서 `Dispatchers.Unconfined` 는 특별한 동작 방식을 가진다.  
이름 그대로 '제한되지 않은' 이 디스패처는 코루틴을 자신을 호출한 스레드에서 **즉시** 실행을 시작하도록 만든다.

특정 스레드 풀에 작업을 예약하는 `Dispatchers.Default` 나 `Dispatchers.IO` 와 달리, `Dispatchers.Unconfined` 디스패처는 어느 스레드에서 호출되든 
그 스레드를 그대로 사용하여 코루틴의 첫 실행을 시작한다.

아래는 `Dispatchders.Unconfined` 와 `Dispatchers.Default` 디스패처의 기본적인 차이를 보여준다.

```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
  // Dispatchers.Unconfined 를 사용해 실행되는 코루틴
  launch(Dispatchers.Unconfined) {
    println("launch 코루틴 실행 스레드: ${Thread.currentThread().name}") // launch 코루틴이 실행되는 스레드 출력
  }

  // Dispatchers.Default 를 사용하는 코루틴
  launch(Dispatchers.Default) {
    println("launch 코루틴 실행 스레드: ${Thread.currentThread().name}") // launch 코루틴이 실행되는 스레드 출력
  }
}
```

```shell
launch 코루틴 실행 스레드: main @coroutine#2
launch 코루틴 실행 스레드: DefaultDispatcher-worker-1 @coroutine#3
```

`Unconfined` 코루틴은 자신을 호출한 runBlocking 의 스레드인 main 에서 바로 실행된 반면, `Default` 코루틴은 별도의 워커 스레드에서 실행된 것을 확인할 수 있다.

---

## 1.1. 무제한 디스패처 특징

### 1.1.1. 코루틴이 자신을 생성한 스레드에서 즉시 실행된다.

`Dispatchders.Unconfined` 의 가장 중요한 특징은 **호출 스레드를 상속받아 즉시 실행**된다는 점이다. 이로 인해 별도의 스레드로 작업을 보내는 과정(Context Switching)이 
없어 코드의 흐름이 순차적으로 보일 수 있다.

예를 들어 runBlocking 이 `Dispatchers.IO` 의 스레드에서 실행되도록 하고 그 안에서 `Unconfined` 코루틴을 실행하면 어떻게 될까?

```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>(Dispatchers.IO) {
    println("runBlocking 코루틴 실행 스레드: ${Thread.currentThread().name}") // runBlocking 코루틴이 실행되는 스레드 출력
    launch(context = Dispatchers.Unconfined) { // Dispatchers.Unconfined 를 사용해 실행되는 코루틴
        println("launch 코루틴 실행 스레드: ${Thread.currentThread().name}") // launch 코루틴이 실행되는 스레드 출력
    }
}
```

```shell
runBlocking 코루틴 실행 스레드: DefaultDispatcher-worker-1 @coroutine#1
launch 코루틴 실행 스레드: DefaultDispatcher-worker-1 @coroutine#2
```

launch 코루틴이 runBlocking 이 실행되던 DefaultDispatcher-worker-1 스레드를 그대로 물려받아 실행된 것을 볼 수 있다.

`Unconfined` 는 이처럼 자신을 둘러싼 외부 코루틴의 실행 스레드가 무엇이든 그대로 이어받는다.

----

### 1.1.2. 실행 흐름 비교: `Unconfined` vs `Confined` 디스패처

무제한 디스패처의 '즉시 실행' 특성은 일반적인 제한된 디스패처(Confined Dispatcher) 의 동작과 대조된다.

- **제한된 디스패처(`Dispatchers.IO`, `Dispatchers.Default` 등)**
  - 호출 스레드 → 디스패처 작업 대기열 → 디스패처 스레드 풀의 가용 스레드에서 실행
  - 코루틴 실행 요청을 받으면 일단 작업 대기열에 넣고, 자신의 스레드 풀에서 순서대로 처리함
  - 이 과정에서 스레드 전환이 발생하며, 실행 순서를 보장하지 않음
- **무제한 디스패처(`Dispatchers.Unconfined`)**
  - 호출 스레드 → 즉시 실행
  - 마치 일반 함수를 호출하는 것처럼, 호출한 스레드의 실행 흐름을 이어받아 바로 코드를 실행함

![제한된 디스패처의 동작](/assets/img/dev/2025/0809/confined.png)

![Dispatchers.Unconfined 의 동작](/assets/img/dev/2025/0809/unconfined.png)

`Unconfined` 사용 시(순차적 실행)

```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    println("${Thread.currentThread().name}: 1")
    launch(context = Dispatchers.Unconfined) {
        println("${Thread.currentThread().name}: 2 (즉시 실행)")
    }
    println("${Thread.currentThread().name}: 3")
}
```

```shell
main @coroutine#1: 1
main @coroutine#2: 2 (즉시 실행)
main @coroutine#1: 3
```

launch 블록이 끼어들어 실행되어 1, 2, 3 순서로 출력된다.

제한된 디스패처 사용 시(비순차적 실행)

```kotlin
package chap11

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    println("${Thread.currentThread().name}: 1")
    launch {
        println("${Thread.currentThread().name}: 2 (나중에 실행)")
    }
    println("${Thread.currentThread().name}: 3")
}
```

```shell
main @coroutine#1: 1
main @coroutine#1: 3
main @coroutine#2: 2 (나중에 실행)
```

launch 블록이 디스패처 작업 대기열에 들어간 후 실행되므로, 바깥 코드인 3번이 먼저 출력되고 2번이 나중에 출력된다.

> **`Dispatchers.Unconfined` 와 [`CoroutineStart.UNDISPATCHED`](https://assu10.github.io/dev/2025/06/23/coroutine-concurrency-control-1/#23-coroutinestartundispatched-%EB%94%94%EC%8A%A4%ED%8C%A8%EC%B2%98%EB%A5%BC-%EA%B1%B4%EB%84%88%EB%9B%B0%EB%8A%94-%EC%A6%89%EC%8B%9C-%EC%8B%A4%ED%96%89) 와의 차이점**
> 
> `Dispatchers.Unconfined` 의 즉시 실행 동작은 `CoroutineStart.UNDISPATCHED` 옵션과 매우 유사하다.  
> 하지만 코루틴이 delay() 와 같은 중단 함수를 만난 후 **재개(resume)될 때의 동작에서 결정적인 차이**가 있다.
> 
> 이에 대한 좀 더 상세한 내용은 [1.2. `CoroutineStart.UNDISPATCHED` vs `Dispatchers.Unconfined`](#12-coroutinestartundispatched-vs-dispatchersunconfined) 를 참고하세요.

---

### 1.1.3. 중단 후에는 스레드가 바뀔 수 있다.

`Dispatchders.Unconfined` 의 '즉시 실행' 특성은 **첫 실행부터 첫 번째 중단점(suspension point)까지만 유효**하다.  
만일 코루틴이 delay() 나 다른 suspend 함수에 의해 일시 중단되었다가 재개(resume)되면, 그 이후의 코드는 코루틴을 재개시킨 스레드에서 계속 실행된다.

이것이 `Dispatchders.Unconfined` 디스패처를 사용할 때 가장 주의해야 할 부분이다.

아래 예시를 보자.

```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = Dispatchers.Unconfined) {
        println("일시 중단 전 실행 스레드: ${Thread.currentThread().name}")
        delay(1000) // 코루틴 일시 중단
        println("일시 중단 후 실행 스레드: ${Thread.currentThread().name}") // 재개된 후의 스레드는?
    }
}
```

```shell
일시 중단 전 실행 스레드: main @coroutine#2
일시 중단 후 실행 스레드: kotlinx.coroutines.DefaultExecutor @coroutine#2
```

- **일시 중단 전**
  - 코루틴은 자신을 호출한 main 스레드에서 정상적으로 실행됨
- **일시 중단 후**
  - delay() 함수가 1초 뒤에 코루틴을 재개시킴
  - 이 때 delay() 함수는 내부적으로 코틀린의 기본 실행자인 `DefaultExecutor` 스레드를 사용함
  - 코루틴은 자신을 재개시켜준 `DefaultExecutor` 스레드에서 남은 작업을 이어감

이처럼 `Dispatchers.Unconfined` 디스패처를 사용한 코루틴은 **어떤 스레드가 자신을 재개시킬지 예측하기 어렵다.**  
이는 비동기 작업의 실행 컨텍스트가 계속해서 바뀔 수 있음을 의미하며, 코드를 불안정하게 만드는 주요 원인이 된다.

따라서 UI 스레드처럼 특정 스레드에서 실행되어야 하는 로직이나, 스레드에 종속적인 자원을 다룰 때 `Dispatchers.Unconfined` 를 사용하는 것은 매우 위험하다.  
이런 특성 때문에 **일반적인 애플리케이션 코드에서는 사용을 권장하지 않으며**, 코루틴의 즉각적인 실행 여부만 확인하면 되는 **테스트 코드 등의 특수한 상황에서만 
제한적으로 사용**하는 것이 좋다.

---

## 1.2. `CoroutineStart.UNDISPATCHED` vs `Dispatchers.Unconfined`

[`CoroutineStart.UNDISPATCHED`](https://assu10.github.io/dev/2025/06/23/coroutine-concurrency-control-1/#23-coroutinestartundispatched-%EB%94%94%EC%8A%A4%ED%8C%A8%EC%B2%98%EB%A5%BC-%EA%B1%B4%EB%84%88%EB%9B%B0%EB%8A%94-%EC%A6%89%EC%8B%9C-%EC%8B%A4%ED%96%89) 와 `Dispatchders.Unconfined`, 두 옵션은 
'코루틴을 호출한 스레드에서 즉시 실행한다'는 공통점 때문에 종종 혼동되곤 한다.  
하지만 **일시 중단 후 재개될 때의 동작 방식에서 결정적인 차이**가 있으며, 이 차이를 이해하는 것이 코루틴의 동작을 예측하는데 매우 중요하다.

- `CoroutineStart.UNDISPATCHED`
  - 시작은 즉시 하지만, 재개될 때는 **원래 자신이 배정받았던 고유의 디스패처로 복귀**하여 나머지 작업 수행
- `Dispatchers.Unconfined`
  - 중단 후 자신을 **재개시킨 스레드**에서 나머지 작업을 이어감
  - 정해진 컨텍스트 없이, 재개 시점의 스레드를 따라감

아래는 두 옵션의 차이를 명확하게 보여준다.

```kotlin
package chap11

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    println("runBlocking 코루틴 스레드: ${Thread.currentThread().name}")

    // 1. CoroutineStart.UNDISPATCHED 예제
    launch(start = CoroutineStart.UNDISPATCHED) {
        println("CoroutineStart.UNDISPATCHED 코루틴이 시작 시 사용하는 스레드: ${Thread.currentThread().name}")
        delay(100L)
        println("CoroutineStart.UNDISPATCHED 코루틴이 재개 시 사용하는 스레드: ${Thread.currentThread().name}")
    }.join()

    // 2. Dispatchers.Unconfined 예제
    launch(context = Dispatchers.Unconfined) {
        println("Dispatchers.Unconfined 코루틴이 시작 시 사용하는 스레드: ${Thread.currentThread().name}")
        delay(100L)
        println("Dispatchers.Unconfined 코루틴이 재개 시 사용하는 스레드: ${Thread.currentThread().name}")
    }.join()
}
```

> `join()` 에 대한 내용은 [1. `join()` 을 사용한 코루틴 순차 처리](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#1-join-%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EC%88%9C%EC%B0%A8-%EC%B2%98%EB%A6%AC) 를 참고하세요.

- `CoroutineStart.UNDISPATCHED`
  - **시작**: launch 는 부모인 runBlocking 의 컨텍스트(여기서는 main 스레드)를 상속받고, `UNDISPATCHED` 옵션에 따라 즉시 main 스레드에서 실행 시작
  - **재개**: delay() 이후 재개될 때, 자신이 원래 소속된 디스패처인 main 스레드로 복귀하여 나머지 코드 실행
- `Dispatchers.Unconfined`
  - **시작**: 마찬가지로 main 스레드에서 즉시 실행 시작
  - **재개**: delay() 함수를 처리한 `DefaultExecutor` 가 코루틴을 재개시키자, **그 스레드를 그대로 이어받아** 나머지 코드 실행

```shell
runBlocking 코루틴 스레드: main @coroutine#1
CoroutineStart.UNDISPATCHED 코루틴이 시작 시 사용하는 스레드: main @coroutine#2
CoroutineStart.UNDISPATCHED 코루틴이 재개 시 사용하는 스레드: main @coroutine#2
Dispatchers.Unconfined 코루틴이 시작 시 사용하는 스레드: main @coroutine#3
Dispatchers.Unconfined 코루틴이 재개 시 사용하는 스레드: kotlinx.coroutines.DefaultExecutor @coroutine#3
```

이처럼 `UNDISPATCHED` 는 잠시 외출했다가 자기 집(원래 디스패처)로 돌아오는 것과 같고, `Unconfined` 는 집 없이 떠돌다가 현재 머무는 곳에서 계속 살아가는 것과 
같다고 비유할 수 있다.

스레드 컨텍스트의 일관성을 유지해야 한다면 `UNDISPATCHED` 옵션을 고려할 수 있지만, 일반적으로는 명시적인 디스패처를 사용하는 것이 코드를 예측 가능하게 만드는 가장 좋은 방법이다.

---

# 2. 코루틴의 동작 방식과 `Continuation`

코루틴의 가장 강력한 기능은 실행 도중 코드를 일시 중단(suspend)하고, 필요할 때 다시 재개(resume)할 수 있다는 점이다.

그렇다면 코루틴은 어떻게 멈췄던 위치를 정확하게 기억하고 돌아올까? 그것은 바로 `Continuation` 객체에 있다.

---

## 2.1. CPS(Continuation-Passing Style)

코틀린 코루틴은 중단과 재개를 구현하기 위해 CPS(Continuation-Passing Style)라는 프로그래밍 기법을 컴파일러 단에서 활용한다.  
CPS 는 간단히 말해서 **'다음에 실행할 작업(Continuation)'을 함수의 인자로 전달하는 방식**이다.

코루틴에서는 이 '다음에 실행할 작업'을 담는 객체가 바로 `Continuation` 인터페이스이다.

```kotlin
/**
 * Interface representing a continuation after a suspension point that returns a value of type `T`.
 * T 타입의 값을 반환하는 중단점 이후의 '연속'을 나타내는 인터페이스
 */
@SinceKotlin("1.3")
public interface Continuation<in T>
```

`Continuation` 객체는 코루틴이 일시 중단되는 시점의 모든 상태(어떤 코드를 실행 중이었는지, 지역 변수는 무엇이었는지 등)를 **스냅샷처럼 저장**한다. 그리고 이 `Continuation` 
객체만 있으면, 언제 어디서든 코루틴을 멈췄던 시점 그대로 복원하여 실행을 재개할 수 있다.

launch(), async(), delay() 같은 고수준의 API 는 이 `Continuation` 객체를 내부적으로 처리하기 때문에 개발자에게 직접 노출되지 않는다.  
하지만 코루틴의 동작 원리를 깊이 이해하려면, 이 저수준의 `Continuation` 이 어떻게 코루틴의 생명주기를 관리하는지 알아두는 것이 중요하다.

---

## 2.2. 코루틴의 일시 중단과 재개로 알아보는 `Continuation`

코루틴에서 일시 중단이 일어나면 `Continuation` 객체에 실행 정보가 저장되며, 일시 중단된 코루틴은 `Continuation` 객체에 대해 resume() 함수가 호출돼야 재개된다.

아래는 저수준 API 인 suspendCancellableCoroutine() 함수를 사용해 코루틴을 직접 중단시키고, `Continuation` 객체를 확인해보는 예시이다.  
suspendCancellableCoroutine() 함수는 코루틴을 중단시키고, 그 시점의 `Continuation` 을 람다의 인자로 넘겨준다.

```kotlin
package chap11

import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine

fun main() = runBlocking<Unit> {
    println("runBlocking 코루틴 일시 중단 호출")
    // 코루틴을 중단시키고, continuation 객체에 접근
    suspendCancellableCoroutine<Unit> { continuation: CancellableContinuation<Unit> ->
        println("일시 중단 시점의 runBlocking 코루틴 실행 정보: ${continuation.context}")
        // 아무것도 재개하지 않고 람다 종료
    }
    println("일시 중단된 코루틴이 재개되지 않아 실행되지 않는 코드")
}
```

위 코드에서 runBlocking 코루틴은 "일시 중단 호출"을 출력하고, suspendCancellableCoroutine() 함수를 호출한다.
suspendCancellableCoroutine() 함수가 호출되면 runBlocking 코루틴은 일시 중단되고, 실행 정보가 Continuation 객체에 저장되어 suspendCancellableCoroutine() 함수의 
람다식에서 CancellableContinuation 타입의 수신 객체로 제공된다. 여기서는 이 수신 객체를 이용해 Continuation 객체 정보를 출력한다.

```shell
runBlocking 코루틴 일시 중단 호출
일시 중단 시점의 runBlocking 코루틴 실행 정보: [BlockingCoroutine{Active}@5ccd43c2, BlockingEventLoop@4aa8f0b4]

(프로세스가 종료되지 않고 계속 대기 상태에 있음)
```

예상대로 suspendCancellableCoroutine() 함수가 호출되자 코루틴은 그 자리에서 일시 중단된다.  
`Continuation` 객체에 실행 정보가 저장된 것도 확인하였다. 하지만 마지막 println() 은 실행되지 않는다.

이유는 코루틴을 재개하라는 resume() 호출이 없기 때문이다.

```kotlin
package chap11

import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

fun main() = runBlocking<Unit> {
    println("runBlocking 코루틴 일시 중단 호출")
    suspendCancellableCoroutine<Unit> { continuation: CancellableContinuation<Unit> ->
        println("일시 중단 시점의 runBlocking 코루틴 실행 정보: ${continuation.context}")
        continuation.resume(Unit) // 코루틴 재개 호출
    }
    println("runBlocking 코루틴 재개 후 실행되는 코드")
}
```

```shell
runBlocking 코루틴 일시 중단 호출
일시 중단 시점의 runBlocking 코루틴 실행 정보: [BlockingCoroutine{Active}@5ccd43c2, BlockingEventLoop@4aa8f0b4]
runBlocking 코루틴 재개 후 실행되는 코드

Process finished with exit code 0
```

---

delay() 함수도 내부적으로는 이와 같은 원리로 동작한다.

아래는 delay() 일시 중단 함수의 구현체이다.

```kotlin
public suspend fun delay(timeMillis: Long) {
    if (timeMillis <= 0) return // don't delay
    // 코루틴을 중단시키고, continuation 을 얻어옴
    return suspendCancellableCoroutine sc@ { cont: CancellableContinuation<Unit> ->
        // if timeMillis == Long.MAX_VALUE then just wait forever like awaitCancellation, don't schedule.
        if (timeMillis < Long.MAX_VALUE) {
            cont.context.delay.scheduleResumeAfterDelay(timeMillis, cont) // timeMillis 이후에 Continuation 재개
        }
    }
}
```

delay() 함수는 suspendCancellableCoroutine() 을 호출해 코루틴을 일단 멈춘 뒤, 지정된 시간이 지나면 `Continuation` 객체를 resume 하도록 예약하는 방식으로 동작한다.

이처럼 Continuation 객체는 코루틴의 일시 중단 시점에 코루틴의 실행 정보를 저장하며, 재개 시 Continuation 객체를 사용해 코루틴의 실행을 복구할 수 있다.

---

## 2.3. 다른 작업의 결과를 받아 코루틴 재개

`Continuation` 은 단순히 코루틴을 재개시키는 역할만 하는 것이 아니다.  
다른 스레드나 비동기 API 에서 수행된 작업의 결과를 받아와 멈춰있던 코루틴에게 전달하는 역할도 한다.

방법은 suspendCancellableCoroutine() 함수의 제네릭 타입으로 반환받고 싶은 결과의 타입을 지정해주면 된다.  
예를 들어 다른 작업으로부터 String 타입의 결과를 받고 싶다면 suspendCancellableCoroutine\<String\> 을 사용하면 된다.

아래는 별도의 스레드에서 1초간 작업을 수행한 후, 그 결과 문자열을 runBlocking 코루틴에게 전달하여 재개시키는 예시이다.

```kotlin
package chap11

import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.concurrent.thread
import kotlin.coroutines.resume

fun main() = runBlocking<Unit> {
    // 코루틴을 중단시키고 String 타입의 결과를 기다림
    val result = suspendCancellableCoroutine<String> { continuation: CancellableContinuation<String> ->
        // 별도의 스레드에서 비동기 작업 수행
        thread { // 새로운 스레드 생성
            Thread.sleep(1000L) // 1초간 무언가 처리한다고 가정
            val workResult = "이게 작업 결과"
            // 작업 결과를 담아 코루틴 재개
            continuation.resume(workResult)
        }
    }
    println(result) // 코루틴 재개 시 반환받은 결과 출력
}
```

- `val result = suspendCancellableCoroutine<String>`: runBlocking 코루틴은 이 지점에서 일시 중단된다. 동시에, String 타입의 결과가 돌아오면 result 변수에 저장한다는 의미이다.
- `thread { ... }`: 코루틴과 상관없는 별도의 스레드가 생성되어 비동기 작업을 시작한다. runBlocking 코루틴은 이 작업이 끝날 때까지 효율적으로 대기한다.
- `continuation.resume("...")`: 1초 후, 별도 스레드는 작업 결과 문자열을 resume() 함수의 인자로 넣어 호출한다.
- resume() 호출은 대기 중이던 runBlocking 코루틴을 재개시키고, 인자로 전달된 문자열은 suspendCancellableCoroutine() 함수의 반환값이 된다.

이처럼 suspendCancellableCoroutine()과 `Continuation` 은 코루틴이 아닌 외부의 비동기 작업(예: 전통적인 콜백 기반의 API)과 코루틴을 연결하는 역할을 한다.  
이를 통해 어떤 비동기 코드라도 세련된 코루틴 스타일로 변환하여 사용할 수 있다.


```shell
이게 작업 결과

Process finished with exit code 0
```

---

# 정리하며..

`Dispatchers.Unconfined` 는 코루틴을 호출한 스레드에서 즉시 실행시켜주는 편리함을 제공하지만, **일시 중단 후에는 자신을 재개시킨 스레드에서 동작**하여 실행 흐름을 
예측하기 어렵게 만드는 특성이 있다.  
이 때문에 테스트와 같은 특수한 상황을 제외하고는 사용에 각별한 주의가 필요하다.

코루틴의 일시 중단과 재개가 어떻게 가능한지에 대해서도 알아보았다.  
컴파일러가 CPS(Continuation-Passing Style) 방식을 통해 코드를 변환하고, `Continuation` 객체에 다음에 실행할 코드의 정보와 상태를 저장하여 전달하기 때문이다.  
suspendCancellableCoroutine() 과 같은 저수준 API 를 통해 직접 `Continuation` 을 다뤄보며 그 원리에 대해서 알아보았다.

일상적으로 작성하는 프로덕션 코드에서는 고수준 API 가 이 모든 복잡함을 감싸고 있어서 `Continuation` 을 직접 다룰 일은 거의 없다.  
하지만 그 내부에서 `Continuation` 이 어떻게 동작하는지 이해하는 것은 코루틴의 동작을 예측하고 동시성 문제를 해결하는데 도움이 된다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)