---
layout: post
title:  "Kubernetes - 배치 워크로드: Job,CronJob"
date: 2025-12-27 10:00:00
categories: dev
tags: devops kubernetes k8s job cronjob batch-processing automation controller pod-lifecycle run-to-completion
---

쿠버네티스 대부분의 리소스(Deployment, ReplicaSet, DaemonSet 등)는 서비스가 **중단 없이 계속 실행**되는 것에 초점을 맞춘다. 
웹 서버나 API 서버처럼 항상 요청을 기다려야 하는 애플리케이션이 이에 해당한다.

하지만 데이터 백업, 로그 분석, 이메일 발송, 대용량 연산 등 **특정 작업만 수행하고 완료되면 종료되어야 하는(Run-to-completion)** 워크로드는 어떻게 관리해야 할까?  
계속 살아있으려고 노력하는 디플로이먼트를 사용한다면, 작업이 끝나고 프로세스가 종료될 때마다 쿠버네티스는 이를 '장애'로 판단하고 다시 시작시키려 할 것이다.

이번 포스트에서는 이러한 배치 성격의 작업을 처리하기 위해 설계된 쿠버네티스의 컨트롤러인 **잡(Job)**과, 이를 주기적으로 실행해주는 **크론잡(CronJob)**에 대해 알아본다.

---

**목차**

<!-- TOC -->
* [1. 잡(Job)](#1-잡job)
  * [1.1. Job 생성 및 실행](#11-job-생성-및-실행)
* [2. 크론잡(CronJob)](#2-크론잡cronjob)
  * [2.1. CronJob 생성 및 실행](#21-cronjob-생성-및-실행)
* [정리하며..](#정리하며)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

**개발 환경**

- Guest OS: Ubuntu 24.04.2 LTS
- Host OS: Mac Apple M3 Max
- Memory: 48 GB
- Kubernetes: v1.29.15

---

# 1. 잡(Job)

Job은 하나 이상의 파드를 생성하고, 지정된 수의 파드가 성공적으로 종료될 때까지 이를 관리하는 컨트롤러이다.

- **핵심 로직**
  - 파드가 정상적으로 완료(exit code 0)되면 잡은 해당 작업을 성공으로 간주하고 기록한다.
- **실패 처리**
  - 파드가 실패하거나 노드 장애가 발생하면, Job은 새로운 파드를 생성하여 작업을 끝까지 완수하려고 시도한다.
- **용도**
  - 데이터베이스 마이그레이션, 일회성 스크립트 실행, 배치 처리 등

---

## 1.1. Job 생성 및 실행

간단한 Nginx 이미지를 사용하여 Job을 생성해보자. Job은 `batch/v1` API 그룹에 속한다.

---

**디렉터리 생성**

```shell
assu@myserver01:~/work/ch09$ mkdir ex15
assu@myserver01:~/work/ch09$ cd ex15
```

---

**Job 매니페스트 작성(job-test01.yml)**

```shell
assu@myserver01:~/work/ch09/ex15$ vim job-test01.yml
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-test01
spec:
  template:
    spec:
      containers:
        - name: nginx-test01
          image: nginx:latest
          # 컨테이너가 시작되자마자 "Hello world"를 출력하고 종료되도록 설정
          command: ["echo", "Hello world"]
      # 중요: 재시작 정책, 잡에서는 Always를 사용할 수 없음 (OnFailure 또는 Never 사용)    
      restartPolicy: Never
  backoffLimit: 3  # 잡 실행에 실패할 경우 재시도 횟수 (기본값: 6)
```

- `restartPolicy`
  - 잡의 파드는 완료되는 것이 목표이므로 `Always`(기본값)를 사용하면 안된다.
    - `Never`: 파드가 실패하면 새로운 파드 생성
    - `OnFailure`: 파드가 실패하면 동일한 파드 내에서 컨테이너 재시작
- `backoffLimit`
  - 작업 실패 시 최대 몇 번까지 재시도할 지 설정
  - 재시도 간격은 지수 단위(10s, 20s, 40s..)로 늘어난다.

---

**Job 실행 및 상태 확인**

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl apply -f job-test01.yml
job.batch/job-test01 created

assu@myserver01:~/work/ch09/ex15$ kubectl get job
NAME         COMPLETIONS   DURATION   AGE
job-test01   1/1           4m25s      5m42s
```

`COMPLETIONS`가 1/1 이 되었다는 것은 작업이 성공적으로 끝났음을 의미한다.

---

**Job 상세 정보 확인**

`kubectl describe` 를 통해 내부 동작을 살펴보자.

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl describe job job-test01
Name:             job-test01
Namespace:        default
Selector:         batch.kubernetes.io/controller-uid=744a9b74-0d1f-4f0b-b254-76bdd7f2155e
Labels:           batch.kubernetes.io/controller-uid=744a9b74-0d1f-4f0b-b254-76bdd7f2155e
                  batch.kubernetes.io/job-name=job-test01
                  controller-uid=744a9b74-0d1f-4f0b-b254-76bdd7f2155e
                  job-name=job-test01
Annotations:      <none>
Parallelism:      1
Completions:      1
Completion Mode:  NonIndexed
...
Pods Statuses:    0 Active (0 Ready) / 1 Succeeded / 0 Failed
...
Events:
  Type    Reason            Age   From            Message
  ----    ------            ----  ----            -------
  Normal  SuccessfulCreate  6m7s  job-controller  Created pod: job-test01-7xf2p
  Normal  Completed         102s  job-controller  Job completed
```

이벤트 로그를 보면 컨트롤러가 파드를 생성하고(`SuccessfulCreate`), 작업이 완료되자 Job을 완료 상태(`Completed`)로 변경한 것을 알 수 있다.

**실행된 파드의 로그 확인**

Job이 완료되어도 파드는 삭제되지 않고 `Completed` 상태로 남아있다. 이를 통해 로그나 결과를 확인할 수 있다.

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl get pod
NAME               READY   STATUS      RESTARTS   AGE
job-test01-7xf2p   0/1     Completed   0          6m39s

assu@myserver01:~/work/ch09/ex15$ kubectl logs job-test01-7xf2p
Hello world
```

---

**리소스 정리**

Job을 삭제하면 관련 파드들도 함께 삭제된다.

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl delete -f job-test01.yml
job.batch "job-test01" deleted

assu@myserver01:~/work/ch09/ex15$ kubectl get pod
No resources found in default namespace.
assu@myserver01:~/work/ch09/ex15$ kubectl get job
No resources found in default namespace.
```

---

# 2. 크론잡(CronJob)

CronJob은 리눅스의 crontab과 유사하게 **일정 주기마다 Job을 자동으로 생성**하는 컨트롤러이다.

- **구조**
  - CronJob → Job → Pod의 계층 구조
- **용도**
  - 매일 밤 데이터베이스 백업, 매시간 리포트 생성, 주기적인 캐시 청소 등

---

## 2.1. CronJob 생성 및 실행

1분마다 Hello World~ 를 출력하는 CronJob을 만들어본다.

---

**CronJob 매니페스트 작성(cronjob-test01.yml)**

```shell
assu@myserver01:~/work/ch09/ex15$ vim cronjob-test01.yml
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cronjob-test01
spec:
  schedule: "*/1 * * * *"  # 1분에 한 번씩 실행
  jobTemplate:  # 생성될 Job의 템플릿
    spec:
      template: 
        spec:
          containers:
            - name: nginx-test02
              image: nginx:latest
              command:
                - /bin/sh
                - -c
                - echo Hello World~  # 텍스트 출력
          restartPolicy: Never  # 재시작 정책
```

---

**CronJob 실행 및 확인**

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl apply -f cronjob-test01.yml
cronjob.batch/cronjob-test01 created

assu@myserver01:~/work/ch09/ex15$ kubectl get cronjob
NAME             SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob-test01   */1 * * * *   False     1        5s              6s
```

`LAST SCHEDULE`을 통해 마지막으로 언제 실행되었는지 확인할 수 있다.

---

**CronJob 실행 이력 및 관리**

시간이 조금 지난 후 파드 상태를 확인해보면, 주기에 맞춰 생성된 여러 개의 파드를 볼 수 있다.

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl get pod
NAME                            READY   STATUS      RESTARTS   AGE
cronjob-test01-29454240-mrjbc   0/1     Completed   0          116s
cronjob-test01-29454241-z7qbj   0/1     Completed   0          56s
```

파드 이름 뒤의 숫자 29454240 는 작업이 생성된 시간을 의미한다.

---

**상세 정보 확인**

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl describe cronjob cronjob-test01
Name:                          cronjob-test01
...
Successful Job History Limit:  3
Failed Job History Limit:      1
...
Events:
  Type    Reason            Age   From                Message
  ----    ------            ----  ----                -------
  Normal  SuccessfulCreate  71s   cronjob-controller  Created job cronjob-test01-29454240
  Normal  SawCompletedJob   66s   cronjob-controller  Saw completed job: cronjob-test01-29454240, status: Complete
  Normal  SuccessfulCreate  11s   cronjob-controller  Created job cronjob-test01-29454241
  Normal  SawCompletedJob   6s    cronjob-controller  Saw completed job: cronjob-test01-29454241, status: Complete
```

`History Limit`은 CronJob이 무한정 데이터를 쌓는 것을 방지하기 위해 이력을 관리한다.
- `Successful Job History Limit`
  - 성공한 Job을 몇 개까지 남길지 설정(기본값: 3)
- `Failed Job History Limit`
  - 실패한 Job을 몇 개까지 남길지 설정(기본값: 1)

기본값에 따라 성공한 Job은 최근 3개까지만 파드와 Job 리소스가 유지되고, 오래된 것은 자동으로 삭제된다.

---

**로그 확인**

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl logs cronjob-test01-29454240-mrjbc
Hello World~
```

---

**리소스 정리**

```shell
assu@myserver01:~/work/ch09/ex15$ kubectl delete -f cronjob-test01.yml
cronjob.batch "cronjob-test01" deleted

assu@myserver01:~/work/ch09/ex15$ kubectl get cronjob
No resources found in default namespace.
assu@myserver01:~/work/ch09/ex15$ kubectl get pod
No resources found in default namespace.
```

---

# 정리하며..

Job은 애플리케이션이 지정된 횟수만큼 성공적으로 완료되는 것을 보장한다.  
일회성 배치 작업에 적합하며, 파드 실패 시 재시작 정책(`OnFailure`, `Never`)과 백오프(`backoffLimit`) 설정을 통해 안정성을 보장할 수 있다.

CronJob은 Job을 주기적으로 생성하는 스케줄러 역할을 한다.  
리눅스의 crontab 문법을 사용하며, 실행 이력(History) 관리를 통해 클러스터 리소스 낭비를 방지한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 장철원 저자의 **한 권으로 배우는 도커&쿠버네티스**를 기반으로 스터디하며 정리한 내용들입니다.*

* [한 권으로 배우는 도커&쿠버네티스](https://www.yes24.com/product/goods/126115324)
* [예제 코드](https://github.com/losskatsu/DockerKubernetes)
* [Doc:: Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
* [Doc:: CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)