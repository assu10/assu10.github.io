---
layout: post
title:  "Typescript - 빅데이터 배치 프로그램"
date:   2021-10-03 10:00
categories: dev
tags: typescript
categories: dev
---

이 포스팅은 빅데이터 배치 프로그램을 만들어볼 것이다.<br />
50만건의 가짜 데이터를 csv 파일 포맷으로 저장한 뒤, 이를 다시 읽어내는 프로그램을 구현할 것이다.
node.js 환경에서 CSV 파일 형식의 데이터를 MySQL 이나 PostgreSQL 과 같은 데이터베이스 시스템에 batch 작업으로 데이터를 저장할 때 유용하다.

*소스는 [assu10/typescript.git](https://github.com/assu10/typescript.git) 에 있습니다.*

> - 프로젝트 구성
> - CSV 파일과 생성기
> - node.js 에서 프로그램 명령 줄 인수 읽기
> - 파일 처리 비동기 함수를 프로미스로 구현
>   - `fs.access` API 로 디렉터리와 파일 확인
>   - `mkdirp` 패키지로 디렉터리 생성 함수 생성
>   - `rimraf` 패키지로 디렉터리 삭제 함수 생성
>   - `fs.writeFile` API 로 파일 생성
>   - `fs.readFile` API 로 파일 내용 읽기
>   - `fs.appendFile` API 로 파일에 내용 추가
>   - `fs.unlink` API 로 파일 삭제
>   - src/fileApi/index.ts 파일 생성
> - 가짜 데이터 생성
> - `Object.keys` 와 `Object.values` 함수 사용
> - CSV 파일 생성
> - 데이터를 CSV 파일에 쓰기
> - zip 함수 생성
> - 생성기 코드 구현 시 주의점
> - CSV 파일 데이터 읽기


아래와 같은 순서로 진행 예정이다.
- node.js 의 fs 패키지가 제공하는 비동기 방식 API 들의 Promise 방식 구현
- range, zip 같은 유틸리티 함수 구현
- chance 패키지를 사용해 그럴듯한 가짜 데이터 생성 코드 구현
- CSV 파일 포맷 데이터를 읽고 쓰는 코드 구현

---

## 1. 프로젝트 구성

```shell
> npm init --y
> npm i mkdirp rimraf chance
> npm i -D typescript ts-node @types/node @types/mkdirp @types/rimraf @types/chance
> tsc --init
> mkdir -p src/fileApi
> mkdir src/fake
> mkdir src/csv
> mkdir src/utils
> mkdir src/test
```

`mkdirp` 은 디렉터리를 생성하는 패키지이고, `rimraf` 는 디렉터리를 삭제하는 기능이다.

package.json
```json
{
  "name": "chap12-big-data-batch",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1",
    "dev": "ts-node src",
    "build": "tsc && node dist"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "chance": "^1.1.8",
    "mkdirp": "^1.0.4",
    "rimraf": "^3.0.2"
  },
  "devDependencies": {
    "@types/chance": "^1.1.3",
    "@types/mkdirp": "^1.0.2",
    "@types/node": "^16.10.2",
    "@types/rimraf": "^3.0.2",
    "ts-node": "^10.2.1",
    "typescript": "^4.4.3"
  }
}
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
    "downlevelIteration": true,
    "strict": true,
    "noImplicitAny": false,
    "strictNullChecks": false,
    "paths": { "*": ["node_modules/*"] }
  },
  "include": ["src/**/*"]
}
```

---

## 2. CSV 파일과 생성기

자바스크립트나 타입스크립트는 파일에 데이터를 저장할 때 JSON 포맷을 많이 사용하는데 저장할 데이터의 분량이 많아지면 JSON 파일 포맷은 시스템 메모리를 많이 사용한다.<br />
예를 들어 50만 건의 데이터가 담긴 JSON 파일 포맷은 물리적인 구조상 이 데이터를 한꺼번에 읽어들여야 하므로 시스템 메모리를 많이 사용한다.

CSV 파일 형식은 맨 첫 줄을 읽어 쉼표로 구분된 항목의 의미를 파악한 다음, 파일의 끝까지 한 줄씩 계속 데이터를 읽어서 시스템 자원을 적게 소비한다.

[Typescript - 반복기, 생성기](https://assu10.github.io/dev/2021/09/22/typescript-iterator-generator/) 의 *2. 생성기 (`generator`)* 에서 설명한 **생성기**는
시스템 자원을 매우 적게 소모하면서도 엄청량 분량의 데이터를 처리할 수 있다.<br />
예를 들어 50만 건의 데이터가 담긴 CSV 파일을 읽을 때는 한꺼번에 읽지 않고 한 줄씩 읽고, 읽은 데이터를 타입스크립트 객체로 변환한 후 `yield` 문으로 `for...of` 문에 넘겨주면
생성기가 전달한 객체 한 개를 대상으로만 작업을 진행한다.

---

## 3. node.js 에서 프로그램 명령 줄 인수 읽기

프로그램을 실행할 때 외부에서 입력된 값을 **명령 줄 인수 (command line arguments)** 라고 한다.

node.js 에서는 `process` 라는 내장 객체를 제공하는데 프로그램의 명령 줄 인수는 이 객체의 `argv` 배열 속성에서 얻을 수 있다.

```ts
process.argv.forEach((val: string, index: number) => {
    console.log(index + ': ', val);
});
```

```shell
> ts-node src/index.ts data/aa.csv 500000
0:  /usr/local/bin/ts-node
1:  /Users/assu/myhome/02_Study/03_typescript/mytypescript/chap12-big-data-batch/src/index.ts
2:  data/aa.csv
3:  500000
```

src/utils/getFileNameAndNumber.ts
```ts
export type FileNameAndNumber = [string, number];

export const getFileNameAndNumber = (defaultFilename: string, defaultNumberOfFakeData: number): FileNameAndNumber => {
    const [bin, node, filename, numberOfFakeData] = process.argv;
    return [filename || defaultFilename, numberOfFakeData ? parseInt(numberOfFakeData, 10) : defaultNumberOfFakeData];
};

const [filename, numberOfFakeItems] = getFileNameAndNumber('data/fake.csv', 500000);
console.log(filename, numberOfFakeItems);
```

```shell
> ts-node src/utils/getFileNameAndNumber.ts data/fake2.csv 500001
data/fake2.csv 500001
```

---

## 4. 파일 처리 비동기 함수를 프로미스로 구현

### 4.1. `fs.access` API 로 디렉터리와 파일 확인

`fs.access` - 파일이나 디렉터리가 현재 있는지 확인

아래는 `fs.access` 함수를 사용하여 파일이나 디렉터리가 있는지 확인하는 코드를 프로미스 형태로 구현한 것이다.

src/fileApi/fileExists.ts
```ts
import * as fs from "fs";

export const fileExists = (filepath: string): Promise<boolean> =>
    new Promise<boolean>(resolve => fs.access(filepath, error => resolve(error ? false : true)));

const exist = async(filepath) => {
    const result = await fileExists(filepath);
    console.log(`${filepath} ${result ? 'exists': 'not exits'}`);
};

exist('./package.json');    // ./package.json exists
exist('./package'); // ./package not exits
```

node.js 에서는 package.json 파일이 있는 위치가 현재 디렉터리이다.

---

### 4.2. `mkdirp` 패키지로 디렉터리 생성 함수 생성

node.js 는 `mkdir` 이라는 API 를 제공하는데 이 API 는 './src/aaa/bbb' 와 같은 여러 경로의 디렉터리를 한번에 만들지 못한다.

`mkdirp` 는 여러 디렉터리를 한번에 만드는 명령인 `mkdir -p` 처럼 동작하는 API 를 제공한다.

아래는 디렉터리가 있는지 판단하여 없을 때만 `mkdirp` 함수로 디렉터리를 생성한다.

src/fileApi/mkdir.ts
```ts
import mkdirp from 'mkdirp'
import {fileExists} from "./fileExists";

// .then(resolve) 에서 아래와 같은 오류가 나면 tsconfig.json 의 "strictNullChecks": false 설정
// TS2345: Argument of type '(value: string | PromiseLike<string>) => void'
//   is not assignable to parameter of type '(value: string | undefined) => void | PromiseLike<void>'.
export const mkdir = (dirname: string): Promise<string> =>
    new Promise(async (resolve, reject) => {
        const alreadyExists = await fileExists(dirname);
        alreadyExists ? resolve(dirname) : mkdirp(dirname).then(resolve).catch(reject);
    });

const makeDataDir = async (dirname: string) => {
    let result = await mkdir(dirname);
    console.log(`${result} dir created.`);  // /Users/mytypescript/chap12-big-data-batch/data dir created.
}

makeDataDir('./data/today');
```

> .then(resolve) 에서 아래와 같은 오류 발생 시 tsconfig.json 의 "strictNullChecks": false 설정<br /><br />
> TS2345: Argument of type '(value: string | PromiseLike<string>) => void'
>   is not assignable to parameter of type '(value: string | undefined) => void | PromiseLike<void>'.

---

### 4.3. `rimraf` 패키지로 디렉터리 삭제 함수 생성

node.js 는 `fs.rmdir` 함수를 제공하지만 이 함수는 비어있지 않은 디렉터리는 삭제하지 못한다.

`rimraf` 패키지를 이용하면 비어있지 않은 디렉터리도 삭제가 가능하다.

src/fileApi/rmdir.ts
```ts
import rimraf from "rimraf";
import {fileExists} from "./fileExists";

export const rmdir = (dirname: string): Promise<string> =>
    new Promise<string>(async (resolve, reject) => {
        const alreadyExists = await fileExists(dirname);
        !alreadyExists ? resolve(dirname) :
            rimraf(dirname, error => error ? reject(error) : resolve(dirname));
    });

const deleteDataDir = async (dir) => {
    const result = await rmdir(dir);
    console.log(`${result} dir deleted.`);  // ./data/today dir deleted.
}
deleteDataDir('./data/today');      // today 디렉터리 삭제
```

---

### 4.4. `fs.writeFile` API 로 파일 생성

node.js 환경에서 파일의 데이터를 읽거나 쓸 때는 대부분 text 데이터를 대상으로 하는데 이 때 그 데이터는 유니코드로 처리해야 한다.

```ts
fs.writeFile(filepath, data, 'utf8', callback)
```

src/fileApi/writeFile.ts
```ts
import * as fs from "fs";
import {mkdir} from "./mkdir";

export const writeFile = (filename: string, data: any): Promise<any> =>
    new Promise<any>((resolve, reject) => {
        fs.writeFile(filename, data, 'utf8', (error: Error) => {
            error? reject(error) : resolve(data);
        })
    });

const writeTest = async (filename: string, data: any) => {
    const result = await writeFile(filename, data);
    console.log(`write ${result} to ${filename}`);
};

mkdir('./data')
    .then(s => writeTest('./data/hello.txt', 'hello world!'))
    .then(s => writeTest('./data/test.json', JSON.stringify({name: 'assu', age: 20}, null, 2)))
    .catch((e: Error) => console.log(e.message));

/*
write hello world! to ./data/hello.txt
write {
    "name": "assu",
        "age": 20
} to ./data/test.json
*/
```

타입스크립트나 자바스크립트는 객체 object 를 `JSON.stringify(object)` 를 통해 JSON 문자열로 바꿔준다.
사람이 좀 더 읽기 편한 형식으로는 `JSON.stringify(object, null, 2)` 로 사용하면 된다. 숫자 2는 들여쓰기를 위해 공백문자 2개를 사용하라는 의미이다. 

---

### 4.5. `fs.readFile` API 로 파일 내용 읽기

파일에 담긴 데이터를 읽을 때는 `fs.readFile` API 를 사용한다.

파일에 담긴 데이터는 텍스트 포맷으로 읽을 수도 있고, 바이너리 포맷으로 읽을 수도 있다.<br />
텍스트 포맷은 텍스트가 영문으로만 이루어졌다고 가정하는 **ANSI 포맷**과 비영어권 문자도 있다고 가정하는 **유니코드 포맷** 두 가지가 존재한다.<br />
그리고 **유니코드 포맷**은 ANSI 문자열 체계를 확장한 utf8 포맷과 원래의 유니코드 포맷 두 가지가 있다.

node.js 에서 파일의 데이터를 읽거나 쓸 때는 기본으로 utf8 포맷을 사용한다.

```ts
fs.readFile(filepath, 'utf8', callback)
```

src/fileApi/readFile.ts
```ts
import * as fs from "fs";

export const readFile = (filename: string): Promise<any> =>
    new Promise<any>((resolve, reject) => {
        fs.readFile(filename, 'utf8', (e: Error, data: any) => {
            e ? reject(e) : resolve(data);
        })
    });

const readTest = async (filename: string) => {
    const result = await readFile(filename);
    console.log(`read ${result} from ${filename} file.`);
};

readTest('./data/hello.txt')
    .then(s => readTest('./data/test.json'))
    .catch((e: Error) => console.log(e.message));
/*
read hello world! from ./data/hello.txt file.
    read {
    "name": "assu",
        "age": 20
} from ./data/test.json file.
*/
```

---

### 4.6. `fs.appendFile` API 로 파일에 내용 추가

`fs.writeFile` 은 파일이 이미 존재하면 기존 파일 내용을 모두 지우고 새로운 데이터를 쓴다.

기존 내용을 보존하면서 새로운 데이터를 파일 끝에 삽입할 때는 `fs.appendFile` API 를 이용한다.

```ts
fs.appendFile(filepath, data, 'utf8', callback)
```

src/fileApi/appendFile.ts
```ts
import * as fs from "fs";
import {mkdir} from "./mkdir";

export const appendFile = (filename: string, data: any): Promise<any> =>
    new Promise<any>((resolve, reject) => {
        fs.appendFile(filename, data, 'utf8', (error: Error) => {
            error ? reject(error) : resolve(data)
        })
    });

const appendTest = async (filename: string, data: any) => {
    const result = await appendFile(filename, data);
    console.log(`append ${result} to ${filename}`);
};

mkdir('./data')
    .then(s => appendTest('./data/hello.txt', '\nhi, there'))
    .catch((e: Error) => console.log(e.message));
/*
append
hi, there to ./data/hello.txt
*/
```

---

### 4.7. `fs.unlink` API 로 파일 삭제

`fs.unlink` 는 파일을 삭제하는 API 이다.

```ts
fs.unlink(filepath, callback)
```

src/fileApi/deleteFile.ts
```ts
import {fileExists} from "./fileExists";
import * as fs from "fs";
import {rmdir} from "./rmdir";

export const deleteFile = (filename: string): Promise<string> =>
    new Promise<string>(async (resolve, reject) => {
        const alreadyExists = await fileExists(filename);
        !alreadyExists ? resolve(filename) :
            fs.unlink(filename, (error: Error) => error ? reject(error) : resolve(filename));
    });

const deleteTest = async (filename: string) => {
    const result = await deleteFile(filename);
    console.log(`delete ${result} file.`);
}

Promise.all([deleteTest('./data/hello.txt'), deleteTest('./data/test.json')])
    .then(s => rmdir('./data'))
    .then(dirname => console.log(`delete ${dirname} dir`))
    .catch((e: Error) => console.log(e.message));
/*
delete ./data/hello.txt file.
    delete ./data/test.json file.
    delete ./data dir
*/
```

> Promise.all 은 [Typescript - Promise, async/await](https://assu10.github.io/dev/2021/09/26/typescript-promise-async-await/) 의 *2.4. `Promise.all` 메서드* 와 *3.6. async 함수와 `Promise.all`* 을 참고하세요.

---

### 4.8. src/fileApi/index.ts 파일 생성

앞에서 만든 기능들을 모두 export 해주는 파일을 만든다. 이 파일을 앞으로 src/fileApi 디렉터리의 함수들을 아래처럼 사용할 수 있도록 해준다.

```ts
import {fileExists, mkdir, rmdir} from './src/fileApi'
```

src/fileApi/index.ts
```ts
import {fileExists} from './fileExists'
import {mkdir} from './mkdir'
import {rmdir} from './rmdir'
import {writeFile} from './writeFile'
import {readFile} from './readFile'
import {appendFile} from './appendFile'
import {deleteFile} from './deleteFile'

export {fileExists, mkdir, rmdir, writeFile, readFile, appendFile, deleteFile}
```

---

## 5. 가짜 데이터 생성

`chance` 패키지를 사용하여 가짜 데이터를 만든다.

*IFake* 라는 인터페이스를 만들고 이름, 이메일 주소, 간단한 프로필(sentence) 등을 속성으로 포함한다.

src/fake/IFake.ts
```ts
export interface IFake {
    name: string,
    email: string,
    sentence: string,
    profession: string,
    birthday: Date
}
```

이제 *IFake* 형태의 데이터를 만들자.

src/fake/makeFakeData.ts
```ts
import Chance from 'chance'
import {IFake} from "./IFake";

const c = new Chance();
export const makeFakeData = (): IFake => ({
    name: c.name(),
    email: c.email(),
    profession: c.profession(),
    birthday: c.birthday(),
    sentence: c.sentence()
});

export { IFake }
```

사용하는 법은 아래와 같다.

src/test/makeFakeData-test.ts
```ts
import {makeFakeData, IFake} from "../fake/makeFakeData";

const fakeData: IFake = makeFakeData();
console.log(fakeData);
/*
{
    name: 'Ida Fuller',
        email: 'nap@huc.sv',
    profession: 'City Manager',
    birthday: 1967-02-12T00:30:53.300Z,
    sentence: 'Li po vevmad getire modde lu fekural ig if fimo wocef kisodcil famateme.'
}
*/
```

src/fake/index.ts
```ts
import {IFake, makeFakeData} from './makeFakeData'
export {IFake, makeFakeData }
```

이제 이렇게 만들어진 가짜 데이터를 CSV 파일에 쓸 차례인데 이를 위해서는 한 가지 먼저 만들어둬야 할 함수가 있다.

---

## 6. `Object.keys` 와 `Object.values` 함수 사용

CSV 파일을 만드려면 객체의 속성과 값을 분리해야 하는데 자바스크립트는 이를 위해 `Object.keys` 와 `Object.values` 함수를 제공한다.

src/test/keys-values-test.ts
```ts
import {IFake, makeFakeData} from "../fake";

const data: IFake = makeFakeData();
const keys = Object.keys(data);
console.log(keys);  // [ 'name', 'email', 'profession', 'birthday', 'sentence' ]

const values = Object.values(data);
console.log(values);
// ['Leah Ortega', 'tuglu@tuji.sj', 'Production Engineer', 1967-11-01T01:45:26.062Z,
// 'Se unuijogo kuweju cipa lazeuf samew guv jet cejzah vorol linrejvo pe ti.']
```

---

## 7. CSV 파일 생성

이제 가짜 데이터를 여러 개 생성하여 CSV 파일에 써보자.

src/utils/range.ts
```ts
export function* range(max: number, min: number = 0) {
    while (min < max) {
        yield min++;
    }
}
```

src/utils/index.ts
```ts
import {getFileNameAndNumber, FileNameAndNumber} from './getFileNameAndNumber'
import {range} from './range'

export {getFileNameAndNumber, FileNameAndNumber, range}
```

> 생성기 `function*` 은 [Typescript - 반복기, 생성기](https://assu10.github.io/dev/2021/09/22/typescript-iterator-generator/) 의 *2. 생성기 (`generator`)* 를 참고하세요.

이제 *makeFakeData* 를 사용하여 numberOfItems 만큼 *IFake* 객체를 생성하고, 속성명과 속성값의 배열을 각각 추출하여 filename 파일을 만든다.

src/fake/writeCsvFakeData.ts
```ts
import path from "path";
import {IFake, makeFakeData} from './makeFakeData'
import { mkdir, writeFile, appendFile } from '../fileApi'
import {range} from "../utils";

export const writeCsvFormatFakeData = async (filename: string, numberOfItems: number): Promise<string> => {
    const dirname = path.dirname(filename);
    console.log('dirname: ', dirname);
    await mkdir(dirname);

    const comma = ',';
    const newLine = '\n';

    for (let n of range(numberOfItems)) {
        const fake: IFake = makeFakeData();
        if (n == 0) {
            const keys = Object.keys(fake).join(comma);
            await writeFile(filename, keys);
        }
        const values = Object.values(fake).join(comma);
        await appendFile(filename, newLine + values);
    }
    return `write ${numberOfItems} items to ${filename} file.`
}
```
 
src/fake/index.ts
```ts
import {IFake, makeFakeData} from './makeFakeData'
import {writeCsvFormatFakeData } from './writeCsvFormatFakeData'
export {IFake, makeFakeData, writeCsvFormatFakeData }
```

---

## 8. 데이터를 CSV 파일에 쓰기

이제 CSV 포맷으로 *IFake* 타입 객체를 저장하는 기능을 만들도록 한다.

src/writeCsv.ts
```ts
import {getFileNameAndNumber} from "./utils";
import {writeCsvFormatFakeData} from "./fake";

const [filename2, numberOfFakeData2] = getFileNameAndNumber('./data/fake', 100000);
const csvFilename = `${filename2}-${numberOfFakeData2}.csv`;

writeCsvFormatFakeData(csvFilename, numberOfFakeData2)
    .then(result => console.log(result))
    .catch((e: Error) => console.log(e.message));
// write 1 items to ./data/fake-1.csv file.
```

```ts
> ts-node src/writeCsv.ts
> ts-node src/writeCsv.ts data/fake 10
```

---

## 9. zip 함수 생성

이제 CSV 포맷 파일을 읽는 코드를 작성하자.

CSV 파일은 첫 줄에 객체의 속성명들이 있고, 두 번째 줄부터는 속성값들만 있기 때문에 객체의 속성명 배열과 속성값 배열을 결합하여 객체를 만드는 함수가 필요하다.

이런 기능을 하는 함수는 보통 **zip** 이라는 이름으로 구현한다.

src/utils/zip.ts
```ts
export const zip = (keys: string[], values: any[]): object => {
    const makeObject = (key: string, value: any) => ({[key]: value});
    const mergeObject = (a: any[]) => a.reduce((accu, val) => ({...accu, ...val}), {});

    let tmp = keys.map((key: string, index: number) => [key, values[index]])
        .filter(a => a[0] && a[1])
        .map(a => makeObject(a[0], a[1]));
    return mergeObject(tmp);
}
```

src/utils/index.ts
```ts
import {getFileNameAndNumber, FileNameAndNumber} from './getFileNameAndNumber'
import {range} from './range'
import {zip} from './zip'

export {getFileNameAndNumber, FileNameAndNumber, range, zip}
```

위에서 만든 zip 함수에 대한 테스트 코드를 작성해보자.

아래는 makeFakeData 를 호출해 가짜 데이터를 만든 다음 Object.keys 와 Object.values 를 각각 호출해 속성명 배열과 속성값 배열을 만든다.
그리고 zip 를 이용해 다시 가짜 데이터를 IFake 타입 객체로 만든다.

src/test/zip-test.ts
```ts
import {IFake, makeFakeData} from "../fake";
import {zip} from "../utils";

const data = makeFakeData();
const keys = Object.keys(data), values = Object.values(data);

const fake: IFake = zip(keys, values) as IFake;

console.log(data);
console.log(fake);
/*
{
    name: 'Gerald Carter',
        email: 'mu@og.bn',
    profession: 'Fast Food Manager',
    birthday: 1965-11-04T17:29:29.370Z,
    sentence: 'Zogtuvvu zotrajni kewi ki tecros mozub wuw gi si lel azafule sah.'
}
{
    name: 'Gerald Carter',
        email: 'mu@og.bn',
    profession: 'Fast Food Manager',
    birthday: 1965-11-04T17:29:29.370Z,
    sentence: 'Zogtuvvu zotrajni kewi ki tecros mozub wuw gi si lel azafule sah.'
}
*/
```

---

## 10. 생성기 코드 구현 시 주의점

아래 코드를 보자.

```ts
import {readFile} from '../fileApi'
import * as fs from "fs";

function* readFileGen() {
    yield 1;
    fs.readFile('./package.json', (err: Error, data: any) => {
        yield data; // TS1163: A 'yield' expression is only allowed in a generator body.
    })
}
```

yield 가 총 2 군데 있는데 *yield data* 는 fs.readFile 의 콜백 함수 내부에 있다.
즉, 생성기 본문에 있지 않다.

생성기를 구현할 때는 fs.readFile 과 같은 비동기 함수를 사용할 수 없다.

---

## 11. CSV 파일 데이터 읽기

위에서 본 것처럼 파일 읽기는 '생성기 방식' 으로 구현할 때 `fs.readFile` 을 사용하지 못하기 때문에 '그냥' `fs.readFile` 을 이용하는 방법을 생각해볼 수 있다.

하지만 `fs.readFile` 을 이용하면 시스템 메모리를 많이 사용하는 문제가 발생한다. 즉, `fs.readFile` 의 물리적인 동작을 고려할 때 엄청난 용량의 데이터가 담겨 있을지도 모르는
CSV 파일을 한꺼번에 읽는 것은 바람직하지 못하다.

결론적으로 파일을 한 줄씩 읽는 방식으로 생성기를 구현해야 한다.

아래는 1,024 Byte 의 Buffer 타입 객체를 생성하여 파일을 1,024 Byte 씩 읽으면서 한 줄씩 찾은 후, 찾을 줄 (=\n 으로 끝난 줄) 의 데이터를 yield 문으로 발생시키는 예시이다.

src/fileApi/readFileGenerator.ts
```ts
import * as fs from "fs";

export function* readFileGenerator(filename: string): any {
    let fd: any;

    try {
        fd = fs.openSync(filename, 'rs');   // rs: 동기 모드를 사용하여 파일을 열고 읽습니다. 운영 체제가 로컬 파일 시스템 캐시를 무시하도록 지시합니다.
        const stats = fs.fstatSync(fd); // Getting information for a file or directory
        // Using methods of the Stats object
        console.log("Path is file:", stats.isFile());
        console.log("Path is directory:", stats.isDirectory());

        const bufferSize = Math.min(stats.size, 1024);
        const buffer = Buffer.alloc(bufferSize + 4);
        let filepos = 0;
        let line: string;

        while (filepos > -1) {
            [line, filepos] = readLine(fd, buffer, bufferSize, filepos);
            if (filepos > -1) {
                yield line;
            }
        }
        yield  buffer.toString();   // yield last line (마지막 줄)
    } catch (e) {
        console.error('readline:', e);
    } finally {
        fd && fs.closeSync(fd);
    }
}

function readLine (fd: any, buffer: Buffer, bufferSize: number, position: number): [string, number] {
    let line = '';
    let readSize;
    const crSize = '\n'.length;
    console.log('crSize: ', crSize);

    while (true) {
        readSize = fs.readSync(fd, buffer, 0, bufferSize, position);
        if (readSize > 0) {
            const tmp = buffer.toString('utf8', 0, readSize);
            const index = tmp.indexOf('\n');
            if (index > -1) {
                line += tmp.substr(0, index);
                position += index + crSize;
                break;
            } else {
                line += tmp;
                position += tmp.length;
            }
        } else {
            position = -1;  // end of file
            break;
        }
    }
    return [line.trim(), position];
}
```

src/fileApi/index.ts
```ts
import {fileExists} from './fileExists'
import {mkdir} from './mkdir'
import {rmdir} from './rmdir'
import {writeFile} from './writeFile'
import {readFile} from './readFile'
import {appendFile} from './appendFile'
import {deleteFile} from './deleteFile'
import {readFileGenerator} from './readFileGenerator'

export {fileExists, mkdir, rmdir, writeFile, readFile, appendFile, deleteFile, readFileGenerator}
```

실제로 CSV 파일을 잘 읽는지 확인해보자.

src/test/readFileGenerator-test.ts
```ts
import {readFileGenerator} from "../fileApi";

for (let value of readFileGenerator('data/fake-10.csv')) {
    console.log('<line>', value, '</line>\n');
}
/*
<line> name,email,profession,birthday,sentence </line>

<line> Carrie Lloyd,hewfuc@or.mu,Aerospace Engineer,Sun Jul 15 2001 16:21:59 GMT+0900 (Korean Standard Time),Nu comwa comu maw pez wukibuz ul dollasek sujo sof ohizuz vab oza. </line>
*/
```

*readFileGenerator* 는 단순히 파일을 한 줄 한 줄 읽는다.

이번엔 CSV 파일을 해석하면서 읽는 코드를 만들어보자.

src/csv/csvFileReaderGenerator.ts
```ts
import {readFileGenerator} from "../fileApi";
import {zip} from "../utils";

export function* csvFileReaderGenerator(filename: string, delim: string = ',') {
    let header: string[] = [];
    for (let line of readFileGenerator(filename)) {
        if (!header.length) {
            header = line.split(delim);
        } else {
            yield zip(header, line.split(delim));
        }
    }
}
```

src/readCsv.ts
```ts
import {getFileNameAndNumber} from "./utils";
import {csvFileReaderGenerator} from "./csv/csvFileReaderGenerator";

const [filename] = getFileNameAndNumber('./data/fake-100000.csv', 1);

let line = 1;
for (let object of csvFileReaderGenerator(filename)) {
    console.log(`[${line++}] ${JSON.stringify(object)}`);
}
console.log('\n read completed.');

/*
[99999] {"name":"Harry Morris","email":"werfuksot@tuhho.zw","profession":"Payroll Specialist","birthday":"Fri Aug 01 1969 02:41:44 GMT+0900 (Korean Standard Time)","sentence":"Wum nipwilas witgok asa uge nopotwi korjor lic ludhocmik fasawohek owu de."}
[100000] {"name":"Myra Schultz","email":"labjal@anagawu.uy","profession":"Traffic Manager","birthday":"Fri Mar 18 1983 23:27:21 GMT+0900 (Korean Standard Time)","sentence":"Gi cubessod wagkif dakim osiwikkiw kurogtun do jihdonfi ra ibsa kowarov fahe dewwow ma kuju.labjal@anagawu.uy"}

read completed.
*/
```

시스템 자원을 거의 소비하지 않으면서 이와 같은 대용량 데이터를 처리할 수 있게 하는 것이 생성기의 진정한 위력이다.

---

*본 포스트는 전예홍 저자의 **Do it! 타입스크립트 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Do it! 타입스크립트 프로그래밍](http://easyspub.co.kr/20_Menu/BookView/367/PUB0)