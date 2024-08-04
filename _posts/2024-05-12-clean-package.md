---
layout: post
title:  "Clean Architecture - 패키징 구성"
date: 2024-05-12
categories: dev
tags: clean 
---

프로젝트를 진행하다보면 점점 바빠져서 패키지 구조가 엉망이 되는 경우가 있다.  
한 패키지에 있는 클래스들이 import 하지 말아야 할 다른 패키지에 있는 클래스들을 불러오기도 한다.

이 포스트에서는 '송금하기' 유스케이스를 예시로 표현력있는 패키지 구조에 대해 알아본다.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 계층으로 패키지 구성](#1-계층으로-패키지-구성)
* [2. 기능으로 패키지 구성](#2-기능으로-패키지-구성)
* [3. 아키텍처적으로 표현력있는 패키지 구조](#3-아키텍처적으로-표현력있는-패키지-구조)
* [4. 의존성 주입 (DI, Dependency Injection) 의 역할](#4-의존성-주입-di-dependency-injection-의-역할)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 계층으로 패키지 구성

> 추천하지 않는 패키징 구조 방식이므로 참고만 할 것

아래와 같이 웹 계층, 도메인 계층, 영속성 계층 각각에 대한 전용 패키지는 web, domain, persistence 패키지를 구성할 수 있다.

```shell
.
└── buckpal
    ├── domain
    │   ├── Account
    │   ├── AccountRepository
    │   └── AccountService
    ├── persistence
    │   └── AccountRepositoryImpl
    └── web
        └── AccountController
```

위 구조에서 domain 패키지에 _AccountRepository_ 인터페이스를 추가하고, persistence 패키지에  _AccountRepositoryImpl_ 구현체를 둠으로써 
의존성을 역전시켰다.

하지만 아래와 같은 이유로 **위 패키지 구조는 최적의 구조가 아니다.**

- **애플리케이션의 기능이나 특성을 구분짓는 패키지 경계가 없음**
  - 만일 사용자를 관리하는 기능을 추가해야 한다면 web 패키지에 _UserController_ 를 추가하고, domain 패키지에 _UserService_, _UserRepository_, _User_ 를 추가하고, persistence 패키지에 _UserRepositoryImpl_ 을 추가해야 함
  - 서로 연관되지 않은 기능들끼리 예상치못한 부수효과를 일으킬 수 있는 클래스들이 모이게 됨
- **애플리케이션이 어떤 유스케이스를 제공하지는지 알 수 없음**
  - _AccountService_, _AccountController_ 가 어떤 유스케이스를 구현했는지 파악하기 어려움
  - 특정 기능을 찾기 위해 어떤 서비스가 해당 기능을 구현했는지 직접 찾아야 함
- **패키지 구조를 통해 아키텍처를 파악할 수 없음**
  - 어떤 기능이 웹 어댑터에서 호출되고 영속성 어댑터가 도메인 계층에 어떤 기능을 제공하는지 한 눈에 파악하기 어려움
  - 인커밍 (incoming) 포트와 아웃고잉 (outgoing) 포트가 코드 속에 숨겨져 있음

> **인커밍 (incoming) 포트, 아웃고잉 (outgoing) 포트**  
> 
> 인커밍 포트: 외부로부터 값을 전달받는 포트  
> 아웃고밍 포트: 외부로 값을 내보내는 포트

---

# 2. 기능으로 패키지 구성

> 추천하지 않는 패키징 구조 방식이므로 참고만 할 것

아래는 기능으로 구성된 패키지의 구조이다.

```shell
.
└── buckpal
    └── account
        ├── Account
        ├── AccountController
        ├── AccountRepository
        ├── AccountRepositoryImpl
        └── SendMoneyService
```

계좌와 관련된 모든 코드를 최상위의 account 패키지에 넣었고, 계층 패키지들을 제거하였다.

각 기능을 묶은 새로운 그룹은 account 와 같은 레벨의 새로운 패키지로 들어가고, 패키지 외부에서 접근하면 안되는 클래스들에 대해서는 `package-private` 접근 수준을 이용하여 
패키지 간의 경계를 강화할 수 있다.

**패키지 경계를 `package-private` 접근 수준과 결합하면 각 기능 사이의 불필요한 의존성을 제거**할 수 있다.

> **자바의 접근 수준**  
> 
> - `public`
>   - 다른 패키지에서 모두 접근 가능
> - `protected`
>   - 다른 패키지에서 접근 불가
>   - 단, 상속을 한다면 (child class) 는 접근 가능
> - `package-private` (default)
>   - 상속을 해도 다른 패키지에서 접근 불가
> - `private`
>   - 해당 클래스 내부에서만 접근 가능

또한 _AccountService_ 의 책임을 좁히기 위해 `SendMoneyService` 로 클래스명을 변경하였다.

이제 '송금하기' 유스케이스를 구현한 코드는 클래스명만으로도 찾을 수 있게 되었다.

하지만 **기능에 의한 패키징 방식은 계층에 의한 패키징 방식보다 아키텍처의 가시성을 더 떨어뜨린다.**

- **어댑터를 나타내는 패키지명이 없음**
- **인커밍 포트, 아웃고잉 포트를 확인할 수 없음**
- 도메인 코드와 영속성 코드 간의 의존성을 역전시켜서 _SendMoneyService_ 가 _AccountRepository_ 인터페이스만 알고 구현체는 알 수 없도록 했음에도 불구하고 **`package-private` 접근 수준을 이용하여 도메인 코드가 실수로 영속성 코드에 의존하는 것을 막을 수 없음**

아래와 같은 아키텍처 다이어그램에서 특정 박스를 가리켰을 때 코드의 어떤 부분이 해당 박스를 책임지는지 바로 알 수 있다면 좋을 것이다.

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

# 3. 아키텍처적으로 표현력있는 패키지 구조

육각형 아키텍처에서의 핵심 요소는 아래와 같다.

- 엔티티
- 유스케이스
- 인커밍/아웃고잉 포트
- 인커밍/아웃고잉 (or Driving/Driven) 어댑터

아래 구조는 위 요소들을 애플리케이션의 아키텍처로 표현하는 패키지 구조이다.

```shell
.
└── buckpal
    └── account
        ├── adapter
        │   ├── in
        │   │   └── web
        │   │       └── AccountController
        │   └── out
        │       └── persistence
        │           ├── AccountPersistenceAdapter
        │           └── SpringDataAccountRepository
        ├── application
        │   ├── SendMoneyService
        │   └── port
        │       ├── in
        │       │   └── SendMoneyUseCase
        │       └── out
        │           ├── LoadAccountPort
        │           └── UpdateAccountStatePort
        └── domain
            ├── Account
            └── Activity
```

구조의 각 요소들은 패키지 하나씩에 직접 매핑된다.

최상위에는 Account 와 관련된 유스케이스를 구현한 모듈임을 나타내는 account 패키지가 있다.

- **domain 패키지**
  - 도메인 모델
- **application 패키지**
  - 도메인 모델을 둘러싼 서비스 계층
  - _SendMoneyService_
    - 인커밍 포트 인터페이스인 _SendMoneyUseCase_ 를 구현
    - 아웃고잉 포트 인터페이스이자 영속성 어댑터에 의해 구현된 _LoadAccountPort_ 와 _UpdateAccountStatePort_ 를 사용
- **adapter 패키지**
  - **애플리케이션 계층의 인커밍 포트를 호출하는 인커밍 어댑터**와 **애플리케이션 계층의 아웃고잉 포트에 대한 구현을 제공하는 아웃고잉 어댑터** 포함
  - 위 패키지 구조의 경우 각각의 하위 패키지를 가진 web 어댑터와 persistence 어댑터로 이뤄진 애플리케이션임

만일 현재 사용중인 서드파티 API 에 대한 클라이언트를 변경하는 작업을 해야한다면 해당 API 클라이언트의 코드는 _adapter/out/어댑터명_ 패키지에서 바로 찾을 수 있다.  
만일 **패키지 구조가 아키텍처를 반영할 수 없다면 시간이 지남에 따라 점점 목표하던 아키텍처로부터 멀어지게 될 것이다.**

이 패키지 구조는 '아키텍처-코드 갭' 혹은 '모델-코드 갭' 을 효과적으로 다룰 수 있다.

---

하지만 패키지가 아주 많다는 것은 모든 것을 public 으로 만들어서 패키지 간의 접근을 허용해야 한다는 것을 의미하는 것은 아닐지 생각해보자.

적어도 어댑터 패키지에 대해서는 그렇지 않다.  
**어댑터 패키지에 들어있는 모든 클래스들은 application 패키지 내에 있는 포트 인터페이스를 통하지 않고는 외부에서 호출되지 않기 때문에 `package-private` 수준**으로 두어도 된다.  
따라서 애플리케이션 계층에서 어댑어 클래스로 향하는 의존성은 있을 수 없다.

**하지만 application 패키지와 domain 패키지 내의 일부 클래스들은 public 으로 지정**해야 한다.  
의도적으로 **어댑터에서 접근 가능해야 하는 포트들은 public** 이어야 한다.  

<**public 클래스이어야 하는 경우**>  
- **application 패키지**
  - 어댑터에서 접근 가능해야 하는 포트들은 public 이어야 함
  - 단, 서비스 (_SendMoneyService_)는 인커밍 포트 인터페이스 (_SendMoneyUseCase_) 뒤에 숨겨지므로 public 일 필요가 없음
- **domain 패키지**
  - **도메인 클래스들은 서비스, 잠재적으로는 어댑터에서도 접근 가능하도록 public** 이어야 함

---

위의 패키지 구조는 **어댑터 코드를 자체 패키지로 이동시키면 필요할 경우 하나의 어댑터를 다른 구현으로 쉽게 교체**할 수 있다.  
예) DB 변경 시 아웃고잉 포트들만 새로운 어댑터 패키지에 구현하고 기존 패키지 삭제

**위의 패키지 구조는 DDD 개념에 직접적으로 대응**시킬 수도 있다.

account 와 같은 상위 레벨 패키지는 다른 바운디드 컨텍스트와 통신할 전용 진입점과 출구(포트) 를 포함하는 바운디드 컨텍스트에 해당한다.

> **바운디드 컨텍스트**  
> 
> 어떤 하나의 도메인 모델이 적용될 수 있는 범위
> 
> 바운디드 컨텍스트에 대한 좀 더 상세한 내용은 [DDD - 바운디드 컨텍스트](https://assu10.github.io/dev/2024/04/27/ddd-bounded-context/) 를 참고하세요.

---

# 4. 의존성 주입 (DI, Dependency Injection) 의 역할

**클린 아키텍처의 본질은 애플리케이션 계층이 인커밍/아웃고잉 (Driving/Driven) 어댑터에 의존성을 갖지 않는 것**이다.

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

위 그림에서 웹 어댑터와 같이 인커밍 어댑터는 제어 흐름의 방향이 어댑터와 도메인 코드 간의 의존성 방향이 같은 방향이기 때문에 그렇게 하기 쉽다.  
그럼에도 불구하고 애플리케이션 계층으로의 진입점을 구분짓기 위해 실제 서비스를 포트 인터페이스들 사이에 숨겨두고 싶을 수 있다.

**영속성 어댑터와 같이 아웃고잉 어댑터에 대해서는 제어 흐름의 반대 방향으로 의존성을 돌리기 위한 의존성 역전 원칙 (DIP, Dependency Inversion Principle) 을 이용**해야 한다.

의존성 역전 원칙은 애플리케이션 계층에 인터페이스를 만들고 어댑터에 해당 인터페이스를 구현한 클래스를 두면 된다.  
**육각형 아키텍처에서는 이 인터페이스가 포트**이다.

![호출 흐름](/assets/img/dev/2024/0512/di.png)

위 그림을 보면 웹 컨트롤러가 서비스에 의해 구현된 인커밍 포트를 호출하고, 서비스는 어댑터에 의해 구현된 아웃고잉 포트를 호출한다.  
즉, **애플리케이션은 어댑터의 기능을 이용하기 위해 포트 인터페이스를 호출**한다.

_AccountController_ 는 _SendMoneyUseCase_ 인터페이스를 필요로 하기 때문에 의존성 주입을 통해 _SendMoneyService_ 클래스의 인스턴스를 주입하고, 
_SendMoneyService_ 는 _LoadAccountPort_ 인터페이스로 가장한 _AccountPersistenceAdapter_ 클래스의 인스턴스를 주입한다.

> 스프링 프레임워크를 통해 애플리케이션을 초기화하는 방법에 대해서는 추후 상세히 다룰 예정입니다. (p. 31)

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)
* [자바의 접근제어자(public, protected, private, private-package)](https://rutgo-letsgo.tistory.com/entry/%EC%9E%90%EB%B0%94%EC%9D%98-%EC%A0%91%EA%B7%BC%EC%A0%9C%EC%96%B4%EC%9E%90public-protected-private-private-package#private-package(default)-1)