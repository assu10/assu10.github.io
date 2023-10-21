---
layout: post
title:  "NestJS - Health Check"
date:   2023-04-15
categories: dev
tags: nestjs health-check
---

이 포스팅은 NestJS 에서 HTTP Health Check, TypeORM Health Check, Custom Health Check 하는 법에 대해 알아본다.

- [NestJS 의 Health Check](#1-nestjs-의-health-check)
- [Terminus 적용](#2-terminus-적용)
- [HTTP Health Check: `HttpHealthIndicator`, `@HealthCheck()`](#3-http-health-check-httphealthindicator-healthcheck)
- [TypeORM Health Check: `TypeOrmHealthIndicator`](#4-typeorm-health-check-typeormhealthindicator)
- [Custom Health Indicator](#5-custom-상태-표시기)

소스는 [user-service](https://github.com/assu10/nestjs/tree/user-service/ch15) 에 있습니다.

---

# 1. NestJS 의 Health Check

서버는 HTTP, DB 등을 체크하는 Health Check 장치가 있어야 한다.

Healthy 하지 않은 상태가 되었을 때 바로 알람을 보내기보다는 예를 들어 10분간 응답 성공률이 95% 이하가 되었을 경우 알람을 주는 식으로 구성한다.

NestJS 는 `Terminus(@nestjs/terminus)` Health Check 라이브러리를 제공한다.

Terminus 는 다양한 Health Indicator 를 제공하여, 필요하면 직접 만들어서 사용할 수도 있다.

`@nestjs/terminus` 패키지에서 제공하는 Health Indicator 는 아래와 같다.  
해당 포스트에선 HttpHealthIndicator 와 TypeOrmHealthIndicator 에 대해 알아본다.

- **HttpHealthIndicator** 
- **MongooseHealthIndicator**
- **TypeOrmHealthIndicator**
- **SequelizeHealthIndicator**

---

# 2. Terminus 적용

Terminus 설치

```shell
$ npm i @nestjs/terminus
```

상태 확인은 특정 라우터 엔드포인트에 요청을 보낸 후 응답을 확인하는 방법을 사용하는데 이를 위해 HealthCheckController 를 생성하고, 
TerminusModule 과 HealthCheckController 를 실행할 수 있도록 AppModule 에 추가한다.

```shell
$ nest g co health-check
CREATE src/health-check/health-check.controller.spec.ts (528 bytes)
CREATE src/health-check/health-check.controller.ts (112 bytes)
UPDATE src/app.module.ts (2701 bytes)
```

app.module.ts
```ts
...
import { HealthCheckController } from './health-check/health-check.controller';
import { TerminusModule } from '@nestjs/terminus';

@Module({
  imports: [
      ...
      TerminusModule
  ],
  controllers: [HealthCheckController],
  providers: [],
})
export class AppModule {}
```

---

# 3. HTTP Health Check: `HttpHealthIndicator`, `@HealthCheck()`

`HttpHealthIndicator` 는 동작 시 HTTP 클라이언트 패키지인 `@nestjs/axios` 가 필요하다.

```shell
$ npm i @nestjs/axios
```

`@nestjs/axios` 에서 제공하는 HttpModule 도 사용 가능하도록 AppModule 에 imports 에 추가한다.

app.module.ts
```ts
...
import { HealthCheckController } from './health-check/health-check.controller';
import { TerminusModule } from '@nestjs/terminus';
import { HttpModule } from '@nestjs/axios';

@Module({
  imports: [
    ...
    TerminusModule,
    HttpModule,
  ],
  controllers: [HealthCheckController],
  providers: [],
})
export class AppModule {}
```

이제 위에서 생성한 HealthCheckController 에 HTTP Health Check 코드를 구현한다.

/src/health-check/health-check.controller.ts 
```ts
import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  HttpHealthIndicator,
} from '@nestjs/terminus';

@Controller('health-check')
export class HealthCheckController {
  constructor(
    private healthCheckService: HealthCheckService,
    private httpHealthIndicator: HttpHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.healthCheckService.check([
      // HttpHealthIndicator 가 제공하는 pingCheck() 를 통해 다른 서버가 잘 동작하고 있는지 확인
      // https://docs.nestjs.com 에 요청을 보내서 받은 응답을 첫 번째 인수인 nestjs-docss 에 준다는 의미
      () =>
        this.httpHealthIndicator.pingCheck(
          'nestjs-docss',
          'https://docs.nestjs.com',
        ),
    ]);
  }
}
```

```shell
$ npm run start:dev
```

```shell
$ curl --location 'http://localhost:3000/health-check' | jq

{
  "status": "ok",
  "info": {
    "nestjs-docss": {
      "status": "up"
    }
  },
  "error": {},
  "details": {
    "nestjs-docss": {
      "status": "up"
    }
  }
}
```

HealthCheckService.check() 시그니처
```ts
check(healthIndicators: HealthIndicatorFunction[]): Promise<HealthCheckResult>;
```

HealthCheckResult 시그니처
```ts
import { HealthIndicatorResult } from '../health-indicator';
/**
 * @publicApi
 */
export declare type HealthCheckStatus = 'error' | 'ok' | 'shutting_down';
/**
 * The result of a health check
 * @publicApi
 */
export interface HealthCheckResult {
    /**
     * The overall status of the Health Check
     
     * 헬스 체크를 수행한 전반적인 상태, 'error' | 'ok' | 'shutting_down'
     */
    status: HealthCheckStatus;
    /**
     * The info object contains information of each health indicator
     * which is of status "up"
     
     * 상태가 up 일 때의 상태 정보
     */
    info?: HealthIndicatorResult;
    /**
     * The error object contains information of each health indicator
     * which is of status "down"
     * 
     * 상태가 down 일 때의 상태 정보
     */
    error?: HealthIndicatorResult;
    /**
     * The details object contains information of every health indicator.
     * 
     * 모든 Health Indecator 의 정보
     */
    details: HealthIndicatorResult;
}
```

---

# 4. TypeORM Health Check: `TypeOrmHealthIndicator`

`TypeOrmHealthIndicator` 은 단순히 DB 가 잘 살아있는지 확인한다.  

/src/health-check/health-check.controller.ts 
```ts
import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  HttpHealthIndicator,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';

@Controller('health-check')
export class HealthCheckController {
  constructor(
    private healthCheckService: HealthCheckService,
    private httpHealthIndicator: HttpHealthIndicator,
    private typeOrmHealthIndicator: TypeOrmHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.healthCheckService.check([
      () => this.httpHealthIndicator.pingCheck('nestjs-docss','https://docs.nestjs.com'),
      () => this.typeOrmHealthIndicator.pingCheck('database'),
    ]);
  }
}
```

```shell
$ curl --location 'http://localhost:3000/health-check' | jq

{
  "status": "ok",
  "info": {
    "nestjs-docss": {
      "status": "up"
    },
    "database": {
      "status": "up"
    }
  },
  "error": {},
  "details": {
    "nestjs-docss": {
      "status": "up"
    },
    "database": {
      "status": "up"
    }
  }
}
```

---

# 5. Custom 상태 표시기

`@nestjs/terminus` 에서 제공하지 않는 Health Indicator 가 필요하면 `HealthIndicator` 를 상속받는 Custom Health Indicator 를 직접 생성할 수도 있다. 

`HealthIndicator` 시그니처
```ts
export declare abstract class HealthIndicator {
    /**
     * Generates the health indicator result object
     * @param key The key which will be used as key for the result object
     * @param isHealthy Whether the health indicator is healthy
     * @param data Additional data which will get appended to the result object
     */
    protected getStatus(key: string, isHealthy: boolean, data?: {
        [key: string]: any;
    }): HealthIndicatorResult;
}

export declare type HealthIndicatorResult = {
    /**
     * The key of the health indicator which should be unique
     */
    [key: string]: {
        /**
         * The status if the given health indicator was successful or not
         */
        status: HealthIndicatorStatus;
        /**
         * Optional settings of the health indicator result
         */
        [optionalKeys: string]: any;
    };
};

export declare type HealthIndicatorStatus = 'up' | 'down';
```

`HealthIndicator` 에는 `HealthIndicatorResult` 를 리턴해주는 getStatus() 가 있는데 이 메서드의 인자는 아래와 같다.
- key
  - 상태를 나타냄
- isHealthy 
  - Health Indicator 가 상태를 측정한 결과
- data
  - 결과에 포함시킬 데이터

아래는 강아지 상태를 나타내는 DegHealthIndicator 예시이다.

/src/health-check/dog.health.ts
```ts
import { Injectable } from '@nestjs/common';
import { HealthCheckError, HealthIndicator } from '@nestjs/terminus';
import { HealthIndicatorResult } from '@nestjs/terminus/dist/health-indicator';

export interface Dog {
  name: string;
  type: string;
}

@Injectable()
export class DogHealthIndicator extends HealthIndicator {
  private dogs: Dog[] = [
    { name: 'Silby', type: 'good' },
    { name: 'Kamang', type: 'normal' },
  ];

  // 강아지 상태가 모두 good 인지 체크
  // normal 인 강아지가 있으면 HealthCheckError 던짐
  async isHealthy(key: string): Promise<HealthIndicatorResult> {
    const normals = this.dogs.filter((dog) => dog.type === 'normal');
    const isHealthy = normals.length === 0;
    const result = this.getStatus(key, isHealthy, { normals: normals.length });

    if (isHealthy) {
      return result;
    }

    throw new HealthCheckError(`Normal Dog: ${normals}`, result);
  }
}
```

이제 DogHealthIndicator 를 사용하기 위해 AppModule 에 Provider 로 제공한다.

app.module.ts
```ts
...
import { DogHealthIndicator } from './health-check/dog.health';

@Module({
  ...
  providers: [DogHealthIndicator],
})
export class AppModule {}
```

이제 HealthCheck Controller 에서 DogHealthIndicator 를 주입받아 사용해본다.

/src/health-check/health-check.controller.ts 
```ts
import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  HttpHealthIndicator,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import { DogHealthIndicator } from './dog.health';

@Controller('health-check')
export class HealthCheckController {
  constructor(
    private healthCheckService: HealthCheckService,
    private httpHealthIndicator: HttpHealthIndicator,
    private typeOrmHealthIndicator: TypeOrmHealthIndicator,
    private dogHealthIndicator: DogHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.healthCheckService.check([
      // HttpHealthIndicator 가 제공하는 pingCheck() 를 통해 다른 서버가 잘 동작하고 있는지 확인
      // https://docs.nestjs.com 에 요청을 보내서 받은 응답을 첫 번째 인수인 nestjs-docss 에 준다는 의미
      () =>
        this.httpHealthIndicator.pingCheck(
          'nestjs-docss',
          'https://docs.nestjs.com',
        ),
      () => this.typeOrmHealthIndicator.pingCheck('database'),
      () => this.dogHealthIndicator.isHealthy('dog'),
    ]);
  }
}
```

```shell
$ curl --location 'http://localhost:3000/health-check' | jq

{
  "status": "error",
  "info": {
    "nestjs-docss": {
      "status": "up"
    },
    "database": {
      "status": "up"
    }
  },
  "error": {
    "dog": {
      "status": "down",
      "normals": 1
    }
  },
  "details": {
    "nestjs-docss": {
      "status": "up"
    },
    "database": {
      "status": "up"
    },
    "dog": {
      "status": "down",
      "normals": 1
    }
  }
}
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)