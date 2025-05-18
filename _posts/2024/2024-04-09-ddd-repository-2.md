---
layout: post
title:  "DDD - 리포지터리(2): 애그리거트 로딩 전략, 애그리거트 영속성 전파"
date: 2024-04-09
categories: dev
tags: ddd 
---

- 애그리거트 로딩 전략과 영속성 전파
- 식별자 생성 기능

> 소스는 [github](https://github.com/assu10/ddd/tree/feature/chap04_01)  에 있습니다.

> 매핑되는 테이블은 [DDD - ERD](https://assu10.github.io/dev/2024/04/08/ddd-table/) 을 참고하세요.

---

**목차**

<!-- TOC -->
* [1. 애그리거트 로딩 전략](#1-애그리거트-로딩-전략)
* [2. 애그리거트의 영속성 전파](#2-애그리거트의-영속성-전파)
* [3. 식별자 생성 기능](#3-식별자-생성-기능)
  * [3.1. 사용자가 직접 생성](#31-사용자가-직접-생성)
  * [3.2. 도메인 로직으로 생성](#32-도메인-로직으로-생성)
  * [3.3. DB 를 이용한 일련번호 사용](#33-db-를-이용한-일련번호-사용)
* [4. 도메인 구현과 DIP](#4-도메인-구현과-dip)
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
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>
```

---

# 1. 애그리거트 로딩 전략

JPA 매핑을 설정할 때 중요한 점은 애그리거트에 속한 객체가 모두 모여야 완전한 하나가 된다는 것이다.

아래와 같이 애그리거트 루트를 로딩하면 루트에 속한 모든 객체가 완전한 상태이어야 한다.
```java
// product 는 완전한 하나이어야 함
Product product = productRepository.findById(id);
```

조회 시점에 애그리거트를 완전한 상태가 되게 하려면 애그리거트 루트에서 연관 매핑의 조회 방식을 즉시 로딩(`Fetch.EAGER`) 로 설정하면 된다.

아래와 같이 컬렉션이나 `@Entity` 에 대한 매핑의 `fetch` 속성을 `Fetch.EAGER` 로 설정하면 `EntityManager#find()` 메서드로 애그리거트 루트를 조회할 때 
연관된 구성 요소를 DB 에서 함께 읽어온다.

`@Entity` 컬렉션에 대한 즉시 로딩 설정
```java
@OneToMany(
        cascade = {CascadeType.PERSIST, CascadeType.REMOVE},    // Product 의 저장/삭제 시 함께 저장 삭제
        orphanRemoval = true,   // 리스트에서 Image 객체 제거 시 DB 에서도 함께 삭제
        fetch = FetchType.EAGER
)
@JoinColumn(name = "product_id")
@OrderColumn(name = "list_idx")
private List<Image> images = new ArrayList<>();
```

`@Embeddable` 컬렉션에 대한 즉시 로딩 설정
```java
@ElementCollection(fetch = FetchType.EAGER)  // 값 타입 컬렉션
@CollectionTable(name = "product_category",
        joinColumns = @JoinColumn(name = "product_id")) // 테이블명 지정
private Set<CategoryId> categoryIds;
```

이렇게 즉시 로딩 방식으로 설정하면 애그리거트 루트를 로딩하는 시점에 애그리거트에 속한 모든 객체를 함께 로딩하는 장점이 있지만 **컬렉션에 대해 로딩 전략을 
`Fetch.EAGER` 로 설정 시 오히려 문제**가 될 수 있다.

아래와 같이 _Product_ 애그리거트 루트가 `@Entity` 로 구현한 _Image_ 와 `@Embeddable` 로 구현한 _CategoryId_ 목록을 가지고 있다고 하자.

```java
@Entity
@Table(name = "product")
public class Product {
    @EmbeddedId
    private ProductId id;

    @ElementCollection(fetch = FetchType.EAGER)  // 즉시 로딩, 값 타입 컬렉션
    @CollectionTable(name = "product_category",
            joinColumns = @JoinColumn(name = "product_id")) // 테이블명 지정
    private Set<CategoryId> categoryIds;

    @OneToMany(
            cascade = {CascadeType.PERSIST, CascadeType.REMOVE},    // Product 의 저장/삭제 시 함께 저장 삭제
            orphanRemoval = true,   // 리스트에서 Image 객체 제거 시 DB 에서도 함께 삭제
            fetch = FetchType.EAGER // 즉시 로딩
    )
    @JoinColumn(name = "product_id")
    @OrderColumn(name = "list_idx")
    private List<Image> images = new ArrayList<>();
 
    // ...
}
```

위와 같이 설정 시 `EntityManager#find()` 메서드로 _Product_ 를 조회하면 하이버네이트는 아래와 같이 _Product_ 를 위한 테이블, _Image_ 를 위한 테이블, 
_CategoryId_ 를 위한 테이블을 조인한 쿼리를 실행한다.

```sql
select 
    p.product_id, ..,, img.product_id, ..., cat.category_id, cat.name 
from product p
     left outer join image img on p.product_id = img.product_id
     left outer join product_category cat on p.product_id = cat.product_id
where p.product_id = ?
```

위 쿼리의 결과는 중복을 발생시킨다.

만일 조회하는 _Product_ 의 image 가 2개이고, product_category 가 2개면 쿼리의 결과는 총 4개가 된다.  
product 테이블의 정보는 4번 중복되고, image, product_category 의 정보는 2번 중복된다.

하이버네이트가 중복된 데이터를 알맞게 제거해서 실제 메모리에는 1개의 _Product_ 객체, 각각 2개의 _Image_, _CategoryId_ 객체로 변환해주지만 
애그리거트가 커지면 문제가 될 수 있다.

**보통 조회 성능 문제 때문에 즉시 로딩 방식을 사용하지만 이렇게 조회되는 데이터 개수가 많아지면 즉시 로딩 방식을 사용할 때 실행 빈도, 트래픽, 지연 로딩 시 실행 속도 등 
성능을 검토**해봐야 한다.


**애그리거트는 개념적으로 하나이어야 하지만 루트 엔티티를 로딩하는 시점에 애그리거트에 속한 객체를 모두 로딩해야 하는 것은 아니다.**

<**애그리거트가 완전해야 하는 이유**>  
1. 상태를 변경하는 기능 실행 시 애그리거트 상태가 완전해야 함
2. 표현 영역에서 애그리거트의 상태 정보를 보여줄 때 필요함

위에서 2번째는 별도의 조회 전용 기능과 모델을 구현하는 방식을 사용하는 것이 더 유리하다.  
따라서 애그리거트의 완전한 로딩과 관련된 문제는 1번째 문제와 더 관련이 있다.

**상태 변경 기능을 실행하기 위해 조회 시점에 즉시 로딩을 이용해서 애그리거트를 완전한 상태로 로딩할 필요는 없다.**

**JPA 는 트랜잭션 범위 내에서 지연 로딩을 허용하기 때문에 아래처럼 실제로 상태를 변경하는 시점에 필요한 구성 요소만 로딩해도 문제없다.**

```java
@Transactional
public void removeCategories(ProductId id, int categoryIdxToBeDeleted) {
    // Product 로딩
    // 컬렉션은 지연 로딩으로 설정했다면 이 때 CategoryId 는 로딩하지 않음
    Product product = productRepository.findById(id);
    
    // 트랜잭션 범위이므로 지연 로딩으로 설정한 연관 로딩 가능
    product.removeCategory(categoryIdxToBeDeleted);
}
```

```java
@Entity
@Table(name = "product")
public class Product {
    @EmbeddedId
    private ProductId id;

    @ElementCollection(fetch = FetchType.LAZY)  // 값 타입 컬렉션
    @CollectionTable(name = "product_category",
            joinColumns = @JoinColumn(name = "product_id")) // 테이블명 지정
    private Set<CategoryId> categoryIds;

    public void removeCategory(int categoryIdx) {
        // 실제 컬렉션에 접근할 때 로딩됨
        this.categoryIds.remove(categoryIdx);
    }
}
```

일반적으로 애플리케이션은 상태 변경 기능을 실행하는 빈도보다 조회 기능을 실행하는 빈도가 훨씬 높기 때문에 상태 변경을 위해 지연 로딩을 사용할 때 발생하는 
추가 쿼리로 인한 실행 속도 저하는 보통 문제가 되지 않는다.

**따라서 애그리거트 내의 모든 연관을 즉시 로딩으로 설정할 필요는 없다.**

즉시 로딩은 `@Entity` 나 `@Embeddable` 에 대해 다르게 동작하고, JPA 프로바이더에 따라 구현 방식이 다를 수도 있어서 경우의 수를 따져봐야 하는데 
지연 로딩을 동작 방식이 항상 일정하므로 즉시 로딩처럼 경우의 수를 따질 필요가 없다.

하지만 지연 로딩은 즉시 로딩보다 쿼리 실행 횟수가 많아질 가능성도 있으므로 애그리거트에 맞게 즉시 로딩과 지연 로딩을 선택해야 한다.

---

# 2. 애그리거트의 영속성 전파

애그리거트가 완전한 상태이어야 한다는 것은 애그리거트 루트를 조회할 때 뿐 아니라 저장하고 삭제할 때도 애그리거트에 속한 모든 객체가 함께 저장되고 삭제되어야 한다는 것을 의미한다.

**`@Embeddable` 매핑 타입은 함께 저장되고 삭제되기 때문에 `cascade` 속성을 추가로 설정하지 않아도 된다.**

**애그리거트에 속한 `@Entity` 타입에 대한 매핑은 `cascade` 속성을 사용해서 저장과 삭제 시에 함께 처리되도록 설정**해야 한다.  
`@OneToMany`, `@OneToOne` 은 `cascade` 속성의 기본값이 없으므로 아래처럼 `CascadeType.PERSIST`, `CascadeType.REMOVE` 를 설정해주어야 한다.

```java
@OneToMany(
        cascade = {CascadeType.PERSIST, CascadeType.REMOVE},    // Product 의 저장/삭제 시 함께 저장 삭제
        orphanRemoval = true,   // 리스트에서 Image 객체 제거 시 DB 에서도 함께 삭제
        fetch = FetchType.LAZY
)
@JoinColumn(name = "product_id")
@OrderColumn(name = "list_idx")
private List<Image> images = new ArrayList<>();
```

---

# 3. 식별자 생성 기능

식별자는 크게 3가지 방식 중 하나로 생성한다.
- 사용자가 직접 생성
- 도메인 로직으로 생성
- DB 를 이용한 일련번호 사용

---

## 3.1. 사용자가 직접 생성

이메일 주소처럼 사용자가 직접 식별자를 입력하는 경우는 식별자 생성 주체가 사용자이므로 도메인 영역에 식별자 생성 기능을 구현할 필요가 없다.

---

## 3.2. 도메인 로직으로 생성

식별자 생성 규칙이 있다면 별도 서비스 식별자 생성 기능을 분리해야 한다.  
**식별자 생성 규칙은 도메인 규칙이므로 도메인 영역에 식별자 생성 기능을 위치**시켜야 한다.

```java
public class ProductIdService {
    public ProductId nextId() {
        // 정해진 규칙으로 식별자 생성
    }
}
```

응용 서비스는 위의 도메인 서비스를 이용해서 식별자를 구한 뒤 엔티티를 생성한다.

```java
@RequiredArgsConstructor
public class CreateProductService {
    @Transactional
    public ProductId createProduct(ProductCreationCommand cmd) {
        // 응용 서비스는 도메인 서비스를 이용하여 식별자 생성
        ProductId id = productIdService.nextId();
        
        Product product = new Product(id, cmd.getDetail(, ...));
        productRepository.save(product);
        
        return id;
    }
}
```

---

## 3.3. DB 를 이용한 일련번호 사용

DB 자동 증가 컬럼을 식별자로 사용하려면 식별자 매핑에서 `@GenerateValue` 를 사용하면 된다.

```java
@Entity
@Table(name = "article")
public class Article {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "article_id")
    private Long id;

    // ...
}
```

자동 증가 컬럼은 도메인 객체를 생성하는 시점에는 식별자를 알 수 없고, 도메인 객체를 저장한 뒤에 식별자를 구할 수 있다.
```java
@RequiredArgsConstructor
public class WriteArticleService {
    public Long write(newArticleRequest req) {
        Article article = new Article("title", new ArticleContent("content", "type");
        articleRepository.save(article);
        
        return article.getId(); // 저장 이후 식별자 사용 가능
    }
}
```

---

# 4. 도메인 구현과 DIP

[3. DIP (Dependency Inversion Principle, 의존관계 역전 원칙)](https://assu10.github.io/dev/2024/04/01/ddd-architecture/#3-dip-dependency-inversion-principle-%EC%9D%98%EC%A1%B4%EA%B4%80%EA%B3%84-%EC%97%AD%EC%A0%84-%EC%9B%90%EC%B9%99) 에서 DIP 에 대해 알아보았다.

하지만 지금까지 알아본 엔티티는 구현 기술인 JPA 에 특화된 `@Entity`, `@Table`, `@Id` 등의 애너테이션을 사용하고 있다.

```java
@Entity
@Table(name="article")
public class Article {
    @Id 
    private Long id;
}
```

DIP 에 따르면 `@Entity`, `@Table` 등은 구현 기술에 속하므로 _Article_ 과 같은 도메인 모델은 구현 기술인 JPA 에 의존하지 말아야 하는데 위 코드는 
도메인 모델인 _Article_ 이 영속성 구현 기술인 JPA 에 의존하고 있다.

리포지터리 인터페이스도 도메인 패키지에 위치하고 있는데 구현 기술인 스프링 데이터 JPA 의 Repository 인터페이스를 상속하고 있다.

즉, 도메인이 인프라에 의존하고 있다.

**DIP 를 적용하는 주된 이유는 저수준 구현이 변경되더라도 고수준이 영향을 받지 않도록 하기 위함**이다.  
하지만 리포지터리와 도메인 모델의 구현 기술은 거의 바뀌지 않는다.  
이렇게 변경이 거의 없는 상황에서 변경을 미리 대비하는 것은 과하기 때문에 애그리거트, 리포지터리 등 도메인 모델을 구현할 때는 개발 편의성과 실용성을 고려하여 어느 정도 타협하는 것이 좋다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 최범균 저자의 **도메인 주도 개발 시작하기**을 기반으로 스터디하며 정리한 내용들입니다.*

* [도메인 주도 개발 시작하기](https://www.yes24.com/Product/Goods/108431347)
* [책 예제 git](https://github.com/madvirus/ddd-start2)