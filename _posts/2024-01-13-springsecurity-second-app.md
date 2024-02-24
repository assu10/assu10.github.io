---
layout: post
title:  "Spring Security - BE, FE 분리된 설계의 애플리케이션 구현"
date:   2024-01-13
categories: dev
tags: spring-security jwt 
---

이 포스트에서는 프론트 엔드와 백엔드가 분리된 웹 애플리케이션의 보안 요구 사항을 충족하는 애플리케이션을 구축해본다.  
그리고 그에 맞는 CSRF 보호와 토큰을 적용하는 법에 대해 알아본다. 

클라이언트, 인증 서버, 비즈니스 논리 서버를 설계한 후 그 중 클라이언트는 제외하고, 인증서버의 백엔드 부분과 비즈니스 논리 서버를 구현해본다.  
이후 한 시스템 안에서 인증과 권한 부여를 분리해본다.

- 토큰의 구현
- JSON 웹 토큰을 이용한 작업
- 여러 앱에서 인증과 권한 부여 책임의 분리
- 다단계 인증 시나리오 구현
- 여러 맞춤형 필터와 여러 `AuthenticationProvider` 객체 이용
- 하나의 시나리오를 위한 다양한 구현 선택

---

**목차**

<!-- TOC -->
* [1. 프로젝트 요구사항](#1-프로젝트-요구사항)
* [2. 토큰 구현](#2-토큰-구현)
  * [2.1. JSON 웹 토큰 (JWT)](#21-json-웹-토큰-jwt)
* [3. 인증 서버 구현](#3-인증-서버-구현)
  * [_/user/add_ 를 호출하여 사용자를 DB 에 추가](#_useradd_-를-호출하여-사용자를-db-에-추가)
  * [위에서 추가한 사용자로 _/user/auth_ 를 호출하여 OTP 가 테이블에 저장되었는지 확인](#위에서-추가한-사용자로-_userauth_-를-호출하여-otp-가-테이블에-저장되었는지-확인)
  * [위에서 생성된 OTP 로 _/otp/check_ 을 호출하여 정상적으로 동작하는지 확인](#위에서-생성된-otp-로-_otpcheck_-을-호출하여-정상적으로-동작하는지-확인)
* [4. 비즈니스 논리 서버 구현](#4-비즈니스-논리-서버-구현)
  * [4.1. `Authentication` 객체 구현](#41-authentication-객체-구현)
  * [4.2. 인증 서버에 대한 프록시 구현](#42-인증-서버에-대한-프록시-구현)
  * [4.3. `AuthenticationProvider` 인터페이스 구현](#43-authenticationprovider-인터페이스-구현)
  * [4.4. 필터 구현](#44-필터-구현)
    * [4.4.1. 인증 서버가 처리하는 인증 관련 필터](#441-인증-서버가-처리하는-인증-관련-필터)
    * [4.4.2. JWT 기반 인증 관련 필터](#442-jwt-기반-인증-관련-필터)
  * [4.5. 보안 구성](#45-보안-구성)
  * [4.6. 전체 시스템 테스트](#46-전체-시스템-테스트)
* [마치며..](#마치며)
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

# 1. 프로젝트 요구사항

구축할 시스템의 구성 요소는 아래와 같다.

- 클라이언트 (실제 여기서는 구현하지 않고 curl 이용)
  - 모바일 앱일수도 있고, 리액트와 같은 프레임워크로 개발된 웹 애플리케이션일수도 있음
- 인증 서버
  - 사용자 자격 증명 DB 를 포함하는 애플리케이션
  - 사용자의 자격 증명(이름,암호) 을 기준으로 사용자를 인증
  - SMS 를 통해 OTP 를 클라이언트로 전송 (MFA, 여기서는 SMS 전송을 하지는 않고 DB 에서 바로 OTP 읽음)
  - 추후 AWS SNS, Twilio 등으로 구현 가능
- 비즈니스 논리 서버
  - 클라이언트가 이용한 엔드포인트가 노출되는 애플리케이션
  - 이 엔드포인트에 대한 접근 보안 적용
  - 엔드포인트를 호출하기 위해 사용자는 먼저 사용자 이름/암호로 인증 후 OTP 를 보내야 함

클라이언트는 비즈니스 논리 서버의 엔드포인트를 호출하기 위해 아래의 단계를 따른다.

- 비즈니스 논리 서버의 _/login_ 엔드포인트를 호출하여 사용자 이름과 암호 인증 후 OTP 수신
- 사용자 이름과 OTP 로 _/login_ 호출 후 토큰 얻음
- 토큰을 HTTP 요청의 Authorization 헤더에 추가하여 다른 엔드포인트 호출

클라이언트가 사용자 이름/암호를 인증하면 비즈니스 논리 서버가 OTP 에 대한 요청을 인증 서버로 보낸다.  
인증이 성공하면 인증 서버가 OTP 코드를 SMS 를 통해 클라이언트로 보낸다.    
클라이언트는 받은 OTP 코드와 사용자 이름으로 비즈니스 논리 서버의 _/login_ 를 호출한다.  
비즈니스 논리 서버는 인증 서버로 코드를 검증하여 코드가 유효하면 클라이언트로 모든 엔드포인트를 호출할 수 있는 토큰을 발급한다.  
클라이언트는 이 토큰으로 비즈니스 논리 서버의 다른 엔드포인트를 호출한다.

> 클라이언트는 인증 서버에만 암호를 공유하고, 비즈니스 논리 서버에는 공유하지 말아야하는 것이 맞지만 프로젝트의 단순화를 위해 위처럼 한다.  
> 또한, Google OTP, Okta 를 이용하면 MFA 를 더 쉽게 구현할 수 있지만 맞춤형 필터를 구현해보는 것이 목적이므로 직접 구현해본다.

---

# 2. 토큰 구현

토큰은 애플리케이션이 사용자를 인증했음을 증명하는 방법을 제공하여 사용자가 애플리케이션의 리소스에 액세스할 수 있게 해준다.

<**인증과 권한 부여 프로세스에서 토큰을 이용하는 일반적인 흐름**>  
- 클라이언트가 자격 증명으로 서버에 자신의 신원을 증명
- 서버가 클라이언트에게 토큰 발급
- 이 토큰은 해당 클라이언트와 연결되고, 서버에 의해 저장됨
- 클라이언트가 엔드포인트를 호출할 때 토큰을 제공하고 권한을 부여받음



<**토큰의 장점**>  
- **엔드포인트 이용시마다 자격 증명을 공유할 필요가 없음**
  - HTTP Basic 인증 방식을 사용하면 요청할 때마다 자격 증명을 보내야하는데 이것은 매번 자격 증명을 노출한다는 의미이므로 자격 증명이 탈취될 기회도 많아짐
  - 토큰을 이용하면 인증을 위한 첫 번째 요청에만 자격 증명을 보내고, 이후 인증으로 받은 토큰으로 리소스를 호출하기 위한 권한을 얻음
  - 즉, 토큰을 얻기 위해 한 번만 자격 증명을 보냄
- **토큰의 수명을 짧게 지정 가능**
  - 토큰이 탈취되더라도 기한이 정해져있으므로 토큰이 만료되면 이용 불가
  - 토큰을 무효로 할 수도 있고, 탈취된 것을 알게된 후 토큰 거부도 가능
- **요청에 필요한 세부 정보를 토큰에 저장 가능**
  - 토큰에 사용자의 권한과 역할 같은 세부 정보를 저장함으로써 서버 쪽 세션을 클라이언트 쪽 세션으로 대체하여 Scale-out 을 위한 높은 유연성 제공 가능
  - > 서버 쪽 세션을 클라이언트 쪽 세션으로 대체하여 Scale-out 을 위한 높은 유연성 제공을 위한 상세한 내용은 추후 다룰 예정입니다.
- **인증 및 권한 부여 책임을 시스템의 다른 구성 요소로 분리 가능**
  - 사용자를 직접 관리하지 않고 github, google 등의 플랫폼을 이용하여 계정의 자격 증명 가능
  - 인증을 수행하는 구성 요소를 구현하기로 했더라도 구현을 별도로 만들 수 있으면 유연성을 향상하는데 도움이 됨
- **아키텍처를 상태 비저장상태로 만들 수 있음**

---

## 2.1. JSON 웹 토큰 (JWT)

JWT 는 3 부분으로 구성되고, 각 부분은 `.`  로 구분된다.  
JWT 는 인증 중에 데이터를 쉽게 전송하고 무결성을 검증하기 위해 데이터에 서명할 수 있다는 이점이 있다.

![JWT 구성](/assets/img/dev/2024/0113/jwt.png)

처음 2 부분은 헤더와 본문으로, JSON 형식으로 형식이 지정되고 요청 헤더를 통해 쉽게 보낼 수 있도록 Base64 로 인코딩된다.

- **헤더**
  - 토큰과 관련된 메타데이터 저장
  - 예) 서명을 생성하는데 이용한 알고리즘 (HS256) 이름 정의
- **본문**
  - 권한 부여에 필요한 세부 정보 저장
  - 토큰은 가급적 짧게 유지하고 본문에 너무 많은 데이터를 추가하지 않는 것이 좋음
  - 토큰이 너무 길면 요청 속도가 느려지고, 토큰에 서명하는 경우 토큰이 길수록 암호화 알고리즘이 서명하는 시간이 길어짐  
  > 어드민 사이트의 경우 토큰이 길어도 크게 상관이 없지만, 유저 유입이 많은 유저사이트의 경우 토큰을 짧게 하는 것이 좋을 것으로 판단됨 
- **디지털 서명** (생략 가능)
  - 헤더와 본문을 바탕으로 생성되는 해시값
  - 나중에 서명을 이용하여 내용이 변경되지 않았는지 확인할 수 있는데, 서명이 없으면 토큰이 탈취되어 내용을 변경하지 않았는지 확신할 수 없음

> [`jjwt (Java Json Web Token)`](https://github.com/jwtk/jjwt#overview) 은 가장 자주 이용되는 라이브러리임

---

# 3. 인증 서버 구현

[1. 프로젝트 요구사항](#1-프로젝트-요구사항) 에서 인증 서버의 요구사항은 아래와 같았다.

- 인증 서버
  - 사용자 자격 증명 DB 를 포함하는 애플리케이션
  - 사용자의 자격 증명(이름,암호) 을 기준으로 사용자를 인증
  - SMS 를 통해 OTP 를 클라이언트로 전송 (MFA, 여기서는 SMS 전송을 하지는 않고 DB 에서 바로 OTP 읽음)
  - 추후 AWS SNS, Twilio 등으로 구현 가능

인증 서버는 사용자 자격 증명과 요청 인증 이벤트 중에 생성된 OTP 가 저장된 DB 에 연결한다.

인증 서버에 필요한 엔드포인트는 총 3개이다.
- _/user/add_: 사용자 추가
- _/user/auth_: 사용자를 인증하고, OTP 가 포함된 SMS 발송 (실제로 발송하지는 않음)
- _/otp/check_: OTP 값이 인증 서버가 특정 사용자를 위해 이전에 생성한 값인지 확인

![인증 서버 클래스 설계](/assets/img/dev/2024/0113/auth_server.png)

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1101) 에 있습니다.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.3</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.assu.study</groupId>
    <artifactId>chap1101</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1101</name>
    <description>chap1101</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <!-- DB 에 사용자 암호 저장 시 BCryptPasswordEncoder 를 사용하기 위해 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
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
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <scope>annotationProcessor</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>
```

인증 서버에 스크링 시큐리티 종속성을 추가한 유일한 이유는 DB 에 저장할 사용자 암호를 해싱할 때 `BCryptPasswordEncoder` 를 사용하기 위함이다.

> 간단히 하기 위해 비즈니스 논리 서버와 인증 서버 간의 인증은 구현하지 않음  
> 실제 구현 시 대칭키와 비대칭키 쌍을 이용하여 구현 가능  
> 
> [2. 기존 필터 앞에 필터 추가](https://assu10.github.io/dev/2023/12/16/springsecurity-filter/#2-%EA%B8%B0%EC%A1%B4-%ED%95%84%ED%84%B0-%EC%95%9E%EC%97%90-%ED%95%84%ED%84%B0-%EC%B6%94%EA%B0%80),  
> [4. 필터 체인의 다른 필터 위치에 필터 추가](https://assu10.github.io/dev/2023/12/16/springsecurity-filter/#4-%ED%95%84%ED%84%B0-%EC%B2%B4%EC%9D%B8%EC%9D%98-%EB%8B%A4%EB%A5%B8-%ED%95%84%ED%84%B0-%EC%9C%84%EC%B9%98%EC%97%90-%ED%95%84%ED%84%B0-%EC%B6%94%EA%B0%80),  
> [1.4. 인코딩, 암호화, 해싱](https://assu10.github.io/dev/2023/11/19/springsecurity-password/#14-%EC%9D%B8%EC%BD%94%EB%94%A9-%EC%95%94%ED%98%B8%ED%99%94-%ED%95%B4%EC%8B%B1) 를 참고하세요.

DB 테이블 스키마는 아래와 같다.

```sql
CREATE TABLE `user` (
  `username` varchar(45) NOT NULL,
  `password` text,
  PRIMARY KEY (`username`)
) COMMENT='사용자 자격 증명 저장';

CREATE TABLE IF NOT EXISTS `security`.`otp`
(
    `username` VARCHAR(45) NOT NULL,
    `code`     VARCHAR(45) NULL,
    PRIMARY KEY (`username`)
) COMMENT='OTP 코드 저장';
```

application.properties
```properties
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.url=jdbc:mysql://localhost:13306/security?serverTimezone=UTC
spring.datasource.username=root
spring.datasource.password=
spring.jpa.show-sql=true
#spring.jpa.defer-datasource-initialization=true
```

/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ProjectConfig {
  // DB 에 저장된 암호를 해싱하는 암호 인코더 정의
  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(c -> c.disable()) // POST 를 포함한 모든 엔드포인트를 호출할 수 있게 csrf 비활성화
        .authorizeHttpRequests(authz -> authz.anyRequest().permitAll());  // 인증없이 모든 호출 허용

    return http.build();
  }
}
```

/entity/User.java
```java
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@ToString
@Getter
@Setter
@Entity
public class User {

  @Id
  private String username;

  @Lob
  private String password;
}
```

/entity/Otp.java
```java
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@ToString
@Getter
@Setter
@Entity
public class Otp {

  @Id
  private String username;

  private String code;
}
```

/repository/UserRepository.java
```java
import com.assu.study.chap1101.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, String> {
  Optional<User> findByUsername(String username);
}
```

/repository/OtpRepository.java
```java

import com.assu.study.chap1101.entity.Otp;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface OtpRepository extends JpaRepository<Otp, String> {
  Optional<Otp> findByUsername(String username);
}
```

**사용자를 추가하는 로직**  
/service/UserService.java
```java
import com.assu.study.chap1101.entity.User;
import com.assu.study.chap1101.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
@Transactional
@Service
public class UserService {

  private final PasswordEncoder passwordEncoder;
  private final UserRepository userRepository;

  // 사용자 추가
  public void addUser(User user) {
    user.setPassword(passwordEncoder.encode(user.getPassword()));
    userRepository.save(user);
  }
}
```

`BCrypPasswordEncoder` 는 해싱 알고리즘으로 `bcrypt` 를 이용하는데, `bcrypt` 는 솔트값을 기반으로 출력이 생성되기 때문에 입력이 같아도 다른 출력을 얻는다.  
실제로 같은 암호를 지정해도 다른 해시값을 얻는 것을 확인할 수 있다.


**OTP 코드 생성 유틸 로직**  
/util/GenerateCodeUtil.java
```java
import lombok.NoArgsConstructor;

import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;

@NoArgsConstructor
public final class GenerateCodeUtil {
  
  public static String generateCode() {
    String code;

    try {
      // 임의의 int 값을 생성하는 SecureRandom 인스턴스 생성
      SecureRandom random = SecureRandom.getInstanceStrong();
      
      // 0~8,999 사이의 값을 생성하고 1,000을 더해서 1,000~9,999 (4자리 코드) 사이의 값 얻음
      int c = random.nextInt(9000) + 1000;
      
      // int 를 String 응로 변환하여 반환
      code = String.valueOf(c);
    } catch (NoSuchAlgorithmException e) {
      throw new RuntimeException("Error when generating the random code.");
    }

    return code;
  }
}
```

> immutable class 설계는 [9. Spring bean, Java bean, DTO, VO](https://assu10.github.io/dev/2023/05/07/springboot-spring/#9-spring-bean-java-bean-dto-vo) 를 참고하세요.

**사용자 인증 후 OTP 를 생성하여 유저에게 발송하는 로직**  
/service/UserService.java
```java
import com.assu.study.chap1101.entity.Otp;
import com.assu.study.chap1101.entity.User;
import com.assu.study.chap1101.repository.OtpRepository;
import com.assu.study.chap1101.repository.UserRepository;
import com.assu.study.chap1101.util.GenerateCodeUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@RequiredArgsConstructor
@Transactional
@Service
public class UserService {

  private final PasswordEncoder passwordEncoder;
  private final UserRepository userRepository;
  private final OtpRepository otpRepository;

  // ...

  // 사용자 인증 후 OTP 생성하여 SMS 를 통해 발송
  public void auth(User user) {
    Optional<User> oUser = userRepository.findByUsername(user.getUsername());

    // 사용자가 있으면 암호를 확인 후 새로운 OTP 생성
    // 사용자가 없거나 암호가 틀리면 예외 발생
    if (oUser.isPresent()) {
      User u = oUser.get();
      if (passwordEncoder.matches(user.getPassword(), u.getPassword())) {
        renewOtp(u);
      } else {
        throw new BadCredentialsException("Bad Credentials");
      }
    } else {
      throw new BadCredentialsException("Bad Credentials");
    }
  }

  private void renewOtp(User user) {
    String code = GenerateCodeUtil.generateCode();

    Optional<Otp> userOtp = otpRepository.findByUsername(user.getUsername());

    // 이 사용자에 대한 otp 가 있으면 otp 값 업데이트
    Otp otp;
    if (userOtp.isPresent()) {
      otp = userOtp.get();
    } else {
      otp = new Otp();
      // 이 사용자에 대한 opt 가 없으면 새로 생성된 값으로 레코드 생성
      otp.setUsername(user.getUsername());
    }
    otp.setCode(code);

    otpRepository.save(otp);
  }
}
```

**사용자의 OTP 검증**  
/service/UserService.java
```java
import com.assu.study.chap1101.entity.Otp;
import com.assu.study.chap1101.repository.OtpRepository;
import com.assu.study.chap1101.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@RequiredArgsConstructor
@Transactional
@Service
public class UserService {

  private final PasswordEncoder passwordEncoder;
  private final UserRepository userRepository;
  private final OtpRepository otpRepository;

  // ...
  
  // 사용자의 OTP 검증
  public boolean check(Otp otp) {
    // 사용자 이름으로 OTP 검색
    Optional<Otp> userOtp = otpRepository.findByUsername(otp.getUsername());

    if (userOtp.isPresent()) {
      Otp o = userOtp.get();
      // DB 에 OTP 가 있고, 비즈니스 논리 서버에서 받은 OTP 와 일차하면 true 반환
      return otp.getCode().equals(o.getCode());
    }
    return false;
  }
}
```

**엔드포인트 추가**  
/controller/AuthController.java
```java
import com.assu.study.chap1101.entity.Otp;
import com.assu.study.chap1101.entity.User;
import com.assu.study.chap1101.service.UserService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RequiredArgsConstructor
@RestController
public class AuthController {

  private final UserService userService;

  // 사용자 추가
  @PostMapping("/user/add")
  public void addUser(@RequestBody User user) {
    userService.addUser(user);
  }

  // 사용자 인증 후 OTP 생성하여 SMS 를 통해 발송
  @PostMapping("/user/auth")
  public void auth(@RequestBody User user) {
    userService.auth(user);
  }

  // 사용자의 OTP 검증
  @PostMapping("/otp/check")
  public void check(@RequestBody Otp otp, HttpServletResponse response) {
    if (userService.check(otp)) {
      response.setStatus(HttpServletResponse.SC_OK);
    } else {
      response.setStatus(HttpServletResponse.SC_FORBIDDEN); // 403
    }
  }
}
```

이제 아래와 같은 흐름으로 인증 서버의 기능을 테스트한다.
- _/user/add_ 를 호출하여 사용자를 DB 에 추가
- 위에서 추가한 사용자로 _/user/auth_ 를 호출하여 OTP 가 테이블에 저장되었는지 확인
- 위에서 생성된 OTP 로 _/otp/check_ 을 호출하여 정상적으로 동작하는지 확인

---

## _/user/add_ 를 호출하여 사용자를 DB 에 추가

```shell
$ curl --location 'http://localhost:8080/user/add' \
--header 'Content-Type: application/json' \
--data '{
    "username": "assu",
    "password": "1111"
}'
```

DB 에 보면 아래와 같이 유저가 추가된 것을 확인할 수 있다.
![DB 에 사용자 추가](/assets/img/dev/2024/0113/step_1.png)

---

## 위에서 추가한 사용자로 _/user/auth_ 를 호출하여 OTP 가 테이블에 저장되었는지 확인

```shell
$ curl --location 'http://localhost:8080/user/auth' \
--header 'Content-Type: application/json' \
--data '{
    "username": "assu",
    "password": "1111"
}'
```

![DB 에 OTP 추가](/assets/img/dev/2024/0113/step_2.png)

---

## 위에서 생성된 OTP 로 _/otp/check_ 을 호출하여 정상적으로 동작하는지 확인

올바른 OTP 일 경우
```shell
$  curl -w %{http_code} --location 'http://localhost:8080/otp/check' \
--header 'Content-Type: application/json' \
--data '{
    "username": "assu",
    "code": "2207"
}'
200%
```

잘못된 OTP 일 경우
```shell
$ url -w %{http_code} --location 'http://localhost:8080/otp/check' \
--header 'Content-Type: application/json' \
--data '{
    "username": "assu",
    "code": "2208"
}'
403%
```

---

# 4. 비즈니스 논리 서버 구현

[1. 프로젝트 요구사항](#1-프로젝트-요구사항) 에서 비즈니스 논리 서버의 요구 사항은 아래와 같았다.
- 비즈니스 논리 서버
  - 클라이언트가 이용한 엔드포인트가 노출되는 애플리케이션
  - 이 엔드포인트에 대한 접근 보안 적용
  - 엔드포인트를 호출하기 위해 사용자는 먼저 사용자 이름/암호로 인증 후 OTP 를 보내야 함

비즈니스 논리 서버 구축 후 인증 서버 간의 통신도 구현한다.

흐름은 아래와 같다.
- 보호할 리소스에 해당하는 엔드포인트 생성
- 첫 번째 인증: 클라이언트가 자격 증명을 비즈니스 논리 서버로 보내고 로그인
- 두 번째 인증: 클라이언트가 인증 서버에서 사용자가 받은 OTP 를 비즈니스 논리 서버로 보내고, OTP 로 인증이 되면 클라이언트는 리소스 접근에 필요한 JWT 를 발급받음
- JWT 인증: 비즈니스 논리 서버가 클라이언트로부터 받은 JWT 를 검증 후 리소스에 접근할 수 있도록 허용

위의 흐름대로 진행되기 위해 아래와 같은 순서로 서버를 구축한다.
- 2 개의 인증 단계를 나타내는 역할을 하는 `Authentication` 객체 구현
- 인증 서버와 비즈니스 논리 서버 간의 통신을 수행하는 프록시 구현
- `Authentication` 객체로 2 개의 인증 논리를 구현하는 `AuthenticationProvider` 객체 정의
- HTTP 요청을 가로채고 `AuthenticationProvider` 객체로 구현하는 인증 논리를 적용하는 맞춤형 필터 객체 정의
- 보안 구성: 권한 부여 구성

> 소스는 [github](https://github.com/assu10/spring-security/tree/feature/chap1102) 에 있습니다.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.3</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.assu.study</groupId>
    <artifactId>chap1102</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>chap1102</name>
    <description>chap1102</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>

        <!-- JWT 생성과 구문 분석을 위한 jjwt 종속성 -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>0.12.5</version>
        </dependency>
        <!-- JWT 생성과 구문 분석을 위한 jjwt 종속성 -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>0.12.5</version>
            <scope>runtime</scope>
        </dependency>
        <!-- JWT 생성과 구문 분석을 위한 jjwt 종속성 -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>0.12.5</version>
            <scope>runtime</scope>
        </dependency>
        <!-- java10 이상에 필요한 종속성 -->
        <dependency>
            <groupId>jakarta.xml.bind</groupId>
            <artifactId>jakarta.xml.bind-api</artifactId>
            <version>4.0.1</version>
        </dependency>
        <!-- java10 이상에 필요한 종속성 -->
        <dependency>
            <groupId>org.glassfish.jaxb</groupId>
            <artifactId>jaxb-runtime</artifactId>
            <version>4.0.4</version>
        </dependency>

    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>

</project>
```

/controller/HelloController.java
```java
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
  @GetMapping("/hello")
  public String hello() {
    return "hello";
  }
}
```

![인증 흐름](/assets/img/dev/2024/0113/auth.png)

스프링 시큐리티의 인증 아키텍처 흐름은 아래와 같다.
![스프링 시큐리티의 인증 프로세스에 포함된 주 구성 요소](/assets/img/dev/2023/1125/security.png)

비즈니스 논리 서버는 사용자를 관리하지 않기 때문에 위 그림에서 `UserDetailsService` 와 `PasswordEncoder` 는 필요없다.

---

위 조건에 맞게 아키텍처를 구성하는 시나리오는 2가지 정도가 있다.

첫 번째는 3개의 맞춤형 `Authentication` 객체와 3개의 맞춤형 `AuthenticationProvider` 객체, 1개의 맞춤형 필터를 정의한 후 `AuthenticationManager` 를 이용하여 
인증 책임을 위임하는 방법이다.

> `Authentication`, `AuthenticationProvider` 인터페이스의 구현은 [Spring Security - 인증 구현(1): AuthenticationProvider](https://assu10.github.io/dev/2023/11/25/springsecurity-authrorization-1/) 를 참고하세요.

![아키텍처 구현 #1](/assets/img/dev/2024/0113/archi_1.png)

`AuthenticationFilter` 가 요청을 가로챈 후 인증 단계에 따라 특정한 `Authentication` 객체를 만들어서 `AuthenticationManager` 에게 전달한다.  
`Authentication` 객체를 각 인증 단계를 나타내며, 각 인증 단계별로 `AuthenticationProvider` 가 인증 논리를 구현한다.


두 번째는 앞으로 진행할 방식이며, 2개의 맞춤형 `Authentication` 객체와 2개의 맞춤형 `AuthenticationProvider` 객체를 이용한다.  
이 객체들의 역할은 각각 자격 증명으로 사용자를 인증하고, OTP 로 사용자를 인증하는 역할이다.  
이 후 두 번째 필터로 토큰 검증을 구현한다.

![아키텍처 구현 #2](/assets/img/dev/2024/0113/archi_2.png)

위 아키텍처는 인증 책임을 2개의 필터로 분리한다.  
첫 번째 필터는 _/login_ 경로에 대해 사용자 이름/암호, 사용자 이름/OTP 인증을 처리하고, 두 번째 필터는 JWT 토큰을 검증해야 하는 나머지 엔드포인트에 대해 인증한다.

---

## 4.1. `Authentication` 객체 구현

위에서 본 것처럼 사용자 이름/암호, 사용자 이름/OTP, 2가지 형식의 `Authentication` 객체를 정의한다.

`Authentication` 계약은 인증 요청 이벤트이며, 인증 진행 중 또는 인증 완료 후의 프로세스 일 수도 있다.

**사용자 이름/암호를 이용한 인증을 구현하는 클래스**

/authentication/UsernamePasswordAuthentication.java
```java
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;

import java.util.Collection;

/**
 * 사용자 이름/암호를 이용한 인증을 구현하는 클래스
 * Authentication 는 간접적으로 확장됨
 */
public class UsernamePasswordAuthentication extends UsernamePasswordAuthenticationToken {

  /**
   * 인증 인스턴스가 인증되지 않은 상태로 유지됨
   * 
   * Authentication 객체가 인증 상태로 설정되지 않고, 프로세스 중 예외로 발생하지 않았다면 
   * AuthenticationManager 는 요청을 인증할 AuthenticationProvider 객체를 찾음
   */
  public UsernamePasswordAuthentication(Object principal, Object credentials) {
    super(principal, credentials);
  }

  /**
   * Authentication 객체가 인증됨 (= 인증 프로세스가 완료됨)
   * 
   * AuthenticationProvider 객체가 요청을 인증할 때는 이 생성자를 호출하여 Authentication 인스턴스를 만들고, 
   * 이 때는 인증된 객체가 됨
   * 
   * @param authorities 허가된 권한의 컬렉션이며, 완료된 인증 프로세스에서는 필수임
   */
  public UsernamePasswordAuthentication(Object principal, Object credentials, Collection<? extends GrantedAuthority> authorities) {
    super(principal, credentials, authorities);
  }
}
```

**사용자 이름/OTP를 이용한 인증을 구현하는 클래스**

/authentication/OtpAuthentication.java
```java
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

/**
 * 사용자 이름/OTP를 이용한 인증을 구현하는 클래스
 * Authentication 는 간접적으로 확장됨
 */
public class OtpAuthentication extends UsernamePasswordAuthenticationToken {
  public OtpAuthentication(Object principal, Object credentials) {
    super(principal, credentials);
  }

//  public OtpAuthentication(Object principal, Object credentials, Collection<? extends GrantedAuthority> authorities) {
//    super(principal, credentials, authorities);
//  }
}
```

---

## 4.2. 인증 서버에 대한 프록시 구현

인증 서버가 노출하는 REST 엔드포인트를 호출하는 법에 대해 알아본다.

`Authentication` 객체를 정의한 후에는 보통 `AuthenticationProvider` 객체를 구현하지만, `AuthenticationProvider` 는 `AuthenticationServerProxy` 를 이용하여 인증 서버를 호출하므로 
인증 서버에 대한 프록시부터 구현해본다.

![AuthenticationServerProxy](/assets/img/dev/2024/0113/proxy.png)

인증을 완료하려면 인증 서버를 호출하는 방법이 필요하다.

- 인증 서버가 노출하는 REST API 를 호출할 때 사용할 모델 클래스 User 정의
- 인증 서버가 노출하는 REST API 를 호출하는데 이용할 RestTemplate 형식의 빈 선언
- 사용자 이름/암호, 사용자 이름/OTP 인증을 수행하는 메서드 2개를 정의하는 프록시 클래스 구현


**인증 서버가 노출하는 REST API 를 호출할 때 사용할 모델 클래스 User**  
/authentication/model/User.java
```java
import lombok.Getter;
import lombok.Setter;

/**
 * 인증 서버가 노출하는 REST API 를 호출할 때 사용할 모델 클래스
 */
@Getter
@Setter
public class User {
  private String username;
  private String password;
  private String code;
}
```

**인증 서버가 노출하는 REST API 를 호출하는데 이용할 RestTemplate 형식의 빈 선언**  
/config/ProjectConfig.java
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

/**
 * 인증 서버가 노출하는 REST API 를 호출하는데 이용할 RestTemplate 형식의 빈 선언
 */
@Configuration
public class ProjectConfig {
  @Bean
  public RestTemplate restTemplate() {
    return new RestTemplate();
  }
}
```

**사용자 이름/암호, 사용자 이름/OTP 인증을 수행하는 메서드 2개를 정의하는 프록시 클래스**  
/proxy/AuthenticationServerProxy.java
```java
import com.assu.study.chap1102.authtication.model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@RequiredArgsConstructor
@Component  // 이 형식의 인스턴스를 컨텍스트에 포함시킴
public class AuthenticationServerProxy {

  private final RestTemplate restTemplate;

  @Value("${auth.server.base.url}")
  private String baseUrl;

  /**
   * 사용자 이름/암호 인증을 수행
   */
  public void sendAuth(String username, String password) {
    String url = baseUrl + "/user/auth";

    User body = new User();
    body.setUsername(username);
    body.setPassword(password);

    HttpEntity request = new HttpEntity<>(body);

    restTemplate.postForEntity(url, request, Void.class);
  }

  /**
   * 사용자 이름/OTP 인증을 수행
   */
  public boolean sendOtp(String username, String code) {
    String url = baseUrl + "/otp/check";

    User body = new User();
    body.setUsername(username);
    body.setCode(code);

    HttpEntity request = new HttpEntity<>(body);

    ResponseEntity response = restTemplate.postForEntity(url, request, Void.class);

    return response.getStatusCode().equals(HttpStatus.OK);
  }
}
```

application.properties
```properties
server.port=9090
auth.server.base.url=http://localhost:8080
jwt.signing.key=ymLTU8rq83j4fmJZj60wh4OrMNuntIj4fmJ
```

---

## 4.3. `AuthenticationProvider` 인터페이스 구현

맞춤형 인증 논리를 기술할 `AuthenticationProvider` 를 구현한다.

`Authentication` 의 _UsernamePasswordAuthentication_ 형식을 지원할 _UsernamePasswordAuthenticationProvider_ 와 _OtpAuthenticationProvider_ 를 구현한다.

이 단계에서는 아직 `Authentication` 객체가 인증된 상태가 아니므로 매개 변수가 2개인 `UsernamePasswordAuthentication(Object principal, Object credentials)` 생성자를 이용하여 `Authentication` 객체를 만든다.

**사용자 이름/암호의 인증 논리 구현 클래스**  
/provider/UsernamePasswordAuthenticationProvider.java
```java
import com.assu.study.chap1102.authtication.UsernamePasswordAuthentication;
import com.assu.study.chap1102.authtication.proxy.AuthenticationServerProxy;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.stereotype.Component;

/**
 * 사용자 이름/암호의 인증 논리 구현 클래스
 */
@RequiredArgsConstructor
@Component  // 이 형식의 인스턴스를 컨텍스트에 포함시킴
public class UsernamePasswordAuthenticationProvider implements AuthenticationProvider {

  private final AuthenticationServerProxy authenticationServerProxy;

  @Override
  public Authentication authenticate(Authentication authentication) throws AuthenticationException {
    String username = authentication.getName();
    String password = String.valueOf(authentication.getCredentials());

    // 프록시를 통해 인증 서버로 사용자 이름/암호 인증 요청
    // 인증이 되면 인증 서버는 SMS 로 클라이언트에게 OTP 전송
    authenticationServerProxy.sendAuth(username, password);

    return new UsernamePasswordAuthenticationToken(username, password);
  }

  /**
   * AuthenticationProvider 가 어떤 종류의 Authentication 인터페이스를 지원할 지 결정
   * 이는 authenticate() 메서드의 매개 변수로 어떤 형식이 제공될지에 따라서 달라짐
   * <p>
   * AuthenticationFilter 수준에서 아무것도 맞춤 구성하지 않으면 UsernamePasswordAuthenticationToken 클래스가 형식을 정의함
   */
  @Override
  public boolean supports(Class<?> authentication) {
    return UsernamePasswordAuthentication.class.isAssignableFrom(authentication);
  }
}
```

**사용자 이름/OTP의 인증 논리 구현 클래스**  
/provider/OtpAuthenticationProvider.java
```java
import com.assu.study.chap1102.authtication.OtpAuthentication;
import com.assu.study.chap1102.authtication.proxy.AuthenticationServerProxy;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.stereotype.Component;

/**
 * 사용자 이름/OTP의 인증 논리 구현 클래스
 */
@RequiredArgsConstructor
@Component  // 이 형식의 인스턴스를 컨텍스트에 포함시킴
public class OtpAuthenticationProvider implements AuthenticationProvider {

  private final AuthenticationServerProxy authenticationServerProxy;

  @Override
  public Authentication authenticate(Authentication authentication) throws AuthenticationException {
    String username = authentication.getName();
    String code = String.valueOf(authentication.getCredentials());

    boolean result = authenticationServerProxy.sendOtp(username, code);

    // OTP 가 맞으면 Authentication 인스턴스를 반환하고, 필터가 HTTP 응답에 토큰을 보냄
    if (result) {
      // 아직 `Authentication` 객체가 인증된 상태가 아니므로
      // 매개 변수가 2개인
      // `OtpAuthentication(Object principal, Object credentials)` 생성자를 이용하여
      // `Authentication` 객체 생성
      return new OtpAuthentication(username, code);
    } else {
      // OTP 가 틀리면 예외 발생
      throw new BadCredentialsException("bad credentials");
    }
  }

  /**
   * AuthenticationProvider 가 어떤 종류의 Authentication 인터페이스를 지원할 지 결정
   * 이는 authenticate() 메서드의 매개 변수로 어떤 형식이 제공될지에 따라서 달라짐
   * <p>
   * AuthenticationFilter 수준에서 아무것도 맞춤 구성하지 않으면 UsernamePasswordAuthenticationToken 클래스가 형식을 정의함
   */
  @Override
  public boolean supports(Class<?> authentication) {
    return OtpAuthentication.class.isAssignableFrom(authentication);
  }
}
```

OTP 가 맞으면 Authentication 인스턴스를 반환하고, 필터가 HTTP 응답에 토큰을 보낸다.  
OTP 가 틀리면 AuthenticationProvider 는 예외를 발생시킨다.

---

## 4.4. 필터 구현

이제 요청을 가로채서 인증 논리를 적용할 맞춤형 필터를 구현한다.

![인증 흐름](/assets/img/dev/2024/0113/auth.png)

![아키텍처 구현 #2](/assets/img/dev/2024/0113/archi_2.png)

2개의 필터를 만드는데 각 필터의 역할은 아래와 같다.
- _InitialAuthenticationFilter_
  - 인증 서버가 수행하는 인증을 처리
- _JwtAuthenticationFilter_
  - JWT 기반 인증을 처리

---

### 4.4.1. 인증 서버가 처리하는 인증 관련 필터

> 아래 코드 작성 시 `Could not autowire. No beans of 'AuthenticationManager' type found.` 오류가 뜨는데  
> [4.5. 보안 구성](#45-보안-구성) 에서 빈으로 등록해주고 나면 오류가 사라집니다.

/filter/InitialAuthenticationFilter.java
```java
import com.assu.study.chap1102.authtication.OtpAuthentication;
import com.assu.study.chap1102.authtication.UsernamePasswordAuthentication;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.crypto.SecretKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

@RequiredArgsConstructor
@Component
public class InitialAuthenticationFilter extends OncePerRequestFilter {

  // 인증 관리자, 인증 책임을 위임
  private final AuthenticationManager authenticationManager;

  @Value("${jwt.signing.key}")
  private String SIGNING_KEY;

  /**
   * 요청이 필터 체인에서 이 필터에 도달할 때 호출됨
   * <p>
   * OTP 를 얻기 위해 사용자 이름/암호를 보내는 인증 논리 구현
   */
  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
    // HTTP 요청 헤더를 통해 자격 인증 정보가 넘어옴
    String username = request.getHeader("username");
    String password = request.getHeader("password");
    String code = request.getHeader("code");

    // 헤더에 OTP 가 없으면 사용자 이름/암호 인증으로 가정
    if (code == null) {
      Authentication authentication = new UsernamePasswordAuthentication(username, password);

      // 따라서 OTP 가 없으면 UsernamePasswordAuthentication 인스턴스를 만든 후 책임을 AuthenticationManager 에게 전달하여 첫 번째 인증단계 호출
      // AuthenticationManager 는 해당하는 AuthenticationProvider 를 찾음
      // UsernamePasswordAuthenticationProvider.supports() 가 UsernamePasswordAuthentication 형식을 받는다고
      // 선언하였으므로 UsernamePasswordAuthenticationProvider 로 인증 책임을 위임함
      authenticationManager.authenticate(authentication);
    } else {
      // 헤더에 OTP 가 있으면 사용자 이름/OTP 인증 단계라고 가정
      // OtpAuthentication 형식의 인스턴스를 만든 후 책임을 AuthenticationManager 에게 전달하여 두 번째 인증단계 호출
      Authentication authentication = new OtpAuthentication(username, code);
      authenticationManager.authenticate(authentication);

      // OtpAuthenticationProvider 에 OTP 가 틀리면 인증이 실패하면서 예외가 발생하므로
      // OTP 가 유효할 때만 JWT 토큰이 생성되고, HTTP 응답 헤더에 포함됨

      // 대칭키로 서명 생성
      SecretKey key = Keys.hmacShaKeyFor(SIGNING_KEY.getBytes(StandardCharsets.UTF_8));

      // TODO: deprecated
      // JWT 생성 후 인증된 사용자의 이름을 클레임 중 하나로 저장함
      // 토큰을 서명하는데 키를 이용함
      String jwt = Jwts.builder()
              .setClaims(Map.of("username", username))  // 본문에 값 추가
              .signWith(key)  // 비대칭키로 토큰에 서명 첨부
              .compact();

      // 토큰을 HTTP 응답의 권한 부여 헤더에 추가
      response.setHeader("Authorization", jwt);
    }
  }

  /**
   * /login 경로가 아니면 이 필터를 실행하지 않음
   */
  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) throws ServletException {
    return !request.getServletPath().equals("/login");
  }
}

```

> 위에선 예외 처리나 로그 등은 남기지 않는데 실제 운영 시엔 모두 처리해주어야 함

위에서 JWT 토큰 만드는 부분을 보자.
```java
// 대칭키로 서명 생성
SecretKey key = Keys.hmacShaKeyFor(SIGNING_KEY.getBytes(StandardCharsets.UTF_8));

// JWT 생성 후 인증된 사용자의 이름을 클레임 중 하나로 저장함
// 토큰을 서명하는데 키를 이용함
String jwt = Jwts.builder()
        .setClaims(Map.of("username", username))  // 본문에 값 추가
        .signWith(key)  // 비대칭키로 토큰에 서명 첨부
        .compact();
```

서명키는 비즈니스 논리 서버만 알고 있다.

여기선 간단히 구현하기 위해 모든 사용자가 하나의 키를 이용하지만 **실제 운영 시엔 사용자별로 다른 키를 사용**해야 한다.

사용자별 키를 사용하면 한 사용자의 모든 토큰을 무효화해야 하는 경우에 해당 키만 변경하면 된다.

---

### 4.4.2. JWT 기반 인증 관련 필터

/filter/JwtAuthenticationFilter.java
```java
import com.assu.study.chap1102.authtication.UsernamePasswordAuthentication;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.crypto.SecretKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * JWT 기반 인증 관련 필터
 * <p>
 * 요청의 권한 부여 HTTP 헤더에 JWT 가 있다고 가정하고, 서명을 확인하여 JWT 검증 후
 * 인증된 Authentication 객체를 만들어 SecurityContext 에 추가함
 */
@RequiredArgsConstructor
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

  @Value("${jwt.signing.key}")
  private String SIGNING_KEY;

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
    String jwt = request.getHeader("Authorization");

    SecretKey key = Keys.hmacShaKeyFor(SIGNING_KEY.getBytes(StandardCharsets.UTF_8));

    // TODO: deprecated
    // 토큰을 구문 분석하여 클레임을 얻고, 서명을 검증함
    // 서명이 유효하지 않으면 예외가 발생함
    Claims claims = Jwts.parser()
        .setSigningKey(key)
        .build()
        .parseClaimsJws(jwt)
        .getBody();

    String username = String.valueOf(claims.get("username"));

    // SecurityContext 에 추가할 Authentication 인스턴스 생성
    GrantedAuthority grantedAuthority = new SimpleGrantedAuthority("user");

    // 인증이 되었으므로 매개변수가 3개인 생성자로 Authentication 인스턴스 생성
    UsernamePasswordAuthentication auth = new UsernamePasswordAuthentication(username, null, List.of(grantedAuthority));

    // SecurityContext 에 Authentication 객체 추가
    SecurityContextHolder.getContext().setAuthentication(auth);

    // 필터 체인의 다음 필터 호출
    filterChain.doFilter(request, response);
  }

  /**
   * /login 경로이면 이 필터를 실행하지 않음
   * 즉, /login 외의 다른 모든 경로에 대한 요청 처리
   */
  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) throws ServletException {
    return request.getServletPath().equals("/login");
  }
}
```

---

## 4.5. 보안 구성

이제 보안 구성을 정의한다.

- [필터 체인에 필터 추가](https://assu10.github.io/dev/2023/12/16/springsecurity-filter/)
- [CSRF 보호 비활성화](https://assu10.github.io/dev/2023/12/17/springsecurity-csrf/), 여기서는 JWT 를 이용하므로 CSRF 토큰을 통한 검증을 대신할 수 있음
- `AuthenticationManager` 가 인식할 수 있게 [`AuthenticationProvider` 객체 추가](https://assu10.github.io/dev/2023/11/25/springsecurity-authrorization-1/#13-%EB%A7%9E%EC%B6%A4%ED%98%95-%EC%9D%B8%EC%A6%9D-%EB%85%BC%EB%A6%AC-%EC%A0%81%EC%9A%A9-authenticationprovider)
- [선택기 메서드를 이용하여 인증이 필요한 모든 요청 구성](https://assu10.github.io/dev/2023/12/09/springsecurity-authorization-2/)
- _InitialAuthenticationFilter_ 에서 주입할 수 있게 [`AuthenticationManager` 빈 추가](https://assu10.github.io/dev/2023/11/25/springsecurity-authrorization-1/#13-%EB%A7%9E%EC%B6%A4%ED%98%95-%EC%9D%B8%EC%A6%9D-%EB%85%BC%EB%A6%AC-%EC%A0%81%EC%9A%A9-authenticationprovider)

/config/SecurityConfig.java
```java
import com.assu.study.chap1102.authtication.filter.InitialAuthenticationFilter;
import com.assu.study.chap1102.authtication.filter.JwtAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.www.BasicAuthenticationFilter;

@Configuration
public class SecurityConfig {
  // filter 주입
  private final InitialAuthenticationFilter initialAuthenticationFilter;
  private final JwtAuthenticationFilter jwtAuthenticationFilter;

  public SecurityConfig(InitialAuthenticationFilter initialAuthenticationFilter, JwtAuthenticationFilter jwtAuthenticationFilter) {
    this.initialAuthenticationFilter = initialAuthenticationFilter;
    this.jwtAuthenticationFilter = jwtAuthenticationFilter;
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(c -> c.disable()) // POST 를 포함한 모든 엔드포인트를 호출할 수 있게 csrf 비활성화
        .addFilterAt(initialAuthenticationFilter, BasicAuthenticationFilter.class)  // 필터 체인에 필터 추가
        .addFilterAfter(jwtAuthenticationFilter, BasicAuthenticationFilter.class)
        .authorizeHttpRequests(authz -> authz.anyRequest().authenticated());  // 모든 요청이 인증되게 함

    return http.build();
  }
}
```

/config/ProviderConfig.java
```java
import com.assu.study.chap1102.authtication.provider.OtpAuthenticationProvider;
import com.assu.study.chap1102.authtication.provider.UsernamePasswordAuthenticationProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;

import java.util.Arrays;

@Configuration
public class ProviderConfig {

  // AuthenticationProvider 주입
  private final UsernamePasswordAuthenticationProvider usernamePasswordAuthenticationProvider;
  private final OtpAuthenticationProvider otpAuthenticationProvider;

  public ProviderConfig(UsernamePasswordAuthenticationProvider usernamePasswordAuthenticationProvider, OtpAuthenticationProvider otpAuthenticationProvider) {
    this.usernamePasswordAuthenticationProvider = usernamePasswordAuthenticationProvider;
    this.otpAuthenticationProvider = otpAuthenticationProvider;
  }

  /**
   * 맞춤 구성한 AuthenticationProviderService 구현 연결
   */
  @Bean
  public AuthenticationManager authenticationManager() throws Exception {
    return new ProviderManager(Arrays.asList(this.usernamePasswordAuthenticationProvider, this.otpAuthenticationProvider));
  }
}
```

---

## 4.6. 전체 시스템 테스트

이제 애플리케이션 동작을 확인한다.

인증 서버의 포트는 8080 이고, 비즈니스 논리 서버의 포트는 9090 이다.

**헤더에 사용자 이름/암호 자격 증명을 넣어서 비즈니스 논리 서버의 _/login_ 호출**  
```shell
$ curl --location 'http://localhost:9090/login' \
--header 'username: assu' \
--header 'password: 1111'
```

이제 OTP 테이블에 생성된 OTP 코드를 넣어서 토큰을 얻는다.

**헤더에 사용자 이름/OTP 를 넣어서 비즈니스 논리 서버의 _/login_ 호출**  
```shell
$ curl -v --location 'http://localhost:9090/login' \
--header 'username: assu' \
--header 'code: 2932'
```

curl 에 `-v` 옵션을 넣어 응답 헤더를 본다.
```text
< Authorization: eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6ImFzc3UifQ.2A2MBByWuj33TYwams_7RtOIBBrAQcokmDkx6LGv3fI
```

**헤더에 토큰을 넣어서 비즈니스 논리 서버의 _/hello_ 호출**  
```shell
$ curl --location 'http://localhost:9090/hello' \
--header 'Authorization: eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6ImFzc3UifQ.2A2MBByWuj33TYwams_7RtOIBBrAQcokmDkx6LGv3fI'
hello%
```

유효한 토큰일 경우만 엔드포인트 호출이 가능한 것을 확인할 수 있다.

---

# 마치며..

- JWT 토큰은 서명하거나 완전히 암호화할 수 있음
  - 서명된 JWT 토큰을 JWS (JSON Web Signed) 라고 하고, 세부 정보가 완전히 암호화된 토큰은 JWE (JSON Web Token Encrypted) 라고 함
- JWT 에 너무 많은 세부 정보를 저장하지 않는 것이 좋음
  - 토큰이 서명되거나 암호화되면 토큰이 길수록 이를 서명하거나 암호화하는데 시간이 많이 걸림
  - 또한 토큰은 HTTP 요청에 헤더로 보냄
  - 토큰이 길면 각 요청에 추가되는 데이터가 증가하고, 애플리케이션의 성능이 크게 영향을 받음

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.jetbrains.com/help/idea/markdown.html#floating-toolbar)
* [Configuration Migrations](https://docs.spring.io/spring-security/reference/5.8/migration/servlet/config.html)
* [Spring Boot 3.x + Security 6.x 기본 설정 및 변화](https://velog.io/@kide77/Spring-Boot-3.x-Security-%EA%B8%B0%EB%B3%B8-%EC%84%A4%EC%A0%95-%EB%B0%8F-%EB%B3%80%ED%99%94)
* [스프링 부트 2.0에서 3.0 스프링 시큐리티 마이그레이션 (변경점)](https://nahwasa.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%EB%B6%80%ED%8A%B8-20%EC%97%90%EC%84%9C-30-%EC%8A%A4%ED%94%84%EB%A7%81-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%A7%88%EC%9D%B4%EA%B7%B8%EB%A0%88%EC%9D%B4%EC%85%98-%EB%B3%80%EA%B2%BD%EC%A0%90)
* [jjwt: github](https://github.com/jwtk/jjwt#overview)