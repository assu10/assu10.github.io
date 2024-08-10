---
layout: post
title:  "Kafka - 카프카 용어, 장점, 이용 사례"
date: 2024-06-10
categories: dev
tags: kafka
---

이 포스트에서는 카프카의 기본 개념에 대해 알아본다.

모든 애플리케이션은 데이터를 생성하고 데이터는 중요한 정보를 담고 있다.  
그 정보가 무엇인지 알기 위해서는 데이터를 생성된 곳에서 분석할 수 있는 곳으로 옮겨야 하는데 이러한 작업을 빠르게 해낼수록 조직은 더 유연해지고 민첩해질 수 있다.  
데이터를 이동시키는 작업에 더 적은 노력을 들일수록 핵심 비즈니스에 더 집중할 수 있다.

데이터가 중심이 되는 기업에서 파이프라인이 중요한 핵심 요소가 되는 이유가 바로 이것 때문이다.

---

**목차**

<!-- TOC -->
* [1. 발행/구독 메시지 전달 (publish/subscribe messaging)](#1-발행구독-메시지-전달-publishsubscribe-messaging)
  * [1.1. 초기의 발행/구독 시스템](#11-초기의-발행구독-시스템)
  * [1.2. 개별 메시지 큐 시스템](#12-개별-메시지-큐-시스템)
* [2. 카프카 용어](#2-카프카-용어)
  * [2.1. 메시지, 키, 배치](#21-메시지-키-배치)
  * [2.2. 스키마: Avro](#22-스키마-avro)
  * [2.3. 토픽, 파티션, 스트림](#23-토픽-파티션-스트림)
  * [2.4. 프로듀서, 컨슈머, 오프셋, 컨슈머 그룹](#24-프로듀서-컨슈머-오프셋-컨슈머-그룹)
  * [2.5. 브로커, 클러스터, 컨트롤러, 파티션 리더, 팔로워](#25-브로커-클러스터-컨트롤러-파티션-리더-팔로워)
    * [2.5.1. 보존 (retention) 기능](#251-보존-retention-기능)
  * [2.6. 다중 클러스터](#26-다중-클러스터)
* [3. 카프카 장점](#3-카프카-장점)
* [4. 카프카 이용 사례](#4-카프카-이용-사례)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 발행/구독 메시지 전달 (publish/subscribe messaging)

카프카에 대해 알아보기 전에 발행/구독 메시지 전달 개념에 대해 알아두어야 한다.

**pub/sub 메시지 전달 패턴의 특징**은 아래와 같다.
- 전송자(publisher)가 데이터(메시지)를 보낼 때 직접 수신자(subscriber) 로 보내지 않음
- 전송자는 어떤 형태로든 메시지를 분류해서 보냄
- 수신자는 이렇게 분류된 메시지를 구독함
- 전송자와 수신자 사이에는 발행된 메시지를 전달받아 중계해주는 중간 지점 역할을 하는 브로커(broker) 가 있음

---

## 1.1. 초기의 발행/구독 시스템

초기의 발행/구독 시스템은 대부분 가운데 간단한 메시지 큐나 프로세스 간 통신 채널을 두는 것으로 시작한다.  
즉, 어디론가 모니터링 지표를 보내는 애플리케이션을 개발했다면 아래와 같이 애플리케이션에서 지표를 대시보드 형태로 보여주는 앱으로 연결을 생성하여 그 연결을 통해 지표를 전송한다.

![발행자와 구독자가 직접 연결된 단일 지표 발행자](/assets/img/dev/2024/0610/pubsub1.png)

위 방식은 처음엔 괜찮지만 시간이 지날수록 문제가 발생하기 시작한다.

지표를 받아서 저장하고 분석하는 서비스를 새로 하나 만들게 되면 그 서비스가 잘 동작하게 하기 이해 애플리케이션을 고쳐서 두 시스템에 지표값을 전송해야 한다.  
만일 지표를 생성하는 애플리케이션이 3개가 되면 2개의 지표서비스에 똑같은 연결을 또 만든다.

만일 서비스를 폴링해서 이슈 발생 시 알람을 울리는 기능을 넣으려면 각각의 애플리케이션에 요청을 받아서 지표를 응답하는 서버를 추가해야 한다.

시간이 더 흐르면 이러한 서버들에서 지표를 가져다 여러 목적으로 활용하는 더 많은 애플리케이션이 추가되고 그렇게 되면 아래 그림처럼 연결을 추적하는 것이 어려워진다.

![발행자와 구독자가 직접 연결된 여러 지표 발행자](/assets/img/dev/2024/0610/pubsub2.png)

이런 방식에서 발생하는 기술 부채는 명백하기 때문에 개선이 필요하다.

**모든 애플리케이션으로부터 지표를 받는 하나의 애플리케이션을 만들고, 이 지표값들을 필요로 하는 모든 시스템에서 지표를 질의할 수 있도록 해주는 서버를 제공**하면 아래와 같이 
복잡성이 줄어든 아키텍처를 만들 수 있다.

![지표 발행 및 구독 시스템](/assets/img/dev/2024/0610/pubsub3.png)

**위 아키텍처가 바로 메시지 발행/구독 시스템의 아키텍처**이다.

---

## 1.2. 개별 메시지 큐 시스템

지표를 다루는 것과 동시에 로그 메시지에 대해서도 비슷한 작업이 필요하다.

프론트엔드 웹사이트에서의 사용자 활동을 추적하여 이 정보를 기계 학습 개발자에게 제공하거나 보고용으로 사용할 수도 있다.  
이러한 경우에도 비슷한 시스템을 구성하여 정보의 발행자와 구독자를 분리할 수 있다.

아래는 3개의 발생/구독 시스템으로 이루어진 인프라스트럭처이다.

![3개의 발행 및 구독 시스템](/assets/img/dev/2024/0610/pubsub4.png)

아래의 그림처럼 포인트 투 포인트 연결을 활용하는 방식보다 위의 방식이 더 바람직하지만 여기에도 중복이 많다.  
위처럼 하게 되면 버그와 한계가 제각각인 다수의 데이터 큐 시스템을 유지 관리해야 한다.  
또 여기에 메시지 교환을 필요로 하는 케이스가 추가로 발생할 수도 있다.

![발행자와 구독자가 직접 연결된 여러 지표 발행자 (포인트 투 포인트)](/assets/img/dev/2024/0610/pubsub2.png)

따라서 **비즈니스가 확장함에 따라 함께 확장되는 일반화된 유형의 데이터를 발행하고 구독할 수 있는 중앙 집중화된 시스템이 필요**하다.

---

# 2. 카프카 용어

카프카는 위와 같은 문제를 해결하기 위해 고안된 메시지 발행/구독 시스템으로 **분산 커밋 로그** 혹은 **분산 스트리밍 플랫폼**이라고 불리기도 한다.

DB 의 커밋 로그는 모든 트랙잭션 기록을 지속성 (durable) 있게 보존함으로써 시스템의 상태를 일관성 (consistency) 있게 복구할 수 있도록 고안되었다.

비슷하게 **카프카에 저장된 데이터는 순서를 유지한채로 지속성있게 보관되며, 결정적 (deterministic) 으로 읽을 수 있다.**    
또한 **확장 시 성능을 향상시키고 실패가 발생하더라도 데이터 사용에는 문제가 없도록 시스템 안에서 데이터를 분산시켜 저장**할 수 있다.

---

## 2.1. 메시지, 키, 배치

- **메시지**
  - 카프카에서 데이터의 기본 단위
  - 카프카 입장에서는 단순한 바이트의 배열임
  - key 라고 불리는 메타데이터 포함할 수 있음
  - key 역시 카프카 입장에서는 단순한 바이트의 배열임
- **키(key)**
  - 메시지를 저장할 파티션을 결정하기 위해 사용됨
  - 가장 간단한 방법은 key 값에서 일정한 해시값을 생성한 후 이 해시값을 토픽의 파티션 수로 나눴을 때 나머지 값에 해당하는 파티션에 메시지를 저장하는 것임
  - 이렇게 하면 같은 key 값을 가진 메시지는 파티션 수가 변하지 않는 한 항상 같은 파티션에 저장됨
- **배치**
  - 메시지를 저장하는 단위로 같은 토픽의 파티션에 쓰이는 메시지의 집함
  - 메시지를 쓸 때마다 네트워크 상에서 신호가 오가는 것은 큰 오버헤드를 발생시키는데 메시지를 배치 단위로 모아서 쓰면 이를 줄일 수 있음
  - 이것은 지연 (latency) 과 처리량 (throughput) 사이에 트레이드 오프를 발생시킴
  - 즉, 배치 크기가 커질수록 시간당 처리되는 메시지 수는 늘어나지만 각각의 메시지가 전달되는 데 걸리는 시간은 늘어남
  - 배치는 더 효율적인 데이터 전송과 저장을 위해 약간의 처리 능력을 들여서 압축되는 경우가 많음

> key 와 value 에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다. (p. 5)

---

## 2.2. 스키마: Avro

카프카 입장에서 메시지는 단순한 바이트 배열일 뿐이지만 **내용을 이해하기 쉽도록 일정한 구조(= 스키마) 를 부여**하는 것이 좋다.  
사용 가능한 메시지 스키마는 JSON, XML 등이 있지만 이 방식들은 타입 처리 기능이나 스키마 버전 간의 호환성 유지 기능이 떨어진다.

그래서 **보통 [아파치 아브로](https://ko.wikipedia.org/wiki/%EC%95%84%ED%8C%8C%EC%B9%98_%EC%95%84%EB%B8%8C%EB%A1%9C) 를 선호**한다.

**아브로는 조밀한 직렬화 형식을 제공하며, 메시지 본체와 스키마를 분리하기 때문에 스키마가 변경되더라도 코드를 생성할 필요가 없다.**    
또한 **강력한 데이터 타이핑과 스키마 변경에 따른 상위 호환성, 하위 호환성을 지원**한다.

카프카에서는 일관적인 데이터 형식이 중요한데 그 이우는 일관적인 데이터 형식은 메시지 쓰기와 읽기 작업을 분리할 수 있게 해주기 때문이다.  
만일 메시지 쓰기와 읽기 작업이 서로 결합되어 있다면 데이터 형식이 변경될 때 아래와 같은 순서로 진행되어야 한다.

- 메시지를 구독하는 애플리케이션들이 먼저 구버전과 신버전을 동시에 지원할 수 있도록 업데이트
- 메시지를 발행하는 애플리케이션이 신버전 형식을 사용하도록 업데이트

만일 **잘 정의된 스키마를 공유 저장소에 저장하여 사용하면 카프카는 두 버전 형식을 동시에 지원하도록 하는 작업 없이도 메시지 처리가 가능**하다.

> 스키마와 직렬화에 대해서는 추후 상세히 다룰 예정입니다. (p. 5)

---

## 2.3. 토픽, 파티션, 스트림

- **토픽**
  - 카프카에 저장되는 메시지는 토픽 단위로 분류됨 (DB 의 테이블이나 파일시스템의 폴더 개념)
- **파티션**
  - **토픽은 여러 개의 파티션으로 나뉘어짐**
  - 커밋 로그의 관점으로 볼 때 파티션은 하나의 로그에 해당함
  - 파티션에 메시지가 쓰여질 때는 추가만 가능한 형태로 쓰여지고, 읽을 때는 맨 앞부터 제일 끝까지의 순서로 읽힘
  - **토픽에 여러 개의 파티션이 있는만큼 토픽 안의 메시지 전체에 대해 순서는 보장되지 않으며, 단일 파티션 안에서만 순서가 보장**됨
  - 파티션은 카프카가 데이터 중복과 확장성을 제공하는 방법임
    - **각 파티션이 서로 다른 서버에 저장될 수 있기 때문에 하나의 토픽이 여러 개의 서버로 수평적으로 확장되어 하나의 서버의 용량을 넘어가는 성능**을 보여줄 수 있음
  - 파티션은 복제될 수 있음
    - 즉, **서로 다른 서버들이 동일한 파티션의 복제본을 저장하고 있기 때문에 서버 중 하나에 장애가 발생해도 읽거나 쓸 수 없는 상황이 벌어지지 않음**

아래는 4개의 파티션을 가진 토픽이다.

![4개의 파티션을 갖는 하나의 토픽](/assets/img/dev/2024/0610/topic.png)

메시지룰 쓰면 각 파티션의 끝에 추가된다.

- **스트림**
  - 스트림은 파티션의 개수와 상관없이 하나의 토픽에 저장된 데이터로 간주됨
  - 프로듀서로부터 컨슈머로의 하나의 데이터 흐름을 나타냄

> 스트림 처리에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다. (p. 6)

---

## 2.4. 프로듀서, 컨슈머, 오프셋, 컨슈머 그룹

**카프카 클라이언트는 이 시스템의 사용자이며, 기본적으로 프로듀서와 컨슈머 두 종류**가 있다.

이 외에 데이터 통합에 사용되는 **카프카 커넥트 API** 와 스트림 처리에 사용되는 **카프카 스트림즈**도 있는데 이 클라이언트들은 프로듀서와 컨슈머를 기본 요소로 사용하며, 좀 더 고급 기능을 제공한다.

- **프로듀서 (publisher, writer)**
  - 새로운 메시지 생성
  - **메시지는 특정한 토픽에 쓰여지며, 기본적으로 프로듀서는 메시지를 쓸 때 포틱에 속한 파티션들 사이에 고르게 나뉘어서 쓰도록 되어 있음**
  - 어쩔 때는 프로듀서가 특정한 파티션을 지정해서 메시지를 쓰기도 하는데 이것은 보통 메시지 key 와 key 값의 해시를 특정 파티션으로 대응시켜 주는 **파티셔너**를 사용하여 구현됨
  - 이렇게 함으로써 동일한 key 값을 가진 모든 메시지는 같은 파티션에 저장됨
  - 프로듀서는 메시지를 파티션으로 대응시켜주는 특정 규칙을 가진 커스텀 파티셔너를 사용할 수도 있음
  - > 프로듀서에 대한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 7)
- **컨슈머 (subscriber, reader)**
  - 메시지를 읽음
  - **컨슈머는 1개 이상의 토픽을 구독하여 여기에 저장된 메시지들을 각 파티션에 쓰여진 순서대로 읽어옴**
  - 컨슈머는 메시지 오프셋을 기록함으로써 어느 메시지까지 읽었는지를 유지함
- **오프셋**
  - 지속적으로 증가하는 정수값
  - 카프카가 메시지를 저장할 때 각각의 메시지에 부여해주는 또 다른 메타 데이터
  - 주어진 파티션의 각 메시지는 고유한 오프셋을 가짐
  - **파티션별로 다음 번에 사용 가능한 오프셋 값을 저장함으로써 컨슈머는 읽기 작업을 정지했다가 다시 시작하더라도 마지막으로 읽었던 메시지의 바로 다음 메시지부터 읽을 수 있음**
- **컨슈머 그룹**
  - 컨슈머는 컨슈머 그룹의 일원으로써 동작함
  - 컨슈머 그룹은 토픽에 저장된 데이터를 읽어오기 위해 협업하는 하나 이상의 컨슈머로 구성됨
  - **컨슈머 그룹은 각 파티션이 하나의 컨슈머에 의해서만 읽히도록 함**

![토픽을 읽는 컨슈머들](/assets/img/dev/2024/0610/consumer_group.png)

위 그림은 하나의 컨슈머 그룹에 속한 3개의 컨슈머가 하나의 토픽에서 데이터를 읽어오는 모습이다.    
2개의 컨슈머는 각각 하나의 파티션만 읽어서 처리하는 반면, 1개의 컨슈머는 2개의 파티션을 읽어서 처리한다.  
**컨슈머에서 파티션으로의 대응 관계를 컨슈머의 파티션 소유권(ownership)** 이라고 한다.

위처럼 **컨슈머 그룹을 사용함으로써 대량의 메시지를 갖는 토픽들을 읽기 위해 컨슈머들을 수평확장** 할 수 있다.  
또한 컨슈머 중 하나에 장애가 발생하더라도 컨슈머 그룹 안의 다른 컨슈머들이 장애가 발생한 컨슈머가 읽고 있던 파티션을 재할당받은 뒤 이어서 데이터를 읽어볼 수 있다.

> 컨슈머와 컨슈머 그룹에 대한 좀 더 상세한 내용은 추후 다룰 예정입니다. (p. 8)

---

## 2.5. 브로커, 클러스터, 컨트롤러, 파티션 리더, 팔로워

- **브로커**
  - **하나의 카프카 서버를 브로커**라고 함
  - 브로커는 프로듀서로부터 메시지를 전달받아 오프셋을 할당한 뒤 디스크 저장소에 씀
  - 브로커는 컨슈머의 파티션 읽기 (fetch) 요청을 처리하고 발행된 메시지를 보내줌
  - 하드웨어 성능에 따라 다르겠지만 하나의 브로커는 초당 수천개의 파티션과 수백만개의 메시지를 쉽게 처리할 수 있음
- **클러스터**
  - 카프카 브로커는 클러스터의 일부로써 작동하도록 설계되어 있음
  - 하나의 클러스터 안에 여러 개의 브로커가 포함될 수 있으며 그 중 하나의 브로커가 **클러스터 컨트롤러 역할**을 하게 됨
- **컨트롤러**
  - 컨트롤러는 클러스터 안의 현재 작동 중인 브로커 중 하나가 자동으로 선정됨
  - **파티션을 브로커에 할당해주거나 장애가 발생한 브로커를 모니터링 하는 등의 관리 기능을 담당**함
- **파티션 리더**
  - **파티션은 클러스터 안의 브로커 중 하나가 담당**하며, 그것을 파티션 리더라고 함
- **팔로워**
  - **복제된 파티션이 여러 브로커에 할당될 수도 있는데 이것들은 파티션의 팔로워**라고 부름

![클러스터 안에서의 파티션 복제](/assets/img/dev/2024/0610/dupl.png)

복제 (replication) 기능은 파티션의 메시지를 중복 저장함으로써 리더 브로커가 장애가 발생했을 때 팔로워 중 하나가 리더 역할을 이어받을 수 있게 한다.

모든 프로듀서는 리더 브로커에게 메시지를 발생해야 하지만 컨슈머는 리더나 팔로워 중 하나로부터 데이터를 읽어올 수 있다.

> 파티션 복제를 포함한 클러스터 기능은 추후 상세히 다룰 예정입니다. (p. 8)

---

### 2.5.1. 보존 (retention) 기능

카프카의 핵심 기능 중 하나는 **일정 기간 동안 메시지를 지속성 (durability) 있게 보관하는 보존 기능**이다.

카프카 브로커는 토픽에 대해 기본적인 보존 설정이 되어있는데 **특정 기간동안 메시지를 보존하거나 파티션의 크기가 특정 사이즈에 도달할 때까지 데이터를 보존**한다.  
만일 한도값에 도달하면 메시지는 만료되어 삭제된다.  
**각각의 토픽에는 메시지가 필요한 정도까지만 저장되도록 보존 설정**을 잡아줄 수 있다.

**토픽에는 로그 압착 (log compaction)** 기능을 설정할 수도 있는데 이 경우 **같은 키를 갖는 메시지 중 가장 최신의 것만 보존**된다.  
로그 압착 기능은 마지막 변경값만이 중요한 체인지 로그 형태의 데이터에 사용하면 좋다.

---

## 2.6. 다중 클러스터

다중 클러스터를 사용하면 아래와 같은 장점이 있다.

- 데이터 유형별 분리
- 보안 요구사항을 충족시키기 위한 격리
- 재해 복구(DR, Disaster Recovery) 를 대비한 다중 데이터센터

카프카 클러스터의 복제 메커니즘은 다중 클러스터 사이에서가 아닌 하나의 클러스터 안에서만 작동하도록 설계되었기 때문에 다중 클러스터로 운영 시 클러스터 간 메시지를 복제해주어야 한다.

**카프카 프로젝트는 데이터를 다른 클러스터로 복제하는데 사용되는 미러메이커 (MirrorMaker) 라는 툴을 포함**한다.  
미러메이커는 하나의 카프카 클러스터에서 메시지를 읽어와서 다른 클러스터에 쓴다.

> 미러메이커의 데이터 파이프라인 구축에 관한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 10)

---

# 3. 카프카 장점

- **다중 프로듀서**
  - 카프카의 다중 프로듀서 기능 때문에 많은 프론트엔트 시스템으로부터 데이터를 수집하고 일관성을 유지하는데 적격임
  - 예) 다수의 마이크로서비스를 통해 사용자에게 컨텐츠를 서비스하는 사이트에서는 모든 서비스가 공통의 형식으로 쓸 수 있는 페이지 뷰 용 토픽을 가질 수 있음  
  컨슈머 애플리케이션은 애플리케이션별로 하나씩, 여러 개의 토픽에서 데이터를 읽어올 필요없이 사이트의 모든 애플리케이션에 대한 페이지 뷰 스트림 하나만 읽어오면 됨
- **다중 컨슈머**
  - **카프카는 많은 컨슈머가 상호 간섭없이 메시지 스트림을 읽을 수 있도록 설계**되어 있음
  - 이것이 **하나의 메시지를 하나의 클라이언트에서만 소비할 수 있도록 되어있는 많은 큐 시스템과의 결정적인 차이점**임
  - 다수의 카프카 컨슈머는 컨슈머 그룹의 일원으로 작동함으로써 하나의 스트림을 여럿이서 나눠서 읽을 수 있음
  - 이 경우 주어진 메시지는 전체 컨슈머 그룹에 대해 한 번만 처리됨
- **디스크 기반 보존**
  - 카프카는 메시지를 지속성있게 저장할 수 있음
  - 이는 **컨슈머들이 항상 실시간으로 데이터를 읽어올 필요가 없다는 의미**임
  - 메시지는 디스크에 쓰여진 뒤 설정된 보유 규칙과 함께 저장되는데 이 옵션들은 토픽별로 설정이 가능해서 서로 다른 메시지 스트림이 컨슈머의 필요에 따라 서로 다른 기간동안 보존될 수 있음
  - 따라서 **만일 컨슈머가 느린 처리 속도 혹은 트래픽 폭주로 인해 뒤쳐질 경우에도 데이터 유실은 없음**
  - **컨슈머를 정지하더라도 메시지는 카프카에 남아있으므로 프로듀서가 메시지를 백업하거나 메시지 유실 걱정없이 컨슈머 애플리케이션을 내리고 컨슈머를 유지보수할 수 있음**
  - 그리고 컨슈머가 다시 시작되면 작업을 멈춘 지점부터 유실없이 데이터 처리 가능
- **확장성**
  - 카프카는 유연한 확정성을 가지고 있어서 어떠한 크기의 데이터도 쉽게 처리 가능
  - **카프카 클러스터는 작동 중에도 시스템 전체의 가용성 (availability) 에 영향을 주지 않으면서 확장 가능**
  - 여러 대의 브로커로 구성된 클러스터는 개별 브로커의 장애를 처리하면서 지속적으로 클라이언트의 요청을 처리할 수 있다는 의미
  - 동시다발적인 장애를 견뎌야 하는 클러스터의 경우 더 큰 **복제 팩터 (RF, Replication Factor)** 를 설정해주는 것이 가능함
  - > 복제에 대한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 12)
- **고성능**
  - 발행된 메시지가 컨슈머에게 전달될 때까지 1초도 안 걸리면서도 프로듀서, 컨슈머, 브로커 모두가 매우 큰 메시지 스트림을 쉽게 다룰 수 있도록 수평 확장 가능
- **플랫폼 기능**
  - 아파치 카프카의 코어 프로젝트에는 개발자들이 자주 하는 작업을 쉽게 수행할 수 있도록 해주는 플랫폼 기능이 있음
  - 이 기능들은 API 와 라이브러리의 형태로 사용 가능
  - **카프카 커넥트**는 소스 데이터 시스템으로부터 카프카로 데이터를 가져오거나 카프카의 데이터를 싱크 시스템으로 내보내는 작업을 함
  - **카프카 스트림즈**는 규모 가변성 (scalability) 과 내고장성 (fault tolerance) 을 갖춘 스트림 처리 애플리케이션을 쉽게 개발할 수 있도록 해줌
  - > 카프카 커넥트에 대한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 12)
  - > 카프카 스트림즈에 대한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 12)

---

# 4. 카프카 이용 사례

- **사용자 활동 추적**
  - 사용자 활동에 대한 메시지들은 하나 이상의 토픽으로 발행되어 백엔드에서 작동 중인 애플리케이션에 전달됨
  - 이 애플리케이션들은 보고서를 생성하거나 기계 학습 시스템에 데이터를 전달하거나 풍부한 사용자 경험을 제공하기 위해 다른 작업을 수행할 수 있음
- **메시지 교환**
  - 유저에게 이메일과 같은 알림을 보내야하는 애플리케이션에서 활용 가능
  - 이 애플리케이션들은 메시지 형식이나 전송 방법에 신경쓰지 않고 메시지 생성 가능한데 **아래와 같은 작업을 수행하는 하나의 애플리케이션이 보낼 메시지를 모두 읽어와서 같은 방식으로 처리할 수 있기 때문**임
    - 같은 룩앤필 (look and feel) 을 사용하여 메시지를 포매팅 혹은 데코레이팅해줌
    - 여러 개의 메시지를 모아서 하나의 알림 메시지로 전송
    - 사용자가 원하는 메시지 수신 방식을 적용
  - 하나의 애플리케이션에서 이러한 작업을 처리하면 여러 애플리케이션에 기능을 중복해서 구현할 필요가 없음
- **지표, 로그 수집**
  - 카프카는 애플리케이션과 시스템의 지표값과 로그를 수집하는데 이상적임
  - 지표, 로그 수집은 여러 애플리케이션이 같은 유형으로 생성한 메시지를 활용하는 대표적인 사례임
  - 애플리케이션이 정기적으로 지표값을 카프카 토픽에 발행하면 모니터링과 경보를 맡고 있는 시스템이 이 지표값들을 가져다 사용함
  - 로그 메시지 역시 같은 방식으로 발행될 수 있으며 엘라스틱 서치와 같은 로그 검색 전용 시스템이나 보안 분석 애플리케이션으로 보내질 수 있음
  - 지표, 로그 수집에 카프카를 사용하면 목적 시스템 (예- 로그 저장 시스템 변경) 변경 시에도 프론트엔드 애플리케이션이나 메시지 수집 방법을 변경할 필요가 없음
- **커밋 로그**
  - 카프카가 DB 의 커밋 로그 개념을 기반으로 하여 만들어진 만큼 DB 에 가해진 변경점들이 스트림의 형태로 카프카에 발행될 수 있으며 애플리케이션은 이 스트림을 이용하여 쉽게 실시간 업데이트를 받아볼 수 있음
  - 이 체인지로그 스트림은 DB 에 가해진 업데이트를 원격 시스템에 복제하거나 다수의 애플리케이션에서 발생한 변경점을 하나의 DB 뷰로 통합할 때 사용 가능함
  - 토픽에 key 별로 마지막 값 하나만을 보존하는 로그 압착 기능을 사용함으로써 로그를 더 오랫동안 보존 가능
- **스트림 처리**
  - 카프카를 사용하는 거의 모든 경우가 스트림 처리임
  - 하둡은 오랜 시간에 걸쳐 누적된 데이터를 처리하는 반면 스트림 처리는 메시지가 생성되자마자 실시간으로 데이터를 처리함
  - > 스트림 처리에 대한 좀 더 상세한 설명은 추후 다룰 예정입니다. (p. 15)

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [아파치 아브로](https://ko.wikipedia.org/wiki/%EC%95%84%ED%8C%8C%EC%B9%98_%EC%95%84%EB%B8%8C%EB%A1%9C)