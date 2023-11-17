---
layout: post
title:  "NestJS - Task Scheduling"
date:   2023-04-09
categories: dev
tags: nestjs task-scheduling
---

이 포스트는 NestJS 에서 Task Scheduling 을 선언하는 방법에 대해 알아본다.

- [`@nest/schedule` 패키지](#1-nestschedule-패키지)
- [Task Scheduling 선언](#2-task-scheduling-선언)
  - [Cron Job 선언 방식: `@Cron`](#21-cron-job-선언-방식-cron)
  - [Interval 선언 방식: `@Interval`](#22-interval-선언-방식-interval)
  - [Timeout 선언 방식: `@Timeout`](#23-timeout-선언-방식-timeout)
- [Dynamic Task Scheduling](#3-dynamic-task-scheduling)

소스는 [example](https://github.com/assu10/nestjs/tree/feature/ch14) 에 있습니다.

---

# 1. `@nest/schedule` 패키지

주기적 반복 작업을 Task 혹은 Batch 라고 한다.

NestJS 에는 인기 패키지인 [node-cron](https://github.com/kelektiv/node-cron) 을 통합한 `@nestjs/schedule` 패키지를 제공한다.

```shell
$ nest new ch14

$ npm i @nestjs/schedule @types/cron   
```

Task Scheduling 은 `@nestjs/schedule` 패키지에 포함된 `ScheduleModule` 을 사용한다.  

`ScheduleModule` 을 AppModule 에서 바로 가져와도 되지만 태스크 관련 작업을 담당하는 별도의 모듈인 BatchModule 에 작성해보도록 한다.

```shell
$  nest g mo batch
CREATE src/batch/batch.module.ts (82 bytes)
UPDATE src/app.module.ts (312 bytes)
```

/src/batch/batch.module.ts 
```ts
import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { TaskService } from './task.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [TaskService], // 아래에서 생성할 서비스
})
export class BatchModule {}
```

`ScheduleModule` 은 forRoot() 메서드를 통해 가져오는데 이 과정에서 NestJS 는 스케쥴러를 초기화하여 앱에 선언한 Cron Job 과 Timeout, Interval 등을 등록한다.  
Timeout 은 스케쥴링이 끝나는 시각을 의미한다.

Task Scheduling 은 모든 모듈이 예약된 작업을 로드하고 확인하는 `onApplicationBootstrap` 생명주기 Hook 이 발생할 때 등록된다.

ScheduleModule 에 Task 를 등록하는 방법은 3 가지가 있다. 아래에 각 방법에 대해 살펴본다. 

---

# 2. Task Scheduling 선언

위의 BatchModule 에는 TaskService Provider 가 있는데 이 TaskService 에 실제 수행되는 Task 를 구현하고 있다.

NestJS 가 Task Scheduling 을 선언하는 `@Cron`, `@Interval`, `@Timeout` 데커레이터를 사용하는 3가지 방법에 대해 알아본다.

---

## 2.1. Cron Job 선언 방식: `@Cron`

**Cron Job 선언 방식은 `@Cron` 데커레이터를 선언한 메서드를 Task 로 구현하는 방식**이다.

/src/batch/task.service.ts
```ts
import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

@Injectable()
export class TaskService {
  private readonly logger = new Logger(TaskService.name);

  @Cron('* * * * * *', { name: 'cronTask' })
  handleCron() {
    this.logger.log('Task Called!');
  }
}
```

`@Cron` 데커레이터의 첫 번째 인수는 Task 의 반복 주기로서 [표준 크론 패턴](http://crontab.org/) 을 따른다.

총 6개의 문자열을 받는데 초, 분, 시간, 날, 월, 요일 의 순이다.

- 초: 0-59의 값을 가짐, 선택 사항 (초를 생략하고 5자리만 표기 시 초를 0 으로 취급)
- 분: 0-59의 값을 가짐
- 시간: 0-23의 값을 가짐
- 날: 1-31 의 값을 가짐
- 월: 0-12의 값을 가짐, 0과 12는 12월
- 요일: 0-7의 값을 가짐, 0과 7은 일요일

예를 들어 각 패턴의 의미는 아래와 같다.

- `* * * * * *`: 매 초마다
- `45 * * * * *`: 매 분 45초마다
- `0 10 * * * *`: 매 시간, 10분에
- `0 /30 9-17 * *`: 오전 9시부터 오후 5시까지 30분 마다
- `0 30 11 * * 1-5`: 월~금요일 오전 11시 30분에

매 초마다 수행되는 Task 를 등록했으니 로그가 정상적으로 출력되는지 확인해본다.
```shell
$ npm run start:dev

[Nest] 81534  - 04/29/2023, 12:49:34 PM     LOG [NestFactory] Starting Nest application...
[Nest] 81534  - 04/29/2023, 12:49:34 PM     LOG [InstanceLoader] AppModule dependencies initialized +14ms
[Nest] 81534  - 04/29/2023, 12:49:34 PM     LOG [InstanceLoader] BatchModule dependencies initialized +0ms
[Nest] 81534  - 04/29/2023, 12:49:34 PM     LOG [InstanceLoader] DiscoveryModule dependencies initialized +0ms
[Nest] 81534  - 04/29/2023, 12:49:34 PM     LOG [InstanceLoader] ScheduleModule dependencies initialized +0ms
[Nest] 81534  - 04/29/2023, 12:49:34 PM     LOG [NestApplication] Nest application successfully started +17ms
[Nest] 81534  - 04/29/2023, 12:49:35 PM     LOG [TaskService] Task Called!
[Nest] 81534  - 04/29/2023, 12:49:36 PM     LOG [TaskService] Task Called!
[Nest] 81534  - 04/29/2023, 12:49:37 PM     LOG [TaskService] Task Called!
[Nest] 81534  - 04/29/2023, 12:49:38 PM     LOG [TaskService] Task Called!
[Nest] 81534  - 04/29/2023, 12:49:39 PM     LOG [TaskService] Task Called!
```

**한 번만 수행되는 Task 를 등록하려면 수행되는 시각은 Date 객체로 설정**하면 된다.

```ts
@Cron(new Date(Date.now() + 3 * 1000)) // 앱이 실행되고 나서 3초 뒤에 수행
handleCron() {
  this.logger.log('Task Called!');
}
```

```shell
$ npm run start:dev

[Nest] 82129  - 04/29/2023, 12:57:01 PM     LOG [NestFactory] Starting Nest application...
[Nest] 82129  - 04/29/2023, 12:57:01 PM     LOG [InstanceLoader] AppModule dependencies initialized +13ms
[Nest] 82129  - 04/29/2023, 12:57:01 PM     LOG [InstanceLoader] BatchModule dependencies initialized +0ms
[Nest] 82129  - 04/29/2023, 12:57:01 PM     LOG [InstanceLoader] DiscoveryModule dependencies initialized +0ms
[Nest] 82129  - 04/29/2023, 12:57:01 PM     LOG [InstanceLoader] ScheduleModule dependencies initialized +0ms
[Nest] 82129  - 04/29/2023, 12:57:01 PM     LOG [NestApplication] Nest application successfully started +15ms
[Nest] 82129  - 04/29/2023, 12:57:04 PM     LOG [TaskService] Task Called!    # 앱 실행 후 3초 뒤 실행
```

NestJS 는 **자주 사용되는 패턴을 [CronExpression 열거형](https://github.com/nestjs/schedule/blob/master/lib/enums/cron-expression.enum.ts)으로 제공**하고 있다.

예를 들어 월~금 새벽 1시에 수행되는 Task 는 아래와 같이 할 수 있다.
```ts
import { Cron, CronExpression } from '@nestjs/schedule';

...

@Cron(CronExpression.MONDAY_TO_FRIDAY_AT_1AM) // 월~금 새벽 1시에 수행
handleCron() {
  this.logger.log('Task Called!');
}
```

`@Cron` 데커레이터 시그니처
```ts
export declare function Cron(cronTime: string | Date, options?: CronOptions): MethodDecorator;


/**
 * @ref https://github.com/DefinitelyTyped/DefinitelyTyped/blob/master/types/cron/index.d.ts
 */
export interface CronOptions {
  /**
   * Specify the name of your cron job. This will allow to inject your cron job reference through `@InjectCronRef`.
   */
  name?: string;
  /**
   * Specify the timezone for the execution. This will modify the actual time relative to your timezone. If the timezone is invalid, an error is thrown. You can check all timezones available at [Moment Timezone Website](http://momentjs.com/timezone/). Probably don't use both ```timeZone``` and ```utcOffset``` together or weird things may happen.
   */
  timeZone?: string;
  /**
   * This allows you to specify the offset of your timezone rather than using the ```timeZone``` param. Probably don't use both ```timeZone``` and ```utcOffset``` together or weird things may happen.
   */
  utcOffset?: string | number;
  /**
   * If you have code that keeps the event loop running and want to stop the node process when that finishes regardless of the state of your cronjob, you can do so making use of this parameter. This is off by default and cron will run as if it needs to control the event loop. For more information take a look at [timers#timers_timeout_unref](https://nodejs.org/api/timers.html#timers_timeout_unref) from the NodeJS docs.
   */
  unrefTimeout?: boolean;
  /**
   * This flag indicates whether the job will be executed at all.
   * @default false
   */
  disabled?: boolean;
}
```

- `name`
  - Task 이름
  - 선언한 Cron Job 에 액세스할 때 유용
- `timeZone`
  - 실행 시간대 지정
  - [moment Timezone](https://momentjs.com/timezone/) 에서 사용 가능한 모든 시간대 확인 가능
  - 우리 나라는 Asia/Seoul
  - `utcOffset` 과 동시에 사용하면 오류 발생 가능성 있음
- `utcOffset`
  - timeZone 대신 UTC 기반으로 시간대의 오프셋 지정
  - 우리 나라 시간대 설정 시엔 문자열 '+09:00' 을 사용하거나 숫자 9 사용
  - `timeZone` 과 동시에 사용하면 오류 발생 가능성 있음
- `unrefTimeout`
  - Node.js 의 timeout.unref() 와 관련 있음
  - 이벤트 루프를 계속 실행하는 코드가 있고 Cron Job 상태에 관계없이 Job 이 완료될 때 Node 프로세스를 중지하고 싶을 때 사용
- `disabled`

---

## 2.2. Interval 선언 방식: `@Interval`

**Task 수행 함수에 `@Interval` 데커레이터를 사용**할 수도 있다.

첫 번째 인수는 Task 의 이름이고, 두 번째 인수는 타임아웃 시간(ms) 이다.

```ts
import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';

@Injectable()
export class TaskService {
  private readonly logger = new Logger(TaskService.name);

  @Interval('intervalTask', 3000)   // 앱 실행 후 3초 후에 처음 수행되며, 3초마다 반복
  handleInterval() {
    this.logger.log('Task Called!');
  }
}
```

```shell
$ npm run start:dev 

[Nest] 83513  - 04/29/2023, 1:15:02 PM     LOG [NestFactory] Starting Nest application...
[Nest] 83513  - 04/29/2023, 1:15:02 PM     LOG [InstanceLoader] AppModule dependencies initialized +12ms
[Nest] 83513  - 04/29/2023, 1:15:02 PM     LOG [InstanceLoader] BatchModule dependencies initialized +0ms
[Nest] 83513  - 04/29/2023, 1:15:02 PM     LOG [InstanceLoader] DiscoveryModule dependencies initialized +0ms
[Nest] 83513  - 04/29/2023, 1:15:02 PM     LOG [InstanceLoader] ScheduleModule dependencies initialized +1ms
[Nest] 83513  - 04/29/2023, 1:15:02 PM     LOG [NestApplication] Nest application successfully started +11ms
[Nest] 83513  - 04/29/2023, 1:15:05 PM     LOG [TaskService] Task Called!
[Nest] 83513  - 04/29/2023, 1:15:08 PM     LOG [TaskService] Task Called!
[Nest] 83513  - 04/29/2023, 1:15:11 PM     LOG [TaskService] Task Called!
[Nest] 83513  - 04/29/2023, 1:15:14 PM     LOG [TaskService] Task Called!
```

---

## 2.3. Timeout 선언 방식: `@Timeout`

**`@Timeout` 데커레이터를 사용하면 앱에 실행된 후 Task 를 단 한번만 수행**한다.

인수는 `@Interval` 데커레이터와 동일하게 첫 번째 인수는 Task 의 이름이고, 두 번째 인수는 타임아웃 시간(ms) 이다.

```ts
import { Injectable, Logger } from '@nestjs/common';
import { Timeout } from '@nestjs/schedule';

@Injectable()
export class TaskService {
  private readonly logger = new Logger(TaskService.name);

  @Timeout('timeout', 3000) // 앱 실행 후 3초 뒤에 한번만 실행
  handleTimeout() {
    this.logger.log('Task Called!');
  }
}
```

```shell
$ npm run start:dev

[Nest] 83929  - 04/29/2023, 1:19:44 PM     LOG [NestFactory] Starting Nest application...
[Nest] 83929  - 04/29/2023, 1:19:44 PM     LOG [InstanceLoader] AppModule dependencies initialized +13ms
[Nest] 83929  - 04/29/2023, 1:19:44 PM     LOG [InstanceLoader] BatchModule dependencies initialized +0ms
[Nest] 83929  - 04/29/2023, 1:19:44 PM     LOG [InstanceLoader] DiscoveryModule dependencies initialized +0ms
[Nest] 83929  - 04/29/2023, 1:19:44 PM     LOG [InstanceLoader] ScheduleModule dependencies initialized +0ms
[Nest] 83929  - 04/29/2023, 1:19:44 PM     LOG [NestApplication] Nest application successfully started +14ms
[Nest] 83929  - 04/29/2023, 1:19:47 PM     LOG [TaskService] Task Called!
```

---

# 3. Dynamic Task Scheduling

위의 `@Cron`, `@Interval`, `@Timeout` 3가지 방법 모두 앱이 구동되는 과정에서 Task 가 등록되는 방식이다.

만일 **앱 구동 중 특정 조건을 만족했을 때 Task 를 등록해야 한다면 동적으로 Task 를 등록/해제**해야 한다.

Dynamic Task Scheduling 은 `SchedulerRegistry` 에서 제공하는 API 를 사용하여 구현할 수 있다. 

```ts
import { Injectable, Logger } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CronJob } from 'cron';

@Injectable()
export class TaskService {
  private readonly logger = new Logger(TaskService.name);

  // ScheduleRegistry 객체를 TaskService 에 주입
  constructor(private schedulerRegistry: SchedulerRegistry) {
    // TaskService 가 생성될 때 Cron Job 하나를 SchedulerRegistry 에 추가함
    // SchedulerRegistry 에 Cron Job 을 추가만 해두는 것이지 Task Scheduling 을 등록하는 것은 아님
    this.addCronJob();
  }

  addCronJob() {
    const name = 'cronSample';

    const job = new CronJob('* * * * * *', () => {
      this.logger.warn(`run! ${name}`);
    });

    this.schedulerRegistry.addCronJob(name, job);

    this.logger.warn(`job ${name} added!!`);
  }
}
```

이 상태에선 앱을 구동해도 아무런 동작도 하지 않는다. 등록된 Cron Job 을 스케쥴링으로 동작시키고 중지하는 기능을 가진 Controller 을 추가한다.

```shell
$  nest g co batch
CREATE src/batch/batch.controller.spec.ts (485 bytes)
CREATE src/batch/batch.controller.ts (99 bytes)
UPDATE src/batch/batch.module.ts (335 bytes)
```

/src/batch/batch.controller.ts
```ts
import { Controller, Post } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';

@Controller('batches')
export class BatchController {
  // 컨트롤러에도 ScheduleRegistry 를 주입받음
  constructor(private scheduler: SchedulerRegistry) {}

  @Post('/start')
  start() {
    // SchedulerRegistry 에 등록된 크론 잡 가져옴
    const job = this.scheduler.getCronJob('cronSample');

    // 크론 잡 실행
    job.start();

    console.log('start!! ', job.lastDate());
  }

  @Post('/stop')
  stop() {
    // SchedulerRegistry 에 등록된 크론 잡 가져옴
    const job = this.scheduler.getCronJob('cronSample');

    // 크론 잡 실행
    job.stop();

    console.log('stop!! ', job.lastDate());
  }
}
```

이제 BatchController 를 BatchModule 에 선언한다.

/src/batch/batch.module.ts
```ts
import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { TaskService } from './task.service';
import { BatchController } from './batch.controller';

@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [TaskService],
  controllers: [BatchController],
})
export class BatchModule {}
```

이제 start, stop API 로 Cron Job 을 제어 가능하다.

start
```shell
$ npm run start:dev

$ curl --location --request POST 'http://localhost:3000/batches/start' | jq
```

```shell
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [NestFactory] Starting Nest application...
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [InstanceLoader] AppModule dependencies initialized +47ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM    WARN [TaskService] job cronSample added!!
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [InstanceLoader] DiscoveryModule dependencies initialized +0ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [InstanceLoader] ScheduleModule dependencies initialized +0ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [InstanceLoader] BatchModule dependencies initialized +0ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [RoutesResolver] BatchController {/batches}: +22ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [RouterExplorer] Mapped {/batches/start, POST} route +2ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [RouterExplorer] Mapped {/batches/stop, POST} route +0ms
[Nest] 85673  - 04/29/2023, 1:39:35 PM     LOG [NestApplication] Nest application successfully started +3ms
start!!  undefined
[Nest] 85673  - 04/29/2023, 1:40:14 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:40:15 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:40:16 PM    WARN [TaskService] run! cronSample
```

stop
```shell
$ curl --location --request POST 'http://localhost:3000/batches/stop' | jq
```

```shell
[Nest] 85673  - 04/29/2023, 1:41:14 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:15 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:16 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:17 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:18 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:19 PM    WARN [TaskService] run! cronSample
stop!!  2023-04-29T04:41:19.001Z
```

다시 start
```shell
$ curl --location --request POST 'http://localhost:3000/batches/start' | jq
```

```shell
start!!  2023-04-29T04:41:19.001Z
[Nest] 85673  - 04/29/2023, 1:41:43 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:44 PM    WARN [TaskService] run! cronSample
[Nest] 85673  - 04/29/2023, 1:41:45 PM    WARN [TaskService] run! cronSample
```

Interval 과 Timeout 역시 Cron 처럼 `SchedulerRegistry` 에서 제공하는 메서드를 이용하여 동적으로 제어할 수 있다.

---

CronJob 객체가 제공하는 메서드는 [Nestjs CronJob 객체가 제공하는 메서드: github](https://github.com/DefinitelyTyped/DefinitelyTyped/blob/master/types/cron/index.d.ts) 에서
확인 가능하여, 주요 메서드는 아래와 같다.

- `stop()`
  - 실행이 예약된 작업 중지
- `start()`
  - 중지된 작업 재시작
- `setTime(time: CronTime)`
  - 현재 작업을 중지하고 새로운 시간을 설정하여 재시작
- `lastDate()`
  - 작업이 마지막으로 실행된 날짜 반환
- `nextDates(count: number)`
  - 예정된 작업의 실행 시각은 count 갯수만큼 배열로 반환
  - 배열의 각 요소는 moment 객체

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [node-cron: github](https://github.com/kelektiv/node-cron)
* [표준 크론 패턴](http://crontab.org/)
* [NestJS 에서 제공하는 Cron Expression 열거](https://github.com/nestjs/schedule/blob/master/lib/enums/cron-expression.enum.ts)
* [moment Timezone](https://momentjs.com/timezone/)
* [Nestjs CronJob 객체가 제공하는 메서드: github](https://github.com/DefinitelyTyped/DefinitelyTyped/blob/master/types/cron/index.d.ts)