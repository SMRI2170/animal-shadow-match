# GitHub Actions × MiniMax 画像量産手順（2026-10-14）

## MiniMax Go (M Plan) 利用者向け — 最優先（2026-10-14）

公式[M Plan](https://www.minimax.io/m-plan)によると、**Goプランにも画像生成とAPIキー利用が含まれています**。従来の「画像生成APIは必ず別途従量課金」という説明は正確ではありません。Goプランで生成する場合はMiniMaxの **Subscription Key (通常 `sk-cp-` で始まるもの)** を利用し、**標準のPay-as-you-go API Keyを使用しない**でください。

このGitHub Actionsは `MINIMAX_SUBSCRIPTION_ONLY=1` を設定し、`sk-cp-` 以外のキーを**API通信前に拒否**します。Secret名は引き続き `MINIMAX_API_KEY` ですが、入れるのはGoプランのSubscription Keyです。キーの文字列をIssue/PR/Chatに貼らないでください。

**請求について:** Subscription KeyはGoの利用枠を先に使用し、枠を使い切ると**購入済みの追加Credits**を消費する場合があります。どのモデルがGoの残枠を使えるか・image-01の具体的な上限はアカウントのUsage表示で確認してください。**Goなら30枚が必ず追加費用ゼロという保証はありません。** 残枠が不明ならdry-runでAPI未実行を確認後、count=1のみ実行しUsage履歴を比較します。Subscription Keyが画像APIで利用不可というエラーなら、**Pay-as-you-go Keyへ切り替えず**、MiniMax公式の現在の対応モデルを確認してください。

- [M Plan公式](https://www.minimax.io/m-plan)
- [残枠・Usage](https://platform.minimax.io/)（ログイン後Usage/Plan）
- [MiniMax API有料サービス規約](https://platform.minimax.io/protocol/paid-agreement) — Subscription KeyとPay-as-you-go Keyは別。
- Run workflow: [画像候補生成](https://github.com/SMRI2170/animal-shadow-match/actions/workflows/minimax-images.yml)


**状態:** ワークフロー・生成スクリプト・30物体の候補JSON・オフラインテストを登録。**実際の生成は未検証**（GitHub Secretは本書から確認できないため、設定済みか不明。生成成功も未確認）。30候補はすべて未審査のプロンプト案。

## 何ができるか
[GitHub Actions: MiniMax - Generate object candidates](../.github/workflows/minimax-images.yml) を手動実行して、MiniMax image-01 に1枚ずつ独立した「ぷにぷに物体」の完成画像を生成。結果は7日間の Actions Artifact に保存する。手元のPCは不要。APIキーはGitHub Secretsから読み込み、ソースコード・アーティファクト・ログに書き出さない。

**重要:** 1枚の有料生成にもMiniMaxのAPI契約に応じた請求が発生し得る。Run workflowの既定値は dry_run=true（料金ゼロの検証）で、明示的にfalseにしたときだけ実際の API 呼出し。1回の実行は必ず最大6枚（サーバー側でも検査）、自動スケジュールや push/PR トリガーはない。APIの契約/残高/単価は [MiniMax Open Platform](https://www.minimax.io/platform/login) で毎回確認する。

## 1. APIキーの登録（ユーザー自身で操作）

1. MiniMax Go（M Plan）のSubscription Key（通常 `sk-cp-` で始まるもの）を取得する。**従量課金用の別のAPI Keyは登録しない**。
2. [リポジトリのActions Secrets](https://github.com/SMRI2170/animal-shadow-match/settings/secrets/actions) を開く。
3. **New repository secret** を選び、名前 `MINIMAX_API_KEY`、値にGoプランのSubscription Keyを入力。キーはIssue/PR/README/チャットに貼らない。
4. MiniMaxアカウントのリージョンに合わせて `intl`（`api.minimax.io`）または `cn`（`api.minimaxi.com`）をワークフローで指定。公式サービス以外の任意API URLは受け付けない。
5. Goの残り利用枠と追加Credits残高を確認する。Subscription Keyは枠超過時に購入済みCreditsを使う可能性があるため、初回は1枚だけ実行しUsage履歴を比較する。

## 2. 最初のテスト（課金なし）

1. [Actionsワークフロー](https://github.com/SMRI2170/animal-shadow-match/actions/workflows/minimax-images.yml) を開く。
2. **Run workflow** をクリックし、Branch=`main`、`start_index=0`、`count=2`、`region=intl`、**`dry_run=true`**（初期値）にする。
3. Runを開くと `DRY RUN` と候補IDがログに表示され、Artifact内の `report.json` に実行予定のプロンプトが残る。API呼出しなし・MiniMax料金なし。
4. 初回の検証が完了してから `dry_run=false` に変える。最初の有料生成は `start_index=0, count=1` が無難。

## 3. 30候補を量産する場合

プロンプト元: [30件の候補一覧](../assets/generation/minimax_object_prompts.json)。**0〜29のゼロ起算index** で選択。

| start_index | count | 内容 |
|---:|---:|---|
| 0 | 6 | ゼリー/グミ 1〜6 |
| 6 | 6 | ゼリー/グミ 7〜12 |
| 12 | 6 | ふしぎなおもちゃ 1〜6 |
| 18 | 6 | おもちゃ7〜10 + 宇宙/自然1〜2 |
| 24 | 6 | 宇宙/自然3〜8 |

5回とも、結果画像をダウンロードして確認してから次を実行する。**再実行は再課金の可能性**がある。画像は生成ごとに1枚、そのファイル形式に応じて `id.jpg/.png/.webp` で保存する。既定は1:1。30枚以上必要なら個別のレビューを経てプロンプトを増やす。

## 4. ダウンロード後の画像処理と採用

1. ワークフローの実行ページ下部 **Artifacts → minimax-review-<run id>** をダウンロード、解凍。
2. `report.json` に各候補のID・画像生成プロンプト・画像名・状態がある。生成画像は**まだ背景が透明ではない**。生成モデルが白い背景を描いても自動で透明にはならない。
3. 人が「1物体・全体が写っている・優しい見た目・影にしたとき識別できる・著作権/ブランド問題なし」を審査。
4. 採用画像を背景除去ツールで**透過PNG**にし、`assets/source/<id>.png`へ配置。特に輪郭の欠け・白フリンジ・細い突起を確認。
5. `python -m pip install -r scripts/requirements.txt`、次に `python scripts/prepare_assets.py --input assets/source --output assets/items`。これで**同じアルファ輪郭を使った**色つきWebPと影WebPが得られる。
6. #29に従いShadowItemカタログへ採用画像とeffectPreset（squish/wobble/bounce/inflate）を登録し、画面で確認してからコミット。

**自動生成候補をmainへコミットしない理由:** MiniMaxの画像は動物/キャラの予期せぬ混入、背景、類似輪郭、権利、幼児に不向きな形を人が見て判断する必要がある。Artifactsに一時保管し、採用されたものだけリポジトリに入れる。

## 5. テストとローカル実行

```bash
python -m pip install -r scripts/requirements.txt
python -m unittest discover -s scripts/tests -p 'test_minimax_batch.py'
python scripts/minimax_batch.py --start 0 --count 2 --dry-run
# MINIMAX_API_KEY を設定したローカル環境のみ（課金される）
python scripts/minimax_batch.py --start 0 --count 1
```

- 有料処理は**1枚につき1回の同期APIリクエスト**、続けて送る場合は7秒待機。
- URLは一時的なものになり得るため `response_format=base64` を使用し、その場でローカルファイルに保存する。モデルから受け取った有料生成結果をログへ全出力しない。
- `report.json`には機密情報は含まないが、プロンプト/物体名は含まれる。公開リポジトリのActionsと生成画像へのアクセス権を踏まえ、アーティファクトも非公開素材として想定せず運用する。
- 既存 Flutter CI は通常通りに動かす。本ワークフローは画像生成のみに限定し、Flutter本体や公開済みの画像カタログへ勝手に追加しない。

## 6. 失敗した場合

| 原因 | 対応 |
|---|---|
| `MINIMAX_API_KEY ... missing` | リポジトリSecretsに登録したかを確認。dry-runならキー不要 |
| HTTP 401/403 | 課金契約/キーのリージョン/期限をMiniMax管理画面で確認 |
| APIの非ゼロ status_code | MiniMax残高/モデル利用権/サービスの状態を確認 |
| 課金が予想より大きい | ワークフローを停止し、MiniMax側のキーを無効化。手動で再実行しない |
| 生成結果が怖い・輪郭が曖昧 | 採用しない。プロンプトを修正し、再生成は料金が増える前提で行う |
| `prepare_assets.py` の透明度エラー | 手動で背景を透過し、実際にalphaが付いたPNGを入力 |

## 公式資料

- [MiniMax公式 GitHub スクリプト](https://github.com/MiniMax-AI/skills/blob/main/skills/frontend-dev/scripts/minimax_image.py)
- [MiniMax公式 Image-01 ガイド](https://github.com/MiniMax-AI/skills/blob/main/skills/frontend-dev/references/minimax-image-guide.md)
- [GitHub Actions workflow_dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_dispatch)
- [GitHub Actions security and secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)

## 未確認事項
GoのSubscription Keyがこのアカウントに登録されたか、GitHub Actionsが実際に成功したか、image-01リクエストがGo利用枠として処理されたかは未確認。**コードをGitHubへ登録したことと、実際の生成成功や料金0円を区別する。**
