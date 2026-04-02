# ClaudeSkills

Claude Code用のカスタムスキル・サブエージェント集。

## 構成

### スキル（`~/.claude/skills/` に配置）

メインコンテキストで動作するガイドライン・ワークフロー。

| スキル名 | バージョン | 説明 |
|----------|------------|------|
| `response-workflow` | v1.2.0 | 入力分解・質問/指示判定・TDD・デグレ対策を含む回答ワークフロー |
| `test-orchestrator` | v1.1.0 | テスト計画・実行・目視確認を統合管理する司令塔（サブエージェントを呼び出す） |
| `serena-memory-manager` | v1.0.0 | Serenaメモリを活用したセッション継続性管理・クラッシュ復帰支援 |
| `error-reporting-format` | v1.0.0 | テスト失敗・エラー調査結果の標準報告フォーマット |

### サブエージェント（`~/.claude/agents/` に配置）

隔離コンテキストで実行される実働部隊。結果のサマリーだけがメインコンテキストに返る。

| エージェント名 | 説明 |
|----------------|------|
| `test-planner` | テスト項目の洗い出しとUnit/E2E振り分け |
| `unit-runner` | ユニットテスト実行・カバレッジ測定・自律修正 |
| `e2e-runner` | E2Eテスト実行・DB環境管理・自律修正 |
| `e2e-visual-verify` | E2Eテストの動画録画・スクリーンショット・目視確認素材の生成 |

### アーキテクチャ

```
ユーザー: 「テストを実行して」
    |
test-orchestrator（スキル・メインコンテキスト）
    |  Agent tool で呼び出し
    |--- test-planner（サブエージェント・隔離）--- 計画だけ返す
    |--- unit-runner（サブエージェント・隔離）--- 結果だけ返す
    |--- e2e-runner（サブエージェント・隔離）--- 結果だけ返す
    |--- e2e-visual-verify（サブエージェント・隔離）--- 動画・スクショパスだけ返す
    |
メインコンテキストで結果をまとめてユーザーに報告
```

## セットアップ

### 前提条件

- Claude Code がインストールされていること
- Git がインストールされていること

### WSL2 / Linux / macOS

```bash
# スキルディレクトリに移動（なければ作成）
mkdir -p ~/.claude/skills ~/.claude/agents
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/MasahikoShinya/ClaudeSkills.git

# スキルのシンボリックリンクを作成
ln -s ClaudeSkills/response-workflow response-workflow
ln -s ClaudeSkills/test-orchestrator test-orchestrator
ln -s ClaudeSkills/serena-memory-manager serena-memory-manager
ln -s ClaudeSkills/error-reporting-format error-reporting-format

# サブエージェントのシンボリックリンクを作成
cd ~/.claude/agents
ln -s ../skills/ClaudeSkills/agents/test-planner.md test-planner.md
ln -s ../skills/ClaudeSkills/agents/unit-runner.md unit-runner.md
ln -s ../skills/ClaudeSkills/agents/e2e-runner.md e2e-runner.md
ln -s ../skills/ClaudeSkills/agents/e2e-visual-verify.md e2e-visual-verify.md
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
New-Item -ItemType SymbolicLink -Path "response-workflow" -Target "ClaudeSkills\response-workflow"
New-Item -ItemType SymbolicLink -Path "test-orchestrator" -Target "ClaudeSkills\test-orchestrator"
New-Item -ItemType SymbolicLink -Path "serena-memory-manager" -Target "ClaudeSkills\serena-memory-manager"
New-Item -ItemType SymbolicLink -Path "error-reporting-format" -Target "ClaudeSkills\error-reporting-format"

# サブエージェントのシンボリックリンク
Set-Location "$env:USERPROFILE\.claude\agents"
New-Item -ItemType SymbolicLink -Path "test-planner.md" -Target "..\skills\ClaudeSkills\agents\test-planner.md"
New-Item -ItemType SymbolicLink -Path "unit-runner.md" -Target "..\skills\ClaudeSkills\agents\unit-runner.md"
New-Item -ItemType SymbolicLink -Path "e2e-runner.md" -Target "..\skills\ClaudeSkills\agents\e2e-runner.md"
New-Item -ItemType SymbolicLink -Path "e2e-visual-verify.md" -Target "..\skills\ClaudeSkills\agents\e2e-visual-verify.md"
```

## セットアップの確認

```bash
# スキル
ls -la ~/.claude/skills/ | grep -E "(response-workflow|test-orchestrator|serena-memory-manager|error-reporting-format)"

# サブエージェント
ls -la ~/.claude/agents/

# 期待される出力:
# ~/.claude/skills/
#   response-workflow -> ClaudeSkills/response-workflow
#   test-orchestrator -> ClaudeSkills/test-orchestrator
#   serena-memory-manager -> ClaudeSkills/serena-memory-manager
#   error-reporting-format -> ClaudeSkills/error-reporting-format
#
# ~/.claude/agents/
#   test-planner.md -> .../ClaudeSkills/agents/test-planner.md
#   unit-runner.md -> .../ClaudeSkills/agents/unit-runner.md
#   e2e-runner.md -> .../ClaudeSkills/agents/e2e-runner.md
#   e2e-visual-verify.md -> .../ClaudeSkills/agents/e2e-visual-verify.md
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

## ライセンス

Private repository - All rights reserved.
