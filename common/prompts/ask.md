# Ask

Report `[AgentSkills][PROMPT][START] ::ask` after reading this file.

`::ask <question>` answers the user's question only. It may read repository files, Git state, logs, local configuration, or authoritative external documentation when needed to give an evidence-based answer.

Do not modify files, Git state, staging, configuration, workflow state, branches, commits, pull requests, external services, or installed tools. Do not turn the question into an implementation, plan, task, or follow-up workflow unless the user explicitly asks for that separately.

State important uncertainty plainly. For a question that needs a current or external fact, cite the source or explain that it could not be verified. End with `[AgentSkills][PROMPT][END] ::ask` and `[AgentSkills][EXECUTED] ::ask`.
