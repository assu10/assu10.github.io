---
layout: post
title:  "Spring Boot - 웹 애플리케이션 구축 (1): WebMvcConfigurer 를 이용한 설정, DispatcherServlet 설정"
date: 2023-08-05
categories: dev
tags: springboot msa web-mvc-configurer dispatcher-servlet
---

- 스프링 웹 MVC 프레임워크에서 제공하는 `WebMvcConfigurer` 를 사용하여 애플리케이션 설정
- `DispatcherServlet` 을 설정하여 기능을 확장하거나 새로 설정


> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap06) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 웹 애플리케이션 기본 설정](#1-웹-애플리케이션-기본-설정)
  * [1.1. 웹 애플리케이션 설정 매커니즘](#11-웹-애플리케이션-설정-매커니즘)
  * [1.2. `WebMvcConfigurer` 를 이용한 설정](#12-webmvcconfigurer-를-이용한-설정)
    * [1.2.1. `configurePathMatch()`](#121-configurepathmatch)
    * [1.2.2. `configureContentNegotiation()`](#122-configurecontentnegotiation)
    * [1.2.3. `configureAsyncSupport()`](#123-configureasyncsupport)
    * [1.2.4. `configureDefaultServletHandling()`](#124-configuredefaultservlethandling)
    * [1.2.5. `addInterceptors()`](#125-addinterceptors)
    * [1.2.6. `addResourcehandlers()`](#126-addresourcehandlers)
    * [1.2.7. `addCorsMappings()`](#127-addcorsmappings)
    * [1.2.8. `addViewControllers()`](#128-addviewcontrollers)
    * [1.2.9. `configureHandlerExceptionResolvers()` 와 `extendsHandlerExceptionResolvers()`](#129-configurehandlerexceptionresolvers-와-extendshandlerexceptionresolvers)
    * [1.2.10. `addFormatters()`](#1210-addformatters)
    * [1.2.11. `addArgumentResolvers()`](#1211-addargumentresolvers)
    * [1.2.12. `addReturnValueHandlers()`](#1212-addreturnvaluehandlers)
    * [1.2.13. `configureMessageConverters()` 와 `extendMessageConverters()`](#1213-configuremessageconverters-와-extendmessageconverters)
  * [1.3. DispatcherServlet 설정](#13-dispatcherservlet-설정)
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


스프링 부트 프레임워크는 기본 설정으로 바로 서비스 운영이 가능하지만 웹 애플리케이션 설정을 변경하거나 기본 설정을 확장해야 하는 경우도 있다.  
스프링 웹 MVC 프레임워크는 기능을 확장하거나 기본 설정으로 구성된 기능을 교체하는 다양한 방법을 제공한다.

웹 애플리케이션을 설정하는 방법은 3 가지로 분류할 수 있다.
- **스프링 웹 프레임워크에서 제공하는 확장 인터페이스를 사용하여 필요 기능을 추가,교체**
  - 예) 이 포스트에 나오는 `WebMvcConfigurer` 인터페이스에서 제공하는 콜백 메서드를 개발자가 설정한 부분만 구현하는 것
- **스프링 프레임워크에 기본 설정으로 만들어지는 스프링 빈을 재설정**
  - 예) `@Primary` 애너테이션을 사용하여 스프링 빈 재정의
- **스프링 웹 MVC 프레임워크에서 미리 정의한 스프링 빈 이름과 타입으로 사용자가 생성**

---

# 1. 웹 애플리케이션 기본 설정

스프링 부트 프레임워크에서 의존성 설정에 `spring-boot-starter-web` 의존성만 추가하면 개발자 대신 설정하는 기능을 스프링 부트가 설정해준다.

---

## 1.1. 웹 애플리케이션 설정 매커니즘

`WebMvcConfigurer` 인터페이스를 구현한 클래스를 스프링 빈으로 등록하면 애플리케이션이 실행되면서 프레임워크 설정 과정을 거치고, 사용자 의도대로 설정된
`WebMvcConfigurer` 구현체의 값을 사용하게 된다.

사용자가 구현한 메서드를 애플리케이션이 다시 호출하는 구조라서 `WebMvcConfigurer` 의 메서드를 콜백 메서드라고 하는데, 아래는 `WebMvcConfigurer` 의 콜백 메서드에 대한
간단한 설명이다.

---

## 1.2. `WebMvcConfigurer` 를 이용한 설정

아래는 `WebMvcConfigurer` 인터페이스의 디폴트 메서드들이다.  
메서드 명이 addXXX(), extendXXX() 인 메서드들은 기본 설정으로 만들어진 기능에 새로운 기능을 추가하여 확장하는 것이고,
configureXXX() 인 메서드들은 기본 설정으로 만들어진 기능을 교체하여 새로운 기능을 설정하는 것이다.

---

### 1.2.1. `configurePathMatch()`

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void configurePathMatch(PathMatchConfigurer configurer) {
    configurer
        // @RestController 애너테이션으로 정의된 컨트롤러 클래스들의 핸들러 메서드에 /v2 머릿말 자동으로 설정
        .addPathPrefix("/v2", HandlerTypePredicate.forAnnotation(RestController.class))
        .setPathMatcher(new AntPathMatcher())
        .setUrlPathHelper(new UrlPathHelper());
  }
}
```

---

### 1.2.2. `configureContentNegotiation()`

콘텐츠 타입을 확인하고 적절한 ViewResolver 를 찾는 일련의 과정을 콘텐츠 협상(content Negotiation) 이라고 한다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  // Accept 헤더 대신 URI 의 파라미터를 사용하여 request 분석
  @Override
  public void configureContentNegotiation(ContentNegotiationConfigurer configurer) {
    configurer
        // 콘텐츠 협상 기능을 사용하기 위한 URI 파라미터명을 contentType 으로 설정
        .parameterName("contentType")
        // Accept 헤더를 사용한 콘텐츠 협상 기능은 사용하지 않음
        .ignoreAcceptHeader(true)
        // 콘텐츠 협상 과정에서 적합한 값을 찾지 못하면 기본값 application/json 으로 설정
        .defaultContentType(MediaType.APPLICATION_JSON)
        // URI 파라미터 contentType 값이 json 이면 application/json 으로 간주
        .mediaType("json", MediaType.APPLICATION_JSON)
        // URI 파라미터 contentType 값이 xml 이면 application/xml 로 간주
        .mediaType("xml", MediaType.APPLICATION_XML);
  }
}
```

---

### 1.2.3. `configureAsyncSupport()`

`configureAsyncSupport()` 는 비동기 서블릿 기능을 설정할 때 사용한다.  
비동기 서블릿은 스프링 프레임워크에서 제공하는 비동기 프레임워크인 WebFlux 와는 다르다.  

전통적인 방식의 동기식 서블릿은 사용자 요청을 받아 처리하고 응답하는 모든 과정이 하나의 스레드에서 처리되지만,
비동기 서블릿은 사용자 요청을 처리하고 응답은 별도의 스레드에서 처리한다.  
그래서 비동기 서블릿은 비동기 처리를 위한 별도의 스레드 풀을 사용하는 구조를 갖는다.

비동기 서블릿을 구현하기 위해서는 먼저 비동기 서블릿 설정을 해야하는데 이 때 비동기 처리를 위한 스레드 풀을 같이 설정한다.

아래는 비동기 서블릿을 설정하는 예시이다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  // 비동기 서블릿 설정
  @Override
  public void configureAsyncSupport(AsyncSupportConfigurer configurer) {
    ThreadPoolTaskExecutor taskExecutor = new ThreadPoolTaskExecutor();

    // 스레드 풀의 이름은 Async-Executor 로 시작
    taskExecutor.setThreadNamePrefix("Async-Executor");
    // 기본 개수는 50개
    taskExecutor.setCorePoolSize(50);
    // 최대 100개까지 늘어남
    taskExecutor.setMaxPoolSize(100);
    // 스레드 풀의 대기열 크기는 300개
    taskExecutor.setQueueCapacity(300);
    // ThreadPoolTaskExecutor 스레드 풀을 초기화하려면 반드시 initialize() 호출
    taskExecutor.initialize();

    // 생성한 스레드 풀 셋팅
    configurer.setTaskExecutor(taskExecutor);
    // 비동기 처리 타임아웃
    configurer.setDefaultTimeout(10_000L);
  }
}
```

비동시 서블릿 예시
```java
@GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
public Callable<HotelRoomResponse> getHotelRoomByPeriod(
    @PathVariable Long hotelId,
    @PathVariable String roomNumber
) {
  Callable<HotelRoomResponse> response = () -> {
    return HotelRoomResponse.of(hotelId, roomNumber);
  };
  return response;
}
```

/controller/HotelRoomResponse.java (DTO)
```java
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;
import lombok.Getter;

// DTO
@Getter
public class HotelRoomResponse {

  @JsonProperty("id") // JSON 객체로 마셜링하는 과정에서 hotelRoomId 속성명 대신 다른 id 가 JSON 객체의 속성명이 됨
  @JsonSerialize(using = ToStringSerializer.class)  // 마셜링 과정에서 hotelRoomId 의 Long 타입을 String 타입으로 변경
  private final Long hotelRoomId;

  private final String roomNumber;

  private HotelRoomResponse(Long hotelRoomId, String roomNumber) {
    this.hotelRoomId = hotelRoomId;
    this.roomNumber = roomNumber;
  }

  // 호출하는 쪽에서 생성자 직접 호출하지 않게 하기 위해..
  // 정적 팩토리 메서드 패턴
  public static HotelRoomResponse of(Long hotelRoomId, String roomNumber) {
    return new HotelRoomResponse(hotelRoomId, roomNumber);
  }
}
```

비동기 서블릿 기능이 설정된 스프링 프레임워크는 `Callable` 타입의 객체를 리턴하면 이를 비동기 서블릿으로 처리한다.
그래서 프레임워크에 설정된 스레드 풀의 스레드를 할당받아 비동기로 클라이언트에 응답한다.

---

### 1.2.4. `configureDefaultServletHandling()`

WAS 가 사용자 요청을 매핑할 적합한 서블릿 설정이 없다면 기본 서블릿을 사용해서 처리해야 하는데 기본 서블릿은 별도로 설정해야 사용할 수 있다.

참고로 위 기능은 REST-API 에서는 사용하지 않는다.

---

### 1.2.5. `addInterceptors()`

o.s.web.servlet.HandlerInterceptor 인터페이스를 구현하면 인터셉터 구현체를 만들 수 있고, `addInterceptors()` 메서드에서 `InterceptorRegistry` 인자를 사용하여
새로 생성한 구현체를 애플리케이션에 추가하면 된다.

> 좀 더 자세한 사항은 [Spring Boot - 웹 애플리케이션 구축 (5): 국제화 메시지 처리, 로그 설정, 애플리케이션 패키징과 실행](https://assu10.github.io/dev/2023/08/19/springboot-application-5/#14-localeresolver-%EC%99%80-localechangeinterceptor-%EC%84%A4%EC%A0%95) 의 
> _1.4. `LocaleResolver` 와 `LocaleChangeInterceptor` 설정_ 를 참고하세요.

---

### 1.2.6. `addResourcehandlers()`

웹 애플리케이션은 REST-API 애플리케이션과 달리 이미지 파일같은 정적 파일을 읽어 클라이언트에 전송하는 기능이 필요하다.  
이 때 정적 파일들은 코드 베이스의 /resources 폴더에 저장하는데 서블릿이나 스프링 애플리케이션 클래스에서 resources 폴더에 저장된 정적 파일에 접근하려면 클래스 패스 경로를 사용한다.  
클래스 패스 경로를 사용하려면 경로에 'classpath:' 접두어를 붙인다.  
예) src > main > resources > main.html 파일의 클래스 패스 경로는 'classpath:/main.html' 이다.

웹 애플리케이션의 resources 폴더에 저장된 파일의 디렉터리 구조와 사용자가 요청하는 디렉터리 구조가 다를 경우 `addResourcehandlers()` 로 변경할 수 있다.

아래는 '/css' 경로로 요청하는 모든 정적 파일을 코드 베이스의 '/static/css' 경로에서 찾는 예시이다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  // '/css' 경로로 요청하는 모든 정적 파일을 코드 베이스의 '/static/css' 경로에서 찾는 예시
  @Override
  public void addResourceHandlers(ResourceHandlerRegistry registry) {
    registry.addResourceHandler("/css/**")
        .addResourceLocations("classpath:/static/css");
    registry.addResourceHandler("/html/**")
        .addResourceLocations("classpath:/static/html");
  }
}
```

---

### 1.2.7. `addCorsMappings()`

`addCorsMappings()` 를 통해 CORS 설정을 할 수 있다.

> **CORS (Cross Origin Resource Sharing)**  
> 출처가 다른 리소스들을 공유하는 것

출처가 다른 리소소를 공유하여 브라우저를 실행하는 것은 보안상 매우 위험하기 때문에 브라우저들은 SOP 를 따르도록 되어있다.

> **SOP (Same Origin Policy)**  
> 웹 브라우저의 보안을 위해 같은 출처의 리소스만 사용하도록 제한하는 방식

CORS 인증 과정을 거치면 다른 출처의 리소스를 사용할 수 있다.  
다른 출처의 리소스를 요청하기 전에 사용 가능 여부를 묻는 것을 **preflight** 라고 하는데 클라이언트는 preflight 응답 메시지에 포함된 헤더와 상태 코드를 읽어서
CORS 사용 여부를 판단한다. 

![preflight 과정](/assets/img/dev/2023/0805/prefight.png)

위 그림은 api.js 에 http://api.spring.io 호스트에 GET /v1/hotels 를 호출하여 JSON 문서를 받는 코드가 있을 경우 preflight 를 하는 과정이다.

① 웹 브라우저는 GET 메서드를 사용하여 http://www.spring.io 호스트에서 index.html 리소스 받음  
index.html 내부에는 api.js 문서가 포함되어 있음  

② api.js 리소스를 http://www.spring.io 에서 내려받음  
api.js 에는 getHotels() 메서드가 있고, 해당 메서드는 http://api.spring.io 호스트에 GET /v1/hotels REST-API 를 호출함  
getHotels() 를 실행하면 브라우저는 SOP 정책을 검사하고 출처를 확인  

③ 이 때 ① 에서 기록된 http://www.spring.io 와 getHotels() 에서 사용하는 출처인 http://api.spring.io 가 다르므로 브라우저는 GET /v1/hotels REST-API 를
실행하기 전에 다른 출처인 http://api.spring.io 호스트에 preflight 를 요청함  
이 때 요청 메시지는 OPTIONS /v1/hotels 이며, preflight 에 필요한 헤더들이 포함되어 있음  
즉, 브라우저는 원래 필요한 리소스에 OPTIONS 메서드로 변경하여 서버에 인증 요청 시도 (= preflight)  

④ REST-API 애플리케이션에 CORS 설정이 되어 있으면 응답  
- **Access-Control-Allow-Origin**: CORS 를 허용하는 출처, 호스트명을 응답함, 호스트 상관없이 모든 출처에 응답하는 경우는 `*` 로 응답  
- **Access-Control-Allow-Method**: CORS 를 허용하는 출처에서 사용할 수 있는 HTTP 메서드  
- **Access-Control-Allow-Headers**: CORS 를 허용하는 출처에서 사용할 수 있는 HTTP 헤더  
- **Access-Control-Max-Age**: 절차상 다른 출처에 있는 리소스를 사용하려면 매번 CORS 인증을 받아야 하는데 불필요한 오버 헤드를 줄이는 인증의 유효 시간  
초 단위의 숫자이며, 86400 은 하루 (24\*60\*60초) 를 의미함  

CORS 인증 과정을 직접 구현하기보다는 `WebMvcConfigurer` 에서 제공하는 `addCorsMappings()` 를 사용하여 구현하는 것이 간단하고 빠르다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addCorsMappings(CorsRegistry registry) {
    registry
        // 모든 리소스에 대해 CORS 적용
        .addMapping("/**")
        // 허용하는 출처는 www.spring.io
        .allowedOrigins("www.spring.io")
        .allowedMethods("GET", "POST")
        .allowedHeaders("*")
        .maxAge(24 * 60 * 60);
  }
}
```

---

### 1.2.8. `addViewControllers()`

웹 애플리케이션에서 사용자 요청을 어떤 뷰와 매핑할 지 설정하는 메서드이다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addViewControllers(ViewControllerRegistry registry) {
    // 요청 URI 가 / 일 때 처리하는 뷰 이름은 main
    registry.addViewController("/").setViewName("main");
  }
}
```

---

### 1.2.9. `configureHandlerExceptionResolvers()` 와 `extendsHandlerExceptionResolvers()`

애플리케이션 전체에서 발생하는 예외를 일관된 방법으로 처리하려면 `@HandlerException` 과 `@ControllerAdvice` 애너테이션을 같이 사용하면 된다.  
`HandlerExceptionResolver` 는 애플리케이션의 컨트롤러 클래스뿐 아니라 서블릿에서 발생한 모든 예외를 처리할 수 있어서 예외 처리 가능한 영역이 넓어진다.

아래는 RestApiHandlerExceptionResolver 만 사용하도록 새로 구성하는 예시이다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void configureHandlerExceptionResolvers(List<HandlerExceptionResolver> resolvers) {
    resolvers.add(new RestApiHandlerExceptionResolver());
  }
}
```

---

### 1.2.10. `addFormatters()`

스프링 프레임워크는 컨버터 구현체를 확장할 수 있도록 o.s.core.convert.converter.Converter, o.s.format.Formatter 인터페이스를 제공한다.

아래는 데이터 바인딩 예시이다.

```java
@GetMapping(path = "/hotels/{hotelId}/rooms/{roomNumber}")
public Callable<HotelRoomResponse> getHotelRoomByPeriod(
    @PathVariable Long hotelId,
    @PathVariable String roomNumber
) {
  Callable<HotelRoomResponse> response = () -> {
    return HotelRoomResponse.of(hotelId, roomNumber);
  };
  return response;
}
```

사용자가 GET /hotels/1234/rooms/ocean-5678 요청 시 1234 는 hotelId 에 할당되고, ocean-5678 은 roomNumber 에 할당되는데 이 과정을 데이터 바인딩이라고 한다.

Converter 인터페이스로 사용자가 입력한 roomNumber(ocean-5678) 를 도메인 모델로 변경하는 Converter 구현 클래스를 만들어보자.

도메인 모델은 HotelRoomNumber 이고, Converter 인터페이스를 구현한 HotelRoomNumberConverter 클래스는 roomNumber 를 HotelRoomNumber 객체로 변환한다.

/domain/HotelRoomNumber.java
```java
import lombok.Getter;

import java.util.StringJoiner;

@Getter
public class HotelRoomNumber {
  private static final String DELIMITER = "-";

  private final String buildingCode;
  private final Long roomNumber;

  public HotelRoomNumber(String buildingCode, Long roomNumber) {
    this.buildingCode = buildingCode;
    this.roomNumber = roomNumber;
  }

  // roomNumber (ocean-5678) 을 파싱하여 HotelRoomNumber 객체 리턴
  public static final HotelRoomNumber parse(String roomNumberId) {
    String[] tokens = roomNumberId.split(DELIMITER);
    if (tokens.length != 2) {
      throw new IllegalArgumentException("invalid roomNumberId format.");
    }
    return new HotelRoomNumber(tokens[0], Long.parseLong(tokens[1]));
  }

  @Override
  public String toString() {
    return new StringJoiner(DELIMITER)
        .add(buildingCode)
        .add(roomNumber.toString())
        .toString();
  }
}
```

GET /hotels/1234/rooms/ocean-5678 요청 시 'ocean-5678' 문자열을 컨트롤러나 서비스 클래스 내부에서 파싱해서 HotelRoomNumber 를 생성해도 되지만,
데이터 바인딩 시점에 'ocean-5678' 문자열을 변환하여 HotelRoomNumber 객체를 핸들러 메서드에 할당하면 좀 더 편하게 개발할 수 있다.

아래는 roomNumber 를 HotelRoomNumber 로 변환하는 Converter 구현체이다.

/converter/HotelRoomNumberConverter.java
```java
import com.assu.study.chap06.domain.HotelRoomNumber;
import org.springframework.core.convert.converter.Converter;

public class HotelRoomNumberConverter implements Converter<String, HotelRoomNumber> {
  @Override
  public HotelRoomNumber convert(String source) {
    return HotelRoomNumber.parse(source);
  }
}
```

이제 Converter 를 확장한 HotelRoomNumberConverter 를 스프링 애플리케이션에 추가한다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addFormatters(FormatterRegistry registry) {
    registry.addConverter(new HotelRoomNumberConverter());
  }
}
```

이제 기존에 String 으로 받던 roomNumber 를 HotelRoomNumber 객체로 받을 수 있다.
```java
@GetMapping(path = "/hotels/{hotelId}/rooms/{roomId}")
public Callable<HotelRoomResponse> getHotelRoomByPeriod(
@PathVariable Long hotelId,
@PathVariable HotelRoomNumber roomNumber
) {
  Callable<HotelRoomResponse> response = () -> {
    return HotelRoomResponse.of(hotelId, roomNumber.toString());
  };
  return response;
}
```

---

**컨버터를 이용하여 문자열을 enum 상수로 바인딩**할 수도 있다.  
REST-API 설계 시 특정 도메인의 타입이나 상태를 파라미터로 받을 때가 많다.

아래는 문자열을 HotelRoomType enum 변환하는 컨버터 구현체이다.

/converter/HotelRoomTypeConverter.java
```java
@Component
public class HotelRoomTypeConverter implements Converter<String, HotelRoomType> {
  @Override
  public HotelRoomType convert(String source) {
    return HotelRoomType.fromParam(source);
  }
}
```

바로 위의 HotelRoomNumberConverter 는 `new` 로 객체를 생성한 후 `addFormatter()` 를 오버라이드하여 명시적으로 애플리케이션에 등록했지만,  
HotelRoomTypeConverter 처럼 **`@Component` 애너테이션을 사용하여 HotelRoomTypeConverter 를 스프링 빈으로 생성**하면 `WebMvcConfigurer` 의 `addFormatter()` 를
오버라이드하지 않아도 스프링 애플리케이션에 컨버터 구현체가 등록된다.

/controller/HotelRoomType.java
```java
package com.assu.study.chap06.controller;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

import java.util.Arrays;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

public enum HotelRoomType {
  SINGLE("single"), // 내부 속성인 param 값는 single
  DOUBLE("double"),
  TRIPLE("triple"),
  QUAD("quad");

  private final String param; // 마셜링 후 사용되는 JSON 객체값 저장

  // 모든 enum 상수 선언 시 JSON 객체 값으로 사용될 값을 인수로 입력
  // SINGLE 상수는 문자열 'single' 이 param 값으로 할당됨
  HotelRoomType(String param) {
    this.param = param;
  }

  private static final Map<String, HotelRoomType> paramMap = Arrays.stream(HotelRoomType.values())
      .collect(Collectors.toMap(
          HotelRoomType::getParam,
          Function.identity()
      ));


  // param 인자를 받아서 paramMap 의 key 와 일치하는 enum 상수를 리턴
  // 언마셜링 과정에서 JSON 속성값이 "single" 이면 fromParam() 메서드가 HotelRoomType.SINGLE 로 변환함
  @JsonCreator  // 언마셜링 과정(JSON -> 객체)에서 값 변환에 사용되는 메서드를 지정
  public static HotelRoomType fromParam(String param) {
    return Optional.ofNullable(param) // 값이 존재하면 값을 감싸는 Optional 반환, null 이면 빈 Optional 반환
        .map(paramMap::get)
        .orElseThrow(() -> new IllegalArgumentException("param is not valid."));  // 값이 존재하면 값 반환, 없으면 Supplier 에서 생성한 예외 발생
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

Converter 와 비슷한 역할을 하는 **Formatter** 는 Formatter 구현체를 애플리케이션에 등록/사용하는 방법은 Converter 와 동일하다.  
둘의 차이점은 **다국어 기능 처리 여부**이다.

아래는 HotelRoomNumberConverter 처럼 roomNumber 문자열을 HotelRoomNumber 객체로 변환하는 포매터이다.

/formatter/HotelRoomNumberFormatter.java
```java
import com.assu.study.chap06.domain.HotelRoomNumber;
import org.springframework.format.Formatter;

import java.text.ParseException;
import java.util.Locale;

// HotelRoomNumberConverter 처럼 roomNumber 문자열을 HotelRoomNumber 객체로 변환하는 포매터
public class HotelRoomNumberFormatter implements Formatter<HotelRoomNumber> {
  @Override
  public HotelRoomNumber parse(String text, Locale locale) throws ParseException {
    return HotelRoomNumber.parse(text);
  }

  @Override
  public String print(HotelRoomNumber object, Locale locale) {
    return object.toString();
  }
}
```

위의 각 메서드는 Locale 을 인자로 받으므로 변환 과정에서 다국어 처리를 할 수 있다.

---

### 1.2.11. `addArgumentResolvers()`

`WebMvcConfigurer` 는 `ArgumentResolver` 를 확장할 수 있는 `addArgumentResolvers()` 를 제공한다.  
`ArgumentResolver` 는 `Converter` 나 `Formatter` 처럼 특정 데이터를 특정 객체로 변환하지만 아래와 같은 차이점이 있다.


- `Converter`, `Formatter`
  - `@PathVariable` 이나  `@RequestParam` 같은 애너테이션과 함께 사용
  - 애너테이션 설정으로 URI 나 URI 파라미터에 변환할 데이터를 정의하고, 애너테이션이 정의된 변수에 데이터를 변환하여 주입
- `AugumentResolver`
  - 대상 데이터를 정하지 않고 사용자가 요청한 HTTP 메시지에서 필요한 모든 것을 선택하여 가공 후 객체로 변환
  - 따라서 `@PathVariable` 이나  `@RequestParam` 같은 애너테이션 없이 동작함
  - 예) 요청 메시지의 헤더, 쿠키, 파라미터, URI 나 요청 메시지 등 모든 정보를 조합하여 변환

`ArgumentResolver` 구현체는 o.s.web.method.support.HandlerMethodArgumentResolver 인터페이스를 구현하면 된다.

`SortHandlerMethodArgumentResolver` 와 `PageableHandlerMethodArgumentResolver` 가 `ArgumentResolver` 의 대표적인 구현 클래스이다.
사용자 HTTP 요청 메시지의 URL 파라미터를 이용하여 각각 Sort 와 Pageable 객체로 변환하고 주입한다.

REST-API 에 `X-SPRING-CHANNEL` 헤더가 반드시 필요하고, 클라이언트의 IP 를 포함하여 ClientInfo 클래스로 변환해보자.

클라이언트 IP 는 HTTP 요청 메시지에서 직접 참조하게 될 경우 정확한 주소 참조가 어렵다.  
REST-API 애플리케이션이 로드 밸런싱 그룹에 포함되어 있거나 NginX, Apache 웹서버가 리버스 프록시 모드로 사용자 요청을 애플리케이션으로 전달하는 경우 클라이언트의 주소가 변경되는데
이 때 진짜 클라이언트의 주소는 `X-FORWARDED-FOR` 헤더로 전달된다.

이 두 가지 헤더를 사용하여 ClientInfo 인자로 변환하는 ClientInfoArgumentResolver 구현체와 ClientInfo 클래스는 아래와 같다.

/controller/ClientInfo.java
```java
import lombok.Getter;
import lombok.ToString;

@ToString
@Getter
public class ClientInfo {
  private final String channel;
  private final String clientAddress;

  public ClientInfo(String channel, String clientAddress) {
    this.channel = channel;
    this.clientAddress = clientAddress;
  }
}
```

/resolver/ClientInfoArgumentResolver.java
```java
import com.assu.study.chap06.controller.ClientInfo;
import org.springframework.core.MethodParameter;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

// X-SPRING-CHANNEL 와 X-FORWARDED-FOR 헤더를 사용하여 ClientInfo 로 변환하는 리졸버
public class ClientInfoArgumentResolver implements HandlerMethodArgumentResolver {
  private static final String HEADER_CHANNEL = "X-SPRING-CHANNEL";
  private static final String HEADER_CLIENT_IP = "X-FORWARDED-FOR";

  // 컨트롤러 클래스의 핸들러 메서드에 포함된 인자가 ArgumentResolver 구현체의 변환대상인지 확인
  @Override
  public boolean supportsParameter(MethodParameter parameter) {
    // 컨트롤러 클래스의 핸들러 메서드에 포함된 인자가 ClientInfo.class 타입이면 ClientInfoArgumentResolver 가 동작하여
    // ClientInfo 인자에 데이터 바인딩
    return ClientInfo.class.equals(parameter.getParameterType());
  }

  // 사용자의 요청 메시지를 특정 객체로 변환
  @Override
  public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer, NativeWebRequest webRequest, WebDataBinderFactory binderFactory) throws Exception {
    String channel = webRequest.getHeader(HEADER_CHANNEL);
    String clientAddress = webRequest.getHeader(HEADER_CLIENT_IP);
    return new ClientInfo(channel, clientAddress);
  }
}
```

`ArgumentResolver` 구현체를 만들었으니 `WebMvcConfigurer` 의 `addArgumentResolvers()` 를 사용하여 해당 구현체를 추가한다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
    resolvers.add(new ClientInfoArgumentResolver());
  }
}
```

이제 컨트롤러에서 ClientInfo 인자를 선언하면 ClientInfoArgumentResolver 가 resolveArgument() 를 실행하고 리턴된 ClientInfo 객체를 해당 인자에 데이터 바인딩한다.

```java
  @GetMapping(path = "/hotels/{hotelId}/rooms/{roomId}")
  public Callable<HotelRoomResponse> getHotelRoomByPeriod(
      ClientInfo clientInfo,
      @PathVariable Long hotelId,
      @PathVariable HotelRoomNumber roomNumber
  ) {
        System.out.println(clientInfo);
        ...
  
    return response;
  }
```

```shell
ClientInfo(channel=iOS, clientAddress=101.120.121.124)
```

---

### 1.2.12. `addReturnValueHandlers()`

웹 애플리케이션의 `HandlerMethodReturnValueHandler` 를 확장할 때 사용한다.  
`HandlerMethodReturnValueHandler` 인터페이스는 컨트롤러 클래스에 정의된 핸들러 메서드가 리턴하는 객체를 변환하는 역할을 한다.

보통 View 기술을 사용하는 웹 애플리케이션에 사용되고, REST-API 애플리케이션에서는 사용하는 일이 드물다.  
REST-API 애플리케이션에서는 JSON 타입의 메시지를 응답하고, 이 과정은 HttpMessageConverter 로 변환되기 때문이다.  
즉, REST-API 는 `HandlerMethodReturnValueHandler` 구현체 없이 객체를 JSON 으로 마셜링할 수 있다.

만약 REST-API 애플리케이션에서 핸들러 메서드가 JSON 이 아닌 아른 포맷으로 리턴해야 한다면 `HttpMessageConverter` 를 확장한 후
`configureMessageConverters()` 나 `extendMessageConverters()` 를 통해 프레임워크에 설정하는데 이건 바로 다음에 나온다.

---

### 1.2.13. `configureMessageConverters()` 와 `extendMessageConverters()`

`@ResponseBody`, `@RequestBody` 애너테이션이 적용된 대상을 특정 포맷으로 변경하는 `HttpMessageConverter` 를 설정하는 메서드이다.

> 좀 더 자세한 내용은 [Spring Boot - 웹 애플리케이션 구축 (2): HttpMessageConverter, ObjectMapper](https://assu10.github.io/dev/2023/08/06/springboot-application-2/#11-httpmessageconverter-%EC%84%A4%EC%A0%95) 의 _1.1. `HttpMessageConverter` 설정_ 를 참고하세요.

---

## 1.3. DispatcherServlet 설정

위의 `WebMvcConfigurer` 는 스프링 웹 MVC 프레임워크에서 제공하는 데이터 바인딩이나 메시지 컨버터같은 기능들을 설정한다.  
비슷하게 DispatcherServlet 도 MultipartResolver, LocaleResolver 등의 기능을 설정한다.

> DispatcherServlet 에 대한 추가 내용은 [2.1. DispatcherServlet](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/#21-dispatcherservlet) 을 참고하세요.

아래는 DispatcherServlet 의 일부분이다.
```java
public class DispatcherServlet extends FrameworkServlet {
  public static final String MULTIPART_RESOLVER_BEAN_NAME = "multipartResolver";
  public static final String LOCALE_RESOLVER_BEAN_NAME = "localeResolver";
  /** @deprecated */
  @Deprecated
  public static final String THEME_RESOLVER_BEAN_NAME = "themeResolver";

  ...

}
```

개발자가 이름이 localeResolver 인 LocaleResolver 스프링 빈을 생성하면 DispatcherServlet 은 애플리케이션이 시작할 때 개발자가 만든 LocaleResolver 를 사용하고,
만일 개발자가 만든 LocaleResolver 가 없다면 기본 LocaleResolver 가 설정된다.

만일 LocaleResolver 외 다른 스프링 빈을 별도로 설정하려면 DispatcherServlet 코들르 확인하여 프레임워크가 미리 정의한 스프링 빈 이름과 클래스 타입으로 설정하면 된다.

아래처럼 자바 설정 클래스에 스프링 빈을 설정하면 자동으로 설정된다.

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Bean(value = "localeResolver")
  public LocaleResolver localeResolver() {
    AcceptHeaderLocaleResolver acceptHeaderLocaleResolver = new AcceptHeaderLocaleResolver();
    acceptHeaderLocaleResolver.setDefaultLocale(Locale.KOREAN);
    return acceptHeaderLocaleResolver;
  }
}
```

`AcceptHeaderLocaleResolver` 는 사용자의 요청 메시지의 `Accept-Language` 헤더에 값을 사용하여 Locale 객체를 생성하고,  
`CookieLocaleResolver` 는 쿠키에 Locale 을 저장/사용하며,  
`SessionLocaleResolver` 는 세션에 Locale 을 저장/사용한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)