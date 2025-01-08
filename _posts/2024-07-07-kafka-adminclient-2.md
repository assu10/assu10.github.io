---
layout: post
title:  "Kafka - 코드로 관리(2): 컨슈머 그룹 관리, 클러스터 메타데이터, 고급 어드민 작업, 테스트"
date: 2024-07-07
categories: dev
tags: kafka listConsumerGroups() listConsumerGroupOffsets() partitionsToOffsetAndMetadata() listOffsets() alterConsumerGroupOffsets() describeCluster() createPartitions() deleteRecords() elecLeader() alterPartitionReassignments() MockAdminClient 
---

이 포스트에서는 `AdminClient` 를 사용하여 프로그램적으로 컨슈머 그룹과 이 그룹들이 커밋한 오프셋을 조회,수정하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap05) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 컨슈머 그룹 관리](#1-컨슈머-그룹-관리)
  * [1.1. 컨슈머 그룹 목록, 상세 조회: `listConsumerGroups()`, `ConsumerGroupDescription`](#11-컨슈머-그룹-목록-상세-조회-listconsumergroups-consumergroupdescription)
  * [1.2. 컨슈머 그룹 상세정보로 오프셋 커밋 정보 조회: `listConsumerGroupOffsets()`, `partitionsToOffsetAndMetadata()`, `OffsetSpec`, `listOffsets()`](#12-컨슈머-그룹-상세정보로-오프셋-커밋-정보-조회-listconsumergroupoffsets-partitionstooffsetandmetadata-offsetspec-listoffsets)
  * [1.3. 컨슈머 그룹 수정: `alterConsumerGroupOffsets()`](#13-컨슈머-그룹-수정-alterconsumergroupoffsets)
* [2. 클러스터 메타데이터: `describeCluster()`, `DescribeClusterResult`](#2-클러스터-메타데이터-describecluster-describeclusterresult)
* [3. 고급 어드민 작업](#3-고급-어드민-작업)
  * [3.1. 토픽에 파티션 추가: `createPartitions()`](#31-토픽에-파티션-추가-createpartitions)
  * [3.2. 토픽에서 레코드 삭제: `deleteRecords()`](#32-토픽에서-레코드-삭제-deleterecords)
  * [3.3. 리더 선출: `elecLeader()`](#33-리더-선출-elecleader)
  * [3.4. 레플리카 재할당: `alterPartitionReassignments()`](#34-레플리카-재할당-alterpartitionreassignments)
* [4. 테스트: `MockAdminClient`](#4-테스트-mockadminclient)
* [정리하며...](#정리하며)
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
      <groupId>org.apache.kafka</groupId>
      <artifactId>kafka-clients</artifactId>
      <version>${kafka.version}</version>
      <classifier>test</classifier>
      <scope>test</scope>
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

# 1. 컨슈머 그룹 관리

대부분의 메시지 큐와는 달리 **카프카는 이전의 데이터를 읽어서 처리한 것과 완전히 동일한 순서로 데이터를 재처리**할 수 있다.

[3. 특정 오프셋의 레코드 읽어오기: `seekToBeginning()`, `seekToEnd()`, `seek()`, `assignment()`, `offsetsForTimes()`](https://assu10.github.io/dev/2024/06/29/kafka-consumer-2/#3-%ED%8A%B9%EC%A0%95-%EC%98%A4%ED%94%84%EC%85%8B%EC%9D%98-%EB%A0%88%EC%BD%94%EB%93%9C-%EC%9D%BD%EC%96%B4%EC%98%A4%EA%B8%B0-seektobeginning-seektoend-seek-assignment-offsetsfortimes) 에서 
본 것과 같이 컨슈머 API 를 사용하여 처리 지점을 되돌려서 오래된 메시지를 다시 토픽으로부터 읽어올 수 있다.

하지만 이런 API 를 사용한다는 것 자체가 애플리케이션에 데이터 재처리 기능을 미리 구현해놓았다는 의미이다.

여기서는 `AdminClient` 를 사용하여 프로그램적으로 컨슈머 그룹과 이 그룹들이 커밋한 오프셋을 조회,수정하는 방법에 대해 알아본다.

> 컨슈머 그룹과 이 그룹들이 커밋한 오프셋을 조회,수정하는 기능을 수행하는 외부 툴들에 대해서는 추후 다룰 예정입니다. (p. 136)

---

## 1.1. 컨슈머 그룹 목록, 상세 조회: `listConsumerGroups()`, `ConsumerGroupDescription`

아래는 컨슈머 그룹의 목록을 조회하는 예시이다.

AdminClientSample2.java
```java
package com.assu.study.chap05;

import java.util.Properties;
import java.util.concurrent.ExecutionException;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;

public class AdminClientSample2 {

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ======= 컨슈머 그룹 조회
    adminClient.listConsumerGroups().valid().get().forEach(System.out::println);
  }
}
```

주의할 점은 **`valid()` 와 `get()` 메서드를 호출함으로써 리턴되는 모음은 클러스터가 에러없이 리턴한 컨슈머 그룹만을 포함**한다는 점이다.  
이 과정에서 발생한 에러가 예외의 형태로 발생하지는 않는데, `errors()` 메서드를 사용하여 모든 예외를 가져올 수 있다.

만일 `valid()` 가 아닌 `all()` 메서드를 호출하면 클러스터가 리턴한 에러 중 맨 첫 번째 것만 예외 형태로 발생한다.

아래는 특정 그룹에 대해 좀 더 상세한 정보를 조회하는 예시이다.

AdminClientSample2.java
```java
package com.assu.study.chap05;

import java.util.List;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.ConsumerGroupDescription;

@Slf4j
public class AdminClientSample2 {
  private static final String CONSUMER_GROUP = "TestConsumerGroup";
  private static final List<String> CONSUMER_GROUP_LIST = List.of(CONSUMER_GROUP);

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ======= 특정 컨슈머 그룹의 상세 정보 조회
    ConsumerGroupDescription groupDescription =
        adminClient
            .describeConsumerGroups(CONSUMER_GROUP_LIST) // DescribeConsumerGroupsResult 반환
            .describedGroups() // Map<String, KafkaFuture<ConsumerGroupDescription>> 반환
            .get(CONSUMER_GROUP) // KafkaFuture<ConsumerGroupDescription> 반환
            .get();
    
    log.info("Description of Consumer group: {} - {}", CONSUMER_GROUP, groupDescription);
  }
}
```

**`ConsumerGroupDescription` 는 아래와 같이 해당 그룹에 대한 상세한 정보**를 가진다.
- 그룹 멤버와 멤버별 식별자
- 호스트명
- 멤버별로 할당된 파티션
- 할당 알고리즘
- 그룹 코디네이터의 호스트명

**이러한 정보들은 트러블 슈팅을 할 때 매우 유용**하다.

하지만 정작 **컨슈머 그룹이 읽고 있는 각 파티션에 대해 마지막으로 커밋된 오프셋 값이 무엇인지, 최신 메시지에서 얼마나 뒤떨어졌는지 (= lag) 에 대한 정보는 없다.**

예전에는 커밋 정보를 얻어오는 유일한 방법으로 컨슈머 그룹이 카프카 내부 토픽에 쓴 커밋 메시지를 가져와서 파싱하는 것 뿐이었는데 이는 카프카가 내부 메시지 형식의 호환성 같은 
것에 대해 아무런 보장을 하지 않기 때문에 권장되지 않는다.

---

## 1.2. 컨슈머 그룹 상세정보로 오프셋 커밋 정보 조회: `listConsumerGroupOffsets()`, `partitionsToOffsetAndMetadata()`, `OffsetSpec`, `listOffsets()`

이제 `AdminClient` 를 이용하여 커밋 정보를 가져와본다.

AdminClientSample2.java
```java
package com.assu.study.chap05;

import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;

@Slf4j
public class AdminClientSample2 {
  private static final String CONSUMER_GROUP = "TestConsumerGroup";
  private static final List<String> CONSUMER_GROUP_LIST = List.of(CONSUMER_GROUP);

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);
    
    // ======= 컨슈머 그룹에서 오프셋 커밋 정보 조회
    // 1)
    // 컨슈머 그룹이 사용 중인 모든 토픽 파티션을 key 로, 각각의 토픽 파티션에 대해 마지막으로 커밋된 오프셋을 value 로 하는 맵 조회
    // `describeConsumerGroups()` 와 달리 `listConsumerGroupOffsets()` 은 컨슈머 그룹의 모음이 아닌 하나의 컨슈머 그룹을 받음
    Map<TopicPartition, OffsetAndMetadata> offsets =
        adminClient.listConsumerGroupOffsets(CONSUMER_GROUP).partitionsToOffsetAndMetadata().get();

    Map<TopicPartition, OffsetSpec> reqLatestOffsets = new HashMap<>();
    Map<TopicPartition, OffsetSpec> reqEarliestOffsets = new HashMap<>();
    Map<TopicPartition, OffsetSpec> reqOlderOffsets = new HashMap<>();

    Instant resetTo = ZonedDateTime.now(ZoneId.of("Asia/Seoul")).minusHours(2).toInstant();

    // 2)
    // 컨슈머 그룹에서 커밋한 토픽의 모든 파티션에 대해 최신 오프셋, 가장 오래된 오프셋, 2시간 전의 오프셋 조회
    for (TopicPartition tp : offsets.keySet()) {
      reqLatestOffsets.put(tp, OffsetSpec.latest());
      reqEarliestOffsets.put(tp, OffsetSpec.earliest());
      reqOlderOffsets.put(tp, OffsetSpec.forTimestamp(resetTo.toEpochMilli()));
    }

    Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> latestOffsets =
        adminClient.listOffsets(reqLatestOffsets).all().get();
    //    Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> earliestOffsets =
    //        adminClient.listOffsets(reqEarliestOffsets).all().get();
    //    Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> orderOffsets =
    //        adminClient.listOffsets(reqOlderOffsets).all().get();

    // 3)
    // 모든 파티션을 반복해서 각각의 파티션에 대해 마지막으로 커밋된 오프셋, 파티션의 마지막 오프셋, 둘 사이의 lag 출력
    for (Map.Entry<TopicPartition, OffsetAndMetadata> e : offsets.entrySet()) {
      String topic = e.getKey().topic();
      int partition = e.getKey().partition();
      long committedOffset = e.getValue().offset();

      long latestOffset = latestOffsets.get(e.getKey()).offset();
      // 아래는 확실하지 않음
      //      long earliestOffset = earliestOffsets.get(e.getKey()).offset();
      //      long orderOffset = orderOffsets.get(e.getKey()).offset();

      log.info(
          "Consumer group {} has committed offset {} to topic {}, partition {}.",
          CONSUMER_GROUP,
          committedOffset,
          topic,
          partition);
      log.info(
          "The latest offset in the partition is {} to consumer group is {} records behind.",
          latestOffset,
          (latestOffset - committedOffset));
      // 아래는 확실하지 않음
      // log.info("The earliest offset: {}, order offset: {}", earliestOffset, orderOffset);
    }
  }
}
```

1) **컨슈머 그룹이 사용중인 모든 토픽 파티션을 key 로, 각각의 토픽 파티션에 대해 마지막으로 커밋된 오프셋을 value 로 하는 맵** 조회  
`describeConsumerGroups()` 와 달리 `listConsumerGroupOffsets()` 은 컨슈머 그룹의 모음이 아닌 하나의 컨슈머 그룹을 받음

2) **컨슈머 그룹에서 커밋한 모든 토픽의 파티션에 대해 마지막 메시지의 오프셋, 가장 오래된 메시지의 오프셋, 2시간 전의 오프셋 조회**  
**`OffsetSpec`**  
- `latest()`: 해당 파티션의 마지막 레코드의 오프셋 조회
- `earliest()`: 해당 파티션의 첫 번째 레코드의 오프셋 조회
- `forTimestamp()`: 해당 파티션의 지정된 시각 이후에 쓰여진 레코드의 오프셋 조회

3) 모든 파티션을 반복하여 각각의 파티션에 대해 마지막으로 커밋된 오프셋, 파티션의 마지막 오프셋, 둘 사이의 lag 출력

---

## 1.3. 컨슈머 그룹 수정: `alterConsumerGroupOffsets()`

`AdminClient` 는 컨슈머 그룹을 수정하기 위한 메서드들을 제공한다.  
- 그룹 삭제
- 멤버 제외
- 커밋된 오프셋 삭제 및 변경

위 기능들은 SRE (사이트 신뢰성 엔지니어, Site Reliability Engineer) 가 비상 상황에서 복구를 위한 툴을 제작할 때 자주 사용된다.

위 3가지 메서드 중 오프셋 변경 기능이 가장 유용하다.

오프셋 삭제는 컨슈머를 맨 처음부터 실행시키는 가장 간단한 방법으로 보일수도 있지만, 이것은 컨슈머 설정에 의존한다.

만일 컨슈머가 시작되었는데 커밋된 오프셋을 못 찾을 경우 맨 처음부터 시작하는 것이 맞을까? 아니면 최신 메시지부터 시작하는 것이 맞을까?
위 2개 중 어떻게 동작할지는 [`auto.offset.reset`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#510-autooffsetreset) 설정값을 갖고 있지 않는한 알 수 없다.

**명시적으로 커밋된 오프셋을 맨 앞으로 변경하면 컨슈머는 토픽의 맨 앞에서부터 처리를 시작**하게 된다.  
즉, **컨슈머가 reset 되는 것**이다.

오프셋 토픽의 오프셋 값을 변경한다고 해도 컨슈머 그룹에 변경 여부는 전달되지 않는다는 점을 유의해야 한다.  
**컨슈머 그룹은 컨슈머가 새로운 파티션을 할당받거나, 새로 시작할 때만 오프셋 토픽에 저장된 값을 읽어올 뿐**이다.

**컨슈머가 모르는 오프셋 변경을 방지하지 위해 카프카에서는 현재 작업이 돌아가고 있는 컨슈머 그룹에 대한 오프셋을 수정하는 것을 허용하지 않는다.**

실제로 대부분의 스트림 처리 애플리케이션이 그렇듯 **상태를 가지고 있는 컨슈머 애플리케이션에서 오프셋을 리셋하고, 해당 컨슈머 그릅이 토픽의 맨 처음부터 처리를 시작하도록 
할 경우 저장된 상태가 깨질 수 있다는 점**을 주의해야 한다.

예를 들어 한 상점 스트림 애플리케이션에 문제가 있다는 것을 오전 8시에 발견해서 오전 3시부터 다시 판매 내역을 집계해야 한다고 해보자.  
만일 저장된 집계값을 변경하지 않고 오프셋만 오전 3시로 되돌린다면 오전 3시~8시까지의 판매 내역은 두 번씩 계산되게 된다.

**이런 이유로 상태 저장소를 적절히 변경해 줄 필요**가 있다.

AdminClientSample2.java
```java
package com.assu.study.chap05;

import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.UnknownMemberIdException;

@Slf4j
public class AdminClientSample2 {
  private static final String CONSUMER_GROUP = "TestConsumerGroup";
  private static final List<String> CONSUMER_GROUP_LIST = List.of(CONSUMER_GROUP);

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ======= 컨슈머 그룹에서 오프셋 커밋 정보 조회
    Map<TopicPartition, OffsetAndMetadata> offsets =
        adminClient.listConsumerGroupOffsets(CONSUMER_GROUP).partitionsToOffsetAndMetadata().get();

    Map<TopicPartition, OffsetSpec> reqLatestOffsets = new HashMap<>();
    Map<TopicPartition, OffsetSpec> reqEarliestOffsets = new HashMap<>();
    Map<TopicPartition, OffsetSpec> reqOlderOffsets = new HashMap<>();

    for (TopicPartition tp : offsets.keySet()) {
      reqLatestOffsets.put(tp, OffsetSpec.latest());
      reqEarliestOffsets.put(tp, OffsetSpec.earliest());
      reqOlderOffsets.put(tp, OffsetSpec.forTimestamp(resetTo.toEpochMilli()));
    }

    // ...
    
    // ======= 컨슈머 그룹을 특정 오프셋으로 리셋

    // 1)
    // 맨 앞 오프셋부터 처리하도록 컨슈머 그룹을 리셋하기 위해 토픽의 맨 앞 오프셋 값 조회
    // (reqOlderOffsets 를 사용하면 2시간 전으로 오프셋 리셋 가능)
    Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> earliestOffsets =
        adminClient.listOffsets(reqEarliestOffsets).all().get();

    Map<TopicPartition, OffsetAndMetadata> resetOffsets = new HashMap<>();

    // 2) 
    // 반복문을 이용하여 listOffsets() 가 리턴한 ListOffsetsResultInfo 의 맵 객체를 alterConsumerGroupOffsets() 를 
    // 호출하는데 필요한 OffsetAndMetadata 의 맵 객체로 변환
    for (Map.Entry<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> e :
        earliestOffsets.entrySet()) {
      log.info("Will reset topic-partition: {}, to offset: {}", e.getKey(), e.getValue().offset());
      resetOffsets.put(e.getKey(), new OffsetAndMetadata(e.getValue().offset()));
    }

    try {
      // 3) 
      //  alterConsumerGroupOffsets() 를 호출한 뒤 get() 을 호출하여 Future 객체가 작업을 성공적으로 완료할 때까지 기다림
      adminClient.alterConsumerGroupOffsets(CONSUMER_GROUP, resetOffsets).all().get();
    } catch (ExecutionException e) {
      log.error(
          "Failed to update the offsets committed by group: {}, with error: {}",
          CONSUMER_GROUP,
          e.getMessage());

      // 4)
      // alterConsumerGroupOffsets() 가 실패하는 가장 흔한 이유 중 하나는 컨슈머 그룹을 미리 정지시키지 않아서임
      // 특정 컨슈머 그룹을 정지시키는 어드민 명령은 없기 때문에 컨슈머 애플리케이션을 정지시키는 것 외에는 방법이 없음
      // 만일 컨슈머 그룹이 여전히 돌아가고 있는 중이라면, 컨슈머 코디네이터 입장에서는 컨슈머 그룹에 대한 오프셋 변경 시도를 그룹의 멤버가 아닌 
      // 클라이언트가 오프셋을 커밋하려는 것으로 간주함
      // 이 경우 UnknownMemberIdException 이 발생됨
      if (e.getCause() instanceof UnknownMemberIdException) {
        log.error("Check if consumer group is still active.");
      }
    }
  }
}
```

1) 맨 앞의 오프셋부터 처리를 시작하도록 컨슈머 그룹을 리셋하기 위해 **맨 앞 오프셋의 값 조회**

2) 반복문을 이용하여 `listOffsets()` 가 리턴한 `ListOffsetsResultInfo` 의 맵 객체를 **`alterConsumerGroupOffsets()` 를 호출하는데 
필요한 `OffsetAndMetadata` 의 맵 객체로 변환**

3) **`alterConsumerGroupOffsets()` 를 호출한 뒤 `get()` 을 호출하여 `Future` 객체가 작업을 성공적으로 완료할 때까지 기다림**

4) **`alterConsumerGroupOffsets()` 가 실패하는 가장 흔한 이유 중 하나는 컨슈머 그룹을 미리 정지시키지 않아서임**  
특정 컨슈머 그룹을 정지시키는 어드민 명령은 없기 때문에 컨슈머 애플리케이션을 정지시키는 것 외에는 방법이 없음  
만일 컨슈머 그룹이 여전히 돌아가고 있는 중이라면, 컨슈머 코디네이터 입장에서는 컨슈머 그룹에 대한 오프셋 변경 시도를 그룹의 멤버가 아닌 클라이언트가 시도하려는 것으로 간주함  
이 경우 `UnknownMemberIdException` 예외가 발생함

---

# 2. 클러스터 메타데이터: `describeCluster()`, `DescribeClusterResult`

애플리케이션이 연결된 클러스터에 대한 정보를 명시적으로 읽어와야 하는 경우는 드물다.

얼마나 많은 브로커가 있고, 어느 브로커가 컨트롤러인지 알 필요없이 메시지를 읽거나 쓸 수 있기 때문이다.

하지만 궁금하다면 아래처럼 **클러스터 id, 클러스터 안의 브로커들, 컨트롤러를 조회**할 수 있다.

```java
DescribeClusterResult cluster = adminClient.describeCluster();

log.info("Connected to cluster: {}", cluster.clusterId().get());
log.info("The brokers in the cluster are: ");
cluster.nodes().get().forEach(node -> log.info("   * {}", node));
log.info("The controller is {}", cluster.controller().get());
```

클러스터 식별자는 GUID 이기 때문에 사람이 읽을 수 없지만 클라이언트가 정확한 클러스터에 연결되었는지 확인하는 용도로는 여전히 유용하다.

---

# 3. 고급 어드민 작업

여기서는 잘 쓰이지도 않고 위험하기도 하지만 필요할 때 사용하면 매우 유용한 메서드 몇 개에 대해 알아본다.

이 메서드들은 사고에 대응 중인 SRE 에게 매우 유용할 것이다.
- `createPartitions()`
- `deleteRecords()`
- `elecLeader()`
- `alterPartitionReassignments()`

---

## 3.1. 토픽에 파티션 추가: `createPartitions()`

**대체로 토픽의 파티션 수는 토픽이 생성될 때 결정**된다.

각 파티션은 매우 높은 처리량을 받아낼 수 있기 때문에 파티션 수를 늘리는 것을 드물뿐더러, 토픽의 메시지들이 키를 갖고 있는 경우 같은 키를 가진 메시지들은 모두 
동일한 파티션에 들어가 동일한 컨슈머에 의해 동일한 순서로 처리될 것으로 예상할 수 있다.

이러한 이유로 토픽에 파티션을 추가하는 경우는 드물기도 하고 위험하기도 하다.

하지만 현재 파티션이 처리할 수 있는 최대 처리량까지 부하가 차서 파티션 추가 외에는 선택지가 없는 경우도 있다.

만일 **토픽에 파티션을 추가해야 한다면 파티션을 추가함으로써 토픽을 읽고 있는 애플리케이션들이 깨지지는 않을지 확인**해보아야 한다.

**`createPartitions()` 메서드를 이용하여 지정된 토픽들에 파티션을 추가**할 수 있다.

여러 토픽을 한 번에 확장할 경우 일부 토픽은 성공하고, 나머지는 실패할 수도 있다는 점을 주의해야 한다.

AdminClientSample3.java
```java
package com.assu.study.chap05;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewPartitions;
import org.apache.kafka.common.errors.InvalidPartitionsException;

@Slf4j
public class AdminClientSample3 {
  public static final String TOPIC_NAME = "sample-topic";
  public static final int NUM_PARTITIONS = 6;

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ======= 토픽에 파티션 추가
    Map<String, NewPartitions> newPartitions = new HashMap<>();
    
    // 토픽의 파티션을 확장할 때는 새로 추가될 파티션 수가 아닌 파티션이 추가된 뒤의 파티션 수를 지정해야 함
    newPartitions.put(TOPIC_NAME, NewPartitions.increaseTo(NUM_PARTITIONS+2));

    try {
      adminClient.createPartitions(newPartitions).all().get();
    } catch (ExecutionException e) {
      if (e.getCause() instanceof InvalidPartitionsException) {
        log.error("Couldn't modify number of partitions in topic: {}", e.getMessage());
      }
    }

  }
}
```

**토픽의 파티션을 확장할 때는 새로 추가될 파티션 수가 아닌 파티션이 추가된 뒤의 파티션 수를 지정해야 하기 때문에 파티션을 확장하기 전에 토픽 상세 정보를 확인하여 
몇 개의 파티션을 갖고 있는지 확인**해야 한다.

---

## 3.2. 토픽에서 레코드 삭제: `deleteRecords()`

현재의 개인정보 보호법은 데이터에 대해 일정한 보존 정책을 강제한다.  
카프카는 토픽에 대해 데이터 보존 정책을 설정할 수 있도록 되어있지만, 법적인 요구 조건을 보장할 수 있을 수준의 기능이 구현되어 있지는 않다.  
따라서 **토픽에 30일간의 보존 기한이 설정되어 있더라도 파티션 별로 모든 데이터가 하나의 세그먼트에 저장되어 있다면 보존 기한을 넘긴 데이터라도 삭제되지 않을 수 있다.**

**`deleteRecords()` 메서드는 호출 시점을 기준으로 지정된 오프셋보다 더 오래된 모든 레코드에 삭제 표시를 함으로써 컨슈머가 접근할 수 없도록 한다.**

`deleteRecords()` 메서드는 삭제된 레코드의 오프셋 중 가장 큰 값을 리턴하므로 의도한 대로 삭제가 이루어졌는데 확인할 수 있다.

이렇게 삭제 표시된 레코드를 디스크에서 실제로 삭제하는 작업은 비동기적으로 일어난다.

[1.2. 컨슈머 그룹 상세정보로 오프셋 커밋 정보 조회: `listConsumerGroupOffsets()`, `partitionsToOffsetAndMetadata()`, `OffsetSpec`, `listOffsets()`](#12-컨슈머-그룹-상세정보로-오프셋-커밋-정보-조회-listconsumergroupoffsets-partitionstooffsetandmetadata-offsetspec-listoffsets) 에서 본 것처럼 
특정 시각 혹은 바로 뒤에 쓰여진 레코드의 오프셋을 가져오기 위해 `listOffsets()` 메서드를 이용할 수 있다.

**`listOffsets()` 메서드와 `deleteRecords()` 메서드를 이용하여 특정 시각 이전에 쓰여진 레코드들을 삭제**할 수 있다.

AdminClientSample3.java
```java
package com.assu.study.chap05;

import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.InvalidPartitionsException;
import org.apache.kafka.common.internals.Topic;

@Slf4j
public class AdminClientSample3 {
  public static final String CONSUMER_GROUP = "testConsumerGroup";
  public static final String TOPIC_NAME = "sample-topic";
  public static final int NUM_PARTITIONS = 6;

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ======= 토픽에 파티션 추가
    // ...

    // ======= 토픽에서 레코드 삭제
    Map<TopicPartition, OffsetAndMetadata> offsets =
        adminClient.listConsumerGroupOffsets(CONSUMER_GROUP).partitionsToOffsetAndMetadata().get();

    Map<TopicPartition, OffsetSpec> reqOrderOffsets = new HashMap<>();
    Instant resetTo = ZonedDateTime.now(ZoneId.of("Asia/Seoul")).minusHours(2).toInstant();

    for (TopicPartition tp : offsets.keySet()) {
      reqOrderOffsets.put(tp, OffsetSpec.forTimestamp(resetTo.toEpochMilli()));
    }

    Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> olderOffsets =
        adminClient.listOffsets(reqOrderOffsets).all().get();

    Map<TopicPartition, RecordsToDelete> recordsToDelete = new HashMap<>();
    for (Map.Entry<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> e :
        olderOffsets.entrySet()) {
      recordsToDelete.put(e.getKey(), RecordsToDelete.beforeOffset(e.getValue().offset()));
    }
    
    adminClient.deleteRecords(recordsToDelete).all().get();
  }
}
```

---

## 3.3. 리더 선출: `elecLeader()`

`elecLeader()` 메서드는 2 가지 서로 다른 형태의 리더 선출을 할 수 있게 해준다.

- **선호 리더 선출 (preferred leader election)**
  - 각 파티션은 선호 리더 (preferred leader) 라 불리는 레플리카를 하나씩 가짐
  - preferred 라는 이름이 붙은 이유는 모든 파티션이 preferred leader 레플리카를 리더로 삼을 경우 각 브로커마다 할당되는 리더의 개수가 균형을 이루기 때문임
  - 기본적으로 카프카는 5분마다 선호 리더 레플리카가 실제로 리더를 맡고 있는지 확인하여 리더를 맡을 수 있는데도 맡고 있지 않은 경우 해당 레플리카를 리더로 삼음
  - **[`auto.leader.rebalance.enable`](https://assu10.github.io/dev/2024/06/15/kafka-install/#317-autoleaderrebalanceenable) 가 false 로 설정되어 있거나 아니면 좀 더 빨리 이 과정을 작동시키고 싶을 때 `electLeader()` 메서드 호출**
  - > 파티션의 선호 리더의 좀 더 상세한 내용은  
    > [3.3. 리더 선출: `elecLeader()`](https://assu10.github.io/dev/2024/07/07/kafka-adminclient-2/#33-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-elecleader),  
    > [3.3. 선호 리더(Preferred leader)](https://assu10.github.io/dev/2024/07/13/kafka-mechanism-1/#33-%EC%84%A0%ED%98%B8-%EB%A6%AC%EB%8D%94preferred-leader) 를 참고하세요.
- **언클린 리더 선출 (unclean leader election)**
  - 어느 파티션의 리더 레플리카가 사용 불능 상태가 되었는데 다른 레플리카들은 리더를 맡을 수 없는 상황일 경우 (보통 데이터가 없어서 그럼) 해당 파티션은 리더가 없게 되고, 따라서 사용 불능 상태가 됨
  - 이 문제를 해결하는 방법 중 하나는 리더가 될 수 없는 레플리카를 그냥 리더로 삼아버리는 언클린 리더 선출을 작동시키는 것임
  - 이것은 데이터 유실을 초래함 (예전 리더에 쓰여졌지만 새 리더로 복제되지 않은 모든 이벤트는 유실됨)
  - 이렇게 **언클린 리더 선출을 작동시키기 위해서도 `elecLeader()` 메서드 사용** 가능
  - > 언클린 리더 선출에 대한 상세한 내용은 [3.2. 언클린 리더 선출: `unclean.leader.election.enable`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#32-%EC%96%B8%ED%81%B4%EB%A6%B0-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-uncleanleaderelectionenable) 을 참고하세요.

AdminClientSample3.java
```java
package com.assu.study.chap05;

import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.ElectionType;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.ElectionNotNeededException;
import org.apache.kafka.common.errors.InvalidPartitionsException;

@Slf4j
public class AdminClientSample3 {
  public static final String CONSUMER_GROUP = "testConsumerGroup";
  public static final String TOPIC_NAME = "sample-topic";
  public static final int NUM_PARTITIONS = 6;

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ...

    // ======= 리더 선출
    Set<TopicPartition> electableTopics = new HashSet<>();
    electableTopics.add(new TopicPartition(TOPIC_NAME, 0));

    try {
      // 1)
      // 특정 토픽의 한 파티션에 대해 선호 리더 선출
      // 지정할 수 있는 토픽과 파티션 수에는 제한이 업음
      // 만일 파티션 모음이 아닌 null 값을 지정하여 아래 명령어를 실행할 경우 모든 파티션에 대해 지정된 선출 유형 작업을 시작함
      adminClient.electLeaders(ElectionType.PREFERRED, electableTopics).all().get();
    } catch (ExecutionException e) {
      // 2)
      // 클러스터 상태가 좋다면 아무런 작업도 일어나지 않을 것임
      // 선호 리더 선출과 언클린 리더 선출은 선호 리더가 아닌 레플리카가 현재 리더를 맡고 있을 경우에만 수행됨
      if (e.getCause() instanceof ElectionNotNeededException) {
        log.error("All leaders are preferred leaders, no need to do anything.");
      }
    }
  }
}
```

1) **특정 토픽의 한 파티션에 대해 선호 리더 선출**  
지정할 수 있는 토픽과 파티션 수에는 제한이 없음  
만일 파티션 모음이 아닌 null (위에서는 _electableTopics_ 대신 null) 값을 지정하여 실행할 경우 모든 파티션에 대해 지정된 선출 유형 작업을 시작함

2) 클러스터 상태가 좋다면 아무런 작업도 일어나지 않을것임  
**`electLeaders()` 메서드는 선호 리더 선출과 언클린 리더 선출은 선호 리더가 아닌 레플리카가 현재 리더를 맡고 있을 경우에만 수행**됨

---

## 3.4. 레플리카 재할당: `alterPartitionReassignments()`

레플리카의 현재 위치를 옮겨야 할 경우가 있다.

- 브로커에 너무 많은 레플리카가 올라가 있어서 몇 개를 다른 곳으로 옮겨야 할 경우
- 레플리카를 추가할 경우
- 장비를 내리기 위해 모든 레플리카를 다른 장비로 내보내야 하는 경우
- 몇몇 토픽에 대한 요청이 너무 많아서 나머지에서 따로 분리해놓아야 하는 경우

이럴 때 **`alterPartitionReassignment()` 메서드를 사용하면 파티션에 속한 각각의 레플리카의 위치를 정밀하게 제어**할 수 있다.

**레플리카를 하나의 브로커에서 다른 브로커로 재할당하는 일은 브로커 간에 대량의 데이터 복제가 일어난다는 점을 주의**해야 한다.  
사용 가능한 네트워크 대역폭에 주의하고, 필요할 경우 쿼터를 설정하여 복제 작업을 스로틀링 해주는 것이 좋다.  
쿼터 역시 브로커의 설정이기 때문에 `AdminClient` 를 사용하여 조회/수정 가능하다.

아래는 시나리오는 다음과 같다.
- ID 가 0인 브로커가 하나 있음
- 토픽에는 여러 개의 파티션이 있는데, 각각의 파티션은 이 브로커에 하나의 레플리카를 갖고 있음
- 새로운 브로커를 추가해 준 다음 이 토픽의 레플리카 일부를 새 브로커에 저장하려고 함

AdminClientSample3.java
```java
package com.assu.study.chap05;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;
import java.util.concurrent.ExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.ElectionType;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.ElectionNotNeededException;
import org.apache.kafka.common.errors.InvalidPartitionsException;
import org.apache.kafka.common.errors.NoReassignmentInProgressException;

@Slf4j
public class AdminClientSample3 {
  public static final String CONSUMER_GROUP = "testConsumerGroup";
  public static final String TOPIC_NAME = "sample-topic";
  public static final int NUM_PARTITIONS = 6;
  private static final List<String> TOPIC_LIST = List.of(TOPIC_NAME);

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    Properties props = new Properties();
    props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(AdminClientConfig.REQUEST_TIMEOUT_MS_CONFIG, 1000); // optional
    props.put(AdminClientConfig.DEFAULT_API_TIMEOUT_MS_CONFIG, 1000); // optional
    AdminClient adminClient = AdminClient.create(props);

    // ...

    // ======= 새로운 브로커로 파티션 재할당 (레플리카 재할당)
    Map<TopicPartition, Optional<NewPartitionReassignment>> reassignment = new HashMap<>();

    // 1)
    // 파티션 0 에 새로운 레플리카 를 추가하고, 새 레플리카를 ID 가 1인 새 브로커에 배치
    // 단, 리더는 변경하지 않음
    reassignment.put(
        new TopicPartition(TOPIC_NAME, 0),
        Optional.of(new NewPartitionReassignment(Arrays.asList(0, 1))));

    // 2)
    // 파티션 1 에는 아무런 레플리카도 추가하지 않음
    // 단지 이미 있던 레플리카를 새 브로커로 옮겼을 뿐임
    // 레플리카가 하나뿐인만큼 이것이 리더가 됨
    reassignment.put(
        new TopicPartition(TOPIC_NAME, 1),
        Optional.of(new NewPartitionReassignment(Arrays.asList(0))));

    // 3)
    // 파티션 2 에 새로운 레플리카를 추가하고 이것을 선호 리더로 설정
    // 다음 선호 리더 선출 시 새로운 브로커에 있는 새로운 레플리카로 리더가 바뀌게 됨
    // 이전 레플리카는 팔로워가 될 것임
    reassignment.put(
        new TopicPartition(TOPIC_NAME, 2),
        Optional.of(new NewPartitionReassignment(Arrays.asList(1, 0))));

    // 4)
    // 파티션 3 에 대해서는 진행중인 재할당 작업이 업음
    // 하지만 그런게 있다면 작업이 취소되고 재할당 작업이 시작되기 전 상태로 원상복구될 것임
    reassignment.put(new TopicPartition(TOPIC_NAME, 3), Optional.empty());

    try {
      adminClient.alterPartitionReassignments(reassignment).all().get();
    } catch (ExecutionException e) {
      if (e.getCause() instanceof NoReassignmentInProgressException) {
        log.error(
            "We tried cancelling a reassignment that was not happening anyway. Let's ignore this.");
      }
    }

    // 5)
    // 현재 진행중인 재할당을 보여줌
    log.info(
        "Currently reassigning: {}",
        adminClient.listPartitionReassignments().reassignments().get());

    DescribeTopicsResult sampleTopic = adminClient.describeTopics(TOPIC_LIST);
    TopicDescription topicDescription = sampleTopic.topicNameValues().get(TOPIC_NAME).get();

    // 6)
    // 새로운 상태를 보여줌
    // 단, 일관적인 결과가 보일 때까지는 잠시 시간이 걸릴 수 있음
    log.info("Description of sample topic: {}", topicDescription);

    adminClient.close(Duration.ofSeconds(30));
  }
}
```

1) 파티션 0 에 새로운 레플리카를 추가하고, 새 레플리카를 ID 가 1인 새 브로커에 배치함  
단, 리더는 변경하지 않음

2) 파티션 1 에는 아무런 레플리카를 추가하지 않음  
단지 이미 있던 레플리카를 새 브로커로 옮겼을 뿐임  
레플리카가 하나뿐이므로 이것이 리더가 됨

3) 파티션 2 에 새로운 레플리카를 추가하고 이것을 선호 리더로 설정함  
다음 선호 리더 선출 시 새로운 브로커에 있는 새로운 레플리카로 리더가 변경됨  
이전 레플리카는 팔로워가 될 것임

4) 파티션 3 에 대해서는 진행중인 재할당 작업이 없음  
하지만 그런 게 있다면 작업이 취소되고, 재할당 작업이 시작되기 전 상태로 원상복구될 것임

5) 현재 진행중인 재할당을 보여무

6) 새로운 상태를 보여줌  
단, 일관적인 결과가 보일 때까지는 잠시 시간이 걸릴 수 있음

---

# 4. 테스트: `MockAdminClient`

**아파치 카프카는 원하는 수만큼의 브로커를 설정해서 초기화할 수 있는 `MockAdminClient` 테스트 클래스를 제공**한다.

**`MockAdminClient` 클래스를 사용하면 실제 카프카 클러스터를 돌려서 거기에 실제 어드민 작업을 수행할 필요없이 애플리케이션이 정상 작동하는지 확인**할 수 있다.

`MockAdminClient` 는 카프카 API 의 일부가 아닌만큼 언제고 사전 경고없이 변경될 수 있지만, 공개된 메서드에 대한 mock-up 이기 때문에 메서드 시그니처는 여전히 호환성을 유지한다.  
그렇다고 해서 `MockAdminClient` 를 이용하여 사용중인 API 의 실제 API 가 변경되어서 테스트가 깨질 위험성이 있다는 점은 알아두고 있어야 한다.

`MockAdminClient` 클래스의 편리한 점은 자주 사용되는 메서드가 매우 포괄적인 mock-up 기능을 제공한다는 점이다.  
`MockAdminClient` 의 토픽 생성 메서드를 호출한 후 `listTopics()` 를 호출하면 방금 전에 생성한 토픽이 리턴된다.

먼저 `MockAdminClient` 를 사용하여 테스트하는 방법에 대해 알아보기 위해 `AdminClient` 를 사용하여 토픽을 생성하는 클래스를 하나 정의한다.

TopicCreator.java
```java
package com.assu.study.chap05;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import lombok.RequiredArgsConstructor;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AlterConfigOp;
import org.apache.kafka.clients.admin.ConfigEntry;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.config.ConfigResource;
import org.apache.kafka.common.config.TopicConfig;

@RequiredArgsConstructor
public class TopicCreator {
  private final AdminClient adminClient;

  // 토픽 이름이 test 로 시작할 경우 토픽을 생성하는 메서드 (좋은 예시는 아님)
  public void maybeCreateTopic(String topicName) throws ExecutionException, InterruptedException {
    Collection<NewTopic> topics = new ArrayList<>();

    // 파티션 1개, 레플리카 1개인 토픽 생성
    topics.add(new NewTopic(topicName, 1, (short) 1));

    if (topicName.toLowerCase().startsWith("test")) {
      adminClient.createTopics(topics);

      // 설정 변경
      ConfigResource configResource = new ConfigResource(ConfigResource.Type.TOPIC, topicName);
      ConfigEntry compaction =
          new ConfigEntry(TopicConfig.CLEANUP_POLICY_CONFIG, TopicConfig.CLEANUP_POLICY_COMPACT);

      Collection<AlterConfigOp> configOp = new ArrayList<>();
      configOp.add(new AlterConfigOp(compaction, AlterConfigOp.OpType.SET));

      Map<ConfigResource, Collection<AlterConfigOp>> alterConfigs = new HashMap<>();
      alterConfigs.put(configResource, configOp);

      adminClient.incrementalAlterConfigs(alterConfigs).all().get();
    }
  }
}
```

토픽 설정을 변경하는 부분은 mock-up 클라이언트에 구현되어 있지 않기 때문에 이 부분은 `Mockito` 테스트 프레임워크를 사용할 것이다.

> `Mockito` 를 사용하는 좀 더 상세한 예시는 [Spring Boot - 스프링 부트 테스트](https://assu10.github.io/dev/2023/08/27/springboot-test/) 를 참고하세요.

이제 **mock-up 클라이언트를 생성**함으로써 테스트를 시작한다.

/test/TopicCreatorTest.java
```java
package com.assu.study.chap05;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.List;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AlterConfigsResult;
import org.apache.kafka.clients.admin.MockAdminClient;
import org.apache.kafka.common.KafkaFuture;
import org.apache.kafka.common.Node;
import org.junit.jupiter.api.BeforeEach;

// mock 을 사용하여 TopicCreator 테스트
class TopicCreatorTest {
  private AdminClient adminClient;

  @BeforeEach
  void setUp() {
    // id 가 0 인 브로커 생성
    Node broker = new Node(0, "localhost", 9092);

    // 브로커 목록과 컨트롤러를 지정하여 MockAdminClient 객체 생성 (여기서는 하나만 지정함)
    // 나중에 TopicCreator 가 제대로 실행되었는지 확인하기 위해 spy() 메서드의 주입 기능을 사용할 것임
    this.adminClient = spy(new MockAdminClient(List.of(broker), broker));

    // 아래 내용이 없으면 테스트 시
    // `java.lang.UnsupportedOperationException: Not implemented yet` 예외 발생됨
    // --> 없애고 해봤는데 오류 안남

    // Mockito 의 doReturn() 메서드를 사용하여 mock-up 클라이언트가 예외를 발생시키지 않도록 함
    // 테스트하고자 하는 메서드는 AlterConfigResult 객체가 필요하고, 
    // 이 객체는 KafkaFuture 객체를 리턴하는 all() 메서드가 있어야 함
    // 가짜 incrementalAlterConfigs() 메서드는 정확히 이것을 리턴해야 함
    
//    AlterConfigsResult emptyResult = mock(AlterConfigsResult.class);
//    doReturn(KafkaFuture.completedFuture(null)).when(emptyResult).all();
//    doReturn(emptyResult).when(adminClient).incrementalAlterConfigs(any());
  }
}
```

위에서 브로커를 생성했지만, 테스트를 실행하는 도중에 실제로 실행되는 브로커는 하나도 없다.

> `spy()`, `mock()` 에 대한 내용은 [3. Jest Unit Test](https://assu10.github.io/dev/2023/04/30/nest-test/#3-jest-unit-test) 를 참고하세요.

아파치 카프카는 `MockAdminClient` 를 test jar 에 담아서 공개하므로 아래와 같은 dependency 를 추가해야 한다.
```xml
<dependency>
    <groupId>org.apache.kafka</groupId>
    <artifactId>kafka-clients</artifactId>
    <version>${kafka.version}</version>
    <classifier>test</classifier>
    <scope>test</scope>
</dependency>
```

이제 가짜 `AdminClient` 를 만들었으니 maybeCreateTopic() 메서드가 정상적으로 작동하는지 확인해본다.

```java
package com.assu.study.chap05;

import static org.mockito.Mockito.*;

import java.util.List;
import java.util.concurrent.ExecutionException;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AlterConfigsResult;
import org.apache.kafka.clients.admin.MockAdminClient;
import org.apache.kafka.common.KafkaFuture;
import org.apache.kafka.common.Node;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

// mock 을 사용하여 TopicCreator 테스트
class TopicCreatorTest {
  private AdminClient adminClient;

  // ...

  @Test
  public void testCreateTopic() throws ExecutionException, InterruptedException {
    TopicCreator tc = new TopicCreator(adminClient);
    tc.maybeCreateTopic("test.is.a.test.topic");

    // createTopics() 가 한 번 호출되었는지 확인
    verify(adminClient, times(1)).createTopics(any());
  }

  @Test
  public void tetNotTopic() throws ExecutionException, InterruptedException {
    TopicCreator tc = new TopicCreator(adminClient);
    tc.maybeCreateTopic("not.a.test");

    // 토픽 이름이 test 로 시작하지 않을 경우 createTopics() 가 한 번도 호출되지 않았는지 확인
    verify(adminClient, never()).createTopics(any());
  }
}
```

---

# 정리하며...

`AdminClient` 는 토픽을 생성하거나 애플리케이션이 사용할 토픽이 올바른 설정을 갖고있는지 확인해야 하는 애플리케이션 개발자들에게 유용하다.

또한 툴을 개발해야 하거나, 카프카 작업을 자동화하거나, 사고 발생 시 복구를 해야하는 운영자가 SRE 에게도 유용하다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Kafka Doc](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)