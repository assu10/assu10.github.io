---
layout: post
title:  "Spring Boot - Redis 와 스프링 캐시(5): Sorting"
date:   2023-10-08
categories: dev
tags: springboot msa redis zset redis-sorting z-set-operations
---

이 포스트에서는 레디스의 자료 구조 중 Sorted Set(`ZSet`) 을 이용한 정렬에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap10) 에 있습니다.

---

**목차**

- [레디스 Sorting 구현](#1-레디스-sorting-구현)
- [레디스 Pub-Sub 구현](#2-레디스-pub-sub-구현)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.5
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap10

![Spring Initializer](/assets/img/dev/2023/0924/init.png)

pom.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>com.assu</groupId>
    <artifactId>study</artifactId>
    <version>1.1.0</version>
  </parent>

  <artifactId>chap10</artifactId>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-redis</artifactId>
      <version>3.1.5</version>
    </dependency>
  </dependencies>
</project>
```

---

# 1. 레디스 Sorting 구현

레디스의 자료 구조 중 Sorted Set(`ZSet`) 은 중복된 값을 허용하지 않는다.  

Sorted Set 에는 key, value, 그리고 value 와 연관된 score 를 저장할 수 있으며, 저장된 score 를 기준으로 데이터를 정렬할 수 있다.  

offset 과 count 를 사용하여 특정 순위에 있는 데이터를 부분 조회하거나, 순위별로 특정 값을 조회/비교하는 기능을 제공한다.  

이러한 특성을 이용하여 경매, 실시간 인기 검색어, 사용자 랭킹같은 기능을 쉽게 구현할 수 있다.

> Sorted Set 에 대한 좀 더 상세한 내용은 [Redis - Sorted Set](https://assu10.github.io/dev/2022/07/30/redis-zset/) 를 참고하세요. 

아래와 같은 상황을 가정해보자.

- 호텔에서 객실을 경매하는 이벤트 진행
- 경매에 붙일 객실을 특정 일자에 업로드하고, 사용자들이 특정 기간동안 입찰
- 호텔마다 3개의 객실을 경매에 붙이며, 사용자는 호텔 단위로 입찰
- 가장 높은 금액 순으로 상위 3명의 입찰자 선정
- 사용자는 실시간으로 현재 입찰 상황 조회 가능하며, 상위 3명의 입찰 금액도 조회 가능 (실시간 순위 조회)

이러한 경우 아래처럼 Sorted Set 자료 구조를 설계할 수 있다.
- key
  - 예) HOTEL-BUILDING::{eventHotelId}
- value
  - score 와 매핑되는 값 (특정 호텔 경매에 참석한 회원의 아이디)
  - 예) 1111
- score
  - 정렬에 사용할 값
  - 예) 10,000 (특정 회원이 입찰한 금액)

`RedisTemplate` 에서 Sorted Set 자료 구조 사용 시 `ZSetOperations` 객체를 사용하며, `RedisTemplate` 의 `opsForZSet()` 이 해당 객체를 리턴한다.

```java
ZSetOperations<String, Long> zSetOperations = redisTemplate.opsForZSet();
```

`ZSetOperations` 은 value, score 를 저장하기 위해 `TypedTuple` 이라는 튜플 클래스를 사용한다. 이 클래스는 value 의 클래스 타입을 지정할 수 있는 제네릭 타입을 설정할 수 있고, 
score 의 클래스 타입은 double 이다.

아래는 `ZSetOperations` 에서 제공하는 몇 가지 메서드들이다.

- `Boolean add(K key, V value, double score)`
  - key 와 매핑되는 Sorted Set 에 value 와 score 를 함께 저장
- `Boolean addIfAbsent(K key, V value, double score)`
  - key 와 매핑되는 Sorted Set 에 저장된 value 가 없을 경우 value 와 score 저장
- `Long remove(K key, Object... values)`
  - key 와 매핑되는 Sorted Set 에 values 인자와 매핑되는 데이터들 삭제
- `Double incrementScore(K key, V value, double delta)`
  - key 와 매핑되는 Sorted Set 에 value 와 연관된 score 를 delta 만큼 증가
- `Long rank(K key, Object o)`
  - key 와 매핑되는 Sorted Set 에서 value 의 순위, 즉 인덱스 값을 리턴
- `Long reverseRank(K key, Object o)`
  - key 와 매핑되는 Sorted Set 에서 value 의 순위, 즉 인덱스 값을 리턴
  - 단, 이 때 인덱스 값은 역순임 
- `Double score(K key, Object o)`
  - key 와 매핑되는 Sorted Set 에서 value 의 score 조회
- `Set<TypedTuple<V>> rangeByScoreWithScores(K key, double min, double max)`
  - key 와 매핑되는 Sorted Set 에서 score 의 최소값과 최대값 사이에 있는 TypedTuple 객체셋 리턴
  - 예를 들어 score 가 10~20 사이에 있는 사용자 정보 조회
- `Set<V> rangeByScore(K key, double min, double max)`
  - key 와 매핑되는 Sorted Set 에서 score 의 최소값과 최대값 사이에 있는 value set 리턴
- `Set<V> rangeByScore(K key, double min, double max, long offset, long count)`
  - key 와 매핑되는 Sorted Set 에서 score 의 최소값과 최대값 사이에 있는 value set 중 특정 위치 (offset) 에서 특정 개수(count) 만큼 value set 리턴
- `Set<V> reverseRangeByScore(K key, double min, double max, long offset, long count)`
  - key 와 매핑되는 Sorted Set 에서 score 의 최소값과 최대값 사이에 있는 value set 중 특정 위치 (offset) 에서 특정 개수(count) 만큼 value set 리턴
  - 단, 이 때 score 의 역순으로 정렬한 값을 리턴

---

이제 3 개의 클래스를 작성한다.
- BiddingConfig 자바 설정 클래스
  - RedisTemplate\<String, Long\> biddingRedisTemplate 를 정의
  - key 는 String, value 는 Long (입찰에 참여한 사용자 아이디를 저장하기 때문에 Long)
- BiddingAdapter 클래스
  - biddingRedisTemplate 스프링 빈을 주입받아 입찰에 필요한 메서드 구현
- BiddingAdapterTest 클래스

/config/BiddingConfig.java
```java
package com.assu.study.chap10.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericToStringSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

@Slf4j
@Configuration
public class BiddingConfig {
  @Bean
  public RedisConnectionFactory biddingRedisConnectionFactory() {
    RedisStandaloneConfiguration configuration = new RedisStandaloneConfiguration("127.0.0.1", 6379);
    return new LettuceConnectionFactory(configuration);
  }

  @Bean(name = "biddingRedisTemplate")
  public RedisTemplate<String, Long> biddingRedisTemplate() {
    // RedisTemplate 는 제네릭 타입 K,V 설정 가능
    // 첫 번째는 레디스 key 에 해당하고, 두 번째는 레디스 value 에 해당함
    // 경매에 참여한 유저 아이디를 저장하기 때문에 value 를 Long 타입으로 설정
    RedisTemplate<String, Long> biddingRedisTemplate = new RedisTemplate<>();
    biddingRedisTemplate.setConnectionFactory(biddingRedisConnectionFactory());

    // key 와 value 값을 직렬화/역직렬화하는 RedisSerializer 구현체 설정
    biddingRedisTemplate.setKeySerializer(new StringRedisSerializer());
    biddingRedisTemplate.setValueSerializer(new GenericToStringSerializer<>(Long.class));

    return biddingRedisTemplate;
  }
}
```

아래는 biddingRedisTemplate 스프링 빈을 주입받아 입찰에 필요한 메서드들을 구현한 BiddingAdapter 클래스이다.

/adapter/bidding/BiddingAdapter.java
```java
package com.assu.study.chap10.adapter.bidding;

import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.stream.Collectors;

@Component
@Slf4j
public class BiddingAdapter {
  private final String PREFIX = "HOTEL-BIDDING::";
  private final RedisTemplate<String, Long> biddingRequestTemplate;

  public BiddingAdapter(RedisTemplate<String, Long> biddingRequestTemplate) {
    this.biddingRequestTemplate = biddingRequestTemplate;
  }

  // 이벤트에 참가하는 호텔 아이디를 사용하여 Sorted Set 의 key 를 생성
  // 별도의 RedisSerializer 구현체를 생성하지 않고 이렇게 해도 됨
  private String serializeKey(Long hotelId) {
    return PREFIX + hotelId;
  }

  // 입찰에 참여할 호텔 아이디, 사용자 아이디, 비딩 금액을 받음
  public Boolean createBidding(Long hotelId, Long userId, Double amount) {
    String key = this.serializeKey(hotelId);

    // ZSetOperations 의 add() 메서드를 사용하여 호텔 아이디를 포함한 key, userId 에 value 와 비딩 금액을 score 로 저장
    return biddingRequestTemplate.opsForZSet().add(key, userId, amount);
  }

  // 입찰에 참여한 사용자들의 비딩 금액을 역순으로 정렬한 후 fetchCount 만큼 참가자의 아이디를 리스트 객체로 리턴
  public List<Long> getTopBidders(Long hotelId, Integer fetchCount) {
    String key = this.serializeKey(hotelId);

    // 비딩 금액이 높은 순으로 정렬해야 하기 때문에 score 를 역순으로 조회하는 reverseRangeByScore() 사용
    // 이 때 score 범위를 인자로 설정할 수 있는데 두 번째 인자인 최소값 0D 부터 최대값 Double.MAX_VALUE 까지 설정
    // 네 번째 인자는 순서 인덱스로 0 부터 fetchCount 개수만큼 조회함
    return biddingRequestTemplate
            .opsForZSet()
            .reverseRangeByScore(key, 0D, Double.MAX_VALUE, 0, fetchCount)
            .stream()
            .collect(Collectors.toList());
  }

  // 참여자가 입찰한 금액 조회
  public Double getBigAmount(Long hotelId, Long userId) {
    String key = this.serializeKey(hotelId);

    // score() 로 score 값 조회
    // 따라서 score 에 저장한 입찰 금액 리턴
    return biddingRequestTemplate.opsForZSet().score(key, userId);
  }

  public void clear(Long hotelId) {
    String key = this.serializeKey(hotelId);
    biddingRequestTemplate.delete(key);
  }
}
```

이제 BiddingAdapter 기능을 테스트해본다.

> Redis Docker 띄우는 법은 [2.2. 레디스 도커 설정](https://assu10.github.io/dev/2023/09/24/springboot-redis-1/#22-%EB%A0%88%EB%94%94%EC%8A%A4-%EB%8F%84%EC%BB%A4-%EC%84%A4%EC%A0%95) 를 참고하세요.

test > adapter/bidding/BiddingAdapterTest.java
```java
package com.assu.study.chap10.adapter.bidding;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;

@SpringBootTest
class BiddingAdapterTest {
    private final Long firstUserId = 1L;
    private final Long secondUserId = 2L;
    private final Long thirdUserId = 3L;
    private final Long fourthUserId = 4L;
    private final Long fifthUserId = 5L;
    private final Long hotelId = 1000L;

    @Autowired
    private BiddingAdapter biddingAdapter;

    @Test
    public void simulate() {
        biddingAdapter.clear(hotelId);

        biddingAdapter.createBidding(hotelId, firstUserId, 100d);
        biddingAdapter.createBidding(hotelId, secondUserId, 110d);
        biddingAdapter.createBidding(hotelId, thirdUserId, 120d);
        biddingAdapter.createBidding(hotelId, fourthUserId, 130d);
        biddingAdapter.createBidding(hotelId, fifthUserId, 150d);

        biddingAdapter.createBidding(hotelId, secondUserId, 160d);
        biddingAdapter.createBidding(hotelId, firstUserId, 200d);

        List<Long> topBidders = biddingAdapter.getTopBidders(hotelId, 3);

        Assertions.assertEquals(firstUserId, topBidders.get(0));
        Assertions.assertEquals(secondUserId, topBidders.get(1));
        Assertions.assertEquals(fifthUserId, topBidders.get(2));

        Assertions.assertEquals(200d, biddingAdapter.getBigAmount(hotelId, firstUserId));
        Assertions.assertEquals(160d, biddingAdapter.getBigAmount(hotelId, secondUserId));
        Assertions.assertEquals(150d, biddingAdapter.getBigAmount(hotelId, fifthUserId));
    }
}
```

---

# 2. 레디스 Pub-Sub 구현

레디스의 Pub-Sub 은 Kafka 나 RabbitMQ 같은 메시지 큐에 비해 비교적 간단하고 빠른 기능을 제공한다.  
단, 구독자가 메시지 수신에 실패해도 레디스는 실패한 메시지를 재전달할 수 없다.  

> 그래서 더 이상 안 보기로... 

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [Redis 데이터 타입: 공홈](https://redis.io/docs/data-types/)
* [Redis Commands 공홈](https://redis.io/commands/)
* [Lettuce reference](https://lettuce.io/core/release/reference/index.html#connection-pooling.is-connection-pooling-necessary)
* [Redis - Sorted Set](https://assu10.github.io/dev/2022/07/30/redis-zset/)