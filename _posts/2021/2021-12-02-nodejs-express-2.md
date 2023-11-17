---
layout: post
title:  "Node.js - Express (2): 라우터, 템플릿 엔진"
date:   2021-12-02 10:00
categories: dev
tags: nodejs express router template-engine
---

이 포스트는 Express 의 라우팅과 넌적스 템플릿 엔진에 대해 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - Router 객체로 라우팅 분리
>   - Router 기본 이용
>   - next('route')
>   - 라우터 주소 표현
>   - 404 처리
>   - `router.route` 혹은 `app.route`
> - req, res 객체
>   - req 객체의 자주 사용되는 속성/메서드
>   - res 객체의 자주 사용되는 속성/메서드
> - 템플릿 엔진 - Nunjucks
>   - 변수
>   - 반복문
>   - 조건문
>   - include
>   - extends 와 block
> - 에러 처리 미들웨어

---

# 1. Router 객체로 라우팅 분리

앞의 [Node.js - http 모듈로 서버 생성](https://assu10.github.io/dev/2021/11/29/nodejs-server-using-http-module/) 의 *3. 쿠키와 세션* 의
코드 일부를 보면 아래와 같이 요청 메서드와 주소별로 분기 처리를 하느라 코드가 매우 복잡하다.

```javascript
if (req.url.startsWith('/login')) {
    // 코드
}
```

express 를 사용하는 이유 중 하나는 바로 **라우팅을 깔끔하게 관리** 할 수 있다는 점이다.

app.js 의 *app.get* 같은 메서드가 바로 라우터 부분이다.<br />
라우터를 많이 연결하면 app.js 가 길어지므로 express 에서는 라우터를 분리할 수 있는 방법을 제공한다.

---

## 1.1. Router 기본 이용

routes 폴더를 만들고 그 안에 index.js 와 user.js 를 작성해보자.

routes/index.js
```javascript
const express = require('express');

const router = express.Router();

// GET / 라우터
router.get('/', (req, res) => {
  res.send('Hello, Express');
});

module.exports = router;
```

routes/users.js
```javascript
const express = require('express');

const router = express.Router();

// GET /user 라우터
router.get('/', (req, res) => {
  res.send('Hello, User~');
});

module.exports = router;
```

app.js
```javascript
...
dotenv.config();

const indexRouter = require('./routes'); // index.js 는 생략 가능
const userRouter = require('./routes/users');

...

app.use('/', indexRouter);
app.use('/user', userRouter);

// 위 라우터에 매핑되지 않으면 404 에러 (미들웨어는 위에서 아래로 순서대로 실행되므로)
app.use((req, res, next) => {
  res.status(404).send('NOT FOUND.');
});

// 에러 처리 미들웨어
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});
```

indexRouter 를 *./routes/index* 가 아니라 *./routes* 로 할 수 있는 이유는 **index.js 는 생략**할 수 있기 때문이다.

userRouter 는 use 의 '/user' 와 get 의 '/' 가 합쳐져서 *GET /user* 라우터가 된다.<br />
이렇게 app.use 로 연결할 때 주소가 합쳐진다는 것을 염두에 두어야 한다.

그래서 위에 만든 라우터의 주소는 각각 *localhost:3000* 과 *localhost:3000/user* 이다.

---

## 1.2. next('route') 

[Node.js - Express (1): 미들웨어](https://assu10.github.io/dev/2021/12/01/nodejs-express-1/) 의 *2.6. 미들웨어 내용 정리* 에서
`next('route')` 호출 시 다음 미들웨어가 아닌 다음 라우터의 미들웨어로 이동한다고 했는데 이는 라우터에 연결된 나머지 미들웨어들을 건너뛰고 싶을 때 사용한다.

index.js
```javascript
router.get(
  '/',
  (req, res, next) => {
    //res.send('hello1~');  // [ERR_HTTP_HEADERS_SENT]: Cannot set headers after they are sent to the client
    next('route');
  },
  (req, res, next) => {
    console.log('실행되지 않음');
    next();
  },
  (req, res, next) => {
    console.log('실행되지 않음');
    next();
  },
);

// 주소가 일치하지 않기 때문에 실행되지 않음
router.get('/aa', (req, res) => {
  console.log('실행되지 않음');
  res.send('hello-aa~');
});

router.get('/', (req, res) => {
  console.log('실행됨');
  res.send('hello2~');
});
```

위처럼 같은 주소의 라우터를 여러 개 만들어도 된다.<br />
첫 번째 라우터의 첫 번째 미들웨어에서 `next('route')` 를 호출했기 때문에 2, 3번째 미들웨어는 실행되지 않는다.<br />
대신 **주소와 일치하는 다음 라우터로** 넘어간다.

만일 첫 번째 라우터의 첫 번째 미들웨어에서 *res.send('hello1~`);* 를 주석 해제하면 아래와 같은 오류가 발생한다.

```shell
// 두 번째 라우터의 res.send 부분에서 오류 발생
Error [ERR_HTTP_HEADERS_SENT]: Cannot set headers after they are sent to the client
    at new NodeError (node:internal/errors:371:5)
    at ServerResponse.setHeader (node:_http_outgoing:573:11)
```

첫 번째 라우터의 첫 번째 미들웨어에서도 응답을 보내고, next('route') 에 의해 실행된 두 번째 라우터의 미들웨어에서도 응답을 보내기 때문에
요청에 대한 응답을 두 번이상 보내서 발생하는 오류이다.

> 오류에 대한 내용은 [Node.js - 기본 개념 (4): 이벤트, 예외처리](https://assu10.github.io/dev/2021/11/29/nodejs-skill-4/) 의
> *3. 자주 발생하는 에러들* 을 참고하세요.

---

## 1.3. 라우터 주소 표현

라우터 주소는 정규표현식을 비롯해서 특수 패턴을 사용할 수 있는데 **라우트 매개변수** 라고 불리는 자주 쓰이는 패턴 하나만 보도록 한다.

```javascript
router.get('/me/:id', (req, res) => {
  res.send('me~');
  console.log('req.params: ', req.params);
  console.log('req.query: ', req.query);
});
```

*http://localhost:3000/me/2* 로 접속
```shell
req.params:  { id: '2' }
req.query:  {}
```

`:id` 는 `req.params` 객체 안에 들어가며, 조회는 `req.params.id` 로 조회한다.

이 패턴 사용 시 주의할 점은 일반 라우터보다 뒤에 위치해야 한다는 것이다.<br />
다양한 라우터를 아우르는 와일드카드 역할을 하기 때문에 일반 라우터보다 뒤에 위치해야 다른 라우터를 방해하지 않는다. 

```javascript
router.get('/me/:id', (req, res) => {
  res.send('me~');
  console.log('req.params: ', req.params);
  console.log('req.query: ', req.query);
});

router.get('/me/haha', (req, res) => {
  res.send('실행되지 않음');
  console.log('req.params: ', req.params);
  console.log('req.query: ', req.query);
});
```

주소에 쿼리스트링이 있으면 쿼리스트링은 `req.query` 객체 안에 들어간다.

*http://localhost:3000/me/2?aa=bb&cc=dd* 로 접속
```shell
req.params:  { id: '2' }
req.query:  { aa: 'bb', cc: 'dd' }
GET /me/2?aa=bb&cc=dd 200 0.646 ms - 3
```

---

## 1.4. 404 처리

app.js 에서 에러 처리 미들웨어 위에 넣어둔 미들웨어는 일치하는 라우터가 없을 때 404 상태 코드를 응답하는 역할을 한다.

```javascript
// 위 라우터에 매핑되지 않으면 404 에러 (미들웨어는 위에서 아래로 순서대로 실행되므로)
app.use((req, res, next) => {
  res.status(404).send('NOT FOUND.');
});

// 에러 처리 미들웨어
app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).send(err.message);
});
```

미들웨어가 존재하지 않아도 express 가 자체적으로 404 에러를 처리해주기는 하지만 왠만하면 404 응답 미들웨어와 에러 처리 미들웨어를 연결해주는 것이 좋다.

404 응답 미들웨어가 없다면 404 상태 코드와 함께 아래와 같은 화면이 노출된다.

![404 미들웨어가 없는 경우](/assets/img/dev/2021/1202/404.png)

![404 미들웨어가 있는 경우](/assets/img/dev/2021/1202/404-2.png)

---

## 1.5. `router.route` 혹은 `app.route`

`router.route` 는 라우터에서 자주 활용되는 방법으로 **주소가 같지만 메서드가 다른 코드가 있을 때 이를 하나의 코드로 묶어주는 기능**이다.

```javascript
router.get('/abc', (req, res) => {
  res.send('GET /abc');
});

router.post('/abc', (req, res) => {
  res.send('POST /abc');
});
```

위의 코드를 `router.route` 를 사용하여 아래와 같이 쓸 수 있다.

```javascript
router
  .route('/abc')
  .get((req, res) => {
    res.send('GET /abc');
  })
  .post((req, res) => {
    res.send('POST /abc');
  });
```

---

# 2. req, res 객체

express 의 req, res 객체는 http 모듈의 req, res 객체를 확장한 것이다.<br />
즉, http 모듈의 메서드도 사용할 수 있고, express 가 추가한 메서드나 속성을 사용할 수도 있다.

예를 들어 res.writeHead, res.write, res.end 메서드도 그대로 사용할 수 있고,<br />
res.send, res.sendFile 과 같은 추가된 메서드도 사용할 수 있다.

아래는 자주 사용되는 속성과 메서드들을 정리한 것이다.

---

## 2.1. req 객체의 자주 사용되는 속성/메서드 

- `req.app`
  - req 객체를 통해 app 객체에 접근
  - 예) req.app.get('port')
- `req.body`
  - body-parser 미들웨어가 만드는 요청의 본문을 해석한 객체
- `req.cookies`
  - cookie-parser 미들웨어가 만드는 요청의 쿠키를 해석한 객체
- `req.ip`
- `req.params`
  - 라우트 매개변수 (/aaa/:id) 에 대한 정보가 담긴 객체
- `req.query`
  - 쿼리스트링에 대한 정보가 담긴 객체
- `req.signedCookies`
  - 서명된 쿠키들이 담기는 객체
- `req.cookies`
  - 서명되지 않은 쿠키들이 담기는 객체
- `req.get(헤더명)`
  - 헤더의 값을 가져오는 메서드

---

## 2.2. res 객체의 자주 사용되는 속성/메서드

- `res.app`
  - req.app 처럼 res 객체를 통해 app 객체에 접근
- `res.cookie(키, 값, 옵션)`
  - 쿠키를 설정하는 메서드
- `res.clearCookie(키, 값, 옵션)`
  - 쿠키를 제거하는 메서
- `res.end()`
  - 데이터없이 응답
- `res.json(JSON)`
  - JSON 형식으로 응답
- `res.redirect(주소)`
  - 리다이렉트할 주소와 함께 응답
- `res.render(뷰, 데이터)`
  - 템플릿 엔진을 렌더링해서 응답
- `res.send(데이터)`
  - 데이터와 함께 응답
- `res.sendFile(경로)`
  - 경로에 위치한 파일을 응답
- `res.set(헤더, 값)`
  - 응답의 헤더 설정
- `res.status(코드)`
  - 응답 시의 HTTP 상태 코드 지정

---


# 3. 템플릿 엔진 - Nunjucks

템플릿 엔진은 자바스크립트를 사용해서 HTML 을 렌더링할 수 있게 한다.

대표적인 템플릿 엔진으로는 퍼그(Pug) 와  넌적스(Nunjucks) 가 있는데 여기선 넌적스만 살펴본다.

넌적스는 파이어폭스를 만든 모질라에서 만들었고, 퍼그의 HTML 문법 변화에 적응하기 힘든 개발자들에게 적합한 템플릿 엔진이다.<br />
HTML 문법을 그대로 사용하되 추가로 자바스크립트 문법을 사용할 수 있다. (파이썬의 Twig 문법과 상당히 유사)

>**EJS**<br /><br />
> 노드에 EJS 나 Handebars 와 같은 템플릿 엔진도 있지만 레이아웃 기능이 없어서 비효율적이다. 

프로젝트 생성 후 아래 패키지들을 설치한다.

```shell
> npm i cookie-parser dotenv express express-session morgan nunjucks
> npm i -D eslint eslint-config-prettier eslint-plugin-prettier nodemon
> npm i -D prettier --save-exact
```

app.js - 일부
```javascript
...

const path = require('path');
const nunjucks = require('nunjucks');

dotenv.config();

const indexRouter = require('./routes'); // index.js 는 생략 가능
const userRouter = require('./routes/users');

const app = express();
app.set('port', process.env.PORT || 3000);
app.set('view engine', 'html');
nunjucks.configure('views', {
  express: app,
  watch: true,
});

...
```

configure 의 첫 번째 인수는 views 폴더의 경로를 넣고, 두 번째 인수로 옵션을 넣는다.<br />
express 속성에 app 객체를 연결하고,<br />
watch 속성을 true 하면 HTML 파일이 변경될 때 템플릿 엔진을 다시 렌더링한다.

파일은 html 을 그대로 사용해도 된다. 예) *app.set('view engine', 'html');* <br />
넌적스 임을 구분하려면 확장자를 `.njk` 로 하면 되고, 이 때는 view engine 도 njk 로 바꿔야 한다. 

app.js - 전체
```javascript
const express = require('express');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const dotenv = require('dotenv');
const path = require('path');
const nunjucks = require('nunjucks');

dotenv.config();

const indexRouter = require('./routes'); // index.js 는 생략 가능
const userRouter = require('./routes/users');

const app = express();
app.set('port', process.env.PORT || 3000);
app.set('view engine', 'html');
nunjucks.configure('views', {
  express: app,
  watch: true,
});

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

app.use('/', indexRouter);
app.use('/user', userRouter);

// 위 라우터에 매핑되지 않으면 404 에러 (미들웨어는 위에서 아래로 순서대로 실행되므로)
app.use((req, res, next) => {
  res.status(404).send('NOT FOUND.');
});

// 에러 핸들러
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트에서 대기 중');
});
```

---

## 3.1. 변수

res.render 호출 시 보내는 변수를 넌적스가 처리한다.

routes/index.js
```javascript
// GET / 라우터
router.get('/', (req, res) => {
  res.render('index', { title: 'Express~ ' });
});
```

넌적스에서 변수는 <!-- {% raw %} --> `{{ }}` <!-- {% endraw %} --> 로 감싼다.

<!-- {% raw %} -->
```html
<h1>{{title}}</h1>
```
<!-- {% endraw %} -->


<!-- {% raw %} --> `{% set 변수 = '값' %}` <!-- {% endraw %} --> 를 이용하여 내부에 변수를 선언하여 사용할 수도 있다.

<!-- {% raw %} -->
```html
{% set node = 'Node.js' %}
<p>{{node}}</p>
```
<!-- {% endraw %} -->

HTML 을 이스케이스하고 싶지 않으면 <!-- {% raw %} -->`{{ 변수 | safe }}`<!-- {% endraw %} --> 를 사용한다.

html
```html
<p>&lt;strong&gt;이스케이프&lt;/strong&gt;</p>
<p>이스케이프하지 않음</p>
```

nunjucks
<!-- {% raw %} -->
```html
<p>{{'<strong>이스케이프</strong>'}}</p>
<p>{{'<strong>이스케이프하지 않음</strong>' | safe }}</p>
```
<!-- {% endraw %} -->

---

## 3.2. 반복문

넌적스에서 특수한 구문은 <!-- {% raw %} --> `{% %}` <!-- {% endraw %} --> 안에 쓰는데 반복문도 이 안에 넣으면 된다.

`for...in 객체` 와 `end for` 사이에 위치하면 된다.  
반복문의 인덱스는 `loop.index` 를 사용하면 된다. (1부터 시작)

<!-- {% raw %} -->
```html
<ul>
  {% set fruits = ['사과', '배', '딸기'] %}
  {% for item in fruits %}
  <li>{{loop.index}} 번째 {{item}}</li>
  {% endfor %}
</ul>
```
<!-- {% endraw %} -->

---

## 3.3. 조건문

조건문은 <!-- {% raw %} -->`{% if 변수 %}`, `{% elif %}`, `{% else %}`, `{% endif %}`<!-- {% endraw %} --> 로 이루어져 있다.

<!-- {% raw %} -->
```html
{% if isLoggedIn %}
로그인 상태
{% else %}
로그인하지 않은 상태
{% endif %}

{% if fruit === 'apple' %}
사과
{% elif fruit === 'banana' %}
바나나
{% else %}
걍 과일
{% endif %}
```
<!-- {% endraw %} -->

<!-- {% raw %} -->`{{ }}`<!-- {% endraw %} --> 안에서는 아래와 같이 사용한다. 

<!-- {% raw %} -->
```html
{{'참' if isLoggedIn}}
{{'참' if isLoggedId else '거짓'}}
```
<!-- {% endraw %} -->


---

## 3.4. include

다른 HTML 파일을 넣을 때 `include 파일 경로` 로 사용한다.  
모든 페이지에 동일한 HTML 을 넣어야하는 번거로움을 없앤다.

<!-- {% raw %} -->
```html
{% include "header.html" %}
본문 내용
{% include "footer.html" %}
```
<!-- {% endraw %} -->

---

## 3.5. extends 와 block

레이아웃을 정할 수 있다.  
레이아웃이 될 파일에는 공통된 마크업을 넣되, 페이지마다 달라지는 부분을 `block` 으로 비워둔다.  
`block` 은 여러 개 만들어도 되며, 선언하는 방법은 <!-- {% raw %} -->`{% block [블록명] %}`<!-- {% endraw %} --> 이고,
블록 종료는 <!-- {% raw %} -->`{% endblock %}`<!-- {% endraw %} --> 이다.

<!-- {% raw %} -->
layout.html
```html
<html>
    <head>
      <title>{{title}}</title>
      <link rel="stylesheet" href="/style.css" />
    </head>
    <body>
    {% block content %}
    {% endblock %}
    
    푸터 시작
    {% block script %}
    {% endblock %}
    </body>
</html>
```

body.html
```html
{% extends 'layout.html' %}

{% block content %}
내용내용
{% endblock %}

{% block script %}
<script src="/main.js" />
{% endblock %}
```
<!-- {% endraw %} -->

block 이 되는 파일에 <!-- {% raw %} -->`{% extends 경로 %}`<!-- {% endraw %} --> 키워드로 레이아웃 파일을 지정하고, block 부분을 넣는다.

나중에 express 에서 `res.render('body')` 를 사용해 하나의 HTML 로 합친 후 렌더링한다.


이제 views 폴더에 layout.html, index.html, error.html 파일을 만들어보자.

<!-- {% raw %} -->
layout.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{{title}}</title>
</head>
<body>
  {% block content %}
  {% endblock %}
</body>
</html>
```

index.html
```html
{% extends 'layout.html' %}

{% block content %}
<h1>{{title}}</h1>
<p>welcome to {{title}}</p>
{% endblock %}
```

error.html
```html
{% extends 'layout.html' %}

{% block content %}
{{message}}
<h2>{{error.status}}</h2>
<pre>{{error.stack}}</pre>
{% endblock %}
```
<!-- {% endraw %} -->

index.js
```javascript
const express = require('express');

const router = express.Router();

// GET / 라우터
router.get('/', (req, res) => {
  res.render('index', { title: 'Express~ ' });
});

module.exports = router;
```

app.js - 전체
```javascript
const express = require('express');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const dotenv = require('dotenv');
const path = require('path');
const nunjucks = require('nunjucks');

dotenv.config();

const indexRouter = require('./routes'); // index.js 는 생략 가능
const userRouter = require('./routes/users');

const app = express();
app.set('port', process.env.PORT || 3000);
app.set('view engine', 'html');
nunjucks.configure('views', {
  express: app,
  watch: true,
});

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

app.use('/', indexRouter);
app.use('/user', userRouter);

// 위 라우터에 매핑되지 않으면 404 에러 (미들웨어는 위에서 아래로 순서대로 실행되므로)
app.use((req, res, next) => {
  res.status(404).send('NOT FOUND.');
});

// 에러 핸들러
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).send(err.message);
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), '번 포트에서 대기 중');
});
```

![localhost:3000](/assets/img/dev/2021/1202/nunjucks.png)

---

# 4. 에러 처리 미들웨어

앞에서 res.send 로 텍스트만 보냈던 404 응답 미들웨어와 에러 처리 미들웨어를 수정하여 아래와 같이 error.html 에 에러를 표시하도록 해보자.

app.js
```javascript
...

// 위 라우터에 매핑되지 않으면 404 에러 (미들웨어는 위에서 아래로 순서대로 실행되므로)
app.use((req, res, next) => {
  const error = new Error(`${req.method} ${req.url} 라우터가 없습니다.`);
  error.status = 404;
  next(error);
});

// 에러 핸들러
app.use((err, req, res, next) => {
  res.locals.message = err.message;
  res.locals.error = process.env.NODE_ENV !== 'production' ? err : {};
  res.status(err.status || 500);
  res.render('error');  // error.html 렌더링
});

...
```

위 코드처럼 res.render 에 변수를 대입하는 것 외에도 `res.locals` 속성에 값을 대입하여 템플릿 엔진에 변수를 주입할 수 있다.

![localhost:3000/ddd](/assets/img/dev/2021/1202/error.png)

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