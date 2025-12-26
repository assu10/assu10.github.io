---
layout: post
title:  "Kubernetes - 스토리지 볼륨(emptyDir, hostPath, PV)"
date: 2025-12-20 10:00:00
categories: dev
tags: devops kubernetes k8s container-storage volume emptydir hostpath persistent-volume pv pvc nfs stateful-application infrastructure
---

컨테이너는 기본적으로 'Stateless(상태가 없는)' 특성을 지향하며, 변경 가능한 파일 시스템 레이어를 가지고 있지만 이는 컨테이너가 삭제되는 순간 함께 소멸한다.  
도커를 다뤄본 사람이라면 이러한 문제를 해결하기 위해 [**도커 볼륨(Docker Volume)**](https://assu10.github.io/dev/2025/11/16/docker-basics-and-commands-guide-2/#2-%EB%8F%84%EC%BB%A4-%EC%8A%A4%ED%86%A0%EB%A6%AC%EC%A7%80)을 
마운트하여 컨테이너 라이프사이클과 데이터를 분리했던 경험이 있을 것이다.

쿠버네티스 환경에서도 이 원칙은 동일하게 적용된다.  
파드 내의 컨테이너가 오류로 인해 재시작되거나, 파드 자체가 삭제될 때 내부 데이터가 유실되는 것을 막기 위해 **스토리지 볼륨(Storage Volume)**이라는 개념을 사용한다.

하지만 쿠버네티스의 볼륨은 도커의 볼륨보다 훨씬 더 다양한 기능을 제공한다.  
단순히 디스크를 보존하는 것을 넘어, 파드 내 컨테이너 간의 데이터 공유나 클러스터 외부 스토리지와의 연동 등 복잡한 요구사항을 처리할 수 있다.

이 포스트에서는 쿠버네티스 볼륨의 가장 기본이 되는 볼륨 타입인 `emptyDir`, `hostPath` 그리고 영구 스토리지를 위한 `PV(PersistentVolume)`에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 스토리지 볼륨(Storage Volume) 개념](#1-스토리지-볼륨storage-volume-개념)
* [2. `emptyDir`](#2-emptydir)
  * [2.1. `emptyDir` 생명주기 확인](#21-emptydir-생명주기-확인)
* [3. `hostPath`](#3-hostpath)
  * [3.1. 노드 간 데이터 공유 확인](#31-노드-간-데이터-공유-확인)
* [4. `PV`(PersistentVolume)](#4-pvpersistentvolume)
  * [4.1. NFS 서버 구축](#41-nfs-서버-구축)
  * [4.2. `PV` 및 `PVC` 생성](#42-pv-및-pvc-생성)
  * [4.3. 파드에서 `PVC` 사용](#43-파드에서-pvc-사용)
  * [4.4. 데이터 영속성 검증](#44-데이터-영속성-검증)
  * [4.5. 리소스 삭제 및 데이터 보존 확인](#45-리소스-삭제-및-데이터-보존-확인)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Ubuntu 24.04.2 LTS
- Mac Apple M3 Max
- Memory 48 GB

---

# 1. 스토리지 볼륨(Storage Volume) 개념

쿠버네티스를 사용할 때 헷갈리는 부분 중 하나는 **데이터의 수명**이다.  
도커와 마찬가지로 쿠버네티스 컨테이너 내부의 파일 시스템은 기본적으로 **일시적(Ephemeral)**이다.

즉, 컨테이너가 정상적으로 실행되다가 오류로 인해 셧다운 되고, 쿠버네티스 컨트롤러에 의해 재시작되면 기존 컨테이너 내부에 저장해 뒀던 로그나 데이터 파일이 모두 
사라진 상태의 컨테이너가 새롭게 뜬다.

이러한 데이터 유실 문제를 해결하기 위해 쿠버네티스는 **스토리지 볼륨**이라는 추상화된 개념을 제공한다.  
파드가 실행되는 동안 데이터를 보존하거나, 파드가 재시작되더라도 데이터를 유지할 수 있게 하는 것이다.

쿠버네티스의 볼륨은 저장 위치와 생명 주기에 따라 크게 세 가지 유형으로 나눌 수 있다.

|       볼륨 유형       | 설명                      | 데이터 보존 범위                     |
|:-----------------:|:------------------------|:------------------------------|
|    `emptyDir`     | 파드 내부에서 임시적으로 사용하는 볼륨   | 파드 생명주기와 동일(파드 삭제 시 삭제됨)      |
|    `hostPath`     | 노드의 파일 시스템을 사용하는 볼륨     | 노드 생명주기와 동일(파드는 삭제되어도 데이터 유지) |
| `PersistentVolume` | 클러스터 외부의 전문 스토리지 시스템 사용 | 영구적(클러스터나 노드가 바뀌어도 유지)        |

![스토리지 볼륨](/assets/img/dev/2025/1220/storage.png)

---

# 2. `emptyDir`

`emptyDir`은 이름 그대로 **비어 있는 디렉터리**로 시작하는 가장 기본적인 볼륨 타입이다.

![emptyDir](/assets/img/dev/2025/1220/emptydir.png)

- **생명주기**
  - 파드가 노드에 할당될 때 생성되며, **파드가 실행되는 동안에만 존재**한다. 파드가 삭제되면 `emptyDir` 내부의 데이터도 영구적으로 삭제된다.
- **데이터 공유**
  - 하나의 파드 내에 여러 개의 컨테이너가 있을 경우(예: [사이드카 패턴(Sidecar Pattern)](https://assu10.github.io/dev/2025/12/20/sidecar-pattern/)), 이 컨테이너들은 `emptyDir` 볼륨을 공유하여 동일한 파일을 읽고 쓸 수 있다.
  - 다른 파드에서는 접근이 불가하다.
- **활용 사례**
  - 디스크 기반의 병합 정렬(Merge sort)과 같은 임시 대용량 연산
  - 크래시 복구 등을 위한 체크포인트 임시 저장
  - 웹 서버 컨테이너가 서빙할 데이터를 콘텐츠 매니저 컨테이너가 갱신하는 경우

---

## 2.1. `emptyDir` 생명주기 확인

`emptyDir`을 사용하여 파드가 재시작되었을 때와 파드가 삭제되었을 때 데이터가 어떻게 되는지 직접 확인해보자.

먼저 디렉터리를 생성한다.



```shell
➜  ~ ssh -p 2201 assu@127.0.0.1

assu@myserver01:~/work/ch09$ pwd
/home/assu/work/ch09
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08

assu@myserver01:~/work/ch09$ mkdir ex09
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08  ex09

assu@myserver01:~/work/ch09$ cd ex09
```

---

**파드 정의(YAML)**

nginx 컨테이너를 하나 띄우고, /mount01 경로에 `emptyDir` 볼륨을 마운트하는 설정이다.

```shell
assu@myserver01:~/work/ch09/ex09$ vim volume-test01.yml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-volume-01             # 파드명
spec:                               # 파드의 내부 상태 정의, 파드 내부에는 컨테이너와 볼륨 생성
  containers:
    - name: nginx-test01
      image: nginx:latest
      volumeMounts:                 # 컨테이너가 사용할 볼륨 마운트
        - name: empty-test01        # 컨테이너가 사용할 볼륨 이름(하단 volumes에 정의된 이름과 일치해야 함)
          mountPath: /mount01       # 컨테이너 내부의 마운트 경로
  volumes:                          # 파드 내부에 생성할 볼륨 생성
    - name: empty-test01            # 볼륨 식별자
      emptyDir: {}                  # 볼륨 타입 설정, {}는 기본 옵션 사용 (메모리가 아닌 디스크 사용)
```

---

**파드 생성 및 데이터 쓰기**

파드를 생성하고 정상적으로 실행 중인지 확인한다.

```shell
assu@myserver01:~/work/ch09/ex09$ kubectl apply -f volume-test01.yml
pod/nginx-volume-01 created

assu@myserver01:~/work/ch09/ex09$ kubectl get all
NAME                  READY   STATUS    RESTARTS   AGE
pod/nginx-volume-01   1/1     Running   0          4m17s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   8d
```

이제 파드 내부로 진입하여 마운트 된 경로에 파일을 하나 생성해본다.

```shell
# 파드 내부 쉘 접속
assu@myserver01:~/work/ch09/ex09$ kubectl exec -it nginx-volume-01 -- /bin/bash

# 마운트 경로로 이동하여 파일 생성
root@nginx-volume-01:/# ls
bin   dev		   docker-entrypoint.sh  home  media  mount01  proc  run   srv	tmp  var
boot  docker-entrypoint.d  etc			 lib   mnt    opt      root  sbin  sys	usr

root@nginx-volume-01:/# cd mount01
root@nginx-volume-01:/mount01# ls
root@nginx-volume-01:/mount01# echo "test" > ./test.txt

# 파일 확인
root@nginx-volume-01:/mount01# ls
test.txt

root@nginx-volume-01:/mount01# cat test.txt
test

root@nginx-volume-01:/mount01# exit
exit
```

![yml 파일 비교](/assets/img/dev/2025/1220/yml.png)

---

**파드 삭제 후 재생성(데이터 유실 확인)**

이제 핵심 테스트이다. 파드를 삭제했다가 재생성했을 때 위에서 만든 test.txt 파일이 삭제되었는지 확인해보자.

```shell
# 기존 파드 삭제(파드가 삭제되면 emptyDir도 삭제됨)
assu@myserver01:~/work/ch09/ex09$ kubectl delete -f volume-test01.yml
pod "nginx-volume-01" deleted

assu@myserver01:~/work/ch09/ex09$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   8d

# 동일한 설정으로 파드 재생성
assu@myserver01:~/work/ch09/ex09$ kubectl apply -f volume-test01.yml
pod/nginx-volume-01 created
assu@myserver01:~/work/ch09/ex09$ kubectl get all
NAME                  READY   STATUS    RESTARTS   AGE
pod/nginx-volume-01   1/1     Running   0          4s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   8d

# 파드 내부 확인
assu@myserver01:~/work/ch09/ex09$ kubectl exec -it nginx-volume-01 -- /bin/bash
root@nginx-volume-01:/# ls
bin   dev		   docker-entrypoint.sh  home  media  mount01  proc  run   srv	tmp  var
boot  docker-entrypoint.d  etc			 lib   mnt    opt      root  sbin  sys	usr

root@nginx-volume-01:/# cd mount01

# 생성했던 test.txt 파일이 존재하지 않음을 확인
root@nginx-volume-01:/mount01# ls
root@nginx-volume-01:/mount01# exit
exit
```

test.txt 파일이 보이지 않는다.  
이를 통해 **`emptyDir`은 파드의 생명 주기와 동일하며, 파드가 삭제되면 데이터도 초기화된다**는 것을 확인할 수 있다.

리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex09$ kubectl delete -f volume-test01.yml
pod "nginx-volume-01" deleted

assu@myserver01:~/work/ch09/ex09$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   8d
```

---

# 3. `hostPath`

> 쿠버네티스 공식 문서에는 **보안상의 이유로 `hostPath` 사용을 최대한 지양할 것을 권고**한다.
> 
> `hostPath` 볼륨에는 많은 보안 위험이 있으며, 가능하면 `hostPath`를 사용하지 않는 것이 좋다.  
> `hostPath` 볼륨을 사용해야 하는 경우, 필요한 파일 또는 디렉터리로만 범위를 지정하고 ReadOnly로 마운트해야 한다.  
> AdmissionPolicy를 사용하여 특정 디렉터리로의 `hostPath` 액세스를 제한하는 경우,  
> readOnly 마운트를 사용하는 정책이 유효하려면 volumeMounts 가 반드시 지정되어야 한다.
> 
> 참고 링크: [https://kubernetes.io/ko/docs/concepts/storage/volumes/#hostPath](https://kubernetes.io/ko/docs/concepts/storage/volumes/#hostpath)

`emptyDir`이 파드의 생명주기에 묶여 있는 임시 저장소라면, **`hostPath`**는 파드가 실행 중인 **호스트 노드의 실제 파일 시스템**을 파드에 마운트하여 사용하는 방식이다.

![hostPath](/assets/img/dev/2025/1220/hostpath.png)

이 방식은 도커의 [`bind mount`](https://assu10.github.io/dev/2025/11/16/docker-basics-and-commands-guide-2/#24-bind-mount-%ED%98%B8%EC%8A%A4%ED%8A%B8-%EA%B2%BD%EB%A1%9C-%EC%A7%81%EC%A0%91-%EA%B3%B5%EC%9C%A0)와 유사한 개념으로, 
파드가 삭제되어도 노드의 디스크에 파일이 남아있기 때문에 데이터가 유지된다는 장점이 있다.  
하지만 치명적인 단점과 보안 이슈가 존재하여 사용 시 각별한 주의가 필요하다.

<**`hostPath`의 특징과 한계**>  
- **노드 종속성**
  - 데이터가 특정 노드의 디스크에 저장되므로, 파드가 다른 노드로 스케줄링되면 기존 데이터에 접근할 수 없다.
- **활용 사례**
  - 주로 시스템 모니터링 에이전트나 로그 수집기처럼 노드의 정보(예: /var/log, /proc)를 읽어야 하는 시스템 데몬 파드에서 제한적으로 사용된다.

---

## 3.1. 노드 간 데이터 공유 확인

여기서는 3개의 노드(myserver01, 02, 03) 환경에서 `hostPath`가 어떻게 동작하는지 확인해본다.

---

**클러스터 노드 확인 및 특정 노드에 디렉터리 생성** 

쿠버네티스 클러스터 노드 이름을 확인해보자.

```shell
➜  ~ ssh -p 2201 assu@127.0.0.1

assu@myserver01:~$ kubectl get nodes --show-labels
NAME         STATUS   ROLES           AGE   VERSION    LABELS
myserver01   Ready    control-plane   10d   v1.29.15   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm64,kubernetes.io/hostname=myserver01,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=
myserver02   Ready    <none>          10d   v1.29.15   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm64,kubernetes.io/hostname=myserver02,kubernetes.io/os=linux
myserver03   Ready    <none>          10d   v1.29.15   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm64,kubernetes.io/hostname=myserver03,kubernetes.io/os=linux
```

위 결과의 `kubernetes.io/hostname=myserver01` 에서 각각 노드 이름이 myserver01, myserver02, myserver03 인 것을 확인할 수 있다.

그럼 이제 데이터의 영속성을 확인하기 위해 myserver03 노드에 직접 접속하여 데이터를 저장할 폴더를 미리 생성한다.

```shell
~ ssh -p 2203 assu@127.0.0.1

assu@myserver03:~$ ls
work

assu@myserver03:~$ cd work
assu@myserver03:~/work$ ls
ch04  ch05  ch06

assu@myserver03:~/work$ mkdir volhost01
assu@myserver03:~/work$ ls
ch04  ch05  ch06  volhost01

# hostPath 볼륨을 생성할 volhost01 디렉터리 생성
assu@myserver03:~/work$ cd volhost01/
assu@myserver03:~/work/volhost01$ pwd
/home/assu/work/volhost01

assu@myserver03:~/work/volhost01$ exit
logout
Connection to 127.0.0.1 closed.
```

---

**파드 생성(myserver03 지정)**

이제 마스터 노드(myserver01)로 돌아와서 파드를 생성한다.  
이 때 `hostPath`의 테스트를 위해 파드가 반드시 데이터를 생성해 둔 myserver03에 뜨도록 `nodeSelector`를 설정한다.

```shell
assu@myserver01:~$ ls
custom-resources.yaml  work

assu@myserver01:~$ cd work/ch09
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08  ex09

assu@myserver01:~/work/ch09$ mkdir ex10
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08  ex09  ex10

assu@myserver01:~/work/ch09$ cd ex10
```

```shell
assu@myserver01:~/work/ch09/ex10$ vim volume-test02.yml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-volume-02
spec:    # 파드 내부 상태 정의, 파드 내부에는 컨테이너와 볼륨 생성
  nodeSelector:   # 파드가 실행될 노드 정의
    kubernetes.io/hostname: myserver03    # 파드를 강제로 myserver03에 배포
  containers:   # 컨테이너 생성
    - name: nginx-test01
      image: nginx:latest
      volumeMounts:   # 컨테이너가 사용할 볼륨 마운트
        - name: hostpath-test01   # 컨테이너가 사용할 볼륨 이름 정의
          mountPath: /mount01   # 볼륨을 마운트할 경로 작성
  volumes:    # 파드 내부에 생성할 볼륨 정의
    - name: hostpath-test01 
      hostPath:   # 볼륨 타입 정의
        path: /home/assu/work/volhost01   # 호스트(myserver03)의 실제 경로
        type: DirectoryOrCreate   # 경로가 없으면 생성 (권한 주의)
```

파드를 실행하고 상태를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex10$ kubectl apply -f volume-test02.yml
pod/nginx-volume-02 created

assu@myserver01:~/work/ch09/ex10$ kubectl get all
NAME                  READY   STATUS    RESTARTS   AGE
pod/nginx-volume-02   1/1     Running   0          6m49s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10d
```

> 만일 파드가 READY 상태로 변경되지 않거나 CNI 관련 에러가 발생한다면 [TroubleShooting - plugin type=calico failed (add): error getting ClusterInformation: connection is unauthorized: Unauthorized
2025-12-20 in DEV on Trouble Shooting](https://assu10.github.io/dev/2025/12/20/trouble-shooting/) 를 참고하세요.

---

**데이터 영속성 확인**

파드 내부에 접속하여 파일을 생성한다.

```shell
assu@myserver01:~/work/ch09/ex10$ kubectl exec -it nginx-volume-02 -- /bin/bash

root@nginx-volume-02:/# ls
bin   dev		   docker-entrypoint.sh  home  media  mount01  proc  run   srv	tmp  var
boot  docker-entrypoint.d  etc			 lib   mnt    opt      root  sbin  sys	usr

# 볼륨이 마운트되는 디렉터리로 이동
root@nginx-volume-02:/# cd mount01
root@nginx-volume-02:/mount01# ls

# 볼륨을 통해 저장할 파일 생성
root@nginx-volume-02:/mount01# echo "hello world" > ./test01.txt
root@nginx-volume-02:/mount01# ls
test01.txt

root@nginx-volume-02:/mount01# exit
exit
```

이제 파드를 **삭제하고 재생성**해본다.  
`emptyDir`과 달리 데이터가 남아있어야 한다.

```shell
# 기존 파드 삭제
assu@myserver01:~/work/ch09/ex10$ kubectl delete -f volume-test02.yml
pod "nginx-volume-02" deleted
assu@myserver01:~/work/ch09/ex10$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10d

# 파드 재생성
assu@myserver01:~/work/ch09/ex10$ kubectl apply -f volume-test02.yml
pod/nginx-volume-02 created
assu@myserver01:~/work/ch09/ex10$ kubectl get all
NAME                  READY   STATUS    RESTARTS   AGE
pod/nginx-volume-02   1/1     Running   0          4s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10d

assu@myserver01:~/work/ch09/ex10$ kubectl get all -o wide
NAME                  READY   STATUS    RESTARTS   AGE     IP                NODE         NOMINATED NODE   READINESS GATES
pod/nginx-volume-02   1/1     Running   0          3m19s   192.168.149.208   myserver03   <none>           <none>

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10d   <none>

# 재생성된 파드에서 파일 확인
assu@myserver01:~$ kubectl exec -it nginx-volume-02 -- cat /mount01/test01.txt
hello world
```

파드가 재시작되어도 myserver03 노드의 디스크에 파일이 저장되어 있으므로 데이터가 유지된다.

---

**`hostPath`의 한계 확인(다른 노드에 배포 시)**

그렇다면 myserver02 노드에 배포된 파드는 이 데이터를 볼 수 있을까?

```shell
~ ssh -p 2202 assu@127.0.0.1
```

```shell
assu@myserver02:~$ vim volume-test03.yml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-volume-03
spec:
  nodeSelector:
    kubernetes.io/hostname: myserver02  # 이번엔 myserver02에 배포
  containers:
    - name: nginx-test01
      image: nginx:latest
      volumeMounts:
        - name: hostpath-test01
          mountPath: /mount01
  volumes: 
    - name: hostpath-test01 
      hostPath:
        path: /home/assu/work/volhost01
        type: DirectoryOrCreate
```

```shell
assu@myserver02:~$ kubectl apply -f volume-test03.yml
pod/nginx-volume-03 created

# myserver02 노드에 nginx-volume-03 파드가 추가됨
assu@myserver02:~$ kubectl get all -o wide
NAME                  READY   STATUS    RESTARTS   AGE     IP                NODE         NOMINATED NODE   READINESS GATES
pod/nginx-volume-02   1/1     Running   0          5m58s   192.168.149.208   myserver03   <none>           <none>
pod/nginx-volume-03   1/1     Running   0          4s      192.168.131.81    myserver02   <none>           <none>

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10d   <none>
```

```shell
assu@myserver02:~$ kubectl exec -it nginx-volume-03 -- /bin/bash
root@nginx-volume-03:/# ls
bin   dev		   docker-entrypoint.sh  home  media  mount01  proc  run   srv	tmp  var
boot  docker-entrypoint.d  etc			 lib   mnt    opt      root  sbin  sys	usr

# test01.txt 파일이 존재하지 않음
root@nginx-volume-03:/# cd mount01
root@nginx-volume-03:/mount01# ls
```

myserver02 노드에는 해당 파일이 없다.  
즉, **`hostPath`는 파드가 실행되는 노드에 종속되므로, 멀티 노드 환경에서의 범용적인 스토리지 솔루션으로는 적합하지 않다.**

이제 리소스를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex10$ kubectl delete -f volume-test02.yml
pod "nginx-volume-02" deleted

assu@myserver02:~$ kubectl delete -f volume-test03.yml
pod "nginx-volume-03" deleted

assu@myserver01:~/work/ch09/ex10$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   11d
```

---

# 4. `PV`(PersistentVolume)

위에서 살펴본 `hostPath`는 데이터가 노드에 종속된다는 치명적인 단점이 있었다.  
엔터프라이즈 환경에서는 파드가 어느 노드에 뜨더라도 동일한 데이터에 접근할 수 있어야 하며, 파드나 노드가 죽더라도 데이터는 안전하게 별도의 저장소에 보관되어야 한다.

이를 위해 쿠버네티스는 `PV`(PersistentVolume)와 `PVC`(PersistentVolumeClaim) 라는 개념을 도입하였다.

![PV](/assets/img/dev/2025/1220/pv.png)

- `PV`
  - 관리자가 프로비저닝할 실제 스토리지 리소스
  - 예: NFS, AWS EBS, GCE PersistentDisk 등
- `PVC`
  - 사용자가 스토리지를 사용하기 위해 요청하는 명세서

**핵심은 분리(Decoupling)**이다.  
개발자는 구체적인 스토리지 내부 구현(NFS인지, 클라우드 스토리지인지)을 알 필요 없이, 필요한 용량과 접근 모드가 적힌 **PVC**만 생성하면 된다.  
그러면 쿠버네티스가 조건에 맞는 **PV**를 찾아 자동으로 연결해준다.

여기서는 NFS(Network File System)을 이용하여 외부 스토리지를 구성하고, 이를 PV로 연결하여 데이터 영속성을 확인해본다.

---

## 4.1. NFS 서버 구축

먼저 쿠버네티스 클러스터 외부의 스토리지 역할을 할 NFS 서버를 myserver03 노드에 구축한다. 실제 운영 환경에서는 별도의 스토리지 서버를 사용한다.

**필수 패키지 설치**

NFS 통신을 위해 모든 노드(클라이언트)에는 `nfs-common`을, 서버(myserver03)에는 `nfs-kernel-server`를 설치한다.

```shell
$ ssh -p 2201 assu@127.0.0.1
assu@myserver01:~$ sudo apt install nfs-common

assu@myserver01:~$ ssh myserver02
assu@myserver02:~$ sudo apt install nfs-common

assu@myserver02:~$ ssh myserver03
assu@myserver03:~$ sudo apt install nfs-common
assu@myserver03:~$ sudo apt install nfs-kernel-server
```

```shell
assu@myserver03:~$ systemctl status nfs-server.service
● nfs-server.service - NFS server and services
     Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; preset: enabled)
     Active: active (exited) since Thu 2025-12-25 04:29:17 UTC; 46s ago
   Main PID: 228689 (code=exited, status=0/SUCCESS)
        CPU: 8ms

Dec 25 04:29:17 myserver03 systemd[1]: Starting nfs-server.service - NFS server and services...
Dec 25 04:29:17 myserver03 exportfs[228688]: exportfs: can't open /etc/exports for reading
Dec 25 04:29:17 myserver03 systemd[1]: Finished nfs-server.service - NFS server and services.
```

---

**공유 디렉터리 생성 및 설정**

myserver03에서 데이터를 저장할 실제 디렉터리(`PV`)를 만들고, 권한을 설정한다.

```shell
# 루트 권한 획득
assu@myserver03:~$ sudo -i

root@myserver03:~# cd /tmp
root@myserver03:/tmp# ls
snap-private-tmp
systemd-private-f315992405a246bca2c4317c045351c1-fwupd.service-su3wED
systemd-private-f315992405a246bca2c4317c045351c1-ModemManager.service-aI4KYx
systemd-private-f315992405a246bca2c4317c045351c1-polkit.service-qobsnC
systemd-private-f315992405a246bca2c4317c045351c1-systemd-logind.service-qoCRgT
systemd-private-f315992405a246bca2c4317c045351c1-systemd-resolved.service-OxMJXc
systemd-private-f315992405a246bca2c4317c045351c1-systemd-timesyncd.service-7ANjuO

# PV용 디렉터리로 k8s-pv 디렉터리 생성
root@myserver03:/tmp# mkdir k8s-pv
root@myserver03:/tmp# ls
k8s-pv
snap-private-tmp
systemd-private-f315992405a246bca2c4317c045351c1-fwupd.service-su3wED
systemd-private-f315992405a246bca2c4317c045351c1-ModemManager.service-aI4KYx
systemd-private-f315992405a246bca2c4317c045351c1-polkit.service-qobsnC
systemd-private-f315992405a246bca2c4317c045351c1-systemd-logind.service-qoCRgT
systemd-private-f315992405a246bca2c4317c045351c1-systemd-resolved.service-OxMJXc
systemd-private-f315992405a246bca2c4317c045351c1-systemd-timesyncd.service-7ANjuO
```

이제 /etc/exports 파일을 수정하여 공유 정책을 설정한다.  
여기서는 myserver02(10.0.2.5)가 접근할 수 있도록 설정한다.  
설정은 `[공유할 디렉터리][접속을 허용할 IP(옵션)]` 형태로 작성한다.

```shell
root@myserver03:/tmp# sudo vim /etc/exports

...

# 파일 끝에 추가
/tmp/k8s-pv 10.0.2.5(rw,no_root_squash)
```

- `rw`
  - 읽기 및 쓰기 권한 부여
- `no_root_squash`
  - 클라이언트의 root 권한을 서버에서도 root로 인정(이 옵션이 없으면 권한 문제로 파일 쓰기가 실패할 수 있음)

---

**서비스 재시작**

설정을 적용하기 위해 NFS 서비스를 재시작한다.

```shell
assu@myserver03:~$ sudo systemctl restart nfs-server
assu@myserver03:~$ systemctl status nfs-server.service
● nfs-server.service - NFS server and services
     Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; preset: enabled)
     Active: active (exited) since Thu 2025-12-25 04:36:47 UTC; 10s ago
...
```

---

## 4.2. `PV` 및 `PVC` 생성

이제 인프라 준비가 끝났으니 쿠버네티스 리소스를 생성한다.

**`PV`(PersistentVolume) 정의**

```shell
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08  ex09  ex10

assu@myserver01:~/work/ch09$ mkdir ex11
assu@myserver01:~/work/ch09$ ls
ex01  ex02  ex03  ex04  ex05  ex06  ex07  ex08  ex09  ex10  ex11
assu@myserver01:~/work/ch09$ cd ex11
```

관리자 입장에서 '100MB 용량의 NFS 스토리지'를 정의한다.

```shell
assu@myserver01:~/work/ch09/ex11$ vim volume-test-04-1-pv.yml
```

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-01
spec:
  accessModes:
    - ReadWriteOnce   # 하나의 노드에서만 R/W 가능
  capacity:
    storage: 100Mi    # 용량 100MB
  persistentVolumeReclaimPolicy: Retain # 중요: 반환 정책
  storageClassName: pv-test-01  # PVC와 연결을 위한 식별자, 여기서 설정하는 storageClassName은 이후 작성할 PVC와의 연결점이 됨
  nfs:
    server: 10.0.2.6  # NFS 서버(myserver03) IP
    path: /tmp/k8s-pv   # NFS 서버 내부에서 PV로 사용할 경로
```

**`persistentVolumeReclaimPolicy`(반환 정책)**  
`PVC`가 삭제되었을 때 `PV`의 데이터를 어떻게 처리할 지 결정한다.  
- `Retain`: `PVC`가 삭제되어도 `PV` 내부의 데이터는 그대로 유지
- `Delete`: `PVC`가 삭제될 때 `PV` 역시 삭제하고 연계되어 있는 외부 스토리지 데이터도 삭제(AWS EBS 등에서 주로 사용)
- `Recycle`(Deprecated): `rm -rf` 명령으로 데이터를 지우고 `PV`를 재사용 가능하게 만듦

---

**`PVC`(PersistentVolumeClaim) 정의**

사용자 입장에서 '30MB 정도의 스토리지가 필요해'라고 요청한다.

```shell
assu@myserver01:~/work/ch09/ex11$ vim volume-test-04-2-pvc.yml
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-01  # 실행할 PVC 이름
spec: # PVC 내부 상태 정의
  accessModes:
    - ReadWriteOnce
  resources:  # 사용할 자원 설정
    requests: # PV에게 보낼 요청사항 작성
      storage: 30Mi # 최소 30MB 요청
  storageClassName: pv-test-01  # PV의 storageClassName과 일치해야 바인딩 됨
```

---

**생성 및 바인딩 확인**

PV와 PVC를 순서대로 생성하고 상태 변화를 관찰한다.

`PV`를 생성한다.
```shell
assu@myserver01:~/work/ch09/ex11$ kubectl apply -f volume-test-04-1-pv.yml
persistentvolume/pv-01 created

assu@myserver01:~/work/ch09/ex11$ kubectl get pv
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-01   100Mi      RWO            Retain           Available           pv-test-01     <unset>                          19s
```

`PV`의 STATUS가 Available 인 것을 확인할 수 있다. 이후 `PVC`를 생성하면 변경된다.

```shell
assu@myserver01:~/work/ch09/ex11$ kubectl apply -f volume-test-04-2-pvc.yml
persistentvolumeclaim/pvc-01 created

assu@myserver01:~/work/ch09/ex11$ kubectl get pvc
NAME     STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-01   Bound    pv-01    100Mi      RWO            pv-test-01     <unset>                 11s

assu@myserver01:~/work/ch09/ex11$ kubectl get pv
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM            STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-01   100Mi      RWO            Retain           Bound    default/pvc-01   pv-test-01     <unset>                          79s
```

`PV`의 STATUS 가 **Available** 에서 **Bound** 로 변경되었다면 `PV`와 `PVC`가 정상적으로 연결된 것이다.

---

## 4.3. 파드에서 `PVC` 사용

이제 파드를 생성하여 `PVC`를 마운트한다.  
파드는 `PV`를 직접 지정하는 것이 아니라 `PVC`의 이름을 참조한다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-volume-04
spec:
  nodeSelector:
    kubernetes.io/hostname: myserver02  # myserver02에 배포
  containers:
    - name: nginx-test01
      image: nginx:latest
      volumeMounts:
        - name: nfs-pv-01 # 컨테이너가 사용하게 될 볼륨 이름, 이후 생성할 볼륨 이름과 일치해야 함
          mountPath: /mount01   # 볼륨을 마운트할 경로
  volumes:  # 파드 내부에 생성할 볼륨
    - name: nfs-pv-01
      persistentVolumeClaim:
        claimName: pvc-01   # 위에서 생성한 PVC 이름 참조
```

![pod, pvc, pv 관계](/assets/img/dev/2025/1220/yml2.png)

파드가 정상적으로 실행되었는지 확인한다.

```shell
assu@myserver01:~/work/ch09/ex11$ kubectl apply -f volume-test-04-3-pod.yml
pod/nginx-volume-04 created

assu@myserver01:~/work/ch09/ex11$ kubectl get pod -o wide
NAME              READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
nginx-volume-04   1/1     Running   0          8s    192.168.131.82   myserver02   <none>           <none>
```

---

## 4.4. 데이터 영속성 검증

이제 **파드(myserver02) → PV/PVC → NFS서버(myserver03)** 으로 이어지는 연결을 통해 데이터가 실제로 유지되는지 확인해보자.

- **파드에서 파일 생성**: myserver02에 있는 파드 내부로 들어가 파일 생성
- **NFS 서버에서 확인**: myserver03의 실제 디렉터리에 파일이 생성되었는지 확인

파드 내부에서 파일 생성
```shell
assu@myserver01:~/work/ch09/ex11$ kubectl exec -it nginx-volume-04 -- /bin/bash

root@nginx-volume-04:/# ls
bin   dev		   docker-entrypoint.sh  home  media  mount01  proc  run   srv	tmp  var
boot  docker-entrypoint.d  etc			 lib   mnt    opt      root  sbin  sys	usr

root@nginx-volume-04:/# cd mount01
root@nginx-volume-04:/mount01# ls

root@nginx-volume-04:/mount01# echo "hello world!" > ./nfs_test.txt
root@nginx-volume-04:/mount01# ls
nfs_test.txt

root@nginx-volume-04:/mount01# exit
exit
assu@myserver01:~/work/ch09/ex11$
```

NFS 서버에서 확인
```shell
assu@myserver01:~/work/ch09/ex11$ ssh myserver03

assu@myserver03:~$ cd /tmp/k8s-pv
assu@myserver03:/tmp/k8s-pv$ ls
nfs_test.txt

assu@myserver03:/tmp/k8s-pv$ cat nfs_test.txt
hello world!

assu@myserver03:/tmp/k8s-pv$ exit
logout
Connection to myserver03 closed.
```

파드는 자신이 어느 서버에 있는지, 실제 스토리지가 어디인지 모르지만 `PVC`를 통해 안전하게 데이터를 외부 서버에 저장하였다.

![전체 흐름](/assets/img/dev/2025/1220/pv_all.png)

---

## 4.5. 리소스 삭제 및 데이터 보존 확인

마지막으로 쿠버네티스 리소스(파드, `PV`, `PVC`)를 모두 삭제했을 때 데이터가 어떻게 되는지 확인해보자.  
우리는 `PV` 정책을 `Retain` 으로 설정했었다.

리소스 삭제
```shell
assu@myserver01:~/work/ch09/ex11$ kubectl delete -f volume-test-04-1-pv.yml
persistentvolume "pv-01" deleted
assu@myserver01:~/work/ch09/ex11$ kubectl delete -f volume-test-04-3-pod.yml
pod "nginx-volume-04" deleted
assu@myserver01:~/work/ch09/ex11$ kubectl delete -f volume-test-04-2-pvc.yml
persistentvolumeclaim "pvc-01" deleted

assu@myserver01:~/work/ch09/ex11$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   11d
```


NFS 서버 데이터 확인
```shell
assu@myserver01:~/work/ch09/ex11$ ssh myserver03
assu@myserver03:~$ cd /tmp/k8s-pv
assu@myserver03:/tmp/k8s-pv$ ls
nfs_test.txt

assu@myserver03:/tmp/k8s-pv$ exit
logout
Connection to myserver03 closed.
```

모든 쿠버네티스 오브젝트가 사라졌음에도 불구하고, NFS 서버의 /tmp/k8s-pv 디렉터리에는 파일이 안전하게 남아있다.  
이것이 바로 상태를 저장하는 **Stateful** 애플리케이션을 위한 핵심이다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)