---
layout: post
title:  "NestJS - 클린 아키텍처"
date:   2023-04-29
categories: dev
tags: nestjs clean-architecture
---

이 포스팅은 클린 아키텍처에 대해 알아본다.

- [클린 아키텍처](#1-클린-아키텍처)
- [SOLID 객체 지향 설계 원칙](#2-solid-객체-지향-설계-원칙)
- [유저 서비스](#3-유저-서비스)
  - [클린 아키텍처 적용](#31-클린-아키텍처-적용)
    - [domain layer](#311-domain-layer)
    - [application layer](#312-application-layer)
    - [interface layer](#313-interface-layer)
    - [infrastructure layer](#314-infrastructure-layer)

> 소스는 [user-service](https://github.com/assu10/nestjs/tree/user-service/ch17) 에 있습니다.

그 동안 진행해 온 user-service 의 디렉터리 구조는 아래와 같다.

```shell
$ tree -L 4 -N -I "node_modules"

.
├── README.md
├── dist
├── nest-cli.json
├── ormconfig.ts
├── package-lock.json
├── package.json
├── src
│   ├── app.module.ts
│   ├── auth
│   │   ├── auth.module.ts
│   │   ├── auth.service.spec.ts
│   │   └── auth.service.ts
│   ├── auth.guard.ts
│   ├── config
│   │   ├── authConfig.ts
│   │   ├── emailConfig.ts
│   │   ├── env
│   │   │   ├── .dev.env
│   │   │   ├── .local.env
│   │   └── validationSchema.ts
│   ├── email
│   │   ├── email.module.ts
│   │   └── email.service.ts
│   ├── exception
│   │   ├── exception.module.ts
│   │   └── http-exception.filter.ts
│   ├── health-check
│   │   ├── dog.health.ts
│   │   ├── health-check.controller.spec.ts
│   │   └── health-check.controller.ts
│   ├── logging
│   │   ├── logging.interceptor.ts
│   │   └── logging.module.ts
│   ├── main.ts
│   ├── migrations
│   │   └── 1680769589673-CreateUserTable.ts
│   ├── users
│   │   ├── UserInfo.ts
│   │   ├── command
│   │   │   ├── create-user.command.ts
│   │   │   ├── create-user.handler.ts
│   │   │   ├── login.command.ts
│   │   │   ├── login.handler.ts
│   │   │   ├── verify-email.command.ts
│   │   │   └── verify-email.handler.ts
│   │   ├── dto
│   │   │   ├── create-user.dto.ts
│   │   │   ├── user-login.dto.ts
│   │   │   └── verify-email.dto.ts
│   │   ├── entity
│   │   │   └── user.entity.ts
│   │   ├── event
│   │   │   ├── cqrs-event.ts
│   │   │   ├── test.event.ts
│   │   │   ├── user-create.event.ts
│   │   │   └── user-event.handler.ts
│   │   ├── query
│   │   │   ├── get-user-info.handler.ts
│   │   │   └── get-user-info.query.ts
│   │   ├── users.controller.ts
│   │   └── users.module.ts
│   └── utils
│       └── decorators
│           └── not-in.ts
├── test
│   ├── app.e2e-spec.ts
│   └── jest-e2e.json
├── tsconfig.build.json
└── tsconfig.json
```

이제 클린 아키텍처에 대해 알아본 후 user-service 의 구조를 개선해보도록 한다.

---

# 1. 클린 아키텍처

클린 아키텍처는 SW 를 여러 동심원의 레이어로 나누고 각 레이어에 있는 컴포넌트가 안쪽 원에 있는 컴포넌트에만 의존성을 갖도록 하는 것이다. (= 안쪽 원에 존재하는 컴포넌트는
바깥 원에 독립적)

![Clean Architecture](/assets/img/dev/2023/0429/clean.png)

여기선 바깥쪽 레이어부터 infrastructure layer, interface layer, application layer, domain layer 로 명명하여 보도록 하겠다.

- infrastructure layer
  - 애플리케이션에 필요하지만 외부에서 가져다 쓰는 컴포넌트
  - DB, email 전송 등 외부에서 제공하는 인터페이스나 라이브러리를 이용하여 우리 서비스에 맞게 구현한 구현체 포함
- interface layer
  - 우리 서비스가 제공하는 인터페이스가 구현되는 레이어
  - 컨트롤러가 외부에서 들어오는 요청 데이터와 나가는 데이터의 형식을 제공하는 것처럼 외부와의 인터페이스를 담당
- application layer
  - 미즈니스 로직이 구현되는 레이어
  - 회원 가입, 회원 정보 조회 등의 로직
- domain layer
  - 애플리케이션의 핵심 도메인을 구현
  - 애플리케이션이 가져야 하는 핵심 요소만 갖기 때문에 다른 레이어에 의존하지 않음


각 레이어는 의존성이 안쪽 원으로 향하는데 구현하다 보면 안쪽에서 바깥쪽 원으로 의존성이 역전되는 경우가 있다.

특히 인프라 레이어는 다른 것으로 바꾸는 경우가 종종 있다. 예를 들어 MySQL 을 사용하다가 Oracle 로 변경하는 일이 발생할 수 있다. 

이렇게 의존성이 역전되는 경우 안쪽 레이어에서는 그 레이어 내에서 인터페이스를 정의하고 그 인터페이스를 구현한 구현체는 바깥 레이어에 둠으로써 의존성이 역전되지 않도록 한다.

---

# 2. SOLID 객체 지향 설계 원칙

클린 아키텍쳐는 SOLID 객체 지향 설계 원칙이 베이스로 깔려 있는데 SOLID 를 적용하면 유지 보수와 확장이 쉬운 시스템을 만들 수 있다.

- `SRP` (Single Responsibility Principle, 단일 책임 원칙)
  - **한 클래스는 하나의 책임만 가져야 한다.**
  - 여기서 클래스는 함수, 객체 등 최소 동작의 단위가 되는 개념임
  - 클래스를 크기가 작고 적은 책임을 갖도록 작성해야 변경에 유연하게 대처 가능함
- `OCP` (Open-Closed Principle, 개방-폐쇄 원칙)
  - **SW 요소는 확장에는 열려있고, 변경에는 닫혀 있어야 한다.**
  - 기능의 추가가 기존 코드에 영향을 미치지 않도록 하는 구조가 필요함
  - OCP 는 인터페이스를 활용하여 쉽게 달성 가능, 필요한 기능이 있으면 그 구현체에 의존하는게 아니라 인터페이스에 의존하도록 하여 추가 기능이 있을 때 인터페이스를 추가
- `LSP` (Liskov Substitution Principle, 리스코프 치환 법칙)
  - **프로그램 객체는 정확성을 깨뜨리지 않으면서 하위 타입의 인스턴스로 바꿀 수 있어야 한다.**
  - 상속 관계에서 자식 클래스의 인스턴스는 부모 클래스로 선언된 함수의 인수로 전달할 수 있음
  - 인스턴스는 인터페이스가 제공하는 기능을 구현한 객체이지만 인터페이스를 사용하는 다른 객체에도 전달 가능하기 때문에 실제 구현체인 자식 인스턴스는 언제든지 부모 또는 인터페이스가 제공하는 기능을 제공하는 다른 구현체로 바꿀 수 있음
- `ISP` (Interface Segregation Principle, 인터페이스 분리 원칙)
  - **특정 클라이언트를 위한 인터페이스 여러 개가 범용 인터페이스 하나보다 낫다.**
  - 하나의 인터페이스에 의존하게 되면 인터페이스에 기능이 추가될 때 인터페이스를 구현하는 모든 클래스를 수정해야 하므로 인터페이스를 기능별로 잘게 쪼개어 특정 클라이언트용 인터페이스로 모아서 사용하는 것이 변경에 대한 
  의존성을 낮추는 방법
- `DIP` (Dependency Inversion Principle, 의존관계 역전 원칙)
  - **프로그래머는 추상화에 의존해야지, 구체화에 의존하면 안된다.**
  - DIP 는 [IoC(제어 반전), DI(의존성 주입)](https://assu10.github.io/dev/2023/03/05/ioc-and-di/) 에서 언급한 DI 와 밀접함
  - 클린 아키텍처를 구현하기 위해서는 의존관계 역전이 발생하기 마련이고, 이를 해소하기 위해 DI 를 이용

---

# 3. 유저 서비스

지금까지는 기능별로 UserModule, ExceptionModule 과 같이 모듈로만 분리했는데 여기서 UserModule 에 클린 아키텍처를 적용해본다.

---

## 3.1. 클린 아키텍처 적용

domain layer, application layer, interface layer, infrastructure layer 와 공통으로 사용하는 컴포넌트를 작성할 common 디렉토리를 생성한다.

```shell
$ tree -L 1
/src/users
├── application
├── common
├── domain
├── infra
├── interface
...
```

### 3.1.1. domain layer

domain layer 에는 도메인 객체와 도메인 객체의 상태 변화에 따라 발생되는 이벤트가 존재하는데 지금 UserModule 이 갖고 있는 도메인 객체는 User 하나밖에 없다.

/src/users/domain/user.ts
```ts
export class User {
  constructor(
    private id: string,
    private name: string,
    private email: string,
    private password: string,
    private signupVerifyToken: string,
  ) {}

  getId(): Readonly<string> {
    return this.id;
  }

  getName(): Readonly<string> {
    return this.name;
  }

  getEmail(): Readonly<string> {
    return this.email;
  }
}
```

User 객체를 생성할 때 유저가 생성되었음을 알리는 UserCreateEvent 를 발송해야 하고, 이 이벤트를 발송하는 주체는 User 의 생성자가 되는 것이 적당하다.
하지만 User 클래스는 new 키워드로 생성해야 해서 EventBus 를 주입받을 수 없으므로 User 를 생성하는 팩터리 클래스인 UserFactory 를 이용하고 이를 프로바이더로 제공한다.

/src/users/domain/user.factory.ts
```ts
import { Injectable } from '@nestjs/common';
import { EventBus } from '@nestjs/cqrs';
import { User } from './user';
import { UserCreateEvent } from '../event/user-create.event';

@Injectable()
export class UserFactory {
  constructor(private eventBus: EventBus) {}

  // 유저 객체 생성
  create(
    id: string,
    name: string,
    email: string,
    signupVerifyToken: string,
    password: string,
  ): User {
    // User 객체 생성 후 UserCreatedEvent 발행함, 이후 생성한 유저 도메인 객체 리턴
    const user = new User(id, name, email, signupVerifyToken, password);
    this.eventBus.publish(new UserCreateEvent(email, signupVerifyToken));
    return user;
  }

  // 이벤트 발행없이 유저 객체만 생성
  reconstitute(
          id: string,
          name: string,
          email: string,
          signupVerifyToken: string,
          password: string,
  ): User {
    return new User(id, name, email, signupVerifyToken, password);
  }
}
```

/src/users/users.module.ts
```ts
...
import { UserFactory } from './domain/user.factory';

...
const factories = [UserFactory];

@Module({
  providers: [
    ...
    ...factories,
  ],
})
export class UsersModule {}
```

그리고 UserCreatedEvent 는 도메인 로직과 밀접하므로 domain 디렉터리로 이동시킨다.

```shell
$ tree -L 2
├── domain
│   ├── cqrs-event.ts
│   ├── user-create.event.ts
│   ├── user.factory.ts
│   └── user.ts
```

---

### 3.1.2. application layer

이제 UserCreatedEvent 를 처리하는 UserEventHandler 를 application/event 로 옮긴 후 리팩터링한다.

/src/users/application/event/user-event.handler.ts
```ts
import { EventsHandler, IEventHandler } from '@nestjs/cqrs';
import { UserCreateEvent } from '../../domain/user-create.event';
import { TestEvent } from '../../event/test.event';
import { EmailService } from '../../../email/email.service';

@EventsHandler(UserCreateEvent)
export class UserEventHandler implements IEventHandler<UserCreateEvent> {
  constructor(private emailService: EmailService) {}

  // 이벤트 핸들러는 커맨드 핸들러와는 다르게 여러 이벤트를 같은 이벤트 핸들러가 받도록 할 수 있음
  async handle(event: UserCreateEvent | TestEvent) {
    switch (event.name) {
      case UserCreateEvent.name: {
        const { email, signupVerifyToken } = event as UserCreateEvent;
        await this.emailService.sendMemberJoinVerification(
          email,
          signupVerifyToken,
        );
        break;
      }
      default:
        break;
    }
  }
}
```

커맨드와 쿼리도 모두 application/command, query 로 이동시킨다.

```shell
$ tree -L 3   

├── application
│   ├── command
│   │   ├── create-user.command.ts
│   │   ├── create-user.handler.ts
│   │   ├── login.command.ts
│   │   ├── login.handler.ts
│   │   ├── verify-email.command.ts
│   │   └── verify-email.handler.ts
│   ├── event
│   │   └── user-event.handler.ts
│   └── query
│       ├── get-user-info.handler.ts
│       └── get-user-info.query.ts

```

---

### 3.1.3. interface layer

UserController 와 관계된 소스 코드가 대상이다.
UserController, UserInfo 및 DTO 관련 클래스들을 모두 interface 디렉터리로 옮긴다.

```shell
$ tree -L 3

├── interface
│   ├── UserInfo.ts
│   ├── dto
│   │   ├── create-user.dto.ts
│   │   ├── user-login.dto.ts
│   │   └── verify-email.dto.ts
│   └── users.controller.ts
```

---

### 3.1.4. infrastructure layer

infra 레이어는 유저 모듈에서 사용하는 외부 컴포넌트가 포함되도록 하면 되므로 데이터베이스와 이메일 관련 로직이 그 대상이다.

엔티티 클래스를 infra/db/entity 디렉터리로 이동시킨다.

UserEntity 클래스는 infra 레이어에 존재하지만 application 레이어에 있는 핸들러에서 사용하고 있다. 
**즉, 의존성 방향이 반대로 되어있으므로 DIP 를 적용하여 의존 관계를 바로 잡는다.** 

먼저 유저 정보를 다루는 인터페이스인 IUserRepository 를 생성하는데 이 인터페이스는 application 레이어 뿐 아니라 어느 레이어에서든 데이터를 다룰 경우가 생길 수 있으므로 domain 레이어에 작성한다.

/src/users/domain/repository/iuser.repository.ts
```ts
import { User } from '../user';

export interface IUserRepository {
  findByEmail: (email: string) => Promise<User>;
  save: (
    name: string,
    email: string,
    password: string,
    signupVerifyToken: string,
  ) => Promise<void>;
}
```

이제 IUserRepository 의 구현체는 UserRepository 클래스는 infra 레이어에서 구현한다.

/src/users/infra/db/repository/UserRepository.ts
```ts
import { IUserRepository } from '../../../domain/repository/iuser.repository';
import { User } from '../../../domain/user';
import { Injectable } from '@nestjs/common';
import { Connection, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { UserEntity } from '../entity/user.entity';
import { UserFactory } from '../../../domain/user.factory';
import { ulid } from 'ulid';

@Injectable()
export class UserRepository implements IUserRepository {
  constructor(
    private connection: Connection,
    //`@InjectRepository` 데커레이터로 유저 저장소 주입
    @InjectRepository(UserEntity)
    private userRepository: Repository<UserEntity>,
    private userFactory: UserFactory,
  ) {}

  // 이메일 주소의 유저를 DB 에서 조회, 만일 없다면 null 리턴, 존재하면 User 도메인 객체 리턴
  async findByEmail(email: string): Promise<User | null> {
    const userEntity = await this.userRepository.findOne({
      where: { email },
    });

    if (!userEntity) {
      return null;
    }

    const { id, name, signupVerifyToken, password } = userEntity;

    return this.userFactory.reconstitute(
      id,
      name,
      email,
      signupVerifyToken,
      password,
    );
  }

  // createUserHandler 의 saveUserUsingTransaction() 내용 이관
  async save(
    id: string,
    name: string,
    email: string,
    password: string,
    signupVerifyToken: string,
  ): Promise<void> {
    await this.connection.transaction(async (manager) => {
      const user = new UserEntity(); // 유저 엔티티 객체 생성
      user.id = id;
      user.name = name;
      user.email = email;
      user.password = password;
      user.signupVerifyToken = signupVerifyToken;

      await manager.save(user);

      // 일부러 에러 발생 시 데이터 저장 안됨
      //throw new InternalServerErrorException();
    });
  }
}
```

이제 다른 레이어에서 IUserRepository 를 이용해 데이터를 다룰 수 있게 되었으니 application 레이어에 있는 createUserHandler 에 적용해본다.

/src/users/application/command/create-user.handler.ts
```ts
import { CommandHandler, ICommandHandler } from '@nestjs/cqrs';
import { CreateUserCommand } from './create-user.command';
import { Inject, UnprocessableEntityException } from '@nestjs/common';
import * as uuid from 'uuid';
import { ulid } from 'ulid';
import { UserFactory } from '../../domain/user.factory';
import { IUserRepository } from 'src/users/domain/repository/iuser.repository';

@CommandHandler(CreateUserCommand)
export class CreateUserHandler implements ICommandHandler<CreateUserCommand> {
  constructor(
    private userFactory: UserFactory,
    // IUserRepository 는 클래스가 아니므로 의존선 클래스로 주입받을 수 없음
    // 따라서 @Inject 데커레이터와 UserRepository 토큰을 이용하여 주입받음
    @Inject('UserRepository') private userRepository: IUserRepository,
  ) {}

  async execute(command: CreateUserCommand) {
    const { name, email, password } = command;

    // 가입 유무 확인
    const user = await this.userRepository.findByEmail(email);
    if (user !== null) {
      throw new UnprocessableEntityException('Email already exists');
    }

    const id = ulid();
    const signupVerifyToken = uuid.v1();

    // 유저 정보 저장
    await this.userRepository.save(
      id,
      name,
      email,
      password,
      signupVerifyToken,
    );

    this.userFactory.create(id, name, email, password, signupVerifyToken);
  }
}
```

/src/users/user.module.ts
```ts
...
import { UserRepository } from './infra/db/repository/UserRepository';

...
const repositories = [
  {
    provide: 'UserRepository',
    useClass: UserRepository,
  },
];

@Module({
  providers: [
    ...
    ...repositories,
  ],
})
export class UsersModule {}
```

이제 이메일 모듈과 유저 모듈이 강하게 결합되어 있는 것도 인터페이스로 느근하게 연결해보도록 한다.

이메일 모듈은 유저 모듈 입장에서는 외부 시스템이므로 infra 레이어에 구현체가 존재해야 하고, 그 구현체를 사용하는 곳은 UserEventHandler 로 application 레이어에 존재한다.
따라서 IEmailService 인터페이스는 application 레이어에 정의한다.

/src/users/application/adapter/iemail.service.ts
```ts
export interface IEmailService {
  sendMemberJoinVerification: (email: string, signupVerifyToken: string) => Promise<void>;
}
```

이제 infra 레이어에 구현체를 작성한다.

/src/users/infra/adapter/email.service.ts
```ts
import { IEmailService } from '../../application/adapter/iemail.service';
import { Injectable } from '@nestjs/common';
import { EmailService as ExternalEmailService } from 'src/email/email.service';

@Injectable()
export class EmailService implements IEmailService {
  constructor(private emailService: ExternalEmailService) {}

  async sendMemberJoinVerification(
    email: string,
    signupVerifyToken: string,
  ): Promise<void> {
    await this.emailService.sendMemberJoinVerification(
      email,
      signupVerifyToken,
    );
  }
}
```

이제 UserEventHandler 에서 IEmailService 를 주입받아 사용한다.

/src/suers/application/event/user-event.handler.ts
```ts
import { EventsHandler, IEventHandler } from '@nestjs/cqrs';
import { UserCreateEvent } from '../../domain/user-create.event';
import { Inject } from '@nestjs/common';
import { IEmailService } from '../adapter/iemail.service';

@EventsHandler(UserCreateEvent)
export class UserEventHandler implements IEventHandler<UserCreateEvent> {
  //constructor(private emailService: EmailService) {}
  constructor(@Inject('EmailService') private emailService: IEmailService) {}

  // 이벤트 핸들러는 커맨드 핸들러와는 다르게 여러 이벤트를 같은 이벤트 핸들러가 받도록 할 수 있음
  async handle(event: UserCreateEvent) {
    switch (event.name) {
      case UserCreateEvent.name: {
        const { email, signupVerifyToken } = event as UserCreateEvent;
        await this.emailService.sendMemberJoinVerification(
          email,
          signupVerifyToken,
        );
        break;
      }
      default:
        break;
    }
  }
}
```

/src/users/users.module.ts
```ts
...
import { UserRepository } from './infra/db/repository/UserRepository';
import { EmailService } from './infra/adapter/email.service';

...
const repositories = [
  {
    provide: 'UserRepository',
    useClass: UserRepository,
  },
  { provide: 'EmailService', useClass: EmailService },
];

@Module({
  ...
  providers: [
    ...repositories,
  ],
})
export class UsersModule {}
```

각 다른 핸들러들도 동일하게 수정한다. 

> 다른 핸들러들은 [user-service](https://github.com/assu10/nestjs/tree/user-service/ch17) 를 참고하세요.

이제 회원 가입 및 조회가 정상적으로 되는지 확인해본다.

```shell
## 가입
$ curl --location 'http://localhost:3000/users' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "assu3",
    "email": "test@naver.com",
    "password": "test1234"
}' | jq


## 로그인
$ curl --location 'http://localhost:3000/users/login' \
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "test@naver.com",
    "password": "test1234"
}'

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAxR1pYQ...

## 유저 정보 조회
$ curl --location --request GET 'http://localhost:3000/users/01GZXC64JYJY26TDASSWQJN8Q5' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6I...' \
--data-raw '{
    "email": "test@naver.com",
    "password": "test1234"
}'
{"id":"01GZXC64JYJY26TDASSWQJN8Q5","name":"assu3","email":"test@naver.com"}%
```

최종 구조는 아래와 같다.

```shell
 tree -L 4 -N -I "node_modules"
.
├── application
│   ├── adapter
│   │   └── iemail.service.ts
│   ├── command
│   │   ├── create-user.command.ts
│   │   ├── create-user.handler.ts
│   │   ├── login.command.ts
│   │   ├── login.handler.ts
│   │   ├── verify-email.command.ts
│   │   └── verify-email.handler.ts
│   ├── event
│   │   └── user-event.handler.ts
│   └── query
│       ├── get-user-info.handler.ts
│       └── get-user-info.query.ts
├── domain
│   ├── cqrs-event.ts
│   ├── repository
│   │   └── iuser.repository.ts
│   ├── user-create.event.ts
│   ├── user.factory.ts
│   └── user.ts
├── event
│   └── test.event.ts
├── infra
│   ├── adapter
│   │   └── email.service.ts
│   └── db
│       ├── entity
│       │   └── user.entity.ts
│       └── repository
│           └── UserRepository.ts
├── interface
│   ├── UserInfo.ts
│   ├── dto
│   │   ├── create-user.dto.ts
│   │   ├── user-login.dto.ts
│   │   └── verify-email.dto.ts
│   └── users.controller.ts
└── users.module.ts
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [The Clean Code Blog](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)