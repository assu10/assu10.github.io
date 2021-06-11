---
layout: post
title:  "Docker 및 Nginx 기본 셋팅"
date:   2021-06-08 10:00
categories: dev
tags: docker container nginx
---

이 포스트는 Docker(Windows 기준) 와 Nginx 를 사용한 웹 서버 셋팅에 대해 기술한다.

>- 컨테이너란?

---

## 1. Docker 설치

>호스트 OS는 Windows 를 기준으로 설명합니다.

Docker for Windows 는 *Hyper-V* 를 활성화하여야 하는데 Hyper-V 활성화 시 Oracle VirtualBox 등의 다른 가상화툴은 사용할 수 없다.

>Hyper-V 는 *Windows 기능 켜기/끄기* 에서 활성화 가능합니다.

*Docker Desktop for Windows* 는 [hub.docker.com](https://hub.docker.com/editions/community/docker-ce-desktop-windows) 에서 다운로드 가능하다.

---

*본 포스트는 Asa Shiho 저자의 **완벽한 IT 인프라 구축을 위한 Docker 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트
* [완벽한 IT 인프라 구축을 위한 Docker 2판](http://www.yes24.com/Product/Goods/64728692)
* [Docker Desktop for Windows user manual](https://docs.docker.com/docker-for-windows/)
* [Docker Desktop for Windows Download](https://hub.docker.com/editions/community/docker-ce-desktop-windows)