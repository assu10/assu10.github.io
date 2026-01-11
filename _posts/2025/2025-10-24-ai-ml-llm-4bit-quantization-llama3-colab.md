---
layout: post
title:  "AI - Colab(T4)에서 Llama 3 8B 모델 4비트 양자화(NF4)로 구동"
date: 2025-10-24
categories: dev
tags: ai ml llm quantization 4bit 8bit nf4 bitsandbytes transformers llama3 colab t4-gpu huggingface bnbconfig auto-quantization floating-point bf16 fp16
---

최근 AI/ML 분야, 특히 LLM 의 발전 속도는 경이로울 지경이다.  
[AI - Colab 에서 LLM 실행](https://assu10.github.io/dev/2025/10/19/ai-ml-llm-huggingface-colab-tutorial/) 에서 메타의 LLaMA 3.2 3B 모델을 
다루어 보았다. 3B(Billion, 30억)이라는 파라미터 수도 결코 작지 않지만, 현재 발표되는 SOTA(State-of-the-Art) 모델들은 400B, 500B, 700B에 육박하는 
거대한 크기를 자랑한다.

일반적으로 모델의 파라미터 수가 많을수록 더 우수한 성능을 보여주는 경향이 있다. 하지만 이는 곧 모델을 구동하기 위해 천문학적인 비용의 고성능 하드웨어(GPU, VRAM 등)가 
필수적이라는 의미이기도 하다. 당장 무료로 제공되는 Google Colab과 같은 환경에서 이러한 대형 모델을 실행하는 것은 사실상 불가능에 가깝다.

그렇다면 우리는 한정된 자원 속에서 상대적으로 작은 모델에 만족해야 할까?

그렇지 않다. 바로 **양자화(Quantization)**라는 기법이 있기 때문이다.  
양자화는 **모델의 가중치(파라미터)를 더 적은 비트 수(예: 32비트 부동 소수점 → 8비트 또는 4비트 정수)로 표현하여, 모델의 크기를 획기적으로 줄이고 추론 속도를 향상시키는 기술**이다.  
이를 통해 성능 저하를 최소화하면서도 한정된 하드웨어 환경에서 더 큰 모델을 구동할 수 있게 된다.

여기서는 이 양자화 기법을 적용하여 대표적인 고성능 모델인 **LLaMA 3 8B** 모델을 실제 Google Colab 환경에서 불러와서 실행해본다.

---

**목차**

<!-- TOC -->
* [1. LLM의 양자화 원리](#1-llm의-양자화-원리)
  * [1.1. 컴퓨터가 실수를 저장하는 방식: 부동 소수점(Floating-Point)](#11-컴퓨터가-실수를-저장하는-방식-부동-소수점floating-point)
  * [1.2. 더 가벼운 표현 방식: FP16, BF16(Brain Floating-Point 16)](#12-더-가벼운-표현-방식-fp16-bf16brain-floating-point-16)
  * [1.3. 양자화(Quantization): INT8과 4-bit](#13-양자화quantization-int8과-4-bit)
  * [1.4. 정밀도 하락 시 함정: 오버플로우와 언더플로우](#14-정밀도-하락-시-함정-오버플로우와-언더플로우)
* [2. 코랩 환경 설정](#2-코랩-환경-설정)
* [3. 라이브러리 설치](#3-라이브러리-설치)
* [4. 모델 양자화 설정](#4-모델-양자화-설정)
* [5. 토크나이저 및 모델 불러오기](#5-토크나이저-및-모델-불러오기)
* [6. LLM에 질문](#6-llm에-질문)
  * [6.1. LLM의 추론 파이프라인 설정](#61-llm의-추론-파이프라인-설정)
  * [6.2. 프롬프트와 메시지 설정](#62-프롬프트와-메시지-설정)
  * [6.3. 추론 하이퍼파라미터: `temperature`, `top_p`](#63-추론-하이퍼파라미터-temperature-top_p)
    * [6.3.1. `temperature`](#631-temperature)
    * [6.3.2. `top_p` (누적 확률)](#632-top_p-누적-확률)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. LLM의 양자화 원리

LLM은 수억 개에서 수천억 개에 이르는 방대한 양의 파라미터(숫자)를 기반으로 작동한다. 이 때 사용되는 숫자는 대부분 소수점이 포함된 **실수(Real Number)**이다.

여기서 핵심은 컴퓨터가 이 실수들을 우리가 보는 10진수 그대로 저장하지 않는다는 점이다. 컴퓨터는 오직 0과 1만 이해하기 때문에, 실수를 0과 1의 조합으로 변환하는 
특별한 방식이 필요하다.  
그것이 바로 **부동 소수점** 표현 방식이다.

---

## 1.1. 컴퓨터가 실수를 저장하는 방식: 부동 소수점(Floating-Point)

우리가 205.67 이라는 숫자를 다룬다면 컴퓨터는 이를 $$2.0567 \times 10^{2}$$ 형태로 변환한다.  
실제 컴퓨터는 2진수를 사용하므로 205.67 이라는 10진수 숫자를 $$1.6074 \times 2^{7}$$ 와 같은 2진수 기반 형태로 변환한다.

이 숫자를 저장하기 위해 컴퓨터는 정보를 세 부분으로 나눈다.
- **부호(Sign)**: 숫자가 양수인지 음수인지(양수면 0, 음수면 1)
- **지수(Exponent)**: 숫자가 크기 범위 (여기서는 $$2^{7}$$ 의 '7'에 해당, $$7_{10} = 111_{2}$$)
- **가수(Mantissa)**: 숫자의 구체적인 값, 즉 유효 숫자 (여기서는 '1.6074'에서 소수점 이하 숫자인 6074 에 해당, $$6074_{10} = 1011110111010_{2}$$)

LLM 연산의 기본이 되는 FP32(32-bit Floating-Point) 방식은 하나의 실수를 저장하는데 총 32비트를 사용한다.

![부동 소수점 32비트](/assets/img/dev/2025/1024/fp.png)

- 부호: 1비트
- 지수: 8비트
- 가수: 23비트

FP32는 매우 정밀하고 넓은 범위의 숫자를 표현할 수 있지만, 파라미터가 수천억 개인 LLM에서는 막대한 메모리 용량을 차지하고 연산 속도를 저하시키는 주된 원인이 된다.

---

## 1.2. 더 가벼운 표현 방식: FP16, BF16(Brain Floating-Point 16)

이 문제를 해결하기 위해 더 적은 비트를 사용하는 방식들이 등장했다.
- **FP16(16-bit Floating-Point)**
  - 부호(1비트), 지수(5비트), 가수(10비트)로 총 16비트 사용
  - FP32 대비 메모리 사용량이 절반으로 줄고, 최신 GPU에서 연산 속도가 매우 빠름
  - 단점은 지수 비트가 5개뿐이라 표현할 수 있는 숫자의 범위가 좁음
- **BF16(Bfloat16 - Brain Floating-Point 16)**
  - 구글과 인텔이 개발한 16비트 방식으로 부호(1비트), **지수(8비트)**, 가수(7비트)를 사용
  - 핵심은 **지수 비트가 FP32와 동일한 8비트**이면서, 메모리는 FP16처럼 가볍게 가져갈 수 있다는 점임
  - 가수 비트(정밀도)를 희생하는 대신, FP32와 거의 동일한 넓은 숫자 범위를 유지함. 이는 딥러닝 연산에서 매우 중요한 장점임

---

## 1.3. 양자화(Quantization): INT8과 4-bit

양자화는 여기서 한 걸음 더 나아가, 실수를 정수(Integer)로 변환하여 저장함으로써 정밀도를 줄이는 대신 메모리와 속도를 극대화하는 기술이다.

- **8비트 양자화(INT8)**
  - FP32나 FP16 같은 부동 소수점 방식이 아닌(=부호, 지수, 가수 구조가 아닌), 실수를 -128~127 사이의 정수 중 하나로 근사하여 표현
  - 정밀도 손실이 발생하지만, 메모리 사용량을 획기적으로 줄이고(FP32 대비 1/4) 정수 연산에 특화된 하드웨어에서 추론 속도를 엄청나게 향상시킴
- **4비트 양자화(4-bit)**
  - 숫자 하나를 저장하는데 단 4비트만 사용하므로 이론적으로 $$2^4 = 16$$ 개의 값만 표현 가능
  - 과거에는 정밀도 손실이 너무 커서 사용하기 어려웠으나, NF4(NormalFloat 4)와 같은 최신 기술이 등장하며 상황이 바뀜
  - NF4는 16개의 정수를 사용하는 대신, 원본 데이터의 분포를 분석하여 가장 중요한 16개의 '소수 값'을 미리 정해두고, 입력되는 실수를 가장 가까운 값으로 매핑함
  - 이 덕분에 4비트라는 극단적인 환경에서도 모델의 정확도를 상당히 보존할 수 있게 되었고, 이는 노트북이나 스마트폰에서 고성능 LLM을 구동할 수 있게 하는 핵심 기술이 됨

---

## 1.4. 정밀도 하락 시 함정: 오버플로우와 언더플로우

비트 수를 줄일 때 가장 조심해야 할 부분은 오버플로우와 언더플로우이다.
- **오버플로우**
  - 숫자가 표현 가능한 최대 범위보다 너무 커서 '무한대'로 처리되는 현상
- **언더플로우**
  - 숫자가 표현 가능한 최소 범위보다 너무 작아서 '0'으로 처리되는 현상

딥러닝 모델, 특히 LLM은 아주 작은 값의 변화에도 민감하게 반응하며 학습이 이루어진다. 만약 언더플로우로 인해 이 값들이 모두 0으로 처리된다면 모델 학습이나 
추론이 제대로 이루어지지 않는다.

결국 LLM에서 숫자를 다루는 방식은 단순히 '저장'이 아니다. **BF16**이 넓은 범위(지수)를 유지하며 주목받는 이유, 그리고 **NF4** 같은 '똑똑한' 양자화 방식이 
각광받는 이유는, 무작정 비트를 줄이는 것이 아니라 **모델의 성능을 유지하는 선에서 얼마나 효율적으로 숫자를 압축하느냐**가 관건이기 때문이다.

양자화는 LLM을 더 작고, 더 빠르고, 더 다양한 환경에서 사용할 수 있게 해주는 필수적인 기술이다.

---

# 2. 코랩 환경 설정

한정된 리소스 내에서 LLM을 구동하기 위해 Google Colab 의 GPU 설정을 확인하고, 허깅페이스 허브에 인증하는 과정이 필요하다.

Colab 에서 [런타임] - [런타임 유형 변경] 에서 T4 GPU를 선택한다.

다음으로 [허깅페이스 허브에 접근하기 위한 인증 토큰을 설정](https://assu10.github.io/dev/2025/10/19/ai-ml-llm-huggingface-colab-tutorial/#2-%ED%97%88%EA%B9%85%ED%8E%98%EC%9D%B4%EC%8A%A4-%EC%A0%91%EA%B7%BC-%EC%BD%94%EB%93%9C-%EB%B0%9C%EA%B8%89)한다.

```python
from google.colab import userdata
from huggingface_hub import login

# Colab 보안 비밀에 저장된 LLAMA_HF_TOKEN 값 불러옴
hf_token = userdata.get('LLAMA_HF_TOKEN')

print(f"현재 로드된 토큰 (앞/뒤 5자리): {hf_token[:5]}...{hf_token[-5:]}")

# 허깅페이스 허브에 로그인
login(token = hf_token)

print("설정 완료")
```

---

# 3. 라이브러리 설치

LLM을 불러오고 양자화를 적용하기 위해 `transformers`와 `bitsandbytes` 라이브러리를 설치한다.

```python
# bitsandbytes와 transformers 를 최신 버전으로 설치
!pip install -U bitsandbytes transformers

# 필요한 모듈과 라이브러리 임포트
from transformers import AutoTokenizer, AutoModelForCausalLM
from transformers import BitsAndBytesConfig, pipeline
import torch
```

---

**핵심 라이브러리 상세**

**!pip install -U bitsandbytes transformers**  
`!pip install` 은 주피터 노트북이나 코랩 환경에서 파이썬 패키지를 설치하는 명령어이다.

- **`!`**
  - Colab 이나 주피터 환경에서 파이썬 코드가 아닌 리눅스 셸 명령어 실행할 때 사용하는 특수 기호
  - 이 기호를 사용하면 파이썬 코드 셸에서 바로 운영체제의 명령어를 실행할 수 있음
  - 코랩에서는 보통 파이썬 코드를 실행하지만 `!`를 붙이면 파이썬 대신 리눅스 명령어를 실행할 수 있다.
- **`-U`**
  - pip install 의 옵션 중 하나로, 패키지를 설치할 때 이미 설치되어 있더라도 최신 버전으로 업그레이드함
- **BitsAndBytes**
  - LLM과 같은 대규모 딥러닝 모델을 8비트 또는 4비트로 양자화하여, GPU 메모리 사용량을 획기적으로 줄이면서도 모델 성능은 거의 그대로 유지시켜주는 필수 라이브러리
- **Transformers**
  - [4. LLM 내려받기](https://assu10.github.io/dev/2025/10/19/ai-ml-llm-huggingface-colab-tutorial/#4-llm-%EB%82%B4%EB%A0%A4%EB%B0%9B%EA%B8%B0)를 참고

---

**주요 임포트 기능**

- **AutoTokenizer**
  - 모델에 맞는 토크나이저를 자동으로 불러온다.
  - AI 모델은 자연어를 직접 이해하지 못하므로, 텍스트를 적절한 단위(토큰)로 자르고 숫자로 변환하는 '토크나이징' 과정이 필요하다.
  - 모델마다 텍스트 처리 방식이 다르기 때문에, 각 모델에 맞는 전용 토크나이저를 사용해야 한다.
- **AutoModelForCausalLM**
  - 'Causal Language Modeling'(인과적 언어 모델링)에 특화된 모델을 자동으로 불러온다.
  - 이는 GPT 계열처럼 입력된 텍스트를 기반으로 **다음에 이어질 단어**를 순차적으로 예측하는 모델을 의미한다.
- **BitsAndBytesConfig**
  - 모델 양자화에 필요한 세부 설정을 정의하는 클래스이다.
  - 이 설정을 통해 모델 가중치를 4비트 혹은 8비트로 변환하여 메모리 효율을 극대화한다.
- **pipeline**
  - 텍스트 생성, 번역 등 복잡한 AI 작업을 몇 줄의 코드로 간단하게 실행할 수 있도록 돕는 유틸리티이다.
- **torch**
  - [파이토치](https://assu10.github.io/dev/2025/10/19/ai-ml-llm-huggingface-colab-tutorial/#4-llm-%EB%82%B4%EB%A0%A4%EB%B0%9B%EA%B8%B0)는 딥러닝 연산과 GPU 가속화를 지원하는 핵심 라이브러리이다.

---

# 4. 모델 양자화 설정

`bitsandbytes` 라이브러리를 사용하여 모델을 4비트로 양자화하는 설정을 구성한다.  
4비트 양자화는 8비트보다 메모리를 더 절약하지만 정밀도 저하의 위험이 있다. 하지만 T4 GPU와 같은 무료 Colab 환경에서 8B 이상의 모델을 구동하기 위해서는 4비트 
양자화가 사실상 필수적이다.

양자화는 딥러닝 모델의 가중치나 연산 값을 낮은 비트로 표현하여 메모리 사용량과 계산 비용을 줄이는 기술이다.
일반적으로 딥러닝 모델의 가중치는 보통 32비트 부동 소수점(FP32)으로 저장되는데, 이 모델을 사용할 경우 계산하는 양이 많아지면서 많은 메모리가 필요하다.
하지만 이를 4비트 혹은 8비트 정밀도로 변환하면 메모리 사용량을 크게 줄일 수 있다.

```python
# 양자화할 모델 ID 설정
model_id = "meta-llama/Meta-Llama-3-8B-Instruct"

# BitsAndBytes 양자화 설정
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4"
)
```

**bnb_config = BitsAndBytesConfig()**  
BitsAndBytesConfig 클래스의 객체를 저장한다. BitsAndBytesConfig 는 인공지능 모델에 대한 4비트나 8비트 양자화 설정을 하는 클래스이다.

**load_in_4bit=True**  
**4비트 양자화를 활성화**한다.  
이 설정 하나만으로 모델의 가중치가 4비트 정밀도로 변환되어 메모리 사용량이 FP32 대비 1/8 수준으로 크게 줄어든다.

**bnb_4bit_compute_dtype=torch.float16**  
**4비트로 양자화된 가중치의 계산(Compute)은 16비트로 수행**한다.  
이것이 양자화의 핵심이다. 모델 가중치는 4비트로 **저장**되어 메모리를 아끼지만, 실제 연산이 일어나는 순간에는 16비트(FP16)로 확장하여 계산한다.  
이를 통해 정밀도 손실을 최소화하면서도 메모리 효율을 유지한다.

**bnb_4bit_use_double_quant=True**  
**2단계 이중 양자화를 활성화**한다.  
1단계 양자화 이후, 양자화 과정에서 사용된 '양자화 상수'들 자체를 다시 한번 미세하게 양자화한다.  
이는 정밀도 손실을 추가로 보정하여 4비트라는 낮은 비트 수에서도 성능 저하를 최소화하는 기법이다.

**bnb_4bit_quant_type="nf4"**  
4비트 양자화된 값을 저장할 때 사용하는 방식이다.
**nf4(NormalFloat 4)**는 4비트로 표현할 수 있는 값들을 단순한 정수가 아닌, 원본 데이터(가중치)의 분포를 고려한 '정규화된 부동 소수점'값으로 매핑하는 방식이다.  
기존 방식보다 더 정밀하고 효율적으로 4비트를 사용할 수 있게 해준다.

---

# 5. 토크나이저 및 모델 불러오기

이제 앞에서 정의한 _model_id_ 와 _bnb_config_ 를 사용하여 실제 모델과 토크나이저를 메모리로 불러온다.

```python
# 토크나이저 불러오기
# modol_id 에 해당하는 모델에 맞는 토크나이저를 자동으로 불러온다.
tokenizer = AutoTokenizer.from_pretrained(
    model_id,
    token=hf_token
)

# 모델 불러오기
# AutoModelForCausalLM을 사용하여 인과적 언어 모델을 불러온다.
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config = bnb_config, # 위에서 정의한 4비트 양자화 설정 적용
    device_map = "auto", # 사용 가능한 하드웨어(CPU, GPU)에 모델을 자동 배치
    token=hf_token
)
```

AutoModelForCausalLM.from_pretrained() 함수 호출 시 사용된 주요 파라미터는 아래와 같다.

**quantization_config = bnb_config**  
위에서 정의한 4비트 양자화 설정을 모델을 불러오는 시점에 적용한다.  
`transformers` 는 이 설정을 보고 `bitsandbytes`를 활용하여 모델 가중치를 4비트로 변환하여 로드한다.

**device_map = "auto"**  
Colab 환경(T4 GPU)을 자동으로 감지하여 알아서 모델의 각 레이어를 GPU와 CPU 메모리에 적절히 나누어 배치한다.  
만약 여러 개의 GPU가 있다면 GPU 간에도 자동으로 분할 배치된다.

_model_ 변수에는 이제 4비트로 양자화되어 T4 GPU 메모리에 올라간 Llama 3 8B 모델이 저장되었다.

---

# 6. LLM에 질문

앞서 4비트로 양자화하여 성공적으로 불러온 Llama 3 8B 모델을 이제 실제로 사용해본다.  
허깅페이스 `transformers` 라이브러리의 `pipeline()` 함수는 모델 추론 과정을 매우 간단하게 만들어준다.

---

## 6.1. LLM의 추론 파이프라인 설정

먼저, 텍스트 생성("text-generation") 작업을 수행할 파이프라인을 설정한다. 이 파이프라인에 우리가 이미 로드한 _model_ 과 _tokenizer_ 를 연결한다.

```python
# LLM 추론을 위한 텍스트 생성 파이프라인 설정
pipe = pipeline(
    "text-generation",  # 수행할 작업
    model = model,      # 양자화하여 로드한 모델
    tokenizer = tokenizer,  # 로드한 토크나이저
    device_map="auto"
)
```

device_map="auto" 설정에 따라 Colab 환경에 할당된 T4 GPU를 자동으로 감지한다.  
코드를 실행하면 아래와 같이 `cuda:0` (첫 번째 GPU)가 사용되도록 설정되었다는 로그를 확인할 수 있다.

```shell
Device set to use cuda:0
```

---

## 6.2. 프롬프트와 메시지 설정

파이프라인이 준비되었으니, 이제 모델에게 전달할 메시지(프롬프트)를 작성한다.  
`meta-llama/Meta-Llama-3-8B-Instruct` 모델은 이름(Instruct)에서 알 수 있듯이, 지시사항이나 채팅 형식에 맞게 파인튜닝되었다. 따라서 메시지 형식을 `role`로 
구분하여 전달하는 것이 좋다.

- role: "system" - 챗봇의 역할이나 정체성 정의
- role: "user" - 사용자가 실제로 입력하는 질문

```python
# LLM에 입력할 프롬프트(메시지) 정의
messages = [
    {"role": "system", "content": "너는 한국어로만 대답하는 챗봇이다."},
    {"role": "user", "content": "대한민국의 수도는 어디니?"},
]

# 파이프라인을 실행하여 추론(응답 생성) 시작
outputs = pipe(
    messages,
    max_new_tokens=256,     # 생성할 최대 새 토큰(단어) 수
    temperature=0.6,      # 생성 다양성 조절
    top_p=0.9             # 누적 확률 샘플링
)

# 생성된 응답 중 마지막 메시지(assistant의 답변)를 출력
print(outputs[0]["generated_text"][-1])
```

코드를 실행하면 모델이 추론을 시작하며, `pad_token_id` 관련 경고가 나타날 수 있다. 이는 자유로운 텍스트 생성(open-end generation) 시 자연스럽게 발생하는 
로그이므로 무시해도 좋다.

잠시 후 아래와 같은 결과를 얻을 수 있다.

```shell
Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
{'role': 'assistant', 'content': '서울입니다!'}
```

outputs 변수에는 시스템, 사용자, 그리고 어시스턴트(모델)의 응답까지 전체 대화 내역이 저장된다.  
`[-1]` 인덱스를 통해 모델의 최종 답변만 확인한다.  
4비트 양자화에도 불구하고 정확한 답변을 생성하는 것을 확인할 수 있다.

---

## 6.3. 추론 하이퍼파라미터: `temperature`, `top_p`

`pipe()` 함수 호출 시 사용한 `temperature`와 `top_p`는 LLM의 응답 스타일을 결정하는 매우 중요한 하이퍼파라미터이다.

### 6.3.1. `temperature`

`temperature`는 모델이 다음 단어를 선택할 때 확률 분포를 얼마나 '날카롭게' 또는 '평평하게' 만들지 결정한다.  
'대한민국의 수도는?' 다음 단어로 '서울'(90% 확률)과 부산(5% 확률)이 있을 때, 이 확률을 어떻게 사용할지 정한다.

- **낮은 값(예: 0.6)**
  - 확률 분포가 날카로워진다.
  - 확률이 높은 단어('서울')가 선택될 가능성이 훨씬 높아진다.
  - 결과가 더 **결정적이고 일관성**있게 나온다.
- **높은 값(예: 1.5)**
  - 확률 분포가 평평해진다.
  - 원래 낮았던 단어('부산')도 선택될 가능성이 커진다.
  - 결과가 더 **다양하고 창의적**이지만, 자칫 엉뚱한 답변이 나올 수 있다.

---

### 6.3.2. `top_p` (누적 확률)

`top_p`는 'Nucleus Sampling'이라고도 불리며, 확률이 높은 순서대로 단어들을 누적하여, 그 합이 `top_p` 값에 도달할 때까지만 후보로 남기는 방식이다.

top_p=0.9(예시)의 경우 단어 후보들을 확률순으로 정렬한 뒤, 상위 단어들의 확률을 더해 90%가 되는 지점까지만 사용한다.  
서울: 70%, 부산: 15%, 인천 5% → 누적 90% 달성했으므로 이 3개만 후보군  
나머지 10%에 해당하는 하위권 단어들은 아예 무시된다.

- **낮은 값**
  - 선택 가능한 단어 범위가 좁아져(후보군이 적어져) 더 **안정적이고 예측 가능**한 텍스트가 생성된다.
- **높은 값**
  - 더 많은 단어가 후보군에 포함되어 **유연하고 창의적**인 텍스트가 생성된다.

일반적으로 정확한 답변이 필요하면 `temperature`를 낮추고, 창의적인 글쓰기가 필요하면 `temperature`를 높이고 `top_p`를 조절한다.

전체 코드
```python
from google.colab import userdata
from huggingface_hub import login

# Colab 보안 비밀에 저장된 LLAMA_HF_TOKEN 값 불러옴
hf_token = userdata.get('LLAMA_HF_TOKEN')

print(f"현재 로드된 토큰 (앞/뒤 5자리): {hf_token[:5]}...{hf_token[-5:]}")

# 허깅페이스 허브에 로그인
login(token = hf_token)

print("설정 완료")

# bitsandbytes와 transformers 를 최신 버전으로 설치
!pip install -U bitsandbytes transformers

# 필요한 모듈과 라이브러리 임포트
from transformers import AutoTokenizer, AutoModelForCausalLM
from transformers import BitsAndBytesConfig, pipeline
import torch

# 모델 양자화 설정
model_id = "meta-llama/Meta-Llama-3-8B-Instruct"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4"
)

# 토크나이저 불러오기
# modol_id 에 해당하는 모델에 맞는 토크나이저를 자동으로 불러온다.
tokenizer = AutoTokenizer.from_pretrained(
    model_id,
    token=hf_token
)

# 모델 불러오기
# AutoModelForCausalLM을 사용하여 인과적 언어 모델을 불러온다.
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config = bnb_config, # 위에서 정의한 4비트 양자화 설정 적용
    device_map = "auto", # 사용 가능한 하드웨어(CPU, GPU)에 모델을 자동 배치
    token=hf_token
)

# LLM 추론을 위한 텍스트 생성 파이프라인 설정
pipe = pipeline(
    "text-generation",  # 수행할 작업
    model = model,      # 양자화하여 로드한 모델
    tokenizer = tokenizer,  # 로드한 토크나이저
    device_map="auto"
)

# LLM에 입력할 프롬프트(메시지) 정의
messages = [
    {"role": "system", "content": "너는 한국어로만 대답하는 챗봇이다."},
    {"role": "user", "content": "대한민국의 수도는 어디니?"},
]

# 파이프라인을 실행하여 추론(응답 생성) 시작
outputs = pipe(
    messages,
    max_new_tokens=256,     # 생성할 최대 새 토큰(단어) 수
    temperature=0.6,      # 생성 다양성 조절
    top_p=0.9             # 누적 확률 샘플링
)

# 생성된 응답 중 마지막 메시지(assistant의 답변)를 출력
print(outputs[0]["generated_text"][-1])
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 이영호 저자의 **모두의 인공지능 with 파이썬**을 기반으로 스터디하며 정리한 내용들입니다.*

* [모두의 인공지능 with 파이썬](https://product.kyobobook.co.kr/detail/S000217061005)
* [Google Colab](https://colab.research.google.com)