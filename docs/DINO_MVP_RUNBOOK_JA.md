# ちび恐竜のふれあい島 — MiniMax画像8体 → MVPへの導入

> 2026-10-14 / 実験テーマ。ユーザー承認なしに本物の画像生成は行わない。
> **親Issue:** [#75](https://github.com/SMRI2170/animal-shadow-match/issues/75)
> **画像Issue:** #76〜#83（それぞれに完全な英語プロンプト）
> **MVP:** [Draft PR #67](https://github.com/SMRI2170/animal-shadow-match/pull/67) / [完成した試遊用Debug APK](https://github.com/SMRI2170/animal-shadow-match/actions/runs/38493647355/artifacts/11863076088)

## なぜ恐竜か
旧30枚はゼリー・おもちゃ・宇宙物体が混在し、幼児が「次は何が出る？」と期待する共通世界を作りにくい。対案として、明らかに異なる体形を持つ8匹の赤ちゃん恐竜に統一。表情・造形も統一し、5問後は自由に触る「ふれあい島」にする。
**仮説であり本採用決定ではない**。旧30枚のプロンプトは消さずに比較する。

## 画像仕様
- MiniMax `image-01`、独立画像1体/1回、パステルの粘土トイ、やさしい表情、画面内全身、均一クリーム背景。
- 1枚を透過PNG化し、`prepare_assets.py`で512pxカラーWebPと完全に同じアルファの影WebPを生成する。モデルには影用イラストを別生成させない。
- 96dpでの外周識別が重要（色では判別できない）。恐竜各種をリアルさ優先で再現して小さく難解にしない。
- 強い発光・牙・爪・既存IPのキャラクターそっくりの造形・複数体・背景シーンは不採用。

## 正本カタログとIssueの対応

| index (0-based) | id | プロンプトIssue | 反応 |
|---:|---|---|---|
| 0 | `dino_trex` | [#76](https://github.com/SMRI2170/animal-shadow-match/issues/76) | bounce |
| 1 | `dino_triceratops` | [#77](https://github.com/SMRI2170/animal-shadow-match/issues/77) | squish |
| 2 | `dino_stegosaurus` | [#78](https://github.com/SMRI2170/animal-shadow-match/issues/78) | wobble |
| 3 | `dino_brachiosaurus` | [#79](https://github.com/SMRI2170/animal-shadow-match/issues/79) | bounce |
| 4 | `dino_ankylosaurus` | [#80](https://github.com/SMRI2170/animal-shadow-match/issues/80) | inflate |
| 5 | `dino_parasaurolophus` | [#81](https://github.com/SMRI2170/animal-shadow-match/issues/81) | wobble |
| 6 | `dino_spinosaurus` | [#82](https://github.com/SMRI2170/animal-shadow-match/issues/82) | squish |
| 7 | `dino_pachy` | [#83](https://github.com/SMRI2170/animal-shadow-match/issues/83) | inflate |

正本は `assets/generation/minimax_dino_mvp_prompts.json`。子Issueの **MiniMax 完全生成プロンプト** は、`style` + `Object shape:` + `Material appearance:` と一致する。Issue本文のpromptを修正した場合は同時にJSONを更新する。

## 手動で生成する（最初はdry-run）
1. この変更を含むPRがmainへマージされてから [MiniMax Actions](https://github.com/SMRI2170/animal-shadow-match/actions/workflows/minimax-images.yml) を開く。
2. `theme=dino_island_mvp_8`、`start_index=0`、`count=1`、`region=intl`、**`dry_run=true`** を選び、想定どおり`dino_trex`になるか確認。
3. 利用枠とプロンプトを確認できたときだけ、`dry_run=false`へ変更し、1枚を生成する（料金・利用枠消費の可能性あり）。**このPRは一切画像生成を起動しない**。
4. 試作可能と判断できたら `start_index=0,count=4`、次に `start_index=4,count=4` の2回で8体が対象（MAX6/Run）。
5. Runの`Artifacts → minimax-review-<run_id>`から画像と`report.json`を確認。7日で期限が来るため早めに保存する。

## 採用・ゲーム反映（自動マージ禁止）
1. 色/影と輪郭を人がレビューする。背景透過が必要なため、生画像をFlutterにそのままコピーしない。
2. [#31](https://github.com/SMRI2170/animal-shadow-match/issues/31)の`promote-minimax-assets.yml`（PR #67に含まれる）をマージ後に利用できる。元の成功run idと`approved_ids`を指定し、承認された画像だけDraft PRにする。通常のエフェクト/カタログコードはPR #67の`ShadowItem`対応を使用する。
3. **画像が最低4種揃ってから**物体プールだけで2〜4択を試す。画像が足りない間は旧デモ動物のMVPでロジックを検証する。
4. 採用PRをレビュー→マージ→Androidビルド更新。既存のオフラインAPKは画像が勝手に更新されない。

## MVP検証項目
- 5問内でターゲット重複なし（画像不足時以外）／正解1つだけ／誤答無制限。
- 正解でそれぞれの`effectPreset`の動きが分かる。5体を自由に触る画面が時間制限なく遊べる。
- 360dp幅でタップの誤判定がない。怖くない・似た輪郭を誤答候補に同時表示しない。
- A/B試遊：旧動物デモと「ちび恐竜」を同じロジックで使い、初見理解と自主タップを比較する。

## 費用・セキュリティ
`dry_run=true` はMiniMaxを呼ばない。通常生成はGitHub Actions Secretsのサブスクリプション用APIキーを使い、課金枠残量を確認する。キーをIssueやPRやチャットに書かない。
