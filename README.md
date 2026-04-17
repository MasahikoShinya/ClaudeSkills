# ClaudeSkills

Claude Code用のカスタムスキル・サブエージェント集。

## 構成

### スキル（`~/.claude/skills/` に配置）

メインコンテキストで動作するガイドライン・ワークフロー。

| スキル名 | バージョン | 説明 |
|----------|------------|------|
| `test-orchestrator` | v1.1.0 | テスト計画・実行・目視確認を統合管理する司令塔（サブエージェントを呼び出す） |
| `code-review` | v1.0.0 | Claude Opus + Codex による独立レビュー・クロスレスポンス・統合レポート生成 |
| `cowork-chrome-launcher` | v1.0.0 | Cowork の Chrome 操作前に専用プロファイルの接続を確認し、未接続なら起動スクリプトで誘導する運用スキル（Mac/Windows 両対応） |

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

### 複数環境で併用する場合の注意（WSL + Windows Cowork など）

Claude Code（WSL / Linux / macOS）と Cowork（macOS / Windows）は**スキルを読み込む場所が環境ごとに独立**している。

- Claude Code in WSL → WSL 側の `~/.claude/skills/`
- Cowork on Windows → Windows ネイティブの `%USERPROFILE%\.claude\skills\`
- Cowork on macOS / Claude Code on macOS → macOS 側の `~/.claude/skills/`

同一マシン上で WSL Claude Code と Windows Cowork を併用する場合、**理論上は Windows 側の symlink を `\\wsl.localhost\Ubuntu\...` 経由で WSL 内のリポジトリに向ける**ことも可能だが、Cowork が UNC パス越しにスキルファイルを確実に読めるかは環境依存で保証できない。

**確実に動かすには、WSL と Windows でそれぞれ独立に clone して symlink を張る**（このリポジトリを2箇所に clone する）のが推奨。各環境は完全に独立しているため、互いに干渉しない。更新時はそれぞれの環境で `git pull` を叩く。

```
例：Windows + WSL 併用時の配置
├── C:\Users\<user>\.claude\skills\ClaudeSkills\        ← Cowork on Windows 用（Windows 側でclone）
└── \\wsl$\Ubuntu\home\<user>\.claude\skills\ClaudeSkills\  ← Claude Code in WSL 用（WSL 側でclone）
```

Mac / Linux のみ、もしくは Windows のみの環境であれば、単一 clone で完結する。

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
ln -s ClaudeSkills/cowork-chrome-launcher cowork-chrome-launcher

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
New-Item -ItemType SymbolicLink -Path "cowork-chrome-launcher" -Target "ClaudeSkills\cowork-chrome-launcher"

# サブエージェントのシンボリックリンク
Set-Location "$env:USERPROFILE\.claude\agents"
New-Item -ItemType SymbolicLink -Path "test-planner.md" -Target "..\skills\ClaudeSkills\agents\test-planner.md"
New-Item -ItemType SymbolicLink -Path "unit-runner.md" -Target "..\skills\ClaudeSkills\agents\unit-runner.md"
New-Item -ItemType SymbolicLink -Path "e2e-runner.md" -Target "..\skills\ClaudeSkills\agents\e2e-runner.md"
New-Item -ItemType SymbolicLink -Path "e2e-visual-verify.md" -Target "..\skills\ClaudeSkills\agents\e2e-visual-verify.md"
New-Item -ItemType SymbolicLink -Path "code-reviewer.md" -Target "..\skills\ClaudeSkills\agents\code-reviewer.md"
New-Item -ItemType SymbolicLink -Path "code-critic.md" -Target "..\skills\ClaudeSkills\agents\code-critic.md"
```

### Claude Code にセットアップを任せる

別 PC・新規環境への展開、または単一スキル追加時は、以下のプロンプトを Claude Code に渡せば clone / symlink / 実行権限付与まで自動で処理できる。OS 判定もするので、macOS・Linux・WSL・Windows のどれでもそのまま使える。

**macOS / Linux / WSL の場合:**

```
https://github.com/MasahikoShinya/ClaudeSkills.git リポジトリの cowork-chrome-launcher スキルを、Claude Code / Cowork から使えるようにセットアップしてほしい。

やること：
1. リポジトリが未クローンなら ~/.claude/skills/ にクローン、既にあれば git pull で最新化
2. ~/.claude/skills/cowork-chrome-launcher というシンボリックリンクを作成し、(clone 先)/cowork-chrome-launcher を指すようにする（既存ならスキップ）
3. open-cowork-chrome.command に実行権限が無ければ chmod +x で付与
4. 結果をまとめて報告（リンク先・権限・確認コマンド）

完了したら最後に「Claude デスクトップアプリを再起動 → 新規セッションで試せ」と念押ししてほしい。
```

**Windows (PowerShell) の場合:**

```
https://github.com/MasahikoShinya/ClaudeSkills.git リポジトリの cowork-chrome-launcher スキルを、Cowork から使えるようにセットアップしてほしい。

やること：
1. リポジトリが未クローンなら %USERPROFILE%\.claude\skills\ にクローン、既にあれば git pull で最新化
2. %USERPROFILE%\.claude\skills\cowork-chrome-launcher という NTFS シンボリックリンクを作成し、(clone 先)\cowork-chrome-launcher を指すようにする（既存ならスキップ）
3. リンク作成に管理者権限または開発者モード ON が必要なら、先に案内する
4. 結果をまとめて報告（リンク先・確認コマンド）

完了したら最後に「Claude デスクトップアプリを再起動 → 新規セッションで試せ」と念押ししてほしい。
```

他スキルを追加する時も、`cowork-chrome-launcher` 部分をスキル名に差し替えれば同じ形で使える。

## セットアップの確認

```bash
# スキル
ls -la ~/.claude/skills/ | grep -E "(test-orchestrator|code-review|cowork-chrome-launcher)"

# サブエージェント
ls -la ~/.claude/agents/

# 期待される出力:
# ~/.claude/skills/
#   test-orchestrator -> ClaudeSkills/test-orchestrator
#   code-review -> ClaudeSkills/code-review
#   cowork-chrome-launcher -> ClaudeSkills/cowork-chrome-launcher
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
# WSL / Linux / macOS
cd ~/.claude/skills/ClaudeSkills
git pull origin main
```

```powershell
# Windows
cd $env:USERPROFILE\.claude\skills\ClaudeSkills
git pull origin main
```

WSL と Windows Cowork を併用している場合は**両方の clone で** `git pull` が必要（それぞれが独立した作業コピー）。

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

### cowork-chrome-launcher (v1.0.0)

Cowork の Chrome 操作前に Cowork 専用 Chrome プロファイルの接続状態を確認し、未接続なら同梱スクリプトで起動するようユーザーを誘導する運用スキル。Chrome Sync によるクロスデバイス誤接続、Cowork プロファイルが閉じている状態での接続失敗、拡張サービスワーカーの切断など、Cowork の Chrome 制御で頻発するパターンを検知して回避する。

**同梱物:**
| 内容 | 説明 |
|------|------|
| `scripts/open-cowork-chrome.command` | Mac 用起動スクリプト（Cowork プロファイルで Chrome を起動） |
| `scripts/open-cowork-chrome.bat` | Windows 用起動スクリプト（同上） |
| `references/setup.md` | Cowork 専用プロファイルの作成、拡張のインストール、自動起動設定の手順書 |

**使用例:**
```
User: Chrome で Yahoo を開いて
User: このサイトのスクショを撮って
User: ウェブページの内容を要約して
User: Cowork で Chrome が動かないんだけど
User: Cowork プロファイルってどう作るの？
```

**前提条件:**
- Cowork 専用の Chrome プロファイル（Google アカウント未ログイン）が作成済み
- そのプロファイルに `Claude for Chrome` 拡張がインストール済み
- セットアップ未完了の場合は `references/setup.md` を参照

詳細は [cowork-chrome-launcher/SKILL.md](./cowork-chrome-launcher/SKILL.md) を参照。

---

## 変更履歴

### 2026-04-16

- **cowork-chrome-launcher v1.0.0**: Cowork の Chrome 操作前にプロファイル接続を確認・誘導する運用スキルを追加

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
