#!/usr/bin/env bash
set -euo pipefail

copy_mode=0
include_claude=0
install_hooks=0
create_models=0
target_path=""

usage() {
  cat <<'EOF'
Usage: deploy.sh [--copy] [--claude] [--install-hooks] [--models] TARGET_REPOSITORY

Deploy the AgentSkills common kit into an existing Git repository.

  --copy           Copy the kit instead of creating a symlink.
  --claude         Add the Claude Code loader block to CLAUDE.md.
  --install-hooks  Install Git hooks after deployment.
  --models         Create AGENT_MODELS.md when it does not exist.
EOF
}

while (($# > 0)); do
  case "$1" in
    --copy)
      copy_mode=1
      ;;
    --claude)
      include_claude=1
      ;;
    --install-hooks)
      install_hooks=1
      ;;
    --models)
      create_models=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "[AgentSkills][DEPLOY][FAIL] Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$target_path" ]]; then
        echo "[AgentSkills][DEPLOY][FAIL] TARGET_REPOSITORY must be specified once." >&2
        usage >&2
        exit 2
      fi
      target_path="$1"
      ;;
  esac
  shift
done

if [[ -z "$target_path" ]]; then
  echo "[AgentSkills][DEPLOY][FAIL] TARGET_REPOSITORY is required." >&2
  usage >&2
  exit 2
fi
if [[ ! -d "$target_path" ]]; then
  echo "[AgentSkills][DEPLOY][FAIL] Target directory not found: $target_path" >&2
  exit 2
fi
if ! git -C "$target_path" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "[AgentSkills][DEPLOY][BLOCKER] Target is not a Git repository: $target_path" >&2
  exit 1
fi

TARGET_ROOT="$(git -C "$target_path" rev-parse --show-toplevel)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

if [[ "$TARGET_ROOT" == "$KIT_ROOT" || "$TARGET_ROOT" == "$(cd "$KIT_ROOT/.." && pwd -P)" ]]; then
  echo "[AgentSkills][DEPLOY][BLOCKER] Target must be a separate repository." >&2
  exit 1
fi

validate_loader() {
  local file="$1"
  local title="$2"
  local begin="<!-- AgentSkills $title: BEGIN -->"
  local end="<!-- AgentSkills $title: END -->"

  if [[ -L "$file" ]]; then
    echo "[AgentSkills][DEPLOY][BLOCKER] Refusing to edit symlinked file: ${file#$TARGET_ROOT/}" >&2
    return 1
  fi
  if [[ -e "$file" ]] && [[ ! -f "$file" ]]; then
    echo "[AgentSkills][DEPLOY][BLOCKER] Expected a regular file: ${file#$TARGET_ROOT/}" >&2
    return 1
  fi
  if [[ -f "$file" ]] && grep -Fq "$begin" "$file"; then
    if ! grep -Fq "$end" "$file"; then
      echo "[AgentSkills][DEPLOY][BLOCKER] Incomplete managed block: ${file#$TARGET_ROOT/}" >&2
      return 1
    fi
  fi
}

ensure_loader() {
  local file="$1"
  local title="$2"
  local body="$3"
  local begin="<!-- AgentSkills $title: BEGIN -->"
  local end="<!-- AgentSkills $title: END -->"

  validate_loader "$file" "$title"
  if [[ -f "$file" ]] && grep -Fq "$begin" "$file"; then
    echo "[AgentSkills][DEPLOY][SKIP] ${file#$TARGET_ROOT/} loader already present"
    return 0
  fi

  if [[ ! -e "$file" ]]; then
    printf '# %s\n' "$title" >"$file"
  fi
  printf '\n%s\n%s\n%s\n' "$begin" "$body" "$end" >>"$file"
  echo "[AgentSkills][DEPLOY][PASS] ${file#$TARGET_ROOT/} loader added"
}

echo "[AgentSkills][DEPLOY][START] workflow-kit"
echo "Source: $KIT_ROOT"
echo "Target: $TARGET_ROOT"

agents_body='## AgentSkills Common Rules

Before starting AgentSkills workflow work, read and follow `.agentskills/rules/AGENTS.base.md`.
Use `::help` to display the available pseudo-commands and execution evidence.'
validate_loader "$TARGET_ROOT/AGENTS.md" "Common Rules"

if ((include_claude == 1)); then
  claude_body='## AgentSkills Claude Rules

Read and follow `.agentskills/rules/CLAUDE.base.md` together with the project-root `AGENTS.md`.'
  validate_loader "$TARGET_ROOT/CLAUDE.md" "Claude Rules"
fi

kit_target="$TARGET_ROOT/.agentskills"
if [[ -e "$kit_target" || -L "$kit_target" ]]; then
  if [[ -L "$kit_target" ]] && [[ "$(cd "$kit_target" && pwd -P)" == "$KIT_ROOT" ]]; then
    echo "[AgentSkills][DEPLOY][SKIP] .agentskills already links to this kit"
  else
    echo "[AgentSkills][DEPLOY][BLOCKER] Existing .agentskills was not changed: $kit_target" >&2
    echo "Resolution: Move it aside or deploy to a repository without an existing .agentskills directory." >&2
    exit 1
  fi
elif ((copy_mode == 1)); then
  cp -R "$KIT_ROOT" "$kit_target"
  echo "[AgentSkills][DEPLOY][PASS] .agentskills copied"
else
  ln -s "$KIT_ROOT" "$kit_target"
  echo "[AgentSkills][DEPLOY][PASS] .agentskills linked"
fi

ensure_loader "$TARGET_ROOT/AGENTS.md" "Common Rules" "$agents_body"

if ((include_claude == 1)); then
  ensure_loader "$TARGET_ROOT/CLAUDE.md" "Claude Rules" "$claude_body"
fi

if [[ -e "$TARGET_ROOT/SESSION_BRIEF.md" ]]; then
  echo "[AgentSkills][DEPLOY][SKIP] SESSION_BRIEF.md already exists"
else
  cp "$KIT_ROOT/briefs/SESSION_BRIEF.template.md" "$TARGET_ROOT/SESSION_BRIEF.md"
  echo "[AgentSkills][DEPLOY][PASS] SESSION_BRIEF.md created"
  echo "Action: Fill only confirmed scope and verification before Convergence work."
fi

working_memory_dir="$TARGET_ROOT/.agents"
working_memory_path="$working_memory_dir/WORKING_MEMORY.md"
if [[ -e "$working_memory_path" ]]; then
  echo "[AgentSkills][DEPLOY][SKIP] .agents/WORKING_MEMORY.md already exists"
else
  mkdir -p "$working_memory_dir"
  cp "$KIT_ROOT/briefs/WORKING_MEMORY.template.md" "$working_memory_path"
  echo "[AgentSkills][DEPLOY][PASS] .agents/WORKING_MEMORY.md created"
fi

local_exclude="$TARGET_ROOT/.git/info/exclude"
working_memory_exclude='/.agents/WORKING_MEMORY.md'
if [[ -f "$local_exclude" ]] && grep -Fqx "$working_memory_exclude" "$local_exclude"; then
  echo "[AgentSkills][DEPLOY][SKIP] local exclude already covers .agents/WORKING_MEMORY.md"
else
  printf '\n# AgentSkills local working memory\n%s\n' "$working_memory_exclude" >>"$local_exclude"
  echo "[AgentSkills][DEPLOY][PASS] .agents/WORKING_MEMORY.md excluded from Git status"
fi

if ((create_models == 1)); then
  if [[ -e "$TARGET_ROOT/AGENT_MODELS.md" ]]; then
    echo "[AgentSkills][DEPLOY][SKIP] AGENT_MODELS.md already exists"
  else
    cp "$KIT_ROOT/config/AGENT_MODELS.template.md" "$TARGET_ROOT/AGENT_MODELS.md"
    echo "[AgentSkills][DEPLOY][PASS] AGENT_MODELS.md created"
  fi
fi

if ((install_hooks == 1)); then
  echo "[AgentSkills][DEPLOY][START] install-hooks"
  (cd "$TARGET_ROOT" && bash .agentskills/setup/setup-hooks.sh)
  echo "[AgentSkills][DEPLOY][PASS] install-hooks"
else
  echo "[AgentSkills][DEPLOY][SKIP] install-hooks"
  echo "Run: (cd \"$TARGET_ROOT\" && bash .agentskills/setup/setup-hooks.sh)"
fi

echo "[AgentSkills][DEPLOY][PASS] workflow-kit"
echo 'Next: Open the target repository in Codex or Claude Code, then send ::help.'
