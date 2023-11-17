---
layout: post
title:  "Spring Boot - 웹 애플리케이션 구축 (5): 국제화 메시지 처리, 로그 설정, 애플리케이션 패키징과 실행"
date:   2023-08-19
categories: dev
tags: springboot msa i18n locale-resolver locale-change-interceptor logger logback logback-spring maven-packaging docker
---

이 포스트에서는 국제화 기능(i18n) 과 로그를 설정하고, 애플리케이션을 패키징한 후 도커를 통해 실행하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap06) 에 있습니다.

---

**목차**

- [REST-API 와 국제화 메시지 처리](#1-rest-api-와-국제화-메시지-처리)
  - [message.properties 파일 설정](#11-messageproperties-파일-설정)
  - [MessageSource 인터페이스](#12-messagesource-인터페이스)
  - [스프링 부트 프레임워크의 자동 설정 구성](#13-스프링-부트-프레임워크의-자동-설정-구성)
  - [`LocaleResolver` 와 `LocaleChangeInterceptor` 설정](#14-localeresolver-와-localechangeinterceptor-설정)
- [로그 설정](#2-로그-설정)
  - [Logger 선언](#21-logger-선언)
  - [logback-spring.xml](#22-logback-springxml)
  - [중앙 수집 로그](#23-중앙-수집-로그)
- [애플리케이션 패키징과 실행](#3-애플리케이션-패키징과-실행)
  - [Maven 패키징](#31-maven-패키징)
  - [Docker 이미지 생성](#32-docker-이미지-생성)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap06

![Spring Initializer](/assets/img/dev/2023/0805/init.png)

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>com.assu</groupId>
    <artifactId>study</artifactId>
    <version>1.1.0</version>
  </parent>

  <artifactId>chap06</artifactId>

  <packaging>jar</packaging><!-- 패키징 타입 추가 -->

  <dependencies>
    <dependency>
      <groupId>com.fasterxml.jackson.dataformat</groupId>
      <artifactId>jackson-dataformat-xml</artifactId>
    </dependency>
  </dependencies>

  <!-- 이 플러그인은 메이븐의 패키지 단계에서 실행되며, 컴파일 후 표준에 맞는 디렉터리 구조로 변경하여 JAR 패키지 파일을 생성함 -->
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

---

# 1. REST-API 와 국제화 메시지 처리

웹 서버에 전달되는 사용자 언어는 크게 두 가지 행위로 설정 가능하다.
- 사용자가 직접 언어를 선택하여 웹 서비스에 요청
- 브라우저가 전송하는 `Accept-Language` 헤더 값을 서버가 인지하여 국제화 기능 제공
  - 사용자 OS 나 브라우저 설정에 따라 사용자가 사용하는 언어 정보가 해당 헤더 값으로 설정되고, 서버 요청 메시지에 자동으로 퍼함됨

웹 애플리케이션과 달리 REST-API 는 HTML 대신 JSON 메시지를 사용하기 때문에 상대적으로 국제화 기능을 적용할 수 있는 영역이 적다.  

만일 REST-API 가 200 OK 가 아닌 에러 코드를 응답하는 경우 응답 메시지에 경고 문구를 국제화할 수 있다.

클라이언트는 국제화가 적용된 에러 문구를 서버에서 받아 그대로 사용자에게 노출해도 되고, 클라이언트에서 직접 국제화 기능을 제공해도 된다.

---

## 1.1. message.properties 파일 설정

메시지 프로퍼티 파일명은 반드시 언어 코드를 포함해야 하며, 국가 코드까지 포함해도 된다.    

> {basename}_{언어코드}_{국가코드}.properties 혹은 {basename}_{언어코드}.properties 

스프링 프레임워크 기본 설정으로 basename 은 `message` 이다.  
언어 코드와 국가 코드는 Locale 클래스의 language 과 region 값을 사용한다.

메시지 프로퍼티 파일의 위치는 클래스 패스에 있어야 하며, 스프링 프로젝트 resources 폴더 하위에 생성한다.

프로퍼티 파일 내에서 파라메터는 `{}` 로 그 위치를 정의할 수 있으며, 배열의 인덱스 숫자와 함께 설정한다.

```properties
# messages_en.properties
main.cart.title=Cart
main.cart.tooltip={0} items in the Cart.

# messages_ko.properties
main.cart.title=장바구니
main.cart.tooltip=장바구니에 {0}개 상품이 담겨있습니다.
```

---

## 1.2. MessageSource 인터페이스

스프링 프레임워크는 메시지 프로퍼티 파일의 메시지 프로퍼티들을 사용할 수 있는 o.s.context.MessageSource 인터페이스를 제공한다.

MessageSource 인터페이스는 `getMessage()` 메서드만 제공하며, 인자에 따른 세 가지 메서드가 오버로딩되어 있다.

MessageSource 인터페이스
```java
public interface MessageSource {
  @Nullable
  String getMessage(String code, @Nullable Object[] args, @Nullable String defaultMessage, Locale locale);

  String getMessage(String code, @Nullable Object[] args, Locale locale) throws NoSuchMessageException;

  String getMessage(MessageSourceResolvable resolvable, Locale locale) throws NoSuchMessageException;
}
```

- 첫 번째 메서드
  - code: 프로퍼티 파일에서 관리하고 있는 메시지와 매핑할 수 있는 고유 키. 예) main.cart.title
  - args: 메시지에 포함된 파라메터 배열 순서대로 교체할 값
  - defaultMessage: args 에서 인자를 교체할 때 code 인자와 매핑되는 메시지 프로퍼티가 없으면 인자로 넘긴 defaultMessage 리턴
  - locale: 사용자 언어, Locale 의 언어 코드와 매핑되는 메시지 프로퍼티 파일에서 프로퍼티 값 리턴
- 두 번째 메서드
  - 첫 번째 메서드에서 defaultMessage 가 빠짐
  - 그래서 code 와 매핑되는 메시지 프로퍼티 값이 없으면 NoSuchMessageException 예외 발생
- 세 번째 메서드
  - 두 번째 메서드에서 args 인자가 빠짐
  - 그래서 프로퍼티 값을 교체할 수 없음

스프링 부트 자동 설정 클래스로 생성되는 MessageSource 스프링 빈의 이름은 `messageSource` 이고, 사용법은 아래와 같다.
```java
String[] args = {"10"};
Locale locale = Locale.KOREA;
String message = messageSource.getMessage("main.cart.tooltip", args, locale);
```

---

## 1.3. 스프링 부트 프레임워크의 자동 설정 구성

스프링 프레임워크에서 MessageSource 구현체로는 아래 두 가지가 있다.  
두 구현제 모두 리소스(=메시지 프로퍼티 파일) 를 사용하여 메시지 프로퍼티들을 관리하지만, `ReloadableResourceBundleMessageSource` 은 주기적으로 리소스를
재로딩한다는 차이점이 있다.

- `ResourceBundleMessageSource`
- `ReloadableResourceBundleMessageSource`
  - 프로퍼티 파일을 수정하면 애플리케이션을 주기적으로 로딩하므로 애플리케이션을 재기동하지 않고도 메시지 변경 가능
  - 단, 프로퍼티 파일을 스프링 프로젝트 내부에 생성 후 패키징하면 jar 파일에 포함되므로 -jar 옵션을 사용하여 애플리케이션 실행하면 
  런타임 도중에 프로퍼티 파일 수정이 불가함.
  - 따라서 jar 파일 외부에서 프로퍼티 파일을 주입해서 리로드 기능이 실질적으로 동작함
 
스프링 부트 프레임워크는 MessageSource 를 자동 설정해주는 `MessageSourceAutoConfiguration` 을 제공하기 때문에 개발자가 스프링 빈의 타입이 MessageSource 이고,
이름이 `messageSource` 인 스프링 빈을 직접 생성하지 않으면 `MessageSourceAutoConfiguration` 이 동작하여 자동으로 설정된다.  
이 때 자동 설정되는 MessageSource 의 구현체는 `ResourceBundleMessageSource` 이다.

`MessageSourceAutoConfiguration` 자동 설정 클래스에서 제공하는 MessageSource 를 설정하려면 아래 속성을 application.properties 에 정의한다.

application.properties
```properties
## MessageSource Configuration
# MessageSource 객체가 로딩하는 메시지 프로퍼티 파일의 기본 이름과 경로
# messages_ko.properties 프로퍼티 파일의 기본 이름(basename) 인 message 를 messages 로 변경한 예시임
spring.messages.basename=messages/messages

# MessageFormat 방식의 메시지 치환 방식 적용 여부
spring.messages.always-use-message-format=false

# 프로퍼티 파일의 메시지들을 캐싱하는 주기, 설정하지 않으면 애플리케이션을 실행하면서 캐싱한 메시지들이 계속해서 사용됨 (디폴트 null)
spring.messages.cache-duration=

# 프로퍼티 파일의 인코딩
spring.messages.encoding=UTF-8

# 입력한 Locale 언어 코드를 지원하지 않을 때 시스템의 Locale 을 사용할지 여부 (디폴트 true, true 이면 시스템 Locale 사용함)
spring.messages.fallback-to-system-locale=true

# 입력된 키와 매칭되는 메시지가 없을 경우 NoSuchMessageException 예외 발생시킬지 여부 (디폴트 false)
spring.messages.use-code-as-default-message=false
```

- `spring.messages.basename=messages/messages`
  - MessageSource 객체가 로딩하는 메시지 프로퍼티 파일의 기본 이름과 경로
  - 위 예시는 resources 경로 하위에 messages 폴터 생성 후 프로퍼티명을 basename 이 messages 로 시작하도록 (messages_ko.properties) 설정하는 예시임
  - 두 개 이상의 디렉터리에서 프로파일 관리 시 콤마(`,`) 로 구분
  - 예를 들어 messages 와 errors 디렉터리에서 프로퍼티 파일 관리 시 `spring.messages.basename=messages/messages, errors/error-messages` 로 설정 
- `spring.messages.always-use-message-format=false`
  - MessageFormat 방식의 메시지 치환 방식 적용 여부
- `spring.messages.cache-duration=`
  - 프로퍼티 파일의 메시지들을 캐싱하는 주기
  - 설정하지 않으면 애플리케이션을 실행하면서 캐싱한 메시지들이 계속해서 사용됨 (디폴트 null)
  - 시간 단위를 의미하는 문자열과 시간 값을 조합하여 응답함
  - 숫자만 입력하는 경우 초 단위를 기본으로 사용
  - 시간을 의미하는 문자열은 아래와 같음
    - `ns`: nanosecond
    - `us`: microsecond
    - `ms`: millisecond
    - `s`: second
    - `m`: minute
    - `h`: hour
    - `d`: day
- `spring.messages.encoding=UTF-8`
  - 프로퍼티 파일의 인코딩
- `spring.messages.fallback-to-system-locale=true`
  - 입력한 Locale 언어 코드를 지원하지 않을 때 시스템의 Locale 을 사용할지 여부 (디폴트 true)
  - true 이면 시스템 Locale 을 사용하고, false 면 message.properties 프로퍼티 파일의 메시지 사용
  - 따라서 false 로 사용하려면 message.properties 파일을 만들어야 함
- `spring.messages.use-code-as-default-message=false`
  - 입력된 키와 매칭되는 메시지가 없을 경우 NoSuchMessageException 예외 발생시킬지 여부 (디폴트 false)
  - true 이면 예외없이 리턴값으로 입력한 키를 그대로 전달, false 이면 NoSuchMessageException 예외 발생
  - 디버깅하는 것이 아니라면 false 권장

---

## 1.4. `LocaleResolver` 와 `LocaleChangeInterceptor` 설정

이제 사용자의 요청 메시지에서 언어 정보를 추출하여 Locale 객체로 변경하는 과정과 사용법에 대해 알아본다.

MessageSource 의  `getMessage()` 메서드는 언어와 국가 정보를 포함하는 Locale 객체를 인자로 받아서 적절한 프로퍼티 파일의 메시지를 응답한다.

사용자 요청 메시지에서 언어 정보를 추출하기 위해 `LocaleResolver` 와 `LocaleChangeInterceptor` 를 설정한다.



> `LocaleResolver` 의 추가 내용은 [Spring Boot - 웹 애플리케이션 구축 (1): WebMvcConfigurer 를 이용한 설정, DispatcherServlet 설정](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#13-dispatcherservlet-설정)
> 을 참고하세요.


아래는 `LocaleResolver` 와 [`addInterceptors()`](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#125-addinterceptors) 를 이용하여 `LocaleChangeInterceptor` 를 설정하는 예시이다.

```java
import org.springframework.web.servlet.LocaleResolver;
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver;
import org.springframework.web.servlet.i18n.LocaleChangeInterceptor;

@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Bean(value = "localeResolver")
  public LocaleResolver localeResolver() {
    AcceptHeaderLocaleResolver acceptHeaderLocaleResolver = new AcceptHeaderLocaleResolver();
    // Locale 객체를 생성할 수 없을 때 기본 Locale 객체 설정
    // Accept-Language 헤더가 없거나 알 수 없는 헤더값이 전달되면 Locale 객체는 KOREAN 으로 설정됨
    acceptHeaderLocaleResolver.setDefaultLocale(Locale.KOREAN);
    return acceptHeaderLocaleResolver;
  }

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    // 클라이언트가 웹 서버에 리소스를 요청할 때 Accept-Language 헤더가 아닌 파라메터로 Locale 값을 변경하고 싶을 때 LocaleChangeInterceptor 사용
    LocaleChangeInterceptor localeChangeInterceptor = new LocaleChangeInterceptor();

    // locale 파라메터값을 Locale 객체로 변경
    // GET /hotels?locale=ko 로 요청 시 Locale 객체를 생성
    localeChangeInterceptor.setParamName("locale");
    System.out.println("--- Interceptor addInterceptors()");
    // 인터셉터 추가
    registry.addInterceptor(localeChangeInterceptor)
        // 인터셉터 기능을 제외한 URI 패턴 입력
        .excludePathPatterns("favicon.ico")
        // 인터셉터가 동작할 경로
        .addPathPatterns("/**");
  }
}
```

스프링 웹 프레임워크는 `AcceptHeaderLocaleResolver` 와 `LocaleChangeInterceptor` 를 통해 Locale 정보를 추출할 수 있다.

`Accept-Language` 헤더값을 파싱하여 Locale 객체 생성 시엔 `AcceptHeaderLocaleResolver` 를 구현한 `LocaleResolver` 스프링 빈이 사용되고,
사용자의 요청에 의한 Locale 객체 생성 시엔 `LocaleChangeInterceptor` 가 사용된다.

위 예시에서 사용한 LocaleResolver 인터페이스의 구현체 중 하나인 `AcceptHeaderLocaleResolver` 는   
`AcceptHeaderLocaleResolver` 는 HTTP 요청 메시지의 `Accept-Language` 헤더값을 파싱하여 Locale 객체로 변경한다.  

DispatcherServlet 은 `LocaleResolver` 가 추출한 Locale 객체를 LocaleContextHolder 의 `setLocaleContext()` 를 사용하여 ThreadLocal 변수에 저장한다.  
파싱된 Locale 객체를 직접 참조하려면 o.s.context.i18n.LocaleContextHolder 클래스의 `getLocale()` 메서드를 사용하면 된다.  
`LocaleContextHolder` 내부 ThreadLocal 변수에 Locale 값을 저장하고 있기 때문에 서블릿 기반의 스프링 웹 애플리케이션에서는 어디에서든지 사용 가능하다.

즉, 스프링 웹 프레임워크가 추출한 **Locale 을 ThreadLocal 변수에 저장하기 때문에 개발자는 `LocalContextHolder` 의 `getLocale()` 메서드를 사용하여 프로그램 어디에서든지 
ThreadLocal 에 저장된 Locale 를 참조**할 수 있다.

> **ThreadLocal 에 저장된 값은 같은 스레드에 저장되므로 같은 스레드 안에서만 참조가 가능**하다.  
> 따라서 비동기 프로그래밍응ㄹ 하거나 별도의 스레드로 작업을 실행하면 ThreadLocal 값을 참조할 수 없다.

---

아래는 에러 메시지에 국제화 기능을 적용한 예시이다.  

`@RestApiControoler` 가 선언된 ErrorController 에서 발생한 에러는 `@RestControllerAdvice` 가 선언된 클래스인 ApiExceptionHandler 클래스의 
`@ExceptionHandler` 가 적용된 메서드에서 처리한다.

`@RestApiControoler` 애너테이션이 적용되어 있기 때문에 ApiExceptionHandler 클래스에서 직접 REST-API 로 응답이 가능하다.

/controller/ErrorController.java
```java
import com.assu.study.chap06.domain.BadRequestException;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Locale;

@RestController
public class ErrorController {
  private final MessageSource messageSource;

  public ErrorController(MessageSource messageSource) {
    this.messageSource = messageSource;
  }

  @GetMapping("/error")
  public void createError() {
    Locale locale = LocaleContextHolder.getLocale();
    String[] args = {"10"};
    String errorMessage = messageSource.getMessage("main.cart.tooltip", args, locale);
    BadRequestException badRequestException = new BadRequestException(errorMessage);

    throw badRequestException;
  }
}
```

/controller/ApiExceptionHandler.java
```java
import com.assu.study.chap06.domain.BadRequestException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

  @ExceptionHandler(BadRequestException.class)
  public ResponseEntity<ErrorResponse> handleBadRequestException(BadRequestException ex) {
    System.out.println("Error Message: " + ex.getErrorMessage());

    return new ResponseEntity<>(
        new ErrorResponse(ex.getErrorMessage()),
        HttpStatus.BAD_REQUEST
    );
  }
}
```

/controller/ErrorResponse.java
```java
import lombok.Getter;
import lombok.ToString;

@Getter
@ToString
public class ErrorResponse {
  private final String errorMessage;

  public ErrorResponse(String errorMessage) {
    this.errorMessage = errorMessage;
  }
}
```


BadRequestException.java
```java
package com.assu.study.chap06.domain;

public class BadRequestException extends RuntimeException {
  private final String errorMessage;

  public BadRequestException(String errorMessage) {
    //super();
    this.errorMessage = errorMessage;
  }

  public String getErrorMessage() {
    return errorMessage;
  }
}
```


```shell
curl --location 'http://localhost:18080/error' | jq

{
  "errorMessage": "장바구니에 10개 상품이 담겨있습니다."
}
```

```shell
curl --location 'http://localhost:18080/error' \
--header 'Accept-Language: en' | jq
```

---

```shell
curl --location 'http://localhost:18080/error?locale=en' | jq

{
  "errorMessage": "10 items in the Cart."
}
```

이렇게 파라메터로 Locale 설정 시 아래와 같은 에러가 난다.

```shell
Cannot change HTTP Accept-Language header - use a different locale resolution strategy
```

아래처럼 SessionLocaleResolver 를 설정해준다.

/config/WebConfig.java
```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  //@Bean(value = "localeResolver")
//  public LocaleResolver localeResolver() {
//    AcceptHeaderLocaleResolver acceptHeaderLocaleResolver = new AcceptHeaderLocaleResolver();
//    // Locale 객체를 생성할 수 없을 때 기본 Locale 객체 설정
//    // Accept-Language 헤더가 없거나 알 수 없는 헤더값이 전달되면 Locale 객체는 KOREAN 으로 설정됨
//    acceptHeaderLocaleResolver.setDefaultLocale(Locale.KOREAN);
//    return acceptHeaderLocaleResolver;
//  }

  // 헤더의 Accept-Language 가 아닌 파라메터로 Locale 값 변경 시 사용
  @Bean(value = "localeResolver")
  public LocaleResolver localeResolver() {
    SessionLocaleResolver sessionLocaleResolver = new SessionLocaleResolver();
    sessionLocaleResolver.setDefaultLocale(Locale.KOREA);

    return sessionLocaleResolver;
  }
}
```

```shell
curl --location 'http://localhost:18080/error?locale=en' | jq

{
  "errorMessage": "10 items in the Cart."
}
```

---

# 2. 로그 설정

`System.out.println()` 메서드는 표준 출력 스트림을 사용하여 화면에 로그를 출력하였다.  
하지만 스트림은 휘발성 이기 때문에 시간이 지나면 다시 확인할 수 없다.  

Java 에서 많이 사용하는 방식은 Slf4J 라이브러리에 로깅 프레임워크를 뭋여서 로깅 방식을 구성하는 것이다.  

> **Slf4J (Simple Logging Facade For Java)**    
> 다양한 로깅 프레임워크를 덧붙여 사용할 수 있는 추상화된 로그 레벨 라이브러리

Slf4J 가 Java 의 인터페이스 역할을 한다면 로깅 프레임워크는 인터페이스를 구현한 구현 클래스 역할을 한다.  

대표적인 로깅 프레임워크는 logback, log4j, log4j2 등이 있다.  
해당 포스트에서는 Slf4J 와 logback 를 사용할 예정이다.

스프링 부트 프레임워크는 추가적인 의존성 설정 없이 기본으로 Slf4J 와 logback 을 지원한다.  
spring-boot-starter 는 spring-boot-starter-logging 을 포함하고 있기 때문에 스프링 부트 스타터를 사용한다면 
추가적인 의존성 없이 바로 사용 가능하다.

> 힙 덤프와 스레드 덤프를 생성하여 로그를 분석할 수도 있지만 이 방법들은 서비스 중인 애플리케이션에 큰 부하를 주기 때문에 
> 애플리케이션에 장애가 있거나 심각한 에러가 발생한 상태에서만 사용 권장

---

## 2.1. Logger 선언

Logger 객체는 org.slf4j.LoggerFactory 의 `getLogger()` static 메서드를 이용하여 만들수도 있지만 
클래스 선언부에 Lombok 의 `@Slf4J` 애너테이션을 사용하여 손쉽게 Logger 객체를 생성할 수도 있다.  
그러면 Java Annotation Preprocessor 가 컴파일 과정에서 Logger 객체를 만들여, 그 객체명은 `log` 가 된다.  
따라서 묵시적으로 log 변수를 사용하여 로그를 남기면 된다.

명시적으로 Logger 객체 생성
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LoggerTest {
  private static final Logger logger = LoggerFactory.getLogger(LoggerTest.class);
}
```

`@Slf4J` 애너테이션으로 Logger 객체 생성
```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
public class LoggerTest {
  ...  
}
```

Slf4J Logger 의 로그 레벨은 5가지로 나뉜다.
- trace 
- debug
- info
- warn
- error


```java
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDate;
import java.util.Locale;

@Slf4j
@RestController
public class ErrorController {
  private final MessageSource messageSource;

  public ErrorController(MessageSource messageSource) {
    this.messageSource = messageSource;
  }

  @GetMapping("/error")
  public void createError() {
    BadRequestException badRequestException = new BadRequestException(errorMessage);

    LocalDate errorDate = LocalDate.now();
    log.trace("trace log, {}", errorDate);
    log.debug("debug log, {}", errorDate);
    log.info("info log, {}", errorDate);
    log.warn("warn log, {}", errorDate);
    log.error("error log, {}, {}", errorDate, "errorMessage 입니다.", badRequestException);

    throw badRequestException;
  }
}
```

```shell
curl --location 'http://localhost:18080/error' | jq

{
  "errorMessage": "장바구니에 10 개가 담김."
}
```

log.error() 의 마지막 인자인 badRequestException 은 예외 객체로, 예외 객체를 인자로 넣으면 스택 트레이스 정보가 로그에 남는다.

```shell
2023-09-28T19:48:52.548+09:00  INFO 35738 --- [io-18080-exec-1] c.a.s.chap06.controller.ErrorController  : info log, 2023-09-28
2023-09-28T19:48:52.549+09:00  WARN 35738 --- [io-18080-exec-1] c.a.s.chap06.controller.ErrorController  : warn log, 2023-09-28
2023-09-28T19:48:52.550+09:00 ERROR 35738 --- [io-18080-exec-1] c.a.s.chap06.controller.ErrorController  : error log, 2023-09-28, errorMessage 입니다.

com.assu.study.chap06.domain.BadRequestException: null
	at com.assu.study.chap06.controller.ErrorController.createError(ErrorController.java:27) ~[classes/:na]
```

---

이제 Slf4J 구현 로그 프레임워크인 Logback 을 스프링 부트 프레임워크에서 제공하는 방법으로 설정해본다.

Logback 프레임워크에서 제공하는 설정 포맷과 방법도 있지만 스프링 부트는 여기에 프로파일 기능을 추가로 사용할 수 있는 방법을 제공한다.

스프링 부트 프레임워크에서 Logback 로깅 프레임워크를 설정하는 방법은 크게 2가지가 있다.

- application.properties 파일에 로깅 관련 설정
- 최상위 루트 클래스 패스에 로깅 설정 파일을 별도로 선언하여 로깅 프레임워크를 상세하게 설정

여기선 두 번째 방식으로 로거를 설정한다.

Logback 프레임워크는 RollingPolicy 인터페이스와 구현체들을 제공한다.

스프링 푸트 프레임워크의 기본 설정으로는 ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy 클래스를 롤링 정책으로 사용하며,  
롤링 정책을 따로 설정하지 않아도 스프링 부트의 기본 설정에 따라 날짜를 기반으로 로그 파일을 롤링한다.

예를 들어 오늘 생성된 로그는 system.log 에 저장되지만 자정이 지나면 system.log 파일은 system.2023-08-19.log 파일로 변경되고 새로운 system.log 파일에 로그가 저장된다.  
또한 로그 파일의 최대 크기를 100M 로 설정했을 경우 해당 크기가 초과하면 로그 파일명에 인덱스를 붙여서 저장한다.  
예를 들어 system.log 파일은 system1.log 로 이름이 변경되고 다시 크기가 0 인 system.log 파일에 새로운 로그가 저장된다.

---

## 2.2. logback-spring.xml

Logback 로깅 프레임워크는 클래스 패스에 있는 logback.xml 파일을 로딩하고 설정하는데 스프링 부트 프레임워크는 logback-spring.xml 파일을 로딩하고 로깅 프레임워크를 설정하는 방법을 제공한다.

따라서 스프링 부트 프레임워크를 사용하여 Logback 을 설정할 경우엔 두 가지 중 하나로 설정하면 되며, 두 설정 파일을 방법이 거의 유사하다.  
단, 앞에서 말한 것처럼 logback-spring.xml 은 스프링 부트 프레임워크에서 제공하는 Profile 기능을 추가로 제공하므로 logback-spring.xml 을 권장한다.

/resources/logback-spring.xml
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<configuration>

    <!-- logger 설정, org.springframework.beans.factory 패키지에 포함되는 클래스에서 발생하는 모든 로그 메시지 중 warn 레벨 이상만 로깅 -->
    <logger name="org.springframework.beans.factory" level="warn"/>

    <springProfile name="local">
        <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>[%d{yyyy/MM/dd HH:mm:ss.SSS}] %magenta([%thread]) %highlight(%-5level) %logger{36} - %msg%n
                </pattern>
            </encoder>
        </appender>

        <!-- root 설정으로 애플리케이션에서 발생하는 모든 로그 중 trace 레벨 이상한 로깅 -->
        <!-- 하위에 포함된 appender-ref 설정으로 모든 로그 메시지는 STDOUT 으로 전달되며 그 결과가 콘솔에 출력됨 -->
        <root level="info">
            <appender-ref ref="STDOUT"/>
        </root>
    </springProfile>

    <springProfile name="dev">
        <appender name="systemLogAppender" class="ch.qos.logback.core.rolling.RollingFileAppender">
            <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
                <fileNamePattern>${LOG_PATH}/system-%d{yyyy-MM-dd}.%i.log</fileNamePattern>
                <timeBasedFileNamingAndTriggeringPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedFNATP">
                    <maxFileSize>100MB</maxFileSize><!-- 로그 파일 크기가 100M 가 넘어가면 로그 파일 분리 -->
                </timeBasedFileNamingAndTriggeringPolicy>
                <maxHistory>30</maxHistory><!-- 최대 30일 동안 로그 유지 -->
            </rollingPolicy>
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>

        <root level="info">
            <appender-ref ref="systemLogAppender"/>
        </root>
    </springProfile>

    <springProfile name="production">
        <appender name="systemLogAppender" class="ch.qos.logback.core.rolling.RollingFileAppender">
            <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
                <fileNamePattern>${LOG_PATH}/system-%d{yyyy-MM-dd}.%i.log</fileNamePattern>
                <timeBasedFileNamingAndTriggeringPolicy
                        class="ch.qos.logback.core.rolling.SizeAndTimeBasedFNATP">
                    <maxFileSize>100MB</maxFileSize>
                </timeBasedFileNamingAndTriggeringPolicy>
                <maxHistory>30</maxHistory>
            </rollingPolicy>
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>

        <root level="warn">
            <appender-ref ref="systemLogAppender"/>
        </root>
    </springProfile>

</configuration>
```

logback-spring.xml 은 크게 4가지 설정으로 구분할 수 있다.  
logger, appender, root 는 Logback 의 설정이고, 스프링 부트의 프로파일 설정을 하려면 springProfile 을 이용하면 된다.

- `logger`
  - 로그의 레벨과 로그가 발생한 클래스, 로그 메시지를 포함하는 컨텍스트
- `appender`
  - 로그 메시지를 어떤 패턴으로 어디에 출력할 지 설정
  - 출력 대상은 콘솔, 파일, 원격 서버에 있는 로그 저장소 등이 될 수 있음
  - 클라우드 환경에서 서버는 scale-out 이 될 수 있으므로 원격 저장소에 네트워크를 통해 로그를 전달함
  - 파일에 출력설정을 한 appender 와  원격 서버에 출력 설정을 한 appender 를 하나의 logger 에 설정하면 분산 서버 환경에서 발생한 모든 로그를 쉽게 수집 가능
- `root`
  - 최상위 로그 설정
  - logger 는 특정 로그 컨텍스트에 대한 설정인 반면, root 는 애플리케이션에서 발생하는 전체 로그 컨텍스트에 대한 설정임
- `springProfile`

---

`springProfile` 에 OR(`|`), NOT(`!`) 을 사용하면 좀 더 간단히 설정할 수 있다.  
예를 들어 `local | dev` 라고 설정하면 Local 과 Dev 환경에서 설정이 동작하고, `!local` 이라고 설정하면 Local 을 제외한 모든 환경에서 설정이 동작한다.

root 와 roller 설정이 같이 사용되면 logger 설정이 더 우선권을 갖는다.  

따라서 아래 xml 에서 logger 설정이 우선권이 있으므로 o.s.beans.factory 패키지에서 발생하는 로그 메시지 중 warn 레벨 이상만 로깅이 되고,  
o.s.beans.factory 패키지 외에서 발생하는 로그 메시지들은 root 설증을 따라서 info 레벨 이상만 로깅이 된다.
```xml
    <logger name="org.springframework.beans.factory" level="warn"/>

    <springProfile name="local">
        ...

        <!-- root 설정으로 애플리케이션에서 발생하는 모든 로그 중 trace 레벨 이상한 로깅 -->
        <!-- 하위에 포함된 appender-ref 설정으로 모든 로그 메시지는 STDOUT 으로 전달되며 그 결과가 콘솔에 출력됨 -->
        <root level="info">
            <appender-ref ref="STDOUT"/>
        </root>
    </springProfile>
```

로그 저장 경로는 실행 환경에 따라 다르므로 application.properties 파일에 `logging.file.path` 로 지정한 후 logback-spring.xml 에서는 `${LOG_PATH}` 로 설정한다.


---

appender 의 로그 메시지 패턴에서 사용할 수 있는 키워드는 아래와 같다.
- `%logger{length}`
  - Logger 이름 출력
  - length 길이에 맞추어 이름을 줄임
- `%-5level`
  - 로그 레벨을 출력하고 다섯 글자로 고정하여 출력
- `%msg`
  - 로그 메시지 출력
- `%d{HH:mm:ss.SSS}`
  - 로그가 발생한 시점의 시간 출력
- `%M`
  - 로그가 발생한 메서드명 출력
- `%thread`
  - 로그가 발생한 스레드명 출력
- `%C`
  - 로그가 발생한 클래스명 출력
- `%n`
  - 줄바꿈

---

애플리케이션을 운영할 때는 반드시 웹 서버의 access 로그와 애플리케이션 로그를 같이 남긴다.

- access 로그
  - 사용자가 서버에 요청한 모든 기록 저장
  - 요청 시간, 리소스와 서버가 응답한 HTTP 상태 코드 등을 한번에 확인
- 애플리케이션 로그
  - 사용자 요청을 처리하는 과정 중 디버깅을 위한 로깅

---

## 2.3. 중앙 수집 로그

각 서버 애플리케이션에서 생성된 로그는 로그 운반 프로그램이나 카프카 같은 대용량 큐를 사용하여 로그 저장소로 운반할 수 있다.  
대표적인 로그 운반툴로는 FileBeat 나 Fluentd 가 있다.  
이 툴들은 애플리케이션에서 생성한 로그 파일을 읽어서 로그 저장소로 전달하는 역할을 한다.

FileBeat 는 LogStash 와 통합하여 로그를 다시 한 번 정제할 수 있으며, 엘라스틱 서치 검색 엔젠에 저장한 후 Kibana 에서 검색하도록 되어있다.  
이러한 아키텍처를 ELK 스택이라고 한다.

---

# 3. 애플리케이션 패키징과 실행

코드를 컴파일하여 생성된 클래스 파일들을 J2EE 표준에 맞게 하나의 파일로 묶는 과정을 패키징 이라고 한다. 이 때 파일의 확장자는 war 혹은 jar 이다.  
그리고 패키징 과정에서 클래스 파일들을 압축하지 않고 하나의 파일로 묶는 것을 아카이빙 이라고 한다.

J2EE 표준에 맞는 디렉터리 구조로 컴파일된 파일을 이동하여 아카이빙한 파일을 패키지 파일이라고 한다.

패키징하는 방법에 따라 war, jar 패키지 파일로 만들 수 있으며, 두 패키지 파일을 애플리케이션을 실행하는 방식이 다르므로 패키징하는 방법도 다르다.

애플리케이션을 실행하는 방식에 따라 패키징 방식을 정하면 되는데 웹 애플리케이션을 실행하는 방식은 크게 2 가지로 나뉠 수 있다.

- 톰캣 같은 웹 애플리케이션 서버가 WAR 패키지 파일을 로딩하여 웹 애플리케이션을 실행
- java 명령어를 사용하여 JAR 패키지 파일을 직접 실행

WAR 패키지 파일을 이용하여 배포하는 방식은 MSA 환경에 적합하지 않다.  
WAR 패키지 파일을 이용하려면 서버에 JRE 와 톰캣 서버가 설치되어 있어야 하지만 JAR 패키지 파일을 이용한 배포 방식은 서버에 JRE 만 설치되어 있으면 되기 때문이다.
(= JAR 파일을 이용하면 톰캣을 서버에 미리 설치/설정할 필요 없음)

JAR 패키지 파일은 WAS 없이는 웹 애플리케이션을 실행할 수 없다. 따라서 웹 애플리케이션을 JAR 패키지 파일로 실행하려면 JAR 파일 내부에 WAS 를 포함하고 있어야 한다.  
이 때 패키지에 포함된 WAS 를 임베디드 WAS 라고 하며, 스프링 부트 프레임워크는 기본 설정으로 임베디드 톰캣을 사용하고 있다.  
(그래서 스프링 부트 프레임워크를 사용하여 개발된 JAR 패키지 파일은 WAS 를 포함하고 있기 때문에 패키지 파일 용량이 WAR 파일보다 조금 더 큼)

---

MSA 컴포넌트들은 쉽게 확장할 수 있는 구조로 설계가 되어야 하는데 이 때 WAR 방식으로 배포 전략을 결정하는 것은 효율적이지 못하다.

서비스에 추가할 서버에는 OS, JRE, 톰캣이 설치되어 있어야 하는데 확장해야 할 컴포넌트마다 톰캣 버전이나 설치된 경로가 다르다면, 그리고 JRE 버전도 다르다면 수많은 
머신 이미지를 생성하고 관리해야 한다.

---

## 3.1. Maven 패키징

스프링 부트 프레임워크는 실행 가능한 JAR 를 만들 수 있는 빌드 플러그인을 제공한다.  
프레임워크에서 제공하는 플러그인은 Maven 과 Gradle 빌드툴에서 사용 가능하다.

여기선 Maven 과 스프링 부트 프레임워크에서 제공하는 플러그인을 사용하여 실행 가능한 JAR 패키지 파일을 만드는 방법에 대해 알아본다.

Maven 은 애플리케이션의 lifecycle 을 관리할 수 있는 툴이다.  
컴파일부터 넥서스 저장소까지 배포할 수 있는 애플리케이션의 생명주기를 관리할 수 있는 빌드툴이다.

그래서 컴파일된 파일을 클린, 컴파일, 테스트, 패키징, 검증, 인스톨, 디플로이하는 여러 단계로 애플리케이션을 관리할 수 있다.

JAR 패키지 파일을 만드는 과정은 클린, 컴파일, (테스트), 패키징 과정까지만 실행하면 된다.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.assu</groupId>
        <artifactId>study</artifactId>
        <version>1.1.0</version>
    </parent>

    <artifactId>chap06</artifactId>

    <packaging>jar</packaging><!-- 패키징 타입 추가 -->

    <dependencies>
        <dependency>
            <groupId>com.fasterxml.jackson.dataformat</groupId>
            <artifactId>jackson-dataformat-xml</artifactId>
        </dependency>
    </dependencies>

  <!-- 이 플러그인은 메이븐의 패키지 단계에서 실행되며, 컴파일 후 표준에 맞는 디렉터리 구조로 변경하여 JAR 패키지 파일을 생성함 -->
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

`-jar` 옵션으로 JAR 패키지 파일을 실행하면 `public static void main()` 메서드가 실행되어야 하는데 해당 애플리케이션 시작점을 JAR 파일 내부의 META-INF/MANIFEST.MF 파일에 정의해야 한다.  
그래야 '-jar' 명령어가 JAR 파일에 포함된 어떤 클래스의 public static void main() 을 실행할 지 알 수 있다.

pom.xml 을 설정했으면 intelliJ 에서 제공하는 Maven 패널을 사용하여 패키징 단계를 실행한다.  
Maven 패널의 `package` 를 더블 클릭하면 target 폴더에 JAR 패키지 파일이 생성된다.

생성된 파일명은 chap06-1.1.0.jar 이며, pom.xml 에서 정의한 artifactId 와 modelVersion 값의 조합으로 구성된다.

```shell
nohup java -Xms1024m -Xmx1024m -XX:+UseG1GC -jar ./chap06-1.1.0.jar > server.out 2>&1 &
```

애플리케이션이 시작할 때 힙 메모리를 설정하는 `-Xms` 와 최대 힙 메모리를 설정하는 `-Xmx` 를 사용하여 해당 애플리케이션은 시작부터 종료까지 힙 메모리 크기를 1G 로 유지한다.  
`-XX:+UseG1GC` 옵션 설정으로 G1GC 를 사용하도록 하였다.  
nohup 과 마지막 & 옵션으로 애플리케이션을 실행한 유저가 리눅스에서 로그아웃해도 백그라운드에서 애플리케이션이 실행된다.

---

## 3.2. Docker 이미지 생성

스프링 부트 애플리케이션을 도커에서 실행할 수 있도록 이미지를 만들고 실행하는 방법에 대해 알아보자.

도커는 컨테이너 기반의 가상화 플랫폼이다.  
스프링 부트 애플리케이션을 실행하려면 OS 가 설치된 서버에 JRE 가 반드시 필요하고, 레디스 같은 애플리케이션도 설치 및 실행이 되어있어야 한다.  
이렇게 **애플리케이션을 실행하는데 필요한 설정과 환경, 배포 파일을 컨테이너에 담아 놓고 컨테이너 자체를 배포하는 방식을 제공하는 것이 바로 도커**이다.   
도커는 컨테이너 배포를 사용하기 때문에 쉽게 배포할 수 있고, scale-out 이 쉽다. JDK 나 별도의 라이브러리 설치없이 컨테이너만 실행하면 되기 때문이다.

**도커 이미지는 실행할 서버의 모든 상태를 저장**하고 있는 것을 말하며, **도커 이미지를 사용하여 도커를 실행하면 컨테이너**가 된다.

도커를 사용하여 애플리케이션을 배포하는 방법은 다양하지만 가장 기본적인 배포 방법은 도커 이미지를 생성한 후 이를 사용하여 도커 컨테이너를 실행하는 것이다.

dockerfile 은 도커 명령어의 집합으로 애플리케이션을 실행할 서버의 모든 정보가 코드로 정의되어 있어야 한다.  
예를 들면 스프링 부트 애플리케이션을 실행할 OS, 사용자 계정과 그룹, 홈 디렉터리가 생성되어야 하고, 애플리케이션을 실행하는 코드도 설정해야 한다.  
즉, **서버 설치부터 애플리케이션 실행까지 일련의 과정들이 dockerfile 에 설정**되어 있어야 하는데 이러한 과정을 미리 설정하여 기본 도커 이미지 파일을 생성하고, 
이를 기본 이미지 파일로 사용해도 된다.

아래는 **dockerfile 을 사용하여 도커 컨테이너를 실행하는 과정**이다.

- 도커 이미지를 만드는 도커 명령어들을 dockerfile 에 선언
- 빌드 서버에서 코드 베이스를 받아 컴파일한 후 JAR 파일을 만드는 패키징 과정을 실행
- dockerfile 을 사용하여 도커 이미지 생성
- 생성한 이미지를 도커 이미지 저장소에 복사
- 도커 이미지 저장소에서 실행할 도커 이미지 파일을 선택한 후 호스트 서버에 다운로드
- 도커 이미지를 사용하여 컨테이너를 호스트 서버에서 실행

코드 베이스를 컴파일하고 JAR 파일을 만드는 서버를 빌드 서버라 하고, 도커 컨테이너를 실행하는 서버를 호스트 서버라고 한다.

여기선 간단한 dockerfile 을 생성하여 확인해본다.

/dockerfile
```dockerfile
FROM eclipse-temurin:17
RUN mkdir -p /Developer/06_msa
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

ENTRYPOINT ["java", "-Dspring.profiles.active=local,email", "-jar", "/app.jar"]
```

- 도커 이미지 중 openjdk 17 버전이 설치된 도커 이미지를 사용하여, 이 도커 이미지를 기반으로 원하는 작업을 더 추가 가능
- 로그를 저장하는 폴더 생성
- JAR_FILE 변수를 선언하여 dockerfile 을 실행할 서버의 target 디렉터리에 있는 모든 jar 파일을 선언
- 위에서 선언한 파일을 도커 이미지 파일로 복사함, 복사된 파일명은 app.jar
- 복사한 app.jar 를 실행

도커 파일에서 사용할 수 있는 명령어는 아래와 같다.
- `FROM`
  - 생성할 도커 이미지의 기본 이미지 설정
  - 이 이미지 설정에 계속해서 서버를 설정함
- `LABEL`
  - 이미지에 메타데이터 설정
- `RUN`
  - 도커 컨테이너 내부에서 실행할 명령어 정의
- `COPY`
  - dockerfile 이 실행되는 호스트 서버의 파일을 도커 컨테이너로 복사
- `ARG`
  - dockerfile 의 변수 설정
- `ADD`
  - host 의 파일 및 디렉터리를 도커 컨테이너에 추가
  - `COPY` 와 다른 점은 복사 대상이 압축파일이면 압축이 해제되면서 복사된다는 점
- `VOLUME`
  - 도커 컨테이너에 연결할 host 디렉터리
- `EXPOSE`
  - 외부 노출 포트 설정
- `CMD`
  - 도커 컨테이너에서 실행할 명령어 정의
  - `RUN` 과 비슷하지만, RUN 은 여러 번 실행할 수 있는 반면, `CMD` 는 한번만 실행함
- `ENTRYPOINT`
  - 도커 컨테이너에서 실행할 프로세스 지정

아래 명령어를 dockerfile 이 있는 위치에서 실행하면 **dockerfile 을 사용하여 도커 이미지를 생성**한다.

/docker_build.sh
```shell
docker build --tag hotel-api:latest .
```

```shell
chmod +x docker_build.sh
chmod +x docker_start.sh
```

/docker_start.sh
```shell
./docker_build.sh
ERROR: Cannot connect to the Docker daemon at unix:///Users/juhyunlee/.rd/docker.sock. Is the docker daemon running?
```

이런 에러가 뜨면 [Rancher Desktop (Docker Desktop 유료화 대응)](https://assu10.github.io/dev/2022/02/02/rancher-desktop/) 을 참고하여 도커 데몬을
먼저 띄운다.

```shell
./docker_build.sh
[+] Building 3.2s (8/8) FINISHED                                                                                                                   
 => [internal] load build definition from Dockerfile                                                                                          0.0s
 => => transferring dockerfile: 225B                                                                                                          0.0s
 => [internal] load .dockerignore                                                                                                             0.0s
 => => transferring context: 2B                                                                                                               0.0s
 => [internal] load metadata for docker.io/library/eclipse-temurin:17                                                                         2.7s
 => [1/3] FROM docker.io/library/eclipse-temurin:17@sha256:e3af901d39eba099b41209fbcacd6cebcd6a1f9479df4051b21b0b99ec3f7446                   0.0s
 => CACHED [2/3] RUN mkdir -p /Developer/06_msa                                                                                               0.0s
 => [internal] load build context                                                                                                             0.3s
 => => transferring context: 20.84MB                                                                                                          0.3s
 => [3/3] COPY target/*.jar app.jar                                                                                                           0.1s
 => exporting to image                                                                                                                        0.1s
 => => exporting layers                                                                                                                       0.1s
 => => writing image sha256:668b7a212a97a6cfebf569316852d307fc804584b80d11531bc4b5bf50a96863                                                  0.0s
 => => naming to docker.io/library/hotel-api:latest   
```

```shell
 docker images                                  
REPOSITORY                         TAG                    IMAGE ID       CREATED              SIZE
hotel-api                          latest                 668b7a212a97   About a minute ago   428MB
```

이제 도커 이미지를 생성했으니 **도커 이미지를 실행**한다.
/src/docker_start.sh
```shell
docker run -d --rm -p 18080:18080 hotel-api:latest
```

도커 이미지를 사용하여 호스트 머신에서 도커 컨테이너를 실행하는 것이다.  
도커 컨테이너를 백그라운드로 실행(`-d`) 하고 종료하면 이미지를 삭제(`--rm`) 하고, 도커의 18080번 포트를 호스트 서버의 18080 포트와 연결한다.

```shell
docker ps -a  # 컨테이터 ID 확인

docker rm -f d7d0d335dab5 # 컨테이너 삭제
```

> 도커 명령어에 대한 좀 더 상세한 내용은 [Docker 관련 명령어들](https://assu10.github.io/dev/2023/08/20/docker-commands/) 를 참고하세요.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [Docker 관련 명령어들](https://assu10.github.io/dev/2023/08/20/docker-commands/)