---
name: cowork-chrome-launcher
description: Cowork で Chrome / ブラウザ操作が必要になったら、実作業の前に必ずこのスキルを使うこと。このスキルは (1) セッション冒頭で switch_browser を呼び、ユーザーに使いたい PC の Chrome で「Connect」を押してもらう明示選択フローを走らせる、(2) 必要な Chrome が起動していなければ Terminal コマンドまたは Dock ショートカット経由での起動を案内する、(3) 接続先が確定したら通常のブラウザ作業に進む、という半自動フローを提供する。Chrome Sync による他 PC への silent 誤接続、Cowork プロファイルが閉じている状態での接続失敗、拡張サービスワーカーの切断など、Cowork の Chrome 制御で頻発する「繋がらない／別 PC が動く」系の失敗を構造的に回避する。ユーザーが「Chrome で」「ブラウザで」「〇〇のサイトを開いて」「ウェブページを読んで」「スクショを撮って」「フォームに入力して」「この URL を開いて」など、Cowork のブラウザ操作を必要とする依頼をした場合、**実作業の前に必ずこのスキルを発動**すること。また「Cowork で Chrome が動かない」「プロファイルの作り方」「別 PC でも Cowork を使いたい」など環境構築系の質問が出たときも、同梱の `references/setup.md` を案内するためにこのスキルを使うこと。Claude はサンドボックスから Chrome を直接起動できない前提で、起動はユーザーの Terminal 実行 / Dock ショートカットクリック / Login Items 自動起動に委ねるが、接続先選択と誘導はこのスキルが確実に担う。
---

# Cowork Chrome Launcher

Cowork の Chrome 制御で頻発する「silent な他 PC 誤接続」「Chrome が閉じていて繋がらない」問題を、**セッション冒頭での明示選択**と**起動手段の明確な案内**で解消する運用スキル。

## ⚠️ 最重要ルール（最初に読むこと）

**Claude は自分では Chrome を起動できない。** サンドボックスの外にあるユーザーの Chrome アプリに対して、以下はすべて**不可能**なので試さない：

- Bash で `open` / `chrome.exe` などを叩く → サンドボックス内 Linux が動くだけで Mac/Windows には届かない
- `mcp__Claude_in_Chrome__switch_browser` を呼んだだけで Chrome が起動するわけではない（switch_browser は「既に起動中の拡張を選ぶ」ツール）
- プラグインや MCP を検索する → このスキルが提供する以上の起動手段はない
- `request_cowork_directory` などで Chrome を探す → 用途違い

**Chrome の起動は常にユーザーの手元の動作（Terminal コマンド / Dock ショートカット / Login Items による自動起動）に委ねる。** スキルの仕事は「何を起動すべきか」を明確に指示することに限定される。

**`computer://` リンクで .command / .bat を実行する手法は Cowork の実装上、信頼できない。** 過去のテストでクリックしても実行まで至らなかった事例があるため、スキルからこの手段に依存しない。Terminal コマンドの提示、または事前登録済みの Dock アイコンの利用を案内すること。

## 背景：なぜこのスキルが必要か

Cowork の Chrome 制御は `Claude for Chrome` 拡張を経由するため、以下のような運用上の落とし穴がある。

- **Chrome Sync によるクロスデバイス誤接続** — 同一 Anthropic アカウントに複数 PC の Claude 拡張が紐付いていると、Cowork がどの PC の Chrome を掴むかが決定論的でない（既知：[anthropics/claude-code#42660](https://github.com/anthropics/claude-code/issues/42660)）
- **`tabs_context_mcp` は silent 成功しうる** — どの PC に繋がったかを応答に含めず、誤接続を検知できないまま navigate まで進んでしまう
- **Cowork プロファイルのウィンドウが閉じていると接続不可** — 拡張がアクティブな Chrome ウィンドウが存在しないと Cowork は繋がらない
- **サービスワーカーのアイドル切断** — 長時間放置で拡張が寝る

このスキルは、**セッション冒頭で `switch_browser` を呼んでユーザーに明示選択させる**ことで silent 誤接続を根本から排除する。

## Activation Triggers

以下のいずれかに該当する発話・状況で発動する。

- ブラウザ／Chrome 関連の操作依頼： "Chrome で", "ブラウザで", "サイトを開いて", "ウェブページを読んで", "スクショを撮って", "フォームに入力して", "この URL を開いて"
- `mcp__Claude_in_Chrome__*` 系ツールを呼ぼうとしている直前
- Cowork の Chrome 設定に関する質問： "Cowork で Chrome が動かない", "プロファイルの作り方", "Cowork Chrome のセットアップ", "別 PC でも使いたい"

## Execution Protocol

### Phase 1: 接続先の明示選択

**セッション内で Chrome 操作が初めて必要になったら、必ずこの Phase を実行する。** 同一セッション内で2回目以降の Chrome 操作では再実行不要（接続先は sticky に保持される）。

#### Phase 1a: `switch_browser` を呼ぶ

```
mcp__Claude_in_Chrome__switch_browser を引数なしで呼ぶ
```

応答に応じて3分岐：

**分岐 1：broadcast 成功（複数候補があって選択待ち）**

全候補の Chrome 拡張に Connect ボタンが一斉に表示される。ユーザーに以下を伝える：

> 両 PC の Chrome に「Connect」ボタンが出ました。今セッションで使いたい側の PC の Chrome で、ツールバーの Claude 拡張アイコン（右上のオレンジ色、または右上のパズルピース型から展開）をクリックし、パネル内の「**Connect**」ボタンを押してください。押した PC がこのセッションの接続先になります。押したら「押した」と教えてください。

ユーザーが「押した」と返答したら Phase 1b へ。

**分岐 2：`No other browsers available to switch to` エラー**

候補が1つしかない状態。Cowork は既にその1つの Chrome に繋がっている。次を伝える：

> 現在 Cowork が認識している Chrome は1つだけです。もしそれが使いたい PC のものなら、そのまま作業を進められます。違う PC の Chrome を使いたい場合は、使いたい側の PC で Cowork プロファイル Chrome を起動してから再試行してください（起動方法は Phase 2B 参照）。
>
> 今の1つを使って進めてよいですか？（Yes なら Phase 3 へ、No なら Phase 2B へ）

**分岐 3：`Claude in Chrome is not connected` エラー**

どの PC の Chrome にも拡張アクティブなウィンドウが無い。Phase 2B へ進む。

#### Phase 1b: 接続確認

```
mcp__Claude_in_Chrome__tabs_context_mcp を createIfEmpty: true で呼ぶ
```

成功すれば Phase 3 へ。エラーなら対応する Phase 2X へ。

### Phase 2A: 複数拡張接続エラー（Connect 選択待ち）

Phase 1a を通常通り踏んだ場合はここに来ないが、念のため保険として残す。`Multiple Chrome extensions connected` エラーが返ってきた場合、Phase 1a の分岐1と同じ案内をする（Connect ボタンのクリック依頼）。

### Phase 2B: 拡張未接続（Chrome を起動する必要がある）

使いたい PC の Cowork プロファイル Chrome が起動していない、または拡張がインストールされていない。

#### 手順

1. **ユーザーの OS を確認** — 会話の文脈から Mac か Windows か分からない場合は「Mac ですか Windows ですか」と一行で聞く
2. **起動方法を優先度順に案内**（ユーザーの環境に合わせて1つ選ばせる）
3. **ユーザーが「起動した」と返答したら Phase 1a を再実行**

#### Mac の場合の案内メッセージ例（そのまま使って良い）

> Cowork プロファイル Chrome が起動していません。以下のいずれかの方法で起動してください（楽な順）：
>
> **方法1: Dock ショートカット（事前に登録済みの場合）**
> Dock に「Cowork Chrome 起動」アイコンを登録していればクリック1発で起動します。
>
> **方法2: Terminal コマンド**
> ターミナル（Spotlight で「ターミナル」検索）を開いて以下を貼り付け→Enter：
>
> ```
> ~/Git/ClaudeSkills/cowork-chrome-launcher/scripts/open-cowork-chrome.command
> ```
>
> **方法3: Finder からダブルクリック**
> Finder で `~/Git/ClaudeSkills/cowork-chrome-launcher/scripts/` に移動し、`open-cowork-chrome.command` をダブルクリック。
>
> 初回は macOS Gatekeeper の警告が出ることがあります。その場合は「システム設定 → プライバシーとセキュリティ」で下の方の「このまま開く」をクリックして許可してください。
>
> Cowork プロファイル Chrome が立ち上がったら教えてください。接続先選択に進みます。

#### Windows の場合の案内メッセージ例

> Cowork プロファイル Chrome が起動していません。以下のいずれかの方法で起動してください：
>
> **方法1: スタートアップ登録済みの場合**
> 登録してあればログイン直後に自動起動しているはず。タスクバーの Chrome を確認してください。
>
> **方法2: ダブルクリック起動**
> Explorer で `%USERPROFILE%\Git\ClaudeSkills\cowork-chrome-launcher\scripts\` に移動し、`open-cowork-chrome.bat` をダブルクリック。
>
> **方法3: PowerShell から実行**
>
> ```
> & "$env:USERPROFILE\Git\ClaudeSkills\cowork-chrome-launcher\scripts\open-cowork-chrome.bat"
> ```
>
> 初回は Windows SmartScreen の警告が出ることがあります。「詳細情報」→「実行」で進めてください。
>
> Cowork プロファイル Chrome が立ち上がったら教えてください。接続先選択に進みます。

### Phase 2C: その他のエラー

一過性のネットワーク／名前付きパイプ競合の可能性がある。1〜2回リトライ、それでもダメなら Claude デスクトップアプリの再起動を案内する。

### Phase 3: 通常作業

`tabs_context_mcp` で既存タブを把握したうえで、`navigate` / `read_page` / `form_input` 等の MCP ツールで依頼された作業を進める。**Phase 1 を踏まずに突然 `navigate` から叩かないこと**。silent 誤接続の原因になる。

## セッション中の接続先切り替え

作業の途中で「やっぱり別 PC で使いたい」という場合は、再度 `switch_browser` を呼んで Phase 1a と同じ手順を踏む。sticky な接続先が上書きされる。

## セットアップ系の質問が来た時

「Cowork の Chrome セットアップ」「プロファイルの作り方」「別 PC でも使いたい」「閉じた Chrome を楽に起動したい」系の質問が来た場合は、`references/setup.md` の該当セクションを読んで回答する。主な内容：

- アカウントなし Chrome プロファイル（Cowork 専用）の作成手順
- Claude for Chrome 拡張のインストール／メインプロファイルからの削除
- Login Items / スタートアップフォルダへの起動スクリプト登録（自動起動化）
- **Dock ショートカットによるワンクリック起動**（Chrome を閉じた時の復旧用）
- Automator で `.app` 化するオプション
- Chrome Sync による誤接続の回避方針

詳細は [`references/setup.md`](./references/setup.md) を参照。

## スクリプト同梱物

`scripts/` に Mac / Windows 両対応の起動スクリプトを置いている。どちらも Chrome の `Local State` JSON を**case-insensitive に**読んで「Cowork」「cowork」等の表示名を持つプロファイルの内部ディレクトリ（`Profile 1`、`Profile 2` など）を自動検出し、そのプロファイルで Chrome を起動する。

- **Mac**: `scripts/open-cowork-chrome.command`（実行権限付与済み、Terminal 実行 / Dock 登録 / Finder ダブルクリックのいずれでも可）
- **Windows**: `scripts/open-cowork-chrome.bat`（ダブルクリック / PowerShell 実行可）

プロファイル名を変えている場合はスクリプト冒頭の `PROFILE_NAME` を書き換える（case-insensitive 比較なので大文字小文字の違いは気にしなくていい）。

## ケース別のまとめ（判断のチートシート）

セッション冒頭で Phase 1a を呼んだ結果から状況を特定：

| Phase 1a の結果 | 状態 | 次のアクション |
|---|---|---|
| Broadcast 成功（Connect ボタン待ち） | 両 PC で拡張アクティブ | ユーザーに Connect クリックを依頼（分岐1） |
| `No other browsers available` | 候補が1つだけ | その1つで進めてよいかユーザーに確認（分岐2） |
| `Claude in Chrome is not connected` | どの Chrome も拡張アクティブでない | Phase 2B で起動を案内（分岐3） |

## アンチパターン集（やってはいけない）

過去のセッションで観測された失敗パターン。同じ罠にハマらないこと。

1. **`switch_browser` が Chrome を起動してくれると誤解する** — `switch_browser` は「起動中の拡張から1つを選ぶ」だけ。Chrome が起動していない状態では「No other browsers」エラーが返るだけで、勝手に立ち上げてはくれない
2. **Bash で `open -a "Google Chrome"` や `chrome.exe` を実行する** — サンドボックス内 Linux で走るだけでユーザーの Mac/Windows には届かない
3. **プラグインや MCP を検索して起動手段を探し回る** — このスキル以外に起動手段はない、無駄に context を食うだけ
4. **`computer://` リンクで .command / .bat を起動しようとする** — Cowork の実装上、クリックで実行まで至らない（テスト済み）。代わりに Terminal コマンドを提示するか、事前登録済みの Dock ショートカットを案内する
5. **Phase 1 をスキップしていきなり `navigate` を叩く** — silent に他 PC に繋がって誤接続が起きる
6. **パスだけ提示して「ダブルクリックしてください」で終わる** — ユーザーがパスをどう開くか分からなくなる。必ず Terminal コマンド or Dock ショートカットの「クリックで起動する方法」を具体的に提示
7. **ユーザーに OS を聞かず適当なスクリプトを案内する** — Mac なのに .bat を渡す、逆も然り

## 注意事項

- Claude サンドボックスから直接 Chrome を起動する手段はない（最重要ルールの再掲）
- Phase 1a を毎セッション最初に呼ぶことで silent 誤接続を構造的に防ぐ。これはスキルの中核の設計判断
- 両 PC で Cowork を使う運用では、各セッション開始時に1回 Connect クリックが発生するが、それが silent 誤接続を排除する代償
- Anthropic が将来 Issue #42660 を解決して「特定 PC へのピン留め」機能を導入した場合、Phase 1a は不要になる可能性がある
- スクリプトの `PROFILE_NAME` は case-insensitive 比較なので、「Cowork」「cowork」「COWORK」どれでも動く
