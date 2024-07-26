---
layout: post
title:  "Git commit message convention"
date: 2024-04-22
categories: dev
tags: web git-commit-convention
---

이 포스트에서는 Git Commit Message Convention 에 대해 알아본다.


<!-- TOC -->
* [1. Commit Message Structure](#1-commit-message-structure)
* [2. Commit Type](#2-commit-type)
* [3. Subject](#3-subject)
* [4. Body](#4-body)
* [5. Footer](#5-footer)
* [참고 사이트 & 함께 보면 좋은 사이트](#참고-사이트--함께-보면-좋은-사이트)
<!-- TOC -->

---

# 1. Commit Message Structure

기본적으로 커밋 메시지는 subject, body, footer 로 구성한다.

```text
type: subject

body

footer
```

---

# 2. Commit Type

- `feat`
  - 새로운 기능 추가
- `fix`
  - 버그 수정
- `docs`
  - 문서 수정
- `style`
  - 코드 포맷팅, 세미콜론 누락, 코드 변경이 없는 경우
- `refactor`
  - 코드 리팩토링
- `test`
  - 테스트 코드, 리펙토링 테스트 코드 추가
- `chore`
  - 빌드 업무 수정, 패키지 매니저 수정

---

# 3. Subject

제목은 50자를 넘기지 않고, 첫 글자는 대문자로 작성하며 마침표를 붙이지 않는다.    
과거 시제가 아니라 명령어로 작성한다.

예) Fixed → Fix, Added → Add

---

# 4. Body

선택 사항이므로 꼭 작성할 필요는 없다.  
부연 설명이 필요할 경우에 작성한다.

---

# 5. Footer

선택 사항이므로 꼭 작성할 필요는 없다.  
issue tracker id 를 작성할 때 사용한다.

---

# 참고 사이트 & 함께 보면 좋은 사이트

* [Git - 커밋 메시지 컨벤션](https://doublesprogramming.tistory.com/256)
* [Udacity Git Commit Message Style Guide](https://udacity.github.io/git-styleguide/)