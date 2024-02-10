---
layout: post
title:  "Kafka - 카프카 컨슈머(1): 컨슈머 생성, 토픽 구독, 폴링 루프, 컨슈머 설정"
date:   2023-11-04
categories: dev
tags: kafka kafka-consumer topic polling-loop
---

이 포스트에서는 카프카에 쓰여진 메시지를 읽기 위한 클라이언트에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 카프카 컨슈머](#1-카프카-컨슈머)
  * [1.1. 컨슈머와 컨슈머 그룹](#11-컨슈머와-컨슈머-그룹)
  * [1.2. 컨슈머 그룹과 컨슈머 리밸런스](#12-컨슈머-그룹과-컨슈머-리밸런스)
  * [1.3. 정적 그룹 멤버십](#13-정적-그룹-멤버십)
* [2. 컨슈머 생성](#2-컨슈머-생성)
* [3. 토픽 구독](#3-토픽-구독)
* [4. 폴링 루프](#4-폴링-루프)
* [5. 컨슈머 설정](#5-컨슈머-설정)
  * [5.1. `fetch.min.bytes`](#51-fetchminbytes)
  * [5.2. `fetch.max.wait.ms`](#52-fetchmaxwaitms)
  * [5.3. `fetch.max.bytes`](#53-fetchmaxbytes)
  * [5.4. `max.poll.records`](#54-maxpollrecords)
  * [5.5. `max.partition.fetch.bytes`](#55-maxpartitionfetchbytes)
  * [5.6. `session.timeout.ms`, `heartbeat.interval.ms`](#56-sessiontimeoutms-heartbeatintervalms)
  * [5.7. `max.poll.interval.ms`](#57-maxpollintervalms)
  * [5.8. `default.api.timtout.ms`](#58-defaultapitimtoutms)
  * [5.9. `request.timeout.ms`](#59-requesttimeoutms)
  * [5.10. `auto.offset.reset`](#510-autooffsetreset)
  * [5.11. `enable.auto.commit`](#511-enableautocommit)
  * [5.12. `partition.assignment.strategy`](#512-partitionassignmentstrategy)
  * [5.13. `client.id`](#513-clientid)
  * [5.14. `client.rack`](#514-clientrack)
  * [5.15. `group.instance.id`](#515-groupinstanceid)
  * [5.16. `receive.buffer.bytes`, `send.buffer.bytes`](#516-receivebufferbytes-sendbufferbytes)
  * [5.17 `offsets.retention.minutes`](#517-offsetsretentionminutes)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.9
- zookeeper 3.8.3
- apache kafka: 3.6.1 (스칼라 2.13.0 에서 실행되는 3.6.1 버전)

---

# 1. 카프카 컨슈머

카프카에서 데이터를 읽는 애플리케이션은 토픽을ㅇ 구독하고, 구독한 토픽들로부터 메시지를 받기 위해 KafkaConsumer 를 사용한다.

---

## 1.1. 컨슈머와 컨슈머 그룹

토픽으로부터 메시지를 읽어서 검사를 한 후 다른 저장소에 저장하는 애플리케이션이 있다고 하자.  

이 애플리케이션은 컨슈머 객체인 KafkaConsumer 인스턴스를 생성하고, 해당 토픽을 구독하고, 메시지를 받기 시작한 뒤 받은 메시지를 받아 검사 후 결과를 쓴다.

만일 이 애플리케이션이 검사할 수 있는 속도보다 프로듀서가 더 빠른 속도로 토픽에 메시지를 쓰게 되면 이 애플리케이션은 새로 추가되는 메시지의 속도를 따라잡을 수 없기 때문에 
메시지 처리가 계속 뒤로 밀리게 된다.  
따라서 토픽으로부터 데이터를 읽어 오는 작업을 확장할 수 있어야 한다. (= 여러 개의 프로듀서가 동일한 토픽에 메시지를 쓰듯이 여러 개의 컨슈머가 같은 토픽으로부터 데이터를 분할하여 읽어올 수 있도록)

카프카 컨슈머는 보통 컨슈머 그룹의 일부로서 동작하는데 같은 컨슈머 그룹에 속한 여러 개의 컨슈머들이 동일한 토픽을 구독할 경우, 각 컨슈머는 해당 토픽에서 서로 다른 파티션의 메시지를 받는다.

![파티션과 컨슈머 그룹 내의 컨슈머 갯수 관계](/assets/img/dev/2023/1104/consumer.png)

하나의 토픽을 구독하는 하나의 컨슈머 그룹에 속한 컨슈머 수가 파티션 수보다 많은 경우 유휴 컨슈머가 발생하여 메시지를 받지 못하게 된다.  
즉, 토픽의 파티션 개수보다 많은 컨슈머를 추가하는 것은 아무런 의미가 없다.

**컨슈머 그룹에 컨슈머를 추가하는 것은 카프카 토픽에서 읽어오는 데이터 양을 확장하는 주된 방법**이다.  

컨슈머가 지연시간이 긴 작업을 수행할 경우 하나의 컨슈머로 들어오는 데이터 속도를 감당할 수 없게 되기 때문에 **컨슈머 그룹에 컨슈머를 추가함으로써 단위 컨슈머가 처리하는 
파티션과 메시지 수를 분산시키는 것이 일반적인 규모 확장**이다.

**바로 이 부분이 토픽을 생성할 때 파티션 수를 크게 잡아주는 것이 좋은 이유**이다.  

> 토픽의 파티션 개수를 선정하는 방법은 [파티션 개수를 정할 때 고려할 사항](https://assu10.github.io/dev/2023/10/22/kafka-install/#%ED%8C%8C%ED%8B%B0%EC%85%98-%EA%B0%9C%EC%88%98%EB%A5%BC-%EC%A0%95%ED%95%A0-%EB%95%8C-%EA%B3%A0%EB%A0%A4%ED%95%A0-%EC%82%AC%ED%95%AD) 과 
> [파티션 수 결정: How to Choose the Number of Topics/Partitions in a Kafka Cluster?](https://www.confluent.io/blog/how-choose-number-topics-partitions-kafka-cluster/) 을 참고하세요.

이렇게 한 애플리케이션의 규모 확장 시 컨슈머를 추가하는 상황이 아닌, 여러 애플리케이션이 동일한 토픽에서 데이터를 읽어와야 하는 경우 각 애플리케이션이 각자의 컨슈머 그룹을 가져야 한다.  
카프카는 성능 저하없이 컨슈머와 컨슈머 그룹 확장이 가능하다.

![컨슈머 그룹이 여러 개일 경우 해당 그룹들 모두 모든 메시지 받음](/assets/img/dev/2023/1104/consumer2.png)

즉, 여러 개의 애플리케이션이 동일한 토픽 데이터를 읽어올 경우엔 1개 이상의 토픽에 대해 모든 메시지를 받아야하는 애플리케이션별로 새로운 컨슈머 그룹을 생성하면 되고, 
토픽에서 읽어들이는 데이터의 규모 확장을 하려면 이미 존재하는 컨슈머 그룹에 새로운 컨슈머를 추가하면 된다.

---

## 1.2. 컨슈머 그룹과 컨슈머 리밸런스

새로운 컨슈머를 컨슈머 그룹에 추가하면 이전에 다른 컨슈머가 읽고 있던 파티션으로부터 메시지를 읽기 시작한다.  
컨슈머가 종료되거나 크래시가 나서 컨슈머 그룹에서 나가게 되면 원래 이 컨슈머가 읽던 파티션들을 그룹에 남아있는 나머지 컨슈머 중 하나가 대신 받아서 읽기 시작한다.  
컨슈머에 파티션을 재할당하는 작업은 컨슈머 그룹이 읽고 있는 토픽이 변경되었을 때도 발생한다.  
예) 토픽에 새로운 파티션 추가

이렇게 **컨슈머 그룹에 할당된 파티션을 다른 컨슈머에게 할당해주는 작업을 리밸런스** 라고 한다.  

리밸런스는 컨슈머 그룹에서 안전하게 컨슈머를 제거할 수 있도록 해주고, 높은 가용성과 규모 가변성을 제공한다.

리밸런스는 컨슈머 그룹이 사용하는 파티션 할당 전략에 따라 2 가지 방식으로 나뉜다.

---

### Eager rebalance (이른 리밸런스)



---

### Cooperative rebalance (협력적 리밸런스) or Incremental rebalance (점진적 리밸런스)

---

## 1.3. 정적 그룹 멤버십

---

# 2. 컨슈머 생성

---

# 3. 토픽 구독

---

# 4. 폴링 루프

---

# 5. 컨슈머 설정

---

## 5.1. `fetch.min.bytes`

---

## 5.2. `fetch.max.wait.ms`

---

## 5.3. `fetch.max.bytes`

---

## 5.4. `max.poll.records`

---

## 5.5. `max.partition.fetch.bytes`

---

## 5.6. `session.timeout.ms`, `heartbeat.interval.ms`

---

## 5.7. `max.poll.interval.ms`

---

## 5.8. `default.api.timtout.ms`

---

## 5.9. `request.timeout.ms`

---

## 5.10. `auto.offset.reset`

---

## 5.11. `enable.auto.commit`

---

## 5.12. `partition.assignment.strategy`

---

## 5.13. `client.id`

---

## 5.14. `client.rack`

---

## 5.15. `group.instance.id`

---

## 5.16. `receive.buffer.bytes`, `send.buffer.bytes`

---

## 5.17 `offsets.retention.minutes`

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [파티션 수 결정: How to Choose the Number of Topics/Partitions in a Kafka Cluster?](https://www.confluent.io/blog/how-choose-number-topics-partitions-kafka-cluster/)