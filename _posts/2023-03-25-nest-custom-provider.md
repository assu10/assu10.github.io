---
layout: post
title:  "NestJS - Custom Provider"
date:   2023-03-25
categories: dev
tags: nestjs provider custom-provider
---

이 포스팅은 NestJS 의 Custom Provider 에 대해 알아본다.

- [ValueProvider](#1-valueprovider)
- [ClassProvider](#2-classprovider)
- [FactoryProvider](#3-factoryprovider)
- [ExistingProvider (AliasedProvider)](#4-existingprovider-aliasedprovider)
- [Provider 내보내기](#5-provider-내보내기)

---

[NestJS - Provider, Scope](https://assu10.github.io/dev/2023/03/03/nest-provider/) 의
*1.2. Provider 사용 (속성 기반 주입): `@Inject`* 에서 `@Inject` 데커레이커의 인수는 타입(클래스명), 문자열, 심벌이 올 수 있다고 하였다.

이 포스트에선 `@Inject` 데커레이터의 인수로 문자열과 심벌이 오는 경우에 대해 알아본다.

[NestJS - Provider, Scope](https://assu10.github.io/dev/2023/03/03/nest-provider/) 에서 Provider 를 모듈에 등록할 때
아래와 같이 클래스 이름을 그대로 사용했다.

app.module.ts
```ts
@Module({
  controllers: [UsersController],
  providers: [UsersService],
})
export class AppModule {}
```

위처럼 등록하는 것이 일반적이지만 위처럼 사용하지 못하는 경우가 있다.

- 라이브러리에 선언된 클래스를 가져오는 경우
- 테스트를 위해 mock 객체 버전으로 Provider 를 재정의 하려는 경우
- NestJS 프레임워크가 생성하는 인스턴스 대신 직접 인스턴스를 생성하고 싶은 경우
- 여러 클래스가 의존 관계에 있을 때 이미 존재하는 클래스를 재사용하고자 하는 경우

> 테스트를 위해 mock 객체 버전으로 Provider 를 재정의 하려는 경우에 대해서는 [NestJS - 테스트 자동화](https://assu10.github.io/dev/2023/04/30/nest-test/) 를 참고해주세요.

`@Module` 데커레이터 인수의 타입은 `ModuleMetadata` 이다. 

`@Module` 데커레이터 시그니처
```ts
export declare function Module(metadata: ModuleMetadata): ClassDecorator;
```

`ModuleMetadata` 시그니처
```ts
export interface ModuleMetadata {
    /**
     * Optional list of imported modules that export the providers which are
     * required in this module.
     */
    imports?: Array<Type<any> | DynamicModule | Promise<DynamicModule> | ForwardReference>;
    /**
     * Optional list of controllers defined in this module which have to be
     * instantiated.
     */
    controllers?: Type<any>[];
    /**
     * Optional list of providers that will be instantiated by the Nest injector
     * and that may be shared at least across this module.
     */
    providers?: Provider[];
    /**
     * Optional list of the subset of providers that are provided by this module
     * and should be available in other modules which import this module.
     */
    exports?: Array<DynamicModule | Promise<DynamicModule> | string | symbol | Provider | ForwardReference | Abstract<any> | Function>;
}
```

`Provider` 시그니처
```ts
// Type 으로 받을 수 있도록 되어 있기 때문에 클래스 이름을 그대로 사용할 수 있음
export type Provider<T = any> = Type<any> | ClassProvider<T> | ValueProvider<T> | FactoryProvider<T> | ExistingProvider<T>;
/**
 * Interface defining a *Class* type provider.
 *
 * For example:
 * 
 * const configServiceProvider = {
 * provide: ConfigService,
 * useClass:
 *   process.env.NODE_ENV === 'development'
 *     ? DevelopmentConfigService
 *     : ProductionConfigService,
 * };
 * 
*
* @see [Class providers](https://docs.nestjs.com/fundamentals/custom-providers#class-providers-useclass)
* @see [Injection scopes](https://docs.nestjs.com/fundamentals/injection-scopes)
*
* @publicApi
*/
export interface ClassProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Type (class name) of provider (instance to be injected).
  */
  useClass: Type<T>;
  /**
* Optional enum defining lifetime of the provider that is injected.
  */
  scope?: Scope;
  /**
* This option is only available on factory providers!
*
* @see [Use factory](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
  */
  inject?: never;
  /**
* Flags provider as durable. This flag can be used in combination with custom context id
* factory strategy to construct lazy DI subtrees.
*
* This flag can be used only in conjunction with scope = Scope.REQUEST.
  */
  durable?: boolean;
}

/**
* Interface defining a *Value* type provider.
*
* For example:
* 
* const connectionProvider = {
*   provide: 'CONNECTION',
*   useValue: connection,
* };
* 
*
* @see [Value providers](https://docs.nestjs.com/fundamentals/custom-providers#value-providers-usevalue)
*
* @publicApi
*/
export interface ValueProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Instance of a provider to be injected.
  */
  useValue: T;
  /**
* This option is only available on factory providers!
*
* @see [Use factory](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
  */
  inject?: never;
}

/**
* Interface defining a *Factory* type provider.
*
* For example:
* 
* const connectionFactory = {
*   provide: 'CONNECTION',
*   useFactory: (optionsProvider: OptionsProvider) => {
*     const options = optionsProvider.get();
*     return new DatabaseConnection(options);
*   },
*   inject: [OptionsProvider],
* };
* 
*
* @see [Factory providers](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
* @see [Injection scopes](https://docs.nestjs.com/fundamentals/injection-scopes)
*
* @publicApi
*/
export interface FactoryProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Factory function that returns an instance of the provider to be injected.
  */
  useFactory: (...args: any[]) => T | Promise<T>;
  /**
* Optional list of providers to be injected into the context of the Factory function.
  */
  inject?: Array<InjectionToken | OptionalFactoryDependency>;
  /**
* Optional enum defining lifetime of the provider that is returned by the Factory function.
  */
  scope?: Scope;
  /**
* Flags provider as durable. This flag can be used in combination with custom context id
* factory strategy to construct lazy DI subtrees.
*
* This flag can be used only in conjunction with scope = Scope.REQUEST.
  */
  durable?: boolean;
}
  
/**
* Interface defining an *Existing* (aliased) type provider.
*
* For example:
* 
* const loggerAliasProvider = {
*   provide: 'AliasedLoggerService',
*   useExisting: LoggerService
* };
* 
*
* @see [Alias providers](https://docs.nestjs.com/fundamentals/custom-providers#alias-providers-useexisting)
*
* @publicApi
*/
export interface ExistingProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Provider to be aliased by the Injection token.
  */
  useExisting: any;
}
```

그럼 이제 각 Provider 에 대해 살펴보자. 
```ts
export type Provider<T = any> = Type<any> | ClassProvider<T> | ValueProvider<T> | FactoryProvider<T> | ExistingProvider<T>;
```

---

# 1. ValueProvider

```ts
/**
 * Interface defining a *Value* type provider.
 *
 * For example:
 * 
 * const connectionProvider = {
 *   provide: 'CONNECTION',
 *   useValue: connection,
 * };
 * 
*
* @see [Value providers](https://docs.nestjs.com/fundamentals/custom-providers#value-providers-usevalue)
*
* @publicApi
*/
export interface ValueProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Instance of a provider to be injected.
  */
  useValue: T;
  /**
* This option is only available on factory providers!
*
* @see [Use factory](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
  */
  inject?: never;
}
```

`ValueProvider` 는 `provide` 와 `useValue` 속성을 갖는데 `useValue` 는 어떤 타입도 받을 수 있기 때문에 `useValue` 를 이용하여
외부 라이브러리에서 Provider 를 사입하거나 실제 구현을 mock 객체로 대체할 수 있다.  
(`inject` 는 factory provider 에서만 사용됨)

예를 들어 모의 값을 테스트하려고 한다고 해보자.

```ts
// mock object
const mockCatsService = {
    // 테스트에 적용할 값 변경
};

@Module({
    imports: [CatsModule],
    providers: [
        {   // CatsService 를 Provider 로 지정하지만 실제 값은 mockCatsService 를 사용한다는 의미
            provide: CatsService,
            useValue: mockCatsService,  // provide 에 선언된 클래스와 동일한 인터페이스를 가진 리터럴 객체 혹은 new 로 생성한 인스턴스 사용해야 함
        }
    ]
});
export class AppModule {}
```

`provide` 는 `InjectionToken` 타입이고, `InjectionToken` 의 시그니처는 아래와 같다.
```ts
export type InjectionToken = string | symbol | Type<any> | Abstract<any> | Function;
```

위의 예시에서는 `provide` 의 타입을 `Type<any>` 로 하여 CatsService 를 사용한 것이다.  
즉, **CatsService 를 Provider 로 지정하지만 실제 값은 mockCatsService 를 사용한다는 의미**이다.

`useValue` 에는 `provide` 에 선언된 클래스와 동일한 인터페이스를 가진 리터럴 객체 혹은 new 로 생성한 인스턴스를 사용해야 한다.

`provide` 속성은 `InjectionToken` 이고, InjectionToken 은 **클래스 이름, 문자열, 심벌, Abstract, Function 인터페이스**를 사용할 수 있다.

예를 들어 CatsRepository 에서 DB 연결 시 Connection 객체를 Provider 로 제공한다고 할 때 provider 의 값을 문자열로 설정할 수 있다.

```ts
import { connection } from './connection';

@Module({
    providers: [
        {
            provide: 'CONNECTION',  // 토큰으로 'CONNECTION' 문자열 사용
            useValue: connection
        }
    ]
});
export class AppModule {}
```

그리고 위 Provider 를 가져다쓰는 CatsRepository 는 'CONNECTION' 문자열로 된 토큰으로 주입받을 수 있다.

```ts
@Injectable()
export class CatsRepository {
    constructor(@Inject('CONNECTION') connection: Connection) {
    }
}
```

> ValueProvider 의 좀 더 상세한 내용은 [Value providers](https://docs.nestjs.com/fundamentals/custom-providers#value-providers-usevalue) 를 참고하세요.

---

# 2. ClassProvider

```ts
/**
 * Interface defining a *Class* type provider.
 *
 * For example:
 * 
 * const configServiceProvider = {
 * provide: ConfigService,
 * useClass:
 *   process.env.NODE_ENV === 'development'
 *     ? DevelopmentConfigService
 *     : ProductionConfigService,
 * };
 * 
*
* @see [Class providers](https://docs.nestjs.com/fundamentals/custom-providers#class-providers-useclass)
* @see [Injection scopes](https://docs.nestjs.com/fundamentals/injection-scopes)
*
* @publicApi
*/
export interface ClassProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Type (class name) of provider (instance to be injected).
  */
  useClass: Type<T>;
  /**
* Optional enum defining lifetime of the provider that is injected.
  */
  scope?: Scope;
  /**
* This option is only available on factory providers!
*
* @see [Use factory](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
  */
  inject?: never;
  /**
* Flags provider as durable. This flag can be used in combination with custom context id
* factory strategy to construct lazy DI subtrees.
*
* This flag can be used only in conjunction with scope = Scope.REQUEST.
  */
  durable?: boolean;
}
```

`ClassProvider` 는 `provide` 와 `useClass` 속성을 사용한다.  
`ClassProvider` 를 사용하면 Provider 로 사용할 인스턴스를 동적으로 구성할 수 있다.

예를 들어 ConfigService 부모 클래스가 있고 이를 상속받은 DevConfigService 와 ProdConfigService 를 환경에 맞게 동적으로 구성할 수 있다.

```ts
const configServiceProvider = {
    provide: ConfigService,
    useClass: 
        process.env.NODE_ENV === 'dev' ? DevConfigService: ProdConfigService;
};

@Module({
    providers:[configServiceProvider]
});
export class AppModule {}
```

> [NestJS - 동적 모듈로 환경변수 구성](https://assu10.github.io/dev/2023/03/05/nest-env/) 의 *3. NestJS 의 Config Package (@nestjs/config 로 `ConfigModule` 을 동적으로 생성)* 와 같은 기능이다.

> ClassProvider 의 좀 더 상세한 내용은 [Class providers](https://docs.nestjs.com/fundamentals/custom-providers#class-providers-useclass) 를 참고하세요.

---

# 3. FactoryProvider

```ts
/**
 * Interface defining a *Factory* type provider.
 *
 * For example:
 * 
 * const connectionFactory = {
 *   provide: 'CONNECTION',
 *   useFactory: (optionsProvider: OptionsProvider) => {
 *     const options = optionsProvider.get();
 *     return new DatabaseConnection(options);
 *   },
 *   inject: [OptionsProvider],
 * };
 * 
*
* @see [Factory providers](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
* @see [Injection scopes](https://docs.nestjs.com/fundamentals/injection-scopes)
*
* @publicApi
*/
export interface FactoryProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Factory function that returns an instance of the provider to be injected.
  */
  useFactory: (...args: any[]) => T | Promise<T>;
  /**
* Optional list of providers to be injected into the context of the Factory function.
  */
  inject?: Array<InjectionToken | OptionalFactoryDependency>;
  /**
* Optional enum defining lifetime of the provider that is returned by the Factory function.
  */
  scope?: Scope;
  /**
* Flags provider as durable. This flag can be used in combination with custom context id
* factory strategy to construct lazy DI subtrees.
*
* This flag can be used only in conjunction with scope = Scope.REQUEST.
  */
  durable?: boolean;
}
```

`FactoryProvider` 는 `provide` 와 `useFactory` 속성을 사용한다.  
`FactoryProvider` 도 `ClassProvider` 처럼 Provider 로 사용할 인스턴스를 동적으로 구성하고자 할 때 사용한다.

`ClassProvider` 는 `useClass: Type<T>` 속성을 갖는 반면 `FactoryProvider` 는 타입이 함수로 정의되어 있다. 
```ts
useFactory: (...args: any[]) => T | Promise<T>;
```

원하는 인수와 리턴 타입으로 함수를 구성하면 된다.  
만일 함수를 수행하는 과정에서 다른 Provider 가 필요하면 주입받아서 사용할 수 있는데 주의할 점은 주입받을 Provider 를 `inject` 속성에 다시 선언해주어야 한다.

아래는 `CONNECTION` Provider 인스턴스를 생성하는 과정에서 `OptionsProvider` 가 필요한 경우이다.
```ts
const connectionFactory = {
    provide: 'CONNECTION',
    useFactory: (optionsProvider: OptionsProvider) => {
        const options = optionsProvider.get();
        return new DatabaseConnection(options);
    },
    inject: [OptionsProvider]
};

@Module({
    providers: [connectionFactory]
})
export class AppModule {}
```

> FactoryProvider 의 좀 더 상세한 내용은 [Factory Providers-usefactory](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory) 를 참고하세요.

---

# 4. ExistingProvider (AliasedProvider)

```ts
/**
 * Interface defining an *Existing* (aliased) type provider.
 *
 * For example:
 * 
 * const loggerAliasProvider = {
 *   provide: 'AliasedLoggerService',
 *   useExisting: LoggerService
 * };
 * 
*
* @see [Alias providers](https://docs.nestjs.com/fundamentals/custom-providers#alias-providers-useexisting)
*
* @publicApi
*/
export interface ExistingProvider<T = any> {
/**
* Injection token
  */
  provide: InjectionToken;
  /**
* Provider to be aliased by the Injection token.
  */
  useExisting: any;
}
```
`ExistingProvider` 는 Provider 에 별칭을 붙여 동일한 Provider 를 별칭으로 접근할 수 있도록 한다.  
`ExistingProvider` 는 `provide` 와 `useExisting` 속성을 사용한다.

```ts
@Injectable()
export class LoggerService {
    private getHello(): string {
        return 'hello';
    }
}
```

어떠한 이유로 LoggerService 를 사용할 수 없다고 할 때 (위에선 예를 들기 위해 private 로 getHello() 를 선언함) 아래와 같이 LoggerService 를 AliasedLoggerService 별칭으로
재정의한다.

```ts
const loggerAliasProvider = {
    provide: 'AliasedLoggerService',
    useExisting: LoggerService
};

@Module({
    providers: [LoggerService, loggerAliasProvider]
})
export class AppModule {}
```

위에서 `useExisting` 속성에 별칭 Provider 의 원본 Provider 를 지정하여 직접 접근할 수 없었던 LoggerService 를 사용한다고 선언한다. 
```ts
@Controller()
export class AppController {
    // 일반적으로 프로바이더를 주입받을 때 원본 프로바이더 타입으로 지정해주는 것이 좋지만 여기선 private 함수를 호출하려고 했기 때문에 any 타입으로 정의
    constructor(@Inject('AliasedLoggerService') private readonly serviceAlias: any) { }

    @Get('/alias')
    getHelloAlias(): string {
        return this.serviceAlias.getHello();
    }
}
```

이제 LoggerService 의 getHello() 를 활용할 수 있다.

> ExistingProvider 의 좀 더 상세한 내용은 [Alias providers-useexisting](https://docs.nestjs.com/fundamentals/custom-providers#alias-providers-useexisting) 를 참고하세요.

---

# 5. Provider 내보내기

다른 모듈에 있는 Provider 를 가져다 쓰려면 해당 모듈에서 export 를 해줘야하듯이 Custom Provider 도 동일하다.

내보내기 토큰을 사용할 수도 있고, Provider 객체를 사용할 수도 있다.

```ts
const connectionFactory = {
    provide: 'CONNECTION',
    useFactory: (optionsProvider: OptionsProvider) => {
        const options = optionsProvider.get();
        return new DatabaseConnection(options);
    },
    inject: [OptionsProvider]
};
```

내보내기 토큰을 사용하여 Provider 내보내기 (='CONNECTION' 토큰 사용)
```ts
@Module({
    providers: [connectionFactory],
    exports: ['CONNECTION']
})
export class AppModule {}
```

Provider 객체를 사용하여 Provider 내보내기 (=connectionFactory 객체를 그대로 내보내는 경우)
```ts
@Module({
    providers: [connectionFactory],
    exports: ['connectionFactory']
})
export class AppModule {}
```

> [NestJS - Module 설계](https://assu10.github.io/dev/2023/03/04/nest-module/) 의 *1.1. Module 다시 내보내기* 와 비교해서 보세요.

---


## 참고 사이트 & 함께 보면 좋은 사이트

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [NestJS 공식문서](https://nestjs.com/)
* [NestJS docs](https://docs.nestjs.com/)
* [Nest.js Github](https://github.com/nestjs/nest)
* [NestJS 공식 예제 Starter 프로젝트 Github](https://github.com/nestjs/typescript-starter)
* [Value providers](https://docs.nestjs.com/fundamentals/custom-providers#value-providers-usevalue)
* [Class providers](https://docs.nestjs.com/fundamentals/custom-providers#class-providers-useclass)
* [Injection scopes](https://docs.nestjs.com/fundamentals/injection-scopes)
* [Factory Providers-usefactory](https://docs.nestjs.com/fundamentals/custom-providers#factory-providers-usefactory)
* [Alias providers-useexisting](https://docs.nestjs.com/fundamentals/custom-providers#alias-providers-useexisting)