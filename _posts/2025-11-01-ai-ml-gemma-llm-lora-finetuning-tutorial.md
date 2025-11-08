---
layout: post
title:  "AI - Gemma 1B 모델 LoRA 파인튜닝"
date: 2025-11-01
categories: dev
tags: ai ml llm gemma fine-tuning peft lora sft hugging-face transformers trl colab tutorial
---

GPT 나 LLaMA와 같은 LLM은 이미 놀라운 성능으로 일반적인 상황 대부분을 처리한다. 하지만 현업에서는 그 이상의 것을 요구하는 경우가 많다.

- **법률, 의료, 금융** 등 고도로 전문화된 도메인 지식이 필요한 경우
- 학생, 내부 담당자 등 **특정 사용자 그룹에 최적화된 맞춤형 응답**이 필요한 경우
- 질의응답 내용이 민감 정보라 **절대 외부로 유출되어서는 안 되는** 보안이 중요한 경우

이러한 상황을 해결하는 기술이 바로 **파인튜닝(fine-tuning)**이다.

파인튜닝은 이미 방대한 데이터로 사전 학습된 LLM에, 우리가 해결하고자 하는 특정 목적이나 환경에 맞는 데이터를 추가로 학습시켜 모델의 응답을 미세하게 조정하는 기법이다.

일반적인 LLM은 광범위한 언어 패턴과 상식을 갖추고 있지만, 특정 영역이나 사용자 요구에 100% 최적화되어 있지는 않다. 파인 튜닝은 바로 이 지점에서 시작한다.  
사전 학습 모델에 **도메인 특화 데이터(domain-specific data)**를 추가로 주입함으로써, 모델이 정보를 선택하는 기준, 표현 방식, 전문 용어 사용, 심지어 말투까지 
우리가 원하는 방향으로 정교하게 제어할 수 있다.

**왜 지금 파인튜닝인가?**  
최근 LLaMA, Phi, Gemma 등 Open LLM이 등장하면서, 많은 기업이 이를 활용해 사내망에서만 접근 가능한 맞춤형 AI를 구축하는 사례가 증가하고 있다.  
이 과정에서 '우리 회사 목적에 맞는' LLM을 만들기 위한 파인튜닝은 선택이 아닌 필수가 되었다.

여기서는 LLM을 특정 목적에 맞게 파인튜닝하는 방법에 대해 알아본다.  
내가 가진 데이터를 바탕으로, 원하는 스타일의 응답을 생성하는 LLM을 직접 조정해보는 실습을 함께 진행해 본다.

---

**목차**

<!-- TOC -->
* [1. LLM 파인튜닝(fine-tuning)](#1-llm-파인튜닝fine-tuning)
* [2. 필요한 라이브러리 설치 및 불러오기](#2-필요한-라이브러리-설치-및-불러오기)
  * [2.1. 라이브러리 설치](#21-라이브러리-설치)
  * [2.2. 라이브러리 임포트](#22-라이브러리-임포트)
* [3. 모델 불러오기](#3-모델-불러오기)
  * [3.1. 허깅페이스 인증](#31-허깅페이스-인증)
  * [3.2. 모델 및 토크나이저 불러오기](#32-모델-및-토크나이저-불러오기)
* [4. LoRA 설정하기](#4-lora-설정하기)
  * [4.1. 모델에 LoRA 적용](#41-모델에-lora-적용)
  * [4.2. 학습 인자(TrainingArguments) 설정](#42-학습-인자trainingarguments-설정)
* [5. 학습 데이터셋 불러오기](#5-학습-데이터셋-불러오기)
  * [5.1. `SFTrainer`를 위한 데이터 포맷팅](#51-sftrainer를-위한-데이터-포맷팅)
  * [5.2. 데이터셋 크기 조절](#52-데이터셋-크기-조절)
* [6. SFT 트레이너 설정 및 학습 시작](#6-sft-트레이너-설정-및-학습-시작)
  * [6.1. 학습 실행](#61-학습-실행)
  * [6.2. 모델 저장](#62-모델-저장)
* [7. 학습 모델 추론](#7-학습-모델-추론)
  * [7.1. 텍스트 생성 파이프라인 설정](#71-텍스트-생성-파이프라인-설정)
  * [7.2 프롬프트 정의](#72-프롬프트-정의)
  * [7.3. 모델 추론 실행](#73-모델-추론-실행)
  * [7.4. 파인튜닝 결과 확인](#74-파인튜닝-결과-확인)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. LLM 파인튜닝(fine-tuning)

파인튜닝은 이미 방대한 데이터로 잘 학습된 LLM의 기존 지식과 응답 습관을 우리가 원하는 방향으로 '미세 조정'하는 과정을 말한다.

하지만 여기서 한 가지 장벽에 부딪힌다. 바로 **모델의 크기**이다. 
GPT나 LLaMA처럼 수십억, 수천억 개의 파라미터를 가진 모델 전체를 다시 학습시키려면 매우 많은 시간과 GPU 메모리가 필요하다.

**효율적인 접근:PEFT(Parameter-Efficient Fine-Tuning)와 LoRA(Low-Rank Adaptation)**  
이러한 비용 문제를 해결하기 위해, 최근에는 모델 전체를 재학습하는 대신 **모델의 일부 핵심적인 부분만 살짝 수정**하는 방식이 표준으로 자리 잡았다.

이러한 기법들을 통틀어 **PEFT**, 즉, '파라미터 효율적 파인튜닝'이라고 한다. 이 포스트에서 사용할 핵심 기술이 바로 PEFT의 일종인 **LoRA**이다.

**LoRA**는 트랜스포머 아키텍처의 핵심인 [어텐션(Attention)](https://assu10.github.io/dev/2025/10/10/ai-ml-llm-transformer-evolution/#3-%EC%96%B4%ED%85%90%EC%85%98attention%EC%9D%98-%EB%93%B1%EC%9E%A5%EA%B3%BC-%ED%8A%B8%EB%9E%9C%EC%8A%A4%ED%8F%AC%EB%A8%B8transformer) 레이어에 집중한다.  
'이 단어가 문장 내 다른 단어들과 어떤 관계를 맺고 있지?' 를 계산하는 이 핵심 로직에, 아주 작은 규모의 '어댑터(Adapter)' 레이어를 추가로 덧붙여 학습시킨다.

이 방식의 가장 큰 장점은 압도적인 **효율성**이다.
- **빠른 학습 속도**
  - 전체 모델(수십~수백 GB)의 파라미터는 freeze 시키고, 추가된 LoRA 어댑터(수십~수백 MB)의 파라미터만 학습함
- **낮은 리소스 요구**
  - 전체 모델을 학습하려면 수십 GB의 고성능 GPU 메모리가 필요하지만, LoRA를 사용하면 Google Colab의 무료 버전 T4 GPU(약 16GB)에서도 충분히 학습 가능
- **모듈성**
  - 학습된 LoRA 가중치는 `adapter_model.bin`과 같은 별도의 작은 파일로 저장됨
  - 원본 LLM 모델 파일을 전혀 건드리지 않고, 필요할 때마다 이 어댑터 파일을 '부착'하거나 '탈착'하며 사용 가능

이 포스트에서는 **Gemma 1B 모델**을 불러온 뒤, '소크라테스식 질문법' 데이터를 준비하여 LoRA 방식으로 파인튜닝을 진행한다.  
그리고 학습 전후의 답변이 실제로 어떻게 달라지는지 확인해본다.

---

# 2. 필요한 라이브러리 설치 및 불러오기

```python
# LLM 파인튜닝 및 데이터 처리를 위한 핵심 라이브러리 설치
!pip install -q -U datasets trl peft

import torch
from datasets import load_dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
)
from trl import SFTTrainer
from peft import LoraConfig, get_peft_model
```

## 2.1. 라이브러리 설치

**!pip install -q -U datasets trl peft**  
LLM을 더 가볍고 효율적으로 다루기 위한 라이브러리를  설치한다.
- `datasets`
  - 허깅페이스에서 제공하는 데이터셋을 쉽게 다운로드하고 처리함
- `trl`
  - 지도 학습 기반 파인튜닝(SFT)을 쉽게 적용할 수 있도록 함
- `peft`
  - LoRA와 같은 PEFT 기법을 적용하기 위한 라이브러리
- `-q(quiet)`
  - 설치 과정에서 발생하는 불필요한 로그 메시지를 생략하여 출력을 깔끔하게 함
- `-U(upgrade)`
  - 이미 패키지가 설치되어 있더라도 최신 버전으로 업그레이드

---

## 2.2. 라이브러리 임포트

**import torch**  
PyTorch 라이브러리  
LLM의 모든 연산(추론 및 파인튜닝)은 내부적으로 이 PyTorch의 Tensor 연산을 기반으로 동작한다.

**from datasets import load_dataset**  
허깅 페이스에 공개된 수많은 데이터셋을 `load_dataset("데이터셋 이름")` 한 줄로 손쉽게 불러올 수 있게 해주는 함수이다.  
학습(train), 검증(validation) 데이터 분할도 자동으로 처리해준다.

**from transformers import (...)**  
허깅페이스의 `transformers`는 LLM 생태계의 표준 라이브러리이다.
- `AutoModelForCausalLM`
  - Causal Language Model(인과 관계 언어 모델), 즉 GPT처럼 다음 단어를 예측하며 문장을 생성하는 [Auto-Regressive](https://assu10.github.io/dev/2025/10/10/ai-ml-llm-transformer-evolution/#52-gpt-decoder) 방식의 모델을 자동으로 불러오는 클래스
- `AutoTokenizer`
  - 텍스트를 모델이 이해할 수 있는 숫자 토큰으로 변환하고, 모델의 숫자 응답을 다시 텍스트로 복원하는 '토크나이저'를 모델에 맞게 자동으로 불러옴
- `TrainingArguments`
  - 모델 학습에 필요한 수많은 하이퍼파라미터(배치 크기, 학습률, 에포크 수, 저장 경로 등)를 체계적으로 설정하는 클래스

**from trl import SFTTrainer**  
허깅페이스의 `trl`(Transformers Reinforcement Learning) 라이브러리의 핵심 기능인 `SFTTrainer` 클래스이다.  
SFT(Supervised Fine-Tuning)를 위해 특별히 설계된 고수준 API로, 기존 Trainer보다 훨씬 적은 코드로 `transformers`, `datasetes`, `peft`를 모두 연동하여 
파인튜닝 프로세스를 자동화해준다.

**from peft import LoraConfig, get_peft_model**  
`peft`(Parameter-Efficient Fine-Tuning) 라이브러리의 핵심 구성 요소이다.
- `LoraConfig`
  - LoRA를 어떻게 적용할지 상세 설정을 정의하는 객체
  - 예) LoRA 랭크(r), 드롭아웃 비율, 어떤 레이어를 적용할지 등
- `get_peft_model`
  - LoraConfig에서 정의한 설정을 바탕으로, 불러온 원본 `transformers` 모델에 LoRA 어댑터를 덧붙여 'PEFT 모델'로 변환해주는 함수이다.
  - 이 함수를 거친 모델은 원본 파라미터는 freeze 되고, LoRA 파라미터만 학습할 준비를 마치게 된다.

---

# 3. 모델 불러오기

Colab 에서 [런타임] - [런타임 유형 변경] 에서 T4 GPU를 선택한다.  
T4 GPU는 약 16GB의 VRAM을 제공하며, LoRA와 같은 PEFT 기법을 사용하기에 충분한 사양이다.

다음으로 [허깅페이스 허브에 접근하기 위한 인증 토큰을 설정](https://assu10.github.io/dev/2025/10/19/ai-ml-llm-huggingface-colab-tutorial/#2-%ED%97%88%EA%B9%85%ED%8E%98%EC%9D%B4%EC%8A%A4-%EC%A0%91%EA%B7%BC-%EC%BD%94%EB%93%9C-%EB%B0%9C%EA%B8%89)한다.  
Gemma 나 LLaMA 2 와 같은 모델은 접근 권한이 필요하기 때문이다.

## 3.1. 허깅페이스 인증

```python
# 허깅페이스 로그인
from google.colab import userdata
from huggingface_hub import login

# Colab 보안 비밀에 저장된 LLAMA_HF_TOKEN 값 불러옴
hf_token = userdata.get('FINE_TOKEN')

print(f"현재 로드된 토큰 (앞/뒤 5자리): {hf_token[:5]}...{hf_token[-5:]}")

# 허깅페이스 허브에 로그인
login(token = hf_token)

print("설정 완료")
```

**login(token = hf_token)**  
런타임 환경에 인증 정보를 저장한다. 이로써 `transformers` 라이브러리가 허깅페이스 API를 통해 모델과 토크나이저를 원활하게 다운로드할 수 있다.

---

## 3.2. 모델 및 토크나이저 불러오기

이제 파인튜닝의 기반이 될 사전 학습 모델과 토크나이저를 로드한다.

```python
# 파인튜닝에 사용할 모델 불러오기
model_id = "google/gemma-3-1b-it"

tokenizer = AutoTokenizer.from_pretrained(
    model_id,
    token=hf_token
)
# 패딩 토큰을 EOS 토큰으로 설정 (중요)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    dtype=torch.float16,  # 16비트 반정밀도로 로드
    device_map="auto",    # 사용 가능한 장치(GPU)에 자동 할당
    token=hf_token,
)
```

**model_id = "google/gemma-3-1b-it"**  
google/gemma-3-1b-it 모델은 구글에서 제작한 것으로, `it`은 'Instruction Tuned'의 약자이다.  
이미 사용자의 지시나 질문에 잘 응답하도록 한 차례 파인튜닝된 모델이다.  
약 10억 개(1B) 파라미터 규모는 T4 GPU에서 다루기에 매우 적합하다.

**tokenizer = AutoTokenizer.from_pretrained(..)**  
허깅페이스에서 제공하는 `AutoTokenizer`는 model_id에 해당하는 모델이 학습될 때 사용했던 토크나이저를 자동으로 불러온다.  
토크나이저는 텍스트를 모델이 이해할 수 있는 숫자 토큰(Token ID) 배열로 변환하고, 그 반대의 역할도 수행한다.

**tokenizer.pad_token = tokenizer.eos_token**  
LLM 파인튜닝 시 매우 중요한 설정이다.  
모델이 배치(batch) 단위로 학습시킬 때, 트랜스포머 아키텍처는 행렬 연산을 위해 모든 입력 데이터의 길이를 동일하게 맞춰야 한다.  

아래 문장을 학습한다고 해보자.

```text
["hello world!", "hi!", "how are you doing today?"]
```

트랜스포머 모델은 동일한 크기의 텐서(배열)을 변환해야 하므로, 가장 긴 문장에 맞추어 길이를 정해야 한다.
이 때 짧은 문장에 의미없는 패딩 토큰(pad_token)을 추가해서 길이를 맞춘다.

```text
["hello world!", "<pad>", "<pad>", "<pad>"] # 길이 5
[hi!", "<pad>", "<pad>", "<pad>", "<pad>"] # 길이 5
["how are you doing today?"] # 길이 5
```

하지만 Gemma, LLaMA 계열 모델은 별도의 `<pad>` 토큰을 정의하지 않는 경우가 많다.  
이 경우 '문장의 끝'을 의미하는 **EOS(End Of Sequence)** 토큰을 패딩 토큰으로 대신 사용하도록 명시적으로 지정해야 한다.

> **EOS(End Of Sequence)**
> 
> 문장의 끝을 나타내는 특수 토큰이다.  
> LLM이나 트랜스포머 기반 모델은 입력된 문장에 대한 출력을 생성할 때 어디까지 생성해야 할 지 모른다.  
> 그래서 문장이 끝났다는 것을 명확히 알리기 위해 EOS 토큰을 추가한다.

**model = AutoModelForCausalLM.from_pretrained(..)**  
`AutoModelForCausalLM`을 사용하여 실제 모델 가중치 파일을 다운로드하고 메모리에 로드한다.  
Causal LM 은 GPT처럼 이전 단어들을 기반으로 다음 단어를 순차적으로 예측하는 [Auto-Regressive](https://assu10.github.io/dev/2025/10/10/ai-ml-llm-transformer-evolution/#52-gpt-decoder) 방식의 생성 모델을 의미한다.

- **dtype = torch.float16**
  - 모델의 연산 데이터 타입은 32비트(FP32)가 아닌 **16비트 부동소수점(FP16, half-precision**으로 설정한다.
  - 그러면 GPU 메모리 사용량이 거의 절반으로 줄어들고, T4와 같은 Tensor Core GPU에서의 연산 속도가 크게 향상된다.
  - 경량 파인튜닝의 핵심 최적화 기법이다.
- **device_map="auto"**
  - 모델의 거대한 레이어들을 사용 가능한 장치(여기서는 T4 GPU)에 자동으로 분배하여 로드한다.

---

# 4. LoRA 설정하기

모델 로드가 완료되었으니, 이제 LLM을 효율적으로 파인튜닝하기 위한 핵심인 LoRA 설정을 정의한다.  
`peft` 라이브러리의 `LoraConfig`를 사용하여 어떤 레이어를 어떤 방식으로 튜닝할지 정한다.

```python
# LoRA 설정
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_prog", "k_proj", "v_proj", "o_prog"],
    lora_dropout=0.05,
    task_type="CAUSAL_LM",
)
```

위 코드는 LoRA 어댑터를 모델의 어느 부분에, 얼마나 강력하게 적용할지 결정하는 설정이다.  
각 매개변수의 의미를 보자.

- `r=16`
  - **LoRA의 rank**를 의미한다. `r`은 LoRA가 새로 추가하는 작은 가중치 행렬의 크기, 즉 모델을 얼마나 정교하게 조정할 지 결정하는 값이다.
    - `r`이 작으면: 학습이 빠르고 메모리를 적게 쓰지만, 표현력이 다소 단순해질 수 있다.
    - `r`이 크면: 더 세밀한 조정이 가능하지만, 파라미터 수가 늘어나 메모리 사용량이 증가하고 학습 속도가 느려질 수 있다.
    - 일반적으로 `r=8` 또는  `r=16`이 성능과 효율 사이의 균형 잡힌 값으로 많이 사용된다.
  - r값은 정밀도와 자원 사용 사이의 균형을 정하는 중요한 설정이다.
- `lora_alpha=32`
  - **LoRA의 스케일링 팩터**이다. LoRA가 학습한 내용이 기존 모델의 가중치에 얼마나 강하게 반영될지를 조절한다.
  - LoRA는 모델의 원래 가중치($$W$$)에 작은 변화($$\Delta W$$)를 더하는 방식(W<sub>new</sub>=W + $$\Delta W$$)으로 작동한다.
  - `lora_alpha`는 이 $$\Delta W$$의 영향력을 조절하는 값이다.
    - 너무 작으면: 파인튜닝 효과가 미미하다.
    - 너무 크면: 원본 모델의 지식을 덮어써 과적합(overfitting)이 발생할 수 있다.
  - 일반적으로 `lora_alpha`는 `r`값의 2배를 설정하는 것이 일반적이다.
- `target_modules=["q_prog", "k_proj", "v_proj", "o_prog"]`
  - **LoRA를 적용할 대상 레이어**를 지정한다. 이는 모델의 어느 부분을 집중적으로 튜닝할지 결정하는 설정이다.
    - 트랜스포머 모델의 [셀프 어텐션(Self-Attention)의 Q, K, V, O 프로젝션](https://assu10.github.io/dev/2025/10/10/ai-ml-llm-transformer-evolution/#32-%EC%85%80%ED%94%84-%EC%96%B4%ED%85%90%EC%85%98self-attention-%ED%8A%B8%EB%9E%9C%EC%8A%A4%ED%8F%AC%EB%A8%B8%EC%9D%98-%ED%95%B5%EC%8B%AC) 레이어들을 지정한다.
    - 이 핵심 모듈들만 튜닝해도 문맥을 이해하고 생성하는 방식을 효과적으로 변경할 수 있어, 메모리를 아끼면서도 높은 성능 향상을 기대할 수 있다.

> **모든 모델의 가중치 행렬의 이름이 같나요?**
> 
> 다르다.  
> 모델의 아키텍처마다 셀프 어텐션 레이어의 가중치 이름이 다를 수 있다.  
> 예) LLaMA는 `q_proj`, `k_proj`, `v_proj`, `o_proj` 이고, GPT-2는 `c_attn`, `c_proj`

- `lora_dropout=0.05`
  - LoRA 레이어에 적용할 드롭아웃(dropout) 비율이다.
  - 학습 중 5%의 확률로 LoRA 가중치의 일부를 임시로 비활성화하여, 모델이 특정 패턴에 과도하게 의존하는 것을 방지하고 일반화 성능을 높여 과적합을 막아준다.

> **드롭아웃(dropout)**
> 
> 드롭아웃은 신경망 학습 과정에서 일부 가중치를 랜덤하게 무시하여 일반화 성능을 높이는 기법이다.  
> 드롭아웃이 없으면 과적합 문제가 발생할 수 있다. 
> 드롭아웃을 적용하면 학습 중 무작위로 일부 뉴런을 제외하면서 더 일반적인 특성을 학습할 수 있도록 유도할 수 있다.

- `task_type="CAUSAL_LM"`
  - LoRA를 적용할 모델의 작업 유형을 명시한다.
  - Gemma, LLaMA와 같은 GPT 계열 모델을 'Causal Language Model(이전 단어들을 기반으로 다음 단어를 예측하는 방식)'이므로 `CAUSAL_LM`으로 설정하여 LoRA가 해당 아키텍처에 맞게 적용되도록 한다.

---

## 4.1. 모델에 LoRA 적용

이제 이 _lora_config_ 설정을 `get_peft_model()` 함수를 사용하여 우리가 로드한 원본 모델에 적용한다.

```python
# 기존의 사전 훈련된 모델에 LoRA 적용
LoRA_model = get_peft_model(model, lora_config)

# 학습 가능한 파라미터 수 확인
LoRA_model.print_trainable_parameters()
```

LoRA 방식으로 모델을 변환하여 기존 모델의 가중치는 그대로 유지하면서 일부 가중치만 추가 학습할 수 있도록 만든다.

**LoRA_model = get_peft_model(model, lora_config)**  
원본 모델에 _lora_config_ 설정을 덧씌워 **PEFT 모델**로 변환한다.  
이 과정에서 **원본 모델의 모든 파라미터는 freeze 되고**, 오직 우리가 `target_modules`로 지정한 레이어에 추가된 LoRA 어댑터의 파라미터($$\Delta W$$)만 '학습 가능'한 상태로 변경된다.

**LoRA_model.print_trainable_parameters()**  
현재 모델에서 실제로 기울기(gradient)가 계산되고 업데이트될 '학습 가능한' 파라미터($$\Delta W$$)의 수를 확인시켜 준다.

```shell
trainable params: 1,171,456 || all params: 1,001,057,408 || trainable%: 0.1170
```

전체 파라미터는 약 10억 개(1,001,057,408)에 달하지만, 우리가 **실제로 학습할 파라미터는 약 117만 개(1,171,456)로 , 전체의 0.117%**에 불과하다.

이것이 바로 LoRA가 '파라미터 효율적(parameter-efficient)'이라고 불리는 이유이다.  
거대한 원본 모델을 건드리지 않고, 이 0.117%의 작은 어댑터만 훈련시켜 모델의 동작을 미세 조정하게 된다.

실행 결과를 보면 전체 파라미터 수는 약 10억 개(1,001,057,408)이고, 이 중 117만개 정도만 학습 가능한 상태이다.
즉, 원래 모델이 있었는데 LoRA 를 덧붙여서 '학습할 부분만 따로 추가하는 변환 과정'이라고 보면 된다.

---

## 4.2. 학습 인자(TrainingArguments) 설정

마지막으로, `transformers` 라이브러리의 `SFTTrainer`에 전달할 학습 관련 하이퍼파라미터를 `TrainingArguments` 클래스로 정의한다.  
이 객체는 훈련 프로세스 전반을 제어하는 설정값들을 담고 있다.

```python
# 학습 인자 설정
training_args = TrainingArguments(
    output_dir="./Gemma-sft-output", # 학습 결과물 저장 경로
    num_train_epochs=1,               # 전체 데이터셋 학습 횟수
    per_device_train_batch_size=4,    # GPU당 배치 크기
    optim="adamw_torch",              # 옵티마이저
    learning_rate=1e-4,               # 학습률 (0.0001)
    logging_steps=10,                 # 로그 출력 빈도 (10 스텝마다)
    report_to="none"                  # 외부 로깅 서비스 비활성화
)
```

**output_dir="./Gemma-sft-outout"**  
학습된 모델 가중치, 로그, 체크포인트 등이 저장될 디렉터리를 지정한다.

> **LoRA 학습 후 어떤 파일이 남나요?**
> 
> LoRA 방식으로 학습하면 10억 개의 파라미터를 가진 전체 모델이 저장되는 것이 아니라, 우리가 추가로 학습한 **LoRA 가중치(어댑터)**만 저장된다.  
> 예) adapter_model.bin, adapter_config.json 등
> 
> 나중에 이 모델을 사용할 때 **반드시 원본 베이스 모델(google/gemma-3-1b-it)을 먼저 불러온 뒤, 이 output_dir에 저장된 LoRA 어댑터를 덧붙여 로드**해야 한다.

**num_train_epochs=1**  
전체 데이터셋을 몇 번 반복하여 학습할지 결정한다.  
1 에포크는 데이터셋 전체를 한 번 학습하는 것을 의미한다.
이 값이 크면 모델이 더 많이 학습하지만 과적합이 발생할 가능성도 높아진다.

**per_device_train_batch_size=4**  
한 번의 학습 스텝에서 GPU가 처리할 수 있는 데이터 샘플의 개수이다.  
T4 GPU의 VRAM(약 16GB)를 고려할 때 4는 안정적인 크기이다. 이 값을 늘리면 학습 속도는 빨라지지만 VRAM을 더 많이 소모한다.

**optim="adamw_torch"**
학습에 사용할 옵티마이저(최적화 알고리즘)이다.  
`AdamW`(Adaptive Moment Estimation with Weight Decay)는 기존 Adam에 과적합을 방지하는 가중치 감소(weight decay) 기법이 추가된 효율적인 옵티마이저이며, `adamw_torch`는 PyTorch에 최적화된 버전이다.

> **가중치 감소**
> 
> 가중치 감소는 모델이 너무 복잡해지는 것을 막기 위해 학습 중에 가중치 값을 조금씩 줄이는 기법이다.
> AI 가 너무 과하게 학습하여 과적합이 발생하는 것을 방지하기 위해 가중치 값을 조금씩 줄인다.

**learning_rate=1e-4**  
학습률을 0.0001로 설정한다.  
모델이 가중치를 얼마나 큰 폭으로 업데이트할 지 결정하는 값이다.  
이 값이 너무 크면 학습이 불안정하고, 너무 작으면 학습이 느려진다.

**logging_steps=10**  
학습을 진행하는 10 스텝마다 학습 손실(loss)과 같은 훈련 상태를 콘솔에 출력한다.  
학습이 잘 진행되고 있는지 모니터링하는데 필수적이다.

**report_to="none"**  
학습 로그를 `wandb(Weights & Biases)`나 `TensorBoard`와 같은 외부 로깅 서비스에 전송하지 않도록 명시적으로 비활성화한다.  
이 설정을 생략하면 `transformers` 라이브러리가 기본적으로 `wandb` 로그인을 시도할 수 있다.  
Colab에서 간편하게 실습하기 위해 none 으로 설정한다.

---

# 5. 학습 데이터셋 불러오기

모델과 학습 설정을 모두 마쳤으니, 이제 모델을 파인튜닝할 재료, 즉 **학습 데이터셋**을 준비할 차례이다.  
여기서는 '소크라테스식 질문법'을 학습시키기 위해 허깅페이스에 공개된 `JosephLee/korean-socratic-qa` 데이터셋을 사용한다.

`load_dataset()` 함수를 사용하면 단 한 줄의 코드로 이 데이터셋을 다운로드하고, 로드할 수 있다.

```python
# 학습 데이터셋 불러오기
# "JosephLee/korean-socratic-qa"는 허깅페이스 허브에 등록된 공개 데이터셋 이름
dataset_name = "JosephLee/korean-socratic-qa"
dataset = load_dataset(dataset_name)

# 데이터셋의 구조와 샘플 데이터 확인
print("dataset structure:", dataset)
print("\nSample data: ", dataset['train'][0])
```

코드를 실행하면 데이터셋의 구조와 실제 샘플 1개를 출력한다.

```shell
dataset structure: DatasetDict({
    train: Dataset({
        features: ['input', 'target'],
        num_rows: 84582
    })
    validation: Dataset({
        features: ['input', 'target'],
        num_rows: 10573
    })
    test: Dataset({
        features: ['input', 'target'],
        num_rows: 10573
    })
})

Sample data:  {'input': '비슷한 논리는 영국이 미국이 세계 경제 강국으로 자리 잡으면서 더 나빠졌다고 주장할 수 있습니다. 
그 주장이 일리가 있을까요? 전혀 그렇지 않습니다. 영국은 미국과의 무역으로 더욱 부유해졌습니다. 
저는 이 답변을 불과 얼마 전까지 개발도상국이었던 한국에서 만든 삼성 휴대폰으로 입력하고 있습니다. 
아마 베트남에서도 더 나은 스마트폰을 개발할 아이들이 있을지도 모릅니다. 
그들이 실제로 만들 수 있을 만큼 부유해지기를 바랍니다. 
귀하의 주장은 본질적으로 중상주의적이며 무역이 제로섬이라고 생각하지만, 실제로 무역은 모든 국가의 소득을 향상시킵니다.', 
'target': '(다른 관점 생각하기) 아무것도 없는 나라들은 어떻습니까?'}
```

- dataset structure
  - 데이터셋이 `train`(학습용, 84,582개), `validation`(검증용), test(테스트용) 3부분으로 나뉘어 있으며, 각 샘플은 `input`, `target` 이라는 두 개의 피처(컬럼)로 구성되어 있음
- Sample data
  - `input`: 우리의 목표는 모델이 `input`과 유사한 내용을 받았을 때, `target`과 같은 스타일의 질문을 생성하도록 학습시키는 것임
  - `target`: 내용에 대해 생각해 볼 만한 '소크라테스식 질문'임

---

## 5.1. `SFTrainer`를 위한 데이터 포맷팅

우리가 사용할 `SFTrainer`는 특정 형식의 데이터를 기대한다.  
일반적으로 모델이 지시문(instruction)이나 프롬프트를 명확히 인지하고 응답을 생성하도록 특정 템플릿에 맞춰 데이터를 재구성해야 한다.

여기서는 `dataset.map()` 함수를 사용하여 전체 데이터셋을 우리가 원하는 형식으로 일괄 변환한다.

```python
# 데이터셋을 SFTTrainer가 인식할 수 있는 프롬프트 형식으로 변환
formatted_dataset = dataset.map(
    lambda x: {
        "text": f"### context: {x['input']}\n### question: {x['target']}"
    }
)

# 변환된 샘플 확인
print(formatted_dataset['train'][0]['text'])
```

**lambda: x: {..}**  
dataset의 모든 샘플 x 에 대해 익명 함수 lambda를 적용한다.

**"text": f"..."**
`input`과 `target` 컬럼을 조합하여 *text*라는 새로운 컬럼을 만든다.

**f"### context: {x['input']}\n### question: {x['target']}"**  
이것이 바로 **프롬프트 템플릿**이다.
- `### context:`는 모델에게 '여기까지가 주어진 문맥이다'라고 알려주는 구분자이다.
- `\n### question:`는 모델에게 '이제 이 문맥에 대해 다음과 같은 질문을 생성해야 한다'라고 지시하는 구분자이다.
- 모델은 이 구조를 학습함으로써, 나중에 `### context: ... \n### question:`라는 프롬프트를 받으면 그 뒤에 올 내용을 생성하도록 유도된다.

변환된 데이터 샘플(text 필드)은 아래와 같은 형식을 갖게 된다.
```shell
### context: 비슷한 논리는 영국이 미국이 세계 경제 강국으로 자리 잡으면서 더 나빠졌다고 주장할 수 있습니다. 그 주장이 일리가 있을까요? 전혀 그렇지 않습니다. 영국은 미국과의 무역으로 더욱 부유해졌습니다. 저는 이 답변을 불과 얼마 전까지 개발도상국이었던 한국에서 만든 삼성 휴대폰으로 입력하고 있습니다. 아마 베트남에서도 더 나은 스마트폰을 개발할 아이들이 있을지도 모릅니다. 그들이 실제로 만들 수 있을 만큼 부유해지기를 바랍니다. 귀하의 주장은 본질적으로 중상주의적이며 무역이 제로섬이라고 생각하지만, 실제로 무역은 모든 국가의 소득을 향상시킵니다.
### question: (다른 관점 생각하기) 아무것도 없는 나라들은 어떻습니까?
```

---

## 5.2. 데이터셋 크기 조절

전체 학습 데이터(8만 4천 개)를 모두 학습하려면 Colab T4 환경에서도 상당한 시간이 소요된다.  
파인튜닝 코드가 정상적으로 작동하는지 빠르게 테스트하고 검증하기 위해, 학습용 데이터셋을 1,000개로 임시로 줄여서 사용한다.

```python
# 빠른 실습을 위해 학습용 데이터셋 크기를 1,000개로 조절
formatted_dataset['train'] = formatted_dataset['train'].select(range(1000))

print(formatted_dataset)
```

```shell
DatasetDict({
    train: Dataset({
        features: ['input', 'target', 'text'],
        num_rows: 1000
    })
    validation: Dataset({
        features: ['input', 'target', 'text'],
        num_rows: 10573
    })
    test: Dataset({
        features: ['input', 'target', 'text'],
        num_rows: 10573
    })
})
```

학습용 데이터셋 중 앞쪽 샘플 1000개만 추려서 학습에 사용할 수 있도록 데이터셋 크기를 임시로 줄이는 전처리 단계이다.
모델을 전체 데이터로 돌리기 전에 간단히 빠른 실험이나 검증을 하기 위해 유용하다.

---

# 6. SFT 트레이너 설정 및 학습 시작

지금까지 모델, LoRA 설정, 학습 인자, 데이터셋까지 모든 준비를 마쳤으니, 이제 이것들을 하나로 조립하여 실제 학습을 진행할 `SFTTrainer`를 설정한다.

`SFTTrainer`는 `trl` 라이브러리에서 제공하는 도구로, SFT(지도 학습 파인튜닝) 과정을 매우 간편하게 만들어준다.  
특히, LoRA와 같은 PEFT 기법과 잘 호환되도록 최적화되어 있다.

```python
# SFT 트레이너 설정 (trl 0.24.0 호환 버전)
trainer = SFTTrainer(
    model=LoRA_model, # 미리 생성한 PEFT 모델
    train_dataset=formatted_dataset['train'], # 미리 준비한 학습 데이터셋
    args=training_args, # 미리 정의한 학습 인자
    formatting_func=lambda x: x['text'], # 미리 정의한 프롬프트 템플릿 사용
    # 'tokenizer=' 대신 'processing_class='를 사용(이것이 0.24.0 버전의 방식)
    processing_class=tokenizer,
)
```

`SFTTrainer`를 초기화할 때 사용된 주요 인자는 아래와 같다.

**model=LoRA_model**  
학습할 모델을 지정한다.  
SFTTrainer는 LoRA가 적용된 모델을 학습하므로 원본 모델이 아닌 LoRA를 적용한 모델을 전달해야 한다.  
여기서는 앞에서 설정한 `get_peft_model(base_model, lora_config)`를 통해 LoRA 어댑터가 적용된 _LoRA_model_을 넣는다.

**train_dataset=formatted_dataset['train']**  
학습에 사용할 데이터셋을 지정한다.  
앞에서 지정한 1,000개로 축소한 학습 데이터를 사용한다.

**args=training_args**  
이전에 `TrainingArguments` 로 정의한 모든 하이퍼파라미터(출력 경로, 에포크, 배치 크기, 학습률 등)을 전달한다.

**formatting_func=lambda x: x['text']**  
`SFTTrainer`의 핵심 편의 기능이다.  
`SFTTrainer`가 내부적으로 `dataset.map()` 을 다시 실행할 때 사용할 함수를 지정하는 방식이다.  
여기서는 이미 _text_ 필드로 포맷팅했으므로, _text_ 필드의 내용을 그대로 반환하도록 지정한다.

---

## 6.1. 학습 실행

```python
# 학습 실행
trainer.train()
```
위 코드를 실행하면 아래와 같은 복잡한 과정이 순차적으로 수행된다.

- **데이터셋 전처리**
  - `train_dataset`의 _text_ 필드 내용을 `tokenizer`를 사용해 숫자 토큰 ID로 변환한다.
  - 이 과정에서 `tokenizer.pad_token` 설정이 사용되어 배치마다 길이를 맞추는 패딩 작업이 자동으로 이루어진다.
- **배치 생성**
  - 전처리된 데이터를 `per_device_train_batch_size`(여기서는 4) 크기의 미니 배치로 분할한다.
- **학습 루프 시작**
  - `num_train_epochs`(여기서는 1)만큼 데이터셋 전체를 반복 학습한다.
- **모델 업데이트 및 손실 계산**
  - 각 배치를 GPU로 이동시켜서 _LoRA_model_에 입력하고 예측값을 생성한다.
  - 이 때 **원본 모델 파라미터(0.117% 외)는 freeze**되어 있으며, 오직 LoRA 어댑터 가중치만 예측에 관여하고 업데이트된다.
  - 모델의 예측값과 실제 정답(레이블)을 비교하여 **손실(loss)**값을 계산한다.
  - `optim="adamw_torch` 옵티마이저가 이 손실값을 기반으로 `learning_rate=1e-4`를 적용하여 **LoRA 가중치($$\Delta W$$)만** 업데이트(역전파)한다.
- **로그 출력**
  - `loggin_steps=10` 설정에 따라, 10 스텝마다 현재 학습 손실(loss), 학습 속도 등의 상태를 콘솔에 출력한다.
- **학습 종료 및 저장**
  - 1 에포크(1,000개 데이터 / 배치 4 = 250 스텝)가 모두 완료되면 학습 루프를 종료하고, `output_dir="./Gemma-sft-output"` 경로에 학습된 결과물을 자동으로 저장한다.

---

## 6.2. 모델 저장

`trainer.train()`이 완료되면 자동으로 모델이 저장되지만, 명시적으로 `save_model()`을 호출하여 최종 모델을 한 번 더 저장할 수도 있다.

```python
# 모델 저장
trainer.save_model()
print("모델 저장이 완료되었습니다. ./Gemma-sft-output 에서 확인하세요.")
```

이 명령어를 실행하면 `output_dir` 로 지정한 _./Gemma-sft-output_ 폴더에 학습 결과물이 저장된다.

중요한 점은, 이 폴더에는 Gemma 1B 모델의 전체 가중치(수 GB) 가 저장되는 것이 아니라, 오직 우리가 추가로 학습한 **LoRA 어댑터 가중치(adapter_model.bin)**와 
관련 설정 파일(adapter_config.json) 등 **수 MB** 크기의 작은 파일들만 저장된다는 것이다.  
이것이 LoRA가 제공하는 스토리지 효율성이다.

---

# 7. 학습 모델 추론

파인튜닝이 완료되었으니, 학습된 모델이 정말로 우리가 의도한 대로 작동하는지 확인해본다.

`transformers` 라이브러리의 `pipeline`은 학습된 모델을 사용해서 실제 텍스트 생성을 테스트하는 가장 간편한 방법이다.

---

## 7.1. 텍스트 생성 파이프라인 설정

먼저, `text-generation`(텍스트 생성) 작업을 수행할 파이프라인을 설정한다.  
이 때 원본 model 이 아닌 LoRA가 적용된 _LoRA_model_을 지정한다.

```python
from transformers import pipeline

# LLM 추론을 위한 텍스트 생성 파이프라인 설정
pipe = pipeline(
    "text-generation",  # 수행할 작업
    model=LoRA_model,     # LoRA 어댑터가 적용된 모델
    tokenizer=tokenizer,  # 로드한 토크나이저
    device_map="auto"     # GPU 자동 할당
)
```

**pipe = pipeline(...)**  
`transformers` 라이브러리에 내장된 고수준 API로, 텍스트 생성에 필요한 모든 전후 처리 과정을 자동으로 설정해준다.

**model=LoRA_model**  
_trainer_ 를 통해 학습이 완료된 _LoRA_model_ 객체를 그대로 전달한다.  
이 모델은 원본 Gemma 1B 가중치 위에 우리가 학습시킨 LoRA 어댑터를 덧입힌 상태이다.

**device_map="auto"**  
`cuda:0` (첫 번째 GPU)와 같이 사용 가능한 장치에 모델을 자동으로 배치하여 추론 속도를 최적화한다.

```shell
Device set to use cuda:0
```

---

## 7.2 프롬프트 정의

이제 모델에게 질문을 던질 프롬프트를 만들 차례이다.  
모델이 학습할 때 사용했던 _formatted_dataset_의 템플릿과 **반드시 동일한 형식**을 사용해야 한다.

_test_ 데이터셋의 10번째 input을 가져와 _### context: {question}\n\n### question: _ 템플릿에 맞춰 프롬프트를 구성한다.

```python
# 프롬프트 정의
# 테스트 데이터셋에서 샘플 질문(context) 가져오기
question = dataset['test'][10]['input']

# 학습 시 사용한 템플릿과 동일하게 프롬프트 구성
prompt = f"### context: {question}\n\n### question: "

print(prompt)
```

생성된 프롬프트는 아래와 같다.  
_### question: _ 뒤에 올 '소크라테스식 질문'을 생성하도록 유도될 것이다.

```shell
### context: 배경: 스웨덴인으로서, 이 관점은 주로 2015년 난민 위기 동안의 과거 이민 정책에서 비롯된 것입니다. 당시 스웨덴은 인구 대비 신규 난민 신청자 수가 유럽에서 두 번째로 많았습니다. 많은 사람들을 사회에 통합하지 못했고, 이는 사회적 배척, 범죄율 상승 및 평행 사회 형성을 초래했습니다. 이 주제는 많은 이들과 논의하기 매우 어려운 듯합니다. 이는 많은 양극화, 허수아비 논증 및 상호 비방이 존재하기 때문입니다. 저는 그저 양측의 명확한 주장을 알고 싶습니다. 제가 다양한 관점을 듣고 싶은 첫 번째 지점은, 망명을 원하여 찾아오는 사람들을 어떻게 정의하는지입니다.

### question: 
```

---

## 7.3. 모델 추론 실행

이제 파이프라인을 통해 모델의 응답을 생성한다.

```python
# 파이프라인을 이용해 모델 예측 실행
outputs = pipe(
    prompt,
    max_new_tokens=256,  # 최대 생성 토큰 수
    temperature=0.9      # 생성 다양성 조절
)

# 생성된 텍스트 결과 확인
print(outputs[0]["generated_text"])
```

**outputs = pipe(...)**  
프롬프트를 모델에 입력하여 텍스트 생성을 시작한다.

**[temperature=0.9](https://assu10.github.io/dev/2025/10/24/ai-ml-llm-4bit-quantization-llama3-colab/#631-temperature)**  
생성 과정의 무작위성을 조절하는 값이다.
그리고 출력된 텍스트를 반환한다.  

---

## 7.4. 파인튜닝 결과 확인

모델이 생성한 전체 텍스트(generated_text)는 아래와 같다.

```shell
### context: 배경: 스웨덴인으로서, 이 관점은 주로 2015년 난민 위기 동안의 과거 이민 정책에서 비롯된 것입니다. 당시 스웨덴은 인구 대비 신규 난민 신청자 수가 유럽에서 두 번째로 많았습니다. 많은 사람들을 사회에 통합하지 못했고, 이는 사회적 배척, 범죄율 상승 및 평행 사회 형성을 초래했습니다. 이 주제는 많은 이들과 논의하기 매우 어려운 듯합니다. 이는 많은 양극화, 허수아비 논증 및 상호 비방이 존재하기 때문입니다. 저는 그저 양측의 명확한 주장을 알고 싶습니다. 제가 다양한 관점을 듣고 싶은 첫 번째 지점은, 망명을 원하여 찾아오는 사람들을 어떻게 정의하는지입니다.

### question: 2015년 난민 위기 당시 스웨덴은 다른 서유럽 국가들보다 난민 신청자 수가 많았습니다. 어떤 국가가 이 경우에는 더 많은 난민을 받아들였습니다
```

_### question: _ 뒷부분을 보면, 모델은 주어진 context 의 내용("스웨덴은... 두 번째로 많았습니다.")을 기반으로 "어떤 국가가 이 경우에는 더 많은 난민을 받아들였습니다."라는, 
문맥과 관련된 새로운 질문을 생성해냈다.

이는 우리가 `JosephLee/korean-socratic-qa` 데이터셋으로 학습시킨 소크라테스식 질문 스타일을 모델이 성공적으로 학습했다는 증거이다.

만일 파인튜닝하지 않은 일반 `google/gemma-3-1b-it` 모델에 동일한 프롬프트를 제공했다면, 아마도 context의 내용을 요약하거나, input에 대한 직접적인 답변을 
시도하는 등, 전혀 다른 방식의 응답을 생성했을 것이다.

이로써 **LoRA를 사용한 PEFT(파라미터 효율적 파인튜닝)**를 통해, 거대한 LLM의 원본은 그대로 둔 채, 0.117%의 파라미터만 튜닝하여 모델의 응답 스타일을 우리가 
원하는 방향으로 '미세 조정'하는데 성공했다.

---

전체 코드
```python
# LLM 파인튜닝 및 데이터 처리를 위한 핵심 라이브러리 설치
!pip install -q -U datasets trl peft

import torch
from datasets import load_dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    pipeline
)
import trl
from trl import SFTTrainer
from peft import LoraConfig, get_peft_model

print(f"현재 로드된 TRL 버전: {trl.__version__}")

# 허깅페이스 로그인
from google.colab import userdata
from huggingface_hub import login

# Colab 보안 비밀에 저장된 LLAMA_HF_TOKEN 값 불러옴
hf_token = userdata.get('FINE_TOKEN')

print(f"현재 로드된 토큰 (앞/뒤 5자리): {hf_token[:5]}...{hf_token[-5:]}")

# 허깅페이스 허브에 로그인
login(token = hf_token)

# 파인튜닝에 사용할 모델 불러오기
model_id = "google/gemma-3-1b-it"

tokenizer = AutoTokenizer.from_pretrained(
    model_id,
    token=hf_token
)
# 패딩 토큰을 EOS 토큰으로 설정 (중요)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    dtype=torch.float16,  # 16비트 반정밀도로 로드
    device_map="auto",    # 사용 가능한 장치(GPU)에 자동 할당
    token=hf_token,
)

# LoRA 설정
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_prog", "k_proj", "v_proj", "o_prog"],
    lora_dropout=0.05,
    task_type="CAUSAL_LM",
)

# 기존의 사전 훈련된 모델에 LoRA 적용
LoRA_model = get_peft_model(model, lora_config)

# 학습 가능한 파라미터 수 확인
LoRA_model.print_trainable_parameters()

# 학습 인자 설정
training_args = TrainingArguments(
    output_dir="./Gemma-sft-output", # 학습 결과물 저장 경로
    num_train_epochs=1,               # 전체 데이터셋 학습 횟수
    per_device_train_batch_size=4,    # GPU당 배치 크기
    optim="adamw_torch",              # 옵티마이저
    learning_rate=1e-4,               # 학습률 (0.0001)
    logging_steps=10,                 # 로그 출력 빈도 (10 스텝마다)
    report_to="none"                  # 외부 로깅 서비스 비활성화
)

# 학습 데이터셋 불러오기
# "JosephLee/korean-socratic-qa"는 허깅페이스 허브에 등록된 공개 데이터셋 이름
dataset_name = "JosephLee/korean-socratic-qa"
dataset = load_dataset(dataset_name)

# 데이터셋의 구조와 샘플 데이터 확인
print("dataset structure:", dataset)
print("\nSample data: ", dataset['train'][0])

# 데이터셋을 SFTTrainer가 인식할 수 있는 프롬프트 형식으로 변환
formatted_dataset = dataset.map(
    lambda x: {
        "text": f"### context: {x['input']}\n### question: {x['target']}"
    }
)

# 변환된 샘플 확인
print(formatted_dataset['train'][0]['text'])

# 빠른 실습을 위해 학습용 데이터셋 크기를 1,000개로 조절
formatted_dataset['train'] = formatted_dataset['train'].select(range(1000))

print(formatted_dataset)

# SFT 트레이너 설정 (trl 0.24.0 호환 버전)
trainer = SFTTrainer(
    model=LoRA_model, # 미리 생성한 PEFT 모델
    train_dataset=formatted_dataset['train'], # 미리 준비한 학습 데이터셋
    args=training_args, # 미리 정의한 학습 인자
    formatting_func=lambda x: x['text'], # 미리 정의한 프롬프트 템플릿 사용
    # 'tokenizer=' 대신 'processing_class='를 사용(이것이 0.24.0 버전의 방식)
    processing_class=tokenizer,
)

print("trl 0.24.0 버전에 맞는 SFTTrainer 설정 완료")

# 학습 실행
trainer.train()

# 모델 저장
trainer.save_model()
print("모델 저장. ./Gemma-sft-output 에서 확인하세요.")

from transformers import pipeline

# LLM 추론을 위한 텍스트 생성 파이프라인 설정
pipe = pipeline(
    "text-generation",  # 수행할 작업
    model=LoRA_model,     # LoRA 어댑터가 적용된 모델
    tokenizer=tokenizer,  # 로드한 토크나이저
    device_map="auto"     # GPU 자동 할당
)

# 프롬프트 정의
# 테스트 데이터셋에서 샘플 질문(context) 가져오기
question = dataset['test'][10]['input']

# 학습 시 사용한 템플릿과 동일하게 프롬프트 구성
prompt = f"### context: {question}\n\n### question: "

print(prompt)

# 파이프라인을 이용해 모델 예측 실행
outputs = pipe(
    prompt,
    max_new_tokens=256,  # 최대 생성 토큰 수
    temperature=0.9      # 생성 다양성 조절
)

# 생성된 텍스트 결과 확인
print(outputs[0]["generated_text"])
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 이영호 저자의 **모두의 인공지능 with 파이썬**을 기반으로 스터디하며 정리한 내용들입니다.*

* [모두의 인공지능 with 파이썬](https://product.kyobobook.co.kr/detail/S000217061005)
* [Google Colab](https://colab.research.google.com)