---
layout: post
title:  "Kotlin - 객체 지향 프로그래밍(4): 타입 검사, 타입 검사 코딩, 내포된 클래스(nested class)"
date:   2024-03-02
categories: dev
tags: kotlin 
---

이 포스트에서는 타입 검사, 내포된 클래스에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kotlin/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 타입 검사](#1-타입-검사)
  * [1.1. 소수의 특별한 타입을 위한 확장 함수 이용](#11-소수의-특별한-타입을-위한-확장-함수-이용)
  * [1.2. 타입 검사 코딩](#12-타입-검사-코딩)
  * [1.3. 외부 함수에서 타입 검사](#13-외부-함수에서-타입-검사)
  * [1.4. `sealed` 클래스에서 외부 함수에서 타입 검사](#14-sealed-클래스에서-외부-함수에서-타입-검사)
* [2. 내포된 클래스(nested class)](#2-내포된-클래스nested-class)
  * [2.1. Local 클래스](#21-local-클래스)
  * [2.2. 인터페이스에 포함된 클래스](#22-인터페이스에-포함된-클래스)
  * [2.3. 내포된 enum: `coerceAtMost()`](#23-내포된-enum-coerceatmost)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

# 1. 타입 검사

코틀린은 객체 타입에 기반하여 원하는 동작을 쉽게 수행할 수 있다.  
일반적으로 타입에 따른 동작은 다형성의 영역에 속하기 때문에 타입 검사를 통해 다양한 설계를 할 수 있다.

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

---

## 1.1. 소수의 특별한 타입을 위한 확장 함수 이용

```kotlin
// Any 를 수신 객체로 받은 후 ::class 를 통해 객체에 연관된 클래스 참조를 얻음
val Any.name
    get() = this::class.simpleName

interface Insect {
    fun walk() = "$name: walk~"
    fun fly() = "$name: fly~"
}

class HouseFly : Insect

class Flea : Insect {
    override fun fly() = throw Exception("Flea cannot fly.")
    fun crawl() = "Flea: crawl~"
}

fun Insect.basic() =
    walk() + " basic- " +
        if (this is Flea) {
            crawl()
        } else {
            fly()
        }

interface SwimmingInsect : Insect {
    fun swim() = "$name: swim~"
}

interface WaterWalker : Insect {
    fun walkWater() = "$name: walk on water~"
}

class WaterBeetle : SwimmingInsect

class WaterStrider : WaterWalker

class WhirligigBeetle : SwimmingInsect, WaterWalker

fun Insect.water() =
    when (this) {
        is SwimmingInsect -> swim()
        is WaterWalker -> walkWater()
        else -> "$name: drown."
    }

fun main() {
    val insects = listOf(HouseFly(), Flea(), WaterStrider(), WaterBeetle(), WhirligigBeetle())
    val result1 = insects.map { it.basic() }
    val result2 = insects.map { it.water() }

    // [HouseFly: walk~ basic- HouseFly: fly~, Flea: walk~ basic- Flea: crawl~,
    // WaterStrider: walk~ basic- WaterStrider: fly~, WaterBeetle: walk~ basic- WaterBeetle: fly~, WhirligigBeetle: walk~ basic- WhirligigBeetle: fly~]
    println(result1)

    // [HouseFly: drown., Flea: drown., WaterStrider: walk on water~, WaterBeetle: swim~, WhirligigBeetle: swim~]
    println(result2)
}
```

**위 코드처럼 극소수 타입에만 적용되는 기능은 기반 클래스에 넣는 것이 아니라 _Insect.water()_ 처럼 확장 함수를 통해 특별한 기능을 하는 타입을 걸러내고 나머지 모든 대상에 대해서는 표준적인 기능을 실행하는 when 식**을 이용하는 것이 좋다.

이렇게 특별한 처리를 위해 별도의 소수 타입을 선택하는 것은 타입 검사의 전형적인 케이스이다.

위 코드에서 아래 내용은 Any 를 수신 객체로 받은 후 ::class 를 통해 객체에 연관된 클래스 참조를 얻은 후 해당 클래스의 simpleName 을 돌려준다.

```kotlin
val Any.name
    get() = this::class.simpleName
```

---

## 1.2. 타입 검사 코딩

> 아래의 예시는 타입 검사 코딩의 예시로 안티 패턴 중 하나임

```kotlin
interface Shape {
    fun draw(): String
}

class Circle : Shape {
    override fun draw(): String = "circle: draw~"
}

class Square : Shape {
    override fun draw(): String = "square: draw~"
    fun rotate() = "square: rotate~"
}

fun turn(s: Shape) =
    when (s) {
        is Square -> s.rotate()
        else -> "none~"
    }

fun main() {
    val shapes = listOf(Circle(), Square())
    val result1 = shapes.map { it.draw() }
    val result2 = shapes.map { turn(it) }

    println(result1)    // [circle: draw~, square: draw~]
    println(result2)    // [none~, square: rotate~]
}
```

위 코드에서 _rotate()_ 를 _Shape_ 대신 _Square_ 에 넣은 이유는 아래와 같다.

- _Shape_ 인터페이스는 객발자가 제어할 수 있는 범위를 벗어났기 때문에 _Shape_ 는 변경 불가
- _Square_ 를 회전시키는 _rotate()_ 는 _Square_ 에만 적용할 연산임
- _Shape_ 에 _rotate()_ 를 넣으면 _Shape_ 의 모든 하위 타입에서 해당 함수를 구현해야 함

하지만 시스템이 운영되면서 더 많은 타입을 추가되면 코드가 지저분해지기 시작한다.

```kotlin
interface Shape1 {
    fun draw(): String
}

class Circle1 : Shape1 {
    override fun draw(): String = "circle: draw~"
}

class Square1 : Shape1 {
    override fun draw(): String = "square: draw~"
    fun rotate() = "square: rotate~"
}

// 새로운 클래스 추가됨
class Triangle1 : Shape1 {
    override fun draw() = "triangle: draw~"
    fun rotate() = "triangle: rotate~"
}

fun turn(s: Shape1) =
    when (s) {
        is Square1 -> s.rotate()
        else -> "none~"
    }

// 새로운 함수 추가 필요
fun turn2(s: Shape1) =
    when (s) {
        is Square1 -> s.rotate()
        is Triangle1 -> s.rotate()
        else -> "none~"
    }

fun main() {
    val shapes = listOf(Circle1(), Square1(), Triangle1())
    val result1 = shapes.map { it.draw() }
    val result2 = shapes.map { turn(it) }
    val result3 = shapes.map { turn2(it) }

    println(result1) // [circle: draw~, square: draw~, triangle: draw~]
    println(result2) // [none~, square: rotate~, none~]
    println(result3) // [none~, square: rotate~, triangle: rotate~]
}
```

위와 같이 **_turn()_, _turn2()_ 같은 함수가 점점 많아진다면 _Shape_ 의 로직은 이제 _Shape_ 계층 구조 안에 집중적으로 들어있지 않고 이 모든 함수에 분산**되어 버린다.  
**_Shape_ 의 하위 타입을 추가하면 _Shape_ 타입에 대해 타입을 검사해 처리하는 when 이 들어있는 모든 함수를 찾아서 새로 추가한 타입을 처리하도록 변경**해야 한다.    
**함수 중 누락한 부분이 있어도 컴파일러는 감지하지 못한다.**

위 코드에서 _turn()_, _turn2()_ 은 **타입 검사 코딩의 방식**이다.  
객체 지향 언어에서 **타입 검사 코딩은 안티 패턴**으로 간주한다.    
시스템에 타입을 추가하거나 변경할 때마다 유지 보수해야 하는 코드가 점점 많아지기 때문이다.

**반면에 다형성은 이런 변경 내용을 캡슐화하여 변경할 타입에 넣어주므로 변경 내용이 시스템 전체에 투명하게 전파**된다.

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

`sealed` 클래스를 사용하면 이런 문제를 완벽하진 않아도 크게 완화할 수 있다.  
`sealed` 클래스는 타입 검사 코딩이 훨씬 더 합리적인 설계적 선택이 되게끔 도와주기 때문이다.

> `sealed` 클래스에 대한 좀 더 상세한 내용은 [3. 봉인된 클래스: `sealed`](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#3-%EB%B4%89%EC%9D%B8%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-sealed) 를 참고하세요.

---

## 1.3. 외부 함수에서 타입 검사

아래는 _BeverageContainer_ 클래스가 음료수를 오픈하고 따르는 것이며, 재활용을 외부 함수로 다루는 예시이다. (잘못된 설계임)

```kotlin
interface BeverageContainer {
    fun open(): String
    fun pour(): String
}

class Can : BeverageContainer {
    override fun open() = "Can Open~"
    override fun pour() = "Can Pour~"
}

open class Bottle : BeverageContainer {
    override fun open() = "Bottle Open~"
    override fun pour() = "Bottle Pour~"
}

class GlassBottle : Bottle()

class PlasticBottle : Bottle()

fun BeverageContainer.recycle() =
    // when 에서 타입 검사
    when (this) {
        is Can -> "Recycle can~"
        is GlassBottle -> "Recycle Glass bottle~"
        else -> "Landfill"
    }

fun main() {
    val refrigerator = listOf(Can(), Bottle(), GlassBottle(), PlasticBottle())

    val result1 = refrigerator.map { it.open() }
    var result2 = refrigerator.map { it.recycle() }

    println(result1) // [Can Open~, Bottle Open~, Bottle Open~, Bottle Open~]
    println(result2) // [Recycle can~, Landfill, Recycle Glass bottle~, Landfill]
}
```

위 코드를 보면 _recycle()_ 을 외부 함수로 정의함으로써 _BeverageContainer_ 의 계층 구조에 분산시키지 않고 한 군데에 모아두었고, when 에서 타입에 대해 작용하는 것도 깔끔하다.  

하지만 위의 코드에도 문제점이 있다.

새로운 타입을 추가할 때는 _recycle()_ 에서 else 절을 사용하게 된다.    
새로운 타입 추가 시 _recycle()_ 과 같이 타입 검사를 사용하는 (= 꼭 수정해야 하는) 함수를 수정하지 않는 경우가 발생할 수 있다.  

원하는 것은 컴파일러가 _recycle()_ 과 같은 함수에서 타입 검사를 추가하지 않았음을 알려주는 것이다.

이 때 `sealed` 클래스를 사용하면 상황이 크게 개선된다.

> 개선되는 내용은 [3.1. 봉인된 클래스 사용](https://assu10.github.io/dev/2024/03/01/kotlin-object-oriented-programming-3/#31-%EB%B4%89%EC%9D%B8%EB%90%9C-%ED%81%B4%EB%9E%98%EC%8A%A4-%EC%82%AC%EC%9A%A9) 의 코드를 참고하세요.

---

## 1.4. `sealed` 클래스에서 외부 함수에서 타입 검사

아래는 위 코드에서 `sealed` 클래스를 _BeverageContainer_ 에 적용 시 발생하는 문제와 그에 대한 해법 예시이다.

```kotlin
sealed class BeverageContainer2 {
    abstract fun open(): String
    abstract fun pour(): String
}

sealed class Can2 : BeverageContainer2() {
    override fun open() = "can open~"
    override fun pour() = "can pour~"
}

class SteelCan2 : Can2()

class AluminumCan2 : Can2()

sealed class Bottle2 : BeverageContainer2() {
    override fun open() = "bottle open~"
    override fun pour() = "bottle pour~"
}

class GlassBottle2 : Bottle2()

sealed class PlasticBottle2 : Bottle2()

class PetBottle2 : PlasticBottle2()

class HepBottle2 : PlasticBottle2()

fun BeverageContainer2.recycle() =
    when (this) {
        is Can2 -> "recycle can~"
        is Bottle2 -> "recycle bottle~"
    }

fun BeverageContainer2.recycle2() =
    when (this) {
        is Can2 ->
            when (this) {
                is SteelCan2 -> "recycle steel~"
                is AluminumCan2 -> "recycle aluminum~"
            }

        is Bottle2 ->
            when (this) {
                is GlassBottle2 -> "recycle glass~"
                is PlasticBottle2 ->
                    when (this) {
                        is PetBottle2 -> "recycle pet-bottle~"
                        is HepBottle2 -> "recycle hep-bottle~"
                    }
            }
    }

fun main() {
    val refrigerator =
        listOf(
            SteelCan2(),
            AluminumCan2(),
            GlassBottle2(),
            PetBottle2(),
            HepBottle2(),
        )

    val result1 = refrigerator.map { it.open() }
    val result2 = refrigerator.map { it.recycle() }
    val result3 = refrigerator.map { it.recycle2() }

    println(result1)    // [can open~, can open~, bottle open~, bottle open~, bottle open~]
    println(result2)    // [recycle can~, recycle can~, recycle bottle~, recycle bottle~, recycle bottle~]
    println(result3)    // [recycle steel~, recycle aluminum~, recycle glass~, recycle pet-bottle~, recycle hep-bottle~]
}
```

위 코드가 제대로 동작하려면 중간 클래스인 _Can2_ 와 _Bottle2_ 도 `sealed` 가 되어야 한다.

클래스가 _BeverageContainer2_ 의 직접적인 파생 클래스인 한 컴파일러는 _recycle()_ 에 있는 when 의 모든 하위 타입을 검사하도록 보장한다.  
하지만 _GlassBottle2_ 와 _AluminumCan2_ 과 같은 하위 타입은 검사가 불가하다.

이러한 문제를 해결하려면 **_recycle2()_ 처럼 when 안에 다른 when 을 내포시켜서 컴파일러가 모든 타입을 검사**할 수 있도록 하면 된다.

이렇게 **견고한 검사 해법을 만들려면 클래스 계층의 각 단계에서 `sealed` 를 적용하면서 when 에서 각 `sealed` 클래스에 해당하는 부분에 when 을 통한 타입 검사를 꼭 내포**시켜야 한다.

사실 이런 문제는 상속을 여러 단계에 걸쳐서 수행할 때만 발생한다.

만일 _recycle()_ 을 아래와 같이 _BeverageContainer2_ 안에 넣으면 _BeverageContainer2_ 를 인터페이스로 정의할 수 있다.

```kotlin
interface BeverageContainer3 {
  fun open(): String
  fun pour() = "pour~"
  fun recycle(): String
}

abstract class Can3: BeverageContainer3 {
  override fun open() = "can open~"
}

class SteelCan3: Can3() {
  // Can3 클래스가 abstract 이므로 recycle() 를 오버라이드 해야함
  override fun recycle() = "can recycle~"
}
```

이렇게 _Can3_ 을 abstract 클래스로 정의함으로써 컴파일러는 모든 파생 클래스가 _recycle()_ 을 오버라이드 하도록 강제할 수 있다.  
이렇게 하면 _recycle()_ 의 행동 방식이 여러 클래스에 분산된다.

따라서 특정 함수의 기능이 자주 바뀌기 때문에 한 군데서 이를 처리하고 싶다면 첫 코드의 _BeverageContainer2.recycle2()_ 처럼 외부 함수 안에서 타입 검사를 하는 것이 
더 좋은 선택일 수 있다.

---

# 2. 내포된 클래스(nested class)

내포된 클래스는 단순히 외부 클래스의 name space 안에 정의된 클래스로, **내포된 클래스를 사용하면 객체 안에 더 세분화된 구조를 정의**할 수 있다.

아래 코드에서 _Plane_ 과 _PrivatePlane_ 은 내포된 클래스이다.

```kotlin
package assu.study.kotlinme.chap05.nastedClasses
import assu.study.kotlinme.chap05.nastedClasses.Airport.Plane

class Airport(private val code: String) {
    // 내포된 클래스 (Airport name space 안에 정의된 클래스)
    open class Plane {
        // 자신을 둘러싼 클래스의 private 프로퍼티(private val code)에 접근 가능
        fun contact(airport: Airport) = "contacting ${airport.code}"
    }

    // 내포된 클래스이면서 private
    private class PrivatePlane : Plane()

    // 결과를 public 타입인 Plane 으로 업캐스트하여 반환
    fun privatePlane(): Plane = PrivatePlane()
}

fun main() {
    val korea = Airport("KOR")

    // Plane 객체 생성 시 Airport 객체가 필요없음
    var plane = Plane()

    val result1 = plane.contact(korea)
    println(result1) // contacting KOR

    // 아래와 같은 오류가 뜨면서 컴파일되지 않음
    // Cannot access 'PrivatePlane': it is private in 'Airport'

    // val privatePlane = Airport.PrivatePlane()

    val japan = Airport("JPN")
    plane = japan.privatePlane()
    val result2 = plane.contact(japan)

    println(result2) // contacting JPN
    
    // 컴파일 오류
    // 외부에서 받은 public 타입의 객체 참조(Plane) 을 다시 private 타입(PrivatePlane) 으로 다운캐스트 불가 
    //val p = plane as PrivatePlane
}
```

위 코드에서 _contact()_ 에서 내포된 클래스인 _Plane_ 은 인자로 받은 _airport_ 의 private 프로퍼티인 _code_ 에 접근 가능하지만, 일반 클래스는 
다른 클래스의 private 프로퍼티에 접근할 수 없다.

---

아래 코드를 보면 _Plane_ 객체 생성 시 _Airport_ 객체가 필요하지는 않다.  
만일 _Airport_ 클래스 본문 밖에서 _Plane_ 객체를 생성하려고 한다면 일반적으로 생성자 호출을 한정시켜야 하는데,  
_.nastedClasses.Airport.Plane_ 를 import 하면 _Plane_ 을 한정시키지 않을 수 있다.

```kotlin
import assu.study.kotlinme.chap05.nastedClasses.Airport.Plane

...

var plane = Plane()
```

---

_PrivatePlane_ 은 **내포된 클래스이면서 private** 이다.  
따라서 Airport 밖에서는 _PrivatePlane_ 에 직접 접근할 수 없으며, _PrivatePlane_ 의 생성자를 호출할 수도 없다.

```kotlin
// 아래와 같은 오류가 뜨면서 컴파일되지 않음
// Cannot access 'PrivatePlane': it is private in 'Airport'

// val privatePlane = Airport.PrivatePlane()
```

**_privatePlane()_ 처럼 _Airport_ 의 멤버 함수가 _PrivatePlane_ 을 반환한다면 결과를 public 타입으로 업캐스트해서 반환(_Plane_ 으로 업캐스트)**해야 하며,  
**_Airport_ 밖에서 이렇게 받은 public 타입의 객체 참조를 다시 private 타입으로 다운캐스트(_PrivatePlane_) 할 수는 없다.**

```kotlin
...

// 결과를 public 타입인 Plane 으로 업캐스트하여 반환
fun privatePlane(): Plane = PrivatePlane()

...

// 외부에서 받은 public 타입의 객체 참조(Plane) 을 다시 private 타입(PrivatePlane) 으로 다운캐스트 불가 
// val p = plane as PrivatePlane
```

---

아래는 _Cleanable_ 이 외부 클래스인 _House_ 와 _House_ 의 모든 내포 클래스의 상위 타입인 경우이다.  
_clean()_ 은 _parts_ 의 List 에 대해 이터레이션하면서 각각의 _clean()_ 을 호출 (일종의 재귀) 한다.

여러 수준의 내포가 이루어져 있는 코드이다.

```kotlin
abstract class Cleanable(val id: String) {
    open val parts: List<Cleanable> = listOf()

    fun clean(): String {
        val text = "id is $id clean~"
        if (parts.isEmpty()) {
            return text
        }
        return "${
            parts.joinToString(
                separator = " ",
                prefix = "(",
                postfix = ")",
                transform = Cleanable::clean, // 각 요소를 변환하는 함수 지정
            )
        }~  $text~\n"
    }
}

class House : Cleanable("House") {
    override val parts =
        listOf(
            Bedroom("Master bedroom"),
            Bedroom("Guest bedroom"),
        )

    // 내포 클래스: 1 depth
    class Bedroom(id: String) : Cleanable(id) {
        override val parts = listOf(Closet(), Bathroom())

        // 내포 클래스: 2 depth
        class Closet : Cleanable("Closet") {
            override val parts = listOf(Shelf(), Shelf())

            // 내포 클래스: 3 depth
            class Shelf : Cleanable("Shelf")
        }

        // 내포 클래스: 2 depth
        class Bathroom : Cleanable("Bathroom") {
            override val parts = listOf(Toilet(), Sink())

            // 내포 클래스: 3 depth
            class Toilet : Cleanable("Toilet")

            // 내포 클래스: 3 depth
            class Sink : Cleanable("Sink")
        }
    }
}

fun main() {
    val result = House().clean()

    // (((id is Shelf clean~ id is Shelf clean~)~  id is Closet clean~~
    // (id is Toilet clean~ id is Sink clean~)~  id is Bathroom clean~~
    // )~  id is Master bedroom clean~~
    // ((id is Shelf clean~ id is Shelf clean~)~  id is Closet clean~~
    // (id is Toilet clean~ id is Sink clean~)~  id is Bathroom clean~~
    // )~  id is Guest bedroom clean~~
    // )~  id is House clean~~
    println(result)
}
```

---

## 2.1. Local 클래스

> Local open 클래스는 거의 정의하지 않는 것을 권장함

> 코틀린은 한 파일안에 여러 최상위 클래스나 함수 정의가 가능함.  
> 따라서 Local 클래스를 사용할 필요가 거의 없음.  
> **Local 클래스로는 아주 기본적이고 단순한 클래스만 사용**해야 함.  
> 
> 예를 들어 **함수 내부에서 data 클래스를 정의해서 사용하는 것은 합리적**이며,  
> **Local 클래스가 복잡해지면 이 Local 클래스를 함수에서 꺼내서 일반 클래스로 격상**시켜야 함

**Local 클래스는 함수 안에 내포된 클래스**이다.

```kotlin
fun localClasses() {
    // Local 클래스
    open class Amphibian
    class Frog: Amphibian()
    val amphibian: Amphibian = Frog()
}
```

_Amphibian_ 는 interface 이어야할 것 같지만 **Local interface 는 허용되지 않는다.**

위 코드에서 _Amphibian_ 과 _Frog_ 는 _localClasses()_ 밖에서는 볼 수 없기 때문에 이런 클래스를 함수가 반환할 수도 없다.  
**Local 클래스의 객체를 반환하려면 그 객체를 함수 밖에서 정의한 인터페이스나 클래스로 업캐스트**해야 한다.

```kotlin
interface Amphibian

fun createAmphibian(): Amphibian {
    // Local 클래스인 Frog 를 반환하기 위해 클래스 밖에서 정의한 인터페이스인 Amphibian 으로 업캐스트
    class Frog : Amphibian
    return Frog()
}

fun main() {
    val amphibian = createAmphibian()
    println(amphibian)  // assu.study.kotlinme.chap05.nastedClasses.ReturnLocalKt$createAmphibian$Frog@4f3f5b24
    
    // createAmphibian() 외부에서는 Frog 를 알지 못하기 때문에 업캐스트 불가
    //amphibian as Frog
}
```

---

## 2.2. 인터페이스에 포함된 클래스

**인터페이스 안에 클래스를 내포**시킬 수도 있다.

```kotlin
interface Item {
    val type: Type

    // 인터페이스안에 내포된 클래스
    data class Type(val type: String)
}

class Bolt(type: String) : Item {
    override val type = Item.Type(type)
}

fun main() {
    val items = listOf(Bolt("aa"), Bolt("bb"))

    val result1 = items.map(Item::type)
    val result2 = items.map { Item::type }  // Suspicious callable reference as the only lambda element 

    // [Type(type=aa), Type(type=bb)]
    println(result1)

    // [val assu.study.kotlinme.chap05.nastedClasses.Item.type: assu.study.kotlinme.chap05.nastedClasses.Item.Type
    // , val assu.study.kotlinme.chap05.nastedClasses.Item.type: assu.study.kotlinme.chap05.nastedClasses.Item.Type]
    println(result2)
}
```

---

## 2.3. 내포된 enum: `coerceAtMost()`

**enum 도 클래스이므로 다른 클래스안에 내포**될 수 있다.

```kotlin
@file:Suppress("ktlint:standard:no-wildcard-imports")

import assu.study.kotlinme.chap05.nastedClasses.Ticket.Seat.*

class Ticket(
    val name: String,
    val seat: Seat = Coach,
) {
    // 내포된 enum
    enum class Seat {
        Coach,
        Premium,
        First,
    }

    fun upgrade(): Ticket {
        // 결과값을 values() 인덱스로 사용하여 새로운 Seat enum 타입값을 만듦
        val newSeat =
            Ticket.Seat.values()[
                // 호출된 객체(seat.ordinal + 1)가 특정 객체(First.ordinal)보다 더 작으면 호출된 객체 반환, 아니면 최대 객체 반환
                (seat.ordinal + 1).coerceAtMost(First.ordinal),
            ]
        return Ticket(name, newSeat)
    }

    // when 을 사용하여 모든 Seat 타입 검사
    fun meal() =
        when (seat) {
            Coach -> "coach meal~"
            Premium -> "premium meal~"
            First -> "first meal~"
        }

    override fun toString() = "$seat~"
}

fun main() {
    val tickets =
        listOf(
            Ticket("AAA"),
            Ticket("BBB", Premium),
            Ticket("CCC", First),
        )

    val result1 = tickets.map(Ticket::meal)
    val result2 = tickets.map(Ticket::upgrade)

    println(tickets) // [Coach~, Premium~, First~]
    println(result1) // [coach meal~, premium meal~, first meal~]
    println(result2) // [Premium~, First~, First~]
}
```

위 코드에서 when 은 모든 Seat 타입을 검사하므로 이 부분을 다형성으로 구현할 수도 있다.

> 다형성에 대한 좀 더 상세한 내용은 [3. 다형성 (polymorphism)](https://assu10.github.io/dev/2024/02/25/kotlin-object-oriented-programming-2/#3-%EB%8B%A4%ED%98%95%EC%84%B1-polymorphism) 을 참고하세요.

---

**enum 은 함수에 내포시킬 수 없고, enum 이 다른 클래스를 상속할 수도 없다.**

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 브루스 에켈, 스베트라아 이사코바 저자의 **아토믹 코틀린**을 기반으로 스터디하며 정리한 내용들입니다.*

* [아토믹 코틀린](https://www.yes24.com/Product/Goods/117817486)
* [아토믹 코틀린 예제 코드](https://github.com/gilbutITbook/080301)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)