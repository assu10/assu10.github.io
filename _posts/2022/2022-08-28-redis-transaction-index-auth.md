---
layout: post
title:  "Redis - Transaction, Index, User Authentication"
date: 2022-08-28 10:00
categories: dev
tags: redis transaction index authentication
---

이 포스트는 Redis 의 Transaction 관리 방법과 보안/인증에 대해 알아본다.  

<!-- TOC -->
* [1. Transaction & Isolation/Lock](#1-transaction--isolationlock)
* [2. CAS (Check And Set)](#2-cas-check-and-set)
  * [2.1. `MULTI` / `EXEC`](#21-multi--exec)
  * [2.2. redis 에서의 roll-back](#22-redis-에서의-roll-back)
  * [2.3. `DISCARD`](#23-discard)
  * [2.4. `WATCH` / `UNWATCH`](#24-watch--unwatch)
* [3. Index](#3-index)
  * [3.1. Sorted Set 타입 인덱스](#31-sorted-set-타입-인덱스)
* [4. 인증/보안/Roles, 사용자 생성](#4-인증보안roles-사용자-생성)
  * [4.1. 액세스 컨트롤 권한](#41-액세스-컨트롤-권한)
  * [4.2. 인증](#42-인증)
  * [4.3. 테스트](#43-테스트)
  * [4.4. User role 유형](#44-user-role-유형)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. Transaction & Isolation/Lock

Redis 는 트랜잭션을 제어할 수 있는 NoSQL 중 하나이다.  

Redis 는 데이터 일관성과 공유를 위해 **Data Set(Key/Value) Lock** 을 제공하고,  
트랜잭션 제어를 위해 **Read Uncommitted** 와 **Read Committed**, 2가지 유형을 제공한다.

**일반적인 RDBMS/NoSQL 에서 제공하는 Lock 메커니즘**
- Global Lock
- Database Lock
- Object Lock
- Page Lock
- Key/Value(Data Set) Lock

> **Isolation Level**  
> 트랜잭션에서 일관성없는 데이터를 허용하는 수준  


**Isolation Level 종류**
- Read Uncommitted (Level 0)
  - SELECT 문이 수행되는 동안 해당 데이터에 Shared Lock 이 걸리지 않음
  - 트랜잭션 처리 중인 데이터를 다른 트랜잭션이 읽는 것을 허용함
- Read Committed (Level 1)
  - SELECT 문이 수행되는 동안 해당 데이터에 Shared Lock 이 걸림
  - 트랜잭션이 처리 중이면 다른 트랜잭션이 접근할 수 없어 대기하게 됨 (commit 이 이루어진 트랜잭션만 조회 가능)
  - 대부분의 SQL 서버가 Default 로 사용하는 isolation level
- Repeatable Read (Level 2)
  - 트랜잭션이 완료될 때까지 SELECT 문이 사용하는 모든 데이터에 Shared Lock 이 걸림
  - 트랜잭션이 범위 내에서 조회한 데이터가 항상 동일함을 보장함
  - 트랜잭션이 완료되기 전까지 트랜잭션 영역에 해당하는 데이터 수정 불가능
  - MySQL 에서 Default 로 사용하는 isolation level
- Serializable (Level 3)
  - 트랜잭션이 완료될 때까지 SELECT 문이 사용하는 모든 데이터에 Shared Lock 이 걸림
  - 완벽한 읽기 일관성 모드 제공
  - 트랜잭션이 완료되기 전까지 트랜잭션 영역에 해당하는 데이터 수정 및 입력 불가능

---

# 2. CAS (Check And Set)

하나의 트랜잭션에 의해 데이터가 변경되는 시점에 다른 트랜잭션에 의해 동일한 데이터가 먼저 변경되는 경우 일관성에 문제가 발생한다.  
이렇게 동시 처리가 발생할 경우 먼저 작업을 요구한 사용자에게 우선권을 보장하고  
나중에 요구한 사용자의 세션에는 해당 트랜잭션이 충돌이 발생했을을 인지할 수 있도록 해주는 것을 Redis DB 에서는 **CAS** 라고 한다.

redis 의 트랜잭션을 사용하면 batch 단위로 commands 를 실행할 수 있다.

batch 단위로 처리되는 commands 는 실행 전에 QUEUE 에 serialized 된 상태로 담겨있고,  
실행 시에는 QUEUE 에 삽입된 순서에 맞춰 순차적으로 실행된다.

트랜잭션이 실행되는 동안에는 어떠한 request 의 영향도 받지 않으므로 독립성을 보장한다.

---

## 2.1. `MULTI` / `EXEC`

- `MULTI`: 트랜잭션의 시작을 알린다.
- `EXEC` : 트랜잭션을 종료한다. (commit)

```shell
127.0.0.1:6379> help multi

  MULTI
  summary: Mark the start of a transaction block
  since: 1.2.0
  group: transactions
  
127.0.0.1:6379> help exec

EXEC
summary: Execute all commands issued after MULTI
since: 1.2.0
group: transactions
```

```shell
127.0.0.1:6379> MULTI  # 트랜잭션에 담을 command 를 입력하기 전에 MULTI 선언
OK
127.0.0.1:6379(TX)> SET test1 111  # 트랜잭션 QUEUE 에 담을 command 를 순서대로 입력
QUEUED
127.0.0.1:6379(TX)> SET test2 222
QUEUED
127.0.0.1:6379(TX)> EXEC  # QUEUE 에 담긴 command 들을 순서대로 batch 로 실행
OK
OK
127.0.0.1:6379> GET test1
111
127.0.0.1:6379> GET test2
222
```

---

## 2.2. redis 에서의 roll-back

redis 의 트랜잭션은 roll-back 기능은 지원하지 않는다.  
따라서 트랜잭션 내부에서 에러가 발생해도 전체 트랜잭션은 roll-back 되지 않으며 에러가 발생하지 않은 command 는 정상적으로 실행된다.

```shell
127.0.0.1:6379> SET test1 10
OK
127.0.0.1:6379> GET test1
10
127.0.0.1:6379> MULTI
OK
127.0.0.1:6379(TX)> ZADD test1 1 100  # 문법상 오류가 있지만 QUEUE 에 들어갈때는 이슈없음
QUEUED
127.0.0.1:6379(TX)> INCRBY test1 100
QUEUED

127.0.0.1:6379(TX)> EXEC  # commit
WRONGTYPE Operation against a key holding the wrong kind of value  # 에러 발생

110  # 다음 command 는 정상적으로 실행
127.0.0.1:6379> GET test1
110
```

---

## 2.3. `DISCARD`

`MULTI` 를 선언해 트랜잭션이 시작된 후 QUEUE 에 담긴 모든 작업을 취소한다.

```shell
127.0.0.1:6379> help discard

  DISCARD
  summary: Discard all commands issued after MULTI
  since: 2.0.0
  group: transactions
```

```shell
127.0.0.1:6379> SET test1 10
OK
127.0.0.1:6379> MULTI
OK
127.0.0.1:6379(TX)> INCRBY test1 1
QUEUED
127.0.0.1:6379(TX)> INCRBY test1 2
QUEUED
127.0.0.1:6379(TX)> DISCARD  # 트랜잭션 선언 이후 QUEUE 에 담긴 commands 취소
OK
127.0.0.1:6379> EXEC
ERR EXEC without MULTI  # 트랜잭션이 없다는 에러 발생

127.0.0.1:6379> GET test1
10  # QUEUE 에 담겼던 commands 실행되지 않음
```

---

## 2.4. `WATCH` / `UNWATCH`

`WATCH` / `UNWATCH` 를 이용하여 key 의 변경을 감지한다.

`WATCH` 를 선언한 key 는 트랜잭션 외부에서 변경이 감지되면 해당 key 는 트랜잭션 내부에서의 변경을 허용하지 않는다.  
`WATCH` 를 선언한 클라이언트 뿐 아니라 다른 클라이언트에서도 트랜잭션 외부에서 해당 key 값이 변경되면 동일하게 트랜잭션 내부의 변경을 허용하지 않는다. 

예를 들어 *test1* key 에 `WATCH` 를 선언했는데 트랜잭션 외부에서 *test1* 를 변경하면 `MULTI` 로 선언한 트랜잭션 내부의 commands 는 
실행되지 않고 (nil) 을 리턴한다. 

```shell
127.0.0.1:6379> help watch

  WATCH key [key ...]
  summary: Watch the given keys to determine execution of the MULTI/EXEC block
  since: 2.2.0
  group: transactions
  
127.0.0.1:6379> help unwatch

  UNWATCH
  summary: Forget about all watched keys
  since: 2.2.0
  group: transactions  
```

```shell
127.0.0.1:6379> set test1 10
OK
127.0.0.1:6379> watch test1  # watch 로 key 모니터링 선언
OK
127.0.0.1:6379> incrby test1 1  # 트랜잭션 외부에서 key 변경
11
127.0.0.1:6379> multi  # 트랜잭션 시작 선언
OK
127.0.0.1:6379(TX)> incrby test1 2
QUEUED
127.0.0.1:6379(TX)> exec  # QUEUE 에는 쌓이지만 외부에서 key 변경이 감지되었으므로 QUEUE 에 쌓인 command 는 실행되지 않음

127.0.0.1:6379> get test1
11
```

한번 `WATCH` 를 선언한 key 는 `EXEC` 가 씰행되면 즉시 `UNWATCH` 상태로 변경된다.  
직접 `UNWATCH` 를 선언할 경우 `WATCH` 가 선언된 모든 key 를 반환한다. (각각의 key 별로는 UNWATCH 선언 불가)

또한 `WATCH` 와는 다르게 다른 클라이언트에서 선언한 `UNWATCH` 는 허용하지 않는다.  
즉, 외부 클라이언트에서 `UNWATCH` 를 선언했다고 하더라고 해당 key 는 `UNWATCH` 되지 않는다.

---

# 3. Index

- `Primary Key Index`
  - Redis 는 기본적으로 하나의 Key 와 하나 이상의 Field/Element 로 구성되는데, 이 때 Key 에 빠른 검색을 위해 기본적으로 생성되는 인덱스
- `Secondary Index`
  - 필요에 따라 생성하는 추가적인 인덱스
    - `Exact Match By a Secondafy Index`
      - 인덱스 키를 통해 검색 시 유일한 값을 검색하는 경우
    - `Range By a Secondafy Index`
      - 인텍스 키를 통해 검색 시 일정 범위의 값을 검색 조건으로 부여하는 경우

---

## 3.1. Sorted Set 타입 인덱스

> Sorted Set 에 대한 자세한 내용은 [Redis - Sorted Set](https://assu10.github.io/dev/2022/07/30/redis-zset/) 을 참고하세요.

```shell
127.0.0.1:6379> zadd order.shipdate.index 1 '202208011:20220802' 2 '202208012:20220803'  # orderno:shipdate 필드에 인덱스 생성
(integer) 2
127.0.0.1:6379> zrange order.shipdate.index 0 -1
1) "202208011:20220802"
2) "202208012:20220803"
127.0.0.1:6379> zscan order.shipdate.index 0
1) "0"
2) 1) "202208011:20220802"
   2) "1"
   3) "202208012:20220803"
   4) "2"
127.0.0.1:6379> zscan order.shipdate.index 0 match 202208011*
1) "0"
2) 1) "202208011:20220802"
   2) "1"

127.0.0.1:6379> zadd order.no.index 1 202208011 2 202208012  # orderno 필드에 인덱스 생성
(integer) 2
127.0.0.1:6379> zrange order.no.index 0 -1
1) "202208011"
2) "202208012"
```

---

# 4. 인증/보안/Roles, 사용자 생성

## 4.1. 액세스 컨트롤 권한

액세스 컨트롤을 하는 방법 중 하나는 미리 DB 내에 사용자 계정/암호를 생성하여 Redis 서버 접속 시 계정과 암호를 입력하는 방법이다.

```shell
vi redis.conf

...
requirepass redis123
```

여러 대의 서버를 분산, 복제 시스템으로 구축할 때는 Master, Slave, Sentinel, Partition, Replication 서버 간 네트워크 액세스 컨트롤 권한이
필요하게 되는데 이와 같은 기능을 활성화하려면 conf 파일 내의 `requirepass`, `masterauth` 파라미터를 통해 환경 설정을 해야 한다.

```shell
vi redis.conf

...
masterauth redis123
```

---

## 4.2. 인증

redis 서버는 2가지 인증 방법을 제공한다.

첫 번째는 **OS 인증** 이다.  
conf 파일에 접속할 클라이언트의 IP 주소를 미리 지정하는 방식으로, IP 주소로만 접속을 허용하는 네트워크 인증 방식이다.

```shell
vi redis.conf

...
bind_ip 111.222.0.10
```

두 번째는 내부 인증 방법으로 Redis 서버에 접속한 후 **auth 명령어** 로 미리 생성해 둔 사용자 계정과 암호를 입력하여 인증하는 방식이다.

---

## 4.3. 테스트

redis.conf 수정
```shell
$ pwd
/usr/local/etc

$ vi redis.conf

...
requirepass redis123
```

redis-server 시작
```shell
$ redis-server /usr/local/etc/redis.conf
```

redis-cli 접속 - 암호없이 로그인 시도
```shell
$ redis-cli  # 암호없이 로그인 시도
127.0.0.1:6379> info
NOAUTH Authentication required.  # 인증 실패

127.0.0.1:6379> exit
```

redis-cli 접속 - 암호를 넣어 로그인 시도
```shell
$ redis-cli -a redis123  # 암호를 넣어 로그인 시도
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> info  # 정상 인증
# Server
redis_version:7.0.4
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:ef6295796237ef48
```

redis-cli 접속 - auth 명령어 이용하여 인증
```shell
$ redis-cli  # 암호없이 로그인 시도
127.0.0.1:6379> info
NOAUTH Authentication required.  # 인증 실패

127.0.0.1:6379> auth redis123  # auth 명령어로 인증
OK
127.0.0.1:6379> info
# Server
redis_version:7.0.4
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:ef6295796237ef48
redis_mode:standalone
```

> **커뮤니티 에디션**  
> 커뮤니티 에디션에서 standalone 서버를 구축하는 경웬는 기본적으로 사용자 계정을 사용자가 직접 부여하는 이름으로 생성할 수 없다.  
> conf 파일의 requirepass 파라미터를 통해 기본 계정에 암호 부여만 가능하다.

> **엔터프라이즈 에디션**  
> 사용자를 직접 설계하여 생성할 수 있으며, 사용자가 부여한 사용자명을 사용할 수 있고,  
> 사용자 정의 롤(User Defined Roles)을 생성하여 부여할 수도 있다.

---

## 4.4. User role 유형

User role 은 엔터프라이즈 에디션 서버에만 제공되며 유형은 아래와 같다.

- Admin role
  - 모든 액세스 권한 소유
- Cluster Member role
  - 클러스터 관리
- Cluster Viewer role
  - 클러스터 셋팅 read
- DB Member role
  - DB 관리자
- DB Viewer role
  - DB 셋팅 read

![user role](/assets/img/dev/2022/0828/redis-roles.png)

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [https://redis.io/commands - transaction](https://redis.io/commands/?group=transactions)
* [Redis docs = Transactions](https://redis.io/docs/manual/transactions/)
* [트랜잭션 격리 수준(Transaction Isolation Level)](https://gyoogle.dev/blog/computer-science/data-base/Transaction%20Isolation%20Level.html)
* [Redis Transaction](https://minholee93.tistory.com/entry/Redis-Transaction)
* [레디스 레플리케이션 예제(Redis Replication)](https://jdm.kr/blog/157)
* [redis docs - roles](https://docs.redis.com/latest/rs/security/access-control/create-roles/)