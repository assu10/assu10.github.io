---
layout: post
title:  "TroubleShooting - `docker push` 시 `denied: requested access to the resource is denied`"
date: 2025-12-28
categories: dev
tags: trouble_shooting
---

`docker push` 시 `denied: requested access to the resource is denied` 아래와 같은 오류가 발생할 때 가장 흔한 오류는
로컬 리눅스 계정 이름과 Docker Hub의 실제 계정 이름이 다르기 때문이다.

현재 도커 허브에 로그인된 계정을 확인한다.

```shell
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker info | grep Username
 Username: real_id
```

그리고 실제 도커 허브 아이디를 넣어서 진행한다.

```shell
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker tag mydjango_ch10:0.2 real_id/mydjango_ch10:0.2
assu@myserver01:~/work/ch10/ex01/myDajngo04$ docker push real_id/mydjango_ch10:0.2
```
