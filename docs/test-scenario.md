# CI Workflow 테스트 시나리오

caller repo에 설치된 `*-caller.yml` workflow가 정상 동작하는지 수동으로 검증하는 절차.

## 사전 조건

- `GH_PAT` secret이 caller repo에 설정되어 있을 것
- self-hosted runner(claude-ci, codex-ci)가 online일 것
- `gh` CLI 인증 완료

## 실행 규칙

- 워크플로우는 **한 번에 하나씩** 트리거한다. 완료를 확인한 후 다음으로 넘어간다.
  - 동시에 여러 코멘트를 달면 이벤트 충돌로 워크플로우가 skipped 될 수 있다.
- 실패 시 해당 시나리오를 중단하고 결과를 보고한다.
- 모든 시나리오 완료(또는 중단) 후 반드시 정리 절차를 수행한다.

## 1. Review workflow 검증

### 1-1. 코드 외 수정
- caller repo에 실제 소스 파일이 아닌 문서나 스크립트를 수정한 테스트 브랜치와 PR을 만든다.
- PR이 잘 만들어졌으면 caller repo에 자동으로 수행되는 git action의 결과가 정상인지 체크한다.
- git action의 결과가 정상이라면 PR에 `/claude-review` 코멘트로 review 워크플로우를 트리거한다. 완료 후 `/codex-review`로 `codex-caller.yml` review job도 동일하게 수행한다.
- review 워크플로우에 의해 달리는 댓글의 내용을 확인한다. 실패 메시지가 없는지 확인한다.

### 1-2. 코드 수정
- caller repo에 실제 소스 파일을 수정한 테스트 브랜치와 PR을 만든다.
- PR이 잘 만들어졌으면 caller repo에 자동으로 수행되는 git action의 결과가 정상인지 체크한다.
- git action의 결과가 정상이라면 PR에 `/claude-review` 코멘트로 review 워크플로우를 트리거한다. 완료 후 `/codex-review`로 `codex-caller.yml` review job도 동일하게 수행한다.
- review 워크플로우에 의해 달리는 댓글의 내용을 확인한다. 실패 메시지가 없는지 확인한다.

## 2. Issue workflow 검증

### 2-1. Analysis
- 이슈 작성 내용에 대한 분석 의견만 받을 수 있는 수준의 이슈를 만든다.
- 제목에 `claude`, `codex`를 포함해 각각의 triage가 자동 트리거되도록 만든다.
- 이슈가 잘 만들어졌으면 `claude-caller.yml`의 triage job과 `codex-caller.yml`의 triage job이 자동 실행되는지 확인한다.
- 각 analysis 워크플로우의 댓글 내용을 확인한다. 실패 메시지가 없는지 확인한다.
- 이 시나리오에서는 fix 워크플로우를 동작시키지 않는다.

### 2-2. Analysis + Fix
- 해당 repo에서 간단한 소스코드 수정으로 해결 가능한 이슈를 만든다.
- 제목에 `claude`, `codex`를 포함해 각각의 triage가 자동 트리거되도록 만든다.
- 이슈가 잘 만들어졌으면 `claude-caller.yml`의 triage job과 `codex-caller.yml`의 triage job이 자동 실행되는지 확인한다.
- 각 analysis 워크플로우의 댓글 내용을 확인한다. 실패 메시지가 없는지 확인한다.
- `/claude-fix` 코멘트로 fix 워크플로우를 트리거한다. 완료 후 `/codex-fix`로 `codex-caller.yml` fix job도 동일하게 수행한다.
- fix 워크플로우에 의해 달리는 댓글을 확인한다. 댓글 내용에 PR이 생성되었다는 내용이 있는지 확인한다. 그 워크플로우에 의해 PR이 실제 생성되었는지 확인한다.

### 2-3. Codex Auto Pipeline
- 별도의 테스트 이슈를 만든다. 이슈 내용은 간단한 소스코드 수정 1~2개로 해결 가능한 수준으로 고른다.
- 제목에 `codex-auto`를 포함해 auto-pipeline이 바로 자동 실행되도록 만들거나, 일반 `codex` 이슈에 `auto-fix` 라벨을 추가한다.
- `codex-auto` 제목 경로를 쓰는 경우 triage 없이 auto-pipeline이 바로 도는지 확인한다.
- `codex-caller.yml`의 auto-pipeline job이 실행되어 issue comment, fix branch push, PR 생성, PR review comment, PR checks 확인까지 순서대로 남기는지 확인한다.
- review 결과에 `CRITICAL` 또는 `HIGH`가 있다면 같은 pipeline run 안에서 추가 patch commit이 올라가는지 확인한다.
- 추가 patch commit이 올라간 경우, PR에도 리뷰 반영 내용 코멘트가 별도로 남는지 확인한다.
- PR checks 중 fail이 있다면 같은 pipeline run 안에서 실패 내용을 요약해 후속 patch commit을 올리는지 확인한다.
- checks 실패로 추가 patch commit이 올라간 경우, PR에도 checks 반영 코멘트가 별도로 남는지 확인한다.
- auto-pipeline 결과 댓글에 단계별 상태 표와 생성된 PR URL이 포함되는지 확인한다.

**이슈 작성 팁:**
- repo 코드를 실제로 읽고, 소스 수정 1~2개로 해결 가능한 내용을 선택
- 예: 에러 메시지 개선, 주석/로그 추가, 변수명 개선, 미사용 import 정리 등
- fix 워크플로우가 PR을 생성해야 하므로 "분석만" 필요한 이슈는 피한다

**repo별 이슈 예시:**

| Repo | 이슈 예시 |
|------|----------|
| oh-my-mermaid | `.omm` 디렉토리 없을 때 에러 메시지에 `omm init` 안내 추가 |
| maru | benchmark 결과 출력 시 단위(ms/us) 표시 추가 |
| naru | CLI help 메시지에 사용 예시 추가 |
| pxl | 빌드 실패 시 에러 메시지에 필요 의존성 안내 추가 |

## 3. 정리

모든 시나리오 완료(또는 중단) 후 반드시 수행한다.

- 테스트로 생성한 PR을 닫고 테스트 브랜치를 삭제한다.
- 테스트로 생성한 이슈를 닫는다.
- fix 워크플로우가 생성한 부산물을 정리한다:
  - `claude/fix-issue-{N}`, `codex/fix-issue-{N}` 브랜치 삭제
  - fix가 만든 PR이 있으면 닫기
- auto-pipeline이 만든 PR도 함께 닫고 관련 브랜치를 정리한다.
