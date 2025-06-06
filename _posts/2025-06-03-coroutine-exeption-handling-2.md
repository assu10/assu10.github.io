---
layout: post
title:  "Coroutine - 예외 처리(2): 예외 처리 방법"
date: 2025-05-30
categories: dev
tags: kotlin coroutine coroutine-exception-handler async cancellation-exception withtimeout job-cancellation-exception withtieoutornull
---

구조화된 동시성이라는 코루틴의 핵심 개념은 예외 전파 방식에 깊이 관여한다.  
이 포스트에서는 아래 내용에 대해 알아본다.

- CoroutineExceptionHandler 를 활용한 예외 처리
- try-catch 로 예외 처리할 때 주의할 점
- 예외는 어디서 catch 해야 하는가?
- `async()` 로 만든 코루틴은 왜 try-catch 로 감싸도 예외를 잡지 못하는가?
- 전파되지 않는 예외: `withContext()`

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap08) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `CoroutineExceptionHandler()` 를 사용한 예외 처리](#1-coroutineexceptionhandler-를-사용한-예외-처리)
  * [1.1. 처리되지 않은 예외만 처리](#11-처리되지-않은-예외만-처리)
  * [1.2. `CoroutineExceptionHandler` 의 동작 위치](#12-coroutineexceptionhandler-의-동작-위치)
  * [1.3. `CoroutineExceptionHandler` 를 사용해야 하는 경우](#13-coroutineexceptionhandler-를-사용해야-하는-경우)
  * [1.4. `CoroutineExceptionHandler` 는 예외 전파를 제한하지 않음](#14-coroutineexceptionhandler-는-예외-전파를-제한하지-않음)
* [2. try-catch 문을 사용한 예외 처리](#2-try-catch-문을-사용한-예외-처리)
  * [2.1. 코루틴 빌더 함수에 대한 try-catch 문은 예외를 잡지 못함](#21-코루틴-빌더-함수에-대한-try-catch-문은-예외를-잡지-못함)
* [3. `async()` 의 예외 처리](#3-async-의-예외-처리)
  * [3.1. `async()` 의 예외 전파: `await()` 없이도 예외는 전파됨](#31-async-의-예외-전파-await-없이도-예외는-전파됨)
  * [3.2. `async()` 와 `launch()` 의 예외 처리](#32-async-와-launch-의-예외-처리)
* [4. 전파되지 않는 예외](#4-전파되지-않는-예외)
  * [4.1. 전파되지 않는 예외, `CancellationException`](#41-전파되지-않는-예외-cancellationexception)
  * [4.2. 코루틴 취소 시 사용되는 `JobCancellationException`](#42-코루틴-취소-시-사용되는-jobcancellationexception)
  * [4.3. `withTimeOut()` 을 사용해 코루틴의 실행 시간 제한](#43-withtimeout-을-사용해-코루틴의-실행-시간-제한)
    * [4.3.1. `withTimeOut()` 의 try-catch](#431-withtimeout-의-try-catch)
    * [4.3.2. `withTimeOutOrNull()`](#432-withtimeoutornull)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. `CoroutineExceptionHandler()` 를 사용한 예외 처리

`CoroutineExceptionHandler()` 는 **구조화된 코루틴 내에서 "최상위 launch 코루틴"의 공통 예외 처리기**로 자주 사용된다.

CoroutineExceptionHandler 시그니처

```kotlin
public inline fun CoroutineExceptionHandler(
  crossinline handler: (CoroutineContext, Throwable) -> Unit
): CoroutineExceptionHandler
```

- `CoroutineExceptionHandler()` 는 **예외가 전파되었을 때 호출할 _handler_ 를 람다식으로** 받는다.
- 이 _handler_ 는 CoroutineContext, Throwable 타입의 매개변수를 갖는 람다식으로 이 람다식에 예외가 발생했을 때 어떤 동작을 할지 입력해 예외를 처리한다.
- 생성된 CoroutineExceptionHandler 객체는 CoroutineContext 객체의 구성 요소로 포함될 수 있어, **launch 시점에 함께 전달**하면 된다.

---

## 1.1. 처리되지 않은 예외만 처리

CoroutineExceptionHandler 객체는 **처리되지 않은 예외(Uncaught Exception)만 처리**한다.  
즉, **자식 코루틴이 예외를 발생시켜 부모 코루틴으로 전파한 경우 자식 코루틴에서는 예외가 처리된 것으로 보아 자식에 설정한 예외 처리 핸들러는 동작하지 않는다.**

자식 코루틴에 설정된 핸들러는 무시되는 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val exceptionHandler = CoroutineExceptionHandler { coroutineContext, throwable ->
        println("Caught~~ [[$throwable]]")
    }
    CoroutineScope(context = Dispatchers.IO).launch(context = CoroutineName("Coroutine1")) {
        launch(context = CoroutineName("Coroutine2") + exceptionHandler) { // CoroutineExceptionHandler 설정
            throw Exception("코루틴 2에 예외 발생")
        }
    }
    delay(1000L)
}
```

```shell
Exception in thread "DefaultDispatcher-worker-3" java.lang.Exception: 코루틴 2에 예외 발생
	at chap08.Code10Kt$main$1$1$1.invokeSuspend(Code10.kt:17)
// ...
Process finished with exit code 0
```

![자식 코루틴에만 설정된 CoroutineExceptionHandler](/assets/img/dev/2025/0603/coroutineException2.webp)

위 코드에서 CoroutineExceptionHandler 는 동작하지 않는다.
- Coroutine2 는 Coroutine1 의 **자식 코루틴**이다.
- 예외는 Coroutine2 → Coroutine1 → 구조화된 상위 코루틴으로 **전파된다.**
- Coroutine2 의 exceptionHandler 는 **예외를 처리한 것이 아니라 상위로 넘겼기 때문에 해당 예외 처리 핸들러는 동작하지 않는다.**

구조화된 코루틴에서 여러 CoroutineExceptionHandler 객체가 설정되어 있어도 예외를 마지막으로 처리하는 위치에 설정된 CoroutineExceptionHandler 객체만 예외를 처리한다.  
이런 특징 때문에 CoroutineExceptionHandler 객체는 '공통 예외 처리기'로서 동작할 수 있다.

예외 처리 핸들러는 이미 처리된(전파된) 예외에 대해서는 무시된다.

그렇다면 예외를 마지막으로 처리하는 위치는 어디일까? 바로 launch 함수로 생성된 코루틴 중 최상위에 있는 코루틴이다.

<**CoroutineExceptionHandler 객체 정리**>
- **처리 대상**
  - 처리되지 않은 예외(Uncaught Exception)
- **작동 위치**
  - **launch 계열**에서만 동작함 (async 는 해당 없음)
- **전파 여부**
  - 예외가 부모로 전파되면 자식의 핸들러는 무시됨
- **실제 적용 위치**
  - **최상위 launch 코루틴**에 설정해야 함

즉, CoroutineExceptionHandler 는 **launch 로 생성된 루트 코루틴의 컨텍스트에 등록**해야 의미가 있다.

---

## 1.2. `CoroutineExceptionHandler` 의 동작 위치

CoroutineExceptionHandler 는 코루틴 계층에 여러 개가 설정되어 있더라도, **최상위 launch 코루틴에 설정된 에러 핸들러만 동작**한다.

CoroutineScope 에 등록된 예외 처리 핸들러가 예외를 처리하는 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val exceptionHandler = CoroutineExceptionHandler { coroutineContext, throwable ->
        println("Caught~~ [[$throwable]]")
    }
    CoroutineScope(context = exceptionHandler).launch(context = CoroutineName("Coroutine1")) {
        launch(context = CoroutineName("Coroutine2")) {
            throw Exception("코루틴 2에 예외 발생")
        }
    }
    delay(1000L)
}
```

- CoroutineScope 의 컨텍스트에 설정한 _exceptionHandler_ 가 Coroutine1 → Coroutine2 로 이어지는 예외 전파의 최상위에 존재함
- 따라서 Coroutine1 에서 예외를 처음으로 처리하며, 해당 예외 처리 핸들러가 동작함

CoroutineScope() 함수가 호출되면 기본적으로 Job 객체가 새로 생성되므로 runBlocking 이 호출되어 만들어지는 Job 객체와의 구조화가 깨지고,
Coroutine1 코루틴은 CoroutineScope 객체로부터 CoroutineContext 를 상속받아 exceptionHandler 가 상속된다.
Coroutine2 코루틴도 Coroutine1 코루틴으로부터 exceptionHandler 를 상속받아 아래와 같은 구조가 된다.

![CoroutineExceptionHandler 설정](/assets/img/dev/2025/0603/coroutineException.webp)

```shell
Caught~~ [[java.lang.Exception: 코루틴 2에 예외 발생]]

Process finished with exit code 0
```

Coroutine2 코루틴에서 발생한 예외가 exceptionHandler 에 의해 처리되어 예외 정보가 출력된 것을 확인할 수 있다.

exceptionHandler 는 CoroutineScope 객체, Coroutine 1,2 코루틴에도 모두 설정되어 있다.
그렇다면 셋 중 어디에 설정된 exceptionHandler 가 예외를 처리한 것일까?

바로 launch 함수로 생성된 코루틴 중 최상위에 있는 코루틴인 Coroutine1 코루틴이다.

위 그림에서 빨간색으로 표시된 launch 코루틴 중 최상위에 있는 Coroutine11 코루틴에 설정된 CoroutineExceptionHandler 객체만 동작해 예외가 출력된다.

이를 확인하기 위해 코드를 아래와 같이 바꿔보자.

예외 처리 핸들러를 각각 다른 위치에 설정한 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val exceptionHandler = CoroutineExceptionHandler { coroutineContext, throwable ->
        println("Caught 1~~ [[$throwable]]")
    }
    val exceptionHandler2 = CoroutineExceptionHandler { coroutineContext, throwable ->
        println("Caught 2~~ [[$throwable]]")
    }

    CoroutineScope(context = Dispatchers.IO + exceptionHandler)
        .launch(context = CoroutineName("Coroutine1") + exceptionHandler2) {
            launch(context = CoroutineName("Coroutine2")) {
                throw Exception("코루틴 2에 예외 발생")
            }
        }
    delay(1000L)
}
```

```shell
Caught 2~~ [[java.lang.Exception: 코루틴 2에 예외 발생]]

Process finished with exit code 0
```

![최상위 launch 코루틴의 예외 처리기](/assets/img/dev/2025/0603/coroutineException3.webp)

- 최상위 launch 코루틴인 Coroutine1 에 설정된 _exceptionHandler2_ 가 실제로 예외를 처리함
- 그보다 상위인 CoroutineScope 의 예외 처리 핸들러인 _exceptionHandler_ 는 무시됨

---

`CoroutineExceptionHandler` 는 **launch 계열의 루트 코루틴에만 적용**된다. (예외 로깅, 공통 에러 처리, 모니터링 로직은 최상위 예외 처리 핸들러에 넣어야 함)  
따라서 **`async` 에서는 무조건 await() + try-catch 로 예외를 처리**해야 한다.

---

## 1.3. `CoroutineExceptionHandler` 를 사용해야 하는 경우

CoroutineExceptionHandler 의 handleException() 함수는 예외가 발생해 코루틴이 이미 완료된 상태에서 호출되기 때문에 **예외 복구나 재시도에는 사용할 수 없다.**

그렇다면 CoroutineExceptionHandler 는 언제 써야 할까?  
CoroutineExceptionHandler 는 **예외 발생 시 공통된 후처리 작업을 수행**하기 위해 사용된다.
- 예외 로깅
- 사용자 알림
- 외부 모니터링 툴 연동
- 앱 전역 처리 로직 등

```kotlin
package chap08

import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
  val exceptionHandler: CoroutineExceptionHandler = CoroutineExceptionHandler { coroutineContext, throwable ->
    println("예외 로깅~~ $throwable")
  }
  CoroutineScope(Dispatchers.IO)
    .launch(context = CoroutineName("Coroutine1") + exceptionHandler) {
      launch(context = CoroutineName("Coroutine2")) {
        throw Exception("코루틴2에 예외 발생함")
      }
      launch(context = CoroutineName("Coroutine3")) {
        delay(200L) // 이게 없으면 예외가 발생하기 전에 코루틴 3 이 실행됨. 코루틴 3 으로 예외 전파가 되는지 여부를 확인해보기 위해 넣어봄
        println("코루틴 3 실행")
      }
    }
  delay(1000L)
}
```

- 예외는 **Coroutine2 에서 발생**함
- 구조상 예외는 상위인 **Coroutine1 으로 전파**됨
- Coroutine1 에 설정된 _exceptionHandler_ 가 **공통 예외 핸들러 역할**을 수행함

```shell
예외 로깅~~ java.lang.Exception: 코루틴2에 예외 발생함

Process finished with exit code 0
```

![CoroutineExceptionHandler 를 사용해야 하는 경우](/assets/img/dev/2025/0603/coroutineException3.webp)

---

앱 전역 오류 처리가 필요한 경우 ViewModelScope, ApplicationScope 의 루트에 등록하여 사용한다.  
네트워크 요청 등 실패가 허용되는 작업에는 [SupervisorJob](https://assu10.github.io/dev/2025/05/30/coroutine-exeption-handling-1/#22-supervisorjob-%EA%B0%9D%EC%B2%B4%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%98%88%EC%99%B8-%EC%A0%84%ED%8C%8C-%EC%A0%9C%ED%95%9C) 과 함께 사용한다.  
UI 앱이라면 Toast, Snackbar, Alert 등 사용자 알림 처리에 유용하다.

---

## 1.4. `CoroutineExceptionHandler` 는 예외 전파를 제한하지 않음

많은 개발자들이 CoroutineExceptionHandler 를 **try-catch 처럼 예외를 '잡아서 흐름을 멈추는' 기능으로 오해**할 수 있다.  
하지만 CoroutineExceptionHandler 는 **예외를 '처리'는 해도 '전파를 막지는 않는다.'**

CoroutineExceptionHandler 는 try-catch 문처럼 동작하지 않는다. 즉, 예외 전파를 제한하지 않는다.
CoroutineExceptionHandler 는 예외가 마지막으로 처리되는 위치에서 예외를 처리할 뿐, 예외 전파를 제한하지 않는다.

```kotlin
package chap08

import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val exceptionHandler: CoroutineExceptionHandler = CoroutineExceptionHandler { coroutineContext, throwable ->
        println("Caught~ $throwable")
    }
    launch(context = CoroutineName("Coroutine1") + exceptionHandler) {
        throw Exception("예외가 발생함")
    }
}
```

- Coroutine1 코루틴에서 예외가 발생한다.
- runBlocking 의 자식 launch 코루틴에서 예외가 발생하면 예외가 runBlocking 까지 전파되어 프로그램이 종료된다.

CoroutineExceptionHandler 는 **루트 코루틴(부모가 없는 launch) 에서만 동작**한다.  
위 코드에서 Coroutine1 은 runBlocking 의 자식으로 **루트가 아니므로** 예외가 전파되어 runBlocking 을 종료시키고, **프로세스가 비정상 종료**된다.

결과를 보면 예외가 전파되어 프로세스가 비정상 종료된 것을 확인할 수 있다. (exit code 1 로 종료됨)

```shell
Exception in thread "main" java.lang.Exception: 예외가 발생함
  // ...
Process finished with exit code 1
```

![예외 전파를 제한하지 않는 CoroutineExceptionHandler](/assets/img/dev/2025/0603/coroutineException5.webp)

---

❗️ **아래 상황에서는 CoroutineExceptionHandler 가 동작하지 않는다.**

- `launch()` 가 runBlocking 의 자식일 때
- `async()` 를 사용할 때
  - 이 때는 try-catch 또는 SupervisorJob + launch 패턴을 사용해야 함

---

# 2. try-catch 문을 사용한 예외 처리

CoroutineExceptionHandler 는 처리되지 않은 예외에 대해서만 동작하지만, **try-catch 는 예외가 발생한 지점에서 즉시 처리**할 수 있다.  
따라서 try-catch 는 정밀한 예외 복구, 로직 분기 등에 사용된다.

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    launch(context = CoroutineName("Coroutine1")) {
        try {
            throw Exception("Coroutine1 에서 예외 발생")
        } catch(e: Exception) {
            println(e.message)
        }
    }

    launch(context = CoroutineName("Coroutine2")) {
        delay(100L)
        println("Coroutine2 실행")
    }
}
```

![try-catch 문을 사용한 예외 처리](/assets/img/dev/2025/0603/tryCatch.webp)

```shell
Coroutine1 에서 예외 발생
Coroutine2 실행

Process finished with exit code 0
```

- Coroutine1 에서 예외가 발생했지만 try-catch 문으로 즉시 처리되어 **상위 코루틴인 runBlocking 으로 예외가 전파되지 않음**
- 따라서 Coroutine2 는 영향을 받지 않고 **정상적으로 실행됨**
- CoroutineExceptionHandler 와는 달리, try-catch 는 예외 목구 및 제어 흐름 유지가 가능함



⚠️ 주의할 점!
- `launch()` 와는 달리 `async()` 에서 발생한 예외는 `await()` 호출 시 발생하므로 try-catch 는 `await()` 로 감싸야 한다.
- 구조화된 코루틴에서 try-catch 로 하위 코루틴의 예외를 감싸더라도, 부모 코루틴이 함께 취소되는 문제는 [SupervisorJob](https://assu10.github.io/dev/2025/05/30/coroutine-exeption-handling-1/#22-supervisorjob-%EA%B0%9D%EC%B2%B4%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%98%88%EC%99%B8-%EC%A0%84%ED%8C%8C-%EC%A0%9C%ED%95%9C) 없이는 막을 수 없다.

---

## 2.1. 코루틴 빌더 함수에 대한 try-catch 문은 예외를 잡지 못함

try-catch 문 사용 시 많이 하는 실수는 코루틴 빌더 함수(`launch()`, `async()`) 자체를 try-catch 문으로 감싸는 것이다.  
하지만 그렇게 하면 코루틴 내부에서 발생하는 예외는 잡히지 않는다.

코루틴 빌더를 try-catch 문으로 감싸는 잘못된 예외 처리 방식의 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    try {
        launch(context = CoroutineName("Coroutine1")) {
            throw Exception("코루틴 1 에서 예외 발생")
        }
    } catch (e: Exception) {
        println(e.message)
    }

    launch(context = CoroutineName("Coroutine2")) {
        delay(100L)
        println("코루틴2 실행")
    }
}
```

- `launch()` 는 **코루틴을 생성만** 하고, 실제 코드는 **별도의 스레드에서 비동기로 실행**됨
- 따라서 try-catch 는 `launch()` **함수 자체의 예외만 감지**할 수 있을 뿐, **코루틴 블록 내부에서 발생한 예외는 잡지 못함**
- 결과적으로 Coroutine1 에서 발생한 예외는 상위인 runBlocking 까지 전파되고, 그 결과 전체 프로그램은 **비정상 종료(exit code 1)** 된다.

코루틴에 대한 예외 처리 시에는 코루틴 빌더 함수의 람다식 내부에서 try-catch 문을 사용해야 한다.

```shell
Exception in thread "main" java.lang.Exception: 코루틴 1 에서 예외 발생
// ...

Process finished with exit code 1 // 프로그램이 비정상 종료됨(exit code 1)
```

---

# 3. `async()` 의 예외 처리

`async()` 는 비동기 연산의 결과를 Deferred\<T\> 객체로 감싸서 반환한다.  
따라서 코루틴 블록 내부에서 예외가 발생해도 그 즉시 예외가 노출되지 않고, `await()` 호출 시점에 예외가 노출된다.

`async()` 코루틴 빌더 함수 사용 시엔 반드시 `await()` 호출부에서 try-catch 문을 감싸야 한다.

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope

fun main() = runBlocking<Unit> {
    supervisorScope {
        val deferred: Deferred<String> = async(context = CoroutineName("Coroutine1")) {
            throw Exception("코루틴1 예외 발생")
        }
        try {
            deferred.await()
        } catch (e: Exception) {
            println("예외 잡음~ ${e.message}")
        }
    }
}
```

- 예외는 `await()` 시점에 발생하고, try-catch 로 안전하게 처리됨
- [supervisorScope](https://assu10.github.io/dev/2025/05/30/coroutine-exeption-handling-1/#23-supervisorscope-%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%98%88%EC%99%B8-%EC%A0%84%ED%8C%8C-%EC%A0%9C%ED%95%9C) 덕분에 예외가 상위 코루틴으로 전파되지 않음

```shell
예외 잡음~ 코루틴1 예외 발생

Process finished with exit code 0
```

만일 supervisorScope 가 없다면 아래처럼 예외는 처리되지만, runBlocking 으로 예외가 전파되어 프로그램이 비정상 종료된다.
```shell
예외 잡음~ 코루틴1 예외 발생
Exception in thread "main" java.lang.Exception: 코루틴1 예외 발생
// ...

Process finished with exit code 1 // 비정상 종료(exit code 1)
```

---

## 3.1. `async()` 의 예외 전파: `await()` 없이도 예외는 전파됨

**`async()` 도 예외 발생 시 부모에게 예외를 전파**한다.  
많은 개발자들이 `async()` 사용 시 예외가 `await()` 를 호출해야만 노출된다고 생각하지만 **예외는 항상 부모 코루틴에게 전파**된다.

예외 전파를 고려하지 않은 `async()` 의 잘못된 사용 예시
```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>{
    async(context = CoroutineName("Coroutine1")) {
        throw Exception("Coroutine1 에서 예외 발생")
    }
    launch(context = CoroutineName("Coroutine2")) {
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }
}
```

- `await()` 를 호출하지 않았음에도 예외 발생
- Coroutine1 에서 발생한 예외가 runBlocking 으로 전파
- 부모 코루틴이 취소되면서 자식 코루틴인 Coroutine2 도 실행되지 않음

```shell
Exception in thread "main" java.lang.Exception: Coroutine1 에서 예외 발생
// ...

Process finished with exit code 1
```

이를 해결하기 위해서는 코루틴1 에서 발생한 예외가 부모 코루틴으로 전파되지 않도록 supervisorScope 를 사용하여 예외 전파를 제한시키면 된다.

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope

fun main() = runBlocking<Unit> {
    supervisorScope {
        async(context = CoroutineName("Coroutine1")) {
            throw Exception("Coroutine1 에서 예외 발생")
        }
        launch(context = CoroutineName("Coroutine2")) {
            delay(100L)
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    }
}
```

```shell
[main @Coroutine2#3] 코루틴 실행

Process finished with exit code 0
```

- Coroutine1 의 예외는 Coroutine2 에 영향을 주지 않음
- supervisorScope 덕분에 자식 코루틴 간 예외 전파 차단

⚠️ 주의할 점
- `async()` 는 예외가 발생하면 **부모 코루틴을 즉시 취소**시킨다.
- `await()` 호출 여부와는 무관하게 **예외는 즉시 전파**된다.
- 따라서 **예외 전파를 막고 싶다면 supervisorScope 로 감싸야 한다.**

**`async()` 코루틴 빌더**를 사용할 때는 **전파되는 예외와 await 호출 시 노출되는 예외를 모두 처리**해주어야 한다.

---

## 3.2. `async()` 와 `launch()` 의 예외 처리

|    구분    | `launch()`                                      | `async()`                     |
|:--------:|:------------------------------------------------|:------------------------------|
|   반환값    | Job (결과 없음)                                     | Deferred\<T\> (결과 있음)         |
| 예외 전파 시점 | 즉시 전파됨                                          | `await()` 호출 시점에 전파됨          |
|  예외 처리   | 코루틴 내부에서 try-catch 또는 CoroutineExceptionHandler | `await()` 를 try-catch 로 감싸야 함 |

---

# 4. 전파되지 않는 예외

---

## 4.1. 전파되지 않는 예외, `CancellationException`

`CancellationException` 는 **코루틴의 취소를 나타내는 특별한 예외**이기 때문에 내부적으로 취소 플래그로만 동작하고 **다른 코루틴에는 영향을 주지 않는다.**  
즉, **`CancellationException` 은 부모에게 예외를 전파하지 않는다.**

```kotlin
package chap08

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit>(context = CoroutineName("runBlocking 코루틴")) {
    launch(context = CoroutineName("Coroutine1")) {
        launch(context = CoroutineName("Coroutine2")) {
            throw CancellationException()
        }
        delay(100L)
        println("[${Thread.currentThread().name}] 코루틴 실행")
    }
    delay(100L)
    println("[${Thread.currentThread().name}] 코루틴 실행")
}
```

- Coroutine2 에서 `CancellationException` 이 발생
- 하지만 `CancellationException` 는 **코루틴 자체를 취소하는 용도**이므로 예외가 부모 코루틴으로 전파되지 않음
- Coroutine2 만 종료되고, 나머지 코루틴은 **정상 실행**

만일 Coroutine2 코루틴에서 발생한 예외가 Exception, RuntimeException 이었다면 예외가 부모로 전파되어 구조화된 코루틴 전체가 취소되었을 것ㅇ다.

```shell
[main @runBlocking 코루틴#1] 코루틴 실행
[main @Coroutine1#2] 코루틴 실행

Process finished with exit code 0
```

![예외 전파되지 않는 cancellationException](/assets/img/dev/2025/0603/cancellationException.webp)

---

## 4.2. 코루틴 취소 시 사용되는 `JobCancellationException`

`CancellationException` 은 **취소 신호로 사용**된다.  
코틀린 코루틴은 **`CancellationException` (혹은 그 하위 클래스인 `JobCancellationException`)**  내부적으로 **코루틴 취소의 시그널**로 사용한다.  
이는 일반적인 예외 처리와는 목적이 다르며 **부모 코루틴으로 전파되지 않고 해당 코루틴만 종료**시키는 특성을 가진다.

코루틴 취소 시 JobCancellationException 확인하는 예시
```kotlin
package chap08

import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking<Unit> {
    val job: Job = launch {
        delay(1000L)
    }
    job.invokeOnCompletion { e ->
        println("--- ${e}") // 발생한 예외 출력
    }
    job.cancel() // job 취소
}
```

- job.cancel() 호출 → 내부적으로 `JobCancellationException` 발생
- 해당 코루틴은 정상적으로 종료된 것처럼 간주됨 (해당 Job(코루틴) 취소)
- **`invokeOnCompletion()` 을 사용하면 코루틴 종료 사유를 콜백으로 받아 종료 사유를 로깅할 수 있으며**, 이 때 발생한 예외가 `JobCancellationException` 임을 확인 가능

```shell
--- kotlinx.coroutines.JobCancellationException: StandaloneCoroutine was cancelled; job=StandaloneCoroutine{Cancelled}@71bc1ae4

Process finished with exit code 0
```

**`JobCancellationException` 은 전파되지 않는다.**
- 일반 예외(Exception, RuntimeException) 과는 다르게 `JobCancellationException` 은 부모나 형제 코루틴을 취소하지 않는다.

---

## 4.3. `withTimeOut()` 을 사용해 코루틴의 실행 시간 제한

`withTimeOut()` 함수는 코루틴 실행 시간을 제한할 수 있다.

`withTimeOut()` 함수는 특정 시간이 초과되면 **작업을 강제로 중단**시키고, `TimeoutCancellationException` 을 발생시켜 해당 코루틴만 취소한다.  
이 예외는 `CacellationException` 의 하위 클래스이므로 **부모 코루틴으로 전파되지 않으며**, 프로그램 종료없이 안전하게 사용 가능하다.

`withTimeOut()` 시그니처
```kotlin
public suspend fun <T> withTimeout(timeMillis: Long, block: suspend CoroutineScope.() -> T): T
```

- timeMillis
  - 제한 시간(ms)
- block
  - 실행할 suspend 함수 블록

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout

fun main() = runBlocking<Unit>(CoroutineName("Parent")) {
    launch(context = CoroutineName("Child")) {
        withTimeout(1000L) { // 실행 시간을 1초로 제한
            delay(2000L) // 2초 걸리는 작업
            println("[${Thread.currentThread().name}] 코루틴 실행11")
        }
    }
    delay(2000L)
    println("[${Thread.currentThread().name}] 코루틴 실행22")
}
```

```shell
[main @Parent#1] 코루틴 실행22

Process finished with exit code 0
```

- Child 코루틴은 2초 동안 대기하려 했지만 withTimeout(1000L) 으로 인ㅇ해 1초 후 `TimeoutCancellationException` 발생
- 이 예외는 부모 코루틴으로 전파되지 않기 때문에 Parent 코루틴은 영향을 받지 않고 정상 실행됨
- `TimeoutCancellationException` 은 `CancellationException` 의 하위 클래스이므로 **취소만 유도하고 예외 전파는 하지 않음**

`withTimeOut()` 사용 시엔 반드시 **예외를 try-catch 로 잡거나**, **취소 로직을 처리**해야 안전한 종료가 가능하다.  
`withTimeOut()` 에 설정된 제한 시간을 초과하면 **지연되던 블록은 즉시 취소**된다.  
`TimeoutCancellationException` 을 catch 하여 타임아웃 시 예외 메시지를 별도로 처리할 수 있다.

`withTimeOut()` 함수는 실행 시간이 제한되어야 할 필요가 있는 네트워크 호출의 실행 시간 제한, IO 작업, 사용자 입력 제한 등에 사용된다.

---

### 4.3.1. `withTimeOut()` 의 try-catch

```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout

fun main() = runBlocking<Unit>(context = CoroutineName("Parent")) {
    try {
        withTimeout(2000L) {
            delay(2000L) // 2초의 작업이 걸리는 작업
            println("[${Thread.currentThread().name}] 코루틴 실행")
        }
    } catch (e: Exception) {
        println("e: ${e}")
    }
}
```

```shell
e: kotlinx.coroutines.TimeoutCancellationException: Timed out waiting for 2000 ms

Process finished with exit code 0
```

결과를 보면 `withTimeOut()` 에서 발생한 예외가 catch 문에 잡혀 로그가 출력되는 것을 확인할 수 있다.

---

### 4.3.2. `withTimeOutOrNull()`

`withTimeOut()` 은 예외를 던지지만, `withTimeOutOrNull()` 은 null 을 반환한다.

`withTimeOutOrNull()` 은 `withTimeOut()` 과 동일하게 **작업 시간 제한**을 두되, 시간이 초과될 경우 `TimeoutCancellationException` 을 **던지지 않고 null 을 반환**한다.  
이로 인해 **예외 처리 없이도 안전하게 timeout 상황을 감지**할 수 있다.


```kotlin
package chap08

import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull

fun main() = runBlocking<Unit>(context = CoroutineName("Parent")) {
    launch(context = CoroutineName("Coroutine")) {
        val result: String? = withTimeoutOrNull(1000L) { // 실행 시간을 1초로 제한
            delay(2000L) // 2초의 시간이 걸리는 작업
            return@withTimeoutOrNull "결과"
        }
        println("result: $result")
    }
}
```

```shell
result: null

Process finished with exit code 0
```

- delay(2000L) 로 작업은 제한 시간 1초를 초과함
- `withTimeOutOrNull()` 은 예외를 던지지 않고 null 반환
- 예외 없이 null 을 출력하고 정상 종료됨

`withTimeOutOrNull()` 은 아래와 같은 상황에 사용된다.
- **예외 발생 없이 timeout 을 처리하고 싶은 경우**
- **타임아웃 여부만으로 분기 처리를 하고 싶은 경우**
- 예) 캐시 조회 또는 외부 서비스 호출 실패 시 fallback 처리 등

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)