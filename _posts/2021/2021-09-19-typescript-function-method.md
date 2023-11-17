---
layout: post
title:  "Typescript - 함수, 메서드"
date:   2021-09-19 10:00
categories: dev
tags: typescript
categories: dev
---

자바스크립트에서 함수는 `function` 키워드와 화살표 `=>` 기호로 만드는 두 가지 방법이 있는데
타입스크립트 함수는 이를 바탕으로 타입 기능을 추가한 것이다.

이 포스트는 타입스크립트에서 함수를 효과적으로 구현하는 방법과 클래스의 메서드를 구현하는 방법에 대해 알아본다. 

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

> - 함수 선언
>   - 함수 시그니처 (function signature)
>   - 타입 별칭 (type alias)
>   - 선택적 매개변수
> - 함수 표현식
>   - 일급 함수 (first-class function)
>   - 계산법
>   - 함수 호출 연산자
>   - 익명 함수 (anonymous function)
> - 화살표 함수(`=>`)와 표현식
>   - 실행문과 표현식문
>   - 표현식문 스타일의 화살표 함수 구현
> - 일급 함수 (first-class function)
>   - 콜백 함수
>   - 중첩 함수
>   - 고차 함수(high-order function) 와 클로저, 부분 함수
> - 함수 구현 기법
>   - 매개변수 기본값 설정
>   - 객체 생성 시 값을 생략하는 타입스크립트 구문
>   - 객체를 반환하는 화살표 함수
>   - 매개변수에 비구조화 할당문 사용
>   - 색인 키와 값으로 객체 만들기
> - 클래스 메서드
>   - function 함수와 this 키워드
>   - 메서드
>   - 클래스 메서드 구문
>   - 정적 메서드
>   - 메서드 체인

---

## 1. 함수 선언

자바스크립트에서 함수는 `function` 키워드와 화살표 `=>` 기호로 만드는 두 가지 방법이 있다.<br />
먼저 `function` 키워드로 만드는 함수에 대해 알아보자.<br />
화살표 `=>` 기호로 만드는 함수는 *3. 화살표 함수(`=>`)와 표현식* 에서 다룰 예정이다.

```ts
function 함수명(매개변수: 타입, 매개변수: 타입[,...]): 반환값 타입 {
    함수 몸통
}
```

```ts
// 함수 선언문

function add(a: number, b: number): number {
    return a+b 
}
```

함수 선언문에서도 매개변수와 반환값에 대한 타입 주석을 생략할 수는 있지만 타입이 생략되면 함수의 구현 의도를 알기 어렵기 때문에 생략하지 않는 것이 바람직하다.

`void` 타입인 경우 아래와 같이 표현한다.

```ts
// void type

function printMe(name: string, age: number) : void {
    console.log(`name: ${name}, age: ${age}`) 
}

printMe('assu', 20) 
```

---

### 1.1. 함수 시그니처 (function signature)

변수에 타입이 있듯이 함수도 타입이 있는데 함수의 타입을 `함수 시그니처(function signatrue)` 라고 한다.

```ts
(매개변수: 타입, 매개변수: 타입[,...]) => 반환값 타입
```

```ts
// 함수 시그니처

function printMe(name: string, age: number) : void {
    console.log(`name: ${name}, age: ${age}`) 
}

let printMeSignature: (p1: string, p2: number) => void = function (name: string, age: number): void {
    console.log(`name: ${name}, age: ${age}`) 
}
printMeSignature('assu', 20) 
```

매개변수도 없고, 반환값도 없는 함수 시그니처는 `() => void` 이다.

---

### 1.2. 타입 별칭 (type alias)

`type` 키워드는 기존에 존재하는 타입을 단순히 이름만 바꿔서 사용할 수 있게 해주는데 이러한 것을 `타입 별칭 (type alias)` 라고 한다.

```ts
type 새로운 타입 = 기존 타입
```

```ts
// 타입 별칭

type stringNumberFunc = (p1: string, p2: number) => void 

let f: stringNumberFunc = function(a: string, b: number): void { }
let g: stringNumberFunc = function(c: string, d: number): void { }
let h: stringNumberFunc = function(e: number) : void { }    // TS2322: Type '(e: number) => void' is not assignable to type 'stringNumberFunc'.
```

`(p1: string, p2: number) => void` 함수 시그니처를 `stringNumberFunc` 라는 이름으로 타입 별칭을 만들어 둔 덕분에 변수 *f*, *g* 에 타입 주석을 더 수월하게 붙일 수 있다.

함수의 타입, 즉 함수 시그니처를 명시하면 매개변수의 개수나 타입, 반환 타입이 다른 함수를 선언하는 오류를 미연에 방지할 수 있다. 

---

### 1.3. 선택적 매개변수

함수의 매개변수에 `?` 를 붙여 선택적 매개변수로 선언이 가능하다.

```ts
// 선택적 매개변수

type OptionalArgFunc = (p1: string, p2?: number) => void 

function fn(p1: string, p2?: number): void {
    console.log(`p2: ${p2}`) 
}

let fn2: OptionalArgFunc = function(a: string, b?: number) : void {
    console.log(`b: ${b}`) 
}

fn('assu', 2)    // p2: 2
fn('assu')           // p2: undefined
fn2('assu', 2)   // b: 2
fn2('assu')          // b: undefined
```

---

## 2. 함수 표현식

```ts
// 함수 표현식

function add1(a: number, b: number): number {
    return a+b 
}

let add2 = function(a: number, b: number): number {
    return a+b 
}

console.log(add1(1, 2)) 
console.log(add2(1, 2)) 
```

위의 *add1()* 과 *add2()* 는 모두 같은 함수 선언문이다.<br />
함수 선언문에서 함수 이름을 제외한 `function(a: number, b: number): number { return a+b  }` 를 함수 표현식이라고 한다.

---

### 2.1. 일급 함수 (first-class function)

`일급 함수` 란 함수와 변수를 구분하지 않는다는 의미이다.

아래 코드를 보자.

```ts
// 일급 함수

let add = function(a: number, b: number): number {
    return a+b 
}
console.log(add(1, 2))      // 3

add = function(a: number, b: number): number {
    return a-b 
}
console.log(add(1, 2))      // -1
```

*add* 앞에 `let` 키워드가 있으므로 *add* 는 변수이다.<br />
*add* 는 변수이므로 값을 저장할 수 있고, 따라서 *add* 변수에 `function(a: number, b: number) { return a-b  }` 형태의 함수 표현식도 저장할 수 있다. 

---

### 2.2. 계산법

컴파일러는 표현식을 만나면 `eager evaluation` 과 `lazy evaluation` 을 적용해 값을 만든다.

예를 들어 컴파일러가 *1+2* 라는 표현식을 만나면 `eager evaluation` 를 적용해 3 이라는 값을 만들고,
컴파일러가 *function(a: number, b: number) { return a-b  }* 라는 함수 표현식을 만나면 a와 b가 어떤 값인지 알 수 없으므로 `lazy evaluation` 를 적용하여 계산을 보류한다.

---

### 2.3. 함수 호출 연산자

변수가 함수 표현식을 담고 있다면 변수 이름 뒤에 `함수 호출 연산자 ()` 를 붙여 호출할 수 있다.<br /> 
`함수 호출` 이란 함수 표현식의 몸통 부분을 실행한다는 의미이다.

함수가 매개변수를 요구하면 함수 호출 연산자 `()` 안에 필요한 매개변수를 명시하면 된다.

```ts
// 함수 호출 연산자

let funcExpression = function(a: number, b: number): number {
    return a+b 
} 
let value = funcExpression(1, 2) 
```

---


### 2.3. 익명 함수 (anonymous function)

함수 표현식은 사실 익명 함수의 다른 표현이다.

```ts
// 익명 함수

let funcExpression = (function(a: number, b: number): number {
    return a+b 
})(1, 2) 

let funcExpression2 =
    (function(a: number, b: number): number {
        return a+b 
    })
    (1, 2)      // 곧바로 함수 호출 연산자를 만나므로 eager evaluation 을 적용해 3이라는 값을 만들어냄

console.log(funcExpression)     // 3

let funcExpression3 = (function(): void {
    console.log('hello') 
})()    // hello
console.log(funcExpression3)    // undefined
```

위 예제의 *funcExpression2* 는 *funcExpression* 을 순서대로 풀어쓴 것이다.

---

## 3. 화살표 함수(`=>`)와 표현식

ESNext 자바스크립트와 타입스크립트는 function 키워드가 아닌 `=>` 기호로 만든 화살표 함수도 제공한다.

```ts
const 함수명 = (매개변수: 타입, 매개변수: 타입[,...]): 반환타입 => 함수 몸통
```

`=>` 함수의 몸통은 중괄호를 사용할 수도 있고 생략할 수도 있다.

```ts
// 화살표 함수(`=>`)와 표현식

const arrow1 = (a: number, b: number): number => { return a+b }
const arrow2 = (a: number, b: number): number => a+b
```

중괄호 사용 여부에 따라 타입스크립트의 문법이 동작하는 방식이 `실행문 방식 (execution statement)` 와  `표현식문 방식 (expression statement)` 로 달라진다.

---

### 3.1. 실행문과 표현식문

- 실행문
    - CPU 에서 실행되는 코드를 의미
    - CPU 에서 실행만 될 뿐 결과를 알려주지는 않음
      결과를 알려면 `return` 키워드를 사용해야 함
- 표현식 문
    - CPU 에서 실행된 결과를 굳이 `return` 키워드를 사용하지 않아도 알려줌
    
예를 들면 아래에서 `a = 1` 처럼 변수에 값을 대입하는 것이 대표적인 `실행문` 이다.<br />
그리고 `a > 2` 처럼 return 키워드없이 결과값을 반환하는 것이 `표현식문` 이다.

```ts
// 실행문
let a 
a = 1 

// 표현식문
if (a > 2) {
    let b = 3 
}
```

`복합 실행문` 은 중괄호를 사용하여 여러 실행문을 하나처럼 인식하게 하는 것을 의미한다.

```ts
if (조건식) {
    실행문 1 
    실행문 2 
}
```

---

### 3.2. 표현식문 스타일의 화살표 함수 구현

```ts
// 표현식문 스타일의 화살표 함수 구현

// 일반 함수
function isGreater(a: number, b:number): boolean {
    return a > b 
}

// 표현식문 스타일의 화살표 함수
const isGreater2 = (a: number, b: number): boolean => a > b 
const isGreater3 = (a: number, b: number): boolean => { return a > b }  // return 키워드를 사용하려면 중괄호로 복합 실행문을 만든 후 그 안에 사용
```

---

## 4. 일급 함수 (first-class function)

### 4.1. 콜백 함수

> **콜백 함수**<br />
> 매개변수 형태로 동작하는 함수

```ts
// 콜백 함수 (init.ts)

// 함수 f 는 callback 이라는 매개변수가 있는데 함수 몸통에서 함수로서 호출함
export const f = (callback: () => void): void => callback() 
// const arrow2 = (a: number, b: number): number => a+b

export const init = (callback: () => void): void => {
    console.log('default init finished.') 
    callback() 
    console.log('all init finished.') 
}


// 콜백 함수 (index.ts)

import {init} from "./init" 

init(() => console.log('custom init finished.') ) 
```

*npm run dev* 결과
```shell
default init finished.
custom init finished.
all init finished.
```

---

### 4.2. 중첩 함수

함수형 언어에서 함수는 **변수에 담긴 함수 표현식**이므로 함수 안에 또 다른 함수를 중첩해서 구현할 수 있다.

아래 코드를 보면 *calc* 함수는 *add* 와 *multiply* 라는 이름의 중첩 함수를 구현하고 있다.

```ts
// 중첩 함수

const calc = (value: number, cb: (c: number) => void): void => {
    let add = (a: number, b: number) => a+b 
    function multiply(a: number, b: number) {
        return a*b 
    }

    let result = multiply(add(1, 2), value) 
    cb(result) 
}

calc(30, (result: number) => console.log(`result is ${result}`))    // 90
```

---

### 4.3. 고차 함수(high-order function) 와 클로저, 부분 함수

`고차 함수(high-order function)` 는 또 다른 함수를 반환하는 함수를 말한다.<br />
함수형 언어에서 함수는 단순히 함수 표현식이라는 값이므로 다른 함수를 반환할 수 있다.

> (update!) 고차 함수는 추후 다른 포스트에서 자세히 설명 예정입니다.<br />
> [Typescript - 함수 조합](https://assu10.github.io//dev/2021/09/29/typescript-function-composition/) 의 *3. 고차 함수와 커리 (curry)* 를 참고하세요.

일반 함수와 고차 함수의 일반적인 형태는 아래와 같다.
```ts
// 고차 함수

const add1 = (a: number, b: number): number => a+b      // 일반 함수
const add = (a: number): (c: number) => number => (b: number): number => a+b      // 고차 함수

const result = add(1)(2) 
console.log(result)     // 3
```

*add* 함수를 호출하는 부분을 좀 더 쉽게 이해하기 위해 *add* 함수를 이해하기 쉬운 형태로 재구현하면 아래와 같다.

```ts
// 고차 함수

const add1 = (a: number, b: number): number => a+b      // 일반 함수
const add = (a: number): (c: number) => number => (b: number): number => a+b      // 고차 함수

const result = add(1)(2) 
console.log(result)     // 3


// add 함수를 이해하기 쉽게 재구현
type NumberToNumberFunc = (c: number) => number 
export const reAdd = (a: number): NumberToNumberFunc => {
    // NumberToNumberFunc 타입의 함수 반환
}
```

이제 *add* 의 반환값을 중첩 함수로 구현할 수 있다.

```ts
const add = (a: number): (c: number) => number => (b: number): number => a+b      // 고차 함수

// add 함수를 이해하기 쉽게 재구현 - 1차
export type NumberToNumberFunc = (c: number) => number 
export const reAdd = (a: number): NumberToNumberFunc => {
    // NumberToNumberFunc 타입의 함수 반환
}


// add 함수를 이해하기 쉽게 재구현 - 2차
export type NumberToNumberFunc = (c: number) => number 
export const reAdd = (a: number): NumberToNumberFunc => {
    // NumberToNumberFunc 타입의 함수 반환
    const _add: NumberToNumberFunc = (b: number): number => {
        // number 타입의 값 반환
        return a+b      // 클로저
    }
    return _add 
}
```
*reAdd* 함수가 반환하는 *_add* 함수는 NumberToNumberFunc 타입의 함수이다.

*_add* 함수가 리턴하는 *return a+b* 를 보자.<br />
*_add* 함수 관점에서 보면 *a* 는 외부에 선언된 변수이다. 이와 같은 형태를 `클로저` 라고 한다.

```ts
// 고차 함수

import {NumberToNumberFunc, reAdd} from "./nested" 

// 변수 fn 에 담긴 값은 NumberToNumberFunc 타입의 함수 표현식
let fn: NumberToNumberFunc = reAdd(1) 

let result = fn(2) 

console.log(result)     // 3
console.log(reAdd(1)(2))    // 3
console.log(reAdd(1))    // [Function: _add], 부분 적용 함수
```

변수 *fn* 에 담긴 값은 NumberToNumberFunc 타입의 함수 표현식이므로 *fn(2)* 처럼 함수 호출 연산자를 붙일 수 있다.<br />
변수 *fn* 은 단순히 *reAdd(1)* 을 저장하는 임시 변수이므로, 임시 변수를 사용하지 않으면 *reAdd(1)(2)* 처럼 함수 호출 연산자를 2개 사용해야 한다.<br />
2차 고차함수인데 함수 호출 연산자를 1개만 붙이면 그것은 아직 값이 아니라 함수인데 이런 것을 `부분 적용 함수(partially applied function)` 라고 한다.


---

## 5. 함수 구현 기법

### 5.1. 매개변수 기본값 설정

```ts
(매개변수: 타입 = 매개변수 기본값)
```

```ts
// 매개변수 기본값 설정

export type Person = { name: string, age: number } 

export const makePerson = (name: string, age: number = 10): Person => {
    const person = { name: name, age: age} 
    return person 
}

console.log(makePerson('assu'))             // { name: 'assu', age: 10 }
console.log(makePerson('assu', 20))    // { name: 'assu', age: 20 }
```

---

### 5.2. 객체 생성 시 값을 생략하는 타입스크립트 구문

타입스크립트는 매개변수의 이름과 똑같은 이름의 속성을 가진 객체를 만들 수 있는데, 이 때 속성값 부분을 생략할 수 있는 단축 구문을 제공한다.

위의 *makePerson* 을 단축 구문을 사용하여 표현하면 아래와 같다.
```ts
// 객체 생성 시 값을 생략하는 타입스크립트 구문

export type Person = { name: string, age: number } 

export const makePerson = (name: string, age: number = 10): Person => {
    const person = { name: name, age: age} 
    return person 
}

// 객체 생성 시 값을 생략하는 타입스크립트 구문
const makePerson2 = (name: string, age: number = 10): Person => {
    const person2 = { name, age }       // const person = { name: name, age: age} 의 단축 표현
    return person2 
}

console.log(makePerson2('assu'))         // { name: 'assu', age: 10 }
```

---

### 5.3. 객체를 반환하는 화살표 함수

**화살표 함수에서 객체를 반환하고자 할 때** 컴파일러가 객체로 해석하게 하려면 반환값을 `소괄호 ( )` 로 감싸주어야 한다.

```ts
// 객체를 반환하는 화살표 함수

export type Person = { name: string, age: number } 

// 객체 생성 시 값을 생략하는 타입스크립트 구문
const makePerson = (name: string, age: number = 10): Person => {
    const person = { name, age }      // const person = { name: name, age: age} 의 단축 표현
    return person
}

console.log(makePerson('assu'))     // { name: 'assu', age: 10 }

// 화살표 함수에서 객체를 반환하고자 할 때 아래와 같이 하면 컴파일러는 중괄호를 객체가 아닌 복합 실행문으로 해석함
const makePersonBad = (name: string, age: number = 10): Person => { name, age } // 오류

// 컴파일러가 중괄호를 객체로 해석하게 하려면 객체를 소괄호 ( ) 로 감싸주어야 함
const makePersonGood = (name: string, age: number = 10): Person => ({ name, age })
```

---

### 5.4. 매개변수에 비구조화 할당문 사용

앞서 보았던 [Typescript - 객체, 타입](https://assu10.github.io/dev/2021/09/14/typescript-object-type/) 의 *4.1. 비구조화 할당문* 에서 객체에 비구조화 할당문을 적용하는 법에 대해 알아보았었다.<br />
함수의 매개변수도 변수이므로 아래처럼 비구조화 할당문 적용이 가능하다.

```ts
// 매개변수에 비구조화 할당문 사용

export type Person = { name: string, age: number } 

// 컴파일러가 중괄호를 객체로 해석하게 하려면 객체를 소괄호 ( ) 로 감싸주어야 함
const makePerson1 = (name: string, age: number = 10): Person => ({ name, age })

// 매개변수에 비구조화 할당문 적용
const makePerson2 = ({ name, age }: Person) => ({ name, age })
const makePerson3 = ({ name, age }: Person): void =>
    console.log(`name: ${name}, age: ${age}`)

makePerson2({name: 'assu', age: 10})
makePerson3({name: 'assu', age: 20})   // name: assu, age: 20
```

---

### 5.5. 색인 키와 값으로 객체 만들기

ESNext 자바스크립트에서는 아래와 같은 코드를 작성할 수 있다.
```ts
const makeObj = (key: string, value: any) => ({ [key]: value})
```

위 코드는 아래처럼 객체의 속성 이름을 변수로 만들고자 할 때 사용하는데 타입스크립트에서는 `{ [key]: value }` 의 형태를 `색인 가능 타입(indexable type)` 이라고 한다.

```ts
// 색인 키와 값으로 객체 만들기

const makeObj = (key: string, value: any) => ({ [key]: value })
const makeObj2 = (key: string, value: any) => ({ key: value })

console.log(makeObj('name', 'assu'))    // { name: 'assu' }
console.log(makeObj('age', 20))         // { age: 20 }

console.log(makeObj2('name', 'assu'))    // { key: 'assu' }
console.log(makeObj2('age', 20))         // { key: 20 }
```

아래는 색인 기능 타입을 사용하여 속성명만 다른 객체를 만드는 예시이다.
```ts
// 색인 가능 타입을 사용하여 속성명만 다른 객체를 만드는 코드

type KeyValueType = {
    [key: string]: string
}

const makeObj3 = (key: string, value: string): KeyValueType => (
    { [key]: value }
)

console.log(makeObj3('name', 'assu'))       // { name: 'assu' }
console.log(makeObj3('name2', 'jhlee'))     // { name2: 'jhlee' }
```

---

## 6. 클래스 메서드

### 6.1. function 함수와 this 키워드

타입스크립트의 `function` 키워드로 만든 함수는 `Function` 클래스의 인스턴스, 즉 함수는 객체이다.

```ts
// function 함수와 this 키워드

let add = new Function('a', 'b', 'return a+b')
let result = add(1, 2)
console.log(result)     // 3
```

객체지향언어에서 인스턴스는 `this` 키워드를 사용할 수 있다.

타입스크립트에서 `function` 키워드로 만든 함수에는 `this` 키워드를 사용할 수 있지만 화살표 함수에는 `this` 키워드를 사용할 수 없다.

---

### 6.2. 메서드

타입스크립트에서 메서드는 `function` 으로 만든 함수 표현식을 담고 있는 속성이다.

```ts
// 메서드 (A.ts)

export class A {
    value: number = 1
    method: () => void = function(): void {
        console.log(`value: ${this.value}`)
    }
}


// 메서드 (index.ts)

import {A} from "./A";

let a: A = new A
a.method()  // value: 1
```

위 코드에서 `tsconfig.json` 가 `"noImplicitThis": false,` 로 설정되어 있지 않으면 `${this.value}` 에서 아래와 같은 오류가 난다.

>TS2683: 'this' implicitly has type 'any' because it does not have a type annotation.

---

### 6.3. 클래스 메서드 구문

위에 작성한 클래스 A 는 가독성이 떨어진다.
타입스크립트는 클래스 속성 중 함수 표현식을 담는 속성은 `function` 키워드를 생략할 수 있는 단축 구문을 제공한다.

```ts
// 클래스 메서드 구문 (A.ts)

export class A {
    value: number = 1
    method: () => void = function(): void {
        console.log(`value: ${this.value}`)
    }
}


// 함수표현식을 담는 속성은 function 키워드 생략
export class B {
    constructor(public value: number = 1) { }
    method(): void {
        console.log(`value: ${this.value}`)
    }
}


// 클래스 메서드 구문 (index.ts)

import {A, B} from "./A";

let b: B = new B()
let b2: B = new B(3)

b.method()  // value: 1
b2.method()  // value: 3
```

---

### 6.4. 정적 메서드

정적 메서드는 `static` 키워드로 선언하며, `클래스명.정적메서드()` 로 호출 가능하다.

```ts
// 정적 메서드

class C {
    static printMe(): string {
        return `print Me`
    }
}

console.log(C.printMe())    // print Me
```
---

### 6.5. 메서드 체인

jQuery 와 같은 라이브러리는 객체의 메서드를 이어서 계속 호출하는 방식으로 `메서드 체인` 을 구현하는데 타입스크립트에서 메서드 체인을 구현하려면
메서드가 항상 `this` 를 반환하게 해야 한다.

```ts
// 메서드 체인 (chain.ts)

export class Calc {
    constructor(public value: number = 0) { }
    add(value: number) {
        this.value += value
        return this
    }
    multiple(value: number) {
        this.value *= value
        return this
    }
}


// 메서드 체인 (index.ts)

import {Calc} from "./chain";

let calc = new Calc
let result = calc.add(1).add(2).multiple(3)

console.log(result)         // Calc { value: 9 }
console.log(result.value)   // 9
```

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)