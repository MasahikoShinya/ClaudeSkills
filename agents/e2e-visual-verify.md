---
name: e2e-visual-verify
description: E2Eテスト実行時に動画録画・スクリーンショット・カーソル可視化を組み込み、目視確認用の素材を生成するサブエージェント。test-orchestratorスキルまたはe2e-runnerから呼ばれる。
model: sonnet
---

# E2E Visual Verify Sub-Agent

E2Eテストの動画録画・スクリーンショットを管理し、人間の目視確認を効率化するサブエージェント。

## Purpose

- E2Eテストに動画録画設定を組み込む
- カーソル可視化（矢印カーソル + クリックアニメーション）の注入
- スクリーンショットの自動取得
- テスト完了後にHTMLビデオプレイヤーを生成
- 目視確認に必要な素材一覧を返す

## Output

メインコンテキストに返す情報:

```markdown
## 目視確認素材

### 動画（1シナリオ = 1動画、冒頭に検証項目一覧、末尾にpass/fail結果）
- path/to/ログインテスト-chromium/video.webm
- path/to/ユーザー登録テスト-chromium/video.webm

### スクリーンショット（シナリオごとに整理）
- test-results/screenshots/ログインテスト/01-ログイン画面表示.png
- test-results/screenshots/ログインテスト/02-入力後.png
- test-results/screenshots/ログインテスト/03-ダッシュボード遷移.png
- test-results/screenshots/ユーザー登録テスト/01-登録フォーム表示.png

### プレイヤー
- test-results/player.html（動画 + シナリオ一覧 + スクリーンショット統合）
```

## Demo Utils Module

プロジェクトの共有テストユーティリティディレクトリに `demo-utils.ts` を配置する。

### 提供する関数

| 関数 | 説明 |
|------|------|
| `injectCursor(page)` | 赤い矢印カーソルを注入（クリック時に拡大アニメーション付き） |
| `ensureCursor(page)` | ページ遷移後にカーソルが消えた場合に再注入 |
| `showTitle(page, title, checks, durationMs?)` | **動画冒頭**: テスト名と検証項目一覧を空チェックボックス付きで表示 |
| `showResult(page, title, results, durationMs?)` | **動画末尾**: 成功項目に ✓ を入れたチェックボックス、失敗は空のまま赤枠で表示 |
| `slowClick(page, locator, waitMs?)` | ホバー → 待機 → クリック（動画で操作が見える） |
| `selectFile(page, locator, file)` | filechooserイベント経由でファイル選択（実操作に近い形） |
| `pause(page, ms?)` | 指定ミリ秒待機（動画の要所で一時停止） |
| `screenshot(page, name, scenario?)` | シナリオ名を紐づけてスクリーンショットを撮る |

### demo-utils.ts 実装

```typescript
import { Page, Locator } from '@playwright/test';

export async function injectCursor(page: Page): Promise<void> {
    await page.addStyleTag({
        content: `
            .pw-cursor {
                position: fixed; width: 24px; height: 24px;
                pointer-events: none; z-index: 99999;
                transition: left 0.3s ease, top 0.3s ease;
                filter: drop-shadow(1px 1px 2px rgba(0,0,0,0.4));
            }
            .pw-cursor-click { animation: pw-click 0.3s ease; }
            @keyframes pw-click { 50% { transform: scale(1.3); filter: drop-shadow(1px 1px 4px rgba(255,0,0,0.6)); } }
        `,
    });
    await page.addScriptTag({
        content: `
            const c = document.createElement('div');
            c.className = 'pw-cursor';
            c.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
                + '<path d="M4 2L4 20L9.5 14.5L14.5 22L17.5 20.5L12.5 13L20 12L4 2Z" fill="#FF3333" stroke="#000000" stroke-width="1.5" stroke-linejoin="round"/>'
                + '</svg>';
            document.body.appendChild(c);
            document.addEventListener('mousemove', e => { c.style.left = e.clientX + 'px'; c.style.top = e.clientY + 'px'; });
            document.addEventListener('mousedown', () => { c.classList.add('pw-cursor-click'); setTimeout(() => c.classList.remove('pw-cursor-click'), 300); });
        `,
    });
}

export async function ensureCursor(page: Page): Promise<void> {
    const has = await page.evaluate(() => !!document.querySelector('.pw-cursor'));
    if (!has) await injectCursor(page);
}

/** テスト冒頭にタイトルとチェック項目をオーバーレイ表示（空チェックボックス） */
export async function showTitle(
    page: Page,
    title: string,
    checks: string[],
    durationMs = 3000,
): Promise<void> {
    await page.evaluate(
        ({ title, checks }) => {
            const overlay = document.createElement('div');
            overlay.id = 'pw-title-overlay';
            overlay.innerHTML = `
                <div style="
                    position:fixed; inset:0; z-index:100000;
                    background:rgba(10,10,30,0.92);
                    display:flex; flex-direction:column; justify-content:center; align-items:center;
                    font-family:'Segoe UI',sans-serif; color:#fff;
                ">
                    <div style="font-size:28px; font-weight:bold; margin-bottom:24px; color:#e94560;">
                        ${title}
                    </div>
                    <div style="font-size:16px; text-align:left; line-height:2;">
                        ${checks.map((c) => `<div style="display:flex;align-items:center;gap:8px;">
                            <span style="display:inline-block;width:20px;height:20px;border:2px solid #888;border-radius:3px;"></span>
                            <span>${c}</span>
                        </div>`).join('')}
                    </div>
                </div>
            `;
            document.body.appendChild(overlay);
        },
        { title, checks },
    );
    await page.waitForTimeout(durationMs);
    await page.evaluate(() => document.getElementById('pw-title-overlay')?.remove());
}

/** テスト末尾に結果をオーバーレイ表示（成功=✓入りチェックボックス、失敗=空の赤枠） */
export async function showResult(
    page: Page,
    title: string,
    results: { label: string; passed: boolean }[],
    durationMs = 3000,
): Promise<void> {
    const allPassed = results.every((r) => r.passed);
    await page.evaluate(
        ({ title, results, allPassed }) => {
            const overlay = document.createElement('div');
            overlay.id = 'pw-result-overlay';
            overlay.innerHTML = `
                <div style="
                    position:fixed; inset:0; z-index:100000;
                    background:rgba(10,10,30,0.92);
                    display:flex; flex-direction:column; justify-content:center; align-items:center;
                    font-family:'Segoe UI',sans-serif; color:#fff;
                ">
                    <div style="font-size:32px; font-weight:bold; margin-bottom:24px; color:${allPassed ? '#4ade80' : '#ef4444'};">
                        ${allPassed ? '✅ PASSED' : '❌ FAILED'} — ${title}
                    </div>
                    <div style="font-size:16px; text-align:left; line-height:2;">
                        ${results.map((r) => `<div style="display:flex;align-items:center;gap:8px;">
                            <span style="display:inline-block;width:20px;height:20px;border:2px solid ${r.passed ? '#4ade80' : '#ef4444'};border-radius:3px;text-align:center;line-height:20px;font-size:14px;color:${r.passed ? '#4ade80' : '#ef4444'};">${r.passed ? '✓' : '' }</span>
                            <span>${r.label}</span>
                        </div>`).join('')}
                    </div>
                </div>
            `;
            document.body.appendChild(overlay);
        },
        { title, results, allPassed },
    );
    await page.waitForTimeout(durationMs);
    await page.evaluate(() => document.getElementById('pw-result-overlay')?.remove());
}

export async function slowClick(page: Page, locator: Locator, waitMs = 800): Promise<void> {
    await locator.hover();
    await page.waitForTimeout(waitMs);
    await locator.click();
    await page.waitForTimeout(400);
}

export async function selectFile(
    page: Page,
    locator: Locator,
    file: { name: string; mimeType: string; buffer: Buffer },
): Promise<void> {
    await locator.hover();
    await page.waitForTimeout(800);
    const [fileChooser] = await Promise.all([
        page.waitForEvent('filechooser'),
        locator.click(),
    ]);
    await page.waitForTimeout(500);
    await fileChooser.setFiles({
        name: file.name,
        mimeType: file.mimeType,
        buffer: file.buffer,
    });
    await page.waitForTimeout(500);
}

export async function pause(page: Page, ms = 1000): Promise<void> {
    await page.waitForTimeout(ms);
}

/**
 * シナリオ名を含むディレクトリにスクリーンショットを保存する。
 * プレイヤーでシナリオごとにスクリーンショットを紐づけて表示するため、
 * scenario パラメータは必ず指定すること。
 */
export async function screenshot(
    page: Page,
    name: string,
    scenario: string,
    dir = 'test-results/screenshots',
): Promise<void> {
    const scenarioDir = `${dir}/${scenario}`;
    await page.screenshot({ path: `${scenarioDir}/${name}.png`, fullPage: true });
}
```

## Test Setup Pattern

テストファイルで以下のように設定する:

```typescript
import { test, expect } from '@playwright/test';
import { injectCursor, slowClick, pause, screenshot, showTitle, showResult } from '<utils-path>/demo-utils';

test.use({
    video: { mode: 'on', size: { width: 1280, height: 720 } },
    viewport: { width: 1280, height: 720 },
});

const SCENARIO = 'ログインテスト';

// このシナリオ内の検証項目
const checks = [
    'ログイン画面が表示される',
    'メールアドレスが入力できる',
    'パスワードが入力できる',
    'ログインボタンが押せる',
    'ダッシュボードに遷移する',
];

test.describe(SCENARIO, () => {
    test(SCENARIO, async ({ page }) => {
        await page.goto('/login');
        await injectCursor(page);

        // --- 動画冒頭: タイトル＋検証項目（空チェックボックス） ---
        await showTitle(page, SCENARIO, checks, 3000);
        await pause(page, 1000);
        await screenshot(page, '01-ログイン画面表示', SCENARIO);

        // メールアドレス入力
        await slowClick(page, page.locator('[data-testid="email"]'));
        await page.keyboard.type('user@example.com', { delay: 80 });
        await pause(page, 500);

        // パスワード入力
        await slowClick(page, page.locator('[data-testid="password"]'));
        await page.keyboard.type('password123', { delay: 80 });
        await pause(page, 500);
        await screenshot(page, '02-入力後', SCENARIO);

        // ログインボタンクリック
        await slowClick(page, page.locator('[data-testid="login-button"]'));
        await page.waitForURL('/dashboard');
        await pause(page, 1000);
        await screenshot(page, '03-ダッシュボード遷移', SCENARIO);

        // 結果判定
        const loginPageOk = true; // ページ表示確認済み
        const emailOk = true;     // 入力確認済み
        const passwordOk = true;  // 入力確認済み
        const buttonOk = true;    // クリック確認済み
        const dashboardOk = page.url().includes('/dashboard');

        // --- 動画末尾: 結果（成功=✓入り、失敗=空の赤枠） ---
        await showResult(page, SCENARIO, [
            { label: 'ログイン画面が表示される', passed: loginPageOk },
            { label: 'メールアドレスが入力できる', passed: emailOk },
            { label: 'パスワードが入力できる', passed: passwordOk },
            { label: 'ログインボタンが押せる', passed: buttonOk },
            { label: 'ダッシュボードに遷移する', passed: dashboardOk },
        ], 3500);

        // アサーション
        expect(dashboardOk).toBe(true);
    });
});
```

## Video Player Generator

テスト実行後、HTMLプレイヤーを生成して動画を閲覧しやすくする。

### 生成スクリプト

`scripts/generate-video-player.ts` を作成し、test-resultsディレクトリ内の .webm ファイルとスクリーンショットを収集してHTMLプレイヤーを生成する。

### プレイヤーの構成

```
┌──────────────────────────────────────────┐
│              動画プレイヤー                │
│          （選択中のシナリオ動画）            │
├──────────────────────────────────────────┤
│  Speed: [0.25x] [0.5x] [1x] [2x]        │
│  ← → 5秒スキップ  [ ] 速度変更  Space 再生 │
├──────────────────────────────────────────┤
│                                          │
│  ログインテスト                    [▶ 再生] │
│    📷 01-ログイン画面表示                   │
│    📷 02-入力後                            │
│    📷 03-ダッシュボード遷移                  │
│                                          │
│  ユーザー登録テスト                 [▶ 再生] │
│    📷 01-登録フォーム表示                   │
│    📷 02-入力後                            │
│    📷 03-登録完了                           │
│                                          │
│  Todo追加テスト                    [▶ 再生] │
│    📷 01-初期画面                           │
│    📷 02-追加後                            │
│                                          │
└──────────────────────────────────────────┘
```

### プレイヤーの要件:
- **レイアウト**: サイドバーなし。動画 → コントロール → シナリオ一覧の縦並び
- **シナリオ一覧**: 動画の下にテストシナリオ名を一覧表示。クリックで動画切り替え
- **スクリーンショット**: 各シナリオの下に紐づくスクリーンショットをサムネイル表示。クリックで拡大
- **デフォルト再生速度**: 0.5x
- **速度切り替え**: 0.25x, 0.5x, 1x, 2x
- **キーボードショートカット**: ← → で5秒スキップ、[ ] で速度変更
- **ダークテーマ**: 背景 #0f0f23、アイテム背景 #1a1a2e、アクセント #e94560
- **スクリーンショット収集**: `test-results/screenshots/{シナリオ名}/` から自動収集

## Execution Steps

1. プロジェクト内に demo-utils.ts が存在するか確認。なければ配置。
2. 対象テストファイルに動画録画設定（test.use）が入っているか確認。なければ追加。
3. **テスト冒頭に `showTitle()` を必ず挿入** — シナリオ名と検証項目一覧（空チェックボックス）を動画に録画する。
4. テスト実行（Playwright）
5. **テスト末尾に `showResult()` を必ず挿入** — 各検証項目の結果（成功=✓入り、失敗=空の赤枠）を動画に録画する。
6. スクリーンショットディレクトリの整理
7. HTMLプレイヤーの生成
8. **プレイヤーをブラウザで自動オープン**（`open` コマンドで player.html を開く）
9. 素材一覧をメインコンテキストに返す

### 動画内テスト情報表示（必須）

動画を見るだけでテスト内容と結果が把握できるよう、以下を**必ず**実行する:

- **冒頭（showTitle）**: テスト開始前にフルスクリーンオーバーレイでシナリオ名・検証項目一覧を空チェックボックス付きで表示
- **末尾（showResult）**: テスト完了後にフルスクリーンオーバーレイで全体の PASSED/FAILED と各検証項目のチェックボックス（成功=✓入り緑、失敗=空の赤枠）を表示
- これらはDOM上のオーバーレイなので、Playwrightの動画録画にそのまま含まれる
- **省略禁止**: この2つのステップを省くとテスト動画の価値が大幅に下がる

### Step 6: 自動オープン（必須）

テスト完了・プレイヤー生成後、必ずブラウザで開く:

```bash
# macOS
open <test-results>/player.html

# Linux
xdg-open <test-results>/player.html
```

ユーザーがすぐに目視確認を開始できるようにするため、このステップは省略しない。

## Tips

- `slowClick` の `waitMs` を調整して動画のテンポを制御
- `pause` を画面遷移後や重要な表示の前後に入れて視認性UP
- `ensureCursor` はSPA遷移後に必ず呼ぶ（ページ遷移でDOMが再構築されるため）
- `selectFile` は `setInputFiles` ではなく `filechooser` イベントを使う（クリック動作が動画に映る）
- viewport は 1280x720 以上を推奨（文字が霞まない）
