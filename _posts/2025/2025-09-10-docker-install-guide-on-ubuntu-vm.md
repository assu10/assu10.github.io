---
layout: post
title:  "Docker - 우분투 가상 머신에 도커 설치"
date: 2025-09-10 10:00:00
categories: dev
tags: devops docker ubuntu install-guide container virtual-machine kubernetes 도커-설치 우분투
---

이 포스트에서는 PC 환경을 깨끗하게 유지하면서도 독립된 실습 공간을 마련하기 위해 가상 머신(Virtual Machine)에 도커를 설치하는 과정에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 사전 준비 사항](#1-사전-준비-사항)
* [2. 도커 설치](#2-도커-설치)
* [3. hello-world: 첫 컨테이너 실행](#3-hello-world-첫-컨테이너-실행)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 사전 준비 사항

여기서는 [Docker, Kubernetes - 우분투 환경 구성](https://assu10.github.io/dev/2024/12/14/kubernetes-ubuntu-virtualbox-setup/) 에서 
구축한 가상 머신을 기반으로 진행한다.

먼저 준비된 가상 머신에 SSH 를 통해 접속한다.

```shell
$ ssh assu@127.0.0.1
assu@127.0.0.1's password:
Welcome to Ubuntu 24.04.2 LTS (GNU/Linux 6.8.0-60-generic aarch64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Sep 13 07:38:55 AM UTC 2025

  System load:  0.13               Processes:               125
  Usage of /:   14.5% of 47.41GB   Users logged in:         0
  Memory usage: 3%                 IPv4 address for enp0s8: 10.0.2.4
  Swap usage:   0%

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

Expanded Security Maintenance for Applications is not enabled.

63 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


The list of available updates is more than a week old.
To check for new updates run: sudo apt update

Last login: Sat Sep 13 07:36:57 2025 from 10.0.2.2

assu@myserver01:~$
```

---

**패키지 관리자 업데이트 및 사전 필요 패키지 설치**

가장 먼저 할 일은 우분투의 패키지 관리자(`apt`)가 최신 패키지 목록을 가질 수 있도록 업데이트하는 것이다.  
이를 통해 설치 과정에서 발생할 수 있는 의존성 문제를 예방할 수 있다.

```shell
# apt 패키지 인덱스를 최신 상태로 업데이트
assu@myserver01:~$ sudo apt-get update
```

다음으로, 도커의 공식 리포지토리와 안전하게 통신(HTTPS)하고 필요한 파일을 내려받기 위한 필수 패키지들을 설치한다.

```shell
# HTTPS 통신에 필요한 패키지들 설치
assu@myserver01:~$ sudo apt-get install ca-certificates curl gnupg lsb-release
```

위 명령어에 포함된 패키지는 아래와 같은 역할을 수행한다.
- ca-certificates: 시스템이 신뢰할 수 있는 인증기관(CA)의 인증서를 관리하여 보안 통신을 가능하게 함
- curl: URL 을 통해 데이터를 전송하고 파일을 다운로드하는데 사용됨
- gnupg: GNU Privacy Guard 의 약자로, 소프트웨어의 진위 여부를 확인할 수 있는 디지털 서명(GPG 키)을 관리함
- lsb-release: 현재 사용 중인 리눅스 배포판의 버전 정보를 정확하게 식별함

---

**도커 공식 GPG 키 추가**

이제 도커에서 공식적으로 제공하는 패키지를 설치한다.  
하지만 이 패키지가 중간에 해커에 의해 변조되지 않았고, 정말로 도커에서 배포한 것이 맞는지 어떻게 신뢰할 수 있을까?

이 신뢰를 보장하기 위해 **도커의 공식 GPG(GNU Privacy Guard)키**를 시스템에 추가해야 한다.  
이 키를 통해 우리 시스템은 앞으로 도커 관련 패키지가 도커에 의해 정식으로 서명되었는지 검증하게 된다.

```shell
assu@myserver01:~$ pwd
/home/assu

# GPG 키를 저장할 디렉토리 생성
assu@myserver01:~$ sudo mkdir -m 0755 -p /etc/apt/keyrings

# 도커의 공식 GPG 키를 다운로드하여 시스템에 저장
assu@myserver01:~$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

---

**도커 공식 리포지토리 설정**

마지막 준비 단계는 패키지 관리자 apt 에게 "앞으로 도커는 이 주소에서 다운로드 하라." 고 알려주는 단계이다.  
즉, 도커 패키지가 저장된 공식 원격 저장소의 주소를 시스템에 등록하는 것이다.

아래 명령어는 도커 다운로드 주소 정보를 담은 설정 파일을 생성한다.
```shell
assu@myserver01:~$ echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

이 한 줄의 명령어는 현재 시스템 아키텍처(amd64, arm64 등)와 우분투 버전 코드명(noble, jammy 등)을 자동으로 감지하여 설정 파일에 반영해주므로, 어떤 
환경에서도 호환되는 편리한 방법이다.  
또한 `signed-by` 옵션을 통해 해당 리포지토리에서 받는 패키지는 방금 전 추가한 GPG 키로 검증해야 함을 명시한다.

---

# 2. 도커 설치

[1. 사전 준비 사항](#1-사전-준비-사항)을 통해 도커 공식 리포지토리를 인식하게 되었으니, 이제 본격적으로 도커 엔진(Docker Engine)을 설치한다.

**도커 패키지 설치**

설치에 앞서, 패키지 목록을 다시 한번 업데이트 해야 한다.

```shell
assu@myserver01:~$ sudo apt-get update
```

앞서 업데이트를 했는데 왜 또 하냐고 생각할 수도 있다.  
이전 단계에서 `/etc/apt/sources.list.d/docker.list` 파일을 추가하여 시스템에 '새로운 소프트웨어 창고(도커 공식 리포지토리)'를 등록했다.  
따라서 `apt` 가 이 새로운 창고에 어떤 패키지들이 있는지 목록을 가져오게 하려면, `update` 명령을 다시 실행해야 한다.  
이 과정을 생략하면 도커 패키지를 찾지 못하고 설치 오류를 발생시키게 된다.

이제 최신 버전의 도커 관련 패키지들을 설치한다.

```shell
assu@myserver01:~$ sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

설치 패키지들은 다음과 같다.
- docker-ce: Docker Community Edition 의 핵심인 도커 엔진
- docker-ce-cli: 도커 엔진과 상호 작용하기 위한 커맨드 라인 인터페이스(CLI)
- containerd.io: 컨테이너의 전체 생명주기를 관리하는 핵심 컨테이너 런타임
- docker-buildx-plugin, docker-compose-plugin: 멀티 아키텍처 빌드를 지원하는 `buildx` 와 여러 컨테이너를 관리하는 `docker compose` 를 `docker` 명령어의 플러그인 형태로 사용할 수 있게 해줌

---

**설치 확인 및 서비스 상태 점검**

설치가 완료되면 도커 서비스(Daemon)가 자동으로 실행된다.  
`systemctl status` 명령어로 도커가 정상적으로 실행 중인지 확인해보자.

```shell
assu@myserver01:~$ systemctl status docker
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; preset: enabled)
     Active: active (running) since Sat 2025-09-13 08:50:34 UTC; 56s ago
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 4094 (dockerd)
      Tasks: 10
     Memory: 22.7M (peak: 23.5M)
        CPU: 878ms
     CGroup: /system.slice/docker.service
             └─4094 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
...
```

출력 결과에서 Active: active (running) 이라는 문구가 보인다면, 도커가 성공적으로 설치되어 현재 시스템에서 동작하고 있다는 의미이다.

---

**`sudo` 없이 `docker` 명령어 사용 설정**

기본적으로 도커 데몬은 root 사용자 권한으로 실행되기 때문에, 일반 사용자가 `docker` 명령어를 사용하려면 매번 `sudo` 를 붙여야 하는 번거로움이 있다.

이 문제를 해결하기 위해 현재 사용자를 `docker` 그룹에 추가해준다. 그러면 `sudo` 없이 `docker` 명령어를 사용할 수 있다.

```shell
assu@myserver01:~$ sudo usermod -aG docker $USER
```

위 명령어를 실행한 후, 변경된 그룹 권한을 터미널 세션에 적용하려면 반드시 로그아웃한 후 다시 로그인해야 한다.

---

**도커 버전 확인**

서버에 다시 접속한 후, 아래 명령어로 `sudo` 없이 도커 버전이 잘 출력되는지 확인한다.

```shell
assu@myserver01:~$ docker version
Client: Docker Engine - Community
 Version:           28.4.0
 API version:       1.51
 Go version:        go1.24.7
 Git commit:        d8eb465
 Built:             Wed Sep  3 20:58:55 2025
 OS/Arch:           linux/arm64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          28.4.0
  API version:      1.51 (minimum version 1.24)
  Go version:       go1.24.7
  Git commit:       249d679
  Built:            Wed Sep  3 20:58:55 2025
  OS/Arch:          linux/arm64
  Experimental:     false
 containerd:
  Version:          1.7.27
  GitCommit:        05044ec0a9a75232cad458027ca83437aae3f4da
 runc:
  Version:          1.2.5
  GitCommit:        v1.2.5-0-g59923ef
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

만일 permission denied 와 같은 권한 오류가 나타나면, 로그아웃 후 재로그인하면 사용자 세션이 재시작되면서 정상적인 결과가 나타날 것이다.

---

# 3. hello-world: 첫 컨테이너 실행

이제 모든 설치와 설정이 끝났다. 도커가 완벽하게 동작하는지 확인하기 위한 가장 간단하면서도 확실한 방법은 hello-world 이미지를 실행해보는 것이다.

```shell
assu@myserver01:~$ docker run hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.
...
```

위 메시지는 단순한 출력이 아니라, 도커의 핵심적인 동작 과정이 모두 성공했다는 증거이다.  
메시지에 설명된 4가지 단계를 풀어보면 아래와 같다.

1. `docker` 클라이언트(터미널의 명령어)가 `dockerd` 데몬(백그라운드 서비스)에게 요청을 보냈다.
2. `dockerd` 데몬은 로컬 시스템에 `hello-world` 이미지가 없는 것을 확인하고, 인터넷을 통해 공식 이미지 저장소인 Docker Hub 에서 이미지를 다운로드했다.
3. `dockerd` 데몬은 다운로드한 이미지를 기반으로 새로운 컨테이너를 생성하고 실행했다.
4. `dockerd` 데몬은 실행된 컨테이너의 출력 결과를 다시 `docker` 클라이언트로 보내주었고, 그 결과가 터미널에 표시되었다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Docs::Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)