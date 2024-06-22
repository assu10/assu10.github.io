---
layout: post
title:  "Kotlin - 객체 지향 프로그래밍(5): object, inner class, 'this@클래스명', companion object"
date:   2024-03-03
categories: dev
tags: kotlin object, inner class, companion object
---

이 포스트에서는 object, inner class, 한정된 `this` (`this@클래스명`), companion object 에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. object](#1-object)
  * [1.1. object 기본](#11-object-기본)
  * [1.2. object 의 상속](#12-object-의-상속)
  * [1.3. 다른 object 나 클래스 안에 object 내포](#13-다른-object-나-클래스-안에-object-내포)
* [2. 내부 클래스 (inner class)](#2-내부-클래스-inner-class)
  * [2.1. 한정된 `this`: `this@클래스명`](#21-한정된-this-this클래스명)
  * [2.2. inner 클래스 상속](#22-inner-클래스-상속)
  * [2.3. Local inner 클래스와 익명 inner 클래스](#23-local-inner-클래스와-익명-inner-클래스)
* [3. 내부 클래스 (inner class) 와 내포된 클래스 (nested class)](#3-내부-클래스-inner-class-와-내포된-클래스-nested-class)
* [4. 동반 객체 (companion object)](#4-동반-객체-companion-object)
  * [4.1. companion object 기본](#41-companion-object-기본)
  * [4.2. 함수를 companion object 대신 파일 영역에 배치](#42-함수를-companion-object-대신-파일-영역에-배치)
  * [4.3. companion object 안에서의 프로퍼티](#43-companion-object-안에서의-프로퍼티)
  * [4.4. 함수를 companion object 영역에 배치](#44-함수를-companion-object-영역에-배치)
  * [4.5. companion object 를 만들면서 인터페이스 구현](#45-companion-object-를-만들면서-인터페이스-구현)
  * [4.6. 클래스 위임을 사용하여 companion object 활용](#46-클래스-위임을-사용하여-companion-object-활용)
  * [4.7. companion object 를 사용하여 인터페이스 구현](#47-companion-object-를-사용하여-인터페이스-구현)
  * [4.8. companion object 로 객체 생성 제어: Factory Method 패턴](#48-companion-object-로-객체-생성-제어-factory-method-패턴)
  * [4.9. companion object 생성 시점](#49-companion-object-생성-시점)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. object

## 1.1. object 기본

**object 의 인스턴스는 오직 하나만 존재**한다. 이것을 싱글턴 패턴이라고도 한다.

**object 는 여러 인스턴스가 필요하지 않거나, 명시적으로 인스턴스를 여러 개 생성하는 것을 막고 싶은 경우 논리적으로 한 개체 안에 속한 함수와 프로퍼티를 함께 엮는 방법**이다.

**object 의 인스턴스를 직접 생성하는 경우는 절대 없다.**    
object 를 정의하면 그 object 의 인스턴스가 오직 하나만 생긴다.

```kotlin
object JustOne {
    val n = 2

    fun f() = n * 2

    // this 키워드는 유일한 객체 인스턴스를 가리킴
    fun g() = this.n * 20
}

fun main() {
    // 오류
    // JustOne() 을 이용하여 JustOne 의 새로운 인스턴스 생성 불가
    // val x = JustOne()

    val result1 = JustOne.n
    val result2 = JustOne.f()
    val result3 = JustOne.g()

    println(result1)
    println(result2)
    println(result3)
}
```

**object 키워드가 객체의 구조를 정의하는 동시에 객체를 생성**해버리기 때문에 _JustOne()_ 으로 새로운 인스턴스를 생성할 수 없다.

object 키워드는 내부 원소들을 object 로 정의한 객체의 name space 안에 넣는다.  
**object 가 선언된 파일 안에서만 보이게 하려면 private 를 앞에 붙이면 된다.**

---

## 1.2. object 의 상속

**object 는 다른 클래스나 인터페이스를 상속**할 수 있다.

```kotlin
open class Paint(private val color: String) {
    open fun apply() = "apply $color~"
}

// 다른 클래스를 상속한 object
object Acrylic : Paint("Red") {
    override fun apply() = "Acrylic, ${super.apply()}"
}

interface PaintPreparation {
    fun prepare(): String
}

// 다른 인터페이스를 상속한 object
object Prepare : PaintPreparation {
    override fun prepare() = "prepare~"
}

fun main() {
    val result1 = Prepare.prepare()
    val result2 = Paint("Green").apply()
    val result3 = Acrylic.apply()

    println(result1) // prepare~
    println(result2) // apply Green~
    println(result3) // Acrylic, apply Red~
}
```

**object 의 인스턴스는 단 하나이기 때문에 이 인스턴스가 object 를 사용하는 모든 코드에서 공유**된다.

아래는 각각 다른 파일이다.

```kotlin
object Shared {
    var i: Int = 0
}
```

```kotlin
fun f() {
    Shared.i += 2
}
```

```kotlin
fun g() {
    Shared.i += 3
}

fun main() {
    f()
    g()
    println(Shared.i) // 5
}
```

object 는 인스턴스를 하나만 만들기 때문에 모든 파일에서 _Shared_ 는 동일하다. 

_Shared_ 를 private 로 정의하면 다른 파일에서는 이 객체에 접근할 수 없다.

---

## 1.3. 다른 object 나 클래스 안에 object 내포

**object 를 함수 안에 넣을 수는 없지만, 다른 object 나 클래스 안에 object 를 내포시킬 수는 있다.**

> 클래스가 내포 클래스이어도 관계없지만, 내부 클래스(inner class) 의 경우엔 내부에 object 를 선언할 수 없음  
> 이 내용은 바로 다음인 [2. 내부 클래스 (inner class)](#2-내부-클래스-inner-class) 에 나옵니다.

```kotlin
object Outer {
    // object 안에 내포된 object
    object Nested {
        val a = "Outer.Nested.a"
    }
}

class HasObject {
    // 클래스 안에 내포된 object
    object Nested {
        val a = "HasObject.Nested.a"
    }
}

fun main() {
    println(Outer.Nested.a) // Outer.Nested.a
    println(HasObject.Nested.a) // HasObject.Nested.a
}
```

> 클래스 안에 object 를 넣는 또 다른 방법으로 companion object 가 있는데 이 내용은 [4. 동반 객체 (companion object)](#4-동반-객체-companion-object) 를 참고하세요.

---

# 2. 내부 클래스 (inner class)

inner 클래스는 내포된 클래스와 비슷하지만, **inner 클래스의 객체는 자신을 둘러싼 클래스 인스턴스에 대한 참조(암시적 링크)를 유지**한다.

아래 코드에서 _Hotel_ 은 [2. 내포된 클래스 (nested class)](https://assu10.github.io/dev/2024/03/02/kotlin-object-oriented-programming-4/#2-%EB%82%B4%ED%8F%AC%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-nested-class) 에 나온 
_Airport_ 와 비슷하지만 내포된 클래스가 아닌 inner 클래스가 포함되어 있다.

```kotlin
class Hotel(private val reception: String) {
    // inner class
    open inner class Room(val id: Int = 1) {
        // Room 을 둘러싼 클래스의 reception 사용
        fun callReception() = "Room $id calling $reception~"
    }

    // 내포된 inner class 이면서 private
    // inner class 인 Room 을 상속하므로 Closet 도 inner class 이어야 함
    // (내포된 클래스는 inner class 를 상속할 수 없음)
    private inner class Closet : Room()

    // 결과를 public 타입인 Room 으로 업캐스트하여 반환해야 함
    fun closet(): Room = Closet()
}

fun main() {
    val aaHotel = Hotel("AAA")

    // inner class 의 인스턴스를 생성하려면 그 inner class 를 둘러싼 클래스의 인스턴스가 필요
    val room = aaHotel.Room(111)
    val result1 = room.callReception()

    println(result1)    // Room 111 calling AAA~

    // 아래와 같은 오류가 뜨면서 컴파일되지 않음
    // Classifier 'Closet' does not have a companion object, and thus must be initialized here

    // val privateCloset = Hotel.Closet()

    val bbHotel = Hotel("BBB")
    val closet = bbHotel.closet()
    val result2 = closet.callReception()

    println(result2)    // Room 1 calling BBB~
}
```

_Airport_ 에서 내포된 클래스인 _Plane_ 객체를 생성할 때는 _Airport_ 객체가 필요없었지만, inner 클래스의 인스턴스를 생성할 때는 그 inner 클래스를 둘러싼 
클래스의 인스턴스가 필요하다.

**코틀린은 inner data 클래스는 허용하지 않는다.**

---

## 2.1. 한정된 `this`: `this@클래스명`

클래스의 장점 중 하나는 `this` 참조를 사용할 수 있다는 점이다.

간단한 클래스에서 `this` 의 의미는 분명해 보이지만 inner 클래스에서 `this` 는 inner 객체나 외부 객체를 가리킬 수 있다.

이러한 문제를 해결하기 위해 코틀린은 **한정된 this 구문**을 사용한다.  
**한정된 `this` 는 `this` 뒤에 `@` 를 붙이고 대상 클래스 이름**을 붙이면 된다.

아래는 3가지 수준의 클래스 예시이다.  
_Fruit_ 안에 inner 클래스인 _Seed_ 가 있고, _Seed_ 클래스 안에 다시 inner 클래스인 _DNA_ 가 있다.

```kotlin
val Any.name
    get() = this::class.simpleName

class Fruit { // @Fruit 라는 레이블이 암시적으로 붙음
    fun changeColor(color: String) = println("Fruit $color~")

    fun absorbWater(amount: Int) {}

    // Fruit 안에 있는 Seed inner class
    inner class Seed { // @Seed 라는 레이블이 암시적으로 붙음
        fun changeColor(color: String) = println("Seed $color~")

        fun germinate() {}

        fun whichThis() {
            // 디폴트로 (가장 안쪽의) 현재 클래스인 Seed 를 가리킴
            println(this.name) // Seed

            // 명확히 하기 위해 디폴트 this 를 한정시킴
            println(this@Seed.name) // Seed

            // name 이 Fruit 와 Seed 에 다 있으므로 Fruit 를 명시하여 접근
            println(this@Fruit.name) // Fruit

            // 현재 클래스의 inner class 에 @레이블 을 사용하여 접근 불가
            // println(this@DNA.name)
        }

        // Seed inner class 안에 있는 DNS inner class
        inner class DNA {
            fun changeColor(color: String) {
                // changeColor(color) // 재귀 호출이 됨

                this@Seed.changeColor(color)
                this@Fruit.changeColor(color)
            }

            fun plant() {
                // 한정시키지 않고 외부 클래스의 함수 호출 가능
                germinate()
                absorbWater(10)
            }

            // 확장 함수
            fun Int.grow() { // @grow 라는 레이블이 암시적으로 붙음
                // 디폴트는 Int.grow() 로, Int 를 수신 객체로 받음
                println(this.name) // Int

                // @grow 한정은 없어도 됨
                println(this@grow.name) // Int

                // 여기서도 여전히 모든 프로퍼티에 접근 가능
                println(this@DNA.name) // DNA
                println(this@Seed.name) // Seed
                println(this@Fruit.name) // Fruit
            }

            // 외부 클래스에 대한 확장 함수들
            fun Seed.plant() {}

            fun Fruit.plant() {}

            fun witchThis() {
                // 디폴트는 현재 클래스
                println(this.name) // DNA

                // @DNA 한정은 없어도 됨
                println(this@DNA.name) // DNA

                // 다른 클래스 한정은 꼭 명시 필요
                println(this@Seed.name) // Seed
                println(this@Fruit.name) // Fruit
            }
        }
    }
}

// 확장 함수
fun Fruit.grow(amount: Int) {
    absorbWater(amount)

    // Fruit 의 changeColor() 호출
    changeColor("Red") // Fruit Red~
}

// inner class 를 확장한 함수
fun Fruit.Seed.grow(amount: Int) {
    germinate()
    // Seed 의 changeColor() 호출
    changeColor("Red") // Seed Red~
}

// inner class 를 확장한 함수
fun Fruit.Seed.DNA.grow(amount: Int) = amount.grow()

fun main() {
    val fruit = Fruit()
    fruit.grow(3) // Fruit Red~

    val seed = fruit.Seed()
    seed.grow(4) // Seed Red~
    seed.whichThis() // Seed  Seed  Fruit

    val dna = seed.DNA()
    dna.plant()
    dna.grow(5) // Int  Int  DNA  Seed  Fruit
    dna.witchThis() // DNA  DNA  Seed  Fruit
    dna.changeColor("Red") // Seed Red~  Fruie Red~
}
```

_Fruit_, _Seed_, _DNA_ 모두 _changeColor()_ 함수를 제공하지만 세 클래스 사이에 아무런 상속관계가 없으므로 오버라이드 하지 않는다.

세 클래스에 정의된 _changeColor()_ 의 시그니처가 같기 때문에 _DNA_ 의 _changeColor()_ 에서 보는 것처럼 한정된 `this` 를 사용하여 각 함수를 구별해야 한다.

_Int.grow()_ 는 확장 함수임에도 불구하고 외부 객체에 접근이 가능하다.

---

## 2.2. inner 클래스 상속

**inner 클래스는 다른 외부 클래스에 있는 inner 클래스를 상속**할 수 있다.

아래에서 _BigEgg_ 의 _York_ 는 _Egg_ 의 _Yolk_ 를 상속한다.  

```kotlin
open class Egg {
    private var yolk = Yolk()

    open inner class Yolk {
        // 주생성자
        init {
            println("Egg.Yolk()~")
        }

        open fun f() = println("Egg.Yolk.f()~")
    }

    // 주생성자
    init {
        println("New Egg~")
    }

    fun insertYolk(y: Yolk) {
        yolk = y
    }

    fun g() {
        yolk.f()
    }
}

// Egg 클래스 상속
class BigEgg : Egg() {
    // Egg 의 inner class 인 Yolk 상속
    inner class Yolk : Egg.Yolk() {
        init {
            println("BigEgg.Yolk()~")
        }

        override fun f() = println("BigEgg.Yolk.f()~")
    }

    // 주생성자
    init {
        insertYolk(Yolk())
    }
}

fun main() {
    // Egg.Yolk()~
    // New Egg~
    // Egg.Yolk()~
    // BigEgg.Yolk()~
    // BigEgg.Yolk.f()~
    BigEgg().g()
}
```

_BigEgg.Yolk_ 는 _Egg.Yolk_ 를 기반 클래스로 정의하고, _Egg.Yolk_ 의 _f()_ 멤버 함수를 오버라이드한다.    
_insertYolk()_ 는 _BigEgg_ 가 자신의 _Yolk_ 객체를 _Egg_ 에 있는 _yolk_ 참조로 업캐스트하게 허용한다.  
따라서 _g()_ 가 _yolk.f()_ 를 호출하면 오버라이드된 _f()_ 가 호출된다.

_Egg.Yolk()_ 에 대한 두 번째 호출은 _BigEgg.Yolk_ 생성자에서 호출한 기반 클래스 생성자이다.  

---

## 2.3. Local inner 클래스와 익명 inner 클래스

**멤버 함수 안에 정의된 클래스를 Local inner 클래스**라고 한다.  
이런 클래스는 객체 식(object expression) 이나 SAM 변환을 사용하여 익명으로 생성할 수 있다.

> SAM 변환에 대한 좀 더 상세한 내용은 [1.3. 단일 추상 메서드 (Single Abstract Method, SAM): `fun interface`](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#13-%EB%8B%A8%EC%9D%BC-%EC%B6%94%EC%83%81-%EB%A9%94%EC%84%9C%EB%93%9C-single-abstract-method-sam-fun-interface) 를 참고하세요.

모든 경우에 inner 키워드를 사용하지는 않지만, Local inner 클래스는 암시적으로 inner 클래스가 된다.

```kotlin
fun interface Pet {
    fun speak(): String
}

object CreatePet {
    fun home() = " home~"

    // dog() 는 Pet 을 상속하면서 speak() 를 오버라이드하는 클래스 반환
    fun dog(): Pet {
        val say = "Bark~"

        // (1) Local inner 클래스
        class Dog : Pet {
            override fun speak() = say + home()
        }
        return Dog()
    }

    fun cat(): Pet {
        val emit = "Meow~"
        // (2) 익명 inner 클래스
        return object : Pet {
            override fun speak() = emit + home()
        }
    }

    fun hamster(): Pet {
        val squeak = "Squeak~"
        // (3) SAM 변환
        return Pet { squeak + home() }
    }
}

fun main() {
    val result1 = CreatePet.dog().speak()
    val result2 = CreatePet.cat().speak()
    val result3 = CreatePet.hamster().speak()

    println(result1)    // Bark~ home~
    println(result2)    // Meow~ home~
    println(result3)    // Squeak~ home~
}
```

Local inner 클래스는 함수에 정의된 원소와 함수 정의를 포함하는 외부 클래스 객체의 원소에 접근이 가능하다.  
그래서 _say_, _emit_, _squeak_ 와 _home()_ 을 _speak()_ 안에서 사용할 수 있다.

위에서 _cat()_ 는 _Pet_ 를 상속하면서 _speak()_ 를 오버라이드하는 클래스의 object 를 반환한다.

---

**inner 클래스는 외부 클래스 객체에 대한 참조를 저장하기 때문에 Local inner 클래스도 자신을 둘러싼 클래스에 속한 객체의 모든 멤버에 접근 가능**하다. 

```kotlin
// 단일 추상 메서드 (fun interface)
fun interface Counter {
    fun next(): Int
}

object CounterFactory {
    private var count = 0

    // Counter interface 구현
    // 이름이 붙은 inner 클래스의 인스턴스 반환
    fun new(name: String): Counter {
        // Local inner 클래스
        class Local : Counter {
            // 주생성자
            init {
                println("Local()~")
            }

            override fun next(): Int {
                // 함수의 지역 변수나 외부 객체 프로퍼티에 접근 가능
                println("$name, $count~")
                return count++
            }
        }
        return Local()
    }

    // 익명 inner 클래스 반환
    fun new2(name: String): Counter {
        // 익명 inner 클래스 인스턴스
        return object : Counter {
            init {
                println("Counter()~")
            }

            override fun next(): Int {
                println("$name, $count~~")
                return count++
            }
        }
    }

    // SAM 변환을 사용하여 익명 객체 반환
    fun new3(name: String): Counter {
        println("Counter()~~")
        // SAM 변환
        return Counter {
            println("$name, $count~~~")
            count++
        }
    }
}

fun main() {
    fun aaa(counter: Counter) {
        (0..3).forEach { _ -> counter.next() }
    }

    // Local()~
    // Local inner class, 0~
    // Local inner class, 1~
    // Local inner class, 2~
    // Local inner class, 3~
    val result1 = aaa(CounterFactory.new("Local inner class"))

    // Counter()~
    // Anonymous inner class, 4~~
    // Anonymous inner class, 5~~
    // Anonymous inner class, 6~~
    // Anonymous inner class, 7~~
    val result2 = aaa(CounterFactory.new2("Anonymous inner class"))

    // Counter()~~
    // SAM, 8~~~
    // SAM, 9~~~
    // SAM, 10~~~
    // SAM, 11~~~
    val result3 = aaa(CounterFactory.new3("SAM"))
}
```

> SAM 변환 (`fun interface`)에 대한 좀 더 상세한 내용은 [1.3.1. SAM 변환](https://assu10.github.io/dev/2024/02/24/kotlin-object-oriented-programming-1/#131-sam-%EB%B3%80%ED%99%98) 을 참고하세요.

> _(0..3).forEach {_ -> counter.next() }_ 에서 밑줄은 [1.4. 람다가 특정 인자를 사용하지 않는 경우: `List.indices()`](https://assu10.github.io/dev/2024/02/12/kotlin-funtional-programming-1/#14-%EB%9E%8C%EB%8B%A4%EA%B0%80-%ED%8A%B9%EC%A0%95-%EC%9D%B8%EC%9E%90%EB%A5%BC-%EC%82%AC%EC%9A%A9%ED%95%98%EC%A7%80-%EC%95%8A%EB%8A%94-%EA%B2%BD%EC%9A%B0-listindices) 를 참고하세요.

위에서 _new()_, _new2()_, _new3()_ 은 각각 _Counter_ 인터페이스에 대한 다른 구현을 생성한다.

- _new()_ : 이름이 붙은 inner 클래스의 인스턴스 반환
- _new2()_ : 익명 inner 클래스의 인스턴스 반환
- _new2()_ : SAM 변환을 사용하여 익명 객체 반환

모든 _Counter_ 객체는 **외부 객체의 원소에 접근할 수 있으므로 이 클래스들은 내포된 클래스가 아니라 inner 클래스**이다.  
출력을 보면 모든 _Counter_ 객체가 _CounterFactory_ 의 _count_ 를 공유한다는 것을 알 수 있다.

> 내포된 클래스에 대한 좀 더 상세한 내용은 [2. 내포된 클래스 (nested class)](https://assu10.github.io/dev/2024/03/02/kotlin-object-oriented-programming-4/#2-%EB%82%B4%ED%8F%AC%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-nested-class) 를 참고하세요.

SAM 변환에는 한계가 있는데 예를 들어 SAM 변환으로 선언하는 객체 내부에는 주 생성자인 _init_ 블록이 들어갈 수 없다.

---

# 3. 내부 클래스 (inner class) 와 내포된 클래스 (nested class)

> 내부 클래스에 대한 내용은 [2. 내부 클래스 (inner class)](https://assu10.github.io/dev/2024/03/03/kotlin-object-oriented-programming-5/#2-%EB%82%B4%EB%B6%80-%ED%81%B4%EB%9E%98%EC%8A%A4-inner-class) 를 참고하세요.

클래스 안에 다른 클래스를 선언할 수도 있는데 이렇게 클래스 안에 다른 클래스를 선언하면 도우미 클래스를 캡슐화하거나 코드 정의를 그 코드를 사용하는 곳에 가까이 두고 싶을 때 유용하다.

자바와의 차이는 **내포된 클래스 (nested class) 는 명시적으로 요청을 하지 않는 한 외부 클래스 인스턴스에 대한 접근 권한이 없다**는 점이다.

아래처럼 _View_ 의 상태를 직렬화해야 할 경우 _View_ 를 직렬화하기는 쉽지 않지만 필요한 모든 데이터를 다른 도우미 클래스로 복사할 수는 있다.  
그러기 위해 _State_ 인터페이스를 선언한 후 `Serializable` 을 구현한다.

_View_ 인터페이스 안에는 뷰의 상태를 가져와서 저장할 때 사용할 메서드가 2개 선언되어 있다.

```kotlin
import java.io.Serializable

// View 를 직렬화하기 위해 선언한 인터페이스
interface State : Serializable

interface View {
    fun getCurrentState(): State

    fun restoreState(state: State) {}
}
```

_Button1_ 클래스의 상태를 저장하는 클래스(ButtonState) 는 Button 클래스 내부에 선언하면 편하다.

아래는 자바에서의 예시이다.

```java
public class Button1 implements View {
  @Override
  public State getCurrentState() {
    return new ButtonState();
  }

  @Override
  public void restoreState(State state) {
    // ...
  }

  public class ButtonState implements State {
    // ...
  }
}
```

자바는 다른 클래스 안에 정의한 클래스는 자동으로 내부 클래스 (inner class) 가 되기 때문의 위의 _ButtonState_ 클래스는 바깥쪽 _Button_ 클래스에 대한 참조를 
묵시적으로 포함한다. 그 참조로 인해 _ButtonState_ 를 직렬화할 수 없다.

이 문제를 해결하려면 _ButtonState_ 를 클래스로 선언해야 한다.  
자바에서 내포된 클래스 (nested class) 를 static 으로 선언하면 그 클래스를 둘러싼 외부 클래스에 대한 묵시적인 참조가 사라진다.

코틀린에서는 내포된 클래스 (nested class) 가 기본적으로 동작하는 방식이 자바와 정반대이다.

아래는 코틀린에서의 예시이다.

```kotlin
class Button2 : View {
    override fun getCurrentState(): State = ButtonState()

    override fun restoreState(state: State) {
        // ...
    }

    // 내포된 클래스 (nested class)
    class ButtonState : State {
        // ...
    }
}
```

코틀린의 내포된 클래스에 아무런 변경자가 붙지 않으면 자바의 static 중첩 클래스와 같다.

만일 이를 내부 클래스 (inner class) 로 변경해서 외부 클래스에 대한 참조를 포함하게 하고 싶다면 `inner` 변경자를 붙이면 된다.

자바와 코틀린의 내포된 클래스 (nested class) 와 내부 클래스 (inner class) 차이

| 클래스 B 안에 정의된 클래스 A                 | 자바              | 코틀린            |
|:-----------------------------------|:----------------|:---------------|
| 내포된 클래스 (바깥쪽 클래스에 대한 참조를 저장하지 않음)  | static class A  | class A        |
| 내부 클래스 (바깥쪽 클래스에 대한 참조를 저장함)       | class A         | inner class A  |

---

# 4. 동반 객체 (companion object)

## 4.1. companion object 기본

동반 객체 (companion object) 안에 있는 함수와 필드는 클래스에 대한 함수와 필드이다.

일반 클래스의 원소는 companion object 의 원소에 접근할 수 있지만, companion object 의 원소는 일반 클래스의 원소에 접근할 수 없다.

> companion object 안에 정의되어 있는 원소는 동반 클래스의 인스턴스나 함수를 마음대로 사용 가능함  
> 다만, 동반 클래스의 멤버는 동반 클래스의 인스턴스에 대해 작용하므로 companion object 의 함수나 프로퍼티가 동반 클래스의 멤버에 접근하려면 
> 반드시 동반 클래스의 인스턴스를 함수 파라메터로 받거나 해야 함

[1.3. 다른 object 나 클래스 안에 object 내포](#13-다른-object-나-클래스-안에-object-내포) 에서 본 것처럼 클래스 안에 일반 object 를 정의할 수 있다.  
**하지만 일반 내포 객체 정의는 내포 object 와 그 객체를 둘러싼 클래스 사이의 연관 관계를 제공하지 않는다.**  
**내포된 object 의 멤버를 클래스 멤버에서 참조해야 할 때는 내포된 object 의 이름을 항상 명시**해야 한다.  
**클래스 안에서 companion object 를 정의하면 클래스의 내부에서 companion object 원소를 투명하게 참조 가능**하다.

```kotlin
class WithCompanion {
    companion object {
        val i = 3

        fun f() = i * 3
    }

    // 클래스 멤버는 companion object 의 원소에 아무런 한정을 사용하지 않고 접근 가능
    // 만일 companion object 가 아니라 일반 object 였다면 Unresolved reference: i, f() 오류 발생
    fun g() = i + f()
}

// companion object 에 대한 확장 함수
fun WithCompanion.Companion.h() = f() * i

fun main() {
    val wc = WithCompanion()

    val result1 = wc.g()

    // 클래스 밖에서는 companion object 의 멤버를 클래스 이름을 사용하여 참조 가능
    // 만일 companion object 가 아니었다면 클래스 밖에서 object 의 원소 참조 불가
    val result2 = WithCompanion.i

    // 클래스 밖에서는 companion object 의 멤버를 클래스 이름을 사용하여 참조 가능
    // 만일 companion object 가 아니었다면 클래스 밖에서 object 의 원소 참조 불가
    val result3 = WithCompanion.f()
    val result4 = WithCompanion.h()

    println(result1) // 12
    println(result2) // 3
    println(result3) // 9
    println(result4) // 27
}
```

---

## 4.2. 함수를 companion object 대신 파일 영역에 배치

**함수가 클래스의 private 멤버에 접근할 필요가 없다면 이 함수를 companion object 에 넣는 대신 파일 영역(최상위 수준)에 정의**하면 된다.  

**companion object 는 클래스 당 하나만 허용 가능하며, 명확성을 위해 companion object 에 이름을 부여**할 수도 있다.

```kotlin
class WithNamed {
    companion object Aaa {
        fun s() = "from Aaa~"
    }
}

class WithDefault {
    companion object {
        fun s() = "from Default~"
    }
}

fun main() {
    val result1 = WithNamed.s()
    val result2 = WithNamed.Aaa.s()
    val result3 = WithDefault.s()

    // 디폴트 이름은 Companion 임
    val result4 = WithDefault.Companion.s()

    println(result1) // from Aaa~
    println(result2) // from Aaa~
    println(result3) // from Default~
    println(result4) // from Default~
}
```

companion object 에 이름을 붙이지 않으면 기본으로 _Companion_ 이라는 이름이 부여된다.

---

## 4.3. companion object 안에서의 프로퍼티

**companion object 안에서 프로퍼티를 생성하면 이 필드는 메모리 상에 단 하나만 존재**하게 되고, **companion object 와 연관된 클래스의 모든 인스턴스가 이 필드를 공유**한다.

```kotlin
class WithObjectProperty {
    companion object {
        private var n: Int = 0 // 메모리 상에 단 하나만 존재
    }

    // companion object 를 둘러싼 클래스에서 companion object 의 private 멤버에 접근 가능
    fun incr() = ++n
}

fun main() {
    val a = WithObjectProperty()
    val b = WithObjectProperty()

    println(a.incr()) // 1
    println(b.incr()) // 2
    println(a.incr()) // 3
}
```

위에서 _WithObjectProperty_ 의 인스턴스가 몇 개가 생성되었든 _n_ 은 모두 하나의 저장소임을 알 수 있다.  
_incr()_ 은 **companion object 를 둘러싼 클래스에서 companion object 의 private 멤버에 접근 가능**하다는 것을 보여준다.

---

## 4.4. 함수를 companion object 영역에 배치

**함수가 오직 companion object 의 프로퍼티만 사용한다면 해당 함수는 companion object 에 넣는 것이 합리적**이다.

아래와 같이 하면 더 이상 _incr()_ 을 호출할 때 _CompanionObjectFunctions_ 의 인스턴스가 필요하지 않다.

```kotlin
class CompanionObjectFunctions {
    companion object {
        private var n: Int = 0

        fun incr() = ++n
    }
}

fun main() {
    println(CompanionObjectFunctions.incr())    // 1
    println(CompanionObjectFunctions.incr())    // 2
}
```

---

만일 생성하는 모든 객체에 대해 고유 식별자를 부여하면서 전체를 카운트하고 싶다면 아래와 같이 하면 된다.


```kotlin
class Counted {
    companion object {
        private var n = 0
    }

    private val id = n++

    override fun toString() = "$id"
}

fun main() {
    val result = List(4) { Counted() }

    println(result) // [0, 1, 2, 3]
}
```

---

## 4.5. companion object 를 만들면서 인터페이스 구현

아래 코드에서 _ZICompanion_ 은 _ZIOpen_ 객체를 companion object 로 사용하고,  
_ZICompanionInheritance_ 는 _ZIOpen_ 클래스를 확장하고, 오버라이드 하면서 _ZIOpen_ 객체를 생성한다.  
_ZIClass_ 는 companion object 를 만들면서 _ZI_ 인터페이스 구현한다.

```kotlin
interface ZI {
    fun f(): String

    fun g(): String
}

// open 으로 되어있어야 다른 곳에서 상속 가능
open class ZIOpen : ZI {
    override fun f() = "ZIOpen.f()~"

    override fun g() = "ZIOpen.g()~"
}

class ZICompanion {
    // ZIOpen 객체를 companion object 로 사용
    companion object : ZIOpen()

    fun u() = println("ZICompanion: ${f()} ${g()}~")
}

// ZIOpen 클래스를 확장하고, 오버라이드 하면서 ZIOpen 객체 생성
class ZICompanionInheritance {
    companion object : ZIOpen() {
        override fun g() = "ZICompanionInheritance.g()~"

        fun h() = "ZICompanionInheritance.h()~"
    }

    fun u() = println("ZICompanionInheritance: ${f()} ${g()} ${h()}")
}

// companion object 를 만들면서 ZI 인터페이스 구현
class ZIClass {
    companion object : ZI {
        override fun f() = "ZIClass.f()~"

        override fun g() = "ZIClass.g()~"
    }

    fun u() = println("ZIClass: ${f()} ${g()}")
}

fun main() {
    ZIClass.f() //
    ZIClass.g() //
    ZIClass().u() // ZIClass: ZIClass.f()~ ZIClass.g()~

    ZICompanion.f() //
    ZICompanion.g() //
    ZICompanion().u() // ZICompanion: ZIOpen.f()~ ZIOpen.g()~~

    ZICompanionInheritance.f() //
    ZICompanionInheritance.g() //
    ZICompanionInheritance().u() // ZICompanionInheritance: ZIOpen.f()~ ZICompanionInheritance.g()~ ZICompanionInheritance.h()~
}
```

---

## 4.6. 클래스 위임을 사용하여 companion object 활용

> 클래스 위임에 대한 좀 더 상세한 내용은 [1. 클래스 위임 (class delegation)](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#1-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%9C%84%EC%9E%84-class-delegation) 을 참고하세요.

바로 위 코드에서 **companion object 로 사용하고 싶은 클래스가 `open` 이 아니라면 위처럼 companion object 가 클래스를 직접 확장할 수 없다.**  
대신 **그 클래스가 어떤 인터페이스를 구현한다면 클래스 위임을 사용하여 companion object 가 해당 클래스를 활용**할 수 있다.

```kotlin
interface ZI1 {
    fun f(): String

    fun g(): String
}

class ZIClosed : ZI1 {
    override fun f() = "ZIClosed.f()~"

    override fun g() = "ZIClosed.g()~"
}

class ZIDelegation {
    // companion object 는 ZI1 인터페이스를 ZIClosed 객체를 사용(by) 하여 구현함
    companion object : ZI1 by ZIClosed()

    fun u() = println("ZIDelegation: ${f()} ${g()}~")
}

// open 이 아닌 ZIClosed 클래스를 위임에 사용하고, 
// 이 위임을 오버라이드하고 확장함
class ZIDelegationInheritance {
    // companion object 는 ZI1 인터페이스를 ZIClosed 객체를 사용(by) 하여 구현함
    companion object : ZI1 by ZIClosed() {
        override fun g() = "ZIDelegationInheritance.g()~"

        fun h() = "ZIDelegationInheritance.h()~"
    }

    fun u() = println("ZIDelegationInheritance: ${f()} ${g()} ${h()}")
}

fun main() {
    ZIDelegation.f() //
    ZIDelegation.g() //
    ZIDelegation().u() // ZIDelegation: ZIClosed.f()~ ZIClosed.g()~~

    ZIDelegationInheritance.f() //
    ZIDelegationInheritance.g() //
    ZIDelegationInheritance().u() // ZIDelegationInheritance: ZIClosed.f()~ ZIDelegationInheritance.g()~ ZIDelegationInheritance.h()~
}
```

_ZIDelegationInheritance_ 는 `open` 이 아닌 _ZIClosed_ 클래스를 위임에 사용하고, 이 위임을 오버라이드하고 확장한다.

위임은 인터페이스의 메서드와 메서드 구현을 제공하는 인스턴스에 제공한다.

구현을 제공하는 인트턴스가 속한 클래스가 `final` 이라고 해도 (코틀린은 `open` 을 지정하지 않으면 기본적으로 `final` 임) 여전히 위임을 사용하여 
정의한 클래스에서 메서드를 추가하고 오버라이드 가능하다.

---

## 4.7. companion object 를 사용하여 인터페이스 구현

아래에서 _Extend_ 는 companion object (디폴트 이름은 Companion) 를 사용하여 _ZI2_ 인터페이스 구현하고, _Extended_ 인터페이스도 구현한다.  
_Extended_ 는 _ZI2_ 인터페이스에 _u()_ 함수를 추가한 인터페이스이다.

_Extended_ 에서 _ZI2_ 에 해당하는 부분은 Companion 을 통해 이미 구현이 제공되므로, _Extend_ 는 _Extended_ 에 추가된 _u()_ 함수만 오버라이드하여 모든 구현을 끝낼 수 있다.

```kotlin
interface ZI2 {
    fun f(): String

    fun g(): String
}

// ZI2 인터페이스에 u() 함수 추가
interface Extended : ZI2 {
    fun u(): String
}

// companion object (디폴트 이름은 Companion) 를 사용하여 ZI2 인터페이스 구현
class Extend : ZI2 by Companion, Extended {
    companion object : ZI2 {
        override fun f() = "Extend.f()~"

        override fun g() = "Extend.g()~"
    }

    override fun u() = "Extend: ${f()}, ${g()}"
}

// Extend 객체를 Extended 로 업캐스트 가능
private fun test(e: Extended): String {
    e.f()
    e.g()
    return e.u()
}

fun main() {
    println(test(Extend())) // Extend: Extend.f()~, Extend.g()~
}
```

---

## 4.8. companion object 로 객체 생성 제어: Factory Method 패턴

companion object 는 객체 생성을 제어하는 경우에 많이 사용하는데 이 방식은 **팩토리 메서드 패턴**에 해당한다.

아래는 _Numbered2_ 객체로 이루어진 List 생성만 허용하고, 개별 _Numbered2_ 의 생성을 불가하는 예시이다.

```kotlin
class Numbered2
// Numbered2 의 비공개 생성자
    private constructor(private val id: Int) {
        override fun toString(): String = "$id~"

        companion object Factory1 {
            fun create(size: Int) = List(size) { Numbered2(it) }
        }
    }

fun main() {
    val result1 = Numbered2.create(0)
    val result2 = Numbered2.create(3)

    // Cannot access '<init>': it is private in 'Numbered2
    // val result3 = Numbered2(1)

    println(result1) // []
    println(result2) // [0~, 1~, 2~]
}
```

**_Numbered2_ 의 생성자가 private 이므로 _Numbered2_ 의 인스턴스를 생성하는 방법은 _create()_ 팩토리 함수를 통하는 방법 뿐**이다.

이렇게 일반 생성자로 해결할 수 없는 문제는 팩토리 함수가 해결해줄 수 있다.

---

## 4.9. companion object 생성 시점

아래 코드를 보면 _CompanionInit()_ 을 호출하여 **_CompanionInit_ 인스턴스가 최초로 생성되는 시점에 companion object 가 단 한번만 생성**된 다는 것을 알 수 있다.  
또한 **동반 클래스 생성자 생성보다 companion object 생성이 먼저** 일어난다는 것도 알 수 있다.

```kotlin
class CompanionInit {
    init {
        println("CompanionInit Constructor~")
    }

    companion object {
        init {
            println("Companion Constructor~")
        }
    }
}

fun main() {
    println("before")
    
    // Companion Constructor~
    // CompanionInit Constructor~
    
    CompanionInit()
    println("after 1")
    
    // CompanionInit Constructor~
    CompanionInit()
    println("after 2")
    
    // CompanionInit Constructor~
    CompanionInit()
    println("after 3")
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