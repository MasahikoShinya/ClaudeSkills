# Agent Workflow Help

Do not modify files, Git state, configuration, or pull requests.

Display the following compact help exactly enough to identify each entry point. Replace `.agentskills/` with `common/` when the kit is used directly from the AgentSkills repository.

```text
[AgentSkills][PROMPT][START] ::help
参照: .agentskills/prompts/workflow-help.md
[AgentSkills][HELP][START]
疑似コマンド
  ::resolve <依頼>              レビュー指摘・不具合を連続で最小修正。仕様書は強制しない
  ::resolve --step <依頼>       resolveを1 Phaseだけ実行して停止
  ::resolve --reset             resolveの未完了stateを表示後、ローカル監査archiveへ退避
  ::status                      workflow・Git状態・直前publishのPRを表示
  ::ask <質問>                  質問だけに回答。調査はしても、変更・計画・タスク化はしない
  ::resume                      唯一の未完了workflowを依頼文なしで再開
  ::abort                       唯一のworkflow stateを表示後、ローカルarchiveへ退避
  ::handoff                     次回用の要約と次の一手をWORKING_MEMORYへ記録
  ::inspect <対象>              修正せず、コード・設定・テスト・ログを根拠付きで調査
  ::reproduce <不具合>          修正せず、再現条件とfailing testを証拠として作る
  ::verify <対象>               対象に適したtest・lint・buildを実行。変更しない
  ::plan <依頼>                 実装せず、仕様・方針・リスク・検証をdocs/plans/へ下書き
  ::scope                       BriefとGit差分を照合し、対象外・混在変更を検出
  ::checkpoint <名前>           Git状態・差分・workflowをローカルにスナップショット
  ::publish                     commit、push、draft PR作成を一括実行。mergeしない
  ::publish --loop              PR reviewがOKになるまで、最大3回の修正・再公開・再review
  ::sound [名前|--list]         省略=全音を順に試聴。名前=通知音変更、--list=一覧
  ::sdd_tdd <依頼>              SESSION_BRIEF仕様 -> 失敗テスト -> 実装 -> レビュー -> ゲート
  ::sdd_tdd --step <依頼>       sdd_tddを1 Phaseだけ実行して停止
  ::ui-mock       静的HTMLのUIモックを docs/ui-mocks/ に作成
  ::test-plan     test-orchestratorの計画、またはCodex fallbackで docs/test-plans/ を作成
  ::diff-review           作業ツリーと staged 差分をレビュー。変更しない
  ::subagent-review       親会話に依存しない独立レビュー。変更しない
  ::pr-review [PR]        GitHub PR を読み取り専用でレビュー
  ::failure-analysis      test / review / gate / hook の失敗原因を分析。変更しない
  ::gate                  ローカル pre-commit gate を実行
  ::help                  この一覧を表示

Git 操作によるトリガー（Hook 導入後）
  git commit            pre-commit: 空白、機密/大容量ファイル、差分警告、Codex staged-diff review
  git push              pre-push: 保護ブランチへの直接 push を確認

直接実行できる script
  bash /path/to/AgentSkills/common/setup/deploy.sh [options] TARGET  対象Gitリポジトリへ一括展開
  bash .agentskills/setup/setup-hooks.sh                    Git Hook を有効化
  bash .agentskills/reviewers/review-staged-diff.sh         Codex staged-diff review を実行
  bash .agentskills/reviewers/inspect-pull-request.sh [PR]  PR 情報、check、変更ファイルを確認
  bash .agentskills/tests/run-tests.sh                       kit の回帰テストを実行

注意: Hook は任意導入です。疑似コマンドはエージェントへの指示であり、shell command ではありません。
実行証跡: 疑似コマンドは最終行の [AgentSkills][EXECUTED] ::<command>。::gate、Hook、script = 端末の status 行。
commit 可否: 最終 GATE / HOOK が PASS なら続行可。BLOCKER / FAIL なら commit は停止。WARNING は最終 status を確認する。
review policy: auto は収束フローの SELF-REVIEW を使う。independent は外部reviewerを必須にする。
Codexセッション内でSELF-REVIEWがなければ、子Codexを起動せず即時BLOCKERになる。
既定: ::sdd_tdd / ::resolve は連続モード。仕様・対象が明確ならGateまで進める。曖昧さ、既存差分混在、検証不足、最終review WARNING/BLOCKER、最終GATE/HOOK BLOCKER/FAIL、高リスク操作では停止する。個別checkのWARNINGは最終GATE/HOOKがPASSなら表示のみ。commitはしない。
--step: 現在の1 Phaseだけを実行して停止する。次回の通常コマンドは、整合する未完了workflow stateがあれば記録済みの次Phaseから連続実行する。stateまたはSESSION_BRIEFの整合性がない場合は停止する。
使い分け:
  条件・原因・期待動作が明確な修正  → ::resolve（最小修正→検証・review・gate）
  条件・原因・期待動作のどれかが不明 → ::reproduce → ::resolve（再現証拠を固めてから修正）
  修正せずに原因候補や影響範囲を知る → ::inspect（事実と仮説を分けて調査）
  質問への回答だけが欲しい          → ::ask（必要な読み取り・検索のみ。変更しない）
  実装前に方針と範囲を固める        → ::plan（下書きのみ。タスク作成・実装はしない）
  変更後に動作・品質を確認する        → ::verify（test等を実行。差分範囲は判定しない）
  commit/PR前に差分の範囲を確認する   → ::scope（対象外・混在・未stage変更を検出）
  後で比較・参照する節目を残す        → ::checkpoint（Git状態・差分・workflowを保存）
  次の担当・次回へ作業を渡す          → ::handoff（Working Memoryに現在地と次の一手を整理）
  検証済み変更を公開用draft PRにする  → ::publish（commit・push・draft PR作成）
  修正からPR review完了まで連続実行    → ::publish --loop（最大3回。曖昧・高リスクなら停止）
  Codex通知音を確認・変更する        → ::sound（試聴。名前指定で変更、--listで一覧）

通常フロー:
  新機能・設計が未確定       → ::plan → （採用）→ ::sdd_tdd → ::scope → ::publish → ::pr-review
  明確な不具合・レビュー指摘 → ::resolve → ::scope → ::publish → ::pr-review
  条件や原因が不明な不具合   → ::inspect / ::reproduce → ::resolve → ::scope → ::publish
  作業を中断・再開する       → ::checkpoint / ::handoff → ::status → ::resume
  未完了workflowをやめる     → ::abort（resolveだけを破棄するなら ::resolve --reset）
EXECUTED がなければ疑似コマンドの実行は未確認です。失敗とは断定しません。
[AgentSkills][HELP][PASS]
[AgentSkills][PROMPT][END] ::help
[AgentSkills][EXECUTED] ::help
```
