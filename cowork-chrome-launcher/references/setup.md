# Cowork 専用 Chrome プロファイルのセットアップ

Cowork が Chrome を安定して操作するための環境構築手順。**Mac でも Windows でも同じ考え方**で、使う PC すべてに同じように適用する。

## 設計方針

Cowork の Chrome 操作は `Claude for Chrome` 拡張を経由する。ここで起きる問題を3つに分けて解く。

1. **「どの PC の Chrome が操作されるか分からない」問題**
   - 同一 Anthropic アカウントに紐付いた複数 PC の拡張がクロスデバイスで候補になる
   - 解決策：**セッション冒頭で `switch_browser` を呼び、ユーザーに使いたい PC の Chrome で「Connect」を押させる**（スキルが自動化）
2. **「Cowork プロファイルのウィンドウを開くのを忘れる」問題**
   - そのプロファイルの Chrome が起動していないと拡張も動かず Cowork は繋がらない
   - 解決策：**起動スクリプトをログイン時に自動実行**、加えて**中途で閉じた時にワンクリックで復旧できる Dock ショートカットを用意**
3. **「Cowork プロファイルと通常プロファイルの混同」問題**
   - Google アカウントでログイン済みの通常プロファイルに拡張を入れると Chrome Sync で他 PC と混線
   - 解決策：**Google アカウント未ログインの専用プロファイルを作り、そこにのみ拡張を入れる**

## 手順 1: Cowork 専用 Chrome プロファイルを作る

Mac / Windows どちらも Chrome 上の操作は共通。

1. Chrome ウィンドウ右上の**プロファイルアイコン**（人型または現プロファイルのアバター）をクリック
2. 「他のプロファイル」セクションの「**+ 追加**」（Add）をクリック
3. ログイン画面で「**アカウントなしで続行**」（Continue without an account）を選ぶ ← **ここが最重要。Google アカウントにログインしない**
4. プロファイル名に「**Cowork**」と入力（大文字小文字は問わない。スクリプトが case-insensitive に対応）、色を選んで完了
5. Cowork プロファイル専用の Chrome ウィンドウが開く

## 手順 2: Cowork プロファイルに Claude 拡張をインストール

手順 1 で開いた Cowork プロファイルのウィンドウで：

1. アドレスバーに `https://chromewebstore.google.com/` を入力
2. 「Claude for Chrome」を検索して「Chrome に追加」
3. インストール後、拡張アイコンをクリックして初期セットアップ／Anthropic アカウントでサインイン

## 手順 3: 他プロファイルの Claude 拡張を無効化または削除

Cowork が間違ったプロファイル・PC の Chrome を掴まないようにする。

- メインプロファイルの Chrome で `chrome://extensions` にアクセス → Claude 拡張を**削除**または**トグル OFF**
- Cowork を使わない他 PC があれば、そちらの全プロファイルでも同様に削除または無効化
- **他 PC でも Cowork を使う場合は、その PC にも手順 1〜2 で「アカウントなし Cowork プロファイル」を作り、そちらだけに拡張を入れる**（各 PC ごとに独立した Cowork プロファイル）

## 手順 4: 起動スクリプトをログイン時に自動実行（Login Items / スタートアップ）

PC 起動時に Cowork プロファイル Chrome が自動起動する状態にする。これで「Cowork 使いたい時に Chrome が閉じている」状態を日常的には回避できる。

### Mac の場合

1. `scripts/open-cowork-chrome.command` を任意の場所に配置（例：Applications フォルダ、または `~/.claude/skills/cowork-chrome-launcher/scripts/` のまま）
2. 初回のみターミナルで実行権限を付与（リポジトリから持ってきた場合、既に付与済みのはず）：
   ```bash
   chmod +x ~/Git/ClaudeSkills/cowork-chrome-launcher/scripts/open-cowork-chrome.command
   ```
3. システム設定 → 一般 → **ログイン項目** → 「ログイン時に開く」セクションの **+** ボタン → スクリプトを選択

これでログインすると Cowork プロファイルの Chrome が自動で立ち上がる。

### Windows の場合

1. `scripts/open-cowork-chrome.bat` を任意の場所に配置
2. `Win + R` → `shell:startup` を実行してスタートアップフォルダを開く
3. そのフォルダに **.bat ファイルのショートカット**を置く（ファイル本体ではなく**ショートカット**にする）

これでサインインすると Cowork プロファイルの Chrome が自動で立ち上がる。

## 手順 5: 中途で閉じた時のワンクリック復旧手段を用意（Dock / Shortcuts）

手順 4 は「ログイン時」だけ。**セッション中に誤って Cowork プロファイル Chrome を閉じてしまった時**にワンクリックで復旧できるよう、以下のいずれかを準備しておく。

### Mac の場合：Dock ショートカット（最も簡単）

1. Finder で `scripts/open-cowork-chrome.command` を表示
2. そのファイルを Dock の**右側エリア**（ゴミ箱の左、書類ファイル用のエリア）にドラッグ＆ドロップ
3. 以後、閉じてしまった時は Dock のそのアイコンをクリック → Terminal が一瞬開いて → Cowork プロファイル Chrome が立ち上がる
4. 初回のみ Gatekeeper の警告が出ることがあるので「システム設定 → プライバシーとセキュリティ」で「このまま開く」

### Mac の場合：Automator で `.app` 化（見た目が綺麗）

Terminal のフラッシュを抑えたい場合のオプション。

1. Launchpad → その他 → Automator を起動
2. 「新規書類」→「**アプリケーション**」を選択
3. 左のアクション一覧から「**シェルスクリプトを実行**」をドラッグして中央にドロップ
4. スクリプト欄に以下を貼る：
   ```bash
   ~/Git/ClaudeSkills/cowork-chrome-launcher/scripts/open-cowork-chrome.command
   ```
5. `File → 保存` → 名前「Cowork Chrome 起動」、場所「アプリケーション」フォルダ
6. 出来上がった `.app` を Dock にドラッグして常駐
7. クリックで Chrome が立ち上がる、アイコンも綺麗

### Mac の場合：macOS Shortcuts でキーボード起動

マウス不要にしたい場合。

1. Shortcuts.app を起動 → 新規ショートカット
2. アクションに「**シェルスクリプトを実行**」を追加
3. スクリプト欄：
   ```bash
   ~/Git/ClaudeSkills/cowork-chrome-launcher/scripts/open-cowork-chrome.command
   ```
4. ショートカット名を「Cowork Chrome 起動」にし、右上の設定からキーボードショートカット（例：`Cmd + Shift + C`）を割り当て
5. キーバインドで Chrome 起動

### Windows の場合：タスクバーピン留め

1. Explorer で `open-cowork-chrome.bat` を右クリック → 「スタートメニューにピン留め」または「タスクバーにピン留め」
2. クリックで起動

## 手順 6: Claude デスクトップアプリを再起動

- Mac: Cmd+Q で完全終了 → 再起動
- Windows: タスクトレイの Claude アイコンを右クリック → 終了 → 再起動

## 手順 7: スキルのインストール（両 PC で必要）

```bash
# macOS / Linux / WSL の場合
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/MasahikoShinya/ClaudeSkills.git
ln -s ClaudeSkills/cowork-chrome-launcher cowork-chrome-launcher
```

```powershell
# Windows (PowerShell 管理者権限または開発者モード ON)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"
Set-Location "$env:USERPROFILE\.claude\skills"
git clone https://github.com/MasahikoShinya/ClaudeSkills.git
New-Item -ItemType SymbolicLink -Path "cowork-chrome-launcher" -Target "ClaudeSkills\cowork-chrome-launcher"
```

## 動作確認

新規の Cowork セッションを開き、「Chrome で Yahoo を開いて」と依頼する。期待される動作：

1. スキル `cowork-chrome-launcher` が発動
2. Phase 1a で `switch_browser` が呼ばれる
3. 使いたい PC の Chrome に Connect ボタンが出る → クリック
4. navigate が実行されて、選んだ PC の Cowork プロファイル Chrome に Yahoo が開く

## 両 PC で Cowork を使う運用パターン

各 PC で独立した Cowork セッションが走らせる前提で：

### 毎セッションの始め方

Cowork に何か Chrome 操作を頼む → スキルが自動で `switch_browser` を呼ぶ → 手元の PC で Connect クリック → 以後そのセッションは手元の PC の Chrome に固定

### 両 PC を同時に使う場合

- Mac の Cowork セッション → Mac の Chrome に Connect → Mac で作業
- Windows の Cowork セッション → Windows の Chrome に Connect → Windows で作業
- 各セッションは独立で干渉しない

### 片 PC のみを使う場合

もう片方の Cowork プロファイル Chrome を閉じておけば、Phase 1a は「No other browsers available」になり、Connect クリックなしでそのまま作業開始できる（候補が1つだけなので silent 誤接続のリスクもない）。

## プロファイル名を変更した場合

スクリプトは case-insensitive に「Cowork」「cowork」「COWORK」のいずれかの表示名を持つプロファイルを検出する。もしそれ以外の名前（例：「作業用」「仕事」）を付けた場合は、スクリプト冒頭の以下を書き換える：

- Mac: `scripts/open-cowork-chrome.command` の `PROFILE_NAME="Cowork"` を実際の名前に編集
- Windows: `scripts/open-cowork-chrome.bat` の `set "PROFILE_NAME=Cowork"` を実際の名前に編集

## トラブルシューティング

### `switch_browser` で `No other browsers available`

候補が1つだけ。それでよければそのまま作業、違う PC を使いたければ使いたい側の Cowork プロファイル Chrome を起動してから再試行。

### `Claude in Chrome is not connected`

どの PC の Cowork プロファイル Chrome も起動していない、または拡張がインストールされていない。手順 5 のワンクリック復旧手段で起動、または手順 2 の拡張インストール確認。

### Yahoo が別 PC に開いてしまう（silent 誤接続）

スキルが Phase 1a をスキップした可能性。明示的に「switch_browser を呼んで」とお願いするか、新規セッションで試す（スキルの description により自動発動するはず）。

### タブグループが同期して他 PC に出てきてしまう

Cowork プロファイルに Google アカウントでログインしてしまっている可能性。プロファイルの設定で同期を OFF にするか、プロファイルを作り直す（手順 1 の「アカウントなしで続行」を再確認）。

### 拡張は入っているのに反応しない

長時間放置で拡張のサービスワーカーが切れている。拡張アイコン → 右上「…」→「Reconnect」、または Claude デスクトップアプリ再起動。

### Dock ショートカットをクリックしても何も起きない

初回は macOS Gatekeeper が無言でブロックしている可能性。システム設定 → プライバシーとセキュリティ で下の方の「このまま開く」を探してクリック、その後再度 Dock アイコンをクリック。

## 参考

- [Claude in Chrome トラブルシューティング（公式）](https://support.claude.com/en/articles/12902405-claude-in-chrome-troubleshooting)
- [Claude in Chrome 権限ガイド（公式）](https://support.claude.com/en/articles/12902446-claude-in-chrome-permissions-guide)
- [GitHub Issue #42660 — クロスデバイス誤接続](https://github.com/anthropics/claude-code/issues/42660)
