---
layout: post
title:  "AWS - Load Balancing (4): Global Accelerator"
date:   2022-12-03 10:00
categories: dev
tags: devops aws global-accelerator
---

이 포스트는 Global Accelerator 에 대해 알아본다.

> - [Global Accelerator](#1-global-accelerator)
> - [Global Accelerator 테스트](#2-global-accelerator-테스트)
>   - [기본 환경 구성](#21-기본-환경-구성)
>   - [Global Accelerator 설정 및 확인](#22-global-accelerator-설정-및-확인)
>   - [`Traffic Dial` 과 `Weight` 를 통한 트래픽 조정](#23-traffic-dial-과-weight-를-통한-트래픽-조정)
>   - [Global Accelerator 의 Failover](#24-global-accelerator-의-failover)
>   - [Resource 삭제](#25-resource-삭제)

---

아래는 이번 포스트에서 다뤄볼 범위 도식화이다.

![이번 포스트 범위 도식화](/assets/img/dev/2022/1203/1203_design.png)


# 1. Global Accelerator

Global Accelerator 는 글로벌 사용자를 대상으로 서비스의 가용성과 성능을 개선하는 서비스로, AWS 의 글로벌 네트워크를 통해 사용자에서 애플리케이션으로 이어진 경로를 최적화하여
트래픽의 성능을 개선하는 기술이다.

Global Accelerator 는 AWS 글로벌 네트워크 인프라를 활용하는데, AWS 글로벌 네트워크 인프라는 Private 글로벌 네트워크 인프라로 상호 연결되어 있는 AWS 글로벌
백본 네트워크이다.

> 국내 사용자가 서울 리전의 AWS 서비스에 접근 시엔 국내 ISP 네트워크망과 지연 상태가 원활하기 때문에 Global Accelerator 를 적용해도 큰 효과가 없다.  
> 
> 글로벌하게 서비스하는 환경에서 자체 네트워크 환경이 좋지 않은 일부 국가에서는 Global Accelerator 적용 시 큰 도움이 된다.

![Global Accelerator Architecture](/assets/img/dev/2022/1203/global_1.png)

① **엔드포인트 그룹**  
- Global Accelerator 대상 애플리케이션이 배포되는 AWS 리전을 정의
- 다수의 엔드포인트 그룹이 존재할 경우 `Traffic Dial` 값(Default 100)을 통해 비중 조정

② **엔드포인트**   
- 엔드포인트 그룹에 속한 Global Accelerator 연결 대상
- EC2, EIP, ALB, NLB 가 될 수 있음
- 다수의 엔드포인트가 존재할 경우 `Weight` 값(Default 128)을 통해 비중 조정
- `Weight` 의 비중은 `자신의 Weight / 전체 Weight` 로 산출

③ **Listener**  
- Global Accelerator 로 inbound 연결을 처리하는 객체 (프로토콜과 포트 기반, TCP/80 등..)

④ **Anycast IP**  
- Global Accelerattor 의 진입점 역할을 하는 고정 IP
- Anycast 통신 방식 사용
- 같은 서비스를 하는 여러 개의 대상이 같은 Anycast IP 를 가질 수 있음

⑤ **Edge Location**  
- 다수의 Edge Location 에서 알리는 Anycast IP 를 통해 사용자에게 가장 가까운 Edge Location 으로 트래픽 전송

⑥ **글로벌 네트워크**  
- Global Accelerator 를 통해 라우팅 되는 트래픽은 공용 인터넷이 아닌 AWS 글로벌 네트워크를 통해 통신
- 가장 가까운 정상 상태의 엔드포인트 그룹을 선택하여 서비스함

> **Anycast 통신**  
> 가장 가까운 노드와 통신

즉, Global Accelerator 는 Anycast IP 를 제공하여 사용자가 가장 인접된 대상으로 접근가능하고, AWS 글로벌 네트워크를 경유하기 때문에
안정적이고 빠른 서비스가 가능하다.

---

<**Global Accelerator 주요 기능**>
- **고정 Anycast IP**
  - Global Accelerator 의 진입점 역할을 하는 2개의 고정 IP 제공
  - 해당 고정 IP 는 Edge Location 의 Anycast 로 여러 Edge Location 에서 동시에 공개함
  - Global Accelerator 로 연결되는 엔드포인트의 Frontend 인터페이스 역할
- **트래픽 제어**  
  - `Traffic Dial` 값과 `Weight` 값을 조정하여 다수의 엔드포인트 그룹과 엔드포인트에 대한 비중을 부여하여 트래픽 제어
- **엔드포인트 상태 확인**  
  - Health check 를 통해 정상 상태의 엔드포인트로 라우팅함으로써 Failover 환경 구성 가능
- **클라이언트 IP 보존**  
  - 사용자가 최종 엔드포인트로 접근 시 사용자의 IP 보존
- **모니터링**  
  - TCP, HTTP(S) 상태 확인을 하여 지속적으로 엔드포인트 상태 모니터링

---

# 2. Global Accelerator 테스트

시드니 리전 (ap-southeast-2) 와 상파울루 리전 (sa-east-1) 에 구성된 웹 서버에 대해 Global Accelerator 를 연결하여 트래픽 흐름 제어와 Failover 동작을
확인해본다.

![목표 구성도(기본 환경은 별도로 구성)](/assets/img/dev/2022/1203/global_flow_2.png)

- 기본 환경 구성
  - CloudFormation 적용
  - CloudFormation 을 통해 생성된 자원 확인
  - 기본 통신 환경 검증
- Global Accelerator 설정 및 확인
  - Global Accelerator 생성
  - Global Accelerator 확인
- `Traffic Dial` 과 `Weight` 를 통한 트래픽 조정
  - 트래픽 조정 전 통신 흐름
  - `Traffic Dial` 트래픽 조정 검증
  - `Weight` 트래픽 조정 검증
- Global Accelerator 의 Failover
- Resource 삭제

---

## 2.1. 기본 환경 구성

- CloudFormation 적용
- CloudFormation 을 통해 생성된 자원 확인
- 기본 통신 환경 검증

![기본 환경 구성도](/assets/img/dev/2022/1203/global_flow_1.png)

---

### 2.1.1. CloudFormation 적용

서울 리전이 아닌 시드니 리전(ap-southeast-2) 와 상파울루 리전(sa-east-1) 에 Resource 를 생성한다.   
(리전마다 CloudFormation 통해 기본 환경 구성)

*[CloudFormation] - [Stacks]*

[CloudFormation Template Download](http://bit.ly/cnbl05041)

<details markdown="1">
<summary>CloudFormation Template (펼쳐보기)</summary>

```yaml
Parameters:
  LatestAmiId:
    Description: (DO NOT CHANGE)
    Type: 'AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>'
    Default: '/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2'
    AllowedValues:
      - /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2

Mappings:
  AWSRegionArch2AMI:
    ap-southeast-2:
      HOST: jhSYDNEY
      VPC: jhSYDNEY-VPC
      IGW: jhSYDNEY-IGW
      RT: jhSYDNEY-Public-RT
      SN1: jhSYDNEY-Public-SN-1
      SN2: jhSYDNEY-Public-SN-2
      EC21: jhSYDNEY-EC2-1
      EC22: jhSYDNEY-EC2-2
    sa-east-1:
      HOST: jhSAOPAULO
      VPC: jhSAOPAULO-VPC
      IGW: jhSAOPAULO-IGW
      RT: jhSAOPAULO-Public-RT
      SN1: jhSAOPAULO-Public-SN-1
      SN2: jhSAOPAULO-Public-SN-2
      EC21: jhSAOPAULO-EC2-1
      EC22: jhSAOPAULO-EC2-2

Conditions:
  CreateSydneyResources: !Equals [!Ref 'AWS::Region', ap-southeast-2]

Resources:
  MyVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.10.0.0/16
      Tags:
        - Key: Name
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', VPC]

  MyIGW:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', IGW]

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
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', RT]

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
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', SN1]

  MyPublicSN2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MyVPC
      AvailabilityZone: !Select [2, !GetAZs '']
      CidrBlock: 10.10.1.0/24
      Tags:
        - Key: Name
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', SN2]

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
          Value: jhWEB-SG
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: '80'
          ToPort: '80'
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: '22'
          ToPort: '22'
          CidrIp: 0.0.0.0/0

  MyEC21:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref LatestAmiId
      Tags:
        - Key: Name
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', EC21]
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref MyPublicSN1
          GroupSet:
            - !Ref WEBSG
          AssociatePublicIpAddress: true
      UserData:
        Fn::Base64: !Sub
          - |+
            #!/bin/bash -v
            (
            echo "CN@12c"
            echo "CN@12c"
            ) | passwd --stdin root
            sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
            sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
            service sshd restart
            hostname ${host}-EC2-1
            yum install httpd -y
            service httpd start
            chkconfig httpd on
            echo "<h1>CloudNeta ${host} Web Server_1</h1>" > /var/www/html/index.html
          - host:
              Fn::FindInMap: [AWSRegionArch2AMI, Ref: 'AWS::Region', HOST]

  MyEC22:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref LatestAmiId
      Tags:
        - Key: Name
          Value: !FindInMap [AWSRegionArch2AMI, !Ref 'AWS::Region', EC22]
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref MyPublicSN2
          GroupSet:
            - !Ref WEBSG
          AssociatePublicIpAddress: true
      UserData:
        Fn::Base64: !Sub
          - |+
            #!/bin/bash -v
            (
            echo "qwe123"
            echo "qwe123"
            ) | passwd --stdin root
            sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
            sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
            service sshd restart
            hostnamectl --static set-hostname ${host}-EC2-2
            yum install httpd -y
            service httpd start
            chkconfig httpd on
            echo "<h1>CloudNeta ${host} Web Server_2</h1>" > /var/www/html/index.html
          - host:
              Fn::FindInMap: [AWSRegionArch2AMI, Ref: 'AWS::Region', HOST]

  ALBTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Condition: CreateSydneyResources
    Properties:
      Name: ALB-TG
      Port: 80
      Protocol: HTTP
      VpcId: !Ref MyVPC
      Targets:
        - Id: !Ref MyEC21
          Port: 80
        - Id: !Ref MyEC22
          Port: 80

  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Condition: CreateSydneyResources
    Properties:
      Name: jhSYDNEY-ALB
      Scheme: internet-facing
      SecurityGroups:
        - !Ref WEBSG
      Subnets:
        - !Ref MyPublicSN1
        - !Ref MyPublicSN2

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Condition: CreateSydneyResources
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref ALBTargetGroup
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP
```
</details>

---

### 2.1.2. CloudFormation 을 통해 생성된 자원 확인

#### 2.1.2.1. 시드니 (ap-southeast-2) 리전

- **VPC**
  - ***jhSYDNEY-VPC***
    - - IP CIDR: 10.10.0.0/16
- **Public Subnet**
  - ***jhSYDNEY-Public-SN-1***
    - IP CIDR: 10.10.0.0/24
    - AZ: ap-southeast-2a
  - ***jhSYDNEY-Public-SN-2***
    - IP CIDR: 10.10.1.0/24
    - AZ: ap-southeast-2c
- **Public Routing Table**
  - ***jhSYDNEY-Public-RT***
    - 연결: jhSYDNEY-Public-SN-1, jhSYDNEY-Public-SN-1
- **IGW**
  - ***jhSYDNEY-IGW***
    - 연결: jhSYDNEY-VPC
- **Public EC2 Instance**
  - ***jhSYDNEY-EC2-1***
    - 연결: jhSYDNEY-Public-SN-1
    - 데몬: HTTP 구성
    - root 계정 로그인: 암호 CN@12c
  - ***jhSYDNEY-EC2-2***
    - 연결: jhSYDNEY-Public-SN-2
    - 데몬: HTTP 구성
    - root 계정 로그인: 암호 qwe123
- **ALB**
  - ***jhSYDNEY-ALB***
    - Target Group: jhSYDNEY-EC2-1, jhSYDNEY-EC2-2
- **Security Group**
  - ***jhWEB-SG***
    - 프로토콜(inbound): SSH, HTTP
    - 대상(Source): 0.0.0.0/0

---

#### 2.1.2.2. 상파울루 (sa-east-1) 리전

- **VPC**
  - ***jhSAOPAULO-VPC***
    - - IP CIDR: 10.10.0.0/16
- **Public Subnet**
  - ***jhSAOPAULO-Public-SN-1***
    - IP CIDR: 10.10.0.0/24
    - AZ: sa-east-1a
  - ***jhSAOPAULO-Public-SN-2***
    - IP CIDR: 10.10.1.0/24
    - AZ: sa-east-1c
- **Public Routing Table**
  - ***jhSAOPAULO-Public-RT***
    - 연결: jhSAOPAULO-Public-SN-1, jhSAOPAULO-Public-SN-1
- **IGW**
  - ***jhSYDNEY-IGW***
    - 연결: jhSAOPAULO-VPC
- **Public EC2 Instance**
  - ***jhSAOPAULO-EC2-1***
    - 연결: jhSAOPAULO-Public-SN-1
    - 데몬: HTTP 구성
    - root 계정 로그인: 암호 CN@12c
  - ***jhSAOPAULO-EC2-2***
    - 연결: jhSAOPAULO-Public-SN-2
    - 데몬: HTTP 구성
    - root 계정 로그인: 암호 qwe123
- **Security Group**
  - ***jhWEB-SG***
    - 프로토콜(inbound): SSH, HTTP
    - 대상(Source): 0.0.0.0/0

![CF Stack 생성 - 도식화](/assets/img/dev/2022/1203/global_2.png)

---

### 2.1.3. 기본 통신 환경 검증

사용자 역할을 하는 EC2 Instance 1대를 서울 리전 (ap-northeast-2) 에 직접 생성한다.  
(EC2 Instance 생성 시 기본 VPC 를 통해 구성하여 외부 인터넷 통신이 가능한 상태만 유지)

- Name
  - jhSEOUL-EC2
- AMI
  - Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type
- Instance type
  - t2.micro
- Network settings
  - VPC: Default VPC
  - Subnet: Default Subnet ap-northeast-2a
- Key pair
  - jh-test

> key pair 생성은 [AWS - Infra](https://assu10.github.io/dev/2022/10/10/aws-infra/) 의 *3. 사전 준비* 를 참고하세요.

이제 jhSEOUL-EC2 에 SSH 접근하여 시드니 리전과 상파울루 리전에 생성한 리소스와 통신을 해본다.

```shell
# 서울 리전의 EC2에 SSH 접속
$ ssh -i sandbox-jh.pem ec2-user@52.78.xx.xx

# 시드니 EC2 Instance 통신 확인 (ALB 의 DNS name)
[ec2-user@ip-172-31-xx-xx ~]$ curl jhSYDNEY-ALB-xxx.ap-southeast-2.elb.amazonaws.com
<h1>CloudNeta jhSYDNEY Web Server_2</h1>
[ec2-user@ip-172-31-xx-xx ~]$ curl jhSYDNEY-ALB-xxx.ap-southeast-2.elb.amazonaws.com
<h1>CloudNeta jhSYDNEY Web Server_1</h1>

# 상파울루 EC2 Instance 통신 확인 (EC2 의 public ip)
[ec2-user@ip-172-31-xx-xx ~]$ curl 18.228.xx.xx
<h1>CloudNeta jhSAOPAULO Web Server_1</h1>
[ec2-user@ip-172-31-xx-xx ~]$ curl 15.228.xx.xx
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
```

![기본 환경 통신 흐름](/assets/img/dev/2022/1203/global_flow_1.png)

기본 환경 통신은 Global Accelerator 가 아니기 때문에 여러 ISP 네트워크를 거쳐 통신이 이루어진다.

---

## 2.2. Global Accelerator 설정 및 확인

- Global Accelerator 생성
- Global Accelerator 확인

![Global Accelerator 설정 구성도](/assets/img/dev/2022/1203/global_flow_2.png)

---

### 2.2.1. Global Accelerator 생성

Global Accelerator 는 **이름 설정** → **리스너 추가** → **엔드포인트 그룹 추가** → **엔드포인트 추가** 순으로 진행된다.   

*[Global Accelerator] - [Accelerators] - [Create accelerator]*

- **이름 설정**
  - 사용할 이름 설정
- **리스너 추가**
  - Global Accelerator 에 연결할 애플리케이션은 웹 서비스로 TCP/80 리스너 추가
  - ![Global Accelerator 설정 - 리스너 추가](/assets/img/dev/2022/1203/global_3.png)
- **엔드포인트 그룹 추가**
  - 엔드포인트 그룹은 대상 애플리케이션이 배포되는 AWS 리전을 정의
  - 해당 포스트에선 시드니 리전 (ap-southeast-2) 와 상파울루 (sa-east-1) 이 해당함
  - ![Global Accelerator 설정 - 엔드포인트 그룹 추가](/assets/img/dev/2022/1203/global_4.png)
- **엔드포인트 추가**
  - 해당 포스트에선 시드니 리전의 엔드포인트 대상은 ALB 로, 상파울루 리전의 엔드포인트 대상은 EC2 2대로 설정
  - ![Global Accelerator 설정 - 엔드포인트 추가](/assets/img/dev/2022/1203/global_5.png)

---

### 2.2.2. Global Accelerator 확인

생성된 Global Accelerator 의 정보를 확인해보자.

![Global Accelerator 정보 확인 - 리스너 정보](/assets/img/dev/2022/1203/global_6.png)
![Global Accelerator 정보 확인 - 리스너와 엔드포인트 그룹](/assets/img/dev/2022/1203/global_7.png)
![Global Accelerator 정보 확인 - 엔드포인트 그룹과 엔드포인트](/assets/img/dev/2022/1203/global_8.png)

---

## 2.3. `Traffic Dial` 과 `Weight` 를 통한 트래픽 조정

- 트래픽 조정 전 통신 흐름
- `Traffic Dial` 트래픽 조정 검증
- `Weight` 트래픽 조정 검증

### 2.3.1. 트래픽 조정 전 통신 흐름

서울 리전의 EC2 Instance 에 SSH 접속을 한 후 Global Accelerator 의 고정 Anycast IP 를 여러 번 호출해본다.

```shell
$ ssh -i sandbox-jh.pem ec2-user@52.78.xx.xx

# 대상 IP 는 Global Accelerator 의 고정 Anycast IP
# 10 은 호출된 횟수
[ec2-user@ip-172-31-8-166 ~]$ for i in {1..20}; do curl -s -q 15.197.251.28; done | sort | uniq -c | sort -nr
     10 <h1>CloudNeta jhSYDNEY Web Server_2</h1>
     10 <h1>CloudNeta jhSYDNEY Web Server_1</h1>
```

시드니 리전에 속한 웹 서버 2대로 부하분산되는 것을 알 수 있다.  
사용자와 가장 인접한 Edge Location 을 경유하고, AWS 글로벌 네트워크를 통해 가장 인접한 시드니 리전의 엔드포인트 그룹으로 전달된 것이다.

> `traceroute xxx.xxx.xx.xx` 를 통해 IP 경로를 추적해볼 수 있음

---

### 2.3.2. `Traffic Dial` 트래픽 조정 검증

`Traffic Dial` 은 엔드포인트 그룹에 대해 전달하는 비중값으로 기본값은 100 이다.

시드니 리전 엔드포인트 그룹의 `Traffic Dial` 값을 100 → 50 으로 조정해본다.

*[Global Accelerator] - [Accelerators] - [시드니 엔드포인트 그룹 선택]*

![시드니 리전 엔드포인트 그룹 Traffic Dial 값 조정](/assets/img/dev/2022/1203/global_9.png)
![시드니 리전 엔드포인트 그룹 Traffic Dial 값 조정 후 확인](/assets/img/dev/2022/1203/global_10.png)

이제 다시 서울 리전의 EC2 Instance 에 SSH 접속을 한 후 Global Accelerator 의 고정 Anycast IP 를 여러 번 호출해본다.

```shell
$ ssh -i sandbox-jh.pem ec2-user@52.78.xx.xx

# 대상 IP 는 Global Accelerator 의 고정 Anycast IP
[ec2-user@ip-172-31-8-166 ~]$ for i in {1..20}; do curl -s -q 15.197.251.28; done
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
<h1>CloudNeta jhSYDNEY Web Server_1</h1>
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
<h1>CloudNeta jhSYDNEY Web Server_2</h1>
<h1>CloudNeta jhSYDNEY Web Server_1</h1>
<h1>CloudNeta jhSYDNEY Web Server_2</h1>
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
<h1>CloudNeta jhSAOPAULO Web Server_1</h1>
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
<h1>CloudNeta jhSYDNEY Web Server_1</h1>
<h1>CloudNeta jhSYDNEY Web Server_2</h1>
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
<h1>CloudNeta jhSYDNEY Web Server_1</h1>
<h1>CloudNeta jhSYDNEY Web Server_1</h1>
<h1>CloudNeta jhSAOPAULO Web Server_1</h1>
<h1>CloudNeta jhSAOPAULO Web Server_2</h1>
<h1>CloudNeta jhSAOPAULO Web Server_1</h1>
<h1>CloudNeta jhSAOPAULO Web Server_1</h1>
<h1>CloudNeta jhSYDNEY Web Server_2</h1>
<h1>CloudNeta jhSYDNEY Web Server_2</h1>
```

시드니 리전의 웹 서버로 10개, 상파울루 웹 서버로 10개의 트래픽이 전달되고 있다.  
시드니 리전 엔드포인트 그룹의 트래픽 수용을 50% 로 수정하였으므로 상파울로 리전 엔드포인트 그룹으로 나머지 50%가 전달된다. 

이제 시드니 리전 엔드포인트 그룹의 `Traffic Dial` 값을 50 → 0 으로 조정해본다.

```shell
$ ssh -i sandbox-jh.pem ec2-user@52.78.xx.xx

[ec2-user@ip-172-31-8-166 ~]$ for i in {1..20}; do curl -s -q 15.197.251.28; done | sort | uniq -c | sort -nr
     11 <h1>CloudNeta jhSAOPAULO Web Server_2</h1>
      9 <h1>CloudNeta jhSAOPAULO Web Server_1</h1>
```

시드니 리전 엔드포인트 그룹의 `Traffic Dial` 을 0 으로 설정하였기 때문에 시드니 리전 엔드포인트 그룹으로는 트래픽이 전달되지 않는다.

> **`Traffic Dial` 0 으로 설정이 필요한 상황**  
> 리전 내 애플리케이션을 업그레이드하거나 작업이 필요할 때 0 으로 설정하여 트래픽 차단 후 작업이 끝나면 다시 100 으로 조정하여 트래픽 다시 수용. 

---

### 2.3.3. `Weight` 트래픽 조정 검증

`Weight` 는 엔드포인트에 대해 전달하는 비중값으로 기본값은 128 이다.  
비중값은 `자신의 Weight / 전체 Weight` 로 산출한다.

시드니 리전의 엔드포인트는 ALB 하나이므로, 상파울루 리전 엔드포인트에 대해 `Weight` 조정 테스트를 해보자. 

*[Global Accelerator] - [Accelerator] - [생성한 Global Accelerator 선택] - [상파울루 엔드포인트 그룹 선택] - [EC2 선택]*

![상파울루 리전 엔드포인트의 Weight 값을 128 → 64 로 조정](/assets/img/dev/2022/1203/global_11.png)

이제 다시 서울 리전의 EC2 Instance 에 SSH 접속을 한 후 Global Accelerator 의 고정 Anycast IP 를 여러 번 호출해본다.

```shell
$ ssh -i sandbox-jh.pem ec2-user@52.78.xx.xx

# 대상 IP 는 Global Accelerator 의 고정 Anycast IP
[ec2-user@ip-172-31-8-166 ~]$ for i in {1..20}; do curl -s -q 15.197.251.28; done | sort | uniq -c | sort -nr
     14 <h1>CloudNeta jhSAOPAULO Web Server_2</h1>
      6 <h1>CloudNeta jhSAOPAULO Web Server_1</h1>
```

웹서버 1로 6개, 웹서버 2로 14개의 트래픽이 전달되었다.
웹서버 1의 비중은 64/(64+128) = 1/3 이고, 웹서버 2의 비중은 128/(64+128) = 2/3 이다.

`Weight` 값을 0으로 조정 시 해당 엔드포인트로는 트래픽이 전달되지 않는다.

---

## 2.4. Global Accelerator 의 Failover

위에서 조정했던 시드니 리전 엔드포인트 그룹의 `Traffic Dial` 값을 다시 100 으로 변경한다.

```shell
[ec2-user@ip-172-31-8-166 ~]$ for i in {1..20}; do curl -s -q 15.197.251.28; done | sort | uniq -c | sort -nr
     10 <h1>CloudNeta jhSYDNEY Web Server_2</h1>
     10 <h1>CloudNeta jhSYDNEY Web Server_1</h1>
```

시드니 리전 엔드포인트 그룹으로만 트래픽이 전달되는 것을 확인할 수 있다.

이제 시드니 리전의 EC2 Instance 를 모두 중지한 후 시드니 리전 엔드포인트의 상태를 확인해본다.

![시드니 리전 엔드포인트의 상태](/assets/img/dev/2022/1203/global_12.png)

이제 다시 서울 리전의 EC2 Instance 에 SSH 접속을 한 후 Global Accelerator 의 고정 Anycast IP 를 여러 번 호출하면
상파울루 리전의 웹 서버로 모든 트래픽이 전달되는 것을 확인할 수 있다.

```shell
[ec2-user@ip-172-31-8-166 ~]$ for i in {1..20}; do curl -s -q 15.197.251.28; done | sort | uniq -c | sort -nr
     20 <h1>CloudNeta jhSAOPAULO Web Server_1</h1>
```

이후 시드니 리전의 EC2 들을 재시작하면 다시 시드니 리전의 엔드포인트로 모든 트래픽이 전달되는 것을 확인할 수 있다.

---

## 2.5. Resource 삭제

아래의 순서대로 Resource 를 삭제한다.

- Global Accelerator 삭제 (*[Global Accelerator] - [선택] - [Disable] - [Delete]*)
- 서울 리전 EC2 삭제
- 시드니와 상파울루 CloudFormation Stack 삭제 (*[CloudFormation] - [Stacks] - [Delete]*)
  - 상파울루와 시드니 EC2 는 Public Subnet 에 위치하고, SSH 로그인 방식이 key 방식이 아닌 암호 입력 방식으로 SSH 무차별 대입 공격이 발생할 수 있으니 반드시
    삭제를 확인할 것

CloudFormation Stack 이 삭제되면 위의 [2.1.2. CloudFormation 을 통해 생성된 자원 확인](#212-cloudformation-을-통해-생성된-자원-확인) 의 자원이
모두 삭제되었는지 확인한다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김원일, 서종호 저자의 **따라하며 배우는 AWS 네트워크 입문**를 기반으로 스터디하며 정리한 내용들입니다.*

* [따라하며 배우는 AWS 네트워크 입문](http://www.yes24.com/Product/Goods/93887402)
* [따라하며 배우는 AWS 네트워크 입문 - 책가이드](https://www.notion.so/ongja/AWS-1af579548fd84c268f8f3ee3f26b2ed4)
* [따라하며 배우는 AWS 네트워크 입문 - 팀블로그](https://gasidaseo.notion.site/gasidaseo/CloudNet-Blog-c9dfa44a27ff431dafdd2edacc8a1863)