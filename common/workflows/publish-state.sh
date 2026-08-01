#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 record <PR-number> <PR-url>" >&2
  echo "       $0 show" >&2
}

action="${1:-}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
STATE_FILE="$(git rev-parse --git-path agentskills/publish/latest-pr)"

case "$action" in
  record)
    [[ $# == 3 && "$2" =~ ^[0-9]+$ ]] || { usage; exit 2; }
    mkdir -p "$(dirname "$STATE_FILE")"
    temporary="$STATE_FILE.tmp.$$"
    {
      printf 'number=%s\n' "$2"
      printf 'url=%s\n' "$3"
      printf 'head=%s\n' "$(git branch --show-current)"
      printf 'recorded_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    } >"$temporary"
    mv "$temporary" "$STATE_FILE"
    echo "[AgentSkills][PUBLISH][PASS] recorded PR #$2"
    ;;
  show)
    [[ $# == 1 ]] || { usage; exit 2; }
    if [[ ! -f "$STATE_FILE" ]]; then
      echo "[AgentSkills][PUBLISH][BLOCKER] No published PR is recorded" >&2
      exit 1
    fi
    cat "$STATE_FILE"
    ;;
  *)
    usage
    exit 2
    ;;
esac
