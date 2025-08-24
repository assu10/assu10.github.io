---
layout: post
title:  "Kafka - 운영(1): 토픽 작업, 컨슈머 그룹 작업, 동적 설정 변경"
date: 2024-09-21
categories: dev
tags: kafka
---

이 포스트에서는 카프카 클러스터 운영 시 필요한 툴들에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 토픽 작업: `kafka-topics.sh`](#1-토픽-작업-kafka-topicssh)
  * [1.1. 토픽 생성: `--create`](#11-토픽-생성---create)
  * [1.2. 토픽 목록 조회: `--list`](#12-토픽-목록-조회---list)
  * [1.3. 토픽 상세 내역 조회: `--describe`](#13-토픽-상세-내역-조회---describe)
  * [1.4. 파티션 추가: `--alter`](#14-파티션-추가---alter)
  * [1.5. 파티션 개수 줄이기](#15-파티션-개수-줄이기)
  * [1.6. 토픽 삭제: `--delete`](#16-토픽-삭제---delete)
* [2. 컨슈머 그룹: `kafka-consumer-groups.sh`](#2-컨슈머-그룹-kafka-consumer-groupssh)
  * [2.1. 컨슈머 그룹 목록 및 상세 내역 조회: `--list`, `--describe --group`](#21-컨슈머-그룹-목록-및-상세-내역-조회---list---describe---group)
  * [2.2. 컨슈머 그룹 삭제: `--delete --group`](#22-컨슈머-그룹-삭제---delete---group)
  * [2.3. 오프셋 관리: `--reset-offsets`](#23-오프셋-관리---reset-offsets)
    * [2.3.1. 오프셋 내보내기: `--dry-run`](#231-오프셋-내보내기---dry-run)
    * [2.3.2. 오프셋 가져오기](#232-오프셋-가져오기)
* [3. 동적 설정 변경: `kafka-configs.sh`](#3-동적-설정-변경-kafka-configssh)
  * [3.1. 토픽 설정 기본값 재정의: `--add-config`](#31-토픽-설정-기본값-재정의---add-config)
  * [3.2. 클라이언트와 사용자 설정 기본값 재정의](#32-클라이언트와-사용자-설정-기본값-재정의)
  * [3.3. 브로커 설정 기본값 재정의](#33-브로커-설정-기본값-재정의)
  * [3.4. 재정의된 설정 상세 조회: `--descibe`](#34-재정의된-설정-상세-조회---descibe)
  * [3.5. 재정의된 설정 삭제: `--delete-config`](#35-재정의된-설정-삭제---delete-config)
* [4. 쓰기 작업과 읽기 작업](#4-쓰기-작업과-읽기-작업)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 토픽 작업: `kafka-topics.sh`

`kafka-topics.sh` 는 클러스터 내의 토픽 생성/변경/삭제/정보 조회 등 대부분의 토픽 작업이 가능하다.  
토픽 설정은 지원이 중단되었으므로 `kafka-configs.sh` 를 사용하는 것을 권장한다.

`kafka-topics.sh` 를 사용할 때는 `--bootstrap-server` 옵션에 연결 문자열과 포트를 넣어주어야 한다.

> [2. 카프카 브로커 설치](https://assu10.github.io/dev/2024/06/15/kafka-install/#2-%EC%B9%B4%ED%94%84%EC%B9%B4-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%EC%84%A4%EC%B9%98) 와 함께 보면 도움이 됩니다.

---

## 1.1. 토픽 생성: `--create`

`--create` 명령을 사용할 때 필요한 3개의 필수 인수는 아래와 같다.
- **`--topic`**
  - 토픽명
- **`--replication-factor`**
  - 클러스터 안에 유지되어야 할 레플리카의 개수
- **`--partitions`**
  - 토픽에서 생성할 파티션 개수

<**토픽명 주의점**>
- `.` 은 사용하지 않는다.
  - 카프카 내부적으로 사용하는 지표에서는 `.` 를 `_` 로 변환해서 처리하므로 토픽명에 충돌이 발생할 수 있음
  - 예) _topic.a_ 가 지표 이름으로 사용될 때 _topic_a_ 로 변환됨
- `__` prefix 를 사용하지 않는다.
  - 카프카 내부에서 사용되는 토픽 생성 시 `__` 로 시작하는 이름을 쓰는 것이 관례임
  - 예) 컨슈머 그룹 오프셋을 저장하는 `__consumer_offsets` 토픽

주키퍼 및 브로커 시작
```shell
# 주키퍼 시작
$ pwd
/Users/Developer/zookeeper/apache-zookeeper-3.9.2-bin/bin

$ ./zKServer.sh start
/usr/bin/java
ZooKeeper JMX enabled by default
Using config: /Users/zookeeper/apache-zookeeper-3.9.2-bin/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED

# 브로커 시작
$ pwd
/Users/Developer/kafka/kafka_2.13-3.8.0

$ ./bin/kafka-server-start.sh -daemon \
./config/server.properties
```

토픽 생성

```shell
$ bin/kafka-topics.sh --bootstrap-server <connection-string>:<port> \
--create --topic <string> --replication-factor <integer> --partitions <integer>
```

각 파티션에 대해서 클러스터는 지정된 수만큼의 레플리카를 적절히 선정하는데 즉, 클러스터에 rack 인식 레플리카 할당 설정이 되어있을 경우 각 파티션의 레플리카는 
서로 다른 rack 에 위치하게 된다는 의미이다.  
만일 rack 인식 할당 기능이 필요없다면 `--disable-rack-aware` 를 지정하면 된다.

아래는 파티션 각각이 2개의 레플리카를 가지는 8개의 파티션으로 이루어진 _my-topic_ 이라는 토픽을 생성하는 예시이다.
```shell
$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 \
--create --topic my-topic --replication-factor 2 --partitions 8

Created topic my-topic.
```

- **`--if-not-exists`**
  - 토픽 생성 시 같은 이름의 토픽이 있어도 에러를 리턴하지 않음
- **`--if-exists`**
  - `--if-exists` 는 `--alter` 명령과 함께 사용하지 않는 것을 권장함
  - `--if-exist` 를 사용하면 변경되는 토픽이 존재하지 않아도 에러가 리턴되지 않기 때문에 생성되어야 할 토픽이 존재하지 않아도 알아차릴 수가 없음

---

## 1.2. 토픽 목록 조회: `--list`

`--list` 명령은 클러스터 안의 모든 토픽을 보여주며, 이 때 특정한 순서는 없다.

토픽 리스트 조회
```shell
$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
my-topic-2
my-topic
```

---

## 1.3. 토픽 상세 내역 조회: `--describe`

클러스터 안에 있는 1개 이상의 토픽에 대한 상세 정보를 조회하며, 파티션 수/재정의된 토픽 설정/파티션 별 레플리카 할당도 출력된다.  
하나의 토픽에 대해서만 보고 싶다면 `--topic` 인수를 지정하면 된다.

```shell
$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 \
> --describe --topic my-topic

Topic: my-topic	TopicId: Yb_Vm6AgRzG6aLr2ntIh5g	PartitionCount: 1	ReplicationFactor: 1	Configs:
	Topic: my-topic	Partition: 0	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
```

`--describe` 명령은 클러스터에 발생한 문제를 찾을 때 도움이 될 수 있도록 출력을 필터링할 수 있는 옵션을 제공한다.  
단, 이 옵션들은 클러스터 내에서 어떠한 기준에 부합하는 모든 토픽이나 파티션을 찾는 것이 목적이므로 보통 `--topic` 인수를 지정하지 않는다.  
또한 이 옵션들은 `--list` 명령과 함께 사용할 수 없다.

- **`--topics-with-overrides`**
  - 클러스터 기본값을 재정의한 것이 있는 토픽들 조회
- **`--exclude-internal`**
  - `__` prefix 로 시작하는(=내부 토픽 앞에 붙는) 모든 토픽들을 결과에서 제외함

<**문제가 발생했을 수 있는 토픽 타피션을 찾을 때 유용한 옵션**>
- **`--under-replicated-partitions`**
  - 1개 이상의 레플리카가 리더와 동기화되고 있지 않은 모든 파티션 조회
- **`--at-min-isr-partitions`**
  - 리더를 포함한 레플리카 수가 ISR(In-Sync Replica) 최소값과 같은 모든 파티션 조회
  - 이 토픽들은 프로듀서나 컨슈머 클라이언트가 여전히 사용은 할 수 있지만 중복 저장된 게 없기 때문에 작동 불능에 빠질 위험이 있음
- **`--under-min-isr-partitions`**
  - ISR 수가 쓰기 작업에 성공하기 위해 필요한 최소 레플리카 수에 미달하는 모든 파티션 조회
  - 이 파티션들은 사실상 읽기 전용 모드이고, 쓰기 작업은 불가능함
- **`--unavailable-partitions`**
  - 리더가 없는 모든 파티션 조회
  - 매우 심각한 상황이며, 파티션이 오프라인 상태이고 프로듀서나 컨슈머 클라이언트가 사용 불가능하다는 것을 의미함

---

## 1.4. 파티션 추가: `--alter`

운영을 하다보면 파티션의 수를 증가시켜야 할 경우가 있다.  
파티션은 클러스터 안에서 토픽이 확장되고 복제되는 수단이기도 하다.  
**파티션 수를 증가시키는 가장 일반적인 이유**는 **단일 파티션에 들어오는 처리량을 줄임으로써 토픽을 더 많은 브로커에 대해 수평 확장**하기 위함이다.  
**하나의 파티션은 컨슈머 그룹 내의 하나의 컨슈머만 읽을 수 있기 때문에 컨슈머 그룹 안에서 더 많은 컨슈머를 활용해야 하는 경우에도 토픽의 파티션 수를 증가**시킨다.

파티션 수를 16개로 증가시킨 뒤 정상적으로 증가되었는지 확인

```shell
$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 \
> --alter --topic my-topic --partitions 16

$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 \
> --describe --topic my-topic
Topic: my-topic	TopicId: Yb_Vm6AgRzG6aLr2ntIh5g	PartitionCount: 16	ReplicationFactor: 1	Configs:
	Topic: my-topic	Partition: 0	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 1	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 2	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 3	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 4	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 5	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 6	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 7	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 8	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 9	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 10	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 11	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 12	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 13	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 14	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
	Topic: my-topic	Partition: 15	Leader: 0	Replicas: 0	Isr: 0	Elr: N/A	LastKnownElr: N/A
```

파티션 수가 변하면 key 값에 대응하는 파티션도 달라지기 때문에 컨슈머 입장에서 key 가 있는 메시지를 갖는 토픽에 파티션을 추가하는 것은 매우 어렵다.  
따라서 key 가 포함된 메시지를 저장하는 토픽을 생성할 때는 미리 파티션의 개수를 정해놓고, 일단 생성한 뒤에는 파티션의 수를 바꾸지 않는 것이 좋다.

---

## 1.5. 파티션 개수 줄이기

파티션을 삭제한다는 것은 곧 토픽에 저장된 데이터를 삭제한다는 의미이므로 토픽의 파티션 개수를 줄일 수는 없다.  
만일 파티션의 수를 줄여야 한다면 토픽을 삭제하고 다시 만들거나, 토픽 삭제가 불가능하다면 새로운 버전의 토픽을 생성한 후 모든 쓰기 트래픽을 새로운 토픽으로 몰아주는 것을 권장한다.

---

## 1.6. 토픽 삭제: `--delete`

메시지가 하나도 없는 토픽이라도 디스크 공간이나 메모리와 같은 클러스터 자원을 소비하고, [컨트롤러](https://assu10.github.io/dev/2024/07/13/kafka-mechanism-1/#2-%EC%BB%A8%ED%8A%B8%EB%A1%A4%EB%9F%AC) 역시 
아무 의미없는 메타데이터에 대한 정보를 보유하고 있어야 한다.  
이는 대규모 클러스터에서는 성능 하락으로 이어진다.

토픽을 삭제하기 위해서는 클러스터 브로커의 `delete.topic.enable` 옵션이 활성화되어 있어야 한다.

토픽 삭제는 비동기적이다.  
명령을 실행하면 토픽이 삭제될 것이라고 표시만 되고, 실제 삭제 작업이 바로 진행되지는 않는다.  
삭제해야 하는 데이터와 정리해야 하는 자원의 양에 따라 삭제 시기가 정해진다.

컨트롤러가 현재 돌아가고 있는 컨트롤러 작업이 완료되는대로 브로커에 아직 계류 중인 삭제 작업에 대해 통지하면, 브로커는 해당 토픽에 대한 메타데이터를 무효화한 뒤 관련 파일을 
디스크에서 지운다.  
컨트롤러가 삭제 작업을 처리하는 방식의 한계 때문에 토픽을 삭제할 때는 한번에 하나의 토픽만 삭제하고, 삭제 작업 사이에 충분한 시간을 둘 것을 권장한다.

토픽 삭제

```shell
$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 \
> --delete --topic my-topic

$ ./bin/kafka-topics.sh --bootstrap-server localhost:9092 \
--list
my-topic-2
```

위에 보면 토픽 삭제의 성공 여부를 알려주는 명시적인 메시지가 없다.  
삭제의 성공 여부를 알려면 `--list` 혹은  `--describe` 옵션을 사용해서 클러스터 내에 토픽이 더 이상 존재하지 않는지 확인하면 된다.

---

# 2. 컨슈머 그룹: `kafka-consumer-groups.sh`

[컨슈머 그룹](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#1-%EC%B9%B4%ED%94%84%EC%B9%B4-%EC%BB%A8%EC%8A%88%EB%A8%B8)은 
여러 개의 토픽 혹은 하나의 토픽에 속한 여러 파티션에서 데이터를 읽어오는 카프카 컨슈머의 집달이다.

`kafka-consumer-groups.sh` 툴을 이용하여 클러스터에서 토픽을 읽고 있는 컨슈머 그룹을 관리할 수 있다.  
`kafka-consumer-groups.sh` 는 컨슈머 그룹 목록 조회, 특정 그룹의 상세 내역 조회, 컨슈머 그룹 삭제, 컨슈머 그룹 오프셋 정보 초기화 기능을 제공한다.

---

## 2.1. 컨슈머 그룹 목록 및 상세 내역 조회: `--list`, `--describe --group`

컨슈머 그룹 목록 조회는 `--list` 매개변수를 이용하면 된다.  
목록은 _console-consumer-{생성된 ID}_ 의 형태로 보인다.

컨슈머 그룹 목록 조회

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
> --list
```

특정 그룹의 상세 정보는 `--describe --group` 매개변수를 이용하면 된다.  
이러면 컨슈머 그룹이 읽어오고 있는 모든 토픽과 파티션 목록, 각 토픽 파티션에서의 오프셋과 같은 추가 정보를 조회할 수 있다.

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
> --describe --group my-consumer

GROUP       TOPIC    PARTITION CURRENT-OFFSET LOG-END-OFFSET LAG CONSUMER-ID              HOST      CLIENT-ID
my-consumer my-topic 0         2              4              2   consumer-1-043ukjfldjfkd 127.0.0.1 consumer-1
my-consumer my-topic 1         2              2              1   consumer-1-043ukjfldjfkd 127.0.0.1 consumer-1
my-consumer my-topic 2         2              2              1   consumer-1-fdsafdsafd343 127.0.0.1 consumer-2
```

위에서 각 필드는 아래를 의미한다.

| 필드             | 설명                                                        |
|:---------------|:----------------------------------------------------------|
| GROUP          | 컨슈머 그룹명                                                   |
| TOPIC          | 읽고 있는 토픽명                                                 |
| PARTITION      | 읽고 있는 파티션 ID                                              |
| CURRENT-OFFSET | 컨슈머 그룹이 이 파티션에서 다음번에 읽어올 메시지의 오프셋<br >이 파티션에서의 컨슈머 위치임    |
| LOG-END-OFFSET | 브로커 토픽 파티션의 하이 워터마크 오프셋 현재값<br />이 파티션에 쓰여질 다음번 메시지의 오프셋임 |
| LAG            | 컨슈머의 CURRENT-OFF 과 브로커의 LOG-END-OFFSET 간의 차이              |
| CONSUMER-ID    | 설정된 client-id 값을 기준으로 생성된 고유한 consumer-id                 |
| HOST           | 컨슈머 그룹이 읽고 있는 호스트의 IP                                     |
| CLIENT-ID      | 컨슈머 그룹에 속한 클라이언트를 식별하기 위해 클라이언트에 설정된 문자열                  |

---

## 2.2. 컨슈머 그룹 삭제: `--delete --group`

`--delete` 는 그룹이 읽고 있는 모든 토픽에 대해 저장된 모든 오프셋을 포함한 전체 그룹을 삭제한다.  
`--delete` 를 수행하려면 컨슈머 그룹 내의 모든 컨슈머들이 내려간 상태, 즉 컨슈머 그룹에 활동 중인 멤버가 하나도 없어야 한다.  
만일 비어있지 않은 그룹을 삭제하려고 하면 _The group is not empty_ 에러가 발생하면서 아무 작업도 수행되지 않는다.

`--topic` 매개변수에 삭제하려는 토픽의 이름을 지정하여 컨슈머 그룹 전체를 삭제하는 대신 컨슈머 그룹이 읽어오고 있는 특정 토픽에 대한 오프셋만 삭제하는 것도 가능하다.

컨슈머 그룹 삭제

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--delete --group my-consumer
```

---

## 2.3. 오프셋 관리: `--reset-offsets`

저장된 오프셋을 가져오거나 새로운 오프셋을 저장할 수도 있다.  
이 기능은 문제가 있어서 메시지를 다시 읽어와야 하거나, 문제가 있는 메시지를 건너뛰기 위해 컨슈머의 오프셋을 리셋하는 경우에 유용하다.

---

### 2.3.1. 오프셋 내보내기: `--dry-run`

컨슈머 그룹을 csv 파일로 내보내려면 `--dry-run` 옵션과 함께 `--reset-offsets` 매개변수를 사용하면 된다.  
이러면 나중에 오프셋을 가져오거나 롤백하기 위해 사용할 수 있는 파일 형태로 현재 오프셋을 내보낼 수 있다.

`--dry-run` 옵션없이 같은 명령을 실행하면 오프셋이 완전히 리셋되므로 주의해야 한다.

CSV 파일의 형식은 _{토픽 이름},{파티션 번호},{오프셋}_ 이다.

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--export --group my-consumer --topic my-topic \
--reset-offsets --to-current --dry-run > offsets.csv

$ cat offsets.csv
my-topic,0,1105
my-topic,1,1115
my-topic,2,1135
```

---

### 2.3.2. 오프셋 가져오기

오프셋 내보내기 작업에서 생성된 파일을 가져와서 컨슈머 그룹의 현재 오프셋을 설정할 수 있다.  
이 기능은 보통 현재 컨슈머 그룹의 오프셋을 내보낸 뒤 백업을 하기 위한 복사본을 하나 만들어놓고, 오프셋을 원하는 값으로 바꿔서 사용하는 식으로 진행한다.

오프셋 가져오기를 하기 전에 컨슈머 그룹에 속한 모든 컨슈머를 중단시켜야 한다.  
컨슈머 그룹이 현재 돌아가고 있는 상태에서 새로운 오프셋을 넣어준다고 해서 컨슈머가 새로운 오프셋 값을 읽어오지는 않는다. 이 경우 컨슈머는 그냥 새 오프셋들을 덮어써버린다.

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--reset-offsets --group my-consumer \
--from-file offsets.csv --execute

TOPIC PARTITION NEW-OFFSET
my-topic 0 1105
my-topic 1 1115
my-topic 2 1135
```

---

# 3. 동적 설정 변경: `kafka-configs.sh`

클러스터를 끄거나 재설치할 필요 없이 돌아가는 와중에 동적으로 변경할 수 있는 설정들은 보통 `kafka-configs.sh` 이용한다.

현재 동적으로 변경이 가능한 설정의 범주(=`entity-type`) 은 토픽, 브로커, 사용자, 클라이언트 총 4가지가 있다.  
동적으로 재정의가 가능한 설정은 카프카 새 버전이 나올 때마다 조금씩 늘어나기 때문에 사용중인 카프카와 같은 버전의 툴을 사용하는 것이 좋다.

설정 작업을 자동화하기 위해 관리하고자 하는 설정을 미리 형식에 담아놓은 파일과 `--add-config-file` 인자를 사용할 수도 있다.

---

## 3.1. 토픽 설정 기본값 재정의: `--add-config`

대부분의 설정값은 브로커 설정 파일에 정의된 값이 토픽에 대한 기본값이 된다.  
동적 설정 기능을 사용하면 하나의 클러스터에서 서로 다른 활용 사례에 맞추기 위한 각 토픽의 클러스터 단위의 기본값을 재정의할 수 있다.  
설정을 삭제하면 토픽은 해당 설정의 기본값을 사용하게 된다.

> 동적으로 설정 가능한 토픽 키는 그때그때 검색해서 볼 것

토픽 설정을 변경하기 위한 명령 형식

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--alter --entity-type topics --entity-name {토픽 이름} \
--add-config {key}={value}[,{key}={value}...]
```

my-topic 의 보존 기한을 3,600,000ms(= 1시간) 으로 변경하는 예시

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--alter --entity-type topics --entity-name my-topic \
--add-config retention.ms=3600000

Updated config for topic: "my-topic"
```

---

## 3.2. 클라이언트와 사용자 설정 기본값 재정의

카프카 클라이언트와 사용자의 경우 재정의 가능한 설정은 쿼터에 관련된 몇 개밖에 없다.

<**사용자와 클라이언트 양쪽에 대해 변경 가능한 설정 목록**>

| 설정 키                      | 내용                                                                                              |
|:--------------------------|:------------------------------------------------------------------------------------------------|
| consumer_bytes_rate       | 하나의 클라이언트 ID 가 하나의 브로커에서 초당 읽어올 수 있는 메시지의 양                                                     |
| producer_bytes_rate       | 하나의 클라이언트 ID 가 하나의 브로커에 초당 쓸 수 있는 메시지의 양                                                        |
| controller_mutations_rate | 컨트롤러의 변경률<br />즉, 사용 가능한 토픽 생성, 파티션 생성, 토픽 삭제 요청의 양<br />생성되거나 삭제된 파티션 수 단위로 집계                 |
| request_percentage        | 사용자 혹은 클라이언트로부터의 요청에 대한 쿼터 윈도우 비율<br >(num.io.threads + num.network.threads) * 100% 에 대한 비율로 집계 |

**스로틀링은 브로커 단위로 이루어지기 때문에 클러스터 안에서 [파티션 리더](https://assu10.github.io/dev/2024/06/10/kafka-basic/#25-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%ED%81%B4%EB%9F%AC%EC%8A%A4%ED%84%B0-%EC%BB%A8%ED%8A%B8%EB%A1%A4%EB%9F%AC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%8D%94-%ED%8C%94%EB%A1%9C%EC%9B%8C) 역할이 균등하게 분포되는 것은 매우 중요**하다.  
만일 브로커 5대로 이루어진 클러스터에 프로듀서별 쿼터가 10Mbps 로 설정된 경우, 프로듀서가 각 브로커에 10Mbps 의 속도로 쓸 수 있으므로 파티션 리더 역할이 5대의 브로커에 
균등하게 나누어져 있을 경우 전체적으로는 50Mbps 속도로 쓰기가 가능하지만, 모두 1번 브로커에 몰려있으면 최대 쓰기 속도는 10Mbps 가 된다.

클라이언트 ID 는 굳이 컨슈머 이름과 같을 필요가 없다.  
컨슈머별로 클라이언트 ID 를 따로 줄 수 있기 때문에 서로 다른 컨슈머 그룹에 속한 컨슈머들이 같은 클라이언트 ID 를 가질 수도 있다.  
이 때 각 컨슈머 그룹의 클라이언트 ID 를 컨슈머 그룹을 식별할 수 있는 값으로 잡아주게 되면 하나의 컨슈머 그룹에 속한 컨슈머들이 쿼터를 공유할 수 있을 뿐더러, 로그에서 특정한 
요청을 보낸 컨슈머 그룹이 어디인지 쉽게 찾을 수 있다.

사용자별, 클라이언트별 컨트롤러 변경률 설정을 한 번에 변경하는 예시

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--alter --add-config "controller_mutations_rate=10" \
--entity-type clients --entity-name {Client-ID} \
--entity-type users --entity-name {User-ID}
```

---

## 3.3. 브로커 설정 기본값 재정의

브로커와 클러스터 수준의 설정은 주로 클러스터 설정 파일에 정적으로 지정되지만, 프로세스가 돌아가는 중에 재정의 가능한 설정들도 많다.

`--help` 명령이나 [Doc:: Broker Configs](https://kafka.apache.org/documentation/#brokerconfigs) 에서 전체 항목을 볼 수 있다.  
그 중 중요한 3가지만 보면 아래와 같다.

- [`min.insync.replicas`](https://assu10.github.io/dev/2024/06/15/kafka-install/#329-mininsyncreplicas)
  - 프로듀서의 acks 설정값이 all 혹은 -1 로 설정되어 있을 때 쓰기 요청에 응답이 가기 전에 쓰기가 이루어져야 하는 레플리카 수의 최소값
- [`unclean.leader.election.enable`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#32-%EC%96%B8%ED%81%B4%EB%A6%B0-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-uncleanleaderelectionenable)
  - 리더로 선출되었을 경우 데이터 유실이 발생하는 레플리카를 리더로 선출할 수 있도록 함
  - 약간의 데이터 유실이 허용되거나 데이터 유실을 피할 수 없어서 카프카 클러스터의 설정을 잠깐 풀어주어야 할 때 유용함
- `max.connections`
  - 브로커에 연결할 수 있는 최대 연결 수
  - 좀 더 정밀한 스로틀링을 위해서 `max.connections.per.ip`, `max.connections.per.ip.overrides` 를 사용할 수 있음

---

## 3.4. 재정의된 설정 상세 조회: `--descibe`

`--descibe` 를 통해 모든 재정의된 설정 목록 조회가 가능하다. 주의할 점은 재정의된 설정값만 조회가 되고, 클러스터 기본값을 따르는 설정을 포함하지 않는다.    
토픽, 브로커, 클라이언트별 설정값을 확인해볼 수 있다.

_my-topic_ 토픽에 대해 재정의된 모든 설정 조회(보존 시간만 재설정됨)

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--describe --entity-type topics --entity-name my-topic

Configs for topics:my-topic are 
retention.ms=3600000
```

---

## 3.5. 재정의된 설정 삭제: `--delete-config`

동적으로 재정의된 설정은 삭제가 가능하며, 이 경우 해당 설정은 클러스터 기본값으로 돌아간다.

재정의된 설정을 삭제하려면 `--delete-config` 매개변수와 함께 `--alter` 명령을 사용하면 된다.

_my-topic_ 토픽의 retention.ms 설정 재정의 삭제

```shell
$ ./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
--later --entity-type topics --entity-name my-topic \
--delete-config retention.ms

Updated config for topic: "my-topic".
```

---

# 4. 쓰기 작업과 읽기 작업

> `kafka-console-consumer.sh` 와 `kafka-console-producer.sh` 는 필요할 때 찾아보자.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [Doc:: Broker Configs](https://kafka.apache.org/documentation/#brokerconfigs)