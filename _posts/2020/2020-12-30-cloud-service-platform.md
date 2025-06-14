---
layout: post
title:  "클라우드 컴퓨팅, IaaS, PaaS, Serverless, SaaS"
date: 2020-12-30 10:00
categories: dev
tags: web network cloud-computing packaged-software iaas paas serverless aas
---

이 포스트는 웹 서비스 플랫폼에 관해 간략히 설명한다.

<!-- TOC -->
* [1. 클라우드 컴퓨팅](#1-클라우드-컴퓨팅)
* [2. 가상화와 클라우드 컴퓨팅의 차이](#2-가상화와-클라우드-컴퓨팅의-차이)
* [3. Packaged Software](#3-packaged-software)
* [4. IaaS (Infrastructure as a Service)](#4-iaas-infrastructure-as-a-service)
* [5. PaaS (Platform as a Service)](#5-paas-platform-as-a-service)
* [6. Serverless](#6-serverless)
* [7. FaaS (Function as a Service)](#7-faas-function-as-a-service)
* [8. SaaS (Software as a Service)](#8-saas-software-as-a-service)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 클라우드 컴퓨팅

서로 다른 물리적인 위치에 존재하는 컴퓨터들의 리소스를 가상화 기술로 통합하여 제공하는 기술.  
개인용 컴퓨터나 기업용 서버에 저장하던 문서를 클라우드에 저장하여 웹 애플리케이션을 이용하여 원하는 작업을 수행할 수 있는 환경.

예) 네이버 오피스, google docs 등

---


# 2. 가상화와 클라우드 컴퓨팅의 차이

가상화는 기술이고, 클라우드는 방법론

가상화는 VMware나 Virtualbox 와 같이 단일한 물리 하드웨어에서 여러 환경이나 자원을 생성할 수 있는 기술이고,  
클라우드 컴퓨팅은 네트워크, 스토리지 인프라 자원, 서비스, 애플리케이션 등을 사용자에게 제공하는 접근 방식.

가상화는 하드웨어에서 기능을 분리하는 기술이고,  
클라우드 컴퓨팅은 이렇게 분할된 기술을 사용하는 솔루션보다 큰 개념인 방법론.


---

# 3. Packaged Software

![Packaged Software](/assets/img/dev/2020/1230/packagedsw.png)

인프라와 플랫폼, 애플리케이션까지 모두 직접 구성/관리하는 모델.  
하드웨어, OS 설치, 네트워크 환경 구성, 서버 관리 등을 사용자가 다 준비해야 하기 때문에 큰 시간과 돈 소비.

---

# 4. IaaS (Infrastructure as a Service)

![IaaS](/assets/img/dev/2020/1230/iaas.png)
![IaaS](/assets/img/dev/2020/1230/iaas-1.png)

Infrastructure 레벨을 제공하는 서비스.  
사용자는 OS 를 직접 올리고 그 상위 계층만 구성.

즉, 사업자는 서버/네트워크/스토리지를 제공하고 사용자는 가상 서버에 필요한 프로그램을 설치하여 사용 및 운영 관리.

가상 호스팅과 비슷하지만, 가상 호스팅은 사용자가 직접 장비를 사서 그 장비 안에서 자원을 할당하고 구성하는 반면,  
IaaS 는 기업이 준비해놓은 환경에서 사용자가 선택.

관리 측면에서 개발자와 인프라 관리자의 역할 분담 가능.

> **관련 AWS 서비스**  
> EC2(컴퓨팅), VPC(네트워크), EBS(스토리지)

e.g.) AWS 의 EC2
사용자가 원하는 OS 와 스펙을 선택하면 모든 관리를 아마존에서 해 줌.  
기업이 클라우드를 운영하고 사용자는 EC2 서비스를 받음.

---

# 5. PaaS (Platform as a Service)

![PaaS](/assets/img/dev/2020/1230/paas.png)
![PaaS](/assets/img/dev/2020/1230/paas-1.png)

개발자가 응용 프로그램을 작성할 수 있도록 플랫폼 제공.

즉, 사업자는 개발에 필요한 미들웨어와 런타임을 제공하고 사용자는 그 미들웨어와 런타임 환경에서 개발에 집중.

운영팀이 인프라를 모니터링할 필요 없음.  
사용자는 애플리케이션 자체만 집중하므로 빠르게 개발하고 서비스 가능.

IaaS 와 차이점은 아마존과 같은 서비스가 VM 을 제공하는 IaaS 라면,  
PaaS 는 node.js, java 와 같은 런타임을 미리 깔아놓고 거기서 소스코드를 넣어서 돌리는 구조.

이미 설치된 미들웨어 위에 코드만 돌리므로 관리가 편함

PaaS 는 기본적으로 애플리케이션과 플랫폼이 함께 제공되기 때문에 애플리케이션이 플랫폼에 종속되어 다른 플랫폼으로의 이동이 어려울 수 있음

> **관련 AWS 서비스**  
> AWS Elastic Beanstalk(애플리케이션 배포)

예) Heroku, google App engine, IBM Bluemix, OpenShift, SalesForce

---

# 6. Serverless

![Serverless](/assets/img/dev/2020/1230/serverless.png)

'서버가 없는 컴퓨팅' 이라는 표현은 오해의 소지가 있다.  
사실은 서버는 존재하지만, 그 관리를 직접 하지 않아도 된다는 의미이다.

<**Serverless 핵심**>
- **서버 관리**
  - 클라우드 벤더가 수행
- **과금 기준**
  - 항상 실행되는 서버가 아닌 실제 실행 시간 기준 과금
- **개발자 책임**
  - 서버 프로비저닝, 스케일링, 유지보수 불필요
- **인프라 종류**
  - DB, 메시징, 인증 등도 포함한 광범위한 서비스형 인프라(IaaS)

<br />

<**Serverless 장점**>
- 인프라 관리 부담없이 빠른 서비스 구축 가능
- 이벤트 기반 설계에 적합 (예: S3 업로드 → Lambda 트리거)
- 자원 효율적 (요청이 없을 땐 비용 없음)
- 개발자는 비즈니스 로직에만 집중 가능

> **관련 AWS 서비스**  
> Lambda(컴퓨팅), API GW(API 프록시)

---

# 7. FaaS (Function as a Service)

FaaS 는 서버리스 환경에서 실제 함수 단위로 로직을 실행하는 방식이다.  
각 FaaS 는 하나의 메서드 또는 프로시저 수준의 작은 단위로 구성된다.

<**동작 방식**>
- 이벤트(HTTP 요청, Kafka 메시지, S3 업로드 등)가 트리거
- 입력을 받아 함수를 실행
- 필요 시 결과를 반환하거나 DB 에 저장

<br />

<**함수형 프로그래밍 관점에서 본 FaaS**>
- 순수 함수처럼 동작 가능
  - 입력 → 연산 → 출력
  - 외부 상태없이 동작 가능 (DB 읽기/쓰기 불필요)
- 하지만 실제 시스템에서는 아래도 가능
  - DB 에서 읽거나
  - DB 에 쓰기도 함 (이때는 side-effect 존재)

<br />

FaaS 는 "입력 기반으로 계산을 수행하는 작은 단위의 로직"이며, 이를 통해 이벤트 기반 메시지 처리를 구현할 수 있다.

Serverless 는 컴퓨팅, 스토리지, DB, 메시징, API 게이트웨이 등 서버의 구성/관리/과금이 최종 사용자에게 보이지 않는 모든 서비스 범주에 초점을 맞추고 있는 반면, 
FaaS 는 Serverless 아키텍처에서 핵심적인 기술이지만 애플리케이션 코드가 이벤트나 요청에 대한 응답으로만 실행되는 이벤트 중심 컴퓨팅 패러다임에 중점을 두고 있다.

---

# 8. SaaS (Software as a Service)

![SaaS](/assets/img/dev/2020/1230/saas.png)
![SaaS](/assets/img/dev/2020/1230/saas-1.png)

설치할 필요도 없이 클라우드를 통해 제공되는 소프트웨어.

퍼블릭 클라우드에 있는 소프트웨어를 웹 브라우저로 불러와 언제 어디서나 사용 가능.  
사용자는 웹만 접속하면 되므로 사용하기 쉽고, 최신 소프트웨어를 빠르게 제공받을 수 있음

SaaS 특성 상 반드시 인터넷에 접속이 가능해야 하고, 외부에 데이터 노출 리스트가 있음

예) 웹 메일, 구글 클라우드, 네이버 클라우드, MS오피스 365, 드롭박스

---

# 참고 사이트 & 함께 보면 좋은 사이트
* [클라우드 컴퓨팅, IaaS, PaaS, SaaS이란?](https://wnsgml972.github.io/network/2018/08/14/network_cloud-computing/)
* [따라하며 배우는 AWS 네트워크 입문](http://www.yes24.com/Product/Goods/93887402)
* [FaaS(Function-as-a-Service)란?](https://www.ibm.com/kr-ko/topics/faas)