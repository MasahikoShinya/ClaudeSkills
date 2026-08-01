# Publish

Report `[AgentSkills][PROMPT][START] ::publish` after reading this file. This is the only command that may commit, push, and create a draft PR.

Accepted forms:

```text
::publish
::publish --loop
```

First run `::scope` procedure and inspect Git status, staged and unstaged diffs, applicable `SESSION_BRIEF.md`, workflow state, review, and final gate evidence. Stop with `PROMPT BLOCKER` if the scope is mixed, required verification/review/gate evidence is missing or failing, an unfinished workflow exists, or candidate paths are not explicit. Never stage unrelated paths and never use `git add .`, `git add -A`, or unrestricted `git add -u`.

Before any external write, display the exact paths to stage, commit message, destination branch, remote, and draft PR title. The original `::publish` invocation authorizes this publish operation; do not request a second conversational confirmation. Stage only the displayed paths, re-check the staged diff, commit, and push the current branch. If an open PR for the current branch already exists (prefer the PR recorded by `publish-state.sh`), reuse it; do not create a second PR. Otherwise create a draft PR with `gh pr create --draft` and record its number and URL with `bash .agentskills/workflows/publish-state.sh record <number> <url>`. Report the commit SHA, PR URL, and recorded PR number. Never merge or convert the draft PR to ready for review.

`::publish` ends after that one publish operation. `::publish --loop` continues as follows:

1. Run `::pr-review` against the PR created or reused above.
2. If its overall result is `OK`, report success and end.
3. If it reports a bounded, actionable finding with concrete evidence, run `::resolve <finding>` for that finding. Do not infer requirements beyond the finding, and preserve the `::resolve` safety stops.
4. After every completed resolution, run the same publish procedure to commit and push its explicit paths to the existing PR, then run `::pr-review` again.
5. Repeat at most three remediation cycles. Stop with `PROMPT BLOCKER` instead of another cycle if a finding is ambiguous, out of scope, security-sensitive, destructive or externally visible; required checks fail without a clearly bounded correction; verification, review, or gate fails; the same finding remains; a new unrelated finding appears; or the cycle limit is reached.

`::publish --loop` never merges, marks a draft ready, comments on a PR, changes Git configuration, or creates a second PR for the same branch. End with `PROMPT END`, including the PR number, each remediation cycle, and the final PR-review result.
