---
layout: post
title:  "NestJS - Custom Parameter Decorator"
date:   2023-04-22
categories: dev
tags: nestjs parameter-decorator custom-parameter-decorator
---

이 포스트는 NestJS 에서 라우트 핸들러의 매개변수에 적용할 수 있는 매개변수 데커레이터를 커스텀하여 활용하는 법에 대해 알아본다.

<!-- TOC -->
* [1. Decorator](#1-decorator)
  * [1.1. 내장 Decorator 종류](#11-내장-decorator-종류)
* [2. Custom Parameter Decorator](#2-custom-parameter-decorator)
* [3. Custom Parameter Decorator 의 data 활용](#3-custom-parameter-decorator-의-data-활용)
* [4. 유효성 검사 파이프(ValidationPipe) 적용](#4-유효성-검사-파이프validationpipe-적용)
* [5. Decorator 합성](#5-decorator-합성)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

소스는 [example](https://github.com/assu10/nestjs/tree/feature/advanced02) 에 있습니다.

---

# 1. Decorator

## 1.1. 내장 Decorator 종류

NestJS 는 ES6 에 도입된 Decorator 를 적극 활용한다.

아래는 제공되고 있는 내장 Decorator 와 그에 대응되는 Express(or Fastify) 의 객체이다.

| 내장 Decorator               | Express 객체                       |
|:---------------------------|:---------------------------------|
| `@Request()`, `@Req()`     | req                              |
| `@Response()`, `@Res()`    | res                              |
| `@Next()`                  | next                             |
| `@Session()`               | req.session                      |
| `@Param(param?: string)`   | req.param / req.params[param]    |
| `@Body(param?: string)`    | req.body / req.body[param]       |
| `@Query(param?: string)`   | req.query / req.query[param]     |
| `@Headers(param?: string)` | req.headers / req.headers[param] |
| `@Ip()`                    | req.ip                           |
| `@HostParam()`             | req.hosts                             |

---

# 2. Custom Parameter Decorator

NestJS 는 라우트 핸들러의 매개변수에 적용할 수 있는 매개변수 데커레이터를 제공한다.

> Parameter Decorator 에 대한 좀 더 상세한 내용은 [Decorator: Blog](https://assu10.github.io/dev/2023/02/25/decorator/) 을 참고하세요.

[NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/) 에서 인증/인가 Guard 로 처리하는 것을 권장했는데
로그인할 때 발급받은 JWT 를 요청마다 헤더에 포함하고 Guard 에서 이 JWT 를 검증(인증) 해서 얻은 유저 정보를 가지고 지금 수행하려는 요청을 이 유저가 실행할 수 있는지
검사(인가) 하는 과정을 거친다.

이 과정에서 라우터 핸들러에 전달된 요청 객에체 유저 정보를 추가로 실어서 이후에 이용하는 방법을 많이 이용하는데 이 때 `@User()` 라는 Custom Parameter Decorator 를 만들어서
유저 정보를 추출해보도록 하자.

[NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/) 의 *3.4. `Guard` 로 인가 처리* 에서 생성했던 AuthGuard 를 다시 구현해보자.

JWT 검증하는 부분은 생략하고 요청 객체에 유저 정보를 하드코딩하여 설정한다.


/src/auth.guard.ts
```ts
import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Observable } from 'rxjs';

export class AuthGuard implements CanActivate {
  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest();
    return this.validateRequest(request);
  }

  // 얻은 정보(request) 를 내부 규칙으로 평가 진행
  private validateRequest(request: any) {
    // JWT 를 검증해서 얻은 정보 넣음. 편의상 하드코딩함
    request.user = {
      name: 'assu',
      email: 'test@test.com',
    };
    return true;
  }
}
```

컨트롤러로 전달된 요청 객체에서 유저 정보를 얻는다.

/src/app.controller.ts
```ts
@Get()
getHello(@Req() req): string {
  console.log(req.user);
  return this.appService.getHello();
}
```

하지만 req.user 를 메서드 내부에서 직접 쓰는 것이 아니라 아래와 같이 `@User()` 데커레이터와 함께 인수로 직접 받도록 해보자.

/src/app.controller.ts
```ts
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';
import { User } from './user.decorator';

interface User {
  name: string;
  email: string;
}
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(@User() user: User): string {    // User 커스텀 데커레이터 사용
    console.log('------', user);
    return this.appService.getHello();
  }
}

```

/src/user.decorator.ts
```ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const User = createParamDecorator(
        // createParamDecorator 를 이용하여 User Decorator 선언
        (data: unknown, ctx: ExecutionContext) => {
          const request = ctx.switchToHttp().getRequest(); // 실행 콘텍스트에서 요청 객체 얻어옴
          return request.user; // AuthGuard 에서 설정한 유저 객체 반환, req.user 가 타입이 any 였다면 User 라는 타입을 갖게 됨
        },
);
```

```shell
$ npm run start:dev

$ curl --location 'http://localhost:3000' | jq

------ { name: 'assu', email: 'test@test.com' }
```

---

# 3. Custom Parameter Decorator 의 data 활용

이제 `createParamDecorator()` 의 첫 번째 인수인 `data` 를 사용해보자.

`data` 는 데커레이터 선언 시 인수로 넘기는 값인데 `@UserData('name`) 과 같이 이름만 가져와서 매개변수로 받고 싶거나 `@UserData()` 처럼 인수로 아무것도 넘기지 않으면
유저 객체 모두를 넘겨받고 싶을 때 활용할 수 있다.

/src/user-data.decorator.ts
```ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const UserData = createParamDecorator<string>(
  (data: string, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;

    return data ? user?.[data] : user;
  },
);
```

/src/app.controller.ts
```ts
  @Get('/name')
getHello2(@UserData('name') name: string): void {
  console.log('------', name);
}

@Get('/name3')
getHello3(@UserData() name: string): void {
  console.log('------', name);
}
```

```shell
$ curl --location 'http://localhost:3000/name'

------ assu


$ curl --location 'http://localhost:3000/name3'

------ { name: 'assu', email: 'test@test.com' }
```

---

# 4. 유효성 검사 파이프(ValidationPipe) 적용

이제 ValidationPipe 를 같이 적용하여 매개 변수의 유효성 검사를 해보도록 한다.

> ValidationPipe 에 대한 상세한 내용은 [NestJS - Pipe, Validation](https://assu10.github.io/dev/2023/03/11/nest-pipe/) 을 참고하세요.

먼저 오류를 발생시키기 위해 AuthGuard 의 name 에 1 를 설정해본다.

app.guard.ts
```ts
private validateRequest(request: any) {
  // JWT 를 검증해서 얻은 정보 넣음. 편의상 하드코딩함
  request.user = {
    name: 1,
    email: 'test@test.com',
  };
  return true;
}
```

그리고 class-validator 를 적용하기 위해 interface 대신 클래스로 변경한다.

```shell
$ npm i class-validator class-transformer
```

/src/app.controller.ts
```ts
import { Controller, Get, ValidationPipe } from '@nestjs/common';
import { User } from './user.decorator';
import { UserData } from './user-data.decorator';
import { IsString } from 'class-validator';

class UserEntity {
  @IsString()
  name: string;

  @IsString()
  email: string;
}
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}
...
  @Get('/with-pipe')
  getHello4(
    @User(new ValidationPipe({ validateCustomDecorators: true })) user: UserEntity): void {
    console.log('---', user);
  }
}
```

```shell
$ curl --location 'http://localhost:3000/with-pipe' | jq

{
  "statusCode": 400,
  "message": [
    "name must be a string"
  ],
  "error": "Bad Request"
}
```

---

# 5. Decorator 합성

`applyDecorator` 헬퍼 메서드를 이용하여 여러 데커레이터를 하나로 합성할 수 있다.

> Decorator 합성에 대한 좀 더 상세한 내용은 [Decorator](https://assu10.github.io/dev/2023/02/25/decorator/) 의 *2. Decorator Composition (데커레이터 합성)* 을 참고하세요.

아래는 SetMetadata, UseGuards, ApiBearerAuth, ApiUnauthorizedResponse 라는 데커레이터를 하나로 합쳐서 Auth 데커레이터로 합성하는 예시이다.

```ts
import { applyDecorators } from '@nestjs/common';

export function Auth(...roles: Role[]) {
    return applyDecorators(
        SetMetadata('roles', roles),
        UseGuards(AuthGuard, RolesGuard),
        ApiBearerAuth(),
        ApiUnauthorizedResponse({ description: 'Unauthorized'})
    );
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [Decorator: Blog](https://assu10.github.io/dev/2023/02/25/decorator/)
* [NestJS - Pipe, Validation: Blog](https://assu10.github.io/dev/2023/03/11/nest-pipe/)