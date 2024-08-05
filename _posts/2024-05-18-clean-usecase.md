---
layout: post
title:  "Clean Architecture - 유스케이스, 입력 유효성 검증, 비즈니스 유효성 검증, 입출력 모델"
date: 2024-05-18
categories: dev
tags: clean usecase rich-domain-model anemic-domain-model
---

[3. 아키텍처적으로 표현력있는 패키지 구조](https://assu10.github.io/dev/2024/05/12/clean-package/#3-%EC%95%84%ED%82%A4%ED%85%8D%EC%B2%98%EC%A0%81%EC%9C%BC%EB%A1%9C-%ED%91%9C%ED%98%84%EB%A0%A5%EC%9E%88%EB%8A%94-%ED%8C%A8%ED%82%A4%EC%A7%80-%EA%B5%AC%EC%A1%B0) 에서 본 아키텍처는 
애플리케이션, 웹, 영속성 계층이 아주 느슨하게 결합되어 있기 때문에 도메인 코드를 자유롭게 모델링 할 수 있다.

이 포스트에서는 육각형 아키텍처에서 유스케이스를 구현해본다.

육각형 아키텍처는 도메인 중심의 아키텍처에 적합하므로 도메인 엔티티를 만드는 것으로 시작하여 해당 도메인 엔티티를 중심으로 
유스케이스를 구현한다.

> 소스는 [github](https://github.com/assu10/clean-architecture/tree/feature/chap04)  에 있습니다.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 도메인 모델 구현](#1-도메인-모델-구현)
* [2. 유스케이스](#2-유스케이스)
* [3. 입력 유효성 검증: 입력 모델의 생성자](#3-입력-유효성-검증-입력-모델의-생성자)
* [4. 빌더 패턴보다는 생성자 사용](#4-빌더-패턴보다는-생성자-사용)
* [5. 유스케이스마다 다른 입력 모델](#5-유스케이스마다-다른-입력-모델)
* [6. 비즈니스 규칙 검증](#6-비즈니스-규칙-검증)
  * [6.1. 입력 유효성 검증과 비즈니스 규칙 검증](#61-입력-유효성-검증과-비즈니스-규칙-검증)
  * [6.2. 비즈니스 규칙 검증](#62-비즈니스-규칙-검증)
* [7. 풍부한 도메인 모델 (rich domain model) vs 빈약한 도메인 모델 (anemic domain model)](#7-풍부한-도메인-모델-rich-domain-model-vs-빈약한-도메인-모델-anemic-domain-model)
  * [7.1. 풍부한 도메인 모델 (rich domain model)](#71-풍부한-도메인-모델-rich-domain-model)
  * [7.2. 빈약한 도메인 모델 (anemic domain model)](#72-빈약한-도메인-모델-anemic-domain-model)
* [8. 유스케이스마다 다른 출력 모델](#8-유스케이스마다-다른-출력-모델)
* [9. 읽기 전용 유스케이스](#9-읽기-전용-유스케이스)
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

  testImplementation('org.springframework.boot:spring-boot-starter-test') {
    exclude group: 'junit' // excluding junit 4
  }

//    testImplementation 'org.junit.jupiter:junit-jupiter-engine:5.10.3'
//    testImplementation 'org.mockito:mockito-junit-jupiter:5.12.0'
//    implementation 'com.tngtech.archunit:archunit:1.3.0'
//    testImplementation 'org.junit.platform:junit-platform-launcher:1.10.3'
}

test {
  useJUnitPlatform()
}
```

---

# 1. 도메인 모델 구현

Account.java
```java
package com.assu.study.clean_me.account.domain;

import java.time.LocalDateTime;
import java.util.Optional;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Value;

// 계좌의 현재 스냅샷을 제공
@Getter
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class Account {
  private final AccountId id;

  // 계좌의 현재 잔고를 계산하기 한 ActivityWindow 의 첫 번째 활동 바로 전의 잔고
  // 과거 특정 시점의 계좌 잔고
  private final Money baselineBalance;

  // 한 계좌에 대한 모든 활동(activity) 들을 항상 메모리에 한꺼번에 올리지 않고,
  // Account 엔티티는 ActivityWindow 값 객체(VO) 에서 포착한 지난 며칠 혹은 특정 범위에 해당하는 활동만 보유
  // 과거 특정 시점 이후의 입출금 내역 (activity)
  private final ActivityWindow activityWindow;

  // ID 가 없는 Account 엔티티 생성
  // 아직 생성되지 않은 새로운 엔티티 생성
  public static Account withoutId(Money baselineBalance, ActivityWindow activityWindow) {
    return new Account(null, baselineBalance, activityWindow);
  }

  // ID 가 있는 Account 엔티티 생성
  // 이미 저장된 엔티티를 재구성할 때 사용
  public static Account withId(
          AccountId accountId, Money baselineBalance, ActivityWindow activityWindow) {
    return new Account(accountId, baselineBalance, activityWindow);
  }

  public Optional<AccountId> getId() {
    return Optional.ofNullable(this.id);
  }

  // 현재 총 잔액은 기준 잔고(baselineBalance) 에 ActivityWindow 의 모든 활동들의 잔고를 합한 값
  public Money calculateBalance() {
    return Money.add(this.baselineBalance, this.activityWindow.calculateBalance(this.id));
  }

  // 계좌에서 일정 금액 인출 시도
  // 성공한다면 새로운 활동 생성
  // 인출에 성공하면 true 리턴, 실패하면 false 리턴
  public boolean withdraw(Money money, AccountId targetAccountId) {
    if (!mayWithdraw(money)) {
      return false;
    }

    Activity withdrawal =
            new Activity(this.id, this.id, targetAccountId, LocalDateTime.now(), money);
    this.activityWindow.addActivity(withdrawal);

    return true;
  }

  // 출금 가능 상태인지 확인 (비즈니스 규칙 검증)
  private boolean mayWithdraw(Money money) {
    return Money.add(this.calculateBalance(), money.negate()).isPositiveOrZero();
  }

  // 계좌에 일정 금액 입금
  // 성공한다면 새로운 활동 생성
  // 입금에 성공하면 true 리턴, 실패하면 false 리턴
  public boolean deposit(Money money, AccountId sourceAccountId) {
    Activity deposit = new Activity(this.id, sourceAccountId, this.id, LocalDateTime.now(), money);
    this.activityWindow.addActivity(deposit);

    return true;
  }

  @Value
  public static class AccountId {
    private Long value;
  }
}

```

계좌에서 일어나는 입출금은 각각 _withdraw()_, _deposit()_ 메서드처럼 새로운 _Activity_ 를 _ActivityWindow_ 에 출금하는 것에 불과하다.

이제 입출금을 할 수 있는 _Account_ 엔티티가 있으므로 이를 중심으로 유스케이스를 구현하여 바깥 방향으로 나가보자.

Money.java
```java
package com.assu.study.clean_me.account.domain;

import java.math.BigInteger;
import lombok.NonNull;
import lombok.Value;

@Value
public class Money {
  public static Money ZERO = Money.of(0L);

  @NonNull private final BigInteger amount;

  public static Money of(long value) {
    return new Money(BigInteger.valueOf(value));
  }

  public boolean isPositiveOrZero() {
    return this.amount.compareTo(BigInteger.ZERO) >= 0;
  }

  public boolean isNegative() {
    return this.amount.compareTo(BigInteger.ZERO) < 0;
  }

  public boolean isPositive() {
    return this.amount.compareTo(BigInteger.ZERO) > 0;
  }

  public boolean isGreaterThenOrEqualTo(Money money) {
    return this.amount.compareTo(money.amount) >= 0;
  }

  public static Money add(Money a, Money b) {
    return new Money(a.amount.add(b.amount));
  }

  public static Money subtract(Money a, Money b) {
    return new Money(a.amount.subtract(b.amount));
  }

  public Money minus(Money money) {
    return new Money(this.amount.subtract(money.amount));
  }

  public Money plus(Money money) {
    return new Money(this.amount.add(money.amount));
  }

  public Money negate() {
    return new Money(this.amount.negate());
  }
}
```

ActivityWindow.java
```java
package com.assu.study.clean_me.account.domain;

import java.time.LocalDateTime;
import java.util.*;
import lombok.NonNull;

// 현재 계좌의 전체 계좌 활동 리스트에서 특정 범위의 계좌 활동만 볼수있는 범위
public class ActivityWindow {
  // 범위 안에서의 계좌 활동 리스트
  private List<Activity> activities;

  // 범위 안에서 첫 번째 활동의 시간
  public LocalDateTime getStartTimestamp() {
    return activities.stream()
        .min(Comparator.comparing(Activity::getTimestamp))
        .orElseThrow(IllegalStateException::new)
        .getTimestamp();
  }

  // 범위 안에서 마지막 활동의 시간
  public LocalDateTime getEndTimestamp() {
    return activities.stream()
        .max(Comparator.comparing(Activity::getTimestamp))
        .orElseThrow(IllegalStateException::new)
        .getTimestamp();
  }

  // 해당 기간동안 입금액과 출금액
  public Money calculateBalance(Account.AccountId accountId) {
    // 입금액
    Money depositBalance =
        activities.stream()
            .filter(a -> a.getTargetAccountId().equals(accountId))
            .map(Activity::getMoney)
            .reduce(Money.ZERO, Money::add);

    // 출금액
    Money withdrawalBalance =
        activities.stream()
            .filter(a -> a.getSourceAccountId().equals(accountId))
            .map(Activity::getMoney)
            .reduce(Money.ZERO, Money::add);

    return Money.add(depositBalance, withdrawalBalance.negate());
  }

  public ActivityWindow(@NonNull List<Activity> activities) {
    this.activities = activities;
  }

  public ActivityWindow(@NonNull Activity... activities) {
    this.activities = new ArrayList<>(Arrays.asList(activities));
  }

  public List<Activity> getActivities() {
    return Collections.unmodifiableList(this.activities);
  }

  public void addActivity(Activity activity) {
    this.activities.add(activity);
  }
}
```

Activity.java
```java
package com.assu.study.clean_me.account.domain;

import java.time.LocalDateTime;
import lombok.Getter;
import lombok.NonNull;
import lombok.RequiredArgsConstructor;
import lombok.Value;

// 계좌에 대한 모든 입출금 엔티티
@RequiredArgsConstructor
@Value
public class Activity {

  private ActivityId id;

  @NonNull private final Account.AccountId ownerAccountId;

  // 출금 계좌
  @NonNull private final Account.AccountId sourceAccountId;

  // 입금 계좌
  @NonNull private final Account.AccountId targetAccountId;

  @NonNull private final LocalDateTime timestamp;

  // 계좌 간 오간 금액
  @NonNull @Getter private final Money money;

  public Activity(
      @NonNull Account.AccountId ownerAccountId,
      @NonNull Account.AccountId sourceAccountId,
      @NonNull Account.AccountId targetAccountId,
      @NonNull LocalDateTime timestamp,
      @NonNull Money money) {
    this.id = null;
    this.ownerAccountId = ownerAccountId;
    this.sourceAccountId = sourceAccountId;
    this.targetAccountId = targetAccountId;
    this.timestamp = timestamp;
    this.money = money;
  }

  @Value
  public static class ActivityId {
    private final Long value;
  }
}
```

---

# 2. 유스케이스

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

유스케이스는 아래와 같은 단계를 따른다.

- **입력을 받음**
  - 인커밍 어댑터로부터 입력을 받음
- **비즈니스 규칙 검증**
  - 유스케이스는 도메인 로직에만 신경써야 하므로 입력 유효성은 다른 곳에서 검증
  - 도메인 엔티티와 비즈니스 규칙 검증의 책임을 공유함
- **모델 상태 조작**
  - 입력을 기반으로 모델의 상태 변경
  - 도메인 객체의 상태를 변경하고, 영속성 어댑터를 통하여 구현된 포트로 이 상태를 전달하여 저장
  - 유스케이스는 또 다른 아웃고잉 어댑터를 호출할 수도 있음
- **출력 반환**
  - 아웃고잉 어댑터에서 온 출력값을 최초 유스케이스를 호출한 어댑터로 반환할 출력 객체로 변환

> 입력 유효성 검증은 [3. 입력 유효성 검증: 입력 모델의 생성자](#3-입력-유효성-검증-입력-모델의-생성자) 을 참고하세요.

SendMoneyService.java (서비스)
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

SendMoneyUseCase.java (인커밍 포트 인터페이스)
```java
package com.assu.study.clean_me.account.application.port.in;

// 인커밍 포트 인터페이스
public interface SendMoneyUseCase {
  boolean sendMoney(SendMoneyCommand command);
}
```
> SendMoneyCommand.java 는 [3. 입력 유효성 검증: 입력 모델의 생성자](#3-입력-유효성-검증-입력-모델의-생성자) 에 나옵니다.

LoadAccountPort.java (아웃고잉 포트 인터페이스)
```java
package com.assu.study.clean_me.account.application.port.out;

import com.assu.study.clean_me.account.domain.Account;
import java.time.LocalDateTime;

// 계좌를 조회하는 아웃고잉 포트 인터페이스
public interface LoadAccountPort {
  Account loadAccount(Account.AccountId accountId, LocalDateTime baselineDate);
}
```

AccountLock.java (아웃고잉 포트 인터페이스)
```java
package com.assu.study.clean_me.account.application.port.out;

import com.assu.study.clean_me.account.domain.Account;

public interface AccountLock {
  void lockAccount(Account.AccountId accountId);

  void releaseAccount(Account.AccountId accountId);
}
```

UpdateAccountStatePort.java (아웃고잉 포트 인터페이스)
```java
package com.assu.study.clean_me.account.application.port.out;

import com.assu.study.clean_me.account.domain.Account;

// 계좌 상태를 업데이트하는 아웃고잉 포트 인터페이스
public interface UpdateAccountStatePort {
  void updateActivities(Account account);
}
```

MoneyTransferProperties.java
```java

```

> **`@Data` 애너테이션**  
> 
> `@Getter`, `@Setter`, `@ToString`, `@EqualsAndHashCode`, `@RequiredArgsConstructor`

ThresholdExceededException.java
```java
package com.assu.study.cleanme.account.application.service;

import com.assu.study.cleanme.account.domain.Money;

class ThresholdExceededException extends RuntimeException {
  public ThresholdExceededException(Money threshold, Money actual) {
    super(
        String.format(
            "Maximum threshold for transferring money exceeded: tried to transfer %s but threshold is %s!",
            actual, threshold));
  }
}
```

CleanMeConfiguration.java
```java
package com.assu.study.cleanme;

import com.assu.study.cleanme.account.application.service.MoneyTransferProperties;
import com.assu.study.cleanme.account.domain.Money;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(CleanMeConfigurationProperties.class)
public class CleanMeConfiguration {
  @Bean
  public MoneyTransferProperties moneyTransferProperties(
      CleanMeConfigurationProperties properties) {
    return new MoneyTransferProperties(Money.of(properties.getTransferThreshold()));
  }
}
```

> 위의 `@Configuration` 을 사용하여 설정 클래스를 만드는 방법에 대한 설명은 [3. 스프링 부트 프레임워크의 `자바 컨피그`로 설정 컴포넌트 구현: `@Configuration`](https://assu10.github.io/dev/2024/06/02/clean-application-composition/#3-스프링-부트-프레임워크의-자바-컨피그로-설정-컴포넌트-구현-configuration-enablejparepositories) 을 참고하세요.

CleanMeConfigurationProperties.java
```java
package com.assu.study.cleanme;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Data
@ConfigurationProperties(prefix = "cleanme")
public class CleanMeConfigurationProperties {
  private long transferThreshold = Long.MAX_VALUE;
}
```

서비스는 인커밍 포트 인터페이스인 _SendMoneyUseCase_ 를 구현하고, 계좌를 조회하기 위해 아웃고잉 포트 인터페이스인 _LoadAccountPort_ 를 호출한다.  
그리고 DB 의 계좌 상태 변경을 위해 _UpdateAccountStatePort_ 인터페이스를 호출한다.

위 컴포넌트들을 UML 로 표현하면 아래와 같다.

![UseCase 호출 흐름](/assets/img/dev/2024/0518/usecase.png)

하나의 서비스가 하나의 유스케이스를 구현하고, 도메인 모델을 변경하고, 변경된 상태를 저장하기 위해 아웃고잉 포트를 호출한다.

---

# 3. 입력 유효성 검증: 입력 모델의 생성자

입력 유효성 검증은 유스케이스 클래스의 책임은 아니지만 여전히 애플리케이션 계층의 책임이다.

호출하는 어댑터 쪽에서 유스케이스에 입력을 전달하기 전에 입력 유효성을 검증하게 되면 유스케이스는 하나 이상의 어댑터에서 호출될텐데 각 어댑터가 유효성 검증을 모두 구현해야 한다.

**애플리케이션 게층에서 입력 유효성을 검증하지 않으면 애플리케이션 코어의 바깥쪽으로부터 유효하지 않은 입력값을 받게 되어 모델의 상태를 해칠 수 있다.**

**입력 유효성은 애플리케이션 계층의 유스케이스 클래스가 아닌 입력 모델**에서 한다.  
**더 정확히는 입력 모델의 생성자 내부에서 입력 유효성을 검증**한다.

[2. 유스케이스](#2-유스케이스) 에 나온 _SendMoneyCommand_ 클래스가 입력 모델인데 여기에 입력 유효성 검증을 추가해보자.

송금을 위해서는 출금 계좌와 입금 계좌의 ID, 송금할 금액이 필요하다.  
모든 파라메터는 null 이 아니어야 하고 송금할 금액은 0보다 커야 한다.

**_SendMoneyCommand_ 의 필드에 final 을 지정해 불변 필드로 만듦으로써 생성에 성공하고 나면 상태는 유효하고 이후에 잘못된 상태로 변경할 수 없다는 사실을 보장**할 수 있다.

_SendMoneyCommand_ 는 유스케이스 API 의 일부이기 때문에 인커밍 포트 패키지에 위치한다. 따라서 유효성 검증이 애플리케이션 코어(육각형 아키텍처의 육각형 내부) 에 있지만 
유스케이스 코드를 오염시키지 않는다.

**유효성 검증은 [Bean Validation API](https://beanvalidation.org/) 가 사실상 표준 라이브러리**이다.  
Bean Validation API 를 사용하면 유효성 규칙들을 필드의 애너테이션으로 표현할 수 있다.

SendMoneyCommand.java (입력 모델, 생성자에서 입력 유효성 검증하는 예시)
```java
package com.assu.study.clean_me.account.application.port.in;

import com.assu.study.clean_me.account.domain.Account;
import com.assu.study.clean_me.account.domain.Money;
import com.assu.study.clean_me.common.SelfValidating;
import jakarta.validation.constraints.NotNull;
import lombok.Value;

// 입력 모델
@Value
public class SendMoneyCommand extends SelfValidating<SendMoneyCommand> {
  @NotNull private final Account.AccountId sourceAccountId;

  @NotNull private final Account.AccountId targetAccountId;

  @NotNull private final Money money;

  public SendMoneyCommand(
          Account.AccountId sourceAccountId, Account.AccountId targetAccountId, Money money) {
    this.sourceAccountId = sourceAccountId;
    this.targetAccountId = targetAccountId;
    this.money = money;

    if (!money.isPositive()) {
      throw new IllegalArgumentException();
    }
    // 각 필드에 지정된 Bean Validation 애너테이션 검증
    this.validateSelf();
  }
}
```

SelfValidating.java
```java
package com.assu.study.clean_me.common;

import jakarta.validation.*;

import java.util.Set;

public abstract class SelfValidating<T> {
  private Validator validator;

  public SelfValidating() {
    ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
    validator = factory.getValidator();
  }

  // 필드에 지정된 Bean Validation 애너테이션(@NotNull 같은) 을 검증 후 유효성 검증 규칙을 위반할 경우 예외 던짐
  protected void validateSelf() {
    Set<ConstraintViolation<T>> violations = validator.validate((T) this);
    if (!violations.isEmpty()) {
      throw new ConstraintViolationException(violations);
    }
  }
}
```

**입력 모델에 있는 입력 유효성 검증 코드를 통해 유스케이스 구현체 주위에 오류 방지 계층 (anti corruption layer) 를 만들었다.**  
여기서의 계층은 계층형 아키텍처에서의 계층이 아니라 잘못된 입력을 호출자에게 돌려주는 유스케이스 보호막을 의미한다.

> **안티코럽션 계층 (anti corruption layer)**  
>
> 하나의 바운디드 컨텍스트를 다른 바운디드 컨텍스트와 격리시키는 계층  
> 
> 안티코럽션 계층에 대한 또 다른 설명은 [5.1. 공개 호스트 서비스 (Open host service): Anti-corruption Layer](https://assu10.github.io/dev/2024/04/27/ddd-bounded-context/#51-공개-호스트-서비스-open-host-service-anti-corruption-layer) 를 참고하세요.

---

# 4. 빌더 패턴보다는 생성자 사용

위의 입력 모델인 _SendMoneyCommand_ 는 생성자에 많은 책임이 있다.

클래스가 불변이므로 생성자의 인자 리스트에는 클래스의 각 속성에 해당하는 파라메터들이 포함되어 있다.  
또한 생성자가 파라메터의 유효성 검증까지 하고 있기 때문에 유효하지 않은 상태의 객체를 만드는 것은 불가능하다.

만일 파라메터가 많은 경우 빌더 패턴을 사용하는 것이 과연 옳은 일일까?

```java
SendMoneyCommandBuiler
        .sourceAccountId(new AccountId(1L))
        .targetAccountIdf(new AcountId(2L))
        // ...
        .build();
```

위처럼 **빌더 패턴을 사용할 경우 새로운 필드를 추가하는 상황에서 빌더를 호출하는 코드에 새로운 필드를 추가하는 것을 잊을수도 있다.**

컴파일러는 유효하지 않은 상태의 불변 객체를 만들려는 시도에 대해서는 감지를 하지 못하기 때문에 런타임 에러가 나게 된다.

**빌더 패턴 대신 생성자를 직접 사용했다면 새로운 필드를 추가하거나 삭제할 때 컴파일 에러를 따라 나머지 코드에 변경 사항을 반영**할 수 있다.

긴 파라메터 리스트로 충분히 깔끔하게 포매팅할 수 있고, IDE 는 파라메터명 힌트도 주기 때문에 빌더 패턴은 되도록 지양하는 것이 좋다.

---

# 5. 유스케이스마다 다른 입력 모델

> 결론은 유스케이스마다 다른 입력 모델을 사용하자!

다른 유스케이스에 동일한 입력 모델을 사용하고 싶을 경우가 있다.  
예) '계좌 등록' 과 '계좌 정보 업데이트'

계좌 등록과 계좌 정보 업데이트 모두 거의 똑같은 계좌 상세 정보가 필요하다.  
차이점은 계좌 등록 유스케이스는 계좌를 등록시킬 소유자의 ID 가 필요하고, 계좌 정보 업데이트는 계좌 정보 ID 가 필요하다.

그래서 2개의 유스케이스에서 같은 입력 모델을 공유할 경우 '계좌 등록' 시엔 '계좌 정보 ID' 를, '계좌 정보 업데이트' 시엔 '소유자의 ID' 에 null 값을 허용해야 한다.

**불변 커맨드 객체의 필드에 null 을 유효한 상태로 받아들이는 것은 code smell** 이다.

> **code smell**  
> 
> 코드에 더 깊은 문제가 있을수도 있음을 암시

또한 등록 유스케이스와 업데이트 유스케이스는 **서로 다른 입력 유효성 검증이 필요하기 때문에 유스케이스에 커스텀 유효성 검증을 넣어야 하고 이것은 비즈니스 코드를 
입력 유효성 검증과 관련된 관심사로 오염**시키게 된다.

**각 유스케이스 전용 입력 모델은 유스케이스를 훨씬 명확하게 만들고 다른 유스케이스와 결합도 제거하여 불필요한 부수효과를 발생하지 않게 한다.**

물론 들어오는 데이터를 각 유스케이스에 해당하는 입력 모델에 매핑해야 한다.

> 매핑 전략에 대해서는 [Clean Architecture - 경계 간 매핑 전략](https://assu10.github.io/dev/2024/06/01/clean-layer-mapping/) 을 참고하세요.

---

# 6. 비즈니스 규칙 검증

## 6.1. 입력 유효성 검증과 비즈니스 규칙 검증

입력 유효성 검증과 비즈니스 규칙 검증의 차이

|     | 입력 유효성 검증                                                                | 비즈니스 규칙 검증                                |
|:---:|:-------------------------------------------------------------------------|:------------------------------------------|
|     | - 유스케이스 로직의 일부가 아님                                                       | - 유스케이스 로직의 일부                            |
| 구분점 | - 도메인 모델의 현재 상태에 접근할 필요가 없음<br />- `@NotNull` 애너테이션을 붙이는 것처럼 선언적으로 구현 가능 | - 도메인 모델의 현재 상태에 접근 필요<br />- 비즈니스 맥락이 필요 |
|     | - 구문상의 유효성을 검증                                                           | - 유스케이스의 맥락 속에서 의미적인 유효성을 검증              |

위 차이로 볼 때 '송금 금액은 0 보다 커야 함' 은 모델에 접근하지 않고도 검증될 수 있으므로 입력 유효성 검증으로 구현할 수 있다.

'출금 계좌는 초과 출금 되어서는 안됨' 은 출금 계좌와 입금 계좌의 존재 여부를 확인하기 위해 모델의 현재 상태에 접근해야 하므로 비즈니스 규칙 검증으로 구현할 수 있다.

쉽게 말하면 **유효성 검증 로직이 현재 모델의 상태에 접근해야 하는지 여부에 따라 비즈니스 규칙 검증과 입력 유효성 검증을 판단**하면 된다.

---

## 6.2. 비즈니스 규칙 검증

비즈니스 규칙 검증 위치는 상황에 따라 3 군데에서 할 수 있다.
- **도메인 엔티티 내부에서 검증**
  - 가장 좋은 방법으로 이 규칙을 지켜야하는 비즈니스 로직 바로 옆에 규칙이 존재하므로 위치를 정하는 것도 쉽고 추론도 쉬움
- **유스케이스 코드에서 도메인 엔티티를 사용하기 전에 검증**
  - 도메인 엔티티에서 비즈니스 규칙 검증이 어려울 경우 사용
- **DB 에서 도메인 모델을 로드하여 상태 검증**
  - 복잡한 비즈니스 규칙의 경우 사용
  - 어쨌든 도메인 모델을 로드해야 한다면 비즈니스 규칙은 도메인 엔티티 내에서 구현해야 함

Account.java (도메인 엔티티 내부에서 비즈니스 규칙을 검증하는 예시)
```java
public class Account {
    // ...
    // 계좌에서 일정 금액 인출 시도
    // 성공한다면 새로운 활동 생성
    // 인출에 성공하면 true 리턴, 실패하면 false 리턴
    public boolean withdraw(Money money, AccountId targetAccountId) {
      if (!mayWithdraw(money)) {
        return false;
      }
      // ...
    }

    // 출금 가능 상태인지 확인 (비즈니스 규칙 검증)
    private boolean mayWithdraw(Money money) {
      return Money.add(this.calculateBalance(), money.negate()).isPositiveOrZero();
    }
}
```

유스케이스 코드에서 도메인 엔티티를 사용하기 전에 검증하는 예시
```java
public class SampleSendMoneyService implements SendMoneyUseCase {
    // ...
  
  @Override 
  public boolean sendMoney(SendMoneyCommand command) {
      requireAccountExists(command.getSourceAccountId);
      requireAccountExists(command.getTargetAccountId);
      // ...
  }
}
```

위 코드는 비즈니스 규칙 유효성을 검증하는 코드를 호출한 후 유효성 검증이 실패할 경우 유효성 검증 전용 예외를 던진다.  
사용자와 통신하는 어댑터는 이 예외에 대해 적절히 처리한다.

---

# 7. 풍부한 도메인 모델 (rich domain model) vs 빈약한 도메인 모델 (anemic domain model)

## 7.1. 풍부한 도메인 모델 (rich domain model)

풍부한 도메인 모델에서 **애플리케이션 코어에 있는 엔티티에서 가능한 많은 도메인 로직이 구현**된다.

엔티티들은 상태를 변경하는 메서드를 제공하고, 비즈니스 규칙에 맞는 유효한 변경만을 허용한다.

풍부한 도메인 모델 사용 시 유스케이스는 도메인 모델의 진입점으로 동작하는데 유스케이스는 사용자의 의도만을 표현하며, 이 의도를 실제 작업을 수행하는 도메인 엔티티 메서드 호출로 변환한다.

**많은 비즈니스 규칙이 유스케이스 구현체 대신 엔티티에 위치**하게 된다.

예를 들어 '송금하기' 유스케이스 서비스는 아래와 같이 동작한다.
- 출금 계좌와 입금 계좌 엔티티 로드
- _withdraw()_, _deposit()_ 메서드를 호출한 후 결과를 다시 DB 로 보냄

---

## 7.2. 빈약한 도메인 모델 (anemic domain model)

빈약한 도메인 모델에서 엔티티에 큰 기능이 없다.

**엔티티는 상태를 표현하는 필드로 getter/setter 만 포함하고 어떤 도메인 로직도 갖고 있지 않다.**  
즉, **도메인 로직이 유스케이스 클래스에 구현**되어 있다는 말이다.

빈약한 도메인 모델에서 유스케이스는 아래와 같은 역할을 한다.
- 비즈니스 규칙 검증
- 엔티티의 상태 변경
- DB 저장을 담당하는 아웃고잉 포트에 엔티티를 전달

---

풍부한 도메인 모델은 엔티티에 많은 도메인 로직이 있는 반면, 빈약한 도메인 모델은 유스케이스에 도메인 로직이 있다.

두 가지 스타일 모두 어떤 것이 옳다고 할 수 없으므로 각자 선택하여 구현하면 된다.

---

# 8. 유스케이스마다 다른 출력 모델

> 결론은 유스케이스마다 다른 출력 모델을 사용하자!

입력 모델과 비슷하게 출력 모델도 가능하면 각 유스케이스에 맞게 구체적일수록 좋으며 **출력 모델은 호출자에게 꼭 필요한 데이터**만 들고 있어야 한다.

예를 들어 '송금하기' 유스케이스 코드를 보자.

SendMoneyUseCase.java
```java
package com.assu.study.clean_me.account.application.port.in;

// 인커밍 포트 인터페이스
public interface SendMoneyUseCase {
  boolean sendMoney(SendMoneyCommand command);
}
```

boolean 값 하나만을 반환하며 이는 가장 구체적인 최소한의 값이다.

업데이트된 _Account_ 를 통째로 반환하고 싶을 수도 있겠지만 '송금하기' 유스케이스에서 정말 이 데이터가 호출자에게 필요한 것인지 생각해보아야 한다.  
만일 그렇다면 다른 호출자도 사용할 수 있도록 해당 데이터를 접근할 수 있는 전용 유스케이스를 만들어야 한다.

즉, **가능한 적게 반환**하는 것이 좋다.

**유스케이스들 간에 출력 모델을 공유하게 되면 유스케이스들도 강하게 결합**된다.

한 유스케이스에서 출력 모델에 새로운 필드가 필요해지면 이 값과 관련없는 다른 유스케이스에서도 이 필드를 처리해야 한다.

**공유 모델은 장기적으로 점점 커지게 되어있기 때문에 단일 책임 원칙(SRP, Single Responsibility Principle) 을 적용하고 모델을 분리하여 유지하는 것이 
유스케이스 결합을 제거**하는게 도움이 된다.

비슷한 이유로 **도메인 엔티티를 출력 모델로 사용하게 되면 도메인 엔티티를 변경할 이유가 늘어나게 되므로 엔티티를 출력 모델로 사용하지 않는 것이 좋다.**

> 엔티티를 입력 모델이나 출력 모델로 사용하는 것에 대해서는 추후 좀 더 상세히 다룰 예정입니다. (p. 50)

---

# 9. 읽기 전용 유스케이스

조회만 필요한 경우 이를 위한 새로운 유스케이스를 구현해야 하는지 생각해보자.

읽기 전용 작업을 유스케이스라고 하는 것은 좀 이상하다.

애플리케이션 코어의 관점에서 조회는 간단한 데이터 쿼리이다.  
그렇기 때문에 프로젝트 맥락에서 유스케이스로 간주되지 않는다면 실제 유스케이스와 구분하기 위해 쿼리로 구현할 수 있다.

이를 구현하는 방법은 **쿼리를 위한 인커밍 전용 포트(_GetAccountBalanceQuery_) 를 만들고 이를 쿼리 서비스(_GetAccountBalanceService_) 로 구현**하는 것이다.

GetAccountBalanceQuery.java (조회를 위한 인커밍 포트)
```java
package com.assu.study.clean_me.account.application.port.in;

import com.assu.study.clean_me.account.domain.Account;
import com.assu.study.clean_me.account.domain.Money;

// 쿼리(=조회) 를 위한 인커밍 전용 포트
public interface GetAccountBalanceQuery {
  Money getAccountBalance(Account.AccountId accountId);
}
```

GetAccountBalanceService.java (조회를 위한 쿼리 서비스)
```java
package com.assu.study.clean_me.account.application.service;

import com.assu.study.clean_me.account.application.port.in.GetAccountBalanceQuery;
import com.assu.study.clean_me.account.application.port.out.LoadAccountPort;
import com.assu.study.clean_me.account.domain.Account;
import com.assu.study.clean_me.account.domain.Money;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;

// 조회를 위한 서비스
@RequiredArgsConstructor
class GetAccountBalanceService implements GetAccountBalanceQuery {
  // DB 로부터 데이터 로드를 위해 호출하는 아웃고잉 포트
  private final LoadAccountPort loadAccountPort;

  @Override
  public Money getAccountBalance(Account.AccountId accountId) {
    return loadAccountPort.loadAccount(accountId, LocalDateTime.now()).calculateBalance();
  }
}
```

쿼리 서비스는 유스케이스와 비슷한 방식으로 동작한다.

인커밍 포트(_GetAccountBalanceQuery_) 를 구현하고, DB 로부터 데이터를 로드하기 위해 아웃고잉 포트(_LoadAccountPort_) 를 호출한다.

읽기 전용 쿼리는 쓰기가 가능한 유스케이스(=command) 와 코드상으로 명확하게 구분되며, 이는 CQRS 개념와 잘 맞는다.

> CQRS 에 대한 상세한 내용은 [DDD - CQRS](https://assu10.github.io/dev/2024/05/05/ddd-cqrs/) 를 참고하세요.

위에서 쿼리 서비스는 아웃고잉 포트로 쿼리를 전달하는 기능만 있지만 여러 계층에 걸쳐 같은 모델을 사용한다면 다른 방법으로 클라이언트가 아웃고잉 포트를 직접 호출하게 할 수도 있다.

> 클라이언트가 아웃고잉 포트를 직접 호출하게 하는 방법은 추후 상세히 다룰 예정입니다. (p. 51)

---

# 정리하며...

입출력 모델을 독립적으로 모델링하면 부수효과를 피할 수 있다.

물론 각 유스케이스마다 별도의 모델을 만들어야 하고 이 모델과 엔티티를 매핑해야 하는 작업이 필요하다.

하지만 유스케이스별로 모델을 만들면 유스케이스를 명확히 이해할 수 있고, 장기적으로 유지보수하기도 쉽다.  
또한 여러 명의 개발자가 다른 사람이 작업 중인 유스케이스를 건드리지 않은 채로 여러 개의 유스케이스를 동시에 작업할 수도 있다.

꼼꼼한 입력 유효성 검증과 **유스케이스별 입출력 모델은 지속 가능한 코드**에 도움이 된다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)
* [공식 문서를 통해 알아보는 @Value(feat. @ToString, @EqualsAndHashCode, @AllArgsConstructor, @FieldDefaults, @Getter) + 사용시 주의사항(단점)](https://siahn95.tistory.com/171#google_vignette)
* [Bean Validation API](https://beanvalidation.org/)