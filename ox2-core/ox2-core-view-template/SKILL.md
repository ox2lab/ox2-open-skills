---
name: ox2-core-view-template
description: ox2-core의 View 클래스, 스킨 경로, HTML/JS/TXT/XML/JSON 템플릿, TSimpleTemplate 문법을 작성하거나 수정할 때 사용한다. TView, TJsonView, TXMLView, TSkinPath, TSimpleTemplate 기반 화면 또는 응답 템플릿 작업에서는 명시 요청이 없어도 이 스킬을 적용한다.
---

# ox2-core 화면 템플릿 작업 지침

## 사용 상황

ox2-core에서 HTML 스킨, JSON 스킨, JS 스킨, TXT 스킨, XML 스킨, View 클래스, 템플릿 변수, include, LOOP/IF 구문을 작성하거나 수정할 때 이 지침을 따른다. `Basecode\View` 하위 클래스와 `TSkinPath`, `TSimpleTemplate`를 사용하는 화면 작업에 적용한다.

## 출력과 스킨 선택 흐름

컨트롤러는 `TController::getView()`에서 `TGlobal::$outputType`에 따라 View 객체를 고른다. HTML은 `TView`, JSON은 `TJsonView`, XML은 `TXMLView`, JS는 `TJsView`, module은 `TModuleView`, text는 `TTextView`, JSONP는 `TJsonPView`, jsoniframe은 `TJsonIFrameView`가 담당한다.

스킨 경로를 전달하지 않으면 각 View가 `TSkinPath::getAutoSkinPath()`로 현재 PHP 파일명에 맞는 스킨을 찾는다. 확장자는 View마다 다르다.

- `TView`: `.html`
- `TJsonView`: `.json`
- `TXMLView`: `.xml`
- `TJsView`: `.js`
- `TTextView`: `.txt`

스킨 경로를 직접 넘기면 `TSkinPath::getFileSystemSkinPath($skinPath)`가 `/skin/...` 또는 현재 스킨 기준 상대 경로를 파일 시스템 경로로 바꾼다. `PARENT_SKIN_ROOT`가 정의되어 있고 파일이 있으면 부모 스킨을 우선한다.

## 실제 코드 기준 핵심 개념

`TAbstractView`는 공통 헤더를 출력한다. 기본 헤더, no-cache 헤더, 보안 헤더를 처리하고 `Content-Type`은 각 View의 `getContentType()`이 정한다. View 작업에서 직접 `header()`를 추가해야 한다면 기존 헤더 정책과 충돌하지 않는지 먼저 확인한다.

`TView::getContent()`는 `SKIN_UPDATE_DATE`, `ENVIRONMENT`, `PRODUCTION`, `LIVE_SYSTEM`을 결과 객체의 특성으로 보강한 뒤 HTML 템플릿을 처리한다. 템플릿에서 이 값들은 `{{@SKIN_UPDATE_DATE}}`처럼 특성 변수로 읽는다.

`TJsonView::getContent()`는 같은 이름의 `.json` 스킨이 있으면 템플릿을 출력하고, 없으면 결과 객체의 `prop()` 배열을 JSON으로 인코딩한다. JSON 응답에 들어갈 데이터는 반드시 결과 객체의 프로퍼티에 둔다.

`TModuleView::getContent()`는 템플릿을 찾지 않고 `export default ...` 형식으로 결과 객체의 `prop()` 데이터를 내보낸다.

`TXMLView::getContent()`는 `.xml` 스킨이 있으면 템플릿을 사용하고, 없으면 `TObject`의 `attr()`과 `prop()` 구조를 XML로 변환한다. XML 헤더 출력 시 UTF-8 BOM을 함께 출력한다.

`TSimpleTemplate`는 `setTemplateFile()`, `setValueObject()`, `dispatch()`, `getContents()` 순서로 사용된다. 템플릿은 include 처리, LOOP/IF 처리, 전역 변수 치환 순서로 해석된다.

## 템플릿 문법

`FRAMEWORK_VERSION`이 정의되어 있고 3 이상이면 이중 중괄호 문법을 사용한다. 정의되어 있지 않거나 3 미만이면 구버전 단일 중괄호 문법이 사용된다. 새 템플릿은 프로젝트 기준 버전을 확인하고 한 파일 안에서 문법을 섞지 않는다.

```html
<!-- FRAMEWORK_VERSION >= 3 -->
{{@title}}
{{user_name}}
{{user:profile.name}}
{{items::name}}

<!-- FRAMEWORK_VERSION < 3 -->
{@title}
{user_name}
{user:profile.name}
{items::name}
```

변수 접두사의 의미는 다음과 같다.

- `@name`: `TObject::attrDef('name', '')`로 읽는 특성 값
- `name`: `TObject::propDef('name', '')`로 읽는 프로퍼티 값
- `name:key`: 프로퍼티로 읽은 배열에서 `key` 값을 읽는 경로
- `items::name`: LOOP 내부의 현재 배열 원소에서 읽는 값

현재 `TSimpleTemplate`의 전역 변수 치환 정규식은 선행 접두사로 `@`만 허용한다. 접두사가 없으면 프로퍼티로 읽는다. 보조 문서에 `{{.name}}`, `{{:items}}` 형태가 보이더라도 실제 코드 기준 새 템플릿에서는 `{{name}}`, `{{name:key}}`처럼 작성한다. 하위 경로는 `@`, `.`, `:`를 이어 쓸 수 있지만, 실제 데이터 타입이 `TObject`인지 배열인지에 맞아야 한다. 타입이 맞지 않으면 빈 문자열로 출력된다.

## LOOP와 IF 작성 규칙

반복은 숫자 인덱스를 가진 배열을 대상으로 한다. `dispatch_loop_syntax()`는 루프 대상 배열에서 숫자 인덱스가 아닌 키를 건너뛴다.

```html
<!--:LOOP items :-->
	<li>
		<span>{{items::name}}</span>
		<span>{{items::price}}</span>
	</li>
<!--:/LOOP items :-->
```

조건문은 값이 비어 있지 않을 때 출력된다. 숫자 `0`과 문자열 `'0'`은 유효한 값으로 처리된다. 부정 조건은 `NOT`을 사용한다.

```html
<!--:IF is_empty :-->
	<p>{{empty_message}}</p>
<!--:/IF is_empty :-->

<!--:IF NOT items :-->
	<p>표시할 항목이 없습니다.</p>
<!--:/IF items :-->
```

include는 스킨 기준 가상 경로를 사용한다. 파일 경로 조립은 `TSkinPath`가 처리하므로 템플릿 안에서 서버 절대 경로를 쓰지 않는다.

```html
<!--#include virtual="include/head.tpl.html"-->
```

## HTML 스킨 작성 규칙

페이지 구조는 시맨틱 태그를 우선 사용한다. 불필요한 wrapper를 늘리지 말고 `header`, `nav`, `main`, `section`, `article`, `footer`의 의미가 맞을 때 사용한다.

```html
<!DOCTYPE html>
<html lang="ko" data-skin-update-date="{{@SKIN_UPDATE_DATE}}" data-crc32="{{@crc32}}">
<head>
	<!--#include virtual="include/head.tpl.html"-->
	<title>{{@title}}</title>
	<link href="/skin/ko/assets/css/page.css" rel="stylesheet">
</head>
<body>
	<header>
		<!--#include virtual="include/header.tpl.html"-->
	</header>
	<main class="contents">
		<h1>{{page_title}}</h1>
	</main>
	<footer>
		<!--#include virtual="include/footer.tpl.html"-->
	</footer>
</body>
</html>
```

아이콘은 단순 이미지 태그를 반복하기보다 CSS background, mask, 인라인 SVG 데이터, CSS 변수로 재사용한다. 버튼 아이콘에는 접근 가능한 이름을 `aria-label`로 제공한다.

장식용 구분선, 접두사, 접미사, 툴팁은 가능한 한 별도 빈 요소를 추가하지 말고 `data-*`, 사용자 정의 속성, `::before`, `::after`를 활용한다.

이미지는 의미 있는 콘텐츠이면 `img`와 정확한 `alt`를 사용하고, 장식 또는 썸네일 배경이면 CSS `background-image`로 처리한다.

## 코드 작성 규칙

새 View 클래스를 만들기 전에 기존 `TAbstractView` 하위 클래스가 해결하는 출력 타입인지 확인한다. 새 클래스가 필요하다면 `getContentType()`과 `getContent($skinPath = '')`를 구현하고, 값 객체는 `attachValueObject()`로 주입된 `$this->result`를 사용한다.

스킨 파일을 읽을 때는 직접 `DOCUMENT_ROOT`를 조합하지 말고 `TSkinPath::getFileSystemSkinPath()` 또는 View의 `$skinPath` 인자를 통해 처리한다.

템플릿 출력에 사용할 값은 컨트롤러에서 `TResult`의 `prop()` 또는 동적 메서드로 설정한다. 템플릿 메타값은 `attr()`에 둔다. 예를 들어 제목은 템플릿 정책에 따라 `attr('title')` 또는 `prop('page_title')` 중 하나로 일관되게 배치한다.

JSON 스킨이 없을 때의 자동 JSON 출력은 `prop()`만 사용한다. `attr()`에만 넣은 값은 템플릿 스킨에서는 보일 수 있지만 자동 JSON에는 빠질 수 있다.

`TSimpleTemplate` 예시를 작성할 때 존재하지 않는 `load()`, `assign()`, `display()` 같은 API를 사용하지 않는다. 실제 사용 가능한 메서드는 `setContents()`, `setTemplateFile()`, `setValueObject()`, `dispatch()`, `getContents()`다.

템플릿 조건으로 배열이나 객체를 다룰 때는 해당 값이 `TObject`인지 배열인지 확인한다. 선행 `@`는 루트 값 객체의 특성을 읽고, 접두사 없는 이름은 루트 값 객체의 프로퍼티를 읽는다. 하위 경로의 `@`와 `.`는 `TObject`에서만 의미가 있고, `:`와 `::`는 배열에서만 의미가 있다.

## 자주 발생하는 실수

`FRAMEWORK_VERSION >= 3` 프로젝트에서 `{@name}`와 `{{@name}}`를 한 파일에 섞으면 유지보수가 어려워진다. 한 템플릿은 한 문법으로 통일한다.

루프 데이터가 연관 배열이면 출력되지 않을 수 있다. `items`는 `[['name' => 'A'], ['name' => 'B']]`처럼 숫자 인덱스 배열로 전달한다.

`{{items::name}}`는 `<!--:LOOP items :-->` 내부에서 현재 원소를 읽는 문법이다. 루프 밖에서 같은 표현을 기대하지 않는다.

`{{@name}}`은 특성, `{{name}}`은 프로퍼티다. 컨트롤러에서 `$result->name('홍길동')`으로 넣은 값은 `{{name}}`으로 읽는다.

JSON 템플릿 파일이 존재하면 `TJsonView`는 자동 인코딩 대신 템플릿 결과를 그대로 반환한다. JSON 문법 오류가 생기지 않도록 쉼표, 따옴표, 배열 루프 위치를 직접 검증한다.

`TXMLView::set_RootNode()`는 타입힌트가 `\XMLDocument`로 되어 있지만, 일반적인 PHP 표준 XML 객체와 다를 수 있다. 기존 호출부가 없다면 새 코드에서 무리하게 사용하지 않는다.

## 검증 체크리스트

- 출력 타입과 기대 확장자 `.html`, `.json`, `.xml`, `.js`, `.txt`가 맞는가?
- 스킨 경로가 `TSkinPath` 규칙으로 해석 가능한 가상 경로인가?
- 템플릿 변수의 선행 `@`, 접두사 없는 프로퍼티 이름, 하위 경로의 `.`, `:`, `::`가 실제 데이터 저장 위치와 타입에 맞는가?
- `FRAMEWORK_VERSION` 기준 문법을 한 파일 안에서 일관되게 사용했는가?
- LOOP 대상은 숫자 인덱스 배열인가?
- IF 조건에서 빈 값, 숫자 0, 문자열 `'0'` 처리가 의도와 맞는가?
- JSON 스킨은 유효한 JSON 문자열을 생성하는가?
- HTML은 시맨틱 구조, 접근성 이름, 이미지 `alt`, 불필요한 wrapper 제거 기준을 충족하는가?
- View 수정 시 `Content-Type`, no-cache, 보안 헤더 기본 정책을 깨지 않았는가?

## 짧은 예시

컨트롤러에서 템플릿 데이터를 준비한다.

```php
<?php
$result = new \Basecode\Core\TResult(true);
$result->attr('title', '상품 목록');
$result->page_title('상품 목록');
$result->items([
	['name' => '노트', 'price' => '3000'],
	['name' => '펜', 'price' => '1200'],
]);

$controller->outputAndExit($result, 'product/list.html');
```

HTML 스킨에서 같은 데이터를 읽는다.

```html
<main class="contents">
	<h1>{{page_title}}</h1>

	<ul class="product-list">
	<!--:LOOP items :-->
		<li class="product-item">
			<span class="name">{{items::name}}</span>
			<span class="price" data-unit="원">{{items::price}}</span>
		</li>
	<!--:/LOOP items :-->
	</ul>

	<!--:IF NOT items :-->
		<p class="empty">상품이 없습니다.</p>
	<!--:/IF items :-->
</main>
```
