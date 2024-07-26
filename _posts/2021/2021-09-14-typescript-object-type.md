---
layout: post
title:  "Typescript - 객체, 타입"
date: 2021-09-14 10:00
categories: dev
tags: typescript
---

이 포스트는 타입스크립트 객체와 타입에 대해 알아본다.

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

<!-- TOC -->
* [1. 타입스크립트에서 지원하는 타입](#1-타입스크립트에서-지원하는-타입)
  * [1.1. 원시값 타입](#11-원시값-타입)
  * [1.2. 객체 타입](#12-객체-타입)
  * [1.3. 함수 타입](#13-함수-타입)
  * [1.4. `any` / `unknown` / `never`](#14-any--unknown--never)
    * [`any`](#any)
    * [`unknown`](#unknown)
    * [`never`](#never)
* [2. 변수](#2-변수)
* [3. 인터페이스](#3-인터페이스)
  * [3.1. 인터페이스 선언](#31-인터페이스-선언)
  * [3.2. 선택 속성 (`?,` Optional Property)](#32-선택-속성--optional-property)
  * [3.3. 익명 인터페이스](#33-익명-인터페이스)
* [4. 객체와 클래스](#4-객체와-클래스)
  * [4.1. 생성자 (constructor)](#41-생성자-constructor)
  * [4.2. 인터페이스 구현 (implements)](#42-인터페이스-구현-implements)
  * [4.3. 추상 클래스 (abstract)](#43-추상-클래스-abstract)
  * [4.4. static 속성](#44-static-속성)
* [5. 비구조화](#5-비구조화)
  * [5.1. 비구조화 할당문](#51-비구조화-할당문)
  * [5.2. 잔여 연산자와 전개 연산자 (`...`)](#52-잔여-연산자와-전개-연산자-)
* [6. 객체의 타입 변환](#6-객체의-타입-변환)
  * [6.1. 타입 변환 (type conversion)](#61-타입-변환-type-conversion)
  * [6.2. 타입 단언 (type assertion)](#62-타입-단언-type-assertion)
* [7. 타입 구성](#7-타입-구성)
  * [7.1. 유니언 타입](#71-유니언-타입)
  * [7.2. 제네릭 타입](#72-제네릭-타입)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 타입스크립트에서 지원하는 타입

타입스크립트는 자바스크립트가 가지는 자료형을 모두 포함한다.  
자바스크립트의 타입은 원시값, 객체, 함수가 있는데 `typeof` 를 이용하여 타입을 알 수 있다.  

`typeof instance === "undefined"`

---

## 1.1. 원시값 타입

|  typeof   | 설명                                | 할당 가능한 값                                                                                  |
|:---------:|:----------------------------------|:------------------------------------------------------------------------------------------|
|  boolean  | 참, 거짓                             | true, false                                                                               |
|   null    | 유효하지 않음                           | null                                                                                      |
| undefined | 값이 존재하지 않음 (변수 선언 후 값이 할당되지 않았음)  | undefined                                                                                 |
|  number   | 배정밀로 64비트 형식 IEEE 754 의 값         | - -(2<sup>53</sup> -1) 와 2<sup>53</sup> -1 사이의 정수와 실수<br/>- Nan<br/>- +Infinity, Infinity |
|  bigint   | Number 의 범위를 넘어서는 정수              | 예) const x = 2n ** 53n; <br/>정수 끝에 n 을 추가                                                 |
|  string   | 문자열, immutable(변경 불가능)함           | 예) 'hello'                                                                                 |
|  symbol   | 유일하고 변경 불가능한 원시값, 객체 속성의 키로 사용 가능 ||

---

## 1.2. 객체 타입

객체 타입은 속성을 갖는 데이터 컬렉션이다.  
속성은 key, value 로 표현되는데 value 는 다시 자바스크립트의 타입을 갖는다.

```ts
const aa = {
    name: 'assu',
    age: 20,
    hobby: ['tennis']
}
```

---

## 1.3. 함수 타입

자바스크립트는 함수를 변수에 할당하거나 다른 함수의 인자로 전달, 함수의 결과로 반환할 수 있다. 이러한 특징을 일급 함수(first-class function) 이라고 한다.  
함수 abc 의 타입을 검사하면 'function' 이 출력된다.

`typeof abc === "function"`

> 함수 타입에 대한 더 상세한 내용은 [Typescript - 함수, 메서드](https://assu10.github.io/dev/2021/09/19/typescript-function-method/) 을 참고하세요.

---

## 1.4. `any` / `unknown` / `never`

### `any`

- 자바스크립트와 같이 어떠한 타입의 값도 받을 수 있는 타입
- 런타임에 오류를 일으킬 가능성이 있음

### `unknown`

- any 타입과 마찬가지로 어떤 타입도 할당 가능하지만 다른 변수에 할당 또는 사용할 때 타입을 강제하도록 하여 any 가 일으키는 오류를 줄여줌

### `never`

- never 타입 변수에는 어떤 값도 할당할 수 없음
- 함수의 리턴 타입으로 지정하면 함수가 어떤 값도 반환하지 않거나 항상 오류를 출력한다는 것을 뜻함
```ts
// 항상 오류 발생
function invalid(message:string): never {
  throw new Error(message);
}

// never 타입을 결과 추론(Inferred)
function fail() {
  return invalid('실패');
}

// 무한 루프
function infiniteAnimate(): never {
  while ( true ) { infiniteAnimate(); }
}
```
- 아래와 같이 특정 타입의 값을 할당받지 못하도록 하는데 사용 가능
```ts
// NonString 타입은 어떤 타입이든 될 수 있지만 string 타입인 경우는 never 로 추론하여 string 타입의 값은 할당될 수 없음
type NonString<T> = T extends string ? never : T;
```

---

# 2. 변수

`[선언 키워드] [변수명]: [타입]`

선언 키워드는 const, let or var 를 사용한다.  
let 과 var 의 차이는 hoisting 여부이다. var 는 변수를 사용한 후에 선언이 가능하지만 let 은 그렇지 않다.

```typescript
// var 는 변수 사용 후 선언 가능
varA = 1;
var varA: number;

// let 은 변수 사용 후 선언 불가능
letB = 1;
```

자바스크립트에 대응하는 타입스크립트의 주요 타입은 아래와 같다.

| javascript  | typescript |
|:-----------:|:---:|
|   Number    | number |
|   Boolean   | boolean |
|   String    | string |
|   Object    | object |

타입스크립트는 자바스크립트와의 호환을 위해 `any` 타입을 제공하는데 아래 코드를 보자.

```ts
let a: any = 0 
a = 'hello'     // 오류 아님
a = true        // 오류 아님
a = {}          // 오류 아님
```

a 의 타입이 `any` 이므로 어떤 종류의 값도 저장이 가능하다.

---

# 3. 인터페이스

인터페이스를 보기 전에 타입스크립트에서의 타입 계층을 먼저 보도록 하자.

```shell
 any
    ├── boolean
    ├── number
    ├── object
    │   ├── class
    │   └── interface
    └── string
```

그리고 저 계층들 중 가장 하위층에 `undefined` 가 있다. (tree 로 표현이 안되서... 말로 풀어서 씁니다..)

위 계층을 보면 `obejct` 로 선언된 변수는 `number`, `boolean`, `string` 타입의 값을 가질 수 없지만 아래처럼 속성명이 다른 객체를 모두 담을 수 있다.

```ts
let o: object = {name: 'assu', age: 32}
o = {first: 1, second: 2}
```

`object` 타입은 마치 객체를 대상으로 하는 `any` 타입처럼 동작하는데 타입스크립트에서 인터페이스는 이렇게 동작하지 않게 하려는 목적(=객체의 타입을 정의)으로 사용된다.<br />
즉, 변수 `o` 는 항상 name, age 속성으로 구성된 객체만 가질 수 있도록 제한하는 것이다.

---

## 3.1. 인터페이스 선언

```ts
interface IPerson {
    name: string
    age: number
}
```

인터페이스 속성들을 여러 개 나열할 때는 쉼표 `,` 대신 세미콜론 ` ` 을 구분자로 쓰거나 아무것도 쓰지 않고 단순히 줄바꿈만 해도 된다. 

아래 인터페이스의 목적은 IPerson 에 name, age 속성이 둘 다 있는 객체만 유효하도록 객체의 타입을 좁히는 것이다.
```ts
interface IPerson {
    name: string
    age: number
}

let good1: IPerson = {name: 'assu', age: 20}

let bad1: IPerson = {name: 'assu'}  // age 가 없어서 오류
let bad2: IPerson = {name: 'assu', age: 20, address: 'suwon'}   // address 가 있어서 오류
```

---

## 3.2. 선택 속성 (`?,` Optional Property)

인터페이스 설계 시 필수가 아닌 선택 옵션은 `속성명 뒤에 물음표 기호` 를 붙여 만든다.

```ts
interface IPerson {
    name: string
    age: number
    address?: string
}

let good1: IPerson = {name: 'assu', age: 20}        // address 는 선택 속성이므로 없어도 오류가 아님

let bad1: IPerson = {name: 'assu'}  // age 가 없어서 오류
let good2: IPerson = {name: 'assu', age: 20, address: 'suwon'}
```

---

## 3.3. 익명 인터페이스

익명 인터페이스는 `interface` 키워드도 사용하지 않고, 인터페이스 이름도 없는 인터페이스를 의미한다.

```ts
// 익명 인터페이스
// 변수 ai 는 interface 키워드도 사용하지 않고, 인터페이스 이름도 없는 익명 인터페이스
let ai: {
    name: string
    age: number
    etc?: boolean
} = {name: 'assu', age: 20}

// 익명 인터페이스 활용
function printMe(me: {name: string, age: number, etc?: boolean}) {
    console.log(
        me.etc ?
            `${me.name} ${me.age} ${me.etc}` :
            `${me.name} ${me.age}`
    )
}

printMe(ai)     // assu 20
```

---

# 4. 객체와 클래스

```ts
// 클래스
class Person1 {
    name: string
    age?: number
}

let assu1: Person1 = new Person1() 
assu1.name = 'assu'
assu1.age = 20 

console.log(assu1)      // Person1 { name: 'assu', age: 20 }
```

---

## 4.1. 생성자 (constructor)

```ts
class Person2 {
    constructor(public name: string, public age?: number) { }
}

let assu2: Person2 = new Person2('assu2', 20)
console.log(assu2)  // Person2 { name: 'assu2', age: 20 }
```

생성자 매개변수에 `public` 접근 제한자를 붙이면 해당 매개변수의 이름을 가진 속성이 클래스에 선언된 것처럼 동작한다.

---

## 4.2. 인터페이스 구현 (implements)

```ts
// 인터페이스
interface IPerson {
    name: string
    age?: number
}

class Person2 implements IPerson {
    name: string
    age: number
}

class Person3 implements IPerson {
    constructor(public name: string, public age?: number) { }
}

let assu3: Person3 = new Person3('assu')
console.log(assu3)      // Person3 { name: 'assu', age: undefined }
```

---

## 4.3. 추상 클래스 (abstract)

```ts
// 추상 클래스
abstract class AbstractPerson {
    abstract name: string
    constructor(public age?: number) { }
}

class Person extends AbstractPerson {
    constructor(public name: string, age?: number) {
        super(age) 
    }
}

let assu1: Person = new Person('assu1')
let assu2: Person = new Person('assu2', 20)

console.log(assu1)  // Person { age: undefined, name: 'assu1' }
console.log(assu2)  // Person { age: 20, name: 'assu2' }
```

---

## 4.4. static 속성

다른 객체지향 언어처럼 타입스크립트 클래스도 정적인 속성을 가질 수 있다.

```ts
// static 속성
class Person {
    static addr: string = 'seoul'
}

let assuAddr = Person.addr
console.log(assuAddr)
```

---

# 5. 비구조화

## 5.1. 비구조화 할당문
```ts
// 비구조화 할당
// Interfaces.ts
export interface IPerson {
    name: string
    age?: number
}

export interface ICompany {
    name: string
    age?: number
}

// index.ts
import {IPerson, ICompany} from "./Interfaces"

let assu: IPerson = {name: 'assu', age: 20},
    jhlee: IPerson = {name: 'jhlee'}

let wev: ICompany = {name: 'wev', age: 10},
    hib: ICompany = {name: 'hib'}

console.log(assu)   // { name: 'assu', age: 20 }
console.log(jhlee)  // { name: 'jhlee' }

let {name, age} = assu  // 비구조화 할당
console.log(name, age)  // assu 20
```

---

## 5.2. 잔여 연산자와 전개 연산자 (`...`)

`...` 는 사용되는 위치에 따라 `잔여 연산자(rest operator)` 혹은  `전개 연산자(spread operator)` 로 불리는데 잔여 연산자부터 살펴보도록 하자.

아래 코드를 보면 country 와 city 를 제외한 나머지 속성을 detail 이라는 변수에 저장할 때 `...` `잔여 연산자`를 붙여서 사용하였다.

반면 coord 와 merged 는 객체 앞에 `...` `전개 연산자` 를 붙여서 사용하였다. 
즉, 점 3개 연산자가 비구조화 할당문이 아닌 곳에서 사용될 때는 `전개 연산자` 로서 사용된다. (여러 개의 객체를 합친 하나의 새로운 객체를 만들 때)

```ts
// 잔여 연산
let address: any = {
    country: 'Korea',
    city: 'seoul',
    address1: 'Jam-sil',
    address2: '311-10'
}
const {country, city, ...detail} = address
console.log(country)    // Korea
console.log(detail)     // { address1: 'Jam-sil', address2: '311-10' }


// 전개 연산
let coord = {...{x: 0}, ...{y: 0}}
console.log(coord)  //{ x: 0, y: 0 }

let part1 = {name: 'assu'}
let part2 = {age: 20}
let part3 = {city: 'suwon', country: 'kr'}
let part4 = {name: 'reAssu'}
let merged = {...part1, ...part2, ...part3, ...part4}

console.log(merged) // { name: 'reAssu', age: 20, city: 'suwon', country: 'kr' }
```

---

# 6. 객체의 타입 변환

## 6.1. 타입 변환 (type conversion)

특정 타입의 변수값을 다른 타입의 값으로 변환하는 기능을 `타입 변환(type conversion)` 이라고 한다.

아래 코드를 보자.
```ts
// 타입 변환
let person: object = {name: 'assu', age: 20} 
person.name = 'assu2'   // TS2339: Property 'name' does not exist on type 'object'.
```

person 의 타입은 object 인데 object 타입은 name 속성을 가지지 않기 때문에 아래와 같은 오류가 발생한다.
`TS2339: Property 'name' does not exist on type 'object'.`

이럴 때는 person 변수를 일시적으로 name 속성이 있는 타입, 즉 `{name: string}` 으로 변환하여 person.name 속성값을 갖도록 할 수 있다.
```ts
let person: object = {name: 'assu', age: 20} 
(<{name: string}>person).name = 'assu2' 

console.log(person)     // { name: 'assu2', age: 20 }
```

---

## 6.2. 타입 단언 (type assertion)

타입스크립트에서는 `타입 변환` 이 아닌 `타입 단언` 이라는 용어도 사용하는데 `타입 단언` 은 아래 두 가지 형태가 있다.
```ts
(<타입>객체)
(객체 as 타입)
```

```ts
// 타입 단언
interface INameable {
    name: string
}

let obj: object = {name: 'assu'} 

let name1 = (<INameable>obj).name 
let name2 = (obj as INameable).name 

console.log(name1, name2)   // assu assu
```

---

# 7. 타입 구성

자바스크립트 변수는 어떠한 타입의 값도 할당할 수 있는데 이런 개념을 [덕 타이핑](https://ko.wikipedia.org/wiki/%EB%8D%95_%ED%83%80%EC%9D%B4%ED%95%91) 이라고 한다.

## 7.1. 유니언 타입

여러 타입을 조합한 타입이다.

```ts
function getLength(obj: string | string[]) {
    return obj.length;
}
```

유니언 타입을 활용하면 변수가 가질 수 있는 값도 제한할 수 있다.

```ts
type Status = "READY" | "DONE";
```

하지만 위 코드보다는 아래처럼 열거형으로 사용하는 것이 더 편하다.
```ts
enum Status {
    READY = "ready",
    DONE = "done"
}
```

---

## 7.2. 제네릭 타입

어떠한 타입이든 정의될 수 있지만 호출되는 시점에 타입이 결정된다.

```ts
function identity(arg: any): any {
    return arg;
}
```

반환값이 any 로 되어있기 때문에 arg 에 "test" 를 인수로 전달할 경우 전달한 인수의 string 타입이 반환될 때 any 가 되어버린다.  
이럴 때는 아래와 같이 제네릭 타입을 사용하여 리턴되는 값의 타입이 함수를 호출하는 시점의 인수로 넣은 타입으로 결정되도록 할 수 있다.
```ts
function identity<T>(arg: T): T {
    return arg;
}
```

> 제네릭 타입의 좀 더 상세한 내용은 [Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/) 과
> [Typescript - Generic 프로그래밍](https://assu10.github.io/dev/2021/10/01/typescript-generic-programming/) 을 참고하세요.

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)
* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [Typescript Guidebook](https://yamoo9.gitbook.io/typescript/types/never)
* [TypeScript의 unknown, any 그리고 never](https://xo.dev/typescript-unknown-any-never/)
* [덕 타이핑](https://ko.wikipedia.org/wiki/%EB%8D%95_%ED%83%80%EC%9D%B4%ED%95%91)
* [Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/)
* [Typescript - Generic 프로그래밍](https://assu10.github.io/dev/2021/10/01/typescript-generic-programming/)