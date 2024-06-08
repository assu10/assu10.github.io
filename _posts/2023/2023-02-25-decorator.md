---
layout: post
title:  "Decorator"
date:   2023-02-25
categories: dev
tags: typescript decorator nestjs
---

이 포스트는 ECMAScript 기능인 Decorator 에 대해 알아본다.   

<!-- TOC -->
* [1. Decorator](#1-decorator)
  * [1.1. Decorator Factory](#11-decorator-factory)
  * [1.2. `PropertyDescriptor`](#12-propertydescriptor)
  * [1.3. Decorator 역할 요약](#13-decorator-역할-요약)
* [2. Decorator Composition (데커레이터 합성)](#2-decorator-composition-데커레이터-합성)
* [3. Class Decorator](#3-class-decorator)
  * [3.1. Class 재정의](#31-class-재정의)
  * [3.2. Class Decorator Factory](#32-class-decorator-factory)
* [4. Method Decorator](#4-method-decorator)
* [5. Accessor Decorator (접근자 데커레이터)](#5-accessor-decorator-접근자-데커레이터)
* [6. Property Decorator (속성 데커레이터)](#6-property-decorator-속성-데커레이터)
* [7. Parameter Decorator (매개변수 데커레이터)](#7-parameter-decorator-매개변수-데커레이터)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. Decorator

TypeScript 공식문서에서는 Decorator 를 아래와 같이 소개하고 있다.

> TypeScript 및 ES6에 클래스가 도입됨에 따라, 클래스 및 클래스 멤버에 어노테이션을 달거나 수정하기 위해 추가 기능이 필요한 특정 시나리오가 있습니다.  
> 데커레이터는 클래스 선언과 멤버에 어노테이션과 메타-프로그래밍 구문을 추가할 수 있는 방법을 제공합니다.  
> 
> 데커레이터는 JavaScript 에 대한 2단계 제안이며 TypeScript 의 실험적 기능으로 이용 가능합니다.
> 실험적인 기능이지만 매우 안정적이며 이미 수많은 프로젝트에서 사용중이다.

NestJS 는 Decorator 를 적극적으로 활용하며, Decorator 를 잘 활용하면 cross-cutting concern (횡단 관심사) 를 분리하여 관점 지향 프로그래밍을 적용할 수 있다.  
특히 typeORM 과 NestJS 에서 많이 사용하는 기능이다. 

TypeScript 의 Decorator 는 Java 의 Annotation 과 유사한 기능을 한다.  
Decorator 를 사용하면 애플리케이션이 허용하는 값으로 제대로 요청을 보냈는지에 대한 검사 등을 할 수 있다.

**Class, Method, Accessor, Property, Parameter 에 적용 가능**하며, 각 요소의 선언부 앞에 `@` 로 시작하는 Decorator 를 선언하면
Decorator 로 구현된 코드를 함께 실행한다.

> Class, Method, Accessor, Property, Parameter 에 따라 Decorator 가 전달받는 인자는 각각 다름

Decorator 를 사용하려면 tsconfig.json<sup id='tsconfig'>[참고](#_tsconfig)</sup> 의 `experimentalDecorators` 컴파일러 옵션을 `true` 로 활성화해야 하고,
ES5 이상이어야 한다.  
뒤에 나오는 내용이지만 Decorator Factory 생성 시 인자로 쓰이는 `PropertyDescriptor` 가 ES5 부터 생겨났기 때문이다.

> ES5 이전 버전에서는 `PropertyDescriptor` 를 타입으로 가진 변수는 undefined 가 뜸

tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES5",
    "experimentalDecorators": true
  }
}
```

Command Line
```shell
$ tsc --target ES5 --experimentalDecorators
```
> <span id='_tsconfig'>tsconfig.json 의 좀 더 상세한 내용은 [Typescript - 기본](https://assu10.github.io/dev/2021/09/11/typescript-basic/) 의 
> *4.1. tsconfig.json* 을 참고하세요.</span> [↩](#tsconfig)

Decorator Signature 는 아래와 같다.
```ts
declare type ClassDecorator = <TFunction extends Function>(target: TFunction) => TFunction | void;
declare type PropertyDecorator = (target: Object, propertyKey: string | symbol) => void;
declare type MethodDecorator = <T>(target: Object, propertyKey: string | symbol, descriptor: TypedPropertyDescriptor<T>) => TypedPropertyDescriptor<T> | void;
declare type ParameterDecorator = (target: Object, propertyKey: string | symbol, parameterIndex: number) => void;
```

Decorator 는 `@expression` 형식을 사용하며 여기서 expression 은 Decorating 된 선언에 대한 정보와 함께 런타임에 호출되는 함수이어야 한다.

```ts
function deco(
  target: any,
  propertyKey: string,
  descriptor: PropertyDescriptor,
) {
  console.log('Decorator 가 평가됨');
}

class TestClass {
  @deco
  test() {
    console.log('test 함수 호출');
  }
}

const t = new TestClass();
t.test();
```

```shell
Decorator 가 평가됨
test 함수 호출
```

---

## 1.1. Decorator Factory

Decorator 가 선언에 적용되는 방식을 바꾸고 싶다면 Decorator Factory 를 작성하면 된다. (= Decorator 에 인자를 넘겨서 Decorator 의 동작을 변경)  
`Decorator Factory` 는 **단순히 Decorator 가 런타임에 호출할 표현식을 반환하는 함수**이다.

```ts
// 데커레이터 팩토리
function Component(value: string) {
    console.log(value);

    // 데커레이터 함수
    // eslint-disable-next-line @typescript-eslint/ban-types
    return function (target: Function) {
        console.log(target);
        console.log(target.prototype);
    };
}

// 데커레이터 팩토리를 사용하면 값을 전달할 수 있습니다.
@Component('tabs')
class TabsComponent {}

// TabsComponent 객체 생성
const tabs = new TabsComponent();
```

eslint 를 쓰고 있다면 Decorator 생성 시 매개 변수 타입 단에서 아래와 같은 오류가 발생하는데 suppress 하여 사용하면 된다.
![eslint 사용 시 오류](/assets/img/dev/2023/0225/deco_01.png)


```ts
// 데커레이터 팩토리
function deco1(value: string) {
  console.log('Decorator 평가됨');
  // 데커레이터 함수
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    console.log(value);
  };
}

class TestClass1 {
  @deco1('Hello')
  test() {
    console.log('함수 호출됨');
  }
}

const t1 = new TestClass1();
t1.test();
```

```shell
Decorator 평가됨
Hello
함수 호출됨
```

---

## 1.2. `PropertyDescriptor`

Decorator Factory 생성 시 인자로 쓰이는 `PropertyDescriptor` 는 ES5 부터 생겼다.  

> 만일 스크립트 대상이 ES5 보다 낮으면 속성 설명자(`PropertyDescriptor` 를 타입으로 가진 변수)는 `undefined` 가 됨.

> PropertyDescriptor 은 ES5 부터 지원하는 [`Object.defineProperty()`](https://developer.mozilla.org/ko/docs/Web/JavaScript/Reference/Global_Objects/Object/defineProperty) 를 참고하세요.

`PropertyDescriptor` 의 인터페이스는 아래와 같은 모양이다.
```ts
interface PropertyDescriptor {
  configurable?: boolean;   // 속성의 정의를 수정할 수 있는지 여부
  enumerable?: boolean; // 열거형인지 여부
  value?: any;  // 속성값
  writable?: boolean;   // 수정 가능 여부
  get?(): any;  // getter
  set?(v: any): void;   // setter
}
```

---

## 1.3. Decorator 역할 요약

|     Decorator      | 역할              | 전달 인수                                   | 선언 불가능 위치                      |
|:------------------:|:----------------|:----------------------------------------|:-------------------------------|
|  Class Decorator   | 클래스의 정의를 읽거나 수정 | constructor                             | d.ts 파일, declare 클래스           |
|  Method Decorator  | 메서드의 정의를 읽거나 수정 | target, propertyKey, propertyDescriptor | d.ts 파일, declare 클래스, 오버로드 메서드 |
| Accessor Decorator | 접근자의 정의를 읽거나 수정 | target, propertyKey, propertyDescriptor | d.ts 파일, declare 클래스           |
| Property Decorator | 속성의 정의를 읽거나 수정  | target, propertyKey                     | d.ts 파일, declare 클래스           |
|     Parameter Decorator     | 매개변수의 정의를 읽음    | target, propertyKey, parameterIndex     | d.ts 파일, declare 클래스           |


---

# 2. Decorator Composition (데커레이터 합성)

Decorator 는 하나 이상 연결하여 사용할 수 있으며, 아래와 같은 흐름으로 진행된다.

- 각 Decorator 표현식은 위에서 아래 방향으로 평가됨
- 결과는 아래에서 위로 함수를 호출함

```ts
function first() {
  console.log('first(): factory evaluated');
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    console.log('first(): called');
  };
}

function second() {
  console.log('second(): factory evaluated');
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    console.log('second(): called');
  };
}

class ExampleClass {
  @first()
  @second()
  method() {}
}
```

```shell
first(): factory evaluated
second(): factory evaluated
second(): called
first(): called
```

---

# 3. Class Decorator

클래스의 생성자에 적용되어 **클래스 선언을 관찰, 수정, 대체**하는데 사용 가능하다.  
런타임에 함수로 호출되며, **Decorating 되는 클래스가 유일한 인자로 전달되어 호출**된다.  
선언 파일과 선언 클래스 내에서 사용할 수 없다.

> **선언 파일**  
> TypeScript 소스 코드를 컴파일할 때 생성되는 파일  
> 타입시스템의 타입 추론을 돕는 코드가 포함되어 있으며 확장자는 `d.ts` 임

```ts
// Component 데커레이터
// eslint-disable-next-line @typescript-eslint/ban-types
function Component(target: Function) {
  // 프로토타입 객체 참조
  const $ = target.prototype;

  // 프로토타입 객체 확장
  $.type = 'component111';
  $.version = '0.0.1';
}
// Component 데커레이터 사용
@Component
class TabsComponent {}

// TabsComponent 객체 인스턴스 생성
const tabs = new TabsComponent();

// 데커레이터로 설정된 프로토타입 확장은
// 타입 단언(Type Assertion) 필요
console.log((tabs as any).type); // 'component111' 출력
console.log((tabs as any).version); // '0.0.1' 출력
console.log((tabs as any).version2); // undefined 출력
```

```shell
component111
0.0.1
undefined
```


## 3.1. Class 재정의

Class Decorator 함수에 생성자 함수 제너릭을 사용한 후 새로운 클래스를 반환하면 생성자 함수 및 속성 등을 재정의할 수 있다.  
**Class Decorator 함수에서 재정의한 속성 및 메서드는 사용자 정의 속성 및 메서드보다 우선**한다.

아래는 클래스에 author 속성을 추가하고, open() 메서드를 재정의하는 Class Decorator 이다.

```ts
// 데커레이터 팩토리
function authorClassDecorator<T extends { new (...args: any[]): {} }>(constructor: T) {     // 1
  // 데커레이터 함수
  return class extends constructor {  // 2
    // 속성
    author = 'assu';    // 3
    // 메서드
    open() {
      console.log('decorator open()');
    }
  };
}

@authorClassDecorator
class TestClass {
  type = 'testType';
  title: string;
  constructor(title: string) {
    this.title = title;
  }
  open() {
    console.log('사용자 정의 open()');
  }

  close() {
    console.log('사용자 정의 close()');
  }
}

const tc = new TestClass('제목');

console.log(tc);
console.log(tc.type);
//console.log(tc.author); // 오류
console.log((tc as any).author);
console.log('---1', tc.open());
```

```shell
TestClass { type: 'testType', title: '제목', author: 'assu' }
testType
assu
decorator open()
---1 undefined
사용자 정의 close()
---2 undefined

```

위 코드의 각 설명은 아래와 같다.

1. `new (...args: any[]): {}` 즉, new 키워드와 함께 어떠한 형식의 인수들도 받을 수 있는 생성자 타입을 상속받은 제네릭 타입 T 를 가지는 생성자(`constructor`) 를
Factory 메서드의 인수로 전달함
2. Class Decorator 는 생성자를 리턴하는 함수이어야 함
3. Class Decorator 가 적용되는 클래스에 author 라는 새로운 속성 추가

> 클래스의 타입이 변경되는 것은 아님  
> 타입 시스템은 author 를 인식하지 못하기 때문에 tc.author 와 같이 직접 사용하지 못하고 `(tc as any).author` 와 같이 타입 단언 필요

---

## 3.2. Class Decorator Factory

사용자로부터 **옵션 객체를 전달 받으려면 Decorator Factory 를 사용**해야 한다.  
Decorator 함수를 반환하는 래퍼 함수를 만들어서 사용자로부터 옵션을 전달받을 수 있다.

```ts
// ClassType 타입 Alias 정의
type AuthorClassType = {
    title: string;
};

// 데커레이터 팩토리
function AuthorClassDecorator(options: AuthorClassType) {
    const _title = options.title;
    // 데커레이터 함수
    return function authorClassDecorator<T extends new (...args: any[]) => {}>(
        constructor: T,
    ) {
        return class extends constructor {
            title = `decorator 재정의값 ${_title}`;
        };
    };
}

@AuthorClassDecorator({ title: '테스트' })
class TestClass {}

// TestClass 객체 인스턴스 생성
const tc = new TestClass();
console.log(tc);
console.log((tc as any).title);
console.log((tc as any)._title);
```

```shell
TestClass { title: 'decorator 재정의값 테스트' }
decorator 재정의값 테스트
undefined

```

---

# 4. Method Decorator

Method Decorator 는 **메서드 선언 직전에 선언**된다.  
메서드의 속성 설명자 (Property Descriptor) 에 적용되며, **메서드 정의를 읽거나 수정**할 수 있다.  
선언 파일, 오버로드 메서드, 기타 주변 컨텍스트(e.g. 선언 클래스) 에 사용할 수 없다.  
Method Decorator 가 값을 반환한다면 이는 해당 메서드의 PropertyDescriptor 가 된다.

Method Decorator 의 표현식은 런타임에 아래 3개의 인수와 함께 함수로 호출된다.

- **target: `any`**
  - 정적 멤버가 속한 클래스의 생성자 함수이거나 인스턴스 멤버에 대한 클래스의 프로토타입
  - 즉, static 메서드면 클래스 생성자(Function), 인스턴스 메서드면 클래스의 프로토타입 객체(Object)
- **prop: `string`**
  - 멤버의 이름 (=메서드명)
- **descriptor: `PropertyDescriptor`**
  - 멤버의 속성 설명자
  - 만일 스크립트 대상이 ES5 보다 낮으면 속성 설명자(`PropertyDescriptor` 를 타입으로 가진 변수)는 `undefined` 가 됨.

Method Decorator 사용법
```ts
// 데커레이터 팩토리
function enumerable(value: boolean) {
  // 데커레이터 함수
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    descriptor.enumerable = value;
  };
}

class Greeter {
  greeting: string;
  constructor(message: string) {
    this.greeting = message;
  }

  @enumerable(false)
  greet() {
    return 'Hello, ' + this.greeting;
  }
}

const t = new Greeter('assu');
console.log(t.greet()); // Hello, assu
```

아래는 Method Decorator 를 사용하여 함수 실행 과정에서 에러가 발생했을 때 에러를 catch 하여 처리하는 예시이다.
```ts
function HandlerError() {
  return (target: any, propertyKey: string, descriptor: PropertyDescriptor) => { // 1
    console.log('target: ', target); // 2
    console.log(`propertyKey: ${propertyKey}`); // 3
    console.log(`descriptor: `, descriptor); // 4

    const method = descriptor.value; // 5

    descriptor.value = function () {
      try {
        method(); // 6
      } catch (e) {
        // 에러 핸들링 로직 구현 // 7
        console.log('Method decorator', e); // 8
      }
    };
  };
}

class Greeter {
  @HandlerError()
  hello() {
    throw new Error('테스트 에러');
  }
}

const t = new Greeter();
t.hello();
```

1. Method Decorator 가 가져야 하는 3개의 인수
2. 출력 결과는 _target:  {}_
3. 출력 결과는 _propertyKey: hello_ (=함수명)
4. hello 함수가 처음 가지고 있던 설명자가 출력됨
출력 결과는 _{ value: [Function: hello], writable: true, enumerable: false, configurable: true }_
5. 설명자의 value 속성으로 원래 정의된 메서드를 따로 저장함
6. 원래 메서드를 호출함
7. 원래 메서드를 수행하는 과정에서 발생한 에러를 핸들링하는 로직을 구현함
8. _Method decorator Error: 테스트 에러_ 가 출력됨

```shell
target:  {}
propertyKey: hello
descriptor:  {
  value: [Function: hello],
  writable: true,
  enumerable: false,
  configurable: true
}
Method decorator Error: 테스트 에러
    at hello (/Users/-/Developer/05_nestjs/me/ch02/src/main.ts:252:11)
    at Greeter.descriptor.value (/Users/-/Developer/05_nestjs/me/ch02/src/main.ts:240:9)
    at Object.<anonymous> (/Users/-/Developer/05_nestjs/me/ch02/src/main.ts:257:3)
    at Module._compile (node:internal/modules/cjs/loader:1254:14)
    at Object.Module._extensions..js (node:internal/modules/cjs/loader:1308:10)
    at Module.load (node:internal/modules/cjs/loader:1117:32)
    at Function.Module._load (node:internal/modules/cjs/loader:958:12)
    at Function.executeUserEntryPoint [as runMain] (node:internal/modules/run_main:81:12)
    at node:internal/main/run_main_module:23:47
```

---

# 5. Accessor Decorator (접근자 데커레이터)

Accessor Decorator 는 **접근자(getter, setter) 선언 직전에 선언**된다.   
접근자의 속성 설명자에 적용되며, **접근자의 정의를 읽거나 수정**할 수 있다.  
선언 파일, 기타 주변 컨텍스트(e.g. 선언 클래스) 에 사용할 수 없다.    
Method Decorator 가 값을 반환한다면 이는 해당 멤버의 PropertyDescriptor 가 된다.

Accessor Decorator 의 표현식은 런타임에 아래 3개의 인수와 함께 함수로 호출된다. (=Method Decorator 와 같은 시그니처)

- **target: `any`**
  - 정적 멤버가 속한 클래스의 생성자 함수이거나 인스턴스 멤버에 대한 클래스의 프로토타입
  - 즉, static 메서드면 클래스 생성자(Function), 인스턴스 메서드면 클래스의 프로토타입 객체(Object)
- **prop: `string`**
  - 멤버의 이름 (=메서드명)
- **descriptor: `PropertyDescriptor`**
  - 멤버의 속성 설명자
  - 만일 스크립트 대상이 ES5 보다 낮으면 속성 설명자(`PropertyDescriptor` 를 타입으로 가진 변수)는 `undefined` 가 됨.

getter 와 setter 에 적용할 수 있으며, 하나의 데커레이터를 getter 와 setter 에 동시에 적용할 수 없다.

> TypeScript disallows decorating both the get and set accessor for a single member.  
> Instead, all decorators for the member must be applied to the first accessor specified in document order.  
> This is because decorators apply to a Property Descriptor, which combines both the get and set accessor, not each declaration separately.  
> 
> [Accessor Decorators](https://www.typescriptlang.org/docs/handbook/decorators.html#accessor-decorators)

데커레이터에 인자로 들어오는 PropertyDescriptors 는 getter, setter 둘 다 포함하고 있지만 각각의 접근자에 대한 PropertyDescriptors 는 없기 때문이라고 한다.  
따라서 코드 순서상 먼저 오는 접근자에 한해서만 적용된다.

아래는 특정 멤버가 열거가 가능한지 결정하는 데커레이터 예이다.
```ts
// 데커레이터 팩토리
function Enumerable(value: boolean) {
  // 데커레이터 함수
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    console.log('target: ', target);
    console.log('propertyKey: ', propertyKey);
    console.log('descriptor: ', descriptor);

    descriptor.enumerable = value; // 1
  };
}

class Person {
  constructor(private name: string) {} // 2
  @Enumerable(true) //  3
  get getName() {
    return this.name;
  }
  @Enumerable(false)    // 4
  set setName(name: string) {
    this.name = name;
  }
}

const person = new Person('assu');
for (const key in person) {
  console.log(`for ${key} : ${person[key]}`); // 5
}
```

1. 설명자의 enumerable 속성을 데커레이터 인수로 결정함
2. name 은 외부에서 접근하지 못하는 private 멤버
3. getter 함수는 열거가 가능하도록 함
4. setter 함수는 열거가 불가능하도록 함
5. 결과 출력 시 getName 은 출력되지만 setName 은 열거가 불가능하므로 key 로 받을 수 없음

```shell
target:  {}
propertyKey:  getName
descriptor:  {
  get: [Function: get getName],
  set: undefined,
  enumerable: false,
  configurable: true
}
target:  { getName: [Getter] }
propertyKey:  setName
descriptor:  {
  get: undefined,
  set: [Function: set setName],
  enumerable: false,
  configurable: true
}
for name : assu
for getName : assu
for setName : undefined // setName 의 @Enumerable(true) 로 설정 시 출력

```

---

# 6. Property Decorator (속성 데커레이터)

Property Decorator 는 **클래스의 속성 선언 직전에 선언**된다.   
**속성 선언의 정의를 읽거나 수정**할 수 있다.  
선언 파일, 기타 주변 컨텍스트(e.g. 선언 클래스) 에 사용할 수 없다.  
반환값은 무시되지만 데커레이터가 PropertyDescriptor 형식의 객체를 반환하는 형식으로 사용 가능하다. (바로 아래 설명 나옴)

Property Decorator 의 표현식은 런타임에 아래 2개의 인수와 함께 함수로 호출된다.

- **target: `any`**
  - 정적 멤버가 속한 클래스의 생성자 함수이거나 인스턴스 멤버에 대한 클래스의 프로토타입
  - 즉, static 메서드면 클래스 생성자(Function), 인스턴스 메서드면 클래스의 프로토타입 객체(Object)
- **prop: `string`**
  - 멤버의 이름 (= 속성명)

Method Decorator 나 Accessor Decorator 와 비교해볼 때 세 번째 인수는 PropertyDescriptor 가 없다.  
공식 문서에서는 아래와 같이 설명하고 있다.

> A Property Descriptor is not provided as an argument to a property decorator due to how property decorators are initialized in TypeScript.   
> This is because there is currently no mechanism to describe an instance property when defining members of a prototype,   
> and no way to observe or modify the initializer for a property.  
> The return value is ignored too.  
> As such, a property decorator can only be used to observe that a property of a specific name has been declared for a class.
> 
> [Property Decorators](https://www.typescriptlang.org/docs/handbook/decorators.html#property-decorators)

공식 문서에 따르면 반환값도 무시된다고 하는데 이는 현재 프로토타입의 멤버를 정의할 때 인스턴스 속성을 설명하는 메커니즘이 없고 속성의 초기화 과정을 관찰하거나 수정할 방법이 없기 
때문이라고 한다.

> 하지만 데커레이터가 PropertyDescriptor 형식의 객체를 반환하면 실제로는 잘 동작(= 속성 설정 변경 가능)한다. 이 부분은 TypeScript 의 동작 원리와 상관이 있는데 이 이슈에 대한 논의는
> [Property decorator documentation is inaccurate?](https://github.com/microsoft/TypeScript/issues/32395) 를 참고하세요. 

아래는 속성에 대한 메타데이터를 기록하는 예시이다.
```ts
import 'reflect-metadata';
const formatMetadataKey = Symbol('format1');

// 데커레이터 팩토리
function format(formatString: string) {
  // 데커레이터 함수
  return Reflect.metadata(formatMetadataKey, formatString);
}

function getFormat(target: any, propertyKey: string) {
  return Reflect.getMetadata(formatMetadataKey, target, propertyKey);
}

class Greeter {
  @format('Hello, %s')
  greeting: string;

  @format('Hello2, %s')
  greeting2: string;
  constructor(message: string, message2: string) {
    this.greeting = message;
    this.greeting2 = message2;
  }
  greet() {
    const formatString = getFormat(this, 'greeting');
    const formatString2 = getFormat(this, 'greeting2');
    console.log('formatString: ', formatString); // 멤버변수인 greeting 의 format 인 Hello, %s 출력
    console.log('formatString2: ', formatString2); // 멤버변수인 greeting 의 format 인 Hello, %s 출력
    return formatString.replace('%s', this.greeting);
  }
}

const t = new Greeter('assu!');
console.log(t.greet());
```

_@format('hello, %s)_ 가 호출되면 `reflect-metadata` 라이브러리의 `Reflect.metadata` 함수를 사용하여 속성에 대한 메타데이터 항목을 추가한다.  
위 예제에선 _format1_ 메타데이터 항목에 formatString 즉, _Hello, %s_ 값을 추가한다.  
이 후 getFormat() 함수를 이용하여 _format1_ 메타데이터 항목의 값을 읽어서 출력한다.

```shell
formatString:  Hello, %s
formatString2:  Hello2, %s
Hello, assu!
```

> reflect-metadata 라이브러리는 [메타데이터 (Metadata)](https://www.typescriptlang.org/ko/docs/handbook/decorators.html#%EB%A9%94%ED%83%80%EB%8D%B0%EC%9D%B4%ED%84%B0-metadata)
> 를 참고하세요.  
> reflect-metadata 라이브러를 사용하려면 tsconfig.json 의 emitDecoratorMetadata 옵션을 활성화 해야 한다.  
> 참고로 reflect-metadata 도 ES5 이후로 실험적으로 제공하는 API 라 차후 변동이 생길 수 있다.

```ts
// 데커레이터 팩토리
function format(formatString: string) {
  // 데커레이터 함수
  return function (target: any, propertyKey: string): any {
    console.log('propertyKey: ', propertyKey);
    console.log('target: ', target);
    console.log('target[propertyKey]: ', target[propertyKey]);
    let value = target[propertyKey];

    function getter() {
      return `${formatString} ${value}`; // 1
    }

    function setter(newVal: string) {
      value = newVal;
    }

    return {
      get: getter,
      set: setter,
      enumerable: true,
      configurable: true,
    };
  };
}

class Greeter {
  @format('hello~') // 2
  greeting: string;
}

const t = new Greeter();
t.greeting = 'assu';
console.log(t.greeting); // 3
```

1. getter 에서 인수로 들어온 formatString 을 원래 속성과 조합한 스트링으로 변경
2. 데커레이커에 formatString 전달
3. 속성을 읽을 때 getter 가 호출되면서 변경된 스트링이 출력

```shell
propertyKey:  greeting
target:  {}
target[propertyKey]:  undefined
hello~ assu
```

---

# 7. Parameter Decorator (매개변수 데커레이터)

> [NestJS - Custom Parameter Decorator](https://assu10.github.io/dev/2023/04/22/nest-custom-parameter-decorator) 와 함께 보면 도움이 됩니다.

Parameter Decorator 는 **클래스의 생성자 함수 또는 메서드의 매개변수 선언 직전에 선언**된다.   
선언 파일, 기타 주변 컨텍스트(e.g. 선언 클래스) 에 사용할 수 없다.  
반환값은 무시된다.

Property Decorator 의 표현식은 런타임에 아래 2개의 인수와 함께 함수로 호출된다.

- **target: `any`**
  - 정적 멤버가 속한 클래스의 생성자 함수이거나 인스턴스 멤버에 대한 클래스의 프로토타입
  - 즉, static 메서드면 클래스 생성자(Function), 인스턴스 메서드면 클래스의 프로토타입 객체(Object)
- **propertyKey: `string`**
  - 멤버의 이름 (= 메서드명)
- **parameterIndex: `number`**
  - 매개변수가 함수에서 몇 번째 위치에 선언되었는지를 나타내는 인덱스

아래는 매개변수가 제대로 된 값으로 전달되었는지 검사하는 데커레이터의 예시이다.  
NestJS 에서 API 요청 매개변수에 대한 유효성 검사를 할 때 아래와 유사한 데커레이터를 많이 사용한다.
Parameter Decorator 는 단독으로 사용되기 보다는 Method Decorator 와 함께 사용할 때 좀 더 유용하다.

```ts
import { BadRequestException } from '@nestjs/common';

// 데커레이터 팩토리
function MinLength(min: number) { // 1
  // 데커레이터 함수
  return function (target: any, propertyKey: string, parameterIndex: number) {
    console.log('target: ', target);
    console.log('propertyKey: ', propertyKey);
    console.log('parameterIndex: ', parameterIndex);

    target.validators2 = { // 2
      minLength: function (args: string[]) { // 3
        return args[parameterIndex].length >= min; // 4
      },
    };
  };
}

// 메서드 데커레이터
function Validate(target: any, propertyKey: string, descriptor: PropertyDescriptor) {   // 5
  console.log('target: ', target);
  console.log('propertyKey: ', propertyKey);
  console.log('descriptor: ', descriptor);

  const method = descriptor.value; // 6
  console.log('method: ', method);

  descriptor.value = function (...args) {// 7
    console.log('descriptor.value ...args: ', ...args);
    console.log('target.validators2: ', target.validators2);
    
    Object.keys(target.validators2).forEach(key => { // 8
      console.log('target.validators2[key]: ', target.validators2[key]);
      console.log('target.validators2[key](args): ', target.validators2[key](args));
      
      if (!target.validators2[key](args)) { // 9
        throw new BadRequestException();
      }
    });
    console.log('Validator args: ', args);
    method.apply(this, args); // 10
  };
}

class User {
  private name: string;

  @Validate
  setName(@MinLength(3) name: string) {
    this.name = name;
  }
}

const t = new User();
t.setName('assu'); // 11
//t.setName('as'); // 12 오류
```

```shell
target:  {}
propertyKey:  setName
parameterIndex:  0
target:  { validators2: { minLength: [Function: minLength] } }
propertyKey:  setName
descriptor:  {
  value: [Function: setName],
  writable: true,
  enumerable: false,
  configurable: true
}
method:  [Function: setName]
descriptor.value ...args:  assu
target.validators2:  { minLength: [Function: minLength] }
target.validators2[key]:  [Function: minLength]
target.validators2[key](args):  true
Validator args:  [ 'assu' ]
```

1. 매개변수의 최소값을 검사하는 Parameter Decorator
2. target 클래스 (User) 의 validator 속성에 유효성을 검사하는 함수 할당
3. args 인수는 9 에서 넘겨받은 인수
4. 유효성 검사를 위한 로직으로 parameterIndex 에 위치한 인수의 길이가 최소값보다 같거나 큰 지 확인
5. 함께 사용할 Method Decorator
6. Method Decorator 가 선언된 메서드를 method 변수에 임시 저장
7. PropertyDescriptor 의 value 에 유효성 검사 로직이 추가된 함수 할당
8. target 클래스 (User) 에 저장해둔 validators2 를 모두 수행함, 이 때 원래 메서드에 전달된 인수들(args)을 각 validators 에 전달
9. 인수를 validators2 에 전달하여 유효성 검사 수행
10. 원래의 함수 실행
11. 매개변수 name 의 길이가 4 이므로 정상 수행
12. 매개변수 name 의 길이가 3보다 작으므로 BadRequestException 발생

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [TypeScript Guidebook - 데커레이터](https://yamoo9.gitbook.io/typescript/decorator)
* [TypeScript 공홈 - Decorators](https://www.typescriptlang.org/ko/docs/handbook/decorators.html)
* [Typescript 공식 Github](https://typescript-kr.github.io/pages/decorators.html)
* [proposal-decorators Github](https://github.com/tc39/proposal-decorators#decorators)
* [Decorator에 관하여](https://codebibimppap.tistory.com/15)
* [Typescript - 기본 (tsconfig.json)](https://assu10.github.io/dev/2021/09/11/typescript-basic/)
* [Object.defineProperty() - PropertyDescriptor 참고](https://developer.mozilla.org/ko/docs/Web/JavaScript/Reference/Global_Objects/Object/defineProperty)
* [Property decorator documentation is inaccurate?](https://github.com/microsoft/TypeScript/issues/32395)
* [reflect-metadata](https://www.typescriptlang.org/ko/docs/handbook/decorators.html#%EB%A9%94%ED%83%80%EB%8D%B0%EC%9D%B4%ED%84%B0-metadata)
* [TypeScript Decorator 직접 만들어보자](https://dparkjm.com/typescript-decorators)
* [NestJS - Custom Parameter Decorator: Blog](https://assu10.github.io/dev/2023/04/22/nest-custom-parameter-decorator)

* [ts-aspect - TypeScript 에서의 AOP](https://github.com/engelmi/ts-aspect)
* [AspectTS - TypeScript 에서의 AOP](https://github.com/dboikliev/AspecTS/blob/master/src/aspect.ts)