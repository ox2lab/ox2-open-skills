---
name: ox2-harness
description: 사용자가 "하네스 방식으로 진행"을 명시하거나 코드 작성/수정이 포함된 복합 작업을 요청할 때 사용한다. 파일 수정이 없는 설명/조회, 단일 파일의 사소한 수정, "빠르게", "간단히", "바로" 요청에는 사용하지 않는다.
---

# 개요

- 일반 프로젝트의 개발을 돕는 범용 작업 하네스 스킬이다.
- **Plan → Build → Review** 루프로 코드 작성/수정 작업을 관리한다.
- 세 단계 모두 메인 세션이 스킬 패키지 내 `agents/*.md`를 프롬프트 템플릿으로 사용하여 **독립 컨텍스트에서 동작하는 범용 서브에이전트**로 호출한다:
    - **Plan**: `agents/ox2-planner.md` (코드베이스 탐색 후 plan.md/checklist.md 초안 작성)
    - **Build**: `agents/ox2-builder.md` (실제 코드 작성/수정)
    - **Review**: `agents/ox2-reviewer.md` (체크리스트 기반 판정)
- 메인 세션은 새 `{timestamp}` 폴더 생성, 프롬프트 템플릿 로드 및 서브에이전트 호출, 사용자 승인 흐름 제어, 승인 전 일반 수정의 직접 Edit 처리, 루프 제어, 사용자 커뮤니케이션을 담당한다.

# 언제 사용하는가

- **명시적**: 사용자가 "하네스 방식으로 진행"을 언급한 경우
- **자동**: 코드 작성/수정이 포함된 복합 작업
- **제외**:
    - 파일 수정이 발생하지 않는 작업 (설명, 정보 조회, 개념 질문)
    - 단일 파일의 사소한 수정 (오타, 포맷팅)
    - 사용자가 "빠르게", "간단히", "바로"를 명시한 경우

# 서브에이전트 사용 메커니즘 (중요)

- 본 스킬은 **멀티 에이전트 스킬**이다. 다양한 코드 에이전트 환경에서 동작하는 것을 목표로 한다.
    - 따라서 **특정 벤더의 서브에이전트 타입 식별자를 하드코딩하지 않는다.**
    - 대신 **"독립 컨텍스트에서 동작하는 범용 서브에이전트"** 라는 추상 개념으로 기술한다.
    - 각 에이전트는 자기 환경에 맞는 동등한 범용 서브에이전트로 매핑하여 동작한다.
- 본 스킬의 세 서브에이전트(`ox2-planner`, `ox2-builder`, `ox2-reviewer`)는 **에디터의 서브에이전트 레지스트리에 사전 설치되지 않는다.**
- 메인 세션이 런타임에 다음 절차로 호출한다:
    1. 스킬이 로드된 디렉토리의 `agents/ox2-planner.md` / `agents/ox2-builder.md` / `agents/ox2-reviewer.md` 중 해당 단계 파일을 **Read**한다.
    2. YAML 프론트매터를 **제외한** 본문 전체를 프롬프트 본체로 사용한다.
    3. 본문 끝에 현재 작업의 런타임 컨텍스트(현재 `{timestamp}` 폴더의 절대 경로, `metadata.json` 경로, 확정된 `actor.name`, 사용자 요청 원문, `plan.md`/`checklist.md`/`result.md` 등 참조 또는 작성 파일 경로, git diff 범위, 이번에 작성할 `review-{NN}.md` 파일명, 이전 `review-*.md` / `fix-*.md` 경로 등)를 덧붙인다.
    4. **Task/Agent 툴**로 **독립 컨텍스트에서 동작하는 범용 서브에이전트**를 호출하여 위 프롬프트를 전달한다.
- 효과:
    - 사용자의 사전 복사/세션 재시작 없이 즉시 동작한다.
    - 스킬 패키지 내 `agents/*.md`가 단일 진실 소스가 되어 수정 즉시 반영된다.
    - 환경별 경로 하드코딩이 불필요하므로 범용성이 유지된다.
- 안전장치:
    - 등록형 서브에이전트가 아니므로 YAML `tools` 필드의 도구 제한이 시스템 차원에서 강제되지 **않는다.**
    - 이를 보완하기 위해 각 프롬프트 템플릿 본문 안에 도구 사용 규칙을 **강제 가드 문구로 명시**한다.
        - `ox2-planner`: 코드/산출물 수정 금지(`Edit`/`NotebookEdit` 미사용), `plan.md`/`checklist.md` 신규 작성만 허용.
        - `ox2-reviewer`: `Write`/`Edit`/`NotebookEdit` 미사용, 새 `review-{NN}.md` 신규 작성만 예외 허용.
    - 메인 세션은 본문을 그대로 전달하며, 가드 문구를 임의로 제거·완화하지 않는다.

## 서브에이전트 미지원 환경 폴백

- 실행 환경에 Task/Agent 툴 또는 독립 컨텍스트 서브에이전트 기능이 없거나, 정책상 사용할 수 없는 경우에도 하네스 작업을 중단하지 않는다.
- 이 경우 메인 세션이 해당 단계의 `agents/*.md` 파일을 Read하고, YAML 프론트매터를 제외한 본문을 그대로 단계별 실행 지침으로 사용하여 직접 수행한다.
- 폴백 실행 시에도 **Plan → Build → Review** 순서, `{timestamp}` 폴더 규칙, 승인 대기, 상태 블록, 리뷰 판정, 루프 제어 규칙은 동일하게 적용한다.
- 단, 독립 컨텍스트 분리가 사라지므로 메인 세션은 각 단계 전환 시 역할을 명확히 전환한다:
    - **Plan** 단계에서는 코드 파일을 수정하지 않고 `plan.md` / `checklist.md`만 작성한다.
    - **Build** 단계에서는 승인된 `plan.md` 범위 안에서만 구현한다.
    - **Review** 단계에서는 구현자의 자기보고가 아니라 `checklist.md`와 실제 diff를 기준으로 판정한다.
- 폴백으로 진행한 경우 `result.md` 또는 최종 보고에 “서브에이전트 미지원으로 메인 세션 폴백 실행” 사실을 간단히 기록한다.

# 디렉토리 구조

- 모든 작업 기록은 각 Plan 작업 전용 폴더 안에 저장한다.
- 루트 위치: **`프로젝트_루트/ox2-harness-runs/`**
- Plan 작업별 폴더: **`프로젝트_루트/ox2-harness-runs/{timestamp}/`**
- `프로젝트_루트/ox2-harness-runs/`는 스킬 패키지 설치 위치(에디터/CLI별 스킬 디렉토리)와는 **완전히 별개**다. 스킬은 에디터 설정 디렉토리에 설치되고, 작업 산출물은 각 프로젝트 루트의 `ox2-harness-runs/`에 저장된다.
- 폴더 내부 파일 명명 (타임스탬프는 폴더명에만 사용, 파일명에는 포함하지 않는다):
    - `metadata.json`
    - `plan.md`
    - `checklist.md`
    - `result.md`
    - `review-{NN}.md`
    - `fix-{NN}.md`
- `{timestamp}` 형식: `yyyymmdd-hhmmss`
- `{NN}`: `01`부터 시작하는 두 자리 정수

## 작업자 메타데이터

- 새 하네스 작업이 시작될 때마다 메인 세션은 `{timestamp}` 폴더 안에 `metadata.json`을 생성한다.
- `metadata.json`에는 작업자 정보로 **사용자 이름만** 저장한다. 이메일, handle, 계정 ID는 기본 저장하지 않는다.
- 메인 세션은 `actor.name` 후보값을 자동 추론하되, `metadata.json` 생성 전에 사용자에게 이번 작업의 작업자 이름을 확인한다.
- `actor.name` 후보 우선순위:
    1. 사용자 요청에 작업자 이름이 명시된 경우
    2. `OX2_HARNESS_ACTOR` 환경변수
    3. `git config user.name`
    4. OS 사용자명
    5. `unknown`
- 사용자가 확인하거나 수정한 이름을 `metadata.json`의 `actor.name`으로 저장한다.
- 동일 Plan 내 Build 재실행, Review 반복, fix 작성, 에스컬레이션 후 복귀에서는 `metadata.json`의 `actor.name`을 그대로 사용하고 다시 묻지 않는다.
- 사용자가 명시적으로 "새 Plan"을 요청하면 새 `{timestamp}` 폴더와 새 `metadata.json`을 만들고 작업자 이름을 다시 확인한다.
- `metadata.json` 예시:

```json
{
  "run_id": "20260421-143000",
  "started_at": "2026-04-21T14:30:00+09:00",
  "actor": {
    "name": "홍길동",
    "source": "user_confirmed"
  }
}
```

## `{timestamp}` 폴더 생성·유지 규칙 (매우 중요)

- **새 하네스 작업이 시작될 때마다(즉, 새로운 Plan이 시작될 때마다) 반드시 현재 시각으로 새 `{timestamp}` 폴더를 생성한다.**
    - 기존 `{timestamp}` 폴더를 재사용하거나 덮어쓰지 않는다.
    - 이전 작업의 `{timestamp}` 폴더는 이력 자료로서 그대로 보존한다.
- 다음과 같은 경우에는 **같은** `{timestamp}` 폴더를 유지한다 (새 폴더를 만들지 않는다):
    - 동일 Plan 내의 반복 작업: **Build** 재실행, **Review** 재수행, 계획 이탈 후 재승인을 받아 이어가는 작업
    - 승인 전 plan.md/checklist.md 수정 (메인 세션이 직접 Edit하든, ox2-planner를 재호출하든 같은 폴더 유지)
    - 에스컬레이션 후 복귀 (동일 Plan의 연속)

## 디렉토리 구조 예시

```
프로젝트_루트/
└── ox2-harness-runs/
    ├── 20260421-143000/
    │   ├── metadata.json
    │   ├── plan.md
    │   ├── checklist.md
    │   ├── result.md
    │   ├── review-01.md
    │   ├── fix-01.md
    │   ├── review-02.md
    │   └── fix-02.md
    └── 20260422-091500/
        ├── metadata.json
        ├── plan.md
        ├── checklist.md
        └── ...
```

# 핵심 절차: Plan → Build → Review 루프

## 1단계: Plan (ox2-planner 프롬프트 템플릿으로 실행)

- **하네스 작업이 시작될 때마다 반드시 현재 시각으로 새 `{timestamp}`(yyyymmdd-hhmmss)를 생성한다.**
    - 기존 `{timestamp}` 폴더를 재사용하지 않는다.
    - 기존 폴더에 덮어쓰거나 추가로 파일을 쌓지 않는다.
- 메인 세션은 `프로젝트_루트/ox2-harness-runs/{timestamp}/` 폴더를 **새로** 생성한다.
- 메인 세션은 `actor.name` 후보값을 추론한 뒤 사용자에게 이번 작업의 작업자 이름을 확인한다.
- 메인 세션은 확인된 작업자 이름을 사용하여 `{timestamp}` 폴더 안에 `metadata.json`을 생성한다.

메인 세션은 다음 절차로 Plan 초안 작성을 위임한다:

1. 스킬이 로드된 디렉토리의 **`agents/ox2-planner.md`**를 Read한다.
2. YAML 프론트매터를 **제외한** 본문을 프롬프트 본체로 사용한다.
3. 본문 끝에 현재 작업의 런타임 컨텍스트를 덧붙인다:
    - 사용자 요청 원문
    - 현재 `{timestamp}` 폴더의 **절대 경로**
    - `metadata.json` 경로
    - 확정된 `actor.name`
    - 작성할 `plan.md`/`checklist.md` 경로
4. **Task/Agent 툴**로 **독립 컨텍스트에서 동작하는 범용 서브에이전트**를 호출하여 위 프롬프트를 전달한다.

호출된 서브에이전트는 사용자 요청을 이해하고 필요한 만큼의 코드베이스 탐색을 거쳐 `{timestamp}` 폴더 안에 다음 파일을 작성한다:
- `plan.md` (작업 지침)
- `checklist.md` (Review 단계의 판정 기준)

Plan 서브에이전트는 `metadata.json`을 참조만 하며 수정하지 않는다.

서브에이전트 종료 후 메인 세션은 `plan.md` / `checklist.md`를 사용자에게 제시하고 **명시적 승인**(예: "승인", "진행해", "OK")을 기다린다. 승인 없이 **Build** 단계로 넘어가지 않는다.

### 사용자 피드백에 따른 수정 처리 (중요)

- **승인 전 `plan.md` / `checklist.md`에 대한 일반적인 수정 요청은 메인 세션이 직접 Edit으로 처리한다. `ox2-planner`를 재호출하지 않는다.**
    - **이유**: 매 수정마다 planner를 재호출하면 코드베이스 탐색이 반복되어 토큰 오버헤드가 발생한다.
    - **적용 범위**: 문구·범위·우선순위·체크리스트 항목 조정 등, 추가 코드 탐색이 필요 없는 모든 수정.
- 단, 수정이 **새로운 코드베이스 탐색을 요구하는 큰 재계획**(예: "다른 모듈도 검토해서 보강해줘", "X 의존성을 다시 분석해서 plan을 다시 짜줘")인 경우에는 `ox2-planner`를 다시 호출한다.
- 어느 경로든 **같은 `{timestamp}` 폴더 안의 `plan.md` / `checklist.md`를 갱신**한다 (새 폴더를 만들지 않는다).

## 2단계: Build (ox2-builder 프롬프트 템플릿으로 실행)

메인 세션은 다음 절차로 **Build**를 위임한다:

1. 스킬이 로드된 디렉토리의 **`agents/ox2-builder.md`**를 Read한다.
2. YAML 프론트매터를 **제외한** 본문을 프롬프트 본체로 사용한다.
3. 본문 끝에 현재 작업의 런타임 컨텍스트를 덧붙인다:
    - 현재 `{timestamp}` 폴더의 **절대 경로**
    - `metadata.json` 경로
    - 확정된 `actor.name`
    - `plan.md`, `checklist.md`의 경로
    - 재빌드인 경우 이전 `review-*.md` / `fix-*.md`의 경로
    - 작업 범위 등 메인 세션이 알고 있는 추가 컨텍스트
4. **Task/Agent 툴**로 **독립 컨텍스트에서 동작하는 범용 서브에이전트**를 호출하여 위 프롬프트를 전달한다.

호출된 서브에이전트는 다음을 모두 참조한다 (모두 같은 `{timestamp}` 폴더 내부):
- `metadata.json` (확정된 `actor.name`)
- `plan.md` (작업 지침)
- `checklist.md` (진행 중 의식할 기준)
- 이전 `review-*.md` / `fix-*.md` (재빌드인 경우)

서브에이전트는 `plan.md`에 따라 실제 코드 작성/수정을 수행하고, `{timestamp}` 폴더 안에 `result.md`를 작성한다 (무엇을, 어떻게, 검증 결과, 상태 블록).
- `metadata.json`의 `actor.name`을 작업자 정보로 참조하되 이메일, handle, 계정 ID를 추가로 수집하거나 기록하지 않는다.
- 같은 **Plan** 내에서 **Build**가 반복될 때마다 최신 결과로 갱신(덮어쓰기)한다 — 같은 `{timestamp}` 폴더 유지.
- 이전 **Build**와의 차이는 git diff로 확인한다.

서브에이전트 종료 후 메인 세션은 `result.md`의 **상태 블록**을 확인하여 다음 단계를 분기한다:
- `STATUS: COMPLETED` → **Review** 단계로 진행
- `STATUS: DEVIATION` → 아래 **계획 이탈 처리** 흐름으로 진입

### 계획 이탈 처리

1. 서브에이전트는 이탈을 감지하면 즉시 작업을 중단하고, `result.md`에 이탈 사유 및 `STATUS: DEVIATION` 플래그를 기록한 뒤 종료한다.
2. 메인 세션은 `result.md`를 확인하고 사용자에게 **에스컬레이션**한다.
3. 사용자 지시에 따라 `plan.md`를 업데이트한다 (**같은** `{timestamp}` 폴더 유지).
4. 필요하면 `checklist.md`도 업데이트한다.
5. 사용자 재승인 후 메인 세션이 `ox2-builder` 프롬프트 템플릿으로 **Build**를 **다시 호출**하여 재개한다.
6. **Plan** 업데이트 시점 이후의 **Build**는 "새 Build"로 간주한다.
    - `result.md`는 새로 덮어쓴다.

## 3단계: Review (ox2-reviewer 프롬프트 템플릿으로 실행)

메인 세션은 다음 절차로 **Review**를 위임한다:

1. 스킬이 로드된 디렉토리의 **`agents/ox2-reviewer.md`**를 Read한다.
2. YAML 프론트매터를 **제외한** 본문을 프롬프트 본체로 사용한다.
3. 본문 끝에 현재 작업의 런타임 컨텍스트를 덧붙인다:
    - 현재 `{timestamp}` 폴더의 **절대 경로**
    - `metadata.json` 경로
    - 확정된 `actor.name`
    - `checklist.md`, `plan.md`, `result.md`의 경로
    - git diff 범위
    - 이번에 작성할 `review-{NN}.md` 파일명 (메인 세션이 기존 `review-*.md`를 확인하여 다음 번호 결정)
    - 이전 `review-*.md` / `fix-*.md` 경로
4. **Task/Agent 툴**로 **독립 컨텍스트에서 동작하는 범용 서브에이전트**를 호출하여 위 프롬프트를 전달한다.

호출된 서브에이전트는 다음을 모두 참조한다 (모두 같은 `{timestamp}` 폴더 내부):
- `metadata.json` (확정된 `actor.name`)
- `checklist.md` (판정 기준)
- `plan.md` (맥락)
- `result.md` (자가보고)
- 실제 코드 변경 (git diff)
- 이전 `review-*.md` / `fix-*.md` (재리뷰인 경우)

서브에이전트는 `{timestamp}` 폴더 안에 `review-{NN}.md`를 작성한다 (판정 + 근거).
- `metadata.json`의 `actor.name`을 작업자 정보로 참조하되 이메일, handle, 계정 ID를 추가로 수집하거나 기록하지 않는다.
- 판정 값: **APPROVED** / **NEEDS_REVISION** / **REJECTED**

메인 에이전트는 review 결과를 받아 `{timestamp}` 폴더 안에 `fix-{NN}.md`를 작성한다 (수정 계획 + 어떤 지적을 어떻게 해결할지).

## 루프 제어

- **APPROVED**: 모든 checklist 항목 통과, blocking 이슈 없음 → 작업 완료
- **NEEDS_REVISION**: checklist 일부 미달, 구현 수정으로 해결 가능 → `fix-{NN}.md`를 참조하여 **Build** 반복 (같은 `{timestamp}` 폴더 유지, `ox2-builder` 프롬프트 템플릿 재호출)
    - `review-03.md`까지 생성되었음에도 **APPROVED**가 나오지 않으면 에스컬레이션한다 (최대 3회 리뷰 후에도 승인이 안 나는 경우).
- **REJECTED**: 계획(plan) **자체의 결함**, 구현 수정으로 해결 불가 → 사용자에게 에스컬레이션 (루프 중단)

## 에스컬레이션 시 보고 내용

- 현재까지의 리뷰 이력
- 반복 지적된 이슈
- 방향 재검토 권고 여부

## 에스컬레이션 후 복귀

- 사용자의 지시에 따라 작업을 재개한다.
- 재개는 **동일 Plan의 연속**이므로 **같은 `{timestamp}` 폴더를 유지**하고 다음 `{NN}`부터 이어간다.
- 사용자가 명시적으로 "새 Plan"을 요청하면 새 `{timestamp}` 폴더를 생성한다 (이 경우에만 새 폴더).

# 요약 흐름도

```
[새 {timestamp} 폴더 생성]
        ↓
[actor.name 확인 후 metadata.json 생성]
        ↓
[Plan: agents/ox2-planner.md를 Read하여 독립 컨텍스트의 범용 서브에이전트로 호출]
        ↓
plan.md / checklist.md 작성 → 사용자 승인 대기
        │
        ├── 승인 전 일반 수정 요청 → 메인 세션이 직접 Edit (planner 재호출 X)
        ├── 승인 전 큰 재계획 요청 → ox2-planner 재호출 (같은 폴더)
        └── 승인
                ↓
[Build: agents/ox2-builder.md를 Read하여 독립 컨텍스트의 범용 서브에이전트로 호출]
        ↓
result.md 상태 블록 확인
        │
├── STATUS: DEVIATION → 사용자 에스컬레이션 → plan 업데이트 → 재승인 → Build 재호출
        │
        └── STATUS: COMPLETED
                ↓
        [Review: agents/ox2-reviewer.md를 Read하여 독립 컨텍스트의 범용 서브에이전트로 호출]
                ↓
        review-{NN}.md 판정
                │
                ├── NEEDS_REVISION → fix-{NN}.md 작성 → Build 재호출 (같은 폴더)
                │                    (review-03까지도 미승인 시 에스컬레이션)
                │
                ├── REJECTED → 사용자 에스컬레이션 (루프 중단)
                │
                └── APPROVED → 완료
```
