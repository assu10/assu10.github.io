---
layout: post
title:  "AWS - Load Balancing (3): CloudFront"
date:   2022-11-26 10:00
categories: dev
tags: devops aws cdn cloudfront
---

이 포스트는 CDN 과 AWS 에서 제공하는 CDN 서비스인 CloudFront 에 대해 알아본다.

<!-- TOC -->
* [1. CDN (Contents Delivery Network)](#1-cdn-contents-delivery-network)
* [2. CloudFront](#2-cloudfront)
* [3. CloudFront 를 통한 CDN 서비스 테스트](#3-cloudfront-를-통한-cdn-서비스-테스트)
  * [3.1. 기본 환경 구성](#31-기본-환경-구성)
    * [3.1.1. CloudFormation 적용](#311-cloudformation-적용)
    * [3.1.2. CloudFormation 을 통해 생성된 자원 확인](#312-cloudformation-을-통해-생성된-자원-확인)
    * [3.1.3. Route 53 설정 (EC2 Instance A Record 연결)](#313-route-53-설정-ec2-instance-a-record-연결)
    * [3.1.4. 기본 통신 환경 검증](#314-기본-통신-환경-검증)
  * [3.2. CloudFront 설정과 Route 53 연결](#32-cloudfront-설정과-route-53-연결)
    * [3.2.1. CloudFront Distribution 생성](#321-cloudfront-distribution-생성)
    * [3.2.2. Route 53 설정 (CloudFront A Record 연결)](#322-route-53-설정-cloudfront-a-record-연결)
    * [3.2.3. CloudFront 검증](#323-cloudfront-검증)
  * [3.3. Resource 삭제](#33-resource-삭제)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

아래는 이번 포스트에서 다뤄볼 범위 도식화이다.

![이번 포스트 범위 도식화](/assets/img/dev/2022/1126/1126_design.png)


# 1. CDN (Contents Delivery Network)

콘텐츠 제공자와 사용자 간 지리적으로 떨어져있는 환경에서 콘텐츠를 빠르게 제공하기 위한 기술이다.  
CDN 이 없는 환경에서 오리진 서버는 모든 사용자 요청에 대해 일일이 처리하는 과부하 환경이며, 지리적으로 떨어져있는 경우 지연 시간이 길어진다.

CDN 은 오리진 서버로부터 지역적으로 분산되어 있는 캐시 서버로 콘텐츠를 분배하고, 각 지역의 사용자는 인접한 캐시 서버로부터 콘텐츠를 전달받아 원활한 서비스를
제공받을 수 있다.

오리진 서버에 저장된 콘텐츠를 캐시 서버로 저장하는 것을 **캐싱**이라고 한다.  
캐시 서버에서 콘텐츠를 갖고 있으면 `Cache Hit`, 갖고 있지 않으면 `Cache Miss` 라고 하는데 `Cache Miss` 인 경우 오리진에 원본 콘텐츠를 요청하여
저장한다.

- Static Caching (정적 캐싱)
  - 이미지 파일, 자바스크립트, CSS 등 정적인 콘텐츠 캐싱
- Dynamic Caching (동적 캐싱)
  - 사용자 요청에 의해 생성되는 동적 콘텐츠
  - 캐싱하더라도 Cache Hit 가 높지 않아 캐싱의 이점을 얻기 어렵지만 CDN 을 통해 배포하게 되면 오리진 서버를 보호하고,
  보다 빠른 콘텐츠를 제공받을 수 있음
  - Dynamic Caching 은 실제 콘텐츠를 캐싱하지 않기 때문에 TTL 은 0으로 설정됨

---

# 2. CloudFront

CloudFront 는 AWS 에서 제공하는 CDN 기능으로, 오리진 대상의 콘텐츠를 캐싱하여 짧은 지연시간과 빠른 전송 속도로 전 세계 사용자에게 콘텐츠를 전송하는
CDN 서비스다.

CloudFront 의 주요 기능은 아래와 같다.
- **오리진 Selection**
  - 여러 오리진을 구성하여 콘텐츠 처리 가능
- **오리진 그룹을 통한 Failover**
  - 오리진 그룹 내의 기본 오리진과 보조 오리진을 구성하여 기본 오리진이 응답 불가한 상태이면 자동으로 보조 오리진으로 변환
- **SSL 지원**
  - 콘텐츠에 대해 SSL/TLS 를 통해 전송 가능
  - 고급 SSL 기능 (Full/Half 브릿지 HTTPS 연결, 필드 레벨 암호화 등) 을 자동으로 활성화 가능
- **액세스 제어**
  - Signed URL 과 Signed Cookie 를 사용하면 토큰 인증을 지원하며, 인증된 최종 사용자만 액세스하도록 제한 가능
- **보안**
  - DDoS 공격을 비롯한 여러 유형의 공격에 대해 계층형 보안 방어 가능
- **비용**
  - 사용한 만큼 지불하는 일반 요금과 약정 트래픽 개별 요금 제공
  - AWS 클라우드 서비스와 오리진에서 CloudFront 간 무료 데이터 전송
  - S3, EC2, ELB 같은 AWS 서비스가 오리진일 경우 오리진에서 CloudFront Edge Location 으로 전송되는 데이터는 요금이 청구되지 않음


![CloudFront Architecture 예시](/assets/img/dev/2022/1126/cloudfront_1.png)

① **오리진**  
- AWS 서비스 중 EC2, ELB, S3 가 오리진 대상이 될 수 있으며, 고객 데이터 센터의 별도 서버도 가능  

② **Distribution**  
- 오리진과 Edge Location 중간에서 콘텐츠를 배포하는 역할을 수행하는 CloudFront 의 독립적인 단위
- HTTP(S) 전용의 Web Distribution 과 동영상 콘텐츠 전용의 RTMP Distribution 으로 분류됨

③ **Edge Location**  
- 오리진에서 Distribution 을 통해 배포되는 콘텐츠를 캐싱하는 장치
- 리전별 Edge Cache 가 존재하고, 하위에 Edge Location 이 구성되어 콘텐츠 캐싱

④ **보안 장치**  
- OSI 3/4 계층 DDoS 를 완화하는 AWS Shield 및 OSI 7계층을 보호하는 AWS WAF 와 통합하여 보안을 강화

⑤ **도메인 구성**  
- Distribution 생성 시 *xxx.cloudfront.net* 형태의 도메인이 생성되는데 해당 도메인으로 접근해도 되고, Route 53 과 연결하여
사용자가 원하는 도메인으로 Alias 부여 가능

⑥ **사용자**  
- 위의 도메인으로 접근하여 콘텐츠 제공받음

---

# 3. CloudFront 를 통한 CDN 서비스 테스트

상파울루 리전에 EC2 Instance 구성 후 로컬(대한민국)에서 직접 연결하는 것과 AWS CloudFront 를 통한 CDN 서비스 연결하는 것의 차이를 알아본다.

- 기본 환경 구성
  - CloudFormation 적용
  - CloudFormation 을 통해 생성된 자원 확인
  - Route 53 설정 (EC2 Instance A Record 연결)
  - 기본 통신 환경 검증
- CloudFront 설정과 Route 53 연결
  - CloudFront Distribution 생성
  - Route 53 설정 (CloudFront A Record 연결)
  - CloudFront 검증
- Resource 삭제

![목표 구성도](/assets/img/dev/2022/1126/cloudfront_flow.png)

---

## 3.1. 기본 환경 구성

- CloudFormation 적용
- CloudFormation 을 통해 생성된 자원 확인
- Route 53 설정 (EC2 Instance A Record 연결)
- 기본 통신 환경 검증

![기본 환경 구성도](/assets/img/dev/2022/1126/cloudfront_2.png)

---

### 3.1.1. CloudFormation 적용

서울 리전이 아닌 상파울루 리전(sa-east-1) 에 AWS Resource 를 생성한다.

*[CloudFormation] - [Stacks]*

[CloudFormation Template Download](http://bit.ly/cnbl05031)

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

Resources:
  SaVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.10.0.0/16
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: jhSA-VPC

  SaIGW:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: jhSA-IGW

  SaIGWAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref SaIGW
      VpcId: !Ref SaVPC

  SaPublicRT:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref SaVPC
      Tags:
        - Key: Name
          Value: jhSA-Public-RT

  SaDefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: SaIGWAttachment
    Properties:
      RouteTableId: !Ref SaPublicRT
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref SaIGW

  SaPublicSN1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref SaVPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: 10.10.0.0/24
      Tags:
        - Key: Name
          Value: jhSA-Public-SN-1

  SaPublicSNRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref SaPublicRT
      SubnetId: !Ref SaPublicSN1

  WEBSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Enable HTTP access via port 80 and SSH access via port 22
      VpcId: !Ref SaVPC
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

  SaEC2:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref LatestAmiId
      Tags:
        - Key: Name
          Value: jhSA-EC2
      NetworkInterfaces:
        - DeviceIndex: 0
          SubnetId: !Ref SaPublicSN1
          GroupSet:
            - !Ref WEBSG
          AssociatePublicIpAddress: true
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          (
          echo "CN@12c"
          echo "CN@12c"
          ) | passwd --stdin root
          sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
          sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
          service sshd restart
          wget https://cloudneta.github.io/test.jpg
          wget -P /usr/share/nginx/html/ https://cloudneta.github.io/test.jpg
          amazon-linux-extras install -y nginx1.12
          echo "<head><link rel='icon' href='data:;base64,iVBORw0KGgo='></head><h1>CloudNet@ CloudFront Test!!</h1><img src='test.jpg'>" > /usr/share/nginx/html/index.html
          systemctl start nginx
          systemctl enable nginx
```
</details>

---

### 3.1.2. CloudFormation 을 통해 생성된 자원 확인

- **VPC**
  - ***jhSA-VPC***
    - IP CIDR: 10.10.0.0/16
- **Public Subnet**
  - ***jhSA-Public-SN-1***
    - IP CIDR: 10.10.0.0/24
    - AZ: sa-east-1a
- **Public Routing Table**
  - ***jhSA-Public-RT***
    - 연결: jhSA-Public-SN-1
- **IGW**
  - ***jhSA-IGW***
    - 연결: jhSA-VPC
- **Public EC2 Instance**
  - ***jhSA-EC2***
    - 연결: jhSA-Public-SN-1
    - 데몬: HTTP 구성
    - root 계정 로그인: 암호 CN@12c
- **Security Group**
  - ***jhWEB-SG***
    - 프로토콜(inbound): SSH, HTTP
    - 대상(Source): 0.0.0.0/0

![CF Stack 생성 - 도식화](/assets/img/dev/2022/1126/cloudfront_3.png)

---

### 3.1.3. Route 53 설정 (EC2 Instance A Record 연결)

Route 53 A Record 를 생성하여 ***jhSA-EC2*** Instance 의 Public IP 와 연결한다.

*[Route 53] - [Hosted zones] - [선택] - [Create record] - [Simple routing] - [Define simple record]*

![Route 53 Simple Record 정의 (jhSA-EC2 의 Public IP 와 연결)](/assets/img/dev/2022/1126/cloudfront_4.png)

> 중도에 *jhjhtest.com* 에서 *jhtesttest.com* 으로 도메인 재취득했음

---

### 3.1.4. 기본 통신 환경 검증

이제 상파울루 리전의 *jhSA-EC2* 로 웹접근을 해본다.  
해당 웹페이지에는 대용량 이미지가 구성되어 있어 지연시간이 꽤 길게 나올 것이다. 개발자 도구를 통해 지연시간을 확인해보자.

![jhSA-EC2 지연 시간 확인](/assets/img/dev/2022/1126/cloudfront_5.png)

캐시 삭제 후 재접속시에도 비슷하게 15s 정도 소요되는 것을 알 수 있다.

---

## 3.2. CloudFront 설정과 Route 53 연결

- CloudFront Distribution 생성
- Route 53 설정 (CloudFront A Record 연결)
- CloudFront 검증

![CloudFront 설정과 Route 53 연결 구성도](/assets/img/dev/2022/1126/cloudfront_6.png)

---

### 3.2.1. CloudFront Distribution 생성

CloudFront 에서 오리진을 EC2 Instance 로 지정할 때는 Public DNS 주소(=EC2 Instance 의 Public DNS 주소)가 필요하다.  

CloudFront Web Distribution 을 생성하여 오리진 웹 서버에 대한 콘텐츠를 전 세계의 Edge Location 으로 배포한다.

*[CloudFront] - [Distributions] - [Create distribution]*

**Origin Setting** 은 Origin 대상에 대한 설정을 하는 영역이다.

- `Origin domain`: Origin 에 대한 도메인 이름 지정
- `Origin path`: CloudFront 가 바라보는 Origin 의 기준 경로
- `custom header`: Origin 으로 보내는 요청에 사용자 지정 헤더 추가

![Distribution 생성 - Origin Settings](/assets/img/dev/2022/1126/cloudfront_7.png)

**Default cache behavior** 는 캐시에 대한 정책을 설정하는 영역이다.  
프로토콜, HTTP method, 캐시 정책 등을 설정한다.

- `Path pattern`: Origin 에서 가져올 콘텐츠에 대한 패턴 지정 (`*` 은 모든 콘텐츠)
- `Viewer protocol policy`: 사용자가 콘텐츠를 액세스하는데 사용할 프로토콜
- `Allowed HTTP methods`: 허용하는 HTTP method
- `Cache policy`: 최소/최대 TTL 설정 및 Cache 키 설정 (헤더, 쿠키, 쿼리)
- `Origin request policy`: Origin 요청에 대한 정책 설정 (헤더, 쿠키, 쿼리)

![Distribution 생성 - Default cache behavior Settings (모든 설정은 기본으로 유지)](/assets/img/dev/2022/1126/cloudfront_8.png)


**Distribution settings** 은 CloudFront Distribution 에 대해 설정을 하는 영역이다.  
Distribution Edge Location 영역 지정, CNAME (Canonical Name), SSL, 로깅 등을 설정한다.

Distribution 설정에서 Alternate Domain Name 을 부여하여 Route 53 과 연결할 예정인데, 이 때 연결 대상 도메인에 대해 SSL 인증서가 등록되어 있어야 한다.
AWS Certificate Manager(ACM) 에 들어가 인증서를 먼저 등록한다. (N.Virginia)

*[AWS Certificate Manager] - [Request certificate]*

![ACM 등록](/assets/img/dev/2022/1126/cloudfront_9.png)

ACM 등록 후 Status 를 보면 `Pending validation` 인 것 을 확인할 수 있는데, 검증을 위해선 Route 53 에 CNAME Record 를 추가해야 한다.  
아래에서 *Create records in Route 53* 을 누르면 CNAME Record 가 생성된다.

![ACM 등록 - Route 53 CNAME 등록](/assets/img/dev/2022/1126/cloudfront_10.png)

레코드 생성 후 잠시 기다리면 Status 가 `Pending validation` 에서 `Issued` 로 변경되며 등록이 완료된다.

> ACM 발급의 자세한 내용은 [AWS Certificate Manager 인증서  관리](https://www.notion.so/ongja/CNBA53-AWS-Certificate-Manager-4e7de7df4f3c449c9678da3abbfdd4c9) 을 참고하세요.

- `Price class`: 배포할 Edge Location 범위
- `Alternate domain name (CNAME)`: CloudFront Distribution 의 도메인 이름에 대한 alias 지정 (Route 53 도 설정)
- `Default root object`: 최상위 주소로 접근 시 보여줄 Root 대상 지정

![Distribution 생성 - Distribution settings](/assets/img/dev/2022/1126/cloudfront_11.png)

약 10~15분 후 Status 가 `Deploying` 에서 `Enabled` 로 변경되는 것을 확인할 수 있다. 

---

### 3.2.2. Route 53 설정 (CloudFront A Record 연결)

Route 53 A Record 를 생성하여 CloudFront Distribution 과 Alias 연결을 한다.

*[Route 53] - [Hosted zones] - [선택] - [Create record] - [Simple routing] - [Define simple record]*

![Route 53 Simple Record 생성 (CloudFront Alias 연결)](/assets/img/dev/2022/1126/cloudfront_12.png)

---

### 3.2.3. CloudFront 검증

이제 로컬에서 CloudFront Distribution 으로 웹 접근을 해본다.  
위의 *3.1.4. 기본 통신 환경 검증* 에서는 약 15s 가 소요된 부분을 기억하자.

![CloudFront Distribution 최초 접근](/assets/img/dev/2022/1126/cloudfront_13.png)

최초 접근 시 약 4s 가 소요되었다.

최초로 CloudFront Distribution 에 접근 시 오리진(EC2) 로부터 콘텐츠를 받고, CloudFront Distribution 은 설정된 모든 Edge Location 으로 콘텐츠를 배포한다.  
개발자 도구에서 이미지 파일 클릭 수 헤더 정보를 보면 `X-Cache` 필드값이 `Miss from cloudfront` 인 것을 확인할 수 있는데, 이것은 콘텐츠 응답을
Edge Location 이 아닌 Origin 을 통해 응답을 주었다는 것을 의미한다.

![CloudFront Distribution 최초 접근 시 헤더](/assets/img/dev/2022/1126/cloudfront_14.png)


![CloudFront Distribution 최초 접근 시 통신 흐름](/assets/img/dev/2022/1126/cloudfront_16.png)

① 사용자는 CloudFront Distribution 도메인(cdn.jhtesttest.com) 으로 웹 접근    
② Distribution 은 최초 연결이므로 Origin 서버인 jhSA-EC2 로 콘텐츠 요청 후 응답을 받음  
③ 사용자에게 웹 접근에 요청에 대한 응답을 줌  
④ Distribution 은 설정된 모든 Edge Location 으로 배포하여 동기화함  


이제 캐시를 지운 후 다시 CloudFront Distribution 으로 웹 접근을 해보자.

![CloudFront Distribution 최초 접근](/assets/img/dev/2022/1126/cloudfront_15.png)

약 1s 로 훨씬 짧은 지연시간과 이미지 파일의 헤더 정보 중 X-Cache 의 값이 `Hit from cloudfront` 인 것을 확인할 수 있다.  
이것은 콘텐츠 응답을 Edge Location 이 응답 주었다는 의미로, 사용자와 가장 인접한 Edge Location 이 응답해준 것을 의미한다.

![CloudFront Distribution 재접근 시 통신 흐름](/assets/img/dev/2022/1126/cloudfront_17.png)

① 사용자는 CloudFront Distribution 도메인(cdn.jhtesttest.com) 으로 웹 접근    
② 최초 접근 시 Edge Location 으로 콘텐츠가 배포된 상태이므로 사용자가 가장 인접한 Edge Location 이 응답해줌

---

## 3.3. Resource 삭제

아래의 순서대로 Resource 를 삭제한다.

- Distribution 삭제 (*[CloudFront] - [Distributions] - [선택] - [Disable] - [대기] - [Delete]*)
- ACM 삭제 (N.Virginia) (*[Certificate Manager]*)
- 호스팅 영역 Record 삭제 (*[Route 53] - [Hosted zones] - [Records]*)
- CloudFormation Stack 삭제 (*[CloudFormation] - [Stacks] - [Delete]*)
  - 상파울루 EC2 는 Public Subnet 에 위치하고, SSH 로그인 방식이 key 방식이 아닌 암호 입력 방식으로 SSH 무차별 대입 공격이 발생할 수 있으니 반드시 
  삭제를 확인할 것

CloudFormation Stack 이 삭제되면 위의 [3.1.2. CloudFormation 을 통해 생성된 자원 확인](#312-cloudformation-을-통해-생성된-자원-확인) 의 자원이
모두 삭제되었는지 확인한다.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김원일, 서종호 저자의 **따라하며 배우는 AWS 네트워크 입문**를 기반으로 스터디하며 정리한 내용들입니다.*

* [따라하며 배우는 AWS 네트워크 입문](http://www.yes24.com/Product/Goods/93887402)
* [따라하며 배우는 AWS 네트워크 입문 - 책가이드](https://www.notion.so/ongja/AWS-1af579548fd84c268f8f3ee3f26b2ed4)
* [따라하며 배우는 AWS 네트워크 입문 - 팀블로그](https://gasidaseo.notion.site/gasidaseo/CloudNet-Blog-c9dfa44a27ff431dafdd2edacc8a1863)
* [Amazon CloudFront 주요 기능](https://aws.amazon.com/ko/cloudfront/features/?whats-new-cloudfront.sort-by=item.additionalFields.postDateTime&whats-new-cloudfront.sort-order=desc)
* [AWS Certificate Manager 인증서  관리](https://www.notion.so/ongja/CNBA53-AWS-Certificate-Manager-4e7de7df4f3c449c9678da3abbfdd4c9)