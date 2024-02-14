---
layout: post
title:  "Spring Cloud - OAuth2, Security(2/2)"
date:   2020-09-30 10:00
categories: dev
tags: msa oauth2 jwt spring-cloud-security security-oauth2 spring-security-jwt 
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Security OAuth2 와 Spring Cloud Security 에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2. Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/16/spring-cloud-eureka/)<br />
>[3. Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4. Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br /><br />
>[5. OAuth2, Security - 보안 (1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/)<br /><br />
>***6. OAuth2, Security - 보안 (2/2)***<br />
>- JWT 과 OAuth2
>- JWT 발행을 위해 인증 서버를 수정 및 JWT 토큰 확장
>- 마이크로서비스(이벤트/회원 서비스)에서 JWT 사용
>- JWT 토큰에서 사용자 정의 필드 파싱
>- 실제 운영에서의 MSA 보안

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

이전 포스트에 이어서 포스트에선 아래의 내용을 다룰 예정이다.

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
    토큰 검증을 위해 인증 서비스를 재호출할 필요가 없음<br />
    (즉, 액세스 토큰을 발급받은 후 사용자 정보 조회를 위해 헤더에 토큰을 실어 리소스 서버를 호출할 필요없음)
  - **확장 가능**
    - 인증 서버가 토큰 생성 시 토큰에 추가 정보를 넣을 수 있고, 수신 서비스는 토큰 페이로드를 복호화하여 추가 정보 조회 가능
    
스프링 클라우드 시큐리티는 JWT 를 기본적으로 지원한다.

>표준 스프링 클라우드 시큐리티의 OAuth2 구성과 JWT 기반 OAuth2 구성은 서로 다른 클래스를 사용하기 때문에
>[*master_jwt*](https://github.com/assu10/msa-springcloud/tree/master_jwt) branch 로 분리

이 포스트는 아래와 같은 절차로 진행된다.

1. JWT 발행을 위해 인증 서버를 수정 및 JWT 토큰 확장<br />
2. 마이크로서비스(회원/이벤트 서비스)에서 JWT 사용 (회원 서비스에서 이벤트 서비스 호출)<br />
3. JWT 토큰에서 사용자 정의 필드를 파싱<br />

--- 

## 2. JWT 발행을 위해 인증 서버를 수정 및 JWT 토큰 확장

JWT OAuth2 의존성인 `spring-security-jwt` 을 추가하고 사용할 서명키를 Config Server의 원격 저장소에 설정한다.

**auth-service > pom.xml**
```xml
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

**auth-service > application.yaml**
```yaml
signing:
  key: assusingkey
```

이제 아래 4개의 클래스를 생성할 예정이다.

![JWT 설정 클래스](/assets/img/dev/2020/0930/directories.jpg)

- *CustomConfig.java*
    - *.properties 설정값 매핑
- *JWTTokenEnhancer.java*
    - 액세스 토큰에 추가 정보 삽입     
- *JWTOAuth2Config.java*
    - JWTTokenStoreConfig 에서 서명하고 생성한 JWT 토큰을 OAuth2 인증 서버로 연결
- *JWTTokenStoreConfig.java*
    - 인증 서버가 JWT 토큰을 생성, 서명, 해석하는 방법 지정

**auth-service > CustomConfig.java**    
```java
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

**auth-service > JWTTokenEnhancer.java**
```java
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

        // 모든 추가 속성은 HashMap 에 추가하고, 메서드에 전달된 accessToken 변수에 추가
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

**auth-service > JWTTokenStoreConfig.java**
```java
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

    /**
     * OAuth2 에 JWT 토큰 확장 클래스인 JWTTokenEnhancer 클래스를 사용한다고 알리기 위해 빈으로 노출
     * 여기서 노출하면 JWTOAuth2Config 에서 사용 가능
     * @return
     */
    @Bean
    public TokenEnhancer jwtTokenEnhancer() {
        return new JWTTokenEnhancer();
    }
}
```

아래 *JWTOAuth2Config.java* 는 이전 포스트의 *OAuth2Config.java* 와 동일한 역할을 한다.

**auth-service > JWTOAuth2Config.java**
```java
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
    private final JWTTokenEnhancer jwtTokenEnhancer;


    public JWTOAuth2Config(AuthenticationManager authenticationManager, @Qualifier("userDetailsServiceBean") UserDetailsService userDetailsService,
                           TokenStore tokenStore, DefaultTokenServices defaultTokenServices,
                           JwtAccessTokenConverter jwtAccessTokenConverter, JWTTokenEnhancer jwtTokenEnhancer) {
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
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        // 스프링 OAuth 의 TokenEnhancerChain 를 등록하면 여러 TokenEnhancer 후킹 가능
        TokenEnhancerChain tokenEnhancerChain = new TokenEnhancerChain();
        tokenEnhancerChain.setTokenEnhancers(Arrays.asList(jwtTokenEnhancer, jwtAccessTokenConverter));

        endpoints.tokenStore(tokenStore)                             // JWT, JWTTokenStoreConfig 에서 정의한 토큰 저장소
                .accessTokenConverter(jwtAccessTokenConverter)       // JWT, 스프링 시큐리티 OAuth2 가 JWT 사용하도록 연결
                .tokenEnhancer(tokenEnhancerChain)                   // JWT, endpoints 에 tokenEnhancerChain 연결
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

![JWT 토큰 내용](/assets/img/dev/2020/0930/jwt_encoding.jpg)

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX25hbWUiOiJhc3N1QWRtaW4iLCJzY29wZSI6WyJtb2JpbGVjbGllbnQiXSwiZXhwIjoxNjAxNTEyMTE1LCJ1c2VySWQiOiIxMjM0NSIsImF1dGhvcml0aWVzIjpbIlJPTEVfQURNSU4iLCJST0xFX1VTRVIiXSwianRpIjoiY2QzZGJiODctMjAxNS00MmIwLThlMzQtNDg4ZTg5MWUzYjYxIiwiY2xpZW50X2lkIjoiYXNzdWFwcCJ9.wSrFVCRUYVv6NdcMf-mAUd5GfX2f7rkkHG_5yzuODys",
    "token_type": "bearer",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX25hbWUiOiJhc3N1QWRtaW4iLCJzY29wZSI6WyJtb2JpbGVjbGllbnQiXSwiYXRpIjoiY2QzZGJiODctMjAxNS00MmIwLThlMzQtNDg4ZTg5MWUzYjYxIiwiZXhwIjoxNjA0MDYwOTE1LCJ1c2VySWQiOiIxMjM0NSIsImF1dGhvcml0aWVzIjpbIlJPTEVfQURNSU4iLCJST0xFX1VTRVIiXSwianRpIjoiMTIzMWVjYTktMDUxMC00YzI1LWE4NzEtYzEyNzcxZGQyMjI0IiwiY2xpZW50X2lkIjoiYXNzdWFwcCJ9.i97pF60RuhkQjQyR8kuUyF0LMFYrkWkMk0VIpacmRkY",
    "expires_in": 43199,
    "scope": "mobileclient",
    "userId": "12345",    // 직접 추가(토큰 확장)한 설정값
    "jti": "cd3dbb87-2015-42b0-8e34-488e891e3b61"
}
```

여기서 access_token 과 refresh_token 값은 Base64 로 인코딩된 문자열이다.
토큰 자체는 반환되지 않고, Base64 로 인코딩된 토큰 내용이 반환되는데 JWT 토큰 내용을 확인하고 싶으면 툴을 사용하여 확인이 가능하다.

디코딩 툴로는 [https://www.jsonwebtoken.io/](https://www.jsonwebtoken.io/), [https://jwt.io/](https://jwt.io/) 등이 있다.

![JWT 토큰 내용 decoding](/assets/img/dev/2020/0930/jwt_decoding.jpg)

***JWT 토큰을 서명은 했지만 암호화는 하지 않는다.<br />
모든 JWT 토큰은 디코딩하여 토큰 내용을 노출할 수 있다.<br />
따라서 개인 식별 정보는 절대 JWT 토큰에 추가하면 안된다.***

---

## 3. 마이크로서비스(이벤트/회원 서비스)에서 JWT 사용
위에서 OAuth2 인증 서버에서 JWT 토큰을 생성하도록 설정했으니 이제 각 마이크로서비스 (이벤트 서비스, 회원 서비스) 에서 JWT 토큰을
사용하도록 수정한다.

수정은 이벤트 서비스에 대해서만 기술할테니 회원 서비스는 동일하게 진행해주세요.

`spring-security-jwt` 의존성을 추가한 JWT 토큰에서 사용자 정의 필드 파싱다.

**event-service > pom.xml**
```xml
<dependency>
    <groupId>org.springframework.security</groupId>
    <artifactId>spring-security-jwt</artifactId>
    <version>1.1.1.RELEASE</version>
</dependency>
```

이제 인증 서버에 만들었던 *JWTTokenStoreConfig.java* 를 만들텐데 그 전에 [Spring Cloud - Netflix Zuul(2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/) 에서
만들어놓은 사용자 정의 필터와 인터셉터를 수정해야 한다.

- 수정 대상 클래스
    - *CustomContext.java* : 서비스가 쉽게 액세스할 수 있는 HTTP 헤더를 만들어 저장하는 클래스
    - *CustomContextFilter.java* : 유입되는 HTTP 요청을 가로채서 필요한 헤더값을 CustomContext 에 매핑<br />
    (즉, HTTP 헤더에서 인증 토큰과 상관관계 ID 파싱)
    - *CustomContextHolder.java* (수정하지 않음): ThreadLocal 저장소에 CustomContext 를 저장하는 클래스
    - *CustomContextInterceptor.java* : RestTemplate 인스턴스에서 실행되는 모든 HTTP 기반 서비스 발신 요청에 상관관계 ID 삽입

**event-service > CustomContext.java**
```java
/**
 * 서비스가 쉽게 액세스할 수 있는 HTTP 헤더를 만들어 저장하는 클래스
 * HTTP 요청에서 추출한 값을 보관하는 POJO
 */
@Component
public class CustomContext {
    public static final String CORRELATION_ID = "assu-correlation-id";
    public static final String AUTH_TOKEN     = "Authorization";        // 추가

    private static final ThreadLocal<String> correlationId = new ThreadLocal<>();
    private static final ThreadLocal<String> authToken = new ThreadLocal<>();       // 추가

    // 그 외 필요한 항목 넣을 수 있음 (인증 토큰 등...)


    public static String getCorrelationId() {       // 추가
        return correlationId.get();
    }

    public static void setCorrelationId(String cid) {       // 추가
        correlationId.set(cid);
    }

    public static String getAuthToken() {
        return authToken.get();
    }

    public static void setAuthToken(String aToken) {
        authToken.set(aToken);
    }
}
```

**event-service > CustomContextFilter.java**
```java
/**
 * 유입되는 HTTP 요청을 가로채서 필요한 헤더값을 CustomContext 에 매핑
 * 
 * REST 서비스에 대한 모든 HTTP 요청을 가로채서 컨텍스트 정보(상관관계 ID 등)를 추출해 CustomContext 클래스에 매핑하는 HTTP 서블릿 필터
 * (즉, HTTP 헤더에서 인증 토큰과 상관관계 ID 파싱)
 *
 * REST 서비스 호출 시 코드에서 CustomContext 액세스가 필요할 때마다 ThreadLocal 변수에서 검색해 읽어올 수 있음
 */
@Component
public class CustomContextFilter implements Filter {

    private static final Logger logger = LoggerFactory.getLogger(CustomContextFilter.class);

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        HttpServletRequest httpServletRequest = (HttpServletRequest) servletRequest;

        // HTTP 호출 헤더에서 상관관계 ID 를 검색하여 CustomContextHolder 의 CustomContext 클래스에 설정
        CustomContextHolder.getContext().setCorrelationId(httpServletRequest.getHeader(CustomContext.CORRELATION_ID));

        // 그 외 필요한 항목 넣을 수 있음 (인증 토큰 등...)
        CustomContextHolder.getContext().setAuthToken(httpServletRequest.getHeader(CustomContext.AUTH_TOKEN));      // 추가

        logger.debug("상관관계 ID {} 로 실행된 동적 라우팅", CustomContextHolder.getContext().getCorrelationId());

        filterChain.doFilter(httpServletRequest, servletResponse);
    }

    @Override
    public void init(FilterConfig filterConfig) {}

    @Override
    public void destroy() {}
}
```

**event-service > CustomContextInterceptor.java**
```java
/**
 * RestTemplate 인스턴스에서 실행되는 모든 HTTP 기반 서비스 발신 요청에 상관관계 ID 삽입 + 토큰
 */
public class CustomContextInterceptor implements ClientHttpRequestInterceptor {
    /**
     * RestTemplate 로 실제 HTTP 서비스 호출 전 intercept 메서드 호출
     */
    @Override
    public ClientHttpResponse intercept(HttpRequest httpRequest, byte[] bytes, ClientHttpRequestExecution clientHttpRequestExecution) throws IOException {
        HttpHeaders headers = httpRequest.getHeaders();

        headers.add(CustomContext.CORRELATION_ID, CustomContextHolder.getContext().getCorrelationId());

        // 그 외 필요한 항목 넣을 수 있음 (인증 토큰 등...)      // 추가
        headers.add(CustomContext.AUTH_TOKEN, CustomContextHolder.getContext().getAuthToken());     // HTTP 헤더에 인증 토큰 추가

        return clientHttpRequestExecution.execute(httpRequest, bytes);
    }
}
```

이제 *JWTTokenStoreConfig.java* 를 만들텐데 해당 클래스는 인증 서버에서 만든 *JWTTokenStoreConfig.java* 에서 
*public TokenEnhancer jwtTokenEnhancer()* 만 제거하면 되므로 따로 설명하지 않는다. 


`OAuth2RestTemplate` 는 JWT 기반 토큰을 전파하지 않으므로 사용자 정의 RestTemplate 빈을 추가하여 토큰을 삽입한다.

[Spring Cloud - Netflix Zuul(2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/) 의 *2.2. 서비스 호출 시 상관관계 ID 사용* 에서
만든 RestTemplate 빈에 `@Primary` 애노테이션만 추가하면 된다.

아래 코드에서 *CustomContextInterceptor.java* 가 상속받은 `ClientHttpRequestInterceptor` 는 REST 기반 호출이 수행되기 전에
실행 기능을 후킹할 수 있다.

>**후킹 (Hooking)**
>
>함수 호출, 메시지, 이벤트 등을 중간에서 바꾸거나 가로채는 명령, 방법, 기술이나 행위

**event-service > EventServiceApplication.java**
```java
/**
 * 사용자 정의 RestTemplate 빈을 생성하여 토큰 삽입
 * RestTemplate 기반 호출이 수행되기 전 후킹되는 메서드
 */
@Primary
@LoadBalanced
@Bean
public RestTemplate getCustomRestTemplate() {
    RestTemplate template = new RestTemplate();
    List interceptors = template.getInterceptors();

    // CustomContextInterceptor 는 Authorization 헤더를 모든 REST 호출에 삽입함
    if (interceptors == null) {
        template.setInterceptors(Collections.singletonList(new CustomContextInterceptor()));
    } else {
        interceptors.add(new CustomContextInterceptor());
        template.setInterceptors(interceptors);
    }
    return template;
}
```

이제 회원 서비스, 이벤트 서비스에서도 JWT 토큰을 사용할 준비가 되었으니 실제 호출하여 확인해보도록 하자.

회원 서비스에서 이벤트 서비스의 REST API 를 호출할텐데 기존에 만들어 둔 API 를 그대로 활용하여 호출한다.

**event-service > EventController.java**
```java
/**
 * 회원 서비스에서 호출할 메서드
 */
@GetMapping(value = "gift/{name}")
public String gift(@PathVariable("name") String gift) {
    return "[EVENT] Gift is " + gift;
}
```

**member-service > MemberController.java**
```java
/**
 * RestTemplate 를 이용하여 이벤트 서비스의 REST API 호출
 */
@GetMapping(value = "gift/{name}")
public String gift(ServletRequest req, @PathVariable("name") String name) {
    return "[MEMBER] " + eventRestTemplateClient.gift(name) + " / port is " + req.getServerPort();
}
```

**member-service > EventRestTemplateClient.java**
```java
@Component
public class EventRestTemplateClient {

    private final RestTemplate restTemplate;
    private final CustomConfig customConfig;

    public EventRestTemplateClient(RestTemplate restTemplate, CustomConfig customConfig) {
        this.restTemplate = restTemplate;
        this.customConfig = customConfig;
    }

    String URL_PREFIX = "/api/evt/event/";      // 이벤트 서비스의 Zuul 라우팅경로와 이벤트 클래스 주소

    public String gift(String name) {
        /*ResponseEntity<EventGift> restExchange =
                restTemplate.exchange(
                    "http://event-service/event/gift/{name}",
                    HttpMethod.GET,
                    null, EventGift.class, name
                );*/
        ResponseEntity<String> restExchange =
                restTemplate.exchange(
                        "http://" + customConfig.getServiceIdZuul() + URL_PREFIX + "gift/{name}",   // http://localhost:5555/api/mb/member/gift/flower
                        HttpMethod.GET,
                        null, String.class, name
                );

        return restExchange.getBody();
    }
}
```

우선 JWT 토큰을 헤더에 넣지 않은 상태로 회원 서비스의 REST API 를 호출하면 아래와 같이 `unauthorized` 오류가 리턴된다.

![JWT 없이 REST API 호출](/assets/img/dev/2020/0930/no_jwt.jpg)


이제 JWT 토큰을 획득한 후 헤더에 토큰을 추가한 후 회원 서비스의 REST API 를 호출해보도록 하자.

**토큰 획득**
POST - [http://localhost:8901/auth/oauth/token](http://localhost:8901/auth/oauth/token)

![JWT 토큰과 함께 REST API 호출](/assets/img/dev/2020/0930/ok_jwt.jpg)

REST API 호출 시 Base64 로 인코딩된 JWT 토큰을 HTTP Authorization 헤더의 Bearer [JWT 토큰값] 으로 전달하면
서비스가 정상적으로 호출된다.

---

## 4. JWT 토큰에서 사용자 정의 필드 파싱
JWT 토큰에서 사용자 정의 필드를 파싱하는 방법을 확인해보자.

참고로 기본 필드들은 아래와 같다.

```json
{user_name=assuAdmin, scope=[mobileclient], exp=1601582137, authorities=[ROLE_ADMIN, ROLE_USER], 
jti=595aa7f9-7887-4263-85b1-20aa3555ffd2, client_id=assuapp}
```

여기선 이전 포스트인 [Spring Cloud - Netflix Zuul(2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/) 의 *2. 사전 필터* 에서 구성한 *PreFilter.java* 를
수정하여 Zuul 로 전달되는 JWT 토큰에서 사용자 정의 필드인 *userId* (위의 *JWTTokenEnhancer.java* 에서 추가함) 필드를 파싱해 볼 예정이다.

`jjwt` 와 `jaxb-api` 의존성을 추가한다.
`jaxb-api` 의존성은 코드에서 직접 사용하고 있지는 않지만 **parseClaimsJws()** 에서 데이터 파싱 시 내부적으로 사용한다.

**zuul-service > pom.xml**
```xml
<!-- JWT Parser -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt</artifactId>
    <version>0.9.1</version>
</dependency>
<!-- parseClaimsJws 데이터 파싱 시 내부적으로 사용 -->
<dependency>
    <groupId>javax.xml.bind</groupId>
    <artifactId>jaxb-api</artifactId>
    <version>2.3.1</version>
</dependency>
```

이제 기존의 *PreFilter.java* 에 *getUserId()* 메서드를 추가한 후 *run()* 에서 *userId* 를 출력해준다.<br />
*getUserId()* 메서드는 HTTP Authorization 헤더에서 JWT 토큰을 파싱한다.

**zuul-service > FilterUtils.java**
```java
// ... 이전 내용 생략
public static final String AUTH_TOKEN = "Authorization";

public final String getAuthToken() {
    RequestContext ctx = RequestContext.getCurrentContext();
    return ctx.getRequest().getHeader(AUTH_TOKEN);
}
```

**zuul-service > PreFilter.java**
```java
// ... 이전 내용 생략
/**
 * 필터의 비즈니스 로직 구현
 *      서비스가 필터를 통과할 때마다 실행되는 메서드
 *      상관관계 ID의 존재 여부 확인 후 없다면 생성하여 헤더에 설정
 */
@Override
public Object run() {
    if (isCorrelationIdPresent()) {
        // 헤더에 assu-correlation-id 가 있다면
        logger.debug("============ assu-correlation-id found in pre filter: {}. ", filterUtils.getCorrelationId());
    } else {
        // 헤더에 assu-correlation-id 가 없다면 상관관계 ID 생성하여 RequestContext 의 addZuulRequestHeader 로 추가
        filterUtils.setCorrelationId(generateCorrelationId());
        logger.debug("============ assu-correlation-id generated in pre filter: {}.", filterUtils.getCorrelationId());
    }

    RequestContext ctx = RequestContext.getCurrentContext();
    logger.debug("============ Processing incoming request for {}.",  ctx.getRequest().getRequestURI());

    logger.info("============ user id is {}.",  getUserId());       // 추가
    return null;
}

private String getUserId() {
    String result = "";
    if (filterUtils.getAuthToken() != null) {
        // HTTP Authorization 헤더에서 토큰 파싱
        String authToken = filterUtils.getAuthToken().replace("Bearer ", "");
        try {
            // 토큰 서명에 사용된 서명 키를 전달해서 Jwts 클래스를 사용해 토큰 파싱
            Claims claims = Jwts.parser()
                    .setSigningKey(customConfig.getJwtSigningKey().getBytes("UTF-8"))
                    .parseClaimsJws(authToken).getBody();
            // JWT 토큰에서 userId 가져옴 (userId 는 인증 서버의 JWTTokenEnhancer 에서 추가했음)
            result = (String) claims.get("userId");
            // {user_name=assuAdmin, scope=[mobileclient], exp=1601582137, userId=12345, authorities=[ROLE_ADMIN, ROLE_USER], jti=595aa7f9-7887-4263-85b1-20aa3555ffd2, client_id=assuapp}
            logger.info("claims: {}", claims);
        } catch (SignatureException e) {
            logger.error("Invalid JWT signature: {}", e.getMessage());
        } catch (MalformedJwtException e) {
            logger.error("Invalid JWT token: {}", e.getMessage());
        } catch (ExpiredJwtException e) {
            logger.error("JWT token is expired: {}", e.getMessage());
        } catch (UnsupportedJwtException e) {
            logger.error("JWT token is unsupported: {}", e.getMessage());
        } catch (IllegalArgumentException e) {
            logger.error("JWT claims string is empty: {}", e.getMessage());
        } catch (Exception e) {
            logger.error("Exception : {}", e.getMessage());
        }
    }
    return result;
} 
```

이제 Zuul 을 통과하는 아무 REST API 를 호출해보면 아래와 같이 JWT 토큰 내 userId 가 출력되는 것을 확인할 수 있다.

```text
c.a.cloud.zuulserver.filters.PreFilter   : ============ Processing incoming request for /api/evt/event/gift/manok.
c.a.cloud.zuulserver.filters.PreFilter   : claims: {user_name=assuAdmin, scope=[mobileclient], exp=1601582137, userId=12345, authorities=[ROLE_ADMIN, ROLE_USER], jti=595aa7f9-7887-4263-85b1-20aa3555ffd2, client_id=assuapp}
c.a.cloud.zuulserver.filters.PreFilter   : ============ user id is 12345.
c.a.cloud.zuulserver.filters.PostFilter  : ============ Adding the correlation id to the outbound headers. 
c.a.cloud.zuulserver.filters.PostFilter  : ============ Completing outgoing request for /api/evt/event/gift/manok.
```

---

## 5. 실제 운영에서의 MSA 보안

실제 운영할 마이크로서비스를 구성할 때는 아래의 사항을 반드시 따라야 한다.

- **모든 통신은 HTTPS/SSL 을 사용**
- **모든 통신은 API 게이트웨이를 통과**
    - 서비스가 실행되는 각 서버/엔드포인트/포트는 클라이언트에서 직접 접근할 수 없어야 함
    - 마이크로서비스가 실행 중인 운영 체제는 게이트웨이에서 유입되는 트래픽만 수용하도록 네트워크 계층 구성
- **공개 API 와 비공개 API 영역 구분**
    - **공개 영역**
        - 클라이언트가 소비사는 공개 API 가 포함된 영역
        - 공개 영역의 API 들은 여러 서비스에서 데이터를 가져와 수집하는 정도의 협소한 작업만 실행
        - 게이트웨이 뒤에 위치해야 하고, OAuth2 인증을 수행할 수 있는 인증 서버 보유 필요
        - 클라이언트가 공개 API 에 접근할 때는 게이트웨이가 제공하는 단일 경로로만 접근
    - **비공개 영역**
        - 핵심 기능과 데이터를 보호하는 역할
        - 자체 게이트웨이 필요
- **불필요한 네트워크 포트는 차단**
    - 서비스나 모니터링, 로그 수집 등에 필요한 포트의 인/아웃바운드만 하용
    - 아웃바운드도 차단할 경우 서비스가 공격당하더라도 데이터 유출을 막을 수 있음


--- 

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [JWT 의 공개/시크릿 키를 사용한 비대칭 암호화](https://www.baeldung.com/spring-security-oauth-jwt)
* [JWT Decoding Tool](https://www.jsonwebtoken.io/)
* [JWT 토큰 생성 및 파싱 1](https://jamcode.tistory.com/45)
* [JWT 토큰 생성 및 파싱 2](https://amanokaze.github.io/blog/Spring-Security-Authentication/)
* [java.lang.ClassNotFoundException: javax.xml.bind.DatatypeConverter 관련 오류 1](https://luvstudy.tistory.com/61)
* [java.lang.ClassNotFoundException: javax.xml.bind.DatatypeConverter 관련 오류 2](https://qastack.kr/programming/43574426/how-to-resolve-java-lang-noclassdeffounderror-javax-xml-bind-jaxbexception-in-j)
