---
layout: post
title:  "Typescript - 기본"
date:   2021-09-11 10:00
categories: dev
tags: typescript
categories: dev
---

이 포스팅은 타입스크립트 기본에 대해 알아본다.

> 소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.

>- 타입스크립트
>- 타입스크립트 문법
>   - 타입 주석과 타입 추론
>   - 인터페이스
>   - 튜플
>   - 제네릭 타입
>   - 대수 타입 (ADT)
>- 타입스크립트 셋팅
   >   - 타입스크립트 설치
>- 타입스크립트 프로젝트 생성
   >   - tsconfig.json
   >   - 프로젝트 구조 생성
   >   - 모듈 (export, import)

---

## 1. 타입스크립트

자바스크립트는 크게 세 가지로 나누어진다.

- ES5(ECMAScript 5)
    - 표준 자바스크립트
- ESNext 자바스크립트
    - 2015년부터 매년 배로운 버전을 발표
- Typescript
    - ESNext 에 새로운 기능을 추가

<br />
<details markdown="1">
<summary>ESNext 자바스크립트 (Click!)</summary>

자바스크립트 공식 표준은 ECMAScript (ES) 인데 2015년도에 발표된 ES6 버전에서 큰 변화가 있었다.<br />
그래서 ES6 이후 버전을 통틀어 ESNext 라고 한다.<br />
</details>

<br /><br />
타입스크립스는 변수의 타입을 명확히 지정해줌으로써 타입스크립트 컴파일러가 오류의 원인을 정확히 알려주므로 코드를 좀 더 수월하게 작성할 수 있다.

`ESNext` 자바스크립트 코드는 `Babel` 이라는 트랜스파일러를 기치면 ES5 자바스크립트 코드로 변환된다.<br />
`Babel` 과 유사하게 타입스크립트 코드는 `TSC(TypeScript Compiler)` 라는 트랜스파일러는 통해 ES5 자바스크립트 코드로 변환된다.

---

## 2. 타입스크립트 문법

### 2.1. 타입 주석과 타입 추론

```typescript
let a: number = 1
let b = 2
```
a 뒤의 콜론 `:` 과 타입 이름이 있는데 이를 `타입 주석`이라고 한다.

b 의 경우 타입 부분이 생략되었는데 이런 경우 대입연산자인 = 뒤의 값을 분석 하여 변수의 타입을 결정하는데 이것을 `타입 추론` 이라고 한다.<br />
타입 추론이 있기 때문에 자바스크립트로 작성된 .js 파일을 확장자만 .ts 로 바꿔도 타입스크립트 환경에서 바로 동작이 가능하다.

---

### 2.2. 인터페이스

```typescript
interface Person {
    name: string
    age?: number
}

let person: Person = { name: 'assu' }
```
---

### 2.3. 튜플

튜플은 물리적으론 배열과 같지만 배열은 모두 같은 타입의 데이터를 저장하는 한편 튜플은 다른 타입의 데이터를 저장한다.

```typescript
let a: number[ ] = [1, 2, 3]       //  배열
let b: [boolean, number, string] = [true, 1, 'assu']    // 튜플
```

---

### 2.4. 제네릭 타입

제레릭 타입은 다양한 타입을 한꺼번에 취급한다.

```typescript
class Container<T> {
  constructor(public value: T) {  }
}
let numberContainer: Container<number> = new Container<number>(1)
let stringContainer: Container<string> = new Container<string>('hello')
```

---

### 2.5. 대수 타입 (ADT)

`ADT` 는 추상 데이터 타입을 의미하기도 하지만 대수 타입 (algebraic data type) 의 의미로도 사용된다.

대수 타입은 다른 자료형의 값을 갖는 자료형을 의미한다.<br />
대수 타입은 합집합과 교집합 타입이 있는데 합집합 타입은 `|` 으로, 교집합 타입은 `&` 을 사용하여 만들 수 있다.

```typescript
type NumberOrString = number | string   // 합집합
type AnimalAndPerson = Animal & Person  // 교집합
```

---

## 3. 타입스크립트 셋팅

### 3.1. 타입스크립트 설치

```shell
> npm i -g typescript
> tsc --version

> tsc hello.ts
```

위에서 `tsc hello.ts` 실행 시 타입스크립트 소스가 TSC 에 의해 트랜스파일이 되어 hello.js 파일이 생성된다.<br />
생성된 hello.js 파일을 노드로 실행할 수 있다.
```shell
> node hello.js
```

tsc 는 타입스크립트 코드를 ES5 자바스크립트 코드로 변환할 할 뿐 실행하지는 않는다.<br />
타입스크립트 코드를 ES5 로 변환하고 실행까지 동시에 하려면 `ts-node` 를 설치해야 한다.

```shell
> npm i -g ts-node
> ts-node -v

> ts-node hello.ts
```

---

## 4. 타입스크립트 프로젝트 생성

타입스크립트로 개발은 node.js 프로젝트를 만든 후 개발 언어를 타입스크립트로 설정하는 방식으로 진행된다.
따라서 node.js 프로젝트를 먼저 생성해야 한다.

```shell
# 프로젝트 폴더로 이동
> npm init --y
```

> `npm init` 시 여러 응답에 답을 하는 절차가 있는데 `--y` 옵션을 붙이면 이러한 절차를 건너뛰고 기본 package.json 파일을 생성한다.

해당 프로젝트를 전달받아 사용하는 개발자를 위해 package.json 에도 기록한다.

```shell
> npm i -D typescript ts-node
```

타입스크립트는 ESNext 자바스크립트 문법을 포함하고는 있지만 자바스크립트와는 완전히 다른 언어이다.<br />
따라서 예를 들어 자바스크립트로 개발된 chance 같은 라이브러리들은 추가로 `@types/chance` 와 같은 라이브러리들을 제공해야 한다.

타입스크립트는 웹브라우저나 node.js 에서 기본적으로 제공하는 타입들도 인식을 못하기 때문에 Promise 와 같은 타입을 사용하려면 `@types/node` 라는 패키지를 설치해야 한다.

```shell
> npm i -D @types/node
```

### 4.1. tsconfig.json

타입스크립트 프로젝트는 타입스크립트 컴파일러 설정 파일인 `tsconfig.json` 파일이 있어야 하는데 아래 명령어를 통해 기본 포맷을 생성할 수 있다.

```shell
> tsc --init
> tsc --help
```

생성된 `tsconfig.json` 에서 필요한 옵션만 활성화하여 사용한다.

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "esModuleInterop": true,
    "target": "es2015",
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

- **include, exclude**
  - 컴파일 할 때 포함할 파일명의 배열이나 패턴을 명시
  - 패턴은 [glob pattern](https://en.wikipedia.org/wiki/Glob_(programming)) 을 사용
  - 파일명의 패스는 tsconfig.json 이 있는 곳으로부터 상대 경로로 표시
  - include 의 디폴트 값은 `[**/*]`
  - exclude 의 디폴트 값은 `["node_modules", "bower_components", "jspm_packages"]`
  - `include: [src/**/*]` : src 디렉터리와 src 하위 디렉터리에 있는 모든 파일을 컴파일 대상으로 포함
  - exclude 는 include 와 함께 동작하면서 include 될 것은 exclude 하는 것
  
```json
{
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["tests/modules/*"]
}
```

- **files**
  - include 시킬 파일들을 개별적으로 포함
  - 보통 `include` 로도 해결이 되므로 잘 사용하지는 않음
```json
{
  "compilerOptions": {},
  "files": [
    "core.ts",
    "tsc.ts"
  ]
}
```
  
- **module**
  - 타입스크립트 소스가 컴파일되어 만들어진 ES5 자바스크립트 코드는 웹 브라우저와 node.js 양쪽에서 모두 동작해야 하는데 이 둘은 동작 방식이 다름
  - 자바스크립트는 웹 브라우저에서는 `AMD (Asynchronous Module Definition)`, node.js 에서는 `CommonJS` 방식으로 동작함
  - 따라서 동작 대상 플랫폼이 웹 브라우저면 `amd` 로 설정하고, node.js 이면 `commonjs`로 설정
  
- **moduleResolution**
  - module 키 값이 commonjs 이면 node.js 에서 동작하는 것이므로 `node` 로 설정
  - module 키 값이 amd 이면 웹 브라우저 에서 동작하는 것이므로 `classic` 로 설정
  
- **target**
  - 트랜스파일할 대상 자바스크립트의 버전
  - [node.js 가 지원하는 버전의 ES 버전](https://node.green/)에 맞게 지정

- **allowJs**
  - 자바스크립트를 타입스크립트로 점차적으로 변환하여 사용할 수도 있는데 이 때 .ts 파일에서 .js 파일도 import 할 수 있게 해야하는 경우가 있음
    allowJs 는 .ts, .tsx 파일에서 .js 파일을 import 할 수 있게 해 줌

- **removeComments**
  - 타입스크립트 코드를 자바스크립트로 트랜스파일할 때 주석을 모두 제거
  
- **baseUrl, outDir**
  - 타입스크립트가 트랜스파일할 때 소스의 가장 상위 base 디렉터리와 root 디렉터리를 설정
  - 다른 파일에서 import 등을 하여 경로를 명시할 때 상대경로를 사용하지 않아도 `baseUrl` 이 명시된 곳을 기준으로 절대경로처럼 시작점을 명시
  - path 를 resolve 할 때도 상대경로가 아니라면 baseUrl 부터 찾음
  - tsc 는 tsconfig.json 파일이 있는 디렉터리에서 실행되기 때문에 현재 디렉터리를 의미하는 `.` 로 `baseUrl` 키 값을 설정하는 것이 일반적  
  - 둘 다 트랜스파일된 ES5 자바스크립트 파일을 저장하는 디렉터리를 설정하는 기능
  - `outDir` 은 `baseUrl` 을 기준으로 했을 때의 하위 디렉터리명
  - dist 라고 설정하면 빌드된 결과가 dist 디렉터리에 생성됨
  
- **paths**
  - import 문에서 from 부분을 해석할 때 찾아야하는 디렉터리를 설정
  - import 시 반복되는 path 를 사용하거나 깊이가 길어지면 path 가 길어지는데 이를 방지하기 위해 path 에 별명을 주어 map 시켜서 간단하게 사용
  - import 문이 찾아야 하는 소스가 외부 패키지이면 node_modules 디렉터리에서 찾아야 하므로 node_modules/* 도 포함
  
- **esModuleInterop**
  - 오픈소스 자바스크립트 라이브러리 중에는 웹 브라우저에서 동작한다는 가정으로 만들어진 라이브러리들이 있는데 이는 CommonJS 방식으로 동작하는 타입스크립트 코드에 혼란을 줌
    예를 들어 `chance` 패키지는 `AMD` 방식을 전제로 해서 구현된 라이브러리인데 이 패키지가 정상 동작하려면 esModuleInterop 키 값을 `true` 로 설정해야 함
    
- **sourceMap**
  - 이 값이 `true` 이면 트랜스파일 디렉터리에 `.js` 파일 외에 `.js.map` 파일이 생성됨
  - 이 sourceMap 파일의 역할은 변환된 자바스크립트 코드가 타입스크립트 코드의 어디에 해당하는지 알려주는 것으로 주로 디버깅 시 사용됨
  - 배포 사이즈를 줄여야 하는 배포 환경에서는 false 로 설정
  
- **downlevelIteration**
  - 생성기 (generator) `function*` 라는 타입스크립트 구문이 정상 동작하려면 `true` 로 설정
  - target 이 `ES5` 이하일 때에도 `for...of`, `전개 연산자`, `비구조화 할당` 등의 문법 지원     
    > 생성기에 대한 설명은 [ES2015+ (ES6+) 기본](https://assu10.github.io/dev/2021/08/01/js-basic/) 의 1.10. generator (생성기) function* 를 참고하세요.

- **strict 체크**
  - 타입을 얼마나 엄격하게 검사할지에 대한 옵션으로 총 8개가 있음
  
  - **strict**
    - 아래 7가지 옵션을 모두 사용하려면 `strict` 옵션만 `true` 로 설정하면 된다.
    - 자바스크립트에서 타입스크립트로 전환하는 경우 바로 strict 를 적용할 수 없으니 여러 옵션들 중 선택해서 사용하는 경우에 적절히 사용
    
  - **alwaysStrict**
    - strict 와 비슷하지만 strict 는 아래 모든 옵션을 사용한다는 의미이고, `alwaysStrict` 는 [ECMAScript strict 모드](https://developer.mozilla.org/ko/docs/Web/JavaScript/Reference/Strict_mode)를 사용한다는 의미

  - **noImplicitAny**
    - 타입스크립트는 `function(a, b)` 처럼 매개변수에 타입을 명시하지 않으면 `function(a: any, b: any)` 처럼 암시적으로 `any 타입` 을 설정한 것으로 간주함
    - `function(a, b)` 와 같은 코드는 타입스크립트에서 오류로 인식을 하는데 `false` 로 설정 시 문제로 인식하지 않음
 
  - **noImplicitThis**
    - this 의 context 가 any 를 추론하게 되면 현재 객체의 context 가 아니라는 것을 뜻하게 되어 에러를 발생
  
  - **strictBindCallApply** 
    - 타입스크립트가 call, bind, apply 사용 시 함수의 arguments 타입을 추론하여 사용할 수 있게 함
  
  - **strictFunctionTypes** 
    - 함수의 arguments 타입을 더 정확히 추론
  
  - **strictNullChecks** 
    - 해당 옵션이 false 인 경우 null, undefined 체킹이 무시되는데 이것은 런타임 오류를 발생시킬 확률이 높으므로 `true` 권장
  
  - **strictPropertyInitialization**
    - 해당 옵션이 true 인 경우 클래스의 멤버 변수가 초기화되지 않았으면 오류 발생
    - 초기화는 속성에 직접 기본값을 대입하거나 생성자에서 대입
 
- **noEmitOnError**
  - true 로 설정하면 에러 발생 시 자바스크립트 코드, source-maps, declaration 이 dist 디렉터리에 생기지 않음
  - 에러가 있는 코드가 빌드되는 것이 싫다면 true 로 설정
  
- **skipLibCheck**
  - 라이브러리의 타입 검사를 생략하여 타입 검사 정확도를 조금 희생하더라고 컴파일 시간을 단축
  - 보통의 경우 라이브러리의 타입을 검사할 필요가 없으므로 `true` 설정 권장

- **noErrorTruncation**  
  - 에러 메시지가 잘리는 것을 방지

---

### 4.2. 프로젝트 구조 생성

해당 포스팅에서는 아래의 `tsconfig.json` 설정을 사용할 것이다.
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "esModuleInterop": true,
    "target": "es2015",
    "moduleResolution": "node",
    "outDir": "dist",
    "baseUrl": ".",
    "sourceMap": true,
    "downlevelIteration": true,
    "noImplicitAny": true,
    "paths": { "*": ["node_modules/*"] }
  },
  "include": ["src/**/*"]
}
```

`"include": ["src/**/*"]` 를 보면 ./src, ./src/utils 디렉터리에 모든 타입스크립트 소스가 있다는 것을 의미하므로 아래와 같이 디렉터리와 소스 파일을 생성한다.

```shell
> mkdir -p src/utils
> touch src/index.ts src/utils/makePerson.ts
```

```shell
>tree -L 3 -N
.
├── node_modules
├── package-lock.json
├── package.json
├── src
│   ├── index.ts
│   └── utils
│       └── makePerson.ts
└── tsconfig.json
```

개발 시엔 `ts-node` 를 사용하지만 개발이 완료되면 타입스크립트 소스를 ES5 자바스크립트 코드로 변환하여 `node` 로 실행해야 한다.<br />
편의성을 위해 `package.json` 의 `scripts` 항목에 dev 와 build 스크립트를 추가한다.

```json
{
...,
  "main": "src/index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1",
    "dev": "ts-node src",
    "build": "tsc && node dist"
  },
...
}
```

`ts-node src` 는 src 아래에 있는 index.ts 를 실행한다는 의미이고,
`tsc && node dist` 는 개발 완료 후 배포를 위해 dist 디렉터리에 ES5 자바스크립트 파일을 생성한다는 의미이다.

makePerson.ts
```ts
export function makePerson(name: string, age:number) {
    return {name: name, age: age}
}

export function testMakePerson() {
    console.log(makePerson('Assu', 22), makePerson('jhlee', 23))
}
```

index.ts
```ts
import {testMakePerson} from "./utils/makePerson"

testMakePerson()
```

이제 index.ts 를 실행해보자.

```shell
> npm run dev

> chap02-1@1.0.0 dev
> ts-node src

{ name: 'Assu', age: 22 } { name: 'jhlee', age: 23 }
```

```shell
> npm run build

> chap02-1@1.0.0 build
> tsc && node dist

{ name: 'Assu', age: 22 } { name: 'jhlee', age: 23 }
```

`npm run build` 시 dist 디렉터리에 ES5 로 변환된 자바스크립트 소스들이 생성된 것을 확인할 수 있다.


### 4.3. 모듈 (export, import)

타입스크립트에서는 index.ts 와 같은 소스 파일을 `모듈` 이라고 한다.

모듈로 분할하여 작성 시 그 내용을 공유하기 위해 `export`, `import` 키워드를 사용한다.

아래의 코드를 보자. (문법 말고 모듈화에 관한 부분만 보세요)

index.ts
```ts
let MAX_AGE = 100

interface IPerson {
    name: string
    age: number
}

class Person implements IPerson {
    constructor(public name: string, public age: number) { }
}

function makeRandomNumber(max: number = MAX_AGE) : number {
    return Math.ceil((Math.random() * max))
}

const makePerson = (name: string, age: number = makeRandomNumber()) => ({name, age})

const testMakePerson = (): void => {
    let assu: IPerson = makePerson('assu')
    let jhlee: IPerson = makePerson('jhlee')
    console.log(assu, jhlee)
}

testMakePerson()
```

```shell
> npm run dev

> chap02-1@1.0.0 dev
> ts-node src

{ name: 'assu', age: 56 } { name: 'jhlee', age: 59 }
```

소스가 동작은 하지만 약간 복잡해보인다.
그럼 이제 모듈화를 진행해보도록 하자.

```shell
> mkdir -p src/person
> touch src/person/Person.ts
```

Person.ts
```ts
let MAX_AGE = 100

export interface IPerson {
    name: string
    age: number
}

class Person implements IPerson {
    constructor(public name: string, public age: number) { }
}

function makeRandomNumber(max: number = MAX_AGE) : number {
    return Math.ceil((Math.random() * max))
}

export const makePerson = (name: string, age: number = makeRandomNumber()) => ({name, age})
```

index.ts
```ts
import {IPerson, makePerson} from "./person/Person"

const testMakePerson = (): void => {
    let assu: IPerson = makePerson('assu')
    let jhlee: IPerson = makePerson('jhlee')
    console.log(assu, jhlee)
}

testMakePerson()
```

`export` 키워드는 interface, class, type, let, const 키워드 앞에 불일 수 있다.

`import` 키워드의 기본 형태는 아래와 같다.

> import { 심볼 목록 } from '파일의 상대 경로'

특정 심볼로 import 할 수도 있다.

> import * as U from '파일의 상대 경로'

```ts
import * as U from "../utils/makeRandomNumber"
...

export const makePerson = (name: string, age: number = U.makeRandomNumber()) => ({name, age})
```

타입스크립트는 자바스크립트와의 호환을 위해 `export default` 구문을 제공한다.
`export default` 키워드는 한 모듈이 내보내는 기능 중 오직 한 개에만 붙일 수 있고, `export default` 가 붙은 기능은 `import` 문으로 불러올 때
중괄호 `{}` 없이 사용 가능하다.

IPerson.ts
```ts
export default interface IPerson {
    name: string
    age: number
}
```

Person.ts
```ts
import * as U from "../utils/makeRandomNumber"
import IPerson from "./IPerson"
...
```

index.ts
```ts
import IPerson from "./person/IPerson"
import Person, {makePerson} from "./person/Person"     // Person 은 export default, makePerson 은 export
```

외부 패키지를 사용할 때 `import` 문을 알아보기 위해 아래와 같이 `chance` 와 `ramda` 패키지를 설치해보자.

```shell
> npm i chance ramda
> npm i -D @types/chance @types/ramda
```

`chance` 는 fake data 를 만들어주는 패키지이고, `ramda` 는 함수형 유틸리티 패키지인데 지금은 이 정도만 알고 넘어가자.

```ts
import IPerson from "./person/IPerson"
import Person, {makePerson} from "./person/Person"     // Person 은 export default, makePerson 은 export
import Chance from 'chance'
import * as R from 'ramda'

const chance = new Chance()
let persons: IPerson[] = R.range(0, 2)
    .map((n: number) => new Person(chance.name(), chance.age()))
console.log(persons)
```

`chance` 와 `ramda` 는 외부 패키지이므로 node_modules 디렉터리에 있기 때문에 경로에서 ./ 등을 생략한 채 패키지명만 기입한다.

```shell
npm run dev                        

> chap02-1@1.0.0 dev
> ts-node src

[
  Person { name: 'Rosalie Rodgers', age: 31 },
  Person { name: 'Carlos Lewis', age: 43 }
]
```

---

*본 포스팅은 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)
* [TypeScript Guidebook](https://yamoo9.gitbook.io/typescript/)
* [tsconfig Reference](https://www.typescriptlang.org/tsconfig)
* [Typescript, tsconfig.json 주요 설정](https://kay0426.tistory.com/69)
* [tsconfig.json 컴파일 옵션 정리](https://geonlee.tistory.com/214)
* [node.js가 지원하는 ES 버전 확인](https://node.green/)
* [typescript - readonly](https://radlohead.gitbook.io/typescript-deep-dive/type-system/readonly)