---
layout: post
title:  "Spring Cloud - Spring Cloud Eureka (상세 설정편)"
date:   2020-12-05 10:00
categories: dev
tags: msa spring-cloud-eureka
---
이 포스트는 유레카 상세 설정값에 대해 기술한다.

> - 유레카 설정 구분
> - 자기 보호 모드
> - 레지스트리 등록 여부/캐싱 여부
> - 레지스트리 갱신 - 서비스 등록 관련
> - 레지스트리 갱신 - 서비스 해제 관련
> - IP 주소 우선하기
> - 유레카 피어링 설정

---

## 1. 유레카 설정 구분

> **유레카 설정 구분**
>
> ***eureka.server.*** : 유레카 서버 관련 설정<br />
> ***eureka.client.*** : 클라이언트가 레지스트리에서 다른 서비스의 정보를 얻을 수 있는 설정<br />
> ***eureka.instance.*** : 포트나 이름 등 현재 유레카 클라이언트의 행동을 재정의하는 설정   

---

## 2. 자기 보호 모드

### 2.1. 서버 측 설정

- **eureka.server.enable-self-preservation**
    - 일시적인 네트워크 장애로 인한 서비스 해제 막기 위한 자기 보호 모드 (디폴트 true, 운영에선 반드시 true 로 설정 필요)
    - 원래는 해당 시간안에 하트비트가 일정 횟수 이상 들어오지 않아야 서비스 해제하는데 false 설정 시 하트비트가 들어오지 않으면 바로 서비스 제거

```yaml
eureka:
  server:
    enable-self-preservation: false
```
---

## 3. 레지스트리 등록 여부/캐싱 여부 

### 3.1. 서버/클라이언트 측 모두 설정

- **eureka.client.register-with-eureka**
    - 레지스트리에 자신을 등록할지에 대한 여부 (디폴트 true)
    - 클러스터링 모드의 유레카 서버 구성은 서로 peering 구성이 가능.
      (유레카 서버 설정에 정의된 peering 노드를 찾아서 레지스트리 정보의 sync 를 맞춤)
    - 독립 실행형 모드(standalone)에서는 peering 실패가 발생하므로 유레카 클라이언트 측 동작을 끔

- **eureka.client.fetch-registry**
    - 레지스트리에 있는 정보를 가져올지에 대한 여부  (디폴트 true)
    - true 로 설정 시 검색할 때마다 유레카 서버를 호출하는 대신 레지스트리가 로컬로 캐싱됨
    - 30초마다 유레카 클라이언트가 유레카 레지스트리 변경 사항 여부 재확인함

```yaml
eureka:
  client:
    register-with-eureka: true
    fetch-registry: true
```

---

### 3.2. 설정 확인

유레카 서버/클라이언트 모두 `eureka.client.register-with-eureka` 와 `eureka.client.fetch-registry` 를 false 로 설정 후 
[http://peer1:8762/eureka/apps](http://peer1:8762/eureka/apps) 호출 시 아무런 클라이언트도 등록되지 않은 것을 확인할 수 있다.

![http://peer1:8762/eureka/apps 으로 등록된 클라이언트 확인](/assets/img/dev/20201205/registry.png)

이제 유레카 클라이언트 측의 `eureka.client.register-with-eureka` 와 `eureka.client.fetch-registry` 를 true 로 설정 후
[http://peer1:8762/eureka/apps](http://peer1:8762/eureka/apps) 호출 시 해당 클라이언트가 등록된 것을 확인할 수 있다.

![http://peer1:8762/eureka/apps 으로 등록된 클라이언트 확인](/assets/img/dev/20201205/registry2.png)

유레카 서버 로그
```text
c.n.e.registry.AbstractInstanceRegistry  : Fetching applications registry with remote regions: false, Regions argument []
c.n.e.registry.AbstractInstanceRegistry  : Processing override status using rule: [com.netflix.eureka.registry.rule.DownOrStartingRule, com.netflix.eureka.registry.rule.OverrideExistsRule, com.netflix.eureka.registry.rule.LeaseExistsRule, com.netflix.eureka.registry.rule.AlwaysMatchInstanceStatusRule]
c.n.e.registry.rule.LeaseExistsRule      : There is already an existing lease with status UP  for instance xx.xx.xx.xx.:zuulserver:5555
c.n.eureka.resources.InstanceResource    : Found (Renew): ZUULSERVER - xx.xx.xx.xx.:zuulserver:5555; reply status=200
c.n.d.shared.MonitoredConnectionManager  : Get connection: {}->http://peer1:8762, timeout = 200
c.n.d.shared.NamedConnectionPool         : [{}->http://peer1:8762] total kept alive: 1, total issued: 0, total allocated: 1 out of 1000
c.n.d.shared.NamedConnectionPool         : Getting free connection [{}->http://peer1:8762][null]
c.n.d.util.DeserializerStringCache       : clearing global-level cache with size 0
c.n.d.util.DeserializerStringCache       : clearing app-level serialization cache with size 0
c.n.e.registry.AbstractInstanceRegistry  : Fetching applications registry with remote regions: false, Regions argument []
c.n.e.registry.AbstractInstanceRegistry  : Processing override status using rule: [com.netflix.eureka.registry.rule.DownOrStartingRule, com.netflix.eureka.registry.rule.OverrideExistsRule, com.netflix.eureka.registry.rule.LeaseExistsRule, com.netflix.eureka.registry.rule.AlwaysMatchInstanceStatusRule]
c.n.e.r.r.AlwaysMatchInstanceStatusRule  : Returning the default instance status UP for instance xx.xx.xx.xx.:zuulserver:5555
c.n.eureka.resources.InstanceResource    : Found (Renew): ZUULSERVER - xx.xx.xx.xx.:zuulserver:5555; reply status=200
c.n.d.shared.MonitoredConnectionManager  : Released connection is reusable.
c.n.d.shared.NamedConnectionPool         : Releasing connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Pooling connection [{}->http://peer1:8762][null]; keep alive for 60000 MILLISECONDS
c.n.d.shared.NamedConnectionPool         : Notifying no-one, there are no waiting threads
c.n.d.util.DeserializerStringCache       : clearing global-level cache with size 0
c.n.d.util.DeserializerStringCache       : clearing app-level serialization cache with size 0
c.n.eureka.registry.ResponseCacheImpl    : Updating the client cache from response cache
c.n.eureka.registry.ResponseCacheImpl    : Updating the client cache from response cache for key : Application ALL_APPS V2 JSON

```

유레카 클라이언트 로그
```text
c.n.d.shared.MonitoredConnectionManager  : Closing connections idle longer than 30 SECONDS
c.n.d.shared.NamedConnectionPool         : Closing connections idle longer than 30 SECONDS
com.netflix.discovery.DiscoveryClient    : Disable delta property : false
com.netflix.discovery.DiscoveryClient    : Single vip registry refresh property : null
com.netflix.discovery.DiscoveryClient    : Force full registry fetch : false
com.netflix.discovery.DiscoveryClient    : Application is null : false
com.netflix.discovery.DiscoveryClient    : Registered Applications size is zero : true
com.netflix.discovery.DiscoveryClient    : Application version is -1: false
com.netflix.discovery.DiscoveryClient    : Getting all instance registry info from the eureka server
c.n.d.shared.MonitoredConnectionManager  : Get connection: {}->http://peer1:8762, timeout = 5000
c.n.d.shared.MonitoredConnectionManager  : Get connection: {}->http://peer1:8762, timeout = 5000
c.n.d.shared.NamedConnectionPool         : [{}->http://peer1:8762] total kept alive: 1, total issued: 0, total allocated: 1 out of 200
c.n.d.shared.NamedConnectionPool         : Getting free connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : [{}->http://peer1:8762] total kept alive: 0, total issued: 1, total allocated: 1 out of 200
c.n.d.shared.NamedConnectionPool         : No free connections [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Available capacity: 49 out of 50 [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Creating new connection [{}->http://peer1:8762]
c.n.d.shared.MonitoredConnectionManager  : Released connection is reusable.
c.n.d.shared.NamedConnectionPool         : Releasing connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Pooling connection [{}->http://peer1:8762][null]; keep alive for 60000 MILLISECONDS
c.n.d.shared.NamedConnectionPool         : Notifying no-one, there are no waiting threads
n.d.s.t.j.AbstractJerseyEurekaHttpClient : Jersey HTTP PUT http://peer1:8762/eureka//apps/ZUULSERVER/xx.xx.xx.xx.:zuulserver:5555; statusCode=200
com.netflix.discovery.DiscoveryClient    : DiscoveryClient_ZUULSERVER/xx.xx.xx.xx.:zuulserver:5555 - Heartbeat status: 200
c.n.d.shared.MonitoredConnectionManager  : Released connection is reusable.
c.n.d.shared.NamedConnectionPool         : Releasing connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Pooling connection [{}->http://peer1:8762][null]; keep alive for 60000 MILLISECONDS
c.n.d.shared.NamedConnectionPool         : Notifying no-one, there are no waiting threads
c.n.d.util.DeserializerStringCache       : clearing global-level cache with size 1
c.n.d.util.DeserializerStringCache       : clearing app-level serialization cache with size 8
n.d.s.t.j.AbstractJerseyEurekaHttpClient : Jersey HTTP GET http://peer1:8762/eureka//apps/?; statusCode=200
com.netflix.discovery.DiscoveryClient    : The response status is 200
com.netflix.discovery.DiscoveryClient    : Got full registry with apps hashcode UP_1_
com.netflix.discovery.DiscoveryClient    : The total number of all instances in the client now is 1
com.netflix.discovery.DiscoveryClient    : Completed cache refresh task for discovery. All Apps hash code is Local region apps hashcode: UP_1_, is fetching remote regions? false 

```

---

## 4. 레지스트리 갱신 - 서비스 등록 관련

> **유레카 클라이언트 등록 시 최장 딜레이 시간**
>
> eureka.server.**response-cache-update-interval-ms** (유레카 서버의 캐싱 업데이트 주기, 30초) <br />
>       + eureka.client.**registry-fetch-interval-seconds** (서비스 목록을 캐싱할 주기, 30초) <br />
> = 60초

### 4.1. 클라이언트 측 설정

- **eureka.client.registry-fetch-interval-seconds**
    - 서비스 목록을 설정한 시간마다 캐싱 (디폴트 30초)
    
- **eureka.client.disable-delta**
    - 캐싱 시 변경된 부분만 업데이트할 지 여부 (디폴트 false)
    - false 로 설정 서 대역폭 낭비이므로 true 로 설정할 것   
        
```yaml
eureka:
  client:
    registry-fetch-interval-seconds: 10
    disable-delta: true
```
        
클라이언트 측 로그 (10초마다 로그 업데이트)
```text
com.netflix.discovery.DiscoveryClient    : Disable delta property : true
com.netflix.discovery.DiscoveryClient    : Single vip registry refresh property : null
com.netflix.discovery.DiscoveryClient    : Force full registry fetch : false
com.netflix.discovery.DiscoveryClient    : Application is null : false
com.netflix.discovery.DiscoveryClient    : Registered Applications size is zero : false
com.netflix.discovery.DiscoveryClient    : Application version is -1: false
com.netflix.discovery.DiscoveryClient    : Getting all instance registry info from the eureka server
c.n.d.shared.MonitoredConnectionManager  : Get connection: {}->http://peer1:8762, timeout = 5000
c.n.d.shared.NamedConnectionPool         : [{}->http://peer1:8762] total kept alive: 1, total issued: 0, total allocated: 1 out of 200
c.n.d.shared.NamedConnectionPool         : Getting free connection [{}->http://peer1:8762][null]
c.n.d.shared.MonitoredConnectionManager  : Released connection is reusable.
c.n.d.shared.NamedConnectionPool         : Releasing connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Pooling connection [{}->http://peer1:8762][null]; keep alive for 60000 MILLISECONDS
c.n.d.shared.NamedConnectionPool         : Notifying no-one, there are no waiting threads
c.n.d.util.DeserializerStringCache       : clearing global-level cache with size 1
c.n.d.util.DeserializerStringCache       : clearing app-level serialization cache with size 8
n.d.s.t.j.AbstractJerseyEurekaHttpClient : Jersey HTTP GET http://peer1:8762/eureka//apps/?; statusCode=200
com.netflix.discovery.DiscoveryClient    : The response status is 200
com.netflix.discovery.DiscoveryClient    : Got full registry with apps hashcode UP_1_
com.netflix.discovery.DiscoveryClient    : The total number of all instances in the client now is 1
com.netflix.discovery.DiscoveryClient    : Completed cache refresh task for discovery. All Apps hash code is Local region apps hashcode: UP_1_, is fetching remote regions? false 
```
        
### 4.2. 서버 측 설정

- **eureka.server.response-cache-update-interval-ms**
    - 유레카 서버의 캐싱 업데이트 주기 (디폴트 30,000ms)
    - 유레카 서버 실행 후 /eureka/apps API 실행 시 아무것도 나오지 않음
      클라이언트 인스턴스 실행 수 /eureka/apps 실행 시 여전히 아무것도 나오지 않음
      30초가 지나고 /eureka/apps 실행 시 클라이언트 인스턴스 조회됨.
    - 유레카 서버의 대시보드(유레카서버:8761/) 에 등록된 인스턴스가 표시될때에는 캐시 사용하지 않음
    - `eureka.client.registry-fetch-interval-seconds` 와 비교하여 볼 것

```yaml
eureka:
  server:
    response-cache-update-interval-ms: 5000
```

유레카 서버 로그 (5초마다 로그 업데이트)
```text
c.n.eureka.registry.ResponseCacheImpl    : Updating the client cache from response cache
```
    
---

## 5. 레지스트리 갱신 - 서비스 해제 관련

위의 자기 보호 모드(`eureka.server.enable-self-preservation`)를 false 로 설정하여도 레지스트리에서 서버가 등록 해지되는 시간은 오래 걸린다.<br />
그 이유는 아래와 같다.

`lease-renewal-interval-in-seconds` 에 의해 클라이언트는 서버로 30초 (디폴트 값) 마다 하트비트 전송하고, <br /> 
`lease-expiration-duration-in-seconds` 에 의해 서버는 하트비트를 받지 못하면 90초 (디폴트 값) 동안 하트비트가 수신되지 않으면 서비스
등록을 해지하기 때문이다.

>실제로 자기 보호 모드 false 인 상태에서 클라이언트 종료 시 109 초 이후에 서비스 등록 해지가 되는 부분을 확인했다.

***<u>이 두 값은 서버 내부적으로 클라이언트를 관리하는 로직에 영향을 미칠 수 있으므로 설정을 변경하지 않는 것을 권장한다.</u>***

> **유레카 클라이언트 등록 해제 시 최장 딜레이 시간**
>
> eureka.server.**response-cache-update-interval-ms** (유레카 서버의 캐싱 업데이트 주기, 30초) <br />
>       + eureka.instance.**lease-expiration-duration-in-seconds** (유레카 서버가 마지막 하트비트로부터 서비스 등록 해제 전 대기 시간, 90초) <br />
> = 120초

### 5.1. 클라이언트 측 설정

- **eureka.instance.lease-renewal-interval-in-seconds**
    - 유레카 서버로 설정된 시간(second)마다 하트비트 전송 (디폴트 30초)

- **eureka.instance.lease-expiration-duration-in-seconds**
    - 디스커버리는 서비스 등록 해제 하기 전에 마지막 하트비트에서부터 설정된 시간(second) 동안 하트비트가 수신되지 않으면 
      서비스 등록 해제 (디폴트 90초)
    - 단, 유레카 인스턴스가 정상적으로 종료된 경우는 레지스트리에서 바로 제거
    - 이 값은 `lease-renewal-interval-in-seconds` 보다 커야 함

```yaml
eureka:
  instance:
    lease-renewal-interval-in-seconds: 3
    lease-expiration-duration-in-seconds: 10
```

서버 측 로그 (3초마다 로그 업데이트)
```text
c.n.d.shared.MonitoredConnectionManager  : Closing connections idle longer than 30 SECONDS
c.n.d.shared.NamedConnectionPool         : Closing connections idle longer than 30 SECONDS
c.n.e.registry.AbstractInstanceRegistry  : Fetching applications registry with remote regions: false, Regions argument []
c.n.e.registry.AbstractInstanceRegistry  : Processing override status using rule: [com.netflix.eureka.registry.rule.DownOrStartingRule, com.netflix.eureka.registry.rule.OverrideExistsRule, com.netflix.eureka.registry.rule.LeaseExistsRule, com.netflix.eureka.registry.rule.AlwaysMatchInstanceStatusRule]
c.n.e.registry.rule.LeaseExistsRule      : There is already an existing lease with status UP  for instance xx.xx.xx.xx:zuulserver:5555
c.n.eureka.resources.InstanceResource    : Found (Renew): ZUULSERVER - xx.xx.xx.xx:zuulserver:5555; reply status=200
c.n.d.shared.MonitoredConnectionManager  : Get connection: {}->http://peer1:8762, timeout = 200
c.n.d.shared.NamedConnectionPool         : [{}->http://peer1:8762] total kept alive: 1, total issued: 0, total allocated: 1 out of 1000
c.n.d.shared.NamedConnectionPool         : Getting free connection [{}->http://peer1:8762][null]
c.n.d.util.DeserializerStringCache       : clearing global-level cache with size 0
c.n.d.util.DeserializerStringCache       : clearing app-level serialization cache with size 0
c.n.e.registry.AbstractInstanceRegistry  : Fetching applications registry with remote regions: false, Regions argument []
c.n.e.registry.AbstractInstanceRegistry  : Processing override status using rule: [com.netflix.eureka.registry.rule.DownOrStartingRule, com.netflix.eureka.registry.rule.OverrideExistsRule, com.netflix.eureka.registry.rule.LeaseExistsRule, com.netflix.eureka.registry.rule.AlwaysMatchInstanceStatusRule]
c.n.e.r.r.AlwaysMatchInstanceStatusRule  : Returning the default instance status UP for instance xx.xx.xx.xx:zuulserver:5555
c.n.eureka.resources.InstanceResource    : Found (Renew): ZUULSERVER - xx.xx.xx.xx:zuulserver:5555; reply status=200
c.n.d.shared.MonitoredConnectionManager  : Released connection is reusable.
c.n.d.shared.NamedConnectionPool         : Releasing connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Pooling connection [{}->http://peer1:8762][null]; keep alive for 60000 MILLISECONDS
c.n.d.shared.NamedConnectionPool         : Notifying no-one, there are no waiting threads
c.n.d.util.DeserializerStringCache       : clearing global-level cache with size 0
c.n.d.util.DeserializerStringCache       : clearing app-level serialization cache with size 0
```

클라이언트 측 로그 (3초마다 로그 업데이트)
```text
c.n.d.shared.MonitoredConnectionManager  : Get connection: {}->http://peer1:8762, timeout = 5000
c.n.d.shared.NamedConnectionPool         : [{}->http://peer1:8762] total kept alive: 1, total issued: 0, total allocated: 1 out of 200
c.n.d.shared.NamedConnectionPool         : Getting free connection [{}->http://peer1:8762][null]
c.n.d.shared.MonitoredConnectionManager  : Released connection is reusable.
c.n.d.shared.NamedConnectionPool         : Releasing connection [{}->http://peer1:8762][null]
c.n.d.shared.NamedConnectionPool         : Pooling connection [{}->http://peer1:8762][null]; keep alive for 60000 MILLISECONDS
c.n.d.shared.NamedConnectionPool         : Notifying no-one, there are no waiting threads
n.d.s.t.j.AbstractJerseyEurekaHttpClient : Jersey HTTP PUT http://peer1:8762/eureka//apps/ZUULSERVER/xx.xx.xx.xx:zuulserver:5555; statusCode=200
com.netflix.discovery.DiscoveryClient    : DiscoveryClient_ZUULSERVER/xx.xx.xx.xx:zuulserver:5555 - Heartbeat status: 200
```

하지만 자기 보호 모드(`eureka.server.enable-self-preservation`) 와 위 2개 설정을 한다 해도 서비스 등록 해지가 바로 되는 것은 아닌데,
그 이유는 아래 서버 측 설정을 보면 알 수 있다.
 
### 5.2. 서버 측 설정

서버 측에서도 변경을 해주어야 하는데 Evict 백그라운드 태스크 때문이다.<br />
클라이언트로부터 하트비트가 계속 수신되는지 점검을 하는 태스크인데 기본값인 60초 마다 실행되기 때문에
클라이언트 측 위의 두 값을 작은 값으로 설정해도 서비스 인스턴스를 제거하는데 최대 60초가 소요된다.

- **eureka.server.eviction-interval-timer-in-ms**
    - 클라이언트로부터 하트비트가 계속 수신 되는지 점검 (디폴트 60초)
      
```yaml
eureka:
  server:
    eviction-interval-timer-in-ms: 10000
```

> `lease-expiration-duration-in-seconds` (디스커버리는 서비스 등록 해제 하기 전에 마지막 하트비트에서부터 설정된 시간(second) 동안 
> 하트비트가 수신되지 않으면 서비스 등록 해제 (디폴트 90초)) 를 10초로 설정,<br />
> `eureka.instance.eviction-interval-timer-in-ms` (클라이언트로부터 하트비트가 계속 수신 되는지 점검 (디폴트 60초)) 를 10초로 설정 후
> 클라이언트 종료 시 약 20초 후에 서비스 등록 해제가 되는 부분을 확인함

---

## 6. IP 주소 우선하기

인스턴스는 기본적으로 호스트명으로 등록되는데 DNS 가 없는 경우 hosts 파일에 IP를 등록하지 않으면 인스턴스를 찾지 못하게 된다.<br />
`eureka.instance.prefer-ip-address` 속성을 통해 서비스의 IP 주소를 사용할 수 있지만 만일 장비에서 하나 이상의 네트워크 인터페이스가
있는 경우 문제가 발생할 수 있으므로 아래와 같이 **무시할 패턴 또는 선호하는 네트워크 주소를 설정하여 해결**할 수 있다.

### 6.1. 클라이언트 측 설정

- **eureka.instance.prefer-ip-address**
    - 서비스의 호스트 이름이 아닌 IP 주소를 유레카 서버에 등록하도록 지정 (디폴트 false)
    - 기본적으로 유레카는 호스트 이름으로 접속하는 서비스를 등록하는데 DNS 가 지원된 호스트 이름을 할당하는 서버 기반 환경에서는 잘 동작하지만,
      컨테이너 기반의 배포에서 컨테이너는 DNS 엔트리가 없는 임의의 생성된 호스트 이름을 부여받아 시작하므로
      컨테이너 기반 배포에서는 해당 설정값을 false 로 하는 경우 호스트 이름 위치를 정상적으로 얻지 못함

- **spring.cloud.inetutils.ignored-interfaces**
    - 해당 인터페이스 무시

- **spring.cloud.inetutils.preferred-networks**
    - 선호하는 IP 주소 설정
    
```yaml
spring:
  cloud:
    inetutils:
      ignored-interfaces: eth1*
      preferred-networks: 192.168

eureka:
  instance:
    prefer-ip-address: true
```

---

## 7. 유레카 피어링 설정

해당 설정은 유레카 서버를 피어링하여 사용하는 경우에만 설정한다.

### 7.1. 서버 측 설정
- **eureka.server.wait-time-in-ms-when-sync-empty**
    - 유레카 서버가 시작되고 유레카 피어링 노드로부터 Instance 들을 가져올 수 없을 때 기다릴 시간 (디폴트 3000ms, 운영 환경에선 삭제 필요)
    - registry 를 갱신할 수 없을 때 재시도를 기다리는 시간
    - 테스트 시 짧은 시간으로 등록해놓으면 유레카 서비스의 시작 시간과 등록된 서비스를 보여주는 시간 단축 가능
    - 유레카는 등록된 서비스에서 10초 간격으로 연속 3회의 상태 정보(heartbeat)를 받아야 하므로 등록된 개별 서비스를 보여주는데 30초 소요
    
-  **eureka.server.registry-sync-retries**
    - 유레카 피어 노드로부터 registry 를 갱신할 수 없을 때 재시도 횟수 (디폴트 5)
        
```yaml
eureka:
  server:
    wait-time-in-ms-when-sync-empty: 3000
    registry-sync-retries: 5
```
        
---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [디스커버리](https://authentication.tistory.com/24)
* [유레카 설정값](https://develop-yyg.tistory.com/5)
* [유레카 설정값](https://jinhyy.tistory.com/52)