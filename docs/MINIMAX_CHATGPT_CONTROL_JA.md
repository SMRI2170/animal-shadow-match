# ChatGPTからMiniMaxの画像生成を操作する

## 現在の稼働状態（2026-10-14）

**チャット操作機能はmainに導入済みです。** [PR #34](https://github.com/SMRI2170/animal-shadow-match/pull/34) をマージ後、GitHubの本人名義コメントで [Issue #33](https://github.com/SMRI2170/animal-shadow-match/issues/33) にドライランを投稿し、[Run 38488571660](https://github.com/SMRI2170/animal-shadow-match/actions/runs/38488571660) の **Success** と report.json Artifactアップロードを確認しました。ドライランはMiniMax API未使用。**チャット経由の実課金生成はまだ未検証**で、ユーザーから実生成の依頼があった場合にのみ実施します。


## できること

このリポジトリのChatGPT連携が、会話から **画像生成プロンプトを作成してGitHub Issue #33にコメント** します。コメントが認証・検証されるとGitHub ActionsがMiniMax `image-01`で1枚を生成してArtifactに保存します。

```text
ユーザー: 「淡いミントのふわふわ雲を1枚MiniMaxで生成して」
  ↓ ChatGPTが英語の完成画像プロンプトを作成（必要ならユーザーに見せる）
  ↓ Issue #33へ /minimax {...} 形式でコメント
  ↓ GitHub Actions: 画像生成（GitHub SecretsのM Planキー）
  ↓ 出力: minimax-review-<run_id> Artifact
  ↓ ChatGPTがGitHub Runの成否・生成画像の中身を確認
  ↓ 人が採用を承認してから、別の画像取り込みワークフローでゲームへ登録
```

リポジトリ: [animal-shadow-match](https://github.com/SMRI2170/animal-shadow-match)
コメント窓口: [Issue #33](https://github.com/SMRI2170/animal-shadow-match/issues/33)
ワークフロー: [MiniMax chat commands](../.github/workflows/minimax-chat-commands.yml)

## 基本コマンド

GitHub Issue #33へ**1件のコメント**を送る。コメント本文は `/minimax ` で始まる**単一行JSON**。コメントは公開されます。APIキーを本文に書かないでください。

### 料金を使わない動作確認（推奨）

```text
/minimax {"id":"mint_cloud_01","prompt":"A single complete plush mint cloud-shaped squishy object. Soft 3D clay-toy illustration, pastel lighting, centered and fully visible on an evenly lit off-white background. Distinctive readable silhouette; no text, logo, face, animals or other objects.","category":"jelly","effectPreset":"squish","region":"intl","dry_run":true}
```

### 実際に1枚生成するとき（利用枠または追加Creditsを消費する場合あり）

```text
/minimax {"id":"mint_cloud_01","prompt":"A single complete plush mint cloud-shaped squishy object. Soft 3D clay-toy illustration, pastel lighting, centered and fully visible on an evenly lit off-white background. Distinctive readable silhouette; no text, logo, face, animals or other objects.","category":"jelly","effectPreset":"squish","region":"intl","dry_run":false,"confirm":"GENERATE_1_IMAGE"}
```

- `id`: 1〜64字の英小文字・数字・下線。英小文字から開始。画像ファイル名になるので**生成ごとに別ID**にする。
- `prompt`: 20〜1500文字。ChatGPTが英語で作成してよい。1物体・輪郭明瞭・中央配置・余白・一様な背景・顔/文字/ロゴなしを推奨。
- `effectPreset`: `squish`, `wobble`, `bounce`, `inflate` から選ぶ。省略時は `squish`。
- `category`: 英小文字・数字・下線。省略時は `squishy_object`。
- `region`: `intl` または `cn`。省略時 `intl`。
- `dry_run`: 省略時 `true`（API呼び出しなし）。`false` には **`confirm`** 必須。
- `confirm`: `dry_run=false` のときだけ正確に `GENERATE_1_IMAGE` を指定。

1回のコメントで**最大1枚**。連続生成が必要なら別々の明示的な要求で実行する。リトライも画像生成枠を消費する場合がある。

## 実行の確認

- [Actions](https://github.com/SMRI2170/animal-shadow-match/actions) で **MiniMax - ChatGPT prompt controller** を探す。
- コメントIDと実行タイミングを照合し、`Run one authenticated MiniMax prompt` の成否を確認する。
- `dry_run=true` なら `report.json` のみ。画像は生成されない。
- `dry_run=false` ならArtifact `minimax-review-<run_id>` 内のJPEG/PNG/WebPと`report.json`を確認する。
- Artifactは7日間保存。公開リポジトリなので、プロンプト/画像を機密資料として扱わない。

## セキュリティと誤課金防止

- 発火イベントは `issue_comment.created`、**#33かつSMRI2170本人の投稿のみ**。他のIssue、PR、第三者コメントからの実行は拒否。
- GitHubイベントのJSONをPythonが直接読み取る。ユーザー文字列をShell命令に補間せず、任意コマンド実行を防ぐ。
- GitHub Secret `MINIMAX_API_KEY`（`sk-cp-`形式）以外からキーを読まない。`MINIMAX_SUBSCRIPTION_ONLY=1`を継承する。
- 画像・プロンプトは未審査候補であり、**ゲームの本番プールに自動追加/マージしない**。
- 明示的な画像生成要求がない会話では、ChatGPTは有料コマンドをIssueに投稿しない。
- 一度投稿した有料コマンドは、GitHub上でワークフローを再実行すると再度課金/利用枠消費があり得る。再実行前に確認する。
- Github App/ChatGPT連携がリポジトリ所有者 `SMRI2170` の権限でコメントできることを前提とする（確認済み）。

## 仕組みの運用状態

- このワークフローの`issue_comment`は **デフォルトブランチにワークフローファイルが存在する時だけ起動する**。機能PRをマージするまではIssue #33にコメントしても自動生成しない。
- 導入後、まず `dry_run=true` のコメントでGitHub Actionsの発火を検証する。テスト成功を確認してから、有料API利用枠を使う画像生成を行う。
- 新しいカスタムIDは固定30件の `minimax_object_prompts.json` に追加されないが、生成レポートにはID・プロンプト・カテゴリー・エフェクトが保存される。現行の画像採用パイプラインは未知IDを基本の`squishy_object/squish`にフォールバックするため、元のメタデータをゲーム側に引き継ぐ実装は後続タスク。
