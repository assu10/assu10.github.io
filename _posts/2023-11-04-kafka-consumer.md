---
layout: post
title:  "Kafka - 카프카 프로듀서"
date:   2023-11-04
categories: dev
tags: kafka kafka-producer
---

이 포스트에서는 카프카에 쓰여진 메시지를 읽기 위한 클라이언트에 대해 알아본다.

---

**목차**


---

**개발 환경**

- mac os
- openjdk 17.0.9
- zookeeper 3.8.3
- apache kafka: 3.6.1 (스칼라 2.13.0 에서 실행되는 3.6.1 버전)

---

# 1. 프로듀서

---

# 2. 프로듀서 생성

---

# 3. 카프카로 메시지 전달

---

## 3.1. 동기적으로 메시지 전달

---

## 3.2. 비동기적으로 메시지 전달

---

# 4. 프로듀서 설정

---

## 4.1. `client.id`

---

## 4.2. `acks`

---

## 4.3. 메시지 전달 시간

---

## 4.4. `linger.ms`

---

## 4.5. `buffer.memory`

---

## 4.6. `compression.type`

---

## 4.7. `batch.size`

---

## 4.8. `max.in.flight.requests.per.connection`

---

## 4.9. `max.request.size`

---

## 4.10. `receive.buffer.bytes`, `send.buffer.bytes`

---

## 4.11. `enable.idempotence`

---

# 5. 시리얼라이저

---

## 5.1. 커스텀 시리얼라이저

---

## 5.2. 아파치 에이브로 사용하여 직렬화

---

## 5.3. 카프카에서 에이브로 레코드 사용

---

# 6. 파티션

---

## 6.1. 커스텀 파티셔너 구현

---

# 7. 헤더

---

# 8. 인터셉터

---

# 9. 쿼터, 스로틀링

---

# 정리하며...

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 김병부 저자의 **O'REILLY 카프카 핵심 가이드 2판**를 기반으로 스터디하며 정리한 내용들입니다.*

* [카프카 핵심 가이드](https://www.yes24.com/Product/Goods/118397432)
* [예제 코드 & 오탈자](https://dongjinleekr.github.io/kafka-the-definitive-guide-v2/)