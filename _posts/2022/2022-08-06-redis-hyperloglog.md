---
layout: post
title:  "Redis - HyperLogLog"
date:   2022-08-06 10:00
categories: dev
tags: redis hyperloglog
---

이 포스팅은 Redis 의 데이터 타입 중 하나인 `HyperLogLog` 타입에 대해 알아본다.

> - `HyperLogLog`
>   - `PFADD`
>   - `PFCOUNT`
>   - `PFMERGE`

---

# 1. `HyperLogLog`

특정 사이트의 방문자 수를 카운트하는 경우 동일 유저는 제외하고 카운트를 해야 하는 경우를 생각해보자.  
방문자가 생길때마다 unique 값을 저장하고 매번 기존의 방문자와 비교한다면 저장 공간과 연산 비용이 엄청날 것이다.

이와 같은 문제점을 해결하고자 unique count 기능을 제공해주는 것이 `HyperLogLog` 이다.  
`HyperLogLog`는 unique item 이 들어올때마다 counter 값을 increments 한다.  
(unique 하지 않은 item 이 들어올 경우는 아무일도 일어나지 않음)

`HyperLogLog` 는 데이터의 값을 저장하지는 않기 때문에 대규모의 저장 공간이 필요하지 않고, 따라서 내부의 데이터 확인도 불가하다.

- 매우 큰 데이터의 오차가 1% 이하의 근사치를 구할 때 사용 (예 - 검색 엔진의 하루 검색어 수 계산 시 사용)
- 메모리를 매우 적게 사용하고 오차도 적음
- 별도 데이터 구조를 사용하지 않고 String 사용

> **`HyperLogLog` 의 메모리 사용량**  
> `Set` 에 1백만개의 숫자 저장 시 4,848KB 사용, 1천만개의 숫자 저장 시 46,387KB 사용  
> `HyperLogLog` 를 사용하면 원소 개수와 상관없이 고정으로 12KB 만 사용 (1백만개 숫자의 Set 과 비교 시 0.25% 만 사용)

> **`HyperLogLog` 의 저장 속도**  
> `Set` 에 1백만개의 데디터 저장 시 `SADD` 로 했을 경우는 8.64s, `PFADD` 로 했을 경우는 5.23s (약 1.6배 빠름)

> **`HyperLogLog` 의 조회 속도**  
> `PFCOUNT`와 `SCARD` 모두 O(1) 로 4ms 정도 소요


```shell
$ pwd
/usr/local/opt/redis/bin

$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ redis-cli
127.0.0.1:6379>
```

---

## 1.1. `PFADD`

elements 를 추가하는 명령어이다.  
원소 추가후엔 원소의 개수와 상관없이 1를 리턴한다.

```shell
127.0.0.1:6379> help pfadd

  PFADD key [element [element ...]]
  summary: Adds the specified elements to the specified HyperLogLog.
  since: 2.8.9
  group: hyperloglog
```

```shell
127.0.0.1:6379> pfadd hlog1 e1 e2
(integer) 1
127.0.0.1:6379> pfadd hlog2 e2 e3
(integer) 1

127.0.0.1:6379> pfcount hlog1 hlog2
(integer) 3
```

---

## 1.2. `PFCOUNT`

elements 의 개수를 조회하는 명령어이다.  
추정 오류는 1% 이하이다.

```shell
127.0.0.1:6379> help pfcount

  PFCOUNT key [key ...]
  summary: Return the approximated cardinality of the set(s) observed by the HyperLogLog at key(s).
  since: 2.8.9
  group: hyperloglog
```

```shell
```shell
127.0.0.1:6379> pfadd hlog1 e1 e2
(integer) 1
127.0.0.1:6379> pfadd hlog2 e2 e3
(integer) 1

127.0.0.1:6379> pfcount hlog1 hlog2
(integer) 3
```

---

## 1.3. `PFMERGE`

2개 이상의 집합을 합하여 하나의 집합으로 만든다.

```shell
127.0.0.1:6379> help pfmerge

  PFMERGE destkey sourcekey [sourcekey ...]
  summary: Merge N different HyperLogLogs into a single one.
  since: 2.8.9
  group: hyperloglog
```

```shell
127.0.0.1:6379> pfadd hlog1 e1 e2 e3
(integer) 1
127.0.0.1:6379> pfadd hlog2 e3 e4 e5
(integer) 1

127.0.0.1:6379> pfmerge hlog3 hlog1 hlog2
OK

127.0.0.1:6379> pfcount hlog3
(integer) 5
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [Redis Gate - HyperLogLog](http://redisgate.kr/redis/command/hyperloglog.php)
* [https://redis.io/commands](https://redis.io/commands/)
* [https://redis.io/commands - HyperLogLog](https://redis.io/commands/?group=hyperloglog)
* [HyperLogLog](https://minholee93.tistory.com/entry/Redis-HyperLogLog)
