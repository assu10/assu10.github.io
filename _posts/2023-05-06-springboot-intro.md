---
layout: post
title:  "Spring Boot - MSA 와 Spring Boot"
date:   2023-05-06
categories: dev
tags: springboot msa
---

이 포스팅에서는 아래의 내용에 대해 알아본다.

- 모놀리식 아키텍처와 MSA 의 차이
- MSA 장/단점
- 프레임워크를 선정하는 기준
- Spring 프레임워크와 Spring Boot 프레임워크
- Spring Boot 프레임워크 애플리케이션 시작법

> 소스는 [github](https://github.com/assu10/msa-springboot-2) 에 있습니다.

---

**목차**
- [모놀리식 아키텍처](#1-모놀리식-아키텍처)
  - [모놀리식 아키텍처 장점](#11-모놀리식-아키텍처-장점)
  - [모놀리식 아키텍처 단점](#12-모놀리식-아키텍처-단점)
- [MSA](#2-msa)
  - [MSA 장점](#21-msa-장점)
  - [MSA 단점](#22-msa-단점)
  - [MSA 설계](#23-msa-아키텍처-설계)
- [프레임워크 선정 기준](#3-프레임워크-선정-기준)
- [Spring 프레임워크](#4-spring-프레임워크)
- [Spring Boot 프레임워크](#5-spring-boot-프레임워크)
- [Spring Boot 애플리케이션 시작](#6-spring-boot-애플리케이션-시작)
  - [프로젝트 구성](#61-프로젝트-구성)
  - [Spring Starter 에 포함된 pom.xml](#62-spring-starter-에-포함된-pomxml)
  - [`@SpringBootApplication`](#63-springbootapplication)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap02

---

# 1. 모놀리식 아키텍처

모놀리식 아키텍처는 하나의 시스템이 서비스 전체 기능을 처리하도록 설계한 것으로, MSA 가 작은 단위로 기능을 분리하여 처리하는 것과 반대되는 개념이다.  

소규모 개발팀이 비교적 간단하고 작은 기능을 제공하는 서비스 개발시엔 모놀리식 아키텍처가 효율적이다. 비교적 빠른 시간 안에 개발할 수 있고, 운영과 유지 보수도 편하다.

하지만 서비스 규모가 커지면 확장에 한계가 있으며 기능이 많아질수록 개발 속도나 생산성이 낮아지기 때문에 서비스 고도화에 한계가 생긴다.

---

## 1.1. 모놀리식 아키텍처 장점

- 개발자는 하나의 데이터 저장소에 하나의 애플리케이션을 개발하면 되므로, **데이터를 처리하는 일에만 집중** 가능
  - 애플리케이션도 하나이므로 codebase 도 하나면 충분
- **네크워크로 인한 지연이나 데이터 유실 없음**
  - MSA 는 서비스 단위로 기능이 개발되므로 데이터가 MSA 사이에 전송되며, 이 때 데이터는 네트워크를 통해 전송되면서 지연이나 유실의 위험이 있음
  - 모놀리식 아키텍처는 클래스들의 조합으로 이루어지며, 데이터는 객체들 사이에서만 전달됨
- 시스템 장애나 버그 발생 시 개발자는 하나의 애플리케이션에서 원인 파악 가능
- 데이터 저장소가 하나이므로 **RDB 의 트랜잭션 기능을 쉽게 사용** 가능
- 테스트 환경 구성이 쉬움

---

## 1.2. 모놀리식 아키텍처 단점

- **클라이언트 코드를 수정할 때도 서버를 다시 실행**해야 함
  - 하나의 애플리케이션만 존재하므로 동적 HTML 을 제공하기 위해 JSP, Thymeleaf 같은 탬플릿 엔진을 사용해야 하고, codebase 는 클라이언트 코드와 서버 코드를 포함하게 됨 (=서버 기능과 클라이언트 기능이 섞인 채 개발)
- **소스 코드와 복잡도가 증가**함
  - 비즈니스 영역이 확장되어 앱 서비스도 제공하게 될 때 애플리케이션 서버는 클라이언트 플랫폼과 개발 언어에 관계없는 중립적인 형태의 API 제공이 필요함
  - 이런 경우 HTTP 프로토콜을 사용하는 REST-API 기능이 필요한데 템플릿 엔진으로는 REST-API 개발이 쉽지 않음
  - REST-API 를 제공하기 위해 JSON 직렬화와 역직렬화와 같은 부가적인 코드를 codebase 에 추가해야 함 (=codebase 에 더 많은 코드가 추가됨)
  - 소스 코드가 증가함에 따라 빌드 시간이 늘어나고 코드를 수정하는 일도 어려워짐
  - 개발 속도와 생산성도 낮아짐
- **시스템 확장이 어려움**
  - 예약과 구매 기능이 있는 애플리케이션이 있고, 예약 기능의 요청이 훨씬 많을 경우 서버를 sacle-out 하여 두 처리 능력을 똑같이 선형적으로 늘리는 것은 비효율적임

---

# 2. MSA

MSA (Micro Service Architecture) 는 기능 위주로 나뉜 여러 애플리케이션이 있고, 각각 독립된 데이터 저장소를 사용한다.  
기능으로 분리된 애플리케이션들은 미리 정의된 인터페이스를 통해 서로 유기적으로 동작하여, 각 애플리케이션들은 서버 용량이 다양하고 다양한 언어로 구성할 수 있다.    
예) 예약 기능 / 항공 정보 조회 / 호텔 정보 조회 로 분류

이렇게 기능별로 쪼개인 작은 서비스를 MSA 라고 한다.

MSA 의 대표적인 키워드는 대규모 시스템, 분산 처리 시스템, 컴포넌트들의 집합, 시스템 확장 등이 있다.

**기능이 복잡하고 처리량이 많은 시스템에 적합**하며, 기능이 복잡한 시스템을 편리하게 개발하고 운영하기 위해 **소프트웨어 기능을 서비스 단위로 분류**하고, 
**컴포넌트들은 네트워크를 통해 데이터를 통합**한다.

---

마이크로서비스들은 **다른 마이크로서비스에 독립적으로 구성**되어야 한다.

마이크로서비스 하나에 장애가 발생했을 때 연쇄적으로 장애가 발생하는 **단일 장애 지점이 존재하면 안된다.**
결국 마이크로서비스는 독립적으로 동작해야 하고, 다른 마이크로서비스에 의존성을 최소화해야 한다. (=**느슨한 결합**, loosely coupled)  

따라서 **마이크로서비스마다 각각 독립된 데이터 저장소가 필요**하다. 데이터 저장소를 공유하면 다른 마이크로서비스가 공유 데이터 저장소의 리소스를 모두 차지해서 다른
마이크로서비스가 데이터를 처리하지 못해 데이터 저장소가 단일 장애 지점이 될 수 있기 때문이다. 

예를 들어 호텔 정보 조회는 호텔 마이크로서비스가 담당하지만 호텔, 숙박 예약 일괄 결제는 여러 마이크로서비스 기능이 조합되어야 한다.  
이 때 데이터는 서로 분리되어 있기 때문에 각 마이크로서비스는 네트워크를 통해 서로 기능을 통합한다.

---

마이크로서비스는 **기능과 성격에 맞게 잘 분리**되어야 하는데 특정 마이크로서비스에 기능을 집중하면 서비스 전체가 하나의 마이크로서비스에 의존하게 되고, 너무 세밀하게 분리하면 
수많은 마이크로서비스를 관리해야 한다.

---

각 마이크로서비스 컴포넌트들은 기능 연동 시 API 를 통해 데이터를 주고받는데 이 API 가 사용하는 네트워크 프로토콜이 성능 저하의 원인이 될 수 있다.  
**따라서 통신에 사용되는 네트워크 프로토콜은 가벼워야 한다.**

네크워크를 통해 전달되는 데이터 객체는 바이트 형태로 직렬화되어야 하고, 받는 쪽에선 바이트 데이터를 객체로 역직렬화한다.
직렬화된 바이트 데이터 크기가 크면 네트워크 성능 저하가 발생하고, 직렬화/역직렬화 과정에서 CPU 같은 시스템 리소스를 많이 사용하면 시스템 전반적인 성능 저하가 발생한다.

따라서 시스템 성능 최적화를 위해서는 가벼운 프로토콜을 사용해야 한다.  
보통 JSON 형식의 메시지를 주고 받으며, HTTP 기반의 REST-API 를 사용한다.  
비동기 처리를 위해 AMQP 프로토콜을 사용하는 메시징 큐 시스템 기반으로 데이터를 주고받을 수도 있다. (RabbitMQ, Kafka..)  

메시징 큐 시스템 기반의 데이터 교환은 REST-API 기반의 통신보다 높은 신뢰성을 제공하지만 마이크로서비스 사이에 메시징 큐 시스템에 의존성이 생기는 단점이 있다.
즉, 메시지 큐가 단일 장애 지점이 될 수도 있다는 의미이다.

---

위의 MSA 의 특징을 정리하면 아래와 같다.

- 잘 분리된 마이크로서비스로 인한 탈중앙화
- 대규모 시스템을 위한 아키텍처
- 가벼운 네트워크 프로토콜
- 느슨한 결합
- 서비스 지향 아키텍처


---

## 2.1. MSA 장점

### 독립성

하나의 마이크로서비스는 하나의 비즈니스 기능을 담당하므로 다른 마이크로서비스와 간섭이 최소화되고, 독립된 데이터 저장소를 갖기 때문에 데이터 간섭에도 자유롭다.

---

### 대용량 데이터 처리에 비교적 자유로움

RDB 는 scale-out 이 쉽지 않아 샤딩을 통해 데이터를 분산 저장하기도 하는데 데이터가 분산 저장되면 RDB 의 운영이 쉽지 않다.

MySQL 은 데이터 복제 기능을 이용하여 replica(복제 서버) 를 구성할 수 있는데 replica 는 읽기 성능만 증가할 뿐 생성/수정/삭제 성능은 크게 증가하지 않는다.

NoSQL 의 경우 데이터를 여러 노드에 분산 저장할 수 있는데 데이터 저장소를 확장해야 한다면 여러 노드에 저장된 데이터를 재배치해야한다. (=리밸런싱)  
리밸런싱 작업 시간 동안 각 노드의 CPU, 디스크 I/O 부하가 높아져서 시스템 전반에 부하로 인한 장애가 발생할 수 있다.

마이크로서비스는 독립된 데이터 저장소를 갖기 때문에 **대용량 데이터를 마이크로서비스마다 나누어 저장**할 수 있다. 기본적으로 마이크로서비스 숫자만큼 데이터가 분산 저장되고, 
**샤딩이나 캐시를 마이크로서비스 단위로 각각 적용 가능**하다.

---

### 시스템 장애에 견고

마이크로서비스는 서로 느슨하게 결합되어 있고, 독립적이기 때문에 서로 간의 영향이 적다.

모놀리식 애플리케이션 서버는 HA 방식과 scale-out 을 이용하여 시스템 장애를 대비하는데, 애플리케이션 서버 중 한 대에 장애가 발생한 경우 해당 장비는 격리시킨다.  
하지만 여러 서버에 문제가 발생하거나 버그가 발생하면 서비스 전체로 영향이 확산된다.

마이크로서비스는 하나의 마이크로서비스에 장애가 버그가 발생해도 다른 마이크로서비스는 정상 동작한다.  

> **탄력 회복성(resilience)**  
> 애플리케이션 서버에 장애 발생 시 새로운 컴퓨팅 자원을 추가해서 빠른 시간 안에 서비스를 다시 제공하는 것  
> 예) CPU 70% 이상 사용 시 마지막에 배포한 JAR 파일을 배포한 인스턴스에 새로 추가

---

### 빠른 서비스 배포 주기

모놀리식 아키텍처는 모든 기능이 하나의 codebase 에 있기 때문에 개발된 모든 기능을 한 번에 배포해야 한다.  

마이크로서비스는 모든 기능이 분리되어 있기 때문에 필요한 기능만 먼저 배포할 수 있다.

버그가 발생한 경우 마이크로서비스는 특정 마이크로서비스만 롤백하거나 수정 배포하면 되므로, 모든 기능을 한 번에 배포하는 것보다 부분 기능만 배포하는 것이 버그와 장애에 더 견고하다.

이런 배포는 CI/CD 시스템을 구축해야 빠른 배포가 가능해진다.  
CI/CD 는 배포 자동화가 목적이다.  
CI 는 지속적인 통합을 의미한다. 개발 소스 코드들이 지속적으로 codebase 에 merge 되고 이 때 자동으로 빌드 및 테스트 진행되어야 하는데 이런 배포/빌드/테스트 과정을 지속적이고 자동으로
할 수 있도록 구축된 것이 CI 이다. (예 - Jenkins..)

CD 는 지속적인 배포를 의미한다. CI 를 통해 자동으로 패키징이 되었다면 CD 를 통해 자동으로 해당 시스템에 배포할 수 있어야 한다.  
CD 가 없다면 개발자가 직접 패키징된 파일을 각 서버에 분배한 후 로드 밸런서에서 배포 중인 시스템을 제외한 후 직접 서버를 재기동해야 한다. 

---

### 서비스 확정성 용이

필요한 마이크로서비스만 확장하면 되기 때문에 효율적으로 시스템 자원을 활용할 수 있고, 클라우드 시스템과 결합하면 동적 확장도 가능하다.

---

### 사용자 반응에 민첩 대응 가능

사용자 반응에 따라 시스템을 고도화하거나 빠르게 시스템에서 제외 가능하다.

---

## 2.2. MSA 단점

### 개발이 어려움

마이크로서비스들이 네크워크상에 분산되어 있기 때문에 분리된 데이터, 네크워크를 통한 데이터 통합 등 여러 가지 상황을 고려해야 한다.

마이크로서비스들은 독립적인 데이터 저장소를 갖기 때문에 데이터가 분리되어 있고 그래서 **RDB 의 트랜잭션을 사용할 수 없다.** 따라서 데이터 정합성이 맞지 않는 경우가 발생한다.  
분산 트랜잭션을 사용할 수는 있지만 분산 트랜잭션은 시스템 전체의 리소스를 많이 사용하므로 권장하지 않는다.

**네크워크를 통해 데이터를 통합해야 하는데 네트워크는 신뢰할 수 없고 커넥션 맺는 비용이 비싸다.**  
네크워크는 언제든지 장애가 발생할 수 있고, 패킷은 언제든지 누락될 수 있다. 또한 네트워크 지연이 발생할 수도 있다.

그래서 커넥션 풀을 이용해서 다른 마이크로서비스의 API 를 호출하는데 커넥션 풀을 설정할 때는 반드시 connection timeout (커넥션을 맺는 타임아웃)과 read timeout (요청 데이터를 기다리는 타임아웃) 을
고려해야 한다. 

네트워크 지연 외 데이터 직렬화/역직렬화하는데에도 비용이 발생한다.

여러 장애 상황을 대비하는 fallback 기능을 고려해야 한다.  
fallback 은 네트워크가 정상적이지 않거나 다른 마이크로서비스 운영이 불가한 상태일 때 대비하는 기능이다. 이 기능을 사용하여 어떤 경우라도 사용자에게 서비스되도록 해야한다.

---

### 운영하기 어려움

하나의 사용자 요청을 처리하기 위해 여러 마이크로서비스가 통합되어 이용되는데 만일 요청이 정상 처리되지 않았다면 **어느 단계에서 에러가 발생했는지 찾기 쉽지 않다.**

하나의 사용자 요청을 처리하는데 3개의 마이크로서비스가 이용이 되고, 그 중 1개의 마이크로서비스가 이용 불가 상태라 만일 데이터 원상 복구를 해야한다면 이 때
스케쥴링 프로세스나 상태 머신과 비슷한 saga 패턴을 이용해서 데이터를 원상 복구 혹은 오류가 발생했음을 사용자에게 알려주어야 하는데 이는 개발 난이도가 높다.

---

### 설계하기 어려움

마이크로서비스 관계가 명확하게 구분되지 못하면 각 마이크로서비스가 관리하는 데이터들이 중복될 수 있고, 과도한 네트워크 통신이 발생하여 전체적인 시스템 성능 저하가 유발될 수 있다.

---

### 여러가지 자동화된 시스템 필요

MSA 를 도입하는 이유는 빠른 서비스 개발과 운영, 대규모 서비스를 처리하기 위해서이므로 많은 인스턴스를 빠르게 배포하기 위해 **CI/CD 시스템**이 필요하다.  
수많은 인스턴스의 리소스 지표를 모니터링하고 문제 발생 시 개발자에게 알람을 보내주는 **모니터링 시스템**도 필요하다.  
로그를 통합하여 검색해주는 **로그 통합 시스템**도 필요하다.

---

### 개발자 실력이 좋아야 함

개발자의 기술 성숙도가 낮으면 오히려 개발 속도와 서비스 안정성 면에서 역효과가 날 수 있다.

---

## 2.3. MSA 아키텍처 설계

잘 분리된 마이크로서비스는 서로 겹치지 않고 독립적으로 서비스되어야 한다. 
독립성이 확보되어야 위의 여러 장점들이 발현되는데 그렇다면 '잘 분리하는 것은 어떻게 정의를 해야하는가?' 에 대해 아래 원칙들을 대입해보자.

### 서비스 세분화 원칙

서비스 세분화 원칙은 서비스 지향 아키텍처의 핵심 원칙 중 하나로 4가지 요소를 기반으로 서비스를 나누도록 제안한다.

- 비즈니스 기능
- 성능
  - 마이크로서비스들은 분리되어 있기 때문에 네트워크와 프로토콜을 사용하여 데이터를 주고 받음
  - 이 때 특정 마이크로서비스의 성능이 떨어진다면 해당 서비스를 나누는 것을 고려해야 하는데 성능 저하의 원인이 비효율적인 개발 때문인지 서비스 크기가 너무 커서인지 판단해야 함
- 메시지 크기
  - API 를 설계하는데 메시지 크기가 크다면 마이크로서비스를 나누는 것을 고려
  - 메시지 크기가 너무 크면 직렬화/역직렬화 시 성능 문제 야기
- 트랜잭션
  - 데이터 정합성을 유지하는 트랜잭션으로 서비스는 나누는 것도 좋음

---

### 도메인 주도 설계(DDD) 의 bounded context

DDD(Domain-Driven Design, 도메인 주도 설계) 에서 말하는 [bounded context](https://wikibook.co.kr/article/bounded-context/) 를 이해하면 마이크로서비스 분리 시 도움이 된다.

도메인은 비즈니스 전체 혹은 조직이 하는 일을 의미하고, 도메인은 서브 도메인들로 구분할 수 있다.  
개발자가 도메인 구현 시 도메인 모델을 모델링하는데 이 때 도메인 모델이 존재하는 다른 도메인 모델과 확연히 구분되는 명시적인 경계를 bounded context 라고 한다.

bounded context 는 다른 도메인 모델과 구분되므로 독립적인 영역이며, 이 구분된 bounded context 로 마이크로서비스를 설계하면 다른 마이크로서비스와 중복될 확률이 줄어든다.

---

### 단일 책임 원칙

---

### 가벼운 통신 프로토콜

마이크로서비스는 데이터 통합 시 네크워크를 사용하는데 이 때 응답 지연, 데이터 직렬화/역직렬화 등의 문제가 시스템에 부하를 준다.  
이 부하를 최소한으로 줄이는 설계가 필요하기 때문에 마이크로서비스 간 네트워크 통신을 가벼워야 하고 프로토콜은 특정 기술이나 언어에 의존성이 없어야 한다.

보통 마이크로서비스 간 통신은 HTTP 기반의 REST-API 를 많이 사용한다.

---

### 독립된 데이터 저장소

서비스 복잡성을 낮추기 위해 마이크로서비스로 분리했는데 데이터 저장소를 같이 사용하면 마이크로서비스들은 모놀리식 서비스처럼 강하게 결합되어 독립성이 없어진다.

하나의 데이터 저장소를 사용하게 될 경우 다른 마이크로서비스가 과도하게 DB 를 사용하게 된다면 DB 의 시스템 부하가 높아질 것이고, 같은 DB 를 사용하는 다른 마이크로서비스도 영향을 받는다.

현실적으로 데이터 저장소를 분리할 수 없는 상황이라면 적어도 논리적으로 데이터 저장소를 분리하는 것이 좋다. 하나의 RDB 인스턴스에 DB 를 분리해서 논리적으로라도 각 데이터의 독립성을 보장해주도록 한다.

어떤 마이크로서비스는 데이터 정합성이 중요하고 어떤 마이크로서비스는 처리 속도와 처리량이 중요할 수 있다. 
데이터 정합성이 중요한 서비스는 적합한 RDBMS 데이터를 사용하고, 데이터 조회/노출 서비스는 인메모리 데이터 그리드를 고려할 수 있다.

---

> 클라우드 컴퓨팅 환경에 적합한 개발 방법론인 [클라우드에서의 운영 - 12요소 애플리케이션](https://assu10.github.io/dev/2020/12/27/12factor-app/) 도 읽어보시면 도움이 됩니다.

# 3. 프레임워크 선정 기준

프레임워크 선정 시 먼저 애플리케이션의 요구 사항 취합이 필요하다.  
웹 애플리케이션이라면 HTTP 프로토콜을 사용하는 REST-API 서버가 필요하고, 웹 서비를 제공하는 프레임워크들은 아래 정도가 있다.

- Spring 프레임워크와 내부에 포함된 Spring 웹 MVC 프레임워크
- Spring Boot 프레임워크
- Spark 웹 서버 프레임워크
- Netty 프레임워크

이 때 어느 프레임워크를 선정할 지 아래와 같은 점을 고려할 수 있다.

- 쉽게 확장할 수 있는 eco-system 이 갖추어진 프레임워크
- MSA 를 고려한다면 MSA 에 적합한 프레임워크
- [12요소 애플리케이션](https://assu10.github.io/dev/2020/12/27/12factor-app/) 을 구현하기에 용이한 프레임워크
- 대중적이고 오픈 소스 기여 활동이 왕성하여 유지 보수가 잘되는 프레임워크
- 참고 문서가 많아 장애 대응이 수월한 프레임워크

위에서 Spring 프레임워크와 Spring Boot 프레임워크의 차이점만 간단히 살펴보도록 한다.

Spring 프레임워크는 개발하기 어려운 EJB 를 대체하고자 나온, 엔터프라이즈 애플리케이션을 개발하려고 개발된 경량 프레임워크이다.

> **엔터프라이즈 애플리케이션**  
> 비즈니스 로직이 매우 복잡한 기능이나 여러 기능을 통합한 애플리케이션

Spring Boot 프레임워크는 Spring 프레임워크를 쉽게 사용할 수 있도록 여러 편의 기능을 제공하는 프레임워크이다.
그래서 엔터프라이즈 애플리케이션 개발을 위한 Spring 프레임워크 특징을 그대로 지니면서 수많은 설정을 자동으로 구성해주는 auto configuration 기능과 Starter 기능, Actuator 를 제공하여
쉽고 빠르게 애플리케이션 서버를 만들 수 있다.  
웹 애플리케이션 외 배치 애플리케이션이나 비동기 애플리케이션 등 MSA 를 구성하는 다양한 종류의 애플리케이션을 만들수도 있고, 12 요소 애플리케이션을 디자인하는데 필요한 모든 기능을 프레임워크에서 제공한다.

---

# 4. Spring 프레임워크

Spring 은 여러 가지 프레임워크를 제공하여, 애플리케이션 형태와 기능에 따라 구분할 수 있다.  
예를 들어 배치 애플리케이션은 Spring 배치 프레임워크, 웹 애플리케이션은 Spring 프레임워크에 포함된 웹 MVC 프레임워크, 데이터 처리 시 일관된 방법을 제공하는 Spring 데이터 프레임워크 등으로 구분 가능하다.

이런 프로젝트들을 Spring 프로젝트라고 하고, 메인 프로젝트 안에 서브 프로젝트들로 나뉘기도 한다. 예를 들면 Spring 데이터 프레임워크는 Spring Data Jpa, Spring Data Redis, Spring Data Couchbase 등으로 나뉠 수 있다.

> Spring 애플리케이션의 기본인 Spring bean container 와 Spring bean 은 [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/#1-spring-bean-%EC%82%AC%EC%9A%A9) 의 _1. Spring bean 사용_ 을 참고해주세요.

Spring 프레임워크는 아래와 같은 특징이 있다.

- POJO(Plain Old Java Object) 기반의 경량 컨테이너 제공
- 복잡한 비즈니스 문제를 쉽게 개발/운영
- 모듈식 프레임워크
- 높은 확장성과 범용성, 광범위한 eco-system
- 엔터프라이즈 애플리케이션에 적합한 경량급 오픈 소스 프레임워크

---

### POJO(Plain Old Java Object) 기반의 경량 컨테이너 제공

모든 Spring 애플리케이션은 POJO 객체와 Spring container 를 포함한다.

> **POJO 객체**  
> 특정 기술에 종속되지 않은 순수 자바 객체

개발자는 POJO 클래스를 개발하고, Spring container 는 이 POJO 객체의 생성/의존성 주입/객체 소멸까지의 생명 주기를 관리한다.  
이 때 Spring container 가 관리하는 객체를 **Spring bean** 이라고 한다.  
**Spring container** 는 o.s.context.ApplicationContext 인터페이스를 구현한 클래스들을 의미하며, Spring 프레임워크에서 필요한 핵심 기능과 Spring bean 주입 기능을 제공한다.

---

### 복잡한 비즈니스 문제를 쉽게 개발/운영

Spring 의 3가지 핵심요소를 스프링 트라이앵글이라고 하는데 각각 아래와 같다.

- **의존성 주입 (dependency injection)**
  - 복잡한 클래스들의 관계를 의존성 주입을 통해 해결
- **관점 지향 프로그래밍 (aspect oriented programming)**
  - 로그를 남기거나 트랜잭션을 다루는 비기능적 요구사항을 핵심 기능과 분리
- **서비스 추상화 (portable service abstraction)**
  - 영속성을 예로 들어 설명하면 Spring 에서 제공하는 영속성 프레임워크는 Spring-data-jdbc, mybatis, jpa 등이 있고,
  Spring 프레임워크는 RDB 의 트랜잭션 기능을 정리한 PlatformTransactionManager 인터페이스를 제공함
  - Spring 프레임워크는 각 환경에 적절한 구현 클래스를 제공하며, 개발자는 어떤 프레임워크를 사용하던지 PlatformTransactionManager 의 메서드만 사용하면 됨

---

### 모듈식 프레임워크

---

### 높은 확장성과 범용성, 광범위한 eco-system

Spring 프레임워크는 여러 형태로 확장할 수 있는 범용적인 애플리케이션을 만들 수 있다.  
배치 프로세스는 Spring 배치 프레임워크, 웹 서비스나 REST-API 애플리케이션은 Spring 프레임워크, 인증 서버/인증, 인가는 Spring 시큐리티 프레임워크를 이용할 수 있다.  
Spring 데이터 프로젝트의 확장성만 간단히 보면 아래와 같다.

- Spring Data JDBC
- Spring Data JPA
- Spring Data LDAP
- Spring Data MongoDB
- Spring Data Redis
- Spring Data GemFire
- Spring Data Couchbase
- Spring Data Elasticsearch

---

### 엔터프라이즈 애플리케이션에 적합한 경량급 오픈 소스 프레임워크

---

# 5. Spring Boot 프레임워크

모든 Spring 프로젝트는 Spring 프로젝트를 포함하기 때문에 Spring Boot 프레임워크도 [4. Spring 프레임워크](#4-spring-프레임워크) 의 특징을 모두 갖는다.  

Spring Boot 는 가능한 빠르게 애플리케이션을 개발하고 서비스할 수 있는 것이 가장 큰 장점이다. 필요한 라이브러리를 찾고 적합한 버전을 선택해서 설정하고 테스트하는 과정을 개발자가 할 필요가 없다.  
예를 들어 DB 쿼리 시 JdbcTemplate 를 사용한다고 하면 개발자는 아래 내용을 애플리케이션에 설정해야 한다.

- DataSource 라이브러리 선정 및 설정
- property 파일에 Jdbc url, password, connection pool 설정
- 트랜잭션을 위한 DataSourceTransactionManager 구현체 설정
- JdbcTemplate Spring Bean 설정

Spring Boot 는 이러한 것들은 미리 설정해서 제공하기 때문에 개발자는 Spring Boot 관례에 따라 몇 가지만 설정 후 바로 애플리케이션을 개발할 수 있다.  
Spring Boot 가 이미 각 라이브러리의 버전을 맞춘 후 테스트까지 끝냈기 때문에 그만큼 개발자는 비즈니스 로직 개발에만 신경쓰면 된다.

그럼 Spring Boot 가 추가적으로 제공하는 기능들에 대해 알아본다.


- 단독 실행(Stand-along) 가능한 애플리케이션
- **간편한 설정을 위한 'Starter' 의존성 제공: `spring-boot-starter`**
- **스프링 기능을 자동 설정하는 'AutoConfiguration' 제공: `spring-boot-autoconfigure`**
- 모니터링 지표, 헬스 체크를 위한 'Actuator': `spring-boot-actuator`
- XML 설정이 아닌 java 설정
- 애플리케이션에 내장된 WAS

---

### 단독 실행(Stand-along) 가능한 애플리케이션

Spring Boot 는 빌드 플러그인을 제공하고, 이를 실행하면 stand-alone 가능한 jar 파일을 생성된다. 이 jar 파일을 -jar 옵션과 사용하면 바로 애플리케이션 실행이 가능하다.

클라우드 서비스를 사용하는 경우 시너지 효과가 난다.  
scale-out 방식으로 HA 를 확보하는 경우 호스트에 미리 설치된 WAS 없이 jar 파일만 있으면 되므로 JDK 가 설치된 VM 에 jar 만 배포하면 빠르게 scale-out 이 가능하다.

---

### 간편한 설정을 위한 'Starter' 의존성 제공: `spring-boot-starter`

Spring Boot 프로젝트는 기능별로 라이브러리 의존성을 포함한 Starter 를 제공한다. 이 Starter 는 Maven 이나 Gradle 같은 의존성 관리 툴에서 사용할 수 있다.

라이브러리들의 버전이 상호 호환 검증되었기 때문에 사용자는 쉽게 사용 가능하고, MSA 환경에서 모든 팀이 사용하는 공통 모듈을 Starter 로 만들어서 Nexus 같은 저장소에 배포한 후 사용하면
일관성 있는 애플리케이션 개발이 가능하다.

---

### 스프링 기능을 자동 설정하는 'AutoConfiguration' 제공: `spring-boot-autoconfigure`

Spring Boot 의 모듈인 `spring-boot-autoconfigure` 은 Spring 에서 사용하는 수많은 기능을 자동 설정으로 제공한다.

예를 들면 애플리케이션에 특정 Spring bean 이 있거나 클래스 패스에 특정 라이브러리가 포함괴더나 환경 설정값이 있으면 실행되는 방식이다.

---

### 모니터링 지표, 헬스 체크를 위한 'Actuator': `spring-boot-actuator`

기본 모니터링 지표와 헬스 체크 기능을 `spring-boot-actuator` 모듈을 통해 제공하여 쉽게 활용 가능하다.

---

### XML 설정이 아닌 java 설정

Spring 3.0 부터 xml 이 아닌 java 클래스를 이용하여 설정 가능한 자바 설정 기능을 제공하는데 Spring Boot 도 자바 설정을 기본으로 한다.

`spring-boot-autoconfigure` 를 통해 이미 많은 기능이 미리 설정되어 있다.

---

### 애플리케이션에 내장된 WAS

Spring Boot 의 `spring-boot-starter-web` 을 이용하여 웹 애플리케이션을 개발한 경우 Tomcat 이 내장되어 있다.  

내장된 WAS 덕에 stand-alone 가능한 애플리케이션 배포가 가능하고, 내장된 WAS 와 실행 가능한 jar 파일 덕에 DEV/STAGE/PROD 환경에서 일관된 실행 환경을 가질 수 있다.

---

# 6. Spring Boot 애플리케이션 시작

개발 환경은 아래와 같다.

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- Group: com.assu.study
- Artifact: chap02
- 의존성 관리툴: Maven

---

## 6.1. 프로젝트 구성

프로젝트 구성은 Maven 을 사용하여 구성할 수도 있고, [spring initializer](https://start.spring.io/) 를 이용해서 구성할 수도 있는데 여기선 spring initializer 를 이용하여 구성한다.

![spring initializer](/assets/img/dev/2023/0506/springboot_1.png)

- `Spring Boot DevTool`
  - 애플리케이션 실행 후 클래스 패스에 포함된 파일에 변경이 감지되면 자동으로 애플리케이션 재시작 (LiveReload)
  - Spring Boot 의 웹 서비스에서 사용하는 cache 를 자동으로 막아주는 기능도 제공
  - 이러한 기능은 로컬 환경에서 **개발할 때 필요한 환경이기 때문에 Maven 의 scope 설정을 반드시 runtime 으로 강제**해야 함
    (컴파일 시점에는 클래스 패스에 DevTools 를 제외하여 JAR 파일에 들어가지 않도록 함)
  - [intelliJ] > [Settings] > [Advanced Settings] > [Allow auto-make to start even if developed application is currently running] 체크
  - [intellij] > [Build, Execution, Deployment] > [Compiler] > [Build project automatically] 체크
  - [intellij] > [Run] > [Edit Configurations] > [Modify options] > [On Update Action] 에서 4가지 옵션 중 하나 선택
- `Spring Configuration Processor`
  - 자바 애너테이션 프로세서로 `@ConfigurationProperties` 애너테이션을 분석하여 메타데이터 생성
  - 애플리케이션 설정 시 사용하는 application.yml or application.properties 파일을 IDE 에서 편집할 때 변수 이름을 자동 완성해주고 문서화 기능을 제공해주기 때문에 편리함
- `Lombok`
  - 반복해서 생성해야 하는 코드 대신 Lombok 애너테이션을 사용하여 생산성과 가독성 향상

> **JDK (Java Development Kit)**  
> java 로 개발하는데 사용되는 라이브러리들과 javac, javadoc 등의 개발 도구들이 포함되어 있는 SDK
> JRE 와 JVM 포함  
> 
> **JRE (Java Runtime Environment)**  
> JVM 과 java 프로그램을 실행시킬 때 필요한 라이브러리 API 를 함께 묶어서 배포되는 패키지  
> JDK 에 포함되어 있음  
> JDK 는 java 로 프로그램 개발 시 필요, JRE 는 컴파일된 java 프로그램을 실행 시 필요  
> 
> **JVM (Java Virtual Machine)**  
> java 프로그램을 실행하기 위한 프로그램  
> JRE 에 포함되어 있음

---

## 6.2. Spring Starter 에 포함된 pom.xml

POM (Project Object Model) 파일은 Maven 의 설정 파일이며, **라이브러리들의 의존성을 설정하고 프로젝트를 빌드하는 기능**을 제공한다.

자식 POM 파일은 부모 POM 파일에 설정된 의존 관계를 그대로 상속받을 수 있으며, 자식 POM 파일에 groupId 와 artifactId 만 설정하면 부모 POM 파일에 설정된
version 이나 exclusion 설정을 상속받는다. 만일 자식 POM 파일에 재설정하면 자식 POM 파일에 설정된 의존 관계가 우선시된다.

`spring-boot-starter-parent` 는 spring 애플리케이션 개발에 필요한 모든 라이브러리 의존성 설정 정보를 갖고 있기 때문에 개발자는 필요한 라이브러리 버전을 명시하지 않아도
`spring-boot-starter-parent` 설정 정보를 참조하여 라이브러리를 내려받는다.

`spring-boot-starter-parent` 는 라이브러리 간 버전 충돌이 없는 검증된 버전들만 제공하므로, `spring-boot-starter-parent` 에 버전을 명시하고,
`spring-boot-starter` 는 버전을 생략하여 `spring-boot-starter-parent` 버전을 따라가도록 한다.

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.1.0</version>
    <relativePath/> <!-- lookup parent from repository -->
</parent>
```

`spring-boot-starter` 내부엔 Spring 프레임워크의 spring-core 와 Spring Boot 의 고유 기능인 AutoConfiguration, 로깅, yaml 설정을 포함한다.  
`spring-boot-starter-parent` 가 3.1.0 이므로 `spring-boot-starter` 도 3.1.0 버전을 사용하게 된다.

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter</artifactId>
    </dependency>
    ...
</dependencies>
```

Maven 빌드와 관련된 설정으로 `spring-boot-maven-plugin` 을 사용하면 실행 가능한 jar 나 war 파일을 패키징할 수 있다. 

```xml
<build>
  <plugins>
    <plugin>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-maven-plugin</artifactId>
      <configuration>
        <excludes>
          <exclude>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
          </exclude>
        </excludes>
      </configuration>
    </plugin>
  </plugins>
</build>
```

chap02/pom.xml 전체 코드
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>

	<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>3.1.0</version>
		<relativePath/> <!-- lookup parent from repository -->
	</parent>

	<groupId>com.assu.study</groupId>
	<artifactId>chap02</artifactId>
	<version>0.0.1-SNAPSHOT</version>

	<name>chap02</name>
	<description>Demo project for Spring Boot</description>

	<properties>
		<java.version>17</java.version>
	</properties>

	<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-devtools</artifactId>
			<scope>runtime</scope>
			<optional>true</optional>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-configuration-processor</artifactId>
			<optional>true</optional>
		</dependency>
		<dependency>
			<groupId>org.projectlombok</groupId>
			<artifactId>lombok</artifactId>
			<optional>true</optional>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-test</artifactId>
			<scope>test</scope>
		</dependency>
	</dependencies>

	<build>
		<plugins>
			<plugin>
				<groupId>org.springframework.boot</groupId>
				<artifactId>spring-boot-maven-plugin</artifactId>
				<configuration>
					<excludes>
						<exclude>
							<groupId>org.projectlombok</groupId>
							<artifactId>lombok</artifactId>
						</exclude>
					</excludes>
				</configuration>
			</plugin>
		</plugins>
	</build>

</project>
```

---

## 6.3. `@SpringBootApplication`

JVM 이 시작하며 메일 클래스의 main() 메서드를 실행하여, 이 main() 메서드를 entry point 라고 한다.  
이제 메인 클래스인 Chap02Application.java 를 보자.

Chap02Application.java
```javas
package com.assu.study.chap02;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Chap02Application {

	public static void main(String[] args) {
		SpringApplication.run(Chap02Application.class, args);
	}

}
```

`@SpringBootApplication` 은 3개의 주요 애너테이션을 포함하고 있다.
```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@SpringBootConfiguration
@EnableAutoConfiguration
@ComponentScan(
    excludeFilters = {@Filter(
    type = FilterType.CUSTOM,
    classes = {TypeExcludeFilter.class}
), @Filter(
    type = FilterType.CUSTOM,
    classes = {AutoConfigurationExcludeFilter.class}
)}
)
public @interface SpringBootApplication {
    ..
}
```

- `@SpringBootConfiguration`
  - 내부에 `@Configuration` 을 포함하고 있으며, `@Configuration` 이 정의된 클래스는 자바 설정 클래스하고 함
  - 자바 설정 클래스는 별도의 Spring bean 을 정의할 수 있음
  - 따라서 `@SpringBootConfiguration` 이 정의된 이 파일도 자바 설정 클래스이며, 클래스 내부에는 Spring bean 설정을 포함할 수 있음
  - > 자바 설정 클래스와 Spring bean 설정은 [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/) 를 참고해주세요.
- `@EnableAutoConfiguration`
  - `@Configuration` 과 같이 사용하면 Spring Boot 의 AutoConfiguration 기능을 활성화함
  - 즉, `@EnableAutoConfiguration` 에 의해 Spring Boot 의 자동 설정 클래스들이 실행되어 애플리케이션을 설정함
- `@ComponentScan`
  - 클래스 패스에 포함되어 있는 `@Configuration` 으로 정의된 자바 설정 클래스와 스테레오 타입 애너테이션으로 정의된 클래스를 스캔함
  - Spring bean 설정을 스캔하여 Spring bean Container 가 Spring bean 으로 로딩하고 관리함
  - > 스테레오 타입 애너테이션은 [Spring Boot - Spring bean, Spring bean Container, 의존성](https://assu10.github.io/dev/2023/05/07/springboot-spring/#3-%EC%8A%A4%ED%85%8C%EB%A0%88%EC%98%A4-%ED%83%80%EC%9E%85-spring-bean-%EC%82%AC%EC%9A%A9) 의 _3. 스테레오 타입 Spring bean 사용_
     를 참고하세요.

정리하면 `@SpringBootApplication` 에 의해 클래스 패스 내 애플리케이션 설정을 위한 자바 설정 클래스와 Spring bean 클래스들을 스캔하여 Spring container 에 등록하고,
Spring Boot 의 Auto Configuration 기능이 동작한다.

---

이제 SpringApplication.run() 메서드를 보자.
SpringApplication 클래스는 Spring Boot 애플리케이션을 실행하는 Bootstrap 클래스이다. 

> **Bootstrap**  
> 실행하면 필요한 일련의 과정이 한 번에 실행되는 것

SpringApplication.run() 에서 ApplicationContext 객체를 생성하는데 ApplicationContext 는 Spring bean 을 로딩하고 관리하는 Spring bean container 이다.  

SpringApplication 클래스는 지연 초기화 기능을 제공하는데 이 기능을 활성화하면 애플리케이션이 실행될 때 모든 Spring bean 객체를 한 번에 생성하지 않으므로 애플리케이션 시작 시간이 단축된다.
하지만 요청이 빈번한 시간에 배포하거나 scale-out 한다면 첫 번째 요청을 느려질 수 있기 때문에 default 는 지연 초기화 기능이 비활성화되어 있다.
활성하하고 싶다면 SpringApplication 클래스의 setLazyInitialization() 메서드로 활성화한다.

---

이제 properties 파일을 설정해본다.

/resource/application.properties
```properties
server.port=18000
## 톰캣 워커 스레드 풀의 최소값
server.tomcat.threads.min-spare=100
## 톰캣 워커 스레드 풀의 최대값
server.tomcat.threads.max=100
```

/chap02/ApiApplication.java
```java
package com.assu.study.chap02;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.Environment;

import java.util.Arrays;

@Slf4j
@SpringBootApplication
public class ApiApplication {
    public static void main(String[] args) {
        // Spring bean container 인 ApplicationContext 객체 리턴
        ConfigurableApplicationContext ctx = SpringApplication.run(Chap02Application.class, args);

        // application.properties 의 내용을 가져오기 위해 Environment 객체 가져옴
        // Environment 객체도 Spring bean 객체임
        Environment env = ctx.getBean(Environment.class);
        String portValue = env.getProperty("server.port");
        log.info("My port: {}", portValue);

        // ApplicationContext 객체가 관리하고 있는 Spring bean 들의 이름 조회
        String[] beanNames = ctx.getBeanDefinitionNames();
        Arrays.stream(beanNames).forEach(name -> log.info("Bean name: {}", name));
    }
}
```

---

앞으로 포스팅마다 프로젝트를 별개로 가져갈 예정이므로 parent pom.xml 과 child pom.xml 파일을 설정한다.

/pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <packaging>pom</packaging>
    <modules>
        <module>chap02</module>
    </modules>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.0</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>

    <groupId>com.assu</groupId>
    <artifactId>study</artifactId>
    <version>1.1.0</version>

    <name>study</name>
    <description>Demo project for Spring Boot</description>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>

</project>
```

/chap02/pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>

	<parent>
		<groupId>com.assu</groupId>
		<artifactId>study</artifactId>
		<version>1.1.0</version>
	</parent>

	<artifactId>chap02</artifactId>

</project>
```


---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [bounded context](https://wikibook.co.kr/article/bounded-context/)
* [클라우드에서의 운영 - 12요소 애플리케이션](https://assu10.github.io/dev/2020/12/27/12factor-app/)
* [spring initializer](https://start.spring.io/)
* [JDK/JRE/JVM 개념](https://inpa.tistory.com/entry/JAVA-%E2%98%95-JDK-JRE-JVM-%EA%B0%9C%EB%85%90-%EA%B5%AC%EC%84%B1-%EC%9B%90%EB%A6%AC-%F0%9F%92%AF-%EC%99%84%EB%B2%BD-%EC%B4%9D%EC%A0%95%EB%A6%AC)