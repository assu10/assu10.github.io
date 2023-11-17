---
layout: post
title:  "AWS - Internet"
date:   2022-11-05 10:00
categories: dev
tags: devops aws internet-gateway igw nat-device proxy-instance nat 
---

이 포스트는 AWS 내부 리소스에서 외부 인터넷 구간으로 통신하기 위한 인터넷 연결 방법에 대해 알아본다.

> - [인터넷 연결](#1-인터넷-연결)
>   - [Internet Gateway](#11-internet-gateway)
>   - [NAT Device (NAT Instance & NAT Gateway)](#12-nat-device-nat-instance--nat-gateway)
>   - [Proxy Instance](#13-proxy-instance)
> - [NAT Instance 로 인터넷 연결 테스트](#2-nat-instance-로-인터넷-연결-테스트)
>   - [기본 환경 구성](#21-기본-환경-구성)
>   - [NAT Instance 구성](#22-nat-instance-구성)
>   - [Resource 삭제](#23-resource-삭제)
     
---

아래는 이번 포스트에서 다뤄볼 범위 도식화이다.

![이번 포스트 범위 도식화](/assets/img/dev/2022/1105/1105_design.png)

# 1. 인터넷 연결

AWS 의 인터넷 연결을 위해서는 IGW, 네트워크 라우팅 테이블 정보, 공인 IP, 그리고 보안 그룹과 네트워크 ACL 이 필요하다.

- **NAT** (Network Address Translation)  
  - IP 를 변환
- **PAT** (Port Address Translation)  
  - IP 와 Port 를 동시에 변환

집의 PC 가 IP 공유기의 NAT 를 통해 인터넷에 연결되는 과정을 보자.

① PC (192.168.1.1) 은 Private IP 를 갖고 있고, 외부 웹서버(60.1.1.1) 연결 시 IP 공유기로 요청  
② IP 공유기는 Private IP (192.168.1.1) 를 인터넷이 가능하도록 자신에게 할당된 Public IP 로 변환하여 웹서버로 연걸

| | **IGW** | **NAT Device** | **Proxy Instance** |
| **동작** | Layer 3 | Layer 4 | Layer 7 |
| **주소 변환** | Private IP 를 Public IP or Elastic IP 로 1:1 주소 변환 | IP 주소와 Port 변환 | IP 주소와 Port 변환 (TCP 신규 연결) |
| **특징** | 1개의 Private IP 마다 1개의 공인 IP 매칭 | 여러 개의 Private IP 가 1개의 공인 IP 사용 가능 | 애플리케이션 수준 제어 가능 |

---

## 1.1. Internet Gateway

IGW 는 Public IP or Elastic IP 에 대해 1:1 NAT 를 진행한다.

> Public IP 와 Elastic IP 는 1:1 로 Private IP 와 매핑되기 때문에 해당 IP 를 독접점으로 사용하는 것과 비슷해서  
> 외부 인터넷에서 Public IP, EIP 를 통해 내부 VPC 로 접근이 가능하다.

<**IGW 를 통한 외부 접속**>  

* 내부 인스턴스는 Private Subnet 에 위치  

① Private IP(10.1.1.1) 를 가진 내부 인스턴스가 외부 웹서버(60.1.1.1) 로 HTTP 접속을 시도함 **(출발지: 10.1.1.1 / 목적지: 60.1.1.1)**    
② IGW 는 출발지 IP 를 확인하고, 자신이 가진 NAT 정보에 의해 출발지 IP 를 Public IP (50.1.1.1) 로 변경하는 NAT 수행 **(10.1.1.1 → 50.1.1.1)**     
③ 외부 웹서버는 요청 처리 후 응답 트래픽 보냄 **(출발지 IP: 60.1.1.1 / 목적지: 50.1.1.1)**  
④ IGW 는 NAT 정보에 의해 목적지인 **50.1.1.1 을 10.1.1.1** 로 변경 후 VPC 내부로 전달하여 내부 인스턴스 (10.1.1.1) 로 전달됨

참고로 하나의 VPC 에는 하나의 IGW 만 사용할 수 있다.

---

## 1.2. NAT Device (NAT Instance & NAT Gateway)

NAT Instance 와 NAT Gateway 를 통칭하여 NAT Device 라 한다.

Private Subnet 에 있는 Instance 는 공인 IP 연결이 안되므로 직접 인터넷 연결이 불가능하며, 이 때 NAT Device 를 사용하여
인터넷 연결 혹은 AWS Public Service (S3...) 에 연결 가능하다.

> NAT 용어가 일반적인 관례에 따라 사용되지만 실제 NAT Device 는 IP 주소와 Port 변환(PAT) 을 한다.

기본적으로 내부에서 외부 인터넷으로만 통신이 가능하고, IGW 와는 다르게 외부 인터넷에서 내부로 직접 통신은 불가능하다.

> 외부 인터넷에서 내부로 직접 통신이 불가능한 제약은 포워딩(iptable 이용) 을 통해서 해소 가능하다.    
> (외부에서 특정 포트나 프로토콜에 요청 시 지정한 내부 IP 로 연결되도록 규칙 지정 가능)

<**NAT Gateway vs NAT Instance**>

| | **NAT Gateway** | **NAT Instance** |
| **관리** | AWS 에서 관리 | 사용자가 직접 관리 |
| **보안그룹** | 연결 불가 | 연결 가능 (In/Out bound 제어) |
| **접속 서버** | 접속 불가 (SSH 등) | 접속 가능 (SSH 등) |

> 소규모 트래픽만 발생하고, 서비스 중요도가 낮으면 상대적으로 저렴한 NAT Instance 구성을 권장한다.

<**NAT Instance 를 통한 외부 접속**>  

* 내부 인스턴스는 Private Subnet 에 위치, NAT Instance 는 Public Subnet 에 위치  

① Private IP(10.1.1.1) 을 가진 내부 인스턴스가 외부 웹서버(60.1.1.1) 로 HTTP 접속을 시도함.  
이 때 Private Subnet Routing Table 에 따라 NAT Instance 로 트래픽을 보냄 **(출발지: 10.1.1.1 / 목적지: 60.1.1.1)**  
② NAT Instance 는 <u>IP Masquerading</u> 기능을 통해 출발지 IP **(10.1.1.1 → 10.1.2.1)** 와 Port 번호를 변환.  
이 때 Public Subnet Routing Table 에 따라 IGW 로 트래픽을 보냄 **(출발지: 10.1.2.1 / 목적지: 60.1.1.1)**    
③ IGW 는 Private IP 를 EIP 로 변환(NAT) **(10.1.2.1 → 70.1.1.1)** 후 외부 웹서버로 트래픽을 보냄 **(출발지: 70.1.1.1 / 목적지: 60.1.1.1)**    
④ 외부 웹서버(60.1.1.1) 에서 요청 처리 후 응답 트래픽 보냄 **(출발지: 60.1.1.1 / 목적지: 70.1.1.1)**  
⑤ IGW 로 온 트래픽은 목적지를 **70.1.1.1 → 10.1.2.1** 로 NAT 후 VPC 로 보냄  
⑥ NAT Instance 는 출발지 IP(**10.1.2.1 → 10.1.1.1**) 와 Port 번호 변환 후 Private Subnet 으로 보냄  
⑦ 응답 트래픽이 내부 인스턴스인 10.1.1.1 에 도달

> **IP Masquerade**  
> IP 마스커레이드는 리눅스의 NAT 기능으로써 내부 컴퓨터들이 리눅스 서버를 통해 외부 네트워크에 접속할 수 있게 해주는 기능임.  
> 내부에서 생성한 모든 네트워크 요청은 MASQ 를 통해 외부 공인 IP 로 변환되어 인터넷에 연결되므로 외부에서는 리눅스 서버의 IP 만 알고
> 내부 컴퓨터의 존재는 모름.  
> 따라서 외부에서 내부 컴퓨터로 먼저 통신 시도를 할 수 없으나, 위에 한번 언급된 것처럼 iptable 을 이용하여 해결 가능함. 

다수의 인스턴스가 외부 인터넷으로 접속 시 NAT Instance 에 연결된 EIP 를 사용하기 때문에 결과적으로 다수의 인스턴스 출발지 IP 가
1개의 EIP 를 공유하여 사용하게 된다.  
따라서 다수의 인스턴스 이용 시엔 Port 번호를 기준으로 내부 인스턴스 트래픽을 구분할 수 있다. (=PAT)

> IGW 는 IP 변환에만 관여하고, Port 변환에는 관여하지 않는다.

참고로 NAT Gateway 는 단일 대상(e.g. 외부 웹서버 1대의 IP) 에 대해 분당 최대 55,000 개의 동시 연결이 가능하다.

---

## 1.3. Proxy Instance

Proxy Instance 는 클라이언트와 서버 중간에서 통신을 대신 처리해주는 역할을 한다.  
Proxy Instance 가 클라이언트의 통신을 대신 처리하기 때문에 서버는 마치 Proxy Instance 와 통신을 하는 것처럼 보인다.

<**Proxy Instance 를 통한 외부 접속**>  

* 내부 인스턴스, Proxy Instance 는 Private Subnet 에 위치  

① EC2 Instance 가 HTTP(S) 통신 시 Proxy Instance (10.1.2.1) 로 요청을 보낼 수 있게 설정함.  
EC2 에서 외부 HTTP(S) 통신 시 목적지 IP 는 Proxy Instance 로 보내짐
```shell
# Proxy Instance 의 IP 가 10.1.2.1 인 경우
export http_proxy=http://10.1.2.1:3128
export https_proxy=http://10.1.2.1:3128
```
② EC2 Instance 가 요청한 패킷을 Proxy Instance 가 대신해서 웹서버와 연결을 생성함(이 때 출발지 IP 는 Proxy Instance 의 IP)  
Private IP (10.1.2.1) 이지만 IGW 에서 EIP 로 변환됨 (목적지 IP 는 DNS 질의 응답값인 외부 웹서버 IP)  
③ Proxy Instance 와 웹서버 간 새로운 TCP 연결을 만들기때문에 출발지 Port 번호는 임시 포트(Ephemeral Port) 중에 선택하고,
목적지 포트는 웹서버이므로 80 을 선택함  
④ HTTP 헤더는 EC2 Instance 가 요청한 내용을 포함하여 전달

> Proxy Instance 에 대한 더 상세한 내용은 [Proxy Instance](https://www.notion.so/LabGuide-Proxy-Squid-Instance-VPC-Outbound-Filtering-96c05f0481044fe0baf9094d3035895d) 을 참고하세요.

---

# 2. NAT Instance 로 인터넷 연결 테스트

NAT Instance 를 통해 Private Subnet 에 있는 Instance 를 외부 인터넷과 연결해본다.

- 기본 환경 구성
  - CloudFormation 적용
  - CloudFormation 을 통해 생성된 자원 확인
  - 기본 통신 환경 검증
- NAT Instance 구성
  - NAT Instance 동작을 위한 스크립트 확인
  - NAT Instance 동작을 위한 설정
  - Private Subnet 에 위치한 Instance 에서 외부로 통신 확인
- Resource 삭제

![목표 구성도](/assets/img/dev/2022/1105/nat-flow.png)

---

## 2.1. 기본 환경 구성

- CloudFormation 적용
- CloudFormation  통해 생성된 자원 확인
- 기본 통신 환경 검증

![기본 환경 구성도](/assets/img/dev/2022/1105/nat-2.png)

### 2.1.1. CloudFormation 적용

*[CloudFormation] - [Stacks]*

[CloudFormation Template Download](http://bit.ly/cnbl0401)

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
  VPC1:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.10.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: jhNATInstance-VPC1
  InternetGateway1:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: jhNATInstance-IGW1
  InternetGatewayAttachment1:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref InternetGateway1
      VpcId: !Ref VPC1

  RouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC1
      Tags:
        - Key: Name
          Value: jhNATInstance-PublicRouteTable1
  DefaultRoute1:
    Type: AWS::EC2::Route
    DependsOn: InternetGatewayAttachment1
    Properties:
      RouteTableId: !Ref RouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway1
  Subnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC1
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: 10.10.1.0/24
      Tags:
        - Key: Name
          Value: jhNATInstance-VPC1-Subnet1
  Subnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref RouteTable1
      SubnetId: !Ref Subnet1

  RouteTable2:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC1
      Tags:
        - Key: Name
          Value: jhNATInstance-PrivateRouteTable1
  Subnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC1
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: 10.10.2.0/24
      Tags:
        - Key: Name
          Value: jhNATInstance-VPC1-Subnet2
  Subnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref RouteTable2
      SubnetId: !Ref Subnet2

  Instance1ENIEth0:
    Type: AWS::EC2::NetworkInterface
    Properties:
      SubnetId: !Ref Subnet1
      Description: Instance1 eth0
      GroupSet:
        - !Ref SG1
      PrivateIpAddress: 10.10.1.100
      #SourceDestCheck: false
      Tags:
        - Key: Name
          Value: jhNAT-Instance eth0
  VPCEIP1:
    Type: AWS::EC2::EIP
    Properties:
      Domain: vpc
  VPCAssociateEIP1:
    Type: AWS::EC2::EIPAssociation
    Properties:
      AllocationId: !GetAtt VPCEIP1.AllocationId
      NetworkInterfaceId: !Ref Instance1ENIEth0

  Instance1:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref LatestAmiId
      InstanceType: t2.micro
      KeyName: !Ref KeyName
      Tags:
        - Key: Name
          Value: jhNAT-Instance
      NetworkInterfaces:
        - NetworkInterfaceId: !Ref Instance1ENIEth0
          DeviceIndex: 0
      UserData:
        Fn::Base64: |
          #!/bin/bash
          hostname jhNAT-Instance
          cat <<EOF>> /etc/sysctl.conf
          net.ipv4.ip_forward=1
          net.ipv4.conf.eth0.send_redirects=0
          EOF
          sysctl -p /etc/sysctl.conf
          yum -y install iptables-services
          systemctl start iptables && systemctl enable iptables
          iptables -F
          iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
          service iptables save

  Instance2:
    Type: AWS::EC2::Instance
    DependsOn: Instance1
    Properties:
      ImageId: !Ref LatestAmiId
      InstanceType: t2.micro
      KeyName: !Ref KeyName
      Tags:
        - Key: Name
          Value: jhPrivate-EC2-1
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref Subnet2
          GroupSet:
            - !Ref SG2
          PrivateIpAddress: 10.10.2.101
      UserData:
        Fn::Base64: |
          #!/bin/bash
          (
          echo "qwe123"
          echo "qwe123"
          ) | passwd --stdin root
          sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
          sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
          service sshd restart
          hostnamectl --static set-hostname jhPrivate-EC2-1

  Instance3:
    Type: AWS::EC2::Instance
    DependsOn: Instance1
    Properties:
      ImageId: !Ref LatestAmiId
      InstanceType: t2.micro
      KeyName: !Ref KeyName
      Tags:
        - Key: Name
          Value: jhPrivate-EC2-2
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref Subnet2
          GroupSet:
            - !Ref SG2
          PrivateIpAddress: 10.10.2.102
      UserData:
        Fn::Base64: |
          #!/bin/bash
          (
          echo "qwe123"
          echo "qwe123"
          ) | passwd --stdin root
          sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
          sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
          service sshd restart
          hostnamectl --static set-hostname jhPrivate-EC2-2

  SG1:
    Type: AWS::EC2::SecurityGroup
    Properties:
      VpcId: !Ref VPC1
      GroupDescription: VPC1-NATInstance-SecurityGroup
      Tags:
        - Key: Name
          Value: jhVPC1-NATInstance-SecurityGroup
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: '22'
          ToPort: '22'
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: '80'
          ToPort: '80'
          CidrIp: 10.10.0.0/16
        - IpProtocol: tcp
          FromPort: '443'
          ToPort: '443'
          CidrIp: 10.10.0.0/16
        - IpProtocol: udp
          FromPort: '0'
          ToPort: '65535'
          CidrIp: 10.10.0.0/16
        - IpProtocol: icmp
          FromPort: -1
          ToPort: -1
          CidrIp: 0.0.0.0/0

  SG2:
    Type: AWS::EC2::SecurityGroup
    Properties:
      VpcId: !Ref VPC1
      GroupDescription: VPC1-PrivateEC2-SecurityGroup
      Tags:
        - Key: Name
          Value: jhVPC1-PrivateEC2-SecurityGroup
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: '22'
          ToPort: '22'
          CidrIp: 10.10.0.0/16
        - IpProtocol: icmp
          FromPort: -1
          ToPort: -1
          CidrIp: 0.0.0.0/0
```
</details>

> key pair 생성은 [AWS - Infra](https://assu10.github.io/dev/2022/10/10/aws-infra/) 의 *3. 사전 준비* 를 참고하세요.

![CF Stack 생성](/assets/img/dev/2022/1105/nat-1.png)


> **ICMP (Internet Group Management Protocol)**  
> ICMP 는 TCP/IP 에서 IP 패킷 처리 시 발생되는 문제를 알려주는 프로토콜임.  
> IP 에는 오로지 패킷을 목적지에 도달시키지 위한 내용들로만 구성이 되어 있기 때문에 정상적으로 목적지 도달 시 IP 에서 통신 성공 후 종료되므로
> 아무런 문제가 없지만, 목적지가 꺼져있거나 비정상인 경우 패킷 전달을 의뢰한 출발지에 이 사실을 알릴 수가 없음. (IP 에는 이러한 에러에 대한 처리 방법이
> 명시되지 있지 않으므로)  
> 
> 이러한 IP 의 부족한 점을 보완하는 것이 `ICMP` 프로토콜임.  
> 
> 예를 들어 `ping` 같은 경우도 `ICMP` 프로토콜을 이용한 방법임.

### 2.1.2. CloudFormation 을 통해 생성된 자원 확인

- **VPC**
  - ***jhNATInstance-VPC1***
    - IP CIDR: 10.10.0.0/16
- **IGW**
  - ***jhNATInstance-IGW1***
    - 연결: jhNATInstance-VPC1
- **Public Subnet**
  - ***jhNATInstance-VPC1-Subnet1***
    - IP CIDR: 10.10.1.0/24
    - AZ: ap-northeast-2a
- **Public Routing Table**
  - ***jhNATInstance-PublicRouteTable1***
    - 연결: jhNATInstance-VPC1-Subnet1
    - 라우팅 정보: 대상 0.0.0.0/0, 타깃: jhNATInstance-IGW1
- **Private Subnet**
  - ***jhNATInstance-VPC1-Subnet2***
    - IP CIDR: 10.10.2.0/24
    - AZ: ap-northeast-2a
- **Private Routing Table**
  - ***jhNATInstance-PrivateRouteTable1***
    - 연결: jhNATInstance-VPC1-Subnet2
- **EC2 Instance**
  - ***jhNAT-Instance***
    - 연결: jhNATInstance-VPC1-Subnet1
    - Private IP: 10.10.1.100 (EIP 연결)
    - AMI: amzn-ami-vpn-nat 포함된 AMI 사용
  - ***jhPrivate-EC2-1***
    - 연결: jhNATInstance-VPC1-Subnet2
    - Private IP: 10.10.2.101
    - SSH: Password 로그인 방식 활성화, root 로그인 활성화
  - ***jhPrivate-EC2-2***
    - 연결: jhNATInstance-VPC1-Subnet2
    - Private IP: 10.10.2.102
    - SSH: Password 로그인 방식 활성화, root 로그인 활성화
- **Security Group**
  - ***jhVPC1-NATInstance-SecurityGroup***
    - inbound rule
      - SSH/ICMP(Source) - 0.0.0.0/0
      - HTTP(S)(Source) - 10.10.0.0/16
  - ***jhVPC1-PrivateEC2-SecurityGroup***
    - inbound rule
      - SSH(Source) - 10.10.0.0/16
      - ICMP(Source) - 0.0.0.0.0/0

![CF Stack 생성 - 도식화](/assets/img/dev/2022/1105/nat-2.png)


### 2.1.3. 기본 통신 환경 검증

Private Subnet 의 EC2 Instance 는 외부에서 직접 SSH 접속이 불가하므로 Public Subnet 에 있는 NAT Instance 로 SSH 접속 후
다시 Private Subnet 의 Instance 로 접속한다.

```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx

# NAT Instance 의 Private IP 조회
[ec2-user@jhNAT-Instance ~]$ ifconfig eth0
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 9001
        inet 10.10.1.100  netmask 255.255.255.0  broadcast 10.10.1.255
        
# NAT Instance 에 연결된 EIP 조회
[ec2-user@jhNAT-Instance ~]$ curl http://checkip.amazonaws.com
13.124.xx.xx        
```

jhPrivateEC2-1 인스턴스로 SSH 접속 후 외부 통신 확인 (**통신 불가**)
```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx
[ec2-user@jhNAT-Instance ~]$ ssh root@10.10.2.101

# 외부 인터넷 통신 확인
[root@jhPrivate-EC2-1 ~]# curl http://checkip.amazonaws.com --connect-timeout 3
curl: (28) Failed to connect to checkip.amazonaws.com port 80 after 2988 ms: Connection timed out
```

jhPrivateEC2-2 인스턴스로 SSH 접속 후 외부 통신 확인 (**통신 불가**)
```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx
[ec2-user@jhNAT-Instance ~]$ ssh root@10.10.2.102

# 외부 인터넷 통신 확인
[root@jhPrivate-EC2-2 ~]# curl http://checkip.amazonaws.com --connect-timeout 3
curl: (28) Failed to connect to checkip.amazonaws.com port 80 after 2988 ms: Connection timed out
```


---

## 2.2. NAT Instance 구성

- NAT Instance 동작을 위한 스크립트 확인
- NAT Instance 동작을 위한 설정
- Private Subnet 에 위치한 Instance 에서 외부로 통신 확인

### 2.2.1. NAT Instance 동작을 위한 스크립트 확인

NAT Instance 동작을 위해 IPv4 라우팅 처리와 IP masquerade 동작을 확인한다.

```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.178.xx


# 아래 값이 1이면 IPv4 라우팅 처리 가능
[ec2-user@jhNAT-Instance ~]$ cat /proc/sys/net/ipv4/ip_forward
1

# iptable 의 NAT 정책에 IP masquerade 확인 
[ec2-user@jhNAT-Instance ~]$ sudo iptables -nL POSTROUTING -t nat -v
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
  659 50641 MASQUERADE  all  --  *      eth0    0.0.0.0/0            0.0.0.0/0
```

### 2.2.2. NAT Instance 동작을 위한 설정

#### 2.2.2.1. Private Subnet 에 라우팅 정보 추가

Private Subnet 에 외부 인터넷과 통신하기 위한 라우팅 정보를 추가한다.

*[VPC] - [Route tables] - [jhNATInstance-PrivateRouteTable1] - [Routes]*

![Private Subnet 에 라우팅 정보 추가](/assets/img/dev/2022/1105/nat-3.png)


#### 2.2.2.2. `Source/Destination Check` 비활성화

NAT Instance 는 자신이 목적지가 아닌 트래픽이 NAT Instance 를 경유해서 외부로 나가기 때문에 NAT Instance 의 `Source/Destination Check` 
기능을 비활성화한다.

*[EC2] - [Instances] - [*jhNAT-Instance*] - [Actions] - [Networking] - [Change source/destination check]*
![Source/Destination check 변경](/assets/img/dev/2022/1105/nat-4.png)


> `Source/Destination Check` 기능  
> 
> 기본적으로 인스턴스는 인스턴스로 들어오는 트래픽이 자신이 목적지가 아닌 IP 트래픽이 들어오거나,  
> 인스턴스에서 나가는 트래픽의 출발지 IP 가 자신이 아닐 경우 폐기하는데  
> 이 기능이 `Source/Destination Check` 임.  
> 
> 기본적으로 VPC 의 ENI (Elastic Network Interface) 는 활성화 상태임.

![NAT Instance 설정 후 - 도식화](/assets/img/dev/2022/1105/nat-5.png)


### 2.2.3. Private Subnet 에 위치한 Instance 에서 외부로 통신 확인

이제 *jhPrivate-EC2-1* 과 *jhPrivate-EC2-2* 에서 외부 인터넷 통신 여부를 확인한다.  

<**기본 환경**>  
jhPrivateEC2-1 인스턴스로 SSH 접속 후 외부 통신 확인 (**통신 불가**)
```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx
[ec2-user@jhNAT-Instance ~]$ ssh root@10.10.2.101

# 외부 인터넷 통신 확인
[root@jhPrivate-EC2-1 ~]# curl http://checkip.amazonaws.com --connect-timeout 3
curl: (28) Failed to connect to checkip.amazonaws.com port 80 after 2988 ms: Connection timed out
```

jhPrivateEC2-2 인스턴스로 SSH 접속 후 외부 통신 확인 (**통신 불가**)
```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx
[ec2-user@jhNAT-Instance ~]$ ssh root@10.10.2.102

# 외부 인터넷 통신 확인
[root@jhPrivate-EC2-2 ~]# curl http://checkip.amazonaws.com --connect-timeout 3
curl: (28) Failed to connect to checkip.amazonaws.com port 80 after 2988 ms: Connection timed out
```

<**NAT Instance 환경**>  
jhPrivateEC2-1 인스턴스로 SSH 접속 후 외부 통신 확인 (**통신 가능**)
```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx

[ec2-user@jhNAT-Instance ~]$ ssh root@10.10.2.101
root@10.10.2.101's password:  # qwe123
[root@jhPrivate-EC2-1 ~]# curl http://checkip.amazonaws.com --connect-timeout 3
13.124.178.83

# 외부로 ping (ICMP) 도 정상 통신
[root@jhPrivate-EC2-1 ~]# ping www.google.com
PING www.google.com (172.217.161.68) 56(84) bytes of data.
64 bytes from nrt20s09-in-f4.1e100.net (172.217.161.68): icmp_seq=1 ttl=104 time=34.6 ms
64 bytes from nrt20s09-in-f4.1e100.net (172.217.161.68): icmp_seq=2 ttl=104 time=34.6 ms
```

jhPrivateEC2-2 인스턴스로 SSH 접속 후 외부 통신 확인 (**통신 가능**)
```shell
$ ssh -i sandbox-jh.pem ec2-user@13.124.xx.xx
[ec2-user@jhNAT-Instance ~]$ ssh root@10.10.2.102
root@10.10.2.102's password:
[root@jhPrivate-EC2-2 ~]# curl http://checkip.amazonaws.com --connect-timeout 3
13.124.178.83

# 외부로 ping (ICMP) 도 정상 통신
[root@jhPrivate-EC2-2 ~]# ping www.google.com
PING www.google.com (172.217.161.68) 56(84) bytes of data.
64 bytes from nrt20s09-in-f4.1e100.net (172.217.161.68): icmp_seq=1 ttl=104 time=34.6 ms
64 bytes from nrt20s09-in-f4.1e100.net (172.217.161.68): icmp_seq=2 ttl=104 time=34.6 ms
```

이제 NAT Instance 에서 `tcpdump` 를 이용하여 *jhPrivate-EC2-n* 인스턴스에서 외부 통신 시 실제로 *jhNAT-Instance* 를 경유하는지 확인해보자.  

```shell
# tcpdump 로 TCP 80 포트만 모니터링
[ec2-user@jhNAT-Instance ~]$ sudo tcpdump -nni eth0 tcp port 80

tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
04:46:26.589478 IP 10.10.2.101.55634 > 99.80.82.214.80: Flags [S], seq 2732866788, win 26883, options [mss 8961,sackOK,TS val 2900371052 ecr 0,nop,wscale 7], length 0
04:46:26.589511 IP 10.10.1.100.55634 > 99.80.82.214.80: Flags [S], seq 2732866788, win 26883, options [mss 8961,sackOK,TS val 2900371052 ecr 0,nop,wscale 7], length 0
04:46:26.821599 IP 99.80.82.214.80 > 10.10.1.100.55634: Flags [S.], seq 1126316262, ack 2732866789, win 26847, options [mss 1460,sackOK,TS val 4030072562 ecr 2900371052,nop,wscale 8], length 0
04:46:26.821627 IP 99.80.82.214.80 > 10.10.2.101.55634: Flags [S.], seq 1126316262, ack 2732866789, win 26847, options [mss 1460,sackOK,TS val 4030072562 ecr 2900371052,nop,wscale 8], length 0
```

위 로그를 보면 출발지 IP 가 **10.10.2.101 (jhPrivate-EC2-1)** 에서 **10.10.1.100 (jhNAT-Instance)** 로 변환되는 것을 확인할 수 있다.

---

## 2.3. Resource 삭제

아래의 순서대로 Resource 를 삭제한다.

- CloudFormation Stack 삭제 (*[CloudFormation] - [Stacks] - [Delete]*)

CloudFormation Stack 이 삭제되면 위의 [2.1.2. CloudFormation 을 통해 생성된 자원 확인](#212-cloudformation-을-통해-생성된-자원-확인) 의 자원이
모두 삭제되었는지 확인한다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김원일, 서종호 저자의 **따라하며 배우는 AWS 네트워크 입문**를 기반으로 스터디하며 정리한 내용들입니다.*

* [따라하며 배우는 AWS 네트워크 입문](http://www.yes24.com/Product/Goods/93887402)
* [따라하며 배우는 AWS 네트워크 입문 - 책가이드](https://www.notion.so/ongja/AWS-1af579548fd84c268f8f3ee3f26b2ed4)
* [따라하며 배우는 AWS 네트워크 입문 - 팀블로그](https://gasidaseo.notion.site/gasidaseo/CloudNet-Blog-c9dfa44a27ff431dafdd2edacc8a1863)
* [Proxy Instance](https://www.notion.so/LabGuide-Proxy-Squid-Instance-VPC-Outbound-Filtering-96c05f0481044fe0baf9094d3035895d)
* [IP Masquerade 란?](https://nsinc.tistory.com/100)