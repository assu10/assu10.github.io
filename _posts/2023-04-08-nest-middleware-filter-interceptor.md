---
layout: post
title:  "NestJS- Middleware vs ExceptionFilter vs Interceptor"
date:   2023-04-08
categories: dev
tags: nestjs middleware exception-filter interceptor
---

이 포스팅은 혼동하기 쉬운 Middleware, ExceptionFilter, Interceptor 에 대해 간단히 비교해본다.

> 각각에 대한 설명은 [NestJS - Middleware](https://assu10.github.io/dev/2023/03/18/nest-middleware/), 
[NestJS - Exception Filter](https://assu10.github.io/dev/2023/04/01/nest-exception-filter/), 
[NestJS - Interceptor](https://assu10.github.io/dev/2023/04/02/nest-interceptor) 를 참고하세요.

# Middleware

Middleware 는 라우트 핸들러가 클라이언트 요청을 처리하기 전에 수행하는 컴포넌트이다.

![Middleware](/assets/img/dev/2023/0318/middleware.png)

Middleware 로 아래와 같은 작업들을 수행할 수 있다.
- **쿠키 파싱**
    - 쿠키를 파싱하여 사용하기 쉬운 데이터 구조로 변경하면 라우터 핸들러가 매번 쿠키를 파싱할 필요가 없음
- **세션 관리**
    - 세션 쿠키를 찾아 해당 쿠키에 대한 세션의 상태를 조회해서 request 에 세션 정보 추가
- **인증/인가**
    - 사용자가 서비스에 접근 가능한 권한이 있는지 확인
    - NestJS 는 인가 구현 시 `Guard` 를 사용하도록 권장하고 있음
- **본문 파싱**

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

---

# ExceptionFilter

NestJS 의 내장 예외 레이어는 인식할 수 없는 에러를 InternalServerErrorException 으로 변환해주는데 직접 Exception Filter 를 레이어를 두어서
예외가 발생했을 때 로그를 남기거나 응답 객체를 원하는 대로 변경하는 등의 로직을 넣을 수 있다.

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

---

# Interceptor

Interceptor 는 요청과 응답을 가로채서 변경을 가할 수 있는 컴포넌트이다.

Interceptor 로 아래와 같은 작업들을 수행할 수 있다.  
- 메서드 실행 전/후 추가 로직 바인딩
- 함수에서 반환된 결과 변환
- 함수에서 던져진 예외 변환
- 특정 조건에 따라 기능 재정의 (예: 캐싱)

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
  intercept(
    context: ExecutionContext,
    next: CallHandler<any>,
  ): Observable<any> | Promise<Observable<any>> {
    
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

[NestJS - Middleware](https://assu10.github.io/dev/2023/03/18/nest-middleware/) 에서 본 Middleware 와 비슷하지만 수행 시점에 차이가 있다.

- Middleware
  - 요청이 라우트 핸들러로 전달되기 전에 동작
  - 여러 개의 Middleware 를 조합하여 각기 다른 목적을 가진 Middleware 로직 수행 가능
  - 다음 Middleware 에게 제어권을 넘기지 않고 요청/응답 주기 종료 가능

- Interceptor
  - 요청에 대한 하루트 핸들러의 처리 전/후 호출되어 요청과 응답을 다룰 수 있음

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [NestJS - Middleware](https://assu10.github.io/dev/2023/03/18/nest-middleware/)
* [NestJS - Exception Filter](https://assu10.github.io/dev/2023/04/01/nest-exception-filter/)
* [NestJS - Interceptor](https://assu10.github.io/dev/2023/04/02/nest-interceptor)