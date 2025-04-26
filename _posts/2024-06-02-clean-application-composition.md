---
layout: post
title:  "Clean Architecture - 설정 컴포넌트"
date: 2024-06-02
categories: dev
tags: clean architecture classpath-scanning java-config @Component @Configuration @EnableJpaRepositories
---

지금까지 유스케이스, 웹 어댑터, 영속성 어댑터를 구현했으니 이제 이것들을 동작하는 애플리케이션으로 조립해야 한다.

애플리케이션이 시작될 때 클래스를 인스턴스화하고 묶기 위해 의존성 주입 메커니즘 (DI) 를 이용한다.

이 포스트에서는 이 작업들을 평범한 자바로, 스프링으로, 스프링 부트 프레임워크로 하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/clean-architecture/tree/feature/chap09)  에 있습니다.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 조립을 해야하는 이유: 설정 컴포넌트 (configuration component)](#1-조립을-해야하는-이유-설정-컴포넌트-configuration-component)
* [2. 스프링 프레임워크의 `클래스패스 스캐닝`으로 설정 컴포넌트 구현: `@Component`](#2-스프링-프레임워크의-클래스패스-스캐닝으로-설정-컴포넌트-구현-component)
* [3. 스프링 부트 프레임워크의 `자바 컨피그`로 설정 컴포넌트 구현: `@Configuration`, `@EnableJpaRepositories`](#3-스프링-부트-프레임워크의-자바-컨피그로-설정-컴포넌트-구현-configuration-enablejparepositories)
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

# 1. 조립을 해야하는 이유: 설정 컴포넌트 (configuration component)

**유스케이스와 어댑터를 필요할 때 그냥 인스턴스화하여 사용하면 안되는 이유는 코드의 의존성이 올바른 방향**을 가리키게 하기 위해서이다.

**모든 의존성은 안쪽으로, 애플리케이션의 도메인 코드 방향으로 향해야 도메인 코드가 바깥 계층의 변경으로부터 안전**하다.

만일 유스케이스가 영속성 어댑터를 호출하고 스스로 인스턴스화한다면 코드 의존성이 잘못된 것이다.    
**이것이 바로 아웃고잉 포트 인터페이스를 생성한 이유**이다.  
**유스케이스는 인터페이스만 알아야 하고, 런타임에 이 인터페이스의 구현을 제공받아야 한다.**

그렇다면 객체 인스턴스를 생성하고 의존성 규칙을 이용할 수 있게 해주는 책임은 어디에 있는 것일까?

답은 바로 **설정 컴포넌트 (configuration component)** 이다.  
아래 그림처럼 **아키텍처에 대해 중립적이고 인스턴스 생성을 위해 _모든_ 클래스에 대한 의존성을 가지는 설정 컴포넌트**가 있어야 한다.

![인스턴스 생성을 위해 모든 클래스에 접근할 수 있는 설정 컴포넌트](/assets/img/dev/2024/0602/configuration_component.png)

**클린 아키텍처에서 설정 컴포넌트는 의존성 규칙에 정의된 대로 모든 내부 계층에 접근할 수 있는 가장 바깥쪽에 위치**한다.

<**설정 컴포넌트의 역할**>  
- 웹 어댑터 인스턴스 생성
- HTTP 요청이 실제로 웹 어댑터로 전달되도록 보장
- 유스케이스 인스턴스 생성
- 웹 어댑터에 유스케이스 인스턴스 제공
- 영속성 어댑터 인스턴스 생성
- 유스케이스에 영속성 어댑터 인스턴스 제공
- 영속성 어댑터가 실제로 DB 에 접근할 수 있도록 보장

**설정 컴포넌트는 설정 파일이나 커맨드라인 파라메터 등과 같은 설정 파라메터의 소스에도 접근**할 수 있어야 한다.  
이러한 파라메터를 애플리케이션 컴포넌트에 제공하여 어떤 DB 에 접근하고 어떤 서버를 메일 전송에 사용할지 등의 행동 양식을 제어한다.


---

# 2. 스프링 프레임워크의 `클래스패스 스캐닝`으로 설정 컴포넌트 구현: `@Component`

스프링 프레임워크를 이용하여 애플리케이션을 조립한 결과물을 `applicaton context` 라고 한다.  
`application context` 는 애플리케이션을 구성하는 모든 객체(=Bean) 를 포함한다.

스프링 프레임워크는 `application context` 를 구성하기 위한 몇 가지 방법을 제공하는데 가장 많이 사용되는 **클래스패스 스캐닝**에 대해 알아본다.

클래스패스 스캐닝이 동작하는 순서는 아래와 같다.

- 스프링은 클래스패스 스캐닝으로 클래스패스에서 접근 가능한 모든 클래스를 확인하여 `@Component` 애너테이션이 붙은 클래스를 찾음
- `@Component` 애너테이션이 붙은 각 클래스의 객체를 생성
  - 이 때 클래스는 필요한 모든 필드를 인자로 받는 생성자를 가져야 함 (`@RequiredArgsConstructor`)

```java
@RequiredArgsConstructor
class GetAccountBalanceService implements GetAccountBalanceQuery {
  private final LoadAccountPort loadAccountPort;
  // ...
}
```
- 스프링은 이 생성자를 찾아서 생성자의 인자로 사용된 `@Component` 가 붙은 클래스들을 찾은 후 이 클래스들의 인스턴스를 만들어 `application context` 에 추가함
- 필요한 객체들이 모두 생성되면 _GetAccountBalanceService_ 의 생성자를 호출하고 생성된 객체도 마찬가지로 `application context` 에 추가함

클래스패스 스캐닝 방식을 이용하면 적절한 곳에 `@Component` 애너테이션을 붙이고 생성자만 잘 만들어두면 된다.

스프링이 인식할 수 있는 애너테이션을 직접 만들수도 있다.

WebAdapter.java

```java
package com.assu.study.clean_me.common;

import java.lang.annotation.*;
import org.springframework.core.annotation.AliasFor;
import org.springframework.stereotype.Component;

@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface WebAdapter {
  @AliasFor(annotation = Component.class)
  String value() default "";
}
```

UseCase.java
```java
package com.assu.study.clean_me.common;

import org.springframework.core.annotation.AliasFor;
import org.springframework.stereotype.Component;

import java.lang.annotation.*;

@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface UseCase {
  @AliasFor(annotation = Component.class)
  String value() default "";
}
```

PersistenceAdapter.java
```java
package com.assu.study.clean_me.common;

import org.springframework.core.annotation.AliasFor;
import org.springframework.stereotype.Component;

import java.lang.annotation.*;

@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface PersistenceAdapter {
  @AliasFor(annotation = Component.class)
  String value() default "";
}
```

이제 `@Component` 대신 `@UseCase` 등의 애너테이션을 사용하여 유스케이스 클래스들이 애플리케이션의 일부임을 표시할 수 있다.  
이 애너테이션 덕분에 코드를 보는 사람들은 아키텍처를 더 쉽게 파악할 수 있다.

<**클래스패스 스캐닝 방식의 단점**>  
- 프레임워크에 특화된 애너테이션을 클래스에 붙여야 함
  - 강경한 클린 아키텍처파는 이런 방식이 코드를 특정 프레임워크와 결합시키기 때문에 사용하지 말아야 한다고 주장함
  - 일반적인 애플리케이션에서는 필요하다면 한 클래스에 애너테이션 하나 정도는 용인할 수 있는 수준이고, 리팩토링도 쉽게 할 수 있음
  - 하지만 다른 개발자들이 사용할 라이브러리나 프레임워크를 만드는 입장에서는 라이브러리 사용자가 스프링 프레임워크의 의존성에 엮이기 때문에 사용하면 안됨
- 스프링 전문가가 아니라면 원인을 찾는데 수일이 걸릴 수 있는 부수 효과를 야기할 수 있음
  - 클래스패스 스캐닝은 단순히 스프링에게 부모 패키지를 알려준 후 이 패키지 안에서 `@Component` 가 붙은 클래스를 찾으라고 지시함

---

# 3. 스프링 부트 프레임워크의 `자바 컨피그`로 설정 컴포넌트 구현: `@Configuration`, `@EnableJpaRepositories`

**이 방식에서는 `application context` 에 추가할 빈을 생성하는 설정 클래스**를 만든다.

예를 들어 모든 영속성 어댑터들의 인스턴스 생성을 담당하는 설정 클래스는 아래와 같다.

```java
@Configuration
@EnableJpaRepositories
class PersistenceAdapterConfiguration {
    @Bean
    AccountPersistenceAdapter accountPersistenceAdapter(
          AccountRepository accountRepository,
          ActivityRepository activityRepository,
          AccountMapper accountMapper
    ) {
        return new AccountPersistenceAdapter(
                accountRepository, activityRepository, accountMapper
        );
    }
    
    @Bean
    AccountMapper accountMapper() {
        return new AccountMapper();
    }
}
```

**`@Configuration` 애너테이션을 통해 이 클래스가 스프링의 클래스패스 스캐닝에서 발견해야 할 설정 클래스임을 표시**한다.  
따라서 사실 여전히 클래스패스 스캐닝을 사용하고 있는 것이다.  
하지만 모든 빈을 가져오는 대신 설정 클래스만 선택하여 가져온다.

빈 자체는 설정 클래스 내의 `@Bean` 애너테이션이 붙은 팩토리 메서드를 통해 생성된다.

위 예시에서 영속성 어댑터는 2개의 리포지터리와 1개의 매퍼를 생성자 입력으로 받는데 스프링은 이 객체들을 자동으로 팩토리 메서드에 대한 입력으로 제공한다.

그럼 스프링은 이 리포지객체들을 어디서 가져오는 걸까?

이 객체들이 다른 설정 클래스의 팩토리 메서드에서 수동으로 생성되었다면 스프링이 자동으로 팩토리 메서드의 파라메터로 제공하겠지만 위 예시에서는 `@EnableJpaRepositories` 애너테이션을 사용하여 
스프링이 직접 생성하도록 하였다.  
스프링 부트가 `@EnableJpaRepositories` 애너테이션을 발견하면 자동으로 모든 스프링 데이터 리포지터리 인터페이스의 구현체를 제공한다.

_PersistenceAdapterConfiguration_ 설정 클래스를 사용하여 **영속성 계층에서 필요로하는 모든 객체를 인스턴스화하는 매우 한정적인 범위의 영속성 모듈**을 만들었다.  
이 **설정 클래스는 스프링의 클래스패스 스캐닝을 통해 자동으로 선택될 것이고, 개발자는 어떤 빈이 `application context` 에 등록될 지 제어**할 수 있다.

**이 방식에서는 클래스패스 스캐닝 방식과 달리 `@Component` 애너테이션을 여기저기 붙이도록 강제하지 않기 때문에 애플리케이션 계층을 스프링 프레임워크에 대한 의존성없이 유지**할 수 있다.

이 방식의 문제점은 설정 클래스가 생성하는 빈(위 예시에서는 영속성 어댑터 클래스들)이 설정 클래스와 같은 패키지에 존재하지 않는다면 이 빈들을 public 으로 만들어야 한다는 점이다.

가시성 제한을 위해 패키지를 모듈 경계로 사용하고 각 패키지 안에 전용 설정 클래스를 만들수는 있지만 그러면 하위 패키지를 사용할 수 없다.

> 이 부분에 대한 좀 더 상세한 설명은 [2. 접근 제한자 (Visibility Modifier)](https://assu10.github.io/dev/2024/06/08/clean-layer-boundary-enforcement/#2-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C%EC%9E%90-visibility-modifier) 를 참고하세요.

---

# 정리하며...

클래스패스 스캐닝은 스프링에게 패키지만 알려주면 거기서 찾은 클래스로 애플리케이션을 조립하기 때문에 매우 편리하다.  
하지만 코드의 규모가 커지면 어떤 빈이 `application context` 에 등록되는지 정확히 알 수 없게 되어 투명성이 낮아진다.  
또한 테스트에서 `application context` 의 일부만 독립적으로 띄우기가 어려워진다.

자바 컨피그를 이용하여 전용 설정 컴포넌트를 만들면 애플리케이션이 변경할 이유 (SOLID 의 S인 `SRP` (Single Responsibility Principle, 단일 책임 원칙)) 로부터 자유로워 진다.  
전용 설정 컴포넌트 방식을 이용하게 되면 서로 다른 모듈로부터 독립되어 코드 상에서 손쉽게 옮겨다닐 수 있는 응집도가 매우 높은 모듈을 만들 수 있다.

> SOLID 에 대한 좀 더 상세한 내용은 [2. SOLID 객체 지향 설계 원칙](https://assu10.github.io/dev/2023/04/29/nest-clean-architecture/#2-solid-%EA%B0%9D%EC%B2%B4-%EC%A7%80%ED%96%A5-%EC%84%A4%EA%B3%84-%EC%9B%90%EC%B9%99) 을 참고하세요.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)