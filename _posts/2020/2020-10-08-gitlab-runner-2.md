---
layout: post
title:  "GitLab CI/CD Pipeline 구성"
date: 2020-10-09 10:00
categories: dev
tags: devops gitlab gitlab-runner ci cd  
---

이 글은 GitLab CI/CD Pipeline 에 대해 설명합니다.

<!-- TOC -->
  * [CI/CD 파이프라인](#cicd-파이프라인)
  * [수동 배포 설정](#수동-배포-설정)
  * [수동 job 실행 시 변수 설정](#수동-job-실행-시-변수-설정)
  * [CI/CD 파이프라인 그룹화](#cicd-파이프라인-그룹화)
  * [파이프라인 아키텍처](#파이프라인-아키텍처)
    * [파이프라인 아키텍처 - Basic](#파이프라인-아키텍처---basic)
    * [파이프라인 아키텍처 - DAG (Directed Acyclic Graph)](#파이프라인-아키텍처---dag-directed-acyclic-graph)
    * [파이프라인 아키텍처 - Child/Parent Pipelines](#파이프라인-아키텍처---childparent-pipelines)
  * [효율적인 파이프라인 구성](#효율적인-파이프라인-구성)
  * [파이프라인 스케쥴링](#파이프라인-스케쥴링)
  * [Artifact 사이즈](#artifact-사이즈)
  * [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

## CI/CD 파이프라인

파이프라인은 `Jobs` 과 `Stages` 로 구성된다.

>**Jobs**<br />
>수행할 작업을 정의
>예를 들면 코드를 컴파일 하거나 테스트하는 작업
>
>**Stages**<br />
>jobs 를 실행할 시기를 정의

`Jobs` 는 Runner 에 의해 실행되는데 같은 `Stage` 내의 여러 개의 `Jobs` 가 병렬로 실행된다.

하나의 `Stage` 가 성공적으로 종료되면 파이프라인은 다음 `Stage` 로 넘어가고,<br />
만약 `Stage` 안의 `Job` 이 실패하면 다음 `Stage` 는 실행되지 않고 파이프라인이 종료된다.

일반적으로 파이프라인 아래 순서로 실행되는 4개의 Stage 로 구성된다.

>**build stage** - 컴파일 job<br />
>**test stage**<br />
>**staging stage** - deploy-to-stage<br />
>**production stage** - deploy-to-prod

파이프 라인과 구성 job 과 stage 는 각 프로젝트의 CI/CD 파이프라인 구성 파일인 `.gitlab-ci.yml` 에 정의된다.

---

## 수동 배포 설정

파이프라인은 자동으로 실행시킬 수 있지만 프로덕션에 배포할 때는 수동 작업이 필요하다.
`when:manual` 설정을 통해 프로덕션 단계에서는 수동으로 배포할 수 있다.

```yaml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  script: echo "Running tests"

build:
  stage: build
  script: echo "Building the app"

deploy_staging:
  stage: deploy
  script:
    - echo "Deploy to staging server"
  environment:
    name: staging
    url: https://staging.example.com
  only:
    - master

deploy_prod:
  stage: deploy
  script:
    - echo "Deploy to production server"
  environment:
    name: production
    url: https://example.com
  when: manual
  only:
    - master
```

![프로덕션 환경에서는 수동 배포하도록 구성된 파이프라인<br />(출처 : https://docs.gitlab.com/ee/ci/environments/index.html#configuring-manual-deployments)](/assets/img/dev/2020/1009/manual.jpg)


그 외에도 아래와 같은 `when:` 옵션이 있다. (default 는 on_success)

![job 실행 조건 when](/assets/img/dev/2020/1009/when.jpg)

좀 더 상세한 설명은 [Configuring manual deployments](https://docs.gitlab.com/ee/ci/environments/index.html#configuring-manual-deployments) 를
참고하세요.

---

## 수동 job 실행 시 변수 설정

**사전 정의된 환경 변수는 [Predefined environment variables reference](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html) 와 
[list-all-environment-variables](https://docs.gitlab.com/ee/ci/variables/README.html#list-all-environment-variables) 를 참고**

수동 job 실행 시 특정 변수를 추가하여 실행할 수 있는데 추가 변수는 실행하려는 수동 job 페이지와 .gitlab-ci.yml 에서 설정 가능하다.
고정된 값의 변수인 경우 .gitlab-ci.yml 에서 설정하여 수동이 아닌 job 에서도 사용 가능하다.

아래 내용 외 더 자세한 사항은 [.gitlab-ci.yml defined variables](https://docs.gitlab.com/ee/ci/variables/README.html#gitlab-ciyml-defined-variables) 를 참고하세요.

```yaml
stages:
  - build
  - test
  - deploy

variables:    # 전역 변수
  NAME: 'assu'

build-phase:      # 임의의 job 이름..
  stage: build
  tags:
    - ci-tag
  except:
    - dev
  before_script:
    - echo 'build-phase before script, except dev'
  script:
    - chcp 65001    # UTF-8 설정
    - echo 'build-phase script, except dev'
  after_script:
    - echo 'build-phase after_script, except dev'

test-phase:      # 임의의 job 이름
  stage: test
  tags:
    - ci-tag
  except:
    - dev
  before_script:
    - echo 'build-phase before script, except dev'
  script:
    - chcp 65001    # UTF-8 설정
    - echo 'build-phase script, except dev' $NAME
  after_script:
    - echo 'build-phase after_script, except dev'

deploy-phase:      # 임의의 job 이름
  stage: deploy
  tags:
    - ci-tag
  when: manual
  only:
    - master
  before_script:
    - echo 'deploy-phase before script, except dev'
  script:
    - chcp 65001    # UTF-8 설정
    - echo 'deploy-phase script, except dev'$NAME
  after_script:
    - echo 'deploy-phase after_script, except dev'
```

```shell
Running with gitlab-runner 13.6.0~beta.126.g34d8ad75 (34d8ad75)
  on ci-test xxxxxxxx
Preparing the "shell" executor
00:00
Using Shell executor...
Preparing environment
00:00
Running on LAPTOP-EGGD0QMM...
Getting source from Git repository
00:04
Fetching changes with git depth set to 50...
Reinitialized existing Git repository in C:/Gitlab-Runner/builds/xxxxxxxx/0/assu/test/.git/
Checking out 3c40ce99 as master...
git-lfs/2.11.0 (GitHub; windows amd64; go 1.14.2; git 48b28d97)
Skipping Git submodules setup
Executing "step_script" stage of the job script
00:00
$ echo 'deploy-phase before script, except dev'
deploy-phase before script, except dev
$ chcp 65001
Active code page: 65001
$ echo 'deploy-phase script, except dev'$NAME         # 변수 출력
deploy-phase script, except dev
assu            # 변수 출력
Running after_script
00:01
Running after script...
$ echo 'deploy-phase after_script, except dev'
deploy-phase after_script, except dev
Cleaning up file based variables
00:00
Job succeeded
```

수동 job 페이지와 .gitlab-ci.yml 에서 변수 동시 사용하는 경우는 아래와 같다.

```yaml
stages:
  - build
  - test
  - deploy

variables:    # 전역 변수
  NAME: 'assu'

build-phase:      # 임의의 job 이름..
  stage: build
  tags:
    - ci-tag
  except:
    - dev
  before_script:
    - echo 'build-phase before script, except dev'
  script:
    - chcp 65001    # UTF-8 설정
    - echo 'build-phase script, except dev'
  after_script:
    - echo 'build-phase after_script, except dev'

test-phase:      # 임의의 job 이름
  stage: test
  tags:
    - ci-tag
  except:
    - dev
  before_script:
    - echo 'build-phase before script, except dev'
  script:
    - chcp 65001    # UTF-8 설정
    - echo "build-phase script, except dev $NAME"   # 변수 출력 시엔 큰 따옴표로 묶어주어야 함
  after_script:
    - echo 'build-phase after_script, except dev'

deploy-phase:      # 임의의 job 이름
  stage: deploy
  tags:
    - ci-tag
  when: manual
  only:
    - master
  before_script:
    - echo 'deploy-phase before script, except dev'
  script:
    - chcp 65001    # UTF-8 설정.
    - echo "deploy-phase script, except dev $NAME $NICK1 $NICK2"    # NAME 은 전역 변수로 셋팅, 나머진 job 페이지에서 셋팅
  after_script:
    - echo 'deploy-phase after_script, except dev'
```

![수동 job 페이지 위치)](/assets/img/dev/2020/1009/job.jpg)

![수동 job 페이지에서 변수 설정)](/assets/img/dev/2020/1009/job2.jpg)


```shell
Running with gitlab-runner 13.6.0~beta.126.g34d8ad75 (34d8ad75)
  on ci-test xxxxxxxx
Preparing the "shell" executor
00:00
Using Shell executor...
Preparing environment
00:01
Running on LAPTOP-EGGD0QMM...
Getting source from Git repository
00:04
Fetching changes with git depth set to 50...
Reinitialized existing Git repository in C:/Gitlab-Runner/builds/xxxxxxxx/0/assu/test/.git/
Checking out 47bcb2a2 as master...
git-lfs/2.11.0 (GitHub; windows amd64; go 1.14.2; git 48b28d97)
Skipping Git submodules setup
Executing "step_script" stage of the job script
00:00
$ echo 'deploy-phase before script, except dev'
deploy-phase before script, except dev
$ chcp 65001
Active code page: 65001
$ echo "deploy-phase script, except dev $NAME $NICK1 $NICK2"
deploy-phase script, except dev assu TEST    # 변수 출력 (대소문자 가리지 않음)
Running after_script
00:01
Running after script...
$ echo 'deploy-phase after_script, except dev'
deploy-phase after_script, except dev
Cleaning up file based variables
00:00
Job succeeded
```

설정한 변수가 없어도 오류는 나지 않으며, 없는 변수를 매개 변수로 넘겨도 또한 오류는 발생하지 않는다.

## CI/CD 파이프라인 그룹화

비슷한 job 이 많은 경우 파이프라인 그래프가 길어져 보기 힘들어지는데 아래와 같은 방식으로 설정하면 비슷한 job 을 자동으로 그룹화할 수 있다.

![그룹화된 파이프라인<br />(출처 : https://docs.gitlab.com/ee/ci/pipelines/index.html)](/assets/img/dev/2020/1009/group1.jpg)

- 슬래쉬 (/) 사용 : test 1/3, test 2/3, test 3/3
- 콜론 (:) 사용 : test 1:3, test 2:3, test 3:3
- 공백 ( ) 사용 : test 0 3, test 1 3, test 2 3

아래와 같이 구성 시 3개의 job 을 가진 *build ruby* 라는 그룹화된 파이프라인 확인이 가능하다.

```yaml
build ruby 1/3:
  stage: build
  script:
    - echo "ruby1"

build ruby 2/3:
  stage: build
  script:
    - echo "ruby2"

build ruby 3/3:
  stage: build
  script:
    - echo "ruby3"
```

![그룹화된 파이프라인<br />(출처 : https://docs.gitlab.com/ee/ci/pipelines/index.html)](/assets/img/dev/2020/1009/group2.jpg)

---

## 파이프라인 아키텍처

파이프라인 아키텍쳐는 3가지로 분류할 수 있다.

- **Basic**<br />
    - 간단한 프로젝트에 적합
- **DAG (Directed Acyclic Graph)**<br />
    - 복잡한 프로젝트에 적합
- **Child/Parent Pipelines**<br />
    - 독립적으로 정의된 구성 요소가 많은 프로젝트에 적합

---

### 파이프라인 아키텍처 - Basic

GitLab 에서 가장 간단한 구조의 파이프라인으로 빌드 stage 의 모든 항목을 동시에 실행하고, 
모든 작업이 완료되면 테스트 stage 의 모든 항목을 동일한 방식으로 실행한다.<br />
유지 관리는 쉽지만, 가장 효율적인 방법은 아니며 단계가 많아질수록 상당히 복잡해진다.

![파이프라인 - 기본 아키텍처](/assets/img/dev/2020/1009/pipeline.jpg)

```yaml
stages:
  - build
  - test
  - deploy

build_a:
  stage: build
  tags:
    - ci-tag
  script:
    - echo "This job builds something."

build_b:
  stage: build
  tags:
    - ci-tag
  script:
    - echo "This job builds something else."

test_a:
  stage: test
  tags:
    - ci-tag
  script:
    - echo "This job tests something. It will only run when all jobs in the"
    - echo "build stage are complete."

test_b:
  stage: test
  tags:
    - ci-tag
  script:
    - echo "This job tests something else. It will only run when all jobs in the"
    - echo "build stage are complete too. It will start at about the same time as test_a."

deploy_a:
  stage: deploy
  tags:
    - ci-tag
  script:
    - echo "This job deploys something. It will only run when all jobs in the"
    - echo "test stage complete."

deploy_b:
  stage: deploy
  tags:
    - ci-tag
  script:
    - echo "This job deploys something else. It will only run when all jobs in the"
    - echo "test stage complete. It will start at about the same time as deploy_a."
```

---

### 파이프라인 아키텍처 - DAG (Directed Acyclic Graph)

DAG 는 기본 아키텍처보다 효율적이고 빠른 실행을 가능하게 해준다.<br />
`needs` 키워드를 통해 job 간의 종속성을 정의하여 사용한다.

예를 들면 아래의 예에서 build_a 와 test_a 가 build_b, test_b 보다 훨씬 빠르면 build_b 가 아직 실행 중이라도
GitLab 은 deploy_a 를 시작한다.

이는 독립적으로 배포 가능하지만 관련성 있는 마이크로서비스의 배포처럼 복잡한 배포 처리 시 특히 효율적이다.

좀 더 자세한 사항은 [Directed Acyclic Graph](https://docs.gitlab.com/ee/ci/directed_acyclic_graph/index.html) 를 참고하세요.

![파이프라인 - DAG 아키텍처](/assets/img/dev/2020/1009/dag.jpg) 

```yaml
stages:
  - build
  - test
  - deploy

build_a:
  stage: build
  tags:
    - ci-tag
  script:
    - echo "This job builds something quickly."

build_b:
  stage: build
  tags:
    - ci-tag
  script:
    - echo "This job builds something else slowly."

test_a:
  stage: test
  tags:
    - ci-tag
  needs: [build_a]
  script:
    - echo "This test job will start as soon as build_a finishes."
    - echo "It will not wait for build_b, or other jobs in the build stage, to finish."

test_b:
  stage: test
  tags:
    - ci-tag
  needs: [build_b]
  script:
    - echo "This test job will start as soon as build_b finishes."
    - echo "It will not wait for other jobs in the build stage to finish."

deploy_a:
  stage: deploy
  tags:
    - ci-tag
  needs: [test_a]
  script:
    - echo "Since build_a and test_a run quickly, this deploy job can run much earlier."
    - echo "It does not need to wait for build_b or test_b."

deploy_b:
  stage: deploy
  tags:
    - ci-tag
  needs: [test_b]
  script:
    - echo "Since build_b and test_b run slowly, this deploy job will run much later."
```

---

### 파이프라인 아키텍처 - Child/Parent Pipelines

구성을 여러 파일로 분리 후 `trigger` 키워드를 통해 파이프라인을 구성하는 방법으로 구성 파일을 간단하게 유지 관리할 수 있다.

- **rules**<br />
    - 예를 들어 해당 영역이 변경된 경우만 하위 파이프라인을 트리거함
- **include**<br /> 
    - 외부의 yaml 파일을 포함시킴으로써 CI/CD 구성을 여러 파일로 나누어 긴 구성 파일의 가독성을 높임
    - 모든 프로젝트에 대한 전역 변수와 같은 중복 구성을 방지할 수 있음

좀 더 자세한 내용은 [rules](https://docs.gitlab.com/ee/ci/yaml/README.html#rules) 와
[include](https://docs.gitlab.com/ee/ci/yaml/README.html#include) 를 참고하세요.


![파이프라인 - Child/Parent Pipelines 아키텍처 (a 디렉터리 안의 내용이 변경된 경우)](/assets/img/dev/2020/1009/trigger.jpg)

.gitlab-ci.yml 의 내용은 아래와 같다.
a 디렉터리 안의 내용이 변경되면 a 디렉터리에 위한 gitlab-ci.yml 을 실행한다. 

```yaml
stages:
  - triggers

trigger_a:
  stage: triggers
  trigger:
    include: a/.gitlab-ci.yml
  rules:
    - changes:
        - a/*

trigger_b:
  stage: triggers
  trigger:
    include: b/.gitlab-ci.yml
  rules:
    - changes:
        - b/*
```

/a/.gitlab-ci.yml 에 위치한 구성 파일이고, DAG 기법을 사용하기 위해 `needs` 키워드를 사용하였다.

```yaml
stages:
  - build
  - test
  - deploy

build_a:
  stage: build
  tags:
    - ci-tag
  script:
    - echo "This job builds something."

test_a:
  stage: test
  tags:
    - ci-tag
  needs: [build_a]
  script:
    - echo "This job tests something."

deploy_a:
  stage: deploy
  tags:
    - ci-tag
  needs: [test_a]
  script:
    - echo "This job deploys something."
```

/b/.gitlab-ci.yml 에 위치한 구성 파일이고, DAG 기법을 사용하기 위해 `needs` 키워드를 사용하였다.

```yaml
stages:
  - build
  - test
  - deploy

build_b:
  stage: build
  tags:
    - ci-tag
  script:
    - echo "This job builds something else."

test_b:
  stage: test
  tags:
    - ci-tag
  needs: [build_b]
  script:
    - echo "This job tests something else."

deploy_b:
  stage: deploy
  tags:
    - ci-tag
  needs: [test_b]
  script:
    - echo "This job deploys something else."
```

---

## 효율적인 파이프라인 구성

파이프라인을 효율적으로 구성하면 개발자의 시간을 절약할 수 있다.

- DevOps 프로세스 속도 향상
- 비용 절감
- 개발 피드백 루프 단축

비효율적인 파이프라인을 확인하는 가장 쉬운 지표는 job, stage 의 런타임 시간과 파이프라인 자체의 총 런타임 시간이다.<br />
파이프라인 총 런타임 시간은 아래 내용에 의해 크게 영향을 받는다.

- job 과 stage 의 총 갯수
- job 간의 종속성

여러 항목을 병렬로 실행하는 job 을 동일한 stage 에서 실행하여 전체 런타임을 줄일 수 있다. 단, 병렬 작업을 지원하기 위해
더 많은 Runner 가 동시에 실행이 되어야 한다.

[GitLab CI Pipelines Exporter](https://github.com/mvisonneau/gitlab-ci-pipelines-exporter) 을 사용하면 파이프라인의 상태 및
수행 시간을 확인할 수 있다.

또한 호스트 시스템의 [monitor CI runners](https://docs.gitlab.com/runner/monitoring/) 를 이용하거나 쿠버네티스를 이용하는 방법도 있다. 

---

## 파이프라인 스케쥴링

파이프라인은 일반적으로 push 가 발생하는 등 특정 조건이 충족할 경우 실행되는데 일정을 사용하여 특정 간격으로 파이프라인을 실행할 수도 있다.<br />
예를 들면 특정 브랜치에 대해서 매월 1일에 실행한다던가 매일 한번 실행 등의 조건으로 실행 가능하다.

GitLab UI 로 스케쥴링하는 것 외에도 [Pipeline schedules API](https://docs.gitlab.com/ee/api/pipeline_schedules.html) 를 사용하여
파이프라인 일정을 관리할 수 있다.

스케쥴링 파이프라인을 구성하기 위해선 스케쥴링 소유자는 대상 브랜치로의 merge 권한이 있어야 한다.

스케쥴링 구성은 GitLab 사이트의 CI/CD > Schedules 에서 설정할 수 있다.

***주의! CI 에 대한 스케쥴링이지 특정 비즈니스 API 를 주기적으로 호출하는 성격의 스케쥴링이 아니다.*** 

---

## Artifact 사이즈

job 의 아티팩트 최대 크기는 인스턴스 레벨 / 그룹 레벨에서 설정할 수 있다.
MB 단위이며, 기본값은 job 당 100 MB 이다.

좀 더 자세한 내용은 [Maximum artifacts size](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#maximum-artifacts-size) 와
[Jobs artifacts administration](https://docs.gitlab.com/ee/administration/job_artifacts.html) 를 참고해주세요.

---

그 외 Settings > CI/CD 메뉴에 대한 설명은 [CI/CD Settings](https://docs.gitlab.com/ee/ci/pipelines/settings.html) 를 참고해주세요.

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [GitLab CI/CD](https://docs.gitlab.com/ee/ci/README.html)
* [CI/CD pipelines](https://docs.gitlab.com/ee/ci/pipelines/index.html)
* [GitLab CI/CD Pipeline Reference](https://docs.gitlab.com/ee/ci/yaml/README.html)
* [Configuring manual deployments(수동 배포)](https://docs.gitlab.com/ee/ci/environments/index.html#configuring-manual-deployments)
* [Pipeline Architecture](https://docs.gitlab.com/ee/ci/pipelines/pipeline_architectures.html)
* [Directed Acyclic Graph](https://docs.gitlab.com/ee/ci/directed_acyclic_graph/index.html)
* [rules](https://docs.gitlab.com/ee/ci/yaml/README.html#rules)
* [include](https://docs.gitlab.com/ee/ci/yaml/README.html#include)
* [GitLab CI Pipelines Exporter](https://github.com/mvisonneau/gitlab-ci-pipelines-exporter)
* [monitor CI runners](https://docs.gitlab.com/runner/monitoring/)
* [Pipeline schedules](https://docs.gitlab.com/ee/ci/pipelines/schedules.html)
* [Job artifacts (war 배포 시 볼 것)](https://docs.gitlab.com/ee/ci/pipelines/job_artifacts.html#retrieve-artifacts-of-private-projects-when-using-gitlab-ci)
* [Maximum artifacts size](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#maximum-artifacts-size)
* [Jobs artifacts administration](https://docs.gitlab.com/ee/administration/job_artifacts.html)
* [Triggering pipelines through the API](https://docs.gitlab.com/ee/ci/triggers/README.html)
* [CI/CD Settings](https://docs.gitlab.com/ee/ci/pipelines/settings.html)