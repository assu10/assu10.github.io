---
layout: post
title:  "NestJS - Exception Filter"
date:   2023-04-01
categories: dev
tags: nestjs exception-filter
---

이 포스트는 NestJS 에 예외 필터를 적용하는 방법에 대해 알아본다.

<!-- TOC -->
* [1. 예외 처리](#1-예외-처리)
* [2. 예외 필터: `@Catch`, `@UseFilters`](#2-예외-필터-catch-usefilters)
* [3. 유저 서비스](#3-유저-서비스)
  * [3.1. 예외 필터 적용](#31-예외-필터-적용)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch12), [user-service](https://github.com/assu10/nestjs/tree/user-service/ch12) 에 있습니다.

---

# 1. 예외 처리

NestJS 는 프레임워크 내에 예외 레이어가 있어서 애플리케이션을 통틀어 제대로 처리하지 못한 예외를 처리한다.

```shell
$ nest new ch12
```

```ts
@Get('error')
error(foo: any): string {
  return foo.bar();
}
```

```shell
$ curl --location 'http://localhost:3000/error' | jq

{
  "statusCode": 500,
  "message": "Internal server error"
}
```

위와 같이 에러 발생 시 응답을 JSON 형식으로 바꿔주고 있는데 이는 기본으로 내장된 전역 예외 필터가 처리하는 것이다.  
내장 예외 필터는 인식할 수 없는 에러(HttpException 이 아니고, HttpException 을 상속받지도 않은 에러) 를 InternalServerErrorException 으로 변환한다.

예를 들어 아래와 BadRequestException 은 아래와 같은 응답이 내려온다.
```ts
@Get(':id')
findOne(@Param('id') id: string) {
  console.log(id); // id 가 pp 인 경우 pp
  console.log(+id); // id 가 pp 인 경우 NaN
  if (+id < 1) {
    throw new BadRequestException('id 는 0 보다 커야함');
  }
  return null;
}
```

```shell
$ curl --location 'http://localhost:3000/0' | jq

{
  "statusCode": 400,
  "message": "id 는 0 보다 커야함",
  "error": "Bad Request"
}
```

**NestJS 에서 제공하는 모든 예외는 HttpException 을 상속**하고 있고 HttpException 의 생성자는 아래와 같다.

```ts
export declare class HttpException extends Error {
  constructor(response: string | Record<string, any>, status: number, options?: HttpExceptionOptions);
}
```

JSON 응답은 `statusCode` 와 `message` 속성을 기본으로 갖고, 이 값은 예외를 만들 때 생성자에 넣어준 response 와 status 로 구성한다.

만일 BadRequestException 을 아래와 같이 던져서 error 필드의 내용을 변경할 수도 있다.

```ts
throw new BadRequestException('id 는 0 보다 커야함', 'id exception');
```

```shell
$ curl --location 'http://localhost:3000/0' | jq

{
  "statusCode": 400,
  "message": "id 는 0 보다 커야함",
  "error": "id exception"
}
```

---

# 2. 예외 필터: `@Catch`, `@UseFilters`

NestJS 에서 제공하는 전역 예외 필터 외에 직접 Exception Filter 레이어를 두어서 예외가 발생했을 때 로그를 남기거나 응답 객체를
원하는 대로 변경하는 등의 로직을 넣을 수 있다.

아래는 예외 발생 시 모든 예외를 잡아서 요청 URL 과 예외 발생 시각을 콘솔에 출력하는 예외 필터이다.

/http-exception.filter.ts
```ts
import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch() // 처리되지 않은 모든 예외를 잡을 때 사용
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: any, host: ArgumentsHost): any {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    // 우리가 다루는 대부분의 예외는 이미 NestJS 에서 HttpException 을 상속받는 클래스들로 제공하므로 HttpException 이 아닌
    // 예외는 알 수 없는 에러이다. 따라서 이를 InternalServerErrorException 으로 처리
    if (!(exception instanceof HttpException)) {
      exception = new InternalServerErrorException();
    }

    const response = (exception as HttpException).getResponse();

    const log = {
      timestamp: new Date(),
      url: req.url,
      response,
    };

    this.logger.log(log);

    res.status((exception as HttpException).getStatus()).json(response);
  }
}
```

예외 필터는 `@UseFilter` 데커레이터로 컨트롤러, 특정 엔드포인트에 직접 적용하거나 전역으로 적용할 수 있다.  
일반적으로 예외 필터는 전역 필터 하나만 갖도록 하는 것이 일반적이다.

컨트롤러에 적용 시
```ts
@UseFilters(HttpExceptionFilter)
@Controller()
export class AppController {
    ...
}
```

엔드포인트에 적용 시
```ts
@UseFilters(HttpExceptionFilter)
@Get()
getHello(): string {
  return this.appService.getHello();
}
```

전역으로 적용 시 (일반적인 사용)
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalFilters(new HttpExceptionFilter());
  await app.listen(3000);
}
bootstrap();
```

하지만 BootStrapping 과정에서 전역 필터를 적용하면 예외 필터의 수행이 예외가 발생한 모듈 외부(main.ts) 에서 이루어지기 때문에 필터에 의존성을 주입할 수 없다는 제약이 있다.
예외 필터에 의존성 주입을 받으려면 예외 필터를 Custom Provider 로 등록하면 된다.

app.module.ts
```ts
...
import { Logger } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { HttpExceptionFilter } from './http-exception.filter';

@Module({
...
  providers: [
    Logger,
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class AppModule {}
```

그럼 이제 HttpExceptionFilter 도 다른 Provider 를 주입받아서 사용 가능하다. 예를 들면 외부 모듈에서 제공하는 Logger 객체를 생성자에 주입받아 사용 가능하다.

```ts
@Catch() // 처리되지 않은 모든 예외를 잡을 때 사용
export class HttpExceptionFilter implements ExceptionFilter {
  constructor(private logger: Logger) { }
}
```

이제 예외를 발생시키면 지정한 포맷대로 응답이 내려오는 것을 알 수 있다.
```shell
[Nest] 14443  - 04/17/2023, 5:55:09 PM     LOG Object:
{
  "timestamp": "2023-04-17T08:55:09.283Z",
  "url": "/0",
  "response": {
    "statusCode": 400,
    "message": "id 는 0 보다 커야함",
    "error": "id exception"
  }
}

[Nest] 14443  - 04/17/2023, 5:55:15 PM     LOG Object:
{
  "timestamp": "2023-04-17T08:55:15.071Z",
  "url": "/error",
  "response": {
    "statusCode": 500,
    "message": "Internal Server Error"
  }
}
```

---

# 3. 유저 서비스

---

## 3.1. 예외 필터 적용

바로 위에서 한 것처럼 HttpExceptionFilter 와 [NestJS - Logging](https://assu10.github.io/dev/2023/03/26/nest-logging/) 의 *3. 유저 서비스* 에서 만든
nest-winston Logger 를 사용하고, HttpExceptionFilter 는 Logger 를 주입받아 사용하도록 한다.

/src/exception/http-exception.filter.ts
```ts
import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch() // 처리되지 않은 모든 예외를 잡을 때 사용
export class HttpExceptionFilter implements ExceptionFilter {
  constructor(private logger: Logger) {}

  catch(exception: Error, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const stack = exception.stack;

    // 우리가 다루는 대부분의 예외는 이미 NestJS 에서 HttpException 을 상속받는 클래스들로 제공하므로 HttpException 이 아닌
    // 예외는 알 수 없는 에러이다. 따라서 이를 InternalServerErrorException 으로 처리
    if (!(exception instanceof HttpException)) {
      exception = new InternalServerErrorException();
    }

    const response = (exception as HttpException).getResponse();

    const log = {
      timestamp: new Date(),
      url: req.url,
      response,
      stack,
    };
    this.logger.log(log);

    res.status((exception as HttpException).getStatus()).json(response);
  }
}
```

예외 처리를 위한 ExceptionModule 을 생성한다.

HttpExceptionFilter 와 주입받을 Logger 를 Provider 로 선언한다.
/src/exception/exception.module.ts
```ts
import { Logger, Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { HttpExceptionFilter } from './http-exception.filter';

@Module({
  providers: [
    Logger,
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class ExceptionModule {}
```

ExceptionModule 을 AppModule 로 가져온다.

app.module.ts
```ts
import { Module } from '@nestjs/common';
import { UsersModule } from './users/users.module';
import { ConfigModule } from '@nestjs/config';
import emailConfig from './config/emailConfig';
import { validationSchema } from './config/validationSchema';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import authConfig from './config/authConfig';
import * as winston from 'winston';
import { utilities, WinstonModule } from 'nest-winston';
import { ExceptionModule } from './exception/exception.module';

@Module({
  imports: [
          ...
    ExceptionModule,
  ],
...
})
export class AppModule {}
```

에러 발생 시
```shell
[MyApp] Info    Mon Apr 17 2023 18:18:07 GMT+0900 (Korean Standard Time) undefined - {
  value: {
    timestamp: '2023-04-17T09:18:07.002Z',
    url: '/users/0',
    response: { statusCode: 500, message: 'Internal Server Error' },
    stack: "TypeError: Cannot read properties of undefined (reading 'split')\n" +
      '    at AuthGuard.validateRequest (/Users/-/Developer/05_nestjs/me/user-service/src/auth.guard.ts:17:53)\n' +
      '    at AuthGuard.canActivate (/Users/-/Developer/05_nestjs/me/user-service/src/auth.guard.ts:12:17)\n' +
      '    at GuardsConsumer.tryActivate (/Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/guards/guards-consumer.js:15:34)\n' +
      '    at canActivateFn (/Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:134:59)\n' +
      '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:42:37\n' +
      '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-proxy.js:9:23\n' +
      '    at Layer.handle [as handle_request] (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/layer.js:95:5)\n' +
      '    at next (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/route.js:144:13)\n' +
      '    at Route.dispatch (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/route.js:114:3)\n' +
      '    at Layer.handle [as handle_request] (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/layer.js:95:5)'
  },
  url: '/users/0',
  response: { statusCode: 500, message: 'Internal Server Error' },
  stack: "TypeError: Cannot read properties of undefined (reading 'split')\n" +
    '    at AuthGuard.validateRequest (/Users/-/Developer/05_nestjs/me/user-service/src/auth.guard.ts:17:53)\n' +
    '    at AuthGuard.canActivate (/Users/-/Developer/05_nestjs/me/user-service/src/auth.guard.ts:12:17)\n' +
    '    at GuardsConsumer.tryActivate (/Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/guards/guards-consumer.js:15:34)\n' +
    '    at canActivateFn (/Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:134:59)\n' +
    '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:42:37\n' +
    '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-proxy.js:9:23\n' +
    '    at Layer.handle [as handle_request] (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/layer.js:95:5)\n' +
    '    at next (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/route.js:144:13)\n' +
    '    at Route.dispatch (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/route.js:114:3)\n' +
    '    at Layer.handle [as handle_request] (/Users/-/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/layer.js:95:5)'
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [NestJS docs](https://docs.nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)