---
layout: post
title:  "Java8 - Stream 활용 (2): Quiz (1)"
date:   2023-06-11
categories: dev
tags: java java8 stream
---

[Java8 - Stream 활용 (2): 리듀싱, 숫자형 스트림, 스트림 생성](https://assu10.github.io/dev/2023/06/10/java8-stream-2-1/) 과 관련된 퀴즈 포스트입니다.

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap05) 에 있습니다.

---

거래자: Trader / 트랜잭션: Transaction

Trader 클래스
```java
public class Trader {
  private String name;
  private String city;

  public Trader(String n, String c){
    this.name = n;
    this.city = c;
  }

  public String getName(){
    return this.name;
  }

  public String getCity(){
    return this.city;
  }

  public void setCity(String newCity){
    this.city = newCity;
  }

  public String toString(){
    return "Trader:"+this.name + " in " + this.city;
  }
}
```

Transaction 클래스
```java
public class Transaction {
  private Trader trader;
  private int year;
  private int value;

  public Transaction(Trader trader, int year, int value)
  {
    this.trader = trader;
    this.year = year;
    this.value = value;
  }

  public Trader getTrader(){
    return this.trader;
  }

  public int getYear(){
    return this.year;
  }

  public int getValue(){
    return this.value;
  }

  public String toString(){
    return "{" + this.trader + ", " +
            "year: "+this.year+", " +
            "value:" + this.value +"}";
  }
}
```

Trader 와 Transaction 리스트
```java
Trader raoul = new Trader("Raoul", "Cambridge");
Trader mario = new Trader("Mario","Milan");
Trader alan = new Trader("Alan","Cambridge");
Trader brian = new Trader("Brian","Cambridge");

List<Transaction> transactions = Arrays.asList(
        new Transaction(brian, 2011, 300),
        new Transaction(raoul, 2012, 1000),
        new Transaction(raoul, 2011, 400),
        new Transaction(mario, 2012, 710),
        new Transaction(mario, 2012, 700),
        new Transaction(alan, 2012, 950)
);
```

---

### 1. 2011 에 일어난 모든 트랜잭션을 찾아 값을 오름차순으로 정리

```java
List<Transaction> transaction2011 = transactions.stream()
                .filter(tr -> tr.getYear() == 2011)
                .sorted(Comparator.comparing(Transaction::getValue))
                .collect(Collectors.toList());

// [{Trader:Brian in Cambridge, year: 2011, value:300}, {Trader:Raoul in Cambridge, year: 2011, value:400}]
System.out.println(transaction2011);
```

---

### 2. 거래자가 근무하는 모든 도시를 중복없이 나열

```java
List<String> distictCity = transactions.stream()
        .map(tr -> tr.getTrader().getCity())
        .distinct()
        .collect(Collectors.toList());

// [Cambridge, Milan]
System.out.println(distictCity);
```

---

### 3. 케임브리지에서 근무하는 모든 거래자를 찾아서 이름순으로 정렬

```java
List<Trader> cambridgeTraders = transactions.stream()
        .map(Transaction::getTrader)
        .filter(tr -> tr.getCity().equals("Cambridge"))
        .distinct()
        .sorted(Comparator.comparing(Trader::getName))
        .collect(Collectors.toList());

// [Trader:Alan in Cambridge, Trader:Brian in Cambridge, Trader:Raoul in Cambridge]
System.out.println(cambridgeTraders);
```

---

### 4. 모든 거래자의 이름을 알파벳순으로 정렬하여 String 으로 반환

```java
String traderNames2 = transactions.stream() // Stream<Transaction> 반환
    .map(tr -> tr.getTrader().getName())  // Stream<String> 반환
    .distinct()
    .sorted()
    .reduce("", (n1, n2) -> n1 + n2);

// AlanBrianMarioRaoul
System.out.println(traderNames2);
```

반복 과정에서 모든 문자열을 반복적으로 연결해서 새로운 문자열 객체를 만들기때문에 효율적이지 못하다.

```java
String traderNames3 = transactions.stream() // Stream<Transaction> 반환
    .map(tr -> tr.getTrader().getName())  // Stream<String> 반환
    .distinct()
    .sorted()
    .collect(Collectors.joining());
```

joining() 은 내부적으로 StringBuilder 를 이용한다.

---

### 5. 밀라노에 거주자가 있는지?

```java
boolean isMilan = transactions.stream()
        .anyMatch(tr -> tr.getTrader()// Trader 반환
                .getCity()  // String 반환
                .equals("Milan"));
// true
System.out.println(isMilan);
```

---

### 6. 케임브리지에 거주하는 거래자의 모든 트랜잭션값 출력

```java
transactions.stream()
            .filter(tr -> tr.getTrader().getCity().equals("Cambridge"))
            .map(Transaction::getValue) //Stream<Integer> 반환
            .forEach(System.out::println);
    // 300
    //1000
    //400
    //950
```

---

### 7. 전체 트랜잭션 중 최대값은?

```java
Optional<Integer> max = transactions.stream()
            .map(Transaction::getValue)
            .reduce(Integer::max);

// Optional[1000]
System.out.println(max);
```

---

### 8. 전체 트랜잭션 중 최소값은?

```java
Optional<Transaction> min2 = transactions.stream()
        .min(Comparator.comparing(Transaction::getValue));

// Optional[{Trader:Brian in Cambridge, year: 2011, value:300}]
System.out.println(min2);
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)