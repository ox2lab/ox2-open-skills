# ox2-open-skills

옥스투랩 AI Skills 모음 저장소입니다.

이 저장소는 직접 수정하지 않으며,
`ox2-skills` 프로젝트의 변경 사항이 자동으로 동기화됩니다.

## 스킬 설치

### 1. 설치 스크립트 다운로드

```bash
curl -O https://raw.githubusercontent.com/ox2lab/ox2-open-skills/main/install-skills.sh
```

### 2. 스크립트 실행

전체 스킬 설치
```bash
sh install-skills.sh
```

특정 스킬만 설치
```bash
sh install-skills.sh [스킬 이름] [스킬 이름] ...
```

예시
```bash
sh install-skills.sh ox2-core ox2-harness ...
```

### 3. 설치 위치

스킬은 아래 폴더에 설치됩니다.
```text
.agents/skills/
```
