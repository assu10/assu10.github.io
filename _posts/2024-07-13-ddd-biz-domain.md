---
layout: post
title:  "DDD - 비즈니스 도메인 분석"
date: 2024-07-13
categories: dev
tags: ddd 
---

이 포스트에서는 아래 내용에 대해 알아본다.

- **소프트웨어 엔지니어링 프로젝트의 맥락을 정의**
  - 비즈니스 도메인
  - 비즈니스 도메인의 목적
  - 이를 지원하기 위한 소프트웨어의 구현 전략
- **기업의 비즈니스 전략을 분석하는 방법**
  - 즉, 소비자에게 어떤 가치를 제공하는지 분석하고 같은 산업에 있는 다른 회사와 경쟁하는 방법
- **좀 더 세분화된 비즈니스 구성 요소 식별하고, 전략적인 가치를 평가하고, 소프트웨어 의사 결정에 미치는 영향**
- **기업의 비즈니스 도메인과 구조**
  - 즉, 핵심 하위 도메인, 지원 하위 도메인, 일반 하위 도메인을 분석하기 위한 도구로서 DDD 설계를 알아봄


도메인 주도 설계 (DDD, Domain-Driven Design) 은 크게 2 가지 주요 부분으로 나뉜다.

- **전략적 설계**
  - '무엇?' 과 '왜?' 라는 질문에 대한 정답을 찾는 것
  - 즉, 어떤 소프트웨어를 만드는지, 왜 그 소프트웨어를 만드는지에 대한 해답을 찾는 것
- **전술적 설계**
  - '어떻게?' 라는 방법을 찾는 것
  - 즉, 소프트웨어 각각의 구성 요소가 구현되는 방법을 찾는 것

여기서는 기업이 어떻게 돌아가는지 알아본다.  
기업이 존재하는 이유와 추구하는 목표가 무엇이며, 그 목표를 달성하기 위한 전략을 논의한다.

효과적인 솔루션을 설계하고 구축하기 위해선 그것의 바탕이 되는 문제를 알아야하고, 그 문제는 바로 우리가 구축해야 하는 소프트웨어 시스템이다.  
해결하고자 하는 문제를 이해하려면 그것이 존재하는 맥락을 이해해야 한다.  
즉, 그 조직의 비즈니스 전략과 소프트웨어를 만들면서 얻고자 하는 가치를 이해해야 한다.

---

**목차**

<!-- TOC -->
* [1. 비즈니스 도메인](#1-비즈니스-도메인)
* [2. 하위 도메인(subdomain)](#2-하위-도메인subdomain)
  * [2.1. 하위 도메인 유형](#21-하위-도메인-유형)
    * [2.1.1. 핵심 하위 도메인(core subdomain)](#211-핵심-하위-도메인core-subdomain)
    * [2.1.2. 일반 하위 도메인(generic subdomain)](#212-일반-하위-도메인generic-subdomain)
    * [2.1.3. 지원 하위 도메인(supporting subdomain)](#213-지원-하위-도메인supporting-subdomain)
  * [2.2. 하위 도메인 비교](#22-하위-도메인-비교)
    * [2.2.1. 경쟁 우위](#221-경쟁-우위)
    * [2.2.2. 복잡성](#222-복잡성)
    * [2.2.3. 변동성](#223-변동성)
    * [2.2.4. 솔루션 전략](#224-솔루션-전략)
  * [2.3. 하위 도메인 경계 식별](#23-하위-도메인-경계-식별)
* [3. 도메인 분석 예시](#3-도메인-분석-예시)
  * [3.1. 예시 1](#31-예시-1)
    * [3.1.1. 비즈니스 도메인과 하위 도메인](#311-비즈니스-도메인과-하위-도메인)
  * [3.2. 예시 2](#32-예시-2)
    * [3.2.1. 비즈니스 도메인과 하위 도메인](#321-비즈니스-도메인과-하위-도메인)
* [4. 도메인 전문가(domain expert)](#4-도메인-전문가domain-expert)
* [정리하며...](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 비즈니스 도메인

비즈니스 도메인은 기업의 주요 활동 영역을 정의한다. 일반적으로 **회사가 고객에게 제공하는 서비스**를 의미한다 

---

# 2. 하위 도메인(subdomain)

비즈니스 도메인의 목표를 달성하기 위해 여러 하위 도메인을 운영해야 한다.

**하위 도메인은 비즈니스 활동의 세분화된 영역**으로, **고객에게 제공하는 서비스 단위로 비즈니스 도메인**을 만든다.

하나의 하위 도메인을 만드는 것만으로는 회사가 성공하기 어려우며, 각각의 하위 도메인은 서로 상호작용해야 한다.  
예) 스타벅스가 성공적인 커피 체인점을 만드는 일은 좋은 커피를 만드는 방법을 이해하는 것 이상으로의 활동이 필요함  
커피를 만드는 일 외에 좋은 위치의 부동산을 임대하고, 직원을 고용하고, 재정을 관리하는 등의 업무가 필요함

---

## 2.1. 하위 도메인 유형

**하위 도메인은 서로 다른 전략적 비즈니스 가치**를 가지며, DDD 에서 하위 도메인은 핵심/일반/지원, 3 가지 유형으로 구분한다.

---

### 2.1.1. 핵심 하위 도메인(core subdomain)

**핵심 하위 도메인은 회사가 경쟁업체와 다르게 수행하고 있는 것**을 의미한다.  
예) 새로운 제품이나 서비스 발명, 기존 프로세스를 최적화하여 비용 감소

우버를 예로 들면 처음에는 새로운 방식의 운송 수단인 승차 공유 서비스를 제공하다가 경쟁업체가 따라잡는 순간 그에 대응하여 핵심 비즈니스를 최적화하는 방법을 찾았다.  
예) 같은 방향으로 향하는 손님을 매칭하여 비용을 절감

핵심 하위 도메인은 **수익에 영향**을 미치고, **경쟁사로부터 차별화**를 가져온다.

핵심 하위 도메인은 고객에게 더 좋은 서비스를 제공하여 수익성을 극대화하는 전략이다.

경쟁력을 유지하기 위한 핵심 하위 도메인으로는 발명, 비즈니스 노하우, 지적 재산 등이 포함된다.

구현하기 쉬운 핵심 하위 도메인은 일시적인 경쟁 우위만을 제공할 수 있다.  
따라서 **핵심 하위 도메인은 자연스럽게 복잡**해진다.

회사의 핵심 비즈니스는 **경쟁사가 회사의 솔루션을 모방하기 어렵도록 높은 진입 장벽**이 있어야 한다.

**핵심 하위 도메인에 반드시 기술이 들어가야 하는 것은 아니다.**  
예를 들어 온라인으로 보석을 판매하는 보석 제조업체의 경우 온라인 쇼핑몰도 중요하지만 핵심 하위 도메인은 아니다.  
보석 디자인이 핵심 하위 도메인이다.  
다른 온라인 쇼핑 엔진을 활용할 수 있지만 보석 디자인은 하청할 수 없다.

---

### 2.1.2. 일반 하위 도메인(generic subdomain)

**일반 하위 도메인은 모든 회사가 같은 방식으로 수행하는 비즈니스 활동**을 의미한다.  
예) 사용자 인증과 권한 부여 시 전용 인증 메커니즘을 발명하는 것보다 기존에 만들어진 솔루션을 사용하는 것이 합리적

핵심 하위 도메인과 마찬가지로 일반 하위 도메인은 일반적으로 복잡하고 구현하기 어렵다.

하지만 **일반 하위 도메인은 회사에 경쟁력을 제공하지는 않는다.**  
이미 모든 회사에서 이용하고 있어서 더 이상 혁신이나 최적화가 필요없다.

온라인으로 보석을 판매하는 제조업체의 경우 보석 디자인은 핵심 하위 도메인이지만, 온라인 쇼핑몰은 일반 하위 도메인이다.  
(= 경쟁업체와 동일한 온라인 쇼핑몰 플랫폼을 사용하는 것은 보석 제조업체의 경쟁 우위에 영향을 주지 않음)

---

### 2.1.3. 지원 하위 도메인(supporting subdomain)

**지원 하위 도메인은 회사의 비즈니스를 지원하는 활동을 의미**한다.  
예) 방문자에게 광고 매칭을 핵심 하위 도메인으로 갖고 있는 온라인 광고 회사의 경우 이 회사가 성공하려면 창의적인 카탈로그가 필요함  
이 때 이 창의적인 자료를 물리적으로 저장하는 방식은 수익에 영향을 주지 않음  
반면, 창의적인 카탈로그는 기업의 광고 관리 시스템을 구현하는데 필수임  
이는 컨텐츠 카탈로그 솔루션을 회사의 지원 하위 도메인으로 구분할 수 있게 해줌

**핵심 하위 도메인과 달리 지원 하위 도메인은 어떠한 경쟁 우위도 제공하지 않는다.**

**지원 하위 도메인의 비즈니스 로직은 간단**하다.  
대부분 데이터 입력 화면과 ETL(Extract, Transform, Load: 추출, 변환, 로드) 작업과 유사하다.

이러한 영역은 회사에 어떠한 경쟁 우위도 제공하지 않으므로 **높은 진입 장벽이 필요하지 않다.**

---

## 2.2. 하위 도메인 비교

여기서는 하위 도메인을 여러 각도에서 살펴본다.

| 하위 도메인 유형 | 경쟁 우위 | 복잡성 | 변동성 |  구현 방식   |  문제  |
|:---------:|:-----:|:---:|:---:|:--------:|:----:|
|    **핵심**     |   Y   | 높음  | 높음  |  사내 구현   | 흥미로움 |
|    **일반**     |   N   | 높음  | 낮음  |  구매/도입   | 해결됨  |
|    **지원**     |   N   | 낮음  | 낮음  | 사내 구현/하청 |  뻔함  |


---

### 2.2.1. 경쟁 우위

**핵심 하위 도메인은 경쟁사와 차별화하기 위한 회사의 전략으로 핵심 하위 도메인만이 회사에 경쟁 우위를 제공**한다.

**일반 하위 도메인은 경쟁 우위의 원천이 될 수 없다.**    
일반 하위 도메인은 일반적인 솔루션을 의미하며, 이미 경쟁업체가 동일한 솔루션을 사용하므로 경쟁 우위를 제공할 수 없다.

**지원 하위 도메인은 진입 장벽이 낮고 경쟁 우위도 제공할 수 없다.**    
지원 하위 도메인은 업계 경쟁력에 영향을 주지 않으므로 경쟁사가 지원 하위 도메인을 모방해도 크게 신경쓰지 않는다.  
회사는 전략적으로 지원 하위 도메인은 이미 만들어져 있는 일반적인 솔루션을 사용하는 것을 선호한다.  
따라서 직접 솔루션을 설계하고 만들 필요가 없다.

> 지원 하위 도메인이 일반 하위 도메인으로 바뀌는 사례와 그 밖의 가능한 조합에 대해서 추후 다룰 예정입니다. (p. 8)

> 위 시나리오의 실제 사례에 대해서는 추후 다룰 예정입니다. (p. 8)

회사가 해결할 수 있는 문제가 복잡할수록 더 많은 비즈니스 가치를 제공할 수 있다.

---

### 2.2.2. 복잡성

기술적인 관점에서 **하위 도메인의 유형에 따라 복잡성의 수준이 다르기 때문에 조직의 하위 도메인을 식별하는 것은 중요**하다.

**지원 하위 도메인의 비즈니스 로직은 간단**하다.  
기본적인 ETL 작업과 CRUD 인터페이스이며, 비즈니스 로직이 명확하다.

**일반 하위 도메인은 훨씬 더 복잡**하다.  
예를 들어 암호화 알고리즘이나 인증 메커니즘 등이 있으며 이 지식은 쉽게 구할 수 있다.  
업계에서 인정하는 모범 사례를 사용하거나 해당 분야의 전문가를 고용하여 맞춤형 솔루션을 설계할 수 있다.

**핵심 하위 도메인은 복잡**하다.  
회사의 수익성이 좌우되기 때문에 경쟁업체가 최대한 모방하기 어려워야 한다.  
그래서 회사는 전략적으로 핵심 하위 도메인으로 복잡한 문제를 해결하려고 한다.

핵심 하위 도메인과 지원 하위 도메인을 구별하는 것이 어려울 때 복잡성은 도메인을 구별하는 유용한 지침이 된다.

지원 하위 도메인과 일반 하위 도메인을 구별하기 어려울 때 외부 솔루션을 연동하는 것이 더 간단하고 저렴하면 일반 하위 도메인이고, 자체 솔루션을 구현하는 것이 
더 간단하고 저렴하면 지원 하위 도메인이다.

핵심 하위 도메인을 식별하기 위한 또 다른 유용한 지표는 우리가 모델링하고 코드로 구현해야 하는 비즈니스 로직의 복잡성을 평가하는 것이다.  
비즈니스 로직이 복잡한 알고르즘 또는 복잡한 프로세스 규칙을 가진다면 일반적으로 핵심 하위 도메인이다.  
비즈니스 로직이 CRUD 인터페이스와 유사하다면 일반적으로 지원 하위 도메인이다.

![3 가지 유형의 하위 도메인의 비즈니스 차별화 및 비즈니스 로직 복잡성](/assets/img/dev/2024/0713/subdomain.png)

위 그림에서 일반적인 솔루션이 존재하는 경우 그 기능을 자체 구현하는 것이 더 간단하거나 저렴하면 일반 하위 도메인이다.  
반대로 자체 구현이 더 간단하고 저렴하면 지원 하위 도메인이다.

---

### 2.2.3. 변동성

**핵심 하위 도메인은 자주 변경**될 수 있다.  
한 번의 시도로 문제가 해결될 수 있다면 경쟁자들도 빠르게 따라잡을 수 있기 때문에 경쟁 우위에서 좋은 위치가 아닐 가능성이 있다.

결과적으로 **핵심 하위 도메인에 대한 솔루션을 찾을수는 있지만 다양한 구현 방법을 시도하고 개선하고 최적화**해야 가능하다.

경쟁사보다 앞서기 위해 핵심 하위 도메인의 지속적인 진화는 필수적이므로 핵심 하위 도메인에 대한 개선 작업을 끝이 없다.

**지원 하위 도메인은 자주 변경되지 않는다.**  
지원 하위 도메인은 기업에 어떠한 경쟁 우위도 제공하지 않으므로 핵심 하위 도메인에 투자한 동일한 노력에 비해 아주 작은 비즈니스 가치를 제공한다.

기존 솔루션이 있음에도 **일반 하위 도메인은 시간이 지남에 따라 변경될 수 있다.**  
보안 패치, 버그 수정에 대해 완전히 새로운 솔루션으로 변경될 수 있다.

---

### 2.2.4. 솔루션 전략

**핵심 하위 도메인은 업계에서 다른 경쟁사와 경쟁할 수 있는 능력을 제공**한다.

하지만 기업이 해당 비즈니스 도메인에서 일하려면 하위 도메인 모두가 필요하다.  
하위 도메인은 기본적인 구성요소이므로 하나를 제거하면 전체 구조가 무너질 수 있다.  
즉, **하위 도메인 각각의 고유한 속성을 활용하면 서로 다른 유형의 하위 도메인을 구현하기 위한 가장 효율적인 전략을 선택**할 수 있다.

**핵심 하위 도메인은 사내에서 구현**되어야 한다.  
핵심 하위 도메인 솔루션을 구매하거나 외부에서 도입하면 경쟁업체들이 똑같이 따라할 수 있으므로 경쟁 우위를 약화시킨다.  
또한 사내에서 핵심 하위 도메인을 개발하면 회사가 솔루션을 더 빠르게 변경하고 발전시킬 수 있기 때문에 더 짧은 시간에 경쟁 우위를 갖출 수 있다.

**조직의 가장 숙련된 인재는 핵심 하위 도메인에서 일하도록 업무가 할당**되어야 한다.

핵심 하위 도메인의 요구사항은 자주, 지속적으로 변경될 가능성이 높으므로 솔루션은 유지 보수가 가능하고 쉽게 개선될 수 있어야 한다.  
따라서 **핵심 하위 도메인은 가장 진보된 기술로 구현**해야 한다.

**일반 하위 도메인은 이미 문제가 해결된 것이기 때문에 사내에서 구현하는 것보다 이미 만들어진 제품을 구입하거나 오픈소스 솔루션을 채택하는 것이 더 효율적**이다.

지원 하위 도메인은 경쟁 우위가 없기 때문에 사내에서 구현하지 않는 것이 합리적이지만 일반 하위 도메인과 달리 지원 하위 도메인은 기존에 만들어진 솔루션이 없는 경우가 있다.  
이런 경우 지원 하위 도메인을 자체 구현할 수 밖에 없다.  
지원 하위 도메인은 비즈니스 로직이 간단하고 변경의 빈도가 적으므로 원칙을 생략하고 적당히 진행하기 쉽다.

**지원 하위 도메인은 고급 엔지니어링 기술이 필요없다.**  
아주 짧은 주기로 신속한 애플리케이션 개발(RAD, Rapid Application Development) 프레임워크를 사용해서 비즈니스 로직을 구현하기에 충분하다.  
지원 하위 도메인은 고도로 숙련된 기술이 필요하지 않기 때문에 새로운 인재를 양성할 수 있는 연습 기회를 제공한다.

비즈니스 로직이 단순한 지원 하위 도메인은 하청할 수 있는 좋은 대상이 된다.

---

## 2.3. 하위 도메인 경계 식별

**하위 도메인과 해당 유형을 식별하면 소프트웨어 솔루션을 구축할 때 설계와 관련된 의사 결정에 큰 도움**이 된다.

여기서는 **하위 도메인과 해당 경계를 식별하는 방법**에 대해 알아본다.

하위 도메인과 그 유형은 기업의 비즈니스 전략에 따라 정의되며, 이는 동일한 분야에서 다른 회사와 경쟁하기 위해 자신을 차별화하는 방법이다.

하위 도메인을 식별하고 분류하기 위해선 도메인 분석을 직접 수행해야 한다.

회사의 조직 단위는 좋은 출발점이다.

예를 들어 온라인 쇼핑몰의 경우 창고, 고객 서비스, 출고, 배송, 품질 관리 부서 등이 포함될 수 있다.  
위에서 고객 서비스 부서를 보자.  
이 기능은 종종 다른 업체에 하청되기 때문에 지원 하위 도메인 혹은 일반 하위 도메인으로 생각할 수 있다.  
**하지만 이 정보가 소프트웨어 설계 시 올바른 의사 결정을 하기에 충분할까?**

크게 나눈 하위 도메인은 좋은 출발점이지만 세부 사항도 함께 보아야 한다.

고객 서비스의 내부적인 업무를 조사하면 헬프 데스크 시스템, 교대 근무 관리 시스템, 전화 시스템 등으로 더 세분화할 수 있다.  
개별 하위 도메인으로 볼 때 이러한 내용은 다양한 유형으로 구분될 수 있다.  
헬프 데스크와 전화 시스템은 일반 하위 도메인으로, 교대 근무 관리 시스템은 지원 하위 도메인으로 분류할 수 있다.

또한 고객 상담 라우팅의 경우 과거 비슷한 상담 사례를 처리한 상담원에게 상담을 전달하는 알고리즘을 개발할 수도 있다.  
이 라우팅 알고리즘을 통해 경쟁업체보다 더 나은 고객 서비스를 제공할 수 있게 되므로 라우팅 알고리즘은 핵심 하위 도메인으로 볼 수 있다.

![일반 하위 도메인의 내부 업무에 의문을 가지고 분석하여 세분화된 핵심 하위 도메인](/assets/img/dev/2024/0713/subdomain2.png)

위는 일반 하위 도메인의 내부 업무에 의문을 가지고 분석하여 더욱 세분화된 1 개의 핵심 하위 도메인, 1 개의 지원 하위 도메인, 2 개의 일반 하위 도메인이다.

**하지만 언제까지 세부적으로 분류해야 할까?**

기술적인 관점에서 하위 도메인은 응집된 유스케이스의 집합과 유사하다.  
잉러한 유스케이스 집합에서는 보통 동일한 행위자(actor), 비즈니스 엔티티를 포함하고 모두 밀접하게 관련된 데이터의 집합을 다룬다.

**세분화된 하위 도메인을 찾는 것을 중단하는 시점을 결정하기 위한 지침으로 '응집된 유스케이스의 집합인 하위 도메인' 이라는 정의를 사용**할 수 있다.  
이것은 **하위 도메인의 가장 정확한 경계**가 된다.

**핵심 하위 도메인은 가장 중요하고 변동성이 있으며 복잡하므로 가능한 많이 정제(= 하위 도메인의 경계를 식별하는 작업)하는 것이 중요**하다.

하지만 **일반/지원 하위 도메인의 경우 이러한 정제 작업을 다소 완화**해도 된다.  
더 자세히 분석해도 소프트웨어 설계와 관련된 의사 결정을 내리는 데 도움이 될 수 있는 통찰이 나오지 않으면 중단하는 것이 좋다.  
예를 들면 **세분화된 하위 도메인이 세분화하기 전의 하위 도메인과 모두 동일한 <u>유형</u>인 경우**이다.

![일반 하위 도메인인 헬프 데스크 시스템을 세분화했을 경우 모두 일반 하위 도메인인 경우](/assets/img/dev/2024/0713/subdomain3.png)

위처럼 헬프 데스크 시스템의 하위 도메인을 추가로 정리한다고해서 전략적으로 유용한 정보가 나오지는 않는다.  
이 경우 일반 하위 도메인이므로 이미 만들어져 있는 도구를 솔루션으로 사용하게 될 것이다.

**하위 도메인을 식별할 때 고려해야 할 또 다른 중요한 질문은 하위 도메인이 모두 필요한 지 여부**이다.

---

# 3. 도메인 분석 예시

하위 도메인의 개념을 실제로 적용하여 여러 전략적 설계 의사 결정을 하는데 활용하는 방법에 대해 알아본다.  
실제 사례처럼 일부 비즈니스 요구사항은 드러나지 않고 숨어있다는 것에 유의하자.

---

## 3.1. 예시 1

Gigmaster 는 티켓 판매 및 유통 회사이다.  
모바일 앱은 사용자의 음악 라이브러리, 스트리밍 서비스 계정, 소셜 미디어 프로필을 분석하여 사용자가 관심가질만한 주변의 공연 정보를 찾아낸다.

이 앱의 사용자는 개인 정보에 민감하므로 사용자의 개인 정보는 암호화된다.  
또한 추천 알고리즘은 익명 데이터만 사용한다.

앱의 추천 기능을 개선하기 위해 새로운 모듈이 구현되었다.  
이 앱을 통해 티켓을 구매하지 않았더라도 사용자가 과거에 참석한 공연 정보를 기록할 수 있다.

---

### 3.1.1. 비즈니스 도메인과 하위 도메인

Gigmaster 의 비즈니스 도메인은 티켓 판매이며, 이것이 고객에게 제공하는 서비스이다.

---

**핵심 하위 도메인**

Gigmaster 의 주요 경쟁 우위는 추천 엔진이다.    
또한 회사는 사용자의 개인 정보를 중요하게 생각하여 익명 데이터에 대해서만 처리한다.  
명시적으로 언급되진 않았지만 모바일 앱의 사용자 경험도 중요하다.

따라서 핵심 하위 도메인은 아래와 같다.
- **추천 엔진**
- **데이터 익명화**
- **모바일 앱**

---

**일반 하위 도메인**

- **암호화**
  - 모든 데이터 암호화
- **회계**
  - 회사가 영업을 하므로
- **정산**
  - 고객에게 청구
- **인증 및 권한 부여**
  - 사용자 식별

---

**지원 하위 도메인**

아래 비즈니스 로직은 간단하며, ETL 프로세스 또는 CRUD 인터페이스와 유사하다.

- **음악 스트리밍 서비스와 연동**
- **소셜 네트워크와 연동**
- **참석 공연 모듈**

---

**설계 의사 결정**

작동 중인 하위 도메인과 해당 유형 간의 차이점을 알면 몇 가지 전략적인 설계 의사 결정을 내릴 수 있다.

- 핵심 하위 도메인에 해당하는 것들(추천 엔진, 데이터 익명화, 모바일 앱)은 가장 진보된 엔지니어링 도구와 기술을 사용하여 사내에서 구현, 이 모듈은 가장 자주 변경됨
- 일반 하위 도메인에 해당하는 것들(암호화, 회계, 정산, 인증 및 권한 부여)은 상용 또는 오픈 소스 솔루션 사용
- 지원 하위 도메인에 해당하는 것들(음악 스트리밍 서비스와 연동, 소셜 네트워크와 연동, 참석 공연 모듈)은 하청할 수 있음

---

## 3.2. 예시 2

BusVNext 는 대중교통 회사로 고객에서 택시를 잡는 것처럼 쉽게 버스를 타는 경험을 제공하는 것이 목표이다.  
이 회사는 주요 도시의 버스를 관리한다.

고객은 모바일 앱을 통해 승차권을 예매할 수 있다.  
예정된 출발 시간에 가까운 버스의 경로를 즉석에서 조정하여 지정된 출발 시간에 고객을 픽업한다.

회사의 주요 과제는 라우팅 알고리즘의 구현으로, 요구사항은 외판원 문제의 변형이다.  
라우팅 로직은 계속 조정되고 최적화된다.  
예를 들면 탑승 취소의 주된 이유는 버스가 도착하기까지의 오랜 대기 시간인데 그래서 회사는 하차가 지연되더라도 빠른 픽업을 우선시하는 라우팅 알고리즘을 만들었다.  
라우팅 알고리즘을 더욱 최적화하기 위해 이 회사는 타회사에서 제공하는 교통 상황과 실시간 경고 정보도 통합했다.

이 회사는 새로운 고객을 유치하고, 피크 시간과 그 외의 시간에 승차 수요를 균등하게 하기 위해 가끔 특별 할인을 제공한다.

---

### 3.2.1. 비즈니스 도메인과 하위 도메인

BusVNext 의 비즈니스 도메인은 대중교통이며, 고객에서 최적화된 버스 승차 서비스를 제공한다.

---

**핵심 하위 도메인**

BusVNext 의 주요 경쟁 우위는 다양한 비즈니스 목표를 우선시하면서 동시에 복잡한 문제(외판원 문제) 해결을 시도하는 라우팅 알고리즘이다.  
예) 주행 시간을 늘리더라도 픽업 시간을 줄이는 것

승차 데이터는 고객 행동에 대한 새로운 통찰력을 얻기 위해 지속적으로 분석된다.  
이러한 통찰력을 통해 회사는 라우팅 알고리즘을 최적화하여 수익을 높일 수 있다.

따라서 핵심 하위 도메인은 아래와 같다.
- **라우팅**
- **분석**
- **모바일 앱 사용자 경험**
- **차량 관리**

---

**일반 하위 도메인**

라우팅 알고리즘은 일반 하위 도메인인 타사에서 제공하는 교통량과 경고 데이터를 사용한다.

BusVNext 는 고객에 결제할 수 있는 기능을 제공하므로 회계와 정산 기능을 구현해야 한다.

따라서 일반 하위 도메인은 아래와 같다.
- **교통 상황 식별**
- **회계**
- **정산**
- **권한 부여**

---

**지원 하위 도메인**

프로모션, 할인 관리 모듈을 회사의 핵심 비즈니스를 지원한다.  
이것은 간단한 CRUD 인터페이스와 유사하므로 지원 하위 도메인이다.

---

**설계 의사 결정**

- 핵심 하위 도메인에 해당하는 것들(라우팅 알고리즘, 데이터 분석, 차량 관리, 앱 사용성)은 가장 정교한 기술 도구와 패턴을 사용하여 사내에서 개발
- 일반 하위 도메인에 해당하는 것들(교통 상황 식별, 사용자 권한 관리, 재무 및 거래 기록 관리)는 외부 서비스 제공 업체에 맡길 수 있음
- 지원 하위 도메인에 해당하는 것(판촉 관리 모듈)의 구현은 외부에 위탁할 수 있음

---

# 4. 도메인 전문가(domain expert)

도메인 전문가는 우리가 모델링하고 코드로 구현할 비즈니스의 모든 복잡성을 알고 있는 주제 전문가이다.  
즉, 소프트웨어 비즈니스 도메인에 대한 권위자이다.

도메인 전문가는 요구사항을 수집하는 분석가도 아니고, 시스템을 설계하는 엔지니어도 아니다.  
도메인 전문가는 모든 비즈니스 지식의 근원이 되는 비즈니스 문제를 처음으로 파악한 사람들이다.  
시스템 분석가와 엔지니어는 비즈니스 도메인의 멘탈 모델은 소프트웨어 요구사항과 소스 콛로 구현한다.

일반적으로 도메인 전문가는 요구사항을 제사하는 사람 또는 소프트웨어의 최종 사용자이다.

---

# 정리하며...

- **핵심 하위 도메인**
  - 흥미로운 문제들
  - 기업이 경쟁자로부터 차별화하고 경쟁 우위를 얻는 활동
- **일반 하위 도메인**
  - 해결된 문제들
  - 모든 회사가 같은 방식으로 하고 있는 일
  - 혁신이 필요하지 않음
  - 사내 솔루션을 개발하는 것보다 기존 솔루션을 사용하는 것이 더 효과적임
- **지원 하위 도메인**
  - 분명한 해결책이 있는 문제들
  - 사내에서 구현해야 할 활동이지만 경쟁 우위를 제공하지는 않음

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 블라드 코노노프 저자의 **도메인 주도 설계 첫걸음**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 설계 첫걸음](https://www.yes24.com/Product/Goods/109708596)
* [책 예제 git](https://github.com/vladikk/learning-ddd)
* [외판원 문제(Traveling Salesman Problem)](https://ko.wikipedia.org/wiki/%EC%99%B8%ED%8C%90%EC%9B%90_%EB%AC%B8%EC%A0%9C)