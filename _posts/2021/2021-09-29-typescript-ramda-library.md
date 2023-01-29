---
layout: post
title:  "Typescript - ramda 라이브러리 (1)"
date:   2021-09-29 10:00
categories: dev
tags: typescript
categories: dev
---

이 포스팅은 람다(ramda) 함수형 유틸리티 라이브러리의 기능에 대해 알아본다.

본 포스팅에 사용된 tsconfig.json
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
    "noImplicitAny": false,
    "noImplicitThis": false,
    "strictFunctionTypes": false,
    "paths": { "*": ["node_modules/*"] }
  },
  "include": ["src/**/*"]
}
```

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

> - 람다(ramda) 라이브러리
> - 프로젝트 구성
> - 람다 기본 사용법
>   - `R.range` 함수
>   - `R.tap` 디버깅용 함수
>   - `R.pipe` 함수
>   - 포인트가 없는 함수
>   - 자동 커리
>   - `R.curryN` 함수
>   - 순수 함수
> - 배열에 담긴 수 다루기
>   - 선언형 프로그래밍
>   - 사칙 연산 함수
>   - `R.addIndex` 함수 (다루지 않음)
>   - `R.flip` 함수
>   - 사칙 연산 함수들의 조합 (다루지 않음)
>   - 2차 방정식의 해 구현 (댜루지 않음)
> - 서술자와 조건 연산
>   - `R.lt`, `R.lte`, `R.gt`, `R.gte`
>   - `R.allPass`, `R.anyPass` 로직 함수
>   - `R.not` 함수
>   - `R.ifElse` 함수
> - 문자열 다루기
>   - `R.trim`, `R.toLower`, `R.split`
>   - toCamelCase 함수 만들기

---

## 1. 람다(ramda) 라이브러리

`ramda` 패키지는 [Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/) 에서 설명한 compose 나 pipe 를 사용하는
함수 조합을 쉽게 할 수 있게 설계된 오픈 소스 자바스크립트 라이브러리이다.

- **람다 라이브러리 특징**
    - 타입스크립트 언어와 100% 호환
    - compose, pipe 함수 제공
    - 자동 커리 (auto curry) 기능 제공
    - 포인트가 없는 고차 도움(utility) 함수 제공
    - 조합 논리 함수 일부 제공
    - 하스켈 렌즈(lens) 라이브러리 기능 일부 제공
    - 자바스크립트 표준 모나드 규격(fantasyland-spec) 과 호환

람다 패키지는 많은 유틸리티 함수를 제공하는데 각각 아래 사이트에 자세히 나와있다. 

[Ramda Documentation](https://ramdajs.com/docs/) (함수를 알파벳 순서로 분류)<br />
[Ramda Documentation-DevDocs](https://devdocs.io/ramda/) (함수를 기능 위주로 분류)

기능 위주로 분류된 사이트에서 찾아볼 때는 아래 카테고리에 맞게 찾아보면 도움이 된다.

- function (함수)
  - R.compose, R.pipe, R.curry 등의 함수
- list (리스트)
  - 배열을 대상으로 하는 R.map, R.filter, R.reduce 등의 함수
- logic (로직)
  - R.not, R.or, R.cond 등 boolean 로직 관련 함수
- math (수학)
  - R.add, R.subtract, R.multiply, R.divide 등 수 관련 함수
- object (객체)
  - R.prop, R.lens 등 객체와 렌즈 관련 함수
- relation (관계)
  - R.lt, R.lte, R.gt, R.gte 등 두 값의 관계를 파악하게 하는 함수
- string (문자열)
  - R.match, R.replace, R.split 등 문자열을 대상으로 정규식 등을 할 수 있게 하는 함수
- type (타입)
  - R.is, R.isNil, R.type 등 대상의 타입을 파악하게 하는 함수

---

## 2. 프로젝트 구성

이번 포스팅에선 `chance` 와 `ramda` 패키지를 설치해야 한다.
```shell
> npm i chance ramda
> npm i -D @types/chance @types/ramda
```

package.json
```json
  "devDependencies": {
    "@types/chance": "^1.1.3",
    "@types/node": "^16.10.1",
    "@types/ramda": "^0.27.45",
    "ts-node": "^10.2.1",
    "typescript": "^4.4.3"
  },
  "dependencies": {
    "chance": "^1.1.8",
    "ramda": "^0.27.1"
  }
```

tsconfig.json 에서 *"noImplicitAny": false,* 로 설정해주는데 람다 라이브러리는 자바스크립트를 대상으로 설계되었기 때문에
타입 스크립트는 any 타입을 완전히 자바스크립트적으로 해석해야 한다.
따라서 noImplicitAny 속성값을 false 로 지정하여 사용한다.

람다를 import 할 때는 `import * as R from 'ramda'` 대신 `import {range} from 'ramda'` 로 하는 것이 좋다.<br />
그 이유는 `import * as R` 형식은 람다 라이브러리 중 사용하지 않는 함수들도 패키징되기 때문에 ES5 자바스크립트의 코드의 크기가 커지는 반면
`import {range}` 는 람다에서 range 함수만 패키징되므로 ES5 자바스크립트 코드 크기를 줄여 배포 파일의 크기를 좀 더 줄일 수 있다.

---

## 3. 람다 기본 사용법

### 3.1. `R.range` 함수

`R.range` 함수는 [최소값, 최소값+1, ..., 최대값-1] 형태의 배열을 생성한다.

```ts
R.range(최소값, 최대)
```

```ts
import { range } from "ramda";

console.log(
    range(1, 9+1)
);

/*
[ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]
*/

```

---

### 3.2. `R.tap` 디버깅용 함수

복잡한 함수를 구현하려면 함수 조합을 이용하는데 이 때 단계별로 값이 어떻게 변하는지 파악이 필요하다.<br />
`R.tap` 함수는 2차 고차 함수 형태로 현재 값을 파악할 수 있다. 

```ts
R.tap(콜백 함수)(배열)
```

```ts
//import { range } from "ramda";
import * as R from 'ramda'

const numbers: number[] = R.range(1, 9+1);
R.tap(n => console.log(n))(numbers);    // [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]
```

---

### 3.3. `R.pipe` 함수

람다는 [Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/) 에서 설명한 compose 와 pipe 함수를 `R.compose`, `R.pipe` 형태로 제공한다.<br />
로직 구현시에는 R.pipe 함수가 더 이해하기 편하므로 앞으로 함수를 조합할 때는 아래처럼 R.pipe 함수를 사용할 예정이다.

```ts
//import { range } from "ramda";
import * as R from 'ramda'

const numbers: number[] = R.range(1, 9+1);
R.pipe(
    R.tap(n => console.log(n))  // [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]
)(numbers);
```

---

### 3.4. 포인트가 없는 함수

람다 라이브러리는 200개가 넘는 함수를 제공하는데 대부분 2차 고차 함수 형태이고, 2차 고차 함수는 **포인트가 없는 함수** 형태로 사용이 가능하다.

> 포인트가 없는 함수는 [Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/) 의 *4.5. 포인트가 없는 함수* 를 참고하세요.

아래에서 *dump* 는 포인트가 없는 함수의 전형적인 모습이다.
```ts
//import { range } from "ramda";
import * as R from 'ramda'

// dump 는 포인트가 없는 함수의 전형적인 모습
const dump = R.pipe(
    R.tap(n => console.log(n))
);

dump(R.range(1, 9+1))   // [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]
```

람다는 타입스크립트를 고려해서 만든 라이브러리가 아니기 때문에 포인트가 없는 함수의 형태가 어색하다고 하여 화살표 함수로 만들면 아래와 같은 오류가 난다.
```ts
//import { range } from "ramda";
import * as R from 'ramda'

// TS2322: Type 'unknown' is not assignable to type 'T[]'.
/*
const dump2 = <T>(array: T[]): T[] => R.pipe(
    R.tap(n => console.log(n))
)(array)
*/
```

이 오류는 타입 단언을 사용하여 해결할 수 있다.

> 타입 단언은 [Typescript - 객체, 타입](https://assu10.github.io/dev/2021/09/14/typescript-object-type/) 의 *5.2. 타입 단언 (type assertion)* 를 참고하세요. 

아래 코드를 보면 *(array) as T[]* 에서 *as T[]* 처럼 타입 단언을 사용해 *R.pipe(...)(array)* 가 반환하는 타입을 *any 가 아니라 T[]* 로 바꿔준다.
```ts
//import { range } from "ramda";
import * as R from 'ramda'

// 타입 단언 사용
const dump2 = <T>(array: T[]): T[] => R.pipe(
        R.tap(n => console.log(n))
)(array) as T[];

dump2(R.range(1, 9+1))   // [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]
```

결론적으로!<br />
dump 처럼 포인트가 없는 함수를 만드는 것이 불필요한 타입스크립트 오류를 발생시키지 않는 방안이다.

---

### 3.5. 자동 커리

람다 라이브러리 함수들은 아래처럼 매개변수가 2개인 일반 함수처럼 사용할 수도 있고, 2차 고차 함수로 사용할 수도 있다.<br />
이러한 기능을 **자동 커리**라고 한다.

```ts
//import { range } from "ramda";
import * as R from 'ramda'

console.log(
    R.add(1, 2),    // 3, 매개변수가 2개인 일반함수
    R.add(1)(2)     // 3, 2차 고차 함수
    //R.add(1, 2, 3), // TS2554: Expected 1-2 arguments, but got 3.
)
```

---

### 3.6. `R.curryN` 함수

람다 라이브러리의 함수들은 자동 커리 방식으로 동작할 수 있도록 매개변수의 개수가 모두 정해져있기 때문에 아래와 같은 가변 인수 형태로 구현된 함수는 없다.
```ts
const sum = (...numbers: number[]): number =>
    numbers.reduce((result: number, sum: number) => result + sum, 0);
```

위와 같은 함수를 N차 고차 함수로 만들 때 `R.curryN` 함수를 사용하면 N 개의 매개변수를 가진 1차 함수를 N개의 커리 매개변수를 가지는 N차 고차 함수로 만들어 준다.
```ts
R.curryN(N, 함수)
```

```ts
//import { range } from "ramda";
import * as R from 'ramda'

const sum = (...numbers: number[]): number =>
    numbers.reduce((result: number, sum: number) => result + sum, 0);

const curriedSum = R.curryN(3, sum);

console.log(
    curriedSum(),          // [Function (anonymous)]
    curriedSum(1),         // [Function (anonymous)]
    curriedSum(1)(2),      // [Function (anonymous)]
    curriedSum(1)(2)(3)    // 6
)
```

---

### 3.7. 순수 함수

람다 라이브러리는 [Typescript - 배열, 튜플](https://assu10.github.io/dev/2021/09/21/typescript-array-tuple/) 의 *3.1. 순수 함수* 에서 설명한 순수 함수를 고려해서 설계되었다.<br />
따라서 람다 라이브러리가 제공하는 함수들은 항상 입력 변수의 상태를 변화시키지 않고 새로운 값을 반환한다.

```ts
//import { range } from "ramda";
import * as R from 'ramda'

const originalArray: number[] = [1, 2, 3];

const resultArray: number[] = R.pipe(
    R.map(R.add(1))
)(originalArray);

console.log(originalArray, resultArray);    // [ 1, 2, 3 ] [ 2, 3, 4 ]
```

---

## 4. 배열에 담긴 수 다루기

### 4.1. 선언형 프로그래밍

함수형 프로그래밍은 선언형 프로그래밍 방식으로 코드를 작성하는데 선언형 프로그래밍에서 **모든 입력 데이터는 보통 단순 데이터보다는 배열 형태**를 주로 사용한다.
```ts
//import { range } from "ramda";
import * as R from 'ramda'

const value = 1;

const newValue = R.inc(value);      // 단순 데이터
console.log(newValue);  // 2

const newArray = R.pipe(
    R.map(R.inc)
)([value]);     // 배열
console.log(newArray);  // [2]
```

아래는 `R.tap` 디버깅 함수를 사용하여 배열의 전/후 값을 출력하는 예시이다.
```ts
// R.tap 디버깅 함수로 배열 전/후 값 출력

//import { range } from "ramda";
import * as R from 'ramda'

const numbers: number[] = R.range(1, 9+1);

const incNumbers = R.pipe(
    R.tap(a => console.log('before inc:', a)),  // "strictFunctionTypes": false, 이게 아니면 TS2769: No overload matches this call.   The last overload gave the following error. 오류 발생
    R.map(R.inc),
    R.tap(a => console.log('after inc:', a))
);

const newNumbers: number[] = incNumbers(numbers);

console.log(newNumbers);

/*before inc: [1, 2, 3, 4, 5, 6, 7, 8, 9]
after inc: [2, 3, 4,  5, 6,7, 8, 9, 10]
[2, 3, 4,  5, 6, 7, 8, 9, 10]*/
```

`R.pipe` 안에 `R.tap` 이 여러 번 들어갈 경우 `tsconfig.json` 의 `"strictFunctionTypes"` 를 **false** 로 설정해야 한다.<br />
그렇지 않을 경우 아래와 같은 오류가 발생한다.
>TS2769: No overload matches this call.   The last overload gave the following error. 오류 발생

또한 `R.pipe` 안에서는 console.log 문을 직접 사용할 수 없으므로 반드시 `R.tap` 함수를 사용해야 한다.<br />
람다 라이브러리로 로직 구현시엔 이런 방식으로 디버깅을 한다.

---

### 4.2. 사칙 연산 함수

람다는 아래와 같은 사칙 연산 관련 함수들을 제공한다.
```ts
R.add(a: number)(b: number)
R.subtract(a: number)(b: number)
R.multiply(a: number)(b: number)
R.divide(a: number)(b: number)
```

`R.inc` 는 `R.add(1)` 이다.

```ts
import * as R from 'ramda'

// 포인트가 있는 함수 형태
const inc = (b: number): number => R.add(1)(b);
console.log(inc);   // [Function: inc]

// 포인트가 없는 함수 형태
const inc2 = R.add(1);
console.log(inc2);  // [Function: f1]

// R.map 에 포인트가 있는 형태로 사용
R.map((n: number) => inc(n));

// R.map 에 포인트가 없는 형태로 사용
R.map(inc);
R.map(R.add(1));
```

*R.map((n: number) => inc(n))* 은 `R.map(콜백 함수)` 의 콜백 함수를 익명 함수로 구현한 것인데 *inc* 는 그 자체가 콜백 함수로 사용 가능하므로 *R.map(inc)* 처럼 간결하게 표현 가능하다.

```ts
import * as R from 'ramda'

const incNumbers = R.pipe(
    R.map(R.add(1)),    // 포인트가 없는 함수
    R.tap(a => console.log('after add(1): ', a))    // after add(1):  [2, 3, 4,  5, 6, 7, 8, 9, 10]
);
const newNumbers = incNumbers(R.range(1, 9+1));
```

*R.map(R.add(1))* 를 보면서 포인트가 없는 함수와 콜백 함수를 익명 함수 형태로만 구현하는 것이 아니라는 것을 기억하자.

---

### 4.3. `R.addIndex` 함수

ramda ver. 0.27.1 에서 타입 정의가 잘못 되어있기 때문에 다루지 않는다.

---

### 4.4. `R.flip` 함수

`R.add`, `R.multiply` 와 달리 `R.subtract`, `R.divide` 는 매개 변수 순서에 따라 값이 달라진다.

예를 들어 아래와 같은 코드가 있다고 하자.
```ts
import * as R from 'ramda'

const subtract = a => b => a - b;
const subtractFrom10 = subtract(10);
console.log(subtractFrom10);    // [Function (anonymous)]

const newArray = R.pipe(
    R.map(subtractFrom10),      // (10 - value)
    R.tap(a => console.log(a))  // [9, 8, 7, 6, 5, 4, 3, 2, 1]

)(R.range(1, 9+1));
```

여기서 만일 아래처럼 동작하는 함수는 완전히 새로 만들어야 할까?
```ts
(a)(b) => b - a
```

람다는 `R.flip` 이라는 함수를 제공하는데 `R.flip` 은 2차 고차 함수의 매개 변수의 순서를 바꿔준다.
```ts
const reverseSubtract = R.flip(R.subtract);
```

```ts
import * as R from 'ramda'

const reverseSubtract = R.flip(R.subtract);
const reverseArray = R.pipe(
    R.map(reverseSubtract(10)),      // (value - 10)
    R.tap(a => console.log(a))  // [ -9, -8, -7, -6, -5, -4, -3, -2, -1 ]


)(R.range(1, 9+1));
```

---

### 4.5. 사칙 연산 함수들의 조합

우선순위가 떨어지는 관계로 추후 포스팅 예정입니다.위

---

### 4.6. 2차 방정식의 해 구현

우선순위가 떨어지는 관계로 추후 포스팅 예정입니다.

---

## 5. 서술자와 조건 연산

`Array.filter` 함수에서 사용되는 콜백 함수는 boolean 타입 값을 반환해야 한다.<br />
함수형 프로그래밍에서 boolean 타입 값을 반환해 어떤 조건을 만족하는지를 판단하는 함수를 **서술자 (predicate)** 라고 한다. 

---

### 5.1. `R.lt`, `R.lte`, `R.gt`, `R.gte`

아래는 수를 비교하여 true, false 를 반환하는 서술자들이다.
```ts
R.lt(a)(b): boolean     // a < b 이면 true
R.lte(a)(b): boolean    // a <= b 이면 true
R.gt(a)(b): boolean     // a > b 이면 true
R.gte(a)(b): boolean    // a <= b 이면 true
```

주로 `R.filter` 함수와 결합하여 포인트가 없는 함수 형태로 사용된다.

```ts
import * as R from 'ramda'

// 1. 3보다 같거나 큰 수만 필터링
R.pipe(
    R.filter(R.lte(3)),
    R.tap(n => console.log(n))  // [3, 4, 5,  6, 7, 8, 9, 10]
)(R.range(1, 10+1));

// 위 코드와 동일한 결과
R.pipe(
    R.filter(R.flip(R.gte)(3)),
    R.tap(n => console.log(n))  // [3, 4, 5,  6, 7, 8, 9, 10]
)(R.range(1, 10+1));


// 2. 7보다 작은 수만 필터링
R.pipe(
    R.filter(R.gt(7)),
    R.tap(n => console.log(n))  // [ 1, 2, 3, 4, 5, 6 ]
)(R.range(1, 10+1));


// 3. 3 <= x < 7 범위의 수만 필터링
R.pipe(
    R.filter(R.lte(3)),
    R.filter(R.gt(7)),
    R.tap(n => console.log(n))  // [ 3, 4, 5, 6 ]
)(R.range(1, 10+1));
```

---

### 5.2. `R.allPass`, `R.anyPass` 로직 함수

`R.lt`, `R.gt` 처럼 boolean 타입의 값을 반환하는 함수들은 `R.allPass` 와 `R.anyPass` 로직 함수를 통해 결합이 가능하다.
```ts
R.allPass(서술자 배열)   // 배열의 조건을 모두 만족하면 true
R.anyPass(서술자 배열)   // 배열의 조건을 하나라도 만족하면 true
```

아래는 x 가 min <= x < max 일 때만 통과되는 예시이다.<br />
*5.1. `R.lt`, `R.lte`, `R.gt`, `R.gte`* 의 *3. 3 <= x < 7 범위의 수만 필터링* 이랑 같은 결과이지만 `R.filter` 를 한 번만 사용하여 동작 속도가 좀 더 빠르다.
```ts
import * as R from 'ramda'

// x 가 min <= x < max 일 때만 통과
type NumberToBooleanFunc = (n: number) => boolean;
const selectRange = (min: number, max: number): NumberToBooleanFunc =>
    R.allPass([
        R.lte(min),
        R.gt(max)
    ]);

R.pipe(
    R.filter(selectRange(3, 6+1)),
    R.tap(n => console.log(n))  // [ 3, 4, 5, 6 ]
)(R.range(1, 10+1));
```

---

### 5.3. `R.not` 함수

`R.not` 은 입력값이 true 이면 false 를 반환하고, false 이면 true 를 반환하는 함수이다.

```ts
import * as R from 'ramda'

// x 가 min <= x < max 일 때만 통과
type NumberToBooleanFunc = (n: number) => boolean;
const selectRange = (min: number, max: number): NumberToBooleanFunc =>
        R.allPass([
          R.lte(min),
          R.gt(max)
        ]);

const notRange = (min: number, max: number) =>
        R.pipe(
                selectRange(min, max),
                R.not,
                R.tap(n => console.log(n))  // true, true, false, false...
        );

R.pipe(
        R.filter(notRange(3, 6+1)),
        R.tap(n => console.log(n))  // [ 1, 2, 7, 8, 9, 10 ]
)(R.range(1, 10+1));
```

---

### 5.4. `R.ifElse` 함수

`R.ifElse` 함수는 세 가지 매개 변수를 포함한다.
- 첫 번째 : true/false 를 반환하는 서술자
- 두 번째 : 선택자가 true 를 반환할 때 실행할 함수
- 세 번째 : 선택자가 false 를 반환할 때 실행할 함수

```ts
R.ifElse(
    조건 서술자, 
    true 일 때 실행할 함수,
    false 일 때 실행할 함수
)
```

아래는 1부터 10까지 수에서 중간값 6보다 작은 수는 1씩 감소시키고, 같거나 큰 수는 1씩 증가시키는 예시이다.
```ts
import * as R from 'ramda'

// 1부터 10까지 수에서 중간값 6보다 작은 수는 1씩 감소시키고,
//                           같거나 큰 수는 1씩 증가
const input: number[] = R.range(1, 10+1);
const halfValue: number = input[input.length / 2];

const subtractOrAdd = R.pipe(
    R.map(
        R.ifElse(
            R.lte(halfValue),   // x => half <= x
            R.inc,
            R.dec
        )
    ),
    R.tap(a => console.log(a))  // [0, 1, 2,  3,  4, 7, 8, 9, 10, 11]

)
const result = subtractOrAdd(input);
```

---

## 6. 문자열 다루기

### 6.1. `R.trim`, `R.toLower`, `R.split`

```ts
문자열 배열 = R.split(구분자)(문자열)
문자열 = R.join(구분자)(문자열 배열)
```

```ts
import * as R from 'ramda'

console.log(R.trim('\t hello \n')); // hello
console.log('\t hello \n');             //          hello

console.log(R.toUpper('Hello'));    // HELLO
console.log(R.toLower('Hello'));    // hello

const strSplit: string[] = R.split(' ')('Hello world, typescript~');
console.log(strSplit);  // [ 'Hello', 'world,', 'typescript~' ]

const strJoin: string = R.join(' ')(strSplit);
console.log(strJoin);   // Hello world, typescript~
```

---

### 6.2. toCamelCase 함수 만들기

타입스크립트(자바스크립트) 에서 문자열은 readonly 형태로만 사용이 가능하기 때문에 'hello' 를 'Hello' 로 가공하려면 일단 문자열을 배열로 전환해야 한다.

```ts
import * as R from 'ramda'

type StringToStringFunc = (string) => string;
const toCamelCase = (delim: string): StringToStringFunc => {
    const makeFirstToCapital = (word: string) => {
        const characters = word.split('');
        return characters.map((c, index) => index == 0 ? c.toUpperCase() : c).join('');
    }

    // R.map 의 콜백 함수에 index 매개변수 제공
    const indexedMap = R.addIndex(R.map);

    return R.pipe(
        R.trim,     // 앞 뒤 공백문자 제거
        R.split(delim),  // delim 문자열을 구분자로 배열로 전환
        R.map(R.toLower),   // 배열에 있는 모든 문자열을 소문자로 전환
        indexedMap((value: string, index: number) =>
            index > 0 ?
                // 두 번째 문자열부터 첫 문자만 대문자로 전환
                makeFirstToCapital(value)
                : value
        ),
        // @ts-ignore
        R.join('')  // 배열을 다시 문자열로 전환
    )
}

console.log(
    toCamelCase(' ')('Hello world'),        // helloWorld
    toCamelCase('_')('Hello_Assu_Jhlee')    // helloAssuJhlee
)
```

---

*본 포스팅은 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)
* [Ramda Documentation](https://ramdajs.com/docs/) (함수를 알파벳 순서로 분류)
* [Ramda Documentation-DevDocs](https://devdocs.io/ramda/) (함수를 기능 위주로 분류)