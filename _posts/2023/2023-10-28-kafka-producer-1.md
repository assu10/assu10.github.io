---
layout: post
title:  "Kafka - 카프카 프로듀서(1): 프로듀서, 메시지 전달, 프로듀서 설정"
date: 2023-10-28
categories: dev
tags: kafka kafka-producer
---

이 포스트에서는 카프카에 메시지를 쓰기 위한 클라이언트에 대해 알아본다.

- 프로듀서의 주요 요소
- KafkaProducer 와 ProducerRecord 객체 생성법과 카프카에 레코드 전송법
- 카프카가 리턴하는 에러에 대한 처리
- 프로듀서 설정 옵션들

> **서드 파티 클라이언트**  
> 
> 카프카는 정식 배포판과 함께 제공되는 공식 클라이언트 이외 공식 클라이언트가 사용하는 TCP/IP 패킷의 명세를 공개하고 있음  
> 이를 사용하면 java 외 언어로도 쉽게 Kafka 를 사용하는 애플리케이션 개발이 가능  
> 이 클라이언트들은 [아파치 카프카 프로젝트 위키](https://cwiki.apache.org/confluence/display/KAFKA/Clients) 에서 확인 가능함  
> 
> TCP 패킷의 명세는 [아파치 카프카 프로토콜](https://kafka.apache.org/protocol.html) 에서 확인 가능함

---

**목차**

<!-- TOC -->
* [1. 프로듀서](#1-프로듀서)
* [2. 프로듀서 생성](#2-프로듀서-생성)
* [3. 카프카로 메시지 전달](#3-카프카로-메시지-전달)
  * [3.1. 동기적으로 메시지 전달](#31-동기적으로-메시지-전달)
  * [3.2. 비동기적으로 메시지 전달](#32-비동기적으로-메시지-전달)
* [4. 프로듀서 설정](#4-프로듀서-설정)
  * [4.1. `client.id`](#41-clientid)
  * [4.2. `acks`](#42-acks)
  * [4.3. 메시지 전달 시간](#43-메시지-전달-시간)
    * [4.3.1. `max.block.ms`](#431-maxblockms)
    * [4.3.2. `delivery.timeout.ms`](#432-deliverytimeoutms)
    * [4.3.3. `request.timeout.ms`](#433-requesttimeoutms)
    * [4.3.4. `retries`, `retry.backoff.ms`](#434-retries-retrybackoffms)
  * [4.4. `linger.ms`](#44-lingerms)
  * [4.5. `buffer.memory`](#45-buffermemory)
  * [4.6. `compression.type`](#46-compressiontype)
  * [4.7. `batch.size`](#47-batchsize)
  * [4.8. `max.in.flight.requests.per.connection`](#48-maxinflightrequestsperconnection)
  * [4.9. `max.request.size`](#49-maxrequestsize)
  * [4.10. `receive.buffer.bytes`, `send.buffer.bytes`](#410-receivebufferbytes-sendbufferbytes)
  * [4.11. `enable.idempotence`](#411-enableidempotence)
  * [순서 보장](#순서-보장)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.9
- zookeeper 3.8.3
- apache kafka: 3.6.1 (스칼라 2.13.0 에서 실행되는 3.6.1 버전)

![Spring Initializer](/assets/img/dev/2023/1028/init.png)

---

# 1. 프로듀서

애플리케이션이 카프카에 메시지를 써야 하는 상황은 매우 다양하다.  
- 분석을 목적으로 한 사용자 행동 기록
- 성능 메트릭 기록
- 로그 메시지 저장
- 다른 애플리케이션과의 비동기적 통신 수행
- 정보를 DB 에 저장하기 전 버퍼링

목적이 다양하기 때문에 요구 조건도 다양하다.  
- 모든 메시지가 중요해서 메시지 유실이 용납되지 않는지?
- 중복이 허용되도 되는지?
- 반드시 지켜야 할 지연이나 처리율이 있는지?

예를 들면 결재 트랜잭션 처리의 경우 메시지의 유실이나 중복은 허용되지 않는다.  
지연 시간은 낮아야 하고, 처리율은 초당 백만 개의 메시지를 처리할 정도로 매우 높아야 한다.  

반면, 사용자의 클릭 정보를 수집하는 경우 메시지가 조금 유실되거나 중복이 되어도 문제가 되지 않는다.  
사용자 경험에 영향을 주지 않는 한 지연이 높아도 된다.  

이러한 다양한 요구 조건은 카프카에 메시지를 쓰기 위해 프로듀서 API 를 사용하는 방식과 설정에 영향을 미친다.

![카프카 프로듀서](/assets/img/dev/2023/1028/producer.png)

① ProducerRecord 객체를 생성함으로써 카프카에 메시지를 쓰는 작업이 시작됨  
  이 때 레코드가 저장될 토픽과 밸류는 필수값이고, 키와 파티션 지정은 선택사항  

② ProducerRecord 를 전송하는 API 를 호출하면 프로듀서는 키와 밸류 객체가 네트워크 상에서 전송 가능하도록 직렬화하여 바이트 배열로 변환함  

③ 파티션을 명시적으로 지정하지 않았다면 해당 데이터를 파티셔너로 보냄  
  파티셔너는 파티션을 결정하는 역할을 하는데, 그 기준은 보통 ProducerRecord 객체의 키의 값임  

④ 파티션이 결정되어 메시지가 전송될 토픽과 파티션이 확정되면 프로듀서는 이 레코드를 같은 토픽 파티션으로 전송될 레코드들을 모은 **레코드 배치**에 추가함  

⑤ 별도의 스레드가 이 레코드 배치를 적절한 카프카 브로커에게 전송  

⑥ 브로커가 메시지를 받으면 응답을 돌려줌  
⑥-① 메시지가 성공적으로 저장되면 브로커는 토픽, 파티션, 해당 파티션 안에서의 레코드의 오프셋을 담은 RecordMetadata 객체를 리턴  
⑥-② 메시지가 저장에 실패하면 에러 리턴    

⑦ 프로듀서가 에러를 수신하면 메시지 쓰기를 포기하고 사용자에게 에러를 리턴하기까지 몇 번 더 재전송 시도 가능  

---

# 2. 프로듀서 생성

카프카에 메시지를 쓰려면 먼저 원하는 속성을 지정해서 프로듀서 객체를 생성해야 한다.  

<**카프카 프로듀서 필수 속성값**>  
- `bootstrap.servers`
  - 카프카 클러스터와 첫 연결을 생성하기 위해 프로듀서가 사용할 브로커의 `host:port` 목록
  - 프로듀서가 첫 연결을 생성한 뒤 추가 정보를 받아오게 되어 있으므로 모든 브로커를 포함할 필요는 없지만, 브로커 중 하나가 작동을 정지하는 경우에도 프로듀서가 클러스터 연결을 할 수 있도록 최소 2개 이상 지정하는 것을 권장함
- `key.serializer`
  - 카프카에 쓸 레코드의 키의 값을 직렬화하기 위해 사용하는 시리얼라이저 클래스의 이름
  - `key.serializer` 에는 `org.apache.kafka.common.serialization.Serializer` 인터페이스를 구현하는 클래스의 이름을 지정해야 함
  - 카프카의 client 패키지에는 `ByteArraySerializer`, `StringSerializer`, `IntegerSerializer` 등이 포함되어 있으므로 자주 사용하는 타입 사용 시 시리얼라이저를 직접 구현할 필요는 없음
  - 키 값 없이 밸류값만 보낼때도 `key.serializer` 설정을 해주어야 하는데, `VoidSerializer` 를 사용하여 키 타입으로 Void 타입 지정이 가능함
- `value.serializer`
  - 카프카에 쓸 레코드의 밸류값을 직렬화하기 위해 사용하는 시리얼라이저 클래스의 이름
  - 밸류값으로 쓰일 객체를 직렬화하는 클래스 이름을 지정함

```java
// Properties 객체 생성
Properties kafkaProps = new Properties();
kafkaProps.put("bootstrap.servers", "broker1:9092,broker2:9092");

// 메시지의 키 값과 밸류값으로 문자열 타입 사용
kafkaProps.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
kafkaProps.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

// 키와 밸류 타입 설정 후 Properties 객체를 넘겨줌으로써 새로운 프로듀서 생성
KafkaProducer<String, String> producer = new KafkaProducer<String, String>(kafkaProps);
```

위에서 프로듀서 설정 시 키 이름을 상수값으로 사용하고 있는데 이는 카프카 클라이언트의 1.x 버전이고, 2.x 버전부터는 관련 클래스에 정의된 정적 상수를 사용한다.

- 프로듀서: org.apache.kafka.clients.producer.ProducerConfig 
- 컨슈머: org.apache.kafka.clients.consumer.ConsumerConfig
- AdminClient: org.apache.kafka.clients.admin.AdminClientConfig

```java
// Producer 의 bootstrap.servers 속성 지정
kafkaProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");

// Consumer 의 auto.offset.reset 속성 지정
kafkaProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "latest");
```

프로듀서 객체를 생성했으면 메시지를 전송할 수 있는데 메시지 전송방법은 크게 3가지가 있다.

<**메시지 전송 방법**>    
- **파이어 앤 포겟(Fire and forget)**
  - 메시지를 서버에 전송만 하고 성공/실패 여부를 신경쓰지 않음
  - 카프카는 보통 고가용성이고, 프로듀서는 자동으로 전송 실패 시 메시지를 재전송 시도하기 때문에 대부분 메시지는 성공적으로 전달됨
  - 단, 재시도를 할 수 없는 에러가 발생하거나 타임아웃 발생 시 메시지는 유실되며 애플리케이션은 이에 대해 아무런 에외를 전달받지 못함
- **동기적 전송**
  - 카프카 프로듀서는 언제나 비동기적으로 작동함
  - 즉, 메시지를 보내면 `send()` 메서드는 `Future` 객체를 리턴함
  - 하지만 다음 메시지를 전송하기 전에 `get()` 메서드를 호출하여 작업이 완료될 때까지 기다렸다가 실제 성공 여부를 확인해야 함
- **비동기적 전송**
  - 콜백 함수와 함께 `send()` 메서드 호출 시 카프카 브로커로부터 응답을 받는 시점에서 자동으로 콜백 함수가 호출됨

해당 포스트의 모든 예시는 단일 스레드를 사용하지만, 프로듀서 객체는 메시지를 전송하려는 다수의 스레드를 동시에 사용할 수 있다.

---

# 3. 카프카로 메시지 전달

아래는 메시지를 전송하는 간단한 코드이다.
```java
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.boot.SpringApplication;

import java.util.Properties;

@SpringBootApplication
public class Chap03Application {

  public static void main(String[] args) {
    SpringApplication.run(Chap03Application.class, args);

    Properties KafkaProps = new Properties();
    KafkaProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    KafkaProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
    KafkaProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

    Producer<String, String> producer = new KafkaProducer<>(KafkaProps);
    // ProducerRecord 객체 생성
    ProducerRecord<String, String> record = new ProducerRecord<>("Topic_Country", "Key_Products", "Value_Korea");
    try {
      // ProducerRecord 객체를 전송하기 위해 프로듀서 객체의 send() 사용
      // 메시지는 버퍼에 저장되었다가 별도 스레드에 의해 브로커로 전달됨
      // Future<RecordMetadata> 를 리턴하지만 여기선 리턴값을 무시하기 때문에 메시지 전송의 성공 여부 모름
	  // 따라서 실제 이런 식으로는 잘 사용하지 않음
      producer.send(record);
    } catch (Exception e) {
      // 프로듀서가 카프카로 메시지를 보내기 전 발생하는 에러 캐치
      e.printStackTrace();
    }
  }
}
```

> [java Future](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/Future.html)

위 코드는 카프카 브로커에 메시지를 전송할 때 발생하는 에러나 브로커 자체에서 발생한 에러를 무시한다.  
단, 프로듀서가 카프카로 메시지를 보내기 전에 에러가 발생할 경우 예외가 발생할 수 있다.  
예) 메시지 직렬화 실패 시 `SerializationException`, 버퍼가 가득 찰 경우 `TimeoutException`, 실제로 전송 작업을 수행하는 스레드에 인터럽스가 걸리는 경우 `InterruptException` 발생

---

## 3.1. 동기적으로 메시지 전달

> 동기적으로 메시지를 전달하는 방식은 성능이 크게 낮아지기 때문에 실제 잘 사용하지 않음

카프카 클러스터에 얼마나 작업이 몰리느냐에 따라 브로커는 쓰기 요청에 응답하기까지 지연이 발생할 수 있다. (최소 2ms~최대 몇 초)  
동기적으로 메시지를 전송할 경우 전송을 요청하는 스레드는 이 시간동안 다른 메시지 전송도 못하고 아무것도 못하고 기다려야 한다.    
결과적으로 동기적으로 메시지를 전달하게 되면 성능이 크게 낮아지게 된다.

아래는 동기적으로 메시지를 전송하는 간단한 예시이다.

```java
package com.assu.study.chap03;

import java.util.Properties;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

public class ProducerSample {
  // 메시지를 전송하는 간단한 예시
  public void simpleMessageSend() {
    Properties kafkaProp = new Properties();
    kafkaProp.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    kafkaProp.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
    kafkaProp.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

    Producer<String, String> producer = new KafkaProducer<>(kafkaProp);

    // ProducerRecord 객체 생성
    ProducerRecord<String, String> record =
            new ProducerRecord<>("Topic_Country", "Key_Product", "Value_France");

    try {
      // ProducerRecord 를 전송하기 위해 프로듀서 객체의 send() 사용
      // 메시지는 버퍼에 저장되었다가 별도 스레드에 의해 브로커로 보내짐
      // send() 메서드는 Future<RecordMetadata> 를 리턴하지만 여기선 리턴값을 무시하기 때문에 메시지 전송의 성공 여부를 모름
      // 따라서 이런 식으로는 잘 사용하지 않음
      producer.send(record);
    } catch (Exception e) {
      // 프로듀서가 카프카로 메시지를 보내기 전 발생하는 에러 캐치
      e.printStackTrace();
    }
  }
}
```

<**KafkaProducer 에러 종류**>  
- **재시도 가능한 에러**
  - 메시지를 재전송하여 해결 가능
  - 연결 에러는 연결 회복 시 해결됨
  - 메시지를 전송받은 브로커가 해당 파티션의 리더가 아닐 경우 발생하는 에러는 해당 파티션에 새 리더가 선출되고 클라이언트 메타데이터가 업데이트되면 해결됨
  - 재시도 가능한 에러 발생 시 자동으로 재시도하도록 KafkaProducer 를 설정할 수 있으므로 이 경우 재전송 횟수가 소진되고서도 에러가 해결되지 않은 경우에 한해 재시도 가능한 예외가 발생함
- **재시도 불가능한 에러**
  - 메시지가 너무 클 경우 재시도를 해도 해결되지 않음
  - 이러한 경우 KafkaProducer 는 재시도없이 바로 예외 발생

---

## 3.2. 비동기적으로 메시지 전달

애플리케이션과 카프카 클러스터 사이에 네트워크 왕복 시간이 10ms 일 때 메시지를 보낼 때마다 응답을 기다린다면 100 개 메시지 전송 시 약 1초가 소요된다.  
만일 메시지를 모두 전송하고 응답을 기다리지 않으면 거의 시간이 소요되지 않는다.  

카프카는 레코드를 쓴 뒤 해당 레코드의 토픽, 파티션, 오프셋을 리턴하는데 대부분 애플리케이션에는 **이러한 메타데이터가 필요없으므로 굳이 응답이 필요**없다.  
**하지만 메시지 전송에 실패했을 경우엔 예외 발생, 에러 로그 등의 작업을 위해 그 내용을 알아야 한다.**  
따라서 **메시지를 비동기적으로 전송하면서 에러를 처리해야 하는 경우, 프로듀서는 레코드를 전송할 때 콜백을 지정함으로써 이를 가능**하게 해준다.

아래는 콜백을 사용하는 예시이다.

```java
import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class ProducerSample {

  // 비동기적으로 메시지 전송하면서 콜백으로 에러 처리
  public void AsyncProducerWithCallback() {
    Properties KafkaProps = new Properties();
    KafkaProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    KafkaProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
    KafkaProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

    Producer<String, String> producer = new KafkaProducer<>(KafkaProps);
    // ProducerRecord 객체 생성
    ProducerRecord<String, String> record = new ProducerRecord<>("Topic_Country", "Key_Products", "Value_Korea");
    // 레코드 전송 시 콜백 객체 전달
    producer.send(record, new AsyncProducerCallback());
  }

  // 비동기적으로 메시지 전송하면서 콜백으로 에러 처리
  // 콜백을 사용하려면 Callback 인터페이스를 구현하는 클래스 필요
  private class AsyncProducerCallback implements Callback {
    @Override
    public void onCompletion(RecordMetadata recordMetadata, Exception e) {
      if (e != null) {
        // 카프카가 에러를 리턴하면 onCompletion() 은 null 이 아닌 Exception 객체를 받음
        // 실제론는 아래처럼 출력 뿐이 아니라 확실한 에러 처리 함수가 필요함
        e.printStackTrace();
      }
    }
  }
}
```

콜백은 프로듀서의 메인 스레드에서 실행되기 때문에 만일 2개의 메시지를 동일한 파티션에 전송한다면 콜백 역시 보낸 순서대로 실행된다.  
즉, **전송되어야 할 메시지가 전송이 안되고 프로듀서가 지연되는 상황을 막기 위해서 콜백은 충분이 빨라야 한다.**  
콜백 안에 블로킹 작업을 수행하는 것은 권장되지 않고 대신 블로킹 작업을 동시에 수행하는 다른 스레드를 사용할 것이 권장된다.

---

# 4. 프로듀서 설정

프로듀서 설정값 중 위의 [2. 프로듀서 생성](#2-프로듀서-생성) 에서 `bootstrap.servers` 와 시리얼라이저는 살펴보았다.

대부분 기본값을 사용해도 되지만 일부 설정값은 메모리 사용량이나 성능, 신뢰성에 영향을 미친다.

---

## 4.1. `client.id`

**프로듀서와 프로듀서를 사용하는 애플리케이션을 구분하기 위한 논리적 식별자**이다.

임의의 문자열 사용이 가능하며, 브로커는 프로듀서가 보내온 메시지를 서로 구분하기 위해 `client.id` 를 사용한다.  
프로듀서가 보내온 메시지를 구분하여 로그 메시지 출력, 성능 메트릭 값 집계, 클라이언트별로 사용량 할당 등에 활용된다. (= **트러블 슈팅에 용이**) 


---

## 4.2. `acks`

**프로듀서가 임의의 쓰기 작업이 성공했다고 판별하기 위해 얼마나 많은 파티션 레플리카가 해당 레코드를 받아야 하는지를 결정**한다.  
즉, `acks` 매개변수 는 메시지가 유실될 가능성에 큰 영향을 미친다.

> 카프카가 보장하는 신뢰성 수준의 좀 더 상세한 내용은 추후 다룰 예정입니다.

<**`acks` 설정 옵션**>  
- `acks=0`
  - 프로듀서는 메시지가 성공적으로 전달되었다고 간주하고 브로커의 응답을 기다리지 않음
  - 오류가 나서 브로커가 메시지를 받지 못했을 경우, 프로듀서는 이 상황에 대해 알 수 없으므로 메시지가 유실됨
  - 프로듀서가 서버로부터 응답을 기다리지 않으므로 네트워크가 허용하는 한 빠르게 메시지 전송 가능
  - 즉, 매우 높은 처리량이 필요할 때 사용
- `acks=1`
  - 프로듀서는 리더 레플리카가 메시지를 받는 순간부터 브로커로부터 성공했다는 응답을 받음
  - 만일 리더에 크래시가 났고, 새 리더가 아직 선출되지 않은 상태라면 리더에 메시지를 쓸 수 없으므로 프로듀서는 에러 응답을 받을 것이고, 데이터 유실을 피하기 위해 메시지 재전송을 시도함
  - 하지만, 리더에 크래시가 난 상태에서 해당 메시지가 복제가 안된 채로 새 리더가 선출될 경우 여전히 메시지는 유실됨
- `acks=all` (기본값)
  - 프로듀서는 메시지가 모든 in-sync 레플리카에 전달된 뒤 브로커로부터 성공했다는 응답을 받음
  - 최소 2개 이상의 브로커가 해당 메시지를 갖고 있으며, 이는 크래시가 나더라도 메시지 유실이 없으므로 가장 안전한 형태임
    - > 위 부분의 좀 더 상세한 내용은 추후 다룰 예정입니다.
  - 하지만 `acks=1` 처럼 단순히 브로커 하나가 메시지를 받는 것보다는 더 기다려야 하므로 지연 시간은 좀 더 길어짐

`acks` 설정은 신뢰성과 프로듀서 지연 사이에 트레이드 오프 관계를 만든다. (= `acks` 설정을 낮추어서 신뢰성을 낮추면 그만큼 레코드를 빠르게 전송가능)  
하지만 **레코드 생성~컨슈머가 읽을 수 있을 때까지의 시간을 의미하는 종단 지연의 경우 3개의 설정값(0, 1, all) 모두 동일**하다.  
카프카는 일관성 유지를 위해 **모든 in-sync 레플리카에 복제가 완료된 뒤에서 컨슈머가 레코드를 읽어갈 수 있게 하기 때문**이다.  

**따라서 단순한 프로듀서의 지연이 아니라 종단 지연이 주로 고려되어야 한다면 가장 신뢰성 있는 설정인 `acks=all` 을 선택해도 종단 지연이 동일하므로 딱히 절충할 것이 없다.**


---

## 4.3. 메시지 전달 시간

프로듀서는 ProducerRecord 를 보낼 때 걸리는 시간을 2 구간으로 나누어 따로 처리 가능하다.

- `send()` 에 대한 비동기 호출이 이루어진 시각 ~ 결과를 리턴할 때까지 걸리는 시간
  - 이 시간동안 `send()` 를 호출한 스레드는 블록됨
- `send()` 에 대한 비동기 호출이 성공적으로 리턴한 시각(성공 or 실패) ~ 콜백이 호출될 때까지 걸리는 시간
  - ProducerRecord 가 전송을 위해 배치에 추가된 시점부터 카프카가 성공 응답을 보내거나, 재시도 불가능한 에러가 나거나, 전송을 위해 할당된 시간이 소진될 때까지의 시간과 동일

만일 `send()` 를 동기적으로 호출할 경우 메시지를 보내는 스레드는 위 2 구간에 대해 연속적으로 블록되기 때문에 각 구간의 소요 시간을 알 수 없다.

아래 그림은 프로듀서 내부에서의 데이터 흐름과 각 설정 매개변수들의 상호 작용을 도식화한 것이다.

![프로듀서 내부에서의 메시지 전달 시간을 작업별로 나눈 도식](/assets/img/dev/2023/1028/message.png)

---

### 4.3.1. `max.block.ms`

**`max.block.ms` 매개변수는 `send()` 를 호출(`partitionsFor` 를 호출해서 명시적으로 메타데이터 요청)했을 때 프로듀서가 얼마나 오랫동안 블록될 지 결정**한다.  

`send()` 메서드는 프로듀서의 전송 버퍼가 가득 차거나, 메타데이터가 아직 사용 가능하지 않을 때 블록되는데 이 때 `max.block.ms` 만큼 시간이 흐르면 예외가 발생한다.

---

### 4.3.2. `delivery.timeout.ms`

**`delivery.timeout.ms` 는 레코드 전송 준비가 완료된 시점(= `send()` 가 문제없이 리턴되고, 레코드가 배치에 저장된 시점) 부터 브로커의 응답을 받거나 전송을 포기하게 되는 
시점까지의 제한시간을 결정**한다.

`delivery.timeout.ms` 는 `linger.ms` 와 `request.timeout.ms` 보다 커야 한다.  
메시지는 `delivery.timeout.ms` 보다 빨리 전송될 수 있으며 실제로도 대부분 그렇다.

만일 프로듀서가 재시도를 하는 도중에 `delivery.timeout.ms` 를 초과하면 마지막으로 재시도하기 전에 브로커가 리턴한 에러에 해당하는 예외와 함께 콜백이 호출되고,  
레코드 배치가 전송을 기다리는 도중에 `delivery.timeout.ms` 를 초과하면 타임아웃 예외와 함께 콜백이 호출된다.

> **재시도 관련 설정 튜닝**  
> 
> 재시도 관련 설정을 튜닝하는 일반적인 방식은 아래와 같다.  
> 브로커가 크래시 났을 때 리더 선출에 약 30s 가 소요되므로 재시도 한도를 안전하게 120s 로 유지하는 것을 튜닝한다고 했을 때  
> 재시도 횟수와 재시도 사이의 시간 간격으로 조정하는 것이 아니라 그냥 `delivery.timeout.ms` 를 120s 로 설정하면 된다.

---

### 4.3.3. `request.timeout.ms`

**`request.timeout.ms` 매개변수는 프로듀서가 데이터를 전송할 때 서버로부터 응답을 받기 위해 얼마나 기다릴 것인지를 결정**한다.  

각각의 쓰기 요청 후 전송을 포기하기까지의 대기하는 시간을 의미하는 것이므로, 재시도 시간이나 실제 전송 이전에 소요되는 시간 등은 포함하지 않는다.

응답없이 타임아웃이 발생할 경우, 프로듀서는 재전송을 시도하거나 `TimeoutException` 과 함께 콜백을 호출한다.

---

### 4.3.4. `retries`, `retry.backoff.ms`

프로듀서가 서버로부터 에러 메시지를 받았을 때 파티션에 리더가 없는 경우처럼 일시적인 에러일 경우가 있다.  
이 때 **`retries` 매개변수는 프로듀서가 메시지 전송을 포기하고 에러를 발생시킬 때까지 메시지를 재전송하는 횟수를 결정**한다.  
**기본적으로 프로듀서는 각각의 재시도 사이에 100ms 동안 대기하는데, `retry.backoff.ms` 매개변수를 이용하여 이 간격을 조정**할 수 있다.

하지만 이 값들을 조정하는 것보다 크래시 난 브로커가 정상으로 돌아오기까지 (= 모든 파티션에 대해 새 리더가 선출되는데 얼마나 시간이 걸리는지)의 시간을 테스트하여 
`delivery.timeout.ms` 매개변수값을 설정하는 것을 권장한다.  
즉, 카프카 클러스터가 크래시로부터 복구되기까지의 시간보다 재전송을 시도하는 전체 시간을 더 길게 잡아주는 것이다. (그렇지 않으면 프로듀서가 일찍 메시지 전송을 포기하게 되므로) 

프로듀서가 에러를 전송하지 않는 경우도 있고, 메시지가 지나치게 큰 경우는 일시적인 에러가 아니기 때문에 이 때 프로듀서는 재시도를 하지도 않는다.  
기본적으로 프로듀서가 재전송을 알아서 처리하기 때문에 애플리케이션에서는 관련 처리를 수행하는 코드가 필요없다.    
**애플리케이션에서는 재시도 불가능한 에러를 처리하거나 재시도 횟수가 고갈되었을 경우에 대한 예외 처리만 하면 된다.**

참고로 재전송 기능을 끄는 방법은 `retries=0` 으로 설정하는 것 뿐이다.

---

## 4.4. `linger.ms`

**`linger.ms` 매개변수는 현재 배치를 전송하기 전까지 대기하는 시간을 결정**한다.  

KafkaProducer 는 현재 배치가 가득 차거나, `linger.ms` 에 설정된 제한 시간이 되었을 때 메시지 배치를 전송한다.  

기본적으로 프로듀서는 메시지 전송에 사용할 수 있는 스레드가 있으면 바로 전송을 하는데 `linger.ms` 을 0 보다 큰 값으로 설정하면 프로듀서가 브로커에 메시지 배치를 전송하기 전에 
메시지를 더 추가할 수 있도록 더 기다리도록 할 수 있다.  

단위 메시지당 추가적으로 드는 시간은 매우 작은 반면 압축이 설정되어 있거나 할 경우 훨씬 더 효율적이므로, **`linger.ms` 를 설정하면 지연을 조금 증가시키는 대신 처리율이 크게 증가**한다.

---

## 4.5. `buffer.memory`

**`buffer.memory` 매개변수는 프로듀서가 메시지를 전송하기 전에 메시지를 대기시키는 버퍼의 크기(메모리 양)를 결정**한다.  

애플리케이션이 서버에 전달 가능한 속도보다 더 빠르게 메시지를 전송한다면 버퍼 메모리가 가득찰 수 있는데, 이 때 추가로 호출되는 `send()` 는 `max.block.ms` 동안 블록되어 버퍼 메모리에 
공간이 생길 때까지 대기하게 된다. 만일 이 시간동안 대기했는데도 공간이 확보되지 않으면 예외를 발생시킨다.  

대부분 프로듀서의 예외는 `send()` 메서드가 리턴하는 `Future` 객체에서 발생하지만 이 타임아웃은 `send()` 메서드에서 발생한다.

---

## 4.6. `compression.type`

기본적으로 메시지는 압축되지 않은 상태로 전송되는데 **`compression.type` 매개변수를 `snappy`, `gzip`, `lz4`, `zstd` 중 하나로 설정하면 해당 압축 알고리즘을 
사용하여 메시지를 압축한 뒤 브로커로 전송**된다.

**압축 기능을 활성화함으로써 카프카로 메시지를 전송할 때 자주 병목이 발생하는 네트워크 사용량과 저장 공간을 절약**할 수 있다.

- `snappy`
  - CPU 부하가 작으면서도 성능이 좋음
  - 압축 성능과 네트워크 대역폭 모두 중요할 때 권장
- `gzip`
  - CPU 와 시간을 더 많이 사용하지만 압축율이 더 좋음
  - 네트워크 대역폭이 제한적일 때 사용하면 좋음

---

## 4.7. `batch.size`

같은 파티션에 있는 다수의 레코드가 전송될 경우 프로듀서는 이것들을 배치 단위로 모아서 한번에 전송한다.

**`batch.size` 매개변수는 각 배치에 사용될 메모리의 양(갯수가 아닌 바이트 단위)을 결정**한다.  

**배치가 가득 차면 해당 배치에 들어있는 모든 메시지가 한꺼번에 전송되지만, 프로듀서가 각 배치가 가득 찰때까지 기다린다는 의미는 아니다.**  
프로듀서는 심지어 하나의 메시지만 들어있는 배치도 전송한다.  

따라서 `batch.size` 매개변수를 매우 큰 값으로 설정한다고 해서 메시지 전송에 지연이 발생하지는 않는다.  
단, 이 값을 너무 작게 설정하면 프로듀서가 지나치게 자주 메시지를 전송하기 때문에 오버헤드가 발생한다.

---

## 4.8. `max.in.flight.requests.per.connection`

**`max.in.flight.requests.per.connection` 매개변수는 프로듀서가 서버로부터 응답을 받지 못한 상태에서 전송할 수 있는 최대 메시지의 수를 결정**한다.  

이 값을 높게 잡아주면 메모리 사용량이 증가하지만 처리량 역시 증가한다.

---

## 4.9. `max.request.size`

**`max.request.size` 매개변수는 프로듀서가 전송하는 쓰기 요청의 크기를 결정**한다.  

이 값은 메시지의 최대 크기를 제한하기도 하지만, 한 번의 요청에 보낼 수 있는 메시지의 최대 개수 역시 제한한다.  
예) `max.request.size` 의 기본값은 1MB 이고 이 때 전송 가능한 메시지의 최대 크기는 1MB 임  
한번에 보낼 수 있는 1KB 크기의 메시지 개수는 1,024 개가 됨

브로커에는 브로커가 받아들일 수 있는 최대 메시지 크기를 결정하는 [message.max.bytes](https://assu10.github.io/dev/2023/10/22/kafka-install/#messagemaxbytes) 매개변수가 있다.  

`max.request.size` 와 `message.max.bytes` 를 동일하게 맞춰줌으로써 프로듀서가 브로커가 받아들 일 수 없는 크기의 메시지를 전송하는 것을 방지할 수 있다.

---

## 4.10. `receive.buffer.bytes`, `send.buffer.bytes`

이 매개변수는 **데이터를 읽거나 소켓이 사용하는 TCP 송수신 버터의 크기를 결정**한다.  

각 값을 -1 로 설정하면 운영체제의 기본값이 사용된다.  

프로듀서나 컨슈머가 다른 데이터센터에 위치한 브로커와 통신할 경우 네트워크 대역폭이 낮고 지연이 길어지는 경우가 대부분이므로 이 값들은 올려잡아주는 것을 권장한다.

---

## 4.11. `enable.idempotence`

멱등적 프로듀서는 매우 중요한 부분이다.

> 명등적 프로듀서에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다.

신뢰성을 최대화하는 프로듀서를 설정할 경우 `acks=all` 로 잡고, 실패가 나더라도 충분히 재시도할 수 있도록 `delivery.timeout.ms` 를 매우 큰 값으로 잡는다.  
이 경우 메시지는 반드시 최소 한번 카프카에 쓰여진다.  
브로커가 프로듀서로부터 레코드를 받아서 로컬 디스크에 쓰고, 다른 브로커에도 성공적으로 복제되었다고 가정해보자.  
첫 번째 브로커가 프로듀서에 응답을 보내기 전에 크래시가 났을 경우 프로듀서는 `request.timeout.ms` 만큼 대기한 후 재전송을 시도하게 된다.  
이 때 새로 보내진 메시지는 이미 기존 쓰기 작업이 성공적으로 복제되었으므로 이미 메시지를 받은 적 있는 새 리더 브로커로 전달된다.  
결국 메시지가 중복되어 저장되는 것이다.

이러한 경우를 방지하기 위해 `enable.idempotence=true` 를 설정한다.

명등적 프로듀서 기능이 활성화되면 프로듀서는 레코드를 보낼 때마다 순차적인 번호를 붙여서 보내게 되는데, 만약 브로커가 동일한 번호를 가진 레코드를 2개 이상 받은 경우엔 
하나만 저장하게 되고 프로듀서는 `DuplicateSequenceException` 예외를 받는다.

멱등적 프로듀서 기능을 활성화하기 위해서는 `max.in.flight.requests.per.connection` 매개변수는 5 이하로, `retries` 매개변수는 1 이상으로, `acks=all` 로 설정해야 한다.  
만일 이 조건이 만족하지 않는다면 `ConfigException` 예외가 발생한다.

---

## 순서 보장

카프카는 파티션 내에서 메시지의 순서를 보존한다.  
즉, 프로듀서가 메시지를 특정한 순서로 보낼 경우 브로커가 받아서 파티션에 쓸 때나 컨슈머가 읽어올 때 해당 순서대로 처리된다는 것을 의미한다.

`retries` 매개변수를 0 보다 큰 값으로 설정한 상태에서 `max.in.flight.requests.per.connection` 매개변수를 1 이상으로 잡아줄 경우 메시지의 순서가 뒤집힐 수 있다.  
즉, 브로커가 첫 번째 배치를 받아서 쓰려다 실패하고, 두 번째 배치를 쓸 때는 성공(= 두 번째 배치가 in-flight 상태) 한 상황에서 다시 첫 번째 배치가 재전송 시도되어 
성공한 경우 메시지 순서가 뒤집히게 된다.

성능을 고려하면 `max.in.flight.requests.per.connection` 이 최소 2 이상이 되어야 하고, 신뢰성을 보장하기 위해 재시도 횟수도 높아야 한다는 점을 고려했을 때 
`enable.idempotence=true` 설정이 필요하다.  

이 설정은 최대 5개의 in-flight 요청을 허용하면서도 순서도 보장하고, 재전송이 발생하더라고 중복이 발생하는 것을 방지해준다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [java Future](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/Future.html)