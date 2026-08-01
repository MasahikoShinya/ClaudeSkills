# Sound

Report `[AgentSkills][PROMPT][START] ::sound` after reading this file.

`::sound` manages the user's global Codex notification WAV. It operates only on `~/.codex/config.toml` and `~/.codex/notify-sound.sh`; never modify the repository, Git state, source, tests, branches, commits, or pull requests.

Accepted forms:

```text
::sound
::sound --list
::sound <name>
::sound --set <name>
```

- `::sound` plays the `*.wav` files under `C:\Windows\Media` in name order with each filename displayed before playback. It changes no configuration. Tell the user that `Ctrl+C` stops playback.
- `::sound --list` lists the `*.wav` files under `C:\Windows\Media`, without changing configuration or playing audio.
- `::sound <name>` selects the matching WAV as the Codex notification sound. Accept a basename with or without `.wav`, case-insensitively. `::sound --set <name>` remains accepted for backward compatibility. Reject path separators, `..`, empty names, unknown options, and extra arguments.

For playback, use Windows `System.Media.SoundPlayer` and wait for each WAV to finish. For selection, first verify that the requested file exists beneath `C:\Windows\Media`; then update only the following user-level notification artifacts, preserving every other `config.toml` setting:

1. `~/.codex/notify-sound.sh`, which ignores Codex's optional JSON payload argument and plays the selected absolute Windows WAV path with `powershell.exe`.
2. The top-level `notify` setting in `~/.codex/config.toml`, set to invoke that script through `bash` using its absolute path.
3. `[tui] notifications = true` and `notification_condition = "always"`, adding or updating only those two keys.

Report the selected filename and state that Codex must be restarted after a selection change. For list and playback operations, report that configuration was unchanged. Report `PROMPT END` with the operation result.
