---
layout: post
title:  ".gitlab-ci.yml 에 대하여"
date:   2020-10-09 10:00
categories: dev
tags: gitlab devops gitlab-runner ci cd  
---

이 글은 GitLab CI/CD Pipeline 구성파일인 .gitlab-ci.yml 에 대해 설명합니다.

>[GitLab-Runner 설치 & 등록(Windows)](https://assu10.github.io/dev/2020/10/08/gitlab-runner-1/)<br />
>[GitLab CI/CD Pipeline 구성](https://assu10.github.io/dev/2020/10/09/gitlab-runner-2/)<br /><br />
>***.gitlab-ci.yml 에 대하여***<br />
>- .gitlab-ci.yml
>- job 구성 요소
>- 전역 파라미터
>   - stages
>   - include
>       - include:local
>   - script
>       - script: before_script, after_script
>       - script:  Multi-line commands
>   - stage
>   - extends
>   - rules
>   - needs
>   - allow_failure
>   - when
>   - environment
>   - artifacts
>       - artifacts:path
>   - trigger
>       - trigger:strategy
>   - pages

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

## .gitlab-ci.yml

GitLab CI/CD 파이프라인은 `.gitlab-ci.yml` 이라는 파일로 구성이 된다.<br />
이 `.gitlab-ci.yml`(이하 구성 파일) 파일은 아래 내용을 정의한다.

- 파이프라인의 구조와 순서를 정의
- GitLab Runner 를 사용하여 실행할 항목
- 특정 상황이 발생했을 때 실행할 항목. (예를 들면 프로세스가 성공 혹은 실패했을 때 어떠한 액션을 취할지)

좀 더 많은 예제는 [GitLab CI/CD Examples](https://docs.gitlab.com/ee/ci/examples/README.html) 를 참고하세요.<br />
복잡한 구조의 구성은 [여기](https://gitlab.com/gitlab-org/gitlab/blob/master/.gitlab-ci.yml) 를 참고하세요.

파이프라인 구성은 `job` 으로 시작하는데 이 `job` 은 구성 파일의 가장 기본적인 요소이다.

- **job**<br />
    - 실행되어야 하는 상황(특정 조건)을 제약 조건으로 정의
    - 최상위 요소이며, 반드시 script 를 포함해야 함
    - 정의할 수 있는 수의 제한 없음

```shell
job1:
  script: "execute-script-for-job1"

job2:
  script: "execute-script-for-job2"
```

위는 각 job 이 서로 다른 명령을 실행하는 두 개의 개별 job 이다.
이 job 은 Runner 에 의해 선택되어 Runner 안에서 실행된다. 

---

## job 구성 요소

job 의 동작을 정의하는 파라미터들은 아래와 같다.

좀 더 정확한 의미는 [Configuration parameters](https://docs.gitlab.com/ee/ci/yaml/README.html#configuration-parameters) 를 참고하세요.

(너무 기본적인 내용이거나 큰 의미가 없는 파라미터는 공란으로 두고, 해석이 애매한 파라미터는 원본 그대로 처리)

| 키워드 | 동작 |
|---|:---:|
| `script` |  |
| `after_script` | job 이 종료된 후 실행되는 커맨드 집합 |
| `allow_failure` | job 의 실패 허용, <br />실패한 job 은 커밋 상태에 영향을 주지 않음 |
| `artifacts` | job 성공 시 첨부할 파일, 디렉토리 리스트<br />`artifacts:paths`, `artifacts:exclude`, `artifacts:expose_as`, `artifacts:name`, `artifacts:untracked`, `artifacts:when`, `artifacts:expire_in`, `artifacts:reports` |
| `before_script` |  |
| `cache` | 후속(?) 실행들 간 캐시되어야 할 파일 리스트<br />`cache:paths`, `cache:key`, `cache:untracked`, `cache:policy` |
| `coverage` |  |
| `dependencies` | Restrict which artifacts are passed to a specific job by providing a list of jobs to fetch artifacts from. |
| `environment` | job deploy 환경의 이름<br />`environment:name`, `environment:url`, `environment:on_stop`, `environment:auto_stop_in`, `environment:action` |
| `except` |  |
| `extends` | 해당 job 이 상속받은 구성 항목 |
| `image` | 도커 이미지 사용/<br />`image:name`, `image:entrypoint` |
| `include` | 외부 yaml 파일 포함. <br />`include:local`, `include:file`, `include:template`, `include:remote` |
| `interruptible` | 새로운 실행으로 인해 중복 실행이 될 때 해당 job 을 취소할 수 있는지 여부 |
| `only` | job 생성 제한, `rules` 가 더 유연하고 강력함 |
| `pages` | GitLab 사이트에서 사용할 job 의 결과 업로드 |
| `parallel` | 병렬로 실행할 job 인스턴스의 갯수 |
| `release` | Instructs the runner to generate a Release object. |
| `resource_group` | Limit job concurrency. |
| `retry` | 실행 실패 시 job 의 재시도 할 수 있는 시기와 횟수 |
| `rules` | job 을 생성할 지 말지에 대한 조건 <br />`only/except` 와 함께 사용할 수 없음 |
| `services` | 도커 이미지 사용.<br />`services:name`, `services:alias`, `services:entrypoint`, `services:command`  |
| `stage` | job 이 실행되는 단계. 디폴트는 test |
| `tags` | Runner 선택 시 사용되는 태그 목록 |
| `timeout` | job 레벨에서의 타임 아웃 |
| `trigger` |  |
| `variables` | job 레벨 에서의 변수 |
| `when` | job 실행 시기.<br />`when:manual`, `when:delayed`  |

---

## 전역 파라미터

모든 job 에 공툥으로 사용되는 전역 파라미터는 `default` 키워드를 사용하여 설정 가능하다.

`default` 키워드 내 사용 가능한 job 파라미터는 아래와 같다.

- image
- services
- before_script
- after_script
- tags
- cache
- artifacts
- retry
- timeout
- interruptible

예를 들면 아래에서 ruby:2.5 는 rspec 2.6 job 을 제외한 모든 job 에 적용된다. 

```shell
default:
  image: ruby:2.5

rspec:
  script: bundle exec rspec

rspec 2.6:
  image: ruby:2.6
  script: bundle exec rspec
```

---

### stages

job 이 실행되는 단계를 의미한다.

동일한 stage 안에 있는 job 은 병렬적으로 실행되며, 다음 stage 의 job 은 이전 stage 가 성공적으로 완료된 후 실행된다.

```shell
stages:
  - build
  - test
  - deploy
```

build stage 의 모든 job 이 성공적으로 완료되면 test stage 의 job 이 실행되고, deploy stage 또한 마찬가지로 동작한다.

.gitlab-ci.yml 에 정의된 stage 가 없으면 기본적으로 build, test, deploy 가 사용된다.

---

### include

`include` 키워드를 사용하여 외부 yaml 파일을 포함할 수 있다.
CI/CD 구성을 여러 파일로 나누어 긴 구성 파일의 가독성을 높이고, 전역 기본 변수와 같은 중복 구성을 방지할 수 있다.

`include` 는 외부 yaml 파일의 확장자가 반드시 .yml 혹은 .yaml 이어야 한다.

- local
    - 로컬 프로젝트 repository 안의 파일을 포함
- file
    - 다른 프로젝트 repository 안의 파일을 포함
- remote
    - 원격 URL 의 파일을 포함 / 공개적으로 access 가능해야 함
- template 
    - GitLab 에서 제공하는 템플릿 포함

---

#### include:local
 
```shell
include:
  - local: '/templates/.gitlab-ci-template.yml'

include: '.gitlab-ci-production.yml'
```

그 외는 [include:file](https://docs.gitlab.com/ee/ci/yaml/README.html#includefile),
[include:remote](https://docs.gitlab.com/ee/ci/yaml/README.html#includeremote),
[include:template](https://docs.gitlab.com/ee/ci/yaml/README.html#includetemplate) 를 참고하세요.

include 의 자세한 예제는 [GitLab CI/CD include examples](https://docs.gitlab.com/ee/ci/yaml/includes.html) 에 있습니다.

---

### script

스크립트에 아래 특수 문자가 오는 경우는 따옴표로 묶어서 처리해야 한다.

```shell
:, {, }, [, ], ,, &, *, #, ?, |, -, <, >, =, !, %, @, `
```

스크립트 명령이 0 이 아닌 exit code 를 반환하는 경우 job 이 실패하는데 이럴 경우엔 변수에 exit code 를 저장하여 처리한다.

```shell
job:
  script:
    - false || exit_code=$?
    - if [ $exit_code -ne 0 ]; then echo "Previous command failed"; fi;
```


#### script - before_script, after_script

`before_script` 는 deploy job 을 포함하여 각 job 이 실행되기 전에 수행될 command 의 집합이고, 
`after_script` 는 실패한 job 을 포함하여 각 job 실행 후 수행될 command 의 집합이다.

또한 before/after script 모두 default 셋팅이 되어있어도 각 job 에서 오버라이드 가능하다.

```shell
default:
  before_script:
    - global before script

job:
  before_script:
    - execute this instead of global before script
  script:
    - my command
  after_script:
    - execute this after my script
```

좀 더 자세한 내용은 [YAML anchors for before_script and after_script](https://docs.gitlab.com/ee/ci/yaml/README.html#yaml-anchors-for-before_script-and-after_script)
을 참고하세요.

---

#### script - Multi-line commands

가독성을 높이기 위해 `|` 과 `>` 을 사용하여 긴 command 를 여러 줄로 분할하여 사용 가능하다.

*여러 명령이 하나의 command 로 구성된 경우 마지막 command 의 성공 여부만 리턴 (이전 command 의 실패는 버그로 인해 무시됨) 되므로,
각 명령을 별도 스크립트로 작성할 것*

```shell
build_a:
  stage: build
  tags:
    - ci-tag
  before_script:        # 둘 다 동일
    - |
      echo "First command line
      is split over two lines."
      echo "Second command line."
    - |
      echo "1First command line
      is split over two lines."

      echo "1Second command line."
```

위의 결과는 아래와 같다.
```shell
$ echo "First command line # collapsed multi-line command
First command line
is split over two lines.
Second command line.

$ echo "1First command line # collapsed multi-line command
1First command line
is split over two lines.
1Second command line.
```

```shell
build_a:
  stage: build
  tags:
    - ci-tag
  before_script:        # 결과 상이
    - >
      echo "First command line
      is split over two lines."
      echo "Second command line."   # echo 가 하나의 문자열로 출력
    - >
      echo "2First command line
      is split over two lines."

      echo "2Second command line."
```

위의 결과는 아래와 같다.
```shell
$ echo "First command line is split over two lines." echo "Second command line."
First command line is split over two lines.
echo
Second command line.

$ echo "2First command line is split over two lines." # collapsed multi-line command
2First command line is split over two lines.
2Second command line.
```

```shell
build_a:
  stage: build
  tags:
    - ci-tag
  before_script:        # 결과 상이
    - echo "First command line
      is split over two lines."
      echo "Second command line."       # echo 가 하나의 문자열로 출력

    - echo "3First command line
      is split over two lines."

      echo "3Second command line."
```

위의 결과는 아래와 같다.
```shell
$ echo "First command line is split over two lines." echo "Second command line."
First command line is split over two lines.
echo
Second command line.

$ echo "3First command line is split over two lines." # collapsed multi-line command
3First command line is split over two lines.
3Second command line.
```

---

### stage

Runner 는 기본적으로 한 번에 하나의 job 만 처리한다.

![하나의 stage 안의 여러 job 은 한 번에 하나씩 실행](/assets/img/dev/2020/1009/parallel.jpg)

job 은 아래와 같은 상황에서 병렬적으로 실행된다.

- 다른 Runner 에서 실행
- Runner 의 `concurrent` 셋팅
 
Runner 의 `concurrent` 셋팅은 [runner global settings](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section) 를 참고하세요.


`.pre` 는 항상 파이프라인의 첫 번째로 실행되고, `.post` 는 항상 파이프라인의 마지막으로 실행된다.<br />
(.gitlab-ci.yml 에서 정의한 순서에 상관없음)

예를 들어 아래는 모두 동일한 순서로 실행된다.

```shell
stages:
  - .pre
  - a
  - b
  - .post


stages:
  - a
  - .pre
  - b
  - .post
```

### extends

템플릿 job 을 설정한 후 `extends` 키워드를 통해 상속받을 수 있다.<br />
이 방법은 [YAML anchors](https://docs.gitlab.com/ee/ci/yaml/README.html#anchors) 를 대체할 수 있을 뿐 아니라 더 유연하고 가독성이 좋다.

```shell
.build:
  stage: build
  tags:
    - ci-tag
  script: echo "job parent"

job_child_1:
  extends:
    - .build
  script: echo "job child 1"    # 오버라이드 가능

job_child_2:
  extends:
    - .build
```

다단계 상속도 가능하지만 최대 3 depth 이상의 상속은 피하는 것이 좋다.

`include` 와 `extends` 를 함께 사용하면 좀 더 유지 관리하기 편한 구조로 구성 파일을 관리할 수 있다.

```shellscript
# event-ci-template.yml

.event-template:
  tags:
    - ci-tag
  script:
    - echo event


# .gitlab-ci.yml
include: event-ci-template.yml

job1:
  extends: .event-template
  stage: build
```

---

### rules

***rules 는 only/except 보다 더 유연하고 강력한 솔루션이다. 파이프라인을 최대한 활용하려면 only/except 대신 rules 를 사용하는 것을 권장한다.***

`rules` 키워드는 파이프라인에 job 을 포함시키거나 제외시킬 때 사용할 수 있다.

단, `only/except` 키워드의 함께 사용할 수 없다. 동일한 job 에 두 키워드를 함께 사용 시 `key may not be used with rules` 오류가 발생한다.

`rules` 에서 허용하는 job 속성은 아래와 같다.

- `when`
    - 정의하지 않으면 기본값은 `when: on_success`
    - `when: delayed` 사용시엔 `start_in` 도 정의해야 함
- `allow_failure`
    - 정의하지 않으면 기본값은 `allow_failure: false`
    
```shell
job1:
  tags:
    - ci-tag
  stage: build
  script:
    - echo event
  rules:
    - if: '$CI_COMMIT_BRANCH == "master"'
      when: delayed
      start_in: '30 seconds'
      allow_failure: false
    - if: '$CI_COMMIT_BRANCH == "master22"'
      when: delayed
      start_in: '50 minutes'
      allow_failure: true
```    

```shell
job:
  script: "echo Hello, Rules!"
  rules:
    - if: ($CI_COMMIT_BRANCH == "master" || $CI_COMMIT_BRANCH == "develop") && $MY_VARIABLE
      when: manual
      allow_failure: true
```

위 예에서 조건에 맞는 경우 job 은 수동으로 실행시켜 주어야 하고, 성공 여부는 true 로 설정된다.

- [`if`](https://docs.gitlab.com/ee/ci/yaml/README.html#rulesif)
    - 조건에 따라 job 을 추가/제외할 때 사용
- [`change`](https://docs.gitlab.com/ee/ci/yaml/README.html#ruleschanges)
    - 변경된 파일에 따라 job 을 추가/제외할 때 사용
    - `only: changes` / `except: changes` 와 동일하게 동작
- [`exist`](https://docs.gitlab.com/ee/ci/yaml/README.html#rulesexists)
    - 특정 파일 존재 여부에 따라 job 을 추가/제외할 때 사용 


```shell
job:
  script: "echo Hello, Rules!"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: never
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
      when: never
    - when: on_success
```

위에서 merge request 인 경우 job 은 파이프라인에 추가되지 않는다.<br />
스케쥴링 파이프라인인 경우 job 은 파이프라인에 추가되지 않는다.<br />
그 외 경우의 job 은 파이프라인에 추가된다.

`rules:if` 에 `$CI_PIPELINE_SOURCE` 가 많이 사용되는데,
`$CI_PIPELINE_SOURCE` 의 값으로 사용되는 항목은 
`api`, `chat`, `external`, `external_pull_request_event`, `merge_request_event`,
`parent_pipeline`, `pipeline`, `push`, `schedule`, `trigger`, `web`, `webide` 가 있다.

각 항목의 상세 내용은 [Common if clauses for rules](https://docs.gitlab.com/ee/ci/yaml/README.html#common-if-clauses-for-rules) 를 참고해주세요.


`when` 키워드 사용 시 push 파이프라인과 merge request 파이프라인은 모두 동일한 이벤트에 의해서 트리거 등의 중복으로 파이프라인이 실행될 수 있다.

이는 [`workflow:rules`](https://docs.gitlab.com/ee/ci/yaml/README.html#workflowrules) 와 
[Prevent duplicate pipelines](https://docs.gitlab.com/ee/ci/yaml/README.html#prevent-duplicate-pipelines) 를 통해 해결할 수 있다.

---

### needs

`needs` 키워드는 [DAG](https://docs.gitlab.com/ee/ci/directed_acyclic_graph/index.html) 를 가능하게 해줌으로써 다른 작업을 기다리지 않고
여러 단계를 동시에 실행할 수 있도록 해준다.

```shell
linux:build:
  tags:
    - ci-tag
  stage: build
  script:
    - echo "linux:build"
mac:build:
  tags:
    - ci-tag
  stage: build
  script:
    - echo "mac:build"
lint:
  tags:
    - ci-tag
  stage: test
  needs: []
  script:
    - echo "lint"
linux:rspec:
  tags:
    - ci-tag
  stage: test
  needs: ["linux:build"]
  script:
    - echo "linux:rspec"
linux:rubocop:
  tags:
    - ci-tag
  stage: test
  needs: ["linux:build"]
  script:
    - echo "linux:rubocop"
mac:rspec:
  tags:
    - ci-tag
  stage: test
  needs: ["mac:build"]
  script:
    - echo "mac:rspec"
mac:rubocop:
  tags:
    - ci-tag
  stage: test
  needs: ["mac:build"]
  script:
    - echo "mac:rubocop"
production:
  tags:
    - ci-tag
  stage: deploy
  script:
    - echo "production"
``` 

위에서 lint 는 build 단계가 끝날때까지 기다리지 않고 즉시 실행되고, 나머진 needs 안의 작업이 끝난 후 실행된다.

---

### allow_failure 

나머지 작업에 영향을 주지 않고 job 이 실패하도록 할 때 사용한다.<br />
`rules` 를 사용하지 않을 때 `when:manual` 을 사용하는 수동 작업을 제외하고 기본값은 false 이다.<br />

예를 들어 아래에서 job1 과 job2 는 병렬로 실행되지만 job1 이 실패하더라고 `allow_failure:true` 이므로 다음 stage 가 실행된다.

```shell
job1:
  stage: test
  script:
    - execute_script_that_will_fail
  allow_failure: true

job2:
  stage: test
  script:
    - execute_script_that_will_succeed

job3:
  stage: deploy
  script:
    - deploy_to_staging
```

---

### when

- `on_success`
    - 이전 stage 의 모든 job 이 성공한 경우에만 job 을 실행
- `on_failure`
    - 이전 stage 의 job 이 하나 이상 실패한 경우에만 job 을 실행
- `always`
    - 이전 stage 의 job 상태에 상관없이 job 을 실행
- `manual`
    - job 을 수동으로 실행
- `delayed`
    - 특정 시간 후에 job 을 실행
- `never`
    - `rules` 와 함께 사용 시 job 을 실행하지 않음
    - `workflow:rules` 와 함께 사용 시 파이프라인을 실행하지 않음

```shell
stages:
  - build
  - cleanup_build
  - test
  - deploy
  - cleanup

build_job:
  stage: build
  script:
    - make build

cleanup_build_job:
  stage: cleanup_build
  script:
    - cleanup build when failed
  when: on_failure

test_job:
  stage: test
  script:
    - make test

deploy_job:
  stage: deploy
  script:
    - make deploy
  when: manual

cleanup_job:
  stage: cleanup
  script:
    - cleanup after jobs
  when: always
```

- *build_job* 이 실패한 경우에만 *cleanup_build_job* 실행
- job 의 성공 여부와 상관없이 항상 파이프라인의 마지막 단계로 *cleanup_job* 실행
- GitLab UI 에서 수동으로 실행할 때 *deploy_job* 실행

`when:manual` 은 프로덕션 환경에서의 배포 시 사용하는데 자세한 내요은 [Configuring manual deployments](https://docs.gitlab.com/ee/ci/environments/index.html#configuring-manual-deployments)
을 참고하세요.

---

### environment

`environment` 는 특정 환경에 배포되도록 정의할 때 사용한다.
`environment` 이 지정되었는데 해당 이름의 `environment` 이 없으면 새로운 `environment` 이 자동으로 생성된다.

```shell
deploy to production:
  stage: deploy
  script: git push production HEAD:master
  environment: 
    - name: production
```

일반적으로 qa, staging, production 등의 이름을 사용한다.


---

### artifacts

`artifacts` 는 job 이 완료된 후 (성공, 실패, 혹은 항상) 첨부되는 파일 혹은 디렉토리 목록 지정 시 사용된다.

job 이 완료된 후 아티팩트가 GitLab 으로 전송되며, [최대 아티팩트 크기(1G)](https://docs.gitlab.com/ee/user/gitlab_com/index.html#gitlab-cicd)가 크지 않으면 GitLab UI 에서 다운로드할 수 있다.

좀 더 자세항 사항은 [job_artifacts](https://docs.gitlab.com/ee/ci/pipelines/job_artifacts.html) 을 참고하세요.

---

#### artifacts:path

아래의 경우 임시 아티팩트는 생성하지 않도록 하기 위해 tag 가 지정된 job 만 아티팩트를 생성하도록 한다.
default-job 은 아티팩트를 생성하지 않는다. 

```shell
default-job:
  script:
    - mvn test -U
  except:
    - tags

release-job:
  script:
    - mvn package -U
  artifacts:
    paths:
      - target/*.war
  only:
    - tags
```
  
좀 더 자세한 내용은 [artifacts](https://docs.gitlab.com/ee/ci/yaml/README.html#artifacts) 을 참고하세요. 

---

### trigger

자식 파이프라인 생성은 하위 파이프라인 ci 구성이 포함된 yaml 파일의 경로를 지정하면 된다.<br />
단일 저장소이면서 특정 파일이 변경될 때만 파이프라인을 트리거하는 경우 `only: change` 가 유용하다.

좀 더 자세한 사항은 [Parent-child pipelines](https://docs.gitlab.com/ee/ci/parent_child_pipelines.html) 을 참고하세요.


#### trigger:strategy

기본적으로 trigger job 은 다운스트림 파이프라인이 생성되는 즉시 성공 상태로 완료된다.<br />
다운스트림 파이프라인이 완료될 때까지 trigger job 이 기다리게 하려면 `strategy: depend` 를 사용하면 된다. 

`strategy: depend` 는 트리거된 파이프라인이 완료될 때까지 trigger job 이 *running* 상태로 대기하도록 한다.

```yaml
microservice_a:
  trigger:
    include: path/to/microservice_a.yml
    strategy: depend
```

---

### pages

pages 는 static 컨텐츠 업로드 시 사용한다.

- 모든 static contents 는 public/ 디렉토리 아래 있어야 함
- public/ 디렉터리에 대한 경로가 있는 아티팩트가 정의되어야 함


아래 예는 단순히 프로젝트 루트에서 public/ 디렉토리로 모든 파일을 이동하는 스크립트이다.

```shell
pages:
  stage: deploy
  script:
    - mkdir .public
    - cp -r * .public
    - mv .public public
  artifacts:
    paths:
      - public
  only:
    - master
```

좀 더 자세한 내용은 [GitLab Pages](https://docs.gitlab.com/ee/user/project/pages/index.html) 를 참고하세요.

---


[inherit](https://docs.gitlab.com/ee/ci/yaml/README.html#inherit)
[workflow:rules](https://docs.gitlab.com/ee/ci/yaml/README.html#workflowrules)
[image](https://docs.gitlab.com/ee/ci/yaml/README.html#image)
[only/except (basic)](https://docs.gitlab.com/ee/ci/yaml/README.html#onlyexcept-basic)
[only/except (advanced)](https://docs.gitlab.com/ee/ci/yaml/README.html#onlyexcept-advanced)
[when:delayed](https://docs.gitlab.com/ee/ci/yaml/README.html#whendelayed)
[(특정 환경 배포 시) environment](https://docs.gitlab.com/ee/ci/yaml/README.html#environment)
[coverage](https://docs.gitlab.com/ee/ci/yaml/README.html#coverage)
[retry](https://docs.gitlab.com/ee/ci/yaml/README.html#retry)
[timeout](https://docs.gitlab.com/ee/ci/yaml/README.html#timeout)
[parallel](https://docs.gitlab.com/ee/ci/yaml/README.html#parallel)
[interruptible](https://docs.gitlab.com/ee/ci/yaml/README.html#interruptible)
[resource_group](https://docs.gitlab.com/ee/ci/yaml/README.html#resource_group)
[secrets](https://docs.gitlab.com/ee/ci/yaml/README.html#secrets)
[(향후 없어지거나 변경) Git strategy](https://docs.gitlab.com/ee/ci/yaml/README.html#git-strategy)
[(extends 로 사용 예정) Anchors](https://docs.gitlab.com/ee/ci/yaml/README.html#anchors)

---

# 추후 확인 예정

[cache](https://docs.gitlab.com/ee/ci/yaml/README.html#cache)
[job_artifacts](https://docs.gitlab.com/ee/ci/pipelines/job_artifacts.html)

---

## 참고 사이트 & 함께 보면 좋은 사이트

* [GitLab CI/CD pipeline configuration reference](https://docs.gitlab.com/ee/ci/yaml/README.html)
* [Configuration parameters](https://docs.gitlab.com/ee/ci/yaml/README.html#configuration-parameters)
* [스크립트 컬러링](https://docs.gitlab.com/ee/ci/yaml/README.html#coloring-script-output)
* [yaml-multiline](https://yaml-multiline.info/)
* [사전 정의된 환경 변수](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html)
* [$CI_PIPELINE_SOURCE value 종류](https://docs.gitlab.com/ee/ci/yaml/README.html#common-if-clauses-for-rules)

---

## 관련하여 나중에 보면 좋은 사이트

* [GitLab CI/CD Variable](https://docs.gitlab.com/ee/ci/variables/README.html)
* [GitLab Runner advanced configuration](https://docs.gitlab.com/runner/configuration/advanced-configuration.html)
* [큰 규모의 프로젝트 구성파일](https://gitlab.com/gitlab-org/gitlab/blob/master/.gitlab-ci.yml)
* [전역 파라미터 - inherit](https://docs.gitlab.com/ee/ci/yaml/README.html#inherit)
* [전역 파라미터 - workflow:rules](workflow:rules)
* [GitLab CI/CD include examples](https://docs.gitlab.com/ee/ci/yaml/includes.html)
* [.gitlab-ci.yml Parameter details](https://docs.gitlab.com/ee/ci/yaml/README.html#parameter-details)
* [GitLab Runner 셋팅](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section)
* [only/except (basic)](https://docs.gitlab.com/ee/ci/yaml/README.html#onlyexcept-basic)
* [only/except (advanced)](https://docs.gitlab.com/ee/ci/yaml/README.html#onlyexcept-advanced)
* [Artifact downloads with needs](https://docs.gitlab.com/ee/ci/yaml/README.html#artifact-downloads-with-needs)
* [(프로덕션 환경에서의 배포)Configuring manual deployments](https://docs.gitlab.com/ee/ci/environments/index.html#configuring-manual-deployments)
* [when:delayed](https://docs.gitlab.com/ee/ci/yaml/README.html#whendelayed)
* [(특정 환경 배포 시)environment](https://docs.gitlab.com/ee/ci/yaml/README.html#environment)