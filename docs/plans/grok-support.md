# Grok 対応の計画（下書き）

## 目的

xAI の Grok を AgentSkills の利用ランタイムおよび staged-diff の独立 LLM reviewer として選択可能にする。既存の Claude Code、Codex、Gemini 利用者の挙動、既存キャッシュ、および review gate の判定を変えない。

## 現状

- 共通の rules と prompt は `.agentskills/` 経由で提供され、疑似コマンドは特定クライアントの正式 command ではない。そのため、Grok に同じ rules/prompt を読み込ませられれば `::plan`、`::resolve` などの手順自体は移植できる。
- Skill の入口は現在 `claude/skills/`、`codex/skills/`、`gemini/commands/` のみ。Grok 用の読み込み形式やインストール手順はない。
- `common/reviewers/review-staged-diff.sh` は `codex exec`、Codex 用 model 列、`codex-*` のキャッシュ／実行記録を前提にする。従って Grok を reviewer にするには runtime の抽象化が必要。
- xAI API は OpenAI 互換 REST API、JSON Schema による Structured Outputs、クライアント側 Function Calling を提供する。reviewer ではローカル実行を許可せず、API に staged diff と必要な指示だけを渡す。

## 提案する振る舞い

### 対象範囲

1. Grok 用の prompt-bundle を新設する。
   - `grok/README.md` に、Grok の Project / API system prompt に読み込ませるファイル、疑似コマンドはテキスト入力であること、利用できないローカル操作を明記する。
   - `grok/rules/` または単一の loader 文書から `common/rules/AGENTS.base.md` と必要な `common/prompts/*.md` を参照する。
   - API/チャット双方で使えるよう、ベンダー固有の tool syntax は共通本文に混ぜない。

2. reviewer runtime を `codex` 固定から選択式にする。
   - Git ローカル設定 `agentskills.reviewRuntime` を導入し、値は `codex`（既定）、`grok`、`manual` を許可する。未設定は現行どおり `codex`。
   - `AGENT_MODELS.md` に Grok 行を追加し、Review / Review escalation のモデル名を設定可能にする。
   - 共通の result schema、severity 判定、risk escalation、timeout、キャッシュ再利用の条件は変えない。runtime 名を cache path、run-state、表示に含め、Codex と Grok の結果を混在させない。
   - Grok 実行時は `XAI_API_KEY` を必須にし、`curl` と `jq` で xAI Responses API を呼ぶ。モデルは設定値、未設定時は安全な明示モデルまたは明確な設定不足として扱う（実装時に xAI の提供モデルを公式文書で再確認して決定する）。
   - Structured Outputs に既存 `review-result.schema.json` 相当の JSON Schema を要求し、レスポンスを既存 validator へ渡す。API 応答の transport wrapper からモデル出力 JSON を抽出するアダプターを置く。
   - Grok reviewer に Web/X search、Code Interpreter、Function Calling、MCP は渡さない。入力は reviewer prompt、必要なプロジェクト文書、staged diff に限定し、外部送信されることを実行開始時に表示する。

3. gate とフォールバックを runtime-aware にする。
   - `check-llm-review.sh` の失敗メッセージを、設定済み runtime と選択可能な手動レビュー手順に合わせる。
   - Grok API の認証不足、HTTP エラー、timeout、schema 不一致は `FAIL` とし、commit を止める。既存の `AGENTSKILLS_SKIP_LLM_REVIEW=1` と `record-manual-review.sh --runtime grok --status OK` は引き続き利用できる。

4. ドキュメントとテストを追加する。
   - README の対応ランタイム表、導入例、API キーの安全な設定方法（環境変数のみ、Git に保存しない）を更新する。
   - shell tests で runtime 未設定時の Codex 互換性、Grok の要求ヘッダー／request body、成功 JSON、API 失敗、timeout、cache 分離、無効 runtime を確認する。HTTP は fixture の `curl` stub で検証し、実 API は CI に呼ばない。

### 非対象

- Grok Web / モバイルアプリにネイティブな slash command やローカルファイル編集権限を実装すること。
- xAI の server-side tools、Remote MCP、Web/X Search を review gate で有効にすること。
- API キー管理、課金、xAI アカウント作成を自動化すること。
- 既存 Codex reviewer の削除・仕様変更、またはデフォルト runtime の変更。

## 代替案

| 案 | 内容 | 判断 |
|---|---|---|
| A | Grok 用の文書だけを追加し、reviewer は手動 attestation に留める | 最小だが、既存の自動 gate と統合できない。暫定導入には可。 |
| B | Grok API adapter と runtime 選択を追加する | 推奨。独立レビューを既存の schema と gate に統合できる。 |
| C | Grok に Remote MCP でローカル Git / shell を渡す | 権限・データ送信・再現性のリスクが大きく、reviewer の read-only 要件にも過剰。採用しない。 |

## 実装の段取り

1. xAI の Responses API のモデル名、Structured Outputs の request/response 形式、rate limit を公式 docs で固定し、adapter の入出力を決める。
2. `review-common.sh` に runtime の検証、model 取得、runtime を含む cache/run artifact 命名を追加する。既存 Codex のパスと出力を回帰させない。
3. Grok HTTP adapter を追加し、API key をログ・state・エラー出力へ一切出さない。HTTP body は一時ファイル、終了時削除とする。
4. `review-staged-diff.sh` と `check-llm-review.sh` を選択 runtime に配送する形へリファクタリングし、manual fallback を更新する。
5. `AGENT_MODELS` template、README、Grok loader 文書、設計書を更新する。
6. fixture による shell test と既存 `common/tests/run-tests.sh` を実行する。任意の手動確認は、専用の低機密テスト repo で `XAI_API_KEY` を環境変数から渡して行う。

## リスクと対策

- 機密性: staged diff と brief が xAI に送信される。runtime は opt-in のままにし、開始ログで送信対象を表示する。秘密情報を含む差分での実行禁止も README に記載する。
- 出力互換性: API の JSON wrapper やモデルの出力が schema を満たさない可能性がある。Structured Outputs と既存 `jq` validator を二重で用い、不正な結果は review 成功としてキャッシュしない。
- コスト／待ち時間: API 呼び出しは課金と遅延を伴う。既存 timeout、OK result の diff-hash cache、リスク閾値を維持する。
- モデル変更: xAI の提供モデル名や API の仕様は変動する。モデル名をリポジトリへ固定せず、設定ファイルから指定可能にする。
- プロンプトインジェクション: diff とリポジトリ内容を不信頼なデータとして扱う既存の reviewer prompt を維持し、ツールを渡さない。

## 検証

- `bash common/tests/run-tests.sh`
- Grok runtime の fixture tests: request schema、Authorization header を伏せたログ、正常結果、HTTP failure、timeout、invalid JSON、cache/runtime separation。
- Codex runtime の既存 fixture tests: 未設定時に同じ command、cache 名、gate status になること。
- 手動 smoke test（任意）: 非機密な staged diff で `agentskills.reviewRuntime=grok`、環境変数の `XAI_API_KEY` を使い、`OK` 結果だけが cache されることを確認する。

## 未解決の判断

1. 対応範囲を「Grok API reviewer + prompt bundle」までとするか、Grok 製品側の正式 CLI / Project 機能までのネイティブ導入を待つか。
2. Grok の既定モデルを設定必須にするか、実装時点の推奨モデルを template に明記するか。
3. review runtime の選択を Git local config のみとするか、環境変数による一時上書きも許可するか（キー漏えい・再現性の観点では local config を推奨）。

## 参考

- [xAI Structured Outputs](https://docs.x.ai/developers/model-capabilities/text/structured-outputs): JSON Schema による形式保証と OpenAI 互換 API。
- [xAI Function Calling](https://docs.x.ai/developers/tools/function-calling): クライアント側の tool 呼び出しは呼び出し元が実行する仕組み。本計画では使用しない。
- [xAI Tools Overview](https://docs.x.ai/developers/tools/overview): server-side tools の概要と呼び出し課金。本計画では無効化する。
