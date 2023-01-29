---
layout: post
title:  "Redis - RedisJSON"
date:   2022-08-07 10:00
categories: dev
tags: redis rejson RedisJSON
---

이 포스팅은 Redis 의 확장 모듈 중 하나인 `RedisJSON` 에 대해 알아본다.  

> - Redis 확장 모듈
> - RedisJSON 설치
> - RedisJSON 사용
>   - `JSON.SET`, `JSON.GET`
>   - `JSON.STRLEN`, `JSON.STRAPPEND`
>   - `JSON.NUMINCRBY`, `JSON.NUMMULTBY`
>   - `JSON.NUMINCRBY`, `JSON.NUMMULTBY`
>   - `JSON.DEL`
>   - `JSON.FORGET`
>   - `JSON.ARRAPPEND`, `JSON.ARRINSERT`, `JSON.ARRTRIM`, `JSON.ARRPOP`
>   - `JSON.OBJLEN`, `JSON.OBJKEYS`
>   - `INDENT`, `NEWLINE`, `SPACE`
> - `make` 오류 시
>   - `make` 버전 업데이트 처리
>   - `rust` 설치
> - `JSONPath`

---

# 1. Redis 확장 모듈

- `RedisJSON`: Redis 에서 JSON 데이터 타입을 처리할 수 있도록 해주는 확장 모듈 
- `RediSQL`: Redis 서버에서 SQLite 로 데이터를 처리할 수 있는 모듈
- `RediSearch`: Redis DB 내에 저장된 데이터에 대한 검색 엔진을 사용할 수 있도록 해주는 모듈
- `Redis-sPiped`: Redis 서버로 전송되는 데이터를 암호화할 수 있는 모듈

> 더 많은 확장 모듈은 [https://redis.io/modules](https://redis.io/docs/modules/) 를 참고하세요.

---

# 2. RedisJSON 설치

```shell
$ pwd
/usr/local/opt/redis

$ git clone https://github.com/RedisJSON/RedisJSON.git

$ cd RedisJSON
$ make
```

위 내용 수행 후 아래 경로에 *rejson.so* 파일 생성 여부를 확인한다.

```shell
$ pwd
/usr/local/opt/redis/RedisJSON/bin/macos-x64-release

$ ll
rejson.so
```

*redis.conf* 파일에 아래 내용을 추가한다.

```shell
$ pwd
/usr/local/etc

$ vi redis.conf

...
loadmodule /usr/local/opt/redis/RedisJSON/bin/macos-x64-release/rejson.so
```

`redis-server` 를 실행한다. 위치는 아무 곳이나 상관없다.

혹은 `brew services start redis` 로 redis 를 실행한다.

```shell
$ redis-server /usr/local/etc/redis.conf

46246:C 27 Aug 2022 13:30:34.844 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
46246:C 27 Aug 2022 13:30:34.844 # Redis version=7.0.4, bits=64, commit=00000000, modified=0, pid=46246, just started
46246:C 27 Aug 2022 13:30:34.844 # Configuration loaded
46246:M 27 Aug 2022 13:30:34.845 * Increased maximum number of open files to 10032 (it was originally set to 256).
46246:M 27 Aug 2022 13:30:34.845 * monotonic clock: POSIX clock_gettime
                _._
           _.-``__ ''-._
      _.-``    `.  `_.  ''-._           Redis 7.0.4 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._
 (    '      ,       .-`  | `,    )     Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
 |    `-._   `._    /     _.-'    |     PID: 46246
  `-._    `-._  `-./  _.-'    _.-'
 |`-._`-._    `-.__.-'    _.-'_.-'|
 |    `-._`-._        _.-'_.-'    |           https://redis.io
  `-._    `-._`-.__.-'_.-'    _.-'
 |`-._`-._    `-.__.-'    _.-'_.-'|
 |    `-._`-._        _.-'_.-'    |
  `-._    `-._`-.__.-'_.-'    _.-'
      `-._    `-.__.-'    _.-'
          `-._        _.-'
              `-.__.-'

46246:M 27 Aug 2022 13:30:34.846 # WARNING: The TCP backlog setting of 511 cannot be enforced because kern.ipc.somaxconn is set to the lower value of 128.
46246:M 27 Aug 2022 13:30:34.846 # Server initialized
46246:M 27 Aug 2022 13:30:34.847 * <ReJSON> version: 999999 git sha: ae0fa8a branch: master
46246:M 27 Aug 2022 13:30:34.847 * <ReJSON> Exported RedisJSON_V1 API
46246:M 27 Aug 2022 13:30:34.847 * <ReJSON> Exported RedisJSON_V2 API
46246:M 27 Aug 2022 13:30:34.847 * <ReJSON> Enabled diskless replication
46246:M 27 Aug 2022 13:30:34.847 * <ReJSON> Created new data type 'ReJSON-RL'
46246:M 27 Aug 2022 13:30:34.847 * Module 'ReJSON' loaded from /usr/local/opt/redis/RedisJSON/bin/macos-x64-release/rejson.so
46246:M 27 Aug 2022 13:30:34.847 * Loading RDB produced by version 7.0.4
46246:M 27 Aug 2022 13:30:34.847 * RDB age 49 seconds
46246:M 27 Aug 2022 13:30:34.847 * RDB memory usage when created 1.14 Mb
46246:M 27 Aug 2022 13:30:34.847 * Done loading RDB, keys loaded: 3, keys expired: 0.
46246:M 27 Aug 2022 13:30:34.847 * DB loaded from disk: 0.000 seconds
46246:M 27 Aug 2022 13:30:34.847 * Ready to accept connections
```

아래는 redis.conf 파일 참조없이 redis-server 실행 시 콘솔이다.

```shell
$ redis-server

46320:C 27 Aug 2022 13:30:59.966 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
46320:C 27 Aug 2022 13:30:59.966 # Redis version=7.0.4, bits=64, commit=00000000, modified=0, pid=46320, just started
46320:C 27 Aug 2022 13:30:59.966 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
46320:M 27 Aug 2022 13:30:59.967 * Increased maximum number of open files to 10032 (it was originally set to 256).
46320:M 27 Aug 2022 13:30:59.967 * monotonic clock: POSIX clock_gettime
                _._
           _.-``__ ''-._
      _.-``    `.  `_.  ''-._           Redis 7.0.4 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._
 (    '      ,       .-`  | `,    )     Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
 |    `-._   `._    /     _.-'    |     PID: 46320
  `-._    `-._  `-./  _.-'    _.-'
 |`-._`-._    `-.__.-'    _.-'_.-'|
 |    `-._`-._        _.-'_.-'    |           https://redis.io
  `-._    `-._`-.__.-'_.-'    _.-'
 |`-._`-._    `-.__.-'    _.-'_.-'|
 |    `-._`-._        _.-'_.-'    |
  `-._    `-._`-.__.-'_.-'    _.-'
      `-._    `-.__.-'    _.-'
          `-._        _.-'
              `-.__.-'

46320:M 27 Aug 2022 13:30:59.967 # WARNING: The TCP backlog setting of 511 cannot be enforced because kern.ipc.somaxconn is set to the lower value of 128.
46320:M 27 Aug 2022 13:30:59.967 # Server initialized
46320:M 27 Aug 2022 13:30:59.968 * Loading RDB produced by version 7.0.4
46320:M 27 Aug 2022 13:30:59.968 * RDB age 64 seconds
46320:M 27 Aug 2022 13:30:59.968 * RDB memory usage when created 1.03 Mb
46320:M 27 Aug 2022 13:30:59.968 * Done loading RDB, keys loaded: 0, keys expired: 0.
46320:M 27 Aug 2022 13:30:59.968 * DB loaded from disk: 0.000 seconds
46320:M 27 Aug 2022 13:30:59.968 * Ready to accept connections
```

`redis-cli` 를 실행한다. 위치는 아무 곳이나 상관없다.

```shell
$ redis-cli
127.0.0.1:6379>
```

---

# 3. RedisJSON 사용

> 더 많은 JSON commands 는 [JSON commands](https://redis.io/commands/?group=json) 를 참고하세요.

`$` 는 JSON document 경로값으로 root 를 의미한다.

> `JSONPath` 는 *9. JSONPath* 를 참고하세요.

---

## 3.1. `JSON.SET`, `JSON.GET`

- `JSON.SET` : JSON 값으로 redis key 설정
- `JSON.GET` : redis key 조회

```shell
127.0.0.1:6379> JSON.SET aninal $ '"dog"'
OK
127.0.0.1:6379> JSON.GET animal $
"[\"cat\"]"
127.0.0.1:6379> JSON.GET animal
"\"cat\""

127.0.0.1:6379> JSON.TYPE animal $
1) "string"
127.0.0.1:6379> JSON.TYPE animal
"string"
```

---

## 3.2. `JSON.STRLEN`, `JSON.STRAPPEND`  

- `JSON.STRLEN` : 문자열의 길이 조회
- `JSON.STRAPPEND` : 문자열 추가

```shell
127.0.0.1:6379> JSON.STRLEN animal
(integer) 3
127.0.0.1:6379> JSON.STRAPPEND animal $ '" (test)"'
1) (integer) 10
127.0.0.1:6379> JSON.GET animal $
"[\"cat (test)\"]"
127.0.0.1:6379> JSON.GET animal
"\"cat (test)\""
```

---

## 3.3. `JSON.NUMINCRBY`, `JSON.NUMMULTBY`  

- `JSON.NUMINCRBY`
- `JSON.NUMMULTBY`

```shell
127.0.0.1:6379> JSON.SET calc $ 0
OK
127.0.0.1:6379> JSON.NUMINCRBY calc $ 1
"[1]"
127.0.0.1:6379> JSON.NUMINCRBY calc $ 1.5
"[2.5]"
127.0.0.1:6379> JSON.NUMINCRBY calc $ -1.5
"[1.0]"
127.0.0.1:6379> JSON.NUMMULTBY calc $ 5
"[5.0]"
```

---

## 3.4. `JSON.DEL`

아래는 JSON 배열과 object 예시이다.

- `JSON.DEL` : 경로로 지정한 모든 json 의 값 삭제

```shell
127.0.0.1:6379> JSON.SET test $ '[true, { "answer": 20 }, null ]'
OK

127.0.0.1:6379> JSON.GET test $
"[[true,{\"answer\":20},null]]"
127.0.0.1:6379> JSON.GET test
"[true,{\"answer\":20},null]"

127.0.0.1:6379> JSON.GET test $[1]
"[{\"answer\":20}]"
127.0.0.1:6379> JSON.GET test $[1].answer
"[20]"

127.0.0.1:6379> JSON.GET test $
"[[true,{\"answer\":20},null]]"
127.0.0.1:6379> JSON.DEL test $[-1]
(integer) 1
127.0.0.1:6379> JSON.GET test $
"[[true,{\"answer\":20}]]"
```

---

## 3.5. `JSON.FORGET`

- `JSON.FORGET` : key 삭제

```shell
127.0.0.1:6379> JSON.forget test
(integer) 1  # 삭제 완료

127.0.0.1:6379> JSON.forget test
(integer) 0  # 삭제할 것이 없음
```

---

## 3.6. `JSON.ARRAPPEND`, `JSON.ARRINSERT`, `JSON.ARRTRIM`, `JSON.ARRPOP`

```shell
127.0.0.1:6379> JSON.SET arr $ []
OK
127.0.0.1:6379> JSON.ARRAPPEND arr $ 0
1) (integer) 1
127.0.0.1:6379> JSON.GET arr $
"[[0]]"
127.0.0.1:6379> JSON.GET arr
"[0]"

127.0.0.1:6379> JSON.ARRINSERT arr $ 0 -2 -1
1) (integer) 3
127.0.0.1:6379> JSON.GET arr $
"[[-2,-1,0]]"
127.0.0.1:6379> JSON.GET arr
"[-2,-1,0]"

127.0.0.1:6379> JSON.ARRTRIM arr $ 1 1
1) (integer) 1
127.0.0.1:6379> JSON.GET arr $
"[[-1]]"

127.0.0.1:6379> JSON.ARRPOP arr $
1) "-1"
127.0.0.1:6379> JSON.ARRPOP arr $
1) (nil)
```

---

## 3.7. `JSON.OBJLEN`, `JSON.OBJKEYS`

```shell
127.0.0.1:6379> JSON.SET obj $ '{"name":"Leonard Cohen","lastSeen":1478476800,"loggedOut": true}'
OK
127.0.0.1:6379> JSON.GET obj $
"[{\"name\":\"Leonard Cohen\",\"lastSeen\":1478476800,\"loggedOut\":true}]"
127.0.0.1:6379> JSON.GET obj
"{\"name\":\"Leonard Cohen\",\"lastSeen\":1478476800,\"loggedOut\":true}"

127.0.0.1:6379> JSON.OBJLEN obj $
1) (integer) 3
127.0.0.1:6379> JSON.OBJLEN obj
(integer) 3

127.0.0.1:6379> JSON.OBJKEYS obj $
1) 1) "name"
   2) "lastSeen"
   3) "loggedOut"
127.0.0.1:6379> JSON.OBJKEYS obj
1) "name"
2) "lastSeen"
3) "loggedOut"
```

---

## 3.8. `INDENT`, `NEWLINE`, `SPACE`

JSON.GET 과 함께 써서 redis 결과물을 알아보기 쉽도록 해준다.

```shell
$ redis-cli --raw

127.0.0.1:6379> JSON.GET obj $
[{"name":"Leonard Cohen","lastSeen":1478476800,"loggedOut":true}]

127.0.0.1:6379> JSON.GET obj
{"name":"Leonard Cohen","lastSeen":1478476800,"loggedOut":true}

127.0.0.1:6379> JSON.GET obj INDENT "\t" NEWLINE "\n" SPACE " " $
[
        {
                "name": "Leonard Cohen",
                "lastSeen": 1478476800,
                "loggedOut": true
        }
]

127.0.0.1:6379> JSON.GET obj INDENT "\t" NEWLINE "\n" SPACE " "
{
        "name": "Leonard Cohen",
        "lastSeen": 1478476800,
        "loggedOut": true
}
```

---

# `make` 오류 시

## `make` 버전 업데이트 처리

```shell
$ make
deps/readies/mk/main:6: *** GNU Make version is too old. Aborting..  Stop.

$ make -v
GNU Make 3.81

$ brew install homebrew/core/make
Warning: make 4.3 is already installed, it's just not linked. --> 이미 4.3 버전이 설치되어 있다고 나옴
To link this version, run:
  brew link make
```

`.zshrc` 파일에 아래 내용 추가
```shell
$ vi ~/.zshrc

...
export PATH="/usr/local/opt/make/libexec/gnubin:$PATH"

$ source ~/.zshrc
```

```shell
$ make -v
GNU Make 4.3
```

---

## `rust` 설치

```shell
$ make
/bin/bash: rustc: command not found
/bin/bash: line 2: cargo: command not found
make: *** [Makefile:175: build] Error 127

$ make test
/bin/bash: rustc: command not found
/bin/bash: cargo: command not found
make: *** [Makefile:220: cargo_test] Error 127
```

```shell
$ brew install rust
```

---

# `JSONPath`

JSONPath 에 좀 더 자세한 사항은 [JsonPath 1](https://goessner.net/articles/JsonPath/) 와 [JsonPath 2](https://redis.io/docs/stack/json/path/#jsonpath-syntax) 를 참고하세요.

![JSONPath](/assets/img/dev/2022/0827/jsonpath.png)

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [https://redis.io/modules](https://redis.io/docs/modules/)
* [RedisJSON docs](https://redis.io/docs/stack/json/)
* [RedisJSON git](https://github.com/RedisJSON/RedisJSON)
* [JsonPath 1](https://goessner.net/articles/JsonPath/)
* [JsonPath 2](https://redis.io/docs/stack/json/path/#jsonpath-syntax)
* [JSON commands](https://redis.io/commands/?group=json)