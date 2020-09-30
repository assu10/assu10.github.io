---
layout: post
title:  "Spring Cloud - OAuth2, Security(2/2)"
date:   2020-09-30 10:00
categories: dev
tags: msa oauth2 jwt spring-cloud-security security-oauth2 spring-security-jwt 
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Security OAuth2 와 Spring Cloud Security 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1.Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2.Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3.Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4.Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br /><br />
>[5.OAuth2, Security - 보안 (1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/)<br /><br />
>***6.OAuth2, Security - 보안 (2/2)***<br />
>- OAuth2
>- OAuth2 로 인증 구현
>   - OAuth2 인증 서버 설정
>   - OAuth2 인증 서버에 클라이언트 애플리케이션 등록
>   - 개별 사용자에 대한 자격 증명(인증)과 역할(인가) 설정
>   - OAuth2 패스워드 그랜트 타입을 사용하여 사용자 인증
>- OAuth2 를 이용하여 회원 서비스 보호
>- OAuth2 액세스 토큰 전파

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

이전 포스팅에 이어서 포스팅에선 아래의 내용을 다룰 예정이다.

- ~~스프링 기반 서비스의 보안을 위해 `스프링 클라우드 보안(security)` 과 `OAuth2 표준`을 사용하여 **본인 인증**과 **권한**을 확인~~
- ~~OAuth2 를 이용하여 사용자가 호출할 수 있는 엔드포인트와 HTTP verb 정의~~
- ~~OAuth2 패스워드 그랜트 타입을 이용하여 인증 구현~~
- `JWT` 를 사용하여 더 견고한 OAuth2 구현, OAuth2 토큰 정보를 인코딩하는 표준 수립

--- 

## 1. JWT 과 OAuth2

`OAuth2` 는 토큰 기반 보안 프레임워크이지만 토큰 정의 명세는 제공하지 않는다.<br />
이를 보완하기 위해 `JWT (Javascript Web Token)` 라는 `OAuth2` 토큰을 위한 표준이 등장했다.

- **JWT 특징**
  - **가볍다**
    - Base64 로 인코딩되어 URL 이나 HTTP 헤더, HTTP POST 매개변수로 전달 가능
  - **암호로 서명됨**
    - JWT 토큰은 토큰을 발행하는 인증 서버에서 서명되기 때문에 토큰이 조작되지 않았다는 것을 보장함
  - **자체 완비형**
    - JWT 토큰은 암호로 서명되기 때문에 수신 마이크로서비스는 토큰의 내용이 유효하다는 것을 보장받는다.<br />
    수신 마이크로서비스가 토큰의 서명 유효성을 검증하고 토큰의 내용 (만료 시간, 정보 등) 을 확인할 수 있으므로 
    토큰 검증을 위해 인증 서비스를 재호출할 필요가 없음
  - **확장 가능**
    - 인증 서버가 토큰 생성 시 토큰에 추가 정보를 넣을 수 있고, 수신 서비스는 토큰 페이로드를 복호화하여 추가 정보 조회 가능
    
스프링 클라우드 시큐리티는 JWT 를 기본적으로 지원한다.

>표준 스크링 클라우드 시큐리티의 OAuth2 구성과 JWT 기반 OAuth2 구성은 서로 다른 클래스를 사용하기 때문에
>[*master_jwt*](https://github.com/assu10/msa-springcloud/tree/master_jwt) branch 로 분리

이 포스팅은 아래와 같은 절차로 진행된다.

1. JWT 발행을 위해 인증 서버를 수정<br />
2. 마이크로서비스(이벤트 서비스)에서 JWT 사용<br />
3. JWT 토큰 확장<br />
4. JWT 토큰에서 사용자 정의 필드를 파싱<br />

--- 

## 2. JWT 발행을 위한 인증 서버 수정

JWT OAuth2 의존성인 `spring-security-jwt` 을 추가하고 사용할 서명키를 컨피그 서버의 원격 저장소에 설정한다.

```xml
<!-- auth-service > pom.xml -->
<!--<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-security</artifactId>
</dependency>-->

<dependency>
    <groupId>org.springframework.security</groupId>
    <artifactId>spring-security-jwt</artifactId>
    <version>1.1.1.RELEASE</version>
</dependency>
```

```yaml
# auth-service > application.yaml

signing:
  key: assusingkey
```

이제 아래 4개의 클래스를 생성할 예정이다.

![JWT 설정 클래스](/assets/img/dev/20200930/directories.jpg)

- *CustomConfig.java*
    - *.properties 설정값 매핑
- *JWTTokenEnhancer.java*
    - 액세스 토큰에 추가 정보 삽입     
- *JWTOAuth2Config.java*
    - JWTTokenStoreConfig 에서 서명하고 생성한 JWT 토큰을 OAuth2 인증 서버로 연결
- *JWTTokenStoreConfig.java*
    - 인증 서버가 JWT 토큰을 생성, 서명, 해석하는 방법 지정
    
```java
// auth-service > CustomConfig.java

@Component
@Configuration
public class CustomConfig {

    @Value("${signing.key}")
    private String jwtSigningKey = "";

    public String getJwtSigningKey() {
        return jwtSigningKey;
    }
}
```    

```java
// auth-service > JWTTokenEnhancer.java

/**
 * 액세스 토큰에 추가 정보 삽입 
 */
@Configuration
public class JWTTokenEnhancer implements TokenEnhancer {

    private String getUserId(String userName){
        // DB 로 유저 아이디 조회
        return "12345";
    }

    @Override
    public OAuth2AccessToken enhance(OAuth2AccessToken accessToken, OAuth2Authentication authentication) {
        Map<String, Object> additionalInfo = new HashMap<>();
        String userId =  getUserId(authentication.getName());

        additionalInfo.put("userId", userId);

        ((DefaultOAuth2AccessToken) accessToken).setAdditionalInformation(additionalInfo);
        return accessToken;
    }
}
```

*JWTTokenStoreConfig.java* 는 인증 서버가 JWT 토큰을 생성, 서명, 해석하는 방법을 지정한다.<br />
*jwtAccessTokenConverter()* 메서드는 토큰의 변환 방법을 정의하고, 토큰 서명 시 사용하는 서명키를 설정한다.<br />
여기에선 대칭 키를 사용하기 때문에 인증 서버와 보호 서비스 모두 동일한 키를 공유한다.

>**스프링 클라우드 시큐리티에서의 서명키**
>
>스프링 클라우드 시큐리티는 **대칭 키 암호화** 와 **공개/시크릿 키를 사용한 비대칭 암호화**를 모두 지원하지만
>하지만 JWT 와 스프링 시큐리티, 공개/시크릿 키에 대한 공식 문서는 거의 없는 상황이다.

```java
// auth-service > JWTTokenStoreConfig.java

/**
 * 인증 서버가 JWT 토큰을 생성, 서명, 해석하는 방법 지정
 */
@Configuration
public class JWTTokenStoreConfig {

    private final CustomConfig customConfig;

    public JWTTokenStoreConfig(CustomConfig customConfig) {
        this.customConfig = customConfig;
    }

    @Bean
    public TokenStore tokenStore() {
        return new JwtTokenStore(jwtAccessTokenConverter());
    }

    /**
     * 서비스에 전달된 토큰에서 데이터를 읽는데 사용
     * @return
     */
    @Bean
    @Primary        // 특정 타입의 빈이 둘 이상인 경우 (여기선 DefaultTokenServices) @Primary 로 지정된 타입을 자동 주입
    public DefaultTokenServices tokenServices() {
        DefaultTokenServices defaultTokenServices = new DefaultTokenServices();
        defaultTokenServices.setTokenStore(tokenStore());
        defaultTokenServices.setSupportRefreshToken(true);
        return defaultTokenServices;
    }

    /**
     * JWT 와 OAuth2 인증 서버 사이의 변환기
     * 토큰 서명에 사용되는 서명키 사용 (여기선 대칭 키)
     * @return
     */
    @Bean
    public JwtAccessTokenConverter jwtAccessTokenConverter() {
        JwtAccessTokenConverter converter = new JwtAccessTokenConverter();
        converter.setSigningKey(customConfig.getJwtSigningKey());      // 토큰 서명에 사용되는 서명키 정의
        return converter;
    }

    @Bean
    public TokenEnhancer jwtTokenEnhancer() {
        return new JWTTokenEnhancer();
    }
}
```

아래 *JWTOAuth2Config.java* 는 이전 포스트의 *OAuth2Config.java* 와 동일한 역할을 한다.

```java
// auth-service > JWTOAuth2Config.java

/**
 * JWTTokenStoreConfig 에서 서명하고 생성한 JWT 토큰을 OAuth2 인증 서버로 연결
 *
 * OAuth2 인증 서버에 등록될 애플리케이션 정의
 *      AuthorizationServerConfigurerAdapter: 스프링 시큐리티 핵심부, 핵심 인증 및 인가 기능 수행하는 기본 메커니즘 제공
 */
@Configuration
public class JWTOAuth2Config extends AuthorizationServerConfigurerAdapter {

    private final AuthenticationManager authenticationManager;
    private final UserDetailsService userDetailsService;
    private final TokenStore tokenStore;
    private final DefaultTokenServices defaultTokenServices;
    private final JwtAccessTokenConverter jwtAccessTokenConverter;
    private final TokenEnhancer jwtTokenEnhancer;


    public JWTOAuth2Config(AuthenticationManager authenticationManager, @Qualifier("userDetailsServiceBean") UserDetailsService userDetailsService,
                           TokenStore tokenStore, DefaultTokenServices defaultTokenServices,
                           JwtAccessTokenConverter jwtAccessTokenConverter, TokenEnhancer jwtTokenEnhancer) {
        this.authenticationManager = authenticationManager;
        this.userDetailsService = userDetailsService;
        this.tokenStore = tokenStore;
        this.defaultTokenServices = defaultTokenServices;
        this.jwtAccessTokenConverter = jwtAccessTokenConverter;
        this.jwtTokenEnhancer = jwtTokenEnhancer;
    }

    /**
     * AuthorizationServerConfigurerAdapter 안에서 사용될 여러 컴포넌트 정의
     * 여기선 스프링에 토큰 스토어, 액세스 토큰 컨버터, 토큰 엔헨서, 기본 인증 관리자와 사용자 상세 서비스를 이용한다고 선언
     */
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) {
        TokenEnhancerChain tokenEnhancerChain = new TokenEnhancerChain();
        tokenEnhancerChain.setTokenEnhancers(Arrays.asList(jwtTokenEnhancer, jwtAccessTokenConverter));

        endpoints.tokenStore(tokenStore)                             // JWT, JWTTokenStoreConfig 에서 정의한 토큰 저장소
                .accessTokenConverter(jwtAccessTokenConverter)       // JWT, 스프링 시큐리티 OAuth2 가 JWT 사용하도록 연결
                .tokenEnhancer(tokenEnhancerChain)                   // JWT
                .authenticationManager(authenticationManager)
                .userDetailsService(userDetailsService);
    }

    /**
     * 인증 서버에 등록될 클라이언트 정의
     * 즉, OAuth2 서비스로 보호되는서비스에 접근할 수 있는 클라이언트 애플리케이션 등록
     */
    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        clients.inMemory()      // 애플리케이션 정보를 위한 저장소 (인메모리 / JDBC)
                .withClient("assuapp")      // assuapp 애플리케이션이 토큰을 받기 위해 인증 서버 호출 시 제시할 시크릿과 애플리케이션명
                .secret(PasswordEncoderFactories.createDelegatingPasswordEncoder().encode("12345"))
                .authorizedGrantTypes("refresh_token", "password", "client_credentials")    // OAuth2 에서 지원하는 인가 그랜트 타입, 여기선 패스워드/클라이언트 자격증명 그랜트타입
                .scopes("webclient", "mobileclient");       // 토큰 요청 시 애플리케이션의 수행 경계 정의
    }
}
```

이제 JWT 토큰을 획득해보도록 하자.

**토큰 획득**
POST - [http://localhost:8901/auth/oauth/token](http://localhost:8901/auth/oauth/token)

토큰 획득 시 Authorization 과 Body 셋팅은 이전 포스트인 [Spring Cloud - OAuth2, Security(1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/) 에서
*2.4.1. 토큰 획득* 를 참고하세요.

POST - [http://localhost:8901/auth/oauth/token](http://localhost:8901/auth/oauth/token) 호출 시 아래와 같은 형식의 페이로드가 반환된다.

![JWT 토큰 내용](/assets/img/dev/20200930/jwt_encoding.jpg)

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX25hbWUiOiJhc3N1QWRtaW4iLCJzY29wZSI6WyJtb2JpbGVjbGllbnQiXSwiZXhwIjoxNjAxNTEyMTE1LCJ1c2VySWQiOiIxMjM0NSIsImF1dGhvcml0aWVzIjpbIlJPTEVfQURNSU4iLCJST0xFX1VTRVIiXSwianRpIjoiY2QzZGJiODctMjAxNS00MmIwLThlMzQtNDg4ZTg5MWUzYjYxIiwiY2xpZW50X2lkIjoiYXNzdWFwcCJ9.wSrFVCRUYVv6NdcMf-mAUd5GfX2f7rkkHG_5yzuODys",
    "token_type": "bearer",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX25hbWUiOiJhc3N1QWRtaW4iLCJzY29wZSI6WyJtb2JpbGVjbGllbnQiXSwiYXRpIjoiY2QzZGJiODctMjAxNS00MmIwLThlMzQtNDg4ZTg5MWUzYjYxIiwiZXhwIjoxNjA0MDYwOTE1LCJ1c2VySWQiOiIxMjM0NSIsImF1dGhvcml0aWVzIjpbIlJPTEVfQURNSU4iLCJST0xFX1VTRVIiXSwianRpIjoiMTIzMWVjYTktMDUxMC00YzI1LWE4NzEtYzEyNzcxZGQyMjI0IiwiY2xpZW50X2lkIjoiYXNzdWFwcCJ9.i97pF60RuhkQjQyR8kuUyF0LMFYrkWkMk0VIpacmRkY",
    "expires_in": 43199,
    "scope": "mobileclient",
    "userId": "12345",
    "jti": "cd3dbb87-2015-42b0-8e34-488e891e3b61"
}
```

여기서 access_token 과 refresh_token 값은 Base64 로 인코딩된 문자열이다.
토큰 자체는 반환되지 않고, Base64 로 인코딩된 토큰 내용이 반환되는데 JWT 토큰 내용을 확인하고 싶으면 툴을 사용하여 확인이 가능하다.

디코딩 툴로는 [https://www.jsonwebtoken.io/](https://www.jsonwebtoken.io/), [https://jwt.io/](https://jwt.io/) 등이 있다.

![JWT 토큰 내용 decoding](/assets/img/dev/20200930/jwt_decoding.jpg)

***JWT 토큰을 서명은 했지만 암호화는 하지 않는다.<br />
모든 JWT 토큰은 디코딩하여 토큰 내용을 노출할 수 있다.<br />
따라서 개인 식별 정보는 절대 JWT 토큰에 추가하면 안된다.***

---

## 3. 마이크로서비스(이벤트 서비스)에서 JWT 사용

---

## 4. JWT 토큰 확장

---

## 5. JWT 토큰에서 사용자 정의 필드 파싱


---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [JWT 의 공개/시크릿 키를 사용한 비대칭 암호화](https://www.baeldung.com/spring-security-oauth-jwt)
* [JWT Decoding Tool](https://www.jsonwebtoken.io/)
