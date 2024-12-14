---
layout: post
title:  "Kafka - 코드로 관리(1): `AdminClient` 생성/수정/닫기, 토픽 관리, 설정 관리"
date: 2024-07-06
categories: dev
tags: kafka adminClient kafkaAdminClient clientdnslookup describeTopics() createTopics() describeTopicsResult topicDescription createTopicsResult deleteTopics() configResource describeConfigResult describeConfigs() alterConfigOp
---

카프카를 관리할 때 여러 CLI, GUI 툴들이 있지만, 클라이언트 애플리케이션에서 직접 관리 명령을 내려야 할 때도 있다.

> 카프카를 관리하는 CLI, GUI 툴은 추후 다룰 예정입니다. (p. 125)

사용자 입력에 기반하여 새로운 토픽을 생성하는 경우는 흔하다.

사물 인터넷 (IoT, Internet of Things) 애플리케이션은 사용자 장치로부터 이벤트를 받아서 장치 유형에 따라 토픽을 쓰는 방식이다.  
만일 제조사가 새로운 유형의 장치를 출시하면 별도 절차를 거쳐 새로운 토픽을 생성하던가 애플리케이션이 동적으로 (미확인된 장치 유형에 대한 이벤트를 받을 경우) 새로운 토픽을 생성하던가 해야 한다.

**`AdminClient` 는 프로그램적인 관리 기능 API 를 제공**한다.  
**`AdminClient` 는 토픽 목록 조회, 생성, 삭제, 클러스터 상세 정보 확인, ACL 관리, 설정 변경 등의 기능을 지원**한다.

예를 들어 애플리케이션이 특정 토픽에 이벤트를 써야할 경우 이벤트를 쓰기 전에 토픽이 존재해야 함을 알아야 하는데 `AdminClient` 가 나오기 전까지는 이를 알 수 있는 방법이 없었기 때문에 
아래와 같은 방식으로 확인하는 식이었다.
- producer.send() 메서드에서 _UNKNOWN_TOPIC_OR_PARTITION_ 예외 발생 시 토픽 생성
- 카프카 클러스터에 자동 토픽 생성 기능 켬

지금의 카프카는 `AdminClient` 를 제공하므로 토픽의 존재 여부를 확인하여 없을 경우 즉시 생성이 가능하다.

이 포스트에서는 `AdminClient` 에 대해 살펴보고, 토픽 관리, 컨슈머 그룹, 개체 (entity) 설정과 같이 많이 쓰이는 기능에 초점이 맞추어서 이를 애플리케이션에서 
어떻게 사용할 수 있는지 알아본다.

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `AdminClient`](#1-adminclient)
  * [1.1. 비동기적이고 최종적 일관성을 갖는 API](#11-비동기적이고-최종적-일관성을-갖는-api)
  * [1.2. 옵션](#12-옵션)
  * [1.3. 수평 구조: `KafkaAdminClient`](#13-수평-구조-kafkaadminclient)
  * [1.4. 추가 참고 사항](#14-추가-참고-사항)
* [2. `AdminClient` 생성, 설정, 닫기: `create()`, `close()`](#2-adminclient-생성-설정-닫기-create-close)
  * [2.1. `client.dns.lookup`](#21-clientdnslookup)
    * [2.1.1. DNS alias 를 사용하는 경우: `resolve_canonical_bootstrap_servers_only`](#211-dns-alias-를-사용하는-경우-resolve_canonical_bootstrap_servers_only)
    * [2.1.2. 다수의 IP 주소로 연결되는 DNS 이름을 사용하는 경우: `use_all_dns_ips`](#212-다수의-ip-주소로-연결되는-dns-이름을-사용하는-경우-use_all_dns_ips)
  * [2.2. `request.timeout.ms`](#22-requesttimeoutms)
* [3. 토픽 관리](#3-토픽-관리)
  * [3.1. 토픽 목록 조회, 상세 내역 조회, 토픽 생성: `describeTopics()`, `createTopics()`, `DescribeTopicsResult`, `TopicDescription`, `CreateTopicsResult`](#31-토픽-목록-조회-상세-내역-조회-토픽-생성-describetopics-createtopics-describetopicsresult-topicdescription-createtopicsresult)
  * [3.2. 토픽 삭제: `deleteTopics()`](#32-토픽-삭제-deletetopics)
  * [3.3. 비동기적으로 토픽의 상세 정보 조회: `KafkaFuture`, `whenComplete()`](#33-비동기적으로-토픽의-상세-정보-조회-kafkafuture-whencomplete)
* [4. 설정 관리: `ConfigResource`, `DescribeConfigsResult`, `describeConfigs()`, `AlterConfigOp`](#4-설정-관리-configresource-describeconfigsresult-describeconfigs-alterconfigop)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

pom.xml (parent)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <packaging>pom</packaging>

  <modules>
    <module>chap03</module>
  </modules>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.2</version>
    <relativePath/> <!-- lookup parent from repository -->
  </parent>

  <groupId>com.assu.study</groupId>
  <artifactId>kafka_me</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>kafka_me</name>
  <description>kafka_me</description>

  <url/>
  <licenses>
    <license/>
  </licenses>
  <developers>
    <developer/>
  </developers>
  <scm>
    <connection/>
    <developerConnection/>
    <tag/>
    <url/>
  </scm>
  <properties>
    <java.version>17</java.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter</artifactId>
    </dependency>

    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-devtools</artifactId>
      <scope>runtime</scope>
      <optional>true</optional>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-configuration-processor</artifactId>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

pom.xml (chap05)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.assu.study</groupId>
        <artifactId>kafka_me</artifactId>
        <version>0.0.1-SNAPSHOT</version>
    </parent>

    <artifactId>chap05</artifactId>

    <url/>
    <licenses>
        <license/>
    </licenses>
    <developers>
        <developer/>
    </developers>
    <scm>
        <connection/>
        <developerConnection/>
        <tag/>
        <url/>
    </scm>
    <properties>
        <kafka.version>3.8.0</kafka.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.apache.kafka</groupId>
            <artifactId>kafka-clients</artifactId>
            <version>${kafka.version}</version>
        </dependency>
        <dependency>
            <groupId>io.vertx</groupId>
            <artifactId>vertx-web</artifactId>
            <version>4.5.9</version>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-lang3</artifactId>
            <version>3.16.0</version>
        </dependency>

    </dependencies>
</project>
```

---

# 1. `AdminClient`

`AdminClient` 를 사용하기 전에 `AdminClient` 가 어떻게 설계되었고, 언제 사용되어야 하는지에 대해 알아본다.

---

## 1.1. 비동기적이고 최종적 일관성을 갖는 API

**`AdminClient` 는 비동기적으로 작동**한다.

**각 메서드는 요청을 클러스터 컨트롤러로 전송한 뒤 바로 1개 이상의 `Future` 객체를 리턴**한다.

`Future` 객체는 비동기 작업의 결과를 가리키며, 비동기 작업의 결과를 확인하거나 취소하거나 완료될 때까지 대기하거나, 아니면 작업이 완료되었을 때 실행할 함수를 
지정하는 메서드를 갖는다.

> `Future` 에 대한 좀 더 상세한 내용은  
> [Java8 - CompletableFuture (1): Future, 병렬화 방법](https://assu10.github.io/dev/2023/07/22/java8-completableFuture-1/),  
> [Java8 - CompletableFuture (2): 비동기 연산의 파이프라인화](https://assu10.github.io/dev/2023/07/23/java8-completableFuture-2/)  
> 를 참고하세요.

`AdminClient` 는 `Future` 객체를 `Result` 객체 안에 감싸는데 **`Result` 객체는 작업이 끝날 때까지 대기하거나, 작업 결과에 대해 일반적으로 뒤이어 
쓰이는 작업을 수행하는 헬퍼 메서드**를 갖고 있다.  
예) `AdminClient.createTopics()` 메서드는 `CreateTopicsResult` 객체를 리턴하는데 이 `CreateTopicsResult` 객체는 모든 토픽이 생성될 때까지 기다리거나, 
각각의 토픽 상태를 하나씩 확인하거나, 특정한 토픽이 생성된 뒤 해당 토픽의 설정을 가져올 수 있도록 해준다.

**카프카 컨트롤러로부터 브로커로의 메타데이터 전파가 비동기적으로 이루어지므로 `AdminClient` API 가 리턴하는 `Future` 객체들은 컨트롤러의 상태가 완전히 업데이트된 
시점에서 완료된 것으로 간주**된다.  
이 시점에서 모든 브로커가 전부 다 새로운 상태에 대해 알고 있지는 못할 수 있기 때문에 `listTopics` 요청은 최신 상태를 전달받지 않은 (= 이제 막 만들어진 토픽에 대해 모르는) 
브로커에 의해 처리될 수 있는 것이다.

> 카프카 컨트롤러에 대한 설명은 [2.5. 브로커, 클러스터, 컨트롤러, 파티션 리더, 팔로워](https://assu10.github.io/dev/2024/06/10/kafka-basic/#25-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%ED%81%B4%EB%9F%AC%EC%8A%A4%ED%84%B0-%EC%BB%A8%ED%8A%B8%EB%A1%A4%EB%9F%AC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%8D%94-%ED%8C%94%EB%A1%9C%EC%9B%8C) 를 참고하세요.

이러한 속성을 **최종적 일관성 (eventual consistency)** 라고 한다.

**최종적으로 모든 브로커는 모든 토픽에 대해 알게 될 것이지만, 그 시점이 정확히 언제가 될지에 대해서는 아무런 보장도 할 수 없다.**

---

## 1.2. 옵션

**`AdminClient` 의 각 메서드는 메서드별로 특정한 `Options` 객체를 인수**로 받는다.

예) `listTopics` 메서드는 `ListTopicsOptions` 객체를 인수로 받고, `describeCluster` 메서드는 `DescribeClusterOptions` 객체를 인수로 받음

이 **`Options` 객체들은 브로커가 요청을 어떻게 처리할지에 대해 서로 다른 설정**을 담는다.

**모든 `AdminClient` 메서드가 갖는 매개 변수는 `timeoutMs`** 이다.  
**`timeoutMs` 는 클라이언트가 _TimeoutException_ 을 발생시키기 전에 클러스터로부터 응답을 기다리는 시간을 조정**한다.

---

## 1.3. 수평 구조: `KafkaAdminClient`

**모든 어드민 작업은 `KafkaAdminClient` 에 구현되어 있는 아파치 카프카 프로토콜을 사용**하여 이루어진다.  
여기엔 객체 간의 의존 관계나 네임 스페이스 같은 게 없다.

인터페이스로 되어 있기 때문에 어드민 작업을 프로그램적으로 수행하는 방법을 알아야 할 때 JavaDoc 문서 검색하여 사용만 하면 된다.

---

## 1.4. 추가 참고 사항

클러스터의 상태를 변경하는 모든 작업 (create,delete, alter) 은 컨트롤러에 의해 수행된다.

클러스터 상태를 읽기만 하는 작업 (list, describe) 은 아무 브로커에서나 수행될 수 있으며, 클라이언트 입장에서 보이는 가장 부하가 적은 브로커로 전달된다.

대부분의 어드민 작업은 `AdminClient` 를 통해서 수행되거나 주키퍼에 저장되어 있는 메타 데이터를 직접 수정하는 방식으로 이루어지는데 주키퍼를 직접 수정하는 것은 
절대 사용하지 않는 것이 좋다.

카프카 3.3 버전부터 KRaft 를 제공할 예정이며, 아파치 카프카 커뮤니티는 조만간 주키퍼 의존성을 완전히 제거할 예정이다.  

> 카프카 3.5 부터 Zookeeper mode 가 deprecate, 3.7 버전이 Zookeeper mode 가 포함된 마지막 버전, 4.0 부터는 KRaft mode 만 지원할 계획이라고 함  
> [Apache Kafka 3.8.0 Release Announcement](https://kafka.apache.org/blog?fbclid=IwAR0K9FLZFzvBJHJlfclqZ8maU1E57gofMapl0LDJPWpTYTssVJaE8obE0Lk#apache_kafka_380_release_announcement)

따라서 주키퍼를 직접 수정하는 방식으로 어드민 작업을 수행한다면 모든 애플리케이션이 수정되어야 한다.

---

# 2. `AdminClient` 생성, 설정, 닫기: `create()`, `close()`

`AdminClient` 를 사용하기 위해 가장 먼저 할 일은 `AdminClient` 객체를 생성하는 것이다.

아래는 `AdminClient` 객체를 생성하는 예시이다.
```java
package com.assu.study.chap05;

import java.time.Duration;
import java.util.Properties;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;

public class AdminClientSample {
  public static void main(String[] args) {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

    AdminClient adminClient = AdminClient.create(props);

    // TODO: AdminClient 를 사용하여 필요한 작업 수행

    adminClient.close(Duration.ofSeconds(30));
  }
}
```

- **`create()`**
  - 설정값을 담고 있는 Properties 객체를 인수로 받는데 반드시 있어야 하는 설정은 클러스터에 대한 URI (= 연결한 브로커 목록을 쉼표로 구분한 목록) 하나 뿐임
  - 프로덕션 환경에서는 브로커 중 하나에 장애가 발생할 경우를 대비하여 최소한 3개 이상의 브로커를 지정하는 것이 보통임

> 좀 더 안전하고 인증된 연결을 설정하는 방법은 추후 다룰 예정입니다. (p. 128)

- **`close()`**
  - `close()` 를 호출할 때는 아직 진행 중인 작업이 있을 수 있으므로 타임아웃 매개변수를 받음
  - `close()` 를 호출하면 다른 메서드를 호출해서 요청을 보낼 수는 없지만, 클라이언트는 타임아웃이 만료될 때까지 응답을 기다림
  - 타임아웃이 발생하면 클라이언트는 모든 진행 중인 작업을 멈추고 모든 자원을 해제함
  - 타임아웃없이 `close()` 를 호출하면 얼마가 되었건 모든 진행 중인 작업이 완료될 때까지 대기함

`AdminClient` 에서 중요한 설정은 아래 2개이다.

- `client.dns.lookup`
- `request.timeout.ms`

---

## 2.1. `client.dns.lookup`

기본적으로 카프카는 부트스트랩 서버 설정에 포함된 호스트명을 기준으로 연결을 검증, 해석, 생성한다. 
(브로커로부터 호스트 정보를 받은 뒤부터는 `advertised.listeners` 설정에 있는 호스트명을 기준으로 연결)

이 모델은 대부분의 경우 제대로 동작하지만, 2가지 유의할 점이 있다.

- DNS 별칭 (alias) 를 사용할 경우
- 2개 이상의 IP 주소로 연결되는 하나의 DNS 항목을 사용할 경우

이 둘은 비슷해보이지만 약간 다른데, (동시에 발생할 수 없는) 이 2 가지 시나리오에 대해 좀 더 자세히 알아본다.

---

### 2.1.1. DNS alias 를 사용하는 경우: `resolve_canonical_bootstrap_servers_only`

_broker1.hostname.com_, _broker2.hostname.com_ .. 등의 브로커들을 가지고 있을 때 이 모든 브로커들을 부트스트랩 서버 설정에 일일이 지정하는 것보다 
**이 모든 브로커 전체를 가리킬 하나의 DNS alias 를 만들어 관리하는 것이 더 편리**하다.

**어떤 브로커가 클라이언트와 처음으로 연결될지는 그리 중요하지 않기 때문에 부트스트래핑을 위해 _all-brokers.hostname.com_ 을 사용**할 수 있는 것이다.

이것은 매우 편리하지만, **SASL(Simple Authentication and Security Layer) 을 사용하여 인증을 하려고 할 때는 문제**가 생긴다.

**SASL 을 사용할 경우 클라이언트는 _all-brokers.hostname_ 에 대해 인증을 하려고 하는데, 서버의 보안 주체 (principal) 는 _broker2.hostname.com_ 이기 때문**이다.

만일 호스트명이 일치하지 않을 경우 악의적인 공격일 수도 있기 때문에 SASL 은 인증을 거부하고 연결도 실패한다.

이 때는 **`client.dns.lookup=resolve_canonical_bootstrap_servers_only` 설정**을 해주면 된다.  
이 설정이 되어있는 경우 클라이언트는 DNS alias 에 포함된 모든 브로커 이름을 일일이 부트스트랩 서버 목록에 넣어준 것과 동일하게 작동한다.

---

### 2.1.2. 다수의 IP 주소로 연결되는 DNS 이름을 사용하는 경우: `use_all_dns_ips`

네트워크 아키텍처에서 모든 브로커를 프록시나 로드 밸런서 뒤로 숨기는 것은 매우 흔하며, 외부로부터 연결을 허용하기 위해 로드 밸런서를 두어야 하는 쿠버네티스를 사용하는 경우는 
특히나 더 그렇다.

이 경우 로드 밸런서가 단일 장애점이 되는 것을 원치 않을 것이다.  
이러한 이유 때문에 _broker1.hostname.com_ 을 여러 개의 IP 로 연결하는 것은 매우 흔한 일이다. (이 IP 주소들은 모두 로드 밸런서로 연결되고 따라서 모든 트래픽이 동일한 
브로커로 전달됨)  
이 IP 주소들은 시간이 지남에 따라 변경될 수도 있다.

**기본적으로 카프카 클라이언트는 해석된 첫 번째 호스트명으로 연결을 시도할 뿐인데, 다시 말하면 해석된 IP 주소가 사용 불가능일 경우 브로커가 정상임에도 불구하고 
클라이언트는 연결에 실패할 수도 있다는 이야기**이다.

이런 이유로 **클라이언트가 로드 밸런싱 계층의 고가용성을 충분히 활용할 수 있도록 `client.dns.lookup=use_all_dns_ips` 로 잡아줄 것을 강력히 권장**한다.

---

## 2.2. `request.timeout.ms`

**`request.timeout.ms` 는 애플리케이션이 `AdminClient` 의 응답을 기다릴 수 있는 최대 시간**이다.  
여기엔 클라이언트가 재시도가 가능한 에러를 받고 재시도하는 시간도 포함된다.

기본값은 120s 이다.

기본값이 꽤 길지만, 컨슈머 그룹 관리 기능 같은 몇몇 `AdminClient` 작업은 응답에 꽤 시간이 걸릴 수도 있다.

각각의 `AdminClient` 메서드는 해당 메서드에만 해당하는 타임아웃 값을 포함하는 `Options` 객체를 받는다.

**만일 애플리케이션에서 `AdminClient` 작업이 주요 경로 (critical path) 상에 있을 경우, 타임아웃 값을 낮게 잡아준 뒤 제 시간에 리턴되지 않는 응답은 
조금 다른 방식으로 처리**해야 할 수도 있다.

그 일반적인 예로는 아래가 있다.
- 서비스가 시작될 때 특정한 토픽이 존재하는지 확인
- 브로커가 응답하는데 30s 이상 걸릴 경우, 확인 작업을 건너뛰거나 일단 서버 기동을 계속한 뒤 나중에 토픽의 존재 확인

---

# 3. 토픽 관리

## 3.1. 토픽 목록 조회, 상세 내역 조회, 토픽 생성: `describeTopics()`, `createTopics()`, `DescribeTopicsResult`, `TopicDescription`, `CreateTopicsResult`

`AdminClient` 의 가장 흔한 활용 사례는 토픽 목록 조회, 상세 내역 조회, 생성 및 삭제 등의 토픽 관리이다.

아래는 클러스터에 있는 토픽 목록을 조회하는 예시이다.

AdminClientSample.java
```java
package com.assu.study.chap05;

import java.time.Duration;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.ListTopicsResult;

public class AdminClientSample {
  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

    AdminClient adminClient = AdminClient.create(props);

    // 클러스터에 있는 토픽 목록 조회
    ListTopicsResult topics = adminClient.listTopics(); // Future 객체들을 ListTopicsResult 객체 리턴
    topics.names().get().forEach(System.out::println);

    adminClient.close(Duration.ofSeconds(30));
  }
}
```

**`adminClient.listTopics()` 는 `Future` 객체들을 감싸고 있는 `ListTopicsResult` 객체를 리턴**한다.  
**`topics.names()` 는 토픽 이름 집합에 대한 `Future` 객체를 리턴**한다.  
**이 `Future` 객체에서 `get()` 메서드를 호출하면 실행 스레드는 서버가 토픽 이름 집합을 리턴할 때까지 기다리거나 타임아웃 예외를 발생**시킨다.

위 코드에선 토픽 이름 집합을 받은 후 모든 토픽 이름을 출력하도록 하였다.

아래는 토픽이 존재하는지 확인 후 없으면 생성하는 예시이다.  
**특정 토픽이 존재하는지 확인하는 방법 중 하나는 모든 토픽의 목록을 받은 후 원하는 토픽이 그 안에 있는지 확인**하는 것이다.

큰 클러스터에서 이 방법은 비효율적일수 있고, 때로는 단순히 토픽의 존재 여부 뿐 아니라 해당 토픽이 필요한 만큼의 파티션과 레플리카키를 갖고 있는지 확인하는 등 
그 이상의 정보가 필요할 수도 있다.

예를 들어 카프카 커넥트와 컨플루언트의 스키마 레지스트리는 설정을 저장하기 위해 카프카 토픽을 사용하는데, 이들은 처음 시작 시 아래 조건을 만족하는 
설정 토픽이 있는지 확인한다.
- 하나의 파티션을 가짐, 이는 설정 변경에 온전한 순서를 부여하기 위해 필요함
- 가용성을 보장하기 위해 3개의 레플리카를 가짐
- 오래된 설정값도 계속해서 저장되도록 토픽에 압착 설정이 되어있음

아래는 예시는 다음의 흐름으로 동작한다.
- 토픽 리스트 조회
- 해당 토픽 리스트에서 특정 토픽이 있는지 조회
  - 해당 토픽이 존재한다면 의도한 파티션 수를 갖고 있는지 확인
  - 해당 토픽이 존재하지 않으면 새로운 토픽 생성
  - 새로운 토픽 생성 후 의도한 파티션 수를 갖고 있는지 확인

AdminClientSample.java
```java
package com.assu.study.chap05;

import java.time.Duration;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.common.errors.UnknownTopicOrPartitionException;

@Slf4j
public class AdminClientSample {
  private static final String TOPIC_NAME = "sample-topic";
  private static final List<String> TOPIC_LIST = List.of(TOPIC_NAME);
  private static final int NUM_PARTITIONS = 6;
  private static final short REPLICATION_FACTOR = 1;

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    TopicDescription topicDescription;

    // ======= 클러스터에 있는 토픽 목록 조회
    
    ListTopicsResult topics = adminClient.listTopics(); // Future 객체들을 ListTopicsResult 객체 리턴
    topics.names().get().forEach(System.out::println);

    // ======= 특정 토픽이 있는지 확인 후 없으면 토픽 생성
    
    // 정확한 설정을 갖는 토픽이 존재하는지 확인하려면 확인하려는 토픽의 목록을 인자로 넣어서 describeTopics() 메서드 호출
    // 리턴되는 DescribeTopicsResult 객체 안에는 토픽 이름을 key 로, 토픽에 대한 상세 정보를 담는 Future 객체를 value 로 하는 맵이 들어있음
    DescribeTopicsResult sampleTopic = adminClient.describeTopics(TOPIC_LIST); // 1)
    try {
      // Future 가 완료될 때가지 기다린다면 get() 을 사용하여 원하는 결과물 (여기선 TopicDescription) 을 얻을 수 있음
      // 하지만 서버가 요청을 제대로 처리하면 못할 수도 있음
      // (만일 토픽이 존재하지 않으면 서버가 상세 정보를 보내줄 수도 없음)
      // 이 경우 서버는 에러를 리턴할 것이고, Future 는 ExecutionException 을 발생시킴
      // 예외의 cause 에 들어있는 것이 서버가 실제 리턴한 실제 에러임
      // 여기선 토픽이 존재하지 않을 경우를 처리하고 싶은 것이므로 이 예외를 처리해주어야 함
      topicDescription = sampleTopic.topicNameValues().get(TOPIC_NAME).get(); // 2)
      log.info("Description of sample topic: {}", topicDescription);

      // 토픽이 존재할 경우 Future 객체는 토픽에 속한 모든 파티션의 목록을 담은 TopicDescription 을 리턴함
      // TopicDescription 는 파티션별로 어느 브로커가 리더이고, 어디에 레플리카가 있고, in-sync replica 가 무엇인지까지 포함함
      // 주의할 점은 토픽의 설정은 포함되지 않는다는 점임
      // 토픽 설정에 대해선 추후 다룰 예정
      if (topicDescription.partitions().size() != NUM_PARTITIONS) { // 3)
        log.error("Topic has wrong number of partitions: {}", topicDescription.partitions().size());
        // System.exit(1);
      }
    } catch (ExecutionException e) { // 4) 토픽이 존재하지 않은 경우에 대한 처리
      // 모든 예외에 대해 바로 종료
      if (!(e.getCause() instanceof UnknownTopicOrPartitionException)) {
        log.error(e.getMessage());
        throw e;
      }

      // 여기까지 오면 토픽이 존재하지 않는 것임
      log.info("Topic {} does not exist. Going to create it now.", TOPIC_NAME);

      // 토픽이 존재하지 않을 경우 새로운 토픽 생성
      // 토픽 생성 시 토픽의 이름만 필수이고, 파티션 수와 레플리카수는 선택사항임
      // 만일 이 값들을 지정하지 않으면 카프카 브로커에 설정된 기본값이 사용됨
      CreateTopicsResult newTopic =
              adminClient.createTopics(
                      List.of(new NewTopic(TOPIC_NAME, NUM_PARTITIONS, REPLICATION_FACTOR))); // 5)

      // 잘못된 수의 파티션으로 토픽으로 생성되었는지 확인하려면 아래 주석 해제
      //      CreateTopicsResult newWrongTopic =
      //          adminClient.createTopics(
      //              List.of(new NewTopic(TOPIC_NAME, Optional.empty(), Optional.empty())));

      // 토픽이 정상적으로 생성되었는지 확인
      // 여기서는 파티션의 수를 확인하고 있음
      // CreateTopic 의 결과물을 확인하기 위해 get() 을 다시 호출하고 있기 때문에 이 메서드가 예외를 발생시킬 수 있음
      // 이 경우 TopicExistsException 이 발생하는 것이 보통이며, 이것을 처리해 주어야 함
      // 보통은 설정을 확인하기 위해 토픽 상세 내역을 조회함으로써 처리함
      if (newTopic.numPartitions(TOPIC_NAME).get() != NUM_PARTITIONS) { // 6)
        log.error("Topic was created with wrong number of partitions. Exiting.");
        System.exit(1);
      }
    }
  }
}
```

1) **정확한 설정을 갖는 토픽이 존재하는지 확인**하려면 확인하려는 토픽의 목록을 인자로 넣어서 **`describeTopics()` 메서드를 호출**함  
리턴되는 **`DescribeTopicsResult` 객체 안에는 토픽 이름을 key 로, 토픽에 대한 상세 정보를 담는 Future 객체를 value 로 하는 맵**이 들어있음

2) **`Future` 가 완료될 때까지 기다린다면 `get()` 을 사용하여 원하는 결과물 (여기선 `TopicDescription`) 을 얻을 수 있음**  
하지만 서버가 요청을 제대로 처리하지 못할수도 있음  
예) 토픽이 존재하지 않은 경우 서버가 상세 정보를 응답으로 보내줄 수도 없음  
이 경우 서버는 에러를 리턴할 것이고, `Future` 는 _ExecutionException_ 을 발생시킴  
예외의 `cause` 에 들어있는 것이 실제 서버가 리턴한 실제 에러임  
여기선 토픽이 존재하지 않을 경우를 처리하고 싶은 것 (= 토픽이 존재하지 않으면 토픽 생성) 이므로 _ExecutionException_ 예외를 처리해주어야 함

3) **토픽이 존재할 경우 `Future` 객체는 토픽에 속한 모든 파티션의 목록을 담은 `TopicDescription` 을 리턴**함  
**`TopicDescription` 엔 파티션별로 어느 브로커가 리더이고, 어디에 레플리카가 있고, ISR(In-Sync Replica) 가 무엇인지까지 포함**함  
주의할 점은 토픽의 설정은 포함되지 않는다는 점임  
> 토픽 설정에 대한 부분은 추후 다룰 예정입니다. (p. 132)

4) **모든 `AdminClient` 의 result 객체는 카프카가 에러 응답을 보낼 경우 _ExecutionException_ 을 발생**시킴  
그 이유는 `AdminClient` 가 리턴한 객체가 `Future` 객체를 포함하고, `Future` 객체는 다시 예외를 포함하고 있기 때문임  
**카프카가 리턴한 에러를 열어보려면 항상 _ExecutionException_ 의 `cause` 를 확인**해보아야 함

5) **토픽이 존재하지 않을 경우 새로운 토픽 생성**  
토픽 생성 시 토픽의 이름만 필수이고, 파티션 수과 레플리카수는 선택사항임  
만일 이 값들을 지정하지 않으면 카프카 브로커에 설정된 기본값이 사용됨

6) **토픽이 정상적으로 생성되었는지 확인**  
여기서는 파티션의 수를 확인하고 있음  
`CreateTopic` 의 결과물을 확인하기 위해 `get()` 을 다시 호출하고 있기 때문에 이 메서드가 예외를 발생시킬 수 있음  
이 경우 _TopicExistsException_ 이 발생하는 것이 보통이며, 이것을 처리해 주어야 함  
보통은 설정을 확인하기 위해 토픽 상세 내역을 조회함으로써 처리함

---

## 3.2. 토픽 삭제: `deleteTopics()`

AdminClientSample.java
```java
package com.assu.study.chap05;

import java.time.Duration;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.common.errors.UnknownTopicOrPartitionException;

@Slf4j
public class AdminClientSample {
  private static final String TOPIC_NAME = "sample-topic";
  private static final List<String> TOPIC_LIST = List.of(TOPIC_NAME);
  private static final int NUM_PARTITIONS = 6;
  private static final short REPLICATION_FACTOR = 1;

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    TopicDescription topicDescription;

    // ======= 클러스터에 있는 토픽 목록 조회

    ListTopicsResult topics = adminClient.listTopics(); // Future 객체들을 ListTopicsResult 객체 리턴
    topics.names().get().forEach(System.out::println);

    // ======= 토픽 생성
    // ...

    // ======= 토픽 삭제
    adminClient.deleteTopics(TOPIC_LIST).all().get();

    try {
      // 토픽이 삭제되었는지 확인
      // 삭제 작업이 비동기적으로 이루어지므로 이 시점에서 토픽이 여전히 남아있을 수 있음
      sampleTopic.topicNameValues().get(TOPIC_NAME).get();
      log.info("Topic {} is still around.");
    } catch (ExecutionException e) {
      log.info("Topic {} is gone.", TOPIC_NAME);
    }
  }
}
```

**삭제할 토픽 리스트를 인자로 하여 `deleteTopics()` 메서드를 호출한 뒤 `get()` 을 호출해서 작업이 끝날 때까지 기다린다.**

**카프카에서 삭제된 토픽은 복구가 불가능하기 때문에 데이터 유실**이 발생할 수 있으므로 토픽을 삭제할 때는 특별히 주의해야 한다.

---

## 3.3. 비동기적으로 토픽의 상세 정보 조회: `KafkaFuture`, `whenComplete()`

위에서는 모두 서로 다른 **`AdminClient` 메서드가 리턴하는 `Future` 객체에 블로킹 방식으로 동작하는 `get()` 메서드를 호출**한다.

어드민 작업은 드물고, 작업이 성공하거나 타임아웃이 날 때까지 기다리는 것 또한 대체로 받아들일만 하기 때문에 대부분 위처럼 작성해도 된다.

하지만 예외 케이스가 하나 있는데 바로 많은 어드민 요청을 처리할 것으로 예상되는 서버를 개발하는 경우이다.  
이 경우 카프카가 응답할 때까지 기다리는 동안 서버 스레드가 블록되는 것보다는, 사용자로부터 계속해서 요청을 받고, 카프카로 요청을 보내고, 카프카가 응답하면 그 때 
클라이언트로 응답을 보내는 것이 더 합리적이다.

**이럴 때 `KafkaFuture` 의 융통성은 매우 도움**이 된다.

아래는 비동기적으로 토픽의 상세 정보를 응답하는 예시이다.

AdminRestServer.java
```java
package com.assu.study.chap05;

import io.vertx.core.Vertx;
import io.vertx.core.VertxOptions;
import io.vertx.core.http.HttpServerOptions;
import java.util.List;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.math.NumberUtils;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.common.KafkaFuture;

// Test with: curl 'localhost:8080?topic=demo-topic'
// 실제로 비동기인지 확인하려면 SIGSTOP 을 사용하여 카프카를 중지시킨 후 아래 실행
// curl 'localhost:8080?topic=demo-topic&timeout=60000' on one terminal
// curl 'localhost:8080?topic=demo-topic' on another

// Vertx 스레드가 하나만 있어도 첫 번째 명령은 60초를 기다리고, 두 번째 명령은 즉시 반환됨
// 두 번째 명령이 첫 번째 명령 이후에 블록되지 않았음을 알 수 있음
@Slf4j
public class AdminRestServer {
  private static Vertx vertx = Vertx.vertx(new VertxOptions().setWorkerPoolSize(1));

  public static void main(String[] args) {
    // AdminClient 초기화
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // request.timeout.ms
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // default.api.timeout.ms
    AdminClient adminClient = AdminClient.create(props);

    // 서버 생성
    HttpServerOptions options = new HttpServerOptions().setLogActivity(true);
    vertx
        .createHttpServer(options)
        // Vertx 를 사용하여 간단한 HTTP 서버 생성
        // 이 서버는 요청을 받을 때마다 requestHandler 호출함
        .requestHandler( // 1)
            req -> {
              // 요청은 매개 변수로 토픽 이름을 보내고, 응답은 토픽의 상세 설정을 내보냄
              String topic = req.getParam("topic"); // 2)
              String timeout = req.getParam("timeout");
              int timeoutMs = NumberUtils.toInt(timeout, 1000); // timeout 이 없으면 디폴트 1000ms

              // AdminClient.describeTopics() 를 호출하여 응답에 들어있는 Future 객체를 받아옴
              DescribeTopicsResult demoTopic =
                  adminClient.describeTopics( // 3)
                      List.of(topic), new DescribeTopicsOptions().timeoutMs(timeoutMs));

              demoTopic
                  .topicNameValues() // Map<String, KafkaFuture<TopicDescription>> 반환
                  .get(topic) // KafkaFuture<TopicDescription> 반환
                  // 호출 시 블록되는 get() 을 호출하는 대신 Future 객체의 작업이 완료되면 호출될 함수 생성
                  .whenComplete( // 4)
                      new KafkaFuture.BiConsumer<TopicDescription, Throwable>() {
                        @Override
                        public void accept(TopicDescription topicDescription, Throwable throwable) {
                          if (throwable != null) {
                            log.info("got exception");

                            // Future 가 예외를 발생시키면서 완료될 경우 HTTP 클라이언트에 에러를 보냄
                            req.response()
                                .end(
                                    "Error trying to describe topic "
                                        + topic
                                        + " due to "
                                        + throwable.getMessage()); // 5)
                          } else {
                            // Future 가 성공적으로 완료될 경우 HTTP 클라이언트에 토픽의 상세 정보를 보냄
                            req.response().end(topicDescription.toString()); // 6)
                          }
                        }
                      });
            })
        .listen(8080);
  }
}
```

위 코드를 보면 **호출 시 블록되는 `get()` 을 호출하는 대신 `Future` 객체의 작업이 완료되면 호출되는 `whenComplete()` 를 호출**하고 있다.

중요한 것은 카프카로부터의 응답을 기다리지 않는다는 점이다.

카프카로부터 응답이 도착하면 `DescribeTopicResult` 가 HTTP 클라이언트에게 응답을 보낼 것이다.  
그 사이에 HTTP 서버는 다른 요청을 처리할 수 있다.

카프카에 `SIGSTOP` 신호를 보내서 잠시 멈춘 뒤 Vert.x 에 2 개의 HTTP 요청을 보내보면 확인할 수 있다.  
```shell
curl 'localhost:8080?topic=demo-topic&timeout=60000'
curl 'localhost:8080?topic=demo-topic'
```

첫 번째 요청 다음으로 두 번째 요청을 보냈을 때 두 번째 응답이 첫 번째 응답보다 먼저 온다.  
이것은 첫 번째 요청이 처리될 때까지 기다리지 않는다는 것을 의미한다.

위 코드에서 아래 코드는 람다로 변경하여 사용할 수 있다.
```java
.whenComplete( // 4)
  new KafkaFuture.BiConsumer<TopicDescription, Throwable>() {
    @Override
    public void accept(TopicDescription topicDescription, Throwable throwable) {
      if (throwable != null) {
        log.info("got exception");
        req.response()
            .end(
                "Error trying to describe topic "
                    + topic
                    + " due to "
                    + throwable.getMessage()); // 5)
      } else {
        req.response().end(topicDescription.toString()); // 6)
      }
    }
  });
```

위 코드를 람다로 변경한 예시
```java
.whenComplete( // 4)
    (topicDescription, throwable) -> {
      if (throwable != null) {
        log.info("got exception");
        req.response()
            .end(
                "Error trying to describe topic "
                    + topic
                    + " due to "
                    + throwable.getMessage()); // 5)
      } else {
        req.response().end(topicDescription.toString()); // 6)
      }
    });
```

---

# 4. 설정 관리: `ConfigResource`, `DescribeConfigsResult`, `describeConfigs()`, `AlterConfigOp`

**설정 관리는 `ConfigResource` 객체를 사용**해서 할 수 있다.

**설정 가능한 자원**은 아래와 같다.
- 브로커
- 브로커 로그
- 토픽

브로커와 브로커 로깅 설정은 `kafka-configs.sh` 혹은 다른 카프카 관리 툴을 사용하는 것이 보통이지만, 애플리케이션에서 사용하는 토픽의 설정을 확인하거나 수정하는 것은 
상당히 빈번하다.

예를 들어 **많은 애플리케이션들은 정확한 작동을 위해 압착 설정이 된 토픽을 사용**한다.  
이 경우 애플리케이션이 주기적으로 해당 토픽에 실제로 압착 설정이 되어있는지를 확인한 후 (보존 기한 기본값보다 짧은 주기로 하는 것이 안전함), 설정이 안되어 있다면 
설정을 교정해주는 것이 합리적이다.

아래는 토픽 압착이 설정되어 있는지 확인 후 설정되어 있지 않다면 압착 설정을 해주는 예시이다.

AdminClientSample.java
```java
package com.assu.study.chap05;

import java.util.*;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.common.config.ConfigResource;
import org.apache.kafka.common.config.TopicConfig;
import org.apache.kafka.common.errors.UnknownTopicOrPartitionException;

@Slf4j
public class AdminClientSample {
  private static final String TOPIC_NAME = "sample-topic";
  private static final List<String> TOPIC_LIST = List.of(TOPIC_NAME);
  private static final int NUM_PARTITIONS = 6;
  private static final short REPLICATION_FACTOR = 1;

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    TopicDescription topicDescription;

    // ======= 클러스터에 있는 토픽 목록 조회
    // ...
    // ======= 특정 토픽이 있는지 확인 후 없으면 토픽 생성
    // ...

    // ======= 토픽 압착(compacted) 설정 확인 및 교정

    // 특정한 토픽의 설정 확인
    ConfigResource configResource = new ConfigResource(ConfigResource.Type.TOPIC, TOPIC_NAME); // 1)
    DescribeConfigsResult configsResult = adminClient.describeConfigs(List.of(configResource));
    Config configs = configsResult.all().get().get(configResource);

    // 기본값이 아닌 설정 출력
    // describeConfig() 의 결과물인 DescribeConfigsResult 는 ConfigResource 를 key 로, 설정값의 모음을 value 로 갖는 맵임
    // 각 설정 항목은 해당 값이 기본값에서 변경되었는지 확인할 수 있게 해주는 isDefault() 메서드를 가짐
    // 토픽 설정이 기본값이 아닌 것으로 취급되는 경우는 2 가지 경우가 있음
    // 1. 사용자가 토픽의 설정값을 기본값이 아닌 것으로 잡아준 경우
    // 2. 브로커 단위 설정이 수정된 상태에서 토픽이 생성되어 기본값이 아닌 값을 브로커 설정으로부터 상속받은 경우
    configs.entries().stream()
            .filter(entry -> !entry.isDefault())
            .forEach(System.out::println); // 2)

    // 토픽에 압착 (compacted) 설정이 되어있는지 확인
    ConfigEntry compaction =
            new ConfigEntry(TopicConfig.CLEANUP_POLICY_CONFIG, TopicConfig.CLEANUP_POLICY_COMPACT); // cleanup.policy, compact

    // 토픽에 압착 설정이 되어있지 않을 경우 압착 설정해 줌
    if (!configs.entries().contains(compaction)) {
      Collection<AlterConfigOp> configOp = new ArrayList<>();

      // 설정을 변경하려면 변경하고자 하는 ConfigResource 를 key 로, 바꾸고자 하는 설정값 모음을 value 로 하는 맵을 지정함
      // 각각의 설정 변경 작업은 설정 항목 (= 설정의 이름과 설정값. 여기서는 cleanup.policy 가 설정 이름이고, compact 가 설정값) 과 작업 유형으로 이루어짐
      // 카프카에서는 4가지 형태의 설정 변경이 가능함
      // 설정값을 잡아주는 SET / 현재 설정값을 삭제하고 기본값으로 되돌리는 DELETE / APPEND / SUBSTRACT
      // APPEND 와 SUBSTRACT 는 목록 형태의 설정에만 사용 가능하며, 이걸 사용하면 전체 목록을 주고받을 필요없이 필요한 설정만 추가/삭제 가능함
      configOp.add(new AlterConfigOp(compaction, AlterConfigOp.OpType.SET)); // 3)
      Map<ConfigResource, Collection<AlterConfigOp>> alterConfigs = new HashMap<>();
      alterConfigs.put(configResource, configOp);
      adminClient.incrementalAlterConfigs(alterConfigs).all().get();
    } else {
      log.info("Topic {} is compacted topic.", TOPIC_NAME);
    }

    // ======= 토픽 삭제
    // ...
}
```

1) **`ConfigResource` 로 특정한 토픽의 설정을 확인**함  
하나의 요청에 여러 개의 서로 다른 유형의 자원을 지정할 수 있음

2) **`describeConfigs()` 의 결과물인 `DescribeConfigsResult` 는 `ConfigResource` 를 key 로, 설정값의 모음을 value 로 갖는 맵**임  
각 설정 항목은 해당 값이 기본값에서 변경되었는지 확인할 수 있게 해주는 `isDefault()` 메서드 제공  
**토픽 설정이 기본값이 아닌 것으로 취급되는 경우는 2가지 경우**가 있음  
1. 사용자가 토픽의 설정값을 기본값이 아닌 것으로 잡아준 경우
2. 브로커 단위 설정이 수정된 상태에서 토픽이 생성되어서 기본값이 아닌 값을 브로커 설정으로부터 상속받은 경우

3) **설정을 변경하기 위해 변경하고자 하는 `ConfigResource` 를 key 로, 바꾸고자 하는 설정값 모음을 value 로 하는 맵을 지정**함  
각각의 설정 변경 작업은 설정 항목과 작업 유형으로 이루어짐  
위에서 설정 항목은 설정의 이름과 설정값을 의미함 (여기서는 `cleanup.policy` 가 설정의 이름이고, `compact` 가 설정값)  
**카프카에서는 4가지 형태의 설정 변경이 가능**함
**설정값을 잡아주는 `SET` / 현재 설정값을 삭제하고 기본값으로 되돌리는 `DELETE` / `APPEND` / `SUBSTRACT`**  
`APPEND` 와 `SUBSTRACT` 는 목록 형태의 설정에만 사용 가능하며, 이걸 사용하면 전체 목록을 주고받을 필요없이 필요한 설정만 추가/삭제 가능함

상세한 설정값을 얻어오는 것은 비상 상황에서 큰 도움이 된다.  
예를 들어 업그레이드를 하다가 실수로 브로커 설정 파일이 깨진 상황에서 이러한 이슈가 있다는 것을 첫 번째 브로커의 재시작 실패를 보고서야 알아차렸을 때 
깨지기 전 원본 파일을 복구할 방법이 없기 때문에 상당히 난감할 수 있다.  
이럴 때 `AdminClient` 를 사용하여 아직 남아있던 브로커 중 하나의 설정값을 통째로 덤프를 떠서 설정 파일을 복구할 수 있다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Kafka Doc](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [KIP-206: Add support for UUID serialization and deserialization](https://cwiki.apache.org/confluence/display/KAFKA/KIP-206:+Add+support+for+UUID+serialization+and+deserialization)
* [KIP-527: Add VoidSerde to Serdes](https://cwiki.apache.org/confluence/display/KAFKA/KIP-527:+Add+VoidSerde+to+Serdes)
* [KIP-466: Add support for `List<T>` serialization and deserialization](https://cwiki.apache.org/confluence/display/KAFKA/KIP-466:+Add+support+for+List%3CT%3E+serialization+and+deserialization)
* [Apache Kafka 3.8.0 Release Announcement](https://kafka.apache.org/blog?fbclid=IwAR0K9FLZFzvBJHJlfclqZ8maU1E57gofMapl0LDJPWpTYTssVJaE8obE0Lk#apache_kafka_380_release_announcement)
* [카프카 보안 - 인증과 인자 (SASL)](https://always-kimkim.tistory.com/entry/kafka101-security)