---
layout: post
title:  "NestJS - Metadata(Reflection Class)"
date:   2023-04-23
categories: dev
tags: nestjs metadata reflection-class reflection-metadata
---

이 포스트는 NestJS 에서 빌드 타임에 선언해 둔 메타데이터를 활용하여 런타임에 동작을 제어할 수 있는 Metadata 에 대해 알아본다.

<!-- TOC -->
* [1. Metadata 지정: `@SetMetadata`](#1-metadata-지정-setmetadata)
* [2. Metadata 를 런타임에 조회: Handler 에 적용](#2-metadata-를-런타임에-조회-handler-에-적용)
* [3. Metadata 를 런타임에 조회: Class 에 적용](#3-metadata-를-런타임에-조회-class-에-적용)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

소스는 [example](https://github.com/assu10/nestjs/tree/feature/advanced03) 에 있습니다.

```shell
$ nest new advanced03

$ nest g res users
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
UPDATE package.json (1974 bytes)
UPDATE src/app.module.ts (312 bytes)
✔ Packages installed successfully.
```

---

# 1. Metadata 지정: `@SetMetadata`

Metadata 를 활용한 Custom Decorator 는 빌드 타임에 선언해 둔 메타데이터를 활용하여 런타임에 동작을 제어할 수 있는 강력한 기술로 잘 활용하면 NestJS 에서
제공하지 않는 데커레이터를 직접 구현하여 코드를 더욱 깔끔하게 만들 수 있는 기술이다.

만일 유저 생성 라우트 핸들러는 *admin* 이라는 role 을 가진 유저만 사용할 수 있도록 하고 싶다고 해보자.

Guard 에서 JWT 로 얻은 유저 정보를 이용하여 User DB 에 저장해둔 역할이 현재 유저와 매치하는지 검사하는 로직을 구성하면 되는데 그럴려면 create 는 *admin* 만 사용 
가능하다는 것을 어디선가 알고 있어야 한다.
어디선가 알고 있어야 하는 이 정보를 **메타데이터** 라고 한다.

> **메타데이터**  
> 데이터가 어떤 특성을 지니는지 기술하는 데이터

즉, '`create` 메서드는 *admin* role 일 때만 호출되어야 한다' 는 메타데이터를 `@SetMetadata` 데커레이터로 지정할 수 있다.

SetMetadata 시그니처
```ts
export type CustomDecorator<TKey = string> = MethodDecorator & ClassDecorator & {
    KEY: TKey;
};
/**
 * Decorator that assigns metadata to the class/function using the
 * specified `key`.
 *
 * Requires two parameters:
 * - `key` - a value defining the key under which the metadata is stored
 * - `value` - metadata to be associated with `key`
 *
 * This metadata can be reflected using the `Reflector` class.
 *
 * Example: `@SetMetadata('roles', ['admin'])`
 *
 * @see [Reflection](https://docs.nestjs.com/guards#reflection)
 *
 * @publicApi
 */
export declare const SetMetadata: <K = string, V = any>(metadataKey: K, metadataValue: V) => CustomDecorator<K>;
```

SetMetadata 는 메타데이터를 key 와 value 로 받아와 CustomDecorator 타입으로 돌려주는 데커레이터이다.


/src/users/users.controller.ts
```ts
import {
  ...
  SetMetadata,
} from '@nestjs/common';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @SetMetadata('roles', ['admin'])  // key 가 'roles' 이고 문자열 목록을 값으로 값는 메타데이터 선언, 값은 'admin' 만 선언
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }
  ...
}
```

하지만 이렇게 직접 라우터 핸들러에 적용하지 않고 다시 커스텀 데커레이터를 정의해서 사용하는게 의미를 드러내기 더 좋다.

/src/roles.decorator.ts
```ts
import { SetMetadata } from '@nestjs/common';

export const Roles = (...roles: string[]) => SetMetadata('roles', roles);
```

/src/users/users.controller.ts
```ts
...
import { Roles } from '../roles.decorator';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  //@SetMetadata('roles', ['admin']) // key 가 'roles' 이고 문자열 목록을 값으로 값는 메타데이터 선언, 값은 'admin' 만 선언
  @Roles('admin')
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }
  ...
}
```

이제 유저 생성 라우트 핸들러는 *admin* 이라는 role 을 가진 메타데이터를 가지게 된다.

이제 이 메타데이터를 런타임에 읽어서 처리하도록 해본다.

---

# 2. Metadata 를 런타임에 조회: Handler 에 적용

NestJS 는 메타데이터를 다루기 위한 헬퍼 클래스로 `Reflector` 클래스를 제공하는데 이 Reflector 헬퍼 클래스를 이용하여 메타데이터를 읽을 수 있다.

우선 JWT 검증 및 JWT 로부터 얻은 userId 를 DB 에서 조회하여 role 을 조회하는 HandlerRolesGuard 를 생성한다.

> Guard 에 대한 상세한 내용은 [NestJS - Guard, JWT](https://assu10.github.io/dev/2023/03/19/nest-auth/) 를 참고하세요.

/src/handler-roles.guard.ts
```ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable } from 'rxjs';

@Injectable()
export class HandlerRolesGuard implements CanActivate {
  // 가드에 Reflector 주입
  constructor(private reflector: Reflector) {}

  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest();

    // 편의상 JWT 를 검증해서 얻은 userid 라고 가정 (request.user 객체에서 얻음)
    const userId = 'abcde';

    // 편의상 userId 이용해서 DB 에서 역할을 가져왔다고 가정
    const userRole = this.getUserRole(userId);

    // 가드에 주입받은 Reflector 를 이용하여 메타데이터 리스트 얻음
    // 핸들러에만 적용 가능 (클래스는 적용 불가)
    const roles = this.reflector.get<string[]>('roles', context.getHandler());

    // DB 에서 얻은 값이 메타데이터에 포함되어 있는지 확인
    return roles?.includes(userRole) ?? true;
  }

  private getUserRole(userId: string): string {
    return 'admin;';
  }
}
```

HandlerRolesGuard 는 Reflector 를 주입받아야 하므로 main.ts 에서 전역으로 설정할 수 없고 컨트롤러에 `@UseGuard` 데커레이터로 선언해주거나 커스텀 프로바이더로 제공해주어야 한다.

/src/app.module.ts
```ts
...
import { APP_GUARD } from '@nestjs/core';
import { HandlerRolesGuard } from './handler-roles.guard';

@Module({
  imports: [UsersModule],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: HandlerRolesGuard }],
})
export class AppModule {}
```

이제 유저 생성 메서드를 호출하면 정상적으로 호출되는 것을 확인할 수 있다.
```shell
$ npm run start:dev

$ curl --location --request POST 'http://localhost:3000/users'
This action adds a new user%
```

만일 컨트롤러에 설정한 메타데이터와 가드에서 설정한 role 이 다를 경우 403 forbidden 에러가 발생한다.

```ts
@Post()
//@SetMetadata('roles', ['admin']) // key 가 'roles' 이고 문자열 목록을 값으로 값는 메타데이터 선언, 값은 'admin' 만 선언
@Roles('manage')
create(@Body() createUserDto: CreateUserDto) {
return this.usersService.create(createUserDto);
}
```

```shell
$ curl --location --request POST 'http://localhost:3000/users' | jq

{
  "statusCode": 403,
  "message": "Forbidden resource",
  "error": "Forbidden"
}
```


---

# 3. Metadata 를 런타임에 조회: Class 에 적용

SetMetadata 는 CustomDecorator 를 리턴하고, CustomDecorator 는 메서드 데커레이터뿐 아니라 클래스 데커레이터의 역할도 할 수 있기 때문에 @Roles 커스텀 데커레이터를 클래스에 적용할 수도 있다.

SetMetadata 시그니처
```ts
export type CustomDecorator<TKey = string> = MethodDecorator & ClassDecorator & {
    KEY: TKey;
};
/**
 * Decorator that assigns metadata to the class/function using the
 * specified `key`.
 *
 * Requires two parameters:
 * - `key` - a value defining the key under which the metadata is stored
 * - `value` - metadata to be associated with `key`
 *
 * This metadata can be reflected using the `Reflector` class.
 *
 * Example: `@SetMetadata('roles', ['admin'])`
 *
 * @see [Reflection](https://docs.nestjs.com/guards#reflection)
 *
 * @publicApi
 */
export declare const SetMetadata: <K = string, V = any>(metadataKey: K, metadataValue: V) => CustomDecorator<K>;
```

```ts
@Roles('admin')
@Controller('users')
export class UsersController {
    ...
}
```

이제 클래스에 적용할 ClassRolesGuard 를 구현해보자. 주의할 점은 Reflector 사용 시 context.getHandler() 가 아니라 context.getClass() 를 사용해야 한다는 점이다.

/src/class-roles.guard.ts
```ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable } from 'rxjs';

@Injectable()
export class ClassRolesGuard implements CanActivate {
  // 가드에 Reflector 주입
  constructor(private reflector: Reflector) {}

  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest();

    // 편의상 JWT 를 검증해서 얻은 userid 라고 가정 (request.user 객체에서 얻음)
    const userId = 'abcde';

    // 편의상 userId 이용해서 DB 에서 역할을 가져왔다고 가정
    const userRole = this.getUserRole(userId);

    // 가드에 주입받은 Reflector 를 이용하여 메타데이터 리스트 얻음
    // 클래스에만 적용 가능 (핸들러는 적용 불가)
    const roles = this.reflector.get<string[]>('roles', context.getHandler());

    console.log('----ClassRolesGuard: ', roles);

      // DB 에서 얻은 값이 메타데이터에 포함되어 있는지 확인
      //return roles?.includes(userRole) ?? true;
      
      // HandlerRolesGuard 와 충돌이 발생하므로 일단 무조건 true 리턴으로 구현
      return true;
  }

  private getUserRole(userId: string): string {
    return 'admin';
  }
}
```

이제 HandlerRolesGuard 와 ClassRolesGuard 를 조합하여 role 이 *admin* 인 유저는 특정 핸들러만 실행 가능하도록 하고,
role 이 *user* 인 유저는 클래스에 정의된 모든 핸들러를 실행할 수 있도록 해본다.

/src/roles.guard.ts
```ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Observable } from 'rxjs';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest();

    // 편의상 JWT 를 검증해서 얻은 userid 라고 가정 (request.user 객체에서 얻음)
    const userId = 'abcde';

    // 편의상 userId 이용해서 DB 에서 역할을 가져왔다고 가정
    const userRole = this.getUserRole(userId);

    // 가드에 주입받은 Reflector 를 이용하여 메타데이터 리스트 얻음
    const roles = this.reflector.getAllAndMerge<string[]>('roles', [
      context.getHandler,
      context.getClass(),
    ]);

    console.log('----RolesGuard: ', roles);

    // DB 에서 얻은 값이 메타데이터에 포함되어 있는지 확인
    return roles?.includes(userRole) ?? true;
  }
  private getUserRole(userId: string): string {
    return 'admin';
  }
}
```

/src/app.module.ts
```ts
...
import { APP_GUARD } from '@nestjs/core';
import { RolesGuard } from './roles.guard';

@Module({
  imports: [UsersModule],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
```

/src/users.controller.ts
```ts
...
import { Roles } from '../roles.decorator';

@Roles('user')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @Roles('admin')
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }

  @Get()
  findAll() {
    return this.usersService.findAll();
  }
...
}
```

유저 조회 핸들러 호출 시
```shell
$ curl --location 'http://localhost:3000/users'

----RolesGuard:  [ 'user' ]
```

유저 생성 핸들러 호출 시
```shell
$ curl --location --request POST 'http://localhost:3000/users'

----RolesGuard:  [ 'admin', 'user' ]
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [NestJS - Reflection: 공홈](https://docs.nestjs.com/guards#reflection)
* [NestJS - Guard, JWT: Blog](https://assu10.github.io/dev/2023/03/19/nest-auth/)