---
layout: post
title:  "Kafka - 카프카 설치"
date: 2023-10-22
categories: dev
tags: kafka zookeeper kafka-brocker kafka-cluster
---

이 포스트에서는 카프카 설치, 설정 및 카프카를 실행하는데 적합한 하드웨어 선택, 프로덕션 작업을 카프카로 옮길 때 고려할 사항들에 대해 알아본다.

- 카프카 브로커 설치
- 브로커의 메타데이터를 저장하기 위해 사용되는 아파치 주키퍼 설치
- 브로커 실행에 적합한 하드웨어 선택 기준
- 여러 개의 카프카 브로커를 클러스터로 구성하는 방법

---

**목차**

<!-- TOC -->
* [1. 환경 설정](#1-환경-설정)
  * [1.2. 주키퍼 설치](#12-주키퍼-설치)
    * [독립 실행 서버](#독립-실행-서버)
    * [주키퍼 앙상블](#주키퍼-앙상블)
* [2. 카프카 브로커 설치](#2-카프카-브로커-설치)
* [3. 카프카 브로커 설정](#3-카프카-브로커-설정)
  * [3.1. 핵심 브로커 매개변수](#31-핵심-브로커-매개변수)
    * [`broker.id`](#brokerid)
    * [`listeners`](#listeners)
    * [`zookeeper.connect`](#zookeeperconnect)
    * [`log.dirs`](#logdirs)
    * [`num.recovery.thread.per.data.dir`](#numrecoverythreadperdatadir)
    * [`auto.create.topics.enable`](#autocreatetopicsenable)
    * [`auto.leader.rebalnace.enable`](#autoleaderrebalnaceenable)
    * [`delete.topic.enable`](#deletetopicenable)
  * [3.2. 토픽별 기본값](#32-토픽별-기본값)
    * [`num.partitions`](#numpartitions)
    * [파티션 개수를 정할 때 고려할 사항](#파티션-개수를-정할-때-고려할-사항)
    * [`default.replication.factor`](#defaultreplicationfactor)
    * [`log.retention.{hours | minutes | ms}`](#logretentionhours--minutes--ms)
    * [`log.retention.bytes`](#logretentionbytes)
    * [크기와 시간을 기준으로 메시지 보존 설정](#크기와-시간을-기준으로-메시지-보존-설정)
    * [`log.segment.bytes`](#logsegmentbytes)
    * [`log.roll.ms`](#logrollms)
    * [`min.insync.replicas`](#mininsyncreplicas)
    * [`message.max.bytes`](#messagemaxbytes)
* [4. 하드웨어 선택](#4-하드웨어-선택)
* [5. 클라우드에서 카프카 사용](#5-클라우드에서-카프카-사용)
  * [MS Azure](#ms-azure)
  * [AWS](#aws)
* [6. 카프카 클러스터 설정](#6-카프카-클러스터-설정)
  * [6.1. 브로커 개수](#61-브로커-개수)
  * [6.2. 브로커 설정](#62-브로커-설정)
* [7. 프로덕션 환경 운영 시 고려사항](#7-프로덕션-환경-운영-시-고려사항)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.9
- zookeeper 3.8.3
- apache kafka: 3.6.1 (스칼라 2.13.0 에서 실행되는 3.6.1 버전)

---

# 1. 환경 설정

주키퍼나 카프카를 설치하기 전에 사용 가능한 자바 환경을 먼저 설치해야 한다.  
여기선 jdk 17 이 설치되어 있다고 가정한다.

---

## 1.2. 주키퍼 설치

아파치 주키퍼는 분산 환경 운영 지원 서비스를 제공하는 코디네이션 엔진으로 카프카 클러스터의 메타데이터와 컨슈머 클라이언트에 대한 정보를 저장하기 위해 사용되며, 설정 정보 관리/이름부여/분산 동기화/그룹 서비스와 같이
사용 빈도가 높은 서비스를 제공하는 중앙화된 서비스이다.

분산 애플리케이션 구현 시 각 분산 노드 설정등의 작업을 중앙 집중식 코디네이션 서비스로 간단한 인터페이스를 제공한다.

<**주키퍼의 주요 특징**>
- **높은 처리량/낮은 대기시간**
    - 주키퍼가 관리하는 데이터는 스토리지가 아닌 메모리에 보관되므로 높은 처리량과 낮은 지연 제공
    - 액세스가 읽기 주체인 경우 특히 고속으로 동작 가능
- **고가용성**
    - 주키퍼를 여러 서버에 설치하여 사용 가능
    - 주키퍼를 여러 개 시작하면 마스터가 자동으로 선택되어 각종 톨괄 관리 실행
    - 마스터 노드가 중지되면 각 노드 간에 선거가 이루어지고, 새로운 마스터 노드가 선택됨
- **노드 간 불일치 제거**
    - 데이터 갱신은 마스터 노드만이 실시하므로 노드 간에 데이터가 일치함

카프카 배포판에 포함된 스크립트를 이용하여 주키퍼 서버를 띄울 수도 있고, 주키퍼 배포판 풀버전을 설치할 수도 있다.

여기선 [주키퍼 3.8.3](https://dlcdn.apache.org/zookeeper/zookeeper-3.8.3/apache-zookeeper-3.8.3-bin.tar.gz) 을 사용한다.

```shell
$ tar -zxvf apache-zookeeper-3.8.3-bin.tar.gz
```

압축이 해제되면 apache-zookeeper-3.8.3-bin 폴더가 생성된다.

---

### 독립 실행 서버

주키퍼는 기본적인 설정 파일을 제공한다.

```shell
$ pwd
/Users/Developer/zookeeper/apache-zookeeper-3.8.3-bin/conf

$ cat zoo_sample.cfg
# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just
# example sakes.
dataDir=/tmp/zookeeper
# the port at which the clients will connect
clientPort=2181
```

> 각 항목의 상세 내용은 [주키퍼 앙상블](#주키퍼-앙상블)에 나옵니다.

주키퍼 시작
```shell
$ pwd
/Users/Developer/zookeeper/apache-zookeeper-3.8.3-bin/conf

$ mv zoo_sample.cfg zoo.cfg

$ pwd
/Users/Developer/zookeeper/apache-zookeeper-3.8.3-bin

$ bin/zkServer.sh start
/usr/bin/java
ZooKeeper JMX enabled by default
Using config: /Users/Developer/zookeeper/apache-zookeeper-3.8.3-bin/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
```

이제 독립 실행 모드 주키퍼가 정상 작동하는지 확인해본다.

클라이언트 포트인 2181 로 접속하여 `srvr` 명령을 실행시켜 본다.
```shell
$ telnet localhost 2181
Trying ::1...
Connected to localhost.
Escape character is '^]'.
srvr
Zookeeper version: 3.8.3-6ad6d364c7c0bcf0de452d54ebefa3058098ab56, built on 2023-10-05 10:34 UTC
Latency min/avg/max: 0/0.0/0
Received: 1
Sent: 0
Connections: 1
Outstanding: 0
Zxid: 0x0
Mode: standalone
Node count: 5
Connection closed by foreign host.
```

주키퍼 정지
```shell
$ pwd
/Users/Developer/zookeeper/apache-zookeeper-3.8.3-bin

$ bin/zkServer.sh stop
/usr/bin/java
ZooKeeper JMX enabled by default
Using config: /Users/Developer/zookeeper/apache-zookeeper-3.8.3-bin/bin/../conf/zoo.cfg
Stopping zookeeper ... STOPPED
```
---

### 주키퍼 앙상블

주키퍼는 고가용성 보장을 위해 앙상블(ensemble) 이라고 불리는 클러스터 단위로 동작하도록 설계되었다.

주키퍼가 사용하는 부하 분산 알고리즘 때문에 앙상블은 홀수 개의 서버를 가지는 것이 권장된다.  
주키퍼가 요청에 응답하려면 앙상블 멤버(쿼럼, Quorum) 의 과반 이상이 작동하고 있어야 하기 때문이다.  
예) 5노드 짜리 앙상블의 경우 2대가 정지하더라도 문제없음

> **주키퍼 앙상블 크기**
>
> 주키퍼 앙상블 구성 시엔 5개 노드로 구성하는 것이 좋다.  
> 앙상블 설정을 변경하려면 한번에 한 대의 노드를 정지시켰다가 설정 변경 후 재시작해야 하는데 만일 앙상블이 2대 이상의 노드 정지를 받아낼 수 없다면  
> 재기동 수행 시 리스크가 있다.  
> 9대 이상의 노드도 권장하지 않는데, 합의 프로토콜 특성상 성능이 저하될 수 있기 때문이다.  
> 클라이언트 연결이 너무 많아서 5대 혹은 7대의 노드가 부하를 감당하지 못하면 옵저버 노드를 추가하여 읽기 전용 트래픽을 분산시킬 수 있다.

주키퍼 서버를 앙상블로 구성할 때 각 서버는 공통된 설정 파일(앙상블에 포함된 모든 서버 목록 포함하는)을 사용해야 하고, 또 각 서버는 데이터 디렉터리에 자신의
ID 번호를 지정하는 myid 파일을 갖고 있어야 한다.

공통 설정 파일 (/conf/zoo.cfg)
```shell
tickTime=2000
initLimit=20
syncLimit=5
dataDir=/tmp/zookeeper
clientPort=2181
server.1=zoo1.example.com:2888:3888
server.2=zoo2.example.com:2888:3888
server.3=zoo3.example.com:2888:3888
```

- `tickTime`
    - ms 단위의 heartbeat 시간 의미
- `initLimit`
    - 팔로워가 리더와 연결할 수 있는 최대 시간 (초기화 제한 시간)
    - 이 시간동안 리더와 연결이 안되면 초기화에 실패
- `syncLimit`
    - 팔로워가 리더와 연결할 수 있는 최대 시간 (동기화 제한 시간)
    - 이 시간동안 리더와 연결이 안되면 동기화가 풀림
- `clientPort`
    - 클라이언트의 커넥션을 listen 하는 포트
- `dataDir`
    - in-memory 데이터베이스 스냅샷을 저장하기 위한 경로
    - 데이터베이스 갱신 시 작성되는 로그가 저장되는 경로

`initLimit`, `syncLimit` 모두 tickTime 단위로 정의되는데 위 설정 파일의 경우 초기화 제한 시간은 `20 * 2,000` ms, 즉, 40초이다.

server.1=zoo1.example.com:2888:3888 는 `server.{x}={hostname}:{peerPort}:{leaderPort}` 이며, 각 의미는 아래와 같다.

- x
    - 서버의 id, 정수값이어야 하지만 순차적으로 부여할 필요는 없음
- hostname
    - 서버의 호스트명 혹은 IP 주소
- peerPort
    - 앙상블 안의 서버들이 서로 통신할 때 사용하는 TCP 포트 번호
- leaderPort
    - 리더 선출 시 사용하는 TCP 포트 번호

클라이언트는 설정 파일(zoo.cgf) 내의 `clientPort` 로 앙상블에 연결할 수만 있으면 되지만, 앙상블 멤버들은 3 포트를 사용하여 모두 통신할 수 있어야 한다.

공통 설정 파일 외에 각 서버는 dataDir 디렉터리 안에 `myid` 라는 파일을 가지고 있어야 하며, 이 파일은 공통 설정 파일에 지정된 것과 일치하는 서버 ID 번호를 포함해야 한다.

---

# 2. 카프카 브로커 설치

java 와 주키퍼 설정이 끝나면 카프카를 설치할 수 있다.

여기선 3.6.1 버전을 설치한다. 카프카는 [여기](https://kafka.apache.org/downloads.html)에서 source 타입이 아닌 binary 타입으로 다운로드 받는다.

```shell
$ tar -zxf kafka_2.13-3.6.1.tgz

$ pwd
/Users/Developer/kafka

# 메시지 로그 세그먼트는 kafka-logs 에 저장
$ mkdir /tmp/kafka-logs

# 카프카 브로커 시작
$ kafka_2.13-3.6.1/bin/kafka-server-start.sh -daemon \
     kafka_2.13-3.6.1/config/server.properties
```

카프카 브로커가 시작되었으면, 클러스터에 토픽 생성, 메시지 쓰기/읽기 등의 명령어를 실행시켜서 동작을 확인한다.

토픽 생성
```shell
$ pwd
/Users/Developer/kafka/kafka_2.13-3.6.1

$ bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --replication-factor 1 --partitions 1 --topic test
Created topic test.
```

> `WARN [AdminClient clientId=adminclient-1] Connection to node -1 (localhost/127.0.0.1:9092) could not be established. Broker may not be available. (org.apache.kafka.clients.NetworkClient)` 이런
> 오류가 발생한다면 [Kafka - could not be established. Broker may not be available.](https://assu10.github.io/dev/2023/10/22/trouble-shooting-2/) 를 참고하세요.

토픽 조회
```shell
$ pwd
/Users/Developer/kafka/kafka_2.13-3.6.1

$ bin/kafka-topics.sh --list --bootstrap-server localhost:9092 
test

$ bin/kafka-topics.sh --bootstrap-server localhost:9092 \
--describe --topic test
Topic: test	TopicId: HKyuorStS1-11a4D38Vvug	PartitionCount: 1	ReplicationFactor: 1	Configs:
	Topic: test	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
```

토픽에 메시지 쓰기
```shell
$ pwd
/Users/Developer/kafka/kafka_2.13-3.6.1

$ bin/kafka-console-producer.sh --bootstrap-server localhost:9092 \
  localhost:9092 --topic test
>Test Message 01
>Test Message 02
>^C%
```

토픽에서 메시지 읽기
```shell
$ pwd
/Users/Developer/kafka/kafka_2.13-3.6.1

$ bin/kafka-console-consumer.sh --bootstrap-server \
localhost:9092 --topic test --from-beginning
Test Message 01
Test Message 02
^CProcessed a total of 2 messages
```

토픽 삭제
```shell
$ pwd
/Users/Developer/kafka/kafka_2.13-3.6.1

$ bin/kafka-topics.sh --delete --topic test --bootstrap-server localhost:9092
```

> 카프카 CLI 유틸리티에서 주키퍼 연결 시 `--bootstrap-server` 를 사용하여 카프카 브로커에 연결

---

# 3. 카프카 브로커 설정

> kafka_2.13-3.6.1/config/server.properties 에 아래 설정 옵션값들이 있음

> apache kafka 3.3.0 부터 추가된 Kafka 모드 설정에 대해서는 추후 다룰 예정입니다.

## 3.1. 핵심 브로커 매개변수

브로커 설정 매개변수들 중 대부분은 다른 브로커들과 함께 클러스터 모드로 작동하려면 기본값이 아닌 다른 값으로 변경해주어야 한다.

### `broker.id`

> 디폴트는 0

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# The id of the broker. This must be set to a unique integer for each broker.
broker.id=0
```

모든 카프카 브로커는 정수값의 식별자를 갖는데, 이 정수값은 클러스터 안의 각 브로커별로 모두 달라야 한다.  
운영 시 브로커 ID 에 해당하는 호스트명을 찾는 것도 부담이기 때문에 호스트별로 고정된 값을 사용하는 것이 좋다.  
예) 호스트명에 고유한 번호가 포함(host1.test.com)되어 있다면 broker.id 를 1로 할당

---

### `listeners`

> 디폴트는 PLAINTEXT://:9092

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# The address the socket server listens on. If not configured, the host name will be equal to the value of
# java.net.InetAddress.getCanonicalHostName(), with PLAINTEXT listener name, and port 9092.
#   FORMAT:
#     listeners = listener_name://host_name:port
#   EXAMPLE:
#     listeners = PLAINTEXT://your.host.name:9092
#listeners=PLAINTEXT://:9092

# Listener name, hostname and port the broker will advertise to clients.
# If not set, it uses the value for "listeners".
advertised.listeners=PLAINTEXT://127.0.0.1:9092

# Maps listener names to security protocols, the default is for them to be the same. See the config documentation for more details
#listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL

# The number of threads that the server uses for receiving requests from the network and sending responses to the network
num.network.threads=3
```

`listeners` 설정은 쉼표로 구분된 리스터 이름과 URI 목록이다.  
리스너명이 일반적인 보안 프로토콜이 아니라면 반드시 `listener.security.protocol.map` 설정을 잡아주어야 한다.

리스너는 `{protocol}://{hostname}:{port}` 의 형태이다.  
예) PLAINTEXT://localhost:9092,SSL://:9091

호스트명을 0.0.0.0 으로 잡아주면 모든 네트워크 인터페이스로부터 연결을 받게 되고, 이 값을 비워주면 기본 인터페이스에 대해서만 연결을 받는다.

1024 미만의 포트 번호 사용 시 루트 권한으로 카프카를 실행시켜야 하므로 바람직하지 않다.

---

### `zookeeper.connect`

> 디폴트는 localhost:2181

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# Zookeeper connection string (see zookeeper docs for details).
# This is a comma separated host:port pairs, each corresponding to a zk
# server. e.g. "127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002".
# You can also append an optional chroot string to the urls to specify the
# root directory for all kafka znodes.
zookeeper.connect=localhost:2181
```

브로커의 메타데이터가 저장되는 주키퍼의 위치로 로컬호스트의 2181 포트에서 작동 중인 주키퍼 사용 시 localhost:2181 로 설정하면 된다.  
세미콜론으로 연결된 {hostname}:{port}/{path} 의 목록 형식으로 지정할 수도 있다.

- hostname: 주키퍼 서버의 호스트명이나 IP
- port: 주키퍼 클라이언트 포트
- path: 선택 사항으로 카프카 칼러스터의 chroot 환경으로 사용될 주키퍼의 경로, 지정하지 않으면 루트 디렉터리가 사용됨

> **`chroot` 경로를 사용하는 이유**
>
> 다른 카프카 클러스터를 포함한 다른 애플리케이션과 충돌할 일 없이 주키퍼 앙상블을 공유해서 사용할 수 있도록 카프카 클러스터에는 chroot 경로는 사용하는 것이 좋다.
>
> 또한, 특정 서버에 장애가 생기더라도 카프카 브로커가 같은 주키퍼 앙상블의 다른 서버에 연결할 수 있도록 같은 앙상블에 속하는 다수의 주키퍼 서버를 지정하는 것이 좋다.

---

### `log.dirs`

> 디폴트는 /tmp/kafka-logs

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# A comma separated list of directories under which to store log files
log.dirs=/tmp/kafka-logs
```

카프카는 모든 메시지를 로그 세그먼트 단위로 묶어서 `log.dir` 설정에 지정된 디렉터리에 저장한다.  
여러 개의 디렉터리를 지정할 경우 `log.dirs` 을 사용하며, `log.dirs` 가 설정되어 있지 않으면 `log.dir` 이 사용된다.

1개 이상의 디렉터리가 지정된 경우 브로커는 가장 적은 수의 파티션이 저장된 디렉터리에 새 파티션을 저장한다. (= 같은 파티션에 속하는 로그 세그먼트는 동일한 경로에 저장됨)

사용된 디스크 용량 기준이 아니라 저장된 파티션 수 기준으로 새 파티션의 저장 위치를 배정하기 때문에 여러 개의 디렉터리에 대해 균등한 양의 데이터가 저장되지는 않는다.

---

### `num.recovery.thread.per.data.dir`

> 디폴트는 1

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# The number of threads per data directory to be used for log recovery at startup and flushing at shutdown.
# This value is recommended to be increased for installations with data dirs located in RAID array.
num.recovery.threads.per.data.dir=1
```

카프카는 설정 가능한 스레드 풀을 사용하여 로그 세그먼트를 관리하는데 이 스레드 풀은 아래와 같은 작업을 한다.

- 브로커가 정상적으로 시작되었을 때, 각 파티션의 로그 세그먼트 파일을 엶
- 브로커가 장애 발생 후 재시작되었을 때, 각 파티션의 로그 세그먼트를 검사 후 잘못된 부분 삭제
- 브로커가 종료될 때, 로그 세그먼트를 정상적으로 닫음

기본적으로 하나의 로그 디렉터리에 대해 하나의 스레드만 사용된다.

이 스레드들은 브로커가 시작/종료될 때만 사용되기 때문에 작업 병렬화를 위해서 많은 스레드를 할당해주는 것이 좋다.  
특히 브로커에 많은 파티션이 저장되어 있을 경우, 이 설정에 따라 언클린 셧다운 이후 복구를 위한 재시작 시간 차이가 크게 날 수도 있다.

> **언클린 셧다운**
>
> 서버가 정상적으로 종료되지 않아 프로세스를 잡고 있는 경우

이 설정값은 `log.dirs` 에 지정된 로그 디렉터리별 스레드 수이다.  
예를 들어 `num.recovery.thread.per.data.dir` 이 8이고, `log.dirs` 에 지정된 디렉터리 수가 2이면 8*2=16 로, 전체 스레드 개수는 16개이다.

---

### `auto.create.topics.enable`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

카프카 기본 설정에서는 아래와 같은 상황에서 브로커가 토픽을 자동 생성하도록 되어있다.

- 프로듀서가 토픽에 메시지를 쓰기 시작할 때
- 컨슈머가 토픽으로부터 메시지를 읽기 시작할 때
- 클라이언트가 토픽에 대한 메타데이터를 요청할 때

하지만 카프카에 토픽을 생성하지 않고 존재 여부만 확인할 방법이 없다는 점에서 `auto.create.topics.enable` 를 true 로 설정하는 것은 바람직하지 않다.

토픽 생성을 명시적으로 관리하려면 `auto.create.topics.enable` 를 false 로 설정한다.

---

### `auto.leader.rebalnace.enable`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

모든 토픽의 리더 역할이 하나의 브로커에 집중되면 카프카 클러스터의 균형이 깨질 수 있으므로 `auto.leader.rebalnace.enable` 설정을 활성화해주는 것이 좋다.  
`auto.leader.rebalnace.enable` 설정을 활성화해주면 가능한 한 리더 역할이 균등하게 분산된다.

해당 설정을 활성화하면 파티션의 분포 상태를 주기적으로 확인하는 백그라운드 스레드가 시작되는데, 이 주기는 `leader.imbalance.check.interval.seconds` 로 설정 가능하다.

전체 파티션 중 특정 브로커에 리더 역할이 할당된 파티션의 비율이 `leader.imbalnace.per.broker.percentage` 에 설정된 값을 넘어가면 파티션의 선호 리더(preferred leader) 리밸런싱이 발생한다.

> 파티션의 preferred leader 의 좀 더 상세한 내용은 추후 다룰 예정입니다.

---

### `delete.topic.enable`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

데이터 보존 문제로 클러스터의 토픽을 임의로 삭제하지 못하게끔 할 때 해당 설정값은 false 로 해주면 토픽 삭제 기능이 막힌다.

---

## 3.2. 토픽별 기본값

> kafka_2.13-3.6.1/config/server.properties 에 아래 설정 옵션값들이 있음

카프카 브로커 설정 중 새로 생성되는 토픽에 적용되는 기본값도 있다.

이 설정값들 중 일부 (파티션 수, 메시지 보존 등) 는 관리용 툴을 사용하여 토픽 단위로 설정이 가능하다.

> 관리용 툴의 좀 더 상세한 내용은 추후 다룰 예정입니다.

> **토픽 단위 지정의 설정값 재정의**
>
> 카프카 구버전에서는 `log.retention.{hours | bytes}.per.topic`, `log.segment.bytes.per.topic` 과 같은 매개변수를 사용하여 토픽별로 설정 가능했지만,
> 이제 더 이상 지원되지 않으며, 토픽별 설정값을 재정의하려면 관리툴을 이용해야 함

---

### `num.partitions`

> 디폴트는 1

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# The default number of log partitions per topic. More partitions allow greater
# parallelism for consumption, but this will also result in more files across
# the brokers.
num.partitions=1
```

`num.partitions` 는 새로운 토픽이 생성될 때 몇 개의 파티션을 갖게 되는지 결정하며, 주로 `auto.create.topics.enable` (자동 토픽 생성 기능) 이 활성화(디폴트)되어 있을 때 사용된다.

토픽의 파티션 개수는 늘릴수는 있지만 줄일 수는 없다.  
즉, 만약 토픽이 `num.partitions` 에 지정된 것보다 더 적은 수의 파티션을 가져야한다면 직접 토픽을 생성해야 한다.

> 위 내용의 좀 더 상세한 내용은 추후 다룰 예정입니다.

파티션은 카프카 클러스터 안에서 토픽의 크기가 확장되는 방법이기도 하므로 브로커가 추가될 때 클러스터 전체에 걸쳐 메시지 부하가 고르게 분산되도록 파티션 개수를 잡아주어야 한다.

> [1.3. 토픽, 파티션](https://assu10.github.io/dev/2023/10/21/kafka-basic/#13-%ED%86%A0%ED%94%BD-%ED%8C%8C%ED%8B%B0%EC%85%98) 참고

대부분 토픽 당 파티션 개수를 클러스터 내의 브로커의 수와 맞추거나, 배수로 설정한다.  
그러면 파티션이 브로커들 사이에 고르게 분산되도록 하여 메시지 부하 역시 고르게 분산된다.  
예) 10개의 파티션으로 이루어진 토픽이 10개의 호스트로 구성된 카프카 클러스터에서 작동중이고, 각 파티션의 리더 역시 이 10개의 호스트에 고르게 분산되어 있다면 최적의 처리량이 나옴

파티션이 너무 많아도 성능에 이슈가 발생할 수 있다.

> 아래 [파티션 개수를 정할 때 고려할 사항](#파티션-개수를-정할-때-고려할-사항) 과 함께 보시면 도움이 됩니다.

토픽의 목표 처리량과 컨슈머의 예상 처리량에 대해 추정값이 있다면 `토픽의 목표 처리량 / 컨슈머의 예상 처리량` 으로 필요 파티션 수를 계산할 수 있다.  
예) 주어진 토픽에 초당 1GB 를 읽거나 쓰고자 하는데 컨슈머 하나는 초당 50MB 만 처리가 가능하다면 최소한 1GB / 50MB = 20, 즉, 20개의 파티션 필요  
이렇게 하면 20개의 컨슈머가 동시에 하나의 토픽을 읽음으로써 초딩 1GB 를 읽을 수 있음

만일 이러한 정보가 없다면 매일 디스크 안에 저장되어 있는 파티션의 용량을 6GB 으로 유지하는 것을 권장한다.  
작은 크기로 시작하여 나중에 필요 시 확장하는 것이 좋다.

---

### 파티션 개수를 정할 때 고려할 사항

- **토픽의 목표 처리량**
    - 예) 쓰기 속도가 초당 100KB 인지, 1GB 인지?
- **단일 파티션에 대해 달성하고자 하는 최대 읽기 처리량**
    - 하나의 파티션은 항상 하나의 컨슈머만 읽을 수 있음 (컨슈머 그룹 기능을 사용하지 않더라도 컨슈머는 해당 파티션의 모든 메시지를 읽음)
    - 만일 컨슈머 애플리케이션이 DB 에 데이터를 쓰는데 이 DB 의 쓰기 스레드 각각이 초당 50MB 이상 처리할 수 없다면 하나의 파티션에서 읽어올 수 있는 속도는 초당 50MB 로 제한됨
- **각 프로듀서가 단일 파티션에 쓸 수 있는 최대 속도**
    - 위의 단일 파티션에 대해 달성하고자 하는 최대 읽기 처리량 과 비슷한 추정을 할 수 있지만 보통 프로듀서는 컨슈머에 비해 훨씬 더 빠르므로 생략해도 좋음

만일 키 값을 기준으로 선택된 파티션에 메시지를 전송하는 경우 나중에 파티션 추가 시 복잡하므로, 현재의 사용량이 아닌 미래의 사용량 예측값을 기준으로 처리량을 계산하는 것이 좋다.

- **각 브로커에 배치한 파티션 개수뿐 아니라 브로커별로 사용 가능한 디스크 공간, 네트워크 대역폭도 고려**
- **과대 예측은 피할 것**
    - 각 파티션은 브로커의 메모리와 다른 자원들도 사용하고, 메타데이터 업데이트나 리더 역할 변경에 걸리는 시간 역시 증가시킴
- **데이터 미러링 여부**
    - 데이터 미러링을 사용한다면 미러링 설정의 처리량도 고려해야 함
    - 미러링 구성에서 큰 파티션이 병목이 되는 경우가 많음
- **클라우드 서비스 사용 시 가상 머신이나 디스크에 초당 입출력(IOPS, Input/Output Per Second) 제한이 걸려있는지 확인**
    - 사용중인 클라우드 서비스나 가상 머진 설정에 따라 허용되는 IOPS 설정이 있을 수 있음
    - 파티션 수가 너무 많으면 병렬 처리 때문에 IOPS 양이 증가할 수 있음


---

### `default.replication.factor`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

`auto.create.topics.enable` (자동 토픽 생성 기능) 이 활성화되어 있는 경우 이 설정은 새로 생성되는 토픽의 복제 팩터를 결정한다.

아래는 하드웨어 장애와 같은 카프카 외부 요인으로 인한 장애를 견디기 위한 권장 사항이다.

- 복제 팩터값은 [`min.insync.replicas`](#mininsyncreplicas) 설정값보다 최소한 1 이상 크게 잡아줄 것
    - 보다 더 안전한 설정을 위해서는 `min.insync.replicas` 설정값보다 2 정도 큰 값으로 복제 팩터를 설정하는 것이 좋음 (이것을 보통 `RF++` 라고 줄여씀)
    - 이유는 replica set 안에 일부러 정지시킨 레플리카와 예상치 않게 정지된 레플리카가 동시에 하나씩 발생해도 장애가 발생하지 않기 때문임
    - 즉, 일반적인 클러스터의 경우 파티션 별로 최소한 3개의 레플리카를 가져야한다는 의미

> 복제 팩터에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다.

---

### `log.retention.{hours | minutes | ms}`

> 디폴트는 log.retention.hours=168

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# The minimum age of a log file to be eligible for deletion due to age
log.retention.hours=168  #7일
```

카프카 메시지 보존 기간을 지정할 때 사용되며, 메시지가 만료되어 삭제되기 까지 걸리는 시간을 지정한다. (=시간 기준 보존 설정에 의해 닫힌 세그먼트가 보존되는 기한)

hours, minutes, ms 모두 동일한 역할이지만 1개 이상의 설정이 정의되어 있을 경우 더 작은 단위의 설정값이 우선권을 가지므로 ms 를 사용하는 것을 권장한다.

이렇게 시간 기준 보존은 디스크게 저장된 각 로그 세그먼트 파일의 마지막 수정 시각을 기준으로 동작한다.  
정상적으로 작동 중이라는 가정 하에 이 값은 해당 로그 세그먼트가 닫힌 시각이며, 해당 파일에 저장된 마지막 메시지의 타임스탬프이기도 하다.  
하지만, 관리툴을 사용하여 브로커 간에 파티션을 이동시켰을 경우 이 값은 정확하지 않으며 해당 파티션이 지나치게 오래 보존될 수도 있다.

> 위 내용의 좀 더 상세한 내용은 추후 다룰 예정입니다.

---

### `log.retention.bytes`

> 디폴트는 1073741824 (주석 처리)

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# A size-based retention policy for logs. Segments are pruned from the log unless the remaining
# segments drop below log.retention.bytes. Functions independently of log.retention.hours.
#log.retention.bytes=1073741824  #1048576BK, 1024MB, 1GB
```

메시지 만료의 또 다른 기준인 보존되는 메시지 용량으로, 파티션 단위로 적용된다.

만일 8개의 파티션을 가진 토픽에 `log.retention.bytes` 가 1GB 로 설정되어 있으면 이 토픽의 최대 저장 용량은 8GB 이다.

**모든 보존 기능은 토픽 단위가 아닌 파티션 단위로 동작**한다.

따라서 `log.retention.bytes` 설정을 사용중인 상태에서 토픽의 파티션 수를 증가시키면 보존되는 데이터 양도 함께 늘어난다.  
만일 -1 로 설정한다면 데이터가 영구 보존된다.

---

### 크기와 시간을 기준으로 메시지 보존 설정

`log.retention.bytes` 설정과 `log.retention.ms` 설정을 동시에 한다면 두 조건 중 하나만 성립해도 메시지가 삭제된다.  
따라서 의도치않은 데이터 유실을 방지하기 위해 크기 기준 설정/시간 기준 설정 중 하나만 설정하는 것이 좋다.

---

### `log.segment.bytes`

> 디폴트는 1073741824 (주석 처리)

kafka_2.13-3.6.1/config/server.properties 기본 설정
```properties
# The maximum size of a log segment file. When this size is reached a new log segment will be created.
#log.segment.bytes=1073741824  #1048576BK, 1024MB, 1GB
```

로그 보존 설정은 메시지 각각이 아닌 로그 세그먼트에 적용된다.

카프카 브로커에 쓰여진 메시지는 해당 파티션의 현재 로그 세그먼트 끝에 추가되는데, 로그 세그먼트의 크기가 `log.segment.bytes` 설정값에 다다르면 브로커는 기존 로그 세그먼트를 닫고
새로운 로그 세그먼트는 연다.

**로그 세그먼트는 닫히기 전까지는 만료와 삭제의 대상이 되지 않는다.** (= 작은 로그 세그먼트의 크기는 파일을 더 자주 닫고 새로 할당하게 되므로 디스크 쓰기의 효율성 감소)

**토픽에 메시지가 뜸하게 주어지는 경우 로그 세그먼트의 크기가 중요**하다.  
예를 들어 토픽에 들어오는 메시지가 하루에 100MB 이고, `log.segment.bytes` 가 기본값인 1GB 로 설정되어 있다면 하나의 로그 세그먼트를 채울 때까지 총 10 일이 소요된다.  
로그 세그먼트가 닫히기 전까지 메시지는 만료되지 않으므로 `log.retention.ms` 가 604800000 (7일) 로 설정되어 있는 경우에 로그 세그먼트가 닫히는 데 10일,
시간 기준 보존 설정에 의해 닫힌 세그먼트가 보존되는 기한이 7일이므로 닫힌 로그 세그먼트가 만료될 때까지 실제로는 최대 17일치의 메시지가 저장될 수 있다.

---

### `log.roll.ms`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

`log.segnemt.bytes` 외에 로그 세그먼트 파일이 닫히는 시점을 제어하는 방법으로 파일이 닫혀야 할 때까지 기다리는 시간을 지정한다.

`log.retention.bytes` 와 `log.retention.ms` 처럼 `log.segment.bytes` 와 `log.roll.ms` 도 상호 배타적인 속성이 아니다.  

카프카는 크기 or 시간 제한 중 하나라도 도달하면 로그 세그먼트를 닫는다.


시간 제한은 브로커가 시작되는 시점부터 계산되기 때문에 크기가 작은 파티션을 닫는 작업들이 한꺼번에 이루어지기 때문에 시간 기준 로그 세그먼트를 제한을 사용할 경우 
여러 개의 로그 세그먼트가 동시에 닫힐 때의 디스크 성능에 대해 고려해야 한다.  

---

### `min.insync.replicas`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

데이터 지속성 위주로 클러스터 설정 시 `min.insync.replicas` 를 2로 잡아주면 최소 2개의 레플리카가 최신 상태로 프로듀서와 동기화되도록 할 수 있다.  
이것은 프로듀서의 ack 설정을 `all` 로 잡아주는 것과 함께 사용된다.  

이렇게 하면 최소 2 개의 레플리카(= 리더 1, 팔로워 중 1) 가 응답해야만 프로듀서의 쓰기 작업이 성공하므로 아래와 같은 상황에서 데이터 유실을 방지할 수 있다.

리더가 쓰기 작업에 응답 → 리더에 장애 발생 → 리더 역할이 최근에 성공한 쓰기 작업 내역을 복제하기 전의 다른 레플리카로 옮겨짐

**만일 이러한 설정이 되어 있지 않다면 프로듀서는 쓰기 작업이 성공했다고 판단하지만 실제로는 메시지가 유실되는 상황이 발생할 수 있다.**  

지속성을 높이기 위해 `min.insync.replicas` 를 크게 잡으면 추가적인 오버헤드가 발생하여 성능이 떨어지므로, 어느 정도의 메시지 유실은 상관없고 높은 처리량을 
요구하는 클러스터의 경우 이 설정값을 기본값인 1 로 유지하는 것을 권장한다.

> 위 내용의 좀 더 상세한 내용은 추후 다룰 예정입니다.

---

### `message.max.bytes`

> kafka_2.13-3.6.1/config/server.properties 기본 설정에 없음

카프카 브로커는 쓸 수 있는 메시지의 최대 크기를 제한하는데 기본값은 1,000,000(1MB) 이다.  

프로듀서가 이 값보다 더 큰 크기의 메시지를 보내려고 시도하면 브로커는 메시지를 거부하고 에러를 리턴한다.

브로커에 설정된 모든 byte 크기와 마찬가지로, `message.max.bytes` 역시 압축된 메시지의 크기를 기준으로 한다.  
즉, 압축 전 기준으로 이 값보다 훨씬 큰 메시지라도 압축된 결과물이 `message.max.bytes` 보다 작으면 된다.

메시지가 커지는 만큼 네트워크 연결과 요청을 처리하는 브로커 스레드의 요청당 작업 시간도 증가하고, 디스크에 써야하는 크기 또한 증가하므로 I/O 처리량에 영향을 미친다.

<**메시지의 크기 설정 조정**>    
카프카 브로커에 설정되는 메시지 크기는 컨슈머 클라이언트의 `fetch.message.max.bytes` 설정과 맞아야 한다.  
만일 컨슈머 클라이언트의 `fetch.message.max.bytes` 값이 브로커의 `message.max.bytes` 값보다 작으면 컨슈머는 `fetch.message.max.bytes` 에 지정된 것보다 
더 큰 메시지를 읽는데 실패하면서 읽기 작업 진행이 멈출 수 있다.  
이 내용은 클러스터 브로커의 `replica.fetch.max.bytes` 설정에도 똑같이 적용된다.

---

# 4. 하드웨어 선택

카프카 브로커의 성능을 고려하여 하드웨어 선택 시 디스크 처리량, 디스크 용량, 메모리, 네트워크, CPU 를 고려해야 한다.  
카프카를 매우 크게 확장할 경우 업데이트되어야 하는 메타데이터의 양 때문에 하나의 브로커가 처리할 수 있는 파티션의 수에도 제한이 생길 수 있다.

- **디스크 처리량**
  - 로그 세그먼트를 저장하는 브로커 디스크의 처리량은 프로듀서 클라이언트의 성능에 가장 큰 영향을 미침
  - 카프카에 메시지를 쓸 때 메시지는 브로커의 로컬 저장소에 커밋되어야 하고, 대부분의 프로듀서 클라이언트는 메시지 전송이 성공했다고 결론을 내리기 전에 
  최소 1개 이상의 브로커가 메시지 커밋 완료 응답을 보낼 때까지 대기함 (= 디스크 쓰기 속도가 빨라진다는 것은 쓰기 지연이 줄어든다는 것)
  - 대체로 많은 수의 클라이언트 연결을 받아내야 하는 경우에는 SSD 가 권장되고, 자주 쓸 일이 없는 데이터를 많이 저장해야 하는 클러스터의 경우 HDD 드라이브를 권장함
- **디스크 용량**
  - 필요한 디스크 용량은 특정한 시점에 얼마나 많은 메시지들이 보존되어야 하는지에 따라 결정됨
  - 예) 브로커가 하루에 1TB 의 트래픽을 받을 것으로 예상되고, 받은 메시지를 7일동안 보존해야 한다면, 브로커는 로그 세그먼트를 저장하기 위한 저장 공간이 최소 7TB 필요함  
  여기에 트래픽 증가 대비 공간, 저장해야 할 다른 파일도 감안하여 최소 10% 이상의 오버 헤드를 고려해야 함
  - 클러스터에 들어오는 전체 트래픽은 토픽별로 다수의 파티션을 잡아줌으로써 클러스터 전체에 균형있게 분산되므로, 단일 브로커의 용량이 충분하지 않은 경우 브로커를 추가하여 전체 용량 증대 가능
  - > 필요한 디스크 용량은 클러스터에 설정된 복제 방식에 따라서도 달라질 수 있는데 이에 대한 내용은 추후 다룰 예정입니다.
- **메모리**
  - 시스템에 페이지 캐시에 저장되어 있는 메시지들을 컨슈머 클라이언트가 읽어오게 함으로써 성능을 향상시킬 수 있음
  - 카프카를 하나의 시스템에서 다른 애플리케이션과 함께 운영하는 것을 권장하지 않는 주된 이유
    - 시스템 메모리의 남는 영역을 페이지 캐시로 사용하여 시스템이 사용중인 로그 세그먼트를 캐시하도록 함으로써 카프카 성능 향상이 가능한데 다른 애플리케이션과 함께 사용할 경우 
    페이지 캐시를 나눠서 쓰게 되고, 이것은 카프카의 컨슈머 성능을 저하시킴
- **네트워크**
  - 사용 가능한 네트워크 대역폭은 카프카가 처리할 수 있는 트래픽의 최대량을 결정함
- **CPU**
  - 카프카 클러스터를 매우 크게 확장하지 않는 한, 처리 능력은 디스크/메모리만큼 중요하지는 않음 (하지만 브로커의 전체적인 성능에는 어느 정도 영향을 미침)
  - 네트워크와 디스크 사용량 최적화를 위해 클아이언트가 메시지를 압축해서 보내고, 카프카 브로커는 각 메시지의 체크섬 확인 및 오프셋 부여를 위해 모든 메시지 배치의 압축을 해제해야 함
  - 이 작업이 끝난 후 디스크에 저장하기 위해 메시지를 다시 압축하는데 이 때 카프카의 처리 능력이 중요해짐

---

# 5. 클라우드에서 카프카 사용

## MS Azure

Azure 는 디스크를 가상 머진과 분리해서 관리 가능하다. (= 저장 장치 선택 시 사용할 VM 을 고려할 필요없음)  
따라서 장비 스펙를 고를 때 필요한 데이터 양을 먼저 고려한 후 프로듀서에 필요한 성능을 다음으로 고려하는 것이 좋다.

만일 지연이 매우 낮아야 한다면 프리미엄 SSD 가 장착된 I/O 최적화 인스턴스가 필요하고, 그게 아니면 `Azure Managed Disks` 나 `Azure Blob Storage (애저 개체 저장소)` 와 같은 
매니지드 저장소 서비스로도 충분하다.

Standard DI6s v3 인스턴스가 작은 클러스터용으로 알맞고, 좀 더 고성능 하드웨어와 CPU 가 필요하면 D64s v4 인스턴스가 클러스터 크기 확장 시 더 좋은 성능을 보여준다.

임시 디스크에 데이터를 쓰다가 가상 머신이 다른 곳으로 이동할 경우 브로커의 모든 데이터가 유실될 수 있으므로 임시 디스크보다는 애저 매니지드 디스크를 사용하는 것이 좋다.

---

## AWS

지연이 매우 낮아야 한다면 로컬 SSD 가 장착된 I/O 최적화 인스턴스가 필요하고, 그게 아니라면 아마존 EBS (Elastic Block Store) 와 같은 임시 저장소로도 충분하다.

AWS 에서 일반적으로 사용되는 인스턴스 유형은 `m4`, `r3` 이다.  
`m4` 는 보존 기한은 더 늘려잡을 수 있지만 EBS 를 쓰는 만큼 디스크 처리량이 줄어든다.  
`r3` 은 로컬 SSD 드라이브를 쓰는 만큼 처리량은 좋지만, 보존 가능한 데이터 양에 제한이 걸린다.  

둘 다 커버하고 싶으면 `i2`, `d2` 인스턴스 유형을 사용하면 된다. (대신 비쌈)

---

# 6. 카프카 클러스터 설정

개발용이나 PoC 용으로는 단일 카프카 브로커도 잘 동작하지만, 여러 대의 브로커를 하나의 클러스터로 구성하면 아래와 같은 이점이 있다.

![카프카 클러스터](/assets/img/dev/2023/1022/cluster.png)

- 부하 분산
- 복제를 사용함으로써 시스템 장애 발생 시 데이터 유실 방지
- 클라이언트 요청을 처리하면서 카프카 클러스터나 시스템의 유지 관리 작업 수행 가능

## 6.1. 브로커 개수

카프카 클러스터 크기 결정 시 아래와 같은 요소를 고려해야 한다.

- 디스크 용량
- 브로커 당 레플리카 용량
- CPU 용량
- 네트워크 용량

---

### 디스크 용량

필요한 메시지를 저장하는데 필요한 디스크 용량과 단일 브로커가 사용할 수 있는 저장소 용량을 생각해보자.

만일, 클러스터에 10TB 의 데이터를 저장하고 있어야 하고, 하나의 브로커가 저장할 수 있는 용량이 2TB 라면 클러스터의 최소 크기는 브로커 5대이다.    
만일 복제 팩터를 증가시킨다면 필요한 저장 용량이 최소 100% 이상 증가한다. 
> 이 부분은 추후 좀 더 상세히 다룰 예정입니다.

이 경우 레플리카는 하나의 파티션이 복제되는 서로 다른 브로커의 수를 의미한다.  
바로 위의 예시처럼 최소 5대의 브로커가 필요한 상황에서 복제 팩터를 2로 설정하면 최소 10대의 브로커가 필요하다.

---

### 브로커 당 레플리카 용량

10개의 브로커를 가진 카프카 클러스터가 있는데 레플리카의 수는 백만 개 (= 복제 팩터가 2인 파티션이 50만개) 가 넘는다면 각 브로커는 대략 10만 개의 레플리카를 보유하게 된다.  
이것은 쓰기, 읽기, 컨트롤러 큐 전체에 걸쳐 병목 현상을 발생시킬 수 있다.

파티션 레플리카 개수는 브로커 당 14,000 개, 클러스터 당 100만개 이하로 유지할 것은 권장한다.

---

### CPU 용량

하나의 브로커에 많은 수의 클라이언트 연결이나 요청이 쏟아지는 경우를 제외하고는 CPU 는 대개 주요 병목 지점이 되지 않는다.

---

### 네트워크 용량

네트워크 용량은 아래의 내용은 고려하면 좋다.

- 네트워크 인터페이스의 전체 용량은?
- 컨슈머가 여럿이거나, 데이터가 보존되는 동안 트래픽이 일정하지 않을때도 클라이언트 트래픽을 받아낼 수 있는지?
  - 예) 피크 시간 대에 단일 브로커에 대해 네트워크 인터페이스 전체 용량의 80% 가 사용되는데 이 데이터를 읽어가는 컨슈머가 2대라면, 2대 이상의 브로커가 있지 않는 한 컨슈머는 처리량을 제대로 받아낼 수 없음
  - 만일 클러스터에 복제 기능을 설정되어 있다면 이 또한 추가로 고려해야 할 데이터 컨슈머가 됨
  - 디스크 처리량이나 시스템 메모리가 부족하여 발생하는 성능 문제는 클러스터에 브로커를 추가하여 확장해주어야 함

---

## 6.2. 브로커 설정

여러 개의 카프카 브로커를 하나의 클러스터로 구성할 때는 아래 2가지를 설정해주면 된다.

- 모든 브로커들이 동일한 `zookeeper.connect` 설정값을 가져야 함 (클러스터가 메타데이터를 저장하는 주키퍼 앙상블과 경로 지정)
- 클러스터 안의 모든 브로커가 유일한 `brocker.id` 를 가져야 함
  - 만일 동일한 `brocker.id` 를 가지는 2개의 브로커가 같은 클러스터에 들어오려고 하면 늦게 들어온 쪽에 에러가 났다는 로그가 찍히면서 실행 실패함

---

# 7. 프로덕션 환경 운영 시 고려사항

> 별도로 다루지 않음..

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [주키퍼 릴리즈 노트](https://zookeeper.apache.org/releases.html)
* [주키퍼 설명 블로그](https://www.devkuma.com/docs/apache-zookeeper/)
* [주키퍼 도커 설치](https://www.devkuma.com/docs/apache-zookeeper/docker-install/)
* [주키퍼 Java API](https://www.devkuma.com/docs/apache-zookeeper/java-api/)
* [카프카 다운로드](https://kafka.apache.org/downloads.html)
* [로컬 PC에 카프카 클러스터 설치 및 실행 블로그: 토픽 생성/쓰기/읽기/삭제](https://yooloo.tistory.com/68)
* [Kafka retention 옵션 - log 보관 주기 설정](https://deep-dive-dev.tistory.com/63)