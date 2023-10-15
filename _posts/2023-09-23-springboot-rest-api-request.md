---
layout: post
title:  "Spring Boot - REST-API 호출"
date:   2023-09-23
categories: dev
tags: springboot msa rest-api uri-components-builder rest-template simple-client-http-request-factory http-components-client-http-request-factory web-client keep-alive parameterized-type-reference client-http-request-interceptor response-error-handler
---

이 포스팅에서는 아래 내용에 대해 살펴본다.

- RestTemplate 클래스를 사용하여 REST-API 호출
- RestTemplate 의 구조와 사용 방법
- RestTemplate 를 사용하면서 발생할 수 있는 네트워크 예외 상황
- WebClient 를 사용하여 REST-API 호출

스프링 프레임워크는 REST-API 를 쉽게 호출할 수 있는 클래스들을 제공한다.  
대표적으로 RestTemplate 와 WebClient 가 있다.  

RestTemplate 는 스프링 3 부터 제공되고 있으며, 블로킹 동기식 방식을 사용하는 대표적인 REST-API 클라이언트이다.  
즉, 다른 서버에 REST-API 를 호출하고 결과를 받을 때까지 스레드는 블로킹 상태로 변경되어 대기하며, 결과를 받으면 다음 코드를 실행한다.

WebClient 는 스프링 5 부터 제공되고 있으며, 논블로킹 비동기 방식을 사용하는 대표적인 REST-API 클라이언트이다.  
WebClient 는 리액트 라이브러리를 사용하는 방법과 스프링 비동기 웹 프레임워크인 WebFlux 에 대한 설명이 필요하기 때문에 이 포스팅에서는 WebClient 를 
동기식으로 사용하는 방법을 간략히 설명한다.


> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap09) 에 있습니다.

---

**목차**

- [RestTemplate 클래스](#1-resttemplate-클래스)
  - [RestTemplate 구조](#11-resttemplate-구조)
    - [`HttpMessageConverter`](#111-httpmessageconverter)
    - [`ClientHttpRequestInterceptor`](#112-clienthttprequestinterceptor)
    - [`ResponseErrorHandler`](#113-responseerrorhandler)
  - [RestTemplate 스프링 빈 설정](#12-resttemplate-스프링-빈-설정)
    - [`ClientHttpRequestInterceptor` 구현](#121-clienthttprequestinterceptor-구현)
    - [`ResponseErrorHandler` 구현](#122-responseerrorhandler-구현)
  - [Connection Timeout 과 Read Timeout 설정](#13-connection-timeout-과-read-timeout-설정)
  - [RestTemplate 클래스](#14-resttemplate-클래스)
  - [RestTemplate 예시](#15-resttemplate-예시)
    - [`GET` 메서드 예시](#151-get-메서드-예시)
    - [`POST` 메서드 예시](#152-post-메서드-예시)
    - [`exchange()` 와 `ParameterizedTypeReference` 메서드 예시](#153-exchange-와-parameterizedtypereference-메서드-예시)
  - [`keep-alive` 와 `Connection-Pool` 설정](#16-keep-alive-와-connection-pool-설정)
    - [커넥션 풀 설정: `HttpComponentsClientHttpRequestFactory`](#161-커넥션-풀-설정-httpcomponentsclienthttprequestfactory)
    - [`keep-alive` 설정](#162-keep-alive-설정)
    - [`keep-alive` 사용 시 주의점](#163-keep-alive-사용-시-주의점)
- [`WebClient`](#2-webclient)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.4
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap09

![Spring Initializer](/assets/img/dev/2023/0923/init.png)

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

  <artifactId>chap09</artifactId>

  <dependencies>
    <!-- HttpComponentsClientHttpRequestFactory (REST-API 커넥션 풀) -->
    <dependency>
      <groupId>org.apache.httpcomponents.client5</groupId>
      <artifactId>httpclient5</artifactId>
      <version>5.2.1</version>
    </dependency>

    <!-- WebClient 를 사용하기 위함 -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>

  </dependencies>
</project>
```

---

# 1. RestTemplate 클래스

**o.s.web.client.RestTemplate 클래스는 다른 서버의 REST-API 를 실행할 수 있는 메서드를 제공**한다.  

<**RestTemplate 특징**>  
- **자바 객체를 HTTP 요청 메시지 바디로 변환하고, HTTP 응답 메시지 바디를 자바 객체로 변환하는 기능 제공**
  - 이 때 메시지 Content-type 에 따라 적절한 컨버터를 찾아서 동작
  - RestTemplate 는 이 컨버터를 쉽게 확장할 수 있는 구조이기 때문에 JSON 뿐 아니라 XML 같은 메시지를 자바 객체로 쉽게 변환 가능
- HTTP 프로토콜을 직접 사용하여 서버의 REST-API 를 호출하는 일련의 네트워크 작업을 추상화한 메서드 제공
  - 예) `getForEntity()`, `postForEntity()`, `delete()`, `put()`...
- RestTemplate 는 네트워크 기능을 별도의 클래스에 위임하고 있음
  - 따라서 커넥션 관리나 메시지를 주고받는 저수준 네트워킹 작업은 구현체에 따라 다르게 동작함
  - RestTemplate 의 메서드는 이 구현체에 상관없이 일관된 기능 제공
- RestTemplate 는 **인터셉터 기능을 제공**하고 있어서 REST-API 실행 시 **메시지를 주고 받을 때 기능 확장 가능**
- RestTemplate 는 **멀티 스레드 환경에 안전한 클래스이므로 스프링 빈으로 객체를 생성하고 필요한 곳에 주입해서 사용해도 됨**

---

# 1.1. RestTemplate 구조

### 1.1.1. `HttpMessageConverter`

아래 그림을 통해 RestTemplate 의 구조를 확인해보자.

![RestTemplate 구조와 관련 클래스들](/assets/img/dev/2023/0923/rest-template.png)

`HttpMessageConverter` 는 HTTP 바디 메시지를 자바 객체로 변환하는 역할을 하고, `ClientRequestFactory` 는 REST-API 서버와 커넥션을 맺고 요청 메시지를 전달 후 응답 메시지를 
받아올 때 까지 일련의 네트워킹 과정을 처리한다. 즉, 네크워킹 과정은 `ClientRequestFactory` 에 위임되어 있다.

> `HttpMessageConverter` 의 좀 더 자세한 내용은 [Spring Boot - 웹 애플리케이션 구축 (2): HttpMessageConverter, ObjectMapper](https://assu10.github.io/dev/2023/08/06/springboot-application-2/#11-httpmessageconverter-%EC%84%A4%EC%A0%95) 의 _1.1. `HttpMessageConverter` 설정_ 를 참고하세요.

`o.s.http.converter.HttpMessageConverter` 는 스프링 MVC 프레임워크에서 컨텐츠 타입에 따라 메시지를 변환하는 역할을 하기 때문에 서버에 요청하는 메시지와 응답받은 메시지를 
자바 객체로 변환할 때 `HttpMessageConverter` 를 사용한다.  
이 때 Content-type 헤더에 정의된 값에 따라 적절한 `HttpMessageConverter` 가 동작한다.  
RestTemplate 기본 생성자 내부에는 기본 설정으로 `HttpMessageConverter` 객체들을 생성하고 내부 변수인 messageConverters 에 할당한다.

만일 개발자가 필요한 `HttpMessageConverter` 객체들을 새로 구성하려면 `setMessageConverter(List<HttpMessageConverter<?> messageConverters)` 나 `HttpMessageConverter` 리스트를 
인자로 받는 생성자를 사용하면 된다.  
이 방법들은 RestTemplate 의 messageConverters 내부 변수를 초기화하기 때문에 기본 설정으로 만들어진 `HttpMessageConverter` 리스트에 새로운 객체를 추가할 수 없다.  
`getMessageConverter()` 메서드가 리턴하는 List\<HttpMessageConverter\> 객체를 참조하여 새로운 객체를 추가하면 된다.

---

**RestTemplate 는 `ClientHttpRequestFactory` 클래스에 HTTP 통신을 위임**하고 있다.  

`ClientHttpRequestFactory` 인터페이스는 HTTP 프로토콜을 사용하여 클라이언트 요청과 서버 응답을 처리한다.  
ClientHttpRequest 의 execute() 메서드를 실행하면 ClientHttpResponse 객체를 받을 수 있는데, 이 때 서버와 클라이언트 사이에 커넥션을 사용하여 요청 전송 및 
응답 수신 과정이 진행된다.  

`ClientHttpRequestFactory` 인터페이스의 구현체는 다양한데 스프링 부트 프레임워크에서 제공하는 구현체로는 아래 구현체들이 있다.  
RestTemplate 을 설정할 때 개발자가 선택할 수 있다.

- `OkHttp3ClientHttpRequestFactory`
  - 안드로이드에서 많이 사용하는 OkHttp 로 작성한 구현체
  - 동기식/비동기식 모두 가능한 장점이 있음
- `Netty4ClientHttpRequestFactory`
  - 비동기 논블로킹 프레임워크인 Netty 를 사용하여 작성된 구현체
  - 비동기 프로그래밍을 계획한다면 가장 먼저 고려하는 것이 좋음
- `SimpleClientHttpRequestFactory`
  - 동기식으로 동작하며, JDK 에서 제공하는 라이브러리를 사용하여 작성된 구현체

---

### 1.1.2. `ClientHttpRequestInterceptor`

`ClientHttpRequestInterceptor` 인터페이스는 클라이언트 요청을 서버로 전송하기 전에 실행되는 `intercept()` 메서드를 제공한다.  
이 인터셉터를 한 개 이상 추가할 수 있고, 인터셉터 순서에 따라 `intercept()` 메서드가 차례로 실행된다.

---

### 1.1.3. `ResponseErrorHandler`

**RestTemplate 는 o.s.web.client.ResponseErrorHandler 인터페이스를 사용하여 에러를 처리**한다.  

기본 설정으로 o.s.web.client.DefaultResponseErrorHandler 구현체를 사용하는데 `ResponseErrorHandler` 구현체를 설정할 수 있는 setErrorHandler() 메서드를 통해 
에러 처리 기능을 교체할 수도 있다.

`ResponseErrorHandler` 2 개의 추상 메서드를 제공한다.

- `boolean hasError()`
  - 에러 여부 판단
- `void handleError()`
  - 에러 처리

기본 설정 구현체인 DefaultResponseErrorHandler 구현체는 HTTP 상태 코드 세 자리 중 첫 번째 자리에 따라 예외를 던지도록 구현되어 있다.  
참고로 DefaultResponseErrorHandler 가 던지는 예외들은 RuntimeException 클래스를 상속받기 때문에 RuntimeException 을 기본 처리하는 스프링 프레임워크의 예외 전략을 사용할 수 있다.

- 4XX
  - HttpClientErrorException 예외 발생
- 5XX
  - HttpServerErrorException 예외 발생
- 그 외
  - 표준에 정의되지 않은 HTTP 상태 코드는 UnknownHttpStatusCodeException 예외 발생

---

즉, RestTemplate 는 `HttpMessageConverter`, `ClientHttpRequestInterceptor`, `ResponseErrorHandler` 를 사용하여 기능 확장이 가능하다.

---

## 1.2. RestTemplate 스프링 빈 설정

아래에서는 SimpleClientHttpRequestFactory 와 RestTemplate 스프링 빈을 각각 설정한다.

/config/RestTemplateConfig.java
```java
package com.assu.study.chap09.config;

import com.assu.study.chap09.server.IdentityHeaderInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.DefaultResponseErrorHandler;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

  @Bean
  public ClientHttpRequestFactory clientHttpRequestFactory() {
    // RestTemplate 의 ClientHttpRequestFactory 구현체로 SimpleClientHttpRequestFactory 사용
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();

    // 클라이언트와 서버 사이에 커넥션 객체 생성 시 소요되는 최대 시간 (ms)
    factory.setConnectTimeout(3000);
    
    // 클라이언트가 서버에 데이터 처리를 요청하고 응답받기까지 소요되는 최대 시간 (ms)
    factory.setReadTimeout(1000);
    
    // SimpleClientHttpRequestFactory 는 요청 메시지의 바디를 버퍼링하는 기능을 제공함
    // 디폴트는 true
    // 요청 메시지의 바디를 버퍼링하지 않으려면 false 로 설정
    factory.setBufferRequestBody(false);

    return factory;
  }

  @Bean
  public RestTemplate restTemplate(ClientHttpRequestFactory clientHttpRequestFactory) {
    // ClientHttpRequestFactory 인자를 받는 생성자를 사용하여 RestTemplate 객체 생성
    // 바로 위에서 설정한 ClientHttpRequestFactory 스프링 빈을 주입받아서 RestTemplate 객체 생성
    RestTemplate restTemplate = new RestTemplate(clientHttpRequestFactory);

    // RestTemplate 객체에 새로운 인터셉터 객체 추가
    // getInterceptors() 는 RestTemplate 객체에 설정된 인터셉터 리스트 객체를 리턴하므로 리스트 객체의 add() 를 사용하여
    // IdentityHeaderInterceptor 객체 추가 (해당 인터셉터 구현은 뒤에 나옴)
    restTemplate.getInterceptors().add(new IdentityHeaderInterceptor());
    
    // RestTemplate 객체에 새로운 ResponseErrorHandler 설정
    restTemplate.setErrorHandler(new DefaultResponseErrorHandler());

    return restTemplate;
  }
}
```

`SimpleClientHttpRequestFactory` 가장 중요한 것은 Connection Timeout 과 Read Timeout 설정이다.

- `setConnectTimeout()`
  - ms 단위
  - 0과 양수값으로 설정 가능, 0은 Connection 이 맺어질 때까지 무기한으로 대기
- `setReadTimeout()`
  - ms 단위
  - 0과 양수값으로 설정 가능, 0은 서버 응답을 읽을 때까지 무기한으로 대기

`SimpleClientHttpRequestFactory` 는 내부에 버퍼를 포함하고 있으며, 요청 메시지의 바디를 저장하는 목적으로 사용된다.  
`setBufferRequestBody()` 로 버퍼링 기능을 설정할 수 있고, 기본값은 true 이다.  

**서버에 파일이나 이미지같은 용량이 큰 파일을 전송한다면 버퍼에 저장되므로 애플리케이션의 메모리에 문제가 발생**할 수 있다.  
따라서 요청 메시지의 바디가 크다면 반드시 `setBufferRequestBody(false)` 를 설정하여 기능을 이용하지 않는 것이 좋다.

---

### 1.2.1. `ClientHttpRequestInterceptor` 구현

REST-API 호출하고 응답받는 과정에 비즈니스 로직을 추가하려면 `ClientHttpRequestInterceptor` 를 이용할 수 있다.  
`ClientHttpRequestInterceptor` 는 스프링 WebMVC 의 인터셉터와 비슷한 역할을 하며, `ClientHttpRequestInterceptor` 구현 클래스를 생성하고 
RestTemplate 객체에 인터셉터 객체를 추가하면 된다.

위 예시에서는 `getInterceptors().add()` 를 이용하여 기존의 인터셉터에 추가를 했으며, 만일 새롭게 설정해야 한다면 `setInterceptors()` 를 사용한다.

여러 개의 인터셉터 설정이 가능하며, 이들은 체인 패턴 방식으로 구성되어 있다.

/server/IdentityHeaderInterceptor.java
```java
package com.assu.study.chap09.server;

import org.springframework.http.HttpRequest;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;

import java.io.IOException;

// 사용자 요청 메시지에 X-COMPONENT-ID 헤더가 없으면 헤더를 추가하는 역할
public class IdentityHeaderInterceptor implements ClientHttpRequestInterceptor {
  private static final String COMPONENT_HEADER_NAME = "X-COMPONENT-ID";
  private static final String COMPONENT_HEADER_VALUE = "HOTEL-API";

  @Override
  public ClientHttpResponse intercept(HttpRequest request, byte[] body, ClientHttpRequestExecution execution) throws IOException {
    // RestTemplate 에 X-COMPONENT-ID 헤더가 없으면 기본값인 HOTEL-API 헤더값 설정
    request.getHeaders().addIfAbsent(COMPONENT_HEADER_NAME, COMPONENT_HEADER_VALUE);

    // ClientHttpRequestExecution 의 execute() 메서드를 실행하여 다음 인터셉터로 요청 전달
    return execution.execute(request, body);
  }
}
```

**`intercept()` 메서드는 REST-API 의 사용자 요청 메시지를 가로채고, 서버의 응답 메시지를 리턴**한다.  

`ClientHttpRequestExcecution` 의 `execute()` 를 실행하면 체인의 다음 인터셉터를 실행한다.  

`intercept()` 의 각 인자는 아래와 같다.
- HttpRequest request
  - 요청 메시지를 추상화함
- byte[] body
  - 요청 메시지의 바디 데이터
- ClientHttpRequestExecution execution
  - 인터페이스 체인에서 다음 인터페이스로 요청 전달

위 인자들을 이용하여 사용자 요청 메시지나 바디 데이터를 수정/조회할 수 있다.

> MSA 아키텍처에서는 사용자의 요청 하나에 여러 컴포넌트의 API 들이 실행된다.  
> 그래서 관리나 통계를 생성하고자 API 를 호출하는 컴포넌트들의 이름을 access log 에 남길 때도 있다.  
> 이를 위해 아키텍처 설계 단계에서 사용자 정의 HTTP 헤더를 설정하고, 컴포넌트마다 고유의 아이디 값을 입력하도록 한다.  
> 
> REST-API 를 제공하는 컴포넌트 입장에서는 어떤 컴포넌트가 어떤 API 를 사용하는지 쉽게 알 수 있다.  
> 클라이언트가 요청 메시지에 헤더를 추가했으므로 서버는 access log 설정을 하여 로그를 남기면 된다.  
> 위의 IdentityHeaderInterceptor 는 사용자 정의 HTTP 헤더가 없을 경우를 보완하는 인터셉터 개념이다.

---

### 1.2.2. `ResponseErrorHandler` 구현

RestTemplate 에러 처리는 ResponseErrorHandler 인터페이스를 구현한 구현 클래스에 위임한다.  
기본 구현체는 DefaultResponseErrorHandler 이며, 별도의 에러 핸들러로 변경할 때는 RestTemplate 의 `setErrorHandler()` 를 사용하면 된다.  

RestTemplateConfig.java 에서는 기본 구현체를 사용하기 때문에 별도로 설정하지 않아도 되지만 예시를 위해 넣어두었다.

ResponseErrorHandler 인터페이스
```java
package org.springframework.web.client;

public interface ResponseErrorHandler {
  // 에러가 있는지 여부 판단
  // true 를 리턴하면 handleError() 메서드를 실행하여 에러 처리를 위임
  boolean hasError(ClientHttpResponse response) throws IOException;

  // 에러가 있다면 IOException 예외를 던져도 되고, ClientHttpResponse 객체를 사용하여 에러를 처리해도 됨
  void handleError(ClientHttpResponse response) throws IOException;

  default void handleError(URI url, HttpMethod method, ClientHttpResponse response) throws IOException {
    this.handleError(response);
  }
}
```

---

## 1.3. Connection Timeout 과 Read Timeout 설정

네트워크는 신뢰성이 낮으며, 네트워크 뿐 아니라 다른 컴포넌트도 장애가 발생할 수 있다.  
시스템에 과부하가 걸리거나 버그가 있어 정상적으로 요청을 처리하지 못할 수 있다.  
이렇게 장애 상황이 지속되면 많은 사람이 여러 번 클릭하기 때문에 사용자 요청이 더 많아질 수 있다.  
결국 REST-API 클라이언트도 리소스가 부족해지거나 과부하 상태가 될 수 있다.

따라서 MSA 환경에서는 특히 Connection Timeout 과 Read Timeout 을 반드시 설정해야 한다.

**Connection Timeout 은 Hotel API 와 Reserve API 사이에 커넥션을 맺는 시간**이다.  
TCP 3-way-handshake 가 Timeout 시간 내에 되지 않으면 예외가 발생하는데 이 때 클라이언트인 Hotel API 에서 예외가 발생하며, 서버인 Reserve API 에서는 예외 여부를 알 수 없다.

Connection Timeout 의 예외 메시지는 아래와 같다.
```shell
java.net.ConnectionException: Connection timed out: connect
```

**Read Timeout 은 Hotel API 가 Reserve API 의 REST-API 를 요청하고 응답을 받을 때까지의 시간**이다.  
Connection Timeout 처럼 클라이언트인 Hotel API 에서 예외가 발생한다.

```shell
java.net.SocketTimeoutException: Read timed out
```

클라이언트가 REST-API 를 호출하고 그 결과를 시간 내에 받지 못한 것이므로 커넥션은 정상적으로 생성되었음을 의미한다. 따라서 Connection Timeout 과 Read Timeout 현상은 
동시에 같은 스레드에서 발생할 수 없다.

일반적으로 Read Timeout 은 서버가 과부하 상태이거나 특정 부분에 문제가 생겨 처리가 오래 걸릴 때 발생한다.

---

적절한 Connection Timeout 과 Read Timeout 값을 찾는 것은 어렵다. 이 때는 서버 관점이 아닌 서비스 관점에서 생각해야 한다.

사용자 요청 수 사용자의 대기 시간은 아래와 같이 계산할 수 있다.

> 사용자 대기 시간 =   
> Hotel API 의 요청 처리 시간  
> \+ Hotel API 의 사용자 구간의 네트워크 지연 시간    
> \+ Reserve API 의 요청 처리 시간  
> \+ Reserve API 와 Hotel API 구간의 네트워크 지연 시간

만일 5초 이내에 요청을 처리하는 것이 목표라면 사용자 대기 시간이 5초인 것을 의미한다.

만일 Hotel API 의 요청 처리 시간이 1초이고, Reserve API 의 요청 처리 시간도 1초라고 하면 3초가 남는다.
두 컴포넌트의 처리 시간 합계가 2초이므로 커넥션을 맺고 데이터를 읽는 네트워크 소요 시간을 3초로 설정하면 된다.  

여기서 Connection Timeout 과 Read Timeout 은 어떻게 분배하는 것이 좋을까?    
정답은 따로 없고 적절한 Timeout 값을 설정한 후 스카우터나 핀 포인트같은 APM 툴을 사용하여 모니터링하며 값을 튜닝하는 것이 좋다.

---

## 1.4. RestTemplate 클래스

RestTemplate 은 서버의 REST-API 를 호출할 수 있는 메서드들을 제공하는데 메서드명으로 분류하면 크게 두 가지로 분류할 수 있다.
- POST, GET 같은 HTTP 메서드명을 사용하여 해당 HTTP 메서드만 사용하는 메서드들
- HTTP 의 메서드를 인자로 넘겨서 범용적으로 사용할 수 있는 exchange 메서드들

아래는 RestTemplate 의 메서드들이다.
- `getForObject()`
  - HTTP GET 메서드 사용
  - 서버의 응답 메시지 중 바디를 변환한 자바 객체 리턴
- `getForEntity()`
  - HTTP GET 메서드 사용
  - 서버의 응답 메시지를 변환한 ResponseEntity 객체 리턴
  - ResponseEntity 는 바디 메시지 클래스 타입을 위한 제네릭 타입을 입력받음
- `headForHeader()`
  - HTTP HEAD 메서드 사용
  - 서버의 리소스에 대해 헤더 정보만 조회할 때 사용
  - 서버의 응답 메시지는 바디가 없으며, HTTP 헤더 정보는 HttpHeaders 객체로 변환하여 리턴
- `postForLocation()`
  - HTTP POST 메서드 사용
  - 서버는 생성된 리소스 위치를 Location 헤더로 응답하는데 이 때 사용하는 메서드
  - 응답 헤더 중에서 Location 헤더값을 URI 객체로 변환하여 리턴
- `postForObject()`
  - HTTP POST 메서드 사용
  - 서버의 응답 메시지 중 바디를 자바 객체로 변환하여 리턴
- `postForEntity()`
  - HTTP POST 메서드 사용
  - `postForObject()` 와 마찬 가지로 REST-API 의 POST 메서드를 호출할 때 사용하지만, 서버의 응답 메시지를 ResponseEntity 객체로 변환하여 리턴
- `put()`
  - HTTP PUT 메서드 사용
  - 응답 타입은 void
- `patchForObject()`
  - HTTP PATCH 메서드 사용
  - 응답 메시지 중 바디를 자바 객체로 리턴
- `Delete()`
  - HTTP DELETE 메서드 사용
  - 응답 타입은 void
- `optionsForAllow()`
  - HTTP OPTIONS 메서드 사용
  - 서버의 특정 리소스에서 제공하는 HTTP 메서드를 조회할 때 사용
  - 서버는 특정 리소스에서 사용할 수 있는 HTTP 메서드를 Allow 헤더를 사용하여 응답
  - 그러므로 Set\<HttpMethod\> 객체를 응답함
  - OPTIONS 의 개념은 [1.2.7. `addCorsMappings()`](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#127-addcorsmappings) 을 보시면 도움이 됩니다.
- `exchange()`
  - 인자를 사용하여 HTTP 통신
  - HTTP 메서드의 종류는 o.s.http.HttpMethod 열거형에 정의되어 있음
  - URI 와 RequestEntity 등을 인자로 받으며, 이 값을 사용하여 서버에 요청
  - 서버의 응답 메시지를 ResponseEntity 객체로 변환하여 리턴

RestTemplate 클래스는 서버에 요청하는 HTTP 요청 메시지로 o.s.http.httpEntity 를 사용하고, 서버가 응답하는 HTTP 응답 메시지로는 o.s.http.ResponseEntity 를 사용한다.

---

## 1.5. RestTemplate 예시

빌링 코드를 조회/생성하는 API 스펙이 아래와 같다고 하자.

```http
// 빌링 코드 조회
// request
GET /billing-codes?codeName=  HTTP/1.0
Accept: application/json

// response
{
  "success": true,
  "resultMessage": "success",
  "data": [
    {"billingCode": "CODE-111111"},
    {"billingCode": "CODE-222222"}
  ]
}


// 빌링 코드 등록
// request
POST /billing-codes HTTP/1.0
Content-type: application/json
Accept: application/json

{
  "type": 1,
  "hotelIds": ["111", "222", "333"]
}

// response
{
  "success": true,
  "resultMessage": "success",
  "data": {
    "codes": [111, 222, 333]
  }
}
```

위 API 스펙을 보면 메시지 포맷이 동일하다.  
이런 공통 메시지 포맷을 어떻게 처리하는지도 함께 보도록 하자.

/controller/ApiResponse.java
```java
package com.assu.study.chap09.controller;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class ApiResponse<T> {
  private boolean success;
  private String resultMessage;
  // data 속성은 API 마다 다를 수 있으므로 제네릭 타입 사용
  private T data;

  public ApiResponse() {
  }

  public ApiResponse(boolean success, String resultMessage) {
    this.success = success;
    this.resultMessage = resultMessage;
  }

  public static <T> ApiResponse ok(T data) {
    ApiResponse apiResponse = new ApiResponse(true, "success");
    apiResponse.data = data;
    return apiResponse;
  }
}
```

/controller/BillingCodeResponse.java
```java
package com.assu.study.chap09.controller;

import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@Getter
@Setter
@ToString
public class BillingCodeResponse {
  private String billingCode;

  public static BillingCodeResponse of(String billingCode) {
    BillingCodeResponse response = new BillingCodeResponse();
    response.billingCode = billingCode;
    return response;
  }
}
```


/controller/CreateCodeResponse.java
```java
package com.assu.study.chap09.controller;

import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

import java.util.List;

@Getter
@Setter
@ToString
public class CreateCodeResponse {
  private List<Long> codes;
  
  public static CreateCodeResponse of(List<Long> codes) {
    CreateCodeResponse response = new CreateCodeResponse();
    response.codes = codes;
    return response;
  }
}
```

ApiResponse 사용법은 아래와 같다.
```java
// GET /billing-codes
ApiResponse<List<BillingCodeResponse>>

// POST /billing-codes
ApiResponse<CreateCodeResponse>
```

RestTemplate 예시는 뒤에서 /adapter/BillingAdapter 클래스를 통해 알아본다.  

---

### 1.5.1. `GET` 메서드 예시

아래는 RestTemplate 의 `getForEntity()` 를 사용하여 서버의 빌링 코드를 조회하는 예시이다.

/Adapter/billingAdapter.java
```java
package com.assu.study.chap09.Adapter;

import com.assu.study.chap09.controller.ApiResponse;
import com.assu.study.chap09.controller.BillingCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.List;
import java.util.Objects;

@Component
@Slf4j
public class BillingAdapter {

  private final RestTemplate restTemplate;

  public BillingAdapter(RestTemplate restTemplate) {
    this.restTemplate = restTemplate;
  }

  public List<BillingCodeResponse> getBillingCodes(String codeNameParam) {
    // URI 객체 생성
    UriComponentsBuilder builder = UriComponentsBuilder.fromPath("/billing-codes")
        .scheme("http").host("127.0.0.1").port(8080);

    if (Objects.nonNull(codeNameParam)) {
      builder.queryParam("codeName", codeNameParam);
    }

    URI uri = builder.build(false).encode().toUri();

    // GET 메서드를 이용하여 서버에 요청
    // 두 번째 인자를 응답 메시지를 변환할 클래스 타입
    // 두 번째 인자가 ApiResponse.class 이므로 리턴 타입은 ResponseEntity<ApiResponse> 가 됨
    ResponseEntity<ApiResponse> responseEntity = restTemplate.getForEntity(uri, ApiResponse.class);

    if (HttpStatus.OK != responseEntity.getStatusCode()) {
      log.error("Error from Billing. status: {}, param: {}", responseEntity.getStatusCode(), codeNameParam);
      throw new RuntimeException("Error From Billing~" + responseEntity.getStatusCode());
    }

    // getBody() 는 HTTP 응답 메시지의 바디값을 응답
    // 단, getForEntity() 메서드의 인자로 사용된 클래스 타입으로 응답하므로 ApiResponse 객체로 응답
    ApiResponse apiResponse = responseEntity.getBody();
    
    // 제네릭 타입이 설정되어 있지 않은 ApiResponse 객체의 data 속성의 클래스 타입은 Object 이므로
    // 적절한 타입의 객체로 변경하려면 타입 캐스팅 필요
    return (List<BillingCodeResponse>) apiResponse.getData();
  }
}
```

BillingAdapter 클래스의 메서드를 호출하는 것은 Chap09Application 클래스이다.

/Chap09Application.java
```java
package com.assu.study.chap09;

import com.assu.study.chap09.Adapter.BillingAdapter;
import com.assu.study.chap09.controller.BillingCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.util.List;

@Slf4j
@SpringBootApplication
public class Chap09Application {

  public static void main(String[] args) {
    ConfigurableApplicationContext ctx = SpringApplication.run(Chap09Application.class, args);

    BillingAdapter billingAdapter = ctx.getBean(BillingAdapter.class);

    List<BillingCodeResponse> responses = billingAdapter.getBillingCodes("CODE:1234567");
    log.info("getBillingCode: {}", responses);

  }

}
```

/controller/BillingController.java
```java
package com.assu.study.chap09.controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Slf4j
@RestController
public class BillingController {

  @GetMapping("/billing-codes")
  public ApiResponse<List<BillingCodeResponse>> getBillingCodes(
      @RequestParam(required = false) String codeName
  ) {
    List<BillingCodeResponse> response = List.of(
        BillingCodeResponse.of("CODE-111111"),
        BillingCodeResponse.of("CODE-222222")
    );
    return ApiResponse.ok(response);
  }
}
```

서버 실행 시 아래와 같은 로그를 확인할 수 있다.
```shell
getBillingCode: [{billingCode=CODE-111111}, {billingCode=CODE-222222}]
```

---

URI 객체는 `UriComponentsBuilder` 클래스를 사용하면 편하게 생성할 수 있다.  
String 문자열을 조합하여 경로를 구성해도 되지만 `UriComponentsBuilder` 클래스를 사용하면 좀 더 명확하게 URI 객체를 만들 수 있다.

`UriComponentsBuilder` 객체를 생성하는 여러가지 static 팩토리 메서드가 있는데 `fromPath()`, `fromUriString()`, `fromHttpUrl()` 은 URI 템플릿 문자열을 사용하여 
객체를 생성할 수 있다.  
템플릿 문자열은 변수를 포함할 수 있으며 `UriComponentsBuilder` 의 `build()` 혹은 `buildAndExpand()` 메서드를 사용하면 변수를 값으로 교체할 수 있다.  
예를 들어 'hotel-names/{hotelName}' 에서 {hotelName} 은 변수이며, `build()` 메서드에 인자로 변수값을 넣으면 {hotelName} 변수값이 교체된다.

`UriComponentsBuilder` 의 예시는 [1.5.4. `UriComponentsBuilder`](#154-uricomponentsbuilder) 에 있습니다.

---

### 1.5.2. `POST` 메서드 예시

아래는 RestTemplate 의 `postForEntity()` 를 사용한 예시이다.  

/controller/BillingAdapter.java
```java
package com.assu.study.chap09.Adapter;

import com.assu.study.chap09.controller.ApiResponse;
import com.assu.study.chap09.controller.BillingCodeResponse;
import com.assu.study.chap09.controller.CreateCodeRequest;
import com.assu.study.chap09.controller.CreateCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Component
@Slf4j
public class BillingAdapter {

  private final RestTemplate restTemplate;

  public BillingAdapter(RestTemplate restTemplate) {
    this.restTemplate = restTemplate;
  }

  public CreateCodeResponse createWithPostForEntity(List<Long> hotelIds) {
    URI uri = UriComponentsBuilder.fromPath("/billing-codes")
        .scheme("http").host("127.0.0.1").port(8080)
        .build(false).encode().toUri();

    CreateCodeRequest request = new CreateCodeRequest(1, hotelIds);

    ResponseEntity<ApiResponse> responseEntity = restTemplate.postForEntity(uri, request, ApiResponse.class);

    if (HttpStatus.OK != responseEntity.getStatusCode()) {
      log.error("Error from Billing. status:{}, hotelIds:{}", responseEntity.getStatusCode(), hotelIds);
      throw new RuntimeException("Error from Billing. " + responseEntity.getStatusCode());
    }

    ApiResponse apiResponse = responseEntity.getBody();

    // data 속성값을 Map 으로 캐스팅
    // JSON 객체의 data 속성값은 "codes": [111,222,333] 이므로 Map 의 key 는 "codes" 문자열이, Map 의 값에는 Long 타입의 리스트가 저장됨
    Map<String, List<Long>> dataMap = (Map) apiResponse.getData();

    return CreateCodeResponse.of(dataMap.get("codes"));
  }
```

/controller/CreateCodeRequest.java
```java
package com.assu.study.chap09.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
//@ToString
public class CreateCodeRequest {
  private Integer type;

  @JsonProperty("hotelIds") // JSON 객체로 마셜링하는 과정에서 ids 속성명 대신 hotelIds 가 JSON 객체의 속성명이 됨
  private List<Long> ids;

  public CreateCodeRequest(Integer type, List<Long> ids) {
    this.type = type;
    this.ids = ids;
  }
}
```

/controller/BillingController.java
```java
package com.assu.study.chap09.controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Slf4j
@RestController
public class BillingController {
  @PostMapping(path = "/billing-codes")
  public ApiResponse<CreateCodeResponse> createBillingCodes(
          @RequestBody CreateCodeRequest request
  ) {
    return ApiResponse.ok(CreateCodeResponse.of(request.getIds()));
  }
}
```

/Chap09Application.java
```java
package com.assu.study.chap09;

import com.assu.study.chap09.Adapter.BillingAdapter;
import com.assu.study.chap09.controller.BillingCodeResponse;
import com.assu.study.chap09.controller.CreateCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.util.List;

@Slf4j
@SpringBootApplication
public class Chap09Application {

  public static void main(String[] args) {
    ConfigurableApplicationContext ctx = SpringApplication.run(Chap09Application.class, args);

    BillingAdapter billingAdapter = ctx.getBean(BillingAdapter.class);

    CreateCodeResponse createCodeResponse = billingAdapter.createWithPostForEntity(List.of(1234567L));

    // createWithPostForEntity: CreateCodeResponse(codes=[1234567])
    log.info("createWithPostForEntity: {}", createCodeResponse);
  }
}
```

```shell
createWithPostForEntity: CreateCodeResponse(codes=[1234567])
```

---

### 1.5.3. `exchange()` 와 `ParameterizedTypeReference` 메서드 예시

위에선 `postForEntity()`, `getForEntity()` 를 사용하여 REST-API 를 호출하였다.  

이번엔 RestTemplate 의 `exchange()` 를 이용하여 REST-API 를 호출해본다.  
`postForEntity()`, `getForEntity()` 와 비교했을 때 **`exchange()` 는 아래와 같은 특징**이 있다.

- HTTP 메서드를 자유롭게 선택 가능
- **`ParameterizedTypeReference` 를 사용할 수 있어 타입 캐스팅없이 슈퍼 타입 토큰 사용 가능**
  - 즉, 클래스 타입에 안전한 코드 작성이 가능하기 때문에 타입 캐스팅 과정이 필요없음

/adapter/BillingAdapter.java
```java
package com.assu.study.chap09.Adapter;

import com.assu.study.chap09.controller.ApiResponse;
import com.assu.study.chap09.controller.CreateCodeRequest;
import com.assu.study.chap09.controller.CreateCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.List;

@Component
@Slf4j
public class BillingAdapter {

  // ParameterizedTypeReference 를 사용하여 ApiResponse<CreateCodeResponse> 처럼 중첩된 클래스 타입에 대한 클래스 타입 정보 정의
  private static final ParameterizedTypeReference<ApiResponse<CreateCodeResponse>> TYPE_REFERENCE;

  static {
    TYPE_REFERENCE = new ParameterizedTypeReference<>() {
    };
  }

  private final RestTemplate restTemplate;

  public BillingAdapter(RestTemplate restTemplate) {
    this.restTemplate = restTemplate;
  }

  // exchange() 로 REST-API 호출
  public CreateCodeResponse createWithExchange(List<Long> hotelIds) {
    URI uri = UriComponentsBuilder.fromPath("/billing-codes")
        .scheme("http").host("127.0.0.1").port(8080)
        .build(false).encode().toUri();

    CreateCodeRequest request = new CreateCodeRequest(1, hotelIds);

    HttpHeaders headers = new HttpHeaders();
    // 요청 메시지의 바디가 JSON 메시지이므로 Content-type 헤더 추가
    headers.setContentType(MediaType.APPLICATION_JSON);
    // HTTP 요청 메시지를 생성하려고 HttpEntity 객체 생성
    HttpEntity<CreateCodeRequest> httpEntity = new HttpEntity<>(request, headers);

    // HTTP 요청 메시지는 HttpEntity 객체 사용
    // 리턴 타입은 ParameterizedTypeReference 를 사용하여 정의
    ResponseEntity<ApiResponse<CreateCodeResponse>> responseEntity =
        restTemplate.exchange(uri, HttpMethod.POST, httpEntity, TYPE_REFERENCE);

    if (HttpStatus.OK != responseEntity.getStatusCode()) {
      log.error("Error from Billing. status:{}, hotelIds:{}", responseEntity.getStatusCode(), hotelIds);
      throw new RuntimeException("Error from Billing. " + responseEntity.getStatusCode());
    }

    // 타입 캐스팅없이 클래스 타입에 안전하게 CreateCodeResponse 객체 리턴
    return responseEntity.getBody().getData();
  }
}
```

/Chap09Applicaton.java
```java
package com.assu.study.chap09;

import com.assu.study.chap09.Adapter.BillingAdapter;
import com.assu.study.chap09.controller.BillingCodeResponse;
import com.assu.study.chap09.controller.CreateCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.util.List;

@Slf4j
@SpringBootApplication
public class Chap09Application {

  public static void main(String[] args) {
    ConfigurableApplicationContext ctx = SpringApplication.run(Chap09Application.class, args);

    BillingAdapter billingAdapter = ctx.getBean(BillingAdapter.class);

    CreateCodeResponse createCodeResponse2 = billingAdapter.createWithExchange(List.of(1234567L, 111L, 876456L));
    // createWithExchange: CreateCodeResponse(codes=[1234567, 111, 876456])
    log.info("createWithExchange: {}", createCodeResponse2);
  }
}
```

```shell
createWithExchange: CreateCodeResponse(codes=[1234567, 111, 876456])
```

---

**`exchange()` 와 `postForEntity()` 의 가장 큰 차이점은 슈퍼 타입 토큰, 즉 `ParameterizedTypeReference` 인자 여부**이다.

`postForEntity()` 메서드의 리턴 타입인 Class\<T\> 인자는 REST-API 의 응답 메시지를 변환할 클래스 타입인데, Class\<T\> 는 중첩된 클래스 타입을 정의할 수 없다.  
그래서 아래처럼 메서드를 실행해야 하며, ApiResponse 의 제네릭 타입인 CreateCodeResponse 클래스 타입을 설정할 수 없다.

```java
ResponseEntity<ApiResponse> responseEntity = restTemplate.postForEntity(uri, request, ApiResponse.class);
```

결국 아래처럼 타입 캐스팅을 사용하여 CreateCodeResponse 객체를 생성해야 한다.

```java
ApiResponse apiResponse = responseEntity.getBody();
// data 속성값을 Map 으로 캐스팅
// JSON 객체의 data 속성값은 "codes": [111,222,333] 이므로 Map 의 key 는 "codes" 문자열이, Map 의 값에는 Long 타입의 리스트가 저장됨
Map<String, List<Long>> dataMap = (Map) apiResponse.getData();
```

**타입 캐스팅의 가장 큰 단점은 클래스 타입 안정성을 확보할 수 없다**는 것이다.  
즉, **타입 캐스팅을 잘못해도 컴파일 에러는 발생하지 않지만 런타임에서 에러가 발생**할 수 있다.  

이런 타입 캐스팅의 단점을 극복하는 것이 슈퍼 타입 토큰이다.  
**슈퍼 타입 토큰은 중첩된 타입을 정의할 수 있는 장점이 있으며, 스프링 프레임워크는 슈퍼 타입 토큰으로 `ParameterizedTypeReference` 클래스 구현체를 제공**한다.

슈퍼 타입 토큰의 사용법은 아래와 같다.
```java
// ParameterizedTypeReference 를 사용하여 ApiResponse<CreateCodeResponse> 처럼 중첩된 클래스 타입에 대한 클래스 타입 정보 정의
private static final ParameterizedTypeReference<ApiResponse<CreateCodeResponse>> TYPE_REFERENCE;

static {
  TYPE_REFERENCE = new ParameterizedTypeReference<>() {
  };
}
```

`exchange()` 메서드를 슈퍼 타입 토큰인 `ParameterizedTypeReference` 를 인자로 받을 수 있기 때문에 타입 캐스팅을 하지 않아도 된다.

---

### 1.5.4. `UriComponentsBuilder`

HTTP 통신을 할 때 URL 의 모든 문자열은 퍼센트 인코딩을 사용하여 서버에 요청한다.  

> **퍼센트 인코딩 방식**  
> 
> 알파벳, 숫자, 예약어를 제외한 나머지 데이터를 octet 값으로 묶은 후 이를 다시 16진수로 변경  
> 이 때 % 를 붙여서 octet 값들을 구분한다고 해서 퍼센트 인코딩이라고 함

아래는 인코딩 전/후의 차이이다.
```http
GET /billing-codes?type=hotel&flight  // 인코딩 전
GET /billing-codes?type=hotel%26flight  // 인코딩 후
```

만일 파라메터값이 한글이면 UTF-8 같은 캐릭터셋으로 인코딩한 후 다시 퍼센트 인코딩을 해야 한다.  
클라이언트는 URL 을 인코딩하고, 요청을 받은 서버는 디코딩해서 요청한 문자열 값으로 변환한다.  
스프링 MVC 프레임워크는 자동으로 URL 값을 디코딩하기 때문에 `@PathVariable` 이나 `@RequestParam` 애넡이션을 사용하여 주입받은 변수들은 자동으로 디코딩된다.

자바는 URL 을 인코딩/디코딩하는 클래스는 제공하는데 java.net 패키지의 URLEncoder 와 URLDecoder 이다.  
각각 `encode()`, `decode()` 를 사용하여 문자열을 인코딩/디코딩할 수 있다.

`UriComponentsBuilder` 의 `build()` 메서드는 리턴하는 클래스 타입에 따라 다르게 동작하기 때문에 주의가 필요하다.  
**URI 를 리턴하는 `build()` 메서드는 내부에서 인코딩을 하지만, UriComponents 를 리턴하는 `build()` 메서드는 내부에서 인코딩을 하지 않는다.**


`UriComponentsBuilder` 의 `build()` 메서드들
```java
public URI build(Object... uriVariables)
public URI build(Map<String, ?> uriVariables)
public UriComponents build()
```

아래 테스트 케이스 예시를 보자.
test > UriComponentsBuilderTest.java
```java
package com.assu.study.chap09;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

public class UriComponentsBuilderTest {

  @Test
  void testBuild() {
    // URI 를 리턴하는 build() 이므로 내부적으로 인코딩하는 케이스
    // given, when
    URI uri = UriComponentsBuilder.fromPath("/hotels/{hotelName}")
        .queryParam("type", "{type}")
        .queryParam("isActive", "{isActive}")
        .scheme("https").host("127.0.0.1").port(18080)
        .build("한국 hotel", "Hotel", "true");  

    // then
    Assertions.assertEquals("https://127.0.0.1:18080/hotels/%ED%95%9C%EA%B5%AD%20hotel?type=Hotel&isActive=true", uri.toString());
  }
}
```

```java
package com.assu.study.chap09;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

public class UriComponentsBuilderTest {
  @Test
  void testEncoding() {
    // 1. URI 를 리턴하는 build() 이므로 내부적으로 인코딩하는 케이스
    URI firstUri = UriComponentsBuilder.fromPath("/hotels/{hotelName}")
        .scheme("https").host("127.0.0.1").port(18080)
        .build("한국호텔"); // URL 경로에 포함된 템플릿 변수를 인자로 치환하고 인코딩함

    Assertions.assertEquals("https://127.0.0.1:18080/hotels/%ED%95%9C%EA%B5%AD%ED%98%B8%ED%85%94", firstUri.toString());


    // 2. UriComponents 를 리턴하는 build() 이므로 내부적으로 인코딩하지 않는 케이스
    String variable = "한국호텔";
    String path = "/hotels/" + variable;  // 템플릿 변수 없음

    // 템플릿을 사용하지 않았으므로 UriComponents 를 리턴하는 build() 사용 (내부에서 인코딩하지 않음)
    URI secondUri = UriComponentsBuilder.fromPath(path)
        .scheme("https").host("127.0.0.1").port(18080)
        .build()  // UriComponents 리턴
        .toUri(); // UriComponents 를 리턴하므로 toUri() 를 통해 URI 객체로 변환

    // 퍼센트 인코딩을 물론 UTF-8 문자셋 인코딩도 되지 않음
    Assertions.assertEquals("https://127.0.0.1:18080/hotels/한국호텔", secondUri.toString());


    // 3. UriComponents 를 리턴하는 build() 이므로 내부적으로 인코딩하지 않기 때문에 별도의 인코딩해주는 케이스
    String variable2 = "한국호텔";
    String path2 = "/hotels/" + variable2;  // 템플릿 변수 없음

    URI thirdUri = UriComponentsBuilder.fromPath(path2)
        .scheme("https").host("127.0.0.1").port(18080)
        .build(false) // 받아온 인자값이 인코딩 되어있는지 여부에 따라 true/false 입력
        .encode() // 인코딩 
        .toUri();

    Assertions.assertEquals("https://127.0.0.1:18080/hotels/%ED%95%9C%EA%B5%AD%ED%98%B8%ED%85%94", thirdUri.toString());
  }
}
```

위 코드에서 `build(false)` 부분에 대해 보자.  

```java
UriComponents build(boolean encoded)
```

인자로 들어가는 true/false 는 URI 를 인코딩할 지 여부가 아니라 인자값이 인코딩되어 있는 상태인지 여부를 설정하는 것이다.  
여기선 URI 값들이 인코딩되어 있지 않은 상태이므로 false 로 설정한다.

---

## 1.6. `keep-alive` 와 `Connection-Pool` 설정

### 1.6.1. 커넥션 풀 설정: `HttpComponentsClientHttpRequestFactory`

바로 위의 예시로 본 RestTemplate 스프링 빈은 `SimpleClientHttpRequestFactory` 구현체를 사용하였다.  

`SimpleClientHttpRequestFactory` 는 HTTP 통신을 할 때마다 서버와 클라이언트에 새로운 커넥션을 맺는다.  
RestTemplate 의 `exchange()` 나 `postForEntity()` 처럼 REST-API 를 호출할 때마다 새로운 커넥션을 생성하고, HTTP 통신이 끝나면 해당 커넥션은 종료된다.  
이렇게 REST-API 를 호출할 때마다 커넥션을 매번 생성하는 것은 시스템 리소스를 낭비하는 일이 된다.

**`SimpleClientHttpRequestFactory` 대신 `HttpComponentsClientHttpRequestFactory` 를 사용하면 커넥션 풀을 활용**할 수 있다.  

**`HttpComponentsClientHttpRequestFactory` 는 아파치 httpcomponents 프로젝트의 `httpclient5` 라이브러리를 사용하여 HTTP 통신을 하는 구현체**이다.

`httpclient5` 라이브러리는 커넥션 풀을 관리할 수 있는 `PoolingHttpClientConnectionManager` 클래스를 제공한다.

pom.xml
```xml
<dependency>
  <groupId>org.apache.httpcomponents.client5</groupId>
  <artifactId>httpclient5</artifactId>
  <version>5.2.1</version>
</dependency>
```

아파치 `httpclient5` 라이브러리는 HTTP 통신을 할 수 있는 `CloseableHttpClient` 클래스와 이를 설정할 수 있는 클래스들을 제공한다.  
`CloseableHttpClient` 를 설정하려면 `RequestConfig` 클래스와 `setDefaultRequestConfig()` 메서드를 사용하는데 
`RequestConfig` 클래스는 HTTP 통신을 요청할 때 필요한 값을 설정하는 클래스로, 이 객체를 `setDefaultRequestConfig()` 인자로 넘긴다.

`CloseableHttpClient` 는 `PoolingHttpClientConnectionManager` 에 커넥션 관리를 위임하며, **`PoolingHttpClientConnectionManager` 는 
커넥션을 관리하는 커넥션 풀 기능을 제공**한다.  

적절한 값으로 설정한 `PoolingHttpClientConnectionManager` 객체를 `CloseableHttpClient` 의 `setConnectionManager()` 메서드의 인자로 입력하면 
`CloseableHttpClient` 는 `PoolingHttpClientConnectionManager` 에서 커넥션 객체를 받아 HTTP 통신을 한다.

아래는 `PoolingHttpClientConnectionManager` 와 `RequestConfig` 를 설정하는 예시이다.

/config/poolingRestTemplateConfig.java
```java
package com.assu.study.chap09.config;

import org.apache.hc.client5.http.HttpRoute;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClientBuilder;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManager;
import org.apache.hc.core5.http.HttpHost;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.util.concurrent.TimeUnit;

@Configuration
public class PoolingRestTemplateConfig {
  @Bean
  public PoolingHttpClientConnectionManager poolingHttpClientConnectionManager() {
    PoolingHttpClientConnectionManager manager = new PoolingHttpClientConnectionManager();
    manager.setMaxTotal(100); // 커넥션 풀에서 관리할 수 있는 총 커넥션 갯수, 여기서는 100개 설정
    manager.setDefaultMaxPerRoute(5); // 커넥션 풀에서 루트마다 관리할 수 있는 총 커넥션 갯수, 일반적으로 별도의 설정이 없다면 5개로 사용함

    // 터넥션 풀에서 특정 루트마다 관리할 수 있는 총 커넥션 개수 설정
    // defaultMaxPerRoute 설정을 덮어씀
    // 여기서는 http://10.192.10.111:8080 의 최대 커넥션 갯수는 10개로 설정
    HttpHost httpHost = new HttpHost("http", "10.192.10.111", 8080);
    manager.setMaxPerRoute(new HttpRoute(httpHost), 10);

    return manager;
  }

  @Bean
  public RequestConfig requestConfig() {
    return RequestConfig.custom()
        .setConnectionRequestTimeout(3000, TimeUnit.MILLISECONDS) // PoolingHttpClientConnectionManager 에서 커넥션을 요청해서 받기까지 걸리는 시간
        .setConnectTimeout(3000, TimeUnit.MILLISECONDS) // 서버와 클라이언트 사이의 커넥션을 생성하는 시간
        .setResponseTimeout(1000, TimeUnit.MILLISECONDS)  // HTTP 요청 메시지 전달 후 응답 메시지를 받기까지의 시간
        .build();
  }

  // 적절한 값으로 설정한 `PoolingHttpClientConnectionManager` 객체를 `CloseableHttpClient` 의 `setConnectionManager()` 메서드의 인자로 입력하면
  // `CloseableHttpClient` 는 `PoolingHttpClientConnectionManager` 에서 커넥션 객체를 받아 HTTP 통신을 함.
  @Bean
  public CloseableHttpClient httpClient() {
    // HttpClientBuilder 를 사용하여 CloseableHttpClient 객체 생성
    // 위에서 생성한 PoolingHttpClientConnectionManager 스프링 빈과 RequestConfig 스프링 빈을 주입받아 CloseableHttpClient 스프링 빈 생성
    return HttpClientBuilder.create()
        .setConnectionManager(poolingHttpClientConnectionManager())
        .setDefaultRequestConfig(requestConfig())
        .build();
  }

  // 커넥션 풀을 사용하는 CloseableHttpClient 를 사용하고자 HttpComponentsClientHttpRequestFactory 객체를 생성
  // 그리고 이를 사용하는 RestTemplate 스프링 빈 생성
  @Bean
  public RestTemplate poolingRestTemplate() {
    HttpComponentsClientHttpRequestFactory requestFactory = new HttpComponentsClientHttpRequestFactory();
    requestFactory.setHttpClient(httpClient());
    return new RestTemplate(requestFactory);
  }
}
```

`PoolingHttpClientConnectionManager` 의 커넥션 풀 사용 시에는 `maxTotal()`, `defaultMaxPerRoute()`, `maxPerRoute()` 설정값을 고려해야 한다.

위에서 해당 코드를 다시 보자.
```java
@Bean
public PoolingHttpClientConnectionManager poolingHttpClientConnectionManager() {
  PoolingHttpClientConnectionManager manager = new PoolingHttpClientConnectionManager();
  manager.setMaxTotal(100); // 커넥션 풀에서 관리할 수 있는 총 커넥션 갯수, 여기서는 100개 설정
  manager.setDefaultMaxPerRoute(5); // 커넥션 풀에서 루트마다 관리할 수 있는 총 커넥션 갯수, 일반적으로 별도의 설정이 없다면 5개로 사용함
  
  // 터넥션 풀에서 특정 루트마다 관리할 수 있는 총 커넥션 개수 설정
  // defaultMaxPerRoute 설정을 덮어씀
  // 여기서는 http://10.192.10.111:8080 의 최대 커넥션 갯수는 10개로 설정
  HttpHost httpHost = new HttpHost("http", "10.192.10.111", 8080);
  manager.setMaxPerRoute(new HttpRoute(httpHost), 10);
  
  return manager;
}
```

`defaultMaxPerRoute()`, `maxPerRoute()` 에서 루트(Route)가 의미하는 것은 IP 주소와 포트의 조합이다.  
같은 IP 라도 포트가 다르면 다른 루트로 취급된다.

- `maxTotal()`
  - 커넥션 풀이 관리할 수 있는 커넥션 개수의 최대값
- `defaultMaxPerRoute()`
  - 루트 당 할당할 수 있는 커넥션 개수의 기본 최대값
  - 예를 들어 `defaultMaxPerRoute()` 가 5일 때 `maxTotal()` 이 100 이더라도 클라이언트가 연결하는 루트가 하나 뿐이라면 커넥션 풀의 최대 커넥션 개수는 5개를 넘을 수 없다.
- `maxPerRoute()`
  - 특정 루트에 커넥션 개수를 따로 설정하는 속성
  - `defaultMaxPerRoute()` 가 5 이더라도 이 설정을 이용하여 별도로 설정 가능

---

### 1.6.2. `keep-alive` 설정

**RestTemplate 의 커넥션 풀 설정 시 주의할 점**이 있다.

- 클라이언트는 REST-API 를 호출할 때 [HTTP/1.1](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/#1-http-%ED%94%84%EB%A1%9C%ED%86%A0%EC%BD%9C) 의 keep-alive 기능을 사용해야 함
- 서버는 keep-alive 기능을 지원해야 함
- keep-alive 를 사용할 때 서버는 graceful shutdown 기능을 지원해야 함

**HTTP/1.0 과 HTTP/1.1 의 가장 큰 차이점은 커넥션 유지 기능**이다.  
이러한 커넥션 유지 기능을 HTTP persistent connection 혹은 keep-alive 라고 한다.  

HTTP/1.0 은 REST-API 를 호출할 때 커넥션 생성 후 응답 메시지를 받으면 커넥션을 종료한다. 이후 다시 요청 시 이 과정을 반복한다.  
이것은 `SimpleClientHttpRequestFactory` 가 동작하는 방식과 일치한다.

HTTP/1.1 은 keep-alive 를 지원하기 때문에 한번 생성한 커넥션을 재사용할 수 있다.  
따라서 커넥션 종료 없이 다음 HTTP 요청을 같은 커넥션을 사용하여 전달한다.

클라이언트와 서버는 keep-alive 기능을 Connection 헤더의 `keep-alive` 와 `close` 를 사용하여 설정한다.  
Connection 헤더는 현재의 HTTP 통신이 완료되면 커넥션을 어떻게 처리할지 결정한다.

`keep-alive` 헤더값은 커넥션을 계속 유지하고, `close` 헤더값은 커넥션을 종료한다.

HTTP/1.1 버전에서 keep-alive 기능을 사용하려면 아래와 같이 Connection 헤더를 사용해야 한다.

```http
// HTTP 요청 메시지
GET /billing-codes HTTP/1.1   // HTTP 요청 메시지에 반드시 HTTP/1.1 버전임을 명시
Connection: keep-alive  // Connection 헤더로 클라이언트가 keep-alive 를 사용할 수 있음을 서버에 전달
ACCEPT: application/json

// HTTP 응답 메시지
HTTP/1.1 200 OK   // 응답 메시지도 HTTP/1.1 버전이므로 HTTP/1.1 프로토콜을 사용하여 응답함을 알 수 있음
Date: Fri, 10 Dec 2023 11:22:33 GMT
Connection: keep-alive  // Connection 헤더로 서버 또한 keep-alive 를 사용할 수 있음을 알려줌, 해당 커넥션을 종료해야 한다면 'Connection: close' 헤더를 응답함
Keep-Alive: timeout=30, max=100   // Keep-Alive 헤더는 서버가 커넥션의 타임아웃과 하나의 커넥션에서 사용할 수 있는 HTTP 요청 개수를 응답
```

클아이언트는 HTTP/1.1 버전과 `Connection: keep-alive` 헤더를 포함하여 커넥션 풀로 커넥션을 유지하면서 사용할 수 있다.  
하지만 서버에서 keep-alive 기능을 제공하지 못한다면 keep-alive 기능을 사용할 수 없다.

REST-API 서버 측에서는 아래와 같이 keep-alive 설정을 한다.

application.properties
```properties
# 스프링 부트에 포함된 임베디드 톰캣이 몇 개의 keep-alive 커넥션을 관리할지 결정, 디폴트 100
server.tomcat.max-keep-alive-requests=100
```

만일 keep-alive 를 사용하고 싶지 않다면 0 혹은 1로 설정한다.  
시스템 리소스가 허용하는 최대치까지 설정하고 싶다면 -1 로 설정한다.

---

### 1.6.3. `keep-alive` 사용 시 주의점

온프레미스 환경에서는 L4 혹은 L7 과 같은 로드 밸런서를 사용하여 HA 환경을 구성하고, AWS 같은 클라우드 환경에서는 ELB 같은 로드 밸런서를 사용한다.

여기서는 로드 밸런서를 사용하는 환경에서 keep-alive 를 사용할 때 발생할 수 있는 상황에 대해 설명한다.

로그 밸런서들은 클라이언트와 서버 그룹 사이에 위치하여 클라이언트 요청을 서버에 분배하여 전달하는 기능을 제공한다.  
클라이언트는 로드 밸런서에 설정된 가상의 IP 와 포트에 커넥션을 연결한 후 HTTP 요청을 전달하여 응답을 받는다.  
로드 밸런서의 IP 는 가상의 서비스 IP 이므로 VIP(Virtual IP) 라고 한다.

만일 서버 그룹에서 장애가 있는 서버를 제외하지 않고 바로 애플리케이션을 배포하면 클라이언트에 아래와 같은 에러가 전달된다.  
서버 애플리케이션이 종료하면서 클라이언트와 서버 사이에 있던 커넥션이 끊겨 서버 OS 가 아래와 같이 connection reset 을 클라이언트에 전달하기 때문이다.  
서버 애플리케이션 로그에서는 예외 로그를 남길 수 없으며, 클라이언트에서만 확인이 가능하다.

```shell
java.net.SocketException: Connection reset
```

**keep-alive 를 사용하는 환경에서 아래 순서로 서버를 배포하면 이와 같은 상황이 발생**한다.
- 클라이언트와 로드 밸런서 사이에 커넥션 생성
  - 클라이언트는 keep-alive 옵션을 사용하여 커넥션 풀을 생성하기 때문에 persistent connection 을 유지
  - 이 때 클라이언트와 로드 밸런서 사이에 커넥션을 커넥션 #1 이라고 하자
- 클라이언트가 요청한 메시지는 커넥션 #1 로 로드 밸런서에게 전달되고, 로드 밸런서는 서버 #1 로 사용자 요청을 전달
  - 이 때 로드 밸런서와 서버 사이의 커넥션을 커넥션 #2 라고 하자
- 로드 밸런서는 세션 테이블을 사용하여 커넥션 #1 과 커넥션 #2 를 매핑
- 클라이언트와 서버 사이에 통신이 끝나도 로드 밸런서에 설정된 세션 타임아웃값 동안 커넥션 #1 과 커넥션 #2 는 유지됨
  - 그래서 특정 시간 동안 커넥션 #1 로 들어온 사용자 요청은 계속해서 커넥션 #2 를 사용하여 서버 #1 로 전달됨
- 서버 #1 을 배포하려고 로드 밸런서의 서버 그룹에서 서버 #1 제외함
- 이 때 로드 밸런서의 세션 테이블에 저장된 커넥션 #1, 커넥션 #2 매핑값을 삭제하지 않았다면 커넥션 #1 로 들어오는 사용자 요청은 계속해서 커넥션 #2 를 이용하여 서버 #1 로 요청이 전달됨
- 서버 #1 에 새로운 애플리케이션을 배포했으므로 기존 애플리케이션에 연결된 커넥션 #2 는 더 이상 유효하지 않음
- 클라이언트는 네트워크 커넥션 에러 발생

이런 상황을 해결하려면 로드 밸런서의 세션 테이블을 정리하는 설정이 필요하다.  
또는 로드 밸런서의 세션 타임아웃만큼 서버가 기다렸다가 종료하는 방법을 사용하면 된다. 
즉, 서버 #1 을 점검 모드로 변경하고, `로드 밸런서의 상태 확인 주기 시간 + 세션 타임 아웃 시간` 만큼 기다린 후 서버를 종료하면 된다.  
그러면 로드 밸런서의 세션 테이블도 갱신되고 더 이상 기존 세션이 유지되지 않으므로 배포로 발생한 에러를 피할 수 있다.

---

# 2. `WebClient`

스프링 가이드 문서는 RestTemplate 대신 o.s.web.reactive.function.client 패키지의 `WebClient` 클래스를 사용하도록 권고한다.

> NOTE: As of 5.0 this class is in maintenance mode, with only minor requests for changes and bugs to be accepted going forward.  
> Please, consider using the org.springframework.web.reactive.client.WebClient which has a more modern API and supports sync, async, and streaming scenarios.
> 
> [RestTemplate 가이드 문서](https://docs.spring.io/spring-framework/docs/6.0.x/javadoc-api/org/springframework/web/client/RestTemplate.html)

하지만 일반적으로 스프링 MVC 프레임워크를 사용하는 애플리케이션에서는 RestTemplate 를 많이 사용한다.  
WebMVC 는 동기식 프레임워크이므로 RestTemplate 를 많이 사용하고, WebClient 는 비동기 논블로킹 프레임워크인 Spring WebFlux 에서 사용한다.

WebClient 를 사용하려면 reactive 라이브러리의 사용법을 익혀야 하는데 비동기 논블로킹 프로그래밍에 적합한 `Mono` 와 `Flux` 를 리턴하는 구조이기 때문이다.  
여기선 동기식 프레임워크인 WebMVC 프레임워크를 다루므로 reactive 라이브러리는 따로 설명하지 않고, WebMVC 프레임워크에서 WebClient 를 설정하는 방법과 간단한 사용 방법에 대해 알아본다.

WebClient 를 사용하려면 스프링 WebFlux 스타터 의존성이 필요하다.  
WebClient 클래스가 WebFlux 프레임워크에 포함되어 있기도 하지만, 의존성 내부에는 reactive 라이브러리와 비동기 프레임워크인 netty 가 포함되어 있기 때문이다.  
이 라이브러리들은 WebClient 를 사용하는데 필요하다.

pom.xml
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webflux</artifactId>
</dependency>
```

WebClient 클래스는 객체를 생성할 수 있는 static 팩토리 메서드를 제공한다.

WebClient 객체를 생성하는 3 가지 방법
```java
WebClient webClient1 = WebClient.create();
WebClient webClient2 = WebClient.create("http://127.0.0.1:8080");
WebClient webClient3 = WebClient.builder().build();
```

`builder()` 메서드는 WebClient.Builder 객체를 리턴하기 하는데, 이 Builder 객체를 사용하면 [빌더 패턴](https://inpa.tistory.com/entry/GOF-%F0%9F%92%A0-%EB%B9%8C%EB%8D%94Builder-%ED%8C%A8%ED%84%B4-%EB%81%9D%ED%8C%90%EC%99%95-%EC%A0%95%EB%A6%AC) 메서드로 WebClient 를 깔끔하게 생성할 수 있다.

아래는 WebClient 스프링 빈을 설정하는 자바 설정 클래스이다.  

/config/WebClientConfig.java
```java
package com.assu.study.chap09.config;

import io.netty.channel.ChannelOption;
import io.netty.handler.timeout.ReadTimeoutHandler;
import io.netty.handler.timeout.WriteTimeoutHandler;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.reactive.ClientHttpConnector;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

@Slf4j
@Component
public class WebClientConfig {
  @Bean
  public WebClient webClient() {
    // tcpConfiguration() 는 deprecated 됨
//    HttpClient httpClient = HttpClient.create()
//        .tcpConfiguration(tcpClient ->
//            tcpClient.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000) // 커넥션을 생성하는 최대 시간
//                .doOnConnected(conn ->
//                    conn.addHandlerLast(new ReadTimeoutHandler(10)) // 서버의 응답 메시지를 읽는데 걸리는 최대 시간 (s)
//                        .addHandlerLast(new WriteTimeoutHandler(10))  // 서버에 데이터를 전송할 때 걸리는 최대 시간 (s)
//                )
//        );
    HttpClient httpClient = HttpClient.create()
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000) // 커넥션을 생성하는 최대 시간
            .doOnConnected(conn ->
                    conn.addHandlerLast(new ReadTimeoutHandler(10))   // 서버의 응답 메시지를 읽는데 걸리는 최대 시간 (s)
                            .addHandlerLast(new WriteTimeoutHandler(10))  // 서버에 데이터를 전송할 때 걸리는 최대 시간 (s)
            );

    // 생성한 HttpClient 객체를 하용하여 ClientHttpConnector 객체 생성
    // wiretap() 메서드를 사용하여 요청 메시지와 응답 메시지 전체를 로깅할 수 있음
    // 단, 로그 설정 파일에 logging.level.reactor.netty.http.client=DEBUG 레벨로 설정해야 함
    ClientHttpConnector connector = new ReactorClientHttpConnector(httpClient.wiretap(true));

    return WebClient.builder()
            .baseUrl("http://localhost:8080") // REST-API 의 기본 URL
            .clientConnector(connector)
            .defaultHeaders(httpHeaders -> {
              httpHeaders.add(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE);
              httpHeaders.add(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE);
            })
            .build();
  }
}
```


> **`@Component` 와 `@Configuration` 차이**  
> 
> `@Component` 와 `@Component` 는 아래와 같은 차이가 있음  
> `@Configuration` 의 선언부를 보면 `@Component` 가 정의되어 있으며, `@Component` 는 개발자가 작성한 클래스를  빈으로 등록하고자 할 때 사용함.
> 
> **`@Componenet`**  
> 개발자가 직접 작성한 클래스를 빈으로 등록하고자 할 경우 사용  
> `@Controller`, `@Service`, `@Repository` 등의 어노테이션에서 상속  
> 
> **`@Configuration`**  
> 외부라이브러리 또는 내장 클래스를 빈으로 등록하고자 할 경우 사용(개발자가 직접 제어가 불가능한 클래스)  
> 1개 이상의 `@Bean` 을 제공하는 클래스의 경우 반드시 `@Configuration`을 사용  
> 즉, 해당 클래스에서 한 개 이상의 빈을 생성하고 있을때 선언해주어야 함

---

WebClient 는 불변 객체(immutable) 이므로 여러 스레드가 동시에 접근해도 안전하다.  
불변 객체는 생성된 이후 내부 속성값이 변하지 않기 때문에 멀티 스레드가 동시에 불변 객체에 접근하더라도 멀티 스레드 환경에 안전하다.  
따라서 WebClient 도 싱글턴 스프링 빈으로 정의하여 필요한 곳에 주입하여 사용하면 된다.

주입받은 WebClient 객체에 추가 설정이 필요하다면 WebClient 의 `mutate()` 메서드를 사용하면 된다.  
`mutate()` 는 WebClient 를 재설정할 수 있는 WebClient.Builder 객체를 리턴한다.  
WebClient.Builder 객체를 리턴하더라도 기존에 설정된 WebClient 설정값은 그대로 유지하는 특징이 있다.  
기존 설정에 새로운 설정을 추가하거나 혹은 재설정할 수 있다.

아래는 WebClient 를 사용하여 REST-API 를 호출하는 예시이다.

/adapter/WebClientBillingAdapter.java
```java
package com.assu.study.chap09.adapter;

import com.assu.study.chap09.controller.ApiResponse;
import com.assu.study.chap09.controller.CreateCodeRequest;
import com.assu.study.chap09.controller.CreateCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.util.UriComponentsBuilder;
import reactor.core.publisher.Mono;

import java.net.URI;
import java.util.List;

@Slf4j
@Component
public class WebClientBillingAdapter {
  private static final ParameterizedTypeReference<ApiResponse<CreateCodeResponse>> TYPE_REFERENCE;

  static {
    TYPE_REFERENCE = new ParameterizedTypeReference<>() {
    };
  }

  private final WebClient webClient;

  public WebClientBillingAdapter(WebClient webClient) {
    this.webClient = webClient;
  }

  public CreateCodeResponse createWithWebClient(List<Long> hotelIds) {
    URI uri = UriComponentsBuilder.fromPath("/billing-codes")
        .scheme("http").host("127.0.0.1").port(8080)
        .build(false).encode().toUri();

    CreateCodeRequest request = new CreateCodeRequest(1, hotelIds);

    return webClient.mutate().build()   // mutate() 메서드로 WebClient.Builder 를 다시 사용할 수 있음을 보여줌, 설정 후 build() 메서드를 다시 호출하면 다시 WebClient 객체 리턴받음
        .method(HttpMethod.POST).uri(uri)   // 기존에 WebClientConfig 에서 설정한 baseUrl() 설정이 있더라도 덮어씀
        .bodyValue(request) // HTTP 요청 메시지의 바디 부분 설정
        .retrieve()   // 서버의 REST-API 실행
        .onStatus(httpStatus -> HttpStatus.OK != httpStatus,  // HTTP 의 상태 코드를 이용하여 에러 처리
            response -> Mono.error(new RuntimeException("Error from Billing. " + response.statusCode().value())))
        .bodyToMono(TYPE_REFERENCE) // ParameterizedTypeReference 상수를 사용하여 바디를 Mono 로 응답
        .flux().toStream()    // 리턴받은 Mono 를 Flux 로 변환한 후 다시 Stream 객체로 변환
        .findFirst()
        .map(ApiResponse::getData)
        .orElseThrow(() -> new RuntimeException("Empty response"));
  }
}
```

/Chap09Application2.java
```java
package com.assu.study.chap09;

import com.assu.study.chap09.adapter.WebClientBillingAdapter;
import com.assu.study.chap09.controller.CreateCodeResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.util.List;

@Slf4j
@SpringBootApplication
public class Chap09Application2 {

  public static void main(String[] args) {
    ConfigurableApplicationContext ctx = SpringApplication.run(Chap09Application2.class, args);

    WebClientBillingAdapter adapter = ctx.getBean(WebClientBillingAdapter.class);
    CreateCodeResponse codeResponse = adapter.createWithWebClient(List.of(19000L, 18000L, 17000L));

    // Result : CreateCodeResponse(codes=[19000, 18000, 17000])
    log.info("Result : {}", codeResponse);
  }
}
```

```shell
Result : CreateCodeResponse(codes=[19000, 18000, 17000])
```

위에서는 `onStatus()` 메서드를 사용하여 200 OK HTTP 상태 코드만 성공처리했다.  
`onStatus()` 메서드를 사용하지 않으면 WebClient 의 기본 설정을 따른다.  
WebClient 의 기본 설정은 HTTP 상태 코드가 4XX 이상이라면 모두 에러로 처리한다. 이 때 WebClientResponseException 이 발생한다.  

WebClient 에서 HTTP 통신을 실행하는 메서드는 `retrieve()` 와 `exchange()` 가 있다.

- `retrieve()`
  - HTTP 응답 메시지의 바디 부분을 바로 가져옴
  - 일반적인 용도로 HTTP 통신을 할때는 `retrieve()` 메서드를 사용하도록 WebClient 의 Javadoc 문서에서 제안함
- `exchange()`
  - HTTP 응답 메시지의 전체를 가져오는 ClientResponse 객체 참조 가능
  - 따라서 HTTP 상태 코드, 헤더, 바디 부분을 모두 참조할 수 있는 장점이 있음

---

WebClient 는 비동기 논블로킹 프레임워크에서 HTTP 통신을 하는데 사용하는 클래스로, 배압 기능을 제공하는 리액티브 스트림을 사용할 수 있다.

일반적인 서버-클라이언트 모델에서 서버가 응답하는 메시지에 한 개 이상의 객체가 리스트 형태로 있을 경우 클라이언트는 서버가 응답하는 객체 갯수만큼 데이터를 처리한다.  
배압은 클라이언트가 처리할 수 있는 객체 갯수를 서버에 요청하고, 서버는 갯수에 맞게 응답한다.  
서버-클라이언트 모델과 달리 클라이언트가 처리량을 조절해서 배압(back-pressure) 이라고 한다.  

리액티브 스트림의 핵심은 `Mono` 와 `Flux` 이다. 이들을 사용하면 배압을 사용할 수 있기 때문이다.  
WebClient 의 `retrieve()` 나 `exchange()` 를 사용하면 `Mono` 와 `Flux` 를 사용할 수 잇다.

스프링 MVC 프레임워크는 `Mono` 와 `Flux` 를 사용하여 리액티브 스트림을 사용할 수 없다.  
그래서 일련의 과정을 거쳐서 스프링 MVC 에서 사용할 수 있는 객체로 변환해야 한다.  
위 예시에서 사용한 `bodyToMono()` 는 `Mono` 를 리턴하고, 이를 다시 `flux()` 메서드를 사용하여 `Flux` 로 변환한다.  
`Flux` 는 `toStream()` 메서드를 제공하기 때문에 Java8 의 스트림 객체를 얻을 수 있다.


---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [RestTemplate 가이드 문서](https://docs.spring.io/spring-framework/docs/6.0.x/javadoc-api/org/springframework/web/client/RestTemplate.html)
* [빌더(Builder) 패턴 - 완벽 마스터하기](https://inpa.tistory.com/entry/GOF-%F0%9F%92%A0-%EB%B9%8C%EB%8D%94Builder-%ED%8C%A8%ED%84%B4-%EB%81%9D%ED%8C%90%EC%99%95-%EC%A0%95%EB%A6%AC)
* [`@Component`와 `@Configuration`](https://velog.io/@albaneo0724/Spring-Component%EC%99%80-Configuration%EC%9D%98-%EC%B0%A8%EC%9D%B4)