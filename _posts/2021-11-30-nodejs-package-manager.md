---
layout: post
title:  "Node.js - 패키지 매니저"
date:   2021-11-30 10:00
categories: dev
tags: nodejs npm package-manager
---

이 포스트는 간단한 npm 사용법과 자신의 코드를 npm 에 배포하여 다른 사람들이 사용할 수 있게 하는 방법에 대해 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - npm (Node Package Manager)
> - package.json
> - 패키지 버전 이해
> - 그 외 npm 명령어
> - 패키지 배포

---

# 1. npm (Node Package Manager)

`npm` 은 말 그대로 노드 패키지 매니저이다.

대부분의 자바스크립트 프로그램은 패키지라는 이름으로 npm 에 등록되어 있으므로 필요하다면 npm 에서 찾아 설치하면 된다.

**npm 에 업로드된 노드 모듈을 패키지**라고 한다.

> `yarn`<br /><br />
> npm 의 대체자로 페이스북이 내놓은 패키지 매니저이다.<br />
> 리액트나 리액트 네이티브같은 페이스북 진영의 프레임워크를 사용할 때 종종 볼 수 있다.

---

# 2. package.json

사용할 패키지는 각각 고유한 버전이 있는데 이러한 **설치 버전을 관리하는 파일**이 바로 `package.json` 이다.

package.json 생성 명령어
```shell
> npm init --y
```

package.json
```json
{
  "name": "chap05",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC"
}
```

scripts 는 npm 명령어를 저장해두는 부분이다.<br />
콘솔에서 `npm run [스크립트 명령어]` 를 입력하면 해당 스크립트가 실행된다. 예) npm run test

test 스크립트 외에도 명령어 여러 개를 등록해두고 사용할 수 있다.<br />
보통 start 명령어에 `node [파일명]` 을 저장해두고 `npm start` 로 실행한다.<br />
start 나 test 같은 스크립트는 run 을 붙이지 않아도 실행된다.

express 패키지를 설치해보자.

```shell
> npm i express

added 56 packages, and audited 150 packages in 2s

13 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```

> **audited [숫자] packages**<br /><br />
> 패키지를 설치할 때 **audited [숫자] packages** 문장이 출력되는데 이는 패키지에 있을 수 있는 취약점을 자동으로 검사했다는 의미이다.<br /><br />
> found [발견숫자] [심각도] severity vulnerabilities<br />
> run `npm audit fix` to fix them, or `npm audit` for details<br /><br />
> `npm audit` 은 패키지의 알려진 취약점을 검사할 수 있는 명령어이다.<br />
> npm 에 패키지들이 워낙 많다보니 일부 패키지는 악성 코드를 담고 있고, 이런 것들은 npm 에 보고가 되는데 `npm audit` 을 통해 악성 코드가 담긴 패키지를 
> 설치하지는 않았는지 검사할 수 있다.<br /><br />
> `npm audit fix` 를 입력하면 npm 이 스스로 수정할 수 있는 취약점을 알아서 수정해준다.<br />
> 주기적으로 `npm audit fix` 로 수정해주는 것이 좋다.

**package-lock.json** 파일도 생성이 되는데 직접 설치한 express 외에도 node_modules 에 들어있는 패키지들의 정확한 버전과 의존 관계가 담겨있다.
npm 으로 패키지를 설치,수정,삭제할 때마다 패키지들 간의 내부 의존 관계를 이 파일에 저장한다.

**개발용 패키지**는 실제 배포 시엔 사용되지 않고 개발 중에만 사용되는 패키지를 말한다.<br />
개발용 패키지는 `npm i -D [package-name]` 으로 설치한다.

```shell
> npm i -D nodemon
```

`nodemon` 은 소스 코드가 바뀔때마다 자동으로 노드를 재실행해주는 패키지이다.

package.json
```json
"devDependencies": {
    "nodemon": "^2.0.15",
  },
```

npm 에는 **전역(global) 설치** 라는 옵션도 있다.<br />
패키지를 현재 폴더의 node_modules 에 설치하는 것이 아니라 npm 이 설치되어 있는 폴더에 설치한다.<br />
전역 설치한 패키지는 package.json 에 기록되지 않는다.<br />
전역 설치한 패키지는 콘솔의 명령어로 사용할 수 있다.

```shell
> sudo npm i -g rimraf
Password:

added 12 packages, and audited 13 packages in 665ms

2 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```

`rimraf` 는 리눅스/맥의 rm -rf 명령어를 윈도에서도 사용할 수 있게 해주는 패키지이다.

아래는 node_modules 폴더를 삭제하는 명령어이다.<br />
이 후 `npm install` 을 통해 package.json 에 기록된 패키지들을 그대로 다시 설치할 수 있다.
```shell
> rimraf node_modules
```

>**npx**<br /><br />
> 전역 설치를 하면 package.json 에 기록되지 않아서 다시 설치할 때 어려움이 따르므로 전역 설치보다는 `npx` 를 사용하는 것이 좋다.<br />
> `npm i -D rimraf` 로 개발용 패키지로 설치한 후에<br />
> `npx rimraf node_modules` 로 실행하면 패키지를 전역 설치한 것과 같은 효과를 얻을 수 있다.


---

# 3. 패키지 버전 이해

노드 패키지들의 버전은 항상 세 자리로 이루어져있다.<br />
그 이뉴는 `SemVer` 방식의 버전 넘버링을 따르기 때문이다.

`SemVer` 는 Semantic Versioning 의 약어이다. 버전을 구성하는 세 자리가 모두 의미가 있다는 뜻이다.

- `major`
    - 0 이면 초기 개발 중이라는 뜻
    - 1 부터는 정식 버전을 의미
    - major 버전은 하위 호환이 안 될 정도로 패키지들의 내용이 수정이 된 경우 올림
    - 예를 들어 1.5.0 -> 2.0.0 으로 올렸다는 것은 1.5.0 버전 패키지를 사용하던 시스템이 2.0.0 으로 업데이트했을 경우 에러가 발생할 확률이 높다는 의미
- `minor`
    - 하위 호환이 되는 기능 업데이트
    - 1.5.0 -> 1.6.0 으로 업데이트 시 아무 문제가 없어야 함
- `patch`
    - 새로운 기능이 추가되었다기 보다는 기존 기능에 문제가 있던 것을 수정한 경우
    - 1.5.0 -> 1.5.1 으로 업데이트 시 아무 문제가 없어야 함

package.json 에는 SemVer 식 세 자리 버전 외에도 `^`, `~`, `>`, `<` 같은 문자가 붙어 있다.<br />
버전에는 포함되지 않지만 설치/업데이트 시 어떤 버전을 설치해야 하는지 알 수 있도록 해주는 표시이다.

- `^`
    - minor 버전까지만 설치하거나 업데이트
    - `npm i express@^1.1.1` 은 1.1.1 이상부터 2.0.0 미만 버전까지 설치됨. 2.0.0은 설치되지 않음
    - 1.x.x 로 표현할 수도 있음
- `~`
    - patch 버전까지만 설치하거나 업데이트
    - `npm i express@~1.1.1` 은 1.1.1 이상부터 1.2.0 미만 버전까지 설치됨
    - 1.1.x 로 표현할 수도 있음
    - `~` 보다 `^` 가 많이 사용되는 이유는 minor 버전까지는 하위 호환이 보장되기 때문
- `@latest`
    - 안정된 최신 버전의 패키지 설치
    - `npm i express@latest` 혹은 `npm i express@x`
- `@next`
    - 가장 최근 배포판 설치
    - `@latest` 와 다른 점은 안정되지 않은 알파나 베타 버전의 패키지를 설치할 수 있다는 점
    - 출시 직전의 패키지에는 2.0.0-rc.0 처럼 rc(Release Candidate) 가 붙음


---

# 4. 그 외 npm 명령어

`npm outdated`<br />
업데이트할 수 있는 패키지가 있는지 확인해보는 명령어이다.

```shell
> npm outdated
Package  Current  Wanted  Latest  Location              Depended by
express    3.0.0  3.21.2  4.17.1  node_modules/express  chap05
```

Current 와 Wanted 가 다르면 업데이트가 필요한 경우이다.<br />
이 때는 `npm update [패키지명]` 으로 업데이트하면 되는데 `npm update` 로 하면 업데이트 가능한 모든 패키지가 Wanted 에 적힌 버전으로 업데이트된다.<br />
Latest 가 최신 버전이지만 package.json 에 적힌 버전 범위와 다르다면 설치되지 않는다.

---

`npm uninstall [패키지명]` 혹은 `npm rm[패키지명]`<br />
해당 패키지를 제거하는 명령어이다.<br />
node_modules  dhk  package.json 에서 제거된다.

---

`npm search [패키지명]`<br />
npm 의 패키지를 검색하는 명령어이다.<br />
윈도우나 맥에선 [npm 공홈](https://npmjs.com) 에서 검색하면 되지만 GUI 가 없는 리눅스에서는 이 명령어로 콘솔에서 검색한다.

---

`npm info [패키지명]`<br />
패키지의 세부 정보를 조회하는 명령어이다.<br />
package.json 의 내용과 의존 관계, 설치 가능한 버전 정보 등이 나온다.

---

`npm adduser`<br />
npm 로그인을 위한 명령어이다.<br />
npm 공식 사이트에 가입한 계정으로 로그인하면 된다.<br />
뒤에 다룰 내용인 패키지 배포 시 로그인이 필요하다. (패키지 배포하지 않을 것이라면 필요없음)

---

`npm whoami`<br />
로그인한 사용자가 누구인지 알리는 명령어

---

`npm logout`<br />
`npm adduser` 로 로그인한 계정을 로그아웃하는 명령어

---

`npm version [버전] 혹은 npm version major/minor/patch`<br />
package.json 의 버전을 올리는 명령어<br />
`npm version 5.3.1`, `npm version major`

---

`npm deprecate [패키지명][버전][메시지]`<br />
해당 패키지를 설치할 때 경고 메시지를 띄우는 명령어<br />
자신의 패키지에만 적용할 수 있으며, 다른 사용자들이 버그가 있는 버전의 패키지를 설치할 때 경고 메시지를 출력해줌

---

`npm publish`<br />
본인이 만든 패키지를 배포할 때 사용하는 명령어

---

`npm unpublish`<br />
배포한 패키지를 제거할 때 사용하는 명령어<br />
24시간 이내에 배포한 패키지만 제거 가능 (다른 사람이 사용하고 있는 패키지를 제거하는 경우를 막기 위함)

---

`npm ci`<br />
package.json 대신 package-lock.json 에 기반하여 패키지를 설치하는 명령어<br />
더 엄격하게 버전을 통제하여 패키지를 설치하고 싶을 때 사용


이 외 명령어는 [npm 공홈](https://docs.npmjs.com) 의 CLI Commands 에서 확인할 수 있다. 

---

# 5. 패키지 배포

본인이 만든 패키지를 배포하기 위해선 npm 계정을 먼저 만들어야 한다.

[npm 사이트](https://www.npmjs.com) 에서 가입한 후 콘솔에서 `npm adduser` 명령어로 로그인한다.

```shell
> npm adduser
npm notice Log in on https://registry.npmjs.org/
Username: assu
Password:
Email: (this IS public) xxxxx@naver.com
Logged in as  on https://registry.npmjs.org/.

> npm whoami
assu
```

패키지로 만들 코드를 작성한다. 이 때 파일명은 package.json 의 main 에 파일명과 일치해야 npm 에서 이 파일이 패키지의 진입점임을 알 수 있다.

index.js
```javascript
module.exports = () => {
  return 'hello i am assu.';
};
```

이제 `npm publish` 를 통해 패키지를 배포해보자. 만약 패키지명이 겹친다면 오류가 날 것이다<br />
굳이 같은 패키지명으로 사용하고 싶다면 네임스페이스를 쓰는 방법도 있다. ([패키지명에 네임스페이스 설정하기](https://docs.npmjs.com/cli/v8/using-npm/scope) 참고)

누군가 사용하고 있는 패키지인지 확인할 때는 `npm info [패키지명]` 으로 확인할 수 있다.<br />
만일 npm ERR! code E404 에러가 나오면 사용해도 되는 패키지명이다.

```shell
> npm publish
npm notice 
npm notice 📦  assu-npmtest-1@1.0.0
npm notice === Tarball Contents === 
npm notice 272B .eslintrc.json
npm notice 687B .prettierrc.js
npm notice 57B  index.js      
npm notice 442B package.json  
npm notice === Tarball Details === 
npm notice name:          assu-npmtest-1                          
npm notice version:       1.0.0                                   
npm notice filename:      assu-npmtest-1-1.0.0.tgz                
npm notice package size:  1.0 kB                                  
npm notice unpacked size: 1.5 kB                                  
npm notice shasum:        ae1dcad2fd8b945a1daaff59626de9c3e0ff3d01
npm notice integrity:     sha512-6BqwudCLkXlqI[...]ENFx27XHN77Zg==
npm notice total files:   4                                       
npm notice 
+ assu-npmtest-1@1.0.0

> npm info assu-npmtest-1

assu-npmtest-1@1.0.0 | ISC | deps: none | versions: 1
testtest

dist
.tarball: https://registry.npmjs.org/assu-npmtest-1/-/assu-npmtest-1-1.0.0.tgz
.shasum: ae1dcad2fd8b945a1daaff59626de9c3e0ff3d01
.integrity: sha512-6BqwudCLkXlqIE5uf7PkdtzOWRPqTKJT9uk6yALPb1HzQDImkg1MLpbAPZOnTevrVALXZ3SWTENFx27XHN77Zg==
.unpackedSize: 1.5 kB

maintainers:
- assu <juhyun1010@naver.com>

dist-tags:
latest: 1.0.0  

published just now by assu <xxxxxxx@naver.com>
```

배포된 패키지의 삭제는 `npm unpublish [패키지명] --force` 으로 삭제한다.

```shell
> npm unpublish assu-npmtest-1 --force
npm WARN using --force Recommended protections disabled.
- assu-npmtest-1
```

삭제 후 `npm info [패키지명]` 입력 시 code E404 오류가 나면 잘 삭제된 것이다.

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

# 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [npm 공홈](https://www.npmjs.com/)
* [yarn 공홈](https://yarnpkg.com/)
* [npm 명령어 설명서](https://docs.npmjs.com/cli/v8)
* [패키지 간 비교 사이트](https://npmcompare.com/)
* [패키지 다운로드 추이 확인](https://www.npmtrends.com/)
* [패키지명에 네임스페이스 설정하기](https://docs.npmjs.com/cli/v8/using-npm/scope)