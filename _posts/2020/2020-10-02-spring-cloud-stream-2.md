---
layout: post
title:  "Spring Cloud - Stream, 분산 캐싱 (2/2)"
date: 2020-10-02 10:00
categories: dev
tags: msa eda event-driven-architecture mda message-driven-architecture spring-cloud-stream redis caching  
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Spring Cloud Stream 과 Redis 를 사용한 분산 캐싱에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

<!-- TOC -->
  * [1. 스프링 클라우드 스트림을 사용한 분산 캐싱](#1-스프링-클라우드-스트림을-사용한-분산-캐싱)
  * [2. 분산 캐싱 구현](#2-분산-캐싱-구현)
    * [2.1. 스프링 데이터 레디스 의존성 추가](#21-스프링-데이터-레디스-의존성-추가)
    * [2.2. 레디스 DB 커넥션을 설정](#22-레디스-db-커넥션을-설정)
    * [2.3. 스프링 데이터 레디스의 Repository 클래스를 정의](#23-스프링-데이터-레디스의-repository-클래스를-정의)
    * [2.4. 레디스에서 회원 데이터를 저장/조회](#24-레디스에서-회원-데이터를-저장조회)
  * [3. 사용자 정의 채널 설정 및 EDA 기반의 캐싱 구현](#3-사용자-정의-채널-설정-및-eda-기반의-캐싱-구현)
    * [3.1. 사용자 정의 채널 설정](#31-사용자-정의-채널-설정)
    * [3.2. 메시지 수신 시 캐시 무효화](#32-메시지-수신-시-캐시-무효화)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

이 포스트에선 **Redis 와 Kafka 를 사용하여 EDA 기반의 분산 캐싱**을 구현하고, 사용자 정의 채널로 EDA 를 구축해본다. 
  
--- 

## 1. 스프링 클라우드 스트림을 사용한 분산 캐싱

이전 포스트에서 회원 서비스와 이벤트 서비스를 메시징을 통하여 통신하도록 설정했지만 실제 메시지로 아무런 작업도 하지 않는다.
이제 클라우드 스트림을 이용하여 분산 캐싱을 구현해 볼 것이다.

시나리오는 아래와 같다.

>- 이벤트 서비스는 회원 데이터에 대한 분산 레디스 캐시를 항상 확인한다.<br />
>- 회원 데이터가 캐시에 있다면 캐시 데이터를 반환하고,<br />
>캐시 데이터가 없다면 회원 서비스를 호출하여 호출 결과를 레디스 해시(hash)에 캐싱한다.<br />
>- 회원 데이터가 업데이트되면 회원 서비스는 Kafka 에 메시지를 보낸다.<br />
>- 이벤트 서비스가 캐시를 무효화하려면 메시지를 수신하여 캐시 삭제를 위해 레디스에 삭제 호출을 한다.

---

## 2. 분산 캐싱 구현

레디스를 사용할 수 있도록 이벤트 서비스를 수정할 것이다.
`스프링 데이터(Spring Data)` 는 레디스 도입을 수월하게 해준다.

분산 캐싱 구현은 아래의 순서로 진행된다.

1. **스프링 데이터 레디스 의존성을 추가**한다.
2. **레디스 DB 커넥션을 설정**한다.
3. 레디스 해시와 통신하는 **스프링 데이터 레디스의 Repository 클래스를 정의**한다.
4. 레디스와 이벤트 서비스를 사용하여 **회원 데이터를 저장하고 조회**한다.

---

### 2.1. 스프링 데이터 레디스 의존성 추가

`jedis`, `common-pool2`, `spring-data-redis` 의존성을 추가한다.

**event-service > pom.xml**
```xml
<!-- 분산 캐싱 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
<dependency>
    <groupId>redis.clients</groupId>
    <artifactId>jedis</artifactId>
    <version>3.3.0</version>
</dependency>
<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-pool2</artifactId>
    <version>2.9.0</version>
</dependency>
```

---

### 2.2. 레디스 DB 커넥션을 설정

스프링은 레디스 서버와 통신 시 오픈 소스 프로젝트인 `Jedis` 를 사용한다.

레디스 인스턴스와 통신하려면 `JedisConnectionFactory` 를 빈으로 노출해주어야 한다.<br />
이벤트 서비스의 부트스트랩 클래스에 아래와 같이 `JedisConnectionFactory` 와 `RedisTemplate` 객체를 만든 후 빈으로 노출해준다.
레디스와 연결이 되면 `JedisConnectionFactory` 커넥션을 사용하여 `RedisTemplate` 객체를 생성한다.
`RedisTemplate` 객체는 레디스 서비스에 회원 데이터에 대한 쿼리를 수행한 후 스프링 데이터 레포지토리 클래스(*MemberRedisRepositoryImpl.java*)에서 사용된다.

**event-service > EventServiceApplication.java**
```java
@EnableEurekaClient
@SpringBootApplication
@EnableFeignClients
@EnableResourceServer           // 보호 자원으로 설정
@EnableBinding(Sink.class)      // 이 애플리케이션을 메시지 브로커와 바인딩하도록 스프링 클라우드 스트림 설정
                                // Sink.class 로 지정 시 해당 서비스가 Sink 클래스에 정의된 채널들을 이용해 메시지 브로커와 통신
public class EventServiceApplication {
    // ... 생략

    /**
     * 레디스 서버에 실제 DB 커넥션을 설정
     * 레디스 인스턴스와 통신하려면 JedisConnectionFactory 를 빈으로 노출해야 함
     * 이 커넥션을 사용해서 스프링 RedisTemplate 객체 생성
     */
    @Bean
    public JedisConnectionFactory jedisConnectionFactory() {
        JedisConnectionFactory jedisConnectionFactory = new JedisConnectionFactory();
        jedisConnectionFactory.setHostName(customConfig.getRedisServer());
        jedisConnectionFactory.setPort(customConfig.getRedisPort());
        return jedisConnectionFactory;
    }

    /**
     * 레디스 서버에 작업 수행 시 사용할 RedisTemplate 객체 생성
     */
    @Bean
    public RedisTemplate<String, Object> redisTemplate() {
        RedisTemplate<String, Object> redisTemplate = new RedisTemplate<>();
        redisTemplate.setConnectionFactory(jedisConnectionFactory());
        return redisTemplate;
    }
}
```

**config-repo > event-service.yaml**
```yaml
#redis
redis:
  server: localhost
  port: 6379
```

여기까지 레디스와 통신할 수 있도록 기본 설정 작업을 완료하였다.

---

### 2.3. 스프링 데이터 레디스의 Repository 클래스를 정의

*이 포스트에서 레디스에 대해선 자세히 다루지 않을 것이다. (레디스에 대해선 별도로 찾아보세요~)*

레디스는 key-value 형태의 데이터 저장소이다.<br />
레디스 저장소에 접근하기 위해서 스프링 데이터를 사용하기 때문에 repository 클래스를 정의해야 한다.

>스프링 데이터는 사용자 정의 repository 클래스로 SQL 쿼리를 작성하지 않아도 자바 클래스가 DB 를 액세스할 수 있는 간단한 메커니즘을
>제공함

이제 레디스 repository 를 정의해보도록 하자.

**event-service > MemberRedisRepository.java**
```java
/**
 * 레디스에 액세스해야 하는 클래스에 주입된 인터페이스
 */
public interface MemberRedisRepository {
    void saveMember(Member member);
    void updateMember(Member member);
    void deleteMember(String userId);
    Member findMember(String userId);
}
```

**event-service > MemberRedisRepositoryImpl.java**
```java
/**
 * 부트스트랩 클래스에서 정의한 RedisTemplate 빈을 사용하여 레디스 서버와 통신
 */
@Repository
public class MemberRedisRepositoryImpl implements MemberRedisRepository {

    private static final String HASH_NAME = "member";       // 회원 데이터가 저장되는 레디스 서버의 해시명
    private final RedisTemplate<String, Member> redisTemplate;
    private HashOperations hashOperations;      // HashOperation 클래스는 레디스 서버에 데이터 작업을 수행하는 스프링 헬퍼 메서드의 집합

    public MemberRedisRepositoryImpl(RedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @PostConstruct
    public void init() {
        hashOperations = redisTemplate.opsForHash();

        // 키와 값을 명시적으로 직렬화해주지 않으면 default serializer 로 JdkSerializationRedisSerializer 를 사용하는데
        // 그러면 \xac\xed\x00\x05t\x00\x06member 이런 식으로 저장됨
       redisTemplate.setKeySerializer(new StringRedisSerializer());
        redisTemplate.setValueSerializer(new GenericJackson2JsonRedisSerializer());
    }

    @Override
    public void saveMember(Member member) {
        hashOperations.put(HASH_NAME, member.getId(), member);
    }

    @Override
    public void updateMember(Member member) {
        hashOperations.put(HASH_NAME, member.getId(), member);
    }

    @Override
    public void deleteMember(String userId) {
        hashOperations.delete(HASH_NAME, userId);
    }

    @Override
    public Member findMember(String userId) {
        return (Member) hashOperations.get(HASH_NAME, userId);
    }
}
```

여기서 주목할 것은 레디스 서버는 여러 해시와 데이터 구조를 가질 수 있기 때문에 작업을 수행할 데이터 구조 이름을 레디스에 알려주어야 한다는
것이다.
여기선 *HASH_NAME* 상수에 저장된 *member* 이다.

---

### 2.4. 레디스에서 회원 데이터를 저장/조회

위 작업까지 진행했으면 이제 레디스 작업을 수행할 준비가 되었으니 회원 데이터가 필요할 때 레디스 캐시를 먼저 확인하도록
이벤트 서비스를 수정해보도록 하자.

**event-service > MemberCacheRestTemplateClient.java**
```java
/**
 * 회원 데이터 필요 시 회원 서비스 호출 전 레디스 캐시 먼저 확인
 */
@Component
public class MemberCacheRestTemplateClient {

    private static final Logger logger = LoggerFactory.getLogger(MemberCacheRestTemplateClient.class);

    private final RestTemplate restTemplate;
    private final MemberRedisRepository memberRedisRepository;
    private final CustomConfig customConfig;

    public MemberCacheRestTemplateClient(RestTemplate restTemplate, MemberRedisRepository memberRedisRepository,  CustomConfig customConfig) {
        this.restTemplate = restTemplate;
        this.memberRedisRepository = memberRedisRepository;
        this.customConfig = customConfig;
    }

    String URL_PREFIX = "/api/mb/member/";      // 회원 서비스의 Zuul 라우팅경로와 회원 클래스 주소

    /**
     * 회원 아이디로 레디스에 저장된 Member 클래스 조회
     */
    private Member checkRedisCache(String userId) {
        try {
            return memberRedisRepository.findMember(userId);
        } catch (Exception e) {
            logger.error("======= Error encountered while trying to retrieve member {} check Redis Cache., Exception {}", userId, e);
            return null;
        }
    }

    /**
     * 레디스 캐시에 데이터 저장
     */
    private void cacheMemberObject(Member member) {
        try {
            memberRedisRepository.saveMember(member);
        } catch (Exception e) {
            e.printStackTrace();
            logger.error("======= Unable to cache member {} in Redis. Exception {}", member.getId(), e);
        }
    }

    public Member getMember(String userId) {

        Member member = checkRedisCache(userId);

        // 레디스에 데이터가 없다면 원본 데이터에서 데이터를 조회하기 위해 회원 서비스 호출
        if (member != null) {
            logger.debug("======= Successfully retrieved an Member {} from the redis cache: {}", userId, member);
            return member;
        }

        logger.debug("======= Unable to locate member from the redis cache: {}", userId);

        ResponseEntity<Member> restExchange =
                restTemplate.exchange(
                        "http://" + customConfig.getServiceIdZuul() + URL_PREFIX + "{userId}",   // http://localhost:5555/api/mb/member/userInfo/rinda
                        HttpMethod.GET,
                        null,
                        Member.class,
                        userId
                );

        // 캐시 레코드 저장
        member = restExchange.getBody();

        // 조회한 객체를 캐시에 저장
        if (member != null) {
            cacheMemberObject(member);
        }
        return member;
    }
}
```

***캐시 통신 시 예외 처리에 특히 주의해야 한다.<br />
레디스와 통신할 수 없더라도 전체 호출을 실패로 하지 말고, 예외 로깅 후 DB 에서 조회하도록 해야 한다.<br />
캐싱은 성능 향상을 돕기 위한 것이므로 캐싱 서버가 없더라도 호출의 성공 여부가 영향을 받아서는 안된다.***


레디스 캐싱 데이터 사용 API 는 아래와 같이 구성하였다.

**event-service > EventController.java**
```java
// ... 생략
private final MemberCacheRestTemplateClient memberCacheRestTemplateClient;

/**
 * 레디스 캐싱 데이터 사용
 */
@GetMapping(value = "{userId}")
public Member userInfo(@PathVariable("userId") String userId) {
    return memberCacheRestTemplateClient.getMember(userId);
}
```

```shell
-- 레디스 실행
redis-server.bat 실행
```

[http://localhost:8070/event/1234](http://localhost:8070/event/1234)

![레디스 캐싱 데이터 사용 메서드 조회](/assets/img/dev/20201001/redis.jpg)

처음으로 API 호출 시 레디스에 데이터가 없으므로 회원 서비스를 호출하여 데이터 조회 후 레디스에 저장한다.
이벤트 서비스와 회원 서비스 로그는 아래와 같다.

```shell
-- 이벤트 서비스 로그
DEBUG 22520 --- MemberCacheRestTemplateClient  : ======= Unable to locate member from the redis cache: 1234

-- 회원 서비스 로그
DEBUG MemberController      : ====== 회원 서비스 호출!
```

이제 다시 한번 동일한 조건으로 호출해보면 위에서 레디스에 데이터를 저장했으므로 회원 서비스를 호출하지 않고,
바로 레디스에 저장된 데이터를 반환하는 것을 알 수 있다.

```shell
-- 이벤트 서비스 로그
DEBUG MemberCacheRestTemplateClient  : ======= Successfully retrieved an Member 1234 from the redis cache: com.assu.cloud.eventservice.model.Member@36f3d263

-- 회원 서비스 로그
없음
```

---

## 3. 사용자 정의 채널 설정 및 EDA 기반의 캐싱 구현

지금까지 스프링 클라우스 스트림 사용법과 레디스를 이용한 분산 캐싱에 대해 알아보았다.<br />
이제 이 둘을 조합하여 EDA 기반의 분산 캐싱을 구현해 보도록 하자.

위에서 말한 시나리오 중 기울임으로 표기된 부분이 지금까지 진행한 부분이다.

>*- 이벤트 서비스는 회원 데이터에 대한 분산 레디스 캐시를 항상 확인한다.<br />*
>*- 회원 데이터가 캐시에 있다면 캐시 데이터를 반환하고,<br />
>캐시 데이터가 없다면 회원 서비스를 호출하여 호출 결과를 레디스 해시(hash)에 캐싱한다.<br />*
>- 회원 데이터가 업데이트되면 회원 서비스는 Kafka 에 메시지를 보낸다.<br />
>- 이벤트 서비스가 캐시를 무효화하려면 메시지를 수신하여 캐시 삭제를 위해 레디스에 삭제 호출을 한다. 

---

### 3.1. 사용자 정의 채널 설정

이전 포스트인 [Spring Cloud - Stream, 분산 캐싱 (1/2)](https://assu10.github.io/dev/2020/10/01/spring-cloud-stream/) 의
*3. 메시지 발행자와 소비자 구현* 에서는 스프링 클라우드 스트림 프로젝트의 `Source` 와 `Sink` 인터페이스에서 제공하는
`output` 및 `input` 채널을 사용하였다.

>**Source**<br />
>publisher, 기본 채널명은 output<br />
>**Sink**<br />
>consumer, 기본 채널명은 input
  
만약 애플리케이션에 둘 이상의 채널을 정의하거나 고유한 채널 이름을 사용하려 한다면, 사용자 정의 인터페이스를 정의하고
필요한 만큼 input 과 output 채널을 노출하면 된다. 

사용자 정의 input 채널 인터페이스는 아래와 같다.

**event-service > CustomChannels.java**
```java
/**
 * 사용자 정의 input 채널 (SINK.INPUT 같은...), Consumer
 */
public interface CustomChannels {

    @Input("inboundMemberChanges")      // @Input 은 채널 이름을 정의하는 메서드 레벨 애너테이션
    SubscribableChannel members();      // @Input 애너테이션으로 노출된 채널은 모두 SubscribableChannel 클래스를 반환해야 함
}
```

노출하려는 사용자 정의 input 채널마다 `SubscribableChannel` 클래스를 반환하는 메서드를 만들고, `@Input` 애너테이션을 추가한다.<br />
output 채널 정의 시엔 호출할 메서드에 `@Output` 애너테이션을 추가하고, `MessageChannel` 클래스를 반환하도록 하면 된다.

사용자 정의 input 채널을 정의했으니 이 채널을 Spring Cloud Stream Kafka 토픽에 매핑하는 작업을 하자.

**config-repo > event-service.yaml**
```yaml
# 스프링 클라우드 스트림 설정
spring:
  cloud:
    stream:
      bindings:
        inboundMemberChanges:   # inboundMemberChanges 은 채널명, EventServiceApplication 의 Sink.INPUT 채널에 매핑되고, input 채널을 mgChangeTopic 큐에 매핑함
          destination: mbChangeTopic       # 메시지를 넣은 메시지 큐(토픽) 이름
          content-type: application/json
          group: eventGroup   # 메시지를 소비할 소비자 그룹의 이름
      kafka:    # stream.kafka 는 해당 서비스를 Kafka 에 바인딩
        binder:
          zkNodes: localhost    # zkNodes, brokers 는 스트림에게 Kafka 와 주키퍼의 네트워크 위치 전달
          brokers: localhost
#spring:
#  cloud:
#    stream:
#      bindings:
#        input:   # input 은 채널명, EventServiceApplication 의 Sink.INPUT 채널에 매핑되고, input 채널을 mgChangeTopic 큐에 매핑함
#          destination: mbChangeTopic       # 메시지를 넣은 메시지 큐(토픽) 이름
#          content-type: application/json
#          group: eventGroup   # 메시지를 소비할 소비자 그룹의 이름
#      kafka:    # stream.kafka 는 해당 서비스를 Kafka 에 바인딩
#        binder:
#          zkNodes: localhost    # zkNodes, brokers 는 스트림에게 Kafka 와 주키퍼의 네트워크 위치 전달
#          brokers: localhost
```

기존엔 Sink.INPUT 채널을 사용했기 때문에 spring.cloud.stream.bindings.**input** 에 Spring Cloud Stream Kafka 토픽을 매핑했지만
spring.cloud.stream.bindings.**inboundMemberChanges** 처럼 새로 추가한 input 채널명으로 수정한다.

사용자 정의 input 채널을 사용하려면 메시지를 처리할 클래스에 *CustomChannels* 인터페이스를 바인딩해 주어야 한다.

**event-service > MemberChangeHandler.java**
```java
/**
 * 사용자 정의 채널을 사용하여 메시지 수신
 * 이 애플리케이션을 메시지 브로커와 바인딩하도록 스프링 클라우드 스트림 설정
 */
@EnableBinding(CustomChannels.class)    // CustomChannels.class 로 지정 시 해당 서비스가 CustomChannels 클래스에 정의된 채널들을 이용해 메시지 브로커와 통신
public class MemberChangeHandler {

    private static final Logger logger = LoggerFactory.getLogger(MemberChangeHandler.class);
    private final MemberRedisRepository memberRedisRepository;

    public MemberChangeHandler(MemberRedisRepository memberRedisRepository) {
        this.memberRedisRepository = memberRedisRepository;
    }

    /**
     * 메시지가 입력 채널에서 수신될 때마다 이 메서드 실행
     */
    @StreamListener("inboundMemberChanges")     // Sink.INPUT 대신 사용자 정의 채널명인 inboundMemberChanges 전달
    public void loggerSink(MemberChangeModel mbChange) {
        logger.info("======= Received a message of type {}", mbChange.getType());
        switch (mbChange.getAction()) {
            case "GET":
                logger.debug("Received a GET event from the member service for userId {}", mbChange.getUserId());
                break;
            case "SAVE":
                logger.debug("Received a SAVE event from the member service for userId {}", mbChange.getUserId());
                break;
            case "UPDATE":
                logger.debug("Received a UPDATE event from the member service for userId {}", mbChange.getUserId());
                memberRedisRepository.deleteMember(mbChange.getUserId());       // 캐시 무효화
                break;
            case "DELETE":
                logger.debug("Received a DELETE event from the member service for userId {}", mbChange.getUserId());
                memberRedisRepository.deleteMember(mbChange.getUserId());
                break;
            default:
                logger.debug("Received an UNKNOWN event from the member service for userId {}", mbChange.getType());
                break;
        }
    }
}
```

위 내용은 부트스트랩 클래스에 작업했던 `@EnableBinding(Sink.class)` 와 *loggerSink(MemberChangeModel mbChange)* 를 재구성한 것이다.
따라서 부트스트랩 클래스에 작업했던 위 두 작업은 주석 처리하도록 한다.

아래 부분을 잘 보면서 이전 내용과 비교하여 떠올려보세요.
**event-service > MemberChangeHandler.java**
```java
// 부트스트랩에 작업했었던 채널 매핑
@StreamListener(Sink.INPUT)     // 메시지가 입력 채널에서 수신될 때마다 이 메서드 실행

// 사용자 정의 채널 매핑
@StreamListener("inboundMemberChanges")     // Sink.INPUT 대신 사용자 정의 채널명인 inboundMemberChanges 전달
```  

---

### 3.2. 메시지 수신 시 캐시 무효화

회원 서비스는 이미 아래처럼 데이터 변경 시 마다 메시지를 발행하도록 되어 있기 때문에 별도 수정할 내용은 없다.

**member-service > MemberController.java**
```java
/**
 * 단순 메시지 발행
 */
@PostMapping("/{userId}")
public void saveUserId(@PathVariable("userId") String userId) {
    // DB 에 save 작업..
    simpleSourceBean.publishMemberChange("SAVE", userId);
}
```

메시지 소비자인 이벤트 서비스 역시 위에서 작성한 *MemberChangeHandler.java* 에서 액션이 UPDATE, DELETE 인 경우 
*memberRedisRepository.deleteMember(mbChange.getUserId());* 를 통해 캐시 무효화를 하고 있다.

이제 실제 동작을 확인해보도록 하자.

확인을 위해 회원 서비스에 아래와 같은 API 를 추가한다.

**member-service > MemberController.java**
```java
/**
 * 이벤트 서비스에서 캐시 제거를 위한 메서드
 */
@DeleteMapping("userInfo/{userId}")
public void deleteUserInfoCache(@PathVariable("userId") String userId) {
    logger.debug("====== 회원 삭제 후 DELETE 메시지 발생");

    // DB 에 삭제 작업  (간편성을 위해 DB 작업은 생략)
    simpleSourceBean.publishMemberChange("DELETE", userId);
}
```

이제 `flushall` 로 모든 레디스 키를 삭제한 뒤 데이터 상태 변화 메시지 수신 및 레디스에 잘 적용되는지 확인해보도록 하자.

```shell
127.0.0.1:6379> flushall
OK
``` 

이벤트 서비스의 조회 API 중 레디스에서 먼저 데이터 확인 후 레디스에 데이터가 없는 경우 회원 서비스를 호출하는 REST API 를 호출해보자.

[GET] [http://localhost:8070/event/1234](http://localhost:8070/event/1234)
 
![레디스 캐싱 데이터 사용 메서드 조회](/assets/img/dev/20201001/redis1.jpg)

```shell
-- 이벤트 서비스 로그 (캐싱된 데이터가 없다, 회원 서비스 호출하여 데이터 조회 후 레디스 해시에 캐싱)
DEBUG 24632 MemberCacheRestTemplateClient  : ======= Unable to locate member from the redis cache: 1234

-- 회원 서비스 로그
DEBUG 11448 MemberController      : ====== 회원 저장 서비스 호출!
```

위 API 를 다시 한번 호출한 후 로그를 보자.

```shell
-- 이벤트 서비스 로그 (캐싱된 데이터가 있으므로 레디스에 캐싱된 데이터를 사용한다)
DEBUG 24632 MemberCacheRestTemplateClient  : ======= Successfully retrieved an Member 1234 from the redis cache: com.assu.cloud.eventservice.model.Member@4abb9b3d

-- 회원 서비스 로그 (이벤트 서비스에서 호출하지 않음)
로그없음
```

이제 회원 데이터를 삭제하는 회원 서비스의 REST API 를 호출해보자.
[DELETE] [http://localhost:8090/member/userInfo/1234](http://localhost:8090/member/userInfo/1234)
 
![레디스 캐싱 데이터 삭제 메서드 호출](/assets/img/dev/20201001/redis2.jpg)

```shell
-- 회원 서비스 로그 (Kafka 에 DELETE 상태 변화 메시지를 발행)
DEBUG 11448 MemberController    : ====== 회원 삭제 후 DELETE 메시지 발생
DEBUG 11448 SimpleSourceBean    : ======= Sending kafka message DELETE for User Id : 1234
DEBUG 11448 SimpleSourceBean    : ======= MemberChangeModel.class.getTypeName() : com.assu.cloud.memberservice.event.model.MemberChangeModel

-- 이벤트 서비스 로그 (회원 서비스가 발행한 DELETE 메시지 수신, 메시지 수신 후 캐시 무효화)
INFO 24632 MemberChangeHandler   : ======= Received a message of type com.assu.cloud.memberservice.event.model.MemberChangeModel
DEBUG 24632 MemberChangeHandler   : Received a DELETE event from the member service for userId 1234
```

이제 제대로 캐시 무효화가 되었는지 다시 처음에 호출한 이벤트 서비스의 [http://localhost:8070/event/1234](http://localhost:8070/event/1234)
를 호출해보자.

```shell
-- 이벤트 서비스 로그 (캐싱된 데이터가 없다, 회원 서비스 호출하여 데이터 조회 후 레디스 해시에 캐싱)
DEBUG 24632 MemberCacheRestTemplateClient  : ======= Unable to locate member from the redis cache: 1234

-- 회원 서비스 로그
DEBUG 11448 MemberController      : ====== 회원 저장 서비스 호출!
```

바로 위에서 해당 캐시를 무효화했기 때문에 회원 서비스를 조회하는 것을 확인할 수 있다.

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [Jedis](https://github.com/xetorthio/jedis)
* [Windows 에 Redis 설치](https://goni9071.tistory.com/473)
* [Redis Download](https://github.com/microsoftarchive/redis/releases/tag/win-3.2.100)
* [Redis key 값에 unicode 제거](https://medium.com/@yongkyu.jang/springboot-%EA%B0%9C%EB%B0%9C%ED%99%98%EA%B2%BD%EA%B5%AC%EC%84%B1-2%EB%B2%88%EC%A7%B8-%EA%B8%80%EC%97%90-%EC%9D%B4%EC%96%B4-%EC%9D%B4%EB%B2%88%EC%97%90%EB%8A%94-%EC%9B%90%EB%9E%98-rest-%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%B4%EC%84%9C-springboot%EA%B8%B0%EB%B0%98-api-%EC%96%B4%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%EC%9D%84-%EA%B0%9C%EB%B0%9C%ED%95%98%EA%B8%B0-%EC%9C%84%ED%95%9C-%ED%99%98%EA%B2%BD%EC%9D%84-%EA%B5%AC%EC%84%B1%ED%95%98%EB%8A%94-%EA%B1%B8%EB%A1%9C-de5997645b17)
