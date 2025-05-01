---
layout: post
title:  "Typescript - 함수 조합"
date: 2021-09-29 10:00
categories: dev
tags: javascript typescript
---

`함수 조합 (function composition)` 은 작은 기능을 하는 여러 함수를 pipe, compose 함수로 조합하여 더 의미있는 함수로 만들어가는 코드 설계 기법이다.<br />
이 포스트는 `함수 조합 (function composition)` 의 기본이 되는 고차 함수와 커리, 이를 이용한 함수 조합에 대해 알아본다.

본 포스트에 사용된 tsconfig.json
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
    "strict": true,
    "noImplicitThis": false,
    "paths": { "*": ["node_modules/*"] }
  },
  "include": ["src/**/*"]
}
```

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

<!-- TOC -->
  * [1. 함수형 프로그래밍](#1-함수형-프로그래밍)
  * [2. 제네릭 함수](#2-제네릭-함수)
    * [2.1. 타입스크립트 제네릭 함수 구문](#21-타입스크립트-제네릭-함수-구문)
    * [2.2. 함수 역할](#22-함수-역할)
    * [2.3. 아이덴티티(Identity, I) 함수](#23-아이덴티티identity-i-함수)
  * [3. 고차 함수와 커리 (curry)](#3-고차-함수와-커리-curry)
    * [3.1. 고차 함수 (high-order function)](#31-고차-함수-high-order-function)
    * [3.2. 부분 적용 함수와 커리 (curry)](#32-부분-적용-함수와-커리-curry)
    * [3.3. 클로저 (closure)](#33-클로저-closure)
  * [4. 함수 조합 (function composition)](#4-함수-조합-function-composition)
    * [4.1. `compose 함수`](#41-compose-함수)
    * [4.2. `pipe 함수`](#42-pipe-함수)
    * [4.3. pipe 와 compose 함수 분석](#43-pipe-와-compose-함수-분석)
    * [4.4. 부분 함수와 함수 조합](#44-부분-함수와-함수-조합)
    * [4.5. 포인트가 없는 함수](#45-포인트가-없는-함수)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## 1. 함수형 프로그래밍

함수형 프로그래밍은 순수 함수와 선언형 프로그래밍의 토대 위에 함수 조합과 모나드 조합으로 코드를 설계하고 구현하는 기법이다.

> 순수 함수는 [Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *3.1. 순수함수* 를 참고하세요.
> 모나드 조합은 각자 찾아보세요.

함수형 프로그래밍 언어는 아래와 같은 기능을 제공한다. (모두 제공하는 것은 아님)
- 정적 타입
- 자동 메모리 관리
- 계산법
- 타입 추론
- 일급 함수
- 대수 데이터 타입 (ADT)
- 패턴 매칭
- 모나드
- 고차 타입

> 대수 타입은 [Typescript 기본](https://assu10.github.io/dev/2021/09/11/typescript-basic/) 의 *2.5. 대수 타입 (ADT)* 을 참고하세요.

타입스크립트는 함수형 언어의 패턴 매칭과 고차 타입이라는 기능을 생략하여 구문을 쉽게 만들었다.

---

## 2. 제네릭 함수

number[] 에서 number 와 같은 타입을 타입 변수 `T` 로 표기할 때 이를 `제네릭 타입` 이라고 한다.<br />
타입스크립트의 함수는 매개변수와 반환값에 타입이 존재하기 때문에 함수 조합을 구현할 때는 제네릭 함수 구문을 사용해야 한다.

---

### 2.1. 타입스크립트 제네릭 함수 구문

타입스크립트에서 제네릭 타입은 함수, 인터페이스, 클래스, 타입 별칭에 적용할 수 있다.

```ts
// 1. function 키워드로 만든 함수에 제네릭 타입 적용
function g1<T>(a: T): void { }
function g2<T, Q>(a: T, b: Q): void { }  // a, b 매개변수를 각각 다른 제네릭 타입으로 지정

// 2. 화살표 함수에 제네릭 타입 적용
const g3 = <T>(a: T): void => { }
const g4 = <T, Q>(a: T, b: Q): void => { }

// 3. 타입 별칭에 제네릭 타입 적용
type Type1Func<T> = (T) => void;
type Type2Func<T, Q> = (T, Q) => void;
type Type3Func<T, Q, R> = (T, Q) => R;
```

> 타입 별칭은 [Typescript - 함수, 메서드](https://assu10.github.io/dev/2021/09/19/typescript-function-method/) 의 *1.2. 타입 별칭 (type alias)* 를 참고하세요.<br />
> [Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *1.5. 제네릭 방식 타입 추론* 와 함께 보면 도움이 됩니다.

이 외 인터페이스와 클래스에 제네릭 타입을 사용하는 방법은 [Typescript - Generic 프로그래밍](https://assu10.github.io/dev/2021/10/01/typescript-generic-programming/) 을 참고하세요.

---

### 2.2. 함수 역할

함수 f 는 값 x에 수식을 적용해 다른 값 y 를 만든다.
```ts
x ~> f ~> y
```

함수 f 가 T 타입의 x 값으로 R 타입의 y 값을 만드는 것은 아래와 같이 표기한다.
```ts
(x: T) ~> f ~> (y: R)
```

이런 관계를 일대일 관계라고 하고, 이런 동작을 하는 함수 f 를 `매핑 (mapping)` 혹은 `맵 (map)` 이라고 한다. 

타입스크립트 언어로 일대일 맵 함수를 만들면 타입 T 인 값을 이용해 타입 R 인 값을 만들어 주어야 하므로 함수 시그니처는 아래와 같다.
```ts
type MapFunc<T, R> = (T) => R
```

---

### 2.3. 아이덴티티(Identity, I) 함수

맵 함수의 가장 단순한 형태는 입력값 x 를 가공없이 그대로 반환(=입력과 출력 타입이 동일) 하는 것이다.<br />
함수형 프로그래밍에서 이러한 역할을 하는 함수 이름을 `identity` 혹은 `I` 라는 단어를 포함하여 표기한다.

MapFunc 타입을 사용해 identity 함수의 시그니처를 표기하면 아래와 같다.
```ts
type MapFunc<T, R> = (T) => R
type IdentityFunc<T> = MapFunc<T, T>
```

*IdentityFunc<T>* 는 다양한 함수를 선언할 때 사용이 가능하다.
```ts
const numberIdentity: IdentityFunc<number> = (x: number): number => x;
const objectIdentity: IdentityFunc<object> = (x: object): object => x;
const arrayIdentity: IdentityFunc<any[]> = (x: any[]): any[] => x;
```

---

## 3. 고차 함수와 커리 (curry)

함수에서 매개변수의 개수를 `애리티 (arity)` 라고 한다.<br />
f() 은 애리티가 0인 함수, f(x) 는 애리티가 1인 함수이다.

함수 f, g, h 모두 애리티가 1이면 아래처럼 연결해서 사용 가능하다.
```ts
x ~> f ~> g ~> h ~> y
```

이를 프로그래밍 언어로 표현하면 아래와 같다.
```ts
y = h(g(f(x)))
```

함수형 프로그래밍에서는 `compose(h, g, f)` 혹은 `pipe(f, g, h)` 의 형태로 함수들을 조합하여 새로운 함수를 만들 수 있다.
`compose`, `pipe` 의 동작 원리를 이해하기 전에 먼저 고차 함수에 대해 알아보도록 하자.

---

### 3.1. 고차 함수 (high-order function)

타입스크립트에서 함수는 변수에 담긴 함수 표현식이고, 이 때 함수 표현식은 일종의 값이므로 함수의 반환값으로 함수를 사용할 수 있다.<br />
이처럼 어떤 함수가 또 다른 함수를 반환할 때 그 함수를 **고차 함수** 라고 한다.

함수가 아닌 단순히 값을 반환하면 *1차 함수*, 1차 함수를 반환하면 *2차 함수* 이고, 이를 함수 시그니처로 표현하면 아래와 같다.

함수 시그니처
```ts
(매개변수: 타입, 매개변수: 타입[,...]) => 반환값 타입
```

```ts
// 고차 함수의 시그니처

type FirstOrderFunc<T, R> = (p1: T) => R
type SecondOrderFunc<T, R> = (p1: T) => FirstOrderFunc<T, R>
type ThirdOrderFunc<T, R> = (p1: T) => SecondOrderFunc<T, R>
```

> 함수 표현식은 [Typescript - 함수, 메서드](https://assu10.github.io/dev/2021/09/19/typescript-function-method/) 의 *2. 함수 표현식* 을 참고하세요.<br />
> 함수 시그니처는 [Typescript - 함수, 메서드](https://assu10.github.io/dev/2021/09/19/typescript-function-method/) 의 *1.1. 함수 시그니처 (function signature)* 를 참고하세요.

고차 함수 시그니처를 참조하여 실제 함수 구성
```ts
// 고차 함수

// 고차 함수의 시그니처
type FirstOrderFunc<T, R> = (p1: T) => R
type SecondOrderFunc<T, R> = (p1: T) => FirstOrderFunc<T, R>
type ThirdOrderFunc<T, R> = (p1: T) => SecondOrderFunc<T, R>

// number 타입의 값을 반환하므로 1차 함수
const add1: FirstOrderFunc<number, number> = (x: number): number => x + 1;
console.log(add1(1));    // 2

// FirstOrderFunc<number, number> 을 반환하므로 2차 고차 함수
const add2: SecondOrderFunc<number, number> =
    (x: number): FirstOrderFunc<number, number> =>
        (y: number): number => x + y;
console.log(add2(1)(2));     // 3

// SecondOrderFunc<number, number> 을 반환하므로 3차 고차 함수
const add3: ThirdOrderFunc<number, number> =
    (x: number): SecondOrderFunc<number, number> =>
        (y: number): FirstOrderFunc<number, number> =>
            (z: number): number => x + y + z;
console.log(add3(1)(2)(3)); // 6
```

위 코드에서 `add(1)(2)` 이런 식으로 함수 호출 연산자를 두 번 연속해서 사용하는데 이를 `커리 (curry)` 라고 한다.

---

### 3.2. 부분 적용 함수와 커리 (curry)

*add2(1)(2)* 나  *add3(1)(2)(3)* 처럼 고차 함수들은 자신의 차수만큼 함수 호출 연산자를 연달아 사용한다.<br />
*add3(1)(2)* 처럼 자신의 차수보다 함수 호출 연산자를 덜 사용하면 `부분 적용 함수 (partially applied function)` 혹은 `부분 함수 (partial function)` 이라고 한다.

앞에서 만든 *add2* 함수의 시그니처는 *FirstOrderFunc<number, number>* 이므로 아래 형태의 함수를 만들 수 있다.
```ts
// 부분 적용 함수
const add2_1: FirstOrderFunc<number, number> = add2(1);
console.log(
    add2_1(2),  // 3
    add2(1)(2)  // 3
);

const add3_1: SecondOrderFunc<number, number> = add3(1);
const add2_2: FirstOrderFunc<number, number> = add3_1(2);
console.log(
    add2_2(3),      // 6
    add3_1(2)(3),   // 6
    add3(1)(2)(3)   // 6
);
```

---

### 3.3. 클로저 (closure)

고차 함수 몸통에 선언되는 변수들은 `클로저 (closure)` 라는 유효 범위를 가진다.<br />
클로저는 **지속되는 유효 범위**를 의미한다.

아래 `(p1: number) => number` 는 add 함수의 리턴 타입으로 `(y: number): number` 에 해당한다.
```ts
// 클로저

function add(x: number): (p1: number) => number {   // 바깥쪽 유효 범위 시작
    return function(y: number): number {            // 안쪽 유효 범위 시작
        return x + y;                               // 클로저
    }                                               // 안쪽 유효 범위 끝
}                                                   // 바깥쪽 유효 범위 끝

// 오류
/*
function add2(x: number): number {
    return function(y: number): number {    // TS2322: Type '(y: number) => number' is not assignable to type 'number'.
        return x + y;
    }
}*/
```

*add* 가 반환하는 함수의 내부 범위에서 보면 변수 x 는 이해할 수 없는 값인데 이렇게 범위 안에서 그 의미를 알 수 없는 변수를 `자유 변수 (free variable)` 라고 한다.<br />
타입스크립트는 자유 변수가 있으면 그 변수의 바깥쪽 유효 범위에서 자유 변수의 의미(선언)를 찾는다.

클로저를 **지속적인 유효 범위** 라고 하는 이뉴는 아래처럼 *add* 함수를 호출해도 변수 x 가 메모리에서 해제되지 않기 때문이다.
```ts
const add1 = add(1);
console.log(add1);  // [Function (anonymous)]
```

자유 변수는 고차 함수가 **부분 함수가 아닌 값** 을 발생해야 메모리가 해제된다.
```ts
const result = add1(2);
console.log(result) // 3
```

클로저는 메모리가 해제되지 않고 프로그램이 끝날 때까지 지속될 수도 있다.<br />
아래에서 makeNames 함수는 *() => string* 타입의 함수를 반환하는 2차 고차 함수이다.
```ts
// 클로저

// () => string 는 makeNames 의 리턴 타입으로 안쪽 유효 범위의 (): string 에 해당
const makeNames = (): () => string => { // 바깥쪽 유효 범위
    const names = ['assu', 'jhlee'];
    let index = 0;
    return (): string => {  //  안쪽 유효 범위
        if (index == names.length) {
            index = 0
        }
        console.log(index);
        return names[index++];
    }
}

const makeName: () => string = makeNames();     // () => string 타입의 함수를 얻음
console.log(
    [1,2,3,4,7,6].map(n => makeName())
);

/*
0
1
0
1
0
1
[ 'assu', 'jhlee', 'assu', 'jhlee', 'assu', 'jhlee' ]
*/
```

index 는 names.length 와 값이 같아지면 다시 0 이 되기 때문에 makeName 함수를 사용하는 한 makeNames 함수에 할당된 클로저는 해제되지 않는다.

> '값'이 아닌 '부분 함수'를 리턴하기 때문에 makeName 함수를 사용하는 한 클로저가 해제되지 않는 것 같은데.. 확실히 모르겠다. 

---

## 4. 함수 조합 (function composition)

**함수 조합**은 작은 기능을 구현한 함수를 여러 번 조합하여 더 의미있는 함수를 만드는 프로그램 설계 기법이다.

애리티가 모두 1 인 함수 f, g, h 는 아래처럼 함수를 연결하여 사용할 수 있다고 하였다.
```ts
x ~> f ~> g ~> h ~> y
```

fgs.ts
```ts
export const f = <T>(x: T): string => `f(${x})`;
export const g = <T>(x: T): string => `g(${x})`;
export const h = <T>(x: T): string => `h(${x})`;
```

---

### 4.1. `compose 함수`

아래 compose 함수는 가변 인수 스타일로 함수들의 배열을 입력받아 그 함수들을 조합하여 매개 변수 x 를 입력받는 1차 함수를 반환한다.

compose.ts
```ts
// compose 함수

export const compose = <T>(...functions: readonly Function[]): Function => (x: T): T => {
    const deepCopiedFunctions = [...functions]
    return deepCopiedFunctions.reverse().reduce((value, func) => func(value), x)
}
```

애리티가 1인 함수 f, g, h 함수들을 조합해보자.

index.ts
```ts
// compose 함수

import { compose } from "./compose";
import { f, g, h } from "./fgh"

const composedFGH = compose(h, g, f);
console.log(composedFGH('x'));  // h(g(f(x)))
```

> 가변 인수 함수는 [Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *3.5. 순수 함수로 가변 인수 함수 구현* 를 참고하세요.

`가변 인수 함수` 의 기본 형태
```ts
const mergeArray = (...arrays) => { }
```

> reduce 메서드는 [Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *2.3. `reduce` 메서드* 를 참고하세요.

배열의 타입이 `T[]` 일 때 `reduce` 메서드는 아래의 형태이다.
```ts
reduce(callback: (result: T, value: T), initiaValue: T): T
```

아래는 inc 라는 함수를 세 번 조합하는 예시이다.
```ts
import { compose } from "./compose";

const inc = (x: number) => x + 1;

const composedInc = compose(inc, inc, inc);
console.log(composedInc(1));    // 4
```

---

### 4.2. `pipe 함수`

`pipe 함수` 는 compose 와 동작 원리는 같은데 단지 조합하는 함수들의 순서만 다르다.
`pipe 함수` 는 compose 와 매개변수들을 해석하는 순서가 반대이므로 reverse 코드가 없다.

pipe.ts
```ts
export const pipe = <T>(...functions: readonly Function[]): Function => (x: T): T => {
    return functions.reduce((value, func) => func(value), x)
}
```

index.ts
```ts
import { f, g, h } from "./fgh"
import { compose } from "./compose";
import { pipe } from "./pipe";

const composedFGH = compose(h, g, f);
console.log(composedFGH('x'));  // h(g(f(x)))

const pipedFGH = pipe(h, g, f);
console.log(pipedFGH('x'));     // f(g(h(x)))
```

---

### 4.3. pipe 와 compose 함수 분석

pipe 함수의 구현 순서를 보면서 동작 원리를 분석해보자.

완성된 pipe 함수
```ts
export const pipe = <T>(...functions: readonly Function[]): Function => (x: T): T => {
    return functions.reduce((value, func) => func(value), x)
}
```

pipe 함수는 *pipe(f)* , *pipe(f, g, h)* 와 같이 가변 인수 방식으로 동작하므로 매개 변수를 아래와 같이 설정한다.
```ts
export const pipe = (...functions)
```

함수 f, g 의 시그니처가 아래와 같다면 functions 의 타입을 설정하기 어렵다.
```ts
f 함수의 시그니처: (number) => string 
g 함수의 시그니처: (string[]) => number
```

이렇게 각 함수의 시그니처가 모두 다르면 모두 포함할 수 있는 제네릭 타입을 적용하기 힘들기 때문에 자바스크립트 타입 `Function` 들의 배열인 *Function[]* 으로 설정한다.

```ts
export const pipe = (...functions: Function[])
```

그리고 functions 배열을 조합하여 어떤 함수를 반환해야 하므로 반환 타입은 Function 으로 설정한다. 
```ts
export const pipe = (...functions: Function[]): Function
```

조합된 결과 함수는 애리티가 1 이므로 매개변수 x 를 입력받는 함수를 작성하는데 이 내용을 제네릭 타입으로 표현하면 타입 T 의 값 x 를 입력받아 T 타입의 값을 반환하는 함수가 된다.
```ts
export const pipe = <T>(...functions: Function[]): Function => (x: T): T
```

이제 함수 몸통을 구현할 차례인데 functions 배열에 [f, g, h] 가 있다고 가정할 때 *h(g(f(x)))* 의 형태의 함수를 만들어야 한다.
```ts
export const pipe = <T>(...functions: Function[]): Function => (x: T): T => {
    // functions 는 [f, g, h]
}
```

Array 가 제공하는 `reduce` 메서드는 아래처럼 변수 x를 reduce 메서드의 초기값으로 설정하면 아래 **<함수>** 라고 된 부분만 구현하면 된다.
```ts
export const pipe = <T>(...functions: Function[]): Function => (x: T): T => {
    return functions.reduce(<함수>, x)
}
```

**<함수>** 부분은 (value, func) 형태의 매개변수 구조를 가져야 하는데 그 이유는 reduce 메서드의 두 번째 매개변수 x는 항상 배열의 아이템이기 때문이다.
```ts
export const pipe = <T>(...functions: Function[]): Function => (x: T): T => {
    return functions.reduce((value, func) => func(value), x)
}
```

compose 함수는 pipe 함수와 매개변수 방향이 반대이다. 
*functions.reverse()* 를 호출하면 될 것 같지만 이렇게 하게 되면 배열의 원본이 변경되므로 전개 연산자로 전개하여 깊은 복사를 해야 한다.

---

### 4.4. 부분 함수와 함수 조합

고차 함수의 부분 함수는 함수 조합에 사용될 수 있다.

inc 함수는 add2 의 부분 함수이고, add3 은 inc 와 add2(2) 두 부분 함수를 조합해서 만든 함수이다.
```ts
// 부분 함수와 함수 조합

import { pipe } from "./pipe";

// 2차 고차 함수
const add2 = (x: number) => (y: number) => x + y;
const inc = add2(1);    // add2의 부분함수
console.log(inc);   // [Function (anonymous)]

const add3 = pipe(inc, add2(2));
console.log(add3(1));   // 4
```

---

### 4.5. 포인트가 없는 함수

아래의 map 함수는 함수 조합을 고려하여 설계한 것으로 map(f) 형태의 부분 함수를 만들면 compose, pipe 에 사용할 수 있다.<br />
이렇게 합수 조합을 고려하여 설계한 함수를 **포인트가 없는 함수** 라고 한다.
```ts
// 포인트가 없는 함수
const map = (f: any) => (a: any) => a.map(f);

const map2 = <T, R>(f: (T) => R) => (a: T[]): R[] => a.map(f)
```

map 함수를 제네릭 형태로 구현하면 map2 의 형태인데 함수 조합 코드는 타입 주석을 생략하여 컴파일러가 타입을 추론하는 것이 이해하기에 편하다.

```ts
// 포인트가 없는 함수

import { pipe } from "./pipe";

const map = (f: any) => (a: any) => a.map(f);
//const map2 = <T, R>(f: (T) => R) => (a: T[]): R[] => a.map(f)     

const square = (value: any) => value * value;
const squareMap = map(square);             // 포인트가 없는 함수, 아래처럼 굳이 a 를 지정하지 않아도 된다.
//const squareMap2 = a => map(square);     // 포인트가 있는 함수

const fourSquare = pipe(squareMap, squareMap);

console.log(fourSquare([3, 4]));    // [81, 256]
```

이번엔 포인트가 없는 함수 squareMap 과 sumArray 를 pipe 로 조합한 예시이다.
```ts
// 포인트가 없는 함수 - reduce

import {pipe} from "./pipe";

const map = (f: any) => (a: any) => a.map(f);
const square = (value: any) => value * value;
const squareMap = map(square);


const reduce = (f: any, initValue: any) => (a: any) => a.reduce(f, initValue);
// const reduce2 = <T>(f: (sum: T, value: T) => T, initValue: T) => (a: T[]): T => a.reduce(f, initValue);

const sum = (result: number, value: number) => result + value;
const sumArray = reduce(sum, 0);

const pitagoras = pipe(squareMap, sumArray, Math.sqrt);

console.log(pitagoras([3,4]));  // 5 (3*3 + 4*4 의 제곱근)
```

함수의 조합은 이렇게 복잡하지 않은 함수들을 compose, pipe 로 조합하여 복잡한 내용을 쉽게 만들 수 있다.

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)