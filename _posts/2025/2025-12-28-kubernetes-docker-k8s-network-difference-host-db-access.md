---
layout: post
title:  "Docker vs k8s 네트워크 차이: Django에서 로컬 DB 연결 시 Host IP의 차이"
date: 2025-12-28
categories: dev
tags: kubernetes k8s docker-networking django postgresql host-access pod-communication overlay-network bridge-network troubleshooting connection-refused
---

[2.2. Django 이미지 빌드(Host IP 연결)](https://assu10.github.io/dev/2025/11/28/docker-compose-nginx-django-postgresql-integration/#22-django-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EB%B9%8C%EB%93%9Chost-ip-%EC%97%B0%EA%B2%B0) 와 
여기 주소 수정
[2.2. Django 이미지 빌드](https://assu10.github.io/dev/2025/12/28/kubernetes-aa/#22-django-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EB%B9%8C%EB%93%9C) 를 보면 
Docker 환경과 k8s 환경에서의 로컬의 차이가 나온다.

---

**목차**

<!-- TOC -->
* [Docker 단독 실행 환경](#docker-단독-실행-환경)
* [Kubernetes 환경](#kubernetes-환경)
* [`HOST` 변경 이유](#host-변경-이유)
  * [네트워크의 주체가 다르다.(`docker0` vs `CNI`)](#네트워크의-주체가-다르다docker0-vs-cni)
  * ['로컬'의 정의가 다르다.](#로컬의-정의가-다르다)
  * [확장성을 고려한 표준 방식이다.](#확장성을-고려한-표준-방식이다)
* [요약](#요약)
<!-- TOC -->

---

Docker 환경에서 사용하던 Django 애플리케이션을 Kubernetes 환경에 배포하기 위해, 로컬(Node)에 설치된 PostgreSQL 데이터베이스를 바라보도록 설정을 수정한다.

# Docker 단독 실행 환경

```python
# ... 기존 코드 ...
DATABASES = {
    'default': {
        # ... 생략 ...
        'HOST': '172.17.0.1', # docker0 (Docker Host Gateway)
        'PORT': 5432,
    }
}
```

# Kubernetes 환경

```python
# ... 기존 코드 ...
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'postgres',
        'USER': 'postgres',
        'PASSWORD': 'mysecretpassword',
        'HOST': '10.0.2.4',   # Node의 실제 LAN IP (혹은 VM의 eth0 IP)
        'PORT': 5432,
    }
}
```

---

# `HOST` 변경 이유

## 네트워크의 주체가 다르다.(`docker0` vs `CNI`)

**Docker에서도 로컬이었고, k8s에서도 로컬인데 왜 `HOST` IP를 172.17.0.1 에서 10.0.2.4 로 변경했을까?**

이는 Docker 컨테이너와 Kubernetes Pod의 **네트워크 구조 차이** 때문이다.

---

**Docker 환경(172.17.0.1)**

Docker 데몬은 기본적으로 호스트에 `docker0` 이라는 가상 브리지 네트워크를 생성한다.  
컨테이너 입장에서 호스트는 바로 이 `docker0` 게이트웨이 너머에 있다. 그래서 172.17.0.1 로 접근하면 호스트의 프로세스(PostgreSQL)에 닿을 수 있다.  
컨테이너 내부에서 172.17.0.1 은 호스트 머신(Gateway)을 가리키는 가장 확실한 경로이다.

---

**Kubernetes 환경(10.0.2.4)**

Kubernetes는 Pod 간 통신을 위해 `docker0` 브리지를 사용하지 않고, 별도의 네트워크 플러그인인 CNI(Container Network Interface, 예: Calico, Flannel 등)를 
사용하여 자체적인 오버레이 네트워크(Pod 네트워크 구역)를 구성한다.

Pod 내부에서 172.17.0.1(docker0)으로의 접근은 네트워크 정책이나 CNI 설정에 따라 막혀있거나, 라우팅되지 않을 수 있다.  

따라서 Pod(Kubernetes 내부)에서 Node(Kubernetes 외부, 즉 호스트 OS)의 프로세스(PostgreSQL)에 접근하기 위해서는 **Node가 실제로 사용하고 있는 LAN IP(10.0.2.4)**를 
사용하여 명시적으로 밖으로 나가는 트래픽을 만들어야 한다.

Pod는 가상 네트워크(Overlay Network) 안에 격리되어 있으므로, Node의 물리적 인터페이스(eth0)의 IP인 10.0.2.4를 타겟으로 해야 호스트에 설치된 PostgreSQL에 도달할 수 있다.

---

## '로컬'의 정의가 다르다.

- **물리적 관점**
  - Django 컨테이너와 PostgreSQL 모두 10.0.2.4(myserver01) **같은 기계** 안에 있다.
- **네트워크 관점**
  - Kubernetes 환경에서 Pod 는 **논리적으로 완전히 격리된 별도의 네트워크 섬**에 떠 있는 것과 같다.
    - Pod 입장에서 `localhost`는 Pod 자기 자신만을 의미한다.
    - Pod 입장에서 호스트(Node)는 '자신이 떠 있는 서버'라기 보다는, **네트워크를 타고 나가서 만나야 하는 외부 서버**처럼 취급된다.

---

## 확장성을 고려한 표준 방식이다.

Kubernetes는 기본적으로 **클러스터(여러 대의 서버)** 환경을 가정한다.
- 만일 나중에 Django Pod가 myserver01 이 아니라 워커 노드인 myserver02에 스케줄링되어 뜬다면?
- 이 때도 172.17.0.1 과 같은 내부 IP는 의미가 없어진다.
- 하지만 10.0.2.4(DB가 설치된 서버의 실제 IP)로 설정해두면, Pod가 어느 노드에 뜨든 상관없이 네트워크를 통해 정확히 DB를 찾아갈 수 있다.

---

# 요약

|            | Docker(ex08 디렉터리)       | Kubernetes(ex01 디렉터리)         |
|:----------:|:-------------------------|:------------------------------|
|  네트워크 방식   | Docker Bridge(`docker0`) | k8s CNI(Pod Network)          |
| Host 접근 IP | 172.17.0.1(게이트웨이 IP)     | 10.0.2.4(노드 실제 IP)            |
|     비고     | 컨테이너가 호스트 브리지에 직접 연결됨    | Pod는 가상 네트워크 위에 있어 실제 IP로 통신함 |
