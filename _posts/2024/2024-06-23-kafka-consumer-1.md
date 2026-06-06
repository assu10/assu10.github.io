---
layout: post
title:  "Kafka - 컨슈머(1): 컨슈머 그룹, 리밸런스, 컨슈머 생성, 토픽 구독, 폴링 루프, 컨슈머 설정, 파티션 할당 전략"
date: 2024-06-23
categories: dev
tags: kafka consumer consumerGroup eagerRebalance cooperativeRebalance staticGroupMembership topic subscribe() poll() partition
---

카프카에서 데이터를 읽는 애플리케이션은 토픽을 구독(subscribe) 하고, 구독한 토픽들로부터 메시지를 받기 위해 `KafkaConsumer` 를 사용한다.  
이 포스트에서는 카프카에 쓰여진 메시지를 읽기 위한 클라이언트에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 카프카 컨슈머](#1-카프카-컨슈머)
  * [1.1. 컨슈머와 컨슈머 그룹](#11-컨슈머와-컨슈머-그룹)
    * [1.1.1. 단일 컨슈머 애플리케이션의 규모 확장을 위한 컨슈머 추가](#111-단일-컨슈머-애플리케이션의-규모-확장을-위한-컨슈머-추가)
    * [1.1.2. 여러 애플리케이션에서 데이터를 읽기 위한 컨슈머 그룹](#112-여러-애플리케이션에서-데이터를-읽기-위한-컨슈머-그룹)
  * [1.2. 컨슈머 그룹과 파티션 리밸런스](#12-컨슈머-그룹과-파티션-리밸런스)
    * [1.2.1. 조급한 리밸런스 (eager rebalance)](#121-조급한-리밸런스-eager-rebalance)
    * [1.2.2. 협력적 리밸런스 (cooperative rebalance) 혹은 점진적 리밸런스 (incremental rebalance)](#122-협력적-리밸런스-cooperative-rebalance-혹은-점진적-리밸런스-incremental-rebalance)
    * [1.2.3. 컨슈머에 파티션이 할당되는 방법: `JoinGroup`, `PartitionAssignor`, `GroupCoordinator`](#123-컨슈머에-파티션이-할당되는-방법-joingroup-partitionassignor-groupcoordinator)
  * [1.3. 정적 그룹 멤버십 (static group membership): `group.instance.id`, `session.timeout.ms`](#13-정적-그룹-멤버십-static-group-membership-groupinstanceid-sessiontimeoutms)
* [2. 컨슈머 생성](#2-컨슈머-생성)
* [3. 토픽 구독: `subscribe()`](#3-토픽-구독-subscribe)
  * [3.1. 정규식으로 토픽 구독 시 주의점: `Describe`](#31-정규식으로-토픽-구독-시-주의점-describe)
* [4. 폴링 루프: `poll()`](#4-폴링-루프-poll)
  * [4.1. 스레드 안전성](#41-스레드-안전성)
    * [4.1.1.컨슈머에서 레코드를 읽지 않고 메타데이터만 받아야 하는 경우 해결법](#411컨슈머에서-레코드를-읽지-않고-메타데이터만-받아야-하는-경우-해결법)
* [5. 컨슈머 설정](#5-컨슈머-설정)
  * [5.1. `fetch.min.bytes`](#51-fetchminbytes)
  * [5.2. `fetch.max.wait.ms`](#52-fetchmaxwaitms)
  * [5.3. `fetch.max.bytes`](#53-fetchmaxbytes)
  * [5.4. `max.poll.records`](#54-maxpollrecords)
  * [5.5. `max.partition.fetch.bytes`](#55-maxpartitionfetchbytes)
  * [5.6. `session.timeout.ms`, `heartbeat.interval.ms`](#56-sessiontimeoutms-heartbeatintervalms)
  * [5.7. `max.poll.interval.ms`](#57-maxpollintervalms)
  * [5.8. `default.api.timeout.ms`](#58-defaultapitimeoutms)
  * [5.9. `request.timeout.ms`](#59-requesttimeoutms)
  * [5.10. `auto.offset.reset`](#510-autooffsetreset)
  * [5.11. `enable.auto.commit`](#511-enableautocommit)
  * [5.12. `partition.assignment.strategy`: `PartitionAssinor`](#512-partitionassignmentstrategy-partitionassinor)
    * [5.12.1. `Range` 파티션 할당 전략](#5121-range-파티션-할당-전략)
    * [5.12.2. `RoundRobin` 파티션 할당 전략](#5122-roundrobin-파티션-할당-전략)
    * [5.12.3. `Sticky` 파티션 할당 전략](#5123-sticky-파티션-할당-전략)
    * [5.12.4. `Cooperative Sticky` (협력적 Sticky) 파티션 할당 전략](#5124-cooperative-sticky-협력적-sticky-파티션-할당-전략)
  * [5.13. `client.id`](#513-clientid)
  * [5.14. `client.rack`, `replica.selector.class`](#514-clientrack-replicaselectorclass)
  * [5.15. `group.instance.id`](#515-groupinstanceid)
  * [5.16. `receive.buffer.bytes`, `send.buffer.bytes`](#516-receivebufferbytes-sendbufferbytes)
  * [5.17. `offsets.retention.minutes`](#517-offsetsretentionminutes)
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

pom.xml (chap04)
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

  <artifactId>chap04</artifactId>

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
    <kafka.version>3.8.0</kafka.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.apache.kafka</groupId>
      <artifactId>kafka-clients</artifactId>
      <version>${kafka.version}</version>
    </dependency>
  </dependencies>
</project>
```

---

# 1. 카프카 컨슈머

카프카로부터 데이터를 읽어오는 방법을 이해하기 위해 먼저 **컨슈머**와 **컨슈머 그룹**에 대해 알아본다.

---

## 1.1. 컨슈머와 컨슈머 그룹

카프카 토픽으로부터 메시지를 읽어서 몇 가지 검사 후 다른 데이터 저장소에 저장하는 애플리케이션을 개발한다고 해보자.

이 경우 애플리케이션은 아래와 같은 과정을 거치게 된다.
- 애플리케이션은 컨슈머 객체 (`KafkaConsumer` 인스턴스) 생성
- 해당 토픽 구독
- 메시지를 받기 시작한 뒤 받은 메시지를 검사한 후 결과를 씀

> 컨슈머 그룹 운영에 대해서는 [2. 컨슈머 그룹: kafka-consumer-groups.sh
](https://assu10.github.io/dev/2024/09/21/kafka-operation-1/#2-%EC%BB%A8%EC%8A%88%EB%A8%B8-%EA%B7%B8%EB%A3%B9-kafka-consumer-groupssh) 을 참고하세요.

---

### 1.1.1. 단일 컨슈머 애플리케이션의 규모 확장을 위한 컨슈머 추가

이 때 컨슈머 애플리케이션이 검사할 수 있는 속도보다 프로듀서가 토픽에 메시지를 쓰는 속도가 더 빠르면 컨슈머 애플리케이션은 새로 추가되는 메시지의 속도를 따라잡을 수 
없기 때문에 메시지 처리가 계속해서 뒤로 밀리게 된다.

따라서 **토픽으로부터 데이터를 읽어오는 작업을 확장**할 수 있어야 한다.

**여러 개의 프로듀서가 동일한 토픽에 메시지를 쓰듯이, 여러 개의 컨슈머가 같은 토픽으로부터 데이터를 분할해서 읽어올 수 있도록 해야 한다.**

카프카 컨슈머는 보통 컨슈머 그룹의 일부로서 동작한다.  
**동일한 컨슈머 그룹에 속한 여러 개의 컨슈머들이 동일한 토픽을 구독할 경우, 각 컨슈머는 해당 토픽에서 서로 다른 파티션의 메시지**를 받는다.

아래는 4개의 파티션을 갖는 토픽과 1개의 컨슈머를 갖는 컨슈머 그룹이 있을 때 유일한 컨슈머인 C1 을 생성하여 T1 토픽을 구독할 때의 예시이다.  
컨슈머 C1 은 토픽 T1 의 4개의 파티션 모두에서 모든 메시지를 받는다.

![4개의 파티션과 1개의 컨슈머](/assets/img/dev/2024/0623/consumer_group_1.png)

이 때 컨슈머 그룹에 새로운 컨슈머 C2 를 추가하면 각 컨슈머는 2개의 파티션에서 메시지를 받게 된다.  
아래는 컨슈머 C1 은 파티션 0과 2를, 컨슈머 C2 는 파티션 1과 4를 맡았다.

![4개의 파티션과 2개의 컨슈머](/assets/img/dev/2024/0623/consumer_group_2.png)

만일 컨슈머 그룹에 컨슈머가 4개가 있다면 아래처럼 각 컨슈머가 하나의 파티션에서 메시지를 읽어오게 된다.

![4개의 파티션과 4개의 컨슈머](/assets/img/dev/2024/0623/consumer_group_3.png)

만일 하나의 토픽을 구독하는 하나의 컨슈머 그룹에 파티션 수보다 많은 컨슈머를 추가한다면 컨슈머 중 몇몇은 유휴 상태가 되어 메시지를 전혀 받지 못한다.

![4개의 파티션과 5개의 컨슈머](/assets/img/dev/2024/0623/consumer_group_4.png)

위처럼 **<u>컨슈머 그룹에 컨슈머를 추가하는 것은 카프카 토픽에서 읽어오는 데이터 양을 확장하는 주된 방법</u>**이다.

카프카 컨슈머가 DB 에 쓴다던가 데이터에 대해 시간이 오래걸리는 연산을 수행하다는 등의 지연 시간이 긴 작업을 할 때 하나의 컨슈머로 토픽에 들어오는 데이터의 속도를 
감당할 수 없을 수도 있기 때문에 **컨슈머를 추가함으로써 단위 컨슈머가 처리하는 파티션과 메시지의 수를 분산시키는 것이 일반적인 규모 확장 방식**이다.

**<u>이것은 토픽을 생성할 때 파티션 수를 크게 잡아주는 게 좋은 이유이기도 한데, 부하가 증가함에 따라 더 많은 컨슈머를 추가할 수 있게 해주기 때문</u>**이다.

> 토픽의 파티션 개수를 선정하는 방법은 [3.2.2. 파티션 개수를 정할 때 고려할 사항](https://assu10.github.io/dev/2024/06/15/kafka-install/#322-%ED%8C%8C%ED%8B%B0%EC%85%98-%EA%B0%9C%EC%88%98%EB%A5%BC-%EC%A0%95%ED%95%A0-%EB%95%8C-%EA%B3%A0%EB%A0%A4%ED%95%A0-%EC%82%AC%ED%95%AD) 을 참고하세요.

---

### 1.1.2. 여러 애플리케이션에서 데이터를 읽기 위한 컨슈머 그룹

여러 애플리케이션이 동일한 토픽에서 데이터를 읽어와야 하는 경우도 있다.

카프카의 주 디자인 목표 중 하나는 카프카 토픽에 쓰여진 데이터를 전체 조직 안에서 여러 용도로 사용하기 위함이다.  
이럴 경우 각 애플리케이션이 전체 메시지의 일부만 받는 게 아니라 전부 다 받도록 해야 하는데 그럴려면 **애플리케이션이 각자의 컨슈머 그룹**을 갖도록 해야 한다.

다른 전통적인 메시지 전달 시스템과 달리 **카프카는 성능 저하 없이 많은 수의 컨슈머와 컨슈머 그룹으로 확장이 가능**하다.

아래는 새로운 컨슈머 그룹인 G2 가 추가된 예시인데, 컨슈머 그룹 G2 는 컨슈머 그룹 G1 과 상관없이 토픽 T1 의 모든 메시지를 받게 된다.

![하나의 토픽을 구독하는 2개의 컨슈머 그룹](/assets/img/dev/2024/0623/consumer_group_5.png)

즉, **1개 이상의 토픽에 대해 모든 메시지를 받아야하는 애플리케이션별로 새로운 컨슈머 그룹을 생성**할 수 있다.

**토픽에서 메시지를 읽거나 처리하는 규모를 확장하기 위해서는 이미 존재하는 컨슈머 그룹에 새로운 컨슈머를 추가함으로써 해당 그룹 내의 컨슈머 각각이 메시지의 
일부만을 받아서 처리**하도록 하면 된다.

---

## 1.2. 컨슈머 그룹과 파티션 리밸런스

**컨슈머 그룹에 속한 컨슈머들은 자신들이 구독하는 토픽의 파티션들에 대한 소유권을 공유**한다.

**컨슈머에 할당된 파티션을 다른 컨슈머에게 할당해주는 작업을 리밸런스**라고 한다.

<**리밸런스가 발생하는 상황**>  
- **컨슈머 그룹에 새로운 컨슈머 추가할 경우**
  - 이전에 다른 컨슈머가 읽고 있던 파티션으로부터 메시지를 읽기 시작함
- **컨슈머가 종료되거나 크래시가 났을 경우**
  - 종료된 컨슈머가 컨슈머 그룹에서 나가면 원래 이 컨슈머가 읽던 파티션들은 그룹에 잔류한 나머지 컨슈머 중 하나가 대신 받아서 읽기 시작함
  - 컨슈머는 [`max.poll.records`](#54-maxpollrecords) 설정의 개수만큼 
  메시지를 처리한 후 poll 요청을 보내는데 메시지 처리 시간이 늦어져서 [`max.poll.interval.ms`](#57-maxpollintervalms) 설정 시간을 넘기게 되면 컨슈머에 문제가 있다고 판단하여 리밸런싱이 일어남
  - 컨슈머가 일정 시간동안 [하트비트](#56-sessiontimeoutms-heartbeatintervalms)를 보내지 못하면 세션이 종료되고, 컨슈머 그룹에서 제외되는데 이 때 리밸런싱이 진행됨
- **컨슈머 그룹이 읽고 있던 토픽이 변경되었을 경우**
  - 운영자가 토픽에 새로운 파티션을 추가했을 경우
- **토픽에 파티션 수가 변경될 때 (추가/감소)**

**리밸런스는 컨슈머 그룹에 쉽고 안전하게 컨슈머를 제거할 수 있도록 해줌과 동시에 높은 가용성(HA)과 규모 가변성 (scalability)을 제공하는 기능이므로 매우 중요**하지만, 
문제없이 작업이 수행되고 있는 와중이라면 그리 달갑지 않은 기능이기도 하다.

**리밸런싱이 진행될 때 아래의 상황**이 발생할 수 있다.
- **리밸런싱이 진행되는 동안 커슈머는 브로커로부터 메시지를 가져오지 못함**
  - 프로듀서는 지속적으로 메시지를 보내고 있기 때문에 컨슈머가 메시지를 처리하지 못하는 만큼 Lag 이 발생함
- **리밸런싱 과정에서 파티션의 어느 위치에서 메시지를 가져와야 하는지 결정하는 프로세스가 복잡해질 수 있음**
  - 이 과정에서 메시지가 중복되거나 누락될 수 있음

---

### 1.2.1. 조급한 리밸런스 (eager rebalance)

> 카프카 버전 3.1 부터 협력적 리밸런스가 기본값으로 변경됨  
> 조급한 리밸런스는 나중에 제거될 예정이므로 아래 내용은 참고만 하자.

조급한 리밸런스의 경우 모든 컨슈머는 읽기 작업을 멈추고 자신에게 할당된 모든 파티션에 대한 소유권을 포기한 뒤, 컨슈머 그룹에 다시 참여 (rejoin) 하여 
완전히 새로운 파티션 할당을 전달받는다.  
즉, 해당 컨슈머 그룹의 모든 작업이 일시 정지되고, 파티션을 재분배한 후 다시 동작한다.  
이 시간동안 컨슈머 그룹은 유휴 상태가 되어 메시지 컨슈밍과 오프셋 커밋이 불가능하다.

이 방식은 전체 컨슈머 그룹에 대해 짧은 시간동안 작업을 멈추게 한다.

작업이 중단되는 시간의 길이는 컨슈머 그룹의 크기, 여러 설정 매개 변수의 영향을 받는다.

<**조급한 리밸런스 과정**>  
- 모든 컨슈머가 자신에게 할당된 파티션 포기
- 파티션을 포기한 컨슈머 모두가 다시 그룹에 참여한 뒤에야 새로운 파티션을 할당받고 읽기 작업 재개

![조급한 리밸런스 과정](/assets/img/dev/2024/0623/rebalance_1.png)

① **Detection**
- 컨슈머 2의 장애 감지

② **Stopping**
- 컨슈머에게 할당된 모든 파티션 제거
- 잘 동작하고 있던 다른 컨슈머의 connection 도 끊기게 됨
- 이 때부터 컨슈머의 downtime 이 시작됨

③ **Restart**
- 구독한 파티션이 컨슈머들에게 재할당됨
- 이 때부터 컨슈머들은 각자 재할당받은 파티션에서 메시지를 consume 하기 시작함

**위 과정을 보면 컨슈머 2 와 매칭되었던 파티션 1 이 컨슈머 1 로 재할당**되었다.  
이처럼 **조급한 리밸런싱 이후에는 컨슈머가 이전에 가졌던 파티션을 반드시 다시 가진다는 보장을 할 수 없다.**

---

### 1.2.2. 협력적 리밸런스 (cooperative rebalance) 혹은 점진적 리밸런스 (incremental rebalance)

협력적 리밸런스는 한 컨슈머에게 할당되어 있던 파티션만을 다른 컨슈머에게 재할당한다.  
재할당되지 않은 파티션에서 레코드를 읽어서 처리하던 **나머지 컨슈머들은 작업에 방해받지 않고 하던 일을 계속** 할 수 있다.

이 경우 리밸런싱은 2개 이상의 단계를 걸쳐서 수행된다.
- 컨슈머 그룹 리더가 다른 컨슈머들에게 각자에게 할당된 파티션 중 일부가 재할당될 거라고 통보하면, 컨슈머들은 해당 파티션에서 데이터를 읽어 오는 작업을 멈추고 해당 파티션에 대한 소유권 포기
- 컨슈머 그룹 리더가 이 포기된 파티션을 새로 할당

이 점진적인 방식은 안정적으로 파티션이 할당될 때까지 몇 번 반복될 수 있지만, **조급한 리밸런스 방식에서 발생하는 전체 작업이 중단되는 상태는 발생하지 않는다.**  
즉, **컨슈머 그룹의 중지없이 파티션 재분배**가 일어난다.  
기존에 할당된 파티션을 새롭게 들어오는 컨슈머에게 양도하는 형태로 동작한다.

컨슈머는 해당 컨슈머 그룹의 **그룹 코디네이터** 역할을 지정받은 카프카 브로커에 **하트비트**를 전송함으로써 멤버십과 할당된 파티션에 대한 소유권을 유지한다.  
하티비트는 컨슈머의 백그라운드 스레드에 의해 일정한 간격을 두고 전송된다.

**만일 컨슈머가 일정 시간동안 하트비트를 전송하지 않는다면 세션 타임아웃이 발생하면서 그룹 코디네이터는 해당 컨슈머가 죽었다고 간주하고 리밸런스를 실행**한다.  
예) 컨슈머가 크래시가 나서 메시지 처리를 중단했을 경우, 그룹 코디네이터는 몇 초 이상 하트비트가 들어오지 않는 것을 보고 컨슈머가 죽었다고 판단한 뒤 리밸런스 실행

컨슈머를 깔끔하게 닫아줄 경우 컨슈머는 그룹 코디네이터에게 그룹을 나간다고 통지하는데, 그러면 그룹 코디네이터는 즉시 리밸런스를 실행함으로써 처리가 정지되는 시간을 줄인다.

> [5.6. `session.timeout.ms`, `heartbeat.interval.ms`](#56-sessiontimeoutms-heartbeatintervalms) 옵션으로 컨슈머 작동을 정밀하게 제어할 수 있음

그림으로 좀 더 자세히 살펴보면 아래와 같다.

![협력적 리밸런스 과정](/assets/img/dev/2024/0623/rebalance.png)

① **Detection**    
- 컨슈머 그룹 내에 컨슈머 2 가 합류하면서 리밸런싱이 트리거 됨  
- 컨슈머 그룹 내의 컨슈머들은 그룹 합류 요청과 자신들이 컨슘하는 토픽의 파티션 정보(소유권) 를 그룹 코디네이터로 전송  
- 그룹 코디네이터는 해당 정보를 조합하여 컨슈머 그룹의 리더에게 전송  

② **First Rebalancing**  
- 컨슈머 그룹의 리더는 현재 컨슈머들이 소유한 파티션 정보를 활용하여 제외해야 할 파티션 정보를 담은 새로운 파티션 할당 정보를 컨슈머 그룹 멤버들에게 전달  
- 새로운 파티션 할당 정보를 받은 컨슈머 그룹 멤버들은 **필요없는 파티션을 골라서 제외**함  
- 이전의 파티션 할당 정보와 새로운 파티션 할당 정보가 동일한 파티션들에 대해서는 어떤 작업도 수행할 필요가 없음  

③ **Second Rebalancing**  
- 제외된 파티션 할당을 위해 컨슈머들은 다시 합류 요청을 시도함 (여기서 두 번째 리밸런싱이 트리거됨)  
- 컨슈머 그룹의 리더는 제외된 파티션을 적절한 컨슈머에게 할당함

**위 과정을 보면 컨슈머 3 이 새로 합류하였지만 현재 동작하고 있는 컨슈머 1, 2 에게는 아무런 영향을 주고있지 않다.** 

**협력적 리밸런싱은 파티션 재배치가 필요하지 않은 컨슈머는 downtime 없이 계속 동작하며, 두 번의 리밸런싱**이 일어난다.  
비록 리밸런싱 동작이 2 번 발생하지만, 정상 동작하는 다른 컨슈머에게는 아무런 영향을 주지 않는다.

**조급한 리밸런스와 달리 전체가 중단되지 않기 때문에 효율적일 수 있지만 파티션 할당이 안정적인 상태가 될 때까지 몇 번의 반복이 필요**하다.

---

### 1.2.3. 컨슈머에 파티션이 할당되는 방법: `JoinGroup`, `PartitionAssignor`, `GroupCoordinator`

컨슈머가 컨슈머 그룹에 참여하고 싶을 때는 **그룹 코디네이터**에게 `JoinGroup` 요청을 보낸다.  
가장 먼저 참여한 컨슈머가 **그룹 리더**가 된다.

그룹 리더는 그룹 코디네이터로부터 해당 그룹 안에 있는 모든 컨슈머의 목록을 받아서 각 컨슈머에게 파티션의 일부를 할당해준다.  
어느 파티션이 어느 컨슈머에게 할당되어야 하는지를 결정하기 위해서는 `PartitionAssinor` 인터페이스의 구현체가 사용된다.

카프카에는 몇 개의 파티션 할당 정책이 기본적으로 내장되어 있다.  
파티션 할당이 결정되면 커슈머 그룹 리더는 할당 내역을 `GroupCoordinator` 에게 전달하고, 그룹 코네네이터는 다시 이 정보를 모든 컨슈머에게 전파한다.

그룹 리더만 클라이언트 프로세스 중에서 유일하게 그룹 내 컨슈머와 할당 내역 전부를 볼 수 있고, 각 컨슈머 입장에서는 자기에게 할당된 내역만 보인다.

이 과정은 리밸런스가 발생할 때마다 반복적으로 수행된다.

---

## 1.3. 정적 그룹 멤버십 (static group membership): `group.instance.id`, `session.timeout.ms`

기본적으로 컨슈머가 갖는 컨슈머 그룹의 멤버로서의 자격(= 멤버십) 은 일시적이다.

컨슈머가 컨슈머 그룹을 떠나는 순간 해당 컨슈머에 할당되어 있던 파티션들은 해제되고, 다시 참여하면 새로운 멤버 ID 가 발급되면서 리밸런스 프로토콜에 의해 새로운 
파티션들이 할당된다.

하지만 컨슈머가 컨슈머 그룹의 정적인 멤버가 되도록 해주는 고유한 `group.instance.id` 값을 컨슈머에게 부여하면 해당 컨슈머는 정적 그룹 멤버십을 갖게 된다.

컨슈머가 정적 멤버로서 컨슈머 그룹에 처음 참여하면 평소와 같이 해당 그룹이 사용하고 있는 파티션 할당 전략에 따라 파티션이 할당된다.  
하지만 이 컨슈머가 꺼질 경우 자동으로 그룹을 떠나지는 않는다. (세션 타임아웃이 경과될 때까지 여전히 그룹 멤버로 남아있음)  
그리고 컨슈머가 다시 그룹에 조인하면 멤버십이 그대로 유지되기 때문에 리밸런스가 발생할 필요 없이 예전에 할당받았던 파티션들을 그대로 재할당받는다.

그룹 코디네이터는 그룹 내 각 멤버에 대한 파티션 할당을 캐시해두고 있기 때문에 정적 멤버가 다시 조인했을 경우 리밸런스를 발생시키지 않고 캐시되어 있는 파티션 할당을 보내준다.

---

**정적 그룹 멤버십은 애플리케이션이 각 컨슈머에 할당된 파티션의 내용을 사용해서 로컬 상태에 캐시를 유지해야 할 때 편리**하다. (= 캐시를 재생성하지 않으므로)

**반대로 생각하면 각 컨슈머에 할당된 파티션들이 종료되었던 정적 그룹 멤버십의 컨슈머가 재시작한다고 해서 다른 컨슈머로 재할당되지 않는다는 의미**이기도 하다. (= 리밸런싱이 일어나지 않으므로)

일정한 기간 동안 어떤 컨슈머도 이렇게 컨슈머를 잃어버린 파티션들로부터 메시지를 읽어오지 않을 것이기 때문에 정지되었던 정적 그룹 멤버십의 컨슈머가 다시 돌아오면 
이 파티션에 저장된 최신 메시지에서 한참 뒤에 있는 메시지까지 처리하게 된다.  
따라서 이 파티션들은 할당받은 컨슈머가 재시작했을 때 밀린 메시지들을 따라잡을 수 있는지 확인할 필요가 있다.

---

컨슈머 그룹의 정적 멤버는 종료할 때 미리 컨슈머 그룹을 떠나지 않는다.  
정적 멤버가 종료되었음을 알아차리는 것은 [`session.timeout.ms`](#56-sessiontimeoutms-heartbeatintervalms) 설정에 달려있다.

`session.timeout.ms` 는 애플리케이션 재시작이 리밸런스를 작동시키지 않을 만큼 충분히 크면서, 설정된 시간동안 작동이 멈출 경우 자동으로 파티션 재할당이 이루어져서 
오랫동안 파티션 처리가 멈추는 상황을 막을 수 있을만큼 충분히 작은 값으로 설정해야 한다.

---

# 2. 컨슈머 생성

카프카 레코드를 읽어오기 위한 첫 단계는 KafkaConsumer 인스턴스를 생성하는 것이다.  

반드시 설정해야 하는 속성은 3개로 각각 `bootstrap.servers`, `key.deserializer`, `value.deserializer` 이다.

- `bootstrap.servers`
  - 카프카 클러스터로의 연결 문자열
- `key.deserializer`, `value.deserializer`
  - 바이트 배열을 자바 객체로 변환하는 클래스 지정

반드시 지정해야 하는 건 아니지만 매우 일반적으로 사용되는 네 번째 속성이 있는데 그건 바로 **`KafkaConsumer` 인스턴스가 속하는 컨슈머 그룹을 지정하는 [`group.id`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#511-groupid)** 이다.  
어떤 컨슈머 그룹에도 속하지 않는 컨슈머를 생성할 수는 있지만 일반적이지는 않다.

아래는 `KafkaConsumer` 를 생성하는 예시이다.

ConsumerSample.java
```java
package com.assu.study.chap04;

import java.util.Properties;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

public class ConsumerSample {
  // 컨슈머 생성 예시
  public void simpleConsumer() {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CountryCounter");

    KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
  }
}
```

---

# 3. 토픽 구독: `subscribe()`

컨슈머를 생성하고 나서 할 일은 1개 이상의 토픽을 구독하는 것이다.

`subscribe()` 메서드는 토픽 목록을 매개변수로 받는다.

```java
// 하나의 토픽 이름만으로 목록 생성
consumer.subscribe(Collections.singletonList("customerCountries"));
```

정규식을 매개변수로 사용하는 것도 가능하다.

정규식은 다수의 토픽 이름에 매치될 수 있으며, 정규식과 매치되는 이름을 가진 새로운 토픽이 생성될 경우, 거의 즉시 리밸런스가 발생하면서 컨슈머들은 새로운 토픽으로부터 
읽기 작업을 시작하게 된다.

**정규식을 매개변수로 사용하는 것은 다수의 토픽에서 레코드를 읽어와서 토픽이 포함하는 서로 다른 유형의 데이터를 처리해야 하는 애플리케이션의 경우 편리**하다.

**정규식을 사용하여 다수의 토픽을 구독하는 것은 카프카와 다른 시스템 사이의 데이터를 복제하는 애플리케이션이나 스트림 처리 애플리케이션에서 매우 흔하게 사용**된다.

아래는 모든 테스트 토픽을 구독하는 예시이다.
```java
// test 가 들어간 모든 토픽 구독
consumer.subscribe(Pattern.compile("test.*"));
```

---

## 3.1. 정규식으로 토픽 구독 시 주의점: `Describe`

구독할 토픽을 필터링하는 작업은 클라이언트쪽에서 이루어지게 되므로 카프카 클러스터에 파티션이 매우 많다면 (3만개 이상이라든지) 주의해야 한다.

만일 **전체 토픽의 일부를 구독할 때 명시적으로 목록을 지정하는 것이 아니라 정규식으로 지정할 경우 컨슈머는 전체 토픽과 파티션에 대한 정보를 브로커에 일정한 간격으로 요청**하게 된다.  
클라이언트는 이 목록을 구독할 새로운 토픽을 찾는데 사용한다.

이는 정규식을 이용하여 토픽을 구독하려면 클라이언트는 클러스터 안에 있는 모든 토픽에 대한 상세 정보를 조회할 권한이 있어야 한다는 의미이기도 하다.  
즉, 전체 클러스터에 대한 완전한 `Describe` 작업 권한이 부여되어야 한다.

> 작업 권한에 대한 내용은 [2. 인가(Authorization): `authorizer.class.name`](https://assu10.github.io/dev/2024/09/14/kafka-security-2/#2-%EC%9D%B8%EA%B0%80authorization-authorizerclassname) 를 참고하세요.

만일 **토픽의 목록이 굉장히 크고, 컨슈머도 굉장히 많고, 토픽과 파티션의 목록도 굉장히 크면 정규식을 사용한 구독은 브로커, 클라이언트, 네트워크 전체에 걸쳐서 상당한 오버헤드를 발생**시킨다.  
데이터를 주고받는 데 사용하는 네트워크 대역폭보다 토픽 메타데이터를 주고받는데 사용되는 대역폭 크기가 더 큰 경우도 있다.

---

# 4. 폴링 루프: `poll()`

컨슈머 API 의 핵심은 **서버에 추가 데이터가 들어왔는지 폴링하는 단순한 루프**이다.

PollingLoop.java
```java
package com.assu.study.chap04.polling;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.boot.configurationprocessor.json.JSONObject;

@Slf4j
public class PollingLoop {
  static Map<String, Integer> custCountryMap = new HashMap<>();

  static {
    custCountryMap.put("assu", 1);
    custCountryMap.put("silby", 1);
  }

  public void polling() {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {

      // timeout 은 100ms
      Duration timeout = Duration.ofMillis(100);

      // 컨슈머 애플리케이션은 보통 게속해서 카프카에 추가 데이터를 폴링함
      // (나중에 이 무한루프를 탈출하여 컨슈머를 깔끔하게 닫는 법에 대해 알아볼 예정)
      while (true) {
        // 컨슈머가 카프카를 계속해서 폴링하지 않으면 죽은 것으로 간주되어 이 컨슈머가 읽어오고 있던 파티션들은
        // 처리를 계속 하기 위해 그룹 내의 다른 컨슈머에게 넘김
        // poll() 에 전달하는 timeout 은 컨슈머 버퍼에 데이터가 없을 경우 poll() 이 블록될 수 있는 최대 시간임
        // 만일 timeout 이 0 으로 지정되거나, 버퍼 안에 이미 레코드가 준비되어 있을 경우 poll() 은 즉시 리턴됨
        // 그게 아니면 지정된 ms 만큼 기다림
        ConsumerRecords<String, String> records = consumer.poll(timeout);

        // poll() 은 레코드들이 저장된 List 반환
        // 각 레코드들에는 토픽, 파티션, 파티션에서의 오프셋, 키, 밸류값이 들어가있음
        for (ConsumerRecord<String, String> record : records) {
          log.info(
                  "topic: {}, partition: {}, offset: {}, customer: {}, country: {}",
                  record.topic(),
                  record.partition(),
                  record.offset(),
                  record.key(),
                  record.value());

          int updatedCount = 1;
          if (custCountryMap.containsKey(record.value())) {
            updatedCount = custCountryMap.get(record.value()) + 1;
          }
          custCountryMap.put(record.value(), updatedCount);

          // 처리가 끝나면 결과물을 데이터 저장소에 쓰거나, 이미 저장된 레코드 갱신
          JSONObject json = new JSONObject(custCountryMap);
          log.info("json: {}", json);
        }
      }
    }
  }
}
```

> 위 코드는 무한루프에서 폴링을 하고 있는데 무한루프를 탈출하여 컨슈머를 깔끔하게 닫는 법에 대해서는 [1. 폴링 루프 벗어나기: `consumer.wakeup()`, `ShutdownHook`](https://assu10.github.io/dev/2024/06/30/kafka-consumer-3/#1-%ED%8F%B4%EB%A7%81-%EB%A3%A8%ED%94%84-%EB%B2%97%EC%96%B4%EB%82%98%EA%B8%B0-consumerwakeup-shutdownhook) 를 참고하세요.

위 코드에서 폴링 루프는 단순히 데이터를 가져오는 것보다 훨씬 많은 일을 한다.
- 새로운 컨슈머에서 처음으로 `poll()` 을 호출하면 컨슈머는 `GroupCoordinator` 를 찾아서 컨슈머 그룹에 참가한 후 파티션을 할당받음
- 리밸런스 역시 연관된 콜백들과 함께 이 때 처리됨
- 즉, 컨슈머 혹은 콜백에서 에러가 나면 모든 것들은 `poll()` 에서 예외 형태로 발생됨

**`poll()` 이 [`max.poll.interval.ms`](#57-maxpollintervalms) 에 지정된 시간 이상으로 호출되지 않으면 컨슈머는 죽은 것으로 판정되어 컨슈머 그룹에서 퇴출**된다.

**따라서 폴링 루프 안에서 예측 불가능한 시간동안 블록되는 작업을 수행하는 것은 피해야 한다.**

> [`default.api.timeout.ms`](#58-defaultapitimeoutms) 과 함께 보면 도움이 됩니다.

---

## 4.1. 스레드 안전성

**하나의 스레드 당 하나의 컨슈머**가 돌아간다.

하나의 스레드에서 동일한 그룹 내의 여러 개의 컨슈머를 생성할 수는 없으며, 같은 컨슈머를 다수의 스레드가 안전하게 사용할 수도 없다.

하나의 애플리케이션에서 동일한 그룹에 속하는 여러 개의 컨슈머를 운영하고 싶다면 스레드를 여러 개 띄워서 각각의 컨슈머를 하나씩 돌리는 수밖에 없다.

**스레드 하나 당 하나의 컨슈머가 돌아가게 하는 방법**은 2가지가 있다.
- **컨슈머 로직을 자체적인 객체로 감싼 후 자바의 `ExcecutorService` 를 이용하여 각자의 컨슈머를 가지는 다수의 스레드 시작**
  - > 해당 예시는 [Introducing the Kafka Consumer: Getting Started with the New Apache Kafka 0.9 Consumer Client](https://www.confluent.io/blog/tutorial-getting-started-with-the-new-apache-kafka-0-9-consumer-client/) 를 참고하세요.
- **이벤트를 받아서 큐에 넣는 컨슈머 하나와, 이 큐에서 이벤트를 꺼내서 처리하는 여러 개의 워커 스레드 (Worker thread) 사용**

---

### 4.1.1.컨슈머에서 레코드를 읽지 않고 메타데이터만 받아야 하는 경우 해결법

- 할당받은 파티션에 대한 메타데이터를 받은 뒤, 레코드를 읽어오기 전에 호출되는 `rebalanceListener.onPartitionAssignment()` 메서드에 로직 위치
- while 루프 안에서 짧은 시간동안 폴링한 후 `poll()` 의 크기를 확인
  - > 해당 예시는 [Kafka’s Got a Brand-New Poll](https://www.jesse-anderson.com/2020/09/kafkas-got-a-brand-new-poll/) 를 참고하세요.

---

# 5. 컨슈머 설정

카프카의 필수 속성인 `bootsrap.servers`, `key.deserializer`, `value.deserializer`, 그리고 자주 사용되는 `group.id` 에 대해서는 위에서 보았다.

대부분의 매개 변수는 합리적인 기본값을 갖고 있으므로 딱히 변경할 필요는 없지만, 몇몇 매개변수는 컨슈머의 성능과 가용성에 영향을 준다.

여기선 상대적으로 중요한 속성들에 대해 알아본다.

---

## 5.1. `fetch.min.bytes`

**`fetch.min.bytes` 는 컨슈머가 브로커로부터 레코드를 받아올 때 받는 데이터의 최소량 (byte 단위)**이다.

기본값은 1byte 이다.

만일 브로커가 컨슈머로부터 레코드 요청을 받았는데 새로 보낼 레코드의 양이 `fetch.min.bytes` 보다 작으면 브로커는 충분한 메시지를 보낼 수 있을 때까지 기다린 후 
컨슈머에게 레코드를 보낸다.

**`fetch.min.bytes` 는 토픽에 새로운 메시지가 많이 들어오지 않거나 쓰기 요청이 적은 시간대와 같은 상황일 때 오가는 메시지 수를 줄임으로써 컨슈머와 브로커 양쪽에 대해 
부하를 줄여준다.**

읽어올 데이터가 그리 많지 않은 상황에서 컨슈머가 CPU 자원을 너무 많이 사용하고 있거나, 컨슈머 수가 많을 때 브로커의 부하를 줄여야 할 경우 `fetch.min.bytes` 를 
기본값보다 올려주는 게 좋다.

하지만, `fetch.min.bytes` 을 올려잡아 줄 경우 처리량이 적은 상황에서 지연도 증가한다.

---

## 5.2. `fetch.max.wait.ms`

**`fetch.max.wait.ms` 는 카프카가 컨슈머에게 응답하기 전 대기하는 최대 시간**이다.

기본값은 500ms 이다.

카프카는 토픽에 컨슈머에게 리턴할 데이터가 부족할 경우 리턴할 데이터를 최소량 조건에 맞추기 위해 500ms 까지 기다린다.

지연을 제한하고 싶다면 `fetch.max.wait.ms` 를 작게 잡아주면 된다.

만일 `fetch.max.wait.ms` 가 100ms, `fetch.min.bytes` 가 1MB 일 경우 카프카는 컨슈머로부터 읽기 (= fetch) 요청을 받았을 때 리턴할 데이터가 
1MB 이상 모이거나 100ms 가 지나거나, 둘 중 하나가 만족하면 리턴하게 된다.

---

## 5.3. `fetch.max.bytes`

**`fetch.max.bytes` 는 컨슈머가 브로커를 폴링할 때 카프카카 리턴하는 최대 바이트 수**이다.

기본값은 50MB 이다.

**`fetch.max.bytes` 는 컨슈머가 서버로부터 받은 데이터를 저장하기 위해 사용하는 메모리 양을 제한하기 위해 사용**된다.  
(이 때 얼마나 많은 파티션으로부터 얼마나 많은 메시지를 받았는지와는 무관함)

브로커가 컨슈머에 레코드를 보낼때는 배치 단위로 보내며, 만일 브로커가 보내야 하는 첫 번째 레코드 배치의 크기가 `fetch.max.bytes` 를 넘기면 `fetch.max.bytes` 의 
제한값을 무시하고 해당 배치를 그대로 전송한다. (= `fetch.max.bytes` 에 설정된 bytes 만큼 잘라서 보내는 게 아님)  
이것은 컨슈머가 읽기 작업을 계속해서 진행할 수 있도록 보장해준다.

브로커 설정에도 최대 읽기를 제한할 수 있는 [`message.max.bytes`](https://assu10.github.io/dev/2024/06/15/kafka-install/#3210-messagemaxbytes) 설정이 있다.

대량의 데이터 요청은 대량의 디스크 읽기와 오랜 네트워크 전송 시간을 초래하여 브로커 부하를 증가시킬 수 있기 때문에 이를 막기 위해선 브로커 설정을 사용할 수 있다.

---

## 5.4. `max.poll.records`

**`poll()` 을 호출할 때마다 리턴되는 최대 레코드 개수**이다.

폴링 루프를 반복할 때마다 처리해야 하는 레코드의 개수를 제어할 때 사용한다.

---

## 5.5. `max.partition.fetch.bytes`

**`max.partition.fetch.bytes` 는 서버가 파티션별로 처리하는 최대 바이트 수**이다.

기본값은 1MB 이다.

`KafkaConfumser.poll()` 이 `ConsumerRecords` 를 리턴할 때 메모리상에 저장된 레코드 객체의 크기는 컨슈머에 할당된 파티션 별로 
최대 `max.partition.fetch.bytes` 까지 차지할 수 있다.

**브로커가 보내온 응답에 얼마나 많은 파티션이 포함되어 있는지 알 수 없기 때문에 `max.partition.fetch.bytes` 를 사용하여 메모리 사용량을 조절하는 것 보다는 
각 파티션에서 비슷한 양의 데이터를 받아 처리해야 하는 것처럼 특별한 이유가 아니라면 [`fetch.max.bytes`](#53-fetchmaxbytes) 설정을 대신 사용할 것을 강력히 권장**한다.

---

## 5.6. `session.timeout.ms`, `heartbeat.interval.ms`

컨슈머가 브로커와 신호를 주고 받지 않고도 살아있는 것으로 판정되는 최대 시간인 `session.timeout.ms` 의 기본값은 45s 이다.

- **`session.timeout.ms`**
  - **컨슈머가 그룹 코디네이터에게 하트비트를 보내지 않은 채로 `session.timeout.ms` 가 지나면 그룹 코디네이터는 해당 컨슈머를 죽은 것으로 간주하여, 죽은 컨슈머에게 
  할당되어 있던 파티션들을 다른 컨슈머에게 할당해주기 위해 리밸런스 실행**
- **`heartbeat.interval.ms`**
  - **카프카 컨슈머가 그룹 코디네이터에게 하트비트를 보내는 주기**

`session.timeout.ms` 는 컨슈머가 하트비트를 보내지 않을 수 있는 최대 시간을 결정하기 때문에 `session.timeout.ms` 와 `heartbeat.interval.ms` 는 
보통 함께 변경된다.

`heartbeat.interval.ms` 는 `session.timeout.ms` 보다 더 낮은 값이어야 하고, 보통 1/3 의 값으로 설정한다.  
예) `session.timeout.ms` 가 3초라면 `heartbeat.interval.ms` 는 1초로 설정

- **`session.timeout.ms` 를 낮게 잡을 경우**
  - 컨슈머 그룹이 죽은 컨슈머를 좀 더 빨리찾아내고 회복할 수 있도록 해주지만 그만큼 원치않은 리밸런싱을 초래할 수 있음
- **`session.timeout.ms` 를 높게 잡을 경우**
  - 사고로 인한 리밸런스 가능성을 줄일 수 있지만, 실제로 죽은 컨슈머를 찾아내는 데 시간이 더 걸림

> **카프카 컨슈머의 `session.timeout.ms` 기본값 변경 히스토리**  
> 
> 카프카 3.0 버전 이전에는 `session.timeout.ms` 의 기본값은 10초였지만, 3.0 버전 이후부터는 45s 로 변경됨
> 
> `session.timeout.ms` 의 기본값이었던 10s 는 카프카가 처음 개발되던 [온프레미스](https://assu10.github.io/dev/2021/05/19/infra-basic/#1-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B8%B0%EC%B4%88-%EC%A7%80%EC%8B%9D) 데이터 센터를 
> 기준으로 정해진 것이기 때문에 순간적인 부하 집중과 네트워크 불안정이 일상인 클라우드 환경에서는 적철치 않음  
> 즉, 별것도 아닌 순간적인 네트워크 문제로 인해 리밸런스가 발생하고, 컨슈머 작동이 정지될 수 있었음
> 
> 10s 는 심지어 아래 나올 [`request.timeout.ms`](#59-requesttimeoutms) 의 기본값인 30s 와도 잘 맞지 않음  
> 세션 타임아웃이 만료되어 이미 그룹에서 죽은 것으로 간주되었음에도 불구하고 계속해서 응답을 기다리는 상황이 발생할 수 있기 때문임
> 
> 이에 대한 자세한 내용은 [KIP-735: Increase default consumer session timeout](https://cwiki.apache.org/confluence/display/KAFKA/KIP-735:+Increase+default+consumer+session+timeout) 을 참고하세요.

---

## 5.7. `max.poll.interval.ms`

**`max.poll.interval.ms` 는 컨슈머가 폴링을 하지 않고도 죽은 것으로 판정되지 않을 수 있는 최대 시간**이다.

기본값은 5분 (300,000ms)이다.

컨슈머의 폴링 주기가 `max.poll.interval.ms` 를 초과하면 리밸런스가 발생한다.

**하트비트와 세션 타임아웃은 카프카가 죽은 컨슈머를 찾아내고 할당된 파티션을 해제할 수 있게 해주는 주된 메커니즘**이다.

하지만 [1.2.2. 협력적 리밸런스 (cooperative rebalance) 혹은 점진적 리밸런스 (incremental rebalance)](#122-협력적-리밸런스-cooperative-rebalance-혹은-점진적-리밸런스-incremental-rebalance) 에서 보았듯이 하트비트는 
백그라운드 스레드에 의해서 전송된다.  
**카프카에서 레코드를 읽어오는 메인 스레드는 데드락이 걸렸는데 백그라운드 스레드는 멀쩡히 하트비트를 전송하고 있을수도 있다.**  
**이는 컨슈머에 할당된 파티션의 레코들들이 처리되고 있지 않음을 의미**한다.

컨슈머가 여전히 레코드를 처리하고 있는지의 여부를 확인하는 가장 쉬운 방법은 컨슈머가 추가로 메시지를 요청하는지 확인하는 것이지만 이는 요청 사이의 간격이나 
추가 레코드 요청은 예측하기 힘들 뿐더러 현재 사용 가능한 데이터의 양, 컨슈머가 처리하고 있는 작업의 유형, 때로는 함께 사용되는 서비스의 지연에도 영향을 받는다.

리턴된 레코드 각각에 대해 시간이 오래 걸리는 처리를 해야하는 애플리케이션의 경우 리턴되는 데이터의 양을 제한하기 위해 [`max.poll.records`](#54-maxpollrecords) 를 사용할 수 있으며, 
자연히 `poll()` 을 재호출할 수 있을 때까지 걸리는 시간 역시 제한할 수 있다.

**하지만 `max.poll.records` 를 정의했다 할지라도 `poll()` 을 호출하는 시간 간격은 예측하기 어렵기 때문에 그에 대한 안전 장치로 `max.poll.interval.ms` 가 사용**된다.

`max.poll.interval.ms` 는 정상 작동 중인 컨슈머가 매우 드물게 도달할 수 있도록 충분히 크게, 하지만 정지한 컨슈머로 인한 영향이 뚜렷이 보이지 않을만큼 
충분히 작게 설정해야 한다.

`max.poll.interval.ms` 의 타이마웃이 발생하면 백그라운드 스레드는 브로커로 하여금 컨슈머가 죽어서 리밸런스가 수행되어야 한다는 것을 알 수 있도록 
'leave group' 요청을 보낸 뒤 하트비트 전송을 중단한다.

---

## 5.8. `default.api.timeout.ms`

**`default.api.timeout.ms` 은 명시적으로 타임아웃을 지정하지 않는 한 거의 모든 컨슈머 API 호출에 적용되는 타임아웃 값**이다.

기본값은 1분이다.

`default.api.timeout.ms`이 `request.timeout.ms` 보다 크므로 필요한 경우 `request.timeout.ms` 안에 재시도를 할 수 있다.

`default.api.timeout.ms` 이 적용되지 않은 중요한 예외로는 `poll()` 메서드가 있다.  
**`poll()` 메서드는 호출할 때 언제나 명시적으로 타임아웃을 지정**해줘야 한다.

---

## 5.9. `request.timeout.ms`

**`request.timeout.ms` 는 컨슈머가 브로커로부터 응답을 기다릴 수 있는 최대 시간**이다.

기본값은 30s 이다.

브로커가 `request.timeout.ms` 에 설정된 시간 안에 응답하지 않을 경우 클라이언트는 브로커가 완전히 응답하지 않을 것으로 간주하여 연결을 닫은 뒤 재연결을 시도한다.

**`request.timeout.ms` 의 기본값인 30s 보다 더 내리지 않는 것을 권장**한다.

연결을 끊기 전 브로커에 요청을 처리할 시간을 충분히 주는 것이 중요하다.  
**즉, 이미 과부하에 걸려있는 브로커는 요청을 다시 보낸다고 얻을 게 거의 없을 뿐더러, 연결을 끊고 다시 맺는 것은 더 큰 오버헤드만 추가**한다.

---

## 5.10. `auto.offset.reset`

**`auto.offset.reset` 은 컨슈머가 예전에 오프셋을 커밋한 적이 없거나, 커밋된 오프셋이 유효하지 않거나(컨슈머가 브로커에 없는 오프셋 요청), 파티션을 읽기 시작할 때 컨슈머가 해야할 동작을 정의**한다.

커밋된 오프셋이 유효하지 않은 경우는 보통 컨슈머가 오랫동안 읽은 적이 없어서 오프셋의 레코드가 이미 브로커에서 삭제된 경우이다.

기본값은 `latest` 이다.  

- `latest`
  - 유효한 오프셋이 없을 경우 컨슈머는 가장 최신 레코드(= 컨슈머가 작동하기 시작한 다음부터 쓰여진 레코드)부터 읽기 시작함
  - 중복 처리는 최소화하지만, 컨슈머가 일부 메시지는 누락할 것이 거의 확실함
- `earliest`
  - 유효한 오프셋이 없을 경우 파티션의 맨 처음부터 모든 데이터를 읽음
  - 컨슈머는 많은 메시지들을 중복 처리하게 될 수 있지만, 데이터 유실은 최소화할 수 있음
- `none`
  - 유효하지 않은 오프셋부터 읽으려 할 경우 예외 발생

---

## 5.11. `enable.auto.commit`

**`enable.auto.commit` 은 컨슈머가 자동으로 오프셋을 커밋할 지 여부를 결정**한다.

기본값은 true 이다.

자동 오프셋 커밋의 장점은 [폴링 루프](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#4-%ED%8F%B4%EB%A7%81-%EB%A3%A8%ED%94%84-poll)에서 읽어온 모든 레코드에 대한 처리를 하는 와중에도 처리하지 
않은 오프셋을 실수로 커밋하는 상황이 벌어지지 않도록 보장해준다.

자동 오프셋 커밋의 단점은 메시지 중복 처리를 개발자가 제어할 수 없다는 점이다.  
읽어온 메시지 중 일부만을 처리했고 아직 자동 커밋이 되지 않은 상태에서 컨슈머가 멈추면, 컨슈머를 재시작했을 때 메시지 중복 처리를 피할 수 없다.

애플리케이션이 백그라운드에서 처리를 수행하기 위해 다슨 스레드에 레코드를 넘기는 것과 같이 더 복잡한 처리를 해야하는 경우, 직접 오프셋을 커밋해주는 것 외에는 선택지가 없다.  
자동 커밋 기능이 컨슈머가 읽어오기는 했지만 아직 처리하지 않은 오프셋을 커밋할 수도 있기 때문이다.

따라서 언제 오프셋을 커밋할 지 직접 결정하고 싶다면 false 로 설정하면 한다.  
**중복을 최소화하고 유실되는 데이터를 방지하려면 false 로 설정**해야 한다.

true 로 설정 시 [`auto.commit.interval.ms`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#514-autocommitintervalms) 를 사용하여 얼마나 자주 오프셋이 커밋될지 제어할 수 있다.

> [1.1. 자동 커밋: `enable.auto.commit`](https://assu10.github.io/dev/2024/06/29/kafka-consumer-2/#11-%EC%9E%90%EB%8F%99-%EC%BB%A4%EB%B0%8B-enableautocommit) 과 함께 보면 도움이 됩니다.

> [1.2. 현재 오프셋 커밋: `commitSync()`](https://assu10.github.io/dev/2024/06/29/kafka-consumer-2/#12-%ED%98%84%EC%9E%AC-%EC%98%A4%ED%94%84%EC%85%8B-%EC%BB%A4%EB%B0%8B-commitsync) 과 함께 보면 도움이 됩니다.

---

## 5.12. `partition.assignment.strategy`: `PartitionAssinor`

컨슈머 그룹에 속한 컨슈머들에게는 파티션이 할당된다.

**파티션 할당 전략은 카프카 컨슈머가 구독하는 대상 토픽 중 어느 파티션의 레코드를 읽을 지 결정하는 방식**이다.  
컨슈머 그룹에 설정된 파티션 전략에 따라 컨슈머-파티션 간의 매칭이 결정된다.  
즉, **리밸런싱 시 발생하는 모든 동작은 컨슈더(리더)가 관장**한다.

**`PartitionAssinor` 클래스는 컨슈머에게 이들이 구독한 토픽들이 주어졌을 때 어느 컨슈머에게 어떤 파티션을 할당될 지 결정하는 역할**을 한다.

`partition.assignment.strategy` 을 통해 파티션 할당 전략을 선택할 수 있으며 카프카 2.4 부터 기본값은 `org.apache.kafka.clients.consumer.CooperativeStickyAssinor` 이다.  
직접 할당 전략을 구현할 경우엔 `partition.assignment.strategy` 이 해당 클래스를 가리키게 하면 된다.

카프카는 아래와 같은 파티션 할당 전략을 지원한다.
- `Range`
- `RoundRobin`
- `Sticky`
- `Cooperative Sticky`

위 파티션들의 할당 전략을 설명하기 앞서 중요 부분만 정리하면 아래와 같다.

|      파티션 할당 전략      | 설명                                                |  리밸런싱 프로토콜  |
|:-------------------:|:--------------------------------------------------|:-----------:|
|       `Range`       | 토픽별로 동일한 파티션을 특정 컨슈머에게 할당                         |    eager    |
|    `RoundRobin`     | 사용 가능한 파티션과 컨슈머를 순차적으로 할당                         |    eager    |
|      `Sticky`       | 컨슈머가 구독중인 파티션을 계속 유지하게끔 할당                        |    eager    |
| `Cooperative Sticky` | `Sticky` 와 유사하지만 전체 리밸런싱이 아닌 필요한 파티션끼리 점진적으로 리밸런싱 | cooperative |

---

### 5.12.1. `Range` 파티션 할당 전략

**컨슈머가 구독하는 각 토픽의 파티션들을 연속된 그룹으로 나눠서 할당**한다.

만일 컨슈머 C1, C2 가 각각 3개의 파티션을 갖는 토픽 T1, T2 를 구독할 경우 파티션 할당은 아래와 같이 이루어진다.

![Range 파티션 할당 전략](/assets/img/dev/2024/0623/range.png)

- 구독 중인 토픽의 파티션과 컨슈머를 순서대로 나열
- 각 컨슈머가 받아야 할 파티션 수를 결정하는데, 이는 해당 토픽의 전체 파티션 수를 컨슈머 그룹의 총 컨슈머 수로 나눈 값임
- 컨슈머 수와 파티션 수가 정확히 일치하면 모든 컨슈머는 파티션을 균등하게 할당받음
- 컨슈머 수와 파티션 수가 균등하게 나눠지지 않으면 앞 순서의 컨슈머들이 추가로 파티션을 할당받음

각 토픽은 홀수 개의 파티션을 갖고 있고, 각 토픽의 할당이 독립적으로 이루어지기 때문에 첫 번째 컨슈머는 두 번째 컨슈머보다 더 많은 파티션을 할당받게 된다.

각 토픽의 파티션 수가 컨슈머 수로 깔끔하게 나누어떨어지지 않는 상황에서 `Range` 파티션 할당 전략이 사용될 경우 언제든지 발생할 수 있는 상황이다.

<**`Range` 파티션 할당의 장점**>  
- 특정 도메인에 대한 데이터 처리를 한 컨슈머에서 일관되게 처리할 수 있음
  - 예) 정상 로그와 에러 로그를 각각 처리하는 2개의 토픽이 있다고 하자.  
  두 토픽의 파티션 수가 같을 때 로그 프로듀서가 동일한 key 를 사용하면 메시지는 동일한 파티션(파티션 0)으로 전송됨  
  두 토픽의 파티션 0 은 모두 컨슈머 1에서 처리되기 때문에 일관된 데이터 처리/관리가 가능함

<**`Range` 파티션 할당의 단점**>  
- 컨슈머의 파티션 할당이 불균형하기 때문에 특정 컨슈머에 부하가 몰릴 수 있음
- [조급한 리밸런싱](#121-조급한-리밸런스-eager-rebalance)으로 동작하므로 리밸런싱 발생 시 모든 컨슈머가 작업을 중단하게 됨

---

### 5.12.2. `RoundRobin` 파티션 할당 전략

**모든 구독된 토픽의 모든 파티션을 순차적으로 하나씩 컨슈머에게 할당**한다.

![RoundRobin 파티션 할당 전략](/assets/img/dev/2024/0623/roundrobin.png)

일반적으로 컨슈머 그룹 내 모든 컨슈머들이 동일한 토픽들을 구독한다면 (실제로도 보통 그렇다) `RoundRobin` 파티션 할당 전략을 선택할 경우 모든 컨슈머들이 
완전히 동일한 수 (혹은 많아야 1개 차이) 의 파티션을 할당받게 된다.

<**`RoundRobin` 파티션 할당의 장점**>  
- 모든 컨슈머에 균등한 파티션 분배가 이루어지기 때문에 컨슈머를 효과적으로 활용하여 성능 향상 가능

<**`RoundRobin` 파티션 할당의 단점**>
- [조급한 리밸런싱](#121-조급한-리밸런스-eager-rebalance)으로 동작하므로 리밸런싱 발생 시 모든 컨슈머가 작업을 중단하게 됨
- 모든 파티션을 균등하게 분배하려 하기 때문에 하나의 컨슈머만 다운되더라도 모든 컨슈머의 리밸런싱이 발생함

---

### 5.12.3. `Sticky` 파티션 할당 전략

`Range` 파티션 할당 전략과 `RoundRobin` 파티션 할당 전략은 조급한 리밸런싱으로 동작하므로 리밸런싱 발생 시 기존 매핑 정보와 전혀 다른 매핑이 이루어진다.  
**`Stikcy` 파티션 할당 전략은 리밸런싱이 발생하더라도 기존 매핑 정보를 최대한 유지하는 컨슈머-파티션 할당 전략**이다.

`Sticky` 할당자의 목표는 2개이다.
- 파티션들을 가능한 균등하게 할당
- 리밸런스가 발생했을 때 가능하면 기존의 할당된 파티션 정보를 보장하여 할당된 파티션을 하나의 컨슈머에서 다른 컨슈머로 옮길 때 발생하는 오버헤드를 최소화

이 중 **첫 번째 목적의 우선순위**가 더 높기 때문에 `Stikcy` 할당 전략이라고 해서 **항상** 기존 파티션과 컨슈머 매핑을 보장하는 것은 아니다.

> `Sticky` 에 대한 설명은 [2.1. 키 값이 없는 상태에서 기본 파티셔너 이용](https://assu10.github.io/dev/2024/06/16/kafka-producer-2/#21-%ED%82%A4-%EA%B0%92%EC%9D%B4-%EC%97%86%EB%8A%94-%EC%83%81%ED%83%9C%EC%97%90%EC%84%9C-%EA%B8%B0%EB%B3%B8-%ED%8C%8C%ED%8B%B0%EC%85%94%EB%84%88-%EC%9D%B4%EC%9A%A9) 
> 과 함께 보면 도움이 됩니다.

컨슈머들이 모두 동일한 토픽을 구독하는 일반적인 상황에서 `Sticky` 할당자를 사용하여 처음으로 할당된 결과물은 얼마나 균형이 잡혀 있는가의 측면에서는 
`RoundRobin` 할당자를 사용하는 것과 그리 다르지 않다.

**하지만 이동하는 파티션 측면에서는 `Sticky` 쪽이 더 적다.**

**`Sticky` 파티션 할당 전략이 이상적으로 동작하는 이유는 아래의 규칙에 따라 재할당 동작을 수행**하기 때문이다.
- 컨슈머 간 최대 할당된 파티션 수의 차이는 1개
- 기존에 존재하는 파티션 할당은 최대한 유지
- 재할당 동작 시 휴요하지 않은 모든 파티션 할당은 제거
- 할당되지 않은 파티션들은 균현을 맞추는 방법으로 컨슈머들에게 할당

![Sticky 파티션 할당 전략](/assets/img/dev/2024/0623/sticky.png)

위 그림은 `Sticky` 파티션 할당 전략의 과정이다.
- 컨슈머 2 에 장애가 생겨 컨슈머 그룹에서 이탈하면 리밸런싱이 발생함
- 정상 동작하는 나머지 2개의 컨슈머의 매핑은 최대한 유지한 채 매핑이 해제된 파티션만 재할당됨  
  (`RoundRobin` 파티션 할당 전략에서는 정상 동작하는 나머지 2개의 컨슈머도 리밸런싱에 동참하게 되어 기존 파티션 매핑이 모두 해제된 후 재할당됨)

같은 그룹에 속한 컨슈머들이 서로 다른 토픽을 구독할 경우 `Sticky` 할당자를 사용한 할당이 `RoundRobin` 할당자를 사용한 것보다 더 균형잡히게 된다.

하지만 [조급한 리밸런싱](#121-조급한-리밸런스-eager-rebalance)으로 동작하기 때문에 리밸런싱 발생 시 Stop the world 현상이 발생한다.

---

### 5.12.4. `Cooperative Sticky` (협력적 Sticky) 파티션 할당 전략

> 카프카 버전 2.4 부터 디폴트 파티션 할당 전략이 됨  
> 
> 카프카 버전 2.3 버전 이하의 버전에서 업그레이드를 하고 있다면 `Cooperative Sticky` 할당 전략을 활성화하기 위해 특정한 업그레이드 순서를 따라야 함  
> 이에 대한 부분은 [카프카 2.3 → 2.4 업그레이드 가이드](https://kafka.apache.org/documentation/#upgrade_240_notable) 를 참고하세요.

`Sticky` 파티션 할당 전략과 결과적으로 동일하지만 컨슈머가 재할당되지 않은 파티션으로부터 레코드를 계속해서 읽어올 수 있도록 해주는 [협력적 리밸런스 기능](#122-협력적-리밸런스-cooperative-rebalance-혹은-점진적-리밸런스-incremental-rebalance)을 지원한다.

위 개의 파티션 전략은 내부적으로 [조급한 리밸런싱](#121-조급한-리밸런스-eager-rebalance)으로 동작하기 때문에 리밸런싱 발생 시 모든 컨슈머는 메시지를 구독할 수 없는 
**Stop the world 현상**이 발생한다.

이와 달리 `Cooperative Sticky` 파티션 전략은 [협력적 리밸런스 기능](#122-협력적-리밸런스-cooperative-rebalance-혹은-점진적-리밸런스-incremental-rebalance) 을 사용하여 
리밸런싱이 필요한 특정 파티션에만 집중하며, 그 외의 나머지 파티션들은 컨슈머와 매핑을 그대로 유지한다.  
문제가 있는 파티션의 메시지 컨슈밍만 중단될 뿐 이 외의 파티션은 모두 정상적으로 메시지 컨슈밍이 동작하기 때문에 전체적인 데이터 처리 성능을 크게 저하하지 않는다.

![협력적 리밸런스 과정](/assets/img/dev/2024/0623/rebalance.png)

이와 같은 특징 때문에 **`Cooperative Sticky` 파티션 할당 전략은 컨슈머 그룹의 구성 변경이 자주 발생하는 환경에 특히 유용하며, 효율적인 리밸런싱을 수행**할 수 있다.

---

## 5.13. `client.id`

`client.id` 는 어떠한 문자열도 될 수 있으며, **브로커가 요청 (읽기 요청 등) 을 보낸 클라이언트를 식별**하기 위해 쓰인다.  
로깅, 모니터링 지표 (metrics), 쿼터에서도 사용된다.

---

## 5.14. `client.rack`, `replica.selector.class`

> 카프카 버전 2.4 부터 지원되는 기능임

기본적으로 컨슈머는 각 파티션의 리더 레플리카로부터 메시지를 읽어온다.

하지만 클러스터가 다수의 데이터 센터 혹은 다수의 클라우드 가용 영역 (AZ, Availability Zone) 에 걸쳐서 설치되어 있는 경우 컨슈머와 같은 영역에 있는 
레플리카로부터 메시지를 읽어오는 것이 성능, 비용면에서 유리하다.

가장 가까운 레플리카로부터 읽어올 수 있도록 `client.rack` 설정을 잡아주어 클라이언트가 위치한 영역을 식별할 수 있게 해주면 된다.  
그리고 나서 `replica.selector.class` 설정 기본값을 `org.apache.kafka.common.replica.RackAwareReplicaSelector` 로 잡아주면 된다.

클라이언트 메타데이터와 파티션 메타데이터를 활용하여 읽기 작업에 사용할 최적의 레플리카를 선택하는 커스텀 로직을 직접 구현하여 넣을 수도 있다.  
읽어올 레플리카를 선택하는 로직을 직접 구현하고 싶으면 `ReplicaSelector` 인터페이스를 구현하는 클래스를 구현한 뒤 `replica.relector.class` 가 
그 클래스를 가리키게 하면 된다.

> rack 에 대한 추가 설명은  
> [2. 파티션 할당](https://assu10.github.io/dev/2024/08/11/kafka-mechanism-2/#2-%ED%8C%8C%ED%8B%B0%EC%85%98-%ED%95%A0%EB%8B%B9),  
> [3.1. 복제 팩터(레플리카 개수): `replication.factor`, `default.replication.factor`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#31-%EB%B3%B5%EC%A0%9C-%ED%8C%A9%ED%84%B0%EB%A0%88%ED%94%8C%EB%A6%AC%EC%B9%B4-%EA%B0%9C%EC%88%98-replicationfactor-defaultreplicationfactor)  
> 를 참고하세요.

> **가까운 rack 에서 읽어오기**  
> 
> 카프카가 처음 개발되던 시점에서는 데이터센터에 설치된 물리적 서버에서 작동시키는 것이 보통이었음  
> 브로커의 `brocker.rack` 설정 역시 원래는 레플리카들이 서로 다른 서버 rack 에 배치되도록 함으로써 한꺼번에 작동 불능에 빠지는 것을 방지하기 위해 고안된 것임  
> 하지만 시간이 흐르면서 클라우드 환경에서 카프카를 작동시키는 것이 더 일반적이 되었고, `brocker.rack` 설정 역시 물리적 서버 rack 이라기 보다 클라우드의 
> 가용 영역을 가리키는 경우가 많아짐
> 
> 문제는 여기서 발생하는데 컨슈머를 물리적 서버에서 작동시키는 경우에는 같은 데이터센터 안에 있는 한 데이터를 읽어오는 레플리카가 어느 rack 에 위치해있는지는 
> 별로 문제가 되지 않음 (어차피 속도는 비슷하므로)  
> 하지만 클라우드에서 작동시키는 경우엔 설명 브로커와 컨슈머가 같은 지역에 있더라도 다른 가용 영역에 있으면 실제로 위치한 데이터센터 역시 다를 가능성이 높음  
> 이것은 자연히 네트워크 속도 또한 떨어질 수 밖에 없음
> 
> 이 문제를 해결하기 위해 컨슈머에게 현재의 대략적인 위치를 알려주고, **'읽어오려는 파티션의 최신 상태 레플리카가 클라이언트와 같은 있을 경우에 한해 해당 레플리카에서** 
> **데이터를 읽어오도록'** 하여 네트워크 지연을 어느 정도 피하도록 함  
> 이것이 바로 `client.rack` 설정이 있는 이유임
> 
> **`client.rack` 설정을 잡아주면 같은 `broker.rack` 설정값을 가진 브로커에 저장된 레플리카를 우선적으로 읽어옴**  
> [KIP-392: Allow consumers to fetch from closest replica](https://cwiki.apache.org/confluence/display/KAFKA/KIP-392:+Allow+consumers+to+fetch+from+closest+replica)  
> 
> 기본적으로 카프카는 리더 레플리카에서 읽고 쓰기가 모두 이루어지지만 이 경우는 약간의 예외라고 할 수 있음

---

## 5.15. `group.instance.id`

**컨슈머에 [정적 그룹 멤버십 기능](#13-정적-그룹-멤버십-static-group-membership-groupinstanceid-sessiontimeoutms)을 적용하기 위해 사용되는 설정으로, 어떤 고유한 문자열도 사용 가능**하다.

---

## 5.16. `receive.buffer.bytes`, `send.buffer.bytes`

**데이터를 읽거나 쓸 때 소켓이 사용하는 TCP 의 수신 및 송신 버퍼의 크기**이다.

-1 로 설정 시 운영체제의 기본값이 사용된다.

다른 데이터센터에 있는 브로커와 통신하는 프로듀서나 컨슈머의 경우 보통 지연이 크고 대역폭은 낮으므로 이 값을 올려 잡아주는 것이 좋다.

---

## 5.17. `offsets.retention.minutes`

`offsets.retention.minutes` 은 브로커 설정이지만 컨슈머 작동에 큰 영향을 미친다.

컨슈머 그룹에 현재 돌아가고 있는 컨슈머들이 있는 한, 컨슈머 그룹이 각 파티션에 대해 커밋한 마지막 오프셋 값은 카프카에 의해 보존되기 때문에 재할당이 발생하거나 
재시작을 한 경우데도 가져다 쓸 수 있다.

**하지만 컨슈머 그룹이 비게 된다면 카프카는 커밋된 오프셋을 `offsets.retention.minutes` 에 설정된 기간동안만 보관**한다.

기본값은 7일이다.

커밋된 오프셋이 삭제된 상태에서 컨슈머 그룹이 다시 활동을 시작하면 과거에 수행했던 읽기 작업에 대한 기록이 전혀없는, 마치 완전히 새로운 컨슈머 그룹인 것처럼 동작한다.

> [5.10 `auto.offset.reset`](#510-autooffsetreset) 과 함께 보면 도움이 됩니다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Kafka Doc](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [컨슈머 파티션 할당 전략](https://baebalja.tistory.com/629)
* [`ExecutorService` 를 이용하여 각자의 컨슈머를 갖는 다수의 스레드 시작하는 방법: Introducing the Kafka Consumer: Getting Started with the New Apache Kafka 0.9 Consumer Client](https://www.confluent.io/blog/tutorial-getting-started-with-the-new-apache-kafka-0-9-consumer-client/)
* [레코드를 읽기오지 않고 메타데이터만 가져오기: Kafka’s Got a Brand-New Poll](https://www.jesse-anderson.com/2020/09/kafkas-got-a-brand-new-poll/)
* [카프카 브로커 설정](https://free-strings.blogspot.com/2016/04/blog-post.html)
* [KIP-735: Increase default consumer session timeout](https://cwiki.apache.org/confluence/display/KAFKA/KIP-735:+Increase+default+consumer+session+timeout)
* [kafka 설정을 사용한 문제해결](https://saramin.github.io/2019-09-17-kafka/)
* [리밸런싱 종류와 컨슈머 파티션 할당 전략 (정리 잘 되어 있음)](https://junior-datalist.tistory.com/387)
* [카프카 2.3 → 2.4 업그레이드 가이드](https://kafka.apache.org/documentation/#upgrade_240_notable)
* [KIP-392: Allow consumers to fetch from closest replica](https://cwiki.apache.org/confluence/display/KAFKA/KIP-392:+Allow+consumers+to+fetch+from+closest+replica)