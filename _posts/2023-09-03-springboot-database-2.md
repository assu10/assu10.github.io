---
layout: post
title:  "Spring Boot - 데이터 영속성(2): 엔티티 클래스 설계"
date:   2023-09-03
categories: dev
tags: springboot msa database entity enumerated mapped-super-class generationtype
---

이 포스트에서는 엔티티 클래스를 설정하여 테이블의 레코드와 매핑하는 방법에 대해 알아본다.

> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap08) 에 있습니다.

---

**목차**

- [엔티티 클래스와 `@Entity` 애너테이션](#1-엔티티-클래스와-entity-애너테이션)
- [엔티티 클래스 기본키 설정: `@Id`](#2-엔티티-클래스-기본키-설정-id)
  - [`GenerationType.TABLE`](#21-generationtypetable)
  - [`GenerationType.SEQUENCE`](#22-generationtypesequence)
  - [`GenerationType.IDENTITY`](#23-generationtypeidentity)
  - [`GenerationType.AUTO`](#24-generationtypeauto)
- [열거형과 `@Enumerated`](#3-열거형과-enumerated)
- [Date 클래스와 `@Temporal`](#4-date-클래스와-temporal)
- [엔티티 클래스 속성 변환과 AttributeConverter: `@Convert`, `@Converter`](#5-엔티티-클래스-속성-변환과-attributeconverter-convert-converter)
- [엔티티 클래스 상속과 `@MappedSuperClass`](#6-엔티티-클래스-상속과-mappedsuperclass)

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.4
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap08

![Spring Initializer](/assets/img/dev/2023/0902/init.png)

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

  <artifactId>chap08</artifactId>

  <dependencies>
    <!-- Spring Data JPA, Hibernate, aop, jdbc -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>

    <!-- mysql 관련 jdbc 드라이버와 클래스들 -->
    <!-- https://mvnrepository.com/artifact/com.mysql/mysql-connector-j -->
    <dependency>
      <groupId>com.mysql</groupId>
      <artifactId>mysql-connector-j</artifactId>
      <version>8.0.33</version>
    </dependency>
  </dependencies>

</project>
```

---

엔티티 클래스는 관계형 데이터베이스의 테이블과 매핑할 수 있는 클래스이다.  
JPA 가 쿼리를 실행한 결과인 레코드를 엔티티 객체에 매핑하며, JPA 에서는 엔티티 클래스는 정의하는 `@Entity` 애너테이션을 사용한다. 

---

# 1. 엔티티 클래스와 `@Entity` 애너테이션

`@Entity` 는 엔티티 클래스를 정의하는 기본 애너테이션이고, 엔티티 클래스 설계 시 아래의 애너테이션들이 사용된다.

- `@Entity`
  - 엔티티 클래스 선언
- `@Table`
  - 엔티티 클래스와 매핑할 테이블 설정
  - `name`: 테이블명 설정
  - `schema`: 스키마명 설정
  - `catalog`: 카탈로그명 설정
  - `uniqueConstraint`
    - 유니크 키 설정
    - 배열 설정 가능
  - `indexes`
    - 인덱스 설정
    - 배열 설정 가능
- `@Column`
  - 테이블의 필드를 엔티티 클래스의 속성과 매핑
  - `name`: 필드명 설정
  - `unique`: 유니크 설정 여부에 따라 true/false
  - `nullable`: null 가능 여부에 따라 true/false
  - 이 외에도 다양한 추가 속성이 있음
- `@Transient`
  - 엔티티 클래스의 속성을 테이블의 필드와 매핑하지 않을 때 사용
  - 해당 필드를 영속 대상에서 제외
  - `value`: 동작 여부 설정
  - `value` 의 기본값이 true 이므로 `@Transient` 애너테이션만 사용해도 필드와 매핑되지 않음
  - 좀 더 자세한 내용은 [JPA에서 @Transient 애노테이션이 존재하는 이유](https://gmoon92.github.io/jpa/2019/09/29/what-is-the-transient-annotation-used-for-in-jpa.html) 참고
- `@Id`
  - 테이블의 기본키를 엔티티 클래스의 속성으로 설정
  - 애너테이션 속성값이 없기 때문에 애너테이션만 정의하면 됨
  - 기본키를 생성하는 방식은 `@GeneratedValue` 와 함께 사용됨
- `@GeneratedValue`
  - 기본키는 생성하는 방법 설정
  - `strategy` 와 `generator` 속성이 있음
  - 좀 더 자세한 설명은 [엔티티 클래스 기본키 설정](#2-엔티티-클래스-기본키-설정) 를 참고하세요.

---

<**엔티티 클래스 작성 시 유의할 점**>  
- 엔티티 클래스에는 `@Entity` 애너테이션을 반드시 정의
- 엔티티 클래스는 인자가 없는 기본 생성자가 반드시 필요, 그리고 기본 생성자는 public 혹은 protected 접근 제어자로 정의되어야 함
- 엔티티 클래스는 final 제어자를 사용하여 정의하면 안되며, 메서드나 속성들도 final 로 정의하면 안됨
- enum, interface, inner class 는 엔티티 클래스가 될 수 없음
- 엔티티 클래스의 속성은 private, protected 접근 제어자로 정의되어야 하며, 엔티티 클래스의 getter() 로 접근

---

/domain/HotelEntity.java
```java
package com.assu.stury.chap08.domain;

import jakarta.persistence.*;
import lombok.Getter;

//@NoArgsConstructor
@Entity
@Getter
@Table(name = "hotels", indexes = @Index(name = "INDEX_NAME_STATUS", columnList = "name asc, status asc"))
public class HotelEntity extends AbstractManageEntity {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "hotel_id")
  private Long hotelId;
  
  @Column(name = "status")
  private HotelStatus status;
  
  @Column
  private String name;
  
  @Column
  private String address;
  
  @Column(name = "phone_number")
  private String phoneNumber;
  
  @Column(name = "room_count")
  private Integer roomCount;

  // 반드시 AbstractManageEntity 의 생성자를 호출해야 함
  public HotelEntity() {
    super();
  }

  public static HotelEntity of(String name, String address, String phoneNumber, Integer roomCount) {
    HotelEntity hotelEntity = new HotelEntity();

    hotelEntity.name = name;
    hotelEntity.status = HotelStatus.READY;
    hotelEntity.address = address;
    hotelEntity.phoneNumber = phoneNumber;
    hotelEntity.roomCount = roomCount;

    return hotelEntity;
  }
}
```

`spring.jpa.hibernate.ddl-auto` 즉, 스키마 자동 설정 전략을 create 나 create-drop 사용 시 엔티티 클래스에 의해 DDL 이 생성된다.  
이럴 때는 `@Table` 애너테이션의 indexes 나 uniqueConstraints 는 반드시 정의하고 관리해야 하지만, 스키마 자동 설정을 사용하지 않는 전략이라면 스키마를 
생성할 때 사용하는 속성들은 생략해도 좋다.

/domain/HotelStatus.java
```java
package com.assu.stury.chap08.domain;

import java.util.Arrays;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

public enum HotelStatus {
  // 내부에 Integer value 속성이 있음
  // HotelStatus 의 value 는 데이터베이스의 값으로 변환할 때 사용하는 열거형의 속성임
  OPEN(1), CLOSED(-1), READY(0);

  // Map 의 key 는 HotelStatus 열거형의 value 로, Map 의 value 는 HotelStatus 의 상수로 저장
  // 빠르게 변환하고자 static 구문으로 클래스가 로딩될 때 Map 객체를 미리 생성함
  private static final Map<Integer, HotelStatus> valueMap = Arrays.stream(HotelStatus.values())
          .collect(Collectors.toMap(HotelStatus::getValue, Function.identity()));
  private final Integer value;

  HotelStatus(Integer value) {
    this.value = value;
  }

  // 테이블에 저장된 value 값을 사용하여 열거형 상수로 변경할 때 사용할 메서드
  // value 와 매칭되는 열거형 상수를 valueMap 에서 받아와 리턴함
  public static HotelStatus fromValue(Integer value) {
    if (value == null) {
      throw new IllegalArgumentException("value is null");
    }
    return valueMap.get(value);
  }

  public Integer getValue() {
    return value;
  }
}
```

> 위 예시에서 상속하고 있는 AbstractManageEntity 클래스는 [6. 엔티티 클래스 상속과 `@MappedSuperClass`](#6-엔티티-클래스-상속과-mappedsuperclass) 에서 다룹니다.

Java 에서 제공하는 기본 클래스인 String, Integer, Long 등은 자동으로 테이블의 필드에 변환되어 저장되지만 사용자가 정의한 클래스 타입, 열거형, Date, Calendar 클래스는 별도의 추가 설정이 필요하다.

각각 [3. 열거형과 `@Enumerated`](#3-열거형과-enumerated), [4. Date 클래스와 `@Temporal`](#4-date-클래스와-temporal), [5. 엔티티 클래스 속성 변환과 AttributeConverter](#5-엔티티-클래스-속성-변환과-attributeconverter) 에서 그 내용을 참고할 수 있다.

---

# 2. 엔티티 클래스 기본키 설정: `@Id`

기본키를 생성하는 방법은 크게 2 가지가 있다.

- 애플리케이션에서 고유한 값을 생성하여 직접 할당
- 데이터베이스에서 제공하는 자동 채번 기능을 사용하여 할당

애플리케이션에서 고유한 값을 생성하여 직접 할당하는 경우는 `@Id` 애너테이션 외에 추가 설정이 필요없지만,  
데이터베이스의 채번 기능을 사용하는 경우는 엔티티 클래스에 추가 애너테이션을 사용하여 정의가 필요하다.

---

## 2.1. `GenerationType.TABLE`

데이터베이스에 별도 키를 생성하는 전용 케이블을 만들고, 레코드를 생성할 때마다 채번 테이블에서 채번한 값을 기본키로 사용한다.    
로직으로 기본키를 생성하기 때무넹 데이터베이스에 독립적인 방법이다.

> 관련 애너테이션: `@TableGenerator`

---

## 2.2. `GenerationType.SEQUENCE`

데이터베이스에서 제공하는 시퀀스 기능을 사용하여 기본키를 사용한다.  
데이터베이스 기능에 의존적인 방법이며, Oracle, PostgreSQL, DB2 등에서 사용할 수 있다.

---

## 2.3. `GenerationType.IDENTITY`

데이터베이스에서 제공하는 자동 증가 기능으로 키본키를 사용한다.  
데이터베이스 기능에 의존적인 방법이며, MySQL, PostgreSQL, SQL Server, DB2, Derby, Sybase 등에서 사용할 수 있다.

```java
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
@Column(name = "hotel_id")
private Long hotelId;
```

---

## 2.4. `GenerationType.AUTO`

`@GeneratedValue` 의 `strategy` 속성 기본값이다.  
데이터베이스에 따라 적절한 키 생성 전략을 매핑한다.

Oracle 을 사용한다면 GenerationType.SEQUENCE 방식으로 매핑하고, MySQL 을 사용한다면 GenerationType.IDENTITY 방식으로 매핑한다.  

데이터베이스 종류에 의존하지 않고 데이터베이스에서 제공하는 채번 기능을 사용하여 매핑할 때 유용하다.

---

# 3. 열거형과 `@Enumerated`

열거형을 위한 데이터베이스의 데이터 타입은 없다.  
따라서 VARCHAR, CHAR 같은 문자열 타입이나 INT 같은 숫자형 데이터 타입으로 설정된 필드에 열거형을 변환하여 저장해야 한다.

JPA 에서는 열거형을 쉽게 변환할 수 있는 `@Enumerated` 애너테이션을 제공한다.  
`@Enumerated` 의 `value` 속성은 javax.persistence.EnumType 값을 설정할 수 있으며, 기본값은 EnumType.ORDINAL 이다.

HotelEntity.java
```java
@Entity
@Getter
@Table(name = "hotels")
public class HotelEntity extends AbstractManageEntity {
  @Column
  @Enumerated(value = EnumType.STRING)
  private HotelStatus status;
  
  // ...

  public enum HotelStatus {
    OPEN, CLOSED, READY
  }
}
```

EnumType 은 ORDINAL 과 STRING 이 있다.  

위처럼 EnumType.STRING 으로 설정할 경우 데이터베이스에 저장 시 'OPEN' 이라는 문자열로 변환되어 저장된다.

만일 EnumType.ORDINAL 로 설정 시 데이터베이스에 저장 시 숫자로 변환되어 저장된다.  
EnumType.ORDINAL 은 열거형 상수들을 순서대로 사용하여 숫자로 변환하는데 위에선 OPEN 은 1, CLOSED 는 2, READY 는 3 으로 저장된다.  

만일 OPEN 과 CLOSED 사이에 다른 값이 필요하여 넣게 되는 경우 CLOSED 는 3, READY 는 4 로 변경이 되기 때문에 기본값인 EnumType.ORDINAL 로 열거형을 
변환하는 경우 상수들의 순서가 매우 중요하다.

따라서 **EnumType.ORDINAL 은 변화에 취약하기 때문에 사용하지 않는 것이 좋다.**  
`@Enumerated` 애너테이션을 사용하게 된다면 EnumType.STRING 을 사용하는 것을 권고한다.

`@Enumerated` 보다는 [5. 엔티티 클래스 속성 변환과 AttributeConverter](#5-엔티티-클래스-속성-변환과-attributeconverter-convert-converter) 에 나오는 AttributeConverter 가 
데이터를 변환하는 과정을 개발자가 직접 처리할 수 있어 명시적으로 프로그래밍 가능하기 하다.

---

# 4. Date 클래스와 `@Temporal`

java.util.Date, java.util.Calendar, java.time 패키지에 포함된 시간 관련 클래스들을 엔티티 클래스 속성으로 이용한다면 `@Temporal` 애너테이션을 사용하여 데이터베이스 필드값으로 변환할 수 있다.

> java.util.Date, java.util Calendar 사용은 추천하지 않는다.  
> 이에 대한 자세한 내용은 [Java8 - 날짜와 시간](https://assu10.github.io/dev/2023/07/29/java8-datetime/) 을 참고하세요.

java.time 패키지에 포함된 시간 클래스들은 AttributeConverter 를 사용해서 변환한다.  

---

# 5. 엔티티 클래스 속성 변환과 AttributeConverter: `@Convert`, `@Converter`

`@Temporal` 애너테이션은 java.util.Date 와 java.util.Calendar 클래스 타입 속성에서만 유효하다.

java.time 패키지에 포함된 LocalDateTime 같은 날짜 관련 클래스는 `@Temporal` 애너테이션이 아닌 다른 방법을 사용하여 변환할 수 있다.

java.time 패키지에 포함된 날짜 클래스들은 자바 스펙 요구서(JSR, Java Specification Request) JSR-310 으로 Java 8 부터 추가되었다.  
JSR-310 스펙으로 추가된 자바 클래스들은 JPA 에서 제공하는 속셩 변환 기능(AttributeConverter) 기능을 사용하여 변환한다.

> AttributeConverter 는 날짜 클래스를 포함하여 모든 클래스 변환 가능

JPA 는 속성 변환 기능을 위해  `@Convert` 와 `@Converter` 애너테이션과 `AttributeConverter` 인터페이스를 제공한다.  
개발자는 AttributeConverter 인터페이스를 구현하여 엔티티 객체 속성을 어떻게 데이터베이스 값으로 변환할 지 개발하고, 그 반대도 같이 구현한다.  

AttributeConverter 구현 클래스가 `@Convert` 와 `@Converter` 애너테이션을 사용하여 JPA/Hibernate 프레임워크에 등록하면  
이 후 엔티티 객체를 데이터베이스에 저장하거나 조회할 때 JPA/Hibernate 가 AttributeConverter 구현체를 사용하여 데이터를 변환한다.

Spring Data JPA 프레임워크는 JSR-310 클래스들을 변환하기 위해 o.s.data.convert 패키지의 Jsr310JpaConverters 클래스를 제공하는데 
클래스 내부에는 LocalDateTimeConverter, LocalTimeConverter 와 같은 이너 클래스들이 정의되어 있다.  
이 이너 클래스들은 AttributeConverter 인터페이스를 구현하고 있으며 이 구현체들이 데이터를 변환하는 역할을 한다.

Jsp310JpaConverters.java 일부
```java
package org.springframework.data.jpa.convert.threeten;

public class Jsr310JpaConverters {
  @jakarta.persistence.Converter(
          autoApply = true
  )
  // 2 개의 제네틱 타입 인자를 받음
  // 첫 번째 타입 인자는 엔티티 클래스의 속성 클래스 타입이고, 두 번째 타입 인자를 테이블 필드의 데이터 타입
  public static class LocalDateTimeConverter implements AttributeConverter<LocalDateTime, Date> {
    public LocalDateTimeConverter() {
    }

    // 엔티티 클래스의 속성값을 데이터베이스에 적합한 데이터로 변환
    // LocalDateTime 을 Date 로 변환
    @Nullable
    public Date convertToDatabaseColumn(LocalDateTime date) {
      return date == null ? null : LocalDateTimeToDateConverter.INSTANCE.convert(date);
    }

    // 데이터베이스에 저장된 데이터를 엔티티 객체의 속성으로 변환
    // Date 를 LocalDateTime 으로 변환
    @Nullable
    public LocalDateTime convertToEntityAttribute(Date date) {
      return date == null ? null : DateToLocalDateTimeConverter.INSTANCE.convert(date);
    }
  }
}
```

---

AttributeConverter 를 사용하면 `@Enumerated` 애너테이션 대신 열거형 클래스의 상수값을 데이터베이스에 변환하여 저장할 수 있다.  
`@Enumerated` 애너테이션은 EnumType.ORDINAL 혹은 EnumType.STRING 으로만 데이터를 변환할 수 있는 반면, AttributeConverter 는 어떤 값이라도 변환할 수 있다.  
운영 도중 열거형 상수의 위치나 이름을 바꾸는 리팩토링을 해도 다른 값이나 변환되거나 값이 변환되지 않는 상황을 방지할 수 있다.

---

/domain/HotelStatus.java  
> [1. 엔티티 클래스와 `@Entity` 애너테이션](#1-엔티티-클래스와-entity-애너테이션) 참고

/domain/converter/HotelStatusConverter.java
```java
package com.assu.stury.chap08.domain.converter;

import com.assu.stury.chap08.domain.HotelStatus;
import jakarta.persistence.AttributeConverter;

import java.util.Objects;

public class HotelStatusConverter implements AttributeConverter<HotelStatus, Integer> {

  // 데이터베이스에서 사용할 데이터로 변환
  // HotelStatus 의 value 값을 리턴하는 getValue() 리턴
  @Override
  public Integer convertToDatabaseColumn(HotelStatus attribute) {
    if (Objects.isNull(attribute)) {
      return null;
    }
    return attribute.getValue();
  }

  // 데이터베이스에 저장된 값을 HotelStatus 열거형으로 변환
  // 데이터베이스에 저장된 Integer 값과 매핑되는 HotelStatus 상수를 리턴하는 fromValue() 리턴
  @Override
  public HotelStatus convertToEntityAttribute(Integer dbData) {
    if (Objects.isNull(dbData)) {
      return null;
    }
    return HotelStatus.fromValue(dbData);
  }
}
```

---

AttributeConverter 구현 클래스를 작성했으면 JPA/Hibernate 프레임워크에 구현한 컨버터 클래스를 등록해야 한다.  
하지만 JPA/Hibernate 는 스프링 프레임워크의 서브 프로젝트가 아니기때문에 AttributeConverter 를 스프링 빈으로 등록해도 애플리케이션에서 사용할 수 없다.  

이 때 구현 클래스를 등록하기 위해 JPA 에서 제공하는 `@Convert` 와 `@Converter` 애너테이션을 사용한다.

**`@Convert` 애너테이션은 엔티티 클래스 속성에 직접 정의해서 사용**하기 때문에 적용 범위는 엔티티 클래스의 특정 속성에만 적용할 수 있다.

/domain/HotelEntity.java
```java
public class HotelEntity extends AbstractManageEntity {
  // ...
  
  @Column
  @Convert(converter = HotelStatusConverter.class)
  private HotelStatus status;
  
  // ...
}
```

만일 HotelStatus 열거형을 여러 엔티티 클래스에서 사용하고 있고, 사용된 모든 속성을 같은 방식으로 변환한다면 `@Converter` 애너테이션을 고려해볼 수 있다.  
`@Converter` 애너테이션은 애플리케이션 내부에 있는 모든 엔티티 클래스 속성에 일괄 적용이 가능하다.

즉, `@Converter` 는 전체 설정이고, `@Convert` 는 특정 엔티티 설정이다.


Jsp310JpaConverters.java 일부
```java
package org.springframework.data.jpa.convert.threeten;

public class Jsr310JpaConverters {
  @jakarta.persistence.Converter(
          autoApply = true  // 애플리케이션 전체에 글로벌 설정
  )
  public static class LocalDateTimeConverter implements AttributeConverter<LocalDateTime, Date> {
  }// ...
}
```

---

# 6. 엔티티 클래스 상속과 `@MappedSuperClass`

엔티티 클래스도 자바 클래스이기 때문에 다른 클래스처럼 상속이 가능하다.  

엔티티 클래스는 `@Entity` 나 `@MappedSuperClass` 로 정의된 클래스만 상속받을 수 있다.

감사 목적으로 생성자, 생성일시, 수정자, 수정일시를 공통적으로 적용하고 싶을 때 사용하면 유용하다.

아래는 `@MappedSuperClass` 를 사용하여 엔티티 클래스를 상속받는 예시이다.

/domain/AbstractManageEntity.java
```java
package com.assu.stury.chap08.domain;

import com.assu.stury.chap08.server.UserIdHolder;
import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;

import java.time.ZonedDateTime;

@Slf4j
@MappedSuperclass // 상속할 수 있도록 애너테이션 정의
@Getter
// 단독으로 매핑되는 테이블이 없으므로 영속할 수 없다.
// 따라서 abstract 제어자를 사용하여 클래스가 단독으로 생성되는 상황을 막는다.
public abstract class AbstractManageEntity {
  @Column(name = "created_at")
  private final ZonedDateTime createdAt;

  @Column(name = "created_by")
  private final String createdBy;

  @Column(name = "modified_at")
  private ZonedDateTime modifiedAt;

  @Column(name = "modified_by")
  private String modifiedBy;

  public AbstractManageEntity() {
    this.createdAt = ZonedDateTime.now();
    this.createdBy = UserIdHolder.getUserId();
  }
}
```

/domain/HotelEntity.java
```java
// AbstractManageEntity 를 상속받으므로 createdAt, createdBy, modifiedAt, modifiedBy 를 구현할 필요가 없다.
public class HotelEntity extends AbstractManageEntity {
  // ...

  // 반드시 AbstractManageEntity 의 생성자를 호출해야 함
  public HotelEntity() {
    super();
  }
}
```

/server/UserIdHolder.java
```java
package com.assu.stury.chap08.server;

public class UserIdHolder {
  private static final ThreadLocal<String> threadLocalUserId = new ThreadLocal<>();

  public static String getUserId() {
    return threadLocalUserId.get();
  }

  public static void setUserId(String userId) {
    threadLocalUserId.set(userId);
  }

  public static void unset() {
    threadLocalUserId.remove();
  }
}
```

/server/UserIdInterceptor.java
```java
package com.assu.stury.chap08.server;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.servlet.HandlerInterceptor;

@Slf4j
public class UserIdInterceptor implements HandlerInterceptor {
  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
    String userId = request.getHeader("user-id");
    UserIdHolder.setUserId(userId);

    return true;
  }

  @Override
  public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) throws Exception {
    UserIdHolder.unset();
  }
}
```

config/WebConfig/java
```java
package com.assu.stury.chap08.config;

import com.assu.stury.chap08.server.UserIdInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Bean
  public UserIdInterceptor userIdInterceptor() {
    return new UserIdInterceptor();
  }

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    registry.addInterceptor(userIdInterceptor());
  }
}
```

> addInterceptors() 에 대한 좀 더 상세한 내용은 [Spring Boot - 웹 애플리케이션 구축 (1): WebMvcConfigurer 를 이용한 설정, DispatcherServlet 설정](https://assu10.github.io/dev/2023/08/05/springboot-application-1/#125-addinterceptors) 를 참고하세요.

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **스프링 부트로 개발하는 MSA 컴포넌트**를 기반으로 스터디하며 정리한 내용들입니다.*

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [hibernate 6.2 공홈](https://docs.jboss.org/hibernate/orm/6.2/)
* [JPA에서 @Transient 애노테이션이 존재하는 이유](https://gmoon92.github.io/jpa/2019/09/29/what-is-the-transient-annotation-used-for-in-jpa.html)