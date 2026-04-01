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

## awesome-claude-skills の設定

コミュニティのスキル集 [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) も併せて設定することを推奨します。

### 含まれる主なスキル

| スキル | 説明 |
|--------|------|
| `artifacts-builder` | 複雑なHTML artifact作成 |
| `webapp-testing` | Playwrightを使用したWebアプリテスト |
| `mcp-builder` | MCPサーバー構築ガイド |
| `changelog-generator` | 変更履歴自動生成 |
| `skill-creator` | 新規スキル作成ガイド |
| `video-downloader` | YouTube動画ダウンロード |
| その他多数 | [リポジトリ](https://github.com/ComposioHQ/awesome-claude-skills)を参照 |

### セットアップ手順（スクリプト使用）

このリポジトリに含まれるセットアップスクリプトを使用すると、すべてのawesome-claude-skillsを一括でインストールできます。

#### WSL2 / Linux / macOS

```bash
# ClaudeSkillsリポジトリのセットアップ後に実行
~/.claude/skills/ClaudeSkills/scripts/setup-awesome-skills.sh
```

#### Windows (PowerShell 管理者権限)

```powershell
# ClaudeSkillsリポジトリのセットアップ後に実行
& "$env:USERPROFILE\.claude\skills\ClaudeSkills\scripts\setup-awesome-skills.ps1"
```

### セットアップ手順（手動）

個別にスキルを選択してインストールする場合：

#### WSL2 / Linux / macOS

```bash
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/ComposioHQ/awesome-claude-skills.git

# 使用したいスキルのシンボリックリンクを作成
ln -s awesome-claude-skills/artifacts-builder artifacts-builder
ln -s awesome-claude-skills/webapp-testing webapp-testing
ln -s awesome-claude-skills/mcp-builder mcp-builder
ln -s awesome-claude-skills/changelog-generator changelog-generator
ln -s awesome-claude-skills/skill-creator skill-creator
ln -s awesome-claude-skills/video-downloader video-downloader
# 必要なスキルを追加...
```

#### Windows (PowerShell 管理者権限)

```powershell
Set-Location "$env:USERPROFILE\.claude\skills"

# リポジトリをクローン
git clone https://github.com/ComposioHQ/awesome-claude-skills.git

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

---

## スキル詳細

### response-workflow (v1.2.0)

ユーザー入力に対する回答ワークフローを定義するスキル。

**機能:**
- 入力の単一/複数判定と分解
- 質問/指示の判定
- コード/設定変更を伴う指示へのTDDフロー適用
- デグレ対策（影響範囲分析、段階的テスト実行）

**メインフロー:**
```
ユーザー入力
    │
    ├─→ 単一/複数判定 → 複数なら分解
    │
    ├─→ 各項目: 質問か指示か判定
    │       ├─→ 質問 → 回答のみ
    │       └─→ 指示 → コード変更あり? → TDDフロー
    │                              なし? → 通常実行
    │
    └─→ 終了
```

**TDDフロー:**
1. 既存テスト確認
2. 影響範囲分析
3. RED: テスト準備
4. GREEN: 実装
5. REFACTOR: 改善
6. デグレチェック
7. 報告

詳細は [response-workflow/SKILL.md](./response-workflow/SKILL.md) を参照。

---

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

### serena-memory-manager (v1.0.0)

Serenaメモリを活用して、セッション間の継続性を確保し、突然の中断からも簡単に復帰できるようにするスキル。

**機能:**
- セッション状態の自動保存・復元
- プロジェクト全体の状態管理
- チェックポイント作成によるクラッシュ復帰
- ハイブリッド方式（常時更新 + スナップショット）

**管理するメモリ:**
| メモリ | 用途 |
|--------|------|
| `session-current` | 現在のセッション状態（常時更新） |
| `project-status` | プロジェクト全体の情報（長期保持） |
| `checkpoint-*` | スナップショット（履歴） |

**使用例:**
```
User: 本日の作業を開始します
User: 前回の続きから
User: 作業終了
User: チェックポイントを作成して
```

詳細は [serena-memory-manager/SKILL.md](./serena-memory-manager/SKILL.md) を参照。

---

### error-reporting-format (v1.0.0)

テスト失敗やエラー調査結果を報告する際の標準フォーマット。

**使用場面:**
- E2Eテスト失敗の調査報告時
- ユニットテスト失敗の調査報告時
- バグ調査・デバッグ結果の報告時
- 障害調査レポート作成時

**報告構成（必須順序）:**

1. **まず結論**（高レベル分類）
   | 分類 | 件数 |
   |------|------|
   | ソースコードのデグレ | X件 |
   | テスト実装の修正が必要 | Y件 |

2. **次に修正状況**
   | 状況 | 件数 |
   |------|------|
   | 修正して解決 | X件 |
   | 未修正 | Y件 |

3. **最後に詳細**（ファイル別、原因別）

**原則:**
- 結論ファースト: デグレか否かを最初に
- 段階的詳細化: 概要→状況→詳細の順
- 表形式活用: 件数や分類は表で整理

詳細は [error-reporting-format/SKILL.md](./error-reporting-format/SKILL.md) を参照。

---

## ライセンス

Private repository - All rights reserved.
