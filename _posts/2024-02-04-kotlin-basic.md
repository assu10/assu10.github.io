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
* [1. Hello, World](#1-hello-world)
* [2. `var`, `val`](#2-var-val)
* [3. 데이터 타입](#3-데이터-타입)
* [4. 함수](#4-함수)
* [5. if](#5-if)
* [6. 문자열 템플릿](#6-문자열-템플릿)
* [7. number 타입](#7-number-타입)
* [8. for, until, downTo, step, repeat](#8-for-until-downto-step-repeat)
* [9. `in` 키워드](#9-in-키워드)
* [10. 식(expression), 문(statement)](#10-식expression-문statement)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle

---

# 1. Hello, World

`fun` 은 function 의 줄임말이다.  

코틀린은 식 뒤에 세미콜론을 붙이지 않아도 된다.

```kotlin
package assu.study.kotlin_me.helloWorld

fun main() {
    println("Hello, world")
}
```

---

# 2. `var`, `val`

`var` 는 가변 변수이고, `val` 는 불변 변수이다.

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

---

# 3. 데이터 타입

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

# 4. 함수

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
fun multiple2(x: Int): Int = x*2

fun main() {
    val result2 = multiple2(5)
    println("result2: $result2")
}
```

---

# 5. if

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

# 6. 문자열 템플릿

```kotlin
fun main() {
    val a = 42
    println("Found $a")
    println("Fount $1")
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
println("""s = "$s"~""")
```

```shell
s = "my apple"~
s = "my apple"~
```

---

# 7. number 타입

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

# 8. for, until, downTo, step, repeat

1~3 까지 루프
```kotlin
// 1~3 까지 루프
for (i in 1..3) {
    println(i)
}
```

1~10 까지 루프 (10 포함)
```kotlin
val range1 = 1..10
println(range1) // 1..10
```
1~10 까지 루프 (10 미포함)
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

# 9. `in` 키워드

**`in` 키워드는 어떤 값이 주어진 범위 안에 들어있는지 검사하거나, 이터레이션** 을 한다.  
for 문 안에 있는 `in` 만 이터레이션을 뜻하고, 나머지 `in` 은 모두 원소인지 여부를 검사한다.



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

---

# 10. 식(expression), 문(statement)

식(expression) 은 값을 표현하고, 문(statement) 는 상태를 변경한다.  
따라서 statement 는 효과는 발생시키지만 결과를 내놓지는 않고, expression 은 항상 결과를 만들어낸다.

if 식도 식이기 때문에 결과를 만들어내고, 이 결과를 val, var 에 저장 가능하다.  
단, if 가 식으로 사용될 때는 반드시 else 가 있어야 한다.
```kotlin
val result = if (1 < 2) 'a' else 'b'
println(result) // a
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)