---
layout: post
title:  "Coroutine - 코루틴 단위 테스트(1): 코루틴 테스트 라이브러리 runTest()"
date: 2025-08-10
categories: dev
tags: kotlin coroutine unittest testing kotlinx-coroutines-test runTest TestScope TestDispatcher virtual-time runBlocking TestDouble Stub Fake JUnit5 concurrency parallelism delay suspend
---

이 포스트에서는 코틀린 코루틴의 안전성과 신뢰성을 보장하는 핵심적인 방법인 단위 테스트(Unit Test) 에 대해 알아본다.

비동기적으로 동작하는 코루틴 코드는 테스트하기 까다로울 수 있지만, 올바른 도구와 방법을 사용한다면 견고한 테스트를 작성할 수 있다.

- **코틀린 Unit Test** 기초
- **테스트 더블(Test Double)**을 활용한 의존성 주입 객체 테스트
- `kotlinx-coroutine-test` 라이브러리의 핵심 기능과 사용법
- 실제 코루틴 코드를 테스트하는 실전 예시

> 소스는 [github](https://github.com/assu10/coroutine/tree/feature/chap12) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 단위 테스트 기초](#1-단위-테스트-기초)
  * [1.1. 테스트 환경 설정](#11-테스트-환경-설정)
  * [1.2. 간단한 테스트 만들고 실행](#12-간단한-테스트-만들고-실행)
  * [1.3. `@BeforeEach` 애너테이션을 사용한 테스트 환경 설정](#13-beforeeach-애너테이션을-사용한-테스트-환경-설정)
  * [1.4. 테스트 더블을 사용해 의존성 있는 객체 테스트](#14-테스트-더블을-사용해-의존성-있는-객체-테스트)
    * [1.4.1. 테스트 더블을(Test Double) 통한 객체 모방](#141-테스트-더블을test-double-통한-객체-모방)
      * [1.4.1.1. Stub](#1411-stub)
      * [1.4.1.2. Fake](#1412-fake)
    * [1.4.2. 테스트 더블(Test Double)을 사용한 테스트](#142-테스트-더블test-double을-사용한-테스트)
* [2. 코루틴 단위 테스트](#2-코루틴-단위-테스트)
  * [2.1. runBlocking 을 사용한 테스트의 한계](#21-runblocking-을-사용한-테스트의-한계)
* [3. 코루틴 테스트 라이브러리](#3-코루틴-테스트-라이브러리)
  * [3.1. `TestCoroutineScheduler` 사용해 가상 시간에서 테스트](#31-testcoroutinescheduler-사용해-가상-시간에서-테스트)
    * [3.1.1. `advanceTimeBy()` 로 가상 시간 흐르게 하기](#311-advancetimeby-로-가상-시간-흐르게-하기)
    * [3.1.2. `TestCoroutineScheduler` 와 `StandardTestDispatcher()` 로 가상 시간 위에서 테스트 진행](#312-testcoroutinescheduler-와-standardtestdispatcher-로-가상-시간-위에서-테스트-진행)
    * [3.1.3. `advanceUntilIdle()` 로 모든 코루틴 실행](#313-advanceuntilidle-로-모든-코루틴-실행)
  * [3.2. `TestCoroutineScheduler` 를 포함하는 `StandardTestDispatcher()`](#32-testcoroutinescheduler-를-포함하는-standardtestdispatcher)
  * [3.3. `TestScope()` 를 사용해 가상 시간에서 테스트](#33-testscope-를-사용해-가상-시간에서-테스트)
  * [3.4. `runTest()` 를 사용해 테스트](#34-runtest-를-사용해-테스트)
    * [3.4.1. `runTest()` 함수의 람다식에서 `TestScope` 사용](#341-runtest-함수의-람다식에서-testscope-사용)
      * [3.4.1.1. `launch()`와 함께 사용할 때: `advanceUntilIdle()` 이 필요한 이유](#3411-launch와-함께-사용할-때-advanceuntilidle-이-필요한-이유)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 단위 테스트 기초

여기서는 코루틴 테스트에 중점을 두므로, 단위 테스트의 모든 것을 다루기 보다는 코루틴 테스트에 필요한 최소한의 내용에 집중한다.
따라서 단위 테스트 시 일반적으로 사용되는 Mokito, MockK 같은 라이브러리들은 생략하고 테스트를 진행하는데 필수적인 JUnit5 만을 사용한다.

단위(Unit) 이란 명확하게 정의된 역할을 수행하는 코드의 집합이다. 특정 동작을 실행하는 개별 함수, 클래스, 모듈 모두 하나의 Unit 이 될 수 있다.

단위 테스트는 바로 이러한 Unit 이 예상대로 정확하게 동작하는지 확인하기 위해 자동화된 테스트를 작성하고 실행하는 프로세스이다.

코틀린은 [객체 지향 프로그래밍](https://assu10.github.io/dev/2024/02/04/kotlin-basic/#113-%ED%95%A8%EC%88%98%ED%98%95-%ED%94%84%EB%A1%9C%EA%B7%B8%EB%9E%98%EB%B0%8D-vs-%EA%B0%9D%EC%B2%B4-%EC%A7%80%ED%96%A5-%ED%94%84%EB%A1%9C%EA%B7%B8%EB%9E%98%EB%B0%8D) 언어이다.  
객체 지향의 핵심은 '책임'을 객체에 할당하고, 객체 간의 유연한 관계를 구축하는 것이다. 즉, 특정 기능을 담는 책임의 주체가 바로 객체(Object)이다.  
따라서 코틀린과 같은 객체 지향 언어에서 단위 테스트의 대상은 주로 객체가 된다.

테스트는 일반적으로 아래와 같은 과정을 통해 진행된다.
- 테스트 대상 객체의 함수 호출
- 함수가 호출된 후, **객체가 예상한 대로 동작하는지 확인**

'예상한 대로 동작하는지'를 확인하는 방법은 다양하다.
- 함수가 **올바른 결과값을 반환**하는지 확인
- 객체가 가진 **상태가 의도대로 변경**되는지 확인
- 해당 객체가 의존하는 **다른 객체와 올바르게 상호작용**하는지 확인

이러한 검증 과정을 통해 우리는 코드의 각 단위가 견고하고 신뢰할 수 있음을 보장할 수 있다.

---

## 1.1. 테스트 환경 설정

Gradle 을 사용하는 코틀린 프로젝트에서 `build.gradle.kts` 파일을 아래와 같이 수정한다.

```kotlin
dependencies {
    // 코루틴 라이브러리
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.1")
    testImplementation(platform("org.junit:junit-bom:5.10.2"))
    // JUnit5 테스트 API(테스트 코드 작성용)
    testImplementation("org.junit.jupiter:junit-jupiter-api")
    // JUnit5 테스트 엔진(테스트 실행 시 필요)
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine")
    // 코루틴 테스트 라이브러리
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
}

// JUnit5 를 테스트 프레임워크로 사용하기 위한 설정
tasks.test {
    useJUnitPlatform()
}
```

- **`testImplementation()`**
  - **테스트 코드를 컴파일하고 실행**하는데 사용하는 의존성을 설정
  - JUit 의 `@Test` 애너테이션과 같은 API 들이 여기에 해당함
- **`testRuntimeOnly()`**
  - 컴파일할 때는 필요 없지만, **테스트를 실행하는 시점(Runtime)**에 필요한 의존성 설정
  - JUnit 테스트를 실제로 구동하는 테스트 엔진이 대표적인 예

이렇게 설정된 의존성들은 테스트 소스 코드 경로(src/test)에서만 유효하다. 따라서 앱의 프로덕션 빌드에는 포함되지 않아 최종 결과물(APK, JAR 등)의 크기가 
불필요하게 커지는 것을 방지할 수 있다.

tasks.test 블록의 `useJUnitPlatform()` 설정은 Gradle 이 테스트를 실행할 때 **JUnit 플랫폼을 사용하도록 지정**한다.

---

## 1.2. 간단한 테스트 만들고 실행

```kotlin
package chap12

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class AddUseCaseTest {
    @Test
    fun `1 더하기 2는 3이다`() {
        val addUseCase: AddUseCase = AddUseCase()
        val result = addUseCase.add(1, 2)
        assertEquals(result, 3)
    }
}
```

---

## 1.3. `@BeforeEach` 애너테이션을 사용한 테스트 환경 설정

```kotlin
package chap12

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class AddUseCaseTestBeforeEach {
    @Test
    fun `1 더하기 2는 3이다`() {
        val addUseCase: AddUseCase = AddUseCase()
        val result = addUseCase.add(1, 2)
        assertEquals(result, 3)
    }

    @Test
    fun `-1 더하기 2는 1이다`() {
        val addUseCase: AddUseCase = AddUseCase()
        val result = addUseCase.add(-1, 2)
        assertEquals(result, 1)
    }
}
```

위 코드에서 AddUseCase 클래스를 인스턴스화하는 코드가 똑같이 반복된다.
이 때 `@BeforeEach` 함수를 만들면 해당 함수는 모든 테스트 실행 전에 공통으로 실행된다.

```kotlin
package chap12

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class AddUseCaseTestBeforeEach {
    lateinit var addUseCase: AddUseCase

    @BeforeEach
    fun setUp() {
        addUseCase = AddUseCase()
    }

    @Test
    fun `1 더하기 2는 3이다`() {
        val result = addUseCase.add(1, 2)
        assertEquals(result, 3)
    }

    @Test
    fun `-1 더하기 2는 1이다`() {
        val result = addUseCase.add(-1, 2)
        assertEquals(result, 1)
    }
}
```

---

## 1.4. 테스트 더블을 사용해 의존성 있는 객체 테스트

위에선 독립적인 객체를 테스트했지만, 실제 애플리케이션의 객체들 대부분은 다른 객체에 **의존성(Dependency)**를 가진다.

여기서는 다른 객체와 의존성이 있는 객체를 어떻게 효과적으로 테스트할 수 있는지 알아본다.

**테스트 대상: `UserProfileFetcher`**

`UserProfileFetcher` 클래스는 2개의 다른 Repository 에 의존하여 사용자 프로필 정보를 가져오는 역할을 한다.
- `UserNameRepository` 에서 유저 이름 조회
- `UserPhoneNumberRepository` 에서 유저 전화번호 조회
- 두 데이터를 조합하여 `UserProfile` 객체 반환

`UserProfileFetcher.kt`

```kotlin
package chap12

class UserProfileFetcher(
    private val userNameRepository: UserNameRepository,
    private val userPhoneNumberRepository: UserPhoneNumberRepository,
) {
    fun getUserProfileById(id: String): UserProfile {
        // 유저 이름 조회
        val userName = userNameRepository.getNameByUserId(id)

        // 유저 전화번호 조회
        val userPhoneNumber = userPhoneNumberRepository.getPhoneNumberById(id)

        return UserProfile(
            id = id,
            name = userName,
            phoneNumber = userPhoneNumber,
        )
    }
}
```

UserNameRepository.kt (**Interface**)
```kotlin
package chap12

interface UserNameRepository {
    fun saveUserName(id: String, name: String)
    fun getNameByUserId(id: String): String
}
```

UserPhoneNumberRepository.kt (**Interface**)
```kotlin
package chap12

interface UserPhoneNumberRepository {
    fun saveUserPhoneNumber(id: String, phoneNumber: String)
    fun getPhoneNumberById(id: String): String
}
```

UserProfile.kt (**Data Class**)
```kotlin
package chap12

data class UserProfile(
    val id: String,
    val name: String,
    val phoneNumber: String,
)
```

여기서 한 가지 문제가 있다. `UserProfileFetcher` 를 테스트하고 싶은데, 2개의 Repository 의 실제 구현체가 없다. 설령 실제 구현체(예: DB 에 접근하는 코드)가 
있다 하더라도, `UserProfileFetcher` 를 테스트할 대 사용하면 아래와 같은 문제가 생긴다.

**"테스트는 다른 구현체에 영향을 받지 않고 독립적으로 수행되어야 한다."**

만일 Repository 의 DB 로직에 버그가 있다면, `UserProfileFetcher` 의 로직이 정상임에도 불구하고 테스트는 실패하게 된다. 이것은 우리가 원하는 순수한 **'단위(Unit)'** 테스트가 아니다.

이럴 때 바로 테스트 더블(Test Double) 을 사용하면 된다.

---

### 1.4.1. 테스트 더블을(Test Double) 통한 객체 모방

테스트 더블(Test Double)이란 실제 객체를 대신하여 테스트를 위해 만들어진 대체 객체를 의미한다. 실제 객체의 행동을 모방하여, 테스트 대상 객체가 필요로 하는 
의존성을 제공해준다.

테스트 대상(`UserProfileFetcher`)이 의존하는 객체(`Repository`)를 테스트 더블로 대체하면, 의존 객체의 구체적인 구현에 상관없이 테스트 대상의 동작만을 
고립시켜 검증할 수 있다.

테스트 더블에는 대표적으로 [Stub, Fake, Mock, Dummy, Spy](https://assu10.github.io/dev/2023/04/30/nest-test/#31-test-double) 등이 있다.
여기서는 **Stub**과 **Fake**만 다룬다.

---

#### 1.4.1.1. Stub

Stub 은 미리 정해진(하드코딩) 데이터를 반환하도록 만들어진 모방 객체이다. 테스트 중에 호출되었을 때, 미리 준비된 값을 반환하는 역할만 수행한다.

아래는 `UserNameRepository` 에 대한 Stub 이다.

StubUserNameRepository.kt (**유연하지 않은 구조**)
```kotlin
package chap12

class StubUserNameRepository: UserNameRepository {
    private val userNameMap = mapOf<String, String>(
        "0x1111" to "ASSU",
        "0x2222" to "Jaehun",
    )

    override fun saveUserName(id: String, name: String) {
        // Stub 은 상태를 변경하거나 로직을 갖지 않으므로 구현하지 않는다.
    }

    override fun getNameByUserId(id: String): String {
        return userNameMap[id] ?: "" // 미리 정의된 데이터 반환
    }
}
```

이 Stub 은 getNameByUserId() 가 호출되면 userNameMap 에 미리 정의된 값을 반환한다.  
반환값이 없는 saveUserName() 은 아무 동작도 하지 않도록 비워둔다.

하지만 이 Stub 은 userNameMap 의 데이터가 고정되어 있어 다양한 테스트 케이스에 대응하기 어렵다. 이 문제를 해결하려면 **의존성 주입**을 활용하면 된다.

StubUserNameRepository.kt (**유연한 구조**)
```kotlin
// 생성자를 통해 데이터를 주입받아 유연성을 높인 구조
class StubUserNameRepository(
    private val userNameMap: Map<String, String> // 데이터 외부 주입
) : UserNameRepository {
    override fun saveUserName(id: String, name: String) {
        // 구현하지 않는다.
    }

    override fun getNameByUserId(id: String): String {
        return userNameMap[id] ?: ""
    }
}
```

이제 테스트 코드에서 `StubUserNameRepository` 를 생성할 때, 원하는 데이터가 담긴 Map 을 직접 전달하여 훨씬 유연하게 Stub 을 사용할 수 있게 되었다.

---

#### 1.4.1.2. Fake

Fake 는 실제 객체처럼 동작하도록 좀 더 복잡한 로직을 구현한 모방 객체이다. 실제 구현(DB, 네트워크)를 더 가벼운 방식(인메모리)으로 대체하여 동작을 시뮬레이션 한다.

`UserPhoneNumberRepository` 의 실제 구현체가 로컬 DB 를 사용한다고 가정하고, 이를 흉내내는 Fake 객체를 만들면 아래와 같ㄴ다.

FakeUserPhoneNumberRepository.kt
```kotlin
package chap12

class FakeUserPhoneNumberRepository: UserPhoneNumberRepository {
    private val userPhoneNumberMap = mutableMapOf<String, String>()

    override fun saveUserPhoneNumber(id: String, phoneNumber: String) {
        // 실제 DB 대신 인메모리 Map 에 데이터 저장
        userPhoneNumberMap[id] = phoneNumber
    }

    override fun getPhoneNumberById(id: String): String {
        // 인메모리 Map 에서 데이터 조회
        return userPhoneNumberMap[id] ?: ""
    }
}
```

이 `FakeUserPhoneNumberRepository` 는 실제 DB 대신 MutableMap 을 사용하여 데이터를 저장하고 조회한다.  
**Stub 과 달리 실제 객체처럼 상태가 변하고 동작**하는 것을 볼 수 있다.

---

`UserProfileFetcher` 가 의존하는 두 Repository 에 대한 테스트 더블(`StubUserNameRepository`, `FakeUserPhoneNumberRepository`) 이 
모두 준비되었다.  
이제 이 둘을 사용하여 `UserProfileFetcher` 를 완벽하게 고립시킨 상태에서 테스트를 진행할 수 있다.

이 테스트 더블을 실제 테스트 코드에서 어떻게 활용하는지 알아보자.

---

### 1.4.2. 테스트 더블(Test Double)을 사용한 테스트

이제 위에서 만든 테스트 더블을 `UserProfileFetcher` 에 주입하여, 오직 `UserProfileFetcher` 의 로직만을 고립시켜 테스트해본다.

테스트 코드는 Given-When-Then 구조로 작성하여 가독성을 높인다.
- Given: 테스트에 필요한 환경과 객체 설정
- When: 테스트하려는 실제 동작(함수 호출 등)을 수행
- Then: 실행 결과가 예상한 대로인지 확인

UserProfileFetcherTest.kt
```kotlin
package chap12

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class UserProfileFetcherTest {
    @Test
    fun `UserNameRepository 가 반환하는 이름이 ASSU1 이면, UserProfileFetcher 에서 UserProfile 을 가져왔을 때 이름이 ASSU1 이어야 한다`() {
        // Given
        val userProfileFetcher = UserProfileFetcher(
            // StubUserRepository에 테스트용 데이터를 주입
            userNameRepository = StubUserNameRepository(
                userNameMap = mapOf(
                    "0x1111" to "ASSU1",
                    "0x2222" to "ASSU2",
                ),
            ),
            userPhoneNumberRepository = FakeUserPhoneNumberRepository(),
        )

        // When
        val userProfile = userProfileFetcher.getUserProfileById("0x1111")

        // Then
        assertEquals("ASSU1", userProfile.name)
    }

    @Test
    fun `UserPhoneNumberRepository 에 휴대폰 번호가 저장되어 있으면, UserProfile 을 가져왔을 때 해당 휴대폰 번호가 반환되어야 한다`() {
        // Given
        val userProfileFetcher = UserProfileFetcher(
            userNameRepository = StubUserNameRepository(
                userNameMap = mapOf(
                    "0x1111" to "ASSU1",
                    "0x2222" to "ASSU2",
                ),
            ),
            // Fake 객체를 원하는 상태로 만듦
            userPhoneNumberRepository = FakeUserPhoneNumberRepository().apply {
                this.saveUserPhoneNumber("0x1111", "010-1111-2222")
            },
        )

        // When
        val userProfile = userProfileFetcher.getUserProfileById("0x1111")

        // Then
        assertEquals("010-1111-2222", userProfile.phoneNumber)
    }
}
```

두 번째 테스트에서는 [`apply()`](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#2-%EC%98%81%EC%97%AD-%ED%95%A8%EC%88%98-scope-function-let-run-with-apply-also) 를 이용해서 `FakeUserPhoneNumberRepository` 의 saveUserPhoneNumber() 를 먼저 호출하여 특정 데이터를 저장하는 **'상태 변화'**를 일으켰다. 
그 후 getUserProfileById() 를 호출했을 때, Fake 객체 내부 상태(userPhoneNumberMap)에 따라 올바른 전화번호를 반환하는지 검증하였다.  
이를 통해 `UserProfileFetcher` 가 의존 객체와 올바르게 상호작용하는지 확인할 수 있다.

하지만 매번 테스트를 위해 인터페이스의 모든 함수를 구현하는 테스트 더블 클래스를 만드는 것은 매우 비효율적이다.

이런 반복적이고 번거로운 작업을 해결하기 위해 **모킹(Mocking) 라이브러리**가 등장했다.  
코틀린에서는 **Mokito** 나 **MockK** 같은 라이브러리가 널리 사용되며, 단 몇 줄의 코드로 테스트 더블을 동적으로 생성해준다.

또한, 실제 단위 테스트는 단순히 반환값을 비교하는 것을 넘어 아래와 같은 다양한 측면을 검증하낟.
- 테스트 대상 객체의 **상태가 어떻게 변화**하는가?
- 테스트 대상 객체가 의존 객체의 함수를 **올바른 순서와 횟수로 호출**하는가?

---

# 2. 코루틴 단위 테스트

비동기적으로 동작하는 코루틴을 테스트할 때는 **시간**과 **스레드**라는 변수를 효과적으로 통제하는 것이 관건이다.

테스트 대상 객체

```kotlin
package chap12

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class RepeatAddUseCase {
    suspend fun add(repeatTime: Int): Int = withContext(Dispatchers.Default) {
        var result = 0
        repeat(times = repeatTime) {
            result++
        }
        return@withContext result
    }
}
```

add() 는 일시 중단 함수이다.  
내부적으로 [withContext(Dispatchers.Default)](https://assu10.github.io/dev/2024/11/10/coroutine-async-and-deferred/#4-withcontext) 를 사용하여 코루틴이 사용하는 스레드를 CPU 바운드 작업을 위한 백그라운드 스레드로 전환한 후 
코드를 실행한다. 그리고 매개변수로 입력된 숫자만큼 1씩 더한 값을 반환한다.

`@Test` 애너테이션이 붙은 일반 함수에서는 suspend 함수를 직접 호출할 수 없다. 일시 중단 함수는 다른 일시 중단 함수 또는 코루틴 내에서만 호출 가능하기 때문이다.

간단한 해결책은 바로 runBlocking 코루틴 빌더를 사용하는 것이다.  
runBlocking 은 새로운 코루틴을 생성하고, 그 코루틴이 완료될 때까지 **현재 스레드를 블로킹**한다.  
테스트 코드에서는 이 특성을 이용해 비동기 코드가 끝날 때까지 기다렸다가 결과를 검증할 수 있다.

```kotlin
package chap12

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class RepeatAddUseCaseTest {
    // 일시 중단 함수는 코루틴 내부에서 실행되어야 하므로 테스트 함수를 runBlocking 함수로 감쌈
    @Test
    fun `100번 더하면 100이 반환된다`() = runBlocking {
        // Given
        val repeatAddUseCase = RepeatAddUseCase()

        // When
        val result = repeatAddUseCase.add(100)

        // Then
        assertEquals(100, result)
    }
}
```

위 테스트는 성공적으로 통과한다. runBlocking 이 add() 함수가 결과를 반환할 때까지 기다려주기 때문이다.

**하지만 runBlocking 만으로 충분할까?**

위 코드처럼 빠르게 완료되는 단순한 일시 중단 함수는 runBlocking 만으로도 충분히 테스트할 수 있다.

하지만 만일 테스트하려는 코루틴이 오랜 시간 동안 실행된다면? 예를 들어, 10초의 딜레이가 포함된 함수라면?

runBlocking 을 사용한 테스트는 실제 시간만큼 고스란히 기다려야 한다. 테스트가 10초가 걸린다면, 수십 개의 테스트는 엄청난 시간을 낭비하게 된다.  
이것이 바로 runBlocking 을 사용한 테스트의 한계이다.

이제 runBlocking 을 사용해 오랜 시간이 걸리는 함수를 테스트할 때 어떤 구체적인 문제가 발생하는지, 그리고 어떻게 해결할 수 있는지 알아본다.

---

## 2.1. runBlocking 을 사용한 테스트의 한계

위의 예제는 매우 빠르게 실행되었지만, 실제 비동기 코드에는 네트워크 요청, DB 접근, 혹은 단순한 지연 등 시간이 소요되는 작업이 포함되는 경우가 많다.

delay() 를 포함하는 예시를 통해 runBlocking 의 한계를 살펴보자.

RepeatAddWithDelayUseCase.kt
```kotlin
package chap12

import kotlinx.coroutines.delay

class RepeatAddWithDelayUseCase {
    suspend fun add(repeatTime: Int): Int {
        var result = 0
        repeat(times = repeatTime) {
            delay(100L)
            result++
        }
        return result
    }
}
```

이전 예제와 거의 동일하지만, 반복문 내에 delay(100L) 이 추가되었다.

<br />

<details markdown="1">
<summary><strong>잠깐! 왜 `withContext()` 를 사용하지 않았을까? (CPU-bound vs I/O bound) (펼쳐보기)</strong></summary>

이전 `RepeatAddUseCase` 에서는 `withContext(Dispatchers.Default)` 를 사용했지만, 이번 `RepeatAddWithDelayUseCase` 에서는 사용하지 않았다.  
그 이유는 작업의 성격이 다르기 때문이다.

- **CPU-bound 작업**
  - 복잡한 연산처럼 **CPU 를 계속 사용**하는 작업
  - 이런 작업을 메인 스렏에서 수행하면 UI가 멈추는(ANR, Application Not Responding) 현상이 발생할 수 있으므로, `withContext()`를 통해 백그라운드 스레드로 작업을 전환해야 함
  - 예) 대규모 데이터 정렬, 이미지/영상 인코딩, 반복문을 통한 복잡한 계산 등
- **I/O-bound 작업**
  - 네트워크 요청, 파일 읽기/쓰기, DB 쿼리처럼 **외부 리소스의 응답을 기다리는 작업이 대부분**인 작업
  - delay() 도 일종의 '시간'이라는 리소스를 기다리를 I/O-bound 작업임
  - suspend 함수는 이런 대기 상태에서 스레드를 차단하지 않고(non-blocking) 코루틴을 '중단'하기 때문에, 굳이 다른 스레드로 작업을 넘길 필요가 없음
  - 메인 스레드에서 호출해도 UI 를 막지 않아 안전함

결론적으로, delay() 는 스레드 non-blocking 으로 동작하므로 `withContext()` 없이 현재 컨텍스트에서 바로 호출해도 안전하다.

</details>

<br />

이제 delay() 가 포함된 함수를 runBlocking 으로 테스트해본다.

RepeatAddWithDelayUseCaseTest.kt
```kotlin
package chap12

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import kotlin.system.measureTimeMillis

class RepeatAddWithDelayUseCaseTest {
    @Test
    fun `runBlocking_100번 더하면 100이 반환된다`() = runBlocking {
        // Given
        val repeatAddUseCase = RepeatAddWithDelayUseCase()

        // When
        val time = measureTimeMillis {
            val result = repeatAddUseCase.add(100)

            // Then
            assertEquals(100, result)
        }
        println("테스트 소요 시간: ${time}ms") // 실제 소요 시간 측정
    }
}
```

- 결과: 테스트는 성공적으로 통과
- 문제점: 테스트 소요 시간이 총 10403ms (10초) 소요됨

**훌륭한 테스트의 핵심 원칙 중 하나는 '신속함'이다.**

테스트 실행이 느리고 부담스러워진다면, 개발자들은 테스트 코드 작성을 꺼리게 되고 결국 코드의 품질은 저하된다.  
테스트 하나에 10초씩 걸린다면 수백 개의 테스트를 가진 프로젝트는 사실상 테스트를 유지하기 어렵다.

이 '실제 시간'을 기다려야 하는 문제를 해결하기 위해, 코루틴 테스트 라이브러리는 '가상 시간'에서 테스트를 진행할 수 있는 도구를 제공한다.

---

# 3. 코루틴 테스트 라이브러리

앞서 delay() 가 포함되어 테스트가 10초 넘게 걸리는 문제를 확인했다.  
이런 느린 테스트는 프로젝트의 생산성을 크게 저하시킨다.

이런 문제를 해결하기 위해 `kotlinx-coroutines-test` 라이브러리는 가상 시간(virtual time)을 사용하여 테스트를 즉시 실행할 수 있는 기능을 제공한다.

```kotlin
dependencies {
    // ...
    
    // 코루틴 테스트 라이브러리 (kotlinx-coroutine-core 와 버전을 맞춰주어야 함)
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
}
```

## 3.1. `TestCoroutineScheduler` 사용해 가상 시간에서 테스트

`TestCoroutineScheduler` 는 테스트 코드 내의 가상 시간을 관리하는 '시계'와 같은 역할을 한다.

---

### 3.1.1. `advanceTimeBy()` 로 가상 시간 흐르게 하기

`TestCoroutineScheduler` 의 가장 기본적인 기능은 시간을 직접 제어하는 것이다.
- `advanceTimeBy(시간)`: 인자로 전달된 ms 만큼 가상 시간 진행
- `currentTime`: 현재까지 흐른 총 가상 시간을 ms 단위로 반환

`TestCoroutineScheduler` 기본 사용법
```kotlin
package chap12

import kotlinx.coroutines.test.TestCoroutineScheduler
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class TestCoroutineScheduler {
    @Test
    fun `가상 시간 조절 테스트`() {
        // Given: 테스트용 스케줄러 생성
        val testCoroutineScheduler = TestCoroutineScheduler()

        // When: 가상 시간에서 5초 흐르게 만듦
        testCoroutineScheduler.advanceTimeBy(delayTimeMillis = 5000L)
        // Then: 현재 가상 시간은 5000ms
        assertEquals(5000L, testCoroutineScheduler.currentTime)

        // When: 가상 시간에서 6초를 흐르게 만듦
        // Then: 현재 가상 시간은 11000ms
        testCoroutineScheduler.advanceTimeBy(delayTimeMillis = 6000L)
        assertEquals(11000L, testCoroutineScheduler.currentTime)
    }
}
```

---

### 3.1.2. `TestCoroutineScheduler` 와 `StandardTestDispatcher()` 로 가상 시간 위에서 테스트 진행

> 해당 코드는 최종적으로 사용될 `runTest()` 함수의 내부 동작을 이해하기 위한 과정이므로 해당 코드는 참고만 할 것

`TestCoroutineScheduler` 객체만으로는 코루틴을 실행할 수 없다.  
`TestCoroutineScheduler` 에 맞춰 동작할 일꾼인 CoroutineDispatcher 가 필요하다. `kotlinx-coroutine-test` 는 `StandardTestDispatcher` 라는 
테스트용 Dispatcher 를 제공한다.

`StandardTestDispatcher` 를 생성할 때 `TestCoroutineScheduler` 를 인자로 넘겨주면, 해당 Dispatcher 에서 실행되는 코루틴들은 우리가 제어하는 가상 시간을 따르게 된다.

가상 시간 위에서 코루틴 실행하는 예시
```kotlin
package chap12

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestDispatcher
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class TestCoroutineScheduler {
    @Test
    fun `가상 시간 위에서 테스트 진행`() {
        // 가상 시간을 관리할 '시계' 생성
        val testCoroutineScheduler: TestCoroutineScheduler = TestCoroutineScheduler()
        // '시계'에 맞춰 동작할 '일꾼'인 Dispatcher 생성
        val testDispatcher: TestDispatcher = StandardTestDispatcher(scheduler = testCoroutineScheduler)
        // '일꾼'을 사용하는 코루틴 스코프 생성
        val testCoroutineScope = CoroutineScope(context = testDispatcher)

        // Given
        var result = 0

        // When: 테스트 스코프에서 코루틴 실행(20초짜리 작업)
        testCoroutineScope.launch {
            delay(10000L) // 10초간 대기
            result = 1
            delay(10000L) // 10초간 대기
            result = 2
            println(Thread.currentThread().name) // Test worker @coroutine#1
        }

        // Then: 코루틴은 시작됐지만, 아직 시간이 흐르지 않아 아무것도 실행되지 않음
        assertEquals(0, result)

        // 가상 시간에서 5초 흐르게 함: 현재 시간 5초
        testCoroutineScheduler.advanceTimeBy(5000L)
        assertEquals(0, result)

        // 가상 시간에서 6초 흐르게 함: 현재 시간 11초
        testCoroutineScheduler.advanceTimeBy(6000L)
        assertEquals(1, result)

        // 가상 시간에서 10초 흐르게 함: 현재 시간 21초
        testCoroutineScheduler.advanceTimeBy(10000L)
        assertEquals(2, result)
    }
}
```

위 코드는 `TestCoroutineScheduler` 의 동작 원리를 명확하게 보여준다.  
코루틴 내의 delay()는 `advanceByTime()` 으로 가상 시간을 진행시켜야만 비로소 완료된다.

실제 테스트에서 이렇게 시간을 수동으로 여러 번 조절하는 경우는 거의 없다.  
하지만 이 메커니즘을 이해하는 것은 라이브러리의 다른 고급 기능을 파악하는데 큰 도움이 된다.

---

### 3.1.3. `advanceUntilIdle()` 로 모든 코루틴 실행

> 해당 코드는 최종적으로 사용될 `runTest()` 함수의 내부 동작을 이해하기 위한 과정이므로 해당 코드는 참고만 할 것

실제 테스트에서는 '코루틴이 끝날 떼까지 시간을 감고 결과를 확인'하는 경우가 대부분이다. 매번 delay() 시간을 계산하여 `advanceTimeBy()`를 호출하는 것은 매우 번거롭다.

이런 경우를 위해 `advanceUntilIdle()` 함수가 존재한다.  
이 함수는 스케줄러에 대기 중인 모든 작업이 완료될 때까지 가상 시간을 **한 번에** 진행시킨다.

`advanceUntilIdle()` 사용 예시
```kotlin
package chap12

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestDispatcher
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class TestCoroutineScheduler {
    @Test
    fun `advanceUntilIdle() 사용`() {
        // 테스트 환경 설정(스케쥴러는 Dispatcher 가 내부적으로 관리)
        val testDispatcher: TestDispatcher = StandardTestDispatcher()
        val testCoroutineScope: CoroutineScope = CoroutineScope(context = testDispatcher)

        // Given
        var result = 0

        // When
        testCoroutineScope.launch {
            delay(10000L) // 10초간 대기
            result = 1
            delay(10000L) // 10초간 대기
            result = 2
        }

        // Then: testCoroutineScope 내부의 코루틴이 모두 실행되게 만듦(= 대기 중인 모든 코루틴이 끝날 때까지 가상 시간을 진행시킴)
        testDispatcher.scheduler.advanceUntilIdle()
        // 최종 결과인 2가 즉시 확인됨
        assertEquals(2, result)
    }
}
```

`TestCoroutineScheduler.advanceUntilIdle()` 이 호출되면 testCoroutineScheduler 와 연결된 코루틴이 모두 실행 완료될 때까지 가상 시간이 흐른다.

---

## 3.2. `TestCoroutineScheduler` 를 포함하는 `StandardTestDispatcher()`

> 해당 코드는 최종적으로 사용될 `runTest()` 함수의 내부 동작을 이해하기 위한 과정이므로 해당 코드는 참고만 할 것

앞선 코드에서 `TestCoroutineScheduler` 객체를 직접 생성하고, `StandardTestDispatcher()` 에 주입하는 과정을 살펴보았다.  
하지만 코루틴 테스트 라이브러리를 이 과정을 더 간결하게 해준다.

결론부터 말하면, **`StandardTestDispatcher()` 는 내부적으로 `TestCoroutineScheduler` 를 자동으로 생성하고 관리**한다.

`StandardTestDispatcher()` 시그니처
```kotlin
public fun StandardTestDispatcher(
    scheduler: TestCoroutineScheduler? = null,
    name: String? = null
): TestDispatcher = StandardTestDispatcherImpl(
    scheduler ?: TestMainDispatcher.currentTestScheduler ?: TestCoroutineScheduler(), name)
```

scheduler 파라메터는 null 을 허용하며, 기본적으로 null 이다.  
이 경우 `StandardTestDispatcher` 내부에서 `TestCoroutineScheduler()` 를 직접 생성하여 사용한다.

따라서 `TestCoroutineScheduler` 를 직접 생성할 필요없이 `StandardTestDispatcher()` 만 호출하면 된다.  
그리고 필요하다면 생성된 Dispatcher 의 scheduler 프로퍼티는 통해 내부 스케쥴러에 접근할 수 있다.

이미 [3.1.3. `advanceUntilIdle()` 로 모든 코루틴 실행](#313-advanceuntilidle-로-모든-코루틴-실행) 의 예시에서 이 방식을 사용했다.

```kotlin
// TestCoroutineScheduler 를 직접 생성하지 않음
val testDispatcher: TestDispatcher = StandardTestDispatcher()
// dispatcher 의 scheduler 프로퍼티를 통해 스케쥴러 기능 사용
testDispatcher.scheduler.advanceUntilIdle()
```

코드가 깔끔해졌지만 아직 개선의 여지가 남아있다.

---

## 3.3. `TestScope()` 를 사용해 가상 시간에서 테스트

> 해당 코드는 최종적으로 사용될 `runTest()` 함수의 내부 동작을 이해하기 위한 과정이므로 해당 코드는 참고만 할 것

`StandardTestDispatcher()` 덕분에 `TestCoroutineScheduler` 스케쥴러 생성 코드를 사라졌지만, 여전히 아래와 같은 코드가 반복된다.

```kotlin
val testDispatcher: TestDispatcher = StandardTestDispatcher()
val testCoroutineScope: CoroutineScope = CoroutineScope(context = testDispatcher)
```

이 두 줄의 코드를 하나로 합쳐주는 것이 바로 `TestScope()` 이다.

`TestScope()` 는 테스트에 필요한 `TestDispatcher` 와 `TestCoroutineScheduler` 를 모두 내장하고 있는 튻한 CoroutineScope 이다.

`TestScope()` 를 사용하면 `advanceTimeBy()`, `advanceUntilIdle()` 같은 스케쥴러 함수들과 `currentTime` 같은 프로퍼티들을 Scope 에서 직접 호출할 수 있다.  
예) testScope.scheduler.advanceUntilIdle() 대신 testScope.advanceUntilIdle() 사용

이전 코드를 `TestScope()` 를 사용하도록 수정하면 아래와 같다.

`TestScope()` 사용 예시
```kotlin
package chap12

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class TestCoroutineScheduler {
    @Test
    fun `TestScope() 사용`() {
        // Dispatcher 와 Scope 생성을 한 줄로!
        val testCoroutineScope: TestScope = TestScope()

        // Given
        var result = 0

        // When
        testCoroutineScope.launch {
            delay(10000L) // 10초간 대기
            result = 1
            delay(10000L) // 10초간 대기
            result = 2
        }

        // Then: scheduler 에 접근할 필요없이 Scope 에서 바로 시간 제어 함수 호출
        testCoroutineScope.advanceUntilIdle()
        assertEquals(2, result)
    }
}
```

코드가 훨씬 깔끔하고 직관적으로 개선되었다.

하지만 아직도 `TestScope` 객체를 직접 생성하고, 테스트 마지막에 `advanceUntilIdle()` 을 수동으로 호출해주고 있다.  
코루틴 테스트 라이브러리는 이 마지막 남은 코드마저 제거할 수 있는 `runTest()` 함수를 제공한다.

---

## 3.4. `runTest()` 를 사용해 테스트

`TestCoroutineScheduler` 로 시작해서 `StandardTestDispatcher()`, `TestScope()` 를 거치며 테스트 코드를 점진적으로 개선해왔다.  
이제 이 모든 것을 하나로 합친 최종 해결책인 `runTest()` 에 대해 알아본다.

**`runTest()` 는 코루틴 테스트를 위한 궁극의 코루틴 빌더이다.  
`TestScope()` 를 자동으로 생성하고, delay() 와 같은 일시 중단 함수를 만났을 때 가상 시간을 즉시 진행시켜, 시간이 걸리는 테스트를 바로 완료해준다.**

원래 20초 짜리 테스트 코드를 `runTest()` 로 테스트하는 예시
```kotlin
package chap12

import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class TestCoroutineSchedulerTest {
    @Test
    fun `runTest() 사용`() {
        // Given
        var result = 0

        // When
        runTest {
            delay(10000L) // 10초간 대기
            result = 1
            delay(10000L) // 10초간 대기
            result = 2
        }

        // Then
        assertEquals(2, result)
    }
}
```

runBlocking 을 사용했다면 20초가 걸렸을 이 테스트는 `runTest()` 를 사용함으로써 단 50ms 내외로 완료된다.

![코루틴 라이브러리 구성 요소의 포함관계](/assets/img/dev/2025/0810/testscope.png)

위 코드에서는 이전 예시와 비교를 위해 테스트를 원하는 코드만 `runTest()` 함수로 감쌌지만, **일반적으로는 위처럼 코드 블록만 감싸기보다는 테스트 함수 전체를 
`runTest()` 로 정의하는 방식을 권장**한다.

```kotlin
@Test
fun `runTest() 로 테스트 감싸기`() = runTest { // this: TestScope
    // Given
    var result = 0

    // When
    delay(10000L) // 10초간 대기
    result = 1
    delay(10000L) // 10초간 대기
    result = 2

    // Then
    assertEquals(2, result)
}
```

이렇게 하면 Given-When-Then 의 모든 단계에서 일시 중단 함수가 호출되어도 빠른 테스트가 가능하기 때문에, 
모든 곳에서 일시 중단 함수(suspend)를 자유롭게 호출할 수 있어 훨씬 유연한 테스트 작성이 가능하다.

---

### 3.4.1. `runTest()` 함수의 람다식에서 `TestScope` 사용

`runTest()` 함수가 강력한 이유는 그 블록 내부가 `TestScope` 이기 때문이다.  
즉, `runTest()` 블록 안에서 this 는 `TestScope` 를 가리키므로 `advanceTimeBy()`, `advanceUntilIdle()`, `currentTime` 등 `TestScope`의 
모든 기능을 직접 사용할 수 있다.

`runTest()` 함수의 람다식에서 this.currentTime 으로 가상 시간 확인
```kotlin
package chap12

import kotlinx.coroutines.delay
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test

class TestCoroutineSchedulerTest {
    @Test
    fun `runTest() 내부에서 가상 시간 확인`() = runTest { // 0ms
        delay(1000L)
        println("가상 시간: ${this.currentTime}ms")
        delay(1000L)
        println("가상 시간: ${this.currentTime}ms")
    }
}
```

```shell
가상 시간: 1000ms
가상 시간: 2000ms
```

`runTest()` 블록 내에서 delay() 가 호출되자, 별도의 조작 없이도 가상 시간이 자동으로 흐르는 것을 볼 수 있다.

---

#### 3.4.1.1. `launch()`와 함께 사용할 때: `advanceUntilIdle()` 이 필요한 이유

`runTest()` 는 **자신이 직접 실행하는** suspend 함수에 대해서만 시간을 자동으로 진행시킨다.  
launch, async 등으로 생성된 **새로운 자식 코루틴에 대해서는 자동으로 시간을 진행시키지 않는다.**

이것은 여러 코루틴을 동시에 실행하는 병렬/동시성 테스트를 이해 의도적으로 설계된 동작이다.  
만일 launch 가 즉시 실행된다면 모든 코루틴이 순차적으로 진행되어 동시성 테스트가 불가능해지기 때문이다.  
`runTest()` 의 테스트 환경은 기본적으로 단일 스레드 위에서 동작하기 때문에 launch 가 여러 개 있으면 순차적으로 실행된다.  
`runTest()` 에서 launch 는 '즉시 실행'이 아니라 '작업 예약'이다.  
따라서 launch 즉시 실행되지 않고 예약만 하기 때문에, 여러 작업을 모두 예약한 뒤(launch, launch..) `advanceUntilIdle()` 을 통해 한 번에 실행시켜 동시성 테스트를 할 수 있다.

launch 로 생성된 코루틴을 실행시키기 위해, `advanceUntilIdle()`을 명시적으로 호출하는 예시
```kotlin
package chap12

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test

class TestCoroutineSchedulerTest {
    @Test
    fun `runTest() 내부에서 advanceUntilIdle() 사용하기`() = runTest { // this: TestScope
        var result = 0

        // When: 새로운 자식 코루틴 생성
        launch {
            delay(1000L)
            result = 1
        }

        // Then
        // launch 는 선언 즉시 실행되지 않으므로, 아직 가상 시간: 0ms, result: 0
        println("가상 시간: ${this.currentTime}ms, result: $result")
        
        // 대기 중인 모든 자식 코루틴(launch) 실행
        advanceUntilIdle()
        
        // launch 블록이 모두 실행 완료됨, 가상 시간: 1000ms, result: 1
        println("가상 시간: ${this.currentTime}ms, result: $result")
    }
}
```

---
만일 runTest() 코루틴의 자식 코루틴을 생성하는 것이 아니라 runTest() 로 생성한 작업(Job) 에 대해 [`join()`](https://assu10.github.io/dev/2024/11/09/coroutine-builder-job/#1-join-%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%9C-%EC%BD%94%EB%A3%A8%ED%8B%B4-%EC%88%9C%EC%B0%A8-%EC%B2%98%EB%A6%AC)
함수를 호출하면 어떻게 될까?  
join() 자체도 일시 중단 함수이므로, `runTest()` 의 자동 시간 메커니즘이 동작한다.  
따라서 이 경우에는 `advanceUntilIdle()`을 호출하지 않아도 해당 launch 블록이 완료될 때까지 시간이 흐른다.

```kotlin
package chap12

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test

class TestCoroutineSchedulerTest {
    @Test
    fun `runTest() 내부에서 join() 사용하기`() = runTest {
        var result = 0

        launch {
            delay(1000L)
            result = 1
        }.join() // join() 이 runTest 코루틴을 중단시켜 가상 시간을 흐르게 함

        // join() 이 완료된 시점에는 이미 launch 블록이 모두 실행됨, 가상 시간: 1000ms, result: 1
        println("가상 시간: ${this.currentTime}ms, result: $result")
    }
}
```

지금까지 `kotlinx-coroutines-test` 라이브러리의 핵심 기능을 단계별로 알아보았다.

다음 포스트에서는 실제 코루틴 코드에 대한 테스트를 만드는 방법에 대해 알아볼 예정이다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 조세영 저자의 **코틀린 코루틴의 정석**을 기반으로 스터디하며 정리한 내용들입니다.*

* [기초부터 심화까지 알아보는 코틀린 코루틴의 정석](https://www.yes24.com/Product/Goods/125014350)
* [예제 코드](https://github.com/seyoungcho2/coroutinesbook)