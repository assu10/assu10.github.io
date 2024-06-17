---
layout: post
title:  "NestJS - Module 설계"
date:   2023-03-04
categories: dev
tags: nestjs module
---

이 포스트는 NestJS 의 Module 설계에 대해 알아본다.

<!-- TOC -->
* [1. Module 설계: `@Module`](#1-module-설계-module)
  * [1.1. Module 다시 내보내기](#11-module-다시-내보내기)
  * [1.2. 전역 Module: `@Global`](#12-전역-module-global)
* [2. 유저 서비스 Module 분리](#2-유저-서비스-module-분리)
  * [2.1. UsersModule 분리](#21-usersmodule-분리)
  * [2.2. EmailModule 분리](#22-emailmodule-분리)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->


> 소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch05), [user-service](https://github.com/assu10/nestjs/tree/user-service/ch05) 에 있습니다.

---

# 1. Module 설계: `@Module`

Module 이란 여러 컴포넌트를 조합하여 좀 더 큰 작업을 수행할 수 있게 하는 단위이다.  

NestJS 애플리케이션이 실행될 때 하나의 Root Module (일반적으로 AppModule) 이 존재하고, 이 Root Module 은 다른 Module 들로 구성된다.
모듈을 쪼개는 이유는 책임을 나누고 응집도를 높이기 위함이다.

Module 은 `@Module` 데커레이터를 사용한다. `@Module` 데커레이터는 ModuleMetadata 를 인수로 받으며
각 시그니처는 아래와 같다.

```ts
export declare function Module(metadata: ModuleMetadata): ClassDecorator;

export interface ModuleMetadata {
  imports?: Array<Type<any> | DynamicModule | Promise<DynamicModule> | ForwardReference>;
  controllers?: Type<any>[];
  providers?: Provider[];
  exports?: Array<DynamicModule | Promise<DynamicModule> | string | symbol | Provider | ForwardReference | Abstract<any> | Function>;
}
```

- **imports**
  - 이 Module 에서 사용하기 위한 Provider 를 가지고 있는 다른 모듈을 가져옴
  - 예를 들면 A_Module 을 가져와서 함께 빌드되도록 함
- **controllers / providers**
  - Controller 와 Provider 를 사용할 수 있도록 NestJS 가 객체를 생성하고 주입할 수 있도록 해줌
- **exports**
  - 이 Module 에서 제공하는 컴포넌트를 다른 모듈에서 import 해서 사용하려면 export 해야함
  - export 로 선언했다는 건 어디에서나 가져다 쓸 수 있으므로 public Interface 혹은 API 로 간주됨

---

## 1.1. Module 다시 내보내기

가져온 Module 은 다시 내보내기가 가능하다.  

예를 들어 서비스 전반에 사용되는 공통 기능을 모아놓은 모듈을 CommonModule, 공통이긴 하지만 앱을 구동시키는 데 필요한 기능(로깅, 인터셉터 등) 을 
모아놓은 모듈을 CoreModule 이라고 할 때 AppModule 은 애플리케이션 구동 시 CoreModule 이 필요하면서 CommonModule 도 필요하다. 이럴 때 AppModule 은
둘 다 가져오는 것이 아니라 CoreModule 을 가져오고, CoreModule 은 가져온 CommonModule 을 다시 내보내면 AppModule CommonModule 을 가져오지 않아도 사용이 가능하다.

```shell
$  nest g mo Common
CREATE src/common/common.module.ts (83 bytes)
UPDATE src/app.module.ts (579 bytes)

$ nest g s Common 
CREATE src/common/common.service.spec.ts (460 bytes)
CREATE src/common/common.service.ts (90 bytes)
UPDATE src/common/common.module.ts (163 bytes)

$ nest g mo Core  
CREATE src/core/core.module.ts (81 bytes)
UPDATE src/app.module.ts (640 bytes)
```

common.module.ts (CommonModule 에서 CommonService 제공)
```ts
@Module({
  providers: [CommonService],
  exports: [CommonService], // CommonService 제공
})
export class CommonModule {}
```

common.service.ts (CommonService 에서 hello 제공)
```ts
@Injectable()
export class CommonService {
  hello(): string {
    return 'Common Hello~';
  }
}
```

core.module.ts (CommonModule 을 가져온 후 다시 내보냄)
```ts
// CommonModule 을 가져온 후 다시 내보냄
@Module({ imports: [CommonModule], exports: [CommonModule] })
export class CoreModule {}
```

app.module.ts (CoreModule 만 가져옴)
```ts
@Module({
  imports: [CoreModule], // CommonModule 삭제
  controllers: [AppController], // CommmonController 삭제
  providers: [AppService], // CommonService 삭제
})
export class AppModule {}
```

app.controller.ts
```ts
@Controller()
export class AppController {
  constructor(private readonly commonService: CommonService) {}

  @Get('/common-hello')
  getCommonHello(): string {
    return this.commonService.hello();
  }
}
```

```shell
$ npm run start:dev

$ curl --location 'http://localhost:3000/common-hello'
Common Hello~
```

> Module 간 순환 종속성이 발생하기 때문에 Module 은 Provider 처럼 주입해서 사용이 불가하다. 

> Provider 내보내기의 좀 더 상세한 내용은 [NestJS - Custom Provider](https://assu10.github.io/dev/2023/03/25/nest-custom-provider/) 의 *5. Provider 내보내기* 를 참고하세요. 

---

## 1.2. 전역 Module: `@Global`

NestJS 는 Module 범위 내에서 Provider 를 캡슐화하기 때문에 어떤 Module 에 있는 Provider 를 사용하려면 Module 을 먼저 가져와야 한다.  
만일 공통 기능이나 DB 연결과 같이 전역적으로 사용해야 하는 Provider 가 필요한 경우는 이런 Provider 를 모아 전역 모듈로 제공하는 것이 좋다.

전역 모듈은 Root Module 이나 Core Module 에서 한 번만 등록해야 한다.

```ts
@Global()
@Module({
  providers: [CommonService],
  exports: [CommonService],
})
export class CommonModule {}
```

---

# 2. 유저 서비스 Module 분리

지금 현재 유저 서비스의 구조는 아래와 같다.
```shell
$ tree -L 3 -N -I "node_modules"
.
├── app.module.ts
├── email
│   └── email.service.ts
├── main.ts
└── users
    ├── UserInfo.ts
    ├── dto
    │   ├── create-user.dto.ts
    │   ├── user-login.dto.ts
    │   └── verify-email.dto.ts
    ├── users.controller.ts
    └── users.service.ts
```

Root Module 인 AppModule 만 있는데 이를 UserModule 과 Email Module 로 분리해본다.

---

## 2.1. UsersModule 분리

```shell
$ nest g mo Users  
CREATE src/users/users.module.ts (82 bytes)
UPDATE src/app.module.ts (433 bytes)
```

이제 UserController, UserService, EmailService(UserService 에서 사용) 추가한다.

users.module.ts
```ts
@Module({
  imports: [],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
```

UsersModule 생성 시 AppModule 에 UsersModule 이 추가되었고, 이제 AppModule 에서 UsersController, UsersService, EmailService 는 필요없으므로 삭제한다.

app.module.ts
```ts
@Module({
  imports: [UsersModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
```

---

## 2.2. EmailModule 분리

```shell
$ nest g mo Email
CREATE src/email/email.module.ts (82 bytes)
UPDATE src/app.module.ts (428 bytes)
```

이제 EmailModule 에서 EmailService 를 제공하도록 하고, UsersService 가 있는 UsersModule 에서 사용할 수 있도록 내보내기를 한다.

email.module.ts
```ts
@Module({ providers: [EmailService], exports: [EmailService] })
export class EmailModule {}
```

이제 UsersModule 에서 EmailModule 을 import 하여 UsersService 에서 EmailService 를 사용할 수 있도록 한다.

users.module.ts
```ts
@Module({
  imports: [EmailModule],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
```

이제 소스 구조는 아래와 같다.
```ts
$ tree -L 3 -N -I "node_modules"
.
├── app.module.ts
├── email
│   ├── email.module.ts
│   └── email.service.ts
├── main.ts
└── users
    ├── UserInfo.ts
    ├── dto
    │   ├── create-user.dto.ts
    │   ├── user-login.dto.ts
    │   └── verify-email.dto.ts
    ├── users.controller.ts
    ├── users.module.ts
    └── users.service.ts
```

```shell
$ curl --location 'http://localhost:3000/users' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "assu",
    "email": "test@test.com",
    "password": "test"
}'
```

정상적으로 메일이 오는 것을 확인할 수 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [NestJS docs](https://docs.nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)