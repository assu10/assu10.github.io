---
layout: post
title:  "NestJS - Logging"
date:   2023-03-26
categories: dev
tags: nestjs logging nest-winston
---

이 포스팅은 NestJS 에서 내장 Logger, Custom Logger, 외부 Logger 를 사용하는 방법에 대해 알아본다.

- [내장 Logger](#1-내장-logger)
  - [로깅 비활성화](#11-로깅-비활성화)
  - [로그 레벨 지정](#12-로그-레벨-지정)
- [Custom Logger](#2-custom-logger)
  - [Custom Logger 주입하여 사용](#21-custom-logger-주입하여-사용)
  - [Custom Logger 전역으로 사용](#22-custom-logger-전역으로-사용)
  - [외부 Logger 사용](#23-외부-logger-사용)
- [유저 서비스](#3-유저-서비스)
  - [`nest-winston` 적용](#31-nest-winston-적용)
  - [내장 Logger 대체](#32-내장-logger-대체)
  - [BootStrapping 까지 포함하여 내장 Logger 대체](#33-bootstrapping-까지-포함하여-내장-logger-대체)
  - [외부 서비스에 로그 전송](#34-외부-서비스에-로그-전송)


소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch11), [user-service](https://github.com/assu10/nestjs/tree/user-service/ch11)에 있습니다.

---

> 외부 Logger 인 `winston` 을 주로 사용하므로 내장 Logger, Custom Logger 는 내용만 참고 차 알아두세요. 

# 1. 내장 Logger

내장 Logger 클래스는 @nest/common 패키지에 제공된다.

---

## 1.1. 로깅 비활성화

```shell
$ nest new ch11
```

내장 로거는 로그를 남기려는 곳에서 인스턴스를 직접 생성하여 사용할 수 있다.
```ts
import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class AppService {
  // 로거 인스턴스 생성 시 클래스명을 컨텍스트로 설정하여 로그 메시지 앞에 클래스명이 함께 출력되도록 함. 
  private readonly logger = new Logger(AppService.name);
  getHello(): string {
    this.logger.error('this is error');
    this.logger.warn('this is warn');
    this.logger.log('this is log');
    this.logger.verbose('this is verbose');
    this.logger.debug('this is debug');

    return 'Hello World!';
  }
}
```

```shell
$ curl --location 'http://localhost:3000'
Hello World!%

[Nest] 72540  - 04/17/2023, 9:19:30 AM   ERROR [AppService] this is error
[Nest] 72540  - 04/17/2023, 9:19:30 AM    WARN [AppService] this is warn
[Nest] 72540  - 04/17/2023, 9:19:30 AM     LOG [AppService] this is log
[Nest] 72540  - 04/17/2023, 9:19:30 AM VERBOSE [AppService] this is verbose
[Nest] 72540  - 04/17/2023, 9:19:30 AM   DEBUG [AppService] this is debug
```

NestFactory.create 메서드의 인수인 NestApplicationOptions 에 logger 를 비활성화할 수 있는 옵션이 있다.
해당 옵션을 false 로 설정 시 로그가 출력되지 않는다.

/main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  //const app = await NestFactory.create(AppModule);
  // 로그 비활성화
  const app = await NestFactory.create(AppModule, {
    logger: false,
  });
  await app.listen(3000);
}
bootstrap();
```

---

## 1.2. 로그 레벨 지정

PROD 환경에서까지 모든 로그를 남기면 사용자의 민감 정보가 포함될 수도 있고, 로그 파일 사이즈의 크기가 커지기 때문에 실행 환경에 따라 로그 레벨을 지정해야 한다.

/main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  //const app = await NestFactory.create(AppModule);

  // 로그 비활성화
  // const app = await NestFactory.create(AppModule, {
  //   logger: false,
  // });

  // 로그 레벨 지정 (PROD 환경은 log 레벨 이상, 그 외 환경은 debug 레벨 이상 로그 출력
  const app = await NestFactory.create(AppModule, {
    logger:
      process.env.NODE_ENV === 'prod' ? ['error', 'warn', 'log'] : ['debug'],
  });
  await app.listen(3000);
}
bootstrap();
```

[NestJS Log Level](https://github.com/nestjs/nest/blob/master/packages/common/services/utils/is-log-level-enabled.util.ts#L3)
```ts
const LOG_LEVEL_VALUES = {
  debug: 0,
  verbose: 1,
  log: 2,
  warn: 3,
  error: 4,
};
```

---

# 2. Custom Logger

내장 Logger 는 파일이나 DB 로 저장하는 기능을 제공하지 않기 때문에 이를 위해선 Custom Logger 를 사용해야 한다.  
Custom Logger 는 @nestjs/common 패키지의 LoggerService 인터페이스를 구현해야 한다.

LoggerService 시그니처
```ts
export interface LoggerService {
    log(message: any, ...optionalParams: any[]): any;
    error(message: any, ...optionalParams: any[]): any;
    warn(message: any, ...optionalParams: any[]): any;
    debug?(message: any, ...optionalParams: any[]): any;
    verbose?(message: any, ...optionalParams: any[]): any;
    setLogLevels?(levels: LogLevel[]): any;
}
```

/src/logging/mylogger.service.ts
```ts
import { LoggerService } from '@nestjs/common';

export class MyloggerService implements LoggerService {
  debug(message: any, ...optionalParams: any[]): any {
    console.log(message);
  }

  error(message: any, ...optionalParams: any[]): any {
    console.log(message);
  }

  log(message: any, ...optionalParams: any[]): any {
    console.log(message);
  }

  verbose(message: any, ...optionalParams: any[]): any {
    console.log(message);
  }

  warn(message: any, ...optionalParams: any[]): any {
    console.log(message);
  }
}
```

```ts
import { Injectable, Logger } from '@nestjs/common';
import { MyloggerService } from './logging/mylogger.service';

@Injectable()
export class AppService {
  private readonly logger = new Logger(AppService.name);
  private readonly mylogger = new MyloggerService();
  getHello(): string {
    console.log(process.env.NODE_ENV);
    this.logger.error('this is error');
    this.logger.warn('this is warn');
    this.logger.log('this is log');
    this.logger.verbose('this is verbose');
    this.logger.debug('this is debug');

    this.mylogger.error('test');

    return 'Hello World!';
  }
}
```

```shell
[Nest] 80549  - 04/17/2023, 11:30:13 AM   ERROR [AppService] this is error
[Nest] 80549  - 04/17/2023, 11:30:13 AM    WARN [AppService] this is warn
[Nest] 80549  - 04/17/2023, 11:30:13 AM     LOG [AppService] this is log
test
```

Custom Logger 로 로그 출력 시에도 내장 Logger 처럼 프로세스 ID, 로깅 시간, 로그 레벨, 컨텍스트명 등이 출력되게 하려면 Custom Logger 가 `ConsoleLogger` 를 상속받은 후
원하는 메서드만 override 해주면 된다.

/src/logging/mylogger.service.ts
```ts
import { ConsoleLogger } from '@nestjs/common';

export class MyloggerService extends ConsoleLogger {
  error(message: any, ...optionalParams: [...any, string?]) {
    super.error(`${message}...`, ...optionalParams);
    this.doSomething();
  }

  private doSomething() {
    // 여기에 로깅에 관련된 부가 로직을 추가
    // ex. DB에 저장
  }
}
```

```ts
import { Injectable, Logger } from '@nestjs/common';
import { MyloggerService } from './logging/mylogger.service';

@Injectable()
export class AppService {
  // 로거 인스턴스 생성 시 클래스명을 컨텍스트로 설정하여 로그 메시지 앞에 클래스명이 함께 출력되도록 함.
  private readonly logger = new Logger(AppService.name);
  private readonly mylogger = new MyloggerService();
  getHello(): string {
    console.log(process.env.NODE_ENV);
    this.logger.error('this is error');
    this.logger.warn('this is warn');
    this.logger.log('this is log');
    this.logger.verbose('this is verbose');
    this.logger.debug('this is debug');

    this.mylogger.error('test');

    return 'Hello World!';
  }
}
```

```shell
[Nest] 81840  - 04/17/2023, 11:42:54 AM   ERROR [AppService] this is error
[Nest] 81840  - 04/17/2023, 11:42:54 AM    WARN [AppService] this is warn
[Nest] 81840  - 04/17/2023, 11:42:54 AM     LOG [AppService] this is log
[Nest] 81840  - 04/17/2023, 11:42:54 AM   ERROR test...
```

---

## 2.1. Custom Logger 주입하여 사용

위에선 Logger 를 사용하는 곳에서 매번 new 로 생성 후 사용했는데 그보다 Logger 를 모듈로 만든 후 생성자에서 주입받아 사용하는 것이 더 편하다.

LoggerModule 을 만든 후 AppModule 에서 가져온다. 

/src/logging/logger.module.ts
```ts
import { Module } from '@nestjs/common';
import { MyloggerService } from './mylogger.service';

@Module({
  providers: [MyloggerService],
  exports: [MyloggerService],
})
export class LoggerModule {}
```

/app.module.ts
```ts
import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { LoggerModule } from './logging/logger.module';

@Module({
  imports: [LoggerModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
```

이제 MyLogger Provider 를 생성자에서 주입받아 사용한다.

```ts
import { Injectable } from '@nestjs/common';
import { MyloggerService } from './logging/mylogger.service';

@Injectable()
export class AppService {
  constructor(private myLogger: MyloggerService) {}
  getHello(): string {
    console.log(process.env.NODE_ENV);
    this.myLogger.error('test');
    this.myLogger.debug('test');

    return 'Hello World!';
  }
}
```

```shell
[Nest] 82508  - 04/17/2023, 11:50:48 AM   ERROR test...
[Nest] 82508  - 04/17/2023, 11:50:48 AM   DEBUG test
```

---

## 2.2. Custom Logger 전역으로 사용

Custom Logger 를 main.ts 에 지정해주면 전역으로 사용이 가능한데 이렇게 하면 서비스 Bootstrapping 과정에서도 Custom Logger 가 사용된다.

/main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { MyloggerService } from './logging/mylogger.service';

async function bootstrap() {
  // 커스텀 로거 전역으로 사용
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true, // 이 설정이 없으면 NestJS 앱이 구동되는 초반에 잠시동안 내장 로거가 사용됨
  });
  app.useLogger(app.get(MyloggerService));
  await app.listen(3000);
}
bootstrap();
```

---

## 2.3. 외부 Logger 사용

위처럼 직접 Custom Logger 를 만들기보다는 이미 잘 만들어진 외부 로깅 라이브러리를 이용하는 것이 좋다.  
뒤에서 [`winston`](https://www.npmjs.com/package/winston) 을 Nest 모듈로 만들어놓은 [`nest-winston`](https://www.npmjs.com/package/nest-winston) 패키지를 이용하여 로깅 기능을 구현해 볼 예정이다.

---

# 3. 유저 서비스

서비스를 운영하다보면 로그를 콘솔에만 출력하는 것이 아니라 파일이나 DB 에 저장하기도 하고, 로그 필터와 추적을 쉽게 해주는 외부 서비스로 로그를 전송하기도 한다.
이 때 `nest-winston` 패키지를 이용하면 쉽게 구현이 가능하다.

[winston 공식 문서](https://github.com/winstonjs/winston) 에 보면 winston 은 다중 전송을 지원한다고 되어있다.

> Each winston logger can have multiple transports (see: Transports) configured at different levels (see: Logging levels).  
> For example, one may want error logs to be stored in a persistent remote location (like a database), 
> but all logs output to the console or a local file.

로깅 프로세스 과정들을 분리시켜 좀 더 유연한 로깅 시스템 구성이 가능하다.

`nest-winston` 은 총 세 가지 방식으로 적용이 가능한데 필요한 곳만 `nest-winston` 을 적용하는 방법, 내장 Logger 를 대체하는 방법 그리고 BootStrapping 까지 포함하여
내장 Logger 를 대체하는 방법 이렇게 총 세 가지 방식이 있다.

이제 순서대로 그 방식을 살펴보자.

---

## 3.1. `nest-winston` 적용

```shell
$  npm i nest-winston winston  
```

app.module.ts
```ts
...
import * as winston from 'winston';
import { utilities, WinstonModule } from 'nest-winston';

@Module({
  imports: [
...
    WinstonModule.forRoot({
      transports: [
        new winston.transports.Console({
          level: process.env.NODE_ENV === 'production' ? 'info' : 'silly',
          format: winston.format.combine(
            winston.format.timestamp(), // 로그 남긴 시각 표시
            utilities.format.nestLike('MyApp', {  // 로그 출처인 appName('MyApp') 설정
              prettyPrint: true,
            }),
          ),
        }),
      ],
    }),
  ],
...
})
export class AppModule {}
```

winston 의 로그 레벨을 총 7 단계이다.

```ts
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  verbose: 4,
  debug: 5,
  silly: 6
};
```

이제 `WINSTON_MODULE_PROVIDER` 토큰으로 winston 에서 제공하는 Logger 객체를 주입받아 로그를 남겨본다.

/src/users/users.controller.ts
```ts
...
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import { Logger as WinstonLogger } from 'winston';

@Controller('users')
export class UsersController {
  // UsersService 를 컨트롤러에 주입
  constructor(
          ...
          @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: WinstonLogger,
  ) {
  }

  // 회원 가입
  @Post()
  async createUser(@Body() dto: CreateUserDto): Promise<void> {
    const {name, email, password} = dto;
    console.log('createUser dto: ', dto);
    this.printWinstonLog(dto);
    await this.usersService.createUser(name, email, password);
  }

  private printWinstonLog(dto) {
    // console.log(this.logger.name);

    this.logger.error('error: ', dto);
    this.logger.warn('warn: ', dto);
    this.logger.info('info: ', dto);
    this.logger.http('http: ', dto);
    this.logger.verbose('verbose: ', dto);
    this.logger.debug('debug: ', dto);
    this.logger.silly('silly: ', dto);
  }
}
```

```shell
$ curl --location 'http://localhost:3000/users/' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "assu1",
    "email": "test1@test.com",
    "password": "12341234"
}'
```

```shell
[MyApp] Error   4/17/2023, 2:31:50 PM error:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
[MyApp] Warn    4/17/2023, 2:31:50 PM warn:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
[MyApp] Info    4/17/2023, 2:31:50 PM info:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
[MyApp] Http    4/17/2023, 2:31:50 PM http:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
[MyApp] Verbose 4/17/2023, 2:31:50 PM verbose:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
[MyApp] Debug   4/17/2023, 2:31:50 PM debug:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
[MyApp] Silly   4/17/2023, 2:31:50 PM silly:  - { name: 'assu1', email: 'test1@test.com', password: '12341234' }
```

---

## 3.2. 내장 Logger 대체

`nest-winston` 은 LoggerService 를 구현한 `WinstonLogger` 클래스를 제공하는데 Nest 가 시스템 로깅을 할 때 바로 이 클래스를 이용하도록 해서 
Nest 시스템에서 출력하는 로그와 우리가 출력하려는 로그의 형식을 동일하게 설정할 수 있다.

WinstonLogger 시그니처
```ts
export declare class WinstonLogger implements LoggerService {
    private readonly logger;
    private context?;
    constructor(logger: Logger);
    setContext(context: string): void;
    log(message: any, context?: string): any;
    error(message: any, trace?: string, context?: string): any;
    warn(message: any, context?: string): any;
    debug?(message: any, context?: string): any;
    verbose?(message: any, context?: string): any;
    getWinstonLogger(): Logger;
}
```

우선 `WinstonLogger` 를 전역 Logger 로 설정한다.

main.ts
```ts
...
import { WINSTON_MODULE_NEST_PROVIDER } from 'nest-winston';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
    }),
  );
  app.useLogger(app.get(WINSTON_MODULE_NEST_PROVIDER));
  await app.listen(3000);
}
bootstrap();
```

이제 로깅하려는 곳에서 LoggerService 를 `WINSTON_MODULE_NEST_PROVIDER` 토큰으로 주입받아서 사용한다.

/src/users/users.controller.ts
```ts
import {
  LoggerService,
  InternalServerErrorException,
} from '@nestjs/common';
import { WINSTON_MODULE_NEST_PROVIDER } from 'nest-winston';

@Controller('users')
export class UsersController {
  // UsersService 를 컨트롤러에 주입
  constructor(
          // nest-winston 적용
          //@Inject(WINSTON_MODULE_PROVIDER) private readonly logger: WinstonLogger,

          // 내장 로거 대체
          @Inject(WINSTON_MODULE_NEST_PROVIDER) private readonly logger: LoggerService,
  ) {
  }

  // 회원 가입
  @Post()
  async createUser(@Body() dto: CreateUserDto): Promise<void> {
    const {name, email, password} = dto;
    console.log('createUser dto: ', dto);
    //this.printWinstonLog(dto);
    this.printLoggerServiceLog(dto);
    await this.usersService.createUser(name, email, password);
  }

  // nest-winston 적용
  // private printWinstonLog(dto) {
  //   // console.log(this.logger.name);
  //
  //   this.logger.error('error: ', dto);
  //   this.logger.warn('warn: ', dto);
  //   this.logger.info('info: ', dto);
  //   this.logger.http('http: ', dto);
  //   this.logger.verbose('verbose: ', dto);
  //   this.logger.debug('debug: ', dto);
  //   this.logger.silly('silly: ', dto);
  // }

  // 내장 로거 대체
  private printLoggerServiceLog(dto) {
    try {
      throw new InternalServerErrorException('test');
    } catch (e) {
      this.logger.error('error::', JSON.stringify(dto), e.stack);
    }

    this.logger.warn('warn: ', JSON.stringify(dto));
    this.logger.log('log: ', JSON.stringify(dto));
    this.logger.verbose('verbose: ', JSON.stringify(dto));
    this.logger.debug('debug: ', JSON.stringify(dto));
  }
}
```

```shell
[MyApp] Error   4/17/2023, 3:03:22 PM [InternalServerErrorException: test
    at UsersController.printLoggerServiceLog (/Users/-/Developer/05_nestjs/me/user-service/src/users/users.controller.ts:63:13)
    at UsersController.createUser (/Users/-/Developer/05_nestjs/me/user-service/src/users/users.controller.ts:43:10)
    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:38:29
    at processTicksAndRejections (node:internal/process/task_queues:95:5)
    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:46:28
    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-proxy.js:9:17] error:: - {
  stack: [ '{"name":"assu1","email":"test1@test.com","password":"12341234"}' ]
}
[MyApp] Warn    4/17/2023, 3:03:22 PM [{"name":"assu1","email":"test1@test.com","password":"12341234"}] warn:  - {}
[MyApp] Info    4/17/2023, 3:03:22 PM [{"name":"assu1","email":"test1@test.com","password":"12341234"}] log:  - {}
[MyApp] Verbose 4/17/2023, 3:03:22 PM [{"name":"assu1","email":"test1@test.com","password":"12341234"}] verbose:  - {}
[MyApp] Debug   4/17/2023, 3:03:22 PM [{"name":"assu1","email":"test1@test.com","password":"12341234"}] debug:  - {}
```

LoggerService 가 제공하는 로그 레벨은 WinstonLogger 에 비해 좀 제한적이다. LoggerService 는 WinstonLogger 와 다르게 인수로 받은 객체를 출력하지 않기 때문에
내용을 출력하기 위해서 dto 객체를 아래와 같이 string 으로 변환하여 메시지 내에 포함시켜 주었다.

```ts
this.logger.error('error::', JSON.stringify(dto), e.stack);
```

error 함수는 두 번째 인수로 받은 객체를 stack 속성을 가진 객체로 출력한다.

error 함수에 넘기는 인자에 따른 출력 비교
```shell
this.logger.error('error::', JSON.stringify(dto), e.stack);

[MyApp] Error   4/17/2023, 3:34:47 PM [InternalServerErrorException: test
    at UsersController.printLoggerServiceLog (/Users/-/Developer/05_nestjs/me/user-service/src/users/users.controller.ts:63:13)
    at UsersController.createUser (/Users/-/Developer/05_nestjs/me/user-service/src/users/users.controller.ts:43:10)
    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:38:29
    at processTicksAndRejections (node:internal/process/task_queues:95:5)
    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:46:28
    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-proxy.js:9:17] error:: - {
  stack: [
    '{"name":"assu1","email":"test2sdd1@test.com","password":"12341234"}'
  ]
}
```

```shell
this.logger.error('error::', e.stack);

[MyApp] Error   4/17/2023, 3:34:47 PM error:: - {
  stack: [
    'InternalServerErrorException: test\n' +
      '    at UsersController.printLoggerServiceLog (/Users/-/Developer/05_nestjs/me/user-service/src/users/users.controller.ts:63:13)\n' +
      '    at UsersController.createUser (/Users/-/Developer/05_nestjs/me/user-service/src/users/users.controller.ts:43:10)\n' +
      '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:38:29\n' +
      '    at processTicksAndRejections (node:internal/process/task_queues:95:5)\n' +
      '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-execution-context.js:46:28\n' +
      '    at /Users/-/Developer/05_nestjs/me/user-service/node_modules/@nestjs/core/router/router-proxy.js:9:17'
  ]
}
```

```shell
this.logger.error('error::', JSON.stringify(dto));

[MyApp] Error   4/17/2023, 3:34:47 PM error:: - {
  stack: [
    '{"name":"assu1","email":"test2sdd1@test.com","password":"12341234"}'
  ]
}
```

NestJS 는 라우터 엔드포인트를 시스템 로그로 출력하는데 서비스 재시작 시 `nest-winston` 모듈이 적용된 것을 확인할 수 있다.  
([Nest] 가 아닌 [MyApp] 태그)
```shell
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [NestFactory] Starting Nest application...
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] AppModule dependencies initialized +75ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] TypeOrmModule dependencies initialized +1ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] ConfigHostModule dependencies initialized +2ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] WinstonModule dependencies initialized +1ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] EmailModule dependencies initialized +0ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] AuthModule dependencies initialized +0ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] ConfigModule dependencies initialized +0ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] TypeOrmCoreModule dependencies initialized +42ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] TypeOrmModule dependencies initialized +0ms
[Nest] 1069  - 04/17/2023, 3:34:44 PM     LOG [InstanceLoader] UsersModule dependencies initialized +1ms
[MyApp] Info    4/17/2023, 3:34:44 PM [RoutesResolver] UsersController {/users}: - {}
[MyApp] Info    4/17/2023, 3:34:44 PM [RouterExplorer] Mapped {/users, POST} route - {}
[MyApp] Info    4/17/2023, 3:34:44 PM [RouterExplorer] Mapped {/users/email-verify, POST} route - {}
[MyApp] Info    4/17/2023, 3:34:44 PM [RouterExplorer] Mapped {/users/login, POST} route - {}
[MyApp] Info    4/17/2023, 3:34:44 PM [RouterExplorer] Mapped {/users/:id, GET} route - {}
[MyApp] Info    4/17/2023, 3:34:44 PM [NestApplication] Nest application successfully started - {}
```

---

## 3.3. BootStrapping 까지 포함하여 내장 Logger 대체

바로 위의 시스템이 부팅될 때 BootStrapping 과정은 아직 WinstonLogger 가 적용되지 않아 [Nest] 태그가 붙은 내장 로거가 사용되고 있는 것을 알 수 있다.  
BootStrapping 과정까지 포함하여 Nest Logger 를 대체하려면 NestFactory.create 시 `bufferLogs` 설정을 true 로 설정하면 된다.

main.ts
```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import {
  utilities,
  WINSTON_MODULE_NEST_PROVIDER,
  WinstonModule,
} from 'nest-winston';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true, // 부트스트래핑 과정까지 nest-winston 로거 사용
  });
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
    }),
  );
  app.useLogger(app.get(WINSTON_MODULE_NEST_PROVIDER));
  await app.listen(3000);
}
bootstrap();
```
---

## 3.4. 외부 서비스에 로그 전송

winston 을 사용하는 이유는 로그 포맷을 구성하기 쉽다는 점과 로그를 파일이나 DB 에 저장하기도 쉽고, [New Relic](https://newrelic.com/) 이나 [DataDog](https://www.datadoghq.com/) 과 같은 외부 유료 서비스에 로그를 전송하여
로그 분석툴과 시각화 툴을 활용하기 위해서이다.

winston 을 사용하면 다른 매체에 로그를 저장하거나 외부 서비스에 로그를 전송할 때 간단한 설정만으로 구현이 가능하다.

`transports` 옵션이 리스트를 받도록 되어있기 때문에 여기에 전송할 옵션을 추가해주기만 하면 되고, `winston-transport` 라이브러리를 이용하여 TransportStream 으로 지속적인
로그 전달도 가능하다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [NestJS docs](https://docs.nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [NestJS Log Level](https://github.com/nestjs/nest/blob/master/packages/common/services/utils/is-log-level-enabled.util.ts#L3)
* [winston: npm](https://www.npmjs.com/package/winston)
* [nest-winston: npm](https://www.npmjs.com/package/nest-winston)
* [winston 공식 문서](https://github.com/winstonjs/winston)
* [New Relic](https://newrelic.com/)
* [DataDog](https://www.datadoghq.com/)