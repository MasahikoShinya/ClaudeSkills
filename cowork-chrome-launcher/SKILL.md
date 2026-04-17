---
name: cowork-chrome-launcher
description: Cowork で Chrome / ブラウザ操作が必要になったら、実作業の前に必ずこのスキルを使うこと。このスキルは (1) Cowork 専用 Chrome プロファイルの接続状態を Chrome MCP で確認する、(2) 未接続なら同梱の起動スクリプトを computer:// リンクで提示してユーザーにクリックで起動させる、(3) 接続できたら通常のブラウザ作業に進む、という半自動フローを提供する。Chrome Sync による他 PC への誤接続、Cowork プロファイルが閉じている状態での接続失敗、拡張サービスワーカーの切断など、Cowork の Chrome 制御で頻発する「繋がらない／別 PC が動く」系の失敗を事前に検知して回避できる。ユーザーが「Chrome で」「ブラウザで」「〇〇のサイトを開いて」「ウェブページを読んで」「スクショを撮って」「フォームに入力して」「この URL を開いて」など、Cowork のブラウザ操作を必要とする依頼をした場合、**実作業の前に必ずこのスキルを発動**すること。また「Cowork で Chrome が動かない」「プロファイルの作り方」「別 PC でも Cowork を使いたい」など環境構築系の質問が出たときも、同梱の `references/setup.md` を案内するためにこのスキルを使うこと。Claude はサンドボックスから Chrome を直接起動できないが、このスキルは「ユーザーにクリックさせる computer:// リンク」を介して起動を完了させる仕組みになっている。
---

# Cowork Chrome Launcher

Cowork が Chrome を操作する前に、専用プロファイルが起動しているか確認し、未起動ならユーザーがワンクリックで起動できる形で誘導する運用スキル。

## ⚠️ 最重要ルール（最初に読むこと）

**Claude は自分では Chrome を起動できない。** サンドボックスの外にあるユーザーの Chrome アプリに対して、以下はすべて**不可能**で、試しても無駄に時間と context を消費する：

- Bash で `open` / `chrome.exe` などを叩く → サンドボックス内 Linux が動くだけで Mac/Windows には届かない
- `mcp__Claude_in_Chrome__switch_browser` を呼ぶ → これは「既に起動中の別 Chrome に接続先を切り替える」ツールで、Chrome 自体は起動できない
- プラグインや MCP を検索する → このスキルが提供する以上の起動手段はない
- `request_cowork_directory` などで Chrome を探す → 用途違い

**ユーザーに「クリックで起動してもらう」のが唯一の起動手段。** その「クリック」を成立させるのが `computer://` リンクで、このスキルの同梱スクリプトはそれで叩けるように設計されている。

## 背景：なぜこのスキルが必要か

Cowork の Chrome 制御は `Claude for Chrome` 拡張を経由するため、以下のような運用上の落とし穴がある。

- **Chrome Sync によるクロスデバイス誤接続** — 同一 Google アカウントでログインした複数 PC の Chrome に拡張が入っていると、Cowork がどの PC の Chrome を掴むか固定できない（既知：[anthropics/claude-code#42660](https://github.com/anthropics/claude-code/issues/42660)）
- **Cowork プロファイルのウィンドウが閉じていると接続不可** — 拡張が動いている Chrome ウィンドウが存在しないと Cowork は繋がらない
- **サービスワーカーのアイドル切断** — 長時間放置で拡張が切れる

## Activation Triggers

以下のいずれかに該当する発話・状況で発動する。

- ブラウザ／Chrome 関連の操作依頼： "Chrome で", "ブラウザで", "サイトを開いて", "ウェブページを読んで", "スクショを撮って", "フォームに入力して", "この URL を開いて"
- `mcp__Claude_in_Chrome__*` 系ツールを呼ぼうとしている直前
- Cowork の Chrome 設定に関する質問： "Cowork で Chrome が動かない", "プロファイルの作り方", "Cowork Chrome のセットアップ"

## Execution Protocol

### Phase 1: 接続チェック

Chrome 操作を開始する最初のツール呼び出しは、必ず `mcp__Claude_in_Chrome__tabs_context_mcp`（`createIfEmpty: true`）にする。レスポンスで分岐する：

- **成功（`availableTabs` と `tabGroupId` が返る）** → **Phase 3** へ進む（通常作業）
- **`Multiple Chrome extensions connected` エラー** → **Phase 2A** へ
- **`Claude in Chrome is not connected` エラー** → **Phase 2B** へ
- **その他のエラー** → **Phase 2C** へ

### Phase 2A: 複数拡張接続エラー（選択待ち）

複数 PC の Chrome に Claude 拡張が入っていて Cowork がどれを使うか決められない状態。ユーザーに以下を伝える（そのまま貼っても良い）：

> Chrome 拡張が複数台の PC で接続中のため、Cowork がどちらを使うか決められません。操作したい側の PC の Chrome で、ツールバーの Claude 拡張アイコン（右上のオレンジ色のアイコン、見つからなければパズルピース型のアイコンをクリックして出てくるメニュー内の Claude）をクリックし、開いたパネルの中の「**Connect**」ボタンを押してください。押したら教えてください、接続を再確認します。

ユーザーが「押した」と返答したら **Phase 1** を再実行する。

**恒久対応の案内**（Phase 2A を繰り返すようなら追加で伝える）：他 PC 側の Claude 拡張を `chrome://extensions` から OFF にしておけば、このエラーは出なくなる。

### Phase 2B: 拡張未接続エラー（起動が必要）

Cowork プロファイルの Chrome ウィンドウが閉じている、または拡張自体がインストールされていない可能性が高い。**ここがこのスキルの半自動フローの核心。**

#### 手順

1. **ユーザーの OS を確認** — 会話の文脈から Mac か Windows か分からない場合は「Mac ですか Windows ですか」と一行で聞く
2. **同梱スクリプトへの computer:// リンクを提示**（下の「リンク生成ルール」参照）。Claude 側で勝手に Bash で起動しようとしないこと
3. **ユーザーがクリックしたら Chrome ウィンドウが立ち上がる** — Mac の初回は Gatekeeper の「開発元を確認できません」系の警告が出ることを事前に予告しておき、システム設定 → プライバシーとセキュリティ → 下の方の「**このまま開く**」で許可するよう案内
4. **ユーザーが「起動した」と返答したら Phase 1 を再実行**
5. **それでも Phase 2B が再発する場合**は、スキル未セットアップの可能性が高い → `references/setup.md` を案内（プロファイル未作成／拡張未インストール）

#### リンク生成ルール（必ず守る）

- **リンクは必ず `[表示テキスト](computer://<絶対パス>)` 形式のクリック可能リンク**で提示する。パスだけ単独で書いてはいけない（ユーザーがどうやって起動するか分からなくなる）
- 絶対パスはこのスキルの同梱スクリプトの実体パスを使う。スキルディレクトリが `/sessions/<sandbox>/mnt/.claude/skills/cowork-chrome-launcher/` に見えているはずなので、以下のように組み立てる：
  - **Mac**: `computer:///sessions/<sandbox>/mnt/.claude/skills/cowork-chrome-launcher/scripts/open-cowork-chrome.command`
  - **Windows**: `computer:///sessions/<sandbox>/mnt/.claude/skills/cowork-chrome-launcher/scripts/open-cowork-chrome.bat`
  - `<sandbox>` 部分は `pwd` 等で自分のサンドボックス名を取得、または system prompt 内の skill location から流用する
- クリック時に Cowork がホストパス（ユーザーの Mac/Windows の実ファイルパス）に解決して実行してくれる

#### 提示メッセージ例（そのまま使って良い）

Mac の場合：

> Cowork プロファイルの Chrome が起動していません。こちらのリンクをクリックすると Cowork プロファイルの Chrome が立ち上がります：
>
> [Cowork プロファイルの Chrome を起動](computer:///sessions/…/scripts/open-cowork-chrome.command)
>
> **初回のみ**：Mac の Gatekeeper が「開発元を確認できません」と警告を出すことがあります。その場合は「システム設定 → プライバシーとセキュリティ」を開き、下の方にある「このまま開く」ボタンをクリックして許可してください。以後は警告なしで起動します。
>
> Chrome ウィンドウが立ち上がったら教えてください、続きの作業に進みます。

Windows の場合：

> Cowork プロファイルの Chrome が起動していません。こちらのリンクをクリックすると Cowork プロファイルの Chrome が立ち上がります：
>
> [Cowork プロファイルの Chrome を起動](computer:///sessions/…/scripts/open-cowork-chrome.bat)
>
> **初回のみ**：Windows SmartScreen が「WindowsによってPCが保護されました」と警告を出すことがあります。その場合は「詳細情報」→「実行」で進めてください。
>
> Chrome ウィンドウが立ち上がったら教えてください、続きの作業に進みます。

### Phase 2C: その他のエラー

一過性のネットワーク／名前付きパイプ競合の可能性がある。1〜2回リトライ、それでもダメなら Claude デスクトップアプリの再起動を案内する。

### Phase 3: 通常作業

`tabs_context_mcp` で既存タブを把握したうえで、`navigate` / `read_page` / `form_input` 等の MCP ツールで依頼された作業を進める。**Phase 1〜2 を経由せず突然 navigate から叩かないこと**（未接続時に不親切なエラーで止まる）。

## セットアップ系の質問が来た時

「Cowork の Chrome セットアップ」「プロファイルの作り方」「別 PC でも使いたい」系の質問が来た場合は、`references/setup.md` の該当セクションを読んで回答する。主な内容：

- アカウントなし Chrome プロファイル（Cowork 専用）の作成手順
- Claude for Chrome 拡張のインストール／メインプロファイルからの削除
- ログイン項目／スタートアップフォルダへの起動スクリプト登録（自動起動化）
- Chrome Sync による誤接続の回避方針

詳細は [`references/setup.md`](./references/setup.md) を参照。

## スクリプト同梱物

`scripts/` に Mac / Windows 両対応の起動スクリプトを置いている。どちらも Chrome の `Local State` JSON を読んで「Cowork」という表示名のプロファイル内部ディレクトリ（`Profile 1`、`Profile 2` など）を自動検出し、そのプロファイルで Chrome を起動する。

- **Mac**: `scripts/open-cowork-chrome.command`（実行権限付与済み、ダブルクリックまたは computer:// リンクで実行可）
- **Windows**: `scripts/open-cowork-chrome.bat`（ダブルクリックまたは computer:// リンクで実行可）

プロファイル名を「Cowork」以外にしている場合はスクリプト冒頭の `PROFILE_NAME` を書き換える。

## アンチパターン集（やってはいけない）

過去のセッションで観測された失敗パターン。同じ罠にハマらないこと。

1. **`switch_browser` を呼んで起動しようとする** — これは起動ツールではない。現在接続中の別ブラウザに切り替えるだけで、起動していない Chrome には無力
2. **Bash で `open -a "Google Chrome"` や `chrome.exe` を実行する** — サンドボックス内 Linux で走るだけでユーザーの Mac/Windows には届かない
3. **プラグインや MCP を検索して探し回る** — このスキル以外に起動手段はない、無駄に context を食うだけ
4. **パスだけ提示して「ダブルクリックしてください」で終わる** — ユーザーがパスをどう開くか分からない。必ず `computer://` クリック可能リンクで提示
5. **ユーザーに OS を聞かず適当なスクリプトを案内する** — Mac なのに .bat を渡す、逆も然り
6. **Phase 1 をスキップしていきなり `navigate` を叩く** — 未接続時に不親切なエラーで止まる

## 注意事項

- Claude サンドボックスから直接 Chrome を起動する手段はない（最重要ルールの再掲）
- Phase 2A のように複数接続が出る状況は、セットアップ完了後でも発生しうる（他 PC で拡張を入れ直した等）。毎回 Phase 1 で確認するのが安全
- ユーザーが「Windows 側で Cowork を使わない」と明言している場合は、Windows の Claude 拡張を無効化しておくと Phase 2A が出なくなる
