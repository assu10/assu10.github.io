---
layout: post
title:  "Docker - 도커 기초(1): 기초 명령어"
date: 2025-09-11 10:00:00
categories: dev
tags: devops docker 도커 도커-기초 도커-입문 도커-명령어 docker-cli 도커-이미지 docker-image 도커-컨테이너 docker-container docker-run docker-pull docker-commit docker-rm 데브옵스 컨테이너 가상화
---

이 포스트에서는 도커의 가장 기초적인 개념부터 실제 운영에 필수적인 요소까지 차근차근 알아본다.  
먼저 **도커 이미지**와 **컨테이너**가 무엇인지, 이들이 어떤 방식으로 상호작용하며 동작하는지 핵심 원리에 대해 알아본다.

기초 개념을 알아본 후에는 실습을 통해 필수적인 **도커 명령어**들을 익힌다.  
이미지를 다운로드하고, 컨테이너를 실행, 조회, 접속, 삭제하는 모든 과정을 직접 해본다.

---

**목차**

<!-- TOC -->
* [1. 도커 기초 개념](#1-도커-기초-개념)
  * [1.1. 도커 동작 방식](#11-도커-동작-방식)
  * [1.2. 도커 이미지](#12-도커-이미지)
  * [1.3. 도커 컨테이너](#13-도커-컨테이너)
  * [1.4. hello world 실행 과정 분석](#14-hello-world-실행-과정-분석)
* [2. 도커 기초 명령어](#2-도커-기초-명령어)
  * [2.1. 도커 이미지 다운로드(Pull)](#21-도커-이미지-다운로드pull)
  * [2.2. 도커 이미지 상세 구조](#22-도커-이미지-상세-구조)
  * [2.3. 도커 이미지 목록 확인: `ls`](#23-도커-이미지-목록-확인-ls)
  * [2.4. 도커 컨테이너 실행: `run`](#24-도커-컨테이너-실행-run)
  * [2.5. 도커 컨테이너 목록 확인: `ls`](#25-도커-컨테이너-목록-확인-ls)
  * [2.6. 컨네이너 내부 접속: `-it`](#26-컨네이너-내부-접속--it)
  * [2.7. 컨테이너 삭제: `rm`](#27-컨테이너-삭제-rm)
  * [2.8. 이미지 삭제: `rmi`](#28-이미지-삭제-rmi)
  * [2.9. 도커 이미지 변경: `commit`](#29-도커-이미지-변경-commit)
  * [2.10. 도커 이미지 명령어 모음](#210-도커-이미지-명령어-모음)
  * [2.11. 도커 컨테이너 명령어 모음](#211-도커-컨테이너-명령어-모음)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 도커 기초 개념

여기서는 도커 명령어가 어떻게 실행되는지 그 내부 동작을 살펴보고, 도커의 가장 중요한 구성 요소인 **이미지(Image)**와 **컨테이너(Container)**의 개념에 대해 알아본다.  
또한, 가장 기본적인 _hello-world_ 예제를 통해 이 모든 요소가 어떻게 상호작용하는지 알아본다.

---

## 1.1. 도커 동작 방식

이전 포스트인 [3. hello-world: 첫 컨테이너 실행](https://assu10.github.io/dev/2025/09/10/docker-install-guide-on-ubuntu-vm/#3-hello-world-%EC%B2%AB-%EC%BB%A8%ED%85%8C%EC%9D%B4%EB%84%88-%EC%8B%A4%ED%96%89) 에서 
도커 설치 후 `docker run hello world` 명령으로 첫 컨테이너를 실행했었다.  
이 간단한 명령어 뒤에서는 어떤 일들이 벌어지고 있었을까?  
도커의 전체적인 아키텍처를 통해 그 작동 원리에 대해 알아보자.

도커는 크게 **도커 클라이언트(Docker Client)**, **도커 호스트(Docker Host)**, **도커 레지스트리(Docker Registry)** 라는 세 가지 핵심 요소로 구성된다.

![도커 전체 구조](/assets/img/dev/2025/0911/docker.png)

- **도커 클라이언트(Docker Client)**
  - 사용자와 도커가 상호작용하기 위해 사용하는 주된 인터페이스
  - 터미널에 입력하는 `docker`로 시작하는 모든 명령어가 바로 도커 클라이언트를 통해 전달됨
  - 이 CLI 도구를 통해 이미지, 컨테이너, 네트워크, 볼륨 등 도커의 모든 요소를 관리할 수 있음
- **도커 호스트(Docker Host)**
  - 도커가 설치된 물리 서버나 가상 머신(VM), 이곳에서 실제 컨테이너가 생성되고 실행됨
  - 도커 호스트 내부에는 **도커 데몬(Docker Daemon)**이라는 핵심 프로세스가 백그라운드에서 항상 실행 중임
  - 이 데몬은 클라이언트로부터 받은 명령을 해석하고, 이미지 생성, 컨네이너 실행 등 실제 작업을 총괄함
- **도커 레지스트리(Docker Registry)**
  - 도커 이미지를 저장하고 공유하는 원격 저장소
  - 공개(public)와 개인(private) 레지스트리로 나눌 수 있음
  - 가장 대표적인 공개 레지스트리는 [**도커 허브(Docker Hub)**](https://hub.docker.com/)임
  - 전 세계 개발자들이 만든 수많은 공식 이미지가 저장되어 있어, 누구나 필요한 이미지를 내려받거나 자신이 만든 이미지를 업로드하여 공유 가능함

![도커 상세 구조](/assets/img/dev/2025/0911/docker_detail.png)

이 세 가지 요소를 바탕으로 `docker run` 명령어의 흐름을 정리하면 아래와 같다.

1. 사용자가 **도커 클라이언트**에 `docker run hello-world` 명령어를 입력한다.
2. 도커 클라이언트는 이 명령을 **도커 호스트**의 **도커 데몬**에게 전달한다.
3. 도커 데몬은 로컬 환경에서 _hello-world_ 이미지가 있는지 확인한다.
4. 만약 이미지가 없다면, 원격 **도커 레지스트리**(기본값은 도커 허브)에서 _hello-world_ 이미지를 검색하여 다운로드한다.
5. 다운로드한 이미지를 기반으로 새로운 컨테이너를 생성하고 실행한다.

---

## 1.2. 도커 이미지

도커 이미지를 한마디로 정의하면 **소프트웨어를 실행하는데 필요한 모든 것을 담은 실행 가능한 패키지**이다.  
애플리케이션 코드, 런타임, 라이브러리, 환경 변수, 설정 파일 등 필요한 모든 요소를 하나의 파일로 압축해 놓은 것이다.

도커 이미지만 있으면 어떤 환경에서든 동일한 컨테이너를 생성할 수 있다.

- **독립성(Self-contained)**
  - 도커 이미지는 애플리케이션 실행에 필요한 모든 의존성을 포함하고 있어서 '내 PC 에서는 됐는데..'와 같은 환경 문제를 해결해준다.
- **경량성(Lightweight)**
  - 도커 이미지는 여러 개의 읽기 전용 레이어로 구성된다. 중복되는 부분은 공유하여 전체 용량을 최소화하므로 매우 효율적이다.
- **불변성(Immutable)**
  - 이미지는 한 번 생성되면 그 내용이 변하지 않는 스냅숏과 같다. 덕분에 배포의 일관성과 신뢰성을 보장한다.

이러한 도커 이미지들은 도커 허브와 같은 중앙 레지스트리에 저장되고, 버전별로 관리되어 손쉽게 공유하고 배포할 수 있다.

---

## 1.3. 도커 컨테이너

**도커 컨테이너는 도커 이미지를 실행할 수 있는 인스턴스**이다.  
하나의 도커 이미지로 수많은 컨테이너를 생성할 수 있으며, 각 컨테이너는 독립된 공간에서 실행, 중지, 재시작, 삭제될 수 있다.

각 컨테이너는 격리된 자체 파일 시스템을 가지며 독립적으로 실행된다.  
'독립된 공간에서 운영체제처럼 동작한다면 가상머신처럼 무겁지 않을까?' 라는 의문이 들 수 있다.  
하지만 도커 컨테이너는 매우 가볍다. 그 비밀은 바로 **호스트 운영체제의 커널을 공유**하는데 있다.

<**컨테이너와 가상머신의 구조적 차이**>  
가상머신은 하드웨어를 가상화하고 그 위에 게스트 OS를 통째로 설치하는 방식이라 무겁고 부팅 시간도 길다.  
반면, **컨테이너는 도커 엔진 위에서 호스트 OS의 커널을 직접 사용**한다. (= 도커 엔진이 설치되어 있는 호스트 OS 이용)  
컨테이너 내부에는 애플리케이션을 실행하는데 필요한 최소한의 바이너리와 라이브러리만 들어있을 뿐, OS 전체가 포함되어 있지 않기 때문에 빠르고 가볍다.

---

## 1.4. hello world 실행 과정 분석

[3. hello-world: 첫 컨테이너 실행](https://assu10.github.io/dev/2025/09/10/docker-install-guide-on-ubuntu-vm/#3-hello-world-%EC%B2%AB-%EC%BB%A8%ED%85%8C%EC%9D%B4%EB%84%88-%EC%8B%A4%ED%96%89) 에서 
`docker run hello-world` 를 입력하여 도커가 올바르게 동작하는지 테스트해보았다.

`docker run hello-world` 명령을 실행했을 때 터미널에 나타난 메시지를 분석해보자.  
이 과정을 이해하면 도커의 동작 원리를 파악할 수 있다.

```shell
$ ssh assu@128.0.0.1

assu@myserver01:~$ docker run hello-world

# 1. 로컬 이미지 검색
Unable to find image 'hello-world:latest' locally
# -> 'hello-world' 이미지가 로컬(내 PC)에 없음을 확인합니다.

# 2. 원격 레지스트리에서 이미지 다운로드 (Pull)
latest: Pulling from library/hello-world
# -> 도커 허브의 공식 라이브러리에서 이미지를 가져옵니다.
198f93fd5094: Pull complete
# -> 이미지 레이어 다운로드가 완료되었습니다.

# 3. 다운로드 완료 및 무결성 검증
Digest: sha256:54e66cc1dd1fcb1c3c58bd8017914dbed8701e2d8c74d9262e26bd9cc1642d31
# -> 다운로드한 이미지의 고유 식별 해시값(Digest)입니다. 데이터 무결성을 보장합니다. Digest 는 해시 함수를 거쳐 나온 후의 데이터를 의미함
Status: Downloaded newer image for hello-world:latest
# -> 최신 버전의 'hello-world' 이미지 다운로드가 최종 완료되었음을 알립니다.

# 4. 컨테이너 실행 및 결과 출력
Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.
...
```

hello-world 컨테이너가 출력한 4단계 설명은 [1.1. 도커 동작 방식](#11-도커-동작-방식) 에서 본 동작 방식과 정확히 일치한다.

1. 클라이언트가 데몬에게 요청(`docker run`)
2. 데몬이 도커 허브에서 이미지 다운로드(`pull`)
3. 데몬이 이미지로부터 새 컨테이너를 생성 및 실행(`create` & `run`)
4. 데몬이 컨테이너의 출력 결과를 클라이언트로 전송하여 터미널에 표시

---

# 2. 도커 기초 명령어

위에서 도커의 핵심 개념과 동작 원리에 대해 알아보았다.  
여기서는 직접 명령어를 입력하여 도커를 다뤄본다. 도커 이미지를 내려받고, 확인하며, 그 내부 구조에 대해 알아보는 가장 기본적인 명령어부터 시작한다.

---

## 2.1. 도커 이미지 다운로드(Pull)

도커 컨테이너를 실행하려면 가장 먼저 그 기반이 되는 도커 이미지가 필요하다.  
원격 레지스트리(기본적으로 도커 허브)에 저장된 이미지를 내 로컬 환경으로 가져오는 명령어는 `docker image pull` 이다.

아리 그램은 도커 허브에서 Nignx 이미지를 다운로드하는 과정이다.
![도커 이미지 다운로드 과정](/assets/img/dev/2025/0911/docker_download.png)

명령어의 기본 형식은 `docker image pull [이미지 이름]:[태그]` 이다. 태그는 보통 이미지의 버전을 나타내며, 생략할 경우 기본값인 `latest` 가 자동으로 적용된다.

먼저 공식 ubuntu 이미지를 다운로드해보자.

```shell
# 'ubuntu' 이미지를 다운로드합니다.
assu@myserver01:~$ docker image pull ubuntu

# 태그를 지정하지 않았으므로 'latest'가 기본값으로 사용됩니다.
Using default tag: latest
# 도커 허브의 공식 라이브러리에서 이미지를 가져옵니다.
latest: Pulling from library/ubuntu
# 이미지 레이어 다운로드가 완료되었습니다.
# 'Pull complete'가 한 번만 나타나는 것으로 보아, 이 이미지는 단일 레이어로 구성되어 있음을 추측할 수 있습니다.
59a5d47f84c3: Pull complete
# 다운로드한 이미지 콘텐츠의 고유 식별자인 Digest 값입니다.
Digest: sha256:353675e2a41babd526e2b837d7ec780c2a05bca0164f7ea5dbbd433d21d166fc
# 다운로드 상태를 요약하여 보여줍니다.
Status: Downloaded newer image for ubuntu:latest
# 다운로드한 이미지의 전체 주소입니다.
docker.io/library/ubuntu:latest
```

결과에서 Digest 값을 사용해서도 특정 이미지를 정확하게 다운로드할 수 있다.  
형식은 `docker image pull [이미지 이름]@[Digest]` 이다.

```shell
# 위에서 확인한 Digest 값으로 동일한 ubuntu 이미지를 다운로드합니다.
docker image pull ubuntu@sha256:353675e2a41babd526e2b837d7ec780c2a05bca0164f7ea5dbbd433d21d166fc
```

이번에는 여러 개의 레이어로 구성된 python 이미지를 특정 태그(3.13.7)로 다운로드해보자.

```shell
assu@myserver01:~$ docker image pull python:3.13.7

3.13.7: Pulling from library/python
# 여러 개의 'Pull complete' 메시지는 이미지가 다수의 레이어로 구성되어 있음을 의미합니다.
37b49b813d9c: Pull complete
5bd36c08acb8: Pull complete
02fd600967e6: Pull complete
739133f1214d: Pull complete
68a1debaf428: Pull complete
be6827a2c896: Pull complete
d5606296ed56: Pull complete
# 이 모든 레이어를 포함하는 이미지의 최종 Digest 값입니다.
Digest: sha256:2deb0891ec3f643b1d342f04cc22154e6b6a76b41044791b537093fae00b6884
Status: Downloaded newer image for python:3.13.7
docker.io/library/python:3.13.7
```

![도커 이미지 구조](/assets/img/dev/2025/0911/image.png)

---

## 2.2. 도커 이미지 상세 구조

방금 다운로드한 python:3.13.7 이미지의 출력 결과를 보면 여러 개의 해시값과 최종 Digest 값이 있다.  
이것들은 무엇을 의미할까?

도커 이미지의 내부 구조를 통해 알아보자.

![이미지 상세 구조: 인덱스, 매니페스트, 레이어](/assets/img/dev/2025/0911/image_detail.png)

도커 이미지는 크게 이미지 인덱스(Image Index), 이미지 매니페스트(Image Manifest), 레이어(Layer) 3가지 요소로 구성된다.

- **이미지 인덱스(Image Index)**
  - `docker image pull` 명령 실행 시 출력되는 최종 Digest 값이 바로 이미지 인덱스의 식별자이다.
  - 이 인덱스는 다양한 OS 와 아키텍처(e.g., amd64, arm64)를 지원하기 위해 여러 개의 이미지 매니페스트 목록을 가지고 있다.
- **이미지 매니페스트(Image Manifest)**
  - 특정 OS/아키텍처에 맞는 이미지의 상세 정보를 담고 있는 JSON 형식의 파일이다.
  - 이미지 설정 정보와 함께, 해당 이미지를 구성하는 각 레이어들의 Digest 목록을 포함하고 있다.
  - [도커 허브의 python:3.13.7 이미지 정보](https://hub.docker.com/layers/library/python/3.13.7/images/sha256-9f6629a0ec6b3b543fe94036f50bcc6868f2de7ee0b11aed1c0c7c3c9aa60555) 페이지에서 OS/ARCH 별 매니페스트 정보를 확인할 수 있다.
- **레이어(Layer)**
  - 이미지의 가장 기본적인 빌딩 블록이다. 파일 시스템의 변경 사항을 담고 있으며, 각 레이어는 고유한 Digest 값을 가진다.
  - `docker image pull` 시 여러 줄로 나타났던 `Pull complete` 메시지가 바로 이 레이어들을 하나씩 다운로드하는 과정이다.

![도커 허브에 표시된 linux/arm64 아키텍처용 이미지 매니페스트 정보](/assets/img/dev/2025/0911/dockerhub_image.png)


![python:3.13.7 이미지의 인덱스-매니페스트-레이어 관계](/assets/img/dev/2025/0911/python.png)

결론적으로 `docker image pull` 명령으로 이미지를 다운로드할 때 도커 데몬은 현재 내 PC 의 OS/아키텍처에 맞는 **이미지 매니페스트**를 **이미지 인덱스**에서 찾아, 
해당 매니페스트에 명시된 **레이어**들을 순서대로 내려받는다.

---

## 2.3. 도커 이미지 목록 확인: `ls`

위에서 `pull` 명령어로 내려받은 이미지들이 로컬 스토리지에 잘 저장되었는지 확인해보자.  
`docker image ls` 로 로컬에 다운로드된 이미지의 목록을 확인할 수 있다.

```shell
assu@myserver01:~$ docker image ls
REPOSITORY    TAG       IMAGE ID       CREATED        SIZE
ubuntu        latest    f4158f3f9981   2 months ago   101MB
python        3.13.7    ce75f3f8bdaf   2 months ago   1.12GB
hello-world   latest    ca9905c726f0   3 months ago   5.2kB
```

- **REPOSITORY**
  - 이미지의 이름이다.
- **TAG**
  - 이미지의 버전 정보이다.
- **IMAGE ID**
  - 로컬환경에서 해당 이미지를 식별하는 고유 ID 이다.
  - 다운로드할 때의 DIGEST 값과 다른데, 이는 다운로드할 때의 DIGEST 값은 도커 레지스트리에 존재하는 이미지의 DIGEST 값이고, `docker image ls` 의 결과값으로 나오는 IMAGE ID 값은 다운로드한 후에 로컬에서 할당받은 IMAGE ID 값이기 때문ㄴ이다.
- **CREATED**
  - 이미지가 생성된 시점이다.
- **SIZE**
  - 이미지의 용량이다.

여기서 IMAGE ID(f4158f3f9981) 과 [2.1. 도커 이미지 다운로드(Pull)](#21-도커-이미지-다운로드pull)에서 이미지를 다운로드할 때 본 DIGEST(sha256:353675e2...) 값은 서로 다른다.  
DIGEST 는 도커 레지스트리(허브)에서 이미지를 식별하는 전역 고유값으로 이미지 콘텐츠 자체의 해시값이라 불변성을 보장한다.  
IMAGE ID는 로컬 도커 호스트(내 PC)에 다운로드된 이미지를 관리하기 위해 할당된 로컬 식별자이다.

---

## 2.4. 도커 컨테이너 실행: `run`

이미지를 준비했으니 이제 이 이미지를 바탕으로 컨테이너를 실행해본다.  
`docker container run` 명령어를 이미지를 기반으로 컨테이너를 생성하고 실행하는 가장 기본적인 명령어이다.

![도커 컨테이너 run](/assets/img/dev/2025/0911/docker_run.png)

`docker container run` 명령은 아래와 같은 과정을 거친다.
- 로컬에 지정된 이미지가 있는지 확인한다.
- 이미지가 없다면 레지스트리에서 `pull` 명령어를 실행하여 이미지를 다운로드 한다. ([2.1. 도커 이미지 다운로드(Pull)](#21-도커-이미지-다운로드pull) 참고)
- 해당 이미지를 기반으로 새로운 컨테이너를 생성한다.
- 컨테이너를 실행한다.

앞서 다운로드한 우분투 이미지를 실행해보자.
```shell
assu@myserver01:~$ docker container run ubuntu
assu@myserver01:~$
```

> 도커 초기 버전에서는 `docker run [이미지 이름]` 처럼 `container` 하위 명령 없이 사용했다.  
> 지금도 호환성을 위해 작동하지만, 도커는 이미지 관련 명령어는 `docker image ...`로, 컨테이너 관련 명령어를 `docker container run [이미지 이름]` 로 명확히 구분하여 사용하는 것을 권장한다.

우분투 이미지를 실행했지만 터미널에는 아무런 변화없이 바로 프롬프트가 다시 나타났다.  
`hello-world` 와 달리 특별한 출력 메시지가 없는데, 컨테이너가 제대로 실행된 것인지는 [2.6. 컨네이너 내부 접속: `-it`](#26-컨네이너-내부-접속--it)에서 확인해 볼 것이다.

---

## 2.5. 도커 컨테이너 목록 확인: `ls`

위에서 실행한 우분투 컨테이너를 포함하여 내 도커 호스트에 존재하는 컨테이너들의 목록을 확인해보자.  
`docker container ls` 로 확인해본다.

```shell
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

방금 실행한 우분투 컨테이너가 목록에 보이지 않는다.  
`docker container ls` 명령어의 기본 동작은 **현재 실행 중(Up)**인 컨테이너만 보여준다.

정지된 컨테이너까지 모두 확인하려면 `-a`(all) 옵션을 추가해야 한다.

```shell
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE         COMMAND       CREATED       STATUS                   PORTS     NAMES
b8020ee3aa76   ubuntu        "/bin/bash"   5 days ago    Exited (0) 5 days ago              trusting_merkle
95119949e19f   hello-world   "/hello"      7 weeks ago   Exited (0) 7 weeks ago             vibrant_agnesi
```

- **CONTAINER ID**
  - 하나의 이미지로 여러 컨테이너를 만들 수 있으므로, 각 컨테이너를 식별하기 위한 고유 ID 이다.
- **STATUS**
  - 컨테이너의 현재 상태이다.
  - hello-world 와 ubuntu 모두 Exited (0) 상태이다.
  - Exited 는 컨테이너가 종료되었다는 뜻이고, 숫자 0은 정상적으로 종료되었다는 뜻이다.

Exited (0)은 컨테이너가 실행은 되었지만, **정상적으로 종료(Exit Code 0)** 되었음을 의미한다.

그렇다면 우분투 컨테이너는 왜 실행하자마자 바로 종료되었을까?  
**컨테이너가 바로 종료되는 이유**는 내부에 실행 중인 **포그라운드(foreground) 프로세스가 하나라도 있어야 유지**된다.  
우분투 이미지는 기본적으로 /bin/bash 셸을 실행하도록 설정되어 있지만, 우리가 별도의 명령을 내리지 않았기 때문에 셸이 실행되자마자 할 일이 없어서 바로 종료된 것이다.  
이와 동시에 이 셸 프로세스르 붙잡고 있던 컨테이너도 함께 종료된 것이다.

hello-world 역시 "Hello from Docker!" 메시지를 출력하는 `/hello` 프로세스를 실행한 뒤, 임무를 완수하고 정상 종료(Exited 0)된 것이다.

---

## 2.6. 컨네이너 내부 접속: `-it`

[2.4. 도커 컨테이너 실행: `run`](#24-도커-컨테이너-실행-run) 에서 `docker container run ubuntu`를 실행했을 때, 컨테이너가 즉시 Exited 상태가 되는 것을 확인했다.  
컨테이너가 셸(bash)를 실행할 임무는 완수했지만, 우리가 셸에 아무런 명령도 입력하지 않아 할 일이 없었기 때문이다.

컨테이너를 종료하지 않고, 내부 셸에 직접 접속하여 상호작용하려면 `-it` 옵션을 사용해야 한다.
- `-i`(interactive)
  - 표준 입력(STDIN)을 활성화한다.(컨테이너에 키보드 입력을 전달)
- `-t`(tty)
  - 가상 터미널(pseudo-TTY)을 할당한다.(우리가 보는 터미널 화면처럼 만들어줌)

이제 새로운 터미널을 열고(터미널 1), `-it` 옵션으로 우분투 컨테이너를 실행해본다.

터미널 1: 컨테이너 실행 및 접속
```shell
assu@myserver01:~$ docker container run -it ubuntu
root@d48c11facf7b:/#
```

명령을 실행하자마자 프롬프트가 `assu@myserver01:~$` 에서 `root@d48c11facf7b:/#` 로 바뀌었다.  
이는 우리가 호스트(myserver01)를 떠나서, **컨테이너(ID: d48c11facf7b) 내부에 `root` 사용자로 접속**했음을 의미한다.

이 상태를 확인하기 위해 새로운 터미널(터미널 2)을 열어서 `docker container ls`를 실행해보자.

터미널 2: 컨테이너 상태 확인
```shell
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE     COMMAND       CREATED         STATUS         PORTS     NAMES
d48c11facf7b   ubuntu    "/bin/bash"   3 minutes ago   Up 2 minutes             wizardly_lovelace
```

`ls -a` 옵션 없이도 컨테이너가 조회된다. STATUS가 Exited가 아닌 **Up**으로 표시되는 것을 볼 수 있다.  
현재 터미널 1에서 bash 셸이 실행 중(Up 2 minutes)이며, 우리가 접속을 유지하고 있기 때문이다.

---

이 컨테이너를 종료하는 방법을 2가지이다.

1. 터미널 1 컨테이너 내부에서 `exit` 명령어를 입력하여 셸을 종료(컨테이너 밖으로 나감)
2. 터미널 2 호스트에서 `docker container stop [컨테이너 ID]` 명령어로 강제 종료

여기서는 두 번째 방법으로 종료한다.

터미널 2
```shell
assu@myserver01:~$ docker container stop d48c11facf7b
d48c11facf7b
```

`docker container stop [컨테이너 ID]` 을 입력하면 약 10초 후에 터미널 1의 프롬프트가 자동으로 닫히고, 컨테이너가 종료된다.

> **`docker contaiiner stop [컨테이너 ID]` vs `docker container kill [컨테이너 ID]`**
> 
> - `stop`: 컨테이너에 SIGTERM 신호를 보내고, 컨테이너를 약 10초간 작업을 정리할 시간을 갖는다.
> - `kill`: SIGKILL 신호를 보내 즉시 종료시킨다.

---

**종료된 컨테이너에 다시 접속하기**

`stop`으로 중지된 컨테이너는 삭제된 것이 아니라 Exited 상태로 남아있다.  
`run`으로 새 컨테이너를 마드는 대신, 이 컨테이너를 다시 시작(`start`)하여 접속(`attach`)할 수 있다.

```shell
# 중지된 컨테이너를 다시 시작
assu@myserver01:~$ docker container start d48c11facf7b
d48c11facf7b

# 실행 중인 상태(Up)인지 혹인
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE     COMMAND       CREATED         STATUS         PORTS     NAMES
d48c11facf7b   ubuntu    "/bin/bash"   9 minutes ago   Up 7 seconds             wizardly_lovelace

# 실행 중인 컨테이너에 다시 접속
assu@myserver01:~$ docker container attach d48c11facf7b

# exit 로 접속 종료(컨테이너도 다시 Exited 상태가 됨)
root@d48c11facf7b:/# exit
exit
assu@myserver01:~$
```

---

## 2.7. 컨테이너 삭제: `rm`

더 이상 사용하지 않는 Exited 상태의 컨테이너들은 디스크 공간을 차지하므로 정리해주는 것이 좋다.  
`docker container rm [컨테이너 ID]` 명령어로 컨테이너를 삭제할 수 있다.

```shell
# 중지된 컨테이너를 포함한 전체 목록 확인
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE         COMMAND       CREATED          STATUS                      PORTS     NAMES
d48c11facf7b   ubuntu        "/bin/bash"   14 minutes ago   Exited (0) 58 seconds ago             wizardly_lovelace
b8020ee3aa76   ubuntu        "/bin/bash"   5 days ago       Exited (0) 5 days ago                 trusting_merkle
95119949e19f   hello-world   "/hello"      7 weeks ago      Exited (0) 7 weeks ago                vibrant_agnesi

# 특정 컨테이너(b8020ee3aa76) 삭제
assu@myserver01:~$ docker container rm b8020ee3aa76
b8020ee3aa76

# 삭제 확인 (목록에서 사라짐)
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE         COMMAND       CREATED          STATUS                          PORTS     NAMES
d48c11facf7b   ubuntu        "/bin/bash"   14 minutes ago   Exited (0) About a minute ago             wizardly_lovelace
95119949e19f   hello-world   "/hello"      7 weeks ago      Exited (0) 7 weeks ago                    vibrant_agnesi
```

`docker container rm [ID 1] [ID 2]`처럼 여러 ID 를 공백으로 구분하여 한 번에 여러 컨테이너를 삭제할 수도 있다.

```shell
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE         COMMAND       CREATED          STATUS                          PORTS     NAMES
d48c11facf7b   ubuntu        "/bin/bash"   14 minutes ago   Exited (0) About a minute ago             wizardly_lovelace
95119949e19f   hello-world   "/hello"      7 weeks ago      Exited (0) 7 weeks ago                    vibrant_agnesi

# 나머지 컨테이너들도 한 번에 삭제
assu@myserver01:~$ docker container rm d48c11facf7b 95119949e19f
d48c11facf7b
95119949e19f

# 모든 컨테이너가 삭제됨
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
assu@myserver01:~$
```

`rm` 명령어는 **중지된(Exited) 컨테이너만 삭제**할 수 있다. 만일 실행 중인(Up) 컨테이너를 삭제하려고 하면 오류가 발생한다.  
이 경우 `docker container stop [ID]`로 먼저 중지해야 한다.

---

## 2.8. 이미지 삭제: `rmi`

`docker image rm [ID]` 혹은 `docker image rm [이름:태그]`로 이미지를 삭제할 수 있다.

```shell
# 현재 이미지 목록 확인
assu@myserver01:~$ docker image ls
REPOSITORY    TAG       IMAGE ID       CREATED        SIZE
ubuntu        latest    f4158f3f9981   2 months ago   101MB
python        3.13.7    ce75f3f8bdaf   3 months ago   1.12GB
hello-world   latest    ca9905c726f0   3 months ago   5.2kB

# hello-world 이미지 삭제 (IMAGE ID 사용)
assu@myserver01:~$ docker image rm ca9905c726f0
Untagged: hello-world:latest
Untagged: hello-world@sha256:54e66cc1dd1fcb1c3c58bd8017914dbed8701e2d8c74d9262e26bd9cc1642d31
Deleted: sha256:ca9905c726f06de3cb54aaa54d4d1eade5403594e3fbfb050ccc970fd0212983
Deleted: sha256:50163a6b11927e67829dd6ba5d5ba2b52fae0a17adb18c1967e24c13a62bfffa

# 삭제 확인 (목록에서 사라짐)
assu@myserver01:~$ docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
ubuntu       latest    f4158f3f9981   2 months ago   101MB
python       3.13.7    ce75f3f8bdaf   3 months ago   1.12GB
```

- **Untagged**
  - 이미지에 연결된 hello-world:latest 같은 태그를 제거한다.
- **Deleted**
  - 태그가 모두 제거된 이미지의 실제 데이터(레이어)를 디스크에서 삭제한다.

이미지를 삭제하려고 할 때, 해당 이미지를 기반으로 생성된 **컨테이너가 (중지 상태라도) 하나라도 남아있다면 이미지를 삭제되지 않고 오류가 발생**한다.  
이 경우 **반드시 `docker container rm` 으로 관련 컨테이너를 먼저 삭제**한 후, `docker image rm`으로 이미지를 삭제해야 한다.

---

## 2.9. 도커 이미지 변경: `commit`

> `commit`은 편리하지만, 이미지 생성 과정을 추적하기 어렵다는 단점이 있다.  
> 실무에서는 어떤 베이스 이미지에서 어떤 명령어가 실행되었는지 명확히 기록할 수 있는 **Dockerfile**을 사용하여 이미지를 빌드하는 방식(`docker image build`)이 표준으로 사용된다.  
> `commit`은 테스트나 임시 변경 사항을 저장할 때 유용하다.

지금까지는 도커 허브에 이미 완성되어 배포된 이미지를 다운로드해서 사용했다. 이번에는 기존 이미지를 기반으로 **내가 필요한 프로그램을 추가 설치**한 뒤, 그 변경 사항을 
저장하여 '나만의 커스텀 이미지'를 만들어본다.

`docker container commit` 명령어는 현재 실행 중인 컨테이너의 상태를 그대로 스냅숏으로 찍어 새로운 이미지로 생성해준다.

여기서는 ubuntu 이미지에 네트워크 상태를 확인하는 `net-tools`(ifconfig 명령어 포함)를 설치한 후, _my-ubuntu:0.1_이라는 새 이미지로 저장해본다.  
여기서는 2개의 터미널이 필요하다.

---

**터미널 1: 원본 컨테이너 실행 및 수정**

먼저 원본 ubuntu 이미지를 `-it` 옵션으로 실행하여 컨테이너 내부에 접속한다.

```shell
# 로컬 이미지 목록 확인
assu@myserver01:~$ docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
ubuntu       latest    f4158f3f9981   2 months ago   101MB
python       3.13.7    ce75f3f8bdaf   3 months ago   1.12GB

# -it 옵션을 사용해 우분투 컨테이너 실행 및 접속
assu@myserver01:~$ docker container run -it ubuntu
root@fce5aebdb10a:/#
```

기존 우분투 이미지에는 `ifconfig` 명령어가 없다. 확인해보면 _command not found_ 오류가 ㄱ발생한다.
```shell
# 컨테이너 내부 IP 를 확인하기 위해 ifconfig 를 입력해도 net-tools 가 미설치되어 있어서 확인 불가 
root@fce5aebdb10a:/# ifconfig
bash: ifconfig: command not found
```

이제 `apt` 명령어로 `net-tools` 패키지를 설치해준다.

```shell
# 패키지 목록 업데이트 및 net-tools 설치
root@fce5aebdb10a:/# apt update && apt install net-tools
Get:1 http://ports.ubuntu.com/ubuntu-ports noble InRelease [256 kB]
Get:2 http://ports.ubuntu.com/ubuntu-ports noble-updates InRelease [126 kB]
...
```

설치가 완료되면 다시 ifconfig 를 실행해본다.

```shell
# IP 주소 확인 (설치 성공)
root@fce5aebdb10a:/# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255  # 아이피가 172.17.0.2 인 것을 확인
        ether 26:2f:28:9a:84:79  txqueuelen 0  (Ethernet)
        RX packets 7887  bytes 37063895 (37.0 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4664  bytes 256547 (256.5 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

이제 이 컨테이너(fce5aebdb10a)는 `net-tools`가 설치된 상태가 되었다.  
**이 터미널은 `exit`로 빠져나가지 말고 그대로 둔 채** 새로운 터미널을 연다.

---

**터미널 2: 컨테이너를 이미지로 저장(Commit)**

새 터미널2(호스트 터미널)에서 현재 실행 중인 컨테이너를 확인한다.

```shell
$ ssh assu@127.0.0.1

# 실행 중인 컨테이너 확인 (터미널 1에서 실행 중인 컨테이너)
assu@myserver01:~$ docker container ls
CONTAINER ID   IMAGE     COMMAND       CREATED         STATUS         PORTS     NAMES
fce5aebdb10a   ubuntu    "/bin/bash"   5 minutes ago   Up 5 minutes             loving_chaplygin
```

이제 `docker container commit` 명령어를 사용해 net-tools 가 설치된 fce5aebdb10a 컨테이너를 _my-ubuntu:0.1_이라는 새로운 이미지로 저장한다.

명령어 형식: `docker container commit [실행 중인 컨테이너 ID] [새 이미지 이름]:[태그]`

기존 ubuntu 컨테이너에 net-tools를 설치한 컨테이너를 my-ubuntu 라는 새로운 이름의 이미지로 저장하고 0.1이라는 태그를 붙여줄 것이다.

터미널 2
```shell
# 'fce5aebdb10a' 컨테이너를 'my-ubuntu:0.1' 이미지로 생성
assu@myserver01:~$ docker container commit fce5aebdb10a my-ubuntu:0.1
sha256:3eb5806116ca8a55268bc42993120862fa0a62ec58a212441006b1970467ab64
```

새로운 이미지의 ID(sha256:3eb580611..)가 출력되며 생성이 완료되었다.

---

**터미널 1: 새 이미지 검증**

이제 터미널 1로 돌아와서 `commit` 작업의 기반이 되었던 원본 컨테이너를 정리하고, 새로 만든 이미지인 _my-ubuntu:0.1_이 잘 작동하는지 검증한다.

터미널 1
```shell
# 기존 컨테이너에서 빠져나옴
root@fce5aebdb10a:/# exit
exit

# 컨테이너가 Exited 상태가 됨
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE     COMMAND       CREATED          STATUS                      PORTS     NAMES
fce5aebdb10a   ubuntu    "/bin/bash"   14 minutes ago   Exited (0) 15 seconds ago             loving_chaplygin

# 기존 컨테이너 삭제
assu@myserver01:~$ docker container rm fce5aebdb10a
fce5aebdb10a

# 모든 컨테이너가 정리됨
assu@myserver01:~$ docker container ls -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

이제 새로 생성된 이미지를 `docker image ls`로 확인한다.

```shell
# 'my-ubuntu:0.1' 이미지가 생성된 것을 확인
assu@myserver01:~$ docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
my-ubuntu    0.1       3eb5806116ca   2 minutes ago   162MB
ubuntu       latest    f4158f3f9981   2 months ago    101MB
python       3.13.7    ce75f3f8bdaf   3 months ago    1.12GB
```

_my-ubuntu:0.1_ 이미지가 목록에 보인다. net-tools가 추가되어 원본 ubuntu(101MB)보다 용량(162MB)이 더 커진 것을 알 수 있다.

이제 **새로 만든 이미지를 실행**하여 ifconfig 가 별도 설치없이 바로 실행되는지 확인해본다.

```shell
# 새로 만든 'my-ubuntu:0.1' 이미지로 컨테이너 실행
assu@myserver01:~$ docker container run -it my-ubuntu:0.1

# 접속하자마자 'ifconfig' 실행
root@3f724b51317e:/# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255
        ether fa:3d:d7:76:fc:99  txqueuelen 0  (Ethernet)
        RX packets 7  bytes 646 (646.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 3  bytes 126 (126.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

`apt install` 과정 없이도 ifconfig 가 바로 실행되는 것을 확인할 수 있다.  
이것으로 나만의 커스텀 이미지 생성이 완료되었다.

```shell
# 검증 완료 후 컨테이너 종료
root@3f724b51317e:/# exit
exit
```

---

## 2.10. 도커 이미지 명령어 모음

아래는 자주 사용하는 도코 이미지 명령어들이다.

| 명령어                  | 설명                                      |
|:---------------------|:----------------------------------------|
| docker image build   | Dockerfile로부터 이미지 빌드                    |
| docker image history | 이미지 히스토리 확인                             |
| docker image import  | 파일 시스템 이미지 생성을 위한 타볼(tarball) 콘텐츠를 임포트함 |
| docker image inspect | 이미지 정보 표시                               |
| docker image load    | 타볼로 묶인 이미지를 로드함                         |
| docker image ls      | 이미지 목록 확인                               |
| docker image prune   | 사용하지 않는 이미지 삭제                          |
| docker image pull    | 레지스트리로부터 이미지 다운로드                       |
| docker image push    | 레지스트리에 이미지 업로드                          |
| docker image rm      | 하나 이상의 이미지 삭제                           |
| docker image save    | 이미지를 타볼로 저장                             |
| docker image tag     | 이미지 태그 생성                               |

---

## 2.11. 도커 컨테이너 명령어 모음

| 명령어                      | 설명                               |
|:-------------------------|:---------------------------------|
| docker container attach  | 실행 중인 컨테이너의 표준 입출력 스트림에 붙음       |
| docker container exec    | 실행 중인 컨테이너에 명령어를 실행              |
| docker container commit  | 변경된 컨테이너에 대한 새로운 이미지 생성          |
| docker container cp      | 컨테이너와 로컬 파일 시스템 간 파일/폴더 복사       |
| docker container create  | 새로운 컨테이너 생성                      |
| docker container run     | 이미지로부터 컨테이너를 생성하고 실행             |
| docker container start   | 멈춰 있는 하나 이상의 컨테이너 실행             |
| docker container diff    | 컨테이너 파일 시스템의 변경 내용 검사            |
| docker container export  | 컨테이너 파일 시스템을 타볼로 추출              |
| docker container inspect | 하나 이상의 컨테이너의 자세한 정보 표시           |
| docker container kill    | 하나 이상의 실행 중인 컨테이너를 kill          |
| docker container logs    | 컨테이너 로그 조회                       |
| docker container ls      | 컨테이너 목록 조회                       |
| docker container pause   | 하나 이상의 컨테이너 내부의 모든 프로세스 정지       |
| docker container port    | 특정 컨테이너의 매핑된 포트 리스트 확인           |
| docker container prune   | 멈춰 있는 모든 컨테이너 삭제                 |
| docker container rename  | 컨테이너 이름을 다시 지음                   |
| docker container restart | 하나 이상의 컨테이너를 재실행                 |
| docker container rm      | 하나 이상의 컨테이너를 삭제                  |
| docker container stats   | 컨테이너 리소스 사용 통계 조회                |
| docker container stop    | 하나 이상의 실행 중인 컨테이너 정지             |
| docker container top     | 컨테이너의 실행 중인 프로세스 표시              |
| docker container unpause | 컨테이너 내부의 멈춰 있는 프로세스 재실행          |
| docker container update  | 하나 이상의 컨테이너 설정을 업데이트             |
| docker container wait    | 컨테이너가 종료될 때까지 기다린 후 exit code 표시 |


**<`exec` vs `attach`>**
- `docker container exec`
  - 실행 중인 컨테이너 내부에서 **새로운 프로세스를 시작**하여 명령어를 실행한다.
  - 예) `docker container exec [ID] ls -l`
- `docker container attach`
  - 컨테이너가 시작될 때 실행된 **기존의 메인 프로세스**의 표준 입력(stdin), 표준 출력(stdout), 표준 오류(stderr) 에 연결한다.
  - 예) `docker container run -it ubuntu` 이후 `exit` 했다가 `start` + `attach` 로 다시 붙는 경우

**<`create` vs `start` vs `run`>**
- `docker container create [이미지]`
  - 새로운 컨테이너를 생성하는 명령어로 create 다음에 나오는 이미지를 활용해 새로운 컨테이너를 **생성만** 한다. (Exited 상태)
- `docker container start [컨테이너 ID]`
  - **이미 생성되어 멈춰있는(Exited) 컨테이너를 실행**하는 명령어이다.
  - 따라서 `docker container create` 명령어를 통해 컨테이너를 생성하고, `docker container start` 명령어로 앞서 생성된 컨테이너를 실행한다.
- `docker container run [이미지]`
  - `create`와 `start`를 한 번에 실행한다. 즉, 이미지를 기반으로 컨테이너를 **생성하고 바로 실행**까지 한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Docker hub](https://hub.docker.com/)