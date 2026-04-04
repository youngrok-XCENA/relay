## 개발 환경 설정

clone 후 반드시 pre-commit hook을 활성화한다.

```bash
git config core.hooksPath .githooks
```

이 hook은 커밋 시 `tests/test_*.sh`를 전부 실행한다. 테스트가 하나라도 실패하면 커밋이 차단된다.

## 테스트

```bash
bash .githooks/pre-commit
```

전체 테스트를 실행한다. 개별 테스트는 `bash tests/test_xxx.sh`로 실행할 수 있다.

테스트는 install.sh의 함수를 source해서 검증하는 방식이다. 외부 API 호출이 필요한 경우 mock 함수로 대체한다 (`tests/test_install_secret.sh` 참고).

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
