---
layout: post
title:  "Clean Architecture - 아키텍처 경계 강제"
date: 2024-06-08
categories: dev
tags: clean 
---

일정 규모 이상의 프로젝트는 시간이 지남에 따라 아키텍처가 서서히 무너지게 된다.

계층 간의 경계가 약화되고, 코드는 점점 테스트하기 어려워지고, 새로운 기능을 구현하는데 점점 더 많은 시간이 든다.

이 포스트에서는 아키텍처 내의 경계를 강제하는 방법과 아키텍처 붕괴를 막기 위한 몇 가지 조치에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/clean-architecture/tree/feature/chap10)  에 있습니다.

![클린 아키텍처의 추상적인 모습](/assets/img/dev/2024/0511/clean.png)

![육각형 아키텍처](/assets/img/dev/2024/0511/hexagonal.png)

---

**목차**

<!-- TOC -->
* [1. 경계와 의존성](#1-경계와-의존성)
* [2. 접근 제한자 (Visibility Modifier)](#2-접근-제한자-visibility-modifier)
* [3. 컴파일 후 체크(post-compile check): `ArchUnit`](#3-컴파일-후-체크post-compile-check-archunit)
* [4. 빌드 아티팩트](#4-빌드-아티팩트)
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

//    testImplementation 'org.junit.jupiter:junit-jupiter-engine:5.10.3'
//    testImplementation 'org.mockito:mockito-junit-jupiter:5.12.0'
//    testImplementation 'org.junit.platform:junit-platform-launcher:1.10.3'
}

test {
    useJUnitPlatform()
}
```

application.properties
```properties
spring.application.name=clean_me
spring.datasource.url=jdbc:mysql://localhost:13306/clean?characterEncoding=utf8
spring.datasource.username=root
spring.datasource.password=
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.hikari.maximum-pool-size=10
spring.jpa.database=mysql
spring.jpa.show-sql=true
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.jpa.open-in-view=false
```

---

# 1. 경계와 의존성

아키텍처 경계를 강제한다는 것은 의존성이 올바른 방향을 향하도록 강제하는 것을 의미한다.

아래 그림에서 허용되지 않은 의존성은 점섬 화살표로 표시되었다.
![아키텍처 의존성 방향](/assets/img/dev/2024/0608/architecture_layer.png)

가장 안쪽에는 **도메인** 엔티티가 있다.

**애플리케이션 계층**은 애플리케이션 서비스 안에 유스케이스를 구현하기 위해 도메인 엔티티에 접근한다.

**어댑터**는 인커밍 포트를 통해 서비스에 접근하고, 반대로 서비스는 아웃고잉 포트를 통해 어댑터에 접근한다.  

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
    │   │   │       ├── LoadAccountPort.java
    │   │   └── service
    │   │       ├── SendMoneyService.java
```

어댑터가 인커밍 포트를 통해 서비스에 접근하는 예시
```java
@WebAdapter
class SendMoneyController {
    private final SendMoneyUseCase sendMoneyUseCase;    // 인커밍 포트
    // ...
}
```

서비스가 아웃고잉 포트를 통해 어댑터에 접근하는 방식
```java
@UseCase
class SendMoneyService implements SendMoneyUseCase {
    // 계좌를 조회하기 위한 아웃고잉 인터페이스
    private final LoadAccountPort loadAccountPort;
    // ...
}


// 아웃고잉 포트 인터페이스 구현체
@PersistenceAdapter
@RequiredArgsConstructor
class AccountPersistenceAdapter implements LoadAccountPort, UpdateAccountStatePort {
    // ...
}
```

**설정 계층**은 어댑터와 서비스 객체를 생성할 팩토리를 포함하고 있고, 의존성 주입 메커니즘을 제공한다.

이제 위 그림의 점선 화살표처럼 잘못된 방향을 가리키는 의존성을 없애보자.

---

# 2. 접근 제한자 (Visibility Modifier)

경계를 강제하기 위해 자바에서 제공하는 접근 제한자를 보자.

자바의 접근 제한자는 `public`, `protected`, `private` 그리고 `package-private(default)` 가 있다.

> 자바의 접근 제한자에 대한 좀 더 상세한 내용은 [2. 기능으로 패키지 구성](https://assu10.github.io/dev/2024/05/12/clean-package/#2-%EA%B8%B0%EB%8A%A5%EC%9C%BC%EB%A1%9C-%ED%8C%A8%ED%82%A4%EC%A7%80-%EA%B5%AC%EC%84%B1) 을 참고하세요.

`package-private` 제한자는 자바 패키지를 통해 클래스들을 **응집적인 모듈**로 만들어준다.  
이러한 **모듈 내에 있는 클래스들은 서로 접근 가능하지만, 다른 패키지에서는 접근할 수 없다.**    
따라서 **모듈의 진입점으로 활용될 수 있는 클래스들만 골라서 public** 으로 만들면 의존성이 잘못된 방향을 가리켜서 의존성 규칙을 위반할 위험이 줄어든다.

이제 접근 제한자를 염두에 두고 패키지 구조를 다시 보자.
```shell
.
└── cleanme
    ├── account
    │   ├── adapter
    │   │   ├── in
    │   │   │   └── web
    │   │   │       └── (o) SendMoneyController.java
    │   │   └── out
    │   │       └── persistence
    │   │           ├── (o) AccountJpaEntity.java
    │   │           ├── (o) AccountMapper.java
    │   │           ├── (o) AccountPersistenceAdapter.java
    │   │           ├── AccountRepository.java
    │   │           ├── (o) ActivityJpaEntity.java
    │   │           └── ActivityRepository.java
    │   ├── application
    │   │   ├── port
    │   │   │   ├── in
    │   │   │   │   ├── (+) GetAccountBalanceQuery.java
    │   │   │   │   ├── (+) SendMoneyCommand.java
    │   │   │   │   └── (+) SendMoneyUseCase.java
    │   │   │   └── out
    │   │   │       ├── (+) AccountLock.java
    │   │   │       ├── (+) LoadAccountPort.java
    │   │   │       └── (+) UpdateAccountStatePort.java
    │   │   └── service
    │   │       ├── (o) GetAccountBalanceService.java
    │   │       ├── MoneyTransferProperties.java
    │   │       ├── (o) NoOpAccountLock.java
    │   │       ├── (o) SendMoneyService.java
    │   │       └── (o) ThresholdExceededException.java
    │   └── domain
    │       ├── (+) Account.java
    │       ├── (+) Activity.java
    │       ├── (+) ActivityWindow.java
    │       └── (+) Money.java
```

(o) 은 package-private 이고, (+) 는 public 이다.

**_persistence_ 패키지에 있는 클래스들은 외부에서 접근할 필요가 없으므로 package-private** 로 만들 수 있다.  
영속성 어댑터는 자신이 구현하는 출력 포트를 통해 접근된다.

같은 이유로 **_service_ 패키지도 package-private** 로 만들 수 있다.

의존성 주입 메커니즘은 일반적으로 리플렉션을 이용하여 클래스를 인스턴스로 만들기 때문에 package-private 이더라도 여전히 인스턴스를 만들 수 있다.

그 외의 나머지 패키지들은 public 이어야 한다.

**_domain_ 패키지는 다른 계층에서 접근**할 수 있어야 하고, **_application_ 계층은 웹 어댑터와 영속성 어댑터에서 접근** 가능해야 한다.

`package-private` 제한자는 적은 갯수의 클래스로만 이뤄진 작은 모듈에서 가장 효과적이다.  
그럴 땐 코드를 쉽게 찾을 수 있도록 하위 패키지를 만드는 방법을 권장한다.  
하지만 그러면 **자바는 하위 패키지를 다른 패키지로 취급하기 때문에 하위 패키지의 `package-private` 멤버에 접근할 수 없게 된다.**    
**그래서 하위 패키지의 멤버는 public 으로 만들어서 외부에 노출시켜야 하기 때문에 아키텍처 의존성 규칙이 깨질 수 있는 환경이 만들어진다.**

---

# 3. 컴파일 후 체크(post-compile check): `ArchUnit`

클래스에 public 제한자를 쓰면 아키텍처 상의 의존성 방향이 잘못되더라도 컴파일러는 다른 클래스들이 이 클래스를 사용하도록 허용한다.  
이럴 때는 컴파일러가 도움이 되지 않기 때문에 의존성 규칙을 위반했는지 확인할 수 있는 다른 수단이 필요한 데 그것은 바로 **컴파일 후 체크** 를 도입하는 것이다.  
즉, 코드가 컴파일 된 후에 런타임에 체크한다는 뜻인데 이런 **런타임 체크는 지속적인 통합 빌드 환경에서 자동화된 테스트 과정에서 가장 잘 동작**한다.

런타임 후 체크를 도와주는 자바용 도구로는 `ArchUnit` 이 있다.

`ArchUnit` 은 의존성 방향이 기대한 대로 잘 설정되어 있는지 API 를 제공하여 의존성 규칙 위반을 발견하면 예외를 던진다.

`ArchUnit` 은 `JUnit` 과 같은 단위 테스트 프레임워크 기반에서 가장 잘 동작하며 의존성 규칙을 위반할 경우 테스트를 실패시킨다.

즉, **`ArchUnit` 을 사용하면 계층 간의 의존성을 체크**할 수 있다.

아래는 도메인 계층에서 바깥쪽의 애플리케이션 계층으로 향하는 의존성이 없다는 것을 체크하는 예시이다.

/test/com/assu/study/cleanme/DependencyRuleTest.java
```java
package com.assu.study.cleanme;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ClassFileImporter;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

public class DependencyRuleTest {
  @DisplayName("도메인 레이어는 애플리케이션 레이어로 향하는 의존성이 없음")
  @Test
  void domainLayerDoesNotDependOnApplicationLayer() {
    noClasses()
        .that()
        .resideInAPackage("com.assu.study.cleanme.account.domain..")
        .should()
        .dependOnClassesThat()
        .resideInAnyPackage("com.assu.study.cleanme.account.application..")
        .check(new ClassFileImporter().importPackages("com.assu.study.cleanme"));
  }
}
```

이 상태에서 domain 패키지에서 application.port.in.SendMoneyUseCase.java 를 의존하는 테스트 파일을 아래와 같이 만들어보자.

Test.java
```java
package com.assu.study.cleanme.account.domain;

import com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class Test {
  private final SendMoneyUseCase sendMoneyUseCase;
}
```

이 후 테스트 코드를 실행하면 아래와 같은 로그가 남으면서 테스트에 실패하게 된다.
```shell
Architecture Violation [Priority: MEDIUM] - Rule 'no classes that reside in a package 'com.assu.study.cleanme.account.domain..' should depend on classes that reside in any package ['com.assu.study.cleanme.account.application..']' was violated (2 times):
Constructor <com.assu.study.cleanme.account.domain.Test.<init>(com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase)> has parameter of type <com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase> in (Test.java:0)
Field <com.assu.study.cleanme.account.domain.Test.sendMoneyUseCase> has type <com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase> in (Test.java:0)
java.lang.AssertionError: Architecture Violation [Priority: MEDIUM] - Rule 'no classes that reside in a package 'com.assu.study.cleanme.account.domain..' should depend on classes that reside in any package ['com.assu.study.cleanme.account.application..']' was violated (2 times):
Constructor <com.assu.study.cleanme.account.domain.Test.<init>(com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase)> has parameter of type <com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase> in (Test.java:0)
Field <com.assu.study.cleanme.account.domain.Test.sendMoneyUseCase> has type <com.assu.study.cleanme.account.application.port.in.SendMoneyUseCase> in (Test.java:0)

// ...

DependencyRuleTest > 도메인 레이어는 애플리케이션 레이어로 향하는 의존성이 없음 FAILED
```

`ArchUnit` API 를 이용하면 적은 작업만으로도 육각형 아키텍처 내에서 관련된 모든 패키지를 명시할 수 있는 일종의 도메인 특화 언어 (DSL, Domain Specific Language) 를 만들 수 있고, 
패키지 사이의 의존성 방향이 올바른지 자동으로 체크할 수 있다.

/test/com/assu/study/cleanme/DependencyRuleTest.java
```java
package com.assu.study.cleanme;

import com.assu.study.cleanme.archunit.HexagonalArchitecture;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

public class DependencyRuleTest {
  @DisplayName("아키텍처 내의 모든 패키지 간의 의존성 방향 체크")
  @Test
  void validateRegistrationContextArchitecture() {
    // 바운디드 컨텍스트의 부모 패키지 지정 (단일 바운디드 컨텍스트면 애플리케이션 전체에 해당)
    HexagonalArchitecture.boundedContext("com.assu.study.cleanme.account")
        // 도메인 하위 패키지 지정
        .withDomainLayer("domain")

        // 어댑터 하위 패키지 지정
        .withAdaptersLayer("adapter")
        .incoming("in.web")
        .outgoing("out.persistence")
        .and()

        // 애플리케이션 하위 패키지 지정
        .withApplicationLayer("application")
        .services("service")
        .incomingPorts("port.in")
        .outgoingPorts("port.out")
        .and()

        // 설정 하위 패키지 지정
        .withConfiguration("configuration")

        // 의존성 검사
        .check(new ClassFileImporter().importPackages("com.assu.study.cleanme.."));
  }
}
```

test/com/assu/study/cleanme/archunit/ArchitectureElement.java
```java
package com.assu.study.cleanme.archunit;

import static com.tngtech.archunit.base.DescribedPredicate.greaterThanOrEqualTo;
import static com.tngtech.archunit.lang.conditions.ArchConditions.containNumberOfElements;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import java.util.List;

// 육각형 아키텍처 DSL
abstract class ArchitectureElement {
  final String basePackage;

  public ArchitectureElement(String basePackage) {
    this.basePackage = basePackage;
  }

  String fullQualifiedPackage(String relativePackage) {
    return this.basePackage + "." + relativePackage;
  }

  static void denyDependency(String fromPackageName, String toPackageName, JavaClasses classes) {
    noClasses()
        .that()
        .resideInAPackage(fromPackageName + "..")
        .should()
        .dependOnClassesThat()
        .resideInAnyPackage(toPackageName + "..")
        .check(classes);
  }

  static void denyAnyDependency(
      List<String> fromPackages, List<String> toPackages, JavaClasses classes) {
    for (String fromPackage : fromPackages) {
      for (String toPackage : toPackages) {
        noClasses()
            .that()
            .resideInAPackage(matchAllClassesInPackage(fromPackage))
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage(matchAllClassesInPackage(toPackage))
            .check(classes);
      }
    }
  }

  static String matchAllClassesInPackage(String packageName) {
    return packageName + "..";
  }

  void denyEmptyPackage(String packageName) {
    classes()
        .that()
        .resideInAPackage(matchAllClassesInPackage(packageName))
        .should(containNumberOfElements(greaterThanOrEqualTo(1)))
        .check(classesInPackage(packageName));
  }

  private JavaClasses classesInPackage(String packageName) {
    return new ClassFileImporter().importPackages(packageName);
  }

  void denyEmptyPackages(List<String> packages) {
    for (String packageName : packages) {
      denyEmptyPackage(packageName);
    }
  }
}
```

test/com/assu/study/cleanme/archunit/Adapters.java
```java
package com.assu.study.cleanme.archunit;

import com.tngtech.archunit.core.domain.JavaClasses;
import java.util.ArrayList;
import java.util.List;

// 육각형 아키텍처 DSL
public class Adapters extends ArchitectureElement {
  private final HexagonalArchitecture parentContext;
  private List<String> incomingAdapterPackages = new ArrayList<>();
  private List<String> outgoingAdapterPackages = new ArrayList<>();

  public Adapters(HexagonalArchitecture parentContext, String basePackage) {
    super(basePackage);
    this.parentContext = parentContext;
  }

  public Adapters outgoing(String packageName) {
    this.incomingAdapterPackages.add(fullQualifiedPackage(packageName));
    return this;
  }

  public Adapters incoming(String packageName) {
    this.outgoingAdapterPackages.add(fullQualifiedPackage(packageName));
    return this;
  }

  List<String> allAdapterPackages() {
    List<String> allAdapters = new ArrayList<>();
    allAdapters.addAll(incomingAdapterPackages);
    allAdapters.addAll(outgoingAdapterPackages);
    return allAdapters;
  }

  public HexagonalArchitecture and() {
    return parentContext;
  }

  String getBasePackage() {
    return basePackage;
  }

  void dontDependOnEachOther(JavaClasses classes) {
    List<String> allAdapters = allAdapterPackages();
    for (String adapter1 : allAdapters) {
      for (String adapter2 : allAdapters) {
        if (!adapter1.equals(adapter2)) {
          denyDependency(adapter1, adapter2, classes);
        }
      }
    }
  }

  void doesNotDependOn(String packageName, JavaClasses classes) {
    denyDependency(this.basePackage, packageName, classes);
  }

  void doesNotContainEmptyPackages() {
    denyEmptyPackages(allAdapterPackages());
  }
}
```
test/com/assu/study/cleanme/archunit/ApplicationLayer.java
```java
package com.assu.study.cleanme.archunit;

import com.tngtech.archunit.core.domain.JavaClasses;
import java.util.ArrayList;
import java.util.List;

// 육각형 아키텍처 DSL
public class ApplicationLayer extends ArchitectureElement {
  private final HexagonalArchitecture parentContext;
  private List<String> incomingPortsPackages = new ArrayList<>();
  private List<String> outgoingPortsPackages = new ArrayList<>();
  private List<String> servicePackages = new ArrayList<>();

  public ApplicationLayer(HexagonalArchitecture parentContext, String basePackage) {
    super(basePackage);
    this.parentContext = parentContext;
  }

  public ApplicationLayer incomingPorts(String packageName) {
    this.incomingPortsPackages.add(fullQualifiedPackage(packageName));
    return this;
  }

  public ApplicationLayer outgoingPorts(String packageName) {
    this.outgoingPortsPackages.add(fullQualifiedPackage(packageName));
    return this;
  }

  public ApplicationLayer services(String packageName) {
    this.servicePackages.add(fullQualifiedPackage(packageName));
    return this;
  }

  public HexagonalArchitecture and() {
    return parentContext;
  }

  public void doesNotDependOn(String packageName, JavaClasses classes) {
    denyDependency(this.basePackage, packageName, classes);
  }

  public void incomingAndOutgoingPortsDoNotDependOnEachOther(JavaClasses classes) {
    denyAnyDependency(this.incomingPortsPackages, this.outgoingPortsPackages, classes);
    denyAnyDependency(this.outgoingPortsPackages, this.incomingPortsPackages, classes);
  }

  private List<String> allPackages() {
    List<String> allPackages = new ArrayList<>();
    allPackages.addAll(this.incomingPortsPackages);
    allPackages.addAll(this.outgoingPortsPackages);
    allPackages.addAll(this.servicePackages);
    return allPackages;
  }

  void doesNotContainEmptyPackages() {
    denyEmptyPackages(allPackages());
  }
}
```

test/com/assu/study/cleanme/archunit/HexagonalArchitecture.java
```java
package com.assu.study.cleanme.archunit;

import com.tngtech.archunit.core.domain.JavaClasses;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

// 육각형 아키텍처 DSL
public class HexagonalArchitecture extends ArchitectureElement {
  private Adapters adapters;
  private ApplicationLayer applicationLayer;
  private String configurationPackage;
  private List<String> domainPackages = new ArrayList<>();

  public HexagonalArchitecture(String basePackage) {
    super(basePackage);
  }

  public static HexagonalArchitecture boundedContext(String basePackage) {
    return new HexagonalArchitecture(basePackage);
  }

  public Adapters withAdaptersLayer(String adaptersPackage) {
    this.adapters = new Adapters(this, fullQualifiedPackage(adaptersPackage));
    return this.adapters;
  }

  public HexagonalArchitecture withDomainLayer(String domainPackage) {
    this.domainPackages.add(fullQualifiedPackage(domainPackage));
    return this;
  }

  public ApplicationLayer withApplicationLayer(String applicationPackage) {
    this.applicationLayer = new ApplicationLayer(this, fullQualifiedPackage(applicationPackage));
    return this.applicationLayer;
  }

  public HexagonalArchitecture withConfiguration(String packageName) {
    this.configurationPackage = fullQualifiedPackage(packageName);
    return this;
  }

  private void domainDoesNotDependOnOtherPackages(JavaClasses classes) {
    denyAnyDependency(
        this.domainPackages, Collections.singletonList(this.adapters.basePackage), classes);
    denyAnyDependency(
        this.domainPackages, Collections.singletonList(this.applicationLayer.basePackage), classes);
  }

  public void check(JavaClasses classes) {
    this.adapters.doesNotContainEmptyPackages();
    this.adapters.dontDependOnEachOther(classes);
    this.adapters.doesNotDependOn(this.configurationPackage, classes);

    this.applicationLayer.doesNotContainEmptyPackages();
    this.applicationLayer.doesNotDependOn(this.adapters.getBasePackage(), classes);
    this.applicationLayer.doesNotDependOn(this.configurationPackage, classes);
    this.applicationLayer.incomingAndOutgoingPortsDoNotDependOnEachOther(classes);

    this.domainDoesNotDependOnOtherPackages(classes);
  }
}
```

잘못된 의존성을 바로잡는데 컴파일 후 체크가 큰 도움이 되긴 하지만 실패에 안전하지는 않다.

패키지명에 오타를 내면 테스트가 어떤 클래스도 찾지 못하기 때문에 의존성 규칙 위반 사례를 발견하지 못한다.  
이런 상황을 방지하려면 클래스를 하나도 찾지 못했을 때 실패하는 테스트를 추가해야 한다.

컴파일 후 체크는 언제나 코드와 함께 유지보수되어야 한다.

---

# 4. 빌드 아티팩트

---

# 정리하며...

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)
* [KooKu's log](https://kooku0.github.io/docs/books/get-your-hands-dirty-on-clean-architecture/10/)
* [자바의 접근제어자(public, protected, private, private-package)](https://rutgo-letsgo.tistory.com/entry/%EC%9E%90%EB%B0%94%EC%9D%98-%EC%A0%91%EA%B7%BC%EC%A0%9C%EC%96%B4%EC%9E%90public-protected-private-private-package#private-package(default)-1)
* [ArchUnit](https://github.com/TNG/ArchUnit)
* [archunit 사용법](https://rudaks.tistory.com/entry/archunit-%EC%82%AC%EC%9A%A9%EB%B2%95)