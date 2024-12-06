---
layout: post
title:  "Kafka - 멱등적 프로듀서, 트랜잭션"
date: 2024-08-18
categories: dev
tags: kafka idempotence-producer transaction
---

[Kafka - 신뢰성 있는 데이터 전달, 복제](https://assu10.github.io/dev/2024/08/17/kafka-reliability/) 에서 '최소 한 번' 전달에 초점을 맞추었다면 
이번 포스트에서는 메시지 중복 가능성을 최소화하는 '정확히 한 번' 에 초점을 맞춘다.

대부분의 애플리케이션들은 메시지를 읽는 애플리케이션이 중복 메시지를 제거할 수 있도록 메시지에 고유한 식별자를 포함한다.

이 포스트에서는 아래의 내용에 대해 알아본다.
- 카프카의 '정확히 한 번' 의미 구조를 사용하는 방법
- '정확히 한 번' 이 권장되는 활용 사례와 한계

카프카의 '정확히 한 번' 의미 구조는 아래 2개의 핵심 기능의 조합으로 이루어진다.
- 멱등적 프로듀서(idempotent producer)
  - 프로듀서 재시도로 인해 발생하는 중복 방지
- 트랜잭션 의미 구조
  - 스트림 처리 애플리케이션에서 '정확히 한 번' 처리 보장

> 소스는 [github](https://github.com/assu10/kafka/tree/feature/chap08) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 멱등적 프로듀서(idempotent producer)](#1-멱등적-프로듀서idempotent-producer)
  * [1.1. 멱등적 프로듀서 작동 원리](#11-멱등적-프로듀서-작동-원리)
    * [1.1.1. 프로듀서 재시작](#111-프로듀서-재시작)
    * [1.1.2. 브로커 장애](#112-브로커-장애)
  * [1.2. 멱등적 프로듀서 한계](#12-멱등적-프로듀서-한계)
  * [1.3. 멱등적 프로듀서 사용법: `enable.idempotence`](#13-멱등적-프로듀서-사용법-enableidempotence)
* [2. 트랜잭션](#2-트랜잭션)
  * [2.1. 트랜잭션을 사용하지 않을 경우](#21-트랜잭션을-사용하지-않을-경우)
    * [2.1.1. 애플리케이션 크래시로 인한 재처리로 중복 발생](#211-애플리케이션-크래시로-인한-재처리로-중복-발생)
    * [2.1.2. 좀비 애플리케이션에 의해 발생하는 재처리로 중복 발생](#212-좀비-애플리케이션에-의해-발생하는-재처리로-중복-발생)
  * [2.2. 트랜잭션이 '정확히 한 번'을 보장하는 방법](#22-트랜잭션이-정확히-한-번을-보장하는-방법)
    * [2.2.1. 트랜잭션적 프로듀서: `transactional.id`](#221-트랜잭션적-프로듀서-transactionalid)
    * [2.2.2. 좀비 펜싱](#222-좀비-펜싱)
    * [2.2.3. 트랜잭션을 위한 컨슈머 설정: `isolation.level`](#223-트랜잭션을-위한-컨슈머-설정-isolationlevel)
  * [2.3. 트랜잭션이 해결하지 못하는 문제](#23-트랜잭션이-해결하지-못하는-문제)
    * [2.3.1. 스트림 처리에 있어서의 side effect](#231-스트림-처리에-있어서의-side-effect)
    * [2.3.2. 카프카 토픽에서 읽어서 DB 에 쓰는 경우](#232-카프카-토픽에서-읽어서-db-에-쓰는-경우)
      * [2.3.2.1. 아웃박스 패턴(outbox pattern)](#2321-아웃박스-패턴outbox-pattern)
    * [2.3.3. DB 에서 읽어서 카프카에 쓰고, 다시 다른 DB 에 쓰는 경우](#233-db-에서-읽어서-카프카에-쓰고-다시-다른-db-에-쓰는-경우)
    * [2.3.4. 한 클러스터에서 다른 클러스터로 데이터 복제](#234-한-클러스터에서-다른-클러스터로-데이터-복제)
    * [2.3.5. 발행/구독 패턴](#235-발행구독-패턴)
  * [2.4. 트랜잭션 사용법](#24-트랜잭션-사용법)
    * [2.4.1. 카프카 스트림즈 사용: `processing.guarantee`](#241-카프카-스트림즈-사용-processingguarantee)
    * [2.4.2. 트랜잭션 API 직접 사용](#242-트랜잭션-api-직접-사용)
  * [2.5. 트랜잭션 ID 와 펜싱](#25-트랜잭션-id-와-펜싱)
  * [2.6. 트랜잭션 작동 원리](#26-트랜잭션-작동-원리)
* [3. 트랜잭션 성능](#3-트랜잭션-성능)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 멱등적 프로듀서(idempotent producer)

동일한 작업을 여러 번 실행해도 한 번 실행한 것과 결과가 같은 서비스를 멱등적(idempotent) 이라고 한다.

카프카에서 프로듀서가 메시지를 전송을 재시도함으로써 메시지 중복이 발생하는 경우의 고전적인 경우는 아래와 같다.
- 파티션 리더가 프로듀서로부터 레코드를 받아서 팔로워들에게 성공적으로 복제함
- 프로듀서에게 응답을 보내기 전에 파티션 리더가 있는 브로커에 크래시가 발생함
- 프로듀서 입장에서는 응답을 받지 못한 채 타임아웃이 발생해서 메시지를 재전송함
- 재전송한 메시지가 새로운 파티션 리더에게 도착하지만 이 메시지는 이미 저장되어 있음(= 결과적으로 중복 발생)

카프카의 멱등적 프로듀서 기능은 자동으로 이러한 중복을 탐지하여 처리한다.

---

## 1.1. 멱등적 프로듀서 작동 원리

**멱등적 프로듀서 기능을 켜면 모든 메시지는 고유한 프로듀서 아이디(PID, producer Id) 와 시퀀스 넘버(sequence ID)** 를 갖게 된다.

**대상 토픽 및 파티션과 위 두 값을 합치면 각 메시지의 고유한 식별자**가 된다.

각 브로커는 해당 브로커에 할당된 모든 파티션들에 쓰여진 마지막 5개의 메시지들을 추적하기 위해 이 고유 식별자를 사용한다.  
파티션별로 추적할 시퀀스 넘버의 수를 제한하고 싶다면 프로듀서의 [`max.in.flight.requests.per.connection`](https://assu10.github.io/dev/2024/06/16/kafka-producer-1/#48-maxinflightrequestsperconnection) 설정값이 5 이하로 잡혀있어야 한다. (기본값은 5)

브로커가 예전에 받은 적이 있는 메시지를 받은 경우 에러를 발생시킴으로써 중복 메시지를 거부한다.  
이 에러는 프로듀서에 로깅도 되고 지표값에도 반영이 되지만 예외가 발생하는 것은 아니기 때문에 사용자에게 경보를 보내지는 않는다.  
프로듀서 클라이언트에서는 `record-error-rate` 지표값을 통해 에러를 확인할 수 있고, 브로커의 경우 `RequestMetrics` 유형의 `ErrorsPerSec` 지표값을 통해 
에러를 확인할 수 있다.

> `RequestMetrics` 에는 유형별 에러 수가 기록됨

브로커가 예상보다 높은 시퀀스 넘버를 받게 되면 브로커는 _out of order sequence number_ 에러를 발생시킨다.

> **_out of order sequence number_ 에러**
> 
> 하지만 **위 에러가 발생한 뒤에도 프로듀서가 정상 동작한다면 이 에러는 보통 프로듀서와 브로커 사이에 메시지 유실이 있었음을 의미**하므로 로그에 위 에러가 찍힌다면 
> 프로듀서와 브로커 설정을 재점검하고, 프로듀서 설정이 고신뢰성을 위해 권장되는 값으로 설정되어 있는지, 아니면 언클린 리더 선출이 발생했는지의 여부를 
> 확인해 볼 필요가 있음

작동이 실패했을 경우 멱등적 프로듀서가 어떻게 처리하는지를 알기 위해 아래 2가지의 장애 상황을 생각해보자.
- 프로듀서 재시작
- 브로커 장애

---

### 1.1.1. 프로듀서 재시작

프로듀서에 장애가 발생할 경우 보통 새로운 프로듀서를 생성하여 장애가 난 프로듀서를 대체한다.  
이 때 쿠버네티스와 같이 자동 장애 복구 기능을 제공하는 프레임워크를 사용할 수도 있다.

중요한 점은 **프로듀서가 시작될 때 멱등적 프로듀서 기능이 켜져있는 경우 프로듀서는 초기화 과정에서 브로커로부터 프로듀서 ID 를 생성받는다**는 점이다.

트랜잭션 기능을 켜지 않았을 경우, 프로듀서를 초기화할 때마다 완전히 새로운 프로듀서 ID가 생성되기 때문에 새로 투입된 프로듀서가 기존 프로듀서가 이미 전송한 
메시지를 재전송할 경우 브로커는 메시지에 중복이 발생했음을 알 수가 없다. (= 두 메시지가 서로 다른 프로듀서 ID 와 시퀀스 넘버를 가지므로 서로 다른 것으로 취급됨)

만일 기존 프로듀서가 작동을 멈췄다가 새로운 프로듀서가 투입된 후 기존 프로듀서가 작동을 재개해도 마찬가지이다.  
서로 다른 프로듀서로 간주되기 때문에 기존 프로듀서는 좀비로 취급되지 않는다.

---

### 1.1.2. 브로커 장애

브로커에 장애가 발생할 경우 [컨트롤러](https://assu10.github.io/dev/2024/06/10/kafka-basic/#25-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%ED%81%B4%EB%9F%AC%EC%8A%A4%ED%84%B0-%EC%BB%A8%ED%8A%B8%EB%A1%A4%EB%9F%AC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%8D%94-%ED%8C%94%EB%A1%9C%EC%9B%8C)는 
해당 브로커가 리더를 맡고 있던 파티션들에 대해 새로운 리더를 선출한다.

![클러스터 안에서의 파티션 복제(구조만 볼 것)](/assets/img/dev/2024/0610/dupl.png)

예) 토픽 A 의 파티션 0 에 메시지를 쓰는 프로듀서가 있음.  
이 파티션의 리더 레플리카는 브로커 5에 있고, 팔로워 레플리카는 브로커 3에 있음  
이 때 브로커 5에 장애가 발생하면 브로커 3이 새로운 리더가 됨  
프로듀서는 [메타데이터 프로토콜](https://assu10.github.io/dev/2024/07/13/kafka-mechanism-1/#4-%EC%9A%94%EC%B2%AD-%EC%B2%98%EB%A6%AC)을 통해 
브로커 3이 새로운 리더임을 알아차리고 거기로 메시지를 쓰기 시작함

이 때 **브로커3은 어느 시퀀스 넘버까지 쓰여졌는데 어떻게 알고 중복 메시지를 걸러내는 걸까?**

리더 레플리카는 새로운 메시지가 쓰여질 때마다 인-메모리 프로듀서 상태에 저장된 최근 5개의 시퀀스 넘버를 업데이트한다.  
팔로워 레플리카는 리더로부터 새로운 메시지를 복제할 때마다 자체적인 인-메모리 버퍼를 업데이트한다.  
즉, 팔로워가 리더가 된 시점에 이미 메모리 안에 최근 5개의 시퀀스 넘버를 가지고 있기 때문에 아무 이슈나 지연없이 새로 쓰여진 메시지의 유효성 검증이 재개될 수 있는 것이다.

**여기서 예전 리더가 다시 돌아온다면 어떻게 될까?**

재시작 후에는 인-메모리 프로듀서 상태는 더 이상 메모리안에 저장되어 있지 않다.  
복구 과정에 사용하기 위해 브로커는 종료되거나 새로운 세그먼트가 생성될 때마다 프로듀서 상태에 대한 스냅샷을 파일 형태로 저장하고, 브로커가 시작되면 일단 파일에서 최신 상태를 읽어온다.  
이후 현재 리더로부터 복제한 레코드를 사용하여 프로듀서 상태를 업데이트함으로써 최신 상태를 복구함으로써 이 브로커가 다시 리더를 맡을 준비가 될 시점에는 최신 
시퀀스 넘버를 가지고 있게 된다.

**만일 브로커가 크래시가 나서 최신 스냅샷이 업데이트되지 않는다면 어떻게 될까?**

프로듀서 ID 와 시퀀스 넘버는 둘 다 카프카 로그에 저장되는 메시지 형식의 일부이다.  
크래시 복구 작업이 진행되는 동안 프로듀서 상태는 더 오래된 스냅샷 뿐 아니라 각 파티션의 최신 세그먼트의 메시지들도 함께 사용하여 복구된다.  
복구 작업이 완료되는대로 새로운 스냅샷 파일이 저장된다.

**만일 메시지가 없다면 어떻게 될까?**

보존 기한이 1시간인데 지난 1시간동안 메시지가 들어오지 않은 토픽이 있다고 해보자.  
이 때 브로커가 크래시가 날 경우 프로듀서 상태를 복구하기 위해 사용할 수 있는 메시지 역시 없을 것이다. 하지만 메시지가 없다는 것은 중복이 없다는 얘기도 되므로 
즉시 새로운 메시지를 받기 시작해서(프로듀서 상태가 없다는 경고는 로그에 찍힘) 새로 들어오는 메시지들을 기준으로 프로듀서 상태를 생성할 수 있다.

---

## 1.2. 멱등적 프로듀서 한계

- **카프카 멱등적 프로듀서는 프로듀서 내부 로직으로 인한 재시도에 대한 중복만 방지함**
  - 동일 메시지를 producer.send() 로 두 번 호출하면 멱등적 프로듀서가 개입하지 않으므로 중복 메시지가 발생함
  - 프로듀서 입장에서는 전송된 레코드 2개가 실제로 동일한 레코드인지 확인할 방법이 없기 때문임
  - **프로듀서 예외를 잡아서 애플리케이션이 직접 재시도하는 것보다 프로듀서에 탑재된 재시도 메커니즘을 사용하는 것이 언제나 더 나음** 
    (멱등적 프로듀서는 이 패턴을 더 편리하게 만들어줌)
- **여러 개의 인스턴스를 띄우거나, 하나의 인스턴스에서 여러 개의 프로듀서를 띄우는 애플리케이션인 경우(이런 경우는 꽤 흔함) 이 프로듀서들 중 2개가 동일한 메시지를 전송하려 할 때 멱등적 프로듀서는 중복을 잡아내지 못함**
  - 이런 경우는 파일 디렉터리와 같은 원본에서 데이터를 읽어서 카프카로 쓰는 애플리케이션에서 꽤 흔함
  - 동일한 파일을 읽어서 카프카에 레코드를 쓰는 2개의 애플리케이션 인스턴스가 뜰 경우 해당 파일의 레코드들은 2번 이상 쓰여지게 됨

**멱등적 프로듀서는 프로듀서 자체의 재시도 메커니즘(프로듀서, 네트워크, 브로커 에러)에 의한 중복만을 방지할 뿐, 그 이상은 하지 못한다.**

---

## 1.3. 멱등적 프로듀서 사용법: `enable.idempotence`

멱등적 프로듀서 활성화는 [`enable.idempotence=true`](https://assu10.github.io/dev/2024/06/16/kafka-producer-1/#411-enableidempotence) 를 추가해주면 끝이다.

> 카프카 3.0 부터는 `enable.idempotence=true` 가 기본값임  
> [KIP-679: Producer will enable the strongest delivery guarantee by default](https://cwiki.apache.org/confluence/display/KAFKA/KIP-679%3A+Producer+will+enable+the+strongest+delivery+guarantee+by+default)
> 
> [`acks`](https://assu10.github.io/dev/2024/06/16/kafka-producer-1/#42-acks) 도 1에서 all 로 기본값이 변경되었기 때문에 가장 강력한 전달 보장이 기본값이 됨

**멱등적 프로듀서를 활성화시키면 아래와 같은 점들이 변경**된다.
- **프로듀서 ID 를 받아오기 위해 프로듀서 시동 과정에서 API 를 하나 더 호출함**
- **전송되는 각각의 레코드 배치에는 프로듀서 ID 와 배치 내 첫 메시지의 시퀀스 넘버가 포함됨**
  - 이 새로운 필드들은 각 메시지 배치에 96 bit 를 추가함 (프로듀서 ID 는 long 타입이고, 시퀀스 넘버는 integer 타입)
  - 따라서 대부분의 경우 작업 부하에 어떠한 오버헤드도 되지 않음
- **브로커들은 모든 프로듀서 인스턴스에서 들어온 레코드 배치의 시퀀스 넘버를 검증해서 메시지 중복을 방지함**
- **장애가 발생하더라도 각 파티션에 쓰여지는 메시지들의 순서는 보장됨**
  - `max.in.flight.requests.per.connection` 설정값이 1보다 큰 값으로 잡혀도 마찬가지임  
    (5는 기본값인 동시에 멱등적 프로듀서가 지원하는 가장 큰 값임)

> 멱등적 프로듀서의 로직 및 에러 처리는 카프카 버전 2.5부터 [KIP-360: Improve reliability of idempotent/transactional producer](https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=89068820) 이 
> 도입되면서 프로듀서/브로커 양쪽 모두에서 크게 개선됨
> 
> **2.5 버전 이전**  
> 프로듀서 상태가 충분히 길게 유지되지 않아 다양한 경우에 있어서 치명적인 _UNKNOWN_PRODUCER_ID_ 에러가 발생하고는 했음  
> (이런 경우의 예는 파티션 재할당 상황에서 발생함, 새로운 리더 입장에서 해당 파티션에 대해 프로듀서 상태 같은 것이 아예 없는 것임)  
> 몇몇 에러 상황에서는 시퀀스 넘버를 변경하기도 했는데, 이것은 메시지 중복을 초래할 수 있었음
> 
> **2.5 버전 이후**  
> 레코드 배치에서 치명적인 에러가 발생할 경우, 에러가 발생한 배치를 포함한 모든 전송 중인 배치들은 거부됨  
> 애플리케이션을 작성하는 입장에서는 발생한 예외를 잡아서 이 레코드들을 건너뛸지, 중복이나 순서 반전의 위험을 감수하고 재시도할 지 결정할 수 있음

---

# 2. 트랜잭션

트랜잭션은 카프카 스트림즈를 사용해서 개발된 애플리케이션의 정확성을 보장하기 위해 도입되었다.  
각 입력 레코드는 정확히 한 번만 처리되어야 하며, 그 처리 결과 역시 장애 상황일지라도 정확히 한 번만 반영이 되어야 한다.  
즉, 카프카 트랜잭션은 정확성이 핵심 요구 조건인 활용 사례에서 스트림 처리 애플리케이션을 사용할 수 있도록 해준다.

카프카의 트랜잭션 기능이 스트림 처리 애플리케이션을 위해 특별히 개발된만큼 카프카 트랜잭션은 스트림 처리 애플리케이션의 기본 패턴인 '읽기-처리-쓰기' 패턴에서 
사용되도록 개발되었다. (각 입력 레코드의 처리는 애플리케이션의 내부 상태가 업데이트되고, 결과가 출력 토픽에 성공적으로 쓰여졌을 때 완료된 것으로 간주)

> 카프카 스트림즈는 '정확히 한 번' 보장을 구현하기 위해 트랜잭션 기능을 사용함

트랜잭션은 정확성이 중요한 스트림 처리 애플리케이션이라면 언제나 도움이 되며, 스트림 처리 로직에 aggregation 이나 조인이 포함되어 있는 경우엔 특히 더 그렇다.

---

## 2.1. 트랜잭션을 사용하지 않을 경우

원본 토픽으로부터 이벤트를 읽어서 처리를 한 다음 결과를 다음 토픽에 쓰는 단순한 스트림 처리 애플리케이션을 생각해보자.

위 상황에서 처리하는 각 메시지에 대해 결과가 정확히 한 번만 쓰여지도록 하고 싶을 때 과연 잘못된 것은 무엇이 있을까?

---

### 2.1.1. 애플리케이션 크래시로 인한 재처리로 중복 발생

원본 클러스터로부터 메시지를 읽어서 처리한 뒤 애플리케이션을 2가지 처리를 해야 한다.

- 결과를 출력 토픽에 쓰기
- 읽어온 메시지의 오프셋 커밋

위 2가지 작업이 순서대로 실행된다고 했을 때 만약 **출력 토픽에는 썼는데 입력 오프셋을 커밋하기 전에 애플리케이션이 크래시가 나면 어떻게 될까?**

[1.2. 컨슈머 그룹과 파티션 리밸런스](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#12-%EC%BB%A8%EC%8A%88%EB%A8%B8-%EA%B7%B8%EB%A3%B9%EA%B3%BC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%B0%B8%EB%9F%B0%EC%8A%A4) 에서 본 것처럼
컨슈머가 크래시가 나면 아래와 같은 일이 벌어진다.

- 몇 초가 지난 후 하트비트가 끊어지면서 리밸런스 발생
- 컨슈머가 읽어오고 있던 파티션들은 다른 컨슈머로 재할당됨
- 컨슈머는 새로 할당된 파티션의 마지막 커밋된 오프셋으로부터 레코드를 읽어오기 시작함
- **즉, 마지막 커밋된 오프셋으로부터 크래시가 난 시점까지, 애플리케이션에 의해 처리된 레코드들은 재처리될 것이며 결과 역시 출력 토픽이 다시 쓰여지게 됨(= 중복 발생)**

---

### 2.1.2. 좀비 애플리케이션에 의해 발생하는 재처리로 중복 발생

**애플리케이션이 카프카로부터 레코드 배치를 읽어온 직후 처리를 하기 전에 멈추거나, 카프카와의 연결이 끊어지면 어떻게 될까?**

하트비트가 끊어지면서 해당 애플리케이션이 죽은 것으로 간주될 것이며, 해당 컨슈머에 할당되어 있던 파티션들은 컨슈머 그룹 내의 다른 컨슈머들에게 재할당될 것이다.  
파티션을 재할당받은 컨슈머가 레코드 배치를 다시 읽어서 처리하고, 출력 토픽에 결과를 쓰고, 작업을 계속 한다.

그 사이에 멈췄던 애플리케이션의 첫 번재 인스턴스가 재작동할 수도 있다.  
즉, 마지막으로 읽어왔던 레코드 배치를 처리하고 결과를 출력 토픽에 쓰는 것이다.  
레코드를 읽어오기 위해 카프카를 새로 폴링하거나, 하트비트를 보냈다가 자기가 죽은 것으로 판정되어 다른 인스턴스들이 현재 해당 파티션들을 할당받은 상태라는 것을 
알아차릴 때까지 이 작업은 계속 될 수 있다.

이렇게 스스로가 죽은 상태인지 모르는 상태를 좀비 상태라고 한다.

이러한 상황에서 **추가적인 보장이 없을 경우, 좀비는 출력 토픽으로 데이터를 쓸 수 있으며 결과적으로 중복된 처리가 발생**할 수 있다.

---

## 2.2. 트랜잭션이 '정확히 한 번'을 보장하는 방법

'정확히 한 번'은 읽기/처리/쓰기 작업이 원자적으로 이루어진다는 의미이다.  
메시지의 오프셋이 커밋되고 결과가 성공적으로 쓰여지거나, 아니면 둘 다 되지 않는 것이다.  
오프셋은 커밋되었는데 결과는 안 쓰여진다던가 처럼 부분적인 결과가 결코 발생하지 않을 것이라는 보장이 필요하다.

**이러한 동작을 지원하기 위해 카프카 트랜잭션은 원자적 다수 파티션 쓰기(atomic multipartition write) 기능을 도입**하였다.  
오프셋을 커밋하는 것과 결과를 쓰는 것은 둘 다 파티션에 메시지를 쓰는 과정을 수반한다는 점에서 착안한 것이다.  
결과는 출력 토픽에, 오프셋은 [`_consumer_offsets`](https://assu10.github.io/dev/2024/06/29/kafka-consumer-2/#1-%EC%98%A4%ED%94%84%EC%85%8B%EA%B3%BC-%EC%BB%A4%EB%B0%8B-__consumer_offsets) 토픽에 
쓰여진 다는 점이 다를 뿐이다.

트랜잭션을 시작해서 출력 토픽과 `_consumer_offsets` 토픽 둘 다에 메시지를 쓰고, 둘 다 성공해서 커밋할 수 있다면 그 다음부터는 '정확히 한 번' 이 알아서 해준다.

아래는 읽어온 이벤트의 오프셋을 커밋함과 동시에 2개의 파티션(파티션 0,1)에 원자적 다수 파티션 쓰기를 수행하는 간단한 스트림 처리 애플리케이션이다.

![트랜잭션적 프로듀서와 여러 파티션에 대한 원자적 쓰기](/assets/img/dev/2024/0818/atomic.png)

---

### 2.2.1. 트랜잭션적 프로듀서: `transactional.id`

트랜잭션을 사용해서 원자적 다수 파티션 쓰기를 하려면 **트랜잭션적 프로듀서**를 사용해야 한다.

**트랜잭션적 프로듀서와 일반 프로듀서의 차이점**은 아래와 같다.
- `transactional.id` 설정이 잡혀 있음
- `initTransactions()` 를 호출하여 초기화해줌

브로커에 의해 자동 생성되는 `producer.id` 와 달리 `transactional.id` 는 프로듀서 설정의 일부이며, 프로듀서가 재시작하더라도 값이 유지된다.

**`transactional.id` 의 주용도는 재시작 후에도 동일한 프로듀서를 식별하는 것**이다.  
브로커는 `transactional.id` 에서 `producer.id` 로의 대응 관계를 유지하고 있다가 만약 이미 있는 `transactional.id` 프로듀서가 `initTransactions()` 를 
다시 호출하면 새로운 랜덤값이 아닌 기존에 쓰던 `producer.id` 를 할당해준다.

---

### 2.2.2. 좀비 펜싱

애플리케이션의 좀비 인스턴스가 중복 프로듀서를 생성하는 것을 방지하는 방법은 2가지가 있다.
- 좀비 펜싱
- 애플리케이션의 좀비 인스턴스가 출력 스트림에 결과를 쓰는 것을 방비

일반적인 **좀비 펜싱 방법으로는 에포크(epoch) 를 사용**하는 방식이 사용된다.

카프카는 트랜잭션적 프로듀서가 초기화를 위해 `initTransactions()` 를 호출하면 `transactional.id` 에 해당하는 에포크 값을 증가시킨다.  
같은 `transactional.id` 를 갖고 있지만 에포트 값이 낮은 프로듀서가 메시지를 전송하거나 트랜잭션 커밋/중단 요청을 보낼 경우 _FenceProducer_ 에러를 발생시키면서 거부한다.  
이렇게 오래된 프로듀서는 출력 스트림을 쓰는 것이 불가능하기 때문에 `close()` 를 호출해서 닫아주는 것 외에는 방법이 없다. (= 좀비 인스턴스가 중복 레코드를 쓰는 것이 불가능함)

카프카 2.5 버전 이후부터 트랜잭션 메타데이터에 컨슈머 그룹 메타데이터를 추가할 수 있는 옵션이 추가되었다.  
이 메타데이터 역시 펜싱에 사용되기 때문에 좀비 인스턴스를 펜싱하면서도 서로 다른 트랜잭션 ID 를 갖는 프로듀서들이 같은 파티션들에 레코드를 쓸 수 있게 되었다.

---

### 2.2.3. 트랜잭션을 위한 컨슈머 설정: `isolation.level`

트랜잭션은 대부분 프로듀서 쪽 기능이다.  
트랜잭션적 프로듀서를 생성하고, 트랜잭션을 시작하고, 다수의 파티션에 레코드를 쓰고, 이미 처리된 레코드들을 표시하기 위해 오프셋을 쓰고, 트랜잭션을 커밋/중단하는 
모든 작업들은 프로듀서로부터 이루어진다.

하지만 트랜잭션 기능을 이용해서 쓰여진 레코드를 비록 결과적으로 중단된 트랜잭션에 속할지라도 다른 레코드와 마찬가지로 파티션에 쓰여진다.  
즉, 컨슈머의 올바른 격리 수준이 설정되어 있지 않으면 '정확히 한 번' 보장은 이루어지지 않는다.

> isolation 에 대한 내용은 [3. `@Transactional` 의 `isolation` 속성](https://assu10.github.io/dev/2023/09/10/springboot-database-4/#3-transactional-%EC%9D%98-isolation-%EC%86%8D%EC%84%B1) 을 참고하세요.

**컨슈머에서는 `isolation.level` 설정을 통해 트랜잭션 기능을 써서 쓰여진 메시지들을 읽어오는 방식을 제어**할 수 있다.

- **`read_committed`**
  - 토픽들을 구독한 뒤 `consumer.poll()` 을 호출하면 커밋된 트랜잭션에 속한 메시지나 처음부터 트랜잭션에 속하지 않은 메시지만 리턴함
  - 중단된 트랜잭션에 속한 메시지나 아직 진행중인 트랜잭션에 속하는 메시지는 리턴하지 않음
- **`read_uncommitted` (기본값)**
  - 진행중이거나 중단된 트랜잭션에 속하는 메시지를 포함하여 모든 레코드들 리턴

**`read_committed` 로 설정한다고 해서 특정 트랜잭션에 속한 모든 메시지가 리턴된다고 보장되는 것도 아니다.**  
트랜잭션에 속하는 토픽의 일부만 구독했기 때문에 일부 메시지만 리턴받을 수도 있다.  
애플리케이션은 트랜잭션이 언제 시작되고 끝날지, 어느 메시지가 어느 트랜잭션에 속하는지에 대해서는 알 수 없다.

![read_committed vs read_uncommitted](/assets/img/dev/2024/0818/consumer.png)

위 그림을 보면 `read_committed` 모드로 작동 중인 컨슈머는 `read_uncommitted` 모드로 작동 중인 컨슈머보다 더 뒤에 있는 메시지를 읽는다.

메시지의 읽기 순서를 보장하기 위해 `read_committed` 모드에서는 아직 진행중인 트랜잭션이 처음으로 시작된 시점 LSO(Last Stable Offset) 이후에 쓰여진 메시지를 리턴되지 않는다.  
LSO 이후에 쓰여진 메시지들은 트랜잭션이 프로듀서에 의해 커밋/중단될 때까지, 혹은 `transaction.timeout.ms` (기본값 15분) 만큼 시간이 지나 브로커가 트랜잭션을 
중단시킬 때까지 보류된다.  
이렇게 트랜잭션이 오랫동안 닫히지 않고 있으면 컨슈머들이 지체되면서 종단 지연이 길어진다.

---

**스트림 처리 애플리케이션은 입력 토픽이 트랜잭션 없이 쓰여졌을 경우에도 '정확히 한 번' 출력을 보장**한다.  
원자적 다수 파티션 쓰기 기능은 만일 출력 레코드가 출력 토픽에 커밋되었을 경우, 입력 레코드의 오프셋 역시 해당 컨슈머에 대해 커밋되는 것을 보장하므로 입력 레코드는 
재처리되지 않는다.

---

## 2.3. 트랜잭션이 해결하지 못하는 문제

트랜잭션 기능은 다수의 파티션에 대한 원자적 쓰기(읽기가 아님)를 제공하고, 스트림 처리 애플리케이션에서 좀비 프로듀서를 방지하기 위해 추가되었다.  
즉, **읽기/처리/쓰기 스트림 처리 작업에서 사용될 때 '정확히 한 번' 처리가 보장**된다.

**트랜잭션 기능과 관련하여 흔히 하는 실수**는 2가지가 있다.
- '정확히 한 번' 보장이 카프카에 대한 '쓰기' 이외에도 보장된다고 착각하는 경우
- 컨슈머가 항상 전체 트랜잭션을 읽어온다고(= 트랜잭션 간의 경계에 대해 알고 있다고) 착각하는 경우

여기서는 카프카의 트랜잭션 기능이 '정확히 한 번' 을 보장하지 못하는 경우에 대해 알아본다.

---

### 2.3.1. 스트림 처리에 있어서의 side effect

스트림 처리 애플리케이션의 처리 단계에 이메일을 보내는 작업이 있다고 하자.

이 애플리케이션에서 '정확히 한 번' 의 기능을 활성화한다고 해서 이메일이 한 번만 발송되는 것은 아니다.

**카프카의 '정확히 한 번' 기능은 카프카에 쓰여지는 레코드에만 적용**된다.  
**레코드 중복을 방지하기 위해 시퀀스 넘버를 사용하는 것이건, 트랜잭션 중단/취소를 위해 마커를 사용하는 것은 카프카 안에서만 작동하는 것이지 이메일 발송을 취소시킬 수 있는 것은 아니다.**

이는 스트림 처리 애플리케이션 안에서 외부 효과를 일으키는 REST API 호출, 파일 쓰기 등도 해당된다.

---

### 2.3.2. 카프카 토픽에서 읽어서 DB 에 쓰는 경우

이 애플리케이션은 카프카가 아닌 외부 DB 에 결과물을 쓴다.  
여기서는 프로듀서가 사용되지 않는다.  
즉, 레코드는 JDBC 와 같은 DB 드라이버를 통해 DB 에 쓰여지고, 오프셋은 컨슈머에 의해 카프카에 커밋된다.

**하나의 트랜잭션에서 외부 DB 에는 결과를 쓰고 카프카에는 오프셋을 커밋할 수 있도록 해주는 메커니즘은 없다.**

대신, 오프셋을 DB 에 저장하도록 할 수는 있다.  
이렇게 하면 하나의 트랜잭션에서 데이터와 오프셋을 동시에 DB 에 커밋할 수 있다. (이 부분은 카프카가 아닌 DB 의 트랜잭션 보장에 달림)

---

#### 2.3.2.1. 아웃박스 패턴(outbox pattern)

**MSA 에서 하나의 원자적 트랜잭션 안에서 DB 도 업데이트하고, 카프카에 메시지도 써야 하는 경우**가 종종 있다. (둘 다 성공하던지, 둘 다 안되던지)  
카프카 트랜잭션은 이러한 작업은 해주지 않는다.

이럴 때 일반적인 **해법은 아웃박스 패턴**을 이용하는 것이다.

MSA 는 아웃박스라고 불리는 카프카 토픽에 메시지를 쓰는 작업까지만 하고, 별도의 메시지 중계 서비스가 카프카로부터 메시지를 읽어와서 DB 에 업데이트를 한다.  
카프카가 DB 업데이트에 대해 '정확히 한 번' 을 보장하지 않으므로 업데이트 작업은 반드시 멱등적이어야 한다.  
**아웃박스 패턴을 사용하면 결과적으로 메시지가 카프카, 토픽 컨슈머, DB 모두에서 사용 가능하거나, 셋 중 어디에도 쓰이지 않는다.**

위의 패턴을 반전시켜서 DB 를 아웃박스로 사용하고, 릴레이 서비스가 테이블 업데이트 내역을 카프카에 메시지로 쓰게 할 수도 있다.  
(UK 나 FK 같이 RDBMS 에 제약이 적용되어야 할 때 유용함)

> 디비지움 프로젝트 블로그의 [Reliable Microservices Data Exchange With the Outbox Pattern](https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/) 에서 상세한 예제를 볼 수 있다.

---

### 2.3.3. DB 에서 읽어서 카프카에 쓰고, 다시 다른 DB 에 쓰는 경우

한 애플리케이션에서 DB 데이터를 읽어서 트랜잭션을 구분하고, 카프카에 레코드를 쓰고, 다시 다른 DB 에 레코드를 쓰고, 이 와중에 원본 데이터의 원래 트랜잭션을 
관리할 수 있다면 참 좋겠지만 카프카 트랜잭션은 이러한 종단 보장에 필요한 기능은 없다.

하나의 트랜잭션 안에서 레코드와 오프셋을 함께 커밋하는 문제 외에 다른 문제가 있기 때문이다.

카프카 컨슈머의 `read_committed` 보장은 DB 트랜잭션을 보장하기엔 부족하다.  
컨슈머가 아직 커밋되지 않은 레코드를 볼 수 없는 건 맞지만, 일부 토픽에서 lag 이 발생했을 경우 이미 커밋된 트랜잭션의 레코드를 모두 봤을 거라는 보장이 없기 때문이다.

트랜잭션의 경계도 알 수 없기 때문에 언제 트랜잭션이 시작되고, 끝나고, 레코드 중 어디까지를 읽었는지도 알 수 없다.

---

### 2.3.4. 한 클러스터에서 다른 클러스터로 데이터 복제

하나의 카프카 클러스터에서 다른 클러스터로 데이터를 복사할 때 '정확히 한 번'을 보장할 수 있다.

> 위 내용이 어떻게 가능한지에 대해서는 [KIP-656: MirrorMaker2 Exactly-once Semantics](https://cwiki.apache.org/confluence/display/KAFKA/KIP-656%3A+MirrorMaker2+Exactly-once+Semantics) 참고
> 
> KIP-656 에는 원본 클러스터의 각 레코드가 대상 클러스터에 정확히 한 번 복사될 것을 보장하는 내용이 있음

하지만 이것이 트랜잭션의 원자성을 보장하지는 않는다.  
만약 애플리케이션이 여러 개의 레코드와 오프셋을 트랜잭션적으로 쓰고, 미러메이커 2.0이 이 레코드들을 다른 카프카 클러스터에 복사한다면 복사 과정에서 트랜잭션 속성 등은 유실된다.  
컨슈머 입장에서는 트랜잭션의 모든 데이터를 읽어왔는지 알 수 없고 보장할 수도 없다.  
예) 토픽의 일부만 구독할 경우 전체 트랜잭션의 일부만 복사할 수 있음

---

### 2.3.5. 발행/구독 패턴

`read_committed` 모드가 설정된 컨슈머들은 중단된 트랜잭션에 속한 레코드들은 보지 못한다.  
하지만 이러한 보장은 오프셋 커밋 로직에 따라 컨슈머들이 메시지를 한 번 이상 처리할 수 있으므로 '정확히 한 번' 을 보장하지는 못한다.

카프카가 보장하는 것은 JMS(Java Message Service) 트랜잭션에서 보장하는 것과 비슷하지만, 커밋되지 않은 트랜잭션들이 보이지 않도록 컨슈머들에게 
`read_committed` 설정이 있어야 한다는 전제 조건이 붙는다.  
위 조건이 있으면 JMS 브로커들은 모든 컨슈머에게 커밋되지 않은 트랜잭션의 레코드를 주지 않는다.

**메시지를 쓰고 나서 커밋하기 전에 다른 애플리케이션이 응답하기를 기다리는 패턴은 반드시 피해야 한다.**  
다른 애플리케이션은 트랜잭션이 커밋될 때까지 메시지를 받지 못할 것이기 때문에 결과적으로 데드락이 발생한다.

---

## 2.4. 트랜잭션 사용법

### 2.4.1. 카프카 스트림즈 사용: `processing.guarantee`

트랜잭션은 브로커의 기능이기도 하다.

**트래잭션 기능을 사용하는 가장 일반적이고 권장되는 방법은 카프카 스트림즈에서 `exactly_once` 보장을 활성화하는 것**이다.  
이렇게 하면 트랜잭션 기능을 직접적으로 사용하지 않고도 카프카 스트림즈가 대신 해당 기능을 사용하여 정확히 한 번의 보장을 해준다.  
카프카 스트림즈를 통한 간접 사용은 가장 쉬우면서도 예상하는 결과를 얻을 가능성이 높은 방법이다.

**카프카 스트림즈 애플리케이션에서 '정확히 한 번' 보장 기능을 활성화하는 방법은 `processing.guarantee` 설정을 `exactly_once` 혹은 `exactly_once_beta` 로 설정**해주면 끝이다.

> **`exactly_once_beta`**
> 
> `exactly_once_beta` 는 크래시가 나거나 트랜잭션 전송 중에 멈춘 애플리케이션 인스턴스를 처리하는 방식이 조금 다름  
> 이 기능은 카프카 브로커에서는 2.5, 카프카 스트림즈에서는 2.6 에 도입됨
> 
> `exactly_once_beta` 을 사용하면 하나의 트랜잭션적 프로듀서에서 더 많은 파티션을 효율적으로 다룰 수 있게 되고, 그로 인해 카프카 스트림즈 애플리케이션의 확장성이 향상됨
> 
> [KIP-447: Producer scalability for exactly once semantics](https://cwiki.apache.org/confluence/display/KAFKA/KIP-447%3A+Producer+scalability+for+exactly+once+semantics)

---

### 2.4.2. 트랜잭션 API 직접 사용

카프카 스트림즈를 사용하지 않고 '정확히 한 번' 을 보장하고 싶다면 트랜잭션 API 를 직접 사용하면 된다.

> 아파치 카프카의 전체 예제는 [Git:: Kafka Example](https://github.com/apache/kafka/tree/trunk/examples) 에 있음
> 
> 이번 내용의 전체 예시는 아래 참고  
> - [데모 드라이버(KafkaExactlyOnceDemo.java)](https://github.com/apache/kafka/blob/trunk/examples/src/main/java/kafka/examples/KafkaExactlyOnceDemo.java)
> - [별개의 스레드에서 돌아가는 '정확히 한 번' 프로세서(ExactlyOnceMessageProcessor.java)](https://github.com/apache/kafka/blob/trunk/examples/src/main/java/kafka/examples/ExactlyOnceMessageProcessor.java)

'정확히 한 번' 프로세서
```java
package com.assu.study.chap08;

import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.KafkaException;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.InvalidProducerEpochException;
import org.apache.kafka.common.errors.ProducerFencedException;

/** 읽기-처리-쓰기 애플리케이션 */
public class ExactlyOnceMessageProcessor extends Thread {
  private final String transactionalId;
  private final KafkaProducer<Integer, String> producer;
  private final KafkaConsumer<Integer, String> consumer;
  private final String inputTopic;
  private final String outTopic;

  public ExactlyOnceMessageProcessor(String threadName, String inputTopic, String outTopic) {
    this.transactionalId = "tid-" + threadName;
    this.inputTopic = inputTopic;
    this.outTopic = outTopic;

    Properties producerProps = new Properties();
    producerProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    producerProps.put(ProducerConfig.CLIENT_ID_CONFIG, "DemoProducer"); // client.id

    // 프로듀서에 transactional.id 를 설정해줌으로써 다수의 파티션에 대해 원자적 쓰기가 가능한 트랜잭션적 프로듀서 생성
    // 트랜잭션 ID 는 고유하고, 오랫동안 유지되어야 함
    producerProps.put(
        ProducerConfig.TRANSACTIONAL_ID_CONFIG, this.transactionalId); // transactional.id

    producer = new KafkaProducer<>(producerProps);

    Properties consumerProps = new Properties();
    consumerProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
    consumerProps.put(ConsumerConfig.GROUP_ID_CONFIG, "DemoGroupId"); // group.id

    // 트랜잭션의 일부가 되는 컨슈머는 오프셋을 직접 커밋하지 않으며, 프로듀서가 트랜잭션 과정의 일부로써 오프셋을 커밋함
    // 따라서 오프셋 커밋 기능은 꺼야 함
    consumerProps.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false"); // enable.auto.commit

    // 이 예시에서 컨슈머는 입력 토픽을 읽어옴
    // 여기서는 입력 토픽의 레코드들 역시 트랜잭션적 프로듀서에 의해 쓰였다고 가정함
    // 진행중이거나 실패한 트랙잭션들은 무시하기 위해 컨슈머 격리 수준을 read_committed 로 설정
    // 컨슈머는 커밋된 트랜잭션 외에도 비 트랜잭션적 쓰기 역시 읽어온다는 것을 유념할 것
    consumerProps.put(ConsumerConfig.ISOLATION_LEVEL_CONFIG, "read_committed"); // isolation.level

    consumer = new KafkaConsumer<>(consumerProps);
  }

  @Override
  public void run() {
    // 트랜잭션적 프로듀서 사용 시 가장 먼저 할 일은 초기화 작업
    // 이것은 트랜잭션 ID 를 등록하고, 동일한 트랜잭션 ID 를 갖는 다른 프로듀서들이 좀비로 인식될 수 있도록 에포크 값을 증가시킴
    // 같은 트랜잭션 ID 를 사용하는, 아직 진행중인 트랜잭션들 역시 중단됨
    producer.initTransactions();

    // subscribe() 컨슈머 API 사용
    // 이 애플리케이션 인스턴스에 할당된 파티션들은 언제든지 리밸런스의 결과로서 변경될 수 있음
    // subscribe() 는 트랜잭션에 컨슈머 그룹 정보를 추가하고, 이를 사용하여 좀비 펜싱을 수행함
    // subscribe() 를 사용할 때는 관련된 파티션이 할당 해제될 때마다 트랜잭션을 커밋해주는 것이 좋음
    consumer.subscribe(Collections.singleton(inputTopic));

    while (true) {
      try {
        ConsumerRecords<Integer, String> records = consumer.poll(Duration.ofMillis(200));
        if (records.count() > 0) {
          // 레코드를 읽어왔으니 처리하여 결과를 생성함
          // beginTransaction() 은 호출된 시점부터 트랜잭션이 종료(커밋/중단)되는 사이 쓰여진 모든 레코드들이 하나의 원자적 트랜잭션의 일부임을 보장함
          producer.beginTransaction();

          for (ConsumerRecord<Integer, String> record : records) {
            // 레코드를 처리해주는 곳
            // 모든 비즈니스 로직이 여기 들어감
            ProducerRecord<Integer, String> customizedRecord = transform(record);
            producer.send(customizedRecord);
          }

          Map<TopicPartition, OffsetAndMetadata> offsets = getOffsetsToCommit(consumer);

          // 트랜잭션 작업 도중에 오프셋을 커밋해주는 것이 중요함
          // 결과 쓰기에 실패하더라도 처리되지 않은 레코드 오프셋이 커밋되지 않도록 보장해줌
          // 다른 방식으로 오프셋을 커밋하면 안된다는 점을 유의해야 함
          // 자동 커밋 기능은 끄고, 컨슈머의 커밋 API 도 호출하지 않아야 함
          // 다른 방식으로 오프셋을 커밋할 경우 트랜잭션 보장이 적용되지 않음
          producer.sendOffsetsToTransaction(getOffsetsToCommit(consumer), consumer.groupMetadata());

          // 필요한 메시지를 모두 쓰고 오프셋을 커밋했으니 이제 트랜잭션을 커밋하고 작업을 마무리함
          // 이 메서드가 성공적으로 리턴하면 전체 트랜잭션이 완료된 것임
          // 이제 다음 이벤트 배치를 읽어와서 처리해주는 작업을 계속할 수 있음
          producer.commitTransaction();
        }
      } catch (ProducerFencedException | InvalidProducerEpochException e) {
        // 이 예외가 발생한다면 현재의 프로세서가 좀비가 된 것임
        // 애플리케이션이 처리를 멈췄든 연결이 끊어졌든 같은 트랜잭션 ID 를 갖는 애플리케이션의 새로운 인스턴스가 실행되고 있을 것임
        // 여기서 시작한 트랜잭션은 이미 중단되었고, 어디선가 그 레코드들을 대신 처리하고 있을 가능성이 높음
        // 이럴 땐 이 애플리케이션을 종료하는 것 외엔 할 수 있는 조치가 없음
        throw new KafkaException(
            String.format("The transactional.id %s is used by another process", transactionalId));
      } catch (KafkaException e) {
        // 트랜잭션을 쓰는 도중에 엥러가 발생한 경우 트랜잭션을 중단시키고 컨슈머의 오프셋 위치를 뒤로 돌린 후 재시도함
        producer.abortTransaction();
        resetToLastCommittedPositions(consumer);
      }
    }
  }

  // 레코드를 처리해주는 곳
  // 모든 비즈니스 로직이 여기 들어감
  private ProducerRecord<Integer, String> transform(ConsumerRecord<Integer, String> record) {
    return new ProducerRecord<>(outTopic, record.key(), record.value() + "-ok");
  }

  private Map<TopicPartition, OffsetAndMetadata> getOffsetsToCommit(
      KafkaConsumer<Integer, String> consumer) {
    Map<TopicPartition, OffsetAndMetadata> offsets = new HashMap<>();
    for (TopicPartition topicPartition : consumer.assignment()) {
      offsets.put(topicPartition, new OffsetAndMetadata(consumer.position(topicPartition), null));
    }
    return offsets;
  }

  private void resetToLastCommittedPositions(KafkaConsumer<Integer, String> consumer) {
    Map<TopicPartition, OffsetAndMetadata> committed = consumer.committed(consumer.assignment());
    consumer
        .assignment()
        .forEach(
            tp -> {
              OffsetAndMetadata offsetAndMetadata = committed.get(tp);
              if (offsetAndMetadata != null) {
                consumer.seek(tp, offsetAndMetadata.offset());
              } else {
                consumer.seekToBeginning(Collections.singleton(tp));
              }
            });
  }
}
```

---

## 2.5. 트랜잭션 ID 와 펜싱

---

## 2.6. 트랜잭션 작동 원리

---

# 3. 트랜잭션 성능


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [KIP-679: Producer will enable the strongest delivery guarantee by default](https://cwiki.apache.org/confluence/display/KAFKA/KIP-679%3A+Producer+will+enable+the+strongest+delivery+guarantee+by+default)
* [KIP-360: Improve reliability of idempotent/transactional producer](https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=89068820)
* [Blog:: 트랜잭셔널 아웃박스 패턴](https://rudaks.tistory.com/entry/%EC%84%B1%EB%8A%A5-%ED%8C%A8%ED%84%B4-%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%94%EB%84%90-%EC%95%84%EC%9B%83%EB%B0%95%EC%8A%A4Transactional-Outbox-%ED%8C%A8%ED%84%B4)
* [Blog:: Reliable Microservices Data Exchange With the Outbox Pattern](https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/)
* [KIP-656: MirrorMaker2 Exactly-once Semantics](https://cwiki.apache.org/confluence/display/KAFKA/KIP-656%3A+MirrorMaker2+Exactly-once+Semantics)
* [KIP-447: Producer scalability for exactly once semantics](https://cwiki.apache.org/confluence/display/KAFKA/KIP-447%3A+Producer+scalability+for+exactly+once+semantics)