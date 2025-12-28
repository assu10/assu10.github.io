---
layout: post
title:  "Kubernetes - MetalLB와 Ingress(온프레미스 쿠버네티스 LoadBalancer 문제 해결)"
date: 2025-12-22 10:00:00
categories: dev
tags: devops kubernetes k8s helm ingress nginx-ingress-controller metallb bare-metal on-premise loadbalancer l7-loadbalancer service-exposure routing
---

쿠버네티스 클러스터를 구축하고 애플리케이션을 배포했다면, 그 다음으로 마주하는 것은 **외부의 사용자가 내부의 서비스에 어떻게 접근하게 만들 것인가?**이다.

AWS나 GCP 같은 퍼블릭 클라우드 환경에서는 LoadBalancer 타입의 서비스를 생성하면 자동으로 외부 IP가 할당되지만, 지금 실습하는 로컬 VM이나 
베어메탈(Bare-Metal) 환경에서는 이러한 자동화된 로드밸런서가 존재하지 않아 IP가 `<pending>` 상태로 남게 된다.

이 포스트에서는 이러한 환경적 제약을 극복하고 서비스를 우아하게 노출하는 방법에 대해 알아본다.  
쿠버네티스의 패키지 매니저인 **헬름(Helm)**을 사용하여 **Nginx Ingress Controller**를 설치하고, **MetalLB**를 통해 베어메탈 환경에서도 LoadBalancer IP를 
할당받는 전체 과정을 실습해본다.

> **베어메탈(Bare Metal) 환경**
> 
> 어떠한 소프트웨어(가상화 계층)도 거치지 않고 하드웨어 위에 운영체제를 직접 설치하여 사용하는 환경

최종적으로는 Ingress 설정을 통해 단일 IP로 들어오는 트래픽을 여러 서비스로 라우팅하는 L7 로드밸런싱을 구현해본다.

---

**목차**

<!-- TOC -->
* [1. 인그레스(Ingress) 개념](#1-인그레스ingress-개념)
* [2. 헬름(Helm) 개념](#2-헬름helm-개념)
* [3. 헬름 설치](#3-헬름-설치)
* [4. 헬름으로 `nginx ingress controller` 설치](#4-헬름으로-nginx-ingress-controller-설치)
* [5. metalLB를 통한 베어메탈 LoadBalancer 구성](#5-metallb를-통한-베어메탈-loadbalancer-구성)
* [6. 인그레스로 하나의 서비스 배포](#6-인그레스로-하나의-서비스-배포)
* [7. 인그레스로 두 개의 서비스 배포](#7-인그레스로-두-개의-서비스-배포)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Guest OS: Ubuntu 24.04.2 LTS
- Host OS: Mac Apple M3 Max
- Memory: 48 GB
- Kubernetes Cluster: Custom Setup (Bare-metal style on VM)

---

# 1. 인그레스(Ingress) 개념

쿠버네티스에서 [`Service` 오브젝트(LoadBalancer, NodePort)](https://assu10.github.io/dev/2025/12/08/kubernetes-service-concept-and-types/)만으로도 외부 연결이 가능하다.  
하지만 서비스가 늘어날 때마다 매번 로드밸런서를 생성하고 IP를 할당받는 것은 비용과 관리 측면에서 매우 비효율적이다.  
이 때 필요한 것이 바로 **인그레스(Ingress)**이다.

인그레스는 클러스터 외부의 HTTP/HTTPS 트래픽을 내부의 서비스로 라우팅하는 규칙(Rules)의 집합이다.  
쉽게 말해서 '어떤 주소로 들어오면 어디로 보내라'는 교통 정리 역할을 하는 **L7(Application Layer) 로드밸런서**이다.

단순히 IP와 포트만 보고 연결해주는 L4 로드밸런서(예: MetalLB 자체)와 달리, 인그레스는 **URL 경로(Path)**나 **도메인(Host)**을 이해한다.

- **단일 진입점**
  - 클라이언트는 하나의 IP(인그레스 컨트롤)로만 접근함
- **라우팅 규칙**
  - http://my-ip/test01 → **Service A**로 전달
  - http://my-ip/test02 → **Service B**로 전달

이처럼 인그레스를 사용하면 단 하나의 로드밸런서 IP만으로도 수십 개의 웹 서비스를 경로 기반으로 나누어 서비스할 수 있어, 운영 효율성을 극대화할 수 있다.

![Ingress 개념](/assets/img/dev/2025/1222/ingress.png)

---

# 2. 헬름(Helm) 개념

쿠버네티스 애플리케이션을 배포하려면 Pod, Service, ConfigMap, Ingress 등 수많은 YAML 파일을 작성하고 관리해야 한다.  
버전이 업데이트되거나 환경 변수를 바꿀 때마다 이 파일들을 일일이 수정하는 것은 어려운 작업이다.

**헬름(Helm)**은 이러한 문제를 해결해 주는 쿠버네티스 패키지 매니저이다.
헬름을 활용하면 YAML 파일을 만들지 않고도 쿠버네티스 환경에서 애플리케이션을 쉽게 설치할 수 있다.

![Helm 개념](/assets/img/dev/2025/1222/helm.png)

리눅스의 `apt`나 `yum`이 패키지를 관리하듯, 헬름은 쿠버네티스 리소스를 패키지 단위로 관리한다.
- **차트(Chart)**
  - 쿠버네티스 리소스 파일들의 묶음(패키지)
- **리포지토리(Repository)**
  - 차트들이 저장된 원격 저장소(도커 허브와 유사)
- **릴리스(Release)**
  - 차트가 클러스터에 설치되어 실행 중인 인스턴스
- **values.yaml**
  - 사용자가 설정을 변경할 수 있는 설정 파일
  - 이를 통해 YAML을 직접 수정하지 않고도 이미지 버전이나 포트 등을 쉽게 변경 가능

즉, 헬름을 통해 쿠버네티스 애플리케이션을 설치한다는 말은 리포지토리에서 헬름 차트를 다운로드하고 해당 디렉터리에 있는 파일을 수정하여 자신의 환경에 맞게 
최적화한 후 쿠버네티스 클러스터에 설치하는 것이다.

---

# 3. 헬름 설치

실습을 위해 헬름을 설치해보자.  
헬름 클라이언트는 `kubectl` 명령을 내리는 마스터 노드에만 설치하면 된다.

---

**설치 스크립트 실행**

작업 디렉터리를 생성하고 공식 스크립트를 다운로드한다.

> 헬름을 설치하는 자세한 방법은 [Doc:: Installing Helm](https://helm.sh/docs/intro/install/) 을 참고하세요.

```shell
assu@myserver01:~/work$ mkdir -p app/helm && cd app/helm
assu@myserver01:~/work/app/helm$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
assu@myserver01:~/work/app/helm$ ls
get_helm.sh

assu@myserver01:~/work/app/helm$ chmod 700 get_helm.sh
```

스크립트를 실행하여 헬름을 설치한다.

```shell

assu@myserver01:~/work/app/helm$ ./get_helm.sh
Downloading https://get.helm.sh/helm-v4.0.4-linux-arm64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
[sudo] password for assu:
helm installed into /usr/local/bin/helm

assu@myserver01:~/work/app/helm$ helm version
version.BuildInfo{Version:"v4.0.4", GitCommit:"8650e1dad9e6ae38b41f60b712af9218a0d8cc11", GitTreeState:"clean", GoVersion:"go1.25.5", KubeClientVersion:"v1.34"}
```

---

# 4. 헬름으로 `nginx ingress controller` 설치

이제 헬름을 사용하여 인그레스 규칙을 실제로 수행할 구현체인 **Nginx Ingress Controller**를 설치한다.  
이전에는 복잡한 설정 파일을 직접 수정해야 했지만, 헬름을 사용하면 명령어 한 줄로 필요한 옵션을 적용하여 간편하게 설치할 수 있다.

**리포지토리 추가**

먼저 `ingress-nginx` 공식 헬름 리포지토리를 추가한다.

```shell
assu@myserver01:~/work/app/helm$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
"ingress-nginx" has been added to your repositories

assu@myserver01:~/work/app/helm$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "ingress-nginx" chart repository
Update Complete. ⎈Happy Helming!⎈
```

---

**디렉터리 정리**

```shell
assu@myserver01:~/work/app$ pwd
/home/assu/work/app
assu@myserver01:~/work/app$ ls
helm

assu@myserver01:~/work/app$ mkdir nginx-ingress-controller
assu@myserver01:~/work/app$ cd nginx-ingress-controller/
assu@myserver01:~/work/app/nginx-ingress-controller$
```

---

**네임 스페이스 생성**

인그레스 컨트롤러를 관리할 전용 네임스페이스(mynginx)를 생성한다. 전용 네임스페이스를 사용하면 다른 리소스와 섞이지 않아 관리가 용이하다.

```shell
# 현재 있는 네임스페이스 확인
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ kubectl get namespace
NAME               STATUS   AGE
calico-apiserver   Active   13d
calico-system      Active   13d
default            Active   13d
kube-node-lease    Active   13d
kube-public        Active   13d
kube-system        Active   13d
tigera-operator    Active   13d
```

```shell
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ kubectl create namespace mynginx
namespace/mynginx created

assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ kubectl get namespace
NAME               STATUS   AGE
calico-apiserver   Active   13d
calico-system      Active   13d
default            Active   13d
kube-node-lease    Active   13d
kube-public        Active   13d
kube-system        Active   13d
mynginx            Active   7s
tigera-operator    Active   13d
```

---

**헬름으로 설치 진행**

이제 Nginx Ingress Controller를 설치한다.

여기서 중요한 옵션은 `controller.publishService.enabled=true` 이다. 이 옵션은 인그레스 컨트롤러가 할당받은 외부 IP(LoadBalancer IP)를 인그레스 리소스의 
status 필드에 업데이트하도록 하여, 트래픽이 올바르게 라우팅되도록 돕는다.

```shell
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ helm install nginx-ingress-controller ingress-nginx/ingress-nginx \
  --namespace mynginx \
  --set controller.publishService.enabled=true

NAME: nginx-ingress-controller-1766819417
LAST DEPLOYED: Sat Dec 27 07:10:23 2025
NAMESPACE: mynginx
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
CHART NAME: nginx-ingress-controller
CHART VERSION: 12.0.7
APP VERSION: 1.13.1
```

- `ingress-nginx/ingress-nginx`
  - 설치할 차트 이름(리포지토리/차트명)
- `--namespace mynginx`
  - 설치할 네임스페이스 지정
- `--set controller.publishService.enabled=true`
  - `values.yaml`을 직접 수정하지 않고, 설치 시점에 동적으로 설정 주입

---

**설치 확인**

설치가 완료되면 파드와 서비스가 정상적으로 생성되었는지 확인한다.

```shell
# nginx-ingress-controller를 mynginx 네임스페이스에 설치했기 때문에 아무것도 안 나온다.
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ helm ls
NAME	NAMESPACE	REVISION	UPDATED	STATUS	CHART	APP VERSION

# --namespace를 통해 네임스페이스를 지정해주면 설치가 된 것을 확인할 수 있다.
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ helm ls -n mynginx
NAME                    	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART               	APP VERSION
nginx-ingress-controller	mynginx  	1       	2025-12-28 05:32:02.781702412 +0000 UTC	deployed	ingress-nginx-4.14.1	1.14.1
```

```shell
# 실행 중인 쿠버네티스 오브젝트를 확인해도 nginx-ingress-controller 는 확인할 수 없음. mynginx 네임스페이스를 지정해주어야 함
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ kubectl get all -o wide
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   26h   <none>

# 네임스페이스 리스트 확인
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ kubectl get namespace
NAME               STATUS   AGE
calico-apiserver   Active   13d
calico-system      Active   13d
default            Active   13d
kube-node-lease    Active   13d
kube-public        Active   13d
kube-system        Active   13d
mynginx            Active   45m
tigera-operator    Active   13d

# mynginx 네임스페이스에서 실행 중인 오브젝트 확인
assu@myserver01:~/work/app/nginx-ingress-controller/nginx-ingress-controller-12.0.7$ kubectl get all --namespace mynginx
NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/nginx-ingress-controller-ingress-nginx-controller-79bdc88bq9qzp   1/1     Running   0          3h34m

# 서비스 영역을 보면 nginx-ingress-controller를 외부에서 접근할 수 있는 EXTERNAL-IP가 <pending>임
# 이는 IP가 할당되지 않았음을 의미함
# 이후에 metallb를 설치하여 nginx-ingress-controller-1766819417 에 EXTERNAL-IP를 할당함
NAME                                                                  TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/nginx-ingress-controller-ingress-nginx-controller             LoadBalancer   10.107.56.92    <pending>     80:32038/TCP,443:32311/TCP   3h34m
service/nginx-ingress-controller-ingress-nginx-controller-admission   ClusterIP      10.107.71.139   <none>        443/TCP                      3h34m

NAME                                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-ingress-controller-ingress-nginx-controller   1/1     1            1           3h34m

NAME                                                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-ingress-controller-ingress-nginx-controller-79bdc88b77   1         1         1       3h34m
```

**확인 포인트:**  
- **Pod Status**
  - `Running` 상태이어야 한다.
- **Service EXTERNAL-IP**
  - 현재는 `<pending>` 상태인 것이 정상이다.
  - 아직 클라우드 환경이 아닌 베어메탈(VM) 환경에 있기 때문에, IP를 할당해 줄 로드밸런서가 아직 없기 때문이다.
  - 바로 다음 단계에서 **MetalLB**를 설치하여 이 `<pending>` 상태를 해결하고 실제 IP를 할당받을 것이다.

---

# 5. metalLB를 통한 베어메탈 LoadBalancer 구성

[4. 헬름으로 `nginx ingress controller` 설치](#4-헬름으로-nginx-ingress-controller-설치)에서 확인했듯이, 온프레미스나 베어메탈(VM) 환경에서는 
클라우드 제공자(AWS, GCP)가 없기 때문에 `LoadBalancer` 타입의 서비스를 생성해도 IP가 할당되지 않고 `<pending>` 상태로 남는다.

이를 해결하기 위해 **MetalLB**를 사용한다.  
MetalLB는 베어메탈 환경에서 표준 라우팅 프로토콜(ARP/BGP)을 사용하여 로드밸런서 기능을 구현해준다.

> MetalLB에 대한 좀 더 상세한 내용은 [MetalLB](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-loadbalancer-for-bare-metal/)를 참고하세요.

---

**사전 준비: kube-proxy 설정(`strictARP`)**

MetalLB가 정상적으로 작동하려면 `kube-proxy`의 `strictARP` 모드가 활성화되어야 한다.

> `strictARP` 에 대한 좀 더 상세한 내용은 [strictARP](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-ipvs-strict-arp-deep-dive/)를 참고하세요.

먼저 현재 설정을 확인한다.

```shell
assu@myserver01:~/work$ kubectl get configmap kube-proxy -n kube-system -o yaml | grep strictARP
      strictARP: false
```

`kube-proxy`의 `strictARP`가 false 이므로, 아래 명령어를 통해 true로 변경해준다.

```shell
assu@myserver01:~/work$ kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

Warning: resource configmaps/kube-proxy is missing the kubectl.kubernetes.io/last-applied-configuration annotation 
which is required by kubectl apply. 
kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. 
The missing annotation will be patched automatically.
configmap/kube-proxy configured
```

이제 strictARP 를 확인하면 true로 변경된 것을 알 수 있다.

```shell
assu@myserver01:~/work$ kubectl get configmap kube-proxy -n kube-system -o yaml | grep strictARP
      strictARP: true
      ...
```

---

**MetalLB 헬름 설치**

MetalLB 설치를 위한 디렉터리를 생성하고 공식 리포지토리를 추가한다.

```shell
assu@myserver01:~/work$ mkdir -p app/metallb && cd app/metallb

# MetalLB 공식 리포지토리 추가
assu@myserver01:~/work/app/metallb$ helm repo add metallb https://metallb.github.io/metallb
"metallb" has been added to your repositories

assu@myserver01:~/work/app/metallb$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "metallb" chart repository
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
```

최신 버전의 차트를 다운로드(pull)하고 압축을 해제한다.

```shell
# 2개의 검색 결과
assu@myserver01:~/work/app/metallb$ helm search repo metallb
NAME           	CHART VERSION	APP VERSION	DESCRIPTION
bitnami/metallb	6.4.22       	0.15.2     	MetalLB is a load-balancer implementation for b...
metallb/metallb	0.15.3       	v0.15.3    	A network load-balancer implementation for Kube...

assu@myserver01:~/work/app/metallb$ helm pull metallb/metallb
assu@myserver01:~/work/app/metallb$ ls
metallb-0.15.3.tgz

assu@myserver01:~/work/app/metallb$ tar xvfz metallb-0.15.3.tgz
assu@myserver01:~/work/app/metallb$ ls
metallb  metallb-0.15.3.tgz

assu@myserver01:~/work/app/metallb$ mv metallb metallb-0.15.3
assu@myserver01:~/work/app/metallb$ ls
metallb-0.15.3  metallb-0.15.3.tgz
```

설치 시 사용할 기본 설정 파일(`values.yaml`)을 복사해 둔다.(필요 시 수정하여 사용)

```shell
assu@myserver01:~/work/app/metallb$ cd metallb-0.15.3/
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ ls
Chart.lock  charts  Chart.yaml  policy  README.md  templates  values.schema.json  values.yaml

assu@myserver01:~/work/app/metallb/metallb-0.15.3$ cp values.yaml my-values.yaml
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ ls
Chart.lock  charts  Chart.yaml  my-values.yaml  policy  README.md  templates  values.schema.json  values.yaml
```

관리 목적의 네임스페이스인 mymetallb 를 생성하고 설치를 진행한다.

```shell
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl create namespace mymetallb
namespace/mymetallb created

assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl get namespace
NAME               STATUS   AGE
calico-apiserver   Active   13d
calico-system      Active   13d
default            Active   13d
kube-node-lease    Active   13d
kube-public        Active   13d
kube-system        Active   13d
mymetallb          Active   7s
mynginx            Active   4h10m
tigera-operator    Active   13d
```

```shell
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ helm install metallb . \
--namespace mymetallb \
-f my-values.yaml

NAME: metallb-1766834438
LAST DEPLOYED: Sat Dec 27 11:20:39 2025
NAMESPACE: mymetallb
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
MetalLB is now running in the cluster.

Now you can configure it via its CRs. Please refer to the metallb official docs
on how to use the CRs.
```

[설치 후 메시지를 보면 CRs를 통해 설정을 할 수 있다고 한다.](https://assu10.github.io/dev/2025/12/22/kubernetes-custom-resource-definition-metallb-configuration/)  
따라서 지금부터는 metalLB가 관리할 IP주소 범위를 설정한다.

먼저 metalLB를 통해 설치한 오브젝트가 원활하게 동작하고 있는지 확인한다.  
controller와 노드마다 실행되는 speaker 파드가 보여야 한다.

```shell
# speaker와 controller가 정상적으로 작동 중(Running)이다.
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl get all --namespace mymetallb
NAME                                               READY   STATUS    RESTARTS   AGE
pod/metallb-1766834438-controller-66c6c584-kbwdn   1/1     Running   0          22m
pod/metallb-1766834438-speaker-7sjlw               4/4     Running   0          22m
pod/metallb-1766834438-speaker-j99kv               4/4     Running   0          22m
pod/metallb-1766834438-speaker-zkktj               4/4     Running   0          22m

# metallb-webhook-service 의 EXTERNAL-IP 가 none 인 것은 정상이다. metallb-webhook-service 는 클러스터 내부에서만 사용하기 때문이다.
NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/metallb-webhook-service   ClusterIP   10.97.206.62   <none>        443/TCP   22m

NAME                                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/metallb-1766834438-speaker   3         3         3       3            3           kubernetes.io/os=linux   22m

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/metallb-1766834438-controller   1/1     1            1           22m

NAME                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/metallb-1766834438-controller-66c6c584   1         1         1       22m
```

---

**MetalLB 설정(IP 주소 풀 할당)**

설치는 완료되었지만 MetalLB가 어떤 IP 대역을 사용할지 아직 모르는 상태이다.  
과거에는 ConfigMap을 사용했으나, 최근에는 **CRD(Custom Resource Definition)**을 통해 설정한다.

> MetalLB CRD에 대한 좀 더 상세한 내용은 [MetalLB 설정의 핵심 CRs](https://assu10.github.io/dev/2025/12/22/kubernetes-custom-resource-definition-metallb-configuration/#metallb-%EC%84%A4%EC%A0%95%EC%9D%98-%ED%95%B5%EC%8B%AC-crs)를 참고하세요.

이제 metalLB의 설정을 변경하기 위해 metalLB를 설치했던 디렉터리에서 config 파일을 추가한다.

```shell
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ vim my-config.yaml
```

```yaml
---
# metalLB가 로드밴런서 서비스에 할당할 IP 주소의 범위를 정의하는 리소스
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: my-metallb-config
  namespace: mymetallb
spec:
  addresses:
    - 10.0.2.20-10.0.2.40   # 로드밸런서가 사용할 IP 범위
  autoAssign: true
---
# 정의된 IP 주소 풀을 네트워크에 어떻게 알릴지(Advertisement) 설정하는 리소스
# Layer 2 모드(ARP 사용)로 동작할지, BGP 모드로 동작할지 결정하는 역할 수행
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: my-metallb-config
  namespace: mymetallb
spec:
  ipAddressPools:
    - my-metallb-config
```

**주의사항:**  
`addresses` 범위를 설정할 때, **쿠버네티스 노드들이 실제로 사용 중인 IP(예: 10.0.2.4~10.0.2.6)과 겹치지 않도록** 주의해야 한다.  
IP 충돌을 방지하기 위해 여유 있는 대역(예: 20~40)을 할당했다.

작성한 설정을 적용한다.

```shell
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl apply -f my-config.yaml
ipaddresspool.metallb.io/my-metallb-config created
l2advertisement.metallb.io/my-metallb-config created

assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl get ipaddresspool.metallb.io --namespace mymetallb
NAME                AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
my-metallb-config   true          false             ["10.0.2.20-10.0.2.40"]  # my-metallb-config가 정상적으로 실행된 것을 확인할 수 있다.
```

`describe` 를 통해 my-metallb-config 의 상세 정보를 확인한다.

```shell
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl describe ipaddresspool.metallb.io my-metallb-config --namespace mymetallb
Name:         my-metallb-config
Namespace:    mymetallb
Labels:       <none>
Annotations:  <none>
API Version:  metallb.io/v1beta1
Kind:         IPAddressPool
Metadata:
  Creation Timestamp:  2025-12-27T12:13:54Z
  Generation:          1
  Resource Version:    292181
  UID:                 f03615d3-532e-401a-ae1e-170950e9e60b
Spec:
  Addresses:
    10.0.2.20-10.0.2.40  # IP 주소 범위가 정확히 설정되어 있는 것 확인
  Auto Assign:       true
  Avoid Buggy I Ps:  false
Status:
  assignedIPv4:   1
  assignedIPv6:   0
  availableIPv4:  20
  availableIPv6:  0
Events:           <none>
```

---

**IP 할당 확인**

이제 MetalLB가 설정을 받아들였으므로, **Nginx Ingress Controller** 서비스를 다시 확인해보자.  
`<pending>` 상태였던 External-IP가 할당되었을 것이다.

mynginx 네임스페이스에 존재하는 오브젝트를 확인한다.

```shell
assu@myserver01:~/work/ch09/ex13$ kubectl get all -n mynginx

NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/nginx-ingress-controller-ingress-nginx-controller-79bdc88bq9qzp   1/1     Running   0          4h19m

NAME                                                                  TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/nginx-ingress-controller-ingress-nginx-controller             LoadBalancer   10.107.56.92    10.0.2.20     80:32038/TCP,443:32311/TCP   4h19m
service/nginx-ingress-controller-ingress-nginx-controller-admission   ClusterIP      10.107.71.139   <none>        443/TCP                      4h19m

NAME                                                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-ingress-controller-ingress-nginx-controller   1/1     1            1           4h19m

NAME                                                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-ingress-controller-ingress-nginx-controller-79bdc88b77   1         1         1       4h19m
```

서비스 영역의 nginx-ingress-controller 에 10.0.2.20 라는 외부 아이피인 `EXTERNAL-IP`가 할당된 것을 확인할 수 있다.

`kubectl describe` 명령어로 상세 이벤트를 확인해보면 MetalLB가 IP를 할당한 기록을 볼 수 있다.

```shell
assu@myserver01:~/work/app/metallb/metallb-0.15.3$ kubectl describe service/nginx-ingress-controller-1766819417 --namespace mynginx
...
Events:
  Type    Reason       Age   From                Message
  ----    ------       ----  ----                -------
  Normal  IPAllocated  14h   metallb-controller  Assigned IP ["10.0.2.20"]
```

---

**호스트 포트 포워딩(VM 환경)**

VM 환경에서 실습 중이므로, VM 내부의 IP(10.0.2.20)로 호스트 PC(내 로컬)에서 직접 접근이 불가할 수 있다.  
이 경우 VM 설정에서 **포트 포워딩**을 해주어야 한다.

![포트 포워딩](/assets/img/dev/2025/1222/portforwarding.png)

위 그림처럼 호스트의 포트(예: 2000)를 게스트 VM의 인그레스 IP(10.0.2.20)이나 노드 IP의 포트로 전달하도록 설정하면, 로컬 브라우저에서도 접속 테스트가 가능하다.

---

# 6. 인그레스로 하나의 서비스 배포

이제 환경 구성이 되었으니, 실제로 인그레스를 활용해 웹 서비스를 배포해보자.

---

**디렉터리 준비**

```shell
assu@myserver01:~/work/ch09$ mkdir ex13
assu@myserver01:~/work/ch09$ cd ex13
```

---

**디플로이먼트 생성(ingress01-deploy.yml)**

가장 먼저 웹 서비스를 수행할 애플리케이션(Nginx 파드)를 배포한다.

```shell
assu@myserver01:~/work/ch09/ex13$ vim ingress01-deploy.yml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-deploy-test01
spec:
  replicas: 3
  selector: # 이 라벨을 가진 파드를 관리함
    matchLabels:
      app.kubernetes.io/name: web-deploy01  # selector로 적용되는 이름이 되므로 파드를 생성했을 때의 이름과 동일해야 함
  template: # 생성될 파드의 스펙
    metadata:
      labels:
        app.kubernetes.io/name: web-deploy01  # 서비스와 연결될 라벨
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
```

디플로이먼트를 실행하고 파드가 정상적으로 생성되었는지 확인한다.

```shell
assu@myserver01:~/work/ch09/ex13$ kubectl apply -f ingress01-deploy.yml
deployment.apps/ingress-deploy-test01 created

assu@myserver01:~/work/ch09/ex13$ kubectl get all
# 파드 3개가 실행됨
NAME                                         READY   STATUS    RESTARTS   AGE
pod/ingress-deploy-test01-68d47df476-8qq8q   1/1     Running   0          6s
pod/ingress-deploy-test01-68d47df476-db5gk   1/1     Running   0          6s
pod/ingress-deploy-test01-68d47df476-l2ctz   1/1     Running   0          6s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   47h

# 디플로이먼트 실행됨
NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-deploy-test01   3/3     3            3           6s

# 레플리카셋 실행됨
NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-deploy-test01-68d47df476   3         3         3       6s
```

---

**서비스(Service) 생성(ingress01-service.yml)**

파드 앞단에서 트래픽을 받아줄 서비스를 생성한다.  
여기서 중요한 점은 서비스 타입이 `ClusterIP`라는 점이다. 외부 노출은 인그레스가 담당하므로 이 서비스는 **클러스터 내부에서 인그레스 컨트롤러와 통신**만 되면 충분하다.

```shell
assu@myserver01:~/work/ch09/ex13$ vim ingress01-service.yml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-service-test01
spec:
  selector: # 디플로이먼트의 파드 라벨과 일치해야 함
    app.kubernetes.io/name: web-deploy01  # 디플로이먼트에서 만든 web-deploy01 앱과 연동
  type: ClusterIP   # 인그레스 연결용이므로 내부 IP만 있으면 됨
  ports:  # 서비스를 사용하기 위한 포트 정의
    - protocol: TCP
      port: 80    # 서비스가 사용하는 포트
      targetPort: 80    # 파드가 받게 될 포트
```

서비스를 생성하고 확인한다.

```shell
assu@myserver01:~/work/ch09/ex13$ kubectl apply -f ingress01-service.yml
service/ingress-service-test01 created

assu@myserver01:~/work/ch09/ex13$ kubectl get service
NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
ingress-service-test01   ClusterIP   10.108.252.69   <none>        80/TCP    4s  # 정상적으로 실행
kubernetes               ClusterIP   10.96.0.1       <none>        443/TCP   47h
```

---

**인그레스(Ingress) 생성(ingress01-ingress.yml)**

이제 외부의 요청을 서비스로 연결해 줄 라우팅 규칙(Ingress)을 정의한다.

```shell
assu@myserver01:~/work/ch09/ex13$ vim ingress01-ingress.yml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test01
  annotations:  # 인그레스 컨트롤러에 대해 옵션을 설정
    # [중요] 사용자가 /test01로 접근하더라도 백엔드 파드에는 / 경로로 전달하도록 재작성
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx   # 설치한 Nginx Ingress Controller 사용, kubectl get ingressclass 입력 시 나오는 결과인 nginx 로 기재
  rules:
    - http: # http 사용
        paths:
          - path: /test01   # 사용자가 접근할 URL 경로
            pathType: Prefix  # pathType은 path를 인식하는 방식을 정하는 옵션으로 Prefix는 접두사가 일치하면 해당 경로가 적용됨, Exact로 하면 정확히 일치해야 함
            backend:  # 백엔드 설정
              service:  # 인그레스에 연동할 서비스 등록
                name: ingress-service-test01  # 연결할 서비스 이름
                port:
                  number: 80
```

**설정 포인트:**  
`rewrite-target: /`: 사용자가 http://IP/test01 로 요청을 보낼 때, 실제 Nginx 웹 서버는 `/test01` 이라는 경로를 알지 못한다.(기본값은 `/`가 루트)  
이 애너테이션은 요청을 백엔드로 보낼 때 `/test01`을 `/`로 바꿔서 전달해 주는 역할을 한다.

인그레스를 생성 후 확인한다.

```shell
assu@myserver01:~/work/ch09/ex13$ kubectl apply -f ingress01-ingress.yml
ingress.networking.k8s.io/ingress-test01 created

assu@myserver01:~/work/ch09/ex13$ kubectl get ingress
NAME             CLASS   HOSTS   ADDRESS     PORTS   AGE
ingress-test01   nginx   *       10.0.2.20   80      71m
```

`ADDRESS` 필드에 IP(10.0.2.20)이 표시되기까지 약 1분 정도 소요된다.  
이 IP는 MetalLB가 Nginx Ingress Controller 서비스에 할당한 IP와 동일하다.

---

**아키텍처 및 접속 테스트**

지금까지 작성한 YAML 파일들의 유기적인 연결 관계는 아래와 같다.  
Ingress가 Service를 가리키고, Service가 Deployment(Pod)를 가리키는 구조이다.

![Ingress yml 관계](/assets/img/dev/2025/1222/yml.png)

실제 트래픽이 흐르는 경로는 다음과 같다.

![인그레스를 통한 서비스 배포](/assets/img/dev/2025/1222/flow.png)

사용자는 **MetalLB IP**로 진입하고, **Ingress Controller**가 경로를 확인한 뒤 **Service**를 거쳐 **Pod**로 도달한다.

이제 브라우저에서 접속을 시도해보자.  
VM 환경에서 포트 포워딩(Host: 2000 → VM LB IP: 80)을 설정했으므로, 호스트 PC에서 아래 주소로 접속한다.

- [http://127.0.0.1:2000/test01](http://127.0.0.1:2000/test01)

Nginx 의 환영 페이지가 보인다면 성공이다.

---

**리소스 정리**

현재 생성한 리소스들을 삭제한다.

```shell
assu@myserver01:~/work/ch09/ex13$ kubectl delete -f ingress01-ingress.yml
ingress.networking.k8s.io "ingress-test01" deleted
assu@myserver01:~/work/ch09/ex13$ kubectl delete -f ingress01-service.yml
service "ingress-service-test01" deleted
assu@myserver01:~/work/ch09/ex13$ kubectl delete -f ingress01-deploy.yml
deployment.apps "ingress-deploy-test01" deleted

assu@myserver01:~/work/ch09/ex13$ kubectl get ingress
No resources found in default namespace.

assu@myserver01:~/work/ch09/ex13$ kubectl get all -o wide
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   2d    <none>
```

---

# 7. 인그레스로 두 개의 서비스 배포

여기서는 인그레스의 꽃이라 할 수 있는 **경로 기반 라우팅(Path-based Routing)**을 통해, 하나의 IP로 여러 서비스를 운영하는 **L7 로드밸런싱**을 구현해본다.

[6. 인그레스로 하나의 서비스 배포](#6-인그레스로-하나의-서비스-배포)에서는 인그레스를 통해 하나의 서비스만 연결했다.  
하지만 인그레스의 진정한 가치는 **단일 진입점(IP/도메인)으로 들어온 트래픽을 URL 경로나 호스트 이름에 따라 여러 서비스로 분산**시키는 데 있다.  
이를 [**Fan-out**](https://assu10.github.io/dev/2025/05/27/fanout/) 구성이라고도 한다.

여기서는 `/test01` 경로는 첫 번째 서비스로, `/test02` 경로는 두 번째 서비스로 연결하는 구성을 해본다.

---

**디렉터리 준비**

```shell
assu@myserver01:~/work/ch09$ cp -r ex13 ex14
assu@myserver01:~/work/ch09$ cd ex14

assu@myserver01:~/work/ch09/ex14$ ll
total 24
drwxrwxr-x  2 assu assu 4096 Dec 28 07:09 ./
drwxrwxr-x 16 assu assu 4096 Dec 28 07:09 ../
-rw-rw-r--  1 assu assu  333 Dec 28 07:09 1
-rw-rw-r--  1 assu assu  332 Dec 28 07:09 ingress01-deploy.yml
-rw-rw-r--  1 assu assu  410 Dec 28 07:09 ingress01-ingress.yml
-rw-rw-r--  1 assu assu  212 Dec 28 07:09 ingress01-service.yml
```

---

**두 번째 웹 서비스(Deployment & Service) 정의**

첫 번째 서비스(/test01)은 이미 준비되어 있으므로, 두 번째 서비스인 /test02를 위한 디플로이먼트와 서비스 매니페스트를 작성한다.


**디플로이먼트(ingress02-deploy.yml)**

기존 파일에서 이름과 라벨을 02로 변경한다.

```shell
assu@myserver01:~/work/ch09/ex14$ vim ingress02-deploy.yml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-deploy-test02   # 이름 변경
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: web-deploy02  # 라벨 변경
  template:
    metadata:
      labels:
        app.kubernetes.io/name: web-deploy02  # 라벨 변경
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
```

**서비스(ingress02-service.yml)**

마찬가지로 web-deploy02 파드를 바라보도록 셀렉터를 설정한다.

```shell
assu@myserver01:~/work/ch09/ex14$ vim ingress02-service.yml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-service-test02  # 서비스 이름 변경
spec:
  selector:
    app.kubernetes.io/name: web-deploy02  # 위에서 만든 파드와 연결
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

---

**멀티 패스 인그레스 정의**

이제 가장 중요한 인그레스 규칙을 작성한다.  
하나의 host 아래 두 개의 `path`를 정의하여 트래픽을 분기한다.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress 
metadata:
  name: ingress-test02 
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          # 첫 번째 경로
          - path: /test01
            pathType: Prefix
            backend:
              service:
                name: ingress-service-test01
                port:
                  number: 80
          # 두 번째 경로 (추가됨)
          - path: /test02
            pathType: Prefix
            backend:
              service:
                name: ingress-service-test02    # 두 번째 path 가 바라보는 서비스 이름
                port:
                  number: 80
```

이 YAML 파일들의 관계는 아래와 같다.

![Ingress 구조](/assets/img/dev/2025/1222/yml2.png)

---

**배포 및 실행 확인**

이제 디플로이먼트, 서비스, 인그레스를 실행한다.

```shell
# 서비스 1 배포
assu@myserver01:~/work/ch09/ex14$ kubectl apply -f ingress01-deploy.yml
deployment.apps/ingress-deploy-test01 created
assu@myserver01:~/work/ch09/ex14$ kubectl apply -f ingress01-service.yml
service/ingress-service-test01 created

# 서비스 2 배포
assu@myserver01:~/work/ch09/ex14$ kubectl apply -f ingress02-deploy.yml
deployment.apps/ingress-deploy-test02 created
assu@myserver01:~/work/ch09/ex14$ kubectl apply -f ingress02-service.yml
service/ingress-service-test02 created
```

모든 파드와 서비스가 정상적으로 실행 중인지 확인한다.
```shell
^Cassu@myserver01:~/work/ch09/ex14$ kubect get all
NAME                                         READY   STATUS    RESTARTS   AGE
pod/ingress-deploy-test01-68d47df476-bf2kg   1/1     Running   0          5m56s
pod/ingress-deploy-test01-68d47df476-m9h8k   1/1     Running   0          5m56s
pod/ingress-deploy-test01-68d47df476-wsdrs   1/1     Running   0          5m56s
pod/ingress-deploy-test02-6c574cb47c-8xqhv   1/1     Running   0          5m42s
pod/ingress-deploy-test02-6c574cb47c-ntbxj   1/1     Running   0          5m42s
pod/ingress-deploy-test02-6c574cb47c-whr4p   1/1     Running   0          5m42s

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/ingress-service-test01   ClusterIP   10.107.58.239   <none>        80/TCP    5m49s
service/ingress-service-test02   ClusterIP   10.102.186.26   <none>        80/TCP    5m34s
service/kubernetes               ClusterIP   10.96.0.1       <none>        443/TCP   2d2h

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-deploy-test01   3/3     3            3           5m56s
deployment.apps/ingress-deploy-test02   3/3     3            3           5m42s

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-deploy-test01-68d47df476   3         3         3       5m56s
replicaset.apps/ingress-deploy-test02-6c574cb47c   3         3         3       5m42s
```

마지막으로 인그레스를 생성한다.

```shell
assu@myserver01:~/work/ch09/ex14$ kubectl apply -f ingress02-ingress.yml
ingress.networking.k8s.io/ingress-test02 created

assu@myserver01:~/work/ch09/ex14$ kubectl get ingress
NAME             CLASS   HOSTS   ADDRESS     PORTS   AGE
ingress-test02   nginx   *       10.0.2.20   80      32s
```

마찬가지로 `ADDRESS` 는 처음에 확인하면 안 나오고 약 1분정도 기다리면 나온다.  
`ADDRESS`에 MetalLB가 제공한 IP(10.0.2.20)가 할당된 것을 확인할 수 있다.

```shell
assu@myserver01:~/work/ch09/ex14$ kubectl get all --namespace mynginx
NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/nginx-ingress-controller-ingress-nginx-controller-79bdc88bq9qzp   1/1     Running   0          127m

NAME                                                                  TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/nginx-ingress-controller-ingress-nginx-controller             LoadBalancer   10.107.56.92    10.0.2.20     80:32038/TCP,443:32311/TCP   127m
service/nginx-ingress-controller-ingress-nginx-controller-admission   ClusterIP      10.107.71.139   <none>        443/TCP                      127m

NAME                                                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-ingress-controller-ingress-nginx-controller   1/1     1            1           127m

NAME                                                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-ingress-controller-ingress-nginx-controller-79bdc88b77   1         1         1       127m
```

---

**전체 트래픽 흐름 및 테스트**

지금까지의 전체적인 트래픽을 그림으로 나타내면 아래와 같다.

![인그레스로 두 개의 서비스 배포](/assets/img/dev/2025/1222/flow2.png)

**L7 로드밸런서(Ingress)**가 URL 경로를 분석하여 트래픽을 분기한다.

웹 브라우저(로컬 호스트)를 통해 접속 테스트를 진행한다.
- [http://127.0.0.1:2000/test01](http://127.0.0.1:2000/test01) → ingress-service-test01 연결 → Nginx 환영 페이지 출력
- [http://127.0.0.1:2000/test02](http://127.0.0.1:2000/test02) → ingress-service-test02 연결 → Nginx 환영 페이지 출력

두 주소 모두 동일한 Nginx 이미지를 사용했기에 화면은 같지만, 실제로는 서로 다른 파드로 라우팅 되고 있음을 알 수 있다.

---

생성했던 리소스들을 삭제하여 클러스터를 정리한다.

```shell
assu@myserver01:~/work/ch09/ex14$ kubectl delete -f ingress02-ingress.yml
ingress.networking.k8s.io "ingress-test02" deleted
assu@myserver01:~/work/ch09/ex14$ kubectl delete -f ingress01-service.yml
service "ingress-service-test01" deleted
assu@myserver01:~/work/ch09/ex14$ kubectl delete -f ingress02-service.yml
service "ingress-service-test02" deleted
assu@myserver01:~/work/ch09/ex14$ kubectl delete -f ingress01-deploy.yml
deployment.apps "ingress-deploy-test01" deleted
assu@myserver01:~/work/ch09/ex14$ kubectl delete -f ingress02-deploy.yml
deployment.apps "ingress-deploy-test02" deleted

assu@myserver01:~/work/ch09/ex14$ kubectl get ingress
No resources found in default namespace.

assu@myserver01:~/work/ch09/ex14$ kubectl get all
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   2d2h
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Doc:: Installing Helm](https://helm.sh/docs/intro/install/)
* [MetalLB](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-loadbalancer-for-bare-metal/)
* [strictARP](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-ipvs-strict-arp-deep-dive/)