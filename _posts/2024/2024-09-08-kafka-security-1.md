---
layout: post
title:  "Kafka - 보안(1): 보안 프로토콜(TLS, SASL), 인증(SSL, SASL)"
date: 2024-09-08
categories: dev
tags: kafka tls ssl sasl kafkaPrincipal
---

이 포스트에서는 아래의 내용에 대해 알아본다.

- 카프카의 보안 기능
- 각 기능이 보안의 서로 측면을 어떻게 담당하는지?
- 카프카의 보안에 어떻게 기여하는지?
- 모범 사례, 잠재적인 위협, 이 위협을 완화시킬 방법

사용 가능한 가장 강력하고 최신인 보안 기능을 사용하는 것이 좋지만, 보안을 향상시키면 성능, 비용, 사용자 경험 측면에서 손해가 발생할 수밖에 없기 때문에 어느 정도의 
정출은 필수적이다.  
카프카는 각 활용 사례에 맞는 보안 설정을 지원하기 위해 여러 표준 보안 기술과 다양한 설정 옵션을 제공한다.

---

**목차**

<!-- TOC -->
* [1. 카프카의 보안](#1-카프카의-보안)
* [2. 보안 프로토콜: `inter.broker.listener.name`, `security.inter.broker.protocol`](#2-보안-프로토콜-interbrokerlistenername-securityinterbrokerprotocol)
  * [2.1. TLS(Transport Layer Security) vs SSL(Secure Sockets Layer)](#21-tlstransport-layer-security-vs-sslsecure-sockets-layer)
  * [2.2. SASL(Simple Authentication and Security Layer) vs SSL(Secure Sockets Layer)](#22-saslsimple-authentication-and-security-layer-vs-sslsecure-sockets-layer)
* [3. 인증: `KafkaPrincipal`](#3-인증-kafkaprincipal)
  * [3.1. SSL(Secure Sockets Layer)](#31-sslsecure-sockets-layer)
    * [3.1.1. TLS 설정: `ssl.client.auth`](#311-tls-설정-sslclientauth)
      * [3.1.1.1. 자체 서명 인증서로 키스토어와 트러스트스토어 생성](#3111-자체-서명-인증서로-키스토어와-트러스트스토어-생성)
      * [3.1.1.2. 브로커, 클라이언트에 TLS 설정](#3112-브로커-클라이언트에-tls-설정)
      * [3.1.1.3. 키스토어, 트러스트스토어 갱신](#3113-키스토어-트러스트스토어-갱신)
    * [3.1.2. 주의 사항](#312-주의-사항)
  * [3.2. SASL(Simple Authentication and Security Layer)](#32-saslsimple-authentication-and-security-layer)
  * [3.3. 재인증: `connections.max.reauth.ms`](#33-재인증-connectionsmaxreauthms)
  * [3.4. 무중단 보안 업데이트](#34-무중단-보안-업데이트)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- mac os
- openjdk 17.0.12
- zookeeper 3.9.2
- apache kafka: 3.8.0 (스칼라 2.13.0 에서 실행되는 3.8.0 버전)

---

# 1. 카프카의 보안

카프카는 데이터의 기밀성과 가용성을 보장하기 위해 아래와 같은 보안 절차를 사용한다.
- **인증(Authentication)**
  - 사용자가 누구인지 식별
- **인가(Authorization)**
  - 사용자가 무엇을 할 수 있는지 결정
- **암호화(Encryption)**
  - 누설과 위조로부터 데이터 보호
- **감사(Auditing)**
  - 사용자가 무엇을 했는지 추적
- **쿼터(Quotas)**
  - 자원을 얼마나 많이 사용할 수 있는지 조절

아래는 카프카 클러스터에서 데이터가 어떻게 흐르는지에 대한 그림이다.  
이번 포스트에서는 개발 과정 전체에 있어서 보안성을 보장하기 위해 각 단계에서 카프카를 어떻게 설정하는지에 대해 아래 예시 그림의 흐름을 사용한다.

![카프카 클러스터 내 데이터 흐름](/assets/img/dev/2024/0908/kafka.png)

① 앨리스는 _customerOrders_ 토픽의 파티션에 고객 주문 정보를 씀  
레코드를 해당 파티션의 리더를 맡고 있는 브로커에게 보내짐  
② 리더 브로커는 레코드를 로컬 로그 파일에 씀  
③ 팔로워 브로커는 리더 브로커로부터 메시지를 받아서 로컬 레플리카 로그 파일에 씀  
④ 필요할 경우 리더 브로커는 주키퍼에 저장된 파티션 상태의 ISR(In-Sync Replica) 정보를 갱신함  
⑤ 밥이 _customerOrders_ 토픽에서 고객 주문 정보를 읽음 (①에서 앨리스가 쓴 레코드 읽어옴)  
⑥ 내부 애플리케이션이 _customerOrders_ 토픽애서 가져온 모든 메시지를 처리한 후 가장 많이 팔린 상품에 대한 실시간 지표 생성

<**안전한 카프카 클러스터 특징**>
- **클라이언트 진정성(Client Authenticity)**
  - 앨리스가 사용하고 있는 클라이언트가 브로커로 연결을 맺을 때, 브로커는 전송된 메시지가 정말 앨리스로부터 온 것인지 클라이언트를 인증
- **서버 진정성(Server Authenticity)**
  - 리더 브로커에게 메시지를 보내기 전에, 앨리스의 클라이언트는 해당 연결이 실제 브로커와 맺어진 것임을 검증
- **기밀성(Data Privacy)**
  - 메시지가 전달되는 도중에 있는 모든 연결은 암호화되어서 외부에서 엿보거나 훔칠 수 없어야 함
- **무결성(Data Integrity)**
  - 안전하지 못한 네트워크를 통해 전송되는 모든 데이터에 메시지 다이제스트(digest) 를 포함하여 내용물 변조 시 알아차릴 수 있어야 함
- **접근 제어(Access Control)**
  - 메시지를 로그에 쓰기 전에, 리더 브로커는 앨리스가 _customerOrders_ 에 쓰기 권한이 있는지 확인
  - 밥의 컨슈머에 메시지를 전달하기 전에, 브로커는 밥이 해당 토픽에 읽기 권한이 있는지 확인
  - 만일 밥의 컨슈머가 그룹 관리 기능을 쓰고 있다면, 브로커는 밥이 해당 컨슈머 그룹에 접근할 권한이 있는지도 검증
- **감사 가능성(Auditability)**
  - 브로커, 앨리스, 밥, 클라이언트들이 수행하는 모든 작업을 보여주는 감시용 기록이 남아야 함
- **가용성(Availability)**
  - 브로커는 사용 가능한 대역폭을 독차지하거나 브로커에 서비스 거부 공격을 가하는 것을 방지하기 위해 쿼터와 제한을 두어야 함
  - 브로커의 가용성은 주키퍼의 가용성과 주키퍼 안에 저장된 메타데이터의 일관성에 의존하기 때문에 주키퍼 역시 카프카 클러스터의 가용성을 보장하기 위해 보호되어야 함

> **메시지 다이제스트(Digest)**
> 
> 해시 함수의 출력값으로, 주로 데이터의 무결성을 확인하거나 인증 목적으로 사용됨  
> 입력 데이터의 내용을 고정된 길이의 문자열로 변환하는 과정
> 
> 주요 해시 알고리즘으로는 MD5, SHA, Blake2 가 있음

> **서비스 거부 공격(Denial of Service, Dos)**
> 
> 과도한 트래픽이나 요청을 발생시켜서 정상적인 사용자가 서비스를 이용하기 못하도록 만드는 사이버 공격  
> DoS 공격은 주로 시스템 과부하, 리소스 고갈, 네트워크 대역폭을 점유(엄청난 양의 데이터 전송)하는 방식으로 이루어짐

이제 위와 같은 특징을 보장하기 위해 사용할 수 있는 카프카의 보안 기능에 대해 알아본다.

- [카프카의 연결 모델과 클라이언트에서 브로커로의 연결에 적용되는 보안 프로토콜](#2-보안-프로토콜-interbrokerlistenername-securityinterbrokerprotocol)
- 각 보안 프로토콜을 살펴보면서 프로토콜별로 서버와 클라이언트의 진정성 검증을 위해 사용 가능한 인증 기능에는 무엇이 있는지
- 카프카에서 접근 권한을 관리하기 위해 사용되는 커스터마이즈 가능한 인가 기능과 감사 사능성에 도움을 주는 로그들
- 가용성을 유지하기 위해 주키퍼, 플랫폼 등에 할 수 있는 보안들

> 쿼터 기능에 대한 내용은 [5. 쿼터](https://assu10.github.io/dev/2024/06/22/kafka-producer-2/#5-%EC%BF%BC%ED%84%B0) 를 참고하세요.

---

# 2. 보안 프로토콜: `inter.broker.listener.name`, `security.inter.broker.protocol`

카프카 브로커에는 1개 이상의 엔드포인트를 가진 리스너 설정이 있는데, 클라이언트로부터의 연결을 받는 것이 이 리스너이다.  
각각의 리스너는 각자의 보안 설정을 가질 수 있다.

카프카는 2개의 표준 인증 기술(TLS, SASL) 을 사용해서 4개의 보안 프로토콜을 지원한다.

- **TLS(Transport Layer Security)**
  - 서버와 클라이언트 사이의 **인증** 뿐 아니라 **암호화**도 지원
- **SASL(Simple Authentication and Security Layer)**
  - 연결 지향 프로토콜에서 서로 다른 메커니즘을 사용한 인증을 지원하는 프레임워크

<**카프카가 제공하는 보안 프로토콜 4가지**>
- **`PLAINTEXT`**
  - PLAINTEXT 전송 계층에는 **인증이 존재하지 않음**
  - 사설 네트워크 안에서 인증이나 암호화가 필요없을 정도로 민감하지 않은 데이터를 처리할 때만 적합함
- **`SSL`**
  - SSL 전송 계층은 선택적으로 클라이언트 SSL 인증을 수행할 수 있음
  - **암호화, 클라이언트/서버 인증도 지원**되기 때문에 안전하지 않은 네트워크에 적합함
- **`SASL_PLAINTEXT`**
  - SASL 인증과 PLAINTEXT 전송 계층이 합쳐진 것
  - **서버 인증은 지원**하지만 **암호화는 지원하지 않으므로** 사설 네트워크 안에서만 적합함
- **`SASL_SSL`**
  - SASL 인증과 SSL 전송 계층이 합쳐진 것
  - **암호화, 클라이언트/서버 인증도 지원**되므로 안전하지 않은 네트워크에서 적절함

`inter.broker.listener.name` 이나 `security.inter.broker.protocol` 설정을 통해 브로커 간의 통신에서 사용되는 리스너를 선택할 수 있다.  
이 경우 브로커가 다른 브로커 리스너에 연결을 맺을 때는 클라이언트로서 맺기 때문에 브로커 간 통신과 관련된 보안 프로토콜 설정에 서버 쪽과 클라이언트 쪽 옵션을 모두 넣어주어야 한다.

브로커 간 통신 및 내부 네트워크용 리스너에는 SSL을, 외부용 리스너에는 SASL_SSL 을 사용하는 예시

```shell
# 브로커가 수신 요청을 대기하는 실제 주소
listeners=EXTERNAL://:0902,INTERNAL://10.0.0.1:9093,BROKER://10.0.0.1:9004

# 브로커가 클라이언트와 통신할 때 접근 가능한 주소 설정
# 브로커가 클라이언트에게 자신을 알릴 때 사용하는 주소와 포트 지정 (클라이언트가 브로커에 연결할 때 사용할 주소)
advertised.listeners=EXTERNAL://broker1.test.com:9092,INTERNAL://broker1.local:9093,BROKER://broker1.local:9094

listener.security.protocol.map=EXTERNAL:SASL_SSL,INTERNAL:SSL,BROKER:SSL
inter.broker.listener.name=BROKER
```

---

## 2.1. TLS(Transport Layer Security) vs SSL(Secure Sockets Layer)

TLS(Transport Layer Security) 는 SSL(Secure Sockets Layer) 의 발전된 버전으로 SSL 을 대체하는 프로토콜이다.  
둘 다 데이터를 암호화하여 통신의 보안을 유지하는데 사용된다.  
주요 기능은 암호화, 무결성(데이터가 변조되지 않도록 보장), 인증(서버 및 클라이언트의 신원 확인) 가 있다.

SSL 은 취약점이 존재하여 더 이상 사용되지 않으며, 현재는 SSL 대신 TLS 를 사용하는 것이 표준이다.  
HTTPS 연결을 통해 웹사이트 접속 시 TLS 가 사용되더라도 'SSL 인증서' 라는 표현을 쓰는데 이는 관습적으로 사용되는 것이며, 'TLS 인증서' 가 더 정확한 표현이다.

---

## 2.2. SASL(Simple Authentication and Security Layer) vs SSL(Secure Sockets Layer)

SASL 과 SSL 은 용도가 약간 겹칠 뿐 목적 자체가 전혀 다른 기술이다.

- **SASL**
  - 종단 간에 사용할 인증 방식을 서로 합의할 수 있도록 해주는 프레임워크
  - 인증 방식을 합의하는 방법과 절차를 정의할 뿐, 구체적인 인증 작업을 OAUTHBEARER 등의 인증 프로토콜이 구현함
  - 즉, 사용자 인증을 위한 인증 메커니즘 정의
  - 애플리케이션 계층에서 동작함
  - 사용 사례: IMAP, SMTP, LDAP
  - 애플리케이션에 의존하므로 핸드셰이크가 없음
- **SSL**
  - 공개 키 암호화를 사용한 통신 프로토콜
  - 종단 사이에 교환되는 메시지를 안전하게 보호하는 것이 목표임
  - 네트워크 통신을 암호화하여 데이터의 기밀성과 무결성 보장
  - 전송 계층에서 동작함(TCP/IP 기반)
  - 사용 사례: HTTPS, SMTPS, FTPS
  - 암호화 채널 설정 시 핸드셰이크가 있음 (핸드셰이크를 통해 암호화 방식과 인증서 교환)

<**SASL 과 SSL 동작 방식**>
- **SASL**
  - 클라이언트와 서버가 SASL 을 지원하는 프로토콜로 통신 시작
  - SASL 은 다양한 인증 메커니즘을 제공하여 사용자 인증 수행
  - 인증이 완료되면 통신 프로토콜은 정상적으로 동작
- **SSL**
  - 클라이언트와 서버가 핸드셰이크 과정을 통해 암호화 방식과 인증서 교환
  - 대칭 키를 생성하여 암호화된 통신 채널 설정
  - 이후 모든 데이터가 암호화된 상태로 전송

애플리케이션에서 네트워크 통신 보안 기능을 추가하려면 아래와 같은 경우의 수가 있다.
- SSL 암호화를 사용할 것인가?
- SASL 을 사용한 인증 기능을 사용할 것인가?

카프카 리스너에 설정할 수 있는 보안 프로토콜이 2*2=4개 인 것도 바로 이 때문이다.  
카프카 브로커가 클라이언트의 요청을 받는 소켓을 생성할 때 리스너 설정에 들어있는 보안 프로토콜 이름을 기준으로 거기에 맞는 소켓을 생성하기 때문이다.
- **리스너 설정이 PLAINTEXT:// 로 시작**
  - SSL 암호화와 SASL 인증 둘 다 사용안함(기본값)
- **리스너 설정이 SSL:// 로 시작**
  - SSL 암호화는 사용하지만 SASL 인증은 사용하지 않음
- **리스너 설정이 SASL_PLAINTEXT:// 로 시작**
  - SSL 암호화는 사용하지 않지만 SASL 인증 기능은 사용함
- **리스너 설정이 SASL_SSL:// 로 시작**
  - SSL 암호화와 SASL 인증 둘 다 사용함

이렇게 SASL 과 SSL(TLS) 는 동시에 사용될 수도 있다.  
예) SMTP 프로토콜에서 SSL 을 사용하여 안전한 연결을 설정한 후, SASL 을 통해 사용자 인증

SSL 의 경우 서버 쪽이 보유하고 있는 인증서를 클라이언트가 확인하는 식으로 동작하지만, 브로커 역시 클라이언트 쪽이 보유하고 있는 인증서를 확인하도록 설정을 잡아줄 수 있다. (`ssl.client.auth=required`)  
이 기능을 쓸 때는 클라이언트 간에 서로 다른 인증서를 발급해서 사용하는 것이 보통이기 때문에 결과적으로 상호 인증이 되어버린다.  
즉, 브로커 입장에서는 인증서를 확인하는 순간 클라이언트가 누구인지 알 수 있기 때문에 SSL 은 암호화 통신 프로토콜이지만 인증 기능도 어느 정도 한다고 할 수 있다.

결과적으로 SASL 과 SSL 은 서로 다른 목적을 가진 별개의 기술이지만 역할이 조금 겹치거나 거의 항상 서로에게 의존하여 사용된다.

---

# 3. 인증: `KafkaPrincipal`

여기서는 각각의 보안 프로토콜에 대해 브로커와 클라이언트에서 사용 가능한 프로토콜 한정 설정 옵션들에 대해 알아본다.

인증은 **서버와 클라이언트 사이에서 서로의 신원을 확인하는 과정**이다.

A 라는 유저의 클라이언트가 레코드를 쓰기 위해 리더 브로커로 접속할 때 각 서버와 클라이언트 단은 아래와 같은 인증 과정을 진행한다.
- 클라이언트 인증
  - A 의 신원(비밀번호, 디지털 인증서 등)을 확인하여 연결된 유저가 A 의 신원을 사칭하고 있는지 검증
- 서버 인증
  - 제 3자가 아닌 실제 브로커와 연결 설정

카프카는 클라이언트 신원을 나타내기 위해 `KafkaPrincipal` 객체를 사용한다.  
`KafkaPrincipal` 는 자원에 대한 접근을 허가하거나, 해당 클라이언트에 쿼터를 할당할 때도 사용하며, `KafkaPrincipal` 객체는 인증 프로토콜에 의한 인증 과정에서 설정된다.  
예) 비밀번호 기반 인증에서 이름이 A 인 유저에 대해서 _User:A_ 라는 인증 주체가 사용됨

> **익명 연결**
> 
> 비인증 연결의 경우 _User:ANONYMOUS_ 가 보안 주체로 사용됨  
> 이것은 PLAINTEXT 리스너로 접속하는 클라이언트 뿐 아니라 SSL 리스너로 접속했지만 인증을 하지 않은 클라이언트에도 적용됨

`KafkaPrincipal` 는 브로커의 `principal.builder.class` 설정을 통해 커스터마이징 가능하다.

---

## 3.1. SSL(Secure Sockets Layer)

여기서는 **SSL 암호화 기능을 하기 위한 각종 연관 설정을 하는 방법**에 대해 알아본다.

카프카 리스너의 보안 프로토콜이 SSL 이나 SASL_SSL 로 설정된 경우 TLS 보안 전송 계층이 사용된다.  
TLS 를 통해 연결이 생성되면 TLS 핸드셰이크 과정에서 인증, 암호화 매개변수 교환, 암호화는 위한 공개 키 생성 등이 처리된다.  
클라이언트는 서버 신원을 확인하기 위해 서버의 디지털 인증서를 검증하고, SSL 을 사용한 클라이언트 인증 기능이 활성화되어 있다면 서버 역시 클라이언트의 디지털 인증서를 검증하여 
신원을 확인한다.

> **SSL 성능**
> 
> SSL 채널은 앙호화되기 때문에 CPU 사용 시 오버헤드가 발생하며, SSL 에서의 [제로카피](https://assu10.github.io/dev/2024/07/13/kafka-mechanism-1/#42-%EC%9D%BD%EA%B8%B0-%EC%9A%94%EC%B2%AD) 전송은 
> 지원되지 않음  
> 트래픽 패턴에 따라 20~30% 의 오버헤드 발생 가능성 있음

---

### 3.1.1. TLS 설정: `ssl.client.auth`

<**브로커 리스너에 SSL 혹은 SASL_SSL 을 사용하여 TLS 기능을 활성화시킬 경우**>
- **클라이언트**
  - 브로커의 인증서 혹은 브로커 인증서에 서명한 인증기관(CA, Certificate Authority) 의 인증서를 포함하는 **트러스트스토어(truststore) 가 설정**되어야 함
- **브로커**
  - 비밀키와 인증서를 포함하고 있는 **키스토어(keystore) 가 설정**되어야 함

키스토어는 SSL 인증서와 개인 키를 저장하는 파일이고, 트러스트스토어는 신뢰할 수 있는 인증서를 저장하는 파일이다.

> **트러스트스토어(truststore)**
> 
> 잘 알려진 인증기관에 의해 서명된 인증서를 사용할 경우, 브로커든 클라이언트든 트러스트스토어 설정 생략이 가능함  
> 예) 자바를 설치할 때 함께 설치되는 기본 트러스트스토어

브로커 인증서는 SAN(Subject Alternative Name) 혹은 CN(Common Name) 항목에 브로커 호스트명이 설정되어 있어서 클라이언트가 검증할 수 있도록 해야 한다.  
와일드카드 인증서를 사용하면 모든 브로커가 같은 키스토어를 사용하게 됨으로써 관리가 단순해진다.

> **서버 호스트네임 검증**
> 
> 호스트네임 검증은 TLS 핸드셰이크 과정에서 클라이언트가 서버의 인증서를 검증할 때, 인증서에 포함된 호스트네임(주로 CN 이나 SAN 필드에 명시됨)과 실제 서버의 호스트네임이 일치하는지 확인하는 과정임  
> 호스트네임 검증을 통해 클라이언트는 통신하고자 하는 대상이 신뢰할 수 있는 서버(=인증서에 명시된 서버)인지 확인할 수 있음
> 
> 기본적으로 카프카 클라이언트는 서버의 인증서에 저장되어 있는 서버 이름과 클라이언트가 접속을 시도하는 호스트명이 일치하는지 검증함  
> 접속을 시도하는 호스트명은 클라이언트에 설정된 부트스트랩 서버이거나, 메타데이터 응답으로 리턴되는 [`advertised.listeners`](https://assu10.github.io/dev/2024/07/06/kafka-adminclient-1/#21-clientdnslookup) 에 포함된 
> 호스트명이어야 함
> 
> 호스트명 검증은 서버 인증 시 중간자 공격(MITM, Man-in-the-Middle)을 방지하는 역할이므로 프로덕션 환경에서는 절대 끄면 안됨

<**클라이언트-브로커 통신에서의 서버 호스트네임 검증**>
- 카프카 클라이언트가 브로커와 TLS 를 통해 연결을 설정할 때 브로커의 인증서가 클라이언트에 의해 검증됨
- 클라이언트는 브로커의 인증서에서 호스트네임을 확인하여 브로커가 설정한 호스트네임과 일치하지 않으면 연결이 거부됨

<**브로커 간 통신에서의 서버 호스트네임 검증**>
- 위와 동일한 방식으로 호스트네임 검증을 수행함
- 브로커 간의 보안 연결을 강화하여 중간자 공격을 방지함

카프카는 기본적으로 호스트네임 검증이 활성화되어 있으며, `ssl.endpoint.identification.algorithm` 설정을 통해 비활성화할 수도 있다.

server.properties or client.properties (카프카 커넥트를 사용한다면 connect-distributed.properties 또는 connect-standalone.properties)

```properties
# 호스트네임 검증 활성화(기본값)
ssl.endpoint.identification.algorithm=HTTPS

# 호스트네임 검증 비활성화
ssl.endpoint.identification.algorithm=
```

<**`ssl.client.auth` 의 옵션값**>
- **required**
  - 클라이언트 인증서를 필수로 요구함
- **requested**
  - 클라이언트 인증서를 요청하되, 없어도 허용함
- **none**
  - 클라이언트 인증서를 요청하지 않음

<**브로커에 `ssl.client.auth=required` 설정할 경우**>
- 브로커에 `ssl.client.auth=required` 설정을 함으로써 SSL 을 통해 접속하는 클라이언트를 인증할 수 있도록 설정 가능함
- **클라이언트**
  - **키스토어**를 사용하도록 설정되어야 함
- **브로커**
  - 클라이언트 인증서 혹은 클라이언트 인증서에 서명한 인증기관의 인증서를 포함하는 **트러스트스토어**가 설정되어야 함
- **브로커 간 통신**에 SSL 을 사용한다면 브로커의 트러스트스토어는 클라이언트 인증서의 인증기관 인증서 뿐 아니라 브로커 인증서의 인증기관 인증서도 포함해야 함

<**브로커에 `ssl.client.auth=requested` 설정할 경우**>
- SSL 클라이언트 인증 기능을 선택 사항으로 만듦
- 이 경우 키스토어 설정이 되어있지 않은 클라이언트는 TLS 핸드셰이크를 마칠 수 있지만, _User:ANONYMOUS_ 보안 주체가 할당됨

기본적으로 인가와 쿼터 적용 시 클라이언트 인증서의 DN(Distinguished Name) 항목이 보안 주체인 `KafkaPrincipal` 로 사용된다.  
보안 주체를 커스터마이징하기 위해 적용할 규칙은 `ssl.principal.mapping.rules` 에서 설정 가능하다.

<**SASL_SSL 을 사용하는 리스너**>
- TLS 를 통한 클라이언트 인증 기능을 비활성화시키고, SASL 인증을 대신 사용함
- 보안 주체 역시 SASL 에 의해 결정된 것을 사용함

---

#### 3.1.1.1. 자체 서명 인증서로 키스토어와 트러스트스토어 생성

자체 서명 인증서를 사용하여 서버와 클라이언트 간의 인증에 사용될 키스토어와 트러스트스토어를 생성하는 방법에 대해 알아본다.

**브로커에서 사용할 자체 서명 인증서 키 쌍 생성**

```shell
$ pwd
/Users/Developer/kafka

# 인증서용 키 쌍 생성 후 PKCS12 형식 파일인 server.ca.p12 에 저장
# 이 키 쌍을 서명용 인증서로 사용할 예정
$ keytool -genkeypair -keyalg RSA -keysize 2048 -keystore server.ca.p12 \
-storetype PKCS12 -storepass server-ca-password -keypass server-ca-password \
-alias ca -dname "CN=BrokerCA" -ext bc=ca:true -validity 365

Generating 2,048 bit RSA key pair and self-signed certificate (SHA384withRSA) with a validity of 365 days
	for: CN=BrokerCA

$ ls 
rw-r--r--   1 assu  staff   2.5K Jan 25 13:57 server.ca.p12

# CA 공공 인증서를 server.ca.crt 로 저장
# 이것은 트러스트스토어와 인증서 체인에 포함될 것임	
$ keytool -export -file server.ca.crt -keystore server.ca.p12 \
-storetype PKCS12 -storepass server-ca-password -alias ca -rfc

Certificate stored in file <server.ca.crt>

$ ls 
-rw-r--r--   1 assu  staff   1.0K Jan 25 13:59 server.ca.crt
```

---

자체 서명된 CA 에 의해 서명된 인증서를 사용하여 **브로커에서 사용할 키스토어 생성**

```shell
# 브로커에서 사용할 비밀 키를 생성한 후 server.ks.p12 라는 이름의 PKCS12 형식 파일로 저장
$ keytool -genkey -keyalg RSA -keysize 2048 -keystore server.ks.p12 \
-storepass server-ks-password -keypass server-ks-password -alias server \
-storetype PKCS12 -dname "CN=Kafka,O=Confluent,C=GB" -validity 365

Generating 2,048 bit RSA key pair and self-signed certificate (SHA384withRSA) with a validity of 365 days
	for: CN=Kafka, O=Confluent, C=GB

$ ll
-rw-r--r--   1 assu  staff   2.6K Jan 25 14:08 server.ks.p12	

# 인증서 서명 요청(CSR, Certificate Signing Request) 생성
$ keytool -certreq -file server.csr -keystore server.ks.p12 -storetype PKCS12 \
-storepass server-ks-password -keypass server-ks-password -alias server

$ ll 
-rw-r--r--   1 assu  staff   1.0K Jan 25 14:10 server.csr

# CA 키스토어를 사용하여 브로커의 인증서 서명
# 서명된 인증서는 server.crt 에 저장됨
$ keytool -gencert -infile server.csr -outfile server.crt \
-keystore server.ca.p12 -storetype PKCS12 -storepass server-ca-password \
-alias ca -ext SAN=DNS:broker1.test.com -validity 365

$ ll 
-rw-r--r--   1 assu  staff   810B Jan 25 14:13 server.crt

$ cat server.crt server.ca.crt > serverchain.crt

$ ll 
-rw-r--r--   1 assu  staff   1.8K Jan 25 14:22 serverchain.crt

# 브로커의 인증서 체인을 브로커의 키스토어로 불러옴
$  keytool -importcert -file serverchain.crt -keystore server.ks.p12 \
-storepass server-ks-password -keypass server-ks-password -alias server \
-storetype PKCS12 -noprompt

Certificate reply was installed in keystore
```

위에서 호스트네임에 와일드카드를 사용할 경우 모든 브로커에 대해 동일한 키스토어가 사용될 수 있다.  
그게 아니라면 각 브로커별로 전체 주소 도메인 네임(FQDN, Fully Qualified Domain Name) 을 사용하여 키스토어를 따로 생성해야 한다.

---

브로커간 통신에 TLS 가 사용될 경우 브로커끼리 서로 인증할 수 있도록 브로커의 CA 인증서를 사용하여 **브로커용 트러스트스토어를 생성**한다.

```shell
$ keytool -import -file server.ca.crt -keystore server.ts.p12 \
-storetype PKCS12 -storepass server-ts-password -alias server -noprompt

Certificate was added to keystore

$ ll 
-rw-r--r--   1 assu  staff   1.1K Jan 25 14:26 server.ts.p12
```

---

브로커의 CA 인증서를 사용하여 **클라이언트용 트러스트스토어를 생성**한다.

```shell
$ keytool -import -file server.ca.crt -keystore client.ts.p12 \
-storetype PKCS12 -storepass clienet-ts-password -alias server -noprompt

Certificate was added to keystore

$ ll 
-rw-r--r--   1 assu  staff   1.1K Jan 25 14:28 client.ts.p12
```

---

**TLS 클라이언트 인증이 활성화되어 있는 경우 클라이언트는 키스토어와 함께 설정**되어야 한다.  
아래는 **클라이언트용으로 자체 서명된 CA 를 생성한 후, 클라이언트 CA 로 서명된 인증서를 사용하여 클라이언트용 키스토어를 생성**한다.  
브로커가 클라이언트를 인증할 수 있도록 **클라이언트 CA 는 브로커의 트러스트스토어에 추가**되어야 한다.

**클라이언트가 사용할 자체 서명된 CA 키 쌍 생성**

```shell
# 클라이언트용으로 사용할 새로운 CA 생성
$ keytool -genkeypair -keyalg RSA -keysize 2048 -keystore client.ca.p12 \
-storetype PKCS12 -storepass client-ca-password -keypass clinet-ca-password \
-alias ca -dname CN=ClientCA -ext bc=ca:true -validity 365

Warning:  Different store and key passwords not supported for PKCS12 KeyStores. Ignoring user-specified -keypass value.
Generating 2,048 bit RSA key pair and self-signed certificate (SHA384withRSA) with a validity of 365 days
	for: CN=ClientCA

$ ll 
-rw-r--r--   1 assu  staff   2.5K Jan 25 18:43 client.ca.p12

# CA 공공 인증서를 client.ca.crt 로 저장
# 이것은 트러스트스토어와 인증서 체인에 포함될 것임
$ keytool -export -file client.ca.crt -keystore client.ca.p12 \
-storetype PKCS12 -storepass client-ca-password -alias ca -rfc
Certificate stored in file <client.ca.crt>

$ ll 
-rw-r--r--   1 assu  staff   1.0K Jan 25 19:04 client.ca.crt
```

---

**자체 서명된 CA 에 의해 서명된 인증서를 사용하여 클라이언트에서 사용할 키스토어 생성**

```shell
# 클라이언트에서 사용할 비밀 키를 생성한 후 client.ks.p12 라는 이름의 PKCS12 형식 파일로 저장
# 이 인증서를 사용하는 클라이언트는 인증 주체의 기본값으로 User:CN=Metric App,O=Confluent,C=GB 를 사용함
$ keytool -genkey -keyalg RSA -keysize 2048 -keystore client.ks.p12 \
-storepass client-ks-password -keypass client-ks-password -alias client \
-storetype PKCS12 -dname "CN=Metric App,O=Confluent,C=GB" -validity 365

Generating 2,048 bit RSA key pair and self-signed certificate (SHA384withRSA) with a validity of 365 days
	for: CN=Metric App, O=Confluent, C=GB

$ ll 
-rw-r--r--   1 assu  staff   2.6K Jan 25 18:55 client.ks.p12

# 인증서 서명 요청(CSR, Certificate Signing Request) 생성
$ keytool -certreq -file client.csr -keystore client.ks.p12 -storetype PKCS12 \
-storepass client-ks-password -keypass client-ks-password -alias client

$ ll
-rw-r--r--   1 assu  staff   1.0K Jan 25 18:58 client.csr

# CA 키스토어를 사용하여 클라이언트의 인증서 서명
# 서명된 인증서는 client.crt 에 저장됨
$ keytool -gencert -infile client.csr -outfile client.crt \
-keystore client.ca.p12 -storetype PKCS12 -storepass client-ca-password \
-alias ca -validity 365

$ ll
-rw-r--r--   1 assu  staff   785B Jan 25 19:00 client.crt

$ cat client.crt client.ca.crt > clientchain.crt

$ ll
-rw-r--r--   1 assu  staff   1.8K Jan 25 19:09 clientchain.crt

# 클라이언트의 인증서 체인을 클라이언트의 키스토어에 추가함
$ keytool -importcert -file clientchain.crt -keystore client.ks.p12 \
-storepass client-ks-password -keypass client-ks-password -alias client \
-storetype PKCS12 -noprompt

Certificate reply was installed in keystore
```

---

**브로커의 트러스트스토어는 모든 클라이언트의 CA 를 포함**해야 한다.

```shell
# 클라이언트 CA 인증서를 브로커의 트러스트스토어에 추가함
$ keytool -import -file client.ca.crt -keystore server.ts.p12 \
-storetype PKCS12 -storepass server-ts-password -alias client -noprompt
Certificate was added to keystore

$ ll 
-rw-r--r--   1 assu  staff   1.9K Jan 25 19:17 server.ts.p12
```

---

#### 3.1.1.2. 브로커, 클라이언트에 TLS 설정

키스토어와 트러스트스토어가 준비되었으면 이제 브로커에 TLS 를 설정할 수 있다.  
브로커는 브로커 간의 통신에 TLS 가 사용되거나 클라이언트 인증 기능이 활성화된 경우에만 트러스트스토어가 필요하다.

SSL 설정을 활성화하는 카프카 브로커 설정(server.properties)

```properties
# SSL 키스토어 파일 경로 지정, 키스토어는 SSL 인증서와 개인 키를 저장하는 파일임
ssl.keystore.location=/path/to/server.ks.p12
# 키스토어 파일을 보호하기 위해 설정된 암호 설정, keytool 명령에서 설정한 키스토어 암호와 동일해야 함
ssl.keystore.password=server-ks-password
# 키스토어 내부의 개인키를 보호하기 위한 암호 설정, 키를 생성할 때 설정한 암호와 동일해야 함
ssl.key.password=server-ks-password
# 키스토어 파일 형식 지정
ssl.keystore.type=PKCS12
# 트러스트스토어 파일 경로 지정, 트러스트스토어는 신뢰할 수 있는 인증서를 저장하는 파일임
ssl.truststore.location=/path/to/server.ts.p12
# 트러스트스토어 파일의 암호 설정, keytool 명령으로 트러스트스토어를 생성할 때 설정한 암호와 동일해야 함
ssl.truststore.password=server-ts-password
# 트러스트스토어 파일 형식 지정
ssl.truststore.type=PKCS12
# 클라이언트 인증을 필수로 요구
ssl.client.auth=required
```

생성된 트러스트스토어를 사용하여 클라이언트를 설정한다.  
클라이언트 인증 기능이 필요한 경우 클라이언트에 키스토어야 설정되어야 한다.

클라이언트 측에서 SSL 인증서를 사용하여 브로커와 통신할 때 사용하는 카프카 클라이언트 설정(client.properties)

```properties
# 클라이언트가 신뢰할 수 있는 인증서를 저장하는 트러스트스토어 파일 경로 설정, 브로커 인증서를 검증하기 위해 사용됨
ssl.truststore.location=/path/to/client.ts.p12
# 트러스트스토어 파일에 접근하기 위한 암호
ssl.truststore.password=client-ts-password
# 트러스트스토어 파일 형식 지정
ssl.truststore.type=PKCS12
# 클라이언트의 개인 키와 인증서를 저장하는 키스토어 파일 경로 설정, 클라이언트의 신원을 증명하기 위해 사용됨
ssl.keystore.location=/path/to/client.ks.p12
# 키스토어 파일에 접근하기 위한 암호 설정
ssl.keystore.password=client-ks-password
# 키스토어 내부의 개인 키를 보호하기 위한 암호 설정
ssl.key.password=client-ks-password
# 키스토어 파일 형식 지정
ssl.keystore.type=PKCS12
```

---

#### 3.1.1.3. 키스토어, 트러스트스토어 갱신

TLS 핸드셰이크가 실패하는 것을 방지하려면 인증서가 만료되기 전에 키스토어와 트러스트스토어를 주기적으로 갱신해주어야 한다.  
브로커 SSL 저장소는 같은 파일을 덮어쓰거나, 설정 옵션이 새 버전의 파일을 가리키게 하여 동적으로 갱신이 가능하다.  
어떤 경우든 간에 Admin API 와 카프카 설정 툴을 사용하여 변경 가능하다.

아래는 카프카 설정 툴을 사용하여 0번 브로커의 외부 리스너에 사용될 키스토어를 갱신하는 예시이다.

```shell
$ bin/kafka-configs.sh --bootstrap-server localhost:9092 \
--command-config admin.props \
--entity-type brokers --entity-name 0 --alter --add-config \
'listener.name.external.ssl.keystore.location=/path/to/server.ks.p12'
```

브로커와 클라이언트 양쪽에 상대편의 인증서를 넣은 뒤 `ssl.client.auth=required` 설정을 하여 상호 인증이 가능하다.  
`kafka-configs.sh` 툴을 사용하여 브로커의 키스토어와 트러스트스토어를 동적으로 갱신(hot reload) 할 수도 있다.

이렇게 **서버 쪽 저장소는 동적으로 갱신이 가능하지만 클라이언트에 대해서는 그런 기능이 없다.**

브로커의 경우 단순히 설정을 조금 바꾸기 위해 재시작하는 것이 큰 부담이지만 클라이언트의 경우 재시작에 대한 부담이 상대적으로 적기 때문에 갱신이 필요하다면 
클라이언트를 재시작하는 것 외엔 방법이 없다.

이는 대부분의 경우 문제가 되지 않지만 보안을 강화하기 위해 클라이언트쪽 인증서의 유효 기간 등을 동적으로 업데이트하는 기법을 사용한다면 신경을 쓸 필요가 있다.  
컨슈머 그룹에 컨슈머가 추가되거나 제거될 때마다 리밸런싱이 발생함으로써 작업이 지연될 수도 있기 때문에 관련 기능을 작업할 때는 이 부분도 고려해야 한다.

---

### 3.1.2. 주의 사항

카프카는 기본적으로 TLSv1.2 와 TLSv1.3 이후의 프로토콜만을 지원한다.

> 카프카 버전 3.4 부터는 자바 8 이후 버전만을 지원하고 있고, 버전 3.7 부터는 자바 17 이후 버전만을 지원하고 있음    
> TLSv1.3 은 자바 11부터 지원됨  
> 자바 11 이상 버전을 사용하는 경우 자동으로 TLSv1.3 이 활성화되는 것이 기본값임

**재교섭(renegotiation) 관련 보안 이슈가 있기 때문에 TSL 연결 시 재교섭 기능도 지원하지 않는다.**  
카프카가 TLS 연결에서 재교섭은 지원하지 않는다는 것은 초기 TLS 핸드셰이크 이후 인증서 교체, 암호화 키 변경 등의 보안 설정을 다시 협상할 수 없음을 의미한다. 
따라서 보안 매개변수를 변경하려면 기존 연결을 종료하고 새로운 TLS 세션을 생성해야 한다.

> **TLS 의 재교섭(renegotiation)**
> 
> 이미 설정된 TLS 연결을 통해 보안 매개변수를 다시 협상하거나 인증 정보를 갱신하는 과정임  
> 이는 클라이언트와 서버 간에 새로운 핸드셰이크 과정을 거쳐 초기 연결 설정 시 사용된 암호화 키, 인증 정보 등을 변경할 수 있도록 함
> 
> **TLS 재교섭은 아래와 같은 순서로 동작함**
> - 초기 핸드셰이크
>   - 클라이언트와 서버가 TLS 연결 설정 (여기서 암호화 키와 보안 매개변수가 정해짐)
> - 재교섭 요청
>   - 클라이언트 또는 서버가 기존 연결이 유지된 사태에서 새로운 보안 설정을 요청함 (예를 들어 더 강력한 암호화 방식을 적용하거나, 인증 정보를 업데이트하고 싶을 때)
> - 재협상 핸드셰이크
>   - 초기 핸드셰이크와 유사한 과정이 수행되지만, 기존 연결을 닫지 않고 새로운 매개변수를 적용함
> 
> **재교섭은 아래와 같을 때 사용됨**
> - 클라이언트 인증 추가
>   - 서버가 초기 연결 시엔 클라이언트 인증을 요구하지 않았지만, 이후 특정 조건에서 클라이언트 인증을 요청해야 할 때
> - 보안 강화
>   - 장시간 유지되는 연결에서 암호화 키를 주기적으로 변경하여 보안을 강화할 때
> - 속도 조정
>   - 초기 연결에서는 비교적 약한 암호화 키를 사용하여 연결 속도를 빠르게 한 후, 연결 안정화 이후 더 강력한 암호화 키로 교체할 때

> **Kafka 와 TLS 재교섭**
> 
> 카프카에서는 아래와 같은 이유로 TLS 재교섭을 지원하지 않음
> 
> - 성능 문제
>   - 재교섭은 추가적인 핸드셰이크 과정을 필요로 하므로 성능 저하를 유발할 수 있음
> - 보안 이슈
>   - 과거 TLS 프로토콜에서 재교섭은 중간자 공격(MITM, Man-in-the-Middle) 공격에 취약점이 있었기 때문에 이를 방지하기 위해 많은 시스템이 재교섭을 비활성화하거나 완전히 제거했음
> - 단순화
>   - 카프카는 고속 데이터 스트리밍을 위해 설계된 시스템으로 불필요한 시스템을 최소화하고자 함

**암호화 스위트(cipher suite) 를 제한**하여 TLS 연결에서 사용하는 암호화 알고리즘과 키 교환 방식을 설정하여 보안을 향상시킬 수도 있다.

server.properties or client.properties

```properties
ssl.cipher.suites=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
```

암호화 스위트를 설정할 때는 아래와 같은 사항을 고려해야 한다.
- 클라이언트와 브로커 간 호환성
  - 클라이언트와 브로커 모두 설정된 암호화 스위트를 지원해야 함
- 자바 버전
  - 사용 중인 자바 버전이 지정된 암호화 스위트를 지원해야 함
- TLS 버전
  - 특정 암호화 스위트는 TLS 버전에 의존하므로 `ssl.protocol` 설정에서 적절한 TLS 버전을 함께 지정해야 함
  - 
```properties
ssl.protocol=TLSv1.2
```

> **암호화 스위트(cipher suite)**
> 
> 암호화 스위트는 TLS 프로토콜에서 사용되는 암호화 알고리즘의 조합임  
> 각 스위트는 아래의 구성 요소로 이루어짐
> - **키 교환 알고리즘**
>   - 클라이언트와 서버 간의 암호화 키를 교환하는 방식
>   - 예) RSA, ECDHE
> - **대칭 키 암호화 알고리즘**
>   - 데이터 암호화를 위한 알고리즘
>   - 예) AES
> - **메시지 인증 코드(MAC)**
>   - 데이터의 무결성을 보장하는 알고리즘
>   - 예) SHA-256

비밀 키를 저장하는 키스토어는 기본적으로 파일 시스템에 저장하도록 되어 있으므로, 파일 시스템 권한을 사용하여 **키스토어 파일에 접근할 수 있는 권한을 제한**할 필요가 있다.

**비밀 키가 위조되면 인증서를 페기**할 수 있도록 자바 표준 TLS 기능을 사용해도 된다. 이 경우 수명이 짧은 키를 사용하여 키의 노출 시간을 줄일 수 있다.

TLS 핸드셰이크는 자원을 많이 소비하고, 브로커의 네크워크 스레드를 상당히 사용한다.  
TLS 를 사용하는 리스너는 브로커의 가용성을 확보하기 위해 **연결에 쿼터나 제한을 두어 서비스 거부 공격(DoS, Denial of Service)을 막아낼 수 있어야 한다.**

- **연결 수 제한**
  - TLS 리스너를 통해 브로커로 들어오는 연결 수 제한
  - 단일 클라이언트가 과도한 연결을 생성하는 것을 방지함

```properties
# 리스너별 프로토콜 매핑 정의
listener.security.protocol.map=TLS_LISTENER:SSL

# 최대 연결수 정의
num.network.threads=3
max.connections=1000
```
- **데이터 처리량 제한**
  - 클라이언트가 전송하거나 수신할 수 있는 데이터의 최대 처리량 제한

```properties
# 프로듀서 데이터 전송 속도 제한 (바이트/초)
quota.producer.byte-rate=1048576  # 1MB/s

# 컨슈머 데이터 수신 속도 제한 (바이트/초)
quota.consumer.byte-rate=2097152  # 2MB/s
```
- **브로커별 연결 제한**
  - 브로커 전체에서 허용되는 최대 연결 수 제한

```properties
# IP 당 최대 연결 수
max.connections.per.ip=100

# 특정 IP 에 대한 연결 제한
max.connections.per.ip.overrides=192.168.1.1:50
```
- **인증 시간 제한**
  - TLS 핸드셰이크 및 클라이언트 인증 프로세스에 시간 제한을 두어 과도한 인증 요청으로 인해 발생할 수 있는 리소스 낭비 방지

```properties
# 비활성 연결에 대한 최대 유휴 시간
connections.max.idle.ms=300000  # 5분
```
- **클라이언트-브로커 리소스 분리**
  - 클라이언트별 쿼터를 사용하여 특정 클라이언트가 브로커 리소스를 독점하지 못하도록 함

인증에 실패한 클라이언트가 재시도하는 속도를 제한하려면 브로커 설정의 `connection.failed.authentication.delay.ms` 옵션으로 실패한 인증에 대해 응답하는 시간을 늦추면 된다.

---

## 3.2. SASL(Simple Authentication and Security Layer)

여기서는 **브로커-클라이언트, 브로커-브로커 사이에 사용될 인증 프로토콜과 관련된 설정을 하는 방법**에 대해 알아본다.

카프카 프로토콜은 SASL 을 사용한 인증을 지원하며, SASL 메커니즘을 기본적으로 지원한다.  
전송 계층에 SASL 과 TLS 을 함께 사용함으로써 인증과 암호화를 동시에 지원하는 안전한 채널 사용이 가능하다.

SASL 인증은 서버가 챌린지(challenge) 를 내놓으면 클라이언트가 여기에 응답하는 순으로 수행된다.

카프카 브로커는 기본적으로 아래와 같은 **SASL 메커니즘**과 함께 커스터마이징 가능한 콜백을 지원한다.
- **GSSAPI**
  - SASL/GSSAPI 를 사용하는 케르베로스 인증이 지원됨
  - Active Directory 나 OpenLDAP 과 같은 케르베로스 서버와 통합할 때 사용됨
- **PLAIN**
  - 사용자 이름/암호 인증
  - 보통 외부 비밀번호 저장소를 사용하여 비밀번호를 검증하는 서버 측 커스텀 콜백과 함께 사용됨
- **SCRAM-SHA-256 and SCRAM-SHA-512**
  - 추가적인 비밀번호 저장소를 설정할 필요 없이 카프카를 설치하자마자 바로 사용 가능한 사용자 이름/암호 인증
- **OAUTHBEARER**
  - OAuth bearer 토큰을 사용한 인증
  - 표준화된 OAuth 서버에서 부여된 토큰을 추출하고 검증하는 커스텀 콜백과 함께 사용됨

- 브로커
  - 각 SASL 이 활성화된 리스너테엇는 해당 리스너의 `sasl.enabled.mechanism` 설정을 사용하여 1개 이상의 SASL 메커니즘 활성화 간ㅇ
- 클라이언트
  - `sasl.mechanism` 설정을 사용하여 활성화된 메커니즘 중 하나를 선택

카프카는 자바 인증 및 인가 서비스(JAAS, Java Authentication and Authorization Service) 를 사용하여 SASL 을 설정한다.  
`sasl.jaas.config` 설정 옵션은 하나의 JAAS 설정 엔트리를 포함하는데, 사용할 로그인 모듈과 옵션이 여기에 지정된다.

`sasl.jaas.config` 를 설정할 때 브로커는 리스너와 메커니즘을 앞에 붙인다.  
예) listener.name.external.gssapi.sasl.jaas.config 는 EXTERNAL 이라는 이름을 가진 리스너의 SASL/GSSAPI 메커니즘 엔트리에 대한 JAAS 설정이 들어감

JAAS 설정 파일은 브로커와 클라이언트 사이의 로그인 과정에서 인증에 필요한 공개 자격 증명, 비밀 자격 증명을 결정할 때 사용한다.

JAAS 설정은 자바의 시스템 속성인 `java.security.auth.login.config` 를 사용하여 파일 형태로 정의될 수도 있지만 카프카가 `sasl.jaas.config` 옵션이 더 권장된다.  
이유는 비밀번호 보호 기능이 있고, 하나의 리스너에 다수의 메커니즘이 활성화되어 있을 경우 각 SASL 메커니즘에 대한 설정을 분리할 수 있기 때문이다.

카프카가 지원하는 **SASL 메커니즘은 콜백 핸들러**를 사용하여 서드 파티 인증 서버와 통합할 수도 있다.  
- 로그인 과정을 커스터마이징하기 위해 브로커나 클라이언트에 로그인 콜백 핸들러를 설정하여 인증에 사용될 자격 증명을 얻어옴
- 클라이언트가 제출한 자격 증명을 인증하기 위해 서버 콜백 핸들러를 사용하여 비밀 번호를 외부 비밀번호 서버에 보내서 검증함

> SASL/GSSAPI, SASL/PLAIN, SASL/SCRAM, SASL/OAUTHBEARER, 위임 토큰 에 대한 상세 내역을 필요할 때 보는 걸로...

---

## 3.3. 재인증: `connections.max.reauth.ms`

카프카 브로커는 클라이언트가 새로운 연결을 맺는 시점에 클라이언트 인증을 수행한다.

케르베로스나 OAuth 와 같은 보안 메커니즘은 유효기간이 있는 자격 증명을 사용한다.  
카프카는 기존 자격 증명이 만료되기 전에 새로운 자격 증명을 얻어오기 위해 백그라운드에서 돌아가는 로그인 스레드를 사용하지만, 새로운 자격 증명은 기본적으로 
새로운 연결에만 적용된다.  
예전 자격 증명을 사용하여 인증에 성공한 기존 연결들은 요청 타임아웃, 유휴 타임아웃 등의 이유로 연결이 끊어질 때까지 멀쩡하게 동작한다.

- **브로커 측의 재인증**
  - 브로커는 `connections.max.reauth.ms` 옵션을 사용하여 SASL 로 인증된 연결을 재인증할 수 있돋록 함
  - 이 옵션 설정값을 0 보다 큰 정수값으로 잡아주면 브로커는 SASL 연결의 세션 수명을 체크하고 있다가, 클라이언트와 SASL 핸드셰이크를 수행할 때 클라이언트에게 이 값을 알려줌
  - 세션 수명은 자격 증명의 잔여 수명과 `connections.max.reauth.ms` 값 중 작은 값임
  - 이 기간 동안 재인증을 하지 않은 연결을 브로커가 강제로 종료시킴
- **클라이언트 측의 재인증**
  - 백그라운드에서 돌아가는 로그인 스레드가 얻어오거나, 커스텀 콜백을 사용하여 주입된 최신 자격 증명값을 사용하여 재인증 수행

만일 사용자가 위조된 경우 가능하면 빨리 시스템에서 해당 사용자를 삭제해야 한다.  
사용자가 인증 서버에서 삭제되는 순간부터 해당 사용자가 카프카 브로커로 시도하는 모든 새로운 연결 시도는 인증에 실패한다.  
이미 맺어진 연결을 재인증 타임아웃 때까지 계속 동작하는데, 만일 `connections.max.reauth.ms` 과 타임아웃 설정이 없다면 위조된 사용자로 맺어진 연결을 오랫동안 
계속 동작한다.  
카프카의 SSL 은 재교섭을 지원하지 않으므로 이미 맺어진 SSL 연결은 인증 과정에서 사용한 인증서가 폐기되거나 만료되어도 계속해서 동작한다.  
이 때는 해당 보안 주체에 대해 Deny ACL 을 사용하면 된다.  
ACL 변경은 매우 짧은 시간 안에 모든 브로커에 대해 적용되므로 위조된 사용자의 접근을 방지하는 가장 빠른 방법이다.

---

## 3.4. 무중단 보안 업데이트

비밀번호 순환, 보안 패치 적용, 최신 보안 프로토콜 업데이트 등의 작업을 하기 위해 정기적으로 카프카를 정비해주어야 한다.  
대부분의 정비 작업은 카프카 브로커를 하나씩 정지시킨 후 설정을 업데이트한 후에 다시 실행시키는 롤링 업데이트 방식으로 이루어진다.  
SSL 키스토어나 트러스트스토어를 업데이트하는 작업은 브로커를 재시작할 필요없이 동적 설정 업데이트 기능을 사용하여 할 수 있다.

사용 중인 클러스터에 새로운 보안 프로토콜을 추가할 때는 브로커에 오래된 프로토콜을 사용하는 기존 리스너를 그대로 두고, 새로운 프로토콜을 사용하는 리스너를 추가함으로써 
업데이트 도중에도 클라이언트 애플리케이션이 오래된 리스너를 사용해서 동작할 수 있도록 한다.  
예) 이미 사용중인 클러스터에서 PLAINTEXT 에서 SASL_SSL 로 옮겨갈 때

이미 사용중인 SASL 리스너에 새로운 SASL 메커니즘을 추가/삭제할 때는 클러스터를 정지할 필요 없이 동일 리스너 포트에 대해 롤링 업데이트를 해주는 것만으로 가능하다.  
예) SASL 메커니즘을 PLAINTEXT 에서 SCRAM-SHA-256 으로 교체

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)
* [Doc:: Kafka](https://kafka.apache.org/documentation/)
* [Git:: Kafka](https://github.com/apache/kafka/)