---
layout: post
title:  "NestJS - Provider, Scope"
date:   2023-03-03
categories: dev
tags: nestjs provider scope
---

이 포스팅은 NestJS 의 Provider 에 대해 알아본다.

> - [Provider: `@Injectable`](#1-provider--injectable)
>   - [Provider 등록](#11-provider-등록)
>   - [Provider 사용 (속성 기반 주입): `@Inject`](#12-provider-사용--속성-기반-주입---inject)
> - [유저 서비스 회원 가입 로직 구현](#2-유저-서비스-회원-가입-로직-구현)
>   - [Provider 생성](#21-provider-생성)
>   - [회원 가입](#22-회원-가입)
>   - [회원 가입 이메일 발송](#23-회원-가입-이메일-발송)
>   - [이메일 인증](#24-이메일-인증)
>   - [로그인](#25-로그인)
>   - [유저 정보 조회](#26-유저-정보-조회)
> - [Scope](#3-scope)
>   - [Provider 에 Scope 적용](#31-provider-에-scope-적용)
>   - [Controller 에 Scope 적용](#32-controller-에-scope-적용)
> - [Custom Provider](#4-custom-provider)

> 소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch04), [user-service](https://github.com/assu10/nestjs/tree/user-service/ch04)에 있습니다.

---

# 1. Provider: `@Injectable`

Provider 는 애플리케이션의 비즈니스 로직을 수행하는 역할을 한다.  
Provider 는 Service, Repository, Factory, Helper 등 여러 가지 형태로 구현 가능하다.

> 단일 책임 원칙 (SRP, Single Responsibility Principle)  

NestJS 에서 제공하는 Provider 는 의존성 주입이 가능하다.

> **의존성 주입 (DI, Dependency Injection)**    
> DI 를 통해 객체를 생성하고, 관심사 분리 가능, 코드 가독성과 재사용성 높아짐

users.controller.ts
```ts
@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Delete(':id')
    remove(@Param('id') id: string) {
        return this.usersService.remove(+id);
    }
}
```

users.service.ts
```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class UsersService {
  remove(id: number) {
    return `This action removes a #${id} user`;
  }
}
```

비즈니스 로직을 UsersController 가 수행하는 것이 아니라 UsersService 에서 수행한다.  
UserService 는 UserController 의 생성자에서 주입받아 userService 객체 멤버 변수에 할당되어 사용된다.  

UserService 클래스에 `@Injectable` 데커레이터를 선언하여 다른 컴포넌트에서 주입할 수 있는 Provider 가 된다. (즉, UserService 가 Provider)
별도의 scope 를 지정하지 않으면 Singleton Instance 가 생성된다.

---

## 1.1. Provider 등록

Controller 와 마찬가지로 Provider Instance 를 모듈에서 사용 가능하도록 users.module.ts 에 등록해준다.

```ts
@Module({
  controllers: [UsersController],
  providers: [UsersService],
})

```

---

## 1.2. Provider 사용 (속성 기반 주입): `@Inject`

위의 users.controller.ts 를 보면 생성자를 통해 Provider 를 주입받았다.

users.controller.ts
```ts
@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Delete(':id')
    remove(@Param('id') id: string) {
        return this.usersService.remove(+id);
    }
}
```

Provider 를 직접 주입받는 것이 아니라 상속 관계에 있는 자식 클래스를 주입받아 사용하고 싶은 경우(= 레거시 클래스를 확장한 새로운 클래스를 만들고 새로 만든 클래스를 Provider 로 사용하고 싶은 경우) 에 
자식 클래스에서 부모 클래스가 제공하는 함수를 호출하기 위해서 부모 클래스에서 필요한 Provider 를 super() 를 통해 전달해줘야 한다.

base-service.ts
```ts
import { ServiceA } from './service-A';

// 해당 클래스를 직접 참조하지 않으므로 @Injectable 선언하지 않음
export class BaseService {
  constructor(private readonly serviceA: ServiceA) {}

  getHello(): string {
    return 'Hello Base.';
  }

  doFromA(): string {
    return this.serviceA.getHello();
  }
}
```

service-A.ts
```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class ServiceA {
    getHello(): string {
        return 'Hello Service A.';
    }
}
```

service-B.ts
```ts
import { Injectable } from '@nestjs/common';
import { BaseService } from './base-service';

@Injectable()
export class ServiceB extends BaseService {
    getHello(): string {
        return this.doFromA();
    }
}
```

app.controller.ts
```ts
import { Controller, Get } from '@nestjs/common';
import { ServiceB } from './service-B';

@Controller()
export class AppController {
  constructor(private readonly serviceB: ServiceB) {}

  @Get('/serviceB')
  getHelloB(): string {
    return this.serviceB.getHello();
  }
}
```

이제 `npm run start:dev` 로 서버 실행 후 엔드 포인트를 호출해보면 에러가 뜨는 것을 확인할 수 있다.
```shell
$ curl --location 'http://localhost:3000/serviceB'
{"statusCode":500,"message":"Internal server error"}%
```

```shell
ERROR [ExceptionsHandler] Cannot read properties of undefined (reading 'getHello')
TypeError: Cannot read properties of undefined (reading 'getHello')
    at ServiceB.doFromA (/src/base-service.ts:12:26)
```

AppController 에서는 ServiceB 를 주입받았고, ServiceB 의 getHello() 호출 시 ServiceB 의 getHello() 는 BaseService 의 doFromA() 를 호출한다.
하지만 BaseService 는 주입가능한 클래스가 아니기 때문에(= `@Injectable` 데커레이터가 선언되어 있지 않음) IoC 컨테이너는 BaseService 생성자에 선언된 ServiceA 를 주입하지 않아 오류가 발생한다.

이 때는 ServiceB 에서 super 를 통해 ServiceA 의 인스턴스를 전달해주어야 한다.

service-B.ts
```ts
import { Injectable } from '@nestjs/common';
import { BaseService } from './base-service';
import { ServiceA } from './service-A';

@Injectable()
export class ServiceB extends BaseService {
  // 상속 관계에서 생성자 기반 주입을 받을 때에는 하위 클래스가 super 를 통해 상위 클래스에 필요한 프로바이더를 전달해주어야 함
  constructor(private readonly _serviceA: ServiceA) {
    super(_serviceA);
  }
  getHello(): string {
    return this.doFromA();
  }
}
```

이제 오류없이 동작하는 것을 확인할 수 있다.
```shell
$ curl --location 'http://localhost:3000/serviceB'
Hello Service A.%
```

매번 이렇게 자식 클래스에서 super 를 통해 전달하는 대신 부모 클래스에 `@Inject` 데커레이터를 통해 속성 기반 프로바이더를 사용하면 된다.

service-B.ts
```ts
import { Injectable } from '@nestjs/common';
import { BaseService } from './base-service';

@Injectable()
export class ServiceB extends BaseService {
  // 상속 관계에서 생성자 기반 주입을 받을 때에는 하위 클래스가 super 를 통해 상위 클래스에 필요한 프로바이더를 전달해주어야 함
  // constructor(private readonly _serviceA: ServiceA) {
  //   super(_serviceA);
  // }

  getHello(): string {
    return this.doFromA();
  }
}
```

base-service.ts
```ts
// 해당 클래스를 직접 참조하지 않으므로 @Injectable 선언하지 않음
export class BaseService {
  // 상속 관계에서 생성자 기반 주입을 받을 때
  //constructor(private readonly serviceA: ServiceA) {}

  // 상속 관계에서 속성 기반 주입을 받을 때
  @Inject(ServiceA)
  private readonly serviceA: ServiceA;

  ...
    
  doFromA(): string {
    return this.serviceA.getHello();
  }
}
```

`@Inject` 데커레이터의 인수는 타입(클래스명), 문자열, 심벌이 올 수 있는데 Provider 가 어떻게 정의되느냐에 따라 다르다.  
`@Injectable` 이 선언된 클래스는 클래스명을 사용하면 된다.  

> 문자열과 심벌을 추후 다룰 예정입니다.

> 상속 관계에 있지 않은 경우는 속성 기반 주입이 아닌 생성자 기반 주입을 권장함

---

# 2. 유저 서비스 회원 가입 로직 구현

- 회원 가입
- 이메일 인증
- 로그인
- 회원 정보 조회

---

## 2.1. Provider 생성

UsersService Provider 를 생성한다.
```shell
$ nest g s Users       
CREATE src/users/users.service.spec.ts (453 bytes)
CREATE src/users/users.service.ts (89 bytes)
UPDATE src/app.module.ts (302 bytes)
```

테스트 작성법은 아직 활용하지 않을 예정이므로 .spec.ts 는 삭제한다.

최종 디렉터리 구조는 아래와 같다.
```shell
$ pwd
/src

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

---

## 2.2. 회원 가입

uuid library 설치
```shell
$ npm i uuid
$ npm i -D @types/uuid
```

UsersService, UsersController 의 회원 가입 로직을 수정한다.

users.service.ts
```ts
import { Injectable } from '@nestjs/common';
import * as uuid from 'uuid';

@Injectable()
export class UsersService {
  // 회원 가입
  async createUser(name: string, email: string, password: string) {
    // 가입 유무 확인
    await this.checkUserExists(email);

    const signupVerifyToken = uuid.v1();
    console.log('signupVerifyToken: ', signupVerifyToken);

    // 유저 정보 저장
    await this.saveUser(name, email, password, signupVerifyToken);

    // 회원 가입 이메일 발송
    await this.sendMemberJoinEmail(email, signupVerifyToken);
  }

  // 가입 유무 확인
  private async checkUserExists(email: string) {
    return false; // TODO: DB 연동 후 구현
  }

  // 유저 정보 저장
  private saveUser(
    name: string,
    email: string,
    password: string,
    signupVerifyToken: string,
  ) {
    return; // TODO: DB 연동 후 구현
  }

  // 회원 가입 이메일 발송
  private async sendMemberJoinEmail(email: string, signupVerifyToken: string) {
    return; // TODO: 이메일 발송 프로바이더 구현 후 적용
  }
}
```

users.controller.ts
```ts
@Controller('users')
export class UsersController {
    // UsersService 를 컨트롤러에 주입
    constructor(private readonly usersService: UsersService) { }

    // 회원 가입
    @Post()
    async createUser(@Body() dto: CreateUserDto): Promise<void> {
        const {name, email, password} = dto;
        console.log('createUser dto: ', dto);
        await this.usersService.createUser(name, email, password);
    }
}
```


---

## 2.3. 회원 가입 이메일 발송

이메일 전송 library 설치 (무료 서비스, 테스트용으로만 사용하고 상용 서비스에는 적용하지 말 것)
```shell
$ npm i nodemailer
$ npm i -D @types/nodemailer
```

이메일 처리 프로바이더를 생성 후 .spec.ts 파일은 삭제한다.
```shell
$ nest g s Email            
CREATE src/email/email.service.spec.ts (453 bytes)
CREATE src/email/email.service.ts (89 bytes)
UPDATE src/app.module.ts (370 bytes)
```

/src/email/email.service.ts
```ts
import { Injectable } from '@nestjs/common';
import Mail from 'nodemailer/lib/mailer';
import * as nodemailer from 'nodemailer';

interface EmailOptions {
  to: string;
  subject: string;
  html: string;
}
@Injectable()
export class EmailService {
  private transporter: Mail;

  constructor() {
    this.transporter = nodemailer.createTransport({
      service: 'Gmail',
      auth: {
        user: 'YOUR_EMAIL',
        pass: 'YOUR_PASSWORD',
      },
    });
  }

  // 가입 인증 메일 발송
  async sendMemberJoinVerification(email: string, signupVerifyToken: string) {
    const baseUrl = 'http://localhost:3000';
    const url = `${baseUrl}/users/email-verify?signupVerifyToken=${signupVerifyToken}`;
    const mailOptions: EmailOptions = {
      to: email,
      subject: '가입 인증 메일',
      html: `가입확인 버튼를 누르시면 가입 인증이 완료됩니다.<br />
        <form action="${url}" method="POST">
          <button>가입확인</button>
        </form>`,
    };

    return await this.transporter.sendMail(mailOptions);
  }
}
```

users.service.ts
```ts
import { EmailService } from '../email/email.service';

@Injectable()
export class UsersService {
    constructor(private emailService: EmailService) { }
    
    ...
    
    // 회원 가입 이메일 발송
    private async sendMemberJoinEmail(email: string, signupVerifyToken: string) {
        await this.emailService.sendMemberJoinVerification(
            email,
            signupVerifyToken,
        );
    }
}
```

nodemailer 는 간단한 이메일 전송 테스트만을 위한 라이브러리이므로 Gmail 에서 보안이 낮은 앱으로 판단한다.
[Google 앱 비밀번호로 로그인 설정](https://support.google.com/accounts/answer/185833?hl=ko) 를 참고하여 앱 비밀번호 설정 후 테스트해보아야 한다.

위에서 나온 앱 비밀번호를 EmailOptions 의 pass 에 기재한다.


이제 회원 가입 요청 시 가입 인증 메일이 도착하는 것을 확인할 수 있다.

```shell
$ curl --location 'http://localhost:3000/users' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "assu",
    "email": "test@test.com",
    "password": "test"
}'
```

```shell
createUser dto:  { name: 'assu', email: 'jh.lee@weversecompany.com', password: 'test' }
signupVerifyToken:  b2d8f740-c163-11ed-9057-497683782c6d
```

---

## 2.4. 이메일 인증

메일의 가입 확인 버튼 클릭 시 진행되는 이메일 인증을 구현한다.

users.service.ts
```ts
  // 이메일 인증
  async verifyEmail(signupVerifyToken: string): Promise<string> {
    // TODO: DB 에 signupVerifyToken 으로 회원 가입 처리중인 유저가 있는지 조회 후 없다면 에러 처리
    // TODO: 바로 로그인 상태가 되도록 JWT 발급

    throw new Error('아직 미구현된 로직');
  }
```

users.controller.ts
```ts
  // 이메일 인증
  @Post('/email-verify')
  async verifyEmail(@Query() dto: VerifyEmailDto): Promise<string> {
    const { signupVerifyToken } = dto;
    console.log('verifyEmail dto: ', dto);
    return await this.usersService.verifyEmail(signupVerifyToken);
  }
```

---

## 2.5. 로그인

users.service.ts
```ts
  // 로그인
  async login(email: string, password: string): Promise<string> {
    // TODO: DB 에 email, password 가진 유저 존재 여부 조회 후 없다면 에러 처리
    // TODO: JWT 발급

    throw new Error('아직 미구현된 로직');
  }
```

users.controller.ts
```ts
  // 로그인
  @Post('login')
  async login(@Body() dto: UserLoginDto): Promise<string> {
    const { email, password } = dto;
    console.log('login dto: ', dto);
    return await this.usersService.login(email, password);
  }
```

---

## 2.6. 유저 정보 조회

users.service.ts
```ts
  // 유저 정보 조회
  async getUserInfo(userId: string): Promise<UserInfo> {
    // TODO: DB 에 userId 가진 유저 존재 여부 조회 후 없다면 에러 처리
    // TODO: 조회 데이터를 userInfo 타입으로 리턴

    throw new Error('아직 미구현된 로직');
  }
```

users.controller.ts
```ts
  // 유저 정보 조회
  @Get(':id')
  async getUserInfo(@Param('id') userId: string): Promise<UserInfo> {
    console.log('getUserInfo userId: ', userId);
    return await this.usersService.getUserInfo(userId);
  }
```

---

# 3. Scope

Node.js 는 멀티 스레드 상태 비저장(stateless) 모델을 따르지 않기 때문에 Singleton Instance 를 사용하는 것이 안전하다. 이것은 요청으로 들어오는 모든 정보(DB 커넥션 풀, 전역 싱글턴 서비스 등) 들을
공유할 수 있다는 것을 의미한다.

하지만 요청별 캐싱이 필요하거나, 요청을 추적하거나, 멀티테넌시<sup id='multitenancy'>[참고](#_multitenancy)</sup>를 지원하기 위해서는 요청 기반으로 생명 주기를 제한해야 한다.

> <span id='_multitenancy'>**멀티테넌시**  
> 하나의 애플리케이션 인스턴스가 여러 사용자에게 각각 다르게 동작하도록 하는 아키텍처  
> 반대로 각 사용자마다 인스턴스가 만들어지는 것은 멀티 인스턴스 방식</span> [↩](#multitenancy)

Scope 종류는 아래와 같다.

- **DEFAULT (권장)**
  - Singleton Instance 가 전체 애플리케이션에 공유됨
  - Instance 수명은 애플리케이션 생명 주기와 동일
  - 애플리케이션의 부트스트랩 과정이 끝나면 모든 Singleton 프로바이더의 Instance 가 생성됨
  - Instance 를 캐시할 수 있고, 초기화가 애플리케이션 시작 시 한 번만 발생하므로 메모리와 동작 성능을 향상시킬 수 있기 때문에 해당 옵션을 권장함
- **REQUEST**
  - 들어오는 요청마다 별도의 Instance 생성
  - 요청이 끝나면 Instance 는 GarbageCollected 됨
- **TRANSIENT**
  - TRANSIENT Scope 를 지정한 Instance 는 공유되지 않음
  - 이 Provider 를 주입하는 컴포넌트는 새로 생성된 전용 Instance 를 주입받음

Scope 는 Controller 와 Provider 에 선언이 가능한데 만일 연관된 컴포넌트들이 서로 다른 Scope 를 가진다면 종속성을 가진 컴포넌트들의 Scope 를 따라가게 된다.  
예를 들어 TestController → TestService → TestRepository 의 종속성이 있을 때 TestService 만 REQUEST Scope 이고 나머지는 모두 DEFAULT 라면
TestController 는 TestService 에 의존적이므로 Scope 가 REQUEST 로 변경된다. 하지만 TestRepository 의 경우 TestService 에 의존적이지 않으므로 그대로 DEFAULT 를 유지한다.


## 3.1. Provider 에 Scope 적용

`@Injectable` 데커레이터에 scope 속성을 준다.

```ts
import { Injectable, Scope } from '@nestjs/common';

@Injectable({ scope: Scope.REQUEST })
```

Custom Provider 도 마찬가지이다.

```json
{
  "provide": 'TEST',
  "useClass": Test,
  "scope": Scope.REQUEST
}
```

---

## 3.2. Controller 에 Scope 적용

`@Controller` 데커레이터는 ControllerOptions 를 인수로 받는데 ControllerOptions 는 ScopeOptions 를 상속받는다.

```ts
@Controller({
  path: 'test',
  scope: Scope.REQUEST,
})
export class UsersController { }
```

---

# 4. Custom Provider

> 추후 다룰 예정입니다..

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [npm - nodemailer](https://www.npmjs.com/package/nodemailer)
* [Google 앱 비밀번호로 로그인 설정](https://support.google.com/accounts/answer/185833?hl=ko)