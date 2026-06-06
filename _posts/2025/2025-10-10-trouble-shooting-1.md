---
layout: post
title:  "TroubleShooting - Colab: The secret `HF_TOKEN` does not exist in your Colab secrets."
date: 2025-10-10
categories: dev
tags: trouble_shooting
---

# 내용
Google Colab 에서 토큰화 테스트 중 아래와 같은 Warning 이 발생하였다.

```python
from transformers import AutoTokenizer
model_id = "microsoft/phi-4"
tokenizer = AutoTokenizer.from_pretrained(model_id)

text = "I am studying tokenization"
tokens = tokenizer.tokenize(text)
print(tokens)
```

```shell
/usr/local/lib/python3.12/dist-packages/huggingface_hub/utils/_auth.py:94: UserWarning: 
The secret `HF_TOKEN` does not exist in your Colab secrets.
To authenticate with the Hugging Face Hub, create a token in your settings tab (https://huggingface.co/settings/tokens), set it as secret in your Google Colab and restart your session.
You will be able to reuse this secret in all of your notebooks.
Please note that authentication is recommended but still optional to access public models or datasets.
  warnings.warn(
tokenizer_config.json: 
 17.7k/? [00:00<00:00, 398kB/s]
vocab.json: 
 1.61M/? [00:00<00:00, 21.2MB/s]
merges.txt: 
 917k/? [00:00<00:00, 15.2MB/s]
tokenizer.json: 
 4.25M/? [00:00<00:00, 62.4MB/s]
added_tokens.json: 
 2.50k/? [00:00<00:00, 57.4kB/s]
special_tokens_map.json: 100%
 95.0/95.0 [00:00<00:00, 2.11kB/s]
['I', 'Ġam', 'Ġstudying', 'Ġtoken', 'ization']
```



---

# 원인

위 경고는 Hugging Face Hub 에 로그인하기 위한 인증 토큰(HF_TOKEN)이 Colab 환경에 설정되어 있지 않다는 의미이다.  
Hugging Face Hub 에서 모델이나 데이터셋을 다운로드할 때, 사용자를 인증하기 위해 토큰을 사용하는데 이 토큰이 없으면 경고가 발생한다.  
microsoft/phi-4 모델은 public 모델이라 인증 토큰이 없어도 다운로드하고 사용하는데에는 문제가 없어서 경고만 표시되고 정상적으로 실행된다.  
하지만 private 모델에 접근하거나, 파일을 업로드 하는 등 인증이 필요한 작업을 하려면 Hugging Face Hub 에서 토큰을 발급받아 Colab 에 시크릿으로 등록해야 한다.

---

# 해결책

먼저 https://huggingface.co/settings/tokens 에 로그인하여 개인 액세스 토큰을 받는다.  
개인 엑세스 토큰은 화면 좌측의 [Settings] > [Access Tokens] 에서 발급받을 수 있다.

이 토큰을 Colab 에 시크릿으로 등록한다.  
Colab 노트북 왼쪽 사이드바에서 열쇠 모양을 클릭하여 시크릿 탭을 연 후 '새 보안 비밀 추가'를 클릭한다.  
이름은 반드시 `HF_TOKEN` 이라고 정확하게 입력해야 한다. 라이브러리가 이 이름으로 토큰을 찾기 때문이다.  
값은 발급받은 토큰을 붙여 넣고, '노트북 액세스' 스위치가 켜져있는지 확인한다.  

설정을 마쳤으면 Colab 메뉴에서 런타임 > 세션 다시 시작을 눌러 런타임을 재시작한다.