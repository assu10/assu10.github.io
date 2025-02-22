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

여기서는 카프카 스트림즈를 이용하여 단어 개수를 세는 예시에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap14_1) 에 있습니다.

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

---

## 1.3. 클릭 스트림 확장: 스트리밍 조인

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
* [Processor API](https://kafka.apache.org/28/documentation/streams/developer-guide/processor-api.html)
* [단어 개수 세기 전체 코드](https://github.com/gwenshap/kafka-streams-wordcount)