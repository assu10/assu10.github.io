---
layout: post
title:  "Redis - Sorted Set"
date: 2022-07-30 10:00
categories: dev
tags: redis zset sorted-set
---

이 포스트는 Redis 의 데이터 타입 중 하나인 `Set` 타입에 대해 알아본다.

<!-- TOC -->
* [1. `Sorted Set`](#1-sorted-set)
  * [1.1. `ZADD`](#11-zadd)
    * [1.1.1. [`NX`|`XX`]](#111-nxxx)
    * [1.1.2. [`GT`|`LT`]](#112-gtlt)
    * [1.1.3. [`CH`]](#113-ch)
    * [1.1.4. [`INCR`]](#114-incr)
  * [1.2. `ZRANGE`, `ZREVRANGE`](#12-zrange-zrevrange)
    * [1.2.1. [`BYSCORE`|`BYLEX`], [`LIMIT offset count`]](#121-byscorebylex-limit-offset-count)
    * [1.2.2. [`REV`]](#122-rev)
  * [1.3. `ZRANK`, `ZREVRANK`](#13-zrank-zrevrank)
  * [1.4. `ZSCORE`](#14-zscore)
  * [1.5. `ZCARD`](#15-zcard)
  * [1.6. `ZCOUNT`](#16-zcount)
  * [1.7. `ZSCAN`](#17-zscan)
  * [1.8. `ZPOPMIN`, `ZPOPMAX`](#18-zpopmin-zpopmax)
  * [1.9. `ZREM`, `ZREMRANGEBYRANK`, `ZREMRANGEBYSCORE`](#19-zrem-zremrangebyrank-zremrangebyscore)
  * [1.10. `ZINCRBY`](#110-zincrby)
  * [1.11. `ZUNION`, `ZINTER`, `ZDIFF`](#111-zunion-zinter-zdiff)
    * [1.11.1. `ZUNION`](#1111-zunion)
    * [1.11.2. `ZINTER`](#1112-zinter)
    * [1.11.3. `ZDIFF`](#1113-zdiff)
  * [1.12. `ZUNIONSTORE`, `ZINTERSTORE`, `ZDIFFSTORE`](#112-zunionstore-zinterstore-zdiffstore)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. `Sorted Set`

- `Sorted Set` 은 `Set` 타입과 동일한 데이터 구조이지만 저장된 데이터 값이 정렬된 상태라는 점이 다름
- 정렬의 기준을 `score` 라고 함

사용자들의 데이터를 redis 상에서 정렬하거나 업데이트하는 시나리오도 접근해 볼 예정이다.

- `key`: user:userNumber
- `score`: userNumber
- `member`: userNumber 에 해당하는 user 

```shell
$ pwd
/usr/local/opt/redis/bin

$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ redis-cli
127.0.0.1:6379>
```

---

## 1.1. `ZADD`

`Sorted Set` 에 하나 이상의 member 를 추가하거나, 만일 이미 존재하는 member 이면 score 를 업데이트한다.

```shell
127.0.0.1:6379> help zadd

  ZADD key [NX|XX] [GT|LT] [CH] [INCR] score member [score member ...]
  summary: Add one or more members to a sorted set, or update its score if it already exists
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zadd user:userNumber 1 assu
(integer) 1
127.0.0.1:6379> zadd user:userNumber 2 user2 3 user3
(integer) 2

127.0.0.1:6379> zrange user:userNumber 0 -1
1) "assu"
2) "user2"
3) "user3"

127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "assu"
2) "1"
3) "user2"
4) "2"
5) "user3"
6) "3"

127.0.0.1:6379> zadd user:userNumber 5 assu  # 이미 존재하는 member 는 score 업데이트
(integer) 0
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "2"
3) "user3"
4) "3"
5) "assu"
6) "5"
```

---

### 1.1.1. [`NX`|`XX`]

- `NX`: member 가 존재하지 않을 경우에만 추가하도록 하는 옵션, 기존 member 를 수정하지는 않음
- `XX`: member 가 존재하는 경우에만 추가 (Update) 하도록 하는 옵션, 새로운 member 를 추가하지는 않음

`NX`

```shell
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "2"
3) "user3"
4) "3"
5) "assu"
6) "5"

127.0.0.1:6379> zadd user:userNumber NX 4 user4  # NX: user4 member 가 존재하지 않으므로 추가 
(integer) 1

127.0.0.1:6379> zadd user:userNumber NX 5 user4  # NX: user4 member 가 존재하므로 추가하지 않음
(integer) 0

127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "2"
3) "user3"
4) "3"
5) "user4"
6) "4"  # NX: user4 member 가 존재하므로 추가하지 않음
7) "assu"
8) "5"
```

`XX`

```shell
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "2"
3) "user3"
4) "3"
5) "user4"
6) "4"
7) "assu"
8) "5"

127.0.0.1:6379> zadd user:userNumber XX 5 user4  # XX: user4 member 가 존재하므로 score 를 5 로 업데이트함
(integer) 0

127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "2"
3) "user3"
4) "3"
5) "assu"
6) "5"
7) "user4"
8) "5"

127.0.0.1:6379> zadd user:userNumber XX 6 user6  # XX: user6 member 가 존재하지 않으므로 추가하지 않음
(integer) 0

127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "2"
3) "user3"
4) "3"
5) "assu"
6) "5"
7) "user4"
8) "5"
```

---

### 1.1.2. [`GT`|`LT`]

- `GT`: 추가하려는 member 의 score 가 더 크면 score 업데이트 (member 가 없으면 바로 추가)
- `LT`: 추가하려는 member 의 score 가 더 작으면 score 업데이트 (member 가 없으면 바로 추가)

`GT`

```shell
127.0.0.1:6379> zadd user:userNumber 10 user1
(integer) 1
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "10"

# 그냥 추가
127.0.0.1:6379> zadd user:userNumber 20 user1
(integer) 0
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "20"

# GT 30 으로 하면 기존의 score 인 20 보다 크기 때문에 score 업데이트됨
127.0.0.1:6379> zadd user:userNumber GT 30 user1
(integer) 0
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "30"

# GT 20 으로 하면 기존의 score 인 30 보다 작기 때문에 score 업데이트되지 않음
127.0.0.1:6379> zadd user:userNumber GT 20 user1
(integer) 0
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "30"

# # GT 20 으로 기존에 없던 member 추가 시 바로 추가됨
127.0.0.1:6379> zadd user:userNumber GT 20 user2
(integer) 1
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user2"
2) "20"
3) "user1"
4) "30"
```

---

### 1.1.3. [`CH`]

추가된 새 elements 갯수에서 **변경된 총 elements 의 갯수**로 반환 값을 수정한다.

> 변경된 elements: **새로 추가된 elements** + **기존에 존재하는데 score 가 업데이트된 elements**  
> (기존과 동일한 score 를 가진 elements 는 포함되지 않음)  
>
> 일반적으로 `ZADD` 의 반환 값은 추가된 새로운 elements 의 갯수만 계산하며,  
> `CH` 옵션을 사용하지 않으면 수정된 갯수는 리턴하지 않는다.

```shell
127.0.0.1:6379> zadd user:userNumber 10 user1 20 user2 30 user3
(integer) 3
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "10"
3) "user2"
4) "20"
5) "user3"
6) "30"

# 40 user4 (1) + 21 user2(1) = 2 반환 
127.0.0.1:6379> zadd user:userNumber CH 40 user4 21 user2
(integer) 2

127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "10"
3) "user2"
4) "21"
5) "user3"
6) "30"
7) "user4"
8) "40"

# 40 user4 (0) + 21 user2(0) = 0 반환 (모두 기존 score 와 동일하므로)
127.0.0.1:6379> zadd user:userNumber CH 40 user4 21 user2
(integer) 0
```

---

### 1.1.4. [`INCR`]

`ZINCRBY` 처럼 동작하는 명령어이며, 한번에 하나의 score-element pair 만 지정이 가능하다.

```shell
127.0.0.1:6379> zadd user:userNumber 10 user1
(integer) 1
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "10"

127.0.0.1:6379> zadd user:userNumber incr -2 user1
"8"
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "8"

127.0.0.1:6379> zadd user:userNumber incr 2 user1
"10"
127.0.0.1:6379> zrange user:userNumber 0 -1 withscores
1) "user1"
2) "10"
```


---

## 1.2. `ZRANGE`, `ZREVRANGE`

```shell
127.0.0.1:6379> help zrange

  ZRANGE key min max [BYSCORE|BYLEX] [REV] [LIMIT offset count] [WITHSCORES]
  summary: Return a range of members in a sorted set
  since: 1.2.0
  group: sorted-set

127.0.0.1:6379> help zrevrange

  ZREVRANGE key start stop [WITHSCORES]
  summary: Return a range of members in a sorted set, by index, with scores ordered from high to low
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zadd user:userName 10 user1 20 user2 30 user3 40 user5 50 user5
(integer) 4
127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user1"
2) "10"
3) "user2"
4) "20"
5) "user3"
6) "30"
7) "user5"
8) "50"

# score 가 낮은 순으로 3개 조회
127.0.0.1:6379> zrange user:userName 0 2 withscores
1) "user1"
2) "10"
3) "user2"
4) "20"
5) "user3"
6) "30"
```

---

### 1.2.1. [`BYSCORE`|`BYLEX`], [`LIMIT offset count`]

`BYSCORE`

`BYSCORE` 사용 시 zrange key min max 에서 min, max 는 index 가 아닌 score 의 범위이다.

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user2"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"

127.0.0.1:6379> zrange user:userName 0 100 byscore withscores
 1) "user1"
 2) "10"
 3) "user2"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"

# score 가 0~30 범위 안에 드는 element 조회
127.0.0.1:6379> zrange user:userName 0 30 byscore withscores
1) "user1"
2) "10"
3) "user2"
4) "20"
5) "user3"
6) "30"

# score 의 범위가 0~100 범위 안에서 낮은 score 순으로 limit 0,2 조회
127.0.0.1:6379> zrange user:userName 0 100 byscore limit 0 2 withscores
1) "user1"
2) "10"
3) "user2"
4) "20"

# score 의 범위가 0~100 범위 안에서 낮은 score 순으로 limit 1,2 조회
127.0.0.1:6379> zrange user:userName 0 100 byscore limit 1 2 withscores
1) "user2"
2) "20"
3) "user3"
4) "30"

# score 의 범위가 0~20 범위 안에서 낮은 score 순으로 limit 1,2 조회
127.0.0.1:6379> zrange user:userName 0 20 byscore limit 1 2 withscores
1) "user2"
2) "20"
```

`BYLEX`

`BYLEX` 는 member 의 사전적 순서로 필터링하여 조회한다.
`(`: 미포함
`[`: 포함
`-`: 음의 무한
`+`: 양의 무한

```shell
127.0.0.1:6379> zadd test 0 a 0 b 0 c 0 d 0 e 0 f 0 g
(integer) 7
127.0.0.1:6379> zrange test 0 -1
1) "a"
2) "b"
3) "c"
4) "d"
5) "e"
6) "f"
7) "g"
127.0.0.1:6379> zrange test - [c bylex
1) "a"
2) "b"
3) "c"
127.0.0.1:6379> zrange test - (c bylex
1) "a"
2) "b"
127.0.0.1:6379> zrange test [aaa (g bylex
1) "b"
2) "c"
3) "d"
4) "e"
5) "f"
127.0.0.1:6379> zrange test [a (g bylex
1) "a"
2) "b"
3) "c"
4) "d"
5) "e"
6) "f"
```

```shell
127.0.0.1:6379> zadd test 0 a 1 c 2 b 3 f 4 d
(integer) 5
127.0.0.1:6379> zrange test 0 -1
1) "a"
2) "c"
3) "b"
4) "f"
5) "d"
127.0.0.1:6379> zrange test 0 -1 withscores
 1) "a"
 2) "0"
 3) "c"
 4) "1"
 5) "b"
 6) "2"
 7) "f"
 8) "3"
 9) "d"
10) "4"

# member 가 처음부터 시작해서 b 를 포함하는 범위까지 조회 (c 가 b 앞에 있으므로 b 는 조회안됨)
127.0.0.1:6379> zrange test - [b bylex
1) "a"

# member 가 처음부터 시작해서 b 를 포함하지 않는 범위까지 조회
127.0.0.1:6379> zrange test - (b bylex
1) "a"

# member 가 a 를 포함하는 곳부터 시작해서 f 를 포함하는 범위까지 조회
127.0.0.1:6379> zrange test [a [f bylex
1) "a"
2) "c"
3) "b"
4) "f"
5) "d"

# member 가 a 를 포함하는 곳부터 시작해서 f 를 포함하지 않는 범위까지 조회 (d 는 f 뒤에 있기 때문에 조회되지 않음)
127.0.0.1:6379> zrange test [a (f bylex
1) "a"
2) "c"
3) "b"

127.0.0.1:6379> zrange test [a (f bylex rev
(empty array)
```

---

### 1.2.2. [`REV`]

score 를 기준으로 역순으로 조회한다.

```shell
127.0.0.1:6379> zrange test 0 -1
1) "a"
2) "c"
3) "b"
4) "f"
5) "d"
127.0.0.1:6379> zrange test 0 -1 withscores
 1) "a"
 2) "0"
 3) "c"
 4) "1"
 5) "b"
 6) "2"
 7) "f"
 8) "3"
 9) "d"
10) "4"

# score 역순으로 조회
127.0.0.1:6379> zrange test 0 -1 rev
1) "d"
2) "f"
3) "b"
4) "c"
5) "a"
```

---

## 1.3. `ZRANK`, `ZREVRANK`

`ZRANK` 는 낮은 score 기준으로 해당 member 의 index 를 조회하는 명령어이고,  
`ZREVRANK` 는 높은 score 기준으로 해당 member 의 index 를 조회하는 명령어이다.

```shell
127.0.0.1:6379> help zrank

  ZRANK key member
  summary: Determine the index of a member in a sorted set
  since: 2.0.0
  group: sorted-set

127.0.0.1:6379> help zrevrank

  ZREVRANK key member
  summary: Determine the index of a member in a sorted set, with scores ordered from high to low
  since: 2.0.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zadd user:userName 10 user1 20 user2 30 user3 40 user4 50 user5
(integer) 5
127.0.0.1:6379> zrange user:userName 0 -1
1) "user1"
2) "user2"
3) "user3"
4) "user4"
5) "user5"

# 낮은 score 기준으로 user2 member 의 index 조회
127.0.0.1:6379> zrank user:userName user2
(integer) 1

# 높은 score 기준으로 user2 member 의 index 조회
127.0.0.1:6379> zrevrank user:userName user2
(integer) 3
```

---

## 1.4. `ZSCORE`

해당 member 의 score 를 조회하는 명령어이다.

```shell
127.0.0.1:6379> help zscore

  ZSCORE key member
  summary: Get the score associated with the given member in a sorted set
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user2"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"

127.0.0.1:6379> zscore user:userName user3
"30"
```

---

## 1.5. `ZCARD`

`Set` 에 속한 member 의 갯수를 조회하는 명령어이다.

```shell
127.0.0.1:6379> help zcard

  ZCARD key
  summary: Get the number of members in a sorted set
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zcard user:userName
(integer) 5
```

---

## 1.6. `ZCOUNT`

주어진 범위 안에 속하는 score 를 가진 member 의 갯수를 조회하는 명령어이다.

```shell
127.0.0.1:6379> help zcount

  ZCOUNT key min max
  summary: Count the members in a sorted set with scores within the given values
  since: 2.0.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user2"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"

127.0.0.1:6379> zcount user:userName 0 1
(integer) 0

127.0.0.1:6379> zcount user:userName 0 30
(integer) 3
```

---

## 1.7. `ZSCAN`

```shell
127.0.0.1:6379> help zscan

  ZSCAN key cursor [MATCH pattern] [COUNT count]
  summary: Incrementally iterate sorted sets elements and associated scores
  since: 2.8.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1
1) "user1"
2) "user2"
3) "user3"
4) "user4"
5) "user5"

127.0.0.1:6379> zscan user:userName 0 match user1 count 3
1) "0"
2) 1) "user1"
   2) "10"

127.0.0.1:6379> zscan user:userName 0 match user* count 3
1) "0"
2)  1) "user1"
    2) "10"
    3) "user2"
    4) "20"
    5) "user3"
    6) "30"
    7) "user4"
    8) "40"
    9) "user5"
   10) "50"

127.0.0.1:6379> zscan user:userName 0 count 3
1) "0"
2)  1) "user1"
    2) "10"
    3) "user2"
    4) "20"
    5) "user3"
    6) "30"
    7) "user4"
    8) "40"
    9) "user5"
   10) "50"
```

---

## 1.8. `ZPOPMIN`, `ZPOPMAX`

각각 score 가 낮/높은 순으로 count 갯수만큼 pop 을 실행하는 명령어이다.

```shell
127.0.0.1:6379> help zpopmin

  ZPOPMIN key [count]
  summary: Remove and return members with the lowest scores in a sorted set
  since: 5.0.0
  group: sorted-set

127.0.0.1:6379> help zpopmax

  ZPOPMAX key [count]
  summary: Remove and return members with the highest scores in a sorted set
  since: 5.0.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user2"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"
11) "user6"
12) "60"
13) "user7"
14) "70"
15) "user8"
16) "80"
17) "user9"
18) "90"

127.0.0.1:6379> zpopmin user:userName
1) "user1"
2) "10"
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user2"
 2) "20"
 3) "user3"
 4) "30"
 5) "user4"
 6) "40"
 7) "user5"
 8) "50"
 9) "user6"
10) "60"
11) "user7"
12) "70"
13) "user8"
14) "80"
15) "user9"
16) "90"

127.0.0.1:6379> zpopmin user:userName 2
1) "user2"
2) "20"
3) "user3"
4) "30"
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user4"
 2) "40"
 3) "user5"
 4) "50"
 5) "user6"
 6) "60"
 7) "user7"
 8) "70"
 9) "user8"
10) "80"
11) "user9"
12) "90"

127.0.0.1:6379> zpopmax user:userName 2
1) "user9"
2) "90"
3) "user8"
4) "80"
127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user4"
2) "40"
3) "user5"
4) "50"
5) "user6"
6) "60"
7) "user7"
8) "70"
```
---

## 1.9. `ZREM`, `ZREMRANGEBYRANK`, `ZREMRANGEBYSCORE`

`ZREM`

```shell
127.0.0.1:6379> help zrem

  ZREM key member [member ...]
  summary: Remove one or more members from a sorted set
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user20"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"
11) "user6"
12) "60"
13) "user7"
14) "70"

# 존재하지 않는 member 삭제 시도 시
127.0.0.1:6379> zrem user:userName 40
(integer) 0

127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user20"
 4) "20"
 5) "user3"
 6) "30"
 7) "user4"
 8) "40"
 9) "user5"
10) "50"
11) "user6"
12) "60"
13) "user7"
14) "70"

# user4 member 삭제
127.0.0.1:6379> zrem user:userName user4
(integer) 1
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user20"
 4) "20"
 5) "user3"
 6) "30"
 7) "user5"
 8) "50"
 9) "user6"
10) "60"
11) "user7"
12) "70"
```

`ZREMRANGEBYRANK`

```shell
127.0.0.1:6379> help zremrangebyrank

  ZREMRANGEBYRANK key start stop
  summary: Remove all members in a sorted set within the given indexes
  since: 2.0.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
 1) "user1"
 2) "10"
 3) "user20"
 4) "20"
 5) "user3"
 6) "30"
 7) "user5"
 8) "50"
 9) "user6"
10) "60"
11) "user7"
12) "70"

127.0.0.1:6379> zremrangebyrank user:userName 1 2
(integer) 2

127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user1"
2) "10"
3) "user5"
4) "50"
5) "user6"
6) "60"
7) "user7"
8) "70"
```

`ZREMRANGEBYSCORE`

```shell
127.0.0.1:6379> help zremrangebyscore

  ZREMRANGEBYSCORE key min max
  summary: Remove all members in a sorted set within the given scores
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user1"
2) "10"
3) "user5"
4) "50"
5) "user6"
6) "60"
7) "user7"
8) "70"

127.0.0.1:6379> zremrangebyscore user:userName 55 65
(integer) 1

127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user1"
2) "10"
3) "user5"
4) "50"
5) "user7"
6) "70"
```

---

## 1.10. `ZINCRBY`

```shell
127.0.0.1:6379> help zincrby

  ZINCRBY key increment member
  summary: Increment the score of a member in a sorted set
  since: 1.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user1"
2) "10"
3) "user5"
4) "50"
5) "user7"
6) "70"

127.0.0.1:6379> zincrby user:userName 5 user5
"55"

127.0.0.1:6379> zrange user:userName 0 -1 withscores
1) "user1"
2) "10"
3) "user5"
4) "55"
5) "user7"
6) "70"
```

---

## 1.11. `ZUNION`, `ZINTER`, `ZDIFF`

### 1.11.1. `ZUNION`

- `numkeys` - 입력받을 key 의 갯수
- `WEIGHTS` - 각 score 에 곱해지는 값
- `AGGREGATE` - sum / min / max, 따로 지정하지 않으면 default 는 sum

```shell
127.0.0.1:6379> help zunion

  ZUNION numkeys key [key ...] [WEIGHTS weight [weight ...]] [AGGREGATE SUM|MIN|MAX] [WITHSCORES]
  summary: Add multiple sorted sets
  since: 6.2.0
  group: sorted-set
```

합집합을 수행하는데 동일한 member 가 있을 경우 score 를 합산하여 보여준다.

set1 = { (1,A), (2,B), (3,C) }  
set2 = { ......... (4,B), (5,C), (6,D) }  
result = { (1,A), **(6,B)**, **(8,C)**, (6,D) }

```shell
127.0.0.1:6379> zadd set1 1 a 2 b 3 c
(integer) 3
127.0.0.1:6379> zadd set2 4 b 5 c 6 d
(integer) 3
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zunion 2 set1 set2 withscores
1) "a"
2) "1"
3) "b"
4) "6"
5) "d"
6) "6"
7) "c"
8) "8"
```

`WEIGHTS` 사용

set1 = { (1,A), (2,B), (3,C) } ......... → { (1x2,A), (2x2,B), (3x2,C) }  
set2 = { ......... (4,B), (5,C), (6,D) } → { ............ (4x3,B), (5x3,C), (6x3,D) }   
result = { (2,A), (4+12,B), (6+15,C), (18,D)}
       = { (2,A), (16,B), (21,C), (18,D)}

```shell
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zunion 2 set1 set2 weights 2 3
1) "a"
2) "b"
3) "d"
4) "c"

127.0.0.1:6379> zunion 2 set1 set2 weights 2 3 withscores
1) "a"
2) "2"
3) "b"
4) "16"
5) "d"
6) "18"
7) "c"
8) "21"
```

`AGGREGATE` 사용

set1 = { (1,A), (2,B), (3,C) }  
set2 = { ......... (4,B), (5,C), (6,D) }  
min result = { (1,A), **(2,B)**, **(3,C)**, (6,D)}  
max result = { (1,A), **(4,B)**, **(5,C)**, (6,D)}

```shell
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zunion 2 set1 set2 aggregate min withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
7) "d"
8) "6"

127.0.0.1:6379> zunion 2 set1 set2 aggregate max withscores
1) "a"
2) "1"
3) "b"
4) "4"
5) "c"
6) "5"
7) "d"
8) "6"
```

```shell
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zunion 2 set1 set2 weights 2 3 aggregate max withscores
1) "a"
2) "2"
3) "b"
4) "12"
5) "c"
6) "15"
7) "d"
8) "18"
```

---

### 1.11.2. `ZINTER`

- `numkeys` - 입력받을 key 의 갯수
- `WEIGHTS` - 각 score 에 곱해지는 값
- `AGGREGATE` - sum / min / max, 따로 지정하지 않으면 default 는 sum

```shell
127.0.0.1:6379> help zinter

  ZINTER numkeys key [key ...] [WEIGHTS weight [weight ...]] [AGGREGATE SUM|MIN|MAX] [WITHSCORES]
  summary: Intersect multiple sorted sets
  since: 6.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zinter 2 set1 set2 withscores
1) "b"
2) "6"
3) "c"
4) "8"

127.0.0.1:6379> zinter 2 set1 set2 weights 2 3 withscores
1) "b"
2) "16"
3) "c"
4) "21"

127.0.0.1:6379> zinter 2 set1 set2 aggregate max withscores
1) "b"
2) "4"
3) "c"
4) "5"
```
---

### 1.11.3. `ZDIFF`

```shell
127.0.0.1:6379> help zdiff

  ZDIFF numkeys key [key ...] [WITHSCORES]
  summary: Subtract multiple sorted sets
  since: 6.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zdiff 2 set1 set2 withscores  # set1 에만 있는 member 조회
1) "a"
2) "1"

127.0.0.1:6379> zdiff 2 set2 set1 withscores  # set2 에만 있는 member 조회
1) "d"
2) "6"
```

---

## 1.12. `ZUNIONSTORE`, `ZINTERSTORE`, `ZDIFFSTORE`

연산 결과를 저장한다는 점 빼고는 `ZUNION`, `ZINTER`, `ZDIFF` 와 동일하다.

```shell
127.0.0.1:6379> help zunionstore

  ZUNIONSTORE destination numkeys key [key ...] [WEIGHTS weight [weight ...]] [AGGREGATE SUM|MIN|MAX]
  summary: Add multiple sorted sets and store the resulting sorted set in a new key
  since: 2.0.0
  group: sorted-set

127.0.0.1:6379> help zinterstore

  ZINTERSTORE destination numkeys key [key ...] [WEIGHTS weight [weight ...]] [AGGREGATE SUM|MIN|MAX]
  summary: Intersect multiple sorted sets and store the resulting sorted set in a new key
  since: 2.0.0
  group: sorted-set

127.0.0.1:6379> help zdiffstore

  ZDIFFSTORE destination numkeys key [key ...]
  summary: Subtract multiple sorted sets and store the resulting sorted set in a new key
  since: 6.2.0
  group: sorted-set
```

```shell
127.0.0.1:6379> zrange set1 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "2"
5) "c"
6) "3"
127.0.0.1:6379> zrange set2 0 -1 withscores
1) "b"
2) "4"
3) "c"
4) "5"
5) "d"
6) "6"

127.0.0.1:6379> zunionstore set3 2 set1 set2 withscores
(error) ERR syntax error

127.0.0.1:6379> zunionstore set3 2 set1 set2
(integer) 4

127.0.0.1:6379> zrange set3 0 -1 withscores
1) "a"
2) "1"
3) "b"
4) "6"
5) "d"
6) "6"
7) "c"
8) "8"
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [https://redis.io/commands](https://redis.io/commands/)
* [https://redis.io/commands - sortedSet](https://redis.io/commands/?group=sorted-set)
* [Resit 자료 구조 - ZSet](https://luran.me/381)
* [Redis Gate](http://redisgate.kr/redis/command/zunionstore.php)