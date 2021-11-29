---
layout: post
title:  "Node.js - 이벤트, 예외처리"
date:   2021-11-29 10:00
categories: dev
tags: nodejs event exception
---

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - 이벤트(중요)
> - 예외 처리
> - 자주 발생하는 에러들

---

## 1. 이벤트 (중요)

[Node.js - 파일시스템](https://assu10.github.io/dev/2021/11/28/nodejs-filesystem/) 에서 스트림에 대해 볼 때 `on('data', callback)` 과
같은 코드를 사용하였다.

`on('data', callback)` 는 data, end 라는 이벤트가 발생할 때 콜백 함수를 호출하도록 이벤트를 등록한 것이다.

```javascript
readStream.on('data', chunk => {
data.push(chunk);
console.log('data: ', chunk, chunk.length);
});
```

`createReadStream` 의 경우 내부적으로 알아서 `data`, `end` 이벤트를 호출하지만 직접 이벤트를 만들 수도 있다.

event.js
```javascript
const EventEmitter = require('events');

const myEvent = new EventEmitter();
myEvent.addListener('event1', () => {
  console.log('이벤트1');
});
// event2 에 여러 개의 이벤트 리스너 등록
myEvent.on('event2', () => {
  console.log('이벤트2');
});
myEvent.on('event2', () => {
  console.log('이벤트2 추가');
});
// 한 번만 실행됨
myEvent.once('event3', () => {
  console.log('이벤트3');
});

myEvent.emit('event1'); // 이벤트 호출
myEvent.emit('event2');

myEvent.emit('event3');
myEvent.emit('event3'); // 실행 안 됨

myEvent.on('event4', () => {
  console.log('이벤트4');
});
myEvent.removeAllListeners('event4');
myEvent.emit('event4'); // 실행 안 됨

const listener = () => {
  console.log('event5');
};
myEvent.on('event5', listener);
myEvent.removeListener('event5', listener);
myEvent.emit('event5'); // 실행 안 됨

console.log(myEvent.listenerCount('event2'));
```

```shell
이벤트1
이벤트2
이벤트2 추가
이벤트3
2
```

- `on(이벤트명, 콜백)`
  - 이벤트명과 이벤트 발생 시의 콜백을 연결하는데 이러한 동작을 **이벤트 리스닝**이라고 함
  - event2 처럼 이벤트 하나에 여러 개의 리스너를 연결할 수도 있음  
- `addListener(이벤트명, 콜백)`
  - on 과 같은 기능
- `emit(이벤트명)`
  - 이벤트 호출
  - 이벤트명을 인수로 넣으면 미리 등록해두었던 콜백이 실행됨
- `once(이벤트명, 콜백)`
  - 한 번만 실행되는  이벤트
- `removeAllListeners(이벤트명)`
  - 이벤트에 연결된 모든 이벤트 리스너 제거
- `removeListener(이벤트명, 리스너)`
  - 이벤트에 연결된 리스터를 하나씩 제거
- `off(이벤트명, 콜백)`
  - 노드 10 에서 추가된 메서드로 removeListener 와 같은 기능
- `listenerCount(이벤트명)`
    - 등록된 리스터의 개수 조회

`on('data')` 도 겉으론 이벤트를 호출하지 않지만 내부적으로 chunk 를 전달할 때마다 data 이벤트를 emit 하고 있고, 완료되었을 경우 end 이벤트를 emit 한 것이다.

직접 이벤트를 만들 수 있어서 다양한 동작을 구현할 수 있으므로 실무에서 많이 사용된다.

---

## 2. 예외 처리

멀티 스레드 프로그램에서는 스레드 하나가 멈추면 그 일은 다른 스레드가 대신 하지만 노드의 메인 스레드는 하나뿐이므로 메인 스레드가 에러로 인해 멈추면
스레드를 갖고 있는 프로세스가 멈춘다는 뜻이고, 전체 서버도 멈춘다는 뜻이다.

에러가 발생하면 에러 로그가 기록되더라도 작업은 계속 진행될 수 있어야 한다.

아래는 `try/catch` 로 에러를 처리하는 예시이다.

error1.js
```javascript
setInterval(() => {
  console.log('START');
  try {
    throw new Error('ERROR');
  } catch (err) {
    console.error(err);
  }
}, 1000);
```

```shell
START
Error: ERROR
    at Timeout._onTimeout (/Users/juhyunlee/Developer/01_nodejs/mynode/chap03-event/src/2-error1.js:4:11)
    at listOnTimeout (node:internal/timers:557:17)
    at processTimers (node:internal/timers:500:7)
START
Error: ERROR
    at Timeout._onTimeout (/Users/juhyunlee/Developer/01_nodejs/mynode/chap03-event/src/2-error1.js:4:11)
    at listOnTimeout (node:internal/timers:557:17)
    at processTimers (node:internal/timers:500:7)
    // 계속 반복
```

아래는 노드 자체에서 잡아주는 에러 처리이다.

error2.js
```javascript
const fs = require('fs');

setInterval(() => {
  fs.unlink('./ddd.js', err => {
    if (err) {
      console.error(err);
    }
  });
}, 1000);
```

```shell
[Error: ENOENT: no such file or directory, unlink './ddd.js'] {
  errno: -2,
  code: 'ENOENT',
  syscall: 'unlink',
  path: './ddd.js'
}
[Error: ENOENT: no such file or directory, unlink './ddd.js'] {
  errno: -2,
  code: 'ENOENT',
  syscall: 'unlink',
  path: './ddd.js'
}
// 계속 반복
```

아래는 프로미스의 에러이다.

error3.js
```javascript
const fs = require('fs').promises;

setInterval(() => {
  fs.unlink('./ddd.js');
}, 1000);
```

```shell
node:internal/process/promises:246
          triggerUncaughtException(err, true /* fromPromise */);
          ^

[Error: ENOENT: no such file or directory, unlink './ddd.js'] {
  errno: -2,
  code: 'ENOENT',
  syscall: 'unlink',
  path: './ddd.js'
}
// 프로세스 멈춤
```

아래는 예측이 불가능한 에러 처리 방법이다.

error4.js
```javascript
process.on('uncaughtException', err => {
  console.error('예측치 못한 에러', err);
});

setInterval(() => {
  throw new Error('ERROR');
}, 1000);

setTimeout(() => {
  console.log('실행됨');
}, 2000);
```

```shell
예측치 못한 에러 Error: ERROR
    at Timeout._onTimeout (/Users/juhyunlee/Developer/01_nodejs/mynode/chap03-event/src/2-error4.js:6:9)
    at listOnTimeout (node:internal/timers:557:17)
    at processTimers (node:internal/timers:500:7)
실행됨
예측치 못한 에러 Error: ERROR
    at Timeout._onTimeout (/Users/juhyunlee/Developer/01_nodejs/mynode/chap03-event/src/2-error4.js:6:9)
    at listOnTimeout (node:internal/timers:557:17)
    at processTimers (node:internal/timers:500:7)
예측치 못한 에러 Error: ERROR
    at Timeout._onTimeout (/Users/juhyunlee/Developer/01_nodejs/mynode/chap03-event/src/2-error4.js:6:9)
    at listOnTimeout (node:internal/timers:557:17)
    at processTimers (node:internal/timers:500:7)
// 계속 반복
```

언뜻보면 `uncaughtException` 이벤트 리스너가 모든 에러를 처리할 수 있을 것처럼 보이지만 노드 공식 문서에서는 `uncaughtException` 이벤트를
최후의 수단으로 사용할 것을 명시하고 있다.<br />
노드는 `uncaughtException` 이벤트 발생 수 다음 동작이 제대로 동작하는지를 보증하지 않기 때문에 복구 작업 코드를 넣었더라도 그것이 동작하는지 확신할 수 없다.

따라서 `uncaughtException` 는 단순히 에러 내용을 기록하는 정도로 사용하고, 에러를 기록한 후 process.exit() 로 프로세스를 종료하는 것이 좋다.

---

## 3. 자주 발생하는 에러들

- `node: command not found`
  - 노드를 설치했지만 이 에러가 발생하면 환경 변수가 제대로 설정되지 않은 것
- `ReferenceError: 모듈 is not defined`
  - 모듈을 require 했는지 확인
- `Error: Cannot find module 모듈명`
  - 해당 모듈을 require 했지만 설치는 하지 않은 상태, npm i 로 설치 필요
- `Error: Can't set headers after they are sent`
  - 요청에 대한 응답을 보낼 때 응답을 두 번 이상 보낸 경우, 요청에 대한 응답은 한 번만 보내야 함
- `FATAL ERROR: CALL_END_REPLY_LAST Allocation failed - JavaScript heap out of memory`
  - 코드 실행 시 메모리가 부족하여 스크립트가 정상 작동하지 않은 경우
  - 코드가 잘못되었을 확률이 높으므로 코드 점검 필요
  - 코드가 정상이라면 노드 실행 시 `node --max-old-space-size=4096 파일명` 으로 노드 메모리 늘려서 해결 (4096 은 4GB)
- `UnhandledPromiseRejectionWarning: Unhandled promise rejection`
  - 프로미스 사용 시 catch 메서드 붙이지 않은 경우 발생
- `EACCESS 혹은 EPERM`
  - 노드가 작업을 수행하는데 권한이 충분하지 않음
  - 파일/폴더 수정/삭제/생성 권한 확인 필요
  - 맥/리눅스면 명령어 앞에 sudo 붙이는 것도 방법
- `ECONNREFUSED`
  - 요청을 보냈으나 연결이 성립하지 않은 경우
  - 요청을 받는 서버의 주소가 올바른지, 서버가 내려가있지는 않은지 확인 필요
- `ETARGET`
  - package.json 에 기록한 패키지 버전이 존재하지 않을 때 발생
- `ETIMEOUT`
  - 요청을 보냈으나 응답이 일정 시간 이내에 오지 않은 경우 발생
  - 요청을 받는 서버의 상태 점검 필요
- `ENOENT: no such file or directory`
  - 지정한 폴더나 파일이 존재하지 않는 경우

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [node.js 에러 코드](https://nodejs.org/dist/latest-v16.x/docs/api/errors.html#errors_node_js_error_codes)
* [uncaughtException](https://nodejs.org/dist/latest-v16.x/docs/api/process.html#process_event_uncaughtexception)