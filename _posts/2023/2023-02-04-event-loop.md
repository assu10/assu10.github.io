---
layout: post
title:  "Event Loop"
date:   2023-02-04
categories: dev
tags: nodejs javascript event-loop setImmediate() setTimeout() process.nextTick()
---

이 포스트는 Single Thread 로 동작하는 Node.js 가 어떻게 Non-Block (비동기) 처리를 할 수 있는지 Event Loop 의 원리를 통해 알아본다.  


<!-- TOC -->
* [1. Event Loop](#1-event-loop)
  * [1.1. Timer phase (타이머 단계)](#11-timer-phase-타이머-단계)
  * [1.2. Pending callback phase (대기 콜백 단계): `pending_queue`](#12-pending-callback-phase-대기-콜백-단계-pending_queue)
  * [1.3. Idle, Prepare phase (유휴, 준비 단계)](#13-idle-prepare-phase-유휴-준비-단계)
  * [1.4. Poll phase (폴 단계): `watch_queue`](#14-poll-phase-폴-단계-watch_queue)
  * [1.5. Check phase (체크 단계): `check_queue`](#15-check-phase-체크-단계-check_queue)
  * [1.6. Close callback phase (종료 콜백 단계): `closing_callbacks_queue`](#16-close-callback-phase-종료-콜백-단계-closing_callbacks_queue)
* [2. `setImmediate()` vs `setTimeout()`](#2-setimmediate-vs-settimeout)
* [3. `process.nextTick()`](#3-processnexttick)
* [4. `process.nextTick()` vs `setImmediate()`](#4-processnexttick-vs-setimmediate)
* [5. `process.nextTick()` 을 사용하는 이유](#5-processnexttick-을-사용하는-이유)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. Event Loop

Event Loop 는 시스템 커널에서 가능한 작업이 있다면 그 작업을 커널로 이관한다.  
**javascript 가 Single Thread 기반임에도 불구하고 Node.js 가 Non-Blocking (비동기) I/O 작업을 수행할 수 있도록 해주는 핵심 기능**이다.

Event Loop 는 총 6단계가 있고, 각 단계마다 처리해야 하는 callback 함수를 담기 위한 큐를 갖고 있다. 

아래 이미지는 각 단계가 전이되는 과정이며, 반드시 다음 단계로 넘어가는 것은 아니다.
Event Loop 의 구성 요소는 아니지만 `nextTickQueue` 와 `microTaskQueue` 도 존재하며 이 큐에 들어있는 작업은 Event Loop 가 어느 단계에 있든지 실행될 수 있다. 

![Event Loop](/assets/img/dev/2023/0204/event_loop_01.png)

javascript 코드는 idle, prepare 단계를 제외한 어느 단계에서나 실행될 수 있다. 

`node main.js` 명령어로 Node.js 애플리케이션을 콘솔에서 실행하면 Node.js 는 먼저 Event Loop 를 생성한 후 메인 모듈인 main.js 를 실행한다.  
이 과정에서 생성된 callback 들이 각 단계에 존재하는 큐에 들어가게 되는데 메인 모듈의 실행을 완료한 다음 Event Loop 를 계속 실행할 지 결정한다.  
큐가 모두 비어서 더 이상 수행할 작업이 없다면 (=다른 비동기 I/O 나 timer 를 기다리는지 확인 후 기다리는 것이 없다면) Node.js 는 Event Loop 를 빠져나가고 프로세스를 종료한다.

---

## 1.1. Timer phase (타이머 단계)

Event Loop 는 Timer 단계로 시작하는데, 이 단계는 `setTimeout()`과 `setInterval()` 로 스케쥴링한 콜백을 실행한다.(= setTimeout, setInterval 을 통해 만들어진
타이머들을 큐에 넣고 실행)

Timer 는 실행되기 원하는 정확한 시간이 아니라 제공된 callback 이 일정 시간 후에 실행되어야 하는 기준 시간을 지정한다. 따라서 Timer callback 은 지정 시간이 지난 후
스케쥴링될 수 있는 가장 이른 시간에 실행된다.

아래 코드에서 100ms 임계값 이후에 실행되도록 만료시간을 지정했기 때문에 스크립트는 95ms가 걸리는 파일 읽기를 비동기로 먼저 시작한다.

```javascript
const fs = require('fs');

function someAsyncOperation(callback) {
  // 이 작업이 완료되는데 95ms가 걸린다고 가정합니다.
  fs.readFile('/path/to/file', callback);
}

const timeoutScheduled = Date.now();

setTimeout(() => {
  const delay = Date.now() - timeoutScheduled;

  console.log(`${delay}ms have passed since I was scheduled`);
}, 100); // 100 이 임계값

// 완료하는데 95ms가 걸리는 someAsyncOperation를 실행합니다.
someAsyncOperation(() => {
  const startCallback = Date.now();

  // 10ms가 걸릴 어떤 작업을 합니다.
  while (Date.now() - startCallback < 10) {
    // 아무것도 하지 않습니다.
  }
});
```

Event Loop poll 단계에 진입했을 때 빈 큐를 가지고 있으므로(fs.readFile()이 아직 완료되지 않음) 가장 빠른 Timer 의 임계값에 도달할 때까지 기다린다.  
95ms가 지나기를 기다리는 동안 fs.readFile()이 파일 읽기를 끝마치고 완료하는데 10ms가 걸리는 콜백이 poll 큐에 추가되어 실행된다.  
callback 이 완료되었을 때 큐에 있는 콜백이 없으므로 Event Loop 는 가장 빠른 Timer 의 임계값에 도달했는지를 확인하고 Timer 의 callback 을 실행하려고 timers 단계에 되돌아간다.  
위 코드에서 Timer 가 스케줄링되고 callback 이 실행되기까지의 전체 지연시간이 105ms (95+10) 가 되는 것을 볼 수 있습니다.

---

## 1.2. Pending callback phase (대기 콜백 단계): `pending_queue`

이 단계의 큐(pending_queue) 에 들어있는 callback 들은 현재 돌고 있는 Loop 이전의 작업에서 큐에 들어온 callback 이다.  
예를 들어 TCP 핸들러 내에서 비동기의 쓰기 작업을 한다면 TCP 통신과 쓰기 작업이 끝난 후 해당 작업의 callback 이 큐에 들어온다.  
또한 에러 핸들러 callback 도 `pending_queue` 에 들어온다.  
예를 들어 TCP 소켓이 연결을 시도하다가 ECONNREFUSED 를 받으면 일부 시스템은 오류를 보고하기를 기다리는데 이는 pending callbacks 단계에서 실행되기 위해 큐에 추가된다.

---

## 1.3. Idle, Prepare phase (유휴, 준비 단계)

Idle 단계는 tick 마다 실행되고, Prepare 단계는 매 polling 직전에 실행된다.  
이 두 단계는 Node.js 의 내부용으로만 사용된다.

---

## 1.4. Poll phase (폴 단계): `watch_queue`

새로운 I/O 이벤트를 가져와서 관련 callback 을 수행한다. (e.g. 소켓 연결과 같은 새로운 커넥션을 맺거나 파일 읽기과 같이 데이터 처리를 받아들임)  

Poll 단계는 2 가지 주요 기능을 가진다.  
- I/O 를 얼마나 오래 block 하고 polling 해야 하는지 계산
- 이 후 poll queue 에 있는 이벤트를 처리

Event Loop 가 Poll phase 에 진입하고 스케쥴링된 Timer 가 없을 때 두 가지 중 하나의 상황이 발생한다.

- poll 큐 (`watch_queue`) 가 비어있지 않다면 Event Loop 가 callback 의 큐를 순회하면서 큐를 다 소진하거나 시스템 실행 한계에 도달할 때까지 동기적으로 모든 callback 을 실행
- poll 큐 (`watch_queue`) 가 비어있다면 바로 다음 단계로 넘어가는 것이 아니라 `check_queue`, `pending_queue`, `closing_callbacks_queue` 에 남은 작업이 있는지 확인 후 다음 작업이 있다면 다음 단계로 이동 (=즉 아래 중 하나의 상황이 발생)
  - 스크립트가 `setImmediate()` 로 스케쥴링 되었다면 Event Loop 는 Poll 단계를 종료하고 스케쥴링된 스크립트를 실행하기 위해 Check 단계로 넘어감
  - 스크립트가 `setImmediate()` 로 스케쥴링 되지 않았다면 Event Loop 는 callback 이 큐에 추가되기를 기다린 후 즉시 실행

poll 큐가 비게 되면 Timer 가 시간 임계점에 도달했는지 확인하고 하나 이상의 Timer 가 준비되었다면 Event Loop 는 Timer 의 callback 을 실행하기 위해 Timer 단계로 돌아간다.

---

## 1.5. Check phase (체크 단계): `check_queue`

`setImmediate()` 의 callback 만을 위한 단계다.

Poll 단계가 완료된 직후 사람이 callback 을 실행할 수 있게 한다.  
Poll 단계가 idle 상태가 되고 스크립트가 `setImmediate()` 로 큐에 추가되어 대기 중인 경우 Event Loop 는 기다리지 않고 Check 단계로 진행된다.  

보통은 코드가 실행되면 Event Loop 는 connection, request 등을 기다리는 Poll 단계를 거치는데 만약 callback 이 `setImmediate()` 로 스케쥴링되고 Poll 단계가
idle 상태가 되었다면 Poll Event 를 기다리지 않고 Check 단계로 넘어온다.


---

## 1.6. Close callback phase (종료 콜백 단계): `closing_callbacks_queue`

`socket.on('close', () => {})` 과 같은 close 나 `socket.destroy()` 등의 destroy 이벤트 타입의 callback 이 처리된다.

---

# 2. `setImmediate()` vs `setTimeout()`

`setImmediate()` 와 `setTimeout()` 는 비슷하지만 호출된 시기에 따라 다르게 동작한다.

- `setImmediate()`
  - 현재의 Poll 단계가 완료되면 스크립트를 실행하도록 설계됨
- `setTimeout()`
  - 최소 임계값(ms) 이 지난 후 스크립트가 실행되도록 스케쥴링함

타이머가 실행되는 순서는 어떤 컨텍스트에서 호출되었는지에 따라 다르다.  

예를 들어 I/O 주기 안에 있지 않은 컨텍스트 (e.g. 메인 모듈) 에서 아래 스크립트를 실행하면 두 타이머의 순서는 프로세스 성능에 영향을 받으므로 그때마다 다르다.

```javascript
// timeout_vs_immediate.js
setTimeout(() => {
  console.log('timeout');
}, 0);

setImmediate(() => {
  console.log('immediate');
});
```

```shell
$ node timeout_vs_immediate.js
timeout
immediate

$ node timeout_vs_immediate.js
immediate
timeout
```

만일 I/O 주기 안에서 호출하면 항상 `setImmediate()` callback 이 먼저 실행된다.

```javascript
// timeout_vs_immediate.js
const fs = require('fs');

fs.readFile(__filename, () => {
  setTimeout(() => {
    console.log('timeout');
  }, 0);
  setImmediate(() => {
    console.log('immediate');
  });
});
```

```shell
$ node timeout_vs_immediate.js
immediate
timeout

$ node timeout_vs_immediate.js
immediate
timeout
```

`setImmediate()` 를 사용하게 되면 얼마나 많은 타이머가 존재하냐에 상관없이 I/O 주기 내에서 스케쥴링된 어떤 타이머보다 항상 먼저 실행된다.

---

# 3. `process.nextTick()`

`process.nextTick()` 는 비동기 API 이지만 Event Loop 에는 포함되지 않는다. 대신 `nextTickQueue` 는 Event Loop 의 현재 단계와 관계없이
현재 작업이 완료된 후 처리된다.

`process.nextTick()` 을 호출하면 `process.nextTick()` 에 전달한 모든 callback 은 언제나 Event Loop 가 계속 진행되기 전에 처리된다.  
이러한 동작때문에 재귀로 `process.nextTick()` 를 호출하면 Event Loop 가 Poll 단계에 가는 걸 막아서 I/O 가 `starve` 상태가 되어 좋지 않은 상황이 발생할 수 있다.

그러함에도 불구하고 이러한 동작이 왜 Node.js 에 포함되었냐면 API 가 반드시 그럴 필요가 없는 경우에도 항상 비동기이어야 한다는 설계 철학 때문이다.

```javascript
function apiCall(arg, callback) {
  if (typeof arg !== 'string')
    return process.nextTick(
      callback,
      new TypeError('argument should be string')
    );
}
```

위에서 인자를 확인 후 제대로 된 이자가 아니면 callback 에 오류를 전달한다. 사용자에게 오류를 다시 전달하고 있지만 그 우에 사용자의 남은 코드를 실행할 수 있다.  
`process.nextTick()` 을 사용하면 위의 apiCall() 이 나머지 사용자 코드 이후 부분과 Event Loop 가 진행되기 전에 항상 callback 을 실행할 수 있다.  
그러기 위해 JS 호출 스택은 제공된 callback 을 즉시 실행하여 개발자가 `RangeError: Maximum call stack size exceeded from v8` 에 도달하지 않고 
`process.nextTick()` 을 재귀호출할 수 있게 한다.

이러한 철학은 잠재적인 문제 상황을 만들 수 있다. 

```javascript
let bar;

// 비동기 시그니처를 갖지만, 동기로 콜백을 호출합니다.
function someAsyncApiCall(callback) {
  callback();
}

// `someAsyncApiCall`이 완료되면 콜백을 호출한다.
someAsyncApiCall(() => {
  // someAsyncApiCall는 완료되었지만, bar에는 어떤 값도 할당되지 않았다.
  console.log('bar', bar); // undefined
});

bar = 1;
```

개발자가 someAsyncApiCall() 을 비동기 시그니처로 정의했지만 실제로는 동기로 동작한다.  이 함수가 호출되었을 때 someAsyncApiCall() 가 실제로 비동기로 아무것도 하지 않으므로
someAsyncApiCall() 에 전달된 callback 은 Event Loop 의 같은 단계에서 호출된다. 따라서 이 스크립트는 완료 단계까지 실행되지 않았으므로 이 범위에서는 bar 변수가 없을 수 있는데
그래도 callback 이 bar 를 참조하려고 시도한다.

process.nextTick() 에 callback 을 두면 스크립트는 여전히 완료될 때까지 실행할 수 있는 기능을 가지고 있어 콜백이 호출되기 전에 모든 변수, 함수 등을 초기화할 수 있다.
이는 Event Loop 가 계속 진행되지 않도록 하는 장점도 있다. Event Loop 가 계속 진행되기 전에 사용자에게 오류 알림을 줄 때 유용하다.

아래는 바로 위의 코드를 `process.nextTick()` 으로 변경한 것이다.

```javascript
let bar;

function someAsyncApiCall(callback) {
  process.nextTick(callback);
}

someAsyncApiCall(() => {
  console.log('bar', bar); // 1
});

bar = 1;
```

---


# 4. `process.nextTick()` vs `setImmediate()`

- `process.nextTick()`
  - 같은 단계에서 바로 실행됨
- `setImmediate()`
  - 이어지는 순회나 Event Loop 의 `tick` 에서 실행됨

`setImmediate()` 보다 `process.nextTick()` 이 더 즉시 실행되기 때문에 두 함수의 이름이 바뀌어야 할 것 같지만 이는 과거의 유산(?) 이고 
이 둘이 바뀌면 수많은 npm 패키지가 깨질 것이라고 한다.

**`setImmediate()` 가 예상하기 더 쉬우므로 모든 경우에 `setImmediate()` 사용을 권장한다.**

---

# 5. `process.nextTick()` 을 사용하는 이유

두 가지 이유가 있다.

- 사용자가 Event Loop 를 계속하기 전에 오류를 처리하고 불필요한 자원을 정리 후 요청을 다시 시도할 수 있도록 함
- 호출 스택이 해제된 후 Event Loop 가 계속 진행되기 전에 callback 을 실행해야 하는 경우

```javascript
const server = net.createServer();
server.on('connection', (conn) => {});

server.listen(8080);
server.on('listening', () => {});
```

listen() 이 Event Loop 시작부분에서 실행되었지만 listening callback 은 setImmediate() 에 있다. 바인딩할 host name 을 전달하지 않는 한 포트는 즉시 적용될 것이다.
Event Loop 를 진행하려면 Poll 단계에 도달해야 하는데 이 말은 listening 이벤트 전에 connection 이벤트가 발생하도록 해서 connection 을 받을 가능성이 있다는 것이다. 

아래는 `EventEmmitter` 를 상속받고 생성자 내에서 이벤트를 호출하는 함수 생성자를 실행하는 것이다.

```javascript
const EventEmitter = require('events');
const util = require('util');

function MyEmitter() {
  EventEmitter.call(this);
  this.emit('event');
}
util.inherits(MyEmitter, EventEmitter);

const myEmitter = new MyEmitter();
myEmitter.on('event', () => {
  console.log('an event occurred!');
});
```

사용자가 callback 을 이벤트에 할당한 시점에 스크립트가 실행되는 것이 아니므로 생성자에서 발생시킨 이벤트는 즉시 실행되지 않는다.  
만일 생성자 안에서 생성자가 완료된 후 이벤트를 발생시키는 callback 을 설정하려면 `process.nextTick()` 을 사용하면 된다.

```javascript
const EventEmitter = require('events');
const util = require('util');

function MyEmitter() {
  EventEmitter.call(this);

  // 핸들러가 할당되면 이벤트를 발생시키려고 nextTick을 사용합니다.
  process.nextTick(() => {
    this.emit('event');
  });
}
util.inherits(MyEmitter, EventEmitter);

const myEmitter = new MyEmitter();
myEmitter.on('event', () => {
  console.log('an event occurred!');
});
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [Event Loop 공식 문서](https://nodejs.org/ko/docs/guides/event-loop-timers-and-nexttick/)
* [Node.js event loop workflow & lifecycle in low level - Blog](https://www.voidcanvas.com/nodejs-event-loop)