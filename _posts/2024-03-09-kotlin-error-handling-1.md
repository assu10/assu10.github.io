---
layout: post
title:  "Kotlin - 에러 방지(1): 커스텀 에러 타입 정의, 'require()', 'check()', Nothing 타입, 'TODO()'"
date:   2024-03-09
categories: dev
tags: kotlin finally require() requireNotNull() check() nothing todo()
---

이 포스트에서는 커스텀 에러 타입 정의, 검사 명령, `Nothing` 타입에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap06) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 예외 처리](#1-예외-처리)
  * [1.1. 커스텀 에러 타입 정의](#11-커스텀-에러-타입-정의)
  * [1.2. 복구](#12-복구)
  * [1.3. 예외 하위 타입](#13-예외-하위-타입)
  * [1.4. 자원 해제: `finally`](#14-자원-해제-finally)
* [2. 검사 명령](#2-검사-명령)
  * [2.1. `require()`](#21-require)
  * [2.2. `File`, `Paths`](#22-file-paths)
  * [2.3. `requireNotNull()`](#23-requirenotnull)
  * [2.4. `check()`](#24-check)
  * [2.5. `assert()`](#25-assert)
* [3. `Nothing` 타입: `TODO()`](#3-nothing-타입-todo)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 예외 처리

---

## 1.1. 커스텀 에러 타입 정의

표준 라이브러리의 예외로 충분하지 못한 경우 _Exception_ 이나 _Exception_ 의 하위 타입을 상속한 새로운 예외 타입을 정의할 수 있다.

`throw` 식은 `Throwable` 의 하위 타입을 요구한다.  
**새로운 예외 타입을 정의하려면 _Exception_ 을 상속**하면 된다. (_Exception_ 은 `Throwable` 을 확장함)

```kotlin
class Exception1(val value: Int) : Exception("wrong value: $value")

open class Exception2(desc: String) : Exception(desc)

class Exception3(desc: String) : Exception2(desc)

fun main() {
    throw Exception1(11)
    //throw Exception3("abc")
}
```

_throw Exception1(11)_ 실행 시 
```shell
Exception in thread "main" assu.study.kotlinme.chap06.exceptionHandling.Exception1: wrong value: 11
```

_throw Exception3("abc")_ 실행 시
```shell
Exception in thread "main" assu.study.kotlinme.chap06.exceptionHandling.Exception3: abc
```

---

## 1.2. 복구

아래 코드를 먼저 보자.

```kotlin
class Exception11(val value: Int) : Exception("wrong value: $value")

fun func1(): Int = throw Exception11(-11)

fun func2() = func1()

fun func3() = func2()

fun main() {
    func3()
}
```

```shell
Exception in thread "main" assu.study.kotlinme.chap06.exceptionHandling.Exception11: wrong value: -11
	at assu.study.kotlinme.chap06.exceptionHandling.StacktraceKt.func1(Stacktrace.kt:5)
	at assu.study.kotlinme.chap06.exceptionHandling.StacktraceKt.func2(Stacktrace.kt:7)
	at assu.study.kotlinme.chap06.exceptionHandling.StacktraceKt.func3(Stacktrace.kt:9)
	at assu.study.kotlinme.chap06.exceptionHandling.StacktraceKt.main(Stacktrace.kt:12)
	at assu.study.kotlinme.chap06.exceptionHandling.StacktraceKt.main(Stacktrace.kt)
```

예외가 처음 던져진 _func1()_ 이 _func1()_ 을 호출한 _func2()_ 로 한 단계 올라가고, _func2()_ 를 호출한 _func3()_ 으로 한 단계 더 전달된다.  
이런 식으로 함수 호출 체인의 가장 위쪽인 _main()_ 으로 전달된다.

이 과정에서 예외와 일치하는 exception handler 가 있으면 예외를 catch 한다.  
`exception handler` 를 찾으면 핸들러 검색이 끝나고 핸들러가 종료된다.  

만일 일치하는 핸들러는 잡지 못하면 콘솔에 stack trace 를 출력하면서 종료된다.

`exception handler` 에서는 catch 키워두 다음에 처리하려는 예외의 목록을 나열하고, 이 후 복구 과정을 구현하는 코드를 구현한다.

```kotlin
class Exception111(val value: Int) : Exception("wrong value: $value")

open class Exception222(desc: String) : Exception(desc)

class Exception333(desc: String) : Exception222(desc)

fun toss(which: Int) =
    when (which) {
        1 -> throw Exception111(111)
        2 -> throw Exception222("222")
        3 -> throw Exception333("333")
        else -> "ok"
    }

fun test(which: Int): Any? =
    try {
        toss(which)
    } catch (e: Exception111) {
        println("1 e: $e")
        println("1 e.message: ${e.message}")
        println("1 e.value: ${e.value}")
        e.message
    } catch (e: Exception333) {
        println("3 e: $e")
        println("3 e.message: ${e.message}")
        // println("1 e.value: ${e.value}")
        e.message
    } catch (e: Exception222) {
        println("2 e: $e")
        println("2 e.message: ${e.message}")
        // println("3 e.value: ${e.value}")
        e.message
    }

fun main() {
    println(test(0)) // ok
    println(test(1)) // 111
    println(test(2)) // 222
    println(test(3)) // 333
}
```

```shell
ok
1 e: assu.study.kotlinme.chap06.exceptionHandling.Exception111: wrong value: 111
1 e.message: wrong value: 111
1 e.value: 111
wrong value: 111

2 e: assu.study.kotlinme.chap06.exceptionHandling.Exception222: 222
2 e.message: 222
222

3 e: assu.study.kotlinme.chap06.exceptionHandling.Exception333: 333
3 e.message: 333
333
```

> _Any?_ 의 `?` null 이 될 수 있는 타입으로 좀 더 상세한 내용은 [1. null 이 될 수 있는 타입: `?`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#1-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%ED%83%80%EC%9E%85-) 을 참고하세요. 

---

**_Exception3333_ 이 _Exception2222_ 를 확장하고, 핸들러가 차례로 정의될 때 아래처럼 _Exception2222_ 가 먼저 위치하면 _Exception3333_ 도 함께 catch** 한다.

```kotlin
class Exception1111(val value: Int) : Exception("wrong value: $value")

open class Exception2222(desc: String) : Exception(desc)

class Exception3333(desc: String) : Exception2222(desc)

fun toss1(which: Int) =
    when (which) {
        1 -> throw Exception1111(111)
        2 -> throw Exception2222("222")
        3 -> throw Exception3333("333")
        else -> "ok"
    }

fun catchOrder(which: Int) =
    try {
        toss1(which)
    } catch (e: Exception1111) {
        "handler for Exception1111 got ${e.message}"
    } catch (e: Exception2222) {
        "handler for Exception2222 got ${e.message}"
    } catch (e: Exception3333) {
        "handler for Exception3333 got ${e.message}"
    }

fun main() {
    println(catchOrder(1))  // handler for Exception1111 got wrong value: 111
    println(catchOrder(2))  // handler for Exception2222 got 222
    println(catchOrder(3))  // handler for Exception2222 got 333
}
```

---

## 1.3. 예외 하위 타입

너무 많은 예외 타입을 만드는 것은 코드의 복잡도를 높힌다.  
간단한 규칙으로, **처리 방식이 달라야 한다면 다른 예외 타입**을 사용하여 이를 구분하는 것이 좋고,  
**처리 방식이 같다면 동일한 예외 타입을 쓰면서 생성자 인자를 다르게 주는 방식**으로 구체적인 정보를 전달하는 것이 좋다.

아래는 잘못된 값을 전달하여 발생하는 표준 라이브러리인 _IllegalArgumentException_ 발생 예시이다.

```kotlin
fun testCode(code: Int) {
    if (code <= 1000) {
        throw IllegalArgumentException("code must be > 1000: $code")
    }
}

fun main() {
    try {
        // A1 은 16진수로 161
        testCode("A1".toInt(16))
    } catch (e: IllegalArgumentException) {
        println(e.message)  // code must be > 1000: 161
    }

    try {
        testCode("0".toInt(1))
    } catch (e: IllegalArgumentException) {
        println(e.message)  // radix 1 was not in valid range 2..36
    }
}
```

두 번째 예외를 _testCode()_ 가 아닌 `toInt(radix)` 에 의해서 _IllegalArgumentException_ 이 발생하였다.

두 가지 다른 상황에서 같은 예외를 쓰면 혼선이 올 수 있기 때문에 이럴 때는 코드가 발생시키는 오류에서는 커스텀으로 _IncorrectInputException_ 을 던지게 하면 된다.

```kotlin
class IncorrectInputException1(message: String) : Exception(message)

fun checkCode(code: Int) {
    if (code <= 1000) {
        throw IllegalArgumentException("code must be > 1000: $code")
    }
}

fun main() {
    try {
        // A1 은 16진수로 161
        checkCode("A1".toInt(16))
    } catch (e: IncorrectInputException1) {
        println(e.message) // produces error code must be > 1000: 161
    } catch (e: IllegalArgumentException) {
        println("produces error ${e.message}")
    }

    try {
        checkCode("1".toInt(1))
    } catch (e: IncorrectInputException1) {
        println(e.message)
    } catch (e: IllegalArgumentException) {
        println("produces error ${e.message}") // produces error radix 1 was not in valid range 2..36
    }
}
```

---

## 1.4. 자원 해제: `finally`

> 자원을 해제하는 좀 더 나은 방법이 있으므로 아래 내용은 참고만 할 것

> `finally` 절은 자원 해제 도중 예외 발생 시 대응이 불가하므로 자원을 해제할 때는 `use()` 를 사용함    
> 이 부분에 대한 상세한 내용은 [1. 자원 해제: `use()`](https://assu10.github.io/dev/2024/03/10/kotlin-error-handling-2/#1-%EC%9E%90%EC%9B%90-%ED%95%B4%EC%A0%9C-use) 참고하세요.

실패를 피할 수 없을 때 자원을 자동으로 해제하게 만들면 다른 부분이 계속 안전하게 실행될 수 있다.

`finally` 는 예외를 처리하는 과정에서 자원을 해제할 수 있도록 보장한다.

```kotlin
fun checkValue(value: Int) {
    try {
        println(value)
        if (value <= 0) {
            throw IllegalArgumentException("value must be positive: $value")
        }
    } finally {
        println("finally for $value")
    }
}

fun main() {
    val result = listOf(10, -10)

    result.forEach {
        try {
            checkValue(it)
        } catch (e: IllegalArgumentException) {
            println("catch for main: ${e.cause}, ${e.message}")
        }
    }
}
```

```shell
10
finally for 10

-10
finally for -10
catch for main: null, value must be positive: -10
```

아래는 `finally` 의 또 다른 예시이다.

```kotlin
data class Switch(var on: Boolean = false, var result: String = "ok")

// Switch 클래스를 리턴
fun testFinally(i: Int): Switch {
    val sw = Switch()
    try {
        sw.on = true
        when (i) {
            0 -> throw IllegalArgumentException()
            1 -> return sw
        }
    } catch (e: IllegalArgumentException) {
        sw.result = "exception~"
    } finally {
        sw.on = false
    }
    return sw
}

fun main() {
    println(testFinally(0)) // Switch(on=false, result=exception~)
    println(testFinally(1)) // Switch(on=false, result=ok)
    println(testFinally(2)) // Switch(on = false, result = ok)
}
```

---

# 2. 검사 명령

검사 명령은 만족시켜야 하는 제약 조건을 적은 단언문으로 보통 함수 인자와 검증할 때 검사 명령을 사용한다.

검사 명령을 사용하면 프로그램을 검증하고, 코드를 더 자세히 설명할 수 있으므로 가능할 때마다 검사 명령을 사용하는 것이 좋다.

---

## 2.1. `require()`

사전 조건은 초기화 관련 제약 사항을 보장한다.

**`require()` 는 보통 함수 인자를 검증하기 위해 사용되며, 함수 본문 맨 앞에 위치**한다.

**인자 검증이나 사전 조건 검증을 컴파일 시점에 사용할 수는 없다.**

사전 조건은 코드에 포함시키기가 상대적으로 쉽지만, 상황에 따라서는 단위 테스트로 변환하여 처리할 수도 있다.

> 단위 테스트에 대한 상세한 내용은 [3. 단위 테스트](https://assu10.github.io/dev/2024/03/10/kotlin-error-handling-2/#3-%EB%8B%A8%EC%9C%84-%ED%85%8C%EC%8A%A4%ED%8A%B8) 를 참고하세요.

아래와 같이 달력을 달을 표현하는 숫자 필드(1..12)가 있을 때 사전 조건은 이 필드값이 해당 범위를 벗어나면 오류를 반환한다.

```kotlin
data class Month(val monthNumber: Int) {
    init {
        require(monthNumber in 1..12) {
            "Month out of range: $monthNumber"
        }
    }
}

fun main() {
    // Month(monthNumber=1)
    println(Month(1))

    // Exception in thread "main" java.lang.IllegalArgumentException: Month out of range: 13
    println(Month(13))
}
```

`require()` 를 생성자 안에서 호출하는데, `require()` 는 조건을 반족하지 못하면 _IllegalArgumentException_ 을 반환한다.  
따라서 **_IllegalArgumentException_ 예외를 던지는 대신에 항상 `require()` 를 사용**할 수 있다.

**`require()` 의 두 번째 라파메터는 String 을 만들어내는 람다**이다.  
**따라서 `require()` 가 예외를 던지기 전까지는 문자열 생성 부가 비용이 들지 않는다.**

위 코드의 `init` 을 아래와 같이 사용할 수도 있다.

```kotlin
init {
    require(monthNumber in 1..12)
}
```

```shell
Exception in thread "main" java.lang.IllegalArgumentException: Failed requirement.
```

---

## 2.2. `File`, `Paths`

아래 코드에서 _DataFile_ 객체는 파일을 _targetDir_ 하위 디렉터리에 저장한다.

```kotlin
import java.io.File
import java.nio.file.Paths

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
    println(DataFile("Test.txt").reset().toString())    // DataFiles/Test.txt
    println(Paths.get("DataFiles", "Test.txt").toString())  // DataFiles/Test.txt
}
```

`File` 클래스는 운영체제 수준의 파일을 조작하여 데이터를 읽고 쓴다.

`Paths` 클래스는 오버로드한 `get()` 만 제공한다.  
`get()` 은 String 을 여러 개 받아서 `Path` 객체를 만든다.  
`Path` 객체는 운영체제와 독립적으로 디렉터리 경로를 표현한다.

---

파일을 열 때는 파일 경로, 이름, 내용 등의 제약이 있을 수 있는데 
`require()` 를 사용하여 파일이름이 올바른지 검증하고, 파일 존재 여부와 파일이 비어있지는 않은지 여부를 검증할 수 있다.

```kotlin
fun getTrace(fileName: String): List<String> {
    // 파일명이 file_ 로 시작하는지 확인
    require(fileName.startsWith("file_")) {
        "$fileName must start with 'file_'"
    }

    // 파일이 존재하는지 확인
    val file = DataFile(fileName)
    require(file.exists()) {
        "$fileName doesn't exists"
    }

    // 파일이 비어있는지 확인
    val lines = file.readLines()
    require(lines.isNotEmpty()) {
        "$fileName is empty"
    }

    return lines
}

fun main() {
    DataFile("file_empty.txt").writeText("")
    DataFile("file_assu.txt").writeText("assu aa bb cc")

    // Exception in thread "main" java.lang.IllegalArgumentException: wrong_name.txt must start with 'file_'
    // val result1 = getTrace("wrong_name.txt")

    // Exception in thread "main" java.lang.IllegalArgumentException: file_nonexistence.txt doesn't exists
    // val result2 = getTrace("file_nonexistence.txt")

    // Exception in thread "main" java.lang.IllegalArgumentException: file_empty.txt is empty
    // val result3 = getTrace("file_empty.txt")
  
    val result4 = getTrace("file_assu.txt")
    println(result4) // [assu aa bb cc]
}
```

Exception 이 발생하기 때문에 result1~3 까지 주석을 해제하면 위의 주석과 같은 오류가 난다.

---

## 2.3. `requireNotNull()`

**`requireNotNull()` 은 첫 번째 인자가 null 인지 검사한 후 null 이 아니면 그 값을 돌려준다.**  
만일 **null 이면 _IllegalArgumentException_ 을 발생**시킨다.

**성공하면 `requireNotNull()` 의 인자는 자동으로 null 이 아닌 타입으로 스마트 캐스트**된다.  

**`requireNotNull()` 은 null 가능성만 검사하기 때문에 `require()` 와 달리 파라메터가 한 개 뿐인 버전이 더 유용**하다.

> 스마트 캐스트에 대한 좀 더 상세한 내용은 [2.1. 스마트 캐스트: `is`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#21-%EC%8A%A4%EB%A7%88%ED%8A%B8-%EC%BA%90%EC%8A%A4%ED%8A%B8-is) 를 참고하세요.

```kotlin
fun checkNotNull(n: Int?): Int {
    // null 일 경우 직접 리턴 메시지 조작 (파라메터가 2개)
    requireNotNull(n) {
        "checkNotNull() argument cannot be null~"
    }

    // requireNotNull() 호출이 n 을 null 이 될 수 업을 값으로 스마트캐스트 해주므로
    // n 에 대해 더 이상 null 검사를 할 필요가 없음
    return n * 9
}

fun main() {
    val n: Int? = null

    // Exception in thread "main" java.lang.IllegalArgumentException: checkNotNull() argument cannot be null~
    // val result1 = checkNotNull(n)

    // null 일 경우 디폴트 메시지 사용 (파라메터가 1개)
    // Exception in thread "main" java.lang.IllegalArgumentException: Required value was null.
    // val result2 = requireNotNull(n)

    val result3 = checkNotNull(1)
    println(result3)    // 9
}
```

---

## 2.4. `check()`

사후 조건은 함수의 결과를 검사한다.

**함수의 결과에 대한 제약 사항을 묘사하는 경우 이를 사후 조건으로 표현하는 것이 좋다.**

**`check()` 는 `require()` 와 동일하지만 _IllegalStateException_ 을 반환한다는 차이**가 있다.

**일반적으로 `check()` 를 함수의 맨 끝에 두어서 함수 결과 (또는 함수가 반환하는 객체의 필드) 가 올바른지 검증하기 위해 사용**한다.

아래는 파일에 데이터를 쓰는 함수에서 모든 실행 경로가 파일을 생성할 지 확신할 수 없다고 가정할 때 사후 조건으로 함수의 결과를 검증한다.

> _DataFile_ 은 [2.2. `File`, `Paths`](#22-file-paths) 에서 만들어놓은 클래스임

```kotlin
val resultFile = DataFile("result.txt")

fun createResultFile(create: Boolean) {
    if (create) {
        resultFile.writeText("result\n ok")
    }

    check(resultFile.exists()) {
        "$resultFile.name doesn't exist~"
    }
}

fun main() {
    resultFile.erase()

    // Exception in thread "main" java.lang.IllegalStateException: DataFiles/result.txt.name doesn't exist~
    // val result1 = createResultFile(false)

    // DataFiles/result.txt 가 생성됨
    createResultFile(true)
}
```

사전 조건이 제대로 들어왔음을 검증했을 때 사후 조건이 실패한다는 건 거의 로직의 실수가 있다는 의미이다.  
이런 이유로 로직이 올바르다고 확신하면 성능에 미치는 영향을 최소화하기 위해 사후 조건을 주석으로 처리하거나 제거하는 경우가 많은데 
미래에 코드를 변경하여 발생하는 문제를 감지할 수 있도록 그대로 두는 것이 좋다.

코드에 남겨두는 방법 중 하나는 사후 조건 검사를 단위 테스트로 옮기는 방법도 있다.

---

## 2.5. `assert()`

`check()` 문을 주석처리했다가 해제하는 수고를 덜기 위해 `assert()` 를 사용한다.  
`assert()` 의 경우 검사를 활성화하거나 비활성화할 수 있는데 기본적으로 비활성화 되어있기 때문에 명령줄 플래그로 명시적으로 활성화할 수 있다.
코틀린에서는 `-ea` 라는 플래그를 사용한다.

하지만 **특별한 설정이 없어도 항상 사용할 수 있는 `require()` 와 `check()` 를 사용하는 것이 좋다.**

---

# 3. `Nothing` 타입: `TODO()`

**`Nothing` 은 함수가 결코 반환되지 않는다는 사실을 표현하는 반환 타입**이다.

**항상 예외를 던지는 함수의 반환 타입이 `Nothing` 타입**이다. 

`Nothing` 은 아무 인스턴스도 없는 코틀린 내장 타입이다.

아래는 무한 루프를 발생시키는 함수이므로 결코 반환되지 않기 때문에 반환 타입이 `Nothing` 이다.
```kotlin
fun infinite(): Nothing {
    while (true) {
    }
}
```

실용적인 예시로는 **내장 함수인 `TODO()`** 가 있다.  
**`TODO()` 는 반환 타입이 `Nothing` 이고, 항상 _NotImplementedError_ 를 던진다.**

```kotlin
fun later(s: String): String = TODO("later()~")

fun later2(s: String): Int = TODO()

fun main() {
    // Exception in thread "main" kotlin.NotImplementedError: An operation is not implemented: later()~
    // later("hello")

    // Exception in thread "main" kotlin.NotImplementedError: An operation is not implemented.
    later2("hello")
}
```

`TODO()` 는 `Nothing` 타입을 반환하지만 위의 _later()_, _later2()_ 는 Nothing 이 나닌 String, Int 타입을 반환한다.  
**`Nothing` 은 모든 타입과 호환 가능**하다. 즉, `Nothing` 타입은 모든 다른 타입의 하위 타입으로 취급된다.

_later()_, _later2()_ 은 앞으로 함수를 구현해야 한다는 사실을 알려주는 예외를 발생시킨다.  

**`TODO()` 는 자세한 세부 사항을 채워넣기 전에 모든 것이 맞아떨어지는지 검증하기 위해 코드를 스케치할 때 유용**하다.

---

아래 코드에서 _fail()_ 은 상상 예외를 던지기 때문에 반환 타입이 `Nothing` 이다.  
_fail()_ 을 호출하는게 명시적으로 예외를 던지는 것보다 가독성이 좋고, 간결하다.

```kotlin
// 항상 예외를 던지므로 반환 타입이 Nothing
fun fail(i: Int): Nothing {
    throw Exception("fail $i")
}

fun main() {
    // Exception in thread "main" java.lang.Exception: fail 1
    fail(1)
}
```

**위와 같은 방법을 사용하면 오류 처리 시 유용**하다.  
예를 들어 **예외 타입을 변경하거나 예외를 던지기 전 로그를 남기는 등의 처리가 가능**하다.

---

아래는 인자가 String 이 아니면 예외를 던지는 예시이다.

```kotlin
class BadData(m: String) : Exception(m)

fun checkObject(obj: Any?): String =
    if (obj is String) {
        obj
    } else {
        throw BadData("Need String, got $obj")
    }

fun testObj(checkObj: (obj1: Any?) -> String) {
    println(checkObj("abc")) // abc

    // Exception in thread "main" assu.study.kotlinme.chap06.nothingType.BadData: Need String, got null
    // println(checkObj(null))

    // Exception in thread "main" assu.study.kotlinme.chap06.nothingType.BadData: Need String, got 111
    println(checkObj(111))
}

fun main() {
    testObj(::checkObject)
}
```

**코틀린은 `throw` 를 `Nothing` 타입으로 취급하고, `Nothing` 타입은 모든 타입의 하위 타입으로 취급**될 수 있다.

```kotlin
fun checkObject(obj: Any?): String =
    if (obj is String) {
        obj
    } else {
        throw BadData("Need String, got $obj")
    }
```

위에서 **if 문의 하나는 String 타입이고, else 문은 Nothing 타입이므로 String 으로도 취급**할 수 있다.  
**따라서 전체 if 식은 String 타입**이 된다.

---

위 코드에서 _checkObject()_ 를 [안전한 캐스트 `as?`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#232-%EC%95%88%EC%A0%84%ED%95%9C-%EC%BA%90%EC%8A%A4%ED%8A%B8-as)와 [엘비스 연산자 `?:`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#22-%EC%97%98%EB%B9%84%EC%8A%A4elvis-%EC%97%B0%EC%82%B0%EC%9E%90-)로 재작성할 수 있다.

```kotlin
class BadData2(m: String) : Exception(m)

fun failWithBadData(obj: Any?): Nothing = throw BadData2("Need String, got $obj")

// 인자를 String 으로 변환할 수 있으면 String 으로 변환한 값을 돌려주고, 아니면 예외 던짐
fun checkObject2(obj: Any?): String = (obj as? String) ?: failWithBadData(obj)

fun testObj2(checkObj: (obj1: Any?) -> String) {
    println(checkObj("abc")) // abc

    // Exception in thread "main" assu.study.kotlinme.chap06.nothingType.BadData2: Need String, got null
    // println(checkObj(null))

    // Exception in thread "main" assu.study.kotlinme.chap06.nothingType.BadData2: Need String, got 111
    println(checkObj(111))
}

fun main() {
    testObj2(::checkObject2)
}
```

---

**추가적인 타입 정보가 없는 상태로 그냥 null 이 주어지면 컴파일러가 null 이 될 수 있는 `Nothing` 타입으로 추론**한다.

```kotlin
fun main() {
    val none: Nothing? = null

    var nullableString: String? = null
    nullableString = "aaa"
    nullableString = none
    println(nullableString) // null

    val nullableInt: Int? = none
    println(nullableInt) // null

    // null 값만 있는 List 로 초기화
    val listNone: List<Nothing?> = listOf(null)
    val ints: List<Int?> = listOf(null)
    println(listNone)   // [null]
    println(ints)   // [null]
}
```

위 코드에서 _none_ 과 null 의 타입은 모두 _Nothing?_ (null 이 될 수 있는 Nothing) 이므로 둘 다 _nullableString_ 과 _nullableInt_ 에 대입 가능하다.


아래에서 _listNone_ 은 null 값만 들어있는 List 로 초기화됐다.  
컴파일러는 _listNone_ 의 타입이 List\<Nothing?\> 이라고 추론한다.  
따라서 **null 이 될 수 있는 타입이 원소인 리스트를 가리키는 변수를 null 만 들어있는 List 로 초기화하고 싶을 때에는 이런 식 (_List\<Nothing?\>_) 으로 원소의 타입을 명시**해야 한다. 

```kotlin
val listNone: List<Nothing?> = listOf(null)
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)