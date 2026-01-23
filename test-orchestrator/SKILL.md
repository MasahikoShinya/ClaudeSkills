---
name: test-orchestrator
description: Comprehensive test orchestration skill that manages test planning, unit tests, and E2E tests with coverage targets and autonomous fix loops
---

# Test Orchestrator

A comprehensive testing skill that orchestrates the full testing lifecycle with sub-agents for planning, unit testing, and E2E testing.

## Workflow Overview

```
1. Test Planning    → テスト項目の洗い出しと文書化
2. Unit Testing     → カバレッジ90%目標、自律修正ループ
3. E2E Testing      → ユニットでカバー不可な部分、DB切替管理
4. Result Recording → test-results.mdに結果と日付を記録（必須）
```

## Activation Triggers

- User requests test execution, test planning, or test coverage improvement
- Keywords: "テスト", "test", "coverage", "カバレッジ", "ユニットテスト", "E2E"

## Sub-Agents

This skill uses three specialized sub-agents:

### 1. test-planner
- **Purpose**: テスト項目の洗い出しとUnit/E2E振り分け
- **Output**: `test-plan.md` (テスト項目文書)

### 2. unit-runner
- **Purpose**: ユニットテストの実行と自律的修正
- **Target**: カバレッジ90%
- **Constraint**: 本番DB禁止、モック必須

### 3. e2e-runner
- **Purpose**: E2Eテストの実行とDB管理
- **Target**: ユニットでカバー不可な部分
- **Constraint**: テスト用DB使用、完了後に復元

## Execution Protocol

### Phase 1: Planning (test-planner)

```markdown
1. 対象コード/機能を分析
2. テスト項目を洗い出し
3. Unit/E2E振り分けを決定
4. test-plan.md を作成・保存
```

### Phase 2: Unit Testing (unit-runner)

```markdown
1. テストフレームワーク検出 (Vitest/Jest or pytest)
2. テスト実行とカバレッジ測定
3. カバレッジ90%未満 → 指示者に相談
4. 失敗テストがある場合:
   a. 原因分析
   b. 修正実施（実装変更は記録）
   c. 全テスト再実行
   d. 全合格まで繰り返し
5. 変更レポート作成
6. **結果をtest-results.mdに記録（日付・件数・修正内容）** ← 必須
```

### Phase 3: E2E Testing (e2e-runner)

```markdown
1. テスト用DB環境を構築
   - 環境変数でDB切替
   - コンテナ再起動（必要に応じて）
2. E2Eテスト実行
3. 失敗テストがある場合:
   a. 原因分析
   b. 修正実施
   c. 再実行
   d. 全合格まで繰り返し
4. 本番DB設定に復元
5. 復元確認
6. **結果をtest-results.mdに記録（日付・件数・修正内容）** ← 必須
```

## Framework Detection

### Frontend (Vitest/Jest)
```bash
# Detection priority
1. vitest.config.ts/js → Vitest
2. jest.config.ts/js → Jest
3. package.json の test script を確認

# Coverage tool
- Vitest: built-in c8/v8
- Jest: --coverage flag
```

### Backend (pytest)
```bash
# Detection
1. pytest.ini / pyproject.toml [tool.pytest]
2. conftest.py の存在

# Coverage tool
- pytest-cov (pytest --cov)
```

## Coverage Configuration

### Unified Coverage Standard
```yaml
unit_test:
  target: 90%
  tool:
    frontend: c8 (Vitest) or Jest coverage
    backend: pytest-cov

  on_below_target:
    action: "指示者に相談"
    report:
      - current_coverage
      - uncovered_files
      - suggested_tests

e2e_test:
  target: none (定めない)
  focus: "ユニットでカバー不可な部分"
```

## Database Management (E2E)

### Environment Variable Strategy
```bash
# Production
DATABASE_URL=postgresql://user:pass@prod-host:5432/prod_db

# Test
DATABASE_URL=postgresql://user:pass@test-host:5432/test_db
# or
DATABASE_URL=postgresql://user:pass@localhost:5432/test_db
```

### Container Restart Protocol
```bash
# 1. Stop containers
docker-compose down

# 2. Switch environment
export DATABASE_URL="..."  # or update .env.test

# 3. Start with test config
docker-compose --env-file .env.test up -d

# 4. Wait for healthy state
docker-compose ps

# 5. Run E2E tests
# ...

# 6. Restore production config
docker-compose down
docker-compose up -d  # uses default .env
```

## Reporting Requirements

### Implementation Change Report
When modifying source code (not just tests), MUST report:
```markdown
## 実装変更レポート

### 変更ファイル
- `path/to/file.ts:line` - 変更内容の概要

### 変更理由
- テストで発見された問題の説明

### 影響範囲
- 変更による影響を受ける可能性のある機能
```

### Coverage Report
```markdown
## カバレッジレポート

### 現在のカバレッジ
- Frontend: XX%
- Backend: XX%

### 未カバー箇所
- file1.ts: lines 10-15 (理由: ...)
- file2.py: function_name (理由: ...)

### 90%未達の場合の提案
- 追加すべきテストケース
- カバレッジ向上の見込み
```

## Critical Rules

1. **コンテナ内実行必須**: ユニットテストもE2Eも必ずコンテナ内で実行する
2. **本番DB絶対禁止**: ユニットテストもE2Eも本番DBを使用しない
3. **モック必須**: 外部API/DBアクセスはモックで対応
4. **全テスト合格**: 修正ループは全テスト合格まで継続
5. **変更報告**: 実装変更は必ず報告
6. **DB復元確認**: E2E完了後は必ず本番DB設定に戻す
7. **90%相談**: カバレッジ90%未達は自己判断せず相談
8. **結果記録必須**: テスト実行後は必ず結果と日付を記録する（下記参照）

## Test Result Recording (必須)

**テスト実行後は必ず結果をファイルに記録すること。**

### 記録先
- プロジェクトルートの `test-results.md` に追記
- ファイルが存在しない場合は作成

### 記録フォーマット

```markdown
## YYYY-MM-DD HH:MM (JST)

### Unit Tests
| Category | Passed | Failed | Skipped | Total |
|----------|--------|--------|---------|-------|
| Frontend | X | X | X | X |
| Backend  | X | X | X | X |

### E2E Tests
| Passed | Failed | Skipped | Total |
|--------|--------|---------|-------|
| X | X | X | X |

### Summary
- ✅ All tests passed / ❌ X failures detected
- Coverage: Frontend XX%, Backend XX%

### Fixes Applied (if any)
- `file.ts:line` - 修正内容

### Notes
- 特記事項があれば記載

---
```

### Recording Timing
1. **ユニットテスト完了時**: Frontend/Backendそれぞれの結果を記録
2. **E2Eテスト完了時**: E2E結果を記録
3. **修正適用後の再実行時**: 再実行結果を更新

### Example Entry

```markdown
## 2026-01-23 12:30 (JST)

### Unit Tests
| Category | Passed | Failed | Skipped | Total |
|----------|--------|--------|---------|-------|
| Frontend | 1503 | 0 | 0 | 1503 |
| Backend  | 745 | 0 | 126 | 871 |

### E2E Tests
| Passed | Failed | Skipped | Total |
|--------|--------|---------|-------|
| 317 | 0 | 9 | 326 |

### Summary
- ✅ All tests passed
- Coverage: Frontend 85%, Backend 78%

### Fixes Applied
- `frontend/app/tests/unit/lib/hls-player.test.ts` - vi.hoisted()でモック修正
- `frontend/app/tests/unit/Console.test.tsx` - ページネーション形式対応

### Notes
- Backend skipped tests are eKYC related (expected)
- E2E skipped tests are environment-specific

---
```

## Container Execution Policy

すべてのテストはコンテナ内で実行する。ホストマシンでの直接実行は禁止。

### Why Container Execution?
- 環境の一貫性を保証
- ホストマシンへの影響を防止
- 本番環境との差異を最小化
- チーム間での再現性を確保

### Container Test Commands

```bash
# Frontend (Unit Test)
docker-compose exec frontend npm run test
docker-compose exec frontend npx vitest run --coverage

# Backend (Unit Test)
docker-compose exec backend pytest --cov=src -v

# E2E Test
docker-compose exec e2e npx playwright test
# or
docker-compose run --rm e2e-runner npx playwright test
```

### Container Configuration Example

```yaml
# docker-compose.yml
services:
  frontend:
    build: ./frontend
    volumes:
      - ./frontend:/app
    command: npm run dev

  backend:
    build: ./backend
    volumes:
      - ./backend:/app
    command: python -m uvicorn main:app

  # テスト専用コンテナ (オプション)
  test-runner:
    build: ./frontend
    volumes:
      - ./frontend:/app
    profiles: ["test"]
    command: npm run test

  e2e-runner:
    build:
      context: ./e2e
      dockerfile: Dockerfile
    volumes:
      - ./e2e:/app
    profiles: ["test"]
    depends_on:
      - frontend
      - backend
```

## Usage Examples

### Full Test Cycle
```
User: このプロジェクトのテストを実行して
Claude: [test-orchestrator activates]
        → test-planner でテスト計画作成
        → unit-runner でユニットテスト実行
        → e2e-runner でE2Eテスト実行
```

### Unit Test Only
```
User: ユニットテストだけ実行して
Claude: [unit-runner sub-agent activates]
        → ユニットテスト実行とカバレッジ測定
```

### Plan Only
```
User: テスト計画を作成して
Claude: [test-planner sub-agent activates]
        → テスト項目文書を作成
```
