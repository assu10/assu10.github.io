---
layout: post
title: "Redis 기본, 데이터 처리 명령어, String"
date: 2022-06-01 10:00
categories: dev
tags: db redis
---

이 포스트는 NoSQL 의 종류와 그 중 Key-Value DB 인 Redis, 그리고 데이터 타입 중 하나인 `String` 에 대해 알아본다. 
(redis version 은 7.0.0)

<!-- TOC -->
* [1. Redis 설치 및 시작 종료](#1-redis-설치-및-시작-종료)
 * [1.1. 설치](#11-설치)
 * [1.2. redis start & stop](#12-redis-start--stop)
 * [1.3. redis-server, redis-client](#13-redis-server-redis-client)
 * [1.4. 테스트 데이터 입력 및 조회](#14-테스트-데이터-입력-및-조회)
* [2. 데이터 처리 명령어](#2-데이터-처리-명령어)
 * [2.1. `RENAME`](#21-rename)
 * [2.2. `RANDOMKEY`](#22-randomkey)
 * [2.3. `KEYS`](#23-keys)
 * [2.4. `EXISTS`](#24-exists)
 * [2.5. `DEL`, `FLUSHALL`](#25-del-flushall)
 * [2.6. `SAVE`](#26-save)
 * [2.7. `CLEAR`](#27-clear)
 * [2.8. `time`](#28-time)
 * [2.9. `INFO`](#29-info)
* [3. `String`](#3-string)
 * [3.1. `SET`, `GET`](#31-set-get)
  * [3.1.1 `SET` - [`NX | XX`]](#311-set---nx--xx)
  * [3.1.2 `SET` - [`EX seconds | PX milliseconds | EXAT unix-time-seconds | PXAT unix-time-milliseconds | KEEPTTL`]](#312-set---ex-seconds--px-milliseconds--exat-unix-time-seconds--pxat-unix-time-milliseconds--keepttl)
 * [3.2. `MSET`, `MGET`](#32-mset-mget)
 * [3.3. `STRLEN`](#33-strlen)
 * [3.4. `SETEX`](#34-setex)
 * [3.5. `TTL`](#35-ttl)
 * [3.6. `INCR`, `DECR`](#36-incr-decr)
 * [3.7. `INCRBY`, `DECRBY`, `INCRBYFLOAT`](#37-incrby-decrby-incrbyfloat)
 * [3.8. `APPEND`](#38-append)
 * [3.9. `GETRANGE`, `SETRANGE`](#39-getrange-setrange)
 * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. Redis 설치 및 시작 종료

## 1.1. 설치

```shell
$ brew install redis
```

```shell

...

We've installed your MySQL database without a root password. To secure it run:
  mysql_secure_installation

MySQL is configured to only allow connections from localhost by default

To connect run:
  mysql -uroot

To restart mysql after an upgrade:
 brew services restart mysql
Or, if you don't want/need a background service you can just run:
 /usr/local/opt/mysql/bin/mysqld_safe --datadir=/usr/local/var/mysql
==> Summary
🍺 /usr/local/Cellar/mysql/8.0.29: 311 files, 294.7MB
==> Running `brew cleanup mysql`...
Removing: /usr/local/Cellar/mysql/8.0.27... (304 files, 293.8MB)
==> Checking for dependents of upgraded formulae...
==> No broken dependents found!
==> Caveats
==> redis
To restart redis after an upgrade:
 brew services restart redis
Or, if you don't want/need a background service you can just run:
 /usr/local/opt/redis/bin/redis-server /usr/local/etc/redis.conf
==> mysql
We've installed your MySQL database without a root password. To secure it run:
  mysql_secure_installation

MySQL is configured to only allow connections from localhost by default

To connect run:
  mysql -uroot

To restart mysql after an upgrade:
 brew services restart mysql
Or, if you don't want/need a background service you can just run:
 /usr/local/opt/mysql/bin/mysqld_safe --datadir=/usr/local/var/mysql
```

> redis 실행파일 
> /usr/local/opt/redis/bin/redis-server
> redis.conf 위치 
> /usr/local/etc/redis.conf (default port: 6379)

---

## 1.2. redis start & stop

redis start & stop
```shell
$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ brew services stop redis
Stopping `redis`... (might take a while)
==> Successfully stopped `redis` (label: homebrew.mxcl.redis)

$ brew services restart redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)
```

---

## 1.3. redis-server, redis-client

redis 서버 실행
```shell
$ pwd
/usr/local/opt/redis/bin
$ redis-server
60068:C 01 Jun 2022 14:41:46.934 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
60068:C 01 Jun 2022 14:41:46.934 # Redis version=7.0.0, bits=64, commit=00000000, modified=0, pid=60068, just started
60068:C 01 Jun 2022 14:41:46.934 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
60068:M 01 Jun 2022 14:41:46.935 * INCReased maximum number of open files to 10032 (it was originally SET to 256).
60068:M 01 Jun 2022 14:41:46.935 * monotonic clock: POSIX clock_GETtime
        _._
      _.-``__ ''-._
   _.-``  `. `_. ''-._      Redis 7.0.0 (00000000/0) 64 bit
 .-`` .-```. ```\/  _.,_ ''-._
 (  '   ,    .-` | `,  )   Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|   Port: 6379
 |  `-._  `._  /   _.-'  |   PID: 60068
 `-._  `-._ `-./ _.-'  _.-'
 |`-._`-._  `-.__.-'  _.-'_.-'|
 |  `-._`-._    _.-'_.-'  |      https://redis.io
 `-._  `-._`-.__.-'_.-'  _.-'
 |`-._`-._  `-.__.-'  _.-'_.-'|
 |  `-._`-._    _.-'_.-'  |
 `-._  `-._`-.__.-'_.-'  _.-'
   `-._  `-.__.-'  _.-'
     `-._    _.-'
       `-.__.-'

60068:M 01 Jun 2022 14:41:46.936 # WARNING: The TCP backlog SETting of 511 cannot be enforced because kern.ipc.somaxconn is SET to the lower value of 128.
60068:M 01 Jun 2022 14:41:46.936 # Server initialized
60068:M 01 Jun 2022 14:41:46.936 * The AOF directory APPENDonlydir doesn't exist
60068:M 01 Jun 2022 14:41:46.936 * Loading RDB produced by version 7.0.0
60068:M 01 Jun 2022 14:41:46.936 * RDB age 5 seconds
60068:M 01 Jun 2022 14:41:46.936 * RDB memory usage when created 1.03 Mb
60068:M 01 Jun 2022 14:41:46.936 * Done loading RDB, KEYS loaded: 0, KEYS expired: 0.
60068:M 01 Jun 2022 14:41:46.936 * DB loaded from disk: 0.000 seconds
60068:M 01 Jun 2022 14:41:46.936 * Ready to accept connections
```

redis client 접속 및 redis-server 종료
```shell
$ redis-cli
127.0.0.1:6379>

$ shutdown # redis server 종료
not connected> exit
```

help 사용 
help 와 함께 실행할 명령어 실행 시 설명 조회
```shell
$ help SET

 SET key value [NX|XX] [GET] [EX seconds|PX milliseconds|EXAT unix-time-seconds|PXAT unix-time-milliseconds|KEEPTTL]
 summary: SET the string value of a key
 since: 1.0.0
 group: string
```

redis-server 기본 문법
```shell
$ redis-server -h
Usage: ./redis-server [/path/to/redis.conf] [options] [-]
    ./redis-server - (read config from stdin)
    ./redis-server -v or --version
    ./redis-server -h or --help
    ./redis-server --test-memory <megabytes>

Examples:
    ./redis-server (run the server with default conf)
    ./redis-server /etc/redis/6379.conf
    ./redis-server --port 7777
    ./redis-server --port 7777 --replicaof 127.0.0.1 8888
    ./redis-server /etc/myredis.conf --loglevel verbose -
    ./redis-server /etc/myredis.conf --loglevel verbose

Sentinel mode:
    ./redis-server /etc/sentinel.conf --sentinel
```

redis-cli 기본 문법
```shell
redis-cli -h
redis-cli 7.0.0

Usage: redis-cli [OPTIONS] [cmd [arg [arg ...]]]
 -h <hostname>   Server hostname (default: 127.0.0.1).
 -p <port>     Server port (default: 6379).
 -s <socket>    Server socket (overrides hostname and port).
 -a <password>   Password to use when connecting to the server.
           You can also use the REDISCLI_AUTH environment
           variable to pass this password more safely
           (if both are used, this argument takes precedence).
 --user <username> Used to send ACL style 'AUTH username pass'. Needs -a.
 --pass <password> Alias of -a for consistency with the new --user option.
 --askpass     Force user to input password with mask from STDIN.
           If this argument is used, '-a' and REDISCLI_AUTH
           environment variable will be ignored.
 -u <uri>      Server URI.
 -r <repeat>    Execute specified command N times.
 -i <interval>   When -r is used, waits <interval> seconds per command.
           It is possible to specify sub-second times like -i 0.1.
           This interval is also used in --scan and --stat per cycle.
           and in --bigKEYS, --memKEYS, and --hotKEYS per 100 cycles.
 -n <db>      Database number.
 -2         Start session in RESP2 protocol mode.
 -3         Start session in RESP3 protocol mode.
 -x         Read last argument from STDIN (see example below).
 -X         Read <tag> argument from STDIN (see example below).
 -d <DELimiter>   DELimiter between response bulks for raw formatting (default: \n).
 -D <DELimiter>   DELimiter between responses for raw formatting (default: \n).
 -c         Enable cluster mode (follow -ASK and -MOVED redirections).
 -e         Return exit error code when command execution fails.
 --tls       Establish a secure TLS connection.
 --sni <host>    Server name indication for TLS.
 --cacert <file>  CA Certificate file to verify with.
 --cacertdir <dir> Directory where trusted CA certificates are stored.
           If neither cacert nor cacertdir are specified, the default
           system-wide trusted root certs configuration will apply.
 --insecure     Allow insecure TLS connection by skipping cert validation.
 --cert <file>   Client certificate to authenticate with.
 --key <file>    Private key file to authenticate with.
 --tls-ciphers <list> SETs the list of preferred ciphers (TLSv1.2 and below)
           in order of preference from highest to lowest separated by colon (":").
           See the ciphers(1ssl) manpage for more information about the syntax of this string.
 --tls-ciphersuites <list> SETs the list of preferred ciphersuites (TLSv1.3)
           in order of preference from highest to lowest separated by colon (":").
           See the ciphers(1ssl) manpage for more information about the syntax of this string,
           and specifically for TLSv1.3 ciphersuites.
 --raw       Use raw formatting for replies (default when STDOUT is
           not a tty).
 --no-raw      Force formatted output even when STDOUT is not a tty.
 --quoted-input   Force input to be handled as quoted strings.
 --csv       Output in CSV format.
 --json       Output in JSON format (default RESP3, use -2 if you want to use with RESP2).
 --quoted-json   Same as --json, but produce ASCII-safe quoted strings, not Unicode.
 --show-pushes <yn> Whether to print RESP3 PUSH messages. Enabled by default when
           STDOUT is a tty but can be overridden with --show-pushes no.
 --stat       Print rolling stats about server: mem, clients, ...
 --latency     Enter a special mode continuously sampling latency.
           If you use this mode in an interactive session it runs
           forever displaying real-time stats. Otherwise if --raw or
           --csv is specified, or if you redirect the output to a non
           TTY, it samples the latency for 1 second (you can use
           -i to change the interval), then produces a single output
           and exits.
 --latency-history Like --latency but tracking latency changes over time.
           Default time interval is 15 sec. Change it using -i.
 --latency-dist   Shows latency as a spectrum, requires xterm 256 colors.
           Default time interval is 1 sec. Change it using -i.
 --lru-test <KEYS> Simulate a cache workload with an 80-20 distribution.
 --replica     Simulate a replica showing commands received from the master.
 --rdb <filename>  Transfer an RDB dump from remote server to local file.
           Use filename of "-" to write to stdout.
 --functions-rdb <filename> Like --rdb but only GET the functions (not the KEYS)
           when GETting the RDB dump file.
 --pipe       Transfer raw Redis protocol from stdin to server.
 --pipe-timeout <n> In --pipe mode, abort with error if after sending all data.
           no reply is received within <n> seconds.
           Default timeout: 30. Use 0 to wait forever.
 --bigKEYS     Sample Redis KEYS looking for KEYS with many elements (complexity).
 --memKEYS     Sample Redis KEYS looking for KEYS consuming a lot of memory.
 --memKEYS-samples <n> Sample Redis KEYS looking for KEYS consuming a lot of memory.
           And define number of key elements to sample
 --hotKEYS     Sample Redis KEYS looking for hot KEYS.
           only works when maxmemory-policy is *lfu.
 --scan       List all KEYS using the SCAN command.
 --pattern <pat>  KEYS pattern when using the --scan, --bigKEYS or --hotKEYS
           options (default: *).
 --quoted-pattern <pat> Same as --pattern, but the specified string can be
             quoted, in order to pass an otherwise non binary-safe string.
 --intrinsic-latency <sec> Run a test to measure intrinsic system latency.
           The test will run for the specified amount of seconds.
 --eval <file>   Send an EVAL command using the Lua script at <file>.
 --ldb       Used with --eval enable the Redis Lua debugger.
 --ldb-sync-mode  Like --ldb but uses the synchronous Lua debugger, in
           this mode the server is blocked and script changes are
           not rolled back from the server memory.
 --cluster <command> [args...] [opts...]
           Cluster Manager command and arguments (see below).
 --verbose     Verbose mode.
 --no-auth-warning Don't show warning message when using password on command
           line interface.
 --help       Output this help and exit.
 --version     Output version and exit.

Cluster Manager Commands:
 Use --cluster help to list all available cluster manager commands.

Examples:
 cat /etc/passwd | redis-cli -x SET mypasswd
 redis-cli -D "" --raw dump key > key.dump && redis-cli -X dump_tag restore key2 0 dump_tag replace < key.dump
 redis-cli -r 100 lpush mylist x
 redis-cli -r 100 -i 1 info | grep used_memory_human:
 redis-cli --quoted-input SET '"null-\x00-separated"' value
 redis-cli --eval myscript.lua key1 key2 , arg1 arg2 arg3
 redis-cli --scan --pattern '*:12345*'

 (Note: when using --eval the comma separates KEYS[] from ARGV[] items)

When no command is given, redis-cli starts in interactive mode.
Type "help" in interactive mode for information on available commands
and SETtings.
```

redis-server 상태 확인
```shell
$ redis-cli
127.0.0.1:6379> INFO
# Server
redis_version:7.0.0
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:fa9ffba7836907da
redis_mode:standalone

... 

```

---

## 1.4. 테스트 데이터 입력 및 조회

```shell
127.0.0.1:6379> SET foo bar
OK
127.0.0.1:6379> GET foo
"bar"
```

---

# 2. 데이터 처리 명령어

K-V DB 에서의 용어는 아래와 같다.

- `Table`
- `Data Sets`: Row
- `Key`: PK
- `Field/Element`: Column

```shell
$ pwd
/usr/local/opt/redis/bin

$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ redis-cli
127.0.0.1:6379>
```

---

## 2.1. `RENAME`

저장된 key 명을 변경한다.

```shell
127.0.0.1:6379> help RENAME

 RENAME key newkey
 summary: RENAME a key
 since: 1.0.0
 group: generic
```

```shell
127.0.0.1:6379> SET username assu
OK
127.0.0.1:6379> GET username
"assu"
127.0.0.1:6379> RENAME username username1
OK
127.0.0.1:6379> GET username
(nil)
127.0.0.1:6379> GET username1
"assu"
```

---

## 2.2. `RANDOMKEY`

저장된 key 중 랜덤하게 하나의 key 를 검색한다.

```shell
127.0.0.1:6379> help RANDOMKEY

 RANDOMKEY
 summary: Return a random key from the KEYSpace
 since: 1.0.0
 group: generic
```

```shell
127.0.0.1:6379> SET username assu
OK
127.0.0.1:6379> SET username1 assu1
OK
127.0.0.1:6379> SET username2 assu2
OK
127.0.0.1:6379> RANDOMKEY
"username"
127.0.0.1:6379> RANDOMKEY
"username"
127.0.0.1:6379> RANDOMKEY
```

---

## 2.3. `KEYS`

저장된 모든 key 를 검색한다.

```shell
127.0.0.1:6379> help KEYS

 KEYS pattern
 summary: Find all KEYS matching the given pattern
 since: 1.0.0
 group: generic
```

```shell
127.0.0.1:6379> KEYS *
1) "username2"
2) "username1"
3) "user9name3"
4) "username"

127.0.0.1:6379> KEYS username*
1) "username2"
2) "username1"
3) "username"
```

---

## 2.4. `EXISTS`

검색 대상 key 존재 여부를 확인하여 존재하는 key 값이면 1을 반환하고, 존재하지 않는 key 값이면 0 을 반환한다.

```shell
127.0.0.1:6379> help EXISTS

 EXISTS key [key ...]
 summary: Determine if a key EXISTS
 since: 1.0.0
 group: generic
```

```shell
127.0.0.1:6379> EXISTS username
(integer) 1
127.0.0.1:6379> EXISTS username username7
(integer) 1
127.0.0.1:6379> EXISTS username7 username
(integer) 1
127.0.0.1:6379> EXISTS username7 username8
(integer) 0
```

---

## 2.5. `DEL`, `FLUSHALL`

`DEL` 은 특정 key 를 삭제한다.

```shell
127.0.0.1:6379> help DEL

 DEL key [key ...]
 summary: DELete a key
 since: 1.0.0
 group: generic
```

```shell
127.0.0.1:6379> KEYS *
1) "username2"
2) "username1"
3) "user9name3"
4) "username"
127.0.0.1:6379> DEL user9name3
(integer) 1
127.0.0.1:6379> DEL user9name3
(integer) 0
```

`FLUSHALL` 은 현재 저장되어 있는 모든 key 삭제한다.

```shell
127.0.0.1:6379> help FLUSHALL

 FLUSHALL [ASYNC|SYNC]
 summary: Remove all KEYS from all databases
 since: 1.0.0
 group: server
```

```shell
127.0.0.1:6379> FLUSHALL
OK
127.0.0.1:6379> FLUSHALL
OK
127.0.0.1:6379> KEYS *
(empty array)
```

---

## 2.6. `SAVE`

현재 입력되어 있는 key, value 값을 파일로 저장한다. 
`SAVE` 명령으로 저장된 데이터는 redis 폴더의 *dump.rdb* 파일로 생성된다.

redis 폴더는 아래와 같은 방식으로 알 수 있다. 
*homebrew.redis.service* 파일에 보면 *WorkingDirectory=/usr/local/var* 를 볼 수 있다.

```shell
$ pwd
/usr/local/opt/redis

$ ll
total 80
-rw-r--r-- 1 assu admin  1.5K 4 27 22:32 COPYING
-rw-r--r-- 1 assu admin  1.2K 5 30 19:50 INSTALL_RECEIPT.json
-rw-r--r-- 1 assu admin  22K 4 27 22:32 README.md
drwxr-xr-x 8 assu admin  256B 7 21 15:05 bin
-rw-r--r-- 1 assu admin  670B 5 30 19:50 homebrew.mxcl.redis.plist
-rw-r--r-- 1 assu admin  335B 5 30 19:50 homebrew.redis.service

$ cat homebrew.redis.service
───────┬────────────────────────────────────────────────────────────────────────────────────────────
    │ File: homebrew.redis.service
───────┼────────────────────────────────────────────────────────────────────────────────────────────
  1  │ [Unit]
  2  │ Description=Homebrew generated unit for redis
  3  │
  4  │ [Install]
  5  │ WantedBy=multi-user.tarGET
  6  │
  7  │ [Service]
  8  │ Type=simple
  9  │ ExecStart=/usr/local/opt/redis/bin/redis-server /usr/local/etc/redis.conf
 10  │ Restart=always
 11  │ WorkingDirectory=/usr/local/var
 12  │ StandardOutput=APPEND:/usr/local/var/log/redis.log
 13  │ StandardError=APPEND:/usr/local/var/log/redis.log
 
$ pwd
/usr/local/var/db/redis

$ ll
total 8
-rw-r--r-- 1 assu admin  108B 7 21 15:10 dump.rdb
```

```shell
127.0.0.1:6379> help SAVE

 SAVE
 summary: Synchronously SAVE the dataSET to disk
 since: 1.0.0
 group: server
```

---

## 2.7. `CLEAR`

화면 CLEAR 하는 명령어이다.

```shell
127.0.0.1:6379> CLEAR
```

---

## 2.8. `time`

현재 서버의 시간을 unix time in seconds 와 현재 초에서 이미 경과된 microseconds, 2 가지 항목으로 조회한다.

```shell
127.0.0.1:6379> help TIME

 TIME
 summary: Return the current server TIME
 since: 2.6.0
 group: server
```

```shell
127.0.0.1:6379> TIME
1) "1658385383" # 서버 시간 (unix time in seconds)
2) "808254"  # 현재 초에서 이미 경과된 microseconds
```

---

## 2.9. `INFO`

redis 서버 설정 상태를 조회한다.

```shell
127.0.0.1:6379> help INFO

 INFO [section [section ...]]
 summary: GET information and statistics about the server
 since: 1.0.0
 group: server
```

```shell
127.0.0.1:6379> INFO
# Server
redis_version:7.0.0
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:fa9ffba7836907da
redis_mode:standalone
os:Darwin 21.5.0 x86_64
arch_bits:64
monotonic_clock:POSIX clock_GETtime
multiplexing_api:kqueue
atomicvar_api:c11-builtin
gcc_version:4.2.1
process_id:39942
process_supervised:no
run_id:7c1a92e98f69a6c344ce0f505d3a02db76395250
tcp_port:6379
server_time_usec:1658385510640954
uptime_in_seconds:168673
uptime_in_days:1
hz:10
configured_hz:10
lru_clock:14218342
executable:/usr/local/opt/redis/bin/redis-server
config_file:/usr/local/etc/redis.conf
io_threads_active:0

# Clients
connected_clients:1
cluster_connections:0
maxclients:10000
client_recent_max_input_buffer:16
client_recent_max_output_buffer:0
blocked_clients:0
tracking_clients:0
clients_in_timeout_table:0

# Memory
used_memory:1821664
used_memory_human:1.74M
used_memory_rss:1028096
used_memory_rss_human:1004.00K
used_memory_peak:1821664
used_memory_peak_human:1.74M
used_memory_peak_perc:100.11%
used_memory_overhead:1134704
used_memory_startup:1132640
used_memory_dataSET:686960
used_memory_dataSET_perc:99.70%
allocator_allocated:1802688
allocator_active:996352
allocator_resident:996352
total_system_memory:17179869184
total_system_memory_human:16.00G
used_memory_lua:31744
used_memory_vm_eval:31744
used_memory_lua_human:31.00K
used_memory_scripts_eval:0
number_of_cached_scripts:0
number_of_functions:0
number_of_libraries:0
used_memory_vm_functions:32768
used_memory_vm_total:64512
used_memory_vm_total_human:63.00K
used_memory_functions:216
used_memory_scripts:216
used_memory_scripts_human:216B
maxmemory:0
maxmemory_human:0B
maxmemory_policy:noeviction
allocator_frag_ratio:0.55
allocator_frag_bytes:18446744073708745280
allocator_rss_ratio:1.00
allocator_rss_bytes:0
rss_overhead_ratio:1.03
rss_overhead_bytes:31744
mem_fragmentation_ratio:0.57
mem_fragmentation_bytes:-774592
mem_not_counted_for_evict:0
mem_replication_backlog:0
mem_total_replication_buffers:0
mem_clients_slaves:0
mem_clients_normal:1776
mem_cluster_links:0
mem_aof_buffer:0
mem_allocator:libc
active_defrag_running:0
lazyfree_pending_objects:0
lazyfreed_objects:0

# Persistence
loading:0
async_loading:0
current_cow_peak:0
current_cow_size:0
current_cow_size_age:0
current_fork_perc:0.00
current_SAVE_KEYS_processed:0
current_SAVE_KEYS_total:0
rdb_changes_since_last_SAVE:0
rdb_bgSAVE_in_progress:0
rdb_last_SAVE_time:1658383851
rdb_last_bgSAVE_status:ok
rdb_last_bgSAVE_time_sec:0
rdb_current_bgSAVE_time_sec:-1
rdb_SAVEs:4
rdb_last_cow_size:0
rdb_last_load_KEYS_expired:0
rdb_last_load_KEYS_loaded:0
aof_enabled:0
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:-1
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_rewrites:0
aof_rewrites_consecutive_failures:0
aof_last_write_status:ok
aof_last_cow_size:0
module_fork_in_progress:0
module_fork_last_cow_size:0

# Stats
total_connections_received:2
total_commands_processed:126
instantaneous_ops_per_sec:0
total_net_input_bytes:5259
total_net_output_bytes:346626
instantaneous_input_kbps:0.00
instantaneous_output_kbps:0.00
rejected_connections:0
sync_full:0
sync_partial_ok:0
sync_partial_err:0
expired_KEYS:0
expired_stale_perc:0.00
expired_time_cap_reached_count:0
expire_cycle_cpu_milliseconds:568
evicted_KEYS:0
evicted_clients:0
total_eviction_exceeded_time:0
current_eviction_exceeded_time:0
KEYSpace_hits:64
KEYSpace_misses:9
pubsub_channels:0
pubsub_patterns:0
latest_fork_usec:475
total_forks:4
migrate_cached_sockets:0
slave_expires_tracked_KEYS:0
active_defrag_hits:0
active_defrag_misses:0
active_defrag_key_hits:0
active_defrag_key_misses:0
total_active_defrag_time:0
current_active_defrag_time:0
tracking_total_KEYS:0
tracking_total_items:0
tracking_total_prefixes:0
unexpected_error_replies:0
total_error_replies:11
dump_payload_sanitizations:0
total_reads_processed:132
total_writes_processed:134
io_threaded_reads_processed:0
io_threaded_writes_processed:0
reply_buffer_shrinks:3
reply_buffer_expands:1

# Replication
role:master
connected_slaves:0
master_failover_state:no-failover
master_replid:e68a27ace65ac1489544683f27a00aac7eabbdb7
master_replid2:0000000000000000000000000000000000000000
master_repl_offSET:0
second_repl_offSET:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offSET:0
repl_backlog_histlen:0

# CPU
used_cpu_sys:17.338330
used_cpu_user:12.698221
used_cpu_sys_children:0.010956
used_cpu_user_children:0.001772

# Modules

# Errorstats
errorstat_ERR:count=11

# Cluster
cluster_enabled:0

# KEYSpace
db0:KEYS=1,expires=0,avg_TTL=0
```

---

# 3. `String`

`String` 은 redis 에서 기본적으로 문자열/숫자를 저장할 때 사용하는 자료 구조이다. 
key/value 모두 최대 길이는 **512MB** 이지만 너무 길면 메모리 낭비가 발생한다.


```shell
$ pwd
/usr/local/opt/redis/bin

$ brew services start redis
==> Successfully started `redis` (label: homebrew.mxcl.redis)

$ redis-cli
127.0.0.1:6379>
```

---

## 3.1. `SET`, `GET`

```shell
127.0.0.1:6379> help SET

 SET key value [NX|XX] [GET] [EX seconds|PX milliseconds|EXAT unix-time-seconds|PXAT unix-time-milliseconds|KEEPTTL]
 summary: SET the string value of a key
 since: 1.0.0
 group: string

127.0.0.1:6379> help GET

 GET key
 summary: GET the value of a key
 since: 1.0.0
 group: string
```

```shell
127.0.0.1:6379> SET username assu
OK

127.0.0.1:6379> GET username
"assu"
```

### 3.1.1 `SET` - [`NX | XX`]

`NX` 는 key 가 존재하지 않을 때만 insert 하는 명령어이다. 

```shell
127.0.0.1:6379> KEYS *
1) "username"

127.0.0.1:6379> SET username assu1 NX # username key 가 설정되어 있는 경우 (오류)
(nil)

127.0.0.1:6379> GET username
"assu"

127.0.0.1:6379> DEL username
(integer) 1

127.0.0.1:6379> SET username assu1 NX # username key 가 설정되어 있지 않은 경우 (정상)
OK

127.0.0.1:6379> GET username
"assu1"
```

`XX` 는 key 가 존재할 때만 update 하는 명령어이다.

```shell
127.0.0.1:6379> KEYS *
(empty array)

127.0.0.1:6379> SET username assu XX # username key 가 설정되어 있지 않은 경우 (오류)
(nil)

127.0.0.1:6379> SET username assu
OK

127.0.0.1:6379> SET username assu1 XX # username key 가 설정되어 있는 경우 (정상)
OK

127.0.0.1:6379> GET username
"assu1"
```

---

### 3.1.2 `SET` - [`EX seconds | PX milliseconds | EXAT unix-time-seconds | PXAT unix-time-milliseconds | KEEPTTL`]

`EX seconds` 는 만료 TTL 을 seconds 단위로 지정한다.

```shell
127.0.0.1:6379> SET username assu EX 10 # TTL을 10s 설정
OK

127.0.0.1:6379> GET username # 10초 경과 전
"assu"

127.0.0.1:6379> GET username # 10초 경과 후
(nil)
```

`PX milliseconds` 는 만료 TTL 을 ms 단위로 지정한다.

```shell
127.0.0.1:6379> SET username assu PX 10000 # TTL을 10,000ms 설정
OK

127.0.0.1:6379> GET username # 10,000 경과 전
"assu"

127.0.0.1:6379> GET username # 10,000 경과 후
(nil)
```

`EXAT unix-time-seconds` 는 TTL 을 unix time 기준 seconds 단위로 지정한다. 
`PXAT unix-time-milliseconds` 는 TTL 을 unix time 기준 ms 단위로 지정한다.

`KEEPTTL` 은 기존 key 의 TTL 을 지우지 않는다.

```shell
127.0.0.1:6379> SET test 111 ex 5 # TTL 을 5초로 설정
OK
127.0.0.1:6379> GET test
"111"
127.0.0.1:6379> SET test 222 # TTL 이 삭제됨
OK
127.0.0.1:6379> TTL test
(integer) -1
127.0.0.1:6379> GET test # TTL 이 삭제되어 5초 후에도 key 존재
"222"


127.0.0.1:6379> SET test 111 ex 10 # TTL 을 10초로 설정
OK
127.0.0.1:6379> SET test 222 keepTTL # TTL 유지
OK
127.0.0.1:6379> TTL test
(integer) 4
127.0.0.1:6379> GET test
"222"
127.0.0.1:6379> GET test # TTL 이 유지되어 10초 후에 key 삭제됨
(nil)
```

---

## 3.2. `MSET`, `MGET`

여러 개의 key-value 를 한번에 저장하고 검색하는데 사용하며, 입력 순서대로 저장된다는 보장은 없다.

```shell
127.0.0.1:6379> help MSET

 MSET key value [key value ...]
 summary: SET multiple KEYS to multiple values
 since: 1.0.1
 group: string

127.0.0.1:6379> help MGET

 MGET key [key ...]
 summary: GET the values of all the given KEYS
 since: 1.0.0
 group: string
```

```shell
127.0.0.1:6379> MSET username assu userage 20 usercity seoul
OK

127.0.0.1:6379> MGET username usercity
1) "assu"
2) "seoul"

127.0.0.1:6379> GET usercity
"seoul"
```

---

## 3.3. `STRLEN`

검색하려는 key 의 value 길이를 조회한다.

```shell
127.0.0.1:6379> help STRLEN

 STRLEN key
 summary: GET the length of the value stored in a key
 since: 2.2.0
 group: string
```

```shell
127.0.0.1:6379> SET username assu
OK

127.0.0.1:6379> STRLEN username
(integer) 4
```

---

## 3.4. `SETEX`

일정 시간이 지난 후 자동으로 key 를 삭제하며, 시간 단위는 seconds 단위이다. 
`TTL key` 로 삭제 전까지의 시간 확인이 가능하다.

```shell
127.0.0.1:6379> help SETEX

 SETEX key seconds value
 summary: SET the value and expiration of a key
 since: 2.0.0
 group: string
```

```shell
127.0.0.1:6379> SETEX username 100 assu
OK

127.0.0.1:6379> TTL username
(integer) 97
```

---

## 3.5. `TTL`

key 의 남아있는 TTL 시간을 seconds 단위로 확인한다.

TTL 설정이 안된 key 의 경우 -1 을 리턴하고, TTL 이 만료된 key 의 경우 -2 를 리턴한다.

```shell
127.0.0.1:6379> help TTL

 TTL key
 summary: GET the time to live for a key in seconds
 since: 1.0.0
 group: generic
```

```shell
127.0.0.1:6379> SET username assu
OK

127.0.0.1:6379> TTL username # TTL 설정이 안된 key 조회
(integer) -1
```

```shell
127.0.0.1:6379> SETEX username 10 assu
OK
127.0.0.1:6379> TTL username # 남아있는 시간(seconds) 리턴
(integer) 8
127.0.0.1:6379> TTL username # TTL 이 만료된 경우
(integer) -2
```

---

## 3.6. `INCR`, `DECR`

key 값의 value 값 1씩 증감시킨다.

```shell
127.0.0.1:6379> help INCR

 INCR key
 summary: INCRement the integer value of a key by one
 since: 1.0.0
 group: string

127.0.0.1:6379> help DECR

 DECR key
 summary: DECRement the integer value of a key by one
 since: 1.0.0
 group: string
```

```shell
127.0.0.1:6379> SET aa 2
OK

127.0.0.1:6379> GET aa
"2"

127.0.0.1:6379> INCR aa
(integer) 3

127.0.0.1:6379> GET aa
"3"

127.0.0.1:6379> DECR aa
(integer) 2

127.0.0.1:6379> GET aa
"2"
```

---

## 3.7. `INCRBY`, `DECRBY`, `INCRBYFLOAT`

`INCRBY`, `DECRBY` 는 특정 수치만큼 value 값을 증감시킨다.

```shell
127.0.0.1:6379> help INCRBY

 INCRBY key INCRement
 summary: INCRement the integer value of a key by the given amount
 since: 1.0.0
 group: string

127.0.0.1:6379> help DECRBY

 DECRBY key DECRement
 summary: DECRement the integer value of a key by the given number
 since: 1.0.0
 group: string
```

```shell
127.0.0.1:6379> SET aa 2
OK

127.0.0.1:6379> INCRBY aa 3
(integer) 5

127.0.0.1:6379> GET aa
"5"

127.0.0.1:6379> INCRBY aa -9
(integer) -4

127.0.0.1:6379> DECRBY aa 1
(integer) -5
```

`INCRBYFLOAT` 는 소수의 형태로 value 값을 증감시킨다. 
쌍이 되는 `DECRBYfloat` 명령어는 없는데 `-`값을 설정하여 `INCRBYFLOAT` 를 사용하면 된다.

```shell
127.0.0.1:6379> help INCRBYFLOAT

 INCRBYFLOAT key INCRement
 summary: INCRement the float value of a key by the given amount
 since: 2.6.0
 group: string
```

```shell
127.0.0.1:6379> SET aa 1
OK

127.0.0.1:6379> INCRBYFLOAT aa 2
"3"

127.0.0.1:6379> GET aa
"3"

127.0.0.1:6379> INCRBYFLOAT aa 2.5
"5.5"

127.0.0.1:6379> INCRBYFLOAT aa -2.5
"3"
```

---

## 3.8. `APPEND`

현재 value 값 뒤에 value 를 추가한다. 
만일 key 가 존재하지 않으면 신규로 생성한다.

```shell
127.0.0.1:6379> help APPEND

 APPEND key value
 summary: APPEND a value to a key
 since: 2.0.0
 group: string
```

```shell
127.0.0.1:6379> KEYS *
(empty array)

127.0.0.1:6379> APPEND username assu # key 가 없는 경우 생성
(integer) 4

127.0.0.1:6379> GET username
"assu"

127.0.0.1:6379> APPEND username hi # 기존에 존재하는 key 에 APPEND
(integer) 6

127.0.0.1:6379> GET username
"assuhi"
```

---

## 3.9. `GETRANGE`, `SETRANGE`

string 연산에서 substring, replace 와 동일한 연산이다.

```shell
127.0.0.1:6379> help GETRANGE

 GETRANGE key start end
 summary: GET a substring of the string stored at a key
 since: 2.4.0
 group: string

127.0.0.1:6379> help SETRANGE

 SETRANGE key offSET value
 summary: Overwrite part of a string at key starting at the specified offSET
 since: 2.2.0
 group: string
```

```shell
127.0.0.1:6379> SET hello world
OK

127.0.0.1:6379> GET hello
"world"

127.0.0.1:6379> GETRANGE hello 2 4
"rld"

127.0.0.1:6379> SETRANGE hello 2 ppp
(integer) 5

127.0.0.1:6379> GET hello
"woppp"
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 주종면 저자의 **빅데이터 저장 및 분석을 위한 NoSQL & Redis**를 기반으로 스터디하며 정리한 내용들입니다.*

* [빅데이터 저장 및 분석을 위한 NoSQL & Redis](http://www.yes24.com/Product/Goods/71131862)
* [빅데이터 저장 및 분석을 위한 NoSQL & Redis - 실습파일](http://www.pitmongo.co.kr/bbs/board.php?bo_table=h_file&wr_id=35)
* [https://redis.io/commands](https://redis.io/commands/)
* [https://redis.io/commands - string](https://redis.io/commands/?group=string)
* [Redis 언어별 관련 드라이브](https://redis.io/docs/clients/)
* [Redis 데이터 입력, 수정, 삭제, 조회](https://sungwookkang.com/1313)
* [Redis 자료 구조 - String](https://luran.me/362)
* [RedisGate - keepTTL](http://redisgate.kr/redis/command/SET.php)