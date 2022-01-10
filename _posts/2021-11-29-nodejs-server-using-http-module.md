---
layout: post
title:  "Node.js - http 모듈로 서버 생성"
date:   2021-11-29 10:00
categories: dev
tags: nodejs
---

이 포스트는 실제 서버 동작에 필요한 쿠키와 세션 처리, 요청 주소별 라우팅 방법에 대해 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - 요청과 응답
> - REST 와 라우팅
> - 쿠키와 세션
> - https 와 http2
> - cluster

---

## 1. 요청과 응답

서버는 요청을 받는 부분과 응답을 보내는 부분이 있어야 한다.<br />
요청과 응답은 이벤트 방식이라고 생각하면 된다.<br />
클라이언트로부터 요청이 왔을 때 어떤 작업을 수행할 지 이벤트 리스터를 미리 등록해두어야 한다.

이제 이벤트 리스너를 가진 노드 서버를 만들어보도록 하자.

createServer.js
```javascript
const http = require('http');

http.createServer((req, res) => {
  // 응답 콜백
});
```

http 서버가 있어야 웹 브라우저의 요청을 처리할 수 있으므로 http 모듈을 사용한다.<br />
http 모듈에는 createServer 메서드가 있는데 인수로 요청에 대한 콜백 함수를 넣을 수 있으며, 요청이 올 때마다
콜백 함수가 실행된다.

이제 응답을 보내는 부분과 서버에 연결하는 부분을 추가해보자.

server1-1.js
```javascript
const http = require('http');

http
  .createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.write('hello');
    res.end('END');
  })
  .listen(8080, () => {
    // 서버 연결
    console.log('waiting 8080 port...');
  });
```

```shell
waiting 8080 port...
```

![localhost:8080](/assets/img/dev/2021/1129/localhost.png)

createServer 메서드 뒤에 listen 메서드를 붙여 클라이언트에 공개할 포트 번호와 포트 연결 완료 후 실행될 콜백 함수를 넣는다.

- `res.writeHead`
    - 헤더에 기록되는 정보
- `res.write`
    - body 에 기록되는 정보
    - 클라이언트에 보낼 데이터
- `res.end`
    - 응답을 종료하는 메서드
    - 인수가 있다면 그 데이터도 클라이언트로 보내고 응답을 종료

> 80 포트를 사용하면 주소에서 포트 생략이 가능하다.<br />
> https 의 경우 443 포트 생략이 가능하다.<br />
> 리눅스/맥의 경우 1024번 이하의 포트에 연결 시엔 관리자 권한이 필요하기 때문에 1024 이하의 포트 사용 시 sudo node server1 로 실행하여야 한다.

위의 listen 메서드에 콜백 함수를 넣는 대신 서버에 listening 이벤트 리스너를 붙여서 사용할 수도 있다.

server1-2.js
```javascript
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.write('hello');
  res.end('END');
});
server.listen(8080);

server.on('listening', () => {
  console.log('waiting 8080 port...');
});

server.on('error', err => {
  console.error(err);
});
```

한 번에 여러 서버를 실행할 수도 있다.

server1-3.js
```javascript
const http = require('http');

http
  .createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.write('hello');
    res.end('END');
  })
  .listen(8080, () => {
    // 서버 연결
    console.log('waiting 8080 port...');
  });

http
  .createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.write('hello');
    res.end('END');
  })
  .listen(8081, () => {
    // 서버 연결
    console.log('waiting 8081 port...');
  });
```

```shell
waiting 8080 port...
waiting 8081 port...
```

res.write, res.end 에 일일이히 HTML 을 적는 대신 HTML 을 미리 만들어 두고 그 파일을 fs 모듈로 읽어서 전송하도록 해보자.

server2.js
```javascript
const http = require('http');
const fs = require('fs').promises;

http
  .createServer(async (req, res) => {
    try {
      const data = await fs.readFile('server2.html');
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(data); // 저장된 버퍼를 그대로 클라이언트로 전달
    } catch (err) {
      console.error(err);
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(err.message);
    }
  })
  .listen(8080, () => {
    console.log('wait 8080 port...');
  });
```

---

## 2. REST 와 라우팅

REST 에 관한 내용은 따로 구글링하여 찾아보세요. ^^

> GET 메서드의 경우 브라우저에서 캐싱할 수도 있으므로 같은 주소로 GET 요청을 할 때 서버에서 가져오는 것이 아니라 캐시에서 갸져올 수도 있다.

`res.end()` 를 호출한다고 해서 함수가 종료되는 것은 아니다.

노드도 일반적인 자바스크립트 문법을 따르므로 return 을 붙이지 않는 한 함수가 종료되지 않는다.<br />
return 을 붙이지 않아서 res.end 같은 메서드가 여러 번 실행되면 `Error: Can't set headers after they are sent to the client.` 에러가 발생한다.

```javascript
const data = await fs.readFile('restFront.html');
res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
return res.end(data);
```

req, res 모두 내부적으로는 Stream (readStream, writeStream) 으로 되어있기 때문에 요청/응답의 데이터가 Stream 형식으로 전달된다.

```javascript
// 요청 body 를 stream 형식으로 받음
req.on('data', data => {
  body += data;
});
// 요청 body 다 받은 후 실행
return req.on('end', () => {
  console.log('POST body: ', body);
  const { name } = JSON.parse(body);
  const id = Date.now();
  users[id] = name;
  res.writeHead(201, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('ok');
});
```

---

## 3. 쿠키와 세션

쿠키는 요청의 헤더(Cookie) 에 담겨 전송되고, 브라우저는 응답의 헤더(Set-Cookie) 에 따라 쿠키를 저장한다.

```javascript
const http = require('http');

http
  .createServer((req, res) => {
    console.log(req.url, req.headers.cookie);
    res.writeHead(200, { 'Set-Cookie': 'mycookie=test' });
    res.end('쿠키 완료');
  })
  .listen(8080, () => {
    console.log('8080...');
  });
```

```shell
8080...
/ undefined
/ mycookie=test
```

쿠키는 *name=assu;age=20* 처럼 세미콜론으로 구분된 문자열이다.

또한 응답의 헤더에 쿠키를 기록해야 하므로 *res.writeHead* 메서드를 사용한다.

아래는 쿠키와 세션을 사용한 예이다.

cookie2.js
```javascript
const http = require('http');
const fs = require('fs').promises;
const url = require('url');
const qs = require('querystring');

// 문자열의 쿠키를 { aa: bb } 형태의 객체 형식으로 변환
const parseCookies = (cookie = '') =>
  cookie
    .split(';')
    .map(v => v.split('='))
    .reduce((acc, [k, v]) => {
      acc[k.trim()] = decodeURIComponent(v);
      return acc;
    }, {});

const session = {};

http
  .createServer(async (req, res) => {
    const cookies = parseCookies(req.headers.cookie); // {mycookie: 'test}

    if (req.url.startsWith('/login')) {
      const { query } = url.parse(req.url);
      const { name } = qs.parse(query);
      const expires = new Date();
      // 쿠키 유효 시간을 현재시간 + 5분으로 설정
      expires.setMinutes(expires.getMinutes() + 5);

      const uniqueInt = Date.now();
      session[uniqueInt] = {
        name,
        expires,
      };
      res.writeHead(302, {
        Location: '/',
        'Set-Cookie': `session=${uniqueInt}; Expires=${expires.toGMTString()}; HttpOnly; Path=/`,
      });
      res.end();
      // 세션 쿠키가 존재하고, 만료 기간 전인 경우
    } else if (
      cookies.session &&
      session[cookies.session].expires > new Date()
    ) {
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(`${session[cookies.session].name} 님~`);
    } else {
      try {
        const data = await fs.readFile('cookie2.html');
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(data);
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(err.message);
      }
    }
  })
  .listen(8080, () => {
    console.log('waiting 8080...');
  });
```

아래 부분을 보면 HTTP 응답 코드를 302 로 보낸다.<br />
브라우저는 이 응답 코드를 보고 이 페이지를 해당 주소로 리다이렉트 한다.<br />
헤더에는 한글을 설정할 수 없으므로 한글이 있다면 encodeURIComponent 메서드로 인코딩해야 한다.<br />
Set-Cookie 의 값으로는 제한된 ASCII 코드만 들어가야 하므로 줄바꿈은 넣으면 안된다.

```javascript
res.writeHead(302, {
  Location: '/',
  'Set-Cookie': `session=${uniqueInt}; Expires=${expires.toGMTString()}; HttpOnly; Path=/`,
});

// 한글이 있는 경우는
es.writeHead(302, {
  Location: '/',
  'Set-Cookie': `name=${encodeURIComponent(
          name,
  )}; Expires=${expires.toGMTString()}; HttpOnly; Path=/`,
});
```

- `쿠키명=쿠키값`
- `Expires=날짜`
  - 기본값은 클라이언트가 종료될 때 까지임
- `Max-age=초`
  - Expires 와 비슷하지만 날짜 대신 초를 입력, Expires 보다 우선함
- `Domain=도메인명`
  - 쿠키가 전송될 도메인을 특정함, 기본값은 현재 도메인.
- `Path=URL`
  - 쿠키가 전송될 URL 을 특정함, 기본값은 `/` 이고, 이 경우 모든 URL 에서 쿠키 전송 가능
- `Secure`
  - true: HTTPS 일 경우에만 쿠키 전송
  - false: HTTPS 가 아닌 환경에서도 쿠키 전송
- `HttpOnly`
  - 설정 시 자바스크립트에서 쿠키에 접근할 수 없음(즉, 클라이언트에서 쿠키 확인 불가), 쿠키 조작 방지를 위해 설정하는 것이 좋음

위처럼 하는 방식이 `세션`이다.<br />
서버에 사용자 정보를 저장하지 않고 클라이언트와는 세션 아이디로만 소통한다.<br />
세션을 위해 사용하는 쿠키를 `세션 쿠키` 라고 한다.

> 세션 쿠키에 대한 상세한 내용은
> [Node.js - Express (1): 미들웨어](https://assu10.github.io/dev/2021/12/01/nodejs-express-1/) 의 *2.5. `express-session`* 을
> 참고하세요.

실제 운영 서버에서는 세션을 위처럼 변수에 저장하지 않는다.<br />
서버가 멈추거나 재시작되면 메모리에 저장된 변수가 초기화되고, 서버의 메모리가 부족하면 세션을  저장하지 못하는 문제도 생긴다.<br />
따라서 보통은 레디스나 맴캐시  드 같은 DB 에 저장한다.

**위의 코드는 쿠키를 악용한 여러 위협에 방어하지 못하므로 개념만 익혀두는 용도로 보고 절대 실제 서비스에 사용해서는 안된다.**

> 실제 서비스에 사용할 수 있는 쿠키와 세션은 
> [Node.js - Express (1): 미들웨어](https://assu10.github.io/dev/2021/12/01/nodejs-express-1/) 의 *2.5. `express-session`* 을
> 참고하세요.

---

## 4. https 와 http2

https 모듈은 웹 서버에 SSL 암호화를 추가한다.

http2 모듈은 SSL 암호화와 더불어 최신 HTTP 프로토콜인 http/2 를 사용할 수 있게 한다.<br />
http/2 는 요청 및 응답 방식이 기존 http/1.1 보다 개선되어 훨씬 효율적으로 요청을 보내어 웹의 속도도 많이 개선된다. (한번에 여러 리소스 요청 가능)


---

## 5. cluster

cluster 모듈은 기본적으로 싱글 프로세스로 동작하는 노드가 CPU 코어를 모두 사용할 수 있도록 해주는 모듈이다.

포트를 공유하는 노드 프로세스를 여러 개 둘 수 있으므로 요청이 많이 들어왔을 대 병렬로 실행된 서버의 개수만큼 요청이 분산되게 할 수 있다.

메모리를 공유하지 못하는 단점이 있으므로, 세션을 메모리에 저장하고 있다면 레디스 등의 서버를 도입하는 방식을 고려해보아야 한다.

직접 cluster 모듈로 클러스터링을 구현할 수도 있지만 실무에서는 pm2 등의 모듈로 cluster 기능을 사용한다.<br />
아래 예시는 기본 노드 문법을 보는 정도로만 가볍게 보도록 하자.

cluster.js
```javascript
const cluster = require('cluster');
const http = require('http');
const numCPUs = require('os').cpus().length;

if (cluster.isMaster) {
  console.log(`마스터 프로세스 아이디: ${process.pid}`);
  // CPU 개수만큼 워커를 생산
  for (let i = 0; i < numCPUs; i += 1) {
    cluster.fork();
  }
  // 워커가 종료되었을 때
  cluster.on('exit', (worker, code, signal) => {
    console.log(`${worker.process.pid}번 워커가 종료되었습니다.`);
    console.log('code', code, 'signal', signal);
    cluster.fork();
  });
} else {
  // 워커들이 포트에서 대기
  http
    .createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.write('<h1>Hello Node!</h1>');
      res.end('<p>Hello Cluster!</p>');
      setTimeout(() => {
        // 워커 존재를 확인하기 위해 1초마다 강제 종료
        process.exit(1);
      }, 1000);
    })
    .listen(8086);

  console.log(`${process.pid}번 워커 실행`);
}
```

```shell
마스터 프로세스 아이디: 70017
70020번 워커 실행
70018번 워커 실행
70019번 워커 실행
70021번 워커 실행
70022번 워커 실행
70026번 워커 실행
```

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [쿠키](https://developer.mozilla.org/ko/docs/Web/HTTP/Cookies)
* [세션](https://developer.mozilla.org/ko/docs/Web/HTTP/Session)
* [http 모듈 설명](https://nodejs.org/dist/latest-v16.x/docs/api/http.html)
* [https 모듈 설명](https://nodejs.org/dist/latest-v16.x/docs/api/https.html)
* [http2 모듈 설명](https://nodejs.org/dist/latest-v16.x/docs/api/http2.html)
* [cluster 모듈 설명](https://nodejs.org/dist/latest-v16.x/docs/api/cluster.html)