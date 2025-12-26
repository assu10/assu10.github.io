---
layout: post
title:  "TroubleShooting - plugin type=calico failed (add): error getting ClusterInformation: connection is unauthorized: Unauthorized"
date: 2025-12-20
categories: dev
tags: trouble_shooting
---

# 내용
쿠버네티스 메니페스트를 통해 파드를 생성하는 중 파드의 상태가 READY 로 변경되지 않았다.




> 파드 실행 시 status 가 READY 로 변경되지 않으면  
> `kubectl describe pod 파드명` 을 실행하여 이벤트를 확인한다.  
> `plugin type="calico" failed (add): error getting ClusterInformation: connection is unauthorized: Unauthorized`  
> 이런 오류가 있다면 쿠버네티스 네트워크 플러그인(Calico) 인증 오류로 파드가 생성되지 못하는 것이다.
>
> 이 때는 Calico 관련 파드를 강제로 삭제하여 재시작하면 파드가 다시 생성되면서 새로운 인증 정보를 받아오게 된다.
>
> 먼저 Calico 파드가 있는 네임스페이스를 확인한다.  
> `kubectl get pods -A | grep calico`
>
> 이후 Calico Node 파드를 재시작한다.  
> `kubectl delete pod -n calico-system -l k8s-app=calico-node`



---

# 원인

쿠버네티스 네트워크 플러그인(Calico) 인증 오류로 파드가 생성되지 못하는 것이었다.  
이런 현상은 주로 Calico Node Pod 의 인증 토큰이 만료되었거나 일시적인 통신 오류로 인해 발생한다.

---

# 해결책

Calico 파드를 강제로 삭제하여 재시작하면 된다. 그러면 파드가 다시 생성되면서 새로운 인증 정보를 받아오게 된다.

1.  Calico 파드가 있는 네임스페이스를 확인한다.

```shell
$ kubectl get pods -A | grep calico

calico-apiserver   calico-apiserver-6c4c866f9f-hdvxh          1/1     Running   0            4d23h
calico-apiserver   calico-apiserver-6c4c866f9f-zl96c          1/1     Running   0            4d23h
calico-system      calico-kube-controllers-7f86844856-v785r   1/1     Running   0            3d20h
calico-system      calico-node-kq2rw                          0/1     Running   0            7s
calico-system      calico-node-t76dx                          0/1     Running   0            7s
calico-system      calico-node-wc4zx                          0/1     Running   0            7s
calico-system      calico-typha-674886f54f-dfmzp              1/1     Running   0            3d20h
calico-system      calico-typha-674886f54f-ff8ht              1/1     Running   0            3d20h
calico-system      csi-node-driver-cd58m                      2/2     Running   0            3d20h
calico-system      csi-node-driver-p6rs4                      2/2     Running   0            3d20h
calico-system      csi-node-driver-pxhnw                      2/2     Running   0            3d20h
```

이후 Calico 노드 파드를 재시작한다.

```shell
$ kubectl delete pod -n calico-system -l k8s-app=calico-node
```

잠시 후 파드 상태를 확인해보면 READY 상태로 변경된 것을 확인할 수 있다.

```shell
$ kubectl get pods -o wide
```