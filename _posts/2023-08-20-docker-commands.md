---
layout: post
title:  "Docker 관련 명령어들"
date:   2023-08-20
categories: dev
tags: devops docker docker-commands  
---

이 포스팅에서는 도커 관련 명령어들에 대해 알아본다.   

---

**목차**

- [Docker 설치](#1-docker-설치)
- [Docker Image 관련 명령어들](#2-docker-image-관련-명령어들)
- [Docker Container 관련 명령어들](#3-docker-container-관련-명령어들)
- [Docker Image 저장소 관련 명령어들](#4-docker-image-저장소-관련-명령어들)

---

# 1. Docker 설치

도커는 리눅스 기반의 컨테이너 기술로 [도커 웹 사이트](https://docs.docker.com/) 에서 다운로드 가능하다.  

> [Rancher Desktop (Docker Desktop 유료화 대응)](https://assu10.github.io/dev/2022/02/02/rancher-desktop/) 와 함께 보시면 도움이 됩니다.

```shell
$ docker version

Client:
 Version:           23.0.1-rd
 API version:       1.41 (downgraded from 1.42)
 Go version:        go1.19.5
 Git commit:        393499b
 Built:             Fri Feb 10 16:53:44 2023
 OS/Arch:           darwin/amd64
 Context:           rancher-desktop

Server:
 Engine:
  Version:          20.10.20
  API version:      1.41 (minimum version 1.12)
  Go version:       go1.18.7
  Git commit:       03df974ae9e6c219862907efdd76ec2e77ec930b
  Built:            Wed Oct 19 02:58:31 2022
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v1.6.8
  GitCommit:        9cd3357b7fd7218e4aec3eae239db1f68a5a6ec6
 runc:
  Version:          1.1.4
  GitCommit:        5fd4c4d144137e991c4acebb2146ab1483a97925
 docker-init:
  Version:          0.19.0
  GitCommit:
```

---

# 2. Docker Image 관련 명령어들

호스트 머신에 있는 이미지 확인, 도커 이미지 저장소에 있는 이미지 복사, 호스트 머신에 있는 이미지 삭제하는 등의 명령어이다.

도커 이미지 저장소는 따로 설정하지 않으면 `hub.dockers.com` 이 이미지 저장소가 된다.

- `docker images`
  - 로컬 호스트 머신에 있는 도커 이미지 리스트들을 확인
- `docker rmi [option] image [iamge id]`
  - 로컬 호스트 머신에 있는 도커 이미지 삭제
  - 삭제하려는 이미지가 다른 이미지에 사용되고 있으면 삭제 불가, 이 때 강제로 삭제하려면 `-f` 옵션 설정
- `docker pull [image name]:[tag name]`
  - 도커 이미지 저장소에서 이미지 이름, 태그와 매칭되는 도커 이미지를 로컬 호스트 머신으로 복사
  - 태그명을 생략하면 최신을 뜻하는 `latest` 태그 이름으로 간주

```shell
$ docker pull mysql

$ docker pull mysql:8.0.16

$ docker iamges 
```

---

# 3. Docker Container 관련 명령어들

로컬 호스트에 있는 도커 이미지를 사용하여 도커 컨테이너를 생성할 수 있는데 이 도커 컨테이너를 실행,종료,제거 하는 명령어이다.

- `docker run [options] image [command] [arg...]`
  - 도커 이미지를 사용하여 컨테이터를 생성하는 동시에 실행
- `docker ps [options]`
  - 실행 중인 컨테이너 리스트 출력
  - `-a` 를 추가하면 종료 상태의 컨테이너 리스트까지 출력
- `docker stop`
  - 실행 중인 컨테이너를 종료 상태로 만듦 
- `docker start`
  - 종료 상태인 컨테이너를 실행 상태로 만듦
- `docker kill`
  - 컨테이너 강제 종료
- `docker rm`
  - 해당 컨테이너 삭제
- `docker exec -it bash`
  - 실행 중인 도커 컨테이너에 접속
  - 이때 사용하는 셸은 `bash`

도커 이미지를 사용하여 도커 컨테이너를 실행하는 명령어인 `run` 에서 사용하는 주요 옵션들은 아래와 같다.

- `-d`
  - 컨테이너를 백그라운드로 실행
  - 실행할 때 container id 출력
- `-h`
  - 호스트 이름 설정
- `--name`
  - 컨테이너 이름 설정
- `--restart`
  - 컨테이너가 있으면 재시작
- `-p`
  - 컨테이너 내부 포트와 외부 포트를 매핑하여 포트 포워딩
- `-expose`
  - 컨테이너 포트만 개방
- `-e`
  - 환경 변수 설정
- `-i`
  - 인터랙티브 모드로 컨테이너 실행
- `-rm`
  - 컨네이터 종료 후 자동으로 컨테이너 삭제
- `--env-file`
  - 환경 변수 파일 설정

docker-compose.yml 예시
```yaml
version: "3" # 파일 규격 버전
services: # 이 항목 밑에 실행하려는 컨테이너 들을 정의
   db: # 서비스 명
      #    image: mysql:5.7 # 사용할 이미지
      image: mysql:latest
      container_name: mysql-container # 컨테이너 이름 설정
      ports:
         - "13306:3306" # 접근 포트 설정 (컨테이너 외부:컨테이너 내부)
      environment: # -e 옵션
         MYSQL_ROOT_PASSWORD: "test"  # MYSQL 패스워드 설정 옵션
         #      - TZ=Asia/Seoul
      command: # 명령어 실행
         - --sql_mode=
      volumes:
         - ~//Developer/Volumes/mysql8:/var/lib/mysql --user 1000
```

```shell
# 도커 내부의 3306번 포트와 호스트 머신의 3306번 포트를 연결하여 오픈, 그래서 외부의 인스턴스가 3306번 포트를 사용하여 도커 컨테이너의 mysql 에 접속 가능
$ docker run -d -p 3306:3306 \  
-e MYSQL_ROOT_PASSWORD=test \  # 도커를 실행할 때는 환경변수 MYSQL_ROOT_PASSWORD 에 암호 설정 
--name hotel-mysql mysql:latest \  # 실행하는 도커 컨테이너명은 hotel-mysql 이며, 도커 이미지명과 태그는 mysql:latest 임
--character-set-server-utf8mb4 \  #  
--collation-server=utf8mb4_unicode_ci

# 도커 컨테이너 내부에 접속
$ docker exec -it hotel-mysql bash

$ docker stop d7d0d335dab5  # 도커 컨테이너 상태를 종료 상태로 만듦

$ docker ps -a 

$ docker rm -f d7d0d335dab5  # 도커 컨테이터 강제 삭제
```

---

# 4. Docker Image 저장소 관련 명령어들

도커 이미지는 도커 이미지 저장소에서 관리한다.

도커 컨테이너를 배포하기 위해 도커 이미지를 만들어 저장소에 등록하고, 이를 이용하여 호스트 서버에서 도커 컨테이너를 실행한다.

- `docker commit [container id] [username/imagename]`
  - 로컬 시스템에 수정된 컨테이너를 사용하여 새로운 이미지 생성
  - `username/imagename` 을 사용하여 이미지 저장소에 저장되는 위치와 이미지명 지정
- `docker login`
  - 이미지 저장소에 로그인
  - 기본 이미지 저장소는 도커 허브
- `docker push [username/imagename]`
  - 로컬 시스템에 생성된 도커 이미지를 도커 저장소로 전달
- `docker build [path to dockerfile]`
  - dockerfile 을 사용하여 이미지를 빌드

아래는 실행 중인 컨테이너를 사용하여 도커 이미지를 만드는 예시이다.
```shell
# 로컬 호스트 머신에서 실행 중인 컨테이터를 사용하여 assu/local-hotel-mysql 이라는 이미지 생성
$ docker commit 344232432 assu/local-hotel-mysql

# 이미지가 잘 생성되었는지 확인
$ docker images
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [도커 웹 사이트](https://docs.docker.com/)