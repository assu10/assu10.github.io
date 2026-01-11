---
layout: post
title:  "Docker - 도커 기초(2): 도커 네트워크 구조와 스토리지"
date: 2025-11-16 10:00:00
categories: dev
tags: devops docker docker-network docker-storage docker-volume bind-mount tmpfs docker-bridge docker-host docker-cp data-persistence container-communication
---

이 포스트에서는 애플리케이션을 컨테이너 환경에서 안정적으로 운영하기 위해 알아야 할 **네트워크**와 **스토리지** 개념까지 알아본다.

---

**목차**

<!-- TOC -->
* [1. 도커 컨테이너 네트워크](#1-도커-컨테이너-네트워크)
  * [1.1. 도커 컨테이너 네트워크 구조](#11-도커-컨테이너-네트워크-구조)
    * [1.1.1. 컨테이너 내부 네트워크: eth0](#111-컨테이너-내부-네트워크-eth0)
    * [1.1.2. 도커 호스트 네트워크: docker0, veth](#112-도커-호스트-네트워크-docker0-veth)
  * [1.2. 도커 네트워크 확인](#12-도커-네트워크-확인)
  * [1.3. 호스트에서 컨테이너로 파일 전송: `docker container cp`](#13-호스트에서-컨테이너로-파일-전송-docker-container-cp)
  * [1.4. 컨테이너에서 호스트로 파일 전송: `docker container cp`](#14-컨테이너에서-호스트로-파일-전송-docker-container-cp)
* [2. 도커 스토리지](#2-도커-스토리지)
  * [2.1. 도커 스토리지 개념](#21-도커-스토리지-개념)
  * [2.2. 도커 스토리지의 필요성](#22-도커-스토리지의-필요성)
    * [2.2.1. 케이스 1: 컨테이너 정지(`stop`) 후 재시작(`start`)](#221-케이스-1-컨테이너-정지stop-후-재시작start)
    * [2.2.2. 케이스 2: 컨테이너 삭제(`rm`) 후 새로운 컨테이너 생성](#222-케이스-2-컨테이너-삭제rm-후-새로운-컨테이너-생성)
  * [2.3. `volume`: 도커가 관리하는 영속성 스토리지](#23-volume-도커가-관리하는-영속성-스토리지)
    * [2.3.1. `volume` 생성 및 확인](#231-volume-생성-및-확인)
    * [2.3.2. `volume`을 사용하여 데이터 영속성 확보](#232-volume을-사용하여-데이터-영속성-확보)
    * [2.3.3. 컨테이너 삭제 후 데이터 확인](#233-컨테이너-삭제-후-데이터-확인)
    * [2.3.4. `volume`의 실제 위치 확인: `inspect`](#234-volume의-실제-위치-확인-inspect)
  * [2.4. `bind mount`: 호스트 경로 직접 공유](#24-bind-mount-호스트-경로-직접-공유)
    * [2.4.1. 호스트와 컨테이너 간 양방향 동기화 확인](#241-호스트와-컨테이너-간-양방향-동기화-확인)
    * [2.4.2. 동기화 테스트 1: 컨테이너에서 생성 후 호스트에서 확인](#242-동기화-테스트-1-컨테이너에서-생성-후-호스트에서-확인)
    * [2.4.3. 동기화 테스트 2: 호스트에서 삭제 후 컨테이너에서 확인](#243-동기화-테스트-2-호스트에서-삭제-후-컨테이너에서-확인)
  * [2.5. `tmpfs mount`: 메모리 기반의 임시 스토리지](#25-tmpfs-mount-메모리-기반의-임시-스토리지)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 도커 컨테이너 네트워크

도커를 효율적으로 활용하기 위해서는 도커 호스트와 컨테이너의 네트워크 구조를 이해해야 한다.  
여기서는 도커 컨테이너가 통신하는 기본적인 방식과 호스트와 컨테이너 간 파일 전송이 어떻게 이루어지는지 알아본다.

---

## 1.1. 도커 컨테이너 네트워크 구조

[2.4. 도커 컨테이너 실행: `run`](https://assu10.github.io/dev/2025/09/11/docker-basics-and-commands-guide-1/#24-%EB%8F%84%EC%BB%A4-%EC%BB%A8%ED%85%8C%EC%9D%B4%EB%84%88-%EC%8B%A4%ED%96%89-run) 에서 
도커 호스트에 설치된 도커가 컨테이너를 관리하는 것에 대해 알아보았다.

여기서는 도커 호스트와 도커 컨테이너의 네트워크 구성이 어떻게 되어있는지 알아본다.

---

### 1.1.1. 컨테이너 내부 네트워크: eth0

my-ubuntu:0.1 이미지로 컨테이너를 실행하고 접속한 뒤 `ifconfig` 명령어로 네트워크 인터페이스를 확인한다.

터미널 1
```shell
# 컨테이너 전체 목록 확인
# 컨테이너를 삭제했다면 docker container run -it my-ubuntu:0.1 로 재실행
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE           COMMAND       CREATED        STATUS                    PORTS     NAMES
3f724b51317e   my-ubuntu:0.1   "/bin/bash"   21 hours ago   Exited (0) 21 hours ago             fervent_easley

# container start 명령어로 my-ubuntu 이미지로 생성한 컨테이너 가동
assu@myserver01:~$ docker container start 3f724b51317e
3f724b51317e

# attach 명령어로 컨테이너 내부에 접속
assu@myserver01:~$ docker container attach 3f724b51317e

# 아이피 주소 확인
root@3f724b51317e:/# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255  # 컨테이너 내부 IP는 172.17.0.2
        ether 3a:86:ab:e2:76:b4  txqueuelen 0  (Ethernet)
...

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
...

root@3f724b51317e:/#
```

컨테이너 내부에 `eth0` 인터페이스가 할당되었으며, 172.17.0.2 라는 사설 IP를 가진 것을 확인할 수 있다.

---

### 1.1.2. 도커 호스트 네트워크: docker0, veth

이제 다른 터미널에서 **도커 호스트**의 네트워크 인터페이스를 확인해본다.

터미널 2
```shell
~ ssh assu@127.0.0.1

# 도커 호스트에서 ifconfig 로 네트워크 정보 확인
assu@myserver01:~$ ifconfig
docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet6 fe80::648e:1fff:fe33:34c2  prefixlen 64  scopeid 0x20<link>
        ether 66:8e:1f:33:34:c2  txqueuelen 0  (Ethernet)
...

enp0s8: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.2.4  netmask 255.255.255.0  broadcast 10.0.2.255
        inet6 fe80::a00:27ff:fed8:1a48  prefixlen 64  scopeid 0x20<link>
        ether 08:00:27:d8:1a:48  txqueuelen 1000  (Ethernet)
...

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
...
veth47d3865: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::c479:3aff:fe2e:b51c  prefixlen 64  scopeid 0x20<link>
        ether c6:79:3a:2e:b5:1c  txqueuelen 0  (Ethernet)
...

assu@myserver01:~$
```

여기서 주목할 인터페이스는 `docker0`과 `veth47d3865` 이다.

- `docker0`
  - 도커 설치 시 생성되는 가상 브리지(도커 호스트와 컨테이너를 연결하는 역할)
  - 컨테이너의 게이트웨이 역할을 하며, 여기서는 172.17.0.1 IP 를 갖고 있음
  - 컨테이너(172.17.0.2)는 이 `docker0` 브리지를 통해 호스트 및 외부와 통신함
- `vethXXXX`
  - `veth`(virtual Ethernet) 인터페이스
  - 컨테이너를 실행할 때 자동으로 생성되며, 컨테이너 내부의 `eth0`과 도커 호스트의 `docker0` 브리지를 연결해주는 가상의 네트워크 케이블과 같은 역할
- `enp0s8`
  - 도커 호스트(서버) 자체가 보유한 물리적 또는 가상 네트워크 인터페이스 (외부망과 연결)

![도커 네트워크](/assets/img/dev/2025/1116/network.png)

---

이제 터미널 1을 통해 컨테이너를 빠져나온다.

터미널 1
```shell
root@3f724b51317e:/# exit
exit
assu@myserver01:~$
```

---

## 1.2. 도커 네트워크 확인

도커는 `docker network ls` 명령을 통해 현재 사용 가능한 네트워크 목록을 보여준다.

```shell
# 도커 네트워크 확인
assu@myserver01:~$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
d5a14cb66f42   bridge    bridge    local
26dfd2bd80ec   host      host      local
426836c8786b   none      null      local
```

기본적으로 `bridge`, `host`, `none` 이라는 세 가지 네트워크 드라이버를 제공하며, 각 드라이버는 컨테이너의 네트워크 동작 방식을 결정한다.

---

**`bridge` 드라이버(기본)**

[1.1.1. 컨테이너 내부 네트워크: eth0](#111-컨테이너-내부-네트워크-eth0) 에서 살펴본 구조가 바로 `bridge` 드라이버의 작동 방식이다.  
컨테이너를 생성할 때 **기본으로 사용되는 드라이버**이다.

각 컨테이너는 자신만의 격리된 네트워크 인터페이스(`eth0`)을 가지며, 이는 도커 호스트의 `docker0` 브리지에 바인딩된다.

`--network=bridge` 옵션을 명시적으로 사용하거나, 생략 시 자동으로 적용된다.

---

**`host` 드라이버**

컨테이너가 **호스트의 네트워크 스택을 그대로 공유**한다. 즉, 네트워크 격리가 이루어지지 않는다.

`docker container run -it --network=host my-ubuntu:0.1`

`host` 드라이버로 컨테이너를 실행하고 `ifconfig`를 확인하면, 컨테이너 내부가 아닌 **호스트의 네트워크 인터페이스(`docker0`, `enp0s8`..)가 그대로 노출**된다.

네트워크 격리에 따른 오버헤드가 없어 속도가 빠르다는 장점이 있지만, 컨테이너가 호스트의 포트를 직접 사용하므로 포트 충돌이 발생할 수 있으며, 보안상 취약할 수 있다는 단점이 있다.

```shell
# --network=host 로 실행한 컨테이너 내부
assu@myserver01:~$ docker container run -it --network=host my-ubuntu:0.1
root@myserver01:/# ifconfig

# 호스트 네트워크 정보와 동일함
docker0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet6 fe80::648e:1fff:fe33:34c2  prefixlen 64  scopeid 0x20<link>
        ether 66:8e:1f:33:34:c2  txqueuelen 0  (Ethernet)
...

enp0s8: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.2.4  netmask 255.255.255.0  broadcast 10.0.2.255
        inet6 fe80::a00:27ff:fed8:1a48  prefixlen 64  scopeid 0x20<link>
        ether 08:00:27:d8:1a:48  txqueuelen 1000  (Ethernet)
...

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
...

root@myserver01:/# exit
exit
```

---

**`none` 드라이버**

컨테이너에 **네트워크 인터페이스를 할당하지 않는다.** (루프백 `lo` 인터페이스 제외)

`docker container run -it --network=none my-ubuntu:0.1`

컨테이너 외부(호스트 및 다른 컨테이너, 외부망)와 **어떠한 통신도 불가능**하다.  
네트워크 연결이 전혀 필요없는 작업(예: 일회성 배치 작업, 보안이 매우 중요한 연산)에 사용된다.
```shell
# --network=none 으로 실행한 컨테이너 내부
assu@myserver01:~$ docker container run -it --network=none my-ubuntu:0.1
root@61b9f8676213:/# ifconfig

# 컨테이너 자체적으로 네트워크 인터페이스를 가지고 있지 않음
lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
...

root@61b9f8676213:/# exit
exit
```

---

## 1.3. 호스트에서 컨테이너로 파일 전송: `docker container cp`

컨테이너를 운영하다 보면 호스트에 있는 설정 파일이나 데이터를 컨테이너 내부로 전송해야 할 경우가 있다.  
이 때 `docker container cp` 명령어를 사용하면 SSH나 다른 복잡한 설정 없이 간편하게 파일을 복사할 수 있다.

`docker container cp [호스트 로컬 경로] [컨테이너 ID 또는 이름]:[컨테이너 내부 경로]`

---

**터미널 1: 도커 호스트(파일 전송 명령 실행)**

```shell
# 호스트에서 작업용 디렉터리 생성 및 파일 준비
assu@myserver01:~$ cd work
assu@myserver01:~/work$ mkdir ch04
assu@myserver01:~/work$ ls
ch04
assu@myserver01:~/work$ cd ch04
assu@myserver01:~/work/ch04$ mkdir ex01
assu@myserver01:~/work/ch04$ cd ex01

assu@myserver01:~/work/ch04/ex01$ vim test01.txt

assu@myserver01:~/work/ch04/ex01$ pwd
/home/assu/work/ch04/ex01

assu@myserver01:~/work/ch04/ex01$
```

---

**터미널 2: 컨테이너**

파일을 받을 컨테이너를 준비하고, /home 디렉터리 내부를 확인한다.
```shell
# 새 컨테이너 실행 및 접속
assu@myserver01:~$ docker container run -it ubuntu
root@8bf3a110cb04:/# ls
bin  boot  dev  etc  home  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var

root@8bf3a110cb04:/# cd home

root@8bf3a110cb04:/home# ls
ubuntu
```

---

**터미널 1: 도커 호스트에서 파일 전송**

이제 `docker container cp` 명령을 실행하여 호스트의 test01.txt 파일을 8bf3a110cb04 컨테이너의 /home 디렉터리로 복사한다.

```shell
# 현재 실행 중인 컨테이너 ID 확인
assu@myserver01:~/work/ch04/ex01$ docker container ls
CONTAINER ID   IMAGE     COMMAND       CREATED              STATUS              PORTS     NAMES
8bf3a110cb04   ubuntu    "/bin/bash"   About a minute ago   Up About a minute             sharp_rhodes

# 파일 복사 실행
assu@myserver01:~/work/ch04/ex01$ docker container cp ./test01.txt 8bf3a110cb04:/home
Successfully copied 2.05kB to 8bf3a110cb04:/home
```

---

**터미널 2: 컨테이너에서 파일 확인**

```shell
root@8bf3a110cb04:/home# ls
test01.txt  ubuntu
```

---

## 1.4. 컨테이너에서 호스트로 파일 전송: `docker container cp`

반대로 컨테이너 내부에서 생성된 로그 파일이나 결과 데이터를 호스트로 가져와야 하는 경우도 있다.  
이 때도 `docker container cp` 명령어를 사용하며, 경로의 순서만 바꿔주면 된다.

`docker container cp [컨테이너 ID 또는 이름]:[컨테이너 내부 경로] [호스트 로컬 경로]`

---

**터미널 2: 컨테이너**
```shell
root@8bf3a110cb04:/home# cp test01.txt test02.txt

root@8bf3a110cb04:/home# ls
test01.txt  test02.txt  ubuntu
```

---

**터미널 1: 도커 호스트에서 파일 전송**

컨테이너에서 호스트로 파일을 복사할 때도 명령어는 **반드시 도커 호스트(터미널 1)에서 실행**해야 한다.  
컨테이너 내부에는 도커 엔진이 설치되어 있지 않아 `docker` 명령어를 실행할 수 없다.

호스트의 현재 디렉터리(~/work/ch04/ex01)를 확인한 뒤, `docker cp` 명령으로 컨테이너의 test02.txt 파일을 호스트로 가져온다.

```shell
assu@myserver01:~/work/ch04/ex01$ docker container ls
CONTAINER ID   IMAGE     COMMAND       CREATED         STATUS         PORTS     NAMES
8bf3a110cb04   ubuntu    "/bin/bash"   6 minutes ago   Up 6 minutes             sharp_rhodes

assu@myserver01:~/work/ch04/ex01$ pwd
/home/assu/work/ch04/ex01

# 현재 호스트 디렉터리 상태 확인
assu@myserver01:~/work/ch04/ex01$ ls
test01.txt

# 컨테이너의 파일을 호스트로 복사
assu@myserver01:~/work/ch04/ex01$ docker cp 8bf3a110cb04:/home/test02.txt /home/assu/work/ch04/ex01
Successfully copied 2.05kB to /home/assu/work/ch04/ex01

# 호스트 디렉터리에 파일이 복사되었는지 최종 확인
assu@myserver01:~/work/ch04/ex01$ ls
test01.txt  test02.txt
```

---

**터미널 2: 컨테이너 종료**
```shell
root@8bf3a110cb04:/home# exit
exit
```

---

# 2. 도커 스토리지

도커 컨테이너는 기본적으로 **휘발성(non-persistent)**이다.  
컨테이너는 언제든 중지되고 삭제될 수 있으며, 컨테이너가 삭제되면 내부에서 생성되거나 변경된 파일도 함께 사라진다.

하지만 애플리케이션의 데이터(예: 데이터베이스 파일, 로그 등)는 컨테이너의 생명주기와 관계없이 영구적으로 보존되어야 한다. 이를 위해 **도커 스토리지**가 필요하다.

---

## 2.1. 도커 스토리지 개념

도커 스토리지는 컨테이너에서 사용되거나 생성되는 데이터를 컨테이너의 실행 여부와 관계없이 **영속성(persistence)**을 가지고 유지하기 위한 메커니즘이다.

컨테이너 내부에 데이터를 저장하는 대신, 호스트나 별도의 스토리지 시스템에 데이터를 저장하고 이를 컨테이너에 연결(마운트)하여 사용한다.

![도커 볼륨 종류](/assets/img/dev/2025/1116/volumes.png)

도커는 데이터를 저장하는 방식에 따라 크게 3가지 스토리지(마운트) 유형을 제공한다.

- [**volume**](#23-volume)
  - 도커가 관리하는 영역(volume)을 생성하고, 이 영역을 컨테이너의 특정 디렉터리와 공유(마운트)하는 방식
  - **도커에서 가장 권장하는 방식**
- [**bind mount**](#24-bind-mount)
  - 도커 **호스트의 특정 디렉터리나 파일**을 컨테이너의 디렉터리와 직접 공유하는 방식
- [**tmpfs**](#25-tmpfs-mount)
  - 도커 **호스트의 메모리**에 파일을 저장하는 방식
  - 매우 빠르지만, 컨테이너가 중지되면 데이터가 함께 삭제되는 임시 스토리지임

---

## 2.2. 도커 스토리지의 필요성

도커 스토리지의 필요성을 PostgreSQL 컨테이너를 통해 알아보자.

---

### 2.2.1. 케이스 1: 컨테이너 정지(`stop`) 후 재시작(`start`)

먼저 PostgreSQL 컨테이너를 실행하고, 그 안에 데이터를 생성한다.

```shell
# postgres 이미지 다운로드
assu@myserver01:~$ docker image pull postgres
Using default tag: latest
latest: Pulling from library/postgres
51365f04b688: Pull complete
...
Digest: sha256:41bfa2e5b168fff0847a5286694a86cff102bdc4d59719869f6b117bb30b3a24
Status: Downloaded newer image for postgres:latest
docker.io/library/postgres:latest

# 이미지 확인
assu@myserver01:~$ docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
my-ubuntu    0.1       3eb5806116ca   24 hours ago   162MB
postgres     latest    b90e9c757ca1   2 days ago     479MB
ubuntu       latest    f4158f3f9981   2 months ago   101MB
python       3.13.7    ce75f3f8bdaf   3 months ago   1.12GB
```

[도커 허브 검색 결과](https://hub.docker.com/_/postgres) 에서 postgres 컨테이너 실행 방법을 알 수 있다.

```shell
$ docker run --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d postgres
```

- `--name`: 컨테이너 이름
- `-e`: 환경 변수 설정
- `-d`: 백그라운드 실행

```shell
# 컨테이너 실행 (비밀번호 설정, 백그라운드 실행)
assu@myserver01:~$ docker run --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d postgres
6c11d8c7f64efd63d97d5cc441ad857dfae2a77f0e6c73fb9a90b7e7734de22a

# 컨테이너 상태 확인
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED              STATUS              PORTS      NAMES
6c11d8c7f64e   postgres   "docker-entrypoint.s…"   About a minute ago   Up About a minute   5432/tcp   some-postgres
```

```shell
# 실행 중인 컨테이너에 접속
assu@myserver01:~$ docker container exec -it 6c11d8c7f64e /bin/bash
root@6c11d8c7f64e:/# psql -U postgres
psql (18.1 (Debian 18.1-1.pgdg13+2))
Type "help" for help.

postgres=#
```

`exec -it` 옵션으로 실행 중인 컨테이너 내부에 접속한다.
`psql` 명령어로 postgres 계정으로 PostgreSQL 에 접속한다. `-U`는 username 을 의미한다.

```shell
# superuser 권한을 부여한 user01 이라는 새로운 사용자 생성
postgres=# create user user01 password '1234' superuser;
CREATE ROLE

# test01 데이터베이스 생성, 소유자는 user01
postgres=# create database test01 owner user01;
CREATE DATABASE

# user01으로 test01 데이터베이스에 접속
postgres=# \c test01 user01
You are now connected to database "test01" as user "user01".

# table01 테이블 생성
test01=# create table table01(
id integer primary key,
name varchar(20)
);
CREATE TABLE

# 테이블 목록 확인
test01=# \dt
          List of tables
 Schema |  Name   | Type  | Owner
--------+---------+-------+--------
 public | table01 | table | user01
(1 row)

# 데이터 확인
test01=# select * from table01;
 id | name
----+------
(0 rows)

# 데이터 삽입
test01=# insert into table01(id, name)
test01-# values (1, 'assu');
INSERT 0 1

# 데이터 확인
test01=# select * from table01;
 id | name
----+------
  1 | assu
(1 row)
```

```shell
# PostgreSQL 빠져나감
test01-# \q

# 컨테이너에서도 빠져나감
root@6c11d8c7f64e:/# exit
exit
assu@myserver01:~$
```

이제 컨테이너를 정지(stop)했다가 다시 시작(start)한 뒤, 데이터가 유지되는지 확인한다.

```shell
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS          PORTS      NAMES
6c11d8c7f64e   postgres   "docker-entrypoint.s…"   14 minutes ago   Up 14 minutes   5432/tcp   some-postgres

# 컨테이너 정지
assu@myserver01:~$ docker container stop 6c11d8c7f64e
6c11d8c7f64e

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE           COMMAND                  CREATED          STATUS                         PORTS     NAMES
6c11d8c7f64e   postgres        "docker-entrypoint.s…"   15 minutes ago   Exited (0) 8 seconds ago                 some-postgres
8bf3a110cb04   ubuntu          "/bin/bash"              2 hours ago      Exited (0) About an hour ago             sharp_rhodes
61b9f8676213   my-ubuntu:0.1   "/bin/bash"              3 hours ago      Exited (0) 3 hours ago                   nervous_stonebraker
0aa364ee8697   my-ubuntu:0.1   "/bin/bash"              4 hours ago      Exited (0) 4 hours ago                   vigorous_franklin
3f724b51317e   my-ubuntu:0.1   "/bin/bash"              25 hours ago     Exited (0) 4 hours ago                   fervent_easley

# 컨테이너 재시작
assu@myserver01:~$ docker container start 6c11d8c7f64e
6c11d8c7f64e

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS         PORTS      NAMES
6c11d8c7f64e   postgres   "docker-entrypoint.s…"   15 minutes ago   Up 3 seconds   5432/tcp   some-postgres
```

```shell
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS         PORTS      NAMES
6c11d8c7f64e   postgres   "docker-entrypoint.s…"   15 minutes ago   Up 3 seconds   5432/tcp   some-postgres

# 재시작된 컨테이너에 접속
assu@myserver01:~$ docker container exec -it 6c11d8c7f64e /bin/bash
root@6c11d8c7f64e:/# psql -U postgres
psql (18.1 (Debian 18.1-1.pgdg13+2))
Type "help" for help.

# 데이터 확인
postgres=# \c test01 user01
You are now connected to database "test01" as user "user01".

test01=# \dt
          List of tables
 Schema |  Name   | Type  | Owner
--------+---------+-------+--------
 public | table01 | table | user01
(1 row)

test01=# select * from table01;
 id | name
----+------
  1 | assu
(1 row)

test01=# \q

root@6c11d8c7f64e:/# exit
exit
```

컨테이너는 단순히 `stop/start` 하는 경우에는 **데이터가 유지**된다. 컨테이너의 파일 시스템이 그대로 보존되기 때문이다.

---

### 2.2.2. 케이스 2: 컨테이너 삭제(`rm`) 후 새로운 컨테이너 생성

이번에는 컨테이너를 아예 **삭제(rm)**한 뒤, 같은 이름과 옵션으로 **새로운 컨테이너를 생성**해보자.

```shell
# 1. 컨테이너 정지 및 삭제
assu@myserver01:~$ docker container stop some-postgres
6c11d8c7f64e
assu@myserver01:~$ docker container rm some-postgres
6c11d8c7f64e

assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE           COMMAND       CREATED        STATUS                         PORTS     NAMES
8bf3a110cb04   ubuntu          "/bin/bash"   2 hours ago    Exited (0) About an hour ago             sharp_rhodes
61b9f8676213   my-ubuntu:0.1   "/bin/bash"   4 hours ago    Exited (0) 4 hours ago                   nervous_stonebraker
0aa364ee8697   my-ubuntu:0.1   "/bin/bash"   4 hours ago    Exited (0) 4 hours ago                   vigorous_franklin
3f724b51317e   my-ubuntu:0.1   "/bin/bash"   25 hours ago   Exited (0) 4 hours ago                   fervent_easley
```

6c11d8c7f64e 컨테이너가 완전히 사라졌다. 이 컨테이너가 가지고 있던 모든 데이터도 함께 삭제되었다.

```shell
# 동일한 설정으로 새 컨테이너 실행
assu@myserver01:~$ docker run --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d postgres
44d8899dd1b6c12fb53593d346acac3ab9618213de2cd0b8d2fcaa936e3330f4

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
44d8899dd1b6   postgres   "docker-entrypoint.s…"   7 seconds ago   Up 7 seconds   5432/tcp   some-postgres

# 새로 생성된 컨테이너에 접속하여 데이터 확인
assu@myserver01:~$ docker container exec -it 44d8899dd1b6 /bin/bash

# postgreSQL에 접속
root@44d8899dd1b6:/# psql -U postgres
psql (18.1 (Debian 18.1-1.pgdg13+2))
Type "help" for help.

# 이전에 생성했던 user01 / test01 DB로 접속 시도
postgres=# \c test01 user01
connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: FATAL:  role "user01" does not exist
Previous connection kept

# postgreSQL 종료
postgres=# \q

# 컨테이너에서 빠져나옴
root@44d8899dd1b6:/# exit
exit
```

컨테이너를 삭제하는 순간, 컨테이너 내부에 저장되었던 모든 데이터가 함께 삭제되었다.

이처럼 컨테이너의 버전 업그레이드나 설정 변경 등을 위해 기존 컨테이너를 삭제하고 새로 생성하는 일은 매우 빈번하다. 이 때 데이터가 함께 사라진다면 실제 서비스에서는 
절대 사용할 수 없을 것이다.

이 문제를 해결하고 **데이터를 컨테이너의 생명주기와 분리하여 영구적으로 보존**하기 위해 **도커 볼륨(Volume)**이 필요하다.

---

## 2.3. `volume`: 도커가 관리하는 영속성 스토리지

`volume`은 도커 컨테이너에서 생성되는 데이터가 컨테이너를 삭제한 후에도 영구적으로 유지될 수 있도록 도와주는 **도커에서 공식적으로 권장하는 스토리지 솔루션**이다.

이 볼륨은 도커 엔진에 의해 관리되며, 호스트 파일 시스템의 특정 경로(일반적으로 /var/lib/docker/volumes/)에 저장된다.

---

### 2.3.1. `volume` 생성 및 확인

먼저 `docker volume` 관련 명령어를 알아보자.

```shell
# 현재 도커에 생성된 볼륨 목록 확인
assu@myserver01:~$ docker volume ls
DRIVER    VOLUME NAME
local     23642dc5d5f1551c6b01fb23d0296080819fabb080784842a79efd7c6c7d904f
local     a4d9879d5f51104566f90f965f8c9851882b2543b626f278f27edfa39aeb3d91

# 'myvolume01'이라는 이름의 새 볼륨 생성
assu@myserver01:~$ docker volume create myvolume01
myvolume01

# 볼륨이 생성되었는지 다시 확인
assu@myserver01:~$ docker volume ls
DRIVER    VOLUME NAME
local     23642dc5d5f1551c6b01fb23d0296080819fabb080784842a79efd7c6c7d904f
local     a4d9879d5f51104566f90f965f8c9851882b2543b626f278f27edfa39aeb3d91
local     myvolume01
```

---

### 2.3.2. `volume`을 사용하여 데이터 영속성 확보

이제 [2.2.2. 케이스 2: 컨테이너 삭제(`rm`) 후 새로운 컨테이너 생성](#222-케이스-2-컨테이너-삭제rm-후-새로운-컨테이너-생성)에서 발생했던 데이터 유실 문제를 `volume`으로 해결해보자.

컨테이너를 실행할 때 `--mount` 옵션을 사용하여 우리가 생성한 볼륨을 컨테이너의 특정 디렉터리에 연결(마운트)한다.

```shell
# 'myvolume01' 볼륨을 컨테이너의 /var/lib/postgresql 디렉터리에 연결하여 실행
# (참고: source에 지정된 'myvolume01'가 없으면 도커가 자동으로 생성해 줍니다.)
assu@myserver01:~$ docker container run -e POSTGRES_PASSWORD=mysecretpassword \
--mount type=volume,source=myvolume01,target=/var/lib/postgresql -d postgres
e42339de1019eef3773e49805213dfa22fccb730388f196cc15c395c21fccd6a

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS          PORTS      NAMES
44d8899dd1b6   postgres   "docker-entrypoint.s…"   40 minutes ago   Up 40 minutes   5432/tcp   some-postgres
```

`--mount` 옵션의 의미는 아래와 같다.
- **type=volume**
  - 마운트 타입을 볼륨으로 지정
- **source=myvolume01**
  - 호스트의 myvolume01이라는 볼륨 사용
- **target=/var/lib/postgresql/**
  - 컨테이너 내부의 /var/lib/postgresql 디렉터리에 연결

이제 컨테이너 내부의 /var/lib/postgresql 디렉터리에 생성되는 모든 파일은 컨테이너가 아닌 호스트의 myvolume01 볼륨에 저장된다.

```shell
# 볼륨을 공유하는 새로운 컨테이너 실행
assu@myserver01:~$ docker container run --name mypostgre -e POSTGRES_PASSWORD=mysecretpassword \
--mount type=volume,source=myvolume01,target=/var/lib/postgresql -d postgres
4e2926d4e86aaac40f076feffb6940c7c0577f7c1b83aea0b1a15391ff252c0a

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
4e2926d4e86a   postgres   "docker-entrypoint.s…"   5 seconds ago   Up 4 seconds   5432/tcp   mypostgre
```

```shell
root@4e2926d4e86a:/# psql -U postgres
psql (18.1 (Debian 18.1-1.pgdg13+2))
Type "help" for help.

# 2.2절과 동일하게 user01 생성
postgres=# create user user01 password '1234' superuser;
CREATE ROLE

# 사용자가 생성되었는지 확인
postgres=# \du
                             List of roles
 Role name |                         Attributes
-----------+------------------------------------------------------------
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS
 user01    | Superuser

postgres=# \q
```

```shell
root@4e2926d4e86a:/# cd /var/lib/postgresql

root@4e2926d4e86a:/var/lib/postgresql# ls
18

root@4e2926d4e86a:/var/lib/postgresql# exit
exit
```

`ls`의 출력 결과로 나오는 파일들이 도커 볼륨에 저장될 예정이다.

---

### 2.3.3. 컨테이너 삭제 후 데이터 확인

이제 이 컨테이너를 삭제한 뒤, 새로운 컨테이너에 동일한 볼륨을 연결하여 데이터가 보존되었는지 확인해보자.

```shell
# 컨테이너 정지 및 삭제
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
4e2926d4e86a   postgres   "docker-entrypoint.s…"   5 minutes ago   Up 5 minutes   5432/tcp   mypostgre

assu@myserver01:~$ docker stop 4e2926d4e86a
4e2926d4e86a

assu@myserver01:~$ docker rm 4e2926d4e86a
4e2926d4e86a

# 동일한 볼륨(myvolume01)을 마운트하여 새 컨테이너 실행
assu@myserver01:~$ docker container run --name mypostgre -e POSTGRES_PASSWORD=mysecretpassword \
--mount type=volume,source=myvolume01,target=/var/lib/postgresql -d postgres
b82b2f7f6d69623f6b45f34629a35bafc0fec19eb2d2e28d4ef259580576a6cf

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
b82b2f7f6d69   postgres   "docker-entrypoint.s…"   4 seconds ago   Up 3 seconds   5432/tcp   mypostgre

# 새로 생성된 컨테이너(b82b...)에 접속
assu@myserver01:~$ docker exec -it b82b2f7f6d69 /bin/bash

root@b82b2f7f6d69:/# psql -U postgres
psql (18.1 (Debian 18.1-1.pgdg13+2))
Type "help" for help.

# 사용자 목록 조회 시 user01 이 그대로 존재하는 것을 확인할 수 있다.
postgres=# \du
                             List of roles
 Role name |                         Attributes
-----------+------------------------------------------------------------
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS
 user01    | Superuser

postgres=# \q
root@b82b2f7f6d69:/# exit
exit
```

기존 컨테이너는 삭제되었지만, 데이터는 myvolume01 볼륨에 안전하게 보관되었다.  
새로 생성된 컨테이너가 동일한 볼륨에 연결되자, 이전에 생성했던 user01 의 정보를 그대로 읽어오는 것을 확인할 수 있다.

---

### 2.3.4. `volume`의 실제 위치 확인: `inspect`

`docker volume inspect` 명령어를 사용하면 이 볼륨이 호스트의 어느 경로에 데이터를 저장하는지 확인할 수 있다.

```shell
assu@myserver01:~$ docker volume inspect myvolume01
[
    {
        "CreatedAt": "2025-11-17T08:05:40Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/myvolume01/_data",
        "Name": "myvolume01",
        "Options": null,
        "Scope": "local"
    }
]
```

Mountpoint 가 이 볼륨이 실제 데이터를 보관하는 **도커 호스트의 경로**이다.

해당 경로로 이동해보면 PostgreSQL이 생성한 데이터 파일들이 호스트의 파일 시스템에 저장되어 있는 것을 확인할 수 있다.

```shell
assu@myserver01:~$ sudo -i
root@myserver01:~# cd /var/lib/docker/volumes/myvolume01/_data
root@myserver01:/var/lib/docker/volumes/myvolume01/_data# ls
```

![volume](/assets/img/dev/2025/1116/volume.png)

이제 컨테이너를 중지시킨다.

```shell
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
b82b2f7f6d69   postgres   "docker-entrypoint.s…"   8 minutes ago   Up 8 minutes   5432/tcp   mypostgre

assu@myserver01:~$ docker container stop mypostgre
mypostgre
```

---

## 2.4. `bind mount`: 호스트 경로 직접 공유

`bind mount`는 도커가 관리하는 `volume mount`와 달리, **사용자가 지정한 도커 호스트의 특정 디렉터리**를 컨테이너의 디렉터리와 직접 연결하는 방식이다.

이 방식은 소스 코드를 호스트에서 수정하면 컨테이너에 즉시 반영되므로, **개발 환경을 구축할 때 유용**하게 사용된다.

---

### 2.4.1. 호스트와 컨테이너 간 양방향 동기화 확인

여기서는 2개의 터미널을 사용하여 호스트와 컨테이너 간의 파일 동기화를 실시간으로 확인해본다.
- 터미널 1: 컨테이너 실행 및 내부 작업
- 터미널 2: 호스트에서 파일 확인 및 삭제

---

**터미널 1: 호스트 준비 및 컨테이너 실행**

먼저 호스트의 실습 디렉터리를 확인한다. 여기에는 test01.txt와 test02.txt 2개의 파일이 존재한다.
```shell
# 호스트 경로 확인
assu@myserver01:~/work/ch04/ex01$ pwd
/home/assu/work/ch04/ex01

# 2개의 파일 존재
assu@myserver01:~/work/ch04/ex01$ ls
test01.txt  test02.txt
```

이제 `bind` 타입으로 마운트하여 컨테이너를 실행한다.
```shell
# --mount type=bind 옵션 사용
# source: 호스트의 절대 경로(/home/assu/work/ch04/ex01)
# target: 컨테이너 내부 경로(/work)
assu@myserver01:~/work/ch04/ex01$ docker container run \
-e POSTGRES_PASSWORD=mysecretpassword \
--mount type=bind,source=/home/assu/work/ch04/ex01,target=/work -d postgres
e66792e3b5e1ed3ce7dc1eddcea5dd07d3f7c23f8915d40c7508c4190a23e376

# 컨테이너 동작 확인
assu@myserver01:~/work/ch04/ex01$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS          PORTS      NAMES
e66792e3b5e1   postgres   "docker-entrypoint.s…"   11 seconds ago   Up 11 seconds   5432/tcp   hungry_hugle

# 실행 중인 컨테이너 내부에 접속
assu@myserver01:~/work/ch04/ex01$ docker container exec -it e66792e3b5e1 /bin/bash

# 컨테이너 내부의 /work 디렉터리 확인
root@e66792e3b5e1:/# ls
bin  boot  dev	docker-entrypoint-initdb.d  etc  home  lib  media  mnt	opt  proc  root  run  sbin  srv  sys  tmp  usr	var  work

root@e66792e3b5e1:/# cd work

# /home/assu/work/ch04/ex01처럼 2개의 파일이 존재하는 것을 확인
root@e66792e3b5e1:/work# ls
test01.txt  test02.txt
```

![bind mount](/assets/img/dev/2025/1116/bind.png)

---

### 2.4.2. 동기화 테스트 1: 컨테이너에서 생성 후 호스트에서 확인

컨테이너 내부에서 test_dir 디렉터리를 생성해본다.

터미널 1(컨테이너 내부)
```shell
root@e66792e3b5e1:/work# mkdir test_dir

root@e66792e3b5e1:/work# ls
test01.txt  test02.txt  test_dir
```

이제 터미널 2(호스트)에서 해당 디렉터리가 생성되었는지 확인한다.

터미널 2(호스트)
```shell
# 위에서 만든 test_dir 확인
assu@myserver01:~/work/ch04/ex01$ ls
test01.txt  test02.txt  test_dir
```

---

### 2.4.3. 동기화 테스트 2: 호스트에서 삭제 후 컨테이너에서 확인

이번엔 호스트에서 test_dir 을 삭제해본다.

터미널 2(호스트)
```shell
assu@myserver01:~/work/ch04/ex01$ rm -rf test_dir

assu@myserver01:~/work/ch04/ex01$ ls
test01.txt  test02.txt
```

터미널 1(컨테이너 내부)

```shell
# 위에서 삭제한 test_dir 폴더가 사라진 것을 확인
root@e66792e3b5e1:/work# ls
test01.txt  test02.txt
```

호스트에서의 변경 사항이 컨테이너에도 즉시 반영되어 test_dir 디렉터리가 사라진 것을 확인할 수 있다.  
이처럼 `bind mount`는 호스트와 컨테이너가 파일 시스템을 완벽하게 공유한다.

```shell
root@e66792e3b5e1:/work# exit
exit

assu@myserver01:~/work/ch04/ex01$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
e66792e3b5e1   postgres   "docker-entrypoint.s…"   4 minutes ago   Up 4 minutes   5432/tcp   hungry_hugle

assu@myserver01:~/work/ch04/ex01$ docker container stop e66792e3b5e1
e66792e3b5e1

assu@myserver01:~/work/ch04/ex01$ docker container ls
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

---

## 2.5. `tmpfs mount`: 메모리 기반의 임시 스토리지

`tmpfs mount`는 디스크가 아닌 **도커 호스트의 메모리(RAM)**에 데이터를 저장하는 방식이다.

- **특징**
  - 디스크 I/O가 발생하지 않아 속도가 매우 빠름
  - **휘발성**임. 컨테이너가 정지되거나 삭제되면 데이터도 즉시 사라짐
  - 기본적으로 컨테이너 간 데이터 공유 불가능
- **용도**
  - 보안상 디스크에 기록되면 안되는 민감한 정보를 일시적으로 저장할 때
  - 대량의 데이터를 고속으로 처리해야 하지만 영구 저장은 필요 없는 경우

`--mount` 옵션에서 `type=tmpfs`를 지정한다.  메모리에 저장되므로 호스트의 경로(source)를 지정할 필요가 없으며, 컨테이너 내부 경로(destination)만 지정한다.


```shell
# /var/lib/postgresql 경로를 메모리(tmpfs)에 마운트
assu@myserver01:~$ docker container run \
> -e POSTGRES_PASSWORD=mysecretpassword \
> --mount type=tmpfs,destination=/var/lib/postgresql \
> -d postgres

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS          PORTS      NAMES
ac0ff0268a77   postgres   "docker-entrypoint.s…"   16 seconds ago   Up 15 seconds   5432/tcp   bold_ardinghelli

# inspect 명령어로 tmpfs 타입으로 마운트된 것을 확인
assu@myserver01:~$ docker inspect bold_ardinghelli --format ''
[
    {
        "Id": "ac0ff0268a77c4c1cfac0f7db605efeb2bb3edfcc495e640c5b345a5a56e189a",
        "Created": "2025-11-22T01:52:45.461475807Z",
        "Path": "docker-entrypoint.sh",
        "Args": [
            "postgres"
        ],
        // ...
        "Mounts": [
            {
                "Type": "tmpfs",
                "Source": "",
                "Destination": "/var/lib/postgresql",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
        // ...
    }
]

assu@myserver01:~$ docker inspect ac0ff0268a77 --format '{{json .Mounts}}'
[
    {
        "Type": "tmpfs",
        "Source": "",
        "Destination": "/var/lib/postgresql",
        "Mode": "",
        "RW": true,
        "Propagation": ""
    }
]

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE      COMMAND                  CREATED          STATUS          PORTS      NAMES
ac0ff0268a77   postgres   "docker-entrypoint.s…"   10 minutes ago   Up 10 minutes   5432/tcp   bold_ardinghelli

assu@myserver01:~$ docker container stop ac0ff0268a77
ac0ff0268a77

assu@myserver01:~$ docker container rm ac0ff0268a77
ac0ff0268a77

assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

이제 이 컨테이너를 정지(stop)하거나 삭제(rm)하면 메모리에 저장되어 있던 데이터는 모두 소멸된다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Docker hub](https://hub.docker.com/)