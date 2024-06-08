---
layout: post
title:  "Kotlin - 연산자 오버로딩, 'infix', 가변 컬렉션에 '+=', '+' 적용, Comparable, 구조 분해 연산자"
date:   2024-03-23
categories: dev
tags: kotlin infix equals() compareTo() rangeTo() contains() invoke() comparable
---

이 포스트에서는 연산자 오버로딩, `infix`, 연산자 사용, 구조 분해 연산자에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap07) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 연산자 오버로딩: `operator`](#1-연산자-오버로딩-operator)
  * [1.1. `infix`](#11-infix)
  * [1.2. 동등성 `==`, 비동등성 `!=`](#12-동등성--비동등성-)
    * [1.2.1. `equals()` 오버로딩](#121-equals-오버로딩-)
    * [1.2.2. null 이 될 수 있는 객체를 `==` 로 비교](#122-null-이-될-수-있는-객체를--로-비교)
  * [1.3. 산술 연산자](#13-산술-연산자)
    * [1.3.1. 파라메터 타입이 연산자가 확장하는 타입과 다른 타입인 경우](#131-파라메터-타입이-연산자가-확장하는-타입과-다른-타입인-경우)
  * [1.4. 비교 연산자: `compareTo()`](#14-비교-연산자-compareto)
  * [1.5. 범위와 컨테이너: `rangeTo()`, `contains()`](#15-범위와-컨테이너-rangeto-contains)
  * [1.6. 컨테이너 원소 접근: `get()`, `set()`](#16-컨테이너-원소-접근-get-set)
  * [1.7. 호출 연산자: `invoke()`](#17-호출-연산자-invoke)
    * [1.7.1. `invoke()` 를 확장 함수로 정의](#171-invoke-를-확장-함수로-정의)
  * [1.8. 역작은따옴표로 감싼 함수 이름](#18-역작은따옴표로-감싼-함수-이름)
* [2. 연산자 사용](#2-연산자-사용)
  * [2.1. 가변 컬렉션에 `+=`, `+` 적용](#21-가변-컬렉션에---적용)
  * [2.2. 불변 컬렉션에 `+=` 적용](#22-불변-컬렉션에--적용)
  * [2.3. `Comparable` 인터페이스 구현 후 `compareTo()` 오버라이드](#23-comparable-인터페이스-구현-후-compareto-오버라이드)
  * [2.4. 구조 분해 연산자](#24-구조-분해-연산자)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 연산자 오버로딩: `operator`

> 연산자를 오버로드하는 경우는 실전에서는 드문 케이스임  
> 연산자 오버로드를 보통 직접 라이브러리를 만들때만 사용함

초기 자바 설계자들은 연산자 오버로딩이 안좋다는 결론을 내려서 자바는 가비지 컬렉션을 제공하기 때문에 연산자 오버로딩 구현이 상대적으로 쉬움에도 불구하고 이를 허용하지 않았다.

코틀린은 연산자 오버로딩의 과정을 단순화함과 동시에, 익숙하거나 **오버로딩하는 것이 타당한 몇몇 연산자만 선택해서 오버로딩할 수 있도록 선택지를 제한**하였다.  
또한, **연산자의 우선순위 (예를 들면 덧셈보다 곱셈이 먼저임)도 바꿀 수 없도록 하였다.**  

> **가비지 컬렉션과 연산자 오버로딩의 관계 (중요하지는 않음)**  
> 
> 연산자 오버로딩은 C++ 에서 유명해졌는데 가비지 컬렉션이 없었던 C++ 은 오버로딩한 연산자를 작성하는 것이 어려웠음  
> C++ 에서는 객체가 힙에 할당될 수도 있고, 스택에 할당될 수도 있으므로 식에서 이런 객체들을 섞어서 사용하면 메모리를 낭비하는 경우가 생기기 쉬움  
> 따라서 가비지 컬렉션이 있으면 연산자 오버로딩 구현이 더 쉬워짐  
> 하지만 다른 일반적인 함수 구현도 가비지 컬렉션이 있으면 더 쉬워지기 때문에 가비지 컬렉션이 있다고 해서 연산자 오버로딩과 함수 호출의 상대적인 코딩 편의성이 달라지지는 않음
> 
> 자바가 연산자 오버로딩을 채택하지 않은 이유는 BigInteger, 행렬 등 수학적인 경우에 연산자 오버로딩이 쓸모가 많은데 
> 자바가 만들어진 당시에는 이런 수학 연산이 그다지 필요가 없었어서 연산자 오버로딩이 실제 필요한 경우가 아주 많지는 않았고,  
> C++ 에서 연산자 오버로딩을 남용하는 경우가 많았기 때문임

연산자를 오버로딩하려면 fun 앞에 `operator` 키워드를 붙여야 한다.  
그리고 함수 이름은 연산자에 따라 미리 정해진 특별한 이름만 사용 가능하다.  
예를 들어 `+` 연산자에 대한 특별 함수는 `plus()` 이다.

아래는 `+` 연산자 오버로딩의 예시이다.
```kotlin
data class Num(val n: Int)

// + 를 확장 함수로 추가
// + 연산자 오버로딩
operator fun Num.plus(rval: Num) = Num(n + rval.n)

fun main() {
    // 위의 연산자 오버로딩이 없으면 아래 수식은 오류남
    val result1 = Num(1) + Num(2)
    val result2 = Num(1).plus(Num(2))

    println(result1) // Num(n=3)
    println(result2) // Num(n=3)
}
```

위 코드에서 `+` 연산자 오버로딩이 정의되어 있지 않으면 _val result1 = Num(1) + Num(2)_ 수식도 성립하지 않는다.

두 피연산자 사이에서 사용하기 위해 연산자가 아닌 일반 함수를 정의하고 싶다면 `infix` 키워드를 사용하면 되지만, 
연산자들은 대부분 이미 `infix` 이므로 굳이 `infix` 를 붙이지 않아도 된다.

> `infix` 에 대한 좀 더 상세한 내용은 [1.1. `infix`](#11-infix) 를 참고하세요.

---

연산자를 확장 함수로 정의하면 클래스의 private 멤버를 볼 수 없지만, 멤버 함수로 정의하면 private 멤버에 접근 가능하다.

```kotlin
data class Num2(private val n: Int) {
    // 클래스의 멤버 함수로 연산자 오버로딩 사용
    operator fun plus(rval: Num2) = Num2(n + rval.n)
}

// 컴파일 오류
// Cannot access 'n': it is private in 'Num2'
// Num2 에서 n 이 private 이기 때문에 n 에 접근할 수 없다는 의미

// operator fun Num2.minus(rval: Num2) = Num2(n - rval.n)

fun main() {
    val result1 = Num2(1) + Num2(2)
    val result2 = Num2(1).plus(Num2(2))

    println(result1) // Num2(n=3)
    println(result2) // Num2(n=3)
}
```

상황에 따라서 연산자에 특별한 의미를 부여하면 좋은 경우가 있다.

아래는 _House_ 에 `+` 연산을 적용하여 다른 _House_ 를 덧붙이는 예시이다.  
_attached_ 는 _House_ 사이의 연결을 의미한다.

```kotlin
package assu.study.kotlinme.chap07.operatorOverloading

data class House(
    val id: Int = idCount++,
    var attached: House? = null,
) {
    // 동반 객체
    companion object {
        private var idCount = 0
    }

    // 연산자 오버로딩
    operator fun plus(other: House) {
        attached = other
    }
}

fun main() {
    val h1 = House()
    val h2 = House()

    // House 클래스에 plus() 연산자 오버로딩이 없으면 아래 수식은 오류남
    h1 + h2
    // h1.plus(h2)  // 위와 동일한 표현

    // Exception in thread "main" java.lang.StackOverflowError
    // h2 + h1

    println(h1) // House(id=0, attached=House(id=1, attached=null))
    println(h2) // House(id=1, attached=null)
}
```

> `companion object (동반 객체)` 에 대한 좀 더 상세한 설명은 [3. 동반 객체 (companion object)](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#3-%EB%8F%99%EB%B0%98-%EA%B0%9D%EC%B2%B4-companion-object) 를 참고하세요.

> null 이 될 수 있는 타입 `?` 에 대한 좀 더 상세한 내용은 [1. null 이 될 수 있는 타입: `?`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#1-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%ED%83%80%EC%9E%85-) 을 참고하세요.

하지만 위 예제는 완전하지는 않다.

_h2 + h1_ 을 한 후 _h1_ 이나 _h2_ 를 출력하면 stack overflow 가 발생한다.

---

## 1.1. `infix`

`infix` 는 중위 표기법이라고도 하는데 두 개의 객체 중간에 들어가게 되는 함수 형태를 `infix function` 이라고 한다.

중위 표기법을 사용하면 `a.함수(b)` 를 `a 함수 b` 로 사용할 수 있으며, `infix` 키워드를 붙인 함수만 중위 표기법을 사용하여 호출할 수 있다.  
인자가 하나뿐인 일반 메서드나 인자가 하나뿐인 확장 함수에 중위 호출을 사용할 수 있다.  
중위 호출시에는 수신 객체와 유일한 메서드 인자 사이에 메서드 이름을 넣는다.

`infix` 함수를 잘 사용하면 가독성을 크게 향상시킬 수 있다.

예를 들어 아래 코드를 보자.
```kotlin
//  일반적인 표현
val result1 = mapOf(Pair("Monday", "월요일"), Pair("Tuesday", "화요일"))

// 중위 표기법
val result2 = mapOf("Monday" to "월요일", "Tuesday" to "화요일")
```

위에서 `to` 는 코틀린 키워드가 아니라 중위 호출이라는 특별한 방식으로 `to` 라는 일반 메서드를 홏ㄹ한 것이다. (= `infix`)

`infix` 함수는 아래와 같은 형태를 유지하여 직접 정의할 수도 있다.

```kotlin
infix fun dispatcher.함수명(receiver): 리턴타입 { }
```

위 코드에서는 _Monday_ 가 dispatcher 이고, _월요일_ 이 receiver 이다.

예를 들어 `add` 라는 infix 함수는 아래와 같이 만들 수 있다.  
String 에 확장함수 형태로 달아주며, 결과적으로 왼쪽과 오른쪽 String 을 하나로 합쳐주는 기능이다.

```kotlin
infix fun String.add(other: String): String {
    return this + other // this 가 dispatcher
}

fun main() {
    println("월요일" add "휴...")
}
```

---

## 1.2. 동등성 `==`, 비동등성 `!=`

`==` 과 `!=` 은 `equals()` 멤버 함수를 호출한다.

data 클래스는 자동으로 저장된 모든 필드를 서로 비교하는 `equals()` 를 오버라이드해주지만, 일반 클래스에서는 `equals()` 를 오버라이드하지 않으면 
클래스 내용이 아닌 참조를 비교하는 디폴트 버전이 실행된다.

```kotlin
class A(val i: Int)

data class B(val i: Int)

fun main() {
    // 일반 클래스
    val a1 = A(1)
    val a2 = A(1)
    val c = a1

    // a1 과 a2 는 메모리에서 다른 객체를 가리키므로 두 참조는 다름 (false)
    println(a1 == a2) // false

    // a1 과 c 는 메모리에서 같은 객체를 가리키므로 두 참조는 같음 (true)
    println(a1 == c) // true

    // data 클래스
    val b1 = B(1)
    val b2 = B(1)
    val d = b1

    // data 클래스는 자동으로 내용을 비교해주는 equals() 를 오버라이드 하므로 true 리턴
    println(b1 == b2) // true
    println(b1 == d) // true
}
```

> data 클래스에 대한 좀 더 상세한 내용은 [6. data 클래스](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#6-data-%ED%81%B4%EB%9E%98%EC%8A%A4) 를 참고하세요.

---

### 1.2.1. `equals()` 오버로딩 

**`equlas()` 는 확장 함수로 정의할 수 없는 유일한 연산자**이다.

**`equals()` 는 반드시 멤버 함수로 오버라이드** 되어야 하며, 정의할 때는 디폴트 `equals(other: Any?)` 를 오버라이드 한다.  
여기서 _other_ 의 타입은 개발자가 정의한 클래스의 구체적인 타입이 아니라 _Any?_ 이므로, **`equals()` 를 오버라이드할 때는 반드시 비교 대상 타입을 선택**해야 한다.


아래는 `equals()` 를 오버라이드하는 예시이다.
```kotlin
class E(var v: Int) {
    override fun equals(other: Any?): Boolean =
        when {
            // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
            this === other -> true
            // other 의 타입이 현재 클래스 타입과 같은지 검사
            other !is E -> false
            // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
            else -> v == other.v
        }

    // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
    override fun hashCode(): Int = v

    override fun toString(): String = "E($v)"
}

fun main() {
    val a1 = E(1)
    val a2 = E(2)
    val a3 = E(2)

    println(a1 == a2) // false, a1.equals(a2)
    println(a1 != a2) // true, !a1.equals(a2)
    println(a2 == a3) // true
    println(a2 != a3) // false

    // 참조 동등성
    println(a1 === a2) // false
    println(a2 === a3) // false
    println(a2 !== a3) // true
    println(E(1) === E(1)) // false
}
```

**`equals()` 를 오버라이드할 때는 항상 `hashCode()` 도 오버라이드**해야 한다.  
기본적인 규칙은 두 객체가 같다면 두 객체의 `hashCode()` 도 같은 값을 반환해야 한다.    
**만일 이 규칙을 지키지 않으면 Map 이나 Set 같은 표준 데이터 구조가 정상적으로 동작하지 않는다.**

`open` 클래스의 경우 모든 파생 클래스를 감안해야 하기 때문에 `equals()` 나 `hashCode()` 오버라이드가 더 복잡해진다.  
data 클래스가 자동으로 `equals()` 와 `hashCode()` 를 만들어주는 이유도 이런 복잡도 때문이다.

만일 직접 `equals()` 와 `hashCode()` 를 구현해야 한다면 intelliJ 가 자동으로 만들어주도록 하여 구현하는 것을 권장한다.

아래는 intelliJ 가 자동으로 생성해주는 `equals()` 와 `hashCode()` 구현이다.

`cmd + n` 에서 `equals() and hashCode()` 선택
```kotlin
// 인텔리제이에서 자동으로 생성해주는 equals() 와 hashCode()
class T(var d: Int) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as T

        return d == other.d
    }

    override fun hashCode(): Int {
        return d
    }
}
```

---

### 1.2.2. null 이 될 수 있는 객체를 `==` 로 비교

null 이 될 수 있는 객체를 `==` 로 비교하면 코틀린은 null 검사를 강제하는데 이 경우 엘비스 연산자 `?:` 를 통하여 null 을 검사할 수 있다.

```kotlin
class F(var v: Int) {
    override fun equals(other: Any?): Boolean =
        when {
            // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
            this === other -> true
            // other 의 타입이 현재 클래스 타입과 같은지 검사
            other !is E -> false
            // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
            else -> v == other.v
        }

    // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
    override fun hashCode(): Int = v

    override fun toString(): String = "F($v)"
}

// null 이 될 수 있는 객체를 if 문으로 검사
fun equalsWithIf(
    a: F?,
    b: F?,
) = if (a === null) {
    b === null
} else {
    a == b
}

// null 이 될 수 있는 객체를 엘비스 연산자로 검사
fun equalsWithElvis(
    a: F?,
    b: F?,
): Boolean = a?.equals(b) ?: (b === null)

fun main() {
    val a: F? = null
    val b = F(0)
    val c: F? = null

    val result1 = a == b
    val result2 = a == c

    val result3 = equalsWithIf(a, b)
    val result4 = equalsWithIf(a, c)

    val result5 = equalsWithElvis(a, b)
    val result6 = equalsWithElvis(a, c)

    println(result1) // false
    println(result2) // true
    println(result3) // false
    println(result4) // true
    println(result5) // false
    println(result6) // true
}
```

> 엘비스 연산자 `?:` 에 대한 좀 더 상세한 내용은 [2.2. 엘비스(Elvis) 연산자: `?:`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#22-%EC%97%98%EB%B9%84%EC%8A%A4elvis-%EC%97%B0%EC%82%B0%EC%9E%90-) 를 참고하세요.

> 안전한 호출 `?.` 에 대하나 좀 더 상세한 내용은 [2.1. 안전한 호출 (safe call): `?.`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#21-%EC%95%88%EC%A0%84%ED%95%9C-%ED%98%B8%EC%B6%9C-safe-call-) 을 참고하세요.

> null 이 될 수 있는 타입 `?` 에 대한 좀 더 상세한 내용은 [1. null 이 될 수 있는 타입: `?`](https://assu10.github.io/dev/2024/02/11/kotlin-function-2/#1-null-%EC%9D%B4-%EB%90%A0-%EC%88%98-%EC%9E%88%EB%8A%94-%ED%83%80%EC%9E%85-) 을 참고하세요.

---

## 1.3. 산술 연산자

**기본 산술 연산자를 확장으로 정의**할 수 있다.

일단 아래 기본적인 내용을 숙지하자.
```kotlin
var g1 = 1
var g2 = 1
var g3 = 1

println(g1++) // 1
println(++g2) // 2
println(+g3) // 1

println(g1) // 2
println(g2) // 2
println(g3) // 1
```

- **단항 연산자**
  - `unaryPlus()`
  - `unaryMinus()`
  - `not()`
- **증가/감소 연산자**
  - `inc()`: var 에서만 가능
  - `dec()`: var 에서만 가능
- **2항 연산자**
  - `plus()`
  - `minus()`
  - `times()`
  - `div()`
  - `rem()`
- **복합 대입 연산자**
  - `plusAssign()`
  - `minusAssign()`
  - `timesAssign()`
  - `divAssign()`
  - `remAssign()`

```kotlin
class G(var v: Int) {
  override fun equals(other: Any?): Boolean =
    when {
      // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
      this === other -> true
      // other 의 타입이 현재 클래스 타입과 같은지 검사
      other !is E -> false
      // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
      else -> v == other.v
    }

  // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
  override fun hashCode(): Int = v

  override fun toString(): String = "G($v)"
}

// 단항 연산자
operator fun G.unaryPlus() = G(v)

operator fun G.unaryMinus() = G(-v)

operator fun G.not() = this

// 증가/감소 연산자
operator fun G.inc() = G(v + 1)

operator fun G.dec() = G(v - 1)

fun unary(a: G) {
  // 위의 산술 연산자 오버로딩이 없으면 아래 수식들은 모두 오류남
  +a // unaryPlus()
  -a // unaryMinus()
  !a // not()

  var b = a
  b++ // inc() (var 에서만 가능)
  b-- // dec() (var 에서만 가능)
}

// 2항 연산자
operator fun G.plus(g: G) = G(v + g.v)

operator fun G.minus(g: G) = G(v - g.v)

operator fun G.times(g: G) = G(v * g.v)

operator fun G.div(g: G) = G(v / g.v)

operator fun G.rem(g: G) = G(v % g.v)

fun binary(
  a: G,
  b: G,
) {
  // 위의 산술 연산자 오버로딩이 없으면 아래 수식들은 모두 오류남
  a + b // a.plus(b)
  a - b // a.minus(b)
  a * b // a.times(b)
  a / b // a.div(b)
  a % b // a.rem(b)
}

// 복합 대입 연산자
operator fun G.plusAssign(g: G) {
  v += g.v
}

operator fun G.minusAssign(g: G) {
  v -= g.v
}

operator fun G.timesAssign(g: G) {
  v *= g.v
}

operator fun G.divAssign(g: G) {
  v /= g.v
}

operator fun G.remAssign(g: G) {
  v %= g.v
}

fun assignment(
  a: G,
  b: G,
) {
  a += b // a.plusAssign(b)
  a -= b // a.minusAssign(b)
  a *= b // a.timesAssign(b)
  a /= b // a.divAssign(b)
  a %= b // a.remAssign(b)
}

fun main() {
  val two = G(2)
  val three = G(3)
  println(two + three) // G(5)
  println(two.plus(three)) // G(5)
  println(two * three) // G(6)

  val t = true
  println(!t) // false

  val thirteen = G(13)
  println(thirteen / three) // G(4)
  println(thirteen % three) // G(1)

  val one = G(1)
  one += (three * three)
  println(one) // G(10)

  var four = G(4)
  // var 로 되어 있는 경우 컴파일 오류
  // Assignment operators ambiguity. All these functions match.
  // four += (three * three)
}
```

위에서 아래 코드는 오류가 난다.
```kotlin
var four = G(4)
four += (three * three)
```

```shell
Assignment operators ambiguity. All these functions match.
public operator fun G.plus(g: G): G defined in assu.study.kotlinme.chap07.operatorOverloading in file ArithmeticOperators.kt
public operator fun G.plusAssign(g: G): Unit defined in assu.study.kotlinme.chap07.operatorOverloading in file ArithmeticOperators.kt
```

_four_ 가 var 로 정의되어 있는 경우 _four = four.plus(g)_ 로 해석할 수도 있고, _four = four.plusAssign(g)_ 로 해석할 수도 있기 때문에 
두 경우를 모두 적용할 수 있는 상황이라면 컴파일러는 두 연산자 중 어느 쪽을 선택할 지 모른다는 오류를 발생시킨다.

---

### 1.3.1. 파라메터 타입이 연산자가 확장하는 타입과 다른 타입인 경우

파라메터 타입이 연산자가 확장하는 타입과 다른 타입이면 아래처럼 확장 함수를 정의하면 된다.
```kotlin
class H(var v: Int) {
    override fun equals(other: Any?): Boolean =
        when {
            // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
            this === other -> true
            // other 의 타입이 현재 클래스 타입과 같은지 검사
            other !is E -> false
            // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
            else -> v == other.v
        }

    // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
    override fun hashCode(): Int = v

    override fun toString(): String = "H($v)"
}

// 산술 연산자 확장 함수
operator fun H.plus(i: Int) = H(v + i)

fun main() {
    println(H(1) + 10) // H(11)
}
```

---

## 1.4. 비교 연산자: `compareTo()`

> 제어할 수 없는 클래스를 써야 하는 경우에만 `compareTo()` 를 확장 함수로 정의하고, 그 외엔 `Comparable` 인터페이스를 구현하는 것이 좋음
> 
> [2.3. `Comparable` 인터페이스 구현 후 `compareTo()` 오버라이드](#23-comparable-인터페이스-구현-후-compareto-오버라이드) 를 참고하세요. 

`compareTo()` 를 정의하면 모든 비교 연산자인 `<`, `>`, `<=`, `>=` 를 사용할 수 있다.

`compareTo()` 는 아래의 Int 를 반환해야 한다.
- 두 피연산자가 동등하면 0 반환
- 첫 번째 피연산자(수신 객체)가 두 번째 피연산자(함수의 인자) 보다 크면 양수 반환
- 이와 반대면 음수 반환


```kotlin
class I(var v: Int) {
    override fun equals(other: Any?): Boolean =
        when {
            // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
            this === other -> true
            // other 의 타입이 현재 클래스 타입과 같은지 검사
            other !is E -> false
            // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
            else -> v == other.v
        }

    // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
    override fun hashCode(): Int = v

    override fun toString(): String = "I($v)"
}

operator fun I.compareTo(i: I): Int = v.compareTo(i.v)

fun main() {
    val a = I(2)
    val b = I(3)
    val c = I(3)

    val result1 = a < b // a.compareTo(b) < 0
    val result2 = a > b // a.compareTo(b) > 0
    val result3 = a <= b // a.compareTo(b) <= 0
    val result4 = a >= b // a.compareTo(b) >= 0

    val result5 = (b == c) // b.compareTo(c) == 0

    println(result1) // true
    println(result2) // false
    println(result3) // true
    println(result4) // false

    println(result5) // false
    println(b.compareTo(I(3))) // 0
}
```

---

## 1.5. 범위와 컨테이너: `rangeTo()`, `contains()`

**`rangeTo()` 는 범위를 생성하는 `..` 연산자를 오버로드**하고, **`contains()` 는 값이 범위 안에 들어가는지 여부를 알려주는 `in` 연산자를 오버로드**한다.

> `in` 키워드에 대한 좀 더 상세한 설명은 [9. `in` 키워드](https://assu10.github.io/dev/2024/02/04/kotlin-basic/#9-in-%ED%82%A4%EC%9B%8C%EB%93%9C) 를 참고하세요.

```kotlin
class J(var v: Int) {
  override fun equals(other: Any?): Boolean =
    when {
      // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
      this === other -> true
      // other 의 타입이 현재 클래스 타입과 같은지 검사
      other !is E -> false
      // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
      else -> v == other.v
    }

  // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
  override fun hashCode(): Int = v

  override fun toString(): String = "J($v)"
}

data class R(val r: IntRange) {
  override fun toString() = "R($r)"
}

operator fun J.rangeTo(j: J) = R(v..j.v) // R(v <= .. <= j.v)

operator fun R.contains(j: J): Boolean = j.v in r

fun main() {
  val a = J(2)
  val b = J(3)
  val r = a..b // a.rangeTo(b)

  val result1 = a in r // r.contains(a)
  val result2 = a !in r // !r.contains(a)

  println(r) // R(2..3)
  println(result1) // true
  println(result2) // false
}
```

---

## 1.6. 컨테이너 원소 접근: `get()`, `set()`

**`get()`, `set()` 는 각괄호인 `[]` 을 사용하여 컨테이너의 원소를 읽고 쓰는 연산을 정의**한다.

```kotlin
class K(var v: Int) {
    override fun equals(other: Any?): Boolean =
        when {
            // === 는 참조 동등성 검사로, 메모리상에서 other 가 this 랑 같은 객체를 가리키는지 검사
            this === other -> true
            // other 의 타입이 현재 클래스 타입과 같은지 검사
            other !is E -> false
            // 저장된 데이터를 비교하는 검사, 이 시점에서 컴파일러는 other 의 타입이 E 라는 사실을 알기 때문에 별도의 타입 변환없이 other.v 사용 가능
            else -> v == other.v
        }

    // equals() 를 오버라이드할 때는 항상 hashCode() 도 오버라이드해야함
    override fun hashCode(): Int = v

    override fun toString(): String = "K($v)"
}

data class C(val c: MutableList<Int>) {
    override fun toString() = "C($c)"
}

operator fun C.contains(k: K) = k.v in c

operator fun C.get(i: Int): K = K(c[i])

operator fun C.set(
    i: Int,
    k: K,
) {
    c[i] = k.v
}

fun main() {
    val c = C(mutableListOf(2, 3))

    val result1 = (K(2) in c) // c.contains(K(2))
    val result2 = (K(4) in c) // c.contains(K(4))
    val result3 = c[1] // c.get(1)

    println(result1) // true
    println(result2) // false
    println(result3) // K(3)
    println(c.get(1)) // K(3)
    println(c) // C([2, 3])

    c[1] = K(4) // c.set(1, K(4))
    println(c) // C([2, 4])

    c.set(1, K(5))
    println(c) // C([2, 5])
}
```

---

## 1.7. 호출 연산자: `invoke()`

객체 참조 뒤에 괄호를 넣으면 `invoke()` 가 호출되기 때문에 **`invoke()` 연산자는 객체가 함수처럼 동작**하게 만든다.  
**`invoke()` 가 받을 수 있는 파라메터 개수는 원하는 대로 지정 가능**하다.

**`invoke()` 를 직접 정의하는 가장 흔한 경우는 DSL 을 만드는 경우**이다.

```kotlin
class Func {
    operator fun invoke() = "invoke()~"

    operator fun invoke(i: Int) = "invoke($i)~"

    operator fun invoke(
        i: Int,
        s: String,
    ) = "invoke($i, $s)~"

    operator fun invoke(
        i: Int,
        s: String,
        d: Double,
    ) = "invoke($i, $s, $d)~"

    // 가변 인자 목록 사용
    operator fun invoke(
        i: Int,
        vararg v: String,
    ) = "invoke($i, ${v.map { it }})~"
}

fun main() {
    val f = Func()

    val result1 = f()
    val result2 = f(1)
    val result3 = f(1, "a")
    val result4 = f(1, "a", 2.2)
    val result5 = f(1, "a", "b", "c")

    println(result1)    // invoke()~
    println(result2)    // invoke(1)~
    println(result3)    // invoke(1, a)~
    println(result4)    // invoke(1, a, 2.2)~
    println(result5)    // invoke(1, [a, b, c])~
}
```

> 가변 인자 목록 `vararg` 에 대한 좀 더 상세한 내용은 [4. 가변 인자 목록: `vararg`](https://assu10.github.io/dev/2024/02/09/kotlin-object/#4-%EA%B0%80%EB%B3%80-%EC%9D%B8%EC%9E%90-%EB%AA%A9%EB%A1%9D-vararg) 을 참고하세요.

---

### 1.7.1. `invoke()` 를 확장 함수로 정의

아래는 함수를 파라메터로 받아서 그 함수에 현재의 String 을 넘기는 String 의 확장 함수이다.

```kotlin
// 함수를 파라메터로 받아서 그 함수에 현재의 String 을 넘기는 확장 함수
operator fun String.invoke(f: (s: String) -> String) = f(this)

fun main() {
    // 이 람다는 invoke() 의 마지막 인자이기 때문에 괄호를 사용하지 않고 호출 가능
    val result = "aaa" { it.uppercase() }

    println(result) // AAA
}
```

함수 참조가 있는 경우엔 이 함수 참조를 `invoke()` 를 사용하여 호출할 수도 있고, 괄호를 사용하여 호출할 수도 있다.

```kotlin
fun main() {
    val func: (String) -> Int = { it.length }

    val result1 = func("abc")
    val result2 = func.invoke("abc")

    println(result1) // 3
    println(result2) // 3

    val nullableFunc: ((String) -> Int)? = null

    var result3 = 0
    if (nullableFunc != null) {
        result3 = nullableFunc("abc")
    }

    val result4 = nullableFunc?.invoke("abc")

    println(result3) // 0
    println(result4) // null
}
```

---

## 1.8. 역작은따옴표로 감싼 함수 이름

코틀린은 함수 이름을 역작은따옴표로 감싸는 경우 함수 이름에 공백, 몇몇 비표준 글자, 예약어 등을 허용한다.

단위 테스트 시 읽기 쉬운 테스트 함수를 정의할 때 유용하다.

```kotlin
fun `A long name with spaces`() = println("111")

fun `*how* is func`() = println("222")

fun `'when' is hohoho`() = println("333")

//fun `Illigal characters: <>`() = println("444")

fun main() {
    `A long name with spaces`() // 111
    `*how* is func`() // 222
    `'when' is hohoho`() // 333
}
```

---

# 2. 연산자 사용

아래는 이미 정의되어 있는 오버로드된 연산자인 `get()`, `set()`, `contains()` 의 사용 예시이다.

```kotlin
fun main() {
    val list1 = MutableList(10) { 'a' + it }
    val list2 = MutableList(10) { it }

    println(list1) // [a, b, c, d, e, f, g, h, i, j]
    println(list2) // [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    val result1 = list1[7] // operator get()
    val result2 = list1.get(8) // 명시적 호출

    list1[9] = 'x' // operator set()
    list1.set(9, 'x') // 명시적 호출

    val result3 = ('d' in list1) // operator contains()
    val result4 = list1.contains('d') // 명시적 호출

    println(result1) // h
    println(result2) // i
    println(result3) // true
    println(result4) // true
}
```

리스트 원소에 각괄호로 접근하는 연산은 오버로드한 연산자인 `get()`, `set()` 을 호출하며, `in` 은 `contains()` 를 호출한다.

---

## 2.1. 가변 컬렉션에 `+=`, `+` 적용

**가변 컬렉션에 `+=` 를 호출하면 컬렉션 내용을 변경**하지만, **`+` 를 호출하면 예전 원소에 새 원소가 추가된 새로운 컬렉션을 반환**한다.

```kotlin
fun main() {
    val mutableList = mutableListOf(1, 2, 3) // 가변 컬렉션

    mutableList += 4 // operator plusAssign()
    mutableList.plusAssign(5) // 명시적 호출

    println(mutableList) // [1, 2, 3, 4, 5]
    // + 를 호출해도 기존 컬렉션은 변하지 않고, 새로운 컬렉션 반환
    println(mutableList + 99) // [1, 2, 3, 4, 5, 99]
    println(mutableList) // [1, 2, 3, 4, 5]

    val list = listOf(1) // 읽기 전용 컬렉션
    val newList = list + 2 // operator plus()

    println(list) // [1]
    println(newList) // [1, 2]

    val list3 = list.plus(3) // 명시적 호출
    println(list3) // [1, 3]

    // + 를 호출해도 기존 컬렉션은 변하지 않고, 새로운 컬렉션 반환
    println(list3 + 99) // [1, 3, 99]
    println(list3) // [1, 3]
}
```

---

## 2.2. 불변 컬렉션에 `+=` 적용

가변 컬렉션에 `+=` 를 호출하면 컬렉션 내용을 변경하지만, 읽기 전용 컬렉션에 `+=` 을 적용하면 예상치 못한 결과를 얻을수도 있다.

```kotlin
fun main() {
    var list = listOf(1, 2) // 가변 컬렉션
    list += 3
    
    // Int 처럼 간단한 타입은 기존 컬렉션 내용을 변경함
    println(list) // [1, 2, 3]
}
```

**가변 컬렉션에서 _a += b_ 는 _a_ 를 변경하는 `plusAssign()` 을 호출**하지만, **읽기 전용 컬렉션에는 `plusAssign()` 이 없다.**  
따라서 코틀린은 _a += b_ 를 _a = a + b_ 로 해석하고, 이 식은 `plus()` 를 호출한다.  
**`plus()` 는 컬렉션 내용을 변경하지 않고 새로운 컬렉션을 생성한 후 리스트에 대한 var 참조에 대입**한다.

위처럼 Int 처럼 간단한 타입의 경우 _a += b_ 는 예상한대로 기존의 컬렉션 내용을 변경한다.

하지만 아래의 경우를 보자.

```kotlin
fun main() {
    var list = listOf(1, 2) // 가변 컬렉션
    val initial = list

    list += 3

    // 기존 컬렉션 내용을 변경함
    println(list) // [1, 2, 3]

    list = list.plus(4)
    println(list) // [1, 2, 3, 4]
    
    // 컬렉션이 변경되지 않고 그대로 있음
    println(initial) // [1, 2]
}
```

_initial_ 의 경우 컬렉션이 변경되지 않고 그대로 있는 것을 확인할 수 있다.

원소를 추가할 때마다 새로운 컬렉션을 만드는 것을 원하지는 않았을 것이다.

만일 _var list_ 를 _val list_ 로 변경하면 _list += 3_ 이 컴파일되지 않기 때문에 이런 문제가 발생하지 않는다.

**이것이 디폴트로 val 를 사용해야 하는 이유 중 하나이다. var 는 꼭 필요할 때만 사용하는 것이 좋다.** 

---

## 2.3. `Comparable` 인터페이스 구현 후 `compareTo()` 오버라이드

[1.4. 비교 연산자: `compareTo()`](#14-비교-연산자-compareto) 에서 `compareTo()` 를 확장 함수로 오버라이드하는 것을 보았는데 
클래스가 `Comparable` 인터페이스를 구현한 후 `compareTo()` 를 오버라이드하면 더 좋다.

두 `Comparable` 객체 사이에는 항상 `<`, `>`, `>=`, `<=` 사용할 수 있다.  
(`==`, `!=` 는 포함되지 않음)

`Comparable` 인터페이스 안에서 이미 `compareTo()` 가 `operator` 로 정의되어 있기 때문에 여기서 `compareTo()` 를 오버라이드 할 때는 `operator` 를 사용하지 않아도 된다.

**`Comparable` 인터페이스를 구현하면 정렬이 가능**해지며, **별도로 `..` 연산자를 오버로드하지 않아도 범위 연산을 자동**으로 할 수 있다.  
**값이 범위 안에 속해있는지 `in` 으로 검사**할 수도 있다.

```kotlin
// Comparable 인터페이스 구현 후 compareTo() 오버라이드
data class Contact(val name: String, val mobile: String) : Comparable<Contact> {
    override fun compareTo(other: Contact): Int = name.compareTo(other.name)
}

fun main() {
    val assu = Contact("assu", "010-1111-1111")
    val silby = Contact("sibly", "010-2222-3333")
    val jaehun = Contact("jaehun", "010-3333-3333")

    val result1 = assu < silby
    val result2 = assu <= silby
    val result3 = assu > silby
    val result4 = assu >= silby

    println(result1) // true
    println(result2) // true
    println(result3) // false
    println(result4) // false

    val contacts = listOf(assu, silby, jaehun)

    val result5 = contacts.sorted()
    val result6 = contacts.sortedDescending()

    // // [Contact(name=assu, mobile=010-1111-1111), Contact(name=jaehun, mobile=010-3333-3333), Contact(name=sibly, mobile=010-2222-3333)]
    println(result5)

    // [Contact(name=sibly, mobile=010-2222-3333), Contact(name=jaehun, mobile=010-3333-3333), Contact(name=assu, mobile=010-1111-1111)]
    println(result6)
}
```

List 에 **`sorted()` 를 호출하면 원본의 요소들을 정렬한 새로운 List 를 리턴하고 원래의 List 는 그대로 남아있다.**    
**`sort()` 를 호출하면 원본 리스트를 변경**한다.

---

## 2.4. 구조 분해 연산자

보통 직접 정의할 일이 거의 없는 또 다른 연산자로 [구조 분해](https://assu10.github.io/dev/2024/02/10/kotlin-function-1/#7-%EA%B5%AC%EC%A1%B0-%EB%B6%84%ED%95%B4-destructuring-%EC%84%A0%EC%96%B8) 함수가 있다.

아래는 구조 분해 대입을 위해 코틀린이 암묵적으로 _component1()_, _component2()_ 을 호출해주는 예시이다.

```kotlin
class Duo(val x: Int, val y: Int) {
    operator fun component1(): Int {
        println("component1()~")
        return x
    }

    operator fun component2(): Int {
        println("component2()~")
        return y
    }
}

fun main() {
    val (a, b) = Duo(10, 20)

    // component1()~
    // component2()~
    // 10
    // 20
    println(a)
    println(b)
}
```

같은 접근 방법을 Map 에도 적용할 수 있는데, **Map 의 Entry 타입에는 이미 _component1()_, _component2()_ 멤버 함수가 정의**되어 있다.

```kotlin
fun main() {
    val map = mapOf("a" to 1)

    // 구조 분해 대입
    for ((key, value) in map) {
        // a -> 1
        println("$key -> $value")
    }

    // 위의 구조 분해 대입은 아래와 같음
    for (entry in map) {
        val key = entry.component1()
        val value = entry.component2()

        // a -> 1
        println("$key -> $value")
    }
}
```

**data 클래스는 자동으로 `componentN()` 을 만들어주기 때문에 모든 data 클래스에 대해 구조 분해 선언을 사용**할 수 있다.  
코틀린은 **data 클래스의 각 프로퍼티에 대해 data 클래스 생성자에 프로퍼티가 나타난 순서대로 `componentN()` 을 생성**해준다.

```kotlin
data class Person(val name: String, val age: Int) {
    // 컴파일러가 아래 두 함수를 생성해줌
    // fun component1() = name
    // fun component2() = age
}

fun main() {
    val person = Person("Assu", 20)

    // 구조 분해 대입
    val (name, age) = person

    // 위의 구조 분해 대입은 아래와 같음
    val name1 = person.component1()
    val age1 = person.component2()

    println(name) // Assu
    println(age) // 20
    println(name1) // Assu
    println(age1) // 20
}
```

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
* [Infix Function 이 뭐게?](https://velog.io/@haero_kim/Kotlin-Infix-Function-%EC%9D%B4-%EB%AD%90%EA%B2%8C)