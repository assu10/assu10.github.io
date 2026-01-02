---
layout: post
title:  "Kubernetes - 쿠버네티스로 웹 서비스 배포(1): 인그레스를 활용한 Django & Nginx 배포"
date: 2025-12-28 10:00:00
categories: dev
tags: devops kubernetes k8s docker django nginx ingress sidecar-pattern deployment service docker-hub container-orchestration python web-server
---

여러 도메인을 라우팅해야 하거나, SSL/TLS 인증서를 통합 관리하고, 로드 밸런싱을 더 효율적으로 처리해야 할 때 **인그레스(Ingress)**를 사용한다.

이번 포스트에서는 **Django(웹 프레임워크)**와 **Nginx(웹 서버)**를 쿠버네티스 환경에 배포해보며, 인그레스를 활용하여 외부 트래픽을 안정적으로 처리하는 
전체 과정을 실습해본다.

도커 이미지를 빌드하는 것부터 디플로이먼트, 서비스, 그리고 최종적으로 인그레스를 설정하는 단계까지 포함한다.

---

**목차**

<!-- TOC -->
* [1. 사전 준비 사항](#1-사전-준비-사항)
* [2. 인그레스(Ingress)를 활용한 django 실행](#2-인그레스ingress를-활용한-django-실행)
  * [2.1. 디렉터리 정리](#21-디렉터리-정리)
  * [2.2. Django 이미지 빌드](#22-django-이미지-빌드)
  * [2.3. Nginx 이미지 빌드](#23-nginx-이미지-빌드)
  * [2.4. 디플로이먼트(Deployment) 실행](#24-디플로이먼트deployment-실행)
  * [2.5. 서비스(Service) 실행](#25-서비스service-실행)
  * [2.6. 인그레스(Ingress) 실행](#26-인그레스ingress-실행)
    * [2.6.1. 파드 내부 접속 및 상태 확인](#261-파드-내부-접속-및-상태-확인)
    * [2.6.2. 전체 아키텍처 및 리소스 정리](#262-전체-아키텍처-및-리소스-정리)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Guest OS: Ubuntu 24.04.2 LTS
- Host OS: Mac Apple M3 Max
- Memory: 48 GB

---

# 1. 사전 준비 사항

본격적인 실습에 앞서 몇 가지 준비가 필요하다.  
이번 포스트에서는 우리가 만든 컨테이너 이미지를 **Docker Hub**에 직접 업로드하고, 쿠버네티스 클러스터가 이를 내려받아 실행하는 구조를 가진다.

따라서 [Docker Hub](https://hub.docker.com) 계정이 없다면 먼저 가입을 진행해야 한다.

또한, Django 애플리케이션이 데이터를 저장할 데이터베이스인 PostgreSQL이 로컬 서버(Host)에서 정상적으로 실행 중인지 확인한다.

```shell
assu@myserver01:~/work/ch09/ex15$ sudo systemctl status postgresql.service
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; preset: enabled)
     Active: active (exited) since Mon 2025-12-15 06:27:35 UTC; 2 weeks 3 days ago
   Main PID: 1459 (code=exited, status=0/SUCCESS)
        CPU: 1ms
```

이와 같이 상태가 `active`인 것을 확인했다면 준비가 완료된 것이다.

> PostgreSQL이 설치되어 있지 않다면, [2.2. 도커 스토리지의 필요성](https://assu10.github.io/dev/2025/11/16/docker-basics-and-commands-guide-2/#22-%EB%8F%84%EC%BB%A4-%EC%8A%A4%ED%86%A0%EB%A6%AC%EC%A7%80%EC%9D%98-%ED%95%84%EC%9A%94%EC%84%B1)을 참고하세요.

---

# 2. 인그레스(Ingress)를 활용한 django 실행

이제 인그레스를 활용하여 Django 애플리케이션을 외부로 서비스해본다.  전체적인 흐름은 다음과 같다.

- **Django & Nginx 이미지 빌드**(Docker Hub에 업로드)
- **디플로이먼트(Deployment) 생성**(Pod 실행)
- **서비스(Service) 생성**(내부 네트워크 구성)
- **인그레스(Ingress) 생성**(외부 트래픽 라우팅)

---

## 2.1. 디렉터리 정리

먼저 디렉터리를 생성하고 정리한다.  
기존에 사용했던 Django 관련 파일을 재사용할 것이므로, [2.2. Django 이미지 빌드(Host IP 연결)](https://assu10.github.io/dev/2025/11/28/docker-compose-nginx-django-postgresql-integration/#22-django-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EB%B9%8C%EB%93%9Chost-ip-%EC%97%B0%EA%B2%B0) 
에서 사용했던 ch05/ex08 디렉터리를 복사하여 가져온다.

```shell
assu@myserver01:~/work$ ls
app  ch04  ch05  ch06  ch09

# 이번 실습을 위한 디렉터리 생성
assu@myserver01:~/work$ mkdir ch10
assu@myserver01:~/work$ cd ch10
assu@myserver01:~/work/ch10$ mkdir ex01
assu@myserver01:~/work/ch10$ cd ex01
assu@myserver01:~/work/ch10/ex01$ pwd
/home/assu/work/ch10/ex01
```

```shell
assu@myserver01:~/work/ch05/ex08$ pwd
/home/assu/work/ch05/ex08
assu@myserver01:~/work/ch05/ex08$ ls
myDajngo04  myNginx04

# 기존 소스 복사
assu@myserver01:~/work/ch05/ex08$ cp -r ./ /home/assu/work/ch10/ex01

assu@myserver01:~/work/ch05/ex08$ cd /home/assu/work/ch10/ex01
assu@myserver01:~/work/ch10/ex01$ ls
myDajngo04  myNginx04
```

---

## 2.2. Django 이미지 빌드

Django 컨테이너가 로컬 호스트(Node)에 설치된 PostgreSQL 데이터베이스를 바라볼 수 있도록 설정을 변경하고, 새로운 이미지를 빌드한다.

먼저 `settings.py` 파일이 있는 위치로 이동한다.

```shell
assu@myserver01:~/work/ch10/ex01$ cd myDajngo04/myapp/myapp
assu@myserver01:~/work/ch10/ex01/myDajngo04/myapp/myapp$ ls
asgi.py  __init__.py  __pycache__  settings.py  urls.py  wsgi.py
```

```shell
assu@myserver01:~/work/ch10/ex01/myDajngo04/myapp/myapp$ vim settings.py
```

`DATABASES` 항목의 `HOST` 정보를 수정한다.

**수정 전(Docker 환경)**
```python
...
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'postgres',
        'USER': 'postgres',
        'PASSWORD': 'mysecretpassword',
        'HOST': '172.17.0.1', # Docker Bridge Gateway IP
        'PORT': 5432,
    }
}
...
```

**수정 후(Kubernetes 환경)**
```python
...
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'postgres',
        'USER': 'postgres',
        'PASSWORD': 'mysecretpassword',
        'HOST': '10.0.2.4', # PostgreSQL이 설치된 Node의 실제 IP
        'PORT': 5432,
    }
}
...
```

기존 Docker 환경에서는 172.17.0.1을 사용했지만, 쿠버네티스 환경(특히 Minikube나 VM 환경)에서는 노드의 실제 IP를 명시해주어야 파드에서 호스트의 DB로 
접근이 원활하다. 여기서는 myserver01의 IP인 10.0.2.4를 입력했다.

> Docker 환경과 k8s 환경에서의 네트워크 차이에 대한 내용은 [Docker vs k8s 네트워크 차이: Django에서 로컬 DB 연결 시 Host IP의 차이](https://assu10.github.io/dev/2025/12/28/kubernetes-docker-k8s-network-difference-host-db-access/)를 참고하세요.


이제 설정 변경을 완료했으므로 Docker 이미지를 빌드한다.

```shell
assu@myserver01:~/work/ch10/ex01/myDajngo04/myapp/myapp$ cd ../..
assu@myserver01:~/work/ch10/ex01/myDajngo04$ ls
Dockerfile  myapp  requirements.txt

# 이미지 빌드(Tag: 0.2)
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker image build . -t mydjango_ch10:0.2
[+] Building 9.7s (11/11) FINISHED                                                                                                           docker:default
...
 1 warning found (use docker --debug to expand):
 - JSONArgsRecommended: JSON arguments recommended for CMD to prevent unintended behavior related to OS signals (line 11)

assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker image ls
REPOSITORY       TAG       IMAGE ID       CREATED         SIZE
mydjango_ch10    0.2       a5b8ae94299f   8 seconds ago   1.19GB
```

이미지가 정상적으로 생성되었다. 이제 이 이미지를 쿠버네티스 클러스터가 가져갈 수 있도록 **Docker Hub**에 업로드한다.

먼저 웹 브라우저로 Docker Hub에 접속하여 *mydjango_ch10* 이라는 이름의 리포지토리를 생성한다.

![django 리포지토리 생성](/assets/img/dev/2025/1228/docker_hub.png)

리포지토리 생성이 완료되었다면, 터미널에서 로그인을 진행한다.

```shell
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker login
USING WEB-BASED LOGIN
...
WARNING! Your credentials are stored unencrypted in '/home/assu/.docker/config.json'.
Configure a credential helper to remove this warning. See
https://docs.docker.com/go/credential-store/

Login Succeeded
```

로그인 성공 후, 생성한 이미지를 Docker Hub 계정 경로에 맞게 태그를 변경하고 Push 한다.  
(assu 부분은 본인의 Docker Hub ID로 변경해야 합니다.)

```shell
# 도커 이미지 태그 생성(형식: <DockerHub_ID>/<Repo_Name>:<Tag>)
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker tag mydjango_ch10:0.2 assu/mydjango_ch10:0.2

# 도커 허브에 업로드
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker push assu/mydjango_ch10:0.2
The push refers to repository [docker.io/assu/mydjango_ch10]
5f70bf18a086: Pushed
...
0.2: digest: sha256:c6f8562dc49e19e246e40bb0f57d31b40dce153a8fccc035bffa2675ffc99e76 size: 2840
```

`docker tag` 명령은 기존 로컬 이미지를 가리키는 새로운 Alias를 만드는 과정이며, `docker push`를 통해 원격 저장소로 업로드된다.

![도커 허브 업로드 확인](/assets/img/dev/2025/1228/tag2.png)

> 만일 `docker push` 시 `denied: requested access to the resource is denied` 오류가 발생한다면, 로그인이 제대로 되지 않았거나 
> 리포지토리 권한 문제일 수 있습니다. 리포지토리 권한 문제일 경우 
> [TroubleShooting - `docker push` 시 `denied: requested access to the resource is denied`](https://assu10.github.io/dev/2025/12/28/trouble-shooting/) 을 참고하세요.

---

## 2.3. Nginx 이미지 빌드

Django 애플리케이션 앞단에서 리버스 프록시(Reverse Proxy) 역할을 수행할 Nginx 이미지를 빌드한다.

먼저 Nginx 관련 파일이 있는 디렉터리로 이동한다.

```shell
assu@myserver01:~/work/ch10/ex01/myNginx04$ pwd
/home/assu/work/ch10/ex01/myNginx04

assu@myserver01:~/work/ch10/ex01/myNginx04$ ls
default.conf  Dockerfile
```

쿠버네티스 파드 환경에 맞게 `default.conf` 설정 파일을 수정한다.

```shell
assu@myserver01:~/work/ch10/ex01/myNginx04$ vim default.conf
```

**수정 전(Docker Compose 환경)**
```text
upstream myweb{
        server djangotest:8000;
}

server{
        listen 80;
        server_name localhost;
        location /{
                proxy_pass http://myweb;
        }
}
```

**수정 후(Kubernetes [Sidecar 패턴](https://assu10.github.io/dev/2025/12/20/sidecar-pattern/) 환경)**
```text
server{
        listen 80;
        server_name localhost;
        location /{
                proxy_pass http://127.0.0.1:8000;
        }
}
```

**중요 변경 사항**  
기존의 Docker Compose 환경에서는 컨테이너 간 통신 시 서비스 이름(예: *djangotest*)을 호스트명으로 사용했었다.  
하지만 이번 쿠버네티스 환경에서는 **하나의 파드 안에 Nginx 컨테이너와 Django 컨테이너를 함께 배치**할 예정이다.

동일한 파드 내의 컨테이너들은 네트워크 네임스페이스를 공유하므로 **localhost**를 통해 서로 통신할 수 있다.  
따라서 `upstream` 설정 없이 바로 *http://127.0.0.1:8000* 으로 패킷을 전달하도록 수정한다.

이제 수정된 설정을 바탕으로 Nginx 도커 이미지를 빌드한다.

```shell
assu@myserver01:~/work/ch10/ex01/myNginx04$ docker image build . -t mynginxd_ch10:0.3
[+] Building 2.1s (9/9) FINISHED                                                     docker:default
 => [internal] load build definition from Dockerfile                                           0.0s
...
```

이미지가 정상적으로 생성되었는지 확인한다.

```shell
assu@myserver01:~/work/ch10/ex01/myNginx04$ docker image ls
REPOSITORY               TAG       IMAGE ID       CREATED         SIZE
mynginxd_ch10            0.3       abb07383ce25   3 minutes ago   192MB
```

생성된 이미지를 Docker Hub에 올리기 위해 웹 브라우저에서 *mynginxd_ch10* 리포지토리를 생성한다.

![nginx 리포지토리 생성](/assets/img/dev/2025/1228/dockerhub2.png)

Django 이미지와 동일한 방식으로 태그를 생성하고 Push를 진행한다.

```shell
# 태그 생성
assu@myserver01:~/work/ch10/ex01/myNginx04$ docker tag mynginxd_ch10:0.3 assu/mynginxd_ch10:0.3

# 도커 허브 업로드
assu@myserver01:~/work/ch10/ex01/myNginx04$ docker push assu/mynginxd_ch10:0.3
The push refers to repository [docker.io/assu/mynginxd_ch10]
98888136d0ec: Pushed
...
0.3: digest: sha256:de72045142edf66d03dcf150732ad9acad026fb278371e20d0a3923d2dfe4e4a size: 2192
```

![도커 허브 업로드 확인](/assets/img/dev/2025/1228/tag1.png)

---

## 2.4. 디플로이먼트(Deployment) 실행

이제 앞서 만든 두 개의 이미지(Django, Nginx)를 사용하여 실제 애플리케이션을 구동할 디플로이먼트를 정의한다.

```shell
assu@myserver01:~/work/ch10/ex01$ ls
myDajngo04  myNginx04
```

```shell
assu@myserver01:~/work/ch10/ex01$ vim django-deploy.yml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-django
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
        # Nginx 컨테이너 (Reverse Proxy)
        - name: nginx-d
          image: assu/mynginxd_ch10:0.3  # Docker Hub에 업로드한 이미지
          ports:
            - containerPort: 80
        # Django 컨테이너 (App)
        - name: django-web
          image: assu/mydjango_ch10:0.2
          ports:
            - containerPort: 8000
```

위 YAML 파일의 핵심은 `spec.containers` 항목에 두 개의 컨테이너가 정의되어 있다는 점이다.  
이를 통해 **멀티 컨테이너 파드**가 생성되며, 두 컨테이너는 항상 함께 스케줄링되고 동일한 IP와 포트 공간을 공유한다.

이제 디플로이먼트를 실행한다.

```shell
assu@myserver01:~/work/ch10/ex01$ kubectl apply -f django-deploy.yml
deployment.apps/deploy-django created

assu@myserver01:~/work/ch10/ex01$ kubectl get pods
NAME                             READY   STATUS    RESTARTS   AGE
deploy-django-77675fcbcf-4rbhn   2/2     Running   0          72s
deploy-django-77675fcbcf-6f5gf   2/2     Running   0          72s
deploy-django-77675fcbcf-p5ptn   2/2     Running   0          72s
```

`READY` 열이 *2/2*로 표시되는 것은 파드 내의 두 컨테이너(Django, Nginx)가 모두 정상적으로 실행 중임을 의미한다.  
도커 허브에서 이미지를 다운로드해야 하기 때문에 파드가 실행되기까지 다소 시간이 소요된다.

---

## 2.5. 서비스(Service) 실행

파드들이 정상적으로 실행되었으므로, 이들에 접근할 수 있는 단일 진입점인 서비스(Service)를 생성한다.  
외부 노출을 인그레스가 담당할 예정이므로, 서비스 타입은 내부 통신용인 [`ClusterIP`](https://assu10.github.io/dev/2025/12/08/kubernetes-service-concept-and-types/#2-clusterip)을 사용한다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: django-service
spec:
  selector:
    app.kubernetes.io/name: web-deploy  # 서비스와 연결한 파드 설정, 디플로이먼트의 라벨과 일치해야 함
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80        # [서비스용] 클러스터 내부 다른 리소스(Ingress 등)가 접근할 포트
      targetPort: 80  # [파드용] 파드 내 Nginx 컨테이너의 포트
```

서비스를 생성하고 상태를 확인한다.

```shell
assu@myserver01:~/work/ch10/ex01$ kubectl apply -f django-service.yml
service/django-service created

assu@myserver01:~/work/ch10/ex01$ kubectl get pod,svc
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-django-77675fcbcf-4rbhn   2/2     Running   0          2m40s
pod/deploy-django-77675fcbcf-6f5gf   2/2     Running   0          2m40s
pod/deploy-django-77675fcbcf-p5ptn   2/2     Running   0          2m40s

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/django-service   ClusterIP   10.98.94.163   <none>        80/TCP    5s
service/kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP   7d1h
```

*service/django-service* 서비스가 `ClusterIP` 타입으로 생성되었으며, 클러스터 IP *10.98.94.163* 을 할당받은 것을 확인할 수 있다.  
이제 클러스터 내부에서는 이 IP를 통해 Django 앱(정확히는 Nginx)에 접근할 수 있게 되었다.

---

## 2.6. 인그레스(Ingress) 실행

이제 클러스터 외부에서 내부의 서비스로 접근할 수 있도록 **인그레스**를 설정한다.  
인그레스는 외부 요청(HTTP/HTTPS)을 클러스터 내부의 서비스(Service)로 라우팅해주는 규칙의 모음이다.

```shell
assu@myserver01:~/work/ch10/ex01$ vim django-ingress.yml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: django-ingress
  annotations:
    # Nginx Ingress Controller가 /test01 경로를 제거하고 백엔드로 전달하도록 설정 (Rewrite)
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http: 
        paths:
          # 정규표현식을 사용하여 /test01 뒤에 오는 모든 경로를 포착
          - path: /test01(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: django-service  # 인그레스와 연동할 서비스 이름, 앞서 생성한 서비스 이름
                port:
                  number: 80
```

> 인그레스 설정값에 대한 좀 더 상세한 설명은 [6. 인그레스로 하나의 서비스 배포](https://assu10.github.io/dev/2025/12/22/kubernetes-ingress-helm-metallb-baremetal-loadbalancer/#6-%EC%9D%B8%EA%B7%B8%EB%A0%88%EC%8A%A4%EB%A1%9C-%ED%95%98%EB%82%98%EC%9D%98-%EC%84%9C%EB%B9%84%EC%8A%A4-%EB%B0%B0%ED%8F%AC)
> 를 참고하세요.

이제 인그레스 리소스를 생성하고 상태를 확인한다.

```shell
assu@myserver01:~/work/ch10/ex01$ kubectl apply -f django-ingress.yml
ingress.networking.k8s.io/django-ingress created

assu@myserver01:~/work/ch10/ex01$ kubectl get pod,svc,ingress
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-django-77675fcbcf-4rbhn   2/2     Running   0          8m49s
pod/deploy-django-77675fcbcf-6f5gf   2/2     Running   0          8m49s
pod/deploy-django-77675fcbcf-p5ptn   2/2     Running   0          8m49s

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/django-service   ClusterIP   10.98.94.163   <none>        80/TCP    6m14s
service/kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP   7d1h

NAME                                       CLASS   HOSTS   ADDRESS   PORTS   AGE
ingress.networking.k8s.io/django-ingress   nginx   *                 80      28s
```

*django-ingress*가 정상적으로 생성된 것을 확인할 수 있다.

이제 웹 브라우저를 통해 접속 테스트를 진행한다.

- 접속 URL: [http://127.0.0.1:2000/test01](http://127.0.0.1:2000/test01)

브라우저에서 Django 환영 페이지가 보인다면 외부 요청이 `Ingress → Service → Pod(Nginx → Django)` 순서로 정상적으로 도달한 것이다.

---

### 2.6.1. 파드 내부 접속 및 상태 확인

정말 설정한 대로 파일들이 배치되어 있고, DB 연결이 잘 되는지 확인하기 위해 **실행 중인 파드 내부**로 직접 들어가본다.

---

**1) Nginx 컨테이너 접속**

```shell
assu@myserver01:~/work/ch10/ex01$ kubectl exec -it pod/deploy-django-77675fcbcf-p5ptn -- /bin/bash
Defaulted container "nginx-d" out of: nginx-d, django-web

root@deploy-django-77675fcbcf-p5ptn:/etc/nginx/conf.d# cat default.conf
server{
	listen 80;
	server_name localhost;
	location /{
		proxy_pass http://127.0.0.1:8000;
	}
}
root@deploy-django-77675fcbcf-p5ptn:/etc/nginx/conf.d# exit
exit
```

`kubectl exec` 명령어 실행 시 별도의 컨테이너 옵션을 주지 않으면, 쿠버네티스는 **첫 번째 컨테이너(nginx-d)**로 접속시킨다.  
`default.conf` 파일을 확인해보니 우리가 빌드한 대로 `proxy_pass` 설정이 잘 들어가있다.

---

**2) Django 컨테이너 접속(`-c` 옵션 사용)**

이번에는 같은 파드 내에 있는 **Django 컨테이너**로 접속해본다.  
멀티 컨테이너 파드에서는 `-c`(container) 옵션을 사용하여 접속할 대상을 명시해야 한다.

```shell
assu@myserver01:~/work/ch10/ex01$ kubectl exec -it pod/deploy-django-77675fcbcf-4rbhn -c django-web -- /bin/bash
root@deploy-django-77675fcbcf-4rbhn:/usr/src/app/myapp# ls
db.sqlite3  manage.py  myapp

# 데이터베이스 연결 확인
root@deploy-django-77675fcbcf-4rbhn:/usr/src/app/myapp# python manage.py inspectdb
...
from django.db import models
root@deploy-django-77675fcbcf-4rbhn:/usr/src/app/myapp# exit
exit
```

`inspect` 명령어가 에러 없이 실행되었다면, Django 컨테이너가 **호스트(Node)에 설치된 PostgreSQL** 데이터베이스와 정상적으로 통신하고 있음을 의미한다.

---

### 2.6.2. 전체 아키텍처 및 리소스 정리

지금까지 진행한 내용의 전체 네트워크 흐름은 아래 그림과 같다.

![네트워크 흐름](/assets/img/dev/2025/1228/flow.png)

- **User**: /test01 경로로 요청
- **Ingress**: 요청을 받아 *django-service*로 라우팅(경로는 `/`로 Rewrite)
- **Service**: 적절한 파드를 찾아 트래픽 분산
- **Pod(Nginx)**: 80 포트로 요청을 받아 로컬호스트의 8000 포트로 전달
- **Pod(Django)**: 요청을 처리하고 필요한 경우 노드(Host)의 DB에서 데이터를 조회


이제 생성한 리소스를 정리한다.

```shell
assu@myserver01:~/work/ch10/ex01$ kubectl delete -f django-ingress.yml
ingress.networking.k8s.io "django-ingress" deleted
assu@myserver01:~/work/ch10/ex01$ kubectl delete -f django-service.yml
service "django-service" deleted
assu@myserver01:~/work/ch10/ex01$ kubectl delete -f django-deploy.yml
deployment.apps "deploy-django" deleted

assu@myserver01:~/work/ch10/ex01$ kubectl get pod,svc,ingress
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d2h
```

---

# 정리하며..

이번 포스트의 핵심 내용은 아래와 같다.

- **Docker Hub 활용**
  - 로컬 이미지가 아닌 Docker Hub에 업로드된 이미지를 사용하여 클러스터가 이미지를 받아오도록 구성하였다.
- **Sidecar 패턴**
  - 하나의 파드 안에 Django와 Nginx 컨테이너를 함께 배치하여 localhost 통신이 가능하도록 설계하였다.
- **Ingress 활용**
  - 복잡한 외부 접속 설정을 Ingress 리소스 하나로 통합 관리하여 유연한 라우팅을 구현하였다.

이러한 구조는 실제 환경에서도 매우 자주 사용되는 패턴이므로, 각 구성 요소(Pod, Service, Ingress)의 역할과 연결 고리를 확실히 이해해두는 것이 중요하다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)