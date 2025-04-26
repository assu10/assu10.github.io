---
layout: post
title:  "Clean Architecture - 웹 어댑터 구현"
date: 2024-05-19
categories: dev
tags: clean architecture web-adapter
---

육각형 아키텍처에서 외부와의 모든 통신을 어댑터를 통해 이루어지는데 이 포스트에서는 웹 인터페이스를 제공하는 
어댑터의 구현 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/clean-architecture/tree/feature/chap05)  에 있습니다.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 의존성 역전 (DI, Dependency Inversion)](#1-의존성-역전-di-dependency-inversion)
* [2. 웹 어댑터의 책임](#2-웹-어댑터의-책임)
* [3. 컨트롤러 나누기: `@WebAdapter`, `@UseCase`, `@PersistenceAdapter` 애너테이션 생성](#3-컨트롤러-나누기-webadapter-usecase-persistenceadapter-애너테이션-생성)
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

# 1. 의존성 역전 (DI, Dependency Inversion)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

아래는 어댑터 자체와 애플리케이션 코어와 상호작용 하는 포트에 초점을 맞춘 흐름도이다.

![인커밍 어댑터의 흐름](/assets/img/dev/2024/0519/adapter.png)

**인커밍 어댑터는 애플리케이션 서비스에 의해 구현된 인터페이스인 전용 포트를 통해 애플리케이션 계층과 통신**한다.

웹 어댑터는 인커밍 혹은 Driving 어댑터이다. 외부로부터 요청을 받아 애플리케이션으로 전달한다.  
이 때 제어 흐름은 웹 어댑터에 있는 컨트롤러에서 애플리케이션 계층에 있는 서비스로 흐른다.

**애플리케이션 계층은 웹 어댑터가 통신할 수 있는 특정 포트를 제공**한다.  
**웹 어댑터는 이 포트를 호출할 수 있고, 서비스는 이 포트를 구현**한다.

위 그림을 다시 보면 의존성 역전 원칙이 적용된 것을 볼 수 있다.

제어 흐름이 왼쪽에서 오른쪽으로 흐르므로 웹 어댑터가 유스케이스를 직접 호출할 수도 있다.

![포트 인터페이스를 삭제하고 서비스를 직접 호출](/assets/img/dev/2024/0519/adapter_2.png)

위처럼 **웹 어댑터가 바로 서비스를 호출할 수도 있는데 왜 어댑터와 유스케이스 사이에 또 다른 간접 계층을 넣는 것일까?**

**이유는 애플리케이션 코어가 외부와 통신할 수 있는 곳에 대한 명세가 바로 포트이기 때문**이다.  
**포트를 적절한 곳에 위치시키면 외부와 어떤 통신이 일어나고 있는지 정확히 알 수 있다.**

> 인커밍 포트를 생략하고 애플리케이션 서비스를 직접 호출하는 것에 대한 내용은 [5. 인커밍 포트 생략](https://assu10.github.io/dev/2024/06/09/clean-shotcut/#5-%EC%9D%B8%EC%BB%A4%EB%B0%8D-%ED%8F%AC%ED%8A%B8-%EC%83%9D%EB%9E%B5) 을 참고하세요.

---

만일 웹 소켓을 통해서 실시간 데이터를 사용자의 브라우저에 보낼 때 웹 어댑터는 이 데이터를 어떻게 사용자의 브라우저에 전달하는 것일까?

이 때도 반드시 포트가 필요하다.  
**이 포트는 웹 어댑터에서 구현하고, 애플리케이션 코어에서 호출**한다.

![아웃고잉 포트](/assets/img/dev/2024/0519/adapter_3.png)

위 그림을 보면 애플리케이션이 웹 어댑터에 능동적으로 알림을 주어야 한다면 의존성을 올바른 방향으로 유지하기 위해 아웃고잉 포트를 통과해야 한다.

**이제 웹 어댑터는 인커밍 어댑터인 동시에 아웃고잉 어댑터**가 된다.

---

# 2. 웹 어댑터의 책임

웹 어댑터는 일반적으로 아래와 같은 일을 한다.

- **HTTP 요청을 자바 객체로 매핑**
  - URL, HTTP 메서드, Content-type 과 같이 특정 기준을 만족하는 HTTP 요청 수신
  - HTTP 요청의 파라메터와 콘텐츠를 객체로 역직렬화
- **권한 검사**
  - 인증과 권한 부여 수행 후 실패하면 에러 반환
- **입력 유효성 검증**
  - [유스케이스에서 하는 입력 유효성](https://assu10.github.io/dev/2024/05/18/clean-usecase/#3-%EC%9E%85%EB%A0%A5-%EC%9C%A0%ED%9A%A8%EC%84%B1-%EA%B2%80%EC%A6%9D-%EC%9E%85%EB%A0%A5-%EB%AA%A8%EB%8D%B8%EC%9D%98-%EC%83%9D%EC%84%B1%EC%9E%90) 과는 다름
  - 유스케이스 입력 모델은 유스케이스의 맥락에서 유효한 입력만을 허용하는 것임
  - 웹 어댑터의 입력 모델은 유스케이스의 입력 모델과 다를 수 있으므로 또 다른 유효성 검증을 해야 함
  - 따라서 유스케이스 입력 모델에서 했던 유효성 검증을 똑같이 웹 어댑터에서도 구현하는 것이 아님
  - **웹 어댑터의 입력 모델을 유스케이스의 입력 모델로 변환할 수 있다는 것을 검증**하는 것임
  - 이 때 오류가 나면 유효성 검증 에러 반환
- **입력을 유스케이스의 입력 모델로 매핑**
- **유스케이스 호출**
  - 변환된 입력 모델로 특정한 유스케이스 호출
- **유스케이스의 출력을 HTTP 로 매핑**
  - 어댑터는 유스케이스의 출력을 반환받은 후 HTTP 응답으로 직렬화하여 호출자에게 전달
- **HTTP 응답 반환**

위 과정에서 한 곳이라도 에러가 나면 예외를 던지고 웹 어댑터는 에러를 호출자에게 적절히 노출한다.

위의 작업들은 애플리케이션 계층이 신경쓰면 안되는 것들이다.  
**HTTP 와 관련된 것들은 애플리케이션 계층으로 침투해서는 안된다.**

---

# 3. 컨트롤러 나누기: `@WebAdapter`, `@UseCase`, `@PersistenceAdapter` 애너테이션 생성

위에서 말한 웹 어댑터의 책임을 수행할 컨트롤러들을 생성할 때 한 개 이상의 클래스로 구성할 수 있다.

컨트롤러는 너무 적은 것보다는 너무 많은 게 낫다.

**각 컨트롤러가 가능한 좁고 다른 컨트롤러와 적게 공유하는 웹 어댑터 조각을 구현**해야 한다.

예를 들어 _Account_ 엔티티의 연산들을 모아놓은 _AccountController_ 가 있다고 해보자.  
이 컨트롤러는 계좌와 관련된 모든 요청을 받을 것이다.

하나의 컨트롤러에 모든 연산을 담은 안 좋은 예시
```java
@RestController
@RequiredArgsController
class AccountController {
    private final GetAccountBalanceQuery getAccountBalanceQuery;
    private final ListAccountQuery listAccountQuery;
    private final LoadAccountQuery loadAccountQuery;
    
    private final SendMoneyUseCase sendMoneyUseCase;
    private final CreateAccountUseCase createAccountUseCase;
    
    @GetMapping("/accounts")
    List<AccountResource> listAccounts() {
        // ...
    }
    
    @GetMapping("/accounts/{accountId}")
    AccountResource getAccount(@PathVariable("accountId") Long accountId) {
        // ...
    }
    
    @GetMapping("/accounts/{accountId}/balance")
    long getAccountBalance(@PathVariable("accountId") Long accountId) {
        // ...
    }
    
    @PostMapping("/accounts")
    AccountResource createAccount(@RequestBody AccountResource account) {
        // ...
    }
    
    @PostMapping("/accounts/send/{sourceAccountId}/{targetAccountId}/{amounts}")
    void sendMoney(
          @PathVariable("sourceAccountId") Long sourceAccountId,
          @PathVariable("targetAccountId") Long targetAccountId,
          @PathVariable("amounts") Long amounts
    ) {
        // ...
    }
}
```

위 코드는 계좌 리소스와 관련된 모든 것이 하나의 클래스에 모여 있다.

이럴 때의 단점은 아래와 같다.

- **클래스마다 코드는 적을수록 좋음**
  - 클래스 코드가 길면 코드 파악에 어려움이 있음
- **테스트 코드 찾기가 어려움**
  - 컨트롤러에 코드가 많으면 그에 해당하는 테스트 코드도 많음
  - 보통 테스트 코드는 더 추상적이라서 프로덕션 코드에 비해 파악하기 어려울 때가 많음
  - 따라서 특정 프로덕션 코드에 해당하는 테스트 코드를 찾기 쉽게 만들어야 하는데 클래스가 작을수록 더 찾기 쉬움
- **데이터 구조의 재활용을 촉진 (공유 모델이 생겨남)**
  - 모든 연산을 단일 컨트롤러에 넣음으로써 하나의 모델 클래스를 공유하게 됨 (위에서는 _AccountResource_)
  - 위 코드에서는 _AccountResource_ 가 모든 연산에서 필요한 모든 데이터를 담고 있음

---

따라서 각 연산에 대해 별도의 패키지 안에 별도의 컨트롤러를 만들고 메서드와 클래스명은 유스케이스를 최대한 반영하여 짓는 것이 좋다.

SendMoneyController.java
```java
package com.assu.study.clean_me.account.adapter.in.web;

import com.assu.study.clean_me.account.application.port.in.SendMoneyCommand;
import com.assu.study.clean_me.account.application.port.in.SendMoneyUseCase;
import com.assu.study.clean_me.account.domain.Account;
import com.assu.study.clean_me.account.domain.Money;
import com.assu.study.clean_me.common.WebAdapter;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@WebAdapter
@RestController
@RequiredArgsConstructor
class SendMoneyController {
  private final SendMoneyUseCase sendMoneyUseCase;

  @PostMapping("accounts/send/{sourceAccountId}/{targetAccountId}/{amount}")
  void sendMoney(
      @PathVariable("sourceAccountId") Long sourceAccountId,
      @PathVariable("targetAccountId") Long targetAccountId,
      @PathVariable("amount") Long amount) {
    SendMoneyCommand command =
        new SendMoneyCommand(
            new Account.AccountId(sourceAccountId),
            new Account.AccountId(targetAccountId),
            Money.of(amount));

    sendMoneyUseCase.sendMoney(command);
  }
}
```

**각 컨트롤러가 _CreateAccountResource_, _UpdateAccountResource_ 와 같은 컨트롤러 자체의 모델을 갖거나 위처럼 Long 같은 
원시값**을 받아도 된다.

이러한 **전용 모델 클래스들은 컨트롤러 패키지에 대해 private 로 선언할 수 있기 때문에 실수로 다른 곳에서 재사용될 일이 없다.**

컨트롤러끼리는 모델을 공유할 수 있지만 다른 패키지에 있으므로 공유하여 사용하기 전에 다시 한번 생각해볼 수 있다.

**이렇게 나누게 되면 서로 다른 연산에 대한 동시 작업이 가능해진다는 장점**이 있다.

SendMoneyService.java
```java
package com.assu.study.cleanme.account.application.service;

import com.assu.study.cleanme.account.application.port.in.SendMoneyCommand;
import com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase;
import com.assu.study.cleanme.account.application.port.out.AccountLock;
import com.assu.study.cleanme.account.application.port.out.LoadAccountPort;
import com.assu.study.cleanme.account.application.port.out.UpdateAccountStatePort;
import com.assu.study.cleanme.account.domain.Account;
import com.assu.study.cleanme.common.UseCase;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

// 인커밍 포트 인터페이스인 SendMoneyUseCase 구현
@UseCase
@RequiredArgsConstructor
@Transactional
class SendMoneyService implements SendMoneyUseCase {

  // 계좌를 조회하기 위한 아웃고잉 인터페이스
  private final LoadAccountPort loadAccountPort;

  private final AccountLock accountLock;

  // 계좌 상태를 업데이트하기 위한 아웃고잉 인터페이스
  private final UpdateAccountStatePort updateAccountStatePort;

  private final MoneyTransferProperties moneyTransferProperties;

  // 1. 비즈니스 규칙 검증
  // 2. 모델 상태 조작
  // 3. 출력값 반환
  @Override
  public boolean sendMoney(SendMoneyCommand command) {
    // 1. 비즈니스 규칙 검증

    // 이체 가능한 최대 한도를 넘는지 검사
    checkThreshold(command);

    // 오늘로부터 -10 일
    LocalDateTime baselineDate = LocalDateTime.now().minusDays(10);

    // 최근 10일 이내의 거래내역이 있는 계좌 정보 확인
    Account sourceAccount = loadAccountPort.loadAccount(command.getSourceAccountId(), baselineDate);
    Account targetAccount = loadAccountPort.loadAccount(command.getTargetAccountId(), baselineDate);

    // 입출금 계좌 아이디가 존재하는지 확인
    Account.AccountId sourceAccountId =
        sourceAccount
            .getId()
            .orElseThrow(() -> new IllegalStateException("source accountId not to be empty"));

    Account.AccountId targetAccountId =
        targetAccount
            .getId()
            .orElseThrow(() -> new IllegalStateException("target accountId not to be empty"));

    // 출금 계좌의 잔고가 다른 트랜잭션에 의해 변경되지 않도록 lock 을 검
    accountLock.lockAccount(sourceAccountId);

    // 출금 계좌에서 출금을 한 후 lock 해제
    if (!sourceAccount.withdraw(command.getMoney(), targetAccountId)) {
      accountLock.releaseAccount(sourceAccountId);
      return false;
    }

    // 출금 후 입금 계좌에 lock 을 건 후 입금 처리
    accountLock.lockAccount(targetAccountId);
    if (!targetAccount.deposit(command.getMoney(), sourceAccountId)) {
      accountLock.releaseAccount(sourceAccountId);
      accountLock.releaseAccount(targetAccountId);
      return false;
    }

    // 2. 모델 상태 조작
    updateAccountStatePort.updateActivities(sourceAccount);
    updateAccountStatePort.updateActivities(targetAccount);

    accountLock.releaseAccount(sourceAccountId);
    accountLock.releaseAccount(targetAccountId);

    // 3. 출력값 반환
    return true;
  }

  private void checkThreshold(SendMoneyCommand command) {
    if (command
        .getMoney()
        .isGreaterThenOrEqualTo(moneyTransferProperties.getMaximumTransferThreshold())) {
      throw new ThresholdExceededException(
          moneyTransferProperties.getMaximumTransferThreshold(), command.getMoney());
    }
  }
}
```

> `@WebAdapter`, `@UseCase`, `@PersistenceAdapter` 의 상세 구현은 [2. 스프링 프레임워크의 `클래스패스 스캐닝`으로 설정 컴포넌트 구현: `@Component`](https://assu10.github.io/dev/2024/06/02/clean-application-composition/#2-%EC%8A%A4%ED%94%84%EB%A7%81-%ED%94%84%EB%A0%88%EC%9E%84%EC%9B%8C%ED%81%AC%EC%9D%98-%ED%81%B4%EB%9E%98%EC%8A%A4%ED%8C%A8%EC%8A%A4-%EC%8A%A4%EC%BA%90%EB%8B%9D%EC%9C%BC%EB%A1%9C-%EC%84%A4%EC%A0%95-%EC%BB%B4%ED%8F%AC%EB%84%8C%ED%8A%B8-%EA%B5%AC%ED%98%84-component) 을 참고하세요.

---

# 정리하며...

**웹 어댑터를 구현할 때는 HTTP 요청을 애플리케이션 유스케이스에 대한 메서드 호출로 변환하고, 결과를 다시 HTTP 로 변환하며 어떠한 
도메인 로직도 수행하지 않아야 한다.**

**애플리케이션 계층은 HTTP 에 대한 상세 정보를 노출시키지 않도록 HTTP 와 관련된 작업을 하면 안된다.**  
그러면 나중에 웹 어댑터를 다른 어댑터로 쉽게 교체할 수 있다.

**웹 컨트롤러를 나눌 때는 모델을 공유하지 않는 여러 개의 작은 클래스**로 만들어야 한다.  
**작은 클래스들은 더 파악하기 쉽고, 더 테스트하기 쉬우며, 동시 작업을 지원**한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)