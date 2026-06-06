---
layout: post
title:  "Kubernetes - 쿠버네티스 클러스터 환경 셋팅"
date: 2025-12-06 10:00:00
categories: dev
tags: devops kubernetes k8s kubeadm installation cluster-setup ubuntu-linux virtual-machine containerd calico infrastructure
---

AWS EKS나 Google GKE와 같은 Managed Service를 이용하면 버튼 몇 번으로 클러스터를 사용할 수 있지만, 이는 쿠버네티스의 핵심 구성 요소와 내부 동작 원리를 
깊이 이해하는 데에는 한계가 있다.

이 포스트에서는 가상 머신(Virtual Machine) 환경 위에 쿠버네티스 클러스터를 처음부터 직접 구축해본다.  
이는 단순히 실습 환경을 얻는 것을 넘어, 운영 체제 레벨의 설정부터 컨테이너 런타임, 그리고 쿠버네티스 컴포넌트 간의 상호작용을 이해하는데 큰 도움을 줄 것이다.

실제 운영 환경에서 발생하는 트러블 슈팅의 대부분은 네트워크, 보안 설정, OS 커널 파라미터와 연관되어 있다.  
직접 클러스터를 구축해보는 경험은 이러한 문제 상황에서 시스템 전체를 조망할 수 있는 엔지니어링 통찰력을 길러준다.

---

**목차**

<!-- TOC -->
* [1. 사전 준비 사항](#1-사전-준비-사항)
  * [1.1. 가상머신 복제](#11-가상머신-복제)
  * [1.2. 호스트 이름 변경](#12-호스트-이름-변경)
  * [1.3. IP 주소 변경](#13-ip-주소-변경)
  * [1.4. DNS 설정(/etc/hosts)](#14-dns-설정etchosts)
  * [1.5. UFW(Uncomplicated FireWall) 방화벽 설정](#15-ufwuncomplicated-firewall-방화벽-설정)
  * [1.6. 네트워크 설정(커널 모듈 및 브릿지 설정)](#16-네트워크-설정커널-모듈-및-브릿지-설정)
  * [1.7. `containerd` 설정](#17-containerd-설정)
  * [1.8. swap 메모리 비활성화](#18-swap-메모리-비활성화)
* [2. 쿠버네티스 설치](#2-쿠버네티스-설치)
  * [2.1. 모든 노드에 쿠버네티스 설치](#21-모든-노드에-쿠버네티스-설치)
  * [2.2. 마스터 노드 설정(Control Plane Setup)](#22-마스터-노드-설정control-plane-setup)
  * [2.3. 워커 노드 설정](#23-워커-노드-설정)
* [3. 쿠버네티스로 실행하는 Hello World!](#3-쿠버네티스로-실행하는-hello-world)
* [4. 쿠버네티스 삭제 방법(클러스터 초기화)](#4-쿠버네티스-삭제-방법클러스터-초기화)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB
- Kubernetes: v1.29.15

---

# 1. 사전 준비 사항

쿠버네티스는 단일 노드에서도 동작할 수 있지만, 실제 운영 환경과 유사한 고가용성 및 부하 분산을 학습하기 위해 **멀티 노드 클러스터**를 구축한다.

여기서는 총 3대의 가상 머신(VM)을 사용하여 아래와 같이 역할을 분배한다.
- **마스터 노드(1대)**
  - 클러스터 전체를 제어하고 관리(Control Plane)
- **워커 노드(2대)**
  - 실제 애플리케이션(Pod)이 배포되고 실행되는 노드

![쿠버네티스 클러스터 구축을 위해 가상머신 추가](/assets/img/dev/2025/1206/add_vm.png)

---

## 1.1. 가상머신 복제

먼저 베이스가 되는 가상머신(myserver01)을 복제하여 3대의 서버를 준비한다.  
VirtualBox와 같은 가상화 도구를 사용한다면 Clone 기능을 활용하여 쉽게 동일한 환경을 구성할 수 있다.

![가상머신 복제(1)](/assets/img/dev/2025/1206/clone1.png)

- 기존 가상머신(myserver01) 우클릭 후 Clone 선택
- 이름을 myserver02, myserver03 으로 각각 설정

이 때 Full Clone(완전한 복제)을 선택하여 모든 디스크 파일이 독립적으로 생성되도록 한다.

복제가 완료되면 3대의 가상머신을 모두 부팅한다.

---

## 1.2. 호스트 이름 변경

복제된 가상머신들은 원본과 동일한 호스트 이름(myserver01)을 가지고 있다.  
관리 용이성을 위해 각 서버의 호스트 이름을 변경한다.

각 서버 터미널에 접속하여 아래 명령어를 통해 이름을 변경한다.

```shell
assu@myserver01:~$ sudo hostnamectl set-hostname myserver02
assu@myserver01:~$ cat /etc/hostname
myserver02
assu@myserver01:~$ sudo reboot now
```

설정 후 터미널을 재접속하면 프롬프트의 호스트 이름이 변경된 것을 확인할 수 있다.

---

## 1.3. IP 주소 변경

가상머신을 단순 복제했기 때문에 IP 주소도 원본과 동일하다. 쿠버네티스 클러스터 내 통신을 위해 각 노드는 **고정된 고유 IP**를 가져야 한다.

우분투 환경에서는 `netplan`을 사용하여 네트워크를 설정한다. 각 서버의 /etc/netplan/00-installer-config.yaml 파일을 수정하고 고정 IP를 할당한다.

**계획된 IP 할당**  
- myserver01: 10.0.2.4
- myserver02: 10.0.2.5
- myserver03: 10.0.2.6

두 번째 가상머신에 접속 후 ifconfig로 아이피를 확인하면 10.0.2.5 인 것을 확인할 수 있다.

```shell
assu@myserver02:~$ ifconfig

enp0s8: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.2.5  netmask 255.255.255.0  broadcast 10.0.2.255
        inet6 fe80::a00:27ff:fe48:a91a  prefixlen 64  scopeid 0x20<link>
        ether 08:00:27:48:a9:1a  txqueuelen 1000  (Ethernet)
        RX packets 3661  bytes 465732 (465.7 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 3302  bytes 331197 (331.1 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

---

이제 00-installer-config.yaml 파일로 IP 주소를 변경하자.

**1) myserver01 설정(Master)**

```shell
assu@myserver01:/$ sudo vim /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  ethernets:
    enp0s8:
      dhcp4: false
      addresses: [10.0.2.4/24]
      routes:
        - to: default
          via: 10.0.2.1
      nameservers:
        addresses: [8.8.8.8]
  version: 2
```

---

**2) myserver02 설정(Worker 1)**
```shell
assu@myserver02:~$ sudo cat /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  ethernets:
    enp0s8:
      dhcp4: false
      addresses: [10.0.2.5/24]
      routes:
        - to: default
          via: 10.0.2.1
      nameservers:
        addresses: [8.8.8.8]
  version: 2
```

---

**3) myserver03 설정(Worker 2)**

```shell
assu@myserver03:~$ sudo cat /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  ethernets:
    enp0s8:
      dhcp4: false
      addresses: [10.0.2.6/24]
      routes:
        - to: default
          via: 10.0.2.1
      nameservers:
        addresses: [8.8.8.8]
  version: 2
```

---

**4) 설정 적용 및 확인**

각 서버에서 파일을 수정했다면 설정을 적용한다.

```shell
assu@myserver02:/$ sudo netplan apply
```

`ifconfig`로 IP가 정상적으로 변경되었는지 확인한다.

---

**5) 로컬 접속을 위한 포트포워딩**

호스트 OS(내 로컬)에서 각 가상머신에 쉽게 SSH로 접속하기 위해 포트포워딩을 설정한다.  
VM 네트워크 설정에서 아래와 같이 매핑한다.


![포트포워딩 설정](/assets/img/dev/2025/1206/server_config.png)

호스트 아이피와 포트는 내 로컬에서 서버로 접속할 때의 창구이고, 게스트 아이피와 포트는 위에서 설정한 서버들의 고정 IP이다.

이제 로컬 터미널에서 아래 명령어로 각 서버에 바로 접속할 수 있다.

```shell
# myserver01 접속
$ ssh -p 2201 assu@127.0.0.1

# myserver02 접속
$ ssh -p 2202 assu@127.0.0.1

# myserver03 접속
$ ssh -p 2203 assu@127.0.0.1
```

---

## 1.4. DNS 설정(/etc/hosts)

쿠버네티스 노드들은 서로를 호스트 이름으로 식별하고 통신한다.  
별도의 DNS 서버를 구축하지 않았으므로, 각 서버의 /etc/hosts 파일을 수정하여 Name Resolution이 가능하게 한다.

모든 노드(myserver01, 02, 03)에서 /etc/hosts 파일을 열고 아래와 같이 수정한다.

```shell
➜  ~ ssh -p 2202 assu@127.0.0.1
assu@myserver02:~$ sudo vim /etc/hosts
```

```text
127.0.0.1 localhost
127.0.1.1 myserver02 # 호스트이름 변경

# Cluster Node Info 추가
10.0.2.4 myserver01
10.0.2.5 myserver02
10.0.2.6 myserver03

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
~
```

설정이 완료되면 `ping`과 `ssh`로 호스트 이름으로 통신이 되는지 검증한다.

```shell
assu@myserver02:~$ ping myserver01
PING myserver01 (10.0.2.4) 56(84) bytes of data.
64 bytes from myserver01 (10.0.2.4): icmp_seq=1 ttl=64 time=0.041 ms
^C

assu@myserver02:~$ ping myserver03
PING myserver03 (10.0.2.6) 56(84) bytes of data.
64 bytes from myserver03 (10.0.2.6): icmp_seq=1 ttl=64 time=1.49 ms
```

이번엔 myserver02에서 myserver01로 ssh 접속을 해본다.
```shell
assu@myserver02:~$ ssh myserver01
assu@myserver01's password:
assu@myserver01:~$ exit
logout
Connection to myserver01 closed.
assu@myserver02:~$

assu@myserver02:~$ ssh myserver03
assu@myserver03:~$ exit
logout
Connection to myserver03 closed.
assu@myserver02:~$
```

같은 방법으로 myserver01, myserver03도 수정한다.

myserver01 /etc/hosts
```text
127.0.0.1 localhost
127.0.1.1 myserver01  # 여기를 각각 myserver02, myserver03 으로 수정

# 아래 추가
10.0.2.4 myserver01
10.0.2.5 myserver02
10.0.2.6 myserver03

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

위와 같이 모든 노드 간에 ping 과 ssh 접속이 원활하다면 클러스터 구축을 위한 기본적인 네트워크 준비는 끝났다.

---

## 1.5. UFW(Uncomplicated FireWall) 방화벽 설정

쿠버네티스 클러스터는 노드 간에 수많은 포트를 사용하여 통신한다. (API 서버, etcd, 스케줄러, Kubelet 등)  
실무 환경에서는 보안을 위해 특정 포트만 개방하는 것이 원칙이지만, 실습 환경의 복잡도를 낮추고 원활한 통신을 보장하기 위해 우분투 기본 방화벽인 UFW를 비활성화한다.

> **UFW(Uncomplicated FireWall)**
> 
> 리눅스 운영체제에서 작동하는 방화벽

모든 노드(myserver01, 02, 03)에서 아래 명령어를 실행한다.

```shell
assu@myserver02:~$ sudo ufw disable
assu@myserver02:~$ sudo ufw status
Status: inactive
```

---

## 1.6. 네트워크 설정(커널 모듈 및 브릿지 설정)

쿠버네티스 Pod 간의 통신을 원활하게 하기 위해 리눅스 커널 설정을 변경한다.  
이 과정은 모든 노드에서 root 권한으로 진행하는 것이 편리하다.

---

**1) 커널 모듈 로드(`overlay`, `br_netfilter`)**

먼저 필요한 커널 모듈 두 가지를 로드하고, 재부티이 후에도 적용되도록 설정 파일을 생성한다.

- **`overlay`**
  - 서로 다른 호스트에 있는 Pod 들이 마치 같은 네트워크에 있는 것처럼 통신할 수 있게 해주는 네트워크 드라이버 기술
- **`br_netfilter`**
  - 브릿지 네트워크를 통과하는 패킷이 `iptables` 규칙의 적용을 받도록 하여, 쿠버네티스가 네트워크 트래픽을 세밀하게 제어(NAT, 포트 포워딩 등)할 수 있게 함

쿠버네티스를 설치하기 전에 네트워크를 설정한다.

```shell
# 루트 권한 획득
assu@myserver01:~$ sudo -i

# 모듈 로드 설정 파일 생성
root@myserver01:~# cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
> overlay
> br_netfilter
> EOF
overlay
br_netfilter
root@myserver01:~#
```

`EOF`는 문서의 마지막을 의미한다.

설정 파일 생성 후, `modprobe` 명령어로 즉시 모듈을 커널에 로드한다.
```shell
root@myserver01:~# sudo modprobe overlay
root@myserver01:~# sudo modprobe br_netfilter
```

`modprobe`는 리눅스 커널 모듈 관리 도구로, 이를 이용하면 특정 모듈을 로드하거나 제거할 수 있다.

---

**2) 커널 파라미터 설정(`sysctl`)**

이제 브릿지 구성과 IP 포워딩 관련 커널 파라미터를 설정한다.

```shell
# 필요한 sysctl 매개변수를 설정하면, 재부팅 후에도 값이 유지된다.
root@myserver01:~# cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
> net.bridge.bridge-nf-call-iptables=1   # IPv4 트래픽이 iptables 체인을 통과하도록 설정
> net.bridge.bridge-nf-call-ip6tables=1  # IPv6 트래픽이 iptables 체인을 통과하도록 설정
> net.ipv4.ip_forward=1  # 커널이 처리하는 패킷에 대해 외부로 ipv4 포워딩이 가능하게 해줌
> EOF  # 문서의 마지막
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
```

설정 파일을 생성했다면, 재부팅없이 즉시 적용한다.

```shell
root@myserver01:~# sudo sysctl --system
```

위 과정을 mysever02, 03에도 동일하게 수행한다.

---

## 1.7. `containerd` 설정

쿠버네티스는 컨테이너를 실행하기 위해 **컨테이너 런타임**이 필요하다.  
과거에는 Docker를 직접 사용했으나, 현재는 경량화된 표준 런타임인 `containerd`를 주로 사용한다.

> 도커를 설치했다면 `apt install containerd.io`를 통해 이미 설치되어 있을 것이다.

**<핵심 설정>**  
`Systemd Cgroup` 쿠버네티스의 노드 에이전트인 `kubelet`은 시스템의 자원을 관리하기 위해 cgroup을 사용한다.  
리눅스의 init 시스템인 `systemd`도 `cgroup`을 사용하는데, 이 둘의 드라이버를 `systemd`로 통일해주어야 시스템 안정성을 보장할 수 있다.

> containerd 를 컨테이너 런타임으로 설정하는 것에 대한 좀 더 상세한 내용은  [Doc:: containerd](https://kubernetes.io/ko/docs/setup/production-environment/container-runtimes/#containerd) 를 참고하세요.

---

**1) 기본 설정 파일 생성**

기존 설정을 초기화하고 기본 설정(default config)을 파일로 저장한다.

```shell
assu@myserver01:~$ sudo mkdir -p /etc/containerd
assu@myserver01:~$ containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

`containerd config default` 를 통해 출력된 기본 설정값들을 `tee` 명령어를 통해 config.toml 파일로 저장한다.

---

**2) Systemd Cgroup 활성화**

생성된 config.toml 파일을 열어 `SystemdCgroup` 값을 true로 변경한다.

```shell
assu@myserver01:~$ sudo vim /etc/containerd/config.toml
...
    systemd_cgroup = true  # true로 변경
```

---

**3) 재시작 및 확인**

설정을 적용하기 위해 containerd를 재시작하고 상태를 확인한다.

```shell
assu@myserver01:~$ sudo systemctl restart containerd
assu@myserver01:~$ sudo systemctl enable containerd
assu@myserver01:~$ sudo systemctl status containerd
● containerd.service - containerd container runtime
     Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; preset: enabled)
     Active: active (running) since Sun 2025-12-14 02:22:53 UTC; 17s ago
       Docs: https://containerd.io
   Main PID: 2580 (containerd)
      Tasks: 9
     Memory: 13.3M (peak: 14.1M)
        CPU: 79ms
     CGroup: /system.slice/containerd.service
             └─2580 /usr/bin/containerd

Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.482992179Z" level=info msg=">
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.482995471Z" level=info msg=">
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.482999721Z" level=info msg=">
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.483012221Z" level=info msg=">
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.483018013Z" level=info msg=">
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.483126763Z" level=warning ms>
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.483233638Z" level=info msg=s>
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.483250513Z" level=info msg=s>
Dec 14 02:22:53 myserver01 containerd[2580]: time="2025-12-14T02:22:53.483273513Z" level=info msg=">
Dec 14 02:22:53 myserver01 systemd[1]: Started containerd.service - containerd container runtime.
lines 1-21/21 (END)
```
Active: active (running) 상태가 확인되면 정상이다.

이 과정을 myserver02, myserver03에도 동일하게 진행한다.

---

## 1.8. swap 메모리 비활성화

쿠버네티스는 **swap 메모리 비활성화**를 강력하게 권장한다.  
쿠버네티스 스케줄러는 노드의 가용 메모리를 기반으로 Pod를 배치하는데, 시스템이 swap 메모리를 사용하게 되면 정확한 리소스 사용량을 예측하기 어려워지고 
성능 이슈가 발생할 수 있기 때문이다.  
실제로 swap이 켜져 있으면 `kubelet`이 실행되지 않는다.

---

**1) 현재 상태 확인**

```shell
assu@myserver01:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       418Mi       7.1Gi        16Mi       432Mi       7.3Gi
Swap:          4.0Gi          0B       4.0Gi  # swap 메모리가 할당되어 있는 것 확인
```

swap이 활성화 중인지 아래의 방법으로 확인할 수도 있다.

```shell
assu@myserver01:~$ cat /proc/swaps
Filename				Type		Size		Used		Priority
/swap.img                               file		4194300		0		-2
```

---

**2) swap 비활성화**

`swapoff --all`로 swap 메모리를 비활성화한다.

```shell
assu@myserver01:~$ sudo -i
root@myserver01:~# swapoff --all
```

`free -h`와 `cat /proc/swaps` 로 swap 메모리가 비활성화된 것을 확인한다.

```shell
root@myserver01:~# free -h
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       420Mi       7.1Gi        16Mi       433Mi       7.3Gi
Swap:             0B          0B          0B
root@myserver01:~# cat /proc/swaps
Filename				Type		Size		Used		Priority
root@myserver01:~#
```

재부팅 후에도 스왑이 켜지지 않도록 /etc/fstab 파일을 수정한다.

```shell
root@myserver01:~# vim /etc/fstab

/dev/disk/by-uuid/41DF-08C6 /boot/efi vfat defaults 0 1
#/swap.img      none    swap    sw      0       0  # 주석 처리
~
```

---

**3) 재부팅 및 확인**

설정을 확인하기 위해 시스템을 재부팅한다.
```shell
root@myserver01:~# shutdown -r now
```

재부팅 후 다시 접속하여 `free -h` 명령어로 swap 이 0B 인지 확인한다.

위 내용을 myserver02, myserver03 에도 동일하게 적용한다.

---

# 2. 쿠버네티스 설치

OS, 네트워크, 런타임 설정을 하여 사전 준비를 마쳤으니, 이제 쿠버네티스 소프트웨어를 설치한다.

`kubeadm`이라는 도구를 사용하여 클러스터를 구축한다. 이를 위해 모든 노드에 아래 3개 구성 요소를 설치한다.
- **`kubeadm`**
  - 클러스터를 부트스트랩(구축)하는 명령 도구
- **`kubelet`**
  - 클러스터의 모든 노드에서 실행되는 에이전트로, Pod와 컨테이너 시작 등을 관리
- **`kubectl`**
  - 클러스터와 통신하기 위한 커맨드 라인 유틸리티(CLI)

이후 클러스터 구축이 완료되면 Hello World! Pod를 띄워 정상 동작을 확인하고, 클러스터를 삭제하는 방법까지 알아본다.

---

## 2.1. 모든 노드에 쿠버네티스 설치

이 과정은 myserver01, 02, 03 모든 노드에 동일하게 수행한다.

> 쿠버네티스 설치에 대한 좀 더 상세한 내용은 [Doc:: kubeadm 설치하기](https://kubernetes.io/ko/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) 를 참고하세요.

---

**1) 필수 패키지 설치 및 저장소 설정**

먼저 `apt` 패키지 인덱스를 업데이트하고, HTTPS를 통해 저장소를 사용할 수 있도록 필요한 패키지들을 설치한다.

```shell
➜  ~ ssh -p 2201 assu@127.0.0.1

# 패키지 인덱스 업데이트
assu@myserver01:~$ sudo apt-get update

# 필수 패키지 설치
assu@myserver01:~$ sudo apt-get install -y apt-transport-https ca-certificates curl
```

쿠버네티스 패키지 저장소의 공개 서명 키(Signing Key)를 다운로드한다.
```shell
# signing 키 다운로드를 위해 필요한 디렉터리 생성
assu@myserver01:~$ sudo mkdir -p /etc/apt/keyrings

# 쿠버네티스 설치에 필요한 서명 키를 다운로드 하여 /etc/apt/keyrings/ 디렉터리에 저장 및 변환(dearmor)
assu@myserver01:~$ sudo curl -fsSL \
> https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg \
> --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyrings.gpg
```

다운로드한 키를 사용하여 쿠버네티스 패키지 저장소를 `apt` 소스 리스트에 추가한다.
```shell
# 쿠버네티스 패키지 저장소를 apt 패키지 관리자에 추가
assu@myserver01:~$ echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyrings.gpg] \
> https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee \
> /etc/apt/sources.list.d/kubernetes.list

# 출력 확인
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyrings.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /
```

---

**2) `kubeadm`, `kubelet`, `kubectl` 설치**

저장소가 추가되었으므로 다시 한번 업데이트를 진행한 뒤, 특정 버전을 명시하여 설치한다.  
버전을 명시하지 않으면 항상 최신 버전이 설치된다.

```shell
assu@myserver01:~$ sudo apt-get update
assu@myserver01:~$ sudo apt-get install -y kubelet=1.29.15-1.1 kubeadm=1.29.15-1.1 kubectl=1.29.15-1.1
```

설치 후에는 패키지 관리 도구(`apt`)가 이들을 자동으로 업그레이드하지 못하도록 **버전을 고정**한다.  
쿠버네티스 업그레이드는 복잡한 과정을 거쳐야 하므로, 의도치 않은 자동 업데이트는 시스템 장애를 유발할 수도 있다.

```shell
# 설치 후 의도치않게 버전이 업그레이드되는 것을 막기 위해 버전 고정
assu@myserver01:~$ sudo apt-mark hold kubelet kubeadm kubectl
kubelet set on hold.
kubeadm set on hold.
kubectl set on hold.
```

---

**3) 설치 확인**

```shell
assu@myserver01:~$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"29", GitVersion:"v1.29.15", GitCommit:"0d0f172cdf9fd42d6feee3467374b58d3e168df0", GitTreeState:"clean", BuildDate:"2025-03-11T17:46:36Z", GoVersion:"go1.23.6", Compiler:"gc", Platform:"linux/arm64"}

assu@myserver01:~$ kubelet --version
Kubernetes v1.29.15

assu@myserver01:~$ kubectl version --output=yaml
clientVersion:
  buildDate: "2025-03-11T17:48:10Z"
  compiler: gc
  gitCommit: 0d0f172cdf9fd42d6feee3467374b58d3e168df0
  gitTreeState: clean
  gitVersion: v1.29.15
  goVersion: go1.23.6
  major: "1"
  minor: "29"
  platform: linux/arm64
kustomizeVersion: v5.0.4-0.20230601165947-6ce0bf390ce3

# 아직 클러스터가 없으므로 서버 연결 에러 메시지는 정상임
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

이제 위 내용은 myserver02, myserver03 에도 적용한다.

---

## 2.2. 마스터 노드 설정(Control Plane Setup)

이제 myserver01을 클러스터의 두뇌 역할을 하는 **마스터 노드(Control Plane)**로 초기화한다.  
이 과정이 완료되면 나머지 두 서버를 워커 노드로 연결할 것이다.

---

**1) 사전 점검 및 이미지 준비**

설치 전, 쿠버네티스 인증서 상태를 확인해본다.  
아직 클러스터가 구성되지 않았으므로 모든 항목이 MISSING으로 나오는 것이 정상이다.

```shell
assu@myserver01:~$ kubeadm certs check-expiration
CERTIFICATE                          EXPIRES   RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
!MISSING! admin.conf
!MISSING! apiserver
!MISSING! apiserver-etcd-client
!MISSING! apiserver-kubelet-client
!MISSING! controller-manager.conf
!MISSING! etcd-healthcheck-client
!MISSING! etcd-peer
!MISSING! etcd-server
!MISSING! front-proxy-client
!MISSING! scheduler.conf
!MISSING! super-admin.conf

CERTIFICATE AUTHORITY      EXPIRES   RESIDUAL TIME   EXTERNALLY MANAGED
!MISSING! ca
!MISSING! etcd-ca
!MISSING! front-proxy-ca
```

인증이 하나도 되지 않은 것을 확인할 수 있다.

다음으로 초기화에 필요한 쿠버네티스 코어 이미지들을 미리 다운로드(Pull)한다.  
이 과정을 통해 실제 초기화(`init`) 단계에서의 시간을 단축할 수 있다.



kubeadm이 사용할 수 있는 이미지 리스트를 출력한다.

```shell
assu@myserver01:~$ kubeadm config images list
I1214 03:17:27.071881    4263 version.go:256] remote version is much newer: v1.34.3; falling back to: stable-1.29
registry.k8s.io/kube-apiserver:v1.29.15
registry.k8s.io/kube-controller-manager:v1.29.15
registry.k8s.io/kube-scheduler:v1.29.15
registry.k8s.io/kube-proxy:v1.29.15
registry.k8s.io/coredns/coredns:v1.11.1
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.16-0
```

쿠버네티스 설치에 필요한 이미지를 다운로드한다.

```shell
assu@myserver01:~$ sudo -i
[sudo] password for assu:
root@myserver01:~# kubeadm config images pull
```

오류가 난다면 containerd(컨테이너 런타임)의 설정 파일(config.toml)이 초기화되지 않았거나, kubernetes가 요구하는 설정(CRI)이 제대로 활성화되지 않은 것이므로 
아래 내용을 진행해준다.

```shell
root@myserver01:~# mkdir -p /etc/containerd
root@myserver01:~# mv /etc/containerd/config.toml /etc/containerd/config.toml.bak 2>/dev/null
root@myserver01:~# containerd config default > /etc/containerd/config.toml
root@myserver01:~# sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
root@myserver01:~# systemctl restart containerd
root@myserver01:~# systemctl enable containerd
```

이제 `--cir-socket` 옵션을 명시하여 이미지를 다운로드한다.

```shell
root@myserver01:~# kubeadm config images pull --cri-socket /run/containerd/containerd.sock
W1214 03:23:47.234175    4698 initconfiguration.go:125] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/run/containerd/containerd.sock". Please update your configuration!
I1214 03:23:47.704439    4698 version.go:256] remote version is much newer: v1.34.3; falling back to: stable-1.29
[config/images] Pulled registry.k8s.io/kube-apiserver:v1.29.15
[config/images] Pulled registry.k8s.io/kube-controller-manager:v1.29.15
[config/images] Pulled registry.k8s.io/kube-scheduler:v1.29.15
[config/images] Pulled registry.k8s.io/kube-proxy:v1.29.15
[config/images] Pulled registry.k8s.io/coredns/coredns:v1.11.1
[config/images] Pulled registry.k8s.io/pause:3.9
[config/images] Pulled registry.k8s.io/etcd:3.5.16-0
```

---

**2) 클러스터 초기화(kubeadm init)**

가장 중요한 단계인 마스터 노드 초기화를 진행한다. 각 옵션의 의미는 아래와 같다.
- **`--apiserver-advertise-address`**
  - 마스터 노드가 다른 노드와 통신할 IP 주소
- **`--pod-network-cidr`**
  - pod가 사용할 네트워크 대역
  - 여기서는 `Calico` CNI를 사용할 예정이므로 192.168.0.0/16 을 지정함(flannel 사용 시 10.244.0.0/16)
- **`--cri-socket`**
  - 컨테이너 런타임 소켓 경로 지정

```shell
root@myserver01:~# kubeadm init \
  --apiserver-advertise-address=10.0.2.4 \
  --pod-network-cidr=192.168.0.0/16 \
  --cri-socket unix:///run/containerd/containerd.sock
  
...

kubeadm join 10.0.2.4:6443 --token rvtrff.b0hnsxmuwd0hnxzy \
	--discovery-token-ca-cert-hash sha256:6ffeed543f773476c54c31b7010054c58b453e702abacccc7191d6c395e0f058
```

초기화가 성공하면 결과로 마지막에 _kubeadm join ...e0f058_ 명령어가 출력된다.  
이 명령어(토큰 포함)는 워커 노드를 연결할 때 필수적이므로 반드시 따로 저장해두어야 한다.

이제 다시 쿠버네티스 인증서 상태를 확인해보면 인증이 되어있는 것을 확인할 수 있다.

```shell
root@myserver01:~# kubeadm certs check-expiration
[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Dec 14, 2026 03:33 UTC   364d            ca                      no
apiserver                  Dec 14, 2026 03:33 UTC   364d            ca                      no
apiserver-etcd-client      Dec 14, 2026 03:33 UTC   364d            etcd-ca                 no
apiserver-kubelet-client   Dec 14, 2026 03:33 UTC   364d            ca                      no
controller-manager.conf    Dec 14, 2026 03:33 UTC   364d            ca                      no
etcd-healthcheck-client    Dec 14, 2026 03:33 UTC   364d            etcd-ca                 no
etcd-peer                  Dec 14, 2026 03:33 UTC   364d            etcd-ca                 no
etcd-server                Dec 14, 2026 03:33 UTC   364d            etcd-ca                 no
front-proxy-client         Dec 14, 2026 03:33 UTC   364d            front-proxy-ca          no
scheduler.conf             Dec 14, 2026 03:33 UTC   364d            ca                      no
super-admin.conf           Dec 14, 2026 03:33 UTC   364d            ca                      no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Dec 12, 2035 03:33 UTC   9y              no
etcd-ca                 Dec 12, 2035 03:33 UTC   9y              no
front-proxy-ca          Dec 12, 2035 03:33 UTC   9y              no
```

---

**3) `kubectl` 권한 설정(사용자 설정)**

초기화 직후에는 root 계정만 클러스터를 제어할 수 있다.  
일반 사용자(assu)도 `kubectl`을 사용할 수 있도록 설정 파일을 복사하고 권한을 부여한다.

```shell
# root 세션을 종료하고 기존 사용자로 돌아감
root@myserver01:~# exit
logout

# 사용자가 쿠버네티스를 활용할 수 있도록 쿠버네티스 설정을 저장할 디렉터리 생성
assu@myserver01:~$ mkdir -p $HOME/.kube

# 기존 설정 파일을 새로운 디렉터리로 복사
assu@myserver01:~$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[sudo] password for assu:

# 설정 디렉터리의 소유자와 그룹을 변경하여 현재 사용자가 사용할 수 있도록 함
assu@myserver01:~$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

**4) CNI(Container Network Interface) 설치: Calico**

쿠버네티스 네트워킹을 담당할 CNI 플러그인을 설치해야 노드 상태가 `Ready`로 변경되고, Pod 간 통신이 가능하다.  
여기서는 널리 사용되는 **Calico** 를 설치한다.

> calico 설치에 대한 좀 더 상세한 내용은 [Doc:: calico 설치](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises)를 참고하세요.

```shell
# calico를 설치하기 위해 해당 URL에 존재하는 yaml 파일을 실행
assu@myserver01:~$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
namespace/tigera-operator created
...
deployment.apps/tigera-operator created

# calico 설치를 위해 필요한 커스텀 리소스 설치
assu@myserver01:~$ curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   777  100   777    0     0   3262      0 --:--:-- --:--:-- --:--:--  3264

# 다운로드한 파일 확인
assu@myserver01:~$ ls
custom-resources.yaml  work

# 해당 yaml을 활용하여 calico 설치
assu@myserver01:~$ kubectl create -f custom-resources.yaml
installation.operator.tigera.io/default created
apiserver.operator.tigera.io/default created
```

설치 후 `calico-system` 네임스페이스의 Pod들이 모두 Running 상태가 될 때까지 기다린다.

설치가 완료된 후 calico에 대한 pod가 실행중인지 확인한다.
모든 요소가 작동하려면 약 1~2분 정도가 소요된다.

```shell
assu@myserver01:~$ watch kubectl get pods -n calico-system

Every 2.0s: kubectl get pods -n calico-system                   myserver01: Sun Dec 14 03:48:21 2025

NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-7f86844856-pvszk   1/1     Running   0          2m23s
calico-node-tlz2z                          1/1     Running   0          2m23s
calico-typha-674886f54f-t5xsd              1/1     Running   0          2m23s
csi-node-driver-fftgf                      2/2     Running   0          2m23s
```

마스터 노드의 상태를 확인해보면 이제 `Ready` 상태가 된 것을 확인할 수 있다.
```shell
assu@myserver01:~$ kubectl get node -o wide
NAME         STATUS   ROLES           AGE   VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
myserver01   Ready    control-plane   15m   v1.29.15   10.0.2.4      <none>        Ubuntu 24.04.2 LTS   6.8.0-88-generic   containerd://1.7.27
```

지금은 myserver01로만 구성이 되어 있다.  
이제 뒤에서 myserver02와 myserver03을 추가할 것이다.

---

## 2.3. 워커 노드 설정

워커 노드는 myserver02, myserver03 노드를 대상으로 진행한다.  
이 워커 노드들을 클러스터에 합류시킬 것이다.

**1) `kubectl` 설정 파일 복사**

워커 노드에서도 `kubectl` 명령어를 통해 클러스터 상태를 조회하고 싶다면, 마스터 노드의 설정 파일(config)을 복사해온다.  
이 때 마스터 노드의 IP는 10.0.2.4 이다.

```shell
assu@myserver02:~$ mkdir -p $HOME/.kube

# 마스터 노드(10.0.2.4)의 설정 파일 복사 (scp)
assu@myserver02:~$ scp -p assu@10.0.2.4:~/.kube/config ~/.kube/config
config                                                     100% 5652     1.1MB/s   00:00

assu@myserver02:~$ cd .kube
assu@myserver02:~/.kube$ ls
config
```

---

**2) 클러스터 조인(kubeadm join)**

이제 워커 노드를 클러스터에 연결한다. 앞서 [2.2. 마스터 노드 설정(Control Plane Setup)](#22-마스터-노드-설정control-plane-setup) 에서 마스터 노드 초기화(init) 시 
따로 저장해두었던 `kubeadm join` 명령어를 root 권한으로 실행한다.  
이 때 `--cri-socket` 은 직접 입력해주어야 한다.

```shell
assu@myserver02:~/.kube$ sudo -i

root@myserver02:~# kubeadm join 10.0.2.4:6443 --token rvtrff.b0hnsxmuwd0hnxzy --discovery-token-ca-cert-hash sha256:6ffeed543f773476c54c31b7010054c58b453e702abacccc7191d6c395e0f058 --cri-socket /run/containerd/containerd.sock
W1214 03:58:51.293629    4890 initconfiguration.go:125] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/run/containerd/containerd.sock". Please update your configuration!
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

---

**3) 전체 클러스터 확인**

마스터 노드(myserver01)로 돌아와 전체 노드가 정상적으로 연결되었는지 확인한다.

```shell
assu@myserver01:~$ kubectl get nodes
NAME         STATUS   ROLES           AGE     VERSION
myserver01   Ready    control-plane   28m     v1.29.15
myserver02   Ready    <none>          3m42s   v1.29.15
myserver03   Ready    <none>          38s     v1.29.15
```

3대의 노드 모두 Ready 상태라면 성공적으로 쿠버네티스 클러스터 구축이 완료된 것이다.

---

# 3. 쿠버네티스로 실행하는 Hello World!

클러스터 구축이 완료되었으니, 실제로 Pod를 생성하여 쿠버네티스가 정상 동작하는지 검증해보자.  
이 작업은 `kubectl` 명령어를 사용할 수 있는 마스터 노드인 myserver01에서 진행한다.

가장 간단한 도커 이미지인 hello-world 를 실행해보자.

```shell
assu@myserver01:~$ kubectl run hello-world --image=hello-world --restart=Never
pod/hello-world created
```

- **`kubectl run`**
  - Pod를 생성하는 명령어
- **`--image=hello-world`**
  - 사용할 컨테이너 이미지 지정
- **`--restart-Never`**
  - hello-world 이미지는 메시지를 출력하고 바로 종료되는 프로그램임
  - 쿠버네티스는 기본적으로 종료된 pod를 다시 살리려고 시도하기 때문에, 이를 방지하기 위해 재시작 옵션을 끔

Pod 상태를 확인한다.

```shell
assu@myserver01:~$ kubectl get pod
NAME          READY   STATUS      RESTARTS   AGE
hello-world   0/1     Completed   0          12s
```

**<Status 설명>**  
- `Completed`
  - 정상적으로 메시지를 출력하고 종료된 경우
- `StartError` / `CrashLoopBackOff`
  - 이미지 아키텍처(ARM/AMD)가 맞지 않거나, 컨테이너 런타임 설정 문제로 실행에 실패한 경우

---

# 4. 쿠버네티스 삭제 방법(클러스터 초기화)

설정이 꼬이거나, 처음부터 다시 구축하고 싶을 때 쿠버네티스를 완전히 삭제하고 초기화하는 방법이다.

이 과정은 모든 노드에서 수행해야 완전히 깨끗한 상태로 돌아간다.

---

**1) 패키지 삭제**

설치된 쿠버네티스 관련 패키지들을 삭제하고, 의존성 패키지들을 정리한다.

```shell
# purge 명령어로 설정 파일까지 포함하여 패키지 삭제
$ sudo apt-get purge kubeadm kubelet kubectl

# 시스템에서 사용하지 않는 패키지를 자동으로 삭제
$ sudo apt-get autoremove
```

---

**2) 관련 디렉터리 및 파일 삭제**

패키지 삭제만으로는 설정 파일이나 데이터가 남을 수 있다. 관련 디렉터리를 모두 수동으로 삭제한다.

```shell
# 쿠버네티스 설정 관련 .kube 디렉터리 삭제
$ sudo rm -rf ~/.kube
$ sudo rm -rf /etc/kubernetes/
$ sudo rm -rf /var/lib/kubelet/
$ sudo rm -rf /var/lib/etcd/
$ sudo rm -rf /etc/cni/
$ sudo rm -rf /opt/cni/
$ sudo rm -rf /var/log/pods/
$ sudo rm -rf /var/log/containers/
```

---

**3) 네트워크 설정 초기화**

CNI(Calico 등)나 쿠버네티스 프록시가 설정한 `iptables` 규칙을 초기화하여 네트워크를 깨끗한 상태로 되돌린다.

```shell
# 네트워크 설정(iptables) 초기화
$ sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

위 과정을 모두 마치면 서버는 쿠버네티스 설치 이전의 상태로 돌아간다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Doc:: containerd](https://kubernetes.io/ko/docs/setup/production-environment/container-runtimes/#containerd)
* [Doc:: kubeadm 설치하기](https://kubernetes.io/ko/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
* [Doc:: calico 설치](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises)
* [github:: flannel 설치](https://github.com/flannel-io/flannel)