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

## awesome-claude-skills の設定

Anthropic公式のスキル集 [awesome-claude-skills](https://github.com/anthropics/awesome-claude-skills) も併せて設定することを推奨します。

### 含まれる主なスキル

| スキル | 説明 |
|--------|------|
| `artifacts-builder` | 複雑なHTML artifact作成 |
| `webapp-testing` | Playwrightを使用したWebアプリテスト |
| `mcp-builder` | MCPサーバー構築ガイド |
| `changelog-generator` | 変更履歴自動生成 |
| `skill-creator` | 新規スキル作成ガイド |
| `video-downloader` | YouTube動画ダウンロード |
| その他多数 | [リポジトリ](https://github.com/anthropics/awesome-claude-skills)を参照 |

### セットアップ手順

#### WSL2 / Linux / macOS

```bash
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/anthropics/awesome-claude-skills.git

# 使用したいスキルのシンボリックリンクを作成
ln -s awesome-claude-skills/artifacts-builder artifacts-builder
ln -s awesome-claude-skills/webapp-testing webapp-testing
ln -s awesome-claude-skills/mcp-builder mcp-builder
ln -s awesome-claude-skills/changelog-generator changelog-generator
ln -s awesome-claude-skills/skill-creator skill-creator
ln -s awesome-claude-skills/video-downloader video-downloader
# 必要なスキルを追加...
```

#### 一括セットアップスクリプト

すべてのスキルを一括でリンクする場合：

```bash
cd ~/.claude/skills

# リポジトリをクローン（未クローンの場合）
[ ! -d "awesome-claude-skills" ] && git clone https://github.com/anthropics/awesome-claude-skills.git

# 全スキルのシンボリックリンクを作成
for skill in awesome-claude-skills/*/; do
  skill_name=$(basename "$skill")
  [ ! -e "$skill_name" ] && ln -s "awesome-claude-skills/$skill_name" "$skill_name"
done
```

#### Windows (PowerShell 管理者権限)

```powershell
Set-Location "$env:USERPROFILE\.claude\skills"

# リポジトリをクローン
git clone https://github.com/anthropics/awesome-claude-skills.git

# 使用したいスキルのシンボリックリンクを作成
New-Item -ItemType SymbolicLink -Path "artifacts-builder" -Target "awesome-claude-skills\artifacts-builder"
New-Item -ItemType SymbolicLink -Path "webapp-testing" -Target "awesome-claude-skills\webapp-testing"
# 必要なスキルを追加...
```

### awesome-claude-skills の更新

```bash
cd ~/.claude/skills/awesome-claude-skills
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
