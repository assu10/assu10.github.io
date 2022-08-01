---
layout: post
title:  "Redis - List"
date:   2022-07-21 10:00
categories: dev
tags: redis list
---

이 포스트는 Redis 의 데이터 타입 중 하나인 `List` 타입에 대해 알아본다.

> - `List`
>   - `LPUSH`, `RPUSH`
>   - `LRANGE`
>   - `LPOP`, `RPOP`
>   - `LPUSHX`, `RPUSHX`
>   - `RPOPLPUSH`
>   - `LSET`
>   - `LLEN`
>   - `LINSERT`
>   - `LTRIM`
>   - `LREM`
>   - `LINDEX`, `LPOS`
>   - `LMOVE`

---

# 1. `List`

- 하나의 key 에 여러 개의 배열값 저장
- String 타입의 경우 배열에 저장할 수 있는 데이터 크기는 512 MB 
- 양 끝의 데이터 연산 비용은 낮지만, 중간에 위치한 데이터의 연산 비용은 상대적으로 높으므로 데이터 성격 및 연산 종류에 따라 알고 써야 함

```shell
$ pwd
/usr/local/opt/redis/bin

$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ redis-cli
127.0.0.1:6379>
```

---

## 1.1. `LPUSH`, `RPUSH`

```shell
127.0.0.1:6379> help lpush

  LPUSH key element [element ...]
  summary: Prepend one or multiple elements to a list
  since: 1.0.0
  group: list

127.0.0.1:6379> help rpush

  RPUSH key element [element ...]
  summary: Append one or multiple elements to a list
  since: 1.0.0
  group: list
```

```shell
127.0.0.1:6379> lpush userid:1 assu
(integer) 1
127.0.0.1:6379> lpush userid:1 seoul
(integer) 2
127.0.0.1:6379> lpush userid:1 20 woman
(integer) 4
127.0.0.1:6379> lrange userid:1 0 -1
1) "woman"
2) "20"
3) "seoul"
4) "assu"
127.0.0.1:6379> lrange userid:1 -1 0
(empty array)
```

```shell
127.0.0.1:6379> rpush userid:1 assu
(integer) 1
127.0.0.1:6379> rpush userid:1 seoul
(integer) 2
127.0.0.1:6379> rpush userid:1 20 woman
(integer) 4
127.0.0.1:6379> lrange userid:1 0 -1
1) "assu"
2) "seoul"
3) "20"
4) "woman"
127.0.0.1:6379> lrange userid:1 -1 0
(empty array)
```

---

## 1.2. `LRANGE`

List 에 저장된 값을 조회하는 명령어이다.  
전체 조회 시엔 start 0, end -1 을 입력한다.

```shell
127.0.0.1:6379> help lrange

  LRANGE key start stop
  summary: Get a range of elements from a list
  since: 1.0.0
  group: list
```

```shell
127.0.0.1:6379> rpush userid:1 assu
(integer) 1
127.0.0.1:6379> rpush userid:1 seoul
(integer) 2
127.0.0.1:6379> rpush userid:1 20 woman
(integer) 4
127.0.0.1:6379> lrange userid:1 0 -1
1) "assu"
2) "seoul"
3) "20"
4) "woman"
127.0.0.1:6379> lrange userid:1 -1 0
(empty array)
```

---

## 1.3. `LPOP`, `RPOP`

```shell
127.0.0.1:6379> help lpop

  LPOP key [count]
  summary: Remove and get the first elements in a list
  since: 1.0.0
  group: list

127.0.0.1:6379> help rpop

  RPOP key [count]
  summary: Remove and get the last elements in a list
  since: 1.0.0
  group: list
```

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5
(integer) 5
127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"
127.0.0.1:6379> lpop list1
"e1"
127.0.0.1:6379> lrange list1 0 -1
1) "e2"
2) "e3"
3) "e4"
4) "e5"
127.0.0.1:6379> rpop list1 2
1) "e5"
2) "e4"
127.0.0.1:6379> lrange list1 0 -1
1) "e2"
2) "e3"
```

---

## 1.4. `LPUSHX`, `RPUSHX`

List 가 존재할 경우에만 각각 push 를 수행하는 명령어이다.

```shell
127.0.0.1:6379> help lpushx

  LPUSHX key element [element ...]
  summary: Prepend an element to a list, only if the list exists
  since: 2.2.0
  group: list

127.0.0.1:6379> help rpushx

  RPUSHX key element [element ...]
  summary: Append an element to a list, only if the list exists
  since: 2.2.0
  group: list
```

```shell
127.0.0.1:6379> lpushx list1 e1  # list1 이 없기 때문에 push 되지 않음
(integer) 0

127.0.0.1:6379> lrange list1 0 -1
(empty array)

127.0.0.1:6379> lpush list1 el # list1 생성
(integer) 1

127.0.0.1:6379> lrange list1 0 -1
1) "el"

127.0.0.1:6379> lpushx list1 e1 # list1 이 있기 때문에 push 됨
(integer) 2

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "el"
```

---

## 1.5. `RPOPLPUSH`

`RPOP` + `LPUSH` 의 명령어를 합쳐놓은 것과 같이 동작한다.  
source list 로 부터 `RPOP` 을 하여 꺼낸 항목을 dest list 에 `LPUSH` 한다.

```shell
127.0.0.1:6379> help rpoplpush

  RPOPLPUSH source destination
  summary: Remove the last element in a list, prepend it to another list and return it
  since: 1.2.0
  group: list
```

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5
(integer) 5

127.0.0.1:6379> rpush list2 e6 e7 e8
(integer) 3

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"

127.0.0.1:6379> lrange list2 0 -1
1) "e6"
2) "e7"
3) "e8"

127.0.0.1:6379> rpoplpush list1 list2
"e5"

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"

127.0.0.1:6379> lrange list2 0 -1
1) "e5"
2) "e6"
3) "e7"
4) "e8"
```

---

## 1.6. `LSET`

List 특정 인덱스의 값을 교체한다.

```shell
127.0.0.1:6379> help lset

  LSET key index element
  summary: Set the value of an element in a list by its index
  since: 1.0.0
  group: list
```

```shell
127.0.0.1:6379> lpush list1 e1 e2 e3 e4 e5
(integer) 5

127.0.0.1:6379> lrange list1 0 -1
1) "e5"
2) "e4"
3) "e3"
4) "e2"
5) "e1"

127.0.0.1:6379> lset list1 1 e9
OK

127.0.0.1:6379> lrange list1 0 -1
1) "e5"
2) "e9"
3) "e3"
4) "e2"
5) "e1"
```

---

## 1.7. `LLEN`

```shell
127.0.0.1:6379> help llen

  LLEN key
  summary: Get the length of a list
  since: 1.0.0
  group: list
```

```shell
127.0.0.1:6379> lrange list1 0 -1
1) "e5"
2) "e9"
3) "e3"
4) "e2"
5) "e1"

127.0.0.1:6379> llen list1
(integer) 5

127.0.0.1:6379> lrange list2 0 -1
(empty array)

127.0.0.1:6379> llen list2
(integer) 0
```

---

## 1.8. `LINSERT`

List 에 존재하는 값을 기준으로 insert 를 수행한다.

```shell
127.0.0.1:6379> help linsert

  LINSERT key BEFORE|AFTER pivot element
  summary: Insert an element before or after another element in a list
  since: 2.2.0
  group: list
```

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5
(integer) 5

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"

127.0.0.1:6379> linsert list1 before e3 e2.5  # e3 앞에 e2.5 삽입
(integer) 6

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e2.5"
4) "e3"
5) "e4"
6) "e5"
```

```shell
127.0.0.1:6379> rpush list1 e2
(integer) 7

127.0.0.1:6379> lrange list1 0 -1  # e2 가 2개임
1) "e1"
2) "e2"
3) "e2.5"
4) "e3"
5) "e4"
6) "e5"
7) "e2"

127.0.0.1:6379> linsert list1 after e2 e2.7
(integer) 8

127.0.0.1:6379> lrange list1 0 -1  # 앞에서부터 먼저 발견된 element 를 기준으로 insert 수행
1) "e1"
2) "e2"
3) "e2.7"
4) "e2.5"
5) "e3"
6) "e4"
7) "e5"
8) "e2"
```

---

## 1.9. `LTRIM`

java 나 javascript 에서의 trim 은 좌우 공백을 제거해주는 함수이지만 Redis 에서는 start ~ stop ***에 해당하지 않는*** 데이터를 삭제하는 명령어이다.

주의할 점은 ***일치하지 않는 범위의 start ~ stop 을 지정하면 전체 데이터가 삭제***된다.

```shell
127.0.0.1:6379> help ltrim

  LTRIM key start stop
  summary: Trim a list to the specified range
  since: 1.0.0
  group: list
```

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5
(integer) 5

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"

127.0.0.1:6379> ltrim list1 1 3
OK

127.0.0.1:6379> lrange list1 0 -1
1) "e2"
2) "e3"
3) "e4"

127.0.0.1:6379> ltrim list1 1 3
OK

127.0.0.1:6379> lrange list1 0 -1
1) "e3"
2) "e4"

127.0.0.1:6379> ltrim list1 5 9  # 다른 index 의 데이터 삭제 시도
OK

127.0.0.1:6379> lrange list1 0 -1  # 전체 데이터 삭제
(empty array)
```

리스트의 마지막을 기준으로 데이터 삭제를 원하면 인덱스를 음수로 설정하면 된다.

- (+) 0 1 2 3 4
- (-) -5 -4 -3 -2 -1

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5
(integer) 5

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"

127.0.0.1:6379> ltrim list1 -2 -1  # 맨 우측 2개를 제외하고 나머지 삭제
OK

127.0.0.1:6379> lrange list1 0 -1
1) "e4"
2) "e5"
```

---

## 1.10. `LREM`

count 는 같은 값을 갖는 아이템을 기준으로 삭제할 갯수를 의미한다.  
count 에 0 을 넣으면 일치하는 요소 전체를 삭제한다.

```shell
127.0.0.1:6379> help lrem

  LREM key count element
  summary: Remove elements from a list
  since: 1.0.0
  group: list
```

```shell
27.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5 e3 e4 e3 e4
(integer) 9

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"
6) "e3"
7) "e4"
8) "e3"
9) "e4"

127.0.0.1:6379> lrem list1 1 e3  # 왼쪽부터 e3 인 요소 1개 삭제
(integer) 1

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e4"
4) "e5"
5) "e3"
6) "e4"
7) "e3"
8) "e4"

127.0.0.1:6379> lrem list1 5 e3  # 왼쪽부터 e3 인 요소 5개 삭제
(integer) 2

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e4"
4) "e5"
5) "e4"
6) "e4"

127.0.0.1:6379> lrem list1 0 e4  # e4 인 요소 전체 삭제
(integer) 3

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e5"
```

---

## 1.11. `LINDEX`, `LPOS`

`LINDEX` 는 인덱스로 값을 조회하는 명령어이다.
`LPOS` 는 값으로 인덱스를 조회하는 명령어이다.

```shell
127.0.0.1:6379> help lindex

  LINDEX key index
  summary: Get an element from a list by its index
  since: 1.0.0
  group: list

127.0.0.1:6379> help lpos

  LPOS key element [RANK rank] [COUNT num-matches] [MAXLEN len]
  summary: Return the index of matching elements on a list
  since: 6.0.6
  group: list
```

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5 e3 e4
(integer) 7
127.0.0.1:6379> lindex list1 3
"e4"
```

`LPOS` 에서 `count` 는 일치하는 데이터가 여러 개일 때 count 갯수만큼 리턴한다. (0을 쓰면 전체 일치하는 index 리턴)

```shell
127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"
6) "e3"
7) "e4"

127.0.0.1:6379> lpos list1 e3 count 0
1) (integer) 2
2) (integer) 5

127.0.0.1:6379> lpos list1 e3 count 1
1) (integer) 2

127.0.0.1:6379> lpos list1 e3 count 2
1) (integer) 2
2) (integer) 5
```

`LPOS` 에서 `rank` 는 순위를 지정하여 인덱스를 조회한다. 

```shell
127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"
6) "e3"
7) "e4"

127.0.0.1:6379> lpos list1 e3 rank 1
(integer) 2

127.0.0.1:6379> lpos list1 e3 rank 2  # 두 번째 e3 의 인덱스 조회
(integer) 5

127.0.0.1:6379> lpos list1 e3 rank -1 # 마지막 e3 의 인덱스 조회
(integer) 5

127.0.0.1:6379> lpos list1 e3 rank -1 count 2 # e3 의 인덱스를 뒤에서부터 조회
1) (integer) 5
2) (integer) 2
```

`LPOS` 에서 `maxlen` 는 검색 범위를 지정하여 해당 범위 내에서의 요소 인덱스를 조회한다.

```shell
127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"
6) "e3"
7) "e4"

127.0.0.1:6379> lpos list1 e3 maxlen 5
(integer) 2

127.0.0.1:6379> lpos list1 e3 maxlen 10
(integer) 2

127.0.0.1:6379> lpos list1 e3 maxlen 2
(nil)
```

---

## 1.12. `LMOVE`

```shell
127.0.0.1:6379> help lmove

  LMOVE source destination LEFT|RIGHT LEFT|RIGHT
  summary: Pop an element from a list, push it to another list and return it
  since: 6.2.0
  group: list
```

`RPOPLPUSH` 와 비슷하지만 `RPOPLPUSH` 보다 좀 더 유연하게 사용 가능하다.

`RPOPLPUSH` 는 source 에서 RPOP 을 하여 destination 에 LPUSH 를 하지만,  
`LMOVE` 는 아래에 나오는 예시와 같이 다양하게 동작이 가능하다.

> `RPOPLPUSH`
> `RPOP` + `LPUSH` 의 명령어를 합쳐놓은 것과 같이 동작한다.  
> source list 로 부터 `RPOP` 을 하여 꺼낸 항목을 dest list 에 `LPUSH` 한다.

- LEFT LEFT: head → head
- LEFT RIGHT: head → tail
- RIGHT LEFT: tail → head
- RIGHT RIGHT: tail → tail

```shell
127.0.0.1:6379> rpush list1 e1 e2 e3 e4 e5
(integer) 5
127.0.0.1:6379> rpush list2 e6 e7 e8 e9 e10
(integer) 5

127.0.0.1:6379> lrange list1 0 -1
1) "e1"
2) "e2"
3) "e3"
4) "e4"
5) "e5"

127.0.0.1:6379> lrange list2 0 -1
1) "e6"
2) "e7"
3) "e8"
4) "e9"
5) "e10"

127.0.0.1:6379> lmove list1 list2 LEFT LEFT  # LEFT LEFT: head → head
"e1"
127.0.0.1:6379> lrange list1 0 -1
1) "e2"
2) "e3"
3) "e4"
4) "e5"
127.0.0.1:6379> lrange list2 0 -1
1) "e1"
2) "e6"
3) "e7"
4) "e8"
5) "e9"
6) "e10"

127.0.0.1:6379> lmove list1 list2 RIGHT LEFT  # RIGHT LEFT: tail → head
"e5"
127.0.0.1:6379> lrange list1 0 -1
1) "e2"
2) "e3"
3) "e4"
127.0.0.1:6379> lrange list2 0 -1
1) "e5"
2) "e1"
3) "e6"
4) "e7"
5) "e8"
6) "e9"
7) "e10"
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [https://redis.io/commands](https://redis.io/commands/)
* [https://redis.io/commands - list](https://redis.io/commands/?group=list)
* [Resit 자료 구조 - List](https://luran.me/364)