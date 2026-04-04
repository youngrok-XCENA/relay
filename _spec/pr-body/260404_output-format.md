# PR Body 출력 형식

## 배경

- **원본**: [PR #89 리뷰](https://github.com/youngrok-XCENA/pxl/pull/89) — auto-pipeline이 생성한 PR body가 대상 레포의 PR 템플릿을 준수하지 않는 문제에서 출발
- **맥락**: fix/auto-pipeline 모드에서 Claude/Codex가 생성하는 PR body의 형식을 표준화하고, 대상 레포의 PR 템플릿을 자동으로 감지하여 반영하는 스펙

## 원칙

1. **Why before How** — 변경 이유(`### Why`)가 항상 PR body의 첫 섹션
2. **설계 변경은 mermaid** — 구조적 변경(call flow, module boundary, data flow 등)이 있으면 `### Design changes` 섹션에 mermaid 다이어그램 포함. 단순 변경(config, typo, 단일 함수)이면 섹션 생략
3. **PR 템플릿 자동 준수** — 대상 레포에 `.github/pull_request_template.md`가 있으면 자동 감지하여 Why / Design changes 뒤에 템플릿 형식을 채움

## 출력 구조

```
### Why
(이 변경이 필요한 이유. 적용하지 않으면 어떤 문제가 있는가?)

### Design changes (optional)
(구조적 변경이 있을 때만. mermaid 다이어그램 포함)

--- PR 템플릿이 있는 경우 아래가 추가됨 ---

## 📌 PR 요약
...
## 📝 상세 내용
...
(이하 대상 레포의 PR 템플릿 형식 그대로)

Closes #N
```

## PR 템플릿 감지

fix 프롬프트 조립 시(`Collect issue context` 단계) 아래 순서로 탐색:

1. workflow input `pr_template`이 있으면 사용
2. 없으면 체크아웃된 레포에서 `.github/pull_request_template.md` → `.github/PULL_REQUEST_TEMPLATE.md` 순으로 탐색
3. 둘 다 없으면 Why / Design changes만 출력 (기본 형식)

## Preamble 제거

Claude/Codex가 프롬프트 지시에도 불구하고 출력 앞에 메타 코멘터리("All tests pass.", "The fix is complete." 등)를 추가하는 경우가 있다. 이를 방지하기 위해:

- **프롬프트 레벨**: `CRITICAL: Output Format` 섹션에서 "Output NOTHING before the first section header" 명시
- **후처리 레벨**: PR body 조립 시 `sed -n '/^#/,$p'`로 첫 `#` 헤딩 이전 텍스트를 제거. 결과가 비면 원본 사용 (폴백)
- **적용 범위**: PR body (`Create PR` 단계), PR fix comment (`Post PR fix comment` 단계)

## 분석 단계 READ-ONLY 제약

`Analyze issue` 단계는 분석만 수행해야 하며 코드를 수정해서는 안 된다. 프롬프트에 아래 규칙이 포함됨:

> This is a READ-ONLY analysis step. Do NOT modify, edit, or write any files. Do NOT run fix commands. Only read and analyze.

이 제약이 없으면 분석 에이전트가 fix까지 수행하고 "fix 완료" 메시지를 분석 코멘트에 포함시키는 문제가 발생한다.
