---
layout: post
title:  "eslint/prettier 셋팅 + Node.js - 기본 개념 (1): 내장 객체, 내장 모듈, util"
date: 2021-10-04 10:00
categories: dev
tags: nodejs
---

이 포스트는 노드가 기본적으로 제공하는 객체와 모듈 사용법에 대해 알아본다.<br />
모듈을 사용하면서 버퍼와 스트림, 동기와 비동기, 이벤트, 예외 처리에 대해서도 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - eslint 설정
> - REPL 사용
> - 모듈 생성
> - 노드 내장 객체
>   - global
>   - console
>   - console
>   - `__filename`, `__dirname`
>   - module, exports, require
>   - `process`
> - 노드 내장 모듈 사용
>   - `os`
>   - `path`
>   - `url`
>   - `querystring`
>   - `crypto`
> - util

---

# eslint 설정

```shell
> npm i -D eslint
> npm i -D prettier --save-exact
> npm i -D eslint-config-prettier eslint-plugin-prettier
> ./node_modules/.bin/eslint --init
✔ How would you like to use ESLint? · problems
✔ What type of modules does your project use? · esm
✔ Which framework does your project use? · none
✔ Does your project use TypeScript? · No / Yes
✔ Where does your code run? · browser
✔ What format do you want your config file to be in? · JSON
```

- `--save-exact` 는 버전이 달라지면서 생길 스타일의 변화를 막아주는 역할을 한다.
- `eslint-config-prettier` 는 Prettier 와 충돌할 설정들을 비활성화 한다.
- `eslint-plugin-prettier` 는 코드 포맷 시 Prettier 를 사용하게 만드는 규칙을 추가한다.

package.json
```json
  "devDependencies": {
    "eslint": "^8.0.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-prettier": "^4.0.0",
    "prettier": "2.4.1"
  }
```

.eslintrc.json
```json
{
  "env": {
    "browser": true,
    "es2021": true,
    "node": true
  },
  "extends": ["eslint:recommended", "plugin:prettier/recommended"],
  "parserOptions": {
    "ecmaVersion": 13,
    "sourceType": "module"
  },
  "rules": {
  }
}
```

.prettierrc.js
```js
module.exports = {
    singleQuote: true,
    // 문자열은 따옴표로 formatting
    semi: true,
    //코드 마지막에 세미콜른이 있게 formatting
    useTabs: false,
    //탭의 사용을 금하고 스페이스바 사용으로 대체하게 formatting
    tabWidth: 2,
    // 들여쓰기 너비는 2칸
    trailingComma: 'all',
    // 자세한 설명은 구글링이 짱이긴하나 객체나 배열 키:값 뒤에 항상 콤마를 붙히도록 	  	//formatting
    printWidth: 80,
    // 코드 한줄이 maximum 80칸
    arrowParens: 'avoid',
    // 화살표 함수가 하나의 매개변수를 받을 때 괄호를 생략하게 formatting
    endOfLine: "auto"
};
```

---

# 1. REPL 사용

입력한 코드를 읽고 (Read), 해석하고 (Eval), 결과물을 반환하고 (Print), 종료할 때까지 반복 (Loop) 하는 것을 REPL 이라고 한다.

노드의 REPL 을 이용해보자.

콘솔창에서 *node* 라고 입력하면 노드의 REPL 을 이용할 수 있다.

```shell
> node  # 노드의 REPL
Welcome to Node.js v16.6.0.
Type ".help" for more information.

> const str = 'hello~'
undefined
> console.log(str)
hello~
undefined
>
```

---

# 2. 모듈 생성

노드는 코드를 모듈로 만들 수 있다는 점에서 브라우저의 자바스크립트와 다르다.

> 모듈<br />
> 특정한 기능을 하는 함수나 변수들의 집합


> 아래의 `require, module.exports` 는 ES2015 이전의 문법이다.<br />
> ES2015 버전의 문법은 `import, export default` 이다.
> 
> 노드 9 버전부터 ES2015 의 모듈 시스템을 사용할 수 있지만 파일 확장자를 mjs 로 지정해야 하는 제한이 있다.
> mjs 대신 js 확장자를 사용하려면 package.json 에서 type: "module" 속성을 추가하면 된다.

var.js
```js
const odd = "홀수";
const even = "짝수";

module.exports = {
  odd,
  even,
};
```

func.js
```js
const { odd, even } = require("./var");

function checkOddOrEven(num) {
  if (num % 2) {
    return odd;
  }
  return even;
}

module.exports = checkOddOrEven;
```

index.js (ES2015 이전 문법)
```js
const { odd, even } = require("./var");
const checkNumber = require("./func");

function checkStringOddOrEven(str) {
  if (str.length % 2) {
    return odd;
  }
  return even;
}

console.log(checkStringOddOrEven("hello"));
console.log(checkNumber(10));

module.exports = checkStringOddOrEven;
```

index.js (ES2015 이후 문법)
```js
import { even, odd } from "./var";
import checkNumber from "./func";

function checkStringOddOrEven(str) {
  if (str.length % 2) {
    return odd;
  }
  return even;
}

console.log(checkStringOddOrEven("hello"));
console.log(checkNumber(10));

export default checkStringOddOrEven;
```

```shell
> node index
홀수
짝수
```

---

# 3. 노드 내장 객체

## 3.1. global

브라우저의 window 와 같은 전역 객체이다. 전역 객체이므로 모든 파일에서 접근 가능하고, window.open 을 open 으로 사용할 수 있는 것처럼 global 로 생략이 가능하다.<br />
예) global.require 를 require 로 사용, global.console 을 console 로 사용

global 객체 내부에는 많은 속성들이 있는데 이 내부를 보려면 REPL 을 이용해야 한다.
```shell
node
Welcome to Node.js v16.6.0.
Type ".help" for more information.
> global
<ref *1> Object [global] {
  global: [Circular *1],
  clearInterval: [Function: clearInterval],
  clearTimeout: [Function: clearTimeout],
  setInterval: [Function: setInterval],
  setTimeout: [Function: setTimeout] {
    [Symbol(nodejs.util.promisify.custom)]: [Getter]
  },
  queueMicrotask: [Function: queueMicrotask],
  performance: Performance {
    nodeTiming: PerformanceNodeTiming {
      name: 'node',
      entryType: 'node',
      startTime: 0,
      duration: 2964.2559480667114,
      nodeStart: 3.1854209899902344,
      v8Start: 4.410906076431274,
      bootstrapComplete: 30.637053966522217,
      environment: 18.627029180526733,
      loopStart: 53.917073011398315,
      loopExit: -1,
      idleTime: 2883.690295
    },
    timeOrigin: 1633863509511.48
  },
  clearImmediate: [Function: clearImmediate],
  setImmediate: [Function: setImmediate] {
    [Symbol(nodejs.util.promisify.custom)]: [Getter]
  }
}

> global.console
Object [console] {
  log: [Function: log],
  warn: [Function: warn],
  dir: [Function: dir],
  time: [Function: time],
  timeEnd: [Function: timeEnd],
  timeLog: [Function: timeLog],
  trace: [Function: trace],
  assert: [Function: assert],
  clear: [Function: clear],
  count: [Function: count],
  countReset: [Function: countReset],
  group: [Function: group],
  groupEnd: [Function: groupEnd],
  table: [Function: table],
  debug: [Function: debug],
  info: [Function: info],
  dirxml: [Function: dirxml],
  error: [Function: error],
  groupCollapsed: [Function: groupCollapsed],
  Console: [Function: Console],
  profile: [Function: profile],
  profileEnd: [Function: profileEnd],
  timeStamp: [Function: timeStamp],
  context: [Function: context]
}
```

global 은 전역 객체라는 점을 이용하여 파일 간 간단한 데이터를 공유할 때 사용하기도 한다. 하지만 이를 남용하면 유지 보수에 어려움이 있으므로 다른 파일의 값을 사용할 때는 모듈 형식으로
만들어 명시적으로 값을 불러와서 사용하는 것이 좋다.

globalA.js
```js
module.exports = () => global.message;
```

globalB.js
```js
const A = require('./3.4.1-globalA');

global.message = '안녕하세요';
console.log(A());   // 안녕하세요.
```

---

## 3.2. console

- `console.time(레이블)`
    - `console.timeEnd(레이블)` 과 대응되어 같은 레이블을 가진 time 과 timeEnd 사이의 시간 측정
- `console.table(배열)`
    - 배열의 요소로 객체 리터럴을 넣으면 객체 속성들이 테이블 형식으로 표현됨
- `console.dir(객체, 옵션)`
    - 객체를 콘솔에 표시할 때 사용하는데 옵션에서 colors 를 true 로 하면 콘솔에 색이 추가되어 가독성이 높아지고, depth 의 숫자는 객체의 몇 단계까지 보여줄 지를 결정한다. (기본값 2)
- `console.trace(레이블)`
    - 에러가 어디서 발생했는지 추적 가능하게 해준다. 에러 위치가 나오지 않을 때 사용하면 유용하다.

console.js
```js
const str = 'abc';
const num = 1;
const bool = true;
const obj = {
  outside: {
    inside: {
      key: 'value',
    },
  },
};

console.time('전체시간');

console.log(str, num, bool);
console.error('이것은 에러');

console.table([
  { name: 'assu', age: 20 },
  { name: 'jhlee', age: 21 },
]);

console.dir(obj, { colors: false, depth: 2 });
console.dir(obj, { colors: true, depth: 1 });

console.time('시간측정');
for (let i = 0; i < 100000; i++) {}
console.timeEnd('시간측정');

function b() {
  console.trace('에러 위치 추적');
}

function a() {
  b();
}

a();

console.timeEnd('전체시간');
```

```shell
abc 1 true
이것은 에러
┌─────────┬─────────┬─────┐
│ (index) │  name   │ age │
├─────────┼─────────┼─────┤
│    0    │ 'assu'  │ 20  │
│    1    │ 'jhlee' │ 21  │
└─────────┴─────────┴─────┘
{ outside: { inside: { key: 'value' } } }
{ outside: { inside: [Object] } }
시간측정: 2.088ms
Trace: 에러 위치 추적
    at b (/Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src/console.js:30:11)
    at a (/Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src/console.js:34:3)
    at Object.<anonymous> (/Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src/console.js:37:1)
    at Module._compile (node:internal/modules/cjs/loader:1101:14)
    at Object.Module._extensions..js (node:internal/modules/cjs/loader:1153:10)
    at Module.load (node:internal/modules/cjs/loader:981:32)
    at Function.Module._load (node:internal/modules/cjs/loader:822:12)
    at Function.executeUserEntryPoint [as runMain] (node:internal/modules/run_main:79:12)
    at node:internal/main/run_main_module:17:47
전체시간: 12.097ms
```

---

## 3.3. 타이머

- `setTimeout(콜백, 밀리초)`
  - 주어진 ms 이후에 콜백 함수 실행
- `setInterval(콜백, 밀리초)`
  - 주어진 ms 마다 콜백 함수 실행
- `setImmediate(콜백)`
  - 콜백 함수 즉시 실행
  
위 타이머 함수들은 모두 아이디를 반환하는데 이 아이디를 사용하여 타이머를 취소할 수 있다.

- `clearTimeout(아이디)`
- `clearInterval(아이디)`
- `clearImmediate(아이디)`

timer.js
```js
setTimeout(() => {
  console.log('1.5 초후 실행');
}, 1500);

const interval = setInterval(() => {
  console.log('1초마다 실행');
});

const timeout2 = setTimeout(() => {
  console.log('실행되지 않음');
});

setTimeout(() => {
  clearTimeout(timeout2);
  clearInterval(interval);
}, 2500);

setImmediate(() => {
  console.log('즉시 실행');
});

const immediate2 = setImmediate(() => {
  console.log('실행되지 않습니다');
});

clearImmediate(immediate2);
```

> 파일 시스템 접근, 네트워킹 같은 I/O 작업의 콜백 함수 안에서 타이머를 호출하는 경우에는 `setImmediate(콜백)`가 `setTimeout(콜백, 0)` 보다 먼저 호출된다.<br />
> 헷갈리지 않도록 `setTimeout(콜백, 0)` 은 사용하지 않는 것을 권장한다.

---

## 3.4. `__filename`, `__dirname`

각각 현재의 파일명과 경로를 리턴한다.

```js
console.log(__filename); // /Users/myhome/02_Study/01_nodejs/mynode/chap03/src/index.js
console.log(__dirname); // /Users/myhome/02_Study/01_nodejs/mynode/chap03/src
```

경로 구분자의 경우 `\`, `/` 의 문제를 해결하기 위해 뒤의 *4.2. `path`* 에서 볼 path 모듈과 함께 쓴다.

---

## 3.5. module, exports, require

### 3.5.1. module, exports

지금까지 모듈을 생성할 때 `module.exports` 만 사용했는데 `module` 객체 말고 `exports` 객체로도 모듈을 생성할 수 있다.

*2. 모듈 생성* 의 *var.js* 를 아래처럼 수정해도 동일하게 *index.js* 에서 사용 가능하다.

```js
// var.js

/*
const odd = '홀수';
const even = '짝수';

module.exports = {
  odd,
  even,
};
*/
exports.odd = '홀수';
exports.even = '짝수';


//index.js

/*import { even, odd } from './3.1.1-var';
import checkNumber from './3.1.1-func';*/

const { odd, even } = require('./3.1.1-var');
const checkNumber = require('./3.1.1-func');
```

---

### 3.5.2. `require.cache`

여기선 `require` 함수의 `require.cache` 속성에 대해 알아본다.

require.js
```js
console.log('require 가 가장 위에 오지 않아도 됨');

module.exports = 'find me~';

require('./3.1.1-var');

console.log('require.cache..', require.cache);
console.log('require.main === module..', require.main === module);
console.log('require.main.filename..', require.main.filename);
```

```shell
node 3.5.1-require    
require 가 가장 위에 오지 않아도 됨
require.cache.. [Object: null prototype] {
  '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/3.5.1-require.js': Module {
    id: '.',
    path: '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src',
    exports: 'find me~',
    filename: '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/3.5.1-require.js',
    loaded: false,
    children: [ [Module] ],
    paths: [
      '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/node_modules',
      '/Users/myhome/02_Study/01_nodejs/mynode/chap03/node_modules',
      '/Users/myhome/02_Study/01_nodejs/mynode/node_modules',
      '/Users/myhome/02_Study/01_nodejs/node_modules',
      '/Users/myhome/02_Study/node_modules',
      '/Users/myhome/node_modules',
      '/Users/node_modules',
      '/Users/node_modules',
      '/node_modules'
    ]
  },
  '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/3.1.1-var.js': Module {
    id: '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/3.1.1-var.js',
    path: '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src',
    exports: { odd: '홀수', even: '짝수' },
    filename: '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/3.1.1-var.js',
    loaded: true,
    children: [],
    paths: [
      '/Users/myhome/02_Study/01_nodejs/mynode/chap03/src/node_modules',
      '/Users/myhome/02_Study/01_nodejs/mynode/chap03/node_modules',
      '/Users/myhome/02_Study/01_nodejs/mynode/node_modules',
      '/Users/myhome/02_Study/01_nodejs/node_modules',
      '/Users/myhome/02_Study/node_modules',
      '/Users/myhome/node_modules',
      '/Users/node_modules',
      '/Users/node_modules',
      '/node_modules'
    ]
  }
}
require.main === module.. true
require.main.filename.. /Users/myhome/02_Study/01_nodejs/mynode/chap03/src/3.5.1-require.js
```

require 가 반드시 최상단에 위치할 필요는 없고, module.exports 도 최하단에 위치할 필요는 없다.

만일 두 모듈이 서로를 require 한다면 어떻게 될까?<br />
아래와 같은 두 파일이 서로를 require 한다고 해보자.

dep1.js
```js
const dep2 = require('./3.5.2-dep2');

console.log('require dep2:', dep2);
module.exports = () => {
  console.log('dep2', dep2);
};
```

dep2.js
```js
const dep1 = require('./3.5.2-dep1');

console.log('require dep1:', dep1);
module.exports = () => {
  console.log('dep1', dep1);
};
```

dep-run.js
```js
const dep1 = require('./3.5.2-dep1');
const dep2 = require('./3.5.2-dep2');

dep1();
dep2();
```

```shell
> node 3.5.2-dep-run.js 
require dep1: {}
require dep2: [Function (anonymous)]
dep2 [Function (anonymous)]
dep1 {}
(node:71459) Warning: Accessing non-existent property 'Symbol(nodejs.util.inspect.custom)' of module exports inside circular dependency
(Use `node --trace-warnings ...` to show where the warning was created)
(node:71459) Warning: Accessing non-existent property 'constructor' of module exports inside circular dependency
(node:71459) Warning: Accessing non-existent property 'Symbol(Symbol.toStringTag)' of module exports inside circular dependency
(node:71459) Warning: Accessing non-existent property 'Symbol(Symbol.iterator)' of module exports inside circular dependency
(node:71459) Warning: Accessing non-existent property 'Symbol(nodejs.util.inspect.custom)' of module exports inside circular dependency
(node:71459) Warning: Accessing non-existent property 'constructor' of module exports inside circular dependency
(node:71459) Warning: Accessing non-existent property 'Symbol(Symbol.toStringTag)' of module exports inside circular dependency
(node:71459) Warning: Accessing non-existent property 'Symbol(Symbol.iterator)' of module exports inside circular dependency
```

위 로그를 보면 코드가 위에서부터 실행되므로 *require('./3.5.2-dep1')* 이 실행되고 *dep1.js* 의 *require('./3.5.2-dep2')* 가 실행된다.<br />
다시 *dep2.js* 에서는 *require('./3.5.2-dep1')* 가 실행된다.

보면 dep1 의 module.exports 가 함수가 아닌 빈 객체로 표시된다.

이러한 현상을 **순환 참조** 라고 하는데 이렇게 순환 참조가 있는 경우 순환 참조가 되는 대상을 빈 객체로 만든다.<br />
에러가 발생하지 않고 조용히 빈 객체로 변경되므로 예기치못한 동작이 발생할 수 있으므로 순환 참조가 발생하지 않도록 구조를 잘 잡아야 한다.

---

## 3.6. `process`

`process` 는 현재 실행되고 있는 노드 프로세스에 대한 정보를 담고 있다.

REPL 에 아래와 같이 입력하여 확인해볼 수 있다.

```shell
> node
process.version
'v16.6.0' // 설치된 노드 버전
> process.arch
'x64' // 프로세서 아키텍처 정보. arm, ia32..
> process.platform
'darwin'  // 운영체제 플랫폼 정보. linux, darwin, freebsd..
> process.pid
73385   // 현재 프로세스의 아이디
> process.uptime()
39.635160857  // 프로세스가 시작된 후 흐른 시간 (seconds)
> process.execPath
'/usr/local/bin/node' // 노드 경로
> process.cwd()
'/Users/yourcomputer' // 현재 프로세스가 실행되는 위치
> process.cpuUsage()
{ user: 338856, system: 56582 } // 현재 cpu 사용량
```

위 정보들의 사용 빈도는 높지 않지만 운영체제나 실행 환경별로 다른 동작을 하고 싶을 때 사용한다.

---

### 3.6.1. `process.env`

REPL 에 `process.env` 를 입력하면 많은 정보가 출력되는데 이 정보들은 보두 시스템 환경 변수이다.<br />
노드에 직접적인 영향을 미치는 대표적인 시스템 환경 변수로는 `UV_THREADPOOL_SIZE`와 `NODE_OPTIONS` 가 있다.

```shell
UV_THREADPOOL_SIZE=--max-old-space-size=8092
NODE_OPTIONS=8
```

`NODE_OPTIONS` 는 노드를 실행할 때의 옵션들을 입력받는 환경변수인데 `--max-old-space-size=8092` 는 노드의 메모리를 8GB 까지 사용할 수 있게 한다는 의미이다.
좀 더 자세한 내용은 [NODE_OPTIONS](https://nodejs.org/dist/latest-v16.x/docs/api/cli.html#cli_node_options_options) 를 참고바란다.

`UV_THREADPOOL_SIZE` 은 노드에서 기본적으로 사용하는 스레드풀의 스레드 갯수를 조절하는 변수이다.

>`UV_THREADPOOL_SIZE` 에 는 [Node.js - 파일시스템](https://assu10.github.io/dev/2021/11/28/nodejs-skill-3/) 의
> *5. 스레드풀* 을 참고하세요.

시스템 환경 변수 외에도 임의로 환경 변수를 저장할 수 있다.<br />
`process.env` 는 서비스의 중요한 키를 저장하는 공간으로도 사용한다. 예를 들어 서버나 DB 의 비밀번호나 각종 API 의 키를 코드에 입력하는 것은 위험하므로
아래와 같이 `process.env` 속성으로 대체한다.

```js
const secretId = process.env.SECRET_ID;
const secretCode = process.env.SECRET_CODE;
```

> `process.env` 에 임의의 환경 변수를 넣는 방법은
> [Node.js - Express (1): 미들웨어](https://assu10.github.io/dev/2021/12/01/nodejs-express-1/) 의 *2. 미들웨어* 중 `dotenv` 를
> 참고하세요.

---

### 3.6.2. `process.nextTick(콜백)`

`process.nextTick(콜백)` 은 이벤트 루프가 다른 콜백 함수들보다 먼저 처리되게 한다.

아래 코드를 보자.

nextTick.js
```js
setImmediate(() => {
  console.log('immediate~');
});

process.nextTick(() => {
  console.log('nextTick~');
});

setTimeout(() => {
  console.log('timeout~');
}, 0);

Promise.resolve().then(() => console.log('promise~'));
/*
nextTick~
promise~
timeout~
immediate~
*/
```

`process.nextTick(콜백)` 은 setTimeout 이나 setImmediate 보다 먼저 실행된다.<br />
Promise.resolve 된 Promise 도 nextTick 처럼 다른 콜백들보다 우선시되는데 이를 구분하기 위해 `process.nextTick(콜백)` 과 `Promise` 를 **마이크로태스크** 라고 구분지어 부른다.

---

### 3.6.3. `process.exit(코드)`

`process.exit(코드)` 는 실행 중인 노드 프로세스를 종료한다.

서버 환경에서 이 함수를 사용하면 서버가 멈추기 때문에 특수한 경우를 제외하고는 잘 사용하지 않지만 서버 외의 독립적인 프로그램에서 수동으로 노드를 멈추기위해서는 사용한다.

exit.js
```js
let i = 1;
setInterval(() => {
  if (i === 5) {
    console.log('stop');
    process.exit();
  }
  console.log(i);
  i += 1;
}, 1000);

/*
1
2
3
4
stop
*/
```

`process.exit(코드)` 에 인수를 코드로 줄 수 있는데 인수를 주지 않거나 0 을 주면 정상 종료를 뜻하고, 1 을 주면 비정상 종료를 뜻한다.
에러가 발생해서 종료하는 경우에는 1을 넣으면 된다.

---

# 4. 노드 내장 모듈 사용

## 4.1. `os`

웹 브라우저에서 사용되는 자바스크립트는 운영 체제의 정보를 가져올 수 없지만 노드는 os 모듈에 정보가 담겨있어 정보를 가져올 수 있다.

os.js
```js
const os = require('os');

console.log('운영체제 정보---------');
console.log('os.arch():', os.arch()); // process.arch 와 동일
console.log('os.platform():', os.platform()); // process.platform 과 동일
console.log('os.type():', os.type()); // 운영체제의 종류
console.log('os.uptime():', os.uptime()); // 운영체제 부팅 이후 흐른 시간 (seconds)
console.log('os.hostname():', os.hostname()); // 컴퓨터의 이름
console.log('os.release():', os.release()); // 운영체제의 버전

console.log('경로------------');
console.log('os.homedir():', os.homedir());
console.log('os.tmpdir():', os.tmpdir());

console.log('cpu 정보-------------');
console.log('os.cpus():', os.cpus()); // 컴퓨터의 코어 정보
console.log('os.cpus().length:', os.cpus().length); // 코어 갯수

console.log('메모리 정보-----------');
console.log('os.freemem():', os.freemem()); // 사용가능한 메모리(RAM)
console.log('os.totalmem():', os.totalmem()); // 전체 메모리 용량
```

```shell
운영체제 정보---------
os.arch(): x64
os.platform(): darwin
os.type(): Darwin
os.uptime(): 1229797
os.hostname(): -MacBookPro.local
os.release(): 20.6.0
경로------------
os.homedir(): /Users/username
os.tmpdir(): /var/folders/52/152mnlz94mq4pv238l5q91gm0000gn/T
cpu 정보-------------
os.cpus(): [
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 40473350, nice: 0, sys: 29556590, idle: 312429490, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 2035780, nice: 0, sys: 1517170, idle: 377597410, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 40172510, nice: 0, sys: 19048140, idle: 321936510, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 1972660, nice: 0, sys: 1216270, idle: 377961090, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 25547300, nice: 0, sys: 13897010, idle: 341712290, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 2088680, nice: 0, sys: 1134590, idle: 377926250, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 21786840, nice: 0, sys: 11417770, idle: 347951410, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 2188490, nice: 0, sys: 1052490, idle: 377908040, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 18438910, nice: 0, sys: 9046630, idle: 353669900, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 2282100, nice: 0, sys: 959040, idle: 377907390, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 15867070, nice: 0, sys: 7087270, idle: 358200520, irq: 0 }
  },
  {
    model: 'Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz',
    speed: 2600,
    times: { user: 2364070, nice: 0, sys: 881780, idle: 377902180, irq: 0 }
  }
]
os.cpus().length: 12
메모리 정보-----------
os.freemem(): 1336008704
os.totalmem(): 17179869184
```

`os.cpus().length` 는 코어의 갯수가 나온다. 노드에서 싱글 스레드 프로그래밍을 하면 코어가 몇 개든 상관없이 대부분의 경우 코어를 하나밖에 사용하지 않는다.
다음 포스트에 나오는 `cluster` 모듈을 사용하는 경우에는 코어 개수에 맞춰서 프로세스를 늘릴 수 있다.

---

## 4.2. `path`

`path` 는 폴더와 파일의 경로를 쉽게 조작할 수 있도록 해주는 모듈이다.

`path` 모듈이 필요한 유 중 하나는 운영체제별로 경로 구분자가 다르기 때문이다.
- 윈도우 타입 : C\Users 처럼 `\` 로 구분
- POSIX 타입 (유닉스 기반의 운영체제들로 맥, 리눅스 등) : /home/assu 처럼 `/` 로 구분

이 외에도 파일 경로에서 파일명이나 확장자만 따로 떼어주는 기능 등도 있다.

path.js
```js
const path = require('path');

console.log(`path.sep: ${path.sep}`); // 경로 구분자, 윈도우는 \, POSIX 는 /
console.log(`path.delimiter: ${path.delimiter}`); // 환경변수 구분자, 윈도우는 ;, POSIX 는 :, process.env.PATH 입력 시 여러 개의 경로가 이 구분자로 구분되어 있음
console.log(`process.env.PATH: ${process.env.PATH}`);
console.log('-------------------------');

console.log(`__filename: ${__filename}`); // 경로를 포함한 파일명
console.log(`path.dirname(__filename): ${path.dirname(__filename)}`); // 파일이 위치한 폴더 경로
console.log(`path.extname(__filename): ${path.extname(__filename)}`); // 파일 확장자
console.log(`path.basename(__filename): ${path.basename(__filename)}`); // 파일의 이름 (확장자 포함)
console.log(
  `path.basename(__filename, path.extname(__filename): ${path.basename(
    __filename,
    path.extname(__filename),
  )}`,
); // 확장자를 뺀 파일명
console.log('-------------------------');

console.log('path.parse(__filename): ', path.parse(__filename)); // 파일 경로를 root, dir, base(파일명), ext, name 으로 분리
console.log(
  `path.format(): ${path.format({
    dir: 'C://users/assu',
    name: 'path',
    ext: '.js',
  })}`,
); // path.parse() 한 객체를 파일 경로로 합침
console.log(
  `path.normalize(): ${path.normalize('C://users///assu///path.js')}`,
); // \ 나 / 를 실수로 여러 번 사용 시 정상적인 경로로 변환
console.log('-------------------------');

console.log(`path.isAbsolute(/home): ${path.isAbsolute('/home')}`); // 파일의 경로가 절대경로이면 true
console.log(`path.isAbsolute(./home): ${path.isAbsolute('./home')}`);
console.log('-------------------------');

console.log(
  `path.relative(): ${path.relative('C://users/assu/path.js', 'C://')}`,
); // 첫 번째 인자의 경로에서 두 번째 경로로 가는 방법
console.log(`__dirname: ${__dirname}`);
console.log(
  `path.join(): ${path.join(__dirname, '..', '..', '/users', '.', '/assu')}`,
); // 하나의 경로로 합치며, 상대경로인 .. 와 . 도 알아서 처리함
console.log(
  `path.resolve(): ${path.resolve(__dirname, '..', 'users', '.', '/assu')}`,
); // 뒤에 설명
```

```shell
path.sep: /
path.delimiter: :
process.env.PATH: /Users/assu/.rbenv/shims:/Users/assu/.rbenv/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
-------------------------
__filename: /Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src/4.1.2-path.js
path.dirname(__filename): /Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src
path.extname(__filename): .js
path.basename(__filename): 4.1.2-path.js
path.basename(__filename, path.extname(__filename): 4.1.2-path
-------------------------
path.parse(__filename):  {
  root: '/',
  dir: '/Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src',
  base: '4.1.2-path.js',
  ext: '.js',
  name: '4.1.2-path'
}
path.format(): C://users/assu/path.js
path.normalize(): C:/users/assu/path.js
-------------------------
path.isAbsolute(/home): true
path.isAbsolute(./home): false
-------------------------
path.relative(): ../../..
__dirname: /Users/assu/myhome/02_Study/01_nodejs/mynode/chap03/src
path.join(): /Users/assu/myhome/02_Study/01_nodejs/mynode/users/assu
path.resolve(): /assu
```

`path.join()` 과 `path.resolve()` 는 비슷하지만 약간 다르게 동작한다.
`\` 를 만나면 `path.resolve()` 는 절대 경로로 인식해서 앞의 경로를 무시하지만 `path.join()` 은 상대 경로로 처리한다.

```js
console.log(
  `path.join(): ${path.join('/a', '/b', 'c')}`,
); // //a/b/c
console.log(
  `path.resolve(): ${path.resolve('/a', '/b', 'c')}`,
);  // /b/c
```

> 윈도우에서 POSIX 스타일 경로를 사용하거나 혹은 그 반대일 경우는 아래와 같이 사용한다.
> path.posix.sep, path.posix.join(), path.win32.sep, path.win32.join()

---

## 4.3. `url`

url 처리 방식에는 크게 두 가지 방식이 있다.

노드 버전 7 에서 추가된 `WHATWG` 방식의 url 과 예전부터 노드에서 사용하던 방식의 url 인데, 두 가지 방법 다 알아두는 것이 좋다.

url.js
```js
const url = require('url');

const { URL } = url;
const myURL = new URL('http://www.assu.co.kr/node/study.js?q1=haha#anchor');
console.log('new URL(): ', myURL);  // WHATWG 방식의 url
console.log('url.format(): ', url.format(myURL));

console.log('----------');

// 기존 노드 방식
const parsedUrl = url.parse(
  'http://www.assu.co.kr/node/study.js?q1=haha#anchor',
);
console.log('url.parse(): ', parsedUrl);
console.log('url.format(): ', url.format(parsedUrl));
```

```shell
new URL():  URL {
  href: 'http://www.assu.co.kr/node/study.js?q1=haha#anchor',
  origin: 'http://www.assu.co.kr',
  protocol: 'http:',
  username: '',
  password: '',
  host: 'www.assu.co.kr',
  hostname: 'www.assu.co.kr',
  port: '',
  pathname: '/node/study.js',
  search: '?q1=haha',
  searchParams: URLSearchParams { 'q1' => 'haha' },
  hash: '#anchor'
}
url.format():  http://www.assu.co.kr/node/study.js?q1=haha#anchor
----------
url.parse():  Url {
  protocol: 'http:',
  slashes: true,
  auth: null,
  host: 'www.assu.co.kr',
  port: null,
  hostname: 'www.assu.co.kr',
  hash: '#anchor',
  search: '?q1=haha',
  query: 'q1=haha',
  pathname: '/node/study.js',
  path: '/node/study.js?q1=haha',
  href: 'http://www.assu.co.kr/node/study.js?q1=haha#anchor'
}
url.format():  http://www.assu.co.kr/node/study.js?q1=haha#anchor
```

URL 객체에 주소를 넣어 객체로 만들면 주소가 부분별로 정리된다.<br />
이 방법은 `WHATWG` 의 방식으로 `username`, `password`, `origin`, `searchParams` 속성이 있다.

기존 노드 방식은 아래 두 메서드를 주로 사용한다.
- `url.parse(url 주소)` : 주소 분해, `WHATWG` 에 있는 `username`, `password` 대신 auth 속성이 있고, `searchParams` 대신 `query` 가 있다.
- `url.format(객체)` : 분해된 url 객체를 다시 원래 상태로 조립, `WHATWG` 방식의 url 과 기존 노드의 url 모두 사용 가능

*/node/study.js* 처럼 host 부분 없이 pathname 만 오는 경우는 WHATWG 방식으로 처리할 수 없으므로 기존 노드 url 형식을 사용해야 한다.

WHATWG 방식은 search 부분을 searchParams 객체로 반환하므로 파라미터 처리 시 유용하게 사용할 수 있다.

searchParams.js
```js
const { URL } = require('url');

const myURL = new URL(
  'http://www.assu.co.kr/?page=3&limit=10&category=nodejs&category=javascript',
);
console.log('searchParams: ', myURL.searchParams);
console.log('searchParams.getAll(): ', myURL.searchParams.getAll('category')); // 키에 해당하는 모든 값 조회
console.log('searchParams.get(): ', myURL.searchParams.get('limit')); // 키에 해당하는 첫 번째 값만 조회
console.log('searchParams.has(): ', myURL.searchParams.has('page'));

console.log('searchParams.keys(): ', myURL.searchParams.keys()); // 모든 키를 반복기 객체로 가져옴
console.log('searchParams.values(): ', myURL.searchParams.values()); // 모든 값을 반복기 객체로 가져옴

myURL.searchParams.append('estype', 'es3'); // 키 추가, 같은 키가 있으면 유지하고 하나 더 추가
myURL.searchParams.append('estype', 'es5');
console.log('searchParams.getAll(): ', myURL.searchParams.getAll('estype'));

myURL.searchParams.set('estype', 'es6'); // 키 추가, 같은 키가 있으면 모두 삭제하고 새로 추가
console.log('searchParams.getAll(): ', myURL.searchParams.getAll('estype'));

myURL.searchParams.delete('estype'); // 해당 키 모두 제거
console.log('searchParams.getAll(): ', myURL.searchParams.getAll('estype'));

console.log('myURL.searchParams.toString(): ', myURL.searchParams.toString()); // searchParams 객체를 문자열로 만듦, search 에 대입하면 주소 객체에 반영됨
myURL.search = myURL.searchParams.toString();
```

```shell
searchParams:  URLSearchParams {
  'page' => '3',
  'limit' => '10',
  'category' => 'nodejs',
  'category' => 'javascript' }
searchParams.getAll():  [ 'nodejs', 'javascript' ]
searchParams.get():  10
searchParams.has():  true
searchParams.keys():  URLSearchParams Iterator { 'page', 'limit', 'category', 'category' }
searchParams.values():  URLSearchParams Iterator { '3', '10', 'nodejs', 'javascript' }
searchParams.getAll():  [ 'es3', 'es5' ]
searchParams.getAll():  [ 'es6' ]
searchParams.getAll():  []
myURL.searchParams.toString():  page=3&limit=10&category=nodejs&category=javascript
```

query 같은 문자열보다 searchParams 가 유용한 이유는 query 의 경우 querystring 모듈을 한번 더 사용해야 하기 때문이다.

---

## 4.4. `querystring`

`querystring` 은 WHATWG 방식의 url 대신 기존 노드의 url 사용 시, `search` 부분을 사용하기 쉽게 객체로 만들어 주는 모듈이다.

```javascript
const url = require('url');
const querystring = require('querystring');

const parsedUrl = url.parse(
  'http://www.assu.co.kr/?page=3&limit=10&category=nodejs&category=javascript',
);

// url 의 쿼리 부분을 자바스크립트 객체로 분해
const query = querystring.parse(parsedUrl.query);
console.log('querystring.parse(): ', query);
console.log('querystring.stringify(): ', querystring.stringify(query));
```

```shell
querystring.parse():  [Object: null prototype] {
  page: '3',
  limit: '10',
  category: [ 'nodejs', 'javascript' ]
}
querystring.stringify():  page=3&limit=10&category=nodejs&category=javascript
```

---

## 4.5. `crypto`

### 4.5.1. 단방향 암호화

비밀번호는 보통 단방향 암호화 알고리즘을 사용하여 암호화한다.

> **단방향 암호화**<br />
> 복호화할 수 없는 암호화 방식<br />
> 복호화할 수 없기 때문에 암호화 라고 표현하는 대신 **해시 함수**라고 하기도 함

단방향 암호화 알고리즘은 주로 해시 기법을 사용한다.

> **해시 기법**<br />
> 어떠한 문자열을 고정된 길이의 다른 문자열로 바꿔버리는 방식<br />
> 예) abcdedsafds 라는 문자열을 poiu 문자열로 바꿔버리고, dfcvd 문자열을 dkfd 문자열로 바꿔버림<br />
> 입력 문자열의 길이는 다르지만, 출력 문자열의 길이는 고정되어 있음

hash.js
```javascript
const crypto = require('crypto');

console.log(
  'base64: ',
  crypto.createHash('sha512').update('password').digest('base64'),
);

console.log(
  'hex: ',
  crypto.createHash('sha512').update('password').digest('hex'),
);

console.log(
  'other base64: ',
  crypto.createHash('sha512').update('other_password').digest('base64'),
);
```

```shell
base64:  sQnzu7wkTrgkQZF+0G1hi5AI3Qmzvv0bXgc5THBqi7mAsdd4Xll27ASbRt9fEyavWi6m0QP9B8lThf+rDKy8hg==
hex:  b109f3bbbc244eb82441917ed06d618b9008dd09b3befd1b5e07394c706a8bb980b1d7785e5976ec049b46df5f1326af5a2ea6d103fd07c95385ffab0cacbc86
other base64:  fAfMKoTZE5e4OFpTuPzWoL4zWUG0Oyl8z4bETLx1/sbPXObY6yPuoBnPo+jlg8s22TWaVVz14u8SD520uC6MAg==
```

- **createHash(알고리즘)**
  - 사용할 해시 알고리즘을 넣음
  - `sha256`, `sha512` (md5, sha1 은 취약점이 발견되었음)
- **update(문자열)**
  - 변환할 문자열을 넣음
- **digest(인코딩)**
  - 인코딩할 알고리즘을 넣음
  - `base64`, `hex`, `latin1` 이 주로 사용되고, base64 가 결과 문자열이 가장 짧아서 많이 사용됨
  
주로 `pbkdf2`, `bcrypt`, `scrypt` 알고리즘으로 비밀번호를 암호화 하는데 아래는 노드에서 지원하는 pbkdf2 에 대해 알아본다.

- `pbkdf2`
 - 기존 문자열에 salt 문자열을 붙인 후 해시 알고리즘을 반복하여 적용하는 방식

```javascript
const crypto = require('crypto');

crypto.randomBytes(64, (err, buf) => {
  const salt = buf.toString('base64');
  console.log('salt: ', salt);
  crypto.pbkdf2('password', salt, 100000, 6, 'sha512', (err, key) => {
    console.log('password: ', key.toString('base64'));
  });
});
```

```shell
salt:  JUSoX18d6csKqCjYe8ypzvMOZ/JnVl0I2tN3JC00tBewVZh476bn7w/8ewPkZC6B1Zcf2rPuTNY+ryE0zM1tyA==
password:  gOLeI/3g
```

randomBytes() 메서드로 64바이트 길이의 문자열을 만드는 게 이것이 salt 가 된다.<br />
randomBytes 이므로 매번 결과가 달라지므로 salt 를 DB 에 저장하고 있어야 비밀번호를 찾을 수 있다.

*crypto.pbkdf2('password', salt, 100000, 6, 'sha512' ...)* 는 각각 비밀번호, salt, 반복 횟수, 출력 바이트, 해시 알고리즘이다.<br />
즉, sha512 로 변환된 결과값을 다시 sha512 로 변환하는 과정을 10만번 반복하는 것이다. (약 1초 소요)

싱글 스레드 프로그래밍할 때 그 1초 동안 블로킹이 되는 것에 대한 우려가 있을 수 있지만 `crypto.randomBytes` 와 `crypto.pbkdf2` 메서드는
내부적으로 스레드풀을 사용하여 멀티 스레딩으로 동작한다.

> 비슷하게 동작하는 메서드들에 대해선 [Node.js - 파일시스템](https://assu10.github.io/dev/2021/11/28/nodejs-skill-3/) 의 *5. 스레드풀* 을 참고하세요

pbkdf2 는 간단하지만 bcrypt, scrypt 보다는 취약하므로 더 나은 보안을 위해선 bcrypt 나 scrypt 를 사용하면 된다.

> `bcrypt` 를 사용하는 내용은 [3.2.2. 로컬 로그인 - 회원가입, 로그인, 로그아웃 라우터](https://assu10.github.io/dev/2022/01/03/nodejs-sns-service/#322-%EB%A1%9C%EC%BB%AC-%EB%A1%9C%EA%B7%B8%EC%9D%B8---%ED%9A%8C%EC%9B%90%EA%B0%80%EC%9E%85-%EB%A1%9C%EA%B7%B8%EC%9D%B8-%EB%A1%9C%EA%B7%B8%EC%95%84%EC%9B%83-%EB%9D%BC%EC%9A%B0%ED%84%B0) 를 참고하세요.

---

### 4.5.2. 양방향 대칭형 암호화

양방향 대칭형 암호화는 암호화된 문자열을 key 를 사용하여 복호화 가능한 암호화를 말한다.

cipher.js
```javascript
const crypto = require('crypto');

const algorithm = 'aes-256-cbc';
const key = 'abcdefghijklmnopqrstuvwxyz123456';
const iv = '1234567890123456';

const cipher = crypto.createCipheriv(algorithm, key, iv);
let result = cipher.update('암호화할 문장', 'utf8', 'base64');
result += cipher.final('base64');
console.log('암호화: ', result);

const decipher = crypto.createDecipheriv(algorithm, key, iv);
let result2 = decipher.update(result, 'base64', 'utf8');
result2 += decipher.final('utf8');
console.log('복호화: ', result2);

console.log('사용가능한 알고리즘: ', crypto.getCiphers());
```

```shell
암호화:  iiopeG2GsYlk6ccoBoFvEH2EBDMWv1kK9bNuDjYxiN0=
복호화:  암호화할 문장
사용가능한 알고리즘:  [
  'aes-128-cbc',
  'aes-128-cbc-hmac-sha1',
  'aes-128-cbc-hmac-sha256',
  'aes-128-ccm',
  'aes-128-cfb',
  'aes-128-cfb1',
  'aes-128-cfb8',
  'aes-128-ctr',
  'aes-128-ecb',
  'aes-128-gcm',
  'camellia-256-cfb1',
  'camellia-256-cfb8',
  'camellia-256-ctr',
  'camellia-256-ecb',
  'camellia-256-ofb',
  'camellia128',
  ... more items
]
```

- **crypto.createCipheriv(알고리즘, 키, iv)**
  - 암호화 알고리즘, 키, iv 를 넣음
  - 암호화 알고리즘은 `aes-256-cbc` 를 사용했고, 해당 알고리즘의 경우 `키는 32 bytes`, `iv 는 16 bytes` 이어야 함
  - iv 는 암호화할 때 사용하는 초기화 벡터를 의미
  - 사용가능한 알고리즘은 crypto.getCiphers() 를 통해 알 수 있음
- **cipher.update(문자열, 인풋 인코딩, 출력 인코딩)**
  - 암호화 대상과 대상의 인코딩, 출력 결과물의 인코딩을 넣음
  - 보통 문자열은 utf8 인코딩, 암호는 base64 인코딩을 주로 사용함
- **cipher.final(출력 인코딩)**
  - 출력 결과물의 인코딩을 넣으면 암호화가 완료됨
- **crypto.createDecipheriv(알고리즘, 키, iv)**
  - 복호화 시 사용
  - 암호화할 때 사용한 알고리즘, 키, iv 를 그대로 넣어야 함
- **decipher.update(문자열, 인풋 인코딩, 출력 인코딩)**
  - 암호화된 문장, 그 문장의 인코딩, 복호화할 인코딩을 넣음 
  - cipher.update() 인자의 역순으로 넣으면 됨
- **decipher.final(출력 인코딩)**
  -  복호화 결과물의 인코딩을 넣음

이 외에도 crypto 모듈은 양방향 비대칭형 암호화, HMAC 등 다양한 암호화를 제공하고 있다. 

[node crypto 공식문서](https://nodejs.org/api/crypto.html) 를 참고하여 좀 더 상세히 확인이 가능하다.<br />
좀 더 간단하게 암호화를 하고 싶으면 npm 패키지인 [crypto-js (간단한 암호화)](https://www.npmjs.com/package/crypto-js) 를 사용하는 것도 좋다.

---

## 4.6. `util`

아래는 util 모듈에서 자주 사용되는 2 가지 모듈이다.

util.js
```javascript
const util = require('util');
const crypto = require('crypto');

const dontUserMe = util.deprecate((a, b) => {
  console.log(a + b);
}, 'dontUseMe 함수는 deprecated 되었으니 더 이상 사용 금지');

dontUserMe(1, 2);

const randomBytesPromise = util.promisify(crypto.randomBytes);
randomBytesPromise(64)
  .then(buf => {
    console.log(buf.toString('base64'));
  })
  .catch(err => {
    console.error(err);
  });
```

```shell
3
(node:71167) DeprecationWarning: dontUseMe 함수는 deprecated 되었으니 더 이상 사용 금지
(Use `node --trace-deprecation ...` to show where the warning was created)
fJQ27C7o8pfeANEvsCx2jlHVQx8graotM6m8WwoZKwHYeN8hDEuvIm/tfeYB44VMM4zIXYO1bG7ah5kfZnCkKw==
```

- **util.deprecate**
  - 함수가 deprecated 처리 되었음을 알림
- **util.promisify**
  - 콜백 패턴을 프로미스 패턴으로 바꿔줌
  - 바꿀 함수를 인수로 제공하면 됨
  - 바뀐 함수는 async/await 패턴으로 사용할 수 있음

*4.5.1. 단방향 암호화* 에서 나온 randomBytes 와 비교해보도록 하자.

```javascript
const crypto = require('crypto');

crypto.randomBytes(64, (err, buf) => {
  const salt = buf.toString('base64');
  console.log('salt: ', salt);
  crypto.pbkdf2('password', salt, 100000, 6, 'sha512', (err, key) => {
    console.log('password: ', key.toString('base64'));
  });
});
```

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

# 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [NODE_OPTIONS](https://nodejs.org/dist/latest-v16.x/docs/api/cli.html#cli_node_options_options)
* [UV_THREADPOOL_SIZE](https://nodejs.org/dist/latest-v16.x/docs/api/cli.html#cli_uv_threadpool_size_size)
* [node.js 에러 코드](https://nodejs.org/dist/latest-v16.x/docs/api/errors.html#errors_node_js_error_codes)
* [uncaughtException](https://nodejs.org/dist/latest-v16.x/docs/api/process.html#process_event_uncaughtexception)
* [node crypto 공식문서](https://nodejs.org/api/crypto.html)
* [crypto-js (간단한 암호화)](https://www.npmjs.com/package/crypto-js)