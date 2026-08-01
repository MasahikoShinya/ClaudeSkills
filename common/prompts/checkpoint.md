# Checkpoint

Report `[AgentSkills][PROMPT][START] ::checkpoint` after reading this file. `::checkpoint <name>` requires a short ASCII name containing only letters, digits, dot, underscore, or hyphen. Run `bash .agentskills/workflows/checkpoint.sh <name>`. It records Git status, staged and unstaged diffs, HEAD, applicable briefs, Working Memory, and workflow state under `.git/agentskills/checkpoints/`. It must not modify source, worktree, stage, commits, branches, PRs, or Git configuration. Report the checkpoint path and `PROMPT END`.
