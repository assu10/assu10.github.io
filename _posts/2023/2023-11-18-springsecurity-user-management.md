---
layout: post
title:  "Spring Security - 사용자 관리"
date:   2023-11-18
categories: dev
tags: spring-security user-details granted-authority user-details-service user-details-manager jdbc-user-details-manager
---

이 포스트에서는 스프링 시큐리티에서 사용자 관리하는 `UserDetailsService` 에 대해 자세히 알아본다.  
스프링 시큐리티에 있는 `UserDetailsService` 구현과 이를 이용하는 방법, 인터페이스 계약을 위한 맞춤형 구현을 정의하는 방법, 실제 운영에 적용할 수 있는 인터페이스를 
구현하는 방법에 대해 알아본다.

- 스프링 시큐리티에서 사용자를 정의하는 `UserDetails`
- 사용자가 실행할 수 있는 작업을 정의하는 `GrantedAuthority`
- `UserDetailsService` 계약을 확장하는 `UserDetailsManager`

먼저 `UserDetails`, `GrantedAuthority` 계약을 먼저 알아보고, `UserDetailsService` 를 알아본 후 `UserDetailsManager` 가 이 인터페이스 계약을 
확장하는 법에 대해 알아본다.  
그리고 이러한 인터페이스들의 구현(`InMemoryUserDetailsManager`, `JdbcUserDetailsManager`) 을 적용하고, 
이러한 구현들이 시스템에 적합하지 않을 때 맞춤형 구현을 작성해본다.

---

**목차**
<!-- TOC -->
* [1. 스프링 시큐리티 인증 구현](#1-스프링-시큐리티-인증-구현)
* [2. 사용자 기술](#2-사용자-기술)
  * [2.1. `UserDetails` 계약](#21-userdetails-계약)
  * [2.2. `GrantedAuthority` 계약](#22-grantedauthority-계약)
  * [2.3. 최소한의 `UserDetails` 구성](#23-최소한의-userdetails-구성)
  * [2.4. 빌더를 이용하여 `UserDetails` 형식의 인스턴스 생성](#24-빌더를-이용하여-userdetails-형식의-인스턴스-생성)
  * [2.5. JPA 와 `UserDetails` 계약 책임 분리 예시](#25-jpa-와-userdetails-계약-책임-분리-예시)
* [3. 스프링 시큐리티가 사용자를 관리하는 방법 지정](#3-스프링-시큐리티가-사용자를-관리하는-방법-지정)
  * [3.1. `UserDetailsService` 계약](#31-userdetailsservice-계약)
  * [3.2. `UserDetailsService` 계약 구현](#32-userdetailsservice-계약-구현)
  * [3.3. `UserDetailsManager` 계약 구현](#33-userdetailsmanager-계약-구현)
    * [3.3.1. 사용자 관리자 `JdbcUserDetailsManager` 적용](#331-사용자-관리자-jdbcuserdetailsmanager-적용)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.2.2
- Spring ver: 6.1.3
- Spring Security ver: 6.2.1
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven

![Spring Initializer Sample](/assets/img/dev/2023/1112/init.png)

---

# 1. 스프링 시큐리티 인증 구현

![Spring Initializer Sample](/assets/img/dev/2023/1118/security.png)

위 그림에서 `UserDetailsService` 와 `PasswordEncoder` 는 기본적으로 있는 구성 요소이다.

위 그림에 보이는 스프링 시큐리티의 인증 흐름은 아래와 같다.
- `AuthenticationFilter` 가 요청을 가로채서 인증 책임을 `AuthenticationManager` 에게 위임함
- `AuthenticationManager` 는 인증 논리를 구현하기 위해 `AuthenticationProvider` 를 이용
- `AuthenticationProvider` 는 사용자 이름과 암호를 확인하기 위해 `UserDetailsService`, `PasswordEncoder` 를 이용


사용자 관리를 위해서는 `UserDetailsService`, `UserDetailsManager` 인터페이스를 이용한다.

- `UserDetailsService`: 사용자 검색
- `UserDetailsManager`: 사용자 추가, 수정, 삭제

**따라서 사용자를 인증하는 기능한 필요한 경우 `UserDetailsService` 만 구현하면 되고, 사용자를 관리하려면 둘 다 구현하면 된다.**

`UserDetails` 계약을 구현하여 사용자를 기술하고, 사용자가 수행할 수 있는 작업(=권한)은 `GrantedAuthority` 인터페이스로 나타낸다.

> 권한에 대한 좀 더 상세한 내용은    
> [Spring Security - 권한 부여(1): 권한과 역할에 따른 액세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-1/),  
> [Spring Security - 권한 부여(2): 경로, HTTP Method 에 따른 엑세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-2/) 
> 를 참고하세요.

아래는 사용자 관리를 수행하는 구성 요소 간의 종속성이다.

![사용자 관리를 수행하는 구성 요소 간 종속성](/assets/img/dev/2023/1118/user_manage.png)

- **`UserDetails` 계약**
  - `UserDetails` 인터페이스로 사용자를 기술함
  - 스프링 시큐리티가 관리하는 사용자를 나타냄
- **`GrantedAuthority` 계약**
  - 사용자는 `GrantedAuthority` 인터페이스로 나타내는 권한을 하나 이상 가짐
  - 사용자에게 허용되는 작업을 정의
- **`UserDetailsService` 계약**
  - 사용자 이름으로 찾은 사용자 세부 정보를 반환함
- **`UserDetailsManager` 계약**
  - `UserDetailsService` 를 확장해서 암호 생성, 삭제, 변경 등의 작업을 추가함
- **`PasswordEncoder`**
  - 암호를 암호화 또는 해시하는 방법과, 주어진 인코딩된 문자열을 일반 텍스트 암호와 비교하는 방법을 지정

---

# 2. 사용자 기술

스프링 시큐리티가 사용자를 이해하기 위해서는 애플리케이션은 사용자를 기술해야 한다.

스프링 시큐리티에서 사용자 정의는 `UserDetails` 계약을 준수해야 하며, 애플리케이션에서 사용자를 기술하는 클래스는 이 인터페이스를 구현해야 한다.

---

## 2.1. `UserDetails` 계약

UserDetails 인터페이스
```java
package org.springframework.security.core.userdetails;

import java.io.Serializable;
import java.util.Collection;
import org.springframework.security.core.GrantedAuthority;

public interface UserDetails extends Serializable {
  // 앱 사용자가 수행할 수 있는 작업을 GrantedAuthority 인스턴스의 컬렉션으로 반환
  // (= 사용자에게 부여된 권한의 그룹을 반환)
  Collection<? extends GrantedAuthority> getAuthorities();

  // 사용자 자격 증명을 반환하는 메서드들, 앱에서 인증 과정에서 사용됨
  String getPassword();
  String getUsername();

  // 사용자 계정을 필요에 따라 활성화/비활성화하는 메서드들
  // 사용자가 애플리케이션의 리소스에 접근할 수 있도록 권한을 부여하기 위함
  boolean isAccountNonExpired();
  boolean isAccountNonLocked();
  boolean isCredentialsNonExpired();
  boolean isEnabled();
}
```

`UserDetails` 는 4가지 작업이 가능하다.

- 계정 만료 (`isAccountNonExpired()`)
  - **권한 부여가 실패해야 하면 `false` 반환, 성공해야 하면 `true` 반환 (아래 메서드들도 모두 동일)** 
- 계정 잠금 (`isAccountNonLocked()`)
- 자격 증명 만료 (`isCredentialsNonExpired()`)
- 계정 비활성화 (`isEnabled()`)

애플리케이션 논리에서 사용자 제한을 구현하려면 위 4가지 메서드들을 재정의하여 true 를 반환하게 해야 한다.  
만일, 애플리케이션에서 이러한 기능을 구현할 필요가 없다면 단순히 4가지 메서드가 true 를 반환하게 하면 된다.

---

## 2.2. `GrantedAuthority` 계약

스프링 시큐리티는 `GrantedAuthority` 인터페이스로 권한을 나타낸다.

여기서는 권한은 정의하는 방법에 대해 알아본다.

> 사용자 권한을 바탕으로 권한 부여 구성을 작성하는 방법에 대해서는  
> [Spring Security - 권한 부여(1): 권한과 역할에 따른 액세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-1/),  
> [Spring Security - 권한 부여(2): 경로, HTTP Method 에 따른 엑세스 제한](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-2/)
> 를 참고하세요.

사용자는 권한이 하나도 없거나, 여러 개의 권한을 가질 수 있으며 일반적으로 1개 이상의 권한을 소유한다.

`GrangedAuthority` 인터페이스
```java
package org.springframework.security.core;

import java.io.Serializable;

public interface GrantedAuthority extends Serializable {
  // 권한명을 String 으로 반환
  String getAuthority();
}
```

위 인터페이스를 보면 추상 메서드 하나만 있기 때문에 람다 식을 구현에 이용할 수 있다. (권장하지는 않음)

> 인터페이스가 함수형으로 표시되지 않으면 추후에 추가로 추상 메서드가 추가될 수도 있다는 의미일 수도 있기 때문에  
> 람다식으로 구현하기 전에 `@FuntionalInterface` 애너테이션을 지정하여 인터페이스가 함수형임을 지정하는 것이 좋음  
> 
> **`GrantedAuthority` 인터페이스는 함수형으로 표시되지 않았지만, 실제 운영 시엔 람다식으로 구현하지 않는 것이 좋음**

`SimpleGrantedAuthority` 클래스를 이용하여 권한 인스턴스를 만드는 것도 가능하다.

아래는 각각 람다식을 이용, `SimpleGrantedAuthority` 클래스를 이용하여 `GrantedAuthority` 인터페이스를 구현하는 예시이다.

```java
GrantedAuthority g1 = () -> "READ";
GrantedAuthority g2 = new SimpleGrantedAuthority("READ");
```

---

## 2.3. 최소한의 `UserDetails` 구성

> 실제 운영에서는 이렇게 사용하지 않으며, 개념 이해만 하자.

여기서는 각 메서드가 정적인 값을 반환하도록 하여 가장 간단한 수준으로 `UserDetails` 계약의 구현을 작성해본다.

`UserDetails` 로 최소한의 사용자 기술을 구현 
```java
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/**
 * 최소한의 사용자 기술 구현
 * 이 클래스에서 권한 메서드들을 모두 true 로 반호나하게 함으로써 사용자가 항상 활성화되고, 사용 가능하도록 함
 */
public class DummyUser implements UserDetails {
  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    return List.of(() -> "READ");
  }

  @Override
  public String getPassword() {
    return "1234";
  }

  @Override
  public String getUsername() {
    return "assu";
  }

  @Override
  public boolean isAccountNonExpired() {
    return true;
  }

  @Override
  public boolean isAccountNonLocked() {
    return true;
  }

  @Override
  public boolean isCredentialsNonExpired() {
    return true;
  }

  @Override
  public boolean isEnabled() {
    return true;
  }
}
```

하지만 실제로는 다른 사용자를 나타내는 인스턴스를 생성할 수 있도록 클래스를 작성해야 한다.  
아래는 사용자 이름과 암호를 특성으로 포함하도록 하여 사용자 기술을 구현한 클래스이다.

```java
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;

public class SimpleUser implements UserDetails {
  private final String username;
  private final String password;

  public SimpleUser(String username, String password) {
    this.username = username;
    this.password = password;
  }

  @Override
  public String getPassword() {
    return this.password;
  }

  @Override
  public String getUsername() {
    return this.username;
  }
  
  // ...
}
```

---

## 2.4. 빌더를 이용하여 `UserDetails` 형식의 인스턴스 생성

일부 간단한 애플리케이션에서는 `UserDetails` 인터페이스의 구현이 필요없는데, 이 때는 org.springframework.security.core.userdetails.User 빌더 클래스를 이용하여 
`UserDetails` 형식의 인스턴스를 간단히 만들 수 있다.  
사용자 기술 구현 클래스는 하나 이상 선언해도 되지만, `User` 빌더 클래스로 사용자를 나타내는 인스턴스를 간편히 얻을 수도 있다.

즉, `User` 빌더 클래스를 사용하면 `UserDetails` 계약의 구현을 하지 않아도 된다.

```java
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;

public class TestUser {
  // User builder 이용하는 1번째 방법
  UserDetails user = User.withUsername("assu")
      .password("1234")
      .authorities("read", "write")
      .accountExpired(false)
      .disabled(true)
      .build();

  // User builder 이용하는 2번째 방법
  User.UserBuilder builder1 = User.withUsername("assu");

  UserDetails user1 = builder1
          .password("1234")
          .authorities("read")
          .passwordEncoder(p -> customEncode(p))  // 암호 인코딩
          .build();

  User.UserBuilder builder2 = User.withUserDetails(user1);

  UserDetails user2 = builder2.build();
}
```

---

## 2.5. JPA 와 `UserDetails` 계약 책임 분리 예시

아래는 사용자를 DB 에 저장할 때의 `UserDetails` 계약 구현의 간단한 예시이다.

JPA 엔티티 책임의 User.class
```java
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class User {
  @Id
  private int id;
  private String username;
  private String password;
  private String authority;
}
```

사용자 세부 정보를 `UserDetails` 계약과 매핑하는 책임의 SecurityUser.class
```java
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

public class SecurityUser implements UserDetails {
  private final User user;

  public SecurityUser(User user) {
    this.user = user;
  }

  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    return List.of(() -> user.getAuthority());
  }

  @Override
  public String getPassword() {
    return user.getPassword();
  }

  @Override
  public String getUsername() {
    return user.getUsername();
  }
  
  // ...
}
```

---

# 3. 스프링 시큐리티가 사용자를 관리하는 방법 지정

위에서 `UserDetails` 계약을 구현하여 사용가를 기술하였다.

이제 아래의 내용에 대해 알아본다.
- `UserDetailsService` 클래스를 구현하는 다양한 방법
- `UserDetailsService` 계약에 기술된 책임을 구현하여 사용자 관리가 작동하는 방식
- `UserDetailsManager` 인터페이스로 `UserDetailsService` 로 정의된 계약에 더 많은 동작 추가
- 스프링 시큐리티에 있는 `UserDetailsManager` 인터페이스의 구현
- 스프링 시큐리티에 있는 가장 잘 알려진 구현인 `JdbcUserDetailsManager` 이용

---

## 3.1. `UserDetailsService` 계약


`UserDetailsService` 인터페이스 (함수형)
```java
package org.springframework.security.core.userdetails;

public interface UserDetailsService {
  UserDetails loadUserByUsername(String username) throws UsernameNotFoundException;
}
```

인증 구현은 `loadUserByUsername()` 메서드를 호출하여 사용자 정보를 얻는다. 여기서 사용자 이름은 고유하다고 가정한다.

`loadUserByUsername()` 이 반환하는 사용자는 `UserDetails` 계약의 구현인데, 사용자 이름이 존재하지 않으면 _UsernameNotFoundException_ 예외가 발생한다.

> **_UsernameNotFoundException_**  
> 
> _UsernameNotFoundException_ 는 RuntimeException 임.  
> _UsernameNotFoundException_ 는 인증 프로세스와 연관된 모든 예외의 상위 항목인 _AuthenticationException_ 을 상속하여, _AuthenticationException_ 은 RuntimeException 을 상속함

![인증 흐름](/assets/img/dev/2023/1118/security_1.png)

`AuthenticationProvider` 는 인증 논리를 구현하고, `UserDetailsService` 를 이용하여 사용자 세부 정보를 로드한다.  
이 때 DB, 외부 시스템, Vault 등에서 사용자를 로드하도록 `UserDetailsService` 를 구현할 수 있고, 사용자 이름으로 사용자를 찾기 위해 `loadUserByUsername()` 을 호출한다. 

---

## 3.2. `UserDetailsService` 계약 구현

애플리케이션은 사용자 자격 증명과 다른 측면의 세부 정보도 관리하는데, 이러한 정보는 DB, Vault 등을 이용하여 관리할 수 있다.  
이러한 정보와 관계없이 스프링 시큐리티에서 필요한 것은 사용자 이름으로 사용자를 검색하는 구현을 제공하는 것이다.

아래는 메모리 내의 목록을 이용하는 `UserDetailsService` 예시이다. 
[3.4. 구성 클래스 분리](https://assu10.github.io/dev/2023/11/12/springsecurity-basic-2/#34-%EA%B5%AC%EC%84%B1-%ED%81%B4%EB%9E%98%EC%8A%A4-%EB%B6%84%EB%A6%AC) 에서 한 것처럼 
`InMemoryUserDetailsManager()` 와 같은 기능을 하는 InMemoryUserDetailsService 을 직접 구현해본다.

InMemoryUserDetailsService 는 `UserDetailsService` 클래스의 인스턴스를 만들 때 사용자의 목록을 제공한다.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0301) 에 있습니다.

/model/User.java
```java
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/**
 * 사용자 기술
 */
public class User implements UserDetails {
  private final String username;
  private final String password;
  private String authority; // 간단히 하기 위해 한 사용자에게 하나의 권한만 적용

  public User(String username, String password) {
    this.username = username;
    this.password = password;
  }

  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    // 인스턴스 생성 시 지정한 이름의 GrantedAuthority 객체만 포함하는 목록 반환
    return List.of(() -> authority);
  }

  @Override
  public String getPassword() {
    return password;
  }

  @Override
  public String getUsername() {
    return username;
  }

  @Override
  public boolean isAccountNonExpired() {
    // 계정이 만료되지 않음
    return true;
  }

  @Override
  public boolean isAccountNonLocked() {
    // 계정이 잠기지 않음
    return true;
  }

  @Override
  public boolean isCredentialsNonExpired() {
    // 자격 증명이 만료되지 않음
    return true;
  }

  @Override
  public boolean isEnabled() {
    // 계정이 비활성화되지 않음
    return true;
  }
}
```

/service/InMemoryUserDetailsService.java
```java
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import java.util.List;

/**
 * 사용자 이름으로 찾은 사용자 세부 정보 반환
 */
public class InMemoryUserDetailsService implements UserDetailsService {
  // UserDetailsService 는 메모리 내의 사용자 목록을 관리
  private final List<UserDetails> users;

  public InMemoryUserDetailsService(List<UserDetails> users) {
    this.users = users;
  }

  /**
   * 주어진 사용자 이름을 목록에서 검색하여 UserDetails 인스턴스 반환
   */
  @Override
  public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
    return users.stream()
        .filter(u -> u.getUsername().equals(username))  // 사용자 목록에서 요청된 사용자 이름과 일치하는 항목 필터링
        .findFirst()  // 일치하는 사용자 반환
        .orElseThrow(() -> new UsernameNotFoundException("User not found...!"));  // 사용자 이름이 존재하지 않으면 예외 발생
  }
}
```

이제 `UserDetailsService` 계약을 구현한 클래스를 구성 클래스에 빈으로 추가한다.

/config/ProjectConfig.java
```java
import com.assu.study.chap0301.model.User;
import com.assu.study.chap0301.service.InMemoryUserDetailsService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

@Configuration
public class ProjectConfig {
  @Bean
  public UserDetailsService userDetailsService() {
    UserDetails user = new User("assu", "1234", "read");
    List<UserDetails> users = List.of(user);
    return new InMemoryUserDetailsService(users);
  }
  
  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }
}
```

> `@Configuration` 과 `@Component` 의 차이는 [2. WebClient](https://assu10.github.io/dev/2023/09/23/springboot-rest-api-request/#2-webclient) 를 참고하세요.

이제 간단한 엔드포인트를 만든 후 호출해본다.
```java
@GetMapping("/hello")
public String hello() {
  return "hello";
}
```

```shell
# 인증 없이 호출
$ curl -w "%{http_code}" http://localhost:8080/hello
401%

# 잘못된 비번으로 호출
$ curl -w "%{http_code}" -u assu:123477 http://localhost:8080/hello
401%

# 정상 호출
$ curl -w "%{http_code}" -u assu:1234 http://localhost:8080/hello
hello200%
```

---

## 3.3. `UserDetailsManager` 계약 구현

이제 `UserDetailsManager` 인터페이스를 이용, 구현하는 법에 대해 알아본다.

[1. 스프링 시큐리티 인증 구현](#1-스프링-시큐리티-인증-구현) 에서 본 것처럼 각 구성 요소의 역할은 아래와 같다.

- **`UserDetails` 계약**
  - `UserDetails` 인터페이스로 사용자를 기술함
- **`GrantedAuthority` 계약**
  - 사용자는 `GrantedAuthority` 인터페이스로 나타내는 권한을 하나 이상 가짐
- **`UserDetailsService` 계약**
  - 사용자 이름으로 찾은 사용자 세부 정보를 반환함
- **`UserDetailsManager` 계약**
  - `UserDetailsService` 를 확장해서 암호 생성, 삭제, 변경 등의 작업을 추가함

`UserDetailsManager` 는 `UserDetailsService` 계약을 확장하고, 메서드를 추가한다.
`UserDetailsManager` 계약은 `JdbcUserDetailsManager`, InMemoryUserDetailsManager`, `LdapUserDetailsManager` 구현을 제공한다.

스프링 시큐리티가 인증을 수행하려면 `UserDetailsService` 계약이 필요한데 일반적으로 애플리케이션은 사용자를 추가/삭제 하는 등의 관리 기능이 필요하다.  
이 때 `UserDetailsManager` 인터페이스를 구현한다.

`UserDetailsManager` 인터페이스
```java
package org.springframework.security.provisioning;

import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;

public interface UserDetailsManager extends UserDetailsService {
  void createUser(UserDetails user);
  void updateUser(UserDetails user);
  void deleteUser(String username);
  void changePassword(String oldPassword, String newPassword);
  boolean userExists(String username);
}
```

[3.4. 구성 클래스 분리](https://assu10.github.io/dev/2023/11/12/springsecurity-basic-2/#34-%EA%B5%AC%EC%84%B1-%ED%81%B4%EB%9E%98%EC%8A%A4-%EB%B6%84%EB%A6%AC) 에서 사용한 
`InMemoryUserDetailsManager()` 객체가 하는 역할을 `UserDetailsManager` 인터페이스가 정의한다.  

---

### 3.3.1. 사용자 관리자 `JdbcUserDetailsManager` 적용

실제 운영 시엔 `InMemoryUserDetailsManager` 는 사용하지 않고, 다른 `UserDetailsManager` 인 `JdbcUserDetailsManager` 를 자주 이용한다. 

`JdbcUserDetailsManager` 는 DB 에 저장된 사용자를 관리하며, JDBC 를 통해 DB 에 직접 연결한다.  
JDBC 를 직접 이용하기 때문에 애플리케이션이 다른 프레임워크에 고정되지 않는다는 장점이 있다.

![JdbcUserDetailsManager 를 UserDetailsService 구성 요소로 이용한 인증 흐름](/assets/img/dev/2023/1118/jdbc.png)

여기서는 users, authorities 테이블을 생성한 후 `JdbcUserDetailsManager` 를 이용하여 MySQL 에 저장된 사용자를 관리하는 애플리케이션을 구현해본다.  
user, authorities 는 `JdbcUserDetailsManager` 가 인식하는 기본 테이블명이며, 원하면 기본 이름 변경이 가능하다.

이번에 보는 `JdbcUserDetailsManager` 구현은 users 테이블에 사용자 이름, 암호, 사용자 활성화 여부를 저장하는 기능을 구현한다.

> Docker 로 mysql 띄우는 법은 [Docker 관련 명령어들](https://assu10.github.io/dev/2023/08/20/docker-commands/) 과 [Rancher Desktop (Docker Desktop 유료화 대응)](https://assu10.github.io/dev/2022/02/02/rancher-desktop/) 을 참고하세요.

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap0302) 에 있습니다.

/resources/schemas.sql
```mysql
CREATE TABLE IF NOT EXISTS `security`.`users`
(
    `id`       INT         NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(45) NULL,
    `password` VARCHAR(45) NULL,
    `enabled`  INT         NOT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `security`.`authorities`
(
    `id`        INT         NOT NULL AUTO_INCREMENT,
    `username`  VARCHAR(45) NULL,
    `authority` VARCHAR(45) NULL,
    PRIMARY KEY (`id`)
);
```

/resources/data.sql
```mysql
INSERT INTO `security`.`authorities`
VALUES (NULL, 'assu', 'write');

INSERT INTO `security`.`users`
VALUES (NULL, 'assu', '1234', '1');
```

이제 `spring-boot-starter-data-jpa` 와 `mysql-connector-j` 종속성을 추가한다.

```xml
<!-- Spring Data JPA, Hibernate, aop, jdbc -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>

<!-- mysql 관련 jdbc 드라이버와 클래스들 -->
<!-- https://mvnrepository.com/artifact/com.mysql/mysql-connector-j -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <version>8.0.33</version>
</dependency>
```

application.properties
```properties
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.url=jdbc:mysql://localhost:13306/security?serverTimezone=UTC
spring.datasource.username=<사용자 이름>
spring.datasource.password=<암호>
spring.jpa.show-sql=true
```

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.JdbcUserDetailsManager;

import javax.sql.DataSource;

@Configuration
public class ProjectConfig {
//  @Bean
//  public DataSource dataSource() {
//    return new EmbeddedDatabaseBuilder()
//        .setType(EmbeddedDatabaseType.H2)
//        .addScript(JdbcDaoImpl.DEFAULT_USER_SCHEMA_DDL_LOCATION)
//        .build();
//  }

//  private final DataSource dataSource;
//
//  public ProjectConfig(DataSource dataSource) {
//    this.dataSource = dataSource;
//  }

  @Bean
  public UserDetailsService userDetailsService(DataSource dataSource) {
    //return new JdbcUserDetailsManager(dataSource);

    String usersByUsernameQuery = "select username, password, enabled from security.users where username = ?";
    String authsByUserQuery = "select username, authority from security.authorities where username = ?";

    JdbcUserDetailsManager userDetailsManager = new JdbcUserDetailsManager(dataSource);
    userDetailsManager.setUsersByUsernameQuery(usersByUsernameQuery);
    userDetailsManager.setAuthoritiesByUsernameQuery(authsByUserQuery);

    return userDetailsManager;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return NoOpPasswordEncoder.getInstance();
  }
}
```

이제 db 에 있는 사용자 인증 정보를 넣어서 호출하면 정상 호출된다.
```shell
$ curl -w "%{http_code}" -u assu:1234 http://localhost:8080/hello
hello200%

$ curl -w "%{http_code}"  http://localhost:8080/hello
401%
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.jetbrains.com/help/idea/markdown.html#floating-toolbar)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [Spring Security without the WebSecurityConfigurerAdapter](https://spring.io/blog/2022/02/21/spring-security-without-the-websecurityconfigureradapter)
* [JDBC Authentication](https://spring.io/blog/2022/02/21/spring-security-without-the-websecurityconfigureradapter#jdbc-authentication)
* [WebSecurityConfigurerAdapter deprecated 대응: JDBC 설정](https://soojae.tistory.com/53)