---
layout: post
title:  "Kubernetes - 우분투 환경 구성"
date: 2024-12-14
categories: dev
tags: devops kubernetes docker virtualbox vm virtual-machine ubuntu
---

도커와 쿠버네티스를 제대로 이해하려면 리눅스 기반 환경에서 실습해보는 것이 가장 좋다.  
이 포스트에는 버추얼박스 + 우분투 조합으로 리눅스 가상 환경을 구성하고, 도커와 쿠버네티스 실습 전 준비를 마치는 과정을 정리한다.

---

**목차**

<!-- TOC -->
* [1. 우분투 이미지 다운로드](#1-우분투-이미지-다운로드)
* [2. 버추얼박스 설치](#2-버추얼박스-설치)
* [3. 가상머신 생성](#3-가상머신-생성)
* [4. 가상머신에 우분투 설치](#4-가상머신에-우분투-설치)
* [5. 가상머신 네트워크 환경 설정](#5-가상머신-네트워크-환경-설정)
* [6. 가상 서버 접속](#6-가상-서버-접속)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 25.04
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 우분투 이미지 다운로드

[ubuntu-24.04.2-live-server-arm64.iso](https://cdimage.ubuntu.com/releases/24.04.2/release/) 다운로드

이 ISO 이미지를 사용해 가상 머신을 생성할 예정이다.

---

# 2. 버추얼박스 설치

버추얼박스는 가상머신을 생성할 수 있는 소프트웨어이다.  
앞으로 여러 개의 서버를 이용할 예정인데, 실제 물리 서버를 구축하는 것은 상당한 비용이 발생하므로 버추얼박스로 가상머신을 생성한 후 진행한다.

[VirtualBox-7.1.8-168469-macOSArm64.dmg](https://www.virtualbox.org/wiki/Downloads) 다운로드 후 설치한다.

---

# 3. 가상머신 생성

이제 버추얼박스와 우분투 이미지를 이용하여 가상머신을 생성한다.

- Hardware
  - Base Memory: 8192MB (쿠버네티스를 실행하려면 8192MB 이상 권장)
  - Processor: 4 CPU (1 CPU 는 우분투가 설치되지 않고, 쿠버네티스 실행이 어려움)
- Virtual Hard Disk
  - Disk: 100GB

![가상머신 생성](/assets/img/dev/2024/1214/vm.png)

---

# 4. 가상머신에 우분투 설치

생성한 가상머신의 설정으로 들어가 아래를 설정해준다.
- Display
  - Video Memory: 128MB (하지 않으면 가상머신의 화면이 안 보일수도 있음)
- Storage
  - _ubuntu-server01.vdi_ 아래 _Empty_ 선택 후 _Optical Drive_ 에서 _Choose a Disk File_ 에서 우분투 이미지 선택

VirtualBox Manager 화면에서 _Start_ 로 우분투 설치를 시작한다.

이어 나오는 화면에서 _Try or Install Ubuntu Server_ 를 선택하여 우분투 설치를 시작한다.  
다 기본 설정으로 넘어가다가 마지막 즈음에 _Install OpenSSH server_ 는 설치함으로 체크한다.

이 후 username 과 password 로 로그인한다.

---

네트워크와 관련된 도구를 모아놓은 프로그램인 `net-tools` 를 설치한다.

```shell
$ sudo apt install net-tools
```

`ifconfig` 로 아이피를 확인해본다.

우분투를 설치할 때 함께 설치한 OpenSSH server 의 실행 여부도 확인한다.

```shell
$ sudo systemctl start ssh

$ sudo systemctl status ssh
```

이제 가상머신 시스템 전원을 끈다.

---

# 5. 가상머신 네트워크 환경 설정

VirtualBox Manager 화면에서 좌측 상단의 _Tools > Network > NAT Networks_ 에서 우클릭 후 _Create_ 를 한다.  
그리고 _Enable DHCP_ 가 선택되었는지 확인한다.

이제 다시 좌측 상단에서 생성해 놓은 _ubuntu-server01_ 을 선택 후 _Settings_ 를 클릭한다.  
_Network > Adapter 1 > Attached to: NAT Network_ 선택 후 확인을 클릭한다.

_ubuntu-server01_ 를 시작한 후 `ifconfig` 로 아이피를 확인한다.

VirtualBox Manager 화면에서 좌측 상단의 _Tools > Properties > Port Forwarding > Create_ 를 한 후 Host Port, Guest Port 는 22, Guest IP 는 
ifconfig 로 확인한 아이피를 기입한다.

---

# 6. 가상 서버 접속

터미널에서 아래와 같이 입력한다.

```shell
$ ssh assu@127.0.0.1

assu@127.0.0.1's password:
Welcome to Ubuntu 24.04.2 LTS (GNU/Linux 6.8.0-59-generic aarch64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Mon May 12 07:29:50 AM UTC 2025

  System load:  0.0                Processes:               116
  Usage of /:   13.6% of 47.41GB   Users logged in:         1
  Memory usage: 2%                 IPv4 address for enp0s8: 10.0.2.4
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

63 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


Last login: Mon May 12 07:29:50 2025 from 10.0.2.2
assu@myserver01:~$
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)