#!/usr/bin/env bash
set -euo pipefail

if (($# > 1)); then
  echo "Usage: $0 [<PR-number-or-URL>]" >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[AgentSkills][PR-REVIEW][FAIL] GitHub CLI not found" >&2
  echo 'Reason: ::pr-reviewには、PR metadata と diff を確認する認証済みの gh が必要です。' >&2
  exit 3
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[AgentSkills][PR-REVIEW][FAIL] jq not found" >&2
  exit 3
fi

pr_ref="${1:-}"
if [[ -z "$pr_ref" ]]; then
  publish_state="$(git rev-parse --git-path agentskills/publish/latest-pr)"
  if [[ -f "$publish_state" ]]; then
    published_number="$(awk -F= '$1 == "number" { print $2; exit }' "$publish_state")"
    if [[ "$published_number" =~ ^[0-9]+$ ]]; then
      pr_ref="$published_number"
      echo "[AgentSkills][PR-REVIEW][INFO] Using PR #$published_number recorded by ::publish"
    fi
  fi
fi
view_args=(pr view)
[[ -n "$pr_ref" ]] && view_args+=("$pr_ref")
view_args+=(--json number,url,title,state,isDraft,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision)

set +e
metadata="$(gh "${view_args[@]}" 2>&1)"
metadata_rc=$?
set -e
if ((metadata_rc != 0)); then
  if [[ -z "$pr_ref" ]]; then
    fallback_ref="$(gh pr list --author @me --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || true)"
    if [[ "$fallback_ref" =~ ^[0-9]+$ ]]; then
      echo "[AgentSkills][PR-REVIEW][INFO] Using your most recently updated open PR #$fallback_ref"
      metadata="$(gh pr view "$fallback_ref" --json number,url,title,state,isDraft,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision 2>&1)" || true
      pr_ref="$fallback_ref"
    fi
  fi
  if [[ -z "$metadata" || "$metadata" != \{* ]]; then
    echo "[AgentSkills][PR-REVIEW][BLOCKER] PR metadata unavailable" >&2
    echo "Reason: $metadata" >&2
    echo "Resolution: Authenticate gh with 'gh auth login', verify repository access, and confirm the PR number or URL." >&2
    exit 2
  fi
fi
number="$(jq -r '.number' <<<"$metadata")"
url="$(jq -r '.url' <<<"$metadata")"

echo "[AgentSkills][PR-REVIEW][START] #$number"
echo "URL: $url"
echo "Title: $(jq -r '.title' <<<"$metadata")"
echo "State: $(jq -r '.state' <<<"$metadata")"
echo "Draft: $(jq -r '.isDraft' <<<"$metadata")"
echo "Base: $(jq -r '.baseRefName' <<<"$metadata")"
echo "Head: $(jq -r '.headRefName' <<<"$metadata")"
echo "Mergeable: $(jq -r '.mergeable' <<<"$metadata")"
echo "Merge state: $(jq -r '.mergeStateStatus' <<<"$metadata")"
echo "Review decision: $(jq -r 'if .reviewDecision == null or .reviewDecision == "" then "none" else .reviewDecision end' <<<"$metadata")"

set +e
checks="$(gh pr checks "$number" 2>&1)"
checks_rc=$?
set -e
if ((checks_rc == 0)); then
  echo "[AgentSkills][PR-REVIEW][PASS] checks"
elif [[ "$checks" == *"no checks reported"* ]]; then
  echo "[AgentSkills][PR-REVIEW][SKIP] checks"
  echo "Reason: No checks are configured for this PR branch."
else
  echo "[AgentSkills][PR-REVIEW][WARNING] checks"
fi
printf '%s\n' "$checks"

echo "Changed files:"
set +e
changed_files="$(gh pr diff "$number" --name-only 2>&1)"
changed_files_rc=$?
set -e
if ((changed_files_rc != 0)); then
  echo "[AgentSkills][PR-REVIEW][BLOCKER] PR diff unavailable" >&2
  echo "Reason: $changed_files" >&2
  echo "Resolution: Verify gh authentication, repository access, and PR availability before retrying." >&2
  exit 2
fi
printf '%s\n' "$changed_files"
echo "Review diff with: gh pr diff $number"
echo "[AgentSkills][PR-REVIEW][PASS] inspection"
