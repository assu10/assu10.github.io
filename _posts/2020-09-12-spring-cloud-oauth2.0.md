---
layout: post
title:  "Spring Cloud - OAuth2, Security (작성 중...)"
date:   2020-09-12 10:00
categories: dev
tags: msa oauth2 spring-cloud-security security-oauth2 spring-security-jwt 
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Security OAuth2 와 Spring Cloud Security 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1.Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2.Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3.Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4.Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br /><br />
>***4.OAuth2, Security - 보안***<br />
>- OAuth2
>- OAuth2 로 인증 구현
>   - OAuth2 인증 서버 설정

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

애플리케이션 보안의 여러 가지 측면으로 바라볼 수 있다.

- **본인 인증(authenticate)** 후 요청한 작업을 수행할 수 있는 **권한(authorized)** 여부 검증 -> 이 포스팅에서 다룰 내용
- 인프라 스트럭처의 꾸준한 패치
- 정의된 포트로만 접근 허용, 인가된 서버만 접근할 수 있도록 네트워크 접근 통제

이 포스팅에선 아래의 내용을 다룰 예정이다.

- 스프링 기반 서비스의 보안을 위해 `스프링 클라우드 보안(security)` 과 `OAuth2 표준`을 사용하여 **본인 인증**과 **권한**을 확인
- OAuth2 를 이용하여 사용자가 호출할 수 있는 엔드포인트와 HTTP verb 정의
- `OAuth2 패스워드 그랜트 타입`을 이용하여 인증 구현
- `JWT` 를 사용하여 더 견고한 OAuth2 구현, OAuth2 토큰 정보를 인코딩하는 표준 수립

--- 

## 1. OAuth2
`OAuth2` 는 토큰 기반 보안 프레임워크로 사용자가 제 3자 (third-party) 서비스에서 자신을 인증할 수 있도록 해준다.
OAuth2 의 주요 목적은 사용자 요청을 수행하기 위해 여러 서비스들을 호출할 때 이 요청을 처리할 서비스에 일일이 자격증명을 제시하지 않고도
사용자를 인증하는 것이다.

여기선 OAuth2 에 대해 간략하게만 설명하도록 한다.

(OAuth2 의 좀 더 자세한 내용은 [Oauth2.0](https://assu10.github.io/dev/2019/10/25/oauth2.0/) 를 참고해주세요)

`OAuth 2`은 아래 4가지로 구성된다.

- **Resource Owner (이하 자원 소유자)**
  - User, 즉 사용자
  - 이미 google, facebook 등에 가입된 유저로 Resource Server 의 Resource Owner
  - 자원 소유자가 등록한 애플리케이션은 OAuth2 토큰을 인증할 때 전달되는 자격증명의 일부인 식별 가능한 애플리케이션 이름과 secret key 를 받음
  
- **Resource Server (이하 보호 자원)**
  - 자원을 호스팅하는 서버
  - google, facebook, Naver 등 OAuth 제공자
  - 여기에서는 마이크로서비스에 해당
  
- **Client (애플리케이션)**
  - 리소스 서버에서 제공하는 자원을 사용하는 애플리케이션
  - Naver band, Notion 등등
  
- **Authorization Server (이하 인증 서버)**
  - 사용자 동의를 받아서 권한을 부여 및 관리하는 서버

OAuth2 명세에는 4가지 Grant Type 이 있는데 여기선 `OAuth2 패스워드 그랜트 타입`을 구현할 것이다.

> **OAuth2 4가지 Grant Type**
>- 패스워드
>- 클라이언트 자격 증명 (client credential)
>- 인가 코드 (authorization code)
>- 암시적 (implicit)

---

## 2. OAuth2 로 인증 구현

OAuth2 패스워드 그랜트 타입을 구현하기 위해 아래와 같은 절차로 진행한다.

1. 스프링 클라우드 기반의 **OAuth2 인증 서버 설정**
2. OAuth2 서비스와 사용자를 인증/인가할 수 있도록 인가된 애플리케이션 역할을 하는 임시 UI 애플리케이션 등록 (**OAuth2 인증 서버에 클라이언트 애플리케이션 등록**)
3. OAuth2 패스워드 그랜트 타입을 사용하여 회원 서비스 보호(**사용자 인증**)<br />
(임시 UI 애플리케이션은 만들지 않고 REST API 호출 어플을 이용해 사용자 로그인 시뮬레이션)
4. 인증된 사용자만 호출할 수 있도록 이벤트 서비스 보호

---

### 2.1. OAuth2 인증 서버 설정

> **인증 서버의 역할**
>- 사용자 자격 증명을 인증
>- 토큰 발행
>- 인증 서버가 보호하는 서비스에 요청이 올 때마다 올바른 OAuth2 토큰인지 만료 전인지 확인

인증 서버 설정을 위해 스프링 부트 애플리케이션 모듈을 생성한 후 `spring-cloud-security` Dependency 설정 및 부트스트랩 클래스 설정을 해준다.

```xml
<!-- auth-service > pom.xml -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-security</artifactId>
</dependency>
<!--  springboot 2 에선 spring-security-oauth2 기능이 핵심 spring security 로 포팅되어 별도 추가 필요 없음 -->
<!--<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-oauth2</artifactId>
</dependency>-->
```

`spring-cloud-security` 의존성은 일반적인 스프링과 스프링 클라우드 보안 라이브러리를 모두 가져온다.

> springboot 2 에선 spring-security-oauth2 기능이 핵심 spring security 로 포팅되어 별도의 추가가 필요 없다.

```java
// auth-service > AuthServiceApplication.java

@SpringBootApplication
@RestController
@EnableResourceServer
@EnableAuthorizationServer      // 이 서비스가 OAuth2 인증 서버가 될 것이라고 스프링 클라우드에 알림
public class AuthServiceApplication {
    /**
     * 사용자 정보 조회 시 사용
     *      OAuth2 로 보호되는 서비스에 접근하려고 할 때 사용
     *      보호 서비스로 호출되어 OAuth2 액세스 토큰의 유효성을 검증하고 보호 서비스에 접근하는 사용자 역할 조회
     */
    @RequestMapping(value = { "/user" }, produces = "application/json")    // /auth/user 로 매핑
    public Map<String, Object> user(OAuth2Authentication user) {
        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("user", user.getUserAuthentication().getPrincipal());
        userInfo.put("authorities", AuthorityUtils.authorityListToSet(user.getUserAuthentication().getAuthorities()));
        return userInfo;
    }
    public static void main(String[] args) {
        SpringApplication.run(AuthServiceApplication.class, args);
    }
}
```

`@EnableAuthorizationServer` 는 해당 애플리케이션이 OAuth2 인증 서버라는 점과 
OAuth2 인증 과정에서 사용될 여러 REST 엔드포인트를 추가할 것이라고 알린다.

`/user`(/auth/user로 매핑) 엔드포인트는 OAuth2 로 보호되는 서비스에 접근 시 사용된다.
이 엔드포인트는 보호 서비스로 호출되어 OAuth2 액세스 토큰 유효성을 검증하고, 사용자의 권한을 확인한다.

---

## 2.2. OAuth2 인증 서버에 클라이언트 애플리케이션 등록

이제 인증 서버가 준비되었으니 인증 서버에 애플리케이션을 등록해보자.




 
## 참고 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [SSO with OAuth2: Angular JS and Spring Security Part V](https://spring.io/blog/2015/02/03/sso-with-oauth2-angular-js-and-spring-security-part-v)
* [Spring Security & OAuth 2.0 로그인](https://seokr.tistory.com/810)
