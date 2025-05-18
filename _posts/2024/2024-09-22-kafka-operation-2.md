---
layout: post
title:  "Kafka - 운영(2): 파티션 관리"
date: 2024-09-22
categories: dev
tags: kafka
---

이 포스트에서는 카프카 클러스터 운영 시 필요한 툴들에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 파티션 관리](#1-파티션-관리)
  * [1.1. 선호 레플리카 선출: `kafka-leader-election.sh`](#11-선호-레플리카-선출-kafka-leader-electionsh)
  * [1.2. 파티션 레플리카 변경: `kafka-reassign-partitions.sh`](#12-파티션-레플리카-변경-kafka-reassign-partitionssh)
  * [1.3. 로그 세그먼트 덤프 뜨기: `kafka-dump-log.sh`](#13-로그-세그먼트-덤프-뜨기-kafka-dump-logsh)
  * [1.4. 레플리카 검증: `kafka-replica-verification.sh`](#14-레플리카-검증-kafka-replica-verificationsh)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 파티션 관리

카프카는 파티션 관리를 위해 2가지 툴을 제공한다.
- 리더 레플리카를 재선출하기 위한 툴: `kafka-leader-election.sh`
- 파티션을 브로커에 할당해주는 저수준 유틸리티: `kafka-reassign-partitions.sh`

위 2가지 툴은 카프카 클러스터 안의 브로커 간에 메시지 트래픽의 균형을 직접 맞춰줘야 할 때 유용하다.

---

## 1.1. 선호 레플리카 선출: `kafka-leader-election.sh`

> 파티션의 선호 리더의 좀 더 상세한 내용은  
> [3.3. 리더 선출: `elecLeader()`](https://assu10.github.io/dev/2024/07/07/kafka-adminclient-2/#33-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-elecleader),  
> [3.3. 선호 리더(Preferred leader)](https://assu10.github.io/dev/2024/07/13/kafka-mechanism-1/#33-%EC%84%A0%ED%98%B8-%EB%A6%AC%EB%8D%94preferred-leader) 를 참고하세요.

> 언클린 리더 선출에 대한 상세한 내용은 [3.2. 언클린 리더 선출: `unclean.leader.election.enable`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#32-%EC%96%B8%ED%81%B4%EB%A6%B0-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-uncleanleaderelectionenable) 을 참고하세요.

[3. 신뢰성 있는 브로커 설정](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#3-%EC%8B%A0%EB%A2%B0%EC%84%B1-%EC%9E%88%EB%8A%94-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%EC%84%A4%EC%A0%95) 에서 
본 것처럼 각 파티션은 신뢰성을 보장하기 위해 여러 개의 레플리카를 가질 수 있고, 이 레플리카 중 단 하나만이 특정한 시점에 있어서 리더 역할을 맡는다.  
모든 쓰기와 읽기 작업은 리더 역할을 맡는 레플리카가 저장된 브로커에서 일어나므로 전체 카프카 클러스터에 대해 부하를 고르게 하려면 리더 레플리카를 전체 브로커에 걸쳐서 
균형있게 분산해주어야 한다.

리더 레플리카는 레플리카 목록에 있는 첫 번째 ISR 정의된다.  
브로커가 중단되거나 나머지 브로커와의 네트워크 연결이 끊어지면 다른 ISR 중 하나가 리더 역할을 맡게 되는데 중단된 브로커가 다시 살아나거나 네트워크가 복구되어도 
리더 역할은 원래의 리더 레플리카로 복구되지 않는다.  
따라서 자동 리더 밸런싱([`auto.leader.rebalance.enable`](https://assu10.github.io/dev/2024/06/15/kafka-install/#317-autoleaderrebalanceenable)) 기능이 꺼져있으면 처음 설치했을 때는 균형을 이루었던 것이 나중에는 엉망이 되어버릴 수 있다.

이런 이유로 자동 리더 밸런싱 기능을 켜놓거나 [크루즈 컨트롤]((https://github.com/linkedin/cruise-control))과 같은 다른 오픈 소스 툴을 사용하여 언제나 균형을 맞추도록 해주는 것이 좋다.

선호 레플리카를 선출하는 작업은 클러스터에 거의 영향을 미치지 않는 가벼운 작업으로, 클러스터 컨트롤러로 하여금 파티션에 가장 적절한 리더를 고르도록 한다.

클러스터 내의 모든 선호 레플리카를 선출하는 예시

```shell
$ ./bin/kafka-leader-election.sh --bootstrap-server localhost:9092 \
--election-type PREFERRED \
--all-topic-partitions
```

`--topic` 옵션과 `--partition` 옵션을 사용하여 특정 파티션이나 토픽에 대해서만 선출할 수도 있고, 선출 작업을 할 파티션 목록을 지정해 줄 수도 있다.

partitions.json

```json
{
  "partitions": [
    {
      "partition": 1,
      "topic": "my-topic"
    },
    {
      "partition": 2,
      "topic": "my-topic-2"
    }
  ]
}
```

partitions.json 파일에 지정된 파티션 목록에 대해 선호 레플리카를 선출하는 예시

```shell
$ ./bin/kafka-leader-election.sh --bootstrap-server localhost:9092 \
--election-type PREPERRED \
--path-to-json-file partitions.json
```

---

## 1.2. 파티션 레플리카 변경: `kafka-reassign-partitions.sh`

<**파티션의 레플리카 할당을 수동으로 변경해주어야 할 때**>
- 자동으로 리더 레플리카를 분산시켜 주었지만 여전히 브로커 간의 부하가 불균등할 때
- 브로커가 내려가서 파티션이 불완전 복제되고 있을 때
- 새로 추가된 브로커에 파티션을 빠르게 분산시켜주고 싶을 때
- 토픽의 복제 팩터를 변경해주고 싶을 때

`kafka-reassign-partitions.sh` 툴 사용은 2단계로 구성된다.
- **이동시킬 파티션 목록 생성**
  - 브로커 목록과 토픽 목록을 사용하여 이동시킬 파티션 목록 생성
  - 주어질 토픽 목록을 담은 JSON 파일 생성 필요함
- **생성된 것을 실행**

4대의 브로커를 가진 카프카 클러스터에 2대의 브로커를 추가해서 총 6대가 되었고, 토픽 중 2개를 5번과 6번 브로커로 옮긴다고 해보자.  
먼저 이동시킬 파티션 목록을 생성하기 위해 토픽 목록을 담은 JSON 파일을 생성해야 한다.

```json
{
  "topics": [
    {
      "topic": "foo1"
    },
    {
      "topic": "foo2"
    }
  ],
  "version": 1 // 버전은 항상 1임
}
```

이제 위의 JSON 파일을 이용하여 topics.json 파일에 지정된 토픽들을 5번과 6번 브로커로 이동시키는 파티션 이동 목록을 생성할 수 있다.

```shell
$ ./bin/kafka-leader-election.sh --bootstrap-server localhost:9092 \
--topics-to-move-json-file topics.json \
--broker-list 5,6 --generate

{
  "version": 1,
  "partitions": [
    {"topic": "foo1","partition": 2,"replicas": [1,2]},
    {"topic": "foo1","partition": 0,"replicas": [3,4]},
    {"topic": "foo2","partition": 2,"replicas": [1,2]},
    {"topic": "foo2","partition": 0,"replicas": [3,4]},
    {"topic": "foo1","partition": 1,"replicas": [2,3]},
    {"topic": "foo2","partition": 1,"replicas": [2,3]}
  ]
}
Proposed partition reassignment configuration
{
  "version": 1,
  "partitions": [
    {"topic": "foo1","partition": 2,"replicas": [5,6]},
    {"topic": "foo1","partition": 0,"replicas": [5,6]},
    {"topic": "foo2","partition": 2,"replicas": [5,6]},
    {"topic": "foo2","partition": 0,"replicas": [5,6]},
    {"topic": "foo1","partition": 1,"replicas": [5,6]},
    {"topic": "foo2","partition": 1,"replicas": [5,6]}
  ]
}
```

위의 2개의 출력물은 2개의 JSON(_revert-reassignment.json_ 과 _expand-cluster-reassignment.json_ 이라고 해보자) 을 보여준다.

첫 번째 파일은 어떤 이유로 재할당 작업을 롤백하고 싶을 때 파티션을 원래 위치로 돌릴 때 사용할 수 있고, 두 번째 파일은 다음에 사용할 파일인데 아직 실행되지 않은 파티션의 이동 안을 나타낸다.

_expand-cluster-reassignment.json_ 파일에 있는 파티션 재할당 안 실행

```shell
$ ./bin/kafka-leader-election.sh --bootstrap-server localhost:9092 \
--reassignment-json-file expand-cluster-reassignment.json \
--execute Current partition replica assignment
```

위 명령은 지정된 파티션 레플리카를 새로운 브로커로 재할당하는 작업을 시작시킨다.  
클러스터 컨트롤러는 일단 각 파티션의 레플리카 목록에 새로운 레플리카를 추가하는 식으로 재할당 작업을 실행한다. 이 때 이 토픽의 복제 팩터가 일시적으로 증가된다.  
이 때부터 새로 추가된 레플리카들은 각 파티션의 현재 리더로부터 모든 기존 메시지들을 복사해오는데, 디스크 안의 파티션 크기에 따라 이 작업은 엄청난 시간이 걸릴 수도 있다.  
복제 작업이 완료되면 컨트롤러는 복제 팩터를 원상 복구시킴으로써 오래된 레플리카를 제거한다.

어떤 재할당이 현재 진행중이고, 완료되었고, 실패했는지, 파티션 이동의 진행 상태는 `--verify` 옵션을 사용하여 모니터링 할 수 있다.

```shell
$ ./bin/kafka-leader-election.sh --bootstrap-server localhost:9092 \
--reassignment-json-file expand-cluster-reassignment.json \
--verify
```

---

## 1.3. 로그 세그먼트 덤프 뜨기: `kafka-dump-log.sh`

포이즌 필(poison fill 메시지)라고 불리는 토픽 내 특정 메시지가 오염되어 컨슈머가 처리할 수 없을 때 특정 메시지의 내용을 봐야 한다.  
`kafka-dump-log.sh` 는 파티션의 로그 세그먼트를 열어볼 때 사용하는 툴로 토픽을 컨슈머로 읽어올 필요없이 각 메시지를 바로 열어볼 수 있게 해준다.

아래는 _my-topic_ 토픽의 로그를 덤프로 뜨는 예시이다.  
00000.log 로그 세그먼트 파일을 열어서 각 메시지의 기본적인 메타데이터 정보만 출력한다.  
이 포스트에서 카프카 데이터는 /tmp/kafka-logs 디렉토리에 저장되므로 로그 세그먼트는 /tmp/kafka-logs/<topic-name>-<partition> 형식에 따라 /tmp/kafka-logs/my-topic-0/ 을 찾는다.

```shell
$ ./bin/kafka-dump-log.sh --files /tmp/kafka-logs/my-topic-0/00000.log
```

---

## 1.4. 레플리카 검증: `kafka-replica-verification.sh`

`kafka-replica-verification.sh` 툴은 클러스터 전체에 걸쳐 토픽 파티션의 레플리카들이 서로 동일하다는 점을 확인할 수 있게 해준다.  
`kafka-replica-verification.sh` 툴은 주어진 토픽 파티션의 모든 레플리카로부터 메시지를 읽어온 뒤, 모든 레플리카가 해당 메시지를 갖고 있다는 점을 확인하고, 주어진 
파티션의 최대 lag 값을 출력한다.  
이 작업은 취소될 때까지 루프를 돌면서 계속해서 실행된다.  
기본적으로 모든 토픽이 검증 대상이지만, 검증하려고 하는 토픽들의 이름에 해당하는 정규식을 지정해 줄 수도 있다.

레플리카 검증을 하기 위해서는 가장 오래된 오프셋에서부터 모든 메시지를 읽어와야 하기 때문에 파티션 재할당 툴과 마찬가지로 클러스터에 영향을 준다.

_my-topic_ 토픽의 0번 파티션을 포함하는 브로커 1,2번에 대해 _my_ 로 시작하는 토픽들의 레플리카를 검증하는 예시

```shell
$ ./bin/kafka-replica-verification.sh \
--broker-list kafka.host1.domain.com:9092,kafka.host2.domain.com:9092 \
--topic-white-list 'my.*'
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)