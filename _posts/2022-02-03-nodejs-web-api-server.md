---
layout: post
title:  "Node.js - API 서버"
date:   2022-02-03 10:00
categories: dev
tags: nodejs 
---

이 포스트는 이전에 포스팅한 내용들을 기반으로 JWT 토큰 인증, 사용량 제한 기능이 있는 REST API 서버를 구축해본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - 프로젝트 세팅

---

## 1. 프로젝트 세팅

```shell
> npm init --y
> npm i -D eslint eslint-config-prettier eslint-plugin-prettier nodemon
> npm i -D prettier --save-exact

> npm i bcrypt cookie-parser dotenv express express-session 
> npm i morgan mysql2 nunjucks passport passport-kakao passport-local sequelize uuid
```

package.json
```json
{
  "name": "nodebird-api",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "nodemon app"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "devDependencies": {
    "eslint": "^8.8.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-prettier": "^4.0.0",
    "nodemon": "^2.0.15",
    "prettier": "2.5.1"
  },
  "dependencies": {
    "bcrypt": "^5.0.1",
    "cookie-parser": "^1.4.6",
    "dotenv": "^16.0.0",
    "express": "^4.17.2",
    "express-session": "^1.17.2",
    "morgan": "^1.10.0",
    "mysql2": "^2.3.3",
    "nunjucks": "^3.2.3",
    "passport": "^0.5.2",
    "passport-kakao": "^1.0.1",
    "passport-local": "^1.0.0",
    "sequelize": "^6.15.0",
    "uuid": "^8.3.2"
  }
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
    printWidth: 110,
    // 코드 한줄이 maximum 80칸
    arrowParens: 'avoid',
    // 화살표 함수가 하나의 매개변수를 받을 때 괄호를 생략하게 formatting
    endOfLine: "auto"
};
```

![전체 프로세스](/assets/img/dev/2022/0203/process.png)

---

## 2. Model 등록

![DB](/assets/img/dev/2022/0203/tables.png)

[Node.js - Express 로 SNS 서비스 구현 (Passport, multer)](https://assu10.github.io/dev/2022/01/03/nodejs-sns-service/) 에서 진행한
[소스](https://github.com/assu10/nodejs/tree/main/chap09) 에서 *config*, *models*, *passport* 폴더와 *routes* 폴더의 *auth.js*, *middlewares.js*, 
그리고 *.env* 파일을 복사한다.

/views/error.html
```html
<h1>{{message}}</h1>

<h2>{{error.status}}</h2>
<pre>{{error.stack}}</pre>
```

app.js
```js
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const passport = require('passport');
const morgan = require('morgan');
const session = require('express-session');
const nunjucks = require('nunjucks');
const dotenv = require('dotenv');

dotenv.config();
const authRouter = require('./routes/auth');
const indexRouter = require('./routes');
const { sequelize } = require('./models');
const passportConfig = require('./passport'); // require('./passport/index.js') 와 동일

const app = express();
passportConfig(); // 패스포트 설정
app.set('port', process.env.PORT || 3001);
app.set('view engine', 'html');
nunjucks.configure('views', {
  express: app,
  watch: true,
});

sequelize
  .sync({ force: false })
  .then(() => {
    console.log('DB 연결 성공');
  })
  .catch(err => {
    console.error(err);
  });

app.use(morgan('dev'));
app.use(express.static(path.join(__dirname, 'public')));
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
  }),
);

// 요청 (req 객체) 에 passport 설정
app.use(passport.initialize());

// req.session 객체에 passport 정보 저장
// req.session 객체는 express-session 에서 생성하는 것이므로
//   passport 미들웨어는 express-session 미들웨어보다 뒤에 연결
app.use(passport.session());

app.use('/auth', authRouter);
app.use('/', indexRouter);

// 위 라우터에 매핑되지 않으면 404 에러 (미들웨어는 위에서 아래로 순서대로 실행되므로)
app.use((req, res, next) => {
  const error = new Error(`${req.method} ${req.url} 라우터 없음`);
  error.status = 404;
  next(error);
});

// 에러처리 미들웨어
app.use((err, req, res, next) => {
  res.locals.message = err.message;
  res.locals.error = process.env.NODE_ENV !== 'production' ? err : {};
  res.status(err.status || 500);
  res.render('error');
});

app.listen(app.get('port'), () => {
  console.log(app.get('port'), ' 번 포트에서 대기 중...');
});
```

/models/domain.js
```js
const Sequelize = require('sequelize');

module.exports = class Domain extends Sequelize.Model {
  static init(sequelize) {
    return super.init(
      {
        host: {
          type: Sequelize.STRING(80),
          allowNull: false,
        },
        type: {
          type: Sequelize.ENUM('free', 'premium'),
          allowNull: false,
        },
        clientSecret: {
          type: Sequelize.STRING(36), // UUID 타입 가질 예정
          allowNull: false,
        },
      },
      {
        sequelize,
        timestamps: true, // createAt, updateAt 컬럼 추가
        paranoid: true, // deleteAt 컬럼생기고 데이터 삭제 대신 지운 시각 기록됨
        modelName: 'Domain',
        tableName: 'domains',
      },
    );
  }

  static associate(db) {
    db.Domain.belongsTo(db.User);
  }
};
```

/models/index.js
```js
const Sequelize = require('sequelize');
const env = process.env.NODE_ENV || 'development';
const config = require('../config/config')[env];
const User = require('./user');
const Post = require('./post');
const Hashtag = require('./hashtag');
const Domain = require('./domain');

const db = {};
const sequelize = new Sequelize(config.database, config.username, config.password, config);

db.sequelize = sequelize;
db.User = User;
db.Post = Post;
db.Hashtag = Hashtag;
db.Domain = Domain;

User.init(sequelize);
Post.init(sequelize);
Hashtag.init(sequelize);
Domain.init(sequelize);

User.associate(db);
Post.associate(db);
Hashtag.associate(db);
Domain.init(db);

module.exports = db;
```

/modes/user.js
```js

...

static associate(db) {
    db.User.hasMany(db.Post);
    db.User.belongsToMany(db.User, {
      foreignKey: 'followingId',
      as: 'Followers',
      through: 'follows',
    });
    db.User.belongsToMany(db.User, {
      foreignKey: 'followerId',
      as: 'Followings',
      through: 'follows',
    });
    
    db.User.has(db.Domain);
}
```

routes/index.js
```js
const express = require('express');
const { v4: uuidv4 } = require('uuid'); // v4 를 uuidv4 이름으로 가져옴
const { User, Domain } = require('../models');
const { isLoggedIn } = require('./middlewares');

const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const user = await User.findOne({
      where: { id: (req.user && req.user.id) || null },
      include: { model: Domain }, // 해당 유저의 Domain 까지 조회
    });
    res.render('login', {
      user,
      domain: user && user.Domains,
    });
  } catch (err) {
    console.error(err);
    next(err);
  }
});

router.post('/domain', isLoggedIn, async (req, res, next) => {
  try {
    await Domain.create({
      UserId: req.user.id,
      host: req.body.host,
      type: req.body.type,
      clientSecret: uuidv4(),
    });
    res.redirect('');
  } catch (err) {
    console.error(err);
    next(err);
  }
});

module.exports = router;
```

clientSecret 값을 uuid 패키지를 통해 생성하는데, uuid 중 4버전을 사용한다.  
4버전은 36자리 문자열이며, `-` 로 나눠진 세 번째 마디의 첫 번째 숫자가 `4` 이다.

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [JWT Token](https://jwt.io/)
* [JSONWebToken 공식문서](https://www.npmjs.com/package/jsonwebtoken)
* [axios 공식문서](https://github.com/axios/axios)
* [CORS 공식문서](https://www.npmjs.com/package/cors)
* [express-rate-limit 공식문서](https://www.npmjs.com/package/express-rate-limit)
* [UUID 공식문서](https://www.npmjs.com/package/uuid)
* [ms 공식문서](https://github.com/vercel/ms)