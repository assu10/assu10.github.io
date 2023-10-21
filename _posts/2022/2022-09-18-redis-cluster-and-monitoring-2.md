---
layout: post
title:  "Redis - Redis Cluster & Monitoring (2)"
date:   2022-09-18 10:00
categories: dev
tags: redis 
---

이 포스팅은 Redis Cluster 를 구축하는 방법에 대해 알아본다.   

> - [Redis Cluster 구축 및 운영](#1-redis-cluster-구축-및-운영)
>   - [Cluster 서버](#11-cluster-서버)
>   - [Cluster 명령어를 이용한 수동 설정](#12-cluster-명령어를-이용한-수동-설정)
>   - [Cluster 명령어](#13-cluster-명령어)
>   - [redis-trib.rb 유틸리티를 이용한 자동 설정](#14-redis-tribrb-유틸리티를-이용한-자동-설정)

---

# 1. Redis Cluster 구축 및 운영

## 1.1. Cluster 서버

분산(Partition) 시스템은 하나의 테이블에 저장되는 데이터를 2개 이상의 서버로 동시에 분산저장하는 방식이다.  
파티셔닝을 통해 데이터를 분산 저장하다보면 예기치 못한 문제로 특정 서버에 장애가 발생하게 되고, 데이터 유실이 발생할 수 있는데
이를 방지하기 위해서는 분산 서버만다 복제 서버를 함께 구축해야 한다.

**데이터 분산 처리를 위한 파티셔닝 시스템**과 **안정성 확보를 위한 복제 시스템**은 함께 사용되는데 이를 **Redis 클러스터(Shard-Replication)** 라 한다.  
클러스터 서버 환경에서는 Sentinel 서버는 필요없다.

아래는 3개의 분산 서버(master) 마다 3개의 복제 서버(slave) 로 구축된 Redis Cluster 시스템이다.

![Redis Cluster Management](/assets/img/dev/2022/0918/redis-cluster.png)

Redis Cluster 시스템을 구축하는 방법은 2가지가 있다.  
- **Cluster 명령어를 이용한 수동 설정**
  - 직접 물리적 설계 필요
  - 최적화된 Cluster 서버 환경 구축 가능
  - 장애 발생 시 관리자 의도에 따라 대응 가능
- **redis-trib.rb 유틸리티를 이용한 자동 설정**
  - Redis-trib.rb는 Redis version 5.0 부터 Redis-cli로 대체됨

관리자의 기술 이해도, 업무 스킬 정도, 시스템 환경에 따라 적합한 방법을 선택하는 것이 좋다.

- Redis Cluster 특징
  - Redis 3.0 부터 제공
  - 클러스터 모드는 Database 0번만 사용 가능
  - 클러스터 모드에서 `MSET` 명령어 실행 불가, Hash-Tag 를 통해 데이터 표현 및 분산 저장
  - 기본적으로 Master/Slave 로만 구성되며, Sentinel 서버는 필요없음
  - Redis 서버는 기본적으로 16,384 개의 slot 을 갖는데 빅데이터를 여러 대의 서버에 분산 저장 시 각 slot 당 데이터를 일정 단위로 분류하여 저장할 때 사용됨  
   e.g. 3대의 Redis 서버가 구축되어 있는 환경일 경우
    - 첫 번째 서버는 0~5,460 slot 정보가 분산
    - 두 번째 서버는 5,461~10,922 slot 정보가 분산
    - 세 번째 서버는 10,923~16,384 slot 정보가 분산
  - Hash Partition 을 통해 데이터를 분산 저장할 수 있음, 이 때 해시 함수는 CRC16(Cycle Redundancy Check) 함수 사용

> Hash Partition 에 대한 내용은 [Redis - Redis Cluster & Monitoring (1)](https://assu10.github.io/dev/2022/09/17/redis-cluster-and-monitoring-1/) 의
> *1.1. 파티션 유형* 을 참고하세요.

---

## 1.2. Cluster 명령어를 이용한 수동 설정

redis-{port}.conf 파일 생성
```shell
$ pwd
/usr/local/etc
$ mkdir redis-cluster
$ cd redis-cluster
$ pwd
/usr/local/etc/redis-cluster

# 5001 node
$ mkdir /usr/local/etc/redis-cluster/5001
$ mkdir /usr/local/etc/redis-cluster/5001/data

$ vi redis-5001.conf
port 5001
cluster-enabled yes
cluster-config-file /usr/local/etc/redis-cluster/5001/nodes-5001.conf
# ms
cluster-node-timeout 5000

# /usr/local/var/db/redis
dir "/usr/local/etc/redis-cluster/5001/data"
appendonly yes

$ redis-server /usr/local/etc/redis-cluster/5001/redis-5001.conf
```

5001 node 를 생성한 과정과 동일하게 5002~5006 node 를 생성한다.

5001~5006 Redis 서버를 띄운다.
```shell
$ redis-server /usr/local/etc/redis-cluster/5001/redis-5001.conf
$ redis-server /usr/local/etc/redis-cluster/5002/redis-5002.conf
$ redis-server /usr/local/etc/redis-cluster/5003/redis-5003.conf
$ redis-server /usr/local/etc/redis-cluster/5004/redis-5004.conf
$ redis-server /usr/local/etc/redis-cluster/5005/redis-5005.conf
$ redis-server /usr/local/etc/redis-cluster/5006/redis-5006.conf
```

5001 node 에 접속하여 Cluster 멤버로 참여할 각 node 를 등록한다.
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5002  # 5002 node 를 멤버로 등록
$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5003
$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5004
$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5005
$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5006
```

등록된 멤버 확인
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665716069944 1 connected
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 master - 0 1665716069439 4 connected
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,master - 0 1665716068000 0 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 master - 0 1665716069000 3 connected
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 master - 0 1665716069540 5 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665716069540 2 connected
```

5004 node 를 5001 의 복제 서버로, 5005 node 를 5002 의 복제 서버로, 5006 node 를 5003 의 복제 서버로 설정한다.

```shell
$ redis-cli -h 127.0.0.1 -p 5004 cluster replicate f86bfd9f1665797a47a03a1e664d348ab7b9c55e  # 위에서 5001 의 node-id
OK
$ redis-cli -h 127.0.0.1 -p 5005 cluster replicate 50e59dfef86d1760b07fb5c477afe9ee122742b9
OK
$ redis-cli -h 127.0.0.1 -p 5006 cluster replicate 52abd0292b44e95774d701e116c75f1a5dcb7279
OK
```

등록된 멤버 재확인
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665716122759 1 connected
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665716122256 1 connected
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,master - 0 1665716123000 0 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 slave f86bfd9f1665797a47a03a1e664d348ab7b9c55e 0 1665716123260 0 connected
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 slave 52abd0292b44e95774d701e116c75f1a5dcb7279 0 1665716122558 2 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665716121550 2 connected
```

만일 master-slave 관계를 잘못 설정한 경우 아래와 같이 설정을 해지한 후 다시 설정한다.
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster forget 567950b15f8c77572cd8fa859106c342bdd5ebc0

# nodes-{port}.conf 파일 삭제

# 이후 다시 cluster meet 초대 후 master-slave 설정
```

> 데이터 분산은 Slot 을 기준으로 분산된다.  
> 3개의 node 가 구축되었다고 하면 1번 node 는 0~5,461, 2번 node 는 5,462~10,922, 3번 node 는 10,923~16,383 Slot 을 가지며,  
> 사용자가 직접 정의할 수도 있다.

![데이터 분산 예시](/assets/img/dev/2022/0918/slot.png)

> **Slot**  
> 입력된 KEY 에 CRC16 Function 을 적용하여 나온 값에 16,384 값을 나눈 나머지 값

각 master node 에 slot 설정
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster addslots {0..5461}
OK
$ redis-cli -h 127.0.0.1 -p 5002 cluster addslots {5462..10922}
OK
$ redis-cli -h 127.0.0.1 -p 5003 cluster addslots {10923..16383}
```

각 node 에 설정된 slot 확인
```shell
redis-cli -h 127.0.0.1 -p 5005 cluster slots
1) 1) (integer) 0
   2) (integer) 5461
   3) 1) "127.0.0.1"
      2) (integer) 5001
      3) "f86bfd9f1665797a47a03a1e664d348ab7b9c55e"
      4) (empty array)
   4) 1) "127.0.0.1"
      2) (integer) 5004
      3) "7fb6701e5793f0dc9523d1e12262fd95c840e100"
      4) (empty array)
2) 1) (integer) 5462
   2) (integer) 10922
   3) 1) "127.0.0.1"
      2) (integer) 5002
      3) "50e59dfef86d1760b07fb5c477afe9ee122742b9"
      4) (empty array)
   4) 1) "127.0.0.1"
      2) (integer) 5005
      3) "4c843eb9df07e67887d9b044acf4fc37e378b3f5"
      4) (empty array)
3) 1) (integer) 10923
   2) (integer) 16383
   3) 1) "127.0.0.1"
      2) (integer) 5003
      3) "52abd0292b44e95774d701e116c75f1a5dcb7279"
      4) (empty array)
   4) 1) "127.0.0.1"
      2) (integer) 5006
      3) "8524149ffc81c9406f6328e1643645920a3a7c8a"
      4) (empty array)
```

cluster 설정 상태 확인
```shell
$ redis-cli -h 127.0.0.1 -p 5005 cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3  # 3개의 샤드 서버로 설정된 상
cluster_current_epoch:5
cluster_my_epoch:1
cluster_stats_messages_ping_sent:10465
cluster_stats_messages_pong_sent:10352
cluster_stats_messages_sent:20817
cluster_stats_messages_ping_received:10351
cluster_stats_messages_pong_received:10465
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:20817
total_cluster_links_buffer_limit_exceeded:0
```

이제 5007(master), 5008(slave) 를 추가/삭제해보자.

```shell
$ mkdir /usr/local/etc/redis-cluster/5007
$ mkdir /usr/local/etc/redis-cluster/5007/data

$ mkdir /usr/local/etc/redis-cluster/5008
$ mkdir /usr/local/etc/redis-cluster/5008/data


$ vi /usr/local/etc/redis-cluster/5007/redis-5007.conf
port 5007
cluster-enabled yes
cluster-config-file /usr/local/etc/redis-cluster/5007/nodes-5007.conf
# ms
cluster-node-timeout 5000

# /usr/local/var/db/redis
dir "/usr/local/etc/redis-cluster/5007/data"
appendonly yes

$ vi /usr/local/etc/redis-cluster/5008/redis-5008.conf
port 5008
cluster-enabled yes
cluster-config-file /usr/local/etc/redis-cluster/5008/nodes-5008.conf
# ms
cluster-node-timeout 5000

# /usr/local/var/db/redis
dir "/usr/local/etc/redis-cluster/5008/data"
appendonly yes


$ redis-server /usr/local/etc/redis-cluster/5007/redis-5007.conf
$ redis-server /usr/local/etc/redis-cluster/5008/redis-5008.conf

$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5007
$ redis-cli -h 127.0.0.1 -p 5001 cluster meet 127.0.0.1 5008
```

등록된 멤버 확인
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665722174325 1 connected 5462-10922
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,master - 0 1665722173000 0 connected 0-5461
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 master - 0 1665722175028 7 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 slave f86bfd9f1665797a47a03a1e664d348ab7b9c55e 0 1665722173000 0 connected
705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512 127.0.0.1:5007@15007 master - 0 1665722173521 6 connected
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 slave 52abd0292b44e95774d701e116c75f1a5dcb7279 0 1665722173320 2 connected
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665722174000 1 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665722173000 2 connected 10923-16383
```

master/slave 설정
```shell
$ redis-cli -h 127.0.0.1 -p 5008 cluster replicate 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512  # 위에서 5007 의 node-id
```

등록된 멤버 재확인
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665722319248 1 connected 5462-10922
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,master - 0 1665722318000 0 connected 0-5461
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 slave 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512 0 1665722319549 6 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 slave f86bfd9f1665797a47a03a1e664d348ab7b9c55e 0 1665722321053 0 connected
705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512 127.0.0.1:5007@15007 master - 0 1665722320551 6 connected
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 slave 52abd0292b44e95774d701e116c75f1a5dcb7279 0 1665722320250 2 connected
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665722320250 1 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665722320000 2 connected 10923-16383
```

이제 5007 node 를 제거해보자.  
`cluster meet` 과는 다르게 `cluster forget` 은 전체 노드에서 실행해야 하며, 타임아웃 60초 범위 안에 실행해야 한다.  
그리고 반드시 Master 대상으로 해야한다.

```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
OK
$ redis-cli -h 127.0.0.1 -p 5002 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
OK
$ redis-cli -h 127.0.0.1 -p 5003 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
OK
$ redis-cli -h 127.0.0.1 -p 5004 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
OK
$ redis-cli -h 127.0.0.1 -p 5005 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
OK
$ redis-cli -h 127.0.0.1 -p 5006 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
OK
$ redis-cli -h 127.0.0.1 -p 5007 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
(error) ERR I tried hard but I can't forget myself...
$ redis-cli -h 127.0.0.1 -p 5008 cluster forget 705f4fbfc5d5bb9ad6fd09e6193c11c62f2a7512
(error) ERR Can't forget my master!
```

nodes-5007.conf 파일 삭제 후 재확인
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665722921597 1 connected 5462-10922
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,master - 0 1665722922000 0 connected 0-5461
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 slave - 0 1665722921000 7 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 slave f86bfd9f1665797a47a03a1e664d348ab7b9c55e 0 1665722922000 0 connected
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 slave 52abd0292b44e95774d701e116c75f1a5dcb7279 0 1665722922000 2 connected
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665722921000 1 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665722922606 2 connected 10923-16383
```


- `cluster-enabled` yes
  - Redis Cluster 모드 설정
- `cluster-config-file` /usr/local/etc/redis-cluster/5007/nodes-5007.conf
  - Redis Cluster node 상태 정보 기록하는 Binary 파일 경로와 파일명 지정
- `cluster-node-timeout` 5000 
  - ms 단위이며, Cluster node 가 다운된 상태인지 여부를 판단하기 위한 타임아웃 시간 설정
  - 지정된 시간 내에 node 가 응답하지 않으면 다운된 것으로 판단

---

## 1.3. Cluster 명령어

`cluster info`
```shell
127.0.0.1:5001> cluster info
cluster_state:ok
cluster_slots_assigned:16384  # Redis 서버에 할당된 최대 slot 수 (cluster_slots_ok + cluster_pfail + cluster_slots_fail)
cluster_slots_ok:16384
cluster_slots_pfail:0  # 접속할 수 없는 노드에 할당된 슬롯 수
cluster_slots_fail:0  # 다운된 서버에 할당된 슬롯 수
cluster_known_nodes:7  # 클러스터에 할당된 모든 노드 수
cluster_size:3  # 클러스터에 할당된 master 노드 수
cluster_current_epoch:7
cluster_my_epoch:0
cluster_stats_messages_ping_sent:19666
cluster_stats_messages_pong_sent:19771
cluster_stats_messages_meet_sent:7
cluster_stats_messages_sent:39444
cluster_stats_messages_ping_received:19771
cluster_stats_messages_pong_received:19672
cluster_stats_messages_fail_received:1
cluster_stats_messages_received:39444
total_cluster_links_buffer_limit_exceeded:0
```

`cluster nodes` -  Cluster 에 할당된 모든 노드 정보
```shell
127.0.0.1:5001> cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665726564952 1 connected 5462-10922
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,master - 0 1665726563000 0 connected 0-5461
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 slave - 0 1665726564549 7 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 slave f86bfd9f1665797a47a03a1e664d348ab7b9c55e 0 1665726564549 0 connected
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 slave 52abd0292b44e95774d701e116c75f1a5dcb7279 0 1665726565000 2 connected
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665726564000 1 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665726563542 2 connected 10923-16383
```

`cluster slaves` - 해당 master 를 바라보는 slaves 정보
```shell
127.0.0.1:5001> cluster slaves 50e59dfef86d1760b07fb5c477afe9ee122742b9  # master node-id
1) "4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665726884000 1 connected"

127.0.0.1:5001> cluster slaves 4c843eb9df07e67887d9b044acf4fc37e378b3f5  # slave node-id
(error) ERR The specified node is not a master
```

`cluster keyslot`
```shell
127.0.0.1:5001> cluster keyslot 1101  # key 1101 이 저장되어 있는 slot 번호
(integer) 2863

127.0.0.1:5001> cluster keyslot 9999
(integer) 7389
```

`cluster failover` - slave node 를 master node 로 전환
```shell
$ redis-cli -h 127.0.0.1 -p 5004 cluster failover
OK

$ redis-cli -h 127.0.0.1 -p 5004 cluster nodes
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665727493042 1 connected
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 slave 7fb6701e5793f0dc9523d1e12262fd95c840e100 0 1665727493543 8 connected  # slave 로 변경
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665727494044 1 connected 5462-10922
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 slave - 0 1665727494546 7 connected
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 myself,master - 0 1665727493000 8 connected 0-5461  # master 로 변경
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 slave 52abd0292b44e95774d701e116c75f1a5dcb7279 0 1665727494546 2 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665727493543 2 connected 10923-16383
```

`cluster reset`
```shell
$ redis-cli -h 127.0.0.1 -p 5006 cluster reset
OK
$ redis-cli -h 127.0.0.1 -p 5008 cluster reset
OK

$ redis-cli -h 127.0.0.1 -p 5001 cluster nodes
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665727638405 1 connected 5462-10922
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 myself,slave 7fb6701e5793f0dc9523d1e12262fd95c840e100 0 1665727635000 8 connected
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 master - 0 1665727637601 7 connected  # master 로 변경
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 master - 0 1665727638506 8 connected 0-5461
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 master - 0 1665727638000 5 connected  # master 로 변경
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 0 1665727636395 1 connected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665727638506 2 connected 10923-16383
```

`cluster saveconfig` - 변경된 환경 정보를 redis.conf 에 저장
```shell
$ redis-cli -h 127.0.0.1 -p 5001 cluster saveconfig
OK
```

---

## 1.4. redis-trib.rb 유틸리티를 이용한 자동 설정

>Redis-trib.rb는 Redis version 5.0 부터 Redis-cli로 대체되었음

--- 

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)