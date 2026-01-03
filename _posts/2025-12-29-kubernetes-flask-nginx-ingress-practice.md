---
layout: post
title:  "Kubernetes - 쿠버네티스로 웹 서비스 배포(2): 인그레스를 활용한 Flask & Nginx 배포"
date: 2025-12-29 10:00:00
categories: dev
tags: devops kubernetes k8s deployment service ingress sidecar-pattern clusterip port-forwarding nginx-ingress-controller path-rewrite
---

이번 포스트에서는 **Flask**와 **Nginx(웹 서버)**를 쿠버네티스 환경에 배포해보며, 인그레스를 활용하여 외부 트래픽을 안정적으로 처리하는
전체 과정을 실습해본다.

도커 이미지를 빌드하는 것부터 디플로이먼트, 서비스, 그리고 최종적으로 인그레스를 설정하는 단계까지 포함한다.

---

**목차**

<!-- TOC -->
* [1. 디렉터리 정리](#1-디렉터리-정리)
* [2. Flask 이미지 빌드](#2-flask-이미지-빌드)
  * [2.1. 소스 코드 및 설정 확인](#21-소스-코드-및-설정-확인)
  * [2.2. 이미지 빌드 및 Docker Hub Push](#22-이미지-빌드-및-docker-hub-push)
* [3. Nginx 이미지 빌드](#3-nginx-이미지-빌드)
  * [3.1. Nginx 설정 파일 변경](#31-nginx-설정-파일-변경)
  * [3.2. 이미지 빌드 및 Docker Hub Push](#32-이미지-빌드-및-docker-hub-push)
* [4. 디플로이먼트(Deployment) 실행](#4-디플로이먼트deployment-실행)
  * [4.1. 매니페스트 작성(Sidecar 패턴 적용)](#41-매니페스트-작성sidecar-패턴-적용)
  * [4.2. 배포 및 확인](#42-배포-및-확인)
* [5. 서비스(Service) 실행](#5-서비스service-실행)
  * [5.1. 매니페스트 작성 및 포트 개념 정리](#51-매니페스트-작성-및-포트-개념-정리)
  * [5.2. Service 생성 및 확인](#52-service-생성-및-확인)
* [6. 인그레스(Ingress) 실행](#6-인그레스ingress-실행)
  * [6.1. 매니페스트 작성(URL Rewriting)](#61-매니페스트-작성url-rewriting)
  * [6.2. 인그레스 적용 및 접속 테스트](#62-인그레스-적용-및-접속-테스트)
  * [6.3. 전체 아키텍처 및 리소스 정리](#63-전체-아키텍처-및-리소스-정리)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Guest OS: Ubuntu 24.04.2 LTS
- Host OS: Mac Apple M3 Max
- Memory: 48 GB

---

# 1. 디렉터리 정리

먼저 실습을 위한 작업 디렉터리를 구성한다. 기존에 작성했던 [2.2. Flask 이미지 빌드](https://assu10.github.io/dev/2025/11/29/docker-compose-flask-nginx-integration/#22-flask-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EB%B9%8C%EB%93%9C) 
를 재사용한다.

기존 ch06/ex02 에 있던 Flask와 Nginx 관련 파일들을 이번 작업 디렉터리 경로인 ch10/ex02 로 복사한다.

```shell
# 작업 디렉터리 생성
assu@myserver01:~/work/ch10$ ls
ex01
assu@myserver01:~/work/ch10$ mkdir ex02
assu@myserver01:~/work/ch10$ ls
ex01  ex02
assu@myserver01:~/work/ch10$ cd ex02
assu@myserver01:~/work/ch10/ex02$ pwd
/home/assu/work/ch10/ex02

assu@myserver01:~/work/ch10/ex02$ cd
assu@myserver01:~$ cd work/ch06/ex02
assu@myserver01:~/work/ch06/ex02$ ls
Flask02  myNginx02f

# 기존 소스 복사
assu@myserver01:~/work/ch06/ex02$ cp -r ~/work/ch06/ex02/* ~/work/ch10/ex02/

assu@myserver01:~/work/ch06/ex02$ cd
assu@myserver01:~$ cd work/ch10/ex02
assu@myserver01:~/work/ch10/ex02$ ls
Flask02  myNginx02f

# 디렉터리명 변경 (Flask02 -> myFlask02)
assu@myserver01:~/work/ch10/ex02$ mv Flask02 myFlask02
assu@myserver01:~/work/ch10/ex02$ ls
myFlask02  myNginx02f
```

---

# 2. Flask 이미지 빌드

애플리케이션 계층을 담당할 Flask 이미지를 빌드한다.

---

## 2.1. 소스 코드 및 설정 확인

myFlask02 디렉터리는 아래와 같은 구조를 가지고 있다.
- **main.py**: Flask 애플리케이션 소스 코드
- **Dockerfile**: 컨테이너 빌드 명세
- **requirements.txt**: 의존성 패키지 목록

```shell
assu@myserver01:~/work/ch10/ex02$ cd myFlask02/
assu@myserver01:~/work/ch10/ex02/myFlask02$ ls
Dockerfile  myapp  requirements.txt

assu@myserver01:~/work/ch10/ex02/myFlask02$ cd myapp
assu@myserver01:~/work/ch10/ex02/myFlask02/myapp$ ls
main.py
```

**main.py**
```python
from flask import Flask

# flask 웹 애플리케이션 객체를 app이라고 지정
app = Flask(__name__)

# 루트 경로에 접근
@app.route('/')
def hello_world():
    return 'hello world!'

# 파이썬 스크립트가 실행되면 app.run을 통해 웹 애플리케이션 실행
# host=0.0.0.0은 모든 IP주소로부터 요청을 수락한다는 의미이고, port=8001은 8001번 포트를 사용한다는 의미
if __name__ == '__main__':
    app.run(host='0.0.0.0', port='8001')
```

main.py 파일은 수정할 필요없이 그대로 사용한다.

이번엔 도커 파일을 확인한다.

```shell
assu@myserver01:~/work/ch10/ex02/myFlask02/myapp$ cd ..
assu@myserver01:~/work/ch10/ex02/myFlask02$ ls
Dockerfile  myapp  requirements.txt
```

**Dockerfile**
```dockerfile
FROM python:3.13.9

WORKDIR /usr/src/app

COPY . .

RUN python -m pip install --upgrade pip
RUN pip install -r requirements.txt

WORKDIR ./myapp

# Gunicorn을 사용하여 프로덕션 레벨의 WSGI 서버 실행
CMD gunicorn --bind 0.0.0.0:8001 main:app

EXPOSE 8001
```

도커 파일도 수정하지 않고 그대로 사용한다.

마지막으로 requirements.txt 파일을 확인한다.

**requirements.txt**
```text
flask==3.1.2
gunicorn==23.0.0
```

해당 파일 역시 수정할 부분은 따로 없다.

---

## 2.2. 이미지 빌드 및 Docker Hub Push

이제 도커 이미지를 빌드한다. 태그는 0.2로 지정한다.

```shell
assu@myserver01:~/work/ch10/ex02/myFlask02$ docker image build . -t myflask_ch10:0.2
[+] Building 2.4s (12/12) FINISHED                                                                                                           docker:default
...
 1 warning found (use docker --debug to expand):
 - JSONArgsRecommended: JSON arguments recommended for CMD to prevent unintended behavior related to OS signals (line 12)
 
assu@myserver01:~/work/ch10/ex02/myFlask02$ docker image ls
REPOSITORY               TAG       IMAGE ID       CREATED       SIZE
myflask_ch10             0.2       2e8232aedc7f   3 weeks ago   1.15GB
```

이미지 빌드가 완료되었다면, Kubernetes 클러스터가 이미지를 가져갈 수 있도록 원격 저장소인 Docker Hub에 업로드해야 한다.  
이를 위해 리포지토리를 생성한다.

![도커 허브 리포지토리 생성](/assets/img/dev/2025/1229/repo.png)


**로그인 및 푸시**
```shell
# Docker Hub 로그인
assu@myserver01:~/work/ch10/ex02/myFlask02$ docker login
...
Login Succeeded
```

도커 이미지 업로드를 위해 tag 명령어를 활용하여 업로드용 이미지를 생성하고 해당 이미지를 도커 허브에 업로드한다.

```shell
# 원격 저장소용 태그 생성 (사용자 ID/이미지명:태그)
assu@myserver01:~/work/ch10/ex02/myFlask02$ docker tag myflask_ch10:0.2 assu/myflask_ch10:0.2

# 이미지 푸시
assu@myserver01:~/work/ch10/ex02/myFlask02$ docker push assu/myflask_ch10:0.2
5f70bf18a086: Pushed
...
0.2: digest: sha256:94e9bba2a7b9358bf7f4bf00c8b864aabe050ebeac680b4c587cd6ff4b890194 size: 2838
```

도커 허브에 접속한 후 해당 리포지토리를 확인하면 이미지가 업로드된 것을 확인할 수 있다.

![업로드 확인](/assets/img/dev/2025/1229/tag.png)

---

# 3. Nginx 이미지 빌드

다음은 웹 서버 역할을 할 Nginx 이미지를 빌드한다.  
이 단계에서 **설정 파일의 변경**이 매우 중요하다.

먼저 디렉터리를 확인한다.

```shell
assu@myserver01:~/work/ch10/ex02$ ls
myFlask02  myNginx02f

assu@myserver01:~/work/ch10/ex02$ cd myNginx02f/

assu@myserver01:~/work/ch10/ex02/myNginx02f$ ls
default.conf  Dockerfile
```

---

## 3.1. Nginx 설정 파일 변경

기존 설정 파일인 `default.conf` 파일을 수정한다.

**수정 전(Docker 환경)**
```text
upstream myweb{
    server flasktest:8001;
}

server{
    listen 81; # Nginx는 81번 포트로 요청을 받음
    server_name localhost;

    location /{
        proxy_pass http://myweb;
    }
}
```

기존에는 `upstream`을 사용하여 별도의 호스트(flasktest)로 트래픽을 보냈다.  
이는 Nginx와 Flask가 서로 다른 컨테이너(또는 호스트)로 네트워크가 분리된 상태를 가정한 것이다.


**수정 후(Kubernetes 환경)**
```text
server{
    listen 80; # Nginx는 80번 포트로 요청을 받음
    server_name localhost;

    location /{
        # 127.0.0.1 (Localhost)로 포워딩
        proxy_pass http://127.0.0.1:8001;
    }
}
```

**왜 127.0.0.1 일까?**  
여기서 `proxy_pass` 주소를 *127.0.0.1:8001*로 변경했다. 이는 **Nginx 컨테이너와 Flask 컨테이너가 동일한 네트워크 네임스페이스를 공유**한다는 것을 의미한다.

Kubernetes에서 **파드**는 하나의 논리적인 호스트와 같아서, 파드 내부의 컨테이너들은 localhost를 통해 서로 통신할 수 있다.  
즉, 우리는 추후 배포 단계에서 **하나의 파드 안에 Nginx와 Flask 컨테이너를 함께 배치(멀티 컨테이너 파드 패턴 혹은 [Sidecar 패턴](https://assu10.github.io/dev/2025/12/20/sidecar-pattern/))**할 것임을 알 수 있다.

---

## 3.2. 이미지 빌드 및 Docker Hub Push

변경된 설정을 포함하여 Nginx 이미지를 빌드하고 업로드한다.

```shell
# 이미지 빌드
assu@myserver01:~/work/ch10/ex02/myNginx02f$ docker image build . -t mynginxf_ch10:0.3
[+] Building 2.2s (9/9) FINISHED                                                                                                             docker:default
... 

# 이미지 확인
assu@myserver01:~/work/ch10/ex02/myNginx02f$ docker image ls
REPOSITORY               TAG       IMAGE ID       CREATED          SIZE
mynginxf_ch10            0.3       2a658d12231a   26 seconds ago   192MB
```

이미지 업로드를 위해 도커 허브에 리포지토리를 추가한다.

![도커 허브 리포지토리 생성](/assets/img/dev/2025/1229/repo2.png)

이제 도커 이미지를 도커 허브로 업로드하기 위해 `docker tag` 명령어로 업로드 이미지를 생성한다.

```shell
# 태그 생성 및 푸시
assu@myserver01:~/work/ch10/ex02/myNginx02f$ docker tag mynginxf_ch10:0.3 assu/mynginxf_ch10:0.3

assu@myserver01:~/work/ch10/ex02/myNginx02f$ docker push assu/mynginxf_ch10:0.3
5725d8228845: Pushed
...
0.3: digest: sha256:3ee610cb3e166f6cbbff90acd4d8a88a4d6906c2cf2c44603e100baf6409e3c3 size: 2192
```

도커 허브 페이지에 들어가면 이미지가 업로드된 것을 확인할 수 있다.  
이제 Kubernetes 클러스터에 배포할 준비가 끝났다.

![업로드 확인](/assets/img/dev/2025/1229/tag2.png)

---

# 4. 디플로이먼트(Deployment) 실행

가장 먼저 애플리케이션의 Replica를 관리하고 배포를 담당하는 디플로이먼트를 생성한다.

앞서 생성한 이미지를 활용해 디플로이먼트를 생성한다.

---

## 4.1. 매니페스트 작성(Sidecar 패턴 적용)

아래 파일에서 중요한 부분은 `spec.containers` 항목이다.

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ vim flask-deploy.yml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-flask
spec:
  replicas: 3   # 파드를 3개로 유지하여 가용성 확보
  selector:
    matchLabels:
      app.kubernetes.io/name: flask-web-deploy  # 디플로이먼트가 관리할 파드 지정
  template:
    metadata:
      labels: 
        app.kubernetes.io/name: flask-web-deploy  # 파드 라벨도 동일하게 지정
    spec:
      containers:
        # 첫 번째 컨테이너: Nginx (Reverse Proxy)
        - name: nginx-f
          image: assu/mynginxf_ch10:0.3  # 도커 허브에서 가져올 이미지
          ports:
            - containerPort: 80
        # 두 번째 컨테이너: Flask (Application)
        - name: flask-web 
          image: assu/myflask_ch10:0.2
          ports:
            - containerPort: 8001
```

**Multi-container Pod 혹은 Sidecar 패턴이란?**  
위 설정처럼 하나의 파드 안에 두 개 이상의 컨테이너를 정의한다. 이들은 **동일한 네트워크 네임스페이스**를 공유한다.  
따라서 Nginx가 localhost:8001 로 요청을 보내면, 같은 파드 내의 Flask 컨테이너가 이를 수신할 수 있게 된다.

---

## 4.2. 배포 및 확인

작성한 YAML 파일을 클러스터에 적용한다.

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl apply -f flask-deploy.yml
deployment.apps/deploy-flask created
```

정상적으로 실행되었는지 확인한다.

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl get all
NAME                               READY   STATUS    RESTARTS   AGE
pod/deploy-flask-b8ffb7c86-bg6q5   2/2     Running   0          23s
pod/deploy-flask-b8ffb7c86-gj7tt   2/2     Running   0          23s
pod/deploy-flask-b8ffb7c86-zx6kq   2/2     Running   0          23s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d5h

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-flask   3/3     3            3           23s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-flask-b8ffb7c86   3         3         3       23s
```

`READY 2/2` 표시는 파드 내의 두 컨테이너(Flask, Nginx)가 모두 정상적으로 실행 중임을 의미한다.

---

# 5. 서비스(Service) 실행

파드들은 동적으로 생성되고 IP가 변경될 수 있다. 따라서 파드 집합에 대한 단일 진입점을 제공하기 위해 **Service**를 생성한다.

---

## 5.1. 매니페스트 작성 및 포트 개념 정리

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ vim flask-service.yml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  selector:
    app.kubernetes.io/name: flask-web-deploy  # Deployment의 라벨과 일치해야 함
  type: ClusterIP  # 클러스터 내부에서만 접근 가능
  ports:
    - protocol: TCP
      port: 80  # 서비스가 노출하는 포트
      targetPort: 80  # 파드(컨테이너)로 전달될 포트
```

**port vs targetPort**  
- **port**
  - **Service 자체의 포트**이다.
  - 클러스터 내부의 다른 리소스들이 이 서비스에 접근할 때 사용하는 포트이다.
  - 예: curl http://flask-service:80
- **targetPort**
  - **파드 내부 컨테이너의 포트**이다.
  - 서비스가 요청을 받으면 이 포트로 트래픽을 토스한다.
  - 여기서는 Nginx 컨테이너가 80번 포트를 열고 있으므로 80으로 설정했다.
  - 만일 Nginx 없이 Flask(8001)로 직접 연결했다면 targetPort는 8001이 되어야 한다.

---

## 5.2. Service 생성 및 확인

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl apply -f flask-service.yml
service/flask-service created

assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl get all
NAME                               READY   STATUS    RESTARTS   AGE
pod/deploy-flask-b8ffb7c86-bg6q5   2/2     Running   0          3m55s
pod/deploy-flask-b8ffb7c86-gj7tt   2/2     Running   0          3m55s
pod/deploy-flask-b8ffb7c86-zx6kq   2/2     Running   0          3m55s

NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/flask-service   ClusterIP   10.101.8.233   <none>        80/TCP    4s
service/kubernetes      ClusterIP   10.96.0.1      <none>        443/TCP   7d5h

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-flask   3/3     3            3           3m55s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-flask-b8ffb7c86   3         3         3       3m55s
```

`ClusterIP` 타입으로 생성되었으므로, 클러스터 내부 통신망이 구축되었다.

---

# 6. 인그레스(Ingress) 실행

이제 외부 사용자(Browser)가 접근할 수 있도록 L7 로드밸런서 역할을 하는 인그레스를 설정한다.

---

## 6.1. 매니페스트 작성(URL Rewriting)

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ vim flask-ingress.yml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress
  annotations:
    # [중요] 캡처 그룹($2)을 이용하여 경로 재작성
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          # 정규표현식을 사용하여 경로 매칭
          - path: /test02(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: flask-service  # 연동할 서비스 지정
                port:
                  number: 80
```

**Rewrite Target**  
사용자가 *http://domain/test02/hello* 로 접근한다고 가정해보자.  
Flask 애플리케이션은 보통 루트(`/`)나 */hello* 경로를 기다린다. */test02* 라는 접두사는 인그레스 라우팅용이지 앱 용이 아니다.
- `path: /test02(/|$)(.*)`
  - URL을 분석하여 */test02* 뒤의 나머지 부분(*hello*)을 두 번째 그룹 `(.*)`으로 캡처한다.
- `rewrite-target: /$2`
  - 캡처한 그룹 (`$2`)을 `/` 뒤에 붙여서 서비스로 전달한다.
  - 즉, */test02/hello* 요청은 */hello*로 바뀌어 파드로 전달된다.

> 인그레스 설정값에 대한 좀 더 상세한 설명은 [6. 인그레스로 하나의 서비스 배포](https://assu10.github.io/dev/2025/12/22/kubernetes-ingress-helm-metallb-baremetal-loadbalancer/#6-%EC%9D%B8%EA%B7%B8%EB%A0%88%EC%8A%A4%EB%A1%9C-%ED%95%98%EB%82%98%EC%9D%98-%EC%84%9C%EB%B9%84%EC%8A%A4-%EB%B0%B0%ED%8F%AC)
> 를 참고하세요.

---

## 6.2. 인그레스 적용 및 접속 테스트

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl apply -f flask-ingress.yml
ingress.networking.k8s.io/flask-ingress created

assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl get ingress
NAME            CLASS   HOSTS   ADDRESS     PORTS   AGE
flask-ingress   nginx   *       10.0.2.20   80      4m47s
```

웹 브라우저에서 [http://127.0.0.1:2000/test02](http://127.0.0.1:2000/test02)로 접속하면, Flask 앱이 반환하는 hello world! 메시지를 확인할 수 있다.

---

## 6.3. 전체 아키텍처 및 리소스 정리

지금까지 구성한 전체 네트워크 흐름을 시각화하면 아래와 같다.

![전체적인 네크워크 흐름](/assets/img/dev/2025/1229/flow.png)

- **User**: 브라우저에서 */test02* 로 요청
- **Ingress**: */test02* 경로를 확인하고, Rewrite 규칙에 따라 경로를 `/`로 변경하여 flask-service로 전달
- **Service**: flask-service는 연결된 파드 중 하나를 선택하여 트래픽 전달(LoadBalancing)
- **Pod**
  - **Nginx(Container 1)**: 80번 포트로 요청을 받음. 설정(`proxy_pass`)에 따라 localhost:8001로 전달
  - **Flask(Container 2)**: 8001번 포트에서 요청을 받아 hello world! 응답


이제 리소스를 정리한다.

```shell
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl delete -f flask-ingress.yml
ingress.networking.k8s.io "flask-ingress" deleted
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl delete -f flask-service.yml
service "flask-service" deleted
assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl delete -f flask-deploy.yml
deployment.apps "deploy-flask" deleted

assu@myserver01:~/work/ch10/ex02/myNginx02f$ kubectl get pod,svc,ingress
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d5h
```

---

# 정리하며..

- **Sidecar 패턴**
  - 한 파드 내에 Nginx와 Flask를 두어 localhost 통신을 구현했다.
- **Service Port**
  - `port`(서비스 노출)와 `targetPort`(컨테이너 수신)의 차이를 명확히 했다.
- **Ingress Rewrite**
  - 외부 노출 경로(/test02)와 내부 애플리케이션 경로(`/`)의 차이를 극복하기 위해 Annotations를 활용했다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)