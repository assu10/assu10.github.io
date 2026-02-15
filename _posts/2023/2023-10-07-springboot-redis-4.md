---
layout: post
title:  "Spring Boot - Redis 와 스프링 캐시(4): 스프링 프레임워크 Cache"
date: 2023-10-07
categories: dev
tags: springboot msa redis db cache cache-manager redis-cache-manager enable-caching cacheable cache-put cache-evict caching
---

이 포스트에서는 레디스를 사용한 Cache 에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap10) 에 있습니다.

---

**목차**

<!-- TOC -->
* [1. `Cache` 와 `CacheManager` 인터페이스](#1-cache-와-cachemanager-인터페이스)
  * [1.1. `CacheManager` 구현체, 캐시 데이터 삭제 알고리즘/유효기간](#11-cachemanager-구현체-캐시-데이터-삭제-알고리즘유효기간)
  * [1.2. `RedisCacheManager` 스프링 빈 설정](#12-rediscachemanager-스프링-빈-설정)
* [2. Cache 애너테이션: `@EnableCaching`](#2-cache-애너테이션-enablecaching)
  * [2.1. `@Cacheable`](#21-cacheable)
    * [2.1.1. `@Cacheable` 애너테이션의 `value`, `key`, `condition`](#211-cacheable-애너테이션의-value-key-condition)
    * [2.1.2. `@Cacheable` 애너테이션의 `keyGenerator`](#212-cacheable-애너테이션의-keygenerator)
  * [2.2. `@CachePut`](#22-cacheput)
  * [2.3. `@CacheEvict`](#23-cacheevict)
  * [2.4. `@Caching`](#24-caching)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

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

스프링 프레임워크는 일부 데이터를 미리 메모리 저장소에 저장하고, 저장된 데이터를 다시 읽어서 사용하는 cache 기능을 제공한다.  

**cache 대상 데이터는 쓰기 비율보다 읽기 비율이 높은 경우 그 효과를 발휘**할 수 있다.

스프링 프레임워크의 cache 기능은 AOP 를 사용하여 구현되어 있으므로 프레임워크에서 제공하는 cache 애너테이션을 사용하면 쉽게 스프링 애플리케이션에 
cache 를 구현할 수 있다.

주로 많이 사용하는 cache 프레임워크는 `EhCache`, `Caffeine`, `JCache` 등이 있지만 이 포스트에서는 레디스를 사용한 캐시에 대해 알아본다.

cache 저장소를 구성하는 방식에 따라 2 가지 아키텍처가 있다.

- **로컬 캐시 아키텍쳐**
  - 자바 애플리케이션에 cache 시스템 구성
  - `EhCache`, `Caffeine`, `JCache`...
  - 애플리케이션은 각각의 캐시 시스템을 가지며, 1:1 방식으로 사용
  - 따라서 로컬 캐시들은 데이터를 서로 공유할 수 없음
  - 같은 이름의 데이터라도 각 서버마다 관리하고 있는 캐시 데이터들은 다를 수 있음
- **원격 캐시 아키텍쳐**
  - 애플리케이션 외부에 독립 메모리 저장소를 별도로 구축하여 모든 인스턴스가 네트워크를 사용하여 데이터를 캐시
  - `EhCache` 서버를 구축하거나, 레디스 서버 사용
  - 애플리케이션이 데이터를 캐시하거나 사용할 때 I/O 가 발생
  - 로컬 캐시 방식보다 I/O 시간만큼 서버 리소스와 시간이 더 소요됨
  - 네트워크를 사용하므로 외부 환경에 의해 캐시 성능이 영향을 받음
  - 하지만 한 곳에 데이터가 저장되므로 모든 서버가 같은 데이터를 사용할 수 있음

캐시한 데이터 성격에 따라 적절한 아키텍처를 선택하면 된다.  
데이터 정합성이 매우 중요하면 원격 캐시 아키텍쳐를 고려하면 된다.  

이 포스트에서는 원격 캐시 저장소를 구성하는 방법에 대해 알아본다.

---

# 1. `Cache` 와 `CacheManager` 인터페이스

스프링 프레임워크에는 캐시 기능을 추상화한 o.s.cache.Cache 인터페이스와 캐시를 관리하는 o.s.cache.CacheManager 인터페이스를 제공한다.

스프링 프레임워크에서 캐시는 key-value 로 구성되는데 자바의 자료 구조 중 Map 과 형태가 비슷하다.

예) key - 10111 / value - {"name":"assu", "address":"seoul"}

아래는 `Cache` 인터페이스에서 제공하는 주요 추상 메서드이다.

Cache 인터페이스
```java
package org.springframework.cache;

public interface Cache {
  // ...
  
  // 캐시 이름 리턴
  String getName();

  // 캐시에서 Object key 와 매핑된 객체 리턴
  // 리턴되는 객체는 두 번째 인자인 Class<T> type 으로 형변환됨
  @Nullable
  <T> T get(Object key, @Nullable Class<T> type);

  // 캐시에 새로운 데이터 입력
  void put(Object key, @Nullable Object value);

  // 캐시에서 Object key 와 매핑되는 데이터 퇴출(evict)
  void evict(Object key);
}
```

아래는 캐시 데이터를 관리하는 기능을 추상화한 `CacheManager` 인터페이스이다.  

> 스프링 프레임워크는 이 인터페이스의 기본 구현체들도 제공함

CacheManager 인터페이스
```java
package org.springframework.cache;

import java.util.Collection;
import org.springframework.lang.Nullable;

public interface CacheManager {
  // 애플리케이션에서 관리하는 여러 개의 캐시 중 name 인자와 매핑되는 Cache 객체 리턴
  @Nullable
  Cache getCache(String name);

  // 애플리케이션에서 사용할 수 있는 캐시 이름들을 리턴
  Collection<String> getCacheNames();
}
```

---

## 1.1. `CacheManager` 구현체, 캐시 데이터 삭제 알고리즘/유효기간

애플리케이션에서 사용할 캐시를 조회하려면 `CacheManager` 구현체가 필요하다.  

캐시 데이터 저장소에 따라 `CacheManager` 구현체를 개발하면 되는데 **스프링 스레임워크는 자주 사용하는 몇 가지 캐시 프레임워크로 개발된 `CacheManager` 구현체를 제공**한다.

- `ConcurrentMapCacheManager`
  - JRE 에서 제공하는 ConcurrentHashMap 을 캐시 저장소로 사용할 수 있는 구현체
- `EhCacheCacheManager`
  - EhCache 캐시 저장소를 사용할 수 있는 구현체
- `CaffeineCacheManager`
- `JCacheCacheManager`
  - JRE-107 표준을 따르는 JCache 캐시 저장소를 사용할 수 있는 구현체
- `RedisCacheManager`
- `CompositeCacheManager`
  - 한 개 이상의 CacheManager 를 사용할 수 있는 CacheManager
  - 한 개 이상의 캐시 저장소가 필요할 때 사용하는 구현체
  - CompositeCacheManager 는 다른 여러 CacheManager 구현체를 포함하는 구조임

캐시 저장소는 메모리를 사용하므로 그 크기가 한정적이다.  
항상 **CacheManager 구현체를 설정하기 전에 구현체가 최대 데이터 개수와 데이터 유효 기간을 설정할 수 있는지 확인**해야 한다.  

`EhCacheCacheManager` 와 `CaffeineCacheManager` 는 최대 데이터 개수와 유효 기간을 설정할 수 있다.  

이 포스트에서 사용할 `RedisCacheManager` 는 유효 기간을 설정할 수 있고, 최대 데이터 갯수는 직접 구현해야 한다.

일반적으로 **캐시마다 최대 데이터 갯수를 설정하는데, 최대 데이터 갯수를 초과하면 캐시 프레임워크는 저장된 데이터 중 초과된 개수만큼 삭제**한다.  
이렇게 캐시에서 데이터를 삭제하는 과정을 Evict(퇴출) 이라고 한다.  

**삭제 대상 데이터는 페이지 교체 알고리즘으로 결정**된다.

- `FIFO`
  - First In First Out
  - 가장 먼저 캐시된 데이터 삭제
- `LFU`
  - Least Frequently Used
  - 참조된 횟수가 가장 적은 데이터 삭제 (= 사용 빈도가 적은 데이터 삭제)
- `LRU`
  - Least Recently Used
  - 참조된 시간이 가장 오래된 데이터 삭제
  - 참조 시간이 오래된 데이터는 사용 빈도가 적으므로 삭제
  - 간단한 구조라 가장 많이 사용하는 알고리즘

**유효 기간을 설정할 수 있는 `CacheManager` 인 경우 유효 기간 설정 시 오래된 데이터를 삭제하는 별도의 데몬이나 스케쥴 프로그램을 구현할 필요가 없다.**    
그래서 **캐시 데이터 저장소의 크기를 일정하게 유지**할 수 있고, **오래된 데이터가 자동 evict 되어 새로운 데이터가 다시 캐시**될 수 있다.  

`CaffeineCacheManager` 나 `RedisCacheManager` 같은 구현체는 유효 기간 기능을 제공한다.  

아래는 `CaffeineCacheManager` 스프링 빈을 설정하는 자바 설정 클래스이다.

CaffeineCacheManager 를 사용한 CacheManager 설정
```java
@Bean
public Caffeine caffeineConfig() {
  return Caffeine.newBuilder()
        .expireAfterWrite(60, TimeUnit.MINUTES)   // 캐시 데이터의 유효 기간 설정
        .maximumSize(1000); // Caffeine 객체가 관리할 수 있는 캐시 데이터의 최대 개수는 1000개
}

@Bean
public CacheManager cacheManager(Caffeine caffeine) {
  CaffeineCacheManager caffeineCacheManager = new CaffeineCacheManager();
  caffeineCacheManager.setCaffeine(caffeine); // Caffeine 스프링 빈을 사용하여 CaffeineCacheManager 스프링 빈 생성
  return caffeineCacheManager;
}
```

---

## 1.2. `RedisCacheManager` 스프링 빈 설정

아래는 `RedisCacheManager` 스프링 빈을 생성하고, `RedisCacheManager` 를 설정한 BasicCacheConfig 자바 설정 클래스이다.  

`RedisCacheManager` 는 유효 기간 기능만 기본으로 제공한다.  
이 기능은 레디스의 `EXPIRE` 명령어를 사용한 것이므로 유효 기간이 지난 데이터는 레디스가 직접 정리한다.  
`RedisCacheManager` 의 최대 개수를 설정해야 한다면 이것은 직접 구현해야 한다.

/config/BasicCacheConfig.java
```java
package com.assu.study.chap10.config;

import com.assu.study.chap10.service.HotelKeyGenerator;
import io.lettuce.core.ClientOptions;
import io.lettuce.core.SocketOptions;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceClientConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

@Configuration
@EnableCaching
public class BasicCacheConfig {

  @Bean
  public RedisConnectionFactory basicCacheRedisConnectionFactory() {
    RedisStandaloneConfiguration configuration = new RedisStandaloneConfiguration("127.0.0.1", 6379);

    // 레디스와 클라이언트 사이에 커넥션을 생성할 때 소요되는 최대 시간 설정
    // 설정한 SocketOptions 객체는 ClientOptions 객체에 다시 랩핑함
    // 랩핑한 ClientOptions 는 LettuceClientConfigurationBuilder 의 clientOptions() 메서드를 사용하여 설정 가능
    final SocketOptions socketOptions = SocketOptions.builder().connectTimeout(Duration.ofSeconds(10)).build();
    final ClientOptions clientOptions = ClientOptions.builder().socketOptions(socketOptions).build();

    LettuceClientConfiguration lettuceClientConfiguration = LettuceClientConfiguration.builder()
        .clientOptions(clientOptions)
        .commandTimeout(Duration.ofSeconds(5))  // 레디스 명령어를 실행하고 응답받는 시간 설정
        .shutdownTimeout(Duration.ZERO) // 레디스 클라이언트가 안전하게 종료하려고 애플리케이션이 종료될 때까지 기다리는 최대 시간
        .build();

    return new LettuceConnectionFactory(configuration, lettuceClientConfiguration);
  }

  // 스프링 빈의 이름은 cacheManager
  // 레디스 서버에 캐시 데이터 저장
  @Bean
  public CacheManager cacheManager() {
    // RedisCacheConfigurations 은 캐시 데이터를 저장하는 RedisCache 를 설정하는 기능 제공
    RedisCacheConfiguration defaultConfig = RedisCacheConfiguration.defaultCacheConfig()  // defaultCacheConfig() 는 기본값으로 설정된 RedisCacheConfiguration 객체 리턴
        .entryTtl(Duration.ofHours(1))  // 캐시의 유효 기간을 1시간으로 설정
        .serializeKeysWith(RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer())) // 캐시 데이터 key 직렬화 시 문자열로 변환하여 저장
        //.serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(new Jackson2JsonRedisSerializer<>(Object.class)));  // 캐시 데이터 value 직렬화할 때 JSON 으로 변환하여 저장
        .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer()));  // 캐시 데이터 value 직렬화할 때 JSON 으로 변환하여 저장

    Map<String, RedisCacheConfiguration> configurations = new HashMap<>();
    // HashMap configuration 객체의 key 는 캐시 이름을 저장하고, value 는 캐시를 설정할 수 있는 RedisConfiguration 저장
    // hotelCache 캐시의 설정은 defaultConfig 설정과 같지만 캐시 데이터의 유효 기간을 30분으로 변경
    // RedisCacheConfiguration 은 불변 객체이므로 entryTtl() 은 새로운 RedisCacheConfiguration 객체를 리턴
    // 즉, 기존 defaultConfig 객체에는 영향이 없음
    configurations.put("hotelCache", defaultConfig.entryTtl(Duration.ofMinutes(30)));
    configurations.put("hotelAddressCache", defaultConfig.entryTtl(Duration.ofDays(1)));

    return RedisCacheManager.RedisCacheManagerBuilder
        .fromConnectionFactory(basicCacheRedisConnectionFactory())  // RedisCacheManager 가 사용할 RedisConnectionFactory 객체 설정
        .cacheDefaults(defaultConfig) // RedisCacheConfiguration 인자를 사용하여 RedisCacheManager 의 기본 캐시 설정
        .withInitialCacheConfigurations(configurations) // RedisCacheManager 생성 시 초기값 설정, 따라서 RedisCacheManager 스프링 빈이 생성되면 hotelCache 와 hotelAddressCache 캐시 값이 설정됨
        .build();
  }

  // 이 내용은 뒤에 나옴
  @Bean
  public HotelKeyGenerator hotelKeyGenerator() {
    return new HotelKeyGenerator();
  }
}
```

HotelKeyGenerator 내용은 [2.1.2. `@Cacheable` 애너테이션의 `keyGenerator`](#212-cacheable-애너테이션의-keygenerator) 을 참고하세요.

/service/HotelRequest.java
```java
package com.assu.study.chap10.service;

import lombok.Getter;
import lombok.ToString;
import org.springframework.cache.annotation.Cacheable;

@Getter
@ToString
@Cacheable
public class HotelRequest {
  private final Long hotelId;

  public HotelRequest(Long hotelId) {
    this.hotelId = hotelId;
  }
}
```

---

# 2. Cache 애너테이션: `@EnableCaching`

스프링 프레임워크에서 제공하는 캐시 애너테이션들은 기능에 따라 두 종류로 나눌 수 있다.
- **애플리케이션에 캐시 기능을 켜는 애너테이션**
  - `@EnableCaching`
    - 위의 BasicCacheConfig 클래스에 선언한 것처럼 자바 설정 클래스에 선언
- **애플리케이션에서 캐시 데이터를 사용할 수 있도록 하는 애너테이션**
  - `@Cacheable`, `@CachePut`, `@CacheEvict`, `@Caching`
  - 메서드에 선언하면 캐시 데이터들을 저장/조회/퇴출 가능
  - 이들은 AOP 로 구현되어 있으므로 스프링 빈에 정의된 메서드에 정의해야 정상적으로 동작함
  - 또한 대상 메서드가 public 접근 제어자로 정의된 메서드만 AOP 가 정상적으로 동작함

---

## 2.1. `@Cacheable`

**`@Cacheable` 애너테이션은 캐시 저장소에 캐시 데이터를 저장/조회하는 기능을 하며, 메서드에 정의**한다.  

애너테이션이 정의된 메서드를 실행하면 데이터 저장소에 캐시 데이터 유무를 확인하여, 캐시 데이터가 있다면 메서드를 실행하지 않고 바로 데이터를 리턴하고  
캐시 데이터가 없으면 메서드를 실행한 후 메서드가 응답하는 객체를 캐시 저장소에 저장한다.  
메서드를 실행하는 과정에서 예외가 발생하면 캐시 데이터는 저장하지 않는다.

```java
// CacheManager 의 hotelCache 캐시에 저장됨
// hotelCache 에 정의된 설정값에 따라 캐시 데이터 관리 (BasicCacheConfig 클래스 참고)
// BasicCacheConfig 에서 hotelCache 캐시의 TTL 은 30분으로 설정함
// 미리 설정된 캐시가 없다면 CacheManager 의 기본 설정에 따라 캐시를 생성하고 데이터 저장
@Cacheable(value = "hotelCache")  // 캐시 이름을 hotelCache 로 설정
// 리턴되는 HotelResponse 객체를 사용하여 캐시 데이터 생성
public HotelResponse getHotelById(Long hotelId) { // Long HotelId 메서드 인자의 toString() 을 사용하여 캐시 key 생성
  return new HotelResponse(hotelId, "ASSU Hotel", "seoul");
}
```

위의 CacheManager 스프링 빈에 설정된 StringRedisSerializer 와 GenericJackson2JsonRedisSerializer (혹은 Jackson2JsonRedisSerializer) 로 캐시 key 는 문자열로 변경되어 저장되고, 
캐시 데이터는 JSON 형식으로 변경되어 저장된다.  
레디스에서 캐시 데이터를 조회하는 경우 JSON 메시지가 다시 객체로 변경되어 사용된다.  

위의 getHotelById() 메서드의 hotelId 인자를 사용하여 캐시 key 를 생성하고, 메서드가 리턴하는 HotelResponse 가 캐시 데이터가 된다.  
따라서 getHotelById() 메서드를 실행하는 클래스가 캐시를 생성하는 동시에 사용한다.

/service/HotelResponse.java
```java
package com.assu.study.chap10.service;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.ToString;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@ToString
public class HotelResponse {
  private Long hotelId;
  private String hotelName;
  private String hotelAddress;
}
```

---

**`@Cacheable` 애너테이션을 사용할 때는 메서드의 인자와 리턴 타입 변경에 유의**해야 한다.  

운영 중인 시스템의 인자를 추가하면 캐시 key 값이 변경될 수 있어서 데이터 저장소에 저장된 데이터를 활용할 수 없는 상태가 된다.  
메서드의 리턴 타입을 다른 클래스로 변경하면, 데이터 저장소에 저장된 데이터가 언마셜링(JSON → 객체) 되는 과정 중 에러가 발생할 수 있다.

아래는 `@Cacheable` 애너테이션의 속성과 기능이다.

- `value`, `cacheNames`
  - 캐시 데이터를 저장하는 캐시 이름 설정
- `key`
  - SpEL 을 사용하여 캐시 key 의 이름 설정
- `keyGenerator`
  - 캐시 key 를 생성하는 KeyGenerator 스프링 빈 설정
- `cacheManager`
  - 캐시를 관리하는 CacheManager 스프링 빈 이름 설정
- `cacheResolver`
  - 캐시 데이터를 처리하는 리졸버 설정
- `condition`
  - SpEL 로 캐시를 사용하는 조건 설정
  - 설정된 SpEL 이 true 일 때만 캐시 데이터를 저장하거나 조회 가능
- `unless`
  - SpEL 로 캐시를 사용하지 않는 조건 설정
  - 설정된 SpEL 이 true 일 때만 캐시 데이터를 사용하지 않음
- `sync`
  - 설정된 CacheManager 가 멀티 스레드 환경에 안전하게 동작하지 않는다면 동시에 같은 캐시 데이터를 생성/수정할 때 데이터가 오염될 수 있음
  - 이를 막고자 프로그램 레벨에서 `sync` 설정을 하여 synchronized 키워드처럼 동기화 기능을 제공함
  - 기본값은 false

---

### 2.1.1. `@Cacheable` 애너테이션의 `value`, `key`, `condition`

아래는 `@Cacheable` 애너테이션의 `value`, `key`, `condition` 속성을 사용한 예시이다.

/service/HotelService.java
```java
package com.assu.study.chap10.service;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

@Service
public class HotelService {

 // ...

  @Cacheable(
      value = "hotelCache",
      key = "#hotelName",
      condition = "#hotelName > '' && #hotelAddress.length() > 2"
  )
  public HotelResponse getHotelNameAndAddress(String hotelName, String hotelAddress) {
    return new HotelResponse(1111L, hotelName, hotelAddress);
  }
}
```

getHotelNameAndAddress() 메서드의 인자는 2개이다.  
만일 hotelName 인자만 사용하여 캐시 key 를 설정해야 하면 `key` 속성을 사용한다.

SpEL `#hotelName` 에서 `#` 은 객체를 의미하고, `hotelName` 은 인자 이름을 의미한다.  
만약 hotelName 인자의 클래스 타입이 String 이 아니라 HotelRequest 처럼 getter 패턴으로 내부 속성에 접근할 수 있는 밸류 클래스이면 `#hotelRequest.hotelName` 처럼 설정할 수 있다.

`condition` 속성에서 `#hotelName > ''` 은 null 조건을 검사한다.

아래는 위 기능의 테스트 케이스이다.

test > HotelServiceTest.java
```java
package com.assu.study.chap10.service;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class HotelServiceTest {

  @Autowired
  private HotelService hotelService;

  @Test
  void getHotelNameAndAddress() {
    // key: hotelCache::testHotelName
    // value: "{\"@class\":\"com.assu.study.chap10.service.HotelResponse\",\"hotelId\":1111,\"hotelName\":\"testHotelName\",\"hotelAddress\":\"testHotelAddress\"}"
    hotelService.getHotelNameAndAddress("testHotelName2", "testHotelAddress");
    hotelService.getHotelNameAndAddress("testHotelName2", "t");
  }
}
```

```shell
$ docker start spring-tour-redis

$ docker exec -it spring-tour-redis /bin/bash
redis-cli -h 127.0.0.1
127.0.0.1:6379> KEYS *
1) "backup4"
2) "backup1"
3) "hotelCache::testHotelName"
4) "backup2"
5) "backup3"
127.0.0.1:6379> GET "hotelCache::testHotelName"
"{\"@class\":\"com.assu.study.chap10.service.HotelResponse\",\"hotelId\":1111,\"hotelName\":\"testHotelName\",\"hotelAddress\":\"testHotelAddress\"}"
```

---

`@Cacheable` 애너테이션의 `value`, `key`, `condition`
### 2.1.2. `@Cacheable` 애너테이션의 `keyGenerator`

`@Cacheable` 애너테이션의 `keyGenerator` 를 사용하여 캐시 key 를 설정해보자.  

스프링 프레임워크는 캐시 key 이름을 생성하는 기능을 확장할 수 있는 o.s.cache.interceptor 의 `KeyGenerator` 인터페이스를 제공한다.  
이 인터페이스 구현체를 생성하고 스프링 빈으로 설정한 후 `@Cacheable` 의 `keyGenerator` 속성에 스프링 빈 이름을 설정하면 된다.

/service/HotelKeyGenerator.java
```java
package com.assu.study.chap10.service;

import org.springframework.cache.interceptor.KeyGenerator;
import org.springframework.cache.interceptor.SimpleKeyGenerator;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Objects;

public class HotelKeyGenerator implements KeyGenerator {
  private final String PREFIX = "HOTEL::";

  @Override
  // 캐시 key 생성 시 KeyGenerator 구현체가 설정되어 있으면 generate() 메서드를 사용하여 key 생성
  // Object target: 애너테이션이 정의된 클래스 객체
  // Method method: 애너테이션이 정의된 메서드
  // Object... params: 메서드의 인자들
  public Object generate(Object target, Method method, Object... params) {
    if (Objects.isNull(params)) {
      return "NULL";
    }

    return Arrays.stream(params)
            // 인자 중에서 HotelRequest 조회
            .filter(param -> param instanceof HotelRequest)
            .findFirst()
            // HotelRequest 클래스 타입인 인자가 있으면 HOTEL:: 문자열과 hotelRequest 객체의 hotelId 값을 결합하여 key 생성
            .map(obj -> (HotelRequest) obj)
            .map(hotelRequest -> PREFIX + hotelRequest.getHotelId())
            // HotelRequest 클래스 타입인 객체가 없다면 스프링 프레임워크에서 기본으로 사용하는 SimpleKeyGenerator 로 캐시 key 생성
            .orElse(SimpleKeyGenerator.generateKey(params).toString());
  }
}
```

HotelKeyGenertor 를 생성했으니 자바 설정 클래스에 스프링 빈으로 설정한다.

/config/BasicCacheConfig.java
```java
package com.assu.study.chap10.config;

import com.assu.study.chap10.service.HotelKeyGenerator;
import io.lettuce.core.ClientOptions;
import io.lettuce.core.SocketOptions;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceClientConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

@Configuration
@EnableCaching
public class BasicCacheConfig {
// ...

  @Bean
  public HotelKeyGenerator hotelKeyGenerator() {
    return new HotelKeyGenerator();
  }
}
```

스프링 빈으로 정의된 HotelKeyGenerator 는 `@Cacheable` 애너테이션의 `keyGenerator` 속성에 스프링 빈 이름을 정의하면 된다.

test > HotelServiceTest.java
```java
package com.assu.study.chap10.service;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class HotelServiceTest {

  @Autowired
  private HotelService hotelService;

// ...

  @Test
  void getHotel() {
    // key: hotelCache::HOTEL::2222
    // value: "{\"@class\":\"com.assu.study.chap10.service.HotelResponse\",\"hotelId\":2222,\"hotelName\":\"ASSU2\",\"hotelAddress\":\"seoul2\"}"
    HotelRequest request = new HotelRequest(2222L);
    hotelService.getHotel(request);
  }
}
```

```shell
127.0.0.1:6379> KEYS *
1) "backup4"
2) "backup1"
3) "hotelCache::testHotelName"
4) "hotelCache::testHotelName2"
5) "backup2"
6) "hotelCache::HOTEL::2222"
7) "backup3"
127.0.0.1:6379> GET "hotelCache::HOTEL::2222"
"{\"@class\":\"com.assu.study.chap10.service.HotelResponse\",\"hotelId\":2222,\"hotelName\":\"ASSU2\",\"hotelAddress\":\"seoul2\"}"
```

---

## 2.2. `@CachePut`

`@Cacheable` 애너테이션은 캐시 key 와 매핑되는 캐시 데이터의 유무에 따라 캐시 데이터를 저장하거나, 캐시 데이터를 조회하는 두 가지 기능을 제공한다.  

`@CahcePut` 애너테이션은 캐시를 생성하는 기능만 제공하므로, 캐시 데이터를 생성하고 갱신하는 목적으로 사용한다.  
해당 메서드가 정상적으로 실행되면 메서드가 리턴하는 객체를 캐시에 저장하고, 메서드 실행 도중 에러가 발생하면 캐시 데이터는 갱신하지 않는다.

속성은 `@Cacheable` 에서 제공하는 기능에서 `sync` 를 제외하고 모두 동일하다.

---

## 2.3. `@CacheEvict`

`@CacheEvict` 애너테이션은 캐시 데이터를 캐시에서 제거하는 기능이다.  
원본 데이터를 변경하거나 삭제하는 메서드에 `@CacheEvict` 를 적용하면 된다.  

원본 데이터가 변경되면 캐시에서 삭제하고, `@Cacheable` 애너테이션이 적용된 메서드가 실행되면 다시 변경된 데이터가 저장된다.

`@CacheEvict` 의 속성은 `@Cacheable` 애너테이션과 같은 속성들을 제공하며, 아래 속성을 추가로 제공한다.

- `allEntries`
  - 기본값은 true
  - true 이면 해당 캐시에 포함된 모든 캐시 데이터 삭제
- `beforeInvocation`
  - 기본값은 false
  - true 이면 대상 메서드를 실행하기 전에 캐시를 삭제함
  - false 이면 대상 메서드를 실행한 후 캐시를 삭제함, 대상 메서드를 실행하는 과정에서 예외가 발생하면 캐시도 정상적으로 삭제되지 않음

---

## 2.4. `@Caching`

`@Caching` 애너테이션은 2 개 이상의 캐시 애너테이션을 조합하여 사용할 수 있도록 한다.  
즉, 여러 개의 `@Cacheable`, `@CachePut`, `@CacheEvict` 애너테이션을 정의할 수 있다.

아래는 `cacheable` 속성을 사용하여 여러 캐시 저장소에 데이터를 저장하는 예시이다.

```java
@Caching(cacheable = {
    @Cacheable(value="primaryHotelCache", keyGenerator="hotelKeyGenerator"),
    @Cacheable(value="secondHotelCache", keyGenerator="hotelKeyGenerator")
})
public HotelResponse getHotel(HotelRequest hotelRequest) {
  // ...  
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [Redis 데이터 타입: 공홈](https://redis.io/docs/data-types/)
* [Redis Commands 공홈](https://redis.io/commands/)
* [Lettuce reference](https://lettuce.io/core/release/reference/index.html#connection-pooling.is-connection-pooling-necessary)