#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "Usage: $0 <name>" >&2
  exit 2
fi

name="$1"
if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "[AgentSkills][CHECKPOINT][FAIL] Name must contain only ASCII letters, digits, dot, underscore, or hyphen" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
CHECKPOINT_ROOT="$(git rev-parse --git-path agentskills/checkpoints)"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
checkpoint_dir="$CHECKPOINT_ROOT/$timestamp-$name"
suffix=1
while [[ -e "$checkpoint_dir" ]]; do
  checkpoint_dir="$CHECKPOINT_ROOT/$timestamp-$name-$suffix"
  suffix=$((suffix + 1))
done
mkdir -p "$checkpoint_dir"

git status --short >"$checkpoint_dir/status.txt"
git diff --binary >"$checkpoint_dir/unstaged.diff"
git diff --cached --binary >"$checkpoint_dir/staged.diff"
git rev-parse HEAD >"$checkpoint_dir/head.txt"
if [[ -f SESSION_BRIEF.md ]]; then cp SESSION_BRIEF.md "$checkpoint_dir/SESSION_BRIEF.md"; fi
if [[ -f .agents/WORKING_MEMORY.md ]]; then cp .agents/WORKING_MEMORY.md "$checkpoint_dir/WORKING_MEMORY.md"; fi
STATE_DIR="$(git rev-parse --git-path agentskills/workflows)"
for file in "$STATE_DIR"/*.state "$STATE_DIR"/*.initial-staged; do
  [[ -f "$file" ]] && cp "$file" "$checkpoint_dir/"
done

echo "Checkpoint: $checkpoint_dir"
echo "[AgentSkills][CHECKPOINT][PASS] checkpoint created"
