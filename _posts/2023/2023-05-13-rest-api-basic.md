---
layout: post
title:  "REST-API"
date: 2023-05-13
categories: dev
tags: backend rest-api
---

이 포스트에서는 REST-API 의 특징과 설계 시 유의할 점에 대해 알아본다.

<!-- TOC -->
* [1. REST-API](#1-rest-api)
* [2. REST-API 설계 시 유의점](#2-rest-api-설계-시-유의점)
* [3. HTTP 메서드별 REST-API](#3-http-메서드별-rest-api)
  * [GET](#get)
  * [POST](#post)
  * [DELETE](#delete)
  * [PUT](#put)
  * [PATCH](#patch)
  * [URI 수 줄이기 vs 변경 추적 용이성](#uri-수-줄이기-vs-변경-추적-용이성)
* [4. HATEOAS(Hypermedia As The Engine Of Application State)](#4-hateoashypermedia-as-the-engine-of-application-state)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. REST-API

REST 는 HTTP 를 업계 프로토콜로 삼고 아래의 원칙을 따른다.

- `리소스` 중심 URI 설계
  - **리소스는 HTTP URI 로 표현**
  - 예) 호텔 정보를 조회하는 API 의 호텔 리소스는 '/hotels' 로 정의
  - 특정 호텔을 조회할 때는 '/hotels/{id}' 형태로 설계
- `행위`
  - **리소스에 대한 행위는 HTTP 메서드로 표현**
- `표현`
  - **리소스에 대한 행위 내용은 HTTP message 내용으로 표현**
  - message 포맷은 JSON 사용 

---

# 2. REST-API 설계 시 유의점

REST-API 설계 시 아래 규칙을 고려해야 한다.

- **리소스명은 동사보다는 명사**를 사용
  - 행위를 HTTP 메서드 기준으로 설계하므로 리소스를 동사로 설계하면 행위가 중복되어 의미가 모호해질 수 있음
- 리소스는 계층적 구조를 가질 수 있으며, 계층 관계를 가지므로 **단수형이 아닌 복수형**을 사용
  - 계층 구조일 경우 좌측에서 우측으로 큰 개념에서 작은 개념으로 설계
  - 예) 호텔에 속한 객실 조회에 대한 리소스의 URI 는 '/hotels/{hotelId}/rooms/{roomId}' 로 설계한다.
- 리소스에 대한 행위는 GET, POST, PUT, DELETE 를 기본으로 하며 전체 수정이 아닌 부분 수정일 경우 PATCH 를 사용

아래는 REST-API 설계 예시이다.

- 새로운 호텔 정보 생성
  - POST /hotels
- 복수의 호텔 정보 조회
  - GET /hotels
- 특정 호텔 정보 조회
  - GET /hotels/{hotelId}
- 특정 호텔 전체 데이터 수정
  - PUT /hotels/{hotelId}
- 특정 호텔 일부 데이터 수정
  - PATCH /hotels/{hotelId}
- 특정 호텔 정보 삭제
  - DELETE /hotels/{hotelId}

> REST-API 의 응답 코드는 [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/) 의 _1.1. HTTP 상태 코드_ 를 참고하세요.

---

또한 REST-API 설계 시 아래 3 가지 특징을 적용하면 좀 더 견고한 애플리케이션이 될 수 있다.

- `무상태성`
  - REST-API 는 HTTP 프로토콜을 사용하는 API 이므로 HTTP 의 무상태성 특징을 그대로 갖고 있음
  - 클라이언트는 응답을 받으면 커넥션을 끊기 때문에 이러한 특성을 이용하여 고가용성을 구축할 수 있음 (scale-out / scale-in)    
    (Load Balancer 를 서버 앞에 두면 클라이언트의 요청이 균등하게 서버에 분배)
- `일관성`
  - 같은 형태의 응답 메시지나 일관된 규칙으로 HTTP 상태 코드 정의
- `멱등성 (Idempotent)`
  - 여러 번 API 를 호출해도 한 번 호출한 결과와 동일해야 함
  - 데이터를 변경하는 POST 를 제외한 메서드들은 멱등성이 있어야 함
  - 나쁜 예시) 호텔 정보 변경 시 변경 쿼리를 아래와 같이 하면 호출할 때마다 결과가 달라져서 멱등성이 없어짐  
```sql
UPDATE hotels
   SET isOpened = !isOpened
 WHERE hotelId = 1;
```

---

# 3. HTTP 메서드별 REST-API

## GET

```http
// Reqeust
GET /hotels?page=2 HTTP/1.1
host : 127.0.0.1:80
Accept: application/json

// Response
HTTP/1.1 200 OK
Date: Fri, 1 Jan 2023 01:01:01 GMT
Content-length: 1024
Content-type: application/json
```

REST-API 의 버전은 2 가지 방법으로 제공 가능하다.

- URI 사용
- 헤더 사용

```http
// URI 사용
GET /v1.0//hotels?page=2 HTTP/1.1
host : 127.0.0.1:80
Accept: application/json

// 헤더 사용
GET /hotels?page=2 HTTP/1.1
host : 127.0.0.1:80
X-Api-Version: 1.0
Accept: application/json
```

---

## POST

```http
// Request
POST /hotels
host : 127.0.0.1:80
Accept: application/json
{
  "name": "test"
}

// Response
HTTP/1.1 200 OK
Date: Fri, 1 Jan 2023 01:01:01 GMT
Content-length: 1024
Content-type: application/json
{
  "message": "success"
}
```

---

## DELETE

```http
// Request
DELETE /hotels/111
host : 127.0.0.1:80
Accept: application/json

// Response
HTTP/1.1 200 OK
Date: Fri, 1 Jan 2023 01:01:01 GMT
Content-length: 1024
Content-type: application/json
{
  "message": "success"
}
```

---

## PUT

**전체 엔티티를 교체**한다.  
PUT /users/1 의 요청은 사용자 정보를 통채로 교체하겠다는 의미이다.

```http
// Request
PUT /hotels/111 or PATCH /hotels/111
host : 127.0.0.1:80
{
  "name": "test",
  "role": "ADMIN"
}
```

<**PUT 의 장점**>
- 상태를 정의적으로 표현할 수 있음
- 클라이언트가 전체 상태를 항상 인지하게 됨

<br />

<**PUT 의 단점**>
- 일부 필드만 바뀌었더라도 **전체 전송**해야 함
- 서버는 **어떤 필드가 변경되었는지 알 수 없음**
- 네트워크 비용과 파싱 오버헤드 증가

---

## PATCH

PATCH /users/1 의 요청은 **일부 필드만 변경**하겠다는 의미이다.

```http
// Request
PATCH /hotels/111 or PATCH /hotels/111
host : 127.0.0.1:80
{
  "name": "test"
}
```

<**PATCH 의 장점**>
- 변경된 데이터만 명확하게 전달 가능
- 서버에서 정확한 이벤트 추적이 가능 (예: 역할만 변경됨)
- 네트워크 비용 절감

<br />

<**PATCH 의 단점**>
- 명확한 스펙 설계 필요 (REC 5789 또는 JSON Patch 형식 등)

> REST-API 애플리케이션 예시는 [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/) 의 _3. REST-API 애플리케이션 구축_ 을 참고하세요.

---

## URI 수 줄이기 vs 변경 추적 용이성

|  메서드  | 장점                    | 단점                     |
|:-----:|:----------------------|:-----------------------|
|  PUT  | URI 수를 줄이고 전체 상태 전송   | 무엇이 변경되었는지 명확히 알기 어려움  |
| PATCH | 세밀한 변경 추적 가능, 전송량 최소화 | URI 수 증가 가능성, 표준 형식 필요 |

하지만 HATEOAS 를 사용하면 클라이언트가 어떤 URI 로 요청해야 할 지 하드코딩하지 않아도 된다.  
서버가 필요한 링크를 응답에 포함시켜주기 때문이다.

- **Audit, 변경 이력, 이벤트 소싱**이 중요한 도메인에서는 PATCH 가 유리
- **클라이언트 제어가 약하거나 리소스 상태를 명확하게 전달받아야 하는 경우**는 PUT 이 더 직관적
- **하이브리드 방식**도 가능
  - 중요 리소스는 PATCH, 나머지는 PUT

---

# 4. HATEOAS(Hypermedia As The Engine Of Application State)

HATEOAS 는 REST 아키텍처의 제약 조건 중 하나로, **클라이언트가 서버의 응답에 포함된 하이퍼미디어 링크를 통해 애플리케이션의 상태 전이를 유도**하는 방식이다.  
쉽게 말하면 **클라이언트는 별도의 API 문서 없이도 응답에 포함된 링크를 따라가며 다음 동작을 결정할 수 있어야 한다**는 의미이다.

예를 들어 어떤 리소스(/orders/123) 을 요청해서 서버가 이 주문 정보를 반환할 때 단순히 JSON 데이터만 주는 것이 아니라, 이 주문과 관련된 다음 행동을 하이퍼링크로 함께 제공한다.

```json
{
  "orderId": 123,
  "status": "SHIPPED",
  "items": [
    { "productId": "abc", "quantity": 2 }
  ],
  "_links": {
    "self": { "href": "/orders/123" },
    "cancel": { "href": "/orders/123/cancel" },
    "track": { "href": "/orders/123/track" }
  }
}
```

이런 식으로 응답에 `_links` 가 포함되어 있으면
- 클라이언트는 /orders/123/cancel 을 호출해서 주문을 취소할 수도 있고,
- /orders/123/track 으로 배송 정보를 확인할 수도 있다.

즉, **애플리케이션의 다음 상태로 어떻게 이동할지를 서버가 명시적으로 알려주는 것**이다.

<**HATEOAS 장점**>
- **API 탐색성 향상**
  - 클라이언트가 응답 안의 링크만 따라가면 되기 때문에 API 문서 없이도 상태 전이를 탐색할 수 있음
- **유연한 클라이언트**
  - 클라이언트는 하드코딩된 URI 가 아니라 응답에 포함된 링크를 따르기 때문에, 서버 구조가 바뀌어도 클라이언트 변경이 적음

<br />

<**HATEOAS 단점**>
- **구현 복잡도 증가**
  - 하이퍼링크를 매번 생성하고 응답에 포함시키는 작업이 번거로울 수 있음
- **프론트와의 협의 필요**
  - 대부분의 클라이언트는 HATEOAS 를 활용하지 않기 때문에 프론트와의 협업이 중요함
- **실무 적용률 낮음**
  - HATEOAS는 이론적으로 REST 의 핵심이지만, 실무에서는 Swagger 나 GraphQL 문서를 더 선호나는 경함이 있음

<br />

실무에서는
- RESTful 하다고 주장하는 많은 API 가 실제로는 HATEOAS 를 적용하지 않음
- 오히려 **Swagger(OpenAPI) 문서나 클라이언트 전용 명세서로 URI 를 관리하는 게 일반적임**
- 하지만 동적 클라이언트, 또는 API 게이트웨이, 하이퍼미디어 클라이언트와 연동할 때는 매우 유용할 수 있음


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/)