---
layout: post
title:  "Coroutine - 예외 처리(1): 예외 전파 제한 방법"
date: 2025-05-30
categories: dev
tags: kotlin coroutine supervisor-job supervisor-scope
---

구조화된 동시성이라는 코루틴의 핵심 개념은 예외 전파 방식에 깊이 관여한다.  
이 포스트에서는 아래 내용에 대해 알아본다.
- 코루틴이 예외를 전파하는 방식
- 예외 전파를 막거나 범위를 제한하는 방법

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap08) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 코루틴의 예외 전파](#1-코루틴의-예외-전파)
* [2. 예외 전파 제한 3가지 방법](#2-예외-전파-제한-3가지-방법)
  * [2.1. Job 객체로 예외 전파 제한](#21-job-객체로-예외-전파-제한)
    * [2.1.1. Job 객체로 구조화 깨기](#211-job-객체로-구조화-깨기)
    * [2.1.2. Job 객체를 사용한 예외 전파의 한계](#212-job-객체를-사용한-예외-전파의-한계)
  * [2.2. `SupervisorJob` 객체를 사용한 예외 전파 제한](#22-supervisorjob-객체를-사용한-예외-전파-제한)
    * [2.2.1. 구조화를 유지하지 않는 `SupervisorJob` 잘못된 사용](#221-구조화를-유지하지-않는-supervisorjob-잘못된-사용)
    * [2.2.2. 구조화를 유지한 `SupervisorJob` 사용](#222-구조화를-유지한-supervisorjob-사용)
    * [2.2.3. `SupervisorJob` 을 `CoroutineScope` 와 함께 사용](#223-supervisorjob-을-coroutinescope-와-함께-사용)
    * [2.2.4. `SupervisorJob` 을 사용할 때 흔히 하는 실수](#224-supervisorjob-을-사용할-때-흔히-하는-실수)
  * [2.3. `supervisorScope()` 를 사용한 예외 전파 제한](#23-supervisorscope-를-사용한-예외-전파-제한)
  * [2.4. `coroutineScope()` vs `supervisorScope()`](#24-coroutinescope-vs-supervisorscope)
  * [2.5. `SupervisorJob` vs `supervisorScope()`](#25-supervisorjob-vs-supervisorscope)
    * [2.5.1. 내부 동작 차이](#251-내부-동작-차이)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 코루틴의 예외 전파

코루틴은 동시성을 안전하게 다룰 수 있도록 구조화된 동시성 개념을 따른다.  
이 구조 덕분에 코루틴이 예외를 발생시키면 단지 해당 코루틴만 종료되는 것이 아니라 **전체 구조에 영향을 미치는 예외 전파**가 발생한다.

여기서는 예외가 어떻게 전파되고, 왜 예외 하나가 전체 코루틴 구조를 중단시킬 수 있는지에 대해 알아본다.

코루틴 내부에서 예외가 발생하면 **해당 코루틴은 즉시 취소**되고, **부모 코루틴으로 예외가 전파**된다.  
부모 코루틴에서도 예외를 처리하지 않으면 **상위 코루틴까지 전파**되며, 최종적으로 **루트 코루틴(runBlocking 등)까지 도달**할 수 있다.

또한 코루틴의 구조상, **한 코루틴의 취소는 그 자식 코루틴들까지 영향을 미치므로 예외 하나로 전체 코루틴 트리가 취소**될 수 있다.

예외 하나가 전체 코루틴을 취소시키는 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = CoroutineName("Coroutine1")) {
        launch(context = CoroutineName("Coroutine3")) {
            throw Exception("예외 발생")
        }
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }

    launch(context = CoroutineName("Coroutine2")) {
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }

    delay(1000L)
}
```

```shell
Exception in thread "main" java.lang.Exception: 예외 발생
	at chap08.Code01Kt$main$1$1$1.invokeSuspend(Code01.kt:11)
	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
	at kotlinx.coroutines.EventLoopImplBase.processNextEvent(EventLoop.common.kt:263)
	at kotlinx.coroutines.BlockingCoroutine.joinBlocking(Builders.kt:95)
	at kotlinx.coroutines.BuildersKt__BuildersKt.runBlocking(Builders.kt:69)
	at kotlinx.coroutines.BuildersKt.runBlocking(Unknown Source)
	at kotlinx.coroutines.BuildersKt__BuildersKt.runBlocking$default(Builders.kt:47)
	at kotlinx.coroutines.BuildersKt.runBlocking$default(Unknown Source)
	at chap08.Code01Kt.main(Code01.kt:8)
	at chap08.Code01Kt.main(Code01.kt)
```

- runBlocking 은 루트 코루틴이다.
- Coroutine1, 2 는 자식 코루틴이고, Coroutine3 은 Coroutine1 의 자식 코루틴이다.

- Coroutine3 에서 발생한 예외가 처리되지 않아 Coroutine1 을 통해 runBlocking 까지 전달됨
- 루트 코루틴(runBlocking) 이 취소됨
- 하위 코루틴들인 Coroutine1, 2 도 함께 취소됨
- 결국 모든 코루틴이 실행되지 못하여 예외 로그만 출력되고, "코루틴 실행" 메시지는 보이지 않음

구조화된 동시성은 안전한 자원 정리를 위한 장치이지만, 명시적 예외 처리가 없으면 전체 작업이 중단될 수 있다.  
이러한 문제를 막기 위해 코루틴은 전파되는 예외를 제한하거나 격리하는 방법을 제공한다.

---

# 2. 예외 전파 제한 3가지 방법

특정 코루틴에서 발생한 예외가 전체에 영향을 미치지 않게 하는 방법에 대해 알아본다.

---

## 2.1. Job 객체로 예외 전파 제한

> `Job()` 을 이용한 예외 전파 제한은 구조화를 깨뜨림으로써 구현되는데 이는 취소 전파까지 제한되고, 정상적인 자원 정리의 흐름도 함께 끊어진다.  
> 따라서 해당 코드를 참고만 할 것

### 2.1.1. Job 객체로 구조화 깨기


코루틴은 예외를 **부모 Job 객체를 통해 전파**한다.  
따라서 부모와의 구조화 관계를 인위적으로 끊으면, **예외가 상위로 전파되지 않게 할 수 있다.**

부모 코루틴과의 구조화를 깨는 방법은 새로운 Job 객체를 만들어 구조화를 깨고 싶은 코루틴을 연결하면 된다.

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(CoroutineName("Parent Coroutine")) {
        // 새로운 Job 객체를 만들어 Coroutine1에 연결
        launch(CoroutineName("Coroutine1") + Job()) {
            launch(CoroutineName("Coroutine3")) {
                throw Exception("예외 발생")
            }
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
        launch(CoroutineName("Coroutine2")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    delay(1000L)
}
```

```shell
Exception in thread "main @Coroutine1#3" java.lang.Exception: 예외 발생
	at chap08.Code01Kt$main$1$1$1$1.invokeSuspend(Code01.kt:14)
	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
	at kotlinx.coroutines.EventLoopImplBase.processNextEvent(EventLoop.common.kt:263)
	at kotlinx.coroutines.BlockingCoroutine.joinBlocking(Builders.kt:95)
	at kotlinx.coroutines.BuildersKt__BuildersKt.runBlocking(Builders.kt:69)
	at kotlinx.coroutines.BuildersKt.runBlocking(Unknown Source)
	at kotlinx.coroutines.BuildersKt__BuildersKt.runBlocking$default(Builders.kt:47)
	at kotlinx.coroutines.BuildersKt.runBlocking$default(Unknown Source)
	at chap08.Code01Kt.main(Code01.kt:9)
	at chap08.Code01Kt.main(Code01.kt)
	Suppressed: kotlinx.coroutines.internal.DiagnosticCoroutineContextException: [CoroutineName(Coroutine1), CoroutineId(3), "Coroutine1#3":StandaloneCoroutine{Cancelling}@457e2f02, BlockingEventLoop@5c7fa833]
[main @Coroutine2#4] 코루틴 실행
```

- Coroutine1 은 `Job()` 을 통해 **부모 코루틴과의 구조화를 끊었기 때문에**, 그 내부 자식인 Coroutine3 의 예외가 **Parent Coroutine 까지 전파되지 않음**
- 따라서 Coroutine2 는 예외의 영향을 받지 않고 **정상 실행**

구조화를 의도적으로 끊으면 예외 전파가 차단되므로, **전체 작업 중단을 방지**할 수 있다.

> **구조화를 깨뜨리는 것은 특별한 상황에서만!**
> 
> 일반적으로 **구조화된 동시성의 원칙을 지키는 것이 안전**하다.  
> `Job()` 을 사용해 구조를 끊는 방식은 **의도적으로 분리된 작업을 실행하거나, 독립적인 생명주기를 부여할 때만 사용**해야 한다.

---

### 2.1.2. Job 객체를 사용한 예외 전파의 한계

`Job()` 을 이용한 구조화 깨기 방식은 **예외 전파 뿐 아니라 취소 전파도 제한**한다.

일반적으로 코루틴은 **부모가 취소되면 자식도 함께 취소**된다.  
하지만 새로운 Job() 객체를 생성하면, **해당 코루틴은 부모의 자식이 아니게 되므로** 취소 전파가 일어나지 않는다.

취소가 전파되지 않는 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val parentJob = launch(context = CoroutineName("parentCoroutine")) {
        launch(context = CoroutineName("Coroutine1") + Job()) {
            launch(context = CoroutineName("Coroutine3")) {
                delay(100L)
                println("[${Thread.currentThread().name}] 코루틴 실행")
            }
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }

        launch(context = CoroutineName("Coroutine2")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }

    delay(20L) // 코틀린들이 모두 생성될 때까지 대기
    parentJob.cancel() // ParentCoroutine 에 취소 요청
    delay(1000L)
}
```

```shell
[main @Coroutine1#3] 코루틴 실행
[main @Coroutine3#5] 코루틴 실행
```

- Coroutine1은 `Job()` 을 사용해 구조화를 끊었기 때문에 ParentCoroutine 의 **자식이 아님**
- 따라서 ParentCoroutine 이 `cancel()` 되더라도 **Coroutine1, 3 은 취소되지 않고 정상 실행됨**
- 반면, Coroutine2 는 구조화된 자식이므로 취소 전파에 의해 실행되지 않음

---

**구조화를 깨뜨리는 방식의 한계**

이러한 방식은 예외 전파와 취소 전파 모두를 차단하기 때문에 **정상적인 자원 정리 흐름도 함께 끊어질 수 있다.**  
즉, ParentCoroutine 이 중단되었을 때 **하위 작업도 함께 정리되어야 안정적**인데, 구조화가 깨져있으면 **오히려 비동기 작업의 안정성을 해질 수 있다.**  
**구조화를 유지하면서도 예외 전파만 하는 방식이 더 안전하다.**

구조화를 유지하면 예외만 제한하고 싶다면 코루틴 라이브러리에서 제공하는 `SupervisorJob` 객체를 사용하면 된다.  
이는 구조화된 코루틴 계층을 유지하면서도 **자식의 실패가 부모나 형제 코루틴에 영향을 주지 않도록 해준다.**

---

## 2.2. `SupervisorJob` 객체를 사용한 예외 전파 제한

`SupervisorJob` 은 **구조화된 동시성은 유지하면서도 자식 코루틴 간의 예외 전파를 막을 수 있는 Job** 이다.  
즉, 하나의 자식 코루틴에서 예외가 발생하더라도 **다른 자식 코루틴에게 영향을 주지 않게 할 수 있다.**

SupervisorJob 시그니처

```kotlin
public fun SupervisorJob(parent: Job? = null) : CompletableJob = SupervisorJobImpl(parent)
```

- `parent` 인자를 생략하면 루트 `SupervisorJob` 으로 동작
- `parent` 인자에 **상위 Job 을 넣으면 구조화를 유지**하면서 사용 가능

<br />

<**`SupervisorJob` 를 사용하는 이유와 주의점**>
- **역할**
  - 자식 코루틴 간 예외 전파 방지
- **구조화 유지**
  - `SupervisorJob(parent)` 사용 시 가능
- **취소 전파**
  - 부모 Job 이 취소되면 `SupervisorJob` 도 취소됨
- **완료 처리**
  - `complete()` 호출 필요

`SupervisorJob` 은 코루틴 간 결합을 느슨하게 유지하면서 안정성을 높이는 전략이다. 특히 UI 작업, 네트워크 요청, 로그 기록 작업 등 **실패해도 다른 작업에 영향을 
주면 안되는 작업에 유용**하다.

---

### 2.2.1. 구조화를 유지하지 않는 `SupervisorJob` 잘못된 사용

SupervisorJob 객체로 예외를 전파시키지 않는 예시 (구조화를 유지하지 않음)
```kotlin
package chap08

import kotlinx.coroutines.CompletableJob
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val supervisor: CompletableJob = SupervisorJob()
  launch(context = CoroutineName("Coroutine1") + supervisor) { // supervisor 객체 사용
    launch(context = CoroutineName("Coroutine3")) {
      throw Exception("예외 발생")
    }
    delay(100L)
    println("[${Thread.currentThread().name}] 코루틴 실행")
  }
  launch(context = CoroutineName("Coroutine2") + supervisor) { // supervisor 객체 사용
    delay(100L)
    println("[${Thread.currentThread().name}] 코루틴 실행")
  }
  delay(1000L)  // 1초 뒤 전체 코루틴 종료
}
```

![SupervisorJob 을 사용한 취소 전파 제한](/assets/img/dev/2025/0530/supersivor1.webp)

```shell
Exception in thread "main @Coroutine1#2" java.lang.Exception: 예외 발생
	at chap08.Code04Kt$main$1$1$1.invokeSuspend(Code04.kt:14)
    // ...
	Suppressed: kotlinx.coroutines.internal.DiagnosticCoroutineContextException: [CoroutineName(Coroutine1), CoroutineId(2), "Coroutine1#2":StandaloneCoroutine{Cancelling}@39aeed2f, BlockingEventLoop@724af044]
[main @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

- Coroutine3 → 예외 발생 → Coroutine1 취소됨
- 하지만 Coroutine2 는 영향을 받지 않고 **정상 실행**됨

**`SupervisorJob` 덕분에 자식 간 예외 전파가 차단된 것**이다.

⚠️ 하지만 이 코드는 구조화를 깨뜨리는 문제가 있다.  
위 코드는 `SupervisorJob` 이 **`runBlocking` 이 생성한 Job 과 구조화되어 있지 않기** 때문에 `runBlocking` 이 취소되더라도 `SupervisorJob` 하위 코루틴은 
**취소되지 않을 수 있다.**

---

### 2.2.2. 구조화를 유지한 `SupervisorJob` 사용

구조화를 깨지 않고 SupervisorJob 을 사용하기 위해서는 SupervisorJob 의 인자로 부모 Job 객체를 넘기면 된다.

```kotlin
package chap08

import kotlinx.coroutines.CompletableJob
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    // supervisorJob 의 parent 로 runBlocking 이 호출되어 만들어진 Job 객체 설정
    val supervisor: CompletableJob = SupervisorJob(parent = this.coroutineContext[Job])

    launch(context = CoroutineName("Coroutine1") + supervisor) { // supervisor 객체 사용
        launch(context = CoroutineName("Coroutine3")) {
            throw Exception("예외 발생")
        }
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }
    launch(context = CoroutineName("Coroutine2") + supervisor) { // supervisor 객체 사용
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }
    // supervisor 완료 처리 (이게 없으면 전체 코루틴 종료가 되지 않음)
    supervisor.complete()
}
```

- **구조화 유지**
  - `SupervisorJob` 이 runBlocking 의 Job 을 부모로 가지므로 전체 작업 구조 내에서 관리된다.
- **자식 간 예외 차단**
  - 예외는 Coroutine1 만 취소시키고, Coroutine2 는 영향이 없다.
- **명시적 완료 처리**
  - SupervisorJob() 을 통해 생성된 Job 객체는 자동 완료 처리되지 않으므로 supervisor.complete() 호출이 필요하다.

마지막에 supervisor.complete() 를 실행하여 SupervisorJob 에 대해 명시적으로 완료 처리를 한다.  
SupervisorJob() 을 통해 생성된 Job 객체는 Job() 을 통해 생성된 Job 객체와 같이 자동으로 완료처리 되지 않는다.

![구조화를 깨지 않고 SupervisorJob 사용](/assets/img/dev/2025/0530/supervisor2.webp)

```shell
Exception in thread "main @Coroutine1#2" java.lang.Exception: 예외 발생
	at chap08.Code05Kt$main$1$1$1.invokeSuspend(Code05.kt:17)
    // ...
	Suppressed: kotlinx.coroutines.internal.DiagnosticCoroutineContextException: [CoroutineName(Coroutine1), CoroutineId(2), "Coroutine1#2":StandaloneCoroutine{Cancelling}@c038203, BlockingEventLoop@cc285f4]
[main @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

---

### 2.2.3. `SupervisorJob` 을 `CoroutineScope` 와 함께 사용

`SupervisorJob` 을 CoroutineScope 와 함께 사용하면 **스코프 전체를 구조화된 단위로 유지하면서도 자식 간의 예외 전파를 효과적으로 차단**할 수 있다.

CoroutineScope(context = SupervisorJob()) 처럼 생성하면 이 스코프 내에서 `launch()` 되는 모든 코루틴은 **형제 간 예외에 영향을 받지 않는다.**

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    // CoroutineContext  에 SupervisorJob() 객체 설정
    val coroutineScope = CoroutineScope(context = SupervisorJob())

    coroutineScope.apply {
        launch(context = CoroutineName("Coroutine1")) {
            launch(context = CoroutineName("Coroutine3")) {
                throw Error("예외 발생")
            }
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
        launch(context = CoroutineName("Coroutine2")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
    delay(1000L)
}
```

![CoroutineScope 와 SupervisorJob 함께 사용](/assets/img/dev/2025/0530/supervisor3.webp)

```shell
Exception in thread "DefaultDispatcher-worker-1 @Coroutine1#2" java.lang.Error: 예외 발생
	at chap08.Code06Kt$main$1$1$1$1.invokeSuspend(Code06.kt:17)
    // ...
	Suppressed: kotlinx.coroutines.internal.DiagnosticCoroutineContextException: [CoroutineName(Coroutine1), CoroutineId(2), "Coroutine1#2":StandaloneCoroutine{Cancelling}@597a693c, Dispatchers.Default]
[DefaultDispatcher-worker-1 @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

- Coroutine3 → 예외 발생 → Coroutine1 만 취소
- Coroutine2 는 영향받지 않고 **정상 실행**
- CoroutineScope 에 설정된 SupervisorJob 이 **형제 코루틴 간 예외 전파 차단**

<br />

<**`SupervisorJob` 을 `CoroutineScope` 와 함께 사용할 때의 장점**>
- **스코프 구조화**
  - 전체 작업을 하나의 스코프로 관리
- **자식 간 예외 전파 제한**
  - 하나의 자식이 실패해도 다른 자식은 영향 없음
- **실용성**
  - UI, 병렬 처리, 안정성이 중요한 상황에서 유용

이 방식은 병렬로 여러 작업을 수행하면서 **하나가 실패하더라도 나머지를 계속 유지하고 싶을 때** 사용한다.  
예) 병렬 API 요청, 파일 업로드, 알림 전송 등 **실패 허용 가능한 작업들**

---

### 2.2.4. `SupervisorJob` 을 사용할 때 흔히 하는 실수

`SupervisorJob` 은 자식 코루틴 간의 예외 전파를 방지할 수 있는 훌륭한 도구이다.  
하지만 **코루틴 빌더 함수의 context 인자에 직접 SupervisorJob() 을 넘기는 방식**은 의도와 다르게 동작하여 **오히려 전체 코루틴 트리의 취소를 유발**할 수 있다.

잘못 사용된 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  launch(context = CoroutineName("ParentCoroutine") + SupervisorJob()) {
    launch(context = CoroutineName("Coroutine1")) {
      launch(context = CoroutineName("Coroutine3")) {
        throw Exception("예외 발생")
      }
      delay(100L)
      println("[${Thread.currentThread().name}] 코루틴 실행")
    }
    launch(context = CoroutineName("Coroutine2")) {
      delay(100L)
      println("[${Thread.currentThread().name}] 코루틴 실행")
    }
  }
  delay(1000L)
}
```

```shell
Exception in thread "main @Coroutine2#4" java.lang.Exception: 예외 발생
	at chap08.Code07Kt$main$1$1$1$1.invokeSuspend(Code07.kt:14)
    // ...
	Suppressed: kotlinx.coroutines.internal.DiagnosticCoroutineContextException: [CoroutineName(ParentCoroutine), CoroutineId(2), "ParentCoroutine#2":StandaloneCoroutine{Cancelling}@8bd1b6a, BlockingEventLoop@18be83e4]

Process finished with exit code 0
```

- launch(context = SupervisorJob()) 으로 생성된 _ParentCoroutine_ 은 실제로는 **`SupervisorJob` 을 부모로 하는 새로운 Job 을 갖는 일반적인 코루틴**이 된다.
- 즉, Coroutine3 에서 발생한 예외는 Coroutine1 → ParentCoroutine 까지 전파되어 ParentCoroutine 이 취소되고, 그 하위 코루틴인 Coroutine2 도 함께 취소된다.
- 이 때 **`SupervisorJob` 은 최상위에 존재하지만 아무 역할도 하지 못한다.**

![잘못 사용된 SupervisorJob](/assets/img/dev/2025/0530/supervisor4.webp)

<**`SupervisorJob` 사용 시 주의할 점**>

|  항목   | 잘못된 사용                              | 올바른 사용                                                                 |
|:-----:|:------------------------------------|:-----------------------------------------------------------------------|
| 사용 위치 | `launch(context = SupervisorJob())` | `CoroutineScope(context = SupervisorJob())` 또는 `SupervisorJob(parent)` |
|  결과   | 중간에 새로운 Job 이 생성되어 예외 전파 차단 실패      | 구조화 유지 + 자식 간 예외 차단                                                    |
|       | 위 그림처럼 `SupervisorJob` 이 고립됨        | `SupervisorJob` 이 상위 Job 에 정확히 연결됨                                     |

`SupervisorJob` 를 사용하는 가장 안전한 방식은 `CoroutineScope(context = SupervisorJob())` 으로 스코프를 명시적으로 만들거나, `SupervisorJob(parent)` 로 구조화된 
상위 Job 에 연결하는 것이다.

---

## 2.3. `supervisorScope()` 를 사용한 예외 전파 제한

코루틴의 예외 전파를 제한하는 세 번째 방법은 `supervisorScope()` 함수를 사용하는 것이다.  
`supervisorScope()` 의 목적은 구조화된 동시성을 유지하면서도 자식 코루틴 간 예외 전파를 막는 것이다.

`supervisorScope()` 함수는 내부적으로 `SupervisorJob` 을 포함한 CoroutineScope 를 생성한다.  
이 SupervisorJob 은 `supervisorScope()` 를 호출한 코루틴의 Job 을 부모(여기서는 runBlocking)로 가지며, 이를 통해 구조화를 유지하면서도 
**자식 코루틴 간의 예외 전파를 제한**할 수 있다.

즉, 별도의 설정 없이도 `supervisorScope()` 를 사용하면 **구조화된 동시성을 깨지 않고**, 각 자식 코루틴의 실패가 다른 자식에게 영향을 주지 않도록 설계할 수 있다.

또한 `supervisorScope()` 는 블록 내부 코드와 자식 코루틴이 모두 완료되면 자신의 SupervisorJob 이 **자동으로 완료 처리**되도록 보장한다.

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope

fun main() = runBlocking<Unit>{
  supervisorScope {
    launch(context = CoroutineName("Coroutine1")) {
      launch(context = CoroutineName("Coroutine3")) {
        throw Exception("예외 발생")
      }
      delay(100L)
      println("[${Thread.currentThread().name}] 코루틴 실행")
    }

    launch(context = CoroutineName("Coroutine2")) {
      delay(100L)
      println("[${Thread.currentThread().name}] 코루틴 실행")
    }
  }
}
```

![supervisorScope 를 사용한 코루틴 구조](/assets/img/dev/2025/0530/supervisor5.webp)

```shell
Exception in thread "main @Coroutine1#2" java.lang.Exception: 예외 발생
	at chap08.Code08Kt$main$1$1$1$1.invokeSuspend(Code08.kt:13)
    // ...
[main @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

지금까지 코루틴의 예외 전파를 제한할 수 있는 세 가지 방법에 대해 알아보았다. 이 중 완벽한 정답은 없으며, 각자 상황에 맞춰 고민하고 사용해야 한다.

---

## 2.4. `coroutineScope()` vs `supervisorScope()`

|   구분    | coroutineScope() | supervisorScope() |
|:-------:|:-----------------|:------------------|
| 예외 발생 시 | 전체 스코프 취소        | 다른 자식 코루틴은 유지     |
|   구조화   | 유지됨              | 유지됨               |
|  사용 목적  | 전체 작업의 실패 처리     | 자식 간 독립적인 실패 처리   |

---

## 2.5. `SupervisorJob` vs `supervisorScope()`

둘 다 모두 자식 코루틴 간 예외 전파를 제한하기 위한 수단이지만, 용도와 내부 동작 방식에 차이가 있다.

|      항목       | SupervisorJob                                                          | supervisorScope()                                |
|:-------------:|:-----------------------------------------------------------------------|:-------------------------------------------------|
|      역할       | 자식 코루틴 간 예외 전파를 막는 **Job** 객체                                          | 예외 전파를 제한하는 **Scope builder 함수**                 |
|      구조화      | 직접 CoroutineScope 에 붙여 사용해야 함                                          | runBlocking, launch 등 내부에서 구조화 유지                |
|     생성 방식     | - CoroutineScope(SupervisorJob())<br />- Job(parent) + SupervisorJob() | suspend 함수로 사용하며, 블록 전체가 SupervisorJob 으로 감싸짐    |
| 예외 처리 시 부모 영향 | - 자식이 실패해도 다른 자식에게 영향 없음<br />- 부모 Job 은 수동으로 관리해야 함                   | - 자식이 실패해도 다른 자식에게 영향 없음<br />- 부모와 구조화되어 자동 정리됨 |
|   코루틴 생명주기    | **수동으로 관리**해야 함(cancel() 등)                                            | 블록안의 코드 + 자식 코루틴이 모두 완료되면 **자동 종료**              |
|   적절한 사용 예시   | ViewModel, Application Scope 등 **스코프를 명시적으로 설계할 때**                    | 특정 블록 안에서만 **일시적으로 예외 분리 처리**할 때                 |
|     예시 코드     | CoroutineScope(SupervisorJob()).launch { ... }                         | supervisorScope { launch { ... } }               |

---

### 2.5.1. 내부 동작 차이

<**SupervisorJob 의 내부 동작**>
- Job 의 일종이지만 parentJob 에게 예외를 전파하지 ㅇ낳음
- 자식 코루틴이 실패해도 다른 자식은 취소되지 않음
- 하지만 **코루틴 스코프 자체는 개발자가 직접 관리**해야 함

```kotlin
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
```

<br />

<**supervisorScope() 의 내부 동작**>
- 내부적으로 SupervisorJob() 을 사용하지만, 호출한 코루틴의 Job 을 부모로 가진 **구조화된 Job** 을 생성
- **자동으로 스코프가 닫히고, 예외 핸들링이 구조화 안에서 해결됨**

```kotlin
runBlocking {
  supervisorScope {
    launch { ... }
    launch { ... }
  }
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)