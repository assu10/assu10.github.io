---
layout: post
title:  "Java8 - 날짜와 시간"
date:   2023-07-29
categories: dev
tags: java java8 localdate parsing formatting temporal-adjusters datetimeformatter datetimeformatterbuilder zoneid zoneoffset
---

이 포스트에서는 아래 내용에 대해 알아본다.
- Java 8 에서 새로운 날짜와 시간 라이브러리를 제공하는 이유
- 날짜 조작
- 시간대와 캘린더

> 소스는 [github](https://github.com/assu10/java8/tree/feature/chap12) 에 있습니다.

---

**목차**  

- [LocalDate, LocalTime, LocalDateTime, Instant, Duration, Period](#1-localdate-localtime-localdatetime-instant-duration-period)
  - [LocalDate, LocalTime](#11-localdate-localtime)
  - [LocalDateTime](#12-localdatetime)
  - [Instant](#13-instant)
  - [Duration, Period](#14-duration-period)
- [날짜 조정, Parsing, Formatting](#2-날짜-조정-parsing-formatting)
  - [TemporalAdjusters](#21-temporaladjusters)
    - [커스텀 TemporalAdjuster 구현](#211-커스텀-temporaladjuster-구현)
  - [날짜와 시간 객체 출력과 parsing: `DateTimeFormatter`, `DateTimeFormatterBuilder`](#22-날짜와-시간-객체-출력과-parsing-datetimeformatter-datetimeformatterbuilder)
- [다양한 시간대와 캘린더 활용: `ZoneId`](#3-다양한-시간대와-캘린더-활용-zoneid)
  - [UTC/GMT 기준의 고정 오프셋: `ZoneOffset`](#31-utcgmt-기준의-고정-오프셋-zoneoffset)
- [정리하며..](#4-정리하며)

---

**java.util.Date 클래스의 문제점**

- 특정 시점을 날짜가 아닌 ms 단위로 표현
- 1900년을 기준으로 하는 오프셋
- 0부터 시작하는 month 인덱스
- 가변 클래스

2014.03.18 을 Date 클래스로 표현
```java
Date date = new Date(114, 2, 2);  // Sun Mar 02 00:00:00 KST 2014
System.out.println(date);
```

위와 같이 결과가 직관적이지 않고, 반환되는 문자열을 활용하기 어렵다.

이런 문제점을 보완하기 위해 java.util.Calendar 클래스를 제공했는데 1900년을 기준으로 하는 오프셋은 사라졌지만 Calendar 클래스 역시 아래와 같은 문제점이 있다.

- 0부터 시작하는 month 인덱스
- DateFormat 같은 일부 기능은 Date 클래스에서만 작동
- 가변 클래스

위와 같은 문제점들 때문에 Java 8 은 java.time 패키지를 추가하여 새로운 날짜와 시간 클래스를 제공한다.

---

# 1. LocalDate, LocalTime, LocalDateTime, Instant, Duration, Period

---

## 1.1. LocalDate, LocalTime

LocalDate 인스턴스는 시간을 제외한 날짜를 표현하는 불변 객체이며, 어떤 시간대 정보도 포함하지 않는다.

static 팩토리 메서드 `of()` 로 LocalDate 인스턴스 생성이 가능하다.

```java
LocalDate localDate = LocalDate.of(2014, 3, 2); // 2014-03-02

int year = localDate.getYear(); // 2014
Month month = localDate.getMonth(); // MARCH
int day = localDate.getDayOfMonth();  // 2

DayOfWeek dayOfWeek = localDate.getDayOfWeek(); // 요일, SUNDAY
int len = localDate.lengthOfMonth();  // 3월의 일 수, 31
boolean leap = localDate.isLeapYear();  // 윤달 여부, false
```

팩토리 메서드 `now()` 는 시스템 시계의 정보를 이용하여 현재 날짜 정보를 조회한다.
```java
LocalDate today = LocalDate.now();  // 2023-07-29
```

`get()` 메서드에 `TemporalField` 를 전달해서 날짜 정보를 얻을수도 있다.  

> **`TemporalField`**  
> 시간 관련 객체에서 어떤 필드의 값에 접근할 지 정의하는 인터페이스

열거자인 `ChronoField` 는 `TemporalField` 인터페이스를 정의하기 때문에 `ChronoField` 를 이용해서 아래처럼 원하는 정보 조회가 가능하다.

```java
int year2 = localDate.get(ChronoField.YEAR);  // 2014
int month2 = localDate.get(ChronoField.MONTH_OF_YEAR);  // 3
int day2 = localDate.get(ChronoField.DAY_OF_MONTH); // 2
```


---

시간은 LocalTime 클래스로 표현 가능하다.

```java
LocalTime localTime = LocalTime.of(13, 10, 20); // 13:10:20

int hour = localTime.getHour(); // 13
int minute = localTime.getMinute(); // 10
int second = localTime.getSecond(); // 20
```

---

`parse()` 를 이용하여 문자열로 LocalDate, LocalTime 인스턴스를 생성할 수도 있다.

```java
LocalDate localDate1 = LocalDate.parse("2014-03-02"); // 2014-03-02
LocalTime localTime1 = LocalTime.parse("13:10:20"); // 13:10:20
```

`parse()` 메서드에 날짜, 시간, 객체 형식을 지정하는 `DateTimeFormatter` 를 전달할 수도 있는데 (기존의 java.util.DateFormat 클래스 대체하는 클래스) 
이 부분은 [2.2. 날짜와 시간 객체 출력과 parsing: `DateTimeFormatter`, `DateTimeFormatterBuilder`](#22-날짜와-시간-객체-출력과-parsing-datetimeformatter-datetimeformatterbuilder) 에서 다룬다.

---

## 1.2. LocalDateTime

직접 LocalDateTime 을 만들수도 있고, 날짜와 시간을 조합하는 방법도 있다.

직접 LocalDateTime 생성
```java
// 2014-03-02T13:10:20
LocalDateTime localDateTime = LocalDateTime.of(2014, Month.MARCH, 2, 13, 10, 20);

// 2014-03-02T13:10:20
LocalDateTime localDateTime2 = LocalDateTime.of(2014, 3, 2, 13, 10, 20);
```

날짜와 시간을 조합하여 LocalDateTime 생성 (`atTime()`, `atDate()`)
```java
System.out.println("localDate: " + localDate);  // 2014-03-02
System.out.println("localTime: " + localTime);  // 13:10:20

LocalDateTime localDateTime3 = LocalDateTime.of(localDate, localTime);  // 2014-03-02T13:10:20
LocalDateTime localDateTime4 = localDate.atTime(13, 11, 22);  // 2014-03-02T13:11:22
LocalDateTime localDateTime5 = localDate.atTime(localTime); // 2014-03-02T13:10:20
LocalDateTime localDateTime6 = localTime.atDate(localDate); // 2014-03-02T13:10:20
```

LocalDateTime 의 `toLocalDate()`, `toLocalTime()` 으로 LocalDate, LocalTime 인스턴스 추출도 가능하다.
```java
System.out.println("localDateTime: " + localDateTime);  // 2014-03-02T13:10:20

LocalDate localDate3 = localDateTime.toLocalDate(); // 2014-03-02
LocalTime localTime3 = localDateTime.toLocalTime(); // 13:10:20
```

---

## 1.3. Instant

사람은 날짜, 시간, 분으로 날짜를 계산하지만 지계는 연속된 시간에서 특정 지점을 하나의 큰 수로 표현하는 것이 자연스럽다.

java.time.Instant 클래스는 기계적인 관점에서 시간을 표현하기 때문에 **유닉스 에포크 시간(1970년 1월 1일 0시 0분 0초 UTC) 를 기준으로 특정 지점까지의 시간을 초로 표현**한다.

팩토리 메서드인 `ofEpochSecond()` 에 초를 넘겨줘서 Instant 인스턴스를 생성할 수 있다.

Instant 클래스는 nano seconds 의 정밀도를 제공하여, ofEpochSecond() 에 두 번째 인수를 제공해서 nano seconds 단위로 시간 보정도 가능하다.

```java
System.out.println(Instant.ofEpochSecond(3)); // 1970-01-01T00:00:03Z
System.out.println(Instant.ofEpochSecond(3, 0)); // 1970-01-01T00:00:03Z
// 3초 이후의 1억 나노초(1초)
System.out.println(Instant.ofEpochSecond(3, 1_000_000_000)); // 1970-01-01T00:00:04Z
// 3초 이전의 1억 나노초(1초)
System.out.println(Instant.ofEpochSecond(3, -1_000_000_000)); // 1970-01-01T00:00:02Z
```

Instant 도 사람이 확인할 수 있도록 시간을 표시해주는 static 팩토리 메서드인 `now()` 를 제공한다. (UTC0 기준)
```java
System.out.println(Instant.now());  // 2023-07-29T04:14:17.608598Z (UTC0)
```

---

## 1.4. Duration, Period

두 시간 객체 사이의 지속시간은 Duration 클래스를 이용해서 얻을 수 있고, 두 날짜 사이의 지속 ? 은 Period 클래스를 이용해서 얻을 수 있다.

Duration
```java
// 13:10:20
LocalTime localTime1 = LocalTime.of(13, 10, 20);
// 13:10:50
LocalTime localTime2 = LocalTime.of(13, 10, 50);

// 2014-03-02T13:10:20
LocalDateTime localDateTime1 = LocalDateTime.of(2014, Month.MARCH, 2, 13, 10, 20);
// 2014-03-02T13:10:50
LocalDateTime localDateTime2 = LocalDateTime.of(2014, Month.MARCH, 2, 13, 10, 50);

// 1970-01-01T00:00:03Z
Instant instant1 = Instant.ofEpochSecond(3);
// 1970-01-01T00:00:10Z
Instant instant2 = Instant.ofEpochSecond(10);
```

```java
// PT30S
Duration d1 = Duration.between(localTime1, localTime2);
// PT-30S
Duration d2 = Duration.between(localTime2, localTime1);
// PT30S
Duration d3 = Duration.between(localDateTime1, localDateTime2);
// PT7S
Duration d4 = Duration.between(instant1, instant2);
```

Duration 클래스는 초와 나노초로 시간단위를 표현하기 때문에 between() 에 LocalDate 를 전달할 수 없다.

년,월,일로 시간을 표현할 때는 Period 클래스를 사용한다.

```java
LocalDate localDate1 = LocalDate.of(2014, 3, 2); // 2014-03-02
LocalDate localDate2 = LocalDate.of(2014, 3, 5); // 2014-03-05

// P3D
Period p1 = Period.between(localDate1, localDate2);
// P0D
Period p2 = Period.between(localDate2, localDate2);

//Period p3 = Period.between(localDateTime1, localDateTime2); // 오류
```

Duration 과 Period 는 두 시간 객체를 사용하지 않고도 생성할 수 있다.

```java
Duration d5 = Duration.ofMinutes(3);
Duration d6 = Duration.of(3, ChronoUnit.MINUTES);

// PT3M
System.out.println(d5);
// PT3M
System.out.println(d6);
```

```java
// P10D
Period p3 = Period.ofDays(10);
// P21D (3주는 21일)
Period p4 = Period.ofWeeks(3);
// P2Y6M1D (2년 6개월 1일)
Period p5 = Period.of(2, 6, 1);
```

Duration 과 Period 가 제공하는 메서드 중 헷갈릴 수 있는 메서드 2개가 있다.
- `addTo()`
  - 현재값의 복사본을 생성한 후 지정된 Temporal 객체에 추가함
- `plus`
  - 현재값에 주어진 시간을 더한 복사본 생성

---

> **`ChronoUnit` vs `ChronoField`**
> - **ChronoUnit**
    >   - 시간(년, 월, 일, 시간, 분, 초)를 측정하는데 사용되는 단위
>   - 예) ChronoUnit.YEARS, ChronoUnit.DAYS
> - **ChronoFiled**
    >   - 사람이 부분적으로 시간을 참조하는 방식
>   - 예) ChronoFiled.YEAR, ChronoFiled.MONTH_OF_YEAR

---

# 2. 날짜 조정, Parsing, Formatting

`withXXX()` 메서드로 기존의 LocalDate 를 변경할 수 있다.  
**LocalDate 는 불변 클래스이므로 기존 객체를 변경하는 것이 아니라 바뀐 속성을 포함하는 새로운 객체를 반환**한다.

날짜 계산 - 절대적
```java
// 2023-03-01
LocalDate localDate1 = LocalDate.of(2023, 3, 1);

// 2022-03-01
LocalDate localDate2 = localDate1.withYear(2022);
// 2023-03-10
LocalDate localDate3 = localDate1.withDayOfMonth(10);
// 2023-09-01
LocalDate localDate4 = localDate1.with(ChronoField.MONTH_OF_YEAR, 9);

// 2023-03-01, 원래 객체는 변경되지 않음
System.out.println(localDate1);
```

날짜 계산 - 상대적
```java
// 2023-03-01
LocalDate localDate5 = LocalDate.of(2023, 3, 1);

// 2023-03-08
LocalDate localDate6 = localDate5.plusWeeks(1);
// 2022-03-01
LocalDate localDate7 = localDate5.minusYears(1);
// 2023-04-01
LocalDate localDate8 = localDate5.plus(1, ChronoUnit.MONTHS);
```


---

## 2.1. TemporalAdjusters

예를 들어 다음 주 일요일, 돌아오는 평일, 어떤 달의 마지막 날 등 복잡한 날짜를 조회해야 할 때 `with()` 에 `TemporalAdjuster` 를 전달하여 구할 수 있다.

> `TemporalAdjuster` 는 인터페이스이고,  
> `TemporalAdjusters` 는 여러 TemporaryAdjuster 를 반환하는 static 팩토리 메서드를 포함하는 클래스

```java
// 2023-05-09
LocalDate localDate1 = LocalDate.of(2023, 05, 9);

// 2023-05-14, 현재 날짜를 포함하여 다음으로 돌아오는 일요일의 날짜
LocalDate localDate2 = localDate1.with(nextOrSame(DayOfWeek.SUNDAY));

// 2023-05-31, 그 달의 마지막 날짜 반환
LocalDate localDate3 = localDate1.with(lastDayOfMonth());
```

TemporalAdjusters 클래스의 팩토리 메서드

| 메서드                |                                                                     |
|:-------------------|:--------------------------------------------------------------------|
| dayOfWeekInMonth() | '5월의 둘째 화요일' 처럼 서수 요일에 해당하는 날짜를 반환하는 TemporalAdjuster 를 반환          |
| firstInMonth()     | '5월의 첫 번째 화요일' 처럼 그 달의 첫 번째 요일에 해당하는 날짜를 반환하는 TemporalAdjuster 를 반환 |
| lastDayOfMonth()   | 현재 달의 마지막 날짜를 반환하는 TemporalAdjuster 를 반환                            |
| lastInMonth()      | '5월의 마지막 화요일' 처럼 현재 달의 마지막 요일에 해당하는 날짜를 반환하는 TemporalAdjuster 를 반환  |
| next()             | 현재 날짜 이후로 지정한 요일이 처음으로 나타나는 날짜를 반환하는 TemporalAdjuster 를 반환          |
| nextOrSame()       | 현재 날짜를 포함하여 지정한 요일이 처음으로 나타나는 날짜를 반환하는 TemporalAdjuster 를 반환        |

이 외에도 더 많은 팩토리 메서드가 있다.

TemporalAdjuster 는 아래 하나의 메서드만 정의하기 때문에 함수형 인터페이스이다.
```java
@FunctionalInterface
public interface TemporalAdjuster {
  Temporal adjustInto(Temporal temporal);
}
```

---

### 2.1.1. 커스텀 TemporalAdjuster 구현

TemporalAdjuster 인터페이스를 구현하는 NextWorkingDay 클래스를 구현해보자.  
이 클래스는 날짜를 하루씩 다음날로 바꾸는데 이 때 토요일과 일요일은 건너뛴다.

```java
public class NextWorkingDay implements TemporalAdjuster {
  @Override
  public Temporal adjustInto(Temporal temporal) {
    // 현재 요일 조회
    DayOfWeek dow = DayOfWeek.of(temporal.get(ChronoField.DAY_OF_WEEK));
    int dayToAdd = 1;
    if (dow == DayOfWeek.FRIDAY) {
      dayToAdd = 3;
    } else if (dow == DayOfWeek.SATURDAY) {
      dayToAdd = 2;
    }
    return temporal.plus(dayToAdd, ChronoUnit.DAYS);
  }
}
```

```java
LocalDate date = LocalDate.now();
date = date.with(new NextWorkingDay()); // 2023-05-15
```

TemporalAdjuster 는 함수형 인터페이스이므로 위 코드를 아래와 같이 람다 표현식을 사용할 수 있다.  
또한 [UnaryOperator\<LocalDate\>](https://assu10.github.io/dev/2023/05/28/java8-lambda-expression-1/#24-%EA%B8%B0%EB%B3%B8%ED%98%95primitive-type-%ED%8A%B9%ED%99%94) 를 인수로 받는 TemporalAdjusters 클래스의 static 팩토리 메서드인 `ofDateAdjuster()` 를 사용하여
아래와 같이 표현 가능하다.

> **UnaryOperator\<LocalDate\>**  
> UnaryOperator\<T\>, T -> T

```java
public static TemporalAdjuster nextWorkingDay2 = TemporalAdjusters.ofDateAdjuster(
  temporal -> {
    DayOfWeek dow = DayOfWeek.of(temporal.get(ChronoField.DAY_OF_WEEK));
    int dayToAdd = 1;
    if (dow == DayOfWeek.FRIDAY) {
      dayToAdd = 3;
    } else if (dow == DayOfWeek.SATURDAY) {
      dayToAdd = 2;
    }
    return temporal.plus(dayToAdd, ChronoUnit.DAYS);
  } 
);
```

```java
LocalDate date = LocalDate.now();
date = date.with(NextWorkingDay.nextWorkingDay2); // 2023-05-15
```

---

## 2.2. 날짜와 시간 객체 출력과 parsing: `DateTimeFormatter`, `DateTimeFormatterBuilder`

날짜와 시간 관련된 formatting 과 parsing 은 `java.time.format.DateTimeFormatter` 클래스를 통해 할 수 있다.

DateTimeFormatter 가 미리 정의해놓은 `BASIC_ISO_DATE`, `ISO_LOCAL_DATE` 등을 이용하여 날짜나 시간을 특정 형식의 문자열로 만들 수 있다.
```java
LocalDate localDate1 = LocalDate.of(2023, 5, 9);

// 20230509
String s1 = localDate1.format(DateTimeFormatter.BASIC_ISO_DATE);

// 2023-05-09
String s2 = localDate1.format(DateTimeFormatter.ISO_LOCAL_DATE);
```

반대로 문자열을 파싱해서 날짜 객체를 다시 만들수도 있다.

```java
// 2023-05-09
LocalDate localDate2 = LocalDate.parse("20230509", DateTimeFormatter.BASIC_ISO_DATE);

// 2023-05-09
LocalDate localDate3 = LocalDate.parse("2023-05-09", DateTimeFormatter.ISO_LOCAL_DATE);
```

> `format()`: 날짜 객체 → 문자열    
> `parse()`: 문자열 → 날짜 객체

기존의 **java.util.DateFormat 클래스와 달리 모든 DateTimeFormatter 는 스레드에서 안전하게 사용할 수 있는 클래스**이다.

아래와 같이 DateTimeFormatter 클래스를 이용하여 날짜와 문자열을 서로 변경해보자.
```java
DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy");

// 2023-05-09
LocalDate localDate4 = LocalDate.of(2023, 5, 9);
// 09/05/2023
String formattedDateString = localDate4.format(formatter);
// 2023-05-09
LocalDate localDate5 = LocalDate.parse(formattedDateString, formatter);
```

`DateTimeFormatter.ofPattern()` 메서드도 Locale 로 formatter 를 생성할 수 있다.

지역화된 DateTimeFormatter 
```java
DateTimeFormatter italianFormatter = DateTimeFormatter.ofPattern("d. MMM yyyy", Locale.ITALIAN);

// 2023-05-09
LocalDate localDate6 = LocalDate.of(2023, 5, 9);
// 9. mag 2023
String formattedDateString6 = localDate6.format(italianFormatter);
// 2023-05-09
LocalDate localDate7 = LocalDate.parse(formattedDateString6, italianFormatter);
```

---

`DateTimeFormatterBuilder` 클래스로 좀 더 복합적인 formatter 를 정의해서 세부적으로 제어할 수 있다.

예를 들어 대소문자를 구분하는 파싱, 패딩, 포매터의 선택사항 등을 활용할 수 있다.

```java
DateTimeFormatter italianFormatter1 = new DateTimeFormatterBuilder()
    .appendText(ChronoField.DAY_OF_MONTH)
    .appendLiteral(". ")
    .appendText(ChronoField.MONTH_OF_YEAR)
    .appendLiteral(" ")
    .appendText(ChronoField.YEAR)
    .parseCaseInsensitive()
    .toFormatter(Locale.ITALIAN);

// 2023-05-09
LocalDate localDate8 = LocalDate.of(2023, 5, 9);
// 9. maggio 2023
String formattedDateString8 = localDate8.format(italianFormatter1);
// 2023-05-09
LocalDate localDate9 = LocalDate.parse(formattedDateString8, italianFormatter1);
```

---

# 3. 다양한 시간대와 캘린더 활용: `ZoneId`

위의 클래스들에는 시간대와 관련된 정보가 없다.

기존의 java.util.TimeZone 을 대체하는 java.time.ZoneId 로 시간대를 간단히 처리할 수 있다.  
서버 타임 (DST, Daylight Saving Time) 과 같은 사항도 자동으로 처리된다.

ZoneId 또한 불변 클래스로 스레드에 안전하다.

`ZoneRules` 클래스에는 약 40개 정도의 시간대가 있고, ZoneId 의 `getRules()` 를 이용해서 해당 시간대의 규정을 조회할 수 있다.

아래처럼 지역 ID({지역}/{도시}) 로 특정 ZoneId 를 구분하며, 지역 ID 는 [IANA Time Zone Database](https://www.iana.org/time-zones) 에서 제공하는 지역 집합 정보를 사용한다.

```java
ZoneId romeZone = ZoneId.of("Europe/Rome");

// Europe/Rome
System.out.println(romeZone);
```

기존의 TimeZone 객체를 ZoneId 객체로 변환하는 것은 아래와 같다.
```java
ZoneId zoneId = TimeZone.getDefault().toZoneId();

// Asia/Seoul
System.out.println(zoneId);
```

ZoneId 객체를 얻은 후 LocalDate, LocalDateTime, Instant 를 이용해서 ZoneDateTime 인스턴스로 변환 가능하다.  
`ZoneedDateTime` 은 지정한 시간대에 상대적인 시점을 표현한다.

```java
ZoneId romeZone1 = ZoneId.of("Europe/Rome");

// 2023-03-10
LocalDate localDate1 = LocalDate.of(2023, Month.MARCH, 10);
// 2023-03-10T00:00+01:00[Europe/Rome]
ZonedDateTime zdt1 = localDate1.atStartOfDay(romeZone1);
```

```java
// 2023-03-10T13:20
LocalDateTime localDateTime1 = LocalDateTime.of(2023, Month.MARCH, 10, 13, 20);
// 2023-03-10T13:20+01:00[Europe/Rome]
ZonedDateTime zdt2 = localDateTime1.atZone(romeZone1);
```

```java
// 2023-07-16T10:12:58.272252Z
Instant instant1 = Instant.now();
// 2023-07-16T12:12:58.272252+02:00[Europe/Rome]
ZonedDateTime zdt3 = instant1.atZone(romeZone1);
```

`2023-07-16T12:12:58.272252+02:00[Europe/Rome]` 로 ZonedDateTime 를 이해해보면 아래와 같다.
- 2023-07-16
  - LocalDate 
- 12:12:58.272252
  - LocalTime 
- +02:00[Europe/Rome]
  - ZonedId
- 2023-07-16T12:12:58.272252
  - LocalDateTime
- 2023-07-16T12:12:58.272252+02:00[Europe/Rome]
  - ZonedDateTime

위에서 `+02:00[Europe/Rome]` 가 ZonedId 이고, 

---

## 3.1. UTC/GMT 기준의 고정 오프셋: `ZoneOffset`

UTC/GMT 를 기준으로 시간대를 표현하기도 한다.

> UTC (Universal Time Coordinated): 협정 세계시  
> GMT (Greenwich Mean Time): 그리니치 표준시

ZoneId 의 서브 클래스인 `ZoneOffset` 클래스로 런던의 그리니치 0도 자오선과 시간값의 차이를 표현할 수 있다.

```java
ZoneOffset newYorkOffset = ZoneOffset.of("-05:00");
// -05:00
System.out.println(newYorkOffset);
```

위 예시는 서머타임을 제대로 처리할 수 없으므로 권장하지 않는 방식이다.

[ISO 8601](https://ko.wikipedia.org/wiki/ISO_8601) 캘린더 시스템에서 정의하는 UTC/GMT 와 오프셋으로 날짜와 시간을 표현하는 OffsetDateTime 을 만들수도 있다.
```java
// 2023-02-10T18:10:20
LocalDateTime localDateTime1 = LocalDateTime.of(2023, 2, 10, 18, 10, 20);

// 2023-02-10T18:10:20-05:00
OffsetDateTime localDateTimeInNewYork = OffsetDateTime.of(localDateTime1, newYorkOffset);
```

---

# 4. 정리하며..

- 기존의 java.util.Date, java.util.Calendar 를 java.time.LocalDate.. 이 대체
- 기존의 java.util.DateFormat 를 java.time.DateTimeFormat 이 대체
- 기존의 java.util.TimeZone 을 java.time.ZoneId 가 대체

---

## 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 라울-게이브리얼 우르마, 마리오 푸스코, 앨런 마이크로프트 저자의 **Java 8 in Action**을 기반으로 스터디하며 정리한 내용들입니다.*

* [자바 8 인 액션](https://www.yes24.com/Product/Goods/17252419)
* [책 예제 소스](https://download.hanbit.co.kr/exam/2179/)
* [TemporalAdjuster 예시](https://docs.oracle.com/javase/8/docs/api/java/time/temporal/TemporalAdjusters.html)
* [IANA Time Zone Database](https://www.iana.org/time-zones)
* [ISO 8601](https://ko.wikipedia.org/wiki/ISO_8601)