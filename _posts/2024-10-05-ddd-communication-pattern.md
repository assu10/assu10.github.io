---
layout: post
title:  "DDD - 커뮤니케이션 패턴(모델 변환, 아웃박스 패턴, 사가 패턴)"
date: 2024-10-05
categories: dev
tags: ddd communication-pattern outbox-pattern saga-pattern
---

[DDD - 트랜잭션 스크립트 패턴, 액티브 레코드 패턴](https://assu10.github.io/dev/2024/08/25/ddd-transactionscript-activerecord/), 
[DDD - 도메인 모델 패턴](https://assu10.github.io/dev/2024/08/31/ddd-domain-model-pattern/),
[DDD - 이벤트 소싱 도메인 모델 패턴](https://assu10.github.io/dev/2024/09/08/ddd-event-sourcing-domain-model/), 
[DDD - 아키텍처 패턴(계층형 / 포트와 어댑터 / CQRS)](https://assu10.github.io/dev/2024/09/29/ddd-architecture-pattern/) 에서는 
시스템 컴포넌트를 구현하는 다양한 방법, 즉 비즈니스 로직을 모델링하는 방법과 바운디드 컨텍스트의 내부를 아키텍처 상에서 구성하는 전술적 설계 패턴에 대해 알아보았다.

이 포스트에서는 단일 컴포넌트의 경계를 넘어서 시스템 요소 전반의 커뮤니케이션 흐름을 구성하는 패턴에 대해 알아본다.

- 시스템 구성 요소의 작동을 조율하는데 필요한 패턴
- 시스템 구성 요소 간의 상호작용을 체계화하기 위한 기술적 문제와 구현 전략
- 바운디드 컨텍스트 연동을 지원하는 패턴
- 신뢰할 수 있는 메시지 발행을 구현하는 방법
- 복잡한 교차 구성 요소 워크플로를 정의하기 위한 패턴

커뮤니케이션 패턴은 아래와 같은 역할을 한다.
- 바운디드 컨텍스트 간의 커뮤니테이션을 용이하게 함
- 애그리거트 설계 원칙에 의해 만들어진 제한 사항을 해결함
- 여러 시스템 컴포넌트에 걸쳐 비즈니스 프로세스를 조율함


---

**목차**

<!-- TOC -->
* [1. 모델 변환](#1-모델-변환)
  * [1.1. Stateless 모델 변환](#11-stateless-모델-변환)
    * [1.1.1. 바운디드 컨텍스트가 동기식으로 통신](#111-바운디드-컨텍스트가-동기식으로-통신)
    * [1.1.2. 바운디드 컨텍스트가 비동기식으로 통신](#112-바운디드-컨텍스트가-비동기식으로-통신)
  * [1.2. Stateful 모델 변환](#12-stateful-모델-변환)
    * [1.2.1. 유입되는 데이터 집계](#121-유입되는-데이터-집계)
    * [1.2.2. 여러 요청 통합: BFF](#122-여러-요청-통합-bff)
* [2. 애그리거트 연동](#2-애그리거트-연동)
  * [2.1. 아웃박스(Outbox): 최 소 한번 이벤트 발행 보장](#21-아웃박스outbox-최-소-한번-이벤트-발행-보장)
  * [2.2. 사가(saga): 여러 트랜잭션에 걸친 비즈니스 로직](#22-사가saga-여러-트랜잭션에-걸친-비즈니스-로직)
    * [2.2.1. 사가 패턴의 일관성](#221-사가-패턴의-일관성)
  * [2.3. 프로세스 관리자](#23-프로세스-관리자)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 모델 변환

[DDD - 바운디드 컨텍스트 연동](https://assu10.github.io/dev/2024/08/24/ddd-bounded-context-linkage/) 에서 본 것처럼 서로 다른 바운디드 컨텍스트 간 
커뮤니케이션하기 위한 다양한 설계 패턴이 있다.

사용자-제공자 관계에서 권력은 업스트림(제공자) 또는 다운스트림(사용자) 바운디드 컨텍스트가 갖는다.  
만일 다운스트림 바운디드 컨텍스트가 업스트림 바운디드 컨텍스트 모델을 따를 수 없다면 바운디드 컨텍스트 모델을 변환하여 커뮤니케이션을 용이하게 하는 것보다 더 정교한 기술이 필요하다.

이 변환을 한쪽 혹은 양쪽 모두에서 처리할 수 있다.
- 다운스트림 바운디드 컨텍스트에서는 [충돌 방지 계층(ACL) 패턴](https://assu10.github.io/dev/2024/08/24/ddd-bounded-context-linkage/#22-%EC%B6%A9%EB%8F%8C-%EB%B0%A9%EC%A7%80-%EA%B3%84%EC%B8%B5acl-anticorruption-layer-%ED%8C%A8%ED%84%B4)을 사용하여 업스트림 바운디드 컼ㄴ텍스트의 모델을 필요게 맞게 조정
- 업스트림 바운디드 컨텍스트에서는 [오픈 호스트 서비스(OHS)](https://assu10.github.io/dev/2024/08/24/ddd-bounded-context-linkage/#23-%EC%98%A4%ED%94%88-%ED%98%B8%EC%8A%A4%ED%8A%B8-%EC%84%9C%EB%B9%84%EC%8A%A4ohs-open-host-service-%ED%8C%A8%ED%84%B4) 의 역할을 하고, 연동 관련 공표된 언어를 사용하여 구현 모델에 대한 변경으로부터 사용자를 보호

모델의 변환 로직은 2가지가 있다.
- Stateless 변환
  - 상태를 보존하지 않음
  - 수신(OHS) 또는 발신(ACL) 요청이 발행할 때 즉석에서 발생함
- Stateful 변환
  - 상태 보존을 위해 DB 를 사용하여 좀 더 복잡한 변환 로직을 다룰 수 있음

> **수신이 OHS, 발신이 ACL 로 해석된 이유**
> 
> OHS 는 제공자 측에서 구현하고, ACL 은 사용자 측에서 구현함  
> 하지만 ACL 이 다운스트림을 보호한다는 역할을 강조한 경우 ACL 이 업스트림 시스템의 요청을 받아서 변환하는 것이 아니라, 다운스트림 컨텍스트가 외부로 나가는 데이터를 
> 변환하는 역할을 한다는 관점에서 보면 발신이 ACL 이 됨
> 
> OHS 는 외부 시스템이 접근할 수 있도록 열려있는 서비스 인터페이스이므로 내부 도메인 컨텍스트가 외부에서 오는 요청을 수신하는 진입점 역할을 하므로 수신으로 해석함
> 
> 즉, OHS 는 유입되는 요청을 처리하고, ACL 은 업스트림 바운디드 컨텍스트를 호출함

이제 2가지 모델 변환을 구현하기 위한 디자인 패턴에 대해 알아본다.

---

## 1.1. Stateless 모델 변환

stateless 모델 변환을 소유하는 바운디드 컨텍스트는 프록시 디자인 패턴을 구현하여 수신과 발신 요청을 삽입하고, 소스 모델을 바운디드 컨텍스트의 목표 모델에 매핑한다.  
이 때 stateless 모델 변환을 소유하는 바운디드 컨텍스트는 업스트림의 경우 OHS, 다운스트림의 경우 ACL 이다.

![프록시에 의한 모델 변환](/assets/img/dev/2024/1005/proxy.png)

이 때 프록시 구현은 바운디드 컨텍스트가 동기식으로 통신하는지, 비동기식으로 통신하는지에 따라 다르다.

---

### 1.1.1. 바운디드 컨텍스트가 동기식으로 통신

동기식 통신에 사용하는 모델을 변환하는 방법은 2가지가 있다.
- 바운디드 컨텍스트의 코드베이스에 변환 로직 포함
  - 오픈 호스트 서비스(OHS) 에서 공용 언어로의 변환은 유입되는 요청 처리 시 발생
  - 충돌 방지 계층(ACL) 에서는 업스트림 바운디드 컨텍스트를 호출할 때 발생
- 변환 로직을 API Gateway 와 같은 외부 컴포넌트에 위임
  - 오픈 호스트 서비스(OHS) 를 구현하는 바운디드 컨텍스트의 경우 API Gateway 는 내부 모델을 통합에 최적화된 공표된 언어로 변환하는 역할을 함

![동기식 통신의 모델 변환](/assets/img/dev/2024/1005/sync.png)

---

### 1.1.2. 바운디드 컨텍스트가 비동기식으로 통신

비동기 통신에 사용하는 모델을 변환하기 위해 메시지 프록시를 구현할 수 있다.  
메시지 프록시는 소스 바운디드 컨텍스트에서 오는 메시지를 구독하는 중개 컴포넌트로, 필요한 모델 변환을 하여 결과 메시지를 대상 구독자에게 전달한다.  
또한, 중개 컴포넌트는 관련없는 메시지들을 필터링하여 목표 바운디드 컨텍스트의 노이즈를 줄일 수 있다.

![비동기식 통신의 모델 변환](/assets/img/dev/2024/1005/async.png)

오픈 호스트 서비스(OHS) 를 구현할 때 비동기식 모델 변환을 반드시 필요하다.  
오픈 호스트 서비스에서 내부 도메인 모델을 직접 노출하는 것은 흔한 실수이다.  
내부 모데인 모델이 직접 노출되면 이를 소비하는 외부 시스템들이 영향을 받게 되고 이는 곧 결합도가 높아지는 문제가 발생하게 된다.

비동기 변환을 사용하면 도메인 이벤트를 가로채서 공표된 언어로 변환할 수 있으므로 바운디드 컨텍스트의 구현 상세를 더 잘 캡슐화할 수 있다.

또한, 메시지를 공표된 언어로 변환하면 바운디드 컨텍스트의 내부 요구사항을 위한 private event 와 다른 바운디드 컨텍스트와 연동하기 위해 설계된 public event 를 
구분할 수 있게 된다.

> 위 내용은 추후 좀 더 상세히 다룰 예정입니다. (p. 152)

---

## 1.2. Stateful 모델 변환

원천 데이터를 집계하거나 여러 요청에서 들어오는 데이터를 단일 모델로 통합해야 하는 변환 메커니즘의 경우 stateful 모델 변환이 필요하다.

---

### 1.2.1. 유입되는 데이터 집계

바운디드 컨텍스트가 들어오는 요청을 집계하고 성능 최적화를 위해 일괄 처리를 해야하는 경우이다.

![요청의 일괄 처리](/assets/img/dev/2024/1005/aggregate.png)

유입되는 데이터를 집계하는 모델 변환은 API Gateway 를 사용하여 구현할 수 없으므로 들어오는 데이터를 추적하고 처리하기 위해 변환 로직에 자체 영구 저장소가 필요하다.

![stateful 요청 변환](/assets/img/dev/2024/1005/stateful.png)

stateful 변환을 위한 솔루션을 직접 구현하지 않고 스트림 처리 플랫폼인 Kafka, AWS Kinesis 를 사용하거나 일괄 처리 솔루션인 Apache NiFi, AWS Glue, Spark 등을 
사용할 수도 있다.

---

### 1.2.2. 여러 요청 통합: BFF

여러 요청에서 집계된 데이터를 처리해야하는 경우가 있다.

일반적인 예로는 사용자 인터페이스가 여러 서비스에서 발생하는 데이터를 결합해야 하는 BFF(Backend-for-frontend) 패턴이다.  
BFF 는 특정 프론트엔트(웹, 모바일 등) 요구사항에 맞춘 백엔드 계층을 제공하는 아키텍처 패턴으로 하나의 공통 백엔드(API Gateway 등) 대신 각 프론트엔드별로 
최적화된 백엔드를 제공할 수 있다.

> **BFF(Backend-for-frontend)**
> 
> 일반적인 백엔드 구조인 웹, 모바일이 같은 공통 백엔드를 사용한다고 하면 아래와 같은 문제점이 있음
> - 불필요한 데이터 과다 전송
>   - 모바일은 작은 데이터만 필요하지만 웹과 같은 API 를 사용함
> - 비효율적인 데이터 처리
>   - 웹은 복잡한 데이터를 요구하지만 백엔드는 모바일 최적화
> - 클라이언트 로직 증가
>   - 프론트엔드에서 데이터를 조합해야 할 수도 있음
> 
> **BFF 패턴의 장점**
> - 프론트엔드별 최적화
>   - 각 클라이언트(Web, iOS, Android 등)에 맞는 백엔드 제공
> - 백엔드 서비스의 변화로부터 프론트엔드 보호
>   - BFF 가 변경을 흡수하여 클라이언트가 API 변경에 영향을 덜 받음
> - 보안 강화
>   - 프론트엔드가 직접 백엔드와 통신하지 않으므로 BFF 에서 인증/인가 로직을 추가할 수 있음
>   - 즉, 클라이언트별로 보안과 인증을 다르게 적용할 수 있음
> - 백엔드가 아닌 BFF 에서 요청을 변환하여 프론트엔트 코드의 단순화
> 
> **BFF 패턴의 단점**
> - 관리 부담 증가
>   - 각 클라이언트마다 BFF 를 만들면 관리해야 할 서비스가 늘어남
> - 중복된 로직
>   - 각 BFF 가 유사항 기능을 수행하는 경우 코드 중복이 발생할 수 있음
> - 추가적인 인프라 및 유지보수 비용
>   - 기존 API Gateway 와 별도로 동작하므로 추가적인 운영 비용이 발생할 수 있음

또 다른 예로는 여러 다른 컨텍스트의 데이터를 처리하고, 복잡한 비즈니스 로직을 구현해야 하는 바운디드 컨텍스트일 경우이다.  
이 때는 다른 모든 바운디드 컨텍스트에서 데이터를 집계하는 충돌 방지 계층(ACL) 을 바운디드 컨텍스트 전면에 배치하여 바운디드 컨텍스트 연동과 비즈니스 로직의 복잡성을 
분리하는 것이 유리하다.

---

# 2. 애그리거트 연동


[3.3.6. 도메인 이벤트](https://assu10.github.io/dev/2024/08/31/ddd-domain-model-pattern/#336-%EB%8F%84%EB%A9%94%EC%9D%B8-%EC%9D%B4%EB%B2%A4%ED%8A%B8) 에서 
본 것처럼 애그리거트가 시스템의 나머지 부분과 통신하는 방법 중 하나로 도메인 이벤트를 발행하는 방법이 있다.

먼저 이벤트 발생 프로세스에서 실수할 수 있는 몇 가지 케이스에 대해 알아보자.

- 애그리거트에서 바로 도메인 이벤트를 발행하는 것
  - 애그리거트의 새로운 상태가 DB 에 커밋되기 전에 이벤트가 전달되면 구독자는 이벤트를 받아볼 수 있지만, 실제 상태와 모순됨
  - 후속 작업의 로직으로 인해 작업이 무효화되거나 트랜잭션이 커밋되지 않아도 이벤트는 이미 발행되어 구독자에게 전달되고, 철회할 수 있는 방법이 없음

위의 문제를 해결하기 위해 도메인 이벤트를 애플리케이션 계층으로 이전하여 애그리거트 관련 인스턴스가 로드되고 상태 변경이 커밋된 후 새로운 도메인 이벤트를 발행한다고 했울 때 
과연 안전할까?  
메시지 버스가 다운되었을 수도 있고, 코드를 실행하는 서버가 DB 트랜잭션을 커밋한 직후 이벤트를 발행하기 전에 실패할 수도 있다.  
즉, DB 트랜잭션은 커밋되지만 도메인 이벤트를 발행되지 않을 수 있다.

이런 극단적인 경우 [아웃박스 패턴](https://assu10.github.io/dev/2024/08/18/kafka-exactly-once/#2321-%EC%95%84%EC%9B%83%EB%B0%95%EC%8A%A4-%ED%8C%A8%ED%84%B4outbox-pattern)을 사용하여 해결할 수 있다.

---

## 2.1. 아웃박스(Outbox): 최 소 한번 이벤트 발행 보장

아웃박스 패턴은 아래의 흐름으로 동작하여 적어도 한 번 도메인 이벤트의 안정적인 발행을 보장한다.

![아웃박스 패턴](/assets/img/dev/2024/1005/outbox.png)

- 업데이트된 애그리거트의 상태와 새로운 도메인 이벤트는 모두 동일한 원자성 트랜잭션으로 커밋됨
- 메시지 릴레이는 DB 에서 새로 커밋된 도메인 이벤트를 가져온 후 도메인 이벤트를 메시지 버스에 발행함
- 성공적으로 발행되면 메시지 릴레이는 이벤트를 DB 에 발행된 것으로 표시하거나 완전히 삭제함

발행 릴레이는 pull 과 push 기반 방식으로 도메인 이벤트를 가져올 수 있다.

- **pull: 발행자를 폴링**
  - 릴레이는 발행되지 않은 이벤트에 대해 DB 를 지속해서 질의할 수 있음
  - 지속적인 폴링으로 인한 DB 부하를 줄이려면 적절한 인덱스가 있어야 함
- **push: 트랜잭션 로그 추적**
  - DB 의 기능을 활용하여 새로운 이벤트가 추가될 때마다 발행 릴레이를 호출할 수 있

---

## 2.2. 사가(saga): 여러 트랜잭션에 걸친 비즈니스 로직

여기서는 도메인 이벤트의 안정적인 발행을 활용하여 애그기러트 설계 원칙으로 인해 발생한 제한 사항을 극복할 수 있는 방법에 대해 알아본다.

애그리거트 설계 원칙 중 하나는 각 트랜잭션을 애그리거트의 단일 인스턴스로 제한하는 것이다.  
하지만 만일 아래처럼 여러 애그리거트에 걸쳐있는 비즈니스 프로세스를 구현해야 하는 경우가 있다면 어떻게 해야 할까?

예) 광고 캠페인이 활성화되면 캠페인의 광고 자료를 퍼블리셔에게 자동으로 제출함  
퍼블리셔로부터 확인을 받으면 캠페인의 발행 상태가 발행됨으로 변경됨  
퍼블리셔가 거부한 경우 캠페인의 발행 상태가 거부됨으로 변경됨

위는 광고 캠페인과 퍼블리셔라는 2가지 비즈니스 엔티티에 함께 동작해야 한다.  
이런 경우 사가(saga) 를 통해 구현할 수 있다.

**사가(saga)**

- 오래 지속되는 비즈니스 프로세스
- 몇 초에서 몇 년까지 계속될 수 있지만, 단순히 시간 측면이 아닌 트랜잭션 측면에서 봐야 함
- 즉, 여러 트랜잭션에 걸쳐 있는 비즈니스 프로세스 측면임
- 관련 컴포넌트에서 발생하는 이벤트를 수신하고, 다른 컴포넌트에 후속 커맨드를 발행함
- 발행 단계 중 하나가 실패하면 사가는 시스템 상태를 일관되게 유지하기 위해 적절한 보상 조치를 발행함

![사가](/assets/img/dev/2024/1005/saga.png)

- 사가는 캠페인 애그리거트로부터는 _CampaignActivated_ 이벤트를 기다리고, 퍼블리셔 바운디드 컨텍스트로부터는 _PublishingRejected_ 혹은 _PublishingConfirmed_ 이벤트를 기다림
- 사가는 퍼블리셔 바운디드 컨텍스트에서는 _SubmitAdvertisement_ 커맨드를 실행하고, 캠페인 애그리거트에서는 _TrackPublishingConfirmation_ 혹은 _TrackPublishingRejection_ 커맨드를 실행함

상태 관리가 필요없는 사가의 예로는 메시징 인프라에 의존하여 관련 이벤트를 전달하고, 관련 커맨드를 실행하여 이벤트에 반응하는 것이다.

상태 관리가 필요없는 사가 예시
```java
public class CampaignPublishingSaga {
    private ICampaignRepository repository;
    private IPublishingServiceClient publishingServiceClient;
    
    public void process(CampaignActivated event) {
        Campaign campaign = repository.load(event.campaignId);
        String advertising = campaign.generateAdvertising();
        
        // 관련 커맨드 실행
        publishingServiceClient.submitAdvertisement(event.campaignId, advertising);
    }

    public void process(PublishingConfirm event) {
      Campaign campaign = repository.load(event.campaignId);
      campaign.trackPublishingConfirmation(event.confirmationId);
      
      // 관련 커맨드 실행
      repository.commit(campaign);
    }
  
    public void process(PublishingRejected event) {
      Campaign campaign = repository.load(event.campaignId);
      campaign.trackPublishingRejection(event.rejectionReason);
      
      // 관련 커맨드 실행
      repository.commit(campaign);
    }
}
```

상태 관리가 필요한 사가도 있다.  
예를 들어 실행된 작업을 추적하여 실패 시 적절한 보상 조치를 발행해야 한다면 사가는 이벤트 소싱 애그리거트로 구현되어 수신된 이벤트와 발행된 커맨드의 전체 기록을 유지할 수 있다.  
이 때 커맨드 실행 로직은 도메인 이벤트가 아웃박스 패턴으로 전달하는 방식과 유사하가 사가 패턴 자체에서 벗어나서 비동기적으로 실행되어야 한다.

상태 관리가 필요한 사가 예시
```java
public class CampaignPublishingSage {
    private ICampaignRepository repository;
    private IList<IDomainEvent> events;
    
    public void process(CampaignActivated activated) {
        Campaign campaign = repository.load(activated.campaignId);
        String advertising = campaign.generateAdvertising();
        IssuedEvent commandIssuedEvent = new CommandIssuedEvent (
            Target.publishingService,   // target
            new SubmitAdvertisementCommand(activated.campaignId),    // command
            advertising
        );
        
        // 커맨드 실행 로직은 비동기적으로 실행
        events.append(activated);
        events.append(commandIssuedEvent);
    }
    
    public void process(PublishingConfirmed confirmed) {
        IssuedEvent commandIssuedEvent = new CommandIssuedEvent(
                Target.campaignAggregate,   // target
                new TrackConfirmation(confirmed.campaignId, confirmed.confirmationId)  // command
        );

        // 커맨드 실행 로직은 비동기적으로 실행
        events.append(commandIssuedEvent);
        events.append(confirmed);
    }

    public void process(PublishingRejected rejected) {
        IssuedEvent commandIssuedEvent = new CommandIssuedEvent(
                Target.campaignAggregate,   // target
                new TrackRejection(rejected.campaignId, rejected.rejectionReason)  // command
        );
    
        // 커맨드 실행 로직은 비동기적으로 실행
        events.append(rejected);
        events.append(commandIssuedEvent);
    }
}
```

위 코드를 보면 아웃박스 릴레이는 _CommandIssuedEvent_ 의 각 인스턴스에 대한 관련 엔드포인트에서 커맨드를 실행하고 있다.  
도메인 이벤트 발행의 경우 사가 상태의 전환과 커맨드 실행을 분리하면 프로세스가 어느 단계에서 실패하더라도 커맨드가 안정적으로 실행될 수 있다.

---

### 2.2.1. 사가 패턴의 일관성

사가 패턴이 다중 컴포넌트의 트랜잭션을 조율하기는 하지만 ACID 트랜잭션처럼 "원자성"을 보장하는 것이 아니라 관련된 컴포넌트의 상태는 "궁긍적 일관성"을 가진다.  
사가가 관련 커맨드를 실행한다고 해도 두 개의 트랜잭션은 원자적으로 간주되지 않으므로 하나만 성공하거나 실패할 수도 있는 것이다.  
트랜잭션이 실패했을 경우엔 보상 작업을 수행하는 방식으로 롤백을 처리한다.

<**사가 패턴 특징**>
- **다중 컴포넌트 트랜잭션 조율**
  - 여러 개의 마이크로서비스나 도메인 간에 걸쳐있는 분산 트랜잭션을 관리함
  - 각 서비스는 개별적인 로컬 트랜잭션을 수행하며, 중앙에서 조율하는 컴포넌트에 의해 실행됨
- **원자성 미보장**
  - ACID 트랜잭션은 모두 성공하거나 모두 실패해야 하지만 사가 패턴에서는 개별 트랜잭션이 순차적으로 진행되기 때문에 중간에 일부만 성공할 수 있음
  - 즉, 2개의 트랜잭션이 하나의 단일 단위처럼 동작하지 않음
- **궁극적 일관성**
  - 전체 시스템이 즉시 일관성을 갖는 "강한 일관성"을 제공하지 않음
  - 하지만 시간이 지나면서 모든 관련 서비스의 상태가 일관된 상태에 도달하는 "궁극적 일관성"을 보장함
- **보상 트랜잭션**
  - 일부 트랜잭션이 실패하면 이전 단계에서 성공한 트랜잭션을 롤백하기 위해 보상 트랜잭션을 수행함
  - 예) 항공 예약 시스템에서 결제 후 좌석 예약이 실패하면 결제 취소

사가 패턴은 분산 시스템에서 트랜잭션의 일관성을 유지하는 강력한 패턴이지만 보상 트랜잭션을 설계하는 것이 까다로울 수 있고, 복잡도가 증가할 수 있으므로 
부적절한 애그리거트 경계를 보상하기 위해 사가를 남용하는 것은 좋지 않다.

---

## 2.3. 프로세스 관리자

사가 패턴은 종종 프로세스 관리자와 혼동된다.  
사가와 프로세스 관리자는 구현은 비슷하지만 다른 패턴이다.

사가 패턴은 단순하고 선형적인 흐름을 관리한다.  
사가는 이벤트를 해당 커맨드와 일치시킨다.
- _CampaignActivated_ 이벤트와 _publishingServiceClient.submitAdvertisement_ 커맨드
- _PublishingConfirm_ 이벤트와 _campaign.trackPublishingConfirmation_ 커맨드
- _PublishingRejected_ 이벤트와 _campaign.trackPublishingRejection_ 커맨드

프로세스 관리자는 시퀀스의 상태를 유지하고, 다음 처리 단계를 결정하는 중앙 처리 장치로 정의한다.

![프로세스 관리자](/assets/img/dev/2024/1005/process.png)

사가의 올바른 동작 과정을 선택하는 if-else 문이 포함되어 있다면 프로세스 관리자일 가능성이 크다.

---

# 정리하며..

- 아웃박스 패턴은 애그리거트의 도메인 이벤트를 발행하는 안정적인 방법임
- 아웃박스 패턴은 다른 프로세스가 실패해도 도메인 이벤트를 항상 발행함
- 사가 패턴은 간단한 교차 컴포넌트 비즈니스 프로세스를 구현함
- 프로세스 관리자 패턴은 좀 더 복잡한 비즈니스 프로세스를 구현함
- 사가 패턴과 프로세스 관리자 패턴 모두 도메인 이벤트에 대한 비동기식 반응과 커맨드 발행에 의존함


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 블라드 코노노프 저자의 **도메인 주도 설계 첫걸음**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 설계 첫걸음](https://www.yes24.com/Product/Goods/109708596)
* [책 예제 git](https://github.com/vladikk/learning-ddd)