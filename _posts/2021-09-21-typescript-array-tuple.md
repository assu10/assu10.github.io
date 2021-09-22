---
layout: post
title:  "Typescript - 배열, 튜플"
date:   2021-09-21 10:00
categories: dev
tags: typescript
categories: dev
---

이 포스트는 함수형 프로그래밍의 일부인 선언형 프로그래밍과 함수형 프로그래밍을 가능하게 하는 순수 함수를 다루면서 배열과 튜플에 대해 알아본다. 

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

> - 배열
>   - split, join
>   - 배열의 비구조화 (잔여 연산자와 전개 연산자, `...`)
>   - for...in, for...of
>   - 제네릭 방식 타입
>   - 제네릭 방식 타입 추론
>   - 전개 연산자를 사용하여 range 함수 구현
> - 배열의 filter, map, reduce 메서드
>   - filter 메서드
>   - map 메서드
>   - reduce 메서드
> - 순수 함수와 배열
>   - 순수 함수
>   - 타입 수정자 readonly
>   - 깊은 복사, 얕은 복사
>   - 순수 함수로 splice 메서드 구현 (원본 배열 유지하면서 특정 아이템 삭제)
>   - 순수 함수로 가변 인수 함수 구현
> - 튜플
>   - 튜플에 타입 별칭 사용, 비구조화 할당 사용

---

## 1. 배열

자바스크립트에서 배열은 다른 언어와 다르게 객체이다.<br />
배열은 Array 클래스의 인스턴스인데 클래스의 인스턴스는 객체이기 때문이다.

`Array.isArray()` 는 전달받은 심벌이 배열인지 객체인지 알려주는 역할을 한다.

```ts
//  배열

let a = [1, 2, 3]
let o = {name: 'assu'}

console.log(Array.isArray(a), Array.isArray(o)) // true, false
```

배열의 타입은 `아이템 타입[]` 이다.

```ts
//  배열의 타입

let numArr: number[] = [1, 2, 3]

type IPerson = {name: string, age?: number}
let personArr: IPerson[] = [{name: 'assu'}, {name: 'jhlee', age:20}]

console.log(numArr);    // [ 1, 2, 3 ]
console.log(personArr); // [ { name: 'assu' }, { name: 'jhlee', age: 20 } ]
```

---

### 1.1. split, join

다른 언어에서는 문자열(string) 을 문자(character) 들의 배열로 간주하지만 타입스크립트에서는 문자 타입이 없기 때문에 문자열을 가공하려면 문자열을 배열로 전환해야 한다.

String 클래스의 `split 메서드`를 이용하여 문자열을 배열로 만들 수 있다.<br />
string[] 타입의 배열을 다시 string 으로 변경 시엔 Array 클래스의 `join 메서드` 를 사용한다.

```ts
split(구분자: string): string[]
join(구분자: string): string
```

```ts
// split, join

console.log('hello'.split(''))          // [ 'h', 'e', 'l', 'l', 'o' ]
console.log('h_e_l_l_o'.split('_'))     // [ 'h', 'e', 'l', 'l', 'o' ]

console.log([ 'h', 'e', 'l', 'l', 'o' ].join())     // h,e,l,l,o
console.log([ 'h', 'e', 'l', 'l', 'o' ].join(''))   // hello
console.log([ 'h', 'e', 'l', 'l', 'o' ].join('_'))  // h_e_l_l_o
```

---

### 1.2. 배열의 비구조화 (잔여 연산자와 전개 연산자, `...`)

```ts
// 배열의 비구조화

// 잔여 연산자
let array = [1,2,3,4,5]
let [first, second, third, ...rest] = array
console.log(first, second, third, rest)     // 1 2 3 [ 4, 5 ]

// 전개 연산자
let arr1: number[] = [1]
let arr2: number[] = [1,2,3]
let mergedArr: number[] = [...arr1, ...arr2, 4]

console.log(mergedArr)  // [ 1, 1, 2, 3, 4 ]
```

---

### 1.3. for...in, for...of

ESNext 자바스크립트와 타입스크립트에서 제공하는 반복문이다.<br />
`for...in` 은 배열의 인덱스값을 대상으로 순회하는 반면 `for...of` 는 배열의 아이템값을 대상으로 순회한다.

```ts
for (let 변수 in 객체) {
    
}
```

```ts
for (let 변수 of 객체) {
    
}
```

```ts
// for...in, for...of

// 배열인 경우 for...in
let array = ['assu', 'jh', 'lee']
for (let index in array) {
    const name = array[index]
    console.log(`${index} - ${name}`)
}

// 객체인 경우 for...in
let obj = {name: 'assu', age: 20}
for (let prop in obj) {
    console.log(`${prop} ${obj[prop]}`)     // tsconfig.json 의 stric 이 false 이어야 함
}

// 배열인 경우 for...of
for (let name of array) {
    console.log(name)
}
```

---

### 1.4. 제네릭 방식 타입

배열을 다루는 함수를 작성할 때 number[] 와 같이 타입이 고정된 함수보다는 `T[]` 형태로 배열의 아이템 타입을 한꺼번에 표현하는 것이 편리하다.

타입을 `T` 와 같은 일종의 변수(타입 변수)로 취급하는 것을 `제네릭 타입` 이라고 한다.

```ts
// 제네릭 방식 타입

let numArray: number[] = [1, 2, 3]
let strArray: string[] = ['one', 'two'];

type IPerson = {name: string, age?: number}
let personArray: IPerson[] = [{name: 'assu'}, {name: 'jhlee', age: 20}]

const arrayLength = (array: string[]) => array.length
const arrayGenericLength = <T>(array: T[]): number => array.length
const isEmpty = <T>(array: T[]): boolean => arrayGenericLength(array) == 0

console.log(
    arrayGenericLength(numArray),   // 3
    arrayGenericLength(strArray),   // 2
    arrayGenericLength(personArray),    // 2
    isEmpty([]),    // true
    isEmpty([1])    // false
)
```

---

### 1.5. 제네릭 방식 타입 추론

제네릭 형태로 구현된 함수는 원칙적으로는 아래와 같이 명시해주어야 한다.
```ts
함수명<타입 변수>(매개 변수)
```

```ts
let fn = <T>(n: T): T => n
```
하지만 코드가 번거로워지므로 타입스트립트는 타입 변수 부분을 생략할 수 있게 해준다.

```ts
// 제네릭 방식 타입 추론

console.log(
    fn<boolean>(true),  // true
    fn(true)        // true
)
```

---

### 1.6. 전개 연산자를 사용하여 range 함수 구현

위의 *1.2. 배열의 비구조화 (잔여 연산자와 전개 연산자, `...`)* 에서 본 전개 연산자를 사용하면 `ramda` 를 사용하면 `R.range` 와 같은 함수를 쉽게 만들 수 있다.

```ts
// 전개 연산자를 사용하여 range 함수 구현

// 재귀 함수 스타일로 동작하도록 구현
const range = (from: number, to: number): number[] =>
    from < to ? [from, ...range(from+1, to)]: []

let numbers: number[] = range(1, 9+1)
console.log(numbers)    // [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

---

## 2. 배열의 filter, map, reduce 메서드

### 2.1. filter 메서드

배열의 타입이 T 일 때 배열의 filter 메서드는 아래 형태로 설계되어있다.
```ts
filter(callback: (value: T, index?: number): boolean): T[]
```

`filter` 메서드를 이용하여 숫자 배열에서 홀수와 짝수를 구분하는 기능을 만들어보자.<br />
`filter` 는 배열의 원본을 변경하지 않는다. (순수 함수)

*순수 함수* 는 바로 다음 부분에 설명이 있습니다.

```ts
// filter 메서드

import {range} from "./range";

const array: number[] = range(1, 10+1)

let odds: number[] = array.filter((value => value % 2 != 0))
let evens: number[] = array.filter((value => value % 2 == 0))

console.log(odds, evens)    // [ 1, 3, 5, 7, 9 ] [ 2, 4, 6, 8, 10 ]
```

filter 는 두 번째 매개변수에 `index` 라는 선택 속성도 제공한다.
아래는 index 를 이용하여 배열을 반으로 나누는 기능이다.
```ts
// filter 메서드 - 배열 반으로 나누기

import {range} from "./range";

const array: number[] = range(1, 10+1)
const half = array.length / 2

let belowHalf: number[] = array.filter((value, index) => index < half)
let overHalf: number[] = array.filter((value, index) => index >= half)

console.log(belowHalf, overHalf)    // [ 1, 2, 3, 4, 5 ] [ 6, 7, 8, 9, 10 ]
```

---

### 2.2. map 메서드

배열의 타입이 `T[]` 일 때 배열의 `map` 메서드는 아래의 형태이다.
```ts
map(callback: (value: T, index?: number): Q): Q[]
```

`map` 도 배열의 원본을 변경하지 않는다. (순수 함수)

```ts
// map 메서드 - 제곱 구하기

import {range} from "./range";

let squared: number[] = range(1, 5+1).map((value: number) => value * value)
console.log(squared)    // [ 1, 4, 9, 16, 25 ]
```

`filter` 와 달리 `map` 은 입력 타입과 다른 타입의 배열을 만들 수 있다.

```ts
// map 메서드 - number[] 타입 배열을 string[] 타입 배열로 가공

import {range} from "./range";

let names: string[] = range(1, 5+1).map((value, index) => `[${index}]: ${value}`)
console.log(names)  // [ '[0]: 1', '[1]: 2', '[2]: 3', '[3]: 4', '[4]: 5' ]
```

---

### 2.3. reduce 메서드

배열의 타입이 `T[]` 일 때 `reduce` 메서드는 아래의 형태이다.
```ts
reduce(callback: (result: T, value: T), initiaValue: T): T
```

`reduce` 도 배열의 원본을 변경하지 않는다. (순수 함수)

```ts
// reduce 메서드 - 1~100 더하기

import {range} from "./range";

let reduceSum: number = range(1, 100+1).reduce((result: number, value: number) => result + value, 0)
console.log(reduceSum)  // 5050

// 곱하기는 0 을 곱하면 안되니까 두 번째 인수에 1을 넣어준다.
let reduceMultiply: number = range(1, 10+1).reduce((result: number, value: number) => result * value, 1)
console.log(reduceMultiply) // 3628800
```
---

## 3. 순수 함수와 배열

### 3.1. 순수 함수

`순수 함수` 란 side-effect 가 없는 함수를 말한다.<br />
side-effect 란 함수가 가진 고유한 목적 이외의 다른 효과가 나타나는 것을 의미한다.

- 순수함수
    - 함수 몸통에 입출력 관련 코드가 없음
    - 함수 몸통에서 매개변수값을 변경시키지 않음 (= 매개변수는 readonly 형태로만 사용)
    - 함수는 몸통에서 만들어진 결과를 즉시 반환
    - 함수 내부에서 전역 변수나 정적 변수를 사용하지 않음
    - 함수가 예외를 발생시키지 않음
    - 함수가 콜백 함수로 구현되었거나, 함수 몸통에 콜백 함수를 사용하는 코드가 없음
    - 함수 몸통에 Promise 와 같은 비동기 방식으로 동작하는 코드가 없음

예를 들어 아래와 같은 함수는 순수 함수이다.
```ts
function pure(a: number, b: number): number {
    return a + b
}
```

아래는 매개변수로 전달받은 배열은 push 와 slice 로 변경하고 (= 매개변수가 readonly 형태로 동작하지 않으므로) g 라는 외부 변수를 사용하므로 순수 함수가 아니다.
```ts
let g = 10
function impure(array: number[]): void {
    array.push(1)
    array.slice(0, 1)
    return g
}
```

---

### 3.1. 타입 수정자 readonly

타입스크립트는 순수 함수 구현을 위해 `readonly` 키워드를 제공한다.

```ts
// 타입 수정자 readonly

function pure(array: readonly number[]) {
    array.push(1)  // TS2339: Property 'push' does not exist on type 'readonly number[]'.
}
```

---

### 3.2. 깊은 복사, 얕은 복사

- 깊은 복사
  - 대상 변수값이 바뀔 때 원본 변수값은 그대로 유지
  - number, boolean
- 얕은 복사
  - 대상 변수값이 바뀔 때 원본 변수값도 변경
  - 객체, 배열

```ts
// 깊은 복사, 얕은 복사

// 깊은 복사
let original: number = 1
let copied = original

copied += 2

console.log(original, copied)   // 1 3


// 얕은 복사
const originalArr = [1,2,3,4]
const shallowCopiedArr = originalArr

shallowCopiedArr[0] = 10
console.log(originalArr, shallowCopiedArr)  // [ 10, 2, 3, 4 ] [ 10, 2, 3, 4 ]
```

근데 `전개 연산자 ...` 를 사용해서 배열을 복사하면 깊은 복사를 할 수 있다.

```ts
// 전개 연산자를 이용하여 배열 깊은 복사

// 깊은 복사
const array = [1,2,3,3,4,5]
const deepCopiedArray = [...array]  // 전개연산자 사용

deepCopiedArray[0] = 10

console.log(array, deepCopiedArray) // [ 1, 2, 3, 3, 4, 5 ] [ 10, 2, 3, 3, 4, 5 ]
```

---

### 3.3. 순수 함수로 sort 메서드 구현 (원본 배열 유지하면서 sort)

Array 클래스의 `sort` 메서드는 배열을 오름차순/내림차순으로 정렬해주는데 이 때 배열의 원본 내용도 같이 변경이 된다. (= 얕은 복사)

**순수 함수**란 *함수 몸통에서 매개변수값을 변경시키지 않는 것* 이라고 하였다.<br />
`readonly` 타입을 이용하여 입력 배열의 내용을 유지한 채 정렬할 수 있도록 (= 순수 함수가 될 수 있도록) 해보자. 

먼저 아래는 [Typescript - 함수, 메서드](https://assu10.github.io/dev/2021/09/19/typescript-function-method/) 의 *화살표 함수(`=>`)와 표현식* 에서 본 화살표 함수 기본 형태이다.

```ts
const 함수명 = (매개변수: 타입, 매개변수: 타입[,...]): 반환타입 => 함수 몸통
```

```ts
// 순수 함수로 sort 메서드로 구현

const pureSort = <T>(array: readonly T[]): T[] => {
    let deepCopied = [...array]
    return deepCopied.sort()
}

const beforeArray: number[] = [1,5,4,3]
const afterArray = pureSort(beforeArray)

console.log(beforeArray, afterArray)    // [ 1, 5, 4, 3 ] [ 1, 3, 4, 5 ]
```

---

### 3.4. 순수 함수로 splice 메서드 구현 (원본 배열 유지하면서 특정 아이템 삭제)

배열에서 특정 아이템 삭제 시 `splice` 메서드를 사용하는데 `splice` 는 원본 배열을 변경하므로 순수 함수에서는 사용할 수 없다.<br />
이 때 `filter` 메서드를 이용하여 특정 아이템을 삭제할 수 있는데<br />
배열이 제공하는 `filter`, `map` 메서드는 `sort` 와 다르게 깊은 복사 형태(= 원본 배열을 유지)로 동작한다.

```ts
// 순수 함수로 splice 메서드 구현 (원본 배열 유지하면서 특정 아이템 삭제)

const pureDelete = <T>(array: readonly T[], cb: (value: T, index?: number) => boolean): T[] =>
    array.filter((value, index) => cb(value, index) == true)

const mixedArray: object[] = [
    [], {name: 'assu'}, {name: 'jhlee', age:20}, ['desc']
]

const arrayOnly: object[] = pureDelete(mixedArray, (value) => Array.isArray(value))
const objectOnly: object[] = pureDelete(mixedArray, (value) => !Array.isArray(value))

console.log('mixedArray', mixedArray)   // [ [], { name: 'assu' }, { name: 'jhlee', age: 20 }, [ 'desc' ] ]
console.log('arrayOnly', arrayOnly)     // [ [], [ 'desc' ] ]
console.log('objectOnly', objectOnly)   // [ { name: 'assu' }, { name: 'jhlee', age: 20 } ]
```  

---

### 3.5. 순수 함수로 가변 인수 함수 구현

함수를 호출할 때 전달하는 인수의 개수를 제한하지 않는 것을 `가변 인수` 라고 한다.

아래를 보면 *mergeArray* 함수는 각각 2개, 4개의 인수를 전달받는데 이런 방식으로 동작하는 함수를 `가변 인수 함수` 라고 한다.


```ts
// 순수 함수로 가변 인수 함수 구현

import { mergeArray } from "./mergeArray";

const mergedArray1: string[] = mergeArray(
        ['hello'], ['world']
)
console.log(mergedArray1)   // [ 'hello', 'world' ]

const mergedArray2: number[] = mergeArray(
        [1], [2,3], [3,4,5]
)
console.log(mergedArray2)   // [ 1, 2, 3, 3, 4, 5 ]
```

`가변 인수 함수` 의 기본 형태는 아래와 같다.
```ts
const mergeArray = (...arrays) => { }
```

위에서 매개변수 arrays 앞의 `...` 은 잔여나 전개 연산자가 아니라 가변 인수를 표현하는 구문이다.<br />
>잔여 연산자와 전개 연산자의 상세 내용은 [Typescript - 객체, 타입](http://localhost:4000/dev/2021/09/14/typescript-object-type/) 의 *4.2. 잔여 연산자와 전개 연산자 (`...`)* 를 참고하세요.

string[], number[] 타입 배열을 모두 받으려면 제네릭 타입으로 구현해야 하므로 아래와 같이 수정한다.
```ts
const mergeArray = <T>(...arrays) => { }
```

또한 전달받는 인수는 모두 배열이므로 매개변수인 arrays 의 타입을 배열의 배열로 선언한다.
```ts
const mergeArray = <T>(...arrays: T[][]) => { }
```

매개변수는 배열의 배열인 *T[][]* 이지만 출력은 배열이므로 *T[]* 형태의 배열을 반환하도록 한다.
```ts
const mergeArray = <T>(...arrays: T[][]): T[] => { }
```

마지막으로 *mergeArray* 함수를 **순수 함수** 로 구현하려면 매개 변수의 내용이 변경되지 말아야 하기 때문에 매개 변수 타잎 앞에 `readonly` 키워드를 넣어준다.
```ts
const mergeArray = <T>(...arrays: readonly T[][]): T[] => { }
```

위 내용을 바탕으로 *mergeArray* 함수를 구현하면 아래와 같다.
```ts
// 순수 함수로 가변 인수 함수 구현

export const mergeArray = <T>(...arrays: readonly T[][]): T[] => {
    let result: T[] = []
    for (let index=0; index<arrays.length; index++) {
        const array: T[] = arrays[index]

        // result 와 array 배열을 각각 전개(spread)하고 결합(merge)해야 T[] 타입 배열 생성 가능
        result = [...result, ...array]
    }
    return result
}
```

---

## 4. 튜플

자바스크립트에는 `튜플` 이 없으며 단순히 배열의 한 종류이다.

아래는 여러 타입에 대응하는 `any` 타입 배열을 선언한 예이다.
```ts
let tuple: any[] = [true, 'hello']
```

그런데 `any` 타입의 형태는 타입스크립트의 타입 기능을 무력화하기 때문에 타입스크립트는 튜플의 타입 표기법을 배열과 다르게 선언할 수 있다.
```ts
let numArray: number[] = [1, 2, 3, 4]
let tuple: [boolean, string] = [true, 'hello']
```

---

### 4.1. 튜플에 타입 별칭 사용, 비구조화 할당 사용

튜플을 사용할 때는 타입 별칭으로 튜플의 의미를 명확하게 한다.<br />
예를 들어 바로 위처럼 *[boolean, string]* 으로 타입을 지정하는 것보다 아래처럼 타입 별칭을 사용하여 이 튜플이 어떠한 용도로 사용되는지 분명하게 알려주는 것이 좋다.
```ts
// 튜플 - 타입 별칭 사용 (ResultType.ts)

export type ResultType = [boolean, string]
```

```ts
// 튜플 - 타입 별칭  (doSomething.ts)

import { ResultType } from "./ResultType";

// 예외 발생 시 구체적인 내용을 튜플로 반환
export const doSomething = (): ResultType => {
    try {
        throw new Error('Error occurs...')
    } catch (e) {
        if (e instanceof Error) {
            return [false, e.message]
        } else {
            return [false, 'unknown error']
        }
    }
}
```

```ts
// 튜플 - 튜플에 비구조화 할당 적용 (index.ts)

import { doSomething } from "./doSomething";

const [result, errorMsg] = doSomething()
console.log(result, errorMsg)   // false Error occurs...
```

---


*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)