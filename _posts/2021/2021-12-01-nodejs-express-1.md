---
layout: post
title:  "Node.js - Express (1): 미들웨어"
date: 2021-12-01 10:00
categories: dev
tags: javascript nodejs express middleware morgan static body-parser cookie-parser express-session multer
---

이 포스트는 Express 에 대해 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - Express 사용
> - 미들웨어
>   - `morgan`
>   - `static`
>   - `body-parser`
>   - `cookie-parser`
>   - `express-session`
>   - 미들웨어 내용 정리
>   - `multer`
>     - `upload.single('img')` - req.file 객에체 하나의 파일만 업로드
>     - `upload.array('imgs')` - req.files 객체에 input 태그의 name 이 동일한 여러 개의 파일을 업로드
>     - `upload.fields([{ name: 'imagename1' }, { name: 'imagename2' }])` - req.files 객체에 input 태그의 name 이 다른 여러 개의 파일을 업로드 
>     - `upload.none()` - 파일 업로드 없이 텍스트 데이터만 multipart 형식으로 전송

---

npm 에는 **서버를 제작하는 과정에서의 불편함을 해소하고 편의 기능을 추가한 Express 라는 웹 서버 프레임워크**가 있다.

웹 서버 프레임워크에 Express 외에도 koa, hapi 같은 프레임워크가 있지만 아래 그래프를 보면 express 가 npm 패키지 다운로드 수가 월등히 높은 것을 알 수 있다. 

![https://www.npmtrends.com/express-vs-hapi-vs-koa](/assets/img/dev/2021/1201/express-hapi-koa.png)

---

# 1. Express 사용

`npm init --y` 명령어로 package.json 을 생성한 후 express 와 nodemon 패키지를 설치한다.

```shell
> npm init --y

> npm i express
> npm i -D nodemon
```

package.json
```json
{
  "name": "chap06",
  "version": "1.0.0",
  "description": "learn express",
  "main": "app.js",
  "scripts": {
    "start": "nodemon app"
  },
  "author": "assu",
  "license": "ISC",
  "devDependencies": {
    "eslint": "^8.3.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-prettier": "^4.0.0",
    "nodemon": "^2.0.15",
    "prettier": "2.5.0"
  },
  "dependencies": {
    "express": "^4.17.1"
  }
}
```

scripts 부분에 `start` 속성 `nodemon app` 을 기입한 후 `nodemon app` 으로 서버를 실행한다. (nodemon 으로 app.js 를 실행한다는 의미)<br />
서버 코드에 수정 사항이 생길때마다 매번 서버를 재시작하기 귀찮은데 nodemon 모듈로 서버를 자동으로 재시작하게 해준다.

nodemon 이 실행되는 콘솔에 `rs` 를 입력하여 수동으로 재시작할 수도 있다.

운영 환경에서는 서버 코드가 빈번하게 변경될 일이 없으므로 nodemon 은 개발용으로만 사용하는 것을 권장한다. 

app.js
```javascript
const express = require('express');

const app = express();
app.set('port', process.env.PORT || 3000);

app.get('/', (req, res) => {
  res.send('Hello~');
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트 대기중');
});
```

express 내부에 http 모듈이 내장되어 있으므로 서버의 역할을 할 수 있다.

express 에서는 `res.write`, `res.end` 대신 `res.send` 를 사용한다.<br />
`res.writeHead`, `res.write`, `res.end` 등의 메서드는 http 모듈의 기능이고, <br />
`res.send`, `res.sendFile` 은 express 가 추가한 메서드이다.

app.get 외에도 app.post, app.put, app.patch, app.delete, app.options 메서드가 존재한다.


`npm start` 로 서버를 실행해보자.

```shell
> npm start        

> chap06@1.0.0 start
> nodemon app

[nodemon] 2.0.15
[nodemon] to restart at any time, enter `rs`
[nodemon] watching path(s): *.*
[nodemon] watching extensions: js,mjs,json
[nodemon] starting `node app.js`
3000 번 포트 대기중
rs
[nodemon] starting `node app.js`
3000 번 포트 대기중
```

문자열 대신 파일로 응답하려면 `res.sendFile` 을 이용한다.

```javascript
const express = require('express');
const path = require('path');

const app = express();
app.set('port', process.env.PORT || 3000);

app.get('/', (req, res) => {
  //res.send('Hello~');
  console.log(__dirname);
  res.sendFile(path.join(__dirname, '/index.html'));
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트 대기중');
});
```

```shell
/Users/assu/Developer/01_nodejs/mynode/chap06
```

---

# 2. 미들웨어

미들웨어는 express 의 핵심이다.<br />
요청과 응답의 중간에 위치하여 미들웨어라고 부른다. 라우터와 에러 핸들러 또한 미들웨어의 일종이다.

미들웨어는 `app.use` 와 함께 사용된다. 예) `app.use(미들웨어)`

express 서버에 미들웨어를 연결해보자.

app.js
```javascript
const express = require('express');

const app = express();
app.set('port', process.env.PORT || 3000);

app.use((req, res, next) => {
  console.log('모든 요청에 다 실행됨');
  next();
});

app.get(
  '/',
  (req, res, next) => {
    console.log('GET / 요청에서만 실행됨');
    next();
  },
  (req, res) => {
    throw new Error('에러는 에러 처리 미들웨어로 보냄');
  },
);

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트 대기중');
});
```

미들웨어는 `app.use` 에 매개 변수가 `req, res, next 인 함수`를 넣으면 된다.<br />
미들웨어는 위에서 아래로 순서대로 실행되면서 요청과 응답 사이에 특별한 기능을 추가할 수 있다.

**next 라는 세 번째 매개변수는 다음 미들웨어로 넘어가는 함수**이다.<br />
next 를 실행하지 않으면 다음 미들웨어가 실행되지 않는다.

주소를 첫 번째 매개변수로 넣지 않으면 미들웨어는 모든 요청에서 실행되고, 주소를 넣으면 해당 요청에서만 실행된다.

예) `app.use(미들웨어)` - 모든 요청에서 미들웨어 실행<br />
`app.use('/aa', 미들웨어)` - aa 로 시작하는 요청에서 미들웨어 실행<br />
`app.post('/aa', 미들웨어)` - aa 로 시작하는 POST 요청에서 미들웨어 실행

app.use 나 app.get 같은 라우터에 미들웨어를 여러 개 붙일 수도 있다. 위 코드에선 app.get 라우터에 미들웨어 2개가 연결되어 있다.

```javascript
app.get(
  '/',
  (req, res, next) => {     // 첫 번째 미들웨어
    console.log('GET / 요청에서만 실행됨');
    next();
  },
  (req, res) => {           // 두 번째 미들웨어
    throw new Error('에러는 에러 처리 미들웨어로 보냄');
  },
);
```

에러 처리 미들웨어는 매개 변수가 err, req, res, next 로 4개이다.<br />
모든 매개 변수를 사용하지 않아도 매개 변수는 반드시 4개 이어야 한다.<br />
res.status 로 HTTP 상태 코드를 지정할 수 있는데 기본값은 200 이다.

에러 처리 미들웨어를 직접 연결하지 않아도 기본적으로 express 가 에러를 처리하지만 실무에서는 직접 에러 처리 미들웨어를 연결해주는 것이 좋다.

에러 처리 미들웨어는 특별한 경우가 아니면 가장 아래에 위치하도록 한다.

> 에러 처리 미들웨어에 대한 상세 내용은
> [Node.js - Express (2): 라우터, 템플릿 엔진](https://assu10.github.io/dev/2021/12/02/nodejs-express-2/) 의
> *4. 에러 처리 미들웨어* 를 참고하세요.

localhost:3000 에 접속하면 콘솔에 아래와 같이 출력된다.

```shell
모든 요청에 다 실행됨
GET / 요청에서만 실행됨
Error: 에러는 에러 처리 미들웨어로 보냄
    at /Users/assu/Developer/01_nodejs/mynode/chap06/app.js:18:11
    at Layer.handle [as handle_request] (/Users/assu/Developer/01_nodejs/mynode/chap06/node_modules/express/lib/router/layer.js:95:5)
    at next (/Users/assu/Developer/01_nodejs/mynode/chap06/node_modules/express/lib/router/route.js:137:13)
    at /Users/assu/Developer/01_nodejs/mynode/chap06/app.js:15:5
```

실무에서 자주 사용하는 미들웨어 패키지들에 대해 알아보자.

```shell
> npm i morgan cookie-parser express-session dotenv
```

`dotenv` 를 제외한 다른 패키지는 미들웨어로 process.env 를 관리하기 위해 사용한다.

app.js
```javascript
const express = require('express');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config();
const app = express();
app.set('port', process.env.PORT || 3000);

app.use(morgan('dev'));

app.use('/', express.static(path.join(__dirname, 'public')));

app.use(express.json());
app.use(express.urlencoded({ extended: false }));

app.use(cookieParser(process.env.COOKIE_SECRET));

app.use(
        session({
          resave: false,
          saveUninitialized: false,
          secret: process.env.COOKIE_SECRET,
          cookie: {
            // 세션 쿠키에 대한 설정
            httpOnly: true,
            secure: false,
          },
          name: 'session-cookie', // 세션 쿠키명 (기본값은 connect.sid)
        }),
);

app.use((req, res, next) => {
  console.log('모든 요청에 다 실행됨');
  next();
});

app.get(
        '/',
        (req, res, next) => {
          console.log('GET / 요청에서만 실행됨');
          next();
        },
        (req, res) => {
          throw new Error('에러는 에러 처리 미들웨어로 보냄');
        },
);

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트 대기중');
});

```

.env
```text
COOKIE_SECRET=cookiesecret
```

설치한 패키지들을 불러온 뒤 app.use 에 연결한다.<br />
req, res, next 가 없는 이유는 미들웨어 내부에 이미 들어있기 때문이다. next 도 내부적으로 호출하기 때문에 다음 미들웨어로 넘어갈 수 있다.

`dotenv` 패키지는 `.env` 파일을 읽어서 process.env 로 만든다.<br />
process.env.COOKIE_SECRET 에 cookiesecret 값이 할당된다.

process.env 를 별도의 파일로 관리하는 이유는 보안과 설정의 편의성 때문이다.<br />
비밀키들을 소스 코드에 그대로 적어두면 소스 코드가 유철되었을 때 키도 같이 유출되는데 .env 같은 별도의 파일에 비밀 키를 적어두고
dotenv 패키지로 비밀 키를 로딩하는 방식으로 관리하면 소스 코드가 유출되더라도 .env 파일만 잘 관리하면 비밀 키는 지킬 수 있다.

---

## 2.1. `morgan`

```javascript
app.use(morgan('dev'));
```

`morgan` 연결 후 localhost:3000 으로 접속 시 기존에 나오던 로그 외에 추가적인 로그를 볼 수 있다.

```shell
3000 번 포트 대기중
모든 요청에 다 실행됨
GET / 요청에서만 실행됨
Error: 에러는 에러 처리 미들웨어로 보냄
// 에러 스택 트레이스 생략
GET / 500 8.151 ms - 46
```

콘솔의 **GET / 500 8.151 ms - 46** 는 morgan 미들웨어에서 나오는 것이다.<br />
morgan 미들웨어는 요청과 응답에 대한 정보를 콘솔에 기록하여 요청과 응답을 한 눈에 볼 수 있어 편하다.

인수로 dev 외에 combined, common, short, tiny 등을 넣을 수 있고, 각 인수바다 로그가 달라진다.<br />
주로 개발 환경에서는 dev, 배포 환경에서는 combined 를 사용한다.

**GET / 500 8.151 ms - 46** 는 `[HTTP 메서드][주소][HTTP 상태코드][응답 속도][응답 바이트]` 를 의미한다.

---

## 2.2. `static`

```javascript
app.use('/', express.static(path.join(__dirname, 'public')));
```

static 미들웨어는 정적인 파일들을 제공하는 라우터 역할을 한다.<br />
기본적으로 제공되기 때문에 따로 설치할 필요 없이 express 객체 안에서 꺼내쓰면 된다.

`app.use('요청 경로', express.static('실제 경로'))`

예) **app.use('/', express.static(path.join(__dirname, 'public')));**

예를 들어 public/css/style.css 에 css 파일이 있다면 http://localhost:3000/css/style.css 으로 접근이 가능하다.

서버 폴더 경로와 요청 경로가 다르기 때문에 외부인이 서버의 구조를 쉽게 파악할 수 없다.

또한 정적 파일을 알아서 제공해주기 때문에 fs.readFile 로 파일을 직접 읽어서 전송할 필요도 없다.<br />
요청 경로에 해당 파일이 없으면 알아서 내부적으로 next 를 호출하고, 파일을 발견하면 응답으로 파일을 보내고 다음 미들웨어는 호출하지 않는다.

---

## 2.3. `body-parser`

```javascript
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
```

`body-parser` 는 요청 본문에 있는 데이터를 해석하여 `req.body` 객체로 만들어주는 미들웨어이다.<br />
단, multiPart (이미지, 동영상, 파일) 데이터는 처리하지 못한다. 이런 경우는 뒤에 나올 `multer` 모듈을 사용한다.

express 4.16.0 부터 body-parser 미들웨어의 일부 기능이 express 에 내장되어 따로 설치할 필요는 없지만 버퍼나 텍스트 형식의
데이터 처리시엔 따로 설치해서 사용해서 한다.

body-parser 는 JSON, URL-encoded 형식 외 Raw, Text 형식의 데이터도 추가로 해석할 수 있는데<br />
Raw 는 요청의 본문이 버퍼 데이터인 경우, Text 는 텍스트 데이터일 경우이다.

```shell
> npm i body-parser
```

```javascript
const bodyParser = require('body-parser');
app.use(bodyParser.raw());
app.use(bodyParser.text());
```

요청 데이터의 종류를 보면 아래와 같다.

- `JSON`
  - JSON 형식의 데이터 전달 방식
- `URL-encoded`
  - 주소 형식으로 데이터는 보내는 방식
  - 폼 전송은 URL-encoded 방식을 주로 사용
  - { extended: false }
    - false: 노드의 내장 모듈인 querystring 모듈을 사용하여 쿼리스트링 해석
    - true: npm 패키지인 qs 모듈을 사용하여 쿼리 스트링 해석

앞에서 POST, PUT 요청의 본문을 받을 때 req.on('data'), req.on('end') 로 스트림을 받았는데 body-parser 를 사용하면 body-parser 가
내부적으로 스트림을 처리해 req.body 에 추가해준다.

예를 들어 JSON 형식으로 { name: 'assu', age: 30 } 으로 본문을 보내면 req.body 에 그대로 들어가고,<br />
URL-encoded 형식인 name=assu&age=30 으로 본문을 보내면 req.body 에 { name: 'assu', age: 30 } 으로 들어간다.

---

## 2.4. `cookie-parser`

```javascript
app.use(cookieParser(process.env.COOKIE_SECRET));
```

`cookie-parser` 는 request 에 있는 쿠키를 해석하여 `req.cookies` 객체로 만든다.<br />
[Node.js - http 모듈로 서버 생성](https://assu10.github.io/dev/2021/11/29/nodejs-server-using-http-module/) 의 *3. 쿠키와 세션* 에 나온
parseCookies 함수와 비슷한 기능이다.

예를 들어 name=assu 쿠키가 있다면 req.cookie 는 *{ name: 'assu' }* 가 된다.<br />
유효기간이 지난 쿠키는 알아서 걸러낸다.

cookieParser 의 인수로 **비밀키** 를 넣어줄 수 있는데 서명된 쿠키가 있는 경우 제공한 비밀키를 통해 해당 쿠키가 내 서버에서 만든 쿠키임을 검증할 수 있다.

쿠키는 클라이언트에서 위조하기 쉽기 때문에 비밀키를 통해 만들어낸 서명을 쿠키값 뒤에 붙이는데 서명이 붙은 쿠키는 *name=assu.sign* 과 같은 모양이다.<br />
서명된 쿠키는 `req.cookie` 대신 `req.signedCookies` 객체에 들어간다.

주의할 것은 cookie-parser 가 쿠키를 생성할 때 쓰는게 아니라 쿠키를 해석하여 req 객체에 넣어주는 역할이라는 것이다.

쿠키를 생성/제거할 때는 `res.cookie`, `res.clearCookie` 메서드를 사용한다.<br />
`res.cookie(key, value, option)` 형식이다.

옵션은 [Node.js - http 모듈로 서버 생성](https://assu10.github.io/dev/2021/11/29/nodejs-server-using-http-module/) 의 *3. 쿠키와 세션* 에 나온
쿠키 옵션과 동일하다.

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


쿠키 생성 예시
```javascript
const expires = new Date();
  // 쿠키 유효 시간을 현재시간 + 5분으로 설정
  expires.setMinutes(expires.getMinutes() + 5);

  res.cookie('name', 'assu', {
    expires: expires,
    httpOnly: true,
    secure: true,
  });
```

쿠키를 제거하려면 키와 값, 옵션이 정확히 일치해야 한다. (단, expires, maxAge 옵션은 제외)

옵션 중에 `signed` 옵션을 true 로 설정 시 쿠키 뒤에 서명이 붙는다.<br />
내 서버에서 만든 쿠키임을 검증할 수 있으므로 대부분의 경우 서명 옵션을 활성화하는 것이 좋다.

---

## 2.5. `express-session`

```javascript
app.use(
  session({
    resave: false,
    saveUninitialized: false,
    secret: process.env.COOKIE_SECRET,
    cookie: {
      // 세션 쿠키에 대한 설정
      httpOnly: true,
      secure: false,
    },
    name: 'session-cookie', // 세션 쿠키명 (기본값은 connect.sid)
  }),
);
```

`express-session` 은 **세션 관리용 미들웨어** 이다.

세션은 사용자별로 `req.session` 객체 안에 유지된다.

> express-session 1.5 버전 이전에는 내부적으로 cookie-parser 를 사용하고 있어서 cookie-parser 미들웨어보다 뒤에 위치해야 했지만<br />
> 1.5 버전 이후부터는 사용하지 않게 되어 순서가 상관없어졌다.

`express-session` 은 인수로 세션에 대한 설정은 받는다.

- `resave`
  - 요청이 올 때 세션에 수정사항이 생기지 않아도 세션을 다시 저장할 지 여부
- `saveUninitialized`
  - 세션에 저장할 내역이 없어도 처음부터 세션을 생성할 지 여부
- `secret`
  - `express-session` 은 세션 관리 시 클라이언트로 쿠키를 보내는데 [Node.js - http 모듈로 서버 생성](https://assu10.github.io/dev/2021/11/29/nodejs-server-using-http-module/) 의 *3. 쿠키와 세션* 에 나온
  **세션 쿠키** 가 바로 이것임.
  - 안전하게 쿠키를 전송하려면 쿠키에 서명을 추가해야 하고, 쿠키를 서명하는데 **비밀키** 가 필요함
  - `cookie-parser` 의 `secret` 값과 동일하게 설정하는 것이 좋음
- `cookie`
  - 세션 쿠키에 대한 설정
  - maxAge, domain, path, expires, sameSite, httpOnly, secure 등 일반적인 쿠키 옵션이 모두 제공됨
- `name`
  - 세션 쿠키의 이름, 기본값은 **connect.sid**
- `store`
  - 지금은 메모리에 세션을 저장하고 있지만 서버 재시작 시 메모리가 초기화되어 세션이 사라지므로 배포 시에는 store 에 DB 를 연결하여 세션을 유지함

> `store` 로 레디스가 많이 사용되는데 사용법은 각자 알아보세요.

---

```javascript
req.session.name = 'assu';  // 세션 등록
req.sessionID;  // 세션 아이디 확인
req.session.destroy();  // 세션 모두 제거
```

`express-session` 으로 만들어진 req.session 객체에 값을 대입하거나 삭제하여 세션을 변경할 수 있다.

세션을 한번에 삭제하려면 `req.session.destroy()` 를 사용한다.

현재 세션의 아이디는 `req.sessionID` 로 확인한다.

세션을 강제로 저장하기 위해 `req.session.save()` 가 있긴한데, 일반적으로 요청이 끝날 때 자동으로 호출되기 때문에 직접 호출할 일은 거의 없다.

`express-session` 에서 서명한 세션 쿠키의 모양은 약간 특이한데 쿠키 앞에 `s:` 가 붙는다.<br />
실제로는 encodeURIComponent 함수가 실행되어 `s%3A` 가 된다.<br />
따라서 앞에 `s%3A` 가 붙은 경우 이 쿠키가 `express-session` 미들웨어에 의해 암호화된 것으로 생각하면 된다.

---

## 2.6. 미들웨어 내용 정리

지금까지 미들웨어를 직접 만들기도 하고, 미들웨어 패키지를 설치해 사용해보기도 하였다.

```javascript
app.use((req, res, next) => {
  console.log('모든 요청에 다 실행됨');
  next();
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});
```

미들웨어는 **req, res, next** 를 매개변수로 갖는 함수 (에러 처리 미들웨어만 예외적으로 **err, req, res, next**) 로서,<br />
`app.use` 나 `app.get`, `app.post` 등으로 장착하여 사용한다.<br />
특정 주소의 요청에만 미들웨어가 실행되게 하려면 첫 번째 인수에 주소를 넣으면 된다.

---

```javascript
app.use(
  morgan('dev'),
  express.static(path.join(__dirname, 'public')),
  express.json(),
  express.urlencoded({ extended: false }),
  cookieParser(process.env.COOKIE_SECRET)
);
```

이렇게 **동시에 여러 개의 미들웨어를 장착**할 수도 있고, 다음 미들웨어로 넘어가려면 next() 를 호출해야 하지만 위 미들웨어들은 내부적으로 next 를 호출하고 있기 때문에
연달아 사용이 가능하다.<br />
next 를 호출하지 않는 미들웨어는 res.send 나 res.sendFile 등의 메서드로 응답을 보내야 한다.

`express.static`, `multer` 과 같은 미들웨어는 정적 파일을 제공할 때 next 대신 res.sendFile 메서드로 응답을 보낸다.<br />
따라서 정적 파일을 제공하는 경우엔 위 코드에서 express.json, express.urlencoded, cookieParser 미들웨어는 실행되지 않는다.<br />
미들웨어 장착 순서에 따라 어떤 미들웨어는 실행이 되지 않을수도 있다는 것을 기억해야 한다.

> 그럼 항상 express.static 은 마지막에 두어야 하나...? (잘 모르겠다. ;;)

**next 도 호출하지 않고 응답도 보내지 않으면 클라이언트는 응답을 받지 못해 계속 대기상태에 있게 된다.**

**next 에 인수**를 넣을 수도 있다.
- `next()` -> 다음 미들웨어로 이동
- `next('route')` -> 다음 라우터의 미들웨어로 이동
- `next(route 외의 다른 인수)` -> 에러 처리 미들웨어로 이동, 이 때의 인수는 에러 처리 미들웨어의 err 매개변수가 된다.<br />
예) next(err1) -> (err1, req, res, next) => { }
  
---

**미들웨어 간에 데이터를 전달**하는 방법도 있다.

세션은 세션이 유지되는 동안 데이터도 유지되므로 요청이 끝날 때까지만 데이터를 유지하고 싶다면 req 객체에 데이터를 넣어두면 된다.

```javascript
app.use((req, res, next) => {
  req.data1 = '데이터를 넣어요.';
  next();
}, (req, res, next) => {
  console.log(req.data1);
  next();
})
```

앞에서 *app.set('port', process.env.PORT || 3000)* 과 같이 app.set 으로 express 에서 데이터를 저장하였다.<br />
**app.set 으로 데이터 저장 시 app.get 혹은 req.app.get 으로 어디서든 데이터를 가져올 수 있다.**<br />
하지만 app.set 은 express 전역적으로 사용되기 때문에 개별 데이터를 넣기엔 부적절하므로 **미들웨어 간 데이터 공유시에는 req 객체를 이용**하도록 한다.

---

아래는 미들웨어 안에 미들웨어를 넣는 방법으로 **조건에 따라 다른 미들웨어를 적용하는 패턴**이다.

```javascript
app.use(morgan('dev')); // 이 부분을

app.use((req, res, next) => {   // 이렇게 변경
    morgan('dev')(req, res, next);
})
```

위 부분을 확장하여 조건에 따라 다른 미들웨어를 적용할 수 있다.

```javascript
app.use((req, res, next) => {
    if (precess.env.NODE_ENV === 'production') {
        morgan('combined')(req, res, next);
    } else {
      morgan('dev')(req, res, next);
    }
})
```


---

## 2.7. `multer`

`multer` 는 **이미지, 동영상, 파일 등을 멀티파트 형식으로 업로드할 때 사용하는 미들웨어** 이다.

> **멀티파트 형식**<br /><br />
> enctype 이 multipart/form-data 인 폼을 통해 업로드하는 데이터의 형식

```shell
> npm i multer
```

> `path` 는 [eslint/prettier 셋팅 + Node.js - 기본 개념 (1): 내장 객체, 내장 모듈, util](https://assu10.github.io/dev/2021/10/04/nodejs-skill-1/) 의
> 4.2. `path` 를 참고하세요.

app.js
```javascript
const multer = require('multer');
const path = require('path');

const upload = multer({
  storage: multer.diskStorage({
    destination(req, file, done) {
      done(null, 'uploads/'); // 에러가 있으면 첫 번째 인수에 에러 전달
    },
    filename(req, file, done) {
      const ext = path.extname(file.originalname);
      done(null, path.basename(file.originalname, ext) + Date.now() + ext);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});
```

- `storage`
  - `destination`, `filename`
    - done 매개변수는 함수
    - 에러가 있다면 done 의 첫 번째 인수에 에러를 넣고, 두 번째 인수엔 실제 경로나 파일명을 넣어줌
    - req 나 file 의 데이터를 가공하여 done 으로 넘기는 형식
  - disk 외에 `aws-sdk` 와 `multer-s3` 를 이용하여 S3 에 저장할 수도 있고, memory 에 저장할 수도 있음
- `limits`
  - 업로드에 대한 제한 사항 설정


s3 와 memory 에 파일 업로드 예시
```javascript
const multerS3 = require('multer-s3');
const aws = require('aws-sdk');

let s3 = new aws.S3();

upload = multer({
  storage: multerS3({
    s3: s3,
    bucket: 'xxx',
    contentType: multerS3.AUTO_CONTENT_TYPE,
    metadata: function(req, file, done) {
        done(null, {fieldName: file.fieldname});
    },
    key: async function(req, file, done) {
      const ext = path.extname(file.originalname);
      done(null, path.basename(file.originalname, ext) + Date.now() + ext);
    },
    acl: 'public-read-write'
  })
})



upload2 = multer({ inMemory: true });
```

파일을 업로드할 폴더가 없으면 오류가 나므로 서버가 시작할 때 생성해준다.

app.js
```javascript
try {
  fs.readdirSync('uploads');
} catch (err) {
  console.error('uploads 폴더가 없으므로 uploads 폴더 생성');
  fs.mkdirSync('uploads');
}
```

> `fs.readdirSync()` 에 대한 내용은 [Node.js - 기본 개념 (3): 파일시스템](https://assu10.github.io/dev/2021/11/28/nodejs-skill-3/) 의
> *4.2. `fs.readdir`, `fs.unlink`, `fs.rmdir`* 를 참고하세요.

---

여기까지 설정하고 나면 upload 변수가 생기는데 이 변수엔 여러 종류의 미들웨어가 들어있다.<br />
여기서는 3가지로 나누어 살펴보도록 한다.


### 2.7.1. `upload.single('img')` - req.file 객에체 하나의 파일만 업로드

하나의 파일만 업로드하는 경우 `single 미들웨어` 를 사용한다.

multipart.html
```html
<form id="form" action="/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="imagename" /><!-- req.file -->
  <input type="text" name="title" /><!-- req.body -->
  <button type="submit">업로드</button>
</form>
```

app.js
```javascript
// 하나의 파일만 업로드 하는 경우
app.post('/upload', upload.single('imagename'), (req, res) => {
  console.log(req.file, req.body);
  res.send('ok');
});
```

이렇게 `single 미들웨어` 를 라우터 미들웨어 앞에 넣어두면 multer 설정에 따라 파일을 업로드 한 후 `req.file` 생성하여 리턴한다.<br />
`req.body` 엔 *title* 처럼 파일이 아닌 데이터가 들어간다.

localhost:3000/upload 로 접속하여 파일을 업로드해보자.

![하나의 파일만 업로드하는 경우](/assets/img/dev/2021/1202/single.png)

```shell
npm start

> chap06@1.0.0 start
> nodemon app

[nodemon] 2.0.15
[nodemon] to restart at any time, enter `rs`
[nodemon] watching path(s): *.*
[nodemon] watching extensions: js,mjs,json
[nodemon] starting `node app.js`
uploads 폴더가 없으므로 uploads 폴더 생성
3000 번 포트에서 대기 중
GET /upload 200 7.989 ms - 241
req.file:  {
  fieldname: 'imagename',
  originalname: '이재훈.jpeg',
  encoding: '7bit',
  mimetype: 'image/jpeg',
  destination: 'uploads/',
  filename: '이재훈1638441412036.jpeg',
  path: 'uploads/이재훈1638441412036.jpeg',
  size: 203831
}
req.body:  [Object: null prototype] { title: '' }
POST /upload 200 14.596 ms - 2
```

---

### 2.7.2. `upload.array('imgs')` - req.files 객체에 input 태그의 name 이 동일한 여러 개의 파일을 업로드

`upload.single 미들웨어` 가 아닌 `upload.array 미들웨어` 를 사용하며,
업로드 결과가 `req.file` 이 아닌 `req.files` 배열에 들어간다.

multipart.html
```html
<form id="form" action="/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="imagename" multiple />
  <input type="text" name="title" />
  <button type="submit">업로드</button>
</form>
```

app.js
```javascript
// input 태그의 name 이 동일한 여러 개의 파일을 업로드하는 경우
app.post('/upload', upload.array('imagename'), (req, res) => {
  console.log('req.file: ', req.file);
  console.log('req.files: ', req.files);
  console.log('req.body: ', req.body);
  res.send('ok');
});
```

![input 태그의 name 이 동일한 여러 개의 파일을 업로드하는 경우](/assets/img/dev/2021/1202/multi1.png)

```shell
req.file:  undefined
req.files:  [
  {
    fieldname: 'imagename',
    originalname: '이재훈.jpeg',
    encoding: '7bit',
    mimetype: 'image/jpeg',
    destination: 'uploads/',
    filename: '이재훈1638442154979.jpeg',
    path: 'uploads/이재훈1638442154979.jpeg',
    size: 203831
  },
  {
    fieldname: 'imagename',
    originalname: 'express-hapi-koa.png',
    encoding: '7bit',
    mimetype: 'image/png',
    destination: 'uploads/',
    filename: 'express-hapi-koa1638442154982.png',
    path: 'uploads/express-hapi-koa1638442154982.png',
    size: 254031
  }
]
req.body:  [Object: null prototype] { title: '' }
POST /upload 200 15.289 ms - 2
```


---

### 2.7.3. `upload.fields([{ name: 'imagename1' }, { name: 'imagename2' }])` - req.files 객체에 input 태그의 name 이 다른 여러 개의 파일을 업로드

파일을 여러 개 업로드하지만 input 태그나 폼 데이터의 키가 다른 경우 `upload.fields 미들웨어` 를 사용한다.

multipart.html
```html
<form id="form" action="/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="imagename1" />
  <input type="file" name="imagename2" />
  <input type="text" name="title" />
  <button type="submit">업로드</button>
</form>
```

app.js
```javascript
// input 태그의 name 이 다른 여러 개의 파일을 업로드하는 경우
app.post(
  '/upload',
  upload.fields([{ name: 'imagename1' }, { name: 'imagename2' }]),
  (req, res) => {
    console.log('req.files: ', req.files);
    console.log('req.body: ', req.body);
    res.send('ok');
  },
);
```

```shell
req.files:  [Object: null prototype] {
  imagename1: [
    {
      fieldname: 'imagename1',
      originalname: '이재훈.jpeg',
      encoding: '7bit',
      mimetype: 'image/jpeg',
      destination: 'uploads/',
      filename: '이재훈1638442482272.jpeg',
      path: 'uploads/이재훈1638442482272.jpeg',
      size: 203831
    }
  ],
  imagename2: [
    {
      fieldname: 'imagename2',
      originalname: 'express-hapi-koa.png',
      encoding: '7bit',
      mimetype: 'image/png',
      destination: 'uploads/',
      filename: 'express-hapi-koa1638442482275.png',
      path: 'uploads/express-hapi-koa1638442482275.png',
      size: 254031
    }
  ]
}
req.body:  [Object: null prototype] { title: '' }
```

---

### 2.7.4. `upload.none()` - 파일 업로드 없이 텍스트 데이터만 multipart 형식으로 전송

이미지를 미리 업로드하고 req.body 에 이미지 데이터가 아닌 이미지 URL (텍스트) 만 있는 경우 사용한다.

---

위에서 본 내용의 전체 소스는 아래와 같다.

app.js
```javascript
const express = require('express');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const dotenv = require('dotenv');

const multer = require('multer');
const path = require('path');
const fs = require('fs');

dotenv.config();
const app = express();
app.set('port', process.env.PORT || 3000);

app.use(morgan('dev'));
app.use('/', express.static(path.join(__dirname, 'public')));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser(process.env.COOKIE_SECRET));
app.use(
  session({
    resave: false,
    saveUninitialized: false,
    secret: process.env.COOKIE_SECRET,
    cookie: {
      httpOnly: true,
      secure: false,
    },
    name: 'session-cookie',
  }),
);

try {
  fs.readdirSync('uploads');
} catch (err) {
  console.error('uploads 폴더가 없으므로 uploads 폴더 생성');
  fs.mkdirSync('uploads');
}

const upload = multer({
  storage: multer.diskStorage({
    destination(req, file, done) {
      done(null, 'uploads/'); // 에러가 있으면 첫 번째 인수에 에러 전달
    },
    filename(req, file, done) {
      const ext = path.extname(file.originalname);
      done(null, path.basename(file.originalname, ext) + Date.now() + ext);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

app.get('/upload', (req, res) => {
  res.sendFile(path.join(__dirname, 'multipart.html'));
});

// 하나의 파일만 업로드 하는 경우
/*app.post('/upload', upload.single('imagename'), (req, res) => {
  console.log('req.file: ', req.file);
  console.log('req.body: ', req.body);
  res.send('ok');
});*/

// input 태그의 name 이 동일한 여러 개의 파일을 업로드하는 경우
/*app.post('/upload', upload.array('imagename'), (req, res) => {
  console.log('req.file: ', req.file);
  console.log('req.files: ', req.files);
  console.log('req.body: ', req.body);
  res.send('ok');
});*/

// input 태그의 name 이 다른 여러 개의 파일을 업로드하는 경우
app.post(
  '/upload',
  upload.fields([{ name: 'imagename1' }, { name: 'imagename2' }]),
  (req, res) => {
    console.log('req.files: ', req.files);
    console.log('req.body: ', req.body);
    res.send('ok');
  },
);

app.get(
  '/',
  (req, res, next) => {
    console.log('GET / 요청에서만 실행됩니다.');
    next();
  },
  () => {
    throw new Error('에러는 에러 처리 미들웨어로 갑니다.');
  },
);
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트에서 대기 중');
});
```

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

# 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [Express 공홈](https://expressjs.com/)
* [퍼그 공홈](https://pugjs.org/api/getting-started.html)
* [넌적스 공홈](https://mozilla.github.io/nunjucks/)
* [morgan](https://github.com/expressjs/morgan)
* [body-parser](https://github.com/expressjs/body-parser)
* [cookie-parser](https://github.com/expressjs/cookie-parser)
* [serve-static](https://github.com/expressjs/serve-static)
* [session](https://github.com/expressjs/session)
* [multer](https://github.com/expressjs/multer)
* [dotenv](https://github.com/motdotla/dotenv)