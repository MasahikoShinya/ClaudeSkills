#!/usr/bin/env bash
set -euo pipefail

if (($# != 0)); then
  echo "Usage: $0" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
STATE_DIR="$(git rev-parse --git-path agentskills/workflows)"

state_value() {
  local file="$1" key="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$file"
}

echo "[AgentSkills][STATUS][START]"
for workflow in resolve sdd_tdd; do
  state_file="$STATE_DIR/$workflow.state"
  if [[ -f "$state_file" ]]; then
    echo "Workflow: $workflow"
    echo "Next phase: $(state_value "$state_file" next_phase)"
    echo "Recorded at: $(state_value "$state_file" recorded_at)"
    echo "Request identity: $(state_value "$state_file" request_hash)"
    echo "State: $state_file"
  fi
done

publish_file="$(git rev-parse --git-path agentskills/publish/latest-pr)"
if [[ -f "$publish_file" ]]; then
  echo "Last published PR: $(awk -F= '$1 == "number" { print $2; exit }' "$publish_file")"
  echo "Last published at: $(awk -F= '$1 == "recorded_at" { print $2; exit }' "$publish_file")"
fi

echo "Git status:"
git status --short
echo "[AgentSkills][STATUS][PASS] status"
