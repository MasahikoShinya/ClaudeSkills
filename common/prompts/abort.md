# Abort

Report `[AgentSkills][PROMPT][START] ::abort` after reading this file. Inspect `bash .agentskills/workflows/status.sh`. If exactly one workflow state exists, run `bash .agentskills/workflows/workflow-state.sh abort <workflow>`. It displays the state before archiving only its state files under `.git/agentskills/workflows/archive/`; it must not change source files, worktree, stage, commits, branches, PRs, or Git configuration. If no state or multiple workflow states exist, report `PROMPT BLOCKER`. Report the script result and `PROMPT END`.
