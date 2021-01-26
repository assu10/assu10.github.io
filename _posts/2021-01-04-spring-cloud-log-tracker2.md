---
layout: post
title:  "Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (2/3) - ELK 스택"
date:   2021-01-04 10:00
categories: dev
tags: msa centralized-log elasticsearch logstash kibana elk-stack elastic-stack 
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
>[10. Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (1/3) - 이론](https://assu10.github.io/dev/2020/12/30/spring-cloud-log-tracker/)<br /><br />
>***11. Spring Cloud Sleuth, Open Zipkin 을 이용한 분산 추적 (2/3) - ELK 스택***<br />
>- ELK Stack 이란?
>- Elastic Stack 이란?
>- ElasticSearch, Kibana, Logstash 설치
>   - ElasticSearch 설치
>   - Kibana 설치
>   - Logstash 설치
>- Springboot에 Logging 설정
>- Kibana 를 통해 여러 마이크로서비스의 로그를 통합하여 조회
>   - Index 생성
>   - 로그 조회

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

중앙 집중형 로깅 시스템 구축 시 DB 는 인메모리가 될 수도 있고 MySQL 이 될 수도 있다.<br />
인메모리인 경우 별도 스토리지 설치가 필요없기 때문에 로컬 테스트 시 사용하면 좋고, MySQL 은 소규모 서비스에 적절하다.<br />
실제 운영 시엔 Cassandra 나 ElasticSearch 를 저장소로 사용하는 것이 바람직하다.

이 글을 읽고 나면 아래와 같은 내용을 알게 될 것이다.

- ELK 스택을 통해 여러 로그 데이터를 검색 가능한 단일 소스로 수집 

---

## 1. ELK Stack 이란?

ELK 스택은 `Elasticsearch`, `Logstash`, `Kibana` 이 세 가지 오픈 소스 프로젝트의 머릿글자이다.<br />
로그를 위해 `Elasticsearch` 를 사용하는데 이것을 손쉽게 수집해서 시각화할 수 있도록 해주는 것이 수집 파이프라인 `Logstash`와
시각화 도구인 `Kibana` 이다.

- **Logstash**
    - 여러 소스에서 동시에 데이터를 수집하여 변환한 후 Elasticsearch 와 같은 *stash* 로 전송하는 서버 사이드 데이터 처리 파이프라인
    - 입력: `Beats`, `Cloudwatch`, `Eventlog` 등 다양한 입력을 지원
    - 필터: 형식이나 복잡성에 상관없이 설정을 통해 데이터를 동적으로 변환
    - 출력: Elasticsearch, Email, ECS, Kafka 등 원하는 저장소에 데이터 전송
- **Elasticsearch**
    - JSON 기반의 분산형 오픈 소스 RESTful 검색 엔진
    - 대량의 데이터를 신속하고 거의 실시간으로 저장, 검색, 분석 가능
- **Kibana**
    - 사용자가 Elasticsearch 에서 차트와 그래프를 이용해 데이터를 시각화할 수 있도록 해줌    

---

## 2. Elastic Stack 이란?

`Elastic Stack` 은 위의 `ELK Stack` 에서 한 단계 발전한 형태이다.<br />

![Elastic Stack](/assets/img/dev/20210104/elasticstack.png)

사용자들은 파일을 추적하고 싶어했고 2015년에 기존 `ELK Stack` 에 경량의 단일 목적 데이터 수집기 제품군을 도입했는데 이것을 `Beats` 이다.<br />
이 한 단계 발전된 형태를 BELK? BLEK? 등 앞글자를 따서 만들까했지만 머릿글자를 확장이 쉽지 않아 이름을 `Elastic Stack` 으로 지었다고 한다.

- **Beats**
    - 경량의 에이전트로 설치되어 데이터를 Logstash 또는 Elasticsearch 로 전송해주는 도구.
    - Logstash 보다 경량화되어 있는 서비스

`Beats` 는 `Filebeat`, `Metricbeat`, `Packetbeat`, `Winlogbeat`, `Heartbeat` 등이 있고, `Libbeat` 를 이용하여 직접 구축도 가능하다.

- **Filebeat**
    - 서버에서 로그 파일 제공
- **Metricbeat**
    - 서버에서 실행 중인 운영체제 및 서비스에서 metric 을 주기적으로 수집하는 서버 모니터링 에이전트
- **Packetbeat**
    - 응용 프로그램 서버 간에 교환되는 정보를 제공하는 네트워크 패킷 분석기
- **Winlogbeat**
    - Windows 이벤트 로그 제공
    
이 포스팅에선 일단 ELK 스택을 다룰 예정이다.

이제 ELK 스택을 사용하기 위해 각 오픈 소스를 설치해보도록 하자.<br />
로그 데이터의 전체적인 흐름은 아래와 같다.

![로그 데이터의 흐름](/assets/img/dev/20210104/log.png)

---

## 3. ElasticSearch, Kibana, Logstash 설치

[https://www.elastic.co/kr/elastic-stack](https://www.elastic.co/kr/elastic-stack) 에 접속하여 ElasticSearch 와 Kibana 를 설치한다.

### 3.1. ElasticSearch 설치

설치 파일은 [https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.10.1.msi](https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.10.1.msi) 이며, 
설치 상세 설명은 [https://www.elastic.co/guide/en/elasticsearch/reference/current/windows.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/windows.html) 를
참고하여 설치한다.

설치 완료 후 ElasticSearch 가 기동되면 커맨드창에 아래와 같이 입력하여 정상적으로 설치 및 기동이 되었는지 확인한다.

```shell
C:\>curl -X GET "localhost:9200/?pretty"
{
  "name" : "first_msa",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "gy2rooW0SC6foVrsAxek8w",
  "version" : {
    "number" : "7.10.1",
    "build_flavor" : "unknown",
    "build_type" : "unknown",
    "build_hash" : "1c34507e66d7db1211f66f3513706fdf548736aaddd",
    "build_date" : "2020-12-05T01:00:33.671820Z",
    "build_snapshot" : false,
    "lucene_version" : "8.7.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

**Elasticsearch 기동** (cmd 창은 꼭 관리자모드로 실행할 것!)
```shell
C:\Program Files\Elastic\Elasticsearch\7.10.1> ./bin/elasticsearch
``` 


![엘라스틱서치 기동](/assets/img/dev/20210104/elasticsearch.png)

---

### 3.2. Kibana 설치

설치 파일은 [https://artifacts.elastic.co/downloads/kibana/kibana-7.10.1-windows-x86_64.zip](https://artifacts.elastic.co/downloads/kibana/kibana-7.10.1-windows-x86_64.zip) 이며, 
설치 상세 설명은 [https://www.elastic.co/guide/en/kibana/current/windows.html](https://www.elastic.co/guide/en/kibana/current/windows.html) 를
참고하여 설치한다.

**Kibana 기동**
```shell
C:\myhome\03_Study\13_SpringCloud\kibana-7.10.1-windows-x86_64> ./bin/kibana.bat
```

![Kibana 기동](/assets/img/dev/20210104/kibana.png)

이제 [http://localhost:5601/](http://localhost:5601/) 로 Kibana 콘솔 화면에 접속해보자.

![Kibana 콘솔](/assets/img/dev/20210104/kibana2.png)

---

### 3.3. Logstash 설치
설치 파일은 [https://artifacts.elastic.co/downloads/logstash/logstash-7.10.2-windows-x86_64.zip](https://artifacts.elastic.co/downloads/logstash/logstash-7.10.2-windows-x86_64.zip) 이며, 
설치 상세 설명은 [https://www.elastic.co/kr/downloads/logstash](https://www.elastic.co/kr/downloads/logstash) 를
참고한다.

Logstash를 설치한 위치에서 config 폴더에 보면 logstash-sample.conf 파일이 있는데 해당 파일을 복사하여 logstash.conf 라는 파일을 하나 생성한다.<br />
그리고 *logstash.conf* 파일을 아래와 같이 수정한다.

**C:\myhome\03_Study\13_SpringCloud\logstash-7.10.2\config > logstash.conf**
```editorconfig
input {
  tcp {
    port => 4560
	host => localhost
	codec => json_lines
  }
}
output {
  elasticsearch {
    hosts => ["http://localhost:9200"]
	index => "logstash-%{+YYYY.MM.dd}"
  }
  stdout {
	codec => rubydebug
  }
}
```

**Logstash 기동**
```shell
C:\myhome\03_Study\13_SpringCloud\logstash-7.10.2> ./bin/logstash -f ./config/logstash.conf
```

![Logstash 기동](/assets/img/dev/20210104/logstash.png)

---

## 4. Springboot에 Logging 설정

이제 로그를 통합시키고자 하는 마이크로서비스에 Logstash 의존성을 추가하여 Logback 을 Logstash 에 통합한다.

**event-service, member-service > pom.xml**
```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>6.6</version>
</dependency>
```

/src/main/resources 폴더 아래 logback.xml 파일을 만들어 기본 logback 설정을 오버라이드한다.

아래 파일의 내용은 4560 포트로 리스닝하고 있는 Logstash 서비스로 흘러드는 모든 로그 메시지를 처리할 새 TCP 소켓 appender 로 기본 Logback appender 를 오버라이드한다.

**event-service, member-service > ... > resources > logback.xml**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- logback에 대한 기본적인 설정을 base.xml을 통해서 제공함.console,file appender 를 base.xml에 include 하고 있음-->
    <include resource="org/springframework/boot/logging/logback/base.xml" />
    <include resource="org/springframework/boot/logging/logback/defaults.xml" />

    <appender name="STASH" class="net.logstash.logback.appender.LogstashAccessTcpSocketAppender">
        <destination>localhost:4560</destination>
        <!-- encoder 필요 -->
        <encoder class="net.logstash.logback.encoder.LogstashEncoder" />
    </appender>

    <root level="INFO">
        <appender-ref ref="CONSOLE" />
        <appender-ref ref="STASH" />
    </root>
</configuration>
```

---

## 5. Kibana 를 통해 여러 마이크로서비스의 로그를 통합하여 조회

이제 logstash, elasticsearch, kibana 를 각각 기동한다.

```shell
C:\Program Files\Elastic\Elasticsearch\7.10.1> ./bin/elasticsearch
C:\myhome\03_Study\13_SpringCloud\kibana-7.10.1-windows-x86_64> ./bin/kibana.bat
C:\myhome\03_Study\13_SpringCloud\logstash-7.10.2> ./bin/logstash -f ./config/logstash.conf
```
[http://localhost:9200/](http://localhost:9200/) 와 [http://localhost:5601/app/home#/](http://localhost:5601/app/home#/) 로 접속하여
Elasticsearch와 Kibana가 제대로 기동되었는지 확인한다.

---

### 5.1. Index 생성

[http://localhost:5601/app/home#/](http://localhost:5601/app/home#/) 로 접속하여 우측 상단의 *Manage* 로 들어간 후 
좌측의 *Kinaba > Index Patterns* 에 들어가 *Create index pattern* 버튼을 클릭한다.

![Index 생성 1](/assets/img/dev/20210104/kibana3.png)
![Index 생성 2](/assets/img/dev/20210104/kibana4.png)
![Index 생성 3](/assets/img/dev/20210104/kibana5.png)

*logstash.conf* 에서 인덱스를 *index => "logstash-%{+YYYY.MM.dd}"* 로 설정하였으므로 logstash-* 로 인덱스명을 입력한 후 다음 단계로 넘어간다.<br />
(저는 이미 해당 인덱스를 생성하여 Next Step 버튼이 활성화되지 않은 상태로 보입니다)

![Index 생성 4](/assets/img/dev/20210104/kibana6.png)

이제 로그 시간으로 사용할 필드를 지정하는데 logstash appender 가 자동으로 생성해준 timestamp 값을 지정한다.

![Index 생성 5](/assets/img/dev/20210104/kibana7.png)

---

### 5.2. 로그 조회

이제 로그를 심은 후 로그 발생 후 로그를 확인해보자.

**member-service > MemberController.java, event-service > EventController.java**
```java
// member-service > MemberController.java
@RestController
@RequestMapping("/member")
public class MemberController {
    private static final Logger logger = LoggerFactory.getLogger(MemberController.class);

    // ... 생략

    @GetMapping(value = "name/{nick}")
    public String getYourName(ServletRequest req, @PathVariable("nick") String nick) {
        logger.info("[MEMBER] name/{nick} logging...nick is {}.", nick);
        return "[MEMBER] Your name is " + customConfig.getYourName() + " / nickname is " + nick + " / port is " + req.getServerPort();
    }

// event-service > EventController.java
@RestController
@RequestMapping("/event")
public class EventController {
    private static final Logger logger = LoggerFactory.getLogger(EventController.class);

    // ... 생략

    @GetMapping(value = "name/{nick}")
    public String getYourName(ServletRequest req, @PathVariable("nick") String nick) {
        logger.info("[EVENT] name/{nick} logging...nick is {}.", nick);
        return "[EVENT] Your name is " + customConfig.getYourName() + ", nickname is " + nick + ", port is " + req.getServerPort();
    }
```

그리고 [http://localhost:5555/api/mb/member/name/hyori3](http://localhost:5555/api/mb/member/name/hyori3), [http://localhost:5555/api/evt/event/name/hyori2](http://localhost:5555/api/evt/event/name/hyori2) 를
호출하여 로그를 발생시키자.

logstash 콘솔에 아래와 같이 로그가 찍히는 것을 확인할 수 있다.

![logstash에서 로그 확인](/assets/img/dev/20210104/logstash2.png)

이제 kibana 에서 로그를 확인해보자.

Kibana 콘솔인 [http://localhost:5601/app/home#/](http://localhost:5601/app/home#/) 로 접속하여 *Kibana > Discover* 로 들어간다.

![Kibana에서 로그 확인 1](/assets/img/dev/20210104/kibana8.png)

원하는 로그를 필터링하여 보려면 상단 필터링 조건을 이용하면 된다.

![Kibana에서 로그 확인 2](/assets/img/dev/20210104/kibana9.png)

---

지금까지 로그 집중화를 위한 ELK 스택에 대해 살펴보았다.<br />
이 후엔 분산 로그 추적을 직접 구현해보는 예제를 포스팅하도록 하겠다.

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [스프링 부트와 스프링 클라우드로 배우는 스프링 마이크로서비스](http://acornpub.co.kr/book/spring-microservices)
* [ELK 스택이란?](https://www.elastic.co/kr/what-is/elk-stack)
* [ELK 스택 설치 전체 플로우](https://www.elastic.co/kr/start)
* [Elastic Stack 설명](https://17billion.github.io/elastic/2017/06/30/elastic_stack_overview.html)
* [Beats](https://www.elastic.co/guide/en/beats/libbeat/5.5/beats-reference.html)
* [ElasticSearch, Kibana 다운로드](https://www.elastic.co/kr/elastic-stack)
* [ElasticSearch 설치 설명](https://www.elastic.co/guide/en/elasticsearch/reference/current/windows.html)
* [ElasticSearch > Logstash 공홈](https://www.elastic.co/kr/logstash)
* [Logstash 다운로드](https://www.elastic.co/kr/downloads/logstash)
* [Kibana 설치 설명](https://www.elastic.co/guide/en/kibana/current/windows.html)
* [Logstash에 로그를 보내자.](https://twowinsh87.github.io/etc/2019/05/30/etc-springboot-logbackAndLogstash/)
* [Logstash 공식문서](https://github.com/Logstash/Logstash-logback-encoder#tcp-appenders)
* [Logback Appenders 공식문서](https://logback.qos.ch/manual/appenders.html)
* [Logging과 Profile 전략](https://meetup.toast.com/posts/149)
* [Spring Boot - Logging](https://www.sangkon.com/hands-on-springboot-logging/)
* [Losstash 셋팅](https://hyungyu-lee.github.io/articles/2019-05/example-of-elk)
* [Losstash 셋팅2](https://dev-t-blog.tistory.com/30)
* [Losstash 셋팅3](https://www.sysnet.pe.kr/2/0/12312)

