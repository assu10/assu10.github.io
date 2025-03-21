---
layout: post
title:  "Kafka - 모니터링: 지표, SLO, 브로커 지표, 클라이언트 모니터링, lag 모니터링"
date: 2024-09-28
categories: dev
tags: kafka monitoring
---

이 포스트에서는 브로커와 클러스터의 상태를 모니터링 하는 방법과 카프카가 제대로 동작하고 있는지 확인하는 방법에 대해 알아본다.  
또한 프로듀서와 컨슈머를 포함하는 클라이언트를 모니터링하는 방법 역시 알아본다.

- 항상 모니터링할 필요가 있는 중요한 지표
- 이 지표값에 대해 어떻게 대응해야 하는지?
- 디버깅할 때 살펴봐야 하는 좀 더 중요한 지표

---

**목차**

<!-- TOC -->
* [1. 지표 기초](#1-지표-기초)
  * [1.1. 지표 위치](#11-지표-위치)
    * [1.1.1. 비(非) 애플리케이션 지표](#111-비非-애플리케이션-지표)
  * [1.2. 지표 종류](#12-지표-종류)
    * [1.2.1. 경보 vs 디버깅](#121-경보-vs-디버깅)
    * [1.2.2. 자동화 vs 사람이 모니터링](#122-자동화-vs-사람이-모니터링)
* [2. 서비스 수준 목표(SLO, Service-Level Objective)](#2-서비스-수준-목표slo-service-level-objective)
  * [2.1. 서비스 수준 정의](#21-서비스-수준-정의)
  * [2.2. 좋은 서비스 수준 지표(SLI)를 위한 지표값](#22-좋은-서비스-수준-지표sli를-위한-지표값)
  * [2.3. 경보에 SLO 사용](#23-경보에-slo-사용)
* [3. 카프카 브로커 지표](#3-카프카-브로커-지표)
  * [3.1. 클러스터 문제 진단](#31-클러스터-문제-진단)
  * [3.2. 불완전 복제 파티션(URP, Under-Replication Partition) 다루기](#32-불완전-복제-파티션urp-under-replication-partition-다루기)
    * [3.2.1. 클러스터 수준의 문제](#321-클러스터-수준의-문제)
  * [3.3. 브로커 지표](#33-브로커-지표)
    * [3.3.1. 활성 컨트롤러 수: `ActiveControllerCount`](#331-활성-컨트롤러-수-activecontrollercount)
    * [3.3.2. 컨트롤러 큐 크기: `EventQueueSize`](#332-컨트롤러-큐-크기-eventqueuesize)
    * [3.3.3. 요청 핸들러 유휴 비율: `RequestHandlerAvgIdlePercent`](#333-요청-핸들러-유휴-비율-requesthandleravgidlepercent)
    * [3.3.4. 전 토픽 바이트 인입: `BytesInPerSec`](#334-전-토픽-바이트-인입-bytesinpersec)
    * [3.3.5. 전 토픽 바이트 유출: `BytesOutPerSec`](#335-전-토픽-바이트-유출-bytesoutpersec)
    * [3.3.6. 전 토픽 메시지 인입: `MessageInPerSec`](#336-전-토픽-메시지-인입-messageinpersec)
    * [3.3.7. 파티션 수: `PartitionCount`](#337-파티션-수-partitioncount)
    * [3.3.8. 리더 수: `LeaderCount`](#338-리더-수-leadercount)
    * [3.3.9. 오프라인 파티션: `OfflinePartitionsCount`](#339-오프라인-파티션-offlinepartitionscount)
  * [3.4. 토픽과 파티션별 지표](#34-토픽과-파티션별-지표)
    * [3.4.1. 토픽별 지표](#341-토픽별-지표)
    * [3.4.2. 파티션별 지표](#342-파티션별-지표)
  * [3.5. 운영체제 모니터링](#35-운영체제-모니터링)
  * [3.6. 로깅](#36-로깅)
* [4. 클라이언트 모니터링](#4-클라이언트-모니터링)
  * [4.1. 프로듀서 지표](#41-프로듀서-지표)
    * [4.1.1. 프로듀서 종합 지표](#411-프로듀서-종합-지표)
  * [4.2. 컨슈머 지표](#42-컨슈머-지표)
    * [4.2.1. 읽기 매니저(fetch manager) 지표](#421-읽기-매니저fetch-manager-지표)
    * [4.2.2. 컨슈머 코디네이터 지표](#422-컨슈머-코디네이터-지표)
  * [4.3. 쿼터](#43-쿼터)
* [5. lag 모니터링](#5-lag-모니터링)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 지표 기초

카프카 브로커와 클라이언트가 제공하는 지표들을 보기 전에 자바 애플리케이션 모니터링의 기본적인 사항들과 모니터링, 경보 설정의 모범 사례에 대해 알아본다.

---

## 1.1. 지표 위치

카프카의 모든 지푯값은 자바 관리 확장(JMX, Java Management Extensions) 인터페이스를 통해 사용 가능하다.

외부 모니터링 시스템 입장에서 이를 사용하는 가장 쉬운 방법은 해당 모니터링 시스템에서 제공하는 메트릭 수집 에이전트를 카프카 프로세스에 붙이는 것이다.
- JMX 인터페이스에 접속하는 시스템 내 별도 프로세스
  - 예) Nagios XI 의 check_jms 플러그인, jmxtrans
- 카프카 프로세스에서 직접 실행되는 JMX 에이전트를 사용하여 HTTP 연결을 통해 지푯값을 받아옴
  - 예) Jolokia, MX4J

자바 애플리케이션 모니터링 경험이 없다면 모니터링 서비스를 이용하는 것도 좋다.

---

### 1.1.1. 비(非) 애플리케이션 지표

<**카프카 브로커를 모니터링할 때 볼 수 있는 지표의 종류**>

| 종류          | 설명                                                             |
|:------------|:---------------------------------------------------------------|
| 애플리케이션 지표   | 카프카 자체의 JMX 인터페이스에서 나온 지표                                      |
| 로그          | 카프카 자체에서 나온 또 다른 타입의 모니터링 데이터                                  |
| 인프라스트럭처 지표  | 개발자가 제어할 수 있는 시스템에서 발생하는 지표<br />예) 로드 밸런서                     |
| 특수 클라이언트 지표 | 카프카 외부 툴에서 나온 데이터<br />예) 카프카 모니터(Kafka Monitor)와 같은 외부 모니터링 툴 |
| 일반 클라이언트 지표 | 카프카 클러스터에 접속한 카프카 클라이언트로부터 나온 지표                               |

카프카에 대해 알아갈수록 애플리케이션이 어떻게 동작하고 있는지 온전히 이해하기 위해서는 이러한 지표 출처들이 중요해진다.  
예를 들어 처음엔 브로커 지표에만 의존해도 충분하겠지만, 나중에는 카프카가 어떻게 돌아가는지 목적성을 갖는 값들을 원하게 될 것이다.  
예) 웹사이트 상태 모니터링의 경우 웹 서버가 제대로 작동중이고 모든 수집된 지푯값이 정상이지만, 웹 서버와 외부 사용자 간의 네트워크에 문제가 발생해서 모든 요청이 
웹 서버에 도달할 수 없을 경우를 대비하여 외부 네트워크에서 웹 사이트 접근 여부를 모니터링하는 특수 클라이언트 지표에 대해 경보 설정을 함

---

## 1.2. 지표 종류

어느 지표가 중요한 지에 대한 대답은 아래에 따라 달라진다.
- 의도가 무엇인지?
- 데이터를 수집하는데 사용되는 툴은 무엇인지?
- 카프카를 얼마나 사용해봤는지?
- 카프카를 둘러싼 인프라스트럭처를 구축하는데 엉ㄹ마나 시간을 쓸 수 있는가?

예를 들면 브로커 내부를 개발하는 사람이 필요한 지표와 카프카를 설치하고 운영하는 사이트 신뢰성 엔지니어(SRE, Site Reliability Engineer) 가 필요한 지표는 서로 다르다.

---

### 1.2.1. 경보 vs 디버깅

**경보를 보내기 위한 지표**는 문제 발생 시 빠르게 대응할 수 있도록 짧은 시간 간격으로 설정하는 것이 좋다.  
이는 시스템 장애가 성능 저하게 대한 실시간 대응을 가능하게 하며, 서비스 가용성을 보장하는데 도움이 된다.  
자동화된 경보 시스템은 Prometheus + Alertmanager, Grafana 등의 도구를 활용하면 효율성을 높일 수 있다.

<**짧은 시간 간격이 중요한 이유**>
- **문제 감지 속도 향상**
  - 긴 시간 간격을 사용하면 문제 발생 후 경보가 너무 늦게 발생할 수 있음
- **빠른 대응 가능**
  - 짧은 간격으로 모니터링하면 장애 발생 시 즉각적인 조치 가능
- **운영 비용 절감**
  - 장애 대응 시간이 짧아지면 서비스 다운타임을 줄일 수 있어 비용이 절감됨

<**카프카에서 유용한 경보용 지표**>

|             지표              | 설명                           | 추천 경보 조건              |
|:---------------------------:|:-----------------------------|:----------------------|
| Under-replicated Partitions | 리더보다 뒤처진 레플리카가 있는 파티션 개수     | 값 > 0 (즉각 경보)         |
|        Consumer Lag         | 컨슈머 그룹이 최신 메시지를 얼마나 늦게 소비하는지 | lag > 임계값 (예: 10,000) |
|  Offline Partitions Count   | 오프라인 상태가 된 파티션 개수            | 값 > 0 (즉각 경보)         |
|   Active Controller Count   | 활성 컨트롤러 개수                   | 값 != 1 (즉각 경보)        |
|      Broker CPU Usage       | 브로커의 CPU 사용률                 | CPU > 80% (30초 이상 지속) |
|         Disk Usage          | 브로커의 디스크 사용량                 | 사용량 > 90%             |
|    Network Request Rate     | 네트웤 요청수                      | 급격한 증가 혹은 감소          |


**디버깅이 목적인 지표**는 일정 시간 동안 존재하는 문제의 원인을 자주 진단해야 안다든가 등의 이유로 시간 범위가 긴 경향이 있다.  
디버깅용 데이터는 수집된 뒤 며칠 혹은 몇 주가 지난 뒤에도 사용이 가능해야 한다.  
디버깅용 데이터는 수집한 뒤 꼭 모니터링 시스템으로 보낼 필요는 없다. 그냥 필요할 때 사용 가능한 것만으로도 충분하다. 
수만 개의 값을 계속해서 모니터링 시스템에 굳이 넣을 필요는 없다.

> **오랫동안 누적된 운영 지표**
> 
> 오랜 시간에 걸쳐 누적된 애플리케이션의 지표도 필요함  
> 누적되는 지표의 일반적인 용도는 용량 산정을 위해서이므로 컴퓨팅 자원, 스토리지, 네트워크 등 사용된 리소스에 대한 정보를 포함함

---

### 1.2.2. 자동화 vs 사람이 모니터링

지표 수집 시 누가 지표를 사용할 것이냐도 고민해봐야 한다.

**자동화가 목적인 지표**는 어차피 컴퓨터가 처리할 것이므로 대량의 메트릭을 사용하여 세세한 부분까지 대량의 데이터를 수집해도 상관없다. 더 상세한 데이터를 수집할수록 
해석이 별로 필요없으므로 이에 대한 자동화는 오히려 더 쉽다.

**사람이 봐야할 지표**를 대량으로 수집하면 오히려 운영자가 혼란스러울 수 있다.  
특히 측정된 지푯값에 따라 경보를 설정할 때 더 그런 경향이 있는데 문제가 얼마나 심각한 지 알 길이 없어서 많은 경보를 무시하는 경보 피로감(alert fatigue) 에 빠지기 쉽다.

---


# 2. 서비스 수준 목표(SLO, Service-Level Objective)

서비스 수준 목표(SLO)는 카프카와 같은 인프라스트럭처 서비스에 있어서 모니터링이 다루어야 할 부분 중 하나이다.  
서비스 수준 목표는 클라이언트와 제공되어야 할 인프라스트럭처 서비스의 수준에 대해 이야기하는 수준이기도 하다.

---

## 2.1. 서비스 수준 정의

- **서비스 수준 지표(SLI, Service-Level Indicator)**
  - 클라이언트 경험과 크게 연관성이 있으므로 여기에 속하는 지표들은 목표 지향적일수록 좋음
  - SLI 는 SLO threshold 아래 실제 측정값을 근거로 정하는 것이 좋음
    - 이상적으로 각 이벤트는 SLO threshold 아래에 있는지 개별적으로 확인할 수 있어야 함
    - 이러한 이유때문에 변위치(quantile) 지푯값은 좋은 SLI 가 못됨
    - 변위치 지푯값은 '전체 이벤트의 90% 가 주어진 값 아래 있다'와 같은 것을 알려줄 뿐, 그 값을 제어할 수 있게 해주는 것은 아님
  - 예) 웹 서버에서 2XX, 3XX, 4XX 응답을 받은 요청의 비율
- **서비스 수준 목표(SLO, Service-Level Objective)**
  - 서비스 수준 한계(SLT, Service-Level Threshold) 라고도 함
  - SLI 에 목표값을 결합한 것으로 측정되는 시간 간격이 포함되어야 함
  - 예) 일주일 간 웹서버에 대한 요청 중 99% 가 2XX 응답을 받아야 함
- **서비스 수준 협약(SLA, Service-Level Agreement)**
  - 서비스 제공자와 클라이언트 사이의 계약
  - 측정 방식, 보고 방식, 지원받을 수 있는 방법, SLA 를 준수하지 못했을 때 서비스 제공자가 져야 할 책임이 명시된 여러 개의 SLO를 포함함
  - 예) 서비스 제공자가 SLO 수준의 동작을 제공하지 못할 경우 해당 기간에 대한 모든 비용을 환불해준다.

> **변위치(Quantile) 기반 지표의 한계**
> 
> 변위치 지표는 'N% 의 요청이 특정 시간 이하에서 처리되었다' 라는 방식으로 표현됨  
> 예) p90(latency)=200ms → 전체 요청 중 90% 가 200ms 이하에서 처리됨
> 
> 변위치 지표의 문제점은 아래와 같음
> - 개별 이벤트에 대한 정보 제공 부족
>   - 변위치 지푯값은 특정 퍼센트의 이벤트가 특정값을 넘지 않는다고만 나타낼 뿐, 개별 이벤트가 SLO 를 초과했는지는 확인할 수 없음
>   - 예) p99(latency)=500ms 이면 99% 의 요청이 500ms 이하이지만, 나머지 1% 가 10초일수도 있음
> - 장애를 정확히 감지하기 어려움
>   - 예) p90(latency)=200ms 더라도 10% 의 요청이 5초 이상 걸린다면 서비스 품질이 낮아졌지만 p90 만 보면 이를 감지하지 못함
> - SLO 임계값을 초과하는 요청을 직접 측정할 수 없음
>   - SLO 는 '90% 이상의 요청이 100ms 이하에서 처리되어야 한다' 와 같은 형태인데 변위치 지푯값은 비율이 아니라 특정 지점의 응답 시간만 제공하므로 정확한 평가가 어려움
> - 평균과 비슷한 허점이 있음
>   - 평균 지표처럼 일부 극단적인 값에 영향을 받지 않는 대신, 특정 비율의 요청이 심각한 장애를 겪어도 이를 반영하지 못함

---

## 2.2. 좋은 서비스 수준 지표(SLI)를 위한 지표값

SLI 를 기준으로 볼 때 인프라스트럭처 지표는 사용해도 좋고, 특수 클라이언트 지표는 좋은 수준이며, 일반 클라이언트 지표는 가장 좋을 지표이다.

<**SLI 종류**>

|       가용성       | 설명                                     |
|:---------------:|:---------------------------------------|
|   지연(latency)   | 응답이 얼마나 빨리 리턴되는지?                      |
|   품질(quality)   | 응답의 내용이 적절한지?                          |
|  보안(security)   | 요청과 응답이 적절히 보호되는지? 권한이나 암호화가 잘 되어 있는지? |
| 처리량(throughput) | 클라이언트가 충분한 속도로 데이터를 받을 수 있는지?          |


---

## 2.3. 경보에 SLO 사용

SLO 는 사용자의 관점에서 문제를 기술하는 것이고, 운영자 입장에서 가장 먼저 고려해야 하기 때무에 주된 경보로 설정해야 한다.  
SLO 는 무엇이 문제인지 알려주지는 않지만 문제가 있다는 것은 알려준다.  
문제는 SLO 를 직접적인 경보 기준으로 사용하는 것은 어렵다는 것이다.  
참고로 SLO 경보가 울릴때쯤이면 이미 늦었다는 의미이다.  
SLO 를 경보에 사용하는 가장 좋은 방법은 조기에 경보가 가도록 소진율(burn rate) 를 보는 것이다.

---

# 3. 카프카 브로커 지표

브로커에는 수많은 지표들이 있는데 대부분 카프카 개발자들이 특정 이슈 혹은 나중에 디버깅할 목적으로 만든 저수준 지표들이다.

여기서는 카프카 클러스터에 발생한 문제의 원인을 진단하는 대략적인 작업 흐름에 대해 알아본다.

> **카프카 모니터링(감시자는 누가 감시하는가?)**
> 
> 많은 조직에서 중앙 모니터링 시스템에서 사용할 애플리케이션 지표, 시스템 지표, 로그 저장에 카프카를 사용함  
> 이는 애플리케이션과 모니터링 시스템을 분리하는 좋은 방법임
> 
> 만일 카프카 자체를 모니터링하는데 동일한 시스템을 사용한다면 카프카에 장애가 발생할 경우 모니터링 시스템으로의 데이터 흐름 역시 덩달아 장애를 겪으므로 
> 문제가 발생했는지 알 수 없음  
> 이를 해결하는 방법은 카프카를 모니터링하는 시스템은 카프카에 의존하지 않는 별도의 시스템을 사용하는 것임

---

## 3.1. 클러스터 문제 진단

<**카프카 클러스터에 문제가 발생하는 4가지 경우**>
- 단일 브로커에서 발생하는 문제
- 클러스터에 요청이 몰려서 발생하는 문제
- 과적재된 클러스터에서 발생하는 문제
- [컨트롤러](https://assu10.github.io/dev/2024/06/10/kafka-basic/#25-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%ED%81%B4%EB%9F%AC%EC%8A%A4%ED%84%B0-%EC%BB%A8%ED%8A%B8%EB%A1%A4%EB%9F%AC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%8D%94-%ED%8C%94%EB%A1%9C%EC%9B%8C) 문제

**단일 브로커에서 발생하는 문제**들은 진단하기도 쉽고, 대응하기도 쉽다.  
클러스터 내에서 지푯값이 튀는 것만 봐도 알 수 있고, 고장난 저장 장치나 시스템 내의 다른 애플리케이션으로 인한 자원 제한으로 발생하기 때문이다.  
이러한 문제들을 탐지하기 위해선 각 서버에 대한 가용성 뿐 아니라 저장 장치, 운영 체제 사용률도 모니터링해야 한다.

하드웨어, 운영 체제 수준의 문제를 제외하면 대부분의 문제는 **카프카 클러스터에 요청이 몰려서 발생**한다.  
카프카는 클러스터 안의 데이터를 브로커 사이에 최대한 고르게 분포시키려 하지만, 그 데이터에 접근하는 클라이언트는 고르게 분포되어 있지 않고, 요청이 몰리는 파티션과 
같은 이슈를 찾아주는 것도 아니다.  
따라서 **외부 툴을 사용하여 클러스터의 균형을 항상 유지하는 것을 강력히 권장**한다.  
이러한 툴로는 [크루즈 컨트롤(cuise-control)](https://github.com/linkedin/cruise-control) 이 있다. 크루즈 컨트롤은 클러스터를 모니터링하고 있다가 
그 안의 파티션을 리밸런싱해주고, 브로커 추가 및 제거와 같은 기능도 제공한다.

> **선호 레플리카 선출**
> 
> [1.1. 선호 레플리카 선출: `kafka-leader-election.sh`](https://assu10.github.io/dev/2024/09/22/kafka-operation-2/#11-%EC%84%A0%ED%98%B8-%EB%A0%88%ED%94%8C%EB%A6%AC%EC%B9%B4-%EC%84%A0%EC%B6%9C-kafka-leader-electionsh) 에서 
> 본 것처럼 브로커는 자동 리더 리밸런스 기능이 켜져 있지 않는한 자동으로 리더 자격을 원래 리더로 돌려놓지 않음 (= 리더 레플리카의 균형이 깨지기 쉬움)  
> 선호 레플리카 선출 기능을 실행하는 것은 안전하면서도 쉬운 해법이므로, 우선 이것부터 실행시켜 보고 문제가 사라졌는지 확인해보는 것은 좋은 방법임

**과적재된 클러스터에서 발생하는 문제**도 쉽게 알 수 있다.  
클러스터에 균형이 잡혀있는데도 다수의 브로커가 요청에 대해 높은 지연을 갖거나, 요청 핸들러 풀의 유휴 비율이 높다면 브로커가 처리할 수 있는 트래픽의 한계에 다다른 것이다.  
이 때는 클러스터에 걸리는 부하는 줄이던가, 브로커 수를 늘리던가 해야 한다.

카프카 클러스터의 **컨트롤러에 발생한 문제**는 진단하기 어렵다.  
컨트롤러를 모니터링하는 방법은 많지는 않지만, 활성 컨트롤러 수나 컨트롤러 큐 크기와 같은 지표를 모니터링함으로써 문제가 발생했을 때 알아차릴 수 있다.  
(정상일 경우 활성 컨트롤러 수는 1임)

---

## 3.2. 불완전 복제 파티션(URP, Under-Replication Partition) 다루기

카프카에서 각 토픽의 파티션은 하나의 리더와 하나 이상의 팔로워 레플리카로 구성된다.  
리더는 프로듀서로부터 데이터를 받고, 팔로워는 리더의 데이터를 복사한다.  
- **정상적인 복제 상태**
  - 모든 팔로워 레플리카가 리더와 완전히 동기화됨
  - 모든 레플리카가 ISR(In-Sync Replica) 리스트에 포함됨
- **불완전 복제 상태**
  - 일부 팔로워 레플리카가 리더와 동기화되지 않음
  - 해당 레플리카는 ISR 리스트에서 제외됨
  - 데이터 가용성이 낮아지고, 장애 복구 시 리스크가 증가함

---

<**불완전 복제 파티션의 발생 원인**>
- **네트워크 지연**
  - 팔로워가 리더의 데이터를 적시에 복제하지 못함
- **팔로워 브로커 다운**
  - 팔로워 브로커가 중단되면 해당 레플리카가 ISR 에서 제외됨
- **CPU, 디스크, 네트워크 등 리소스 부족**
  - 팔로워 브로커가 부하로 인해 데이터를 정상적으로 복제하지 못함
- **Replication 설정 오류**
  - [`min.insync.replicas`](https://assu10.github.io/dev/2024/06/15/kafka-install/#329-mininsyncreplicas) 값이 너무 높거나, [`unclean.leader.election.enable=false`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#32-%EC%96%B8%ED%81%B4%EB%A6%B0-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-uncleanleaderelectionenable) 일 경우 복구가 지연될 수 있음

---

<**불완전 복제 파티션 해결 방법**>
- **브로커 상태 확인 및 복구**
  - 팔로워 브로커가 다운된 경우 브로커 재시작
  - `advertised.listeners` 설정이 올바른지 확인 (네트워크 문제 해결)
- **카프카 설정 최적화**
  - ISR 이 느리게 복구되는 경우 [`replica.lag.time.max.ms`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#34-%EB%A0%88%ED%94%8C%EB%A6%AC%EC%B9%B4%EB%A5%BC-in-sync-%EC%83%81%ED%83%9C%EB%A1%9C-%EC%9C%A0%EC%A7%80-zookeepersessiontimeoutms-replicalagtimemaxms) 를 줄여서 빠른 감지 유도
  - [`unclean.leader.election.enable=false`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#32-%EC%96%B8%ED%81%B4%EB%A6%B0-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-uncleanleaderelectionenable) 를 유지하여 비정상적인 리더 선출을 방지함으로써 데이터 유실 방지
  - [`min.insync.replicas`](https://assu10.github.io/dev/2024/06/15/kafka-install/#329-mininsyncreplicas) 값을 적절히 조정하여 ISR 에서 너무 자주 빠지는 것을 방지
- **카프카 클러스터 성능 튜닝**
  - 브로커 추가
    - 복제본이 많아질수록 리더가 처리해야 할 데이터가 증가하므로 클러스터 확장 필요
  - 디스크 I/O 최적화
    - [`log.segment.bytes`](https://assu10.github.io/dev/2024/06/15/kafka-install/#327-logsegmentbytes), `log.segment.ms` 값을 조정하여 로깅 성능 최적화
  - 리소스 모니터링 및 자동화
    - Prometheus + Grafana 또는 Datadog을 활용해 Kafka 지표를 지속적으로 모니터링

---

<**운영 환경에서의 권장 모니터링**>
- 실시간 경보 설정
  - Prometheus + Alertmanager
- 카프카 클러스터 상태 시각화
  - Grafana
- 브로커 및 파티션 상태 모니터링
  - Kafka Manager / Kafdrop

---

카프카 모니터링에 있어서 가장 자주 쓰이는 지표 중 하나는 불완전 복제 파티션이다.  
불완전 복제 파티션은 클러스터에 속한 브로커 단위로 집계된다.

> **불완전 복제 파티션 함정**
> 
> 불완전 복제 파티션은 중요한 지표이지만 별 것 아닌 이유로 자주 1이 될 수 있음  
> 이는 운영자가 잘못된 경보를 받을 수 있다는 의미이며, 이러한 일이 반복되면 경보를 무시하게 됨  
> 이러한 이유로 불완전 복제 파티션에 경보 설정하는 것은 권장하지 않으며, 대신 알려지지 않은 문제를 탐지하기 위해 SLO 기준 경보를 사용하는 것을 권장함

**다수의 브로커가 일정한 수의 불완전 복제 파티션을 갖고 있다는 것**은 보통 클러스터의 브로커 중 하나가 내려가있다는 것을 의미하는 경우가 많다.  
전체 클러스터에 걸친 불완전 복제 파티션 수는 내려간 브로커에 할당된 파티션 수와 동일할 것이며, 그 브로커는 해당 지표를 보고하지 않을 것이다.

**불완전 복제 파티션 수가 오르락내리락 하거나, 수는 일정한데 내려간 브로커가 없다면** 보통 클러스터의 성능 문제이다.  
가장 먼저 할 일은 단일 브로커에 국한된 것인지, 클러스터 전체에 연관된 것인지 확인해야 한다.  
**불완전 복제 파티션들이 한 브로커에 몰려있다면** 해당 브로커가 문제일 가능성이 높다.  
**불완전 복제 파티션이 여러 브로커에 걸쳐 나타나면** 클러스터 문제일수도 있지만, 여전히 특정 브로커가 문제일 가능성이 있다.  
이 경우 특정 브로커가 다른 브로커로부터 메시지를 복제하는데 문제가 발생할 수 있는데 어느 브로커가 문제인지 알아내야 한다.  
한 가지 방법은 클러스터 내의 불완전 복제 파티션 목록을 뽑은 후 공통되는 브로커가 있는지 보는 것이다.

[`kafka-topics.sh`](https://assu10.github.io/dev/2024/09/21/kafka-operation-1/#1-%ED%86%A0%ED%94%BD-%EC%9E%91%EC%97%85-kafka-topicssh) 로 불완전 복제 파티션 목록 출력

```shell
$ ./bin/kafka-topics.sh --bootstrap-server test.com:9092/kafka-cluster /
--describe --under-replicated

Topic: my-topic-1 Partition: 5 Leader: 1 Replicas: 1,2 Isr: 1
Topic: my-topic-1 Partition: 5 Leader: 3 Replicas: 2,3 Isr: 3
Topic: my-topic-2 Partition: 3 Leader: 4 Replicas: 2,4 Isr: 3
Topic: my-topic-2 Partition: 7 Leader: 5 Replicas: 5,2 Isr: 5
Topic: my-topic-3 Partition: 1 Leader: 3 Replicas: 2,3 Isr: 3
```

위에서 보면 공통으로 나타나는 브로커는 2번 브로커이므로 이 브로커에 초점을 맞춰서 살펴보아야 한다.  
만일 공통으로 나타나는 브로커가 없다면 클러스터 수준의 문제일 가능성이 높다.

---

### 3.2.1. 클러스터 수준의 문제

클러스터 문제는 보통 아래 2가지 중 하나에 속한다.
- **부하 불균형**
- **자원 고갈**

**부하 불균형**은 찾기는 쉽지만, 해결하는 것은 상당히 복잡할 수 있다.  
부하 불균형을 찾아내려면 브로커의 아래 지표들을 확인해봐야 한다.
- 파티션 개수
- 리더 파티션 개수
- 전 토픽에 있어서의 초당 들어오는 메시지
- 전 토픽에 있어서의 초당 들어오는 바이트
- 전 토픽에 있어서의 초당 나가는 바이트

선호 리더(= 선호 레플리카) 선출을 했는데도 받고 있는 트래픽의 편차가 크다면, 클러스터에 들어오는 트래픽이 불균형하다는 의미이므로 부하가 많은 브로커의 파티션을 
적은 브로커로 재할당해야 한다. ([`kafka-reassign-partitions.sh`](https://assu10.github.io/dev/2024/09/22/kafka-operation-2/#12-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A0%88%ED%94%8C%EB%A6%AC%EC%B9%B4-%EB%B3%80%EA%B2%BD-kafka-reassign-partitionssh) 이용)

카프카 브로커는 자동 파티션 재할당 기능을 제공하지 않기 때문에 카프카 클러스터의 트래픽 균형을 맞추는 일은 긴 지표 목록을 일일이 확인해가면서 가능한 재할당을 검토해야 한다.  
링크드인이 개발한 [kafka-tools](https://github.com/linkedin/kafka-tools) 의 `kafka-assigner` 툴을 이용하여 이 작업을 자동화할 수 있다.

**자원 고갈**은 브로커에 들어오는 요청이 처리 가능한 용량을 넘어가는 경우이다.  
CPU, 디스크 입출력, 네트워크 처리량 등 병목 현상이 발생할 수 있는 원인믄 많지만 디스크 활용률의 경우 브로커는 디스크가 꽉 찰 때까지 작동하다가 꽉 차는 순간 
작동을 정지하기 때문에 디스크 활용률은 여기에 해당하지 않는다.

용량 문제는 아래의 운영체제 수준 지표들을 모니터링해야 한다.
- **CPU 사용률**
  - 높은 CPU 사용률을 카프카의 복제, 압축 작업에 영향을 미침
  - CPU 사용률이 80% 이상 지속되면 복제 작업이 지연될 가능성이 높으며, 그 결과 ISR 리스트에서 팔로워 레플리카가 빠지게 됨 (= 불완전 복제 파티션 발생)
- **인바운드/아웃바운드 네트워크 속도**
  - 브로커가 다른 브로커나 클라이언트로부터 데이터를 받거나 전달할 때의 속도
  - 브로커는 네트워크를 통해 다른 브로커와 클라이언트 간 데이터를 송수신하므로 네트워크 병목이 발생하면 복제 지연이 발생할 수 있음
  - 인바운드 속도가 낮으면 팔로워 브로커가 리더 브로커에서 데이터를 가져오는 속도가 느려짐
  - 아웃바운드 속도가 낮으면 리더 브로커가 팔로워에게 데이터를 전송하는 속도가 느려짐
- **평균 디스크 대기 시간**
  - 디스크 읽기/쓰기 요청이 처리되기까지 걸리는 평균 시간
  - 카프카는 로그 세그먼트 파일을 저장하기 위해 디스크 I/O 를 활용하므로 디스크 대기 시간이 길어지거나 디스크 사용률이 높으면 복제 작업이 지연됨
  - 디스크 대기 시간(I/O latency) 이 길어지면 데이터 저장이 느려지고 복제 속도가 감소함
- **디스크 평균 활용률**
  - 브로커 디스크 사용률이 높으면 데이터 저장 및 복제 작업이 지연됨
  - 디스크 사용률이 85% 이상이면 새로운 데이터 저장과 읽기 속도가 저하됨

대부분 위 자원들 중 하나라도 고갈되면 불완전 복제 파티션이 발생한다.  
브로커의 복제 기능은 다른 카프카 클라이언트(프로듀서, 컨슈머) 와 동일한 방식으로 수행된다. 즉, 브로커 간의 복제 작업도 클라이언트와 마찬가지로 리소스를 사용하며, 
클러스터 내의 어떤 브로커에서든 리소스 부족이 발생하면 복제 지연 및 데이터 동기화 문제가 발생할 수 있다.  
만일 클러스터에 복제 문제가 있다면, 메시지를 읽거나 쓰는 클라이언트도 똑같은 문제가 발생한다.

<**복제 문제 발생 시 클라이언트 영향**>

| 복제 문제            | 프로듀서 영향                          | 컨슈머 영향                      |
|:-----------------|:---------------------------------|:----------------------------|
| 팔로워가 리더를 따라잡지 못함 | [`acks=all`](https://assu10.github.io/dev/2024/06/16/kafka-producer-1/#42-acks) 설정 시 메시지 전송 실패 발생 | 오프셋이 리더와 동기화되지 않아 메시지 손실 가능 |
| 브로커 네트워크 병목      | 전송 속도 저하, 타임아웃 발생                | 메시지 소비 속도 저하                |
| 디스크 I/O 병목       | 메시지 저장 지연                        | 메시지 소비 속도 저하                |

즉, 리소스 병목이 발생하면 복제 지연이 발생하고, 결국 클러스터 성능이 저하된다.  
따라서 클러스터가 정상 동작할 때 이러한 지표들의 기준값을 미리 정해놓은 뒤 용량 문제가 발생하기 전에 알아차릴 수 있도록 하는 것이 좋다.

- 카프카 지표 실시간 모니터링
  - Prometheus + Grafana
- 카프카 클러스터 네트워크 및 디스크 상태 정기 점검
- 카프카 설정 최적화
  - `num.replica.fetchers`, `log.segment.bytes` 등
- 클러스터 확장 고려
  - 디스크 용량 증가, 브로커 추가 등

---

## 3.3. 브로커 지표

불완전 복제 파티션 외 전체 브로커 수준에서 모니터링해야 하는 다른 지표들에 대해 알아본다.  
여기서 볼 지표들은 클러스터에 속한 브로커에 대해 중요한 정보를 제공하므로, 모니터링 대시보드를 만들 때 이 지표들을 포함해야 한다.

카프카는 JMX(Java Management Extensions) 를 통해 아래 지표들을 노출한다.

---

### 3.3.1. 활성 컨트롤러 수: `ActiveControllerCount`

- JMX MBean
  - kafka.controller:type=KafkaController,name=ActiveControllerCount
- 값 범위
  - 0 또는 1

활성 컨트롤러 수는 클러스터의 [컨트롤러](https://assu10.github.io/dev/2024/06/10/kafka-basic/#25-%EB%B8%8C%EB%A1%9C%EC%BB%A4-%ED%81%B4%EB%9F%AC%EC%8A%A4%ED%84%B0-%EC%BB%A8%ED%8A%B8%EB%A1%A4%EB%9F%AC-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A6%AC%EB%8D%94-%ED%8C%94%EB%A1%9C%EC%9B%8C) 노드가 몇 개 활성화되어있는지를 나타내는 지표이다.

클러스터에서 정상적인 상태에서는 단 하나의 컨트롤러만 존재해야 한다.

- **정상적인 클러스터 상태**
  - **Active Controller Count = 1**
- **비정상적인 클러스터 상태**
  - **Active Controller Count = 0**
    - 컨트롤러 역할을 하던 브로커가 다운되었거나, 네트워크 장애가 발생했을 수 있음
    - 토픽이나 파티션 생성, 브로커 장애 발생과 같은 상태 변경이 발생할 때 제대로 대응할 수 없게됨
    - 컨트롤러 후보 브로커를 확인한 후 새로운 컨트롤러를 강제 지정한 후 모든 브로커 재시작하여 해결할 수 있음
  - **Active Controller Count > 1**
    - 종료되었어야 할 컨트롤러 스레드에 문제가 생겼을 가능성이 있음
    - 컨트롤러 선출 과정에서 충돌이 발생했을 수 있음
    - 파티션 이동과 같은 관리 작업을 정상적으로 실행할 수 없게됨
    - 컨트롤러 브로커 ID 를 확인한 후 중복된 컨트롤러 브로커를 종료하고 컨트롤러를 강제 재선출하여 해결할 수 있음

---

### 3.3.2. 컨트롤러 큐 크기: `EventQueueSize`

- JMX MBean
  - kafka.controller:type-ControllerEventManager,name=EventQueueSize
- 값 범위
  - 0 이상의 Integer
  - 
컨트롤러 큐 크기는 현재 컨트롤러에서 브로커의 처리를 기다리고 있는 요청의 수이다.  
이 값이 순간적으로 튈 수는 있지만, 계속해서 증가하거나 높아진 상태를 유지한다면 컨트롤러에 뭔가 문제가 생긴 것이다.  
이럴 경우 현재 컨트롤러 역할을 하고 있는 브로커를 끔으로써 컨트롤러를 다른 브로커로 옮겨야 한다.

---

### 3.3.3. 요청 핸들러 유휴 비율: `RequestHandlerAvgIdlePercent`

- JMX MBean
  - kafka.server:type=KafkaRequestHandlerPool,name=RequestHandlerAvgIdlePercent
- 값 범위
  - 0 이상 1 이하의 Float

카프카는 모든 클라이언트 요청을 처리하기 위해 네트워크 스레드 풀과 요청 핸들러 스레드(I/O 스레드), 이렇게 2개의 스레드 풀을 사용한다.  
네크워크 스레드풀은 네트워크를 통해 클라이언트와 데이터를 주고 받는 작업을 전담하는데, 특별한 처리를 필요로 하지 않으므로 네트워크 스레드가 당장 고갈되더라도 우려하지 않아도 된다.  
하지만 요청 핸들러 스레드는 메시지를 디스크에 쓰거나 읽어오는 것을 포함한 클라이언트 요청 그 자체의 처리를 담당하므로 브로커에 더 많은 부하가 걸릴수록 요청 핸들러 
스레드 풀에는 큰 영향을 미친다.

요청 핸들러 스레드 수는 브로커의 CPU 수보다 더 많은 스레드를 설정할 필요는 없다.  
카프카는 처리가 오래 걸리는 요청을 요청 퍼거토리(request purgatory) 자료 구조에 넣기 때문이다.

> **요청 퍼거토리(Request Purgatory)**
> 
> 요청 퍼거토리는 아직 성공이나 실패 여부가 결정되지 않은 요청들을 모아놓는 자료 구조임  
> 당장 처리가 필요하지 않은 요청들을 저장해놓을 수 있기 때문에 적은 수의 스레드로 많은 요청을 처리할 수 있게 해줌  
> 요청 퍼거토리에 저장된 요청은 응답을 보내기 위한 조건이 달성되거나 타임아웃이 발생하면 자동으로 삭제됨

요청 핸들러 유휴 비율 지표는 요청 핸들러가 작동 중이지 않은 시간 비율(%)로, 값이 낮을수록 브로커에 부하가 많이 걸려있다는 의미이다.  
(보통 20% 이하로 내려가면 잠재적 문제가 있다는 것이고, 10% 이하면 성능 문제가 현재 진행형임)

스레드 수가 충분하지 않으면 요청 핸들러 스레드 풀의 사용율이 높아지는데, 일반적으로 요청 핸들러 스레드의 수는 시스템의 프로세서 수와 같게 설정해야 한다.

---

### 3.3.4. 전 토픽 바이트 인입: `BytesInPerSec`

- JMX MBean
  - kafka.server:type=BrokerTopicMetrics,name=ByteInPerSec
- 값 범위
  - 초당 인입률(rate) 는 Double, 개수(count) 는 Integer

초당 바이트로 표현되는 전 토픽 바이트 인입 속도는 브로커가 프로듀서 클라이언트로부터 얼마나 많은 메시지 트래픽을 받는지에 대한 측정값으로 유용하다.  
전 토픽 바이트 인입 지표는 아래와 같은 상황에 유용하다.
- 클러스터를 언제 확장해야 하는지?
- 트래픽이 어떻게 증가함에 따라 필요한 다른 작업을 언제 해야하는지?
- 클러스터의 어느 브로커가 다른 브로커보다 더 많은 트래픽은 받고 있는지? (= 파티션 재할당이 필요하다는 의미)

아래는 속도 지표가 갖고 있는 속성이다.
- EventType
  - 모든 지표의 단위(byte)
- RateUnit
  - 속도 지표의 시간적 기준(second)
- OneMinuteRate
  - 지난 1분간의 평균
  - 짧은 시간동안 급격히 튀어오르는 트래픽을 볼 때 유용함
- FiveMinuteRate
  - 지난 5분간의 평균
- FifteenMinuteRate
  - 지난 15분간의 평균
- MeanRate
  - 브로커가 시작된 이후의 평균

속도 속성 뿐 아니라 Count 속성도 있다.  
Count 속성은 브로커가 시작된 시점부터 지속적으로 증가하는 값으로, 전 토픽 바이트 인입 지표에서는 브로커에 쓰여진 전체 바이트 수를 의미한다.

---

### 3.3.5. 전 토픽 바이트 유출: `BytesOutPerSec`

- JMX MBean
  - kafka.server:type=BrokerTopicMetrics,name=BytesOutPerSec
- 값 범위
  - 초당 유출률(rate) 은 Double, 개수(count) 는 Integer

전 토픽 바이트 유출은 브로커에서 나가는 총 데이터 전송 속도, 즉 컨슈머가 메시지를 읽는 속도를 보여준다.

전 토픽 바이트 유출 속도는 레플리카에 의해 발생하는 트래픽도 포함한다.  
유출 속도는 아래 2가지 영향을 받는다.
- 레플리카 복제 트래픽
  - 카프카 팔로워 브로커는 리더 브로커보루터 데이터를 복제함
  - 따라서 컨슈머가 없더라도 레플리카 복제 트래픽이 유출 속도를 발생시킴
- 컨슈머의 메시지 소비
  - 컨슈머가 메시지를 읽어갈 때 브로커에서 컨슈머에게 데이터를 전송함

만일 복제 팩터가 2라면 모든 메시지는 리더 브로커에서 팔로워 브로커로 1회 복제가 되므로 컨슈머가 없는 경우 유출 속도는 유입 속도와 같다.  
만일 여기에 컨슈머가 하나 추가된다면 리더 브로커는 팔로워에게 데이터는 전송(=복제)하고, 동시에 컨슈머에게도 메시지를 전송해야 하므로 유출 속도는 유입 속도의 딱 2배가 된다.

---

### 3.3.6. 전 토픽 메시지 인입: `MessageInPerSec`

- JMX MBean
  - kafka.server:type=BrokerTopicMetrics,name=MessageInPerSec
- 값 범위
  - 초당 인입률(rate) 는 Double, 개수(count) 는 Integer

메시지 인입 속도는 메시지 크기와 무관하게 초당 들어오는 메시지 수를 보여준다.  
전 토픽 메시지 인입은 프로듀서 트래픽 만큼이나 트래픽의 성장을 보여주는 중요한 지표이다.

컨슈머가 메시지를 읽을 때 브로커는 그냥 다음 배치를 컨슈머에게 넘겨줄 뿐, 배치를 열어서 몇 개의 메시지가 있는지 확인하지는 않기 때문에 브로커에 메시지 유출 지표는 없다.  
브로커가 제공할 수 있는 지표는 초당 읽기 요청 수 뿐이다.

---

### 3.3.7. 파티션 수: `PartitionCount`

- JMX MBean
  - kafka.server:type=ReplicaManager=name=PartitionCount
- 값 범위
  - 0 이상 Integer

브로커에 할당된 파티션의 전체 개수를 의미한다.  
자동 토픽 생성 기능이 켜져있는 클러스터라면 토픽 생성이 운영자의 손을 벗어나기 때문에 이 값을 모니터링하는 것이 더 중요하다.

---

### 3.3.8. 리더 수: `LeaderCount`

- JMX MBean
  - kafka.server:type=ReplicaManager,name=LeaderCount
- 값 범위
  - 0 이상 Integer

토픽은 여러 개의 파티션으로 나뉘며, 각 파티션을 특정 브로커가 리더 역할을 담당한다.
- 리더 브로커
  - 프로듀서가 메시지를 전송하는 대상이며, 컨슈머도 기본적으로 리더에서 데이터를 소비함
- 팔로워 브로커
  - 리더의 데이터를 복제하여 장애 시 데이터 유실 방지

<**리더 개수 지표의 역할**>
- 각 브로커가 담당하는 리더 파티션의 개수를 나타내는 지표
- 이 값이 불균등할 경우, 특정 브로커에 과부하가 발생할 수 있음
- 클러스터 내 브로커 간 리더 역할을 고르게 분배하는 것이 이상적임

<**리더 개수가 불균등할 수 있는 이유**>
- 초기 리더 배정이 뷸균등
- 장애 발생 시 특정 브로커로 리더 집중
  - 선호 리더 선출을 실행하여 해결 가능함
- 토픽 및 파티션 추가 시 기존 리더 균형 유지 실패

위와 같은 이율호 리더 개수 지표는 정기적으로 확인하고, 가능하면 경보도 걸어놓는 것이 좋다.

<**리더 개수 불균형 해결 방법**>
- 선호 리더 선출
- [리더 재배치 수행](https://assu10.github.io/dev/2024/09/22/kafka-operation-2/#12-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A0%88%ED%94%8C%EB%A6%AC%EC%B9%B4-%EB%B3%80%EA%B2%BD-kafka-reassign-partitionssh)

리더 개수 불균형 지표를 활용하는 요령은 해당 브로커가 리더 역할을 맡고 있는 파티션의 수를 전체 파티션의 수로 나눠서 백분율 비율의 형태로 나타내는 것이다.  
예) 복제 팩터가 2인 클러스터가 균형이 잘 잡혀 있는 경우 모든 브로커는 전체 파티션의 절반에 대해 리더 역할을 맡게 됨  
복제 팩터가 3일 경우는 이 비율이 33% 가 됨


---

### 3.3.9. 오프라인 파티션: `OfflinePartitionsCount`

- JMX MBean
  - kafka.controller:type=KafkaController,name=OfflinePartitionsCount
- 값 범위
  - 0 이상 Integer

각 파티션은 반드시 하나의 리더를 가져야하는데, 리더가 없는 상태가 되면 해당 파티션의 데이터는 사용할 수 없으며 프로듀서와 컨슈머가 데이터를 읽거나 쓸 수 없게 된다.

오프라인 파티션은 컨트롤러 역할을 맡고 있는 브로커에서만 제공(다른 브로커에서는 0)되며, 현재 리더가 없는 파티션의 개수를 보여준다.  
정상적인 경우라면 이 값은 0 이어야 하며, 이 값이 0 보다 크면 사이트 다운과 같은 문제를 일으키므로 즉각적인 조치가 필요하다.

<**오프라인 파티션이 발생하는 이유**>
- 리더 브로커 장애로 인해 새로운 리더 선출이 실패한 경우
- 모든 레플리카가 동기화되지 않아 ISR 에서 제외된 경우
- 클러스터 설정 문제로 리더 전환이 실패한 경우
- 브로커 간 네트워크 장애로 리더 선출이 불가능한 경우

<**오프라인 파티션 발생 시 해결 방법**>
- **새로운 리더 강제 선출**
  - 선호 리더 선출을 실행하여 기존에 리더였던 브로커를 다시 리더로 선출하도록 요청함
- **컨트롤러 브로커 재시작**
  - 컨트롤러 브로커는 클러스터 내 리더 선출을 담당함
  - 컨트롤러 브로커에 문제가 발생한 경우 재시작하면 리더 선출이 다시 이루어질 수 있음
- **[`unclean.leader.election.enable`](https://assu10.github.io/dev/2024/08/17/kafka-reliability/#32-%EC%96%B8%ED%81%B4%EB%A6%B0-%EB%A6%AC%EB%8D%94-%EC%84%A0%EC%B6%9C-uncleanleaderelectionenable) 설정 확인**
  - false: ISR 에 있는 레플리카만 리더로 선출됨 (데이터 유실을 막기 위해 false 를 권장함)
  - true: ISR 이 없어도 비정상적인 브로커를 리더로 선출할 수 있음
- **클러스터 재배치**
  - 리더 선출이 제대로 이루어지지 않은 경우 [`kafka-reassign-partitions.sh`](https://assu10.github.io/dev/2024/09/22/kafka-operation-2/#12-%ED%8C%8C%ED%8B%B0%EC%85%98-%EB%A0%88%ED%94%8C%EB%A6%AC%EC%B9%B4-%EB%B3%80%EA%B2%BD-kafka-reassign-partitionssh) 를 통해 특정 브로커를 리더로 재배치

---

## 3.4. 토픽과 파티션별 지표

토픽과 파티션별 지표는 클라이언트에 연관된 특정 문제를 디버깅할 때 유용하다.  
예) 토픽 지표는 클러스터의 트래픽을 급증시킨 특정한 문제를 디버깅할 때 유용함

---

### 3.4.1. 토픽별 지표

모든 토픽별 지표의 측정값은 브로커 지표와 매우 비슷하며, 유일한 차이점은 토픽 이름을 지정해야 한다는 점과 지푯값이 지정된 토픽에 국한된 값이라는 점이다.

<**토픽별 지표**>

| 이름              | JMX MBean                                                                            |
|:----------------|:-------------------------------------------------------------------------------------|
| 초당 바이트 인입       | kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec,topic=my-topic               |
| 초당 바이트 유출       | kafka.server:type=BrokerTopicMetrics,name=BytesOutPerSec,topic=my-topic              |
| 초당 실패한 읽기 요청 개수 | kafka.server:type=BrokerTopicMetrics,name=FailedFetchRequestsPerSec,topic=my-topic   |
| 초당 실패한 쓰기 요청 개수 | kafka.server:type=BrokerTopicMetrics,name=FailedProduceRequestsPerSec,topic=my-topic |
| 초당 인입 메시지 수     | kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec,topic=my-topic            |
| 초당 읽기 요청 개수     | kafka.server:type=BrokerTopicMetrics,name=TotalFetchRequestsPerSec,topic=my-topic    |
| 초당 쓰기 요청 개수     | kafka.server:type=BrokerTopicMetrics,name=TotalProduceRequestsPerSes,topic=my-topic  |


---

### 3.4.2. 파티션별 지표

파티션별 지표는 토픽별 지표에 비해 덜 유용하고, 토픽이 수백개면 파티션은 수천개가 되기 쉽상이다.  
하지만 몇몇 상황에서는 유용하게 사용될 수 있다.  
예) 파티션 크기 지표는 해당 파티션에 대해 현재 디스크에 저장된 데이터의 양을 바이트 단위로 보여줌  
따라서 이 값들을 합산하면 하나의 토픽에 저장된 데이터의 양을 알 수 있는데, 이는 카프카를 각 클라이언트에 할당할 때 들어갈 자원의 양을 계산하는데 유용함

같은 토픽에 속하는 두 파티션의 크기가 다를 경우, 메시지를 쓸 때 사용되는 메시지 키가 고르게 분산되어 있지 않다는 것을 의미한다.

로그 세그먼트 수 지표는 디스크에 저장된 해당 파티션의 로그 세그먼트 파일의 수를 보여주며, 이것은 파티션 크기와 함께 자원 추적 관리에 유용하다.

<**파티션별 지표**>

| 이름         | JMX MBean                                                         |
|:-----------|:------------------------------------------------------------------|
| 파티션 크기     | kafka.log=type=Log,name=Size,topic=my-topic,partition=0           |
| 로그 세그먼트 개수 | kafka.log=type=Log,name=NumLogSegment,topic=my-topic,partition=0  |
| 로그 끝 오프셋   | kafka.log=type=Log,name=LogEndOffset,topic=my-topic,partition=0   |
| 로그 시작 오프셋  | kafka.log=type=Log,name=LogStartOffset,topic=my-topic,partition=0 |

로그 끝 오프셋과 로그 시작 오프셋은 해당 파티션에 속한 메시지 중 가장 높은 오프셋과 가장 낮은 오프셋을 보여주는데 이 두 값은 차이가 항상 해당 파티션의 메시지 수를 의미하는 것은 아니다.
[로그 압착](https://assu10.github.io/dev/2024/08/11/kafka-mechanism-2/#7-%EB%A1%9C%EA%B7%B8-%EC%95%95%EC%B0%A9compact%EC%9D%98-%EC%9E%91%EB%8F%99-%EC%9B%90%EB%A6%AC)으로 인해 동일한 키를 가진 
최신의 메시지만이 남음으로써 파티션에서 제거된 오프셋들이 있을 수 있기 때문이다.  
때로는 파티션에서 이렇게 사라진 오프셋들을 추적 관리하는데 사용될 수도 있다.

---

## 3.5. 운영체제 모니터링

운영체제 정보 중 눈여겨볼 것은 CPU 사용, 디스크 사용, 디스크 I/O, 네트워크 사용량이다.

- **CPU**
  - 프로세스들의 상대적인 사용률을 가리키는 시스템 부하 평균을 보아야 함
  - 카프카 브로커는 요청을 처리하기 위해 CPU 자원을 많이 사용하므로 카프카를 모니터링할 때 CPU 활용률을 추적 관리하는 것은 중요함
- **디스크 사용**
  - 모든 메시지가 디스크에 저장되기 때문에 카프카의 성능은 디스크 성능에 크게 의존함
- **디스크 I/O**
  - 디스크가 효율적으로 사용되고 있는지 여부를 알려줌
  - 최소한 카프카의 데이터가 저장되는 디스크에 대해서는 초당 읽기/쓰기, 읽기 및 쓰기 큐의 평균 크기, 평균 대기 시간, 디스크 사용률(%) 은 모니터링해야 함
- **네트워크 사용량**
  - 네트워크의 인입/유출 트래픽 모니터링

---

## 3.6. 로깅

별도의 디스크로 저장하는 것이 좋은 로거는 2개가 있다.
- INFO 레벨로 로깅되는 `kafka.controller`
  - 클러스터 컨트롤러에 대한 메시지를 제공함
  - 하나의 브로커만이 컨트롤러가 될 수 있으므로, 이 로거를 쓰는 브로커 역시 하나뿐임
  - 토픽 생성, 변경 외에 선호 레플리카 선출, 파티션 이동 등의 클러스터 작업 정보가 포함됨
- INFO 레벨로 로깅되는 `kafka.server.ClientQuotaManager`
  - 프로듀서, 컨슈머 쿼터 작업에 관련된 정보를 제공함
  - 주 브로커 로그 파일에는 포함되지 않도록 하는 것이 좋음

로그 압착 스레드 상태에 관한 정보를 로깅하는 것도 좋다.  
로그 압착 스레드의 작동 상태를 가리키는 지표는 없기 때문에, 파티션 하나를 압착하다 실패가 되면 전체 로그 압착 스레드가 조용히 멈출 수도 있다.  
`kafka.log.LogCleaner`, `kafka.log.Cleaner`, `kafka.log.LogCleanerManager` 로거를 DEBUG 레벨로 활성화하여 로그 압착 스레드의 상태 정보를 
남기는 것이 좋다. 이것은 압착되는 각 파티션 크기나 메시지 수 등의 정보를 포함하며, 정상 운영 상태에서는 메시지가 그리 많이 찍히지도 않는다.

`kafka.request.logger` 는 브로커로 들어오는 모든 요청에 대한 정보를 기록한다.  
DEBUG 레벨로 설정할 경우 연결된 endpoint, 요청 시각, 요약을 보여주고, TRACE 레벨로 설정할 경우 토픽과 파티션 정보를 포함하여, 탑재된 메시지 내용물을 제외한 
거의 모든 정보를 보여준다.  
이 로거는 많은 정보를 기록하기 때문에 디버깅을 할 것이 아니라면 켜지 않는 것을 권장한다.

---

# 4. 클라이언트 모니터링

---

## 4.1. 프로듀서 지표

모든 프로듀서 지표는 bean 이름에 프로듀서 클라이언트의 클라이언트 ID 를 갖는다.

<**프로듀서 지표**>

| 이름      | JMX MBean                                                                                     |
|:--------|:----------------------------------------------------------------------------------------------|
| 프로듀서 전반 | kafka.producer:type=producer-metrics,client-id={MY-CLIENT-ID}                                 |
| 브로커별    | kafka.producer:type=producer-node-metrics,client-id={MY-CLIENT-ID},nodeid=node-{MY-BROKER-ID} |
| 토픽별     | kafka.producer:type=producer-topic-metrics,client-id={MY-CLIENT_ID},topic={MY-TOPIC-NAME}     |


---

### 4.1.1. 프로듀서 종합 지표

<**경보 설정을 해놓아야 하는 지표**>
- **`record-error-rate`**
  - 언제나 9 이어야 하며, 만일 0보다 크다면 프로듀서가 브로커로 메시지를 보내는 도중에 누수가 발생하고 있음을 의미함
  - 프로듀서는 backoff 를 해가면서 사전에 설정된 수만큼 재시도를 하는데, 만일 재시도 수가 고갈되면 메시지(=레코드)는 폐기됨
- **`request-latency-avg`**
  - 브로커가 쓰기 요청을 받을 때까지 걸린 평균 시간
  - 정상 작동 상태에서 이 지표값의 기준점을 찾은 뒤, 그 기준값보다 큰 값으로 threshold 를 설정하면 됨
  - 요청에 대한 지연이 증가하는 것은 쓰기 요청이 점점 느려지고 있다는 의미인데, 이것은 네트워크 문제일수도 있지만 브로커에 문제가 발생한 것일수도 있음

---

<**프로듀서가 전송하는 메시지 트래픽 측정 지표**>
- **`outgoint-byte-rate`**
  - 전송되는 메시지의 절대 크기를 초당 바이트 형태로 나타냄
- **`record-send-rate`**
  - 트래픽을 초당 전송되는 메시지 수의 크기로 나타냄
- **`request-rate`**
  - 브로커로 전달되는 쓰기 요청의 수를 초 단위로 나타냄

하나의 요청은 하나 이상의 배치를 포함하고, 하나의 배치는 1개 이상의 메시지를 포함할 수 있으며, 각 메시지는 여러 바이트로 구성된다.  
위의 지표들을 애플리케이션 대시보드에 추가해놓으면 좋다.

---

<**메시지, 요청, 배치의 크기를 나타내는 지표**>
- **`record-size-avg-metric`**
  - 브로커로 보내지는 쓰기 요청의 평균 크기를 바이트 단위로 나타냄
- **`batch-size-avg`**
  - 하나의 토픽 파티션으로 보내질 메시지들로 구성된 메시지 배치의 평균 크기를 바이트 단위로 나타냄
- **`record-size-avg`**
  - 레코드의 평균 크기를 바이트 단위로 나타냄
- **`records-per-request-avg`**
  - 쓰기 요청에 포함된 메시지의 평균 개수를 나타냄

---

**`record-queue-time-avg`** 는 애플리케이션이 메시지를 전송한 뒤 실제로 카프카에 쓰여지기 전까지 프로듀서에서 대기하는 평균 ms 이다.  
애플리케이션이 메시지를 전송하기 위해 프로듀서 클라이언트를 호출(= send() 호출)하면 프로듀서는 아래 조건 중 하나가 만족할 대까지 기다린다.
- [`batch.size`](https://assu10.github.io/dev/2024/06/16/kafka-producer-1/#47-batchsize) 설정에 지정된 크기를 갖는 배치가 메시지로 채워질 때
  - 거의 많은 메시지가 들어오는 토픽에 적용됨
- 마지막 배치가 전송된 이후 [`linger.ms`](https://assu10.github.io/dev/2024/06/16/kafka-producer-1/#44-lingerms) 설정에 지정된 시간이 경과될 때
  - 거의 적은 메시지가 들어오는 토픽에 적용됨

`record-queue-time-avg` 지표는 메시지를 쓰는데 걸리는 시간을 나타내므로, 위의 2개의 설정을 애플리케이션의 지연 요구 조건을 만족시키도록 튜닝할 때 도움이 된다.

---

## 4.2. 컨슈머 지표

컨슈머의 경우 메시지를 읽어오는 로직은 단순히 메시지를 브로커로 보내는 것보다 좀 더 복잡한 만큼 다뤄야 할 지표도 조금 더 많다.

<**컨슈머 지표**>

| 이름     | JMX MBean                                                                                         |
|:-------|:--------------------------------------------------------------------------------------------------|
| 컨슈머 전반 | kafka.consumer:type=consumer-metrics,client-id={MY-CLIENT-ID}                                     |
| 읽기 매니저 | kafka.consumer:type=consumer-fetch-manager-metrics,client-id={MY-CLIENT-ID}                       |
| 토픽별    | kafka.consumer:type=consumer-fetch-manager-metrics,client-id={MY-CLIENT-ID},topic={MY-TOPIC-NAME} |
| 브로커별   | kafka.consumer:type=consumer-node-metrics,client-id={MY-CLIENT-ID},nodeid=node-{MY-BROKER-ID}     |
| 코디네이터  | kafka.consumer:type=consumer-coordinator-metrics,client-id={MY-CLIENT-ID}                         |


---

### 4.2.1. 읽기 매니저(fetch manager) 지표

컨슈머 클라이언트에는 중요한 지표들이 읽기 매니저 bean 에 들어있기 때문에 컨슈머 종합 지표 bean 은 상대적으로 덜 유용하다.  
컨슈머 종합 지표 bean 은 저수준의 네트워크 작업에 관련된 지표들을 가지는 반면, 읽기 매니저 bean 은 바이트, 요청, 레코드에 대한 지표를 갖는다.

- **`fetch-latency-avg`**
  - 프로듀서 클라이언트의 `request-latency-avg` 와 마찬가지로 이 지표는 브로커로 읽기 요청을 보내는 데 걸리는 시간을 보여줌
  - 지연은 컨슈머 설정 중 [`fetch.min.bytes`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#51-fetchminbytes) 와 [`fetch.max.wait.ms`](https://assu10.github.io/dev/2024/06/23/kafka-consumer-1/#52-fetchmaxwaitms) 의 영향을 받으므로 이 지표에 경보 설정을 하는 것은 문제가 있음
- **`bytes-consumed-rate`, `records-consumed-rate`**
  - 클라이언트 인스턴스의 읽기 트래픽을 초당 바이트 수 혹은 초당 메시지 수 형태로 보여줌
  - 컨슈머 클라이언트가 얼마나 많은 메시지 트래픽을 처리중인지 알고 싶을 때 유용함
- **`fetch-rate`**
  - 컨슈머가 보내는 초당 읽기 요청 수
- **`fetch-size-avg`**
  - 읽기 요청의 평균 크기를 바이트 수로 나타냄
- **`records-per-request-avg`**
  - 각 읽기 요청의 결과로 주어진 메시지 수의 평균값

> 컨슈머의 lag 모니터링은 [5. lag 모니터링](#5-lag-모니터링) 에서 말하듯이 외부 lag 모니터링을 사용하는 것을 권장한다.

---

### 4.2.2. 컨슈머 코디네이터 지표

컨슈머 클라이언트는 일반적으로 컨슈머 그룹의 일원으로써 함께 동작한다.  
컨슈머 그룹은 그룹 코디네이션 작업을 수행하는데 그룹 멤버 합류가 그룹 멤버십을 유지하기 위해 브로커로 하트비트 메시지를 보내는 것이 여기 들어간다.  
컨슈머 코디네이터는 컨슈머 클라이언트의 일부로써 이러한 컨슈머 그룹 관련된 작업을 수행하며, 자체적인 지표를 유지 관리한다.

코디네이터 관련 작업으로 인해 컨슈머에게 생길 수 있는 가장 큰 문제를 컨슈머 그룹 동기화때문에 읽기 직업이 일시 중지될 수 있다는 것이다.  
이것은 같은 그룹에 속한 컨슈머 인스턴스들이 어느 인스턴스가 어느 파티션을 담당할 지 합의할 때 발생한다.  
그룹 코디네이터는 동기화 작업에 들어간 평균 시간을 **`sync-time-avg`** 지표를 통해 ms 단위로 보여준다.

컨슈머는 메시지를 어디까지 읽어왔는지 기록하기 위해 오프셋을 커밋한다.  
컨슈머 코디네이터는 오프셋 커밋에 걸린 평균 시간을 **`commit-latency-avg`** 지표로 제공한다.  
프로듀서에서 요청 지연을 모니터링하는 것과 마찬가지로, 이 지표의 기대값을 기준으로 하여 threshold 값으로 사용하면 된다.

**`assigned-partitions`** 지표는 특정 컨슈머 클라이언트에게 할당된 파티션의 개수를 보여준다.  
이것은 같은 그룹의 다른 컨슈머 클라이언트와 비교했을 때 컨슈머 그룹 전체에 부하가 고르게 분배되었는지 확인할 수 있게 해준다.

---

## 4.3. 쿼터

카프카는 하나의 클라이언트가 전체 클러스터를 독차지하는 것을 방지하기 위해 클라이언트 요청을 스로틀링하는 기능을 제공한다.  
스로틀링 기능은 프로듀서와 컨슈머 양쪽 다 설정 가능하며, 각 클라이언트 ID 에서부터 각 브로커까지 허용된 트래픽(초당 바이트) 형태로 제공된다.  
모든 클라이언트에 제공되는 기본값은 브로커에 설정하며, 클라이언트별로 동적으로 재정의가 가능하다.

브로커는 클라이언트로 응답을 보낼 대 스로틀링되고 있다는 사실을 알려주지 않으므로, 애플리케이션이 현재 스로틀링되고 있는지 여부를 알기 위해서는 클라이언트 스로틀링 시간을 
보여주는 지표를 모니터링해야 한다.

<**스토틀링 시간을 보여주는 지표**>

| 클라이언트 | Bean 이름                                                                                                            |
|:------|:-------------------------------------------------------------------------------------------------------------------|
| 컨슈머   | bean kafka.consumer:type=consumer-fetch-manager-metrics,client-id={MY-CLIENT-ID},attribute fetch-throttle-time-avg |
| 프로듀서  | bean kafka.producer:type=producer-metrics,client-id={MY-CLIENT-ID},attribute produce-throttle-time-avg             |


---

# 5. lag 모니터링

카프카 컨슈머에 있어서 가장 중요하게 모니터링되어야 하는 것은 컨슈머 lag 이다.  
컨슈머 lag 은 메시지의 수로 측정되는데, 프로듀서가 특정 파티션에 마지막으로 쓴 메시지와 컨슈머가 마지막으로 읽고 처리한 메시지 사이의 차이이다.

컨슈머 lag 지표는 외부 모니터링을 사용하는 것이 클라이언트 자체적으로 제공하는 것보다 훨씬 낫다.  
컨슈머 클라이언트에도 lag 지표인 읽기 매니저 bean 의 `records-lag-max` 속성이 있지만 이 속성의 모니터링을 권장하지 않는다.  
`records-lag-max` 지표는 가장 뒤처진 파티션의 현재 lag (= 컨슈머 오프셋과 브로커의 [`LOG-END-OFFSET`](https://assu10.github.io/dev/2024/09/21/kafka-operation-1/#21-%EC%BB%A8%EC%8A%88%EB%A8%B8-%EA%B7%B8%EB%A3%B9-%EB%AA%A9%EB%A1%9D-%EB%B0%8F-%EC%83%81%EC%84%B8-%EB%82%B4%EC%97%AD-%EC%A1%B0%ED%9A%8C---list---describe---group)) 의
차이를 보여준다.  
`records-lag-max` 의 문제점은 2가지가 있다.
- 가장 지연이 심한 단 하나의 파티션에 대한 lag 만을 보여줌
  - 따라서 컨슈머가 얼만큼 뒤처져있는지 정확하게 보여주지 않음
- 컨슈머가 정상적으로 동작하고 있을 경우를 상정하고 있음
  - 컨슈머에 문제가 생기거나 오프라인 상태가 되면 이 지표는 부정확하거나, 아예 사용 불능이 됨

컨슈머 lag 을 모니터링할 때 선호되는 방법은 브로커의 파티션 상태와 컨슈머 상태를 둘 다 지켜봄으로써 마지막으로 쓰여진 메시지 오프셋과 컨슈머 그룹에 파티션에 대해 
마지막으로 커밋한 오프셋을 추적하는 외부 프로세스를 두는 것이다. 이것은 컨슈머 자체와는 상관없이 갱신될 수 있는 주관적인 관점을 제공한다.

[2. 컨슈머 그룹: kafka-consumer-groups.sh](https://assu10.github.io/dev/2024/09/21/kafka-operation-1/#2-%EC%BB%A8%EC%8A%88%EB%A8%B8-%EA%B7%B8%EB%A3%B9-kafka-consumer-groupssh) 에서 본 것처럼 
컨슈머 그룹 정보, 커밋된 오프셋, lag 을 볼 수 있는 툴이 있지만 이런 식으로 lag 을 모니터링하는 것은 문제가 있다.  
우선 각 파티션에 대해 어느 정도가 적당한 수준의 lag 인지 알아야 한다.  
예) 시간당 100개의 메시지를 받는 토픽과 초당 10만개의 메시지를 받는 토픽에 대한 threshold 는 달아야 함  
또한 모든 lag 지표를 가져다가 모니터링 시스템에 넣고 경고를 설정할 수 있어야 하는데 만일 10만개의 파티션을 가진 1000개의 토픽을 읽는 컨슈머 그룹에 대해 이 작업을 
한다면 매우 힘들 것이다.

그래서 컨슈머 그룹을 모니터링할 때는 버로우(Burrow) 를 사용할 것을 추천한다.  
버로우는 클러스터 내의 모든 컨슈머 그룹의 lag 정보를 가져온 뒤 각 그룹이 제대로 동작하고 있는지, 뒤쳐지고 있는지, 일시 중지되거나 완전히 중지되었는지를 계산하여 보여준다.  
또한, 컨슈머 그룹이 메시지를 처리하는 동작 진척 상황을 모니터링함으로써 threshold 없이도 동작한다.

버로우를 사용하면 단일 클러스터 뿐 아니라 다중 클러스터 환경에서도 모든 컨슈머를 모니터링할 수 있고, 이미 사용중인 모니터링 및 경보 시스템과 연동하기도 쉽다.

> 버로우의 동작 방식은 [Burrow: Kafka Consumer Monitoring Reinvented](https://engineering.linkedin.com/apache-kafka/burrow-kafka-consumer-monitoring-reinvented) 를 참고하세요.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)
* [Git:: cuise-control](https://github.com/linkedin/cruise-control)
* [Git:: kafka-tools](https://github.com/linkedin/kafka-tools)