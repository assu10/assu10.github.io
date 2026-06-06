---
layout: post
title:  "이 블로그의 MSA 에 사용된 인스턴스 포트 정보 및 서비스 시작법"
date: 2021-01-30 10:00
categories: dev
tags: msa centralized-log sleuth open-zipkin
---

이 글은 본 블로그의 MSA 카테고리 중 2020-08-16(Spring Cloud - Spring Cloud Config Server) ~ ? 동안 사용된
인스턴스의 포트 정보 및 인스턴스 기동 전 미리 기동시켜야 하는 작업들을 정리해놓은 포스트입니다.

(제가 헷갈려서 정리해놓은 글..)

<!-- TOC -->
  * [1. 인스턴스 포트 정리](#1-인스턴스-포트-정리)
  * [2. 사전 기동 서비스들](#2-사전-기동-서비스들)
  * [3. 로그 서비스들](#3-로그-서비스들)
<!-- TOC -->

---

## 1. 인스턴스 포트 정리

|       마이크로서비스명       | 사용 포트      |
|:--------------------:|:-----------|
|        Eureka        | 8762, 8763 |
|         Zuul         | 5555       |
|    Config Server     | 8889       |
|  Event MicroService  | 8070, 8071 |
| Member MicroService  | 8090, 8091 |
|         Auth         | 8901       |

---

## 2. 사전 기동 서비스들

Kafka 는 Zookeeper 를 사용하기 때문에 주키퍼부터 실행한 후 Kafka 를 실행한다.<br />
(윈도우 환경이라면 C:\myhome\03_Study\kafka_2.13-2.6.0\logs 의 log 먼저 모두 삭제)

```shell
--  주키퍼 실행
C:\myhome\03_Study\kafka_2.13-2.6.0\bin\windows> .\zookeeper-server-start.bat ..\..\config\zookeeper.properties

-- Spring Cloud Stream Kafka 실행
C:\myhome\03_Study\kafka_2.13-2.6.0\bin\windows> .\kafka-server-start.bat ..\..\config\server.properties

-- Spring Cloud Stream Kafka 토픽 리스트 조회
C:\kafka_2.13-2.6.0\bin\windows>.\kafka-topics.bat --list --zookeeper localhost:2181
__consumer_offsets
mbChangeTopic
springCloudBus
```

---

## 3. 로그 서비스들

logstash, elasticsearch, kibana 를 각각 기동한다.

(ElasticSearch 는 관리자 모드로 실행)
```shell
C:\Program Files\Elastic\Elasticsearch\7.10.1> ./bin/elasticsearch
C:\myhome\03_Study\13_SpringCloud\kibana-7.10.1-windows-x86_64> ./bin/kibana.bat
C:\myhome\03_Study\13_SpringCloud\logstash-7.10.2> ./bin/logstash -f ./config/logstash.conf
```
[http://localhost:9200/](http://localhost:9200/) 로 ElasticSearch 가 실행되었는지 확인한다.<br />
[http://localhost:5601/](http://localhost:5601/) 로 Kibana 콘솔 화면에 접속하여 확인한다.

Zipkin 실행

```shell
C:\myhome\03_Study\13_SpringCloud> java -jar .\zipkin-server-2.23.2-exec.jar
```

[http://localhost:9411](http://localhost:9411) 에 접속하면 집킨 서버의 첫 화면을 볼 수 있다.

---

