---
layout: post
title:  "Node.js - Express 로 SNS 서비스 구현 (Passport, multer)"
date:   2022-01-03 10:00
categories: dev
tags: nodejs passport multer
---

이 포스트는 이전에 포스팅한 내용들을 기반으로 로그인, 이미지 업로드, 게시글 작성, 해시태그 검색, 팔로잉 등이 있는
SNS 서비스를 구축해본다.

특히 `Passport` 모듈을 이용하여 자체 회원가입과 로그인 뿐 아니라 카카오톡을 통한 로그인하는 방법과  
`multer` 를 이용하여 이미지 업로드 기능에 대해 자세히 살펴본다.


*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - 프로젝트 세팅
> - 데이터베이스 세팅
>   - 사용할 테이블의 ERD, Schema
>   - 모델 정의
>   - 관계 정의
>   - 모델과 서버 연결
> - Passport 모듈로 로그인 구현
>   - 기본 구조 셋팅
>   - 로컬 로그인 구현
>     - 로그인 여부 확인 미들웨어
>     - 로컬 로그인 - 회원가입, 로그인, 로그아웃 라우터
>   - 카카오 로그인 구현
>     - 카카오 clientID 발급
> - multer 패키지로 이미지 업로드 구현
> - 그 외 라우터

---

## 1. 프로젝트 세팅

```shell
> npm init --y
> npm i -D eslint eslint-config-prettier eslint-plugin-prettier nodemon
> npm i -D prettier --save-exact

> npm i sequelize mysql2 sequelize-cli  # mysql 사용
> npx sequelize init  # config, migrations, models, seeder 폴더 생성

> npm i express cookie-parser express-session morgan multer dotenv nunjucks
```

> **npx 를 사용하는 이유**  
> 전역 설치 (npm i -g) 를 피하기 위함

템플릿 파일을 넣은 views 폴더, 라우터를 넣을 routes 폴더, 정적 파일을 넣을 public 폴더, passport 패키지를 위한
passport 폴더를 생성한다.

package.json
```json
{
  "name": "chap09",
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
    "eslint": "^8.6.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-prettier": "^4.0.0",
    "nodemon": "^2.0.15",
    "prettier": "2.5.1"
  },
  "dependencies": {
    "cookie-parser": "^1.4.6",
    "dotenv": "^10.0.0",
    "express": "^4.17.2",
    "express-session": "^1.17.2",
    "morgan": "^1.10.0",
    "multer": "^1.4.4",
    "mysql2": "^2.3.3",
    "nunjucks": "^3.2.3",
    "sequelize": "^7.0.0-alpha.4",
    "sequelize-cli": "^6.3.0"
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
```javascript
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

![폴더 구조](/assets/img/dev/2022/0103/structure.png)

app.js
```javascript
const express = require('express');
const cookieParser = require('cookie-parser');
const morgan = require('morgan');
const path = require('path');
const session = require('express-session');
const nunjucks = require('nunjucks');
const dotenv = require('dotenv');

dotenv.config();
const pageRouter = require('./routes/page');

const app = express();
app.set('port', process.env.PORT || 3000);
app.set('view engine', 'html');
nunjucks.configure('views', {
  express: app,
  watch: true,
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

app.use('/', pageRouter);

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

.env
```text
COOKIE_SECRET=assucookiesecret
```

*2. 데이터베이스 세팅* 에서 설정하겠지만 하드 코딩된 비밀번호가 유일하게 남아있는 파일은 시퀄라이즈 설정을 담아둔 *config.json* 이다.  
JSON 파일이라 process.env 를 사용할 수 없다.  

> 시퀄라이즈 비밀번호를 숨기는 방법은 config.json 대신 config.js 를 사용하면 되는데 추후 다룰 예정이다.

routes/page.js
```javascript
const express = require('express');

const router = express.Router();

// 라우터용 미들웨어, 템플릿 엔진에서 사용할 user, followerCount 등을 res.locals 로 설정
// res.locals 로 설정하는 이유는 각 변수가 모든 템플릿 엔진에서 공통으로 사용되기 때문
router.use((req, res, next) => {
  res.locals.user = null;
  res.locals.followerCount = 0;
  res.locals.followingCount = 0;
  res.locals.followerIdList = [];
  next();
});

router.get('/profile', (req, res) => {
  res.render('profile', { title: '내 정보 - ASSU' });
});

router.get('/join', (req, res) => {
  res.render('join', { title: '회원가입 - ASSU' });
});

router.get('/', (req, res, next) => {
  const twits = [];
  res.render('main', {
    title: 'ASSU',
    twits,
  });
});

module.exports = router;
```

**router.use** 로 라우터용 미들웨어를 만들어 템플릿 엔진에서 사용할 user, followingCount 등의 변수를 *res.locals* 로 설정하였다.  
*res.locals* 로 설정한 이유는 user, followingCount 등의 변수를 모든 템플릿 엔진에서 공통으로 사용하기 때문이다.  
지금은 모두 null, 0, [] 이지만 나중에 값을 넣을 예정이다.  
render 함수 안의 twits 도 지금은 빈 배열이지만 나중에 값을 넣을 예정이다.

클라이언트 코드 (views/\*,public/\* 은 [git](https://github.com/assu10/nodejs/tree/main/chap09) 에서 복사하세요.)

이제 `npm start` 로 서버를 올린 후 localhost:3000 으로 접속하면 아래와 같은 화면이 뜰 것이다.

![메인](/assets/img/dev/2022/0103/main.png)
![회원가입](/assets/img/dev/2022/0103/join.png)

---

## 2. 데이터베이스 세팅

### 2.1. 사용할 테이블의 ERD, Schema

이제 MySQL 과 시퀄라이즈로 데이터베이스를 설정한다.

필요한 테이블은 _사용자 테이블_, _게시글 테이블_, _해시태그_ 테이블 총 3개이다.  
마지막에 설명할 거지만 시퀄라이즈에 의해 생성되는 2개의 테이블이 추가로 더 있다.

![전체 ERD](/assets/img/dev/2022/0103/erd.png)

```mysql
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(40) DEFAULT NULL,
  `nick` varchar(12) NOT NULL,
  `password` varchar(100) DEFAULT NULL,
  `provider` varchar(10) NOT NULL DEFAULT 'local',
  `snsId` varchar(30) DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime NOT NULL,
  `deletedAt` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3
```

```mysql
CREATE TABLE `posts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `content` varchar(140) COLLATE utf8mb4_general_ci NOT NULL,
  `img` varchar(200) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime NOT NULL,
  `UserId` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `UserId` (`UserId`),
  CONSTRAINT `posts_ibfk_1` FOREIGN KEY (`UserId`) REFERENCES `users` (`id`) 
      ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
```

```mysql
CREATE TABLE `follows` (
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime NOT NULL,
  `followingId` int NOT NULL,
  `followerId` int NOT NULL,
  PRIMARY KEY (`followingId`,`followerId`),
  KEY `followerId` (`followerId`),
  CONSTRAINT `follows_ibfk_1` FOREIGN KEY (`followingId`) REFERENCES `users` (`id`) 
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `follows_ibfk_2` FOREIGN KEY (`followerId`) REFERENCES `users` (`id`) 
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3
```

```mysql
CREATE TABLE `hashtags` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(15) COLLATE utf8mb4_general_ci NOT NULL,
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
```

```mysql
CREATE TABLE `postHashtag` (
  `createdAt` datetime NOT NULL,
  `updatedAt` datetime NOT NULL,
  `PostId` int NOT NULL,
  `HashtagId` int NOT NULL,
  PRIMARY KEY (`PostId`,`HashtagId`),
  KEY `HashtagId` (`HashtagId`),
  CONSTRAINT `posthashtag_ibfk_1` FOREIGN KEY (`PostId`) REFERENCES `posts` (`id`) 
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `posthashtag_ibfk_2` FOREIGN KEY (`HashtagId`) REFERENCES `hashtags` (`id`) 
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
```

먼저 사용할 데이터베이스를 생성한다.  
SQL 문으로 직접 생성해도 되지만 시퀄라이즈는 `config.json` 을 읽어 데이터베이스를 생성해주는 기능이 있다.  

`config.json` 을 아래와 같이 수정한다.

config.json
```json
{
  "local": {
    "username": "root",
    "password": "1234",
    "database": "sns",
    "host": "127.0.0.1",
    "dialect": "mysql"
  }
}
```

그리고 콘솔에서 `npx sequelize db:create` 를 통해 데이터베이스를 생성한다.

```shell
> npx sequelize db:create

Sequelize CLI [Node: 16.6.0, CLI: 6.3.0, ORM: 7.0.0-alpha.4]

Loaded configuration file "config/config.json".
Using environment "development".
Database sns created.
```

---

### 2.2. 모델 정의

models/user.js
```javascript
const Sequelize = require('sequelize');

module.exports = class User extends Sequelize.Model {
  static init(sequelize) {
    return super.init(
      {
        email: {
          type: Sequelize.STRING(40),
          allowNull: true,
          unique: true,
        },
        nick: {
          type: Sequelize.STRING(12),
          allowNull: false,
        },
        password: {
          type: Sequelize.STRING(100),
          allowNull: true,
        },
        // SNS 로그인 시 저장
        // local: 로컬 로그인, kakao: 카카오로그인 
        provider: {
          type: Sequelize.STRING(10),
          allowNull: false,
          defaultValue: 'local',
        }, 
        -// SNS 로그인 시 저장
        snsId: {
          type: Sequelize.STRING(30),
          allowNull: true,
        },
      },
      {
        sequelize,
        timestamps: true, // createdAt, updatedAT
        underscored: false, // 테이블명과 컬럼명을 Snake case 로
        modelName: 'User',
        tableName: 'users',
        paranoid: true, // deletedAt
        charset: 'utf8',
        collate: 'utf8_general_ci',
      },
    );
  }

  static associate(db) {}
};
```

*provider*, *snsId* 는 SNS 로그인 시 저장된다.

models/post.js
```javascript
const Sequelize = require('sequelize');

module.exports = class Post extends Sequelize.Model {
  static init(sequelize) {
    return super.init(
      {
        content: {
          type: Sequelize.STRING(140),
          allowNull: false,
        },
        img: {
          type: Sequelize.STRING(200),
          allowNull: true,
        },
      },
      {
        sequelize,
        timestamps: true,
        underscored: false,
        modelName: 'Post',
        tableName: 'posts',
        paranoid: false,
        charset: 'utf8mb4',
        collate: 'utf8mb4_general_ci',
      },
    );
  }

  static associate(db) {}
};
```

models/hashtag.js
```javascript
const Sequelize = require('sequelize');

module.exports = class Hashtag extends Sequelize.Model {
  static init(sequelize) {
    return super.init(
      {
        title: {
          type: Sequelize.STRING(15),
          allowNull: false,
          unique: true,
        },
      },
      {
        sequelize,
        timestamps: true,
        underscored: false,
        modelName: 'Hashtag',
        tableName: 'hashtags',
        paranoid: false,
        charset: 'utf8mb4',
        collate: 'utf8mb4_general_ci',
      },
    );
  }

  static associate(db) {}
};
```

이제 위 모델들을 시퀄라이즈에 등록한다.  
자동으로 생성된 models/index.js 의 내용을 아래와 같이 수정한다.

models/index.js
```javascript
const Sequelize = require('sequelize');
const env = process.env.NODE_ENV || 'development';
const config = require('../config/config')[env];
const User = require('./user');
const Post = require('./post');
const Hashtag = require('./hashtag');

const db = {};
const sequelize = new Sequelize(
  config.database,
  config.username,
  config.password,
  config,
);

db.sequelize = sequelize;
db.User = User;
db.Post = Post;
db.Hashtag = Hashtag;

User.init(sequelize);
Post.init(sequelize);
Hashtag.init(sequelize);

User.associate(db);
Post.associate(db);
Hashtag.associate(db);

module.exports = db;
```

---

### 2.3. 관계 정의

이제 관계를 설정해보자.

먼저 users 테이블과 posts 테이블은 `1:N` 관계이다. (hasMany-belongsTo)

![users-posts ERD](/assets/img/dev/2022/0103/user-post.png)

> 1:N, 1:1, N:M 관계 설정은 [Node.js - MySQL, 시퀄라이즈](https://assu10.github.io/dev/2021/12/03/nodejs-mysql/) 의 *5. 관계 정의* 를 참고하세요.

models/users.js
```javascript
static associate(db) {
    db.User.hasMany(db.Post);
}
```

models/post.js
```javascript
static associate(db) {
    // foreign key 를 지정하지 않았으므로 "모델명+기본키" 인 UserId 로 FK 컬럼 생성
    db.Post.belongsTo(db.User);
}
```

시퀄라이즈는 Post 모델에 User 모델의 id 를 가리키는 *UserId* 컬럼을 추가한다.

*post.getUser*, *post.addUser* 와 같은 관계 메서드가 생성된다.

---

같은 모델끼리도 `N:M` 관계를 가질 수 있다. (belongsToMany-belongsToMany)

사용자 한 명이 팔로워를 여러 명 가질수도 있고, 한 사람이 여러 명을 팔로잉할 수도 있다.  
(항상 헷갈리는데...;; 팔로잉이 내가 팔로우하는 사람 / 팔로워가 나를 팔로우하는 사람)

users 테이블과 users 테이블 간에 N:M 관계가 있다.

![users-follows ERD](/assets/img/dev/2022/0103/user-follows.png)

models/user.js
```javascript
static associate(db) {
    ...

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
  }
```

**같은 테이블 간의 N:M 관계에서는 모델명과 컬럼명을 반드시 정해줘야 한다.** (모델명이 UserUser 일 수는 없으니까...)

`through` 를 사용해서 생성할 모델명은 *follows* 라고 정했다.

*follows* 테이블에서 사용자 아이디를 저장하는 컬럼 이름이 둘 다 UserId 이면 누가 팔로워고 팔로잉인지 구분이 되지 않으므로
따로 설정을 해주어야 한다.  
`foreignKey` 옵션에 각각 *followingId*, *followerId* 를 설정하여 두 사용자 아이디를 구별한다.

**같은 테이블 간의 N:M 관계에서는 `as` 옵션도 넣어주어야 한다.**  
둘 다 User 모델이라 구분되지 않기 때문이다.  
여기서 주의할 점은 `as` 는 `foreignKey` 와 반대되는 모델을 가리켜야 한다.  
foreignKey 가 followingId 이면 as 는 Followers 이어야 한다.

`as` 에 특정 이름을 설정하였으므로 user.getFollowers, user.getFollowings 와 같은 관계 메서드를 사용할 수 있다.  
`include` 시에도 `as` 에 같은 값을 넣으면 관계 쿼리가 작동한다.

---

posts 테이블과 hashtags 테이블은 `N:M` 관계이다. (belongsToMany-belongsToMany)

hashtags-posts-postHashtag ERD](/assets/img/dev/2022/0103/hashtags-posts-postHashtag.png)

models/post.js
```javascript
static associate(db) {
    ...
    db.Post.belongsToMany(db.Hashtag, { through: 'postHashtag' });
}
```

models/hashtag.js
```javascript
static associate(db) {
    db.Hashtag.belongsToMany(db.Post, { through: 'postHashtag' });
}
```

N:M 관계이므로 postHashtag 라는 중간 모델이 생기고 각각 postId 와 hashtagId 라는 foreignKey 도 추가된다.

as 는 따로 지정하지 않으면 post.getHashtags, post.addHashtags, hashtags.getPosts 와 같은 관계 메서드들이 생성된다.

같은 테이블 간의 N:M 관계 시에는 `foreignKey`, `as`, `through` 모두 필수이고,  
다른 테이블 간의 N:M 관계 시에는 `through` 만 필수이다.

---

정리해보면 직접 생성한 모델인 User, Hashtag, Post 와 시퀄라이즈가 관계를 파악하여 생성한 PostHashtag, Follow 모델,  
총 5개의 모델이 사용 예정이다.

최종적인 관계 설정은 아래와 같다.

models/user.js
```javascript
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
}
```

models/post.js
```javascript
static associate(db) {
    // foreign key 를 지정하지 않았으므로 "모델명+기본키" 인 UserId 로 FK 컬럼 생성
    db.Post.belongsTo(db.User);
    
    db.Post.belongsToMany(db.Hashtag, { through: 'postHashtag' });
}
```

models/hashtag.js
```javascript
static associate(db) {
    db.Hashtag.belongsToMany(db.Post, { through: 'postHashtag' });
}
```

자동으로 생성된 모델도 아래와 같이 접근 가능하고, 아래 모델을 통해 쿼리 호출이나 관계 메서드 사용도 가능하다.
```javascript
db.sequelize.models.PostHashtag
db.sequelize.models.Follow
```

---

### 2.4. 모델과 서버 연결

app.js
```javascript
...
const pageRouter = require('./routes/page');
const { sequelize } = require('./models');

const app = express();
app.set('port', process.env.PORT || 3000);
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

...
```

---

## 3. Passport 모듈로 로그인 구현

회원 가입과 로그인을 직접 구현할 수도 있지만 세션, 쿠키 처리 등 복잡한 작업이 많기 때문에 검증된 모듈을 사용하는 것이 좋다.  
`Passport` 가 바로 그러한 역할을 해주는 모듈이다.

아이디/비밀번호 로그인 외 카카오톡, 페이스북, 구글과 같은 기존의 SNS 서비스 계정을 이용한 로그인도 있는데 이 또한 `Passport` 를
이용해서 구현할 수 있다.

이제 자체 회원가입, 로그인 뿐 아니라 카카오톡을 이용하여 로그인하는 방법을 알아볼 예정이다.

---

### 3.1. 기본 구조 셋팅

```shell
> npm i passport passport-local passport-kakao bcrypt
```

잠시 후에 만들 Passport 모듈을 미리 app.js 와 연결한다.

app.js
```javascript

...

const dotenv = require('dotenv');
const passport = require('passport');

dotenv.config();
const pageRouter = require('./routes/page');
const { sequelize } = require('./models');

const passportConfig = require('./passport'); // require('./passport/index.js') 와 동일

const app = express();

passportConfig(); // 패스포트 설정

app.set('port', process.env.PORT || 3000);

...

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

app.use('/', pageRouter);

...

```

- `passport.initialize` 미들웨어
  - 요청 (req 객체) 에 passport 설정
  
- `passport.session` 미들웨어
  - req.session 객체에 passport 정보 저장
  - req.session 객체는 express-session 에서 생성하는 것이므로 passport.session 미들웨어는 express-session 미들웨어보다 뒤에 연결해야 함


passport/index.js
```javascript
const passport = require('passport');
const local = require('./localStrategy');
const kakao = require('./kakaoStrategy');
const User = require('../models/user');

module.exports = () => {
  // 로그인 시 실행 (사용자 정보 객체를 세션에 아이디로 저장)
  // req.session(세션) 에 어떤 데이터를 저장할 지 결정
  // 매개변수로 user 를 받아서 user.id 를 세션에 저장
  passport.serializeUser((user, done) => {
    done(null, user.id); // 첫 번째 인수는 에러 발생 시 사용, 두 번째 인수는 세션에 저장하고 싶은 데이터
  });

  // 매 요청 시 실행 (세션에 저장한 아이디를 통해 사용자 정보 객체 조회, 세션에 불필요한 데이터를 담아두지 않기 위한 과정)
  // passport.session 미들웨어가 호출함
  // serializeUser 의 done 의 두 번째 인수로 넣었던 데이터가 deserializeUser 의 매개변수가 됨
  // 위의 serializeUser 에서 세션에 저장했던 아이디를 받아 DB 에서 사용자 정보 조회한 후 req.user 에 저장
  // 앞으로 req.user 를 통해 로그인한 사용자의 정보 조회 가능
  passport.deserializeUser((id, done) => {
    User.findOne({ where: { id } })
      .then(user => done(null, user))
      .catch(err => done(err));
  });

  local();
  kakao();
};
```

- `passport.serializeUser`
  - **로그인 시 실행**
  - **사용자 정보 객체를 세션에 아이디로 저장**
  - req.session(세션) 객체에 어떤 데이터를 저장할 지 정하는 메서드
  - 매개변수로 user 를 받은 후 `done` 함수의 두 번째 인수로 user.id 넘기고 있음  
    매개변수 user 는 `req.login()` 가 `passport.serializeUser` 를 호출할 때 넘겨받는데  
    자세한 내용은 뒤에 나오는 *3.2.2. 회원가입, 로그인, 로그아웃 라우터* 의 *로그인 라우터* 부분을 참고하세요.
  - `done` 함수의 첫 번째 인수는 에러 발생 시 사용, 두 번째 인수는 저장하고 싶은 데이터
  - 세션에 사용자 정보를 모두 저장하면 세션의 용량이 커지고, 데이터 일관성에 문제가 발생하므로 사용자의 아이디만 저장
  
- `passport.deserializeUser`
  - **매 요청 시 실행**
  - **세션에 저장한 아이디를 통해 사용자 정보 객체 조회** (세션에 불필요한 데이터를 담아두지 않기 위한 과정)
  - app.js 의 `passport.session` 미들웨어가 이 메서드 호출
  - `passport.serializeUser` 의 `done` 의 두 번째 인수로 넣었던 데이터가 `passport.deserializeUser` 의 매개변수가 됨
  - `passport.serializeUser` 에서 세션에 저장했던 아이디를 받아와 DB 에서 사용자 정보를 조회한 후 `req.user` 에 저장
  - 앞으로는 `req.user` 를 통해 로그인한 사용자의 정보 조회 가능


> **로그인 까지의 전체 과정**  
1. 라우터를 통해 로그인 요청 들어옴
2. 라우터에서 passport.authenticate 메서드 호출
3. 로그인 전략 수행
4. 로그인 성공 시 사용자 정보 객체와 함께 req.login 호출
5. req.login 메서드가 passport.serializeUser 호출
6. req.session 에 사용자 아이디만 저장
7. 로그인 완료

1~4 번은 이제 앞으로 구현해 나갈 것이다.

> **로그인 이후의 과정**  
1. 요청이 들어옴
2. 라우터에 요청이 도달하기 전에 passport.session 미들웨어가 passport.deserializeUser 메서드 호출
3. req.session 에 저장된 아이디로 DB 에서 사용자 조회
4. 조회된 사용자 정보를 req.user 에 저장
5. 라우터에서 req.user 객체 사용

---

### 3.2. 로컬 로그인 구현

#### 3.2.1. 로그인 여부 확인 미들웨어 

로컬 로그인은 다른 SNS 서비스를 통해 로그인하지 않고 자체적으로 회원가입 후 로그인하는 것을 의미한다.  
`Passport` 에서 이를 구현하려면 `passport-local` 모듈이 필요하다.

`passport-local` 모듈 설치하였으니 로그인 전략을 세워보도록 한다.

회원가입, 로그인, 로그아웃 라우터를 만들기 전에 회원가입과 로그인 라우터는 로그인 하지 않은 사용자만 접근이 가능해야 하고,  
로그아웃 라우터는 로그인한 사용자만 접근이 가능해야 한다.  
**라우터에 로그인 여부를 검사하는 미들웨어를 넣어 구현 가능**하다.

따라서 접근 제한을 제어하는 미들웨어를 먼저 만들어야 한다.

Passport 가 req 객체에 추가해주는 `req.isAuthenticated()` 메서드를 사용해보자.

routes/middleware.js
```javascript
exports.isLoggedIn = (req, res, next) => {
  if (req.isAuthenticated()) {
    next(); // 로그인 상태면 다음 미들웨어 호출
  } else {
    res.status(403).send('로그인 필요');
  }
};

exports.isNotLoggedIn = (req, res, next) => {
  if (!req.isAuthenticated()) {
    next();
  } else {
    const message = encodeURIComponent('이미 로그인 한 상태입니다.');
    res.redirect(`?error=${message}`);
  }
};
```

이 미들웨어가 page 라우터에 어떻게 사용되는지 보자.

routes/page.js
```javascript
const express = require('express');

const { isLoggedIn, isNotLoggedIn } = require('./middlewares');

const router = express.Router();

// 라우터용 미들웨어, 템플릿 엔진에서 사용할 user, followerCount 등을 res.locals 로 설정
// res.locals 로 설정하는 이유는 각 변수가 모든 템플릿 엔진에서 공통으로 사용되기 때문
router.use((req, res, next) => {
  res.locals.user = req.user; // 넌적스에서 user 객체를 통해 사용자 정보에 접근할 수 있도록..
  res.locals.followerCount = 0;
  res.locals.followingCount = 0;
  res.locals.followerIdList = [];
  next();
});

// 내 프로필 보기
// 로그인이 된 상태이어야 next() 가 호출되어 res.render 가 있는 미들웨어로 넘어갈 수 있음
router.get('/profile', isLoggedIn, (req, res) => {
  res.render('profile', { title: '내 정보 - ASSU' });
});

// 회원가입 하기
router.get('/join', isNotLoggedIn, (req, res) => {
  res.render('join', { title: '회원가입 - ASSU' });
});

...

```

**로그인 여부만 미들웨어를 만들 수 있는 것이 아니라 팔로잉 여부, 관리자 여부 등의 미들웨어를 만들어 다양하게 활용할 수 있다.**

---

#### 3.2.2. 로컬 로그인 - 회원가입, 로그인, 로그아웃 라우터

routes/auth.js
```javascript
const express = require('express');
const passport = require('passport');
const bcrypt = require('bcrypt');
const { isLoggedIn, isNotLoggedIn } = require('./middlewares');
const { User } = require('../models/');

const router = express.Router();

// 회원 가입
router.post('/join', isNotLoggedIn, async (req, res, next) => {
  const { email, nick, password } = req.body;
  try {
    const existUser = await User.findOne({ where: { email } });
    if (existUser) {
      return res.redirect('/join?error=exist');
    }
    // 두 번째 인수는 hash 반복 횟수, 12 이상을 추천하며 최대 31까지 가능
    const hash = await bcrypt.hash(password, 12);
    await User.create({
      email,
      nick,
      password: hash,
    });
    return res.redirect('/');
  } catch (err) {
    console.error(err);
    return next(err);
  }
});

// 로그인
router.post('/login', isNotLoggedIn, (req, res, next) => {
  // authError 이 있다면 오류
  // user 가 있다면 로그인 성공이므로 req.login 메서드 호출
  passport.authenticate('local', (authError, user, info) => {
    if (authError) {
      console.error(authError);
      return next(authError);
    }
    if (!user) {
      return res.redirect(`/?loginError=${info.message}`);
    }

    // req.login 메서드는 user 객체를 넣어서 passport.serializeUser() 호출
    return req.login(user, loginError => {
      if (loginError) {
        console.error(loginError);
        return next(loginError);
      }
      return res.redirect('/');
    });
  })(req, res, next); // 미들웨어 내의 미들웨어에는 (req, res, next) 를 붙인다.
});

// 로그아웃
router.get('/logout', isLoggedIn, (req, res, next) => {
  req.logout(); // req.user 객체 제거
  req.session.destroy(); // req.session 객체 내용 제거
  res.redirect('/');
});

module.exports = router;
```

**POST /join, 회원가입 라우터**  
`bcrypt` 모듈을 사용하여 비밀번호 암호화를 하였다.  
`bcrypt.hash()` 의 두 번째 인수는 `pbkdf2` 의 반복 횟수와 비슷한 기능을 하는데 숫자가 커질수록 비밀번호를 알아내기 힘들어지지만
암호화시간도 오래 걸린다.  
12 이상을 추천하며, 최대 31까지 설정 가능하다.

**POST /login, 로그인 라우터**  
로그인 요청이 들어오면 `passport.authenticate('local')` 미들웨어가 로컬 로그인 전략을 수행한다.(전략 코드는 바로 뒤 localStrategy.js 에서 구현)  
라우터 미들웨어 안에 다른 미들웨어가 들어가있는 형태인데,  
이런 식으로 (req, res, next) 인수를 제공하여 호출하는 방식으로 미들웨어에 사용자 정의 기능을 추가하여 사용할 수 있다.

전략이 성공/실패하면 authenticate 메서드의 콜백 함수가 실행되는데  
콜백 함수의 첫 번째 매개변수인 *authError* 이 있으면 실패한 것이다.  
콜백 함수의 두 번째 매개변수인 *user* 가 있다면 성공한 것이기 때문에 `req.login()` 메서드를 호출한다.

**`Passport` 는 req 객체에 `login`, `logout` 메서드를 추가한다.**  
`req.login()` 는 `passport.serializeUser()` 를 호출하는데 이 때 user 객체를 함께 넘긴다.

**GET /logout, 로그인 라우터**  
`req.login()` 은 req.user 객체를 제거하고, `req.session.destroy()` 는 req.session 객체의 내용을 제거한다.

passport/localStrategy.js
```javascript
const passport = require('passport');
const LocalStrategy = require('passport-local').Strategy;
const bcrypt = require('bcrypt');

const User = require('../models/user');

module.exports = () => {
  passport.use(
    new LocalStrategy(
      // 전략에 관한 설정
      {
        usernameField: 'email', //   각각 usernameField, passwordField 에 해당하는 로그인 라우터의 req.body 속성명 적음
        passwordField: 'password',
      },
      // 실제 전략 수행, 위에서 넣어준 email, password 가 각각 async 함수의 첫 번째와 두 번째 매개변수가 됨
      // done() 은 passport.authenticate() 의 콜백 함수임
      async (email, password, done) => {
        try {
          const existUser = await User.findOne({ where: { email } });
          console.log('existUser.password: ', existUser.password); // $2b$12$AucHY01QpFdQUsh4qjzaMuC9.AMkfhMVrNa5maNfb0MkwjUJoMALm
          console.log('password: ', password); // 1234
          if (existUser) {
            const passwordCompare = await bcrypt.compare(
              password,
              existUser.password,
            );
            // 비밀번호가 일치하면 done 함수의 두 번째 인수로 사용자 정보 넣어서 passport.authenticate() 에 보냄
            if (passwordCompare) {
              done(null, existUser);
            } else {
              done(null, false, { message: '비밀번호가 일치하지 않습니다.' });
            }
          } else {
            done(null, false, { message: '가입되지 않은 회원입니다.' });
          }
        } catch (err) {
          console.error(err);
          done(err);
        }
      },
    ),
  );
};
```

로컬 로그인은 `passport-local` 모듈에서 *new LocalStrategy()* 로 Strategy 생성자를 불러와 그 안에 전략을 구현하면 된다.

<u>LocalStrategy 생성자의 첫 번째 인수</u> 는 전략에 관한 설정을 한다.  
`usernameField`, `passwordField` 에 일치하는 로그인 라우터의 req.body 속성명을 적으면 된다.

<u>LocalStrategy 생성자의 두 번째 인수</u> 는 실제 전략을 수행하는 로직을 넣는다.  
첫 번째 인수에서 넣어준 email, password 는 각각 async 함수의 첫 번째, 두 번째 매개변수가 된다.  
세 번째 매개변수인 `done()` 함수는 *auth.js* 의 로그인 라우터에서 사용한 `passport.authenticate()` 의 콜백 함수이다. (`(authError, user, info)`)

routes/auth.js
```javascript

... 

// passport.authenticate() 의 콜백 함수
passport.authenticate('local', (authError, user, info) => {

... 

```

DB 에서 일치하는 이메일이 있는지 조회한 후 `bcrypt` 의 `compare()` 로 비밀번호를 비교한다.  
비밀번호가 일치하면 done 함수의 두 번째 인수로 사용자 정보 넣어서 passport.authenticate() 에 보낸다.  

참고로 passport.authenticate() 의 콜백 함수 형태는 `(authError, user, info)` 이다.

두 번째 인수를 사용하지 않는 경우는 로그인이 실패했을 때 뿐이다.  
첫 번째 인수를 사용하는 경우는 서버 쪽에서 에러가 발생했을 경우이고,   
세 번째 인수를 사용할 때는 로그인 처리 과정에서 비밀번호가 일치하지 않거나 존재하지 않는 회원일 때와 같이 사용자 정의 에러가 발생했을 경우이다.

**`LocalStrategy` 의 `done` 과  `passport.authenticate` 의 `콜백 함수` 와의 관계** 는 아래와 같다.

![LocalStrategy 의 done 과  passport.authenticate 의 콜백 함수와의 관계](/assets/img/dev/2022/0103/done-authenticate.png)


`done` 이 호출된 후에 다시 `passport.authenticate` 의 콜백 함수에서 나머지 로직이 실행된다.

> 아직 auth 라우터를 연결하지 않았기때문에 코드는 동작하지 않습니다.

---

### 3.3. 카카오 로그인 구현

SNS 로그인은 로그인 인증 과정을 SNS 서비스에 맡기는 것을 의미한다.

SNS 로그인의 특징은 회원가입 절차가 따로 없다는 것인데,  
처음 로그인할 때는 회원가입+로그인 처리를 하고 두 번째 로그인부터는 로그인처리를 하기 때문에 로컬 로그인 전략보다 약간 복잡하다.

passport/kakaoStrategy.js
```javascript
const passport = require('passport');
const KakaoStrategy = require('passport-kakao').Strategy;

const User = require('../models/user');

module.exports = () => {
  passport.use(
    new KakaoStrategy(
      {
        clientID: process.env.KAKAO_ID, // 카카오에서 발급해주는 아이디 (노출되면 안되므로 .env 파일에 저장)
        callbackURL: '/auth/kakao/callback',  // 카카오로부터 인증 결과를 받을 라우터 주소
      },
      // 카카오에서는 인증 수 callbakcURL 에 적힌 주소로 accessToken, refreshToken, profile 보냄
      async (accessToken, refreshToken, profile, done) => {
        console.log('kakao profile: ', profile);
        try {
          const existUser = await User.findOne({
            where: { snsId: profile.id, provider: 'kakao' },
          });
          if (existUser) {
            // kakao 를 통해 이미 가입된 회원이면 로그인 처리
            done(null, existUser);
          } else {
            // kakao 를 통해 처음 로그인하는 회원이면 회원가입 처리 및 로그인 처리
            const newUser = await User.create({
              email: profile._json && profile._json.kakao_account.email,
              nick: profile._json && profile._json.properties.nickname,
              snsId: profile.id,
              provider: 'kakao',
            });
            done(null, newUser);
          }
        } catch (err) {
          console.error(err);
          done(err);
        }
      },
    ),
  );
};
```

```json
kakao profile:  {
  provider: 'kakao',
  id: 2073217302,
  username: 'ASSU',
  displayName: 'ASSU',
  _raw: '{"id":2073217302,"connected_at":"2022-01-10T11:17:57Z","properties":{"nickname":"ASSU"},"kakao_account":{"profile_nickname_needs_agreement":false,rofile":{"nickname":"ASSU"},"has_email":true,"email_needs_agreement":false,"is_email_valid":true,"is_email_verified":true,"email":"ASSU@gmail.com"},
  _json: {
    id: 2073217302,
    connected_at: '2022-01-10T11:17:57Z',
    properties: { nickname: 'ASSU' },
    kakao_account: {
      profile_nickname_needs_agreement: false,
      profile: [Object],
      has_email: true,
      email_needs_agreement: false,
      is_email_valid: true,
      is_email_verified: true,
      email: 'ASSU'
    }
  }
}

```

`clientID` 는 카카오에서 발급해주는 아이디이다. 노출되면 안되므로 `.env` 파일에 저장한다.  
`callbackURL` 은 카카오로부터 인증 결과를 받을 라우터 주소이다.

카카오를 통해 기존에 가입한 회원인지 조회 후 이미 회원가입한 유저이면 사용자 정보와 함께 done 함수를 호출하고 전략을 종료한다.  
만일 아직 회원가입하지 않은 유저이면 회원가입을 진행한다.

카카오에서는 인증 후 callbackURL 에 적힌 주소로 accessToken, refreshToken, profile 을 보낸다.  
profile 에는 사용자 정보들이 들어있는데 이 profile 객체에서 원하는 정보를 꺼내와 회원가입을 진행한다.

이제 카카오 로그인 라우터를 만든다.

routes/auth.js
```javascript

...

// 로그아웃
router.get('/logout', isLoggedIn, (req, res, next) => {
  req.logout(); // req.user 객체 제거
  req.session.destroy(); // req.session 객체 내용 제거
  res.redirect('/');
});

// 카카오 로그인 시작 (카카오 로그인 창으로 리다이렉트)
router.get('/kakao', passport.authenticate('kakao'));

// 카카오 로그인 성공 여부 결과받을 라우터 주소
// 로컬 로그인과 다르게 passport.authenticate 메서드에 콜백 함수를 제공하지 않음
// 왜냐면 카카오 로그인은 로그인 성공 시 내부적으로 req.login 을 호출하기 때문에 우리가 직접 호출할 필요가 없음
router.get(
        '/kakao/callback',
        passport.authenticate('kakao', {
          failureRedirect: '/',   // 콜백 함수 대신 로그인 실패 시 어디로 이동할 지 설정
        }),
        // 로그인 성공 시 어디로 이동할 지 다음 미들웨어에 설정
        (req, res) => {
          res.redirect('/');
        },
);
module.exports = router;
```

**GET /auth/kakao** 에 접근하면 카카오 로그인 과정이 시작된다.  
처음에는 카카오 로그인 창으로 리다이렉트한다. 그 창에서 로그인 후 성공 여부 결과를 **GET /auth/kakao/callback** 으로 받는다.

로컬 로그인과 다른 점은 `passport.authenticate` 메서드에 콜백 함수를 제공하지 않는다는 점이다.  
카카오 로그인은 로그인 성공 시 **내부적으로 `req.login` 을 호출하기 때문에 우리가 직접 호출할 필요가 없다.**  
콜백 함수 대신 로그인에 실패했을 때 어디로 이동할 지를 `failureRedirect` 속성에 기재한다.  
로그인 성공 시 어디로 이동할 지는 다음 미들웨어에 기재한다.

app.js
```javascript

... 

dotenv.config();
const pageRouter = require('./routes/page');
const authRouter = require('./routes/auth');

...

app.use('/', pageRouter);
app.use('/auth', authRouter);

... 

```

#### 3.3.1. 카카오 clientID 발급

[Kakao Developers](https://developers.kakao.com/) 로 가서 회원 가입 및 카카오 로그인용 애플리케이션 등록을 한다.

애플리케이션 등록은 [내 애플리케이션] 으로 이동하여 추가한다.  
애플리케이션을 추가하면 네이티브 앱 키, REST API 키, JavaScript 키, Admin 키가 나오는데 그 중 REST API 키를 복사하여 .env 파일에 넣는다. 

.env
```text
COOKIE_SECRET=assucookiesecret
KAKAO_ID=165988452ef5a14602f269c34d1cddd6
```

[앱 설정] - [플랫폼] - [Web 플랫폼 등록] 으로 이동하여 도메인 등록을 한다.  
도메인은 *http://localhost:3000* 으로 등록하며, 엔터를 눌러 여러 개의 주소를 입력할 수도 있다.

[내 애플리케이션] - [제품 설정] - [카카오 로그인] 으로 이동하여 활성화 설정을 ON 으로 설정한 후 Redirect URI 를 http://localhost:3000/auth/kakao/callback 로 설정한다.

[내 애플리케이션] - [제품 설정] - [카카오 로그인] - [동의항목] 으로 이동하여 로그인 동의항목을 설정한다.  
여기선 이메일이 반드시 필요한데 혹시나 값이 없는 경우에 대비해 *카카오 계정으로 정보 수집 후 제공* 체크박스를 체크한다.

![로그인 동의항목](/assets/img/dev/2022/0103/agree.png)

카카오 로그인 외에 구글 (`passport-google-oauth2`), 페이스북 (`passport-facebook`), 네이버 (`passport-naver`), 트위터 (`passport-twitter`) 
등의 로그인도 가능하다.

카카오톡 로그인 클릭 시 흐름

![카카오 로그인 화면](/assets/img/dev/2022/0103/1.png)
![카카오 동의 화면](/assets/img/dev/2022/0103/2.png)
![로그인 후 화면](/assets/img/dev/2022/0103/after-login.png)


![user DB](/assets/img/dev/2022/0103/user.png)

---

## 4. multer 패키지로 이미지 업로드 구현

### 4.1. 이미지 업로드 구현

[Node.js - Express (1): 미들웨어](https://assu10.github.io/dev/2021/12/01/nodejs-express-1/) 의 *2.7. `multer`* 에서 본 내용으로
이미지 업로드를 구현한다.

여기서는 input 태그를 통해 이미지 선택 시 이미지를 서버 디스크에 바로 업로드 한 후, 업로드된 주소를 클라이언트에 알린다.

> 이미지를 디스크에 저장하면 서버에 문제가 생겼을 때 이미지가 제공되지 않거나 손실될 수 있다.  
> 따라서 실제 운영 시엔 AWS S3 나 클라우드 스토리지 같은 정적 파일 제공 서비스를 이용하여 이미지를 따로 저장 및 제공하여야 한다.  
> multer-S3, multer-google-storage 와 같은 패키지를 이용하면 되는데 이는 추후 포스팅 예정이다.

routes/post.js
```javascript
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const { Post, Hashtag } = require('../models');
const { isLoggedIn } = require('./middlewares');

const router = express.Router();

try {
  fs.readdirSync('uploads');
} catch (err) {
  console.error('uploads 폴더가 없어 uploads 폴더를 생성합니다.');
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

// 이미지 업로드
router.post('/img', isLoggedIn, upload.single('img'), (req, res, next) => {
  console.log('req.file: ', req.file);
  res.json({ url: `/img/${req.file.filename}` });
});

// 이미지 업로드 후 게시글 저장
const upload2 = multer();
router.post('/', isLoggedIn, upload2.none(), async (req, res, next) => {
  try {
    const post = await Post.create({
      content: req.body.content,
      img: req.body.url,
      UserId: req.user.id,
    });

    const hashtags = req.body.content.match(/#[^\s#]*/g);
    if (hashtags) {
      const result = await Promise.all(
              hashtags.map(tag => {
                // 데이터가 존재하면 조회만 하고, 존재하지 않으면 생성 후 조회하여 리턴
                return Hashtag.findOrCreate({
                  where: { title: tag.slice(1).toLowerCase() }, // # 을 떼고 소문자로 변경
                });
              }),
      );
      console.log('result: ', result);
      // result 의 결과값은 [모델, 성셩여부] 이므로 r[0] 으로 모델만 추출
      await post.addHashtags(result.map(r => r[0]));
    }
    res.redirect('/');
  } catch (err) {
    console.error(err);
    next(err);
  }
});

module.exports = router;
```

**POST /post/img 라우터** 는 이미지 하나를 업로드받은 후 이미지 저장 경로를 클라이언트로 응답한다.  
`static 미들웨어` 가 /img 경로의 정적 파일을 제공하기 때문에 클라이언트에서 업로드한 이미지에 접근할 수 있다.


**POST /post 라우터** 는 게시글 업로드를 처리한다.  
폼 데이터 형식은 multipart 이지만 이미지 데이터가 없으므로 `upload.none()` 를 사용한다.  
`Hashtag.findOrCreate()` 은 데이터베이스에 데이터가 존재하면 가져오고, 존재하지 않으면 생성한 후 가져온다.  
`tag.slice(1).toLowerCase()` 는 # 을 떼고 소문자로 변경하는 로직이다.  

`Hashtag.findOrCreate()` 의 결과값은 [모델, 생성 여부] 이므로 `result.map(r => r[0])` 을 통해 모델만 추출하여 
해시태그 모델들을 `post.addHashtags` 메서드로 게시글과 연결한다.

![POST /post 라우터 내부 흐름](/assets/img/dev/2022/0103/hashtag.png)

---

### 4.2. 메인 페이지 로딩 시 게시글도 함께 로딩

routes/page.js
```javascript
const express = require('express');
const { isLoggedIn, isNotLoggedIn } = require('./middlewares');
const { Post, User } = require('../models');

... 

// 메인 페이지 로딩 + 게시글도 함께 로딩
router.get('/', async (req, res, next) => {
  try {
    const posts = await Post.findAll({
      include: {
        model: User,
        attributes: ['id', 'nick'],
      },
      order: [['createdAt', 'DESC']],
    });
    res.render('main', {
      title: 'ASSU',
      twits: posts,
    });
  } catch (err) {
    console.error(err);
    next(err);
  }
});

module.exports = router;
```

```javascript
const posts = await Post.findAll({
  include: {
    model: User,
    attributes: ['id', 'nick'],
  },
  order: [['createdAt', 'DESC']],
});
```

위의 쿼리는 아래와 같다.

```mysql
SELECT `Post`.`id`, `Post`.`content`, `Post`.`img`, `Post`.`UserId`, `User`.`id` AS `User.id`, 
       `User`.`nick` AS `User.nick` 
FROM `posts` AS `Post` 
    LEFT OUTER JOIN `users` AS `User` ON `Post`.`UserId` = `User`.`id` AND (`User`.`deletedAt` IS NULL) 
ORDER BY `Post`.`createdAt` DESC;
```

---

## 5. 그 외 라우터

아래는 다른 사용자를 팔로우하는 라우터이다.

routes/user.js
```javascript
const express = require('express');

const { isLoggedIn } = require('./middlewares');
const { User } = require('../models');

const router = express.Router();

// 다른 사용자를 팔로우하는 기능
router.post('/:id/follow', isLoggedIn, async (req, res, next) => {
  try {
    const user = await User.findOne({ where: { id: req.user.id } });
    if (user) {
      await user.addFollowing(parseInt(req.params.id, 10)); // user 모델의 관계 설정에서 as 옵션에 따라 이름 결정
      res.send('success');
    } else {
      res.status(404).send('no user');
    }
  } catch (err) {
    console.error(err);
    next(err);
  }
});

module.exports = router;
```

팔로우할 사람을 DB 에서 먼저 조회한 후 시퀄라이즈에서 추가한 addFollowing 메서드로 현재 로그인한 사용자와의 관계를 지정한다.

`req.user` 에도 팔로워와 팔로잉 목록을 저장하여 앞으로 사용자 정보를 조회할 때마다 팔로워와 팔로잉 목록도 함께 조회하도록 한다.

passport/index.js
```javascript

...

passport.deserializeUser((id, done) => {
  console.log('passport.deserializeUser');
  // 사용자 정보 조회 시 팔로워와 팔로잉 목록도 함께 조회
  User.findOne({
    where: { id },
    include: [
      {
        model: User,
        attributes: ['id', 'nick'],
        as: 'Followers',
      },
      {
        model: User,
        attributes: ['id', 'nick'],
        as: 'Followings',
      },
    ],
  })
          .then(user => done(null, user))
          .catch(err => done(err));
});

... 

```

```javascript
  User.findOne({
  where: { id },
  include: [
    {
      model: User,
      attributes: ['id', 'nick'],
      as: 'Followers',
    },
    {
      model: User,
      attributes: ['id', 'nick'],
      as: 'Followings',
    },
  ],
})
```

위의 쿼리는 아래와 같다.
```mysql
 SELECT `User`.`id`, `User`.`email`, `User`.`nick`, `User`.`password`, `User`.`provider`,
        `User`.`snsId`, `User`.`createdAt`, `User`.`updatedAt`, `User`.`deletedAt`, `Followers`.`id` AS `Followers.id`,
        `Followers`.`nick` AS `Followers.nick`, `Followers->follows`.`createdAt` AS `Followers.follows.createdAt`,
        `Followers->follows`.`updatedAt` AS `Followers.follows.updatedAt`,
        `Followers->follows`.`followingId` AS `Followers.follows.followingId`,
        `Followers->follows`.`followerId` AS `Followers.follows.followerId`,
        `Followings`.`id` AS `Followings.id`, `Followings`.`nick` AS `Followings.nick`,
        `Followings->follows`.`createdAt` AS `Followings.follows.createdAt`,
        `Followings->follows`.`updatedAt` AS `Followings.follows.updatedAt`,
        `Followings->follows`.`followingId` AS `Followings.follows.followingId`,
        `Followings->follows`.`followerId` AS `Followings.follows.followerId`
 FROM `users` AS `User`
     LEFT OUTER JOIN
     (
         `follows` AS `Followers->follows` INNER JOIN `users` AS `Followers` ON `Followers`.`id` = `Followers->follows`.`followerId`
     ) ON `User`.`id` = `Followers->follows`.`followingId`
              AND (`Followers`.`deletedAt` IS NULL)
     LEFT OUTER JOIN
     (
         `follows` AS `Followings->follows` INNER JOIN `users` AS `Followings` ON `Followings`.`id` = `Followings->follows`.`followingId`
     ) ON `User`.`id` = `Followings->follows`.`followerId`
              AND (`Followings`.`deletedAt` IS NULL)
 WHERE (`User`.`deletedAt` IS NULL AND `User`.`id` = 1);
```

> **deserializeUser 캐싱**  
> 라우터가 실행되기 전에 항상 deserializeUser 가 먼저 실행되기 때문에 모든 요청이 들어올 때마다 매번 사용자 정보를 조회한다.  
> 서비스의 규모가 크면 더 많은 요청이 들어오기 때문에 DB 에도 큰 부담이 가기 때문에 캐싱을 해두는 것이 좋다.  
> 단, 캐싱이 유지되는 동안 정보가 갱신되지 않으므로 캐싱 시간은 적절히 조절해야 한다.  
> 실제 서비스에서는 메모리 캐싱보다는 레디스에 사용자 정보를 캐싱한다.

팔로잉/팔로워 숫자와 팔로우 버튼을 표기하기 위해 아래도 수정한다.

routes/page.js
```javascript

... 

// 라우터용 미들웨어, 템플릿 엔진에서 사용할 user, followerCount 등을 res.locals 로 설정
// res.locals 로 설정하는 이유는 각 변수가 모든 템플릿 엔진에서 공통으로 사용되기 때문
router.use((req, res, next) => {
  res.locals.user = req.user; // 넌적스에서 user 객체를 통해 사용자 정보에 접근할 수 있도록..
  res.locals.followerCount = req.user ? req.user.Followers.length : 0;
  res.locals.followingCount = req.user ? req.user.Followings.length : 0;
  res.locals.followerIdList = req.user ? req.user.Followings.map(f => f.id) : [];
  next();
});

... 

```

팔로워 아이디 리스트를 넣는 이유는 팔로워 아이디 리스트에 게시글 작성자 아이디가 없으면 팔로우 버튼을 노출시켜주기 위함이다.

이제 해시태그로 조회하는 **GET /hashtag 라우터** 를 만들어보자.

routes/page.js
```javascript

... 

// 해시태그로 조회
router.get('/hashtag', async (req, res, next) => {
  const query = req.query.hashtag;
  if (!query) {
    return res.redirect('/');
  }
  try {
    const hashtag = await Hashtag.findOne({ where: { title: query } });
    let posts = [];
    if (hashtag) {
      // 해시태그 조회 후 있으면 시퀄라이즈에서 제공하는 getPosts 메서드로 모든 게시글 조회
      // 조회하면서 작성자 정보를 합침
      posts = await hashtag.getPosts({ include: [{ model: User }] });
    }

    return res.render('main', {
      title: `${query} | ASSU`,
      twits: posts,
    });
  } catch (err) {
    console.error(err);
    return next(err);
  }
});

... 

```

```javascript
posts = await hashtag.getPosts({ include: [{ model: User }] });
```

위의 쿼리는 아래와 같다.
```mysql
SELECT `Post`.`id`, `Post`.`content`, `Post`.`img`, `Post`.`createdAt`, `Post`.`updatedAt`, `Post`.`UserId`, `User`.`id` AS `User.id`,
       `User`.`email` AS `User.email`, `User`.`nick` AS `User.nick`, `User`.`password` AS `User.password`, `User`.`provider` AS `User.provider`,
       `User`.`snsId` AS `User.snsId`, `User`.`createdAt` AS `User.createdAt`, `User`.`updatedAt` AS `User.updatedAt`,
       `User`.`deletedAt` AS `User.deletedAt`, `postHashtag`.`createdAt` AS `postHashtag.createdAt`, `postHashtag`.`updatedAt` AS `postHashtag.updatedAt`,
       `postHashtag`.`PostId` AS `postHashtag.PostId`, `postHashtag`.`HashtagId` AS `postHashtag.HashtagId`
FROM `posts` AS `Post`
    LEFT OUTER JOIN `users` AS `User`
        ON `Post`.`UserId` = `User`.`id`
               AND (`User`.`deletedAt` IS NULL)
    INNER JOIN `postHashtag` AS `postHashtag`
        ON `Post`.`id` = `postHashtag`.`PostId` AND `postHashtag`.`HashtagId` = 1;
```

마지막으로 routes/post.js, routes/user.js 를 app.js 에 연결하고,  
업로드한 이미지를 제공할 라우터도 express.static 미들웨어로 uploads 폴더와 연결한다.

app.js
```javascript

... 

const pageRouter = require('./routes/page');
const authRouter = require('./routes/auth');
const postRouter = require('./routes/post');
const userRouter = require('./routes/user');

... 

app.use(express.static(path.join(__dirname, 'public')));
app.use('/img', express.static(path.join(__dirname, 'uploads')));

...

app.use('/', pageRouter);
app.use('/auth', authRouter);
app.use('/post', postRouter);
app.use('/user', userRouter);

... 

```

![최종 화면](/assets/img/dev/2022/0103/final.png)

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [Passport 공식문서](http://www.passportjs.org/)
* [passport-local 공식문서](https://www.npmjs.com/package/passport-local)
* [passport-kakao 공식문서](https://www.npmjs.com/package/passport-kakao)
* [bcrypt 공식 문서](https://www.npmjs.com/package/bcrypt)
* [카카오 로그인](https://developers.kakao.com/docs/latest/ko/kakaologin/common)