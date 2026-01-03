---
layout: post
title:  "Kubernetes - 깃허브 액션과 ArgoCD를 활용한 CI/CD 파이프라인 구축"
date: 2025-12-31 10:00:00
categories: dev
tags: devops kubernetes k8s ci-cd github-actions argocd gitops docker metallb helm automation continuous-integration continuous-delivery
---

클라우드 네이티브 환경에서 애플리케이션을 신속하고 안정적으로 배포하는 것은 선택이 아닌 필수이다.  
수동으로 컨테이너를 빌드하고 배포하는 과정은 비효율적일 뿐만 아니라 휴먼 에러를 유발할 수 있기 때문이다.

이번 포스트에서는 **지속적 통합(Continuous Integration)**과 **지속적 전달/배포(Continuous Delivery 혹은 Deployment)** 과정을 
자동화하는 방법에 대해 알아본다.

특히 개발자들에게 익숙한 **깃허브 액션**을 이용하여 CI를 구성하고, 쿠버네티스 환경의 배포 표준으로 자리 잡고 있는 GitOps 도구인 **ArgoCD**를 활용하여 
CD를 구현해본다.

---

**목차**

<!-- TOC -->
* [1. CI/CD의 이해](#1-cicd의-이해)
* [2. 사전 준비 사항](#2-사전-준비-사항)
  * [2.1. metalLB 설치 확인](#21-metallb-설치-확인)
  * [2.2. 깃허브 가입](#22-깃허브-가입)
  * [2.3. 깃 설치](#23-깃-설치)
* [3. 깃허브(Github) 액션을 통한 소스코드 관리](#3-깃허브github-액션을-통한-소스코드-관리)
  * [3.1. 깃허브 액션을 사용한 Hello World! 출력](#31-깃허브-액션을-사용한-hello-world-출력)
  * [3.2. 깃허브 액션을 통한 도커 컨테이너 실행](#32-깃허브-액션을-통한-도커-컨테이너-실행)
    * [3.2.1. 프로젝트 디렉터리 및 코드 준비](#321-프로젝트-디렉터리-및-코드-준비)
    * [3.2.2. GitHub Actions 워크플로 작성](#322-github-actions-워크플로-작성)
    * [3.2.3. 코드 푸시 및 결과 확인](#323-코드-푸시-및-결과-확인)
* [4. ArgoCD를 활용한 CD](#4-argocd를-활용한-cd)
  * [4.1. ArgoCD 설치](#41-argocd-설치)
  * [4.2. ArgoCD를 활용한 깃허브 실습](#42-argocd를-활용한-깃허브-실습)
    * [4.2.1. 배포용 매니페스트 작성 및 Push](#421-배포용-매니페스트-작성-및-push)
    * [4.2.2. ArgoCD 애플리케이션 연동](#422-argocd-애플리케이션-연동)
    * [4.2.3. 배포 확인 및 상태 변경](#423-배포-확인-및-상태-변경)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Guest OS: Ubuntu 24.04.2 LTS
- Host OS: Mac Apple M3 Max
- Memory: 48 GB

---

# 1. CI/CD의 이해

애플리케이션 개발 프로젝트는 댜수의 개발자가 동시에 참여하여 진행한다. 서로 다른 기능을 개발하는 개발자들이 각자의 코드를 하나로 통합하는 과정은 필수적이며, 
이 과정에서 충돌을 해결하고 정합성을 검증하는 일은 매우 중요하다.

이러한 통합과 배포 작업이 하루에도 여러 번 발생할 수 있는데, 이를 수동으로 처리한다면 엄청난 리소스 낭비과 휴먼 에러를 유발하게 된다.  
이를 해결하기 위해 등장한 개념이 **CI/CD**이다.

---

**CI(Continuous Integration, 지속적 통합)**

CI는 개발자가 작성한 코드를 공유 리포지토리에 지속적으로 통합하고, 이 과정에서 빌드 및 테스트를 자동화하는 프로세스를 의미한다.

- **프로세스**
  - 개발자가 코드를 Git과 같은 버전 관리 시스템에 push하면, CI 서버(Github Actions, Jenkins 등)가 트리거되어 코드를 가져오고, 빌드하며, 단위 테스트 등을 자동으로 수행한다.
- **장점**
  - 버그를 조기에 발견할 수 있어 배포 위험을 획기적으로 줄이고, 소프트웨어의 품질을 일정 수준 이상으로 유지할 수 있다.

---

**CD(Continuous Delivery/Deployment, 지속적 전달/배포)**

CD는 CI과정을 통과한 코드를 실제 사용자에게 서비스하기 위해 배포하는 단계를 자동화하는 것이다.  
용어는 비슷해 보이지만 범위에 따라 두 가지로 나뉜다.

- **지속적 전달(Continuous Delivery)**
  - 코드를 운영 환경에 배포하기 전, 프로덕션과 유사한 스테이징 환경까지 배포하거나 배포 승인 단계까지 준비해두는 것을 의미한다.
  - 실제 배포는 수동 트리거가 필요할 수 있다.
- **지속적 배포(Continuous Deployment)**
  - 코드 변경 사항이 파이프라인의 모든 단계를 통과하면 사람의 개입 없이 자동으로 프로덕션 환경까지 배포되는 것을 의미한다.

이번 포스트에서는 **Github Actions**를 활용하여 CI를 구축하고, 쿠버네티스 환경의 배포를 위해 **ArgoCD**를 활용하여 CD를 실습해본다.

---

# 2. 사전 준비 사항

먼저 로드밸런서 구성과 Git 환경 설정이 필요하다.

먼저 [metalLB](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-loadbalancer-for-bare-metal/)가 올바르게 설치되었는지 확인한 후 Github에 가입하고 Git을 설치한다.

---

## 2.1. metalLB 설치 확인

> metalLB 는 [4.1. ArgoCD 설치](#41-argocd-설치) 에서 사용됩니다.

이 포스트에서는 베어메탈(Bare-metal) 혹은 온프레미스 VM 환경을 가정하므로, LoadBalancer 타입의 서비스를 사용하기 위해 [**MetalLB**](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-loadbalancer-for-bare-metal/)가 필요하다.

> metalLB가 설치되어 있지 않다면 [5. metalLB를 통한 베어메탈 LoadBalancer 구성](https://assu10.github.io/dev/2025/12/22/kubernetes-ingress-helm-metallb-baremetal-loadbalancer/#5-metallb%EB%A5%BC-%ED%86%B5%ED%95%9C-%EB%B2%A0%EC%96%B4%EB%A9%94%ED%83%88-loadbalancer-%EA%B5%AC%EC%84%B1)을 참고하세요.

아래 명령어로 설치 상태를 확인한다.

```shell
# 헬름을 통한 설치 확인
assu@myserver01:~$ helm ls --namespace mymetallb
NAME              	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART         	APP VERSION
metallb-1766834438	mymetallb	1       	2025-12-27 11:20:39.760663539 +0000 UTC	deployed	metallb-0.15.3	v0.15.3

# mymetallb 네임스페이스에서 작동 중인 오브젝트 확인
assu@myserver01:~$ kubectl get all --namespace mymetallb
NAME                                               READY   STATUS    RESTARTS   AGE
pod/metallb-1766834438-controller-66c6c584-kbwdn   1/1     Running   0          6d19h
pod/metallb-1766834438-speaker-7sjlw               4/4     Running   0          6d19h
pod/metallb-1766834438-speaker-j99kv               4/4     Running   0          6d19h
pod/metallb-1766834438-speaker-zkktj               4/4     Running   0          6d19h

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/metallb-webhook-service   ClusterIP   10.97.206.62   <none>        443/TCP   6d19h

NAME                                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/metallb-1766834438-speaker   3         3         3       3            3           kubernetes.io/os=linux   6d19h

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/metallb-1766834438-controller   1/1     1            1           6d19h

NAME                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/metallb-1766834438-controller-66c6c584   1         1         1       6d19h
```

Controlelr와 Speaker 파드가 모두 `Running` 상태이고, Webhook 서비스가 정상적으로 떠 있다면 준비가 완료된 것이다.

---

## 2.2. 깃허브 가입

GitHub Actions를 사용하기 위해서는 GitHub 계정이 필수이다. 계정이 없다면 가입을 진행한다.

---

## 2.3. 깃 설치

로컬 환경에서 코드를 작성하고 깃허브로 전송하기 위해 Git 클라이언트를 설치하고 기본 설정을 진행한다.

```shell
# Git 설치
assu@myserver01:~$ sudo apt install git-all
Reading package lists... Done
Building dependency tree... Done
...

# 사용자 정보 설정(커밋 로그에 남을 정보)
assu@myserver01:~$ git config --list
assu@myserver01:~$ git config --global user.name <이름>
assu@myserver01:~$ git config --global user.email <이메일>

assu@myserver01:~/work$ ls
app  ch04  ch05  ch06  ch09  ch10

# 작업 디렉터리 초기화
assu@myserver01:~/work$ git init
```

---

# 3. 깃허브(Github) 액션을 통한 소스코드 관리

**GitHub Actions**는 깃허브 리포지토리 내에서 바로 소프트웨어 개발 워크플로를 자동화할 수 있게 해주는 강력한 CI/CD 도구이다.  
별도의 CI 서버를 구축할 필요 없이 YAML 파일 설정만으로 빌드, 테스트, 배포 파이프라인을 정의할 수 있다.

---

## 3.1. 깃허브 액션을 사용한 Hello World! 출력

가장 기본적인 워크플로를 작성하여 동작 방식을 이해해본다.  
먼저 깃허브 웹사이트에서 *github-action-practice* 라는 이름의 리포지토리를 생성한다.

리포지토리 생성 후 **Actions** 탭으로 이동하여 새로운 워크 플로를 생성한다.

![액션 워크플로 생성](/assets/img/dev/2025/1231/workflow.png)

그 다음에 뜨는 *github-action-practice/.github/workflows/main.yml* 파일 편집기에 아래 내용을 작성한다.

```yaml
# 워크플로 이름
name: HelloWorld

# 트리거 조건: 코드가 push 될 때 실행
on: [push]

# 수행할 작업 정의
jobs:
  echo:  # 작업(Job) 식별자
    runs-on: ubuntu-latest  # 실행될 환경(Runner) 지정 (Ubuntu 최신 버전)
    steps:  # 순차적으로 실행될 단계들
      - name: hello  # 실행 단계의 이름
        run: echo "Hello, World!"  # 실행할 쉘 명령어
```

![main.yml 파일 생성](/assets/img/dev/2025/1231/mainyml.png)

작성 후 커밋하면 GitHub Actions가 자동으로 main.yml을 감지하여 실행한다.  
**Actions** 탭에서 *Create main.yml* 워크플로 실행 내역을 확인할 수 있다.

![액션 확인 1](/assets/img/dev/2025/1231/action1.png)
![액션 확인 2](/assets/img/dev/2025/1231/action2.png)

실행된 *echo* 작업을 클릭하면 상세 로그를 볼 수 있다.

![워크플로 확인](/assets/img/dev/2025/1231/workflow2.png)

로그를 자세히 살펴보면 다음과 같은 정보를 얻을 수 있다.

```text
Current runner version: '2.330.0'
Runner Image Provisioner
  Hosted Compute Agent
  Version: 20251211.462
  Commit: 6cbad8c2bb55d58165063d031ccabf57e2d2db61
  Build Date: 2025-12-11T16:28:49Z
  Worker ID: {4ff93d9d-3120-4526-890c-90592f60e50a}
Operating System
  Ubuntu
  24.04.3
  LTS
Runner Image
  Image: ubuntu-24.04
  Version: 20251215.174.1
  Included Software: https://github.com/actions/runner-images/blob/ubuntu24/20251215.174/images/ubuntu/Ubuntu2404-Readme.md
  Image Release: https://github.com/actions/runner-images/releases/tag/ubuntu24%2F20251215.174
GITHUB_TOKEN Permissions
  Contents: read
  Metadata: read
  Packages: read
Secret source: Actions
Prepare workflow directory
Prepare all required actions
Complete job name: echo
```

---

## 3.2. 깃허브 액션을 통한 도커 컨테이너 실행

이제 단순한 텍스트 출력을 넘어, 실제 애플리케이션을 도커 이미지로 빌드하고 컨테이너로 실행하는 CI 파이프라인을 구축해본다.

---

### 3.2.1. 프로젝트 디렉터리 및 코드 준비

먼저 로컬 작업 환경을 구성하고 원격 리포지토리를 clone 한다.

```shell
assu@myserver01:~/work$ ls
app  ch04  ch05  ch06  ch09  ch10
assu@myserver01:~/work$ mkdir ch11
assu@myserver01:~/work$ cd ch11
assu@myserver01:~/work/ch11$ mkdir ex01
assu@myserver01:~/work/ch11$ cd ex01
```

```shell
assu@myserver01:~/work/ch11/ex01$ git clone https://github.com/assu/github-action-practice.git
Cloning into 'github-action-practice'...
...
Receiving objects: 100% (5/5), done.

assu@myserver01:~/work/ch11/ex01$ ls
github-action-practice

assu@myserver01:~/work/ch11/ex01$ cd github-action-practice/

assu@myserver01:~/work/ch11/ex01/github-action-practice$ ls

assu@myserver01:~/work/ch11/ex01/github-action-practice$ ls -al
total 16
drwxrwxr-x 4 assu assu 4096 Jan  3 08:04 .
drwxrwxr-x 3 assu assu 4096 Jan  3 08:04 ..
drwxrwxr-x 8 assu assu 4096 Jan  3 08:04 .git
drwxrwxr-x 3 assu assu 4096 Jan  3 08:04 .github

assu@myserver01:~/work/ch11/ex01/github-action-practice$ cd .github/workflows/
assu@myserver01:~/work/ch11/ex01/github-action-practice/.github/workflows$ ls -al
total 12
drwxrwxr-x 2 assu assu 4096 Jan  3 08:04 .
drwxrwxr-x 3 assu assu 4096 Jan  3 08:04 ..
-rw-rw-r-- 1 assu assu  136 Jan  3 08:04 main.yml

assu@myserver01:~/work/ch11/ex01/github-action-practice/.github/workflows$ cat main.yml
name: HelloWorld

on: [push]

jobs:
  echo:
    runs-on: ubuntu-latest
    steps:
      - name: hello
        run: echo "Hello, World!"
```

---

**Dockerfile 작성**

애플리케이션을 컨테이너화하기 위한 명세서이다.

```shell
assu@myserver01:~/work/ch11/ex01/github-action-practice$ vim Dockerfile
```

```dockerfile
# 베이스 이미지로 Python 3.13.9 버전을 사용
FROM python:3.13.9

# 컨테이너 내 작업 디렉터리를 /usr/src/app 으로 설정
WORKDIR /usr/src/app

# 현재 디렉터리의 모든 파일을 컨테이너의 작업 디렉터리로 복사
COPY . .

# pip를 최신 버전으로 업그레이드하고, 의존성 패키지를 설치
RUN python -m pip install --upgrade pip
RUN pip install -r requirements.txt

# 애플리케이션 소스 코드가 있는 디렉터리로 이동
WORKDIR ./myapp

# 컨테이너 실행 시 Gunicorn을 사용하여 Flask 앱을 실행
# 0.0.0.0:8001 주소로 바인딩하여 외부 접속을 허용
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:8001"]

EXPOSE 8001
```

---

**requirements.txt 작성**

설치할 파이썬 패키지 목록이다.

```shell
assu@myserver01:~/work/ch11/ex01/github-action-practice$ vim requirements.txt
```

```text
flask==3.1.2
gunicorn==23.0.0
```

- flask: 웹 프레임워크
- gunicorn: 프로덕션 환경에서 사용할 WSGI HTTP 서버

---

**애플리케이션 코드(myapp/main.py) 작성**

Flask 라이브러리를 활용하여 간단한 웹 애플리케이션 코드를 작성한다.

```python
from flask import Flask

app = Flask(__name__)

# 루트 경로('/')로 접속 시 'hello world!'를 반환
@app.route('/')
def hello_world():
    return 'hello world!'

# 스크립트가 직접 실행될 경우 8001 포트에서 앱을 실행
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001)
```

---

### 3.2.2. GitHub Actions 워크플로 작성

이제 위에서 만든 애플리케이션을 테스트하는 워크플로 파일 *.github/workflows/flask-test.yml* 을 작성한다.

---

**작업 디렉터리 정리**

```shell
assu@myserver01:~/work/ch11/ex01/github-action-practice$ ls -al
total 28
drwxrwxr-x 5 assu assu 4096 Jan  3 08:12 .
drwxrwxr-x 3 assu assu 4096 Jan  3 08:04 ..
-rw-rw-r-- 1 assu assu  214 Jan  3 08:10 Dockerfile
drwxrwxr-x 8 assu assu 4096 Jan  3 08:04 .git
drwxrwxr-x 3 assu assu 4096 Jan  3 08:04 .github
drwxrwxr-x 2 assu assu 4096 Jan  3 08:14 myapp
-rw-rw-r-- 1 assu assu   30 Jan  3 08:11 requirements.txt

assu@myserver01:~/work/ch11/ex01/github-action-practice$ cd .github/
assu@myserver01:~/work/ch11/ex01/github-action-practice/.github$ ls
workflows

assu@myserver01:~/work/ch11/ex01/github-action-practice/.github$ cd workflows/
assu@myserver01:~/work/ch11/ex01/github-action-practice/.github/workflows$ ls
main.yml
```

---

**워크플로 작성**


```shell
assu@myserver01:~/work/ch11/ex01/github-action-practice/.github/workflows$ vim flask-test.yml
```

```yaml
# 워크플로 이름 정의
name: Docker Test

# main 브랜치에 push 이벤트가 발생할 때만 이 워크플로를 실행
on:
  push:
    branches:
      - main
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      # 1. GitHub 저장소의 코드를 러너 환경으로 체크아웃(내려받기)
      - name: Checkout code
        uses: actions/checkout@v3  # 깃허브 액션에서 제공하는 checkout 액션 의미

      # 2. 파이썬 3.13 환경을 설정
      - name: Setup Python
        uses: actions/setup-python@v3
        with:
          python-version: '3.13'
          
      # 3. Dockerfile을 기반으로 이미지를 빌드. 태그는 myflask-test로 지정    
      - name: build Flask Docker Image
        run: docker image build -t myflask-test .
        
      # 4. 빌드된 이미지로 컨테이너를 실행 (백그라운드 모드 -d, 포트 포워딩 -p)  
      - name: Run Flask Docker Container
        run: docker container run -d --name myflask-ac -p 8001:8001 myflask-test
        
      # 5. 컨테이너가 구동될 시간을 잠시 대기(sleep)한 후, curl 명령어로 응답을 테스트  
      - name: Test Flask App 
        run: |
          sleep 10
          curl http://127.0.0.1:8001

      # 6. 테스트가 끝나면 컨테이너를 정지하고 삭제하여 환경을 정리    
      - name: Stop and remove Docker Container 
        run: |
          docker container stop myflask-ac
          docker container rm myflask-ac
```

---

### 3.2.3. 코드 푸시 및 결과 확인

작성한 파일들을 Git에 추가하고 원격 저장소로 푸시한다.

먼저 업로드할 깃 브랜치와 리모트 정보를 확인한다.
```shell
assu@myserver01:~/work/ch11/ex01/github-action-practice$ git branch
* main
assu@myserver01:~/work/ch11/ex01/github-action-practice$ git remote
origin
```

```shell
# 파일을 스테이지 영역에 추가
assu@myserver01:~/work/ch11/ex01/github-action-practice$ git add .

assu@myserver01:~/work/ch11/ex01/github-action-practice$ git commit -m "flask docker test"
[main 6e44db2] flask docker test
 4 files changed, 55 insertions(+)
 create mode 100644 .github/workflows/flask-test.yml
 create mode 100644 Dockerfile
 create mode 100644 myapp/main.py
 create mode 100644 requirements.txt

assu@myserver01:~/work/ch11/ex01/github-action-practice$ git push
Username for 'https://github.com': <깃허브 ID>
Password for 'https://assu@github.com': <깃허브 토큰>
Enumerating objects: 12, done.
Counting objects: 100% (12/12), done.
Delta compression using up to 4 threads
Compressing objects: 100% (6/6), done.
Writing objects: 100% (9/9), 1.15 KiB | 1.15 MiB/s, done.
Total 9 (delta 0), reused 0 (delta 0), pack-reused 0
To https://github.com/assu/github-action-practice.git
   7ba9080..6e44db2  main -> main
```

푸시가 완료되면 깃허브 저장소의 **Actions** 탭에서 워크플로가 자동으로 실행되는 것을 볼 수 있다.

![깃허브 액션 결과 확인 1](/assets/img/dev/2025/1231/result1.png)
![깃허브 액션 결과 확인 2](/assets/img/dev/2025/1231/result2.png)

**build** 버튼을 눌러서 세부 작업 내역을 확인해 보면, 도커 이미지가 빌드되고 컨테이너가 실행된 후 curl 명령어를 통해 hello world! 응답을 정상적으로 수신했음을 
확인할 수 있다.

![깃허브 액션 결과 확인 3](/assets/img/dev/2025/1231/result3.png)

이로써 코드 변경 사항이 발생했을 때 자동으로 빌드하고 테스트하는 CI 파이프라인을 구축해보았다.

---

# 4. ArgoCD를 활용한 CD

[3. 깃허브(Github) 액션을 통한 소스코드 관리](#3-깃허브github-액션을-통한-소스코드-관리)에서 깃허브 액션을 통해 코드를 빌드하고 도커 컨테이너가 정상적으로 
실행되는지 테스트하는 **CI(지속적 통합)** 과정에 대해 알아보았다.  
하지만 테스트가 끝난 컨테이너를 실제 쿠버네티스 클러스터에 배포하고 관리하는 것은 또 다른 영역이다.

이를 해결하기 위해 **ArgoCD**를 사용한다.  
ArgoCD는 쿠버네티스를 위한 선언적 **GitOps** 도구로, Git 리포지토리에 정의된 형상(Manifest)을 쿠버네티스 클러스터의 상태와 자동으로 동기화(Sync)해주는 
역할을 한다.

---

## 4.1. ArgoCD 설치

ArgoCD는 쿠버네티스 애플리케이션 형태(CRD, Controller, Server 등)로 설치된다.  
가장 간편한 방법인 Helm을 사용하여 설치를 진행한다.

**헬름 리포지토리 추가 및 차트 다운로드**

```shell
# ArgoCD 헬름 리포지토리 추가
assu@myserver01:~$ helm repo add argo https://argoproj.github.io/argo-helm
"argo" has been added to your repositories

assu@myserver01:~$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "argo" chart repository
...Successfully got an update from the "ingress-nginx" chart repository
...Successfully got an update from the "metallb" chart repository
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈

# 설치 가능한 ArgoCD 차트 버전 확인
assu@myserver01:~$ helm search repo argo
NAME                      	CHART VERSION	APP VERSION  	DESCRIPTION
argo/argo                 	1.0.0        	v2.12.5      	A Helm chart for Argo Workflows
argo/argo-cd              	9.2.4        	v3.2.3       	A Helm chart for Argo CD, a declarative, GitOps...
argo/argo-ci              	1.0.0        	v1.0.0-alpha2	A Helm chart for Argo-CI
...
```

작업 디렉터리를 생성하고 차트를 다운로드하여 압축을 해제한다.

```shell
assu@myserver01:~/work$ ls
app  ch04  ch05  ch06  ch09  ch10  ch11

assu@myserver01:~/work$ cd app
assu@myserver01:~/work/app$ ls
helm  metallb  nginx-ingress-controller

assu@myserver01:~/work/app$ mkdir argocd
assu@myserver01:~/work/app$ cd argocd/
```

```shell
assu@myserver01:~/work/app/argocd$ helm pull argo/argo-cd
assu@myserver01:~/work/app/argocd$ ls
argo-cd-9.2.4.tgz

assu@myserver01:~/work/app/argocd$ tar xvfz argo-cd-9.2.4.tgz

assu@myserver01:~/work/app/argocd$ ls
argo-cd  argo-cd-9.2.4.tgz

assu@myserver01:~/work/app/argocd$ mv argo-cd argo-cd-9.2.4
assu@myserver01:~/work/app/argocd$ ls
argo-cd-9.2.4  argo-cd-9.2.4.tgz

assu@myserver01:~/work/app/argocd$ cd argo-cd-9.2.4/
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ ls
Chart.lock  charts  Chart.yaml  README.md  templates  values.yaml

# 사용자 설정을 위한 values.yaml 복사
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ cp values.yaml my-values.yaml

assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ ls
Chart.lock  charts  Chart.yaml  my-values.yaml  README.md  templates  values.yaml
```

---

**ArgoCD 설치 및 서비스 노출**

ArcoCD 전용 네임스페이스를 생성하고 설치를 진행한다.

```shell
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ kubectl create namespace myargocd
namespace/myargocd created

assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ kubectl get namespace
NAME               STATUS   AGE
calico-apiserver   Active   20d
calico-system      Active   20d
default            Active   20d
kube-node-lease    Active   20d
kube-public        Active   20d
kube-system        Active   20d
myargocd           Active   6s
mymetallb          Active   6d21h
mynginx            Active   7d1h
tigera-operator    Active   20d
```

```shell
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ helm install --namespace myargocd --generate-name argo/argo-cd -f my-values.yaml --debug --v=1

NOTES:
In order to access the server UI you have the following options:

1. kubectl port-forward service/argo-cd-1767430758-argocd-server -n myargocd 8080:443

    and then open the browser on http://localhost:8080 and accept the certificate

2. enable ingress in the values file `server.ingress.enabled` and either
      - Add the annotation for ssl passthrough: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-1-ssl-passthrough
      - Set the `configs.params."server.insecure"` in the values file and terminate SSL at your ingress: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-2-multiple-ingress-objects-and-hosts


After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:

kubectl -n myargocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

(You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli)
```

설치가 완료된 후 실행되고 있는 리소스들을 확인해본다.

```shell
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ kubectl get all --namespace myargocd
NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/argo-cd-1767430758-argocd-application-controller-0                1/1     Running   0          6m37s
pod/argo-cd-1767430758-argocd-applicationset-controller-5bd64bxlvwb   1/1     Running   0          6m37s
pod/argo-cd-1767430758-argocd-dex-server-6d7db8885d-gl8dh             1/1     Running   0          6m37s
pod/argo-cd-1767430758-argocd-notifications-controller-5fd5d7fskd42   1/1     Running   0          6m37s
pod/argo-cd-1767430758-argocd-redis-59f6cfd96f-jn95x                  1/1     Running   0          6m37s
pod/argo-cd-1767430758-argocd-repo-server-d69d5f468-kwrrd             1/1     Running   0          6m37s
pod/argo-cd-1767430758-argocd-server-6b75d9fdcd-tnfpl                 1/1     Running   0          6m37s


NAME                                                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/argo-cd-1767430758-argocd-applicationset-controller   ClusterIP   10.102.4.107     <none>        7000/TCP            6m37s
service/argo-cd-1767430758-argocd-dex-server                  ClusterIP   10.111.156.0     <none>        5556/TCP,5557/TCP   6m37s
service/argo-cd-1767430758-argocd-redis                       ClusterIP   10.106.109.139   <none>        6379/TCP            6m37s
service/argo-cd-1767430758-argocd-repo-server                 ClusterIP   10.104.152.234   <none>        8081/TCP            6m37s
service/argo-cd-1767430758-argocd-server                      ClusterIP   10.102.54.141    <none>        80/TCP,443/TCP      6m37s

NAME                                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/argo-cd-1767430758-argocd-applicationset-controller   1/1     1            1           6m37s
deployment.apps/argo-cd-1767430758-argocd-dex-server                  1/1     1            1           6m37s
deployment.apps/argo-cd-1767430758-argocd-notifications-controller    1/1     1            1           6m37s
deployment.apps/argo-cd-1767430758-argocd-redis                       1/1     1            1           6m37s
deployment.apps/argo-cd-1767430758-argocd-repo-server                 1/1     1            1           6m37s
deployment.apps/argo-cd-1767430758-argocd-server                      1/1     1            1           6m37s

NAME                                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/argo-cd-1767430758-argocd-applicationset-controller-5bd64bd8c8   1         1         1       6m37s
replicaset.apps/argo-cd-1767430758-argocd-dex-server-6d7db8885d                  1         1         1       6m37s
replicaset.apps/argo-cd-1767430758-argocd-notifications-controller-5fd5d7ffdf    1         1         1       6m37s
replicaset.apps/argo-cd-1767430758-argocd-redis-59f6cfd96f                       1         1         1       6m37s
replicaset.apps/argo-cd-1767430758-argocd-repo-server-d69d5f468                  1         1         1       6m37s
replicaset.apps/argo-cd-1767430758-argocd-server-6b75d9fdcd                      1         1         1       6m37s

NAME                                                                READY   AGE
statefulset.apps/argo-cd-1767430758-argocd-application-controller   1/1     6m37s
```

파드와 서비스를 확인해보면 *argocd-server* 서비스가 `ClusterIP` 타입으로 생성된 것을 볼 수 있다.  
외부 (웹 브라우저)에서 ArgoCD UI에 접속하기 위해 이를 `LoadBalancer` 타입으로 변경한다.

이 때 **MetalLB** 가 사용된다.  
일반적인 베어메탈(온프레미스) 환경이나 VM에서는 서비스 타입을 `LoadBalancer`로 변경해도 외부 IP(External-IP)가 할당되지 않고 `<pending>` 상태로 남는다.  
하지만 사전에 설치해 둔 **MetalLB**가 이 요청을 감지하고, 설정된 IP 풀에서 사용 가능한 IP(예: 10.0.2.21)를 할당해준다.  
즉, MetalLB 덕분에 로드밸런서 IP를 통해 ArgoCD에 접속할 수 있게 되는 것이다.

```shell
# 서비스 타입을 ClusterIP에서 LoadBalancer로 변경
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ kubectl patch svc argo-cd-1767430758-argocd-server -n myargocd -p \
> '{"spec": {"type": "LoadBalancer"}}'
service/argo-cd-1767430758-argocd-server patched

# 변경 결과 확인 (EXTERNAL-IP가 할당되었는지 확인)
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ kubectl get svc -n myargocd
NAME                                                  TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
argo-cd-1767430758-argocd-applicationset-controller   ClusterIP      10.102.4.107     <none>        7000/TCP                     23m
argo-cd-1767430758-argocd-dex-server                  ClusterIP      10.111.156.0     <none>        5556/TCP,5557/TCP            23m
argo-cd-1767430758-argocd-redis                       ClusterIP      10.106.109.139   <none>        6379/TCP                     23m
argo-cd-1767430758-argocd-repo-server                 ClusterIP      10.104.152.234   <none>        8081/TCP                     23m
argo-cd-1767430758-argocd-server                      LoadBalancer   10.102.54.141    10.0.2.21     80:32137/TCP,443:30346/TCP   23m
```

---

**ArgoCD 접속**

초기 관리자(admin) 비밀번호를 확인한다.  
출력된 결과를 이용하여 argocd에 접속할 예정이니 잘 메모해두어야 한다.

```shell
assu@myserver01:~/work/app/argocd/argo-cd-9.2.4$ kubectl -n myargocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
MLgJ3DVNB3JigJKc
```

VM 환경인 경우 호스트 OS에서 접속하기 위해 포트포워딩 설정이 필요하다.

![argocd 접속을 위한 포트포워딩](/assets/img/dev/2025/1231/port.png)

이제 웹 브라우저에서 127.0.0.1:2001 로 접속하여 로그인한다.  
처음에 신뢰할 수 없는 사이트라는 경고가 뜨는데 무시하고 접속한다.  
아이디는 admin이고 비밀번호는 위에서 확인한 비밀번호이다.

로그인이 성공하면 아래와 같은 argocd 첫 화면을 볼 수 있다.

![argoCD 접속 화면](/assets/img/dev/2025/1231/argocd.png)

---

## 4.2. ArgoCD를 활용한 깃허브 실습

이제 GitOps 방식을 통해 실제 애플리케이션을 배포해본다. 깃허브에 *argocd-practice* 리포지토리를 생성하고 매니페스트를 작성한다.

---

### 4.2.1. 배포용 매니페스트 작성 및 Push

작업 디렉터리를 정리한다.

```shell
assu@myserver01:~/work/ch11$ ls
ex01
assu@myserver01:~/work/ch11$ mkdir ex02
```

디플로이먼트(Nginx 파드 3개를 띄우는 설정)와 서비스에 대한 매니페스트 작성 후 Git에 push 한다.

```shell
assu@myserver01:~/work/ch11/ex02$ vim deployment.yml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-test01
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: web-deploy
  template:
    metadata:
      labels: 
        app.kubernetes.io/name: web-deploy
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          
```

```shell
assu@myserver01:~/work/ch11/ex02$ vim service.yml
```

```yaml
apiVersion: v1 
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app.kubernetes.io/name: web-deploy
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
```

```shell
assu@myserver01:~/work/ch11/ex02$ git init
Initialized empty Git repository in /home/assu/work/ch11/ex02/.git/
```

깃허브에 업로드하기 위해 리포지토리에 추가하고 업로드한다.

```shell
assu@myserver01:~/work/ch11/ex02$ git remote add origin https://github.com/assu10/argocd-practice.git

assu@myserver01:~/work/ch11/ex02$ git add .

assu@myserver01:~/work/ch11/ex02$ git commit -m "argocd-practice"
[main (root-commit) 42c6730] argocd-practice
 2 files changed, 29 insertions(+)
 create mode 100644 deployment.yml
 create mode 100644 service.yml
 
assu@myserver01:~/work/ch11/ex02$ git push -u origin main
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 4 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 564 bytes | 564.00 KiB/s, done.
Total 4 (delta 0), reused 0 (delta 0), pack-reused 0
To https://github.com/assu10/argocd-practice.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

깃허브 사이트에 들어가보면 해당 리포지토리에 해당 파일이 업로드된 것을 확인할 수 있다.

---

### 4.2.2. ArgoCD 애플리케이션 연동

**리포지토리 연결**

https://127.0.0.1:2001/ ArgoCD UI의 **Settings > Repositories** 에서 **CONNECT REPO** 버튼을 클릭한다.

![리포지토리 정보 입력](/assets/img/dev/2025/1231/repo.png)

---

**애플리케이션 생성**

**Applications > NEW APP** 를 클릭하여 아래 정보를 입력한다.

![애플리케이션 정보 입력 1](/assets/img/dev/2025/1231/application1.png)
![애플리케이션 정보 입력 2](/assets/img/dev/2025/1231/application2.png)
![애플리케이션 정보 입력 3](/assets/img/dev/2025/1231/application3.png)

- Application Name: nginx-test02
- Project: default
- Sync Policy: Manual(수동 동기화)
- Source: 연결할 리포지토리 URL, Path는 루트 경로인 `.`을 입력(원하는 디렉터리가 있으면 `/디렉터리 이름`)
- Destination: Cluster URL(https://kubernetes.default.svc), Namespace(nginx-argocd-test02)

---

**배포(Sync)**

생성된 애플리케이션에서 **SYNC** 버튼을 누르면 Git에 있는 매니페스트 내용을 바탕으로 쿠버네티스 리소스를 생성한다.

![싱크로나이즈 작업](/assets/img/dev/2025/1231/sync1.png)

![배포 확인](/assets/img/dev/2025/1231/result.png)

화면 좌측부터 보자.

첫 번째의 nginx-test02 는 argoCD 에서의 애플리케이션 이름이다.  
두 번째의 web-service는 Service 의 이름이고, deploy-test01은 디플로이먼트의 이름이다.  
세 번째 디플로이먼트와 연결된 deploy-test01-5b8c666f54 은 ReplicaSet이다.  
네 번째 ReplicaSet에 연결된 3개의 파드가 있다.

---

### 4.2.3. 배포 확인 및 상태 변경

터미널에서 실제로 리소스가 생성되었는지 확인한다.

```shell
assu@myserver01:~/work/ch11/ex02$ kubectl get namespace
NAME                  STATUS   AGE
...
nginx-argocd-test02   Active   6m13s
...
```

해당 애플리케이션 설치를 위한 네임스페이스가 추가된 것을 확인할 수 있다.

그리고 해당 애플리케이션이 설치된 네임스페이스의 리소스를 검색하면 앞서 Argocd 화면에서 본 것과 동일하게 원할히 실행 중인 것을 알 수 있다.
```shell
assu@myserver01:~/work/ch11/ex02$ kubectl get all -n nginx-argocd-test02
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-test01-5b8c666f54-4jhb9   1/1     Running   0          7m14s
pod/deploy-test01-5b8c666f54-d7w42   1/1     Running   0          7m14s
pod/deploy-test01-5b8c666f54-tbchm   1/1     Running   0          7m14s

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/web-service   ClusterIP   10.107.141.23   <none>        80/TCP    7m14s

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-test01   3/3     3            3           7m14s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-test01-5b8c666f54   3         3         3       7m14s
```

---

GitOps의 강력함을 변경 사항 관리에서 드러난다.  
ArgoCD UI 의 디플로이먼트인 deploy-test01을 클릭하면 LIVE MANIFEST 가 나오는데 여기서 EDIT 버튼을 클릭한다.

그리고 `spec.replicas`를 3에서 1로 수정하고 저장하면, 즉시 클러스터에 반영되어 파드 개수가 줄어드는 것을 시각적으로 확인할 수 있다.

수정 전
```yaml
spec:
  progressDeadlineSeconds: 600
  replicas: 3
```

수정 후
```yaml
spec:
  progressDeadlineSeconds: 600
  replicas: 1
```

그럼 아래와 같이 실행 중인 파드 개수가 한 개로 변한 것을 확인할 수 있다.

![파드 개수 변동 확인](/assets/img/dev/2025/1231/pod.png)

---

이제 애플리케이션을 삭제한다.  
ArgoCD는 기본적으로 Cascading Delete를 수행하므로, 생성되었던 파드와 서비스도 함께 정리된다.

![애플리케이션 삭제](/assets/img/dev/2025/1231/delete.png)

네임스페이스를 삭제하며 실습을 종료한다.

```shell
assu@myserver01:~/work/ch11/ex02$ kubectl get all -n nginx-argocd-test02
No resources found in nginx-argocd-test02 namespace.

assu@myserver01:~/work/ch11/ex02$ kubectl delete namespace nginx-argocd-test02
namespace "nginx-argocd-test02" deleted
```

---

# 정리하며..

- **GitHub Actions(CI)**
  - 코드가 리포지토리에 푸시될 때 자동으로 도커 이미지를 빌드하고 테스트 컨테이너를 실행하여 코드의 정합성을 검증했다.
- **MetalLB**
  - 베어메탈 환경에서 `LoadBalancer` 타입의 서비스를 사용할 수 있도록 IP를 할당해주어, ArgoCD 서버에 외부 접속을 가능하게 했다.
- **ArgoCD(CD)**
  - Git 리포지토리의 매니페스트를 쿠버네티스 클러스터와 동기화하여, 복잡한 배포 과정을 자동화하고 시각화했다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Doc:: ArgoCD](https://argo-cd.readthedocs.io/en/stable/)
* [Doc:: GitHub Actions](https://docs.github.com/ko/actions)