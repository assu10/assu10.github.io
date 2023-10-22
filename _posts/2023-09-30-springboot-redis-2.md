---
layout: post
title:  "Spring Boot - Redis 와 스프링 캐시(2): `RedisTemplate` 설정"
date:   2023-09-30
categories: dev
tags: springboot msa redis redis-serializer value-operation redis-template
---

이 포스팅에서는 `RedisTemplate` 를 직접 설정하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap10) 에 있습니다.

---

**목차**

- [레디스 스트링 예시와 `RedisSerializer` 설정](#1-레디스-스트링-예시와-redisserializer-설정)
  - [`ValueOperation<K,V>` 인터페이스](#11-valueoperationkv-인터페이스)
  - [`RedisSerializer` 구현체](#12-redisserializer-구현체)
  - [`RedisTemplate` 스프링 빈 직접 설정](#13-redistemplate-스프링-빈-직접-설정)
  - [직접 설정한 `RedisTemplate` 스프링 빈을 사용하여 데이터 조작](#14-직접-설정한-redistemplate-스프링-빈을-사용하여-데이터-조작)

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

# 1. 레디스 스트링 예시와 `RedisSerializer` 설정

여기서는 레디스 문자열 자료 구조를 사용하여 데이터를 레디스에 입력/조회하는 방법에 대해 알아본다.  

[`RedisAutoConfiguration`](https://assu10.github.io/dev/2023/09/24/springboot-redis-1/#21-redisautoconfiguration-%EC%9E%90%EB%8F%99-%EC%84%A4%EC%A0%95) 에서 제공하는 `RedisTemplate` 스프링 빈은 범용으로 쓸 수 있도록 레디스 키와 밸류의 클래스 타입을 Object 로 사용한다.  
따라서 `RedisTemplate<Object, Object>` 처럼 키, 밸류에 Object 클래스로 제네릭이 설정되어 있다.  

여기선 별도의 `RedisTemplate` 스프링 빈을 설정하여 특정 클래스를 레디스 키와 밸류의 클래스 타입으로 사용하는 방법에 대해 알아본다.  
이 때 레디스와 애플리케이션 사이에 데이터를 변환하는 역할은 `RedisSerializer` 가 담당한다.

> `RedisSerializer` 에 대한 내용은 추후 다룰 예정입니다.

여기선 레디스의 문자열 자료 구조를 사용하여 호텔 캐시 데이터를 레디스에 저장하는 법에 대해 알아본다.

HotelCacheKey 객체를 레디스 키로 사용하고, HotelCacheValue 객체를 레디스 밸류로 사용한다.  
레디스 key 의 경우 특정 호텔 정보를 캐시하는 데이터를 저장하므로 _HOTEL::{hotelId}_ 처럼 설계할 수 있고,  
레디스 value 의 경우 캐시를 위한 호텔 객체를 JSON 문자열로 변환하여 저장한다.

---

## 1.1. `ValueOperation<K,V>` 인터페이스

o.s.data.redis.core.ValueOperation\<K,V\> 인터페이스는 레디스의 문자열 자료 구조를 사용할 수 있는 기능을 제공하는데, `RedisTemplate` 의 `opsForValue()` 메서드를 사용하면 
`ValueOperations` 객체를 획득할 수 있다.  
만일 RedisTemplate 의 제네릭 클래스 타입을 RedisTemplate\<HotelCacheKey, HotelCacheValue\> 스프링 빈처럼 정의하면 `opsForValue()` 메서드가 리턴하는 클래스 타입은 
ValueOperations\<HotelCacheKey, HotelCacheValue\> 이 된다.

```java
ValueOperations<HotelCacheKey, HotelCacheValue> hotelCacheOperation = hotelCacheRedisTemplate.opsForValue();
```

<**ValueOperation\<K,V\> 인터페이스가 제공하는 일부 메서드**>  
- `void set(K key, V value)`
  - key, value 저장
- `void set(K key, V value, long timeout, TimeUnit unit)`
  - key, value 저장과 동시에 유효 기간 설정
  - TimeUnit 값과 timeout 인자를 사용하여 설정
- `Boolean setIfAbsent(K key, V value)`
  - key 와 매칭되는 데이터가 없으면 value 저장
  - 메서드 성공 시 true 리턴
- `Boolean setIfAbsent(K key, V value, long timeout, TimeUnit unit)`
  - `setIfAbsent()` 와 같은 기능이지만, 데이터 저장 시 timeout 과 TimeUnit 값을 사용하여 유효 기간 설정
- `Boolean setIfPresent(K key, V value)`
  - key 와 매칭되는 데이터가 있으면 데이터를 덮어씀
  - 메서드 성공 시 true 리턴
- `Boolean setIfPresent(K key, V value, long timeout, TimeUnit unit)`
  - `setIfPresent()` 와 같은 기능이지만, 데이터 저장 시 timeout 과 TimeUnit 값을 사용하여 유효 기간 설정 
- `V getAndDelete(K key)`
  - key 와 매칭되는 데이터를 조회하여 리턴하는 동시에 데이터 삭제
- `V getAndExpire(K key, long timeout, TimeUnit unit)`
  - key 와 매칭되는 데이터를 조회하면서 데이터의 유효 기간 설정
- `V getAndSet(K key, V value)`
  - key 와 매칭되는 이전 데이터를 조회하고 리턴
  - 그리고 인자로 받은 value 를 새로 저장
- `Long increment(K key)`
  - 저장된 문자열이 숫자라면 1 증가
- `Double increment(K key, double delta)`
  - delta 인자만큼 증가
  - Long 타입으로 리턴하는 메서드도 있음
- `Long decrement(K key)`
  - 저장된 문자열이 숫자라면 1 감소
- `Long decrement(K key, long delta)`
  - delta 인자만큼 감소

---

## 1.2. `RedisSerializer` 구현체

[3.1.3. `RedisClusterConfiguration` 을 사용하여 `RedisConnectionFactory` 스프링 빈 생성](https://assu10.github.io/dev/2023/09/24/springboot-redis-1/#31-redisconnectionfactory-%EC%84%A4%EC%A0%95) 에서 만든
CacheConfig 자바 설정 클래스는 `RedisTemplate` 스프링 빈을 설정한다.

직접 설정한 `RedisTemplate` 스프링 빈은 레디스 key 로 HotelCacheKey 클래스를 사용하고, value 는 호텔 정보를 의미하는 HotelCacheValue 클래스를 사용하도록 설정할 예정이다.

이 RedisTemplate\<HotelCacheKey, HotelCacheValue\> 는 HotelCacheKey, HotelCacheValue 두 클래스 타입 전용으로만 사용할 수 있으므로 이 두 클래스를 변환하는 전용 `RedisSerializer` 를 구현할 수 있다.

**직렬화 과정을 거치면 자바 객체가 byte[] 로 변환되어 레디스에 저장되고, 역직렬화 과정을 거치면 레디스에 저장된 byte[] 가 자바 객체로 변환**된다.

---

기본 설정으로 생성된 `RedisTemplate` 에 설정된 `RedisSerializer` 구현체는 `JdkSerializationRedisSerializer` 클래스로 이 구현체는 자바 Object 객체를 byte[] 로 직렬화하고, 
byte[] 데이터를 다시 Object 객체로 역직렬화하는 기능을 제공한다.  
Object 클래스 타입을 사용하므로 어떤 자바 객체라도 변환할 수 있지만 이 **JdkSerializationRedisSerializer 구현체를 사용하면 애플리케이션 코드에서 적절한 클래스 타입으로 변환하는 타입 캐스팅이 필요**하다.  
즉, **타입 캐스팅 과정에서 잘못된 클래스 타입으로 변환하면 런타임 에러가 발생**한다.  
결국 클래스 타입에 안전하지 않게 된다.

만일 `RedisTemplate` 를 별도의 Serializer 를 사용하지 않고 기본 `JdkSerializationRedisSerializer` 사용하게 될 경우
`JdkSerializationRedisSerializer` 는 자바의 직렬화 기능을 사용하기 때문에 직렬화/역직렬화의 대상 클래스인 HotelCacheKey 와 HotelCacheValue 클래스에 java.io.Serializable 인터페이스를 반드시 구현해야 한다.  

또한 **`JdkSerializationRedisSerializer` 로 직렬화된 데이터는 아래처럼 인코딩된 문자열로 레디스에 저장**되어서 레디스에서 커맨드 명령어를 사용하여 사용자가 직접 확인하기 어려워서 
Prod 환경에 유연하게 대응하기 어렵다.

따라서 **_가능하면 별도의 `RedisSerializer` 구현체를 사용하는 것을 권장_**한다.

---

레디스 key 를 직렬화할 때 문자열로 저장하도록 설계하는 것이 일반적이다.  
그래서 아래 HotelCacheKeySerializer 가 레디스 데이터 키로 사용할 HotelCacheKey 객체를 직렬화하면 문자열로 변환된다.  
이 때 변환된 문자열은 'HOTEL::{hotelId}' 형태로 직렬화된 문자열에 `::` 을 사용하여 정보를 구분하는 것이 레디스의 관례이다.

레디스 value 에 저장되는 객체는 일반적으로 JSON 메시지로 변환한다.  
value 객체에는 하나 이상의 속성을 포함하고, 이를 문자열로 변환하기에 JSON 메시지가 가독성이 좋기 때문이다.

---

아래는 HotelCacheKeySerializer 와 HotelCacheValueSerializer 의 구현체 코드이다.

/adapter/cache/HotelCacheKeySerializer.java
```java
package com.assu.study.chap10.adapter.cache;

import org.springframework.data.redis.serializer.RedisSerializer;
import org.springframework.data.redis.serializer.SerializationException;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

public class HotelCacheKeySerializer implements RedisSerializer<HotelCacheKey> {
  private final Charset UTF_8 = StandardCharsets.UTF_8;

  @Override
  public byte[] serialize(HotelCacheKey hotelCacheKey) throws SerializationException {
    // 레디스 데이터 중 key 는 null 이 될 수 없음
    if (Objects.isNull(hotelCacheKey)) {
      throw new SerializationException("hotelCacheKey is null.");
    }
    
    // HotelCacheKey 가 직렬화되면 byte[] 를 리턴해야 함
    // 이 때 Charset 를 설정하여 byte[] 로 변환하는 것이 좋음
    return hotelCacheKey.toString().getBytes(UTF_8);
  }

  @Override
  public HotelCacheKey deserialize(byte[] bytes) throws SerializationException {
    if (Objects.isNull(bytes)) {
      throw new SerializationException("bytes is null.");
    }
    
    // 레디스의 key 데이터는 byte[] 이므로 적절히 변환하여 HotelCacheKey 객체를 생성하여 리턴
    return HotelCacheKey.fromString(new String(bytes, UTF_8));
  }
}
```

/adapter/cache/HotelCacheValueSerializer.java
```java
package com.assu.study.chap10.adapter.cache;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.data.redis.serializer.RedisSerializer;
import org.springframework.data.redis.serializer.SerializationException;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

public class HotelCacheValueSerializer implements RedisSerializer<HotelCacheValue> {
  // JSON Mapper
  // HotelCacheValue 객체를 직렬화한 메시지 포맷은 JSON 메시지임
  // JSON 메시지 변환에 사용할 ObjectMapper 객체 생성
  // ObjectMapper 는 생성 비용이 비싸고, 멀티 스레드 환경에 안전하므로 static 변수로 생성하여 공요하는 형태로 사용함
  public static final ObjectMapper MAPPER = new ObjectMapper();
  private final Charset UTF_8 = StandardCharsets.UTF_8;

  @Override
  public byte[] serialize(HotelCacheValue hotelCacheValue) throws SerializationException {
    if (Objects.isNull(hotelCacheValue)) {
      return null;
    }

    try {
      // HotelCacheValue 객체를 JSON 메시지 문자열로 변경
      String json = MAPPER.writeValueAsString(hotelCacheValue);
      return json.getBytes(UTF_8);
    } catch (JsonProcessingException e) {
      throw new SerializationException("json serialize error", e);
    }
  }

  @Override
  public HotelCacheValue deserialize(byte[] bytes) throws SerializationException {
    // 레디스의 value 를 역직렬화할 때 null 검사 시 주의
    // 레디스 key 와 맞는 value 가 레디스에 없을수도 있으므로 null 인 경우 무조건 예외를 던지면 안됨
    if (Objects.isNull(bytes)) {
      return null;
    }

    try {
      // HotelCacheValue 객체로 변환
      return MAPPER.readValue(new String(bytes, UTF_8), HotelCacheValue.class);
    } catch (JsonProcessingException e) {
      throw new SerializationException("json deserialize error", e);
    }
  }
}
```

**ObjectMapper 는 생성 비용이 비싸고, 멀티 스레드 환경에 안전하므로 static 변수로 생성하여 공요하는 형태로 사용**한다.  

/adapter/cache/HotelCacheKey.java
```java
package com.assu.study.chap10.adapter.cache;

import java.util.Objects;

public class HotelCacheKey {
  private static final String PREFIX = "HOTEL::";

  private final Long hotelId;

  private HotelCacheKey(Long hotelId) {
    if (Objects.isNull(hotelId)) {
      throw new IllegalArgumentException("hotelId can't be null.");
    }
    this.hotelId = hotelId;
  }

  // 정적 팩토리 메서드
  public static HotelCacheKey from(Long hotelId) {
    return new HotelCacheKey(hotelId);
  }

  public static HotelCacheKey fromString(String key) {
    String idToken = key.substring(0, PREFIX.length());
    Long hotelId = Long.valueOf(idToken);

    return HotelCacheKey.from(hotelId);
  }

  @Override
  public String toString() {
    return PREFIX +
        hotelId;
  }
}
```

/adapter/cache/HotelCacheValue.java
```java
package com.assu.study.chap10.adapter.cache;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.ToString;

import java.util.Objects;

// VO
@Getter
@ToString
@EqualsAndHashCode
public final class HotelCacheValue {
  private final String name;
  private final String address;

  private HotelCacheValue(String name, String address) {
    if (Objects.isNull(name)) {
      throw new IllegalArgumentException("name can't be null.");
    }
    if (Objects.isNull(address)) {
      throw new IllegalArgumentException("address can't be null.");
    }
    this.name = name;
    this.address = address;
  }

  @JsonCreator // 언마셜링 과정(JSON -> 객체)에서 값 변환에 사용되는 메서드를 지정
  public static HotelCacheValue of(@JsonProperty("name") String name,
                                   @JsonProperty("address") String address) {
    return new HotelCacheValue(name, address);
  }
}
```

> `@JsonCreator` 에 대한 내용은 [2.4. Enum 클래스의 변환: `@JsonValue`, `@JsonCreator`](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2/#24-enum-%ED%81%B4%EB%9E%98%EC%8A%A4%EC%9D%98-%EB%B3%80%ED%99%98-jsonvalue-jsoncreator) 을 참고하세요.

> `@JsonProperty` 에 대한 내용은 [2.1. JSON 마셜링: `@JsonProperty`, `@JsonSerialize`](https://assu10.github.io/dev/2023/05/14/springboot-rest-api-2/#21-json-%EB%A7%88%EC%85%9C%EB%A7%81-jsonproperty-jsonserialize) 를 참고하세요.

---

## 1.3. `RedisTemplate` 스프링 빈 직접 설정

위에서 만든 `RedisSerializer` 구현체를 이제 `RedisTemplate` 에 설정한다.

/config/CacheConfig.java
```java
package com.assu.study.chap10.config;

// ...

import java.time.Duration;

// RedisConnectionFactory 스프링 빈 생성
@Slf4j
@Configuration
public class CacheConfig {
  // RedisStandaloneConfiguration 으로 RedisConnectionFactory 스프링 빈 생성
  @Bean
  public RedisConnectionFactory cacheRedisConnectionFactory() {
    // ...
  }

  @Bean(name = "hotelCacheRedisTemplate")
  public RedisTemplate<HotelCacheKey, HotelCacheValue> hotelCacheRedisTemplate() {
    // RedisTemplate 는 제네릭 타입 K,V 설정 가능
    // 첫 번째는 레디스 key 에 해당하고, 두 번째는 레디스 value 에 해당함
    RedisTemplate<HotelCacheKey, HotelCacheValue> hotelCacheRedisTemplate = new RedisTemplate();

    // 위에서 생성한 RedisConnectionFactory 스프링 빈을 사용하여 RedisTemplate 객체 생성
    hotelCacheRedisTemplate.setConnectionFactory(cacheRedisConnectionFactory());
    
    // key 와 value 값을 직렬화/역직렬화하는 RedisSerializer 구현체 설정
    hotelCacheRedisTemplate.setKeySerializer(new HotelCacheKeySerializer());
    hotelCacheRedisTemplate.setValueSerializer(new HotelCacheValueSerializer());

    return hotelCacheRedisTemplate;
  }
}
```

`RedisTemplate` 에는 key, value 에 각각 별도의 `RedisSerializer` 구현체를 설정할 수 있다.  

`RedisSerializer` 또한 제네릭 타입을 설정할 수 있다.  

---

## 1.4. 직접 설정한 `RedisTemplate` 스프링 빈을 사용하여 데이터 조작


이제 `RedisTemplate` 스프링 빈을 설정했으니 데이터를 다루어본다.

아래 CacheAdapter 클래스는 RedisTemplate\<HotelCacheKey, HotelCacheValue\> hotelCacheRedisTemplate 스프링 빈을 주입받은 후 
HotelCacheValue 객체를 레디스에 생성/조회/삭제하는 기능을 제공한다.

/adapter/cache/CacheAdapter.java
```java
package com.assu.study.chap10.adapter.cache;

import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Component
public class CacheAdapter {
  private final RedisTemplate<HotelCacheKey, HotelCacheValue> hotelCacheRedisTemplate;
  private final ValueOperations<HotelCacheKey, HotelCacheValue> hotelCacheOperation;

  public CacheAdapter(RedisTemplate<HotelCacheKey, HotelCacheValue> hotelCacheRedisTemplate) {
    this.hotelCacheRedisTemplate = hotelCacheRedisTemplate;
    // CacheAdapter 클래스는 레디스의 key-value 자료 구조를 사용하므로 RedisTemplate 의 opsForValue() 를 사용하여 ValueOperations 객체 생성
    // ValueOperations 객체는 key-value 자료 구조에서 사용할 수 있는 get(), set(), delete() 와 같은 메서드들을 제공함
    this.hotelCacheOperation = hotelCacheRedisTemplate.opsForValue();
  }

  public void put(HotelCacheKey key, HotelCacheValue value) {
    // 유효 기간은 24시간으로 설정
    hotelCacheOperation.set(key, value, Duration.ofSeconds(24 * 60 * 60));
  }

  public HotelCacheValue get(HotelCacheKey key) {
    return hotelCacheOperation.get(key);
  }

  public void delete(HotelCacheKey key) {
    hotelCacheRedisTemplate.delete(key);
  }
}
```

위에서 레디스에 데이터를 저장할 때 유효 기간을 설정하려고 `hotelCacheOperation.set(key, value, Duration.ofSeconds(24 * 60 * 60));` 를 사용하였다.  

레디스 데이터의 유효 기간 설정 시 `RedisTemplate` 의 `expire()` 와 `ValueOperations` 의 `getAndExpire()`, `set()` 명령어를 사용할 수도 있지만 명령어를 두 번 사용해야 한다.

---

아래는 CacheAdapterTest.java 이다.

test > CAcheAdapterTest.java
```java
package com.assu.study.chap10.adapter.cache;

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@Slf4j
@SpringBootTest
class CacheAdapterTest {

  @Autowired
  private CacheAdapter cacheAdapter;

  @Test
  @DisplayName("Cache 에서 데이터 조회")
  void get() {
    // given
    HotelCacheKey key = HotelCacheKey.from(1111L);
    HotelCacheValue value = HotelCacheValue.of("assu", "seoul");
    cacheAdapter.put(key, value);

    // when
    HotelCacheValue result = cacheAdapter.get(key);
    log.info("result: {}", result);

    // then
    Assertions.assertEquals(value, result);
  }

  @Test
  @DisplayName("Cache 에서 데이터 삭제")
  void delete() {
    // given
    HotelCacheKey key = HotelCacheKey.from(1111L);
    HotelCacheValue value = HotelCacheValue.of("assu", "seoul");
    cacheAdapter.put(key, value);

    // when
    cacheAdapter.delete(key);

    // then
    HotelCacheValue result = cacheAdapter.get(key);
    Assertions.assertNull(result);
  }
}
```

> 로컬에서 레디스 도커 설정은 [2.2. 레디스 도커 설정](https://assu10.github.io/dev/2023/09/24/springboot-redis-1/#22-%EB%A0%88%EB%94%94%EC%8A%A4-%EB%8F%84%EC%BB%A4-%EC%84%A4%EC%A0%95) 를 참고하세요.

```shell
$ docker start spring-tour-redis

$ docker exec -it spring-tour-redis /bin/bash
root@cd367c349449:/data# redis-cli -h 127.0.0.1
127.0.0.1:6379> KEYS *
1) "HOTEL::1111"
2) "backup4"
3) "backup3"
4) "backup2"
5) "backup1"


# put test 후
127.0.0.1:6379> GET "HOTEL::1111"
"{\"name\":\"assu\",\"address\":\"seoul\"}"

# delete test 후
127.0.0.1:6379> GET "HOTEL::1111"
(nil)
```

만일 레디스 value 값의 자료 구조가 Hash 자료 구조라면 RedisSerializer 구현체 설정 시 아래와 같이 한다.
```java
package com.assu.study.chap10.config;

// ...

// RedisConnectionFactory 스프링 빈 생성
@Slf4j
@Configuration
public class CacheConfig {

  // ...
  
  @Bean(name = "hotelCacheRedisTemplate")
  public RedisTemplate<HotelCacheKey, HotelCacheValue> hotelCacheRedisTemplate() {

    // ...
    
    // Hash 자료 구조 사용 시 레디스 key, hash filed, hash value 의 RedisSerializer 3개 설정 필요
    hotelCacheRedisTemplate.setKeySerializer(new HotelCacheKeySerializer());
    hotelCacheRedisTemplate.setHashKeySerializer(new StringRedisSerializer());
    hotelCacheRedisTemplate.setHashValueSerializer(new Jackson2JsonRedisSerializer<HotelCacheValue>(HotelCacheValue.class));

    return hotelCacheRedisTemplate;
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
