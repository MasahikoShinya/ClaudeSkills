---
name: serena-memory-manager
description: This skill should be used when starting a session ("本日の作業を開始", "前回の続きから"), ending a session ("作業終了", "セッション終了"), or when the user asks to save/update memory state. Manages Serena memory for session continuity and crash recovery.
version: 1.0.0
---

# Serena Memory Manager

Serenaメモリを活用して、セッション間の継続性を確保し、突然の中断からも簡単に復帰できるようにする。

## Overview

このスキルは2種類のメモリを管理する：

| メモリ | 用途 | ライフサイクル |
|--------|------|----------------|
| `session-current` | 今取り組み中のタスク・状態 | セッションごとに更新 |
| `project-status` | プロジェクト全体の情報 | 長期保持、随時更新 |

## When This Skill Applies

- セッション開始時（「本日の作業を開始」「前回の続きから」）
- セッション終了時（「作業終了」「セッション終了」）
- 明示的なメモリ操作要求（「状態を保存して」「メモリを更新して」）
- チェックポイント作成（「チェックポイントを作成」）

## Memory Structure

### session-current.md（セッション固有）

現在取り組み中のタスクに関する情報：

- **現在のタスク**: 作業中のタスク一覧
- **直前の操作**: 最後に行った操作の記録
- **次のアクション**: 次に実行すべき手順
- **git状態**: ブランチ、未コミット変更
- **タスク関連の保留問題**: 現在のタスクに関連する未解決事項

### project-status.md（プロジェクト全体）

プロジェクト全体に関わる長期的な情報：

- **既知の問題**: バグ、技術的負債
- **重要な決定事項**: アーキテクチャ選択、設計方針
- **テスト結果サマリー**: 最新のテスト状況
- **環境変更履歴**: 設定変更、依存関係更新
- **プロジェクト全体の保留問題**: 判断待ち、確認待ち事項

## Operations

### セッション開始

1. `read_memory("session-current")` で前回の状態を確認
2. `read_memory("project-status")` でプロジェクト状況を確認
3. `git status` で現在のgit状態を確認
4. 必要に応じてTodoWriteを復元
5. ユーザーに状況サマリーを報告

### セッション中の更新

以下のタイミングで `session-current` を更新：

- タスク完了時
- 重要な決定後
- git commit前後
- 30分以上経過時（チェックポイント）

### セッション終了

1. `session-current` を最新状態に更新
2. 必要に応じて `project-status` を更新
3. 未解決事項があれば保留問題として記録

### チェックポイント作成

リスクのある操作前や長時間作業時：

```
checkpoint-YYYYMMDD-HHMM.md
```

## Templates

テンプレートは `templates/` ディレクトリを参照：

- `templates/session-current.md` - セッション用
- `templates/project-status.md` - プロジェクト用

## Customization

### セッション固有の項目（session-current）

必要に応じて以下を追加・削除可能：

- 現在のタスク
- 直前の操作
- 次のアクション
- git状態
- タスク関連の保留問題

### プロジェクト全体の項目（project-status）

必要に応じて以下を追加・削除可能：

- 既知の問題
- 重要な決定事項
- テスト結果サマリー
- 環境変更履歴
- プロジェクト全体の保留問題

## Examples

### セッション開始時
```
User: 本日の作業を開始します

Claude:
1. read_memory("session-current") を実行
2. read_memory("project-status") を実行
3. git status を確認
4. 状況サマリーを報告
```

### セッション終了時
```
User: 作業終了

Claude:
1. 現在の状態を session-current に保存
2. プロジェクト全体の変更があれば project-status を更新
3. 次回の作業に必要な情報をまとめて報告
```

### チェックポイント作成
```
User: チェックポイントを作成して

Claude:
1. 現在の session-current をコピーして checkpoint-YYYYMMDD-HHMM として保存
2. 保存完了を報告
```
