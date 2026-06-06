---
layout: post
title:  "MetalLB"
date: 2025-12-22
categories: dev
tags: kubernetes k8s metallb load-balancer bare-metal layer2 bgp on-premise networking external-ip
---

MetalLB는 클라우드 공급자(AWS, GCP, Azure 등)가 제공하는 로드밸런서 기능이 없는 **베어메탈(Bare Metal) 환경의 쿠버네티스 클러스터를 위해 만들어진 로드밸런서 구현체**이다.

표준 라우팅 프로토콜(ARP, BGP)을 사용하여, 쿠버네티스 서비스(Service) 중 `type: LoadBalancer`에 외부 접속 가능한 IP(External IP)를 할당하고 
외부 트래픽을 클러스터 내부로 끌어오는 역할을 한다.

---

**목차**

<!-- TOC -->
* [`MetalLB`가 필요한 이유](#metallb가-필요한-이유)
* [주요 요소](#주요-요소)
* [두 가지 동작 모드](#두-가지-동작-모드)
  * [Layer 2 모드(ARP/NDP)](#layer-2-모드arpndp)
  * [BGP 모드(Border Gateway Protocol)](#bgp-모드border-gateway-protocol)
* [트래픽 흐름](#트래픽-흐름)
* [정리하며..](#정리하며)
<!-- TOC -->

---

# `MetalLB`가 필요한 이유

쿠버네티스를 AWS와 같은 퍼블릭 클라우드에서 사용할 때, 서비스 타입을 `LoadBalancer`로 지정하면 클라우드 공급자가 자동으로 외부 IP를 가진 로드밸런서를 생성해준다.

하지만 **베어메탈(온프레미스) 환경**에서는 어떨까?
- **현상**
  - `External-IP` 상태가 영원히 `<pending>` 상태로 멈춰있다.
- **이유**
  - 쿠버네티스 자체에는 로드밸런서를 구현하는 기능이 포함되어 있지 않기 때문이다.
  - 쿠버네티스는 로드밸런서가 필요하다고 요청만 할 뿐, 실제 IP를 주고 연결해 줄 주체가 베어메탈에는 없다.

MetalLB는 베어메탈에서도 클라우드처럼 `LoadBalancer` 서비스를 즉시 사용할 수 있게 해준다.

---

# 주요 요소

MetalLB는 크게 두 가지 요소로 구성되어 파드 형태로 실행된다.

- **Controller**
  - 설정된 IP pool에서 어떤 IP를 서비스에 할당할 지 결정하고 관리한다.
  - 즉, IP 자원 관리자이다.
- **Speaker**
  - 각 노드마다 실행(DaemonSet)되며, 할당된 IP를 네트워크 상에서 알리는(Advertising) 역할을 한다.
  - '이 IP의 주인은 나(노드)야'라고 라우터에게 알려서 트래픽을 유도한다.

---

# 두 가지 동작 모드

MetalLB는 네트워크 환경에 따라 두 가지 모드 중 하나를 선택하여 동작한다.

---

## Layer 2 모드(ARP/NDP)

- **동작 방식**
  - 클러스터 노드 중 하나가 리더가 되어 로드밸런서 IP에 대한 ARP 요청에 응답한다.
  - 이 때 [`strictARP`](https://assu10.github.io/dev/2025/12/22/kubernetes-metallb-ipvs-strict-arp-deep-dive/) 설정이 충돌 방지를 위해 사용된다.
- **장점**
  - 특별한 네트워크 장비 설정 없이 공유기 수준의 환경에서도 즉시 사용 가능하다. 설정이 가장 쉽다.
- **단점**
  - 리더 노드 한 곳으로만 트래픽이 몰린다. (단일 노드 대역폭 제한)
  - 리더가 죽으면 다른 노드가 리더가 되기까지 짧은 끊김이 발생한다.

---

## BGP 모드(Border Gateway Protocol)

- **동작 방식**
  - 라우터와 직접 BGP 피어링을 맺고 라우팅 정보를 교환한다.
- **장점**
  - 진정한 로드밸런싱이 가능하다.
  - 라우터가 여러 노드로 트래픽을 분산(ECMP)하여 보내준다. 대역폭 한계가 노드 수만큼 늘어난다.
- **단점**
  - BGP를 지원하는 고가/고기능의 라우터가 필요하며, 네트워크 설정이 복잡하다.

---

# 트래픽 흐름

- 사용자가 `Service (type: LoadBalancer)` 생성 요청
- MetalLB Controller가 설정된 범위(예: 192.168.1.200~240)내에서 IP 하나를 할당
- MetalLB Speaker가 해당 IP를 네트워크에 알림(Layer 2 모드라면 ARP 응답)
- 외부 사용자가 해당 IP로 접속하면, 라우터가 MAC 주소를 확인하고 해당 노드로 트래픽 전송
- 노드의 `kube-proxy` (IPVS/iptables)가 받아서 최종 파드로 전달

---

# 정리하며..

MetalLB가 없다면 온프레미스 쿠버네티스에서 외부 통신을 위해 
[`NodePort`](https://assu10.github.io/dev/2025/12/08/kubernetes-service-concept-and-types/#3-nodeport)나 
`Ingress`만을 제한적으로 사용해야 하는 불편함이 있다.  
MetalLB를 통해 비로소 베어메탈 클러스터도 클라우드와 동일한 수준의 **네트워크 유연성**을 갖추게 된다.  
특히 **Layer 2 모드**는 복잡한 장비 없이도 누구나 쉽게 구축할 수 있어 홈랩이나 중소규모 온프레미스 환경의 표준으로 자리잡았다.