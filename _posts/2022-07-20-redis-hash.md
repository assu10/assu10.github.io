---
layout: post
title:  "Redis - Hash"
date:   2022-07-20 10:00
categories: dev
tags: redis hash
---

이 포스트는 Redis 의 데이터 타입 중 하나인 `Hash` 타입에 대해 알아본다.

> - 데이터 타입
>   - `Hash`
>      - `HSET`, `HGET`
>      - `HGETALL`
>      - `HKEYS`, `HVALS`
>      - ~~`HMSET`~~, `HMGET`
>      - `HEXISTS`
>      - `HDEL`
>      - `HLEN`
>      - `HSTRLEN`
>      - `HRANDFIELD`
>      - `HSETNX`
>      - `HINCRBY`, `HINCRBYFLOAT`
>      - `HSCAN`

---

# 1. 데이터 타입

Redis 에서 데이터 표현 기본 타입은 하나의 Key 와 하나 이상의 Field/Element 값으로 구성하는 것이다.

- Key
  - ASCII value 저장 가능
- Value
  - 기본적으로 String 데이터 저장
  - Container 타입의 데이터 저장 가능

> **Container 타입**  
> Hash, List, Set, Sorted Set 이 포함됨 

---

# 2. `Hash` 

- 하나의 key 에 여러 개의 fields 와 value 로 구성된 데이터 저장
- RDBMS 에서 PK 와 하나 이상의 컬럼으로 구성된 테이블 구조와 매우 흡사한 데이터 유형
- 하나의 Key 는 Object 명과 하나 이상의 Field 값을 `:` 으로 결합하여 표현 가능  
  예) *order:20220719:01*
- 문자 저장 시엔 `""` 가 사용, 숫자 저장 시엔 `""` 없이 사용
- Field 개수 제한 없음

```shell
$ pwd
/usr/local/opt/redis/bin

$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ redis-cli
127.0.0.1:6379>
```

---

## 2.1. `HSET`, `HGET`

```shell
127.0.0.1:6379> help HSET

  HSET key field value [field value ...]
  summary: Set the string value of a hash field
  since: 2.0.0
  group: hash

127.0.0.1:6379> help HGET

  HGET key field
  summary: Get the value of a hash field
  since: 2.0.0
  group: hash
  
```

`HSET` 으로 하나 이상의 field 값 설정이 가능하다. (=`HMSET` 과 동일)

```shell
127.0.0.1:6379> HSET order:20220719 username "assu" locate "seoul" userage 20
(integer) 3
127.0.0.1:6379> HGET order:20220719 username
"assu"
127.0.0.1:6379> HGET order:20220719 userage
"20"
127.0.0.1:6379> HGET order:20220719 userage1
(nil)
```

전체 필드와 그 값들 조회 시엔 `HGETALL` 을 사용한다.

---

## 2.2. `HGETALL`

key 에 매핑되는 모든 field 와 value 를 조회한다.

```shell
127.0.0.1:6379> help HGETALL

  HGETALL key
  summary: Get all the fields and values in a hash
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HGETALL order:20220719
1) "username"
2) "assu"
3) "locate"
4) "seoul"
5) "userage"
6) "20"
```

위와 같이 field, value 가 모두 나와 구분이 어려울 땐 `HKEYS`, `HVALS` 명령어로 확인할 수 있다.

---

## 2.3. `HKEYS`, `HVALS`

```shell
127.0.0.1:6379> help HKEYS

  HKEYS key
  summary: Get all the fields in a hash
  since: 2.0.0
  group: hash

127.0.0.1:6379> help HVALS

  HVALS key
  summary: Get all the values in a hash
  since: 2.0.0
  group: hash
```

`HKEYS` 는 모든 field 리스트를 조회한다.

```shell
127.0.0.1:6379> HKEYS order:20220719
1) "username"
2) "locate"
3) "userage"
```

```shell
127.0.0.1:6379> HVALS order:20220719
1) "assu"
2) "seoul"
3) "20"
```

---

## 2.4. ~~`HMSET`~~, `HMGET`

> Redis 4.0.0 부터는 `HMSET` 이 deprecated 된다고 하니 참고.
> 
> As of Redis version 4.0.0, this command is regarded as deprecated.  
> It can be replaced by HSET with multiple field-value pairs when migrating or writing new code.  
> (https://redis.io/commands/HMSET/)

```shell

127.0.0.1:6379> help HMGET

  HMGET key field [field ...]
  summary: Get the values of all the given hash fields
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HSET order:20220719 username "assu" locate "seoul" userage 20
(integer) 3
127.0.0.1:6379> HGET order:20220719 username
"assu"

127.0.0.1:6379> HMGET order:20220719 username userage
1) "assu"
2) "20"
```

---

## 2.5. `HEXISTS`

특정 필드가 존재하는지 확인하는 명령어이다.  
필드가 존재하면 1, 없으면 0을 리턴한다.

```shell
127.0.0.1:6379> help HEXISTS

  HEXISTS key field
  summary: Determine if a hash field exists
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HSET order:20220719 username "assu" locate "seoul" userage 20
(integer) 3
127.0.0.1:6379> HEXISTS order:20220719 userage
(integer) 1
127.0.0.1:6379> HEXISTS order:20220719 userage1
(integer) 0
```

---

## 2.6. `HDEL`

기존에 존재하는 field 를 삭제하는 명령어이다.

```shell
127.0.0.1:6379> help HDEL

  HDEL key field [field ...]
  summary: Delete one or more hash fields
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HGETALL order:20220719
1) "username"
2) "assu"
3) "locate"
4) "seoul"
5) "userage"
6) "20"
127.0.0.1:6379> HKEYS order:20220719
1) "username"
2) "locate"
3) "userage"
127.0.0.1:6379> HDEL order:20220719 username userage
(integer) 2
127.0.0.1:6379> HGETALL order:20220719
1) "locate"
2) "seoul"
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
127.0.0.1:6379> HEXISTS order:20220719 userage
(integer) 0
```

---

## 2.6. `HLEN`

해당 key 에 정의된 field 의 수를 조회한다.

```shell
127.0.0.1:6379> help HLEN

  HLEN key
  summary: Get the number of fields in a hash
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HLEN order:20220719
(integer) 1
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
127.0.0.1:6379> HSET order:20220719 username assu
(integer) 1
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
2) "username"
127.0.0.1:6379> HLEN order:20220719
(integer) 2
```

---

## 2.7. `HSTRLEN`

field 에 매핑된 value 의 길이를 조회한다.

```shell
127.0.0.1:6379> help HSTRLEN

  HSTRLEN key field
  summary: Get the length of the value of a hash field
  since: 3.2.0
  group: hash
```

```shell
127.0.0.1:6379> HSTRLEN order:20220719 username
(integer) 4
127.0.0.1:6379> HGET order:20220719 username
"assu"
```

---

## 2.8.  `HRANDFIELD`

해당 키에서 랜덤하게 하나 혹은 여러 개의 field 를 조회한다.

```shell
127.0.0.1:6379> help HRANDFIELD

  HRANDFIELD key [count [WITHVALUES]]
  summary: Get one or multiple random fields from a hash
  since: 6.2.0
  group: hash
```

```shell
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
2) "username"
3) "userage"
127.0.0.1:6379> HRANDFIELD order:20220719
"locate"
127.0.0.1:6379> HRANDFIELD order:20220719
"userage"
127.0.0.1:6379> HRANDFIELD order:20220719 2
1) "username"
2) "userage"
127.0.0.1:6379> HRANDFIELD order:20220719 2
1) "username"
2) "locate"
```

---

## 2.9. `HSETNX`

해당 field 가 존재하지 않을 때만 value 를 설정한다.

```shell
127.0.0.1:6379> help HSETNX

  HSETNX key field value
  summary: Set the value of a hash field, only if the field does not exist
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HGETALL order:20220719
1) "locate"
2) "seoul"
3) "username"
4) "assu"
5) "userage"
6) "20"
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
2) "username"
3) "userage"
127.0.0.1:6379> HSETNX order:20220719 talls 163
(integer) 1
127.0.0.1:6379> HSETNX order:20220719 talls 163
(integer) 0
127.0.0.1:6379> HGETALL order:20220719
1) "locate"
2) "seoul"
3) "username"
4) "assu"
5) "userage"
6) "20"
7) "talls"
8) "163"
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
2) "username"
3) "userage"
4) "talls"
```

---

## 2.10. `HINCRBY`, `HINCRBYFLOAT`

`HINCRBY` 는 해당 field 의 value 에 셋팅한 숫자만큼 증감한다.

```shell
127.0.0.1:6379> help HINCRBY

  HINCRBY key field increment
  summary: Increment the integer value of a hash field by the given number
  since: 2.0.0
  group: hash
```

```shell
127.0.0.1:6379> HGET order:20220719 userage
"20"
127.0.0.1:6379> HINCRBY order:20220719 userage 3
(integer) 23
127.0.0.1:6379> HGET order:20220719 userage
"23"
127.0.0.1:6379> HINCRBY order:20220719 userage -3
(integer) 20
127.0.0.1:6379> HGET order:20220719 userage
"20"
127.0.0.1:6379> HINCRBY order:20220719 username -3
(error) ERR hash value is not an integer
```

`HINCRBYFLOAT` 는 `HINCRBY` 와 같은 동작을 하지만 소숫점 기반으로 연산을 한다.

```shell
127.0.0.1:6379> help HINCRBYFLOAT

  HINCRBYFLOAT key field increment
  summary: Increment the float value of a hash field by the given amount
  since: 2.6.0
  group: hash
```

```shell
127.0.0.1:6379> HGET order:20220719 userage
"20"
127.0.0.1:6379> HINCRBYFLOAT order:20220719 userage 3
"23"
127.0.0.1:6379> HGET order:20220719 userage
"23"
127.0.0.1:6379> HINCRBYFLOAT order:20220719 userage 3.8
"26.8"
127.0.0.1:6379> HGET order:20220719 userage
"26.8"
```

---

## 2.11. `HSCAN`

성능을 위해 `keys` 대신 `HSCAN` 사용을 권장한다.  
Redis 는 싱글 스레드로 동작하기 때문에 어떤 명령어를 수행하면 (=keys 를 쓰는 순간) Redis 는 이 명령을 처리하기 위해 멈춰버린다.  
특히, 트래픽이 많은 서버는 `keys` 때문에 장애를 일으키기도 한다. 

`scan` 는 `keys` 처럼 한번에 모든 key 를 읽어보는 것이 아니라 count 값을 정하여 그 count 값 만큼 여러 번 Redis 의 key 를 조회하는 것이다.

count 를 작게 잡으면 count 만큼 key 를 조회하는 시간이 적게 걸리고, 대신 모든 데이터를 조회하는 시간은 오래 걸린다.  
하지만 그 사이사이 시간에 다른 요청들을 Redis 에서 처리가 가능하다.

count 를 크게 잡으면 count 개수만큼 key 를 조회하는 시간이 오래 걸리고, 대신 모든 데이터를 조회하는 시간은 적게 걸린다.  
하지만 그 사이사이 다른 요청을 받는 횟수가 줄어들어 Redis 가 다른 요청을 처리하는데 병목 현상이 생길 수 있다.

`keys` 의 단점을 보완하면서 성능도 좋은 `scan` 을 사용하는 것을 권장한다.

cursor 값을 0(default 10) 으로 지정한 `SCAN`/`SSCAN`/`ZSCAN`/`HSCAN` 명령으로 순회가 시작되고,  
이어지는 순회에 사용할 cursor 값과 지정한 패턴(pattern)과 일치하는 키를 최대 지정한 갯수(count)만큼 반환한다.  
반환된 cursor 값이 0 이면 순회가 종료되는데 이 과정을 전체 순회(full iteration)이라고 한다.

> count 설정값에 따른 퍼포먼스는 [Redis scan 명령어 퍼포먼스](https://medium.com/@chlee7746/redis-scan-%EB%AA%85%EB%A0%B9%EC%96%B4-%ED%8D%BC%ED%8F%AC%EB%A8%BC%EC%8A%A4-e29e242b8038) 에
> 어떤 분이 잘 정리해주셨습니다.

```shell
127.0.0.1:6379> help HSCAN

  HSCAN key cursor [MATCH pattern] [COUNT count]
  summary: Incrementally iterate hash fields and associated values
  since: 2.8.0
  group: hash
```

```shell
127.0.0.1:6379> HKEYS order:20220719
1) "locate"
2) "username"
3) "userage"
4) "talls"
127.0.0.1:6379> HSCAN order:20220719 0 match user* count 1
1) "0"
2) 1) "username"
   2) "assu"
   3) "userage"
   4) "26.8"
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [https://redis.io/commands](https://redis.io/commands/)
* [https://redis.io/commands - hash](https://redis.io/commands/?group=hash)
* [Redis 자료구조 - Hash](https://luran.me/376)
* [Redis의 SCAN은 어떻게 동작하는가?](https://tech.kakao.com/2016/03/11/redis-scan/)
* [성능을 위해 Redis keys 대신 scan 이용하기](https://tjdrnr05571.tistory.com/11)
* [Redis scan 명령어 퍼포먼스](https://medium.com/@chlee7746/redis-scan-%EB%AA%85%EB%A0%B9%EC%96%B4-%ED%8D%BC%ED%8F%AC%EB%A8%BC%EC%8A%A4-e29e242b8038)