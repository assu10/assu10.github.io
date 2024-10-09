---
layout: post
title: "Kotlin - 'inline'"
date: 2024-03-16
categories: dev
tags: kotlin inline
---

이 포스트에서는 `inline` 에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `inline`: 람다의 부가 비용 없애기](#1-inline-람다의-부가-비용-없애기)
  * [1.1. 인라이닝이 동작하는 방식](#11-인라이닝이-동작하는-방식)
  * [1.2. 인라인 함수의 한계: `noinline`](#12-인라인-함수의-한계-noinline)
  * [1.3. 컬렉션 연산 인라이닝](#13-컬렉션-연산-인라이닝)
  * [1.4. 함수를 `inline` 으로 선언해야 하는 경우](#14-함수를-inline-으로-선언해야-하는-경우)
  * [1.5. 자원 관리를 위한 `inline` 된 람다 사용: `withLock()`, `use()`](#15-자원-관리를-위한-inline-된-람다-사용-withlock-use)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. `inline`: 람다의 부가 비용 없애기

람다가 변수를 포획하면 (closer) 람다가 생성되는 시점마다 새로운 무명 클래스가 생기기 때문에 실행 시점에 무명 클래스 생성에 따른 부가 비용이 든다는 점에 대해
[1.8. 클로저 (Closure)](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#18-%ED%81%B4%EB%A1%9C%EC%A0%80-closure) 에서 보았다.

이렇게 람다를 사용하게 되면 일반 함수를 사용하는 것보다 덜 효율적인데 이 때 `inline` 변경자를 사용하면 컴파일러는 그 함수를 호출하는 모든 문장을
함수 본문에 해당하는 바이트코드로 변경해주므로 반복되는 코드를 별도의 라이브러리 함수로 빼내되 컴파일러가 자바의 일반 함수처럼 효율적인 코드를 생성해주므로 람다를 효율적으로 사용할 수 있다.

람다를 인자로 전달하면 람다 코드를 외부 객체에 넣기 때문에 일반 함수 호출에 비해 실행 시점의 부가 비용이 좀 더 발생하지만, 람다가 주는 신뢰성과 코드 구조 개선에 비하면
이런 부가 비용은 크게 문제가 되지는 않는다.

**`inline` 함수는 이렇게 람다를 사용함에 따라 발생할 수 있는 성능상 부가 비용을 없애고** 람다 안에서 더 유연하게 흐름을 제어할 수 있도록 해준다.

**영역 함수를 `inline` 으로 만들면 모든 실행 시점의 부가 비용을 없앨 수 있다.**

**컴파일러는 `inline` 함수 호출을 보면 함수 호출 식을 함수의 본문으로 치환**하며, 이 때 함수의 모든 파라메터를 실제 제공된 인자로 바꿔준다.

**함수 실행 비용보다 함수 호출 비용이 큰, 작은 함수의 경우 `inline` 이 효과적**이다.

반면, **함수가 커질수록** 전체 호출을 실행하는데 걸리는 시간에서 함수 호출이 차지하는 비중이 줄어들기 때문에 **`inline` 의 가치가 하락**하고,
**함수가 크면 모든 함수 호출 지점에 함수 본문이 삽입되므로 컴파일된 전체 바이트 코드의 크기도 늘어난다.**

**인라인 함수가 람다를 인자로 받으면 컴파일러는 인라인 함수의 본문과 함께 람다 본문을 인라인**해준다.  
**따라서 인라인 함수에 람다를 전달하는 경우 클래스나 객체가 추가로 생기지 않는다.**

원하는 모든 함수에 `inline` 을 적용할 수 있지만, **일반적으로 `inline` 의 목적**은 아래와 같다.

- **함수 인자로 전달되는 람다를 인라이닝(예-영역 함수) 하거나 실체화한 제네릭스를 정의하는 것**

> 제네릭스 정의에 대한 내용은 좀 더 상세한 내용은 [Kotlin - 제네릭스 (타입 정보 보존, 제네릭 확장 함수, 타입 파라메터 제약, 타입 소거, 'reified', 타입 변성 애너테이션 ('in'/'out'), 공변과 무공변)](https://assu10.github.io/dev/2024/03/17/kotlin-advanced-2/) 을 참고하세요.


---

## 1.1. 인라이닝이 동작하는 방식

**어떤 함수를 `inline` 으로 선언하면 그 함수의 본문이 인라인**된다.  
즉, 함수를 호출하는 코드를 함수를 호출하는 바이트코드 대신에 함수 본문을 번역한 바이트코드로 컴파일한다는 의미이다.

여기서는 인라이닝을 한 코드가 어떻게 컴파일되는지에 대해 알아본다.

아래는 다중 스레드 환경에서 어떤 공유 자원에 대한 동시 접근을 막기 위한 것으로, _Lock_ 객체를 잠그고 주어진 코드 블록을 실행한 후 _Lock_ 객체에 대한 잠금을 해제하는 예시이다.

```kotlin
package com.assu.study.kotlin2me.chap08

import java.util.concurrent.locks.Lock

inline fun <T> customSynchronized(lock: Lock, action: () -> T): T {
    lock.lock()
    
    try {
        return action()
    } finally {
        lock.unlock()
    }
}

fun main() {
    val lock = Lock()
  customSynchronized(lock) {
        // ..
    }
}
```

위 코드는 단지 예시일 뿐이며 코틀린 표준 라이브러리는 아무 타입의 객체를 인자로 받을 수 있는 `synchronized()` 함수를 제공한다.

하지만 동기화에 명시적인 lock 을 사용하면 더 신뢰할 수 있고 관리하기 쉬운 코드를 만들 수 있다.

> 표준 코틀린 라이브러리가 제공하는 `withLock()` 함수에 대해서는 뒤에 나오는 [1.5. 자원 관리를 위한 `inline` 된 람다 사용: `withLock()`, `use()`](#15-자원-관리를-위한-inline-된-람다-사용-withlock-use) 를 참고하세요.

코틀린에서 lock 을 건 상태에서 코드를 실행해야 한다면 먼저 `withLock()` 을 써도 될 지 고려해보아야 한다.

위 코드의 _customSynchronized()_ 함수를 `inline` 으로 선언했으므로 이 함수를 호출하는 코드는 모두 자바의 `synchronized()` 문과 같아진다.

이제 위 함수를 사용하는 예시를 보자.

```kotlin
fun foo(lock: Lock) {
    println("Before sync")
    customSynchronized(lock) {
        println("Action")
    }
    println("After sync")
}
```

아래 코드는 위의 코드와 동등한 코드이다. (= 같은 바이트코드를 만들어 냄)

```kotlin
fun __foo__(lock: Lock) {
    println("Before sync")

    // customSynchronized() 가 인라이닝된 코드 시작
    lock.lock()
    try {
      // customSynchronized() 가 인라이닝된 코드 끝
        
      println("Action") // 람다의 코드 본문이 인라이닝된 코드

    // customSynchronized() 가 인라이닝된 코드 시작
    } finally {
      lock.unlock()
    }
    // customSynchronized() 가 인라이닝된 코드 끝
    
    println("After sync")
}
```

위 코드를 보면 **_customSynchronized()_ 함수의 본문 뿐 아니라 _customSynchronized()_ 에 전달된 람다의 본문도 함께 인라이닝**되고 있다.

람다의 본문에 의해 만들어지는 바이트코드는 그 람다를 호출하는 코드 (_customSynchronized()_) 정의의 일부분으로 간주되기 때문에 코틀린 컴파일러는 그 람다를
함수 인터페이스를 구현하는 무명 클래스로 감싸지 않는다.

인라인 함수를 호출하면서 람다를 넘기는 대신 함수 타입의 변수를 넘길수도 있다.

```kotlin
class LockOwner(val lock: Lock) {
    fun runUnderLock(body: () -> Unit) {
        // 람다 대신 함수 타입의 변수를 인자로 넘김
        customSynchronized(lock, body)
    }
}
```

위처럼 람다가 아닌 함수 타입의 변수를 넘기는 경우 인라인 함수를 호출하는 코드에서는 변수에 저장된 람다의 코드를 알 수 없으므로 람다 본문은 인라이닝되지 않고
_customSynchronized()_ 함수의 본문만 인라이닝된다.

따라서 람다는 다른 일반적인 경우와 마찬가지로 호출된다.

위 코드를 컴파일하면 아래와 같다.

```kotlin
class LockOwnerI(val lock: Lock) {
    fun __runUnderLock__(body: () -> Unit) {
      lock.lock()
      
      try {
          body()    // 람다의 본문은 인라이닝되지 않음
      } finally {
          lock.unlock()
      }
    }
}
```

하나의 인라인 함수를 2 곳에서 각각 다른 람다를 사용해 호출한다면 그 2 호출은 각각 따로 인라이닝된다.

인라인 함수의 본문 코드가 호출 지점에 복사되고, 각 람다의 본문이 인라인 함수의 본문 코드에서 람다를 사용하는 위치에 복사된다.

---

## 1.2. 인라인 함수의 한계: `noinline`

인라이닝을 하는 방식으로 인해 람다를 사용하는 모든 함수를 인라이닝할 수는 없다.

함수가 인라이닝될 때 그 함수에 인자로 전달된 람다식의 본문은 결과 코드에 직접 들어갈 수 있지만, 이렇게 람다가 본문에 직접 펼쳐지기 때문에 **함수가 파라메터로
전달받은 람다를 본문에 사용하는 방식이 한정**될 수밖에 없다.

함수 본문에서 파라메터로 받은 람다를 호출한다면 그 호출을 쉽게 람다 본문으로 바꿀 수 있겠지만 만일 **파라메터로 받은 람다를 다른 변수에 저장한 후 나중에 그 변수를 사용한다면
람다를 표현하는 객체가 어딘가는 존재해야 하기 때문에 람다를 인라이닝할 수 없다.**

인라인 함수의 본문의 본문에서 람다식을 바로 호출하거나 람다식을 인자로 받은 후 바로 호출하는 경우에 그 람다를 인라이닝할 수 있다.

그런 경우가 아니라면 컴파일러는 `Illegal usage of inline-parameter` 오류와 함께 인라이닝을 금지시킨다.

예를 들어 시퀀스에 대해 동작하는 메서드 중에는 람다를 받아서 모든 시퀀스 원소에 그 람다를 적용할 새로운 시퀀스를 반환하는 함수가 많은데 그런 함수는 인자로 받은
람다를 시퀀스 객체 생성자의 인자로 넘기곤 한다.

아래는 `Sequence.map` 을 정의하는 방식이다.

```kotlin
fun <T, R> Sequence<T>.map(transform: (T) -> R): Sequence<R> {
    return TransformingSequence(this, transform)
}
```

위의 map 함수는 _transform_ 파라메터로 전달받은 함수값을 호출하는 대신 `TransformingSequence` 클래스의 생성자에게 그 함수값을 넘기고, `TransformingSequence` 생성자는
전달받은 람다를 프로퍼티로 저장한다.

이런 기능을 지원하려면 map 에 전달되는 _transform_ 인자를 인라이닝하지 않은 일반적인 함수 표현으로 만들 수 밖에 없다.

즉, _transform_ 을 함수 인터페이스로 구현하는 무명 클래스 인스턴스로 만들어야만 한다.

---

둘 이상의 람다를 인자로 받는 함수에서 일부 람다만 인라이닝하고 싶을 때가 있다.

어떤 람다에 너무 많은 코드가 들어가거나, 인라이닝을 하면 안되는 코드가 들어갈 가능성이 있다면 그런 람다는 인라이닝을 하면 안된다.

이렇게 **인라이닝하면 안되는 람다를 파라메터로 받는다면 `noinline` 변경자를 파라메터 이름 앞에 붙여서 인라이닝을 금지**할 수 있다.

`noinline` 사용 예시

```kotlin
inline fun foo(inlined: () -> Unit, noinline notInlined: () -> Unit) {
    // ...
}
```

어떤 모듈이나 서드파티 라이브러리 안에서 인라인 함수를 정의한 후 그 모듈이나 서드파티 밖에서 해당 인라인 함수를 사용하는 경우가 있다.  
이런 경우 컴파일러는 인라인 함수를 인라이닝하지 않고 일반 함수 호출로 컴파일한다.

> 이 외 `noinline` 을 사용해야 하는 경우는 추후 다룰 예정입니다. (p. 369)

---

## 1.3. 컬렉션 연산 인라이닝

여기서는 컬렉션에 대해 작용하는 코틀린 표준 라이브러리 성능에 대해 알아본다.

코틀린 표준 라이브러리의 컬렉션 함수는 대부분 람다를 인자로 받는다.

아래는 람다를 사용하여 컬렉션을 필터링하는 경우와 람다를 사용하지 않고 직접 필터링을 하는 경우의 코드이다.

람다를 사용하여 컬렉션을 필터링하는 예시

```kotlin
package com.assu.study.kotlin2me.chap08

data class Person1(
    val name: String,
    val age: Int,
)

fun main() {
    val person1 = listOf(Person1("Assu", 20), Person1("Silby", 5))

    // 람다를 사용하여 컬렉션 필터링
    // [Person1(name=Silby, age=5)]
    println(person1.filter { it.age < 15 })
}
```

람다를 사용하지 않고 컬렉션을 필터링하는 예시

```kotlin
package com.assu.study.kotlin2me.chap08

data class Person1(
    val name: String,
    val age: Int,
)

fun main() {
    val person1 = listOf(Person1("Assu", 20), Person1("Silby", 5))

    // 람다를 사용하지 않고 컬렉션 필터링
    val result = mutableListOf<Person1>()
    for (person in person1) {
        if (person.age < 15) {
            result.add(person)
        }
    }
    // [Person1(name=Silby, age=5)]
    println(result)
}
```

`filter()` 는 인라인 함수이다.

따라서 `filter()` 함수의 바이트코드는 그 함수에 전달된 람다 본문의 바이트코드와 함께 `filter()` 를 호출한 위치에 들어간다.

결과적으로 위 2개의 바이트코드는 거의 같다.

그러므로 코틀린이 제공하는 함수 인라이닝을 빋고 성능에 신경쓰지 않아도 된다.

---

`filter()` 와 `map()` 을 연쇄해서 사용하는 경우를 보자.

```kotlin
println(person1.filter { it.age < 15 }.map(Person::name))
```

위의 식은 람다와 멤버 참조를 이용하고 있으며, `filter()` 와 `map()` 모두 인라인 함수이다.

다라서 두 함수의 본문은 인라이닝되며, 추가 객체나 클래스 생성은 없다.

하지만 이 코드는 리스트를 걸러낸 결과를 중간 저장하는 중간 리스트를 만든다.

처리할 원소가 많아지면 중간 리스트가 사용하는 부가 비용이 크기 때문에 [`asSequence`](https://assu10.github.io/dev/2024/02/23/kotlin-funtional-programming-3/#1-%EC%8B%9C%ED%80%80%EC%8A%A4-sequence-constrainonce) 를 통해 리스트 대신 시퀀스를 사용하여 중간 리스트로 인한 부가 비용을 줄일 수 있다.

이 때 각 중간 시퀀스는 람다를 필드에 저장하는 객체로 표현하며, 최종 연산은 중간 시퀀스에 있는 여러 람다를 연쇄 호출한다.  
**따라서 시퀀스는 람다를 저장해야 하므로 람다를 인라인하지 않는다.**

**그러므로 지연 계산을 통해 성능을 향상시키려는 목적으로 모든 컬렉션 연산에 `asSequence` 를 붙여서는 안된다.**

**시퀀스 연산에서는 람다가 인라이닝되지 않기 때문에 크기가 작은 컬렉션은 오히려 일반 컬렉션 연산이 더 좋은 성능을 보일 수 있다.**

**시퀀스를 통해 성능을 향상시킬 수 있는 경우는 컬렉션 크기가 큰 경우일 뿐이다.**

---

## 1.4. 함수를 `inline` 으로 선언해야 하는 경우

코드의 성능을 높이기 위해 여기저기에 `inline` 을 사용하는 것은 좋은 생각이 아니다.

**`inline` 키워드를 사용해도 람다를 인자로 받는 함수만 성능이 좋아질 가능성이 높다.**

인라인 함수가 아닌 일반 함수의 경우 JVM 은 이미 강력하게 인라이닝을 지원하고 있다.  
JVM 은 코드 실행을 분석해서 가장 이익이 되는 방향으로 호출을 인라이닝하며, 이런 과정은 바이트코드를 기계어코드로 번역하는 과정인 JIT 과정에서 일어난다.

이런 JVM 의 최적화를 활용한다면 바이트코드에서는 각 함수 구현이 정확히 한 번만 있으면 되고, 그 함수를 호출하는 부분에서 따로 함수 코드를 중복할 필요가 없다.

하지만 코틀린 인라인 함수는 바이트코드에 각 함수 호출 지점을 함수 본문으로 대치하기 때문에 코드 중복이 생기게 된다.

반면 **람다를 인자로 받는 함수를 인라이닝하면 이익**이 더 많다.

- 인라이닝을 통해 없앨 수 있는 부가 비용이 상당함
  - 함수 호출 비용을 줄일 수 있음
  - 람다를 표현하는 클래스와 람다 인스턴스에 해당하는 객체를 만들 필요가 없음
- 현재의 JVM 은 함수 호출과 람다를 인라이닝해주지 못함
- 인라이닝을 사용하면 일반 람다에서 사용할 수 없는 몇 가지 기능을 사용할 수 있음
  - > 그런 기능들 중 `non-local` 반환이 있는데 이는 추후 다룰 예정입니다. (p. 371)

`inline` 변경자를 함수에 붙일 때는 코드 크기에 주의해야 한다.

**인라이닝 함수가 큰 경우 함수의 본문에 해당하는 바이트코드를 모든 호출 지점에 복사하므로 바이트코드가 전체적으로 아주 커질 수 있다.**

---

## 1.5. 자원 관리를 위한 `inline` 된 람다 사용: `withLock()`, `use()`

람다로 중복을 없앨 수 있는 일반적인 패턴 중 하나는 어떤 작업을 하기 전에 자원을 획득하고, 작업을 마친 후 자원을 해제하는 자원 관리이다.

여기서 자원은 파일, lock, Transaction 등이 될 수 있다.

자원 관리 패턴을 만들 때 보통 사용하는 방법은 try/finally 문을 사용하여 try 블록을 시작하기 직전에 자원을 획득하고, finally 블록에서 자원을 해제하는 것이다.

[1.1. 인라이닝이 동작하는 방식](#11-인라이닝이-동작하는-방식) 에서 본 _customSynchronized()_ 가 그런 패턴이다.

_customSynchronized()_ 는 자바의 `synchronized` 문과 똑같은 구문을 제공한다.

```kotlin
inline fun <T> customSynchronized(lock: Lock, action: () -> T): T {
    lock.lock()
    
    try {
        return action()
    } finally {
        lock.unlock()
    }
}
```

코틀린 라이브러리에는 좀 더 코틀린다운 API 를 통해 같은 기능을 제공하는 `withLock()` 이라는 함수가 있다.

`withLock()` 함수는 `Lock` 인터페이스의 확장 함수이다.

아래는 `withLock()` 의 사용법이다.

```kotlin
val l: Lock = ...

// lock 을 잠근 후 주어진 동작 수행 
l.withLock {
    // lock 에 의해 보호되는 자원 사용
}
```

아래는 `withLock()` 의 시그니처이다.

```kotlin
// lock 을 획득한 후 작업하는 과정을 별도의 함수로 분리함
public inline fun <T> Lock.withLock(action: () -> T): T {
    contract { callsInPlace(action, InvocationKind.EXACTLY_ONCE) }
    lock()
    try {
        return action()
    } finally {
        unlock()
    }
}
```

---

이런 패턴을 사용할 수 있는 다른 유형의 자원으로 파일이 있다.

자바 7 부터 이를 위한 구문인 `try-with-resource` 문이 생겼다.

아래는 `try-with-resources` 를 사용하여 파일의 각 줄을 읽는 예시이다.

```java
static String readFirstLineFromFile(String path) throws IOException {
    try (BufferedReader br = new BufferedReader(new FileReader(path))) {
        return br.readLine();
    }
}
```

> `try-with-resources` 에 대한 내용은 [`try-with-resources` 개선](https://assu10.github.io/dev/2023/07/30/java-java-versions/#try-with-resources-%EA%B0%9C%EC%84%A0) 을 참고하세요.

자바의 `try-with-resources` 와 같은 기능을 제공하는 [`use()`](https://assu10.github.io/dev/2024/03/10/kotlin-error-handling-2/#1-%EC%9E%90%EC%9B%90-%ED%95%B4%EC%A0%9C-use) 라는 함수가 코틀린 표준 라이브러리 안에 들어있다.

위 코드를 `use()` 를 이용하여 작성하면 아래와 같다.

```kotlin
fun readFirstLineFromFile(path: String): String {
    // BufferedReader 객체를 만들고 use() 함수를 호출하면서 파일에 대한 연산을 실행할 람다를 넘김
    BufferedReader(FileReader(path)).use { br ->
        // 자원(파일)에서 맨 처음 가져온 한 줄을 람다가 아닌 readFirstLineFromFile 에서 반환함
        return br.readLine()
    }
}
```

`use()` 함수는 닫을 수 있는 (closable) 자원에 대한 확장 함수이며, 람다를 인자로 받는다.

`use()` 는 람다를 호출한 다음 람다의 정상 종료와 무관하게 자원을 확실히 닫아준다.

물론 `use()` 함수로 인라인 함수이다. 따라서 `use()` 를 사용해도 성능에 영향이 없다.

위 코드에서 람다의 본문 안에서 사용한 `return` 은 `non-local return` 이다.  
이 `return` 문은 람다가 아니라 _readFirstLineFromFile()_ 함수를 끝내면서 값을 반환한다.

> 람다 안에서 `return` 을 사용하는 방법에 대해서는 추후 다룰 예정입니다. (p. 374)

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