---
layout: post
title:  "Spring Cloud - Netflix Zuul(Ribbon) Retry"
date: 2020-12-06 10:00
categories: dev
tags: msa zuul hystrix-timeout ribbon-timeout
---
이 포스트는 Zuul (Ribbon) Retry 와 Zuul 타임아웃에 대해 기술한다.

<!-- TOC -->
  * [1. Retry](#1-retry)
  * [2. Zuul (Ribbon) Retryable 설정](#2-zuul-ribbon-retryable-설정)
  * [3. Ribbon 설정](#3-ribbon-설정)
  * [4. Hystrix 설정](#4-hystrix-설정)
  * [5. Zuul, Ribbon, Hystrix 의 타임아웃 관계](#5-zuul-ribbon-hystrix-의-타임아웃-관계)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## 1. Retry

Spring Cloud Netflix 는 `load balanced RestTemplate`, `Ribbon`, `Feign` 등 HTTP Requests 생성하는 다양한 방법을 제공한다.<br /> 


> *`load balanced RestTemplate` 는 [Spring Cloud - Spring Cloud Eureka](https://assu10.github.io/dev/2020/08/16/spring-cloud-eureka/) 의
> 3.3. 서비스 검색 을 참고하시면 도움이 됩니다.*
>
> *`Feign` 는 [Spring Cloud - Spring Cloud Feign](https://assu10.github.io/dev/2020/06/18/spring-cloud-feign/) 을 참고하시면 
> 도움이 됩니다.*

HTTP Request 를 생성하는 방법에 관계없이 Request 는 항상 실패할 가능성이 있는데 이 때 자동으로 요청을 재시도 (Retry) 할 수 있도록 설정할 수 있다.

이 포스트에선 Request 가 실패할 경우 Zuul 에서 Ribbon 을 통해 다른 서버로 Request 를 시도하도록 설정하는 방법에 대해 알아본다. 

---

## 2. Zuul (Ribbon) Retryable 설정

이전 [Spring Cloud - Hystrix (회복성 패턴)](https://assu10.github.io/dev/2020/11/01/spring-cloud-hystrix/) 에선 회원 서비스에 히스트릭스를 적용해보았는데,<br />
이번엔 Zuul 에 적용할 예정이므로 Zuul pom 파일에 `spring-cloud-starter-netflix-hystrix` dependency 를 추가한다.

**zuulserver > pom.xml**
```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
</dependency>
```

이제 `zuul.retryable` 속성을 true 로 설정해준다. (디폴트 false)

- **`zuul.retryable`**
    - true 로 설정 시 Ribbon 이 실패한 요청을 자동으로 재시도 (디폴트 false)

> *위 속성 외 다른 속성은 [Spring Cloud - Netflix Zuul(1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/) 과
> [Spring Cloud - OAuth2, Security(1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/) 를 참고하세요.*
    
**zuulserver > application.yml**    
```yaml
zuul:
  ignored-services: '*'       # 유레카 기반 모든 경로 제외
  prefix: /api                # 정의한 모든 서비스에 /api 접두어
  routes:
    event-service: /evt/**
    member-service: /mb/**
  sensitive-headers: Cookie,Set-Cookie    # Zuul 이 하위 서비스에 전파하지 않는 헤더 차단 목록 (디폴트는 Cookie, Set-Cookie, Authorization)
  retryable: true   # 디폴트 false
```
        
---

## 3. Ribbon 설정

이제 Zuul 내의 Ribbon 설정을 진행한다.

`spring-retry` dependency 를 추가해주는데 다른 라이브러리에 이미 포함되어 있는 경우도 있으니 확인해 본 후 추가하도록 한다.

**zuulserver > pom.xml**
```xml
<dependency>
    <groupId>org.springframework.retry</groupId>
    <artifactId>spring-retry</artifactId>
    <version>1.3.0</version>
</dependency>

```

> 속성 이름은 대소문자를 구분하며, 이 속성들 중 일부는 Netflix Ribbon Project 에 정의되어 있기 때문에 [Pascal Case 표기법](https://zetawiki.com/wiki/%EC%B9%B4%EB%A9%9C%ED%91%9C%EA%B8%B0%EB%B2%95_camelCase,_%ED%8C%8C%EC%8A%A4%EC%B9%BC%ED%91%9C%EA%B8%B0%EB%B2%95_PascalCase)을 사용하고,
> Spring Cloud 에 속하는 속성은 Camel Case 를 사용한다.

각 속성의 앞에 {service-id} 생략 시 해당 서비스만 적용이 아닌 전체적으로 설정 적용이 가능하다. 

-  **`{service-id}.ribbon.MaxAutoRetries`**
    - 첫 시도 실패시 같은 서버로 재시도 하는 수 (첫번째 전송은 제외)

-  **`{service-id}.ribbon.MaxAutoRetriesNextServer`**
    - 첫 시도 실패시 다음 서버로 재시도 하는 수 (첫번째 전송은 제외)
    
-  **`{service-id}.ribbon.ConnectTimeout`**
    - HttpClient 의 Connection timeout (디폴트 1,000 ms, 연결과정의 Timeout 시간)
    
-  **`{service-id}.ribbon.ReadTimeout`**
    - HttpClient 의 Read Timeout (디폴트 1,000 ms, 데이터를 읽어오는 과정의 Timeout 시간)

**zuulserver > application.yml**
```yaml
event-service:
  ribbon:
    MaxAutoRetries: 0
    MaxAutoRetriesNextServer: 1
    ConnectTimeout: 1000
    ReadTimeout: 2000
```
                    
---

## 4. Hystrix 설정

이전 포스트인 [Spring Cloud - Hystrix (회복성 패턴)](https://assu10.github.io/dev/2020/11/01/spring-cloud-hystrix/) 에선 java 코드를 통해 hystrix 를 설정했는데
여기선 yaml 을 통해 hystrix 설정을 진행해보도록 한다.

**zuulserver > pom.xml**
```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
</dependency>
```

-  **`hystrix.command.default.circuitBreaker.sleepWindowInMilliseconds`**
    - 서킷 브레이커 차단 후 히스트릭스가 서비스 호출 시도를 대기하는 시간 (디폴트 5,000 ms, 서킷 브레이커가 차단되었을 때 얼마나 지속될지)
    - 5초마다 히스트릭스는 서비스를 호출하는데 호출이 성공하면 서킷 브레이커를 초기화 하고 다시 호출을 허용
    - 호출이 실패하면 서킷 브레이커가 차단된 상태를 유지하고 5초 후 다시 재시도
    
-  **`hystrix.command.default.circuitBreaker.errorThresholdPercentage`**
    - 서킷 브레이커가 열린 후 `requestVolumeThreshold` 값만큼 호출한 후 타임아웃, 예외, HTTP 500 반환등으로 실패해야 하는 호출 비율 (디폴트 50)
    - 반복 시간 간격 중 서킷 브레이커를 차단하는데 필요한 실패 비율
    - 10초(`metrics.rollingStats.timeInMilliseconds`) 시간대 동안 호출이 최소 호출 횟수를 넘으면 히스트릭스는 전체 실패 비율을 조사하기 시작함
    - 전체 실패 비율이 임계치를 초과하면 서킷 브레이커가 열리고 거의 모든 호출이 실패함
      (히스트릭스는 서비스가 회복 여부를 테스트하고 확인할 수 있도록 일부 호출을 허용)

-  **`hystrix.command.default.circuitBreaker.requestVolumeThreshold`**
    - 히스트릭스가 호출 차단을 고려하는데 필요한 시간인 10초(`metrics.rollingStats.timeInMilliseconds`) 동안 연속 호출 횟수 (디폴트 20)
    - 반복 시간 간격 중 서킷 브레이커의 차단 여부를 검토하는데 필요한 최소 요청 수
    - 히스트릭스가 에러를 포착하면 서비스 호출의 실패 빈도 검사용 10초 타이머(`metrics.rollingStats.timeInMilliseconds`)를 시작하는데 이 10초 동안 호출 횟수를 확인함
    - 그 시간대에 발생한 호출 횟수가 최소 호출 횟수 이하라면 히스트릭스는 호출이 다소 실패하더라도 아무런 조치를 하지 않음
    - 예를 들어 10초(`metrics.rollingStats.timeInMilliseconds`) 동안 호출 횟수가 15번이고 15번 모두 실패하더라도 서킷 브레이커는 열리지 않음
        
-  **`hystrix.command.default.metrics.rollingStats.timeInMilliseconds`**
    -  서비스 호출 문제를 모니터할 시간 간격. 즉 서킷 브레이커가 열리기 위한 조건을 체크할 시간. (디폴트 10초)
    
-  **`hystrix.command.default.metrics.rollingStats.numBuckets`**
    - 모니터할 시간 간격에서 유지할 측정 지표의 버킷 수 (디폴트 10)
    - 히스트릭스는 해당 시간 동안 버킷에 측정 비표를 수집하고 통계를 바탕으로 서킷 브레이커 차단 여부 결정
    - 버킷 수는 `metrics.rollingStats.timeInMilliseconds` 에 설정된 밀리초에 균등하게 분할되어야 함
    - 예를 들어 `metrics.rollingStats.timeInMilliseconds` 는 15초이고 버킷 수 5인 경우 
      히스트릭스는 15초 시간 간격을 사용하고 3초 길이의 5개 버킷에 통계 데이터 수집
      
> 확인할 통계 간격이 작고 유지하는 버킷 수가 많을수록 대량 서비스에서 CPU 및 메모리 사용량이 증가하므로
> 측정 지표 수집 간격과 버킷 수를 적절히 설정하여야 한다.      
          
-  **`hystrix.command.default.execution.isolation.thread.timeoutInMilliseconds`**
    - 서킷 브레이커의 타임아웃 시간 (디폴트 1초)
    - Ribbon 의 타임아웃보다 커야 정상적으로 동작함

**zuulserver > application.yml**
```yaml
hystrix:
  command:
    default:
      circuitBreaker:
        sleepWindowInMilliseconds: 5000
        errorThresholdPercentage: 50
        requestVolumeThreshold: 20
      metrics:
        rollingStats:
          timeInMilliseconds: 10000
          numBuckets: 10
#    event-service:   # 이 부분이 없으면 전체적으로 적용됨
      execution:
        isolation:
          thread:
            timeoutInMilliseconds: 5000
```

이제 Eureka Client 인스턴스를 2개 띄운 후 호출 시 라운드 로빈 방식으로 각 인스턴스를 번갈아가며 호출하는 것을 확인할 수 있다.<br />
아래와 같이 포트를 함께 리턴하도록 하면 좀 더 확실한 확인이 가능하다.

[http://localhost:5555/api/evt/event/name/hyori](http://localhost:5555/api/evt/event/name/hyori)

**event-service > EventController.java**
```java
@GetMapping(value = "name/{nick}")
public String getYourName(ServletRequest req, @PathVariable("nick") String nick) {
    return "[EVENT] Your name is " + customConfig.getYourName() + ", nickname is " + nick + ", port is " + req.getServerPort();
}
```

![리턴값에 포트값 노출](/assets/img/dev/2020/1206/port.png)

이제 인스턴스 하나를 강제로 종료 후 [http://localhost:5555/api/evt/event/name/hyori](http://localhost:5555/api/evt/event/name/hyori) 을 지속적으로 호출하여 
다운된 인스턴스 호출 시 자동으로 정상적인 인스턴스로 호출하는지 확인해보도록 하자.
 
혹은 [http://localhost:5555/api/evt/actuator/health](http://localhost:5555/api/evt/actuator/health) 을 지속적으로 호출 시 500 에러가 아닌 status:UP 이 계속 나오면 된다.   


---

## 5. Zuul, Ribbon, Hystrix 의 타임아웃 관계

여기선 이전 포스트인 [Spring Cloud - Netflix Zuul(1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/) 에서 다룬 서비스 타임아웃을 좀 더 상세히
살펴볼 것이다.

Ribbon 의 타임아웃과 hystrix 의 타임아웃은 각각 어떤 역할을 하는 것일까?

***결론적으로 Timeout 설정값은 ribbon,  hystrix 의 값 중 작은 값이 우선 적용*** 된다.

타임아웃에 관련된 각 항목값이 무엇인지 다시 한번 아래 기재했다.

-  **`{service-id}.ribbon.MaxAutoRetries`**
    - 첫 시도 실패시 같은 서버로 재시도 하는 수 (첫번째 전송은 제외)

-  **`{service-id}.ribbon.MaxAutoRetriesNextServer`**
    - 첫 시도 실패시 다음 서버로 재시도 하는 수 (첫번째 전송은 제외)
    
-  **`{service-id}.ribbon.ConnectTimeout`**
    - HttpClient 의 Connection timeout (디폴트 1,000 ms, 연결과정의 Timeout 시간)
    
-  **`{service-id}.ribbon.ReadTimeout`**
    - HttpClient 의 Read Timeout (디폴트 1,000 ms, 데이터를 읽어오는 과정의 Timeout 시간)

-  **`hystrix.command.default.execution.isolation.thread.timeoutInMilliseconds`**
    - 서킷 브레이커의 타임아웃 시간 (디폴트 1초)
    - Ribbon 의 타임아웃보다 커야 정상적으로 동작함

Ribbon 의 timeout 공식은 다음과 같다.

> **ribbonTimeout = (ribbon.ConnectTimeout + ribbon.ReadTimeout) * (ribbon.MaxAutoRetries + 1) * (ribbon.MaxAutoRetriesNextServer + 1)**

즉, 이 포스트의 예제대로라면 ribbon timeout 은 (2 + 1) * (0 + 1) * (1 + 1) = 6 seconds 이다.<br />
히스트릭스의 타임아웃인 `hystrix.command.default.execution.isolation.thread.timeoutInMilliseconds` 는 디폴트가 1초이므로
의도한 6초 이후 타임아웃이 동작하게 하려면 ribbon 과 hystrix 모두 타임아웃 설정이 필요하다. 

아직 타임아웃이 정상적으로 동작하지 않음...
나중에 이어서 올릴 예정..
        
---

## 참고 사이트 & 함께 보면 좋은 사이트
* [Retrying Failed Requests](https://docs.spring.io/spring-cloud-netflix/docs/2.2.6.RELEASE/reference/html/#retrying-failed-requests)
* [Backoff Policy](https://namocom.tistory.com/847)
* [Ribbon properties](https://github.com/Netflix/ribbon/wiki/Getting-Started#the-properties-file-sample-clientproperties)
* [Ribbon properties(번역)](https://sabarada.tistory.com/54)
* [Ribbon Retry](https://sabarada.tistory.com/56)
* [numBuckets](https://github.com/Netflix/Hystrix/wiki/Configuration#metrics.rollingStats.numBuckets)
* [Ribbon 타임아웃 공식 / Zuul, Ribbon and Hystrix timeout confusion #2606](https://github.com/spring-cloud/spring-cloud-netflix/issues/2606)
* [Zuul API Gateway Timeout Error 디폴트값](https://www.appsdeveloperblog.com/zuul-api-gateway-timeout-error/)
* [타임아웃](https://coe.gitbook.io/guide/load-balancing/ribbon)