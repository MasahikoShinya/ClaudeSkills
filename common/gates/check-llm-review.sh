#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../lib/review-common.sh
source "$KIT_ROOT/lib/review-common.sh"
cd "$REPO_ROOT"

echo "[AgentSkills][CHECK][START] llm-review"
if git diff --cached --quiet --exit-code; then
  echo "[AgentSkills][CHECK][SKIP] llm-review"
  echo "Reason: No staged diff."
  exit 0
fi
if ! agentskills_require_hash_command; then
  echo "[AgentSkills][CHECK][FAIL] llm-review" >&2
  echo "Reason: sha256sum, shasum, or openssl is required." >&2
  exit 1
fi

diff_hash="$(agentskills_hash_staged_diff)"
if [[ "${AGENTSKILLS_SKIP_LLM_REVIEW:-0}" == "1" ]]; then
  echo "[AgentSkills][LLM-REVIEW][SKIP] staged-diff"
  echo "Reason: AGENTSKILLS_SKIP_LLM_REVIEW=1 was explicitly set."
  echo "Diff hash: $diff_hash"
  echo "Warning: This result is not cached. Mechanical checks still ran."
  exit 0
fi

line_limit="$(git config --local --get agentskills.reviewEscalateLines || true)"
file_limit="$(git config --local --get agentskills.reviewEscalateFiles || true)"
line_limit="${line_limit:-300}"
file_limit="${file_limit:-10}"
agentskills_collect_staged_risk "$line_limit" "$file_limit"

echo "Changed files: $AGENTSKILLS_CHANGED_FILES"
echo "Changed lines: $AGENTSKILLS_CHANGED_LINES"
if ((AGENTSKILLS_REVIEW_ESCALATE == 1)); then
  echo "[AgentSkills][MODEL][WARNING] Review escalation"
  printf 'Reason: %s\n' "${AGENTSKILLS_RISK_REASONS[@]}"
fi

set +e
AGENTSKILLS_REVIEW_ESCALATED="$AGENTSKILLS_REVIEW_ESCALATE" "$KIT_ROOT/reviewers/review-staged-diff.sh"
rc=$?
set -e

case "$rc" in
  0)
    echo "[AgentSkills][CHECK][PASS] llm-review"
    ;;
  2)
    echo "[AgentSkills][CHECK][BLOCKER] llm-review" >&2
    exit 1
    ;;
  *)
    configured_kit_path="$(git config --local --get agentskills.kitPath || true)"
    configured_kit_path="${configured_kit_path:-$KIT_ROOT}"
    echo "[AgentSkills][CHECK][FAIL] llm-review" >&2
    echo "" >&2
    echo "Option 1 - Review manually in Claude Code:" >&2
    echo '  ::subagent-review SESSION_BRIEF.md と git diff --cached を根拠にレビューし、コードは変更しない。' >&2
    printf '  bash %q/reviewers/record-manual-review.sh --runtime claude --status OK\n' "$configured_kit_path" >&2
    echo "  git commit" >&2
    echo "" >&2
    echo "Option 2 - Skip LLM review once:" >&2
    echo "  AGENTSKILLS_SKIP_LLM_REVIEW=1 git commit" >&2
    echo "" >&2
    echo "Mechanical gate checks will still run." >&2
    exit 1
    ;;
esac
