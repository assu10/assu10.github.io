---
layout: post
title:  "Kafka - 데이터 파이프라인(2): "
date: 2024-08-25
categories: dev
tags: kafka
---

이 포스트에서는 아래의 내용에 대해 알아본다.
- 카프카 커넥트의 기초적인 사용 방법과 기본적인 사용 예제
- 다른 데이터 통합 시스템과 이것들을 어떻게 카프카와 연동할 수 있는지?

---

**목차**

<!-- TOC -->
* [1. 카프카 커넥트](#1-카프카-커넥트)
  * [1.1. 카프카 커넥트 실행](#11-카프카-커넥트-실행)
    * [1.1.1. 커넥트 워커의 핵심 설정](#111-커넥트-워커의-핵심-설정)
      * [1.1.1.1. `bootstrap.servers`](#1111-bootstrapservers)
      * [1.1.1.2. `group.id`](#1112-groupid)
      * [1.1.1.3. `plugin.path`](#1113-pluginpath)
      * [1.1.1.4. `key.converter`, `value.converter`](#1114-keyconverter-valueconverter)
      * [1.1.1.5. `rest.advertised.host.name`, `rest.advertised.port`](#1115-restadvertisedhostname-restadvertisedport)
  * [1.2. 커넥터 예시: `FileStreamSourceConnector`, `FileStreamSinkConnector`](#12-커넥터-예시-filestreamsourceconnector-filestreamsinkconnector)
    * [1.2.1. 사전 준비](#121-사전-준비)
    * [1.2.2. `FileStreamSourceConnector`와 JSON 컨버터 사용](#122-filestreamsourceconnector와-json-컨버터-사용)
    * [1.2.3. `FileStreamSinkConnector` 로 토픽 내용을 파일로 전송](#123-filestreamsinkconnector-로-토픽-내용을-파일로-전송)
  * [1.3. 커넥터 예시: MySQL에서 Elasticsearch 로 데이터 전송](#13-커넥터-예시-mysql에서-elasticsearch-로-데이터-전송)
  * [1.4. 개별 메시지 변환](#14-개별-메시지-변환)
  * [1.5. 카프카 커넥트 좀 더 자세히](#15-카프카-커넥트-좀-더-자세히)
* [2. 카프카 커넥트 대안](#2-카프카-커넥트-대안)
  * [2.1. 다른 데이터 저장소를 위한 수집 프레임워크](#21-다른-데이터-저장소를-위한-수집-프레임워크)
  * [2.2. GUI 기반 ETL 툴](#22-gui-기반-etl-툴)
  * [2.3. 스트림 프로세싱 프레임워크](#23-스트림-프로세싱-프레임워크)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 카프카 커넥트

카프카 커넥트(줄여서 커넥트)는 아파치 카프카의 일부로서 **카프카와 다른 데이터 저장소 사이에 확장성과 신뢰성을 가지면서 데이터를 주고 받을 수 있는 수단을 제공**한다.  
카프카 커넥트는 커넥터 플러그인을 개발하고 실행하기 위한 API 와 런타임을 제공한다.  
**커넥터 플러그인은 카프카 커넥트가 실행시키는 라이브러리로, 데이터를 이동시키는 것을 담당**한다.

<**카프카 커넥터**>
- 여러 워커 프로세스들의 클러스터 형태로 실행됨
- 사용자는 워커에 커넥터 플러그인을 설치한 뒤 REST API 를 사용하여 커넥터별 설정을 잡아주거나 관리하면 됨
- 대용량의 데이터 이동을 병렬화해서 처리하고, 워커의 유휴 자원을 더 효율적으로 활용하기 위해 **태스크를 추가로 실행**시킴
- **소스 커넥터 태스크**는 원본 시스템으로부터 데이터를 읽어와서 카프카 커넥트 자료 객체의 형태로 워커 프로세스에 전달함
- **싱크 커넥터 태스크**는 워커로부터 카프카 커넥트 자료 객체를 받아서 대상 시스템에 쓰는 작업을 담당함
- 카프카 커넥트는 자료 객체를 카프카에 쓸 때 사용되는 형식으로 바꿀 수 있도록 **컨버터**를 사용함
  - JSON 형식 기본 지원
  - 컨플루언트 스키마 레지스트리와 함께 사용할 경우 Avro, Protobuf, JSON 스키마 컨버터 지원
  - 따라서 사용하는 커넥터와 상관없이 카프카에 저장되는 형식 뿐 아니라 저장되는 데이터의 스키마도 선택할 수 있음

여기서는 카프카 커넥트의 개요와 간단한 사용법에 대해 다룬다.

---

## 1.1. 카프카 커넥트 실행

카프카 커넥트는 아파치 카프카에 포함되어 배포되므로 별도로 설치할 필요는 없다.  
카프카 커넥트를 프로덕션 환경에서 사용할 경우엔 카프카 브로커와는 별도의 서버에서 커넥트를 실행시켜야 한다. (특히 대량의 데이터를 옮기기 위해 카프카 커넥트를 사용하거나 많은 수의 커넥터를 사용하는 경우)  
이런 경우엔 일단 모든 서버에 카프카를 설치한 후 일부에서는 브로커를 실행시키고, 나머지에서는 카프카 커넥트를 실행시키면 된다.

> 주키퍼와 브로커를 실행시키는 방법은 [1.1.1. 독립 실행 서버](https://assu10.github.io/dev/2024/06/15/kafka-install/#111-%EB%8F%85%EB%A6%BD-%EC%8B%A4%ED%96%89-%EC%84%9C%EB%B2%84) 를 참고하세요.

카프카 커넥트 워커를 실행

``` shell
$ pwd
/Users/juhyunlee/Developer/kafka/kafka_2.13-3.8.0

$ bin/connect-distributed.sh config/connect-distributed.properties
```

만일 카프카 커넥트를 standalone mode 로 실행시키고자 한다면 아래와 같이 실행하면 된다.

``` shell
$ pwd
/Users/juhyunlee/Developer/kafka/kafka_2.13-3.8.0

$ bin/connect-standalone.sh config/connect-standalone.properties
```

standalone 모드를 사용하면 모든 커넥터와 태스크들이 하나의 독립 실행 워커에서 돌아한다.  
standalone 모드는 커넥터나 태스크가 특정한 장비에서 실행되어야 하는 경우에 사용된다.  
예) syslog 커넥터가 특정 포트에서 요청을 받고 있을 경우, 이 커넥터가 어느 장비에서 작동 중인지 알아야 함

---

### 1.1.1. 커넥트 워커의 핵심 설정

kafka_2.13-3.8.0/config/connect-distributed.properties 기본 설정값

```properties
bootstrap.servers=localhost:9092
group.id=connect-cluster

key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true

offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
#offset.storage.partitions=25

offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
#offset.storage.partitions=25

config.storage.topic=connect-configs
config.storage.replication.factor=1

status.storage.topic=connect-status
status.storage.replication.factor=1
#status.storage.partitions=5

offset.flush.interval.ms=10000

#listeners=HTTP://:8083

#rest.advertised.host.name=
#rest.advertised.port=
#rest.advertised.listener=

# plugin.path=/usr/local/share/java,/usr/local/share/kafka/plugins,/opt/connectors,
#plugin.path=
```

kafka_2.13-3.8.0/config/connect-standalone.properties 기본 설정값

```properties
bootstrap.servers=localhost:9092

key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true

offset.storage.file.filename=/tmp/connect.offsets

offset.flush.interval.ms=10000

# plugin.path=/usr/local/share/java,/usr/local/share/kafka/plugins,/opt/connectors,
#plugin.path=
```


#### 1.1.1.1. `bootstrap.servers`

카프카 커넥트와 함께 작동하는 카프카 브로커의 목록이다.

커넥커는 다른 곳의 데이터를 이 브로커로 전달하거나, 이 브로커의 데이터를 다른 시스템으로 전달한다.  
클러스터 안의 모든 브로커를 지정할 필요는 없지만, 최소 3개 이상이 권장된다.

```properties
bootstrap.servers=localhost:9092
```

---

#### 1.1.1.2. `group.id`

동일한 그룹 ID 를 갖는 모든 워커들은 같은 커넥트 클러스터를 구성한다.  
실행된 커넥터를 클러스터 내의 어느 워커에서도 실행될 수 있으며, 태스크 또한 마찬가지이다.

```properties
group.id=connect-cluster
```

---

#### 1.1.1.3. `plugin.path`

카프카 커넥트는 커넥터, 컨버터, 트랜스포메이션, 비밀 제공자를 다운로드받아서 플랫폼에 플러그인할 수 있도록 설계되어 있고, 카프카 커넥트는 이런 플러그인을 찾아서 
적재할 수 있어야 한다.

카프카 커넥트에는 커넥터와 그 의존성들을 찾을 수 있는 디렉터리를 1개 이상 설정할 수 있다.  
예) _plugin.path=/usr/local/share/java,/opt/connectors,_

보통 이 디렉터리 중 하나에 커넥터별로 서브 디렉터리를 하나씩 만들어준다.  
예) _opt/connectors/jdbc_, _/opt/connectors/elastic_ 을 만들고 이 안에 커넥터 jar 파일과 모든 의존성들을 저장함

만일 커넥터가 uberJar 형태여서 별도의 의존성이 없다면 서브 디렉터리 필요없이 `plugin.path` 아래 바로 저장 가능하다. 
단, `plugin.path` 에 의존성을 바로 저장할 수는 없다.

> **uberJar**
> 
> uber 는 독일어로 above 혹은 over 라는 의미임  
> uberJar 는 패키징 시 제작된 모듈과 그것의 디펜던시가 하나의 jar 파일에 포함된 것을 의미함  
> 즉, 목적지에 설치 시 디펜던시에 대한 고려가 필요없다는 것을 의미함

카프카 커넥트의 클래스패스에 커넥터를 의존성과 함께 추가할 수는 있지만 그렇게 하게 되면 커넥터의 의존성과 카프카의 의존성이 충돌할 때 에러가 발생할 수 있기 때문에 
클래스패스를 이용하는 것보다는 `plugin.path` 설정을 사용하는 것을 권장한다.

```properties
plugin.path=/usr/local/share/java,/usr/local/share/kafka/plugins,/opt/connectors,
```

---

#### 1.1.1.4. `key.converter`, `value.converter`

카프카 커넥트는 카프카에 저장된 여러 형식의 데이터를 처리할 수 있다.

카프카에 저장될 메시지의 key 와 value 각각에 대해 컨버터를 설정해줄 수 있으며, 기본값은 아파치 카프카에 포함되어 있는 JSONConverter 를 사용하는 JSON 형식이다.  
컨플루언트 스키마 레지스트리의 AvroConverter, ProtobufConverter, JsonSchemaConverter 도 사용 가능하다.  
위 3개의 컨버터를 사용하기 위해서는 먼저 [스키마 레지스트리 프로젝트](https://github.com/confluentinc/schema-registry) 소스 코드를 다운로드 받은 후 빌드해주어야 한다.

어떤 컨버터는 해당 컨버터에만 한정하여 사용 가능한 설정 매개변수들이 있는데 이런 설정 매개변수가 있을 경우 매개변수 이름 앞에 _key.converter._, _value.converter._ 를 붙여주어 
설정 가능하다.  
예) JSON 메시지에 스키마를 포함하고 싶다면 `key.converter.schema.enable=true` 로 설정

Avro 메시지에도 스키마는 있지만 `key.converter.schema.registry.url` 이나 `value.converter.schema.registry.url` 을 사용하여 스키마 레지스트리의 
위치를 잡아주어야 한다.

```properties
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
```

---

#### 1.1.1.5. `rest.advertised.host.name`, `rest.advertised.port`

커넥터를 설정하거나 모니터링할 때는 카프카 커넥트의 REST API 를 사용하는 것이 보통이다.

클러스터에 워커가 돌아가고 있다면 아래와 같이 REST API 를 호출해서 확인할 수 있다.

현재 실행되고 있는 카프카 커넥트 버전 확인

```shell
# bin/connect-distributed.sh config/connect-distributed.properties 로 카프카 커넥트 워커 실행 시 포트는 8083 으로 잡힘
$ curl http://localhost:8083
{"version":"3.8.0","commit":"771b9576b00ecf5b","kafka_cluster_id":"OK7ZY6vnQaGPnu125uV04g"}
```

사용 가능한 커넥터 목록 확인

```shell
$ curl http://localhost:8083/connector-plugins | jq
[
  {
    "class": "org.apache.kafka.connect.mirror.MirrorCheckpointConnector",
    "type": "source",
    "version": "3.8.0"
  },
  {
    "class": "org.apache.kafka.connect.mirror.MirrorHeartbeatConnector",
    "type": "source",
    "version": "3.8.0"
  },
  {
    "class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "type": "source",
    "version": "3.8.0"
  }
]
```

위 코드에서는 아파치 카프카 본체만 실행시키고 있기 때문에 사용 가능한 커넥터는 미러메이커 2.0 에 포함된 커넥터뿐이다.

```properties
rest.advertised.host.name=
rest.advertised.port=
rest.advertised.listener=
```

---

## 1.2. 커넥터 예시: `FileStreamSourceConnector`, `FileStreamSinkConnector`

### 1.2.1. 사전 준비

> 카프카 3.2 버전부터 `FileStreamSourceConnector` 와 `FileStreamSinkConnector` 가 기본 클래스패스에서 제거됨  
> [Notable changes in 3.2.0](https://kafka.apache.org/documentation/#upgrade_320_notable)

파일 소스 커넥터와 파일 싱크 커넥터를 사용하기 위해 아래의 작업을 해주자.

```shell
$ pwd
/Users/kafka/kafka_2.13-3.8.0

# plugin.path 에 넣을 주소
$ mkdir -p opt/kafka-connect-plugins

# FileStreamSourceConnector, FileStreamSinkConnector 가 포함된 jar 파일을 위에서 만든 폴더로 복사
$ cp -r libs/connect-file-3.8.0.jar opt/kafka-connect-plugins
```

config/connect-distributed.properties 의 `plugin.path` 수정 후 카프카 커넥트 재시작

```properties
plugin.path=/Users/kafka/kafka_2.13-3.8.0/opt/kafka-connect-plugins
```

```shell
$ bin/connect-distributed.sh config/connect-distributed.properties
```

이제 사용 가능한 커넥터 목록을 다시 확인해보면 FileStreamSinkConnector 와 FileStreamSourceConnector 가 추가된 것을 확인할 수 있다.

```shell
$ curl http://localhost:8083/connector-plugins | jq
[
  {
    "class": "org.apache.kafka.connect.file.FileStreamSinkConnector",
    "type": "sink",
    "version": "3.8.0"
  },
  {
    "class": "org.apache.kafka.connect.file.FileStreamSourceConnector",
    "type": "source",
    "version": "3.8.0"
  },
  {
    "class": "org.apache.kafka.connect.mirror.MirrorCheckpointConnector",
    "type": "source",
    "version": "3.8.0"
  },
  {
    "class": "org.apache.kafka.connect.mirror.MirrorHeartbeatConnector",
    "type": "source",
    "version": "3.8.0"
  },
  {
    "class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "type": "source",
    "version": "3.8.0"
  }
]
```

---

### 1.2.2. `FileStreamSourceConnector`와 JSON 컨버터 사용

여기서는 파일 커넥터와 JSON 컨버터를 사용하는 방법에 대해 알아본다.

먼저 **주키퍼와 카프카를 실행**시킨다.

```shell
# 주키퍼 시작
$ pwd
/Users/zookeeper/apache-zookeeper-3.9.2-bin/bin

$ ./zKServer.sh start

# 카프카 브로커 시작
$ pwd
/Users/Developer/kafka

$ kafka_2.13-3.8.0/bin/kafka-server-start.sh -daemon \
     kafka_2.13-3.8.0/config/server.properties
```

> 주키퍼와 카프카를 시작하는 방법은 각각 [1.1.1. 독립 실행 서버](https://assu10.github.io/dev/2024/06/15/kafka-install/#111-%EB%8F%85%EB%A6%BD-%EC%8B%A4%ED%96%89-%EC%84%9C%EB%B2%84) 와 
> [2. 카프카 브로커 설치](https://assu10.github.io/dev/2024/06/15/kafka-install/#2-%EC%B9%B4%ED%94%84%EC%B9%B4-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%EC%84%A4%EC%B9%98) 를 참고하세요.

이제 **분산 모드로 커넥트 워커**를 실행한다. 프로덕션 환경에서는 고가용성을 위해 최소 2~3개의 프로세스를 실행시키지만 여기서는 하나만 실행시킨다.

```shell
# 커넥트 워커 실행
$  pwd
/Users/Developer/kafka/kafka_2.13-3.8.0

$ bin/connect-distributed.sh config/connect-distributed.properties
```

이제 **파일 소스를 시작**시킨다.  
여기서는 카프카의 설정 파일을 읽어오도록 커넥터를 설정한다. (= 카프카 설정을 토픽으로 보냄)

```shell
# 파일 소스 시작
$ echo '{"name":"load-kafka-config", "config":{"connector.class":"FileStreamSource","file":"/Users/kafka/kafka_2.13-3.8.0/config/server.properties","topic":"kafka-config-topic"}}' | curl -X POST -d @- http://localhost:8083/connectors -H "Content-Type: application/json" | jq

{
  "name": "load-kafka-config",
  "config": {
    "connector.class": "FileStreamSource",
    "file": "/Users/kafka/kafka_2.13-3.8.0/config/server.properties",
    "topic": "kafka-config-topic",
    "name": "load-kafka-config"
  },
  "tasks": [],
  "type": "source"
}
```

커넥터를 생성하기 위해 _load-kafka-config_ 라는 이름과 설정맵을 포함하는 JSON 형식을 사용하였다.  
설정맵에는 커넥터 클래스 명, 읽고자 하는 파일의 위치, 파일에서 읽은 내용을 보내고자 하는 토픽 이름이 포함된다.

이제 [컨슈머를 사용](https://assu10.github.io/dev/2024/06/15/kafka-install/#2-%EC%B9%B4%ED%94%84%EC%B9%B4-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%EC%84%A4%EC%B9%98)해서 카프카 설정 파일의 내용이 토픽에 제대로 저장되었는지 확인해보자.

```shell
$ bin/kafka-console-consumer.sh --bootstrap-server=localhost:9092 \
--topic kafka-config-topic --from-beginning

{"schema":{"type":"string","optional":false},"payload":"#    2. Latency: Very large flush intervals may lead to latency spikes when the flush does occur as there will be a lot of data to flush."}
//...
```

이것은 server.properties 파일의 내용이 커넥터에 의해 줄 단위로 JSON 으로 변환된 뒤 kafka-config-topic 토픽에 저장된 것이다.

JSON 컨버터는 레코드마다 스키마 정보를 포함시키는 것이 기본 작동이다.  
위의 경우엔 단순히 string 타입의 열이 payload 하나만 있는 것이다.  
각 레코드는 파일 한 줄 씩을 포함한다.

---

### 1.2.3. `FileStreamSinkConnector` 로 토픽 내용을 파일로 전송

이제 sink 커넥터를 사용해서 토픽의 내용을 파일로 내보자보자.  
JSON 컨버터가 JSON 레코드를 텍스트 문자열로 원상복구하기 때문에 생성된 파일은 원본인 server.properties 와 완전히 동일할 것이다.

```shell
$ echo '{"name":"dump-kafka-config", "config":{"connector.class":"FileStreamSink","file":"/Users/juhyunlee/Developer/kafka/kafka_2.13-3.8.0/config/copy-of-server.properties","topics":"kafka-config-topic"}}' | curl -X POST -d @- http://localhost:8083/connectors --header "Content-Type: application/json" | jq

{
  "name": "dump-kafka-config",
  "config": {
    "connector.class": "FileStreamSink",
    "file": "/Users/kafka_2.13-3.8.0/config/copy-of-server.properties",
    "topics": "kafka-config-topic",
    "name": "dump-kafka-config"
  },
  "tasks": [],
  "type": "sink"
}
```

`FileStreamSinkConnector` 를 사용할 때와 다른 점은 아래와 같다.  
`file` 속성이 있지만 이것은 레코드를 읽어 올 파일이 아닌 레코드를 쓸 파일을 가리키며, 토픽 하나를 지정하는 대신 다수의 토픽을 지정하는 `topics` 를 사용한다.  
즉, 소스 커넥터는 하나의 토픽에만 쓸 수 있는 반면, 싱크 커넥터를 여러 토픽의 내용을 하나의 sink 파일에 쓸 수 있다.

이제 **커넥터를 삭제**한다.

```shell
# 커넥터 확인
$ curl -X GET http://localhost:8083/connectors
["dump-kafka-config","load-kafka-config"]%

$ curl -X DELETE http://localhost:8083/connectors/load-kafka-config
$ curl -X DELETE http://localhost:8083/connectors/dump-kafka-config

$ curl -X GET http://localhost:8083/connectors
[]
```

---

## 1.3. 커넥터 예시: MySQL에서 Elasticsearch 로 데이터 전송

---

## 1.4. 개별 메시지 변환

---

## 1.5. 카프카 커넥트 좀 더 자세히

---

# 2. 카프카 커넥트 대안

---

## 2.1. 다른 데이터 저장소를 위한 수집 프레임워크

---

## 2.2. GUI 기반 ETL 툴

---

## 2.3. 스트림 프로세싱 프레임워크



---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [Blog:: uberJar](https://opennote46.tistory.com/110)
* [Git:: 스키마 레지스트리 프로젝트](https://github.com/confluentinc/schema-registry)