---
name: ox2-core-db-sql-runtime
description: ox2-core의 DB SQL 런타임 계층을 작성하거나 수정할 때 사용한다. TConnection, TCommand, TSqlBuilder, TSqlExecutor, TDataSet, TTable 관련 코드에서 SQL 생성, 바인딩, 실행, 결과셋, 테이블 메타데이터 처리가 등장하면 반드시 이 스킬을 적용한다.
---

# ox2-core DB SQL 런타임 작업 지침

## 적용 범위

ox2-core의 SQL 런타임 계층을 기준으로 코드를 작성한다. 특히 `TConnection`, `TCommand`, `TSqlBuilder`, `TSqlExecutor`, `TDataSet`, `TTable`을 사용하는 코드에서 이 지침을 따른다.

## 연결과 실행 객체

- 기본 연결은 `TConnection::getConnection()`을 사용한다. 별도 연결이 필요한 경우에만 생성자에 `TConnection`을 주입한다.
- `TConnection`은 `PDO`를 상속하며 기본 fetch 모드는 연관 배열이다. 결과 처리 코드는 숫자 인덱스에 기대지 말고 컬럼명을 기준으로 작성한다.
- 트랜잭션 상태는 `TConnection::$inTransaction`으로 관리된다. 중첩 트랜잭션처럼 보이는 코드를 새로 만들지 말고, `beginTransaction()`, `commit()`, `rollBack()`의 기존 동작을 존중한다.
- SQL 직접 실행이 필요하면 `TSqlExecutor::query($sql, $bindField)`를 우선 사용한다. 단, CRUD 빌더 흐름에 들어맞는 작업은 직접 SQL보다 `TSqlBuilder`와 `TSqlExecutor`의 전용 메서드를 사용한다.

## TSqlBuilder 작성 규칙

- `TSqlBuilder`의 `tableName()`, `field()`, `where()`, `having()`, `groupBy()`, `orderBy()`, `limit()`은 getter/setter 겸용 체이닝 메서드다. 인자가 없으면 현재 SQL 조각이나 상태를 반환하고, 인자가 있으면 내부 상태를 변경한 뒤 `$this`를 반환한다.
- 체이닝 예시는 다음 흐름을 따른다.

```php
$builder
	->tableName('users')
	->field('name', $name)
	->where('id', $id)
	->orderBy('created_at', 'DESC');
```

- `where()`, `having()`, `field()`의 `$bind` 기본값은 `true`다. 사용자 입력, 요청 파라미터, 외부 데이터는 기본적으로 `bind=true`를 유지한다.
- `$bind=false`는 `NOW()`, `COUNT(*)`, 이미 검증된 SQL 함수, 프레임워크 내부 상수처럼 SQL 리터럴로 넣어야 하는 값에만 사용한다. 요청값을 `$bind=false`로 넣지 않는다.
- `where('id', [1, 2, 3])`처럼 숫자 인덱스 배열을 넘기면 기본 IN 절이 만들어진다. 배열 조건을 직접 문자열 조립으로 만들지 않는다.
- 조건이 복잡해서 `where('AND (...)')`처럼 원문 조건을 넣을 수는 있지만, 값은 가능한 별도 바인딩 조건으로 분리한다.
- `reset()`은 테이블명, 필드, 조건, 정렬, 그룹, 바인딩, limit을 모두 초기화한다. 같은 빌더 인스턴스를 재사용할 때는 이전 조건이 섞이지 않도록 작업 시작점에서 명시적으로 초기화한다.

## limit 기본값 주의

- `TSqlBuilder`의 기본 limit은 `LIMIT 1 OFFSET 0`이다. 단건 조회에는 유리하지만 목록 조회나 집계 조회에서는 의도하지 않게 1건만 반환할 수 있다.
- 여러 건을 조회해야 하면 반드시 `limit($offset, $limit)`, `limit($limit)`, 또는 제한이 없어야 할 때 `limit(-1)`을 명시한다.
- `TSqlExecutor::readOne()`은 빌더의 limit 상태와 관계없이 `LIMIT 1`을 강제한다. 여러 건이 필요한 코드에서 `readOne()`을 사용하지 않는다.
- `TSqlExecutor::update()`는 기본 limit 값이 그대로면 SQL에 limit을 붙이지 않는다. 삭제는 `TSqlExecutor::delete()`가 limit을 붙이지 않으므로 where 조건을 더 엄격히 확인한다.

## 실행 안전 규칙

- `append()`, `replace()`, `update()`, `delete()`, `read()`는 빌더의 `bindField`를 그대로 사용한다. 필드와 조건을 만든 뒤 별도로 바인딩 배열을 조작하지 않는다.
- `delete()`는 `WHERE`가 비어도 실행 가능한 SQL을 만든다. 하위 모델의 `remove()`와 달리 런타임 executor에는 무조건 삭제 방지 장치가 없다. executor를 직접 사용할 때는 호출 전에 `where()`가 비어 있지 않은지 확인한다.
- 디버깅이 필요하면 각 실행 메서드의 `$debug` 인자를 사용한다. SQL 문자열을 임시 출력하거나 예외 메시지에 민감한 값을 직접 붙이지 않는다.
- 예외 처리에서는 원래 `PDOException` 흐름과 `TLog::error()` 로깅을 보존한다. 실패를 조용히 삼키는 코드를 만들지 않는다.

## TDataSet 결과 처리

- `TDataSet::open()`은 전체 결과를 `fetchAll(PDO::FETCH_ASSOC)`로 읽어 `recordSet`, `current`, `columns`, `values`, `recordCount`를 채운다. 대용량 스트리밍이 필요한 작업에는 적합하지 않다.
- 빈 결과는 `isEmpty()`로 먼저 확인한다. `rows()`와 `toArray()`는 빈 배열을 반환할 수 있지만, 현재 레코드 기반 접근과 `column()` 호출은 빈 결과에서 의도와 달라질 수 있으므로 단건 값 접근 전에는 반드시 확인한다.
- 단일 컬럼 목록은 `rows($name)`, 키 기반 배열은 `toArray($keyColumn, $valueColumn)`을 사용한다. 반복문으로 같은 변환을 중복 구현하지 않는다.
- `column()`과 동적 프로퍼티 접근은 현재 레코드 기준이다. 커서를 이동한 뒤 사용하는 값이 바뀐다는 점을 코드 흐름에 드러낸다.

## TTable 메타데이터 규칙

- `TTable::getFieldNames()`와 `clearAllFieldNames()`는 MySQL의 `information_schema`에 의존한다. SQLite나 information_schema가 없는 DB에서 그대로 동작한다고 가정하지 않는다.
- 모델의 `preInsert()`와 `preUpdate()`는 `TTable` 필드 목록을 기준으로 요청 필드를 거른다. 테이블 메타데이터 캐시가 stale일 수 있는 마이그레이션 직후에는 `clearFieldNames()` 또는 `clearAllFieldNames()` 호출을 고려한다.
- `TTable`은 필드명 캐시에 `TCache`를 사용한다. 캐시 정책을 바꿀 때는 DB 메타데이터 조회 빈도와 스키마 변경 반영 시점을 함께 확인한다.

## 자주 발생하는 실수

- `where()`나 `field()`를 인자 없이 호출해 현재 상태를 읽는 코드와, 인자를 넣어 상태를 변경하는 코드를 혼동한다.
- 목록 조회에서 `limit()`을 명시하지 않아 기본 `LIMIT 1 OFFSET 0` 때문에 1건만 반환된다.
- 사용자 입력을 `$bind=false`로 넘겨 SQL 문자열에 직접 삽입한다.
- `TModel::remove()`의 where 방어 동작을 `TSqlExecutor::delete()`에도 있다고 착각한다.
- SQLite 연결이 가능하다는 이유로 `TTable::getFieldNames()`도 SQLite에서 동작한다고 가정한다.

## 검증 체크리스트

- SQL 생성 로직을 바꿀 때는 getter 호출과 setter 호출을 혼동하지 않았는지 확인한다.
- 요청값이 들어가는 모든 조건과 필드는 `bind=true` 흐름인지 확인한다.
- 목록 조회, 집계 조회, 삭제, 수정 코드에서는 기본 limit과 where 유무를 명시적으로 검토한다.
- 테이블 필드 자동 필터링에 기대는 코드는 대상 DB가 `information_schema`를 지원하는지 확인한다.
