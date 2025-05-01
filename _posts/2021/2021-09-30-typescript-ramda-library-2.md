---
layout: post
title:  "Typescript - ramda 라이브러리 (2)"
date: 2021-09-30 10:00
categories: dev
tags: javascript typescript
---

이 포스트는 람다(ramda) 함수형 유틸리티 라이브러리의 기능에 대해 알아본다.

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
    "noImplicitAny": false,
    "noImplicitThis": false,
    "strictFunctionTypes": false,
    "paths": { "*": ["node_modules/*"] }
  },
  "include": ["src/**/*"]
}
```

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

<!-- TOC -->
  * [1. `chance` 패키지로 객체 생성](#1-chance-패키지로-객체-생성)
    * [1.1. ICoordinates 타입 객체 생성](#11-icoordinates-타입-객체-생성)
    * [1.2. ILocation 타입 객체 생성](#12-ilocation-타입-객체-생성)
    * [1.3. IPerson 타입 객체 생성](#13-iperson-타입-객체-생성)
  * [2. 렌즈 (Lens) 를 활용한 객체의 속성 다루기](#2-렌즈-lens-를-활용한-객체의-속성-다루기)
    * [2.1. 렌즈 (Lens)](#21-렌즈-lens-)
    * [2.2. `R.prop`, `R.assoc` 함수](#22-rprop-rassoc-함수)
    * [2.3. `R.lens` 함수](#23-rlens-함수)
    * [2.4. `R.view`, `R.set`, `R.over` 함수](#24-rview-rset-rover-함수)
    * [2.5. `R.lensPath` 함수](#25-rlenspath-함수)
  * [3. 객체 다루기](#3-객체-다루기)
    * [3.1. `R.toPairs`, `R.fromParis` 함수](#31-rtopairs-rfromparis-함수)
    * [3.2. `R.keys`, `R.values` 함수](#32-rkeys-rvalues-함수)
    * [3.3. `R.zipObj` 함수](#33-rzipobj-함수)
    * [3.4. `R.mergeLeft`, `R.mergeRight` 함수](#34-rmergeleft-rmergeright-함수)
    * [3.5. `R.mergeDeepLeft`, `R.mergeDeepRight` 함수](#35-rmergedeepleft-rmergedeepright-함수)
  * [4. 배열 다루기](#4-배열-다루기)
    * [4.1. `R.prepend`, `R.append` 함수](#41-rprepend-rappend-함수)
    * [4.2. `R.flatten` 함수](#42-rflatten-함수)
    * [4.3. `R.unnest` 함수](#43-runnest-함수)
    * [4.4. `R.sort` 함수](#44-rsort-함수)
    * [4.5. `R.sortBy` 함수](#45-rsortby-함수)
    * [4.6. `R.sortWith` 함수](#46-rsortwith-함수)
  * [5. 조합 논리 이해](#5-조합-논리-이해)
    * [5.1. 조합자 (combinator)](#51-조합자-combinator)
    * [5.2. `R.chain` 함수](#52-rchain-함수)
    * [5.3. `R.flip` 조합자](#53-rflip-조합자)
    * [5.4. `R.identity` 조합자](#54-ridentity-조합자)
    * [5.5. `R.always` 조합자](#55-ralways-조합자)
    * [5.6. `R.applyTo` 조합자](#56-rapplyto-조합자)
    * [5.7. `R.ap` 조합자](#57-rap-조합자)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## 1. `chance` 패키지로 객체 생성

`chance` 패키지는 그럴듯한 가짜 데이터를 만들어주는 라이브러리이다.

람다와 직접적인 관련은 없지만 람다가 제공하는 객체 속성을 다루는 함수 등을 사용하려면 객체 데이터가 필요하므로 객체 데이터를 만들기위해 사용할 예정이다.

총 3개 타입의 객체를 만들건데 각 용도는 아래와 같다.

- **IPerson** 타입 객체
    - 이름, 나이 등 한 사람의 정보를 담음
- **ILocation** 타입 객체
    - IPerson 타입 객체는은 주소를 표현하는 ILocation 타입의 location 속성을 포함
- **ICoordinates** 타입 객체
    - ILocation 타입 객체는 좌표를 표현하는 ICoordinates 타입의 coordinates 속성을 포함

---

### 1.1. ICoordinates 타입 객체 생성

```shell
> mkdir -p src/model/coordinates
> cd src/model/coordinates
> touch ICoordinates.ts makeICoordinates.ts makeRandomICoordinates.ts index.ts
```

각 파일의 용도는 아래와 같다.
- **ICoordinates.ts**
  - 위도와 경도 속성 표시
- **makeICoordinates.ts**
    - ICoordinates 객체를 쉽게 생성해주는 함수 구현
- **makeRandomICoordinates.ts**
    - 가짜 데이터 생성
- **index.ts**

ICoordinates.ts
```ts
// 위도와 경도 표시

export type ICoordinates = {
    latitude: number,   // 위도
    longitude: number   // 경도
}
```

makeICoordinates.ts
```ts
// ICoordinates 객체를 쉽게 만들어주는 역할

import {ICoordinates} from "./ICoordinates";

export const makeICoordinates = (latitude: number, longitude: number): ICoordinates =>
    ({latitude, longitude});
```

makeRandomICoordinates.ts
```ts
// chance 패키지를 이용하여 makeRandomICoordinates 함수 만듦

import {ICoordinates} from "./ICoordinates";
import {makeICoordinates} from "./makeICoordinates";
import Chance from 'chance'

const c = new Chance;

export const makeRandomICoordinates = (): ICoordinates =>
    makeICoordinates(c.latitude(), c.longitude());
```

src/model/coordinates/index.ts
```ts
import { ICoordinates } from "./ICoordinates";
import { makeICoordinates } from "./makeICoordinates";
import { makeRandomICoordinates } from "./makeRandomICoordinates";


// ICoordinates 와 makeICoordinates, makeRandomICoordinates 를 export 합니다.
export {ICoordinates, makeICoordinates, makeRandomICoordinates}
```

src/coordinates-test.ts
```ts
// ./model/coordinates 는 파일명이 아니라 디렉터리명이다.
// 해당 디렉터리에 index.ts 파일이 있으면 타입스크립트 컴파일러는 './model/coordinates/index/ts' 로 해석한다.
import {ICoordinates, makeRandomICoordinates} from "./model/coordinates";

const coordinates: ICoordinates = makeRandomICoordinates();
console.log(coordinates);   // { latitude: -70.33719, longitude: 138.98725 }
```

*./model/coordinates* 는 파일명이 아니라 디렉터리명이다.<br />
해당 디렉터리에 index.ts 파일이 있으면 타입스크립트 컴파일러는 *./model/coordinates/index/ts* 로 해석한다.

```shell
> ts-node coordinates-test
```

---

### 1.2. ILocation 타입 객체 생성

이제 ICoordinates 타입 속성을 포함하는 ILocation 타입을 구현해보자.

```shell
> mkdir -p src/model/location
> cd src/model/location
> touch ILocation.ts makeILocation.ts makeRandomILocation.ts index.ts
```

각 파일의 용도는 아래와 같다.
- **ILocation.ts**
  - 주소 속성 표시
- **makeILocation.ts**
  - ILocation 객체를 쉽게 생성해주는 함수 구현
- **makeRandomILocation.ts**
  - 가짜 데이터 생성
- **index.ts**

ILocation 타입에서 country 만 필수 속성이고, 나머지는 모두 선택 속성으로 구현한다.

ILocation.ts
```ts
import {ICoordinates} from "../coordinates";

// country 만 필수 속성이고, 그 외엔 선택 속성
export type ILocation = {
    country: string,
    city?: string,
    address?: string,
    coordinates?: ICoordinates
}
```

makeILocation.ts
```ts
// ILocation 객체를 쉽게 생성해주는 함수 구현

import {ICoordinates} from "../coordinates";
import {ILocation} from "./ILocation";

export const makeILocation = (
    country: string,
    city: string,
    address: string,
    coordinates: ICoordinates
): ILocation => ({country, city, address, coordinates})
```

makeRandomILocation.ts
```ts
import {ILocation} from "./ILocation";
import {makeILocation} from "./makeILocation";
import {makeRandomICoordinates} from "../coordinates";
import Chance from 'chance'

const c = new Chance

export const makeRandomILocation = (): ILocation =>
    makeILocation(c.country(), c.city(), c.address(), makeRandomICoordinates());
```

src/model/location/index.ts
```ts
import { ILocation } from "./ILocation";
import { makeILocation } from "./makeILocation";
import { makeRandomILocation } from "./makeRandomILocation";

export {ILocation, makeILocation, makeRandomILocation}
```

src/location-test.ts
```ts
import {ILocation, makeRandomILocation} from "./model/location";

const location: ILocation = makeRandomILocation();
console.log(location);

/*
{
    country: 'MM',
    city: 'Bojdiati',
    address: '1949 Sasso River',
    coordinates: { latitude: -82.0187, longitude: 103.75517 }
}
*/
```

```shell
> ts-node location-test
```

---

### 1.3. IPerson 타입 객체 생성

이제 IPerson 타입을 구현해보자.

```shell
> mkdir -p src/model/person
> cd src/model/person
> touch IPerson.ts makeIPerson.ts makeRandomIPerson.ts index.ts
```

IPerson.ts
```ts
import {ILocation} from "../location";

export type IPerson = {
    name: string,
    age: number,
    title?: string,
    location?: ILocation
}
```

> 뒤에 설명한 R.sortBy, R.sortWith 는 선택 속성을 대상으로 동작하지 않기 때문에 name, age 는 필수 속성으로 구현

makeRandomIPerson.ts
```ts
import {IPerson} from "./IPerson";
import {makeIPerson} from "./makeIPerson";
import {makeRandomILocation} from "../location";
import Chance from 'chance'

const c = new Chance();

export const makeRandomIPerson = (): IPerson =>
    makeIPerson(c.name(), c.age(), c.profession(), makeRandomILocation());
```

src/model/person/index.ts
```ts
import { IPerson } from "./IPerson";
import { makeIPerson } from "./makeIPerson";
import { makeRandomIPerson } from "./makeRandomIPerson";

export {IPerson, makeIPerson, makeRandomIPerson}
```

src/person-test.ts
```ts
import {IPerson, makeRandomIPerson} from "./model/person";

const person: IPerson = makeRandomIPerson();
console.log(person);

/*
{
    name: 'Leroy Bryan',
        age: 31,
    title: 'Occupational Therapist',
    location: {
    country: 'ST',
        city: 'Buetunu',
        address: '1556 Zemip Turnpike',
        coordinates: { latitude: -12.52604, longitude: 39.08515 }
}
}
*/
```

지금까지 `chance` 패키지를 이용하여 객체를 만들어보았다.<br />
이제 만들어놓은 객체를 이용하는 람다 라이브러리에 대해 알아보자.

---

## 2. 렌즈 (Lens) 를 활용한 객체의 속성 다루기

### 2.1. 렌즈 (Lens) 

**렌즈**란 하스켈 언어의 Control.Lens 라이브러리 내용 중 자바스크립트에서 동작할 수 있는 getter, setter 기능만을 람다 함수로 구현한 것이다.<br />
람다의 렌즈 기능을 활용하면 객체의 속성값을 얻거나 설정하는 작업을 쉽게 할 수 있다.

렌즈는 아래와 같은 순서로 이용한다.

- `R.lens` 함수로 객체의 특정 속성에 대한 렌즈를 만듦
- 렌즈를 `R.view` 함수에 적용하여 속성값을 얻음
- 렌즈를 `R.set` 함수에 적용하여 속성값이 바뀐 새로운 객체을 얻음
- 렌즈와 속성값을 바꾸는 함수를 `R.over` 함수에 적용하여 값이 바뀐 새로운 객체를 얻음

---

### 2.2. `R.prop`, `R.assoc` 함수

`R.prop` 은 객체의 속성값을 가져오는 *getter* 역할을 한다.

`R.assoc` 은 객체의 속성값을 변경하는 *setter* 역할을 한다.

```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

// R.prop
const person: IPerson = makeRandomIPerson();

const name = R.pipe(
    R.prop('name'),
    R.tap(name => console.log(name))    // Brian Turner
)(person);


// R.assoc
const person2: IPerson = makeRandomIPerson();
const getName = R.pipe(
    R.prop('name'),
    R.tap(name => console.log(name))
);
const originalName = getName(person2);

const modifiedPerson = R.assoc('name', 'assu')(person2);
const modifiedName = getName(modifiedPerson);
```

---

### 2.3. `R.lens` 함수

렌즈 기능을 사용하려면 먼저 렌즈를 만들어야 하는데 `R.lens`, `R.prop`, `R.assoc` 의 조합으로 렌즈를 만들 수 있다. 

```ts
const makeLens = (propName: string) => R.lens(R.prop(propName), R.assoc(propName));
```

---

### 2.4. `R.view`, `R.set`, `R.over` 함수

렌즈를 만들었으면 `R.view`, `R.set`, `R.over` 함수에 렌즈를 적용해서 getter, setter, 그 외 함수를 만들 수 있다.

```ts
const getter = (lens) => R.view(lens);
const setter = (lens) => <T>(newValue: T) => R.set(lens, newValue);
const setterUsingFunc = (lens) => <T, R>(func: (T) => R) => R.over(lens, func);
```


```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

const makeLens = (propName: string) => R.lens(R.prop(propName), R.assoc(propName));

const getter = (lens) => R.view(lens);
const setter = (lens) => <T>(newValue: T) => R.set(lens, newValue);
const setterUsingFunc = (lens) => <T, R>(func: (T) => R) => R.over(lens, func);

// 활용
const nameLens = makeLens('name');
console.log('nameLens', nameLens);  // [Function (anonymous)]

const getName = getter(nameLens);
console.log('getName', getName);   // [Function: f1]

const setName = setter(nameLens);
console.log('nameLens', nameLens);  // [Function (anonymous)]

const setNameUsingFunc = setterUsingFunc(nameLens);
console.log('setNameUsingFunc', setNameUsingFunc);  // [Function (anonymous)]

const person: IPerson = makeRandomIPerson();

const name = getName(person);
console.log('name', name);  // Ina White

const newPerson = setName('assu')(person);
console.log('newPerson', newPerson);
/*
newPerson {
    name: 'assu',
        age: 64,
        title: 'Buyer',
        location: {
        country: 'NF',
            city: 'Jeicfa',
            address: '1982 Ugeka Mill',
            coordinates: { latitude: -48.87136, longitude: -164.53377 }
    }
}
*/

const anotherPerson = setNameUsingFunc(name => `Miss ${name}`)(person);
console.log('anotherPerson', anotherPerson);
/*
anotherPerson {
    name: 'Miss Lura Cole',
        age: 56,
        title: 'EEO Compliance Manager',
        location: {
        country: 'LK',
            city: 'Mutubrew',
            address: '966 Boge Grove',
            coordinates: { latitude: 29.59275, longitude: -19.68588 }
    }
}
*/

const capitalPerson = setNameUsingFunc(R.toUpper)(person);
console.log('capitalPerson', capitalPerson);
/*
capitalPerson {
    name: 'LIDA OWEN',
        age: 35,
        title: 'Manpower Planner',
        location: {
        country: 'TN',
            city: 'Ekapuvzo',
            address: '1286 Zoklah Court',
            coordinates: { latitude: 28.94433, longitude: 177.0845 }
    }
}
*/

console.log(
    name, getName(newPerson), getName(anotherPerson), getName(capitalPerson)
)
// Rose Gibson assu Miss Rose Gibson ROSE GIBSON
```

위와 같이 코드를 작성하면 name 이라는 속성이 *const nameLens = makeLens('name');* 에만 사용되기 때문에 나중에 속성명이 변경되도 코드의 다른 부분에 영향을 주지 않는다.

---

### 2.5. `R.lensPath` 함수

IPerson 객체의 longitude 속성값을 알려면 person.location.coordinates.longitude 와 같은 중첩 속성 코드를 작성해야하는데 이러한 중첩 속성을 **경로 (path)** 라고 한다.

위와 같은 긴 경로의 속성을 렌즈로 만들려면 `R.lensPath` 를 이용하면 된다.

```ts
렌즈 = R.lensPath(['location', 'coordinates', 'longitude'])
```

아래 코드는 바로 위의 nameLens 대신 longitudeLens 를 사용하면서 함수들의 이름과 값만 바뀌고 다른 내용은 완전히 똑같다.
```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

const makeLens = (propName: string) => R.lens(R.prop(propName), R.assoc(propName));

const getter = (lens) => R.view(lens);
const setter = (lens) => <T>(newValue: T) => R.set(lens, newValue);
const setterUsingFunc = (lens) => <T, R>(func: (T) => R) => R.over(lens, func);

// 활용
const longitudeLens = R.lensPath(['location', 'coordinates', 'longitude']);  // 렌즈 생성
console.log('longitudeLens', longitudeLens);     // [Function (anonymous)]

const getLongitude = getter(longitudeLens);
console.log('getLongitude', getLongitude);      //  [Function: f1]

const setLongitude = setter(longitudeLens);
console.log('setLongitude', setLongitude);      // [Function (anonymous)]

const setLongitudeUsingFunc = setterUsingFunc(longitudeLens);
console.log('setLongitudeUsingFunc', setLongitudeUsingFunc);        // [Function (anonymous)]

const person: IPerson = makeRandomIPerson();

const longitude = getLongitude(person);
console.log('longitude', longitude);    // -88.99555

const newPerson = setLongitude(0.12345)(person);
console.log('newPerson', newPerson);
/*
newPerson {
    name: 'Charles Hudson',
        age: 63,
        title: 'Biotechnical Researcher',
        location: {
        country: 'UM',
            city: 'Tipedivot',
            address: '874 Wazvod Court',
            coordinates: { latitude: 2.4853, longitude: 0.12345 }
    }
}
*/

const anotherPerson = setLongitudeUsingFunc(R.add(0.12345))(person);
console.log('anotherPerson', anotherPerson);
/*
anotherPerson {
    name: 'Trevor Schultz',
        age: 57,
        title: 'Food & Beverage Director',
        location: {
        country: 'MC',
            city: 'Rarito',
            address: '484 Deha Square',
            coordinates: { latitude: -65.29564, longitude: 26.61039 }
    }
}
*/

console.log(
    longitude, getLongitude(newPerson), getLongitude(anotherPerson)
);
// 164.50159 0.12345 164.62503999999998
```

---

## 3. 객체 다루기

### 3.1. `R.toPairs`, `R.fromParis` 함수

`R.toPairs` 함수는 객체의 속성을 분해하여 배열로 만들어준다. 이 때 배열의 각 아이템은 **[string, any] 타입의 튜플**이다.

`R.fromParis` 함수는 *[키:값]* 형태의 아이템을 가진 배열을 다시 객체로 만들어준다.  

```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

const person: IPerson = makeRandomIPerson();
const pairs: [string, any][] = R.toPairs(person);
console.log('pairs: ', pairs);
/*
pairs:  [
  [ 'name', 'Willie James' ],
  [ 'age', 53 ],
  [ 'title', 'Technical Support Specialist' ],
  [
    'location',
    {
      country: 'IE',
      city: 'Itmitu',
      address: '1910 Maizo View',
      coordinates: [Object]
    }
  ]
]
*/

// TS2739: Type '{ [index: string]: any; }' is missing the following properties from type 'IPerson': name, age
//const person2: IPerson = R.fromPairs(pairs);  // 오류
const person3: IPerson = R.fromPairs(pairs) as IPerson;
console.log('person3', person3);
/*person3 {
    name: 'Willie James',
        age: 53,
        title: 'Technical Support Specialist',
        location: {
        country: 'IE',
            city: 'Itmitu',
            address: '1910 Maizo View',
            coordinates: { latitude: 37.34966, longitude: 169.75269 }
    }
}*/
```

---

### 3.2. `R.keys`, `R.values` 함수

`R.keys` 은 객체의 속성 이름만 추려서 **string[]** 타입 배열로 반환한다.

`R.values` 는 객체의 속성값만 추려서 **any[]** 타입 배열로 반환한다.

```ts
import * as R from 'ramda'
import {makeRandomIPerson} from "./model/person";

const keys: string[] = R.keys(makeRandomIPerson());
console.log('keys', keys);  // keys [ 'name', 'age', 'title', 'location' ]

const values: any[] = R.values(makeRandomIPerson());
console.log('values', values);
/*
values [
    'Eliza Riley',
        58,
        'Traffic Manager',
        {
            country: 'CL',
            city: 'Pubuceb',
            address: '1563 Nule Turnpike',
            coordinates: { latitude: -64.73081, longitude: 8.88806 }
        }
    ]
*/
```

---

### 3.3. `R.zipObj` 함수

`R.zipObj` 는 **키 배열(속성 이름의 배열)**과 **값 배열(속성값의 배열)**, 이 두 가지 매개 변수를 결합하여 객체를 생성한다. 

```ts
객체 = R.zipObj(키 배열, 값 배열)
```

```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

const originalPerson: IPerson = makeRandomIPerson();
const keys: string[] = R.keys(originalPerson);
const values: any[] = R.values(originalPerson);

const zippedPerson: IPerson = R.zipObj(keys, values) as IPerson;

console.log('originalPerson: ', originalPerson, 'zippedPerson: ', zippedPerson);
/*
originalPerson:  {
    name: 'Bertha Gonzalez',
        age: 64,
        title: 'Producer',
        location: {
        country: 'BQ',
            city: 'Fifcuwusu',
            address: '381 Vigfor Loop',
            coordinates: { latitude: -54.04413, longitude: 56.24533 }
    }
} zippedPerson:  {
    name: 'Bertha Gonzalez',
        age: 64,
        title: 'Producer',
        location: {
        country: 'BQ',
            city: 'Fifcuwusu',
            address: '381 Vigfor Loop',
            coordinates: { latitude: -54.04413, longitude: 56.24533 }
    }
}
*/
```

---

### 3.4. `R.mergeLeft`, `R.mergeRight` 함수

`R.mergeLeft`, `R.mergeRight` 함수는 두 객체를 입력받아 두 객체의 속성들을 결합하여 하나의 새로운 객체를 생성한다.<br />

```ts
새로운 객체 = R.mergeLeft(객체1)(객체2)  // 속성명은 같고 속성같이 다를 때 왼쪽 객체의 우선순위가 높음
새로운 객체 = R.mergeRight(객체1)(객체2)  // 속성명은 같고 속성같이 다를 때 오른쪽 객체의 우선순위가 높음
```

```ts
import * as R from 'ramda'

const left: object = {name: 'assu'};
const right: object = {name: 'jhlee', age: 20}

const merge: object = R.mergeLeft(left, right);

console.log(merge); // { name: 'assu', age: 20 }
```

---

### 3.5. `R.mergeDeepLeft`, `R.mergeDeepRight` 함수

`R.mergeLeft`, `R.mergeRight` 는 객체의 속성에 담긴 객체를 바꾸지는 못한다.<br />
예를 들어 *IPerson* 의 name, age 등의 속성값은 변경해도 location 이나 location.coordinates 의 속성값을 변경하지는 못한다.

반면 `R.mergeDeepLeft`, `R.mergeDeepRight` 는 *IPerson* 의 name, age 외에도 location 이나 location.coordinates 같은 경로(path) 의 속성값들도 변경할 수 있다.

```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";
import {ILocation, makeRandomILocation} from "./model/location";
import {ICoordinates, makeRandomICoordinates} from "./model/coordinates";

const person: IPerson = makeRandomIPerson();
const location: ILocation = makeRandomILocation();
const coordinates: ICoordinates = makeRandomICoordinates();

const newLocation = R.mergeDeepRight(location, {coordinates});
const newPerson = R.mergeDeepRight(person, {location: newLocation});

console.log('person', person);
console.log('newPerson', newPerson);
/*
person {
    name: 'Mildred Hart',
        age: 21,
        title: 'Novelist',
        location: {
        country: 'TM',
            city: 'Puafjev',
            address: '1834 Hijoma Street',
            coordinates: { latitude: 43.8177, longitude: 138.68656 }
    }
}
newPerson {
    name: 'Mildred Hart',
        age: 21,
        title: 'Novelist',
        location: {
        country: 'AM',
            city: 'Fijosrid',
            address: '1230 Ekita River',
            coordinates: { latitude: 36.94358, longitude: -121.11057 }
    }
}*/
```

위 결과를 보면 location 과 coordinates 만 변경된 것을 알 수 있다.

---

## 4. 배열 다루기

### 4.1. `R.prepend`, `R.append` 함수

`R.prepend`, `R.append` 는 기존 배열의 앞, 뒤에 새 아이템을 삽입한 새 배열을 반환한다.
순수 함수 관점에서 기존 배열 내용은 변경되면 안되기 때문에 이 함수가 만들어졌다.

```ts
import * as R from 'ramda'

const array: number[] = [3, 4];
const newArray: number[] = R.prepend(1)(array);
console.log(newArray);  // [ 1, 3, 4 ]
```

---

### 4.2. `R.flatten` 함수

만약 배열의 구조가 아래처럼 복잡하게 구성되어 있으면 이 배열을 대상으로 람다 라이브러리의 기능을 적용하는 것이 어렵다. 
```ts
[ [ [ 1, 1 ], [ 1, 2 ] ], [ [ 2, 1 ], [ 2, 2 ] ] ]
```

`R.flatten` 함수는 이렇게 복잡한 배열을 1차원 배열로 변경해준다.
```ts
import * as R from 'ramda'

const array = R.range(1, 2+1).map((x: number) => {
    return R.range(1, 2+1).map((y: number) => {
        return [x, y];
    });
});

console.log(array); // [ [ [ 1, 1 ], [ 1, 2 ] ], [ [ 2, 1 ], [ 2, 2 ] ] ]

const flatArray = R.flatten(array);
console.log(flatArray); // [1, 1, 1, 2, 2, 1, 2, 2]
```

---

### 4.3. `R.unnest` 함수

`R.unnest` 함수는 `R.flatten` 함수보다 좀 더 정교하게 배열을 가공해주는데 아래 코드를 보고 이해하자.

```ts
import * as R from 'ramda'

const array = R.range(1, 2+1).map((x: number) => {
    return R.range(1, 2+1).map((y: number) => {
        return [x, y];
    });
});

console.log(array); // [ [ [ 1, 1 ], [ 1, 2 ] ], [ [ 2, 1 ], [ 2, 2 ] ] ]

const unnestedArray = R.unnest(array);
console.log(unnestedArray);     // [ [ 1, 1 ], [ 1, 2 ], [ 2, 1 ], [ 2, 2 ] ], array 를 한 번만 들어올림

const twoUnnestedArray = R.pipe(R.unnest, R.unnest)(array);
console.log(twoUnnestedArray);  // [1, 1, 1, 2, 2, 1, 2, 2], array 를 두 번 들어올림
```

---

### 4.4. `R.sort` 함수

**배열의 타입이 number[]** 라면 `R.sort` 함수를 이용하여 내림차순이나 오름차순으로 정렬할 수 있다.

```ts
정렬된 배열 = R.sort(콜백 함수)(배열)
```

`R.sort` 의 콜백 함수는 아래처럼 구현해야 한다.
```ts
// 마이너스이면 오름차순, 0이거나 플러스값이면 내림차순
(a: number, b: number): number => a - b
```

*a-b* 를 *0* 혹은 *b-a* 로 하면 내림차순으로 정렬한다.

```ts
import * as R from 'ramda'

type voidToNumberFunc = () => number;
const makeRandomNumber = (max: number): voidToNumberFunc =>
    (): number => Math.floor(Math.random() * max);

const array = R.range(1, 5+1).map(makeRandomNumber(100));
const sortedArray = R.sort((a: number, b: number): number => a-b)(array);

console.log(array, sortedArray);    // [ 9, 54, 43, 28, 11 ] [ 9, 11, 28, 43, 54 ]
```

---

### 4.5. `R.sortBy` 함수

**배열에 담긴 아이템이 객체** 라면 특정 속성값에 따라 정렬을 해야하는데 이 때 `R.sortBy` 로 정렬이 가능하다.

`R.sortBy` 는 선택 속성을 대상으로는 동작하지 않고, **오름차순만 가능**하다.

```ts
정렬된 배열 = R.sortBy(객체의 속성을 얻는 함수)(배열)
```

아래는 IPerson 객체들의 배열을 대상으로 name 속성에 따른 정렬과 age 속성에 따른 정렬이다.

```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

const displayPersons = (prefix: string) => R.pipe(
    R.map((person: IPerson) => ({name: person.name, age: person.age})),
    R.tap(o => console.log(prefix, o))
)

const person: IPerson[] = R.range(1, 4+1).map(makeRandomIPerson);   // person 객체 4개가 있는 하나의 배열 생성
//console.log(person);
const nameSortedPersons = R.sortBy(R.prop('name'))(person);
const ageSortedPersons = R.sortBy(R.prop('age'))(person);

displayPersons('sorted by name: ')(nameSortedPersons);
displayPersons('sorted by age: ')(ageSortedPersons);
/*
sorted by name:  [
    { name: 'Bruce Floyd', age: 21 },
    { name: 'Roger Brock', age: 21 },
    { name: 'Todd Webster', age: 32 },
    { name: 'Trevor Gardner', age: 24 }
]
sorted by age:  [
    { name: 'Roger Brock', age: 21 },
    { name: 'Bruce Floyd', age: 21 },
    { name: 'Trevor Gardner', age: 24 },
    { name: 'Todd Webster', age: 32 }
]
*/
```

---

### 4.6. `R.sortWith` 함수

`R.sortBy` 는 오름차순만 가능한 반면 `R.sortWith` 는 `R.ascend`, `R.descend` 와 함께 사용되어 오름차순과 내림차순 모두 가능하다.

`R.sortWith` 도 `R.sortBy` 처럼 선택 속성을 대상으로는 동작하지 않는다.

```ts
import * as R from 'ramda'
import {IPerson, makeRandomIPerson} from "./model/person";

const displayPersons = (prefix: string) => R.pipe(
        R.map((person: IPerson) => ({name: person.name, age: person.age})),
        R.tap(o => console.log(prefix, o))
) as any

const person: IPerson[] = R.range(1, 4+1).map(makeRandomIPerson);   // person 객체 4개가 있는 하나의 배열 생성
const nameSortedPersons = R.sortWith([
  R.descend(R.prop('name'))
])(person);

displayPersons('sorted by name: ')(nameSortedPersons);
/*
sorted by name:  [
    { name: 'Lilly McKinney', age: 51 },
    { name: 'Josie Morrison', age: 61 },
    { name: 'Flora Manning', age: 61 },
    { name: 'Fanny Griffith', age: 63 }
]
*/

```

---

## 5. 조합 논리 이해

### 5.1. 조합자 (combinator)

조합 논리학은 **조합자**라는 특별한 형태의 고차 함수들을 결합하여 새로운 조합자를 만들어내는 것이다.

대부분의 함수형 라이브러리들은 조합 논리로 개발된 유용한 조합자들을 제공하고, 람다 라이브러리 또한 몇 가지 유명한 조합자를 제공한다.

| 조합자 이름 | 의미 | 람다 함수 이름 |
|---|:---:|  |
| C | flip | `R.flip` |
| I | identity | `R.identity` |
| K | constant | `R.always` |
| T | thrush | `R.applyTo` |
| S | substitution | `R.ap` |
| W | duplication | `R.nunnest` |

람다 함수의 동작 방식을 이해하기가 좀 힘든 면이 있다. 그래서 먼저 `R.chain` 에 대해 먼저 알아보자. 

---

### 5.2. `R.chain` 함수

`R.chain` 은 함수를 매개변수로 받아서 동작하는 함수로 매개변수가 1개 일 때와 2개 일 때의 동작이 약간 다르다.

```ts
R.chain(콜백 함수1)
R.chain(콜백 함수1, 콜백 함수2)
```

```ts
import * as R from 'ramda'

const array = [1, 2, 3];

// 매개변수가 1개 일 때
R.pipe(
    R.chain(n => [n, n]),
    R.tap(n => console.log(n))  // [ 1, 1, 2, 2, 3, 3 ]
)(array);

// 매개변수가 2개 일 때
R.pipe(
    R.chain(R.append, R.head),
    R.tap(n => console.log(n))  // [ 1, 2, 3, 1 ]
)(array);
```

매개변수가 1개일 때를 먼저 보자.<br />
매개변수가 1개일 때는 아래 *flatMap* 함수처럼 동작한다.
```ts
// 매개변수가 1개 일 때
R.pipe(
    R.chain(n => [n, n]),
    R.tap(n => console.log(n))  // [ 1, 1, 2, 2, 3, 3 ]
)(array);

// 함수 flapMap 은 fn 을 매개변수로 받아서 => 뒤의 부분을 리턴
// R.chain 의 매개변수가 1개일때는 아래처럼 동작
const flapMap = (fn) => R.pipe(
    R.map(fn),
    R.flatten
)

R.pipe(
    flapMap(n => [n, n]),
    R.tap(n => console.log(n))  // // [ 1, 1, 2, 2, 3, 3 ]
)(array);
```

매개변수가 2개일 때는 아래 *chainTwoFunc* 함수처럼 동작한다.
```ts
// 매개변수가 2개 일 때
R.pipe(
    R.chain(R.append, R.head),
    R.tap(n => console.log(n))  // [ 1, 2, 3, 1 ]
)(array);

const chainTwoFunc = (firstFn, secondFn) => (x) => firstFn(secondFn(x), x);

R.pipe(
    chainTwoFunc(R.append, R.head), // array => (R.append(R.head(array))(array)
    R.tap(n => console.log(n))  // [ 1, 2, 3, 1 ]
)(array);
```

---

### 5.3. `R.flip` 조합자

[Typescript - ramda 라이브러리 (1)](https://assu10.github.io/dev/2021/09/29/typescript-ramda-library/) 의 *4.4. `R.flip` 함수* 에서 설명한 `R.flip` 함수는 아래처럼
**2차 고차 함수의 매개변수 순서를 바꿔주는 역할**을 한다.

```ts
const flip = callback => a => b => callback(b)(a);

// flip(a)
// flip(a)(b) --> flip(b)(a)
```

---

### 5.4. `R.identity` 조합자

`R.identity` 는 단순한 조합이지만 **조합자의 구조상 반드시 함수가 있어야 하는 곳에 위치할 때 그 위력을 발휘**한다.

```ts
const identity = x => x;
```

> Identity 함수의 추가 내용은 [Typescript - 함수 조합](https://assu10.github.io/dev/2021/09/29/typescript-function-composition/) 의 *2.3. 아이덴티티(Identity, I) 함수* 를 참고하세요.

앞에서 구현한 *flatMap* 함수는 콜백 함수가 하나 필요한데, 이 때 `R.identity` 를 사용할 수 있다.
```ts
import * as R from 'ramda'

const array = [[1], [2], [3]];

// 함수 flapMap 은 fn 을 매개변수로 받아서 => 뒤의 부분을 리턴
// R.chain 의 매개변수가 1개일때는 아래처럼 동작
const flapMap = (fn) => R.pipe(
    R.map(fn),
    R.flatten
)

const unnest = flapMap(R.identity);

R.pipe(
    unnest,
    R.tap(n => console.log(n))  // [ 1, 2, 3 ]
)(array);
```

아래 코드는 [Typescript - ramda 라이브러리 (1)](https://assu10.github.io/dev/2021/09/29/typescript-ramda-library/) 의 *5.4. `R.ifElse` 함수* 에서 본 `R.ifElse` 함수를 사용한 예시이다.<br />
(최소 5,000 원 어치 상품은 사면 500원을 할인)
```ts
import * as R from 'ramda'

type NumberToNumFunc = (n: number) => number;

const applyDiscount = (minimum: number, discount: number): NumberToNumFunc =>
    R.pipe(
        R.ifElse(
            R.flip(R.gte)(minimum),
            R.flip(R.subtract)(discount),
            R.identity
        ),
        R.tap(amount => console.log(amount))
    );
const calcPrice = applyDiscount(5000, 500);

const discountedPrice = calcPrice(6000);    // 5500
const notDiscountedPrice = calcPrice(4500); // 4500
```

---

### 5.5. `R.always` 조합자

이 내용은 각자 찾아보세요.

---

### 5.6. `R.applyTo` 조합자

`R.applyTo` 조합자는 값을 첫 번째 매개변수로, 그리고 이 값을 입력으로 하는 콜백 함수를 두 번째 매개변수로 받아 아래 코드처럼 동작한다.
```ts
const applyTo = value => cb => cb(value);
```

```ts
import * as R from 'ramda'

// 함수 T 는 value 값을 첫 번째 매개변수로 받는 2차 고차함수
const T = value => R.pipe(
    R.applyTo(value),
    R.tap(value => console.log(value))
);

// value100 은 첫 번째 매개변수에 100을 대입해서 만든 1차 함수로 R.identity 처럼 매개변수가 한 개인 콜백함수를 입력받을 수 있음
const value100 = T(100);

const sameValue = value100(R.identity);    // 100
const add1Value = value100(R.add(1));   // 101
```

---

### 5.7. `R.ap` 조합자

`R.ap` 조합자는 콜백 함수들의 배열을 첫 번째 매개변수로, 배열을 두 번째 매개변수로 받는 2차 고차 함수이다.
```ts
const ap = ([콜백 함수]) => 배열 => [콜백 함수](배열)
```

`R.ap` 는 콜백 함수가 1개일 때는 마치 `R.map` 함수처럼 동작한다.
```ts
import * as R from 'ramda'

// 콜백 함수가 1개일 때

const callAndAppend = R.pipe(
    R.ap([R.multiply(2)]),
    R.tap(a => console.log(a))
);

const input = [1,2,3];
const result = callAndAppend(input);    // [ 2, 4, 6 ]
```

만일 콜백 함수가 2개일 때는 마치 앞의 *5.2. `R.chain` 함수* 에서 본 것처럼 `R.chain(n => [n, n])` 처럼 동작한다.

*5.2. `R.chain` 함수* 에서 본 것처럼 `R.chain(n => [n, n])`
```ts
import * as R from 'ramda'

const array = [1, 2, 3];

// 매개변수가 1개 일 때
R.pipe(
    R.chain(n => [n, n]),
    R.tap(n => console.log(n))  // [ 1, 1, 2, 2, 3, 3 ]
)(array);
```


```ts
import * as R from 'ramda'

// 콜백 함수가 2개일 때
const callAndAppend2 = R.pipe(
    R.ap([R.multiply(2), R.add(10)]),
    R.tap(a => console.log(a))
);
const input2 = [1,2,3];
const result2 = callAndAppend2(input2);  // [ 2, 4, 6, 11, 12, 13 ]
```

아래는 `R.ap` 조합자의 이런 성질을 이용하여 [1, 2, 3] 배열을 세 번 복제 후 통합한 배열을 만드는 코드이다.
```ts
import * as R from 'ramda'

const repeat = (n, cb) => R.range(1, n+1).map(n => cb);

const callAndAppend = R.pipe(
    R.ap(repeat(3, R.identity)),
    R.tap(a => console.log(a))
);

const input = [1,2,3];
const result = callAndAppend(input);    // [1, 2, 3, 1, 2, 3, 1, 2, 3]
```

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)
* [Ramda Documentation](https://ramdajs.com/docs/) (함수를 알파벳 순서로 분류)
* [Ramda Documentation-DevDocs](https://devdocs.io/ramda/) (함수를 기능 위주로 분류)