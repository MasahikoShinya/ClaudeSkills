#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_COMMON="$(cd "$TEST_DIR/.." && pwd)"
ORIGINAL_PATH="$PATH"
PASS_COUNT=0
FAIL_COUNT=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok %d - %s\n' "$PASS_COUNT" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'not ok - %s\n' "$1" >&2
}

assert_contains() {
  local value="$1"
  local expected="$2"
  local label="$3"
  if [[ "$value" == *"$expected"* ]]; then
    pass "$label"
  else
    fail "$label (missing: $expected)"
  fi
}

assert_not_contains() {
  local value="$1"
  local unexpected="$2"
  local label="$3"
  if [[ "$value" == *"$unexpected"* ]]; then
    fail "$label (unexpected: $unexpected)"
  else
    pass "$label"
  fi
}

new_repo() {
  local repo
  repo="$(mktemp -d "$TEST_ROOT/repo.XXXXXX")"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name AgentSkillsTest
  cp -R "$SOURCE_COMMON" "$repo/common"
  printf '# Rules\n' >"$repo/AGENTS.md"
  printf '# Brief\nConfirmed scope.\n' >"$repo/SESSION_BRIEF.md"
  cat >"$repo/AGENT_MODELS.md" <<'EOF'
| Runtime | A | B | C | Review | Escalation |
| Codex | - | - | - | test-review | test-escalation |
EOF
  printf 'base\n' >"$repo/app.txt"
  git -C "$repo" add .
  git -C "$repo" commit -qm baseline
  printf '%s\n' "$repo"
}

new_target_repo() {
  local repo
  repo="$(mktemp -d "$TEST_ROOT/target.XXXXXX")"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name AgentSkillsTest
  printf '# Project Rules\n' >"$repo/AGENTS.md"
  printf '%s\n' "$repo"
}

new_target_repo_with_symlinked_agents() {
  local repo
  repo="$(mktemp -d "$TEST_ROOT/target-symlink.XXXXXX")"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name AgentSkillsTest
  printf '# Project Rules\n' >"$repo/AGENTS-target.md"
  ln -s AGENTS-target.md "$repo/AGENTS.md"
  printf '%s\n' "$repo"
}

make_fake_codex() {
  local repo="$1"
  mkdir -p "$repo/fake-bin"
  cat >"$repo/fake-bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while (($# > 0)); do
  if [[ "$1" == "--output-last-message" ]]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
if [[ -n "${FAKE_CODEX_DELAY_SECONDS:-}" ]]; then
  /bin/sleep "$FAKE_CODEX_DELAY_SECONDS"
fi
printf '%s\n' "$FAKE_CODEX_RESULT" >"$output"
EOF
  chmod +x "$repo/fake-bin/codex"
}

make_tracked_sleep() {
  local repo="$1"
  cat >"$repo/fake-bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$$" >"$FAKE_SLEEP_PID_FILE"
exec /bin/sleep "$@"
EOF
  chmod +x "$repo/fake-bin/sleep"
}

make_fake_gh() {
  local repo="$1"
  mkdir -p "$repo/fake-bin"
  cat >"$repo/fake-bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "${FAKE_GH_VIEW_FAIL:-0}" == "1" ]]; then
    echo "authentication required" >&2
    exit 1
  fi
  printf '%s\n' '{"number":42,"url":"https://github.com/example/repo/pull/42","title":"Test PR","state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"feature/test","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","reviewDecision":""}'
elif [[ "$1" == "pr" && "$2" == "checks" ]]; then
  if [[ "${FAKE_GH_NO_CHECKS:-0}" == "1" ]]; then
    echo "no checks reported on the 'feature/test' branch" >&2
    exit 1
  fi
  printf '%s\n' 'unit-tests\tpass\t2m'
elif [[ "$1" == "pr" && "$2" == "diff" && "$4" == "--name-only" ]]; then
  if [[ "${FAKE_GH_DIFF_FAIL:-0}" == "1" ]]; then
    echo "PR diff is unavailable" >&2
    exit 1
  fi
  printf '%s\n' 'src/example.ts'
else
  echo "Unexpected gh arguments: $*" >&2
  exit 2
fi
EOF
  chmod +x "$repo/fake-bin/gh"
}

make_stubborn_codex() {
  local repo="$1"
  mkdir -p "$repo/fake-bin"
  cat >"$repo/fake-bin/codex" <<'EOF'
#!/usr/bin/env bash
trap '' TERM
while :; do :; done
EOF
  chmod +x "$repo/fake-bin/codex"
}

run_reviewer_with_result() {
  local repo="$1"
  local result="$2"
  local output_file="$repo/reviewer.out"
  make_fake_codex "$repo"
  set +e
  (
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="$repo/fake-bin:$ORIGINAL_PATH" FAKE_CODEX_RESULT="$result" common/reviewers/review-staged-diff.sh
  ) >"$output_file" 2>&1
  TEST_RC=$?
  set -e
  TEST_OUTPUT="$(cat "$output_file")"
}

test_status_consistency() {
  local repo result
  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  result='{"status":"OK","summary":"wrong","model":"test","escalate":false,"findings":[{"severity":"BLOCKER","category":"regression","file":"app.txt","line":1,"evidence":"changed","finding":"breaks","reason":"regression","recommendation":"fix"}]}'
  run_reviewer_with_result "$repo" "$result"
  [[ "$TEST_RC" == "3" ]] && pass "status/finding contradiction is rejected" || fail "status/finding contradiction is rejected"
  assert_contains "$TEST_OUTPUT" "Invalid or inconsistent reviewer JSON" "contradiction reason is visible"
  assert_contains "$TEST_OUTPUT" "Run state:" "invalid reviewer result exposes the run-state path"
  assert_contains "$TEST_OUTPUT" "Log:" "invalid reviewer result exposes the log path"
  assert_contains "$TEST_OUTPUT" "Result:" "invalid reviewer result preserves the result path"
}

test_evidence_required() {
  local repo result
  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  result='{"status":"WARNING","summary":"missing evidence","model":"test","escalate":false,"findings":[{"severity":"WARNING","category":"other","file":"app.txt","line":1,"finding":"unclear","reason":"missing","recommendation":"inspect"}]}'
  run_reviewer_with_result "$repo" "$result"
  [[ "$TEST_RC" == "3" ]] && pass "finding without evidence is rejected" || fail "finding without evidence is rejected"
}

test_manual_cache_and_invalidation() {
  local repo output rc
  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  (cd "$repo" && common/reviewers/record-manual-review.sh --runtime claude --status OK) >/dev/null
  set +e
  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="/usr/bin:/bin" common/reviewers/review-staged-diff.sh 2>&1
  )"
  rc=$?
  set -e
  [[ "$rc" == "0" ]] && pass "manual cache works without Codex" || fail "manual cache works without Codex"
  assert_contains "$output" "Cached: true" "manual cache use is visible"

  printf 'Changed confirmed scope.\n' >>"$repo/SESSION_BRIEF.md"
  set +e
  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="/usr/bin:/bin" common/reviewers/review-staged-diff.sh 2>&1
  )"
  rc=$?
  set -e
  [[ "$rc" == "3" ]] && pass "brief change invalidates manual cache" || fail "brief change invalidates manual cache"
  assert_contains "$output" "no valid manual review" "invalidated cache explains Codex fallback"
}

test_review_policy_and_nested_codex() {
  local repo output rc result
  result='{"status":"OK","summary":"clean","model":"test","escalate":false,"findings":[]}'

  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  output="$(cd "$repo" && common/reviewers/record-manual-review.sh --runtime codex-self-review --status OK 2>&1)"
  assert_contains "$output" "[AgentSkills][SELF-REVIEW][OK]" "self-review attestation is labeled separately"

  git -C "$repo" config agentskills.reviewPolicy independent
  output="$(cd "$repo" && common/reviewers/record-manual-review.sh --runtime codex-self-review --status OK 2>&1)"
  make_fake_codex "$repo"
  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="$repo/fake-bin:$ORIGINAL_PATH" FAKE_CODEX_RESULT="$result" common/reviewers/review-staged-diff.sh 2>&1
  )"
  assert_contains "$output" "Cached: false" "independent policy ignores the self-review cache"

  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  make_fake_codex "$repo"
  set +e
  output="$(cd "$repo" && CODEX_THREAD_ID=active PATH="$repo/fake-bin:$ORIGINAL_PATH" common/reviewers/review-staged-diff.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "nested Codex review is blocked without a self-review cache" || fail "nested Codex review is blocked without a self-review cache"
  assert_contains "$output" "Nested Codex reviewer disabled" "nested Codex block is explicit"
  assert_contains "$output" "--runtime codex-self-review --status OK" "nested Codex block shows the self-review recording command"

  git -C "$repo" config agentskills.reviewPolicy independent
  set +e
  output="$(cd "$repo" && CODEX_THREAD_ID=active PATH="$repo/fake-bin:$ORIGINAL_PATH" common/reviewers/review-staged-diff.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "independent policy blocks nested Codex review" || fail "independent policy blocks nested Codex review"
  assert_contains "$output" "independent policy requires an external reviewer" "independent policy gives an external-review resolution"
  assert_not_contains "$output" "--runtime codex-self-review --status OK" "independent policy does not suggest a self-review cache"
}

test_staged_path_parsing() {
  local repo output unusual_path
  repo="$(new_repo)"
  mkdir -p "$repo/tests"
  printf 'test\n' >"$repo/tests/old.test.js"
  git -C "$repo" add tests/old.test.js
  git -C "$repo" commit -qm test-file
  git -C "$repo" mv tests/old.test.js renamed.txt
  unusual_path=$'line\nbreak.test.js'
  printf 'newline\n' >"$repo/$unusual_path"
  git -C "$repo" add -A
  output="$(cd "$repo" && source common/lib/review-common.sh && agentskills_collect_staged_risk 999999 999999 && printf 'files=%s escalate=%s\n' "$AGENTSKILLS_CHANGED_FILES" "$AGENTSKILLS_REVIEW_ESCALATE" && printf 'path=%q\n' "${AGENTSKILLS_STAGED_PATHS[@]}")"
  assert_contains "$output" "files=2 escalate=1" "rename and unusual path are counted and escalated"
  assert_contains "$output" "old.test.js" "rename source path is inspected"
  assert_contains "$output" "break.test.js" "newline-containing path is preserved"

  git -C "$repo" reset -q --hard HEAD
  git -C "$repo" rm -q tests/old.test.js
  output="$(cd "$repo" && source common/lib/review-common.sh && agentskills_collect_staged_risk 999999 999999 && printf 'files=%s escalate=%s\n' "$AGENTSKILLS_CHANGED_FILES" "$AGENTSKILLS_REVIEW_ESCALATE")"
  assert_contains "$output" "files=1 escalate=1" "deleted test path triggers escalation"
}

test_fallback_path() {
  local repo output rc
  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  git -C "$repo" config agentskills.kitPath common
  set +e
  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="/usr/bin:/bin" common/gates/check-llm-review.sh 2>&1
  )"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "missing Codex blocks automatic review" || fail "missing Codex blocks automatic review"
  assert_contains "$output" '::subagent-review' "fallback displays the manual review pseudo-command"
  assert_contains "$output" "bash common/reviewers/record-manual-review.sh" "fallback uses configured kit path"
}

test_mechanical_gates() {
  local repo output rc
  repo="$(new_repo)"
  printf 'TOKEN=secret\n' >"$repo/.env.local"
  git -C "$repo" add .env.local
  set +e
  output="$(cd "$repo" && common/gates/check-sensitive-files.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" != "0" ]] && pass "sensitive staged file is blocked" || fail "sensitive staged file is blocked"
  assert_contains "$output" "BLOCKER" "sensitive-file blocker is visible"

  git -C "$repo" reset -q --hard HEAD
  dd if=/dev/zero of="$repo/large.bin" bs=1048576 count=5 2>/dev/null
  printf x >>"$repo/large.bin"
  git -C "$repo" add large.bin
  set +e
  output="$(cd "$repo" && common/gates/check-large-files.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" != "0" ]] && pass "file over 5 MiB is blocked" || fail "file over 5 MiB is blocked"

  git -C "$repo" reset -q --hard HEAD
  printf 'trailing space \n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  set +e
  output="$(cd "$repo" && AGENTSKILLS_SKIP_LLM_REVIEW=1 common/gates/pre-commit-gate.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" != "0" ]] && pass "whitespace error is blocked by pre-commit gate" || fail "whitespace error is blocked by pre-commit gate"
  assert_contains "$output" "[AgentSkills][CHECK][START] whitespace" "pre-commit check name is visible"
}

test_reviewer_timeout() {
  local repo output rc start end
  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  git -C "$repo" config agentskills.reviewTimeoutSeconds 1
  git -C "$repo" config agentskills.reviewTimeoutKillGraceSeconds 1
  make_stubborn_codex "$repo"

  start="$(date +%s)"
  set +e
  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="$repo/fake-bin:$ORIGINAL_PATH" common/reviewers/review-staged-diff.sh 2>&1
  )"
  rc=$?
  set -e
  end="$(date +%s)"
  [[ "$rc" == "3" ]] && pass "TERM-resistant reviewer is forcibly stopped" || fail "TERM-resistant reviewer is forcibly stopped"
  assert_contains "$output" "exceeded 1 seconds" "timeout reason is visible"
  assert_contains "$output" "Run state:" "timeout exposes the run-state path"
  assert_contains "$output" "Log:" "timeout exposes the log path"
  assert_contains "$output" "Last log lines:" "timeout reports the captured log tail"
  (((end - start) < 8)) && pass "timeout returns within bounded time" || fail "timeout returns within bounded time"

  git -C "$repo" config agentskills.reviewTimeoutSeconds invalid
  set +e
  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="$repo/fake-bin:$ORIGINAL_PATH" common/reviewers/review-staged-diff.sh 2>&1
  )"
  rc=$?
  set -e
  [[ "$rc" == "3" ]] && pass "invalid timeout configuration is rejected" || fail "invalid timeout configuration is rejected"
  assert_contains "$output" "must be a positive integer" "invalid timeout explains required format"
}

test_successful_reviewer_cleans_watchdog() {
  local repo result output timer_pid
  repo="$(new_repo)"
  printf 'change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  git -C "$repo" config agentskills.reviewTimeoutSeconds 30
  make_fake_codex "$repo"
  make_tracked_sleep "$repo"
  result='{"status":"OK","summary":"clean","model":"test","escalate":false,"findings":[]}'

  output="$(
    cd "$repo"
    unset CODEX_THREAD_ID
    PATH="$repo/fake-bin:$ORIGINAL_PATH" FAKE_CODEX_RESULT="$result" FAKE_CODEX_DELAY_SECONDS=1 FAKE_SLEEP_PID_FILE="$repo/sleep.pid" common/reviewers/review-staged-diff.sh 2>&1
  )"
  assert_contains "$output" "[AgentSkills][LLM-REVIEW][PASS]" "successful reviewer completes"
  if [[ -f "$repo/sleep.pid" ]]; then
    timer_pid="$(cat "$repo/sleep.pid")"
    if kill -0 "$timer_pid" 2>/dev/null; then
      kill "$timer_pid" 2>/dev/null || true
      fail "successful reviewer cleans watchdog timer"
    else
      pass "successful reviewer cleans watchdog timer"
    fi
  else
    fail "successful reviewer started a watchdog timer"
  fi
}

test_pull_request_inspection() {
  local repo output rc
  repo="$(new_repo)"
  make_fake_gh "$repo"
  set +e
  output="$(cd "$repo" && PATH="$repo/fake-bin:/usr/bin:/bin" common/reviewers/inspect-pull-request.sh 42 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "0" ]] && pass "pull-request inspection succeeds" || fail "pull-request inspection succeeds"
  assert_contains "$output" "[AgentSkills][PR-REVIEW][START] #42" "PR number is displayed"
  assert_contains "$output" "unit-tests" "PR checks are displayed"
  assert_contains "$output" "src/example.ts" "PR changed files are displayed"
  assert_contains "$output" "Review diff with: gh pr diff 42" "PR diff command is displayed"

  set +e
  output="$(cd "$repo" && PATH="$repo/fake-bin:/usr/bin:/bin" FAKE_GH_NO_CHECKS=1 common/reviewers/inspect-pull-request.sh 42 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "0" ]] && pass "PR inspection permits absent checks" || fail "PR inspection permits absent checks"
  assert_contains "$output" "[AgentSkills][PR-REVIEW][SKIP] checks" "absent checks are skipped rather than warned"

  set +e
  output="$(cd "$repo" && PATH="$repo/fake-bin:/usr/bin:/bin" FAKE_GH_VIEW_FAIL=1 common/reviewers/inspect-pull-request.sh 42 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "PR metadata failure blocks inspection" || fail "PR metadata failure blocks inspection"
  assert_contains "$output" "[AgentSkills][PR-REVIEW][BLOCKER] PR metadata unavailable" "metadata failure is visible"
  assert_contains "$output" "gh auth login" "metadata failure provides authentication resolution"

  set +e
  output="$(cd "$repo" && PATH="$repo/fake-bin:/usr/bin:/bin" FAKE_GH_DIFF_FAIL=1 common/reviewers/inspect-pull-request.sh 42 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "PR diff failure blocks inspection" || fail "PR diff failure blocks inspection"
  assert_contains "$output" "[AgentSkills][PR-REVIEW][BLOCKER] PR diff unavailable" "diff failure is visible"
}

test_pull_request_inspection_without_gh() {
  local repo output rc
  repo="$(new_repo)"
  set +e
  output="$(cd "$repo" && PATH="/usr/bin:/bin" common/reviewers/inspect-pull-request.sh 42 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "3" ]] && pass "missing GitHub CLI fails with the documented status" || fail "missing GitHub CLI fails with the documented status"
  assert_contains "$output" "GitHub CLI not found" "missing GitHub CLI is visible"
  assert_contains "$output" '::pr-review' "missing GitHub CLI names the pseudo-command"
  if [[ "$output" == *"unbound variable"* ]]; then
    fail "missing GitHub CLI does not expand pseudo-command text as a variable"
  else
    pass "missing GitHub CLI does not expand pseudo-command text as a variable"
  fi
}

test_pre_push_policy() {
  local repo output rc zero
  repo="$(new_repo)"
  zero=0000000000000000000000000000000000000000
  set +e
  output="$(cd "$repo" && printf 'refs/heads/topic %040d refs/heads/main %s\n' 1 "$zero" | common/hooks/pre-push origin example 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "default main push is blocked" || fail "default main push is blocked"
  assert_contains "$output" "Protected branch: main" "blocked branch is visible"

  git -C "$repo" config --add agentskills.protectedPushBranch release
  set +e
  output="$(cd "$repo" && printf 'refs/heads/topic %040d refs/heads/main %s\n' 1 "$zero" | common/hooks/pre-push origin example 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "0" ]] && pass "configured policy replaces default branches" || fail "configured policy replaces default branches"
}

test_setup_conflict_and_force() {
  local repo output rc
  repo="$(new_repo)"
  git -C "$repo" config core.hooksPath existing/hooks
  set +e
  output="$(cd "$repo" && common/setup/setup-hooks.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "setup preserves an existing hooksPath" || fail "setup preserves an existing hooksPath"
  [[ "$(git -C "$repo" config core.hooksPath)" == "existing/hooks" ]] && pass "blocked setup leaves configuration unchanged" || fail "blocked setup leaves configuration unchanged"

  (cd "$repo" && common/setup/setup-hooks.sh --force) >/dev/null
  [[ "$(git -C "$repo" config core.hooksPath)" == "common/hooks" ]] && pass "forced setup installs common hooks" || fail "forced setup installs common hooks"
  [[ "$(git -C "$repo" config agentskills.kitPath)" == "common" ]] && pass "setup records logical kit path" || fail "setup records logical kit path"
}

test_deploy() {
  local repo conflict_repo symlink_repo output rc
  repo="$(new_target_repo)"
  output="$(bash "$SOURCE_COMMON/setup/deploy.sh" --claude --models "$repo" 2>&1)"
  [[ -L "$repo/.agentskills" ]] && pass "deploy creates kit symlink" || fail "deploy creates kit symlink"
  [[ "$(cd "$repo/.agentskills" && pwd -P)" == "$SOURCE_COMMON" ]] && pass "deploy symlink targets source kit" || fail "deploy symlink targets source kit"
  assert_contains "$(cat "$repo/AGENTS.md")" "AgentSkills Common Rules" "deploy adds AGENTS loader"
  assert_contains "$(cat "$repo/CLAUDE.md")" "AgentSkills Claude Rules" "deploy adds CLAUDE loader"
  [[ -f "$repo/SESSION_BRIEF.md" ]] && pass "deploy creates session brief" || fail "deploy creates session brief"
  [[ -f "$repo/.agents/WORKING_MEMORY.md" ]] && pass "deploy creates local working memory" || fail "deploy creates local working memory"
  git -C "$repo" check-ignore -q .agents/WORKING_MEMORY.md && pass "deploy excludes local working memory from Git status" || fail "deploy excludes local working memory from Git status"
  [[ -f "$repo/AGENT_MODELS.md" ]] && pass "deploy creates model template on request" || fail "deploy creates model template on request"
  assert_contains "$output" "[AgentSkills][DEPLOY][PASS] workflow-kit" "deploy reports completion"

  output="$(bash "$SOURCE_COMMON/setup/deploy.sh" --claude --models "$repo" 2>&1)"
  assert_contains "$output" "loader already present" "deploy is idempotent for managed loaders"
  assert_contains "$output" ".agentskills already links to this kit" "deploy is idempotent for kit link"

  conflict_repo="$(new_target_repo)"
  mkdir "$conflict_repo/.agentskills"
  set +e
  output="$(bash "$SOURCE_COMMON/setup/deploy.sh" "$conflict_repo" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "deploy preserves an existing kit directory" || fail "deploy preserves an existing kit directory"
  assert_contains "$output" "Existing .agentskills was not changed" "deploy conflict explains preservation"
  if grep -Fq "AgentSkills Common Rules" "$conflict_repo/AGENTS.md"; then
    fail "deploy conflict does not edit AGENTS.md"
  else
    pass "deploy conflict does not edit AGENTS.md"
  fi

  symlink_repo="$(new_target_repo_with_symlinked_agents)"
  set +e
  output="$(bash "$SOURCE_COMMON/setup/deploy.sh" "$symlink_repo" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "deploy rejects a symlinked AGENTS.md" || fail "deploy rejects a symlinked AGENTS.md"
  [[ ! -e "$symlink_repo/.agentskills" && ! -L "$symlink_repo/.agentskills" ]] && pass "failed loader preflight leaves no kit artifact" || fail "failed loader preflight leaves no kit artifact"
  assert_contains "$output" "Refusing to edit symlinked file: AGENTS.md" "symlinked loader failure is visible"
}

test_pseudo_command_execution_marker() {
  local rules help help_output help_last_line
  rules="$(cat "$SOURCE_COMMON/rules/AGENTS.base.md")"
  help="$(cat "$SOURCE_COMMON/prompts/workflow-help.md")"
  help_output="$(awk '
    /^```text$/ { inside = 1; next }
    inside && /^```$/ { exit }
    inside { print }
  ' "$SOURCE_COMMON/prompts/workflow-help.md")"
  help_last_line="$(printf '%s\n' "$help_output" | awk 'NF { last = $0 } END { print last }')"
  assert_contains "$rules" '[AgentSkills][EXECUTED] ::<command>' "rules define the pseudo-command execution marker"
  assert_contains "$rules" 'Its absence means execution was not confirmed' "rules do not treat a missing marker as failure"
  assert_contains "$help" '[AgentSkills][EXECUTED] ::help' "help defines its pseudo-command execution marker"
  [[ "$help_last_line" == '[AgentSkills][EXECUTED] ::help' ]] && pass "help display ends with its pseudo-command execution marker" || fail "help display ends with its pseudo-command execution marker"
}

test_workflow_resume_state() {
  local repo output rc state_file

  repo="$(new_repo)"
  printf 'pre-existing staged change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start sdd_tdd spec "SDD workflow request" 2>&1)"
  assert_contains "$output" "started sdd_tdd" "SDD workflow state starts"
  assert_contains "$output" "Next phase: spec" "SDD workflow state records the first phase"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start sdd_tdd spec "SDD workflow request" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "unfinished SDD workflow state blocks replacement" || fail "unfinished SDD workflow state blocks replacement"
  assert_contains "$output" "Unfinished sdd_tdd workflow state already exists" "unfinished SDD workflow state blocker is visible"
  assert_contains "$output" "::sdd_tdd <request>" "unfinished SDD workflow state recommends the default command"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance sdd_tdd gate 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "SDD workflow state blocks skipped phases" || fail "SDD workflow state blocks skipped phases"
  assert_contains "$output" "must advance from spec to test" "SDD skipped phase blocker identifies required transition"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance sdd_tdd test 2>&1)"
  assert_contains "$output" "Next phase: test" "SDD workflow state advances"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh show sdd_tdd "SDD workflow request" 2>&1)"
  assert_contains "$output" "resumable sdd_tdd workflow" "SDD workflow state is resumable"
  assert_contains "$output" "Next phase: test" "SDD resume uses the recorded next phase"
  assert_contains "$output" "app.txt" "SDD resume exposes initial staged paths"

  printf 'Changed brief after state capture.\n' >>"$repo/SESSION_BRIEF.md"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh show sdd_tdd "SDD workflow request" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "brief changes block SDD workflow resume" || fail "brief changes block SDD workflow resume"
  assert_contains "$output" "SESSION_BRIEF.md changed" "brief change blocker is visible"

  repo="$(new_repo)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Resolve workflow request" 2>&1)"
  assert_contains "$output" "started resolve" "resolve workflow state starts"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance resolve review 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "resolve workflow state blocks skipped phases" || fail "resolve workflow state blocks skipped phases"
  assert_contains "$output" "must advance from inspect to implement" "resolve skipped phase blocker identifies required transition"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance resolve implement 2>&1)"
  assert_contains "$output" "Next phase: implement" "resolve workflow state advances"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh show resolve "Resolve workflow request" 2>&1)"
  assert_contains "$output" "Next phase: implement" "resolve resume uses the recorded next phase"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh show resolve "Different resolve request" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "different resolve request blocks automatic resume" || fail "different resolve request blocks automatic resume"
  assert_contains "$output" "does not match the requested work" "different resolve request blocker is visible"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance resolve verify 2>&1)"
  assert_contains "$output" "Next phase: verify" "resolve workflow state advances to verify"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance resolve review 2>&1)"
  assert_contains "$output" "Next phase: review" "resolve workflow state advances to review"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance resolve gate 2>&1)"
  assert_contains "$output" "Next phase: gate" "resolve workflow state advances to gate"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh advance resolve complete 2>&1)"
  assert_contains "$output" "Next phase: complete" "resolve workflow state advances to complete"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh show resolve "Resolve workflow request" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "completed resolve workflow state is not resumable" || fail "completed resolve workflow state is not resumable"
  assert_contains "$output" "resolve is already complete" "completed resolve workflow state explains new start"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "New resolve workflow request" 2>&1)"
  assert_contains "$output" "started resolve" "completed resolve workflow state permits a new start"

  repo="$(new_repo)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Legacy resolve workflow request" 2>&1)"
  assert_contains "$output" "started resolve" "legacy test workflow state starts"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh discard-legacy resolve 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "identified resolve workflow state cannot be discarded as legacy" || fail "identified resolve workflow state cannot be discarded as legacy"
  assert_contains "$output" "has a request identity" "identified resolve workflow state explains discard refusal"
  state_file="$repo/.git/agentskills/workflows/resolve.state"
  grep -v '^request_hash=' "$state_file" >"$state_file.legacy"
  mv "$state_file.legacy" "$state_file"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh show resolve "Legacy resolve workflow request" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "legacy resolve workflow state blocks resume" || fail "legacy resolve workflow state blocks resume"
  assert_contains "$output" "discard-legacy resolve" "legacy resolve workflow state provides discard command"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh discard-legacy resolve 2>&1)"
  assert_contains "$output" "discarded legacy resolve workflow state" "legacy resolve workflow state can be explicitly discarded"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Replacement resolve workflow request" 2>&1)"
  assert_contains "$output" "started resolve" "discarded legacy resolve workflow state permits a new start"
}

test_resolve_reset() {
  local repo output rc state_file initial_staged_file archive_state archive_initial_staged before_status before_staged before_unstaged after_status after_staged after_unstaged

  repo="$(new_repo)"
  printf 'staged before reset\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  printf 'unstaged before reset\n' >>"$repo/app.txt"
  before_status="$(git -C "$repo" status --short)"
  before_staged="$(git -C "$repo" diff --cached --binary)"
  before_unstaged="$(git -C "$repo" diff --binary)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Identified resolve workflow request" 2>&1)"
  assert_contains "$output" "started resolve" "identified resolve workflow state starts for reset"
  state_file="$repo/.git/agentskills/workflows/resolve.state"
  initial_staged_file="$repo/.git/agentskills/workflows/resolve.initial-staged"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh reset resolve 2>&1)"
  assert_contains "$output" "Workflow: resolve" "reset displays workflow before archiving"
  assert_contains "$output" "Original request: Identified resolve workflow request" "reset displays identified original request"
  assert_contains "$output" "Next phase: inspect" "reset displays next phase"
  assert_contains "$output" "Recorded at:" "reset displays recorded time"
  assert_contains "$output" "app.txt" "reset displays initial staged paths"
  assert_contains "$output" "State: .git/agentskills/workflows/resolve.state" "reset displays state path"
  assert_contains "$output" "[AgentSkills][WORKFLOW-STATE][PASS] reset resolve workflow state" "identified resolve workflow state resets"
  [[ ! -e "$state_file" && ! -e "$initial_staged_file" ]] && pass "reset removes active resolve state files" || fail "reset removes active resolve state files"
  archive_state="$(find "$repo/.git/agentskills/workflows/archive" -name 'resolve-*.state' -type f -print -quit)"
  [[ -n "$archive_state" ]] && pass "reset archives identified resolve state" || fail "reset archives identified resolve state"
  grep -Fqx 'workflow=resolve' "$archive_state" && pass "reset archive preserves resolve state" || fail "reset archive preserves resolve state"
  archive_initial_staged="$(find "$repo/.git/agentskills/workflows/archive" -name 'resolve-*.initial-staged' -type f -print -quit)"
  [[ -n "$archive_initial_staged" ]] && pass "reset archives initial staged paths" || fail "reset archives initial staged paths"
  grep -Fqx 'app.txt' "$archive_initial_staged" && pass "reset archive preserves initial staged paths" || fail "reset archive preserves initial staged paths"
  after_status="$(git -C "$repo" status --short)"
  after_staged="$(git -C "$repo" diff --cached --binary)"
  after_unstaged="$(git -C "$repo" diff --binary)"
  [[ "$before_status" == "$after_status" && "$before_staged" == "$after_staged" && "$before_unstaged" == "$after_unstaged" ]] && pass "reset preserves Git worktree and staged changes" || fail "reset preserves Git worktree and staged changes"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Replacement after reset" 2>&1)"
  assert_contains "$output" "started resolve" "reset permits a new resolve workflow"

  repo="$(new_repo)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Legacy resolve workflow request" 2>&1)"
  assert_contains "$output" "started resolve" "legacy resolve workflow state starts for reset"
  state_file="$repo/.git/agentskills/workflows/resolve.state"
  grep -v -e '^request_hash=' -e '^request_b64=' "$state_file" >"$state_file.legacy"
  mv "$state_file.legacy" "$state_file"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh reset resolve 2>&1)"
  assert_contains "$output" "Request identity: <missing (legacy state)>" "reset displays legacy request identity status"
  assert_contains "$output" "reset resolve workflow state" "legacy resolve workflow state resets"
  [[ ! -e "$state_file" ]] && pass "reset removes legacy resolve state" || fail "reset removes legacy resolve state"

  repo="$(new_repo)"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh reset resolve 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "reset without state is a blocker" || fail "reset without state is a blocker"
  assert_contains "$output" "No resolve workflow state to reset" "reset without state explains no target"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh reset resolve --step 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "reset rejects step combination" || fail "reset rejects step combination"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh reset resolve "unexpected request" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "reset rejects request text" || fail "reset rejects request text"

  repo="$(new_repo)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start sdd_tdd spec "SDD workflow request" 2>&1)"
  assert_contains "$output" "started sdd_tdd" "SDD workflow state starts before rejected reset"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh reset sdd_tdd 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "2" ]] && pass "reset does not affect SDD workflow state" || fail "reset does not affect SDD workflow state"
  [[ -f "$repo/.git/agentskills/workflows/sdd_tdd.state" ]] && pass "rejected SDD reset preserves SDD state" || fail "rejected SDD reset preserves SDD state"
}

test_additional_workflow_commands() {
  local repo output rc checkpoint_dir

  repo="$(new_repo)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Resume request" 2>&1)"
  assert_contains "$output" "started resolve" "resume test workflow starts"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh resume resolve 2>&1)"
  assert_contains "$output" "Original request: Resume request" "resume restores original request"
  assert_contains "$output" "Next phase: inspect" "resume restores next phase"
  output="$(cd "$repo" && bash common/workflows/status.sh 2>&1)"
  assert_contains "$output" "Workflow: resolve" "status displays workflow"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh abort resolve 2>&1)"
  assert_contains "$output" "abort resolve workflow state" "abort archives resolve state"
  [[ ! -e "$repo/.git/agentskills/workflows/resolve.state" ]] && pass "abort removes active workflow state" || fail "abort removes active workflow state"

  printf 'checkpoint change\n' >>"$repo/app.txt"
  git -C "$repo" add app.txt
  output="$(cd "$repo" && bash common/workflows/checkpoint.sh before-publish 2>&1)"
  assert_contains "$output" "checkpoint created" "checkpoint reports success"
  checkpoint_dir="$(awk -F': ' '/^Checkpoint:/ { print $2 }' <<<"$output")"
  [[ "$checkpoint_dir" != /* ]] && checkpoint_dir="$repo/$checkpoint_dir"
  [[ -f "$checkpoint_dir/status.txt" && -f "$checkpoint_dir/staged.diff" ]] && pass "checkpoint captures Git state" || fail "checkpoint captures Git state"

  output="$(cd "$repo" && bash common/workflows/publish-state.sh record 77 https://github.com/example/repo/pull/77 2>&1)"
  assert_contains "$output" "recorded PR #77" "publish state records PR"
  output="$(cd "$repo" && bash common/workflows/publish-state.sh show 2>&1)"
  assert_contains "$output" "number=77" "publish state displays recorded PR"
  make_fake_gh "$repo"
  output="$(cd "$repo" && PATH="$repo/fake-bin:$ORIGINAL_PATH" common/reviewers/inspect-pull-request.sh 2>&1)"
  assert_contains "$output" "Using PR #77 recorded by ::publish" "PR inspection prefers recorded publish PR"

  repo="$(new_repo)"
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh start resolve inspect "Legacy resume request" 2>&1)"
  state_file="$repo/.git/agentskills/workflows/resolve.state"
  grep -v '^request_b64=' "$state_file" >"$state_file.legacy"
  mv "$state_file.legacy" "$state_file"
  set +e
  output="$(cd "$repo" && bash common/workflows/workflow-state.sh resume resolve 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == "1" ]] && pass "resume blocks state without stored request text" || fail "resume blocks state without stored request text"
  assert_contains "$output" "cannot resume without stored request text" "resume explains legacy blocker"
}

test_workflow_command_routes() {
  local rules help readme resolve_prompt sdd_prompt test_plan_prompt route command prompt expected command_syntax
  rules="$(cat "$SOURCE_COMMON/rules/AGENTS.base.md")"
  help="$(cat "$SOURCE_COMMON/prompts/workflow-help.md")"
  readme="$(cat "$SOURCE_COMMON/README.md")"
  for route in 'resolve:resolve.md' 'sdd_tdd:sdd_tdd.md' 'ui-mock:ui-mock.md' 'test-plan:test-plan.md'; do
    command="${route%%:*}"
    prompt="${route#*:}"
    [[ -f "$SOURCE_COMMON/prompts/$prompt" ]] && pass "$command prompt file exists" || fail "$command prompt file exists"
    command_syntax="::$command"
    [[ "$command" == "resolve" || "$command" == "sdd_tdd" ]] && command_syntax="::$command [--step] <request>"
    expected="| \`$command_syntax\` | \`.agentskills/prompts/$prompt\`"
    assert_contains "$rules" "$expected" "rules route $command to its prompt"
  done
  for prompt in status ask resume abort handoff inspect reproduce verify plan scope checkpoint publish sound; do
    [[ -f "$SOURCE_COMMON/prompts/$prompt.md" ]] && pass "$prompt prompt file exists" || fail "$prompt prompt file exists"
  done
  resolve_prompt="$(cat "$SOURCE_COMMON/prompts/resolve.md")"
  assert_contains "$resolve_prompt" '`::resolve <request>` is the default continuous mode' "resolve command defaults to continuous mode"
  assert_contains "$resolve_prompt" 'It does not create or update `SESSION_BRIEF.md` solely for this command' "resolve continuous mode preserves session brief ownership"
  assert_contains "$resolve_prompt" 'it never commits, pushes, or merges' "resolve continuous mode does not publish changes"
  assert_contains "$resolve_prompt" 'An individual gate check may emit `WARNING` for information' "resolve continuous mode distinguishes check warnings from final gate status"
  assert_contains "$resolve_prompt" '`::resolve --step <request>`' "resolve command defines step mode"
  assert_contains "$resolve_prompt" '`::resolve --reset` is the dedicated state-reset operation' "resolve prompt defines reset mode"
  assert_contains "$rules" '| `::resolve --reset` | `.agentskills/prompts/resolve.md` |' "rules expose resolve reset mode"
  assert_contains "$rules" '| `::publish [--loop]` | `.agentskills/prompts/publish.md` |' "rules expose publish mode"
  publish_prompt="$(cat "$SOURCE_COMMON/prompts/publish.md")"
  assert_contains "$publish_prompt" 'The original `::publish` invocation authorizes this publish operation' "publish does not require a second confirmation"
  assert_not_contains "$publish_prompt" 'Request explicit user confirmation' "publish removes the confirmation wait"
  assert_contains "$publish_prompt" '`::publish --loop`' "publish defines review loop mode"
  assert_contains "$publish_prompt" 'Repeat at most three remediation cycles' "publish review loop is bounded"
  assert_contains "$publish_prompt" 'do not create a second PR' "publish reuses the existing PR"
  assert_contains "$rules" '| `::ask <question>` | `.agentskills/prompts/ask.md` |' "rules expose ask mode"
  assert_contains "$rules" '| `::sound [<name>|--list]` | `.agentskills/prompts/sound.md` |' "rules expose sound mode"
  assert_contains "$help" '省略=全音を順に試聴。名前=通知音変更、--list=一覧' "help explains sound command options"
  assert_contains "$readme" '`::sound Ring02`' "README documents sound selection"
  assert_contains "$help" '::reproduce <不具合>' "help explains reproduce command"
  assert_contains "$help" '::ask <質問>' "help explains ask command"
  assert_contains "$help" '::publish --loop' "help explains publish review loop"
  assert_contains "$readme" '`::ask <質問>`は回答専用です。' "README documents ask command"
  assert_contains "$help" '条件・原因・期待動作が明確な修正  → ::resolve' "help explains reproduce and resolve selection"
  assert_contains "$help" '新機能・設計が未確定       → ::plan → （採用）→ ::sdd_tdd' "help defines the standard feature workflow"
  assert_contains "$readme" 'verifyは「動作が正しいか」、scopeは「変更範囲が正しいか」' "README distinguishes verify and scope"
  sdd_prompt="$(cat "$SOURCE_COMMON/prompts/sdd_tdd.md")"
  assert_contains "$sdd_prompt" 'required SDD specification artifact' "SDD and TDD command records its specification artifact"
  assert_contains "$sdd_prompt" 'Do not implement without the required SDD specification artifact and test evidence.' "SDD and TDD command requires test evidence before implementation"
  assert_contains "$sdd_prompt" '`::sdd_tdd <request>` is the default continuous mode' "SDD and TDD command defaults to continuous mode"
  assert_contains "$sdd_prompt" 'It never commits, pushes, merges' "continuous mode does not publish changes"
  assert_contains "$sdd_prompt" 'read `failure-analysis.md` and report the analysis only' "continuous mode analyzes failures without consecutive fixes"
  assert_contains "$sdd_prompt" 'An individual gate check may emit `WARNING` for information' "continuous mode distinguishes check warnings from final gate status"
  assert_contains "$sdd_prompt" 'final `GATE` or `HOOK` status is `BLOCKER` or `FAIL`' "continuous mode stops on failing final gate or hook status"
  assert_not_contains "$sdd_prompt" 'a test, review, gate, or hook reports `WARNING`, `BLOCKER`, or `FAIL`' "continuous mode does not stop on every informational warning"
  assert_contains "$sdd_prompt" '`::sdd_tdd --step <request>`' "SDD and TDD command defines step mode"
  assert_contains "$rules" '`::sdd_tdd [--step] <request>`' "rules expose the optional continuous step mode"
  test_plan_prompt="$(cat "$SOURCE_COMMON/prompts/test-plan.md")"
  assert_contains "$test_plan_prompt" 'Codex-compatible fallback' "test-plan defines the Codex fallback"
  assert_contains "$test_plan_prompt" 'instead of reporting `PROMPT BLOCKER`' "test-plan does not block Codex when the planner is unavailable"
  assert_contains "$rules" 'otherwise use the Codex-compatible fallback' "rules route unavailable planner work to the Codex fallback"
  if [[ "$rules" == *'converge-bugfix'* ]]; then
    fail "rules no longer expose the previous convergence command"
  else
    pass "rules no longer expose the previous convergence command"
  fi
}

printf 'TAP version 13\n'
test_status_consistency
test_evidence_required
test_manual_cache_and_invalidation
test_review_policy_and_nested_codex
test_staged_path_parsing
test_fallback_path
test_mechanical_gates
test_reviewer_timeout
test_successful_reviewer_cleans_watchdog
test_pull_request_inspection
test_pull_request_inspection_without_gh
test_pre_push_policy
test_setup_conflict_and_force
test_deploy
test_pseudo_command_execution_marker
test_workflow_resume_state
test_resolve_reset
test_additional_workflow_commands
test_workflow_command_routes

if ((FAIL_COUNT > 0)); then
  printf '# %d test assertions failed\n' "$FAIL_COUNT" >&2
  exit 1
fi
printf '# all %d assertions passed\n' "$PASS_COUNT"
