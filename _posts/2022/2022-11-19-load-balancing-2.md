---
layout: post
title:  "AWS - Load Balancing (2): Route 53"
date:   2022-11-19 10:00
categories: dev
tags: devops aws load-balancing route53 dns
---

이 포스트는 AWS 의 관리형 DNS 서비스인 Route 53 에 대해 알아본다.

> - [DNS](#1-dns-domain-name-system)
> - [Route 53](#2-route-53)
>   - [Route 53 라우팅 정책](#21-route-53-라우팅-정책)
>   - [도메인 이름 생성](#22-도메인-이름-생성)
> - [Route 53 구성 테스트](#3-route-53-구성-테스트)
>   - [기본 환경 구성](#31-기본-환경-구성)
>   - [Route 53 과 ALB 연결](#32-route-53-과-alb-연결)
>   - [Route 53 장애 조치 라우팅 정책](#33-route-53-장애-조치-라우팅-정책)
>   - [Resource 삭제](#34-resource-삭제)

---

아래는 이번 포스트에서 다뤄볼 범위 도식화이다.

![이번 포스트 범위 도식화](/assets/img/dev/2022/1119/1119_design.png)

# 1. DNS (Domain Name System)

DNS 는 복잡한 주소 체계를 문자 형태의 domain name 으로 매핑하여 연결하는 서비스이다.

DNS 를 통해 서비스 수행 시 DNS 서버가 필요한데, **DNS 서버는 4개 유형**으로 분류된다.

- **DNS 해석기 (DNS Resolver)**
  - 클라이언트와 네임 서버의 중계자 역할
  - DNS 요청에 대해 네임 서버로 전달
  - DNS 응답을 클라이언트에게 전달
- **루트 네임 서버 (Root Name Server)**
  - DNS 서버의 최상위 네임 서버
  - DNS 해석기에서 발생한 DNS 요청에 대해 TLD 도메인 (`.com`) 에 해당하는 TLD 네임 서버 정보 반환
  - e.g.) `.`
- **TLD 네임 서버 (Top Level Domain Name Server)**
  - `.com` 과 같은 최상위 도메인에 대한 네임 서버
  - 해당 영역에 포함되는 모든 모데인 이름의 정보 유지
  - DNS 요청에 대해 `google.com` 에 대한 권한 있는 네임 서버 주소 반환
  - e.g.) `.com`
- **권한있는 네임 서버 (Authoritative Name Server)**
  - DNS 해석기가 TLD 네임 서버로부터 응답을 받으면 확인자는 해당 응답을 권한 있는 네임 서버로 보냄
  - 권한 있는 네임 서버는 요청하는 도메인 주소에 대한 IP 주소를 확인하여 반환
  - e.g.) `google.com`


도메인에 관한 설정을 하기 위해 사용되는 문자들인 **DNS 레코드** 는 아래와 같은 유형으로 나뉜다.

- `A`: IPv4 주소 매핑
- `AAAA`: IPv6 주소 매핑
- `CNAME`: 도메인 이름의 별칭을 만듦
- `NS`: 도메인 네임 서버 식별
- `SOA`: 도메인 영역 표시
- `MX`: 이메일 서버 지정
- `SRV`: 도메인 서비스 이용 가능여부 식별
- `TXT`: 텍스트 매핑

---

# 2.  Route 53

Route 53 은 AWS 에서 제공하는 관리형 DNS 서비스이다.

Route 53 을 이용하여 도메인 이름을 구매하고, 구매한 도메인 주소에 대한 호스팅 영역을 생성하여 네임 서버를 구축하고,
레코드를 생성하여 DNS 요청에 대한 응답을 처리한다. 또한, 다양한 라우팅 정책을 수립하여 효율적인 트래픽 흐름을 보장한다.

**Route 53 의 구조**는 아래와 같다.

- **도메인 이름 등록**
  - Route 53 이 등록대행소가 되어 등록소인 TLD 네임 서버에 전파하여 해당 도메인명을 사용할 수 있도록 함
- **호스팅 영역**
  - DNS 관리를 할 수 있는 호스팅 영역 생성 (기본적으로 Route 53 을 통해 도메인명 등록 시 자동으로 생성됨)
  - 호스팅 영역이 생성되면 네임 서버가 생성되어 DNS 요청에 대한 DNS 응답 반환
- **레코드**
  - 생성한 호스팅 영역에 레코드 작성 가능하며, 레코드 생성 시 라우팅 정책 수립 가능


**Route 53 의 주요 기능**은 아래와 같다.
- 도메인 등록
- 리소스 상태/성능/지표 모니터링
- DNS 장애 조치
  - 서비스 중단이 발생하지 않도록 대체 가능한 경로로 자동 라우팅
- 다양한 라우팅 정책
- Alias
  - AWS 서비스의 도메인명에 대한 별칭을 지정하여 ELB, CloudFront, S3 등의 도메인과 매핑  
    (뒤의 [3.2. Route 53 과 ALB 연결](#32-route-53-과-alb-연결) 에서 테스트)
- Route 53 Resolver
  - 조건부 전달 규칙 및 DNS 엔드포인트를 생성하여 Route 53 Private 호스팅 영역 (Private Hosted Zones) 과 on-premise DNS 서버 간에 도메인 질의
- VPC용 Private DNS
  - DNS 데이터를 Public 인터넷에 노출하지 않고 내부 AWS 리소스에 대한 사용자 지정 도메인명 관리

> Route 53 Resolver 에 대한 상세한 내용은 [AWS - Network 연결 옵션 (4): Route 53 DNS Resolver (DNS 해석기)](https://assu10.github.io/dev/2023/01/07/network-4/) 를 참고하세요.


![DNS 통신 흐름](/assets/img/dev/2022/1119/route53_1.png)

① google.com 도메인 주소에 대해 Route 53 을 이용하여 등록.  
도메인 주소는 등록소의 TLD 네임 서버에 기록되고, www.google.com 의 IPv4 주소에 대한 A 레코드 구성  
② 클라이언트는 www.google.com 도메인에 대한 DNS 질의  
③ DNS 질의를 받은 DNS Resolver 는 Root 네임 서버로 전달.  
Root 네임 서버는 TLD 도메인(.com) 에 해당하는 TLD 네임 서버 주소 반환  
④ DNS Resolver 는 .com TLD 네임 서버로 다시 DNS 질의.  
TLD 네임 서버는 google.com 에 해당하는 권한있는 네임 서버 주소 반환  
⑤ DNS Resolver 는 google.com 에 대항하는 권한있는 네임 서버로 다시 DNS 질의.  
권한있는 네임 서버는 google.com 에 매핑된 IPv4 반환  
⑥ DNS Resolver 는 클라이언트로 IPv4 응답  
⑦ 클라이언트는 응답받은 www.google.com 에 대한 IPv4 로 접근하여 통신

---

## 2.1. Route 53 라우팅 정책

레코드 생성 시 라우팅 정책을 지정하는데, 라우팅 정책이랑 DNS 요청에 대한 응답 방식을 말한다.

- **단순 라우팅 (Simple Routing)**
  - 도메인에 대해 하나의 리소스 지정
  - 레코드에 대한 값은 여러 개 입력 가능하며, 그 중 하나의 값만 랜덤하게 응답
- **장애 조치 라우팅 (Failover Routing)**
  - Active/Passive 장애 조치 구성 시 사용
  - 레코드값 중 Active 를 지정하고, 주기적인 상태 확인을 통해 Active 가 통신 불가인 경우 Passive 를 Active 로 변경하여 라우팅 
- **가중치 기반 라우팅 (Weighted Routing)**
  - 도메인에 대해 다수의 리소스 지정하고 값에 대한 비중을 지정하여 라우팅
  - 가중치값은 0~255 사이로 설정 (0이면 DNS 응답 하지 않음)
- **지연 시간 기반 라우팅 (Latency Routing)**
  - 여러 AWS 리전에 리소스가 있을 때 최상의 지연 시간을 제공하는 리전으로 라우팅
- **지리 위치 라우팅 (Geolocation Routing)**
  - DNS 질의를 하는 사용자의 DNS 서버 IP 위치를 기반하여 가장 인접한 리전의 리소스 대상으로 라우팅
- **지리 근접 라우팅 (Geoproximity Routing)**
  - 지리 위치 라우팅과 동일한 형태이며, Bias 값을 조정하여 근접 영역의 영향도 조정
- **다중값 응답 라우팅 (Multi-value Answer Routing)**
  - Route 53 이 DNS 질의에 대해 다수의 값을 반환하도록 구성 (최대 8개)

---

## 2.2. 도메인 이름 생성

Route 53 이용을 하려면 도메인이 필요하다. (도메인 이름을 생성하고 호스팅 영역에 등록 시 과금)

도메인을 Route 53 을 도메인 등록 대행소로 활용하거나 무료 DNS 제공 사이트를 도메인 등록 대행소로 활용하여 생성할 수 있다.  
본 포스트에선 Route 53 을 도메인 등록 대행소로 활용한다.

> 무료 DNS 제공 사이트를 이용하는 경우는 [Freenom 무료DNS 생성 후 Route 53 호스팅 영역 연결](https://www.notion.so/ongja/CNBA52-Freenom-DNS-Route-53-aa8bc62b89704555b7ba09dd7465cbc6) 를 참고하세요.  
> 생성한 도메인 이름에 대해 Route 53 에서 호스팅 영역을 생성하여 관리할 수 있습니다.  
> 도메인 생성은 무료이지만 Route 53 에서 최초 호스팅 영역 생성 시 과금 발생 ($0.5)

> Route 53 을 통한 도메인 이름 생성의 자세한 내용은 [Route 53 도메인 이름 등록](https://aws.amazon.com/ko/getting-started/hands-on/get-a-domain/) 의 
*2단계: 도메인 이름 등록* 를 참고하세요.

*[Route 53] - [Domains] - [Registered domains] - [Register Domain]*

아래 그림처럼 원하는 도메인 입력 후 최상위 도메인(TLD) 를 선택한다. (e.g. .com, .org...)
![Route 53 Domain 생성(1)](/assets/img/dev/2022/1119/route53_2.png)

이 후 발송되는 이메일의 링크를 클릭하여 이메일 주소 확인을 한다.

*[Route 53] - [Domains] - [Registered domains]* 와 *[Route 53] - [Hosted zones]* 에서 등록된 도메인과 호스팅 영역을 확인한다.

---

# 3. Route 53 구성 테스트

Route 53 의 도메인을 활용하여 ALB 과 연결해보고, 장애 조치 라우팅 정책을 적용하여 Failover 환경을 구성해본다.

- 기본 환경 구성
  - CloudFormation 적용
  - CloudFormation 을 통해 생성된 자원 확인
  - 기본 통신 환경 검증
- Route 53 과 ALB 연결
  - Route 53 레코드 생성 (단순 라우팅)
  - Route 53 단순 라우팅 검증
- Route 53 장애 조치 라우팅 정책
  - Route 53 레코드 생성 (장애 조치 라우팅)
  - Route 53 장애 조치 라우팅 검증
  - Route 53 으로 AWS 자원이 아닌 다른 대상 연결
- Resource 삭제

![목표 구성도](/assets/img/dev/2022/1119/route53_flow.png)

---

## 3.1. 기본 환경 구성

- CloudFormation 적용
- CloudFormation 을 통해 생성된 자원 확인
- 기본 통신 환경 검증

![기본 환경 구성도](/assets/img/dev/2022/1119/route53_3.png)

---

### 3.1.1. CloudFormation 적용

*[CloudFormation] - [Stacks]*

[CloudFormation Template Download](http://bit.ly/cnbl0501)

<details markdown="1">
<summary>CloudFormation Template (펼쳐보기)</summary>

```yaml
Parameters:
  KeyName:
    Description: Name of an existing EC2 KeyPair to enable SSH access to the instances. Linked to AWS Parameter
    Type: AWS::EC2::KeyPair::KeyName
    ConstraintDescription: must be the name of an existing EC2 KeyPair.
  LatestAmiId:
    Description: (DO NOT CHANGE)
    Type: 'AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>'
    Default: '/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2'
    AllowedValues:
      - /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2

Resources:
  MyVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.10.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: jhMy-VPC

  MyIGW:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: jhMy-IGW

  MyIGWAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref MyIGW
      VpcId: !Ref MyVPC

  MyPublicRT:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref MyVPC
      Tags:
        - Key: Name
          Value: jhMy-Public-RT

  MyDefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: MyIGWAttachment
    Properties:
      RouteTableId: !Ref MyPublicRT
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref MyIGW

  MyPublicSN1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MyVPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: 10.10.0.0/24
      Tags:
        - Key: Name
          Value: jhMy-Public-SN-1

  MyPublicSN2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MyVPC
      AvailabilityZone: !Select [2, !GetAZs '']
      CidrBlock: 10.10.1.0/24
      Tags:
        - Key: Name
          Value: jhMy-Public-SN-2

  MyPublicSNRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref MyPublicRT
      SubnetId: !Ref MyPublicSN1

  MyPublicSNRouteTableAssociation2:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref MyPublicRT
      SubnetId: !Ref MyPublicSN2

  WEBSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Enable HTTP access via port 80 and SSH access via port 22
      VpcId: !Ref MyVPC
      Tags:
        - Key: Name
          Value: jhWEBSG
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: '80'
          ToPort: '80'
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: '22'
          ToPort: '22'
          CidrIp: 0.0.0.0/0

  MYEC21:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref LatestAmiId
      KeyName: !Ref KeyName
      Tags:
        - Key: Name
          Value: jhEC2-1
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref MyPublicSN1
          GroupSet:
            - !Ref WEBSG
          AssociatePublicIpAddress: true
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          hostname jhEC2-1
          yum install httpd -y
          service httpd start
          chkconfig httpd on
          echo "<h1>CloudNet@ jhEC2-1 Web Server</h1>" > /var/www/html/index.html

  MYEC22:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref LatestAmiId
      KeyName: !Ref KeyName
      Tags:
        - Key: Name
          Value: jhEC2-2
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref MyPublicSN2
          GroupSet:
            - !Ref WEBSG
          AssociatePublicIpAddress: true
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          hostname jhEC2-2
          yum install httpd -y
          service httpd start
          chkconfig httpd on
          echo "<h1>CloudNet@ jhEC2-2 Web Server</h1>" > /var/www/html/index.html

  MyEIP1:
    Type: AWS::EC2::EIP
    Properties:
      Domain: vpc

  MyEIP1Assoc:
    Type: AWS::EC2::EIPAssociation
    Properties:
      InstanceId: !Ref MYEC21
      AllocationId: !GetAtt MyEIP1.AllocationId

  MyEIP2:
    Type: AWS::EC2::EIP
    Properties:
      Domain: vpc

  MyEIP2Assoc:
    Type: AWS::EC2::EIPAssociation
    Properties:
      InstanceId: !Ref MYEC22
      AllocationId: !GetAtt MyEIP2.AllocationId

  ALBTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: jhMy-ALB-TG
      Port: 80
      Protocol: HTTP
      VpcId: !Ref MyVPC
      Targets:
        - Id: !Ref MYEC21
          Port: 80
        - Id: !Ref MYEC22
          Port: 80

  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: jhMy-ALB
      Scheme: internet-facing
      SecurityGroups:
        - !Ref WEBSG
      Subnets:
        - !Ref MyPublicSN1
        - !Ref MyPublicSN2

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref ALBTargetGroup
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP
```
</details>

> key pair 생성은 [AWS - Infra](https://assu10.github.io/dev/2022/10/10/aws-infra/) 의 *3. 사전 준비* 를 참고하세요.

![CF Stack 생성](/assets/img/dev/2022/1119/route53_4.png)

---

### 3.1.2. CloudFormation 을 통해 생성된 자원 확인

- **VPC**
  - ***jhMy-VPC***
    - IP CIDR: 10.10.0.0/16
- **Public Subnet**
  - ***jhMy-Public-SN-1***
    - IP CIDR: 10.10.0.0/24
    - AZ: ap-northeast-2a
  - ***jhMy-Public-SN-2***
    - IP CIDR: 10.10.1.0/24
    - AZ: ap-northeast-2c
- **Public Routing Table**
  - ***jhMy-Public-RT***
    - 연결: jhMy-Public-SN-1, jhMy-Public-SN-2
- **IGW**
  - ***jhMy-IGW***
    - 연결: jhMy-VPC
- **Public EC2 Instance**
  - ***jhEC2-1***
    - 연결: jhMy-Public-SN-1
    - 데몬: HTTP 구성, EIP 설정
  - ***jhEC2-2***
    - 연결: jhMy-Public-SN-2
    - 데몬: HTTP 구성, EIP 설정
- **ALB**
  - ***jhMy-ALB***
    - Target Group: jhEC2-1, jhEC2-2
- **Security Group**
  - ***jhWEB-SG***
    - 프로토콜(inbound): SSH, HTTP
    - 대상(Source): 0.0.0.0/0

![CF Stack 생성 - 도식화](/assets/img/dev/2022/1119/route53_3.png)

---

### 3.1.3. 기본 통신 환경 검증

로컬에서 ALB DNS 주소로 웹 접근하여 Load Balancing 되는지 확인한다.

아래와 같이 웹접근 시 ***jhEC2-1*** 과 ***jhEC2-2*** 가 번갈아 나오는 것을 확인할 수 있다.
![ALB DNS 주소로 웹접근](/assets/img/dev/2022/1119/route53_5.png)

---

## 3.2. Route 53 과 ALB 연결

Route 53 에서는 Alias 를 통해 ELB, CloudFront, S3 Bucket 등과 연결할 수 있는데 해당 기능을 통해 ALB 와 연결해본다.

- Route 53 레코드 생성 (단순 라우팅)
- Route 53 단순 라우팅 검증

![Route 53 과 ALB 연결 구성도](/assets/img/dev/2022/1119/route53_6.png)

---

### 3.2.1. Route 53 레코드 생성 (단순 라우팅)

*[Route 53] - [Hosted zones] - [Create Record]*

Record 생성 화면에서 *Switch to wizard* 클릭 → *Simple Routing* 선택 → *Define simple record* 를 클릭한다.

![Simple Routing Record 생성](/assets/img/dev/2022/1119/route53_7.png)

- Record 명: test
- Record 유형: A - IPv4 주소 및 일부 AWS Resource 로 트래픽 라우팅
- 값/트래픽 라우팅 대상: ALB/CLB 에 대한 Alias, 서울 리전, 생성해둔 ALB 선택

ALB DNS 주소와 Alias 연결을 하는 Simple Routing Record 를 생성하였다.

---

### 3.2.2. Route 53 단순 라우팅 검증

이제 로컬에서 위에서 설정한 Simple Routing Record 의 도메인 이름으로 접속해보자.

![Simple Routing Record 도메인으로 접속](/assets/img/dev/2022/1119/route53_8.png)

*jhEC2-1* 과 *jhEC2-2* 가 번걸아 나오는 것을 확인할 수 있다.

![Route 53 과 ALB 연결 - 통신 흐름](/assets/img/dev/2022/1119/route53_6.png)

① 사용자는 *test.jhjhtest.com* 주소의 대상을 알기 위해 DNS Resolver 로 DNS 질의   
② DNS Resolver 는 Root 네임 서버로 DNS 질의 후 .com 의 TLD 네임 서버 주소 받음  
DNS Resolver 는 다시 .com 의 TLD 네임 서버로 DNS 질의 후 Route 53 의 호스팅 영역의 네임 서버 주소를 받음  
③ DNS Resolver 는 Route 53 호스팅 영역의 네임 서버로 *test.testjhjh.com* 에 대한 DNS 질의 후 응답(ALB)을 받음  
④ DNS Resolver 는 사용자에게 DNS 질의에 대한 응답(ALB) 전달   
⑤~⑦ ALB 를 통해 2대의 웹서버로 Load Balancing

---

## 3.3. Route 53 장애 조치 라우팅 정책

Route 53 에 2대의 EC2 Instance 를 각각 Primary / Secondary 형태로 연결하여 장애 조치 라우팅을 구성한다.

- Route 53 레코드 생성 (장애 조치 라우팅)
- Route 53 장애 조치 라우팅 검증
- Route 53 으로 AWS 자원이 아닌 다른 대상 연결

![Route 53 장애 조치 라우팅 정책 구성도](/assets/img/dev/2022/1119/route53_9.png)

---

### 3.3.1. Route 53 레코드 생성 (장애 조치 라우팅)

장애 조치 라우팅을 통해 Failover 환경을 구성하려면 대상의 상태를 확인하는 작업이 필요하다.

*[Route 53] - [Health checks] - [Create health check]*

![Route 53 장애 조치 라우팅 정책 구성도](/assets/img/dev/2022/1119/route53_10.png)

이 후 Create alarm 은 설정하지 않는다.

동일하게 jhSecondary-check 도 생성한다.  
2개의 Health check 는 */index.html* 로 주기적인 상태 확인을 수행한다.

> Health check 에 Alarm 을 설정하면 이메일이나 SMS 등으로 경보 알람을 받을 수 있음

이제 장애 조치 라우팅 정책을 생성해보자.

*[Route 53] - [Hosted zones] - [Create Record]*

Record 생성 화면에서 *Switch to wizard* 클릭 → *Failover* 를 선택한다.

![Route 53 장애 조치 라우팅 - 기본 구성](/assets/img/dev/2022/1119/route53_11.png)
![Route 53 장애 조치 라우팅 - 레코드 정의](/assets/img/dev/2022/1119/route53_12.png)
위와 동일하게 Secondary Record 도 생성한다.

![호스팅 영역의 장애 조치 Record 확인](/assets/img/dev/2022/1119/route53_13.png)


---

### 3.3.2. Route 53 장애 조치 라우팅 검증

이제 로컬에서 위에서 설정한 장애 조치 라우팅 Record 의 도메인으로 웹 접속을 해보자.

![장애 조치 라우팅 레코드 도메인 접속 - Primary](/assets/img/dev/2022/1119/route53_14.png)

Primary 대상인 *jhEC2-1* 이 정상이므로 *jhEC2-1* 으로만 라우팅이 된다.  
이제 *jhEC2-1* 를 Stop 한 후 다시 장애 조치 라우팅 Record 의 도메인으로 웹 접속을 해보자.

![장애 조치 라우팅 레코드 도메인 접속 - Primary](/assets/img/dev/2022/1119/route53_15.png)

Health check 시 Primary 서버가 비정상이기 때문에 Secondary 인 *jhEC2-2* 로 라우팅된다.  
이후 Primary 가 정상상태가 되면 다시 *jhEC2-1* 으로 라우팅된다.

---

### 3.3.3. Route 53 으로 AWS 자원이 아닌 다른 대상 연결

Route 53 호스팅 영역에서 레코드 생성 후 연결 대상이 꼭 AWS Resource 일 필요는 없다.  
외부 서버의 Public IP 에 대해 A Record 연결을 해보자.

*[Route 53] - [Hosted zones] - [Create Record]*

Record 생성 화면에서 *Switch to wizard* 클릭 → *Simple Routing* 선택 → *Define simple record* 를 클릭한다.

![단순 라우팅 레코드 생성 - Google DNS 서버 IP](/assets/img/dev/2022/1119/route53_16.png)

> 중간에 jhtesttest.com 으로 새로 도메인 취득했음

```shell
$ ping qqq.jhtesttest.com
PING qqq.jhtesttest.com (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: icmp_seq=0 ttl=116 time=32.486 ms
64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=32.644 ms
```

---

## 3.4. Resource 삭제

아래의 순서대로 Resource 를 삭제한다.

- Route 53 Health checks 삭제 (*[Route 53] - [Health checks]*)
- 호스팅 영역 Record 삭제 (*[Route 53] - [Hosted zones] - [Records]*)
- 호스팅 영역 삭제 (*[Route 53] - [Hosted zones]*)  
바로 다음 포스트에서 사용 예정이므로 지금 삭제하지 말 것
- CloudFormation Stack 삭제 (*[CloudFormation] - [Stacks] - [Delete]*)

CloudFormation Stack 이 삭제되면 위의 [3.1.2. CloudFormation 을 통해 생성된 자원 확인](#312-cloudformation-을-통해-생성된-자원-확인) 의 자원이
모두 삭제되었는지 확인한다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김원일, 서종호 저자의 **따라하며 배우는 AWS 네트워크 입문**를 기반으로 스터디하며 정리한 내용들입니다.*

* [따라하며 배우는 AWS 네트워크 입문](http://www.yes24.com/Product/Goods/93887402)
* [따라하며 배우는 AWS 네트워크 입문 - 책가이드](https://www.notion.so/ongja/AWS-1af579548fd84c268f8f3ee3f26b2ed4)
* [따라하며 배우는 AWS 네트워크 입문 - 팀블로그](https://gasidaseo.notion.site/gasidaseo/CloudNet-Blog-c9dfa44a27ff431dafdd2edacc8a1863)
* [Freenom 무료DNS 생성 후 Route 53 호스팅 영역 연결](https://www.notion.so/ongja/CNBA52-Freenom-DNS-Route-53-aa8bc62b89704555b7ba09dd7465cbc6)
* [Route 53 도메인 이름 등록](https://aws.amazon.com/ko/getting-started/hands-on/get-a-domain/)