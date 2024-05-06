---
layout: post
title:  "Java8 - Stream 으로 병렬 데이터 처리 (2): Spliterator 인터페이스"
date:   2023-06-25
categories: dev
tags: java java8 stream parallel-stream spliterator-interface
---

이 포스트에서는 여러 chunk 를 병렬로 처리하기 전에 병렬 스트림이 요소를 여러 chunk 로 분할하는 방법에 대해 알아보기 위해 커스텀 Spliterator 를 구현하여 분할 과정을 원하는 방식으로
제어해본다.


> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap07) 에 있습니다.

---

**목차**  

- [Spliterator 인터페이스](#1-spliterator-인터페이스)
  - [Spliterator 분할 과정](#11-spliterator-분할-과정)
  - [커스텀 Spliterator 구현](#12-커스텀-spliterator-구현)
    - [반복형 단어 개수 카운팅 메서드](#121-반복형-단어-개수-카운팅-메서드)
    - [함수형 단어 개수 카운팅 메서드](#122-함수형-단어-개수-카운팅-메서드)
    - [함수형 단어 개수 카운팅 메서드를 병렬로 수행](#123-함수형-단어-개수-카운팅-메서드를-병렬로-수행)
- [정리하며..](#2-정리하며)

---

# 1. Spliterator 인터페이스

Java8 에서는 `Spliterator` 인터페이스를 제공하는데, 이 `Spliterator` 는 자동으로 스트림을 분할하는 기법으로 Iterator 처럼 소스의 요소 탐색 기능을 제공한다는
점은 같지만 **Spliterator 는 병렬 작업에 특화**되어 있다는 부분이 차이점이다.

> Spliterator 는 splitable iterator 의 의미로 분할할 수 있는 반복자 라는 의미

Java8 은 컬렉션 프레임워크에 포함된 모든 자료 구조에 사용할 수 있는 디폴트 Spliterator 구현을 제공하며, 컬렉션은 `spliterator()` 라는 메서드를 제공하는 Spliterator 인터페이스를 구현한다. 

Spliterator 인터페이스 시그니처와 추상 메서드 정의
```java
public interface Spliterator<T> {
  boolean tryAdvance(Consumer<? super T> action);
  Spliterator<T> trySplit();
  long estimateSize();
  int characteristics();
}
```

위에서 `T` 는 Spliterator 에서 탐색하는 요소의 형식을 가리킨다.

- `boolean tryAdvance(Consumer<? super T> action);`
  - Spliterator 의 요소를 하나씩 순차적으로 소비하면서 탐색해야 요소가 남아있는지 여부를 반환
- `Spliterator<T> trySplit();`
  - Spliterator 의 일부 요소를 분할하여 두 번째 spliterator 를 생성
- `long estimateSize();`
  - 탐색해야 할 요소 수 반환
  - 탐색할 요소 수가 정확하지는 않아도 제공된 값을 이용하여 더 쉽게 Spliterator 분할 가능
- `int characteristics();`
  - Spliterator 자체의 특성 집합을 포함하는 int 반환

---

## 1.1. Spliterator 분할 과정

스트림을 여러 스트림으로 분할하는 과정은 아래와 같은 흐름이 재귀적으로 진행된다.

- 1번째 Spliterator 에 `trySplit()` 을 호출하여 2번째 Spliterator 생성
- 2개의 Spliterator 데 `trySplit()` 을 호출하여 4개의 Spliterator 생성
- 위 과정을 `trySplit()` 이 null 을 반환할 때까지 반복 (= `trySplit()` 이 null 을 반환했다는 것은 더 이상 자료 구조를 분할할 수 없음을 의미)
- Spliterator 에 호출한 모든 `trySplit()` 의 결과가 null 이면 재귀 분할 과정 종료

위의 분할 과정은 `characteristics()` 로 정의하는 Spliterator 특성에 영향을 받는다.

`characteristics()` 는 Spliterator 자체의 특성 집합을 포함하는 int 를 반환하는데, 이 특성을 참고하여 적절한 특성들을 반환하면
Spliterator 를 최적화할 수 있다.

<**Spliterator 의 특성**>

| 특성 |                                                                       |
|:--:|:----------------------------------------------------------------------|
| ORDERED | List 처럼 요소에 정해진 순서가 있으므로 요소 탐색/분할 시 이 순서에 유의해야 함                      |
| DISTINCT | x, y 두 요소 방문 시 x.equals(y) 는 항상 false 반환                              |
| SORTED | 탐색된 요는 미리 정의된 정렬 순서를 따름                                               |
| SIZED | Set 같은 크기가 알려진 소스로 Spliterator 를 생성했으므로 `estimatedSize()` 는 정확한 값을 반환 |
| NONNULL | 탐색하는 모든 요소는 null 이 아님                                                 |
| IMMUTABLE | 이 Spliterator 의 소스는 불변이기 때문에 요소를 탐색하는 동안 요소의 추가/삭제/수정이 불가함            |
| CONCURRENT | 동기화없이 Spliterator 의 소스를 여러 스레드에서 동시에 수정 가능                            |
| SUBSIZED | 이 Spliterator 와 분할되는 모든 Spliterator 는 SIZED 의 특성을 가짐                  |

---

## 1.2. 커스텀 Spliterator 구현

문자열의 단어 수를 계산하는 단순 메서드를 구현 후 Spliterator 를 구현하여 적용해본다. 

---

### 1.2.1. 반복형 단어 개수 카운팅 메서드

```java
public static int countWordsIteratively(String s) {
  int counter = 0;
  boolean lastSpace = true;

  // 문자열의 모든 문자를 하나씩 탐색
  for (char c : s.toCharArray()) {
    if (Character.isWhitespace(c)) {
      lastSpace = true;
    } else {
      // 문자를 하나씩 탐색하다가 공백 문자를 만나면 지금까지 탐색한 문자를 단어로 간주하여 단어 개수 증가
      if (lastSpace) {
        counter++;
      }
      lastSpace = false;
    }
  }
  return counter;
}
```

```java
public static final String SENTENCE = " HI  My name is assu.";

public static void main(String[] args) {
  // Found Iteratively: 5 words
  System.out.println("Found Iteratively: " + countWordsIteratively(SENTENCE) + " words");
}
```

---

### 1.2.2. 함수형 단어 개수 카운팅 메서드

반복형 대신 함수형을 이용하면 직접 스레드를 동기화하지 않고도 병렬 스트림으로 작업을 병렬화할 수 있다.

우선 String 을 스트림으로 변환해야 하는데 스트림은 int, long, double 기본형만 제공하므로 Stream<Character> 를 사용한다.
스트림에 리듀싱 연산을 실행하면서 단어 수를 계산할 것이다.  
지금까지 발견한 단어 수를 누적할 int 변수와 마지막 문자의 공백 여부를 기억하는 boolean 변수가 필요한데 Java 에는 튜플이 없으므로 이 두 정보를 저장하는 클래스인 WordCounter 라는 객체는 만든다.

```java
// 함수형 단어 개수 카운팅에서 사용할 클래스
// 지금까지 발견한 단어 개수 누적값과 마지막 문자의 공백 여부값 저장
private static class WordCounter {
  private final int counter;
  private final boolean isLastSpace;

  public WordCounter(int counter, boolean isLastSpace) {
    this.counter = counter;
    this.isLastSpace = isLastSpace;
  }

  // 문자열의 문자를 하나씩 탐색하며 새로운 WordCounter 를 어떤 상태로 생성할 것인지 정의
  // " HI  My name is assu."
  public WordCounter accumulate(Character c) {
    if (Character.isWhitespace(c)) {
      System.out.println("accumulater White 1 - this: " + this);
      return isLastSpace ? this : new WordCounter(counter, true);
    } else {
      System.out.println("accumulater White 2 - this: " + this);
      // 공백을 만나면 지금까지 탐색한 문자를 단어로 간주하여 단어 개수 증가
      return isLastSpace ? new WordCounter(counter+1, false) : this;
    }
  }

  // 2 WordCounter 의 counter 값을 더함
  // 문자열 서브 스트림을 처리한 WordCounter 의 결과 합침
  public WordCounter combine(WordCounter wordCounter) {
    return new WordCounter(counter + wordCounter.counter
            , wordCounter.isLastSpace); // counter 값만 더할 것이므로 마지막 공백은 신경쓰지 않음
  }

  public int getCounter() {
    return counter;
  }

  @Override
  public String toString() {
    return "WordCounter{" +
            "counter=" + counter +
            ", isLastSpace=" + isLastSpace +
            '}';
  }
}
```

```java
// 함수형 단어 개수 카운팅
private static int countWords(Stream<Character> stream) {
  WordCounter wordCounter = stream.reduce(new WordCounter(0, true), // 초기값
                                          WordCounter::accumulate,  // 누적 로직
                                          WordCounter::combine);  // 병합 로직
  return wordCounter.getCounter();
}
```

```java
Stream<Character> stream = IntStream.range(0, SENTENCE.length())
                                    .mapToObj(SENTENCE::charAt);

System.out.println("Found : " + countWords(stream) + " words");
```

```shell
accumulater White 1 - this: WordCounter{counter=0, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=0, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=1, isLastSpace=false}
accumulater White 1 - this: WordCounter{counter=1, isLastSpace=false}
accumulater White 1 - this: WordCounter{counter=1, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=1, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=2, isLastSpace=false}
accumulater White 1 - this: WordCounter{counter=2, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=2, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=3, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=3, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=3, isLastSpace=false}
accumulater White 1 - this: WordCounter{counter=3, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=3, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=4, isLastSpace=false}
accumulater White 1 - this: WordCounter{counter=4, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=4, isLastSpace=true}
accumulater White 2 - this: WordCounter{counter=5, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=5, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=5, isLastSpace=false}
accumulater White 2 - this: WordCounter{counter=5, isLastSpace=false}
Found : 5 words
```

---

### 1.2.3. 함수형 단어 개수 카운팅 메서드를 병렬로 수행

위에서 WordCounter 를 구현한 이유는 병렬 수행이 목적이었으므로 이제 위 내용을 병렬로 수행해본다.

```java
// 함수형 단어 개수 카운팅을 병렬로 수행
Stream<Character> stream = IntStream.range(0, SENTENCE.length())
        .mapToObj(SENTENCE::charAt);

// Found : 15 words
System.out.println("Found : " + countWords(stream.parallel()) + " words");
```

단어의 개수가 5개가 아닌 15개로 나온다.

원래 문자열을 임의의 위치에서 둘로 나누다보니 예상치 못하게 하나의 단어를 두 개로 계산하는 상황이 발생할 수 있다. 
즉, **순차 스트림을 병렬 스트림으로 변경 시 스트림 분할 위치에 따라 잘못된 결과**가 나올 수 있음을 보여준다.

문자열을 임의의 위치에서 분할하는 것이 아닌 단어가 끝나는 위치에서만 분할하는 방법으로 위 문제를 해결할 수 있다.
그러기 위해선 단어 끝에서 문자열을 분할하는 문자 Spliterator 가 필요하다.

문자 Spliterator 를 구현한 후 커스터마이징한 후 원하는 대로 문자열을 분할하여 병렬 스트림으로 전달해보자.

```java
// 함수형 단어 개수 카운팅을 병렬로 수행
private static class WordCounterSpliterator implements Spliterator<Character> {
  private final String strings;
  private int currentCharIdx = 0;

  public WordCounterSpliterator(String strings) {
    this.strings = strings;
  }

  // Spliterator 의 요소를 하나씩 순차적으로 소비하면서 탐색해야 요소가 남아있는지 여부를 반환
  @Override
  public boolean tryAdvance(Consumer<? super Character> action) {
    // 현재 문자를 소비
    // 현재 인덱스에 해당하는 문자를 Consumer 에 제공한 다음에 인덱스를 증가시킴
    action.accept(strings.charAt(currentCharIdx++));

    // 소비할 문자가 남아있으면 true 반환
    return currentCharIdx < strings.length();
  }

  // Spliterator 의 일부 요소를 분할하여 두 번째 spliterator 를 생성
  // 반복될 자료 구조를 분할하는 로직 포함
  @Override
  public Spliterator<Character> trySplit() {
    int currentSize = strings.length() - currentCharIdx;

    // 분할 동작을 중단할 한계를 설정
    // 파싱할 문자열을 순차 처리할 수 있을 만큼 충분히 작아졌음을 알리는 null 반환
    if (currentSize < 4) {
      // 분할 중지
      return null;
    }

    // 파싱할 문자열 chunk 의 중간을 분할 위치로 설정
    for (int splitPos = (currentSize / 2)+currentCharIdx; splitPos < strings.length(); splitPos++) {
      // 단어 중간을 분할하지 않도록 다음 공백이 나올때까지 분할 위치를 뒤로 이동시킴
      if (Character.isWhitespace(strings.charAt(splitPos))) {
        // 분할할 위치를 찾았으면 처음부터 분할 위치까지 문자열을 파싱할 새로운 WordCounterSpliterator 생성
        // 새로운 WordCounterSpliterator 는 현재 위치(currentCharIdx) 부터 분할된 위치까지의 문자를 탐색
        Spliterator<Character> spliterator = new WordCounterSpliterator(strings.substring(currentCharIdx, splitPos));
        // 이 WordCounterSpliterator 의 시작 위치를 분할 위치로 설정
        currentCharIdx = splitPos;
        return spliterator;
      }
    }
    return null;
  }

  // 탐색해야 할 요소 수 반환
  @Override
  public long estimateSize() {
    return strings.length() - currentCharIdx;
  }

  // Spliterator 자체의 특성 집합을 포함하는 int 반환
  @Override
  public int characteristics() {
    return ORDERED  // 문자열의 문자 등장 순서가 유의미함
            + SIZED // estimatedSize() 메서드의 반환값이 정확함
            + SUBSIZED  // trySplit() 으로 생성된 Spliterator 도 정확한 크기를 가짐
            + NONNULL // 문자열에는 null 문자가 존재하지 않음 
            + IMMUTABLE;  // 문자열 자체가 불편 클래스이므로 문자열을 파싱하면서 속성이 추가되지 않음
  }
}
```

```java
Spliterator<Character> spliterator = new WordCounterSpliterator(SENTENCE);
// 두 번째 인수(true)는 병렬 스트림 생성 여부를 지시함
Stream<Character> stream = StreamSupport.stream(spliterator, true);

// Found : 5 words
System.out.println("Found : " + countWords(stream) + " words");
```

Spliterator 는 첫 번째 탐색 시점, 첫 번째 분할 시점, 또는 첫 번째 예상 크기(estimatedSize()) 요청 시점에 요소의 소스를 바인딩할 수 있는데
이러한 동작은 **늦은 바인딩 Spliterator** 라 한다.

---

# 2. 정리하며..

- 내부 반복을 이용하면 명시적으로 다른 스레드를 사용하지 않고도 스트림을 병렬로 처리 가능함
- 병렬 처리가 항상 빠른 것은 아님
- 병렬 스트림으로 병렬 처리 시 처리할 데이터가 아주 많거나 각 요소를 처리하는 시간이 오래 걸릴 경우 성능을 높일 수 있음
- 기본형 특화 스트림을 사용하는 등의 올바른 자료 구조 선택은 병렬로 처리하는 것보다 성능적으로 더 큰 영향을 미칠 수 있음
- 포크/조인 프레임워크는 병렬화할 수 있는 태스크를 작은 태스크로 분할한 후 분할된 태스크를 각각의 스레드로 실행하며, 서브 태스크 각각의 결과를 합쳐서 최종 결과를 생산함
- Spliterator 는 탐색하려는 데이터를 포함하는 스트림을 어떻게 병렬화할 것인지를 정의함

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)
* [Stream API 병렬 데이터 처리하기](https://catsbi.oopy.io/0428be55-8c8d-40a2-923a-acc738d74a14#a419aa3b-b573-43fd-b39a-93af25a36322)