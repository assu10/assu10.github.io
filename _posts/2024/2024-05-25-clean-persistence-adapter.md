---
layout: post
title:  "Clean Architecture - 영속성 어댑터 구현, 트랜잭션, 포트 인터페이스"
date: 2024-05-25
categories: dev
tags: clean architecture persistence-adapter
---

[2.1. 데이터베이스 주도 설계를 유도](https://assu10.github.io/dev/2024/05/06/clean-basic/#21-%EB%8D%B0%EC%9D%B4%ED%84%B0%EB%B2%A0%EC%9D%B4%EC%8A%A4-%EC%A3%BC%EB%8F%84-%EC%84%A4%EA%B3%84%EB%A5%BC-%EC%9C%A0%EB%8F%84) 에서 
계층형 아키텍처는 영속성 계층에 의존하게 되어 데이터베이스 주도 설계가 된다고 하였다.

이 포스트에서는 이러한 의존성을 역전시키기 위해 영속성 계층을 애플리케이션 계층의 플러그인으로 만드는 방법에 대해 살펴본다.

> 소스는 [github](https://github.com/assu10/clean-architecture/tree/feature/chap06)  에 있습니다.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 의존성 역전 (DI, Dependency Inversion)](#1-의존성-역전-di-dependency-inversion)
* [2. 영속성 어댑터의 책임](#2-영속성-어댑터의-책임)
* [3. 포트 인터페이스 나누기](#3-포트-인터페이스-나누기)
* [4. 영속성 어댑터 나누기: 애그리거트 당 하나의 영속성 어댑터](#4-영속성-어댑터-나누기-애그리거트-당-하나의-영속성-어댑터)
* [5. 스프링 데이터 JPA](#5-스프링-데이터-jpa)
* [6. 트랜잭션](#6-트랜잭션)
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

**영속성 어댑터는 애플리케이션 서비스에 영속성 기능을 제공**한다.

아래는 [1. 의존성 역전 (DI, Dependency Inversion)](https://assu10.github.io/dev/2024/05/19/clean-web-adapter/#1-%EC%9D%98%EC%A1%B4%EC%84%B1-%EC%97%AD%EC%A0%84-di-dependency-inversion) 에서 
보았던 어댑터 자체와 애플리케이션 코어와 상호작용 하는 포트에 초점을 맞춘 흐름도이다.

![인커밍 어댑터의 흐름](/assets/img/dev/2024/0519/adapter.png)

**인커밍 어댑터는 애플리케이션 서비스에 의해 구현된 인터페이스인 전용 포트를 통해 애플리케이션 계층과 통신**한다.

아래는 영속성 어댑터가 애플리케이션 서비스에 영속성 기능을 제공하기 위해 어떻게 의존성 역전 원칙을 적용하는지 보여준다.

![아웃고잉 어댑터의 흐름](/assets/img/dev/2024/0525/persistence.png)

**코어의 서비스가 아웃고잉 어댑터인 영속성 어댑터에 접근하기 위해 아웃고잉 포트를 사용**하고 있다.

애플리케이션 서비스에서 영속성 기능을 사용하기 위해 포트 인터페이스를 호출하는데 이 **포트는 실제로 영속성 작업을 수행하고, DB 와 통신할 책임을 가진 영속성 
어댑터 클래스에 의해 구현**된다.

**육각형 아키텍처에서 영속성 어댑터는 아웃고잉 어댑터 혹은 Driven 어댑터**이다.  
**(= 애플리케이션에 의해 호출만 되고 애플리케이션을 호출하지는 않음)**

**포트는 애플리케이션 서비스와 영속성 코드 사이의 간접적인 계층**이다.  
**영속성 계층에 대한 코드 의존성을 없애기 위해 이러한 간접 계층을 추가하는데 이 간접 계층을 추가하면 영속성 코드를 리팩터링하더라도 코어 코드를 변경하지 않아도 된다.**

---

# 2. 영속성 어댑터의 책임

영속성 어댑터는 일반적으로 아래와 같은 일을 한다.

- **입력을 받음**
  - 포트 인터페이스를 통해 입력받음
  - 입력 모델은 인터페이스가 지정한 도메인 엔티티나 특정 DB 연산 전용 객체임
  - **영속성 어댑터의 입력 모델은 영속성 어댑터 내부에 있는 것이 아니라 애플리케이션 코어에 있음**
  - **따라서 영속성 어댑터 내부를 변경해도 코어에 영향을 미치지 않음**
- **입력을 DB 포맷으로 매핑**
  - DB 를 쿼리하거나 변경할 때 사용 가능한 포맷으로 입력 모델을 매핑
  - 자바는 보통 JPA 를 사용하기 때문에 입력 모델을 DB 테이블 구조를 반영한 JPA 엔티티 객체로 매핑함
  - > 입력 모델을 JPA 엔티티로 매핑하는 것이 들이는 노력에 비해 득이 없는 일이 될 수도 있어서 매핑하지 않는 전략을 사용하기 함  
이 부분에 대해서는 [Clean Architecture - 경계 간 매핑 전략](http://localhost:4000/dev/2024/06/01/clean-layer-mapping/) 을 참고하세요.
- **입력을 DB 로 보냄**
  - DB 에 쿼리를 날리고 쿼리 결과를 받아옴
- **DB 출력을 애플리케이션 포맷으로 매핑**
  - DB 응답을 포트에 정의된 출력 모델로 매핑하여 반환
  - **출력 모델은 영속성 어댑터가 아닌 애플리케이션 코어에 있음**
- **출력 반환**

**중요한 점은 영속성 어댑터의 입출력 모델이 영속성 어댑터가 아니라 애플리케이션 코어에 있다는 것**이다.  
애플리케이션 코어에 입출력 모델이 있어야 영속성 어댑터 내부를 변경하더라도 코어에 영향을 미치지 않는다.

---

# 3. 포트 인터페이스 나누기

DB 연산을 정의하고 있는 포트 인터페이스를 나누는 것에 대해 알아보자.

아래는 특정 엔티티가 필요로하는 모든 DB 연산을 하나의 리포지터리 인터페이스에 넣는 안 좋은 예시이다.

![하나의 아웃고잉 포트 인터페이스에 모든 서비스가 의존하는 안 좋은 예시](/assets/img/dev/2024/0525/persistence_1.png)

위 그림을 보면 하나의 아웃고잉 포트 인터페이스에 모든 DB 연산을 모아두어 모든 서비스가 실제로 필요하지 않은 메서드에 의존하게 된다.  
**DB 연산에 의존하는 각 서비스는 포트 인터페이스에서 단 하나의 메서드만 사용하더라도 하나의 '넓은' 포트 인터페이스에 의존성을 갖게 되어 코드에 불필요한 의존성**이 생긴다.

필요하지 않은 메서드에 의해 생긴 의존성은 코드를 이해하기 하기 어렵게 만들고 테스트하기 어렵게 만든다.

예를 들어 _RegisterAccountService_ 의 단위 테스트를 작성할 때 _AccountRepository_ 인터페이스의 어떤 메서드를 모킹할지 찾아야 한다.  
이렇게 인터페이스의 일부만 모킹하는 것은 다음에 테스트를 작성하는 사람에게 인터페이스 전체가 모킹되었다고 오해하게 만드는 상황을 벌어지게 할 수도 있다.

인터페이스 분리 원칙 (ISP, Interface Segregation Principle) 은 클라이언트가 오로지 자신이 필요로 하는 메서드만 알면 되도록 
넓은 인터페이스 대신 특화된 인터페이스를 가져야한다고 한다.

> SOLID 에 대한 설명은 [Clean Architecture - 의존성 역전 (Dependency Inversion Principle)](https://assu10.github.io/dev/2024/05/11/clean-dependency-inversion/) 을 참고하세요.

ISP 원칙을 아웃고잉 포트에 적용하면 아래와 같다.

![인터페이스 분리 원칙을 적용한 좋은 예시](/assets/img/dev/2024/0525/persistence_2.png)

**인터페이스 분리 원칙을 적용하여 불필요한 의존성을 제거하고 기존 의존성을 눈에 더 잘 띄게 만들었다.**

이제 각 서비스는 실제로 필요한 메서드에만 의존하게 되고, 포트 이름도 포트의 역할을 명확하게 잘 표현하고 있다.

테스트를 할 때도 포트 당 하나의 메서드만 있을 것이기 때문에 어떤 메서드를 모킹할 지 고민할 필요가 없다.

이렇게 매우 좁은 포트를 만드는 것은 코딩을 plug-and-play 경험으로 만든다.

> **plug-and-play**  
> 
> 재설정하거나 조정하는 과정없이 연결하는 즉시 완벽하게 작동하는 방식

---

# 4. 영속성 어댑터 나누기: 애그리거트 당 하나의 영속성 어댑터

아래 그림에서는 모든 영속성 포트를 구현한 단 하나의 영속성 어댑터 클래스가 있다.

![인터페이스 분리 원칙을 적용한 좋은 예시](/assets/img/dev/2024/0525/persistence_2.png)

하지만 **영속성 연산이 필요한 도메인 클래스(or DDD 에서의 애그리거트) 하나 당 하나의 영속성 어댑터를 구현하는 방식**도 있다.

> **애그리거트**  
> 
> 불변식을 만족하여 하나의 단위로 취급될 수 있는 연관 객체의 모음  
> 애그리거트에 대한 좀 더 상세한 설명은 [1. 애그리거트](https://assu10.github.io/dev/2024/04/06/ddd-aggregate/#1-%EC%95%A0%EA%B7%B8%EB%A6%AC%EA%B1%B0%ED%8A%B8) 를 참고하세요.

![하나의 애그리거트 당 하나의 영속성 어댑터를 만들어서 여러 개의 영속성 어댑터 생성](/assets/img/dev/2024/0525/persistence_3.png)

**위와 같이 하면 영속성 어댑터들은 각 영속성 기능을 이용하는 도메인 경계를 따라 자동으로 나눠진다.**

영속성 어댑터를 훨씬 더 많은 클래스로 나눌 수 있다.  
예를 들어 **JPA 나 ORM 매퍼를 이용한 영속성 포트도 구현하면서 다른 종류의 포트도 함께 구현**하는 경우가 이에 해당한다.  
이 때는 **JPA 어댑터 하나와 SQL 어댑터 하나를 만들고 각각 영속성 포트의 일부분을 구현**하면 된다.

도메인 코드는 영속성 포트에 의해 정의된 명세를 어떤 클래스가 충족시키는지 관심이 없다.  
모든 포트가 구현되어 있기만 한다면 영속성 계층에서 자유롭게 작업을 해도 된다.

**<u>애그리거트 당 하나의 영속성 어댑터</u> 접근 방식은 여러 개의 바운디드 컨텍스트의 영속성 요구사항을 분리하기 위한 좋은 조건**이 된다.

아래는 계좌 유스케이스를 책임지는 account 바운디드 컨텍스트와 청구 유스케이스를 책임지는 billing 바운디드 컨텍스트의 영속성 어댑터 예시이다.

![각 바운디드 컨텍스트가 영속성 어댑터들을 하나씩 갖고 있어서 바운디드 컨텍스트 간의 경계를 명확함](/assets/img/dev/2024/0525/persistence_4.png)

위 그림을 보면 **각 바운디드 컨텍스트가 영속성 어댑터(들)을 하나씩 갖고 있어서 바운디드 컨텍스트 간의 경계가 명확하게 구분**된다.

account 맥락의 서비스가 billing 맥락의 영속성 어댑터에 접근하지 않고 그 반대도 마찬가지이다.  
**어떤 맥락이 다른 맥락에 있는 무엇인가를 필요로 한다면 전용 인커밍 포트를 통해 접근**해야 한다.

---

# 5. 스프링 데이터 JPA

이제 위에서 본 _AccountPersistenceAdapter_ 를 구현해본다.

이 영속성 어댑터는 DB 로부터 계좌를 가져오거나 저장할 수 있어야 한다.

[1. 도메인 모델 구현](https://assu10.github.io/dev/2024/05/18/clean-usecase/#1-%EB%8F%84%EB%A9%94%EC%9D%B8-%EB%AA%A8%EB%8D%B8-%EA%B5%AC%ED%98%84) 에서 본 Account 엔티티를 참고 삼아 다시 한번 보자.

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

_Account_ 클래스는 getter/setter 만 가진 간단한 데이터 클래스가 아니다.  
최대한 불변성을 유지하고 유효한 상태의 Account 엔티티만 생성할 수 있는 팩토리 메서드를 제공한다.  
출금 전에 계좌의 잔고를 확인하는 등의 유효성 검증을 모든 상태 변경 메서드에서 수행하므로 유효하지 않은 도메인 모델을 생성할 수 없다.

아래는 데이터베이스의 상태를 표현하는 **`@Entity` 애너테이션이 추가된 클래스**들이다.

AccountJpaEntity.java
```java
package com.assu.study.clean_me.account.adapter.out.persistence;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "account")
@Data
@AllArgsConstructor
@NoArgsConstructor
class AccountJpaEntity {
  @Id @GeneratedValue private Long id;
}
```

ActivityJpaEntity.java
```java
package com.assu.study.clean_me.account.adapter.out.persistence;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

// 특정 계좌에 대한 모든 활동을 저장하는 엔티티
@Entity
@Table(name = "activity")
@Data
@AllArgsConstructor
@NoArgsConstructor
class ActivityJpaEntity {
  @Id @GeneratedValue private Long id;

  @Column private LocalDateTime timestamp;

  @Column private Long ownerAccountId;

  @Column private Long sourceAccountId;

  @Column private Long targetAccountId;

  @Column private Long amount;
}
```

이제 기본적인 CRUD 기능과 DB 의 데이터를 로드하기 위한 **리포지터리 인터페이스**를 생성하기 위해 스프링 데이터를 사용한다.

AccountRepository.java
```java
package com.assu.study.clean_me.account.adapter.out.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

interface AccountRepository extends JpaRepository<AccountJpaEntity, Long> {}
```

ActivityRepository.java
```java
package com.assu.study.clean_me.account.adapter.out.persistence;

import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface ActivityRepository extends JpaRepository<ActivityJpaEntity, Long> {

  @Query(
      "SELECT a FROM ActivityJpaEntity a "
          + "WHERE a.ownerAccountId = :ownerAccountId "
          + "  AND a.timestamp >= :since")
  List<ActivityJpaEntity> findByOwnerSince(
      @Param("ownerAccountId") Long ownerAccountId, @Param("since") LocalDateTime since);

  @Query(
      "SELECT SUM(a.amount) FROM ActivityJpaEntity a "
          + "WHERE a.targetAccountId = :accountId "
          + "  AND a.ownerAccountId = :accountId "
          + "  AND a.timestamp < :until")
  Long getDepositBalanceUntil(
      @Param("accountId") Long accountId, @Param("until") LocalDateTime until);

  @Query(
      "SELECT sum(a.amount) FROM ActivityJpaEntity a "
          + "WHERE a.sourceAccountId = :accountId "
          + "  AND a.ownerAccountId = :accountId "
          + "  AND a.timestamp < :until")
  Long getWithdrawalBalanceUntil(
      @Param("accountId") Long accountId, @Param("until") LocalDateTime until);
}
```

JPA 엔티티와 리포지터리를 만들었으니 이제 영속성 기능을 제공하는 **영속성 어댑터**를 구현해본다.

AccountPersistenceAdapter.java
```java
package com.assu.study.clean_me.account.adapter.out.persistence;

import com.assu.study.clean_me.account.application.port.out.LoadAccountPort;
import com.assu.study.clean_me.account.application.port.out.UpdateAccountStatePort;
import com.assu.study.clean_me.account.domain.Account;
import com.assu.study.clean_me.account.domain.Activity;
import com.assu.study.clean_me.common.PersistenceAdapter;
import jakarta.persistence.EntityExistsException;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;

@PersistenceAdapter
@RequiredArgsConstructor
class AccountPersistenceAdapter implements LoadAccountPort, UpdateAccountStatePort {

  private final AccountRepository accountRepository;
  private final ActivityRepository activityRepository;
  private final AccountMapper accountMapper;

  // Account 도메인 엔티티를 DB 로부터 가져와서 반환
  @Override
  public Account loadAccount(Account.AccountId accountId, LocalDateTime baselineDate) {
    // 계좌 정보 조회
    AccountJpaEntity account =
        accountRepository.findById(accountId.getValue()).orElseThrow(EntityExistsException::new);

    // 해당 계좌의 특정 시간까지의 활동 조회
    List<ActivityJpaEntity> activityJpaEntities =
        activityRepository.findByOwnerSince(accountId.getValue(), baselineDate);

    // 특정 시간까지의 모든 출금 정보 조회
    Long withdrawalBalance =
        orZero(activityRepository.getWithdrawalBalanceUntil(account.getId(), baselineDate));

    // 특정 시간까지의 모든 입금 정보 조회
    Long depositBalance =
        orZero(activityRepository.getDepositBalanceUntil(accountId.getValue(), baselineDate));

    return accountMapper.mapToDomainEntity(
        account, activityJpaEntities, withdrawalBalance, depositBalance);
  }

  private Long orZero(Long value) {
    return value == null ? 0L : value;
  }

  // 계좌 상태 업데이트
  // 새로운 계좌 활동을 DB 에 저장
  @Override
  public void updateActivities(Account account) {
    // Account 엔티티의 모든 활동을 순회하여 id 가 있는지 확인 후 없다면 새로운 활동 저장
    for (Activity activity : account.getActivityWindow().getActivities()) {
      if (activity.getId() == null) {
        activityRepository.save(accountMapper.mapToJpaEntity(activity));
      }
    }
  }
}
```

AccountMapper.java
```java
package com.assu.study.clean_me.account.adapter.out.persistence;

import com.assu.study.clean_me.account.domain.Account;
import com.assu.study.clean_me.account.domain.Activity;
import com.assu.study.clean_me.account.domain.ActivityWindow;
import com.assu.study.clean_me.account.domain.Money;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Component;

@Component
class AccountMapper {
  Account mapToDomainEntity(
      AccountJpaEntity account,
      List<ActivityJpaEntity> activityJpaEntities,
      Long withdrawalBalance,
      Long depositBalance) {

    // 특정 시간(= ActivityWindow) 직전의 계좌 잔고 계산
    Money baselineBalance = Money.subtract(Money.of(depositBalance), Money.of(withdrawalBalance));

    // 도메인 엔티티 반환
    return Account.withId(
        new Account.AccountId(account.getId()),
        baselineBalance,
        mapToActivityWindow(activityJpaEntities));
  }

  // ActivityJpaEntity List 를 ActivityWindow 로 mapping
  ActivityWindow mapToActivityWindow(List<ActivityJpaEntity> activityJpaEntities) {
    List<Activity> mappedActivities = new ArrayList<>();

    for (ActivityJpaEntity activityJpa : activityJpaEntities) {
      mappedActivities.add(
          new Activity(
              new Activity.ActivityId(activityJpa.getId()),
              new Account.AccountId(activityJpa.getOwnerAccountId()),
              new Account.AccountId(activityJpa.getSourceAccountId()),
              new Account.AccountId(activityJpa.getTargetAccountId()),
              activityJpa.getTimestamp(),
              Money.of(activityJpa.getAmount())));
    }

    return new ActivityWindow(mappedActivities);
  }

  // Activity 를 ActivityJpaEntity 로 mapping
  ActivityJpaEntity mapToJpaEntity(Activity activity) {
    return new ActivityJpaEntity(
        activity.getId() == null ? null : activity.getId().getValue(),
        activity.getTimestamp(),
        activity.getOwnerAccountId().getValue(),
        activity.getSourceAccountId().getValue(),
        activity.getTargetAccountId().getValue(),
        activity.getMoney().getAmount().longValue());
  }
}
```

위 코드에서 보이는 것처럼 _Account_ 와 _Activity_ 도메인 모델, _AccountJpaEntity_, _ActivityJpaEntity_ 데이터베이스 모델 간에 양방향 매핑이 존재한다.

그렇다면 JPA 의 `@Entity` 애너테이션을 _Account_ 와 _Activity_ 도메인 모델로 옮겨서 이걸 그대로 DB 에 엔티티로 저장하는 건 어떨까?

이것은 '매핑하지 않기' 전략이라고도 하는데 이 '매핑하지 않기' 전략도 유효한 전략일 수 있다.

> '매핑하지 않기' 전략은 [Clean Architecture - 경계 간 매핑 전략](http://localhost:4000/dev/2024/06/01/clean-layer-mapping/) 을 참고하세요.

하지만 **'매핑하지 않기' 전략은 JPA 로 인해 도메인 모델을 타협할 수밖에 없다.**

예를 들어 JPA 엔티티는 기본 생성자를 필요로 하고, 영속성 계층에서는 성능 측면에서 `@ManyToOne` 관계를 설정하는 것이 적절하다.  
하지만 위 예시에서는 항상 데이터의 일부만 가져오기를 바라기 때문에 도메인 모델에서는 이 관계가 반대가 되길 바란다.

따라서 **영속성 측면과 타협없이 풍부한 도메인 모델을 생성하고 싶다면 도메인 모델과 영속성 모델을 매핑하는 것**이 좋다.

---

# 6. 트랜잭션

**트랜잭션은 하나의 특정한 유스케이스에 대해 일어나는 모든 쓰기 작업에 대해 적용**되어야 한다.

**영속성 어댑터는 어떤 DB 연산이 같은 유스케이스에 포함되어 있는지 알지 못하므로 트랜잭션은 영속성 어댑터를 호출하는 서비스에 위임**해야 한다.

SendMoneyService.java
```java
package com.assu.study.clean_me.account.application.service;

import com.assu.study.clean_me.account.application.port.in.SendMoneyCommand;
import com.assu.study.clean_me.account.application.port.in.SendMoneyUseCase;
import com.assu.study.clean_me.account.application.port.out.AccountLock;
import com.assu.study.clean_me.account.application.port.out.LoadAccountPort;
import com.assu.study.clean_me.account.application.port.out.UpdateAccountStatePort;
import com.assu.study.clean_me.common.UseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

// 인커밍 포트 인터페이스인 SendMoneyUseCase 구현
@UseCase
@RequiredArgsConstructor
@Transactional
class SendMoneyService implements SendMoneyUseCase {

    // ...
}
```

---

# 정리하며...

도메인 코드에 플러그인처럼 동작하는 **영속성 어댑터를 만들면 도메인 코드가 영속성과 분리되어 풍부한 도메인 모델**을 만들 수 있다.

**좁은 포트 인터페이스를 사용하면 포트다마 다른 방식으로 구현할 수 있는 유연함이 생기고, 포트 뒤에서 애플리케이션에 영향을 주지 않으면서 다른 영속성 기술을 사용**할 수도 있다.  
포트의 명세만 지켜진다면 영속성 계층 전체를 교체할 수도 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)