---
layout: post
title:  "Spring Security - 암호 처리"
date:   2023-11-19
categories: dev
tags: spring-security password-encoder no-op-password-encoder standard-password-encoder pbkdf2-password-encoder bcrypt-password-encoder scrypt-password-encoder delegating-password-encoder key-generator string-key-generator bytes-key-generator text-encryptor bytes-encryptor encryptors
---

이 포스트에서는 스프링 시큐리티로 구현한 애플리케이션에서 암호를 관리하는 방법에 대해 알아본다.

- `PasswordEncoder` 계약의 구현
- 암호 관리를 위한 스프링 시큐리티 암호화 모듈(SSCM, Spring Security Crypto Module)

---

**목차**

<!-- TOC -->
* [1. `PasswordEncoder` 계약](#1-passwordencoder-계약)
  * [1.1. `PasswordEncoder` 계약 구현](#11-passwordencoder-계약-구현)
  * [1.2. `PasswordEncoder` 의 제공된 구현 (중요)](#12-passwordencoder-의-제공된-구현-중요)
    * [`NoOpPasswordEncoder`](#nooppasswordencoder)
    * [`StandardPasswordEncoder`](#standardpasswordencoder)
    * [`Pbkdf2PasswordEncoder`](#pbkdf2passwordencoder)
    * [`BCryptPasswordEncoder`](#bcryptpasswordencoder)
    * [`SCryptPasswordEncoder`](#scryptpasswordencoder)
  * [1.3. `DelegatingPasswordEncoder` 를 이용한 여러 인코딩 전략: `PasswordEncoderFactories`](#13-delegatingpasswordencoder-를-이용한-여러-인코딩-전략-passwordencoderfactories)
  * [1.4. 인코딩, 암호화, 해싱](#14-인코딩-암호화-해싱)
* [2. 스프링 시큐리티 암호화 모듈(SSCM, Spring Security Crypto Module) 의 추가 정보](#2-스프링-시큐리티-암호화-모듈sscm-spring-security-crypto-module-의-추가-정보)
  * [2.1. KeyGenerator](#21-keygenerator)
  * [2.1.1. `StringKeyGenerator`](#211-stringkeygenerator)
  * [2.1.2. `BytesKeyGenerator`](#212-byteskeygenerator)
  * [2.2. 암호화/복호화 작업에 암호기 사용](#22-암호화복호화-작업에-암호기-사용)
    * [2.2.1. `TextEncryptor`](#221-textencryptor)
    * [2.2.2. `BytesEncryptor`](#222-bytesencryptor)
    * [2.2.3. 암호기 구현: `encryptors`](#223-암호기-구현-encryptors)
* [마치며...](#마치며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.2.2
- Spring ver: 6.1.3
- Spring Security ver: 6.2.1
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap02

![Spring Initializer Sample](/assets/img/dev/2023/1112/init.png)

---

# 1. `PasswordEncoder` 계약

![AuthenticationProvider 는 인증 프로세스에서 PasswordEncoder 를 이용하여 사용자의 암호 검증](/assets/img/dev/2023/1119/security.png)

`AuthenticationProviver`는 `UserDetailsService` 를 통해 사용자를 찾은 후 `PasswordEncoder` 를 이용하여 암호를 검증한다.

`PasswordEncoder` 계약에 선언된 `encode()`, `matches()` 메서드가 계약의 책임을 정의한다.  
애플리케이션이 암호를 인코딩하는 방식은 암호를 검증하는 방식과 연관된다.

`PasswordEncoder` 인터페이스
```java
package org.springframework.security.crypto.password;

public interface PasswordEncoder {
  String encode(CharSequence rawPassword);

  boolean matches(CharSequence rawPassword, String encodedPassword);

  default boolean upgradeEncoding(String encodedPassword) {
    return false;
  }
}
```

`PasswordEncoder` 인터페이스는 2개의 추상 메서드와 1개의 디폴트 메서드로 구성되어 있다.

- `encode(CharSequence rawPassword)`
  - 주어진 문자열을 변환하여 반환
  - 주어진 암호의 해시를 제공하거나, 암호화를 수행함
- `matches(CharSequence rawPassword, String encodedPassword)`
  - 인코딩된 문자열이 원시 암호와 일치하는지 확인
- `upgradeEncoding(String encodedPassword)`
  - true 를 반환하도록 재정의하면 인코딩된 암호를 보안 향상을 위해 다시 인코딩함

---

## 1.1. `PasswordEncoder` 계약 구현

`matches()` 와 `encode()` 메서드들을 정의하려면 기능 측면에서 항상 일치해야 한다.  
`encoce()` 메서드에서 반환된 문자열은 항상 같은 `PasswordEncoder` 의 `matches()` 메서드로 검증할 수 있어야 한다.

[3.1. UserDetailsService 재정의](https://assu10.github.io/dev/2023/11/12/springsecurity-basic-2/#31-userdetailsservice-%EC%9E%AC%EC%A0%95%EC%9D%98) 에서 본 `NoOpPasswordEncoder` 인스턴스 
암호를 인코딩하지 않고 plain 텍스트로 취급한다.

암호를 plain 텍스트로 취급하도록 `PasswordEncoder` 인터페이스를 구현하면 아래와 같다.
```java
/**
 * 암호를 plain text 취급
 */
public class PlainTextPasswordEncoder implements PasswordEncoder {
  @Override
  public String encode(CharSequence rawPassword) {
    // 암호를 변경하지 않고 그대로 반환
    return rawPassword.toString();
  }

  @Override
  public boolean matches(CharSequence rawPassword, String encodedPassword) {
    return rawPassword.equals(encodedPassword);
  }
}
```

아래는 해싱 알고리즘 SHA-512 를 이용한 예시이다.

> [1.2. `PasswordEncoder` 의 제공된 구현 (중요)](#12-passwordencoder-의-제공된-구현-중요)에 좀 더 좋은 `PasswordEncoder` 인터페이스 구현이 있으니 아래는 참고만 할 것

```java
import org.springframework.security.crypto.password.PasswordEncoder;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * 해싱 알고리즘 SHA-512 를 이용
 */
public class Sha512PasswordEncoder implements PasswordEncoder {
  @Override
  public String encode(CharSequence rawPassword) {
    return hashedSha512(rawPassword.toString());
  }

  @Override
  public boolean matches(CharSequence rawPassword, String encodedPassword) {
    String hashedPassword = encode(rawPassword);
    return encodedPassword.equals(hashedPassword);
  }

  private String hashedSha512(String input) {
    StringBuilder result = new StringBuilder();
    try {
      MessageDigest md = MessageDigest.getInstance("SHA-512");
      byte[] digested = md.digest(input.getBytes());
      for (int i=0; i<digested.length; i++) {
        result.append(Integer.toHexString(0xFF & digested[i]));
      }
    } catch (NoSuchAlgorithmException e) {
      throw new RuntimeException(e);
    }
    return result.toString();
  }
}

```

---

## 1.2. `PasswordEncoder` 의 제공된 구현 (중요)

스프링 시큐리티에는 이미 몇 가지 유용한 `PasswordEncoder` 구현 옵션이 있다.

- `NoOpPasswordEncoder`
  - 암호를 인코딩하지 않고 plain text 로 유지함
  - 실제 운영 시엔 절대 사용하지 말아야 함
- `StandardPasswordEncoder`
  - SHA-256 을 이용하여 암호 해시
  - 구식이며, 새로운 구현에는 쓰지 않는 것이 좋음
- `Pbkdf2PasswordEncoder`
  - PBKDF2 를 이용하여 암호 해시
- `BCryptPasswordEncoder`
  - bcrypt 강력 해싱 함수로 암호 인코딩
- `SCryptPasswordEncoder`
  - scrypt 해싱 함수로 암호 인코딩

---

### `NoOpPasswordEncoder`

싱글톤으로 설계되어서 클래스 외부에서 생성자를 호출할 수 업고, 아래와 같이 클래스 인스턴스를 얻을 수 있음 

```java
PasswordEncoder p = NoOpPasswordEncoder.getInstance();
```

---

### `StandardPasswordEncoder`

시크릿 키는 생성자의 매개 변수로 전달하며, 인수가 없는 생성자를 호출하면 빈 문자열이 시크릿 키로 사용됨

```java
PasswordEncoder p = new StandardPasswordEncoder();
PasswordEncoder p = new StandardPasswordEncoder("secret");
```

---

### `Pbkdf2PasswordEncoder`

```java
import org.springframework.security.crypto.password.Pbkdf2PasswordEncoder;

PasswordEncoder p1 = new Pbkdf2PasswordEncoder("secret", 18500, 267, Pbkdf2PasswordEncoder.SecretKeyFactoryAlgorithm.PBKDF2WithHmacSHA512);
```

```java
public static enum SecretKeyFactoryAlgorithm {
  PBKDF2WithHmacSHA1,
  PBKDF2WithHmacSHA256,
  PBKDF2WithHmacSHA512;

  private SecretKeyFactoryAlgorithm() {
  }
}
```

첫 번째 인수는 시크릿 키이고, 두 번째 인수는 암호 인코딩의 반복 횟수, 세 번째 인수는 해시의 크기, 네 번째 인수는 암호화 알고리즘 방식 이다.

해시가 길수록 암호는 더 강력해지지만 이러한 값은 성능에 영향을 주며, 반복 횟수를 늘리면 애플리케이션이 소비하는 리소스가 증가하므로 해시 생성에 사용되는 리소스와 필요한 인코딩 강도 
사이에서 절충안을 찾아야 한다.

---

### `BCryptPasswordEncoder`

```java
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import java.security.MessageDigest;
import java.security.SecureRandom;

PasswordEncoder p1 = new BCryptPasswordEncoder();
// 로그 라운드를 나타내는 강도 계수 지정
PasswordEncoder p2 = new BCryptPasswordEncoder(4);

// 인코딩에 이용되는 SecureRandom 인스턴스를 변경
SecureRandom s = SecureRandom.getInstanceStrong();
PasswordEncoder p3 = new BCryptPasswordEncoder(4, s);
```

로그 라운드 값은 해싱 작업이 이용하는 반복 횟수에 영향을 주며, 반복 횟수는 2로그 라운드로 계산된다.  
반복 회수를 계산하기 위한 로그 라운드 값은 4~31 사이이어야 한다.

---

### `SCryptPasswordEncoder`

```java
import org.springframework.security.crypto.scrypt.SCryptPasswordEncoder;

PasswordEncoder p1 = new SCryptPasswordEncoder(16384, 8, 1, 32, 64);
```

각 인수는 순서대로 아래를 의미한다.
- cpuCost
- memoryCost
- parallelization (병렬화 계수)
- keyLength
- saltLength

---

## 1.3. `DelegatingPasswordEncoder` 를 이용한 여러 인코딩 전략: `PasswordEncoderFactories`

`DelegatingPasswordEncoder` 는 암호 일치를 위해 다양한 구현을 적용해야 할 때 사용한다.

운영을 하다 보면 다양한 암호 인코더를 갖춘 후에 특정 상황에 따라 인코더를 선택하는 방식을 사용해야 할 때가 있다.  
예를 들면 현재 사용되는 알고리즘에서 취약점이 발견되어 신규 등록 유저부터는 자격 증명 방법을 변경하고 싶은데, 기존 자격 증명을 변경하지 쉽지 않을 경우 
`DelegatingPasswordEncoder` 가 좋은 선택이 될 수 있다.

`DelegatingPasswordEncoder` 는 `PasswordEncoder` 인터페이스의 한 구현이며, 자체 인코딩 알고리즘을 구현하는 것이 아니라 같은 계약의 다른 구현 인스턴스에게 작업을 위임한다.

해시는 해당 해시를 의미하는 알고리즘의 이름을 나타내는 접두사로 시작하며, `DelegatingPasswordEncoder` 는 암호의 접두사를 기준으로 적절한 `PasswordEncoder` 구현에게 작업을 위임한다.

아래 그림을 보면 쉽게 이해할 수 있다.

![DelegatingPasswordEncoder](/assets/img/dev/2023/1119/delegating.png)

`DelegatingPasswordEncoder` 는 작업을 위임하는 `PasswordEncoder` 각 구현의 인스턴스를 맵에 저장한다.  
`NoOpPasswordEncoder` 에는 키 noop 가 할당되고, `BCryptPasswordEncoder` 에는 키 bcrypt 가 할당된다.  
암호에 접두사 _{noop}_ 이 있으면 `DeletePasswordEncoder` 는 작업을 `NoOpPasswordEncoder` 구현에게 위임한다.

예를 들어 해시가 아래와 같으면 접두사 _{bcrypt}_ 에 대해 할당한 `BCryptPasswordEncoder` 가 암호 인코더로 사용된다.
```shell
{bcrypt}$2fdsgfdsjgfkldjsgkfdxhgxlkkdlsgo4e
```

`DelegatingPasswordEncoder` 정의
```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.DelegatingPasswordEncoder;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.crypto.scrypt.SCryptPasswordEncoder;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class ProjectConfig {
  // ...
  // DelegatingPasswordEncoder 정의
  @Bean
  public PasswordEncoder passwordEncoder() {
    Map<String, PasswordEncoder> encoders = new HashMap<>();

    encoders.put("noop", NoOpPasswordEncoder.getInstance());
    encoders.put("bcrypt", new BCryptPasswordEncoder(4));
    encoders.put("scrypt", new SCryptPasswordEncoder(16384, 8, 1, 32, 64));

    // 만일 접두사가 없으면 BCryptPasswordEncoder 구현에 작업 위임
    return new DelegatingPasswordEncoder("bcrypt", encoders);
  }
}
```

스프링 시큐리티는 편의를 위해 `PasswordEncoderFactories` 클래스를 통해 모든 표준 제공 `PasswordEncoder` 의 구현에 대한 맵을 제공한다.  

```java
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;

// 기본 인코더는 bcrypt
PasswordEncoder passwordEncoder = PasswordEncoderFactories.createDelegatingPasswordEncoder();
```

---

## 1.4. 인코딩, 암호화, 해싱

- **인코딩**
  - **주어진 입력에 대한 모든 변환을 의미**
  - 예) 문자열을 뒤집은 함수 x 가 있을 때 x -> y 를 ABC 에 적용하면 CBA 가 나옴
- **암호화**
  - **출력을 얻기 위해 입력값과 키를 모두 지정**하는 특별한 유형의 인코딩
  - (x,k) -> y 에서 x 는 입력, k 는 키, y 는 엄호화 결과값
  - (y,k) -> x 는 역함수 복호화(Reverse Function Decryption) 이라고 함, 이렇게 암호화와 복호화에 쓰는 키가 같을 경우 **대칭키**라고 함
  - (x, k1) -> y, (y,k2) -> x 처럼 암호화와 복호화에 다른 키를 쓰면 **비대칭키**(Asymmetric Key)라고 함
  - 이 때 (k1, k2) 는 **Key Pair** 라고 함
  - 암호화에 이용되는 키인 k1 을 **공개키(public key)** 라고 하고, 복호화에 사용되는 k2 를 **개인키(private key)** 라고 함
- **해싱**
  - **함수가 한 방향으로만 작동**하는 특별한 유형의 인코딩
  - 해싱 함수가 x -> y 라면 일치 함수인 (x,y) -> boolean 도 있음
  - 해싱 함수는 임력에 임의의 값을 추가할 수도 있는데 (x,k) -> y 로 표현하며, 여기서 k 는 **Salt** 라고 함 

---

# 2. 스프링 시큐리티 암호화 모듈(SSCM, Spring Security Crypto Module) 의 추가 정보

스프링 시큐리티에서 제공하는 암복호화 함수와 키 생성 솔루선에 대해 알아본다.

`PasswordEncoder` 도 SSCM 의 일부분이며, SSCM 의 두 가지 필수 기능을 이용하는 방법에 대해 알아본다.

- 키 생성기
  - 해싱 및 암호화 알고리즘을 위한 키를 생성하는 객체
- 암호기
  - 데이터를 암복호화하는 객체

---

## 2.1. KeyGenerator

KeyGenerator 는 특정한 종류의 키를 생성하는 객체로서 암호화나 해싱 알고리즘에 필요하다.

애플리케이션에 다른 종속성을 추가하기 보다 스프링 시큐리티의 KeyGenerator 를 이용하는 것이 좋다.

`StringKeyGenerator` 와 `BytesKeyGenerator` 는 KeyGenerator 의 주요 인터페이스이며, 팩토리 클래스인 `KeyGenerators` 로 직접 키를 생성할 수도 있다.

---

## 2.1.1. `StringKeyGenerator`

일반적으로 `StringKeyGenerator` 의 결과물을 해싱 또는 암호화 알고리즘의 Salt 값으로 이용된다.

`StringKeyGenerator` 인터페이스
```java
package org.springframework.security.crypto.keygen;

public interface StringKeyGenerator {
  String generateKey();
}
```

아래는 `StringKeyGenerator` 의 인스턴스를 얻은 후 Salt 값을 가져오는 예시이다.
```java
import org.springframework.security.crypto.keygen.KeyGenerators;
import org.springframework.security.crypto.keygen.StringKeyGenerator;

public class KeyGenerator {
  // 8바이트 키를 생성하고 이를 16진수 문자열로 인코딩하여 문자열로 반환
  public String StringKeyGenerator() {
    StringKeyGenerator keyGenerator = KeyGenerators.string();
    String salt = keyGenerator.generateKey(); // 72710d5c28db1f92

    return salt;
  }
}
```

---

## 2.1.2. `BytesKeyGenerator`

`BytesKeyGenerator` 인터페이스
```java
package org.springframework.security.crypto.keygen;

public interface BytesKeyGenerator {
  // 키 길이(바이트 수)
  int getKeyLength();

  byte[] generateKey();
}
```

아래는 8바이트 길이의 키를 생성하는 예시이다.
```java
package com.assu.study.chap0401;

import org.springframework.security.crypto.keygen.BytesKeyGenerator;
import org.springframework.security.crypto.keygen.KeyGenerators;

public class KeyGenerator {
  public String BytesKeyGenerator() {
    BytesKeyGenerator keyGenerator = KeyGenerators.secureRandom();
    byte[] key = keyGenerator.generateKey();  // [B@66223d94

    // 기본 BytesKeyGenerator 는 8바이트 길이의 키를 생성함
    int keyLength = keyGenerator.getKeyLength();  // 8

    return null;
  }
}
```

만일 다른 길이의 키를 생성하고 싶으면 아래와 같이 원하는 값을 설정하면 된다.
```java
BytesKeyGenerator keyGenerator = KeyGenerators.secureRandom(16);
```

`KeyGenerators.secureRandom()` 메서드로 생성한 `BytesKeyGenerator` 는 `generateKey()` 가 호출될 때마다 고유한 키를 생성하는데, 
만일 같은 KeyGenerator 호출 시 같은 키를 반환하는 구현이 필요하면 아래와 같이 하면 된다.

```java
BytesKeyGenerator keyGenerator3 = KeyGenerators.shared(16);

// 아래 2개는 같은 값을 가짐
byte[] key3 = keyGenerator3.generateKey();
byte[] key4 = keyGenerator3.generateKey();
```

---

## 2.2. 암호화/복호화 작업에 암호기 사용

암호기는 암호화 알고리즘을 구현하는 객체이다.

> 암복호화는 보안을 위한 공통적인 기능이므로 애플리케이션에 이 기능이 필요한 가능성이 큼!

시스템 구성 요소 간에 데이터를 전송하거나 저장할 때 암호화가 필요한 경우가 많다.

이를 위해 SSCM 은 `BytesEncryptor`, `TextEncryptor` 를 제공한다.  
두 암호기의 역할은 비슷하지만 다른 데이터 형식을 처리한다.

---

### 2.2.1. `TextEncryptor`

`TextEncryptor`는 데이터를 문자열로 관리한다.

`TextEncryptor` 인터페이스
```java
package org.springframework.security.crypto.encrypt;

public interface TextEncryptor {
  String encrypt(String text);

  String decrypt(String encryptedText);
}
```

---

### 2.2.2. `BytesEncryptor`

`BytesEncryptor` 는 범용적이며, 바이트 배열을 관리한다.

`BytesEncryptor` 인터페이스
```java
package org.springframework.security.crypto.encrypt;

public interface BytesEncryptor {
  byte[] encrypt(byte[] byteArray);

  byte[] decrypt(byte[] encryptedByteArray);
}
```

---

### 2.2.3. 암호기 구현: `encryptors`

팩토리 클래스인 `Encryptors` 는 여러 암복호화를 제공하며, `BytesEncryptor` 는 `Encryptors.standard()`, `Encryptors.stronger()` 메서드를 이용할 수 있다.

```java
import org.springframework.security.crypto.encrypt.BytesEncryptor;
import org.springframework.security.crypto.encrypt.Encryptors;
import org.springframework.security.crypto.keygen.KeyGenerators;

public class CustomEncryptors {
  public void textEncryptor() {
    // StringKeyGenerator
    String salt = KeyGenerators.string().generateKey();

    String password = "password";
    String valueToEncrypt = "HELLO";

    BytesEncryptor encryptor = Encryptors.standard(password, salt);
    byte[] encrypted = encryptor.encrypt(valueToEncrypt.getBytes());
    byte[] decrypted = encryptor.decrypt(encrypted);
  }
}
```

- `Encryptors.stronger()`
  - standard() 보다 더 강력한 바이트 암호기 인스턴스 생성 시 사용 
  - 256바이트 AES 암호화를 이용하여 암호화 작업 모드로 GCM (갈루아/카운터 모드) 을 이용
- `Encryptors.standard()`
  - 256바이트 AES 암호화를 이용하여 암호화 작업 모드로 더 약한 방식인 CBC (암호 블록 체인) 를 이용

---

`TextEncryptor` 는 `Encryptor.text()`, `Encryptor.delux()` 메서드를 이용할 수 있다.  

`Encryptor.text()` 는 standard 버전이고, 좀 더 강력한 stronger 버전은 `Encryptor.delux()` 를 이용하여 인스턴스를 생성하면 된다.

```java
package com.assu.study.chap0401;

import org.springframework.security.crypto.encrypt.Encryptors;
import org.springframework.security.crypto.encrypt.TextEncryptor;
import org.springframework.security.crypto.keygen.KeyGenerators;

public class CustomEncryptors {
  public void customTextEncryptor() {
    // StringKeyGenerator
    String salt = KeyGenerators.string().generateKey();
    String password = "password";
    String valueToEncrypt = "HELLO";

    TextEncryptor encryptor = Encryptors.text(password, salt);
    String encrypted = encryptor.encrypt(valueToEncrypt); // fe8ecccfc913766c869fc41f2bb111046007029487bec447e92f36ce1d528406
    String decrypted = encryptor.decrypt(encrypted);  // HELLO
  }
}
```

이 외에도 암호화에 시간을 소비하지 않고 성능 테스트나 예제 확인 시에 사용할 수 있게 값을 암호화하지 않는 더미 TextEncryptor 를 반환하는 `Encryptor.noOpText()` 메서드도 있다.

```java
package com.assu.study.chap0401;

import org.springframework.security.crypto.encrypt.Encryptors;
import org.springframework.security.crypto.encrypt.TextEncryptor;
import org.springframework.security.crypto.keygen.KeyGenerators;

public class CustomEncryptors {
  public void customNoOpText() {
    // StringKeyGenerator
    String salt = KeyGenerators.string().generateKey();
    String valueToEncrypt = "HELLO";

    TextEncryptor encryptor = Encryptors.noOpText();
    String encrypted = encryptor.encrypt(valueToEncrypt); // HELLO

  }
}
```

---

# 마치며...

- 스프링 시큐리티는 해싱 알고리즘에 여러 대안을 제공하므로 필요한 구현을 선택하기만 하면 됨
- SSCM 에는 KeyGenerator 와 암호기를 구현하는 여러 대안이 있음
- KeyGenerator 는 암호화 알고리즘에 이용되는 키를 생성하는 유틸리티 객체
- 암호기는 데이터 암복호화를 수행하는 유틸리티 객체

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 로렌티우 스필카 저자의 **스프링 시큐리티 인 액션**을 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 시큐리티 인 액션](https://www.jetbrains.com/help/idea/markdown.html#floating-toolbar)