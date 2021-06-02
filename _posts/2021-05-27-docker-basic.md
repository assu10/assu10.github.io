---
layout: post
title:  "Docker 개요"
date:   2021-05-27 10:00
categories: dev
tags: docker container
---

이 포스트는 Docker 를 알아보기 전 알아야 할 컨테이너와 docker 의 개요 대해 기술한다.

>- 컨테이너란?
>- docker 개요
>- docker 기능

---

## 1. 컨테이너란?

docker 를 이해하기 전에 컨테이너에 대해 알아보자.

**컨테이너** 는 호스트 OS 상에 논리적인 구획(컨테이너)를 만들고 애플리케이션을 기동시키기 위해 필요한 라이브러리 등을 하나로 모아
마치 별도의 서버인 것처럼 사용할 수 있게 만든 것을 말한다.

즉, 호스트 OS 의 리소스를 논리적으로 분리시킨 후 여러 개의 컨테이너가 공유하는 방식이다.

컨테이너를 사용하면 OS, IP 주소 등과 같은 시스템 자원을 마치 각 애플리케이션이 점유하고 있는 것처럼 사용이 가능하다.

>**서버 가상화**<br /><br />
>**호스트형 서버 가상화**<br />
>- 하드웨어에 베이스가 되는 호스트 OS 설치 후 호스트 OS 에 가상화 소프트웨어를 설치하여
>이 가상화 소프트웨어 위에서 게스트 OS를 작동시키는 기술<br />
>- 컨테이너와 다르게 호스트 OS 상에서 다른 게스트 OS 를 구동시키므로 가상화를 수행하기 위한 CPU 자원/메모리 사용량 등의 오버헤드가 큼.<br />
>- Oracle 의 *Oracle VM VirtualBox* 나 VMware 의 *VMware Workstation Player* 등이 있음.
>
>**하이퍼바이저형 서버 가상화**<br />
>- 하드웨어에 가상화 소프트웨어인 *하이퍼바이저* 를 배치하여 하드웨어와 가상 환경을 제어<br />
>- 호스트 OS 없이 하드웨어를 직접 제어하므로 효율적인 자원 사용이 가능하지만,<br />
>가상 환경마다 별도의 OS 가 작동하므로 가상 환경의 시작에 걸리는 오버헤드가 큼<br />
>- Microsoft Windows Server 의 *Hyper-V* 나 Citrix 의 *XenServer* 등이 있음.

컨테이너 - 애플리케이션의 실행 환경을 한 곳에 모아둠으로써 애플리케이션의 이식성을 높임<br />
가상화 기술 - 서로 다른 환경을 효율적으로 에뮬레이트하기 위함


---

## 2. docker 개요

**docker** 란 컨테이너 기술을 사용하여 애플리케이션의 실행 환경을 구축/운영하기 위한 플랫폼으로<br />
애플리케이션 실행에 필요한 환경을 **docker image** 라는 하나의 이미지로 관리함으로써 애플리케이션의 이식성을 높일 수 있다.<br />
docker 내부적으로 컨테이너 기술을 사용하고 있다.

컨테이너의 바탕이 되는 docker image 는 **Docker Hub** 와 같은 repository 에서 공유한다.

---

## 3. docker 기능

docker 의 기능은 크게 3가지로 나눌 수 있다.

- build (docker image 생성)
- ship (docker image 공유)
- run (docker 컨테이너 작동)

---

## 3.1. build (docker image 생성)

docker 는 애플리케이션 실행에 필요한 라이브러리, 미들웨어, 네트워크 설정 등을 하나로 모아 docker image 를 생성한다.

**docker image** 는 애플리케이션 실행에 필요한 파일들이 저장된 디렉토리라고 볼 수 있다.<br />
docker image 는 docker 명령을 통해 수동으로 만들 수도 있고, **Dockerfile** 이라는 설정 파일을 이용하여 자동으로 만들 수도 있다.<br />
CI/CD 관점에서 코드에 의한 인프라 구성을 관리하는 것을 추천하므로 수동 생성보다는 Dockerfile 을 통해 관리하는 것이 좋다.

---

## 3.2. ship (docker image 공유)

docker image 는 **docker registry** 에서 공유할 수 있다.<br />
docker 의 공식 레지스트리인 **[Docker Hub](https://hub.docker.com/)** 에서는 *base image* 를 배포하는데<br />
이러한 *base image 에 미들웨어, 라이브러리를 넣은 이미지를 겹쳐 개별 docker image 를 만들어나가면 된다.

>**base image**<br />
>Ubuntu, CentOS 와 같은 Linux 배포판의 기본 기능 제공<br />
>Ubuntu 용 이미지, CentOS 용 이미지, Node.js 용 이미지, MongoDB 용 이미지, Nginx 용 이미지 등...

Docker Hub 는 Github 나 Bitbucket 과 연동하여 자동으로 이미지를 생성할 수도 있다.<br />
예를 들어 Github 에서 Dockerfile 을 관리하고, 거기서 이미지를 자동으로 생성한 후 Docker Hub 에 공개하는 것이 가능한데
이렇게 이미지를 자동 생성하는 것을 **Automated Build** 라고 한다.

---

## 3.3. run (docker 컨테이너 작동)

docker 가 설치된 환경이라면 docker image 만으로 컨테이너를 작동시킬 수 있다.

docker 는 하나의 linux 커널을 여러 개의 컨테이너에서 공유하는데<br />
컨네이너 동작하는 프로세스는 하나의 그룹으로 관리하고, 각 그룹마다 파일 시스템이나 호스트명, 네트워크 등을 할당하여 사용한다.<br />
(=그룹이 다르면 파일 액세스 불가)

보통 컨테이너 관리는 오케스트레이션 툴을 이용하는데 이 오케스트레이션 툴은 분산 환경에서 컨테이너를 가동시키기 위해 필요한 기능을 제공한다. 
 

---

## 3.4. docker 에디션

docker 는 **Docker Community Edition(CE)** 와 **Docker Enterprise Edition(EE)** 로 제공이 되고 있다.

- **Docker CE**
    - 무료 docker 에디션
    
- **Docker EE**
    - 상용 docker 에디션
    - Basic, Standard, Advanced 로 나뉨
        - Basic : Docker Store 에서 인증이 끝난 컨테이너와 플로그인 제공
        - Standard : Basic + LDAP(Lightweight Directory Access Protocol) 이나 Active Directory 와 통합 가능한 Docker Datacenter 이용 가능
        - Advanced : 보안 기능 제공

본 블로그에선 docker CE 기능을 위주로 다룰 예정이며,
docker CE 의 지원 플랫폼은 아래와 같다.

- 서버 OS 용
    - Ubuntu
    - Debian
    - CentOS
    - Fedora
- public cloud 용
    - Microsoft Azure
    - AWS
- 클라이언트 OS 용
    - Microsoft Windows 10
    - macOS

---

## 3.5. docker 컴포넌트

- **docker engine**
    - docker image 생성 및 컨테이너 기동

- **docker registry**
    - docker image 공유
    - docker 의 공식 레지스트리 서비스인 docker hub 도 docker registry 사용

- **docker compose**
    - 컨테이너들을 관리하기 위한 툴로 컨테이너 구성 정보를 코드로 정의하여 애플리케이션 실행 환경을 구성

- **docker machine**
    - 클라우드 환경에 docker 실행 환경을 명령으로 자동 생성하기 위한 툴
    
- **docker swarm**
    - 여러 docker 호스트를 클러스터화하기 위한 툴
    - Kubernetes 를 이용하거나 아래처럼 역할을 나눔
    - Manager : 클러스터 관리, API 제공
    - Node : docker 컨테이너 실행
      
>주요 퍼블릭 클라우스 업체는 컨테이너 실행환경의 풀 매니지드 서비스 제공<br />
>예) *Amazon EC2 Container Service*, *Azure Container Service*, *Google Kubernetes Engine* ...<br />
>Jenkins 와 연계하여 테스트 자동화도 가능<br />
>GitHub 와 연동하여 GitHub 에서 소스가 관리되는 Dockerfile 를 Docker Hub 와 연계하여 자동 빌드 및 docker image 생성 가능

---

*본 포스트는 Asa Shiho 저자의 **완벽한 IT 인프라 구축을 위한 Docker 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [완벽한 IT 인프라 구축을 위한 Docker 2판](http://www.yes24.com/Product/Goods/64728692)
* [Docker Hub](https://hub.docker.com/)
* [LDAP 개념 잡기](https://yongho1037.tistory.com/796)
* [docker document](https://docs.docker.com/get-docker/)
* [mobyproject](http://mobyproject.org/)