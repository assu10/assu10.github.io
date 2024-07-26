---
layout: post
title:  "Java8 - Stream 으로 데이터 수집 (2): Quiz"
date: 2023-06-19
categories: dev
tags: java java8 stream collectors-class
---

[Java8 - Stream 으로 데이터 수집 (2): Partitioning, Collector 인터페이스, Custom Collector](https://assu10.github.io/dev/2023/06/17/java8-stream-3-1/) 의
_1. 분할: `partitioningBy()`_ 과 관련된 퀴즈 포스트입니다.

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap06) 에 있습니다.

---

숫자를 소수와 비소수로 분할하기

정수 n 을 입력받아 2~n 까지의 자연수를 소수와 비소수로 나눈다.

---

### 주어진 n 이 소수인지 판단하는 Predicate 구현

```java
private static boolean isPrime(int candidate) {
    // 소수의 대상은 주어진 수의 제곱근 이하로 제한
    int candidateRoot = (int) Math.sqrt((double) candidate);
        return IntStream.rangeClosed(2, candidateRoot)
                  .noneMatch(i -> candidate % i == 0);
}
```

### partitioningBy() 컬렉터로 리듀스해서 소수와 비소수 분류
위의 isPrime() 을 Predicate 로 이용한다.

```java
private static Map<Boolean, List<Integer>> partitionPrimes(int n) {
return IntStream.rangeClosed(2, n)  // IntStream 반환
        .boxed()  // Stream<Integer> 반환
        .collect(
                partitioningBy(i -> isPrime(i))
        );
}
```

```shell
System.out.println("Primes and NonPrime: " + partitionPrimes(10));

// Primes and NonPrime: {false=[4, 6, 8, 9, 10], true=[2, 3, 5, 7]}
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)