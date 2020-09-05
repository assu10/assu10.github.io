---
layout: post
title:  "Spring Cloud(3) - Netflix Zuul(2/2)"
date:   2020-09-05 10:00
categories: dev
tags: web MSA hystrix zuul ribbon
---

## 시작하며
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Netflix Zuul 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고바란다.

>[1.Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2.Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3.Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>***3.Zuul - Proxy & API Gateway (2/2)***<br />
 >>   - 게이트 웨이
  >   - Zuul Proxy
  >   - 주울 구축
  >       - 유레카 클라이언트 구축 (유레카 서버에 서비스 동적 등록)
  >       - 서비스 검색 (Feign 사용)
  >   - 주울 경로 구성
  >       - 서비스 디스커버리를 이용한 자동 경로 매핑
  >       - 서비스 디스커버리를 이용한 수동 경로 매핑
  >   - 서비스 타임 아웃<br />
>
> 4.Ribbon - Load Balancer<br />

Spring Cloud Config Server 와 Eureka, Zuul(1) 에 대한 자세한 내용은 위 목차에 걸려있는 링크를 참고바란다.

---

## 1. 필터
앞에서 말했다시피 주울은 사전 필요, 라우팅 필터, 사후 필터, 에러 필터 등을 제공하여 서비스 호출의 서로 다른 여러 단계에 적용할 수 있도록 지원한다. 
또한 추상 클래스인 ZuulFilter 를 상속하여 자체 필터를 작성할 수도 있다.

주울은 프록시 기능 외 주울을 통과하는 모든 서비스 호출에 대해 사용자 정의 로직을 작성할 때 더욱 효과가 있다.
예를 들면 **모든 서비스에 대한 보안이나 로깅, 추적처럼 일관된 정책을 시행**하는 것을 말한다.
<br /><br />

주울은 4가지 타입의 필터를 지원한다.

- **PRE Filter (이후 사전 필터)**
    - 라우팅 되기 전에 실행되는 필터
    - <U>서비스의 일관된 메시지 형식(예-주요 HTTP 헤더의 포함 여부 등)을 확인하는 작업이나 인증(본인 인증), 
    인가(수행 권한 부여 여부)을 확인</U>하는 게이트키퍼 역할
- **ROUTING Filter (이후 라우팅 필터)**
    - 요청에 대한 라우팅을 하는 필터
    - 동적 라우팅 필요 여부를 결정하는데 사용<br />
      예를 들어 <U>동일 서비스의 다른 두 버전을 라우팅할 수 있는 경로 단위의 필터</U> 역할
- **POST Filter (이후 사후 필터)**
    - 라우팅 후에 실행되는 필터
    - 대상 서비스의 <U>응답 로깅, 에러 처리, 민감한 정보에 대한 응답 감시</U> 수행
- **ERROR Filter (이후 에러 필터)**
    - 에러 발생 시 실행되는 필터

![주울 라이프사이클](/assets/img/dev/20200905/lifecycle.png)

## 참고 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/](https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/)
* [https://spring.io/guides/gs/routing-and-filtering/](https://spring.io/guides/gs/routing-and-filtering/)
* [https://github.com/Netflix/zuul/wiki/How-it-Works](https://github.com/Netflix/zuul/wiki/How-it-Works)
