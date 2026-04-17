# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Claude Code用のカスタムスキル・サブエージェント集。スキルは `~/.claude/skills/` に、サブエージェントは `~/.claude/agents/` にシンボリックリンクして使用する。

**Language**: All skill definitions and documentation are in Japanese.

## Architecture

```
test-orchestrator（スキル・メインコンテキスト）
    |  Agent tool で呼び出し
    |--- test-planner（隔離）--- 計画だけ返す
    |--- unit-runner（隔離）--- 結果だけ返す
    |--- e2e-runner（隔離）--- 結果だけ返す
    |--- e2e-visual-verify（隔離）--- 動画・スクショパスだけ返す

code-review（スキル・メインコンテキスト）
    |  Phase 1: 並列独立レビュー
    |--- code-reviewer（Opus・隔離）--- レビュー結果A
    |--- code-critic（Codex・隔離）--- レビュー結果B
    |  Phase 2: 並列クロスレスポンス（根拠付き応答）
    |  Phase 3: 統合レポート（Agreed / Single / Disputed）
```

### Skills (`~/.claude/skills/` に配置)

メインコンテキストで動作するワークフロー定義。エントリポイントは `SKILL.md`。

- **test-orchestrator** — テストライフサイクルの司令塔。実作業はサブエージェントに委譲し、メインコンテキストでは結果集約と報告のみ行う。
- **code-review** — Claude Opus + Codex による独立レビュー・クロスレスポンス・統合レポート生成。矛盾する指摘はAIが裁定せず人間に委ねる。Codex MCP が必要。
- **cowork-chrome-launcher** — Cowork の Chrome 操作前に専用プロファイルの接続を確認し、未接続なら Mac/Windows 両対応の起動スクリプトで誘導する運用スキル。サブエージェントは持たず、`mcp__Claude_in_Chrome__tabs_context_mcp` の応答を見て接続状態を判別する。

### Sub-Agents (`agents/` → `~/.claude/agents/` にリンク)

隔離コンテキストで実行される実働部隊。結果サマリーだけがメインコンテキストに返る。

- **test-planner** — テスト項目の洗い出しとUnit/E2E振り分け
- **unit-runner** — ユニットテスト実行・カバレッジ測定・自律修正ループ
- **e2e-runner** — E2Eテスト実行・DB環境管理・自律修正ループ
- **e2e-visual-verify** — 動画録画・スクリーンショット・カーソル可視化・HTMLプレイヤー生成（model: sonnet）
- **code-reviewer** — Claude Opus による独立レビュー・クロスレスポンス
- **code-critic** — Codex MCP による独立レビュー・クロスレスポンス

### Other

- **scripts/** — コミュニティスキル (awesome-claude-skills) の一括セットアップスクリプト

## Key Conventions

- スキルのエントリポイントは `SKILL.md`、YAML frontmatter (`name`, `description`) を持つ
- サブエージェントはトップレベル `agents/` ディレクトリに `.md` ファイルとして配置
- サブエージェントは `model` frontmatter でモデル指定可能（e.g., e2e-visual-verify は sonnet）
- テスト結果は対象プロジェクトの `test-results.md` に日付付きで記録必須

## Development Workflow

ビルドシステム・リンター・テストスイートはない。変更はMarkdownの内容確認とClaude Codeセッションでの動作テストで検証する。

変更時の注意:
- SKILL.md/エージェント定義の変更時は README.md のスキル表・アーキテクチャ図も同期する
- サブエージェント定義は親スキル（test-orchestrator/SKILL.md, code-review/SKILL.md）のワークフローと整合させる
- サブエージェント追加時は README のセットアップ手順（シンボリックリンク）も更新する
