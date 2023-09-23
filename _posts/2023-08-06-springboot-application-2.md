---
layout: post
title:  "Spring Boot - 웹 애플리케이션 구축 (2): HttpMessageConverter, ObjectMapper"
date:   2023-08-12
categories: dev
tags: springboot msa HttpMessageConverter ObjectMapper
---

이 포스팅에서는 `HttpMessageConverter` 와 `ObjectMapper` 를 설정하는 법에 대해 알아본다.


> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap06) 에 있습니다.

---

**목차**

- `HttpMessageConverter`, REST-API 설정
  - `HttpMessageConverter` 설정
  - `ObjectMapper` 와 스프링 빈을 이용한 애플리케이션 설정

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap05

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

</project>
```

---

# 1. `HttpMessageConverter`, REST-API 설정

`@ResponseBody` 나 `@RequestBody` 애너테이션이 선언된 대상은 `HttpMessageConverter` 가 마셜링/언마셜링을 실행하기 때문에
REST-API 애플리케이션은 ViewResolver 도움없이 객체를 JSON 메시지로(마셜링), JSON 메시지를 객체로(언마셜링) 할 수 있다.

---

## 1.1. `HttpMessageConverter` 설정

[Spring Boot - 웹 애플리케이션 구축 (1): WebMvcConfigurer 를 이용한 설정, DispatcherServlet 설정](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#1210-addformatters) 에서 나온
'GET /hotels/1234/rooms/ocean-5678' 을 클래스 코드를 수정하지 않고, 스프링 웹 MVC 프레임워크의 `HttpMessageConverter` 를 설정하여 
다양한 포맷으로 응답할 수 있게 해보자.

클라이언트의 Accept 헤더값이 'application/json' 이면 JSON 형식으로 마셜링된 메시지를 응답하고, 'application/xml' 이면 XML 형태로 직렬화된 메시지를 
응답하도록 할 것이다.

스프링 프레임워크에서 처리하는 직렬화/역직렬화 과정은 `@ResponseBody`, `@RequestBody` 설정에 의해 `HttpMessageConverter` 가 담당하기 때문에 
List\<HttpMessageConverter\> 에 따라 JSON 혹은 XML 메시지로 직렬화할 수 있다.  
각각 'application/json', 'application/xml' 헤더 값에 동작하는 HttpMessageConverter 를 설정하면 된다.

핵심은 비즈니스 로직이 담길 클래스의 변경없이 `WebMvcConfigurer` 의 `configureMessageConverters()` 혹은 `extendMessageConverters()` 의 
설정으로만 응답하는 메시지 포맷을 변경하는 것이다.

/config/WebConfig.java
```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  // // Accept 헤더값에 따라 json, xml 로 응답
  @Override
  public void configureMessageConverters(List<HttpMessageConverter<?>> converters) {
    converters.add(new MappingJackson2HttpMessageConverter());  // JSON 처리
    converters.add(new MappingJackson2XmlHttpMessageConverter()); // XML 처리
  }
}
```

```xml
<dependency>
    <groupId>com.fasterxml.jackson.dataformat</groupId>
    <artifactId>jackson-dataformat-xml</artifactId>
</dependency>
```

`configureMessageConverters()` 는 프레임워크에서 제공하는 기본 설정 대신 직접 설정한 대로 동작하고,  
`extendMessageConverters()` 는 프레임워크에서 제공하는 기본 설정에 새로운 `HttpMessageConverter` 들이 추가되어 동작한다.

`HttpMessageConverter` 는 컨텐츠 타입에 따라 데이터 변환 여부를 설정하는데 이 콘텐츠 타입은 사용자 요청이나 응답 메시지의 헤더에 사용된다.  
HTTP 메시지 바디의 컨텐츠 타입을 의미하는 `Content-type` 이나 클라이언트가 처리할 수 있는 컨텐츠 타입을 의미하는 `Accept` 헤더의 값으로 사용된다.

아래는 `MappingJackson2HttpMessageConverter` 와 `MappingJackson2XmlHttpMessageConverter` 의 생성자 부분이다.

```java
public MappingJackson2HttpMessageConverter(ObjectMapper objectMapper) {
  super(objectMapper, new MediaType[]{MediaType.APPLICATION_JSON, new MediaType("application", "*+json")});
}
```

`MappingJackson2HttpMessageConverter` 가 지원하는 미디어 타입은 MediaType.APPLICATION_JSON (application/json), application/+json 이다.

```java
public MappingJackson2XmlHttpMessageConverter(ObjectMapper objectMapper) {
  super(objectMapper, new MediaType[]{new MediaType("application", "xml", StandardCharsets.UTF_8), new MediaType("text", "xml", StandardCharsets.UTF_8), new MediaType("application", "*+xml", StandardCharsets.UTF_8)});
  Assert.isInstanceOf(XmlMapper.class, objectMapper, "XmlMapper required");
}
```

`MappingJackson2XmlHttpMessageConverter` 가 지원하는 미디어 타입은 `application/xml', 'text/xml', 'application/+xml' 이다.

이제 클라이언트의 Accept 헤더값에 따라 클라이언트가 원하는 포맷의 데이터를 받을 수 있다.

```java
@GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
public Callable<HotelRoomResponse> getHotelRoomByPeriod(
  ClientInfo clientInfo,
  @PathVariable Long hotelId,
  @PathVariable HotelRoomNumber roomNumber
) {
  Callable<HotelRoomResponse> response = () -> {
    return HotelRoomResponse.of(hotelId, String.valueOf(roomNumber.getRoomNumber()));
  };
  return response;
}
```

Accept 헤더가 없는 경우
```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678' | jq
```

```shell
{
  "roomNumber": "ocean-5678",
  "id": "1234"
}
```

Accept 헤더 - application/json
```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678' \
--header 'Accept: application/json' | jq
```

```shell
{
  "roomNumber": "ocean-5678",
  "id": "1234"
}
```

Accept 헤더 - application/xml

```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678' \
--header 'Accept: application/xml'
```

```shell
<HotelRoomResponse>
    <roomNumber>5678</roomNumber>
    <id>1234</id>
</HotelRoomResponse>
```

---

## 1.2. `ObjectMapper` 와 스프링 빈을 이용한 애플리케이션 설정

여기선 `ObjectMapper` 를 이용하여 직렬화/역직렬화 과정에서 DTO 객체의 속성을 제어해본다.

/controller/HotelRoomController.java
```java
@RestController
public class HotelRoomController {

  @GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
  public HotelRoomResponse getHotelRoomByPeriod(
      ClientInfo clientInfo,
      @PathVariable Long hotelId,
      @PathVariable HotelRoomNumber roomNumber,
      @RequestParam(value = "fromDate", required = false) @DateTimeFormat(pattern = "yyyyMMdd") LocalDate fromDate,
      @RequestParam(value = "toDate", required = false) @DateTimeFormat(pattern = "yyyyMMdd") LocalDate toDate
  ) {
    Long hotelRoomId = IdGenerator.create();
    BigDecimal originalPrice = new BigDecimal("130.00");

    HotelRoomResponse response = HotelRoomResponse.of(hotelRoomId, String.valueOf(roomNumber.getRoomNumber()), HotelRoomType.DOUBLE, originalPrice));

    if (Objects.nonNull(fromDate) && Objects.nonNull(toDate)) {
      fromDate.datesUntil(toDate.plusDays(1)).forEach(date -> response.reservedAt(date));
    }
    return response;
  }
}
```

> `datesUntil()` 에 대한 설명은 [LocalDate datesUntil](https://ntalbs.github.io/2020/java-date-practice/) 을 참고하세요.

```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678' \
--header 'Accept: application/json' | jq

{
  "roomNumber": "5678",
  "hotelRoomType": "double",
  "originalPrice": "130.00",
  "reservations": [],
  "id": "16954473518036293"
}
```

보면 reservations 의 속성은 fromDate 와 toDate 가 없으면 항상 비어있는 리스트이다.  
DTO 객체의 속성이 비어있다면 해당 속성을 제거하고 직렬화를 진행해보도록 하자.  
`ObjectMapper` 객체의 속성을 변경하면 직렬화 과정에서 비어있는 속성을 제외할 수 있다.

여기선 **별도의 `ObjectMapper` 객체를 생성하고, 이를 어떻게 `MessageConverter` 에 주입하여 사용**하는지 알아본다.


/controller/serializer/ToDollarStringSerializer.java
```java
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

DTO /controller/HotelRoomResponse.java
```java
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

> ToDollarStringSerializer.java 에 대한 설명은 [2.2. JsonSerializer, JsonDeserializer](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2/#22-jsonserializer-jsondeserializer) 
> 을 참고하세요.

> `@JsonFormat` 에 대한 설명은 [2.3. `@JsonFormat`](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2/#23-jsonformat) 을 참고하세요.

/util/IdGenerator.java 
```java
import java.util.Random;

public class IdGenerator {
  private static final Integer bound = 10000;

  public static Long create() {
    Random rand = new Random();
    return System.currentTimeMillis() * bound + rand.nextInt(bound);
  }
}
```

---

`AbstractJackson2HttpMessageConverter` 내부에는 `objectMapper` 속성을 포함하고 있다.  
`ObjectMapper` 클래스는 역직렬화할 수 있는 `readValue()` 와 직렬화할 수 있는 `writeValue()` 메서드를 제공한다.

`ObjectMapper` 클래스는 직렬화/역직렬화 과정에서 DTO 객체의 속성에 따라 제외하거나 포함하는 여러 가지 설정 옵션을 제공한다. 
이 설정을 하려면 `ObjectMapper` 의 `setSerializationInclusion()` 메서드를 사용한다.

`setSerializationInclusion()` 는 `JsonInclude.Include` enum 상수를 인자로 받으며, 이 상수에 따라 직렬화 과정을 설정할 수 있다.

`ObjectMapper` 의 상수값들과 사용법은 아래와 같다.

```java
ObjectMapper objectMapper = new ObjectMapper();
objectMapper.setSerializationInclusion(JsonInclude.Include.ALWAYS);
objectMapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
objectMapper.setSerializationInclusion(JsonInclude.Include.NON_ABSENT);
objectMapper.setSerializationInclusion(JsonInclude.Include.NON_EMPTY);

objectMapper.setSerializationInclusion(JsonInclude.Include.NON_DEFAULT);
objectMapper.setSerializationInclusion(JsonInclude.Include.CUSTOM);
objectMapper.setSerializationInclusion(JsonInclude.Include.USE_DEFAULTS);
```

JsonInclude.Include enum
```java
public static enum Include {
  ALWAYS,
  NON_NULL,
  NON_ABSENT,
  NON_EMPTY,
  NON_DEFAULT,
  CUSTOM,
  USE_DEFAULTS;
  private Include() {
  }
}
```

- `JsonInclude.Include.ALWAYS`
  - 속성값에 상관없이 항상 DTO 객체의 속성을 모두 포함하여 직렬화
- `JsonInclude.Include.NON_NULL`
  - DTO 객체의 속성값이 null 이 아닌 속성들만 포함하여 직렬화
- `JsonInclude.Include.NON_ABSENT`
  - JsonInclude.Include.NON_NULL 에 더해서 Optional 객체의 값이 null 이 아닌 속성들만 포함하여 직렬화
- `JsonInclude.Include.NON_EMPTY`
  - JsonInclude.Include.NON_ABSENT 에 더해서 리스트나 배열 또는 컬렉션 객체의 값도 비어있지 않고, 문자열 길이도 0 이상인 속성들만 포함하여 직렬화
- `JsonInclude.Include.NON_DEFAULT`
  - JsonInclude.Include.NON_EMPTY 에 더해서 int 나 long 같은 [원시 타입(primitive)](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 의 값이 기본값이 아닌 속성들만 포함하여 직렬화
  - int 나 long 의 기본값은 0 이며, boolean 의 기본값은 false 이다.
- `JsonInclude.Include.CUSTOM`
  - `@JsonInclude` 애너테이션의 filter 속성으로 거른 속성들만 포함하여 직렬화
- `JsonInclude.Include.USE_DEFAULTS`
  - 클래스 레벨이나 ObjectMapper 에서 설정된 기본값과 비교하여 기본값이 아닌 속성들만 포함하여 직렬화

HotelRoomResponse 의 List<Reservation> reservation 속성은 리스트 타입이기 때문에 null 은 아니지만 요소의 갯수가 0 이면 직렬화 과정에서 제외할 예정이다.  
따라서 `setSerializationInclusion()` 메서드의 인자로 `JsonInclude.Include.NON_EMPTY` enum 상수를 전달해야 한다.

---

`ObjectMapper` 스프링 빈은 `@ResponseBody`, `@RequestBody` 애너테이션을 통한 마셜링/언마셜링 과정에도 사용된다.

스프링 부트 프레임워크는 `JacksonAutoConfiguration` 에서 설정된 `ObjectMapper` 를 사용하기 때문에 `ObjectMapper` 를 설정하려면
자바 설정 클래스에 직접 스프링 빈으로 등록해야 한다.  

`JacksonAutoConfiguration` 자동 설정 클래스는 ApplicationContext 에 `ObjectMapper` 타입의 스프링 빈이 없으면 동작하도록 설정되어 있기 때문이다.  

즉, 스프링 빈이 아닌 `new` 키워드로 생성한 `ObjectMapper` 객체를 직접 `HttpMessageConverter` 의 생성자로 전달하면 
`JacksonAutoConfiguration` 자동 설정 클래스가 동작하여 개발자가 설정한 `ObjectMapper` 가 동작하지 않는다.

`ObjectMapper` 는 멀티 스레드에 안전한 클래스이기 때문에 동시에 여러 스레드에서 `ObjectMapper` 의 메서드를 사용해도 다른 스레드에 영향을 주지 않는다.

`ObjectMapper` 를 변경하려면 아래와 같이 자바 설정 클래스에 스프링 빈으로 등록하고, `@Primary` 애너테이션을 사용하여 우선권을 갖도록 설정한다.  
그러면 개발자가 정의한 `ObjectMapper` 스프링 빈이 ApplicationContext 에 포함되고, 스프링 프레임워크의 의존성 주입 기능으로 `HttpMessageConverter` 에도 적용된다.

/config/WebConfig.java
```java
@Configuration
public class WebConfig implements WebMvcConfigurer {

  // 직렬화 과정에서 NON_EMPTY 로 설정한 ObjectMapper 객체를 생성
  // @Bean 과 @Primary 애너테이션을 사용하여 설정한 ObjectMapper 는 애플리케이션에 가장 우선적으로 스프링 빈으로 생성됨
  @Bean
  @Primary
  public ObjectMapper objectMapper() {
    ObjectMapper objectMapper = new ObjectMapper();
    objectMapper.setSerializationInclusion(JsonInclude.Include.NON_EMPTY);
    return objectMapper;
  }

  // Accept 헤더값에 따라 json, xml 로 응답
  // HttpMessageConverter 생성자에 ObjectMapper 를 주입하지 않아도 바로 위 메서드에서 생성된 ObjectMapper 스프링 빈이 HttpMessageConverter 에 사용됨
  @Override
  public void configureMessageConverters(List<HttpMessageConverter<?>> converters) {
    converters.add(new MappingJackson2HttpMessageConverter());  // JSON 처리
    converters.add(new MappingJackson2XmlHttpMessageConverter()); // XML 처리
  }
}
```

지금 이 상태로 REST-API 를 호출하면 아래와 같은 오류가 발생한다.

```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678?fromDate=20230101&toDate=20230110' \
--header 'Accept: application/json'
```

```shell
com.fasterxml.jackson.databind.exc.InvalidDefinitionException: Java 8 date/time type `java.time.LocalDate` not supported by default: add Module "com.fasterxml.jackson.datatype:jackson-datatype-jsr310" to enable handling (through reference chain: com.assu.study.chap06.controller.HotelRoomResponse["reservations"]->java.util.ArrayList[0]->com.assu.study.chap06.controller.HotelRoomResponse$Reservation["reservedDate"])
	at com.fasterxml.jackson.databind.exc.InvalidDefinitionException.from(InvalidDefinitionException.java:77) ~[jackson-databind-2.15.0.jar:2.15.0]
	at com.fasterxml.jackson.databind.SerializerProvider.reportBadDefinition(SerializerProvider.java:1312) ~[jackson-databind-2.15.0.jar:2.15.0]
	at com.fasterxml.jackson.databind.ser.impl.UnsupportedTypeSerializer.serialize(UnsupportedTypeSerializer.java:35) ~[jackson-databind-2.15.0.jar:2.15.0]
```

LocalDate 의 직렬화/역직렬화 시 발생하는 오류이므로 LocalDate 가 선언된 HotelRoomResponse 의 reservedDate 에 `@JsonSerialize` 와 `@JsonDeserialize` 를 선언해준다.
```java
// 마셜링 과정에서 LocalDate 타입의 데이터를 String 타입의 사용자 정의 포맷으로 변경하기 위해 @JsonFormat 애너테이션 사용
@JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
@JsonSerialize(using = LocalDateSerializer.class)
@JsonDeserialize(using = LocalDateDeserializer.class)
private final LocalDate reservedDate;
```


이제 각각 예약일이 있는 경우와 없는 경우를 확인해본다.
```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678?fromDate=20230101&toDate=20230102' \
--header 'Accept: application/json' | jq

{
  "roomNumber": "5678",
  "hotelRoomType": "double",
  "originalPrice": "130.00",
  "reservations": [
    {
      "reservedDate": "2023-01-01",
      "id": "16954581045079181"
    },
    {
      "reservedDate": "2023-01-02",
      "id": "16954581045074693"
    }
  ],
  "id": "16954581045076620"
}
```

```shell
curl --location 'http://localhost:8080/hotels/1234/rooms/ocean-5678' \
--header 'Accept: application/json' | jq

{
  "roomNumber": "5678",
  "hotelRoomType": "double",
  "originalPrice": "130.00",
  "id": "16954581510720965"
}
```

reservations 의 요소 개수가 0일 경우 출력이 되지 않는 것을 확인할 수 있다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [LocalDate datesUntil](https://ntalbs.github.io/2020/java-date-practice/)