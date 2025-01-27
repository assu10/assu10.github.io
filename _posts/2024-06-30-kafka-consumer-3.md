---
layout: post
title:  "Kafka - 컨슈머(3): 폴링 루프 벗어나기, 디시리얼라이저, 컨슈머 그룹없이 컨슈머 사용"
date: 2024-06-30
categories: dev
tags: kafka consumer consumer.wakeup shutdownHook serdes dereserializer avroDeserializer consumer.assign()
---

카프카에서 데이터를 읽는 애플리케이션은 토픽을 구독(subscribe) 하고, 구독한 토픽들로부터 메시지를 받기 위해 `KafkaConsumer` 를 사용한다.  
이 포스트에서는 카프카에 쓰여진 메시지를 읽기 위한 클라이언트에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap04) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 폴링 루프 벗어나기: `consumer.wakeup()`, `ShutdownHook`](#1-폴링-루프-벗어나기-consumerwakeup-shutdownhook)
* [2. 디시리얼라이저: `Serdes`](#2-디시리얼라이저-serdes)
  * [2.1. 커스텀 디시리얼라이저](#21-커스텀-디시리얼라이저)
  * [2.2. Avro 디시리얼라이저 사용: `AvroDeserializer`](#22-avro-디시리얼라이저-사용-avrodeserializer)
  * [2.3. `List<T>` 직렬화/역직렬화](#23-listt-직렬화역직렬화)
* [3. 컨슈머 그룹없이 컨슈머를 사용하는 경우: `KafkaConsumer.assign()`](#3-컨슈머-그룹없이-컨슈머를-사용하는-경우-kafkaconsumerassign)
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
    <kafka.version>3.8.0</kafka.version>
    <avro.version>1.12.0</avro.version>
    <confluent.version>7.7.0</confluent.version>
  </properties>

  <repositories>
    <repository>
      <id>confluent</id>
      <url>https://packages.confluent.io/maven/</url>
    </repository>
  </repositories>

  <dependencies>
    <dependency>
      <groupId>org.apache.kafka</groupId>
      <artifactId>kafka-clients</artifactId>
      <version>${kafka.version}</version>
    </dependency>

    <dependency>
      <groupId>org.apache.avro</groupId>
      <artifactId>avro</artifactId>
      <version>${avro.version}</version>
    </dependency>
    <dependency>
      <groupId>org.apache.avro</groupId>
      <artifactId>avro-maven-plugin</artifactId>
      <version>${avro.version}</version>
    </dependency>
    <dependency>
      <groupId>io.confluent</groupId>
      <artifactId>kafka-avro-serializer</artifactId>
      <version>${confluent.version}</version>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.avro</groupId>
        <artifactId>avro-maven-plugin</artifactId>
        <version>${avro.version}</version>
        <executions>
          <execution>
            <phase>generate-sources</phase>
            <goals>
              <goal>schema</goal>
              <goal>protocol</goal>
              <goal>idl-protocol</goal>
            </goals>
            <configuration>
              <sourceDirectory>${project.basedir}/src/main/resources/avro</sourceDirectory>
              <stringType>String</stringType>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
```

pom.xml (chap04_simplemovingavg)
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

  <artifactId>chap04_simplemovingavg</artifactId>

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

# 1. 폴링 루프 벗어나기: `consumer.wakeup()`, `ShutdownHook`

[4. 폴링 루프: `poll()`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#4-%ED%8F%B4%EB%A7%81-%EB%A3%A8%ED%94%84-poll) 에서 보면 
무한 루프에서 폴링을 수행하고 있는데 이제 루프를 깔끔하게 탈출하는 방법에 대해 알아본다.

**컨슈머를 종료하고나 할 때 컨슈머가 `poll()` 을 기다리고 있더라도 즉시 루프를 탈출하고 싶다면 다른 스레드에서 `consumer.wakeup()` 을 호출**해주면 된다.  
만일 **메인 스레드에서 컨슈머 루프가 돌고 있다면 `ShutdownHook` 을 사용**할 수 있다.

<**consumer.wakeup()**>  
- 다른 스레드에서 호출해줄 때만 안전하게 작동하는 유일한 컨슈머 메서드
- 이 메서드를 호출하면 대기중이던 `poll()` 이 _WakeupException_ 을 발생시키며 중단되거나, 대기중이 아닐 경우 다음 번에 처음으로 `poll()` 이 호출될 때 예외 발생
- _WakeupException_ 을 딱히 처리해 줄 필요는 없지만 `consumer.close()` 는 호출해주어야 함

컨슈머를 닫으면 필요한 경우 오프셋을 커밋하고, 그룹 코디네이터에게 컨슈머가 그룹을 떠난다는 메시지를 전송한다.  
이 때 컨슈머 코디네이터가 즉시 리밸런싱을 실행하므로 닫고 있던 컨슈머에게 할당되어 있던 파티션들이 그룹 안의 다른 컨슈머에게 할당될때까지 [세션 타임아웃](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#56-sessiontimeoutms-heartbeatintervalms)을 기다릴 필요가 없다.

아래는 메인 애플리케이션 스레드에서 돌아가는 컨슈머의 실행 루프를 종료시키는 예시이다.

SimpleMovingAvgNewConsumer.java
```java
package com.assu.study.chap04_simplemovingavg.newconsumer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections4.queue.CircularFifoQueue;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.WakeupException;
import org.apache.kafka.common.serialization.StringDeserializer;

// 메인 애플리케이션 스레드에서 돌아가는 컨슈머의 실행 루프 종료
@Slf4j
public class SimpleMovingAvgNewConsumer {
  private Properties kafkaProps = new Properties();
  private String waitTime;
  private KafkaConsumer<String, String> consumer;

  public static void main(String[] args) {
    if (args.length == 0) {
      log.error("need args: {brokers} {group.id} {topic} {window-size}");
      return;
    }

    final SimpleMovingAvgNewConsumer movingAvg = new SimpleMovingAvgNewConsumer();
    String brokers = args[0];
    String groupId = args[1];
    String topic = args[2];
    int windowSize = Integer.parseInt(args[3]);

    CircularFifoQueue queue = new CircularFifoQueue(windowSize);
    movingAvg.configure(brokers, groupId);

    final Thread mainThread = Thread.currentThread();

    // ShutdownHook 은 별개의 스레드에서 실행되므로 폴링 루프를 탈출하기 위해 할 수 있는 것은 wakeup() 을 호출하는 것 뿐임
    Runtime.getRuntime()
        .addShutdownHook(
            new Thread() {
              @Override
              public void run() {
                log.info("Starting exit...");
                movingAvg.consumer.wakeup();

                try {
                  mainThread.join();
                } catch (InterruptedException e) {
                  log.error("error: {}", e.getMessage());
                }
              }
            });

    try {
      movingAvg.consumer.subscribe(Collections.singletonList(topic));

      Duration timeout = Duration.ofMillis(10000);  // 10초

      //  Ctrl+c 가 눌리면 shutdownhook 정리 및 종료
      while (true) {
        // 타임아웃을 매우 길게 설정함
        // 만일 폴링 루프가 충분히 짧아서 종료되기 전에 좀 기다리는게 별로 문제가 되지 않는다면 굳이 wakeup() 을 호출해줄 필요가 없음
        // 즉, 그냥 이터레이션마다 아토믹 boolean 값을 확인하는 것만으로 충분함
        // 폴링 타임아웃을 길게 잡아주는 이유는 메시지가 조금씩 쌓이는 토픽에서 데이터를 읽어올 때 편리하기 때문임
        // 이 방법을 사용하면 브로커가 리턴할 새로운 데이터를 가지고 있지 않은 동안 계속해서 루프를 돌면서도 더 적은 CPU 를 사용할 수 있음
        ConsumerRecords<String, String> records = movingAvg.consumer.poll(timeout);
        log.info("{} -- waiting for data...", System.currentTimeMillis());

        for (ConsumerRecord<String, String> record : records) {
          log.info(
              "topic: {}, partition: {}, offset: {}, key: {}, value: {}",
              record.topic(),
              record.partition(),
              record.offset(),
              record.key(),
              record.value());

          int sum = 0;

          try {
            int num = Integer.parseInt(record.value());
            queue.add(num);
          } catch (NumberFormatException e) {
            // just ignore strings
          }

          for (Object o : queue) {
            sum += (Integer) o;
          }

          if (queue.size() > 0) {
            log.info("Moving avg is {}", (sum / queue.size()));
          }
        }
        for (TopicPartition tp : movingAvg.consumer.assignment()) {
          log.info("Committing offset at position: {}", movingAvg.consumer.position(tp));
        }

        movingAvg.consumer.commitSync();
      }
    } catch (WakeupException e) {
      // ignore for shutdown
      // 다른 스레드에서 wakeup() 을 호출할 경우, 폴링 루프에서 WakeupException 발생
      // 발생된 예외를 잡아줌으로써 애플리케이션이 예기치않게 종료되지 않도록 할 수 있지만 딱히 뭔가를 추가적으로 해 줄 필요ㅇ는 없음
    } finally {
      // 컨슈머 종료 전 닫아서 리소스 정리
      movingAvg.consumer.close();
      log.info("Closed consumer and done.");
    }
  }

  private void configure(String servers, String groupId) {
    kafkaProps.put(ConsumerConfig.GROUP_ID_CONFIG, servers);
    kafkaProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, servers);
    // 유효한 오프셋이 없을 경우 파티션의 맨 처음부터 모든 데이터 읽음
    kafkaProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
    kafkaProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    kafkaProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);

    consumer = new KafkaConsumer<>(kafkaProps);
  }
}
```

---

# 2. 디시리얼라이저:  `Serdes`

카프카 프로듀서는 카프카에 데이터를 쓰기 전 커스텀 객체를 바이트 객체로 변환하기 위해 시리얼라이저가 필요하다.  
마찬가지로, 카프카 컨슈머는 카프카로부터 받은 바이트 배열을 자바 객체로 변환하기 위해 디시리얼라이저가 필요하다.

시리얼라이저와 디시리얼라이저는 함께 쓰이는 만큼 같은 데이터 타입의 시리얼라이저와 디시리얼라이저를 묶어 놓은 클래스가 있는데 
`org.apache.kafka.common.serialization.Serdes` 클래스가 바로 그것이다.

```java
// org.apache.kafka.common.serialization.StringSerializer 리턴
Serializer<String> serializer = Serdes.String().serializer();

// org.apache.kafka.common.serialization.StringDeserializer 리턴
Deserializer<String> deserializer = Serdes.String().deserializer();
```

따라서 아래처럼 사용할 수도 있다.
```java
kafkaProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, Serdes.String().deserializer().getClass().getName());
kafkaProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, Serdes.String().deserializer().getClass().getName());
```

[1. 시리얼라이저](https://assu10.github.io/dev/2024/06/16/kafka-producer-2/#1-%EC%8B%9C%EB%A6%AC%EC%96%BC-%EB%9D%BC%EC%9D%B4%EC%A0%80) 에서 커스텀 타입을 직렬화하는 방법과 
카프카에 메시지를 쓸 때 메시지를 직렬화하기 위해 사용되는 Avro, 그리고 `KafkaAvroSerializer` 를 사용하여 스키마 정의로부터 Avro 객체를 어떻게 생성하는지에 대해 알아보았다.

여기서는 사용자 객체에 대해 사용할 수 있는 커스텀 디시리얼라이저를 정의하는 방법과 Avro 와 `AvroDeserializer` 를 사용하는 방법에 대해 알아본다.

당연히 카프카에 이벤트를 쓰기 위해 사용되는 시리얼라이저와 이벤트를 읽어오기 위해 사용되는 디시리얼라이저는 서로 맞아야 한다.  
즉, **개발자는 각 토픽에 데이터를 쓸 때 어떤 시리얼라이저를 사용했는지와 각 토픽에 사용 중인 디시리얼라이저가 읽어올 수 있는 데이터만 들어있는지 여부를 챙길 필요**가 있다.  
바로 이 점이 **직렬화/역직렬화 시 Avro 와 스키마 레지스트리를 사용하면 좋은 이유 중 하나**이다.  
즉, 대응하는 디시리얼라이저와 스키마를 사용하여 역직렬화할 수 있음을 보장하는 것이다.  
프로듀서 쪽이든 컨슈머 쪽이든 호환성에 문제가 발생하더라도 적절한 에러 메시지가 제공되기 때문에 쉽게 원인을 찾아낼 수 있다.  
(= 직렬화 에러가 발생한 바이트 배열을 일일이 디버깅하지 않아도 됨)

---

## 2.1. 커스텀 디시리얼라이저

> 아파치 에이브로를 사용하여 역직렬화하는 것을 강력히 권장하므로 커스텀 디시리얼라이저는 내용만 참고할 것

아래는 [1.1. 커스텀 시리얼라이저](https://assu10.github.io/dev/2024/06/16/kafka-producer-2/#11-%EC%BB%A4%EC%8A%A4%ED%85%80-%EC%8B%9C%EB%A6%AC%EC%96%BC%EB%9D%BC%EC%9D%B4%EC%A0%80) 에서 다뤘던 
커스텀 객체인 Customer 의 디시리얼라이저 예시이다.

Customer.java
```java
package com.assu.study.chap04.deserializer;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Getter
public class Customer {
  private final int customerId;
  private final String customerName;
}
```

CustomerDeserializer.java
```java
package com.assu.study.chap04.deserializer;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.apache.kafka.common.errors.SerializationException;
import org.apache.kafka.common.serialization.Deserializer;

// Customer 클래스를 위한 커스텀 디시리얼라이저

// 컨슈머에서도 Customer 클래스 필요
// 프로듀서에 사용되는 클래스 및 시리얼라이저는 컨슈머 애플리케이션에서도 같은 것이 사용되어야 함
// 같은 데이터를 공유해서 사용하는 컨슈머와 프로듀서의 수가 많은 조직에서는 꽤나 어려운 일임
public class CustomerDeserializer implements Deserializer<Customer> {
  @Override
  public Customer deserialize(String topic, byte[] data) {
    int id;
    int nameSize;
    String name;

    try {
      if (data == null) {
        return null;
      }

      if (data.length < 8) {
        throw new SerializationException(
            "Size of data received by deserializer is shorter than expected.");
      }

      ByteBuffer buf = ByteBuffer.wrap(data);
      id = buf.getInt();
      nameSize = buf.getInt();

      byte[] nameBytes = new byte[nameSize];
      buf.get(nameBytes);
      name = new String(nameBytes, StandardCharsets.UTF_8);

      // 고객 id 와 이름을 바이트 배열로부터 꺼내온 후 필요로 하는 객체 생성
      return new Customer(id, name);
    } catch (Exception e) {
      throw new SerializationException("Error when deserializing byte[] to Customer: ", e);
    }
  }

  @Override
  public void configure(Map<String, ?> configs, boolean isKey) {
    // nothing to configure
  }

  @Override
  public void close() {
    // nothing to close
  }
}
```

아래는 위의 디시리얼라이저를 사용하는 컨슈머 코드의 예시이다.

ConsumerUseCustomerDeserializer.java
```java
package com.assu.study.chap04.deserializer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.Serdes;

@Slf4j
public class ConsumerUseCustomerDeserializer {
  public static void main(String[] args) {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(
        ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
        Serdes.String().deserializer().getClass().getName());
    // CustomerDeserializer 클래스 설정
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, CustomerDeserializer.class.getName());
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CustomerCountry");

    Duration timeout = Duration.ofMillis(100);

    KafkaConsumer<String, Customer> consumer = new KafkaConsumer<>(props);
    consumer.subscribe(Collections.singletonList("topic"));

    while (true) {
      ConsumerRecords<String, Customer> records = consumer.poll(timeout);
      for (ConsumerRecord<String, Customer> record : records) {
        log.info(
            "current customer Id: {}, customer name: {}",
            record.value().getCustomerId(),
            record.value().getCustomerName());
      }
      consumer.commitSync();
    }
  }
}
```

이렇게 **커스텀 시리얼라이저와 디시리얼라이저를 직접 구현하는 것은 권장하지 않는다.**

**프로듀서와 컨슈머를 너무 밀접하게 연관시키는 탓에 깨지기도 쉽고 에러가 발생할 가능성이 높다.**

JSON, Thrift, Protobuf, Avro 와 같은 표준 메시지 형식을 사용하는 것이 더 좋다.

---

## 2.2. Avro 디시리얼라이저 사용: `AvroDeserializer`

이제 카프카 컨슈머에서 Avro 디시리얼라이저를 사용하는 방법에 대해 알아본다.

/resources/avro/LogLine.avsc
```avroschema
{
  "namespace": "javasessionize.avro",
  "type": "record",
  "name": "LogLine",
  "fields": [
    {
      "name": "ip",
      "type": "string"
    },
    {
      "name": "timestamp",
      "type": "long"
    },
    {
      "name": "url",
      "type": "string"
    },
    {
      "name": "referer",
      "type": "string"
    },
    {
      "name": "useragent",
      "type": "string"
    },
    {
      "name": "sessionid",
      "type": [
        "null",
        "int"
      ],
      "default": null
    }
  ]
}
```

> avro 파일 생성은 [1.3. 카프카에서 에이브로 레코드 사용: Schema Registry, KafkaAvroSerializer](https://assu10.github.io/dev/2024/06/16/kafka-producer-2/#13-%EC%B9%B4%ED%94%84%EC%B9%B4%EC%97%90%EC%84%9C-%EC%97%90%EC%9D%B4%EB%B8%8C%EB%A1%9C-%EB%A0%88%EC%BD%94%EB%93%9C-%EC%82%AC%EC%9A%A9-schema-registry-kafkaavroserializer) 을 참고하세요.

AvroConsumer.java
```java
package com.assu.study.chap04.avrosample;

import io.confluent.kafka.serializers.AbstractKafkaSchemaSerDeConfig;
import io.confluent.kafka.serializers.KafkaAvroDeserializer;
import io.confluent.kafka.serializers.KafkaAvroDeserializerConfig;
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import javasessionize.avro.LogLine;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.Serdes;

@Slf4j
public class AvroConsumer {
  private final KafkaConsumer<String, LogLine> consumer;
  private final KafkaProducer<String, LogLine> producer;
  private final String inputTopic;
  private final String outputTopic;
  private Map<String, SessionState> state = new HashMap<>();

  public AvroConsumer(
      String brokers, String groupId, String inputTopic, String outputTopic, String url) {
    this.consumer = new KafkaConsumer<>(createConsumerConfig(brokers, groupId, url));
    this.producer = getProducer(outputTopic, url);
    this.inputTopic = inputTopic;
    this.outputTopic = outputTopic;
  }

  public static void main(String[] args) throws ExecutionException, InterruptedException {
    // 하드 코딩
    String groupId = "avroSample";
    String inputTopic = "iTopic";
    String outputTopic = "oTopic";
    String url = "http://localhost:8081";
    String brokers = "localhost:9092";

    AvroConsumer avroConsumer = new AvroConsumer(brokers, groupId, inputTopic, outputTopic, url);

    avroConsumer.run();
  }

  private void run() throws ExecutionException, InterruptedException {
    consumer.subscribe(Collections.singletonList(inputTopic));

    log.info("Reading topic: {}", inputTopic);

    Duration timeout = Duration.ofMillis(1000);

    while (true) {
      // 레코드 밸류 타입으로 LogLine 지정
      ConsumerRecords<String, LogLine> records = consumer.poll(timeout);
      for (ConsumerRecord<String, LogLine> record : records) {
        String ip = record.key();
        LogLine event = record.value();

        SessionState oldState = state.get(ip);
        int sessionId = 0;

        if (oldState == null) {
          state.put(ip, new SessionState(event.getTimestamp(), 0));
        } else {
          sessionId = oldState.getSessionId();

          // old timestamp 가 30분 이전의 것이면 새로운 세션 생성
          if (oldState.getLastConnection() < event.getTimestamp() - (30 * 60 * 1000)) {
            sessionId = sessionId + 1;
          }
          SessionState newState = new SessionState(event.getTimestamp(), sessionId);
          state.put(ip, newState);
        }

        event.setSessionid(sessionId);

        log.info("event: {}", event);

        ProducerRecord<String, LogLine> sessionizedEvent =
            new ProducerRecord<>(outputTopic, event.getIp().toString(), event);
        producer.send(sessionizedEvent).get();
      }
      consumer.commitSync();
    }
  }

  private Properties createConsumerConfig(String brokers, String groupId, String url) {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, brokers);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
    props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
    props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
    // 스키마가 저장된 곳
    // 프로듀서가 등록한 스키마를 컨슈머가 역직렬화하기 위해 사용
    props.put(AbstractKafkaSchemaSerDeConfig.SCHEMA_REGISTRY_URL_CONFIG, url);
    props.put(KafkaAvroDeserializerConfig.SPECIFIC_AVRO_READER_CONFIG, true);
    props.put(
        ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
        Serdes.String().deserializer().getClass().getName());
    // Avro 메시지를 역직렬화하기 위해 KafkaAvroDeserializer 사용
    props.put(
        ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class.getName());

    return props;
  }

  private KafkaProducer<String, LogLine> getProducer(String topic, String url) {
    Properties props = new Properties();
    // 여기선 카프카 서버 URI 하드코딩
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    props.put(ProducerConfig.ACKS_CONFIG, "all");
    props.put(ProducerConfig.RETRIES_CONFIG, 0);
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());
    props.put(AbstractKafkaSchemaSerDeConfig.SCHEMA_REGISTRY_URL_CONFIG, url);

    KafkaProducer<String, LogLine> producer = new KafkaProducer<>(props);
    return producer;
  }
}
```

SessionState.java
```java
package com.assu.study.chap04.avrosample;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;

@RequiredArgsConstructor
@Getter
@Setter
public class SessionState {
  private final long lastConnection;
  private final int sessionId;
}
```

---

## 2.3. `List<T>` 직렬화/역직렬화

오랫동안 아파티 카프카는 기본 데이터 타입에 대한 시리얼라이저와 디시리얼라이저만을 제공해왔기 때문에 `List`, `Set`, `Map` 과 같은 복합 자료 구조를 사용하려면 
Avro 와 같은 직렬화 라이브러리를 사용할 수 밖에 없었다.

바이트 뭉치를 당기 위해 사용되는 `ByteArraySerializer`, `ByteSerializer`, `ByteBufferSerializer` 정도가 예외였을 뿐이다.

하지만 이제 카프카가 많이 활용되면서 아래의 내용이 추가되었다.

- 2.1.0 부터 **`UUID` 객체 (디)시리얼라이저 추가**
  - 중복이 없는 값을 생성하기 위해 uuid 를 사용하는 것이 일반적인 만큼 카프카 키나 밸류값으로도 자주 사용되기 때문에 추가됨
  - [KIP-206: Add support for UUID serialization and deserialization](https://cwiki.apache.org/confluence/display/KAFKA/KIP-206:+Add+support+for+UUID+serialization+and+deserialization)
- 2.5.0 부터 **`Void` 객체 (디)시리얼라이저 추가**
  - 키나 밸류값이 항상 null 이라는 것을 표시하기 위해 필요함
  - [KIP-527: Add VoidSerde to Serdes](https://cwiki.apache.org/confluence/display/KAFKA/KIP-527:+Add+VoidSerde+to+Serdes)
- 3.0 부터 **`List<T>` 타입 객체 (디)시리얼라이저 추가**
  - 스트림 처리에서 키 값을 기준으로 레코드들을 그룹화하는 것과 같이 집계 처리를 해야할 경우 사용됨
  - > `List<T>` 타입과 스트림 처리에 대한 내용은 추후 다룰 예정입니다. (p. 120)
  - [KIP-466: Add support for `List<T>` serialization and deserialization](https://cwiki.apache.org/confluence/display/KAFKA/KIP-466:+Add+support+for+List%3CT%3E+serialization+and+deserialization)


**`List<T>` 의 경우 중첩된 타입에 대한 기능인 만큼 생성 방식이 좀 복잡**하다.  
**심지어 키 값을 (디)시리얼라이즈하는 경우와 밸류값을 (디)시리얼라이즈하는 경우가 서로 다르다.**

아래는 키 값에 대한 시리얼라이저를 설정하는 예시이다.

ListSerializerSample.java
```java
package com.assu.study.chap04.list;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import org.apache.kafka.clients.CommonClientConfigs;
import org.apache.kafka.common.serialization.*;

// List<T> 에서 키 값에 대한 시리얼라이저, 디시리얼라이저
public class ListSerializerSample {
  // List<T> 키 값에 대한 시리얼라이저
  public void keySerializer() {
    // ListSerializer 객체 생성
    ListSerializer<?> listSerializer = new ListSerializer<>();

    // 생성한 객체 설정
    Map<String, Object> props = new HashMap<>();

    // 밸류값의 경우엔 default.list.value.serde.inner
    props.put(
        CommonClientConfigs.DEFAULT_LIST_KEY_SERDE_INNER_CLASS, Serdes.StringSerde.class.getName());

    // 밸류값의 경우엔 두 번째 인수가 false
    listSerializer.configure(props, true);

    // 설정된 시리얼라이저 얻어옴
    final Serializer<?> inner = listSerializer.getInnerSerializer();
  }

  // List<T> 키 값에 대한 디시리얼라이저
  public void keyDeserializer() {
    // ListDeserializer 객체 생성
    ListDeserializer<?> listDeserializer = new ListDeserializer<>();

    // 생성한 객체 설정
    Map<String, Object> props = new HashMap<>();

    // 바이트 뭉치를 디시리얼라이즈 한 뒤 ArrayList 객체 형태로 리턴
    // LinkedList.class.getName() 으로 설정해주면 LinkedList 객체가 리턴됨
    props.put(CommonClientConfigs.DEFAULT_LIST_KEY_SERDE_TYPE_CLASS, ArrayList.class.getName());

    // 밸류값의 경우엔 default.list.value.serde.inner
    props.put(
        CommonClientConfigs.DEFAULT_LIST_KEY_SERDE_INNER_CLASS, Serdes.StringSerde.class.getName());

    // 밸류값의 경우엔 두 번째 인수가 false
    listDeserializer.configure(props, true);

    // 설정된 디시리얼라이저 얻어옴
    final Deserializer<?> inner = listDeserializer.innerDeserializer();
  }
}
```

위 코드에서 디시리얼라이저의 경우 구체적인 List 타입을 지정하는 옵션이 하나 더 들어간다.
```java
// LinkedList.class.getName() 으로 설정해주면 LinkedList 객체가 리턴됨
props.put(CommonClientConfigs.DEFAULT_LIST_KEY_SERDE_TYPE_CLASS, ArrayList.class.getName());
```

일반적인 (디)시리얼라이저와 작동 방식도 약간 다르다.  
List 안에 들어있는 객체가 아래의 타입일 경우 각각의 객체를 시리얼라이즈할 때 객체 크기 정보를 집어넣지 않는다. (객체 크기가 고정되어 있으므로)
- short
- int
- long
- float
- double
- UUID

---

# 3. 컨슈머 그룹없이 컨슈머를 사용하는 경우: `KafkaConsumer.assign()`

컨슈머 그룹은 컨슈머들에게 파티션을 자동으로 할당해주고, 해당 그룹에 컨슈머가 추가/제거될 경우 자동으로 리밸런싱을 해준다.

하지만 경우에 따라서 훨씬 더 단순한 것이 필요할 수도 있다.  
예) 하나의 컨슈머가 토픽의 모든 파티션으로부터 모든 데이터를 읽어오거나, 토픽의 특정 파티션으로부터 데이터를 읽어와야 할 때

이럴 때는 컨슈머 그룹이나 리밸런스 기능이 필요없다.

그냥 컨슈머에게 특정한 토픽과 파티션을 할당해주고, 메시지를 읽어서 처리한 후 필요할 경우 오프셋을 커밋하면 된다.  
(컨슈머가 그룹에 조인할 일이 없으니 `subscribe()` 메서드를 호출할 일은 없겠지만 오프셋을 커밋하려면 여전히 `group.id` 값은 설정해주어야 함)

만일 **컨슈머가 어떤 파티션을 읽어야 하는지 알고 있을 경우 토픽을 구독(subscribe) 할 필요 없이 그냥 파티션을 스스로 할당받으면 된다.**

컨슈머는 토픽을 구독(= 컨슈머 그룹의 일원)하거나, 스스로 파티션을 할당받을 수 있지만 두 가지를 동시에 할 수는 없다.

아래는 컨슈머 스스로가 특정 토픽의 모든 파티션을 할당한 뒤 메시지를 읽고 처리하는 예시이다.

StandaloneConsumer.java
```java
package com.assu.study.chap04.standalone;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.PartitionInfo;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

// 컨슈머 그룹없이 컨슈머 스스로가 특정 토픽의 모든 파티션을 할당한 뒤 메시지를 읽고 처리
@Slf4j
public class StandaloneConsumer {
  public static void main(String[] args) {
    Properties props = new Properties();
    props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
    props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    props.put(ConsumerConfig.GROUP_ID_CONFIG, "CountryCounter");

    KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
    List<TopicPartition> partitions = new ArrayList<>();
    // 카프카 클러스터에 해당 토픽에 대해 사용 가능한 파티션들을 요청
    // 만일 특정 파티션의 레코드만 읽어올거면 생략해도 됨
    List<PartitionInfo> partitionInfos = consumer.partitionsFor("topic");

    if (partitions != null) {
      for (PartitionInfo partitionInfo : partitionInfos) {
        partitions.add(new TopicPartition(partitionInfo.topic(), partitionInfo.partition()));
      }

      // 읽고자 하는 파티션이 있다면 해당 목록에 `assign()` 으로 추가
      consumer.assign(partitions);

      Duration timeout = Duration.ofMillis(100);

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
        }
        consumer.commitSync();
      }
    }
  }
}
```

리밸런싱 기능을 사용할 수 없고, 직접 파티션을 찾아야 하는 점 외엔 나머지는 크게 다르지 않다.

만일 토픽에 새로운 파티션이 추가될 경우 컨슈머에게 알림이 오지 않으므로 주기적으로 `consumer.partitionsFor()` 를 호출하여 파티션 정보를 확인하거나, 
파티션이 추가될 때마다 애플리케이션을 재시작함으로써 알림이 오지 않는 상황에 대처해 줄 필요는 있다.

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