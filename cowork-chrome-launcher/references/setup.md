# Cowork 専用 Chrome プロファイルのセットアップ

Cowork が Chrome を安定して操作するための環境構築手順。**Mac でも Windows でも同じ考え方**で、どちらか一方／両方のマシンに適用する。

## 設計方針

Cowork の Chrome 操作は `Claude for Chrome` 拡張を経由する。ここで起きる問題を2つに分けて解く。

1. **「どの PC の Chrome が操作されるか分からない」問題**
   - 同一 Google アカウントでログインした複数 PC の Chrome 全部に拡張が入っていると Cowork が混乱する
   - 解決策：**Cowork 操作用の Chrome プロファイルを Google アカウント未ログイン状態で作り、そのプロファイルだけに拡張を入れる**。メインプロファイルの同期は温存しつつ、Cowork 用環境を Chrome Sync の外に置ける
2. **「Cowork プロファイルのウィンドウを開くのを忘れる」問題**
   - そのプロファイルの Chrome が起動していないと拡張も動かず Cowork は繋がらない
   - 解決策：**起動スクリプトをログイン項目／スタートアップに登録**して自動起動

## 手順 1: Cowork 専用 Chrome プロファイルを作る

Mac / Windows どちらも Chrome 上の操作は共通。

1. Chrome ウィンドウ右上の**プロファイルアイコン**（人型または現プロファイルのアバター）をクリック
2. 「他のプロファイル」セクションの「**+ 追加**」（Add）をクリック
3. ログイン画面で「**アカウントなしで続行**」（Continue without an account）を選ぶ ← **ここが最重要。Google アカウントにログインしない**
4. プロファイル名に「**Cowork**」と入力（スクリプトのデフォルトに合わせるため）、色を選んで完了
5. Cowork プロファイル専用の Chrome ウィンドウが開く

## 手順 2: Cowork プロファイルに Claude 拡張をインストール

手順 1 で開いた Cowork プロファイルのウィンドウで：

1. アドレスバーに `https://chromewebstore.google.com/` を入力
2. 「Claude for Chrome」を検索して「Chrome に追加」
3. インストール後、拡張アイコンをクリックして初期セットアップ／サインイン（必要に応じて）

## 手順 3: 他プロファイルの Claude 拡張を無効化または削除

誤接続を防ぐため、**Cowork プロファイル以外**の Chrome から拡張を外す。

- メインプロファイルの Chrome で `chrome://extensions` にアクセス → Claude 拡張を**削除**または**トグル OFF**
- 他 PC（Windows 等）のメインプロファイルでも同様に削除または無効化
- **他 PC でも Cowork を使う場合は、その PC にも手順 1〜2 で「アカウントなし Cowork プロファイル」を作り、そちらだけに拡張を入れる**

## 手順 4: 起動スクリプトをログイン時に自動実行

### Mac の場合

1. `scripts/open-cowork-chrome.command` を任意の場所に配置（例：Applications フォルダ）
2. 初回のみターミナルで実行権限を付与：
   ```bash
   chmod +x /path/to/open-cowork-chrome.command
   ```
3. システム設定 → 一般 → **ログイン項目** → 「ログイン時に開く」の **+** → スクリプトを選択

これでログインすると Cowork プロファイルの Chrome が自動で立ち上がる。

### Windows の場合

1. `scripts/open-cowork-chrome.bat` を任意の場所に配置
2. `Win + R` → `shell:startup` を実行してスタートアップフォルダを開く
3. そのフォルダに **.bat ファイルのショートカット**を置く（本体ではなくショートカット）

これでサインインすると Cowork プロファイルの Chrome が自動で立ち上がる。

## 手順 5: Claude デスクトップアプリを再起動

- Mac: Cmd+Q で完全終了 → 再起動
- Windows: タスクトレイの Claude アイコンを右クリック → 終了 → 再起動

## 動作確認

1. Cowork プロファイルの Chrome ウィンドウが1つ以上開いていることを確認
2. Claude デスクトップアプリで「Yahoo を開いて」など依頼
3. **Cowork プロファイル側のウィンドウに Yahoo のタブが開く**こと、他 PC やメインプロファイルには影響がないことを確認

## プロファイル名を変更した場合

手順 1 で「Cowork」以外の名前（例：`CoworkMac`）を付けた場合は、起動スクリプトの冒頭を書き換える。

- Mac: `scripts/open-cowork-chrome.command` の `PROFILE_NAME="Cowork"` を編集
- Windows: `scripts/open-cowork-chrome.bat` の `set "PROFILE_NAME=Cowork"` を編集

## トラブルシューティング

### `Multiple Chrome extensions connected` が出る

- 複数の PC で Claude 拡張が有効なままになっている
- 操作したい側の Chrome で拡張アイコン → Connect
- 恒久対応は手順 3（他 PC の拡張を無効化）

### `Claude in Chrome is not connected` が出る

- Cowork プロファイルの Chrome ウィンドウが閉じている、または拡張がインストールされていない
- 起動スクリプトをダブルクリック、または手順 2 が済んでいるか確認

### タブグループが同期して他 PC に出てきてしまう

- Cowork プロファイルに Google アカウントでログインしてしまっている可能性
- プロファイルの設定で同期を OFF にするか、プロファイルを作り直す（手順 1 の「アカウントなしで続行」を再確認）

### 拡張は入っているのに反応しない

- 長時間放置で Chrome 拡張のサービスワーカーが切れている
- 拡張アイコン → 右上「…」→「Reconnect」、または Claude デスクトップアプリ再起動

## 参考

- [Claude in Chrome トラブルシューティング（公式）](https://support.claude.com/en/articles/12902405-claude-in-chrome-troubleshooting)
- [Claude in Chrome 権限ガイド（公式）](https://support.claude.com/en/articles/12902446-claude-in-chrome-permissions-guide)
- [GitHub Issue #42660 — クロスデバイス誤接続](https://github.com/anthropics/claude-code/issues/42660)
