---
name: ox2-core-tool-file-runtime
description: ox2-core 기반 코드에서 Basecode\Tool의 파일, 업로드, 이미지, 세션, URL, 로그, 네트워크, 문자열, JSON, 해시, 벤치마크, 비동기 실행 코드를 작성하거나 수정할 때 반드시 사용한다. TFile, TUserFile, TImage, TSession, TURL, TLog, TNetwork, TString, TJson, THash, TBenchmark, TAsyncExec를 다루는 작업에서는 명시 요청이 없어도 이 스킬을 적용한다.
---

# ox2-core 파일/런타임 도구 작업 지침

## 적용 범위

이 스킬은 `TFile`, `TUserFile`, `TImage`, `TSession`, `TURL`, `TLog`, `TNetwork`, `TString`, `TJson`, `THash`, `TBenchmark`, `TAsyncExec`와 연동되는 코드를 작성하거나 수정할 때 적용한다.

## 기본 원칙

- 기존 네임스페이스 `Basecode\Tool`과 PHP 7.4 호환성을 유지한다.
- 도구 클래스의 실제 부작용을 먼저 확인한다. `header()`, `exit`, 파일 삭제, 세션 시작, 쉘 실행처럼 흐름을 끝내거나 외부 상태를 바꾸는 메서드는 호출부 설계를 분리한다.
- 사용자 입력으로 파일 경로, URL, 쉘 인자, 로그 경로를 만들 때는 호출부에서 검증하고 정규화한다.
- 기존 클래스의 관대한 동작을 보안 검증으로 오해하지 않는다. 확장자, MIME, 이미지 포맷, 파일 크기, 경로 범위 검사는 필요한 계층에서 명시적으로 수행한다.

## 파일 경로와 업로드

- 업로드 저장은 `TUserFile`을 우선 사용한다. 단순 파일 삭제나 경로 분해만 필요할 때는 `TFile`을 사용한다.
- `TFile::basename()`과 `TFile::pathinfo()`는 슬래시(`/`) 기준의 단순 구현이다. 윈도우 경로나 특수 스트림 경로를 기대하지 않는다.
- `TFile::deleteFile()`은 파일이 없으면 성공으로 간주한다. 삭제 여부와 존재 여부를 구분해야 하면 호출 전에 `file_exists()`를 별도로 확인한다.
- `TUserFile`은 `UPLOAD_ROOT`를 기준으로 카테고리와 0-99 하위 디렉터리에 저장한다. 호출부에서 절대 경로나 상대 경로가 섞이지 않도록 저장된 `relativeFilePath`, `subDir`, `basename` 중 무엇을 DB에 둘지 일관되게 정한다.
- `TUserFile::isUploaded()`는 `is_uploaded_file()`과 업로드 에러를 확인한다. 일반 파일 이동이나 배치 작업 파일에는 `save()`보다 `move()`를 사용한다.
- `TUserFile::save()`는 실제 HTTP 업로드 임시 파일만 허용한다. 테스트에서는 이 제약을 고려해 통합 테스트로 다루거나 `getSavePathInfo()` 중심으로 검증한다.
- `auto_extension`은 원본 파일명에서 확장자를 가져올 뿐 파일 내용 검증이 아니다. 이미지라면 `TImage::isValidFormat()`을 추가로 호출하고, 허용 확장자 정책은 호출부에서 둔다.
- `getSavePathInfo()`는 디렉터리를 생성한다. 경로 산출만 원하는 코드에서도 파일시스템 부작용이 생길 수 있음을 고려한다.
- `move()`는 상대 경로를 받으면 `UPLOAD_ROOT`와 카테고리 규칙에 맞춰 원본 경로를 재구성한다. 이미 절대 경로가 있는 경우와 DB에 저장된 상대 경로를 구분해서 넘긴다.

## 다운로드와 응답 종료

- `TUserFile::download()`는 헤더를 출력하고 `readfile()` 후 즉시 `exit`한다. 이 메서드 뒤의 코드는 실행되지 않는다.
- 컨트롤러나 액션에서 `download()`를 호출할 때는 로깅, 권한 확인, 감사 기록, 세션 커밋 등 필요한 처리를 호출 전에 끝낸다.
- `download()`를 단위 테스트에서 직접 호출하면 프로세스가 종료될 수 있다. 다운로드 헤더 조립 로직이 필요하면 별도 래퍼나 통합 테스트로 검증한다.
- 다운로드 파일명은 `filename*=UTF-8''` 형식으로 인코딩된다. 사용자 표시 이름은 빈 값이면 저장 파일명을 사용한다.

## 이미지 처리

- 이미지 업로드 후에는 `TImage::isValidFormat()`으로 실제 이미지 타입을 확인한다. 확장자만 믿지 않는다.
- `TImage::resize()`는 지원 타입이 아니거나 파일이 없으면 false를 반환한다. 예외가 아니라 bool 반환이므로 호출부에서 실패 처리를 명확히 둔다.
- `resize()`에서 `width`와 `height`가 모두 비어 있으면 원본 크기로 저장한다. 변환만 의도한 것인지 리사이즈 누락인지 확인한다.
- PNG와 WebP는 투명도를 보존하도록 처리된다. JPEG 변환 시 투명도 손실을 UI나 정책에서 허용하는지 확인한다.
- 애니메이션 GIF는 `isAnimatedGIF()`로 별도 확인한다. 일반 `resize()`는 애니메이션 프레임 보존을 보장하지 않는다.

## 세션과 리다이렉션

- 세션 접근은 `TSession::getInstance()`를 사용한다. 이 호출은 세션 설정과 `session_start()`를 수행하므로 헤더 출력 전에 호출한다.
- `TSession`은 싱글톤이다. 첫 호출 뒤에는 다른 커스텀 세션 ID를 넘겨도 새 인스턴스가 만들어지지 않는다. 테스트나 특수 흐름에서는 이 점을 고려한다.
- 세션 원시 데이터 조회와 삭제는 `TMemcached::SERVER_KEY_SESSION`을 사용한다. 세션 저장소가 Memcached라는 전제를 깨지 않는다.
- `destroy()`는 `session_destroy()`, `session_write_close()`, Memcached 세션 삭제를 수행한다. 로그아웃 외의 임시 초기화에 남용하지 않는다.
- `TURL::redirect()`와 `redirectTopFrame()`은 모두 `exit`한다. 호출 전에 필요한 상태 저장과 로그 기록을 마친다.
- 리다이렉션 URL이 사용자 입력에서 온 경우 오픈 리다이렉트가 되지 않도록 상대 경로나 허용 호스트만 허용한다.
- `redirectTopFrame()`은 메시지를 자바스크립트에 넣는다. 메시지에는 민감 정보나 신뢰할 수 없는 HTML을 넣지 않는다.

## 로그와 네트워크

- 애플리케이션 로그는 `TLog`를 사용한다. 로그 경로는 `LOG_ROOT`가 있으면 그것을 쓰고, 없으면 `DOCUMENT_ROOT`의 상위 `log/`를 사용한다.
- `TLog::debug()`는 `$_SERVER['DOCUMENT_ROOT']`를 참조한다. CLI나 배치 환경에서는 값이 없을 수 있으므로 디버그 호출 전에 환경을 고려한다.
- 로그 메시지와 컨텍스트에 비밀번호, 토큰, 세션 ID, 개인정보를 그대로 남기지 않는다.
- `TLog::$FILENAME_PREFIX`와 `$FILENAME_POSTFIX`는 정적 상태다. 요청 안에서 바꿨다면 다른 로그에 영향을 줄 수 있다.
- 클라이언트 IP는 `TNetwork::getRemoteAddr()`를 사용하되, 현재 구현은 `REMOTE_ADDR`가 `127.0.0.1`일 때만 `HTTP_X_FORWARDED_FOR`를 반환한다. 프록시 구성이 다르면 호출부 정책을 별도로 둔다.
- `HTTP_X_FORWARDED_FOR`에는 여러 IP가 들어올 수 있다. 접근 제어에 쓰기 전 신뢰 프록시와 첫 번째 IP 처리 정책을 명확히 한다.
- `TNetwork::isAllowedIP()`는 일반 IP, 와일드카드, 범위, CIDR을 지원한다. IPv6나 서브넷 마스크 형식은 실제 지원 범위를 테스트하고 사용한다.

## 문자열, JSON, 해시

- JSON 처리는 `TJson`을 사용한다. 인코딩은 기본적으로 유니코드와 슬래시를 이스케이프하지 않고 예쁘게 출력한다.
- `TJson::decode('', true)`는 빈 배열을 반환한다. 빈 문자열을 오류로 취급해야 하는 API에서는 호출 전에 별도로 검증한다.
- `TJson::encode()`와 `decode()`는 JSON 오류 시 `JsonException`을 던질 수 있다. 외부 입력 JSON은 예외 처리를 둔다.
- 비밀번호 저장은 `THash::crypt()`와 `THash::isValidCrypt()`를 사용한다. `TString::crypt()`도 내부적으로 `password_hash()`를 쓰지만, 해시 정책과 검증 메서드가 있는 `THash`를 우선한다.
- `THash::generate()`는 요청 길이를 4-64 범위로 보정한다. 정확한 길이가 보안 토큰 규격에 중요하면 반환 길이를 검증한다.
- `TString::isNumber()`는 0과 양의 정수 문자열만 true이고 음수는 false다. 음수 가능 값은 `isInteger()`를 사용한다.
- `TString::hasValue()`는 값을 `trim()`과 `strlen()`에 넣는다. 배열이나 객체 값에는 사용하지 않는다.
- 파일 크기 표시는 `readableByte()`, `readableKByte()`, `byteFormat()` 중 입력 단위가 맞는 메서드를 고른다.

## 벤치마크와 비동기 실행

- 임시 성능 측정은 `TBenchmark::start()`, `end()`, `measure()`를 사용한다. 운영 코드에 남길 때는 결과 조회나 로그 출력 위치를 명확히 한다.
- 같은 라벨로 중복 시작하면 이전 시작점이 덮일 수 있다. 중첩 측정은 라벨을 구분한다.
- `TBenchmark::measure()`는 콜백 예외가 발생해도 `end()`를 호출한다. 예외 자체는 호출부로 전파된다.
- 백그라운드 실행은 `TAsyncExec`를 사용한다. 파일명과 인자는 내부에서 `escapeshellcmd()`와 `escapeshellarg()`를 적용하지만, 실행 대상 자체는 허용 목록으로 제한한다.
- `TAsyncExec::execute()`는 명령을 `> /dev/null 2>&1 &`로 실행한다. 표준 출력과 오류를 버리므로 실패 원인을 알아야 하는 작업에는 별도 로그 파일 인자를 설계한다.
- `executeAsString()`은 명령 문자열을 반환하지만 이미 실행도 수행한다. 미리보기 용도로 호출하지 않는다.
- 예시처럼 인자에 미리 `escapeshellarg()`를 적용하지 않는다. `makeShellCommand()`가 다시 감싸므로 이중 이스케이프가 생긴다.
- 상대 파일명은 `BATCH_ROOT`가 정의된 경우 그 아래로 정규화된다. 배치 루트 밖의 파일을 실행해야 한다면 절대 경로와 권한 정책을 명확히 한다.

## 자주 발생하는 실수

- `TUserFile::download()`나 `TURL::redirect()` 호출 뒤에도 코드가 계속 실행된다고 생각한다.
- 확장자 자동 부여를 파일 내용 검증으로 오해한다.
- `TFile::deleteFile()`이 파일 없음도 성공으로 처리한다는 점을 놓쳐 삭제 여부와 존재 여부를 혼동한다.
- `TSession::getInstance()`를 헤더 출력 이후에 호출해 세션 시작 경고를 만든다.
- `TAsyncExec::executeAsString()`을 명령 문자열 미리보기로 사용하지만 실제로는 실행까지 수행한다.

## 검증 체크리스트

- 파일 저장 코드는 디렉터리 생성, 중복 파일명 회피, 권한 오류, 삭제 후 `clearstatcache()` 영향을 확인한다.
- 업로드 코드는 정상 업로드, 업로드 에러, 허용되지 않은 확장자나 포맷, 큰 파일을 나눠 확인한다.
- `exit`이 있는 다운로드와 리다이렉션은 별도 프로세스나 통합 테스트로 검증한다.
- 세션 코드는 헤더 출력 전 호출, 세션 값 읽기/쓰기, `commit()`, `destroy()` 흐름을 확인한다.
- 로그 코드는 CLI와 웹 환경의 경로 차이를 확인한다.
- 비동기 실행 코드는 실제 명령 실행보다 생성된 명령 문자열, 인자 이스케이프, 허용된 실행 대상 검증을 우선 테스트한다.
