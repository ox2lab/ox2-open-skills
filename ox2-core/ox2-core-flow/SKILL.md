---
name: ox2-core-flow
description: ox2-core의 PHP 컨트롤러, 요청, 결과, 전역 설정, 예외 처리 코드를 작성하거나 수정할 때 사용한다. TRequest, TResult, TObject, TController, TGlobal, TException, TExceptionHandler 기반의 요청-검증-처리-출력 흐름을 다루는 작업에서는 명시 요청이 없어도 이 스킬을 우선 적용한다.
---

# ox2-core 핵심 흐름 작업 지침

## 사용 상황

ox2-core에서 PHP 엔드포인트, 컨트롤러 초기화, 요청 파라미터 검증, 결과 객체 구성, 출력 타입 선택, 예외 처리 흐름을 작성하거나 수정할 때 이 지침을 따른다. 특히 `TRequest`, `TResult`, `TObject`, `TController`, `TGlobal`, `TException`, `TExceptionHandler`를 직접 사용하거나 그 주변 코드를 바꿀 때 적용한다.

## 핵심 흐름

ox2-core의 기본 실행 흐름은 요청 객체 생성, 컨트롤러 생성, 예외 핸들러 등록, 결과 객체 작성, 검증 및 비즈니스 로직 수행, `outputAndExit()` 출력 순서다.

```php
<?php
$request = new \Basecode\Core\TRequest();
$request->attachProperty($_REQUEST);

$controller = new \Basecode\Core\TController($request);
set_exception_handler([$controller, 'TException_Handler']);

$result = new \Basecode\Core\TResult(true);
$request->validateProp(['user_id' => '사용자']);

$result->user_id($request->prop('user_id'));
$controller->outputAndExit($result);
```

출력 타입은 `TGlobal::$outputType`이 있으면 그 값을 우선 사용하고, 없으면 `TRequest::determineOutputType()`이 요청 프로퍼티 키를 보고 `js`, `m`, `json`, `x`, `e` 순서로 판정한다. 그 밖의 경우 `TGlobal::$defaultOutputType`이 사용된다.

## 실제 코드 기준 핵심 개념

`TObject`는 데이터를 두 저장소로 나눈다. `attr()`은 출력 제어, 상태 코드, 템플릿 메타데이터 같은 특성을 담고, `prop()`은 JSON/XML/템플릿 본문에 들어갈 공개 데이터와 동적 프로퍼티를 담는다. 존재하지 않는 `attr()` 또는 `prop()`을 직접 읽으면 예외가 발생하므로, 기본값이 필요한 흐름에서는 `attrDef()`와 `propDef()`를 사용한다.

`TResult`는 `TObject`를 상속하며 `code()`와 동적 메서드 호출을 제공한다. 인자 없이 `$result->message()`를 호출하면 프로퍼티 `message`를 읽고, 인자를 넣어 `$result->message('OK')`처럼 호출하면 프로퍼티를 설정한다. `new TResult(true)`는 `code` 특성을 `TGlobal::CODE_OK`로, `message` 프로퍼티를 `OK`로 초기화한다.

`TRequest`는 `attachProperty($_REQUEST)`로 요청값을 프로퍼티에 싣는 방식이 기본이다. 필수값 검증은 `validateProp()` 또는 `validateAttr()`를 쓰며, 값이 없거나 빈 문자열이면 실패한다. 숫자 `0`은 빈 값으로 취급하지 않는다.

`TController::getView()`는 `TGlobal::$outputType`에 따라 `TJsonView`, `TModuleView`, `TJsonPView`, `TTextView`, `TJsView`, `TJsonIFrameView`, `TXMLView`, 기본 `TView`를 선택한다. 직접 헤더와 본문을 출력하기보다 `outputAndExit($result, $skin)`을 통해 뷰 선택, 헤더 출력, 값 객체 연결, 종료를 한 번에 맡긴다.

`TException`은 메시지, 이동 URL, 코드값을 함께 담을 수 있다. `TExceptionHandler`는 301, 302, 303, 307 코드와 URL이 있는 `TException`을 리다이렉트로 처리하고, 그 외에는 요청 성격에 따라 JSON 또는 HTML 오류 응답을 출력한다.

## 주요 클래스와 메서드

- `TObject::attachAttribute(array $attr)`: 여러 특성을 한 번에 추가한다.
- `TObject::attachProperty(array $prop)`: 여러 프로퍼티를 한 번에 추가한다.
- `TObject::attr($name, $value)`: 특성을 설정한다.
- `TObject::attr($name)`: 특성을 읽는다. 없으면 예외가 난다.
- `TObject::prop($name, $value)`: 공개 프로퍼티나 동적 프로퍼티를 설정한다.
- `TObject::prop($name)`: 프로퍼티를 읽는다. 없으면 예외가 난다.
- `TObject::attrDef($name, $default)`, `TObject::propDef($name, $default)`: 값이 없거나 비어 있으면 기본값을 저장하고 반환한다.
- `TRequest::determineOutputType()`: 요청값과 전역 설정으로 출력 타입을 결정한다.
- `TRequest::validateProp($fields, $allowed_empty, $onFail)`: 요청 프로퍼티 필수값을 검증한다.
- `TRequest::filteringProp($names)`, `filteringAttr($names)`: 지정한 키를 제외한 배열을 반환한다.
- `TRequest::queryString($param)`: 배열을 URL 인코딩된 쿼리 문자열 조각으로 만든다.
- `TResult::code($code)`: 결과 코드 특성을 설정한다.
- `TController::TurnOnNoCache()`, `TurnOffNoCache()`: 출력 헤더의 no-cache 여부를 제어한다.
- `TController::outputAndExit(TObject &$result, $skin = '')`: 결과를 현재 출력 타입에 맞게 출력하고 종료한다.
- `TGlobal::initialize($config)`: `language`, `timezone`, `charset` 필수 설정을 확인하고 전역값을 반영한다.

## 코드 작성 규칙

엔드포인트 시작부에서는 요청값을 `TRequest`에 싣고 `TController`를 생성한 뒤 예외 핸들러를 등록한다. 기존 코드가 `TException_Handler`, `Throwable_Handler`, `Exception_Handler` 중 하나를 사용하고 있으면 같은 방식을 유지한다.

요청값은 `$_REQUEST`를 곳곳에서 직접 읽지 말고 `$request->prop('name')`으로 읽는다. 선택값은 `$request->propDef('page', 1)`처럼 기본값을 명시한다.

필수값 검증은 수동 `empty()` 분기보다 `validateProp(['id' => '아이디'])`를 우선 사용한다. 빈 값을 허용해야 하는 필드는 두 번째 인자에 `true`를 전달하거나, 검증 대상에서 제외하고 별도 규칙으로 처리한다.

결과 데이터는 응답 본문에 필요한 값만 `prop`으로 설정한다. 상태 코드, 환경값, 템플릿 메타값은 `attr`로 둔다. JSON 출력은 최종적으로 `prop()` 배열을 인코딩하므로, 클라이언트에 보여야 하는 값이 `attr`에만 있으면 누락될 수 있다.

성공 응답은 가능한 한 `new TResult(true)`로 시작하고, 실패는 `TGlobal::CODE_FAIL`, 로그인 필요는 `TGlobal::CODE_NEED_LOGIN`, 잘못된 접근은 `TGlobal::CODE_INVALID_ACCESS` 상수를 사용한다.

출력 타입은 가능한 한 `TGlobal::OUTPUTTYPE_*` 상수를 사용한다. 문자열 `'json'`, `'xml'`, `'module'`을 직접 반복하지 않는다.

출력 직전에는 `echo`, `header`, `die`를 흩어 쓰지 않는다. 뷰 계층이 헤더와 본문을 책임지도록 `$controller->outputAndExit($result, $skin)`을 사용한다.

리다이렉트성 예외가 필요할 때는 `throw new \Basecode\Core\TException('안내 메시지', '/login.php', 302);` 형태를 사용한다. 메시지가 빈 문자열이면 즉시 리다이렉트, 메시지가 있으면 alert 후 이동한다.

## 자주 발생하는 실수

`attr('code')`를 바로 읽으면 값이 없을 때 예외가 발생한다. 코드값이 항상 필요한 결과는 `new TResult(true)`로 만들거나 먼저 `$result->code(...)`를 설정한다.

JSON에 포함되어야 할 값을 `attr()`에 넣으면 빠질 수 있다. JSON과 module 출력은 `prop()` 중심으로 직렬화된다.

`validateProp()`의 라벨 배열을 반대로 작성하지 않는다. `['user_id' => '사용자']`처럼 키는 실제 필드명, 값은 사용자에게 보여줄 라벨이다.

`TRequest::queryString()`은 끝에 `&`를 남긴다. 완전한 URL을 만들 때는 필요한 경우 호출부에서 마무리 처리를 확인한다.

`TGlobal::initialize()`에는 최소 `language`, `timezone`, `charset`가 필요하다. 누락되면 `InvalidArgumentException`이 발생한다.

`TExceptionHandler`는 내부에서 `\TSiteConfig::getInstance()->prop('DEBUG')`를 참조한다. 해당 설정 객체가 준비되지 않은 환경에서는 생성자에 디버그 여부를 명시하거나 기존 초기화 순서를 따른다.

## 검증 체크리스트

- 요청값은 `TRequest`에 `attachProperty()` 또는 필요한 `attachAttribute()`로 실렸는가?
- 필수 파라미터는 `validateProp()` 또는 `validateAttr()`로 검증했는가?
- 선택 파라미터와 템플릿용 값은 `propDef()` 또는 `attrDef()`로 안전하게 기본값을 처리했는가?
- 응답 본문 데이터는 `prop`, 메타/상태성 데이터는 `attr`에 배치했는가?
- 출력 타입은 `TGlobal::OUTPUTTYPE_*` 상수 또는 요청 키 판정 규칙과 충돌하지 않는가?
- 직접 출력과 `outputAndExit()`가 섞여 헤더 전송 문제가 생기지 않는가?
- 예외 코드와 URL이 리다이렉트 의도에 맞는가?
- JSON, HTML, XML, module 출력에서 같은 결과 객체가 의도한 형태로 보이는가?

## 짧은 예시

```php
<?php
\Basecode\Core\TGlobal::$outputType = \Basecode\Core\TGlobal::OUTPUTTYPE_JSON;

$request = new \Basecode\Core\TRequest();
$request->attachProperty($_REQUEST);

$controller = new \Basecode\Core\TController($request);
set_exception_handler([$controller, 'TException_Handler']);

$result = new \Basecode\Core\TResult(true);

try
{
	$request->validateProp(['keyword' => '검색어']);

	$page = (int)$request->propDef('page', 1);
	$keyword = trim($request->prop('keyword'));

	if ($page < 1)
	{
		throw new \Basecode\Core\TException('페이지 번호가 올바르지 않습니다.', '', \Basecode\Core\TGlobal::CODE_INVALID_ACCESS);
	}

	$result->keyword($keyword);
	$result->page($page);
	$result->items([]);
}
catch (\Basecode\Core\TException $e)
{
	throw $e;
}

$controller->outputAndExit($result);
```
