# Platform Architecture Enhancement Plan

## 현재 상태 진단

### 문제 1: Monolith Workflow (2400줄 × 2)

```
claude.yml (2405줄) ─── 5개 모드가 하나의 파일에
codex.yml  (2078줄) ─── 거의 동일한 로직을 복사
                        ────────────────────────
                        총 4483줄, ~85% 중복
```

한 모드(예: review)를 수정하면 두 파일을 모두 고쳐야 하고,
auto-pipeline 하나가 ~1150줄이라 변경 영향도 파악이 어렵다.

### 문제 2: 에이전트 결합도

에이전트 추가 = 2000줄 워크플로우 복사. 현재 차이점은 실제로 이것뿐:

| 항목 | Claude | Codex |
|------|--------|-------|
| CLI 호출 | `claude --print` | `codex exec` |
| 기본 모델 | `claude-sonnet-4-6` | `gpt-5.4` |
| 키워드/라벨 | `claude`, `/claude-*` | `codex`, `/codex-*` |
| Runner 라벨 | `claude-ci` | `codex-ci` |
| 전용 옵션 | `max_turns` | `codex_sandbox`, `node_path` |

나머지 (git 조작, PR 생성, 리뷰 프롬프트 구성, 체크 폴링, 코멘트 포스팅)는 **100% 동일**.

### 문제 3: 상태 비가시성

파이프라인 진행 상태가 GitHub Actions 로그에만 존재.
실패 시 어느 단계에서 멈췄는지, 재시도가 몇 회째인지 외부에서 알 수 없다.

---

## 개선안

### Phase 1: Agent Abstraction Layer (에이전트 추상화)

**목표**: 에이전트를 플러그인으로 교체 가능하게 만들어, 새 에이전트 추가 시 설정 파일 하나로 대응.

#### 1-1. 통합 `run-agent` Action

현재 `run-claude`와 `run-codex`를 하나의 `run-agent` 액션으로 통합.

```yaml
# .github/actions/run-agent/action.yml
inputs:
  agent:        # "claude" | "codex" | "gemini" | ...
    required: true
  prompt:
    required: true
  model:
    required: false
  max_turns:
    required: false
  agent_config:  # JSON string for agent-specific options
    required: false
    default: "{}"

outputs:
  result:
  exit_code:
  failure_type:
  session_id:
```

내부적으로 `agent` 값에 따라 분기:
```bash
case "$AGENT" in
  claude) run_claude "$PROMPT_FILE" "$OUTPUT_FILE" ;;
  codex)  run_codex  "$PROMPT_FILE" "$OUTPUT_FILE" ;;
  *)      echo "Unknown agent: $AGENT"; exit 1 ;;
esac
```

공통 로직 (세션 관리, failure type 감지, 출력 정규화)은 shared function으로.

#### 1-2. 통합 Workflow

`claude.yml` + `codex.yml` → **`relay.yml`** 하나로 통합.

```yaml
# relay.yml
inputs:
  agent:
    type: string
    required: true        # "claude" | "codex"
  mode:
    type: string
    required: true        # "review" | "fix" | "triage" | "auto-pipeline"
  # ... 공통 inputs ...
```

Caller 쪽도 단순화:
```yaml
# Before (claude-caller.yml + codex-caller.yml = 2 files)
uses: youngrok-XCENA/relay/.github/workflows/claude.yml@main

# After (relay-caller.yml = 1 file)
uses: youngrok-XCENA/relay/.github/workflows/relay.yml@main
with:
  agent: claude
  mode: review
```

**효과**: 4483줄 → ~2500줄. 에이전트 추가 시 `run-agent`에 case 하나만 추가.

---

### Phase 2: Workflow Modularization (워크플로우 분해)

**목표**: 2400줄 monolith를 단계별 reusable workflow로 분리.

#### 분리 단위

```
relay.yml (router, ~100줄)
├── review.yml    (~200줄)
├── fix.yml       (~300줄)
├── pr-fix.yml    (~250줄)
├── triage.yml    (~270줄)
└── auto-pipeline.yml (~800줄)
    ├── uses: triage.yml (분석)
    ├── uses: fix.yml (수정)
    └── uses: review.yml (리뷰)
```

#### router 패턴

```yaml
# relay.yml - 라우터
jobs:
  route-review:
    if: inputs.mode == 'review'
    uses: ./.github/workflows/review.yml
    with:
      agent: ${{ inputs.agent }}
      # ...

  route-fix:
    if: inputs.mode == 'fix'
    uses: ./.github/workflows/fix.yml
    with:
      agent: ${{ inputs.agent }}
      # ...
```

**주의**: GitHub Actions에서 reusable workflow는 중첩 호출이 최대 4단계.
caller → relay.yml → auto-pipeline.yml까지는 3단계로 가능.
하지만 auto-pipeline에서 다시 review.yml을 호출하면 4단계 → 한계.

**대안**: auto-pipeline은 composite action 또는 단일 job 내 step 분리로 유지.
review/fix/triage만 독립 workflow로 분리하고, auto-pipeline은 이들의 로직을
shared script로 호출.

#### Shared Scripts

```
.github/scripts/
├── analyze-issue.sh      # 이슈 분석 프롬프트 빌드
├── build-fix-prompt.sh   # 수정 프롬프트 빌드
├── build-review-prompt.sh # 리뷰 프롬프트 빌드
├── create-pr.sh          # PR 생성 + 본문 포맷팅
├── post-result.sh        # 결과 코멘트 포스팅
└── collect-checks.sh     # CI 체크 수집 (기존 action에서 추출)
```

**효과**: 각 모드를 독립적으로 테스트/배포 가능. 변경 영향도 최소화.

---

### Phase 3: Pipeline State Management (상태 관리)

**목표**: 파이프라인 진행 상태를 추적 가능하게 만들어, 실패 재시도/비용 추적/대시보드 연동 가능.

#### 3-1. State Artifact

각 파이프라인 실행 시 JSON 상태 파일을 GitHub Actions Artifact로 저장:

```json
{
  "pipeline_id": "auto-pipeline-42",
  "issue_number": 42,
  "agent": "claude",
  "started_at": "2026-04-04T10:00:00Z",
  "stages": [
    {
      "name": "analysis",
      "status": "completed",
      "started_at": "...",
      "completed_at": "...",
      "session_id": "sess_abc123"
    },
    {
      "name": "fix",
      "status": "in_progress",
      "attempt": 2,
      "started_at": "..."
    },
    {
      "name": "review",
      "status": "pending"
    }
  ],
  "metrics": {
    "total_tokens": 45000,
    "api_calls": 3,
    "check_polls": 12
  }
}
```

#### 3-2. Issue Label 기반 상태

파이프라인 진행 단계를 이슈 라벨로 표시:

```
pipeline:analyzing → pipeline:fixing → pipeline:reviewing → pipeline:complete
                                                          → pipeline:needs-human
```

**효과**:
- 이슈 목록에서 파이프라인 상태 한눈에 파악
- 실패 시 어느 단계에서 멈췄는지 즉시 확인
- 외부 대시보드 연동 가능 (label webhook)

---

### Phase 4: Quality Gates (품질 게이트)

**목표**: 자동 머지 전 품질 기준을 선언적으로 정의.

#### Relay Config 파일

```yaml
# .relay/config.yml (caller repo에 배치)
quality_gates:
  auto_merge: false          # true면 모든 게이트 통과 시 자동 머지
  require_tests: true
  min_test_coverage_delta: 0  # 커버리지 감소 불허
  max_review_issues: 0       # CRITICAL/HIGH 이슈 0개
  require_human_approval:
    - "security/*"           # 보안 관련 파일 변경 시
    - "*.yml"                # CI 설정 변경 시

agent_preferences:
  default: claude
  review: codex              # 리뷰는 다른 에이전트로 (cross-review)

pipeline:
  max_fix_attempts: 3
  max_review_rounds: 2
  timeout_minutes: 60
```

**효과**: 팀이 "어디까지 자동이고 어디서 사람이 개입할지"를 코드로 관리.

---

## 구현 상태

```
Phase 1 (Agent Abstraction)     ✅ 완료 — relay.yml + run-agent 통합
  ↓
Phase 2 (Modularization)        ✅ 완료 — format-and-commit 액션 추출
  ↓
Phase 3 (State Management)      ✅ 완료 — pipeline-label 기반 상태 추적
  ↓
Phase 4 (Quality Gates)         ✅ 완료 — .relay/config.yml + human approval gate
```

### Phase 1 예상 작업량

1. `run-agent` 통합 액션 생성 (run-claude + run-codex 병합)
2. `relay.yml` 통합 워크플로우 작성
3. caller 템플릿 업데이트 (`install.sh` 수정)
4. 기존 테스트 마이그레이션
5. claude.yml / codex.yml을 relay.yml로 전환

### 마이그레이션 전략

기존 caller repo와의 호환성을 위해:
1. `relay.yml`을 먼저 추가 (병행 운영)
2. `install.sh`가 새로운 caller 생성하도록 업데이트
3. 충분한 검증 후 claude.yml / codex.yml deprecated 처리
4. 다음 메이저 버전에서 제거

---

## 아키텍처 변경 후 구조

```
Before:
relay/
├── .github/workflows/
│   ├── claude.yml      (2405줄)
│   └── codex.yml       (2078줄)
├── .github/actions/
│   ├── run-claude/
│   └── run-codex/

After:
relay/
├── .github/workflows/
│   ├── relay.yml        (~200줄, router)
│   ├── review.yml       (~200줄)
│   ├── fix.yml          (~300줄)
│   ├── triage.yml       (~270줄)
│   └── auto-pipeline.yml (~800줄)
├── .github/actions/
│   └── run-agent/       (통합 에이전트 러너)
├── .github/scripts/     (공유 스크립트)
├── .relay/              (설정 스키마)
│   └── config.schema.yml
```

**총 줄 수**: 4483줄 → ~1770줄 (60% 감소)
**에이전트 추가 비용**: 2000줄 복사 → `run-agent`에 ~50줄 추가
