---
name: ox2-core-db-model-list
description: ox2-core의 TModel, TList, TVirtualModel, TVirtualList, TPaging 기반 모델과 목록 조회 코드를 작성하거나 수정할 때 사용한다. CRUD 모델, 검색 리스트, 페이징, 동적 테이블 접근, TModel/TList 매직 메서드 사용이 나오면 반드시 이 스킬을 적용한다.
---

# ox2-core DB 모델/리스트 작업 지침

## 적용 범위

`TModel`, `TList`, `TVirtualModel`, `TVirtualList`, `TPaging`을 사용하는 모델, 리스트, 검색, CRUD, 페이징 코드를 작성할 때 이 지침을 따른다. SQL 빌더의 세부 동작은 `ox2-core-db-sql-runtime` 지침과 함께 확인한다.

## 모델 클래스 작성

- 단일 레코드 CRUD는 `TModel`을 상속한다. 목록 검색과 페이징은 `TList`를 상속한다. 같은 클래스에 단건 변경과 목록 검색 책임을 섞지 않는다.
- 테이블명은 클래스 상수 또는 보호 프로퍼티 흐름에 맞춘다. 생성자는 `static::TABLE_NAME`, `static::SEQUENCE_NAME`이 정의되어 있으면 내부 `TABLE_NAME`, `SEQUENCE_NAME`에 반영하고 `TSqlBuilder`의 `tableName()`을 설정한다.
- `whereFieldNames`에는 조회, 수정, 삭제 조건으로 사용할 안전한 키만 넣는다. 요청의 모든 필드를 조건으로 쓰지 않는다.
- `noInsertFieldNames`, `noUpdateFieldNames`, `noReplaceFieldNames`는 DB가 관리하는 컬럼, 기본키, 생성일시처럼 외부 요청으로 바꾸면 안 되는 필드를 제외하는 데 사용한다.
- 작업을 시작하기 전에 `init()`으로 모델 속성과 SQL 빌더 상태를 초기화한다. 같은 인스턴스를 재사용하면서 이전 where나 field가 남아 있는 상태로 CRUD를 호출하지 않는다.

## TModel CRUD 규칙

- `add()`는 빌더에 field가 없으면 `false`를 반환한다. insert 전에는 `preInsert()` 또는 명시적 `field()` 호출로 저장할 필드를 구성한다.
- `find()`는 where가 비어 있으면 `limit(0, 1)`을 설정하고 조회한다. 이 동작은 임의의 첫 레코드를 읽을 수 있으므로, 실제 서비스 코드에서는 `preLoad()`나 명시적 `where()`로 식별 조건을 먼저 둔다.
- `modify()`는 field가 없거나 where가 비어 있으면 `false`를 반환한다. 수정 요청에서는 `preUpdate()`로 조건 필드와 수정 필드를 분리한다.
- `replace()`는 DB의 `REPLACE INTO` 의미를 따른다. 기존 행 삭제 후 삽입처럼 동작할 수 있으므로, 단순 update 대체재로 쓰지 않는다.
- `remove()`는 where가 비어 있으면 `0`을 반환하여 전체 삭제를 막는다. 반면 `TSqlExecutor::delete()`는 이런 안전장치 없이 `DELETE FROM table` 형태를 만들 수 있다. 모델 레벨 삭제는 `remove()`를 우선 사용하고, executor 직접 삭제는 where를 별도로 검증한다.

## preLoad, preInsert, preUpdate 사용

- `preLoad($request)`는 `whereFieldNames`에 포함된 요청 프로퍼티만 where로 변환하고 `limit(0, 1)`을 설정한다. 단건 조회와 삭제 전 조건 구성에 사용한다.
- `preInsert($request)`는 `TTable::getFieldNames()`로 실제 테이블 필드를 확인한 뒤 insert 제외 필드를 건너뛰고 field를 채운다.
- `preUpdate($request)`는 `whereFieldNames`는 where로, `noUpdateFieldNames`는 제외로, 나머지 실제 테이블 필드는 field로 보낸다.
- `TTable`은 `information_schema`에 의존하므로 MySQL 계열이 아닌 연결이나 권한 제한 환경에서는 `preInsert()`와 `preUpdate()`의 필드 필터링이 실패할 수 있다. 이런 환경에서는 명시적 field 구성이나 별도 호환 처리를 둔다.
- 스키마 변경 직후 필드 목록이 맞지 않으면 `TTable` 캐시를 지우는 흐름을 추가한다.

## TList 검색과 페이징

- 목록 조회는 `TList` 하위 클래스에 `search(array $params = [])`를 두고 조건과 정렬을 구성한다.
- 검색 조건의 요청값은 `where()`의 기본 `bind=true`를 유지한다. 날짜 함수, 집계식, 검증된 SQL 조각만 `$bind=false`를 고려한다.
- `TList::initialize($limit)`는 현재 조건으로 `getTotalCount()`를 먼저 계산하고 `TPaging`을 만든 뒤 `limit(startRecordNo, recordPerPage)`를 설정한다. 검색 조건을 적용한 다음 `initialize()`를 호출한다.
- `TSqlBuilder`의 기본 limit은 `LIMIT 1 OFFSET 0`이다. `initialize()`를 호출하지 않는 목록 조회에서는 `limit(-1)` 또는 원하는 `limit()`을 명시해 1건만 나오는 실수를 막는다.
- `read(&$list, $filterFunc)`는 결과가 없으면 `false`를 반환한다. 호출부는 빈 배열과 실패 반환을 구분해서 처리한다.
- 필터 함수는 현재 레코드 배열을 받아 출력 배열을 반환하는 가벼운 변환에만 사용한다. 추가 쿼리나 상태 변경을 반복문 안에 숨기지 않는다.

## TModel/TList __call 차이

- `TModel::__call()`은 먼저 내부 `TSqlBuilder` 메서드를 찾아 위임한다. 빌더에 없는 메서드면 바로 `BadMethodCallException`을 던지며, 그 아래의 프로퍼티 접근 코드는 현재 도달하지 않는다.
- `TList::__call()`도 먼저 내부 `TSqlBuilder` 메서드를 찾아 위임한다. 빌더에 없는 메서드는 인자가 없으면 `prop($name)` 조회, 인자가 있으면 `prop($name, $arguments[0])` 저장으로 처리한다.
- 따라서 모델 코드에서 `$model->foo()`를 동적 프로퍼티 getter처럼 기대하지 않는다. 리스트 코드에서는 `$list->page(2)` 같은 동적 프로퍼티 흐름이 가능하지만, 빌더 메서드명과 충돌하지 않게 이름을 고른다.
- 체이닝 중 `where()->orderBy()->read()`처럼 빌더 메서드 뒤 owner 메서드를 호출할 수 있다. 이때 `TSqlBuilder::__call()`은 owner의 `read()` 또는 `readGroup()`으로 넘기므로, owner가 해당 메서드를 실제로 제공하는지 확인한다.

## 가상 모델과 가상 리스트

- `TVirtualModel`은 별도 모델 클래스를 만들기 어려운 임시 테이블, 프로토타입, 낮은 빈도의 단순 CRUD에만 사용한다. 생성 후 반드시 `tableName()`을 지정한다.
- `TVirtualList`는 단순 목록이나 임시 뷰 조회에 사용한다. 복잡한 검색 규칙이 생기면 전용 `TList` 하위 클래스로 승격한다.
- 동적 테이블명이나 SQL 조각을 외부 입력에서 직접 받지 않는다. 가상 클래스의 `tableName()`에는 코드에서 결정한 안전한 값만 전달한다.

## 자주 발생하는 실수

- `TModel` 인스턴스를 재사용하면서 `init()`을 호출하지 않아 이전 field나 where가 다음 CRUD에 섞인다.
- `find()`의 where 없는 단건 조회 동작을 안전한 기본 조회처럼 사용한다.
- 검색 조건을 넣기 전에 `initialize()`를 호출해 전체 건수와 페이징 limit이 실제 검색 조건과 어긋난다.
- `TModel::__call()`도 `TList::__call()`처럼 동적 프로퍼티 getter/setter로 동작한다고 가정한다.
- `TVirtualModel`이나 `TVirtualList`에 외부 입력 테이블명을 그대로 전달한다.

## 검증 체크리스트

- 단건 작업은 `TModel`, 목록 작업은 `TList`로 책임이 나뉘었는지 확인한다.
- CRUD 전 `init()`, `preLoad()`, `preInsert()`, `preUpdate()` 호출 순서가 현재 빌더 상태를 오염시키지 않는지 확인한다.
- 삭제와 수정은 where가 비어 있을 때의 동작을 확인한다. 특히 executor 직접 삭제와 `TModel::remove()`의 안전 범위 차이를 코드 리뷰에 남긴다.
- 목록 조회는 검색 조건 적용 후 페이징 초기화 순서를 지키고, 기본 limit 단건 조회 문제를 확인한다.
- `TModel`과 `TList`의 `__call` 차이를 고려해 동적 프로퍼티 호출이 실제로 동작하는 클래스인지 확인한다.
