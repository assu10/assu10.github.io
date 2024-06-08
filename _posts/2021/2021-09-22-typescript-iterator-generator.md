---
layout: post
title:  "Typescript - 반복기, 생성기"
date:   2021-09-22 10:00
categories: dev
tags: typescript
---

이 포스트는 함수형 프로그래밍의 일부인 선언형 프로그래밍과 함수형 프로그래밍을 가능하게 하는 순수 함수를 다루면서 배열과 튜플에 대해 알아본다. 

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

<!-- TOC -->
  * [1. 반복기 (`iterator`)](#1-반복기-iterator)
    * [1.1. 반복기(`iterator`)와 반복기 제공자(`iterable`)](#11-반복기iterator와-반복기-제공자iterable)
    * [1.2. 반복기 (`iterator`) 가 필요한 이유](#12-반복기-iterator-가-필요한-이유)
    * [1.3. `for...of` 구문과 `[Symbol.iterator]` 메서드](#13-forof-구문과-symboliterator-메서드)
    * [1.4. Iterable<T> 인터페이스와 Iterator<T> 인터페이스](#14-iterablet-인터페이스와-iteratort-인터페이스)
  * [2. 생성기 (`generator`)](#2-생성기-generator)
    * [2.1. `setInterval` 함수와 생성기 비교](#21-setinterval-함수와-생성기-비교)
    * [2.2. `yield` 키워드](#22-yield-키워드)
    * [2.3. 반복기 제공자의 메서드로 동작하는 생성기 구현](#23-반복기-제공자의-메서드로-동작하는-생성기-구현)
    * [2.4. `yield*` 키워드](#24-yield-키워드)
    * [2.5. `yield` 반환값](#25-yield-반환값)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## 1. 반복기 (`iterator`)

이번 포스트에서는 `tsconfig.json` 의 `downlevelIteration` 설정을 true 로 설정해야 한다.

>`downlevelIteration` 의 자세한 내용은 [Typescript 기본](https://assu10.github.io/dev/2021/09/11/typescript-basic/) 의 *4.1. tsconfig.json* 을 참고하세요.

tsconfig.json
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "esModuleInterop": true,
    "target": "ES2015",
    "moduleResolution": "node",
    "outDir": "dist",
    "baseUrl": ".",
    "sourceMap": true,
    "downlevelIteration": true,
    "strict": true,
    "noImplicitThis": false,
    "paths": { "*": ["node_modules/*"] }
  },
  "include": ["src/**/*"]
}
```

### 1.1. 반복기(`iterator`)와 반복기 제공자(`iterable`)

[Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *1.3. `for...in`, `for...of`* 에서 `for...of` 구문은
아래처럼 타입에 무관하에 배열에 담긴 값을 차례로 얻는데 활용된다고 하였다.

```ts
// for...of

const numArray: number[] = [1, 2, 3]
for (let value of numArray) {
    console.log(value)  //  1 2 3
}

const strArray: string[] = ['a', 'b', 'c']
for (let value of strArray) {
    console.log(value)  // a b c
}
```

`for...of` 구문은 `반복기 (iterator)` 라는 주제로 흔히 찾아볼 수 있는데 대부분 프로그래밍 언어에서 `반복기 (iterator)` 는 다음과 같은 특징이 있는 객체이다.

- **`반복기 (iterator)`**
    - `next` 메서드 제공
    - `next` 메서드는 `value` 와 `done` 이라는 2개의 속성을 가진 객체를 반환

아래 코드에서 *createRangeIterable* 함수는 **`next` 메서드가 있는 객체를 반환**하므로 이 함수는 `반복기 (iterator)` 를 제공하는 역할을 한다.<br />
이렇게 `반복기 (iterator)` 를 제공하는 역할을 하는 함수를 `반복기 제공자 (iterable)` 라고 한다.

createRangeIterable.ts
```ts
// 반복기와 반복기 제공자

export const createRangeIterable = (from: number, to: number) => {
  let currentValue = from
  return {
    next() {
      const value = currentValue < to ? currentValue++ : undefined
      const done = value == undefined
      return {value, done}
    }
  }
}
```

index.ts
```ts
// 반복기와 반복기 제공자

import { createRangeIterable } from "./createRangeIterable";

const iterator = createRangeIterable(1, 3+1)    // 반복기는 현재 동작하지 않음

while(true) {
  const {value, done} = iterator.next();  // 반복기 동작
  if (done) {
    break
  }
  console.log(value)  // 1 2 3
}
```

위처럼 반복기는 반복기 제공자를 호출해야만 얻을 수 있다. 

>타입스크립트로 `for...of` 구문을 작성하면 TSC 컴파일러는 이처럼 반복기 제공자와 반복기를 사용하는 코드로 바꿔준다. 

---

### 1.2. 반복기 (`iterator`) 가 필요한 이유

결론부터 말하면 반복기 사용 시 일반 반복문보다 메모리를 훨씬 적게 소모하기 때문이다.

바로 위의 코드를 보면 *iterator.next()* 메서드가 반복 호출될 때마다 반복기 제공자가 생성한 값 1, 2, 3 을 배열에 담아서 출력하는 것이 아니라
마치 for 문을 돌면서 값을 찍어내는 듯한 모습니다.

**반복기 제공자는 이렇게 어떤 범위의 값을 한꺼번에 생성해서 배열에 담는 것이 아니라 값이 필요할 때만 생성**한다.

아래는 [Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *1.6. 전개 연산자를 사용하여 range 함수 구현* 에서 보았던 전개 연산자를 이용한 range 함수이다.

```ts
// 재귀 함수 스타일로 동작하도록 구현
const range = (from: number, to: number): number[] => from < to ? [from, ...range(from+1, to)]: []
```

*createRangeIterator* 함수는 값이 필요한 시점에 생성하지만, *range* 함수는 값이 필요한 시점보다 이전에 미리 생성한다.<br />
따라서 시스템 메모리의 효율성으로 보면 반복기를 사용하는 *createRangeIterator* 함수가 메모리를 훨씬 적게 소모한다.

---

### 1.3. `for...of` 구문과 `[Symbol.iterator]` 메서드

바로 위의 *range* 함수는 `for...of` 구문을 사용할 수 있지만 (=필요 값을 미리 생성해놓으므로) *createRangeIterator* 함수를 `for...of` 구문에 사용하면
`[Symbol.iterator]() 메서드가 없다` 는 오류가 발생한다.

```ts
// `for...of` 구문과 `[Symbol.iterator]` 메서드 - 오류

import { createRangeIterable } from "./createRangeIterable";

const iterator = createRangeIterable(1, 3+1)    // 반복기는 현재 동작하지 않음

for (let value of iterator) {   // TS2488: Type '{ next(): { value: number | undefined; done: boolean; }; }' must have a '[Symbol.iterator]()' method that returns an iterator.
    console.log(value)
}
```

이 오류는 *createRangeIterator* 함수를 아래 *RangeIterable* 처럼 `[Symbol.iterable]` 메서드를 구현하는 클래스로 만들어야 한다는 것을 의미한다.

RangeIterable.ts
```ts
// `for...of` 구문과 `[Symbol.iterator]` 메서드

export class RangeIterable {
    // 생성자 매개변수에 public 접근 제한자를 붙이면 해당 매개변수의 이름을 가진 속성이 클래스에 선언된 것처럼 동작
    constructor(public from: number, public to: number) { }
    [Symbol.iterator]() {
        const that = this
        let currentValue = that.from
        return {
            next() {
                const value = currentValue < that.to ? currentValue++ : undefined
                const done = value == undefined
                return {value, done}
            }
        }
    }
}
```

클래스의 메서드도 `function` 키워드가 생략되었을 뿐 사실상 `function` 키워드로 만들어지는 함수이다.<br />
`function` 키워드로 만들어지는 함수는 내부에서 `this` 키워드를 사용할 수 있는데 컴파일러가 *[Symbol.iterator]()* 의 `this` 와 *next* 함수의 `this` 를 구분할 수 있도록 
`const that = this` 와 같은 코드 트릭을 사용하였다. 

index.ts
```ts
// `for...of` 구문과 `[Symbol.iterator]` 메서드 - 오류

import { RangeIterable } from "./RangeIterable";

const iterator = new RangeIterable(1, 3+1)

for (let value of iterator) {
    console.log(value)  // 1 2 3
}
```

---

### 1.4. Iterable<T> 인터페이스와 Iterator<T> 인터페이스

타입스크립트는 반복기 제공자에 `Iterable<T>` 인터페이스와 `Iterator<T>` 인터페이스를 제공한다.<br />

- **`Iterable<T>` 인터페이스**
  - 자신을 구현하는 클래스가 `[Symbol.iterator]` 메서드를 제공한다는 것을 명확하게 알려주는 역할
- **`Iterator<T>` 인터페이스**
  - 반복기가 생성할 값의 타입을 명확하게 해주는 역할

```ts
class 구현 클래스 implements Iterable<생성할 값의 타입> { }
```

```ts
[Symbol.iterator](): Iterator<생성할 값의 타입> { }
```

StringIterable.ts
```ts
// Iterable<T> 와 Iterator<T> 인터페이스

export class StringIterable implements Iterable<string> {
    constructor(private strings: string[], private currentIndex: number = 0) { }
    [Symbol.iterator](): Iterator<string> {
        const that = this
        let currentIndex = that.currentIndex
        let length = that.strings.length

        const iterator: Iterator<string> = {
            next(): {value: any, done: boolean} {
                const value = currentIndex < length ? that.strings[currentIndex++] : undefined
                const done = value == undefined
                return {value, done}
            }
        }
        return iterator
    }
}
```

index.ts
```ts
// Iterable<T> 와 Iterator<T> 인터페이스

import { StringIterable } from "./StringIterable";

for (let value of new StringIterable(['hello', 'world', '!'])) {
    console.log(value)  // hello world !
}
```

지금까지 반복기 제공자와 이를 이용해 반복기를 얻어 사용하는 방법에 대해 알아보았는데 이제 반복기를 쉽게 만들어주는 `생성기 (generator)` 에 대해 알아보자.

---

## 2. 생성기 (`generator`)

[ES2015+ (ES6+) 기본](https://assu10.github.io/dev/2021/08/01/js-basic/) 의 1.10. 생성기 (generator) function* 에서 잠시 살펴본 적 있다. 

ESNext 자바스크립트와 타입스크립트는 `yield` 라는 키워드를 제공한다.<br />
`yield` 는 `return` 키워드처럼 값을 반환하고, 반드시 `function*` 키워드를 사용한 함수에서만 호출이 가능하다.

이렇게 `function*` 키워드로 만든 함수를 `생성기 (generator)` 라고 한다.

- **생성기**
  - `function*` 키워드로 선언된 함수
  - 오직 `function*` 키워드로 선언해야 하므로 화살표 함수로는 만들 수 없음
  - 반복기를 제공하는 반복기 제공자로서 동작
  - 몸통 안에 `yield` 문이 있음

generator.ts
```ts
// 생성기 (generator)

export function* generator() {
    console.log('generator start..')

    let value: number = 1
    while(value < 4) {      // yield 문을 3회 반복 호출
        yield value++
    }

    console.log('generator end..')
}
```

index.ts
```ts
// 생성기 (generator)

import { generator } from "./generator";

for (let value of generator()) {
    console.log(value)
/*    generator start..
    1
    2
    3
    generator end..*/
}
```

### 2.1. `setInterval` 함수와 생성기 비교

생성기가 동작하는 방식을 `세미코루틴 (semi-coroutine, 반협동 루틴)` 이라고 한다.

> **세미코루틴 (semi-coroutine, 반협동 루틴)**<br />
> 타입스크립트처럼 단일 스레드로 동작하는 프로그래밍 언어가 마치 다중 스레드로 동작하는 것처럼 보이게 하는 기능

`setInterval` 은 지정한 주기로 콜백 함수를 계속 호출한다.
```ts
const intervalID = setInterval(콜백 함수, 호출 주기)
```

`clearInterval` 함수를 사용하여 `setInterval` 함수를 멈출 수 있다.
```ts
clearInterval(intervalID)
```

아래는 `setInterval` 함수를 사용하여 1초 간격으로 1, 2, 3 을 출력하는 코드이다.
```ts
// `setInterval` 함수와 생성기 비교

const period: number = 1000
let count: number = 0

console.log('start..')

const id = setInterval(() => {
    if (count >= 3) {
        clearInterval(id)
        console.log('end..')
    } else {
        console.log(++count)
    }
}, period)

/*
start..
1
2
3
end..
*/
```

위 코드를 보면 *start..* 를 출력하고 setInterval 을 동작시킨 부분이 메인 스레드, setInterval 의 콜백 함수는 작업 스레드를 떠올리게 한다.<br />
생성기는 이처럼 일반적인 타입스크립트 코드와는 조금 다른 방식으로 동작한다.

---

### 2.2. `yield` 키워드

생성기 함수 안에는 `yield` 문을 사용할 수 있는데, 이 `yield` 는 연산자 형태로 동작한다.

- **yield 기능**
  - 반복기를 자동으로 만들어 줌
  - 반복기 제공자의 역할도 수행

```ts
// `yield` 키워드

function* rangeGenerator(from: number, to: number) {
  let value: number = from
  while (value < to) {
    yield value++
  }
}

// while 패턴으로 동작하는 생성기
let iterator = rangeGenerator(1, 3+1)
while (1) {
  const {value, done} = iterator.next()
  if (done) {
    break
  }
  console.log(value)  // 1 2 3
}


// for...of 패턴으로 동작하는 생성기
for (let value of iterator) {
  console.log(value) // 위에서 3이 되었으므로 아무것도 출력안됨
}
```

---

### 2.3. 반복기 제공자의 메서드로 동작하는 생성기 구현

1.4. Iterable<T> 인터페이스와 Iterator<T> 인터페이스 에서 StringIterable 클래스로 반복기 제공자를 구현했었다.
생성기는 반복기 제공자로서 동작하므로 생성기를 사용하면 좀 더 간결히 구현할 수 있다. 

기존 StringIterable 클래스
```ts
// Iterable<T> 와 Iterator<T> 인터페이스

export class StringIterable implements Iterable<string> {
    constructor(private strings: string[], private currentIndex: number = 0) { }
    [Symbol.iterator](): Iterator<string> {
        const that = this
        let currentIndex = that.currentIndex
        let length = that.strings.length

        const iterator: Iterator<string> = {
            next(): {value: any, done: boolean} {
                const value = currentIndex < length ? that.strings[currentIndex++] : undefined
                const done = value == undefined
                return {value, done}
            }
        }
        return iterator
    }
}
```

function* 생성자로 구현
```ts
// 반복기 제공자의 메서드로 동작하는 생성기 구현

class IterableUsingGenerator<T> implements Iterable<T> {
    constructor(private values: T[] = [], private currentIndex: number = 0) { }
    [Symbol.iterator] = function* () {
        while (this.currentIndex < this.values.length) {        // "noImplicitThis": false
            yield this.values[this.currentIndex++]
        }
    }
}

for (let item of new IterableUsingGenerator([1, 2, 3])) {
    console.log(item)   //  1 2 3
}

for (let item of new IterableUsingGenerator(['hello', 'world', '!'])) {
    console.log(item)   // hello world !
}
```

---

### 2.4. `yield*` 키워드

- yield
  - 단순히 값을 대상으로 동작
- yield*
  - 다른 생성기나 배열을 대상으로 동작

```ts
// yield*` 키워드

1 function* gen12() {
2     yield 1
3     yield 2
4 }

5 function* gen12345() {
6     yield* gen12()
7     yield* [3,4]
8     yield 5
9 }

10 for (let value of gen12345()) {
11     console.log(value)  // 1 2 3 4 5
12 }
```

위 코드는 아래와 같이 동작한다. 

- 10행에서 gen12345 함수를 호출하므로 6행이 호출됨
- yield* 구문에 의해 1행의 gen12 함수가 호출되어 2행의 yield 문이 값 1을 생성
- 이 상태로 코드 정지

- 다시 for 문에 의해 다시 6행이 호출됨
- 2행에서 정지가 풀리면서 3행에 의해 값 2 생성
- 이 상태로 코드 정지

- 이후 다시 6행이 호출되지만 더 실행할 yield 문이 없으므로 7행이 실행되어 값 3 생성
- 이 상태로 코드 정지

- 다시 for 문에 의해 7행이 실행되면 값 4 생성하고 다시 코드 정지

- 값 5가 생성되면 for 문이 종료되어 프로그램 종료

---

### 2.5. `yield` 반환값

`yield` 연산자는 값을 반환한다.

```ts
// `yield` 반환값

function* gen() {
    let count: number = 5
    let select: number = 0  // 처음엔 항상 0 이 출력
    while (count--) {
        select = yield `you select ${select}`   // yield 연산자의 반환값을 select 에 저장
    }
}

const random = (max: number, min: number = 0) => Math.round(Math.random() * (max-min)) + min

const iter = gen()
while (true) {
    const {value, done} = iter.next(random(10, 1))  // yield 연산자의 반환값은 반복기의 next 메서드 호출 시 매개변수에 전달하는 값
    if (done) {
        break
    }
    console.log(value)
}
/*
you select 0
you select 4
you select 8
you select 10
you select 7
*/
```

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)