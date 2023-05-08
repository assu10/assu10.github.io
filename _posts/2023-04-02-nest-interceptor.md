---
layout: post
title:  "NestJS - Interceptor"
date:   2023-04-02
categories: dev
tags: nestjs interceptor
---

이 포스팅은 NestJS 의 Interceptor 에 대해 알아본다.

- [Interceptor: `@UseInterceptors`](#1-interceptor--useinterceptors)
- [응답과 예외 매핑](#2-응답과-예외-매핑)
  - [응답 변형](#21-응답-변형)
  - [예외 매핑](#22-예외-매핑)
- [유저 서비스](#3-유저-서비스)
  - [Interceptor 적용](#31-interceptor-적용)

소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch13), [user-service](https://github.com/assu10/nestjs/tree/user-service/ch13) 에 있습니다.

---

# 1. Interceptor: `@UseInterceptors`

**Interceptor 는 요청과 응답을 가로채서 변경을 가할 수 있는 컴포넌트**이다.

<**Interceptor 로 할 수 있는 기능**>  
- 메서드 실행 전/후 추가 로직 바인딩
- 함수에서 반환된 결과 변환
- 함수에서 던져진 예외 변환
- 특정 조건에 따라 기능 재정의 (예: 캐싱)

[NestJS - Middleware](https://assu10.github.io/dev/2023/03/18/nest-middleware/) 에서 본 Middleware 와 비슷하지만 수행 시점에 차이가 있다.

- Middleware
  - 요청이 라우트 핸들러로 전달되기 전에 동작
  - 여러 개의 Middleware 를 조합하여 각기 다른 목적을 가진 Middleware 로직 수행 가능
  - 다음 Middleware 에게 제어권을 넘기지 않고 요청/응답 주기 종료 가능

- Interceptor
  - 요청에 대한 하루트 핸들러의 처리 전/후 호출되어 요청과 응답을 다룰 수 있음

라우트 핸들러가 요청을 처리하기 전/후에 로그를 남기고 싶을 때 Interceptor 를 아래와 같이 활용할 수 있다.

```shell
$ nest new ch13
```

logging.interceptor.ts
```ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {  // NestInterceptor 인터페이스 구현
  
  // NestInterceptor 인터페이스의 intercept 함수 구현
  intercept(context: ExecutionContext, next: CallHandler<any>): Observable<any> | Promise<Observable<any>> {
    
    // 요청이 전달되기 전 로그 출력
    console.log('Before log...');

    const now = Date.now();

    return next
      .handle()
      // 요청을 처리한 후 로그 출력
      .pipe(tap(() => console.log(`After log... ${Date.now() - now} ms`)));
  }
}
```

Interceptor 를 특정 컨트롤러나 메서드에 적용하고 싶다면 `@UseInterceptors()` 데커레이터를 이용하면 된다.

> [NestJS - Exception Filter](https://assu10.github.io/dev/2023/04/01/nest-exception-filter/) 의 _2. 예외 필터: `@Catch`, `@UseFilters`_ 에 나오는
> `@UseFilters` 데커레이터 사용법과 동일합니다.

지금은 전역으로 적용하여 로그를 확인해보도록 한다.

main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { LoggingInterceptor } from './logging.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalInterceptors(new LoggingInterceptor());
  await app.listen(3000);
}
bootstrap();
```

이제 서버를 시작한 후 요청을 보내서 로그를 확인한다.
```shell
$ npm run start:dev

$ curl --location 'http://localhost:3000' | jq
```

```shell
curl --location 'http://localhost:3000' | jq
```

`NestInterceptor` 인터페이스의 시그니처는 아래와 같다.

```ts
export interface NestInterceptor<T = any, R = any> {
    /**
     * Method to implement a custom interceptor.
     *
     * @param context an `ExecutionContext` object providing methods to access the
     * route handler and class about to be invoked.
     * @param next a reference to the `CallHandler`, which provides access to an
     * `Observable` representing the response stream from the route handler.
     */
    intercept(context: ExecutionContext, next: CallHandler<T>): Observable<R> | Promise<Observable<R>>;
}

/**
 * Interface providing access to the response stream.
 *
 * @see [Interceptors](https://docs.nestjs.com/interceptors)
 *
 * @publicApi
 */
export interface CallHandler<T = any> {
  /**
   * Returns an `Observable` representing the response stream from the route
   * handler.
   */
  handle(): Observable<T>;
}
```

`NestInterceptor` 의 interceptor() 은 ExecutionContext, CallHandler<T> 이렇게 2개의 인자를 받는다.


> `NestInterceptor` 의 좀 더 상세한 내용은 [Nest Interceptors 공식문서](https://docs.nestjs.com/interceptors) 를 참고하세요.

ExecutionContext 는 [NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/) 의 _2.1. 실행 콘텍스트_ 에서 설명한 것과 동일한 컨텍스트이다.

CallHandler 인터페이스는 handle() 메서드를 구현해야 하는데 **이 handle() 메서드의 역할은 라우트 핸들러에서 전달된 응답 스트림을 돌려주고 RxJS 의 Observable 을 리턴**한다.  
그렇기 때문에 만약에 Interceptor 에서 핸드러가 제공하는 handle() 메서드를 호출하지 않으면 라우터 핸들러가 동작하지 않는다.  
handle() 을 호출하여 Observable 을 수신한 후 응답 스트림에 추가 작업을 수행할 수 있다.

logging.interceptor.ts
```ts
...
return (
    next
      .handle() // handle() 메서드 호출
      // 요청을 처리한 후 로그 출력
      .pipe(tap(() => console.log(`After log... ${Date.now() - now} ms`)))
  );
```

> 응답을 다루는 방법은 RxJS 에서 제공하는 다양한 메서드로 구현이 가능한데 위에선 tap() 을 사용함

---

# 2. 응답과 예외 매핑

Interceptor 를 통해 응답과 예외에 변형을 가하는 예시를 보자.

## 2.1. 응답 변형

아래는 라우터 핸들러에서 전달한 응답을 객체로 감싸서 전달하도록 하는 TransformInterceptor 예시이다.

transform.interceptor.ts
```ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  data: T;
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, Response<T>>
{
  intercept(context: ExecutionContext, next: CallHandler<T>): Observable<Response<T>> | Promise<Observable<Response<T>>> {
    return next
        .handle()
        .pipe(map((data) => {
          return { data };
      }),
    );
  }
}
```

위에서 예시로 들었던 LoggingInterceptor 와 비교해보자.

logging.interceptor.ts
```ts
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  // NestInterceptor 인터페이스 구현

  // NestInterceptor 인터페이스의 intercept 함수 구현
  intercept(context: ExecutionContext, next: CallHandler<any>): Observable<any> | Promise<Observable<any>> {
...
  }
}
```

TransformInterceptor 는 LoggingInterceptor 와 다르게 TransformInterceptor<T> 이렇게 Generic 으로 타입 T 를 선언하고 있다.

NestInterceptor 인터페이스의 시그니처를 보면 Generic 으로 T, R 타입 2개를 선언하도록 되어 있는데 둘 다 기본이 any 타입이라 어떤 타입이 와도 상관없다.

```ts
export interface NestInterceptor<T = any, R = any> {
    intercept(context: ExecutionContext, next: CallHandler<T>): Observable<R> | Promise<Observable<R>>;
}
```

T 는 응답 스트림을 지원하는 Observable 타입이어야 하고,  
R 은 응답의 값을 Observable 로 감싼 타입을 정해주어야 한다. (타입스크립트를 통해 타입을 명확히 지정해주면 더 안전함)

TransformInterceptor 에선 T 는 any 타입이고, R 은 Response 를 지정하였다.

위의 Response 는 요구 사항에 맞게 정의한 타입인 data 속성을 갖는 객체가 되도록 강제하는 역할이다.

이 TransformInterceptor 을 `useGlobalInterceptors` 데커레이터를 통해 전역으로 적용한다.

main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { LoggingInterceptor } from './logging.interceptor';
import { TransformInterceptor } from './transform.initerceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalInterceptors(
    new LoggingInterceptor(),
    new TransformInterceptor(),
  );
  await app.listen(3000);
}
bootstrap();
```

이제 서버 시작 후 요청을 보내본다.
```shell
$ npm run start:dev

$ curl --location 'http://localhost:3000' | jq
{
  "data": "Hello World!"
}
```

```shell
Before log...
After log... 2 ms
```

---

## 2.2. 예외 매핑

라우트 핸들링 중 발생한 예외를 잡아 모두 400 BadRequest 로 변환해보도록 한다. 예외를 변환하는 것은 ExceptionFilter 를 사용하는 것이 좋지만 Interceptor 를 통해서도 가능하다는 정도만 알아두자.

error.interceptor.ts
```ts
import {
  BadRequestException,
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { catchError, Observable, throwError } from 'rxjs';

@Injectable()
export class ErrorInterceptor implements NestInterceptor {
    intercept(context: ExecutionContext, next: CallHandler<any>): Observable<any> | Promise<Observable<any>> {
        return next
            .handle()
            .pipe(
                catchError(err => throwError(() => new BadRequestException()))
            )
    }
}
```

위 Interceptor 는 전역이 아닌 GET / 엔드포인트에 적용해본다.

```ts
@UseInterceptors(ErrorInterceptor)
@Get()
getHello(): string {
  throw new InternalServerErrorException();
  return this.appService.getHello();
}
```

```shell
$ curl --location 'http://localhost:3000/' | jq

{
  "statusCode": 400,
  "message": "Bad Request"
}
```

```shell
Before log...
```

---

# 3. 유저 서비스

요청을 처리하기 전 HTTP 메서드와 URL 를 로그로 남기고, 응답 시 HTTP 메서드와 URL, 응답 결과를 로그로 남기는 Interceptor 를 적용해본다.

---

## 3.1. Interceptor 적용

/src/logging/logging.interceptor.ts
```ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  constructor(private logger: Logger) {}

  intercept(context: ExecutionContext, next: CallHandler<any>): Observable<any> | Promise<Observable<any>> {
    // 실행 콘텍스트에 포함된 첫 번째 객체를 가져옴 (이 객체에로부터 요청 정보 얻을 수 있음)
    const { method, url, body } = context.getArgByIndex(0);
    this.logger.log(`Request to ${method} ${url}`);

    return next
      .handle()
      .pipe(
        tap((data) =>
          this.logger.log(
            `Response from ${method} ${url} \n response: ${JSON.stringify(data)}`,
          ),
        ),
      );
  }
}
```

위 Interceptor 를 main.ts 에 바로 적용하는 것이 아니라 LoggingModule 로 분리하여 AppModule 에 적용하도록 한다.

/src/logging/logging.module.ts
```ts
import { Logger, Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { LoggingInterceptor } from './logging.interceptor';

@Module({
  providers: [
    Logger,
    { provide: APP_INTERCEPTOR, useClass: LoggingInterceptor },
  ],
})
export class LoggingModule {}
```

app.module.ts
```ts
import { LoggingModule } from './logging/logging.module';

@Module({
  imports: [
    ...
    LoggingModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
```

이제 유저 정보 조회 요청을 해본다.

오류 발생 시
```shell
$ curl --location 'http://localhost:3000/users/01GXN39KWVPKV7WZR5XFD0A5FH' | jq
{
  "statusCode": 500,
  "message": "Internal Server Error"
}
```

```shell
{
  "timestamp": "2023-04-23T07:15:01.645Z",
  "url": "/users/01GXN39KWVPKV7WZR5XFD0A5FH",
  "response": {
    "statusCode": 500,
    "message": "Internal Server Error"
  },
  "stack": "TypeError: Cannot read properties of undefined (reading 'split')\n    at AuthGuard.validateRequest (/Users/05_nestjs/me/user-service/src/auth.guard.ts:17:53)\n    at AuthGuard.canActivate (/Users/juhyunlee/Developer/05_nestjs/me/user-service/src/auth.guard.ts:12:17)\n    at GuardsConsumer.tryActivate (/Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/guards/guards-consumer.js:15:34)\n    at canActivateFn (/Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:134:59)\n    at /Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:42:37\n    at /Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-proxy.js:9:23\n    at Layer.handle [as handle_request] (/Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/layer.js:95:5)\n    at next (/Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/route.js:144:13)\n    at Route.dispatch (/Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/route.js:114:3)\n    at Layer.handle [as handle_request] (/Users/juhyunlee/Developer/05_nestjs/me/user-service/node_modules/express/lib/router/layer.js:95:5)"
}
```

정상 요청 시
```shell
$ curl --location 'http://localhost:3000/users/01GXN39KWVPKV7WZR5XFD0A5FH' \
--header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAxR1hOMzlLV1ZQS1Y3V1pSNVhGRDBBNUZIIiwibmFtZSI6ImFzc3UiLCJlbWFpbCI6InRlc3RAdGVzdC5jb20iLCJpYXQiOjE2ODIyMzQ3MjksImV4cCI6MTY4MjMyMTEyOSwiYXVkIjoidGVzdC5jb20iLCJpc3MiOiJ0ZXN0LmNvbSJ9.uXZmMGu4ynWQxfpAh-2iNbcJMrMh4iBdztoXZX2dwoA' | jq

{
  "id": "01GXN39KWVPKV7WZR5XFD0A5FH",
  "name": "assu",
  "email": "test@test.com"
}
```

```shell
[MyApp] Info    4/23/2023, 4:27:54 PM Request to GET /users/01GXN39KWVPKV7WZR5XFD0A5FH - {}
[MyApp] Info    4/23/2023, 4:27:54 PM Response from GET /users/01GXN39KWVPKV7WZR5XFD0A5FH 
 response: {"id":"01GXN39KWVPKV7WZR5XFD0A5FH","name":"assu","email":"test@test.com"} - {}
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [NestJS docs](https://docs.nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [Nest Interceptors 공식문서](https://docs.nestjs.com/interceptors)