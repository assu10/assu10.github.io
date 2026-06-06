---
layout: post
title:  "사이드카 패턴(Sidecar Pattern)"
date: 2025-12-20
categories: dev
tags: backend kubernetes k8s design-pattern sidecar-pattern pod-architecture microservices container-logging service-mesh
---

MSA와 쿠버네티스 환경에서 파드는 배포의 최소 단위이다.  
보통 하나의 파드에 하나의 컨테이너를 두는 것이 일반적이지만, 때로는 하나의 파드 안에 여러 개의 컨테이너를 배치해야 하는 경우가 있다.

그 중 가장 대표적인 디자인 패턴이 **사이드카 패턴(Sidecar Pattern)**이다.

---

**목차**

<!-- TOC -->
* [사이드카 패턴(Sidecar Pattern)](#사이드카-패턴sidecar-pattern)
* [주요 활용사례](#주요-활용사례)
  * [로그 수집 및 가공(Log Aggregation)](#로그-수집-및-가공log-aggregation)
  * [서비스 메시 프록시(Service Mesh Proxy)](#서비스-메시-프록시service-mesh-proxy)
  * [설정 파일 동기화(Configuration Watcher)](#설정-파일-동기화configuration-watcher)
* [구현 예시(YAML)](#구현-예시yaml)
* [장단점](#장단점)
* [정리하며..](#정리하며)
<!-- TOC -->

---

# 사이드카 패턴(Sidecar Pattern)
Sidecar Pattern은 **메인 애플리케이션 컨테이너와 동일한 파드 내에 보조 컨테이너를 함께 배치하여 실행**하는 패턴이다.  
이 보조 컨테이너는 메인 컨테이너의 코드를 수정하지 않고도 기능을 확장하거나 보조하는 역할을 수행한다.

쿠버네티스 파드 내에 있는 컨테이너들은 **동일한 생명주기**를 가지며, **네트워크(IP)와 스토리지(Volume)를 공유**한다. Sidecar Pattern은 이 특성을 적극적으로 활용한다.

- **1 파드 = N 컨테이너**
  - 메인 컨테이너와 사이드카 컨테이너가 한 몸처럼 움직인다.
- **리소스 공유**
  - `localhost`를 통해 서로 통신할 수 있으며, 공유 볼륨을 통해 데이터를 주고 받을 수 있다.
- **독립성**
  - 메인 애플리케이션은 자신의 비즈니스 로직에만 집중하고, 로깅이나 프록시 설정 같은 부가 기능은 사이드카가 담당한다.

---

# 주요 활용사례

## 로그 수집 및 가공(Log Aggregation)

가장 흔한 사례이다. 메인 애플리케이션이 로그를 특정 파일에 기록하면, 사이드카 컨테이너(예: fluentd, logstash)가 그 파일을 읽어(tailing) 중앙 로그 저장소(Elasticsearch, Splunk 등)로 전송한다.

애플리케이션은 로그 전송 로직을 알 필요가 없으며, 다양한 언어로 된 앱들의 로그 수집 방식을 통일할 수 있다는 장점이 있다.

---

## 서비스 메시 프록시(Service Mesh Proxy)

Istio나 Linkerd와 같은 서비스 메시 기술의 핵심이다.

- **구조**
  - 메인 컨테이너로 들어오고 나가는 모든 네트워크 트래픽을 사이드카 컨테이너(예: Envoy Proxy)가 가로챈다.
- **역할**
  - 트래픽 관리, mTLS 보안 적용, 서킷 브레이커 등을 애플리케이션 코드 수정 없이 네트워크 레벨에서 처리한다.

---

## 설정 파일 동기화(Configuration Watcher)

메인 애플리케이션이 로컬 설정 파일을 읽어서 구동되는 경우, 사이드카 컨테이너가 원격 저장소(Git, S3 등)의 설정 변경을 감지하고 로컬 볼륨의 파일을 
최신 상태로 갱신해준다.

---

# 구현 예시(YAML)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-example
spec:
  volumes:
    - name: shared-logs
      emptyDir: {}

  containers:
    # 1. 메인 컨테이너 (애플리케이션)
    - name: main-app
      image: my-web-server:1.0
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/app
      # 로그를 파일로 기록한다고 가정

    # 2. 사이드카 컨테이너 (로그 수집기)
    - name: sidecar-logger
      image: busybox
      args: [/bin/sh, -c, 'tail -f /var/log/app/access.log']
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/app
```

---

# 장단점

**장점**

- **관심사 분리(Separation of Concerns)**
  - 비즈니스 로직과 인프라/운영 로직을 분리하여 코드의 유지보수성을 높인다.
- **재사용성**
  - 사이드카 컨테이너 이미지를 만들어두면, 다른 여러 애플리케이션 파드에 그대로 붙여서 재사용할 수 있다.
- **독립적인 업데이트**
  - 메인 앱을 재배포하지 않고도 사이드카(로그 수집기 버전 등)만 업데이트할 수 있다.

**단점**

- **복잡성 증가**
  - 관리해야 할 컨테이너 수가 늘어나고, 파드 명세가 길어진다.
- **리소스 오버헤드**
  - 파드 당 컨테이너가 늘어나므로 전체 클러스터의 리소스 사용량이 증가할 수 있다.
- **시작 시간 지연**
  - 파드 내의 모든 컨테이너가 준비되어야 트래픽을 받을 수 있으므로, 사이드카가 무거우면 전체 기동 시간이 느려질 수 있다.

---

# 정리하며..

사이드카 패턴은 **기존 컨테이너를 변경하지 않고 기능을 확장**할 수 있는 쿠버네티스 디자인 패턴이다.

- 메인 컨테이너와 **동일한 파드** 내에서 실행되며 네트워크와 스토리지를 공유한다.
- **로그 수집, 프록시, 데이터 갱신** 등의 보조 업무를 담당하여 메인 앱의 결합도를 낮춘다.
- 유지 보수성과 모듈성을 높여주지만, 리소스 사용량과 복잡성에 대한 고려가 필요하다.

MSA 환경에서 인프라 레벨의 공통 기능을 애플리케이션에서 분리하고 싶다면, 사이드카 패턴 도입을 고려해보는 것이 좋다.