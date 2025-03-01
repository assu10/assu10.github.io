---
layout: post
title:  "Kafka - 데이터 파이프라인(2): 카프카 커넥트"
date: 2024-08-25
categories: dev
tags: kafka kafka-connect smt cdc kafka-converter
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
    * [1.2.1. `FileStreamSourceConnector`, `FileStreamSinkConnector` 추가](#121-filestreamsourceconnector-filestreamsinkconnector-추가)
    * [1.2.2. `FileStreamSourceConnector`와 JSON 컨버터 사용](#122-filestreamsourceconnector와-json-컨버터-사용)
    * [1.2.3. `FileStreamSinkConnector` 로 토픽 내용을 파일로 전송](#123-filestreamsinkconnector-로-토픽-내용을-파일로-전송)
  * [1.3. 커넥터 예시: MySQL에서 Elasticsearch 로 데이터 전송](#13-커넥터-예시-mysql에서-elasticsearch-로-데이터-전송)
    * [1.3.1. 커넥터 추가 및 확인: `ElasticsearchSinkConnector`, `JdbcSinkConnector`, `JdbcSourceConnector`](#131-커넥터-추가-및-확인-elasticsearchsinkconnector-jdbcsinkconnector-jdbcsourceconnector)
    * [1.3.2. MySQL 테이블 생성 및 데이터 추가](#132-mysql-테이블-생성-및-데이터-추가)
    * [1.3.2. JDBC 소스 커넥터 설정 및 토픽 확인](#132-jdbc-소스-커넥터-설정-및-토픽-확인)
      * [1.3.2.1. CDC(Change Data Capture, 변경 데이터 캡처) 와 디비지움 프로젝트](#1321-cdcchange-data-capture-변경-데이터-캡처-와-디비지움-프로젝트)
    * [1.3.3. 엘라스틱서치 동작 확인](#133-엘라스틱서치-동작-확인)
    * [1.3.4. 엘라스틱서치 싱크 커넥터 설정](#134-엘라스틱서치-싱크-커넥터-설정)
    * [1.3.5. 엘라스틱서치 인덱스 확인](#135-엘라스틱서치-인덱스-확인)
  * [1.4. SMT(Single Message Transformation, 개별 메시지 변환)](#14-smtsingle-message-transformation-개별-메시지-변환)
    * [1.4.1. SMT 이용](#141-smt-이용)
    * [1.4.2. 에러 처리와 데드 레터 큐(Dead Letter Queue): `error.tolerance`](#142-에러-처리와-데드-레터-큐dead-letter-queue-errortolerance)
  * [1.5. 카프카 커넥트 구성 요소](#15-카프카-커넥트-구성-요소)
    * [1.5.1. 커넥터, 태스크(task)](#151-커넥터-태스크task)
      * [1.5.1.1. 커넥터](#1511-커넥터)
      * [1.5.1.2. 태스크](#1512-태스크)
    * [1.5.2. 워커(worker)](#152-워커worker)
    * [1.5.3. 컨버터, 커넥트 데이터 모델](#153-컨버터-커넥트-데이터-모델)
      * [1.5.3.1. 소스 커넥터에서의 컨버터 역할](#1531-소스-커넥터에서의-컨버터-역할)
      * [1.5.3.2. 싱크 커넥터에서의 컨버터 역할](#1532-싱크-커넥터에서의-컨버터-역할)
    * [1.5.4. 오프셋 관리](#154-오프셋-관리)
      * [1.5.4.1. 소스 커넥터에서의 오프셋: `offset.storage.topic`, `config.storage.topic`, `status.storage.topic`](#1541-소스-커넥터에서의-오프셋-offsetstoragetopic-configstoragetopic-statusstoragetopic)
      * [1.5.4.2. 싱크 커넥터에서의 오프셋](#1542-싱크-커넥터에서의-오프셋)
* [2. 카프카 커넥트 대안](#2-카프카-커넥트-대안)
  * [2.1. 다른 데이터 저장소를 위한 수집 프레임워크](#21-다른-데이터-저장소를-위한-수집-프레임워크)
  * [2.2. GUI 기반 ETL 툴](#22-gui-기반-etl-툴)
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
/Users/Developer/kafka/kafka_2.13-3.8.0

$ bin/connect-distributed.sh config/connect-distributed.properties
```

만일 카프카 커넥트를 standalone mode 로 실행시키고자 한다면 아래와 같이 실행하면 된다.

``` shell
$ pwd
/Users/Developer/kafka/kafka_2.13-3.8.0

$ bin/connect-standalone.sh config/connect-standalone.properties
```

standalone 모드를 사용하면 모든 커넥터와 태스크들이 하나의 독립 실행 워커에서 돌아간다.  
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

> 여기서 사용하는 파일 커넥터는 제한도 많고 신뢰성 보장도 없기 때문에 **실제 프로덕션 파이프라인에서 사용하면 안됨**
> 
> 파일에서 데이터를 수집하고자 한다면 아래와 같은 대안들을 사용하는 것을 권장함  
> [Git:: FilePulse 커넥터](https://github.com/streamthoughts/kafka-connect-file-pulse)  
> [Git:: FileSystem 커넥터](https://github.com/mmolimar/kafka-connect-fs)  
> [Git:: SpoolDir](https://github.com/jcustenborder/kafka-connect-spooldir)

---

### 1.2.1. `FileStreamSourceConnector`, `FileStreamSinkConnector` 추가

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

이제 사용 가능한 커넥터 목록을 다시 확인해보면 `FileStreamSinkConnector` 와 `FileStreamSourceConnector` 가 추가된 것을 확인할 수 있다.

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
$ echo '{"name":"dump-kafka-config", "config":{"connector.class":"FileStreamSink","file":"/Users/Developer/kafka/kafka_2.13-3.8.0/config/copy-of-server.properties","topics":"kafka-config-topic"}}' | curl -X POST -d @- http://localhost:8083/connectors --header "Content-Type: application/json" | jq

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

JDBC source 와 엘라스틱서치 sink 를 빌드하고 설치하는 방법에 대해 알아본다.  
MySQL 테이블 하나의 내용을 카프카로 보낸 후 다시 엘라스틱서치로 보내서 내용물을 인덱싱한다.

먼저 MySQL 과 엘라스틱서치를 설치한다.

docker 로 MySQL 띄우는 방법은 [3. Rancher Desktop 설치 및 mysql docker container 띄우기](https://assu10.github.io/dev/2022/02/02/rancher-desktop/#3-rancher-desktop-%EC%84%A4%EC%B9%98-%EB%B0%8F-mysql-docker-container-%EB%9D%84%EC%9A%B0%EA%B8%B0) 를 참고하세요.


elasticsearch 설치

```shell
# tap 을 통해 homebrew 가 설치할 수 있는 repository 추가
$ brew tap elastic/tap

# install
$ brew install elastic/tap/elasticsearch-full

Data:    /usr/local/var/lib/elasticsearch/elasticsearch/
Logs:    /usr/local/var/log/elasticsearch/elasticsearch.log
Plugins: /usr/local/var/elasticsearch/plugins/
Config:  /usr/local/etc/elasticsearch/

To start elastic/tap/elasticsearch-full now and restart at login:
  brew services start elastic/tap/elasticsearch-full
Or, if you don t want/need a background service you can just run:
  /usr/local/opt/elasticsearch-full/bin/elasticsearch
==> Summary
🍺  /usr/local/Cellar/elasticsearch-full/7.17.4: 948 files, 476.2MB, built in 14 seconds
==> Running `brew cleanup elasticsearch-full`...
Disable this behaviour by setting HOMEBREW_NO_INSTALL_CLEANUP.
Hide these hints with HOMEBREW_NO_ENV_HINTS (see man brew).
```

---

### 1.3.1. 커넥터 추가 및 확인: `ElasticsearchSinkConnector`, `JdbcSinkConnector`, `JdbcSourceConnector`

사용하려는 커넥터가 현재 있는지 확인하는 방법은 여러 가지가 있다.

- [컨플루언트 허브 웹사이트](https://www.confluent.io/hub/)에서 다운로드
- [confluentinc git](https://github.com/confluentinc/) 소스 코드에서 직접 빌드

컨플루언트는 사전에 빌드된 많은 커넥터들을 [컨플루언트 허브 웹사이트](https://www.confluent.io/hub/) 에서 유지 관리하고 있기 때문에 사용자고자 하는 
커넥터가 있다면 컨플루언트 허브에서 찾아서 사용하면 된다.

```shell
# 커넥터 소스 코드 클론
$ git clone https://github.com/confluentinc/kafka-connect-elasticsearch
$ git clone https://github.com/confluentinc/kafka-connect-jdbc

# 프로젝트 빌드
$ mvn install -DskipTest
```

빌드가 끝나면 target 디렉터리에 jar 파일이 생성되어 있다.

이제 jdbc 와 elasticsearch **커넥터들을 추가**한다.

_/opt/connectors_ 와 같은 디렉터리를 만든 후 _config/connect-distributed.properties_ 에 `plugin.path=/opt/connectors` 를 넣어준다.

커넥터 저장

```shell
$ pwd
/Users/Developer/kafka/opt/connectors

$ ll
total 0
drwxr-xr-x  2  staff    64B Dec 22 16:31 elastic
drwxr-xr-x  2  staff    64B Dec 22 16:31 jdbc

$ cp ./temp/kafka-connect-jdbc/target/kafka-connect-jdbc-10.9.0-SNAPSHOT.jar ./kafka/opt/connectors/jdbc
$ cp ./temp/kafka-connect-elasticsearch/target/kafka-connect-elasticsearch-14.2.0-SNAPSHOT-package/share/java/kafka-connect-elasticsearch/* ./kafka/opt/connectors/elastic
```

connect-distributed.properties 수정

```shell
$ pwd
/Users/kafka/kafka_2.13-3.8.0/config

$ vi connect-distributed.properteis

plugin.path=/Users/kafka/kafka_2.13-3.8.0/opt/kafka-connect-plugins,/Users/kafka/opt/connectors
```

이제 [MySQL JDBC 드라이버](https://dev.mysql.com/downloads/connector/j/)를 다운로드하여 _/opt/connectors/jdbc_ 아래 넣어준다.

이제 커넥트 워커를 재시작하여 설치해 준 플러그인들이 잘 보이는지 확인한다.

```shell
$ bin/connect-distributed.sh config/connect-distributed.properties
```

```shell
$ curl http://localhost:8083/connector-plugins | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   824  100   824    0     0  21836      0 --:--:-- --:--:-- --:--:-- 22270
[
  {
    "class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
    "type": "sink",
    "version": "14.2.0-SNAPSHOT"
  },
  {
    "class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "type": "sink",
    "version": "10.9.0-SNAPSHOT"
  },
  {
    "class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "type": "source",
    "version": "10.9.0-SNAPSHOT"
  },
  // ...
]
```

---

### 1.3.2. MySQL 테이블 생성 및 데이터 추가

이제 JDBC 커넥터를 사용하여 카프카로 데이터를 스트리밍해줄 MySQL 테이블을 생성한다.

```sql
create table login (username varchar(30), login_time datetime);

insert into login values ('assu', now());
insert into login values ('silby', now());
```

---

### 1.3.2. JDBC 소스 커넥터 설정 및 토픽 확인

JDBC 소스 커넥터 설정 시 사용 가능한 옵션들은 [3.5 Kafka Connect Configs](https://kafka.apache.org/documentation/#connectconfigs) 에도 있고, 
아래처럼 REST API 를 호출하여 볼 수도 있다.

아래는 커넥터 설정의 유효성을 검사할 때 쓰이는 REST API 에 클래스명만 포함되어 있는 설정을 보내는 예시이다. (= 최소한의 커넥터 설정이기도 함)  
응답은 JSON 형태로 된 모든 사용 가능한 설정에 대한 정의를 준다.

```shell
$ curl -X PUT -H "Content-Type: application/json" -d '{
"connector.class": "JdbcSource"
}' 'http://localhost:8083/connector-plugins/JdbcSourceConnector/config/validate/' | jq

{
  "config": [
    {
      "definition": {
        // ...
      }
    }
  ]
  // ...
}
```

이제 **JDBC 커넥터를 설정하고 생성**해보자.

```shell
$ echo '{
  "name": "mysql-login-connector",
  "config": {
    "connector.class": "JdbcSourceConnector",
    "connection.url": "jdbc:mysql://localhost:13306/kafka?user=root&password=비밀번호",
    "mode": "timestamp",
    "table.whitelist": "login",
    "validate.non.null": false,
    "timestamp.column.name": "login_time",
    "topic.prefix": "mysql."
  }
}' |
curl -X POST -H "Content-Type: application/json" -d @- 'http://localhost:8083/connectors'

{
  "name": "mysql-login-connector",
  "config": {
    "connector.class": "JdbcSourceConnector",
    "connection.url": "jdbc:mysql://localhost:13306/kafka?user=root&password=비밀번호",
    "mode": "timestamp",
    "table.whitelist": "login",
    "validate.non.null": "false",
    "timestamp.column.name": "login_time",
    "topic.prefix": "mysql.",
    "name": "mysql-login-connector"
  },
  "tasks": [],
  "type": "source"
}
```

이제 _mysql.login_ 토픽으로부터 제대로 데이터를 읽어오는지 확인해본다.

```shell
$ bin/kafka-console-consumer.sh --bootstrap-server=localhost:9092 \
--topic mysql.login --from-beginning | jq
{
  "schema": {
    "type": "struct",
    "fields": [
      {
        "type": "string",
        "optional": true,
        "field": "username"
      },
      {
        "type": "int64",
        "optional": true,
        "name": "org.apache.kafka.connect.data.Timestamp",
        "version": 1,
        "field": "login_time"
      }
    ],
    "optional": false,
    "name": "login"
  },
  "payload": {
    "username": "assu",
    "login_time": 1734856216000
  }
}
{
  "schema": {
    "type": "struct",
    "fields": [
      {
        "type": "string",
        "optional": true,
        "field": "username"
      },
      {
        "type": "int64",
        "optional": true,
        "name": "org.apache.kafka.connect.data.Timestamp",
        "version": 1,
        "field": "login_time"
      }
    ],
    "optional": false,
    "name": "login"
  },
  "payload": {
    "username": "silby",
    "login_time": 1734856216000
  }
}
```

커넥터가 돌아가기 시작했다면 login 테이블에 데이터를 추가할 때마다 _mysql.login_ 토픽에 레코드가 추가된다.

---

#### 1.3.2.1. CDC(Change Data Capture, 변경 데이터 캡처) 와 디비지움 프로젝트

[1.3.2. JDBC 소스 커넥터 설정 및 토픽 확인](#132-jdbc-소스-커넥터-설정-및-토픽-확인) 에서 사용한 JDBC 커넥터는 JDBC 와 SQL 을 사용하여 테이블에 새로 들어온 
레코드를 찾아낸다.  
더 정확히는 타임스탬프 필드와 기본키 필드가 증가하는 것을 사용하여 새로운 레코드를 탐지하는 방식이다.

이 방식은 비효율적이며 때로는 정확하지 않은 결과를 낸다.

모든 RDBMS 는 트랜잭션 로그를 포함하며, 대부분 외부 시스템이 트랜잭션 로그를 직접 읽어갈 수 있도록 하고 있다.  
이렇게 **트랜잭션 로그를 읽음으로써 RDBMS 레코드의 변경을 탐지하는 방식을 CDC(Change Data Capture, 변경 데이터 캡처)** 라고 한다.

CDC 방식은 위에서 설명한 특정 필드와 SQL 문을 사용하는 것에 비해 훨씬 정확하고 효율적이다.

대부분의 최신 [`ETL(Extract-Transform-Load)`](https://assu10.github.io/dev/2024/08/24/kafka-data-pipeline-1/#151-etlextract-transform-load) 시스템들은 CDC 를 
데이터 저장소로써 사용한다.

[디비지움 프로젝트](https://debezium.io/) 는 다양한 DB 에 대한 오픈소스 CDC 커넥터를 제공한다.

만일 **RDBMS 에서 카프카로의 데이터 스트리밍을 해야한다면 Debezium 에 포함된 CDC 커넥터를 사용할 것을 강력히 권장**한다.

---

### 1.3.3. 엘라스틱서치 동작 확인

MySQL 데이터를 카프카로 동기화했으니 이제 이 카프카에 있는 데이터를 다시 엘라스틱서치로 보내보자.

**엘라스틱서치를 시작**하고 로컬 포트로 접속하여 **정상 동작하는지 확인**한다.

> elasticsearch 7.17.4 는 JAVA 11 을 권장하기 때문에 JAVA 11 로 설치 후 실행 필요

```shell
# JAVA 11 설치
$ brew install --cask temurin11

# JAVA_HOME 환경 변수 설정
$ export JAVA_HOME=$(/usr/libexec/java_home -v 11)
```

```shell
# 실행
$ pwd
/usr/local/bin

# elasticsearch 실행
$ elasticsearch &

# 확인
$ curl -X GET localhost:9200
{
  "name" : "assu-MacBook-Pro.local",
  "cluster_name" : "elasticsearch_assu",
  "cluster_uuid" : "X63Zvvw_RYKp2NpW1n6oog",
  "version" : {
    "number" : "7.17.4",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "79878662c54c886ae89206c685d9f1051a9d6411",
    "build_date" : "2022-05-18T18:04:20.964345128Z",
    "build_snapshot" : false,
    "lucene_version" : "8.11.1",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

---

### 1.3.4. 엘라스틱서치 싱크 커넥터 설정

이제 **커넥터를 생성하고 시작**시킨다.

```shell
$ echo '{
  "name": "elastic-login-connector",
  "config": {
    "connector.class": "ElasticsearchSinkConnector",
    "connection.url": "http://localhost:9200",
    "type.name": "mysql-data",
    "topics": "mysql.login",
    "key.ignore": "true"
  }
}' |
curl -X POST -H "Content-Type: application/json" -d @- 'http://localhost:8083/connectors'

{
  "name": "elastic-login-connector",
  "config": {
    "connector.class": "ElasticsearchSinkConnector",
    "connection.url": "http://localhost:9200",
    "type.name": "mysql-data",
    "topics": "mysql.login",
    "key.ignore": "true",
    "name": "elastic-login-connector"
  },
  "tasks": [],
  "type": "sink"
}
```

위에서 `connection.url` 은 로컬 엘라스틱 서버의 URL 이다.  
기본적으로 카프카 각 토픽은 별개의 엘라스틱서치 인덱스와 동기화되며, 인덱스의 이름은 토픽과 동일하다.

위에서는 _mysql.login_ 토픽의 데이터만 엘라스틱 서치에 쓴다.

JDBC 커넥터는 메시지 key를 채우지 않기 때문에 카프카에 저장된 이벤트의 key 값은 null 이 된다.  
key 값이 없으므로 엘라스틱서치에 각 이벤트의 key 값으로 토픽 이름, 파티션 ID, 오프셋을 대신 사용하라고 알려주어야 하는데 `key.ignore` 를 `true` 로 설정하면 이것이 가능하다.

---

### 1.3.5. 엘라스틱서치 인덱스 확인

이제 _mysql.login_ 가 생성된 **인덱스를 확인**해본다.

```shell
$ curl 'localhost:9200/_cat/indices?v'

health status index            uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .geoip_databases z69gSce8Re6q7Iz2Kv_pbw   1   0         36            0     34.1mb         34.1mb
yellow open   mysql.login      6AQVDdQ9SBGrNYhrc9mEpw   1   1          3            0        8kb            8kb
```

이제 레코드가 저장된 **인덱스를 검색**해본다.

```shell
$ curl -s -X "GET" "http://localhost:9200/mysql.login/_search?pretty=true"

{
  "took" : 15,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 3,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "mysql.login",
        "_type" : "_doc",
        "_id" : "mysql.login+0+0",
        "_score" : 1.0,
        "_source" : {
          "username" : "assu",
          "login_time" : 1734856216000
        }
      },
      {
        "_index" : "mysql.login",
        "_type" : "_doc",
        "_id" : "mysql.login+0+2",
        "_score" : 1.0,
        "_source" : {
          "username" : "silby22",
          "login_time" : 1734858706000
        }
      },
      {
        "_index" : "mysql.login",
        "_type" : "_doc",
        "_id" : "mysql.login+0+1",
        "_score" : 1.0,
        "_source" : {
          "username" : "silby",
          "login_time" : 1734856216000
        }
      }
    ]
  }
}
```

이제 MySQL 에 데이터를 추가할 때마다 해당 데이터가 카프카의 _mysql.login_ 토픽과 여기에 대응하는 엘라스틱서치 인덱스에 자동으로 적재된다.

---

## 1.4. SMT(Single Message Transformation, 개별 메시지 변환)

MySQL → 카프카 → 엘라스틱서치로 데이터를 그대로 복사하는 것도 유용하지만, 보통 [ETL](https://assu10.github.io/dev/2024/08/24/kafka-data-pipeline-1/#151-etlextract-transform-load) 파이프라인에는 변환 단계가 포함된다.

카프카에서는 이러한 상태가 없는 stateless 변환을 상태가 있는 스트림 처리와 구분하며, **상태가 없는 변환을 SMT(개별 메시지 변환)** 이라고 한다.

SMT 는 카프카 커넥트가 메시지를 복사하는 도중에 하는 데이터 변환 작업의 일부로서 보통은 코드를 작성할 필요없이 수행된다.  
만일 조인이나 aggregation 을 포함하는 더 복잡한 변환의 경우엔 상태가 있는 카프카 스트림즈 프레임워크를 사용해야 한다.

> 카프카 스트림즈에 대해서는  
> [Kafka - 스트림 처리(1): 스트림 처리 개념, 스트림 처리 디자인 패턴](https://assu10.github.io/dev/2024/09/29/kafka-stream-1/),  
> [Kafka - 스트림 처리(2): 카프카 스트림즈 예시](https://assu10.github.io/dev/2024/10/13/kafka-stream-2/),  
> [Kafka - 스트림 처리(3): 토폴로지, 스트림 처리 프레임워크](https://assu10.github.io/dev/2024/10/19/kafka-stream-3/)  
> 를 참고하세요.

아파치 카프카는 아래와 같은 SMT 들을 포함한다.

- `Cast`
  - 필드의 데이터 타입 변경
- `MaskField`
  - 특정 필드의 내용을 null 로 변경
  - 민감한 정보가 개인 식별 정보 제거 시 유용
- `Filter`
  - 특정한 조건에 부합하는 모든 메시지를 제외하거나 포함함
  - 기본으로 제공되는 조건으로는 토픽 이름 패턴, 특정 헤더, [툼스톤 메시지](https://assu10.github.io/dev/2024/08/11/kafka-mechanism-2/#8-%EC%82%AD%EC%A0%9C%EB%90%9C-%EC%9D%B4%EB%B2%A4%ED%8A%B8-%ED%88%BC%EC%8A%A4%ED%86%A4-%EB%A9%94%EC%8B%9C%EC%A7%80) 여부 판별 가능
- `Flatten`
  - 중첩된 자료 구조를 폄
  - 각 value 값의 경로 안에 있는 모든 필드의 이름을 이어붙인 것이 새로운 key 값이 됨
- `HeaderFrom`
  - 메시지에 포함되어 있는 필드를 헤더로 이동시키거나 복사함
- `InsertHeader`
  - 각 메시지의 헤더에 정적인 문자열 추가
- `InsertField`
  - 메시지에 새로운 필드 추가
  - 오프셋과 같은 메타데이터에서 가져온 값일 수도 있고, 정적인 값일 수도 있음
- `RegexRouter`
  - 정규식과 교체할 문자열을 사용하여 목적지 토픽의 이름 변경
- `ReplaceField`
  - 메시지에 포함된 필드를 삭제하거나 이름을 변경함
- `TimestampConverter`
  - 필드의 시간 형식 변경
  - 예를 들어서 유닉스 시간값을 문자열로 변경
- `TimestampRouter`
  - 메시지에 포함된 타임스탬프 값을 기준으로 토픽 변경
  - 싱크 커넥터에서 특히 유용한데, 타임스탬프 기준으로 지정된 특정 테이블의 파티션에 메시지를 복사해야 할 경우, 토픽 이름만으로 목적지 시스템의 데이터 set 을 찾아야 하기 때문

> 변환 기능은 아래 Git 에도 유용한 정보가 많다.
> 
> [Confluent Hub#transform](https://www.confluent.io/hub/#transform)  
> [Git::kafka-connect-transformers](https://github.com/lensesio/kafka-connect-transformers)  
> [Git:: transforms-for-apache-kafka-connect](https://github.com/Aiven-Open/transforms-for-apache-kafka-connect)  
> [Git:: kafka-connect-transform-common](https://github.com/jcustenborder/kafka-connect-transform-common)

변환 기능을 직접 개발하고 싶다면 [How to Use Single Message Transforms in Kafka Connect](https://www.confluent.io/blog/kafka-connect-single-message-transformation-tutorial-with-examples/) 를 참고하면 된다.

---

### 1.4.1. SMT 이용

예를 들어서 [1.3.2. JDBC 소스 커넥터 설정 및 토픽 확인](#132-jdbc-소스-커넥터-설정-및-토픽-확인) 에서 만든 MySQL 커넥터에서 생성되는 각 레코드에 
[레코드 헤더를 추가](https://www.confluent.io/blog/5-things-every-kafka-developer-should-know/#tip-5-record-headers)한다고 해보자.

이 헤더는 레코드가 이 MySQL 커넥터에 의해 생성되었음을 가리키므로 레코드의 전달 내역을 추적할 때 유용하다.

```shell
$ echo '{
  "name": "mysql-login-connector2",
  "config": {
    "connector.class": "JdbcSourceConnector",
    "connection.url": "jdbc:mysql://localhost:13306/kafka?user=root&password=비밀번호",
    "mode": "timestamp",
    "table.whitelist": "login",
    "validate.non.null": false,
    "timestamp.column.name": "login_time",
    "topic.prefix": "mysql.",
    "name": "mysql-login-connector2",
    "transforms": "InsertHeader",
    "transforms.InsertHeader.type": "org.apache.kafka.connect.transforms.InsertHeader",
    "transforms.InsertHeader.header": "MessageSourceTedt",
    "transforms.InsertHeader.value.literal": "mysql-login-connector"
  }
}' |
curl -X POST -H "Content-Type: application/json" -d @- 'http://localhost:8083/connectors' | jq

{
  "name": "mysql-login-connector2",
  "config": {
    "connector.class": "JdbcSourceConnector",
    "connection.url": "jdbc:mysql://localhost:13306/kafka?user=root&password=비밀번호",
    "mode": "timestamp",
    "table.whitelist": "login",
    "validate.non.null": "false",
    "timestamp.column.name": "login_time",
    "topic.prefix": "mysql.",
    "name": "mysql-login-connector2",
    "transforms": "InsertHeader",
    "transforms.InsertHeader.type": "org.apache.kafka.connect.transforms.InsertHeader",
    "transforms.InsertHeader.header": "MessageSourceTedt",
    "transforms.InsertHeader.value.literal": "mysql-login-connector"
  },
  "tasks": [],
  "type": "source"
}
```

이제 컨슈머가 헤더로 출력하도록 하여 메시지들을 확인해보자.

```shell
kafka_2.13-3.8.0 bin/kafka-console-consumer.sh --bootstrap-server=localhost:9092 \
--topic mysql.login --from-beginning --property print.headers=true
```

```shell
NO_HEADERS	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"assu","login_time":1734856216000}}
NO_HEADERS	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby","login_time":1734856216000}}
NO_HEADERS	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby22","login_time":1734858706000}}
NO_HEADERS	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby33","login_time":1735368498000}}
MessageSourceTedt:mysql-login-connector	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"assu","login_time":1734856216000}}
MessageSourceTedt:mysql-login-connector	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby","login_time":1734856216000}}
MessageSourceTedt:mysql-login-connector	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby22","login_time":1734858706000}}
MessageSourceTedt:mysql-login-connector	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby33","login_time":1735368498000}}
MessageSourceTedt:mysql-login-connector	{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"username"},{"type":"int64","optional":true,"name":"org.apache.kafka.connect.data.Timestamp","version":1,"field":"login_time"}],"optional":false,"name":"login"},"payload":{"username":"silby44","login_time":1735371085000}}
```

오래된 레코드들은 `NO_HEADERS` 가 출력되지만, 새로운 레코드에는 `MessageSourceTedt:mysql-login-connector` 가 출력되는 것을 확인할 수 있다.

---

### 1.4.2. 에러 처리와 데드 레터 큐(Dead Letter Queue): `error.tolerance`

변환 기능은 특정 커넥터에 국한되지 않고 모든 커넥터와 사용할 수 있는 커넥터 설정 중 하나인데, 비슷하게 아무 싱크 커넥터에서나 사용 가능한 설정인 `error.tolerance` 가 있다.

`error.tolerance` 를 사용하면 커넥터가 오염된 메시지를 무시하거나, 데드 레터 큐라고 불리는 토픽으로 보내도록 할 수 있다.

좀 더 자세한 내용은 [Kafka Connect Deep Dive – Error Handling and Dead Letter Queues](https://www.confluent.io/blog/kafka-connect-deep-dive-error-handling-dead-letter-queues/) 에 나와있다.

---

## 1.5. 카프카 커넥트 구성 요소

카프카 커넥트를 사용하려면 워크 클러스터를 실행시킨 뒤 커넥터를 생성하거나 삭제해주어야 한다.

---

### 1.5.1. 커넥터, 태스크(task)

커넥터 플러그인은 커넥터 API 를 구현하고, 이 API 는 커넥터와 태스크를 포함한다.

---

#### 1.5.1.1. 커넥터

커넥터는 3가지 작업을 수행한다.

- 커넥터에서 몇 개의 태스크가 실행되어야 하는지 결정
- 데이터 복사 작업을 각 태스크에 어떻게 분할할지 결정
- 워커로부터 태스크 설정을 얻어와서 태스크에 전달

예를 들어 JDBC 소스 커넥터는 DB 에 연결한 뒤 복사할 테이블들을 찾고 그 결과를 근거로 얼마나 많은 태스크가 필요할 지 결정한다.  
테이블 수와 `tasks.max` 설정값 중 작은 쪽으로 선택한다.

실행시킬 태스크 수를 결정하고 나면 `connection.url` 등과 같은 커넥터 설정과 각 태스크에 복사 작업을 할당해 줄 테이블 목록을 사용하여 전달된 설정을 각 태스크에 생성한다.  
`taskConfigs()` 메서드가 이 설정이 저장된 맵을 리턴한다.

이 때 워커들이 태스크를 실행시키고, 이 태스크들이 DB 의 서로 다른 테이블들을 복사할 수 있도록 각각에 대한 설정을 전달해준다.

---

#### 1.5.1.2. 태스크

**태스크는 데이터를 실제로 카프카에 넣거나 가져오는 작업**을 한다.

모든 태스크는 워커로부터 context 를 받아서 초기화된다.

> 소스 커넥터가 생성하는 태스크를 소스 태스크, 싱크 커넥터가 생성하는 태스크를 싱크 태스크라고 함

**소스 컨텍스트는 소스 태스크가 소스 레코드의 오프셋을 저장할 수 있게 해주는 객체를 포함**한다.  
예) 파일 커넥터의 오프셋은 파일 안에서의 위치, JDBC 소스 커넥터의 오프셋은 테이블의 타임스탬프 열 값

**싱크 커넥터의 컨텍스트에는 커넥터가 카프카로부터 받는 레코드를 제어할 수 있게 해주는 메서드**들이 들어있다.  
이 메서드들은 [백프레셔](https://assu10.github.io/dev/2024/08/24/kafka-data-pipeline-1/#11-%EC%A0%81%EC%8B%9C%EC%84%B1timeliness)를 적용하거나, 
[재시도](https://assu10.github.io/dev/2024/08/17/kafka-reliability/)를 하거나, ['정확히 한 번'](https://assu10.github.io/dev/2024/08/18/kafka-exactly-once/#1-%EB%A9%B1%EB%93%B1%EC%A0%81-%ED%94%84%EB%A1%9C%EB%93%80%EC%84%9Cidempotent-producer) 전달을 위해 오프셋을 외부에 저장할 때 사용된다.

태스크는 초기화된 뒤 커넥터가 생성하여 태스크에게 전달해 준 설정값을 담고 있는 프로퍼티 객체와 함께 시작된다.

태스크가 시작되면 소스 태스크는 외부 시스템을 폴링해서 워커가 카프카 브로커로 보낼 레코드 리스트를 리턴한다.  
싱크 태스크는 워커를 통해 카프카 레코드를 받아서 외부 시스템에 쓰는 작업을 한다.

---

### 1.5.2. 워커(worker)

**워커 프로세스는 커넥터와 태스크를 실행시키는 역할을 맡는 '컨테이너' 프로세스**라고 할 수 있다.

<**워커 프로세스 역할**>  
- 커넥터와 그 설정을 정의하는 HTTP 요청 처리
- 커넥터 설정을 내부 카프카 토픽에 저장
- 커넥터와 태스크를 실행시키고, 여기에 적절한 설정값을 전달
- 워커 프로세스가 정지하거나 크래시가 나면 커넥트 클러스터 안의 다른 워커들이 이를 감지(카프카 컨슈머 프로토콜의 하트비트 사용)하여 해당 워커에서 실행 중이던 커넥터와 태스크를 다른 워커로 재할당
- 새로운 워커가 커넥트 클러스터에 추가되면 다른 워커들이 이를 감지하여 커넥터와 태스크를 할당해줌
- 소스 커넥터와 싱크 커넥터의 오프셋을 내부 카프카 토픽에 자동으로 커밋하는 작업 담당
- 태스크에서 에러가 발생할 경우 재시도하는 작업 담당

**커넥터와 태스크는 데이터 통합에서 '데이터 이동' 단계를 담당하고, 워커는 REST API, 설정 관리, 신뢰성, 고가용성, 규모 확장성, 부하 분산을 담당**한다.

**이런 관심사의 분리가 고전적인 컨슈머/프로듀서 API 와 비교했을 때 커넥트 API 의 주된 이점**이다.

커넥트 형태로 데이터 복사를 구현한 뒤 워커 프로세스를 커넥터에 꽂기만 하면 설정 관리, 에러 처리, REST API, 모니터링, 배포, 규모 확장/축소, 장애 대응과 같은 복잡한 운영상의 
이슈를 워커가 알아서 처리해준다.

---

### 1.5.3. 컨버터, 커넥트 데이터 모델

카프카 커넥트 API 에는 데이터 API 가 포함되어 있다.

**데이터 API 는 데이터 객체와 이 객체의 구조를 나타내는 스키마**를 다룬다.  
예) JDBC 소스 커넥터는 DB 의 열을 읽어온 후 DB 에서 리턴된 열의 데이터 타입에 따라 `ConnectSchema` 객체를 생성함  
그리고 이 스키마를 사용하여 DB 레코드의 모든 필드를 포함하는 `Struct` 객체를 생성하고, 각각의 열에 대해 해당 열의 이름과 저장된 값을 저장함

즉, **소스 커넥터는 원본 시스템의 이벤트를 읽어와서 `Schema`, `Value` 순서쌍을 생성**한다.

싱크 커넥터는 정확히 반대의 작업을 수행한다.  
**`Schema`, `Value` 순서쌍을 받아와서 `Schema` 를 사용하여 해당 값을 파싱하고 대상 시스템에 쓴다.**

---

#### 1.5.3.1. 소스 커넥터에서의 컨버터 역할

소스 커넥터는 데이터 API 를 사용하여 데이터 객체를 생성하는 방법을 알고 있지만, 커넥트 워커는 이 객체들을 카프카에 어떻게 써야하는지 어떻게 아는 걸까?

컨버터가 사용되는 곳이 바로 여기이다.

**워커나 커넥터를 설정할 때 카프카에 데이터 저장 시 사용하고자 하는 컨버터를 설정**해주는 것이다.  
(현재 기본 데이터 타입, 바이트 배열, 문자열, Avro, JSON, 스키마가 있는 JSON, Protobuf 사용 가능)  
JSON 컨버터는 결과 레코드에 스키마를 포함할 지 여부를 선택할 수 있기 때문에 구조화된 데이터와 준 구조화된 데이터 모두 지원 가능하다.

**커넥터가 데이터 API 객체를 워커에 리턴**하면, **워커는 설정된 컨버터를 사용하여 이 레코드를 Avro 객체나 JSON 객체나 문자열로 변환한 뒤 카프카에 쓴다.**

---

#### 1.5.3.2. 싱크 커넥터에서의 컨버터 역할

싱크 커넥터에서는 정확히 반대 방향의 처리 과정을 거친다.

**커넥트 워커는 카프카로부터 레코드를 읽어온 후, 설정된 컨버터를 사용하여 읽어온 레코드를 카프카에 저장된 형식을 커넥트 데이터 API 레코드로 변환**한다.  
카프카에 저장된 형식은 기본 데이터 타입일 수도 있고, 바이트 배열, 문자열, Avro, JSON, 스키마가 있는 JSON, Protobuf 일수도 있다.

이렇게 **변환된 데이터는 싱크 커넥터에 전달되어 대상 시스템에 쓰인다.**

이렇게 **컨버터를 사용함으로써 커넥트 API 는 커넥터 구현과 무관하여 카프카에 서로 다른 형식의 데이터를 저장**할 수 있도록 해준다.  
즉, **사용 가능한 컨버터만 있다면 어떤 커넥터도 레코드 형식에 상관없이 사용 가능**하다.

---

### 1.5.4. 오프셋 관리

**오프셋 관리는 워커 프로세스가 커넥터에 제공하는 기능** 중 하나이다.  
커넥터는 어떤 데이터를 이미 처리했는지 알아야하는데, 이 때 카프카가 제공하는 API 를 사용해서 어느 이벤트가 이미 처리되었는지에 대한 정보를 유지 관리할 수 있다.

---

#### 1.5.4.1. 소스 커넥터에서의 오프셋: `offset.storage.topic`, `config.storage.topic`, `status.storage.topic`

**커넥터가 커넥트 워커에 리턴하는 레코드에는 논리적인 파티션과 오프셋이 포함**되어 있다.  
**이 파티션과 오프셋은 카프카의 파티션과 오프셋이 아닌 원본 시스템의 파티션과 오프셋**이다.  
예) 파일 소스의 경우 파일이 파티션 역할, 파일 안의 줄 혹은 문자 위치가 오프셋 역할  
JDBC 소스의 경우 테이블이 파티션 역할, 테이블 레코드의 ID 나 타임스탬프가 오프셋 역할

소스 커넥터를 개발할 때 가장 중요한 것 중 하나가 원본 시스템의 데이터를 분할하고 오프셋을 추적하는 방법을 결정하는 것이며, 이것은 커넥터의 병렬성 수준과 
'최소 한 번' 혹은 '정확히 한 번' 등의 전달의 의미 구조에 영향을 미친다.

**소스 커넥터가 레코드들을 리턴하면 (각 레코드에는 소스 파티션과 오프셋 포함) 워커는 이 레코드를 카프카 브로커로 보낸다.**

**브로커가 해당 레코드를 성공적으로 쓴 뒤 해당 요청에 대한 응답을 보내면, 워커는 방금 전 카프카로 보낸 레코드에 대한 오프셋을 저장**한다.  
이 때 오프셋은 카프카의 오프셋이 아니라 원본 시스템의 논리적인 오프셋이다.

이렇게 함으로써 커넥터는 재시작, 크래시 발생 후에도 마지막으로 저장되었던 오프셋에서부터 이벤트 처리를 할 수 있다.

이 원본 시스템의 논리적인 오프셋은 보통 카프카 토픽에 저장되며, 토픽 이름은 `offset.storage.topic` 설정을 이용하여 토픽 이름을 변경할 수 있다.

카프카 커넥트는 생성한 모든 커넥터의 설정과 각 커넥터의 현재 상태를 저장할 때도 카프카를 사용하는데 이 토픽 이름들은 각각 `config.storage.topic`, `status.storage.topic` 
으로 설정해 줄 수 있다.

---

#### 1.5.4.2. 싱크 커넥터에서의 오프셋

싱크 터넥터는 소스 커넥터와 비슷한 과정을 반대의 순서로 실행한다.

**토픽, 파티션, 오프셋 식별자가 이미 포함되어 있는 카프카 레코드들을 읽은 후 커넥터의 `put()` 메서드를 호출하여 이 레코드를 대상 시스템에 저장**한다.

**작업이 성공하면 싱크 커넥터는 커넥터에 주어졌던 오프셋을 카프카에 커밋**한다.

카프카 커넥트 프레임워크 단위에서 제공되는 오프셋 추적 기능은 서로 다른 커넥터를 사용할 때도 어느 정도 일관적인 작동을 보장한다.

---

# 2. 카프카 커넥트 대안

커넥트 API 가 제공하는 편의성과 신뢰성도 좋지만, 카프카에 데이터를 넣거나 내보내는 방법이 커넥트만 있는 것은 아니다.

---

## 2.1. 다른 데이터 저장소를 위한 수집 프레임워크

하둡이나 엘라스틱서치와 같은 시스템을 중심으로 대부분의 데이터 아키텍처를 구죽하는 경우가 있을수도 있다.  
하둡과 엘라스틱서치에는 자체적인 데이터 수집 툴이 이미 있다.  
하둡의 경우 flume, 엘라스틱서치는 로그스태시와 Fluentd 가 있다.

카프카가 아키텍처의 핵심 부분이면서 많은 수의 소스와 싱크를 연결하는 것이 목표라면 카프카 커넥트 API 를 사용하는 것이 좋지만, 하둡이나 엘라스틱서치 중심 시스템이면서 
카프카는 그저 해당 시스템의 수많은 입력 중 하나일 분이라면 flume 이나 로그스태시를 사용하는 것이 더 바람직하다.

---

## 2.2. GUI 기반 ETL 툴

인포매티카와 같은 전통적인 시스템이나 Talend, Pentaho, NiFi(아파치 나이파이), StreamSets(스트림세츠)와 같이 상대적으로 새로운 대안들도 모두 아파치 카프카와의 
데이터 교환을 지원한다.

이미 펜타호를 이용하여 모든 것을 다 하고 있다면 카프카 하나만을 위해서 또 다른 데이터 통합 시스템을 추가하는 것은 비효율적이며, GUI 기반으로 [ETL 파이프라인](https://assu10.github.io/dev/2024/08/24/kafka-data-pipeline-1/#151-etlextract-transform-load)을 개발하고 있을 경우에도 합리적인 선택이다.

위 시스템들의 주된 단점은 대개 복잡한 워크플로를 상정하고 개발되었다는 점과 단순히 카프카와의 데이터 교환이 목적일 경우 다소 무겁다는 점이다.

**데이터 통합(커넥트)와 애플리케이션 통합(프로듀서, 컨슈머), 스트림 처리를 함께 다를 수 있는 플랫폼으로 카프카를 사용할 것을 권장**한다.  
카프카는 데이터 저장소만 통합하는 ETL 툴의 성공적인 대안이 될 수 있다.

---

# 정리하며..

이 포스트에서는 데이터 통합을 위해 카프카를 사용하는 것에 대해 알아보았다.  
데이터 통합 시스템의 목적은 메시지를 전달하는 것, 단 하나이다.

[데이터 시스템을 선택할 때는 요구 조건들](https://assu10.github.io/dev/2024/08/24/kafka-data-pipeline-1/#1-%EB%8D%B0%EC%9D%B4%ED%84%B0-%ED%8C%8C%EC%9D%B4%ED%94%84%EB%9D%BC%EC%9D%B8-%EA%B5%AC%EC%B6%95-%EC%8B%9C-%EA%B3%A0%EB%A0%A4%EC%82%AC%ED%95%AD)을 검토한 후 
선택한 시스템이 그 요구 조건들을 만족하는지 확인하는 것이 중요하다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [Blog:: uberJar](https://opennote46.tistory.com/110)
* [Git:: 스키마 레지스트리 프로젝트](https://github.com/confluentinc/schema-registry)
* [Git:: FilePulse 커넥터](https://github.com/streamthoughts/kafka-connect-file-pulse)
* [Git:: FileSystem 커넥터](https://github.com/mmolimar/kafka-connect-fs)
* [Git:: SpoolDir](https://github.com/jcustenborder/kafka-connect-spooldir)
* [Blog:: MacOS에 Elasticsearch 설치하기](https://velog.io/@27cean/MacOS%EC%97%90-Elasticsearch-%EC%84%A4%EC%B9%98%ED%95%98%EA%B8%B0)
* [컨플루언트 허브 웹사이트](https://www.confluent.io/hub/)
* [MySQL JDBC 드라이버](https://dev.mysql.com/downloads/connector/j/)
* [3.5 Kafka Connect Configs](https://kafka.apache.org/documentation/#connectconfigs)
* [디비지움 프로젝트](https://debezium.io/)
* [Confluent Hub#transform](https://www.confluent.io/hub/#transform)
* [Git::kafka-connect-transformers](https://github.com/lensesio/kafka-connect-transformers)  
* [Git:: transforms-for-apache-kafka-connect](https://github.com/Aiven-Open/transforms-for-apache-kafka-connect)  
* [Git:: kafka-connect-transform-common](https://github.com/jcustenborder/kafka-connect-transform-common)
* [How to Use Single Message Transforms in Kafka Connect](https://www.confluent.io/blog/kafka-connect-single-message-transformation-tutorial-with-examples/)
* [Top 5 Things Every Apache Kafka Developer Should Know](https://www.confluent.io/blog/5-things-every-kafka-developer-should-know/)
* [Kafka Connect Deep Dive – Error Handling and Dead Letter Queues](https://www.confluent.io/blog/kafka-connect-deep-dive-error-handling-dead-letter-queues/)