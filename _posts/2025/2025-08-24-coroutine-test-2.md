---
layout: post
title:  "Coroutine - 코루틴 단위 테스트(2): `backgroundScope`"
date: 2025-08-24
categories: dev
tags: kotlin coroutine unit-test kotlinx-coroutines-test runTest Test-dispatcher backgroundScope dependency-injection junit asynchronous concurrency tdd
---

이 포스트에서는 실제 코루틴 코드를 테스트하는 실전 예시에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap12) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 코루틴 단위 테스트 만들어보기](#1-코루틴-단위-테스트-만들어보기)
  * [1.1. _FollowerSearcher_ 클래스 테스트](#11-_followersearcher_-클래스-테스트)
    * [1.1.1. `@BeforeEach` 로 테스트 실행 환경 설정](#111-beforeeach-로-테스트-실행-환경-설정)
    * [1.1.2. 테스트 작성](#112-테스트-작성)
* [2. 코루틴 테스트 심화](#2-코루틴-테스트-심화)
  * [2.1. 함수 내부에서 새로운 코루틴을 실행하는 객체에 대한 테스트](#21-함수-내부에서-새로운-코루틴을-실행하는-객체에-대한-테스트)
  * [2.2. `backgroundScope` 를 사용해 테스트](#22-backgroundscope-를-사용해-테스트)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 코루틴 단위 테스트 만들어보기

여기서는 SNS 에서 기업 계정과 개인 계정을 동시에 검색하여 팔로워 목록을 가져오는 _FollowerSearcher_ 클래스를 예시로 단위 테스트를 작성하는 과정에 대해 살펴본다.

먼저 테스트할 대상 클래스와 관련 인터페이스들을 보자.

Follower 인터페이스 및 구현 클래스
```kotlin
// chap12/code06/Follower.kt
package chap12.code06

sealed interface Follower {
    val id: String
    val name: String
}

// 기업용 계정 클래스
data class OfficialFollower(
    override val id: String,
    override val name: String,
) : Follower

// 개인용 계정 클래스
data class PersonFollower(
    override val id: String,
    override val name: String,
) : Follower
```

각 계정 유형을 조회하는 Repository 인터페이스
```kotlin
// chap12/code06/OfficialAccountRepository.kt
package chap12.code06

interface OfficialAccountRepository {
    suspend fun searchByName(name: String): List<OfficialFollower>
}

// chap12/code06/PersonAccountRepository.kt
interface PersonAccountRepository {
    suspend fun searchByName(name: String): List<PersonFollower>
}
```

FollowerSearcher 클래스
```kotlin
// chap12/code06/FollowerSearcher.kt
package chap12.code06

import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

class FollowerSearcher(
    private val officialAccountRepository: OfficialAccountRepository,
    private val personAccountRepository: PersonAccountRepository,
) {
    suspend fun searchByName(name: String): List<Follower> = coroutineScope {
        val officialAccountsDeferred: Deferred<List<OfficialFollower>> = async {
            officialAccountRepository.searchByName(name)
        }
        val personAccountsDeferred: Deferred<List<PersonFollower>> = async {
            personAccountRepository.searchByName(name)
        }

        return@coroutineScope officialAccountsDeferred.await() + personAccountsDeferred.await()
    }
}
```

---

## 1.1. _FollowerSearcher_ 클래스 테스트

_FollowerSearcher_ 클래스는 OfficialAccountRepository, PersonAccountRepository 에 대한 외부 의존성을 가지고 있다.  
**단위 테스트의 핵심은 테스트 대상을 외부 환경으로부터 '고립'**시키는 것이므로, 실제 Repository 구현체 대신 [Test Double](https://assu10.github.io/dev/2025/08/10/coroutine-test-1/#14-%ED%85%8C%EC%8A%A4%ED%8A%B8-%EB%8D%94%EB%B8%94%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%B4-%EC%9D%98%EC%A1%B4%EC%84%B1-%EC%9E%88%EB%8A%94-%EA%B0%9D%EC%B2%B4-%ED%85%8C%EC%8A%A4%ED%8A%B8)을 사용해야 한다.

여기서는 실제 네트워크 통신이나 DB 접근없이 정해진 데이터를 반환하고, delay() 를 통해 약간의 지연을 흉내내는 [Stub](https://assu10.github.io/dev/2023/04/30/nest-test/#31-test-double) 객체를 만들어 사용한다.

테스트를 위한 Stub Repository 구현
```kotlin
// chap12/code06/StubOfficialAccountRepository.kt
package chap12.code06

import kotlinx.coroutines.delay

class StubOfficialAccountRepository(
    private val users: List<OfficialAccount>,
) : OfficialAccountRepository {
    override suspend fun searchByName(name: String): List<OfficialAccount> {
        delay(1000L)
        return users.filter {
            it.name.contains(name)
        }
    }
}

// chap12/code06/StubPersonAccountRepository.kt
import kotlinx.coroutines.delay

class StubPersonAccountRepository(
    private val users: List<PersonAccount>,
) : PersonAccountRepository {
    override suspend fun searchByName(name: String): List<PersonAccount> {
        delay(1000L)
        return users.filter {
            it.name.contains(name)
        }
    }
}
```

---

### 1.1.1. `@BeforeEach` 로 테스트 실행 환경 설정

JUnit5의`@BeforeEach` 애너테이션은 각 테스트 메서드가 실행되기 전에 공통된 초기화 작업을 수행한다.  
여기서는 FollowerSearcher 인스턴스를 생성하고 미리 준비된 Stub Repository 들을 주입해준다.  
이렇게 하면 각 테스트마다 중복된 초기화 코드를 작성할 필요가 없다.

```kotlin
// chap12/code06/FollowerSearcherTest.kt
package chap12.code06

import org.junit.jupiter.api.BeforeEach

class FollowerSearcherTest {
    private lateinit var followerSearcher: FollowerSearcher

    @BeforeEach
    fun setUp() {
        followerSearcher = FollowerSearcher(
            officialAccountRepository = stubOfficialAccountRepository,
            personAccountRepository = stubPersonAccountRepository,
        )
    }

    companion object {
        // 테스트용 데이터
        private val companyA = OfficialAccount(id = "1", name = "CompanyA")
        private val companyB = OfficialAccount(id = "2", name = "CompanyB")
        private val companyC = OfficialAccount(id = "3", name = "CompanyC")

        private val personA = PersonAccount(id = "10", name = "PersonA")
        private val personB = PersonAccount(id = "11", name = "PersonB")
        private val personC = PersonAccount(id = "12", name = "PersonC")
        
        // 테스트 데이터로 Stub 객체 생성
        private val stubOfficialAccountRepository = StubOfficialAccountRepository(
            users = listOf(companyA, companyB, companyC),
        )

        private val stubPersonAccountRepository = StubPersonAccountRepository(
            users = listOf(personA, personB, personC),
        )
    }
}
```

---

### 1.1.2. 테스트 작성

FollowerSearcher 의 searchByName() 은 suspend 함수이므로 일반적인 방법으로는 테스트할 수 없다. 이 때 `runTest()` 를 사용하면 된다.

`runTest()` 는 시간을 마음대로 제어할 수 있다. 즉, Stub에 설정해 둔 delay() 같은 지연 코드를 실제로 기다리는 것이 아니라, 즉시 시간을 점프시켜 테스트를 순식간에 완료한다.

```kotlin
@Test
fun `공식 계정과 개인 계정이 합쳐져서 반환되는가?`() = runTest {
    // Given
    val searchName = "A"
    val expectedResults = listOf(companyA, personA)

    // When
    val results = followerSearcher.searchByName(searchName)

    // Then
    assertEquals(expectedResults, results)
}
```

위 테스트는 Stub 에 포함된 delay() 를 합치면 2초가 걸려야 하지만, `runTest()` 의 가상 시간 제어 덕분에 43ms 만에 완료되었다.

```kotlin
@Test
fun `일치하지 않는 이름을 검색했을 때 빈 리스트가 반환되는가?`() = runTest {
    // Given
    val searchName = "F"
    val expectedResults = emptyList<Follower>()

    // When
    val results = followerSearcher.searchByName(searchName)

    // Then
    assertEquals(expectedResults, results)
}
```

---

# 2. 코루틴 테스트 심화

위에서는 suspend 함수를 `runTest()` 로 감싸서 테스트하는, 비교적 간단한 케이스를 다루었다.  
하지만 실무에서는 suspend 함수가 아닌 일반 함수 내부에서 새로운 코루틴을 실행하는 경우도 흔하게 마주친다.  
여기서는 이런 구조를 테스트하는 방법에 대해 알아본다.

---

## 2.1. 함수 내부에서 새로운 코루틴을 실행하는 객체에 대한 테스트

문자열 상태를 비동기적으로 업데이트하는 StringStateHolder 클래스를 예로 들어본다.
```kotlin
// chap12/code07/StringStateHolder.kt
package chap12.code07

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class StringStateHolder {
    // 클래스 내부에 자체 CoroutineScope 를 가짐
    private val coroutineScope: CoroutineScope = CoroutineScope(Dispatchers.IO)

    var stringState = ""
        private set

    // suspend 함수가 아님!
    fun updateStringWithDelay(string: String) {
        coroutineScope.launch {
            delay(1000L)
            stringState = string
        }
    }
}
```

updateStringWithDelay() 메서드는 suspend 키워드가 없는 일반 함수이지만, 내부적으로 coroutineScope.launch 를 통해 새로운 코루틴을 생성한다.

이제 위 대상 클래스에 대해 `runTest()` 를 사용해 테스트를 작성해보자.
```kotlin
// chap12/code07/StringStateHolderFailTest.kt
package chap12.code07

import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class StringStateHolderFailTest {
    @Test
    fun `updateStringWithDelay(ABC) 가 호출되면 문자열이 ABC 로 변경된다`() = runTest {
        // Given
        val stringStateHolder = StringStateHolder()

        // When
        stringStateHolder.updateStringWithDelay("ABC")

        // Then
        advanceUntilIdle()
        assertEquals("ABC", stringStateHolder.stringState)
    }
}
```

```shell
org.opentest4j.AssertionFailedError: expected: <ABC> but was: <>
```

분명 `advanceUntilIdle()`을 호출해서 가상 시간을 끝까지 진행시켰는데도 stringState 는 여전히 초기값인 빈 문자열이다.

**원인은 바로 StringStateHolder 가 내부적으로 생성하는 CoroutineScope** 에 있다.
- **독립적인 Scope**
    - CoroutineScope(Dispatchers.IO) 는 `runTest()` 가 생성하는 테스트용 코루틴 환경과는 아무런 관계가 없는, 완전히 **독립적인 최상위 스코프**를 생성하기 때문에 둘은 구조화된 동시성으로 묶여있지 않음
- **실제 시간 사용**
    - 이 스코프는 Dispatchers.IO 를 사용하므로, 코루틴을 **실제 시간** 위에서 동작하는 별도의 스레드에서 실행함
- **테스트 스케줄러의 통제 불능**
    - `runTest()` 와 그 내부의 `advanceUntilIdle()` 은 테스트용 스케줄러, 즉 **가상 시간**을 제어함
    - StringStateHolder 내부의 코루틴은 실제 시간 위에서 돌고 있으므로, 가상 시간을 아무리 진행시켜도 아무런 영향을 주지 못함

즉, assertEquals() 단언문이 실행되는 시점에 StringStateHolder 내부 코루틴의 delay(1000L)이 실제 시간으로 1초를 기다리는 중이므로, stringState 값은 아직
변경되지 않은 것이다.

---

이 문제를 해결하려면 테스트 코드에서 StringStateHolder 내부 코루틴의 실행을 통제할 수 있어야 한다.  
즉, 내부 CoroutineScope 가 테스트용 스케줄러를 사용하도록 만들어야 한다.  
가장 깔끔하고 일반적인 방법은 의존성 주입 패턴을 활용하는 것이다.

StringStateHolder 가 사용할 CoroutineDispatcher 를 외부에서 주입받도록 클래스 구조를 변경해보자.

변경된 StringStateHolder 클래스
```kotlin
// chap12/code07/StringStateHolder.kt
package chap12.code07

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class StringStateHolder(
    // 생성자에서 Dispatcher 를 주입받음, 기본값은 Dispatchers.IO
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    // 주입받은 dispatcher 사용
    private val coroutineScope: CoroutineScope = CoroutineScope(dispatcher)

    var stringState = ""
        private set

    fun updateStringWithDelay(string: String) {
        coroutineScope.launch {
            delay(1000)
            stringState = string
        }
    }
}
```

이렇게 변경하면 프로덕션 코드에서도 기본값인 Dispatchers.IO 를 그대로 사용하므로 아무런 영향이 없고, 테스트 코드에서도 우리가 원하는 테스트용 Dispatcher 를
주입할 수 있게 된다.

성공하는 테스트 코드
```kotlin
package chap12.code07

import kotlinx.coroutines.test.StandardTestDispatcher
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class StringStateHolderSuccess() {
    @Test
    fun `updateStringWithDelay(ABC) 가 호출되면 문자열이 ABC 로 변경된다`() {
        // Given
        // 테스트용 Dispatcher 생성
        val testDispatcher = StandardTestDispatcher()
        // 생성한 Dispatcher 를 주입하여 객체 생성
        val stringStateHolder = StringStateHolder(dispatcher = testDispatcher)

        // When
        stringStateHolder.updateStringWithDelay("ABC")

        // Then
        // testDispatcher 의 스케줄러를 직접 제어하여 가상 시간 진행
        testDispatcher.scheduler.advanceUntilIdle()
        assertEquals("ABC", stringStateHolder.stringState)
    }
}
```

핵심적인 변화는 아래와 같다.
- 더 이상 `runTest()` 로 테스트 함수를 감싸지 않는다. 테스트 대상 함수가 suspend 가 아니기 때문이다.
- `StandardTestDispatcher()` 를 직접 생성하고, StringStateHolder 에 주입했다.
- `runTest()` 의 `advanceUntilIdle()` 대신, 직접 만든 testDispatcher.scheduler.advanceUntilIdle() 를 호출하여 testDispatcher 에 예약된 작업(1초 delay 와 상태 변경)을 즉시 실행했다.

이처럼 클래스 내부에서 자체적으로 CoroutineScope 를 관리하는 경우는 생각보다 많다.  
이런 객체들도 모두 안정적으로 테스트가 가능해야 하므로, Dispatcher 를 주입받도록 설계하는 방법을 알아두는 것이 중요하다.

---

|                    | 실패한 테스트(`runTest()` 사용)                           | 성공한 테스트(`runTest()` 미사용)              |
|:------------------:|:--------------------------------------------------|:--------------------------------------|
|      시간 제어 주체      | `runTest()` 환경(암시적)                               | 개발자(명시적)                              |
|    테스트 대상과의 관계     | `runTest()` 의 시간과 테스트 대상의 시간이 **분리**됨(통제 불가능)     | 테스트용 Dispatcher를 주입하여 **시간을 완전히 통제**함 |
| advanceUntilIdle() | `runTest()` 스코프에 속한 함수                            | testDispatcher.scheduler 에 속한 함수      |
|         결론         | suspend 함수가 아닌, **내부에서 독자적인 코루틴을 만드는 객체**를 테스트하기에 부적함 | 이런 객체를 테스트하기 위한 **올바르고 표준**적인 방법          |

실패한 테스트에서 `runTest()` 를 사용한 이유는 잘못된 가정 때문이다.

_"코루틴을 테스트해야 하니 당연히 `runTest()` 블록으로 감싸야겠지?  
그리고 `runTest()` 가 제공하는 `advanceUntilIdle()` 을 호출하면 delay() 를 포함한 모든 비동기 코드가 완료될거야."_  

이것은 suspend 함수를 테스트할 때는 맞는 접근법이지만, 이번의 실패한 케이스에서는 틀린 가정이다.

`runTest()` 는 자신만의 가상 시간용 시계(TestCoroutineScheduler)를 가진 테스트 환경을 만들고, 그 안에서 `advanceUntilIdle()` 을 호출하면 `runTest()` 의
시계 위에서 동작하는 코루틴들의 시간을 빠르게 감아주는 역할을 한다.

하지만 테스트 대상인 StringStateHolder 는 CoroutineScope(Dispatchers.IO) 를 사용해서 `runTest()` 의 시계가 아닌, 실제 시간의 시계를 사용하는 별도의 코루틴을 만들었다.  
즉, 2개의 시계가 따로 돌고 있는 상황이다.

따라서 suspend 함수가 아닌 메서드를 테스트할 때는, 그 메서드 내부의 비동기 로직이 어떤 Dispatcher(어떤 시계)를 사용하는지 파악하고, 그 Dispatcher 를
테스트 코드가 제어할 수 있도록 **의존성을 주입**하는 것이 핵심이다.

---

## 2.2. `backgroundScope` 를 사용해 테스트

`runTest()` 함수는 블록 내에서 실행된 모든 자식 코루틴이 완료될 때까지 테스트를 종료하지 않고 기다린다.

```kotlin
package chap12.code08

import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test

class BackgroundScopeTest {
    @Test
    fun `메인 스레드만 사용하는 runTest`() = runTest {
        println(Thread.currentThread())
        println(Thread.currentThread().name)
    }
}
```

```shell
Thread[Test worker @kotlinx.coroutines.test runner#2,5,main]
Test worker @kotlinx.coroutines.test runner#2
```

이 '모든 자식이 끝날 때까지 기다린다'는 특징 때문에, 만약 자식 코루틴이 무한히 실행되는 작업을 포함하고 있다면 테스트는 영원히 끝나지 않게 된다.

```kotlin
@Test
fun `끝나지 않아서 실패하는 테스트`() = runTest {
    var result = 0

    launch {
        while(true) {
            delay(1000L)
            result++
        }
    }

    advanceTimeBy(1500L)
    assertEquals(1, result)
    advanceTimeBy(1000L)
    assertEquals(2, result)
}
```

```shell
// 1분 대기 후, 활성 상태인 자식 job 이 있다는 오류 메시지
After waiting for 1m, there were active child jobs: ["coroutine#3":StandaloneCoroutine{Active}@2a0b547f]. Use `TestScope.backgroundScope` to launch the coroutines that need to be cancelled when the test body finishes
kotlinx.coroutines.test.UncompletedCoroutinesError: After waiting for 1m, there were active child jobs: ["coroutine#3":StandaloneCoroutine{Active}@2a0b547f]. Use `TestScope.backgroundScope` to launch the coroutines that need to be cancelled when the test body finishes
```

오류 메시지가 친절하게 원인과 해결책(`Use `TestScope.backgroundScope`)을 알려주고 있다.

이 현상이 발생하는 이유는 아래와 같다.
- `runTest()`의 메인 코드 블록은 마지막 줄인 assertEquals(2, result) 까지 성공적으로 실행함
- 하지만 launch 로 생성된 자식 코루틴의 while(true) 루프가 계속해서 돌고 있기 때문에, `runTest()` 는 '아직 자식 작업이 안 끝났네?' 라고 판단하여 테스트를 종료하지 못하고 무한정 기다리게 됨

실제로는 `runTest()` 가 이런 상황을 방지하기 위해 일정 시간(기본 1분)이 지나면 `UncompletedCoroutinesError` 예외를 발생시켜 테스트를 강제로 실패시킨다.

---

이러한 **테스트 실행 중에는 살아있어야 하지만, 테스트 본문이 끝나면 자동으로 정리되어야 하는** 코루틴을 다루기 위해 `backgroundScope` 가 존재한다.

`runTest()` 람다의 수신 객체인 `TestScope` 가 제공하는 `backgroundScope` 는 `runTest()`의 메인 코드 블록 실행이 모두 완료되면 **자동으로 취소(cancel)**되는 특별한 스코프이다.

```kotlin
@Test
fun `backgroundScope를 사용하는 테스트`() = runTest {
    var result = 0

    // backgroundScope.launch로 무한 루프 코루틴 실행
    backgroundScope.launch {
        while(true) {
            delay(1000L)
            result++
        }
    }

    advanceTimeBy(1500L)
    assertEquals(1, result)
    advanceTimeBy(1000L)
    assertEquals(2, result) // <-- 테스트 본문의 마지막 코드
}
```

이제 테스트는 성공적으로 통과한다.  
실행 흐름은 아래와 같다.
- `backgroundScope.launch`로 무한 루프를 가진 코루틴이 백그라운드에서 실행 시작
- `advanceTimeBy()` 를 통해 가상 시간이 흐르고, result 값이 정상적으로 증가하여 두 테스트가 모두 통과함
- 테스트 본문의 마지막 라인인 assertEquals(2, result) 실행이 끝남
- `runTest()`는 '테스트 본문이 모두 끝났으니, `backgroundScope`를 취소해야겠다!' 라고 판단하고 즉시 `backgroundScope` 를 취소시킴
- `backgroundScope`가 취소되면서 그 안에서 돌던 while(true) 루프도 함께 종료됨
- 모든 작업이 정상적으로 정리되었으므로, 테스트는 성공적으로 완료됨

위 코드는 무한히 실행되는 launch 코루틴이 `backgroundScope` 를 사용해 실행되며, 이 `backgroundScope` 는 runTest 코루틴의 마지막 코드인 
assertEquals(2, result) 가 실행되면 취소된다.

---

# 정리하며..

- **의존성 주입을 통한 제어권 확보**
  - 클래스 내부에서 자체적으로 코루틴을 생성하고 실행한다면, 반드시 `CoroutineDispatcher` 를 외부에서 주입할 수 있도록 설계해야 한다.
  - 이는 테스트 코드에 비동기 작업의 '시간'을 제어할 수 있게 해준다.
- **`backgroundScope` 를 활용한 뒷정리**
  - 테스트 도중 계속 실행되어야 하지만, 테스트가 끝나면 사라져야 하는 무한한 작업들은 `backgroundScope` 를 사용한다.
  - 이를 통해 테스트가 영원히 끝나지 않는 상황을 방지하고, 안정적인 테스트 환경을 구축할 수 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)