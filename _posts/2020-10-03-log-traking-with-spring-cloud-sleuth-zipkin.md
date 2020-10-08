---
layout: post
title:  "Spring Cloud - Sleuth, Papertrail, Zipkin 을 이용한 분산 추적"
date:   2020-10-03 10:00
categories: dev
tags: msa sleuth papertrail zipkin log-tracking  
---
이 포스트는 MSA 를 보다 편하게 도입할 수 있도록 해주는 Spring Cloud Sleuth, Papertrail, Zipkin 을 이용한 분산 추적에 대해 기술한다.
관련 소스는 [github/assu10](https://github.com/assu10/msa-springcloud) 를 참고 바란다.

>[1. Spring Cloud Config Server - 환경설정 외부화 및 중앙 집중화](https://assu10.github.io/dev/2020/08/16/spring-cloud-config-server/)<br />
>[2. Eureka - Service Registry & Discovery](https://assu10.github.io/dev/2020/08/26/spring-cloud-eureka/)<br />
>[3. Zuul - Proxy & API Gateway (1/2)](https://assu10.github.io/dev/2020/08/26/netflix-zuul/)<br />
>[4. Zuul - Proxy & API Gateway (2/2)](https://assu10.github.io/dev/2020/09/05/netflix-zuul2/)<br />
>[5. OAuth2, Security - 보안 (1/2)](https://assu10.github.io/dev/2020/09/12/spring-cloud-oauth2.0/)<br />
>[6. OAuth2, Security - 보안 (2/2)](https://assu10.github.io/dev/2020/09/30/spring-cloud-oauth2.0-2/)<br />
>[7. Spring Cloud Stream, 분산 캐싱 (1/2)](https://assu10.github.io/dev/2020/10/01/spring-cloud-stream/)<br />
>[8. Spring Cloud Stream, 분산 캐싱 (2/2)](https://assu10.github.io/dev/2020/10/02/spring-cloud-stream-2/)<br /><br />
>***9. Spring Cloud Sleuth, Papertrail, Zipkin 을 이용한 분산 추적***<br />
>- 스프링 클라우드 스트림을 사용한 분산 캐싱
>- 분산 캐싱 구현
>   - 스프링 데이터 레디스 의존성 추가
>   - 레디스 DB 커넥션을 설정
>   - 스프링 데이터 레디스의 Repository 클래스를 정의
>   - 레디스에서 회원 데이터를 저장/조회
>- 사용자 정의 채널 설정 및 EDA 기반의 캐싱 구현
>   - 사용자 정의 채널 설정
>   - 메시지 수신 시 캐시 무효화

이전 내용은 위 목차에 걸려있는 링크를 참고 바란다.

---

---

## 참고 사이트 & 함께 보면 좋은 사이트
* [스프링 마이크로서비스 코딩공작소](https://thebook.io/006962/)
* [Jedis](https://github.com/xetorthio/jedis)
* [Windows 에 Redis 설치](https://goni9071.tistory.com/473)
* [Redis Download](https://github.com/microsoftarchive/redis/releases/tag/win-3.2.100)
* [Redis key 값에 unicode 제거](https://medium.com/@yongkyu.jang/springboot-%EA%B0%9C%EB%B0%9C%ED%99%98%EA%B2%BD%EA%B5%AC%EC%84%B1-2%EB%B2%88%EC%A7%B8-%EA%B8%80%EC%97%90-%EC%9D%B4%EC%96%B4-%EC%9D%B4%EB%B2%88%EC%97%90%EB%8A%94-%EC%9B%90%EB%9E%98-rest-%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%B4%EC%84%9C-springboot%EA%B8%B0%EB%B0%98-api-%EC%96%B4%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%EC%9D%84-%EA%B0%9C%EB%B0%9C%ED%95%98%EA%B8%B0-%EC%9C%84%ED%95%9C-%ED%99%98%EA%B2%BD%EC%9D%84-%EA%B5%AC%EC%84%B1%ED%95%98%EB%8A%94-%EA%B1%B8%EB%A1%9C-de5997645b17)
