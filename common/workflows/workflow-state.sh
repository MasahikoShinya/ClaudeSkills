#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 start <resolve|sdd_tdd> <initial-phase> <request>" >&2
  echo "       $0 advance <resolve|sdd_tdd> <next-phase>" >&2
  echo "       $0 show <resolve|sdd_tdd> <request>" >&2
  echo "       $0 resume <resolve|sdd_tdd>" >&2
  echo "       $0 discard-legacy <resolve|sdd_tdd>" >&2
  echo "       $0 reset resolve" >&2
  echo "       $0 abort <resolve|sdd_tdd>" >&2
}

action="${1:-}"
workflow="${2:-}"
phase="${3:-}"
request="${4:-}"

case "$action" in
  start)
    [[ $# == 4 ]] || { usage; exit 2; }
    ;;
  advance)
    [[ $# == 3 ]] || { usage; exit 2; }
    ;;
  show)
    [[ $# == 3 ]] || { usage; exit 2; }
    request="$phase"
    phase=""
    ;;
  resume|abort)
    [[ $# == 2 ]] || { usage; exit 2; }
    ;;
  discard-legacy)
    [[ $# == 2 ]] || { usage; exit 2; }
    ;;
  reset)
    [[ $# == 2 ]] || { usage; exit 2; }
    ;;
  *)
    usage
    exit 2
    ;;
esac

case "$workflow" in
  resolve|sdd_tdd) ;;
  *)
    echo "[AgentSkills][WORKFLOW-STATE][FAIL] Unknown workflow: $workflow" >&2
    exit 2
    ;;
esac

valid_phase() {
  case "$1:$2" in
    sdd_tdd:spec|sdd_tdd:test|sdd_tdd:implement|sdd_tdd:review|sdd_tdd:gate|sdd_tdd:complete) return 0 ;;
    resolve:inspect|resolve:implement|resolve:verify|resolve:review|resolve:gate|resolve:complete) return 0 ;;
    *) return 1 ;;
  esac
}

expected_next_phase() {
  case "$1:$2" in
    sdd_tdd:spec) printf 'test\n' ;;
    sdd_tdd:test) printf 'implement\n' ;;
    sdd_tdd:implement) printf 'review\n' ;;
    sdd_tdd:review) printf 'gate\n' ;;
    sdd_tdd:gate) printf 'complete\n' ;;
    resolve:inspect) printf 'implement\n' ;;
    resolve:implement) printf 'verify\n' ;;
    resolve:verify) printf 'review\n' ;;
    resolve:review) printf 'gate\n' ;;
    resolve:gate) printf 'complete\n' ;;
    *) return 1 ;;
  esac
}

if [[ "$action" == "start" ]]; then
  expected_phase="inspect"
  [[ "$workflow" == "sdd_tdd" ]] && expected_phase="spec"
  if [[ "$phase" != "$expected_phase" ]]; then
    echo "[AgentSkills][WORKFLOW-STATE][FAIL] start phase for $workflow must be $expected_phase" >&2
    exit 2
  fi
elif [[ "$action" == "advance" ]]; then
  if [[ -z "$phase" ]] || ! valid_phase "$workflow" "$phase"; then
    echo "[AgentSkills][WORKFLOW-STATE][FAIL] Invalid next phase for $workflow: ${phase:-<missing>}" >&2
    exit 2
  fi
elif { [[ "$action" != "show" ]] && [[ "$action" != "resume" ]] && [[ "$action" != "discard-legacy" ]] && [[ "$action" != "reset" ]] && [[ "$action" != "abort" ]]; } || [[ -n "$phase" ]]; then
  usage
  exit 2
fi

if [[ "$action" == "reset" && "$workflow" != "resolve" ]]; then
  echo "[AgentSkills][WORKFLOW-STATE][FAIL] reset is supported only for resolve" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
STATE_DIR="$(git rev-parse --git-path agentskills/workflows)"
STATE_FILE="$STATE_DIR/$workflow.state"
INITIAL_STAGED_FILE="$STATE_DIR/$workflow.initial-staged"
ARCHIVE_DIR="$STATE_DIR/archive"

hash_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf 'missing\n'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    echo "[AgentSkills][WORKFLOW-STATE][FAIL] sha256sum, shasum, or openssl is required" >&2
    exit 2
  fi
}

hash_text() {
  local value="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "$value" | openssl dgst -sha256 | awk '{print $NF}'
  else
    echo "[AgentSkills][WORKFLOW-STATE][FAIL] sha256sum, shasum, or openssl is required" >&2
    exit 2
  fi
}

encode_request() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

decode_request() {
  if base64 --decode >/dev/null 2>&1 <<<''; then
    printf '%s' "$1" | base64 --decode
  else
    printf '%s' "$1" | base64 -D
  fi
}

state_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$STATE_FILE"
}

validate_state_workflow() {
  if [[ "$(state_value workflow)" != "$workflow" ]]; then
    echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] Workflow state does not match the requested command" >&2
    exit 1
  fi
}

validate_resumable_phase() {
  local recorded_phase
  recorded_phase="$(state_value next_phase)"
  if ! valid_phase "$workflow" "$recorded_phase"; then
    echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] Workflow state has an invalid next phase: ${recorded_phase:-<missing>}" >&2
    exit 1
  fi
  printf '%s\n' "$recorded_phase"
}

validate_request_match() {
  local stored_request_hash current_request_hash
  stored_request_hash="$(state_value request_hash)"
  current_request_hash="$(hash_text "$request")"
  if [[ -z "$stored_request_hash" || "$stored_request_hash" != "$current_request_hash" ]]; then
    echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] Workflow state does not match the requested work" >&2
    echo "Reason: An unfinished workflow can resume only with its original request text." >&2
    echo "Resolution: Continue the active request, or resolve its state before starting different work." >&2
    exit 1
  fi
}

legacy_state_resolution() {
  echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] Legacy $workflow workflow state has no request identity" >&2
  echo "Resolution: Review the active work, then explicitly discard the legacy state with:" >&2
  echo "  $0 discard-legacy $workflow" >&2
  exit 1
}

write_state() {
  local next_phase="$1"
  local initial_file="$2"
  local request_hash="$3"
  local request_b64="$4"
  local temporary
  temporary="$STATE_FILE.tmp.$$"
  {
    printf 'schema=2\n'
    printf 'workflow=%s\n' "$workflow"
    printf 'next_phase=%s\n' "$next_phase"
    printf 'head=%s\n' "$(git rev-parse HEAD)"
    printf 'brief_hash=%s\n' "$(hash_file "$REPO_ROOT/SESSION_BRIEF.md")"
    printf 'request_hash=%s\n' "$request_hash"
    printf 'request_b64=%s\n' "$request_b64"
    printf 'initial_staged_file=%s\n' "$initial_file"
    printf 'recorded_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } >"$temporary"
  mv "$temporary" "$STATE_FILE"
}

display_state_for_archive() {
  local request_identity recorded_phase recorded_at request_text
  recorded_phase="$(state_value next_phase)"
  request_identity="$(state_value request_hash)"
  recorded_at="$(state_value recorded_at)"
  request_text="$(state_value request_b64)"
  echo "Workflow: $workflow"
  if [[ -n "$request_text" ]]; then
    echo "Original request: $(decode_request "$request_text")"
  elif [[ -n "$request_identity" ]]; then
    echo "Request identity: $request_identity"
  else
    echo "Request identity: <missing (legacy state)>"
  fi
  echo "Next phase: ${recorded_phase:-<missing>}"
  echo "Recorded at: ${recorded_at:-<missing>}"
  echo "Initial staged paths: $INITIAL_STAGED_FILE"
  if [[ -s "$INITIAL_STAGED_FILE" ]]; then
    sed 's/^/  /' "$INITIAL_STAGED_FILE"
  else
    echo "  <none>"
  fi
  echo "State: $STATE_FILE"
}

archive_and_remove_state() {
  local archive_base archive_state archive_initial_staged archive_suffix
  mkdir -p "$ARCHIVE_DIR"
  archive_base="$ARCHIVE_DIR/$workflow-$(date -u '+%Y%m%dT%H%M%SZ')"
  archive_state="$archive_base.state"
  archive_initial_staged="$archive_base.initial-staged"
  archive_suffix=1
  while [[ -e "$archive_state" || -e "$archive_initial_staged" ]]; do
    archive_state="$archive_base-$archive_suffix.state"
    archive_initial_staged="$archive_base-$archive_suffix.initial-staged"
    archive_suffix=$((archive_suffix + 1))
  done
  cp "$STATE_FILE" "$archive_state"
  if [[ -f "$INITIAL_STAGED_FILE" ]]; then
    cp "$INITIAL_STAGED_FILE" "$archive_initial_staged"
  fi
  rm -f "$STATE_FILE" "$INITIAL_STAGED_FILE"
  echo "Archived state: $archive_state"
  [[ -e "$archive_initial_staged" ]] && echo "Archived initial staged paths: $archive_initial_staged"
}

case "$action" in
  start)
    mkdir -p "$STATE_DIR"
    if [[ -f "$STATE_FILE" ]]; then
      validate_state_workflow
      recorded_phase="$(validate_resumable_phase)"
      if [[ "$recorded_phase" != "complete" ]]; then
        echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] Unfinished $workflow workflow state already exists" >&2
        echo "Run ::$workflow <request> to continue from its recorded next phase." >&2
        exit 1
      fi
    fi
    git diff --cached --name-only --no-ext-diff >"$INITIAL_STAGED_FILE"
    write_state "$phase" "$INITIAL_STAGED_FILE" "$(hash_text "$request")" "$(encode_request "$request")"
    echo "[AgentSkills][WORKFLOW-STATE][PASS] started $workflow"
    echo "Next phase: $phase"
    echo "State: $STATE_FILE"
    echo "Initial staged paths: $INITIAL_STAGED_FILE"
    ;;
  advance)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] No resumable $workflow workflow state" >&2
      echo "Start a new workflow with the matching pseudo-command, or inspect the requested phase manually." >&2
      exit 1
    fi
    validate_state_workflow
    recorded_phase="$(validate_resumable_phase)"
    expected_phase="$(expected_next_phase "$workflow" "$recorded_phase" || true)"
    if [[ -z "$expected_phase" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] $workflow is already complete; start a new workflow instead of advancing it" >&2
      exit 1
    fi
    if [[ "$phase" != "$expected_phase" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] $workflow must advance from $recorded_phase to $expected_phase, not $phase" >&2
      exit 1
    fi
    write_state "$phase" "$(state_value initial_staged_file)" "$(state_value request_hash)" "$(state_value request_b64)"
    echo "[AgentSkills][WORKFLOW-STATE][PASS] advanced $workflow"
    echo "Next phase: $phase"
    echo "State: $STATE_FILE"
    ;;
  show)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] No resumable $workflow workflow state" >&2
      echo "Use ::$workflow <request> to start a new workflow." >&2
      exit 1
    fi
    validate_state_workflow
    recorded_phase="$(validate_resumable_phase)"
    if [[ "$recorded_phase" == "complete" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] $workflow is already complete" >&2
      echo "Start a new workflow with ::$workflow <request>." >&2
      exit 1
    fi
    if [[ -z "$(state_value request_hash)" ]]; then
      legacy_state_resolution
    fi
    validate_request_match
    stored_brief_hash="$(state_value brief_hash)"
    current_brief_hash="$(hash_file "$REPO_ROOT/SESSION_BRIEF.md")"
    if [[ "$stored_brief_hash" != "$current_brief_hash" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] SESSION_BRIEF.md changed after the recorded phase" >&2
      echo "Recorded hash: $stored_brief_hash" >&2
      echo "Current hash: $current_brief_hash" >&2
      echo "Inspect and reconcile the brief before resuming." >&2
      exit 1
    fi
    echo "[AgentSkills][WORKFLOW-STATE][PASS] resumable $workflow workflow"
    echo "Next phase: $(state_value next_phase)"
    echo "Recorded head: $(state_value head)"
    echo "State: $STATE_FILE"
    echo "Initial staged paths: $(state_value initial_staged_file)"
    if [[ -s "$(state_value initial_staged_file)" ]]; then
      sed 's/^/  /' "$(state_value initial_staged_file)"
    else
      echo "  <none>"
    fi
    ;;
  resume)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] No resumable $workflow workflow state" >&2
      exit 1
    fi
    validate_state_workflow
    recorded_phase="$(validate_resumable_phase)"
    if [[ "$recorded_phase" == "complete" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] $workflow is already complete" >&2
      exit 1
    fi
    request_b64="$(state_value request_b64)"
    if [[ -z "$request_b64" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] $workflow state cannot resume without stored request text" >&2
      echo "Resolution: Use the original ::$workflow <request>, or explicitly reset or abort the state." >&2
      exit 1
    fi
    stored_brief_hash="$(state_value brief_hash)"
    current_brief_hash="$(hash_file "$REPO_ROOT/SESSION_BRIEF.md")"
    if [[ "$stored_brief_hash" != "$current_brief_hash" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] SESSION_BRIEF.md changed after the recorded phase" >&2
      exit 1
    fi
    echo "[AgentSkills][WORKFLOW-STATE][PASS] resumable $workflow workflow"
    echo "Original request: $(decode_request "$request_b64")"
    echo "Next phase: $recorded_phase"
    echo "State: $STATE_FILE"
    ;;
  discard-legacy)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] No legacy $workflow workflow state to discard" >&2
      exit 1
    fi
    validate_state_workflow
    if [[ -n "$(state_value request_hash)" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] $workflow state has a request identity and cannot be discarded as legacy" >&2
      echo "Resolution: Resume it with the original request text." >&2
      exit 1
    fi
    rm -f "$STATE_FILE" "$INITIAL_STAGED_FILE"
    echo "[AgentSkills][WORKFLOW-STATE][PASS] discarded legacy $workflow workflow state"
    ;;
  reset|abort)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "[AgentSkills][WORKFLOW-STATE][BLOCKER] No $workflow workflow state to $action" >&2
      echo "State: $STATE_FILE" >&2
      exit 1
    fi
    validate_state_workflow
    display_state_for_archive
    archive_and_remove_state
    echo "[AgentSkills][WORKFLOW-STATE][PASS] $action $workflow workflow state"
    ;;
esac
