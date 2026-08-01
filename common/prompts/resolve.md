# Resolve

After reading this file, report:

```text
[AgentSkills][PROMPT][START] ::resolve
Source: .agentskills/prompts/resolve.md
```

Use this prompt for a bounded review finding, regression, or confirmed defect. Do not create a task, a new design document, or a new `SESSION_BRIEF.md` solely because this command was used. If an existing brief applies, use it as the current specification.

## Invocation Modes

`::resolve <request>` is the default continuous mode. Before editing, report the requested outcome, evidence, target files, non-target files, verification, and whether the request is sufficiently bounded. If the required behavior is unclear, report `PROMPT BLOCKER` and ask for clarification. When the request is confirmed and bounded, continue through Gate without phase-by-phase permission. It does not create or update `SESSION_BRIEF.md` solely for this command, and it never commits, pushes, or merges.

`::resolve --step <request>` is the step mode. Complete only the recorded current Phase, then report `PROMPT END` and wait for the next user instruction. It preserves the approval stops described below.

`::resolve --reset` is the dedicated state-reset operation. It accepts no request text and cannot be combined with `--step`; reject `::resolve --reset <request>` and `::resolve --step --reset` with `PROMPT BLOCKER`. Run only `bash .agentskills/workflows/workflow-state.sh reset resolve` before reporting `PROMPT END`. The script displays the workflow, stored request identity when available, next phase, recorded time, initial staged paths, and state path before archiving only `resolve.state` and `resolve.initial-staged` under `.git/agentskills/workflows/archive/`. It must not change source files, Git worktree or staged changes, commits, branches, pull requests, or Git configuration. A `BLOCKER`, including no resettable state, stops the operation.

Before any work, run `bash .agentskills/workflows/workflow-state.sh show resolve "<exact request>"` (or the equivalent `common/` path). If it reports an unfinished state, resume only at its recorded `Next phase`; do not infer a phase from conversation history or restart an already-recorded phase. The request must match the original request text. If it reports no state or an already-complete state, start a new workflow with `bash .agentskills/workflows/workflow-state.sh start resolve inspect "<request>"`. A legacy-state `BLOCKER` has no request identity and must be reviewed before the explicitly shown `discard-legacy` command is run. Any other `BLOCKER` stops the command without editing.

Execute only the phase reported as `Next phase`:

- `inspect`: confirm the bounded outcome, evidence, targets, non-targets, and verification, then advance to `implement`.
- `implement`: make the smallest correction, then advance to `verify`.
- `verify`: run the relevant verification, then advance to `review` only when it passes.
- `review`: run `diff-review.md`, stage explicit task paths after `OK`, perform the required staged self-review, then advance to `gate`.
- `gate`: run the gate and advance to `complete` only when it passes.

In step mode, stop immediately after completing and recording the selected phase. In default continuous mode, proceed through the next recorded phase in order.

In default continuous mode, stop with `PROMPT BLOCKER` instead of continuing when any of the following applies:

- expected behavior, scope, or non-targets are ambiguous;
- existing staged or unstaged changes cannot be separated from this task;
- no relevant test or project-native verification can be identified;
- the relevant verification does not pass;
- the final diff review reports `WARNING` or `BLOCKER`;
- the final `GATE` or `HOOK` status is `BLOCKER` or `FAIL`;
- the correction requires a destructive, externally visible, security-sensitive, or otherwise irreversible operation.

An individual gate check may emit `WARNING` for information. Report it, but continue when the final `GATE` or `HOOK` status is `PASS`. After a test, review, gate, or hook failure, read `failure-analysis.md` and report the analysis only. Do not apply another correction in the same continuous run.

In step mode, make the smallest coherent change after the user has authorized the correction. In default continuous mode, make it immediately after confirming the request is bounded. Use existing relevant tests when available, or the smallest project-native verification for the target. Do not weaken test expectations for convenience. Do not perform unrelated refactoring.

Before any user-requested commit, run `diff-review.md`, stage explicit paths, and perform a scope-isolated self-review of `AGENTS.md`, `SESSION_BRIEF.md`, `git status`, and `git diff --cached` without relying on the implementation conversation. Under the default `agentskills.reviewPolicy=auto`, if the overall result is `OK`, record it with `bash .agentskills/reviewers/record-manual-review.sh --runtime codex-self-review --status OK`, then run the gate. Report this as `SELF-REVIEW`, not an independent review. Under `independent`, use an external reviewer runtime instead; do not record a self-review for gate approval. Do not commit unless the final gate status is `PASS`.

In default continuous mode, after relevant verification passes, run `diff-review.md`, stage only explicit task paths after `OK`, and do not alter paths that were staged before the workflow began. Perform the same scope-isolated staged self-review and gate sequence. A passing gate ends the workflow; leave the verified task paths staged and do not commit unless the user separately requests it.

After review completes, advance the workflow state to `gate`. After Gate passes, advance it to `complete`.

After completing the requested resolution, report `PROMPT END` with the verification performed and any remaining limitation. In default continuous mode, report one `PROMPT END` after Gate with the verification, review, and gate results. In step mode, report `PROMPT END` after the completed Phase and its recorded next Phase. If evidence or permission is unavailable, report `PROMPT BLOCKER` instead of `PROMPT END`.
