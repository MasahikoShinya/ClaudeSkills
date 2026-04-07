/**
 * テスト結果ディレクトリからHTMLプレイヤーを生成するスクリプト。
 * test-results/ 内の .webm 動画と screenshots/ 内の画像を収集し、
 * シナリオ一覧付きの player.html を出力する。
 *
 * Usage: npx tsx generate-player.ts
 */
import * as fs from 'fs';
import * as path from 'path';

const TEST_RESULTS_DIR = path.resolve(__dirname, 'test-results');
const SCREENSHOTS_DIR = path.join(TEST_RESULTS_DIR, 'screenshots');
const OUTPUT_PATH = path.join(TEST_RESULTS_DIR, 'player.html');

interface Scenario {
    name: string;
    videoPath: string;
    screenshots: { name: string; path: string }[];
}

function collectScenarios(): Scenario[] {
    const scenarios: Scenario[] = [];

    if (!fs.existsSync(TEST_RESULTS_DIR)) return scenarios;

    // test-results 直下のディレクトリから動画を収集
    const entries = fs.readdirSync(TEST_RESULTS_DIR, { withFileTypes: true });
    for (const entry of entries) {
        if (!entry.isDirectory() || entry.name === 'screenshots') continue;

        const videoPath = path.join(TEST_RESULTS_DIR, entry.name, 'video.webm');
        if (!fs.existsSync(videoPath)) continue;

        // ディレクトリ名からシナリオ名を抽出 (末尾の -chromium 等を除去)
        const scenarioName = entry.name.replace(/-chromium$|-firefox$|-webkit$/, '');

        // シナリオに紐づくスクリーンショットを収集
        const screenshots: { name: string; path: string }[] = [];

        // 1. screenshots/{シナリオ名}/ ディレクトリがあればそこから
        const scenarioScreenshotDir = path.join(SCREENSHOTS_DIR, scenarioName);
        if (fs.existsSync(scenarioScreenshotDir)) {
            const files = fs.readdirSync(scenarioScreenshotDir)
                .filter(f => /\.(png|jpg|jpeg)$/i.test(f))
                .sort();
            for (const file of files) {
                screenshots.push({
                    name: file.replace(/\.(png|jpg|jpeg)$/i, ''),
                    path: `screenshots/${scenarioName}/${file}`,
                });
            }
        }

        // 2. なければ screenshots/ 直下のファイルを共通スクリーンショットとして収集
        if (screenshots.length === 0 && fs.existsSync(SCREENSHOTS_DIR)) {
            const files = fs.readdirSync(SCREENSHOTS_DIR, { withFileTypes: true })
                .filter(f => f.isFile() && /\.(png|jpg|jpeg)$/i.test(f.name))
                .map(f => f.name)
                .sort();
            for (const file of files) {
                screenshots.push({
                    name: file.replace(/\.(png|jpg|jpeg)$/i, ''),
                    path: `screenshots/${file}`,
                });
            }
        }

        scenarios.push({
            name: scenarioName,
            videoPath: `${entry.name}/video.webm`,
            screenshots,
        });
    }

    return scenarios.sort((a, b) => a.name.localeCompare(b.name));
}

function generateHtml(scenarios: Scenario[]): string {
    const scenariosJson = JSON.stringify(scenarios);

    return `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<title>E2E Visual Verify — Player</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #0f0f23; color: #e0e0e0; font-family: 'Segoe UI', sans-serif; }

  .container { max-width: 1200px; margin: 0 auto; padding: 24px; }

  /* ビデオ */
  .video-section { text-align: center; margin-bottom: 16px; }
  video { max-width: 100%; max-height: 60vh; border-radius: 6px; background: #000; }

  /* コントロール */
  .controls { display: flex; gap: 8px; align-items: center; justify-content: center; margin-bottom: 24px; }
  .speed-btn {
    padding: 6px 14px; border: 1px solid #444; border-radius: 4px;
    background: transparent; color: #ccc; cursor: pointer; font-size: 13px;
    transition: all 0.2s;
  }
  .speed-btn:hover { border-color: #e94560; color: #e94560; }
  .speed-btn.active { background: #e94560; border-color: #e94560; color: #fff; }

  .shortcuts { font-size: 12px; color: #555; text-align: center; margin-bottom: 32px; line-height: 1.8; }
  kbd {
    background: #1a1a2e; padding: 2px 6px; border-radius: 3px; border: 1px solid #444;
    font-family: monospace; font-size: 11px;
  }

  /* シナリオ一覧 */
  .scenario-list { border-top: 1px solid #333; padding-top: 24px; }
  .scenario-list h2 { font-size: 14px; color: #888; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 16px; }

  .scenario {
    margin-bottom: 16px; padding: 12px 16px; border-radius: 6px;
    background: #1a1a2e; cursor: pointer; transition: background 0.2s;
  }
  .scenario:hover { background: #2a2a4a; }
  .scenario.active { border-left: 3px solid #e94560; }

  .scenario-header { display: flex; align-items: center; justify-content: space-between; }
  .scenario-name { font-size: 15px; font-weight: 600; }
  .scenario-play { font-size: 12px; color: #e94560; }

  /* スクリーンショット */
  .screenshot-list { display: flex; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
  .screenshot-item {
    display: flex; align-items: center; gap: 6px;
    font-size: 12px; color: #888; cursor: pointer; transition: color 0.2s;
  }
  .screenshot-item:hover { color: #e94560; }
  .screenshot-item::before { content: '📷'; }

  /* スクリーンショット拡大モーダル */
  .modal-overlay {
    display: none; position: fixed; inset: 0; z-index: 100000;
    background: rgba(10,10,30,0.92); justify-content: center; align-items: center;
    cursor: pointer;
  }
  .modal-overlay.visible { display: flex; }
  .modal-overlay img { max-width: 90vw; max-height: 90vh; border-radius: 6px; }
</style>
</head>
<body>

<div class="container">
  <div class="video-section">
    <video id="player" controls autoplay></video>
  </div>

  <div class="controls">
    <span style="color:#888;font-size:13px;">Speed:</span>
    <button class="speed-btn" data-speed="0.25">0.25x</button>
    <button class="speed-btn active" data-speed="0.5">0.5x</button>
    <button class="speed-btn" data-speed="1">1x</button>
    <button class="speed-btn" data-speed="2">2x</button>
  </div>

  <div class="shortcuts">
    <kbd>←</kbd> <kbd>→</kbd> 5秒スキップ &nbsp;
    <kbd>[</kbd> <kbd>]</kbd> 速度変更 &nbsp;
    <kbd>Space</kbd> 再生/停止
  </div>

  <div class="scenario-list">
    <h2>テストシナリオ</h2>
    <div id="scenarios"></div>
  </div>
</div>

<div class="modal-overlay" id="modal">
  <img id="modal-img" src="" alt="">
</div>

<script>
const player = document.getElementById('player');
const scenariosEl = document.getElementById('scenarios');
const speedBtns = document.querySelectorAll('.speed-btn');
const modal = document.getElementById('modal');
const modalImg = document.getElementById('modal-img');
const scenarios = ${scenariosJson};

player.playbackRate = 0.5;

// シナリオ一覧を描画
scenarios.forEach((s, idx) => {
    const div = document.createElement('div');
    div.className = 'scenario' + (idx === 0 ? ' active' : '');
    div.dataset.index = idx;

    let html = '<div class="scenario-header">'
        + '<span class="scenario-name">' + s.name + '</span>'
        + '<span class="scenario-play">▶ 再生</span>'
        + '</div>';

    if (s.screenshots.length > 0) {
        html += '<div class="screenshot-list">';
        s.screenshots.forEach((ss) => {
            html += '<span class="screenshot-item" data-src="' + ss.path + '">' + ss.name + '</span>';
        });
        html += '</div>';
    }

    div.innerHTML = html;
    scenariosEl.appendChild(div);
});

// 最初のシナリオを再生
if (scenarios.length > 0) {
    player.src = scenarios[0].videoPath;
}

// シナリオクリック
scenariosEl.addEventListener('click', (e) => {
    const scenarioEl = e.target.closest('.scenario');
    if (!scenarioEl) return;

    // スクリーンショットクリック
    const ssItem = e.target.closest('.screenshot-item');
    if (ssItem) {
        modalImg.src = ssItem.dataset.src;
        modal.classList.add('visible');
        return;
    }

    const idx = parseInt(scenarioEl.dataset.index);
    player.src = scenarios[idx].videoPath;
    player.play();
    document.querySelectorAll('.scenario').forEach(el => el.classList.remove('active'));
    scenarioEl.classList.add('active');
});

// モーダル閉じる
modal.addEventListener('click', () => modal.classList.remove('visible'));

// 速度ボタン
speedBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        player.playbackRate = parseFloat(btn.dataset.speed);
        speedBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
    });
});

// キーボードショートカット
const speeds = [0.25, 0.5, 1, 2];
document.addEventListener('keydown', e => {
    if (e.key === 'ArrowLeft') { player.currentTime -= 5; }
    else if (e.key === 'ArrowRight') { player.currentTime += 5; }
    else if (e.key === ' ') { e.preventDefault(); player.paused ? player.play() : player.pause(); }
    else if (e.key === '[' || e.key === ']') {
        const cur = speeds.indexOf(player.playbackRate);
        const next = e.key === ']' ? Math.min(cur + 1, speeds.length - 1) : Math.max(cur - 1, 0);
        player.playbackRate = speeds[next];
        speedBtns.forEach(b => b.classList.toggle('active', parseFloat(b.dataset.speed) === speeds[next]));
    }
    else if (e.key === 'Escape') { modal.classList.remove('visible'); }
});
</script>
</body>
</html>`;
}

// 実行
const scenarios = collectScenarios();
if (scenarios.length === 0) {
    console.error('test-results/ に動画が見つかりません');
    process.exit(1);
}

const html = generateHtml(scenarios);
fs.writeFileSync(OUTPUT_PATH, html);
console.log(`player.html を生成しました: ${OUTPUT_PATH}`);
console.log(`シナリオ数: ${scenarios.length}`);
scenarios.forEach(s => {
    console.log(`  - ${s.name} (スクリーンショット: ${s.screenshots.length}枚)`);
});
