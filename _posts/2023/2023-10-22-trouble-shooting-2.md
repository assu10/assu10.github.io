---
layout: post
title:  "TroubleShooting - Kafka: could not be established. Broker may not be available."
date: 2023-10-22
categories: dev
tags: trouble_shooting
---

# 내용
Kafka 토픽 생성 중 아래와 같은 오류가 발생

```shell
$ kafka_2.13-3.6.1/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --replication-factor 1 --partitions 1 --topic test
[2023-12-16 12:55:20,898] WARN [AdminClient clientId=adminclient-1] Connection to node -1 (localhost/127.0.0.1:9092) could not be established. Broker may not be available. (org.apache.kafka.clients.NetworkClient)
```

---

# 해결책

1) 카프카 폴더 내의 config/server.properties 파일에서 아래 주석처리된 부분을 해제한 후 zookeeper 와 카프카 브로커 재시작 

```shell
$ pwd
/Users/juhyunlee/Developer/kafka/kafka_2.13-3.6.1/config

$ vi server.properties
# The address the socket server listens on. If not configured, the host name will be equal to the value of
# java.net.InetAddress.getCanonicalHostName(), with PLAINTEXT listener name, and port 9092.
#   FORMAT:
#     listeners = listener_name://host_name:port
#   EXAMPLE:
#     listeners = PLAINTEXT://your.host.name:9092
#listeners=PLAINTEXT://:9092

# Listener name, hostname and port the broker will advertise to clients.
# If not set, it uses the value for "listeners".
#advertised.listeners=PLAINTEXT://your.host.name:9092  # 이 부분을 아래와 같이 변경
advertised.listeners=PLAINTEXT://127.0.0.1:9092
```

> `advertised.listeners` 는 카프카 클라이언트나 커맨드 라인 툴을 브로커와 연결할 때 사용됨

zookeeper 재시작
```shell
$ pwd
/Users/juhyunlee/Developer/zookeeper/apache-zookeeper-3.8.3-bin

$ bin/zkServer.sh start
/usr/bin/java
ZooKeeper JMX enabled by default
Using config: /Users/juhyunlee/Developer/zookeeper/apache-zookeeper-3.8.3-bin/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
```

카프카 브로커 재시작
```shell
$ pwd
/Users/juhyunlee/Developer/kafka

$ kafka_2.13-3.6.1/bin/kafka-server-start.sh -daemon \
     kafka_2.13-3.6.1/config/server.properties 
```

2) 토픽 생성

```shell
$ kafka_2.13-3.6.1/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --replication-factor 1 --partitions 1 --topic test
Created topic test.
```