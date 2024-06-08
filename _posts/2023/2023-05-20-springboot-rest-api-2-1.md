---
layout: post
title:  "Spring Boot - REST-API with Spring MVC (2): POST/PUT 메서드 매핑, Pageable/Sort, 검증, 예외처리, 미디어 콘텐츠 다운로드"
date:   2023-05-20
categories: dev
tags: springboot msa rest-api spring-web-mvc controller-advice response-entity pageable post-mapping put-mapping
---

이 포스트에서는 아래 내용에 대해 알아본다. 

- 사용자 요청 메시지 검증
- 예외 처리 기능 설정, 에러 메시지 응답
- 클라이언트에 파일 전송

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. POST, PUT 메서드 매핑: `@RequestBody`, `ResponseEntity`](#1-post-put-메서드-매핑-requestbody-responseentity)
* [2. Pageable, Sort 클래스](#2-pageable-sort-클래스)
  * [2.1. Pagination 과 Sort: Pageable 클래스](#21-pagination-과-sort-pageable-클래스)
  * [2.2. Pageable 자동 설정](#22-pageable-자동-설정)
* [3. 검증](#3-검증)
  * [3.1. JSR-303 을 이용한 데이터 검증](#31-jsr-303-을-이용한-데이터-검증)
  * [3.2. `@Valid`](#32-valid)
  * [3.3. Validator 인터페이스와 `@InitBinder` 를 이용한 검증](#33-validator-인터페이스와-initbinder-를-이용한-검증)
* [4. 예외 처리](#4-예외-처리)
  * [4.1. `@ControllerAdvice`, `@ExceptionHandler`, `@RestControllerAdvice`](#41-controlleradvice-exceptionhandler-restcontrolleradvice)
* [5. 미디어 콘텐츠 다운로드](#5-미디어-콘텐츠-다운로드)
  * [5.1. HttpMessageConverter 를 사용하여 파일 byte 정보 조회](#51-httpmessageconverter-를-사용하여-파일-byte-정보-조회)
  * [5.2. HttpServletResponse 를 사용하여 파일 다운로드](#52-httpservletresponse-를-사용하여-파일-다운로드)
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
- Artifact: chap05

![Spring Initializer](/assets/img/dev/2023/0514/init.png)

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

  <artifactId>chap05</artifactId>

  <dependencies>
    <!-- Pageable 관련 -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <!-- https://mvnrepository.com/artifact/mysql/mysql-connector-java -->
    <dependency>
      <groupId>mysql</groupId>
      <artifactId>mysql-connector-java</artifactId>
      <version>8.0.33</version>
    </dependency>
    <!-- https://mvnrepository.com/artifact/org.hsqldb/hsqldb -->
    <dependency>
      <groupId>org.hsqldb</groupId>
      <artifactId>hsqldb</artifactId>
      <version>2.7.2</version>
    </dependency>
    <!-- https://mvnrepository.com/artifact/org.hibernate/hibernate-validator -->
    <dependency>
      <groupId>org.hibernate</groupId>
      <artifactId>hibernate-validator</artifactId>
      <version>8.0.0.Final</version>
    </dependency>
  </dependencies>
</project>
```

---

# 1. POST, PUT 메서드 매핑: `@RequestBody`, `ResponseEntity`

아래는 객실 정보를 생성하는 REST-API 설계이다.

```http
# Request
POST /hotels/{hotelId}/rooms

{
  "roomNumber": "Assu-123",
  "roomType":"double",
  "originalPrice": "100.00"
}

# Response
[HEADER] X-CREATED-AT: yyyy-MM-dd'T'HH:mm:ssXXX
{
  "id": "123" // 객실 고유 아이디
}
```

/controller/HotelController.java
```java
package com.assu.study.chap05.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

@RestController // @Controller 와 @ResponseBody 애너테이션의 기능을 동시에 제공
                // HomeRoomController 가 리턴하는 객체들은 JSON 메시지 형태로 마셜링됨
public class HotelRoomController {

  private static final String HEADER_CREATED_AT = "X-CREATED-AT";
  private final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssXXX");


  @PostMapping(path = "/hotels/{hotelId}/rooms")
  public ResponseEntity<HotelRoomIdResponse> createHotelRoom(
          @PathVariable Long hotelId,
          @RequestBody HotelRoomRequest hotelRoomRequest  // @RequestBody 는 클라이언트에서 전송한 요청 메시지의 body 를 언마셜링하여 자바 객체인 HotelRoomRequest 로 변환
  ) {
    System.out.println(hotelRoomRequest.toString());

    // ResponseEntity 의 HTTP header 는 MultiValueMap 객체를 사용하여 설정
    // add() 메서드를 사용하여 HTTP 헤더 추가 가능
    MultiValueMap<String, String> headers = new LinkedMultiValueMap<>();
    headers.add(HEADER_CREATED_AT, DATE_FORMATTER.format(ZonedDateTime.now()));
    HotelRoomIdResponse body = HotelRoomIdResponse.from(1_002_003L);

    return new ResponseEntity<>(body, headers, HttpStatus.OK);
  }
}
```

- `@RequestBody`
  - 사용자 요청 메시지 body 에 포함된 JSON 메시지를 인자의 클래스 타입 객체로 언마셜링하여 핸들러 메서드의 인자로 매핑함
  - [`@ResponseBody`](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/#3-rest-api-%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98-%EA%B5%AC%EC%B6%95) 처럼 Spring MVC 프레임워크의 HttpMessageConverter 객체 중 하나를 선택하여 언마셜링함

REST-API 는 JSON 형식을 사용하므로 **클라이언트가 POST, PUT 메서드로 요청할 때는 'Content-Type: application/json' 헤더를 반드시 포함**해야 한다.  
만일 포함하지 않으면 적절한 HttpMessageConverter 를 찾을 수 없어 에러가 발생한다.

- `ResponseEntity 클래스`
  - REST-API 개발 시 설계에 맞추어 응답 메시지의 status code, header, body message 를 설정해야 하는데 이 때 ResponseEntity 클래스를 사용하면 쉽게 설정이 가능


/controller/HotelRequest.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.HotelRoomType;
import lombok.Getter;
import lombok.ToString;

import java.math.BigDecimal;

// DTO
@Getter
@ToString
public class HotelRoomRequest {
  private String roomNumber;
  private HotelRoomType roomType;
  private BigDecimal originalPrice;
}
```
`@ToString` 이 없을 경우와 있을 경우의 System.out.println(hotelRoomRequest.toString()); 는 각각 아래와 같다.

// `@ToString`이 없을 경우
```shell
com.assu.study.chap05.controller.HotelRoomRequest@708e1ce7
```

// `@ToString`이 있을 경우
```shell
HotelRoomRequest(roomNumber=ASSU-111, roomType=DOUBLE, originalPrice=100.00)
```

/controller/HotelRoomIdResponse.java
```java
package com.assu.study.chap05.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;
import lombok.Getter;

import java.util.Objects;

@Getter
public class HotelRoomIdResponse {
  @JsonProperty("id") // JSON 객체로 마셜링하는 과정에서 hotelRoomId 속성명 대신 다른 id 가 JSON 객체의 속성명이 됨
  @JsonSerialize(using = ToStringSerializer.class)  // 마셜링 과정에서 hotelRoomId 의 Long 타입을 String 타입으로 변경
  private Long hotelRoomId;

  private HotelRoomIdResponse(Long hotelRoomId) {
    if (Objects.isNull(hotelRoomId)) {
      throw new IllegalArgumentException("hotelRoomId is null.");
    }
    this.hotelRoomId = hotelRoomId;
  }

  public static HotelRoomIdResponse from(Long hotelRoomId) {
    return new HotelRoomIdResponse(hotelRoomId);
  }
}
```

> `@JsonProperty`, `@JsonSerialize` 는
> [Spring Boot - REST-API with Spring MVC (1): GET/DELETE 메서드 매핑, 응답 메시지 처리(마셜링)](https://assu10.github.io//dev/2023/05/14/springboot-rest-api-2/) 의
> _2.1. JSON 마셜링: `@JsonProperty`, `@JsonSerialize`_ 를 참고하세요.


```shell
$ curl -i --location 'http://localhost:18080/hotels/111/rooms' \
--header 'Content-Type: application/json' \
--data '{
    "roomNumber": "ASSU-111",
    "roomType": "double",
    "originalPrice": "100.00"
}'

HTTP/1.1 200
X-CREATED-AT: 2023-06-17T20:23:18+09:00
Content-Type: application/json
Transfer-Encoding: chunked
Date: Sat, 17 Jun 2023 11:23:18 GMT

{"id":"1002003"}%
```

---

# 2. Pageable, Sort 클래스

---

## 2.1. Pagination 과 Sort: Pageable 클래스

아래는 예약 정보 리스트를 조회하는 REST-API 설계이다.

```http
# Request
GET /hotels/{hotelId}/rooms/{roomNumber}/reservations
  - page: 페이지 번호, 0부터 시작
  - size: 페이지 당 포함할 갯수, default 20
  - sort: 정렬 프로퍼티명과 ASC/DESC 를 같이 사용하며 콤마로 구분
    - e.g. reservationId,asc
```

명세서에 있는 **page, size, sort 는 Spring 프레임워크에서 미리 정의한 기본 파라미터명으로 `@RequestParam` 애너테이션이 없어도 Spring 프레임워크가 자동으로
객체로 변환하여 핸들러 메서드의 인자로 주입**하는데 이 기능은 Spring Data 프레임워크의 확장 기능인 `웹 서포트` 이다.

`웹 서포트` 기능을 사용하려면 pom.xml 에 `spring-boot-starter-data-jpa` 의존성을 추가해야 한다.

pom.xml
```xml
<dependencies>
  <!-- Pageable 관련 -->
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
  </dependency>
  <!-- https://mvnrepository.com/artifact/mysql/mysql-connector-java -->
  <dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <version>8.0.33</version>
  </dependency>
  <!-- https://mvnrepository.com/artifact/org.hsqldb/hsqldb -->
  <dependency>
    <groupId>org.hsqldb</groupId>
    <artifactId>hsqldb</artifactId>
    <version>2.7.2</version>
  </dependency>
  <!-- https://mvnrepository.com/artifact/org.hibernate/hibernate-validator -->
</dependencies>
```

`mysql-connector-java` 와 `hsqldb` 는 `spring-data-jpa` 와 연관된 라이브러리로 이 라이브러리들이 없으면 JPA 프레임워크가 동작하지 않는다.

/controller/ReservationController.java
```java
package com.assu.study.chap05.controller;

import org.springframework.data.domain.Pageable;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.Collections;
import java.util.List;

@RestController
public class ReservationController {
  @GetMapping("/hotels/{hotelId}/rooms/{roomNumber}/reservations")
  public List<Long> getReservationsByPaging(
          @PathVariable Long hotelId,
          @PathVariable String roomNumber,
          Pageable pageable // @RequestParam 이 없어도 Pageable 클래스를 인자로 선언하면 page, size, sort 파라메터값을 매핑한 Pageagle 객체를 주입함
  ) {
    System.out.println("page: " + pageable.getPageNumber());  // page 파라메터값 리턴
    System.out.println("size: " + pageable.getPageSize());  // size 파라메터값 리턴
    
    // Pageable 의 getSort() 는 sort 파라메터값과 대응하는 Sort 객체 리턴하고, sort 파라메터는 하나 이상의 값일 수 있음
    // 따라서 Sort 객체는 inner class 인 Sort.order 객체스트림을 구현함
    // stream() 을 사용하면 클라이언트가 전달한 파라메터 집합 처리 가능
    pageable.getSort().stream().forEach(order -> {
      System.out.println("sort: " + order.getProperty() + ", " + order.getDirection());
    });

    return Collections.emptyList();
  }
}
```

sort 파라메터에 하나 이상의 데이터는 아래와 같이 설정한다.

```http 
GET http://localhost:18080/hotels/123/rooms/912/ASSU-123/reservations?page=1&size=30&sort=reservationId,desc&sort=reservationDate,desc
```

```shell
$ curl --location --request GET 'http://localhost:18080/hotels/123/rooms/ASSU-123/reservations' \
--header 'Content-Type: application/json' \
--data '{
    "roomNumber": "ASSU-111",
    "roomType": "double",
    "originalPrice": "100.00"
}'
[]%

# console
page: 0
size: 20
```

```shell
$ curl --location --request GET 'http://localhost:18080/hotels/123/rooms/ASSU-123/reservations?page=1&size=50&sort=reservationId%2Cdesc&sort=reservationDate%2Casc' \
--header 'Content-Type: application/json' \
--data '{
    "roomNumber": "ASSU-111",
    "roomType": "double",
    "originalPrice": "100.00"
}'
[]%

# console
page: 1
size: 50
sort: reservationId, DESC
sort: reservationDate, ASC
```

---

## 2.2. Pageable 자동 설정

application.properties 설정을 통해 Pageable 파라메터 파싱 방법을 변경할 수 있다.

application.properties
```properties
# HTTP 파라메터명인 page 대신 pageNum 으로 변경
spring.data.web.pageable.page-parameter=pageNum
# HTTP 파라메터명인 size 대신 pageSize 로 변경
spring.data.web.pageable.size-parameter=pageSize
# HTTP 파라메터명인 sort 대신 sortOrder 로 변경
spring.data.web.sort.sort-parameter=sortOrder
# 페이지 당 포함할 기본 갯수, default 20
spring.data.web.pageable.default-page-size=50
# 페이지 당 포함할 최대 갯수
spring.data.web.pageable.max-page-size=1000
# page 는 기본 0 부터 시작하는데 숫자 1로 시작하고 싶으면 true 로 설정
spring.data.web.pageable.one-indexed-parameters=false
```

```shell
$ curl --location --request GET 'http://localhost:18080/hotels/123/rooms/ASSU-123/reservations?pageNum=1&pageSize=70&sortOrder=reservationId%2Cdesc&sortOrder=reservationDate%2Casc' \
--header 'Content-Type: application/json' \
--data '{
"roomNumber": "ASSU-111",
"roomType": "double",
"originalPrice": "100.00"
}'
[]%

# console.log
page: 1
size: 70
sort: reservationId, DESC
sort: reservationDate, ASC
```

HTTP 파라메터명이 page → pageNum 으로 변경되었으므로 기존처럼 page, size, sort 로 넘기면 Pageable 이 파싱하지 못한다.

---

# 3. 검증

사용자 요청 데이터에 대해 Controller 에서 하드 코딩으로 검증하여 이슈가 있으면 400 Bad Request 를 응답하는 것을 비효율적이다.

사용가 요청 데이터는 크게 2 가지로 분류가 가능하다.
- **Controller 에서 검증 가능한 케이스**
  - 요청 데이터 자체의 포맷, 무결정 검증
- **Service 나 Component 에서 검증 가능한 케이스**
  - 데이터 저장소의 데이터를 조회하여 데이터 유무 검증

해당 포스트에서는 Controller 에서 검증 가능한 케이스에 대해 알아본다.

---

## 3.1. JSR-303 을 이용한 데이터 검증

JSR-303 은 [Java bean](https://assu10.github.io/dev/2023/05/07/springboot-spring/#9-spring-bean-java-bean-dto-vo) 을 자동으로 검증할 수 있는 스펙으로 애너테이션을 사용하여 Java bean 이 포함하는 속성들의 값을 검증한다.

Java bean 은 내부 속성에 접근 가능한 getter 들이 있는데 이 getter 들을 이용하여 객체의 속성을 검증한다.

JSR-303 을 구현한 구현체인 Hibernate-validator 라이브러리를 사용하기 위해 `hibernate-validator` 의존성을 추가한다.

pom.xml
```xml
<dependency>
    <groupId>org.hibernate</groupId>
    <artifactId>hibernate-validator</artifactId>
    <version>8.0.0.Final</version>
</dependency>
```

/controller/HotelRoomUpdateRequest.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.HotelRoomType;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.ToString;

import java.math.BigDecimal;

@Getter
@ToString
public class HotelRoomUpdateRequest {
  @NotNull(message = "room Type can't be null")
  private HotelRoomType roomType;

  @NotNull(message = "originalPrice can't be null")
  @Min(value = 0, message = "originalPrice must be larger then 0")  // 0 보다 크거나 같아야 함
  private BigDecimal originalPrice;
}
```

> 더 많은 검증 애너테이션은 [Jakarta Bean Validation constraints](https://docs.jboss.org/hibernate/stable/validator/reference/en-US/html_single/#validator-defineconstraints-spec) 을 참고하세요.

---

## 3.2. `@Valid`

바로 위에서 설명한 `@NotNull` 등의 JSR-303 에서 제공하는 애너테이션은 검증 조건을 설정하는 역할이고, `@Valid` 애너테이션은 검증할 Java bean 을 마킹하는 역할이다.  
따라서 **`@NotNull` 만 선언하면 검증이 동작하지 않고, 대상 객체에 `@Valid` 로 선언해야 해당 객체에 대해 검증을 진행**한다.

`@Valid` 는 Java bean 객체에 표기하며 일반적으로 Controller 의 핸들러 메서드 인자에 선언한다.

/controller/HotelRoomController.java
```java
package com.assu.study.chap05.controller;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController // @Controller 와 @ResponseBody 애너테이션의 기능을 동시에 제공
// HomeRoomController 가 리턴하는 객체들은 JSON 메시지 형태로 마셜링됨
public class HotelRoomController {
  @PutMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
  public ResponseEntity<HotelRoomIdResponse> updateHotelRoomByRoomNumber(
          @PathVariable Long hotelId,
          @PathVariable String roomNumber,
          // HotelRoomUpdateRequest 인자 검사, 검사 대상은 대상 클래스 안에 JSR-303 애너테이션이 선언된 속성들
          @Valid @RequestBody HotelRoomUpdateRequest hotelRoomUpdateRequest,
          // HotelRoomUpdateRequest 검증 결과와 결과를 조회할 수 있는 메서드 제공
          BindingResult bindingResult
  ) {

    if (bindingResult.hasErrors()) {
      FieldError fieldError = bindingResult.getFieldError();
      String errorMessage = new StringBuilder("Validation error.")
              .append(" filed: ").append(fieldError.getField()) // 검증에 실패한 속성명 확인
              .append(", code: ").append(fieldError.getCode())  // 어떤 검증을 실패했는지 코드 확인 (=message?)
              .append(", message: ").append(fieldError.getDefaultMessage())
              .toString();

      System.out.println(errorMessage);
      return ResponseEntity.badRequest().build();
    }

    System.out.println(hotelRoomUpdateRequest.toString());
    HotelRoomIdResponse body = HotelRoomIdResponse.from(1_002_003L);
    return ResponseEntity.ok(body);
  }
}
```

**BindingResult 객체가 정상적으로 주입되려면 반드시 검증 대상 객체 바로 다음에 선언**해야 한다.

```shell
$ curl -w "%{http_code}" --location --request PUT 'http://localhost:18080/hotels/123/rooms/ASSU-123' \
--header 'Content-Type: application/json' \
--data '{

    "originalPrice": "-1"
}'
400%

# console 
Validation error. filed: roomType, code: NotNull, message: room Type can't be null
```

---

## 3.3. Validator 인터페이스와 `@InitBinder` 를 이용한 검증

만일 아래와 같이 한 번에 여러 객실을 생성하는 API 가 있다고 하자.  
아래 코드에서 검증 기능은 동작하지 않는다.

```java
@PostMapping(path = "/hotels/{hotelId}/rooms")
public ResponseEntity<HotelRoomIdResponse> createHotelRoom(
        @PathVariable Long hotelId,
        @Valid @RequestBody List<HotelRoomRequest> hotelRoomRequests,  // @RequestBody 는 클라이언트에서 전송한 요청 메시지의 body 를 언마셜링하여 자바 객체인 HotelRoomRequest 로 변환
        BindingResult bindingResult
) {
        ...
  return new ResponseEntity<>(body, headers, HttpStatus.OK);
}
```

위에서 검증 대상은 List 클래스 타입이고, List 객체는 [Java bean](https://assu10.github.io/dev/2023/05/07/springboot-spring/#9-spring-bean-java-bean-dto-vo) 이 아니다.

Java bean 은 내부 속성에 접근할 수 있는 getter 메서드가 있어야 하는데 List 클래스는 getter 메서드가 없기 때문에 자동 검증이 수행되지 못한다.

이런 경우 List 구현체를 상속받는 사용자 정의 클래스를 생성해서 getter 메서드를 생성하여 List 대신 사용해도 되지만 org.springframework.validation.Validator (줄여서 o.s.validation.Validator) 인터페이스와 `@InitBinder` 를 사용하여 검증이 가능하다.

---

JSR-303 에서 제공하는 애너테이션의 하나의 속성에 여러 애너테이션을 조합하여 검증할 수 있지만 검증 조건이 복잡해지면 애너테이션 조합만으로 검증하기 어려울 경우가 있다.  
예를 들어 startDate 속성값이 endDate 속성값보다 미래이면 안되는 경우 두 속성 값을 비교해야 하기 때문에 JSR-303 애너테이션으로는 검증할 수 없다.

보통 Validator 구현체는 검증 대상 클래스와 1:1 로 개발한다.

Validator.class
```java
package org.springframework.validation;

public interface Validator {
  boolean supports(Class<?> clazz);
  void validate(Object target, Errors errors);
}
```

- `supports()`
  - Validator 구현체가 Class clazz 인수를 검증할 수 있는지 확인하는 메서드
  - 검증이 가능하면 true 리턴해야 함
- `validate()`
  - 검증 대상 객체는 Object target 인수로 들어오고, 이를 캐스팅하여 검증하는 코드 작성
  - 검증 에러가 있으면 Errors errors 객체의 메서드를 사용하여 에러 입력

/controller/HotelRoomReserveRequest.java
```java
package com.assu.study.chap05.controller;

import lombok.Getter;
import lombok.ToString;

import java.time.LocalDate;

@Getter
@ToString
public class HotelRoomReserveRequest {
  private LocalDate checkInDate;
  private LocalDate checkOutDate;
  private String name;
}
```

/controller/validator/HotelRoomReserveValidator.java
```java
package com.assu.study.chap05.controller.validator;

import com.assu.study.chap05.controller.HotelRoomReserveRequest;
import org.springframework.validation.Errors;
import org.springframework.validation.Validator;

import java.util.Objects;

public class HotelRoomReserveValidator implements Validator {
  @Override
  public boolean supports(Class<?> clazz) {
    // 검증 대상이 HotelRoomReserveRequest 이므로 검증 대상 클래스 타입인 clazz 인자와 HotelRoomReserveRequest 클래스가 같아야 함
    return HotelRoomReserveRequest.class.equals(clazz);
  }

  @Override
  public void validate(Object target, Errors errors) {
    // target 인수를 HotelRoomReserveRequest 객체로 캐스팅
    // support() 로 확인한 객체만 validate() 의 target 인수로 넘어옴
    HotelRoomReserveRequest request = HotelRoomReserveRequest.class.cast(target);

    if (Objects.isNull(request.getCheckInDate())) {
      errors.rejectValue("checkInDate", "NotNull", "checkInDate is null");
      return;
    }
    if (Objects.isNull(request.getCheckOutDate())) {
      errors.rejectValue("checkOutDate", "NotNull", "checkOutDate is null");
      return;
    }
    // checkInDate 가 checkOutDate 보다 크면 검증 실패 입력
    if (request.getCheckInDate().compareTo(request.getCheckOutDate()) >= 0) {
      errors.rejectValue("checkOutDate", "Constraint Error", "checkOutDate is earlier than checkInDate");
      return;
    }
  }
}
```

이제 validator 구현 클래스를 대상 객체에 연결하여 실제 검증하려면 아래 3 가지를 설정해주어야 한다.

- JSR-303 애너테이션처럼 핸들러 메서드의 검증 대상 인자에 `@Valid` 애너테이션 선언
- WebDataBinder 초기화 함수 선언
- WebDataBinder 초기화 함수 선언에 `@InitBinder` 애너테이션 선언
  - 초기화 함수에 `@InitBinder` 선언 시 WebDataBinder 객체 주입받음

Spring MVC 프레임워크는 사용자 요청과 Java bean 을 바인딩할 수 있는 o.s.web.bind.WebDataBinder 클래스를 제공하는데, WebDataBinder 는 addValidators() 와 같은 
메서드를 사용하여 기능을 확장할 수 있다. 

> 클래스 내부에 사용된 ReserveService 는 [4.1. `@ControllerAdvice`, `@ExceptionHandler`, `@RestControllerAdvice`](#41-controlleradvice--exceptionhandler--restcontrolleradvice) 에 있습니다.

/controller/HotelRoomReserveController.java 
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.controller.validator.HotelRoomReserveValidator;
import com.assu.study.chap05.domain.reservation.ReserveService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.WebDataBinder;
import org.springframework.web.bind.annotation.*;

@RestController
public class HotelRoomReserveController {
  private final ReserveService reserveService;

  public HotelRoomReserveController(ReserveService reserveService) {
    this.reserveService = reserveService;
  }

  @InitBinder // initBinder() 초기화 함수에 선언
  void initBinder(WebDataBinder binder) {
    // 개발자가 Validator 를 확장한 클래스 추가
    binder.addValidators(new HotelRoomReserveValidator());
  }

  @PostMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}/reserve")
  public ResponseEntity<HotelRoomIdResponse> reserveHotelRoomByRoomNumber(
          @PathVariable Long hotelId,
          @PathVariable String roomNumber,
          @Valid @RequestBody HotelRoomReserveRequest reserveRequest,
          BindingResult bindingResult
  ) {
    // 예외 처리
    if (bindingResult.hasErrors()) {
      FieldError fieldError = bindingResult.getFieldError();
      String errorMessage = new StringBuilder(bindingResult.getFieldError().getCode())
              .append(" [").append(fieldError.getField()).append("] ")
              .append(fieldError.getDefaultMessage())
              .toString();

      System.out.println("error  : " + errorMessage);
      return ResponseEntity.badRequest().build();
    }

    System.out.println(reserveRequest.toString());

    Long reservationId = reserveService.reserveHotelRoom(
            hotelId,
            roomNumber,
            reserveRequest.getCheckInDate(),
            reserveRequest.getCheckOutDate()
    );

    HotelRoomIdResponse body = HotelRoomIdResponse.from(reservationId);

    return ResponseEntity.ok(body);
  }
}
```

```shell
$ curl -w"%{http_code}" --location 'http://localhost:18080/hotels/123/rooms/ASSU-123/reserve' \
--header 'Content-Type: application/json' \
--data '{
    "name": "assu",
    "checkInDate": "2023-05-05",
    "checkOutDate": "2023-05-01"
}'
400%

# console 
error  : Constraint Error [checkOutDate] checkOutDate is earlier than checkInDate
```

---

# 4. 예외 처리

java 에서 예외는 크게 2 종류가 있다.
- `Checked Exception`
  - java.lang.Exception 클래스를 상속받은 클래스
  - try-catch 로 예외 처리를 하거나 메서드 시그니처에 throws 키워드를 사용하여 메서드를 호출하는 메서드로 예외를 던짐
  - 예외 처리 하지 않으면 컴파일 에러 발생
- `Unchecked Exception`
  - java.lang.RuntimeException 클래스를 상속받는 Exception 클래스
  - 예외 처리를 하지 않아도 컴파일 에러가 발생하지 않기 때문에 어디선가 적절한 처리를 해줘야 함

대부분의 Exception 클래스들은 대부분 RuntimeException 을 상속받는 Unchecked Exception 이다.

---

## 4.1. `@ControllerAdvice`, `@ExceptionHandler`, `@RestControllerAdvice`

> 클래스 내부에 사용된 BadRequestException 클래스는 바로 뒤에 설명이 있습니다.

/domain/reservation/ReserveService.java
```java
package com.assu.study.chap05.domain.reservation;

import org.springframework.stereotype.Service;

import java.time.LocalDate;

@Service
public class ReserveService {
  public Long reserveHotelRoom(Long hotelId, String roomNumber, LocalDate checkInDate, LocalDate checkOutDate) {
    if (1==1) {
      // 해당 메서드를 호출하는 곳에 @ExceptionHandler 가 선언된 예외 처리 메서드가 있으면 
      // BadRequestException 예외 객체를 예외 처리 메서드로 전달
      // 임시 코드
      Optional.empty().orElseThrow(() -> {
        return new BadRequestException("BadRequestException!!!");
      });

    }
    return 1_002_003L;
  }
}
```

`@ExceptionHandler` 는 예외를 처리할 수 있는 메서드를 지정하며, `@Controller` 가 선언된 클래스나 `@ControllerAdvice` 가 선언된 어드바이스 클래스에 사용할 수 있다.  

`@ControllerAdvice` 는 애플리케이션 전체에서 예외 처리 메서드를 선언할 수 있는 Spring bean 으로, **별도의 클래스 생성 후 선언부에 `@ControllerAdvice` 애너테이션을 선언하면 전역 설정 Spring bean** 이 된다.
이 Spring bean 내부에 `@ExceptionHandler` 을 설정하면 애플리케이션 전체에 예외 처리 메서드가 동작한다.

/domain/BadRequestException.java
```java
package com.assu.study.chap05.domain;

// RuntimeException 을 상속하여 Unchecked Exception 으로 설계
// 따라서 불필요한 예외 처리 구문을 사용하지 않음
public class BadRequestException extends RuntimeException {
  // 클라이언트에 전달할 목적
  private String errorMessage;

  public BadRequestException(String errorMessage) {
    super();
    this.errorMessage = errorMessage;
  }

  public String getErrorMessage() {
    return errorMessage;
  }
}
```

/controller/ApiExceptionHandler.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.BadRequestException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice // @ExceptionHandler 가 정의된 메서드를 포함하는 Spring bean 애너테이션
public class ApiExceptionHandler {

  @ExceptionHandler(BadRequestException.class)  // BadRequestException 이 발생하면 처리할 메서드 지정
  public ResponseEntity<ErrorResponse> handleBadRequestException(BadRequestException ex) {  //
    System.out.println("Error Message: " + ex.getErrorMessage());

    // 클라이언트에 응답 메시지를 전달
    return new ResponseEntity<>(
            new ErrorResponse(ex.getErrorMessage()),
            HttpStatus.BAD_REQUEST
    );
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ErrorResponse> handleException(Exception ex) {
    return new ResponseEntity<>(
            new ErrorResponse("System Error"),
            HttpStatus.INTERNAL_SERVER_ERROR
    );
  }
}
```

@ExceptionHandler() 의 속성값은 배열이므로 아래와 같이 여러 예외 클래스를 설정하여 하나의 핸들러 메서드로 처리 가능하다.
`@ExceptionHandler({Exception.class, BadRequestException.class})`

개발자가 미리 대응할 수 없는 여러 상황을 처리할 수 있는 handleException() 를 넣어 폴백 기능도 추가한다.

/controller/ErrorResponse.java
```java
package com.assu.study.chap05.controller;

import lombok.Getter;
import lombok.ToString;

@Getter
@ToString
public class ErrorResponse {
  private String errorMessage;

  public ErrorResponse(String errorMessage) {
    this.errorMessage = errorMessage;
  }
}
```

`@RestControllerAdvice` 는 `@Controller` 와 `@ResponseEntity` 를 합친 애너테이션이므로 `@ExceptionHandler` 가 정의된 예외 처리가 리턴하는 객체는 HttpMessageConverter 로 마셜링된다.  
그리고 변경된 JSON 메시지가 클라이언트에 전달된다. (=에외 처리를 하면서 동시에 에러 미시지를 클라이언트에 전달)

> `@ResponseBody` 애너테이션이 선언된 메서드가 리턴하는 객체는 HttpMessageConverter 로 마셜링되고, `@RestController` 애너테이션은 `@Controller` 와 `@ResponseBody` 애너테이션의 기능을 동시에 제공함  
> [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/) 의 _3.1. `@ResponseBody`, `HttpMessageConverter`_ 와  
> [Spring Boot - REST-API with Spring MVC (1): GET/DELETE 메서드 매핑, 응답 메시지 처리(마셜링)](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2/) 의 _1.2. Controller 구현: `@PathVariable`, `@RequestParam`, `@DateTimeFormat`_ 을 함께 보시면 도움이 됩니다.


---

# 5. 미디어 콘텐츠 다운로드

이 포스트에서는 두 가지 방법으로 파일을 다운로드받는 방법에 대해 알아본다.

- **HttpMessageConverter 를 사용하여 파일 byte 정보 조회**
  - 파일의 크기가 커지면 그 크기에 비례하여 byte[] 크기도 증가하고, 메모리 사용량도 비례하여 증가함
  - 그만큼 GC 빈도수가 증가하여 성능 하락 발생
  - 이럴 경우는 Stream API 를 직접 다루면 보다 효율적으로 메모리 사용 가능
- **HttpServletResponse 를 사용하여 파일 다운로드**

---

## 5.1. HttpMessageConverter 를 사용하여 파일 byte 정보 조회

HttpMessageConverter 를 사용하여 파일 다운로드 기능을 구현하려면 핸들러 메서드에 아래 설정을 해야 한다.
- `@ResponseBody` 혹은 그와 같은 기능을 하는 `@RestController` 설정
- 메서드 시그니처의 응답 객체는 byte[] 혹은 ResponseEntity<byte[]> 형태

파일이나 이미지같은 데이터를 HTTP 프로토콜로 전달할 때 응답 message body 는 8bit binary 로 구성된다.

/controller/ReservationController.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.FileDownloadException;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.io.InputStream;

@RestController
public class ReservationController {
  
  ...

  // pdf byte 정보 조회
  @GetMapping(value = "/hotels/pdf/getByte")
  public ResponseEntity<byte[]> getInvoice() {
    String filePath = "pdf/hotel_invoice.pdf";  // resources/pdf/hotel_invoice.pdf
    
    try (InputStream inputStream = new ClassPathResource(filePath).getInputStream()) {
      // inputStream 객체를 byte[] 로 변환 후 리턴
      byte[] bytes = StreamUtils.copyToByteArray(inputStream);
      return new ResponseEntity<>(bytes, HttpStatus.OK);
    } catch (Throwable th) {
      th.printStackTrace();
      throw new FileDownloadException("file read Error~");
    }
  }
}
```

pdf byte 정보 조회 기능은 아래와 같은 순서로 진행된다.
- copyToByteArray() 가 InputStream 객체를 byte[] 로 변경
- 핸들러 메서드에 리턴된 byte[] 는 ByteArrayHttpMessageConverter 로 변경됨
- 변경된 메시지는 'Content-type: application/octet-stream' 헤더와 함께 클라이언트에 전달

octet-stream 은 응답 body 가 binary 데이터임을 의미한다

/domain/FileDownloadException.java
```java
package com.assu.study.chap05.domain;

public class FileDownloadException extends RuntimeException {
  public FileDownloadException() {
    super();
  }

  public FileDownloadException(String message) {
    super(message);
  }

  public FileDownloadException(String message, Throwable cause) {
    super(message, cause);
  }

  public FileDownloadException(Throwable cause) {
    super(cause);
  }

  protected FileDownloadException(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) {
    super(message, cause, enableSuppression, writableStackTrace);
  }
}
```

/controller/ApiException.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.FileDownloadException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice // @ExceptionHandler 가 정의된 메서드를 포함하는 Spring bean 애너테이션
public class ApiExceptionHandler {

  ...
  
  @ExceptionHandler(FileDownloadException.class)
  public ResponseEntity handleFileDownloadException(FileDownloadException e) {
    return new ResponseEntity(HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
```

브라우저에서 http://localhost:18080/hotels/pdf/getByte 접속 시 byte 출력되는 것을 확인할 수 있다.

---

## 5.2. HttpServletResponse 를 사용하여 파일 다운로드

/controller/ReservationController.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.FileDownloadException;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.InputStream;
import java.io.OutputStream;

@RestController
public class ReservationController {

  // pdf download
  @GetMapping(value = "/hotels/pdf/download", produces = "application/pdf")
  public void downloadInvoice(
          HttpServletResponse response
  ) {
    String filePath = "pdf/hotel_invoice.pdf";  // resources/pdf/hotel_invoice.pdf

    try (InputStream inputStream = new ClassPathResource(filePath).getInputStream()) {
      OutputStream outputStream = response.getOutputStream();

      // HttpServletResponse 객체의 메서드를 사용하여 HTTP status code, header 설정
      response.setStatus(HttpStatus.OK.value());
      response.setContentType(MediaType.APPLICATION_PDF_VALUE);
      response.setHeader("Content-Disposition", "filename=invoice.pdf");

      // 파일을 읽어오는 InputStream 객체에서 데이터를 읽고, HttpServletResponse 의 OutputStream 객체에 데이터를 씀
      StreamUtils.copy(inputStream, outputStream);
    } catch (Throwable th) {
      th.printStackTrace();
      throw new FileDownloadException("file download error~");
    }
  }
}
```

브라우저에서 http://localhost:18080/hotels/pdf/download 접속 시 pdf 파일이 노출되는 것을 확인할 수 있다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [Lombok의 @ToString()](https://jjam89.tistory.com/242)
* [Jakarta Bean Validation constraints](https://docs.jboss.org/hibernate/stable/validator/reference/en-US/html_single/#validator-defineconstraints-spec)