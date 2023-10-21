---
layout: post
title:  "NestJS - Middleware"
date:   2023-03-18
categories: dev
tags: nestjs middleware
---

이 포스팅은 NestJS 의 Middleware 에 대해 알아본다.

- [Middleware](#1-middleware)
- [Logger Middleware](#2-logger-middleware)
- [`MiddlewareConsumer`](#3-middlewareconsumer) 
- [전역으로 적용](#4-전역으로-적용)

> 소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch09) 에 있습니다.

---

# 1. Middleware

Middleware 는 라우트 핸들러가 클라이언트 요청을 처리하기 전에 수행하는 컴포넌트이다.  

![Middleware](/assets/img/dev/2023/0318/middleware.png)

NestJS 의 Middleware 는 [Express Middleware](https://expressjs.com/ko/guide/using-middleware.html) 와 동일하다.

Express docs 엔 아래와 같이 기술되어 있다.

- 어떤 형태의 코드라도 수행 가능
- **요청 및 응답 오브젝트에 대한 변경 가능**
- **요청/응답 주기를 종료**
  - 응답을 보내거나 에러 처리를 해야한다는 의미
  - 만일 **현재 Middleware 가 응답 주기를 끝내지 않을 것이라면 반드시 next() 호출**해야 함  
  **그렇지 않으면 애플리케이션은 hanging 상태**가 됨 (= 더 이상 아무것도 할 수 없는 상태)
- 여러 개의 Middleware 사용 시 반드시 next() 로 호출 스택 상 다음 Middleware 에게 제어권 전달

Middleware 로 아래와 같은 작업들을 수행할 수 있다.
- **쿠키 파싱**
  - 쿠키를 파싱하여 사용하기 쉬운 데이터 구조로 변경하면 라우터 핸들러가 매번 쿠키를 파싱할 필요가 없음 
- **세션 관리**
  - 세션 쿠키를 찾아 해당 쿠키에 대한 세션의 상태를 조회해서 request 에 세션 정보 추가
- **인증/인가**
  - 사용자가 서비스에 접근 가능한 권한이 있는지 확인
  - NestJS 는 인가 구현 시 `Guard` 를 사용하도록 권장하고 있음
- **본문 파싱**

이 외에 DB Transaction 이 필요한 요청인 경우 Transaction 을 걸어 동작 수행 후 커밋하는 등의 Custom Middleware 를 활용할 수도 있다.

> Middleware 와 비슷한 개념인 Interceptor 는 추후 다룰 예정입니다.

> `Guard` 는 [NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/) 를 참고하세요. 

---

# 2. Logger Middleware

Middleware 는 함수로 작성하거나 `NestMiddleware` 인터페이스를 구현한 클래스로 작성 가능하다.

아래는 request 정보를 로깅하기 위해 `NestMiddleware` 인터페이스를 구현한 클래스로 Middleware 로 Logger 를 구현해보는 예시이다.

```shell
$ nest new ch09
```

/src/logger/logger.middleware.ts
```ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log('Request...');
    //res.send('DONE'); // 이 부분을 주석 해제하고 next() 를 주석처리하면 미들웨어 수행 중단
    next(); // res.send() 와 next() 를 주석 처리하면 애플리케이션은 hanging 상태가 됨
  }
}
```

Middleware 를 모듈에 포함시키려면 `NestModule` 인터페이스 구현 후 `NestModule` 에 선언된 `configure()` 를 통해 Middleware 를 설정한다.

app.module.ts
```ts
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { LoggerMiddleware } from './logger/logger.middleware';

@Module({
  imports: [],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): any {
    consumer.apply(LoggerMiddleware).forRoutes('/test');
  }
}
```

```shell
$ curl --location 'http://localhost:3000/test' | jq

Request...
```

---

# 3. `MiddlewareConsumer`

위에서 `NestModule` 의 `configure()` 의 인수로 전달된 `MiddlewareConsumer` 객체를 이용하여 Middleware 를 어디에 적용할 지 관리할 수 있다.

MiddlewareConsumer.apply() 시그니처
```ts
apply(...middleware: (Type<any> | Function)[]): MiddlewareConfigProxy;
```

`apply()` 에 Middleware 함수나 클래스를 콤마로 나열하면 되고, 나열된 순서대로 적용된다.

만일 미들웨어가 하나 더 있다면 아래와 같이 하면 된다.

/src/logger/logger.middleware.ts
```ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class Logger2Middleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log('Request2...');
    //res.send('DONE'); // 이 부분을 주석 해제하고 next() 를 주석처리하면 미들웨어 수행 중단
    next(); // res.send() 와 next() 를 주석 처리하면 애플리케이션은 hanging 상태가 됨
  }
}
```

app.module.ts
```ts
configure(consumer: MiddlewareConsumer): any {
  consumer.apply(LoggerMiddleware, Logger2Middleware).forRoutes('/test');
}
```

---

forRoutes() 시그니처
```ts
export interface MiddlewareConfigProxy {
    /**
     * Excludes routes from the currently processed middleware.
     *
     * @param {(string | RouteInfo)[]} routes
     * @returns {MiddlewareConfigProxy}
     */
    exclude(...routes: (string | RouteInfo)[]): MiddlewareConfigProxy;
    /**
     * Attaches passed either routes or controllers to the currently configured middleware.
     * If you pass a class, Nest would attach middleware to every path defined within this controller.
     *
     * @param {(string | Type | RouteInfo)[]} routes
     * @returns {MiddlewareConsumer}
     */
    forRoutes(...routes: (string | Type<any> | RouteInfo)[]): MiddlewareConsumer;
}
```

`MiddlewareConfigProxy.forRoutes()` 의 인수로 문자열 형식으로 경로를 넘기거나 컨트롤러 클래스명을 주거나 `RouteInfo` 객체를 넘길 수 있다.  
보통은 컨트롤러 클래스명을 준다.

app.module.ts
```ts
configure(consumer: MiddlewareConsumer): any {
  consumer
    .apply(LoggerMiddleware, Logger2Middleware)
    .forRoutes(AppController);
}
```

---

아래와 같이 응답도 주지 않고 next() 처리도 하지 않으면 애플리케이션이 hanging 상태가 되어 뒤에 오는 요청을 받을 수 없다.  
logger.middleware.ts
```ts
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log('Request...');
    //res.send('DONE'); // 이 부분을 주석 해제하고 next() 를 주석처리하면 미들웨어 수행 중단
    //next(); // res.send() 와 next() 를 주석 처리하면 애플리케이션은 hanging 상태가 됨
  }
}
```

아래와 같이 응답도 주고 next() 처리도 하면 아래와 같은 오류가 발생한다. (뒤에 오는 요청을 받을 수 있음)  
logger.middleware.ts
```ts
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log('Request...');
    res.send('DONE'); // 이 부분을 주석 해제하고 next() 를 주석처리하면 미들웨어 수행 중단
    next(); // res.send() 와 next() 를 주석 처리하면 애플리케이션은 hanging 상태가 됨
  }
}
```

```shell
Request...
Request2...
[Nest] 71397  - 04/08/2023, 2:53:20 PM   ERROR [ExceptionsHandler] Cannot set headers after they are sent to the client
Error: Cannot set headers after they are sent to the client
```

아래와 같이 응답만 주고 next() 처리를 하지 않으면 다음 Middleware 는 실행되지 않는다.  
logger.middleware.ts
```ts
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log('Request...');
    res.send('DONE'); // 이 부분을 주석 해제하고 next() 를 주석처리하면 미들웨어 수행 중단
    //next(); // res.send() 와 next() 를 주석 처리하면 애플리케이션은 hanging 상태가 됨
  }
}
```

---

`MiddlewareConfigProxy.exclude()` 는 Middleware 를 적용하지 않을 라우팅 경로를 설정한다.

app.module.ts
```ts
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): any {
    consumer
      .apply(LoggerMiddleware, Logger2Middleware)
      .exclude({ path: '/test', method: RequestMethod.GET })  // /test 경로의 GET 요청은 미들웨어 무시
      .forRoutes(AppController);
  }
}
```

---

# 4. 전역으로 적용

위에서 `NestMiddleware` 인터페이스를 구현한 클래스로 Middleware 로 Logger 를 구현해보았다.  
이제 Middleware 를 전역으로 적용하기 위해 함수로 Middleware 를 만들어본다.

> Middleware 를 모든 모듈에 적용하려면 main.ts 수정이 필요하다.  
> main.ts 에서 `NestFactory.create` 로 만든 앱은 `INestApplication` 타입을 갖는데 여기 정의된 use() 메서드를 사용하여 Middleware 를 설정한다.  
> 하지만 use() 메서드는 클래스를 인수로 받을 수 없기 때문에 전역으로 적용할 Middleware 는 `NestMiddleware` 인터페이스를 구현한 클래스로 만드는 것이 아니라 함수로 만들어야 한다.

/src/logger3.middleware.ts
```ts
import { Request, Response, NextFunction } from 'express';

export function logger3(req: Request, res: Response, next: NextFunction) {
  console.log('Request3...');
  next();
}
```

이제 main.ts 를 아래와 같이 수정한다.
main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { logger3 } from './logger/logger3.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(logger3);
  await app.listen(3000);
}
bootstrap();
```

```shell
$ curl --location --request POST 'http://localhost:3000/test' | jq
```

다른 Middleware 보다 전역으로 설정한 logger3 Middleware 가 먼저 실행된다.
```shell
Request3...
Request...
Request2...
```


만일 app.use() 에 클래스를 넘기면 request 시 아래와 같은 오류가 뜬다.
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger2Middleware } from './logger/logger2.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(Logger2Middleware);
  await app.listen(3000);
}
bootstrap();
```

```shell
ERROR [ExceptionsHandler] Class constructor Logger2Middleware cannot be invoked without 'new'
TypeError: Class constructor Logger2Middleware cannot be invoked without 'new'
```

함수로 만든 Middleware 는 DI 컨테이너를 사용할 수 없다는 단점이 있다. (= Provider 를 주입받아 사용 불가)

> Middleware 와 비슷한 `Guard` 를 이용하여 Router Handler 에서 요청을 처리하기 전 응답 객체를 처리하는 방법도 있다.  
> 이 부분은 추후 알아볼 예정입니다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [NestJS docs](https://docs.nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [Express Middleware](https://expressjs.com/ko/guide/using-middleware.html)