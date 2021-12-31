---
layout: post
title:  "Node.js - 기본 개념 (3): 파일시스템"
date:   2021-11-28 10:00
categories: dev
tags: nodejs filesystem
---

이 포스트는 노드가 기본적으로 제공하는 객체와 모듈 사용법에 대해 알아본다.<br />
모듈을 사용하면서 Buffer 와 스트림, 동기와 비동기에 대해서도 알아본다.

*소스는 [assu10/nodejs.git](https://github.com/assu10/nodejs.git) 에 있습니다.*

> - 파일 시스템 접근
> - 동기 메서드와 비동기 메서드
> - Buffer 와 스트림
>   - Buffer
>   - 스트림
>   - Piping
>   - Buffer vs 스트림 메모리 사용량 비교
> - 기타 fs 메서드
>   - `fs.access`, `fs.mkdir`, `fs.open`, `fs.rename`
>   - `fs.readdir`, `fs.unlink`, `fs.rmdir`
>   - `fs.copyFile`
>   - `fs.watch`
> - 스레드풀

---

## 1. 파일 시스템 접근

readme.txt
```text
read me~
```

readFile.js
```javascript
const fs = require('fs');
fs.readFile('./readme.txt', (err, data) => {
  if (err) {
    throw err;
  }
  console.log('data: ', data);
  console.log('data.toString(): ', data.toString());
});
```

```shell
data:  <Buffer 72 65 61 64 20 6d 65 7e>
data.toString():  read me~
```

위에서 **파일 경로는 현재 파일 기준이 아니라 node 명령어를 실행하는 콘솔 기준**이다.<br />
예를 들어 C:/ 디렉터리에서  node folder/file.js 를 실행하면 C:/folder/readme.txt 가 실행되는 게 아니라 C:/readme.txt
가 실행된다.

readFile 의 결과물은 Buffer 로 제공된다.

fs 는 기본적으로 콜백 혗식의 모듈이기 때문에 실무에서 사용하기 불편하다. 따라서 fs 모듈을 프로미스 형식으로 바꿔서 사용하자.

readFilePromise.js
```javascript
const fs = require('fs').promises;

fs.readFile('./readme.txt')
  .then(data => {
    console.log('data: ', data);
    console.log('data.toString(): ', data.toString());
  })
  .catch(err => {
    console.error(err);
  });
```

```shell
data:  <Buffer 72 65 61 64 20 6d 65 7e>
data.toString():  read me~
```


이번엔 파일 생성 후 생성된 파일을 읽어보자.

writeFile.js
```javascript
const fs = require('fs').promises;

fs.writeFile('./writeme.txt', '글 입력')
  .then(() => {
    return fs.readFile('./writeme.txt');
  })
  .then(data => {
    console.log(data.toString());
  })
  .catch(err => {
    console.error(err);
  });
```

---


## 2. 동기 메서드와 비동기 메서드

노드는 대부분의 메서드를 비동기로 처리하지만 동기 방식으로도 사용이 가능한 메서드들도 있다.

async.js
```javascript
const fs = require('fs').promises;

console.log('START');

fs.readFile('./readme.txt')
  .then(data => {
    console.log('1 번: ', data.toString());
  })
  .catch(err => {
    console.error(err);
  });

fs.readFile('./readme.txt')
  .then(data => {
    console.log('2 번: ', data.toString());
  })
  .catch(err => {
    console.error(err);
  });

fs.readFile('./readme.txt')
  .then(data => {
    console.log('3 번: ', data.toString());
  })
  .catch(err => {
    console.error(err);
  });

console.log('END');
```

```shell
START
END
2 번:  read me~
3 번:  read me~
1 번:  read me~
```

비동기 메서드들은 백그라운드에 해당 파일을 읽으라고만 요청하고 다음 작업으로 넘어가기 때문에 바로 *console.log('END');* 를 실행한다.<br />
나중에 읽기가 완료되면 백그라운드가 다시 메인 스레드에 알리고, 메인 스레드를 그 때 등록된 콜백 함수를 실행한다.

이러한 방식은 매우 효율적인 방식으로 많은 수의 I/O 요청이 들어와도 메인 스레드는 백그라운드에 요청 처리를 위힘하고 그 후에 요청을 더 받을 수 있다.<br />
나중에 백그라운드가 각각의 요청 처리가 완료되었다고 알리면 그 때 콜백 함수를 처리한다.

백그라운드에서는 이 요청들을 거의 동시에 처리하는데 백그라운드에서 파일 읽기 작업을 처리하는지는 뒤에 나오는 *5. 스레드 풀* 을 참고하세요.

> **동기 vs 비동기, 블로킹 vs 논 블로킹**<br /><br />
> 동기와 비동기는 백그라운드 작업 완료 확인 여부의 차이<br />
> 블로킹과 논 블로킹은 함수가 바로 return 되는지 여부의 차이<br />
> 노드는 동기-블로킹 방식과 비동기-논 블로킹 방식이 대부분<br />
> 동기-블로킹 방식은 백그라운드 작업 완료 여부를 계속 확인하며, 호출한 함수가 바로 return 되지 않고
> 백그라운드 작업이 끝나야 return 됨.<br />
> 비동기-논 블로킹 방식은 호출한 함수가 바로 return 되어 다음 작업으로 넘어가며, 백그라운드 작업 완료 여부는
> 신경쓰지 않고 나중에 백그라운드가 알림을 줄 때 처리함.

순서대로 출력하고 싶다면 아래와 같이 동기 메서드를 사용하면 된다.

sync.js
```javascript
const fs = require('fs');

console.log('START');

let data = fs.readFileSync('./readme.txt');
console.log('1 번: ', data.toString());

data = fs.readFileSync('./readme.txt');
console.log('2 번: ', data.toString());

data = fs.readFileSync('./readme.txt');
console.log('3 번: ', data.toString());

console.log('END');
```

```shell
START
1 번:  read me~
2 번:  read me~
3 번:  read me~
END
```

하지만 이렇게 동기 메서드를 사용하면 요청이 많이 들어오는 경우 성능에 문제가 생긴다.<br />
동기 메서드는 이전 작업이 완료되어야 다음 작업을 진행할 수 있기 때문에 백그라운드가 작업하는 동안 메인 스레드가 대기하고 있어야 한다.<br />
백그라운드는 작업을 동시에 처리할 수 있는데 동기 메서드를 사용하여 백그라운드도 동시 처리가 불가하게 된다.

따라서 동기 메서드는 프로그램을 처음 실행할 때 초기화하는 용도로만 사용하는 것을 권장한다.

비동기 방식으로 하되 순서를 유지하고 싶다면 아래와 같이 하면 된다.

```javascript
const fs = require('fs').promises;

console.log('START');

fs.readFile('./readme.txt')
  .then(data => {
    console.log('1 번: ', data.toString());
    return fs.readFile('./readme.txt');
  })
  .then(data => {
    console.log('2 번: ', data.toString());
    return fs.readFile('./readme.txt');
  })
  .then(data => {
    console.log('3 번: ', data.toString());
    return fs.readFile('./readme.txt');
  })
  .catch(err => {
    console.error(err);
  });

console.log('END');
```

```shell
START
END
1 번:  read me~
2 번:  read me~
3 번:  read me~
```

---

## 3. Buffer 와 스트림

### 3.1. Buffer

영상을 로딩할 때는 버퍼링한다고 하고, 영상을 실시간으로 송출할때는 스트리밍한다고 한다.

버퍼링은 영상을 재생할 수 있을 때까지 데이터를 모으는 것이고, 스트리밍은 시청자의 컴퓨터로 영상 데이터를 조금씩 전송하는 것이다.

노드의 Buffer 와 Stream 도 비슷한 개념이다.<br />
노드는 파일을 읽을 때 메모리에 파일 크기만큼 공간을 마련하여 파일 데이터를 메모리에 저장한 뒤 사용자가 조작할 수 있도록 하는데
**이 때 메모리에 저장된 데이터**가 바로 `Buffer`이다.

buffer.js
```javascript
const buffer = Buffer.from('버퍼로 바꿔보세요');
console.log('from(): ', buffer);
console.log('length: ', buffer.length);
console.log('toString(): ', buffer.toString());

const array = [Buffer.from('하나 '), Buffer.from('둘 '), Buffer.from('셋')];
const buffer2 = Buffer.concat(array);
console.log('concat(): ', buffer2.toString());

const buffer3 = Buffer.alloc(5);
console.log('alloc(): ', buffer3);
```

```shell
from():  <Buffer eb b2 84 ed 8d bc eb a1 9c 20 eb b0 94 ea bf 94 eb b3 b4 ec 84 b8 ec 9a 94>
length:  25
toString():  버퍼로 바꿔보세요
concat():  하나 둘 셋
alloc():  <Buffer 00 00 00 00 00>
```

- `from(문자열)`
  - 문자열을 Buffer 로 변경, length 는 Buffer 의 바이트 크기
- `toString(Buffer)`
  - Buffer 를 다시 문자열로 변경, base64, hex 인수를 넣으면 해당 인코딩으로 변환 가능
- `concat(배열)`
  - 배열 안에 든 Buffer 들을 하나로 합침
- `alloc(바이트)`
  - 빈 Buffer 를 생성, 바이트를 인수로 넣으면 해당 크기의 Buffer 생성

---

### 3.2. Stream

readFile 방식의 Buffer 가 편리하기는 하지만 만약 용량이 100MB 인 파일 10개를 동시에 처리하면 1GB 의 메모리가 사용된다.<br />
또한 모든 내용을 Buffer 에 다 쓴 후에 다음 동작으로 넘어가기 때문에 파일 읽기, 압축, 파일 쓰기 등 여러 조작이 연달아 발생할 때
매번 전체 용량을 Buffer 로 처리해야 다음 단계로 넘어갈 수 있다.

그래서 Buffer 의 크기를 작게 만들어 나눠 보내는 방식이 생겼는데 그것이 바로 `Stream`이다.

파일을 읽는 Stream 메서드로 `createReadStream` 이 있다.

readme2.txt
```text
조금씩 나눠서 전달됩니다. 나눠진 조각은 chunk 라고 합니다. 하하하
```

createReadStream.js
```javascript
const fs = require('fs');

const readStream = fs.createReadStream('./readme2.txt', { highWaterMark: 16 });
const data = [];

readStream.on('data', chunk => {
  data.push(chunk);
  console.log('data: ', chunk, chunk.length);
});

readStream.on('end', () => {
  console.log('end: ', Buffer.concat(data).toString());
});

readStream.on('error', err => {
  console.error(err);
});
```

```shell
data:  <Buffer ec a1 b0 ea b8 88 ec 94 a9 20 eb 82 98 eb 88 a0> 16
data:  <Buffer ec 84 9c 20 ec a0 84 eb 8b ac eb 90 a9 eb 8b 88> 16
data:  <Buffer eb 8b a4 2e 20 eb 82 98 eb 88 a0 ec a7 84 20 ec> 16
data:  <Buffer a1 b0 ea b0 81 ec 9d 80 20 63 68 75 6e 6b 20 eb> 16
data:  <Buffer 9d bc ea b3 a0 20 ed 95 a9 eb 8b 88 eb 8b a4 2e> 16
data:  <Buffer 20 ed 95 98 ed 95 98 ed 95 98> 10
end:  조금씩 나눠서 전달됩니다. 나눠진 조각은 chunk 라고 합니다. 하하하
```

`createReadStream` 로 읽기 Stream 을 만든 후 `data`, `end`, `error` 등의 이벤트 리스너를 붙여서 사용한다.<br />
`highWaterMark` 는 바이트 단위의 Buffer 의 크기인데 기본값은 64KB 이다.<br />
파일을 읽기 시작하면 data 이벤트가 발생하고, 파일을 다 읽으면 end 이벤트가 발생한다.


이번엔 Stream 을 이용하여 파일을 써보도록 하자.

createWriteStream.js
```javascript
const fs = require('fs');

const writeStream = fs.createWriteStream('./writeme2.txt');
writeStream.on('finish', () => {
  console.log('파일 쓰기 완료');
});

writeStream.write('글을 쓰자.\n');
writeStream.write('이어서...');
writeStream.end();
```

```shell
파일 쓰기 완료
```

`createWriteStream` 로 쓰기 Stream 생성 후 `finish 이벤트 리스너`를 붙여서 파일 쓰기가 종료되면 콜백 함수가 호출되게 하였다.<br />
createWriteStream 의 `write 메서드`로 데이터를 다 쓰면 `end 메서드`로 종료를 알린다. 이 때 `finish 이벤트`가 발생한다.

---

### 3.3. Piping

Stream 끼리 연결하는 것을 **파이핑한다**고 표현하는데 아래의 예를 보도록 하자.

pipe.js
```javascript
const fs = require('fs');

const readStream = fs.createReadStream('readme.txt');
const writeStream = fs.createWriteStream('writeme3.txt');
readStream.pipe(writeStream);
```

2개의 Stream 생성 후 `pipe 메서드`로 연결하면 따로 `on('data')` 나 `writeStream.write` 를 하지 않아도 알아서 전달된다.<br />
노드 8.5 버전 이전까지는 이런 방식으로 파일을 복사하였고, 바로 뒤의 *4.3. `fs.copyFile`* 에서 새로운 방식으로 파일을 복사하는 방식에 대해 설명한다.

아래는 파일을 읽은 후 gzip 방식으로 압축하는 예시이다.

gzip.js
```javascript
const zlib = require('zlib');
const fs = require('fs');

const readStream = fs.createReadStream('./readme.txt');
const zlibStream = zlib.createGzip();
const writeStream = fs.createWriteStream('./readme.txt.gz');

readStream.pipe(zlibStream).pipe(writeStream);
```

`zlib` 의 **createGzip 메서드가 Stream 을 지원**하기 때문에 readStream 과 writeStream 사이에서 파이핑이 가능하다.

---

### 3.4. Buffer vs Stream 메모리 사용량 비교

createWriteStream 을 이용하여 약 1GB 의 파일을 생성해보자.

createBigFile.js
```javascript
const fs = require('fs');
const writeStream = fs.createWriteStream('./bigFile.txt');

for (let i = 0; i <= 10000000; i++) {
  writeStream.write(
    '엄청나게 큰 파일입니다. 엄청나게 큰 파일입니다. 엄청나게 큰 파일입니다.!\n ',
  );
}
writeStream.end();
```

이제 Buffer 를 사용하는 방식인 readFile 메서드를 사용하여 bigFile.txt 를 bigFile2.txt 로 복사해보자.

buffer-memory.js
```javascript
const fs = require('fs');

console.log('before memory: ', process.memoryUsage().rss);
console.log('before memory: ', process.memoryUsage());

const bufData = fs.readFileSync('./bigFile.txt');
fs.writeFileSync('./bigFile2.txt', bufData);

console.log('after memory: ', process.memoryUsage().rss);
```

```shell
before memory:  22237184
before memory:  {
  rss: 22986752,
  heapTotal: 4796416,
  heapUsed: 3992896,
  external: 277845,
  arrayBuffers: 11146
}
after memory:  1063510016
```

처음에 22MB 였던 메모리 용량이 1GB 가 넘은 것을 확인할 수 있다.<br />
1GB 용량의 파일을 복사하기 위해 메모리에 파일을 올려둔 후 writeFileSync 를 수행했기 때문이다.

이제 Stream 을 이용하여 파일을 복사해보자.

stream-memory.js
```javascript
const fs = require('fs');

console.log('before memory: ', process.memoryUsage().rss);

const readStream = fs.createReadStream('./bigFile.txt');
const writeStream = fs.createWriteStream('./bigFile3.txt');

readStream.pipe(writeStream);

readStream.on('end', () => {
  console.log('after memory: ', process.memoryUsage().rss);
});
```

```shell
before memory:  22228992
after memory:  47448064
```

처음에 22MB 였던 메모리 용량이 47MB 가 되었다.<br />
Buffer 를 이용할 때 1GB 까지 사용했던 것에 비하면 매우 적게 차지하는 것을 알 수 있다.

따라서 동영상처럼 큰 파일들을 전송할 때는 이러한 이유로 Stream 을 사용한다.

---

## 4. 기타 fs 메서드

### 4.1. `fs.access`, `fs.mkdir`, `fs.open`, `fs.rename`

fsCreate.js
```javascript
const fs = require('fs').promises;
const CONSTANTS = require('fs').constants;

fs.access('./folder', CONSTANTS.F_OK | CONSTANTS.W_OK | CONSTANTS.R_OK)
        .then(() => {
          console.log(
                  '111',
                  CONSTANTS.F_OK,
                  CONSTANTS.W_OK,
                  CONSTANTS.R_OK,
                  CONSTANTS.F_OK | CONSTANTS.W_OK | CONSTANTS.R_OK,
          );
          return Promise.reject('이미 폴더 있음');
        })
        .catch(err => {
          console.log(
                  '222',
                  CONSTANTS.F_OK,
                  CONSTANTS.W_OK,
                  CONSTANTS.R_OK,
                  CONSTANTS.F_OK | CONSTANTS.W_OK | CONSTANTS.R_OK,
          );
          if (err.code === 'ENOENT') {
            console.log('폴더 없음');
            return fs.mkdir('./folder');
          }
          return Promise.reject(err);
        })
        .then(() => {
          console.log('폴더 생성');
          return fs.open('./folder/file.js', 'w');
        })
        .then(fd => {
          console.log('빈 파일 생성', fd);
          return fs.rename('./folder/file.js', './folder/newfile.js');
        })
        .then(() => {
          console.log('이름 변경');
        })
        .catch(err => {
          console.error(err);
        });

```

```shell
222 0 2 4 6
폴더 없음
폴더 생성
빈 파일 생성 FileHandle {
  _events: [Object: null prototype] {},
  _eventsCount: 0,
  _maxListeners: undefined,
  close: [Function: close],
  [Symbol(kCapture)]: false,
  [Symbol(kHandle)]: FileHandle {},
  [Symbol(kFd)]: 22,
  [Symbol(kRefs)]: 1,
  [Symbol(kClosePromise)]: null
}
이름 변경


# 다시 실행 시
111 0 2 4 6
222 0 2 4 6
이미 폴더 있음
```

> 대수 데이터 타입(ADT) 의 합집합 타입 (`|`) 은 [Typescript - Generic 프로그래밍](https://assu10.github.io/dev/2021/10/01/typescript-generic-programming/) 의
> *3.1. 합집합 타입 (`|`)* 을 참고하세요.

위 fs 메서드들은 모두 비동기 메서드이므로 한 메서드의 콜백에서 다른 메서드를 호출한다.

- `fs.access(경로, 옵션, 콜백)`
  - 폴더나 파일 접근 가능 여부 체크
  - require('fs').constants 로 옵션 설정 가능
  - F_OK: 파일 존재 여부, R_OK: 읽기 권한 여부, W_OK: 쓰기 권한 여부  
  - 파일/폴더가 없을 때는 ENOENT 오류 발생
- `fs.mkdir(경로, 콜백)`
  - 폴더 생성
  - 이미 폴더가 있으면 오류가 발생하므로 access 메서드로 꼭 확인 필요
- `fs.open(경로, 옵션, 콜백)`
  - 파일의 아이디(fd) 가져오는 메서드
  - 파일이 없다면 생성한 뒤 그 아이디를 가져옴
  - 가져온 아이디로 fs.read, fs.write 를 이용하여 읽거나 쓰기 가능
  - w: 쓰기, r: 읽기, a: 추가
- `fs.rename(기존 경로, 새 경로, 콜백)`
  - 이름 변경

---

### 4.2. `fs.readdir`, `fs.unlink`, `fs.rmdir`

fsDelete.js
```javascript
const fs = require('fs').promises;

fs.readdir('./folder')
  .then(dir => {
    console.log('폴더 내용 확인', dir);
    return fs.unlink('./folder/newfile.js');
  })
  .then(() => {
    console.log('파일 삭제');
    return fs.rmdir('./folder');
  })
  .then(() => {
    console.log('폴더 삭제');
  })
  .catch(err => {
    console.error(err);
  });
```

```shell
폴더 내용 확인 [ 'newfile.js' ]
파일 삭제
폴더 삭제

# 다시 실행 시
[Error: ENOENT: no such file or directory, scandir './folder'] {
  errno: -2,
  code: 'ENOENT',
  syscall: 'scandir',
  path: './folder'
}
```

- `fs.readdir(경로, 콜백)`
  - 폴더 안의 파일, 폴더명 조회
- `fs.unlink(경로, 콜백)`
  - 파일 삭제
  - 파일이 없으면 오류가 발생하므로 먼저 파일이 있는지 확인 필요
- `fs.rmdir(경로, 콜백)`
  - 폴더 삭제
  - 폴더 안에 파일이 있으면 에러가 발생하므로 내부 파일을 모두 지우고 호출해야 함

---

### 4.3. `fs.copyFile`

*3.3. Piping* 에서 Stream 을 파이핑하여 파일을 복사하는 방법에 대해 보았었다.

pipe.js
```javascript
const fs = require('fs');

const readStream = fs.createReadStream('readme.txt');
const writeStream = fs.createWriteStream('writeme3.txt');
readStream.pipe(writeStream);
```

노드 8.5 버전 이후에는 `createReadStream` 과 `createWriteStream` 을 파이핑하지 않아도 `copyFile` 을 통하여 파일을 복사할 수 있다.

copyFile.js
```javascript
const fs = require('fs').promises;

fs.copyFile('readme.txt', 'writeme4.txt')
  .then(() => {
    console.log('파일 복사');
  })
  .catch(err => {
    console.error(err);
  });
```

---

### 4.4. `fs.watch`

`fs.watch` 는 파일/폴더의 변경 사항을 감지하는 메서드이다.

빈 텍스트 파일인 target.txt 를 만들고 아래 `watch` 메서드를 적용해보자.

watch.js
```javascript
const fs = require('fs').promises;

fs.copyFile('readme.txt', 'writeme4.txt')
  .then(() => {
    console.log('파일 복사');
  })
  .catch(err => {
    console.error(err);
  });
```

```shell
> node watch

# 내용 변경 후
change target.txt
change target.txt
# 파일명 변경 혹은 파일 삭제 후
rename target1.txt
change target1.txt
rename target1.txt
```

파일 삭제 후엔 더 이상 watch 가 수행되지 않는다.<br />
change 이벤트는 두 번씩 발생하기도 하므로 실무에서는 사용하지 말도록 하자.

---

## 5. 스레드 풀

비동기 메서드들은 백그라운드에서 실행되고, 실행된 후엔 다시 메인 스레드의 콜백 함수나 프로미스의 then 부분이 실행된다.<br />
이 때 **비동기 메서드를 여러 번 실행해도 백그라운드에서는 동시에 처리가 되는데 바로 스레드풀이 있기 때문**이다.

fs 외에도 ***내부적으로 스레드풀을 사용하는 모듈***은 `crypto`, `zlib`, `dns`, `lookup` 등이 있다.

threadpool.js
```javascript
const crypto = require('crypto');

const pass = 'password';
const salt = 'salt';
const start = Date.now();

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('1: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('2: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('3: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('4: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('5: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('6: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('7: ', Date.now() - start);
});

crypto.pbkdf2(pass, salt, 1000000, 128, 'sha512', () => {
  console.log('8: ', Date.now() - start);
});
```

```shell
1:  1154
4:  1159
2:  1159
3:  1159
5:  2309
7:  2310
6:  2310
8:  2311
```

스레드풀이 작업을 동시에 처리하므로 8개 작업 중 어느 것이 먼저 처리될 지 모른다.<br />
하지만 자세히 보면 1~4와 5~8 이 각각 2개의 그룹으로 묶여 5~8 이 시간이 더 소요되는 것을 알 수 있다.

기본적인 스레드풀의 개수(`UV_THREADPOOL_SIZE`)가 4개이기 때문에 처음 4개의 작업이 동시에 실행되고, 그 작업들이 종료되면 다음 4개의 작업들이 실행된다.<br />
만일 코어 갯수가 4개보다 작다면 다른 결과가 나올 수 있다.

윈도우는 SET UV_THREADPOOL_SIZE=1, 맥/리눅스는 `UV_THRESDPOOL_SIZE=1` 로 **스레드 갯수를 조절**할 수 있다.<br />
이 명령어는 process.env.UV_THREADPOOL_SIZE 를 설정하는 명령어이다.

스레드의 갯수를 늘릴 때는 코어 개수와 같거나 많게 두어야 뚜렷한 효과를 볼 수 있다.

---

*본 포스트는 조현영 저자의 **Node.js 교과서 2판**을 기반으로 스터디하며 정리한 내용들입니다.*

## 참고 사이트 & 함께 보면 좋은 사이트

* [Node.js 교과서 개정2판](http://www.yes24.com/Product/Goods/91860680)
* [Node.js 공홈](https://nodejs.org/ko/)
* [Node.js (v16.11.0) 공홈](https://nodejs.org/dist/latest-v16.x/docs/api/)
* [NODE_OPTIONS](https://nodejs.org/dist/latest-v16.x/docs/api/cli.html#cli_node_options_options)
* [UV_THREADPOOL_SIZE](https://nodejs.org/dist/latest-v16.x/docs/api/cli.html#cli_uv_threadpool_size_size)
* [node crypto 공식문서](https://nodejs.org/api/crypto.html)
* [crypto-js (간단한 암호화)](https://www.npmjs.com/package/crypto-js)