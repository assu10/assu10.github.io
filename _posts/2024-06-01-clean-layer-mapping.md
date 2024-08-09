---
layout: post
title:  "Clean Architecture - 경계 간 매핑 전략"
date: 2024-06-01
categories: dev
tags: clean 
---

지금까지 웹, 애플리케이션, 도메인, 영속성 계층이 있고, 하나의 유스케이스를 구현하기 위해 각 계층이 어떤 역할을 하는지에 대해 알아보았다.

이 포스트에서는 각 계층의 모델을 매핑하는 것에 대해 알아본다.

매퍼 구현에 대해 논의할 때 아마 아래와 같은 의견으로 진행이 되었을 것이다.
- 매핑 찬성
  - 계층 간 매핑을 하지 않으면 양 계층에서 같은 모델을 사용해야 하는데 그러면 두 계층이 강하게 결합됨
- 매핑 반대
  - 하지만 계층 간 매핑을 하게 되면 보일러 플레이트 (boilerplate) 코드가 너무 많아짐
  - 많은 유스케이스들이 오직 CRUD 만 수행하고 계층에 걸쳐 같은 모델을 사용하기 때문에 계층 사이의 매핑은 과함

위 의견 모두 일정 부분 맞다.

매핑 구현에 대한 결정에 도움이 되도록 몇 가지 매핑 전략에 대해 알아보자.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 매핑하지 않기(No Mapping) 전략](#1-매핑하지-않기no-mapping-전략)
* [2. 양방향 매핑(Two-Way Mapping) 전략](#2-양방향-매핑two-way-mapping-전략)
* [3. 완전 매핑(Full Mapping) 전략](#3-완전-매핑full-mapping-전략)
* [4. 단방향 매핑(One-Way Mapping) 전략](#4-단방향-매핑one-way-mapping-전략)
* [5. 언제 어떤 매핑 전략을 사용할지?](#5-언제-어떤-매핑-전략을-사용할지)
* [정리하며...](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

build.gradle
```groovy
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.3.2'
  id 'io.spring.dependency-management' version '1.1.6'
}

group = 'com.assu.study'
version = '0.0.1-SNAPSHOT'

java {
  toolchain {
    languageVersion = JavaLanguageVersion.of(17)
  }
}

compileJava {
  sourceCompatibility = 17
  targetCompatibility = 17
}

repositories {
  mavenCentral()
}

dependencies {
  compileOnly 'org.projectlombok:lombok'
  annotationProcessor 'org.projectlombok:lombok'

  implementation('org.springframework.boot:spring-boot-starter-web')
  implementation 'org.springframework.boot:spring-boot-starter-validation'
  implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
  implementation 'com.mysql:mysql-connector-j:9.0.0'

  testImplementation('org.springframework.boot:spring-boot-starter-test') {
    exclude group: 'junit' // excluding junit 4
  }
  implementation 'com.tngtech.archunit:archunit:1.3.0'

  //testImplementation 'com.h2database:h2:2.3.230'
}

test {
  useJUnitPlatform()
}
```

---

# 1. 매핑하지 않기(No Mapping) 전략

아래는 송금하기 유스케이스와 관련된 요소들이다.

패키지 구조
```shell
.
└── cleanme
    ├── account
    │   ├── adapter
    │   │   ├── in
    │   │   │   └── web
    │   │   │       └── SendMoneyController.java
    │   │   └── out
    │   │       └── persistence
    │   │           ├── AccountPersistenceAdapter.java
    │   ├── application
    │   │   ├── port
    │   │   │   ├── in
    │   │   │   │   └── SendMoneyUseCase.java
    │   │   │   └── out
    │   │   │       └── UpdateAccountStatePort.java
    │   │   └── service
    │   │       ├── SendMoneyService.java
    │   └── domain
    │       ├── Account.java
```

![매핑하지 않기 전략](/assets/img/dev/2024/0601/nomapping.png)

포트 인터페이스가 도메인 모델을 입출력 모델로 사용하면 두 계층 간에 매핑을 할 필요가 없어진다.

위 그림을 보면 웹 계층에서는 웹 컨트롤러가 _SendMoneyUseCase_ 인터페이스를 호출하여 유스케이스를 실행하고, 이 인터페이스는 _Account_ 객체를 인자로 가진다.  
즉, 웹 계층과 애플리케이션 계층 모두 _Account_ 클래스에 접근(= 두 계층이 같은 모델을 사용) 하는 것을 의미한다.

영속성 계층과 애플리케이션 계층도 같은 관계이다.

모든 계층이 같은 모델을 사용하니 계층 간 매핑을 전혀 할 필요가 없다.

웹 계층과 영속성 계층은 모델에 대해 특별한 요구사항이 있을 수 있다.  
예를 들어 웹 계층에서 REST 로 모델을 노출시켰다면 모델을 JSON 으로 직렬화하기 위한 애너테이션을 모델 클래스 필드에 붙여야할 수도 있고, 영속성 계층에서도 ORM 프레임워크를 
사용한다면 데이터베이스 매핑을 위한 특정 애너테이션이 필요할 것이다.

도메인과 애플리케이션 계층은 웹이나 영속성 계층과 관련된 요구사항에 관심이 없음에도 불구하고 _Account_ 도메인 모델 클래스는 이런 모든 요구사항들을 다루어야 한다.  
이는 **_Account_ 클래스는 웹, 애플리케이션, 영속성 계층과 관련된 이유로 인해 변경되어야 하기 때문에 단일 책임 원칙을 위반**한다.

> 단일 책임 원칙에 대한 내용은 [1. 단일 책임 원칙 (SRP, Single Responsibility Principle)](https://assu10.github.io/dev/2024/05/11/clean-dependency-inversion/#1-%EB%8B%A8%EC%9D%BC-%EC%B1%85%EC%9E%84-%EC%9B%90%EC%B9%99-srp-single-responsibility-principle) 을 참고하세요.

그렇다면 매핑하지 않기 전략을 절대로 사용하면 안되는 것일까? 하면 또 그런 아니다.

간단한 CRUD 유스케이스를 생각해보면 같은 필드를 가진 웹 모델을 도메인 모델로, 혹은 도메인 모델을 영속성 모델로 매핑할 필요가 있을까?  
도메인 모델에 추가한 JSON 이나 ORM 애너테이션을 한 두 개 바꿔야 한다고 하더라도 그게 큰 영향을 미칠까?

모든 계층이 정확히 같은 구조와 같은 정보를 필요로 한다면 매핑하지 않기 전략은 적절한 선택이다.

시간이 지남에 따라 많은 유스케이스들이 간단한 CRUD 유스케이스로 시작했다가 값비싼 매핑 전략이 필요한, 풍부한 행동과 유효성 검즈을 가진 제대로 된 비즈니스 유스케이스로 
바뀔 가능성이 높다.

즉, 어떤 매핑 전략을 선택했더라도 나중에 언제든 바꿀 수 있다.

---

# 2. 양방향 매핑(Two-Way Mapping) 전략

**양방향 매핑 전략은 *각 계층*이 전용 모델을 가진다**.  (웹 계층은 웹 모델, 애플리케이션 계층은 도메인 모델, 영속성 계층은 영속성 모델)

패키지 구조
```shell
.
└── cleanme
    ├── account
    │   ├── adapter
    │   │   ├── in
    │   │   │   └── web
    │   │   │       └── SendMoneyController.java
    │   │   └── out
    │   │       └── persistence
    │   │           ├── AccountJpaEntity.java
    │   │           ├── AccountPersistenceAdapter.java
    │   │           ├── AccountRepository.java
    │   ├── application
    │   │   ├── port
    │   │   │   ├── in
    │   │   │   │   └── SendMoneyUseCase.java
    │   │   │   └── out
    │   │   │       └── UpdateAccountStatePort.java
    │   │   └── service
    │   │       ├── SendMoneyService.java
    │   └── domain
    │       ├── Account.java
```

![양방향 매핑 전략](/assets/img/dev/2024/0601/twoway_mapping.png)

양방향 매핑 전략에서는 각 어댑터가 전용 모델을 갖고 있어서 해당 모델을 도메인 모델로, 도메인 모델을 해당 모델로 매핑할 책임이 있다.

즉, **각 계층은 도메인 모델과는 완전히 다른 구조의 전용 모델**을 갖고 있다.

웹 계층에서는 웹 모델을 인커밍 포트에서 필요한 도메인 모델로 매핑하고, 인커밍 포트에 의해 반환된 도메인 객체를 다시 웹 모델로 매핑한다.

두 계층 모두 양방향으로 매핑하기 때문에 양방향 매핑이라고 부른다.

<**양방향 매핑 전략의 장점**>  
- **웹이나 영속성 관심사 때문에 오염되지 않은 깨끗한 도메인 모델 유지 가능**
  - 도메인 모델에 JSON 이나 ORM 매핑 애너테이션이 없어도 됨 (= 단일 책임 원칙을 따름)
  - 각 계층이 전용 모델을 변경하더라도 다른 계층에는 영향이 없음
- **각 전용 모델은 최적화된 구조를 가질 수 있음**
  - 웹 모델은 데이터를 최적으로 표현할 수 있는 구조
  - 도메인 모델은 유스케이스를 제일 잘 구현할 수 있는 구조
  - 영속성 모델은 DB 에 객체를 저장하기 위해 ORM 에서 필요로 하는 구조
- **개념적으로 매핑하지 않기 전략 다음으로 간단한 전략임**
  - 매핑 책임이 명확함
  - 즉 바깥쪽 계층/어댑터는 안쪽 계층의 모델로 매핑하고, 다시 반대 방향으로 매핑함
  - 안쪽 계층은 해당 계층의 모델만 알면 되고 매핑 대신 도메인 로직에 집중

<**양방향 매핑 전략의 단점**>  
- **너무 많은 보일러 플레이트 (boilerplate) 코드가 발생함**
  - 코드의 양을 줄이기 위해 매핑 프레임워크를 사용하더라도 두 모델 간 매핑을 구현하는데 시간이 소요됨
  - 매핑 프레임워크가 내부 동작 방식을 제네릭 코드와 리플렉션 뒤로 숨길 경우 매핑 로직을 디버깅하는데 어려움이 있음
- **도메인 모델이 계층 경계를 넘어서 통신하는데 사용되고 있음**
  - 인커밍 포트와 아웃고잉 포트는 도메인 객체를 입력 파라메터와 반환값으로 사용함
  - 도메인 모델은 도메인 모델의 필요에 의해서만 변경되는 것이 이상적인데 바깥쪽 계층의 요구에 따른 변경에 취약해짐

양방향 매핑 전략도 은총알 (silver bullet) 은 아니다.  
하지만 많은 프로젝트에서 이런 종류의 매핑은 아주 간단한 CRUD 유스케이스에서 조차 전체 코드에 걸쳐 준수해야 하는 법칙처럼 여겨지곤 하고, 이는 개발을 불필요하게 더디게 만든다.

매핑 전략을 철칙처럼 여기지 말고 각 유스케이스마다 적절한 전략을 택해야 한다.

> **은총알 (silver bullet)**  
> 
> 어떤 엔지니어링 상황에서도 완벽하게 잘 들어맞는 해결책을 의미함

---

# 3. 완전 매핑(Full Mapping) 전략

**완전 매핑 전략은 *각 연산*마다 별도의 입출력 모델을 사용**한다.

패키지 구조
```shell
.
└── cleanme
    ├── account
    │   ├── adapter
    │   │   ├── in
    │   │   │   └── web
    │   │   │       └── SendMoneyController.java
    │   │   └── out
    │   │       └── persistence
    │   │           ├── AccountJpaEntity.java
    │   │           ├── AccountMapper.java
    │   │           ├── AccountPersistenceAdapter.java
    │   ├── application
    │   │   ├── port
    │   │   │   ├── in
    │   │   │   │   ├── SendMoneyCommand.java
    │   │   │   │   └── SendMoneyUseCase.java
    │   │   │   └── out
    │   │   │       └── UpdateAccountStatePort.java
    │   │   └── service
    │   │       ├── SendMoneyService.java
    │   └── domain
    │       ├── Account.java
```

![풀 매핑 전략](/assets/img/dev/2024/0601/full_mapping.png)

위 그림을 보면 각 연산이 전용 모델을 필요로 하기 때문에 웹 어댑터와 애플리케이션 계층 각각이 자신의 전용 모델을 각 연산 실행 시 필요한 모델로 매핑한다.

계층 경계를 넘어 통신할 때 도메인 모델을 사용하는 대신 _SendMoneyUseCase_ 포트의 입력 모델로 동작하는 _SendMoneyCommand_ 처럼 각 작업에 특화된 모델을 사용한다.  
이런 모델을 보통 Command, Request 와 같은 단어로 표현한다.

웹 계층은 입력을 애플리케이션 계층의 커맨드 객체로 매핑할 책임이 있다.  
커맨드 객체는 애플리케이션 계층의 인터페이스를 해석할 여지없이 명확하게 만들어준다.  
각 유스케이스는 전용 필드와 유효성 검증 로직을 가진 전용 커맨드를 가진다.

애플리케이션 계층은 커맨드 객체를 유스케이스에 따라 도메인 모델로 변경하기 위해 필요한 무엇인가로 매핑할 책임이 있다.

한 계층을 다른 여러 개의 커맨드로 매핑하는 데에는 하나의 웹 모델과 도메인 모델 간의 매핑보다 더 많은 코드가 필요하다.  
하지만 **이렇게 매핑하면 여러 유스케이스의 요구 사항을 함께 다뤄야하는 매핑에 비해 구현과 유지보수가 훨씬 쉽다.**

**풀 매핑 전략을 전역 패턴으로는 권장하지는 않는다.**

**풀 매핑 전략은 웹 계층 (혹은 인커밍 어댑터 종류 중 아무거나) 과 애플리케이션 계층 사이에 상태 변경 유스케이스의 경계를 명확하게 할 때 가장 유용**하다.  
**애플리케이션 계층과 영속성 계층 사이에서는 매핑 오버 헤드 때문에 사용하지 않는 것이 좋다.**

**어떤 경우에는 연산의 입력 모델에 대해서만 풀 매핑 전략을 사용하고, 도메인 객체를 그대로 출력 모델로 사용**하는 것도 좋다.  
_SendMoneyUseCase_ 가 업데이트된 잔고를 가진 채로 _Account_ 객체를 그대로 반환하는 것처럼 말이다.

이렇게 매핑 전략은 여러 가지를 섞어서 사용하는 것이 좋다.  
어떤 매핑 전략도 모든 계층에 걸쳐 전역 규칙으로 사용할 필요는 없다.

---

# 4. 단방향 매핑(One-Way Mapping) 전략

패키지 구조
```shell
.
└── cleanme
    ├── account
    │   ├── adapter
    │   │   ├── in
    │   │   │   └── web
    │   │   │       └── SendMoneyController.java
    │   │   └── out
    │   │       └── persistence
    │   │           ├── AccountJpaEntity.java
    │   │           ├── AccountMapper.java
    │   │           ├── AccountPersistenceAdapter.java
    │   ├── application
    │   │   ├── port
    │   │   │   ├── in
    │   │   │   │   └── SendMoneyUseCase.java
    │   │   │   └── out
    │   │   │       └── UpdateAccountStatePort.java
    │   │   └── service
    │   │       ├── SendMoneyService.java
    │   └── domain
    │       ├── Account.java
```

![단방향 매핑 전략](/assets/img/dev/2024/0601/onewya_mapping.png)

위 그림을 보면 동일한 상태 인터페이스를 구현하는 도메인 모델과 어댑터 모델을 이용하면 각 계층은 다른 계층으로부터 온 객체를 단방향으로 매핑하기만 하면 된다.

**단방향 매핑 전략에서는 모든 계층의 모델들이 같은 인터페이스를 구현**한다.  
이 인터페이스는 관련있는 attribute 에 대한 getter 메서드를 제공해서 도메인 모델의 상태를 캡슐화한다.

도메인 모델 자체는 풍부한 행동을 구현할 수 있고, 애플리케이션 계층 내의 서비스에서 이러한 행동에 접근할 수 있다.

**도메인 객체가 인커밍/아웃고잉 포트가 기대하는 대로 상태 인터페이스를 구현하고 있으므로 도메인 객체를 바깥 계층으로 전달할 때 별도의 매핑없이 할 수 있다.**

바깥 계층에서는 상태 인터페이스를 이용할지 전용 모델로 매핑해야 할지 결정할 수 있다.  
행동을 변경하는 것이 상태 인터페이스에 의해 노출되어 있지 않기 때문에 실수로 도메인 객체의 상태를 변경하는 일은 발생하지 ㅇ낳는다.

바깥 계층에서 애플리케이션 계층으로 전달하는 객체들도 이 상태 인터페이스를 구현한다.  
**애플리케이션 계층에서는 이 객체를 실제 도메인 모델로 매핑해서 도메인 모델의 행동에 접근**할 수 있다.  
이 매핑은 factory 라는 DDD 개념과 잘 어울린다.  
**factory 는 어떤 특정한 상태로부터 도메인 객체를 재구성할 책임**을 갖는다.

단방향 매핑에서 매핑 책임은 명확하다.

**한 계층이 다른 계층으로부터 객체를 받으면 해당 계층에서 이용할 수 있도록 다른 무언가로 매핑**한다.  
**따라서 각 계층은 한 방향으로만 매핑**한다.

**하지만 매핑이 계층을 넘나들며 퍼져 있기 때문에 단방향 매핑 전략은 다른 전략에 비해 개념적으로 어렵다.**

**단방향 매핑 전략은 계층 간의 모델이 비슷할 때 효과적**이다.  
예를 들어 읽기 전용 연산의 경우 필요한 모든 정보를 상태 인터페이스가 제공하기 때문에 웹 계층에서 전용 모델로 매핑할 필요가 전혀 없다.

---

# 5. 언제 어떤 매핑 전략을 사용할지?

각 매핑 전략이 장단점을 갖고 있기 때문에 **하나의 전략을 전체 코드에 대한 어떤 경우에도 변하지 않는 전역 규칙으로 정의하는 것은 좋지 않다.**  
특정 작업에 최선의 패턴이 아님에도 불구하고 깔끔하게 느껴진다는 이유로 선택하는 것은 무책임하다.

언제 어떤 전략을 사용할 지 결정하려면 팀 내의 가이드라인을 정해두어야 한다.

예를 들어 변경 유스케이스와 쿼리 유스케이스에 서로 다른 매핑 매핑 전략, 웹 계층과 애플리케이션 계층 사이에서 사용할 매핑 전략과 애플리케이션 계층과 영속성 계층 사이에서 사용할 
매핑 전략을 다르게 세웠다고 가정하면 아마 가이드라인은 아래와 같을 것이다.

- **변경 유스케이스**
  - **웹 계층과 애플리케이션 계층 간**
    - 유스케이스 간의 결합을 제거하기 위해 **완전 매핑 전략**을 첫 번째 선택지로 택함
    - 그러면 유스케이스별 유효성 검증 규칙이 명확해지고 특정 유스케이스에서 필요하지 않은 필드를 다루지 않아도 됨
  - **애플리케이션 계층과 영속성 계층 간**
    - 매핑 오버헤드를 줄이고 빠르게 코드를 짜기 위해 **매핑하지 않기 전략**을 첫 번째 선택지로 택함
    - 단, 애플리케이션 계층에서 영속성 문제를 다뤄야 한다면 **양방향 매핑 전략**으로 바꿔서 영속성 문제를 영속성 계층에 가둠
- **쿼리 유스케이스**
  - **웹 계층과 애플리케이션 계층 간, 애플리케이션 계층과 영속성 계층 간**
    - 매핑 오버헤드를 줄이고 빠르게 코드를 짜기 위해 **매핑하지 않기 전략**을 첫 번째 선택지로 택함
    - 단, 애플리케이션 계층에서 영속성 문제가 웹 문제를 다뤄야한다면 웹 계층과 애플리케이션 계층, 애플리케이션 계층과 영속성 계층 간 매핑을 각각 **양방향 매핑 전략**으로 바꿈

---

# 정리하며...

계층 간 동작하는 인커밍 포트와 아웃고잉 포트는 서로 다른 계층이 어떻게 통신해야 하는지 정의한다.  
여기에는 계층 간 매핑을 수행할지 여부와 어떤 매핑 전략을 선택할지가 포함된다.

각 유스케이스에 대해 좁은 포트를 사용하면 유스케이스마다 다른 매핑 전략을 사용할 수 있고, 다른 유스케이스에 영향을 미치지 않으면서 코드를 개선할 수 있기 때문에 
특정 상황, 특정 시점에 최선의 전략을 선택할 수 있다.

상황별로 매핑 전략을 선택하는 것은 모든 상황에 같은 매핑 전략을 사용하는 것보다 분명 더 어렵고 많은 커뮤니케이션을 필요로 하겠지만 매핑 가이드라인이 잇는 한 코드가 정확히 
해야 하는 일만 수행하면서도 유지보수하기 쉬운 코드가 된다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)
* [은총알은 없다. (No Silver Bullet)](https://johngrib.github.io/wiki/No-Silver-Bullet/)