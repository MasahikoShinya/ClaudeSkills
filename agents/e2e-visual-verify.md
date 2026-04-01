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
import { injectCursor, ensureCursor, slowClick, pause, screenshot } from '<utils-path>/demo-utils';

test.use({
    video: { mode: 'on', size: { width: 1280, height: 720 } },
    viewport: { width: 1280, height: 720 },
});

test.describe('シナリオ名', () => {
    test.beforeEach(async ({ page }) => {
        await page.waitForLoadState('networkidle');
        await injectCursor(page);
    });

    test('テスト名', async ({ page }) => {
        await page.goto('/target-page');
        await ensureCursor(page);
        await pause(page, 1500);
        await screenshot(page, '01-initial');

        await slowClick(page, page.locator('[data-testid="action-button"]'));
        await pause(page, 1000);
        await screenshot(page, '02-after-action');
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
3. テスト実行（Playwright）
4. スクリーンショットディレクトリの整理
5. HTMLプレイヤーの生成
6. **プレイヤーをブラウザで自動オープン**（`open` コマンドで player.html を開く）
7. 素材一覧をメインコンテキストに返す

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
