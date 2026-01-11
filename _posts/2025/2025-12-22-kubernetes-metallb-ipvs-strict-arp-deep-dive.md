---
layout: post
title:  "strictARP"
date: 2025-12-22
categories: dev
tags: kubernetes k8s metallb load-balancer ipvs kube-proxy strict-arp arp-ignore arp-announce bare-metal-network
---

`strictARP`는 쿠버네티스 환경, 특히 [**MetalLB**](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-loadbalancer-for-bare-metal/)와 같은 로드밸런서를 온프레미스(Bare Metal) 환경에서 **IPVS 모드**의 `kube-proxy`와 함께 
사용할 때 짚고 넘어가야 하는 부분이다.

`strictARP`는 쿠버네티스 클러스터의 네트워크 프록시인 `kube-proxy`의 설정 옵션 중 하나이다.  
이 설정을 활성화(true)하면, 리눅스 커널의 ARP(Address Resolution Protocol) 동작 방식인 `arp_ignore`와 `arp_announce` 값을 수정하여, 
**물리 인터페이스가 자신이 보유하지 않은 IP 주소(예: LoadBalancer의 ExternalIP)에 대한 ARP 요청에 응답하지 않도록 제한**한다.

쉽게 말해서 '이 IP는 본인이 진짜 주인일 때만 응답하겠다'라고 커널을 엄격하게 단속하는 설정이며, 주로 MetalLB가 ARP 응답을 전담해야 할 때 충돌을 방지하기 위해 사용한다.

---

**목차**

<!-- TOC -->
* [`strictARP`가 필요한 이유](#strictarp가-필요한-이유)
* [`strictARP`의 동작 원리(Kernel Sysctl)](#strictarp의-동작-원리kernel-sysctl)
* [설정 밥법 및 코드 예시](#설정-밥법-및-코드-예시)
* [장점](#장점)
* [주의 사항](#주의-사항)
* [정리하며..](#정리하며)
<!-- TOC -->

---

# `strictARP`가 필요한 이유

쿠버네티스 서비스 프록시 모드를 **IPVS(IP Virtual Server)**로 설정하고, 온프레미스 로드밸런서인 **MetalLB**를 Layer 2 모드로 사용할 때 문제가 발생할 수 있다.

- **IPVS의 동작**
  - `kube-proxy`가 IPVS 모드일 때, 서비스의 [ClusterIP](https://assu10.github.io/dev/2025/12/08/kubernetes-service-concept-and-types/#2-clusterip)나 LoadBalancer IP는 노드의 가상 인터페이스(주로 `kube-ipvs`)에 할당된다.
- **커널의 기본 동작**
  - 리눅스 커널은 기본적으로 깐깐하지 않다. 어떤 인터페이스로 ARP 요청이 들어오든, 그 IP가 내 노드 어딘가에(예: `kube-ipvs0`)에 있다면 본인에게 있는 IP라고 판단하여 물리 인터페이스(예: `eth0`)가 대신 응답해버릴 수 있다.
- **충돌 발생**
  - MetalLB는 특정 노드 하나가 리더가 되어 '내가 그 LoadBalancer의 주인이다'라고 ARP 응답을 보내려 한다.
  - 그런데 커널이 모든 노드에서 ARP 응답을 보내버리면, 라우터는 혼란에 빠져서 트래픽이 분산되지 않거나 끊기는 현상이 발생한다.

---

# `strictARP`의 동작 원리(Kernel Sysctl)

`kube-proxy` 설정에서 `strictARP: true`를 적용하면, 실제로는 해당 노드의 물리 인터페이스에 대해 리눅스 커널 파라미터(`sysctl`) 두 가지를 수정한다.
- `arp_ignore = 1`
  - 자신이 ARP 요청을 받은 인터페이스에 설정된 IP에 대해서만 응답함
  - 즉, `eth0`으로 들어온 요청인데 IP가 `kube-ipvs0`에만 있다면 응답하지 않고 무시함
- `arp_announce = 2`
  - ARP 요청을 보낼 때, 보내는 인터페이스(`eth0`)의 서브넷에 맞는 소스 IP만 사용하도록 강제함

이 조치를 통해 커널이 불필요하게 ARP 응답을 하는 것을 막고, **ARP 응답의 권한을 온전히 사용자 공간(User Space)의 애플리케이션인 MetalLB에게 넘겨주는 것**이다.

---

# 설정 방법 및 코드 예시

`strictARP`는 `kube-proxy`의 ConfigMap을 수정하여 적용한다.

```shell
# kube-proxy 설정 수정
kubectl edit configmap -n kube-system kube-proxy
```

ConfigMap 내용(YAML)
```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"  # 반드시 IPVS 모드여야 함
ipvs:
  strictARP: true  # 이 값을 false에서 true로 변경
  # ... 기타 설정
```

위 설정을 변경한 후 `kube-proxy` 파드를 재시작하거나, 롤아웃을 적용해야 한다.  
MetalLB 설치 전 사전 작업으로 수행하는 것이 일반적이다.

---

# 장점

- **네트워크 안정성**
  - MetalLB Layer 2 모드에서 다중 노드가 동일한 VIP에 대해 ARP 응답을 보내는 `ARP Flap` 현상을 근본적으로 차단함
- **명확한 역할 분담**
  - 커널과 MetalLB 간의 역할 충돌 방지

---

# 주의 사항

- **IPVS 모드 종속**
  - 이 설정은 `kube-proxy`가 `iptables` 모드일 때는 해당되지 않거나 동작 방식이 다르다. (MetalLB 문서에는 IPVS 사용 시 필수라고 명시)
- **기존 네트워크 영향**
  - 매우 드물지만, 커널의 ARP 동작을 엄격하게 제한하므로, 복잡한 커스텀 네트워크 라우팅을 사용하는 노드에서는 사이드 이펙트가 없는지 확인이 필요하다.

---

# 정리하며..

`strictARP`는 쿠버네티스 베어메탈 환경에서 **IPVS 모드**와 **MetalLB**를 함께 사용할 때, 네트워크 통신의 교통 정리를 담당하는 핵심 설정이다.

리눅스 커널이 모든 IP에 대해 ARP 응답을 하지 못하도록 `arp_ignore`와 `arp_announce`를 엄격하게 조정함으로써, **MetalLB가 LoadBalancer IP에 대한 트래픽을 
온전히 제어할 수 있도록 보장**한다.  
안정적인 온프레미스 서비스 운영을 위해서는 `strictARP` 설정을 꼭 활성화하는 것을 권장한다.