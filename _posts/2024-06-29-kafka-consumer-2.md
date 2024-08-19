---
layout: post
title:  "Kafka - 컨슈머(2): 오프셋, 커밋, 리밸런스 리스너, 특정 오프셋의 레코드 조회"
date: 2024-06-29
categories: dev
tags: kafka consumer offset __consumer_offsets commitSync() commitAsync() topicPartition offsetAndMetadata consumerRebalanceListener seekToBeginning() seekToEnd() seek() assignment() offsetsForTimes()
---

카프카에서 데이터를 읽는 애플리케이션은 토픽을 구독(subscribe) 하고, 구독한 토픽들로부터 메시지를 받기 위해 `KafkaConsumer` 를 사용한다.  
이 포스트에서는 카프카에 쓰여진 메시지를 읽기 위한 클라이언트에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap04)  에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 오프셋과 커밋: `__consumer_offsets`](#1-오프셋과-커밋-__consumer_offsets)
  * [1.1. 자동 커밋](#11-자동-커밋)
  * [1.2. 현재 오프셋 커밋: `commitSync()`](#12-현재-오프셋-커밋-commitsync)
  * [1.3. 비동기적 커밋: `commitAsync()`](#13-비동기적-커밋-commitasync)
    * [1.3.1. 비동기적으로 재시도](#131-비동기적으로-재시도)
  * [1.4. 동기적 커밋과 비동기적 커밋 함께 사용](#14-동기적-커밋과-비동기적-커밋-함께-사용)
  * [1.5. 특정 오프셋 커밋: `TopicPartition`, `OffsetAndMetadata`](#15-특정-오프셋-커밋-topicpartition-offsetandmetadata)
* [2. 리밸런스 리스너: `ConsumerRebalanceListener`](#2-리밸런스-리스너-consumerrebalancelistener)
* [3. 특정 오프셋의 레코드 읽어오기: `seekToBeginning()`, `seekToEnd()`, `seek()`, `assignment()`, `offsetsForTimes()`](#3-특정-오프셋의-레코드-읽어오기-seektobeginning-seektoend-seek-assignment-offsetsfortimes)
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

# 1. 오프셋과 커밋: `__consumer_offsets`

`poll()` 을 호출할 때마다 카프카에 쓰여진 메시지 중 컨슈머 그룹에 속한 컨슈머들이 아직 읽지 않은 레코드들이 리턴된다.  
이 말인 즉슨, 이를 이용하여 그룹 내의 컨슈머가 어떤 레코드를 읽었는지 판단할 수 있다는 이야기이다.

카프카의 고유한 특성 중 하나는 많은 JMS (Java Message Service) 큐들이 하는 것처럼 컨슈머로부터 응답을 받는 방식이 아니라 컨슈머가 카프카를 사용하여 
각 파티션의 위치를 추적한다는 것이다.

**파티션에서의 현재 위치를 업데이트하는 작업을 오프셋 커밋** 이라고 한다.  
전통적인 메시지 큐와는 다르게 카프카는 레코드를 개별적으로 커밋하는 것이 아니라 컨슈머가 파티션에서 성공적으로 처리해 낸 마지막 메시지를 커밋함으로써 그 앞의 
모든 메시지들 역시 성공적으로 처리되었음을 암묵적으로 나타낸다.

**카프카의 특수 토픽인 `__consumer_offsets` 토픽에 각 파티션별로 커밋된 오프셋을 업데이트하도록 메시지를 보냄으로써 컨슈머는 오프셋을 커밋**한다.

[리밸런스](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#12-%EC%BB%A8%EC%8A%88%EB%A8%B8-%EA%B7%B8%EB%A3%B9%EA%B3%BC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%B0%B8%EB%9F%B0%EC%8A%A4) 이후 
각각의 컨슈머는 리밸런스 이전에 처리하고 있던 것과는 다른 파티션들을 할당받을 수 있다.  
어디서부터 작업을 재개해야 하는지 알아내기 위해 컨슈머는 각 파티션의 마지막으로 커밋된 메시지를 읽어온 뒤 거기서부터 처리를 재개한다.

**커밋된 오프셋이 클라이언트가 처리한 마지막 메시지의 오프셋보다 작을 경우, 마지막으로 처리된 오프셋과 커밋된 오프셋 사이의 메시지들은 두 번 처리**되게 된다.
![중복된 메시지들](/assets/img/dev/2024/0629/offset_1.png)

**커밋된 오프셋이 클라이언트가 처리한 마지막 메시지의 오프셋보다 클 경우, 마지막으로 처리된 오프셋과 커밋된 오프셋 사이의 메시지들은 컨슈머 그룹에서 누락**되게 된다.
![누락된 메시지들](/assets/img/dev/2024/0629/offset_2.png)

**오프셋을 커밋할 때 자동으로 커밋하건 오프셋을 지정하지 않고 하건 상관없이 `poll()` 이 리턴한 마지막 오프셋 바로 다음 오프셋을 커밋하는 것이 기본 동작**이다.  
수동으로 특정 오프셋을 커밋하거나 특정 오프셋 위치를 탐색(seek) 할 때 위 내용을 주의해야 한다.

---

## 1.1. 자동 커밋

오프셋을 커밋하는 가장 쉬운 방법은 컨슈머가 대신 커밋하도록 하는 것이다.

[`enable.auto.commit`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#511-enableautocommit) 을 true 로 설정하면 컨슈머는 
기본값인 5초에 한번 `poll()` 을 통해 받은 메시지 중 마지막 메시지의 오프셋을 커밋한다.  
`auto.commit.interval.ms` 설정을 통해 기본값인 5초를 변경할 수 있다.

기본적으로 자동 커밋은 5초에 한번 발생한다.

마지막으로 커밋한 지 3초가 지난 뒤에 컨슈머가 크래시된다면 리밸런싱이 완료된 뒤부터 남은 컨슈머들은 크래시된 컨슈머가 읽고 있던 파티션들을 이어받아서 읽기 시작한다.  
**문제는 남은 컨슈머들이 마지막으로 커밋된 오프셋부터 작업을 시작하는데, 커밋되어 있는 오프셋은 3초 전의 것이기 때문에 크래시되기 3초 전까지 읽혔던 이벤트들이 중복 처리**된다.

오프셋을 더 자주 커밋하여 레코드가 중복될 수 있는 윈도우를 줄어들도록 커밋 간격을 줄여서 설정할 수는 있지만 **중복을 완전히 없애는 것을 불가능**하다.

자동 커밋 기능이 켜진 상태에서 오프셋을 커밋할 때가 되면 다음 번에 호출된 `poll()` 이 이전 호출에서 리턴된 마지막 오프셋을 커밋한다.  
이 동작은 어느 이벤트가 실제로 처리되었는지 알지 못하기 때문에 `poll()` 을 다시 호출하기 전 이전 호출에서 리턴된 모든 이벤트들을 처리하는 게 중요하다.  
이것은 보통은 문제가 되지 않지만, [폴링 루프](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#4-%ED%8F%B4%EB%A7%81-%EB%A3%A8%ED%94%84-poll)에서 예외를 처리하거나 루프를 일찍 벗어날 때 주의해야 한다.

**<u>자동 커밋은 편리하지만, 중복 메시지를 방지하기엔 충분하지 않다.</u>**

---

## 1.2. 현재 오프셋 커밋: `commitSync()`

대부분의 개발자들은 메시지 유실의 가능성을 제거하고 리밸런스 발생 시 중복되는 메시지의 수를 줄이기 위해 오프셋이 커밋되는 시각을 제어하려 한다.  
컨슈머 API 는 타이머 시간이 아닌, 개발자가 원하는 시간에 현재 오프셋을 커밋하는 옵션을 제공한다.

[`enable.auto.commit`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#511-enableautocommit) 을 false 로 설정해줌으로써 
애플리케이션이 명시적으로 커밋하려 할 때만 오프셋이 커밋되게 할 수 있다.

**가장 간단하고 신뢰성있는 커밋 API 는 `commitSync()`** 이다.

**`commitSync()` 는 `poll()` 이 리턴한 마지막 오프셋을 커밋한 뒤 커밋이 성공적으로 완료되면 리턴, 실패하면 예외를 발생**시킨다.

만일 `poll()` 에서 리턴된 모든 레코드의 처리가 완료되기 전에 `commitSync()` 를 호출하게 될 경우 애플리케이션이 크래시되었을 때 커밋은 되었지만 아직 처리되지 않은 메시지들이 누락될 수 있다.

만일 애플리케이션이 아직 레코드들을 처리하는 도중에 크래시가 날 경우, 마지막 메시지 배치의 맨 앞 레코드부터 리밸런스 시작 시점까지의 모든 레코드들은 중복 처리된다.

아래는 가장 최근의 메시지 배치를 처리한 뒤 `commitSync()` 를 호출하여 오프셋을 커밋하는 예시이다.

CommitSync.java
```java
package com.assu.study.chap04.offset;

import java.time.Duration;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.serialization.StringDeserializer;

// 가장 최근의 메시지 배치를 처리한 뒤 commitSync() 를 호출하여 오프셋 커밋
@Slf4j
public class CommitSync {
  public static void main(String[] args) {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    Duration timeout = Duration.ofMillis(100);

    try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
      while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);

        for (ConsumerRecord<String, String> record : records) {
          // 여기서는 로그가 출력되면 처리가 끝나는 것으로 간주함
          log.info(
              "topic: {}, partition: {}, offset: {}, customer: {}, country: {}",
              record.topic(),
              record.partition(),
              record.offset(),
              record.key(),
              record.value());
        }

        try {
          // 현재 배치의 모든 레코드에 대한 '처리'가 완료되면 추가 메시지를 폴링하기 전에 commitSync() 를 호출해서
          // 해당 배치의 마지막 오프셋 커밋
          consumer.commitSync();
        } catch (CommitFailedException e) {
          log.error("commit failed: {}", e.getMessage());
        }
      }
    }
  }
}
```

---

## 1.3. 비동기적 커밋: `commitAsync()`

**수동 커밋의 단점 중 하나는 브로커가 커밋 요청에 응답할 때까지 애플리케이션이 블록되어 처리량이 제한된다는 점**이다.

덜 자주 커밋한다면 처리량은 올라가겠지만 리밸런스에 의한 잠재적인 중복 메시지 수는 늘어간다.

**비동기적 커밋 API 를 사용하면 브로커가 커밋에 응답할 때까지 기다리는 대신 요청만 보내고 처리는 계속**한다.

CommitAsync.java
```java
package com.assu.study.chap04.offset;

import java.time.Duration;
import java.util.Properties;

import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

@Slf4j
public class CommitAsync {
  public void commitAsync() {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    Duration timeout = Duration.ofMillis(100);

    try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
      while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);
        for (ConsumerRecord<String, String> record : records) {
          // 여기서는 로그가 출력되면 처리가 끝나는 것으로 간주함
          log.info(
              "topic: {}, partition: {}, offset: {}, customer: {}, country: {}",
              record.topic(),
              record.partition(),
              record.offset(),
              record.key(),
              record.value());
        }
        // 마지막 오프셋을 커밋하고 처리 작업을 계속함
        consumer.commitAsync();
      }
    }
  }
}
```

**`commitSync()` 는 성공하거나 재시도가 불가능한 실패가 발생할 때까지 재시도를 하지만, `commitAsync()` 는 재시도를 하지 않는다.**

`commitAsync()` 가 서버로부터 응답을 받을 시점에 이미 다른 커밋이 성공했을 수도 있기 때문이다.  
아래 예시를 보자.

- 컨슈머가 `commitAsync()` 를 이용하여 오프셋 10 을 커밋하는 요청을 보냄
- 일시적인 장애로 브로커가 해당 요청을 받지 못하여 응답하지 않음
- 그 사이 컨슈머가 다른 배치를 처리한 뒤 오프셋 30 을 커밋하는 요청을 보냄

위와 같은 상황에서 `commitAsync()` 가 실패한 앞 (오프셋 10 커밋) 의 요청을 재시도해서 성공한다면 오프셋 30 까지 처리되어 커밋이 완료된 후 다음 오프셋으로 20 이 
커밋되는 상황이 발생할 수 있다.

**`commitAsync()` 에 있는 브로커가 보낸 응답을 받았을 때 호출되는 콜백을 지정하는 옵션을 사용할 때 오프셋의 올바른 순서로 커밋하는 문제의 중요성을 더 유의**해야 한다.

이 콜백은 보통 커밋 에러를 로깅하거나, 커밋 에러 수를 지표 형태로 집계하기 위해 사용된다.  
만일 재시도를 하기 위해 콜백을 사용할 때는 커밋 순서와 관련된 문제에 유의해야 한다.

```java
// 마지막 오프셋을 커밋하고 처리 작업을 계속함
// 하지만, 커밋이 실패할 경우 실패가 났다는 사실과 함께 오프셋을 로그에 남김
consumer.commitAsync(
    new OffsetCommitCallback() {
      @Override
      public void onComplete(Map<TopicPartition, OffsetAndMetadata> offsets, Exception e) {
        if (e != null) {
          log.error("Commit failed of offsets: {}", e.getMessage());
        }
      }
    });
}
```

---

### 1.3.1. 비동기적으로 재시도

**순차적으로 단조 증가하는 번호를 사용하면 비동기적 커밋 재시도 시 오프셋 순서**를 맞출 수 있다.  
커밋을 할 때마다 번호를 1씩 증가시킨 후 `commitAsync()` 의 콜백에 해당 번호를 넣어준다.  
그리고 재요청 시도 시 콜백에 주어진 번호와 현재 번호를 비교하여 콜백에 주어진 번호가 더 크다면 새로운 커밋이 없었다는 의미이므로 재시도를 하면 된다.  
만일 그 반대이면 새로운 커밋이 있었다는 의미이므로 재시도를 하면 안된다.

---

## 1.4. 동기적 커밋과 비동기적 커밋 함께 사용

대체로 재시도 없는 커밋은 일시적인 문제일 경우 뒤이은 커밋이 성공할 것이기 때문에 크게 문제가 되지 않는다.

하지만 **그 커밋이 컨슈머를 닫기 전 커밋이거나 리밸런스 전 마지막 커밋이라면 성공 여부를 추가로 확인할 필요**가 있다.

이럴 때 **일반적인 패턴은 종료 직전에 `commitAsync()` 와 `commitSync()` 를 함께 사용**하는 것이다.

아래는 컨슈머 종료 직전에 `commitAsync()` 와 `commitSync()` 를 사용하는 예시이다.

> 리밸런싱 직전에 커밋하는 방법은 [2. 리밸런스 리스너: `ConsumerRebalanceListener`](#2-리밸런스-리스너-consumerrebalancelistener) 를 참고하세요.

CommitAsync.java
```java
package com.assu.study.chap04.offset;

import java.time.Duration;
import java.util.Map;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

@Slf4j
public class CommitAsync {
  // 컨슈머 종료 직전에 동기적 커밋과 비동기적 커밋 함께 사용하여 마지막 오프셋 커밋
  public void commitSyncAndAsyncBeforeClosingConsumer() {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    Duration timeout = Duration.ofMillis(100);

    try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
      boolean closing = false; // TODO: closing 업데이트
      while (!closing) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);
        for (ConsumerRecord<String, String> record : records) {
          // 여기서는 로그가 출력되면 처리가 끝나는 것으로 간주함
          log.info(
              "topic: {}, partition: {}, offset: {}, customer: {}, country: {}",
              record.topic(),
              record.partition(),
              record.offset(),
              record.key(),
              record.value());
        }
        // 정상적인 상황에서는 비동기 커밋 사용
        // 더 빠를 뿐더러 커밋이 실패해도 다음 커밋이 성공할 수 있음
        consumer.commitAsync();
      }
      // 컨슈머를 닫는 상황에서는 '다음 커밋' 이 없으므로 commitSync() 를 호출하여
      // 커밋의 성공하면 종료, 회복 불가능한 에러가 발생할 때까지 재시도함
      consumer.commitSync();
    } catch (Exception e) {
      log.error("Unexpected error: {}", e.getMessage());
    }
  }
}
```

---

## 1.5. 특정 오프셋 커밋: `TopicPartition`, `OffsetAndMetadata`

**가장 최근 오프셋을 커밋하는 것은 메시지 배치 처리가 끝날 때만 수행이 가능**하다.

만일 `poll()` 이 매우 큰 배치를 리턴했는데 리밸런스가 발생한 경우 전체 배치를 재처리하는 상황을 피하기 위해 배치를 처리하는 도중에 오프셋을 
커밋하고 싶다면 어떻게 해야할까?

`commitSync()` 와 `commitAsync()` 는 아직 처리하지 않은, 리턴된 마지막 오프셋을 커밋하기 때문에 이 경우엔 단순히 `commitSync()` 와 `commitAsync()` 를 
호출할 수 없다.

컨슈머 API 에는 **`commitSync()` 와 `commitAsync()` 호출 시 커밋하고자 하는 파티션과 오프셋의 map 을 전달**할 수 있다.

예를 들어 레코드 배치 처리 중이고, _customers_ 토픽의 파티션 3 에서 마지막으로 처리한 메시지의 오프셋이 50 이라면 
_customers_ 토픽의 파티션 3 의 오프셋 51 에 대한 `commitSync()` 를 호출해주면 된다.

아래는 특정 오프셋을 커밋하는 예시이다.

CommitAsync.java
```java
package com.assu.study.chap04.offset;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

@Slf4j
public class CommitAsync {

  int count = 0;
  // 오프셋을 추적하기 위해 사용할 맵
  private Map<TopicPartition, OffsetAndMetadata> currentOffsets = new HashMap<>();

  // 특정 오프셋 커밋
  public void commitSpecificOffset() {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    Duration timeout = Duration.ofMillis(100);

    KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
    while (true) {
      ConsumerRecords<String, String> records = consumer.poll(timeout);
      for (ConsumerRecord<String, String> record : records) {
        // 여기서는 로그가 출력되면 처리가 끝나는 것으로 간주함
        log.info(
            "topic: {}, partition: {}, offset: {}, customer: {}, country: {}",
            record.topic(),
            record.partition(),
            record.offset(),
            record.key(),
            record.value());

        // 각 레코드를 처리한 후 맵을 다음에 처리할 것으로 예상되는 오프셋으로 업데이트
        // 커밋될 오프셋은 애플리케이션이 다음 번에 읽어야 할 메시지의 오프셋이어야 함 (= 향후에 읽기 시작할 메시지의 위치)
        currentOffsets.put(
            new TopicPartition(record.topic(), record.partition()),
            new OffsetAndMetadata(record.offset() + 1, "no metadata"));

        // 10개의 레코드마다 현재 오프셋 커밋
        // 실제 운영 시엔 시간 혹은 레코드의 내용을 기준으로 커밋해야 함
        if (count % 10 == 0) {
          // commitSync() 도 사용 가능
          consumer.commitAsync(currentOffsets, null); // 여기선 callback 을 null 로 처리
        }
        count++;
      }
    }
  }
}
```

**특정 오프셋을 커밋할 때는 모든 에러를 직접 처리**해주어야 한다.

---

# 2. 리밸런스 리스너: `ConsumerRebalanceListener`

컨슈머는 종료하기 전이나 리밸런싱이 시작되기 전에 정리 작업 (cleanup)을 해주어야 한다.

컨슈머에 할당된 파티션이 해제될 것이라는 것을 알게 된다면 해당 파티션에서 마지막으로 처리한 이벤트의 오프셋을 커밋하고, 
파일 핸들이나 DB 연결 등도 닫아주어야 한다.

**컨슈머 API 는 파티션이 할당되거나 해제될 때 사용자의 코드가 실행되도록 해주는 메커니즘을 제공**한다.

[3. 토픽 구독: `subscribe()`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#3-%ED%86%A0%ED%94%BD-%EA%B5%AC%EB%8F%85-subscribe) 에서 본 
`subscribe()` 를 호출할 때 `ConsumerRebalanceListener` 를 전달해주면 된다.

ConsumerRebalanceListener 시그니처
```java
package org.apache.kafka.clients.consumer;

import java.util.Collection;
import org.apache.kafka.common.TopicPartition;

public interface ConsumerRebalanceListener {
  void onPartitionsRevoked(Collection<TopicPartition> partitions);

  void onPartitionsAssigned(Collection<TopicPartition> partitions);

  default void onPartitionsLost(Collection<TopicPartition> partitions) {
    this.onPartitionsRevoked(partitions);
  }
}
```
- **`void onPartitionsAssigned(Collection<TopicPartition> partitions)`**
  - **파티션이 컨슈머에게 재할당 된 후에, 하지만 컨슈머가 메시지를 읽기 시작하기 전에 호출**됨
  - 파티션과 함께 사용할 상태를 적재하거나, 필요한 오프셋을 탐색하는 등과 같은 **준비 작업 수행 시 사용**
  - 컨슈머가 그룹에 문제없이 조인하려면 여기서 수행되는 모든 준비 작업은 [`max.poll.interval.ms`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#57-maxpollintervalms) 안에 완료되어야 함
- **`void onPartitionsRevoked(Collection<TopicPartition> partitions)`**
  - **컨슈머가 할당받았던 파티션이 할당 해제될 때 호출됨** (리밸런스 때문일 수도 있고, 컨슈머가 닫혀서일수도 있음)
  - **여기서 오프셋을 커밋**해주어야 이 파티션을 다음에 할당받는 컨슈머가 시작할 지점을 알 수 있음
  - [조급한 리밸런스 알고리즘](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#121-%EC%A1%B0%EA%B8%89%ED%95%9C-%EB%A6%AC%EB%B0%B8%EB%9F%B0%EC%8A%A4-eager-rebalance) 사용 시
    - 컨슈머가 메시지 읽기는 멈춘 뒤에, 그리고 리밸런스가 시작되기 전에 호출됨
  - [협력적 리밸런스 알고리즘](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#122-%ED%98%91%EB%A0%A5%EC%A0%81-%EB%A6%AC%EB%B0%B8%EB%9F%B0%EC%8A%A4-cooperative-rebalance-%ED%98%B9%EC%9D%80-%EC%A0%90%EC%A7%84%EC%A0%81-%EB%A6%AC%EB%B0%B8%EB%9F%B0%EC%8A%A4-incremental-rebalance) 사용 시
    - 리밸런스가 완료될 때, 컨슈머에서 할당 해제되어야 할 파티션들에 대해서만 호출됨
- **`default void onPartitionsLost(Collection<TopicPartition> partitions)`**
  - 협력적 리밸런스 알고리즘 사용 시 할당된 파티션이 리밸런스 알고리즘에 의해 해제되기 전에 다른 컨슈머에게 먼저 할당된 예외적인 상황에서만 호출됨 (일반적인 상황에서는 `onPartitionsRevoke()` 가 호출됨)
  - **여기서 파티션과 함께 사용되었던 상태나 자원들을 정리**해주어야 함
  - 상태나 자원 정리 시 파티션을 새로 할당받은 컨슈머가 이미 상태를 저장했을수도 있으므로 충돌을 피하도록 주의해야 함
  - 이 메서드를 구현하지 않았을 경우 `onPartitionsRevoked()` 가 대신 호출됨

**협력적 리밸런스 알고리즘 사용 시 아래를 주의**하자.
- **onPartitionsAssigned()**
  - 리밸런싱이 발생할 때마다 호출됨
  - 즉, 리밸런스가 발생했음을 컨슈머에게 알려주는 역할
  - 컨슈머에게 새로 할당된 파티션이 없을 경우 빈 목록과 함께 호출됨
- **onPartitionsRevoked()**
  - 일반적인 리밸런스 상황에서 파티션이 특정 컨슈머에서 해제될 때만 호출됨
  - 메서드가 호출될 때 빈 목록이 주어지는 경우는 없음
- **onPartitionsLost()**
  - 예외적인 리밸런스 상황에서 호출됨
  - 주어지는 파티션들은 이 메서드가 호출되는 시점에서 이미 다른 컨슈머들에게 할당되어 있는 상태임

아래는 파티션이 해제되기 전에 `onPartitionsRevoked()` 를 사용하여 오프셋을 커밋하는 예시이다.

RebalanceListener.java
```java
package com.assu.study.chap04.rebalance;

import java.time.Duration;
import java.util.*;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.WakeupException;
import org.apache.kafka.common.serialization.StringDeserializer;

// 파티션이 해제되기 직전에 동기적 커밋과 비동기적 커밋 함께 사용하여 마지막 오프셋 커밋
@Slf4j
public class RebalanceListener {
  static Properties props = new Properties();

  static {
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");
  }

  private Duration timeout = Duration.ofMillis(100);
  private KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
  private Map<TopicPartition, OffsetAndMetadata> currentOffsets = new HashMap<>();

  public void commitSyncAndAsyncBeforePartitionRevoked() {
    try {
      // subscribe() 호출 시 ConsumerRebalanceListener 를 인수로 지정하여 컨슈머가 호출할 수 있도록 해줌
      consumer.subscribe(Collections.singletonList("testTopic"), new HandleRebalance());

      while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);
        for (ConsumerRecord<String, String> record : records) {
          log.info(
              "topic: {}, partition: {}, offset: {}, customer: {}, country: {}",
              record.topic(),
              record.partition(),
              record.offset(),
              record.key(),
              record.value());

          currentOffsets.put(
              new TopicPartition(record.topic(), record.partition()),
              new OffsetAndMetadata(record.offset() + 1, null));
          consumer.commitAsync(currentOffsets, null); // 여기선 callback 을 null 로 처리
        }
      }
    } catch (WakeupException e) {
      // ignore, we're closing
    } catch (Exception e) {
      log.error("Unexpected error: {}", e.getMessage());
    } finally {
      try {
        consumer.commitSync(currentOffsets);
      } finally {
        consumer.close();
        log.info("Closed consumer and we are done.");
      }
    }
  }

  // ConsumerRebalanceListener 구현
  private class HandleRebalance implements ConsumerRebalanceListener {
    // 여기서는 컨슈머가 새 파티션을 할당받았을 때 아무것도 할 필요가 없기 때문에 바로 메시지를 읽기 시작함
    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {}

    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
      log.error("Lost partitions in rebalance. Commiting current offsets: {}", currentOffsets);
      // 리밸런싱 때문에 파티션이 해제될 상황이라면 오프셋 커밋
      // 할당 해제될 파티션의 오프셋 뿐 아니라 모든 파티션에 대한 오프셋 커밋
      // (이 오프셋들은 이미 처리된 이벤트들의 오프셋이므로 문제없음)
      // 리밸런스가 진행되기 전에 모든 오프셋이 확실히 커밋되도록 commitSync() 사용
      consumer.commitSync(currentOffsets);
    }
  }
}
```


---

# 3. 특정 오프셋의 레코드 읽어오기: `seekToBeginning()`, `seekToEnd()`, `seek()`, `assignment()`, `offsetsForTimes()`

지금까지 각 파티션의 마지막으로 커밋된 오프셋부터 읽기를 시작해서 모든 메시지를 순차적으로 처리하기 위해 `poll()` 을 사용하였다.

다른 오프셋부터 읽기를 시작해야 할 경우를 위해 카프카는 다음 번 `poll()` 이 다른 오프셋부터 읽기를 시작하도록 하는 다양한 메서드를 제공한다.

파티션의 맨 앞에서부터 모든 메시지를 읽고자 한다면 `seekToBeginning(Collection<TopicPartition> tp)` 를 사용하면 되고, 
앞의 메시지는 모두 건너뛰고 파티션의 새로 들어온 메시지부터 읽고자 한다면 `seekToEnd(Collection<TopicPartition> tp)` 를 사용하면 된다.

카프카 API 를 이용하여 특정한 오프셋으로 탐색(seek) 해 갈 수도 있다.  
예) 시간에 민감한 애플리케이션에서 처리가 늦어져서 몇 초간 메시지를 건너뛰어야 하는 경우, 파일에 데이터를 쓰는 컨슈머가 파일이 유실되어 데이터 복구를 위해 특정 과거 시점으로 
되돌아가야 하는 경우

아래는 모든 파티션의 현재 오프셋을 특정한 시각에 생성된 레코드의 오프셋으로 설정하는 예시이다.

Seek.java
```java
package com.assu.study.chap04.offset;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Map;
import java.util.Properties;
import java.util.stream.Collectors;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.consumer.OffsetAndTimestamp;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

public class Seek {
  // 모든 파티션의 현재 오프셋을 특정한 시각에 생성된 레코드의 오프셋으로 설정
  public void setOffset() {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    Duration timeout = Duration.ofMillis(100);
    KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);

    Long oneHourEarlier =
        Instant.now().atZone(ZoneId.systemDefault()).minusHours(1).toEpochSecond();

    // consumer.assignment() 로 얻어온 컨슈머에 할당된 모든 파티션에 대해
    // 컨슈머를 되돌리고자 하는 타임스탬프 값을 담은 맵 생성
    Map<TopicPartition, Long> partitionTimestampMap =
        consumer.assignment().stream().collect(Collectors.toMap(tp -> tp, tp -> oneHourEarlier));

    // 각 타임스탬프에 대한 오프셋 받아옴
    // offsetsForTimes() 는 브로커에 요청을 보내서 타임스탬프 인덱스에 저장된 오프셋을 리턴함
    Map<TopicPartition, OffsetAndTimestamp> offsetMap = consumer.offsetsForTimes(partitionTimestampMap);

    // 각 파티션의 오프셋을 앞 단계에서 리턴된 오프셋으로 재설정
    for (Map.Entry<TopicPartition, OffsetAndTimestamp> entry: offsetMap.entrySet()) {
      consumer.seek(entry.getKey(), entry.getValue().offset());
    }
  }
}
```

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Kafka Doc](https://kafka.apache.org/documentation/)