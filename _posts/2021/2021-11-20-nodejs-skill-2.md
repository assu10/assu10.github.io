---
layout: post
title:  "Node.js - 기본 개념 (2): 멀티스레드"
date:   2021-11-20 10:00
categories: dev
tags: nodejs
---

이 포스트는 노드가 멀티 스레드와 관련된 기능에 대해 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - `worker_threads`
> - `child_process`
> - 기타 모듈들

---

## 4.7. `worker_threads`

### 4.7.1  간단한 worker_threads 사용 방식 

아래는 노드에서 멀티 스레드 방식으로 작업하는 간단한 예시이다.

worker_threads.js
```javascript
const { Worker, isMainThread, parentPort } = require('worker_threads');

if (isMainThread) {
  // 부모인 경우
  const worker = new Worker(__filename);
  worker.on('message', message => console.log('from worker', message));
  worker.on('exit', () => console.log('worker exit'));
  worker.postMessage('ping');
} else {
  // 워커인 경우
  parentPort.on('message', value => {
    console.log('from parent', value);
    parentPort.postMessage('pong');
    parentPort.close();
  });
}
```

```shell
from parent ping
from worker pong
worker exit
```

기존에 동작하던 싱글 스레드를 **메인 스레드** 혹은 **부모 스레드**라고 하고, 생성한 스레드를 **워커 스레드**라고 한다.

위 코드를 설명하면 아래와 같다.

- 부모에서 워커 생성 후 `worker.postMessage` 로 워커에게 데이터 전달
- 워커는 `parentPort.on('message')` 이벤트 리스너로 부모로부터 메시지를 받음
- 워커는 다시 `parentPort.postMessage` 로 부모에게 메시지를 보냄
- 부모는 `worker.on('message')` 로 메시지를 받음 (메시지를 한번만 받고 싶으면 on 대신 once 사용)
- 워커에서 on 메서드 사용시엔 `parentPort.close()` 를 통해 직접 워커를 종료해야 함
- 워커가 종료되면 부모의 `worker.on('exit')` 가 실행됨

---

### 4.7.2  workerData 사용

아래는 2개의 워커 스레드에 데이터를 남기는 예시이다. 위에선 worker.postMessage 로 데이터를 전달했는데 아래는 다른 방식으로
데이터를 전달한다.

```javascript
const {
  Worker,
  isMainThread,
  parentPort,
  workerData,
} = require('worker_threads');

if (isMainThread) {
  // 부모인 경우
  const threads = new Set();
  threads.add(
    new Worker(__filename, {
      workerData: { start: 1 },
    }),
  );
  threads.add(
    new Worker(__filename, {
      workerData: { start: 2 },
    }),
  );

  for (let worker of threads) {
    worker.on('message', message => console.log('from worker', message));
    worker.on('exit', () => {
      threads.delete(worker);
      if (threads.size === 0) {
        console.log('job done');
      }
    });
  }
} else {
  // 워커인 경우
  const data = workerData;
  parentPort.postMessage(data.start + 100);
}
```

```shell
from worker 101
from worker 102
job done
```

new Worker 호출 시 두 번째 인수의 `workerData` 속성으로 데이터를 보낼 수 있다.<br />
워커는 workerData 로 부모로부터 데이터를 받는다.<br />
워커가 값을 돌려주는 순간 워커가 종료되어 worker.on('exit') 가 실행된다.

---

### 4.7.3  복잡한 worker_threads 사용 방식 (소수 갯수 구하기)

아래는 2 ~ 1,000 만 사이의 소수의 갯수를 구하는 작업을 워커 스레드를 사용하지 않은 코드이다.

prime.js
```javascript
const min = 2;
const max = 10000000;
const primes = [];

function generatePrimes(start, range) {
  let isPrime = true;
  const end = start + range;
  for (let i = start; i < end; i++) {
    for (let j = min; j < Math.sqrt(end); j++) {
      if (i !== j && i % j === 0) {
        isPrime = false;
        break;
      }
    }
    if (isPrime) {
      primes.push(i);
    }
    isPrime = true;
  }
}

console.time('prime');
generatePrimes(min, max);
console.timeEnd('prime');
console.log(primes.length);
```

```shell
prime: 9.947s
664579
```

이제 같은 로직을 워커 스레드를 사용하여 사용해보자.

prime-worker.js
```javascript
const {
  Worker,
  isMainThread,
  parentPort,
  workerData,
} = require('worker_threads');

const min = 2;
let primes = [];

function findPrimes(start, range) {
  let isPrime = true;
  const end = start + range;

  for (let i = start; i < end; i++) {
    for (let j = min; j < Math.sqrt(end); j++) {
      if (i !== j && i % j === 0) {
        isPrime = false;
        break;
      }
    }
    if (isPrime) {
      primes.push(i);
    }
    isPrime = true;
  }
}

if (isMainThread) {
  const max = 10000000;
  const threadCount = 8;
  const threads = new Set();
  const range = Math.ceil((max - min) / threadCount);
  let start = min;

  console.time('prime');
  for (let i = 0; i < threadCount - 1; i++) {
    const wStart = start;
    threads.add(
      new Worker(__filename, {
        workerData: {
          start: wStart,
          range,
        },
      }),
    );
    start += range;
  }
  threads.add(
    new Worker(__filename, {
      workerData: {
        start,
        range: range + ((max - min + 1) % threadCount),
      },
    }),
  );

  for (let worker of threads) {
    worker.on('error', err => {
      throw err;
    });
    worker.on('exit', () => {
      threads.delete(worker);
      if (threads.size === 0) {
        console.timeEnd('prime');
        console.log(primes.length);
      }
    });
    worker.on('message', msg => {
      primes = primes.concat(msg);
    });
  }
} else {
  findPrimes(workerData.start, workerData.range);
  parentPort.postMessage(primes);
}
```

```shell
prime: 1.516s
664579
```

워커 스레드를 사용하지 않을 때보다 훨씬 좋은 성능을 나타내는 것을 확인할 수 있다.<br />
하지만 워커 스레드를 8개 사용한다고 해서 8배 빨라지는 것은 아니다.<br />
스레드를 생성하고 스레드 간 통신 비용이 상당하므로 멀티 스레딩 사용 시엔 이러한 부분도 고려햐여야 한다.

---

## 4.8. `child_process`

`child_process` 는 다른 프로그램을 실행하고 싶거나, 명령어를 수행하고 싶을 때 사용하는 모듈이다.<br />
`child_process` 모둘을 통해 다른 언어의 코드를 실행 후 결과값을 받을 수 있다.<br />

`child_process` 라는 말 그대로 현재 노드 프로세스 외의 새로운 프로세스를 띄워서 명령을 수행하고, 노드 프로세스에 결과를 알려준다.

exec.js
```javascript
const exec = require('child_process').exec;

const process = exec('ls');

process.stdout.on('data', function (data) {
  console.log(data.toString());
});

process.stderr.on('data', function (data) {
  console.error(data.toString());
});
```

```shell
3.1-globalA.js
3.1-globalB.js
3.1.1-func.js
```

결과는 `stdout`, `stderr` 에 붙여준 `data` 이벤트 리스너에 버퍼 형태로 전달된다. 

아래는 파이썬 프로그램을 실행하는 예시이다.

spawn.js
```javascript
const spawn = require('child_process').spawn;

const process = spawn('python', ['4.8-test.py']);

process.stdout.on('data', function (data) {
  console.log(data.toString());
});

process.stderr.on('data', function (data) {
  console.error(data.toString());
});
```

test.py
```java
print('hello~')
```

```shell
hello~
```

`spawn` 의 첫 번째 인수는 명령어, 두 번째 인수는 옵션 배열을 넣는다.<br />
`exec` 는 셸을 실행해서 명령어를 수행하고, `spawn` 은 새로운 프로세스를 띄우면서 명령어를 실행한다.<br />
`spawn` 에서도 세 번째 인수로 `{ shell: true }` 를 제공하면 exec 처럼 셸을 실행하여 명령어를 수행한다.

---

## 4.9. 기타 모듈들

- `assert`
- `dns`
    - 도메인 이름에 대한 IP 주소 획득
- `net`
    - HTTP 보다 로우 레벨인 TCP 나 IPC 통신 시 사용
- `string_decoder`
    - 버퍼 데이터를 문자열로 변환 시 사용
- `tls`
    - TLS 와 SSL 에 관련된 작업 시 사용
- `tty`
    - 터미널과 관련된 작업 시 사용
- `dgram`
    - UDP 와 관련된 작업 시 사용
- `v8`
    - V8 엔진에 직접 접근 시 사용
- `vm`
    - 가상 머신에 직접 접근 시 사용

---


*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

# 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)