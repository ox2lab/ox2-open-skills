---
name: ox2-core-tool-cache-http
description: ox2-core 기반 코드에서 Basecode\Tool의 캐시, Memcached, 캐시 프록시, HTTP 클라이언트, 폼 데이터 전송 코드를 작성하거나 수정할 때 반드시 사용한다. TCache, TMemcached, TCacheProxy, TCacheGroupManager, TApcu, THttpClient, TFormData, Basecode\Tool\Http\TClient를 다루는 작업에서는 명시 요청이 없어도 이 스킬을 적용한다.
---

# ox2-core 캐시/HTTP 도구 작업 지침

## 적용 범위

이 스킬은 `TCache`, `TMemcached`, `TCacheProxy`, `TCacheGroupManager`, `TApcu`, `THttpClient`, `TFormData`, `Basecode\Tool\Http\TClient`와 연동되는 코드를 작성하거나 수정할 때 적용한다.

## 기본 원칙

- 기존 네임스페이스 `Basecode\Tool`과 PHP 7.4 호환성을 유지한다.
- 외부 라이브러리를 새로 도입하기보다 기존 래퍼 클래스의 실제 동작에 맞춘다.
- 기존 클래스의 예시 주석을 그대로 신뢰하지 말고, 메서드 본문의 실제 호출 순서와 반환값을 확인한다.
- 에러 처리 방식이 클래스마다 다르므로 같은 패턴으로 통일하려고 크게 고치지 않는다. 호출부에서는 각 클래스의 현재 동작을 기준으로 방어 코드를 둔다.

## 캐시 선택 규칙

- 일반 캐시 저장, 조회, 삭제는 우선 `TCache`를 사용한다.
- `TCache`는 현재 추상 캐시 계층이라기보다 `TMemcached::getInstance()`를 감싼 Memcached 파사드에 가깝다. 다른 엔진으로 자동 전환된다고 가정하지 않는다.
- `TApcu`는 보조/구식 성격의 클래스다. 새 기능의 기본 캐시 저장소로 선택하지 말고, 기존 APCu 의존 코드를 유지하거나 아주 국소적인 프로세스 로컬 캐시를 다룰 때만 검토한다.
- Memcached 서버키, 세션 캐시, 통계, 다중 키, 지연 조회, 서버 목록이 필요한 코드는 `TMemcached`를 직접 사용한다.
- `TMemcached::getInstance()`는 빈 서버키를 받으면 `MEMCACHED_SERVERKEY` 상수에 의존한다. 부트스트랩 전에 호출되는 코드에서는 상수 정의 여부를 먼저 확인한다.
- `TMemcached::set()`과 `setMulti()`는 만료 시간이 `MAX_EXPIRATION`보다 크면 30일로 제한한다. 장기 보관 데이터처럼 보이는 값을 캐시에 넣지 않는다.
- `TCache::get($key, $content, $casToken)`은 성공 여부를 bool로 반환하고 실제 데이터는 참조 인자에 채운다. 반환값 자체를 캐시 데이터로 사용하지 않는다.
- 현재 `TMemcached::get()`은 콜백이 없으면 CAS 토큰 참조를 넘기지 않고 세 번째 인자에 `0`을 전달한다. CAS 갱신이 필요한 코드에서는 실제 토큰 획득 가능 여부를 검증하고 테스트한다.

## 캐시 키와 그룹 관리

- 캐시 키는 충돌을 피할 수 있게 도메인, 모델, 메서드, 핵심 파라미터를 포함해 안정적으로 만든다.
- 배열이나 객체 파라미터를 캐시 키에 반영할 때는 정렬 가능하면 정렬한 뒤 직렬화하여 같은 의미의 입력이 같은 키가 되도록 한다.
- `TCacheProxy`는 대상 객체 메서드 호출을 캐싱한다. 대상 메서드가 존재하지 않으면 `RuntimeException`이 발생하므로 호출 이름은 정적으로 추적 가능한 형태로 유지한다.
- `TCacheProxy::addCacheGroup()`은 내부에서 `getLastCacheKey()`를 호출한다. 따라서 그룹 추가는 반드시 프록시 메서드를 한 번 호출해 캐시 키가 생성된 뒤에 수행한다.
- `getLastCacheKey()`가 호출 전이면 예외를 던진다. 그룹을 먼저 등록하는 흐름을 만들지 않는다.
- `TCacheGroupManager`는 그룹 키에 캐시 키 목록을 `#`로 이어 붙여 저장한다. 키 문자열에 `#`가 들어가지 않도록 한다.
- 원본 데이터의 삭제나 강한 무효화가 필요한 수정에서는 `clearGroup()` 또는 `clearGroups()`를 호출한다. 느슨한 무효화가 가능한 조회 캐시에는 TTL을 짧게 잡는다.
- 그룹 목록 자체도 `TCache`에 저장된다. 그룹 키가 사라지면 개별 캐시 키 목록도 알 수 없으므로, 그룹 등록과 삭제 시점을 한 흐름 안에서 관리한다.

## HTTP 클라이언트 선택 규칙

- 새 HTTP 요청 코드는 가능하면 `THttpClient`를 우선 사용한다. 기존 코드가 `TFormData`에 맞춰져 있으면 작은 수정에서는 기존 클래스를 유지한다.
- HEAD 요청만 필요한 매우 단순한 확인은 `Basecode\Tool\Http\TClient::Head()`를 사용할 수 있지만, 헤더 상세 조회나 에러 처리가 필요한 작업에는 사용하지 않는다.
- JSON POST는 `THttpClient::post($jsonData)` 또는 `TFormData`의 `Content-Type: application/json` + `setCustomRequestBody()` 흐름을 사용한다.
- 파일 업로드는 `attach()`를 사용하고, multipart 여부를 직접 흉내 내지 않는다.
- 요청 인스턴스를 재사용할 때는 이전 URL, 헤더, 쿠키, 폼 데이터, 첨부 파일이 남을 수 있다. `THttpClient`는 `clear()`가 있으므로 연속 요청 전에 필요한 경우 호출한다. `TFormData`에는 동일한 전체 초기화 메서드가 없으므로 재사용보다 새 인스턴스를 선호한다.

## SSL과 보안 옵션

- `THttpClient`와 `TFormData`의 기본 cURL 옵션은 `CURLOPT_SSL_VERIFYHOST => false`, `CURLOPT_SSL_VERIFYPEER => false`다. 운영 HTTPS 통신, 외부 API, 인증 정보가 오가는 요청에서는 반드시 SSL 검증을 명시적으로 켠다.
- `THttpClient`에서는 다음처럼 설정한다.

```php
$client->option(CURLOPT_SSL_VERIFYHOST, 2);
$client->option(CURLOPT_SSL_VERIFYPEER, true);
```

- 테스트 서버나 사내 인증서 때문에 검증을 끄는 경우, 코드 주석에 이유와 제거 조건을 한국어로 남긴다.
- 리다이렉션을 따르는 기본값이 켜져 있으므로 인증 헤더나 쿠키가 다른 호스트로 전달될 가능성을 고려한다.
- 사용자 입력 URL로 서버 사이드 요청을 만들 때는 허용 호스트, 스킴, 사설망 접근 제한을 호출부에서 검증한다.

## THttpClient 작업 규칙

- `url()` 또는 `get($url)`로 URL을 명확히 지정한 뒤 요청한다. URL이 비어 있으면 예외가 발생한다.
- GET 파라미터는 `field()`에 넣으면 URL 쿼리로 붙는다. 같은 인스턴스에서 여러 GET을 호출하면 URL에 파라미터가 누적될 수 있으므로 재사용 시 `clear()`를 호출한다.
- `post($jsonData)`는 `prepare()` 뒤에 JSON 헤더를 추가하고 cURL 헤더를 다시 적용한다. 이 흐름을 바꿀 때는 JSON POST 회귀를 반드시 확인한다.
- `send()`는 HTTP 상태가 400/500이어도 cURL 에러가 아니면 응답 본문을 반환한다. 호출부에서 `$client->response['status']`를 확인한다.
- 다운로드는 `download($serverSaveFilePath, $url)`을 사용한다. 실패 시 예외가 발생하며 성공 조건은 현재 코드상 HTTP 200이다.
- 다운로드 후에는 `CURLOPT_RETURNTRANSFER`가 복구되지만 URL과 폼 데이터는 남는다. 이어지는 요청의 상태 오염을 조심한다.

## TFormData 작업 규칙

- `TFormData`는 기존 호환성 유지가 필요한 코드에서 사용한다. 새 기능에서는 `THttpClient`가 더 명확하다.
- `set()`은 폼 필드를 추가하고 `header()`는 헤더를 설정한다. JSON 요청 본문은 `setCustomRequestBody()`에 넣는다.
- `download()`의 실제 코드에는 정의되지 않은 메서드 호출이 있다. 예외 처리 경로의 `handleError()`와 다운로드 응답 처리의 `checkError()`가 클래스 안에 정의되어 있지 않다.
- 따라서 `TFormData::download()`를 새 코드의 핵심 기능으로 사용하지 않는다. 불가피하게 사용한다면 먼저 미정의 메서드 문제를 보완하거나, 호출부 테스트로 성공/실패 경로를 모두 확인한다.
- `isError()`는 `sock`이 이미 닫힌 뒤 호출하면 false를 반환할 수 있다. 요청 후 에러 판단은 `error`, `getErrorNo()`, `getErrorMessage()`, `getStatusCode()`, `response`를 함께 확인한다.
- 디버그 로그 파일 경로는 외부 입력을 그대로 쓰지 않는다. 로그 경로는 애플리케이션이 쓰기 가능한 고정 위치로 제한한다.

## 자주 발생하는 실수

- `TCache::get()`의 반환값을 캐시 데이터로 착각하고, 참조 인자에 채워지는 실제 데이터를 읽지 않는다.
- `TCacheProxy::addCacheGroup()`을 프록시 메서드 호출 전에 실행해 `getLastCacheKey()` 예외가 발생한다.
- `THttpClient` 인스턴스를 재사용하면서 이전 field, header, cookie, attach 상태를 지우지 않는다.
- 운영 외부 API 요청에서 기본 SSL 검증 비활성화 상태를 그대로 둔다.
- `TFormData::download()`의 미정의 메서드 호출 문제를 확인하지 않고 새 다운로드 기능의 핵심으로 사용한다.

## 검증 체크리스트

- 캐시 코드를 수정하면 적어도 캐시 미스, 캐시 히트, 삭제 후 재조회 흐름을 확인한다.
- 캐시 그룹 코드는 프록시 호출 후 그룹 등록, 그룹 삭제 후 개별 키 삭제를 확인한다.
- HTTP 코드는 성공 응답, 비정상 HTTP 상태, cURL 실패, SSL 검증 옵션을 분리해 확인한다.
- 파일 다운로드 코드는 실제 파일 생성 여부, HTTP 상태, 실패 시 부분 파일 처리 방식을 확인한다.
- 테스트 환경에 Memcached나 cURL 확장이 없을 수 있다. 확장 의존 테스트는 건너뛰기 조건을 두고, 순수 키 생성/옵션 설정 로직은 별도 테스트한다.
