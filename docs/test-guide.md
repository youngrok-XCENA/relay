# CI Workflow 수동 테스트 가이드

각 repo에 설치된 `*-caller.yml` workflow가 정상 동작하는지 수동으로 검증하는 절차.

## 사전 조건

- `GH_PAT` secret이 caller repo에 설정되어 있을 것
- self-hosted runner(claude-ci, codex-ci)가 online일 것
- `gh` CLI 인증 완료

```bash
# 확인
gh secret list -R {owner}/{repo} | grep GH_PAT
gh api repos/{owner}/{repo}/actions/runners --jq '.runners[] | "\(.name): \(.status)"'
```

## 1. 테스트 PR 생성 (review 워크플로우용)

caller repo에 실제 소스 파일을 수정한 테스트 브랜치와 PR을 만든다.

```bash
REPO="youngrok-XCENA/{repo}"
BASE_BRANCH="main"  # repo에 따라 master

# 테스트 브랜치 생성
BASE_SHA=$(gh api repos/$REPO/git/ref/heads/$BASE_BRANCH --jq '.object.sha')
gh api repos/$REPO/git/refs -f ref=refs/heads/ci-test/verify -f sha=$BASE_SHA --silent

# 소스 파일 수정 (프로젝트에 맞는 파일 선택)
FILE_PATH="src/index.ts"  # 예시
FILE_DATA=$(gh api "repos/$REPO/contents/$FILE_PATH?ref=$BASE_BRANCH")
FILE_SHA=$(echo "$FILE_DATA" | jq -r '.sha')
ORIGINAL=$(echo "$FILE_DATA" | jq -r '.content' | base64 -d)
MODIFIED=$(printf '%s\n// CI test: verify review workflow\n' "$ORIGINAL")

gh api "repos/$REPO/contents/$FILE_PATH" -X PUT \
  -f message="ci: test change" \
  -f content="$(echo "$MODIFIED" | base64 -w 0)" \
  -f branch=ci-test/verify \
  -f sha="$FILE_SHA" --silent

# PR 생성
gh pr create -R $REPO --base $BASE_BRANCH --head ci-test/verify \
  --title "[CI Test] Workflow verification" \
  --body "Testing review workflows."
```

## 2. 테스트 이슈 생성 (triage/fix 워크플로우용)

fix 워크플로우가 실제로 코드를 수정하고 PR을 만들 수 있도록, 해당 repo에서 간단한 소스코드 수정으로 해결 가능한 이슈를 만든다.

```bash
gh issue create -R $REPO \
  --title "[CI Test] claude codex 이슈 제목" \
  --body "이슈 상세 내용"
```

- 제목에 `claude`가 있으면 `claude-caller.yml`의 triage job이 자동 트리거된다.
- 제목에 `codex`가 있으면 `codex-caller.yml`의 triage job이 자동 트리거된다.
- 제목에 `codex-auto`가 있으면 `codex-caller.yml`의 auto-pipeline job이 자동 트리거된다.
- `auto-fix` 라벨을 붙여도 `codex-caller.yml`의 auto-pipeline job을 트리거할 수 있다.

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

## 3. 워크플로우 트리거

PR과 이슈가 생성되면 아래 순서로 코멘트를 달아 트리거한다. **하나씩 순서대로** 실행하고, 각 워크플로우가 완료된 후 다음으로 넘어간다 (동시에 여러 코멘트를 달면 이벤트 충돌로 skipped 발생).

### PR 워크플로우

| 순서 | 코멘트 | 트리거 대상 | 비고 |
|------|--------|------------|------|
| - | (자동) | code-style, cppcheck | C++ repo만 해당. PR 생성 시 자동 트리거 |
| 1 | `/claude-review` | claude-review | PR 코멘트 |
| 2 | `/codex-review` | codex review (`codex-caller.yml`) | PR 코멘트 |

```bash
# claude-review (완료 대기 후 다음 실행)
gh pr comment {PR_NUMBER} -R $REPO --body "/claude-review"

# codex-review
gh pr comment {PR_NUMBER} -R $REPO --body "/codex-review"
```

### Issue 워크플로우

| 순서 | 코멘트 | 트리거 대상 | 비고 |
|------|--------|------------|------|
| - | 제목에 `claude` | `claude-caller.yml` triage job | 이슈 생성 시 자동 트리거 |
| - | 제목에 `codex` | `codex-caller.yml` triage job | 이슈 생성 시 자동 트리거 |
| - | 제목에 `codex-auto` | `codex-caller.yml` auto-pipeline job | 이슈 생성 시 자동 트리거 |
| 1 | `/claude-fix` | claude-fix | 이슈 코멘트 |
| 2 | `/codex-fix` | codex fix (`codex-caller.yml`) | 이슈 코멘트 |
| 3 | `auto-fix` 라벨 | codex auto-pipeline (`codex-caller.yml`) | 제목 trigger 대체 경로, 별도 테스트 이슈 권장 |

```bash
# claude-fix
gh issue comment {ISSUE_NUMBER} -R $REPO --body "/claude-fix"

# codex-fix
gh issue comment {ISSUE_NUMBER} -R $REPO --body "/codex-fix"

# codex auto-pipeline (별도 이슈 권장, 제목에 codex-auto를 넣거나)
gh issue edit {ISSUE_NUMBER} -R $REPO --add-label auto-fix
```

후속 질문이나 재분석이 필요하면 수동으로 `/claude-issue`, `/codex-issue` 코멘트를 추가할 수 있다.
`auto-pipeline`은 자체적으로 브랜치 생성, PR 생성, 리뷰, 추가 patch까지 수행하므로 `/codex-fix`와 같은 이슈에서 동시에 검증하지 않는 편이 안전하다. `codex-auto` 제목 이슈는 triage 대신 auto-pipeline이 바로 실행된다.

## 4. 결과 확인

### 워크플로우 실행 상태 확인

```bash
for wf in claude-caller.yml codex-caller.yml code-style-caller.yml cppcheck-caller.yml; do
  status=$(gh api "repos/$REPO/actions/workflows/${wf}/runs" \
    --jq '.workflow_runs[0] | "\(.status)|\(.conclusion)"' 2>/dev/null)
  echo "$wf: $status"
done
```

### 코멘트 내용 확인

```bash
# PR 코멘트
gh api repos/$REPO/issues/{PR_NUMBER}/comments \
  --jq '.[] | select(.user.login == "github-actions[bot]") | .body[:200]'

# Issue 코멘트
gh api repos/$REPO/issues/{ISSUE_NUMBER}/comments \
  --jq '.[] | select(.user.login == "github-actions[bot]") | .body[:200]'
```

### 판정 기준

| 상태 | 판정 |
|------|------|
| workflow `success` + 코멘트에 실제 분석/리뷰 내용 | **PASS** |
| workflow `success` + 코멘트에 `❌` 포함 | **FAIL** (AI 실행 실패) |
| workflow `failure` | **FAIL** (workflow step 실패) |
| workflow `skipped` | 재시도 필요 (이벤트 충돌 가능) |

## 5. 정리

```bash
# PR 닫기 + 브랜치 삭제
gh pr close {PR_NUMBER} -R $REPO
gh api repos/$REPO/git/refs/heads/ci-test/verify -X DELETE

# 이슈 닫기
gh issue close {ISSUE_NUMBER} -R $REPO

# fix 워크플로우가 생성한 부산물 정리
gh api repos/$REPO/git/refs/heads/claude/fix-issue-{ISSUE_NUMBER} -X DELETE 2>/dev/null
gh api repos/$REPO/git/refs/heads/codex/fix-issue-{ISSUE_NUMBER} -X DELETE 2>/dev/null

# fix가 만든 PR 닫기
gh pr list -R $REPO --state open --json number,title \
  --jq '.[] | select(.title | contains("fix:")) | .number' | while read n; do
  gh pr close $n -R $REPO
done
```

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `Repository not found` (checkout 실패) | GH_PAT secret 미설정 또는 권한 부족 | repo secret의 `GH_PAT`를 확인하고 `GH_PAT=$GH_TOKEN ./install.sh {repo}` 재실행 |
| `SyntaxError: Unexpected token '?'` | runner의 Node.js 버전이 v18 미만 | nvm 설치 후 Node.js 18+ 설정, workflow에 nvm 로드 확인 |
| `claude: command not found` | nvm이 runner 환경에서 로드되지 않음 | workflow의 Run step에 nvm.sh 로드 확인 |
| `invalid header field value "token ***\n"` | GH_PAT에 trailing newline 포함 | repo secret의 `GH_PAT`를 줄바꿈 없이 다시 설정 후 `GH_PAT=$GH_TOKEN ./install.sh {repo}` 재실행 |
| `xhigh is not supported` | Codex 모델 파라미터 에러 | codex workflow의 model/reasoning_effort 설정 확인 |
| workflow `skipped` | 동시 코멘트로 이벤트 충돌 | 하나씩 순서대로 트리거 |
| workflow `queued`에서 안 넘어감 | runner가 offline이거나 미등록 | runner 상태 복구 후 `./install.sh {repo}` 재실행 |
