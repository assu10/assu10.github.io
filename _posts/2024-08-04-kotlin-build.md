---
layout: post
title: "Kotlin - 코틀린 빌드"
date: 2024-08-04
categories: dev
tags: kotlin gradle build
---

이 포스트에서는 Gradle 로 코틀린 프로젝트를 빌드하는 것에 대해 알아본다.

---

**개발 환경**

- 언어: kotlin 1.9.23
- IDE: intelliJ
- SDK: JDK 17
- 의존성 관리툴: Gradle 8.5

---

Gradle 은 안드로이드 프로젝트의 표준 빌드 시스템이며, 코틀린을 사용할 수 있는 모든 유형의 프로젝트를 지원한다.  
Gradle 은 유연한 프로젝트 모델을 제공하며, 점진적 빌드, 장시간 실행되는 빌드 프로세스 등의 고급 기법을 통해 더 나은 빌드 성능을 제공하기 때문에 
코틀린 프로젝트를 빌드할 때는 Gradle 사용을 권장한다.

코틀린 스크립트를 사용하면 애플리케이션을 작성하는 언어로 빌드 스크립트도 작성할 수 있다는 장점이 있다.

여기서는 Gradle 빌드 스크립트에 그루비를 사용한다.

코틀린 프로젝트를 JVM 을 타겟으로 빌드하는 표준 Gradle 빌드 스크립트는 아래와 같다.

```kotlin
buildscript {
    // 사용할 코틀린 버전 지정
    ext.kotlin_version = '1.3.0'
    repositories {
        mavenCentral()
    }
    // 코틀린 Gradle 플러그인에 대한 빌드 스크립트 의존관계 추가
    dependencies {
        classpath "org.jetbranis.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

apply plugin: 'java'
apply plugin: 'kotlin'  // 코틀린 Gradle 플러그인 적용

repositories {
    mavenCentral()
}

// 코틀린 표준 라이브러리에 대한 프로젝트 의존관계 추가
dependencies {
    compile "org.jetbranis.kotlin:kotlin-stdlib:$kotlin_version"
}
```

---

# 참고 사이트 & 함께 보면 좋은 사이트

*본 포스트는 드리트리 제메로프, 스베트라나 이사코바 저자의 **Kotlin In Action** 을 기반으로 스터디하며 정리한 내용들입니다.*

* [Kotlin In Action](https://www.yes24.com/Product/Goods/55148593)
* [Kotlin In Action 예제 코드](https://github.com/AcornPublishing/kotlin-in-action)
* [Kotlin Github](https://github.com/jetbrains/kotlin)
* [코틀린 doc](https://kotlinlang.org/docs/home.html)
* [코틀린 lib doc](https://kotlinlang.org/api/latest/jvm/stdlib/)
* [코틀린 스타일 가이드](https://kotlinlang.org/docs/coding-conventions.html)