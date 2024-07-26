---
layout: post
title:  "REST-API"
date: 2023-05-13
categories: dev
tags: web rest-api
---

이 포스트에서는 REST-API 의 특징과 설계 시 유의할 점에 대해 알아본다.

- REST-API
- REST-API 설계 시 유의점
- HTTP 메서드별 REST-API

<!-- TOC -->
* [1. REST-API](#1-rest-api-)
* [2. REST-API 설계 시 유의점](#2-rest-api-설계-시-유의점)
* [3. HTTP 메서드별 REST-API](#3-http-메서드별-rest-api)
  * [GET](#get)
  * [POST](#post)
  * [DELETE](#delete)
  * [PUT/PATCH](#putpatch)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. REST-API 

REST-API 는 아래 3 가지 요소로 구성된다.

- `리소스`
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

## PUT/PATCH

```http
// Request
PUT /hotels/111 or PATCH /hotels/111
host : 127.0.0.1:80
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

> REST-API 애플리케이션 예시는 [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/) 의 _3. REST-API 애플리케이션 구축_ 을 참고하세요.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot - HTTP, Spring Web MVC 프레임워크, REST-API](https://assu10.github.io/dev/2023/05/13/springboot-rest-api-1/)