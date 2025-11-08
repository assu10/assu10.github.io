---
layout: post
title:  "AI - LangChain과 4-bit LLM으로 RAG 구축"
date: 2025-10-25
categories: dev
tags: ai ml rag llm langchain faiss bitsandbytes quantization 4-bit-quantization transformers pypdf retrieval-augmented-generation vector-database embeddings phi-4 hallucination
---

최근 챗GPT와 같은 LLM 서비스는 사용자가 PDF나 텍스트 파일을 업로드하고, 해당 파일의 내용을 기반으로 대화를 나누는 기능을 제공한다. 이러한 시스템은 과연 어떤 
원리로 작동하는 걸까?

기존의 LLM은 방대한 데이터를 학습했지만, 근본적으로 **학습 시점까지의 지식에 한정**된다는 명확한 한계를 가진다.  
따라서 사용자가 방금 첨부한 최신 문서나, 모델이 학습한 적 없는 내부 데이터, 특정 전문 분야의 정보에 대해서는 정확한 답변을 생성하기 어렵다.

심지어, LLM은 때때로 존재하지 않는 정보를 그럴듯하게 지어내는 **환각(Hallucination) 현상**을 보이기도 한다.

이러한 LLM의 본질적인 한계를 극복하기 위해 등장한 기술이 바로 **검색 증강 생성(RAG, Retrieval-Augmented Generation)**이다.

RAG는 이름 그대로 '검색(Retrieval)'을 통해 모델의 지식을 '증강(Augmented)'하여 답변을 '생성(Generation)'하는 방식이다.  
즉, 언어 모델이 자체 지식만으로 답변을 생성하기 전에, 사용자의 질문과 관련된 정보를 **먼저 외부 문서나 데이터베이스에서 검색**한다. 그리고 이 검색된 최신 정보를 
바탕으로 답변을 생성한다.

이 구조를 통해 모델은 자신이 알지 못했던 내용에 대해서도 관련 근거를 찾아 더 정확하고 신뢰할 수 있는 응답을 제공할 수 있다.

이 포스트에서는 RAG 기법을 직접 활용하여 사용자가 첨부한 파일 내용을 기반으로 질문하고 대답하는 실용적인 AI 시스템을 함께 구축해본다.

---

**목차**

<!-- TOC -->
* [1. RAG(Retrieval-Augmented Generation): 검색 증강 생성 작동 원리](#1-ragretrieval-augmented-generation-검색-증강-생성-작동-원리)
* [2. 라이브러리 설치](#2-라이브러리-설치)
  * [2.1. LangChain(랭체인)](#21-langchain랭체인)
* [3. LLM 양자화하여 불러오기](#3-llm-양자화하여-불러오기)
  * [3.1. 허깅페이스 로그인](#31-허깅페이스-로그인)
  * [3.2. 4비트 양자화 설정 및 모델 로드](#32-4비트-양자화-설정-및-모델-로드)
    * [3.2.1. 모델은 4비트로 양자화했는데 연산(compute_dtype)은 16비트로 하는 이유](#321-모델은-4비트로-양자화했는데-연산compute_dtype은-16비트로-하는-이유)
  * [3.3. 텍스트 생성 파이프라인 설정](#33-텍스트-생성-파이프라인-설정)
* [4. 검색 증강 생성을 위한 데이터베이스 생성](#4-검색-증강-생성을-위한-데이터베이스-생성)
* [5. 검색 증강 생성으로 모델 추론](#5-검색-증강-생성으로-모델-추론)
  * [5.1. RAG 추론 함수 정의](#51-rag-추론-함수-정의)
  * [5.2. RAG 실행 및 결과 확인](#52-rag-실행-및-결과-확인)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. RAG(Retrieval-Augmented Generation): 검색 증강 생성 작동 원리

우리가 AI 챗봇을 사용할 때, 종종 사실과 다른 내용을 그럴듯하게 말하거나(환각, Hallucination) 특정 정보는 알지 못한다고 답변하는 경우를 경험한다. 
이는 대부분의 LLM이 **사전에 학습된 데이터만을 바탕으로 답변을 생성**하기 때문이다. 모델의 지식은 학습이 종료된 시점에 멈춰있어, 최신 정보나 사용자가 제공하는 
특정 문서의 내용을 알지 못한다.

이러한 LLM의 근본적인 한계를 해결하는 기술이 바로 RAG이다.

RAG는 LLM이 값비용으로 재학습(re-training) 시키는 대신, AI가 답변을 생성하기 전에 **필요한 정보를 외부 데이터베이스에서 실시간으로 '검색(Retrieval)'하고, 이 정보를 
바탕으로 '증강(Augmented)'하여 '생성(Generation)'하는 방식**이다.

기존 LLM이 '암기한 지식'만으로 답하는 폐쇄형이었다면, RAG는 참고 자료를 먼저 찾아보고 답하는 개방형으로 볼 수 있다. 이 차이점 덕분에 RAG는 훨씬 더 정확하고 
신뢰도 높은 답변을 생성할 수 있다.

---

RAG 작동 원리는 크게 두 가지 단계로 나뉜다.

**1단계: 데이터 준비(Indexing) - 참고 자료 만들기**  
LLM이 사용자의 문서를 참고할 수 있도록, 문서를 미리 인덱싱해두는 과정이다. 이 과정은 사용자가 질문하기 전에 미리 수행된다.

**1-1. 데이터 로드(Load)**: 먼저, AI가 참고할 문서를 불러온다.(예: PDF, TXT, Docx 파일 등)  
**1-2. 분할(Split)**: 문서 전체는 LLM이 한 번에 처리하기에 너무 크다. 따라서 문서를 의미 있는 단위의 작은 조각(Chunk)으로 나눈다.(예: 문단, 문장 단위)  
**1-3. 임베딩(Embed)**: 컴퓨터는 텍스트를 직접 이해할 수 없다. 따라서 각 텍스트 조각을 '임베딩 모델'을 사용해 **숫자 벡터로 변환**한다. 이 벡터는 해당 텍스트의 '의미'를 담고 있는 좌표값이다.  
**1-4. 저장(Store)**: 변환된 벡터들을 검색에 용이하도록 **벡터 데이터베이스(Vector Store)**에 저장한다. 이로써 AI가 참고할 수 있는 지식 창고가 완성된다.

---

**2단계: 검색 및 생성(Retrieval & Generation) - 참고 자료를 참고하여 답변하기**  
사용자가 실제로 질문을 했을 때 RAG가 답변을 생성하는 과정이다.

**2-1. 질문 임베딩(Embed Query)**: 사용자의 질문(Query) 역시 1단계에서 사용한 것처럼 임베딩 모델을 사용해 벡터로 변환한다.  
**2-2. 검색(Retrieve)**: 이 질문 벡터와 벡터 DB에 저장된 문서 조각 벡터들 간의 '의미적 유사도'를 계산한다. 그리고 **질문과 가장 관련성이 높은(가장 가까운) 문서 조각(Chunk) N개를 검색**해 가져온다.  
**2-3. 증강 및 생성(Augment & Generation)**: LLM에게 질문과 함께, 2단계에서 검색된 관련성 높은 문서 조각들을 컨텍스트 또는 참고 자료로 함께 전달한다.  
프롬프트 예) '다음 [참고 자료]를 바탕으로 이 [질문]에 답해줘. [참고자료]: (검색된 문서 조각들..), [질문]: (사용자의 실제 질문...)'  
**2-4. 답변(Response)**: LLM은 제공된 참고 자료(Context)에 기반하여 질문에 대한 정확하고 신뢰할 수 있는 답변을 생성한다.

---

이처럼 RAG는 LLM의 환각 현상을 획기적으로 줄이고, 모델이 학습하지 않은 최신 정보나 특정 도메인 지식에 대해서도 근거를 가지고 답변할 수 있도록 돕는다.

이 포스트에서는  직접 PDF 파일을 불러오고, 텍스트를 잘게 나누고, 숫자 벡터로 바꾼 후 AI가 질문에 따라 그 벡터를 검색해서 답을 생성하도록 만들어본다.  
이 과정을 통해 RAG 가 어떻게 작동하는지, 왜 이런 방식이 신뢰도 높은 인공지능 응답을 이끌어 내는지 알아본다.

---

# 2. 라이브러리 설치

RAG 시스템을 구축하기 위해 필요한 파이썬 라이브러리들을 설치한다.
Colab 에서 [런타임] - [런타임 유형 변경] 에서 T4 GPU를 선택한다.

먼저 `pip` 명령어를 사용해 RAG 파이프라인 구축에 필수적인 라이브러리들을 설치한다.

```python
!pip install langchain langchain-community bitsandbytes faiss-cpu pypdf
```

> `!pip install` 에 대한 내용은 [3. 라이브러리 설치](https://assu10.github.io/dev/2025/10/24/ai-ml-llm-4bit-quantization-llama3-colab/#3-%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC-%EC%84%A4%EC%B9%98)를 참고하세요.

설치가 완료되었으면 RAG 시스템의 각 기능을 수행할 모듈들을 임포트한다.

```python
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig, pipeline

from langchain.document_loaders import PyPDFLoader
from langchain.text_splitter import CharacterTextSplitter
from langchain.vectorstores import FAISS
from langchain.embeddings import HuggingFaceEmbeddings
from google.colab import files
```

각 라이브러리가 RAG 파이프라인에서 어떤 역할을 하는지 살펴보자.

**from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig, pipeline**  
- `AutoModelForCausalLM`: 텍스트 생성을 수행하는 LLM(예: Llama 3, GPT-2)를 쉽게 로드한다. 텍스트를 생성하는 인공지능 모델을 쉽게 불러온다.
- `AutoTokenizer`: 텍스트를 모델이 이해할 수 있는 숫자 토큰으로 변환한다.
- `BitsAndBytesConfig`: 거대한 LLM을 T4 GPU 같은 제한된 환경에서도 실행할 수 있도록, 모델을 양자화하여 메모리 사용량을 최적화한다.
- `pipeline`: 복잡한 AI 작업을(예: 텍스트 생성) 몇 줄의 코드로 간단하게 실행할 수 있게 돕는 유틸리티이다.

**from langchain.document_loaders import PyPDFLoader**  
RAG의 핵심인 '검색(Retrieval)' 대상이 될 외부 문서를 불러온다.  
PyPDFLoader는 PDF 문서를 로드하고 텍스트를 추출하여 AI가 처리할 수 있는 형식으로 준비한다.

**from langchain.text_splitter import CharacterTextSplitter**  
긴 문서를 AI가 효율적으로 처리할 수 있도록 작은 조각(Chunk)으로 분할한다.  
LLM은 한 번에 처리할 수 있는 텍스트의 양(Context Window)에 한계가 있다. 문서를 적절한 크기로 나누어야 메모리 과부하를 방지하고, 검색 및 임베딩 작업의 
정확도를 높일 수 있다.

**from langchain.vectorstores import FAISS**  
텍스트 조각들을 저장하고 빠르게 검색할 수 있는 '벡터 데이터베이스' 역할을 한다.  
FAISS(Facebook AI Similarity Search)는 Meta AI에서 개발한 고속 유사도 검색 라이브러리로, 수많은 텍스트 벡터 중에서 사용자의 질문 벡터와 의미적으로 
가장 유사한 조각을 순식간에 찾아낸다.

**from langchain.embeddings import HuggingFaceEmbeddings**  
모든 텍스트(문서 조각, 사용자 질문)를 컴퓨터가 의미를 비교할 수 있도록 **숫자 벡터로 변환(임베딩)**한다.  
HuggingFaceEmbeddings는 허깅페이스의 다양한 임베딩 모델을 쉽게 가져와 사용할 수 있게 해준다. 
이 벡터의 품질이 RAG 검색 성능을 좌우한다.

**from google.colab import files**  
Google Colab 환경에서 사용자가 직접 PDF 파일을 업로드하거나 받을 수 있도록 파일 관리 기능을 제공한다.

---

## 2.1. LangChain(랭체인)

랭체인은 RAG와 같은 복잡한 LLM 애플리케이션을 쉽게 개발하도록 돕는 프레임워크이다.

랭체인은 위에서 설명한 문서 로드(Load), 분할(Split), 저장(Store), 검색(Retrieve), 생성(Generate) 등 RAG의 모든 단계를 마치 체인처럼 매끄럽게 
연결하고 조율하는 역할을 한다.  
랭체인을 사용하면 PDF 문서에서 정보를 검색하고, LLM이 이 정보를 바탕으로 답변을 생성하도록 하는 일련의 과정을 훨씬 효율적으로 구현할 수 있다.

---

# 3. LLM 양자화하여 불러오기

RAG 시스템의 핵심 구성 요소인 LLM을 메모리에 로드한다. RAG는 LLM을 기반으로 답변을 생성하므로, 먼저 이 LLM을 준비하는 과정이 필요하다.

여기서는 Microsoft가 공개한 `microsoft/phi-4` 모델을 사용한다.  
이 모델은 강력한 성능을 제공하지만, T4 GPU와 같은 Colab 환경에서 원활하게 실행하기 위해서는 **4비트 양자화**를 적용하여 모델의 메모리 사용량을 획기적으로 줄여야 한다.

---

## 3.1. 허깅페이스 로그인

phi-4와 같은 특정 모델은 사용 전 접근 동의가 필요할 수 있다. 이를 위해 Colab 환경에서 허깅페이스에 로그인한다.

다음으로 [허깅페이스 허브에 접근하기 위한 인증 토큰을 설정](https://assu10.github.io/dev/2025/10/19/ai-ml-llm-huggingface-colab-tutorial/#2-%ED%97%88%EA%B9%85%ED%8E%98%EC%9D%B4%EC%8A%A4-%EC%A0%91%EA%B7%BC-%EC%BD%94%EB%93%9C-%EB%B0%9C%EA%B8%89)한다.

```python
# LLM 양자화하여 불러오기
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

## 3.2. 4비트 양자화 설정 및 모델 로드

이제 `bitsandbytes` 라이브러리를 사용해 4비트 양자화 설정을 정의한다. 이 설정은 모델이 메모리에 로드될 때 적용된다.

```python
# phi-4 모델을 4비트로 양자화하여 불러오기
model_id = "microsoft/phi-4"

# 4비트 양자화 설정 (BitsAndBytesConfig)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,  # 4비트 양자화 활성화
    bnb_4bit_compute_dtype=torch.bfloat16, # 실제 연산 시 사용할 데이터 타입 (16비트)
    bnb_4bit_use_double_quant=True,     # 이중 양자화를 사용해 정밀도 향상
    bnb_4bit_quant_type="nf4",          # NF4 (NormalFloat 4-bit) 타입 사용
)

# 토크나이저 로드
tokenizer = AutoTokenizer.from_pretrained(model_id)

# 4비트 양자화 설정을 적용하여 모델 로드
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=bnb_config,  # 위에서 정의한 4비트 양자화 설정 적용
    device_map="auto",             # 사용 가능한 하드웨어(CPU, GPU)에 모델을 자동 배치
    token=hf_token
)
```

> BitsAndBytesConfig, model_id 에 대한 좀 더 상세한 내용은  
> [4. 모델 양자화 설정](https://assu10.github.io/dev/2025/10/24/ai-ml-llm-4bit-quantization-llama3-colab/#4-%EB%AA%A8%EB%8D%B8-%EC%96%91%EC%9E%90%ED%99%94-%EC%84%A4%EC%A0%95),  
> [5. 토크나이저 및 모델 불러오기](https://assu10.github.io/dev/2025/10/24/ai-ml-llm-4bit-quantization-llama3-colab/#5-%ED%86%A0%ED%81%AC%EB%82%98%EC%9D%B4%EC%A0%80-%EB%B0%8F-%EB%AA%A8%EB%8D%B8-%EB%B6%88%EB%9F%AC%EC%98%A4%EA%B8%B0)  
> 를 참고하세요.

AutoModelForCausalLM.from_pretrained() 함수는 _model_id_ 를 기반으로 허깅페이스 허브에서 모델을 다운로드한다. 이 때 원본 모델(float32)을 내려받지만, 
`quantization_config=bnb_config` 설정에 따라 메모리에 적재될 때는 **4비트로 양자화되어 올라간다.**  
이 덕분에 훨씬 적은 GPU VRAM으로도 모델을 실행할 수 있다. 실제 연산은 torch.float16 데이터 타입으로 수행된다.

---

### 3.2.1. 모델은 4비트로 양자화했는데 연산(compute_dtype)은 16비트로 하는 이유

위에서 `bnb_4bit_compute_dtype=torch.bfloat16` 설정이 중요하다. 우리가 말하는 '4비트 양자화'는 모델의 **가중치를 저장**할 때 사용하는 비트 수를 의미한다.

하지만 대부분의 최신 GPU는 4비트 연산을 직접 지원하지 않는다. 4비트로 바로 계산하면 속도가 느리고 정확도가 떨어진다.

따라서 RAG 시스템은 아래와 같이 작동한다.
- **저장(Store)**
  - 모델 가중치는 4비트로 GPU 메모리에 **저장**되어 공간을 절약한다.
- **연산(Computation)**
  - 실제 텍스트 생성(추론)을 위한 계산이 필요할 때, 4비트 가중치를 일시적으로 **16비트(bfloat16)**로 변환하여 연산을 수행한다.

즉, **저장은 4비트로, 계산은 16비트로** 처리함으로써, 메모리 절감 효과와 GPU의 빠른 연산 속도라는 두 마리 토끼를 모두 잡는 효율적인 방식이다.

---

## 3.3. 텍스트 생성 파이프라인 설정

이제 텍스트 생성 파이프라인을 만들어준다.
```python
# 텍스트 생성 파이프라인 만들기
pipe = pipeline(
    "text-generation",    # 수행할 작업 (텍스트 생성)
    model=model,          # 양자화하여 로드한 모델
    tokenizer=tokenizer,  # 로드한 토크나이저
    device_map="auto"
)
```

```shell
Device set to use cuda:0
```

허깅페이스의 pipeline API는 텍스트 생성, 번역, 요약 등 복잡한 NLP 작업을 추상화하여 몇 줄의 코드로 간단히 실행할 수 있게 해준다.

> pipeline 설정에 대한 내용은 [6.1. LLM의 추론 파이프라인 설정](https://assu10.github.io/dev/2025/10/24/ai-ml-llm-4bit-quantization-llama3-colab/#61-llm%EC%9D%98-%EC%B6%94%EB%A1%A0-%ED%8C%8C%EC%9D%B4%ED%94%84%EB%9D%BC%EC%9D%B8-%EC%84%A4%EC%A0%95)을 참고하세요.

---

# 4. 검색 증강 생성을 위한 데이터베이스 생성

이제 RAG 시스템의 두뇌에 해당하는 LLM이 참고할 오픈북(지식 창고)을 만들 차례이다.  
이 과정은 [1. RAG(Retrieval-Augmented Generation): 검색 증강 생성 작동 원리](#1-ragretrieval-augmented-generation-검색-증강-생성-작동-원리) 에서 말한
**1단계: 데이터 준비(Indexing) - 참고 자료 만들기** 에 해당한다.

사용자가 업로드한 문서를 LLM이 검색하고 이해할 수 있는 형태로 가공하여 **벡터 데이터베이스(Vector Store)**에 저장한다.

> 여기서 사용할 PDF 파일을 준비해야 한다.  
> https://bit.ly/3GqjRGI 에서 deepseek.pdf 를 다운로드한 후, Google Colab 에 미리 업로드한다.  
> 업로드한 deepseek.pdf 파일을 마우스 오른쪽 버튼으로 클릭한 뒤 [경로 복사]를 눌러 파일 경로를 확인한다.

이제 RAG 데이터베이스를 생성한다.
```python
# 검색 증강 생성을 위한 DB 생성

# 1. PDF 파일 로드
pdf_path = "/content/deepseek.pdf"  # Colab에 업로드한 파일 경로
loader = PyPDFLoader(pdf_path) # PDF 파일을 읽고 그 안의 글자 추출
documents = loader.load()

# 2. 텍스트 분할 (Chunking)
text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
docs = text_splitter.split_documents(documents)

# 3. 임베딩 모델 초기화
embeddings = HuggingFaceEmbeddings(
    model_name="sentence-transformers/all-MiniLM-L6-v2"
)

# 4. 벡터 DB 생성 (Indexing)
faiss_index = FAISS.from_documents(docs, embeddings)
```

**documents = loader.load()**  
PDF의 각 페이지에서 텍스트를 실제로 추출하고, 이 텍스트들을 리스트(documents)형태로 메모리에 로드한다.  
이 때 텍스트는 리스트 형태로 저장되어 나중에 검색이나 벡터화 작업에서 사용된다.

---

**text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=200)**  
텍스트를 분할할 '도구'를 설정한다.  
LLM은 한 번에 처리할 수 있는 텍스트 길이에 한계가 있으므로(Context Window), 문서를 잘게 나누는 작업이 필수이다.
- chunk_size=1000
  - 텍스트를 1000자 단위로 자른다.
- chunk_overlap=200
  - chunk 간에 200자씩 겹치게 만든다. 이렇게 하면 문맥의 중간이 잘려 의미가 손실되는 것을 방지하고, AI가 문맥을 더 잘 파악할 수 있도록 돕는다.

**docs = text_splitter.split_documents(documents)**  
앞에서 로드한 _documents_ 리스트를 _text_splitter_ 의 설정값에 따라 실제로 작은 청크로 분리하여 _docs_ 리스트에 저장한다.

---

**embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")**  
분할된 텍스트 조각들을 AI가 이해할 수 있는 숫자 벡터로 변환할 '임베딩 모델'을 준비한다.  
텍스트 자체는 단순한 문자열이지만, 임베딩 모델을 통과하면 해당 텍스트의 '의미'와 '문맥'을 담은 고차원의 숫자 리스트(벡터)로 변환된다.  
여기서는 경량이면서 성능이 우수한 `all-MiniLM-L6-v2` 모델을 사용한다.

이 코드는 모델을 실행한 것이 아니라, 앞으로 _embeddings_ 라는 도구를 사용해 텍스트를 벡터로 변환할 것이라고 초기화(준비)만 한 상태이다.

---

**faiss_index = FAISS.from_documents(docs, embeddings)**  
이 한 줄의 코드 안에서 RAG 인덱싱의 가장 중요한 작업이 일어난다.
- **벡터 변환**
  - _embeddings_ 모델을 사용하여 _docs_ 리스트에 있는 **모든 텍스트 조각을 하나하나 숫자 벡터로 변환**한다.
- **인덱스 구축**
  - 변환된 모든 벡터를 `FAISS`라는 벡터 데이터베이스에 저장한다.

`FAISS`는 이 벡터들을 '벡터 공간(Vector Space)'이라는 가상의 좌표 시스템에 배치한다. 이 공간에서는 **비슷한 의미를 가진 텍스트의 벡터들이 서로 가까운 위치에 존재**하게 된다.

`FAISS`는 이 벡터 공간에서 특정 벡터와 가장 가까운 벡터들을 초고속으로 검색할 수 있도록 최적화되어 있다.

---

# 5. 검색 증강 생성으로 모델 추론

위에서 LLM(pipe)과 벡터 데이터베이스(faiss_index)를 모두 준비했다.

이제 이 두 가지를 결합하여, 사용자가 deepseek.pdf 파일의 내용에 대해 질문했을 때 AI가 해당 문서를 **참고하여** 답변을 생성하도록 RAG 파이프라인을 완성해보자.

---

## 5.1. RAG 추론 함수 정의

[1. RAG(Retrieval-Augmented Generation): 검색 증강 생성 작동 원리](#1-ragretrieval-augmented-generation-검색-증강-생성-작동-원리) 에서 말한
**2단계: 검색 및 생성(Retrieval & Generation) - 참고 자료를 참고하여 답변하기** 을 수행하는 함수를 정의한다.

```python
# RAG 로 모델 추론 함수 정의
def rag_generate(query, top_k=2):
    
    # 1. 검색 (Retrieve): 
    # 사용자 질문(query)을 기준으로, FAISS 인덱스에서 가장 관련 있는 문서 조각 top_k 개를 검색
    results = faiss_index.similarity_search(query, k=top_k)
    print("==검색 결과: ", results)

    # 2. 컨텍스트 조합 (Combine Context)
    # 검색된 문서 조각(result.page_content)들을 하나의 '참고 자료(context)' 텍스트로 합침
    context = ""
    for result in results:
        context += result.page_content + "\n"

    print("\n==LLM에 전달될 참고 자료(Context): ", context)

    # 3. 증강 (Augment): 
    # LLM에게 전달할 프롬프트를 구성. (참고 자료 + 실제 질문)
    messages = [
        {
            "role": "system", 
            "content": f"다음을 참고하여 한국어로 답변하세요.\n{context}"
        },
        {
            "role": "user", 
            "content": query
        }
    ]
    print("\n==최종 프롬프트(Messages): ", messages)

    # 4. 생성 (Generate):
    # 'pipe' (phi-4 모델)를 사용하여 최종 답변 추론
    outputs = pipe(
        messages,
        max_new_tokens=512,  # 최대 생성 토큰 수
        temperature=0.5,   # 생성 다양성 조절 (낮을수록 결정적)
        top_p=0.5          # 샘플링 시 고려할 토큰 비율
    )
    return outputs
```

위 함수는 RAG의 핵심 흐름을 그대로 따른다.  
**1.검색(Retrieve)**  
`faiss_index.similarity_search(query, k=top_k)` 가 실행되면, 사용자의 질문(_query_)이 내부적으로 임베딩 모델(all-MiniLM-L6-v2)에 의해 벡터로 변환된다.  
그리고 이 질문 벡터와 DB(_faiss_index_)에 저장된 문서 조각 벡터들 간의 유사도를 비교하여, 가장 관련성이 높은(가장 가까운) `k=2` 개의 문서 조각을 _results_ 로 반환한다.

**2.증강(Augment)**  
검색된 _results_ 의 텍스트 내용(page_content)을 _context_ 라는 하나의 문자열로 합친다.  
그리고 LLM에게 '이 _context_를 참고해서 _query_에 답해'라는 명령 프롬프트(_messages_)를 구성한다.  
이것이 바로 RAG의 '증강(Augment)' 단계이다.

**3.생성(Generate)**  
이 증강된 프롬프트를 `pipe(...)` 에 전달하여, phi-4 모델이 _context_에 기반한 정확한 답변을 생성하도록 한다.

---

## 5.2. RAG 실행 및 결과 확인

이제 실제로 deepseek.pdf 의 내용에 대해 질문을 던져본다.
```python
query = "딥시크를 막는 이유가 뭐야?"
outputs = rag_generate(query)

print("===대답", outputs[0]["generated_text"][2])
```


```shell
===대답 {'role': 'assistant', 'content': '딥시크를 막는 이유는 주로 개인정보 보호와 관련된 우려 때문입니다. 
생성형 AI인 딥시크는 사용자의 입력 데이터를 기반으로 다양한 콘텐츠를 생성할 수 있지만, 이 과정에서 개인정보가 수집되거나 노출될 위험이 있습니다. 
이러한 우려는 다음과 같은 이유로 발생합니다:\n\n
1. **개인정보 수집 및 처리**: 딥시크와 같은 AI 서비스는 사용자의 입력 데이터를 수집하여 학습하고 새로운 콘텐츠를 생성합니다. 
이 과정에서 개인정보가 수집되거나 불필요하게 저장될 수 있습니다.\n\n
2. **데이터 노출 위험**: 수집된 데이터가 적절히 보호되지 않으면, 
데이터 유출이나 불법적인 접근을 통해 개인정보가 노출될 위험이 있습니다.\n\n
3. **데이터 사용 목적의 불명확성**: 사용자가 입력한 데이터가 어떻게 사용되고 있는지 명확하지 않을 수 있으며, 
이는 사용자의 동의 없이 데이터가 다른 목적으로 사용될 수 있다는 우려를 불러일으킵니다.\n\n
4. **국제적인 규제 및 법적 문제**: 다양한 국가에서는 개인정보 보호를 위한 엄격한 법률과 규정을 가지고 있으며, 
이러한 규제를 위반할 수 있는 위험이 있습니다.\n\n
따라서 개인정보보호위원회는 딥시크와 같은 서비스가 국내외의 개인정보 보호 규정을 준수하도록 하기 위해 다양한'}
```

결과에서 볼 수 있듯이, phi-4 모델은 자신이 사전에 학습한 지식이 아니라 우리가 _faiss_index_를 통해 제공한 deepseek.pdf 의 내용을 참고하여 '개인정보 보호 우려'라는 
핵심적인 이유와 그 근거를 상세히 답변하고 있다.

이것이 바로 RAG가 LLM의 환각 현상을 줄이고, 최신 정보나 특정 문서에 기반한 신뢰도 높은 답변을 생성하는 핵심 원리이다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 이영호 저자의 **모두의 인공지능 with 파이썬**을 기반으로 스터디하며 정리한 내용들입니다.*

* [모두의 인공지능 with 파이썬](https://product.kyobobook.co.kr/detail/S000217061005)
* [Google Colab](https://colab.research.google.com)