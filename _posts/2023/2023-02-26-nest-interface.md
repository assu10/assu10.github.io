---
layout: post
title:  "NestJS - Interface"
date:   2023-02-26
categories: dev
tags: nestjs interface
---

이 포스트는 NestJS 의 Controller 에 대해 알아본다.    

<!-- TOC -->
* [1. Controller](#1-controller)
  * [1.1. NestJS 구성 요소 약어](#11-nestjs-구성-요소-약어)
  * [1.2. Routing: `@Controller`, `@Get`](#12-routing-controller-get)
  * [1.3. Request Object: `@Req`](#13-request-object-req)
  * [1.4. Response: `@Res`, `@HttpCode`](#14-response-res-httpcode)
  * [1.5. Header: `@Header`](#15-header-header)
  * [1.6. Redirection: `@Redirect`](#16-redirection-redirect)
  * [1.7. Route Parameter (= Path Parameter): `@Param`](#17-route-parameter--path-parameter-param)
  * [1.8. sub-domain Routing: `@HostParam`](#18-sub-domain-routing-hostparam)
  * [1.9. Payload: `@Body`](#19-payload-body)
* [2. 유저 서비스의 Interface](#2-유저-서비스의-interface)
  * [회원 가입](#회원-가입)
  * [이메일 인증](#이메일-인증)
  * [로그인](#로그인)
  * [회원 정보 조회](#회원-정보-조회)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

> 소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch03), [user-service](https://github.com/assu10/nestjs/tree/user-service/ch03) 에 있습니다.

---

# 1. Controller

NestJS 의 Controller 는 MVC 패턴에서 말하는 그 Controller 를 의미한다.  
request 를 받아서 처리된 결과를 response 로 돌려주는 인터페이스 역할을 한다.  
즉, 서버로 들어오는 요청을 처리하고 응답을 가공하며, 서버에서 제공하는 기술들을 어떻게 클라이언트와 주고 받을지에 대한 인터페이스를 정의하고, 데이터의 구조를 기술한다.

먼저 프로젝트를 생성해보자.

```shell
$ nest new ch03
```

> Failed to execute command: npm install --silent 오류 발생 시 [Nestjs - Failed to execute command: npm install --silent](https://assu10.github.io/dev/2023/02/01/trouble-shooting-1/)
> 를 참고하세요.

아래는 컨트롤러를 생성하는 명령어이다.
```shell
$ nest g controller Users
                            
CREATE src/users/users.controller.spec.ts (485 bytes)
CREATE src/users/users.controller.ts (99 bytes)
UPDATE src/app.module.ts (326 bytes)
```

AppModule (app.module.ts) 에서 방금 생성한 users.controller.ts 와 프로젝트 생성 시 만들어진 AppService (app.service.ts) 를 import 해서 사용하고 있다.

> 모듈과 서비스(Provider) 는 각자 찾아보세요.

CRUD 보일러 플레이트를 한번에 만들 땐 `nest g resouece Users` 명령어를 이용하면 module, controller, service, entity, dto, test 코드 등을 한번에 생성해준다.

```shell
nest g resource Users
? What transport layer do you use? REST API
? Would you like to generate CRUD entry points? Yes
CREATE src/users/users.controller.spec.ts (566 bytes)
CREATE src/users/users.controller.ts (894 bytes)
CREATE src/users/users.module.ts (247 bytes)
CREATE src/users/users.service.spec.ts (453 bytes)
CREATE src/users/users.service.ts (609 bytes)
CREATE src/users/dto/create-user.dto.ts (30 bytes)
CREATE src/users/dto/update-user.dto.ts (169 bytes)
CREATE src/users/entities/user.entity.ts (21 bytes)
UPDATE package.json (1968 bytes)
UPDATE src/app.module.ts (312 bytes)
✔ Packages installed successfully.
```

---

## 1.1. NestJS 구성 요소 약어

NestJS 구성 요소에 대한 약어는 `nest -h` 로 확인할 수 있다.

```shell
$ nest -h
Usage: nest <command> [options]

Options:
  -v, --version                                   Output the current version.
  -h, --help                                      Output usage information.

Commands:
  new|n [options] [name]                          Generate Nest application.
  build [options] [app]                           Build Nest application.
  start [options] [app]                           Run Nest application.
  info|i                                          Display Nest project details.
  add [options] <library>                         Adds support for an external library to your
                                                  project.
  generate|g [options] <schematic> [name] [path]  Generate a Nest element.
    Schematics available on @nestjs/schematics collection:
      ┌───────────────┬─────────────┬──────────────────────────────────────────────┐
      │ name          │ alias       │ description                                  │
      │ application   │ application │ Generate a new application workspace         │
      │ class         │ cl          │ Generate a new class                         │
      │ configuration │ config      │ Generate a CLI configuration file            │
      │ controller    │ co          │ Generate a controller declaration            │
      │ decorator     │ d           │ Generate a custom decorator                  │
      │ filter        │ f           │ Generate a filter declaration                │
      │ gateway       │ ga          │ Generate a gateway declaration               │
      │ guard         │ gu          │ Generate a guard declaration                 │
      │ interceptor   │ itc         │ Generate an interceptor declaration          │
      │ interface     │ itf         │ Generate an interface                        │
      │ middleware    │ mi          │ Generate a middleware declaration            │
      │ module        │ mo          │ Generate a module declaration                │
      │ pipe          │ pi          │ Generate a pipe declaration                  │
      │ provider      │ pr          │ Generate a provider declaration              │
      │ resolver      │ r           │ Generate a GraphQL resolver declaration      │
      │ service       │ s           │ Generate a service declaration               │
      │ library       │ lib         │ Generate a new library within a monorepo     │
      │ sub-app       │ app         │ Generate a new application within a monorepo │
      │ resource      │ res         │ Generate a new CRUD resource                 │
      └───────────────┴─────────────┴──────────────────────────────────────────────┘
```

---

## 1.2. Routing: `@Controller`, `@Get`

app.contoller.ts
```ts
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()   // 데커레이터
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()    // 데커레이터
  getHello(): string {
    return this.appService.getHello();
  }
}
```

`@Controller`, `@Get` 데커레이터를 이용하여 서버가 수행할 로직들을 대신함으로써 개발자는 핵심 로직에 집중할 수 있다.

이제 서버를 구동시킨 후 http://localhost:3000 으로 접속하면 Hello World! 가 출력되는 것을 확인할 수 있다.

```shell
$ npm run start:dev
```

라우팅 경로 변경은 `@Get` 데커레이터에 인수로 관리할 수 있다.

```ts
  // http://localhost:3000/hello 로 접속
  @Get('/hello')
  getHello(): string {
    return this.appService.getHello();
  }
```

`@Controller` 데커레이터에도 인수(prefix)를 전달할 수 있다. @Controller('app') 이라고 한다면 http://localhost:3000/app/hello 로 접근하면 된다.
보통 컨트롤러가 맡은 리소스의 이름을 지정한다.

라우팅 패스는 와일드 카드를 사용할 수도 있다.  
@Get('/he*lo') 로 설정하면 hello, helo, he_____o 등으로 접근가능하고, `*` 외 `?`, `+`, `()` 역시 정규 표현식에서의 와일드 카드와 동일하게 동작한다.
단, `-`, `.` 은 문자열로 취급한다.


---

## 1.3. Request Object: `@Req`

NestJS 는 request 와 함께 전달되는 데이터를 핸들러가 다룰 수 있는 객체로 변환하고, 변환된 객체는 `@Req` 데커레이터를 이용하여 다룰 수 있다.

> **핸들러**  
> request 를 처리할 요소로 컨트롤러가 해당 역할을 함

app.contoller.ts
```ts
import { Request } from 'express';
import { Controller, Get, Req } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(@Req() req: Request): string {
    console.log(req);
    return this.appService.getHello();
  }
}
```

> request Object 에 어떤 정보가 담기는 지는 [Express Request](https://expressjs.com/en/api.html#req) 를 참고하세요.

NestJS 는 요청에 포함된 쿼리 매개변수, 패스 매개변수, body 를 각각 `@Query()`, `@Param(key?: string)`, `@Body()` 데커레이터를 이용해서 받을 수 있다.

---

## 1.4. Response: `@Res`, `@HttpCode`

`nest g resource Users` 로 Users 리소스에 대한 CRUD API 를 모두 만들었다면 서버 실행 시 아래와 같이 어떤 라우팅 경로를 통해 요청을 받을 수 있는지 확인 가능하다.

```shell
[Nest] 5080  - 03/05/2023, 2:52:32 PM     LOG [RoutesResolver] UsersController {/users}: +0ms
[Nest] 5080  - 03/05/2023, 2:52:32 PM     LOG [RouterExplorer] Mapped {/users, POST} route +1ms
[Nest] 5080  - 03/05/2023, 2:52:32 PM     LOG [RouterExplorer] Mapped {/users, GET} route +0ms
[Nest] 5080  - 03/05/2023, 2:52:32 PM     LOG [RouterExplorer] Mapped {/users/:id, GET} route +0ms
[Nest] 5080  - 03/05/2023, 2:52:32 PM     LOG [RouterExplorer] Mapped {/users/:id, PATCH} route +1ms
[Nest] 5080  - 03/05/2023, 2:52:32 PM     LOG [RouterExplorer] Mapped {/users/:id, DELETE} route +0ms
```

각 요청의 성공 응답 코드는 POST 의 경우만 201 이고, 나머지는 모두 200 이다.  
NestJS 는 이렇게 응답을 어떤 방식으로 처리할 지 미리 정의해둔다.

string, number, boolean 과 같은 자바스크립트 원시 타입을 리턴할 경우 직렬화없이 바로 보내지만 객체를 리턴한다면 직렬화하여 JSON 객체로 자동 변환해준다.(권장)      
위 방법이 권장하는 방법이지만 라이브러리별로 응답 객체를 직접 다뤄야 한다면 만일 Express 를 사용한다면 `@Res` 데커레이터를 이용하여 Express 응답 객체를 다룰 수 있다.

```ts
@Get()
findAll(@Res() res) {
    const users = this.usersService.findAll();
    return res.status(200).send(users);
}
```

> Express response 에 대해서는 [Express Response](https://expressjs.com/en/api.html#res) 를 참고하세요.

만일 200 이 아닌 다른 상태 코드를 내보내고 싶을 땐 `@HttpCode` 데커레이터를 이용한다.

```ts
import { HttpCode } from '@nestjs/common';

@HttpCode(202)
@Get()
findAll() {
    return this.usersService.findAll();
}
```

예외 처리 시엔 아래와 같이 출력된다.

```ts
  @Get(':id')
  findOne(@Param('id') id: string) {
    if (+id < 1) {
      throw new BadRequestException('id error');
    }
    return this.usersService.findOne(+id);
  }
```

```shell
 curl -X GET http://localhost:3000/users/0 | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    61  100    61    0     0   6459      0 --:--:-- --:--:-- --:--:-- 30500
{
  "statusCode": 400,
  "message": "id error",
  "error": "Bad Request"
}
```

> `jq` 는 [jq Github](https://stedolan.github.io/jq/) 를 참고하세요.

---

## 1.5. Header: `@Header`

NestJS 는 응답 헤더도 자동으로 구성해주는데 만일 커스텀 헤더를 추가해야 한다면 `@Header` 데커레이션을 사용하면 된다.  
라이브러리에서 제공하는 응답 객체를 사용해서 res.header() 로 직접 설정도 가능하다.

```shell
$ curl -X GET http://localhost:3000/users/1 -v | jq
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 127.0.0.1:3000...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* Connected to localhost (127.0.0.1) port 3000 (#0)
> GET /users/1 HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.86.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< X-Powered-By: Express
< Content-Type: text/html; charset=utf-8
< Content-Length: 29
< ETag: W/"1d-MU9PTdoaF+1jeHzvs+kaeFq7QDs"
< Date: Sun, 05 Mar 2023 06:30:57 GMT
< Connection: keep-alive
< Keep-Alive: timeout=5
<
{ [29 bytes data]
100    29  100    29    0     0   4814      0 --:--:-- --:--:-- --:--:-- 29000
* Connection #0 to host localhost left intact
```

> curl 명령어에서 `-v` 옵션 사용 시 헤더까지 확인이 가능하다.


```ts
import { Header } from '@nestjs/common';

  @Header('CustomHeader', 'Test~')
  @Get(':id')
  findOne(@Param('id') id: string) {
    if (+id < 1) {
      throw new BadRequestException('id error');
    }
    return this.usersService.findOne(+id);
  }
```

```shell
 curl -X GET http://localhost:3000/users/1 -v | jq
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 127.0.0.1:3000...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* Connected to localhost (127.0.0.1) port 3000 (#0)
> GET /users/1 HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/7.86.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< X-Powered-By: Express
< CustomHeader: Test~   // 커스텀 헤더 추가
< Content-Type: text/html; charset=utf-8
< Content-Length: 29
< ETag: W/"1d-MU9PTdoaF+1jeHzvs+kaeFq7QDs"
< Date: Sun, 05 Mar 2023 06:33:22 GMT
< Connection: keep-alive
< Keep-Alive: timeout=5
<
{ [29 bytes data]
100    29  100    29    0     0   2217      0 --:--:-- --:--:-- --:--:--  4142
* Connection #0 to host localhost left intact
```

---

## 1.6. Redirection: `@Redirect`

리다이렉션 시 `@Redirect` 데커레이터를 사용할 수 있다. 두 번째 인수는 상태 코드이다.

```ts
import { Redirect } from '@nestjs/common';
  @Redirect('https://www.naver.com', 301)
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(+id);
  }
```

`@Redirect` 사용 시 200 과 같은 다른 상태코드를 써도 되지만 301 Moved Permanently, 307 Temporary Redirect, 308 Permanent Redirect 같이 Redirect 로 정해진 응답 코드가 아닐 경우 정상 동작하지 않을 수 있다.

> 301 Moved Permanently 는 요청한 리소스가 헤더에 주어진 리소스로 완전이 이동되었다는 의미

요청 결과에 따라 동적으로 리다이렉트할 때는 아래와 같은 객체를 리턴하면 된다.

```json
{
  "url": string,
  "statusCode": number
}
```

```ts
  @Get('/redirect/test')
  @Redirect('', 302)
  redirectTest(@Query('ver') version) {
    if (version) {
      return { url: `https://docs.nestjs.com/${version}` };
    }
  }
```

---

## 1.7. Route Parameter (= Path Parameter): `@Param`

Route Parameter 로 전달받은 매개 변수는 함수 인수에 `@Param` 데커레이터로 주입받을 수 있다.  

Route Parameter 를 전달받는 방법은 2가지가 있다.
- **따로 받는 방법**
  - 일반적인 방법임
  - REST API 를 구성할 때 Routing Parameter 의 개수가 적게 설계하는 것이 좋기 때문에 따로 받아도 코드가 많이 길어지지 않음
```ts
  @Delete(':userId/memo/:memoId')
  deleteUserMemo(
    @Param('userId') userId: string,
    @Param('memoId') memoId: string,
  ) {
    return `userId: ${userId}, memoId: ${memoId}`;
  }
```
```shell
$ curl --location --request DELETE 'http://localhost:3000/users/1/memo/2'
userId: 1, memoId: 2%
```

- **객체로 한번에 받는 방법**
  - params 의 타입이 any 로 되어 권장하지 않음  
   Route Parameter 의 타입은 항상 string 이므로 명시적으로 `{ [key: string]: string }` 타입을 지정해도 되긴 함
```ts
  @Delete(':userId/memo/:memoId')
deleteUserMemo(@Param() params: { [key: string]: string }) {
    return `userId: ${params.userId}, memoId: ${params.memoId}`;
}
```

---

## 1.8. sub-domain Routing: `@HostParam`

http://test.com 과 http://api.test.com 으로 들어온 요청을 서로 다르게 처리하고, 하위 도메인에서 처리 못하는 요청을 원래 도메인에서 처리하고 싶을 때 사용한다.

새로운 컨트롤러를 생성한다.
```shell
$ nest g co Api          
CREATE src/api/api.controller.spec.ts (471 bytes)
CREATE src/api/api.controller.ts (95 bytes)
UPDATE src/app.module.ts (381 bytes)
```

app.controller.ts 에 이미 `@Controller()` 를 통해 루트 라우팅을 가진 엔드 포인트가 있으며, ApiController 에서도 같은 엔드 포인트를 사용할 수 있도록
app.module.ts 에서 ApiController 가 먼저 처리되도록 순서를 변경한다.

app.module.ts
```ts
@Module({
  imports: [UsersModule],
  controllers: [ApiController, AppController],
  providers: [AppService],
})
export class AppModule {}
```

`@Controller` 데커레이터는 `prefix` 혹은 `ControllerOptions` 를 인수로 받을 수 있는데 host 속성에 하위 도메인을 적으면 된다.

`ControllerOptions` 시그니처
```ts
export interface ControllerOptions extends ScopeOptions, VersionOptions {
    /**
     * Specifies an optional `route path prefix`.  The prefix is pre-pended to the
     * path specified in any request decorator in the class.
     *
     * Supported only by HTTP-based applications (does not apply to non-HTTP microservices).
     *
     * @see [Routing](https://docs.nestjs.com/controllers#routing)
     */
    path?: string | string[];
    /**
     * Specifies an optional HTTP Request host filter.  When configured, methods
     * within the controller will only be routed if the request host matches the
     * specified value.
     *
     * @see [Routing](https://docs.nestjs.com/controllers#routing)
     */
    host?: string | RegExp | Array<string | RegExp>;
}
```

api.controller.ts
```ts
//@Controller({ host: 'api.test.com' })  로컬 테스트를 위해
@Controller({ host: 'api.localhost' })
export class ApiController {
  @Get() // app.controller.ts 와 같은 루트경로
  getHello(): string {
    return 'hello Api'; // 다른 응답
  }
}
```

이제 GET 요청을 보내면 각각 다르게 응답한다.

```shell
$ curl --location 'http://localhost:3000'
Hello World!%

$ curl --location 'http://api.localhost:3000'
hello Api%

# 하위 도메인에서 처리 못하는 요청을 원래 도메인에서 처리
$ curl --location 'http://api22.localhost:3000'
Hello World!%
```

만일 app.module.ts 에서 AppController, ApiController 의 순서를 변경하지 않으면 하위 도메인으로는 요청이 가지 않는다.

Controller 의 순서를 변경하지 않았을 때
```ts
$ curl --location 'http://localhost:3000'
Hello World!%
    
$ -  ~  curl --location 'http://api.localhost:3000'
Hello World!%
```

`@Param` 데커레이터로 Routing Parameter 를 받은 것처럼 `@HostParam` 데커레이터로 하위 도메인을 변수로 받을 수 있다.  
API 버저닝 시 이렇게 하위 도메인을 이용하는 방법을 많이 사용한다.

api.controller.ts
```ts
@Controller({ host: ':version.api.localhost' })
export class ApiController {
  @Get()
  getHello(@HostParam('version') version: string): string {
    return `hello Api ${version}`;
  }
}
```

```shell
$ curl --location 'http://localhost:3000'
Hello World!%
$ curl --location 'http://api.localhost:3000'
Hello World!%

$ curl --location 'http://v1.api.localhost:3000'
hello Api v1%
```

---

## 1.9. Payload: `@Body`

POST, PUT, PATCH 요청 시 필요 데이터를 함께 보내는데 이 데이터를 payload = body 라 한다.  
NestJS 는 DTO 가 구현되어 있어서 payload 를 쉽게 다룰 수 있다.

앞에서 유저 생성을 위한 POST/users 로 들어오는 body 를 CreateUserDto 로 받았는데 여기에 회원 가입을 위한 이름과 이메일을 추가해본다.

create-user.dto.ts
```ts
export class CreateUserDto {
  name: string;
  email: string;
}
```

users.controller.ts
```ts
  @Post()
  create(@Body() createUserDto: CreateUserDto) {
    const { name, email } = createUserDto;
    return `유저 생성 완료: ${name}, ${email}`;
    //return this.usersService.create(createUserDto);
  }
```

```shell
$ curl --location 'http://localhost:3000/users' \
--header 'Content-Type: application/json' \
--data '{
    "name": "assu",
    "email": "test@test.com"
}'
유저 생성 완료: assu, test@test.com%
```

---

# 2. 유저 서비스의 Interface

최종 디렉터리 구조는 아래와 같다.
```shell
$ tree -L 3 -N -I "node_modules"
.
├── app.module.ts
├── main.ts
└── users
    ├── UserInfo.ts
    ├── dto
    │   ├── create-user.dto.ts
    │   ├── user-login.dto.ts
    │   └── verify-email.dto.ts
    ├── users.controller.spec.ts
    └── users.controller.ts
```

여기서는 유저 서비스의 4가지 인터페이스를 정의하고, 컨트롤러를 구현한다.

| 기능       | end-point                | body(json)                                                       | path parameter | response        |
|:---------|:-------------------------|:-----------------------------------------------------------------|:---------------|:----------------|
| 회원 가입    | POST /users              | { "name": "assu", email": "email@test.com", "password": "abcd" } |                | 201             |
| 이메일 인증   | POST /users/email-verify | { "signupVerifyToken": "fdsafdsa"                                |                | 201 AccessToken |
| 로그인      | POST /users/login        | { "email": "email@test.com", "password": "fdsafd" }              |                | 201 AccessToken |
| 회원 정보 조회 | GET /users/:id           || id                                                               | 200 회원 정보      |


```shell
$ nest new user-service

$ nest g co Users
CREATE src/users/users.controller.spec.ts (485 bytes)
CREATE src/users/users.controller.ts (99 bytes)
UPDATE src/app.module.ts (326 bytes)

$ mkdir src/users/dto 
```

AppController, AppService 는 삭제한다.

## 회원 가입

src/users/dto/create-user.dto.ts
```ts
export class CreateUserDto {
  readonly name: string;
  readonly email: string;
  readonly password: string;
}
```

src/users/users.controller.ts
```ts
import { Body, Controller, Post } from '@nestjs/common';
import { CreateUserDto } from './dto/create-user.dto';

@Controller('users')
export class UsersController {
  //constructor(private readonly usersService: UsersService) {}

  // 회원 가입
  @Post()
  async createUser(@Body() dto: CreateUserDto): Promise<void> {
    console.log('createUser: dto', dto);
  }
}
```

```shell
curl --location 'http://localhost:3000/users' \
--header 'Content-Type: application/json' \
--data '{
    "name": "assu",
    "email": "test.test.com",
    "password": "1234"
}'
```

```shell
createUser: dto { name: 'assu', email: 'test.test.com', password: '1234' }
```

users.controller.ts 전체
```ts
import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { CreateUserDto } from './dto/create-user.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { UserLoginDto } from './dto/user-login.dto';
import { UserInfo } from './UserInfo';

@Controller('users')
export class UsersController {
  // 회원 가입
  @Post()
  async createUser(@Body() dto: CreateUserDto): Promise<void> {
    console.log('createUser dto: ', dto);
  }

  // 이메일 인증
  @Post('/email-verify')
  async verifyEmail(@Query() dto: VerifyEmailDto): Promise<string> {
    console.log('verifyEmail dto: ', dto);
    return;
  }

  // 로그인
  @Post('login')
  async login(@Body() dto: UserLoginDto): Promise<string> {
    console.log('login dto: ', dto);
    return;
  }

  // 회원 정보 조회
  @Get(':id')
  async getUserInfo(@Param('id') userId: string): Promise<UserInfo> {
    console.log('getUserInfo userId: ', userId);
    return;
  }
}
```

---

## 이메일 인증

src/users/dto/verify-email.dto.ts
```ts
export class VerifyEmailDto {
  signupVerifyToken: string;
}
```

```shell
$ curl --location --request POST 'http://localhost:3000/users/email-verify?signupVerifyToken=11111'
```

```shell
verifyEmail dto:  { signupVerifyToken: '11111' }
```

---

## 로그인

/src/users/dto/user-login.dto.ts
```ts
export class UserLoginDto {
  email: string;
  password: string;
}
```

```shell
$ curl --location 'http://localhost:3000/users/login' \
--header 'Content-Type: application/json' \
--data '{
    "email": "test.test.com",
    "password": "1234"
}'
```

```shell
login dto:  { email: 'test.test.com', password: '1234' }
```

---

## 회원 정보 조회

src/users/UserInfo.ts
```ts
export interface UserInfo {
  id: string;
  name: string;
  email: string;
}
```

```shell
$ curl --location 'http://localhost:3000/users/2'
```

```shell
getUserInfo userId:  2
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
* [Express Request](https://expressjs.com/en/api.html#req)
* [Express Response](https://expressjs.com/en/api.html#res)
* [MDN HttpStatus Code](https://developer.mozilla.org/ko/docs/Web/HTTP/Status/202)
* [jq Github](https://stedolan.github.io/jq/)
* [typescript - readonly](https://radlohead.gitbook.io/typescript-deep-dive/type-system/readonly)

* [TypeORM vs Sequelize](https://codebibimppap.tistory.com/16)