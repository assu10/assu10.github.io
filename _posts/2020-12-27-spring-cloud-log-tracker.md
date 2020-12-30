---
layout: post
title:  "Spring Cloud - Sleuth, papertrail, Zipkin 을 이용한 분산 추적"
date:   2020-12-30 10:00
categories: dev
tags: msa sleuth papertrail zipkin msa-tracker logging-tracker monitoring hystrix turbine
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Spring Cloud Sleuth, Twitter Zipkin 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2. Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3. Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4. Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br />
>[5. OAuth2, Security - 보안 (1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/)<br />
>[6. OAuth2, Security - 보안 (2/2)](https://assu10.github.io/dev/2020/09/30/spring-cloud-oauth2.0-2/)<br />
>[7. Spring Cloud Stream, 분산 캐싱 (1/2)](https://assu10.github.io/dev/2020/10/01/spring-cloud-stream/)<br />
>[8. Spring Cloud Stream, 분산 캐싱 (2/2)](https://assu10.github.io/dev/2020/11/01/spring-cloud-stream-2/)<br /><br />
>[9. Spring Cloud - Hystrix (회복성 패턴)](https://assu10.github.io/dev/2020/11/01/spring-cloud-hystrix/)<br /><br />
>***10. Spring Cloud - Sleuth, papertrail, Zipkin 을 이용한 분산 추적***<br />
>- 클라이언트 회복성 패턴

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

MSA 는 복잡한 모놀리식 시스템을 더 작고 다루기 쉬운 부분으로 분해하는 강력한 설계 패러다임이다.<br />
다루기 쉬운 이 부분들은 독립적으로 빌드 및 배포할 수 있지만, 유연한만큼 복잡해진다.<br />
이러한 특징 때문에 MSA 에 대한 **로깅과 모니터링**은 큰 고민거리이다.<br />
**서로 다른 개별 마이크로서비스에서 발생하는 로그를 연결지어 트랜잭션의 처음부터 끝까지 순서대로 추적**해내는 것은 매우 어렵다.

이 포스팅에선 **마이크로서비스의 로깅과 모니터링의 필요성**에 대해 알아본 후 **다양한 아키텍쳐와 기술**을 살펴보며 **로깅과 모니터링 관련 문제를 해결**할 수 있는
방법에 대해 기술한다.

이 글을 읽고나면 **중앙 집중식 로그관리**, **모니터링 및 대시보드** 외 아래와 같은 내용을 알게 될 것이다.

- 로그 관리를 위한 다양한 옵션, 도구 및 기술 
- 마이크로서비스의 추적성 확보를 위한 Spring Cloud Sleuth 의 사용법
- 마이크로서비스의 전 구간 모니터링에 사용되는 다양한 도구
- 서킷(circuit) 모니터링을 위한 Spring Cloud Hystrix 와 Turbine 의 사용법

★사용 기술 (책 318페이지)

---

## 1. 로그 관리의 난제

로그는 실행 중인 프로세스에서 발생하는 이벤트의 흐름이다.

전통적인 비클라우드 환경에서 클라우드 환경으로 옮겨오면 애플리케이션은 더 이상 미리 정의한 사양의 특정 장비에 종속되지 않는다.<br />
배포에 사용되는 장비를 그때마다 다를 수 있고, 도커 같은 컨테이너는 본질적으로 짧은 수명을 전제로 한다.<br />
즉, 결국 디스크의 저장 상태에 더 이상 의존할 수 없음을 의미한다.

**<u>디스크에 기록된 로그는 컨테이너가 재기동되면 사라질 수 있다.</u>**<br />
**<u>따라서 로그 파일을 로컬 장비의 디스크에 기록하는 것에 의존해서는 절대 안된다.</u>**

12요소 애플리케이션에서 말하는 원칙 중 하나는 로그 파일을 애플리케이션 내부에 저장하지 말라는 로그 외부화이다.

>12요소 애플리케이션 원칙은 *[클라우드에서의 운영 - 12요소 애플리케이션](https://assu10.github.io/dev/2020/12/27/12factor-app/)* 를 참고하세요.

마이크로서비스는 독립적인 물리적 장치 혹은 가상 머신에서 운영되기 때문에 외부화하지 않은 **로그 파일은 결국 각 마이크로서비스 별로 파편화**된다.<br />
즉, 여러 마이크로서비스에 걸쳐서 발생하는 **트랜잭션을 처음부터 끝까지 순서대로 추적하는 것이 불가능**해진다는 의미이다.

---

## 2. 중앙 집중식 로깅

위와 같은 문제점을 해결하려면 로그의 출처에 상관없이 모든 로그를 중앙 집중적으로 저장, 분석해야 한다.<br />
즉, 로그의 저장과 처리를 서비스 실행 환경에서 분리하는 것이다.

중앙 집중식 로깅의 장점은 로컬 I/O나 디스크 쓰기 블로킹이 없으며, 로컬 장비의 디스크 공간을 사용하지 않는다는 점이다.<br />
이런 방식은 빅데이터 처리에 사용되는 람다 아키텍처와 근본적으로 비슷하다.

>람다 아키텍처는 *[Lambda Architecture](http://lambda-architecture.net/)* 를 참고하세요.


![중앙 집중식 로깅 방식의 흐름](/assets/img/dev/20201230/components.png)

위 그림은 중앙 집중식 로깅 방식을 구성하는 컴포넌트들의 흐름이다.
각 컴포넌트들에 대해선 아래 *3.3. 컴포넌트들의 조합* 에서 설명한다.

그렇다면 이렇게 중앙 집중식 로깅 시 로그에 필요한 정보는 무엇이 있을까?<br />
각 로그 메시지엔 아래의 내용이 포함되어야 한다.

- **메시지**
- **컨텍스트**
    - 타임스탬프, IP 주소, 사용자 정보, 처리 상세정보(서비스, 클래스, 함수 등), 로그 유형, 분류 등의 정보를 담고 있어야 함
- **상관관계 ID (correlation ID)**
    - 서비스 호출 사이에서 추적성을 유지하기 위해 사용됨    

---

## 3. 로깅 솔루션 종류

중앙 집중식 로깅 솔루션을 구현하는데 사용할 수 있는 옵션은 여러 가지가 있다.<br />
필요한 기능을 이해하고 그에 맞는 올바른 솔루션을 선택하는 것이 중요하다.

### 3.1. 클라우드 서비스

첫 번째 방법은 SaaS 솔루션과 같은 다양한 클라우드 로깅 서비스 사용이다.

>SaaS 솔루션는 *[클라우드 컴퓨팅, IaaS, PaaS, SaaS](https://assu10.github.io/dev/2020/12/30/cloud-service-platform/)* 를 참고하세요.

- `Loggly` 
    - 가장 많이 사용되는 클라우드 기반 로깅 서비스 중 하나
    - 스프링부트 마이크로서비스는 `Loggly` 의 `Log4j`, `Logback appenders` 를 사용하여 로그 메시지를 `Loggly` 서비스로 직접 스트리밍 가능

애플리케이션이 AWS 에 배포된 경우에는 로그 분석을 위해 `AWS CloudTrail` 을 `Loggly` 와 통합할 수 있다.

그 외 `Papertrail`, `Logsene`, `Sumo Logic`, `Google Cloud Logging`, `Logentries` 가 있다. 

---

### 3.2. 내장 가능한 로깅 솔루션

두 번째 방법은 사내 데이터 센터 또는 클라우드에 설치되어 전 구간을 아우르는 로그 관리 기능을 제공하는 도구들을 사용하는 것이다.

- `Graylog`
    - 인기있는 오픈소스 로그 관리 솔루션 중 하나
    - 로그 저장소로 `ElasticSearch` 를 사용하고, 메타데이터 저장소로 `MongoDB` 사용
    -`Log4j` 로그 스트리밍을 위해 `GELF` 라이브러리 사용
- `Splunk`
    - 로그 관리 및 분석에 사용하는 상용 도구 중 하나
    - 로그를 수집하는 다른 솔루션은 로그 스트리밍 방식을 사용하는데 `Splunk` 는 로그 파일 적재 방식 사용

---


### 3.3. 컴포넌트들의 조합

마지막 방법은 여러 컴포넌트들을 선택하여 커스텀 로깅 솔루션을 구축하는 것이다.

![중앙 집중식 로깅 방식 시 사용되는 컴포넌트들](/assets/img/dev/20201230/components2.png)

- **로그 스트림 (log stream)**
    - 로그 생산자가 만들어내는 로그 메시지의 스트림
    - 로그 생산자는 마이크로서비스, 네트워크 장비일 수도 있음
    - `Loggly` 의 `Log4j`, `Logback appenders`
- **로그 적재기 (log shipper)**
    - 서로 다른 로그 생산자나 종단점에서 나오는 로그 메시지 수집
    - 수집된 로그는 DB 에 쓰거나, 대시보드에 푸시하거나, 실시간 처리를 담당하는 스트림 처리 종단점으로 보내는 등 여러 다른 종담점으로 메시지 보냄
    - `Logstash`
        - 로그 파일을 수집하고 적재하는데 사용할 수 있는 강력한 데이터 파이프라인 도구
        - 서로 다른 소스에서 스티리밍 데이터를 받아 다른 대상과 동기화하는 메커니즘을 제공하는 브로커 역할
        - `Log4j` 와 `Logback appenders` 는 스프링부트 마이크로서비스에서 `Logstash` 로 그 메시지를 직접 보내는 데 사용 가능
        - `Logstash` 는 스트링부트 마이크로서비스로부터 받은 로그 메시지를 `ElasticSearch`, `HDFS` 또는 다른 DB 에 저장
    - `Fluentd`
        - `LogSpout` 와 마찬가지로 `Logstash` 와 매우 유사하지만 도커 컨테이너 기반 환경에서는 `LogSpout` 이 더 적합함
- **로그 스트림 처리기**
    - 신속한 의사 결정에 필요한 실시간 로그 이벤트 분석
    - 대시보드로 정보를 전송하거나 알람 공지의 역할
    - self-healing system (자체 치유 시스템) 에서는 스트림 처리기가 문제점을 바로잡는 역할을 수행하기도 함
      예를 들어 특정 서비스 호출에 대한 응답으로 404 오류가 지속적으로 발생하는 경우 스트림 처리기가 처리 가능
    - `Apache Flume` 과 `Kafka` 를 `Storm` 또는 `Spark Streaming` 과 함께 사용
    - `Log4j` 에는 로그 메시지를 수집하는 데 유용한 `Flume appenders` 가 있음
      이러한 메시지는 분산된 `Kafka` 메시지 큐에 푸시되고, 스트림 처리기는 `Kafka` 에서 데이터를 수집하고 `ElasticSearch` 혹은
      기타 로그 저장소로 보내기 전에 즉시 처리함
- **로그 저장소 (log store)**
    - 모든 로그 메시지 저장
    - 실시간 로그 메시지는 일반적으로 `ElasticSearch` 에 저장됨
      `ElasticSearch` 사용 시 클라이언트가 텍스트 기반 인덱스를 기반으로 쿼리 가능
    - 대용량 데이터를 처리할 수 있는 `HDFS` 와 같은 NoSQL DB 은 일반적으로 아카이브된 로그 메시지를 저장
    - `MongoDB`, `Cassandra` 는 매월 집계되는 트랜잭션 수와 같은 요약 데이터를 저장하는데 사용
    - 오프라인 로그 처리는 `Hadoop` 의 `MapReduce` 프로그램을 사용하여 수행 가능
- **로그 대시보드**
    - 로그 분석 결과를 그래프나 차트로 나타냄
    - 운영 조직이나 관리 조직에서 많이 사용
    - `ElasticSearch` 데이터 스토어 상에서 사용되는 `Kibana` 가 있음
    - 그 외 `Graphite`, `Grafana` 도 로그 분석 보고서 표시하는데 사용됨
    
---


### 3.1. 클라우드 서비스

---


### 3.1. 클라우드 서비스

---


---
## 1. Retry


---
## 1. Retry


---
## 1. Retry


---
## 1. Retry


---


## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [Lambda Architecture](http://lambda-architecture.net/)