---
layout: post
title:  "Kotlin - 코틀린 기본"
date:   2024-02-04
categories: dev
tags: kotlin
---

이 포스트에서는 코틀린 기초에 대해 알아본다. 

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap01) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 코틀린](#1-코틀린)
  * [1.1. 코틀린 특성](#11-코틀린-특성)
    * [1.1.1. 정적 타입 지정 언어](#111-정적-타입-지정-언어)
    * [1.1.2. 함수형 프로그래밍](#112-함수형-프로그래밍)
  * [1.2. 코틀린 응용](#12-코틀린-응용)
  * [1.3. 코틀린 철학](#13-코틀린-철학)
    * [1.3.1. 간결성](#131-간결성)
    * [1.3.2. 안전성](#132-안전성)
    * [1.3.3. 상호운용성](#133-상호운용성)
* [2. Hello, World](#2-hello-world)
* [3. `var`, `val`](#3-var-val)
* [4. 데이터 타입](#4-데이터-타입)
* [5. 함수](#5-함수)
* [6. if](#6-if)
* [7. 문자열 템플릿](#7-문자열-템플릿)
* [8. number 타입](#8-number-타입)
* [9. `for`, `until`, `downTo`, `step`, `repeat`](#9-for-until-downto-step-repeat)
* [10. `in` 키워드](#10-in-키워드)
* [11. 식(expression), 문(statement)](#11-식expression-문statement)
* [Gradle 로 코틀린 빌드](#gradle-로-코틀린-빌드)
* [Java-Kotlin 변환](#java-kotlin-변환)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 코틀린

코틀린은 자바 플랫폼에서 돌아가는 새로운 프로그래밍 언어이다.

[http://try.kotl.in](http://try.kotl.in) 에 접속하면 코틀린 코드를 실행해볼 수 있다.

---

## 1.1. 코틀린 특성

---

### 1.1.1. 정적 타입 지정 언어

자바처럼 코틀린도 **정적 타입 지정 언어**이다.  

<**정적 타입과 동적 타입**>  
- 정적 타입
  - 모든 프로그램 구성 요소의 타입을 컴파일 시점에 알 수 있고, 프로그램 안에서 객체의 필드나 메서드를 사용할 때마다 컴파일러가 타입을 검증해 줌
- 동적 타입
  - JVM 에서 그루비나 JRuby 가 대표적인 동적 타입 지정 언어임
  - 메서드나 필드 접근에 대한 검증이 컴파일 시점이 아닌 실행 시점에 일어남
  - 따라서 코드가 더 짧아지고, 데이터 구조를 더 유연하게 사용 가능
  - 반대로 컴파일 시 오류를 잡아내지 못하여 실행 시점에 오류가 발생

자바와 달리 코틀린에서는 모든 변수의 타입을 직접 명시할 필요가 없다.  
대부분 코틀린의 컴파일러가 문맥으로부터 변수 타입을 자동으로 추론하는데 이를 **타입 추론**이라고 한다.

<**정적 타입 지정 언어의 장점**>  
- 성능
  - 실행 시점에 어떤 메서드를 호출할 지 알아내는 과정이 없으므로 메서드 호출이 더 빠름
- 신뢰성
  - 컴파일 시점에 오류가 검증되므로 실행 시 프로그램이 오류로 중단될 가능성이 더 적음
- 유지 보수성
  - 코드에서 다루는 객체가 어떤 타입에 속하는지 알 수 있기 때문에 처음 보는 코드도 쉽게 알 수 있음

코틀린의 중요한 특성들 중 하나는 **null 이 될 수 있는 타입을 지원**한다는 점이다.  
null 이 될 수 있는 타입을 지원함에 따라 컴파일 시점에 Null Pointer Exception 이 발생할 수 있는지 여부를 검사할 수 있어서 신뢰성을 높일 수 있다.  

> null 이 될 수 있는 타입 `?` 에 대한 좀 더 상세한 설명은 [1. null 이 될 수 있는 타입: `?`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#1-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%ED%83%80%EC%9E%85-) 을 참고하세요.

코틀린 타입 시스템에 있는 또 다른 새로운 내용은 **함수 타입에 대한 지원**이다.

> 함수 타입에 대한 좀 더 상세한 내용은 [1. 고차 함수 (high-order function)](https://assu10.github.io/dev/2024/02/17/kotlin-funtional-programming-2/#1-%EA%B3%A0%EC%B0%A8-%ED%95%A8%EC%88%98-high-order-function) 를 참고하세요.

---

### 1.1.2. 함수형 프로그래밍

<**함수형 프로그래밍의 핵심 개념**>  
- **일급 시민인 함수**
  - 함수를 일반 값처럼 변수에 저장할 수도 있고, 함수를 다른 함수의 인자로 전달할 수 있으며, 함수에서 새로운 함수를 만들어서 반환 가능
- **불변성 (immutable)**
  - 함수형 프로그래밍에서는 일단 만들어지고 나면 내부 상태가 절대로 바뀌지 않는 불변 객체를 사용
- **side-effect 없음**
  - 함수형 프로그래밍에서는 입력이 같으면 항상 같은 출력을 내놓음
  - 다른 객체의 상태를 변경하지 않음
  - 함수 외부나 다른 바깥 환경과 상호작용하지 않는 순수 함수 (pure function) 사용

> 순수 함수에 대한 좀 더 상세한 설명은 [3.1. 순수 함수](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/#31-%EC%88%9C%EC%88%98-%ED%95%A8%EC%88%98) 를 참고하세요.

<**함수형 프로그래밍의 장점**>  
- **간결성**
  - 순수 함수를 값처럼 활용할 수 있으면 강력한 추상화를 할 수 있고, 강력한 추상화를 통해 코드 중복ㅇㄹ 막을 수 있음
- **다중 스레드에 안전**
  - 불변 데이터 구졸ㄹ 사용하고, 순수 함수를 그 데이터 구조에 적용하면 다중 스레드 환경에서 같은 데이터를 여러 스레드가 변경할 수 없음
  - 따라서 복잡한 동기화를 적용하지 않아도 됨
- **쉬운 테스트**
  - side-effect 가 있는 함수를 그 함수를 실행할 때마다 전체 환경을 구성하는 준비 코드가 필요하지만 순수 함수는 그런 준비 코드없이 독립적으로 테스트 가능

<**코틀린이 지원하는 함수형 프로그래밍**>  
- 함수 타입을 지원하여 어떤 함수가 다른 함수를 파라메터로 받거나 함수가 새로운 함수 반환 가능
- 람다식을 지원하여 코드 블록을 쉽게 정의하고, 전달 가능
- 데이터 클래스는 불변적인 값 객체(Value Object) 를 간편하게 만들 수 있는 구문을 제공함
- 코틀린 표준 라이브러리는 객체와 컬렉션을 함수형 스타일로 다룰 수 있는 API 를 제공

---

## 1.2. 코틀린 응용

대부분의 코틀린 표준 라이브러리 함수는 인자로 받은 람다 함수를 인라이닝한다.

> `inline` 에 대한 좀 더 상세한 내용은 [2.5. 영역 함수의 인라인: inline](https://assu10.github.io/dev/2024/03/16/kotlin-advanced-1/#25-%EC%98%81%EC%97%AD-%ED%95%A8%EC%88%98%EC%9D%98-%EC%9D%B8%EB%9D%BC%EC%9D%B8-inline) 을 참고하세요.

따라서 람다를 사용해도 새로운 객체가 만들어지지 않으므로 객체 증가로 인한 가비지 컬렉션이 늘어나서 프로그램이 자주 멈추는 일이 없다.

---

## 1.3. 코틀린 철학

코틀린은 다른 프로그래밍 언어가 채택한 이미 성공적으로 검증된 해법과 기능에 의존한다.

---

### 1.3.1. 간결성

코틀린은 프로그래머가 작성하는 코드에서 의미없는 부분을 줄이고, 언어가 요구하는 구조를 만족시키기 위해 별 뜻은 없지만 프로그램에 꼭 넣어야 하는 부수적인 요소를 줄여준다.  
예를 들어 getter, setter 등 자바에 존재하는 여러 가지 번거로운 준비 코드를 코틀린은 묵시적으로 제공한다.

코틀린은 람다를 지원하기 때문에 읿안적인 기능을 라이브러리 안에 캡슐화하고, 작업에 따라 달라져야 하는 개별적인 내용을 사용자가 작성한 코드 안에 남겨둘 수 있다.

---

### 1.3.2. 안전성

코틀린을 JVM 에서 실행한다는 사실은 이미 상당한 안전성을 보장할 수 있다는 의미이다.

JVM 을 사용하면 메모리 안전성을 보장하고, 버퍼 오버플로를 방지하며, 동적으로 할당한 메모리를 잘못 사용함으로써 발생하는 다양한 문제를 예방할 수 있다.  
JVM 에서 실행되는 정적 타입 지정 언어로서 코틀린은 자바보다 더 적응 비용으로 애플리케이션의 타입 안전성을 보장한다.

코틀린의 **타입 시스템은 null 이 될 수 없는 값을 추적하여 실행 시점에 NPE 가 발생할 수 있는 연산을 사용하는 코드를 금지**시킨다.

```kotlin
val s: String? = null // null 이 될 수 있음
val s: String = ""  // null 이 될 수 없음
```

코틀린이 방지해주는 다른 예외로는 `ClassCastException` 이다.  
어떤 객체를 다른 타입으로 캐스트하기 전에 타입 검사를 하지 않으면 `ClassCastException` 이 발생할 수도 있는데 자바에서는 타입 검사와 타입 캐스트를 각각 해야한다.    
하지만 **코틀린은 타입 검사와 캐스트가 한 연산자에 의해 이루어진다.**

따라서 타입 검사를 생략할 이유도 없고, 검사를 생략함으로서 생기는 오류가 발생할 일도 없다.

 ```kotlin
if (value is String) {  // 타입 검사
    println(value.upperCase())  // 해당 타입의 메서드 사용
}
```

---

### 1.3.3. 상호운용성

코틀린은 자체 컬렉션 라이브러리를 제공하지 않고 자바 표준 라이브러리 클래스에 의존한다.  
다만, 코틀린에서 컬렉션을 더 쉽게 사용할 수 있는 몇 가지 기능을 더할 뿐이다.

> 이런 식으로 기존 라이브러리를 확장하는 방법에 대한 좀 더 상세한 내용은 [1. 확장 함수 (extension function)](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#1-%ED%99%95%EC%9E%A5-%ED%95%A8%EC%88%98-extension-function) 를 참고하세요.

---

# 2. Hello, World

`fun` 은 function 의 줄임말이다.  

코틀린은 식 뒤에 세미콜론을 붙이지 않아도 된다.

```kotlin
fun main() {
    println("Hello, world")
}
```

---

# 3. `var`, `val`

코틀린에서는 타입 지정을 생략하는 경우가 흔하다.

식이 본문인 함수처럼 변수 선언 시 타입을 지정하지 않으면 컴파일러가 초기화 식을 분석하여 변수 타입을 지정한다.

만일 초기화 식을 사용하지 않고 변수를 선언하려면 변수 타입을 반드시 명시해야 한다.

```kotlin
// 초기화 식에 의해 타입 추론됨
val str = "abc"

// 초기화 식이 없는 변수 선언 시 반드시 타입 명시
val str: String
str1 = "abc"
```

- `val`
  - 변경 불가능한 참조를 저장하는 변수
- `var`
  - 변경 가능한 참조


```kotlin
fun main() {
    // var 는 가변
    var tmp1 = 11
    var tmp2 = 1.4
    var tmp3 = "hello world"

    tmp1 += 2

    println(tmp1)
    println(tmp2)
    println(tmp3)

    // val 는 불변
    val tmp11 = 11
    val tmp22 = 1.4

    //tmp11 += 2  // 오류, Val cannot be reassigned
}
```

val 변수는 블록을 실행할 때 정확히 한 번만 초기화되어야 한다.  
하지만, 어떤 블록이 실행될 때 오직 한 번만 초기화 문장이 실행됨을 컴파일러가 확인할 수 있다면 조건에 따라 val 의 값을 여러 값으로 초기화 가능하다.

```kotlin
val message: String

// val 로 선언되었지만 초기화 문장이 오직 한 번만 실행됨
if (str.length > 1) {
    message = "aa"
} else {
    message = "bb"
}
```

**val 참조 자체는 불변이지만, 그 참조가 가리키는 객체의 내부 값은 변경**될 수 있다.

```kotlin
val lang = arrayListOf("Kotlin", "Java")    // 불변 참조 선언
lang.add("HTML")    // 참조가 가리키는 객체 내부 변경
```

> 변경 가능한 객체와 불변 객체에 대해서는 추후 좀 더 상세히 다룰 예정입니다. (p. 66)

만일, 어떤 타입의 변수에 다른 타입의 값을 저장하고 싶다면 변환 함수를 써서 값을 변수의 타입으로 변환하거나, 값을 변수에 대입할 수 있는 타입으로 
강제 형 변환을 해야 한다.

> 원시 타입의 변환에 대해서는 추후 좀 더 상세히 다룰 예정입니다. (p. 67)

---

# 4. 데이터 타입

`var 식별자: 타입 = 초기화`

타입을 적지 않아도 코틀린이 변수의 타입을 알아내서 대입하는데 이를 타입 추론이라고 한다.

```kotlin
var n: Int = 1
var p: Double = 1.2
```

코틀린의 기본 타입들 일부
```kotlin
fun main() {
    val tmp1: Int = 1
    val tmp2: Double = 1.1
    val tmp3: Boolean = true
    val tmp4: String = "hello world"
    val tmp5: Char = 'a'
    val tmp6: String = """aa
        bb
        cc
    """

    println(tmp1)
    println(tmp2)
    println(tmp3)
    println(tmp4)
    println(tmp5)
    println(tmp6)
}
```

```shell
1
1.1
true
hello world
a
aa
        bb
        cc
```

여러 줄의 문자열은 `"""` 로 감싸는데 이를 삼중 큰 따옴표 혹은 raw string 이라고 한다.

---

# 5. 함수

함수의 기본적인 형태
```kotlin
fun 함수 이름(p1: 타입1, p2: 타입2, ...): 반환 타입 {
    코드들
    return 결과
}
```

**파라메터는 전달할 정보를 넣을 장소**이고, **인자(argument) 는 파라메터를 통해 함수에 전달하는 실제 값**이다.

**함수 이름, 파라메터, 반환 타입을 합쳐서 함수 시그니처** 라고 한다.

```kotlin
fun multiple(x: Int): Int {
    println("multiple~")
    return x*2
}
fun main() {
    val result = multiple(5)
    println("result: $result")
}
```

```shell
multiple~
result: 10
```

의미있는 결과를 제공하지 않는 함수의 반환 타입은 `Unit` 이다. `Unit` 는 생략 가능하다.

```kotlin
fun meaningless() {
    println("meaningless~")
}

fun main() {
    meaningless()
}
```

함수 본문이 하나의 식으로만 이루어진 경우 아래처럼 함수를 짧게 작성할 수 있다.
```kotlin
fun 함수이름(p1: 타입1, p2: 타입2, ... ): 반환 타입 = 식
```

**함수 본문이 중괄호로 둘러싸여 있으면 블록 본문(block body)** 라고 하고, **등호 뒤에 식이 본문으로 지정되면 식 본문(expression body)** 라고 한다.

```kotlin
// 식 본문
fun multiple2(x: Int): Int = x*2

// 블록 본문
fun main() {
    val result2 = multiple2(5)
    println("result2: $result2")
}
```

코틀린에서는 식 본문이 더 자주 사용된다.  
식이 본문인 함수는 반환 타입을 생략해도 코틀린이 타입 추론을 해준다.

**단, 식이 본문인 함수의 반환 타입 생략이 가능**하다.

```kotlin
fun max(a: Int): Int = if (a > 0) a else 1

// 식이 본문인 함수에서는 반환 타입 생략 가능
fun max1(a: Int) = if (a > 0) a else 1
```

> intelliJ 에서 식 본문으로 전환(Convert to expression body) 와 블록 본문으로 전환(Convert to block body) 로 각각 변환 가능

---

# 6. if

코틀린은 if 가 값을 만들어내기 때문에 자바와 달리 3항 연산자가 없다.

```kotlin
fun trueOrFalse(exp: Boolean): String {
    if (exp)
        return "TRUE~"
    else
        return "FALSE~"
}

fun main() {
    val a = 1

    println(trueOrFalse(a < 3))
    println(trueOrFalse(a > 3))
}
```

하나의 식 본문인 경우 return 값 없이 아래와 같이 사용 가능하다.
```kotlin
fun trueOrFalse2(exp: Boolean): String =
    if (exp)
        "TRUE~"
    else
        "FALSE~"
```

---

# 7. 문자열 템플릿

아래 코드는 _a_ 라는 변수를 선언한 후 그 다음 줄에 있는 문자열 리터럴 안에서 _a_ 변수를 사용하는 예시이다.
```kotlin
fun main() {
    val a = 42
    println("Found $a") // Found 42
    println("Found \$a") // Found $a
    println("Fount $1") // Found $1
    //println("Fount $b")   // 오류
}
```

**`${}` 의 중괄호 안에 식을 넣으면 그 식을 평가하여 결과값을 String 으로 변환**한다.
```kotlin
val condition = true
println(
    "${if (condition) 'a' else 'b'}"
)   // a
val x = 11
println("$x + 4 = ${x+4}")  // 11 + 4 = 15
```

```shell
a
11 + 4 = 15
```

String 안에 큰 따옴표같은 특수 문자를 넣을 때는 역슬래시 혹은 큰따옴표 3개를 쓰는 String 리터럴을 이용해야 한다.
```kotlin
val s = "my apple"
println("s = \"$s\"~")  // s = "my apple"~
println("""s = "$s"~""")  // s = "my apple"~
```

```shell
s = "my apple"~
s = "my apple"~
```

만일, 문자열 템플릿 안에서 변수와 다른 문자가 바로 붙어있으면 컴파일 오류가 난다.  
이 때는 중괄호를 사용하여 변수명을 감싸면 된다.  
중괄호를 쓴 경우가 일괄 변환할 때 좀 더 편하고 가독성도 더 좋아지므로 문자열 템플릿 안에서 변수명만 사용하는 경우라도 _${name}_ 처럼 
중괄호로 변수명을 감싸는 습관을 들이는 것이 좋다.

```kotlin
val name = "assu"
println("Hello $name") // Hello assu
// println("Hello $name님") // 컴파일 오류
println("Hello ${name}님") // Hello assu님
```

중괄호로 둘러싼 식 안에서 큰 따옴표 사용도 가능하다.
```kotlin
// 중괄호로 둘러싼 식 안에서 큰 따옴표도 사용 가능
println("hello, ${if (str.length > 1) str else "hoho~"}")   // hello, abc
println("hello, ${if (str.length > 10) str else "hoho~"}")  // hello, hoho~
```

> 문자열에 대한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 69)

---

# 8. number 타입

overflow 현상
```kotlin
fun main() {
    val i: Int = Int.MAX_VALUE
    val l: Long = Long.MAX_VALUE
    val a: Int = 2_147_483_647  // 가독성을 위해
    
    println(i)  // 2147483647
    println(i + 1)  // -2147483648
    println(l + 1)  // -9223372036854775808
}
```

```kotlin
val aa = 1000   // Int
val bb = 1000L  // Long
val cc = 1000.0 // Double
```

---

# 9. `for`, `until`, `downTo`, `step`, `repeat`

코틀린의 for 는 아래와 같은 형식이다.
```kotlin
for (<아이템> in <원소들>) {
    // ...
}
```

1~3 까지 루프
```kotlin
// 1~3 까지 루프
for (i in 1..3) {
    println(i)
}
```

1~10 까지 루프 (10 포함): `..`
```kotlin
val range1 = 1..10
println(range1) // 1..10
```
1~10 까지 루프 (10 미포함): `until`
```kotlin
val range2 = 1..<10
val range3 = 1 until 10
println(range2) // 1..9
println(range3) // 1..9
```

until, downTo, step
```kotlin
fun showRange(r: IntProgression) {
    for (i in r) {
        print("$i ")
    }
    print(" // $r")
    println()
}

showRange(1..5)
showRange(0 until 5)
showRange(5 downTo 1)
showRange(0..9 step 2)
showRange(0 until 10 step 3)
showRange(9 downTo 2 step 3)
```

```shell
1 2 3 4 5  // 1..5
0 1 2 3 4  // 0..4
5 4 3 2 1  // 5 downTo 1 step 1
0 2 4 6 8  // 0..8 step 2
0 3 6 9  // 0..9 step 3
9 6 3  // 9 downTo 3 step 3
```

`IntProgression` 은 Int 범위를 포함하며, 코틀린이 기본 제공하는 타입이다.

문자열 이터레이션
```kotlin
for (c in 'a'..'z') {
    print(c)    // abcdefghijklmnopqrstuvwxyz
}
```

lastIndex
```kotlin
val str = "abc"
for (i in 0..str.lastIndex) {
    print(str[i] + 1)   // bcd
}
```

각 문자 이터레이션
```kotlin
for (ch in "Jnskhm  ") {
    print(ch + 1)   // Kotlin!!
}
```

repeat
```kotlin    
// repeat
repeat(3) {
    print("hello")  // hellohellohello
}
```

---

# 10. `in` 키워드

**`in` 키워드는 어떤 값이 주어진 범위 안에 들어있는지 검사하거나, 이터레이션** 을 한다.  
for 문 안에 있는 `in` 만 이터레이션을 뜻하고, 나머지 `in` 은 모두 원소인지 여부를 검사한다.  
반대로 `!in` 을 사용하면 어떤 값이 범위에 속하지 않는지 검사한다.

```kotlin
val a = 11
println(a in 1..10) // false
println(a in 1..12) // true
```

```kotlin
val b = 35

// 아래 2개는 같은 의미
println(0 <= b && b <= 100) // true
println(b in 0..100)    // true
```

이터레이션의 `in` 과 원소검사 `in`
```kotlin
val values = 1..3
for (v in values) {
    println("iteration $v")
}

val v = 2
if (v in values)
    println("$v is a member of $values")    // 2 is a member of 1..3
```

```shell
iteration 1
iteration 2
iteration 3
2 is a member of 1..3
```

`!in`
```kotlin
fun isDigit(ch: Char) = ch in '0'..'9'
fun notDigit(ch: Char) = ch !in '0'..'9'

println(isDigit('a'))   // false
println(isDigit('5'))   // true
println(notDigit('z'))  // true
```

```kotlin
fun recognize(c: Char) =
    when (c) {
        in '0'..'9' -> "Digit"
        in 'a'..'z', in 'A'..'Z' -> "Letter"    // 여러 조건의 범위 함께 사용
        else -> "Unknown"
    }

fun main() {
  println(recognize('8')) // Digit
  println(recognize('d')) // Letter
}
```

Comparable 을 사용하는 범위의 경우 그 범위 내의 모든 객체를 항상 이터레이션할 수는 없다.  
예를 들어 'java' 와 'kotlin' 사이의 문자열을 이터레이션 할 수는 없다.  
하지만 `in` 을 사용하여 값이 밤위 안에 들어가는지 결정은 할 수 있다.

```kotlin
// "java" <= "kotlin" && "kotlin" <= "scala" 와 동일
println("kotlin" in "java".."scala") // true
```

컬렉션에도 `in` 연산을 할 수 있다.
```kotlin
println("kotlin" in setOf("java", "scala")) // false
```

> 범위, 수열, 직접 만든 데이터 타입을 함께 사용하는 방법과 `in` 검사를 적용할 수 있는 객체에 대한 일반 규칙에 대해서는 추후 좀 더 상세히 다룰 예정입니다. (p. 95)

---

# 11. 식(expression), 문(statement)

**식(expression) 은 값을 표현**하고, **문(statement) 는 상태를 변경**한다.  
따라서 statement 는 효과는 발생시키지만 결과를 내놓지는 않고, expression 은 항상 결과를 만들어낸다.

**if 식도 식이기 때문에 결과를 만들어내고**, 이 결과를 val, var 에 저장 가능하다.  
단, if 가 식으로 사용될 때는 반드시 else 가 있어야 한다.
```kotlin
val result = if (1 < 2) 'a' else 'b'
println(result) // a
```

> 코틀린에서 if 는 식이지 문이 아님  
> 식은 값을 만들어내고, 문은 상태를 변경함  
> 
> 자바는 모든 제어 구조가 문인 반면에 코틀린은 루프를 제외한 대부분의 제어 구조가 식임

---

# Gradle 로 코틀린 빌드

코틀린 프로젝트를 빌드할 때는 Gradle 사용을 권장한다.  
Gradle 은 안드로이드 프로젝트의 표준 빌드 시스템이며, 코틀린을 사용할 수 있는 모든 유형의 프로젝트를 지원한다.

Gradle 은 코틀린으로 **Gradle 빌드 스크립트**를 작성하게 하는 작업을 진행중인데, 코틀린 스크립트를 사용할 수 있다면 애플리케이션을 작성하는 언어로 
빌드 스크립트도 작성한다는 장점이 있다.

Gradle 빌드 스크립트에 대한 좀 더 상세한 내용은 [Kotlin-Tools](https://kotlinlang.org/docs/get-started-with-jvm-gradle-project.html#specify-a-gradle-version-for-your-project) 에서 확인 가능하다.

다중 플랫폼 지원 Gradle 스크립트에 대한 좀 더 상세한 내용은 [Kotlin Multiplatform](https://kotlinlang.org/docs/multiplatform-get-started.html) 을 참고하세요.

코틀린 프로젝트를 JVM 을 타겟으로 빌드하는 표준 Gradle 빌드 스크립트는 아래와 같다.

```groovy
group "com.assu.study"
version "0.0.1-SNAPSHOT"

buildscript {
	ext.kotlin_version = "8.7"    // 사용할 코틀린 버전

	repositories {
		mavenCentral()
	}
	dependencies {
		// 코틀린 Gradle 플러그이니에 대한 빌드 스크립트 의존관계 추가
		classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
	}
}

// 코틀린 Gradle 플러그인 적용
apply plugin: 'kotlin'

repositories {
	mavenCentral()
}

dependencies {
	compile "org.jetbrains.kotlin:kotlin-stdlib-jre7:$kotlin_version"
	//compile "org.jetbrains.kotlin:kotlin-reflect:$kotlin_version"
	//compile "junit:junit:4.12"
}

//sourceSets {
//	main.kotlin.srcDirs += 'src'
//}
```

# Java-Kotlin 변환

java 를 kotlin 으로 변환하고 싶을 때는 java 코드를 복사하여 kotlin 파일에 붙여 넣으면 된다.

만일 java 파일 하나를 통채로 변환하고 싶다면 `[Code] > [Convert Java File to Kotlin File]` 을 선택하면 된다.

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
* [코틀린 코드 실행](http://try.kotl.in)
* [공식 코틀린 포럼](https://discuss.kotlinlang.org/)
* [페이스북 한국 코틀린 사용자 그룹](https://www.facebook.com/groups/kotlinkr)
* [Gradle-Kotlin](https://gradle.org/kotlin/)
* [코틀린 빌드 스크립트 공홈](https://kotlinlang.org/docs/get-started-with-jvm-gradle-project.html#specify-a-gradle-version-for-your-project)
* [코틀린 다중 플랫폼 지원 Gradle 스크립트 공홈](https://kotlinlang.org/docs/multiplatform-get-started.html)
