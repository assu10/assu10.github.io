---
layout: post
title:  "Redis - Redis 튜닝"
date:   2022-10-09 10:00
categories: dev
tags: redis 
---

이 포스트는 Redis 튜닝에 대해 알아본다.

> - 성능 튜닝 포인트
> - 시스템 튜닝
>   - 대기시간 모니터링
> - 서버 튜닝
>   - Swapping 모니터링 및 대응
>   - AOF 파일에서 발생하는 디스크 IO 문제 대응
>   - ScaleOut 을 통한 분산 서버 구축 방안
>   - Redis GDB(Gnu DeBugger) 가이드를 이용한 버그 수집/분석을 통한 안정화 방안
> - Slow-Query 튜닝

---

# 1. 성능 튜닝 포인트

## System 튜닝

Redis 는 메모리 크기, CPU 갯수, 시스템 환경 설정(e.g. Transparent Huge Page, System Process 갯수, Block Size) 등 
시스템 환경이 성능에 미치는 영향이 큰 아키텍쳐 구조이다.

## Server 튜닝

Redis 서버 아키텍처는 메모리 영역, 프로세스 영역, 파일영역으로 구성되어 있고, 각 영역은 최적화된 환경으로 구축되어야 한다.  
만일 구축된 비즈니스 환경과 설계된 데이터 저장 구조가 최적화되지 못한 경우에 관련된 성능 튜닝 영역을 Server 튜닝이라고 한다.

## Query 튜닝

인덱스 생성여부, 잘못된 인덱스 타입 선택 등으로 발생하는 성능 지연과 관련된 튜닝 영역을 Query 튜닝이라고 한다.

## Design 튜닝

데이터가 저장되는 Object 의 논리적 설계(테이블 구조, 인덱스 구조) 상 구조적 문제로 인해 발생하는 성능 튜닝 영역을 Design 튜닝이라고 한다.

---

# 2. 시스템 튜닝

## 디스크 블록 사이즈

- Redis 서버를 설치하기 전 가장 먼저 고려해야 할 점은 디스크 장치의 블록 사이즈 결정임  
포맷되는 디스크 블록 사이즈는 향후 Redis 서버 전용 메모리 영역의 블록 사이즈로 결정되며, AOF, RDB 파일의 블록 사이즈를 결정하는 기준이 되기 때문임.
- 블록 사이즈는 포맷 시점에 한번 결정되면 변경할 수 없기 때문에 충분한 분석과 설계를 통해 결정해야 함
- 디스크 블록 사이즈를 해당 서버에 설치된 Linux 서버의 용도와 데이터 저장량 등을 고려하여 결정해야 함
  - 동접자가 많고 CRUD 작업이 수행될 예정이라면 기본값보다 한 단계 낮게.
  - Batch 작업, 소수의 사용자가 조회 위주의 데이터를 처리하는 용도이면 한 단계 높게.


## NUMA & Transparent Huge Pages(THP) 설정 해제

- Redis 서버는 메모리 영역에 대한 할당과 운영, 관리와 관련된 다양한 메커니즘을 자체적으로 제공하는데  
Linux 서버의 경우에도 시스템 RAM 메모리 영역을 효율적으로 관리하기 위한 메커니즘은 NUMA(Non-Uniform Memory Access) 와 THP (Transparent Huge Page) 를 제공함
- Linux 서버에서 제공하는 메모리 운영 메커니즘들이 작동되는 시스템 환경에서는 Redis 서버에서 제공하는 메모리 운영 메커니즘들이 정상 작동하지 못하기 때문에 성능 지연 문제가 발생할 수 있음
- 이러한 현상은 설치 단계에서 설정 해제를 적극 권장함


## Client Keep Alive Time 설정

- 클라이언트가 Redis 서버에 접속한 후 일정한 타임아웃 시간이 지나면 해당 세션은 종료되고 다시 재접속을 하게 되는 상황에서 즉시 접속이 불가한 상태일 때 Wait Time 이 발생.
- 이와 같은 문제점을 해소하기 위해 클라이언트가 일정 시간동안 작업을 수행하지 않더라고 세션을 일정 시간 유지시킴으로써 재접속을 피하고 Wait Time 을 줄인다.


## Key Expire 를 통한 대기시간 최소화

- Redis 인스턴스엔 오랜 시간 참조되고 있지 않은 Key 들도 존재하는데 이러한 Key 들이 메모리에 지속적으로 저장되어 있는 것은 메모리 효율성을 저하시키고,
메모리 영역 크기가 부족할 때 대기 시간을 증가시키는 원인이 됨.
- 이를 해소하기 위해 Redis 서버는 Key 를 Expire 시키는 기능을 두 가지 형태로 제공함.
  - `LazyFree` 파라메터를 이용하여 더 이상 참조되지 않는 Key 를 메모리에서 제거
  - Redis 서버가 내장하고 있는 `ACTIVE_EXPIRE_CYCLE_LOOKUPS_PER_LOOP` 기능을 이용하여 100 ms 마다 (초당 10회) 만료된 Key 를 자동 삭제   
    (default 20, 초당 200 개의 Key 를 만료시켜 제거해줌)

> `LazyFree` 는 [Redis - 아키텍쳐](https://assu10.github.io/dev/2022/09/03/redis-architecture/) 의 *4. LazyFree* 를 참고하세요.

---

## 2.1. 대기시간 모니터링

- Redis 는 서버에서 발생하는 다양한 문제로 인한 성능 지연 상태에 대한 Wait-Time 을 분석할 수 있는 기능 제공
- OS 커널과 가상화를 하게 되면 HyperVisor(가상화 서버 엔진) 에서 발생하는 Wait-Time 과 Redis 서버에서 발생하는 Wait-Time 은 밀접함
- 성능 지연 문제를 유발하는 다양한 원인 중 HyperVisor 의 Wait-Time 을 모니터링하여 최소화하는 것은 매우 중요

## OS 커널, HyperVisor 에서 발생하는 고유 대기시간(intrinsic latency) 모니터링
```shell
$ redis-cli --intrinsic-latency 10  # 10초 내에 발생하는 latency 분석
Max latency so far: 3 microseconds.
Max latency so far: 4 microseconds.
Max latency so far: 17 microseconds.
Max latency so far: 26 microseconds.
Max latency so far: 38 microseconds.
Max latency so far: 54 microseconds.
Max latency so far: 103 microseconds.
Max latency so far: 250 microseconds.
Max latency so far: 278 microseconds.
Max latency so far: 304 microseconds.

3990275 total runs (avg latency: 2.5061 microseconds / 2506.09 nanoseconds per run).
Worst run took 121x longer than the average latency.  # 평균 지연 시간: 2.5061 microseconds
```

## Network 문제로 인행 발생하는 대기시간 
- Redis 서버 내에서 데이터 처리에 소요되는 시간은 대부분 100 microseconds 범위 내이지만, 클라이언트에서 TCP/IP, Socket 을 통해 서버에 접속하여 데이터를 
전송하는데 30~200 microseconds 가 소요됨 (=데이터 처리 시간보다 클라이언트에서 서버 접속하고, 그 결과를 다시 전달받는데 소요되는 시간이 더 많이 발생)
- 서버에서 실행되는 job, CPU cache, Numa 등과 같은 환경요소는 실행 시간을 추가로 소요시키는 원인들
- 하나의 서버로 시스템을 구축하는 것보다 여러 대로 물리적 서버를 분리하는 것은 성능 개선에 도움을 줌

또한 Redis 는 단일 스레드 작업이 수행되도록 설계되었는데 Batch 작업, 분석 작업들이 같은 CPU 코어에서 작업되지 않도록 분리하는 것이 중요하다.

---

# 3. 서버 튜닝

Redis 서버 설치 시 메모리 영역, 프로세스 영역, 파일 영역으로 구성되는 기본 아키텍쳐가 생성된다.

![Redis Architecture](/assets/img/dev/2022/0903/architecture.jpg)

이 구조가 최적화되지 않은 상태에서 시스템이 구동되면 Redis 서버 성능을 기대할 수 없는데 이에 대한 원인을 분석하고 대응하는 것이 서버 튜닝이다.

---

## 3.1. Swapping 모니터링 및 대응

Redis 서버는 사용 가능한 메모리가 부족한 경우 메모리에 저장된 데이터 일부를 디스크로 저장하거나, 디스크에 저장된 데이터를 메모리로 적재하는 경우가 발생하는데
이를 **Swapping** 이라고 한다.  
Swapping 이 자주 발생하면 이를 수행하기 위해 불필요한 시간이 소요되기 때문에 Redis 서버의 성능 지연 문제가 발생할 수 있다.

- Swapping 이 발생하는 경우
  - Redis 인스턴스에 저장되어 있는 DataSet 이 클라이언트에 의해 더 이상 참조되지 않는 유휴상태일 때 OS 커널에 의해 Swapping 될 수 있음
  - Redis 프로세스 일부는 AOF, RDB 파일을 디스크에 저장하기 위해 작동되는데 이 때 Swapping 이 발생할 수 있음

```shell
$ redis-cli -p 6379 info | grep process_id
process_id:77258
```

- Swapping 최소화 대응
  - Redis 인스턴스 크기를 충분히 할당
  ```shell
  $ vi redis.conf
  maxmemory 1000000000  # Redis 인스턴스 크기 늘려줌 
  ```
     - Redis 서버 설치 시 기본값은 시스템 RAM 메모리가 허용하는 최대 범위까지 사용할 수 있도록 설정됨
     - 이 기본값은 시스템에 하나의 Redis 서버만 독립적으로 설치되고 운영되는 환경이면 문제없지만 다양한 소프트웨어가 함께 운영되면 메모리 효율성이 떨어지게 되며,  
  이는 Redis 서버가 사용할 수 있는 메모리가 부족해짐으로써 성능 지연 문제 유발
     - Redis 서버가 독립적으로 설치된다면 전체 RAM 크기의 약 90% 까지 사용할 수 있도록 maxmemory 크기 설정 권장
  - 빅데이터에 대한 Sorting 작업이 빈번하게 발생하는 테이블, DB 는 해당 DB 에 SWAPDB 를 할당

---

## 3.2. AOF 파일에서 발생하는 디스크 IO 문제 대응

Redis 서버는 In-Memory 아키텍처를 기반으로 하지만 필요에 따라 AOF 와 RDB 파일로 데이터를 디스크에 저장할 수 있지만, 파일 기반의 DBMS 와는 아키텍처가 다르기 때문에
방대한 데이터를 디스크에 저장 관리하는 것은 한계가 있다.

이러한 데이터 저장 구조 환경에서 데이터 일부를 저장하기 위해 AOF 를 사용하게 되는데 과도한 쓰기 작업은 성능 지연 문제를 유발시키며, 이를 피하기 위해선 `appendfsync` 파라메터를 적절히
설정하는 것이 좋다.

```shell
$ vi redis.conf

appendfsync no  # no, everysec, always
```

`appendfsync`
- Redis 인스턴스 상의 데이터를 AOF 파일로 내려쓰기 하는 시점을 언제로 수행할 것인지에 대한 설정
  - `everysec`
    - 1초마다 쓰기 작업 수행
    - 해당 설정 권장
  - `always`
    - 실시간으로 쓰기 작업 수행
    - 중요 데이터 손실은 없지만 성능 지연 문제를 피할 수 없음
  - `no`: default

---

## 3.3. ScaleOut 을 통한 분산 서버 구축 방안


---

## 3.4. 손상된 메모리 영역에 대한 충분한 테스트/검증을 통한 안정화 방안

In-Memory 기반의 Redis 서버와 시스템 RAM 은 매우 밀접한 관계이다.

RAM 의 손상은 Redis 서버의 성능 지연 문제를 유발할 수도 있는데 2가지 방법으로 테스트가 가능하다.

- Redis 서버에서 할당된 메모리 영역에 대한 손상 여부 확인
  ```shell
  $ redis-server --test-memory 2048  # 테스트할 RAM 크기 지정 
  ```
- 하드웨어 RAM 상태를 테스트할 수 있는 3rd-party 이용
  - [https://www.memtest86.com/](https://www.memtest86.com/)

--- 

## 3.5. Redis GDB(Gnu DeBugger) 가이드를 이용한 버그 수집/분석을 통한 안정화 방안

Redis GDB 유틸리티를 이용하여 버그 발생 여부와 로그 내용을 수집하여 개발팀으로 보내면 버그를 해결해주고 있다.

- GDB 유틸리티 특징
  - 현재 실행 중인 Redis 인스턴스에 연결하여 버그가 발새한 시점에 로그 메시지 확인 가능
  - Core 파일에 로그 메시지 저장 가능하며, 이를 Redis 개발팀에 메일로 전달하면 관련 내용 분석 후 조치받을 수 있음
  - GDB 유틸리티의 사용은 Redis 서버 성능 지연 문제를 유발시키지 않기 때문에 안전하게 사용 가가능

---

# 4. Slow-Query 튜닝

## `SLOWLOG` 수집/분석

Redis 서버는 사용자가 실행한 쿼리 중 성능 지연 문제가 발생한 쿼리를 자동으로 수집하여 제공한다.  
수집 결과에 있는 Execution-Time 은 해당 쿼리가 서버에서 실제 실행된 시간 정보를 나타내는데 이 정보는 `SLOWLOG` 명령을 통해 분석할 수 있다.

```shell
127.0.0.1:6379> set 111 222
OK
127.0.0.1:6379> get 111
"222"

127.0.0.1:6379> slowlog ?
(error) ERR unknown subcommand '?'. Try SLOWLOG HELP.

127.0.0.1:6379> slowlog get 2
1) 1) (integer) 0  # slowquery id
   2) (integer) 1665802066  # OS timestamp
   3) (integer) 32073  # 실행 시간(milliseconds)
   4) 1) "config"
      2) "rewrite"
   5) "127.0.0.1:60258"  # 클라이언트 IP, port
   6) ""

127.0.0.1:6379> slowlog len  # 현재 저장되어 있는 slow query 갯수
(integer) 1

127.0.0.1:6379> slowlog reset  # 저장되어 있는 모든 slow query 초기화
OK

127.0.0.1:6379> get 111
"222"

127.0.0.1:6379> slowlog get 2
(empty array)
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [Redis PubSub Demo](https://gist.github.com/pietern/348262)