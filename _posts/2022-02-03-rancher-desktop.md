---
layout: post
title:  "Rancher Desktop (Docker Desktop 유료화 대응)"
date:   2022-02-02 10:00
categories: dev
tags: devops rancher-desktop
---

이 포스트는 Docker Desktop 유료화에 따라 Docker Desktop 을 대체할 수 있는 `Rancher Desktop` 에 대해 알아보고,
최종적으로 Rancher Desktop 에서 관리하는 Docker 를 이용하여 mysql 을 띄워본다.


> - Kubernetes 와 Docker 비교
> - Docker Desktop 대체 방안들
>   - VM + minikube
>   - Rancher Desktop
> - Rancher Desktop 설치 및 mysql docker container 띄우기

---

## 1. Kubernetes 와 Docker 비교

> 아주 간단하게만 비교한 글입니다. 자세한 내용은 구글링 해보세요.

Kubernetes 와 Docker 비교해보자면 아래와 같이 비교해볼 수 있다.

- 컨테이너를 하나 띄워서 사용 -> Docker 사용
- x월 x일에 10개의 Container 를 자동 생성 -> Kubernetes 사용

Kubernetes 는 **컨테이너 오케스트레이션 툴** 이다.

Docker 는 **기술적인 개념, 도구** 이고, Kubernetes 는 **Docker 를 관리하는 툴** 로 이해하면 될 것 같다.

이미지를 컨테이너에 띄우고 실행하는 기술이 `Docker` 이고,  
이런 Docker 컨테이너를 관리하는 서비스가 `Kubernetes` 이다.

`VM(가상 머신)` 과 `컨테이너`의 차이점에 대해서도 간략히 보면 아래와 같다.

![VM vs Container](/assets/img/dev/2022/0202/vm_container.png)

- **VM**
  - Server -> Hypervisor -> 각각의 Guest OS 가 설치된 VM 구동
  - 가상 머신의 모든 자원을 사용
- **Container**
  - Server -> Host OS -> Docker Engine -> Container start
  - CPU, RAM, Disk, Network 같은 운영체제의 자원을 필요한만큼 격리하여 컨테이너에 할당하여 사용
  - 독립적, 동적

---

## 2. Docker Desktop 대체 방안들

구글링을 좀 해보니 Docker Desktop 의 대체 방안으로 `VM + minikube` or `Rancher Desktop` 이렇게 크게 2가지로 나뉘는 것 같다.

---

### 2.1. VM + minikube

`minikube` 는 가벼운 쿠버네티스 구현체이며, 로컬 머신에 VM 을 만들어 하나의 노드로 구성된 간단한 클러스터를 생성하는 로컬 쿠버네티스 엔진이다.  
(쿠버네티스와 비교하자면 쿠버네티스는 컨테이너의 클러스터를 단일 시스템으로 관리하는 것)

쿠버네티스는 마스터 노드와 하나 이상의 워커 노드로 구성되어 있는데  
단순 개발 테스트를 위해 플랫폼 구성이 어려운 상황에서 마스터 노드의 일부 기능과 개발/배포를 위한 단일 워커 노드를 제공해주는
간단한 쿠버네티스 플랫폼 환경을 제공해준다.

즉, 로컬 머신에 VM 을 만들고 하나의 노드로 구성된 간단한 클러스터를 배포하는 가벼운 쿠버네티스 구현체라고 보면 된다.

---

### 2.2. Rancher Desktop

`Rancher Desktop` 은 데스크탑 쿠버네티스 및 컨테이너 관리를 위한 오픈 소스 앱으로 쿠버네티스용 GUI 라고 볼 수 있다.  
(쿠버네티스 컨테이너를 관리할 수 있는 오픈소스 프로그램)

내부적으로 컨테이너 엔진으로 `containerd` or `dockerd` 를 사용하여 `netdctl` or `docker cli` 가  사용 가능하다.  
어느 컨테이너 엔진을 사용할지는 설치 후에도 변경 가능하다.

![Rancher Desktop](/assets/img/dev/2022/0202/rancher_desktop.png)

---

보통 하나의 컨테이너만 띄울 거라 Rancher Desktop 이 오버 스펙같지만...  
별도로 VM 을 설치하기 번거롭고, 여러 개의 컨테이너를 띄울 때 프로필 변경 등 좀 불편할 것 같아서 Rancher Desktop 을 설치하여 테스트해보기로 했다.

---

## 3. Rancher Desktop 설치 및 mysql docker container 띄우기

[https://rancherdesktop.io/](https://rancherdesktop.io/) 에 접속하여 각 OS 에 맞는 install 파일을 다운로드 받아 설치한다.

![Rancher Desktop](/assets/img/dev/2022/0202/rancher1.png)
![Rancher Desktop](/assets/img/dev/2022/0202/rancher2.png)

mysql docker image 를 다운받는다.

```shell
docker pull mysql:latest
```

Rancher Desktop 의 [Images] 탭에 들어가보면 방금 다운받은 mysql 이미지가 조회된다.

![Rancher Desktop](/assets/img/dev/2022/0202/mysql.png)

이제 기존에 사용하던 Docker cli 그대로 mysql container 를 띄울 수 있다.

```shell
docker run --name mysql-container \
    -v ~/Developer/Volumes/mysql8:/var/lib/mysql --user 1000 \
    -e MYSQL_ROOT_PASSWORD=password \
    -p 3306:3306 \
    -d mysql:latest \
    --sql_mode=""
```

![mysql 연결](/assets/img/dev/2022/0202/mysql_connection1.png)
![mysql 연결](/assets/img/dev/2022/0202/mysql_connection2.png)


`docker-compose` 로 띄울 때는 docker-compose 설치 후 기존에 사용하던 방식 그대로 띄우면 된다.

```shell
> brew install docker-compose
```

docker-compose.yml
```yaml
version: "3" # 파일 규격 버전
services: # 이 항목 밑에 실행하려는 컨테이너 들을 정의
   db: # 서비스 명
      #    image: mysql:5.7 # 사용할 이미지
      image: mysql:latest
      container_name: mysql-container # 컨테이너 이름 설정
      ports:
         - "3306:3306" # 접근 포트 설정 (컨테이너 외부:컨테이너 내부)
      environment: # -e 옵션
         MYSQL_ROOT_PASSWORD: "password"  # MYSQL 패스워드 설정 옵션
         #      - TZ=Asia/Seoul
      command: # 명령어 실행
         - --sql_mode=
      volumes:
         - ~//Developer/Volumes/mysql8:/var/lib/mysql --user 1000
```

```shell
> docker-compose up -d
```

---

쓰고 보니 엄청 간단한데.. Rancher Desktop 으로 docker 를 어떻게 사용한다는 건지 이해가 잘 안가서 많이 헤맸다.

뿌듯 ^^

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [Rancher Desktop 공홈](https://rancherdesktop.io/)
* [Rancher Doc](https://rancher.com/docs/rancher/v2.6/en/)
* [[Kubernetes] 도커와 쿠버네티스 간단 비교](https://wooono.tistory.com/109)
* [Mac에서 Docker Desktop 사용하지 않고 Docker 사용하기 (feat. minikube)](https://blog.bsk.im/2021/09/07/macos-docker-without-docker-feat-minikube-ko/)
* [minikube로 docker와 docker-compose를 대체하기](https://novemberde.github.io/post/2021/09/02/podman-minikube/)
* [minikube를 이용한 kubernetes 입문 : 네이버 블로그](https://m.blog.naver.com/PostView.naver?isHttpsRedirect=true&blogId=sharplee7&logNo=221737855770)
* [Rancher Desktop v1.0.0 개인Blog](https://www.098.co.kr/rancher-desktop-v1-0-0/)
* [rancher desktop 퀵가이드 : 네이버 블로그](https://blog.naver.com/PostView.naver?blogId=timberx&logNo=222495764063&parentCategoryNo=5&categoryNo=&viewDate=&isShowPopularPosts=true&from=search)
* [[쿠버네티스 Kubernetes] Rancher(멀티 Kubernetes 클러스터 관리)설치 - Wings on PC](https://wings2pc.tistory.com/entry/%EC%BF%A0%EB%B2%84%EB%84%A4%ED%8B%B0%EC%8A%A4-Kubernetes-Rancher%EB%A9%80%ED%8B%B0-Kubernetes-%ED%81%B4%EB%9F%AC%EC%8A%A4%ED%84%B0-%EA%B4%80%EB%A6%AC%EC%84%A4%EC%B9%98)
* [RANCHER 소개 : 네이버 블로그](https://m.blog.naver.com/PostView.naver?isHttpsRedirect=true&blogId=bokmail83&logNo=221185526838)
* [Switch from Docker Desktop to Rancher Desktop in 5 Minutes ](https://blog.tilt.dev/2021/09/07/rancher-desktop.html)
* [유료로 전환되는 도커 데스크탑 대체하기 (Mac m1)](https://giljae.medium.com/%EC%9C%A0%EB%A3%8C%EB%A1%9C-%EC%A0%84%ED%99%98%EB%90%98%EB%8A%94-%EB%8F%84%EC%BB%A4-%EB%8D%B0%EC%8A%A4%ED%81%AC%ED%83%91-%EB%8C%80%EC%B2%B4%ED%95%98%EA%B8%B0-mac-m1-ce9d5da88f31)
* [Rancher Desktop - A Docker Desktop Replacement - Kodeworx](http://kodeworx.net/posts/rancher_desktop_a_docker_desktop_replacement/)