---
layout: post
title:  "Typescript - TypeORM vs Sequelize"
date:   2023-03-12
categories: dev
tags: typescript typeorm
---

Typescript 를 지원하는 ORM 은 [TypeORM](https://typeorm.io/), [MikroORM](https://mikro-orm.io/docs/installation), [Sequelize](https://sequelize.org/docs/v6/), Knex.js, Prisma 등이 있다.

기술을 선택할 때는 아래 정도의 기준으로 선택하게 된다.

- 풀의 크기 (다운로드 수, Github Stars ..)
- 성능

---

# 풀의 크기

[npm trends](https://npmtrends.com/) 에서 기간 당 다운로드 수, Github Stars 등을 확인할 수 있다.

아래는 Sequelize 와 TypeORM 의 최근 5년간 다운로드 수와 Stars 수 이다.  
[https://npmtrends.com/sequelize-vs-typeorm](https://npmtrends.com/sequelize-vs-typeorm)

![Downloads](/assets/img/dev/2023/0312_1/downloads.png)
![Stars](/assets/img/dev/2023/0312_1/stars.png)

다운로드 수는 Sequelize 가 더 높지만 TypeORM 은 Sequelize 보다 5년 뒤에 나왔음에도 불구하고 Stars 가 더 높고 업데이트도 꾸준히 되고 있다.

---

# 성능

2019 년에 어떤 분이 성능 비교한 [블로그](https://kyungyeon.dev/posts/3)에 따르면 Sequelize 보다 TypeORM 이 성능이 더 좋음을 알 수 있다. 

---

# 참고 사이트 & 함께 보면 좋은 사이트

* [TypeORM vs Sequelize](https://codebibimppap.tistory.com/16)
* [TypeORM](https://typeorm.io/)
* [Sequelize](https://sequelize.org/docs/v6/)
* [MikroORM](https://mikro-orm.io/docs/installation)
* [npm trends](https://npmtrends.com/)
* [Sequelize, TypeORM 성능 비교](https://kyungyeon.dev/posts/3)