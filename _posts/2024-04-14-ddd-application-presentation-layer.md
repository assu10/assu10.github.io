---
layout: post
title:  "DDD - "
date:   2024-04-14
categories: dev
tags: ddd 
---

이 포스트에서는 아래 내용에 대해 알아본다.

- 응용(application) 서비스 구현
- 표현(presentation) 영역의 역할
- 값 검증과 권한 검사

> 소스는 [github](https://github.com/assu10/ddd/tree/feature/chap06)  에 있습니다.

> 매핑되는 테이블은 [DDD - ERD](https://assu10.github.io/dev/2024/04/08/ddd-table/) 을 참고하세요.

---

**목차**

<!-- TOC -->
* [1. 표현 영역과 응용 영역](#1-표현-영역과-응용-영역)
* [2. 응용 서비스의 역할](#2-응용-서비스의-역할)
  * [2.1. 도메인 로직 넣지 않기](#21-도메인-로직-넣지-않기)
* [3. 응용 서비스 구현](#3-응용-서비스-구현)
  * [3.1. 응용 서비스의 크기](#31-응용-서비스의-크기)
  * [3.2. 응용 서비스의 인터페이스와 클래스](#32-응용-서비스의-인터페이스와-클래스)
  * [3.3. 메서드 파라메터와 값 리턴](#33-메서드-파라메터와-값-리턴)
  * [3.4. 표현 영역에 의존하지 않기](#34-표현-영역에-의존하지-않기)
  * [3.5. 트랜잭션 처리](#35-트랜잭션-처리)
* [4. 표현 영역](#4-표현-영역)
* [5. 값 검증](#5-값-검증)
* [6. 권한 검사](#6-권한-검사)
* [7. 조회 전용 기능과 응용 서비스](#7-조회-전용-기능과-응용-서비스)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.2.5
- Spring ver: 6.1.6
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven

---

pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.5</version>
    <relativePath/> <!-- lookup parent from repository -->
  </parent>
  <groupId>com.assu</groupId>
  <artifactId>ddd_me</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>ddd</name>
  <description>Demo project for Spring Boot</description>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <scope>annotationProcessor</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <!-- https://mvnrepository.com/artifact/org.hibernate/hibernate-jpamodelgen -->
    <dependency>
      <groupId>org.hibernate</groupId>
      <artifactId>hibernate-jpamodelgen</artifactId>
      <version>6.5.2.Final</version>
      <type>pom</type>
      <!--            <scope>provided</scope>-->
    </dependency>
    <!-- https://mvnrepository.com/artifact/com.mysql/mysql-connector-j -->
    <dependency>
      <groupId>com.mysql</groupId>
      <artifactId>mysql-connector-j</artifactId>
      <version>8.4.0</version>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-devtools</artifactId>
      <scope>runtime</scope>
    </dependency>

  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
      <plugin>
        <groupId>org.bsc.maven</groupId>
        <artifactId>maven-processor-plugin</artifactId>
        <version>2.0.5</version>
        <executions>
          <execution>
            <id>process</id>
            <goals>
              <goal>process</goal>
            </goals>
            <phase>generate-sources</phase>
            <configuration>
              <processors>
                <processor>org.hibernate.jpamodelgen.JPAMetaModelEntityProcessor</processor>
              </processors>
            </configuration>
          </execution>
        </executions>
        <dependencies>
          <dependency>
            <groupId>org.hibernate</groupId>
            <artifactId>hibernate-jpamodelgen</artifactId>
            <version>6.5.2.Final</version>
          </dependency>
        </dependencies>
      </plugin>
    </plugins>
  </build>

</project>

```

```properties
spring.application.name=ddd
spring.datasource.url=jdbc:mysql://localhost:13306/shop?characterEncoding=utf8
spring.datasource.username=root
spring.datasource.password=
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.datasource.hikari.maximum-pool-size=10
spring.jpa.database=mysql
spring.jpa.show-sql=true
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.jpa.open-in-view=false
logging.level.root=INFO
logging.level.com.myshop=DEBUG
logging.level.org.springframework.security=DEBUG
```

---

# 1. 표현 영역과 응용 영역

![아키텍처 구성](/assets/img/dev/2024/0331/architecture.png)

위 그림과 같이 사용자에게 기능을 제공하려면 도메인과 사용자를 연결해 줄 표현 영역과 응용 영역이 필요하다.

표현 영역은 사용자의 요청을 해석한다.  
사용자가 요청한 요청 파라메터를 포함한 HTTP 요청을 표현 영역에 전달하면 표현 영역은 사용자가 실행하고 싶은 기능을 판별하여 응용 서비스가 요구하는 형식으로 사용자 요청을 
변환하여 그 기능을 제공하는 응용 서비스를 실행한다.

즉, 사용자가 원하는 기능을 제공하는 것은 응용 영역에 위치한 서비스이다.

사용자와의 상호 작용은 표현 영역이 처리하므로 응용 서비스는 표현 영역에 의존하지 않는다.

---

# 2. 응용 서비스의 역할

---

## 2.1. 도메인 로직 넣지 않기

---

# 3. 응용 서비스 구현

---

## 3.1. 응용 서비스의 크기

---

## 3.2. 응용 서비스의 인터페이스와 클래스

---

## 3.3. 메서드 파라메터와 값 리턴

---

## 3.4. 표현 영역에 의존하지 않기

---

## 3.5. 트랜잭션 처리

---

# 4. 표현 영역

---

# 5. 값 검증

---

# 6. 권한 검사

---

# 7. 조회 전용 기능과 응용 서비스


---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [책 예제 git](https://github.com/madvirus/ddd-start2)