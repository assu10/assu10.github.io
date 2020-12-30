---
layout: post
title:  "Spring Cloud - Sleuth, papertrail, Zipkin 을 이용한 분산 추적"
date:   2020-12-27 10:00
categories: dev
tags: msa sleuth papertrail zipkin msa-tracker logging-tracker 
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
>- 클라이언트 회복성 패턴
>   - 클라이언트 측 부하분산
>   - Circuit Breaker (회로 차단기)
>   - Fallback (폴백 처리)
>   - Bulkhead (벌크헤드)
>- 클라이언트 회복성의 중요성
>- Hystrix 설정을 위한 회원 서비스 애플리케이션 설정
>- Hystrix 애너테이션을 사용하여 Circuit Breaker (회로 차단기) 패턴으로 원격 호출 실행
>- 개별 서킷 브레이커를 사용자 정의하여 호출별 타임아웃 설정
>- 서킷 브레이커가 작동할 경우 폴백 전략 구현
>- 서비스 내 개별 스레드 풀을 사용하여 서비스 호출을 격리하고, 호출되는 원격 자원 간에 벌크헤드 구축
>   - 벌크헤드 패턴 기본 구성
>   - 벌크헤드 패턴 상세 구성

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

- Hystrix 애너테이션을 사용하여 Circuit Breaker (서킷 브레이커) 패턴으로 원격 호출 실행
- 개별 서킷 브레이커를 사용자 정의하여 호출별 타임아웃 설정 
- 서킷 브레이커가 작동할 경우 폴백 전략 구현
- 서비스 내 개별 스레드 풀을 사용하여 서비스 호출을 격리하고, 호출되는 원격 자원 간에 벌크헤드 구축 (서킷 브레이커가 작동하기 전에 발생할 실패 횟수 조절)

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

서킷 브레이커 패턴은 전기 회로의 차단기 개념에서 유래한 클라이언트 회복성 패턴이다.
전기 시스템에서 회로 차단기는 문제를 감지하면 모든 전기 시스템과 연결된 접속을 차단하여 연관된 시스템들이 손상되지 않도록 보호하는 역할을 한다.

서킷 브레이커는 원격 서비스 호출을 모니터링하여 호출이 오래 걸리거나 사전 설정한 값만큼 호출이 실패하면 이를 중재하여 호출이 빨리 실패하게 만듦으로써
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

서킷 브레이커는 문제가 있는 서비스를 차단하여 해당 서비스로의 호출을 막는다.
그리고 성능이 저하된 서비스를 간헐적으로 호출하여 호출이 연속적으로 충분히 성공하면 서킷 브레이커를 재설정한다.

원격 서비스 호출에서 서킷 브레이커 패턴이 제공하는 핵심 기능은 아래와 같다.

- **빠른 실패**
    - 원격 서비스에 성능 저하 발생 시 애플리케이션은 빨리 실패함으로써 애플리케이션 전체를 다운시킬 수 있는 자원 고갈 이슈를 방지함<br />
    서비스 전체가 다운되는 것보다 부분적으로 다운되는 것이 낫다.
- **원만한 실패**
    - 원격 서비스 호출 실패 시 폴백 패턴을 이용하여 대체 코드를 실행
- **원활한 회복**
    - 서킷 브레이커는 요청 자원이 정상적인 상태인지 주기적으로 확인하여 사람의 개입없이 자원 접근을 다시 허용
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

히스트릭스와 스프링 클라우드는 `@HystrixCommand` 애너테이션을 사용하여 히스트릭스 서킷 브레이커가 관리하는 자바 클래스 메서드라고 표시한다.

스프링 프레임워크가 `@HystrixCommand` 애너테이션을 만나면 메서드를 감싸는 프록시를 동적으로 생성하고 원격 호출을 처리하기 위해 확보한 스레드가 있는
스레드 풀로 해당 메서드에 대한 모든 호출을 관리한다.

회원 서비스 임의의 메서드에 서킷 브레이커 패턴을 적용해보도록 하자.

아래 코드에선 단순히 `@HystrixCommand` 만 적용했지만 `@HystrixCommand` 엔 더 많은 속성들이 있다. (이 포스트 뒷부분에 설명)

별도 속성 정의없이 `@HystrixCommand` 애너테이션만 사용한다면 모두 기본값을 사용한다는 의미이다.
  
```java
// member-service > MemberController.java

/**
 * Hystrix 기본 테스트 (RestTemplate 를 이용하여 이벤트 서비스의 REST API 호출)
 */
@HystrixCommand     // 모두 기본값으로 셋팅한다는 의미
@GetMapping(value = "hys/{name}")
public String hys(ServletRequest req, @PathVariable("name") String name) {
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

위 *hys/{name}* 메서드는 해당 메서드가 호출될 때마다 히스트릭스 서킷 브레이커와 해당 호출이 연결된다.
히스트릭스는 기본적으로 1초 후에 호출을 타임아웃하므로 의도적으로 3초 뒤에 호출이 완료되도록 해본 후 메서드를 호출해보도록 하자.

[http://localhost:8090/member/hys/assu](http://localhost:8090/member/hys/assu)

![원격 호출이 오래 걸리면 HystrixRuntimeException 발생](/assets/img/dev/20201101/hystrixcommandError.png)

호출 타임아웃이 되는 경우 로그를 보면 아래와 같은 오류가 발생하는 것을 확인할 수 있다.

```shell
com.netflix.hystrix.exception.HystrixRuntimeException: hys timed-out and fallback failed.] with root cause
``` 

***`@HystrixCommand` 애너테이션의 구성 설정없이 기본 `@HystrixCommand` 를 사용하는 것은 주의가 많이 필요하다.<br />
프로퍼티없이 `@HystrixCommand` 애너테이션을 지정하면 모든 원격 서비스 호출에 동일한 스레드 풀을 사용하므로 애플리케이션에서 문제가 발생할 수 있다.***

이 포스팅 뒷부분(벌크헤드)에 원격 서비스 호출을 자체 스레드 풀로 분리하는 방법과 스레드 풀을 독립적으로 동작시키는 구성 방법을 설명한다.

---

## 5. 개별 서킷 브레이커를 사용자 정의하여 호출별 타임아웃 설정

히스트릭스가 호출을 중단하기 전 시간을 사용자 정의하여 보자.
히스트릭스는 기본적으로 1초 후에 호출을 타임아웃을 하지만 각 서비스에 맞게 사용자 정의할 수 있다.

java 로 설정하는 방법은 아래와 같다.

```java
// member-service > MemberController.java

/**
 * Circuit Breaker 타임아웃 설정 (RestTemplate 를 이용하여 이벤트 서비스의 REST API 호출)
 */
@HystrixCommand(
        commandProperties = {
                @HystrixProperty(name="execution.isolation.thread.timeoutInMilliseconds",
                                 value="5000")})   // 서킷 브레이커의 타임아웃 시간을 5초로 설정
@GetMapping(value = "timeout/{name}")
public String timeout(ServletRequest req, @PathVariable("name") String name) {
    return "[MEMBER] " + eventRestTemplateClient.gift(name) + " / port is " + req.getServerPort();
}
``` 

여기선 메서드 별로 타임아웃을 설정하지 않고 주울에 서비스별 호출 타임아웃을 설정해보도록 하겠다.<br />
우선 회원 서비스가 호출할 이벤트 서비스 메서드에 의도적으로 결과값을 늦게 리턴하도록 설정한다.

```java
// event-service > EventController.java

/**
 * 회원 서비스에서 호출할 메서드
 */
@GetMapping(value = "gift/{name}")
public String gift(@PathVariable("name") String gift) {
    sleep();
    return "[EVENT] Gift is " + gift;
}

private void sleep() {
    try {
        Thread.sleep(7000);        // 7,000 ms (7초), 기본적으로 히스트릭스는 1초 후에 호출을 타임아웃함
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}
``` 

주울의 application.yml 파일을 아래와 같이 수정한다.

아래 내용은 [Spring Cloud - Netflix Zuul(1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/) 의 *서비스 타임아웃* 에서 한번 언급한 내용이므로
자세한 설명은 생략한다.

```yaml
// zuulserver

hystrix:
  command:
    default:    # 유레카 서비스 ID
      execution:
        isolation:
          thread:
            timeoutInMilliseconds: 5000  # 히스트릭스 타임아웃 5초로 설정 (기본 1초, ribbon 의 타임아웃보다 커야 기대하는 대로 동작함)
event-service:
  ribbon:
    ReadTimeout: 5000       # 리본 타임아웃 5초로 설정 (기본 5초)
```

```java
// member-service > MemberController.java

@GetMapping(value = "timeout/{name}")
public String timeout(ServletRequest req, @PathVariable("name") String name) {
    return "[MEMBER] " + eventRestTemplateClient.gift(name) + " / port is " + req.getServerPort();
}
```

이제 회원서비스의 *[http://localhost:8090/member/timeout/assu](http://localhost:8090/member/timeout/assu)* 을 호출해보도록 하자.

![원격 호출이 오래 걸리면 HystrixRuntimeException 발생](/assets/img/dev/20201101/hystrixcommandError2.png)

주울 서비스의 로그를 보면 아래와 같은 로그가 나오는 것을 확인할 수 있다.

```shell
com.netflix.hystrix.exception.HystrixRuntimeException: event-service timed-out and no fallback available.
``` 

---

## 6. 서킷 브레이커가 작동할 경우 폴백 전략 구현

서킷 브레이커 패턴의 장점은 원격 자원의 소비자와 제공자 사이에서 실패를 가로채고 다른 대안을 선택할 기회는 주는 것인데 이것이 바로 **폴백 전략** 이다.

히스트릭스 폴백 전략 구현 시엔 아래 두 가지만 설정하면 된다.

- 폴백 메서드 정의 (히스트릭스를 차단할 때 호출될 메서드)
- `@HystrixCommand` 에 `fallbackMethod` 속성 추가

바로 위에서 사용했던 회원 서비스 메서드에 폴백 메서드를 적용해보도록 하자.

폴백 메서드는 `@HystrixCommand` 가 보호하려는 메서드와 같은 클래스에 있어야 하고, 보호하려는 메서드에 전달되는 모든 매개 변수를
폴백이 받으므로 파라미터도 완전히 동일해야 한다.

```java
@HystrixCommand(fallbackMethod = "timeoutFallback")     // 폴백 메서드
@GetMapping(value = "timeout/{name}")
public String timeout(ServletRequest req, @PathVariable("name") String name) {
    return "[MEMBER] " + eventRestTemplateClient.gift(name) + " / port is " + req.getServerPort();
}

/**
 * timeout 메서드의 폴백 메서드
 */
public String timeoutFallback(ServletRequest req, @PathVariable("name") String name) {
    return "This is timeoutFallback test.";
}
```

위에선 주울에 히스트릭스를 설정했지만 폴백 메서드에 대한 설정은 폴백 메서드가 위치한 서비스에 위치해야 하므로 
회원 서비스의 application.yml 파일에 타임아웃 시간을 설정한다.

```yaml
# member-service > application.yaml
hystrix:
  command:
    default:    # 유레카 서비스 ID
      execution:
        isolation:
          thread:
            timeoutInMilliseconds: 3000  # 히스트릭스 타임아웃 3초로 설정 (기본 1초, ribbon 의 타임아웃보다 커야 기대하는 대로 동작함)
```

이제 [http://localhost:8090/member/timeout/assu](http://localhost:8090/member/timeout/assu) 를 다시 호출하면 3초가 지난 후 
폴백 함수가 실행되는 것을 확인할 수 있다.
이 때 별도 로그는 남지 않는다.

![타임아웃 후 폴백 함수 실행](/assets/img/dev/20201101/fallback.png) 

>**폴백 전략 구현 시 주의할 점**
>
>폴백은 호출하려는 자원이 타임아웃되거나 실패할 때 실행할 함수를 제공하는 메커니즘이다.
>폴백을 사용하여 타임아웃 예외를 잡아내어 에러 로깅만 한다면 이는 try~catch 블록에 로깅 로직을 넣어도 된다.
>
>폴백 서비스에서 다른 분산 서비스를 호출할 때는 매우 주의해야 한다.
>1차 폴백을 겪은 후 동일한 장애가 2차 폴백 시도시에도 영향을 줄 수 있다는 것을 기억하고 방어적으로 코딩해야 한다.

---

## 7. 서비스 내 개별 스레드 풀을 사용하여 서비스 호출을 격리하고, 호출되는 원격 자원 간에 벌크헤드 구축

MSA 환경에서 벌크헤드 패턴을 적용하지 않으면 기본적으로 전체 자바 컨테이너에 대한 요청을 처리하는 스레드에서 호출이 이루어진다.<br />
이럴 경우 한 서비스에서 발생한 성능 문제로 자바 컨테이너의 모든 스레드가 최대치에 도달하면 새로운 요청들은 적체되고 결국 자바 컨테이너는 비정상 종료된다.

**벌크헤드 패턴은 원격 자원 호출을 자신의 스레드 풀에 격리하기 때문에 오작동하는 서비스를 차단하여 컨테이너의 비정상 종료를 방지**한다.

>타임 아웃만 설정하고 벌크헤드 전략을 설정하지 않으면 이상이 있는 서비스로의 호출 자체는 막히지 않은 상태이므로 
>이상이 있는 서비스의 회복 시간을 벌 수 없다.<br /> 
>(즉, 이상이 있는 원격 자원을 호출한 서버는 타임아웃[빠른 실패] 로 인해 영향을 받지 않지만 비정상 서비스로의 호출 자체는 막지 못함)

히스트릭스는 스레드 풀을 사용해 원격 서비스에 대한 모든 요청을 위임하는데 기본적으로 Hystrix Command 는 동일한 스레드 풀을 공유한다.
이러한 방법은 원격 자원이 적요 균등하게 각 서비스를 호출하는 환경에서는 적합하지만, 호출량이 많고 호출 완료까지 걸리는 시간이 오래 걸리는 서비스에는 적합하지 않다.<br />
히스트릭스의 기본 스레드 풀에 있는 모든 스레드를 차지하므로 결국 모든 스레드가 고갈된다.

히스트릭스는 이러한 상황을 방지하기 위해 **서로 다른 원격 자원 호출간에 벌크헤드를 생성하는 메커니즘**을 제공한다.<br />
즉, 성능이 나쁜 서비스는 동일 서비스 풀 안에 있는 서비스 호출에만 영향을 미치므로 호출에서 발생할 수 있는 피해를 제한시키는 것이다.

분리된 스레드 풀 구현시엔 아래 단계의 순서로 진행이 필요하다.

- 별도 스레드 풀 설정
- 스레드 풀의 스레드 숫자 설정
- 스레드가 꽉 차 있을 경우 큐에 들어갈 요청 수에 해당하는 큐의 크기 설정

이제 벌크헤드 패턴을 직접 구현해보도록 하자.

---

### 7-1. 벌크헤드 패턴 기본 구성

분리된 스레드 풀을 구현하려면 `@HystrixCommand` 애너테이션에 몇 가지 속성을 추가해야 한다.

회원 서비스에서 이벤트 서비스를 호출하는 REST API 에 분리된 스레드 풀을 적용해보도록 하자.

```java
// member-service > MemberController.java

/**
 * eventThreadPool 을 사용하면서 sleep() 이 있는 이벤트 서비스를 호출하는 함수
 */
@HystrixCommand( //fallbackMethod = "timeoutFallback")
        threadPoolKey = "eventThreadPool",
        threadPoolProperties =
                {@HystrixProperty(name = "coreSize", value = "30"),        // 스레드 풀의 스레드 갯수 (디폴트 10)
                 @HystrixProperty(name = "maxQueueSize", value = "10")}    // 스레드 풀 앞에 배치할 큐와 큐에 넣을 요청 수 (디폴트 -1)
)
@GetMapping(value = "bulkheadEvtSleep/{name}")
public String bulkheadEvtSleep(@PathVariable("name") String name) {
    String eventApi = eventRestTemplateClient.gift(name);
    return "[MEMBER] " + eventApi;
}
```

- **threadPoolKey**
    - 새로운 스레드 풀 설정
- **coreSize**
    - 스레드 풀의 스레드 갯수 (디폴트 10개)
- **maxQueueSize**
    - 스레드가 꽉 차있을 경우 스레드 풀의 앞 단에 요청을 백업할 큐를 만들고, 요청 수에 맞는 큐 크기를 정하는데 이 때의 큐 크기 (디폴트 -1)
    - 요청 수가 큐 크기를 초과하면 큐에 여유가 생길때까지 추가 요청을 모두 실패
    - -1인 경우 유입된 호출은 유지하는데 자바의 SynchronousQueue 가 사용됨
      동기식 큐 사용 시 스레드 풀에서 가용한 스레드 갯수보다 더 많은 요청 처리 불가
    - 1보다 큰 값으로 설정한 경우 자바의 LinkedBlockingQueue 사용
      LinkedBlockingQueue 사용 시 모든 스레드가 요청을 처리하는데 분주하더라고 더 많은 요청을 큐에 넣을 수 있음

> 넷플릭스에서 제안하는 스레드 풀의 적정 크기는 아래와 같다.
>
>(서비스가 정상일 때 괴조점에서의 초당 요청 수 * 99 백분위 수 지연 시간(초 단위)) + 오버헤드를 대비한 소량의 추가 스레드

부하가 발생하기 전까진 서비스 성능 특성을 모르는 경우가 많은데 스레드 풀 프로퍼티 조정 시 참고할 수 잇는 지표는 원격 자원은 정상인 상황에서
서비스 호출에 타임아웃이 발생하는 경우이다.
     
---

### 7-2. 벌크헤드 패턴 상세 구성

히스트릭스는 호출 실패 횟수를 모니터링하여 호출이 필요 이상으로 실패하는 경우 원격 자원에 도달하기 전에 호출을 실패시켜 서비스로 들어오는 이후 
호출을 자동으로 차단한다. (=**서킷 브레이커가 열림**)

회원 서비스에 서킷 브레이커를 적용해보도록 하자.

```java
// member-service > MemberController.java

/**
 * eventThreadPool 을 사용하면서 sleep() 이 있는 이벤트 서비스를 호출하는 함수
 */
@HystrixCommand( //fallbackMethod = "timeoutFallback")
        threadPoolKey = "eventThreadPool",
        threadPoolProperties =
                {@HystrixProperty(name = "coreSize", value = "30"),         // 스레드 풀의 스레드 갯수 (디폴트 10)
                 @HystrixProperty(name = "maxQueueSize", value = "10")},    // 스레드 풀 앞에 배치할 큐와 큐에 넣을 요청 수 (디폴트 -1)
        commandProperties = {
                // 히스트릭스가 호출 차단을 고려하는데 필요한 시간인 10초(metrics.rollingStats.timeInMilliseconds) 동안 연속 호출 횟수 (디폴트 20)
                @HystrixProperty(name = "circuitBreaker.requestVolumeThreshold", value = "2"),
                // 서킷 브레이커가 열린 후 requestVolumeThreshold 값만큼 호출한 후 타임아웃, 예외, HTTP 500 반환등으로 실패해야 하는 호출 비율 (디폴트 50)
                @HystrixProperty(name = "circuitBreaker.errorThresholdPercentage", value = "10"),
                // 서킷 브레이커가 열린 후 서비스의 회복 상태를 확인할 때까지 대기할 시간 간격. 즉, 서킷 브레이커가 열렸을 때 얼마나 지속될지...(디폴트 5000)
                @HystrixProperty(name = "circuitBreaker.sleepWindowInMilliseconds", value = "7000"),
                // 서비스 호출 문제를 모니터할 시간 간격. 즉 서킷 브레이커가 열리기 위한 조건을 체크할 시간. (디폴트 10초)
                @HystrixProperty(name = "metrics.rollingStats.timeInMilliseconds", value = "15000"),
                // 설정한 시간 간격동안 통계를 수집할 횟수 (이 버킷수는 모니터 시간 간격에 균등하게 분할되어야 함
                // 여기선 15초 시간 간격을 사용하고, 3초 길이의 5개 버킷에 통계 데이터 수집
                @HystrixProperty(name = "metrics.rollingStats.numBuckets", value = "5")}
)
@GetMapping(value = "bulkheadEvtSleep/{name}")
public String bulkheadEvtSleep(@PathVariable("name") String name) {
    String eventApi = eventRestTemplateClient.gift(name);
    return "[MEMBER] " + eventApi;
}

/**
 * eventThreadPool 을 사용하지만 sleep() 이 없는 이벤트 서비스를 호출하는 함수
 * 바로 위 함수에서 서킷 브레이커가 열려도 아래 함수는 정상 동작함 (스레드 풀 키를 이런 식으로 공유해서 사용할 수 없는 것 같음)
 */
@HystrixCommand( //fallbackMethod = "timeoutFallback")
        threadPoolKey = "eventThreadPool",
        threadPoolProperties =
                {@HystrixProperty(name = "coreSize", value = "30"),         // 스레드 풀의 스레드 갯수 (디폴트 10)
                 @HystrixProperty(name = "maxQueueSize", value = "10")},    // 스레드 풀 앞에 배치할 큐와 큐에 넣을 요청 수 (디폴트 -1)
        commandProperties = {
                // 히스트릭스가 호출 차단을 고려하는데 필요한 시간인 10초(metrics.rollingStats.timeInMilliseconds) 동안 연속 호출 횟수 (디폴트 20)
                @HystrixProperty(name = "circuitBreaker.requestVolumeThreshold", value = "2"),
                // 서킷 브레이커가 열린 후 requestVolumeThreshold 값만큼 호출한 후 타임아웃, 예외, HTTP 500 반환등으로 실패해야 하는 호출 비율 (디폴트 50)
                @HystrixProperty(name = "circuitBreaker.errorThresholdPercentage", value = "75"),
                // 서킷 브레이커가 열린 후 서비스의 회복 상태를 확인할 때까지 대기할 시간 간격. 즉, 서킷 브레이커가 열렸을 때 얼마나 지속될지...(디폴트 5000)
                @HystrixProperty(name = "circuitBreaker.sleepWindowInMilliseconds", value = "7000"),
                // 서비스 호출 문제를 모니터할 시간 간격. 즉 서킷 브레이커가 열리기 위한 조건을 체크할 시간. (디폴트 10초)
                @HystrixProperty(name = "metrics.rollingStats.timeInMilliseconds", value = "15000"),
                // 설정한 시간 간격동안 통계를 수집할 횟수 (이 버킷수는 모니터 시간 간격에 균등하게 분할되어야 함
                // 여기선 15초 시간 간격을 사용하고, 3초 길이의 5개 버킷에 통계 데이터 수집
                @HystrixProperty(name = "metrics.rollingStats.numBuckets", value = "5")}
)
@GetMapping(value = "bulkheadEvtNotSleepPool/{name}")
public String bulkheadEvtPool(ServletRequest req, @PathVariable("name") String name) {
    String eventApi = eventRestTemplateClient.gift2(name);
    return "[MEMBER] " + eventApi;
}
```

- **circuitBreaker.requestVolumeThreshold**
    - 디폴트 20
    - 반복 시간 간격 중 서킷 브레이커의 차단 여부를 검토하는데 필요한 최소 요청 수
    - 히스트릭스가 에러를 포착하면 서비스 호출의 실패 빈도 검사용 10초 타이머를 시작하는데 이 10초 동안 호출 횟수를 확인함
    - 그 시간대에 발생한 호출 횟수가 최소 호출 횟수 이하라면 히스트릭스는 호출이 다소 실패하더라도 아무런 조치를 하지 않음
    - 예를 들어 10초 동안 호출 횟수가 15번이고 15번 모두 실패하더라도 서킷 브레이커는 열리지 않음
- **circuitBreaker.errorThresholdPercentage**
    - 서킷 브레이커가 열린 후 requestVolumeThreshold 값만큼 호출한 후 타임아웃, 예외, HTTP 500 반환등으로 실패해야 하는 호출 비율 (디폴트 50)
    - 디폴트 50
    - 반복 시간 간격 중 서킷 브레이커를 차단하는데 필요한 실패 비율
    - 10초 시간대 동안 호출이 최소 호출 횟수를 넘으면 히스트릭스는 전체 실패 비율을 조사하기 시작함
    - 전체 실패 비율이 임계치를 초과하면 서킷 브레이커가 열리고 거의 모든 호출이 실패함
      (히스트릭스는 서비스가 회복 여부를 테스트하고 확인할 수 있도록 일부 호출을 허용)
- **circuitBreaker.sleepWindowInMilliseconds**
    - 디폴트 5,000 ms
    - 서킷 브레이커 차단 후 히스트릭스가 서비스 호출 시도를 대기하는 시간 (서킷 브레이커가 차단되었을 때 얼마나 지속될지)
    - 5초마다 히스트릭스는 서비스를 호출하는데 호출이 성공하면 서킷 브레이커를 초기화 하고 다시 호출을 허용
      호출이 실패하면 서킷 브레이커가 차단된 상태를 유지하고 5초 후 다시 재시도
- **metrics.rollingStats.timeInMilliseconds**
    - 디폴트 10,000 ms
    - 히스트릭스가 서비스 호출 문제를 모니터할 시간 간격
- **metrics.rollingStats.numBuckets**
    - 디폴트 10
    - 모니터할 시간 간격에서 유지할 측정 지표의 버킷 수
    - 히스트릭스는 해당 시간 동안 버킷에 측정 비표를 수집하고 통계를 바탕으로 서킷 브레이커 차단 여부 결정
    - 버킷 수는 metrics.rollingStats.timeInMilliseconds 에 설정된 밀리초에 균등하게 분할되어야 함
    - 예를 들어 metrics.rollingStats.timeInMilliseconds 는 15초이고 버킷 수 5인 경우 
      히스트릭스는 15초 시간 간격을 사용하고 3초 길이의 5개 버킷에 통계 데이터 수집

위와 같이 구성하였다면 의도적으로 타임아웃이 발생하는 이벤트 REST API 를 연속적으로 호출하여 회원 서비스에서 특정 스레드 풀에 대해
서킷 브레이커가 차단되는지 확인해보도록 하자.

- *eventThreadPool* 스레드 풀이 정의되고 의도적으로 타임아웃되는 이벤트 API 를 호출하는 회원 서비스 API : [http://localhost:8090/member/bulkheadEvtSleep/assu](http://localhost:8090/member/bulkheadEvtSleep/assu)
- *eventThreadPool* 스레드 풀이 정의되었지만 정상적인 이벤트 API 를 호출하는 회원 서비스 API : [http://localhost:8090/member/bulkheadEvtNotSleepPool/assu](http://localhost:8090/member/bulkheadEvtNotSleepPool/assu)

[http://localhost:8090/member/bulkheadEvtSleep/assu](http://localhost:8090/member/bulkheadEvtSleep/assu) 를 연속적으로 호출하는 경우
회원 서비스의 서킷 브레이커가 차단되는 것을 확인할 수 있다. (원격 자원 호출에 대한 타임아웃이 발생하기 전에 실패)

![서킷 브레이커 차단](/assets/img/dev/20201101/circuit1.png)

```shell
java.lang.RuntimeException: Hystrix circuit short-circuited and is OPEN
```

아직 해결되지 못한 부분이긴한데 *eventThreadPool* 스레드 풀을 적용한 API 의 연속적인 호출로 인해 서킷 브레이커 차단 후 동일 스레드 풀이 적용된
다른 API [http://localhost:8090/member/bulkheadEvtNotSleepPool/assu](http://localhost:8090/member/bulkheadEvtNotSleepPool/assu) 호출 시 
호출이 되지 않아야 할 것 같은데 정상적으로 호출이 잘 되고 있다.

더 깊게 보아야겠지만 동일 스레드 풀 key 를 메서드에 사용하여 공유하는 개념은 아닌 듯 하다.  

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [타임아웃 1](https://supawer0728.github.io/2018/03/11/Spring-Cloud-Zuul/)
* [타임아웃 2](https://supawer0728.github.io/2018/03/11/Spring-Cloud-Hystrix/)
* [벌크헤드](https://pjh3749.tistory.com/284)
* [벌크헤드 (모니터링 할때도 참고할 것)](https://multifrontgarden.tistory.com/238)
