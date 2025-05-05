---
layout: post
title:  "Redis - Redis Cluster & Monitoring (1)"
date: 2022-09-17 10:00
categories: dev
tags: redis 
---

이 포스트는 Redis 의 복제 시스템 구성과 FailOver 처리에 대해 알아본다.

<!-- TOC -->
* [1. 복제 & 분산 시스템](#1-복제--분산-시스템)
  * [1.1. 파티션 유형](#11-파티션-유형)
    * [Range Partition (범위 파티션)](#range-partition-범위-파티션)
    * [Hash Partition](#hash-partition)
  * [1.2. 파티션 구현 방법](#12-파티션-구현-방법)
    * [Client Side Partitioning](#client-side-partitioning)
    * [Proxy Assisted Partitioning](#proxy-assisted-partitioning)
    * [Query Routing](#query-routing)
* [2. Master & Slave & Sentinel](#2-master--slave--sentinel)
  * [2.1. 시스템 설정](#21-시스템-설정)
    * [Master-Slave](#master-slave)
    * [Master-Slave-Sentinel](#master-slave-sentinel)
    * [Master-Slave-Sentinel 구축 및 FailOver Test](#master-slave-sentinel-구축-및-failover-test)
  * [2.2. 장애 처리 방법](#22-장애-처리-방법)
  * [2.3. Sentinel 명령어](#23-sentinel-명령어)
* [3. 부분 동기화](#3-부분-동기화)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 복제 & 분산 시스템

Redis 는 초당 5~10만건 이상의 데이터를 빠르게 read/write 할 수 있도록 **scale-out** 기능인 `파티셔닝` 을 제공하는데 **`파티셔닝` 은
대표적인 데이터 분산 처리 시스템**이다.

RDBMS 도 데이터 분산 처리를 위해 striping 과 파티셔닝 기법을 제공하지만 이것은 하나의 논리적 데이터 구조인 테이블을 여러 개의 물리적 디스크 장치에
분산 저장하는 개념이다. (= scale-up, 하나의 서버 내에서 시스템 자원을 확장하여 데이터 저장 관리)

Redis 서버는 **Master-Slave**, **Master-Slave-Sentinel**, **Partition Cluster** 기능을 통해 데이터를 복제하고 분산 처리한다.

> `striping` 은 [Redis - 데이터 모델링](https://assu10.github.io/dev/2022/08/29/redis-data-modeling/) 의 *3. 논리적 DB 설계* 를 참고하세요.

**분산 저장의 목적**
- **자원 공유**
  - 하나의 서버에서 사용할 수 있는 시스템 자원은 제한적이므로 순간적인 과부하 발생 시 다른 서버의 자원을 함께 사용함으로써 동시에 빠른 처리 가능
- **성능 향상**
  - 하나의 서버에 연속적인 데이터 작업을 하는 경우 과부하로 인해 대기 상태가 되었을 때 시스템 전체의 성능 지연을 유발하는데 이 때 다른 서버가
  연속적인 데이터를 처리할 수 있도록 하여 성능 지연을 피함 (=Load Balancing)
- **안정성**
  - 복제 서버: 분산 서버에 장애가 발생하는 경우 실시간으로 데이터를 복제해두었다가 장애가 발생한 서버를 대체하여 작동되는 서버

---

> Redis 서버 환경에서 파티셔닝 기능을 이용한 분산 처리는 적극 권장하지는 않는다고 한다.
1. 2개의 데이터셋이 여러 개의 인스턴스에 동시에 저장되어 있는 경우 트랜잭션 제어를 완벽하게 지원하지 않음
2. 새로운 노드를 추가하고 기존 노드를 실시간으로 제거하는 작업은 하나의 큰 파티션 영역을 새롭게 분할/합병하는 작업이 요구되는데 이 경우 rdb, aof 파일을 백업 후 이전해야 함
3. 런타임에서 노드 추가/제거 작업이 수행되는 단계에서 전체 서버의 균형을 맞추기 위한(?) ReBalancing 작업을 수행해야 하는데 이 때 성능 지연이 발생할 수 있음


## 1.1. 파티션 유형

### Range Partition (범위 파티션)

분산 서버는 최소 2대부터 운영 가능하지만 하나의 서버에 장애가 발생하는 경우 지속적으로 분산 처리가 불가능하기 때문에 3대 이상을 권장한다.

최초 서버 대수를 결정하는 것은 Range Partition 방식에서 중요한데 그 이유는 특정 범위의 key-value 를 어느 서버에 저장할 것인지 사용자가 사전에 결정해야 하므로
서버 대수에 따라 저장되는 위치가 결정되기 때문이다.(= key 값을 기준으로 특정 범위의 데이터들을 특정 샤드 서버로 분산 저장)

### Hash Partition

Range Partition 은 사용자가 지정한 서버로 특정 부위의 값을 저장할 수 있다는 장점이 있지만, 사용자가 직접 설계하다보니 각 분산 서버에 저장되는 데이터 분산 정도가 떨어지는 경우가 있다.

Hash Partition 은 Hash 알고리즘에 의해 데이터를 각 분산 서버로 골고루 분산 저장해준다.

---

## 1.2. 파티션 구현 방법

Redis 서버 환경에서의 분산 처리 방법은 크게 **Client Side Partitioning**, **Proxy Assisted Partitioning**, **Query Routing** 세 가지가 있다.

### Client Side Partitioning

각 서버에 저장될 데이터 성격과 양을 사용자가 직접 설계하는 방식이다. (일반적인 데이터 분산은 서버에서 제공하는 자동화 메커니즘에 의해 특정 서버로 저장됨)  
예) 데이터 양이 많은 성격의 데이터는 1번 서버에 저장, 그 외 양이 적은 데이터들은 2번 서버에 함께 저장  

Redis 서버를 이용하는 대부분의 환경에서 보편적으로 사용하는 방법이다.

Master-Slave, Redis Cluster Data Sharding 기능을 통해 구현할 수 있다.

### Proxy Assisted Partitioning

위의 Client Side Partitioning 은 모든 것을 사용자가 설계,구현하기 때문에 결코 쉬운 방법이 아니다.  

Proxy Assisted Partitioning 방식은 분산 서버 이외의 별도의 Proxy Server 가 필요한데,  
Proxy Server 는 현재 분산 서버의 모든 상태 정보를 수집/저장하여
사용자가 대량의 데이터 저장을 요청하는 경우 가장 적절한 분산 서버를 찾아서 데이터를 저장하고, 특정 데이터 검색 시 해당 데이터가 저장되어 있는 서버 정보를 분석하여 데이터를 검색한다.  
Proxy Server 는 별도의 분리된 서버에 구축하는 것을 권장한다.

Proxy Assisted Partitioning 은 Redis 서버 에서 기본적으로 제공하지는 않으며 *Twemproxy Cluster* 와 같은 오픈 소스와 연동하여 구축해야 한다.

> *Twemproxy Cluster*  
> Apache 2.0 오픈 소스로 여러 개의 Redis 인스턴스에 자동 파티셔닝해주며 Redis 를 Cache 용으로 사용하는 경우에만 사용 가능

### Query Routing

이 방식은 위의 *Hash Partition* 으로 데이터를 분산 저장하며, 특정 분산 서버에 장애가 발생하면 사용 가능한 Slave 서버를 통해 지속적인 읽기 작업이 가능하고, 
사용 가능한 서버로 자동 전환해준다.

오픈 소스로 제공하는 *redis-rb* 혹은 *Predis* 솔루션을 통해 구현 가능하다.

---

# 2. Master & Slave & Sentinel

## 2.1. 시스템 설정

Redis 서버에서 제공하는 복제 시스템은 **Master-Slave**, **Mater-Slave-Sentinel** 서버 구성이다.

### Master-Slave

데이터를 실시간으로 처리(CRUD)하는 Master 서버 1대에 대해 Slave 서버를 마스터 서버의 데이터가 실시간으로 복제된다. (Slave 서버는 읽기 작업만 가능)

Master 서버에 장애가 발생하는 경우 Slave 서버는 Master 서버로 자동 전환(`FailOver`) 되지 않지 않기 때문에 일시적인 서비스 중단이 발생한다.

### Master-Slave-Sentinel

Master 서버에 장애가 발생하는 경우 Slave 서버를 Master 서버로 전환시켜 지속적인 CRUD 작업이 가능하도록 해주는데 이를 위해선 Sentinel 서버를 추가로 구축해야 한다.

**`Sentinel Server`**

- Master 서버와 Slave 서버를 거의 실시간으로 HeartBeat 를 통해 모니터링하다가 Master 서버에 장애가 발생한 경우 Slave 서버를 즉시 Master 서버로 자동 전환(FailOver) 시켜 데이터 유실을 막음
- 서버에 장애 발생 시 SMS, email 등을 통해 상태 정보 전달 가능
- 사용자 데이터가 저장되지 않고 오직 서버의 장애 상태만을 모니터링하므로 좋은 사양의 하드웨어는 필요하지 않음
- 원본 Sentinel 서버의 장애가 발생할 경우를 대비하여 3대의 Sentinel 서버 권장

### Master-Slave-Sentinel 구축 및 FailOver Test

redis.conf, redis-6300.conf, redis-sentinel.conf 수정
```shell
$ pwd
/usr
/local/etc

# Master (redis.conf)
daemonize yes  # 백그라운드에서 인스턴스 구동
port 6379

logfile "/usr/local/var/db/redis/redis_6379.log"

# Slave (redis-6300.conf)
daemonize yes  # 백그라운드에서 인스턴스 구동
port 6300
slaveof 127.0.0.1 6379  # slave 가 바라볼 Master 정보

logfile "/usr/local/var/db/redis/redis_6300.log"

# Sentinel (redis-sentinel.conf)
daemonize yes  # 백그라운드에서 인스턴스 구동
port 6400
sentinel monitor mymaster 127.0.0.1 6300 1  # 센터널 서버가 바라볼 Master 서버 정보
sentinel down-after-milliseconds mymaster 3000  # 장애 발생 시 FailOver 타임아웃 (3초)

logfile "/usr/local/var/db/redis/redis_sentinel.log"
```

- `sentinel monitor mymaster 127.0.0.1 6300 1`  # 센터널 서버가 바라볼 Master 서버 정보
  - mymaster: Master alias
  - 1: Quorum(정족수)
       Sentinel 서버가 3대인 경우 그 중 2대 이상의 Sentinel 에서 Master 서버가 down 된 상태를 인식하면 장애처리 작업 수쟁  
       전체 3대 중 (3/2)+1 이상을 정족수라고 함  
       Sentinel 이 2대 이고, quorum 이 2이면 Sentinel 1대가 down 되더라도 failover 는 발생하지 않음
- `sentinel down-after-milliseconds mymaster 3000`  # 장애 발생 시 FailOver 타임아웃 (3초)
- `sentinel auth-pass mymaster redis123`  # Master, Slave 접속 시 적용할 암호


redis-server start
```shell
# Master start
$ redis-server /usr/local/etc/redis.conf

# Slave start
$ redis-server /usr/local/etc/redis-6300.conf

# Sentinel start
$ redis-server /usr/local/etc/redis-sentinel.conf --sentinel
```

redis-cli start
```shell
# Master start
$ redis-cli -p 6379

127.0.0.1:6379> info replication

# Replication
role:master  # 현재 서버가 Master 서버임을 확인
connected_slaves:1  # 해당 Master 서버에 하나의 Slave 서버 존재
slave0:ip=127.0.0.1,port=6300,state=online,offset=47714,lag=1
master_failover_state:no-failover
master_replid:119e940fe276c0994f34d362aa629d49c45a7dd8
master_replid2:24eda8ba343cf455e4b9044def109fcea66bbdae
master_repl_offset:47714
second_repl_offset:46599
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:46599
repl_backlog_histlen:1116

127.0.0.1:6379> role
1) "master"
2) (integer) 47846
3) 1) 1) "127.0.0.1"
      2) "6300"
      3) "47846"

127.0.0.1:6379> set foo bar
127.0.0.1:6379> get foo
bar      
      
      
# Slave start
$ redis-cli -p 6300

127.0.0.1:6300> info replication

# Replication
role:slave  # 현재 서버가 Slave 임을 확인
master_host:127.0.0.1  # Master 서버의 아이피
master_port:6379  # Master 서버의 port
master_link_status:up
master_last_io_seconds_ago:1
master_sync_in_progress:0
slave_read_repl_offset:50264
slave_repl_offset:50264
slave_priority:100
slave_read_only:1
replica_announced:1
connected_slaves:0
master_failover_state:no-failover
master_replid:119e940fe276c0994f34d362aa629d49c45a7dd8
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:50264
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:47560
repl_backlog_histlen:2705

127.0.0.1:6300> role
1) "slave"
2) "127.0.0.1"
3) (integer) 6379
4) "connected"
5) (integer) 50542

127.0.0.1:6300> get foo
bar      


# Sentinel start
$ redis-cli -p 6400

127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:1  # 현재 서버가 Sentinel 서버임을 확인
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=127.0.0.1:6379,slaves=1,sentinels=1  # 6379 가 Master

127.0.0.1:6400> role
1) "sentinel"
2) 1) "mymaster"
```

FailOver 를 테스트하기 위해 Master 서버 shutdown
```shell
127.0.0.1:6379> shutdown
not connected>
```

6300 Slave 서버가 Master 로 승격되었는지 확인
```shell
127.0.0.1:6300> info replication
# Replication
role:master
connected_slaves:0
master_failover_state:no-failover
master_replid:ccf47bf578609b5cddef8e77aa1c8b5b372eb4de
master_replid2:119e940fe276c0994f34d362aa629d49c45a7dd8
master_repl_offset:153249
second_repl_offset:150191
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:47560
repl_backlog_histlen:105690

127.0.0.1:6300> role
1) "master"
2) (integer) 153381
3) (empty array)


127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=127.0.0.1:6300,slaves=1,sentinels=1
```

FailOver 되어 Slave(6300) 서버가 Master 서버로 승격된 이후 기존의 Master(6379) 를 기동해도 6379 는 Slave 가 된다.

---

## 2.2. 장애 처리 방법

아래는 Sentinel 서버가 장애를 인지하고 FailOver 하는 프로세스이다.  

- Sentinel 서버가 매 1초마다 HeartBeat 를 통해 Master/Slave 서버의 작동 여부 확인
  - 일정 Timeout 동안 응답이 없으면 장애 발생으로 간주하는데 이것을 `주관적 다운(Subjectively Down)` 이라고 하며,  
    로그 파일에 `+sdown` 상태로 표기됨
  - 타임아웃 시간은 *sentinel.conf* 파일에 정의되어 있는 `down-after-milliseconds` 로 결정됨 (default 3000 millisecond)
- 주관적 다운은 하나의 Sentinel 서버가 장애를 인지한 경우이며,  
  여러 대의 Sentinel 서버로 구성되었을 때 모든 Sentinel 서버가 장애를 인지하면 `객관적 다운(Objectively Down)` 이라고 함  
  로그 파일에 `+odown` 상태로 표기됨
  - Sentinel 서버는 Master 서버가 다운된 경우 다른 Sentinel 서버와 함께 Quorum(정족수) 를 확인한 후 조건이 충족하면 최종적으로 다운되었다고 판단함
- 주관적 다운과 객관적 다운이 최종 확인되면 장애 조치 작업 수행
  - Sentinel 서버가 여러 대인 경우 Sentinel 리더 선출
  - 리더 Sentinel 서버는 장애가 발생한 Master 서버를 대신할 Slave 서버 선정
  - 선정된 Slave 서버는 Master 서버로 승격됨
  - 남은 Slave 서버가 새로운 Master 서버를 모니터링하도록 명령 수행
  - 위 작업이 완료되면 Sentinel 서버 정보 갱신 후 장애 복구 작업 종료

> **Sentinel 서버 리더 선출**    
> `sentinel.conf` 파일의 `down-after-milliseconds` 는 주관석 다운 상태를 인지할 수 있도록 설정된 타임아웃 값인데 이 값을 각각 다르게 설정하여
> 제일 작게 설정된 Sentinel 서버가 다운된 경우 그 다음으로 작게 설정된 두 번째 서버가 리더로 선정됨

> **Slave 서버 중 Master 서버 선정**  
> `redis.conf` 의 `slave-priority` 의 값에 따라 우선 순위가 결정됨.  
> `slave-priority` 가 서버 1,2,3 각각 100, 300, 200 이고 서버1(100) 이 Master 서버일 때 Master 서버에 장애가 발생한 경우 서버3(200) 이 Master 서버로 
> FailOver 됨.

---

## 2.3. Sentinel 명령어

redis-server start
```shell
# Master start
$ redis-server /usr/local/etc/redis.conf

# Slave start
$ redis-server /usr/local/etc/redis-6300.conf

# Sentinel start
$ redis-server /usr/local/etc/redis-sentinel.conf --sentinel
```

redis-cli start
```shell
# Master start
$ redis-cli -p 6379

# Slave start
$ redis-cli -p 6300

# Sentinel start
$ redis-cli -p 6400

127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:1  # 현재 서버가 Sentinel 서버임을 확인
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=127.0.0.1:6379,slaves=1,sentinels=1  # 6379 가 Master

127.0.0.1:6400> role
1) "sentinel"
2) 1) "mymaster"
```

sentinel 명령어 - 1
```shell
127.0.0.1:6400> info sentinel  # sentinel, master/slave 서버 상태 조회
# Sentinel
sentinel_masters:1  # 모니터링하고 있는 master 수
sentinel_tilt:0  # 0: 정상, 1: 보호모드(모니터링만 하고 장애조치 안함)
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0  # 실행 중인 스크립스 수
sentinel_scripts_queue_length:0  # 실행 대기 중인 스크립트 수
sentinel_simulate_failure_flags:0  # sentinel 서버 임의 다운 횟수
master0:name=mymaster,status=ok,address=127.0.0.1:6300,slaves=1,sentinels=1


127.0.0.1:6400> info server
# Server
redis_version:7.0.4
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:ef6295796237ef48
redis_mode:sentinel  # 해당 서버의 용도
os:Darwin 21.6.0 x86_64
arch_bits:64
monotonic_clock:POSIX clock_gettime
multiplexing_api:kqueue
atomicvar_api:c11-builtin
gcc_version:4.2.1
process_id:88121
process_supervised:no
run_id:84d9fdffe82f140ca897e0f7d66ddf644abbbe5f
tcp_port:6400  # sentinel 서버 port no
server_time_usec:1665638429760513
uptime_in_seconds:954
uptime_in_days:0
hz:15  # sentinel 리더 선출을 위한 정보 (10~19 사이 값이 랜덤하게 설정)
configured_hz:10
lru_clock:4694045
executable:/Users/-/redis-server
config_file:/usr/local/etc/redis-sentinel.conf
io_threads_active:0


127.0.0.1:6400> role
1) "sentinel"  # 해당 서버의 용도
2) 1) "mymaster"  # master 서버명
```

master/slave 서버 role 확인
```shell
# Master
127.0.0.1:6300> role
1) "master"
2) (integer) 379013
3) 1) 1) "127.0.0.1"
      2) "6379"
      3) "379013"

# Slave
127.0.0.1:6379> role
1) "slave"
2) "127.0.0.1"
3) (integer) 6300
4) "connected"
5) (integer) 378881
```

sentinel 명령어 - 2
```shell
127.0.0.1:6400> sentinel remove mymaster  # 모니터링 설정된 master 서버 해제
OK

127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:0  # 모니터링하고 있는 master 수가 0
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
                                    # 마지막에 master 서버 상태 정보 없음
                                    
                                    
127.0.0.1:6400> sentinel monitor mymaster 127.0.0.1 6300 1  # master 서버 모니터링 설정
OK

127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:1  # 모니터링하고 있는 master 수가 1
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=127.0.0.1:6300,slaves=1,sentinels=1


127.0.0.1:6400> sentinel set mymaster quorum 2  # sentinel 서버 quorum 변경
OK


127.0.0.1:6400> sentinel masters  # sentinel 서버가 모니터링중인 모든 master 정보
1)  1) "name"
    2) "mymaster"
    3) "ip"
    4) "127.0.0.1"
    5) "port"
    6) "6300"
    7) "runid"
    8) "2546f1d1e47ca36c79f5f1092382d20694bb4261"
    9) "flags"
   10) "master"  # master / slave / s_down / o_down 중 하나
   11) "link-pending-commands"
   12) "0"
   13) "link-refcount"
   14) "1"
   15) "last-ping-sent"
   16) "0"
   17) "last-ok-ping-reply"
   18) "97"
   19) "last-ping-reply"
   20) "97"
   21) "down-after-milliseconds"  # master 서버가 다운된 후 30초 이후 failover
   22) "30000"
   23) "info-refresh"
   24) "8064"
   25) "role-reported"
   26) "master"
   27) "role-reported-time"
   28) "138644"
   29) "config-epoch"
   30) "0"
   31) "num-slaves"  # slave 서버 수
   32) "1"
   33) "num-other-sentinels"  # 다른 sentinel 서버 수
   34) "0"
   35) "quorum"  # 정족수
   36) "1"
   37) "failover-timeout"
   38) "180000"
   39) "parallel-syncs"
   40) "1"
   
   
127.0.0.1:6400> sentinel slaves mymaster  # sentinel 서버가 모니터링중인 slave 서버의 상태 조회
1)  1) "name"
    2) "127.0.0.1:6379"
    3) "ip"
    4) "127.0.0.1"
    5) "port"
    6) "6379"
    7) "runid"
    8) "847bc454859a224d57c0025712336367e626a7f2"
    9) "flags"
   10) "slave"  # master / slave / s_down / o_down 중 하나
   11) "link-pending-commands"
   12) "0"
   13) "link-refcount"
   14) "1"
   15) "last-ping-sent"
   16) "0"
   17) "last-ok-ping-reply"
   18) "459"
   19) "last-ping-reply"
   20) "459"
   21) "down-after-milliseconds"
   22) "30000"
   23) "info-refresh"
   24) "1415"
   25) "role-reported"
   26) "slave"
   27) "role-reported-time"
   28) "663870"
   29) "master-link-down-time"
   30) "0"
   31) "master-link-status"
   32) "ok"
   33) "master-host"
   34) "127.0.0.1"
   35) "master-port"
   36) "6300"
   37) "slave-priority"  # 낮은 값의 서버가 장애 발생 시 master 로 선정
   38) "100"
   39) "slave-repl-offset"
   40) "471137"
   41) "replica-announced"
   42) "1"   


127.0.0.1:6400> sentinel reset mymaster  # sentinel 상태 정보 초기화 (master/slave 정보 refresh)
(integer) 1


127.0.0.1:6400> sentinel ckquorum mymaster  # 현재 설정된 quorum 값의 적정 여부 체크
OK 1 usable Sentinels. Quorum and failover authorization can be reached


127.0.0.1:6400> sentinel simulate-failure crash-after-election  # 시뮬레이션을 목적으로 sentinel 리더 선출 후 임의 다운
OK

127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:1  # sentinel 서버 임의 다운 횟수
master0:name=mymaster,status=ok,address=127.0.0.1:6300,slaves=1,sentinels=1


127.0.0.1:6400> sentinel simulate-failure crash-after-promotion  # slave 서버를 master 로 승격 후 sentinel 서버 다운 (음.. slave 승격안됨)
OK
127.0.0.1:6400> info sentinel
# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_tilt_since_seconds:-1
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:2
master0:name=mymaster,status=ok,address=127.0.0.1:6300,slaves=1,sentinels=1


127.0.0.1:6400> sentinel set mymaster down-after-milliseconds 1000  # # 장애 발생 시 FailOver 타임아웃 설정
OK
127.0.0.1:6400> sentinel set mymaster failover-timeout 100000
OK

127.0.0.1:6400> sentinel masters
1)  1) "name"
    2) "mymaster"
    3) "ip"
    4) "127.0.0.1"
    5) "port"
    6) "6300"
    7) "runid"
    8) "2546f1d1e47ca36c79f5f1092382d20694bb4261"
    9) "flags"
   10) "master"
   11) "link-pending-commands"
   12) "0"
   13) "link-refcount"
   14) "1"
   15) "last-ping-sent"
   16) "0"
   17) "last-ok-ping-reply"
   18) "197"
   19) "last-ping-reply"
   20) "197"
   21) "down-after-milliseconds"  # 위에 설정값 반영
   22) "1000"
   23) "info-refresh"
   24) "3432"
   25) "role-reported"
   26) "master"
   27) "role-reported-time"
   28) "3918996"
   29) "config-epoch"
   30) "0"
   31) "num-slaves"
   32) "1"
   33) "num-other-sentinels"
   34) "0"
   35) "quorum"
   36) "1"
   37) "failover-timeout"  # 위에 설정값 반영
   38) "100000"
   39) "parallel-syncs"
   40) "1"
   
   
127.0.0.1:6400> sentinel flushconfig  # sentinel.conf 파일에 변경된 값 반영 (이거 하지 않아도 반영되어 있음)
OK   
```

---

# 3. 부분 동기화

Redis 복제 시스템은 `Master-Slave`, `Master-Slave-Sentinel`, `Partition-Replication` 이렇게 3가지 방식이 있다.  

Slave 는 ReadOnly 이기 때문에 Master 서버에 장애 발생 시 데이터 유실이 발생할 수 밖에 없는데 이를 방지하기 위헤 복제 서버에서 실시간 full 동기화작업이 수행된다. (Redis 3.2 버전)

실제 동기화 데이터가 적은 경우 불필요한 작업이 발생하기 때문에 Redis 4.0 부터는 부분 동기화 작업이 가능할 수 있도록 `repl-backlog-size` 파라미터를 제공한다.  
동기화 대상 데이터의 크기가 `repl-backlog-size` 파라미터 크기보다 큰 경우 full sync 작업이 수행된다. 

```shell
$ vi redis.conf

repl-backlog-size 10mb  # 10MB 이상 권장
```

--- 

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [센티넬이란, 센티넬 구동 및 모니터링 방법](https://mozi.tistory.com/377)
* [redis.io - eviction](https://redis.io/docs/manual/eviction/)
* [redis-cli option](https://jhhwang4195.tistory.com/187)