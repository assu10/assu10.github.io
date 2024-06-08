---
layout: post
title:  "Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API"
date:   2023-05-13
categories: dev
tags: springboot web msa http http-status-code rest-api spring-web-mvc 
---

이 포스트에서는 Spring 웹 MVC 프레임워크 내부 동작과 프레임워크에서 제공하는 컴포넌트 Spring bean 들에 대해 알아본다.
이후 간단한 REST-API 애플리케이션을 만들어본다.

- HTTP 프로토콜
- DispatcherServlet 을 포함한 Spring MVC 프레임워크 내부 구조
- REST-API 애플리케이션 구축

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. HTTP 프로토콜](#1-http-프로토콜)
  * [비연결성](#비연결성)
  * [무상태](#무상태)
  * [1.1. HTTP 상태 코드](#11-http-상태-코드)
* [2. Spring 웹 MVC 프레임워크](#2-spring-웹-mvc-프레임워크)
  * [2.1. DispatcherServlet](#21-dispatcherservlet)
  * [2.2. 서블릿 스택과 리액티브 스택](#22-서블릿-스택과-리액티브-스택)
  * [2.3. Spring boot 설정](#23-spring-boot-설정)
* [3. REST-API 애플리케이션 구축](#3-rest-api-애플리케이션-구축)
  * [3.1. `@ResponseBody`, `HttpMessageConverter`](#31-responsebody-httpmessageconverter)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap04

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

  <artifactId>chap04</artifactId>

</project>
```

---

# 1. HTTP 프로토콜

```http
// request line
GET /test.html HTTP/1.1

// header
Host: www.testme.com
Accept: text/html // 클라이언트에서 처리할 수 있는 콘텐츠 타임을 서버에 알려줌
```

HTTP Response 메시지

```http
// status line
HTTP 1.1 200 OK

// header
Content-type: text/html // body 에 포함된 데이터가 어떤 종류의 컨텐츠인지 클라이언트에 알려줌
Content-length: 12345

// message body
<html>
...
</html>
```

---

HTTP 버전은 아래와 같다.
- HTTP/1.0
  - 기본적으로 사용되는 버전
- HTTP/1.1
  - keep-alive 와 파이프 라이닝 기능 제공, chunk 응답 제공
- HTTP/2.0
  - 구글이 만든 SPDY 프로토콜 채용
  - 요청과 응답에 멀티 플렉싱 기능 제공

HTTP 특징은 비연결성, 무상태 두 가지가 있다.

> HTTP/1.1 의 keep-alive 기능에 대한 좀 더 상세한 내용은 [1.6.2. `keep-alive` 설정](https://assu10.github.io/dev/2023/09/23/springboot-rest-api-request/#162-keep-alive-%EC%84%A4%EC%A0%95) 를 참고하세요.

---

## 비연결성

HTTP 프로토콜이 서버와 클라이언트 사이에 커넥션을 유지할 필요 없이 데이터를 송수신할 수 있는 것을 말한다.  

HTTP 프로토콜은 TCP 를 통해 데이터를 전송하기 때문에 서버와 클라이언트 사이에 커넥션이 필요한데 이 TCP 커넥션을 생성하려면 3-way-handshake 과정을 거쳐야 한다.
그리고 이 3-way-handshake 는 시간과 리소스가 많이 사용되는 과정이다.

이러한 단점을 보완하기 위해 커넥션 맺는 비용을 줄이고자 일정 시간 커넥션을 유지하는 keep-alive 스펙이 HTTP/1.1 에 추가되었지만 기본적으로 클라이언트가 서버와 통신하기 위해선
매번 새로운 커넥션을 맺어야 한다.

커넥션이 유지되는 프로토콜이라면 클라이언트의 모든 요청이 한 서버로 전송되는데 이 때 이 서버가 모두 처리해야 하는 상황이 발생한다. 즉, 서비스에 포함된 모든 서버가 균등한 양의 일을 처리하는 것이 아니라
특정 서버에 부하가 집중될 수 있다. 
하지만 HTTP 프로토콜의 비연결성 특징 덕분에 메시지 전송 시 매번 커넥션을 맺으므로 L4 or L7 과 같은 로드 밸런서가 있다면 모든 서버가 균등하게 요청을 처리할 수 있으며, 쉽게 scale-in/out 할 수 있다.

---

## 무상태

HTTP 프로토콜은 커넥션을 유지하지 않기 때문에 클라이언트가 서버에 여러 번 요청해도 각 요청이 독립적으로 처리된다.

그래서 서버 사이에 데이터를 공유하지 않아도 된다는 장점이 있지만 이전 상태를 기억해야 하는 인가, 인증의 경우 문제가 될 수 있다.
HTTP 프로토콜은 이러한 문제 해결을 위해 쿠키, 세션에 대한 스펙을 제공한다.

---

## 1.1. HTTP 상태 코드

HTTP 응답 상태를 크게 5가지로 구분한다.

- `1XX`
  - 임시 응답을 의미
  - 클라이언트의 요청은 성공적으로 받았으며, 서버의 프로세스는 계속해서 작업
  - 보통 현 상태의 정보를 응답하는데 사용
- `2XX`
  - 성공을 의미
  - 클라이언트의 요청도 성공적으로 받았으며, 서버의 프로세스도 정상적으로 처리함
  - 200 OK, 201 Created (데이터를 성공적으로 생성), 202 Accepted 가 많이 사용됨
- `3XX`
  - 클라이언트 요청을 완전히 처리하는데 추가적인 작업이 필요함을 의미
  - 일반적을로 클라이언트가 요청한 리소스가 다른 위치로 옮겨져서 클라이언트가 새로운 리소스를 다시 요청해야 하는 경우
  - 대표적으로 302 Found 가 있으며, 이 때 서버는 새로운 URL 경로를 포함하는 Location 헤더를 함께 응답하고, 클라이언트는 이 헤더를 파싱하여 새로운 URL 로 재요청 (=리다이렉션)  
    (클라이언트가 이 작업을 처리함)
- `4XX`
  - 클라이언트의 요청한 메시지에 에러가 있음을 의미
  - 400 Bad Request (메시지 문법 오류), 401 Unauthorized/403 Forbidden (인증/인가되지 않은 리소스에 요청), 404 Not Found 가 많이 사용됨 
- `5XX`
  - 클라이언트의 요청을 처리하는 도중 서버가 정상 처리하지 못함을 의미
  - 500 Internal Server Error 가 대표적임

---

# 2. Spring 웹 MVC 프레임워크

`Servlet` 은 HTTP 프로토콜을 사용하여 데이터를 주고받는 서버용 프로그래밍 스펙을 말한다.

Servlet 은 javax.servlet.Servlet 인터페이스 형태로 Java API 에서 제공하여, 이를 구현한 클래스를 `Servlet` or `Servlet 애플리케이션` 이라고 한다.

Servlet 애플리케이션들을 관리하는 서버를 `Servlet 컨테이너` or `WAS` 라고 한다.

J2EE 의 Servlet 스펙을 구현한 WAS 는 Tomcat, Jetty, Undertow 등이 있다.

J2EE 스펙을 사용하여 웹 애플리케이션 개발 시 Servlet 스펙을 따라야하기 때문에 위 개념 정도는 알아두는 것이 좋을 듯 하다.

- `Servlet 3.0`
  - asynchronous Servlet 기능 지원
- `Servlet 3.1`
  - non-blocking 방식의 IO 기능 지원
- `Servlet 4.0`
  - HTTP 2.0 기반의 기능 지원

---

HTTP 요청과 응답의 처리는 Servlet 애플리케이션은 web.xml 설정 파일에 Servlet 정보를 작성하고, Tomcat 이 실행할 때 이를 읽어서 Servlet 애플리케이션을 로딩하는 방식이다.  

```text
브라우저는 HTTP 프로토콜 스펙에 따라 요청 → 이를 Servlet 컨테이너 역할을 하는 WAS 의 한 종류인 Tomcat 이 처리 → Tomcat 은 HTTP 요청에 적절한 Servlet 애플리케이션 실행
```

Servlet 애플리케이션 내부에선 HttpServletRequest, HttpServletResponse 객체를 이용하여 요청과 응답을 처리한다.


---

## 2.1. DispatcherServlet

DispatcherServlet 은 Front Controller Pattern 으로 디자인되어 있다. 따라서 모든 요청과 응답은 DispatcherServlet 에서 처리된다.

> **Front Controller Pattern**    
> 가장 앞 쪽에서 모든 요청과 응답을 처리하는 패턴, 웹 애플리케이션의 전체 흐름 조정  
> 모든 요청과 응답에 대해 공통 기능을 일괄적으로 쉽게 추가 가능하기 때문에 인증, 인가도 쉽게 구현 가능  
> Front Controller Pattern 덕분에 인증, 인가를 위한 Spring Security 프레임워크도 애플리케이션에 쉽게 적용 가능

![Spring MVC](/assets/img/dev/2023/0513/mvc.png)

① 모든 HTTP 요청은 DispatcherServlet 이 받아서 처리  
② DispatcherServlet 은 요청 메시지의 request line, header 파악하여 어떤 컨트롤러의 어떤 메서드로 전달할지 HandlerMapping 컴포넌트의 메서드를 사용하여 확인  
③ DispatcherServlet 은 위에서 확인한 클래스에 HTTP 요청 메시지를 전달 역할을 하는 HandlerAdapter 에 HTTP 요청 메시지 전달  
④ HandlerAdapter 는 컨트롤러에 요청 전달  
⑤ 비즈니스 로직 수행  
⑥ HandlerAdapter 는 처리할 뷰와 뷰에 매핑할 데이터를 ModelAndView 객체에 포함하여 DispatcherServlet 에 전달  
⑦ DispatcherServlet 은 처리할 뷰 정보를 ViewResolver 에 확인  
⑧ DispatcherServlet 은 View 에 데이터를 전달하고, View 는 데이터를 HTML 등의 포맷으로 변환 후 DispatcherServlet 으로 전달  
⑨ DispatcherServlet 은 최종적으로 변환된 데이터를 클라이언트에 전달

- `HandlerMapping`
  - servlet.HandlerMapping 인터페이스를 구현한 컴포넌트
  - HTTP 요청 메시지를 추상화한 HttpServletRequest 객체를 받아 요청을 처리하는 핸들러 객체를 조회하는 getHandler() 메서드 제공
  - RequestMappingHandlerMapping 구현체는 @RequestMapping 애너테이션의 속성 정보 로딩 가능
- `HandlerAdapter`
  - servlet.HandlerAdapter 인터페이스를 구현한 컴포넌트
  - 사용자의 요청과 응답을 추상화한 HttpServletRequest, HttpServletResponse 객체를 컨트롤러 클래스의 메서드에 전달하는 Object adapter 역할
- `ModelAndView` 
  - 컨트롤러 클래스에서 처리한 결과를 어떤 뷰에서 처리할지 결정하고 뷰에 전달할 데이터를 포함하는 클래스
- `ViewResolver`
  - 문자열 기반의 view 이름을 실제 View 구현체로 변경
  - 다양한 템플릿 뷰 엔진이 있으며, 적합한 ViewResolver 구현체를 Spring bean 으로 정의하면 됨
  - 예를 들어 JSP 는 InternalResourceViewResolver, Velocity 템플릿 엔진을 사용한다면 VelocityViewResolver, Freemarker 템플릿 엔진을 사용한다면 FreemarkerViewResolver 구현체를 Spring bean 으로 정의

---

## 2.2. 서블릿 스택과 리액티브 스택

Spring 웹 MVC 프레임워크는 5.0 버전부터 두 가지 방식으로 설정 가능하다.

- `서블릿 스택`
  - 전통적인 Servlet 모델
  - 동기식 프로그래밍 (=동기식 프로그래밍으로 애플리케이션 개발 시 서블릿 스택으로 구성)
  - 하나의 기능은 하나의 스레드에서만 동작하므로 ThreadLocal 같은 클래스 사용이 가능하고, 비교적 간단하게 프로그래밍 가능
- `리액티브 스택`
  - React 모델 적용
  - 비동기식 프로그래밍 (=비동기식 프로그래밍으로 애플리케이션 개발 시 리액티브 스택으로 구성)
  - 이벤트 루프 모델을 기반으로 비동기식 프로그래밍을 쉽게 할 수 있는 react 라이브러리 포함
  - 서블릿 스택으로 개발된 애플리케이션보다 더 높은 처리량 가능 (특정 기능의 종료를 기다리지 않고 바로 다른 기능을 실행하므로)
  - 시스템 자원을 효율적으로 사용 가능
  - 비동기 프로그래밍은 하나의 기능을 여러 이벤트로 분리하고, 분리된 이벤트들은 각각 다른 스레드에서 실행될 수 있음 (=하나의 기능이 여러 스레드에서 실행됨)

서블릿 스택에 대해 좀 더 알아보자.

서블릿 스택에서 WAS 는 스레드를 효율적으로 관리하기 위해 스레드 풀을 포함한다. 스레드 풀은 WAS 가 기동될 때 초기화되고 종료될 때 정리된다. 사용자 요청마다 스레드를 생셩하기엔 생성 비용이 비싸므로
미리 만들어진 스레드를 재사용하는 스레드 풀로 사용자 요청을 처리한다.

서블릿 스택에서 사용자 요청과 스레드 생명주기가 일치하므로 멀티 스레드 프로그래밍 작업이 필요없다. 

---

## 2.3. Spring boot 설정

Spring boot 에 자동 설정된 임베디드 WAS 는 Tomcat, Jetty, Undertow 가 있다.

Spring boot 로 웹 애플리케이션 설정 시 아래 두 가지 작업만 하면 바로 서버를 띄울 수 있다.

- pom.xml 에 spring-boot-starter-web 의존성 추가
  - 이 작업만으로 웹 애플리케이션을 위한 자동 설정 진행
- application.properties 속성 파일에 개발자가 필요한 설정 기입

---

pom.xml
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
```

`spring-boot-starter-web` 의존성을 추가하면 `spring-boot-autoconfigure` 프로젝트에 포함된 WebMvcAutoConfiguration.java 가 실행되어 자동으로 Spring 웹 애플리케이션의 주요 컴포넌트를 설정한다.

WebMvcAutoConfiguration 클래스는 EnableWebMvcConfiguration 과 WebMvcAutoConfigurationAdapter 클래스를 포함한다.

- EnableWebMvcConfiguration
  - RequestMappingHandler Mapping, RequestMappingHandlerAdapter 컴포넌트 생성 후 설정
- WebMvcAutoConfigurationAdapter
  - WebMvcConfigurer 인터페이스 구현하는 구조
  - WebMvcConfigurer 는 HttpMessageConverter 들을 설정할 수 있는 configureMessageConverters() 와 extendMessageConverters() 메서드 제공
  - HttpMessageConverter 객체는 요청/응답 객체를 특정 형태로 변환하는 기능을 제공 (예- java 객체를 JSON 객체로) 하기 때문에 API 서버 작성 시 설정하는 경우가 종종 있음

---

application.properties
```properties
server.port=18080
# 서버와 클라이언트가 커넥션을 맺고, 정해진 시간동안 서버가 응답하지 않으면 해당 커넥션 해제
# s 를 쓰지 않으면 ms 단위임
server.tomcat.connection-timeout=30s

# 톰캣 서버의 스레드풀 최댓값과 최솟값
# 부하가 높으면 최댓값까지 스레드가 생성되고, 부하가 낮으면 최솟값까지 스레드가 줄어듦
# 런타임 도중에 필요한 스레드를 생성하는 시간과 리소스 비용이 높기 때문에 주로 두 값을 같게 설정함
server.tomcat.threads.max=100
server.tomcat.threads.min-spare=100

# 톰캣 서버의 액세스 로그 사용 여부 (default false)
server.tomcat.accesslog.enabled=true
server.tomcat.accesslog.suffix=log
server.tomcat.accesslog.prefix=access_log
server.tomcat.accesslog.rename-on-rotate=true
```

---

# 3. REST-API 애플리케이션 구축

> REST-API 에 대한 내용은 [REST-API](https://assu10.github.io/dev/2023/05/13/rest-api-basic/) 를 참고하세요.

> REST-API 애플리케이션 구축 시 `@Controller` 보다는 `@Controller` 와 `@ResponseBody` 를 동시에 제공하는 `@RestController` 를 주로 사용하는데
> `@RestController` 사용법은 [Spring Boot - REST-API with Spring MVC (1): GET/DELETE 메서드 매핑, 응답 메시지 처리(마셜링)](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2) 의
> _1.2. Controller 구현: `@PathVariable`, `@RequestParam`, `@DateTimeFormat`_ 을 참고하세요.

/controller/ApiController.java
```java
package com.assu.study.chap04.controller;

import com.assu.study.chap04.domain.Hotel;
import com.assu.study.chap04.domain.HotelSearchService;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller // DispatcherServlet 이 전달하는 사용자 요청을 받는 클래스
public class ApiController {
  private HotelSearchService hotelSearchService;

  public ApiController(HotelSearchService hotelSearchService) {
    this.hotelSearchService = hotelSearchService;
  }

  @ResponseBody // ResponseEntity<Hotel> 객체를 JSON 형식으로 변경
  @RequestMapping(method = RequestMethod.GET, path = "/hotels/{hotelId}")
  public ResponseEntity<Hotel> getHotelById(@PathVariable("hotelId") Long hotelId) {
    Hotel hotel = hotelSearchService.getHotelById(hotelId);
    return ResponseEntity.ok(hotel);
  }
}
```

/domain/HotelSearchService.java
```java
package com.assu.study.chap04.domain;

import org.springframework.stereotype.Service;

@Service
public class HotelSearchService {
  public Hotel getHotelById(Long hotelId) {
    return new Hotel(hotelId, "ASSU Hotel", "Seoul", 100);
  }
}
```

/domain/Hotel.java
```java
package com.assu.study.chap04.domain;

import lombok.Getter;

import java.util.Objects;

@Getter
public class Hotel {
  private Long hotelId;
  private String name;
  private String address;
  private Integer roomCount;

  public Hotel(Long hotelId, String name, String address, Integer roomCount) {
    if (Objects.isNull(hotelId) || Objects.isNull(name) || Objects.isNull(address)) {
      throw new IllegalArgumentException("hotel parameter is null");
    }
    if (Objects.isNull(roomCount) || roomCount <= 0) {
      throw new IllegalArgumentException("invalid room count");
    }
    this.hotelId = hotelId;
    this.name = name;
    this.address = address;
    this.roomCount = roomCount;
  }
}
```

```shell
$ curl -w "%{http_code}" --location 'http://localhost:18080/hotels/1' | jq
{
  "hotelId": 1,
  "name": "ASSU Hotel",
  "address": "Seoul",
  "roomCount": 100
}
200
```

```shell
$ curl -I -w "%{http_code}" --location 'http://localhost:18080/hotels/1'
HTTP/1.1 200
Content-Type: application/json
Transfer-Encoding: chunked
Date: Fri, 16 Jun 2023 07:49:36 GMT

200%
```

`return ResponseEntity.ok(hotel)` static 메서드는 200 OK 상태 코드값을 설정하여 ResponseEntity 객체를 생성한다.

200 OK 외의 다른 상태 코드 응답 시엔 아래를 참고하면 된다.
```java
return ResponseEntity.accepted() // 202 Accepted
return ResponseEntity.notFound() // 404 Not Found
return ResponseEntity.internalServerError() // 500 Internal Server Error
return ResponseEntity.badRequest() // 400 Bad Request

// HttpStatus 열거형 사용
return ResponseEntity.status(HttpStatus.OK).body(hotel);
```

---

## 3.1. `@ResponseBody`, `HttpMessageConverter`

> REST-API 애플리케이션 구축 시 `@Controller` 보다는 `@Controller` 와 `@ResponseBody` 를 동시에 제공하는 `@RestController` 를 주로 사용하는데
> `@RestController` 사용법은 [Spring Boot - REST-API with Spring MVC (1): GET/DELETE 메서드 매핑, 응답 메시지 처리(마셜링)](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2) 의
> _1.2. Controller 구현: `@PathVariable`, `@RequestParam`, `@DateTimeFormat`_ 을 참고하세요.

`@ResponseBody` 애너테이션이 선언된 메서드가 리턴하는 객체는 Spring 프레임워크에 설정된 메시지 컨버터(HttpMessageConverter) 중 적합한 메시지 컨버터가 JSON 메시지로 마셜링한다.
또한 `@ResponseBody` 가 선언되어 있으면 Spring MVC 의 View 를 사용하지 않는다. 대신 Controller 의 핸들러 메서드가 리턴하는 객체는 Spring MVC 프레임워크 내부에 설정된
HttpMessageConverter 중 적절한 것을 골라 마셜링하고, 마셜링된 JSON 객체가 클라이언트에 전달된다.

> **마셜링(Marshalling)**  
> 객체가 JSON 문자열로 변환되는 것, 그 뱐대는 언마셜링이라고 함

`@ResponseBody` 애너테이션은 메서드 뿐 아니라 클래스 선언부에도 사용 가능한데 그러면 클래스 내부에 정의된 public 메서드 모두 `@ResponseBody` 의 영향을 받는다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [REST-API: Blog](https://assu10.github.io/dev/2023/05/13/rest-api-basic/)
* [MultiValueMap은 무엇일까?](https://velog.io/@nimoh/Spring-MultiValueMap%EC%9D%80-%EB%AC%B4%EC%97%87%EC%9D%BC%EA%B9%8C)