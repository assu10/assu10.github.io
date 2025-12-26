---
layout: post
title:  "Kubernetes - 스테이트풀셋(StatefulSet) vs 디플로이먼트(Deployment)"
date: 2025-12-21 10:00:00
categories: dev
tags: devops kubernetes k8s statefulset-vs-deployment statefulset headless-service k8s-networking
---

[디플로이먼트(Deployment)](https://assu10.github.io/dev/2025/12/07/kubernetes-pod-deployment-replicaset-guide/#2-%EB%94%94%ED%94%8C%EB%A1%9C%EC%9D%B4%EB%A8%BC%ED%8A%B8deployment)는 
쿠버네티스에서 가장 널리 사용되는 리소스 중 하나로, 웹 서버와 같이 상태가 없는(Stateless) 애플리케이션을 배포하고 관리하는데 최적화되어 있다.  
디플로이먼트 환경에서 각 파드는 언제든지 삭제되고 새로운 파드로 대체될 수 있는, 이른바 **'대체 가능한(Fungible)'** 존재이다.

하지만 데이터베이스나 분산 코디네이터(예: ZooKeeper)와 같이 **상태(State)**를 유지해야 하는 애플리케이션을 운영해야 한다면 어떻게 해야할까?

**스테이트풀셋(StatefulSet)**은 바로 이러한 요구사항을 충족하기 위해 설계되었다.  
개념적으로는 디플로이먼트와 유사하게 파드 집합을 관리하지만, 그 동작 방식에는 결정적인 차이가 있다.

- **디플로이먼트(Deployment)**
  - 각 파드는 서로 **대체 가능**하다. 이름이 바뀌거나 IP가 변경되어도 서비스에 지장이 없는 경우에 사용한다.
- **스테이트풀셋(StatefulSet)**
  - 각 파드는 동일한 스펙이라 하더라도 고유한 식별자를 가지며 **독자성을 유지**한다. 따라서 하나의 파드를 다른 파드로 임의로 **대체할 수 없다.**

여기서는 쿠버네티스에서 상태가 있는 애플리케이션을 안정적으로 운영하기 위한 **스테이트풀셋의 개념과 구체적인 사용 방법**에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 스테이트풀셋(StatefulSet) 개념](#1-스테이트풀셋statefulset-개념)
* [2. 헤드리스 서비스(Headless Service)](#2-헤드리스-서비스headless-service)
* [3. 스테이트풀셋 생성](#3-스테이트풀셋-생성)
  * [3.1. 데이터베이스의 리플리케이션과 스테이트풀셋](#31-데이터베이스의-리플리케이션과-스테이트풀셋)
* [4. 스테이트풀셋 접속 테스트](#4-스테이트풀셋-접속-테스트)
* [5. 스테이트풀셋 볼륨](#5-스테이트풀셋-볼륨)
  * [5.1. 스케일링 이슈: 정적 프로비저닝의 한계](#51-스케일링-이슈-정적-프로비저닝의-한계)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 스테이트풀셋(StatefulSet) 개념

쿠버네티스에서 **스테이트풀셋**은 애플리케이션의 상태(State)를 관리해야 하는 워크로드 API 오브젝트이다.  
여기서 워크로드는 쿠버네티스 상에서 구동되는 애플리케이션을 의미한다.

위에서 언급했듯이 스테이트풀셋은 파드를 관리한다는 점에서 디플로이먼트와 유사하지만 **파드의 독자성(Identity)**이 있다는 점에서 차이가 있다.  
디플로이먼트에서의 각 파드는 이름이 바뀌거나 IP가 변경되어도 각 파드가 서로 대체가 가능하지만, 스테이트풀셋은 각 파드가 고유한 식별자를 가지므로 파드 간 대체가 불가능하다.

스테이트풀셋으로 생성된 파드들은 동일한 컨테이너 스펙을 가지고 있더라도 서로 교체될 수 없으며, 파드가 재스케줄링 되더라도 **영구적인 식별자**를 유지한다.

**언제 스테이트풀셋을 사용해야 할까?**  
스테이트풀셋은 아래와 같은 요구사항이 있을 때 유용하다.  
- **안정적이고 고유한 네트워크 식별자**
  - 파드가 재시작되어도 변하지 않는 호스트 이름이 필요할 때
- **안정적인 퍼시스턴트 스토리지**
  - 각 파드가 자신만의 고유한 데이터를 유지해야 할 때
- **순차적인 배포와 스케일링**
  - 순서에 맞춰 파드를 생성하거나 제거해야 할 때
- **순차적이고 자동화된 롤링 업데이트**
  - 롤링 업데이트: 구버전 파드를 하나씩 줄이고 신버전 파드를 하나씩 늘리는 방식으로 배포를 진행
  - 정해진 순서대로 업데이트가 필요할 때

---

# 2. 헤드리스 서비스(Headless Service)

스테이트풀셋을 제대로 활용하기 위해서는 파드들의 개별 네트워크를 식별해 줄 서비스가 필요하다. 이 때 사용하는 것이 바로 **헤드리스 서비스**이다.

헤드리스 서비스의 가장 큰 특징은 [ClusterIP](https://assu10.github.io/dev/2025/12/08/kubernetes-service-concept-and-types/#2-clusterip)가 없는 것이다.  
일반적인 서비스가 부하 분산(LoadBalancing)을 위해 가상의 IP(ClusterIP)를 가지는 것과 달리, 헤드리스 서비스는 DNS 쿼리에 대해 파드들의 IP 주소 목록을 직접 반환한다.

---

**실습 환경 준비**

먼저 실습을 위한 디렉터리를 생성하고 정리한다.

```shell
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08  ex09  ex10  ex11

assu@myserver01:~/work/ch09$ mkdir ex12
assu@myserver01:~/work/ch09$ cd ex12
assu@myserver01:~/work/ch09/ex12$ ls
```

---

**헤드리스 서비스 매니페스트 작성(statefulset-service.yml)**

ClusterIP를 `None`으로 설정하여 헤드리스 서비스를 정의한다.
```shell
assu@myserver01:~/work/ch09/ex12$ vim statefulset-service.yml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sfs-service01
spec:
  selector: # 어떤 스테이트풀셋과 연동할 지 정의
    # 이 서비스가 트래픽을 전달할 파드를 선택하는 라벨(이후 생성할 스테이트풀셋과 일치해야 함)
    app.kubernetes.io/name: web-sfs01
  type: ClusterIP # 서비스 타입 정의
  clusterIP: None # 핵심: None으로 설정하여 헤드리스 서비스로 만듦
  ports:
    - protocol: TCP
      port: 80
```

---

**헤드리스 서비스 실행 및 확인**

작성한 서비스를 생성하고 정보를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f statefulset-service.yml
service/sfs-service01 created

assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   12d   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    24s   app.kubernetes.io/name=web-sfs01
```

위 결과에서 볼 수 있듯이 sfs-service01의 `CLUSTER-IP`가 **None** 으로 설정된 것을 확인할 수 있다.

---

# 3. 스테이트풀셋 생성

이제 헤드리스 서비스와 연동될 스테이트풀셋을 생성한다.

```shell
assu@myserver01:~/work/ch09/ex12$ vim statefulset-web01.yml
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sfs-test01    # 스테이트풀셋 리소스의 이름
spec:   # 스테이트풀셋 상태 정의
  replicas: 3   # 스테이트풀셋이 생성할 파드의 개수 정의(0,1,2 순서로 생성됨)
  selector:   # 스테이트풀셋의 selector의 matchLabels 를 통해 파드를 하나로 묶어줌
    matchLabels:
      app.kubernetes.io/name: web-sfs01
  serviceName: sfs-service01    # 중요: 앞서 생성한 헤드리스 서비스의 이름을 지정하여 네트워크 식별자 생성
  template:
    metadata:
      labels:
        # selector.matchLabels와 동일해야 함
        app.kubernetes.io/name: web-sfs01
    spec:
      containers:
        - name: nginx
          image: nginx:latest
```

**스테이트풀셋과 헤드리스 서비스의 연결**  
`spec.serviceName` 필드는 스테이트풀셋 내의 파드들이 네트워크 도메인을 가질 수 있도록 헤드리스 서비스를 지정하는 역할을 한다.

![스테이트풀셋과 헤드리스 서비스 연결](/assets/img/dev/2025/1221/yml.png)

---

**스테이트풀셋 실행 및 파드 이름 확인**

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f statefulset-web01.yml

assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME               READY   STATUS    RESTARTS   AGE   IP                NODE         NOMINATED NODE   READINESS GATES
pod/sfs-test01-0   1/1     Running   0          10s   192.168.131.87    myserver02   <none>           <none>
pod/sfs-test01-1   1/1     Running   0          7s    192.168.149.209   myserver03   <none>           <none>
pod/sfs-test01-2   1/1     Running   0          4s    192.168.131.88    myserver02   <none>           <none>

NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   12d   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    21m   app.kubernetes.io/name=web-sfs01

NAME                          READY   AGE   CONTAINERS   IMAGES
statefulset.apps/sfs-test01   3/3     10s   nginx        nginx:latest
```

실행 결과를 보면 파드의 이름이 규칙적임을 알 수 있다.  
디플로이먼트가 `pod-name-x9d2s` 처럼 무작위 해시값을 사용하는 것과 달리, 스테이트풀셋은 `<스테이트풀셋이름>-<순서(ordinal)>` 형식(0부터 시작)으로 이름을 부여한다.
- sfs-test01-0
- sfs-test01-1
- sfs-test01-2

---

**스테이트풀셋 스케일링(Scale Down) 테스트**

이미 실행 중인 파드 개수를 줄였을 때(Scale Down), 어떤 파드가 삭제되는지 확인해보자.  
디플로이먼트는 랜덤하게 파드를 삭제했지만, 스테이트풀셋은 다르다.

파드 개수(`replicas`)를 3개에서 2개로 줄여보자.
```shell
assu@myserver01:~/work/ch09/ex12$ vim statefulset-web02.yml
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sfs-test01
spec:
  replicas: 2   # 기존 3개에서 2개로 변경
  selector:
    matchLabels:
      app.kubernetes.io/name: web-sfs01
  serviceName: sfs-service01
  template:
    metadata:
      labels: 
        app.kubernetes.io/name: web-sfs01
    spec:
      containers:
        - name: nginx
          image: nginx:latest
```

변경 사항을 반영한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f statefulset-web02.yml
statefulset.apps/sfs-test01 configured
```

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME               READY   STATUS    RESTARTS   AGE     IP                NODE         NOMINATED NODE   READINESS GATES
pod/sfs-test01-0   1/1     Running   0          4m23s   192.168.131.87    myserver02   <none>           <none>
pod/sfs-test01-1   1/1     Running   0          4m20s   192.168.149.209   myserver03   <none>           <none>

NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   12d   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    25m   app.kubernetes.io/name=web-sfs01

NAME                          READY   AGE     CONTAINERS   IMAGES
statefulset.apps/sfs-test01   2/2     4m23s   nginx        nginx:latest
```

결과를 보면 `sfs-test01-1` 파드만 삭제되고, 0번과 1번 파드는 유지된 것을 확인할 수 있다.

이처럼 스테이트풀셋은 스케일 다운 시 **가장 나중에 생성된 파드(가장 높은 번호)부터 순차적으로 삭제**한다.  
이는 데이터베이스의 리플리케이션 등 순서가 중요한 환경에서 매우 중요한 특성이다.

---

## 3.1. 데이터베이스의 리플리케이션과 스테이트풀셋

데이터베이스 리플레케이션이란, 데이터의 안정성과 가용성을 높이기 위해 원본 데이터베이스의 데이터를 복제하여 하나 이상의 복제본 서버에 실시간 혹은 비동기로 동기화하는 기술을 말한다.

대부분의 스테이트풀(Stateful) 애플리케이션, 특히 데이터베이스는 Primary(Master)-Replica(Slave) 구조를 가진다.

Primary는 주 서버로 보통 쓰기와 읽기는 모두 담당하며, 데이터의 원본이 된다.  
StatefulSet에서는 관례적으로 인덱스 번호가 가장 낮은 **Pod-0**이 이 역할을 맡는 경우가 많다.

Replica는 Primary의 데이터를 복제해 오며, 보통 읽기 전용으로 쓰거나 Primary가 죽었을 때를 대비한 예비 서버 역할을 한다. (**Pod-1, Pod-2 등**)

스케일 다운 시 **가장 높은 번호(가장 나중에 생성된 파드)부터 역순으로 삭제하는 이유**는 **데이터의 무결성과 클러스터의 Leader를 보호**하기 위해서이다.  
랜덤으로 삭제하다가 만일 Pod-0(Primary)이 삭제된다면 데이터의 원본이 사라져 남은 Pod-1, Pod-2는 새로운 리더를 선출(Election)하는 과정을 거쳐야 하는데 
이 과정에서 **서비스 중단(Downtime)**이나 **데이터 유실**이 발생할 수 있다.

요약하면 아래와 같다.  
- **리플리케이션 구조 보호**
- 데이터의 원본인 Primary(낮은 인덱스)를 끝까지 살려두어 서비스 지속성 보장
- **데이터 정합성 유지**
- 복제본(Replica)부터 순차적으로 제거함으로써 리더 선출에 따른 불필요한 장애 상황 방지

이것이 **Stateless한 웹 서버를 다루는 Deployment와의 가장 큰 차이점**이다.

---

# 4. 스테이트풀셋 접속 테스트

스테이트풀셋으로 생성된 파드들이 정상적으로 네트워크 통신이 가능한지 확인해보자.  
외부에서 직접 접속하는 대신, 클러스터 내부에 테스트용 임시 파드(Nginx)를 생성하여 내부 통신을 시도한다.

---

**테스트용 파드 생성(nginx-test01.yml)**

먼저 curl 명령어를 사용할 수 있는 Nginx 파드를 하나 생성한다.

```shell
assu@myserver01:~/work/ch09/ex12$ vim nginx-test01.yml
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
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f nginx-test01.yml
pod/nginx01 created
```

파드가 정상적으로 실행(`Running`) 상태가 될 때까지 기다린 후 IP 정보를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME               READY   STATUS    RESTARTS   AGE     IP                NODE         NOMINATED NODE   READINESS GATES
pod/nginx01        1/1     Running   0          6s      192.168.131.89    myserver02   <none>           <none>
pod/sfs-test01-0   1/1     Running   0          7m34s   192.168.131.87    myserver02   <none>           <none>
pod/sfs-test01-1   1/1     Running   0          7m31s   192.168.149.209   myserver03   <none>           <none>

NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   12d   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    28m   app.kubernetes.io/name=web-sfs01

NAME                          READY   AGE     CONTAINERS   IMAGES
statefulset.apps/sfs-test01   2/2     7m34s   nginx        nginx:latest
```

---

**파드 간 통신 확인**

이제 nginx01 파드 내부로 진입하여 스테이트풀셋의 첫 번째 파드(sfs-test01-0, IP: 192.168.131.87)로 HTTP 요청을 보내보자.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl exec -it nginx01 -- /bin/bash

# 스테이트풀셋 파드(sfs-test01-0)의 IP로 접속 시도
root@nginx01:/# curl 192.168.131.87
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
...

root@nginx01:/# exit
exit
```

Nginx의 환영 메시지가 출력되는 것으로 보아 파드 간 네트워크 통신이 원활함을 확인할 수 있다.  
테스트가 끝났으므로 리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl delete pods --all
pod "nginx01" deleted
pod "sfs-test01-0" deleted
pod "sfs-test01-1" deleted

assu@myserver01:~/work/ch09/ex12$ kubectl delete services,statefulsets --all
service "kubernetes" deleted
service "sfs-service01" deleted
statefulset.apps "sfs-test01" deleted

assu@myserver01:~/work/ch09/ex12$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   27s
```

---

# 5. 스테이트풀셋 볼륨

스테이트풀셋의 강력한 기능 중 하나는 **각 파드마다 고유한 스토리지를 자동으로 생성하고 연결**할 수 있다는 점이다.  
이를 이해하기 위해 `volumeClaimTemplates`를 사용해보자.

---

**헤드리스 서비스 재실행**

[2. 헤드리스 서비스(Headless Service)](#2-헤드리스-서비스headless-service)에서 작성했던 statefulset-service.yml 을 다시 실행한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f statefulset-service.yml
service/sfs-service01 created

assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   10m   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    6s    app.kubernetes.io/name=web-sfs01
```

---

**정적 프로비저닝: PV(PersistentVolume) 생성(statefulset-vol01-pv.yml)**

테스트를 위한 물리적 볼륨 역할을 할 `PV`를 생성한다.  
여기서는 호스트 경로(`hostPath`)를 사용한다.

```shell
assu@myserver01:~/work/ch09/ex12$ vim statefulset-vol01-pv.yml
```

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-sfs01
spec:   # PersistentVolume의 내부 상태 정의
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 100Mi  # 100MB 용량
  persistentVolumeReclaimPolicy: Retain
  storageClassName: pv-sfs-test01   # 중요: 이 클래스 이름을 기억해야 함
  hostPath:   # 볼륨 타입은 hostPath
    path: /home/assu/work/volhost01
    type: DirectoryOrCreate
```

> `persistentVolumeReclaimPolicy` 에 대한 설명은 [4.2. `PV` 및 `PVC` 생성](https://assu10.github.io/dev/2025/12/20/kubernetes-volume-basic-emptydir-hostpath-pv/#42-pv-%EB%B0%8F-pvc-%EC%83%9D%EC%84%B1)을 참고하세요.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f statefulset-vol01-pv.yml
persistentvolume/pv-sfs01 created

assu@myserver01:~/work/ch09/ex12$ kubectl get pv -o wide
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE   VOLUMEMODE
pv-sfs01   100Mi      RWO            Retain           Available           pv-sfs-test01   <unset>                          11s   Filesystem

# 스테이트볼륨은 kubectl get all 로 조회되지 않음
assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE     SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   4h50m   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    4h39m   app.kubernetes.io/name=web-sfs01
```

---

**`volumeClaimTemplates`를 이용한 스테이트풀셋 생성(statefulset-vol02.yml)**

이제 스테이트풀셋을 정의한다.  
여기서 핵심은 **PVC를 별도로 생성하지 않고, 스테이트풀셋 명세 안에 템플릿으로 정의**한다는 점이다.

```shell
assu@myserver01:~/work/ch09/ex12$ vim statefulset-vol02.yml
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
 name: sfs-test01
spec:
 replicas: 1
 selector:
  matchLabels:
   app.kubernetes.io/name: web-sfs01  # 스테이트풀셋이 관리할 앱 정의
 serviceName: sfs-service01   # 스테이트풀셋이 사용할 헤드리스 서비스 정의
 template:
  metadata:
   labels:
    app.kubernetes.io/name: web-sfs01 # selector.matchLabels.app.kubernetes.io/name과 동일하게 설정
  spec:
   containers:
    - name: nginx
      image: nginx:latest
      volumeMounts:   # 컨테이너 내부에 마운트할 볼륨 정보 설정
       - name: sfs-vol01    # 아래 templates에서 정의한 이름과 일치
         mountPath: /mount01
 volumeClaimTemplates:    # PVC 역할, 따라서 스테이트풀셋이 볼륨을 사용할 때는 PVC 파일을 따로 작성하지 않음
  - metadata:
      name: sfs-vol01
    spec:
     accessModes: [ "ReadWriteOnce" ]
     storageClassName: pv-sfs-test01  # statefulset-vol01-pv.yml 의 storageClassName과 동일해야 함
     resources:
      requests:
       storage: 20Mi
```

스테이트풀셋을 실행하고 파드가 정상적으로 생성되는지 확인한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl get pod,pv,pvc -o wide
NAME               READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
pod/sfs-test01-0   1/1     Running   0          17m   192.168.131.91   myserver02   <none>           <none>

NAME                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE   VOLUMEMODE
persistentvolume/pv-sfs01   100Mi      RWO            Retain           Bound    default/sfs-vol01-sfs-test01-0   pv-sfs-test01   <unset>                          22m   Filesystem

NAME                                           STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/sfs-vol01-sfs-test01-0   Bound    pv-sfs01   100Mi      RWO            pv-sfs-test01   <unset>                 17m   Filesystem
```

결과를 보면 `PVC` 이름이 _sfs-vol01-sfs-test01-0_ 으로 생성된 것을 볼 수 있다.  
이는 다음과 같은 규칙으로 자동 생성된 것이다.

- **PVC 이름 규칙**: `<volumeClaimTemplates 이름>-<파드 이름>`

![헤드리스 서비스, 스테이트풀셋, 볼륨 간의 관계](/assets/img/dev/2025/1221/yml2.png)

---

## 5.1. 스케일링 이슈: 정적 프로비저닝의 한계

만약 파드 개수(`replicas`)를 1개에서 2개로 늘리면 어떻게 될까?  
기존의 stateful-vol02.yml 에서 파드 개수만 2개로 늘려서 적용해보자.

```shell
assu@myserver01:~/work/ch09/ex12$ vim statefulset-vol03.yml
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sfs-test01
spec:
  replicas: 2   # 파드 개수만 2개로 변경
  selector:
    matchLabels:
      app.kubernetes.io/name: web-sfs01
  serviceName: sfs-service01
  template:
    metadata:
      labels:
        app.kubernetes.io/name: web-sfs01
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          volumeMounts:
            - name: sfs-vol01
              mountPath: /mount01
  volumeClaimTemplates:
    - metadata:
        name: sfs-vol01
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: pv-sfs-test01
        resources:
          requests:
            storage: 20Mi
```

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl apply -f statefulset-vol03.yml
statefulset.apps/sfs-test01 configured

assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME               READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
pod/sfs-test01-0   1/1     Running   0          30m   192.168.131.91   myserver02   <none>           <none>
pod/sfs-test01-1   0/1     Pending   0          16s   <none>           <none>       <none>           <none>

NAME                    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE     SELECTOR
service/kubernetes      ClusterIP   10.96.0.1    <none>        443/TCP   5h26m   <none>
service/sfs-service01   ClusterIP   None         <none>        80/TCP    5h15m   app.kubernetes.io/name=web-sfs01

NAME                          READY   AGE   CONTAINERS   IMAGES
statefulset.apps/sfs-test01   1/2     30m   nginx        nginx:latest
```

상태를 확인해보면 두 번째 파드인 sfs-test01-1가 생성되지 못하고 **Pending**상태에 머물러있다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl get all -o wide
NAME               READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
pod/sfs-test01-0   1/1     Running   0          30m   192.168.131.91   myserver02   <none>           <none>

# 문제 발생
pod/sfs-test01-1   0/1     Pending   0          16s   <none>           <none>       <none>           <none>
```

원인을 파악하기 위해 `PVC` 상태를 확인해보자.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl get pod,pv,pvc -o wide
NAME               READY   STATUS    RESTARTS   AGE     IP               NODE         NOMINATED NODE   READINESS GATES
pod/sfs-test01-0   1/1     Running   0          32m     192.168.131.91   myserver02   <none>           <none>
# 새롭게 생긴 파드의 상태가 Pending
pod/sfs-test01-1   0/1     Pending   0          2m13s   <none>           <none>       <none>           <none>

# PV 는 정상
NAME                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE   VOLUMEMODE
persistentvolume/pv-sfs01   100Mi      RWO            Retain           Bound    default/sfs-vol01-sfs-test01-0   pv-sfs-test01   <unset>                          37m   Filesystem

# PVC가 2개 존재하는데 sfs-vol01-sfs-test01-0 은 정상 동작
# sfs-vol01-sfs-test01-1은 Pending 상태임
NAME                                           STATUS    VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE     VOLUMEMODE
persistentvolumeclaim/sfs-vol01-sfs-test01-0   Bound     pv-sfs01   100Mi      RWO            pv-sfs-test01   <unset>                 32m     Filesystem
persistentvolumeclaim/sfs-vol01-sfs-test01-1   Pending                                        pv-sfs-test01   <unset>                 2m13s   Filesystem
```

Pending 상태였던 sfs-vol01-sfs-test01-1 PVC 에 대해 자세히 알아보자.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl describe pvc sfs-vol01-sfs-test01-1
Name:          sfs-vol01-sfs-test01-1
Namespace:     default
StorageClass:  pv-sfs-test01
Status:        Pending
Volume:
Labels:        app.kubernetes.io/name=web-sfs01
Annotations:   <none>
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:
Access Modes:
VolumeMode:    Filesystem
Used By:       sfs-test01-1
Events:
  Type     Reason              Age                  From                         Message
  ----     ------              ----                 ----                         -------
  Warning  ProvisioningFailed  3s (x20 over 4m37s)  persistentvolume-controller  storageclass.storage.k8s.io "pv-sfs-test01" not found
```

**왜 이런 일이 발생한 걸까?**  
- 스테이트풀셋은 두 번째 파드(...-1)을 위해 새로운 `PVC`(...-1)를 자동으로 생성했다.
- 이 새로운 `PVC`는 `storageClassName: pv-sfs-test01`을 가진 `PV`를 요청했다.
- 하지만 우리가 수동으로 만든 `PV`(pv-sfs01)은 이미 첫 번째 파드의 `PVC`에 바인딩(Bound)되어 사용 중이다.
- 남는 `PV`가 없으므로 두 번째 파드는 스토리지를 할당받지 못해 Pending 상태가 된다.

**해결책: 동적 프로비저닝(Dynamic Provisioning)**  
실제 운영 환경에서는 파드가 늘어날 때마다 관리자가 `PV`를 일일이 만들어줄 수 없다.  
따라서 `Rook` 이나 클라우드 제공업체(AWS EBS 등)의 스토리지 클래스를 사용하여, `PVC` 요청이 들어오면 **자동으로 `PV`를 생성하고 연결해주는 동적 프로비저닝**을 사용해야 한다.

---

이제 리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex12$ kubectl delete -f statefulset-vol03.yml
statefulset.apps "sfs-test01" deleted
assu@myserver01:~/work/ch09/ex12$ kubectl delete pv,pvc --all
persistentvolume "pv-sfs01" deleted
persistentvolumeclaim "sfs-vol01-sfs-test01-0" deleted
persistentvolumeclaim "sfs-vol01-sfs-test01-1" deleted
assu@myserver01:~/work/ch09/ex12$ kubectl delete -f statefulset-service.yml
service "sfs-service01" deleted

assu@myserver01:~/work/ch09/ex12$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   5h34m
```

---

# 정리하며..

- **스테이트풀셋의 독자성**
  - 디플로이먼트의 파드는 대체 가능하지만, 스테이트풀셋의 파드는 고유한 식별자를 가지기 때문에 파드가 재시작되어도 이름과 네트워크 ID가 유지된다.
- **헤드리스 서비스**
  - `ClusterIP: None`으로 설정된 서비스를 통해 로드밸런싱 없이 각 파드의 고유 IP 주소를 DNS로 직접 반환받아 통신한다.
- **순차적 관리**
  - 파드의 생성, 삭제, 스케일링이 순차적(0,1,2..)으로 이루어져 데이터의 정합성과 순서가 중요한 애플리케이션에 적합하다.
- **스토리지 관리**
  - `volumeClaimTemplates`를 사용하면 각 파드마다 전용 `PVC`를 자동으로 생성하여 고유한 데이터를 안전하게 저장할 수 있다.
  - 실무에서는 유연한 확장을 위해 동적 프로비저닝 환경 구성이 필수적이다.

데이터베이스나 분산 시스템을 쿠버네티스 위에 구축할 때 스테이트풀셋은 선택이 아닌 필수이다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)