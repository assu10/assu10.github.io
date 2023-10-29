---
layout: post
title:  "Spring Boot - Redis 와 스프링 캐시(3): 분산락, CyclicBarrier"
date:   2023-10-01
categories: dev
tags: springboot msa redis cyclic-barrier
---

이 포스팅에서는 분산락을 어떻게 생성하는지, 데이터베이스의 트랜잭션과 레디스 락을 사용하여 분산락을 처리하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap10) 에 있습니다.

---

**목차**

- 레디스 분산락

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

# 1. 레디스 분산락

MSA 환경에서는 컴포넌트들의 고가용성을 확보하기 위해 Scale-out 을 주로 사용하는데 이 때 여러 인스턴스가 동시에 공유 자원을 사용하는 일이 발생할 수 있다.  
동시성 문제를 해결하지 않고 공유 자원을 작업하면 공유 자원의 무결성이 깨질 수 있다.  
따라서 **MSA 환경에서는 분산락을 사용하여 공유 자원의 원자성을 보장하도록 설계**한다.

**분산락의 기본 개념은 원자성을 제공하는 저장소를 사용하여 동시성 문제를 해결**하는 것이다.  

공유 자원에 작업하기 전에 저장소에 락을 생성하고 작업을 마친 후 생성한 락을 제거한다.  
락 생성 시에 다른 인스턴스가 생성한 락이 있다면 공유 자원에 작업하지 않는다.  
결국 공유 자원은 한 번에 한 인스턴스만 점유하여 처리가 가능하므로 데이터가 무결성을 가질 수 있다.  

이 때 **싱글 스레드 방식의 빠른 처리 속도를 제공하는 레디스가 락 저장소로 매우 적합**하다.

> 레디스 분산락을 사용하지 않을 경우 사용자가 동시에 요청했을 때 중복 당첨자가 발생할 수 있다.  
> 데이터베이스를 최고 상태 격리 수준인 SERIALIZABLE 이 아니면 동시성 문제가 발생하고, SERIALIZABLE 로 설정하기엔 데이터베이스의 부하에 문제가 생길 수 있다.  
> 이 때 레디스를 사용하여 분산락을 구현하는 것이 대안이 될 수 있다.

---

레디스 라이브러리 중 Redisson 은 분산락을 처리할 수 있는 메서드를 제공하지만, Lettuce 는 분산락을 만들 수 있는 별도의 기능을 제공하지 않는다.  
Lettuce 를 이용하여 분산락을 생성해보도록 하자.

아래와 같은 상황을 가정하자.  
- 특정 이벤트 진행 시 선착순 5명을 뽑음
- 각 호텔에서 여러 명이 지원하는 형태이고, 각 호텔에서 1명씩만 선착순으로 당첨 선정
- hotel_event 테이블에서 이벤트 데이터 관리 (event_hotel_id, winner_user_id)
- event_hotel_id: 이벤트에 참석하는 호텔 아이디
- winner_user_id: 이벤트에 가장 먼저 클릭한 사용자 아이디
- 서비스 오픈 전 이벤트에 참여하는 호텔 개수만큼 미리 5개의 레코드 생성, 단 초기 상태이므로 winner_user_id 는 null

비즈니스 로직 순서는 아래와 같다.
- hotel_event 테이블에 해당 호텔 아이디와 매칭되는 레코드 select
- 레코드의 winner_user_id 가 null 이면 사용자의 user_id update 후 성공 응답
- 레코드의 winner_user_id 가 null 이 아니면 실패 응답

위 상황에서 공유 자원은 hotel_event 이다.  
이 공유 자원을 보호하고자 레디스의 key-value 를 사용한 분산락을 만들어본다.  

레디스 key 에는 각 공유 자원을 구분할 수 있는 값을 설정하고, value 에는 락을 소유한 소유자 정보를 저장한다.  
대입하면 hotel_event 의 event_hotel_id 가 key 가 되고, user_id 가 value 가 된다.

아래는 레디스의 키를 디자인한 클래스이다.

/adapter/lock/LockKey.java
```java
package com.assu.study.chap10.adapter.lock;

import java.util.Objects;

/**
 * 분산락을 사용하기 위한 레디스 키 디자인 클래스
 */
public class LockKey {
  private static final String PREFIX = "LOCK::";
  private final Long eventHotelId;

  public LockKey(Long eventHotelId) {
    if (Objects.isNull(eventHotelId)) {
      throw new IllegalArgumentException("eventHotelId can't be null.");
    }
    this.eventHotelId = eventHotelId;
  }

  public static LockKey from(Long eventHotelId) {
    return new LockKey(eventHotelId);
  }

  // 레디스에 저장된 키를 LockKey 객체로 역직렬화할 때 사용
  public static LockKey fromString(String key) {
    String idToken = key.substring(0, PREFIX.length());
    Long eventHotelId = Long.valueOf(idToken);

    return LockKey.from(eventHotelId);
  }

  // LockKey 객체를 레디스의 키로 저장할 때 직렬화 과정에서 사용할 메서드
  // LOCK::eventHotelId 문자열 포맷으로 직렬화되어 저장됨
  @Override
  public String toString() {
    return PREFIX + eventHotelId;
  }
}
```

아래는 레디스에 분산락을 생성/조회할 수 있는 클래스이다.  
LockAdapter 클래스가 의존하는 RedisTemplate 의 제네릭 타입은 LockKey 와 Long 이다.  
즉, 레디스 key 는 LockKey 이고, value 는 Long 타입이다.  
key-value 데이터를 사용할 예정이므로 RedisTemplate 의 opsForValue() 를 사용하여 ValueOperation 객체를 클래스 변수 lockOperation에 할당한다.

/adapter/lock/LockAdapter.java
```java
package com.assu.study.chap10.adapter.lock;

import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Slf4j
@Component
public class LockAdapter {
  private final RedisTemplate<LockKey, Long> lockRedisTemplate;
  private final ValueOperations<LockKey, Long> lockOperation;

  public LockAdapter(RedisTemplate<LockKey, Long> lockRedisTemplate) {
    this.lockRedisTemplate = lockRedisTemplate;
    this.lockOperation = lockRedisTemplate.opsForValue();
  }

  // 레디스에 락 생성
  // hotelId 를 사용하여 LockKey 객체를 생성하고, 레디스 key 에 저장
  // 이 때 value 는 userId
  public Boolean holdLock(Long hotelId, Long userId) {
    LockKey lockKey = LockKey.from(hotelId);
    // setIfAbsent() 는 레디스 key 와 매핑되는 값이 없을때만 레디스 데이터 생성
    // 데이터가 없으면 Boolean.TRUE 리턴
    // 즉, Boolean.FALSE 를 리턴하면 레디스에 이미 데이터가 있음을 의미하므로 분산락이 있다는 의미이기 때문에
    // 공유 자원에 작업하지 않음
    // 레디스의 유효 기간은 10초로 설정
    return lockOperation.setIfAbsent(lockKey, userId, Duration.ofSeconds(10));
  }

  // 레디스에 락이 있는지 확인
  public Long checkLock(Long hotelId) {
    LockKey lockKey = LockKey.from(hotelId);
    return lockOperation.get(lockKey);
  }

  // 레디스에서 락을 삭제
  public void clearLock(Long hotelId) {
    lockRedisTemplate.delete(LockKey.from(hotelId));
  }
}
```

> `ValueOperation<K,V>` 에 대한 상세한 내용은 [1.1. `ValueOperation<K,V>` 인터페이스](https://assu10.github.io/dev/2023/09/30/springboot-redis-2/#11-valueoperationkv-%EC%9D%B8%ED%84%B0%ED%8E%98%EC%9D%B4%EC%8A%A4) 를 참고하세요.

> `RedisTemplate` 에 대한 좀 더 상세한 내용은 [Spring Boot - Redis 와 스프링 캐시(2): RedisTemplate 설정](https://assu10.github.io/dev/2023/09/30/springboot-redis-2/) 를 참고하세요.

---

이제 LockAdapter 와 `@Transactional` 함께 사용하여 아래와 같이 분산락을 이용할 수 있다.

(샘플 코드라 코드 안에서 사용되는 entity, repository 는 실제 git 에는 없음)

/adapter/LockEventService.java
```java
package com.assu.study.chap10.adapter.lock;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
@Slf4j
@Service
public class LockEventService {
  private LockAdapter lockAdapter;

  @Transactional(timeout = 10)  // 트랜잭션의 타임아웃을 10초로 설정
  public Boolean attendEvent(Long hotelId, Long userId) {

    // 레디스에 분산락이 없는지 확인
    // holdLock() 이 false 를 리턴하면 다른 인스턴스나 스레드로 락이 생성되었음을 의미
    // 따라서 attendEvent() 도 false 를 리턴
    if (!lockAdapter.holdLock(hotelId, userId)) {
      return false;
    }

    EventHotelEntity eventHotelEntity = eventHotelRepository.findByHotelId(hotelId);

    // DB 에서 hotelId 와 일치하는 엔티티 객체 조회
    // nonEmptyUser() 는 엔티티 객체에 winnerUserId 의 null 여부 확인
    // null 이 아니면 다른 사용자가 이미 선착순 이벤트에 성공한 것이므로 false 리턴
    // 따라서 attendEvent() 도 false 를 리턴
    if (eventHotelEntity.nonEmptyUser()) {
      return false;
    }

    // 엔티티에 winnerUserId 를 설정하는 winner() 실행 후 DB 에 저장
    eventHotelEntity.winner(userId);
    eventHotelRepository.save(eventHotelEntity);

    return true;
  }
}
```

> 위에서 `@Transactional(timeout = 10)` 를 통해 트랜잭션의 타임아웃을 10초로 설정하였는데 timeout 이 10초라는 의미이지, 10초 동안 DB 에 락이 걸린다는 의미가 아님을 주의하자.


![분산 시스템에서 동시에 공유 자원을 점유할 때 레디스를 이용한 분산락](/assets/img/dev/2023/1001/lock.png)

> `SET "LOCK::1" "100" EX 10 NX` 는 LOCK::1 key 에 100 value 를 저장하고, 유효 시간은 10초이며,  
> key 가 존재하지 않을 때만 insert 한다는 의미임.  
> 
> 명령어에 대한 좀 더 상세한 내용은 [3.1.1 `SET` - `NX`,`XX`](https://assu10.github.io/dev/2022/06/01/redis-basic/#311-set---nxxx) 를 참고하세요.

LockEventService 의 attendEvent() 를 여러 인스턴스에서 동시에 사용한다고 할 때 attendEvent() 의 구현이 정확한지 확인해보자.  
위 그림에서 `SET "LOCK::1" "100" EX 10 NX` 는 `lockOperation.setIfAbsent(lockKey, userId, Duration.ofSeconds(10));` 을 레디스 명령어로 변환한 것이다.

> `lockOperation.setIfAbsent(lockKey, userId, Duration.ofSeconds(10));`    
> `SET "LOCK::1" "100" EX 10 NX`

명령어 하나로 데이터를 저장함과 동시에 유효 기간을 설정한다.

`SET "LOCK::1" "100" EX 10 NX` 를 하나씩 보자.  

eventHotelId 가 1 이므로 생성된 레디스 key 값은 "LOCK::1" 이고, User #1 의 userId 는 "100" 이므로 레디스 value 값은 "100" 이다.  
User #2 도 같은 공유 자원을 사용하므로 레디스 key 값은 "LOCK::1" 이고, User #2 의 userId 는 "101" 이므로 레디스 value 값은 "101" 이다.  

`EX 10` 은 레디스에 데이터를 저장할 때 유효 기간을 10초로 설정하는 기능이다.  
`NX` 옵션은 key 와 매핑되는 데이터가 없을 때 `SET` 명령어를 실행하고, key 와 매핑되는 데이터가 있으면 `SET` 명령어를 실행하지 않고 실패를 응답한다.

`SET` 명령어를 실행하면 레디스는 `OK` or `NIL` 을 응답한다.  
`ValueOperation` 의 `setIfAbsent()` 는 레디스가 `OK` 를 응답하면 true 를, `NIL` 을 응답하면 false 를 리턴한다.

따라서 명령어 결과로 락의 존재 유무를 확인하는 동시에 락을 생성할 수 있다.

---

**분산락을 확인하고자 `GET` 명령어를 실행하여 락의 유무를 확인한 후 `SET` 명령어를 실행하면 안된다.**  

아래 예시를 보자.

![분산락을 확인하고 생성하는데 실패하는 경우](/assets/img/dev/2023/1001/lock2.png)

User #1 이 GET, SET 하는 사이에 User #2 가 GET 을 실행하면 User #1, User #2 모두 분산락이 없다고 판단하는 상황이 발생한다.

**_레디스에도 트랜잭션 기능을 제공하는 명령어 `MULTI` 가 있기는 하지만 레디스 전체 성능에 영향을 줄 수 있으므로 `NX` 옵션을 사용한 `SET` 명령어를 사용하여 
한 번에 락을 확인하고 생성하는 것이 좋다._**

---

위의 LockAdapter 에서 사용한 분산락은 DB 의 트랜잭션 격리 수준을 보조하는 락의 개념이다.  
SERIALIZABLE 격리 수준을 사용하지 않는 한 DB 만으로는 데이터 무결성을 보장할 수 없으므로, DB 의 트랜잭션 시간 동안만 분산락으로 보호하면 된다.  

`@Transactional(timeout=10)` 을 사용하여 트랜잭션 타임아웃 시간을 10초로 설정했으므로, 최대 10초 동안 발생할 수 있는 트랜잭션 시간 동안 분산락이 동작하면 된다.  
따라서 레디스에 설정된 분산락의 유효 기간도 10초로 설정한다.  

최악의 경우 DB 의 트랜잭션이 DeadLock 이 발생하여 10초 동안 락이 걸린다면 해당 트랜잭션은 10초 후에 롤백되므로, 롤백된 DB 의 winnerUserId 필드는 null 이다.  
하지만 트랜잭션 롤백과 관련없는 레디스 분산락에는 가장 먼저 락을 점유한 사용자의 userId 가 저장되어 있을 것이다.  

이런 상태도 괜찮은 것이 어차피 DB 의 winnerUserId 에는 우승자의 userId 가 없으므로 가장 먼저 재시도한 사람의 userId 가 기록될 것이다.  

하지만 분산락의 유효 기간은 10초 이므로 그 사이에 시도한 사람들은 여전히 실패하고, 10초 후 가장 먼저 재시도한 사람이 DB 에 기록된다.

---

아래는 LockAdapter 클래스 테스트 케이스이다.  

Docker 레디스 실행 후 테스트 케이스를 실행해보면서 확인해보자.

> Docker 레디스 설정 및 실행은 [2.2. 레디스 도커 설정](https://assu10.github.io/dev/2023/09/24/springboot-redis-1/#22-%EB%A0%88%EB%94%94%EC%8A%A4-%EB%8F%84%EC%BB%A4-%EC%84%A4%EC%A0%95) 를 참고하세요.

최대한 동시에 LockAdapter 의 holdLock() 을 실행하고자 `CyclicBarrier` 사용하였다.

test > lock/LockAdapterTest.java
```java
package com.assu.study.chap10.adapter.lock;

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.TimeUnit;

@Slf4j
@SpringBootTest
class LockAdapterTest {

  private final Long firstUserId = 1L;
  private final Long secondUserId = 2L;
  private final Long thirdUserId = 3L;

  @Autowired
  private LockAdapter lockAdapter;

  @Test
  @DisplayName("firstUserId 가 락 선점")
  public void testLock() {
    final Long hotelId = 1111L;

    boolean isSuccess = lockAdapter.holdLock(hotelId, firstUserId);
    Assertions.assertTrue(isSuccess);

    isSuccess = lockAdapter.holdLock(hotelId, secondUserId);
    Assertions.assertFalse(isSuccess);

    Long holderId = lockAdapter.checkLock(hotelId);
    Assertions.assertEquals(firstUserId, holderId);
  }

  @Test
  @DisplayName("동시에 3이 락을 선점하지만 1명만 락을 잡음")
  public void testConcurrentAccess() throws InterruptedException {
    final Long hotelId = 9999L;

    // CyclicBarrier 의 인자를 3으로 설정
    // 각 스레드는 CyclicBarrier 공유 객체의 await() 메서드를 호출하고, 3번 호출되면 CyclicBarrier 는 스레드 실행함 
    CyclicBarrier cyclicBarrier = new CyclicBarrier(3);
    
    // Runnable 을 구현하는 Accessor 를 사용하여 3개의 스레드 실행
    // 공유 자원인 hotelId 와 사용자 아이디를 각각 인자로 입력
    // 그리고 CyclicBarrier 기능을 공유하려고 인자로 넘김
    new Thread(new Accessor(hotelId, firstUserId, cyclicBarrier)).start();
    new Thread(new Accessor(hotelId, secondUserId, cyclicBarrier)).start();
    new Thread(new Accessor(hotelId, thirdUserId, cyclicBarrier)).start();

    TimeUnit.SECONDS.sleep(1);
    Long holderId = lockAdapter.checkLock(hotelId);

    log.info("holderId: {}", holderId);

    // 스레드를 실행하고 1초 후 락의 유무 확인
    // 단, firstUserId, secondUserId, thirdUserId 중 하나가 레디스 value 에 저장되어 있음을 검증함
    Assertions.assertTrue(List.of(firstUserId, secondUserId, thirdUserId).contains(holderId));
    lockAdapter.clearLock(hotelId);
  }

  // 최대한 동시에 LockAdapter 의 holdLock() 을 실행하고자 CyclicBarrier 사용
  class Accessor implements Runnable {
    private final Long hotelId;
    private final Long userId;
    private final CyclicBarrier cyclicBarrier;

    public Accessor(Long hotelId, Long userId, CyclicBarrier cyclicBarrier) {
      this.hotelId = hotelId;
      this.userId = userId;
      this.cyclicBarrier = cyclicBarrier;
    }

    // 인자로 받은 cyclicBarrier 객체를 사용하여 await() 메서드를 실행하고,
    // lockAdapter.holdLock() 메서드 실행
    // await() 가 3번 호출될 때까지는 모든 스레드는 대기하고,
    // 3번 호출된 시점에 모든 스레드가 한 번에 lockAdapter.holdLock() 를 호출함
    @Override
    public void run() {
      try {
        cyclicBarrier.await();
        lockAdapter.holdLock(hotelId, userId);
      } catch (Exception e) {
        throw new RuntimeException(e);
      }

    }
  }
}
```

/config/LockConfig.java
```java
package com.assu.study.chap10.config;

import com.assu.study.chap10.adapter.lock.LockKey;
import com.assu.study.chap10.adapter.lock.LockKeySerializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericToStringSerializer;

@Configuration
public class LockConfig {

  @Bean
  public RedisConnectionFactory lockRedisConnectionFactory() {
    RedisStandaloneConfiguration configuration = new RedisStandaloneConfiguration("127.0.0.1", 6379);

    // 레디스의 데이터베이스 번호 설정
    // 레디스 서버는 내부에서 16개의 데이터베이스를 구분해서 운영 가능하며, 0~15번까지의 데이터베이스를 가짐
    // 개발 환경에서 장비를 효츌적으로 사용하기 위해 데이터베이스를 구분하여 각 컴포넌트에 할당해서 운영 가능
//    configuration.setDatabase(0);
//    configuration.setUsername("username");
//    configuration.setPassword("password");

    return new LettuceConnectionFactory(configuration);
  }

  // redisTemplate 가 2개 (hotelCacheRedisTemplate, lockRedisTemplate) 인 경우 하나는
  // 디폴트 이름인 redisTemplate 로 해주어야 하나 봄 (lockRedisTemplate 가 아닌)
  @Bean(name = "redisTemplate")
  public RedisTemplate<LockKey, Long> lockRedisTemplate() {
    RedisTemplate<LockKey, Long> lockRedisTemplate = new RedisTemplate<>();

    // 위에서 생성한 RedisConnectionFactory 스프링 빈을 사용하여 RedisTemplate 객체 생성
    lockRedisTemplate.setConnectionFactory(lockRedisConnectionFactory());
    // key 와 value 값을 직렬화/역직렬화하는 RedisSerializer 구현체 설정
    lockRedisTemplate.setKeySerializer(new LockKeySerializer());
    lockRedisTemplate.setValueSerializer(new GenericToStringSerializer<>(Long.class));

    return lockRedisTemplate;
  }
}
```

/adapter/lock/LockKeySerializer.java
```java
package com.assu.study.chap10.adapter.lock;

import org.springframework.data.redis.serializer.RedisSerializer;
import org.springframework.data.redis.serializer.SerializationException;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

public class LockKeySerializer implements RedisSerializer<LockKey> {
  private final Charset UTF_8 = StandardCharsets.UTF_8;

  @Override
  public byte[] serialize(LockKey lockKey) throws SerializationException {
    // 레디스 데이터 중 key 는 null 이 될 수 없음
    if (Objects.isNull(lockKey)) {
      throw new SerializationException("lockKey is null.");
    }
    // HotelCacheKey 가 직렬화되면 byte[] 를 리턴해야 함
    // 이 때 Charset 를 설정하여 byte[] 로 변환하는 것이 좋음
    return lockKey.toString().getBytes(UTF_8);
  }

  @Override
  public LockKey deserialize(byte[] bytes) throws SerializationException {
    if (Objects.isNull(bytes)) {
      throw new SerializationException("bytes is null.");
    }
    // 레디스의 key 데이터는 byte[] 이므로 적절히 변환하여 HotelCacheKey 객체를 생성하여 리턴
    return LockKey.fromString(new String(bytes, UTF_8));
  }
}
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스팅은 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [Redis 데이터 타입: 공홈](https://redis.io/docs/data-types/)
* [Redis Commands 공홈](https://redis.io/commands/)
* [Lettuce reference](https://lettuce.io/core/release/reference/index.html#connection-pooling.is-connection-pooling-necessary)
