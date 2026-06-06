---
layout: post
title:  "MetalLB Layer 2 모드 설정: CRs(IPAddressPool, L2Advertisement)"
date: 2025-12-22
categories: dev
tags: kubernetes k8s metallb load-balancer custom-resource custom-resource-definition crd ip-address-pool l2-advertisement layer-2-mode
---

CRs(Custom Resources, 사용자 정의 리소스) 혹은 CR(Custom Resource)은 쿠버네티스 API를 확장하여 사용자가 직접 정의한 리소스 타입을 의미한다.

쿠버네티스는 기본적으로 `Pod`, `Service`, `Deployment`와 같은 빌트인 리소스를 제공한다.  
하지만 특정 애플리케이션이나 오퍼레이터가 자신만의 설정이나 상태를 관리해야 할 때, 기본 리소스만으로는 부족할 수 있다.  
이 때 **CRD(Custom Resource Definition)**를 통해 새로운 리소스 타입을 정의하고, 이를 기반으로 생성한 인스턴스가 바로 **CR**이다.

쉽게 말해서 **쿠버네티스 스타일로 만든 개인 전용 설정 파일**이라고 이해하면 된다.

---

**목차**

<!-- TOC -->
* [MetalLB가 CR을 사용하는 이유](#metallb가-cr을-사용하는-이유)
* [MetalLB 설정의 핵심 CRs](#metallb-설정의-핵심-crs)
  * [IPAddressPool](#ipaddresspool)
  * [L2Advertisement](#l2advertisement)
* [CR과 CRD의 관계](#cr과-crd의-관계)
* [정리하며..](#정리하며)
<!-- TOC -->

---

# MetalLB가 CR을 사용하는 이유

과거의 MetalLB(v0.12 이전)는 `ConfigMap`을 사용하여 설정을 관리했다. 하지만 현재 버전에서는 **CRD 기반의 설정**을 권장한다. 그 이유는 다음과 같다.

- **유효성 검사**
  - CRD 스키마를 통해 IP 형식이 올바른지, 필수값이 있는지 API 서버 레벨에서 미리 검증 가능
- **동적 적용**
  - 설정을 변경했을 때 MetalLB 컨트롤러가 이를 즉시 감지하고 반영하기가 훨씬 수월함
- **k8s 네이티브**
  - `kubectl get ipaddresspool`과 같이 쿠버네티스 표준 명령어를 사용하여 설정을 조회하고 관리할 수 있음

---


# MetalLB 설정의 핵심 CRs

MetalLB를 구성하기 위해 주로 다루게 되는 핵심 CR은 2가지가 있다.

---

## IPAddressPool

MetalLB가 로드밸런서 서비스에 할당할 **IP 주소의 범위(Pool)**를 정의하는 리소스이다.

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: mymetallb
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
```

---

## L2Advertisement

정의된 IP 주소 풀을 네트워크에 어떻게 알릴지(Advertisement) 설정하는 리소스이다.  
Layer 2 모드(ARP 사용)로 동작할지, BGP 모드로 동작할지 결정하는 역할을 수행한다.

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: mymetallb
spec:
  ipAddressPools:
  - first-pool
```

---

# CR과 CRD의 관계

- **CRD(Custom Resource Definition)**
  - 붕어빵 틀과 같다. 'IPAddressPool'이라는 리소스는 `addresses`라는 필드를 가져야 한다'라고 정의한다.
  - MetalLB 설치 시(Helm 차트 내 포함) 이미 클러스터에 등록되었다.
- **CR(Custom Resource)**
  - 붕어빵 틀로 찍어낸 실제 붕어빵이다. 사용자가 작성하는 YAML 파일이 여기에 해당한다.
  - `kubectl api-resources | grep metallb` 명령어를 입력하면 현재 클러스터에 등록된 MetalLB 관련 CRD 목록을 확인할 수 있다.
     설치 메시지에서 "Now you can configure it via its CRs"라고 나오는 것은 이제 이 틀(CRD)에 맞춰 내용(CR)을 채워넣으라는 의미이다.

---

# 정리하며..
- **CR(Custom Resource)**은 쿠버네티스의 기능을 확장하여 특정 애플리케이션(여기서는 MetalLB) 전용 설정을 관리하는 방식이다.
- MetalLB 설치 후 메시지에서 말하는 CRs 설정은 **"어떤 IP 대역을 사용할 것인가(IPAddressPool)"**와 **"어떻게 통신할 것인가(L2Advertisement)"**를 정의하는 YAML 파일을 작성하여 적용하라는 의미이다.
- 이를 통해 MetalLB는 `<pending>` 상태인 로드밸런서 서비스에 실제 IP를 부여할 수 있게 된다.