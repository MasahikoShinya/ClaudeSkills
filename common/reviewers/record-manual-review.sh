#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/review-common.sh
source "$KIT_ROOT/lib/review-common.sh"

runtime=""
status=""
while (($# > 0)); do
  case "$1" in
    --runtime)
      runtime="${2:-}"
      shift 2
      ;;
    --status)
      status="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: $0 --runtime <name> --status OK" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$runtime" || "$status" != "OK" ]]; then
  echo "[AgentSkills][MANUAL-REVIEW][BLOCKER] Invalid attestation" >&2
  echo "Usage: $0 --runtime <name> --status OK" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1 || ! agentskills_require_hash_command; then
  echo "[AgentSkills][MANUAL-REVIEW][FAIL] jq and a SHA-256 command are required" >&2
  exit 3
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
if git diff --cached --quiet --exit-code; then
  echo "[AgentSkills][MANUAL-REVIEW][BLOCKER] No staged diff" >&2
  exit 2
fi

line_limit="$(git config --local --get agentskills.reviewEscalateLines || true)"
file_limit="$(git config --local --get agentskills.reviewEscalateFiles || true)"
line_limit="${line_limit:-300}"
file_limit="${file_limit:-10}"
agentskills_collect_staged_risk "$line_limit" "$file_limit"
escalated="$AGENTSKILLS_REVIEW_ESCALATE"
if ! review_policy="$(agentskills_review_policy)"; then
  echo "[AgentSkills][MANUAL-REVIEW][BLOCKER] Invalid review policy" >&2
  echo "Reason: agentskills.reviewPolicy must be auto or independent." >&2
  exit 2
fi
diff_hash="$(agentskills_hash_staged_diff)"
context_fingerprint="$(agentskills_context_fingerprint "$repo_root" "$KIT_ROOT" "$escalated" "$line_limit" "$file_limit" "$review_policy")"
cache_dir="$(git rev-parse --git-path agentskills/reviews)/$context_fingerprint"
runtime_name="$(agentskills_safe_cache_component "$runtime")"
cache_file="$cache_dir/manual-$runtime_name.json"
mkdir -p "$cache_dir"

jq -n \
  --arg model "manual:$runtime" \
  --arg hash "$diff_hash" \
  --arg review_kind "$([[ "$runtime" == "codex-self-review" ]] && printf 'Self review' || printf 'Manual independent review')" \
  '{
    status: "OK",
    summary: ($review_kind + " attested for staged diff " + $hash),
    model: $model,
    escalate: false,
    findings: []
  }' >"$cache_file"

if [[ "$runtime" == "codex-self-review" ]]; then
  echo "[AgentSkills][SELF-REVIEW][OK] staged-diff"
  echo "Runtime: Codex current session"
else
  echo "[AgentSkills][MANUAL-REVIEW][PASS] staged-diff"
  echo "Runtime: $runtime"
fi
echo "Diff hash: $diff_hash"
echo "Context fingerprint: $context_fingerprint"
echo "Review policy: $review_policy"
echo "Recorded: $cache_file"
