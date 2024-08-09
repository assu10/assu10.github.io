---
layout: post
title:  "Typescript - Promise, async/await"
date: 2021-09-26 10:00
categories: dev
tags: typescript
---

이 포스트는 비동기 API 를 사용하는 코드를 쉽게 작성하는 `Promise` 클래스와 `async/await` 구문에 대해 알아본다.

이번 포스트에서는 `tsconfig.json` 의 `downlevelIteration` 설정을 true 로 설정해야 한다.

>`downlevelIteration` 의 자세한 내용은 [Typescript 기본](https://assu10.github.io/dev/2021/09/11/typescript-basic/) 의 *4.1. tsconfig.json* 을 참고하세요.

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

<!-- TOC -->
  * [1. 비동기 콜백 함수](#1-비동기-콜백-함수)
    * [1.1. 동기와 비동기 API](#11-동기와-비동기-api)
    * [1.2. 단일 스레드와 비동기 API](#12-단일-스레드와-비동기-api)
  * [2. Promise 클래스](#2-promise-클래스)
    * [2.1. `resolve`, `reject` 함수](#21-resolve-reject-함수)
    * [2.2. Promise.resolve, Promise.reject 메서드](#22-promiseresolve-promisereject-메서드)
    * [2.3. then-체인](#23-then-체인)
    * [2.4. `Promise.all` 메서드](#24-promiseall-메서드)
    * [2.5. `Promise.race` 메서드](#25-promiserace-메서드)
  * [3. `async/await` 구문](#3-asyncawait-구문)
    * [3.1. await 키워드](#31-await-키워드)
    * [3.2. async 함수 수정자](#32-async-함수-수정자)
    * [3.3. async 함수 특징](#33-async-함수-특징)
    * [3.4. async 함수가 반환하는 값 의미](#34-async-함수가-반환하는-값-의미)
    * [3.5. async 함수 예외 처리](#35-async-함수-예외-처리)
    * [3.6. async 함수와 `Promise.all`](#36-async-함수와-promiseall)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## 1. 비동기 콜백 함수

### 1.1. 동기와 비동기 API

node.js 는 파일 시스템과 관련된 기능을 모아둔 fs 패키지를 제공하는데 fs 패키지는 같은 기능을 `동기 (synchronous)` 와 `비동기 (asynchronous)` 방식으로 나누어 제공한다.<br />
예를 들면 파일을 읽는 기능은 *readFileSync* 와 *readFile* 두 가지로 제공한다.

아래는 package.json 파일을 동기와 비동기 방식으로 읽어서 화면에 출력하는 예시이다.

```ts
// 동기와 비동기 API

import { readFileSync, readFile } from "fs";

// 동기 방식으로 읽기
console.log('read package.json using synchronous api...')
const buffer: Buffer = readFileSync('./package.json')
console.log(buffer.toString())

// 비동기방식으로 읽기
readFile('./package.json', (error, buffer) => {
    console.log('read package.json using asynchronous api...')
    console.log(buffer.toString())
})

// promise 와 async/await 구문으로 읽기
const readFilePromise = (filename: string): Promise<string> =>
    new Promise<string>((resolve, reject) => {
        readFile(filename, (error, buffer) => {
            if (error) {
                reject(error)
            } else {
                resolve(buffer.toString())
            }
        })
    });

(async () => {
    const content: string = await readFilePromise('./package.json')
    console.log('read package.json using Promise and async/await...')
    console.log(content)
})()
```

---

### 1.2. 단일 스레드와 비동기 API

동기 API 를 호출하는 자바스크립트 코드가 웹 서버에서 실행되면 단일 스레드로 동작하는 자바스크립트의 물리적 특징 상 웹 서버는 동기 API 가 결과값을 반환할 때까지 일시적으로 멈춘다.
그리고 웹 브라우저에서 이 웹 서버로 접속이 안되는 현상이 발생한다.

타입스크립트는 이렇게 단일 스레드에서 동작하므로 코드를 작성할 때 항상 비동기 방식으로 동작하는 API 를 사용하여 프로그램 반응성을 훼손하지 말아야 한다.


> **자동 세미콜론 삽입 기능**<br />
> 자바스크립트와 타입스크립트 문법에는 자동 세미콜론 삽입 기능이 있는데 이는 세미콜론이 생략되면 자동으로 세미콜론을 삽입해주는 컴파일러의 기능이다.
> 자동 세미콜론 삽입 기능이 적용되지 않는 경우는 아래 3가지가 있다. 
> 1. 문장이 '(' 로 시작될 때
> 2. 문장이 '[' 로 시작될 때
> 3. 문장이 역따옴표 ` 로 시작될 때

---

## 2. Promise 클래스

`Promise` 는 ES6 버전에서 정식 기능으로 채택되었다.
`Promise` 는 클래스 이므로 `new 연산자` 를 이용하여 프로미스 객체를 만들고, new 연산자로 프로미스 객체를 만들 때에는 아래처럼 **콜백 함수를 제공**해야 한다.

```ts
const promise = new Promise(콜백 함수)
```

Promise 의 콜백 함수는 `resolve`, `reject` 두 개의 매개변수를 갖는다.
```ts
(resolve, reject) => { }
```

```ts
const numPromise: Promise<number> = new Promise<number>(콜백 함수)
const arrayPromise: Promise<number[]> = new Promise<number[]>(콜백 함수)
```

Promise 의 콜백 함수는 아래처럼 resolve 와 reject 함수를 매개변수로 받는 형태이다.

```ts
new Promise<T>((
    resolve: (successValue: T) => void, 
    reject: (any) => void 
) => {
    // ... 코드 구현
})
```

---

### 2.1. `resolve`, `reject` 함수

readFilePromise.ts
```ts
// Promise

import { readFile } from "fs";

export const readFilePromise = (filename: string): Promise<string> =>
    new Promise<string>((
        resolve: (value: string) => void,
        reject: (error: Error) => void
    ) => {
        readFile(filename, (err, buffer: Buffer) => {
            if (err) {
                reject(err);
            } else {
                resolve(buffer.toString())
            }
        })
    });
```

readFilePromise-test.ts
```ts
// Promise

import {readFilePromise} from "./readFilePromise";

readFilePromise('./package.json')
    .then((content: string) => {
        console.log(content);   // package.json 내용
        return readFilePromise('./tsconfig.json');
    })
    .then((content: string) => {
        console.log(content);    // tsconfig.json 내용
        return readFilePromise('.'); // catch 에  EISDIR: illegal operation on a directory, read 전달
    })
    .catch((err: Error) => {
        console.log('error:', err.message);
    })
    .finally(() => {
        console.log('종료');
    });
```

`resolve` 함수를 호출한 값은 `then` 메서드의 콜백 함수쪽에 전달되고, `reject` 함수를 호출한 값은 `catch` 메서드의 콜백 함수에 전달된다.

---

### 2.2. Promise.resolve, Promise.reject 메서드

Promise 클래스는 `resolve` 라는 클래스 메서드(정적 메서드)를 제공한다.<br />
`Promise.resolve(값)` 형태로 호출하면 이 **값**은 `then` 메서드에서 얻을 수 있다. 

`Promise.reject(Error 타입 객체)` 를 호출하면 이 **Error 타입 객체**는 항상 `catch` 메서드의 콜백 함수에서 얻을 수 있다.

```ts
// Promise.resolve

Promise.resolve(1)
    .then(value =>
        console.log(value)  // 1
    );

Promise.resolve([1, 2, 3])
    .then(value =>
        console.log(value)  // [ 1, 2, 3 ]
    );

Promise.resolve({name: 'assu', age: 20})
    .then(value =>
        console.log(value)  // { name: 'assu', age: 20 }
    );

Promise.reject(new Error('error occured...'))
    .catch ((err: Error) =>
        console.log('error:', err.message)
    );
```

---

### 2.3. then-체인

`Promise` 의 `then` 인스턴스 메서드를 호출할 때 사용한 콜백 함수는 값을 반환할 수 있는데 이 `then` 에서 반환된 값을 또 다른 `then` 메서드를 호출하여 값을 수신할 수 있다.

```ts
// Promise then-chain

Promise.resolve(1)
    .then((value: number) => {
        console.log(value);
        return Promise.resolve(true);
    })
    .then((value: boolean) => {
        console.log(value);
        return [1, 2, 3];
    })
    .then((value: number[]) => {
        console.log(value);
        return {name: 'assu', age: 20};
    })
    .then((value: {name: string, age: number}) => {
        console.log(value);
    });
```
---

### 2.4. `Promise.all` 메서드

Array 클래스는 `every` 라는 인스턴스 메서드를 제공하는데, `every` 메서드는 배열의 모든 아이템이 어떤 조건을 만족하면 true 를 반환하는 메서드이다.

```ts
// Promise.all

const isAllTrue = (values: boolean[]) => values.every((value => value == true));

console.log(
    isAllTrue([true, true, true]),  // true
    isAllTrue([true, false, true]), // false
    [true, true].every(value => value == true)  // true
);
```

`Promise.all` 클래스 메서드는 위의 `every` 메서드처럼 동작한다.

```ts
all(프로미스 객체 배열: Promise[]): Promise<resolve된 값들의 배열(혹은 any)>
```

`Promise.all` 메서드는 Promise 객체들을 배열로 받아 모든 객체를 대상으로 resolve 된 값들의 배열로 만든 후 해당 배열로 구성된 또 다른 Promise 객체를 반환한다.<br />
따라서 resolve 된 값들의 배열은 then 메서드를 호출해서 얻어야 한다.<br />
배열에 담긴 Promise 객체 중 reject 객체가 발생하면 더 기다리지 않고 바로 해당 reject 값을 담은 `Promise.reject` 객체를 반환하고, 이 객체는 catch 메서드를 통해 얻는다.

```ts
// Promise.all

const getAllResolveResult = <T>(promises: Promise<T>[]) => Promise.all(promises);

getAllResolveResult<any>([Promise.resolve(true), Promise.resolve('hello')])
    .then(result => console.log(result));   // [ true, 'hello' ]

getAllResolveResult<any>([Promise.reject(new Error('error~')), Promise.resolve(1)])
    .then(result => console.log(result))    // 호출되지 않음
    .catch(error => console.log('error: ', error.message));     // error:  error~
```

---

### 2.5. `Promise.race` 메서드

Array 클래스는 배열의 내용 중 하나라도 조건을 만족하면 true 를 반환하는 `some` 인스턴스 메서드를 제공한다.

이와 비슷하게 `Promise.race` 클래스 메서드는 배열에 담긴 프로미스 객체 중 하나라도 resolve 되면 그 값을 담은 Promise.resolve 객체를 반환한다.<br />
만일 거절 값이 가장 먼저 발생하면 Promise.reject 객체를 반환한다.

```ts
race(프로미스 객체 배열: Promise[]): Promise<가장 먼저 resolve된 객체의 값 타입(혹은 Error)>
```

```ts
// Promise.race

Promise.race([Promise.resolve('assu'), Promise.resolve('hello')])
    .then(value => console.log(value)); // assu

Promise.race([Promise.resolve(true), Promise.reject(new Error('error~'))])
    .then(value => console.log(value))  // true
    .catch(error => console.log(error.message));    // 호출되지 않음

Promise.race([Promise.reject(new Error('error~')), Promise.resolve(true)])
    .then(value => console.log(value))  // 호출되지 않음
    .catch(error => console.log(error.message));    // error~
```

`Promise` 가 비동기 API 에서 나타나는 콜백 지옥 형태를 어느 정도 해소해주지만, ESNext 자바스크립트와 타입스크립트는 Promise 를 좀 더 쉬운 형태인
코드로 만들어주는 `async/await` 구문을 제공한다.

---

## 3. `async/await` 구문

### 3.1. await 키워드

`await` 키워드는 피연산자의 값을 반환해준다. 만일 피연산자가 Promise 객체이면 then 메서드를 호출하여 얻은 값을 반환한다.
```ts
let value = await Promise객체 혹은 값
```

---

### 3.2. async 함수 수정자

`await` 키워드는 항상 `async` 함수 수정자가 있는 함수 몸통에서만 사용 가능하다.
```ts
// 화살표 함수 구문
const test1 = async() => {
    await Promise객체 혹은 값
}

// function 키워드 함수 구문
async function test2() {
    await Promise객체 혹은 값
}
```

```ts
// async/await

const test1 = async() => {
    let value = await 1;
    console.log(value)  // 1
    value = await Promise.resolve(2);
    console.log(value); // 2
}

async function test2() {
    let value = await 'hello';
    console.log(value);     // hello
    value = await Promise.resolve('assu');
    console.log(value);     // assu
}

test1();
test2();

/*
1
hello
2
assu
*/
```

test1() 이 먼저 호출되었으므로 *1 2 hello assu* 가 출력될 것으로 생각할 수도 있지만 실행 결과를 보면 두 함수가 마치 동시에 실행된 것처럼 보인다.

---

### 3.3. async 함수 특징

`async` 함수 수정자가 붙은 함수는 아래와 같은 특징이 있다.

- 일반 함수처럼 사용 가능
- Promise 객체로 사용 가능

바로 위 코드의 *test1(), test2()* 는 async 함수를 일반 함수처럼 사용한 예이고, 아래는 async 함수를 Promise 객체로 사용한 예시이다.

```ts
// async 함수를 Promise 객체로 사용
test1()
    .then(() => test2())

/*
1
2
hello
assu
*/
```

*test1()* 함수 호출이 resolve 된 후 *test2()* 함수를 호출하므로 일반 함수처럼 사용했을 때와는 실행 결과가 다르다.

---

### 3.4. async 함수가 반환하는 값 의미

async 함수는 값을 반환할 수 있는데 이 반환값은 Promise 형태로 반환되기 때문에 then 메서드를 통해 async 함수의 반환값을 얻는다.

```ts
// async 함수가 반환하는 값 의미

const asyncReturn = async() => {
    return [1, 2, 3]
};

asyncReturn()
    .then(value => console.log(value)); // [ 1, 2, 3 ]
```

---

### 3.5. async 함수 예외 처리

async 함수에서 예외가 발생하면 프로그램이 비정상 종료가 되는데 아래가 그 예시이다.

```ts
// async 함수 예외 처리

const asyncException = async() => {
    throw new Error('error~');
};

// 프로그램이 비정상 종료됨
asyncException();
```

프로그램이 비정상 종료되는 상황을 방지하기 위해선 아래처럼 asyncException() 이 반환하는 Promise 객체의 catch 메서드를 호출하는 형태로 코드를 작성해야 한다.
```ts
// 프로그램이 비정상 종료되지 않음
asyncException()
    .catch(err => console.log('error:', err.message));  // error: error~
```

await 구문에서도 Promise.reject 값이 발생하면 프로그램이 비정상 종료되므로 catch 메서드를 호출하는 방식으로 코드를 작성해야 한다.
```ts
const awaitReject = async() => {
    await Promise.reject(new Error('error~~'));
};

// 프로그램이 비정상 종료됨
//awaitReject();

// 프로그램이 비정상 종료되지 않음
awaitReject()
    .catch(err => console.log('error:', err.message));  // error: error~~
```

---

### 3.6. async 함수와 `Promise.all`

*2.1. resolve, reject 함수* 에서 *readFilePromise.ts* 를 만들고, `Promise`, `then` 구문을 이용하여 비동기로 package.json 과 tsconfig.json 파일을 읽었다.
이번엔 `async`, `Promise.all` 를 사용하여 파일을 읽어보도록 한다.

```ts
// async 함수와 Promise.all

import {readFilePromise} from "./readFilePromise";

const readFilesAll = async (filenames: string[]) => {
    // 2. Promise.all 메서드를 사용하여 Promise[] 타입 객체를 단일 Promise 객체로 만듬
    // 3. 단일 Promise 객체에 await 구문을 적용하여 resolve 된 결과값 반환
    return await Promise.all(
        // 1. filenames 에 담긴 string[] 타입 배열에 map 메서드를 적용하여 Promise[] 타입 객체로 전환
        filenames.map(filename => readFilePromise(filename))
    )
};

readFilesAll(['./package.json', './tsconfig.json'])
    .then(([packageJson, tsconfigJson]: string[]) => {
        console.log('package.json', packageJson)
        console.log('tsconfig.json', tsconfigJson)
    })
    .catch(err => console.log('error:', err.message));
```

앞서 작성했던 코드와 비교했을 때 훨씬 깔끔해진 것을 확인할 수 있다.

기존 readFilePromise-test.ts
```ts
// Promise

import {readFilePromise} from "./readFilePromise";

readFilePromise('./package.json')
    .then((content: string) => {
        console.log(content);   // package.json 내용
        return readFilePromise('./tsconfig.json');
    })
    .then((content: string) => {
        console.log(content);    // tsconfig.json 내용
        return readFilePromise('.'); // catch 에  EISDIR: illegal operation on a directory, read 전달
    })
    .catch((err: Error) => {
        console.log('error:', err.message);
    })
    .finally(() => {
        console.log('종료');
    });
```

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)