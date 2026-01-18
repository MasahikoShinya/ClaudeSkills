# ClaudeSkills

Claude Code用のカスタムスキル集。

## 含まれるスキル

| スキル名 | 説明 |
|----------|------|
| `test-orchestrator` | テスト計画・Unit/E2Eテストの実行を統合管理するオーケストレーター |

## セットアップ

### 前提条件

- Claude Code がインストールされていること
- Git がインストールされていること

### WSL2 / Linux

```bash
# スキルディレクトリに移動（なければ作成）
mkdir -p ~/.claude/skills
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/MasahikoShinya/ClaudeSkills.git

# シンボリックリンクを作成
ln -s ClaudeSkills/test-orchestrator test-orchestrator
```

### macOS

```bash
# スキルディレクトリに移動（なければ作成）
mkdir -p ~/.claude/skills
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/MasahikoShinya/ClaudeSkills.git

# シンボリックリンクを作成
ln -s ClaudeSkills/test-orchestrator test-orchestrator
```

### Windows (PowerShell 管理者権限)

```powershell
# スキルディレクトリに移動（なければ作成）
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"
Set-Location "$env:USERPROFILE\.claude\skills"

# リポジトリをクローン
git clone https://github.com/MasahikoShinya/ClaudeSkills.git

# シンボリックリンクを作成（管理者権限必要）
New-Item -ItemType SymbolicLink -Path "test-orchestrator" -Target "ClaudeSkills\test-orchestrator"
```

## セットアップの確認

```bash
# シンボリックリンクが正しく作成されているか確認
ls -la ~/.claude/skills/ | grep test-orchestrator

# 期待される出力:
# test-orchestrator -> ClaudeSkills/test-orchestrator
```

## スキルの更新

```bash
cd ~/.claude/skills/ClaudeSkills
git pull origin main
```

## スキル一覧

### test-orchestrator

テストの計画から実行までを統合的に管理するスキル。

**機能:**
- テスト項目の洗い出しとUnit/E2E振り分け
- ユニットテスト実行（カバレッジ90%目標）
- E2Eテスト実行（DB切替管理）
- 自律的な修正ループ

**サブエージェント:**
| 名前 | 役割 |
|------|------|
| `test-planner` | テスト計画作成 |
| `unit-runner` | ユニットテスト実行 |
| `e2e-runner` | E2Eテスト実行 |

**使用例:**
```
User: このプロジェクトのテストを実行して
User: ユニットテストだけ実行して
User: テスト計画を作成して
```

詳細は [test-orchestrator/SKILL.md](./test-orchestrator/SKILL.md) を参照。

## ライセンス

Private repository - All rights reserved.
