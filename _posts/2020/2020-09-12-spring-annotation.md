---
layout: post
title:  "Spring 어노테이션 정리"
date: 2020-09-12 10:00
categories: dev
tags: backend spring-annotation 
---

스프링 어노테이션에 대한 간단한 요약이다.
용어 인덱싱 용도의 포스트이고, 자세한 내용은 필요할 때마다 검색해서 찾아보세요.

어노테이션 검색하다 보니 제가 원하던 스타일로 정리를 잘 해놓은 [블로그](https://jeong-pro.tistory.com/151)가 있어서 가져온 내용입니다.
(다음에 그 블로그 못 찾을까봐...)

<!-- TOC -->
  * [@ComponentScan](#componentscan)
  * [@EnableAutoConfiguration](#enableautoconfiguration)
  * [@Configuration](#configuration)
  * [@Resource](#resource)
  * [@PostConstruct, @PreConstruct](#postconstruct-preconstruct)
  * [@PreDestroy](#predestroy)
  * [@PropertySource](#propertysource)
  * [@ConfigurationProperties](#configurationproperties)
  * [@Lazy](#lazy)
  * [@Value](#value)
  * [@SpringBootApplication](#springbootapplication)
  * [@CookieValue](#cookievalue)
  * [@CrossOrigin](#crossorigin)
  * [@ModelAttribute](#modelattribute)
  * [@SessionAttributes](#sessionattributes)
  * [@RequestBody](#requestbody)
  * [@RequestHeader](#requestheader)
  * [@RequestParam](#requestparam)
  * [@RequestPart](#requestpart)
  * [@ResponseBody](#responsebody)
  * [@PathVariable](#pathvariable)
  * [@ExceptionHandler(ExceptionClassName.class)](#exceptionhandlerexceptionclassnameclass)
  * [@ControllerAdvice](#controlleradvice)
  * [@RestControllerAdvice](#restcontrolleradvice)
  * [@ResponseStatus](#responsestatus)
  * [@Transactional](#transactional)
  * [@Cacheable](#cacheable)
  * [@CachePut](#cacheput)
  * [@CacheEvict](#cacheevict)
  * [@CacheConfig](#cacheconfig)
  * [@Scheduled](#scheduled)
  * [@Valid](#valid)
  * [@InitBinder](#initbinder)
  * [@Required](#required)
  * [@Qualifier("id123")](#qualifierid123)
  * [@ConditionalOnProperty](#conditionalonproperty)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## @ComponentScan
@Component 와 @Service, @Repository, @Controller, @Configuration 이 붙은 클래스 Bean 들을 찾아서 Context 에 bean 등록 해주는 Annotation<br />
base-package 를 넣으면 해당 패키지 아래에 있는 컴포넌트들을 찾고 그 과정을 spring-context-버전(4.3.11.RELEASE).jar 에서 처리.

@Component 로 다 쓰지 왜 굳이 @Repository, @Service, @Controller 등을 사용하는 이유는 예를 들어 
@Repository 는 DAO 의 메서드에서 발생할 수 있는 unchecked exception 들을 스프링의 DataAccessException 으로 처리할 수 있기 때문.
또한 가독성에서도 해당 애노테이션을 갖는 클래스가 무엇을 하는지 단 번에 알 수 있다.

## @EnableAutoConfiguration
스프링 애플리케이션 컨텍스트를 만들 때 자동으로 설정하는 기능을 켠다.<br />
classpath 의 내용에 기반해서 자동 생성해준다.

## @Configuration
Configuration 을 클래스에 적용하고 @Bean 을 해당 클래스의 메서드에 적용하면 @Autowired 로 빈을 부를 수 있다.

## @Resource
@Autowired 와 마찬가지로 빈 객체를 주입해주는데 차이점은 Autowired 는 타입으로, Resource 는 이름으로 연결해준다.

## @PostConstruct, @PreConstruct
의존하는 객체를 생성한 이후 초기화 작업을 위해 객체 생성 전/후에(pre/post) 실행해야 할 메서드 앞에 붙인다.

## @PreDestroy
객체를 제거하기 전(pre)에 해야할 작업을 수행하기 위해 사용한다.

## @PropertySource
해당 프로퍼티 파일을 Environment 로 로딩하게 해준다.<br />
클래스에 @PropertySource("classpath:/settings.properties")라고 적고 
클래스 내부에 @Resource 를 Environment 타입의 멤버변수앞에 적으면 매핑됨

## @ConfigurationProperties
yaml 파일 읽는다.<br />
default 로 classpath:application.properties 파일이 조회된다.<br />

## @Lazy
지연로딩을 지원한다.<br />
@Component 나 @Bean 애노티에션과 같이 쓰는데 클래스가 로드될 때 스프링에서 바로 bean 등록을 마치는 것이 아니라 
실제로 사용될 때 로딩이 이뤄지게 하는 방법

## @Value
*.properties 에서 값을 가져와 적용할 때 사용<br />
```java
@Value("${value.from.file}")
private String valueFromFile;
```

spEL을 이용해서 조금 더 고급스럽게 쓸 수 있다.
```java
@Value(#{systemProperties['priority'] ?: 'some default'})
```

## @SpringBootApplication
@Configuration, @EnableAutoConfiguration, @ComponentScan 3가지를 하나의 애노테이션으로 합친 것

## @CookieValue
쿠키 값을 파라미터로 전달 받을 수 있는 방법<br />
해당 쿠키가 존재하지 않으면 500 에러를 발생<br />
속성으로 required 가 있는데 default 는 true.<br />
false 를 적용하면 해당 쿠키 값이 없을 때 null 로 받고 에러를 발생시키지 않는다.

```java
public String view(@CookieValue(value="auth") String auth){...};     // 쿠키의 key 가 auth 에 해당하는 값을 가져옴
```

## @CrossOrigin
CORS 보안상의 문제로 브라우저에서 리소스를 현재 origin 에서 다른 곳으로의 AJAX 요청을 방지하는 것이다.<br />
@RequestMapping 이 있는 곳에 사용하면 해당 요청은 타 도메인에서 온 ajax 요청을 처리해준다.<br />

```java
// 기본 도메인이 http://www.google.com 인 곳에서 온 ajax 요청만 받음
@CrossOrigin(origins = "http://www.google.com", maxAge = 3600)
```

## @ModelAttribute
view 에서 전달해주는 파라미터를 클래스(VO/DTO)의 멤버 변수로 binding 해주는 어노테이션<br />
바인딩 기준은 `<input name="id" />` 처럼 어떤 태그의 name 값이 해당 클래스의 멤버 변수명과 일치해야 하고 setter 메서드명도 일치해야 한다.

## @SessionAttributes
세션에 데이터를 넣을 때 사용<br />
```java
// Model 에 key 값이 "name"으로 있는 값은 자동으로 세션에도 저장
@SessionAttributes("name")
```

##@RequestAttribute
Request 에 설정되어 있는 속성 값을 가져올 수 있다.

## @RequestBody
요청이 온 데이터(JSON 이나 XML 형식)를 바로 클래스나 model 로 매핑하기 위한 어노테이션

## @RequestHeader
Request 의 header 값을 가져올 수 있다. 메서드의 파라미터에 사용
```java
@RequestHeader(value="Accept-Language") String acceptLanguage  //ko-KR,ko;q=0.8,en-US;q=0.6
```

## @RequestParam
@PathVariable 과 비슷하다. request 의 parameter 에서 가져오는 것이다. 메서드의 파라미터에 사용됨

## @RequestPart
Request 로 온 MultipartFile 을 바인딩함<br />
@RequestPart("file") MultipartFile file 로 받아올 수 있음.

## @ResponseBody
view 가 아닌 JSON 형식의 값을 응답할 때 사용하는 어노테이션으로 문자열을 리턴하면 그 값이 
http response header 가 아닌 response body 에 들어간다.<br />
만약 객체를 return 하는 경우 JACKSON 라이브러리에 의해 문자열로 변환되어 전송된다.<br />
context 에 설정된 resolver 를 무시한다고 보면된다. (viewResolver)

## @PathVariable
메서드 파라미터 앞에 사용하면 해당 URL 에서 {특정값}을 변수로 받아 올 수 있다.

## @ExceptionHandler(ExceptionClassName.class)
해당 클래스의 예외를 캐치하여 처리한다.

## @ControllerAdvice
클래스 위에 ControllerAdvice 를 붙이고 어떤 예외를 잡아낼 것인지는 
각 메서드 상단에 @ExceptionHandler(에외클래스명.class)를 붙여서 기술한다.

## @RestControllerAdvice
@ControllerAdvice + @ResponseBody

## @ResponseStatus
원하는 response code 와 reason 을 리턴

```java
// 예외처리 함수 앞에 사용한다.
@ResponseStatus(value = HttpStatus.NOT_FOUND, reason = "my page URL changed..")
```

## @Transactional
```java
// rollbackFor: 해당 Exception 이 생기면 롤백
@Transaction(readOnly=true, rollbackFor=Exception.class)

// 해당 Exception 이 나타나도 롤백하지 않음
@Transaction(noRollbackFor=Exception.class)

// 10초 안에 해당 로직을 수행하지 못하면 롤백
@Transaction(timeout = 10)
```

## @Cacheable
메서드 앞에 지정 후 해당 메서드를 최초에 호출하면 캐시에 적재하고 다음부터는 동일한 메서드 호출이 있을 때 
캐시에서 결과를 가져와서 리턴하므로 메서드 호출 횟수를 줄여줌<br />
주의할 점은 입력이 같으면 항상 출력이 같은 메서드(=순수 함수)에 적용해야 한다.<br />
그런데 또 항상 같은 값만 뱉어주는 메서드에 적용하려면 조금 아쉬울 수 있다.<br />
따라서 메서드 호출에 사용되는 자원이 많고 자주 변경되지 않을 때 사용하고 나중에 수정되면 캐시를 없애는 방법을 선택할 수 있다.

```java
@Cacheable(value="cacheKey")
@Cacheable(key="cacheKey")
```

## @CachePut
캐시를 업데이트 하기 위해서 메서드를 항상 실행하게 강제<br />
해당 애노테이션이 있으면 항상 메서드 호출함.<br />
그러므로 @Cacheable 과 같이 사용하면 안된다.

## @CacheEvict
캐시에서 데이터를 제거하는 트리거로 동작하는 메서드<br />
물론 캐시 설정에서 캐시 만료시간을 줄 수도 있다.<br />

```java
@CacheEvict(value="cacheKey")

// 전체 캐시를 지울지 여부
@CacheEvict(value="cacheKey", allEntries=true)
```

## @CacheConfig
클래스 레벨에서 공통의 캐시설정을 공유

## @Scheduled
Linux 의 crontab 역할

```java
// "초 분 시 일 월 요일 년(선택)에 해당 메서드 호출
@Scheduled(cron = "0 0 07 * * ?")
```

## @Valid
유효성 검증이 필요한 객체임을 지정

## @InitBinder
@Valid 애노테이션으로 유효성 검증이 필요하다고 한 객체를 가져오기전에 수행해야 할 메서드를 지정한다.

## @Required
setter 메서드에 적용해주면 빈 생성시 필수 프로퍼티 임을 알린다.

## @Qualifier("id123")
@Autowired 와 같이 쓰이며, 같은 타입의 빈 객체가 있을 때 해당 아이디를 적어 원하는 빈이 주입될 수 있도록 함

## @ConditionalOnProperty
@ConditionalOnProperty(name="use.db.event", havingValue = "true") 와 같이 사용

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [기본기를 쌓는 정아마추어 코딩블로그](https://jeong-pro.tistory.com/151)