---
layout: post
title:  "Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (3/4) - 로그 추적을 위한 Sleuth 사용"
date:   2021-01-30 10:00
categories: dev
tags: msa centralized-log sleuth open-zipkin
---

이 포스트는 중앙 집중형 로깅 솔루션 중 하나인 ELK (ElasticSearch, Logstash, Kibana) 스택에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2. Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3. Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4. Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br />
>[5. OAuth2, Security - 보안 (1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/)<br />
>[6. OAuth2, Security - 보안 (2/2)](https://assu10.github.io/dev/2020/09/30/spring-cloud-oauth2.0-2/)<br />
>[7. Spring Cloud Stream, 분산 캐싱 (1/2)](https://assu10.github.io/dev/2020/10/01/spring-cloud-stream/)<br />
>[8. Spring Cloud Stream, 분산 캐싱 (2/2)](https://assu10.github.io/dev/2020/11/01/spring-cloud-stream-2/)<br />
>[9. Spring Cloud - Hystrix (회복성 패턴)](https://assu10.github.io/dev/2020/11/01/spring-cloud-hystrix/)<br />
>[10. Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (1/4) - 이론](https://assu10.github.io/dev/2020/12/30/spring-cloud-log-tracker/)<br /><br />
>[11. Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (2/4) - ELK 스택](https://assu10.github.io/dev/2020/12/30/spring-cloud-log-tracker2/)<br /><br />
>***12. Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (3/4) - 로그 추적을 위한 Sleuth 사용***<br />
>- Spring Cloud Sleuth 와 Open Zipkin 
>- 슬루스
>   - 마이크로서비스에 슬루스 추가

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

바로 전 포스팅인 [Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (2/4) - ELK 스택](https://assu10.github.io/dev/2021/01/04/spring-cloud-log-tracker2/)
에서는 마이크로서비스에서 분산되고 파편화되는 로깅 문제를 중앙 집중형 로깅 방식(**ELK Stack**)으로 해결하는 방법에 대해 알아보았다.

중앙 집중형 로깅 솔루션을 사용하면 모든 로그를 중앙 저장소에 보관할 수 있지만<br />
여전히 트랜잭션의 전 구간을 추적하는 것은 거의 불가능하다.

여러 마이크로서비스에 걸쳐 있는 트랜잭션의 전 구간을 추적하려면 하나의 연관 ID (Correlation ID)가 필요하다.
 
이 글을 읽고나면 아래와 같은 내용을 알게 될 것이다.

- 마이크로서비스의 추적성 확보를 위한 Spring Cloud Sleuth 의 사용법

---

## 1. Spring Cloud Sleuth 와 Open Zipkin 
`Spring Cloud Sleuth (이하 슬루스)` 와 `Open Zipkin (이하 오픈 집킨)` 의 역할은 각각 아래와 같다.

- **슬루스**
    - 상관관계 ID 를 사용하여 HTTP 호출을 추적하는 스프링 클라우드 프로젝트
    - 생성 중인 추적 데이터를 오픈 집킨에 공급할 수 있는 **연결 고리(hook)을 제공**
    - 생성된 상관관계 ID 를 모든 시스템 호출로 통과시키기 위해 필터를 추가하고, 다른 스프링 컴포넌트와 상호 작용하는 방식으로 활용
- **오픈 집킨**
    - **여러 서비스 사이의 트랜잭션 흐름**을 보여주는 오픈 소스 기반의 **데이터 시각화** 도구
    - 트랜잭션을 컴포넌트별로 분해하고 성능 **과열점(hotspot) 이 어디서 발생했는지 시각적으로 확인** 가능

---

## 2. 슬루스

분산 로그 추적은 `구간(span)` 과 `추적(trace)` 개념으로 동작한다.

- **구간(span)**
    - 하나의 작업 단위
    - 전체 트랜잭션에서 고유한 숫자
    - 예를 들어 하나의 서비스 호출은 64bit 의 `스팬 ID(span ID)` 로 식별됨  
- **추적(trace)**
    - 여러 개의 구간으로 이루어진 한 세트의 트리 구조
    - 전체 트랜잭션의 일부를 나타내는 고유 ID
    - `추적 ID(trace ID)` 를 사용하여 서비스의 호출을 처음부터 끝까지 추적 가능
    
아마 위의 설명만으론 잘 이해가 되지 않을 수 있는데 아래 그림을 보면 이해하는데 도움이 될 것이다.

![추적 아이디(Trace ID)와 구간 아이디(Span ID)](/assets/img/dev/20210130/trace-spanid.png)

위 다이어그램처럼 동일한 추적 아이디가 모든 마이크로서비스에 전달되어 트랜잭션의 전 구간을 추적할 수 있게 된다.

전에 포스팅했던 [Spring Cloud - Netflix Zuul(2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/) 의 *2. 사전 필터*와 *3. 사후 필터*에서
트랜잭션을 추적할 목적으로 아래와 같은 방식으로 상관관계 ID 를 활용하였다. 

- 주울의 사전 필터를 사용하여 유입되는 모든 HTTP 요청을 검사하고 상관관계 ID 가 없으면 삽입 
- 서비스에서 나가는 호출의 HTTP 헤더에 상관관계 ID 를 추가하여 서비스의 모든 HTTP 호출이 상관관계 ID 를 전파할 수 있도록 인터셉터 작성
 
`슬루스`는 위 과정의 복잡성을 아래와 같이 관리한다.

- 상관관계 ID 가 없으면 상관관계 ID 를 생성하여 서비스 호출에 주입
- 서비스에서 나가는 호출에 대한 상관관계 ID 전파를 관리하여 트랜잭션의 상관관계 ID 를 자동으로 나가는 호출에 추가함
- 상관관계 정보를 스프링 MDC 로그에 추가하여 상관관계 ID 가 스프링 부트의 기본 SL4J와 Logback 구현으로 자동적으로 로깅됨
- 선택적으로 서비스의 추적 정보를 집킨 분산 추적 플랫폼에 전송 

이제 마이크로서비스에 슬루스를 적용해보도록 하자.

---

### 2.1. 마이크로서비스에 슬루스 추가

슬루스를 적용하는 방법은 매우 간단하다.<br />
각 마이크로 서비스에 슬루스 의존성을 추가하기만 하면 된다.

**member-service, event-service > pom.xml**
```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-sleuth</artifactId>
</dependency>
```

이제 각 서비스는 아래와 같은 기능을 할 수 있다.

- 서비스로 들어오는 모든 HTTP 호출을 검사하고 그 호출에서 슬루스의 추적 정보가 존재하는지 확인한다.
  추적 정보가 있다면 마이크로서비스로 전달된 추적 정보를 수집하여 로깅을 위해 서비스에 제공한다.
- 서비스에서 나가는 모든 HTTP 호출과 스프링이 메시징 채널의 메시지에 삽입한다.

이제 두 개의 마이크로서비스를 통과하는 API 호출 후 의존성을 추가하기 전과 후의 로그를 비교해보자.<br />
[http://localhost:5555/api/mb/member/gift/ASSU](http://localhost:5555/api/mb/member/gift/ASSU)

**슬루스 의존성 추가 전**
```shell
-- member-service
2021-01-30 20:46:40.566  INFO 22744 --- [nio-8090-exec-1] MemberController      : [MEMBER] gift/{name} logging...name is ASSU.

-- event-service
2021-01-30 20:46:40.919  INFO 21756 --- [nio-8070-exec-1] EventController       : [EVENT] Gift is ASSU logging...gift is {}.
```

**슬루스 의존성 추가 후**
```shell
-- member-service
2021-01-30 20:48:25.056  INFO [,e6fcd377c5c46bd9,e6fcd377c5c46bd9,true] 15792 --- [nio-8090-exec-1] MemberController      : [MEMBER] gift/{name} logging...name is ASSU.

-- event-service
2021-01-30 20:48:25.438  INFO [,e6fcd377c5c46bd9,15a21c3858c0b1e0,true] 22052 --- [nio-8070-exec-1] EventController       : [EVENT] Gift is ASSU logging...gift is {}.
```

INFO 다음에 이상한 문구가 찍힌 것이 보일텐데 각 항목의 의미는 아래와 같다.
`[,e6fcd377c5c46bd9,e6fcd377c5c46bd9,true]`
- 첫 번째 값 : 어플리케이션 이름 (application.yaml 에 spring.application.name 을 지정해주었지만 빈 값으로 나온다. 혹시나 하여 bootstrap.yaml 에 지정하니 정상적으로 출력됨)
- 두 번째 값 : 추적 ID (하나의 트랜잭션의 고유 식별자이며 해당 요청의 모든 서비스 호출에 전달됨)
- 세 번째 값 : 스팬 ID (하나의 트랜잭션의 일부를 나타내는 고유 ID)
- 네 번째 값 : 집킨 전송 여부 (추적을 위해 집킨 서버에 데이터 전송 여부를 결정하는 플래그, 집킨은 다음 포스팅 때 다룰 예정)

회원 서비스와 이벤트 서비스의 추적 ID 는 `e6fcd377c5c46bd9` 로 동일하고 스팬 ID 는 각각 `e6fcd377c5c46bd9`, `15a21c3858c0b1e0` 로 다른 것을 알 수 있다.<br />
이렇게 다른 스팬 ID 로 트랜잭션의 구간을 구별할 수 있다.

네 번째 값인 집킨에 추적 데이터 전송 여부는 대용량 서비스에서 생성된 추적 데이터의 양은 엄청나고 모두 가치가 있는 것은 아니기 때문에
트랜잭션을 집킨에 보낼 시점과 방법을 결정할 수 있다.<br />

그럼 [Kibana](http://localhost:5601/app/) 에 접속하여 로그를 확인해보자.

![Kibana 에서 로그 확인](/assets/img/dev/20210130/kibana.png)

kibana 상의 로그를 보면 추적 ID 와 스팬 ID 가 함께 로깅되는 것을 확인할 수 있다.
다른 서비스에 의해 호출당한 로깅의 경우 `ParentSpanId`, `parentId` 항목이 있는데 이는 해당 서비스를 호출한 서비스의 `SpanId`를 의미한다.

---

지금까지 마이크로 서비스의 추적성 확보를 위해 슬루스를 사용하여 로그에 추적 ID 와 스팬 ID 를 넣어 활용하는 방법에 대해 알아보았다.
이 후엔 전 구간 모니터링에 사용되어 트랜잭션의 흐름을 시각화하는 오픈 집킨에 대해 알아보도록 하겠다.

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [Spring Cloud Sleuth Reference Documentation](https://docs.spring.io/spring-cloud-sleuth/docs/current-SNAPSHOT/reference/html/)
* [오픈 집킨 공홈](https://zipkin.io/)
* [로깅 시스템 #4 - Correlation id & MDC](https://bcho.tistory.com/1316)

