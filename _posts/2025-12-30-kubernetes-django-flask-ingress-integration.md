---
layout: post
title:  "Kubernetes - 쿠버네티스로 웹 서비스 배포(3): 인그레스를 활용한 Flask & Django 동시 배포"
date: 2025-12-30 10:00:00
categories: dev
tags: devops kubernetes k8s ingress django flask nginx microservices path-based-routing fanout load-balancing service-discovery url-rewriting
---

[Kubernetes - 쿠버네티스로 웹 서비스 배포(1): 인그레스를 활용한 Django & Nginx 배포](https://assu10.github.io/dev/2025/12/28/kubernetes-django-nginx-ingress-practice/)와 
[Kubernetes - 쿠버네티스로 웹 서비스 배포(2): 인그레스를 활용한 Flask & Nginx 배포](https://assu10.github.io/dev/2025/12/29/kubernetes-flask-nginx-ingress-practice/) 
를 통해 각 애플리케이션을 쿠버네티스 클러스터 위에서 인그레스를 통해 외부로 노출하는 과정에 대해 알아보았다.

이번 포스트에서는 쿠버네티스 인그레스의 가장 강력한 기능 중 하나인 **단일 진입점을 통한 다중 서비스 라우팅(Path-based Routing)**을 구현해본다.  
(두 개의 개별 서비스를 하나의 인그레스 리소스를 통해 통합 관리하고 라우팅하는 [Fan-out](https://assu10.github.io/dev/2025/05/27/fanout/) 패턴)
즉, 하나의 도메인(IP)에서 경로(path)에 따라 Django 서비스와 Flask 서비스로 분기 처리하는 아키텍처를 구성한다.  
이는 MSA에서 매우 흔하게 사용되는 패턴이다.

---

**목차**

<!-- TOC -->
* [1. 인그레스 팬아웃(Fan-out)이란?](#1-인그레스-팬아웃fan-out이란)
* [2. 인그레스 파일 생성](#2-인그레스-파일-생성)
* [3. 배포 및 검증](#3-배포-및-검증)
* [4. 전체 아키텍처 및 리소스 정리](#4-전체-아키텍처-및-리소스-정리)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Guest OS: Ubuntu 24.04.2 LTS
- Host OS: Mac Apple M3 Max
- Memory: 48 GB

---

# 1. 인그레스 팬아웃(Fan-out)이란?

쿠버네티스 인그레스의 가장 강력한 기능 중 하나는 단일 IP 주소와 포트를 통해 여러 서비스로 트래픽을 분산시키는 **팬아웃(Fan-out)** 구성이다.

이전엔 Django와 Flask를 각각 별도의 인그레스로 배포했지만, 이번에는 하나의 인그레스 리소스에서 **경로(path)**에 따라 */test01*은 Django로, 
*/test02*는 Flask로 연결하는 **경로 기반 라우팅(Path-based Routing)**을 구현한다.

이는 MSA에서 게이트웨이를 구성하는 핵심 원리이다.

---

# 2. 인그레스 파일 생성

가장 먼저 작업 디렉터리 구조를 정의하고 필요한 매니페스트 파일들을 준비한다.  
기존에 작성했던 Django와 Flask의 디플로이먼트 및 서비스(Service) 파일은 그대로 재사용하되, 트래픽을 분기한 새로운 인그레스 파일을 작성한다.

---

**작업 디렉터리 준비 및 파일 복사**

```shell
assu@myserver01:~/work/ch10$ pwd
/home/assu/work/ch10

# 작업 디렉터리 생성
assu@myserver01:~/work/ch10$ mkdir ex03
assu@myserver01:~/work/ch10$ cd ex03
assu@myserver01:~/work/ch10/ex03$
```

Django 디플로이먼트와 서비스 YAML 파일을 복사한다.

```shell
assu@myserver01:~/work/ch10/ex03$ cd ..
assu@myserver01:~/work/ch10$ ls
ex01  ex02  ex03
assu@myserver01:~/work/ch10$ cd ex01
assu@myserver01:~/work/ch10/ex01$ ls
django-deploy.yml  django-ingress.yml  django-service.yml  myDajngo04  myNginx04
assu@myserver01:~/work/ch10/ex01$ cp django-deploy.yml django-service.yml  ../ex03
assu@myserver01:~/work/ch10/ex01$ cd ../ex03
assu@myserver01:~/work/ch10/ex03$ ls
django-deploy.yml  django-service.yml
```

비슷하게 Flask의 디플로이먼트와 서비스 파일을 ex03 디렉터리로 복사한다.

```shell
assu@myserver01:~/work/ch10/ex03$ cd ../ex02
assu@myserver01:~/work/ch10/ex02$ ls
myFlask02  myNginx02f
assu@myserver01:~/work/ch10/ex02$ cd myNginx02f/
assu@myserver01:~/work/ch10/ex02/myNginx02f$ ls
1  default.conf  Dockerfile  flask-deploy.yml  flask-ingress.yml  flask-service.yml
assu@myserver01:~/work/ch10/ex02/myNginx02f$ cp flask-deploy.yml flask-service.yml ../../ex03
assu@myserver01:~/work/ch10/ex02/myNginx02f$ cd ../../ex03
assu@myserver01:~/work/ch10/ex03$ ls
django-deploy.yml  django-service.yml  flask-deploy.yml  flask-service.yml
```

---

**통합 인그레스 매니페스트 작성(django-flask-ingress.yml)**

두 서비스를 동시에 제어할 인그레스 설정이다.  
여기서 핵심은 `paths` 설정과 `rewrite-target` 애너테이션이다.

```shell
assu@myserver01:~/work/ch10/ex03$ vim django-flask-ingress.yml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: django-flask-ingress
  annotations:
    # URL 재작성 설정: 캡처 그룹($2)을 사용하여 경로의 뒷부분만 서비스로 전달
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          # Django 서비스 라우팅 (/test01 로 시작하는 모든 요청)
          - path: /test01(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: django-service  # django 웹 서비스 이름
                port:
                  number: 80
          # Flask 서비스 라우팅 (/test02 로 시작하는 모든 요청)
          - path: /test02(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: flask-service  # flask 웹 서비스 이름
                port:
                  number: 80
```

> Rewrite Target에 대한 내용은 [6.1. 매니페스트 작성(URL Rewriting)](https://assu10.github.io/dev/2025/12/29/kubernetes-flask-nginx-ingress-practice/#61-%EB%A7%A4%EB%8B%88%ED%8E%98%EC%8A%A4%ED%8A%B8-%EC%9E%91%EC%84%B1url-rewriting)을 참고하세요.

> 인그레스 설정값에 대한 좀 더 상세한 설명은 [6. 인그레스로 하나의 서비스 배포](https://assu10.github.io/dev/2025/12/22/kubernetes-ingress-helm-metallb-baremetal-loadbalancer/#6-%EC%9D%B8%EA%B7%B8%EB%A0%88%EC%8A%A4%EB%A1%9C-%ED%95%98%EB%82%98%EC%9D%98-%EC%84%9C%EB%B9%84%EC%8A%A4-%EB%B0%B0%ED%8F%AC)
> 를 참고하세요.

---

# 3. 배포 및 검증

이제 준비된 리소스들을 쿠버네티스 클러스터에 배포한다.  
순서는 일반적으로 **디플로이먼트(파드 생성) → Service(네트워크 노출) → 인그레스(외부 라우팅)** 순으로 진행하는 것이 좋다.

---

**디플로이먼트 및 서비스 배포**

```shell
assu@myserver01:~/work/ch10/ex03$ ll
total 28
drwxrwxr-x 2 assu assu 4096 Jan  3 02:34 ./
drwxrwxr-x 5 assu assu 4096 Jan  3 02:20 ../
-rw-rw-r-- 1 assu assu  510 Jan  3 02:22 django-deploy.yml
-rw-rw-r-- 1 assu assu  644 Jan  3 02:34 django-flask-ingress.yml
-rw-rw-r-- 1 assu assu  202 Jan  3 02:22 django-service.yml
-rw-rw-r-- 1 assu assu  520 Jan  3 02:24 flask-deploy.yml
-rw-rw-r-- 1 assu assu  207 Jan  3 02:24 flask-service.yml

# 디플로이먼트 배포
assu@myserver01:~/work/ch10/ex03$ kubectl apply -f django-deploy.yml
deployment.apps/deploy-django created
assu@myserver01:~/work/ch10/ex03$ kubectl apply -f flask-deploy.yml
deployment.apps/deploy-flask created

assu@myserver01:~/work/ch10/ex03$ kubectl get all
# django 파드와 flask 파드가 실행됨
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-django-77675fcbcf-g6dpb   2/2     Running   0          13s
pod/deploy-django-77675fcbcf-lh9gk   2/2     Running   0          13s
pod/deploy-django-77675fcbcf-lp2kc   2/2     Running   0          13s
pod/deploy-flask-b8ffb7c86-gz4mv     2/2     Running   0          6s
pod/deploy-flask-b8ffb7c86-lrrdw     2/2     Running   0          6s
pod/deploy-flask-b8ffb7c86-rrxdq     2/2     Running   0          6s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d21h

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-django   3/3     3            3           13s
deployment.apps/deploy-flask    3/3     3            3           6s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-django-77675fcbcf   3         3         3       13s
replicaset.apps/deploy-flask-b8ffb7c86     3         3         3       6s
```

```shell
# 서비스 배포
assu@myserver01:~/work/ch10/ex03$ kubectl apply -f django-service.yml
service/django-service created
assu@myserver01:~/work/ch10/ex03$ kubectl apply -f flask-service.yml
service/flask-service created

# 서비스들은 ClusterIP를 부여받음
assu@myserver01:~/work/ch10/ex03$ kubectl get svc
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
django-service   ClusterIP   10.98.235.44   <none>        80/TCP    10s
flask-service    ClusterIP   10.97.10.64    <none>        80/TCP    5s
kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP   7d21h
```

```shell
# 인그레스 배포
assu@myserver01:~/work/ch10/ex03$ kubectl apply -f django-flask-ingress.yml
ingress.networking.k8s.io/django-flask-ingress created
```

---

**배포 상태 확인**

모든 리소스가 정상적으로 생성되었는지 확인한다.

```shell
# 실행 중인 리소스들 확인
assu@myserver01:~/work/ch10/ex03$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/deploy-django-77675fcbcf-g6dpb   2/2     Running   0          2m29s
pod/deploy-django-77675fcbcf-lh9gk   2/2     Running   0          2m29s
pod/deploy-django-77675fcbcf-lp2kc   2/2     Running   0          2m29s
pod/deploy-flask-b8ffb7c86-gz4mv     2/2     Running   0          2m22s
pod/deploy-flask-b8ffb7c86-lrrdw     2/2     Running   0          2m22s
pod/deploy-flask-b8ffb7c86-rrxdq     2/2     Running   0          2m22s

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/django-service   ClusterIP   10.98.235.44   <none>        80/TCP    61s
service/flask-service    ClusterIP   10.97.10.64    <none>        80/TCP    56s
service/kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP   7d21h

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deploy-django   3/3     3            3           2m29s
deployment.apps/deploy-flask    3/3     3            3           2m22s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/deploy-django-77675fcbcf   3         3         3       2m29s
replicaset.apps/deploy-flask-b8ffb7c86     3         3         3       2m22s

# 실행 중인 인그레스 확인
assu@myserver01:~/work/ch10/ex03$ kubectl get ingress
NAME                   CLASS   HOSTS   ADDRESS   PORTS   AGE
django-flask-ingress   nginx   *                 80      25s
```

---

**접속 테스트**

로컬 환경에서 브라우저를 통해 접속을 시도한다.
- [http://127.0.0.1:2000/test01](http://127.0.0.1:2000/test01): Django 환영 페이지 노출
- [http://127.0.0.1:2000/test02](http://127.0.0.1:2000/test02): hello world!(Flask) 노출

하나의 도메인(여기서는 localhost)에서 경로만 바꾸어 서로 다른 기술 스택(Django, Flask)으로 만든 애플리케이션에 각각 접속되는 것을 확인할 수 있다.

---

# 4. 전체 아키텍처 및 리소스 정리

지금까지 진행한 내용의 전체 네트워크 흐름은 아래와 같다.

![전체적인 네크워크 흐름](/assets/img/dev/2025/1230/flow.png)

- **Client Request**: 사용자가 */test01* 또는 */test02* 경로로 요청을 보낸다.
- **Ingress Controller**: 요청 URL을 분석하여 규칙(Rule)에 정의된 서비스로 라우팅을 결정한다. 이 때 `Rewrite` 규칙이 적용되어 URL 접두사가 제거된다.
- **Service**: 선택된 서비스(Django service 또는 Flask service)는 트래픽을 적절한 파드로 부하 분산한다.
- **Pod**: 최종적으로 컨테이너 내부의 애플리케이션이 요청을 처리하고 응답을 반환한다.

---

**리소스 정리**

사용한 리소스를 정리하여 클러스터 자원을 확보한다.

```shell
assu@myserver01:~/work/ch10/ex03$ kubectl delete -f django-flask-ingress.yml
ingress.networking.k8s.io "django-flask-ingress" deleted
assu@myserver01:~/work/ch10/ex03$ kubectl delete -f django-service.yml
service "django-service" deleted
assu@myserver01:~/work/ch10/ex03$ kubectl delete -f flask-service.yml
service "flask-service" deleted
assu@myserver01:~/work/ch10/ex03$ kubectl delete -f django-deploy.yml
deployment.apps "deploy-django" deleted
assu@myserver01:~/work/ch10/ex03$ kubectl delete -f flask-deploy.yml
deployment.apps "deploy-flask" deleted

assu@myserver01:~/work/ch10/ex03$ kubectl get ingress
No resources found in default namespace.

assu@myserver01:~/work/ch10/ex03$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d21h
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Doc:: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)