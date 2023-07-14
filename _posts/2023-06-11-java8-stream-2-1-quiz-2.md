---
layout: post
title:  "Java8 - Stream 활용 (2): Quiz (2)"
date:   2023-06-11
categories: dev
tags: java java8 stream fibonacci
---

[Java8 - Stream 활용 (2): 리듀싱, 숫자형 스트림, 스트림 생성](https://assu10.github.io/dev/2023/06/10/java8-stream-2-1/#34-함수로-무한-스트림-생성) 의
_3.4. 함수로 무한 스트림 생성_ 과 관련된 퀴즈 포스팅입니다.

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap05) 에 있습니다.

---

피보나치 수열과 피보나치 수열 집합 구하기

> 피보나치 수열  
> 첫째 및 둘째 항이 1이며 그 뒤의 모든 항은 바로 앞 두 항의 합인 수열이다.    
> 0,1,1,2,3,5,8,13,21,...
> 처음 여섯 항은 각각 1, 1, 2, 3, 5, 8이다.  
> 편의상 0번째 항을 0으로 두기도 한다.

피보나치 수열 집합: (0,1), (1,1), (1,2), (2,3), (3,5)...

T -> T 의 함수 디스크립터를 갖는 UnaryOperator\<T\> 를 인수로 받는 Stream.iterate() 를 이용한다.  
(0,1) 과 같은 집합을 만든 후 이것을 초기값으로 사용한다.
```java
new int[]{0,1}
```

> UnaryOperator\<T\> 에 관련된 내용은 [Java8 - 람다 표현식 (1): 함수형 인터페이스, 형식 검사](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/) 의 _2.4. 기본형(primitive type) 특화_ 를 참고하세요.

---

# 피보나치 수열 집합 (Stream.iterate())
```java
Stream.iterate(new int[]{0,1}, t -> new int[]{t[1], t[0]+t[1]})
        .limit(20)
        .forEach(t -> System.out.println("(" + t[0] + "," + t[1] + ")"));
```

```shell
(0,1)
(1,1)
(1,2)
(2,3)
(3,5)
...
```

---

# 피보나치 수열 (Stream.iterate())
```java
List<Integer> fib = Stream.iterate(new int[]{0,1}, t -> new int[]{t[1], t[0]+t[1]})
        .limit(10)
        .map(t -> t[0])
        .collect(Collectors.toList());

// [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
System.out.println(fib);
```

---

# 피보나치 수열 (Stream.generate())

기존의 수열 상태를 저장하고, getAsInt() 로 다음 요소를 계산할 수 있도록 IntSupplier 를 만들어야 함

```java
IntSupplier fib2 = new IntSupplier() {
  private int previous = 0;
  private int current = 1;
  @Override
  public int getAsInt() { // 객체 상태가 바뀌며 새로운 값 생상d
    int oldPrevious = this.previous;
    int nextValue = this.previous + this.current;
    this.previous = this.current;
    this.current = nextValue;

    return oldPrevious;
  }
};

IntStream fib2Stream = IntStream.generate(fib2)
        .limit(10);

fib2Stream.forEach(System.out::println);
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)