---
layout: post
title:  "NoSQL 개념"
date:   2022-05-29 10:00
categories: dev
tags: redis
---

이 포스팅은 NoSQL 의 종류와 그 중 Key-Value DB 인 Redis 에 대해 알아본다.

> - NoSQL 종류
> - Key-Value DB 특징
>   - In-Memory 기반의 데이터 저장 구조
>   - 하나의 Key 와 데이터 값으로 구성
>   - 가공처리가 요구되는 비즈니스 환경에서 적합
> - Redis

---

# 1. NoSQL 종류

- **Key-Value DB**
  - `Redis`, `Riak`, `Tokyo`
- **Document DB** 
  - `MongoDB`, `CoughDB`
- **ColumnFamily DB**
  - `Hbase`, `Cassandra`
- **Graph DB** 
  - `Neo4j`, `AllegroGraph`


![NoSQL 가이드라인](/assets/img/dev/2022/0529/guideline.jpg)


분산 기술은 여러 대의 서버에 데이터를 나누어 저장하는 개념인데 초당 몇 만건 이상의 빅데이터를 동시에 저장하다 보면 예기치 못한 문제로 시스템에 종료되어 데이터가
유실되는 경우가 발생한다.  
이를 방지하기 위해 반드시 Replication 시스템을 함께 구축해야 한다.

NoSQL 은 기본적으로 듀얼 라이선스 (Community Edition, Enterprise Edition) 정책으로 제공한다.

엔터프라이즈 에디션의 경우 초기 구매 비용이 발생하는데 그 이유는 커뮤니티 에디션에는 없는 추가 SW 들이 내장되어 있고, 향후 1년간 유지보수 비용이 포함되어 있기 때문이다.

---

# 2. Key-Value DB 특징

## 2.1. In-Memory 기반의 데이터 저장 구조

관계형 DBMS 의 인메모리는 파일 기반의 데이터 저장 구조이고, `Redis` 는 **순수 인메모리 기반의 데이터 저장 구조**이다.  
파일 기반의 데이터 저장 구조는 일단 모든 데이터는 1차적으로 메모리에 우선 저장되었다가 2차적으로 디스크에 존재하는 파일에 저장되며,  
파일들은 DBMS 에 의해 할당되고 자동으로 관리되는 시스템이다.  

순수 인메모리 기반은 1차적으로 모든 데이터는 메모리에 저장되며, 사용자 명령어 혹은 시스템 환경 설정을 통해 필요에 따라 디스크에 존재하는 파일에 저장된다.  
만약 사용자가 추가적인 관리를 안해주면 모든 데이터는 메모리 상에만 존재하여 예상치 못한 장애 발생 시 모든 데이터는 유실된다.

## 2.2. 하나의 Key 와 데이터 값으로 구성

관계형 DB 에서 데이터의 빠른 검색을 위해 인덱스를 사용하는 것처럼 Redis 에서도 인덱스를 생성할 수 있지만 인덱스의 종류 및 구조가 많이 다르기 때문에 표현에 
한계가 있을 수 있다.

## 2.3. 가공처리가 요구되는 비즈니스 환경에서 적합

Redis 와 Memcached DB 를 운영하고 있는 환경을 보면 대부분 Redis/MongoDB, Redis/Cassandra, Redis/MySQL 등 하이브리드 구조로 운영된다.  
보통 Redis 와 Memcached DB 는 보조 DB 로 사용하는데 그 이유는 대부분 메인 DB 로 선택한 제품들은 파일 기반의 저장 구조이다 보니 디스크 IO 문제로 인해 
발생하는 성능 지연 문제를 해소하기 위해 K-V DB 를 보조 DB 로 사용하는 것이다.

즉, 데이터의 가공처리, 통계분석, 데이터 캐싱, 메시지 큐 등의 용도로 사용할 수 있다.

---

# 3. Redis

Redis 는 Remote Directory System 의 약어로 아래는 **Redis 의 주요 특징**들은 아래와 같다.

- 대표적인 인메모리 기반의 데이터 처리 및 저장 기술을 제공하기 때문에 다른 NoSQL 제품에 비해 상대적으로 빠른 Read/Write 가능
- `String`, `Set`, `Sorted Set`, `Hash`, `List`, `HyperLogLog` 유형의 데이터 저장 가능
- Dump 파일과 AOF (Append Of File) 방식으로 메모리 상의 데이터를 디스크에 저장
- Master/Slave Replication 기능을 통해 데이터의 분산, 복제 기능 제공  
  `Query Off Loading` 기능을 통해 Master 는 Read/Write 를 수행하고, Slave 는 Read 만 수행
- 파티셔닝을 통해 동적인 스케일 아웃인 수평 확장 가능
- Expiration 기능을 통해 메모리 상의 데이터 자동 삭제 가능


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)