---
layout: post
title:  "Clean Architecture - 테스트"
date: 2024-05-26
categories: dev
tags: clean test
---

[2.1. 데이터베이스 주도 설계를 유도](https://assu10.github.io/dev/2024/05/06/clean-basic/#21-%EB%8D%B0%EC%9D%B4%ED%84%B0%EB%B2%A0%EC%9D%B4%EC%8A%A4-%EC%A3%BC%EB%8F%84-%EC%84%A4%EA%B3%84%EB%A5%BC-%EC%9C%A0%EB%8F%84) 에서 
계층형 아키텍처는 영속성 계층에 의존하게 되어 데이터베이스 주도 설계가 된다고 하였다.

이 포스트에서는 이러한 의존성을 역전시키기 위해 영속성 계층을 애플리케이션 계층의 플러그인으로 만드는 방법에 대해 살펴본다.

> 소스는 [github](https://github.com/assu10/clean-architecture/tree/feature/chap07)  에 있습니다.

---

**목차**

<!-- TOC -->
* [1. 테스트 피라미드](#1-테스트-피라미드)
* [2. 단위 테스트로 도메인 엔티티 테스트](#2-단위-테스트로-도메인-엔티티-테스트)
* [3. 단위 테스트로 유스케이스 테스트](#3-단위-테스트로-유스케이스-테스트)
* [4. 통합 테스트로 웹 어댑터 테스트](#4-통합-테스트로-웹-어댑터-테스트)
* [5. 통합 테스트로 영속성 어댑터 테스트](#5-통합-테스트로-영속성-어댑터-테스트)
* [6. 시스템 테스트로 주요 경로 테스트](#6-시스템-테스트로-주요-경로-테스트)
* [7. 테스트 정도?](#7-테스트-정도)
* [정리하며...](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

build.gradle
```groovy
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.3.2'
  id 'io.spring.dependency-management' version '1.1.6'
}

group = 'com.assu.study'
version = '0.0.1-SNAPSHOT'

java {
  toolchain {
    languageVersion = JavaLanguageVersion.of(17)
  }
}

compileJava {
  sourceCompatibility = 17
  targetCompatibility = 17
}

repositories {
  mavenCentral()
}

dependencies {
  compileOnly 'org.projectlombok:lombok'
  annotationProcessor 'org.projectlombok:lombok'

  implementation('org.springframework.boot:spring-boot-starter-web')
  implementation 'org.springframework.boot:spring-boot-starter-validation'
  implementation 'org.springframework.boot:spring-boot-starter-data-jpa'

  testImplementation('org.springframework.boot:spring-boot-starter-test') {
    exclude group: 'junit' // excluding junit 4
  }
  testImplementation 'org.junit.jupiter:junit-jupiter-engine:5.0.1'
  testImplementation 'org.junit.platform:junit-platform-launcher:1.4.2'
}

tasks.named('test') {
  useJUnitPlatform()
}
```

---

# 1. 테스트 피라미드

---

# 2. 단위 테스트로 도메인 엔티티 테스트

---

# 3. 단위 테스트로 유스케이스 테스트

---

# 4. 통합 테스트로 웹 어댑터 테스트

---

# 5. 통합 테스트로 영속성 어댑터 테스트

---

# 6. 시스템 테스트로 주요 경로 테스트

---

# 7. 테스트 정도?

---

# 정리하며...

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 톰 홈버그 저자의 **만들면서 배우는 클린 아키텍처**을 기반으로 스터디하며 정리한 내용들입니다.*

* [만들면서 배우는 클린 아키텍처](https://wikibook.co.kr/clean-architecture/)
* [책 예제 git](https://github.com/wikibook/clean-architecture)