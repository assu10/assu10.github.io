---
layout: post
title:  "Java8 - CompletableFuture (1): Future, 병렬화 방법"
date: 2023-07-22
categories: dev
tags: java java8 completable-future
---

- 비동기 작업 생성 후 결과 조회
- Non-block 으로 생산성 높이기
- 비동기 API 설계 및 구현
- 동기 API 를 비동기적으로 소비

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap11) 에 있습니다.

---

**목차**  

<!-- TOC -->
* [1. `Future`](#1-future)
  * [1.1. `Future` 의 한계점과 `CompletableFuture`](#11-future-의-한계점과-completablefuture)
* [2. 동기 API 구현](#2-동기-api-구현)
  * [2.1. 동기 메서드를 비동기 메서드로 변환](#21-동기-메서드를-비동기-메서드로-변환)
  * [2.2. 에러 처리: `completeExceptionally()`](#22-에러-처리-completeexceptionally)
    * [2.2.1. Factory 메서드 `supplyAsync()` 로 `CompletableFuture` 생성](#221-factory-메서드-supplyasync-로-completablefuture-생성)
* [3. Non-block 코드](#3-non-block-코드)
  * [3.1. 병렬 스트림으로 요청 병렬화](#31-병렬-스트림으로-요청-병렬화)
  * [3.2. `CompletableFuture` 로 비동기 호출 구현](#32-completablefuture-로-비동기-호출-구현)
  * [3.3. 확장성 더하기](#33-확장성-더하기)
  * [3.4. 커스텀 `Executor` 사용](#34-커스텀-executor-사용)
  * [3.5. 스트림 병렬화와 `CompletableFuture`](#35-스트림-병렬화와-completablefuture)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

애플리케이션을 구축하다 보면 다중 소스로부터 콘텐츠를 모으고 처리해서 최종 사용자에게 제공하게 된다.

외부 네트워크 서비스의 반응 속도가 느릴 수도 있으므로 빈 화면이나 검은 화면을 보여주는 것보다는 부분 결과라도 먼저 보여주는 것이 좋다.  
예) 서버 응답을 기다리는 동안 검은 화면보다는 텍스트 결과와 함께 아직 위치 정보를 얻지 못했음을 알려주는 물음표 노출

서비스 응답을 기다리는 동안 다른 연산들이 블록되면서 수많은 CPU 사이클을 낭비하는 것은 비효율적이다.  
예) A 서비스의 데이터가 도착할 때까지 기다리는 동안 B 서비스에서 도착한 데이터 처리를 미루는 것은 비효율적

이 상황은 멀티태스크 프로그래밍의 두 가지 특징인 병렬성과 동시성을 잘 보여준다.  
[포크/조인 프레임워크](https://assu10.github.io/dev/2023/06/24/java8-parallel-stream-1/)와 병렬 스트림으로 병렬화를 할 수 있다.
이 두 가지를 이용해서 하나의 동작을 여러 서브 동작으로 분할하여 각각의 서브 동작을 다른 코어/CPU 로 할당할 수 있다.

반면, 병렬성이 아닌 동시성을 이용해야 하는 상황(= 하나의 CPU 사용을 가장 극대화할 수 있도록 느슨하게 연관된 여러 작업을 수행)이라면 원격 서비스 결과를 기다리거나
데이터베이스 결과를 기다리면서 스레드가 블록되는 것은 비효율적이다.

`Future` 인터페이스와 이를 구현하는 `CompletableFuture` 클래스를 이용해서 동시성 문제를 해결할 수 있다.

![동시성과 병렬성 차이](/assets/img/dev/2023/0722/concurrency.png)

---

# 1. `Future`

Java 5 부터 미래의 어느 시점에 결과를 얻는 모델에 활용할 수 있도록 `Future` 인터페이스를 제공한다.  
비동기 계산을 모델링하는데 `Future` 를 이용할 수 있으며, `Future` 는 계산이 끝났을 때 결과에 접근할 수 있는 레퍼런스를 제공한다.
시간이 걸릴 수 있는 작업을 `Future` 내부로 설정하면 호출자 스레드가 결과를 기다리는 동안 다른 작업을 수행할 수 있다.

`Future` 를 이용하려면 시간이 오래 걸리는 작업을 Callable 객체 내부로 감싼 후 ExecutorService 에 제출해야 한다.

아래는 Java 8 이전의 예시이다.

Future 로 오래 걸리는 작업을 비동기로 실행 (Java 8 이전)
```java
// 스레드 풀에 태스크를 제출하려면 ExecutorService 를 생성해야 함
ExecutorService executor = Executors.newCachedThreadPool();

// Callable 을 ExecutorService 로 제출
Future<Double> future = executor.submit(new Callable<Double>() {
  public Double call() {
    // 시간이 오래 걸리는 작업은 다른 스레드에서 비동기적으로 실행
    return doSomeLongComputation();
  }
});

// 비동기 작업을 수행하는 동안 다른 작업 수행
doSomethingElse();

try {
  // 비동기 작업의 결과 조회
  // 결과가 준비되어 있지 않으면 호출 스레드가 블록됨, 하지만 1초까지만 기다림 
  Double result = future.get(1, TimeUnit.SECONDS);  
} catch (ExecutionException ee) {
  // 계산 중 예외 발생
} catch (InterruptedException ie) {
  // 현재 스레드에서 대기 중 인터럽트 발생
} catch (TimeoutException te) {
  // Future 가 완료되기 전에 타임아웃 발생
}
```

오래 걸리는 작업이 영원히 끝나지 않을 수도 있으므로 get() 메서드를 오버로드해서 우리 스레드가 대기할 최대 타임아웃 시간을 설정하는 것이 좋다. 

---

## 1.1. `Future` 의 한계점과 `CompletableFuture`

`Future` 인터페이스가 비동기 계산이 끝났는지 확인할 수 있는 isDone() 메서드, 계산이 끝나길 기다리는 메서드, 결과 회수 메서드 등에 대해 알아볼 것이다.  
하지만 이 메서드들 만으로 동시 실행 코드를 구현하기엔 부족하다.  
예를 들어 오래 걸리는 A 의 계산이 끝나면 그 결과를 다른 오래 걸리는 B 로 전달하는 등의 의존성 표현을 어렵다.

이럴 땐 아래와 같은 기능이 필요하다.

- 두 개의 비동기 계산을 하나로 합침
  - 두 개의 계산 결과는 독립적일 수도 있고, 두 번째 계산의 결과가 첫 번째 계산의 결과에 의존할 수도 있음
- `Future` 집합이 실행하는 모든 태스크의 완료를 기다림
- `Future` 집합에서 가장 빨리 완료되는 태스크를 기다렸다가 결과를 얻음
  - 즉, 여러 태스크가 다양한 방식으로 같은 결과를 구하는 상황
- 프로그램적으로 `Future` 를 완료시킴 (= 비동기 동작에 수동으로 결과 제공)
- `Future` 완료 동작에 반응 (= 결과를 기다리면서 블록되는 것이 아니라 결과가 준비되었다는 알림을 받은 후 `Future` 의 결과로 원하는 추가 동작 수행)

---

이 포스트에서는 위 기능을 선언형으로 이용할 수 있도록 Java 8 에서 제공하는 `CompletableFuture` 클래스 (= `Future` 인터페이스를 구현한 클래스) 에 대해 알아본다.

`CompletableFuture` 는 람다 표현식과 파이프라이팅을 활용하기 때문에 Stream 과 비슷한 패턴이다.  
`Future` 와 `CompletableFuture` 의 관계를 Collection 과 Stream 의 관계에 비유할 수 있다.

이 포스트에서는 여러 온라인 상점 중 가장 저렴한 가격을 제시하는 상점을 찾는 기능을 구현해가면서 `CompletableFuture` 에 대해 알아본다.

- 비동기 API 구현
- 동기 API 를 사용해야 할 때 코드를 Non-block 으로 만드는 방법
  - 두 개의 비동기 동작을 파이프라인으로 만드는 방법과 두 개의 동작 결과를 하나의 비동기 계산으로 합치기
- 비동기 동작의 완료에 대응하는 방법
  - 모든 상점에서 가격 정보를 얻을 때까지 기다리는 것이 아니라 각 상점에서 가격 정보를 얻을 때마다 즉시 최저가를 찾는 애플리케이션을 갱신

---

# 2. 동기 API 구현

아래는 각 상점에서 제공해야 하는 API 정의이다.
```java
public class Shop {

  // 제품명에 해당하는 가격 반환
  public double getPrice(String product) {
    // TODO
    return 1;
  }
}
```

아래는 오래 걸리는 작업을 흉내내는 메서드이다.
```java
public class Util {

  private static final DecimalFormat formatter =
          new DecimalFormat("#.##", new DecimalFormatSymbols(Locale.US));

  // 외부 서비스를 호출하는 것처럼 인위적으로 1초 지연시키는 메서환
  public static void delay() {
    int delay = 1000;
    try {
      Thread.sleep(delay);
    } catch (InterruptedException e) {
      throw new RuntimeException(e);
    }
  }

  public static double format(double number) {
    synchronized (formatter) {
      return Double.valueOf(formatter.format(number));
    }
  }
}
```

이제 delay() 를 이용해서 지연을 흉내낸 후 임의의 계산값을 반환하도록 getPrice() 메서드를 다시 구현한다.

```java
private static final Random random = new Random(0);

// 제품명에 해당하는 가격 반환
public double getPrice(String product) {
  // TODO
  return 1;
}

private double calculatePrice(String product) {
  Util.delay();
  return random.nextDouble() * product.charAt(0) + product.charAt(1);
}
```

이제 이 API 를 호출하게 되면 동작이 완료될 때까지 1초 동안 블록이 진행된다. (비효율적)

---

## 2.1. 동기 메서드를 비동기 메서드로 변환

이제 위 동기 메서드를 비동기로 변환헤보자.

Future 는 결과값의 핸들일 뿐이며 계산이 완료되면 get() 메서드로 결과를 얻을 수 있다.  
getPriceAsync() 메서드는 즉시 반환되므로 호출자 스레드는 다른 작업 수행이 가능하다.

```java
public class AsyncShop {
  private final Random random;
  private final String name;

  public AsyncShop(String name) {
    this.name = name;
    random = new Random(name.charAt(0) * name.charAt(1) * name.charAt(2));
  }

  public Future<Double> getPriceAsync(String product) {
    // 계산 결과를 포함할 CompletableFuture 생성
    CompletableFuture<Double> future = new CompletableFuture<>();

    new Thread(
            () -> {
              // 다른 스레드에서 비동기적으로 계산 수행
              double price = calculatePrice(product);
              // 계산이 완료되면 Future 에 값 설정
              future.complete(price);
            })
            .start();

    // 계산 결과가 완료되길 기다리지 않고 Future 반환
    return future;
  }

  private double calculatePrice(String product) {
    Util.delay();
    return random.nextDouble() * product.charAt(0) + product.charAt(1);
  }
}
```

위 코드에서 비동기 계산과 완료 결과를 포함하는 CompletableFuture 인스턴스를 만들었다.  
그리고 가격을 계산할 다른 스레드를 생성한 후 결과를 기다리지 않고 결과를 포함할 Future 인스턴스를 바로 반환했다.
요청한 가격 정보가 도착하면 complete() 메서드를 이용해서 CompletableFuture 를 종료할 수 있다.

클라이언트는 아래처럼 getPriceAsync() 를 활용하면 된다.

```java
import java.util.concurrent.Future;

public class AsyncShopClient {
  public static void main(String[] args) {
    AsyncShop shop = new AsyncShop("assuShop");
    long start = System.nanoTime();

    // 상점에 가격 정보 요청
    Future<Double> futurePrice = shop.getPriceAsync("my product");
    long invocationTime = ((System.nanoTime() - start) / 1_000_000);

    System.out.println("Invocation returned after " + invocationTime + " ms");

    // assuShop 의 가격을 계산하는 동안 다른 작업 수행
    doSomeThingElse();

    try {
      // 가격 정보가 있으면 Future 에서 가격 정보를 읽고, 없으면 가격 정보를 받을 때까지 블록
      double price = futurePrice.get();
      System.out.println("Price: " + Util.format(price));
      // System.out.printf("Price is %.2f%n", price);
    } catch (Exception e) {
      throw new RuntimeException(e);
    }

    long retrievalTime = ((System.nanoTime() - start) / 1_000_000);
    System.out.println("Price returned after " + retrievalTime + "ms");
  }

  private static void doSomeThingElse() {
    Util.delay();
    System.out.println("doSomeThingElse...");
  }
}
```

```shell
Invocation returned after 4 ms
doSomeThingElse...
Price: 195.56
Price returned after 1025ms
```

클라이언트는 특정 제품의 가격 정보를 상점에 요청하고, 상점은 비동기 API 를 제공하므로 즉시 Future 를 반환한다. 
클라이언트는 반환된 Future 를 이용해서 나중에 결과를 얻을 수 있다.  
그 사이에 클라이언트는 첫 번째 상점의 결과를 기다리면서 대기하지 않고 다른 작업을 처리한다.  
나중에 클라이언트가 할 일이 없을 때 Future 의 get() 를 호출해서 결과값이 있으면 값을 읽고, 결과값이 없으면 있을 때까지 블록한다.

> [Java8 - CompletableFuture (2): 비동기 연산의 파이프라인화](https://assu10.github.io/dev/2023/07/23/java8-completableFuture-2/) 의 _1. 비동기 작업 파이프라인_ 에서 에서는 클라이언트가 블록되는 상황을 회피하는 법에 대해 알아본다.  
즉, 블록하지 않고 Future 의 작업이 끝났을 때만 이를 통지받으면서 람다 표현식이나 메서드 레퍼런스로 정의된 콜백 메서드를 실행한다.

---

## 2.2. 에러 처리: `completeExceptionally()`

위 코드에서 만일 가격을 계산하는 동안 에러가 발생하게 되면 해당 스레드에만 영향을 미치기 때문에 클라이언트는 get() 메서드가 반환될 때까지 영원히 기다리게 될 수도 있다.

이 때 클라이언트는 타임아웃값을 받는 get() 메서드의 오버로드를 만들어서 타임아웃 시간이 지나면 TimeoutException 을 받는 것이 좋다.

하지만 그래도 왜 에러가 발생했는지 알 수는 없다.  
이 때 `completeExceptionally()` 를 이용해서 CompletableFuture 내부에서 발생한 예외를 클라이언트로 전달하면 예외 내용을 알 수 있다.

```java
public Future<Double> getPriceAsync(String product) {
  // 계산 결과를 포함할 CompletableFuture 생성
  CompletableFuture<Double> future = new CompletableFuture<>();

  new Thread(
          () -> {
            try {
              // 다른 스레드에서 비동기적으로 계산 수행
              double price = calculatePrice(product);
              // 계산이 완료되면 Future 에 값 설정
              future.complete(price);
            } catch (Exception e) {
              // 도중에 에러 발생 시 에러를 포함시켜서 Future 종료
              future.completeExceptionally(e);
            }
          })
      .start();

  // 계산 결과가 완료되길 기다리지 않고 Future 반환
  return future;
}
```

---

### 2.2.1. Factory 메서드 `supplyAsync()` 로 `CompletableFuture` 생성

위에서 CompletableFuture 를 만들어보았는데 factory 메서드인 `supplyAsync()` 로 좀 더 간단하게 CompletableFuture 를 만들 수 있다.

```java
public Future<Double> getPriceAsync(String product) {
  return CompletableFuture.supplyAsync(() -> calculatePrice(product));
}
```

위 코드는 [2.2. 에러 처리: `completeExceptionally()`](#22-에러-처리-completeexceptionally) 정확히 동일하게 동작한다. (= 둘 다 같은 방식으로 에러 관리)

`supplyAsunc()` 메서드는 [Supplier](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 인수로 받아서 CompletableFuture 를 반환하고, CompletableFuture 는 Supplier 를 실행해서 비동기적으로 결과를 생성한다.

ForkJoinPool 의 Executor 중 하나가 Supplier 를 실행하게 될텐데 두 번째 인수를 받는 오버로드 버전의 supplyAsync() 를 이용해서 다른 Executor 를 지정할 수도 있다.  
결국 모든 다른 CompletableFuture 의 factory 메서드에 Executor 를 선택적으로 전달할 수 있는데 이 부분은 [3.4. 커스텀 Executor 사용](#34-커스텀-executor-사용) 에서 알아본다.

---

이제 앞으로 모든 API 는 동기 방식의 블록 메서드라고 가정할 것이다.  
블록 메서드를 사용할 수 밖에 없는 상황에서 비동기적으로 여러 상점에 질의하는 방법(= 한 요청의 응답을 기다리며 블록하는 상황을 피해 최저 가격 검색의 성능을 높이는 방법)에 대해
알아본다.

---

# 3. Non-block 코드

```java
public class BestPriceFinder {
  private final List<Shop> shops =
      Arrays.asList(
          new Shop("BestPrice"),
          new Shop("CoolPrice"),
          new Shop("SeventeenPrice"),
          new Shop("TXTPrice"));

  // 제품명 입력 시 상점 이름과 제품가격 반환
  public List<String> findPrices(String product) {
    return shops.stream()
        .map(shop -> String.format("%s price is %.2f", shop.getName(), shop.getPrice(product)))
        .collect(Collectors.toList());
  }
}
```

이제 위 메서드의 결과와 성능을 확인해본다.

```java
private static BestPriceFinder bestPriceFinder = new BestPriceFinder();

public static void main(String[] args) {
  execute("basic", () -> bestPriceFinder.findPrices("CoolPrice"));
}

private static void execute(String msg, Supplier<List<String>> s) {
  long start = System.nanoTime();
  System.out.println(s.get());
  long duration = (System.nanoTime() - start) / 1_000_000;
  System.out.println(msg + " done in " + duration + " ms");
}
```

```shell
[BestPrice price is 112.39, CoolPrice price is 171.64, SeventeenPrice price is 140.72, TXTPrice price is 112.25]
basicdone in 4025 ms
```

4개의 상점에서 가격을 검색하는 동안 각각 1초의 대기시간이 걸려서 전체 결과는 4초보다 조금 더 걸린다. 

이제 성능을 개선해보자.

---

## 3.1. 병렬 스트림으로 요청 병렬화

```java
// 병렬 스트림으로 요청 병렬화
public List<String> findPricesParallel(String product) {
  return shops.parallelStream()
      .map(shop -> String.format("%s price is %.2f", shop.getName(), shop.getPrice(product)))
      .collect(Collectors.toList());
}
```

```java
execute("findPricesParallel", () -> bestPriceFinder.findPricesParallel("CoolPrice"));
```

```shell
[BestPrice price is 157.81, CoolPrice price is 170.19, SeventeenPrice price is 173.38, TXTPrice price is 111.58]
findPricesParalleldone in 1008 ms
```

4개의 상점이 병렬로 검색이 진행되기 때문에 1초 남짓의 시간이 걸린다.

이제 `CompletableFuture` 기능을 활용해서 동기 호출을 비동기 호출로 변경하여 좀 더 성능을 개선해보자.

---

## 3.2. `CompletableFuture` 로 비동기 호출 구현

factory 메서드인 `supplyAsync()` 를 이용하여 CompletableFuture 를 생성해보자.

```java
// 동기 호출을 비동기 호출로 구현
public List<CompletableFuture<String>> findPricesFuture(String product) {
  return shops.stream()
      .map(
          shop ->
              CompletableFuture.supplyAsync(
                  () -> String.format("%s price is %2.f", shop.getName(), shop.getPrice())))
      .collect(Collectors.toList());
}
```

위 코드는 CompletableFuture 를 포함하는 리스트인 List\<CompletableFuture\<String\>\> 을 리턴한다.  
리스트의 CompletableFuture 는 각각 계산 결과가 끝난 상점의 이름 문자열을 포함한다.  

하지만 우리가 개선하고 있는 findPricesXXX() 의 반환 형식은 List\<String\> 이다.

두 번째 map() 연산을 추가하여 List\<CompletableFuture\<String\>\> 에 적용할 수 있다. 리스트의 모든 CompletableFuture 에 `join()` 을 호출해서 모든 동작이 끝나길 기다린 후 리턴할 수 있다.  
CompletableFuture 의 `join()` 은 Future 인터페이스의 `get()` 메서드와 같은 의미를 갖는데 다른 점은 아무 예외로 발생시키지 않는다는 점이다.  
따라서 두 번째 map() 의 람다 표현식을 try/catch 로 감싸지 않아도 된다.

```java
// 동기 호출을 비동기 호출로 구현
public List<String> findPricesFuture(String product) {
  List<CompletableFuture<String>> priceFutures =
      shops.stream()
          .map(
              shop ->
                  CompletableFuture.supplyAsync(
                      () -> String.format("%s price is %.2f", shop.getName(), shop.getPrice(product))))
          .collect(Collectors.toList());

  return priceFutures.stream()
      .map(CompletableFuture::join) // 모든 비동기 동작이 끝나길 기다림
      .collect(Collectors.toList());
}
```

두 개의 map() 연산을 하나의 스트림 파이프라인이 아닌 두 개의 스트림 파이프라인으로 처리했다는 것을 주목해야 한다.  
스트림 연산은 게으른 특성이 있어서 하나의 파이프라인으로 연산을 처리했다면 모든 가격 정보 요청이 동기적, 순차적으로 이루어지는 결과가 된다.  
CompletableFuture 로 각 상점의 정보를 요청할 때 기존 요청 작업이 완료되어야 join() 이 결과를 반환하면서 다음 상점으로 정보를 요청하기 때문이다.

![스트림의 게으름 때문에 순차 계산이 일어나는 이뉴와 순차 계산을 회피하는 방법](/assets/img/dev/2023/0722/stream.png)

위 그림에서 윗 부분(단일 파이프로 구성 시, 순차)의 경우 이전 요청의 처리가 완전히 끝난 다음에 새로 만든 CompletableFuture 가 처리도니다.  
반면 아랫 부분(파이프라인 분리, 병렬)의 경우 우선 CompletableFuture 를 리스트로 모든 다음 다른 작업과는 독립적으로 각자의 작업을 수행한다.

이제 성능을 테스트해보자.

```java
execute("findPricesFuture", () -> bestPriceFinder.findPricesFuture("CoolPrice"));
```

```shell
[BestPrice price is 141.80, CoolPrice price is 114.95, SeventeenPrice price is 128.30, TXTPrice price is 141.01]
findPricesFuturedone in 1004 ms
```

기존의 순차적인, 블록 방식 구현에 비해서는 빨라졌지만 병렬 스트림을 사용할 때와는 크게 차이가 없다.

코드를 실행하고 있는 기기가 4개의 스레드를 병렬로 실행할 수 있는 기기라는 점에 착안해서 이 문제를 좀 더 고민해보아야 한다.

---

## 3.3. 확장성 더하기

병렬 스트림 버전의 코드는 정확히 4개의 상점에서 하나의 스레드를 할당해서 4개의 작업을 병렬로 수행하여 검색 시간을 최소화하였다.

> 일반적으로 스레드 풀에서 제공하는 스레드 수는 4개  
> 본인 기기에서 스레드 수를 확인하려면 `System.out.println(Runtime.getRuntime().availableProcessors());` 로 확인 가능

만일 상점이 하나 더 추가되어서 5개가 되었을 때 순차 버전에서는 1초가 늘어서 총 5초 이상이 소요되고, 병렬 스트림 버전에서는 4개의 스레드가 모두 처리(1초) 후 
5번째 상점을 처리하므로 총 2초 정도가 소요된다.

`CompletableFuture` 와 병렬 스트림 모두 내부적으로 `Runtime.getRuntime().availableProcessors()` 가 반환하는 스레드 수를 사용하면서 비슷한 결과가 된다.

결과적으로는 비슷하지만 `CompletableFuture` 는 작업에 이용할 수 있는 다양한 Executor 를 지정할 수 있다는 장점이 있다.  
따라서 Executor 로 스레드 풀의 크기를 조절하는 등 애플리케이션에 맞는 최적화된 설정을 만들 수 있다.

실제로 위 기능으로 성능을 향상시킬 수 있는지 알아보자.

---

## 3.4. 커스텀 `Executor` 사용

> **스레드 풀 크기 조절**  
> 
> [자바 병렬 프로그래밍](http://jcip.net.s3-website-us-east-1.amazonaws.com/) 에서는 스레드 풀의 최적값을 찾는 방법을 제안한다.  
> 
> 스레드 풀이 너무 크면 CPU 와 메모리 자원을 서로 경쟁하느라 시간을 낭비하고,  
> 스레드 풀이 너무 작으면 CPU 의 일부 코어는 활용되지 않을 수 있다.  
> 
> 아래 공식으로 대략적인 CPU 활용 비율을 계산할 수 있다.  
> N<sub>threads</sub> = N<sub>CPU</sub> * U<sub>CPU</sub> * (1 + W/C)  
> 
> - N<sub>CPU</sub>: `Runtime.getRuntime().availableProcessors()` 가 반환하는 코어 수
> - U<sub>CPU</sub>: 0과 1 사이의 값을 갖는 CPU 활용 비율
> - W/C: 대기 시간과 계산 시간의 비율

상점의 응답을 약 99% 의 시간만큼 기다리므로 W/C 의 비율을 100 으로 간주할 수 있다.  
즉, 대상 CPU 활용률이 100% 라면 4 * 1 * 100 = 400 개의 스레드를 갖는 풀을 만들어야 함을 의미한다.

하지만 상점 수보다 많은 스레드를 가져봤자 사용할 가능성이 전혀 없으므로 상점 수보다 많은 스레드를 갖는 것은 낭비이다.  
한 상점에 하나의 스레드가 할당될 수 있도록 `Executor` 를 설정한다.

> 스레드 수가 너무 많으면 오히려 서버가 크래시될 수 있으므로 하나의 Executor 에서 사용할 최대 개수는 100 이하로 설정하는 것이 바람직하다.


```java
// 커스텀 Executor
private final Executor executor =
    Executors.newFixedThreadPool(
        // 상점 수만큼의 스레드를 갖는 풀 생성 (스레드 수의 범위는 0~100)
        Math.min(shops.size(), 100),
        new ThreadFactory() {
          @Override
          public Thread newThread(Runnable r) {
            Thread t = new Thread(r);
            t.setDaemon(true);  // 프로그램 종료를 방해하지 않는 데몬 스레드 사용
            return t;
          }
        });
```

위에서 만든 풀은 데몬 스레드를 포함한다.  
자바에서 일반 스레드가 실행 중이면 자바 프로그램은 종료되지 않는다. 따라서 어떤 이벤트를 한없이 기다리면서 종료되지 않은 일반 스레드가 있으면 문제가 될 수 있다.  
반면 데몬 스레드를 자바 프로그램이 종료될 때 강제로 실행이 종료될 수 있다.  
두 스레드의 성능은 같다.

이제 이 Executor 를 factory 메서드인 `supplyAsync()` 의 두 번째 인수로 전달할 수 있다.

```java
execute("findPricesExecutor", () -> bestPriceFinder.findPricesExecutor("CoolPrice"));
```

실행 가능 코어수가 12개일 때 상점도 12개인 경우
```shell
[BestPrice price is 112.39, CoolPrice price is 171.64, SeventeenPrice price is 140.72, SeventeenPrice1 price is 140.72, SeventeenPrice2 price is 140.72, SeventeenPrice3 price is 140.72, SeventeenPrice4 price is 140.72, SeventeenPrice5 price is 140.72, SeventeenPrice6 price is 140.72, SeventeenPrice7 price is 140.72, SeventeenPrice8 price is 140.72, TXTPrice price is 112.25]
basicdone in 12051 ms
[BestPrice price is 157.81, CoolPrice price is 170.19, SeventeenPrice price is 173.38, SeventeenPrice1 price is 173.38, SeventeenPrice2 price is 173.38, SeventeenPrice3 price is 173.38, SeventeenPrice4 price is 173.38, SeventeenPrice5 price is 173.38, SeventeenPrice6 price is 173.38, SeventeenPrice7 price is 173.38, SeventeenPrice8 price is 173.38, TXTPrice price is 111.58]
findPricesParalleldone in 1004 ms
[BestPrice price is 141.80, CoolPrice price is 114.95, SeventeenPrice price is 128.30, SeventeenPrice1 price is 128.30, SeventeenPrice2 price is 128.30, SeventeenPrice3 price is 128.30, SeventeenPrice4 price is 128.30, SeventeenPrice5 price is 128.30, SeventeenPrice6 price is 128.30, SeventeenPrice7 price is 128.30, SeventeenPrice8 price is 128.30, TXTPrice price is 141.01]
findPricesFuturedone in 2012 ms
[BestPrice price is 176.48, CoolPrice price is 120.93, SeventeenPrice price is 141.62, SeventeenPrice1 price is 141.62, SeventeenPrice2 price is 141.62, SeventeenPrice3 price is 141.62, SeventeenPrice4 price is 141.62, SeventeenPrice5 price is 141.62, SeventeenPrice6 price is 141.62, SeventeenPrice7 price is 141.62, SeventeenPrice8 price is 141.62, TXTPrice price is 156.08]
findPricesExecutordone in 1004 ms
```

실행 가능 코어수가 12개일 때 상점은 14개인 경우
```shell
[BestPrice price is 112.39, CoolPrice price is 171.64, SeventeenPrice price is 140.72, SeventeenPrice1 price is 140.72, SeventeenPrice2 price is 140.72, SeventeenPrice3 price is 140.72, SeventeenPrice4 price is 140.72, SeventeenPrice5 price is 140.72, SeventeenPrice6 price is 140.72, SeventeenPrice7 price is 140.72, SeventeenPrice8 price is 140.72, SeventeenPrice9 price is 140.72, SeventeenPrice10 price is 140.72, SeventeenPrice11 price is 140.72, TXTPrice price is 112.25]
basicdone in 15044 ms
[BestPrice price is 157.81, CoolPrice price is 170.19, SeventeenPrice price is 173.38, SeventeenPrice1 price is 173.38, SeventeenPrice2 price is 173.38, SeventeenPrice3 price is 173.38, SeventeenPrice4 price is 173.38, SeventeenPrice5 price is 173.38, SeventeenPrice6 price is 173.38, SeventeenPrice7 price is 173.38, SeventeenPrice8 price is 173.38, SeventeenPrice9 price is 173.38, SeventeenPrice10 price is 173.38, SeventeenPrice11 price is 173.38, TXTPrice price is 111.58]
findPricesParalleldone in 2012 ms
[BestPrice price is 141.80, CoolPrice price is 114.95, SeventeenPrice price is 128.30, SeventeenPrice1 price is 128.30, SeventeenPrice2 price is 128.30, SeventeenPrice3 price is 128.30, SeventeenPrice4 price is 128.30, SeventeenPrice5 price is 128.30, SeventeenPrice6 price is 128.30, SeventeenPrice7 price is 128.30, SeventeenPrice8 price is 128.30, SeventeenPrice9 price is 128.30, SeventeenPrice10 price is 128.30, SeventeenPrice11 price is 128.30, TXTPrice price is 141.01]
findPricesFuturedone in 2010 ms
[BestPrice price is 176.48, CoolPrice price is 120.93, SeventeenPrice price is 141.62, SeventeenPrice1 price is 141.62, SeventeenPrice2 price is 141.62, SeventeenPrice3 price is 141.62, SeventeenPrice4 price is 141.62, SeventeenPrice5 price is 141.62, SeventeenPrice6 price is 141.62, SeventeenPrice7 price is 141.62, SeventeenPrice8 price is 141.62, SeventeenPrice9 price is 141.62, SeventeenPrice10 price is 141.62, SeventeenPrice11 price is 141.62, TXTPrice price is 156.08]
findPricesExecutordone in 1004 ms
```

병렬 처리인 경우 12개 처리(1초) + 2개 처리(1초) = 약 2초인 반면, Executor 를 활용한 경우 14개 처리를 한번에 하므로 약 1초가 소요된다.

**비동기 동작을 많이 사용하는 상황에서는 지금 살펴본 기법이 가장 효과적**이다.

---

## 3.5. 스트림 병렬화와 `CompletableFuture`

위에서 컬렉션을 병렬화하는 두 가지 방법에 대해 알아보았다.
- 병렬 스트림으로 변환해서 컬렉션 처리
- 컬렉션을 반복하면서 CompletableFuture 내부의 연산으로 만듦

CompletableFuture 를 이용하면 전체적인 계산이 블록되지 않도록 스레드 풀의 크기를 조절할 수 있다.

어떤 병렬화 기법을 사용할지 아래를 참고하면 도움이 된다.
- I/O 가 포함되지 않은 계산 중심의 동작을 실행할 때는 스트림 인터페이스가 구현하기도 쉽고 효율적
  - 모든 스레드가 계산 작업을 수행하는 상황에서는 프로세서 코어 수 이상의 스레드를 가질 필요 없음
- I/O 를 기다리는 작업을 병렬로 실행할 때는 CompletableFuture 가 더 많은 유연성을 제공하여 대기/계산(W/C) 의 비율에 적합한 스레드 수 설정 가능
  - 스트림의 게으른 특성 때문에 스트림에서 I/O 를 실제로 언제 처리할 지 예측하기 어려운 문제도 있음

---

지금까지 클라이언트에 비동기 API 를 제공하거나 느린 서버에서 제공하는 동기 서비스를 이용하는 클라이언트에 `CompletableFuture` 를 활용하는 방법에 대해 알아보았다.

지금까지는 `Future` 내부에서 수행하는 작업이 모두 일회성 작업이었다.

다음 포스트에서는 스트림 API 처럼 선언형으로 여러 비동기 연산을 `CompletableFuture` 로 파이프라인화하는 방법에 대해 알아본다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)