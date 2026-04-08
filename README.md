# ClaudeSkills

Claude Code用のカスタムスキル・サブエージェント集。

## 構成

### スキル（`~/.claude/skills/` に配置）

メインコンテキストで動作するガイドライン・ワークフロー。

| スキル名 | バージョン | 説明 |
|----------|------------|------|
| `test-orchestrator` | v1.1.0 | テスト計画・実行・目視確認を統合管理する司令塔（サブエージェントを呼び出す） |
| `code-review` | v1.0.0 | Claude Opus + Codex による独立レビュー・クロスレスポンス・統合レポート生成 |

### サブエージェント（`~/.claude/agents/` に配置）

隔離コンテキストで実行される実働部隊。結果のサマリーだけがメインコンテキストに返る。

| エージェント名 | 親スキル | 説明 |
|----------------|----------|------|
| `test-planner` | test-orchestrator | テスト項目の洗い出しとUnit/E2E振り分け |
| `unit-runner` | test-orchestrator | ユニットテスト実行・カバレッジ測定・自律修正 |
| `e2e-runner` | test-orchestrator | E2Eテスト実行・DB環境管理・自律修正 |
| `e2e-visual-verify` | test-orchestrator | E2Eテストの動画録画・スクリーンショット・目視確認素材の生成 |
| `code-reviewer` | code-review | Claude Opusによる独立レビュー・クロスレスポンス |
| `code-critic` | code-review | Codexによる独立レビュー・クロスレスポンス |

### アーキテクチャ

```
test-orchestrator（スキル・メインコンテキスト）
    |  Agent tool で呼び出し
    |--- test-planner（隔離）--- 計画だけ返す
    |--- unit-runner（隔離）--- 結果だけ返す
    |--- e2e-runner（隔離）--- 結果だけ返す
    |--- e2e-visual-verify（隔離）--- 動画・スクショパスだけ返す
    |
    メインコンテキストで結果をまとめてユーザーに報告

code-review（スキル・メインコンテキスト）
    |  Phase 1: 並列独立レビュー
    |--- code-reviewer（Opus・隔離）--- レビュー結果A
    |--- code-critic（Codex・隔離）--- レビュー結果B
    |
    |  Phase 2: 並列クロスレスポンス
    |--- code-reviewer（Opus・隔離）--- Codex指摘への根拠付き応答
    |--- code-critic（Codex・隔離）--- Opus指摘への根拠付き応答
    |
    メインコンテキストで統合レポート（Agreed / Single / Disputed）
```

## セットアップ

### 前提条件

- Claude Code がインストールされていること
- Git がインストールされていること
- code-review スキルを使用する場合: Codex MCP サーバーが設定されていること（[codex-mcp](https://github.com/nicobailon/codex-mcp) 等）

### WSL2 / Linux / macOS

```bash
# スキルディレクトリに移動（なければ作成）
mkdir -p ~/.claude/skills ~/.claude/agents
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/MasahikoShinya/ClaudeSkills.git

# スキルのシンボリックリンクを作成
ln -s ClaudeSkills/test-orchestrator test-orchestrator
ln -s ClaudeSkills/code-review code-review

# サブエージェントのシンボリックリンクを作成
cd ~/.claude/agents
ln -s ../skills/ClaudeSkills/agents/test-planner.md test-planner.md
ln -s ../skills/ClaudeSkills/agents/unit-runner.md unit-runner.md
ln -s ../skills/ClaudeSkills/agents/e2e-runner.md e2e-runner.md
ln -s ../skills/ClaudeSkills/agents/e2e-visual-verify.md e2e-visual-verify.md
ln -s ../skills/ClaudeSkills/agents/code-reviewer.md code-reviewer.md
ln -s ../skills/ClaudeSkills/agents/code-critic.md code-critic.md
```

### Windows (PowerShell 管理者権限)

```powershell
# ディレクトリ作成
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\agents"
Set-Location "$env:USERPROFILE\.claude\skills"

# リポジトリをクローン
git clone https://github.com/MasahikoShinya/ClaudeSkills.git

# スキルのシンボリックリンク
New-Item -ItemType SymbolicLink -Path "test-orchestrator" -Target "ClaudeSkills\test-orchestrator"
New-Item -ItemType SymbolicLink -Path "code-review" -Target "ClaudeSkills\code-review"

# サブエージェントのシンボリックリンク
Set-Location "$env:USERPROFILE\.claude\agents"
New-Item -ItemType SymbolicLink -Path "test-planner.md" -Target "..\skills\ClaudeSkills\agents\test-planner.md"
New-Item -ItemType SymbolicLink -Path "unit-runner.md" -Target "..\skills\ClaudeSkills\agents\unit-runner.md"
New-Item -ItemType SymbolicLink -Path "e2e-runner.md" -Target "..\skills\ClaudeSkills\agents\e2e-runner.md"
New-Item -ItemType SymbolicLink -Path "e2e-visual-verify.md" -Target "..\skills\ClaudeSkills\agents\e2e-visual-verify.md"
New-Item -ItemType SymbolicLink -Path "code-reviewer.md" -Target "..\skills\ClaudeSkills\agents\code-reviewer.md"
New-Item -ItemType SymbolicLink -Path "code-critic.md" -Target "..\skills\ClaudeSkills\agents\code-critic.md"
```

## セットアップの確認

```bash
# スキル
ls -la ~/.claude/skills/ | grep -E "(test-orchestrator|code-review)"

# サブエージェント
ls -la ~/.claude/agents/

# 期待される出力:
# ~/.claude/skills/
#   test-orchestrator -> ClaudeSkills/test-orchestrator
#   code-review -> ClaudeSkills/code-review
#
# ~/.claude/agents/
#   test-planner.md -> .../ClaudeSkills/agents/test-planner.md
#   unit-runner.md -> .../ClaudeSkills/agents/unit-runner.md
#   e2e-runner.md -> .../ClaudeSkills/agents/e2e-runner.md
#   e2e-visual-verify.md -> .../ClaudeSkills/agents/e2e-visual-verify.md
#   code-reviewer.md -> .../ClaudeSkills/agents/code-reviewer.md
#   code-critic.md -> .../ClaudeSkills/agents/code-critic.md
```

## 更新

```bash
cd ~/.claude/skills/ClaudeSkills
git pull origin main
```

## コミュニティスキル（オプション）

必要に応じて [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) から個別にインストール可能。グローバルではなくプロジェクトローカル（`<project>/.claude/skills/`）への配置を推奨。

---

## スキル詳細

### test-orchestrator (v1.1.0)

テストの計画・実行・目視確認を統合管理する司令塔スキル。
実際の作業は `~/.claude/agents/` のサブエージェントに委譲し、メインコンテキストでは結果の集約と報告のみ行う。

**サブエージェント（`agents/` に配置、`~/.claude/agents/` にリンク）:**
| 名前 | 役割 | 実行場所 |
|------|------|----------|
| `test-planner` | テスト計画作成 | 隔離コンテキスト |
| `unit-runner` | ユニットテスト実行・自律修正 | 隔離コンテキスト |
| `e2e-runner` | E2Eテスト実行・DB管理 | 隔離コンテキスト |
| `e2e-visual-verify` | 動画録画・スクショ・目視確認素材生成 | 隔離コンテキスト |

**使用例:**
```
User: このプロジェクトのテストを実行して
User: ユニットテストだけ実行して
User: テスト計画を作成して
User: E2Eの動作確認をして
```

詳細は [test-orchestrator/SKILL.md](./test-orchestrator/SKILL.md) を参照。

---

### code-review (v1.0.0)

2つの異なるAIモデル（Claude Opus + Codex）による独立レビューとクロスレスポンスを統合し、信頼度付きのレビューレポートを生成するスキル。矛盾する指摘はAIが裁定せず、人間の判断に委ねる。

**フロー:**
```
1. 並列独立レビュー（Opus + Codex が別々にレビュー）
2. 並列クロスレスポンス（互いの指摘に根拠付きで応答）
3. 統合レポート（Agreed / Single / Disputed に分類）
```

**サブエージェント（`agents/` に配置、`~/.claude/agents/` にリンク）:**
| 名前 | 役割 | 実行場所 |
|------|------|----------|
| `code-reviewer` | Claude Opusによる独立レビュー・クロスレスポンス | 隔離コンテキスト |
| `code-critic` | Codexによる独立レビュー・クロスレスポンス | 隔離コンテキスト |

**前提条件:**
- Codex MCP サーバーが設定されていること（`mcp__codex__codex` が利用可能）

**使用例:**
```
User: このコードをレビューして
User: 変更をレビューして
User: PR #123 をレビューして
User: セキュリティ観点でレビューして
```

詳細は [code-review/SKILL.md](./code-review/SKILL.md) を参照。

---

## 変更履歴

### 2026-04-08

- **e2e-visual-verify**: プレイヤー生成を固定スクリプト（`scripts/generate-player.ts`）に変更。毎回同一デザインのHTMLを出力

### 2026-04-07

- **e2e-visual-verify**: エージェント定義を実装済みコード（showTitle/showResult）に統一
- **e2e-visual-verify**: スクリーンショットをシナリオ名でディレクトリ分けして紐づけ
- **e2e-visual-verify**: プレイヤーをサイドバー廃止→動画下にシナリオ一覧+スクリーンショット表示に変更

### 2026-04-06

- **code-review v1.0.0**: Claude Opus + Codex による独立レビュー・クロスレスポンス・統合レポート生成スキルを追加
- **code-reviewer / code-critic**: code-review用サブエージェントを追加
- 廃止スキル（response-workflow, serena-memory-manager, error-reporting-format）を削除
- README整理 — 廃止スキル削除、コミュニティスキルをオプション化

### 2026-04-05

- **e2e-visual-verify**: テスト完了後にプレイヤーを自動でブラウザオープンする機能を追加
- **error-reporting-format**: サブエージェントに統合、スキル廃止

### 2026-04-04

- サブエージェントを `~/.claude/agents/` 対応に分離
- README更新 — サブエージェント構成とセットアップ手順を追加

### 2026-04-03

- **response-workflow v1.2.0**: 入力分解、TDD、デグレ対策を追加
- **response-workflow v1.0.0**: スキル追加
- **error-reporting-format**: スキル追加
- **serena-memory-manager**: スキル追加
- **test-orchestrator v1.1.0**: 更新

### 初回リリース

- **test-orchestrator v1.0.0**: テスト計画・実行・目視確認の司令塔スキルを追加
- コミュニティスキル（awesome-claude-skills）のセットアップスクリプトを追加

## ライセンス

MIT License
