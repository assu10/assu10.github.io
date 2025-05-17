---
layout: post
title: "Kotlin - 에러 방지(2): 자원 해제('use()'), Logging, 단위 테스트"
date: 2024-03-10
categories: dev
tags: kotlin use() useLines() forEachLine() authCloseable logging kotlin.test junit5
---

이 포스트에서는 자원 해제, 로깅, 단위 테스트에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap06) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 자원 해제: `use()`](#1-자원-해제-use)
  * [1.1. `useLines()`](#11-uselines)
  * [1.2. `forEachLine()`](#12-foreachline)
  * [1.3. `AutoCloseable` 인터페이스를 구현하여 커스텀 클래스 생성](#13-autocloseable-인터페이스를-구현하여-커스텀-클래스-생성)
* [2. Logging](#2-logging)
* [3. 단위 테스트](#3-단위-테스트)
  * [3.1. kotlin.test](#31-kotlintest)
  * [3.2. 테스트 프레임워크: JUnit5, `@Test`](#32-테스트-프레임워크-junit5-test)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 자원 해제: `use()`

> [1.5. 자원 관리를 위한 `inline` 된 람다 사용: `withLock()`, `use()`](https://assu10.github.io/dev/2024/03/16/kotlin-inline/#15-%EC%9E%90%EC%9B%90-%EA%B4%80%EB%A6%AC%EB%A5%BC-%EC%9C%84%ED%95%9C-inline-%EB%90%9C-%EB%9E%8C%EB%8B%A4-%EC%82%AC%EC%9A%A9-withlock-use) 와 함께 보면 도움이 됩니다.

[1.4. 자원 해제: `finally`](https://assu10.github.io/dev/2024/03/09/kotlin-error-handling-1/#14-%EC%9E%90%EC%9B%90-%ED%95%B4%EC%A0%9C-finally) 에서 본 것처럼 
`finally` 절은 try 블록이 어떤 식으로 끝나는지 관계없이 자원을 해제해줄 수 있다.

하지만 자원을 닫는 도중 예외가 발생한다면 결국 `finally` 절 안에서 다른 try 블록이 필요해지고, 예외가 발생하여 이를 처리하는 상황이라면 `finally` 블록의 try 안에서 예외가 발생한 경우 
나중에 발생한 예외가 최초 발생했던 예외를 감춰서는 안된다.  
결국 `finally` 를 사용하여 자원을 해제하면 제대로 자원을 해제하는 과정이 매우 복잡해진다.

이런 복잡도를 낮추기 위해 코틀린은 **`use()` 를 제공**한다.  
**`use()` 함수는 닫을 수 있는 자원을 제대로 해제**해주고, 자원 해제 코드를 직접 작성하지 않아도 되게 해준다.

**즉, `use()` 를 사용하면 자원을 생성하는 시점에서 자원 해제를 확실히 보장할 수 있으며, 자원 사용을 끝낸 시점에 직접 자원 해제 코드를 작성하지 않아도 된다.**

> 자바의 `try-with-resources` 와 비슷한 기능임  
> `try-with-resoueces` 에 대한 내용은 [`try-with-resources` 개선](https://assu10.github.io/dev/2023/07/30/java-java-versions/#try-with-resources-%EA%B0%9C%EC%84%A0) 을 참고하세요.

**`use()` 는 자바의 `AutoCloseable` 인터페이스를 구현하는 모든 객체에 작용**할 수 있다.  
**`use()` 는 인자로 받은 코드 블록을 실행한 후, 그 블록을 어떻게 빠져나왔는지와 관계없이 객체의 `close()` 를 호출**한다.

**`use()` 는 모든 예외를 다시 던져주기 때문에 프로그램에서는 여전히 예외를 처리**해야 한다.

예를 들어 `File` 에서 한 줄씩 문자열을 읽고 싶다면 `BufferedReader` 에 대해 `use()` 를 사용하면 된다.

```kotlin
import java.io.File

var targetDir = File("DataFiles")

class DataFile(val fileName: String) : File(targetDir, fileName) {
    init {
        if (!targetDir.exists()) {
            targetDir.mkdir()
        }
    }

    fun erase() {
        if (exists()) {
            delete()
        }
    }

    fun reset(): File {
        erase()
        createNewFile()
        return this
    }
}

fun main() {
    // result.txt 의 내용은 아래와 같음
    // result
    // #ok
    // ddd
    val result =
        DataFile("result.txt")
            .bufferedReader()
            .use { it.readLines().first() }

    println(result) // result
}
```

result.txt
```text
result
#ok
ddd
```

---

## 1.1. `useLines()`

**`useLines()` 는 File 객체를 열고, 파일에서 모든 줄을 읽은 후에 대상 함수 (보통은 람다) 에 모든 줄을 전달**한다.

모든 작업은 `useLines()` 에 전달된 람다 내부에서 이루어진다.  
**`useLines()` 는 파일을 닫고 람다가 반환하는 결과를 반환**한다.

> _DataFile_ 클래스는 [1. 자원 해제: `use()`](#1-자원-해제-use) 에서 작성한 클래스임

```kotlin
fun main() {
    val result1 =
        DataFile("result.txt")
            .useLines {
                it.joinToString()
            }

    val result2 =
        DataFile("result.txt")
            .useLines { it ->
                // 왼쪽의 it 은 파일에서 읽은 줄을 모아둔 컬렉션을 가리키고,
                // 오른쪽의 it 은 개별적인 줄을 뜻함
                it.filter { "#" in it }.first()
            }

    val result3 =
        DataFile("result.txt")
            .useLines { lines -> // 이렇게 람다에 이름을 붙이면 it 이 많아서 생기는 혼동을 줄일 수 있음
                lines.filter { line ->
                    "#" in line
                }.first()
            }

    println(result1) // result, #ok, ddd
    println(result2) // #ok
    println(result3) // #ok
}
```

---

## 1.2. `forEachLine()`

**`forEachLine()` 은 파일의 각 줄에 대해 작업을 쉽게 적용**할 수 있다.

**`forEachLine()` 에 전달된 람다는 Unit 을 반환**한다.  
이 말은 이 람다 안에서는 원하는 일을 부수 효과를 통해 달성해야한다는 의미이다.  
**함수형 프로그래밍에서는 부수 효과보다는 결과를 반환하는 쪽을 더 선호하므로 `useLines()` 이 `forEachLine()` 보다 더 함수형인 접근 방법**이다.

하지만 간단한 처리를 해야 하는 경우는 `forEachLine()` 이 더 빠른 방법이 될 수 있다.

> _DataFile_ 클래스는 [1. 자원 해제: `use()`](#1-자원-해제-use) 에서 작성한 클래스임

```kotlin
fun main() {
    val result =
        DataFile("result.txt").forEachLine {
            if (it.startsWith("#")) {
                println("it's $it")

                it
            }
        }

    println(result)
}
```

---

## 1.3. `AutoCloseable` 인터페이스를 구현하여 커스텀 클래스 생성

`AutoCloseable` 인터페이스를 구현하면 `use()` 에 사용할 수 있는 커스텀 클래스를 생성할 수 있다.

`AutoCloseable` 인터페이스
```kotlin
package java.lang;

public interface AutoCloseable {
    void close() throws Exception;
}
```

마지막에 `close()` 를 호출하는 것을 알 수 있다.

```kotlin
class Usable : AutoCloseable {
    fun func() = println("func()~")

    override fun close() = println("close()~")
}

fun main() {
    // func()~
    // close()~
    Usable().use { it.func() }
}
```

---

# 2. Logging

[kotlin-logging](https://github.com/oshai/kotlin-logging) 오픈 소스 로깅 패키지를 사용하여 로깅을 할 수 있다.

대부분의 경우 로거를 파일 영역에 정의해서 같은 파일에 있는 모든 컴포넌트가 로거를 사용할 수 있도록 한다.

```text
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web") {
        exclude(group = "ch.qos.logback", module = "logback-classic")
    }
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    testImplementation("org.springframework.boot:spring-boot-starter-test")

    // Logging
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
    implementation("org.slf4j:slf4j-simple:2.0.13")
}
```

```kotlin
import mu.KLogging

private val log = KLogging().logger

fun main() {
    val msg = "hello~"

    log.trace(msg)
    log.debug(msg)
    log.info(msg) // [main] INFO mu.KLogging - hello~
    log.warn { msg } // [main] WARN mu.KLogging - hello~
    log.error { msg } // [main] ERROR mu.KLogging - hello~
}
```

kotlin-logging 라이브러리는 SLF4J 위에 만든 [퍼사드(facade)](https://assu10.github.io/dev/2024/12/15/Facade/)이다.  SLF4J 자체는 여러 가지 로깅 프레임워크 위에 만들어진 추상화이다.  
위에선 `slf4j-simple` 을 구현으로 선택하였다.

디폴트 설정이 info level 이상 출력하도록 되어있기 때문에 trace() 와 debug() 는 출력되지 않는다.

---

# 3. 단위 테스트

> 테스트에 대한 좀 더 상세한 내용은 [Spring Boot - 스프링 부트 테스트](https://assu10.github.io/dev/2023/08/27/springboot-test/) 를 참고하세요.

단위 테스트는 프로젝트를 빌드할 때마다 실행되기 때문에 실행 속도가 아주 빨라야 한다.

많은 단위 테스트 프레임워크가 있지만 `JUnit` 이 가장 유명하다.  

코틀린 전용 단위 테스트 프레임워크도 있다. **코틀린 표준 라이브러리에는 여러 테스트 라이브러리에 대한 [facade](https://assu10.github.io/dev/2024/12/15/Facade/) 를 제공하는 `kotlin.test` 가 포함**되어 있다.  
따라서 어느 한 라이브러리에 구속될 필요가 없다.

`kotlin.test` 를 사용하려면 build.gradle.kt 의 dependencies 에 아래 내용을 추가한다.  
그러면 코틀린 플러그인이 자동으로 코틀린 테스트 관련 의존 관계를 처리해준다.

```kotlin
// for Kotlin test
implementation(kotlin("test"))
```

단위 테스트안에서는 여러 예상 동작을 검증하기 위해 단언문 함수를 실행한다.

단언문 함수로는 실제값과 예상값을 비교하는 `assertEquals()`, 첫 번째 파라미터로 들어오는 Boolean 식이 참인지 검증하는 `assertTrue()` 등이 있다.  

아래 코드에서 _test_ 로 시작하는 함수들이 단위 테스트이다.

```kotlin
import kotlin.test.assertEquals
import kotlin.test.assertTrue

fun fortyTwo() = 42

// 단위 테스트
fun testFortyTwo(n: Int = 42) {
    assertEquals(
        expected = n,
        actual = fortyTwo(),
        message = "incorrect,",
    )
}

fun allGood(b: Boolean = true) = b

fun testAllGood(b: Boolean = true) {
    assertTrue(actual = allGood(b), message = "not good")
}

fun main() {
    testFortyTwo()
    testAllGood()

    // Exception in thread "main" java.lang.AssertionError: incorrect,. Expected <11>, actual <42>.
    testFortyTwo(11)

    // Exception in thread "main" java.lang.AssertionError: not good
    // testAllGood(false)
}
```

실패한 단언문은 _AssertionError_ 를 발생시킨다.

---

## 3.1. kotlin.test

kotlin.test 는 assert 로 시작하는 여러 함수를 제공한다.

- `assertEquals()`, `assertNotEquals()`
- `assertTrue()`, `assertFalse()`
- `assertNull()`, `assertNotNull()`
- `assertFails()`, `assertFailsWith()`

kotlin.test 에 있는 `expect()` 함수는 코드 블록을 실행하고 그 결과를 예상값과 비교한다.

expect() 시그니처
```kotlin
inline fun <@OnlyInputTypes T> expect(expected: T, message: String?, block: () -> T) {
    contract { callsInPlace(block, InvocationKind.EXACTLY_ONCE) }
    assertEquals(expected, block(), message)
}
```

아래는 `expect()` 를 사용하여 [3. 단위 테스트](#3-단위-테스트) 의 _testFortyTwo()_ 를 다시 구성한 예시이다.  
`assertFails()`, `assertFailsWith()` 의 예시도 들어있다.

```kotlin
import kotlin.test.assertFails
import kotlin.test.assertFailsWith
import kotlin.test.expect

fun fortyTwo2() = 42

fun testFortyTwo2(n: Int = 42) {
    expect(expected = n, message = "Incorrect,") { fortyTwo2() }
}

fun main() {
    testFortyTwo2()

    // Exception in thread "main" java.lang.AssertionError:
    // Incorrect,. Expected <11>, actual <42>.

    // testFortyTwo2(11)

    assertFails { testFortyTwo2(11) }

    // Exception in thread "main" java.lang.AssertionError:
    // Expected an exception to be thrown, but was completed successfully.

    // assertFails { testFortyTwo2() }

    assertFailsWith<AssertionError> { testFortyTwo2(11) }

    // Exception in thread "main" java.lang.AssertionError:
    // Expected an exception of class java.lang.AssertionError to be thrown, but was completed successfully.

    // 던져진 예외의 타입까지 검사함
    assertFailsWith<AssertionError> { testFortyTwo2() }
}
```

---

## 3.2. 테스트 프레임워크: JUnit5, `@Test`

이번 예시는 kotlin.test 의 하부 라이이브러리로 JUnit5 를 사용한다.

프로젝트에 JUnit5 를 추가하려면 build.gradle.kts 의 dependencies 에 아래를 추가한다.

```kotlin
dependencies {
    ...

    // For tests in Tests
    testImplementation(kotlin("test-junit5"))
    testImplementation("org.junit.platform:junit-platform-launcher")
    testImplementation("org.junit.platform:junit-platform-engine")
}

tasks.withType<Test> {
  useJUnitPlatform()
  testLogging {
    exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
  }
}
```

kotlin.test 는 일반적으로 사용되는 함수에 대해 [facade](https://assu10.github.io/dev/2024/12/15/Facade/) 를 제공한다.  
예) kotlin.test 의 `assertEquals()` 는 org.junit.jupiter.api.Assertions 클래스의 `assertEquals()` 를 사용

코틀린은 정의와 식에 애너테이션을 허용하는데 예를 들어 `@Test` 애너테이션은 일반 함수를 테스트 함수로 변경해준다.

> 테스트 러너를 실행하면 러너가 모든 클래스를 뒤지면서 `@Test` 애너테이션이 붙은 함수를 찾아 실행하기 때문에 `@Test` 가 일반 함수를 테스트 함수로 지정해주는 효과가 있음  
> 단, `@Test` 애너테이션이 붙은 함수를 main() 에서 호출하면 그냥 일밤 함수처럼 실행됨

아래는 [3. 단위 테스트](#3-단위-테스트) 의 _fortyTwo()_ 와 _allGood()_ 을 `@Test` 를 사용하여 작성한 예시이다.


/test/unitTesting/SampleTest.kt
```kotlin
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.expect

class SampleTest {
    @Test
    fun testFortyTwo() {
        expect(expected = 42, message = "Incorrect,") { fortyTwo() }
    }

    @Test
    fun testAllGood() {
        assertTrue(actual = allGood(), "not good")
    }
}
```

intelliJ 는 실패한 테스트만 따로 실행할 수 있게 해준다.

---

아래는 _On_, _Off_, _Paused_ 3가지 상태가 있고, _start()_, _pause()_, _resume()_, _finish()_ 가 이 상태를 제어하는 코드 예시이다.

```kotlin
import assu.study.kotlinme.chap06.unitTesting.State.Off
import assu.study.kotlinme.chap06.unitTesting.State.On
import assu.study.kotlinme.chap06.unitTesting.State.Paused

enum class State { On, Off, Paused }

class StateMachine {
    var state: State = Off
        private set

    private fun transition(
        new: State,
        current: State = On,
    ) {
        if (new === Off && state !== Off) {
            state = Off
        } else if (state == current) {
            state = new
        }
    }

    fun start() = transition(On, Off)

    fun pause() = transition(Paused, On)

    fun resume() = transition(On, Paused)

    fun finish() = transition(Off)
}
```

> setter 를 private 를 지정하는 _private set_ 에 대한 내용은 [9. 프로퍼티 접근자: `field`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#9-%ED%94%84%EB%A1%9C%ED%8D%BC%ED%8B%B0-%EC%A0%91%EA%B7%BC%EC%9E%90-field) 를 참고하세요.

위의 _StateMachine_ 을 테스트하기 위해 테스트 클래스 안에 sm 프로퍼티를 만들어본다.   
테스트 러너는 다른 테스트가 실행될 때마다 새로운 _StateMachineTest_ 객체를 생성한다.

/test/unitTesting/StateMachineTest.kt
```kotlin
import kotlin.test.Test
import kotlin.test.assertEquals

class StateMachineTest {
    val sm = StateMachine()

    @Test
    fun start() {
        sm.start()
        assertEquals(expected = State.On, actual = sm.state)
    }

    @Test
    fun `pause and resume`() {
        sm.start()
        sm.pause()
        assertEquals(expected = State.Paused, actual = sm.state)

        sm.resume()
        assertEquals(expected = State.On, actual = sm.state)

        sm.pause()
        assertEquals(expected = State.Paused, actual = sm.state)
    }
}
```

[Teamcity](https://www.jetbrains.com/teamcity/) 같은 CI 서버를 사용하면 자동으로 모든 테스트가 실행되고, 잘못된 경우 알림을 받을 수 있다.

---

아래와 같이 여러 프로퍼티가 있는 데이터 클래스가 있다고 하자.
```kotlin
enum class Language {
    Kotlin,
    Java,
    Go,
    Python,
}

data class Leaner(
    val id: Int,
    val name: String,
    val surname: String,
    val language: Language,
)
```

테스트 데이터를 생성하기 위한 유틸리티 함수를 추가하면 도움이 될 때가 많은데 특히 테스트를 진행하는 과정에서 디폴트 값이 동일한 객체를 많이 생성해야 하는 경우가 특히 그렇다.

아래에서 _makeLeaner()_ 는 디폴트 값을 지정한 객체를 여러 개 생성한다.

/test/unitTesting/LeanerTest.kt
```kotlin
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

fun makeLeaner(
    id: Int,
    language: Language = Language.Kotlin,
    name: String = "Test Name: $id",
    surname: String = "Test Surname: $id",
) = Leaner(id, name, surname, language)

class LeanerTest {
    @Test
    fun `single Learner`() {
        val leaner = makeLeaner(10, Language.Java)
        assertEquals(expected = "Test name: 10", actual = leaner.name)
    }

    @Test
    fun `multiple Learners`() {
        val learners = (1..9).map(::makeLeaner)
        assertTrue(learners.all { it.language == Language.Kotlin })
    }
}
```

> `all()` 에 대한 내용은 [3.6. `any()`, `all()`, `maxByOrNull()`](https://assu10.github.io/dev/2024/02/17/kotlin-funtional-programming-2/#36-any-all-maxbyornull) 을 참고하세요. 


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린** 과 드리트리 제메로프, 스베트라나 이사코바 저자의 **Kotlin In Action** 을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [아토믹 코틀린 예제 코드](https://github.com/gilbutITbook/080301)
* [Kotlin In Action](https://www.yes24.com/Product/Goods/55148593)
* [Kotlin In Action 예제 코드](https://github.com/AcornPublishing/kotlin-in-action)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)
* [kotlin-logging](https://github.com/oshai/kotlin-logging)
* [Teamcity](https://www.jetbrains.com/teamcity/)