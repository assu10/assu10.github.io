---
layout: post
title:  "Spring Cloud - Netflix Zuul(1/2)"
date: 2020-08-26 10:00
categories: dev
tags: msa hystrix zuul ribbon
---

이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Netflix Zuul 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

<!-- TOC -->
  * [1. 게이트웨이](#1-게이트웨이)
  * [2. Zuul Proxy](#2-zuul-proxy)
  * [3. Zuul 구축](#3-zuul-구축)
  * [4. Zuul 경로 구성](#4-zuul-경로-구성)
    * [4.1. 서비스 디스커버리를 이용한 자동 경로 매핑](#41-서비스-디스커버리를-이용한-자동-경로-매핑)
    * [4.2. 서비스 디스커버리를 이용한 수동 경로 매핑](#42-서비스-디스커버리를-이용한-수동-경로-매핑)
  * [5. 기존의 Feign Client 수정하여 서비스들 간의 통신도 Zuul 로 통신하도록 하기](#5-기존의-feign-client-수정하여-서비스들-간의-통신도-zuul-로-통신하도록-하기)
  * [6. 서비스 타임아웃](#6-서비스-타임아웃)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

*[Spring Cloud - Netflix Zuul(Ribbon) Retry](https://assu10.github.io/dev/2020/12/06/netflix-zuul-retryable/)* 와 함께 보면 도움이 됩니다.

---

## 1. 게이트웨이
대부분의 마이크로서비스 아키텍처에서 내부적인 마이크로서비스 종단점은 외부에 공개되지 않고 비공개 서비스로 남는다.
공개될 서비스는 API 게이트웨이를 통해 클라이언트에게 공개하는데 그 이유는 아래와 같다.

- 클라이언트는 일부 마이크로서비스만 필요로 함
- 클라이언트별로 적용되어야 할 정책이 있을 경우 그 정책을 여러 곳에 분산하여 적용하는 것보다 한곳에 두고 적용하는 것이 더 간편하고 누락될 위험이 없음
(예를 들면 cors 정책 적용 등)
- 마이크로서비스 같은 분산형 아키텍처에서는 여러 서비스 호출 사이에서 발생하는 보안, 로깅, 사용자 추적 등을 확인할 수 있어야 함

위와 같은 니즈를 해결하기 위해 게이트웨이에서 횡단 관심사들을 독립적인 위치에서 마이크로서비스 호출에 대한 필터와 라우터 역할을 한다.
서비스 클라이언트가 서비스를 직접 호출하는 것이 아니라 단일한 정책 시행 지점 역할을 하는 서비스 게이트웨이로 모든 호출을 경유 시켜 최종 목적지로 라우팅한다.

<details markdown="1">
<summary>횡단 관심사들 (Click!)</summary>

- 비즈니스 로직과 같은 주요 기능을 핵심 관심사라고 하고, 보안/로깅/추적처럼 애플리케이션에 영향을 미치는 관심사를 횡단 관심사라고 함
</details>

---

## 2. Zuul Proxy
Zuul Proxy 는 내부적으로 서비스 발견을 위해 Eureka 서버를 사용하고, 부하 분산을 위해 Ribbon 을 사용한다.

Zuul Proxy 는 특히 아래의 상황에서 더 유용하다.

>   - 인증이나 보안을 모든 마이크로서비스 종단점에 적용하는 대신 게이트웨이 한곳에 적용
>       - 요청을 서비스에 전달하기 전에 보안 정책 적용, 토큰 처리 등을 수행
>       - 특정 블랙리스트 사용자로부터의 요청을 거부하는 등의 비즈니스 정책 수행
>       - 모든 서비스 호출 시 필요한 광범위한 작업을 일관된 방식으로 수행 가능
>   - 실시간 통계 데이터를 수집 후 수집된 데이터를 외부에 있는 분석 시스템에 전달
>   - 세밀한 제어를 필요로 하는 동적 라우팅 수행
>       - 요청 발생 국가와 같이 비즈니스에서 정하는 특정 값에 따라 요청을 분류하여 다른 곳으로 라우팅
>   - 부하 슈레딩(shredding)이나 부하 스로틀링(throttling)

<details markdown="1">
<summary>부하 슈레딩과 부하 스로틀링 (Click!)</summary>

- 부하 슈레딩: 장비를 닫기 위해 부하를 점진적으로 줄여나가는 것
- 부하 스로틀링: 장비를 기동한 후 부하를 점진적으로 늘려나가는 것
</details>
<br />
Zuul 은 사전 필터, 라우팅 필터, 사후 필터, 에러 필터 등을 제공하여 서비스 호출의 서로 다른 여러 단계에 적용할 수 있도록 지원한다.
또한 추상 클래스인 ZuulFilter 를 상속하여 자체 필터를 작성할 수도 있다.

Zuul 의 동작 흐름을 살펴보면 아래와 같다.

서비스 클라이언트는 개별 서비스의 URL 을 직접 호출하지 않고 Zuul 로 모든 요청을 보내고, (=애플리케이션의 모든 서비스 경로를 단일 URL 로 매핑)
Zuul 은 받은 요청을 추려내서 호출하고자 하는 서비스로 라우팅한다.

![Zuul동작 흐름](/assets/img/dev/2020/0826/zuul.png)

>Zuul 은 기동 시 Eureka Server 에 Zuul 서비스 ID를 등록한다.<br /><br />
>서비스 클라이언트이기도 한 이벤트 마이크로서비스는 Zuul 서비스 ID를 이용하여 Eureka Server 로부터 Zuul 서버 목록을 얻는다.<br /><br />
>URL 을 통해 회원 마이크로서비스 물리적 위치를 찾아 라우팅한다.

***Zuul 은 서비스 호출에 대한 병목점이므로 Zuul 의 코드는 최대한 가볍게 유지하는 것이 좋다.***

이 포스트는 아래의 순서로 진행될 예정이다.

1. 하나의 URL 뒤에 모든 서비스를 배치하고 유레카를 이용해 모든 호출을 실제 서비스 인스턴스로 매핑
2. 서비스 게이트웨이를 경유하는 모든 서비스 호출에 상관관계 ID 삽입
3. 호출 시 생성된 상관관계 ID를 HTTP 응답에 삽입하여 클라이언트에 회신
4. 대중이 사용 중인 것과 다른 회원 서비스 인스턴스 엔드포인트로 라우팅하는 동적 라우팅 메커니즘 구축

---

## 3. Zuul 구축
이번 포스트인 [Config Server](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)와 [유레카](https://assu10.github.io/dev/2020/08/16/spring-cloud-eureka/)를 구축했다면 아래 구성도가 셋팅되어 있을 것이다.

![Config Server + 유레카](/assets/img/dev/2020/0816/config_eureka.png)

위 설정에 Zuul 을 추가하면 아래와 같은 구성도가 된다.

![Config Server + 유레카 + Zuul](/assets/img/dev/2020/0826/config_eureka_zuul.png)

Zuul 도 자신의 서비스 ID 로 Eureka Server 에 자신을 등록한다.<br />
그리고 Zuul 을 호출하는 클라이언트도 Eureka Client 라면 유레카 레지스트리에 등록된 Zuul 의 서비스 ID를 통해 Zuul 에 접근하므로
Zuul 의 이중화 구성 시 별도의 로드밸런서는 필요 없다.
(Eureka Client 는 Eureka Server 로부터 받아온 Zuul 서버 목록 중 하나를 선택하여 호출)<br />

새로운 스트링부트 프로젝트 생성 후 Zuul, Config Client, Eureka Discovery, Actuator Dependency 를 추가한다.

**pom.xml**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-config</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-zuul</artifactId>
</dependency>
```

Zuul 서비스 구현을 위해 부트스트랩 클래스에 `@EnableZuulProxy` 을 추가한다.

**ZuulserverApplication**
```java
@SpringBootApplication
@EnableZuulProxy        // Zuul 서버로 사용
public class ZuulserverApplication {
    public static void main(String[] args) {
        SpringApplication.run(ZuulserverApplication.class, args);
    }
}
```

`@EnableZuulServer`는 유레카가 아닌 서비스 디스커버리 엔진(Consul 같은...)과 통합할 경우 사용한다.
또한 자체 라우팅 서비스를 만들고 내장된 Zuul 기능을 사용하지 않을 때도 사용한다.

Zuul 은 자동으로 유레카를 사용해 서비스 ID로 서비스를 찾은 후 Ribbon 으로 Zuul 내부에서 클라이언트 측 부하 분산을 수행한다.

Config Server 구성 경로 추가한다.

**configserver > bootstrap.yaml**
```yaml
spring:
  application:
    name: configserver
  cloud:
    config:
      server:
        git:
          uri: https://github.com/assu10/config-repo.git
          username: assu10
          password: '{cipher}f38ff3546220bbac52d81c132916b1b1fd7c3cfdcfdf408760d1c4bf0b4ee97c'
          search-paths: member-service, event-service, eurekaserver, zuulserver    # 구성 파일을 찾을 폴더 경로
        encrypt:
          enabled: false
```

Zuul 과 Config Server가 통신할 수 있도록 설정한다.

**zuulserver > application.yaml, bootstrap.yaml**
```yaml
# zuulserver > application.yaml
server:
  port: 5555


# zuulserver > bootstrap.yaml
spring:
  application:
    name: zuulserver    # 서비스 ID (컨피그 클라이언트가 어떤 서비스를 조회하는지 매핑)
  profiles:
    active: default         # 서비스가 실행할 기본 프로파일
  cloud:
    config:
      uri: http://localhost:8889  # Config Server 위치
```

Config Server 원격 저장소에 zuulserver(서비스 ID) 폴더 생성 후 유레카 사용을 위한 설정을 해준다.

**config-repo > zuulserver > zuulserver.yaml**
```yaml
# config-repo > zuulserver > zuulserver.yaml

your.name: "ZUUL DEFAULT"
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: '{cipher}17b3128621cb4e71fbb5a85ef726b44951b62fac541e1de6c2728c6e9d3594ec'
management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    shutdown:
      enabled: true
eureka:
  instance:
    prefer-ip-address: true   # 서비스 이름 대신 IP 주소 등록
  client:
    register-with-eureka: true    # Eureka Server 에 서비스 등록
    fetch-registry: true          # 레지스트리 정보를 로컬에 캐싱
    service-url:
      dafaultZone: http://localhost:8761/eureka/
```

[http://localhost:8761/](http://localhost:8761/) 유레카 콘솔로 접속하면 Zuul 이 등록된 것을 확인할 수 있다.
[http://localhost:5555/actuator/env](http://localhost:5555/actuator/env) 로 접속하면 Zuul 이 잘 떴는지 확인할 수 있다.

---

## 4. Zuul 경로 구성
Zuul 은 클라이언트와 자원 사이에 위치한 중개 서버로 클라이언트가 요청한 호출을 해당 자원으로 매핑을 하는데 이때 매핑 메커니즘은 3가지가 있다.

- 서비스 디스커버리를 이용한 자동 경로 매핑
- 서비스 디스커버리를 이용한 수동 경로 매핑
- 정적 URL 을 이용한 수동 경로 매핑

여기서 정적 URL 을 이용한 수동 경로 매핑은 유레카로 관리하지 않는 서비스를 라우팅할 때 사용하는데 이 포스트에선 다루지 않을 예정이다.

---

### 4.1. 서비스 디스커버리를 이용한 자동 경로 매핑
Zuul 은 application.yaml 에 경로를 정의하여 매핑하는데 유레카와 함께 사용하면 특별한 구성 없이 서비스 ID 기반으로 자동 라우팅을 지원한다.
아래의 주소를 보자.

`http://localhost:5555/event-service/event/member/hyori`

- http://localhost:5555 - Zuul 주소
- event-service - 서비스 ID
- event/member/hyori - 실제 호출될 URL 엔드포인트

서비스의 엔드포인트 경로 첫 부분에 서비스 ID를 기입하는 것만으로 간편하게 라우팅이 가능하다.

유레카와 Zuul 을 함께 사용하면 호출할 수 있는 단일 엔드포인트를 제공할 뿐 아니라
유레카에 새로운 서비스 추가 시 Zuul 은 자동으로 해당 서비스 인스턴스로 라우팅하기 때문에 Zuul 수정 없이 인스턴스를 추가/제거가 가능하다.

Zuul 이 관리하는 경로는 `/routes` 엔드포인트로 접근하여 확인할 수 있다.

아래 그림에서 Zuul 에 등록된 서비스들의 매핑은 "event-service/**" 이고, 유레카에 등록된 서비스 아이디는 "event-service" 이다. 

[http://localhost:5555/actuator/routes](http://localhost:5555/actuator/routes)

![Zuul 매핑 경로](/assets/img/dev/2020/0826/routes.png)


실제로 매핑된 대로 잘 호출이 되는지 확인해보자.
이벤트 마이크로서비스의 API 를 직접 호출하는 것을 이제 Zuul 을 통해 호출해보자.

![Zuul 을 통해 API 호출](/assets/img/dev/2020/0826/routing.png)

---

### 4.2. 서비스 디스커버리를 이용한 수동 경로 매핑
유레카 서비스 ID로 자동 생성된 경로에 의존하지 않고 명시적으로 정의하여 더욱 세분화 할 수도 있다.
서비스 ID가 `event-service`인 이벤트 서비스의 경우 자동 경로 매핑 경로는 아래와 같았다.

`http://localhost:5555/event-service/event/member/hyori`

이제 수동으로 경로를 매핑해보자.

**config-repo > zuulserver > application.yaml**
```yaml
zuul:
  routes:
    event-service: /evt/**
```

이후 [POST http://localhost:5555/actuator/bus-refresh](http://localhost:5555/actuator/bus-refresh) 를 호출하여 경로 구성을 다시 적용할 수 있다. 

[http://localhost:5555/actuator/routes](http://localhost:5555/actuator/routes) 경로로 접속하여 Zuul 이 관리하고 있는 경로를 확인해보자.

![수동 매핑](/assets/img/dev/2020/0826/event.png)

`"/evt/**": "event-service"` 가 추가된 것을 확인할 수 있다.
`/evt/**`로 요청되는 호출은 `event-service` 서비스 ID를 가진 마이크로서비스로 매핑한다는 의미이다.

그리고 그 아래 Zuul 에 의해 자동으로 매핑된 경로인 `"/event-service/**": "event-service"` 도 여전히 함께 있다.
만일 수동으로 매핑한 경로만 사용하고 싶다면 아래와 같은 코드를 추가해주면 된다.

**config-repo > zuulserver > application.yaml**
```yaml
zuul:
  ignored-services: 'event-service'   # 자동 경로 매핑 무시, 쉼표로 한 번에 여러 서비스 제외 가능
  routes:
    event-service: /evt/**
```

만일 유레카 기반의 모든 경로를 제외하려면 `ignored-services` 속성을 `*`로 설정하면 된다.

![수동 매핑](/assets/img/dev/2020/0826/event2.png)

`"/event-service/**": "event-service"` 매핑 정보가 사라진 것을 확인할 수 있다.

그럼 이제 수동 매핑된 경로로 라우팅이 되는지 [http://localhost:5555/**evt**/event/member/hyori](http://localhost:5555/evt/event/member/hyori)를 호출하여 확인해보자.

![수동 매핑 호출](/assets/img/dev/2020/0826/event3.png)


API 게이트웨이의 일반적인 패턴은 모든 서비스 호출 앞에 /api 처럼 레이블을 붙여 콘텐츠 경로를 구별한다.
Zuul 의 `prefix` 프로퍼티가 이러한 기능을 지원한다.

**config-repo > zuulserver > application.yaml**
```yaml
zuul:
  ignored-services: '*'       # 유레카 기반 모든 경로 제외
  prefix: /api                # 정의한 모든 서비스에 /api 접두어
  routes:
    event-service: /evt/**
    member-service: /mb/**
```

[http://localhost:5555/actuator/routes](http://localhost:5555/actuator/routes)를 보면 모든 서비스 매핑 URL 에 /api 가 추가된 것을 확인할 수 있다.

```json
{
    "/api/evt/**": "event-service",
    "/api/mb/**": "member-service"
}
```

변경된 주소로 API 를 호출해보자.

```text
// http://localhost:5555/api/evt/event/member/hyori 호출 결과

[MEMBER] Your name is MEMBER DEFAULT... / nickname is hyori / port is 8090
```

---

## 5. 기존의 Feign Client 수정하여 서비스들 간의 통신도 Zuul 로 통신하도록 하기
이제 기존에 이벤트 서비스에서 Feign 을 이용하여 회원 서비스의 REST API 를 직접 호출하는 부분을 이제 Zuul 을 통해 호출하도록 수정해보자.<br />
(잘 기억이 나지 않는다면 [유레카](https://assu10.github.io/dev/2020/08/16/spring-cloud-eureka/) 의 *3.3. 서비스 검색 (Feign 사용)*과
[Open Feign](https://assu10.github.io/dev/2020/06/18/spring-cloud-feign/) 을 참고하세요) 

- 기존 : 이벤트 서비스 → 회원 서비스 (Feign 이용하여 **직접 호출**)
- 수정 : 이벤트 서비스 → 회원 서비스 (Feign 이용하여 **Zuul 통하여 호출**)

수정은 간단하다.
@FeignClient 에 들어가는 서비스 ID와 최종 URL 만 수정해주면 된다.

컨피스 원격 저장소의 이벤트 서비스 설정 파일에 아래 내용을 추가한다.

**config-repo > event-service > event-service.yaml**
```yaml
service:
  id:
    member: member-service
    zuul: zuulserver    # Zuul 서비스 아이디 추가
```

이후 이벤트 서비스 내에 있는 MemberFeignClient 파일을 아래와 같이 수정한다.

**event-service > client > MemberFeignClient.java**
```java
//@FeignClient("${service.id.member}")
@FeignClient("${service.id.zuul}")      // Zuul 의 서비스 아이디로 수정
public interface MemberFeignClient {
    
    String URL_PREFIX = "/api/mb/member/";      // 회원 서비스의 Zuul 라우팅 경로와 회원 클래스 주소

    /**
     * Zuul 을 통해 호출할 경로 : http://localhost:5555/api/evt/event/member/{nick}
     */
    @GetMapping(value = URL_PREFIX + "name/{nick}")
    String getYourName(@PathVariable("nick") String nick);
}
```

![마이크로서비스 간 Zuul 통신 확인](/assets/img/dev/2020/0826/feignzuul.png)

---

## 6. 서비스 타임아웃

>[Spring Cloud - Hystrix (회복성 패턴)](https://assu10.github.io/dev/2020/08/26/spring-cloud-hystrix/) 의 
>*개별 회로 차단기를 사용자 정의하여 호출별 타임아웃 설정* 과 함께 보면 도움이 됩니다. 

Zuul 은 넷플릭스 히스트릭스와 리본 라이브러리를 사용하여 오래 수행되는 서비스 호출이 게이트웨이 성능에 영향을 미치지 않도록 한다.

기본적으로 Zuul 은 요청을 처리하는데 1초 이상 걸리는 모든 호출을 종료하고 HTTP 500 에러를 반환한다. (히스트릭스 기본 동작)

- 히스트릭스 타임아웃 설정
    - `hystrix.command.default.execution.isolation.thread.timeoutInMilliseconds` : 기본 1초
    - `hystrix.command.event-service.execution.isolation.thread.timeoutInMilliseconds` : 특정 서비스만 별도의 히스트릭스 타임아웃 설정
    
- 리본 타임아웃 설정
    - `event-service.ribbon.ReadTimeout`

**config-repo > zuulserver > zuulserver.yaml**
```yaml
hystrix:
  command:
    default:    # 유레카 서비스 ID
      execution:
        isolation:
          thread:
            timeoutInMilliseconds: 5000   # 히스트릭스 타임아웃 5초로 설정 (기본 1초, ribbon 의 타임아웃보다 커야 기대하는 대로 동작함)
```

이벤트 서비스의 특정 API 를 8초 이후에 리턴값을 반환하도록 설정 후 호출하면 아래와 같이 504 오류가 반환된다.

[http://localhost:5555/api/evt/event/name/hyori](http://localhost:5555/api/evt/event/name/hyori) 호출 시 반환값

```json
{
    "timestamp": "2020-08-30T12:58:38.493+00:00",
    "status": 504,
    "error": "Gateway Timeout",
    "message": ""
}
``` 

~~히스트릭스 타임아웃을 재정의했지만 리본 역시 5초 이상 수행되는 호출을 타임아웃하므로 5초 이상 수행되는 타임아웃 구성은 히스트릭스와 리본 모두 설정해야 한다.~~

다음 포스트엔 Zuul 의 필터에 관해 다루도록 하겠다.

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/](https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/)
