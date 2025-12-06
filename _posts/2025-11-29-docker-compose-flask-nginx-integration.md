---
layout: post
title:  "Docker - 도커 컴포즈로 Nginx와 Flask 연동"
date: 2025-11-29 10:00:00
categories: dev
tags: devops docker docker-compose flask nginx python gunicorn reverse-proxy container-network web-application infrastructure-as-code
---

이 포스트에서는 Django가 아닌 Flask를 활용해 웹 서비스를 실행해본다.

---

**목차**

<!-- TOC -->
* [1. 환경 구축: Flask 설치 및 네트워크 설계](#1-환경-구축-flask-설치-및-네트워크-설계)
  * [1.1. Flask 라이브러리 설치](#11-flask-라이브러리-설치)
  * [1.2. 네트워크 설정(포트 포워딩)](#12-네트워크-설정포트-포워딩)
  * [1.3. Hello World: Flask 애플리케이션 작성 및 테스트](#13-hello-world-flask-애플리케이션-작성-및-테스트)
* [2. Nginx, Flask 연동 후 실행](#2-nginx-flask-연동-후-실행)
  * [2.1. 디렉터리 정리](#21-디렉터리-정리)
  * [2.2. Flask 이미지 빌드](#22-flask-이미지-빌드)
  * [2.3. Nginx 이미지 빌드](#23-nginx-이미지-빌드)
  * [2.4. Flask, Nginx 컨테이너 연동](#24-flask-nginx-컨테이너-연동)
* [3. 도커 컴포즈를 활용한 컨테이너 실행](#3-도커-컴포즈를-활용한-컨테이너-실행)
  * [3.1. docker-compose.yml 파일 작성](#31-docker-composeyml-파일-작성)
  * [3.2. 빌드 및 실행](#32-빌드-및-실행)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 환경 구축: Flask 설치 및 네트워크 설계

Nginx와 Flask를 도커 컨테이너로 연동하기 앞서 애플리케이션의 기본이 되는 Python Flask 환경을 구축하고 기본 동작을 확인한다.  
또한, 호스트와 컨테이너 간의 네트워크 통신을 위한 포트 포워딩 설계를 선행한다.

---

## 1.1. Flask 라이브러리 설치

Flask는 Python 기반의 마이크로 웹 프레임워크이다.  
Django에 비해 가볍고 확장이 용이하며, MSA나 간단한 REST API 서버를 구축할 때 매우 널리 이용된다.

먼저 프로젝트를 위한 독립적인 Python 가상 환경을 활성화한 후 Flask 라이브러리를 설치한다.

> 가상 환경 구축에 대한 내용은 [1.2. `pyenv`를 활용한 파이썬 가상 환경 구축](https://assu10.github.io/dev/2025/11/21/docker-django-nginx-gunicorn-integration/#12-pyenv%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%9C-%ED%8C%8C%EC%9D%B4%EC%8D%AC-%EA%B0%80%EC%83%81-%ED%99%98%EA%B2%BD-%EA%B5%AC%EC%B6%95) 를 참고하세요.

```shell
# pyenv로 파이썬 가상 환경(py3_13_9) 실행
assu@myserver01:~/work/ch05/ex10$ pyenv activate py3_13_9

# pip를 이용한 Flask 설치
(py3_13_9) assu@myserver01:~/work/ch05/ex10$ pip install flask
Collecting flask
  Downloading flask-3.1.2-py3-none-any.whl.metadata (3.2 kB)
...
```

설치가 완료되면 Python 인터프리터를 통해 설치가 정상적으로 이루어졌는지 버전을 확인한다.

```shell
# 파이썬 가상 환경이 실행된 상태에서 python 실행
(py3_13_9) assu@myserver01:~/work/ch05/ex10$ python
Python 3.13.9 (main, Nov 22 2025, 06:17:02) [GCC 13.3.0] on linux
Type "help", "copyright", "credits" or "license" for more information.

# Flask 라이브러리 임포트 및 버전 확인
>>> import flask
>>> from importlib.metadata import version
>>> version('flask')
'3.1.2'

# 파이썬 종료
>>> quit()

# 파이썬 가상 환경 종료
(py3_13_9) assu@myserver01:~/work/ch05/ex10$ source deactivate
pyenv-virtualenv: deactivate 3.13.9/envs/py3_13_9
```

---

## 1.2. 네트워크 설정(포트 포워딩)

도커 환경에서 서비스 간 연동을 위해서는 명확한 포트 포워딩이 필요하다.  
외부(사용자)의 요청이 호스트를 거쳐 컨테이너 내부의 애플리케이션까지 도달하는 흐름은 아래와 같이 설계한다.



![네트워크 설정(1)](/assets/img/dev/2025/1129/network.png)

<**네트워크 흐름 요약**>  
- 사용자 요청: Host IP:81 로 접근
- Nginx(Reverse Proxy): 81번 포트 요청을 받아 내부적으로 처리
- Flask(App): Nginx로부터 전달받은 요청을 처리하거나, 테스트 시 Host IP:8001을 통해 직접 접근

![네트워크 설정(2)](/assets/img/dev/2025/1129/config.png)

---

## 1.3. Hello World: Flask 애플리케이션 작성 및 테스트

도커 이미지로 빌드하기 전에 Flask 애플리케이션을 8001번 포트에서 실행하여 로컬(호스트)에서 코드가 정상적으로 동작하는지 확인하기 위한 Hello World 애플리케이션을 작성한다.

---

**1) 디렉터리 생성 및 코드 작성**

```shell
# myapp 디렉터리에 Flask 코드를 작성할 것임
assu@myserver01:~/work/ch06/ex01$ mkdir myapp
assu@myserver01:~/work/ch06/ex01$ ls
myapp
assu@myserver01:~/work/ch06/ex01$ cd myapp
assu@myserver01:~/work/ch06/ex01/myapp$
```

main.py 파일을 생성하고 아래와 같이 작성한다.

```shell
assu@myserver01:~/work/ch06/ex01/myapp$ vi main.py
```

```python
from flask import Flask

# flask 웹 애플리케이션 객체 생성 후 app이라고 지정
app = Flask(__name__)

# 루트 경로('/') 접근 시 실행될 함수 정의
@app.route('/')
def hello_world():
    return 'hello world!'

# 파이썬 스크립트가 실행되면 app.run을 통해 웹 애플리케이션 실행
if __name__ == '__main__':
    # host='0.0.0.0': 외부(모든 IP)에서의 접근 허용
    # port='8001': 8001번 포트 사용
    app.run(host='0.0.0.0', port='8001')
```

`app.run(host='0.0.0.0')` 설정은 매우 중요하다.  
기본값인 127.0.0.1 로 설정할 경우, 추후 도커 컨테이너 내부에서 실행 시 **컨테이너 외부(호스트)에서의 접근이 차단**되기 때문이다.

---

**2) 애플리케이션 실행 및 검증**

작성한 코드를 실행하여 서버를 구동한다.

```shell
# 파이썬 가상 환경 실행
assu@myserver01:~/work/ch06/ex01/myapp$ pyenv activate py3_13_9
(py3_13_9) assu@myserver01:~/work/ch06/ex01/myapp$ ls
main.py

# 파이썬으로 해당 파일 실행
(py3_13_9) assu@myserver01:~/work/ch06/ex01/myapp$ python main.py
 * Serving Flask app 'main'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8001
 * Running on http://10.0.2.4:8001
Press CTRL+C to quit
```

서버가 실행 중인 상태에서 웹 브라우저를 열어 [http://127.0.0.1:8001](http://127.0.0.1:8001)에 접속하면, 화면에 hello world!가 출력되는 것을 확인할 수 있다.

동시에 터미널 로그에는 접속 요청에 대한 200 OK 응답이 기록된다.
```shell
(py3_13_9) assu@myserver01:~/work/ch06/ex01/myapp$ python main.py
 * Serving Flask app 'main'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8001
 * Running on http://10.0.2.4:8001
Press CTRL+C to quit

# 웹 브라우저에서 http://127.0.0.1:8001 접속 시 찍히는 로그
10.0.2.2 - - [06/Dec/2025 04:32:25] "GET / HTTP/1.1" 200 -
10.0.2.2 - - [06/Dec/2025 04:32:25] "GET /favicon.ico HTTP/1.1" 404 -

# 파이썬 가상 환경 종료
^C(py3_13_9) assu@myserver01:~/work/ch06/ex01/myapp$ source deactivate
pyenv-virtualenv: deactivate 3.13.9/envs/py3_13_9
```

---

# 2. Nginx, Flask 연동 후 실행

앞서 로컬 환경에서 Flask 애플리케이션의 동작을 확인했다. 이제 이 애플리케이션을 도커 컨테이너로 전환하고, 웹 서버인 Nginx와 연동할 준비를 한다.

여기서는 Flask와 Nginx 이미지를 각각 빌드한 후, 이들을 연결하여 실행해본다.

---

## 2.1. 디렉터리 정리

[1.3. Hello World: Flask 애플리케이션 작성 및 테스트](#13-hello-world-flask-애플리케이션-작성-및-테스트)에서는 도커 호스트에서 Flask 서비스를 실행했다.  
이번에는 도커 컨테이너 형태로 Flask 서비스를 실행해본다.

```shell
assu@myserver01:~/work/ch06$ mkdir ex02
assu@myserver01:~/work/ch06$ ls
ex01  ex02

# 바로 전에 사용한 ex01 디렉터리를 ex02 디렉터리로 복사
assu@myserver01:~/work/ch06$ cp -r ex01 ex02
assu@myserver01:~/work/ch06$ cd ex02
assu@myserver01:~/work/ch06/ex02$ ls
ex01
assu@myserver01:~/work/ch06/ex02$ mv ex01 Flask02
assu@myserver01:~/work/ch06/ex02$ ls
Flask02
assu@myserver01:~/work/ch06/ex02/Flask02$ ls
myapp
```

---

## 2.2. Flask 이미지 빌드

이제 Flask 애플리케이션을 도커 이미지로 빌드한다. 단순히 Flask 내장 서버를 사용하는 것이 아니라, 운영 환경에서 성능과 안정성을 보장하기 위해 **Gunicorn(WSGI Server)**을 함께 설치한다.

**1) 라이브러리 명세서 작성(requirements.txt)**

도커 이미지 빌드 시 필요한 패키지들을 정의한다.

```shell
assu@myserver01:~/work/ch06/ex02/Flask02$ vim requirements.txt
```

```text
flask==3.1.2
gunicorn==23.0.0
```

<**Gunicorn을 사용하는 이유**>  
Flask의 기본 개발 서버(`app.run()`)는 단일 스레드로 동작하여 요청 처리에 한계가 있다.  
Gunicorn은 멀티 프로세스/스레드를 지원하는 WSGI HTTP 서버로, 실제 배포 환경에서 Flask 애플리케이션을 안정적으로 구동하기 위해 필수적이다.

---

**2) Dockerfile 작성**

이미지 빌드 명세서인 Dockerfile을 작성한다.

```shell
assu@myserver01:~/work/ch06/ex02/Flask02$ vim Dockerfile
```

```dockerfile
# Python 3.13.9 베이스 이미지 사용
FROM python:3.13.9

# 작업 디렉터리 설정
WORKDIR /usr/src/app

# 현재 디렉터리의 모든 파일을 컨테이너로 복사
COPY . .

# pip 업그레이드 및 의존성 패키지 설치
RUN python -m pip install --upgrade pip
RUN pip install -r requirements.txt

# 소스 코드가 있는 디렉터리로 이동 (main.py가 myapp 안에 있음)
WORKDIR ./myapp

# 컨테이너 실행 시 Gunicorn 구동
# --bind 0.0.0.0:8001 : 8001번 포트로 모든 IP의 요청 수신
# main:app : main.py 파일의 app 객체를 실행
CMD gunicorn --bind 0.0.0.0:8001 main:app

# 8001 포트 개방 선언
EXPOSE 8001
```

> Dockerfile에 대한 설명은 [3.2. Django 이미지 빌드](https://assu10.github.io/dev/2025/11/21/docker-django-nginx-gunicorn-integration/#32-django-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EB%B9%8C%EB%93%9C) 를 참고하세요.

---

**3) 이미지 빌드 및 확인**

작성한 Dockerfile을 기반으로 myflask02라는 태그를 가진 이미지를 빌드한다.

```shell
assu@myserver01:~/work/ch06/ex02/Flask02$ docker image build . -t myflask02
[+] Building 3.5s (7/10)                                                                                                               docker:default
 => [internal] load build definition from Dockerfile                                                                                             0.0s
 => => transferring dockerfile: 241B
```

빌드가 완료되면 이미지가 정상적으로 생성되었는지 확인한다.

```shell
assu@myserver01:~/work/ch06/ex02/Flask02$ docker image ls
REPOSITORY          TAG       IMAGE ID       CREATED         SIZE
myflask02           latest    60ff9a105b2a   9 seconds ago   1.15GB
```

Flask 애플리케이션을 실행할 수 있는 컨테이너 이미지가 준비되었다.  
이제 이 Flask 컨테이너 앞단에서 Reverse Proxy 역할을 수행할 수 있는 Nginx 이미지를 준비해보자.

---

## 2.3. Nginx 이미지 빌드

Flask 컨테이너가 준비되었으니, 사용자 요청을 받아 Flask로 전달할 Nginx 이미지를 준비한다.  
여기서 가장 중요한 것은 Nginx가 Flask 컨테이너의 위치를 알 수 있도록 설정(`default.conf`)하는 것이다.

---

**2) Nginx 설정 파일: default.conf**

Nginx 빌드를 위한 디렉터리를 생성하고 이동한다.

> default.conf 에 대한 내용은 [3.2. Django 이미지 빌드](https://assu10.github.io/dev/2025/11/21/docker-django-nginx-gunicorn-integration/#32-django-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EB%B9%8C%EB%93%9C)를 참고하세요.

```shell
assu@myserver01:~/work/ch06/ex02$ cd myNginx02f/
assu@myserver01:~/work/ch06/ex02/myNginx02f$ pwd
/home/assu/work/ch06/ex02/myNginx02f
```

Nginx의 동작 방식을 정의하는 default.conf 파일을 작성한다.  
여기서 핵심은 `upstream` 설정이다.

```shell
assu@myserver01:~/work/ch06/ex02/myNginx02f$ vim default.conf

# upstream 설정: 백엔드 서버 그룹 정의
# 'flasktest'는 추후 실행할 Flask 컨테이너의 이름(Container Name)임
# 도커 네트워크 내부 DNS를 통해 이름으로 IP를 찾음
upstream myweb{
    server flasktest:8001;
}

server{
    listen 81; # Nginx가 수신할 포트 (이번 실습에서는 81번 사용)
    server_name localhost;

    location /{
        proxy_pass http://myweb;  # 리버스 프록시 설정: 들어온 요청을 upstream 'myweb' (upstream 에 설정한 이름)으로 전달
    }
}
```

`server flasktest:8001` 부분에서 IP 주소가 아닌 _flasktest_라는 호스트명을 사용하였다.  
이는 도커의 **사용자 정의 네트워크**가 컨테이너 이름을 통해 자동으로 IP를 해석해주기 때문에 가능하다.

---

**2) Dockerfile 작성**

작성한 설정 파일을 Nginx 공식 이미지에 덮어씌우는 Dockerfile을 작성한다.

작성한 default.conf 파일을 컨테이너 내부의 설정 경로로 덮어쓰도록 Dockerfile을 수정한다.

```shell
assu@myserver01:~/work/ch06/ex02/myNginx02f$ cat Dockerfile

FROM nginx:1.25.3
# 기존 설정 삭제
RUN rm /etc/nginx/conf.d/default.conf

# 호스트에서 작성한 커스텀 설정 파일 복사
COPY default.conf /etc/nginx/conf.d/

# Nginx 실행 (daemon off: 포그라운드 실행을 유지하여 컨테이너가 종료되지 않게 함)
CMD ["nginx", "-g", "daemon off;"]
```

---

**3) 이미지 빌드**

Dockerfile과 설정 파일이 준비되었으므로 Nginx 이미지를 빌드한다.


이제 Nginx 이미지를 빌드한다.
```shell
# 이미지 빌드 (태그: mynginx02f)
assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker image build . -t mynginx02f
[+] Building 2.1s (8/8) FINISHED                                                                                                       docker:default
 => [internal] load build definition from Dockerfile                                                                                             0.0s
 => => transferring dockerfile: 217B
```

빌드가 완료되면 Flask 이미지와 Nginx 이미지가 모두 준비된 것을 확인할 수 잇다.

```shell
assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED             SIZE
mynginx02f   latest    41443b3e9f82   8 seconds ago       192MB
myflask02    latest    60ff9a105b2a   About an hour ago   1.15GB 
```

---

## 2.4. Flask, Nginx 컨테이너 연동

이제 준비된 두 개의 이미지를 컨테이너로 실행하고 연결한다.  
컨테이너 간의 원활한 통신을 위해 **도커 전용 네트워크**를 생성하여 사용한다.

---

**1) 도커 네트워크 생성**

컨테이너들이 서로 이름을 통해 통신할 수 있도록 사용자 정의 브리지 네트워크를 생성한다.

```shell
# mynetwork02f라는 이름의 네트워크 생성
assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker network create mynetwork02f
9dd0c654c80d1e2800e24d7f728992ca1bdf7250690350ae684a0341b73fdc52

# 네트워크 생성 확인
assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker network ls
NETWORK ID     NAME           DRIVER    SCOPE
a37c58c71116   bridge         bridge    local
26dfd2bd80ec   host           host      local
9dd0c654c80d   mynetwork02f   bridge    local
426836c8786b   none           null      local
```

---

**2) Flask 컨테이너 실행**

먼저 백엔드 애플리케이션인 Flask를 실행한다.

- `--name flasktest`
  - Nginx 설정(default.conf)의 `upstream`에서 이 이름을 참조함
- `--network mynetwork02f`
  - 생성해 둔 네트워크에 연결

Flask 컨테이너는 `-p` 옵션을 사용하지 않는다.  
Flask는 호스트(외부)에 직접 노출되지 않고, 오직 같은 네트워크에 있는 Nginx를 통해서만 접근 가능하다.(보안성 향상)

```shell
assu@myserver01:~/work/ch06/ex02/Flask02$ docker container run -d --name flasktest --network mynetwork02f myflask02
dab9f509999b587a9cbe261e17f2f61cbf71b4ec06c76448702a457a192fe367

assu@myserver01:~/work/ch06/ex02/Flask02$ docker container ls
CONTAINER ID   IMAGE       COMMAND                  CREATED         STATUS         PORTS      NAMES
dab9f509999b   myflask02   "/bin/sh -c 'gunicor…"   6 seconds ago   Up 5 seconds   8001/tcp   flasktest
```

---

**3) Nginx 컨테이너 실행**

이제 프론트엔드 역할을 하는 Nginx 를 실행한다.
- `--name nginxtest`
  - 컨테이너 이름 지정
- `--network mynetwork02f`
  - Flask와 동일한 네트워크에 연결해야 통신 가능
- `-p 81:81`
  - 호스트의 81번 포트를 컨테이너의 81번 포트와 연결
  - 외부 사용자는 이 포트를 통해 접속함

```shell
assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker container run -d --name nginxtest --network mynetwork02f -p 81:81 mynginx02f
1831a05515efb10a9166646c83f31f1127ddb79a5a959de1da36b0f456c43975

assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker container ls
CONTAINER ID   IMAGE        COMMAND                  CREATED         STATUS         PORTS                                         NAMES
1831a05515ef   mynginx02f   "/docker-entrypoint.…"   3 seconds ago   Up 2 seconds   80/tcp, 0.0.0.0:81->81/tcp, [::]:81->81/tcp   nginxtest
dab9f509999b   myflask02    "/bin/sh -c 'gunicor…"   6 minutes ago   Up 6 minutes   8001/tcp                                      flasktest
```

---

**4) 접속 테스트 및 구조 확인**

이제 웹 브라우저를 열어 [http://127.0.0.1:81](http://127.0.0.1:81) 에 접속하면 hello world! 가 출력되는 것을 확인할 수 있다.

이 때의 요청 흐름은 아래와 같다.
- Browser: localhost:81 요청
- Docker Host: 81번 포트를 통해 _nginxtest_ 컨테이너로 전달
- Nginx Container: 설정(proxy_pass)에 따라 http://flasktest:8001로 요청 전달
- Flask Container: 요청 처리 후 응답 반환

![네트워크 흐름](/assets/img/dev/2025/1129/service3.png)

테스트가 끝났으면 리소스 정리를 위해 컨테이너를 중지한다.

```shell
assu@myserver01:~/work/ch06/ex02/myNginx02f$ docker container stop 1831a05515ef dab9f509999b
1831a05515ef
dab9f509999b
```

---

# 3. 도커 컴포즈를 활용한 컨테이너 실행

도커 컴포즈는 여러 개의 컨테이너로 구성된 애플리케이션을 정의하고 실행하기 위한 도구이다.  
위에서 한 이미지 빌드, 컨테이너 실행, 네트워크 생성, 포트 포워딩 등의 모든 옵션은 docker-compose.yml 파일 하나에 기술할 수 있다.

---

## 3.1. docker-compose.yml 파일 작성

**1) 디렉터리 정리**

이전에 했던 디렉터리인 ex02의 코드를 그대로 활용하되, 도커 컴포즈 환경에 맞게 디렉터리 이름을 변경하여 정리한다.

```shell
assu@myserver01:~/work/ch06$ ls
ex01  ex02

# 2. Nginx, Flask 연동 후 실행 에서 사용한 ex02 디렉터리를 복사하여 ex03 디렉터리 생성
assu@myserver01:~/work/ch06$ cp -r ex02 ex03
assu@myserver01:~/work/ch06$ ls
ex01  ex02  ex03

assu@myserver01:~/work/ch06$ cd ex03
assu@myserver01:~/work/ch06/ex03$ ls
Flask02  myNginx02f

assu@myserver01:~/work/ch06/ex03$ mv Flask02 myFlask03
assu@myserver01:~/work/ch06/ex03$ mv myNginx02f myNginx03f

assu@myserver01:~/work/ch06/ex03$ ls
myFlask03  myNginx03f
```

---

**2) YAML 파일 작성**

이제 프로젝트 최상위 경로(ex03)에 docker-compose.yml 파일을 작성한다.

```shell
assu@myserver01:~/work/ch06/ex03$ vim docker-compose.yml
```

```yaml
version: "3"

services:
    # Flask 애플리케이션 서비스 정의
    flasktest:
        build: ./myFlask03  # 이미지를 빌드할 경로 (Dockerfile 위치)
        networks:
            - composenet03  # 연결할 네트워크 지정
        restart: always  # 컨테이너가 죽으면 자동으로 재시작

    # Nginx 웹 서버 서비스 정의
    nginxtest:
        build: ./myNginx03f  # 이미지를 빌드할 경로
        networks:
            - composenet03
        ports:
            - "81:81"  # 호스트:컨테이너 포트 매핑
        depends_on:
            - flasktest  # 실행 순서 제어: flasktest가 뜬 후에 실행됨
        restart: always

# 네트워크 정의
networks:
    composenet03:
```

위에서 service name인 _flasktest_ 가 도커 네트워크 내부에서 **호스트명(DNS)**으로 사용된다.  
앞서 Nginx 설정(default.conf)에서 `upstream myweb { server flasktest:8001; }` 라고 적었던 것이 바로 이 이름을 가리킨다.

Nginx 가 실행되기 전에 백엔드인 Flask가 먼저 준비되어야 하므로 `depends_on`으로 의존성을 설정한다.

---

## 3.2. 빌드 및 실행

설정 파일이 준비되었으므로 단 하나의 명령어로 두 개의 이미지를 빌드하고 컨테이너를 실행해본다.

```shell
# -d: 백그라운드 실행
# --build: 이미지가 있더라도 변경 사항을 반영하여 강제 재빌드
assu@myserver01:~/work/ch06/ex03$ docker compose up -d --build
WARN[0000] /home/assu/work/ch06/ex03/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
[+] Building 2.5s (22/22) FINISHED
...
[+] Running 5/5
 ✔ ex03-flasktest              Built                                                                                                             0.0s
 ✔ ex03-nginxtest              Built                                                                                                             0.0s
 ✔ Network ex03_composenet03   Created                                                                                                           0.0s
 ✔ Container ex03-flasktest-1  Started                                                                                                           0.2s
 ✔ Container ex03-nginxtest-1  Started                                                                                                           0.3s
```

도커 컴포즈가 자동으로 네트워크(ex03_composenet03)을 생성하고, 이미지를 빌드한 뒤, 컨테이너를 올바른 순서대로 실행시켰다.

---

**1) 컨테이너 상태 확인**

```shell
assu@myserver01:~/work/ch06/ex03$ docker container ls
CONTAINER ID   IMAGE            COMMAND                  CREATED              STATUS              PORTS                                         NAMES
f8524fd12e72   ex03-nginxtest   "/docker-entrypoint.…"   About a minute ago   Up 59 seconds       80/tcp, 0.0.0.0:81->81/tcp, [::]:81->81/tcp   ex03-nginxtest-1
9034fff13224   ex03-flasktest   "/bin/sh -c 'gunicor…"   About a minute ago   Up About a minute   8001/tcp                                      ex03-flasktest-1
```

---

**2) 접속 테스트 및 로그 확인**

웹브라우저에서 [http://127.0.0.1:81](http://127.0.0.1:81)에 접속하면 hello world! 가 출력되는 것을 확인할 수 있다.

실제 요청이 들어왔는지 Nginx 컨테이너의 로그를 통해 교차 검증을 해보자.

```shell
assu@myserver01:~/work/ch06/ex03$ docker logs f8524fd12e72
...
10.0.2.2 - - [06/Dec/2025:07:38:21 +0000] "GET / HTTP/1.1" 200 12 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36" "-"
```

HTTP 상태 코드 200 OK가 찍힌 것으로 보아 정상적으로 프록시 처리가 되었다.

---

**3) 리소스 정리(Teardown)**

이제 `docker compose down`으로 리소스를 정리한다.  
이 명령어는 컨테이너 정지 및 삭제 뿐 아니라 컴포즈가 생성했던 네트워크까지 삭제해준다.

```shell
assu@myserver01:~/work/ch06/ex03$ docker compose down
WARN[0000] /home/assu/work/ch06/ex03/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
[+] Running 3/3
 ✔ Container ex03-nginxtest-1  Removed                                                                                                           0.2s
 ✔ Container ex03-flasktest-1  Removed                                                                                                          10.1s
 ✔ Network ex03_composenet03   Removed
```


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)