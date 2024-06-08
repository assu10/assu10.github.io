---
layout: post
title:  "NestJS - Middleware, Guard, Interceptor, Pipe, ExceptionFilter 그리고 Life Cycle"
date:   2023-04-08
categories: dev
tags: nestjs middleware guard interceptor pipe exception-filter life-cycle
---

이 포스트는 혼동하기 쉬운  Middleware, Guard, Interceptor, Pipe, ExceptionFilter 에 대해 간단히 비교해본다.

<!-- TOC -->
* [Middleware](#middleware)
* [Guard](#guard)
* [Interceptor](#interceptor)
* [Pipe](#pipe)
* [ExceptionFilter](#exceptionfilter)
* [전체적인 요청/응답 생명주기](#전체적인-요청응답-생명주기)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->


> 각각에 대한 설명은  
> [NestJS - Middleware](https://assu10.github.io/dev/2023/03/18/nest-middleware/),  
> [NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/),  
> [NestJS - Interceptor](https://assu10.github.io/dev/2023/04/02/nest-interceptor),  
> [NestJS - Pipe, Validation](https://assu10.github.io/dev/2023/03/11/nest-pipe/),  
> [NestJS - Exception Filter](https://assu10.github.io/dev/2023/04/01/nest-exception-filter/)  
> 를 참고하세요.

---

# Middleware

**Middleware 는 라우트 핸들러가 클라이언트 요청을 처리하기 전에 수행하는 컴포넌트**이다.

![Middleware](/assets/img/dev/2023/0318/middleware.png)

Middleware 실행 순서는 전역으로 바인딩된 Middleware 실행 후 모듈에 바인딩되는 순서대로 실행한다.  
다른 모듈에 바인딩되어 있는 Middleware 들이 있으면 먼저 Root Module 에 바인딩된 Middleware 를 실행하고 imports 에 정의한 순서대로 실행된다.

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

# Guard

**Guard 도 라우트 핸들러가 클라이언트 요청을 처리하기 전에 수행하는 컴포넌트**이다.  

![Guard](/assets/img/dev/2023/0319/guard.png)


인가(Authorization) 는 인증을 통과한 유저가 요청 기능을 사용할 권한이 있는지 판별하는 것으로, 인증(Authentication) 은 Middleware 로 구현하고 
인가는 Guard 를 이용하여 구현하는 방법도 있고, 인증/인가를 Guard 를 이용하여 구현하는 방법도 있다.

> **인증(Authentication) 실패 시** - 401 Unauthorized  
> **인가(Authorization) 실패 시** - 403 Forbidden

**인가를 인증처럼 Middleware 로 구현할 수 없는 이유**는 아래와 같다.
- Middleware 는 실행 콘텍스트(ExecutionContext) 에 접근 불가
- 자신의 일만 수행하고 next() 호출하기 때문에 다음에 어떤 핸들러가 실행될 지 알 수 없음
- 반면, `Guard` 는 실행 콘텍스트 인스턴스에 접근이 가능하기 때문에 다음에 실행될 작업을 알고 있음

Guard 의 실행 순서는 전역으로 바인딩된 Guard 를 먼저 시작한 후 컨트롤러에 정의된 순서대로 실행한다.

아래 코드에서 Guard1, Guard2, Guard3 의 순서로 실행된다.
```ts
@UseUrards(Guard1, Guard2)
@Controller('test')
export class TestController {
  @UseUrards(Guard3)
  @Get()
  test(): any {
      return null;
  }
}
```

---

# Interceptor

**Interceptor 는 요청과 응답을 가로채서 변경을 가할 수 있는 컴포넌트**이다.

Interceptor 로 아래와 같은 작업들을 수행할 수 있다.
- 메서드 실행 전/후 추가 로직 바인딩
- 함수에서 반환된 결과 변환
- 함수에서 던져진 예외 변환
- 특정 조건에 따라 기능 재정의 (예: 캐싱)

Interceptor 도 Guard 와 유사하게 전역으로 바인딩된 Interceptor 실행 후 컨트롤러에 정의된 순서대로 실행된다.  
다만 Guard 와 다른 점은 Interceptor 는 RxJS 의 Observable 객체를 반환하는데 이는 요청의 실행 순서와 반대로 동작한다는 점이다.  
즉, 요청은 전역 → 컨트롤러 → 라우터 의 순이고 응답은 라우터 → 컨트롤러 → 전역 의 순으로 동작한다.

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

# Pipe

**Pipe 는 요청이 라우터 핸들러로 전달되기 전에 요청 객체를 변환하거나 검사**할 수 있도록 한다.  
미들웨어와 비슷하지만 미들웨어를 현재 요청이 어떤 핸들러에서 수행되고 어떤 매개변수를 갖는지에 대한 실행 context 를 알지 못하므로
모든 context 에서 사용이 불가하다.

Pipe 는 보통 아래 두 가지 목적으로 사용된다.
- transformation
  - 입력 데이터를 원하는 형식으로 변환
  - ex) user/1 경로 매개변수 문자열 1을 정수로 변환
- validation
  - 입력 데이터가 유효하지 않은 경우 예외 처리

Pipe 는 동작 순서가 조금 특이한데 Pipe 가 여러 레벨로 적용되어 있으면 전역 먼저 실행된 후 나중에 바인딩되는 Pipe 순으로 적용된다는 점은
다른 컴포넌트들과 동일하지만 Pipe 가 적용된 라우터의 매개변수가 여러 개일 경우 정의한 순서의 역순으로 적용된다는 점이 특이하다.

예를 들어 아래 코드를 보자.
```ts
@UsePipes(GeneralValidationPipe)
@Controller('test')
export class TestController {
    
    @UsePipes(RouteSpecificPipe)
    @Get()
    test(
        @Body() body: string,
        @Param() param: string,
        @Query() query: string
    ) {
        return null;
    }
}
```

test() 에 Pipe 가 둘 다 적용되는데 그 실행 순서는 GeneralValidationPipe → RouteSpecificPipe 순으로 적용된다.  
하지만 Pipe 를 각각 적용하는 test() 의 매개변수는 query → param → body 의 순서대로 적용된다.  
즉, GeneralValidationPipe 가 query → param → body 순으로 적용되고, 이후 RouteSpecificPipe 도 같은 순으로 적용된다.

---

# ExceptionFilter

NestJS 의 내장 예외 레이어는 인식할 수 없는 에러를 InternalServerErrorException 으로 변환해주는데 **직접 Exception Filter 를 레이어를 두어서
예외가 발생했을 때 로그를 남기거나 응답 객체를 원하는 대로 변경하는 등의 로직**을 넣을 수 있다.

**유일하게 ExceptionFilter 는 전역 필터가 먼저 적용되지 않는다.**

라우터 → 컨트롤러 → 전역 으로 바딩인된 순서대로 동작한다.

그리고 필터가 예외를 catch 하면 다른 필터가 동일한 예외를 잡을 수 없다. (라우터에 적용된 ExceptionFilter 가 이미 예외를 잡아서 처리했으므로 전역 ExceptionFilter 가 또 잡아서 처리할 필요가 없음)

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

# 전체적인 요청/응답 생명주기

생명 주기에 대해 위 내용을 종합하면 아래와 같다.

![Life Cycle](/assets/img/dev/2023/0408/lifecycle.png)

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [NestJS - Middleware](https://assu10.github.io/dev/2023/03/18/nest-middleware/)
* [NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/)
* [NestJS - Interceptor](https://assu10.github.io/dev/2023/04/02/nest-interceptor)
* [NestJS - Pipe, Validation](https://assu10.github.io/dev/2023/03/11/nest-pipe/)
* [NestJS - Exception Filter](https://assu10.github.io/dev/2023/04/01/nest-exception-filter/)