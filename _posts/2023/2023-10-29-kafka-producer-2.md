---
layout: post
title:  "Kafka - 카프카 프로듀서(2): 시리얼라이저, 파티션, 헤더, 인터셉터, 쿼터/스로틀링"
date: 2023-10-29
categories: dev
tags: kafka kafka-producer serializer avro partition record-header producer-interceptor
---

이 포스트에서는 카프카에 메시지를 쓰기 위한 클라이언트에 대해 알아본다.

- 파티션 할당 방식을 정의하는 파티셔너
- 객체의 직렬화 방식을 정의하는 시리얼라이저

---

**목차**

<!-- TOC -->
* [1. 시리얼라이저](#1-시리얼라이저)
  * [1.1. 커스텀 시리얼라이저](#11-커스텀-시리얼라이저)
  * [1.2. 아파치 에이브로 사용하여 직렬화](#12-아파치-에이브로-사용하여-직렬화)
  * [1.3. 카프카에서 에이브로 레코드 사용](#13-카프카에서-에이브로-레코드-사용)
* [2. 파티션](#2-파티션)
  * [2.1. 커스텀 파티셔너 구현](#21-커스텀-파티셔너-구현)
* [3. 헤더](#3-헤더)
* [4. 인터셉터](#4-인터셉터)
* [5. 쿼터, 스로틀링](#5-쿼터-스로틀링)
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

# 1. 시리얼라이저

[2. 프로듀서 생성](https://assu10.github.io/dev/2023/10/28/kafka-producer-1/#2-%ED%94%84%EB%A1%9C%EB%93%80%EC%84%9C-%EC%83%9D%EC%84%B1) 의 예시처럼 프로듀서를 
설정할 때는 반드시 시리얼라이저를 지정해주어야 한다.

카프카의 client 패키지에는 `ByteArraySerializer`, `StringSerializer`, `IntegerSerializer` 등이 포함되어 있으므로 자주 사용하는 타입 사용 시 
시리얼라이저를 직접 구현할 필요는 없지만, 결국 좀 더 일반적인 레코드를 
직렬화할 수 있어야 한다.

카프카로 전송해야 하는 객체가 단순 문자열이나 정수가 아닐 경우 직렬화를 하기 위한 2가지 방법이 있다.  
- 레코드를 생성하기 위해 에이브로(Avro), 스리프트(Thrift), 프로토버프(Protobuf) 와 같은 범용 직렬화 라이브러리 사용
- 커스텀 직렬화 로직 작성

범용 직렬화 라이브러리인 아파치 에이브로 시리얼라이즈를 사용하는 것을 권장하지만, 
시리얼라이저의 작동 방식과 범용 직렬화 라이브러리의 잠점을 이해하기 위해 직접 커스텀 시리얼라이저를 구현해보는 법도 함께 알아본다.

---

## 1.1. 커스텀 시리얼라이저

> 아파치 에이브로를 사용하여 직렬화하는 것을 강력히 권장하므로 커스텀 시리얼라이저는 내용만 참고할 것

고객 클래스
```java
// 커스텀 시리얼라이저 - 고객 클래스
public class Customer {
  private int customerId;
  private String customerName;

  public Customer(int customerId, String customerName) {
    this.customerId = customerId;
    this.customerName = customerName;
  }

  public int getCustomerId() {
    return customerId;
  }

  public String getCustomerName() {
    return customerName;
  }
}
```

고객 클래스를 위한 커스텀 시리얼라이저
```java
import org.apache.kafka.common.errors.SerializationException;
import org.apache.kafka.common.serialization.Serializer;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public class CustomerSerializer implements Serializer<Customer> {
  /**
   * customerId: 4 byte int
   * customerName length: 4 byte int, UTF-8
   * customerName: N bytes, UTF-8
   */
  @Override
  public byte[] serialize(String topic, Customer data) {
    try {
      byte[] serializedName;
      int stringSize;
      if (data == null) {
        return null;
      } else {
        if (data.getCustomerName() != null) {
          serializedName = data.getCustomerName().getBytes(StandardCharsets.UTF_8);
          stringSize = serializedName.length;
        } else {
          serializedName = new byte[0];
          stringSize = 0;
        }
      }

      ByteBuffer buf = ByteBuffer.allocate(4 + 4 + stringSize);
      buf.putInt(data.getCustomerId());
      buf.putInt(stringSize);
      buf.put(serializedName);

      return buf.array();
    } catch (Exception e) {
      throw new SerializationException("Error when serializing Customer to byte[] ", e);
    }
  }

  @Override
  public void configure(Map configs, boolean isKey) {
    // nothing to configure
  }

  @Override
  public void close() {
    // nothing to close
  }
}
```

위와 같이 직렬화를 한다면 유저가 많아져서 customerId 를 int 에서 long 으로 변경하거나 새로운 필드를 추가할 때 기존 형식과 새 형식 사이의 
호환성을 유지해야 하는 문제점이 있다.  
서로 다른 버전의 직렬화/비직렬화 로직을 디버깅할 때는 단순 바이트를 일일이 비교해야 하기 때문에 상당히 어려운 작업이다.  
또한 여러 곳에서 Customer 데이터를 카프카로 쓰는 작업을 수행하고 있다면 모두 같은 로직을 사용하고 있어야 하기 때문에 동시에 코드를 변경해야 하는 상황이 발생한다.

이러한 문제점 때문에 JSON, 에이브로 등과 같은 범용 라이브러리를 사용하는 것을 권장한다.

---

## 1.2. 아파치 에이브로 사용하여 직렬화

에이브로의 데이터는 언어에 독립적인 스카마 형태로 기술된다.  
이 스키마는 보통 JSON 형식으로 정의되며, 주어진 데이터를 스키마에 따라 직렬화하면 이진 파일 형태로 결과물이 나오는 것이 보통이다. 
(JSON 형태로 나오게 할 수도 있음)

에이브로는 에이브로 파일 자체에 스키마를 내장하는 방법을 사용한다.

**에이브로가 카프카와 같은 메시지 전달 시스템에 적합한 이유는 메시지를 쓰는 애플리케이션이 새로운 스키마로 전환하더라도 기존 스키마와 호환성을 유지하는 한, 데이터를 읽는 
애플리케이션은 변경/업데이트없이 계속해서 메시지를 처리할 수 있다는 점이**다.

아래 예시를 보자.

기존 스키마
```json
{
  "namespace": "customerManagerment.avro",
  "type": "record",
  "name": "Customer",
  "fields": [
    {"name": "id", "type":  "int"},
    {"name": "name", "type":  "string"},
    {"name": "address", "type":  ["null", "string"], "default":  "null"}
  ] 
}
```

위 필드에서 address 필드가 없어지고 email 필드가 추가되었다고 해보자.

변경된 스키마
```json
{
  "namespace": "customerManagerment.avro",
  "type": "record",
  "name": "Customer",
  "fields": [
    {"name": "id", "type":  "int"},
    {"name": "name", "type":  "string"},
    {"name": "email", "type":  ["null", "string"], "default":  "null"}
  ] 
}
```

이제 새로운 버전으로 업그레이드를 하면 예전 레코드는 address 를 가지고 있는 반면, 새 레코드는 email 을 갖게 된다.  
보통 이전 버전 애플리케이션과 새로운 버전 애플리케이션이 카프카에 저장된 모든 이벤트를 처리할 수 있도록 해주어야 한다.

이전 버전 이벤트를 읽는 쪽의 애플리케이션은 getName(), getId(), getAddress() 와 같은 메서드가 있을 텐데 이 애플리케이션이 신버전의 스키마를 사용해서 쓰여진 메시지를 받을 경우 
getName(), getId() 는 변경없이 작동하지만 getAddress() 는 null 을 리턴하게 된다.

읽는 쪽 애플리케이션을 업그레이드한 후 구버전 스키마로 쓰여진 메시지를 받을 경우 getEmail() 은 null 을 리턴하게 된다.

**즉, 데이터를 읽는 쪽 애플리케이션을 전부 변경하지 않고 스키마를 변경하더라도 어떠한 예외나 에러가 발생하지 않으며, 
기존 데이터를 새로운 스키마에 맞춰 업데이트하는 큰 작업을 할 필요가 없다.**

단, 이러한 시나리오에는 주의할 점이 있다.

- **데이터를 쓸 때 사용하는 스키마와 읽을 때 기대하는 스키마가 서로 호환되어야 함**
  - [에이브로 문서 중 호환성 규칙](https://avro.apache.org/docs/1.7.7/spec.html#Schema+Resolution)
- **역직렬화를 할 때는 데이터를 쓸 때 사용했던 스키마에 접근이 가능해야 함**
  - 만일 그 스키마가 읽는 쪽 애플리케이션에서 기대하는 스키마와 다를 경우에도 마찬가지임

위에서 두 번째 조건을 만족시키기 위해 에이브로 파일을 쓰는 과정에는 사용된 스키마를 쓰는 과정이 포함되어 있지만, 카프카 메시지를 다룰 때에는 좀 더 나은 방법이 있다.  
아래에서 그 방법에 대해 살펴본다.

---

## 1.3. 카프카에서 에이브로 레코드 사용

파일 안에 전체 스키마를 저장함으로써 약간의 오버헤드를 감수하는 에이브로 파일과는 달리 카프카 레코드에 전체 스키마를 저장하게 되면 전체 레코드 사이즈가 2배 이상이 될 수 있다. 
하지만 에이브로는 레코드를 읽을 때 스키마 전체를 필요로 하므로 어딘가에는 스키마를 저장해두어야 한다.

이 문제를 해결하기 위해 **스키마 레지스트리 아키텍처 패턴**을 사용한다.

스키마 레지스트리는 아파치 카프카의 일부가 아니므로 여러 오픈소스 구현체 중 하나를 골라서 사용하면 된다.  

이 포스트에서는 컨플루언트에서 제공하는 스키마 레지스트리를 사용한다.

- 컨플루언트 스키마 레지스트리 코드 (깃허브): [https://github.com/confluentinc/schema-registry](https://github.com/confluentinc/schema-registry)
- [컨플루언트 플랫폼](https://docs.confluent.io/platform/current/installation/overview.html) 의 일부로도 설치 가능
- 컨플루언트 스키마 레지스트리 문서: [https://docs.confluent.io/platform/current/schema-registry/index.html](https://docs.confluent.io/platform/current/schema-registry/index.html)

카프카에 데이터를 쓰기 위해 사용되는 모든 스키마를 레지스트리에 저장하고, 카프카에 쓰는 레코드에는 사용된 스키마의 고유 식별자만 넣어준다.  
컨슈머는 이 식별자를 사용하여 스키마 레지스트리에서 스키마를 가져와 데이터를 역직렬화할 수 있다.  

**여기서 중요한 점은 스키마를 레지스트리에 저장하고 필요할 때 가져오는 이 모든 작업이 주어진 객체를 직렬화하는 시리얼라이저와 직렬화된 데이터를 객체로 복원하는 디시리얼라이저 내부에서 수행된다는 점**이다.  
즉, 카프카에 데이터를 쓰는 코드는 그저 다른 시리얼라이저를 사용하듯이 에이브로 시리얼라이저를 사용하면 된다.

![에이브로 레코드의 직렬화/역직렬화 흐름](/assets/img/dev/2023/1029/avro.png)

아래는 에이브로를 사용하여 생성한 객체를 카프카에 쓰는 예시이다.

> 에이브로 스키마에서 객체를 생성해내는 방법은 [아파치 에이브로 docs](https://avro.apache.org/docs/current/) 를 참고하세요.

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.assu</groupId>
        <artifactId>study</artifactId>
        <version>1.1.0</version>
    </parent>

    <artifactId>chap03</artifactId>

    <properties>
        <kafka.version>3.6.1</kafka.version>
        <confluent.version>7.5.1</confluent.version>
        <avro.version>1.11.3</avro.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <repositories>
        <repository>
            <id>confluent</id>
            <url>https://packages.confluent.io/maven/</url>
        </repository>
    </repositories>
    <dependencies>
        <!-- https://mvnrepository.com/artifact/org.apache.avro/avro -->
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
        <!-- https://mvnrepository.com/artifact/io.confluent/kafka-avro-serializer -->
        <dependency>
            <groupId>io.confluent</groupId>
            <artifactId>kafka-avro-serializer</artifactId>
            <version>${confluent.version}</version>
        </dependency>
        <!-- https://mvnrepository.com/artifact/org.apache.kafka/kafka-clients -->
        <dependency>
            <groupId>org.apache.kafka</groupId>
            <artifactId>kafka-clients</artifactId>
            <version>${kafka.version}</version>
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

/resources/avro/AvroCustomer.avsc
```json
{
  "namespace": "avrocustomer.avro",
  "type": "record",
  "name": "AvroCustomer",
  "fields": [
    {
      "name": "id",
      "type": "int"
    },
    {
      "name": "name",
      "type": "string"
    },
    {
      "name": "email",
      "type": [
        "null",
        "string"
      ],
      "default": null
    }
  ]
}
```

에이브로 클래스를 생성하는 것은 `avro-tools.jar` 를 이용하거나 에이브로 메이븐 플러그인을 사용하여 생성 가능하다.  
위처럼 스키마 정의 후 빌드하면 AvroCustomer.java 가 생성된다.

/avrouser/AvroProducer.java
```java
import avrocustomer.avro.AvroCustomer;
import io.confluent.kafka.serializers.AbstractKafkaSchemaSerDeConfig;
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.util.Properties;

public class AvroProducer {
  public static void main(String[] args) {
    Properties props = new Properties();

    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

    // 에이브로를 사용해서 객체를 직렬화하기 위해 KafkaAvroSerializer 사용
    // KafkaAvroSerializer 는 객체 뿐 아니라 기본형 데이터도 처리 가능
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);

    // 에이브로 시리얼라이저의 설정 매개변수 설정
    // 프로듀서가 시리얼라이저에 넘겨주는 값으로, 스키마를 저장해놓은 위치를 가리킴 (= 스키마 레지스트리의 url 지정)
    props.put(AbstractKafkaSchemaSerDeConfig.SCHEMA_REGISTRY_URL_CONFIG, "http://sample.schemaurl");

    String topic = "customerContacts";

    // AvroCustomer 는 POJO 가 아니라 에이브로의 코드 생성 기능을 사용해서 스키마로부터 생성된 에이브로 특화 객체임
    // 에이브로 시리얼라이저는 POJO 객체가 아닌 에이브로 객체만을 직렬화 가능
    Producer<String, AvroCustomer> producer = new KafkaProducer<>(props);

    // 10 번 진행
    for (int i = 0; i < 10; i++) {
      AvroCustomer customer = new AvroCustomer();
      System.out.println("Avro Customer " + customer.toString());

      // 밸류 타입이 AvroCustomer 인 ProducerRecord 객체를 생성하여 전달
      ProducerRecord<String, AvroCustomer> record = new ProducerRecord<>(topic, customer.getName(), customer);

      // AvroCustomer 객체 전송 후엔 KafkaAvroSerializer 가 알아서 해줌
      producer.send(record);
    }
  }
}
```

---

에이브로를 사용하면 키-밸류 맵 형태로 사용가능한 제네릭 에이브로 객체도 사용할 수 있다.  
스키마를 지정하면 여기에 해당하는 getter, setter 와 함께 생성되는 에이브로 객체와는 달리 제네릭 에이브로 객체는 사용 시 스키마만 지정해주면 된다.

```java
import io.confluent.kafka.serializers.AbstractKafkaSchemaSerDeConfig;
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.util.Properties;

public class GenericAvro {
  public static void main(String[] args) {
    Properties props = new Properties();

    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

    // 에이브로를 사용해서 객체를 직렬화하기 위해 KafkaAvroSerializer 사용
    // KafkaAvroSerializer 는 객체 뿐 아니라 기본형 데이터도 처리 가능
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);

    // 에이브로 시리얼라이저의 설정 매개변수 설정
    // 프로듀서가 시리얼라이저에 넘겨주는 값으로, 스키마를 저장해놓은 위치를 가리킴 (= 스키마 레지스트리의 url 지정)
    props.put(AbstractKafkaSchemaSerDeConfig.SCHEMA_REGISTRY_URL_CONFIG, "http://sample.schemaurl");

    // 에이브로가 자동 생성한 객체를 사용하지 않기 때문에 에이브로 스키마를 직접 지정
    String schemaString = """
        {
          "namespace": "avrogeneric.avro",
          "type": "record",
          "name": "AvroGeneric",
          "fields": [
            {
              "name": "id",
              "type": "int"
            },
            {
              "name": "name",
              "type": "string"
            },
            {
              "name": "email",
              "type": [
                "null",
                "string"
              ],
              "default": null
            }
          ]
        }
        """;

    Producer<String, GenericRecord> producer = new KafkaProducer<>(props);
    String topic = "customerContacts";

    // 에이브로 객체 초기화
    Schema.Parser parser = new Schema.Parser();
    Schema schema = parser.parse(schemaString);

    // 10 번 진행
    for (int i = 0; i < 10; i++) {
      String name = "sampleName" + i;
      String email = "sampleEmail" + i;

      GenericRecord customer = new GenericData.Record(schema);
      customer.put("id", i);
      customer.put("name", name);
      customer.put("email", email);

      // ProducerRecord 의 밸류값에 직접 지정한 스키마와 데이터가 포함된 GenericRecord 가 들어감
      ProducerRecord<String, GenericRecord> record = new ProducerRecord<>(topic, name, customer);

      // 객체 전송 후엔 시리얼라이저가 레코드에서 스키마를 얻어오고, 스키마를 스키마 레지스트리에 저장하고,
      // 객체 데이터를 직렬화하는 과정을 알아서 함
      producer.send(record);
    }
  }
}
```

---

# 2. 파티션

위에서 생성한 ProducerRecord 객체는 토픽, 키, 밸류값을 포함한다.

토픽, 키, 밸류가 포함된 ProducerRecord
```java
ProducerRecord<String, String> record = new ProducerRecord<>(topic, name, customer);
```

카프카 메시지는 토픽, 파티션(Optional), 키(Optional), 밸류로 구성될 수 있기 때문에 
토픽과 밸류만 있어도 ProducerRecord 객체 생성이 가능하다. (하지만 대부분 키 값이 지정된 레코드를 사용함)

토픽, 밸류가 포함된 ProducerRecord (키 없음)
```java
ProducerRecord<String, String> record = new ProducerRecord<>(topic, customer);    // key 는 null
```

키는 하나의 토픽에 속한 여러 개의 파티션 중 해당 메시지가 저장될 파티션을 결정짓는 기준점이기도 하다.  
같은 키 값을 갖는 모든 메시지는 같은 파티션에 저장된다.  
즉, 임의의 프로세스가 전체 파티션 중 일부만 읽어올 경우 특정한 키 값을 갖는 모든 메시지를 읽게 된다.

> 키 값은 로그 압착 기능이 활성화된 토픽에서도 중요한 역할을 하는데 이에 대한 상세한 내용은 추후 알아볼 예정입니다.

기본 파티셔너 사용 중에 키 값이 null 인 레코드가 주어지면 레코드는 현재 사용 가능한 토픽의 파티션 중 하나에 랜덤하게 저장된다.

카프카 2.4 프로듀서부터는 기본 파티셔너일 때 키 값이 null 일 경우 sticky 처리가 있는 라운드 로빈 알고리즘을 사용하여 메시지를 파티션에 저장한다. 

![Sticky RoundRobin](/assets/img/dev/2023/1029/sticky.png)

위에서 1, 5번 레코드는 키 값이 있고 각각 0번, 3번 파티션에 저장되어야 하며, 나머지 레코드는 키 값이 null 이라고 하자.  
그리고 한 번에 브로커로 전송될 수 있는 메시지 수는 4개라고 하자.  
좌측 하단 그림은 파티셔너에 Sticky 처리가 없을 경우이고, 우측 하단 그림은 파티셔너에 Sticky 처리가 있을 경우이다.  
Sticky 처리가 있을 경우 키 값이 null 인 메시지들은 일단 키 값이 있는 메시지 뒤에 따라붙은 후 라운드 로빈 방식으로 배치되기 때문에 보내야 하는 요청의 수가 5개가 아닌 3개로 줄어든다.

---

키 값이 지정된 상황에서 기본 파티셔너를 사용할 경우 카프카는 키 값을 해시한 결과를 기준으로 메시지를 저장할 파티션을 특정한다.  
이 때 동일한 키 값은 항상 동일한 파티션에 저장되기 때문에 파티션을 선택할 때는 토픽의 모든 파티션을 대상으로 선택한다. (즉, 사용 가능한 파티션만 대상으로 하지 않음) 

기본 파티셔너 외에 카프카 클라이언트는 `RoundRobinPartitioner` 와 `UniformStickyPartitioner` 를 포함한다.  
각각 메시지가 키 값을 포함하고 있을 경우에도 랜덤 파티션 할당과 Sticky 파티션 할당을 수행한다.  

키 값 분포가 불균형해서 특정한 키 값을 갖는 데이터가 많은 경우 한쪽으로 부하가 몰릴 수 있는데 `UniformStickyPartitioner` 를 사용하면 전체 파티션에 대해서 
균등한 분포를 갖도록 파티션이 할당된다.

위 2개 파티셔너들은 컨슈머 애플리케이션에서 키 값이 중요한 경우에 유용하다.  
예) 카프카에 저장된 데이터를 RDB 로 보낼 때 카프카 레코드의 키 값을 PK 로 사용하는 ETL 애플리케이션  

> **ETL 애플리케이션**  
> 
> ETL 은 추출(Extract), 변환(Transform), 로드(Load) 를 의미하며, 여러 시스템의 데이터를 단일 데이터 베이스에 결합하기 위해 
> 일반적으로 사용하는 방법

---

**기본 파티셔너가 사용될 때 특정한 키 값에 대응되는 파티션은 파티션 수가 변하지 않는 한 변하지 않는다.**  

따라서 파티션 수가 변경되지 않는다는 가정하에 111 에 해당하는 레코드는 모두 222 파티션에 저장된다라는 예상이 가능하기 때문에 
파티션에서 데이터를 읽어오는 부분 최적화 시 이 부분을 활용할 수 있다.

하지만 이러한 특성은 토픽에 새로운 파티션을 추가하는 순간 유효하지 않게 된다. 파티션을 추가하기 전에 쓴 레코드들은 222 파티션에 저장되지만, 
이후에 쓴 레코드들은 다른 위치에 저장될 수 있기 때문이다.  

만약 파티션을 결정하는데 사용되는 키가 중요해서 같은 키 값이 저장되는 파티션이 변경되어서는 안되는 경우라면 충분한 수의 파티션을 가진 토픽을 
생성한 후 더 이상 파티션을 추가하지 않으면 된다.

파티션 수를 결정하는 방법은 [How to Choose the Number of Topics/Partitions in a Kafka Cluster?](https://www.confluent.io/blog/how-choose-number-topics-partitions-kafka-cluster/) 참고하세요.

---

## 2.1. 커스텀 파티셔너 구현

항상 키 값을 해시 처리하여 파티션을 결정하는 게 좋지 않을수도 있다.  

예를 들어 일일 트랜잭션의 큰 부분을 A 업무를 처리하는데 사용한다고 하자.  
이 때 키 값의 해시값을 기준으로 파티션을 할당하는 기본 파티셔너를 사용한다면 A 에서 생성된 레코드들이 다른 레코드들과 같은 파티션에 저장될 것이고, 이 때 한 파티션에 다른 파티션보다 
훨씬 많은 레코드들이 저장되어 서버 공간이 부족해지거나 성능 이슈가 발생할 수 있다.  

이 때는 A 는 특정 파티션에 저장되도록 하고, 다른 레코드들은 해시값을 사용하여 나머지 파티션에 할당되도록 할 수 있다.

아래는 커스텀 파티셔너의 예시이다.

```java
import org.apache.kafka.clients.producer.Partitioner;
import org.apache.kafka.common.Cluster;
import org.apache.kafka.common.InvalidRecordException;
import org.apache.kafka.common.PartitionInfo;
import org.apache.kafka.common.utils.Utils;

import java.util.List;
import java.util.Map;

// 커스텀 파티셔너
public class CustomPartitioner implements Partitioner {

  // partition() 에 특정 데이터를 하드 코딩하는 것보다 configure() 를 경유하여 넘겨주는 게 좋지만 내용 이해를 위해 하드코딩
  @Override
  public int partition(String topic, Object key, byte[] keyBytes, Object value, byte[] valueBytes, Cluster cluster) {
    List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
    int numPartitions = partitions.size();

    if ((keyBytes == null) || (!(key instanceof String))) {
      throw new InvalidRecordException("all messages to have customer name as key.");
    }

    if (((String) key).equals("A")) {
      // A 는 항상 마지막 파티션으로 지정
      return numPartitions - 1;
    }

    // 다른 키들은 남은 파티션에 해시값을 사용하여 할당
    return Math.abs(Utils.murmur2(keyBytes)) % (numPartitions - 1);
  }

  @Override
  public void close() {
  }


  @Override
  public void configure(Map<String, ?> map) {
  }
}
```

---

# 3. 헤더

레코드는 키/밸류값 외에 헤더값을 포함할 수도 있다.  

**레코드 헤더는 카프카 레코드의 키/밸류값을 건드리지 않고 추가 메타데이터를 넣을 사용**한다.  

헤더는 주로 메시지의 전달 내역을 기록할 때 사용하는데 데이터가 생성된 곳의 정보를 헤더에 저장해두면 메시지를 파싱할 필요없이 헤더 정보만으로 메시지를 라우팅하거나 출처 추적이 가능하다.

헤더는 순서가 있는 키/밸류 쌍의 집합으로 구현되는데 키는 항상 String 타입이고, 밸류는 아무 직렬화된 객체라도 상관없다.

ProducerRecord 에 헤더 추가
```java
record.headers().add("privacy", "TEST".getBytes(StandardCharsets.UTF_8));
```

---

# 4. 인터셉터

카프카의 `ProducerInterceptor` 는 2개의 메서드를 정의할 수 있다.

- `ProducerRecord<K,V> onSend(ProducerRecord<K,V> record)`
  - 프로듀서가 레코드를 브로커로 보내기 전, 직렬화되기 직전에 호출됨
  - 보내질 레코드에 담긴 정보 조회 및 수정 가능
  - 이 메서드가 리턴한 레코드가 직렬화되어 카프카로 보내짐
- `void onAcknowledgement(RecordMetadata metadata, Exception exception)`
  - 카프카 브로커가 보낸 응답을 클라이언트가 받았을 때 호출됨
  - 브로커가 보낸 응답을 변경할 수는 없지만 정보 조회는 가능

`ProducerInterceptor` 는 모니터링, 정보추적, 헤더 삽입 등 다양하게 사용된다.  
특히, 레코드 메시지가 생성된 위치 정보를 심음으로써 메시지의 전달 경로 추적, 혹은 민감한 정보 삭제 처리 등의 용도로 많이 사용된다.

아래는 n ms 마다 전송된 메시지의 수와 특정한 시간 윈도우 사이에 브로커가 리턴한 acks 수를 집계하는 간단한 프로듀서 인터셉터 예시이다.  

```java
import org.apache.kafka.clients.producer.ProducerInterceptor;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;

import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

// N 밀리초마다 전송된 메시지 수와 확인된 메시지 수를 출력함
public class CountingProducerInterceptor implements ProducerInterceptor {

  ScheduledExecutorService executorService = Executors.newSingleThreadScheduledExecutor();
  static AtomicLong numSent = new AtomicLong(0);
  static AtomicLong numAcked = new AtomicLong(0);

  @Override
  public void configure(Map<String, ?> map) {
    // ProducerInterceptor 는 Configurable 인터페이스를 구현하므로 configure() 메서드를 재정의함으로써 다른 메서드가
    // 호출되기 전에 뭔가 설정해주는 것이 가능함
    // 이 메서드는 전체 프로듀서 설정을 전달받기 때문에 어떠한 설정 매개변수도 읽거나 수정 가능
    Long windowSize = Long.valueOf((String) map.get("counting.interceptor.window.size.ms"));  // 아래 설정 파일에서 가져온 값

    executorService.scheduleAtFixedRate(CountingProducerInterceptor::run, windowSize, windowSize, TimeUnit.MILLISECONDS);
  }

  // 프로듀서가 레코드를 브로커로 보내기 전, 직렬화되기 직전에 호출
  @Override
  public ProducerRecord onSend(ProducerRecord producerRecord) {
    numSent.incrementAndGet();

    // 레코드가 전송되면 전송된 레코드 수를 증가시키고, 레코드 자체는 변경하지 않은 채 그대로 리턴함
    return producerRecord;
  }

  // 브로커가 보낸 응답을 클라이언트가 받았을 때 호출
  @Override
  public void onAcknowledgement(RecordMetadata recordMetadata, Exception e) {
    // 카프카카 ack 응답을 받으면 응답 수 변수를 증가시키고, 별도로 뭔가 리턴하지는 않음
    numAcked.incrementAndGet();
  }

  // 프로듀서에 close() 메서드가 호출될 때 호출됨
  // 인터셉터의 내부 상태를 정리하는 용도
  @Override
  public void close() {
    // 생성했던 스레드 풀 종료
    // 만일 파일을 열거나 원격 저장소에 연결을 생성했을 경우 여기서 닫아주어야 리소스 유실이 없음
    executorService.shutdownNow();
  }


  public static void run() {
    System.out.println(numSent.getAndSet(0));
    System.out.println(numAcked.getAndSet(0));
  }
}
```

인터셉터는 클라이언트 코드를 변경하지 않은채로 적용이 가능하다.

위 인터셉터를 카프카와 함께 배포되는 `kafka-console-producer.sh` 툴과 함께 사용하려면 아래와 같이 진행한다.

- 인터셉터를 컴파일하여 jar 파일로 만든 후 classpath 에 추가
```shell
export CLASSPATH=$CLASSPATH:~./target/CountProducerInterceptor.jar
```
- 아래와 같이 설정 파일 생성 (예-interceptor.config)
```shell
interceptor.classes=com.assu.study.CountProducerInterceptor
counting.interceptor.window.size.ms=10000
```
- 평소와 같이 애플리케이션을 실행시키되, 위에서 생성한 설정 파일을 포함하여 실행함
```shell
bin/kafka-console-producer.sh --brocker-list localhost:9092 --topic interceptor-test --producer.config producer.config
```

---

# 5. 쿼터, 스로틀링

카프카 브로커에는 쓰기/읽기 속도를 제한할 수 있는 기능이 있는데, 총 3개의 쿼터 타입에 대해 한도 설정이 가능하다.
- **produce quota (쓰기 쿼터)**
  - 클라이언트가 데이터는 전송할 때의 속도를 초당 바이트 수 단위로 제한
- **consume quota (읽기 쿼터)**
  - 클라이언트가 데이터를 받는 속도를 초당 바이트 수 단위로 제한
- **request quota (요청 쿼터)**
  - 브로커가 요청을 처리하는 시간 비율 단위로 제한

쿼터 설정은 아래와 같이 할 수 있다.
- **기본값 설정**
- **특정 `client.id` 값에 대해 설정**
- **특정 유저에 대해 설정**
  - 보안 기능과 클라이언트 인증 기능이 활성화되어 있는 클라이언트에서만 동작함
- **특정 `client.id` 와 특정 유저에 대해 둘 다 설정**

모든 클라이언트에 적용되는 쓰기/읽기 쿼터의 기본값은 카프카 브로커 설정 시 함께 설정할 수 있다.  
예) 각 프로듀서가 초당 평균적으로 쓸 수 있는 데이터를 2MB 로 제한한다면 브로커 설정 파일에 `quota.producer.default=2M` 추가

브로커 설정 파일에 특정 클라이언트에 대한 쿼터값을 정의해서 기본값을 덮어쓸 수도 있다. (권장되는 사항은 아님)  
예) clientA 에 초당 3MB, clientB 에 초당 5MB 쓰기 속도를 허용하고 싶다면 `quota.producer.override="clientA:3MB,clientB:5MB` 추가 

**카프카 설정 파일에 정의된 쿼터값을 변경하고 싶다면 설정 파일을 변경한 후 모든 브로커를 재시작해야 하므로 특정한 클라이언트에 쿼터를 적용할 때는 
`kafka-config.sh` 혹은 `AdminClient API` 에서 제공하는 동적 설정 기능을 사용**한다.

clientC 클라이언트(client.id 값으로 지정)의 쓰기 속도를 초당 1024 바이트로 제한
```shell
bin/kafka-configs --bootstrap-server localhost:9092 --alter \
  --add-config 'producer_byte_rate=1024' --entity-name clientC \
  -- entity-type clients
```

user1 (authenticated principal 로 지정) 의 쓰기 속도를 초당 1024 바이트로, 읽기 속도를 초당 2048 바이트로 제한
```shell
bin/kafka-configs --bootstrap-server localhost:9092 --alter \
  --add-config 'producer_byte_rate 1024,consumer_byte_rate=2048' \
  --entity-name user1 --entity-type users
```

모든 사용자의 읽기 속도를 초당 2048 바이트로 제한하되, 기본 설정값을 덮어쓰고 있는 사용자는 예외 처리
```shell
bin/kafka-configs --bootstrap-server localhost:9092 --alter \
  --add-config 'consumer_byte_rate=2048' --entity-type users
```

---

클라이언트가 할당량을 다 채우면 브로커는 클라이언트 요청에 대한 스로틀링을 시작하여 할당량을 초과하지 않도록 한다. (= 브로커가 클라이언트 요청에 대한 응답을 늦게 보내준다는 의미)  

대부분의 경우 클라이언트는 응답 대기가 가능한 요청의 수인 `max.in.flight.requests.per.connection` 가 한정되어 있기 때문에 이 상황에서 자동적으로 요청 속도를 줄이는 것이 
보통이다. 따라서 해당 클라이언트의 메시지 사용량이 할당량 아래로 줄어들게 되는 것이다.

클라이언트는 아래 JMX 메트릭스를 통하여 스로틀링 작동 여부를 확인할 수 있다.
- `- proruce-throttle-time-avg`
- `- proruce-throttle-time-max`
- `- fetch-throttle-time-avg`
- `- fetch-throttle-time-avg`

각각 쓰기/읽기 요청이 스로틀링 대문에 지연된 평균/최대 시간을 의미하는데, 이 값들은 쓰기 쿼터/읽기 쿼터에 의해 발생한 스로틀링 때문에 지연된 시간일 수도 있고, 
요청 쿼터 때문에 지연된 시간일 수도 있고, 둘 다 일 수도 있다.

---

## 브로커가 처리할 수 있는 용량과 프로듀서가 데이터를 전송하는 속도를 모니터링하고 맞춰주어야 하는 이유

비동기적으로 `Producer.send()` 를 호출하는 상황에서 브로커가 받아들일 수 있는 양 이상으로 메시지를 전송한다고 해보자.  
이 때 메시지는 클라이언트가 사용하는 메모리 상의 큐에 적재된다. 이 상태에서 계속 브로커가 수용가능한 양 이상으로 전송을 시도하는 경우 클라이언트의 버퍼 메모리가 고갈되면서 Producer.send() 호출을 블록하게 된다.

여기서 브로커가 밀린 메시지를 처리해서 프로듀서 버퍼에 공간이 확보될 때까지 기다리는 타임아웃 딜레이를 넘어가면 Producer.send() 는 TimeoutException 을 발생시킨다.  

만일 전송을 기다리는 배치에 이미 올라간 레코드는 대기 시간이 `deliverty.timeout.ms` 를 넘어가는 순간 무효화되고, TimeoutException 이 발생하면서 `send()` 메서드 호출 시 지정한 
콜백이 호출된다.

바로 이러한 이유 때문에 브로커가 처리할 수 있는 용량과 프로듀서가 데이터를 전송하는 속도를 모니터링하고 맞춰주어야 한다. 

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [컨플루언트 스키마 레지스트리 docs](https://docs.confluent.io/platform/current/schema-registry/index.html)
* [아파치 에이브로 docs](https://avro.apache.org/docs/current/)
* [에이브로 문서 중 호환성 규칙](https://avro.apache.org/docs/1.7.7/spec.html#Schema+Resolution)
* [컨플루언트 스키마 레지스트리 코드 (깃허브)](https://github.com/confluentinc/schema-registry)
* [컨플루언트 플랫폼](https://docs.confluent.io/platform/current/installation/overview.html)
* [ETL이란?](https://cloud.google.com/learn/what-is-etl?hl=ko)
* [파티션 수 결정: How to Choose the Number of Topics/Partitions in a Kafka Cluster?](https://www.confluent.io/blog/how-choose-number-topics-partitions-kafka-cluster/)