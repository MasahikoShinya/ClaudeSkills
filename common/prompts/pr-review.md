# Pull Request Review

After reading this file, report:

```text
[AgentSkills][PROMPT][START] ::pr-review
Source: .agentskills/prompts/pr-review.md
```

Review only. Do not modify code, tests, staging, Git configuration, the PR, or its merge state.

Accept one optional argument: a GitHub PR number or URL. An explicit argument always wins. When omitted, inspect the PR recorded by the latest `::publish`; if none is recorded, use the PR associated with the current branch; if that is unavailable, use the current user's most recently updated open PR. If no PR can be selected, report `PROMPT BLOCKER`. First run:

```bash
.agentskills/reviewers/inspect-pull-request.sh [<PR-number-or-URL>]
```

If the kit is used directly from the AgentSkills repository, use the equivalent `common/` path. Treat a missing or unauthenticated `gh` CLI as `BLOCKER`; show the failed prerequisite and do not invent PR metadata, checks, or diffs.

Use only these sources as evidence:

- PR metadata, base branch, head branch, review decision, and checks from `gh`
- `gh pr diff <PR-number>` and `gh pr diff <PR-number> --name-only`
- current file contents needed to understand the PR diff
- repository rules that apply to the changed paths

Do not use parent conversation context, implementation intent, previous review results, or assumptions about why the PR was created. Review out-of-scope work, regressions, security and data-integrity risks, fragile error paths, convenient test changes, compatibility failures, and missing relevant verification.

Output:

1. PR number, URL, base/head, draft status, mergeability, review decision, and checks status.
2. Findings ordered by severity. Each finding must include file, line when known, evidence, impact, and recommended action.
3. One overall result: `OK`, `WARNING`, or `BLOCKER`.
4. A merge recommendation. `OK` may recommend merge only when the PR is open, not draft, mergeable, and its required checks are passing or none are configured. `WARNING` or `BLOCKER` must recommend against merge.

Never run `gh pr merge`, `gh pr edit`, `gh pr comment`, `git push`, or any write operation as part of `::pr-review`. A merge requires a separate explicit user instruction.

After the result, report `PROMPT END` with `Execution: completed` and the same overall result. If PR metadata, checks, or the diff cannot be collected, report `PROMPT BLOCKER` with the failed prerequisite instead of `PROMPT END`.
