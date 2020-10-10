---
layout: post
title:  "GitLab-Runner 설치 & 등록(Windows)"
date:   2020-10-08 10:00
categories: dev
tags: devops gitlab gitlab-runner ci cd  
---

이 글은 CI/CD 구성을 위한 GitLab + GitLab Runner 적용 과정을 설명하기 전에 알아야 할 기본 내용과 
GitLab-Runner 설치에 대해 설명합니다.

*온프레미스가 아닌 gitlab.com 을 이용하여 GitLab 을 구성하였습니다*

>***GitLab-Runner 설치 & 등록(Windows)***<br />
>- DevOps 란?
>- GitLab 이란?
>- GitLab-Runner 다운로드 (Windows)
>- GitLab-Runner 등록

---

## DevOps 란?

GitLab 에 대한 내용을 알아보기 전에 DevOps 란 무엇인지 먼저 짚고 넘어가야 할 듯 싶다.

DevOps 라 했을 때 떠오르는 단어는 자동화, 개발과 운영의 경계를 없애는 것.<br />
이 정도만 생각나지 명확하게 어떤 의미인지 설명할 수 없어 이 기회에 한번 짚고 넘어가려 한다.

DevOps 은 Development + Operations 의 합성어로 개발(조직)와 운영(조직) 을 융합시키기 위한 개발방법론이다.

그렇다면 왜 개발(조직)과 운영(조직)을 융합시켜야 하는 이슈가 생겨났을까?<br />
이는 각자의 입장 차이에서 시작된다.
개발조직은 새로운 기술과 새로운 기능을 도입하고 싶어하고, 운영조직은 당연히 새로움보단 안정성을 우선시 할 수 밖에 없다.

그리하여 이 두 조직을 서로 잘 융합시키기 위해 나온 방법론이 바로 DevOps 이다.

- **DevOps 특징**
    - CI/CD (Continuous Integration, Continuous Deploy)
        - CI : 빌드 및 테스트 자동화 / 테스트를 통과한 소스만 중앙 저장소에 통합 / TravisCI, Jenkins
        - CD : 배포 자동화 / AWS Code Deploy
    - 장애가 있는 경우 팀원과 공유
    - 짧은 주기로 정기 배포

---

## GitLab 이란?

GitLab 은 Git 의 원격 저장소 기능과 이슈 트래커 기능등을 제공하는 소프트웨어이다. 
**설치형 Github 라는 컨셉으로 시작된 프로젝트**이기 때문에 Github 와 비슷한 면이 많이 있다. 
서비스형 원격저장소를 운영하는 것에 대한 비용이 부담되거나, 소스코드의 보안이 중요한 프로젝트에게 적당하다. 

무료임에도 불구하고 **Github 에서 제공하는 기능 대부분을 제공**하여, 프로젝트 관리를 위한 **자체 CI 와 사용자 인터페이스를 제공**한다.
**스니펫 섹션**을 사용하면 전체 프로젝트를 공유하는 대신 프로젝트에서 적은 양의 코드를 공유할 수도 있다.<br />
단, pull/push 가 Github 만큼 빠르지는 않다.

- **GitLab 특징**<br />
    - 설치형 버전관리 시스템 (서버에 직접 설치하여 사용)
    - gitlab.com 사용 시 서버 없이 GitLab 사용 가능, 10명 이하의 프로젝트는 무료 사용
    - issue tracker 제공
    - Git 원격 저장소 제공
    - API 제공

---

## GitLab-Runner 다운로드 (Windows)

본인의 C 드라이드에 GitLab 을 설치할 디렉토리를 하나 만든다. (*C:/GitLab-Runner*)


[GitLab Runner bleeding edge releases](https://docs.gitlab.com/runner/install/bleeding-edge.html#download-any-other-tagged-release) 에 접속하여
본인 사양에 맞는 바이너리 버전을 다운로드 받는다.<br />
Windows 64 비트 : [gitlab-runner-windows-amd64.exe](https://s3.amazonaws.com/gitlab-runner-downloads/master/binaries/gitlab-runner-windows-amd64.exe)

2020.10.09 현재 Gitlab 버전은 `GitLab 13.5-pre`

다운로드 받은 파일의 이름을 `gitlab-runner.exe` 로 변경해준다.

---

## GitLab-Runner 등록

Runner 를 다운로드 받은 디렉토리로 이동하여 관리자 권한으로 cmd 창을 연 후 아래와 같이 Runner 를 등록해준다.

```shell
C:\Gitlab-Runner>gitlab-runner.exe register
Runtime platform arch=amd64 os=windows pid=14956 revision=34d8ad75 version=13.6.0~beta.126.g34d8ad75
```

Runner 가 명령을 실행받을 서버 주소를 입력한다. 
온프레미스인 경우 해당 서버의 주소를 기재하면 된다.

```shell
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
https://gitlab.com
```

GitLab CI 에서 발급된 Token 을 입력한다.

```shell
Please enter the gitlab-ci token for this runner:
xxxxxxxxxxxxxxxxxxxx
```

GitLab CI Token 확인은 해당 GitLab Project > Settings > CI/CD 로 들어가 Runners 를 Expand 하면 확인할 수 있다.

![Get GitLab CI Token](/assets/img/dev/20201009/token.jpg)

Runner 이름을 적는다. 
정상적으로 연동되면 CI/CD 확인 시 아래 기재한 Runner 의 이름이 노출된다.<br />
(나중에 GitLab UI 에서 변경 가능)

```shell
Please enter the gitlab-ci description for this runner:
[LAPTOP-EGGD0QMM]: ci-test
```

.gitlab-ci.yml 에서 Runner 를 지정할 때 사용할 Tag 명을 설정한다. (제일 중요)<br />
(나중에 GitLab UI 에서 변경 가능)

```shell
Please enter the gitlab-ci tags for this runner (comma separated):
ci-tag

Registering runner... succeeded                     runner=
```

위 tag 를 .gitlab-ci.yml 에서 사용할 때 설계한 script 를 실행할 실행 프로그램을 설정한다. 

```shell
Please enter the executor: docker+machine, docker-ssh+machine, docker-windows, parallels, shell, ssh, kubernetes, custom, docker, docker-ssh, virtualbox:
shell

Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
```

이제 *C:\Gitlab-Runner* 에 가보면 방금 설정한 내용들이 기록된 `config.toml` 파일이 하나 생성되어 있을 것이다.

Runner 가 정상적으로 연동이 되어있다면 Runners activated for this project 로 설정이 되어있을 것이다.
 
![연동된 Runner 확인](/assets/img/dev/20201009/runner.jpg)

GitLab-Runner 실행

```shell
C:\Gitlab-Runner>gitlab-runner.exe install
C:\Gitlab-Runner>gitlab-runner.exe start
```

지금까지 GitLab Runner 가 동작하기 위한 사전 작업을 마쳤다.  

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [DevOps 란?](https://medium.com/@simsimjae/devops%EB%9E%80-%EB%AC%B4%EC%97%87%EC%9D%B8%EA%B0%80-c50f4d86666b)
* [Gitlab 소개](https://www.opentutorials.org/course/785/4933)
* [GitLab 설치](https://www.tutorialspoint.com/gitlab/gitlab_installation.htm)
* [GitLab 설치 (Windows)](https://docs.gitlab.com/runner/install/windows.html)
* [GitLab-Runner 등록 1](https://forgiveall.tistory.com/553)
* [GitLab-Runner 등록 2](https://docs.gitlab.com/runner/register/index.html)
* [GitLab-Runner 등록 3](https://microcode.tistory.com/4?category=779702)
* [GitLab-Runner 등록 4](https://www.popit.kr/gitlab-runner-windows-spring-%EC%97%B0%EB%8F%99/)
