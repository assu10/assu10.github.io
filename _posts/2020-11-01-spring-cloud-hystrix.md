---
layout: post
title:  "Spring Cloud - Hystrix (회복성 패턴)"
date:   2020-11-01 10:00
categories: dev
tags: msa hystrix  
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Spring Cloud Hystrix 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2. Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3. Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4. Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br />
>[5. OAuth2, Security - 보안 (1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/)<br />
>[6. OAuth2, Security - 보안 (2/2)](https://assu10.github.io/dev/2020/09/30/spring-cloud-oauth2.0-2/)<br />
>[7. Spring Cloud Stream, 분산 캐싱 (1/2)](https://assu10.github.io/dev/2020/10/01/spring-cloud-stream/)<br />
>[8. Spring Cloud Stream, 분산 캐싱 (2/2)](https://assu10.github.io/dev/2020/11/01/spring-cloud-stream-2/)<br /><br />
>***9. Spring Cloud - Hystrix (회복성 패턴)***<br />
>- 스프링 클라우드 스트림을 사용한 분산 캐싱
>- 분산 캐싱 구현
>   - 스프링 데이터 레디스 의존성 추가
>   - 레디스 DB 커넥션을 설정
>   - 스프링 데이터 레디스의 Repository 클래스를 정의

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

모든 시스템은 장애를 겪는데 이러한 장애에 대응할 수 있는 애플리케이션을 구축하는 것은 매우 중요하다.

서비스 하나가 다운되면 쉽게 감지하고 해당 서비스는 우회할 수 있지만,
아래와 같은 이유로 <u>서비스가 느려질 때 성능 저하를 감지하고 우회하는 것은 매우 어렵다.</u>

- **서비스 저하는 간헐적으로 발생하고 확산될 수 있음**
    - 서비스 저하는 사소한 부분에서 갑자기 발생할 수 있는데 순식간에 스레드 풀을 모두 소진해 완전히 다운되기 전까지는
    장애 징후를 쉽게 발견하기 어려움
- **원격 서비스 호출은 대부분 동기식이며, 오래 걸리는 호출을 중단하지 않음**
    - 클라이언트는 호출에 대한 타임아웃 개념이 없으므로 서비스가 응답할 때까지 대기함
- **애플리케이션은 대부분 부분적인 저하가 아닌 원격 자원의 완전한 장애를 처리하도록 설계됨**
    - 서비스가 완전히 다운되지 않으면 클라이언트는 서비스를 계속 호출하고 빨리 실패하지 않는 일이 자주 발생하게 됨으로써
    클라이언트는 자원 고갈로 인해 비정상적으로 종료될 가능성이 높음
    
> **자원 고갈**
>
>스레드 풀이나 데이터베이스 커넥션 같은 제한된 자원이 고갈된 경우 클라이언트가 해당 자원이 가용 상태가 될 때까지 대기하는 상황    

정상 동작하지 않는 원격 서비스의 문제가 심각한 이유는 탐지하기 어려울 뿐 아니라 애플리케이션 전체에 미치는 파급 효과가 크기 때문이다.<br />
마이크로서비스에 기반을 둔 애플리케이션이 이러한 유형의 장애에 특히 취약한 이유는 하나의 트랜잭션을 완료하는데 여러 분산된 서비스로 구성되기 때문이다.

하여 이 포스트에선 위와 같은 상황을 방지할 수 있도록 아래와 같은 순서로 **Spring Cloud Netflix Hystrix** 를 사용하여 **클라이언트 회복성 패턴**에 대해 알아본다.

- Hystrix 애너테이션을 사용하여 Circuit Breaker (회로 차단기) 패턴으로 원격 호출 실행
- 개별 회로 차단기를 사용자 정의하여 호출별 타임아웃 설정 (회로 차단기가 작동하기 전에 발생할 실패 횟수 조절)
- 회로 차단기가 작동할 경우 폴백 전략 구현
- 서비스 내 개별 스레드 풀을 사용하여 서비스 호출을 격리하고, 호출되는 원격 자원 간에 벌크헤드 구축

--- 

## 1. 클라이언트 회복성 패턴

클라이언트 회복성 패턴은 원격 서비스가 에러를 리턴하거나 정상 동작하지 못해 원격 자원의 접근이 실패하는 경우 이를 호출하는 클라이언트 서비스의 
자원 고갈을 막는 데 초점이 맞추어져 있다.<br />
즉, 원격 서비스의 문제가 클라이언트 서비스로 상향 전파되는 것을 막는 것이 목적이다.

클라이언트 회복성 패턴은 아래와 같다.
아래와 같은 패턴은 원격 자원을 호출하는 클라이언트에서 구현한다.

![클라이언트 회복성 패턴](/assets/img/dev/20201101/overall.png)

---

### 1.1 클라이언트 측 부하분산

[Spring Cloud - Spring Cloud Eureka](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/) 에서
클라이언트 측 부하 분산에 대해 설명을 했지만 다시 한번 설명하자면 
**클라이언트 측 부하 분산은 클라이언트가 유레카와 같은 서비스 디스커버리 에이전트를 이용해 서비스의 모든 인스턴스를 검색하여 서비스 인스턴스의
위치를 캐싱한 후 클라이언트가 인스턴스를 호출할 때마다 클라이언트 측 로드 밸런서를 이용하여 서비스 위치를 하나씩 전달받는 것**을 말한다.

클라이언트 측 로드 밸런서는 서비스 인스턴스가 에러를 전달하거나 불량 동작하면 이를 감지하여 사용 서비스 위치 풀에서 해당 서비스 인스턴스를
제거함으로써 문제가 있는 서비스 인스턴스가 호출되는 것을 방지한다.

---

### 1.2 Circuit Breaker (회로 차단기)

회로 차단기 패턴은 전기 회로의 차단기 개념에서 유래한 클라이언트 회복성 패턴이다.
전기 시스템에서 회로 차단기는 문제를 감지하면 모든 전기 시스템과 연결된 접속을 차단하여 연관된 시스템들이 손상되지 않도록 보호하는 역할을 한다.

회로 차단기는 원격 서비스 호출을 모니터링하여 호출이 오래 걸리거나 사전 설정한 값만큼 호출이 실패하면 이를 중재하여 호출이 빨리 실패하게 만듦으로써
문제가 있는 원격 서비스가 더 이상 호출되지 않도록 차단한다.

---

### 1.3 Fallback (폴백 처리)

폴백 패턴은 원격 서비스에 대한 호출이 실패할 경우 예외를 발생시키지 않고 클라이언트 서비스가 대체 코드 경로를 실행하는 것을 의미한다.<br />
일반적으로 다른 데이터 소스에서 데이터를 검색하거나 후처리를 위해 사용자 요청을 큐에 입력하는 작업과 연관된다.

---

### 1.4 Bulkhead (벌크헤드)

벌크헤드 패턴은 선박을 건조하는 개념에서 유래한다. 배는 격벽이라는 구획으로 나뉘는데 배에 구멍이 나더라도 배는 격벽으로 분리되어 있으므로 침구 구역을
제한하여 배 전체의 침수를 방지하는 개념이다.

벌드헤드 패턴을 적용하면 원격 서비스에 대한 호출을 자원별 스레드 풀로 분리하므로 특정 원격 서비스가 느려져도 전체 애플리케이션이 다운되는 위험을
피할 수 있다. 여기서 스레드 풀이 벌그헤드(격벽) 의 역할을 한다.
각 원격 자원은 분리되어 스레드 풀에 할당되고 한 서비스가 느리게 반응하면 해당 서비스 호출을 위한 스레드 풀은 포화되어 요청을 처리하지 못하지만,
다른 스레드 풀에 할당된 다른 서비스 호출은 영향을 받지 않는다. 

---

## 2. 클라이언트 회복성의 중요성

회로 차단기는 문제가 있는 서비스를 차단하여 해당 서비스로의 호출을 막는다.
그리고 성능이 저하된 서비스를 간헐적으로 호출하여 호출이 연속적으로 충분히 성공하면 회로 차단기를 재설정한다.

원격 서비스 호출에서 회로 차단 패턴이 제공하는 핵심 기능은 아래와 같다.

- **빠른 실패**
    - 원격 서비스에 성능 저하 발생 시 애플리케이션은 빨리 실패함으로써 애플리케이션 전체를 다운시킬 수 있는 자원 고갈 이슈를 방지함<br />
    서비스 전체가 다운되는 것보다 부분적으로 다운되는 것이 낫다.
- **원만한 실패**
    - 원격 서비스 호출 실패 시 폴백 패턴을 이용하여 대체 코드를 실행
- **원활한 회복**
    - 회로 차단기는 요청 자원이 정상적인 상태인지 주기적으로 확인하여 사람의 개입없이 자원 접근을 다시 허용
    - 이는 서비스를 복구하는데 필요한 시간을 줄이고 사람이 직접 서비스 복구에 개입함으로써 발생할 수 있는 더 큰 문제가 발생할 수 있는 위험을 낮춤

---

## 3. Hystrix 설정을 위한 회원 서비스 애플리케이션 설정

회원 서비스에 아래와 같이 히스트릭스 의존성을 추가한다.

```xml
<!-- member-service -->

<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
</dependency>
``` 

히스트릭스 의존성 추가 후 부트스트랩 클래스에 `@EnableCircuitBraker` 애너테이션을 추가한다.

>유레카 클라이언트 의존성이 있다면 `@EnableCircuitBraker` 추가 시엔 오류가 나지 않지만 서버 기동 시 오류가 나므로
>유레카 클라이언트 의존성이 추가되어 있어도 히스트릭스 의존성을 추가해주어야 한다.

```java
// member-service

@SpringBootApplication
@EnableEurekaClient
@EnableResourceServer           // 보호 자원으로 설정
@EnableBinding(Source.class)    // 이 애플리케이션을 메시지 브로커와 바인딩하도록 스프링 클라우드 스트림 설정
                                // Source.class 로 지정 시 해당 서비스가 Source 클래스에 정의된 채널들을 이용해 메시지 브로커와 통신
@EnableCircuitBreaker           // Hystrix
public class MemberServiceApplication {
    // ... 이후 생략
}
```

---

## 4. Hystrix 애너테이션을 사용하여 Circuit Breaker (회로 차단기) 패턴으로 원격 호출 실행

히스트릭스와 스프링 클라우드는 `@HystrixCommand` 애너테이션을 사용하여 히스트릭스 회로 차단기가 관리하는 자바 클래스 메서드라고 표시한다.

스프링 프레임워크가 `@HystrixCommand` 애너테이션을 만나면 메서드를 감싸는 프록시를 동적으로 생성하고 원격 호출을 처리하기 위해 확보한 스레드가 있는
스레드 풀로 해당 메서드에 대한 모든 호출을 관리한다.

회원 서비스 임의의 메서드에 회로 차단기 패턴을 적용해보도록 하자.

아래 코드에선 단순히 `@HystrixCommand` 만 적용했지만 `@HystrixCommand` 엔 더 많은 속성들이 있다. (이 포스트 뒷부분에 설명)

별도 속성 정의없이 `@HystrixCommand` 애너테이션만 사용한다면 모두 기본값을 사용한다는 의미이다.
  
```java
// member-service > MemberController.java

/**
 * Hystrix 테스트 (RestTemplate 를 이용하여 이벤트 서비스의 REST API 호출)
 */
@HystrixCommand     // 모두 기본값으로 셋팅한다는 의미
@GetMapping(value = "hys/{name}")
public String hys(ServletRequest req, @PathVariable("name") String name) {
    logger.debug("LicenseService.getLicensesByOrg  Correlation id: {}", CustomContextHolder.getContext().getCorrelationId());
    sleep();
    return "[MEMBER] " + eventRestTemplateClient.gift(name) + " / port is " + req.getServerPort();
}

private void sleep() {
    try {
        Thread.sleep(3000);        // 3,000 ms (3초), 기본적으로 히스트릭스는 1초 후에 호출을 타임아웃함
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}
```

위 *hys/{name}* 메서드는 해당 메서드가 호출될 때마다 히스트릭스 회로 차단기와 해당 호출이 연결된다.
히스트릭스는 기본적으로 1초 후에 호출을 타임아웃하므로 의도적으로 3초 뒤에 호출이 완료되도록 해본 후 메서드를 호출해보도록 하자.

[http://localhost:8090/member/hys/assu](http://localhost:8090/member/hys/assu)

![원격 호출이 오래 걸리면 HystrixRuntimeException 발생](/assets/img/dev/20201101/hystrixcommandError.png)

호출 타임아웃이 되는 경우 로그를 보면 아래와 같은 오류가 발생하는 것을 확인할 수 있다.

```shell
com.netflix.hystrix.exception.HystrixRuntimeException: hys timed-out and fallback failed.] with root cause
``` 



---


## 3. 개별 회로 차단기를 사용자 정의하여 호출별 타임아웃 설정 (회로 차단기가 작동하기 전에 발생할 실패 횟수 조절)
## 3. 회로 차단기가 작동할 경우 폴백 전략 구현
## 3. 서비스 내 개별 스레드 풀을 사용하여 서비스 호출을 격리하고, 호출되는 원격 자원 간에 벌크헤드 구축


---




---




---




---




---




---




---




---


---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
