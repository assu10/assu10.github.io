---
layout: post
title:  "Spring Boot - REST-API with Spring MVC (1): GET/DELETE 메서드 매핑, 응답 메시지 처리(마셜링)"
date:   2023-05-14
categories: dev
tags: springboot msa rest-api spring-web-mvc marshalling path-variable request-param datetime-format get-mapping delete-mapping
---

이 포스팅에서는 GET, DELETE, POST, PUT 으로 REST-API 를 개발하는 방법을 알아본다.   
그리고 클라이언트와 서버 간 데이터를 주고 받는 과정에서 HTTP 프로토콜을 다루는 방법이나 JSON 메시지를 다루는 방법에 대해 알아본다.  
마지막으로 binary 데이터 처리 방법에 대해서도 알아본다.

REST-API 애플리케이션이 HTTP 프로토콜로 메시지를 교환하려면 HTTP 프로토콜의 헤더나 message body, URI 의 데이터를 읽고 쓰기가 가능해야 한다. 그러기 위해서
Spring MVC 프레임워크는 HTTP 프로토콜을 쉽게 사용할 수 있는 애너테이션과 클래스들을 제공한다.

Spring boot 프레임워크는 JSON 메시지를 처리하는 Jackson 라이브러리를 포함하고 있어서 마셜링/언마셜링 시 Jackson 라이브러리를 별도 설정없이 바로 사용할 수 있다.

> 자바 객체를 바이트 스트림으로 변경하는 것을 직렬화(serialization) 이라고 하고, 반대 과정을 역직렬화(deserialization) 이라고 한다.  
> marshalling/unmarshalling 처럼 데이터 통신을 위한 변경 수단이지만 변환 결과가 다르므로 헷갈리지 말자. 

- HTTP 응답/요청 메시지를 마셜링/언마셜링 하는 방법

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap05) 에 있습니다.

---

**목차**

- [GET, DELETE 메서드 매핑](#1-get-delete-메서드-매핑)
  - [GET 메서드 매핑](#11-get-메서드-매핑)
  - [Controller 구현: `@PathVariable`, `@RequestParam`, `@DateTimeFormat`](#12-controller-구현-pathvariable-requestparam-datetimeformat)
  - [`@GetMapping`, `@RequestHeader`](#13-getmapping-requestheader)
  - [ant-style path](#14-ant-style-path)
  - [`@DeleteMapping`](#15-deletemapping)
- [응답 메시지 처리](#23-jsonformat)
  - [JSON 마셜링: `@JsonProperty`, `@JsonSerialize`](#21-json-마셜링-jsonproperty-jsonserialize)
  - [JsonSerializer, JsonDeserializer](#22-jsonserializer-jsondeserializer)
  - [`@JsonFormat`](#23-jsonformat)
  - [Enum 클래스의 변환: `@JsonValue`, `@JsonCreator`](#24-enum-클래스의-변환-jsonvalue-jsoncreator)

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

</project>
```

---

# 1. GET, DELETE 메서드 매핑

GET, DELETE 메서드는 요청 message body 에 데이터가 없다. 따라서 클라이언트가 서버에 데이터를 전달할 수 있는 방법은 아래 3 가지로 가능하다.

- request line 의 URI 에 리소스 데이터를 포함
- 파라미터를 사용하여 key/value 로 구성된 데이터 전송
- HTTP 헤더에 데이터 설정

---

## 1.1. GET 메서드 매핑

아래는 객실 정보를 조회하는 REST-API 설계이다.

```http
# Request
GET /hotels/{hotelId}/rooms/{roomNumber}?fromDate={yyyyMMdd}&toDate={yyyyMMdd}
  - hotelId: 필수, Long
  - roomNumber: 필수, String
  - fromDate,toDate: 선택, String, 예약일

# Response
{
  "id": "111",  // hotelRoomId (hotelId 나 roomId 아님)
  "roomNumber": "West-3928",
  "numberOfBeds": 2,
  "roomType": "deluxe", // 객실 타입, Enum 클래스로 정의되어 있음, 마셜링 과정에서 enum 키워드가 아닌 문자열로 변환하여 사용
  "originalPrice": "200,000", // 서버에서는 BigDecimal 클래스 타입으로 처리하고, 응답 시엔 문자열로 반환
  "reservations": [
    {
      "id": "222",
      "reservedDate": "{yyyy-MM-dd}"  // LocalDate 클래스 타입으로 사용됨
    },
    {
      "id": "333",
      "reservedDate": "{yyyy-MM-dd}"
    }
  ]
}
```

---

## 1.2. Controller 구현: `@PathVariable`, `@RequestParam`, `@DateTimeFormat`

`@RestController` 애너테이션은 `@Controller` 와 `@ResponseBody` 애너테이션의 기능을 동시에 제공하여 해당 애너테이션이 선언된 클래스가 리턴하는 객체들은 JSON 메시지 형태로 마셜링된다.

> `@ResponseBody` 에 대한 내용은 [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/) 의 _3.1. `@ResponseBody`, `HttpMessageConverter`_ 를 참고하세요.

/controller/HotelRoomController.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.domain.HotelRoomType;
import com.assu.study.chap05.utils.IdGenerator;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Objects;

@RestController // @Controller 와 @ResponseBody 애너테이션의 기능을 동시에 제공
                // HomeRoomController 가 리턴하는 객체들은 JSON 메시지 형태로 마셜링됨
public class HotelRoomController {

  @GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
  public HotelRoomResponse getHotelRoomByPeriod(
          @PathVariable Long hotelId,
          @PathVariable String roomNumber,
          @RequestParam(value = "fromDate", required = false) @DateTimeFormat(pattern = "yyyyMMdd")LocalDate fromDate,
          @RequestParam(value = "toDate", required = false) @DateTimeFormat(pattern = "yyyyMMdd") LocalDate toDate) {

    Long hotelRoodId = IdGenerator.create();
    BigDecimal originalPrice = new BigDecimal("100.00");

    HotelRoomResponse response = HotelRoomResponse.of(hotelRoodId, roomNumber, HotelRoomType.DOUBLE, originalPrice);

    if (Objects.nonNull(fromDate) && Objects.nonNull(toDate)) {
      fromDate.datesUntil(toDate.plusDays(1))
              .forEach(date -> response.reservedAt(date));
    }

    return response;
  }
}
```

/utils/IdGenerator.java
```java
package com.assu.study.chap05.utils;

import java.util.Random;

public class IdGenerator {
  private static final Integer bound = 10000;
  public static Long create() {
    Random rand = new Random();
    return System.currentTimeMillis() * bound + rand.nextInt(bound);
  }
}
```

`@RequestParam` 의 required 속성을 false 로 할 경우 defaultValue 속성과 같이 사용하는 것도 좋다. Optional 클래스의 orElse() 와 비슷한 역할이다.

---

## 1.3. `@GetMapping`, `@RequestHeader`

`@GetMapping` 은 아래 속성들을 갖고 있다.
- `value`
  - `path` 와 상호 호환되는 속성
- `path`
- `params`
  - 요청 메시지 중 파라메터 이름과 대응하는 속성
- `headers`
  - 요청 메시지 중 HTTP 헤더 이름과 대응하는 속성
- `consumes`
  - 요청 메시지 중 Content-type 헤더값과 대응하는 속성
- `produces`
  - 요청 메시지 중 Accept 헤더값과 대응하는 속성

이 속성들을 조합하면 클라이언트 요청을 보다 정교하게 매핑할 수 있다.  
- GET /hotels 은 @GetMapping(path="/hotels") 로..
- GET /hotels?page=1 @GetMapping(path="hotels", params="page") 로..

위 속성들 중 path, value, name, consumes, produces 는 서로 OR 연산으로 동작하고, params 와 headers 는 서로 AND 연산으로 동작한다.  
만일 path 와 params 를 동시에 설정하면 AND 조건으로 동작한다.

- @GetMapping(path={"/hotels", "/test"})
  - path 는 AND 연산
  - 'GET /hotels' 와 'GET /test' 모두 매핑 가능
- @GetMapping(path="/hotels", params="page")
  - path 와 params 는 AND 연산
  - '/GET /hotels?page=1' 매핑 가능
- @GetMapping(path="/hotels", params={"page", "isOpen"})
  - path 와 params 는 AND 연산, params 도 AND 연산
  - 'GET /hotels?page=1&isOpen=true' 매핑 가능

만일 HTTP 헤더를 사용해서 클라이언트 데이터를 받아야 한다면 `@RequestParam` 이 아닌 `@RequestHeader` 를 사용하면 된다.
```java
@GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
  public HotelRoomResponse getHotelRoomByPeriod2(
          @PathVariable(value="hotelId") Long hotelId,
          @PathVariable String roomNumber,  // value 생략 가능
          @RequestHeader(value = "x-from-date", required = false) @DateTimeFormat(pattern = "yyyyMMdd")LocalDate fromDate,
          @RequestHeader(value = "x-to-date", required = false) @DateTimeFormat(pattern = "yyyyMMdd") LocalDate toDate)
```

```shell
$ curl --location 'http://localhost:18080/hotels/123/rooms/456?fromDate=20230101&toDate=20230105' | jq

{
  "roomNumber": "456",
  "hotelRoomType": "double",
  "originalPrice": "100.00",
  "reservations": [
    {
      "reservedDate": "2023-01-01",
      "id": "16869886700104204"
    },
    {
      "reservedDate": "2023-01-02",
      "id": "16869886700103211"
    },
    {
      "reservedDate": "2023-01-03",
      "id": "16869886700107656"
    },
    {
      "reservedDate": "2023-01-04",
      "id": "16869886700101911"
    },
    {
      "reservedDate": "2023-01-05",
      "id": "16869886700108161"
    }
  ],
  "id": "16869886700108763"
}
```


---

## 1.4. ant-style path

경로 지정 시 ant-style-path 패턴 문자열을 사용할 수도 있다.

- `?`
  - 한 개의 문자와 매핑
  - @GetMapping(path="/hotels/?") 는 '/hotels/1' 은 매핑가능하지만 '/hotels/12' 는 매핑 불가
- `*`
  - 0개 이상의 문자만 매핑
  - @GetMapping(path="/hotels/*") 는 '/hotels/12' 는 매핑가능하지만 '/hotels/12/34' 는 매핑 불가
- `**`
  - 0개 이상의 문자와 디렉터리 매핑
  - @GetMapping(path="/hotels/**") 는 '/hotels/12', '/hotels/12/34' 모두 매핑 가능
  - 하위 디렉터리가 몇 개든 상관없이 모두 매핑 가능

---

## 1.5. `@DeleteMapping`

아래는 객실 정보를 삭제하는 REST-API 설계이다.

```http
# Request
DELETE /hotels/{hotelId}/rooms/{roomNumber}
  - hotelId: 필수, Long
  - roomNumber: 필수, String

# Response
{
  "isSuccess": true,
  "message": "success"
}
```

/controller/HotelRoomController.java
```java
@DeleteMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
public DeleteResultResponse deleteHotelRoom(
        @PathVariable Long hotelId,
        @PathVariable String roomNumber
) {
  System.out.println("deleted!");
  return new DeleteResultResponse(Boolean.TRUE, "success");
}
```

/controller/DeleteResultResponse.java
```java
package com.assu.study.chap05.controller;

import lombok.Getter;

@Getter
public class DeleteResultResponse {
  private boolean success;
  private String message;

  public DeleteResultResponse(boolean success, String message) {
    this.success = success;
    this.message = message;
  }
}
```

---

# 2. 응답 메시지 처리

서버에서 클라이언트로 데이터를 전달하는 별도의 데이터 전송 클래스를 DTO (Data Transfer Object) 라고 한다.

데이터 저장소의 데이터를 표현하는 엔티티 객체를 DTO 객체로 사용하는 것은 지양하는 것이 좋다. **별도의 DTO 클래스를 만들어 사용**하는 것을 권장한다.

DTO 클래스는 마셜링/언마셜링을 위한 여러 애너테이션이 사용되고, 엔티티 클래스에도 여러 애너테이션이 사용되는데 이 두 종류의 애너테이션이 섞이는 순간 유지 보수가 힘들어질 수 있다.

---

## 2.1. JSON 마셜링: `@JsonProperty`, `@JsonSerialize`

- `@JsonProperty`
  - JSON 객체로 마셜링하는 과정에서 특정값으로 속성명을 사용하고 싶을 경우 사용
  - 예) @JsonProperty("id")
- `@JsonSerialize`
  - JSON 객체로 마셜링하는 과정에서 속성 타입을 변경하고 싶을 경우 사용
    - 예) @JsonSerialize(using = ToStringSerializer.class) // 만일 해당 애너테이션을 선언한 변수의 타입이 Long 이라도 JSON 으로 마셜링 시 String 타입으로 변경되어 마셜링됨
    - using 속성에는 JsonSerializer 구현체 클래스를 속성 값으로 설정 가능
    - `@JsonDeserialize` 는 JSON 객체를 DTO 자바 객체로 변환하는 언마셜링 과정에서 JSON 속성값을 적절한 객체의 속성값으로 변환할 때 사용  
      (POST, PUT 처럼 사용자 요청을 받는 DTO 클래스에서 사용, 사용 방법은 `@JsonSerialize` 와 동일함)

> 클래스 내부에 사용되는 HotelRoomType 은 [2.4. Enum 클래스의 변환: `@JsonValue`, `@JsonCreator`](#24-enum-클래스의-변환--jsonvalue--jsoncreator) 를 참고하세요.

> 클래스 내부에 사용되는 ToDollarStringSerializer 는 [2.2. JsonSerializer, JsonDeserializer](#22-jsonserializer-jsondeserializer) 를 참고하세요.

> `@JsonFormat` 은 [2.3. `@JsonFormat`](#23-jsonformat) 을 참고하세요.

/controller/HotelRoomResponse.java
```java
package com.assu.study.chap05.controller;

import com.assu.study.chap05.controller.serializer.ToDollarStringSerializer;
import com.assu.study.chap05.domain.HotelRoomType;
import com.assu.study.chap05.utils.IdGenerator;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

// DTO
@Getter
public class HotelRoomResponse {
  @JsonProperty("id") // JSON 객체로 마셜링하는 과정에서 hotelRoomId 속성명 대신 다른 id 가 JSON 객체의 속성명이 됨
  @JsonSerialize(using = ToStringSerializer.class)  // 마셜링 과정에서 hotelRoomId 의 Long 타입을 String 타입으로 변경
  private final Long hotelRoomId;
  private final String roomNumber;
  private final HotelRoomType hotelRoomType;  // HotelRoomType 은 열거형 클래스로 enum 상수도 JSON 형식으로 마셜링됨

  @JsonSerialize(using = ToDollarStringSerializer.class) // 마셜링 과정에서 BigDecimal 타입을 달러 타입으로 변경하기 위해 커스텀 구현체로 지정
  private final BigDecimal originalPrice;
  private final List<Reservation> reservations;

  private HotelRoomResponse(Long hotelRoomId, String roomNumber, HotelRoomType hotelRoomType, BigDecimal originalPrice) {
    this.hotelRoomId = hotelRoomId;
    this.roomNumber = roomNumber;
    this.hotelRoomType = hotelRoomType;
    this.originalPrice = originalPrice;
    reservations = new ArrayList<>();
  }

  // 호출하는 쪽에서 생성자 직접 호출하지 않게 하기 위해..
  // 정적 팩토리 메서드 패턴
  public static HotelRoomResponse of(Long hotelRoomId, String roomNumber, HotelRoomType hotelRoomType, BigDecimal originalPrice) {
    return new HotelRoomResponse(hotelRoomId, roomNumber, hotelRoomType, originalPrice);
  }

  public void reservedAt(LocalDate reservedAt) {
    reservations.add(new Reservation(IdGenerator.create(), reservedAt));
  }

  @Getter // Reservation 객체도 마셜링 되어야하므로 @Getter 애너테이션 정의
  private static class Reservation {

    @JsonProperty("id")
    @JsonSerialize(using = ToStringSerializer.class)
    private final Long reservationId;

    // 마셜링 과정에서 LocalDate 타입의 데이터를 String 타입의 사용자 정의 포맷으로 변경하기 위해 @JsonFormat 애너테이션 사용
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private final LocalDate reservedDate;

    public Reservation(Long reservationId, LocalDate reservedDate) {
      this.reservationId = reservationId;
      this.reservedDate = reservedDate;
    }
  }
}
```
> `public static HotelRoomResponse of()` 에 대해선 '정적 팩토리 메서드 패턴' 을 찾아보세요.

> **final**
> - final 클래스: final 로 정의된 클래스는 상속 불가, 보안/효율성 측면에서 좋음, java.lang.String 처럼 java 에서 기본적으로 제공하는 라이브러리 클래스는 final 사용
> - final 메서드: 어떤 클래스를 상속하는데 그 안에 final 메서드가 있다면 오버라이딩으로 수정 불가
> - final 변수: 한 번 값을 할당하면 수정 불가, 초기화는 한 번만 가능

> **final 변수**  
> `public static fianl String Str = "AAA";` 가 아닌 아래처럼 먼저 선언해놓고 각각 다른 값을 갖도록 초기화할 수도 있음(한 번 값을 할당하면 다음부터는 수정불가)    
> 이런 형태를 `blank final 변수` 라고 함

```java
public Class Test {
  // 선언만 하고 초기화는 각 인스턴스에서 진행
  private final int value;

  public Test(int value) {
    this.value = value;  
  }

  public int getValue() {
    return value;
  }
}
```

> **static**  
> 보통 `public static final String Str = "AAA";` 이렇게 static 과 final 을 같이 쓰는 경우가 많음  
> static 은 변수나 함수에 붙는 키워드로 메모리에 한 번만 할당되어 메모리를 효율적으로 사용 가능함 (=같은 주소값을 공유하여 모든 곳에서 변수 하나로 공유 가능)  
> final 은 그 값을 계속 사용한다는 의미이므로 메모리 낭비할 필요없이 하나로 쓰도록 static 과 final 을 같이 사용하는 케이스가 많음
>
> 주의할 점은 위의 `blank final 변수` 형태일 경우 인스턴스마다 다른 값을 갖기 때문에 final 이어도 초기화가 다르게 된다면 static 을 사용하지 않음


[1.1. GET 메서드 매핑](#11-get-메서드-매핑) 의 Response 에서 hotelRoomId 속성명을 'id' 로 설계했지만 애플리케이션 내부에서는 'hotelRoomId' 가 정확한 표현이므로
내부에서는 Long hotelRoomId 으로 사용하고, 응답 시엔 String id 의 형태로 응답할 수 있도록 아래와 같이 설정한다.
```java
@JsonProperty("id")
@JsonSerialize(using = ToStringSerializer.class)
private final Long hotelRoomId;
```

> 개발 도중 REST-API 의 response 의 속성명이 변경이 된다고 해서 클래스 속성명을 변경하지 말고 `@JsonProperty` 를 이용하자!

`@JsonSerialize(using = ToStringSerializer.class)` 에 사용된 ToStringSerializer 도 JsonSerialize 의 구현체이고, Jackson 라이브러리에서 제공하는 기본 클래스이다.

ToStringSerializer 외에도 다양한 Serializer 구현체들이 기본 제공되고 있다.
- ByteArraySerializer: byte[] 객체 마셜링할 때 사용
- CalendarSerializer
- DateSerializer
- CollectionSerializer
- NumberSerializer
- TimeZoneSerializer

---

**Long 타입값을 마셜링할 때는 문자열로 변환하는 것이 좋다.**  

웹 브라우저와 같은 클라이언트에서 REST-API 호출 시 XHR(XmlHttpRequest) 객체를 사용하여 REST-API 를 호출한 후 그 결과를 화면에 렌더링하는데
javascript 의 숫자는 32 bit integer 이고, java 의 Long 이 표현하는 숫자는 64 bit 이다.  
따라서 32 bit 를 넘는 Long 데이터가 javascript 에 전달되면 overflow 되어 정확한 숫자 처리를 할 수 없기 때문에 Long 데이터를 정확히 전달하기 위해선 문자열로 변경하여 응답하는 것이 좋다.

---

## 2.2. JsonSerializer, JsonDeserializer

마셜링/언마셜링 과정에서 데이터 변환 시 로직 구현이 필요하거나 특별한 형태의 데이터로 변환해야 하는 경우 `JsonSerializer`, `JsonDeserializer` 구현체를 사용하여 기능 확장이 가능하다.

Jackson 라이브러리가 제공하는 `JsonSerializer`, `JsonDeserializer` 추상 클래스를 상속받아 기능을 확장할 수 있다. 

/controller/serializer/ToDollarStringSerializer.java
```java
package com.assu.study.chap05.controller.serializer;


import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.SerializerProvider;

import java.io.IOException;
import java.math.BigDecimal;

// 추상 클래스인 JsonSerializer 를 상속받으며, 변환할 대상의 클래스 타입을 Generic 으로 설정
// 여기서 변환할 대상 클래스 타입은 BigDecimal
public class ToDollarStringSerializer extends JsonSerializer<BigDecimal> {
  @Override
  public void serialize(BigDecimal bigDecimal, JsonGenerator jsonGenerator, SerializerProvider serializerProvider) throws IOException {
    // JSON 문자열을 만드는 JsonGenerator 객체의 writeString() 메서드를 사용하여 BicDecimal 객체를 문자열로 변경
    jsonGenerator.writeString(bigDecimal.setScale(2).toString());
  }
}
```

---

## 2.3. `@JsonFormat`

`@JsonFormat` 은 java.util.Date 혹은 java.util.Calendar 객체를 사용자가 원하는 포맷으로 변경해주는 역할을 한다.

> JsonSerialize 와 다른 점은 구현체 클래스를 설정하는 대신 간단한 속성 설정으로 데이터 변경이 가능하다는 점!


아래 코드는 LocalDate 타입의 데이터를 사용자 정의 포맷으로 변경하기 위해 @JsonFormat 애너테이션 사용한 예시이다.  
shape 속성은 `@JsonFormat` 에 이너 클래스로 정의된 Shape enum 클래스를 사용하여 정의한다. 
JsonFormat.Shape.STRING 은 마셜링 과정에서 해당 데이터를 String 타입으로 변경한다는 의미이다.
```java
@JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
private final LocalDate reservedDate;
```

---

## 2.4. Enum 클래스의 변환: `@JsonValue`, `@JsonCreator`

enum 클래스를 마셜링/언마셜링하는 경우를 생각해보자.

일반적으로 enum 클래스는 마셜링할 때 enum 상수 이름 그대로 변경이 된다. 마셜링 과정에서 enum 상수를 변경 시 toString() 메서드를 사용하는데 
toString() 메서드는 enum 상수 이름을 리턴하기 때문이다. (= 아래 코드에서 HotelRoomType enum 클래스가 마셜링되면 SINGLE 상수의 경우 "SINGLE" 이 됨)

하지만 이렇게 마셜링이 되면 REST-API 응답에 유연하게 설계가 불가능하다.

내부에서는 SINGLE 이라는 enum 상수값을 사용하고, REST-API 명세서에는 'single' 혹은 'singleRoom' 처럼 다양하게 응답할 수 있도록 응답값과 enum 상수값을
따로 분리하는 것이 좋다.

이 때 마셜링/언마셜링 시 각각 `@JsonValue`, `@JsonCreator` 애너테이션을 사용하여 응답값과 enum 상수값 분리가 가능하다.

/domain/HotelRoomType.java
```java
package com.assu.study.chap05.domain;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

import java.util.Arrays;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

public enum HotelRoomType {
  SINGLE("single"), // HotelRoomType.SINGLE 열거형 상수의 내부 속성인 param 값은 'single' 문자열
  DOUBLE("double"),
  TRIPLE("triple"),
  QUAD("quad");

  private final String param; // 마셜링 후 사용되는 JSON 객체 값 저장

  // 모든 enum 상수 선언 시 JSON 객체 값으로 사용도리 값을 인수로 입력
  // SINGLE 상수는 문자열 'single' 이 param 값으로 할당됨
  HotelRoomType(String param) {
    this.param = param;
  }

  private static final Map<String, HotelRoomType> paramMap = Arrays.stream(HotelRoomType.values())
          .collect(Collectors.toMap(HotelRoomType::getParam, Function.identity()));

  // param 인자를 받아서 paramMap 의 key 와 일치하는 enum 상수를 리턴
  // 언마셜링 과정에서 JSON 속성값이 "single" 이면 fromParam() 메서드가 HotelRoomType.SINGLE 로 변환함
  @JsonCreator  // 언마셜링 과정(JSON -> 객체)에서 값 변환에 사용되는 메서드를 지정
  public static HotelRoomType fromParam(String param) {
    return Optional.ofNullable(param)
            .map(paramMap::get)
            .orElseThrow(() -> new IllegalArgumentException("param is not valid."));
  }

  // enum 상수에 정의된 param 변수값 리턴 (= getParam() 이 리턴하는 문자열이 JSON 속성값으로 사용됨)
  // 마셜링 과정에서 HotelRoomType.SINGLE 이 "single" 로 변환됨
  @JsonValue  // 마셜링 과정(객체 -> JSON)에서 값 변환에 사용되는 메서드 지정, 이 애너테이션이 있으면 마셜링 때 toString() 이 아닌 getParam() 사용
  public String getParam() {
    return this.param;
  }
}
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [final 그게 뭔데, 어떻게 쓰는 건데](https://makemethink.tistory.com/184)
* [배열을 스트림으로 변환하는 방법(Array to Stream)](https://developer-talk.tistory.com/756)
* [Stream.collect() 사용 방법 및 예제](https://codechacha.com/ko/java8-stream-collect/)
* [Function.identity()](https://thebook.io/006725/0086/)
* [Optional](https://www.daleseo.com/java8-optional-after/)
* [LocalDate datesUntil](https://ntalbs.github.io/2020/java-date-practice/)
* [정적 팩토리 메서드 사용법](https://inpa.tistory.com/entry/GOF-%F0%9F%92%A0-%EC%A0%95%EC%A0%81-%ED%8C%A9%ED%86%A0%EB%A6%AC-%EB%A9%94%EC%84%9C%EB%93%9C-%EC%83%9D%EC%84%B1%EC%9E%90-%EB%8C%80%EC%8B%A0-%EC%82%AC%EC%9A%A9%ED%95%98%EC%9E%90)