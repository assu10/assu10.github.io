---
layout: post
title: "TroubleShooting - Nestjs: Failed to execute command: npm install --silent"
date: 2023-02-01
categories: dev
tags: trouble_shooting
---

# 내용
Nestjs 새로운 프로젝트 설치 중 `Failed to execute command: npm install --silent` 가 발생했다.

```shell
$ nest new project-name

...

▹▹▹▸▹ Installation in progress... ☕
Failed to execute command: npm install --silent
✖ Installation in progress... ☕
🙀 Packages installation failed!
In case you don't see any errors above, consider manually running the failed command npm install to see more details on why it errored out.
```

2023.01월 부터 해당 오류가 발생하는데 KT 를 사용하고 있는 한국사람들 대상으로 일어나는 현상이라고 한다. 
npm support 팀에서 KT 망에서만 안되는 이유 파악중이라고 한다.

---

# 해결책

1) 아래 명령어를 통해 npm mirror 사이트로 바꿔준다.

```shell
$ npm config set registry https://registry.npmjs.cf/ 
```
2) 다시 프로젝트를 생성한다.

```shell
$ nest new project-name 

✔ Installation in progress... ☕

🚀 Successfully created project basic
👉 Get started with the following commands:

$ cd basic
$ npm run start
```
3) 이후 다시 공식 npm registry 로 변경해준다.

```shell
$ npm config set registry https://registry.npmjs.org/

$ npm config get registry
https://registry.npmjs.org/ 
```

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [NestJS Failed to execute command: npm install --silent 에러](https://minyakk.tistory.com/26)
* [ts-jest 설치 안되는 현상](https://velog.io/@librarian/ts-jest-%EC%84%A4%EC%B9%98-%EC%95%88%EB%90%98%EB%8A%94-%ED%98%84%EC%83%81)