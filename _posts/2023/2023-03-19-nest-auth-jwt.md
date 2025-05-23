---
layout: post
title:  "인증, JWT, Sliding Session, Refresh Token"
date: 2023-03-19
categories: dev
tags: backend auth jwt session token sliding-session refresh-token
---

이 포스트는 인증과 JWT 에 대해 알아본다.

<!-- TOC -->
* [1. 인증](#1-인증)
* [1.1. 세션 기반 인증](#11-세션-기반-인증)
* [1.2. 토큰 기반 인증](#12-토큰-기반-인증)
  * [1.2.1. 슬라이딩 세션](#121-슬라이딩-세션)
    * [1.2.1.1. 리프레시 토큰 발급 전략 및 탈취 조치](#1211-리프레시-토큰-발급-전략-및-탈취-조치)
* [2. JWT](#2-jwt)
* [2.1. Header](#21-header)
* [2.2. Payload](#22-payload)
  * [2.2.1. Registered claim](#221-registered-claim)
  * [2.2.2. Public claim](#222-public-claim)
  * [2.2.3. Private claim](#223-private-claim)
* [2.3. Signature](#23-signature)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->


---

# 1. 인증

인증은 주로 세션이나 토큰을 이용한 방식을 사용하는데 특히 JWT 를 이용한 토큰 인증 방식이 거의 표준이 되었다.

---

# 1.1. 세션 기반 인증

세션은 로그인에 성공한 유저가 서비스를 사용하는 동안 서버에 저장하고 있는 유저 정보이다. (=인증 정보를 서버에 저장)

세션 생성 후 세션을 DB 에 저장 → 이후 사용자의 요청에 포함된 세션 정보가 세션 DB 에 저장되어 있는지 확인 하는 순이다.

브라우저에는 데이터를 저장할 수 있는 3개의 공간이 있다.

- [세션 스토리지](https://developer.mozilla.org/ko/docs/Web/API/Window/sessionStorage)
  - 현재 열려있는 브라우저를 닫거나 새로운 탭/창응ㄹ 열면 데이터 삭제
- [로컬 스토리지](https://developer.mozilla.org/ko/docs/Web/API/Window/localStorage)
  - 창을 닫아도 데이터가 남아있음
- [쿠키](https://developer.mozilla.org/ko/docs/Web/HTTP/Cookies)

---

**세션 기반 인증 방식의 단점**은 아래와 같다.
- 브라우저에 저장된 데이터 탈취 가능
  - 이를 방지하기 위해 HTTPS 로 암호화된 통신을 하고 세션에 유효기간을 정해둠
- 사용자가 몰릴 경우 DB 에 부하가 가고 메모리 부족으로 서비스 장배 발생 가능
  - 서버 저장소에 세션이 저장되고 빠른 응답을 위해 세션을 메모리에 상주시키는 경우가 많은데 이로 인해 사용자가 몰릴 경우 위와 같은 문제 발생
  - 이를 방지하기 위해 Redis 를 이용하여 메모리에 상주하는 세션을 좀 더 빠르게 처리하기도 함
- 서비스가 여러 도메인으로 나누어진 경우 CORS 문제로 도메인 간 세션 공유 처리 힘듦

---

# 1.2. 토큰 기반 인증

세션이 사용자 인증 정보를 서버에 저장하는 반면 토큰은 사용자 인증 시 서버에서 토큰을 생성해서 전달하기만 하고 따로 저장소에 저장하지 않는다.  
로그인 이후 클라이언트가 전달한 토큰 검증만 수행하며 이 검증 방식 중의 하나가 JWT 이다.

세션과 같이 상태를 관리할 필요가 없기 때문에 어느 도메인의 서비스로 보내더라도 같은 인증을 수행할 수 있다.

토큰 기반 인증을 사용하면 서버에 사용자의 상태를 저장하지 않는 반면, 공격자가 토큰 탈취 시 토큰을 즉시 무효화하지 못하는 취약점이 있다.
이를 방지하기 위해 토큰의 유효기간을 짧게 설정할 수 있다. 하지만 이럴 경우 사용자가 로그인 정보를 자주 입력해야 하는데 이렇게 상태 비저장 방식인
토큰의 보안 취약점을 보강하고 사용자 편의성을 유지하기 위해 **슬라이딩 세션** 을 사용한다.

---

## 1.2.1. 슬라이딩 세션

슬라이딩 세션은 로그인 정보를 재입력하지 않고 리프레시 토큰을 사용하여 새로운 액세스 토큰을 발급하는 방식이다.

리프레시 토큰은 액세스 토큰에 비해 만료 시간이 길다.

첫 로그인 때 액세스 토큰과 함께 리프레시 토큰을 발급하고, 클라이언트는 액세스 토큰 만료로 에러 발생 시 리프레시 토큰을 사용하여 
새로운 액세스 토큰 발급 요청을 한다. 만일 리프레시 토큰 만료로 다시 리프레시 토큰을 발급받을 때도 가장 최근에 발급(=클라이언트는 항상 최신 리프레시 토큰만 가짐)한 리프레시 토큰으로 새로운
토큰을 발급받는다.

리프레시 토큰은 보통 서버 DB 에 저장해두고 요청에 포함된 리프레시 토큰과 비교한다.  
상태 비저장 방식의 장점은 줄어들지만 보안성, 사용성을 위해 타협된 방식이라고 생각하면 된다.

---

### 1.2.1.1. 리프레시 토큰 발급 전략 및 탈취 조치

리프레시 토큰은 만료 기간이 길고 액세스 토큰을 언제든지 다시 얻을 수 있기 때문에 새로운 리프레시 토큰 발급 시 이전에 발급한 리프레시 토큰이
유효하지 않도록 해야 한다. 그 이유는 탈취된 토큰을 비정상 토큰으로 인지할 수 있어야 하기 때문이다.

이를 위해 DB 에서 이전에 발급된 리프레시 토큰을 삭제하기 보다는 DB 에 영속화를 하고 유효 여부를 따지는 필드를 따로 두는 것이 좋다.
그러면 공격자가 무작위로 리프레시 토큰을 생성한 것인지, 과거 발급되었던 토큰이 실제 사용되고 있는 것인지 알 수 있다.

만일 무작위로 리프레시 토큰을 생성한 것이라면 공격자의 IP 만 차단하면 되고, 과거 발급되었던 토큰이 사용되는 것이면 사용자에게 토큰 탈취 알람을 주는 등의 조치를 취할 수 있다.

리프레시 토큰이 탈취되면 액세스 토큰보다 만료 기간이 길기 때문에 클라이언트는 반드시 안전한 공간에 저장해야 한다.

액세스 토큰은 5분 미만으로 짧게 가져가는 경우도 있고, 24시간으로 설정하는 경우도 있다.  
리프레시 토큰은 한 달 이상으로 하는 경우가 많고 6개월 이상 혹은 아예 만료하지 않는 경우도 있다. 이 때는 토큰을 암호화하고 암호화 키를
저장하는 등의 별도 보안 장치가 필요하다.

---

# 2. JWT

JWT 는 [jwt.io/](https://jwt.io/) 에서 인코딩/디코딩 해볼 수 있다.

JWT 는 Header, Payload, Signature 3가지 요소가 (`.`) 으로 구분되어 구성되며, 헤더와 페이로드는 각각 Base64 로 인코딩되어 있다.

---

# 2.1. Header

Header 는 (`.`) 으로 구분된 첫 번째 문자열로 JWT 의 유형(`typ`) 와 어떤 알고리즘(`alg`) 으로 인코딩되었는지를 나타낸다. 

```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

- `typ`
  - JWT 를 처리하는 애플리케이션에게 Payload 가 무엇인지 알려주는 역할
  - 이 토큰은 JWT 라는 것을 의미하므로 "JWT" 로 정의할 것을 권고하고 있음
- `alg`
  - 토큰을 암호화하는 알고리즘
  - 이 알고리즘은 토큰을 검증할 때 사용하는 Signature 부분에서 사용됨
  - 암호화하지 않는 경우는 "none" 으로 정의

---

# 2.2. Payload

Payload 는 토큰에 담을 정보가 들어있고 여기에 담는 정보의 한 '조각'을 claim 이라고 한다.  
claim 은 name/value 쌍으로 이루어져 있으며, 토큰에는 여러 개의 claim 들을 넣을 수 있다.

---

## 2.2.1. Registered claim

IANA JWT 클레임 레지스트리에 등록된 클레임들로 서비스에서 필요한 정보들이 아닌 토큰에 대한 정보들을 담기 위해 이름이 이미 정해진 클레임들이다.  
Registered claim 의 사용은 모두 optional 이다.

- `iss`
  - issuer, 발급자
  - 누가 토큰을 생성했는지 나타냄
  - 애플리케이션에서 임의로 정의한 문자열 or URI 형식
- `sub`
  - subject, 주제
  - 발급자가 정의하는 문맥상 or 전역으로 유일한 값
  - 문자열 or URI 형식
- `aud`
  - audience, 수신자
  - 누구에게 토큰이 전달되는지 나타냄
  - 주로 보호된 리소스의 URL 을 값으로 설정함
- `exp`
  - expiration, 만료 시간
  - 언제 토큰이 만료되는지 나타냄
  - 일반적으로 UNIX Epoch 시간을 사용함
- `nbf`
  - not before, 정의된 시간 이후
  - 정의된 시간 이후에 토큰이 활성화됨
  - 토큰이 유효해지는 시간 이전에 미리 발급되는 경우에 사용함
  - 일반적으로 UNIX Epoch 시간을 사용함
- `iat`
  - issued at, 토큰 발급 시간
  - 일반적으로 UNIX Epoch 시간을 사용함
- `jti`
  - JWT ID, 토큰 식별자
  - 토큰 고유 식별자로 일회용 토큰에 사용하면 유용함
  - 공격자가 JWT 를 재사용하는 것을 방지하기 위해 사용

---

## 2.2.2. Public claim

JWT 발급자는 표준 클레임에 덧붙여서 공개되어도 무방한 payload 를 Public claim 으로 정의한다.  
Public claim 들은 이름 충볼 방지를 위해 IANA JWT 클레임 레지스트리에 이름을 등록하거나 클레임 이름을 URI 형식으로 정의한다.

```json
{
    "https://test.com/jwt_claims/is_admin": true
}
```

---

## 2.2.3. Private claim

JWT 발급자와 사용자(보통 클라이언트와 서버) 간에 협의 하에 사용되는 클레임이다.  
이름이 중복되어 충돌될 수 있으니 유의해야 한다.

```json
{
    "username": "test"
}
```

Payload 예시)   
아래는 2개의 Registered claim, 1개의 Public claim, 2개의 Private claim 으로 구성되어 있다.
```json
{
  "iss": "velopert.com",
  "exp": "1485270000000",
  "https://test.com/jwt_claims/is_admin": true
  "userId": "1111",
  "username": "test"
}
```

---

# 2.3. Signature

Header 와 Payload 는 단순히 Base64 로 인코딩하기 때문에 공격자가 원하는 값을 넣은 후 토큰을 생성할 수 있다.
따라서 생성된 토큰이 유효한지 검증하는 장치가 필요하다.  
Signature 는 JWT 의 마지막 부분으로 Header 의 인코딩값과 Payload 의 인코딩값을 합친 후 secret key 로 해쉬하여 생성한다.  
토큰을 암호화할 때 사용하는 secret key 는 토큰을 생성하고 검증하는 서버에서만 저장해야 한다.

> Signature 는 해당 토큰이 유효한지 검증할 뿐이지 Payload 를 암호화하는 것이 아님

HS256 방식의 암호화의 pseudo code 는 아래와 같다.

```text
HMACSHA256(
    base64UrlEncode(header) + "." + 
    base64UrlEncode(payload),
    'secret' 
)
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 한용재 저자의 **NestJS로 배우는 백엔드 프로그래밍**을 기반으로 스터디하며 정리한 내용들입니다.*

* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [NestJS로 배우는 백엔드 프로그래밍 - Github](https://github.com/dextto/book-nestjs-backend)
* [세션 스토리지](https://developer.mozilla.org/ko/docs/Web/API/Window/sessionStorage)
* [로컬 스토리지](https://developer.mozilla.org/ko/docs/Web/API/Window/localStorage)
* [쿠키](https://developer.mozilla.org/ko/docs/Web/HTTP/Cookies)
* [JWT Token](https://useegod.com/2022/03/18/jwt_token/)