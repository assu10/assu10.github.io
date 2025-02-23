---
layout: post
title:  "Kafka - 스트림 처리(2): "
date: 2024-10-13
categories: dev
tags: kafka stream
---

- 카프카 스트림즈를 사용해서 주가의 이동 평균을 계산하는 예시
- 스트림 처리의 다른 모범적인 활용 사례
- 카프카와 함께 사용할 스트림 처리 프레임워크를 선택하기 위한 기준들

---

**목차**

<!-- TOC -->
* [1. 카프카 스트림즈: 예시](#1-카프카-스트림즈-예시)
  * [1.1. 단어 개수 세기: 맵/필터 패턴, 간단한 집계 연산](#11-단어-개수-세기-맵필터-패턴-간단한-집계-연산)
  * [1.2. 주식 시장 통계: 윈도우 집계](#12-주식-시장-통계-윈도우-집계)
  * [1.3. 클릭 스트림 확장: 스트리밍 조인](#13-클릭-스트림-확장-스트리밍-조인)
* [2. 카프카 스트림즈: 아키텍처](#2-카프카-스트림즈-아키텍처)
  * [2.1. 토폴로지 생성](#21-토폴로지-생성)
  * [2.2. 토폴로지 최적화](#22-토폴로지-최적화)
  * [2.3. 토폴로지 테스트](#23-토폴로지-테스트)
  * [2.4. 토폴로지 규모 확장](#24-토폴로지-규모-확장)
  * [2.5. 장애 처리](#25-장애-처리)
* [3. 스트림 처리 활용 사례](#3-스트림-처리-활용-사례)
* [4. 스트림 처리 프레임워크](#4-스트림-처리-프레임워크)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 카프카 스트림즈: 예시

여기서는 카프카 스트림즈 API 를 사용하는 예시에 대해 알아본다.

아파치 카프카는 저수준의 Processor API 와 고수준의 스트림즈 DSL, 2개의 스트림 API 를 제공한다.  
여기서는 고수준의 스트림즈 API 를 사용할 것이며, 이 DSL 을 사용하면 스트림에 포함된 이벤트에 일련의 연속적인 변환을 정의함으로써 스트림 처리 애플리케이션을 정의할 수 있다.  
여기서 변환은 필터와 같이 단순한 것일 수도 있고, 스트림-스트림 조인처럼 복잡한 것일수도 있다.

저수준 API 는 변환을 직접 생성할 수 있게 해준다.

> 저수준 API 에 대한 내용은 [Processor API](https://kafka.apache.org/28/documentation/streams/developer-guide/processor-api.html) 를 참고하세요.

DSL API 를 사용하는 애플리케이션은 항상 `StreamsBuilder` 를 사용하여 처리 토폴로지를 생성함으로써 시작한다.  
처리 토폴로지는 스트림 안의 이벤트에 적용되는 변환을 정점으로 하는 유향 비순환 그래프(DAG, Directed Acyclic Graph) 이다.

- **유향(Directed)**
  - 데이터 흐름이 명확하게 한 방향으로만 이동함
  - 예) Source → Transform → Sink (출발점에서 시작하여 종료점으로 이동)
- **비순환(Acyclic)**
  - 사이클이 존재하지 않음
  - 데이터가 한번 흐르면 같은 지점을 반복해서 방문하지 않음
  - 무한 루프나 데이터 처리의 중복을 방지함
- **그래프(Graph)**
  - 각 노드는 정점(Vertex) 이 되고, 데이터의 흐름(연산)은 간선(Edge) 로 연결됨
  - 예) 필터링, 매핑, 조인, 집계 등의 변환 연산이 각각 정점이 됨

처리 토폴로지를 생성하면 `KafkaStreams` 실행 객체를 생성하고, `KafkaStreams` 객체를 시작시키면 스트림 안의 이벤트에 처리 토폴로지를 적용하는 다수의 스레드가 시작된다.  
`KafkaStreams` 객체를 닫으면 처리는 끝난다.

<**DAG 의 장점**>
- **명확한 데이터 흐름**
  - 데이터가 어떻게 처리되고 이동하는지 한 눈에 파악할 수 있음
- **최적화 가능**
  - `KafkaStreams` 엔진이 DAG 를 기반으로 병렬 처리 및 최적화를 수행함
- **에러 방지**
  - 순환이 없기 때문에 무한 루프와 같은 문제가 발생되지 않음

<**`Kafka Streams` 의 토폴로지 구성 요소**>
- **Source Processor**
  - 입력 데이터를 가져오는 시작점
  - 예) 토픽에서 데이터를 읽어오는 부분
- **Processor**
  - 데이터를 처리하거나 변환하는 연산이 이루어지는 노드
  - 예) map(), filter(), flatMap() 등의 연산
- **State Store(상태 저장소)**
  - 상태를 유지하기 위한 저장소
  - 예) 집계, 조인 사용 시, `KTable` 의 상태 관리
- **Sink Processor**
  - 처리된 데이터를 외부로 출력하는 노드
  - 예) 다른 토픽으로 다시 전송, DB 저장

간단한 DAG 구조
```kotlin
val builder = StreamsBuilder()

// Source Node(입력 데이터 수신)
val sourceStream: KStream<String, String> = builder.stream("input-topic")

// Processor Node(데이터 변환)
val processedStream = sourceStream
  .fileter { _, value -> value.contains("important") }  // 필터링 노드
  .mapValues { value -> value.uppercase() } // 변환 노드

// Sink Node(출력 데이터 전송)
processedStream.to("output-topic")  // 결과 전송 노드
```

위를 DAG 구조로 표현하면 아래와 같다.

```shell
[input-topic] --> [filter] --> [mapValues] --> [output-topic]
```

- 정점(Vertex)
  - 각 변환 연산
- 간선(Edge)
  - 데이터 흐름의 방향성
- 비순환성(Acyclic)
  - 사이클없이 직선적인 처리 흐름 유지


`KTable` 조인의 DAG 구조 예시는 아래와 같다.

```shell
[user-topic] ----
                  --> [join] --> [output-topic]
[order-topic] ---
```

집계와 필터링 DAG 구조 예시는 아래와 같다.

```shell
[input-topic] --> [filter] --> [groupByKey] --> [aggregate] --> [output-topic]
```

---

## 1.1. 단어 개수 세기: 맵/필터 패턴, 간단한 집계 연산

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap14_1) 에 있습니다.

여기서는 카프카 스트림즈를 이용하여 단어 개수를 세는 예시에 대해 알아본다.

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

    <artifactId>chap14_1</artifactId>

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
            <artifactId>kafka-streams</artifactId>
            <version>${kafka.version}</version>
        </dependency>

    </dependencies>
</project>
```

스트림 처리 애플리케이션을 개발하기 위해 가장 먼저 할 일은 **카프카 스트림즈를 설정**하는 것이다.

```java
package com.assu.study.chap14_1;

import java.util.Arrays;
import java.util.Properties;
import java.util.regex.Pattern;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.KStream;

public class WordCountExample {
  public static void main(String[] args) {
    Properties props = new Properties();

    // 모든 카프카 스트림즈 애플리케이션은 애플리케이션 ID 를 가짐
    // 애플리케이션 ID 는 내부에서 사용하는 로컬 저장소와 여기 연관된 토픽에 이름을 정할때도 사용됨
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "wordcount");

    // 카프카 스트림즈 애플리케이션은 항상 카프카 토픽에서 데이터를 읽어서 결과를 카프카 토픽에 씀
    // 카프카 스트림즈 애플리케이션은 인스턴스끼리 서로 협력하도록 할 때도 카프카를 사용하므로 애플리케이션이 카프카를 찾을 방법을 지정해주어야 함
    props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

    // 데이터를 읽고 쓸 때 애플리케이션은 직렬화/역직렬화를 해야하므로 기본값으로 쓰일 Serde 클래스 지정
    // 필요하다면 스트림즈 토폴로지를 생성할 때 재정의할 수도 있음
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
  }
}
```

설정을 했으니 이제 **스트림즈 토폴로지를 생성**한다.

```java
// StreamBuilder 객체를 생성하고, 앞으로 입력으로 사용할 토픽 지정
StreamsBuilder builder = new StreamsBuilder();
KStream<String, String> source = builder.stream("wordcount-input");

final Pattern pattern = Pattern.compile("\\W+");
KStream counts =
    source
        // 입력 토픽에서 읽어오는 각 이벤트는 단어들로 이루어진 문자열 한 줄임
        // 정규식을 사용하여 이 문자열을 다수의 단어들로 분할한 후 현재 이벤트 레코드의 밸류값인 각 단어를 가져다가 이벤트 레코드 키로 넣어줌으로써 그룹화에 사용될 수 있도록 함 
        .flatMapValues(value -> Arrays.asList(pattern.split(value.toLowerCase())))  // KStream<String, String> 반환
        .map((key, value) -> new KeyValue<Object, Object>(value, value))  // KStream<Object, Object> 반환
        // 단어 "the" 를 필터링함 (필터링을 이렇게 쉽게 할 수 있음)
        .filter((key, value) -> (!value.equals("the"))) // KStream<Object, Object> 반환
        // 키 값을 기준으로 그룹화함으로써 각 단어별로 이벤트의 집합을 얻어냄
        .groupByKey() // KGroupedStream<Object, Object> 반환
        .count()  // KTable<Object, Long> 반환
        // 각 집합에 얼마나 많은 이벤트가 포함되어 있는지 셈
        // 계산 결과는 Long 타입임
        .mapValues(value -> Long.toString(value))
        .toStream();

// 결과를 카프카에 씀
counts.to("wordcount-output");
```

애플리케이션을 수행할 변환의 흐름을 정의했으니 이제 **실행**시킨다.

```java
// 위에서 정의한 토폴로지와 설정값을 기준으로 KafkaStreams 객체 정의
KafkaStreams streams = new KafkaStreams(builder.build(), props);

// 동작을 재설정하기 위한 것임
// 프로덕션에서는 절대 사용하지 말 것
// 시작할 때마다 애플리케이션이 Kafka 의 상태를 재로드함
streams.cleanUp();

// 카프카 스트림즈 시작
streams.start();

Thread.sleep(5_000L);

// 잠시 뒤 멈춤
streams.close();
```

`groupBy()` 를 사용해서 데이터를 리파티션한 뒤 각 단어의 개수를 셀 때마다 각 단어를 키 값으로 갖는 레코드의 개수를 저장하는 단순한 로컬 상태를 유지한다.  
만일 입력 토픽이 여러 개의 파티션을 갖고 있다면 애플리케이션 인스턴스를 여러 개 띄움으로써 카프카 스트림즈 처리 클러스터를 구성할 수 있다.

카프카 스트림즈 API 를 사용하면 단순히 애플리케이션 인스턴스를 여러 개 띄우는 것만으로도 처리 클러스터를 구성할 수 있다.

---

## 1.2. 주식 시장 통계: 윈도우 집계

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap14_2) 에 있습니다.

> 주식을 프로듀싱하는 코드는 [Git:: 주식 시장 통계 전체 코드](https://github.com/gwenshap/kafka-streams-stockstats) 를 참고하세요.

여기서는 주식의 종목 콛, 호가와 수량을 포함하는 주식 시장 거래 이벤트 스트림을 읽어오는 예시에 대해 알아본다.

- 매도 호가(ask price): 매도자가 팔고자 하는 가격
- 매수 호가(bid price): 매수자가 사고자 하는 가격
- 매도량(ask size): 매도자가 지정된 가격으로 팔고자 하는 주식의 양

여기서는 단순화를 위해 매수 쪽은 완전히 무시하고, 데이터에 타임스탬프도 포함하지 않고 카프카 프로듀서가 부여하는 이벤트 시간을 대신 사용한다.

아래와 같은 윈도우가 적용된 통계값을 포함하는 결과 스트림을 생성한다.
- 5초 단위 시간 윈도우별로 가장 좋은(최저) 매도가
- 5초 단위 시간 윈도우별 거래량
- 5초 단위 시간 윈도우별 평균 매도가

모든 통계값은 매초 갱신되며, 단순화를 위해 10개의 종목만 거래되고 있다고 가정한다.

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

    <artifactId>chap14_2</artifactId>

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
            <artifactId>kafka-streams</artifactId>
            <version>${kafka.version}</version>
        </dependency>
        <dependency>
            <groupId>com.google.code.gson</groupId>
            <artifactId>gson</artifactId>
            <version>2.12.1</version>
        </dependency>
    </dependencies>
</project>
```

먼저 **카프카 스트림즈를 설정**한다.

Chap142Application.java
```java
// input 은 거래의 스트림임
// output 은 2개의 스트림임
// - 10초마다 최소 및 평균 매도 호가를 가짐
// - 매분 최소 매도 호가가 가장 낮은 상위 3개 주식
public class Chap142Application {

  public static void main(String[] args) throws IOException {
    // ===== 애플리케이션 설정
    Properties props;
    if (args.length == 1) {
      props = LoadConfig.loadConfig(args[0]);
    } else {
      props = LoadConfig.loadConfig();
    }
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "stockstat-2");
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, TradeSerde.class.getName());
  }

  // 키는 문자열이지만 밸류는 종목 코드, 매도 호가, 매도량을 포함하는 Trade 를 사용할 것이므로 이 객체를 
  // 직렬화/역직렬화하기 위해 Gson 라이브러리를 사용해서 자바 객체에 대한 시리얼라이저/디시리얼라이저 생성
  public static final class TradeSerde extends CustomWrapperSerde<Trade> {
    public TradeSerde() {
      super(new CustomJsonSerializer<Trade>(), new CustomJsonDeserializer<>(Trade.class));
    }
  }
}
```

[1.1. 단어 개수 세기: 맵/필터 패턴, 간단한 집계 연산](#11-단어-개수-세기-맵필터-패턴-간단한-집계-연산) 에서는 키와 밸류 모두 문자열을 사용했기 때문에 
시리얼라이저와 디시리얼라이저 둘 다 `Serde.String()` 클래스를 사용했다.  
여기서는 키는 여전히 문자열이지만 밸류는 종목 코드, 매도 호가, 매도량을 포함하는 _Trade_ 를 사용할 것이기 때문에 이 객체를 직렬화/역직렬화하기 위해 [커스텀 시리얼라이저]()https://assu10.github.io/dev/2024/06/22/kafka-producer-2/#11-%EC%BB%A4%EC%8A%A4%ED%85%80-%EC%8B%9C%EB%A6%AC%EC%96%BC%EB%9D%BC%EC%9D%B4%EC%A0%80와 
[디시리얼라이저](https://assu10.github.io/dev/2024/06/30/kafka-consumer-3/#21-%EC%BB%A4%EC%8A%A4%ED%85%80-%EB%94%94%EC%8B%9C%EB%A6%AC%EC%96%BC%EB%9D%BC%EC%9D%B4%EC%A0%80)를 생성한다.

편한 작업을 위해 Gson, Avro, Protobuf 와 같은 라이브러리를 사용해서 `Serde` 를 생성하는 것이 좋다.

LoadConfig.java
```java
package com.assu.study.chap14_2;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Properties;

/**
 * 파일에서 구성 로드
 * 주로 연결 정보를 위한 것으로 다시 컴파일하지 않고도 클러스터 간에 전환할 수 있음
 */
public class LoadConfig {
    private static final String DEFAULT_CONFIG_FILE =
            System.getProperty("user.home") + File.separator + ".ccloud" + File.separator + "config";

    static Properties loadConfig() throws IOException {
        return loadConfig(DEFAULT_CONFIG_FILE);
    }

    static Properties loadConfig(String configFile) throws IOException {
        if (!Files.exists(Paths.get(configFile))) {
            throw new RuntimeException(configFile + "does not exists.");
        }

        final Properties cfg = new Properties();

        try (InputStream inputStream = new FileInputStream(configFile)) {
            cfg.load(inputStream);
        }
        return cfg;
    }
}
```

/model/Trade.java
```java
package com.assu.study.chap14_2.model;

public class Trade {
  String type;
  String ticker;
  double price;
  int size;

  public Trade(String type, String ticker, double price, int size) {
    this.type = type;
    this.ticker = ticker;
    this.price = price;
    this.size = size;
  }

  @Override
  public String toString() {
    return "Trade{"
        + "type='"
        + type
        + '\''
        + ", ticker='"
        + ticker
        + '\''
        + ", price="
        + price
        + ", size="
        + size
        + '}';
  }
}
```

/serde/CustomJsonSerializer.java
```java
package com.assu.study.chap14_2.serde;

import com.google.gson.Gson;
import java.nio.charset.Charset;
import java.util.Map;
import org.apache.kafka.common.serialization.Serializer;

public class CustomJsonSerializer<T> implements Serializer<T> {
  private Gson gson = new Gson();

  @Override
  public void configure(Map<String, ?> map, boolean b) {}

  @Override
  public byte[] serialize(String topic, T t) {
    return gson.toJson(t).getBytes(Charset.forName("UTF-8"));
  }

  @Override
  public void close() {}
}
```

/serde/CustomJsonDeserializer.java
```java
package com.assu.study.chap14_2.serde;

import com.google.gson.Gson;
import java.util.Map;
import org.apache.kafka.common.serialization.Deserializer;

public class CustomJsonDeserializer<T> implements Deserializer<T> {
  private Gson gson = new Gson();
  private Class<T> deserializedClass;

  public CustomJsonDeserializer(Class<T> deserializedClass) {
    this.deserializedClass = deserializedClass;
  }

  public CustomJsonDeserializer() {}

  @Override
  @SuppressWarnings("unchecked")
  public void configure(Map<String, ?> map, boolean b) {
    if (deserializedClass == null) {
      deserializedClass = (Class<T>) map.get("serializedClass");
    }
  }

  @Override
  public T deserialize(String s, byte[] bytes) {
    if (bytes == null) {
      return null;
    }

    return gson.fromJson(new String(bytes), deserializedClass);
  }

  @Override
  public void close() {}
}
```

/serde/CustomWrapperSerde.java
```java
package com.assu.study.chap14_2.serde;

import java.util.Map;
import org.apache.kafka.common.serialization.Deserializer;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serializer;

public class CustomWrapperSerde<T> implements Serde<T> {
    final private Serializer<T> serializer;
    final private Deserializer<T> deserializer;

    public CustomWrapperSerde(Serializer<T> serializer, Deserializer<T> deserializer) {
        this.serializer = serializer;
        this.deserializer = deserializer;
    }

    @Override
    public void configure(Map<String, ?> configs, boolean isKey) {
        serializer.configure(configs, isKey);
        deserializer.configure(configs, isKey);
    }

    @Override
    public void close() {
        serializer.close();
        deserializer.close();
    }

    @Override
    public Serializer<T> serializer() {
        return serializer;
    }

    @Override
    public Deserializer<T> deserializer() {
        return deserializer;
    }
}
```

설정이 끝났으면 이제 **토폴로지를 생성**한다.

전체 코드
```java
package com.assu.study.chap14_2;

import com.assu.study.chap14_2.model.Trade;
import com.assu.study.chap14_2.model.TradeStats;
import com.assu.study.chap14_2.serde.CustomJsonDeserializer;
import com.assu.study.chap14_2.serde.CustomJsonSerializer;
import com.assu.study.chap14_2.serde.CustomWrapperSerde;
import java.io.IOException;
import java.time.Duration;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.DescribeClusterResult;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.common.utils.Bytes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;
import org.apache.kafka.streams.kstream.WindowedSerdes;
import org.apache.kafka.streams.state.WindowStore;

// input 은 거래의 스트림임
// output 은 2개의 스트림임
// - 10초마다 최소 및 평균 매도 호가를 가짐
// - 매분 최소 매도 호가가 가장 낮은 상위 3개 주식
public class Chap142Application {

  public static void main(String[] args)
      throws IOException, ExecutionException, InterruptedException {
    // ===== 애플리케이션 설정
    Properties props;
    if (args.length == 1) {
      props = LoadConfig.loadConfig(args[0]);
    } else {
      props = LoadConfig.loadConfig();
    }
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "stockstat-2");
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, TradeSerde.class.getName());

    // 미리 로드된 동일한 데이터를 데모 코드로 재실행하기 위해 오프셋을 earliest 로 설정
    // 데모를 재실행하려면 오프셋 재설정 도구를 사용해야 함
    // https://cwiki.apache.org/confluence/display/KAFKA/Kafka+Streams+Application+Reset+Tool
    props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

    // 집계 윈도우의 시간 간격(ms)
    long windowSize = 5000; // (5s)

    // AdminClient 를 생성하고 클러스터의 브로커 수를 확인하여 원하는 replicas 수를 알 수 있음
    AdminClient adminClient = AdminClient.create(props);
    DescribeClusterResult describeClusterResult = adminClient.describeCluster();
    int clusterSize = describeClusterResult.nodes().get().size();

    if (clusterSize < 3) {
      props.put("replication.factor", clusterSize);
    } else {
      props.put("replication.factor", 3);
    }

    // ===== 스트림즈 토폴로지 생성
    // StreamBuilder 객체를 생성하고, 앞으로 입력으로 사용할 토픽 지정
    StreamsBuilder builder = new StreamsBuilder();
    KStream<String, Trade> source = builder.stream(Constants.STOCK_TOPIC);

    // 토폴로지 생성
    KStream<Windowed<String>, TradeStats> stats =
        source
            // 입력 토픽에서 이벤트를 읽어오지만 그룹화는 하지 않음
            // 대신 이벤트 스트림이 레코드 키 기준으로 파티셔닝되도록 해줌
            // 이 경우 토픽에 데이터를 쓸 때의 키 값을 가지는 데이터를 사용하고, groupByKey() 를 호출하기 전에 변경하지 않았으므로
            // 데이터는 여전히 키 값을 기준으로 파티셔닝되어 있음
            .groupByKey() // KGroupedStream<String, Trade>
            // 윈도우 정의
            // 이 경우 윈도우는 5초의 길이를 갖고 있으며, 매초 전진함
            .windowedBy(
                TimeWindows.of(Duration.ofMillis(windowSize))
                    .advanceBy(Duration.ofSeconds(1))) // TimeWindowedKStream<Stream<String, Trade>>
            // 데이터가 원하는대로 파티셔닝되고 윈도우도 적용되었으면 집계 작업을 시작함
            // aggregate() 는 스트림을 서로 중첩되는 윈도우들도 나눈 뒤(여기서는 1초마다 겹치는 5초 길기의 시간 윈도우)
            // 각 윈도우에 배정된 모든 이벤트에 대해 집계 연산을 적용함
            .<TradeStats>aggregate(
                // 첫 번째 파라메터는 집계 결과를 저장할 새로운 객체를 받음, 여기서는 TradeStats
                // 이 객체는 각 시간 윈도우에서 알고자하는 모든 통계를 포함하기 위해 생성한 객체로 최저 매도가, 평균 매도가, 거래량을 포함함
                () -> new TradeStats(),
                // 실제로 집계를 수행하는 메서드 지정
                // 여기서는 새로운 레코드를 생성함으로써 해당 윈도우에서의 최저 매도가, 거래량, 매도 총량을 업데이트하기 위해 TradeStats.add() 를
                // 사용함
                (k, v, tradestats) -> tradestats.add(v),
                Materialized
                    // 윈도우가 적용된 집계 작업에서는 상태를 저장할 로컬 저장소를 유지할 필요가 있음
                    // aggregate() 의 마지막 파라메터는 상태 저장소 설정임
                    // Materialized 는 저장소를 설정하는데 사용되는 객체로서 여기서는 저장소의 이름을 trade-aggregates 로 함
                    .<String, TradeStats, WindowStore<Bytes, byte[]>>as("trade-aggregates")
                    // 상태 저장소 설정의 일부로서 집계 결과인 Tradestats 를 직렬화/역직렬화하기 위한 Serde 객체를 지정해주어야 함
                    .withValueSerde(new TradeStatsSerde())) // KTable<Windowed<String>, TradeStats>
            // 집계 결과는 종목 기호와 시간 윈도우를 기본키로, 집계 결과를 밸류값으로 하는 테이블임
            // 이 테이블을 이벤트 스트림으로 되돌릴것임
            .toStream() // KStream<Windowed<String>, TradeStats>
            // 평균 가격을 갱신해 줌
            // 현재 시점에서 집계 결과는 가격과 거래량의 합계를 포함함
            // 이 레코드를 사용하여 평균 가격을 계산한 뒤 출력 스트림으로 내보냄
            .mapValues((trade) -> trade.computeAvgPrice());

    // 결과를 stockstats-output 스트림에 씀
    // 결과물이 윈도우 작업의 일부이므로 결과물을 윈도우 타임스탬프와 함께 윈도우가 적용된 데이터 형식으로 저장하는 WindowedSerde 를 생성해줌
    // 윈도우 크기가 직렬화 과정에서 사용되는 것은 아니지만 출력 토픽에 윈도우의 시작 시간이 저장되기 때문에 역직렬화는 윈도우의 크기를 필요로하므로 Serde 의 일부로서
    // 전달함
    stats.to(
        "stockstats-output",
        Produced.keySerde(WindowedSerdes.timeWindowedSerdeFrom(String.class, windowSize)));

    // ===== 스트림 객체 생성 후 실행
    Topology topology = builder.build();
    KafkaStreams streams = new KafkaStreams(topology, props);
    System.out.println(topology.describe());
    // 동작을 재설정하기 위한 것임
    // 프로덕션에서는 절대 사용하지 말 것
    // 시작할 때마다 애플리케이션이 Kafka 의 상태를 재로드함
    streams.cleanUp();

    streams.start();

    // SIGTERM 에 응답하고 카프카 스트림즈를 gracefully 하게 종료시키는 shutdown hook 추가
    Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
  }

  // 키는 문자열이지만 밸류는 종목 코드, 매도 호가, 매도량을 포함하는 Trade 를 사용할 것이므로 이 객체를
  // 직렬화/역직렬화하기 위해 Gson 라이브러리를 사용해서 자바 객체에 대한 시리얼라이저/디시리얼라이저 생성
  public static final class TradeSerde extends CustomWrapperSerde<Trade> {
    public TradeSerde() {
      super(new CustomJsonSerializer<Trade>(), new CustomJsonDeserializer<>(Trade.class));
    }
  }

  public static final class TradeStatsSerde extends CustomWrapperSerde<TradeStats> {
    public TradeStatsSerde() {
      super(new CustomJsonSerializer<>(), new CustomJsonDeserializer<>());
    }
  }
}
```

Constants.java
```java
package com.assu.study.chap14_2;

public class Constants {
  public static final String STOCK_TOPIC = "stocks";
}
```

/model/TradeStats.java
```java
package com.assu.study.chap14_2.model;

public class TradeStats {
  String type;
  String ticker;
  int countTrades; //  평균 단가를 계산하기 위함
  double sumPrice;
  double minPrice;
  double avgPrice;

  public TradeStats add(Trade trade) {
    if (trade.type == null || trade.ticker == null) {
      throw new IllegalArgumentException("Invalid trade to aggregate: " + trade.toString());
    }

    if (this.type == null) {
      this.type = trade.type;
    }
    if (this.ticker == null) {
      this.ticker = trade.ticker;
    }

    if (!this.type.equals(trade.type) || !this.ticker.equals(trade.ticker)) {
      throw new IllegalArgumentException(
          "Aggregating stats for trade type: " + this.type + "and ticker: " + this.ticker);
    }

    if (countTrades == 0) {
      this.minPrice = trade.price;
    }

    this.countTrades = this.countTrades + 1;
    this.sumPrice = this.sumPrice + trade.price;
    this.minPrice = this.minPrice < trade.price ? this.minPrice : trade.price;

    return this;
  }

  // 평균 단가 계산
  public TradeStats computeAvgPrice() {
    this.avgPrice = this.sumPrice / this.countTrades;
    return this;
  }
}
```

이 예시는 윈도우가 적용된 집계 연산을 스트림에 대해 수행하는 방법을 보여주며, 아마도 이 예시가 가장 많이 사용되는 스트림 처리 사례일 것이다.  
집계 작업의 로컬 상태를 유지하기 위해 단지 Serde 와 상태 저장소의 이름만 지정해주면 된다.

이 애플리케이션은 여러 인스턴스로 확장이 가능하면서도 각 인스턴스에 장애가 발생할 경우, 일부 파티션에 대한 처리 작업을 다른 인스턴스로 이전함으로써 자동으로 복구된다.

> 장애 발생 시 자동으로 복구되는 내용에 대해서는 추후 다룰 예정입니다. (p. 450)

---

## 1.3. 클릭 스트림 확장: 스트리밍 조인

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap14_3) 에 있습니다.

여기서는 웹사이트 클릭 스트림을 확장하는 스트리밍 조인에 대해 알아본다.

모의 클릭 스트림, 가상의 프로필 DB 테이블에 대한 업데이트 스트림, 웹 검색 스트림을 생성한 후 사용자 행동에 대한 종합적인 뷰를 얻기 위해 이 셋을 조인할 것이다.  
이러한 조인은 사용자들이 무엇을 검색하고, 검색 결과 중 무엇을 클릭하는지 등 분석 작업을 위한 풍부한 데이터 집합을 제공한다.  
상품 추천은 보통 이러한 종류의 정보에 기반한다.

```java
package com.assu.study.chap14_3;

import com.assu.study.chap14_3.model.PageView;
import com.assu.study.chap14_3.model.Search;
import com.assu.study.chap14_3.model.UserActivity;
import com.assu.study.chap14_3.model.UserProfile;
import com.assu.study.chap14_3.serde.CustomJsonDeserializer;
import com.assu.study.chap14_3.serde.CustomJsonSerializer;
import com.assu.study.chap14_3.serde.CustomWrapperSerde;
import java.time.Duration;
import java.util.Properties;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.JoinWindows;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.KTable;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.StreamJoined;

public class Chap143Application {

  public static void main(String[] args) throws InterruptedException {
    Properties props = new Properties();
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "clicks");
    props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, Constants.BROKER);

    // 스트림의 각 단계는 서로 다른 객체가 포함되기 때문에 기본 Serde 사용 불가

    // 미리 로드된 동일한 데이터를 데모 코드로 재실행하기 위해 오프셋을 earliest 로 설정
    // 데모를 재실행하려면 오프셋 재설정 도구를 사용해야 함
    // https://cwiki.apache.org/confluence/display/KAFKA/Kafka+Streams+Application+Reset+Tool
    props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

    StreamsBuilder builder = new StreamsBuilder();

    // ===== 다수의 스트림을 조인하는 토폴로지

    // 조인하고자 하는 2개의 스트림 객체인 클릭과 검색 스트림 생성
    // 스트림 객체 생성 시 입력 토픽 뿐 아니라 토픽 데이터를 읽어서 객체로 역직렬화할 때 사용될 키, 밸류에 대한 Serde 역시 지정해주어야 함
    KStream<Integer, PageView> views =
        builder.stream(
            Constants.PAGE_VIEW_TOPIC, Consumed.with(Serdes.Integer(), new PageViewSerde()));

    KStream<Integer, Search> searches =
        builder.stream(Constants.SEARCH_TOPIC, Consumed.with(Serdes.Integer(), new SearchSerde()));

    // 사용자 프로필을 저장할 KTable 객체 정의
    // KTable 은 변경 스트림에 의해 갱신되는 구체화된 저장소(materialized store)임
    KTable<Integer, UserProfile> profiles =
        builder.table(
            Constants.USER_PROFILE_TOPIC, Consumed.with(Serdes.Integer(), new ProfileSerde()));

    // 스트림-테이블 조인
    KStream<Integer, UserActivity> viewsWithProfile =
        // 클릭 스트림을 사용자 프로필 정보 테이블과 조인함으로써 확장함
        // 스트림-테이블 조인에서 스트림의 각 이벤트는 프로필 테이블의 캐시된 사본에서 정보를 받음
        // left join 이므로 해당하는 사용자 정보가 없는 클릭도 보존됨
        views.leftJoin(
            profiles,
            (page, profile) -> {
              if (profile != null) {
                // 조인 메서드임
                // 스트림과 레코드에서 하나씩 값을 받아서 또 다른 값을 리턴함
                // 두 개의 값을 결합해서 어떻게 하나의 결과로 만들지 여기서 결정해야 함
                // 여기서는 사용자 프로필과 페이지 뷰 둘 다 포함하는 하나의 UserActivity 객체를 생성함
                return new UserActivity(
                    profile.getUserId(),
                    profile.getUserName(),
                    profile.getZipcode(),
                    profile.getInterests(),
                    "",
                    page.getPage());
              } else {
                return new UserActivity(-1, "", "", null, "", page.getPage());
              }
            });

    // 스트림-스트림 조인
    KStream<Integer, UserActivity> userActivityKStream =
        // 같은 사용자에 의해 수행된 클릭 정보와 검색 정보 조인
        // 이번엔 스트림을 테이블에 조인하는 것이 아니라 두 개의 스트림을 조인하는 것임
        viewsWithProfile.leftJoin(
            searches,
            (userActivity, search) -> {
              if (search != null) {
                // 조인 메서드임
                // 단순히 맞춰지는 모든 페이지 뷰에 검색어들을 추가해줌
                userActivity.updateSearch(search.getSearchTerms());
              } else {
                userActivity.updateSearch("");
              }
              return userActivity;
            },
            // 스트림-스트림 조인은 시간 윈도우를 사용하는 조인이므로 각 사용자의 모든 클릭과 검색을 조인하는 것은 적절하지 않음
            // 검색 이후 짧은 시간 안에 발생한 클릭을 조인함으로써 검색과 거기 연관된 클릭만을 조인해야 함
            // 따라서 1초 길이의 조인 윈도우를 정의(= 검색 전과 후의 1초 길이의 윈도우)한 뒤 0초 간격으로 before() 를 호출해서 검색 후 1초 동안
            // 발생한 클릭만 조인함
            // 이 때 검색 전 1초는 제외됨
            // 그 결과는 관련이 있는 클릭과 검색어, 사용자 프로필을 포함하게 됨
            // 즉, 검색과 그 결과 전체에 대해 분석 수행이 가능해짐
            JoinWindows.of(Duration.ofSeconds(1)).before(Duration.ofSeconds(0)),
            // 조인 결과에 대한 Serde 를 정의함
            // 조인 양쪽에 공통인 키 값에 대한 Serde 와 조인 결과에 포함될 양쪽의 밸류값에 대한 Serde 를 포함함
            // 여기서는 키는 사용자 id 이므로 단순한 Integer 형 Serde 를 사용함
            StreamJoined.with(Serdes.Integer(), new UserActivitySerde(), new SearchSerde()));

    userActivityKStream.to(
        Constants.USER_ACTIVITY_TOPIC, Produced.with(Serdes.Integer(), new UserActivitySerde()));

    KafkaStreams streams = new KafkaStreams(builder.build(), props);

    // 동작을 재설정하기 위한 것임
    // 프로덕션에서는 절대 사용하지 말 것
    // 시작할 때마다 애플리케이션이 Kafka 의 상태를 재로드함
    streams.cleanUp();

    streams.start();

    Thread.sleep(60_000L);

    // 잠시 뒤 멈춤
    streams.close();
  }

  public static final class PageViewSerde extends CustomWrapperSerde<PageView> {
    public PageViewSerde() {
      super(new CustomJsonSerializer<>(), new CustomJsonDeserializer<>(PageView.class));
    }
  }

  public static final class ProfileSerde extends CustomWrapperSerde<UserProfile> {
    public ProfileSerde() {
      super(new CustomJsonSerializer<>(), new CustomJsonDeserializer<>(UserProfile.class));
    }
  }

  public static final class SearchSerde extends CustomWrapperSerde<Search> {
    public SearchSerde() {
      super(new CustomJsonSerializer<>(), new CustomJsonDeserializer<>(Search.class));
    }
  }

  public static final class UserActivitySerde extends CustomWrapperSerde<UserActivity> {
    public UserActivitySerde() {
      super(new CustomJsonSerializer<>(), new CustomJsonDeserializer<>(UserActivity.class));
    }
  }
}
```

위 예시는 스트림 처리에서 가능한 2가지 서로 다른 조인 패턴을 보여준다.
- 스트림과 테이블을 조인함으로써 스트림 이벤트를 테이블에 저장된 정보로 확장시킴
- 시간 윈도우를 기준으로 2개의 스트림을 조인함

/model/PageView.java
```java
package com.assu.study.chap14_3.model;

public class PageView {
  int userId;
  String page;

  public PageView(int userId, String page) {
    this.userId = userId;
    this.page = page;
  }

  public int getUserId() {
    return userId;
  }

  public String getPage() {
    return page;
  }
}
```

/model/Search.java
```java
package com.assu.study.chap14_3.model;

public class Search {
  int userId;
  String searchTerms;

  public Search(int userId, String searchTerms) {
    this.userId = userId;
    this.searchTerms = searchTerms;
  }

  public int getUserId() {
    return userId;
  }

  public String getSearchTerms() {
    return searchTerms;
  }
}
```
/model/UserActivity.java
```java
package com.assu.study.chap14_3.model;

public class UserActivity {
  int userId;
  String userName;
  String zipcode;
  String[] interests;
  String searchTerm;
  String page;

  public UserActivity(
      int userId,
      String userName,
      String zipcode,
      String[] interests,
      String searchTerm,
      String page) {
    this.userId = userId;
    this.userName = userName;
    this.zipcode = zipcode;
    this.interests = interests;
    this.searchTerm = searchTerm;
    this.page = page;
  }

  public UserActivity updateSearch(String searchTerm) {
    this.searchTerm = searchTerm;
    return this;
  }
}
```

/model/UserProfile.java
```java
package com.assu.study.chap14_3.model;

public class UserProfile {
  int userId;
  String userName;
  String zipcode;
  String[] interests;

  public UserProfile(int userId, String userName, String zipcode, String[] interests) {
    this.userId = userId;
    this.userName = userName;
    this.zipcode = zipcode;
    this.interests = interests;
  }

  public UserProfile update(String zipcode, String[] interests) {
    this.zipcode = zipcode;
    this.interests = interests;
    return this;
  }

  public int getUserId() {
    return userId;
  }

  public String getUserName() {
    return userName;
  }

  public String getZipcode() {
    return zipcode;
  }

  public String[] getInterests() {
    return interests;
  }
}
```

/model/UserWindow.java
```java
package com.assu.study.chap14_3.model;

public class UserWindow {
  int userId;
  long timestamp;
}
```

---

# 2. 카프카 스트림즈: 아키텍처

---

## 2.1. 토폴로지 생성

---

## 2.2. 토폴로지 최적화

---

## 2.3. 토폴로지 테스트

---

## 2.4. 토폴로지 규모 확장

---

## 2.5. 장애 처리

---

# 3. 스트림 처리 활용 사례

---

# 4. 스트림 처리 프레임워크

---

# 정리하며..

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [Doc:: Processor API](https://kafka.apache.org/28/documentation/streams/developer-guide/processor-api.html)
* [Git:: 단어 개수 세기 전체 코드](https://github.com/gwenshap/kafka-streams-wordcount)
* [Git:: 주식 시장 통계 전체 코드](https://github.com/gwenshap/kafka-streams-stockstats)
* [Git:: 클릭 스트림 확장 전체 코드](https://github.com/gwenshap/kafka-clickstream-enrich)
* [Doc:: Kafka Streams Application Reset Tool](https://cwiki.apache.org/confluence/display/KAFKA/Kafka+Streams+Application+Reset+Tool)