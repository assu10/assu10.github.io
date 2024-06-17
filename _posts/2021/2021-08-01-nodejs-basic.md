---
layout: post
title:  "Node.js - 기본 개념"
date:   2021-08-01 10:00
categories: dev
tags: nodejs
---

이 포스트는 Node.js(Mac 기준) 의 기본 개념과 Node.js 을 시작하기에 앞서 알아야 할 내용들에 대해 기술한다.  

<!-- TOC -->
  * [1. Node.js 개념](#1-nodejs-개념)
    * [1.1. Event-driven (이벤트 기반)](#11-event-driven-이벤트-기반)
    * [1.2. Non-Blocking I/O](#12-non-blocking-io)
    * [1.3. Single Thread](#13-single-thread)
  * [2. Node.js 의 활용](#2-nodejs-의-활용)
  * [3. Node.js 환경 설정 (Mac)](#3-nodejs-환경-설정-mac)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## 1. Node.js 개념

>**Node.js란?**  
> Chrome V8 Javascript 엔진으로 빌드된 Javascript 런타임

개발환경: `macOS`, `node 16.6.0`

Node.js 는 Javascript 런타임이며,  
여기서 런타임이란 특정 언어로 만들어진 프로그램들을 실행할 수 있는 환경을 말한다.  
(Node.js = Javascript 실행기) 

브라우저는 Javascript 런타임을 내장하고 있기 때문에 Javascript 코드를 실행할 수 있지만 브라우저 외의 환경에서는 Javascript 속도 문제들이 존재했다.

2008년 구글이 V8 엔진을 사용하여 출시한 크롬은 다른 Javascript 엔진과 달리 매우 빨랐고, 오픈 소스로 코드를 공개함으로써 Node.js  프로젝트를 시작하게 되었다.

Node.js 는 V8 과 더불어 `libuv` 라이브러리를 사용하는데  
`libuv` 라이브러리는 Node.js 의 특징인 Event-driven, Non-Blocking I/O 모델을 구현하고 있다.

> `libuv`  
> Node.js 에 포함된 Non-Blocking(비동기) I/O 라이브러리 

Node.js 의 등장으로 javascript 를 이용하여 서버를 구동할 수 있게 되었다.  
Front-End 와 Back-End 에서 같은 언어를 사용하게 됨으로써 같은 개발자가 풀스택으로 개발할 경우 생상성을 향상시켜 주고, Front-End 와 Back-End 개발자가 분리되어 있어도
소통 비용을 줄어든다.

Node.js 는 npm 이라는 패키지 관리 시스템을 가지고 있는데 누구나 자신이 만든 Node.js 기반 라이브러리를 등록하여 공개할 수 있다.  
공개하기 싫지만 npm 을 이용하여 사내에서 패키지를 관리하고자 한다면 유료로 비공개 등록도 가능하다.

**Node.js 의 장점**은 Single Thread 로 동작하는 것처럼 코드를 작성할 수 있다는 것이다. (멀티 스레딩을 직접 만들고 관리하는 것은 난이도가 높다)  

**Node.js 의 단점**은 컴파일러 언어의 처리 속도에 비해 성능이 떨어진다는 점인데 서버의 성능은 계속 발전하고 있어서 크게 단점으로 작용하지 않는다.  
Event-driven Non-Blocking(비동기) 방식으로 작업하게 되면 이른 바 *콜백 지옥*에 빠질 수 있는데 이 또한 ES6 에서 Promise 가 도입되면서 간결하게 작성할 수 있고,
ES8 에서는 async/await 가 추가되면서 비동기 코드를 마치 동기식으로 처리하는 것처럼 작성할 수 있게 되었다.

---

### 1.1. Event-driven (이벤트 기반)

>**Event-driven**  
> 이벤트가 발생할 때 미리 지정해 둔 작업을 수행하는 방식

특정 이벤트가 발생할 때 수행할 작업을 등록해두는 작업을 *이벤트 리스너에 콜백 함수를 등록*한다고 표현한다.

>**Event Loop (이벤트 루프)**  
> 시스템 커널에서 가능한 작업이 있다면 그 작업을 커널로 이관  
> 여러 이벤트가 동시에 발생했을 때 어떠한 순서로 콜백 함수를 호출할 지 판단  
> 즉, 이벤트 발생 시 호출할 콜백 함수들을 관리하고, 호출된 콜백 함수의 순서를 결정하는 역할  
> Node.js 가 종료될 때까지 이벤트 처리를 위한 작업을 반복하기 때문에 loop 라고 부름  
> **javascript 가 Single Thread 임에도 불구하고 Node.js 가 Non-Blocking I/O 작업을 수행할 수 있도록 해주는 핵심 기능**  
> 
> Event Loop 에 대한 상세한 내용은 [Event Loop](https://assu10.github.io/dev/2023/02/04/event-loop/) 를 참고하세요. 

>**백그라운드**  
> setTimeout 과 같은 타이머나 이벤트 리스터들이 대기하는 곳

>**태스크 큐(콜백 큐)**  
> 이벤트 발생 후 백그라운드에서는 태스크 큐로 타이머나 이벤트 리스너의 콜백 함수를 보냄

---

### 1.2. Non-Blocking I/O

>**Non-Blocking**  
> 이전 작업이 완료될 때까지 대기하지 않고 다음 작업을 수행

>**Blocking**  
> 이전 작업이 완료되어야만 다음 작업을 수행

이벤트 루프를 잘 활용하면 오래 걸리는 작업을 효율적으로 처리할 수 있는데  
예를 들어 I/O 작업 (파일 읽기/쓰기,폴더 생성 등 파일 시스템 접근이나 네트워크를 통한 요청 작업) 은 Non-Blocking 방식으로 처리할 수 있다.

Node.js 는 들어온 작업을 앞의 작업이 끝날 때까지 기다리지 않고 (Non-Blocking) 비동기로 처리한다.  
**입력은 하나의 Thread 에서 받지만 순서대로 처리하지 않고 먼저 처리된 결과를 이벤트로 반환해주는 방식인데 이게 바로 Node.js 에서 사용하는 
`Single Thread Non-Blocking Event-Driven` 방식**이다.

Node.js 는 I/O 작업을 백그라운드로 넘겨 동시에 처리할 수 있기 때문에 동시 처리가 가능한 작업들은 최대한 묶어서 백그라운드로 넘겨야 시간을 절약할 수 있다.  
동시에 처리될 수 있는 I/O 작업이라도 Non-Blocking 방식으로 코딩하지 않으면 의미가 없다.

`setTimeout(callback, 0)` 은 Non-Blocking 으로 만들기 위해 사용하기도 하는데  
호출 스택에서 백그라운드로 setTimeout 을 보내고, 백그라운드는 0초 후에 태스트 큐로 callback 함수를 보내게 되는 구조이다.  
`setTimeout(callback, 0)` 말고 `setImmediate` 가 더 자주 사용되는데 이는 나중에 알아볼 예정이다.

주의할 것은 Node.js 는 Single Thread 이기 때문에 Non-Blocking 방식으로 작성했더라도 그 코드가 모두 개발자가 작성한 코드라면 전체 소요 시간이 짧아지는 것이 아니라 실행 순서만 바뀐다는 것이다.  
**오래 걸리는 작업이 있을 때 Non-Blocking 을 통해 실행 순서를 바꿔줌으로써 그 작업 때문에 다른 작업들이 대기하는 상황을 막는 것**이다.  

Non-Blocking 을 동시성과 헷갈려서도 안된다.  
**동시성**은 **동시 처리가 가능한 작업을 Non-Blocking 처리**해야 얻을 수 있다.

---

### 1.3. Single Thread

Single Thread 란 말 그대로 Thread 가 하나뿐이라는 의미이다.  

>**Process**  
> 운영체제에서 할당하는 작업의 단위  
> 프로세스 간에는 메모리 등의 자원을 공유하지 않음  

>**Thread**  
> 프로세스 내에서 실행되는 흐름의 단위로 프로세스는 스레드를 여러 개 생성하여 여러 작업을 동시에 처리할 수 있음  
> 스레드들은 부모 프로세스의 자원을 공유하고, 같은 주소의 메모리에 접근이 가능하므로 데이터 공유가 가능

엄밀히 말하면 Node.js 는 Single Thread 는 아니다.  
Node.js 를 실행하면 하나의 프로세스가 생성되고, 그 프로세스는 내부적으로 여러 개의 스레드들을 생성하는데 이 중에서 개발자가 직접 제어할 수 있는 스레드는 하나이기 때문에
Node.js 는 Single Thread 라고 하는 것이다.  
애플리케이션 단에서는 Single Thread 이지만 백그라운드에서는 Thread pool 을 구성하여 작업을 처리한다.  
개발자 대신 `libuv` 가 Thread pool 을 관리하기 때문에 개발자는 Single Thread 에서 동작하는 것처럼 코드를 작성할 수 있다.


>**Thread Pool 과 Worker Thread**  
> Node.js 가 Single Thread 로 동작하지 않는 두 가지 경우가 있는데 스레드 풀과 워크 스레드가 그 경우이다.
> 
>**Thread Pool**  
> Node.js 는 특정 동작을 수행할 때 스스로 멀티 스레드를 사용  
> 예) 암호화(crypto), 파일 입출력, 압축(zlib) 등
> 
> **Worker Thread**  
> Node.js  12 버전에서 안정화된 기능  
> CPU(연산) 작업이 많은 경우 워커 스레드를 사용하면 됨

멀티 스레드 방식이 무조건 좋은 것은 아니다.
처리할 작업이 줄어들었을 경우 놀게 되는 스레드가 발생하고, 이러한 스레드를 destroy 하는 데에도 비용이 들어가기 때문이다.

또한 멀티 스레드 방식으로 코딩하는 것은 난이도가 높기 때문에 상황에 따라 멀티 프로세싱 방식을 사용하기도 한다.  
아래와 같은 기준으로 방향성을 정하는 것도 좋다.

- I/O 요청이 많을 경우는 더 효율적이고 난이도가 비교적 낮은 멀티 프로세싱 방식으로 진행  
  예) cluster 모듈, pm2 패키지에서 멀티 프로세싱을 가능하게 해줌
- CPU 작업이 많은 경우는 난이도는 높지만 멀티 스레딩 방식으로 진행  
  예) worker_threads

---

## 2. Node.js 의 활용

위에서 Node.js 는 기본적으로 Single Thread 와 Non-Blocking 모델을 사용한다고 하였다.

서버에는 기본적으로 I/O 요청이 많이 발생하므로 Node.js 를 서버로써 사용하는 경우가 많다.  
이말은 CPU 부하가 큰 작업에는 Node.js 가 부적합하다는 의미이기도 하다.

Node.js 는 `libuv` 라이브러리를 이용하여 I/O 작업을 Non-Blocking 방식으로 처리하기 때문에 하나의 스레드가 많은 수의 I/O 를 처리할 수 있다.  

Node.js 는 네트워크나 DB, 디스크 작업같은 I/O 에 특화되어 있기 때문에 갯수는 많지만 크기는 작은 데이터를 실시간으로 주고 받는 실시간 채팅이나 주식 차트, 
JSON 데이터를 제공하는 API 서버에 사용하기 좋다.

Node.js  12 버전부터 워커 스레드 기능이 안정화되어 멀티 스레드 작업이 가능은 하지만   
멀티 스레드는 Single Thread 에 비해 난이도가 높고 C, C++, Rust, Go 와 같은 언어에 비해 아직 속도가 많이 느리다.  
따라서 멀티 스레드 기능이 있지만 미디어 처리, 대규모 데이터 처리처럼 CPU 를 많이 사용하는 작업을 위한 서버로 Node.js 는 적합하지 않다.  
만일 이러한 작업에 굳이 Node.js 를 사용해야 한다면 AWS Lambda 나 Google Cloud Functions 와 같은 서비스에서 Node.js 로 CPU 를 많이 사용하는 작업처리를
지원하므로 이 부분을 알아보는 것이 좋다.

Node.js 에는 웹 서버가 내장되어 있지만 서버 규모가 커지게 되면 결국 nginx 등의 웹 서버를 Node.js  서버와 연결해야 한다.  
Node.js 는 생산성은 좋지만 (자바스크립트라는 하나의 언어로 프론트와 서버를 모두 개발하므로) nginx 처럼 정적 파일을 제공하거나 로드 밸런싱에 특화된
웹 서버에 비해서는 속도가 느리다.

정적인 컨텐츠를 주로 제공하는 서버로 Node.js 를 사용할 때 `Nunjucks(넌적스)`, `Pug(퍼그)`, `EJS` 와 같은 템플릿 엔진을 통해 다른 언어와 비슷하게 콘텐츠를
제공하는 방법도 있다.

지금까지 서버로서의 Node.js 의 활용에 대해 알아보았다.  
하지만 Node.js 는 자바스크립트 런타임이므로 용도가 서버에만 한정되어 있지 않다.

Node.js  기반 대표적인 웹 프레임워크로는 `Angular`, `React`, `Vue` 등이 있다.  
모바일 개발 도구로는 `React Native` 가 많이 사용되는데 페이스북, 인스타그램, 핀터레스트 등이 리액트 네이티브를 사용하여 모바일 앱을 운영중이다.  
데스크탑 개발 도구로는 `Electron` 이 대표적인데 `Atom`, `Slack`, `Discord`, `Visual Studio Code` 등이 일렉트론으로 만들어진 대표적인 프로그램들이다.

---

## 3. Node.js 환경 설정 (Mac)

[Node.js 공홈](https://nodejs.org) 에 접속하여 Current 버전 (학습용이므로) 을 설치한다. (포스트 작성 기준 16.6.0 버전)

>**npm**  
> Node.js  패키지 매니저

Node.js , npm 설치 확인
```shell
$ node -v
v16.6.0

$ npm -v
7.19.1
```

npm 버전 업데이트
```shell
$ npm install -g npm

# if an error occurs.
# This is an error that occurs when installing globally with -g appended.
$ sudo npm install -g npm

$ npm -v
7.20.3
```

환경 변수 목록 확인 및 PATH 환경 변수 추가
```shell
$ echo $PATH
Users/사용자/.rbenv/shims /Users/사용자/.rbenv/bin /usr/local/bin /usr/bin /bin /usr/sbin /sbin

$ export PATH=$PATH:추가경로
```

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js 공홈 Guide](https://nodejs.org/ko/docs/guides/)
* [Node.js Guide](https://nodejs.dev/)
* [NestJS로 배우는 백엔드 프로그래밍](http://www.yes24.com/Product/Goods/115850682)
* [Event Loop - assu](https://assu10.github.io/dev/2023/02/04/event-loop/)