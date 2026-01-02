---
layout: post
title:  "Kubernetes - 서비스(ClusterIP, NodePort, LoadBalancer, ExternalName)"
date: 2025-12-08 10:00:00
categories: dev
tags: devops kubernetes docker k8s service networking clusterip nodeport loadbalancer externalname infrastructure service-discovery
---

이 포스트에서는 쿠버네티스 서비스의 핵심 개념을 살펴보고, 실무에서 주로 사용되는 4가지 서비스 타입의 동작 원리와 차이점을 알아본다.
- ClusterIP
- NodePort
- LoadBalancer
- ExternalName

---

**목차**

<!-- TOC -->
* [1. 서비스(Service) 개념](#1-서비스service-개념)
  * [1.2. 동작 원리: 레이블 셀렉터(Label Selector)](#12-동작-원리-레이블-셀렉터label-selector)
* [2. ClusterIP](#2-clusterip)
  * [2.1. ClusterIP 서비스 생성 및 연동](#21-clusterip-서비스-생성-및-연동)
  * [2.2. 내부 통신 테스트](#22-내부-통신-테스트)
  * [2.3. 리소스 정리](#23-리소스-정리)
* [3. NodePort](#3-nodeport)
  * [3.1. NodePort 서비스 생성 및 연동](#31-nodeport-서비스-생성-및-연동)
  * [3.2. 외부 접속 테스트: 포트 포워딩](#32-외부-접속-테스트-포트-포워딩)
  * [3.3. 리소스 정리](#33-리소스-정리)
* [4. LoadBalancer](#4-loadbalancer)
  * [4.1. LoadBalancer 서비스 생성 및 연동](#41-loadbalancer-서비스-생성-및-연동)
  * [4.2. 외부 접속 테스트: 포트 포워딩](#42-외부-접속-테스트-포트-포워딩)
  * [4.3. 리소스 정리](#43-리소스-정리)
* [5. ExternalName](#5-externalname)
  * [5.1. ExternalName 서비스 생성 및 연동](#51-externalname-서비스-생성-및-연동)
  * [5.2. 도메인 연결 테스트](#52-도메인-연결-테스트)
  * [5.3. 리소스 정리](#53-리소스-정리)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 서비스(Service) 개념

쿠버네티스 환경에서 가장 먼저 이해해야 할 특성 중 하나는 파드가 **일시적(Ephemeral)**인 리소스이다.  
파드는 언제든지 삭제될 수 있고, 새로운 노드에서 다시 생성될 수 있다. 이 때 파드에 할당된 IP 주소 역시 변하게 된다.

만약 클라이언트가 파드의 IP를 직접 바라보고 통신한다면 파드가 재시작될 때마다 클라이언트는 변경된 IP를 추적해야 하므로 통신이 매우 불안정해진다.

이러한 신뢰할 수 없는 파드 IP문제를 해결하고, **클라이언트와 파드, 혹은 파드와 파드 간의 안정적인 연결을 담당하는 것이 바로 쿠버네티스 서비스(Service)**이다.

서비스(Service)는 **파드 집합에 대한 단일 진입점(Entrypoint)을 제공하고, 이들에 대한 접근 정책을 정의하는 추상화된 논리적 리소스**이다.

서비스는 동적으로 변하는 파드들의 앞단에 위치하여 **고정된 주소(IP)**를 제공하며 아래와 같은 역할을 수행한다.
- **Service Discovery(서비스 발견)**
  - 서비스를 구성하는 개별 파드들의 IP가 바뀌어도, 클라이언트는 서비스의 고정 IP(VIP)만 알면 통신 가능
- **Load Balancing(부하 분산)**
  - 하나의 서비스에 여러 개의 파드가 연결되어 있다면, 트래픽을 각 파드에 적절히 분산
- **External Exposure(외부 노출)**
  - 파드 내부 구성을 수정하지 않고도 외부로 서비스를 안전하게 노출

---

## 1.2. 동작 원리: 레이블 셀렉터(Label Selector)

서비스가 자신이 관리할 파드를 식별하는 방법은 **레이블(Label)**이다.  
YAML 이나 JSON으로 서비스를 정의할 때 `selector`를 지정하면, 해당 레이블을 가진 모든 파드가 자동으로 서비스에 연결된다.

![쿠버네티스 서비스 개념](/assets/img/dev/2025/1208/service.png)

위 그림을 통해 서비스의 동작 방식을 이해해보자.
- **파드(Pod)**
  - 파드들은 워커 노드에 존재하며 각각의 IP를 가짐
- **서비스(Service)**
  - 파드 앞단에서 고정된 진입점 역할
- **연결 기준**
  - 서비스는 **라벨(app.kubernetes.io/name: A)**이 일치하는 파드들을 찾아 연결

그림의 왼쪽처럼 **디플로이없이 단독으로 생성된 파드**든, 오른쪽처럼 **디플로이먼트와 레플리카셋에 의해 관리되는 파드**든 상관없다.  
**라벨만 동일하다면 하나의 서비스로 묶여** 클라이언트에게 단일 진입점을 제공할 수 있다.

결과적으로 개발자는 백엔드 파드가 몇 개인지, 어느 노드에 있는지 신경쓸 필요 없이 **서비스**하고만 통신하면 된다.

---

# 2. ClusterIP

**ClusterIP**는 쿠버네티스 **서비스의 기본(Default) 설정값**이다. 별도로 타입을 지정하지 않으면 자동으로 ClusterIP로 생성된다.

가장 큰 특징은 **쿠버네티스 클러스터 내부에서만 접근 가능한 고정 IP를 할당**한다는 점이다.  
즉, 클러스터 외부(인터넷 등)에서는 이 IP로 접근할 수 없으며, 클러스터 내의 다른 파드나 노드에서만 접근 가능하다.  
**주로 내부 데이터베이스나 백엔드 간의 통신에 사용**된다.

![ClusterIP 개념](/assets/img/dev/2025/1208/clusterip.png)

---

## 2.1. ClusterIP 서비스 생성 및 연동

실제 코드를 통해 ClusterIP 서비스를 생성하고, 파드 간 통신을 확인해보자.

**실습 환경 준비**

[2.3. 매니페스트를 활용한 디플로이먼트 실행(선언형)](https://assu10.github.io/dev/2025/12/07/kubernetes-pod-deployment-replicaset-guide/#23-%EB%A7%A4%EB%8B%88%ED%8E%98%EC%8A%A4%ED%8A%B8%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%9C-%EB%94%94%ED%94%8C%EB%A1%9C%EC%9D%B4%EB%A8%BC%ED%8A%B8-%EC%8B%A4%ED%96%89%EC%84%A0%EC%96%B8%ED%98%95) 에서
사용했던 ex02 디렉터리를 복사하여 새로운 디렉터리를 만든다.

```shell
assu@myserver01:~/work/ch09$ pwd
/home/assu/work/ch09
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04

assu@myserver01:~/work/ch09$ cp -r ex02 ex05
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05

assu@myserver01:~/work/ch09$ cd ex05
assu@myserver01:~/work/ch09/ex05$ ls
deploy-test01.yml
```

---

**서비스 매니페스트 작성(service-test01.yml)**

기존에 준비된 deploy-test01.yml(웹 애플리케이션 디플로이먼트)과 연결할 서비스를 정의한다.

```shell
assu@myserver01:~/work/ch09/ex05$ vim service-test01.yml
```

```yaml
apiVersion: v1          # 서비스 리소스는 v1 API 사용
kind: Service           # 리소스 종류 명시
metadata:
  name: web-service     # 서비스 이름 정의
spec:
  type: ClusterIP       # 서비스 타입 (생략 시 기본값 ClusterIP)
  selector:             # [핵심] 이 서비스가 트래픽을 전달할 파드의 라벨 지정
    app.kubernetes.io/name: web-deploy  #  생성할 서비스는 앞서 생성한 web-deploy 파드와 연결할 것이므로 서비스에 연결할 파드 정보 입력
  ports:
    - protocol: TCP
      port: 80          # 서비스가 노출할 포트
```

서비스 파일을 작성할 때는 아래와 같이 `spec.selector.app.kubernetes.io/name`을 통해 해당 서비스와 연동될 디플로이먼트를 지정해야 한다.

![yml](/assets/img/dev/2025/1208/yml.png)

---

**리소스 배포 및 확인**

디플로이먼트와 서비스를 차례로 생성한다.

```shell
# 디플로이먼트 생성
assu@myserver01:~/work/ch09/ex05$ kubectl apply -f deploy-test01.yml
deployment.apps/deploy-test01 created

# 서비스 생성
assu@myserver01:~/work/ch09/ex05$ kubectl apply -f service-test01.yml
service/web-service created
```

생성이 완료되면 `kubectl get all` 명령어로 상태를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex05$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-test01-5b8c666f54-bnmvr   1/1     Running   0          49s
pod/deploy-test01-5b8c666f54-kkqfb   1/1     Running   0          49s
pod/deploy-test01-5b8c666f54-q6pfm   1/1     Running   0          49s

NAME                  TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/kubernetes    ClusterIP   10.96.0.1     <none>        443/TCP   6d6h
service/web-service   ClusterIP   10.100.25.6   <none>        80/TCP    39s  # web-service 가 생성됨

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-test01   3/3     3            3           49s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-test01-5b8c666f54   3         3         3       49s
```

*web-service* 서비스가 생성되었고, *CLUSTER-IP 10.100.25.6* 이 할당된 것을 확인할 수 있다.  
*EXTERNAL-IP*가 `<none>`인 것은 이 서비스가 외부로 노출되지 않았음을 의미한다.

---

## 2.2. 내부 통신 테스트

ClusterIP는 외부 접근이 불가능하므로 **클러스터 내부에 별도의 '클라이언트용 파드'를 생성**하여 통신을 테스트해야 한다.  
여기서는 nginx 이미지를 사용한 간단한 파드를 생성할 것이다.

**테스트용 클라이언트 파드 생성(nginx-test01.yml)**

```shell
assu@myserver01:~/work/ch09/ex05$ vim nginx-test01.yml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx01
spec:
  containers:
    - name: nginx-test01
      image: nginx:latest
```

```shell
assu@myserver01:~/work/ch09/ex05$ kubectl apply -f nginx-test01.yml
pod/nginx01 created
```

```shell
assu@myserver01:~/work/ch09/ex05$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-test01-5b8c666f54-bnmvr   1/1     Running   0          21m
pod/deploy-test01-5b8c666f54-kkqfb   1/1     Running   0          21m
pod/deploy-test01-5b8c666f54-q6pfm   1/1     Running   0          21m
pod/nginx01                          1/1     Running   0          13s   # Nginx 파드 생성

NAME                  TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/kubernetes    ClusterIP   10.96.0.1     <none>        443/TCP   6d6h
service/web-service   ClusterIP   10.100.25.6   <none>        80/TCP    20m

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-test01   3/3     3            3           21m

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-test01-5b8c666f54   3         3         3       21m
```

---

**서비스 호출(curl)**

nginx01 파드 내부 셸로 진입하여, 위에서 생성한 *web-service*의 ClusterIP(10.100.25.6)로 HTTP 요청을 보낸다.

```shell
# nginx01 파드 내부로 접속
assu@myserver01:~/work/ch09/ex05$ kubectl exec -it nginx01 -- /bin/bash

# 서비스 IP로 요청 전송
root@nginx01:/# curl -v 10.100.25.6
*   Trying 10.100.25.6:80...
* Connected to 10.100.25.6 (10.100.25.6) port 80
* using HTTP/1.x
> GET / HTTP/1.1
> Host: 10.100.25.6
> User-Agent: curl/8.14.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< Server: nginx/1.29.4
< Date: Sat, 20 Dec 2025 10:24:07 GMT
< Content-Type: text/html
< Content-Length: 615
< Last-Modified: Tue, 09 Dec 2025 18:28:10 GMT
< Connection: keep-alive
< ETag: "69386a3a-267"
< Accept-Ranges: bytes
<
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
* Connection #0 to host 10.100.25.6 left intact

root@nginx01:/# exit
exit
```

정상적으로 응답(200 OK)이 왔다.  
이는 클라이언트 파드(nginx01)가 서비스(web-service)를 통해 백엔드 파드에 성공적으로 도달했음을 보여준다.

---

**동작 원리 확인**

이 과정은 아래 그림과 같이 동작한다.

![ClusterIP 도식화](/assets/img/dev/2025/1208/clusterip2.png)

nginx01 파드는 서비스 IP로 요청을 보냈지만, 실제 처리는 서비스 뒤에 연결된 3개의 *deploy-test01* 파드 중 하나가 수행했다.  
서비스는 들어오는 요청을 파드들에게 **로드 밸런싱**하여 전달한다.

실제로 서비스가 어떤 파드들을 바라보고 있는지(로드 밸런싱 대상) 확인하려면 `endpoints`를 조회하면 된다.

```shell
# 서비스에 연결된 파드 확인
assu@myserver01:~/work/ch09/ex05$ kubectl get endpoints web-service
NAME          ENDPOINTS                                                AGE
web-service   192.168.131.71:80,192.168.131.72:80,192.168.149.199:80   33m
```

`ENDPOINTS` 컬럼에 3개의 IP가 등록된 것을 볼 수 있다.  
이것이 실제 트래픽을 처리하는 백엔드 파드들의 IP이다.

---

## 2.3. 리소스 정리

이제 리소스들을 정리한다.

```shell
assu@myserver01:~/work/ch09/ex05$ kubectl delete -f service-test01.yml
service "web-service" deleted
assu@myserver01:~/work/ch09/ex05$ kubectl delete -f deploy-test01.yml
deployment.apps "deploy-test01" deleted
assu@myserver01:~/work/ch09/ex05$ kubectl delete -f nginx-test01.yml
pod "nginx01" deleted

# web-service 는 삭제되었고, 아래 보이는 service/kubernetes는 쿠버네티스 API 서버용 기본 서비스임
assu@myserver01:~/work/ch09/ex05$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   6d7h

assu@myserver01:~/work/ch09/ex05$ kubectl get pod
No resources found in default namespace.
```

---

# 3. NodePort

NodePort는 외부에서 쿠버네티스 클러스터로 접근할 수 있는 가장 기본적인 방법이다. 이름 그대로 **모든 노드의 특정 포트를 개방**하여 외부 트래픽을 파드로 전달한다.

- **동작 방식**
  - 클러스터 내의 **모든 노드**가 지정된 포트(기본 범위: 30000~32767)을 연다.
  - 외부에서 `<NodeIP>:<NodePort>`로 요청을 보내면, 해당 요청은 서비스로 전달되고 다시 파드로 로드 밸런싱된다.
- **포함 관계**
  - NodePort는 ClusterIP 기능을 포함한다.
  - 즉, NodePort 서비스를 만들면 ClusterIP도 자동으로 생성되어 내부 통신도 가능해진다.

![NodePort 도식화](/assets/img/dev/2025/1208/nodeport.png)

---

## 3.1. NodePort 서비스 생성 및 연동

외부에서 접속 가능한 웹 서버 환경을 구축해보자.

**실습 환경 준비**

[2.3. 매니페스트를 활용한 디플로이먼트 실행(선언형)](https://assu10.github.io/dev/2025/12/07/kubernetes-pod-deployment-replicaset-guide/#23-%EB%A7%A4%EB%8B%88%ED%8E%98%EC%8A%A4%ED%8A%B8%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%9C-%EB%94%94%ED%94%8C%EB%A1%9C%EC%9D%B4%EB%A8%BC%ED%8A%B8-%EC%8B%A4%ED%96%89%EC%84%A0%EC%96%B8%ED%98%95) 에서 
사용했던 ex02 디렉터리를 복사하여 새로운 디렉터리를 만든다.

```shell
assu@myserver01:~/work/ch09$ pwd
/home/assu/work/ch09
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05

assu@myserver01:~/work/ch09$ cp -r ex02 ex06
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06

assu@myserver01:~/work/ch09$ cd ex06
assu@myserver01:~/work/ch09/ex06$ ls
deploy-test01.yml
```

---

**디플로이먼트 확인(deploy-test01.yml)**

기존에 작성된 디플로이먼트 매니페스트를 그대로 사용한다.  
nginx 컨테이너를 3개(`replicas: 3`)를 실행하며, 라벨은 _app.kubernetes.io/name: web-deploy_ 를 가진다.

```shell
assu@myserver01:~/work/ch09/ex06$ cat deploy-test01.yml

# Pod 생성 시에는 v1, 디플로이먼트와 같이 리소스를 관리하는 오브젝트인 경우 apps/v1 사용
apiVersion: apps/v1
# 생성할 오브젝트 종류 지정
kind: Deployment
metadata:
  name: deploy-test01  # 생성할 디플로이먼트 이름 지정
# 생성할 디플로이먼트 상태 정의
spec:
  replicas: 3  # 생성할 레플리카셋 개수 정의
  selector:  #  selector는 Pod에 라벨을 붙이는 옵션이라고 생각하면 됨, selector를 활용하여 디플로이먼트가 관리할 Pod를 연결함
    # matchLabels의 app.kubernetes.io/name 으로 지정되는 이름은 selector로 적용하는 이름이 되므로 이는 Pod를 생성했을 때의 이름과 동일해야 함
    matchLabels:
      app.kubernetes.io/name: web-deploy  # (중요)이 라벨을 서비스가 찾음
    # 생성할 Pod의 템플릿
  template:
    # Pod의 메타 정보 입력
    metadata:
      labels:
        app.kubernetes.io/name: web-deploy  # 디플로이먼트가 관리할 Pod 라벨
    # Pod의 spec 정의
    spec:
      containers:
        - name: nginx
          image: nginx:latest
```

---

**NodePort 서비스 작성(service-test01.yml)**

이제 외부 노출을 위한 서비스를 작성한다.

```shell
assu@myserver01:~/work/ch09/ex06$ vim service-test01.yml
```

```yaml
apiVersion: v1
kind: Service # 오브젝트 타입 설정
metadata:
  name: web-service-nodeport  # 서비스 이름 지정
spec:   # 오브젝트의 상태 정의
  selector: # 해당 서비스가 연동하게 될 앱 정의
    app.kubernetes.io/name: web-deploy  # 디플로이먼트와 연결할 라벨
  type: NodePort    # 서비스 타입 정의
  ports:
    - protocol: TCP
      nodePort: 31001 # [외부용] 노드가 리스닝할 포트 (30000~32767)
      port: 80        # [서비스용] 클러스터 내부에서 서비스가 사용할 포트
      targetPort: 80  # [파드용] 실제 컨테이너가 띄우고 있는 포트
```

<**포트 설정 이해**>
- `nodePort`
  - 외부 사용자가 접근할 때 사용하는 포트(예: 브라우저에서 http://노드IP:31001)
- `port`
  - 클러스터 내부의 다른 파드가 이 서비스를 호출할 때 사용하는 포트
- `targetPort`
  - 트래픽이 최종적으로 도달하는 파드(컨테이너)의 포트

아래 그림은 서비스의 `selector`가 디플로이먼트의 `label`을 어떻게 찾아가는지를 보여준다.

![yml 연결](/assets/img/dev/2025/1208/yml2.png)

---

**리소스 배포 및 확인**

```shell
assu@myserver01:~/work/ch09/ex06$ kubectl apply -f deploy-test01.yml
deployment.apps/deploy-test01 created
assu@myserver01:~/work/ch09/ex06$ kubectl apply -f service-test01.yml
service/web-service-nodeport created
```

파드, 서비스, 디플로이먼트, 레플리카셋이 모두 실행 중임을 확인한다.
```shell
assu@myserver01:~/work/ch09/ex06$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-test01-5b8c666f54-nhmwn   1/1     Running   0          48s
pod/deploy-test01-5b8c666f54-t4v8q   1/1     Running   0          48s
pod/deploy-test01-5b8c666f54-w9zj2   1/1     Running   0          48s

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/kubernetes             ClusterIP   10.96.0.1        <none>        443/TCP        7d
service/web-service-nodeport   NodePort    10.103.247.183   <none>        80:31001/TCP   20s

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-test01   3/3     3            3           48s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-test01-5b8c666f54   3         3         3       48s
```

*service/web-service-nodeport*의 `PORT(S)` 항목이 `80:31001/TCP`로 표시된 것을 볼 수 있다.  
이는 내부 80번 포트가 외부 31001번 포트와 매핑되었음을 의미한다.

---

## 3.2. 외부 접속 테스트: 포트 포워딩

실제 파드가 어느 노드에 배치되었는지 확인해보자.

```shell
assu@myserver01:~/work/ch09/ex06$ kubectl get pod -o wide
NAME                             READY   STATUS    RESTARTS   AGE     IP                NODE         NOMINATED NODE   READINESS GATES
deploy-test01-5b8c666f54-nhmwn   1/1     Running   0          2m10s   192.168.131.73    myserver02   <none>           <none>
deploy-test01-5b8c666f54-t4v8q   1/1     Running   0          2m10s   192.168.149.201   myserver03   <none>           <none>
deploy-test01-5b8c666f54-w9zj2   1/1     Running   0          2m10s   192.168.149.202   myserver03   <none>           <none>
assu@myserver01:~/work/ch09/ex06$
```

파드들이 myserver02, myverser03 노드에 분산되어 있다.

---

**호스트 설정 및 포트 포워딩**

VM 환경을 사용 중이라면 호스트 PC에서 VM의 노드 포트로 접근하기 위해 추가 설정이 필요하다.

**1) Hosts 파일 확인**

VM들의 IP를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex06$ cat /etc/hosts
127.0.0.1 localhost
127.0.1.1 myserver01

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

**2) 포트 포워딩 설정**

호스트 PC(내 로컬)의 포트를 VM의 NodePort로 연결한다.

![포트 포워딩 설정](/assets/img/dev/2025/1208/portforwarding.png)

- 호스트 31051 → myserver02 (10.0.2.5):31001(NodePort)
- 호스트 31061 → myserver03 (10.0.2.6):31001(NodePort)

31051 호스트 포트로 접속하면 이를 10.0.2.5 노드의 NodePort 31001로 포트포워딩하고,
31061 호스트 포트로 접속하면 이를 10.0.2.6 노드의 NodePort 31001로 포트포워딩하도록 설정한다.

---

**브라우저 접속 확인**

웹 브라우저를 켜고 각각 [http://127.0.0.1:31051](http://127.0.0.1:31051), [http://127.0.0.1:31061](http://127.0.0.1:31061) 에 
접속하면 Nginx 환영 페이지를 볼 수 있다.

어떤 노드의 IP로 접근하든(myserver02이든 03이든), 31001 포트로 들어온 요청은 쿠버네티스 서비스에 의해 관리되는 파드 중 하나로 전달된다.

---

**트래픽 흐름도**

이 과정을 시각화하면 아래와 같다.

![NodePort를 이용하여 myserver02 접근](/assets/img/dev/2025/1208/flow.png)

- 사용자가 웹 브라우저에 127.0.0.1:31051 입력
- 포트 포워딩을 통해 myserver02(10.0.2.5)의 31001번 포트로 전달
- myserver02의 web-service-nodeport 서비스가 요청을 수신
- 서비스가 nginx 파드(targetPort 80)로 트래픽 전달 및 응답

---

## 3.3. 리소스 정리

리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex06$ kubectl delete -f service-test01.yml
service "web-service-nodeport" deleted
assu@myserver01:~/work/ch09/ex06$ kubectl delete -f deploy-test01.yml
deployment.apps "deploy-test01" deleted

assu@myserver01:~/work/ch09/ex06$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d
```

---

# 4. LoadBalancer

LoadBalancer 타입은 서비스에 고정된 공인 IP(External IP)를 할당하여 클러스터 외부에서 접근할 수 있도록 하는 가장 표준적인 방법이다.

- **동작 방식**
  - 클라우드 제공업체(AWS, GCP, Azure 등)의 로드 밸런서를 자동으로 프로비저닝하여 트래픽을 파드로 전달한다.
- **포함 관계**
  - LoadBalancer는 NodePort의 기능을 포함하여, NodePort는 ClusterIP의 기능을 포함한다.
  - 즉, LoadBalancer를 생성하면 NodePort와 ClusterIP도 자동으로 활성화된다.
- **주 용도**
  - HTTP/HTTPS 웹 서비스 등 외부 인터넷에 서비스를 노출해야 할 때 주로 사용된다.

![LoadBalancer 개념](/assets/img/dev/2025/1208/loadbalancer.png)

---

## 4.1. LoadBalancer 서비스 생성 및 연동

여기서는 로컬 VM 환경에서 LoadBalancer 타입을 설정하고, **External IP를 수동으로 지정**하여 외부 접속을 테스트해본다.

**실습 환경 준비**

[2.3. 매니페스트를 활용한 디플로이먼트 실행(선언형)](https://assu10.github.io/dev/2025/12/07/kubernetes-pod-deployment-replicaset-guide/#23-%EB%A7%A4%EB%8B%88%ED%8E%98%EC%8A%A4%ED%8A%B8%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%9C-%EB%94%94%ED%94%8C%EB%A1%9C%EC%9D%B4%EB%A8%BC%ED%8A%B8-%EC%8B%A4%ED%96%89%EC%84%A0%EC%96%B8%ED%98%95) 에서
사용했던 ex02 디렉터리를 복사하여 새로운 디렉터리를 만든다.

```shell
assu@myserver01:~/work/ch09$ pwd
/home/assu/work/ch09
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06

assu@myserver01:~/work/ch09$ cp -r ex02 ex07
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07
assu@myserver01:~/work/ch09$ cd ex07
```

---

**디플로이먼트 확인(deploy-test01.yml)**

이전과 동일한 Nginx 디플로이먼트를 사용한다.

```shell
assu@myserver01:~/work/ch09/ex07$ cat deploy-test01.yml

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

**LoadBalancer 서비스 작성(service-test01.yml)**

```shell
assu@myserver01:~/work/ch09/ex07$ vim service-test01.yml
```

서비스 타입을 LoadBalancer로 설정하고, 외부에서 접근할 IP를 명시한다.

> 참고로 AWS나 GCP 같은 클라우드 환경에서는 `externalIPs`를 지정하지 않아도 자동으로 공인 IP가 할당된다.  
> 하지만 지금(VM 환경)은 자동으로 IP를 할당해 줄 로드 밸런서가 없으므로, `externalIPs` 필드를 사용하여 myserver01 노드의 IP(10.0.2.4)를 강제로 지정한다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-loadbalancer
spec:
  selector:
    app.kubernetes.io/name: web-deploy
  type: LoadBalancer    # 서비스 타입 설정
  externalIPs:          # [중요] 외부에서 접근할 IP 수동 지정 (VM 환경용)
    - 10.0.2.4          # myserver01의 IP
  ports:
    - protocol: TCP
      nodePort: 31002   # (선택) NodePort 직접 지정. 생략 시 자동 할당.
      port: 80          # 서비스가 사용할 포트
      targetPort: 80    # 파드가 사용할 포트
```

LoadBalancer를 생성할 때는 NodePort를 사용하지 않아도 되지만 여기서는 NodePort를 지정한다.
NodePort를 지정하지 않으면 자동으로 설정한다.

아래 그림은 서비스의 `selector`가 디플로이먼트의 `label`을 어떻게 찾아가는지를 보여준다.

![LoadBalancer yml과 디플로이먼트 yml 연동](/assets/img/dev/2025/1208/yml3.png)

---

**리소스 배포 및 확인**

디플로이먼트와 서비스를 생성한다.

```shell
assu@myserver01:~/work/ch09/ex07$ kubectl apply -f deploy-test01.yml
deployment.apps/deploy-test01 created
assu@myserver01:~/work/ch09/ex07$ kubectl apply -f service-test01.yml
service/web-service-loadbalancer created
```

생성 상태를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex07$ kubectl get pod -o wide
NAME                             READY   STATUS    RESTARTS   AGE     IP                NODE         NOMINATED NODE   READINESS GATES
deploy-test01-5b8c666f54-gbsq4   1/1     Running   0          5m16s   192.168.131.75    myserver02   <none>           <none>
deploy-test01-5b8c666f54-sqs75   1/1     Running   0          5m16s   192.168.149.203   myserver03   <none>           <none>
deploy-test01-5b8c666f54-xlzth   1/1     Running   0          5m16s   192.168.131.74    myserver02   <none>           <none>
assu@myserver01:~/work/ch09/ex07$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-test01-5b8c666f54-gbsq4   1/1     Running   0          5m24s
pod/deploy-test01-5b8c666f54-sqs75   1/1     Running   0          5m24s
pod/deploy-test01-5b8c666f54-xlzth   1/1     Running   0          5m24s

# 외부 아이피로 설정한 10.0.2.4로 이후에 접속할 예정
NAME                               TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/kubernetes                 ClusterIP      10.96.0.1      <none>        443/TCP        7d2h
service/web-service-loadbalancer   LoadBalancer   10.105.85.20   10.0.2.4      80:31002/TCP   5m19s

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-test01   3/3     3            3           5m24s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-test01-5b8c666f54   3         3         3       5m24s
```

`EXTERNAL-IP` 항목에 우리가 지정한 10.0.2.4 가 할당된 것을 볼 수 있다.  
이제 외부에서는 10.0.2.4:80 으로 접근이 가능해진다.

---

## 4.2. 외부 접속 테스트: 포트 포워딩

호스트 PC(내 로컬)에서 VM 내부의 LoadBalancer IP로 접근하기 위해 포트 포워딩 설정을 확인해야 한다.

![포트 포워딩 확인](/assets/img/dev/2025/1208/forwarding.png)

호스트 포트 80번에 대해 myserver01(10.0.2.4) 의 포트 80으로 포트 포워딩이 되어있어야 한다.

이제 웹 브라우저에서 [http://127.0.0.1:80](http://127.0.0.1:80)으로 접속하면 VM 내부의 10.0.2.4:80으로 트래픽이 전달되어 Nginx 환영 페이지가 출력된다.

---

**트래픽 흐름도**

전체적인 트래픽 흐름을 정리하면 아래와 같다.

![LoadBalancer 흐름](/assets/img/dev/2025/1208/loadbalancer2.png)

---

## 4.3. 리소스 정리

리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex07$ kubectl delete -f service-test01.yml
service "web-service-loadbalancer" deleted
assu@myserver01:~/work/ch09/ex07$ kubectl delete -f deploy-test01.yml
deployment.apps "deploy-test01" deleted

assu@myserver01:~/work/ch09/ex07$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d3h
```

---

# 5. ExternalName

ExternalName은 위의 살펴본 3가지 유형(ClusterIP, NodePort, LoadBalancer)과는 성격이 조금 다르다.  
파드의 트래픽을 로드 밸런싱하는 것이 아니라, **서비스 이름을 외부 도메인(DNS)에 매핑(CNAME)**해주는 역할을 한다.

- **동작 방식**
  - 클러스터 내부에서 해당 서비스(web-service-externalname)를 호출하면, 쿠버네티스 DNS가 설정된 외부 도메인(www.google.com)의 CNAME 레코드를 반환한다.
- **특징**
  - ClusterIP나 NodePort를 할당받지 않는다.
  - 프록시를 거치지 않고 DNS 수준에서 리다이렉트한다.
- **활용**
  - 클러스터 내부의 애플리케이션이 외부의 데이터베이스나 서드파티 API를 호출할 때, 코드 변경 없이 서비스 이름만으로 접근 구성을 변경하고 싶을 때 사용한다.


![ExternalName 개념](/assets/img/dev/2025/1208/external.png)

---

## 5.1. ExternalName 서비스 생성 및 연동

외부 도메인인 www.google.com 을 가리키는 서비스를 만들어보자.

**실습 환경 준비**

[1.3. 매니페스트(Manifest)를 활용한 Pod 실행](https://assu10.github.io/dev/2025/12/07/kubernetes-pod-deployment-replicaset-guide/#13-%EB%A7%A4%EB%8B%88%ED%8E%98%EC%8A%A4%ED%8A%B8manifest%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%9C-pod-%EC%8B%A4%ED%96%89) 에서 
사용한 ex01 디렉터리를 복사하여 ex08 디렉터리를 생성한다.

```shell
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07

assu@myserver01:~/work/ch09$ cp -r ex01 ex08
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08

assu@myserver01:~/work/ch09$ cd ex08
assu@myserver01:~/work/ch09/ex08$ ls
nginx-test01.yml
```

**테스트용 파드 준비(nginx-test01.yml)**

기본적인 Nginx 파드 매니페스트를 준비한다.

```shell
assu@myserver01:~/work/ch09/ex08$ cat nginx-test01.yml

apiVersion: v1
kind: Pod
metadata:
  name: nginx01
spec:
  containers:
  - name: nginx-test01
    image: nginx:latest
```

---

**ExternalName 서비스 작성(service-test01.yml)**

`type: ExternalName`을 지정하고, `externalName` 필드에 연결하고 싶은 외부 도메인 주소를 입력한다.

```shell
assu@myserver01:~/work/ch09/ex08$ vim service-test04.yml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-externalname    # 서비스 이름
spec:
  type: ExternalName                # 서비스 타입
  externalName: www.google.com      # 연결할 외부 도메인 (CNAME)
```

---

**리소스 배포 및 확인**

```shell
assu@myserver01:~/work/ch09/ex08$ kubectl apply -f service-test04.yml
service/web-service-externalname created
assu@myserver01:~/work/ch09/ex08$ kubectl apply -f nginx-test01.yml
pod/nginx01 created
```

생성된 서비스를 조회해본다.

```shell
assu@myserver01:~/work/ch09/ex08$ kubectl get all
NAME          READY   STATUS    RESTARTS   AGE
pod/nginx01   1/1     Running   0          20s

NAME                               TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)   AGE
service/kubernetes                 ClusterIP      10.96.0.1    <none>           443/TCP   7d3h
service/web-service-externalname   ExternalName   <none>       www.google.com   <none>    25s

assu@myserver01:~/work/ch09/ex08$ kubectl get pod -o wide
NAME      READY   STATUS    RESTARTS   AGE    IP               NODE         NOMINATED NODE   READINESS GATES
nginx01   1/1     Running   0          5m8s   192.168.131.78   myserver02   <none>           <none>
```

*service/web-service-externalname* 을 보면 `CLUSTER-IP`가 `<none>`이고, `EXTERNAL-IP`가 www.google.com 으로 설정된 것을 확인할 수 있다.

---

## 5.2. 도메인 연결 테스트

이제 nginx01 파드 내부에서 서비스를 호출했을 때 구글로 연결이 되는지 확인해보자.

```shell
# 파드 내부 셸 접속
assu@myserver01:~/work/ch09/ex08$ kubectl exec -it nginx01 -- /bin/bash

# 서비스 이름으로 curl 요청
root@nginx01:/# curl 'web-service-externalname'
<!DOCTYPE html>
<html lang=en>
  <meta charset=utf-8>
  <title>Error 404 (Not Found)!!1</title>
...
```

curl 명령을 실행했을 때 구글의 404 페이지 HTML이 반환되었다.  
404 에러가 떴다는 것은 *web-service-externalname* 이라는 내부 서비스 이름을 통해 실제 외부의 구글 서버(www.google.com)까지 네트워크 도달에 성공했다는 뜻이다.(= DNS Resolution 성공)  
404가 뜬 이유는 구글 서버 입장에서는 요청 헤더의 Host가 www.google.com 이 아닌 web-service-externalname 으로 들어왔거나, 
루트 경로 접근 정책에 의해 404를 반환한 것이다.  
중요한 것은 **클러스터 내부에서 서비스 이름을 통해 외부 리소스에 접근했다**는 사실이다.

---

**트래픽 흐름**

지금까지의 흐름을 정리하면 아래 그림과 같다.

![ExternalName 흐름](/assets/img/dev/2025/1208/flow02.png)

- 파드가 *web-service-externalname* 을 조회함
- 쿠버네티스 DNS가 www.google.com CNAME을 반환함
- 파드는 실제 www.google.com 의 IP로 요청을 보냄

---

## 5.3. 리소스 정리

리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex08$ kubectl delete -f nginx-test01.yml
pod "nginx01" deleted
assu@myserver01:~/work/ch09/ex08$ kubectl delete -f service-test04.yml
service "web-service-externalname" deleted

assu@myserver01:~/work/ch09/ex08$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d3h
```

---

# 정리하며..

쿠버네티스의 서비스(Service)의 개념과 4가지 핵심 유형에 대해 알아보았다.
- `ClusterIP`
  - 클러스터 내부 통신용(기본값)
- `NodePort`
  - 외부에서 노드의 포트를 통해 접근
- `LoadBalancer`
  - 클라우드 환경에서 외부 로드 밸런서(IP)를 통해 접근
- `ExternalName`
  - 외부 도메인을 내부 서비스 이름으로 매핑

서비스는 파드의 동적인 IP 문제를 해결하고, 안정적인 네트워크 통신을 보장하는 쿠버네티스 리소스이다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)