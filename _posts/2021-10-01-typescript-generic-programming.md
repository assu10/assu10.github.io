---
layout: post
title:  "Typescript - Generic 프로그래밍"
date:   2021-10-01 10:00
categories: dev
tags: typescript
categories: dev
---

이 포스팅은 제네릭 타입에 대해 알아보고, 함수형 프로그래밍 관점에서 제네릭 타입이 어떻게 활용되는지 알아본다.

본 포스팅에 사용된 tsconfig.json
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "esModuleInterop": true,
    "target": "ES2019",
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

> - 제네릭 타입
> - 제네릭 타입 제약
>   - `new` 타입 제약
>   - 인덱스 타입 제약
> - 대수 데이터 타입 (ADT)
>   - 합집합 타입 (`|`)
>   - 교집합 타입 (`&`)
>   - 합집합 타입 구분하기
>   - 식별 합집합 구문
> - 타입 가드
>   - `instanceof` 연산자
>   - 타입 가드 (type guard)
>   - `is` 연산자를 활용한 사용자 정의 타입 가드 함수 제작
> - F-바운드 다형성
>   - 프로젝트 구성
>   - `this` 타입과 `F-바운드` 다형성
>       - F-바운드 타입
>       - IValueProvider<T> 인터페이스의 구현
>       - IAddable<T> 와 IMultiplyable<T> 인터페이스 구현
> - nullable 타입과 프로그램 안전성
>   - 프로젝트 구성
>   - nullable 타입
>   - 옵션 체이닝 연산자 `?.`
>   - null 병합 연산자 `??`
>   - nullable 타입의 함수형 방식 구현
>       - Some 클래스 구현
>       - None 클래스 구현
>       - Option 클래스 구현 및 사용
>       - Some 과 None 클래스 사용
>   - Option 타입과 예외 처리

---

## 1. 제네릭 타입

[Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/) 의 *2.1. 타입스크립트 제네릭 함수 구문* 에서 제네릭 타입은 인터페이스, 클래스, 함수, 타입 별칭에 사용할 수 있다고 하였다.

제네릭 타입은 해당 심벌의 타입을 미리 지정하지 않고 다양한 타입에 대응하려고 할 때 사용한다. 

예를 들어 어떤 인터페이스가 value 라는 이름의 속성을 가질 때, 이 value 의 타입을 string, number 등으로 특정하지 않고 T 로 지정하여 제네릭 타입으로 만들 수 있다.
이 때 **인터페이스 이름 뒤**에는 `<T>` 를 표기한다.

```ts
// 제네릭 인터페이스 구문
interface IValueable<T> {
    value: T
}

// 제네릭 클래스 구문
class Valuable<T> {
    constructor(public value: T) { }
}

// 제네릭 함수 구문 - function
function identity<T>(arg: T): T {
    return arg;
}

// 제네릭 함수 구문 - 화살표 함수
const g3 = <T>(a: T): void => { }
const g4 = <T, Q>(a: T, b: Q): void => { }

// 제네릭 타입 별칭 구문
type IValuable<T> = {
    value: T
}

// 제네릭 타입 별칭 구문
type Type1Func<T> = (T) => void;
type Type2Func<T, Q> = (T, Q) => void;
type Type3Func<T, Q, R> = (T, Q) => R;
```

```ts
// 제네릭 인터페이스 정의
interface IValuable<T> {
    value: T
}

// 제네릭 인터페이스를 구현하는 제네릭 클래스는 아래 constructor() 처럼 자신이 가진 타입변수 T 를 인터페이스 쪽 제네릭 타입 변수로 넘길 수 있다.
class Valuable<T> implements IValuable<T> {
    constructor(public value: T) { }
}

// 제네릭 함수는 아래처럼 자신의 타입변수 T 를 제네릭 인터페이스의 타입 변수 쪽으로 넘기는 형태로 구현
const printValue = <T>(o: IValuable<T>): void => console.log(o.value);

// printValue 함수는 아래처럼 다양한 타입을 대상으로 동작한다.
printValue(new Valuable<boolean>(true));
printValue({value: true})
printValue(new Valuable<number[]>([1,2,3]));
printValue(new Valuable(1));        // 타입 변수를 생략하면 스스로 추론
printValue(new Valuable('test'));
```

---

## 2. 제네릭 타입 제약

제네릭 타입 제약은 타입 변수에 적용할 수 있는 타입의 범위를 한정하는 기능이다.
제네릭 함수의 타입을 제한할 때는 아래의 구문을 사용한다.

```ts
<최종 타입1 extends 타입1, 최종 타입2 extends 타입2>(a: 최종 타입1, b: 최종 타입2, ...) => { }
```

매개변수 타입을 어떤 방식으로 제약하느냐만 다르고 사용법은 완전히 동일하다.
```ts
// 제네릭 인터페이스 정의
interface IValuable<T> {
    value: T
}

// 제네릭 인터페이스를 구현하는 제네릭 클래스는 아래 constructor() 처럼 자신이 가진 타입변수 T 를 인터페이스 쪽 제네릭 타입 변수로 넘길 수 있다.
class Valuable<T> implements IValuable<T> {
    constructor(public value: T) { }
}

// 제네릭 함수는 아래처럼 자신의 타입변수 T 를 제네릭 인터페이스의 타입 변수 쪽으로 넘기는 형태로 구현
const printValue = <T>(o: IValuable<T>): void => console.log(o.value);

// 제네릭 타입 제약 구문
const printValueT = <Q, T extends IValuable<Q>>(o: T) => console.log(o.value);

// 매개변수 타입을 어떤 방식으로 제약하느냐만 다르고 사용법은 완전히 동일함
printValue(new Valuable(1));
printValueT(new Valuable(1));

printValue({value: true});
printValueT({value: true});
```

### 2.1. `new` 타입 제약

팩토리 함수는 `new` 연산자를 사용해 객체를 생성하는 기능을 하는 함수를 말한다.<br />
보통 팩토리 함수는 객체를 생성하는 방법이 너무 복잡할 때 이를 단순화하려는 목적으로 구현한다.

아래는 *create* 함수의 매개변수 *type* 은 실제로는 *타입* 이다.<br />
따라서 *type* 변수와 타입 주석으로 명시한 `T` 는 *타입의 타입* 에 해당한다.

근데 타입스크립트 컴파일러는 *타입의 타입*을 허용하지 않기 때문에 아래와 같은 오류가 발생한다.
```ts
// TS2351: This expression is not constructable. 
// Type 'unknown' has no construct signatures.
const create = <T>(type: T): T => new type();
```

타입스크립트는 이를 해결하기 위해 *타입의 타입* 에 해당하는 구문을 만들기보다 C# 의 구문을 빌려서 아래와 같은 타입스크립트 구문을 만들었다.
```ts
const create = <T extends {new(): T}>(type: T): T => new type();
```

위 타입 제약 구문에서 중괄호 {} 로 new() 부분을 감싸서 new() 부분을 메서드 형태로 표현했는데 이를 아래처럼 중괄호를 없앤 간결한 문법으로 표현할 수 있다.
```ts
const create = <T>(type: new() => T): T => new type();
```

즉, `{new(): T}` 와 `new() => T` 는 같은 의미이다.

`new` 연산자를 *type* 에 적용하면서 *type* 의 생성자 쪽으로 매개변수를 전달해야 할때는 아래처럼 `new(...args)` 구문을 사용한다.

```ts
const create = <T>(type: {new(...args): T}, ...args):T => new type(...args);
```

아래는 *Point* 의 인스턴스를 `{new(...args): T}` 타입 제약을 설정한 *create* 함수로 생성하는 예시이다.
```ts
const create3 = <T>(type: {new(...args): T}, ...args):T => new type(...args);

class Point {
    constructor(public x: number, public y: number) { }
}

[
    create3(Date),  // 2021-10-01T07:57:56.458Z
    create3(Point, 0, 0)    // Point { x: 0, y: 0 }
].forEach((s) => console.log(s));
```

---

### 2.2. 인덱스 타입 제약

객체의 일정 속성들만 추려서 좀 더 단순한 객체를 만들어야 할 때가 있다.

아래 *pick* 함수는 4개의 속성을 가진 *obj* 객체에서 *name*, *age* 두 속성한 추출하여 간단한 객체를 만드려 한다.
```ts
const obj = {name: 'assu', age: 20, city: 'seoul', country: 'korea'};

const pick = (obj, keys) => keys.map(key => ({[key]: obj[key]}))
    .reduce((result, value) => ({...result, ...value}), {});

console.log(
    pick(obj, ['name', 'age']), // { name: 'assu', age: 20 }
    pick(obj, ['nam', 'agge'])  // { nam: undefined, agge: undefined }
)
```
두 번째처럼 만일 속성명에 오타가 발생하면 엉뚱한 결과가 나오게 되는데 타입스크립트는 이러한 상황을 방지할 목적으로 `keyof T` 형태로 타입 제약을 설정할 수 있게 지원한다.
이것을 **인덱스 타입 제약**이라고 한다.

```ts
<T, K extends keyof T>
```

아래 코드는 obj, keys 매개변수에 각각 `T,` `K` 라는 타입변수를 적용했지만 `K` 타입에 타입 제약을 설정하지 않았기 때문에 오류가 발생한다.
```ts
// TS2536: Type 'K' cannot be used to index type 'T'.
const pick = <T, K>(obj: T, keys: K[]) => keys.map(key => ({[key]: obj[key]}))
.reduce((result, value) => ({...result, ...value}), {});
```

이 오류를 해결하려면 타입 `K` 가 `T` 의 속성이름(키)이라는 것을 알려줘야 하는데 이 때 **인덱스 타입 제약**을 사용한다.

아래는 `keyof T` 구문으로 타입 `K` 가 타입 `T` 의 속성 이름이라고 타입 제약을 설정한 예시이다. 

```ts
const pick = <T, K extends keyof T>(obj: T, keys: K[]) =>
    keys.map(key => ({[key]: obj[key]}))
        .reduce((result, value) => ({...result, ...value}), {});
```

**이제 컴파일하지 않고도 속성명이 잘못된 경우 입력 오류를 코드 작성 시점에 탐지가 가능**하다.
```ts
console.log(
    pick(obj, ['name', 'age']), // { name: 'assu', age: 20 }
    pick(obj, ['nam', 'agge'])  // TS2322: Type '"agge"' is not assignable to type '"name" | "age" | "city" | "country"'.
```

---

## 3. 대수 데이터 타입 (ADT)

[Typescript 기본](https://assu10.github.io/dev/2021/09/11/typescript-basic/) 의 *2.5. 대수 타입 (ADT)* 에서 대수 타입에 대해 아주 간략이 소개한 바 있다.

객체지향 프로그래밍 언어에서 `ADT` 는 추상 데이터 타입을 의미하지만, 함수형 언어에서는 대수 데이터 타입 (algebraic data type) 을 의미한다.

대수 데이터 타입은 **합집합 타입 (union type)** 과 **교집합 타입 (intersection type)** 이 있다.


### 3.1. 합집합 타입 (`|`)

**합집합 타입**은 `|` 기호로 다양한 타입을 연결해서 만든 타입을 의미한다.

아래 *NumberOrString* 는 number or string 타입이므로 1, hello 등의 문자열을 모두 담을 수 있다.

```ts
type NumberOrString = number | string;

let ns: NumberOrString = 1;
ns = 'hello'
ns = true;  // TS2322: Type 'boolean' is not assignable to type 'NumberOrString'.
```

---

### 3.2. 교집합 타입 (`&`)

**교집합 타입**은 `&` 기호로 다양한 타입은 연결하여 만든 타입을 의미한다.<br />
교집합 타입의 대표적인 예를 2개의 객체를 통합하여 새로운 객체를 만드는 것이다.

아래는 타입 T 와 U 객체를 결합하여 타입이 T & U 인 새로운 객체를 만드는 예시이다.
```ts
// 타입 T 와 U 객체를 결합하여 타입이 T & U 인 새로운 객체를 만드는 예시
const mergeObjects = <T, U>(a: T, b: U): T & U => ({...a, ...b});

type INameable = {name: string};
type IAgeable = {age: number};

const nameAndAge: INameable & IAgeable = mergeObjects({name: 'assu'}, {age: 20});

console.log(nameAndAge);    // { name: 'assu', age: 20 }
```

---

### 3.3. 합집합 타입 구분하기

아래 3개의 인터페이스와 해당 인터페이스 타입으로 만든 3개의 객체가 있다.
```ts
interface ISquare {
    size: number
}
interface IRectangle {
    width: number,
    height: number
}
interface ICircle {
    radius: number
}

// 위 인터페이스 타입으로 만든 객체들
const square: ISquare = {size: 10};
const ractangle: IRectangle = {width: 4, height: 5};
const circle: ICircle = {radius: 10}
```

면적 계산을 하기 위한 매개변수 타입은 아래와 같다.
```ts
// 면적 계산을 하기 위한 매개변수의 타입
type IShape = ISquare | IRectangle | ICircle;
```

이제 면적을 계산하는 함수를 보자.
```ts
// 면적을 계산하는 함수
const calcArea = (shape: IShape): number => {
    // shape 객체가 ISquare 인지 IRectangle 인지 알 수가 없어서 면적을 계산할 수 없음

    return 0;
}
```

여기서 문제는 shape 객체가 구체적으로 어떤 타입의 객체인지 알 수가 없기 때문에 계산 로직을 작성할 수 없다.

타입스크립트는 이런 문제를 해결하기 위해 **합집합 타입의 각각을 구분**할 수 있게 하는 **식별 합집합 (discriminated unions)** 구문을 제공한다.

---

### 3.4. 식별 합집합 구문

**식별 합집합 구문**을 사용하려면 합집합 타입을 구성하는 인터페이스 모두 같은 이름의 속성이 있어야 한다.

아래는 식별가능한 공통 속성인 *tag* 를 넣어주었다.
```ts
interface ISquare {
    tag: 'square',
    size: number
}

interface IRectangle {
    tag: 'rectangle',
    width: number,
    height: number
}
interface ICircle {
    tag: 'circle',
    radius: number
}

// 위 인터페이스 타입으로 만든 객체들
const square: ISquare = {tag: 'square', size: 10};
const ractangle: IRectangle = {tag: 'rectangle', width: 4, height: 5};
const circle: ICircle = {tag: 'circle', radius: 10}
```

```ts
// 면적 계산을 하기 위한 매개변수의 타입
type IShape = ISquare | IRectangle | ICircle;

// 면적을 계산하는 함수
const calcArea = (shape: IShape): number => {
    switch (shape.tag) {
        case 'square':
            return shape.size * shape.size;
        case 'rectangle':
            return shape.width * shape.height;
        case 'circle':
            return Math.PI * shape.radius * shape.radius;
    }
    return 0;
}

console.log(
    calcArea(square),   // 100
    calcArea(ractangle),    // 20
    calcArea(circle)    // 314.1592653589793
)
```

---

## 4. 타입 가드

아래 코드의 *flyOrSwim* 를 보면 매개변수 o 는 Bird 이거나 Fish 인데 정확히 구체적으로 어떤 객체인지 알 수가 없다. 
```ts
class Bird {
    fly() {
        console.log('fly~')
    }
}
class Fish {
    swim() {
        console.log('swim~')
    }
}

// 함수
const flyOrSwim = (o: Bird | Fish): void => {
    // o.fly() ??
}
```

### 4.1. `instanceof` 연산자

자바스크립트에서 제공하는 `instanceof` 연산자를 사용하여 위 문제를 해결할 수 있다.
```ts
객체 instanceof 타입    // boolean 타입의 값 반
```

```ts
class Bird {
    fly() {
        console.log('fly~')
    }
}
class Fish {
    swim() {
        console.log('swim~')
    }
}

// 함수
const flyOrSwim = (o: Bird | Fish): void => {
    if (o instanceof Bird) {
        (o as Bird).fly();
    } else if (o instanceof Fish) {
        (<Fish>o).swim();
    }
}

[new Bird, new Fish].forEach(flyOrSwim);    // fly~ swim~
```
> 타입 단언 관련하여 [Typescript - 객체, 타입](https://assu10.github.io/dev/2021/09/14/typescript-object-type/) 의 *5.2. 타입 단언 (type assertion)* 을 함께 보면 도움이 됩니다.

---

### 4.2. 타입 가드 (type guard)

타입스크립트에서 `instanceof` 연산자는 자바스크립트와 다르게 **타입 가드 (type guard)**라는 기능이 있는데,<br />
**타입 가드**란 타입을 변환하지 않은 코드 때문에 프로그램이 비정상 종료되는 상황을 보호해준다는 의미이다.

아래 코드를 보자.
```ts
// 함수
const flyOrSwim = (o: Bird | Fish): void => {
    if (o instanceof Bird) {
        o.fly();
    } else if (o instanceof Fish) {
        o.swim();
    }
}
```

타입 단언으로 타입 전환을 하지 않았음에도 정상 동작하는 것을 확인할 수 있다.<br />
타입스트립트는 `instanceof` 연산자 행이 true 로 확인되면 변수 o 를 자동으로 Bird 혹은 Fish 타입 객체로 전환한다.

---

### 4.3. `is` 연산자를 활용한 사용자 정의 타입 가드 함수 제작

`instanceof` 연산자처럼 동작하는 함수를 직접 구현할 수도 있다. (=타입 가드 기능을 하는 함수를 직접 구현 가능)

타입 가드 기능을 하는 함수는 아래처럼 함수의 반환 타입 부분에 `is` 라는 연산자를 사용하여 만든다.

```ts
변수 is 타입
```

아래 함수는 반환 타입이 `o is Bird` 이므로 사용자 정의 타입 가드 함수이다.
```ts
// 함수
const isFlyable = (o: Bird | Fish): o is Bird => {
    return o instanceof Bird;
}
const isSwimmable = (o: Bird | Fish): o is Fish => {
    return o instanceof Fish;
}
```

```ts
const flyOrSwim = (o: Bird | Fish): void => {
    if (isFlyable(o)) {
        o.fly();
    } else if (isSwimmable(o)) {
        o.swim();
    }
}

[new Bird, new Fish].forEach(flyOrSwim);    // fly~  swim~
```

---

## 5. F-바운드 다형성

### 5.1. 프로젝트 구성

조금 복잡한 코드를 작성해야 하므로 별도의 node.js 프로젝트를 생성한다.
```shell
> npm init --y
> npm i -D typescript ts-node @types/node
> tsc --init
> mkdir -p src/test
> mkdir src/classes
> mkdir src/interfaces
```

tsconfig.json
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "esModuleInterop": true,
    "target": "ES2019",
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

---

### 5.2. `this` 타입과 `F-바운드` 다형성

타입스크립트에서 `this` 키워드는 타입으로도 사용된다.<br />
`this` 가 타입으로 사용되면 객체지향 언어에서 의미하는 다형성 효과가 나는데 일반적인 다형성과 구분하기 위해 **`this` 타입으로 인한 다형성을 'F-바운드 다형성 (F-bound polymorphism)'** 라고 한다.

---

#### 5.2.1. F-바운드 타입

**F-바운드 타입**은 자신을 구현하거나 상속하는 서브타입을 포함하는 타입을 말한다.

아래 IValueProvider<T> 타입은 특별히 자신을 상속하는 타입이 포함되어 있지 않은 일반 타입이다.

src/interfaces/IValueProvider.ts
```ts
// 특별히 자신을 상속하는 타입이 포함되어 있지 않은 일반 타입
export interface IValueProvider<T> {
    value(): T
}
```

add 메서드가 내가 아닌 나를 상속하는 타입을 반환하는 F-바운드 타입이다.
src/interfaces/IAddable.ts
```ts
// add 메서드가 내가 아닌 나를 상속하는 타입을 반환하는 F-바운드 타입
export interface IAddable<T> {
    add(value: T): this
}
```

메서드의 반환 타입이 this 이므로 F-바운드 타입이다.
src/interfaces/IAddable.ts
```ts
// 메서드의 반환 타입이 this 이므로 F-바운드 타입
export interface IMultiplyable<T> {
    multiply(value: T): this
}
```

src/interfaces/index.ts
```ts
import { IAddable } from "./IAddable";
import { IMultiplyable } from "./IMultiplyable";
import { IValueProvider } from "./IValueProvider";

export {IValueProvider, IAddable, IMultiplyable}
```

이제 이 3개의 인터페이스를 구현하는 *Calculator* 와 *StringComposer* 클래스를 구현해가면서 `this` 타입이 필요한 이유에 대해 알아보자.

---
#### 5.2.2. IValueProvider<T> 인터페이스의 구현

아래 Calculator 클래스는 F-바운드 타입이 아닌 일반 타입의 인터페이스인 IValueProvider<T> 를 구현하고 있다.
_value 속성을 private 로 만들어 Calculator 를 사용하는 코드에서 _value 속성이 아닌 value() 메서드로 접근할 수 있도록 설계되었다.

```ts
import {IValueProvider} from "../interfaces";

// F-바운드 타입이 아닌 일반 타입의 인터페이스 구현
// _value 속성을 private 로 만들어 Calculator 를 사용하는 코드에서 _value 속성이 아닌 value() 메서드로 접근할 수 있도록 설계
export class Calculator implements IValueProvider<number> {
    constructor(private _value: number = 0) { }
    value(): number {
        return this._value;
    }
}
```

같은 방식으로 StringComposer 클래스도 IValueProvider<T> 를 구현한다.
```ts
import {IValueProvider} from "../interfaces";

export class StringComposer implements IValueProvider<string> {
    constructor(private _value: string = '') { }
    value(): string {
        return this._value;
    }
}
```

---

#### 5.2.3. IAddable<T> 와 IMultiplyable<T> 인터페이스 구현

아래 Calculator 클래스는 IValueProvider<T> 외에 IAddable<T> 를 구현한다.<br />
add 메서드는 클래스의 this 를 반환하는데 이는 메서드의 체인 기능을 구현하기 위함이다.

```ts
export class Calculator implements IValueProvider<number>, IAddable<number> {
    constructor(private _value: number = 0) { }
    value(): number {
        return this._value;
    }

    // 클래스의 this 를 반환 (메서드 체인 기능을 구현하기 위함)
    add(value: number): this {
        this._value = this._value + value;
        return this;
    }
}
```

이제 같은 방법으로 IMultiplyable<T> 도 구현한다.
```ts
export class Calculator implements IValueProvider<number>, IAddable<number>, IMultiplyable<number> {
    constructor(private _value: number = 0) { }
    value(): number {
        return this._value;
    }

    // 클래스의 this 를 반환 (메서드 체인 기능을 구현하기 위함)
    add(value: number): this {
        this._value = this._value + value;
        return this;
    }

    multiply(value: number): this {
        this._value = this._value * value;
        return this;
    }
}
```

이제 Calculator 클래스를 테스트해보자.

src/test/Calculator-test.ts
```ts
import {Calculator} from "../classes/Calculator";

const value = (new Calculator(1))
                .add(2) // 2
                .add(3) // 6
                .multiply(4)  // 24
                .value()
console.log(value); // 24
```

위 코드에서 add(), multiply() 메서드는 this 를 반환하기 때문에 메서드 체인이 작성 가능하다.<br />
IValueProvider<T> 의 value() 는 메서드 체인을 위한 것이 아니라 private 로 지정된 속성인 _value 를 가져오는 것이 목적이므로 메서드 체인에서 가장 마지막에 호출해야 한다.

StringComposer 도 동일한 방식으로 구현 가능하다.

src/classes/StringComposer.ts
```ts
export class StringComposer implements IValueProvider<string>, IAddable<string>, IMultiplyable<number> {
    constructor(private _value: string = '') { }
    value(): string {
        return this._value;
    }
    add(value: string): this {
        this._value = this._value.concat(value);
        return this;
    }
    multiply(value: number): this {
        const val = this.value();
        for (let index=0; index < value; index++) {
            this.add(val);
        }
        return this;
    }
}
```

src/test/StringComposer-test.ts
```ts
import {StringComposer} from "../classes/StringComposer";

const value = new StringComposer('hello')
                .add(' ') // hello
                .add('world')   // hello world
                .multiply(3)    // hello worldhello worldhello world
                .value();
console.log(value);
```

*IAddable<T>* 의 *add* 메서드나 *IMultiplyable<T>* 의 *multiply* 메서드는 자신을 구현한 클래스에 따라 반환 타입이 *Calculator* 가 되기도 하고 *StringComposer* 가 되기도 한다.

즉, 반환 타입 `this` 는 어떤 때는 *Calculator* 가 되기도 하고 어떤 때는 *StringComposer* 되기도 하는데 이렇게 동작하는 방식을 **F-바운드 다형성** 이라고 한다.


---

## 6. nullable 타입과 프로그램 안전성

### 6.1. 프로젝트 구성

이번에도 구현 내용이 복잡하므로 새로 node.js 프로젝트를 생성한다.
```shell
> npm init --y
> npm i -D typescript ts-node @types/node
> tsc --init
> mkdir -p src/option
> mkdir src/test
```

tsconfig.json
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "esModuleInterop": true,
    "target": "ES2019",
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

---

### 6.2. nullable 타입

결론부터 말하면 `undefined 타입` + `null타입` 을 `nullable 타입` 이라고 한다.

자바스크립트와 타입스크립트는 변수가 초기화되지 않으면 `undefined` 라는 값을 기본으로 지정하는데, 이 `undefined` 와 `null` 은 사실상 같은 의미이다.

타입스크립트에서 undefined 값의 타입은 undefined 이고, null 값을 타입은 null 이다.
이 둘은 사실상 같은 것이기 때문에 서로 호환된다.

> tsconfig.json 의 strict: true 로 설정 시에는 호환 안됨

`undefined 타입` 과 `null타입` 을 `nullable 타입` 이라고 하며 아래처럼 표현이 가능하다.

```ts
type nullable = undefined | null
const nullable: nullable = undefined
```

이 `nullable 타입` 들은 프로그램이 동작할 때 프로그램을 비정상 종료시키는 주요 원인이 되기 때문에 자바스크립트와 타입스크립트는 
이를 방지하고자 **옵션 체이닝 연산자 (`?.`)** 와 **널 병합 연산자 (`??`)** 를 제공한다.

---

### 6.3. 옵션 체이닝 연산자 `?.`

변수가 선언만 되고 초기화되지 않으면 코드 작성시엔 문제가 없지만 런타임에 오류가 발생하면서 프로그램이 비정상 종료된다. (tsconfig.json 의 strict: true 시엔 프로그램 작성시에도 오류 발생)

이런 오류는 프로그램의 안정성을 해치는데 **옵션 체이닝 연산자** 와 **널 병합 연산자** 를 통해 이런 위험을 방지 가능하다.

자바스크립트는 물음표 기호와 점 기호를 연이어 쓰는 `?.` 연산자를 표준으로 채택했고, 타입스크립트도 버전 3.7.2 부터 이 연산자를 지원하였다.

```ts
interface IPerson {
    name: string,
    age?: number
}

let person: IPerson;
//console.log(person.name); // TS2454: Variable 'person' is used before being assigned.
console.log(person?.name);  // undefined
```

> 위 예시도 tsconfig.json 의 strict: true 시엔 둘 다 코드 작성 시에 오류 발생

**옵션 체이닝 연산자 `?.`** 는 세이프 네비게이션 연산자라고도 한다. 아래 코드를 보면 왜 그렇게 부르는지 알 수 있다.

```ts
type ICoodinates = {longitude: number}
type ILocation = {country: string, coords?: ICoodinates}
type IPerson = {name: string, location?: ILocation}

let person: IPerson = {name: 'assu'}

// 세이프 네비게이션(옵션 체이닝) 을 사용한 경우
let longitude = person?.location?.coords?.longitude;
console.log(longitude); // undefined

// 세이프 네비게이션(옵션 체이닝) 을 사용하지 않은 경우
if (person && person.location && person.location.coords) {
    longitude = person.location.coords.longitude
}
console.log(longitude); // undefined
```

> 위 예시는 tsconfig.json 의 strict: true 이어도 코드 작성, 런타임 시 오류가 발생하지 않음

---

### 6.4. null 병합 연산자 `??`

자바스크립트는 **옵션 체이닝 연산자 `?.`** 를 표준으로 채택하면서 동시에 물음표 기호 2개를 연달아 붙인 **널 병합 연산자 `??`** 도 표준으로 채택했다.
그리고 타입스크립트도 3.7.2 버전부터 지원하기 시작하였다.

```ts
type ICoodinates = {longitude: number}
type ILocation = {country: string, coords?: ICoodinates}
type IPerson = {name: string, location?: ILocation}

let person: IPerson = {name: 'assu'}
let longitude = person?.location?.coords?.longitude ?? 0;
console.log(longitude);     // undefined 가 아니라 0

let n: null = null
console.log(n??0)   // null 이 아니라 0
```

---

### 6.5. nullable 타입의 함수형 방식 구현

하스켈에는 `Maybe` 라는 타입이 있고, 스칼라는 `Mqybe` 타입의 이름을 `Option` 으로 바꿔서 제공한다.
스위프트나 코틀린, 러스트와 같은 언어들도 `Option` 혹은 `Optional` 이란 이름으로 이 타입을 제공한다.

타입스크립트 언어로 `Option` 타입을 구현해보도록 하자.

아래 Option 클래스는 스칼라에서 사용되는 방식으로 동작한다.

우선 아래 2개 인터페이스를 먼저 생성하자.

src/option/IValuable.ts
```ts
export interface IValuable<T> {
    getOrElse(defaultValue: T)
}
```

src/option/IFunctor.ts
```ts
export interface IFunctor<T> {
    map<U>(fn: (value: T) => U)
}
```

함수형 프로그래밍 언어에서 `map` 이라는 메서드가 있는 타입들을 **펑터 (functor)**라고 한다.
위 *IFunctor<T>* 는 타입스크립트 언어로 선언한 **펑터 인터페이스**이다.

---

#### 6.5.1. Some 클래스 구현

```ts
import {IValuable} from "./IValuable";
import {IFunctor} from "./IFunctor";

export class Some<T> implements IValuable<T>, IFunctor<T> {
    constructor(private value: T) { }
    // 클래스의 value 속성이 private 이므로 항상 getOrElse() 를 통해 value 를 얻어야 함
    getOrElse(defaultValue: T) {
        return this.value ?? defaultValue;
    }
    // 클래스의 value 속성이 private 이므로 value 값을 변경하려면 항상 map 메서드 사용
    // map<U>(fn: (value: T) => U) {    // 아래와 같은 의미
    map<U>(fn: (T) => U) {
        return new Some<U>(fn(this.value));
    }
}
```

위에서 *map* 메서드의 반환 타입이 `this` 가 아닌 이유(=T 가 아니라 U 인 이유) 는 *map* 메서드가 반환하는 타입이 Some<`T`> 가 아니라 Some<`U`> 이기 때문이다.

바로 뒤에 보겠지만 *None* 클래스의 경우 *map* 메서드는 None 을 반환한다.<br />
결론적으로 *map* 메서드의 반환 타입은 Some<`U`> | None 이어야겠지만 타입스크립트의 컴파일러는 반환타입을 명시하지 않으면 타입을 추론해서 반환타입을 찾아낸다.

---

#### 6.5.2. None 클래스 구현

*Some* 클래스와 다르게 *None* 의 *map* 메서드는 콜백 함수는 전혀 사용하지 않는다.
*None* 클래스는 nullable 타입의 값을 의미하기 때문에 nullable 값들이 map 의 콜백 함수에 동작하면 프로그램이 비정상 종료될 수 있다.

src/option/nullable.ts
```ts
export type nullable = undefined | null;
export const nullable: nullable = undefined;
```

```ts
import {IValuable} from "./IValuable";
import {nullable} from "./nullable";
import {IFunctor} from "./IFunctor";

export class None implements IValuable<nullable>, IFunctor<nullable> {
    getOrElse<T>(defaultValue: T | nullable) {
        return defaultValue;
    }
    //map<U>(fn: (value: nullable) => U) {  // 아래와 같은 의미
    map<U>(fn: (T) => U) {
        return new None;
    }
}
```

---

#### 6.5.3. Option 클래스 구현 및 사용

아래에서 생성자가 private 이므로 new 연산자로 Option 클래스의 인스터스 생성 불가하다. 
```ts
import {Some} from "./Some";
import {None} from "./None";

export class Option {
    // 생성자가 private 이므로 new 연산자로 Option 클래스의 인스터스 생성 불가
    private constructor() { }
    static Some<T>(value: T) {
        return new Some<T>(value);
    }
    static None = new None();
}
export {Some, None}
```

즉, Option 타입 객체는 Option.Some(값) 혹은 Option.None 형태로만 생성이 가능하다. 

```ts
import {Some} from "./Some";
import {None} from "./None";

export class Option {
    private constructor() { }
    static Some<T>(value: T) {
        return new Some<T>(value);
    }
    static None = new None();
}
export {Some, None}
```

*Option.Some* 정적 메서드는 Some 이라는 클래스의 인스턴스를 반환하고,<br /> 
*Option.None* 정적 속성은 None 이라는 클래스의 인스턴스이다.

보통 어떤 정상적인 값을 가지면 Option.Some(1), Option.Some('hello') 처럼 Some 에 값을 저장하고, undefined 나 null 같은 비정상적인 값들은 모두 None 타입으로 처리하는 경향이 있다.

이렇게 값을 미리 Some 과 None 으로 분리하면 옵션 체이닝 연산자가 널 병합 연자가 필요없다. 이제 왜 Some 과 None 으로 구분하는지 알아보자.

---

#### 6.5.4. Some 과 None 클래스 사용

src/test/Option-test.ts
```ts
import { Option } from '../option/Option'

let m = Option.Some(1);
let value = m.map(value => value + 1).getOrElse(1);
console.log(value);    // 2

let n = Option.None;
value = n.map(value => value + 1).getOrElse(0);
console.log(value);     // 1
```

위 코드를 보면 Some 타입에 설정된 값 1은 map 메서드를 통해 2로 바뀌었고, getOrElse 메서드에 의해 value 변수에 2가 저장된다.

반면  None 타입 변수 n 은 map 메서드를 사용할 수는 있지만 이 map 메서드의 구현 내용은 콜백 함수를 실행하지 않고 단순히 None 타입 객체만 반환하기 때문에 getOrElse(0) 메서드가 호출되어 전달받은 0 이 저장된다.

---

### 6.6. Option 타입과 예외 처리

Option 타입은 부수 효과가 있는 불순 함수를 순수 함수로 만드는 데 효과적이다.

자바스크립트의 *parseInt* 함수는 문자열을 숫자로 만들어주는데 문자열이 1이 아니라 hello 와 같으면 *NaN (Not a Number)* 로 값을 만든다.
어떤 값이 NaN 인지 여부는 자바스크립트가 제공하는 *isNaN* 함수를 사용하면 알 수 있다.

아래는 parseInt 의 반환값이 NaN 인지에 따라 Option.None 혹은 Option.Some 타입의 값을 반환한다.

```ts
import {IFunctor} from "./option/IFunctor";
import {IValuable} from "./option/IValuable";
import {Option} from './option/Option'

const parseNumber = (n: string): IFunctor<number> & IValuable<number> => {
    const value = parseInt(n);
    return isNaN(value) ? Option.None : Option.Some(value);
}
```

아래는 값이 정상 변환되면 map 메서드가 동작하여 4가 출력되고, 비정상이면 getOrElse(0) 이 동작해 0 이 리턴된다.
```ts
import {IFunctor} from "./option/IFunctor";
import {IValuable} from "./option/IValuable";
import {Option} from './option/Option'

const parseNumber = (n: string): IFunctor<number> & IValuable<number> => {
    const value = parseInt(n);
    return isNaN(value) ? Option.None : Option.Some(value);
}

let value = parseNumber('1')
        .map(value => value + 1)    // 2
        .map(value => value * 2)    // 4
        .getOrElse(0)
console.log(value);         // 4

value = parseNumber('hello')
    .map(value => value + 1)    // 콜백 함수 호출안됨
    .map(value => value * 2)    // 콜백 함수 호출안됨
    .getOrElse(0)
console.log(value);         // 0
```

아래는 JSON 포맷 문자열에 따라 예외를 발생시키는 부수 효과가 있는 불순 함수를 try/catch 문과 함께 Option 을 활용하여 순수 함수로 전환시킨 예시이다.
```ts
import {IFunctor} from "./option/IFunctor";
import {IValuable} from "./option/IValuable";
import {Option} from './option/Option'

const parseJeon = <T>(json: string): IValuable<T> & IFunctor<T> => {
    try {
        const value = JSON.parse(json);
        return Option.Some<T>(value);
    } catch (e) {
        return Option.None;
    }
}

const json = JSON.stringify({name: 'assu', age: 20});
let value = parseJeon(json).getOrElse({});
console.log(value);  // { name: 'assu', age: 20 }

value = parseJeon('hello~~').getOrElse({});
console.log(value); // {}
```

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)
* [Ramda Documentation](https://ramdajs.com/docs/) (함수를 알파벳 순서로 분류)
* [Ramda Documentation-DevDocs](https://devdocs.io/ramda/) (함수를 기능 위주로 분류)