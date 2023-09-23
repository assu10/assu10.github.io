---
layout: post
title:  "Spring Boot - 웹 애플리케이션 구축 (1): 기본 설정, HttpMessageConverter, Interceptor, ServletFilter"
date:   2023-08-05
categories: dev
tags: springboot msa HttpMessageConverter ObjectMapper
---

이 포스팅에서는 아래 내용에 대해 알아본다. 

- 실행 환경(dev, prod) 에 따라 스프링 애플리케이션 설정
- 국제화(i18n) 기능
- 에러 메시지를 사용자의 언어별로 응답
- 실제 운영에 필요한 로그 설정, 패키징, 배포


> 소스는 [github](https://github.com/assu10/msa-springboot-2/tree/feature/chap06) 에 있습니다.

---

**목차**

- Interceptor, ServletFilter 설정
  - HandlerInterceptor 인터페이스
  - Filter 인터페이스

---

**개발 환경**

- 언어: java
- Spring Boot ver: 3.1.0
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Maven
- Group: com.assu.study
- Artifact: chap05

![Spring Initializer](/assets/img/dev/2023/0805/init.png)

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

	<artifactId>chap06</artifactId>

</project>
```

---


---

# 2. Interceptor, ServletFilter 설정

---

## 2.1. HandlerInterceptor 인터페이스

---

## 2.2. Filter 인터페이스

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [스프링 부트로 개발하는 MSA 컴포넌트](https://www.yes24.com/Product/Goods/115306377)
* [Spring Boot 공홈](https://spring.io/projects/spring-boot)
* [LocalDate datesUntil](https://ntalbs.github.io/2020/java-date-practice/)