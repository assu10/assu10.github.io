---
layout: post
title:  "AI - 파이썬(2): 반복문, 조건문, 딕셔너리, 리스트 컴프리헨션, 람다, map(), filter(), 클래스/객체"
date: 2025-09-06
categories: dev
tags: ai ml python generative-ai llm for-loop dictionary list-comprehension lambda map filter class object python-basics
---

이 포스트에서는 반복문과 조건문, 딕셔너리, 리스트 컴프리헨션, 람다, `map()`, `filter()`, 마지막으로 클래스와 객체에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 반복문](#1-반복문)
* [2. 조건문](#2-조건문)
* [3. 생성형 인공지능 개발을 위한 파이썬 문법](#3-생성형-인공지능-개발을-위한-파이썬-문법)
  * [3.1. 딕셔너리(Dictionary)](#31-딕셔너리dictionary)
  * [3.2. 리스트 컴프리헨션(List Comprehension)](#32-리스트-컴프리헨션list-comprehension)
  * [3.3. 람다(Lambda) 함수](#33-람다lambda-함수)
  * [3.4. `map()`, `filter()`](#34-map-filter)
    * [3.4.1. `map()`](#341-map)
    * [3.4.2. `filter()`](#342-filter)
  * [3.5. 클래스(class)와 객체(object)](#35-클래스class와-객체object)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. 반복문

파이썬은 for와 while 두 가지 반복문을 제공하지만, 여기서는 데이터 구조를 순회하며 작업하는 데 매우 효율적인 for 문에 집중한다.

```python
five = [1, 2, 3, 4, 5]
print(f"리스트의 길이: {len(five)}")
# 출력: 리스트의 길이: 5

for i in five:
  print(i, "end")

# 실행 결과
# 1 end
# 2 end
# 3 end
# 4 end
# 5 end
```

단순한 숫자 시퀀스를 반복해야 할 때는 `range()` 함수가 유용하다.  
`range()` 는 필요한 시점에 숫자를 하나씩 생성해주어 메모리를 효율적으로 사용할 수 있게 해준다.

```python
rten = range(10)
print(list(rten))
# 출력: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
```

```python
five1 = range(1, 6)
print(list(five1))
# 출력: [1, 2, 3, 4, 5]
```

```python
ten9 = range(9, -1, -1)
print(list(ten9))
# 출력: [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
```

```python
for i in range(1, 3):
  print(i, "end")

# 실행 결과
# 1 end
# 2 end
```

---

# 2. 조건문

```python
num = 15
if num >= 10:
  print("more than 10")

# 실행 결과
# more than 10
```

```python
num2 = 10
if num2 % 2 == 0:
  print("짝수")
else:
  print("홀수")

# 실행 결과
# 짝수
```

함수는 `def` 키워드를 사용하여 정의한다.

```python
def 함수이름(매개변수):
  (함수 내용)
```

```python
def number_check(num):
  if num % 2 == 0:
    print("짝수")
  else:
    print("홀수")

# 함수 호출
number_check(10)

# 실행 결과
# 짝수
```

- **매개 변수(Parameter)**
  - 함수를 정의할 때 사용하는 변수
  - 위 예시에서는 _num_ 이 매개 변수
  - 함수 내부에서 사용될 값을 받아들이는 변수
- **전달 인자(Argument)**
  - 함수를 호출할 때 실제로 전달하는 값
  - 위 예시에서 _number_check(10)_의 _10_ 이 전달 인자

---

# 3. 생성형 인공지능 개발을 위한 파이썬 문법

---

## 3.1. 딕셔너리(Dictionary)

리스트가 순서(인덱스)를 기준으로 데이터를 나열한다면, **딕셔너리**는 고유한 `key` 에 `value` 를 짝지어 저장하는 자료 구조이다.  
순서가 아닌 의미 있는 이름(`key`)으로 데이터를 관리하고 싶을 때 유용하다.

파이썬에서는 중괄호 `{}` 를 사용하여 딕셔너리를 만들고, 내부에는 `key:value` 형태로 데이터를 저장한다.

```python
people = {
    "name": "assu",
    "age": 20,
    "hobby": "exercising"
}

# "name"이라는 key를 사용해서 value를 조회
print(people["name"])

# 실행 결과
# assu
```

딕셔너리가 AI 개발에서 특히 중요한 이유는, LLM 이 추론 결과를 대부분 딕셔너리 형태로 반환하기 때문이다.  
모델이 생성한 텍스트, 관련 메타데이터 등을 `key` 를 통해 명확하게 접근할 수 있어 데이터를 파싱하고 활용하기에 매우 편리하다.

---

## 3.2. 리스트 컴프리헨션(List Comprehension)

리스트 컴프리헨션은 기존 리스트나 다른 순회 가능한 객체를 기반으로, 매우 간결하게 새로운 리스트를 만드는 방법이다.  
컴프리헨션은 '내포'라는 우리말 뜻처럼, 리스트를 만드는 과정을 한 줄의 코드에 함축하고 있다.

AI 나 데이터 분석에서는 기존 데이터를 변형하거나 필터링하여 새로운 데이터셋을 만드는 작업이 끊임없이 발생한다.  
이 때 리스트 컴프리헨션을 사용하면 코드가 짧아지고 가독성이 높아져 생산성이 크게 향상된다.

예를 들어 숫자 리스트의 각 요소를 2배로 만든 새로운 리스트를 만든다고 가정해보자.

일반 for 문 사용 시

```python
numbers = [1, 2, 3, 4, 5]
double_numbers = []
for num in numbers:
  double_numbers.append(num * 2)

print(double_numbers)
# 출력: [2, 4, 6, 8, 10]
```

리스트 컴프리헨션 사용 시

```python
numbers = [1, 2, 3, 4, 5]
result = [a * 2 for a in numbers] # for문이 리스트 안으로 들어간 형태

print(result)
# 출력: [2, 4, 6, 8, 10]
```

for 루프를 돌면서 _numbers_ 의 각 요소를 _a_ 에 담고, _a * 2_ 연산을 수행한 결과를 그대로 새 리스트의 요소로 만드는 과정이 단 한 줄로 완성되었다.

문자열 리스트를 가공하는 것도 가능하다.

```python
names = ["assu", "silby", "jaehoon"]
labels = ["보고 싶은 " + name for name in names]

print(labels)
# 출력: ['보고 싶은 assu', '보고 싶은 silby', '보고 싶은 jaehoon']
```

리스트 컴프리헨션은 **조건문을 포함**하여 원하는 데이터만 필터링하는 기능도 제공한다.
```python
# 1부터 10까지의 숫자 중 짝수만 골라 새로운 리스트 생성
evens = [b for b in range(1, 11) if b % 2 == 0]

print(evens)
# 출력: [2, 4, 6, 8, 10]
```

이제 이 개념을 실제 LLM 출력 데이터를 처리하는 상황에 적용해보자.  
모델이 생성한 텍스트가 딕셔너리 리스트 형태로 반환되었을 때, 생성된 텍스트만 추출하여 새로운 리스트를 만드는 경우이다.

```python
llm_outputs = [
    {"generated_text": "안녕하세요."},
    {"generated_text": "무엇을 도와드릴까요?"},
    {"generated_text": "오늘 날씨가 좋아요."}
]

# 각 딕셔너리(aa)에서 "generated_text" 키의 값만 추출
texts = [aa["generated_text"] for aa in llm_outputs]

print(texts)
# 출력: ['안녕하세요.', '무엇을 도와드릴까요?', '오늘 날씨가 좋아요.']
```

이처럼 리스트 컴프리헨션은 AI 모델의 복잡한 출력 결과에서 원하는 정보만 효율적으로 뽑아내는데 매우 강력한 도구이다.

---

## 3.3. 람다(Lambda) 함수

람다 함수는 이름이 없는 한 줄짜리 함수이다. 그래서 익명 함수(Anonymous function)라고도 불린다.  
`def` 키워드로 만드는 일반 함수와 달리, `lambda` 키워드를 사용하여 간단한 기능을 빠르게 정의할 때 사용한다.

람다 함수의 기본 구조는 아래와 같다.

```python
lambda 매개변수: 표현식

# 예
lambda x: x*2
```

람다 함수는 아래 상황에서 많이 사용된다.
- 함수를 딱 한 번만 사용할 때
- 복잡한 `def` 선언 없이 간단한 계산을 임시로 처리할 때
- `map()`, `filter()` 같은 다른 함수의 인자로 간단한 기능을 전달할 때

```python
# x를 입력받아 x * 2를 반환하는 람다 함수
double = lambda x: x * 2
print(double(3))
# 출력: 6

# a와 b를 입력받아 a + b를 반환하는 람다 함수
value = lambda a, b: a + b
print(value(2, 3))
# 출력: 5
```

람다 함수는 여러 개의 매개변수를 받을 수 있지만, **표현식은 반드시 한 줄**이어야 한다.  
구조적인 작업을 처리해야 한다면 일반 함수(`def`)를, 잠깐 쓰고 버릴 간단한 계산이라면 람다 함수를 사용하는 것이 좋다.

---

## 3.4. `map()`, `filter()`

리스트 컴프리헨션도 훌륭하지만 함수형 프로그래밍 스타일로 데이터를 일괄 처리하고 싶을 때 `map()`과 `filter()` 는 매우 강력한 함수이다.  
이 함수들은 데이터 리스트를 하나씩 자동으로 처리해주는데, 특히 람다 함수와 함께 사용될 때 그 진가가 드러난다.

---

### 3.4.1. `map()`

`map()` 함수는 리스트와 같은 순회 가능한 데이터의 **모든 요소에 동일한 함수(작업)를 일괄적으로 적용**하고 그 결과를 반환한다.

```python
map(계산할 함수, 리스트)
```

`map()` 이 반환하는 값은 엄밀히 말해 리스트가 아닌 map 객체이므로, 결과를 눈으로 확인하려면 `list()` 로 감싸주어야 한다.

```python
numbers = [1, 2, 3, 4, 5]
# numbers의 모든 요소(x)에 lambda x: x*2 함수를 적용
doubled = list(map(lambda x: x * 2, numbers))
print(doubled)
# 출력: [2, 4, 6, 8, 10]

names = ["assu", "silby"]
labels = list(map(lambda x: "보고 싶은 " + x, names))
print(labels)
# 출력: ['보고 싶은 assu', '보고 싶은 silby']
```

LLM 출력 결과에서 특정 값만 추출하는 작업도 `map()` 을 사용하면 매우 간결해진다.

```python
results = [
    {"generated_text": "안녕하세요"},
    {"generated_text": "하하하"},
    {"generated_text": "안녕, 반가워"}
]
# results의 모든 딕셔너리(x)에서 "generated_text" 키의 값을 추출
texts = list(map(lambda x: x["generated_text"], results))
print(texts)
# 출력: ['안녕하세요', '하하하', '안녕, 반가워']
```

---

### 3.4.2. `filter()`

`filter()` 함수는 이름 그대로 **데이터의 각 요소를 특정 조건 함수로 테스트하여, True 인 것들만** 걸러낸다.

```python
filter(조건 함수, 리스트)
```

`filter()` 역시 filter 객체를 반환하므로 `list()` 로 변환해야 내용을 볼 수 있다.

```python
numbers = [1, 2, 3, 4, 5, 6]
# numbers의 요소(x) 중 짝수(x % 2 == 0)인 것만 필터링
evens = list(filter(lambda x: x % 2 == 0, numbers))
print(evens)
# 출력: [2, 4, 6]

texts = ["안녕하세요", "하하하", "안녕, 반가워"]
# "안녕"으로 시작하는 텍스트만 필터링
greetings = list(filter(lambda x: x.startswith("안녕"), texts))
print(greetings)
# 출력: ['안녕하세요', '안녕, 반가워']
```

LLM 결과 중에서 특정 조건을 만족하는 결과물만 추려낼 때도 유용하다.
```python
results = [
    {"generated_text": "안녕하세요"},
    {"generated_text": "하하하"},
    {"generated_text": "안녕, 반가워"}
]
# generated_text가 "안녕"으로 시작하는 딕셔너리만 필터링
greetings = list(filter(lambda x: x["generated_text"].startswith("안녕"), results))
print(greetings)
# 출력: [{'generated_text': '안녕하세요'}, {'generated_text': '안녕, 반가워'}]
```

---

## 3.5. 클래스(class)와 객체(object)

**객체**는 속성(데이터)과 기능(함수)를 함께 묶어놓은 실체를 의미한다. 그리고 이 객체를 어떻게 만들어야 할지 정의해 놓은 설계도가 **클래스**이다.

- **속성(Attribute)**
  - 객체가 가지는 데이터나 상태
- **기능(Method)**
  - 객체가 수행할 수 있는 동작이나 기능


```python
# 클래스 정의 (설계도 만들기)
class Robot:
  # 객체가 생성될 때 속성을 초기화하는 특별한 메서드
  def __init__(self, name, color):
    # self는 만들어지는 객체 자기 자신을 가리킵니다.
    self.name = name   # 이 객체의 name 속성에 입력받은 name을 저장
    self.color = color # 이 객체의 color 속성에 입력받은 color를 저장

  # 객체의 기능(메서드) 정의
  def introduce(self):
    print(f"안녕하세요, 저는 {self.color}의 {self.name}입니다.")

# 객체 생성 (설계도로 실제 제품 만들기)
robot1 = Robot("말하는 로봇", "노랑색")
robot2 = Robot("듣는 로봇", "녹색")

# 객체의 메서드 호출
robot1.introduce()
robot2.introduce()
```

```text
안녕하세요, 저는 노랑색의 말하는 로봇입니다.
안녕하세요, 저는 녹색의 듣는 로봇입니다.
```

`__init__(self, ...)`는 **초기화 메서드(initializer)**라고 불리며, _Robot(...)_처럼 클래스를 통해 객체를 생성할 때 **가장 먼저 자동으로 호출**된다.  
객체가 처음 만들어질 때 필요한 속성들을 설정하는 역할을 한다.

`self`는 클래스 안의 메서드에서 항상 첫 번째 매개변수로 사용되며, **메서드를 호출한 객체 자신**을 가리킨다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 이영호 저자의 **모두의 인공지능 with 파이썬**을 기반으로 스터디하며 정리한 내용들입니다.*

* [모두의 인공지능 with 파이썬](https://product.kyobobook.co.kr/detail/S000217061005)
* [Google Colab](https://colab.research.google.com)