---
layout: post
title:  "Redis - Redis Cluster & Monitoring (3)"
date: 2022-10-08 10:00
categories: dev
tags: redis 
---

이 포스트는 Redis Logging 과 Monitoring 에 대해 알아본다.

<!-- TOC -->
* [1. Master 서버를 이용한 Slave 서버 복구](#1-master-서버를-이용한-slave-서버-복구)
* [2. Logging & Monitoring](#2-logging--monitoring)
  * [2.1. Logging 정보](#21-logging-정보)
  * [2.2. Monitoring](#22-monitoring)
* [3. Subscribe & Publish](#3-subscribe--publish)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. Master 서버를 이용한 Slave 서버 복구

```shell
$ ps -ef | grep redis
  501 33217 86892   0 11:51AM ttys001    0:09.78 redis-server *:5001 [cluster]
  501 33245 87641   0 11:51AM ttys002    0:09.83 redis-server *:5002 [cluster]
  501 33562 87884   0 11:53AM ttys003    0:09.24 redis-server *:5003 [cluster]
  501 54382 88134   0  3:52PM ttys004    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox redis
  501 33594 23473   0 11:53AM ttys005    0:09.46 redis-server *:5004 [cluster]
  501 33623 23658   0 11:53AM ttys006    0:09.71 redis-server *:5005 [cluster]
  501 33651 23814   0 11:54AM ttys007    0:08.98 redis-server *:5006 [cluster]
  501 44397 41564   0  1:48PM ttys008    0:03.44 redis-server *:5007 [cluster]
  501 42058 41712   0  1:35PM ttys009    0:05.33 redis-server *:5008 [cluster]
```

master 5002 를 바라보는 slave 5005 를 강제종료한다.
```shell
$ kill -9 33623

$ ps -ef | grep redis
  501 33217 86892   0 11:51AM ttys001    0:10.73 redis-server *:5001 [cluster]
  501 33245 87641   0 11:51AM ttys002    0:10.79 redis-server *:5002 [cluster]
  501 33562 87884   0 11:53AM ttys003    0:09.94 redis-server *:5003 [cluster]
  501 56179 88134   0  4:17PM ttys004    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox redis
  501 33594 23473   0 11:53AM ttys005    0:10.43 redis-server *:5004 [cluster]
  501 33651 23814   0 11:54AM ttys007    0:09.69 redis-server *:5006 [cluster]
  501 44397 41564   0  1:48PM ttys008    0:04.06 redis-server *:5007 [cluster]
  501 42058 41712   0  1:35PM ttys009    0:06.03 redis-server *:5008 [cluster]
```

```shell
$ cp /usr/local/etc/redis-cluster/5002/nodes-5002.conf /usr/local/etc/redis-cluster/5005/nodes-5005.conf

$ cp /usr/local/etc/redis-cluster/5002/data/*.* /usr/local/etc/redis-cluster/5005/data/
```

vi /usr/local/etc/redis-cluster/5005/redis-5005.conf
```shell
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 slave,fail 50e59dfef86d1760b07fb5c477afe9ee122742b9 1665731861587 1665731859000 1 disconnected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665731866521 2 connected 10923-16383
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 master - 0 1665731866000 5 connected
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 master - 0 1665731866000 7 connected
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 slave 7fb6701e5793f0dc9523d1e12262fd95c840e100 0 1665731865714 8 connected
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 myself,master - 0 1665731864000 1 connected 5462-10922
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 master - 0 1665731866723 8 connected 0-5461
vars currentEpoch 8 lastVoteEpoch 8


# 위에서 127.0.0.1:5005@15005 slave,fail -> 127.0.0.1:5005@15005 myself,slave 로 변경
# 127.0.0.1:5002@15002 myself,master -> 127.0.0.1:5002@15002 master 로 변경
4c843eb9df07e67887d9b044acf4fc37e378b3f5 127.0.0.1:5005@15005 myself,slave 50e59dfef86d1760b07fb5c477afe9ee122742b9 1665731861587 1665731859000 1 disconnected
52abd0292b44e95774d701e116c75f1a5dcb7279 127.0.0.1:5003@15003 master - 0 1665731866521 2 connected 10923-16383
8524149ffc81c9406f6328e1643645920a3a7c8a 127.0.0.1:5006@15006 master - 0 1665731866000 5 connected
e34ef33a0e15784da76f005282d0e4b9d625c752 127.0.0.1:5008@15008 master - 0 1665731866000 7 connected
f86bfd9f1665797a47a03a1e664d348ab7b9c55e 127.0.0.1:5001@15001 slave 7fb6701e5793f0dc9523d1e12262fd95c840e100 0 1665731865714 8 connected
50e59dfef86d1760b07fb5c477afe9ee122742b9 127.0.0.1:5002@15002 master - 0 1665731864000 1 connected 5462-10922
7fb6701e5793f0dc9523d1e12262fd95c840e100 127.0.0.1:5004@15004 master - 0 1665731866723 8 connected 0-5461
vars currentEpoch 8 lastVoteEpoch 8
```

```shell
$ redis-server /usr/local/etc/redis-cluster/5005/redis-5005.conf  # 5005 서버 재기동
```

---

# 2. Logging & Monitoring

## 2.1. Logging 정보

- `loglevel`
  - *loglevel notice*
    - debug (a lot of information, useful for development/testing)
    - verbose (many rarely useful info, but not a mess like the debug level)
    - notice (moderately verbose, what you want in production probably)
    - warning (only very important / critical messages are logged)

- `logfile`
  - *logfile "/usr/local/var/db/redis/redis_6379.log"*

- `syslog-enalbed`
  - *syslog-enabled no*
  - 시스템 로그 정보 수집 여부

- `syslog-ident`
  - *syslog-ident redis*
  - 시스템 로그 식별자

---

## 2.2. Monitoring

- `latency-monitor-threshold`
  - *latency-monitor-threshold 25*: 25ms 이상 소요되는 작업을 수집 분석

```shell
$ redis-cli -h 127.0.0.1 -p 6379

127.0.0.1:6379> debug sleep .25  # 0.25 초 이상 소요된 작업 수집
OK

127.0.0.1:6379> latency latest # 조건을 만족하는 작업 리스트
1) 1) "command"
   2) (integer) 1665733787
   3) (integer) 338
   4) (integer) 338
   
127.0.0.1:6379> latency doctor  # advice report 제공
Dave, I have observed latency spikes in this Redis instance. You don't mind talking about it, do you Dave?

1. command: 1 latency spikes (average 338ms, mean deviation 0ms, period 49.00 sec). Worst all time event 338ms.

I have a few advices for you:

- Check your Slow Log to understand what are the commands you are running which are too slow to execute. Please check https://redis.io/commands/slowlog for more information.
- Deleting, expiring or evicting (because of maxmemory policy) large objects is a blocking operation. If you have very large objects that are often deleted, expired, or evicted, try to fragment those objects into multiple smaller objects.
```

latency 상태 모니터링
```shell
$ redis-cli -h 127.0.0.1 -p 6379  --latency
min: 0, max: 17, avg: 4.25 (1601 samples)^C
```

```shell
$ redis-cli -h 127.0.0.1 -p 6379  --bigkeys

# Scanning the entire keyspace to find biggest keys as well as
# average sizes per key type.  You can use -i 0.1 to sleep 0.1 sec
# per 100 SCAN commands (not usually needed).


-------- summary -------

Sampled 0 keys in the keyspace!
Total key length in bytes is 0 (avg len 0.00)


0 hashs with 0 fields (00.00% of keys, avg size 0.00)
0 lists with 0 items (00.00% of keys, avg size 0.00)
0 strings with 0 bytes (00.00% of keys, avg size 0.00)
0 streams with 0 entries (00.00% of keys, avg size 0.00)
0 sets with 0 members (00.00% of keys, avg size 0.00)
0 zsets with 0 members (00.00% of keys, avg size 0.00)
```

특정 세션 모니터링
```shell
$ redis-cli -h 127.0.0.1 -p 6379 monitor
OK
1665734532.100851 [0 127.0.0.1:63476] "COMMAND" "DOCS"
1665734558.660122 [0 127.0.0.1:63476] "get" "1"
```

---

# 3. Subscribe & Publish

Redis 의 message 는 완벽한 전달을 보장하지 않음.
하여 별도로 보지 않음.

--- 

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [Redis PubSub Demo](https://gist.github.com/pietern/348262)