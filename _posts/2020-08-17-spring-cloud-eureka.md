---
layout: post
title:  "Spring Cloud - Spring Cloud Eureka"
date:   2020-08-26 10:00
categories: dev
tags: msa spring-cloud-eureka feign
---

이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 스프링 클라우드 프로젝트 중 Spring Cloud Eureka 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br /><br />
>***2. Eureka - Service Registry & Discovery***<br />
>   - Service Registry & Discovery (서비스 등록 및 발견)
>       - 서비스 동적 등록 및 정보 공유
>       - 서비스 동적 발견
>       - 상태 모니터링
>   - Eureka
>   - 유레카 구축
>       - 유레카 서버 구축
>       - 유레카 클라이언트 구축 (유레카 서버에 서비스 동적 등록)
>       - 서비스 검색 (RestTemplate, Feign 사용)
>   - 유레카 고가용성<br />

Spring Cloud Config Server 에 대한 자세한 내용은 [여기](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)에서 확인이 가능하다.

*[Spring Cloud - Spring Cloud Eureka (상세 설정편)](https://assu10.github.io/dev/2020/12/05/spring-cloud-eureka-configuration/)* 과
함께 보면 도움이 됩니다.

---

## 1. Service Registry & Discovery (서비스 등록 및 발견)
클라우드가 아닌 환경에서 서비스의 발견은 로드 밸런서로 해결이 되었다.
이 로드 밸런서가 서비스에 대한 프록시 역할을 하므로 서비스에 매핑된 정보가 있어야 하는데 이 매핑 규칙을 수동으로 정의해야 하기 때문에 인프라스트럭처의
복잡성이 높아진다. (새로운 서비스를 인스턴스 시작 시점이 아닌 수동으로 등록)

MSA 로 설계된 환경에서 중앙 집중식 인프라 스트럭처는 확장성에 제한이 있다.
예를 들어 많은 수의 마이크로 서비스가 있다면 서버와 인스턴스의 갯수를 동적으로 조절할 상황이 발생할 수 있는데
이 경우 예측을 통해 서버의 URL 을 정적으로 지정하는 것은 부적합하다.

마이크로서비스가 자신의 서비스를 동적으로 등록하여 스스로 라이프 사이클을 관리할 수 있게 하고, 서비스가 등록되면 서비스 탐색 대상에 포함되어 발견되게 함으로써
최대한 수동 작업을 피하고 자동화하는 것이 좋다.

이러한 부분을 지원하기 위해 MSA 환경에서는 **서비스 디스커버리 메커니즘**을 사용한다.
> - Peer to Peer
>   - 서비스 디스커버리 클러스터의 각 노드는 서비스 인스턴스의 상태를 공유
> - 부하 분산
>   - 서비스 디스커버리는 요청을 동적으로 분산
>   - 정적이며 수동으로 관리되는 ***로드 밸런서가 서비스 디스커버리로 대체됨***
> - 회복성
>   - 서비스 디스커버리 클라이언트는 서비스 정보를 로컬에 캐시하여 서비스 디스커버리 서비스가 가용하지 않을 때도 로컬 캐시에 저장된 정보를 기반으로 동작
> - 장애 내성
>   - 서비스 디스커버리는 서비스 인스턴스의 비정상을 탐지하고 가용서비스 목록에서 인스턴스 제거

**서비스 디스커버리 메커니즘**을 구현하려면 아래 4가지 개념을 먼저 이해해야 한다.
> - 서비스 동적 등록
>   - 서비스를 서비스 디스커버리 에이전트에 어떻게 등록하는가?
> - 서비스 동적 발견
>   - 서비스 클라이언트가 어떻게 서비스 정보를 검색하는가?
> - 정보 공유
>   - 서비스 정보를 어떻게 공유하는가?
> - 상태 모니터링
>   - 서비스가 자신의 가용 여부를 어떻게 전달하는가?

### 1.1. 서비스 동적 등록 및 정보 공유
서비스 인스턴스가 시작될 때 자신의 물리적 위치와 경로, 포트를 서비스 레지스트리에 등록한다.
각 인스턴스에는 고유 IP 주소와 포트가 있지만 동일한 서비스 ID로 등록한다. (=서비스 ID는 동일한 서비스 인스턴스 그룹을 식별하는 키)
서비스는 1개의 서비스 디스커버리 인스턴스에만 등록하며, 서비스가 등록되고 나면 서비스 디스커버리는 Peer to Peer 로 클러스터에 있는 다른 노드에 전파한다.

### 1.2. 서비스 동적 발견
서비스 레지스트리에서 현재 가용 중인 필요한 서비스를 호출할 수 있게 해준다.
즉, 정적으로 서비스 URL 을 설정하고 관리하는 대신 서비스 레지스트리를 통해 그때그때 사용 가능한 URL 을 발견할 수 있다.
또한 빠른 처리를 위해 인스턴스들은 주기적으로 레지스트리 데이터를 로컬에 캐시하여, 서비스 호출 시마다 캐싱된 데이터에서 위치 정보를 검색한다.
서비스 호출이 실패히면 로컬에 있던 캐시는 무효화되고 레지스트리로부터 새로 정보를 받아온다.

### 1.3. 상태 모니터링
인스턴스들은 주기적으로 자신의 상태를 레지스트리에 알린다.
레지스트리는 이 요청이 몇 번 오지 않으면 가용할 수 없는 서비스로 간주하여 레지스트리에서 해당 서비스를 제외시킨다.

설명만 들었을 땐 개념이 확 와닿지 않을 수도 있는데,
위 내용은 오늘 다룰 Eureka 의 동작 원리와 정확히 일치하므로 지금 당장 이해가 되지 않는다고 걱정할 필요는 없다.

이제 Eureka 에 대해 알아본 후 실제 구축을 해보도록 하자.

---

## 2. Eureka
Eureka 는 자가 등록, 동적 발견 및 부하 분산을 담당하며 위의 서비스 디스커버리 패턴을 구현할 수 있도록 도와준다.
클라이언트 측 부하 분산을 위해 내부적으로 Ribbon 을 사용하므로 이미 Ribbon 을 사용하고 있다면 Ribbon 은 제거해도 좋다.

Eureka 는 서버 컴포넌트(이하 유레카 서버)와 클라이언트 컴포넌트(이하 유레카 클라이언트)로 이루어져 있다.

- 유레카 서버
    - 모든 마이크로서비스가 자신의 가용성을 등록하는 레지스트리
    - 등록되는 정보는 서비스 ID와 URL 이 포함되는데 마이크로서비스는 유레카 클라이언트를 이용해서 이 정보를 유레카 서버에 등록


- 유레카 클라이언트
    - 등록된 마이크로서비스를 호출해서 사용할 때 유레카 클라이언트를 이용해서 필요한 서비스를 발견
    - 유레카 서버는 유레카 서버인 동시에 서로의 상태를 동기화하기 서로를 바라보는 유레카 클라이언트이기도 함 (=다른 유레카 서버와 상태를 동기화함)<br />
      이 점은 유레카 서버의 고가용성을 위해 여러 대의 유레카 서버 운영 시 유용함

아래 Eureka 동작 흐름을 살펴보자.

![유레카 동작 흐름](/assets/img/dev/20200816/eureka.png)


>서비스 부트스트래핑 시점에 각 마이크로 서비스는 유레카 서버에 서비스 ID와 URL 등의 정보를 등록한 후 30초 간격으로 ping 을 날려 자신의 가용성을 알림<br />
>이때 ping 요청이 몇 번 오지 않으면 가용 불가한 서비스로 간주되어 레지스트리에서 제외됨<br /><br />
>유레카 클라이언트는 유레카 서버로부터 레지스트리 정보를 읽어와 로컬에 캐싱하고, 이 캐싱된 정보는 30초마다 갱신됨
>(새로 가져온 정보와 현재 캐싱된 정보의 차이를 가져오는 방식)<br /><br />
>다른 마이크로서비스 종단점 접속 시도 시 유레카 클라이언트는 요청된 서비스 ID를 기준으로 현재 사용 가능한 서비스 목록을 제공하고,
>리본은 해당 서비스 인스턴스들에게 요청을 분산함<br />

---

## 3. 유레카 구축
이전 포스팅인 [컨피그 서버](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)를 진행했다면
아래 구성도가 이미 로컬에 셋팅되어 있을 것이다.

![컨피그 서버](/assets/img/dev/20200808/config.png)

기존에 진행한 컨피그 서버에 유레카를 추가하면 아래와 같은 구성도가 된다.
언뜻 보면 복잡해 보이지만 회색 음영된 부분은 컨피그 서버 구축 시 이미 구성된 부분으로 더 이상 신경 쓰지 않아도 된다.

![컨피그 서버 + 유레카](/assets/img/dev/20200816/config_eureka.png)

이 포스팅은 내용을 이해하기 위한 것이기 때문에 유레카 서버를 클러스터 모드가 아닌 독립 설치형 모드로 진행할 것이다.
따라서 위 구성도에선 유레카 서버 != 유레카 클라이언트 이다.

유레카 서버 구축에 앞서 다른 서비스 ID를 가진 마이크로서비스가 필요하니 회원 마이크로서비스를 만들었던 것과 동일한 방식으로
이벤트 마이크로서비스를 미리 만들어두자.<br />
잘 안되는 분들은 [여기](https://github.com/assu10/msa-springcloud/commit/57dfc09b2888b98e718502c0ddcb5195703fa7a4)를 참고하세요.

---

### 3.1. 유레카 서버 구축
새로운 스트링부트 프로젝트 생성 후 Config Client, Eureka Server, Actuator Dependency 를 추가한다.

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
    <artifactId>spring-cloud-starter-netflix-eureka-server</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-bus-amqp</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.security</groupId>
    <artifactId>spring-security-rsa</artifactId>
</dependency>
```

유레카 서버도 컨피그 서버를 사용하므로 bootstrap.yaml 을 생성해 준 후 아래와 같이 구성을 설정한다.

**eurekaserver > application.yaml, bootstrap.yaml**
```yaml
## eurekaserver > application.yaml
server:
  port: 8761          ## 유레카 서버가 수신 대기할 포트

## eurekaserver > bootstrap.yaml
spring:
  application:
    name: eurekaserver    ## 서비스 ID (컨피그 클라이언트가 어떤 서비스를 조회하는지 매핑)
  profiles:
    active: default         ## 서비스가 실행할 기본 프로파일
  cloud:
    config:
      uri: http://localhost:8889  ## 컨피그 서버 위치
```

유레카 서버로 지정하기 위해 부트스트래핑 클래스에 `@EnableEurekaServer` 을 추가한다.

**EurekaserverApplication.java**
```java
@EnableEurekaServer
@SpringBootApplication
public class EurekaserverApplication {
    public static void main(String[] args) {
        SpringApplication.run(EurekaserverApplication.class, args);
    }
}
```

컨피그 저장소에 유레카 서버에 대한 설정 정보를 셋팅한다.

![컨피그 저장소 디렉토리 구조](/assets/img/dev/20200816/folder.png)

컨피그 서버의 bootstrap.yaml 에 유레카 구성정보 폴더 경로를 추가한다.

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
          search-paths: member-service, event-service, eurekaserver    ## 구성 파일을 찾을 폴더 경로
        encrypt:
          enabled: false
```

컨피그 저장소의 유레카 서버 설정을 한다.

**config-repo > eurekaserver.yaml**
```yaml
your.name: "EUREKA DEFAULT"
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
  server:
    wait-time-in-ms-when-sync-empty: 5    # 유레카 서버가 시작되고 Peer nodes 로부터 Instance 들을 가져올 수 없을 때 얼마나 기다릴 것인가? (디폴트 3000ms, 운영 환경에선 삭제 필요)
      # 일시적인 네트워크 장애로 인한 서비스 해제 막기 위한 보호모드 해제 (디폴트 60초, 운영에선 삭제 필요)
      # 원래는 해당 시간안에 하트비트가 일정 횟수 이상 들어오지 않아야 서비스 해제하는데 false 설정 시 하트비트 들어오지 않으면 바로 서비스 제거
    enable-self-preservation: false
  client:
    register-with-eureka: false           # 유레카 서비스에 (자신을) 등록하지 않는다. (클러스터 모드가 아니므로) -> false 로 해도 피어링이 된다.
    fetch-registry: false                 # 레지스트리 정보를 로컬에 캐싱하지 않는다. (클러스터 모드가 아니므로)
    serviceUrl:
      defaultZone: http://peer1:8762/eureka/
```

유레카 서버/클라이언트 각 설정값에 대한 설명은 
[Spring Cloud - Spring Cloud Eureka (상세 설정편)](https://assu10.github.io/dev/2020/12/05/spring-cloud-eureka-configuration/) 을 참고해주세요.

```shell
C:\> mvn clean install
C:\configserver\target>java -jar configserver-0.0.1-SNAPSHOT.jar
C:\eurekaserver\target>java -jar eurekaserver-0.0.1-SNAPSHOT.jar
```

컨피그 서버와 유레카 서버를 띄웠다면 [http://localhost:8761/](http://localhost:8761/) 에 접속하여 유레카 콘솔 화면을 확인해보자.

![유레카 콘솔화면](/assets/img/dev/20200816/eureka_console.png)


콘솔의 "Instances currently registered with Eureka"를 보면 아직 아무런 인스턴스도 등록되어 있지 않다고 나오는데
아직 아무런 유레카 클라이언트가 실행되지 않았기 때문이다.

이제 유레카 서버에 서비스를 동적으로 등록해보자.

---

### 3.2. 유레카 클라이언트 구축 (유레카 서버에 서비스 동적 등록)
유레카 서버에 마이크로서비스(회원 서비스, 이벤트 서비스)를 등록하기 위해 각 마이크로서비스에 Eureka Client Dependency 를 추가한다.

**pom.xml**
```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>
```

---

컨피스 서버 원격 저장소 각 환경설정 파일에 아래 구성 내용을 추가한다.

**conf-repo > member-service.yaml, event-service.yaml**
```yaml
## conf-repo > member-service.yaml, event-service.yaml
your.name: "MEMBER DEFAULT..."
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
eureka:   ## 추가
  instance:
    prefer-ip-address: true       ## 서비스 이름 대신 IP 주소 등록
    lease-renewal-interval-in-seconds: 3  # 디스커버리한테 3초마다 하트비트 전송 (디폴트 30초)
    lease-expiration-duration-in-seconds: 2 # 디스커버리는 서비스 등록 해제 하기 전에 마지막 하트비트에서부터 설정된 시간(second) 기다린 후 서비스 등록 해제 (디폴트 90초)
  client:
    register-with-eureka: true    ## 유레카 서버에 서비스 등록
    fetch-registry: true          ## 레지스트리 정보를 로컬에 캐싱
```

유레카 서비스에 등록되는 서비스는 애플리케이션 ID와 인스턴스 ID가 있는데
애플리케이션 ID(`spring.application.name`)는 서비스 인스턴스 그룹을 의미하고,
인스턴스 ID는 개별 서비스 인스턴스를 인식하는 임의의 숫자이다.

부트스트랩 클래스에 `@EnableEurekaClient` 을 추가한다.

**member-service > MemberServiceApplication.java, event-service > EventServiceApplication.java**
```java
// member-service > MemberServiceApplication.java
// event-service > EventServiceApplication.java
@EnableEurekaClient     // 추가
@SpringBootApplication
public class MemberServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MemberServiceApplication.class, args);
    }
}
```

이제 컨피그 서버, 유레카 서버, 회원/이벤트 마이크로서비스 기동 후 각 마이크로서비스들이 유레카 서버에 등록이 되는지 확인해보자.

```shell
C:\> mvn clean install
C:\eurekaserver\target>java -jar eurekaserver-0.0.1-SNAPSHOT.jar
C:\member-service\target>java -jar member-service-0.0.1-SNAPSHOT.jar
C:\event-service\target>java -Dserver.port=8071 -jar event-service-0.0.1-SNAPSHOT.jar
C:\event-service\target>java -Dserver.port=8070 -jar event-service-0.0.1-SNAPSHOT.jar
```

[http://localhost:8761/](http://localhost:8761/) 에 접속하여 유레카 콘솔 화면을 보자.
이벤트 서비스 2개의 인스턴스, 회원 서비스 1개의 인스턴스가 각각 유레카 서버에 등록되어 있는 부분을 확인할 수 있다.

![유레카 콘솔](/assets/img/dev/20200816/eureka_console2.png)

[http://localhost:8761/eureka/apps/](http://localhost:8761/eureka/apps/) 에 접속하면 유레카 서버에 등록된 레지스트리 내용을 볼 수 있다.

![유레카 콘솔](/assets/img/dev/20200816/eureka_all.png)

또한 [http://localhost:8761/eureka/apps/event-service](http://localhost:8761/eureka/apps/event-service) 이런 식으로 주소 뒤에 애플리케이션 ID를 붙이면 해당 애플리케이션의 정보만 노출된다.

참고로 서비스를 유레카 서버에 등록하면 서비스가 가용하다고 확인될 때까지 유레카 서버는 30초간 연속 세 번의 상태 정보를 확인하며 대기한다.
위에선 유레카 서버 구성 파일의 `wait-time-in-ms-when-sync-empt`를 5ms로 설정하여 서비스 시작 즉시 유레카 서버에 등록이 되지만 운영 시엔 30초 정도 기다려야 서비스 검색이 가능하다.

---

### 3.3. 서비스 검색
이제 유레카 서버에 모든 마이크로서비스가 등록되었기 때문에 회원 서비스는 이벤트 서비스 위치를 직접 알지 못해도 호출이 가능하다.
각 다른 마이크로서비스를 검색하여 호출하는 방법은 3가지가 있는데 이 포스팅에선 넷플릭스 Feign 클라이언트와 RestTemplate 로 호출하는 방법으로 진행할 예정이다.
스프링 디스커버리 클라이언트에 대해선 간략하게 내용만 보도록 하겠다.

- 스프링 디스커버리 클라이언트
    - 디스커버리 클라이언트와 표준 스프링 RestTemplate 클래스를 사용
    - `@EnableDiscoveryClinet` 사용
    - DiscoveryClient 를 직접 호출하면 서비스 목록이 반환되지만, 목록에서 서비스를 선택할 책임은 사용자에게 있음
      (=리본 클라이언트 부하 분산 못 함)
    - 서비스 호출에 사용할 URL 을 직접 생성해야 함
- RestTemplate 이 활성화된 스프링 디스커버리 클라이언트
    - `@LoadBalanced`로 RestTemplate bean 생성 메서드 정의
    - 스프링 RestTemplate 를 사용해 리본 기반의 서비스 호출
    - 스프링 클라우드 초기 릴리스에 리본은 자동으로 RestTemplate 클래스를 지원했지만 스프링 클라우드 Angel 릴리스 이후 RestTemplate 는
      더 이상 리본에서 지원되지 않음. (=`@LoadBalanced` 직접 추가해야 함)
- 넷플릭스 Feign 클라이언트
    - `@EnagleFeignClients` 사용

---

#### 3.3.1 RestTemplate 으로 서비스 검색
리본 지원의 RestTemplate 를 사용하여 회원 서비스에서 이벤트 서비스의 REST API 를 호출해보도록 하자.

리본 지원 RestTemplate 를 사용하려면 부트스트랩 클래스에 `@LoadBalanced` 로 RestTemplate 빈 생성 메서드를 정의해야 한다.

>스프링 클라우드 버전 Angel 이후 RestTemplate 은 더 이상 리본에서 지원되지 않는다.
>RestTemplate 에서 리본을 사용하려면 `@LoadBalanced` 를 직접 추가해야 한다.

이벤트 서비스 컨트롤러에 회원 서비스에서 호출할 메서드를 만든다.

**event-service > EventController.java** 
```java
/**
 * 회원 서비스에서 호출할 메서드
 */
@GetMapping(value = "gift/{name}")
public String gift(@PathVariable("name") String gift) {
    return "[EVENT] Gift is " + gift;
}
```

회원 서비스 부트스트랩 클래스에 RestTemplate 빈을 생성한다.

**member-service > MemberServiceApplication.java**
```java
@SpringBootApplication
@EnableEurekaClient
public class MemberServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MemberServiceApplication.class, args);
    }

    @LoadBalanced       // 스프링 클라우드가 리본이 지원하는 RestTemplate 클래스 생성하도록 지시
    @Bean
    public RestTemplate getRestTemplate() {
        return new RestTemplate();
    }
}
```

RestTemplate Client 를 생성한다.

여기서 주의 깊게 볼 부분은 바로 URL 이다.

http://**event-service**/event/gift/{name} 에서 **event-service** 는 유레카에 등록된 이벤트 서비스 ID 이다.
실제 서비스 위치와 포트는 완전히 감춰져 있는 상태이다.
리본은 RestTemplate 클래스를 사용하는 모든 요청을 라운드 로빈 방식으로 부하 분산한다. 

**member-service > EventRestTemplateClient.java**
```java
@Component
public class EventRestTemplateClient {

    RestTemplate restTemplate;

    public EventRestTemplateClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public String gift(String name) {
        ResponseEntity<String> restExchange =
                restTemplate.exchange(
                        "http://event-service/event/gift/{name}",
                        HttpMethod.GET,
                        null, String.class, name
                );

        return restExchange.getBody();
    }
}
```

이제 실제 호출하는 부분을 보자.

**member-service > MemberController.java**
```java
/**
 * RestTemplate 를 이용하여 이벤트 서비스의 REST API 호출
 */
@GetMapping(value = "gift/{name}")
public String gift(ServletRequest req, @PathVariable("name") String name) {
    return "[MEMBER] " + eventRestTemplateClient.gift(name) + " / port is " + req.getServerPort();
}
```

[http://localhost:8090/member/gift/flower](http://localhost:8090/member/gift/flower) 를 호출해보면 정상적으로 RestTemplate 를 사용하여 
회원 서비스가 이벤트 서비스의 REST API 를 호출하여 응답받는 부분을 확인할 수 있다.


![RestTemplate 를 이용한 호출](/assets/img/dev/20200816/resttemplate.png)

---

#### 3.3.2 Feign 으로 서비스 검색
Feign 의 자세한 내용은 이전 포스트인 [Spring Cloud Feign](https://assu10.github.io/dev/2020/06/18/spring-cloud-feign/) 를 참고하면 된다.

아래는 Feign 을 이용하여 이벤트 서비스(=Consumer)에서 회원 서비스(=Provider)를 호출하는 방법이다.

Eureka 내 Ribbon 기능이 정상적으로 동작하는지 확인하기 위해 호출하고자 하는 메소드 리턴값에 포트값을 함께 넣어주었다.

**member-service > MemberController.java**
```java
// 이벤트 서비스에서 호출할 회원 서비스 내 메소드

@GetMapping(value = "name/{nick}")
public String getYourName(ServletRequest req, @PathVariable("nick") String nick) {
    return "[MEMBER] Your name is " + customConfig.getYourName() + " / nickname is " + nick + " / port is " + req.getServerPort();
}
```

이벤트 서비스에 open-feign Dependency 를 추가한다.
**event-service > pom.xml**
```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
```

이벤트 서비스 부트스트랩 클래스에 `@EnableFeignClients` 를 추가한다.

**event-service > EventServiceApplication**
```java
@EnableEurekaClient
@SpringBootApplication
@EnableFeignClients     // 추가
public class EventServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(EventServiceApplication.class, args);
    }

}
```

이벤트 서비스에 회원 Feign Client 인터페이스를 만들어준다.
`@FeignClient("${member.service.id}")`는 회원 서비스의 서비스 ID로 유레카 서버에 등록된 서비스 ID를 넣어준다.

***event-service > client > MemberFeignClient.java*
```java
package com.assu.cloud.eventservice.client;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

//@FeignClient(name="member-service",url = "http://localhost:8090/member/")
@FeignClient("${member.service.id}")
public interface MemberFeignClient {
    @GetMapping(value = "member/name/{nick}")
    String getYourName(@PathVariable("nick") String nick);
}
```

실제 호출하는 로직은 아래와 같다.

**event-service > EventController.java**
```java
public class EventController {

    private CustomConfig customConfig;
    private MemberFeignClient memberFeignClient;        // 추가

    public EventController(CustomConfig customConfig, MemberFeignClient memberFeignClient) {
        this.customConfig = customConfig;
        this.memberFeignClient = memberFeignClient;
    }

    @GetMapping(value = "name/{nick}")
    public String getYourName(@PathVariable("nick") String nick) {
        return "[EVENT] Your name is " + customConfig.getYourName() + ", nickname is " + nick;
    }

    /**
     * 회원 서비스 REST API 호출
     */
    @GetMapping(value = "member/{nick}")
    public String getMemberName(@PathVariable("nick") String nick) {
        return memberFeignClient.getYourName(nick);
    }
}
```

이제 회원 서비스의 REST API 를 호출한 준비는 끝났다.
직접 호출하여 확인해보자.

```shell
C:\> mvn clean install
C:\configserver>java configserver-0.0.1-SNAPSHOT.jar
C:\member-service\target>java -Dserver.port=8090 -jar member-service-0.0.1-SNAPSHOT.jar
C:\member-service\target>java -Dserver.port=8091 -jar member-service-0.0.1-SNAPSHOT.jar
C:\event-service\target>java event-service-0.0.1-SNAPSHOT.jar
```

현재 이벤트 서비스 인스턴스 1개, 회원 서비스 인스턴스 2개가 떠 있는 상태이다.
![유레카 콘솔](/assets/img/dev/20200816/eureka_console3.png)

이벤트 서비스에서 회원 서비스 호출 시 8090, 8091를 번갈아 가며 호출하는 것을 확인할 수 있다.
![회원 서비스의 8090 인스턴스 호출](/assets/img/dev/20200816/8090.png)

![회원 서비스의 8091 인스턴스 호출](/assets/img/dev/20200816/8091.png)

---

## 4. 유레카 고가용성
유레카 클라이언트는 유레카 레지스트리 정보를 받아와 로컬 캐싱하여 캐싱된 내용 기반으로 동작하고,
30초 간격으로 변경 사항을 로컬 캐시에 다시 반영한다.
따라서 유레카 서버가 멈추어도 마이크로서비스들은 영향도없이 동작한다.
하지만 이렇게 되면 유레카 클라이언트들이 최신 정보를 반영하지 않음으로 일관성에 문제가 생길 수 있기 때문에 유레카 서버는 항상 고가용성을 유지해야 한다.

우선 같은 도메인(localhost)으로는 defaultZone 셋팅이 안되므로 호스트 파일을 아래와 같이 수정해준다.

```shell
-- C:\Windows\System32\drivers\etc\hosts

127.0.0.1 peer1
127.0.0.1 peer2
```

아래는 유레카 서버의 application-*.yaml 파일이다.

파일명은 각각 application-peer1.yaml, application-peer2.yaml 이다.

> intellij 에서 작성 시 `eureka.client.serviceUrl.defaultZone` 는 자동완성으로 안 뜨는데 IDE 이슈이므로 무시하도록 한다.

`eureka.client.serviceUrl.defaultZone` 를 보면 peer1.yaml 에선 peer2 유레카를 바라보게 하고, peer2.yaml 에선 peer1 유레카를 바라보도록 설정해놓았다.

이 설정으로 인해 두 유레카 서버는 서로 peering 이 가능하게 된다.

**eurekaserver > applicatoin-peer1.yaml**
```yaml
spring:
  application:
    name: eurekaserver-peer1
  profiles: peer1
server:
  port: 8762          # 유레카 서버가 수신 대기할 포트
management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    shutdown:
      enabled: true
eureka:
  client:
    register-with-eureka: false           # 유레카 서비스에 (자신을) 등록하지 않는다. (클러스터 모드가 아니므로) -> false 로 해도 피어링이 된다.
    fetch-registry: false                 # 레지스트리 정보를 로컬에 캐싱하지 않는다. (클러스터 모드가 아니므로)
    serviceUrl:
      defaultZone: http://peer2:8763/eureka/
logging:
  level:
    com.netflix: WARN
    org.springframework.web: WARN
    com.assu.cloud: DEBUG
```

**eurekaserver > applicatoin-peer2.yaml**
```yaml
spring:
  application:
    name: eurekaserver-peer2
  profiles: peer2
server:
  port: 8763          # 유레카 서버가 수신 대기할 포트
management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    shutdown:
      enabled: true
eureka:
  client:
    register-with-eureka: false           # 유레카 서비스에 (자신을) 등록하지 않는다. (클러스터 모드가 아니므로)
    fetch-registry: false                 # 레지스트리 정보를 로컬에 캐싱하지 않는다. (클러스터 모드가 아니므로)
    serviceUrl:
      defaultZone: http://peer1:8762/eureka/
logging:
  level:
    com.netflix: WARN
    org.springframework.web: WARN
    com.assu.cloud: DEBUG
```

이제 각 유레카 클라이언트를 아래와 같이 셋팅해준다.

`eureka.client.serviceUrl.defaultZone` 은 유레카 1대만 (peer1) 바라보도록 설정한다. 유레카 peer1 과 peer2 는 서로 피어링 관계이므로 
유레카 peer1 에만 서비스를 등록하여도 유레카 peer2 에 자동 갱신된다.

여기선 이벤트 서비스를 예로 들어 설명한다.

**event-service > application.yaml**
```yaml
server:
  port: 8070
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
    lease-renewal-interval-in-seconds: 3  # 디스커버리한테 1초마다 하트비트 전송 (디폴트 30초)
    lease-expiration-duration-in-seconds: 2 # 디스커버리는 서비스 등록 해제 하기 전에 마지막 하트비트에서부터 2초 기다림 (디폴트 90초)
  client:
    register-with-eureka: true    # 유레카 서버에 서비스 등록
    fetch-registry: true          # 레지스트리 정보를 로컬에 캐싱
    serviceUrl:
      defaultZone: http://peer1:8762/eureka/
    registry-fetch-interval-seconds: 3    # 서비스 목록을 3초마다 캐싱
```

이제 유레카를 띄운 후 서로 피어링이 되는지 확인해보도록 하자.

```shell
C:\eurekaserver\target>java -DSpring.profiles.active=peer1 -jar eurekaserver-0.0.1-SNAPSHOT.jar
C:\eurekaserver\target>java -DSpring.profiles.active=peer2 -jar eurekaserver-0.0.1-SNAPSHOT.jar
```

이 후 이벤트 서비스를 띄운 후 각 유레카 콘솔에 접속해보자.

![peer1 유레카 콘솔](/assets/img/dev/20200816/peering1.png)

![peer2 유레카 콘솔](/assets/img/dev/20200816/peering2.png)

peer1 은 peer2 를, peer2 는 peer1 을 피어링하고 있는 것을 확인할 수 있다.
또한 이벤트 서비스는 peer1 유레카 서버에만 서비스 등록을 하고 있지만 peer2 유레카 서버에도 등록된 것을 확인할 수 있다.

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/](https://docs.spring.io/spring-cloud-netflix/docs/2.2.4.RELEASE/reference/html/)
* [https://coe.gitbook.io/guide/service-discovery/eureka_2](https://coe.gitbook.io/guide/service-discovery/eureka_2)
* [eureka client service-url-defaultzone](https://github.com/spring-cloud/spring-cloud-netflix/issues/2541)
* [스프링 클라우드 - 마이크로서비스 간 통신이란](https://happyer16.tistory.com/entry/%EC%8A%A4%ED%94%84%EB%A7%81-%ED%81%B4%EB%9D%BC%EC%9A%B0%EB%93%9C-%EB%A7%88%EC%9D%B4%ED%81%AC%EB%A1%9C%EC%84%9C%EB%B9%84%EC%8A%A4%EA%B0%84-%ED%86%B5%EC%8B%A0%EC%9D%B4%EB%9E%80-Ribbon)
* [유레카 고가용성(클러스터링 모드)](https://supawer0728.github.io/2018/03/11/Spring-Cloud-Ribbon-And-Eureka/)

## 피어링 관련
* [https://github.com/spring-cloud/spring-cloud-release/wiki/Spring-Cloud-Hoxton-Release-Notes](https://github.com/spring-cloud/spring-cloud-release/wiki/Spring-Cloud-Hoxton-Release-Notes)
* [https://stackoverflow.com/questions/30288959/eureka-peers-not-synchronized](https://stackoverflow.com/questions/30288959/eureka-peers-not-synchronized)
* [https://medium.com/swlh/spring-cloud-high-availability-for-eureka-b5b7abcefb32](https://medium.com/swlh/spring-cloud-high-availability-for-eureka-b5b7abcefb32)
* [유레카 설정값](https://develop-yyg.tistory.com/5)
* [https://github.com/spring-cloud/spring-cloud-netflix/issues/838](https://github.com/spring-cloud/spring-cloud-netflix/issues/838)