---
layout: post
title:  "Coroutine - 실행 제어와 공유 상태의 동시성 문제(1): 공유 상태 문제 해결, `CoroutineStart`"
date: 2025-06-23
categories: dev
tags: kotlin coroutine
---

멀티 스레드 환경에서 공유 상태를 사용하는 복수의 코루틴이 있을 때의 데이터 동기화 문제, CoroutineStart 옵션을 통해 코루틴의 실행 방법을 바꾸는 방법, 
무제한 디스패처가 동작하는 방식, 코루틴의 일시 중단과 재개가 일어나는 원리에 대해 알아본다.
- 코루틴이 공유 상태를 사용할 때의 문제와 다양한 데이터 동기화 방식들
- 코루틴에 다양한 실행 옵션 부여하기

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap11) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 공유 상태를 사용하는 코루틴의 문제와 데이터 동기화](#1-공유-상태를-사용하는-코루틴의-문제와-데이터-동기화)
  * [1.1. 가변 변수를 사용할 때의 문제점](#11-가변-변수를-사용할-때의-문제점)
  * [1.2. JVM 의 메모리 공간이 하드웨어 메모리 구조와 연결되는 방식](#12-jvm-의-메모리-공간이-하드웨어-메모리-구조와-연결되는-방식)
  * [1.3. 공유 상태에 대한 메모리 가시성 문제와 해결 방법](#13-공유-상태에-대한-메모리-가시성-문제와-해결-방법)
    * [1.3.1. `@Volatile` 로 공유 상태의 메모리 가시성 문제 해결](#131-volatile-로-공유-상태의-메모리-가시성-문제-해결)
  * [1.4. 공유 상태에 대한 경쟁 상태 문제와 해결 방법](#14-공유-상태에-대한-경쟁-상태-문제와-해결-방법)
    * [1.4.1. `Mutex` 를 사용해 동시 접근 제한](#141-mutex-를-사용해-동시-접근-제한)
    * [1.4.2. 공유 상태 변경을 위해 전용 스레드 사용](#142-공유-상태-변경을-위해-전용-스레드-사용)
  * [1.5. 원자성 있는 데이터 구조를 사용한 경쟁 상태 문제 해결](#15-원자성-있는-데이터-구조를-사용한-경쟁-상태-문제-해결)
    * [1.5.1. 원자성 있는 객체를 사용해 경쟁 상태 문제 해결: `AtomicInteger`](#151-원자성-있는-객체를-사용해-경쟁-상태-문제-해결-atomicinteger)
    * [1.5.2. 복잡한 객체도 원자적으로: `AtomicReference`](#152-복잡한-객체도-원자적으로-atomicreference)
    * [1.5.3. 원자적 객체 사용의 한계: 스레드 블로킹](#153-원자적-객체-사용의-한계-스레드-블로킹)
    * [1.5.4. 원자성 있는 객체를 사용 시 하는 흔한 실수](#154-원자성-있는-객체를-사용-시-하는-흔한-실수)
* [2. `CoroutineStart` 의 옵션들](#2-coroutinestart-의-옵션들)
  * [2.1. `CoroutineStart.DEFAULT`: 즉시 스케쥴링](#21-coroutinestartdefault-즉시-스케쥴링)
  * [2.2. `CoroutineStart.ATOMIC`: 취소 불가능한 시작 보장하기](#22-coroutinestartatomic-취소-불가능한-시작-보장하기)
  * [2.3. `CoroutineStart.UNDISPATCHED`: 디스패처를 건너뛰는 즉시 실행](#23-coroutinestartundispatched-디스패처를-건너뛰는-즉시-실행)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 공유 상태를 사용하는 코루틴의 문제와 데이터 동기화

코루틴은 동시성(concurrency) 를 단순하게 다룰 수 있도록 돕는 강력한 도구이지만, **공유 상태(shared state)** 를 사용할 때는 반드시 **데이터 동기화(synchronization)** 를 
고려해야 한다.  
특히 **멀티 스레드 환경**에서 여러 코루틴이 동시에 **가변 변수(mutable variable)** 를 읽고 수정하면 심각한 버그로 이어질 수 있다.

여기서는 공유 상태로 인해 발생하는 대표적인 문제 2가지인 **메모리 가시성(memory visibility) 와 경쟁 상태(race condition)** 에 대해 알아본다.

---

## 1.1. 가변 변수를 사용할 때의 문제점

코드의 안전성을 위해 가능한 불변 변수(immutable variable) 를 사용하는 것이 좋지만, 여러 스레드가 코루틴에서 **공유된 자원**을 업데이트할 필요가 있는 경우에는 
가변 변수를 사용할 수밖에 없다.  
예를 들어 스레드 간에 데이터를 전달하거나 공유된 자원을 사용하는 경우이다.

아래는 멀티 스레드 환경에서 복수의 코루틴이 가변 변수를 공유하고 업데이트할 때 어떤 문제가 발생하는지에 대한 예시 코드이다.

```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

var count = 0

fun main() = runBlocking<Unit> {
    withContext(Dispatchers.Default) {
        repeat(10_000) {
            launch {
                count++
            }
        }
    }
    println(count)
}
```

```shell
9467
```

이 코드는 runBlocking 블록 내에서 [`withContext()`](https://assu10.github.io/dev/2024/11/10/coroutine-async-and-deferred/#4-withcontext) 를 
사용해 10,000 개의 launch 코루틴을 실행하고, 각각 count++ 를 수행한 후 완료될 때까지 대기한다.  
Dispatchers.Default 객체는 멀티 스레드를 사용하므로 10,000개의 코루틴이 count 값에 접근하고 변경하는 작업은 병렬적으로 실행된다.

이론적으로는 최종 결과가 10,000이 되어야 하지만 실제 **실행 결과는 매번 달라진다.**

왜 실행 결과가 매번 달라질까?

원인은 아래 2가지 이유 때문이다.

<br />

**1. 메모리 가시성(Memory Visibility)**

메모리 가시성은 스레드가 변수를 읽는 메모리 공간에 관한 문제로 CPU 캐시와 메인 메모리 등으로 이루어진 하드웨어의 메모리 구조와 연관되어 있다.  
JVM 은 하드웨어의 메모리 계층 구조(CPU 캐시 ↔ 메인 메모리)를 그대로 따른다.  
**CPU 캐시의 값이 메인 메모리에 전파되는데 약간의 시간이 걸리기 때문**에 CPU 캐시와 메인 메모리 간에 데이터 불일치 문제가 생긴다.  
이로 인해 한 스레드가 값을 수정해도 그 값이 메인 메모리에 즉시 반영되지 않고 CPU 캐시에만 머무를 수 있는데 이 때 다른 스레드가 그 값을 읽으면 **변경되기 전 값**을 보게 될 수도 있다.

예) 스레드 A 가 count = 1000 → 1001 로 변경했지만 CPU 캐시에만 있고 아직 메인 메모리에 반영되지 않았다면 스레드 B 는 여전히 count = 1000 을 읽게 됨

<br />

**2. 경쟁 상태(Race Condition)**

2개의 스레드가 동시에 값을 읽고 업데이트하면 같은 연산이 2번 일어난다.  
즉, 두 코루틴이 동시에 count 를 읽고 +1을 수행하면 **최종적으로는 한 번만 증가된 결과**가 반영될 수 있다.  
이는 연산이 원자적으로 실행되지 않고, 중간 단계(읽기 → 계산 → 저장)에서 값이 덮어쓰게 되기 때문이다.

예) count = 1000 에서 두 코루틴이 동시에 count 변수에 접근하면 count 변수가 1000 → 1001 이 되는 연산이 2번 일어남  
즉, 2개의 코루틴이 값을 1만큼만 증가시키므로 최종 결과는 1001이 됨 (=하나의 연산이 손실됨)

<br />

요약하면 **스레드 간 캐시 불일치, 연산 중간 단계의 충돌**로 인한 문제이다.  
이 2가지 문제점은 멀티 스레드 환경에서 공유 상태를 사용할 때 데이터 동기화 문제를 일으키는 주범이다.

---

## 1.2. JVM 의 메모리 공간이 하드웨어 메모리 구조와 연결되는 방식

멀티 스레드 환경에서 발생하는 메모리 가시성 문제(Memory Visibility) 와 경쟁 상태(Race Condition) 을 이해하려면, JVM 이 사용하는 메모리 구조와 
실제 하드웨어의 메모리 계층 구조가 어떻게 연결되는지를 먼저 살펴볼 필요가 있다.

---

**JVM(Java Virtual Machine) 메모리 구조**

JVM 은 가상 머신으로, 아래와 같은 구조로 메모리를 분리해 사용한다.

![JVM 의 메모리 구조](/assets/img/dev/2025/0623/jvm.webp)

- **Thread Stack Area(스택 영역)**
  - 각 스레드마다 독립적으로 할당되는 메모리 공간
  - [Primitive Type](https://assu10.github.io/dev/2024/02/04/kotlin-basic/#41-primitive-%ED%83%80%EC%9E%85-int-boolean-%EB%93%B1) 데이터나 힙 영역에 저장된 객체에 대한 참조(주소값)울 저장함
- **Heap Area(힙 영역)**
  - 모든 스레드가 공유하는 메모리 공간
  - 객체, 배열 등 크고 복잡한 데이터를 저장함

---

**하드웨어 메모리 구조**

실제 컴퓨터 하드웨어는 메모리가 아래와 같은 계층으로 구성되어 있다.

![하드웨어 메모리 구조](/assets/img/dev/2025/0623/hardware.webp)

- **CPU Register**
  - 가장 빠른 접근 속도의 저장소
- **CPU Cache Memory**
  - 메인 메모리보다 빠르며, CPU 에서 자주 쓰는 데이터를 임시 저장
- **Main Memory**
  - 모든 스레드가 접근하는 공용 메모리

각 CPU 는 CPU 캐시 메모리를 두어서 데이터 조회 시 공통 영역인 메인 메모리까지 가지 않고, CPU 캐시 메모리에서 데이터를 조회할 수 있도록 하여 메모리 액세스 속도를 향상시킨다.  
이런 구조 덕분에 성능은 향상되지만, 여러 CPU 가 각각의 캐시를 가지게 되면서 **데이터 동기화 문제가 발생**할 수 있다.

---

**JVM 과 하드웨어 메모리의 연결**

이제 JVM 의 메모리 공간인 스택 영역과 힙 영역을 하드웨어 메모리 구조와 연결해보자.

![JVM 메모리 구조와 하드웨어 메모리 구조 연결](/assets/img/dev/2025/0623/jvm_hardware.webp)

하드웨어 메모리 구조는 JVM 의 스택 영역과 힙 영역을 구분하지 않기 때문에 JVM 의 스택 영역에 저장된 데이터들은 CPU 레지스터, CPU 캐시 메모리, 메인 메모리 모두에
나타날 수 있으며, 힙 영역도 마찬가지이다.

이러한 구조로 인해 멀티 스레드 또는 멀티 코루틴 환경에서 **공유 상태를 사용할 때 아래와 같은 문제가 발생**한다.
- **공유 상태에 대한 메모리 가시성 문제(Memory Visibility)**
  - 스레드 A가 변경한 데이터를 스레드 B가 인지하지 못하는 상황 발생
- **공유 상태에 대한 경쟁 상태 문제(Race Condition)**
  - 동시에 접근하여 값이 덮어쓰기 되거나 손실되는 현상

---

## 1.3. 공유 상태에 대한 메모리 가시성 문제와 해결 방법

멀티 스레드 환경에서 공유 상태를 다룰 때 자주 발생하는 문제가 바로 **메모리 가시성(Memory Visibility)** 문제이다.  
한 스레드가 공유 데이터를 변경했음에도 불구하고, 다른 스레드는 이 **변경을 제대로 인식하지 못하는 현상**이 발생할 수 있다.

이 문제는 JVM 메모리 구조와 CPU 의 캐시 구조가 밀접하게 연결되어 있기 때문에 발생하며, 특히 **CPU 캐시 → 메인 메모리 간의 동기화 지연**으로 인해 심각한 버그로 이어질 수 있다.

---

**문맥 전환(Context Switching) 과 캐시 구조의 이해**

- **CPU 는 한 순간에 하나의 스레드만 실행**
- 스레드가 CPU 에 할당되면, 해당 스레드의 상태(Context) 는 CPU 레지스터에 로드됨
- 스레드 전환 시 현재 상태는 저장(Context Save), 새로운 스레드를 CPU 레지스터에 다시 복원(Context Restore) 하는데 이것이 **문맥 전환(Context Switching)** 임

이런 구조에서 각 스레드를 독립적인 CPU 캐시를 활용하게 되고, 이 캐시가 메인 메모리가 즉시 동기화되지 않으면 아래와 같은 문제가 발생한다.

> 하나의 프로세스는 여러 개의 스레드를 가질 수 있음  
> 프로세스는 OS 위에서 실행되는 논리적 단위이고, CPU 는 프로그램을 실제 실행하는 물리적인 연산 장치임  
> 프로세스는 CPU 에 할당되어야만 실행됨  
> 즉, OS 는 다수의 프로세스를 스케쥴링하고, CPU 코어들은 매 순간마다 한 개의 스레드만 실행함

---

**메모리 가시성 문제의 흐름**

공유 상태에 대한 메모리 가시성 문제는 하나의 스레드가 다른 스레드가 변경된 상태를 확인하지 못하는 것으로, 서로 다른 CPU 에서 실행되는 스레드들에서 공유 상태를 조회하고 
업데이트할 때 생기는 문제이다.

![공유 상태 초기화 및 첫 번째 스레드의 연산](/assets/img/dev/2025/0623/shared_1.webp)

1 공유 상태는 처음에는 메인 메모리상에 저장되어 있음  
2 이 때 하나의 스레드가 이 공유 상태를 읽어오고, 해당 스레드를 실행 중인 CPU 는 공유 상태를 CPU 캐시 메모리에 저장함  
3 스레드는 count 값을 증가시킴

![변경값이 CPU 캐시에만 반영됨](/assets/img/dev/2025/0623/shared_2.webp)

4 스레드는 연산 결과인 count = 1001 을 CPU 캐시 메모리에 씀  
CPU 캐시 메모리의 값을 메인 메모리로 플러시하지 않으면 이 값은 메인 메모리로 전파되지 않음

CPU 캐시 메모리의 데이터가 메인 메모리에 전파되지 않은 상태에서 다른 CPU 에서 실행되는 스레드에서 count 값을 읽는 상황을 가정해보자.

![다른 CPU 가 여전히 이전 값을 참조함](/assets/img/dev/2025/0623/shared_3.webp)

5 두 번째 스레드는 여전히 이전값인 1000 을 읽음  
6~7 스레드는 count += 1 을 실행한 후 자신의 CPU 캐시 메모리에 1001 을 저장함

![플러시 후에도 값은 1001 → 연산 손실 발생](/assets/img/dev/2025/0623/shared_4.webp)

8 각 CPU 캐시 메모리 값이 메인 메모리로 플러시가 발생함

결과적으로 두 번의 count += 1 연산이 있었지만, **메인 메모리에는 한 번만 반영**되게 된다.  
이것이 **메모리 가시성 문제로 인한 연산 손실** 문제이다.

---

메모리 가시성 문제를 해결하려면 동기화(Synchronization) 를 통해 **CPU 캐시와 메인 메모리 간 일관성을 보장**해야 한다.  
대표적인 방법은 아래와 같다.

- **`@Volatile`**
  - 변수 변경 시 즉시 메인 메모리에 반영됨(읽기엔 안전, 쓰기엔 미흡)
- **synchronized 블록**
  - 한 번에 하나의 스레드만 접근하도록 lock 을 걸어 안전 보장
- **AtomicInteger 등**
  - 원자적 연산을 제공하는 클래스 사용
- **Mutex, Semaphore(코루틴 용)**
  - 코루틴 환경에서 lock 기반 동기화 제공

---

### 1.3.1. `@Volatile` 로 공유 상태의 메모리 가시성 문제 해결

앞서 설명한 메모리 가시성 문제는 하나의 스레드에서 변경한 값이 메인 메모리에 반영되지 않아 **다른 스레드가 변경된 값을 보지 못하는 현상**이다.  
이 문제를 해결하기 위한 대표적인 방법이 바로 `@Volatile` 애너테이션이다.

`@Volatile` 예제 코드
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

@Volatile
var count = 0

fun main() = runBlocking<Unit> {
    withContext(Dispatchers.Default) {
        repeat(10000) {
            launch {
                count++
            }
        }
    }
    println(count)
}
```

`@Volatile` 애너네이션이 붙은 변수는 **항상 메인 메모리에서 읽고, 메인 메모리에 기록**된다.  
CPU 캐시 메모리를 거치지 않기 때문에 **스레드 간 최신 상태를 보장**할 수 있다.

![@Volatile 을 사용한 공유 상태 가시성 문제 해결](/assets/img/dev/2025/0623/shared_5.webp)

하지만 여전히 문제는 남아있다.

```shell
9427
```

`@Volatile` 을 사용해도 여전히 count 의 값은 10000 이 아니라 매번 다르게 출력된다.

이유는 **연산 자체는 여전히 원자적(atomic) 이지 않기 때문**이다.

count += 1 은 사실상 아래처럼 3단계 연산으로 이루어진다.
```kotlin
val temp = count   // 읽기
val result = temp + 1  // 계산
count = result    // 저장
```

이 3단계 사이에 다른 코루틴이 끼어들어 값을 변경할 수 있기 때문에(= 메인 메모리의 count 변수에 동시 접근 가능) 여전히 **경쟁 상태(Race Condition) 문제**가 발생한다.

---

## 1.4. 공유 상태에 대한 경쟁 상태 문제와 해결 방법

`@Volatile` 애너테이션은 **메모리 가시성(Memory Visibility) 은 보장**하지만, **경쟁 상태(Race Condition) 문제까지는 해결하지 못한다.**  
즉 변수의 값을 항상 최신으로 읽을 수는 있지만, **여러 스레드가 동시에 같은 변수에 접근하고 수정하는 것 자체는 막지 못한다.**


`@Volatile` 예제 코드: count++ 은 안전하지 않다.
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

@Volatile
var count = 0

fun main() = runBlocking<Unit> {
    withContext(Dispatchers.Default) {
        repeat(10000) {
            launch {
                count++
            }
        }
    }
    println(count)
}
```

각 launch 코루틴이 Dispatchers.Default 객체를 사용해 실행되므로 병렬로 실행되는 코루틴들이 count 변수의 값을 증가시킨다.
즉, 각 스레드에서 실행 중인 코루틴들이 count 변수에 동시에 접근할 수 있으므로 같은 연산이 중복으로 실행될 수 있다.

위의 count += 1 은 단순히 1을 더하는 연산처럼 보이지만, 사실은 아래와 같은 3단계이다.
1. 변수 읽기 → val temp = count
2. 덧셈 계산 → val result = temp + 1
3. 변수 쓰기 → count= result

멀티 스레드 환경에서 이 중간 과정에 다른 코루틴이 끼어들게 되면, 연산이 덮어쓰기 되거나 손실될 수 있다.

![두 스레드가 동시에 count++ 실행](/assets/img/dev/2025/0623/shared_6.webp)

![최종적으로 count 는 1001만 반영됨](/assets/img/dev/2025/0623/shared_7.webp)

이처럼 연산이 중복 실행되지만 최종 결과는 한 번만 반영되어 **실제 증가량이 누락**된다.  
이런 현상이 바로 **경쟁 상태(Race Condition)** 이다.

경쟁 상태를 해결하려면, 여러 스레드가 동시에 변수에 접근하지 못하도록 **lock 이나 원자적 계산(atomic operation)** 을 도입해야 한다.

- **synchronize 블록**
  - JVM 레벨에서 lock 을 걸어 단일 스레드만 접근 허용
- **AtomicInteger**
  - 연산 자체를 원자적(atomic)으로 처리하는 클래스
- [**Mutex**](https://assu10.github.io/dev/2024/10/20/mutex-semaphore/)
  - 코루틴 환경에서 사용할 수 있는 lock(Lightweight + Suspendable)
- [**Semaphore**](https://assu10.github.io/dev/2024/10/20/mutex-semaphore/)
  - 동시 접근 허용 개수를 제어할 수 있는 동기화 도구

---

|     문제     | 설명                   | 해결 방법                                |
|:----------:|:---------------------|:-------------------------------------|
| 메모리 가시성 문제 | 변경된 값을 다른 스레드가 보지 못함 | `@Volatile`, Atomic, Mutex           |
|  경쟁 상태 문제  | 동시에 수정 시 값 덮어쓰기 발생   | synchronized, Mutex, AtomicInteger 등 |

---

### 1.4.1. `Mutex` 를 사용해 동시 접근 제한

`@Volatile` 을 사용해도 여전히 Race Condition 은 발생한다.  
이를 해결하려면 **공유 변수의 변경 지점을 임계 영역(Critical Section)** 으로 지정하여 **동시에 한 스레드(또는 코루틴)만 접근할 수 있도록 제한**해야 한다.

---

**코루틴 전용 동기화 도구: `Mutex`**

코틀린 코루틴에서는 임계 영역을 만들기위한 동기화 도구로 Mutex 클래스를 제공한다.
- mutex.lock() 을 호출하면 해당 코루틴이 락을 획득할 때까지 **일시 중단(suspend)** 된다.
- 락을 보유한 코루틴이 mutex.unlock() 을 호출해 락을 해제할 때까지 **다른 코루틴은 임계 영역에 진입할 수 없다.**

> 락 해제를 자동으로 보장하는 `mutex.withLock{ }` 을 사용하는 것을 더 권장하므로 아래 코드는 참고만 할 것

lock-unlock 직접 사용 예시
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext

var count = 0
val mutex = Mutex()

fun main() = runBlocking<Unit>{
    withContext(Dispatchers.Default){
        repeat(10_000) {
            launch {
                mutex.lock() // 임계 영역 시작
                count++
                mutex.unlock() // 임계 영역 종료
            }
        }
    }
    println(count)
}
```

```shell
10000
```

락을 직접 관리하는 방식은 **락 해제 누락**이 발생할 수 있어서, **다른 코루틴이 영원히 대기 상태**에 빠질 수 있다.

`lock-unlock` 보다 안전한 방법: `mutex.withLock{ }` 사용 예시
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

var count = 0
val mutex: Mutex = Mutex()

fun main() = runBlocking<Unit>{
    withContext(Dispatchers.Default){
        repeat(10_000) {
            launch {
                mutex.withLock {
                    count++
                }
            }
        }
    }
    println(count)
}
```

```shell
10000
```

withLock() 은 **락 획득부터 해제까지는 하나의 블록으로 보장**하므로 **예외가 발생해도 락 해제 누락을 막을 수 있다.**

---

**왜 `ReentrantLock` 대신 `Mutex` 를 사용할까?**

코루틴에서 Mutex 를 사용하는 가장 큰 이유는 **락 획득 대기 중에도 스레드를 블로킹하지 않기 때문**이다.

|            | Mutex              | ReentrantLock |
|:----------:|:-------------------|:--------------|
|    락 함수    | suspend fun lock() | fun lock()    |
| 스레드 블로킹 여부 | 블로킹 없음(스레드 양보)     | 블로킹(스레드 점유)   |
|  코루틴 친화도   | 매우 높음              | 낮음            |
|   권장 사용    | 코루틴 기반 동시성 제어      | 스레드 기반 동기화 제어 |


코루틴이 **Mutex 객체의 lock()** 함수를 호출했는데 이미 다른 코루틴에 의해 Mutex 객체에 락이 걸려있으면 코루틴은 기존의 락이 해제될 때가지 **스레드를 양보하고 일시 중단**한다.  
이를 통해 코루틴이 일시 중단되는 동안 스레드가 블로킹되지 않도록 해서 **스레드에서 다른 작업이 실행**될 수 있도록 한다.
이후 기존의 **락이 해제되면 코루틴이 재개되어 Mutex 객체의 락을 획득**한다.

반면 코루틴에서 **ReentrantLock 객체에 대해 lock()** 을 호출했을 때 이미 다른 스레드에서 락을 획득했다면 코루틴은 락이 해제될 때까지 **lock 을 호출한 스레드를 블로킹**하고 기다린다.
즉, 락이 해제될 때까지 lock 을 호출한 스레드를 다른 코루틴이 사용할 수 없다.

ReentrantLock 을 코루틴에서 사용한 예시
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.util.concurrent.locks.ReentrantLock

var count = 0
val reentrantLock: ReentrantLock = ReentrantLock()

fun main() = runBlocking<Unit>{
    withContext(Dispatchers.Default){
        repeat(10_000) {
            launch {
                reentrantLock.lock() // 스레드를 블록하고 기존의 lock 이 해제될 때까지 기다림
                count++
                reentrantLock.unlock()
            }
        }
    }
    println(count)
}
```

```shell
10000
```

- ReentrantLock.lock() 은 **스레드를 블로킹**하므로, 코루틴이 락을 기다리는 동안 **스레드 리소스를 낭비**한다.
- 스케일이 커질수록 비효율적이며, 코루틴 환경에서는 사용을 지양해야 한다.

---

### 1.4.2. 공유 상태 변경을 위해 전용 스레드 사용

스레드 간 공유 상태를 사용해 생기는 문제점은 복수의 스레드가 공유 상태에 동시에 접근할 수 있기 때문에 일어난다.
따라서 공유 상태에 접근할 때 하나의 전용 스레드만 사용하도록 강제하면 공유 상태에 동시에 접근하는 문제를 해결할 수 있다.

아래는 특정 연산을 할 때 하나의 전용 스레드를 사용하는 예시이다.

```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

var count = 0
val countChangeDispatcher = newSingleThreadContext("countChangeThread")

fun main() = runBlocking<Unit> {
    withContext(Dispatchers.Default) {
        repeat(10_000) {
            launch { // count 값을 변경시킬대만 사용
                increaseCount()
            }
        }
    }
    println("[${Thread.currentThread().name}] $count")
}

suspend fun increaseCount() {
    coroutineScope {
        withContext(countChangeDispatcher) {
            count++
        }
    }
}
```

```shell
[main @coroutine#1] 10000
```

count 변수의 값을 증가시키기 위한 전용 스레드인 _countChangeThread_ 를 사용하는 CoroutineDispatcher 객체를 만들어 _countChangeDispatcher_ 변수를 통해 참조한다.  
이 countChangeDispatcher 는 increaseCount 일시 중단 함수 내부의 withContext 인자로 넘어가 count 변수의 값을 증가시킬 때 코루틴의 실행 스레드가 _countChangeThread_ 로 
전환되도록 강제한다.

따라서 launch 코루틴이 Dispatcher.Default 를 통해 백그라운드 스레드에서 실행되더라도 increaseCount 일시 중단 함수가 호출되면 launch 코루틴의 실행 스레드가 
countChangeThread 로 전환되어 count 변수에 대한 동시 접근이 일어나지 않아 count 값이 정상적으로 10000 이 나오는 것을 볼 수 있다.

단일 스레드를 사용하기 위해 newSingleThreadContext 대신 [Dispatchers.IO.limitedParallelism(1)](https://assu10.github.io/dev/2024/11/03/coroutine-dispatcher/#54-%EA%B3%B5%EC%9C%A0-%EC%8A%A4%EB%A0%88%EB%93%9C%ED%92%80%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-dispatchersio-%EC%99%80-dispatchersdefault) 이나 
[Dispatchers.Default.limitedParallelism(1)](https://assu10.github.io/dev/2024/11/03/coroutine-dispatcher/#54-%EA%B3%B5%EC%9C%A0-%EC%8A%A4%EB%A0%88%EB%93%9C%ED%92%80%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-dispatchersio-%EC%99%80-dispatchersdefault) 을 
사용할 수도 있다.

---

## 1.5. 원자성 있는 데이터 구조를 사용한 경쟁 상태 문제 해결

경쟁 상태 문제 해결을 위해 원자성(Atomicity) 을 보장하는 객체를 사용할 수도 있다.  
'원자적'이라는 말을 특정 연산이 실행될 때 중간에 다른 코루틴(스레드)이 끼어들 수 없는, 즉 쪼갤 수 없는 하나의 단위로 동작함을 의미한다.

Java 의 `java.util.concurrent.atomic` 패키지는 `AtomicInteger`, `AtomicLong`, `AtomicBoolean` 등 원자적 연산을 지원하는 클래스를 제공한다.

---

### 1.5.1. 원자성 있는 객체를 사용해 경쟁 상태 문제 해결: `AtomicInteger`

> 원자성 있는 객체는 스레드 블로킹 한계가 있으므로 아래 내용은 참고만 할 것

1만개의 코루틴이 `AtomicInteger` 타입의 공유 변수를 안전하게 증가시키는 예시
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicInteger

var count = AtomicInteger(0)

fun main() = runBlocking{
  withContext(Dispatchers.Default) {
    repeat(10_000) {
      launch {
        // 원자적 연산을 보장하는 getAndUpdate() 사용
        count.getAndUpdate {
          it + 1
        }
      }
    }
  }
  println("count: $count")
}
```

- 공유 변수 count 를 일반 Int 가 아닌 AtomicInteger 로 선언하여 초기값을 0으로 설정함
- `getAndUpdate()` 가 핵심임
  - `getAndUpdate()` 는 내부적으로 값을 읽고, 주어진 람다(여기서는 it + 1) 를 적용하여 값을 업데이트하는 **전 과정을 하나의 원자적 연산으로 처리**함
  - 따라서 여러 코루틴이 동시에 이 함수를 호출해도, 시스템은 한 번에 하나의 코루틴만 내부 값에 접근하도록 보장함
  - **경쟁 상태가 원천적으로 차단**되는 것임

```shell
count: 10000
```

`getAndUpdate()` 외에도 `incrementAndGet()`, `getAndIncrement()`, `compareAndSet()` (현재 값이 특정 값과 같을 때만 새로운 값으로 변경) 등 
다양한 원자적 연산 메서드가 있다.

<**`Atomic` 객체 사용의 장점**>
- **간결함**
  - `synchronized` 블록이나 `Mutex` 같은 명시적인 Lock 메커니즘 없이도 스레드 안전성(Thread-safety) 을 확보할 수 있어 가독성이 좋아짐
- **성능**
  - 저수준에서 하드웨어 지원(CAS Compare-And-Swap 알고리즘)을 받아 구현되므로, 일반적인 락보다 경쟁이 심하지 않은 상황에서 더 나은 성능을 보일 수 있음
- **안정성**
  - 잠금 순서에 다른 교착 상태와 같은 복잡한 문제를 피할 수 있음

AtomicInteger 외에도 AtomicLong, AtomicBoolean 등의 클래스가 있다.  
하지만 종종 복잡한 객체에 대해 원자적인 연산이 필요한 경우가 있다.
이제 복잡한 객체의 참조에 대해 원자성을 부여하는 방법을 알아본다.

---

### 1.5.2. 복잡한 객체도 원자적으로: `AtomicReference`

위에서 원자적 객체인 `AtomicInteger` 대해 알아보았다.  
하지만 실제 애플리케이션에서는 단순히 숫자를 세는 것보다 복잡한 데이터 객체를 다뤄야 할 때가 더 많다.

여기서는 `AtomicReference` 를 사용해 복잡한 객체의 상태를 원자적으로 관리하는 방법에 대해 알아본다.

데이터 클래스로 Counter 를 선언하고, 이 객체의 참조를 `AtomicReference` 로 감싸서 동시성 문제를 해결하는 예시
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicReference

data class Counter(val name: String, val count: Int)

// AtomicReference 로 Counter 객체의 참조 감싸기
val atomicCounter: AtomicReference<Counter> =
    AtomicReference(Counter(name = "MyCounter", count = 0))

fun main() = runBlocking{
    withContext(Dispatchers.Default) {
        repeat(10_000) {
            launch {
                // getAndUpdate() 는 기존 객체를 새 객체로 원자적으로 교체
                atomicCounter.getAndUpdate { // it: Counter!
                    // 불변 객체의 복사본을 만들어 상태 업데이트
                    it.copy(count = it.count + 1)
                }
            }
        }
    }
    println(atomicCounter.get())
}
```

위 코드는 name 과 count 를 갖는 불변 데이터 클래스인 Counter 를 선언한다.  
코틀린에서 데이터 클래스는 `copy()` 메서드를 제공하여 불변성을 유지하며, 객체를 쉽게 복제하고 수정할 수 있게 해준다.

`atomicCounter.getAndUpdate { ... }` 이 부분이 핵심이다.  
이 함수는 현재 Counter 객체를 원자적으로 읽어온 후 `it.copy()` 를 통해 기존 객체를 수정하는 대신, count 만 1 증가한 **새로운 복사본을 만들어 반환**한다.  
이 '읽고-새 객체로 교체'하는 전 과정이 하나의 원자적 연산으로 보장되므로 경쟁 상태가 발생하지 않는다.

```shell
Counter(name=MyCounter, count=10000)
```


---

### 1.5.3. 원자적 객체 사용의 한계: 스레드 블로킹

원자적 객체는 `Mutex` 나 `synchronized` 처럼 명시적인 Lock 을 사용하지 않는 것처럼 보이지만, 내부적으로는 비슷한 동작 방식을 가진다.

어떤 코루틴이 위의 _atomicCounter_ 에 접근해 업데이트하는 동안 다른 코루틴이 동시에 접근을 시도하면, 코루틴은 **스레드를 블로킹**하고 연산 중인 스레드가 연산을 
모두 수행할 때까지 기다린다.  
이는 코루틴에서 [ReentrantLock 객체](https://assu10.github.io/dev/2025/06/23/coroutine-concurrency-control-1/#141-mutex-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%B4-%EB%8F%99%EC%8B%9C-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C)에 대해 Lock 을 사용하는 것과 비슷하며, 
 코루틴의 Non-blocking 철학과는 다소 거리가 있다.

따라서 원자적 객체는 매우 편리하지만, 경합이 매우 심한 환경에서는 스레드 블로킹으로 인한 성능 저하가 발생할 수 있다는 한계를 명확히 인지하고 사용해야 한다.

---

### 1.5.4. 원자성 있는 객체를 사용 시 하는 흔한 실수

원자적 객체를 사용할 때 가장 많이 하고, 또 가장 치명적인 실수는 바로 **읽기와 쓰기 연산을 분리**하는 것이다.

`AtomicInteger` 를 사용했지만 경쟁 상태가 발생하는 잘못된 코드 예시
```kotlin
package chap11

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicInteger

var count = AtomicInteger(0)

fun main() = runBlocking{
    withContext(Dispatchers.Default) {
        repeat(10_000) {
            launch {
                // 경쟁 상태가 발생하는 지점
                val currentCount = count.get() // 값을 읽음
                // 위 코드와 아래 코드의 실행 사이에 다른 스레드가 count 의 값을 읽거나 변경할 수 있음
                count.set(currentCount + 1) // 새로운 값으로 씀
            }
        }
    }
    println("count: $count") // 10000이 보장되지 않음
}
```

`get()` 과 `set()` 각각의 메서드는 원자적으로 동작하지만, 두 메서드를 따로 호출하면 **`get()` 으로 값을 읽고 `set()` 으로 쓰는 그 짧은 시간적 틈새**로 
다른 코루틴이 끼어들 수 있다. 이 틈새가 바로 경쟁 상태를 유발하며, 데이터 유실의 원인이 된다.

**원자적 객체를 안전하게 사용하려면 반드시 `getAndUpdate()`, `incrementAndGet()` 처럼 읽기와 쓰기를 하나의 연산으로 묶어주는 메서드를 사용**해야 한다.

```shell
count: 8798
```

---

# 2. `CoroutineStart` 의 옵션들

여기서는 코루틴의 동작 방식을 좀 더 세밀하게 제어할 수 있는 `CoroutineStart` 옵션들에 대해 알아본다.
`launch()` 나 `async()` 와 같은 코루틴 빌더는 `start` 라는 매개변수를 통해 코루틴이 어떻게 시작될 지 결정할 수 있다.

```kotlin
public fun CoroutineScope.launch(
    context: CoroutineContext = EmptyCoroutineContext,
    start: CoroutineStart = CoroutineStart.DEFAULT, // 바로 여기
    block: suspend CoroutineScope.() -> Unit
)
```

먼저 [CoroutineStart.LAZY](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#3-coroutinestartlazy-%EB%A1%9C-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EC%A7%80%EC%97%B0-%EC%8B%9C%EC%9E%91-jobstart) 를 통해 
코루틴을 지연 시작할 수 있다.

여기서는 `CoroutineStart` 의 나머지 옵션인 `DEFAULT`, `ATOMIC`, `UNDISPATCHED` 에 대해 알아본다.

---

## 2.1. `CoroutineStart.DEFAULT`: 즉시 스케쥴링

`CoroutineStart.DEFAULT` 는 **코루틴 빌더 함수를 호출한 즉시 코루틴의 실행을 `CoroutineDispatcher` 객체에 예약(schedule)**하며, 코루틴 빌더 함수를 호출한 코루틴은 계속해서 실행된다.  
여기서 핵심은 '실행'이 아니라 **'예약'**이라는 점이다.  
실제 실행 시점은 디스패처의 상태와 현재 스레드를 점유하고 있는 다른 코루틴에 따라 달라진다.

```kotlin
package chap11

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    launch {
        println("[${Thread.currentThread().name}] 작업 1")
    }
    println("[${Thread.currentThread().name}] 작업 2")
}
```

- runBlocking 이 main 스레드 위에서 코루틴 #1 로 실행을 시작함
- `launch()` 가 호출됨
  - `start` 옵션이 `DEFAULT` 이므로, `launch()` 블록의 코드(코루틴 #2)는 **즉시 main 스레드의 디스패처 대기열에 예약**됨
- **하지만 코루틴 #1 은 스레드를 양보하지 않고** `launch()` 를 호출한 후에도 자신의 코드 블록을 계속해서 실행함
- 따라서 코루틴 #1 이 작업 2 를 실행함
- 코루틴 #1 의 코드가 모두 실행되고, runBlocking 이 자식 코루틴(여기서는 launch 코루틴)이 끝날 때까지 기다리면서 main 스레드를 양보함
- 이제 main 스레드가 비로소 자유로워졌으므로, 디스패처는 대기열에 있던 코루틴 #2 를 실행함

```shell
[main @coroutine#1] 작업 2
[main @coroutine#2] 작업 1
```

이 결과는 코루틴의 중요한 특성을 잘 보여준다.  
코루틴은 스스로 중단(suspend) 하거나, 실행을 마칠 때까지 스레드를 점유하며, `DEFAULT` 옵션은 코루틴을 **가장 가까운 실행 가능한 시점**에 실행되도록 예약하는 역할을 하고 있다.  
이것은 일반적으로 코루틴을 사용할 때 경험하는 가장 보편적인 동작 방식이다.

---

## 2.2. `CoroutineStart.ATOMIC`: 취소 불가능한 시작 보장하기

`CoroutineStart.ATOMIC` 은 **코루틴이 실행을 시작하기 전까지는 취소되지 않도록 보장**하는 옵션이다.

![코루틴의 상태](/assets/img/dev/2024/1109/state.png)

코루틴은 `launch()` 등으로 생성된 직후, 바로 스레드에 할당되어 실행되지 못할 수도 있다.  
해당 디스패처의 스레드가 모두 다른 작업을 처리하고 있다면, 코루틴은 자신의 차례가 올 때까지 잠시 대기하게 되는데 이 상태를 **`생성`(NEW) 혹은 `실행 대기 상태`**라고 한다.

그렇다면 이 `실행 대기 상태`에 있는 코루틴에 취소 요청을 보내면 어떻게 될까?

> 상태값에 대한 내용은 [6. 코루틴의 상태와 Job 의 상태 변수](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#6-%EC%BD%94%EB%A3%A8%ED%8B%B4%EC%9D%98-%EC%83%81%ED%83%9C%EC%99%80-job-%EC%9D%98-%EC%83%81%ED%83%9C-%EB%B3%80%EC%88%98) 를 참고하세요.

일반적인 코루틴은 실행되기 전에 취소되면 실행되지 않고 종료된다.
```kotlin
package chap11

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking{
    val job = launch {
        println("[${Thread.currentThread().name}] 작업 1")
    }
    job.cancel() // 실행 대기 상태의 코루틴에 취소 요청
    println("[${Thread.currentThread().name}] 작업 2")
}
```

- `launch()` 로 생성된 _job_ 은 runBlocking 이 main 스레드를 양보할 때까지 `실행 대기 상태`에 놓임
- job.cancel() 이 호출됨
  - _job_ 은 아직 코드 실행을 시작하지 않았으므로, 즉시 `취소 완료(Cancelled)` 상태가 됨
- 작업 2 가 출력된 후 ruBlocking 이 종료될 때, _job_ 은 이미 취소되었으므로 작업 1 은 출력되지 않음

```shell
[main @coroutine#1] 작업 2

Process finished with exit code 0
```

`ATOMIC` 옵션은 원자적이라는 이름처럼, 코루틴의 시작을 **쪼갤 수 없는 하나의 단위**로 취급한다.  
즉, 일단 시작이 예약된 코루틴은 **그 어떤 방해도 받지 않고 반드시 실행을 시작하는 것을 보장**한다. 따라서 실행 대기 상태에서의 cancel() 요청은 무시된다.

하지만 launch 함수의 start 인자로 `ATOMIC` 옵션을 적용하면 해당 옵션이 적용된 코루틴은 `실행 대기 상태`에서 취소되지 않는다.
```kotlin
package chap11

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking{
    val job = launch(start = CoroutineStart.ATOMIC) {
        println("[${Thread.currentThread().name}] 작업 1")
    }
    job.cancel() // 실행 대기 상태의 코루틴에 취소 요청
    println("[${Thread.currentThread().name}] 작업 2")
}
```

- `ATOMIC` 으로 생성된 _job_ 역시 `실행 대기 상태`에 놓임
- job.cancel() 이 호출되지만, `ATOMIC` 옵션 때문에 이 취소 요청은 코루틴이 **실행을 시작할 때까지는 효력이 없음**
- 작업 2 가 출력되고 main 스레드가 비워지면, _job_ 은 **취소 요청에도 불구하고 무조건 실행을 시작**함
- 따라서 작업 1 이 정상적으로 출력됨
  - 물론 코루틴 블록 내부에 중단점(suspension point) 이 있다면 그 이후에는 취소될 수 있음

```shell
[main @coroutine#1] 작업 2
[main @coroutine#2] 작업 1

Process finished with exit code 0
```

`CoroutineStart.ATOMIC` 은 '일단 launch 된 코루틴은 최소 한 번은 실행되어야 한다'와 같이, **반드시 실행되어야 하는 리소스 정리나 상태 업데이트 로직**을 
담고 있을 때 유용하게 사용할 수 있는 옵션이다.

---

## 2.3. `CoroutineStart.UNDISPATCHED`: 디스패처를 건너뛰는 즉시 실행

`CoroutineStart.UNDISPATCHED` 는 이름 그대로 **디스패처를 거치지 않고 코루틴을 실행**하는 옵션이다.

`DEFAULT` 옵션이 코루틴을 디스패처의 작업 대기열에 '예약'하는 방식이었다면, `UNDISPATCHED` 는 **작업 대기열을 거치지 않고 코루틴을 호출한 스레드에서 즉시 실행을 시작**한다.

`CoroutineStart.DEFAULT` 옵션의 동작
```kotlin
package chap11

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val job = launch {
        println("[${Thread.currentThread().name}] 작업 1")
    }
    println("[${Thread.currentThread().name}] 작업 2")
}
```

```shell
[main @coroutine#1] 작업 2
[main @coroutine#2] 작업 1

Process finished with exit code 0
```

코드를 보면 작업 2, 1 순서로 실행된다.

launch 코루틴은 즉시 스케쥴링되지만, 호출자인 runBlocking 코루틴이 main 스레드를 계속 사용하므로 대기하다가 runBlocking 코루틴의 코드가 모두 실행되고 나서야 
launch 코루틴이 실행된다.

![`CoroutineStart.DEFAULT` 의 동작](/assets/img/dev/2025/0623/default.webp)

이제 launch 코루틴을 `CoroutineStart.UNDISPATCHED` 옵션으로 실행해보자.

```kotlin
package chap11

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking{
    val job = launch(start = CoroutineStart.UNDISPATCHED) {
        println("[${Thread.currentThread().name}] 작업 1")
    }
    println("[${Thread.currentThread().name}] 작업 2")
}
```

```shell
[main @coroutine#2] 작업 1
[main @coroutine#1] 작업 2

Process finished with exit code 0
```

코드를 보면 작업 1, 2 순서로 실행된다.

`UNDISPATCHED` 옵션은 launch 코루틴을 디스패처의 대기열에 보내는 대신, **호출한 runBlocking 의 스레드(main)를 빼앗아 즉시 실행을 시작**한다.  
따라서 작업 1 이 먼저 실행되고, launch 블록의 실행이 끝난 후에야 호출자로 제어권이 돌아와 작업 2 가 실행된다.

정리하면 `CoroutineStart.UNDISPATCHED` 가 적용된 코루틴은 CoroutineDispatcher 객체의 작업 대기열을 거치지 않고 곧바로 호출자의 스레드에 할당되어 실행된다.

![`CoroutineStart.UNDISPATCHED` 의 동작](/assets/img/dev/2025/0623/undispatched.webp)

---

`UNDISPATCHED` 를 사용할 때 반드시 알아야 할 주의할 점은 이 **'디스패처를 건너뛰는' 특권은 오직 코루틴이 시작될 때, 첫 번재 중단점을 만나기 전까지만 유효**하다는 점이다.

만일 코루틴 내부에 `delay()` 나 `withContext()` 같은 중단 함수를 만나 **일시 중단되었다가 재개될 때는 원래의 동작대로 디스패처를 거쳐 실행**된다.

```kotlin
package chap11

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(start = CoroutineStart.UNDISPATCHED) {
        println("[${Thread.currentThread().name}] 일시 중단 전에는 CoroutineDispatcher 를 거치지 않고 실행됨")
        delay(100L)
        println("[${Thread.currentThread().name}] 일시 중단 후에는 CoroutineDispatcher 를 거쳐서 실행됨")
    }
}
```

- launch 코루틴이 `UNDISPATCHED` 옵션으로 호출되어 main 스레드에서 즉시 실행을 시작하고 첫 번째 println() 을 출력함
- delay(100L) 을 만나 코루틴이 이시 중단됨
- 100ms 후 코루틴이 재개될 준비가 되면, 이번에는 디스패처를 건너뛰지 않고 **정상적으로 main 스레드의 디스패처에 의해 스케쥴링되어 실행**됨. 그리고 두 번째 println() 을 출력함

```shell
[main @coroutine#2] 일시 중단 전에는 CoroutineDispatcher 를 거치지 않고 실행됨
[main @coroutine#2] 일시 중단 후에는 CoroutineDispatcher 를 거쳐서 실행됨
```

![`CoroutineStart.UNDISPATCHED` 의 일시 중단 후 재개 동작](/assets/img/dev/2025/0623/undispatched2.webp)

---

이처럼 **`UNDISPATCHED` 는 특정 상황에서 즉각적인 실행을 보장할 때 유용**하지만, **중단 이후에는 동작 방식이 변경되므로 코드의 흐름을 예측하기 어렵게** 만들 수 있다.  
따라서 이 옵션은 코루틴의 동작 메커니즘을 명확히 이해하고, **매우 제한적인 경우에만 신중하게 사용**해야 한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)