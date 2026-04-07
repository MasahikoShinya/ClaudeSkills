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

### 動画
- path/to/video1.webm — テスト名
- path/to/video2.webm — テスト名

### スクリーンショット
- path/to/01-screenshot.png — 説明
- path/to/02-screenshot.png — 説明

### プレイヤー
- test-results/player.html（0.5x再生、キーボード操作対応）

### 確認ポイント
- [ ] 画面遷移が正しいか
- [ ] エラー表示が適切か
- [ ] データが正しく表示されているか
```

## Demo Utils Module

プロジェクトの共有テストユーティリティディレクトリに `demo-utils.ts` を配置する。

### 提供する関数

| 関数 | 説明 |
|------|------|
| `injectCursor(page)` | 赤い矢印カーソルを注入（クリック時に拡大アニメーション付き） |
| `ensureCursor(page)` | ページ遷移後にカーソルが消えた場合に再注入 |
| `showTestPlan(page, title, items)` | **動画冒頭**: テスト名と確認項目一覧をフルスクリーンオーバーレイで表示 |
| `showTestResults(page, title, results)` | **動画末尾**: 各項目の pass/fail 結果をフルスクリーンオーバーレイで表示 |
| `slowClick(page, locator, waitMs?)` | ホバー → 待機 → クリック（動画で操作が見える） |
| `selectFile(page, locator, file)` | filechooserイベント経由でファイル選択（実操作に近い形） |
| `pause(page, ms?)` | 指定ミリ秒待機（動画の要所で一時停止） |
| `screenshot(page, name, dir?)` | スクリーンショットを撮る |

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

/**
 * 動画冒頭: テスト名と確認項目一覧をフルスクリーンオーバーレイで表示し、
 * 指定秒数後に自動で消す。録画に含まれるため、動画を見るだけでテスト内容がわかる。
 */
export async function showTestPlan(
    page: Page,
    title: string,
    items: string[],
    displayMs = 4000,
): Promise<void> {
    await page.evaluate(({ title, items }) => {
        const overlay = document.createElement('div');
        overlay.id = 'pw-test-plan';
        overlay.style.cssText = `
            position: fixed; inset: 0; z-index: 100000;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%);
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            font-family: 'Segoe UI', sans-serif; color: #e0e0e0;
            animation: pw-fade-in 0.5s ease;
        `;
        const style = document.createElement('style');
        style.textContent = `
            @keyframes pw-fade-in { from { opacity: 0; } to { opacity: 1; } }
            @keyframes pw-fade-out { from { opacity: 1; } to { opacity: 0; } }
        `;
        document.head.appendChild(style);

        const heading = document.createElement('h1');
        heading.textContent = title;
        heading.style.cssText = 'font-size: 32px; margin-bottom: 32px; color: #e94560; font-weight: 700;';
        overlay.appendChild(heading);

        const label = document.createElement('div');
        label.textContent = '確認項目';
        label.style.cssText = 'font-size: 14px; color: #888; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 16px;';
        overlay.appendChild(label);

        const list = document.createElement('ol');
        list.style.cssText = 'list-style: none; padding: 0; max-width: 600px; width: 100%;';
        items.forEach((item, i) => {
            const li = document.createElement('li');
            li.style.cssText = `
                padding: 12px 20px; margin-bottom: 8px; border-radius: 8px;
                background: rgba(255,255,255,0.05); border-left: 3px solid #e94560;
                font-size: 16px; display: flex; align-items: center; gap: 12px;
            `;
            const num = document.createElement('span');
            num.textContent = String(i + 1);
            num.style.cssText = 'color: #e94560; font-weight: 700; font-size: 18px; min-width: 24px;';
            li.appendChild(num);
            const text = document.createElement('span');
            text.textContent = item;
            li.appendChild(text);
            list.appendChild(li);
        });
        overlay.appendChild(list);

        document.body.appendChild(overlay);
    }, { title, items });
    await page.waitForTimeout(displayMs);
    await page.evaluate(() => {
        const el = document.getElementById('pw-test-plan');
        if (el) {
            el.style.animation = 'pw-fade-out 0.5s ease forwards';
            setTimeout(() => el.remove(), 500);
        }
    });
    await page.waitForTimeout(600);
}

/**
 * 動画末尾: 各確認項目の pass/fail 結果をフルスクリーンオーバーレイで表示。
 * 目視確認者がテスト結果を一覧で把握できる。
 */
export async function showTestResults(
    page: Page,
    title: string,
    results: { item: string; passed: boolean; note?: string }[],
    displayMs = 5000,
): Promise<void> {
    await page.evaluate(({ title, results }) => {
        const overlay = document.createElement('div');
        overlay.id = 'pw-test-results';
        overlay.style.cssText = `
            position: fixed; inset: 0; z-index: 100000;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%);
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            font-family: 'Segoe UI', sans-serif; color: #e0e0e0;
            animation: pw-fade-in 0.5s ease;
        `;

        const heading = document.createElement('h1');
        heading.textContent = title;
        heading.style.cssText = 'font-size: 28px; margin-bottom: 12px; color: #e94560; font-weight: 700;';
        overlay.appendChild(heading);

        const passCount = results.filter(r => r.passed).length;
        const total = results.length;
        const allPassed = passCount === total;
        const summary = document.createElement('div');
        summary.textContent = allPassed ? `ALL PASSED (${total}/${total})` : `${passCount}/${total} PASSED`;
        summary.style.cssText = `
            font-size: 20px; font-weight: 700; margin-bottom: 28px; padding: 8px 24px;
            border-radius: 8px;
            background: ${allPassed ? 'rgba(0,200,100,0.15)' : 'rgba(233,69,96,0.15)'};
            color: ${allPassed ? '#00c864' : '#e94560'};
        `;
        overlay.appendChild(summary);

        const list = document.createElement('div');
        list.style.cssText = 'max-width: 650px; width: 100%;';
        results.forEach((r, i) => {
            const row = document.createElement('div');
            row.style.cssText = `
                display: flex; align-items: center; gap: 12px;
                padding: 10px 16px; margin-bottom: 6px; border-radius: 8px;
                background: rgba(255,255,255,0.04);
                border-left: 3px solid ${r.passed ? '#00c864' : '#e94560'};
            `;
            const icon = document.createElement('span');
            icon.textContent = r.passed ? '✅' : '❌';
            icon.style.cssText = 'font-size: 18px; min-width: 28px; text-align: center;';
            row.appendChild(icon);

            const num = document.createElement('span');
            num.textContent = String(i + 1);
            num.style.cssText = 'color: #888; font-size: 14px; min-width: 20px;';
            row.appendChild(num);

            const text = document.createElement('span');
            text.textContent = r.item;
            text.style.cssText = `flex: 1; font-size: 15px; color: ${r.passed ? '#e0e0e0' : '#e94560'};`;
            row.appendChild(text);

            if (r.note) {
                const note = document.createElement('span');
                note.textContent = r.note;
                note.style.cssText = 'font-size: 12px; color: #888; max-width: 200px; text-align: right;';
                row.appendChild(note);
            }
            list.appendChild(row);
        });
        overlay.appendChild(list);

        document.body.appendChild(overlay);
    }, { title, results });
    await page.waitForTimeout(displayMs);
    await page.evaluate(() => {
        const el = document.getElementById('pw-test-results');
        if (el) {
            el.style.animation = 'pw-fade-out 0.5s ease forwards';
            setTimeout(() => el.remove(), 500);
        }
    });
    await page.waitForTimeout(600);
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

export async function screenshot(page: Page, name: string, dir = 'test-results/screenshots'): Promise<void> {
    await page.screenshot({ path: `${dir}/${name}.png`, fullPage: true });
}
```

## Test Setup Pattern

テストファイルで以下のように設定する:

```typescript
import { test, expect } from '@playwright/test';
import {
    injectCursor, ensureCursor, slowClick, pause, screenshot,
    showTestPlan, showTestResults,
} from '<utils-path>/demo-utils';

test.use({
    video: { mode: 'on', size: { width: 1280, height: 720 } },
    viewport: { width: 1280, height: 720 },
});

// テスト確認項目を定義
const testItems = [
    'ページが正しく表示される',
    'ボタンクリックでアクションが実行される',
    'データが正しく更新される',
];

test.describe('シナリオ名', () => {
    test.beforeEach(async ({ page }) => {
        await page.waitForLoadState('networkidle');
        await injectCursor(page);
    });

    test('テスト名', async ({ page }) => {
        // === 動画冒頭: テスト項目一覧を表示 ===
        await showTestPlan(page, 'テスト名', testItems);

        await page.goto('/target-page');
        await ensureCursor(page);
        await pause(page, 1500);
        await screenshot(page, '01-initial');

        await slowClick(page, page.locator('[data-testid="action-button"]'));
        await pause(page, 1000);
        await screenshot(page, '02-after-action');

        // === 動画末尾: 各項目の結果を表示 ===
        await showTestResults(page, 'テスト名 — 結果', [
            { item: 'ページが正しく表示される', passed: true },
            { item: 'ボタンクリックでアクションが実行される', passed: true },
            { item: 'データが正しく更新される', passed: false, note: '値が期待値と不一致' },
        ]);
    });
});
```

## Video Player Generator

テスト実行後、HTMLプレイヤーを生成して動画を閲覧しやすくする。

### 生成スクリプト

`scripts/generate-video-player.ts` を作成し、test-resultsディレクトリ内の .webm ファイルを収集してHTMLプレイヤーを生成する。

プレイヤーの要件:
- デフォルト再生速度 0.5x
- 速度切り替えボタン（0.25x, 0.5x, 1x, 2x）
- プレイリスト（左サイド）
- キーボードショートカット（← → で5秒スキップ、[ ] で速度変更）
- ダークテーマ

## Execution Steps

1. プロジェクト内に demo-utils.ts が存在するか確認。なければ配置。
2. 対象テストファイルに動画録画設定（test.use）が入っているか確認。なければ追加。
3. **テスト冒頭に `showTestPlan()` を必ず挿入** — テスト名と確認項目一覧を動画に録画する。
4. テスト実行（Playwright）
5. **テスト末尾に `showTestResults()` を必ず挿入** — 各項目の pass/fail 結果を動画に録画する。
6. スクリーンショットディレクトリの整理
7. HTMLプレイヤーの生成
8. **プレイヤーをブラウザで自動オープン**（`open` コマンドで player.html を開く）
9. 素材一覧をメインコンテキストに返す

### 動画内テスト情報表示（必須）

動画を見るだけでテスト内容と結果が把握できるよう、以下を**必ず**実行する:

- **冒頭（showTestPlan）**: テスト開始前にフルスクリーンオーバーレイでテスト名・確認項目一覧を4秒間表示
- **末尾（showTestResults）**: テスト完了後にフルスクリーンオーバーレイで各項目の ✅/❌ 結果を5秒間表示
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
