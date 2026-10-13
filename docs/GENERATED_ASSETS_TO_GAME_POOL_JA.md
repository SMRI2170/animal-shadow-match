# MiniMax生成画像をゲームの出題プールへ反映する手順（v6）

> 2026-10-14。現時点では「MiniMax画像生成 → Actions Artifact」まで実装済み、`dry_run=false`のSuccessはユーザーが報告。**実際のZIP内容・画像品質は未確認**。出題プールへの自動取り込み／PR生成は**未実装**。
> 関連: [ワンアセットゲームv6](SINGLE_ASSET_OBJECT_GAME_JA.md)、[#28 画像試作](https://github.com/SMRI2170/animal-shadow-match/issues/28)、[#29 汎用カタログ移行](https://github.com/SMRI2170/animal-shadow-match/issues/29)、[#31 承認PRパイプライン](https://github.com/SMRI2170/animal-shadow-match/issues/31)。

## 現時点で何ができるか

GitHub Actions `minimax-images.yml`を `dry_run=false` で実行すると、`minimax-review-<run_id>` というArtifactを7日間保持する。生成画像は`report.json`に記載された `<id>.png/.jpg/.webp` のいずれかで、成功した個別画像は `generated_unreviewed` というstatus。

**ZIPができたことは、ゲームに登録できたことではない。** 現行ソースコードを調べた結果:
- `lib/data/catalog_repository.dart` は `assets/catalog/animals.json` の `animals` だけを読む。
- `lib/domain/animal.dart` と `round_factory.dart` は `Animal` 固定。
- `pubspec.yaml` のアセット登録は `assets/catalog/` と `assets/animals/` のみ。
- `scripts/validate_catalog.py`も `animals.json` 専用。物体を`assets/items/`に置くだけではFlutterの出題対象にならない。
- デモの動物素材8種は移行時の回帰テストとして保持。

## すぐ取り込む（手動+PR）

1. [MiniMax Actions](https://github.com/SMRI2170/animal-shadow-match/actions/workflows/minimax-images.yml)の成功Runを開き、画面下の`Artifacts → minimax-review-<run_id>`をダウンロード。7日を過ぎると消える可能性がある。
2. ZIPを展開して`report.json`の`items[].id` / `items[].file` / `items[].status`を確認。実画像1件が`generated_unreviewed`か確認。怪しい画像、既存キャラに似た画像、影で差が出ないものは不採用。
3. 採用した元画像を手動、あるいは信頼できる背景除去ツールで透過PNGにする。現行`prepare_assets.py`は透明背景を自動生成しない。半透明エッジの白フリンジ、物体の欠損を確認。たとえば`assets/source/gel_star.png`。
4. `python -m pip install -r scripts/requirements.txt`、`python scripts/prepare_assets.py --input assets/source --output assets/items` を実行。透過PNGから色画像と影のWebPを512×512で書き出す。**2つの画像は1枚の元画像から生成**される。
5. `assets/items/gel_star.webp`と`assets/items/gel_star_shadow.webp`を追加。`assets/source/`はgitignore済みなので、元画像を残す必要がある場合は別途権利・サイズを検討する。
6. `assets/catalog/items.json`へ`id/image/shadow/category/distractors/effectPreset`等を登録する。
7. **[#29を実装することが必要**: Flutterの`Animal`固定モデル・`CatalogRepository`を`ShadowItem`対応にして`assets/catalog/items.json`をロードし、`pubspec.yaml`に`assets/items/`を追加する。**少なくとも4種類**の物体を揃えて、2〜4択や既存のCI validatorの下限に対応する（1つだけでは最終的な出題プールにできない）。
8. 汎用カタログ用の独立バリデータとWidgetテストを追加。現行の`validate_catalog.py`はanimal専用であるため、対象カテゴリ拡張が必要。`flutter pub get && flutter test`、`flutter analyze`を実行。
9. ブランチからGitHub Pull Requestを作成。変更差分に採用画像、同じ輪郭の影、カタログ、必要なコード/テストだけを含める。PRのCIと画像プレビューを人が確認し、**人がマージ**する。
10. PRのマージ後、Flutterを再ビルドしてAndroidへ再インストール/アップデートする。**GitHubのマージだけでは既存インストール済みアプリのオフライン素材は自動更新されない**。

```text
Actions generated artifact (unreviewed)
  └── gel_star.png + report.json
       ↓ 人が画像を採否判定
  assets/source/gel_star.png         ← transparent PNG, ignored by git
       ↓ prepare_assets.py
  assets/items/gel_star.webp
  assets/items/gel_star_shadow.webp
       ↓ assets/catalog/items.json + Flutter ShadowItem reading
  Pull Request → CI + visual review → merge
       ↓ new Android build
  実際の出題プールへ追加
```

## 完成形（次の開発Issue #31）

**画像生成時にそのままmainへ自動投入しない。** 独立した`workflow_dispatch`の承認ワークフローを追加する。

提案入力:
- `source_run_id` = MiniMax画像生成の元Run ID
- `approved_ids` = 取り込みたいIDのカンマ区切り（例: `gel_star,cloud_cushion`）
- `background_mode` = `auto_draft`（自動背景除去 + 視覚承認必須）または `already_transparent` （透過済みファイルを利用）。**公開への直接マージ不可**。

処理:
- 別RunのArtifactを **GitHubのrun_id/token指定でダウンロード**。権限`actions:read`。生成元Runの実行結果が`success`、同一リポジトリ、想定されたworkflowをチェック。
- `report.json`と候補IDの完全一致を検証。パストラバーサル・シンボリックリンク・拡張子偽装/巨大ファイルを拒否。Secretを成果物/PR/ログに含めない。
- 画像が未透過の場合は背景除去を試すが、ゼリー・透明なグミ・細い突起は誤除去リスクがある。**必ず元絵+透過+影のレビュー用シートを作成**。完全自動で品質保証と宣言しない。
- `prepare_assets.py`で512×512のWebP対を生成。影マスク一致を検証。
- `items.json`をID/パスで重複排除し更新。**既存IDの上書きは禁止**。effectPresetは`assets/generation/minimax_object_prompts.json`から取るか固定default。
- `pubspec.yaml`が`assets/items/`をバンドルし、Flutterが`items.json`を読むことをCI/Widgetテストで検証（[#29](https://github.com/SMRI2170/animal-shadow-match/issues/29)完了が前提）。
- `permissions: {contents: write, pull-requests: write, actions: read}` をそのワークフローだけに指定し、ブランチ+**Draft Pull Request** を自動作成。GitHubの [Settings → Actions → General → Allow GitHub Actions to create and approve pull requests](https://github.com/SMRI2170/animal-shadow-match/settings/actions) が許可されている必要がある（デフォルトでは無効の場合あり）。
- 生成とPRのGitHub Actionsを自動連鎖して人間の承認を飛ばさない。PRをマージしてもGitHub-hosted CIで勝手にストア配信しない。
- CIのテストだけでなく、スクリーンショット/Galleryで**影の見分けやすさ**を人が検査してから承認。

推奨順: まず[#29](https://github.com/SMRI2170/animal-shadow-match/issues/29)（Flutterが物体カタログを読める）を実装し、続いて[#31](https://github.com/SMRI2170/animal-shadow-match/issues/31)（Artifact→PR）を実装。前者未実装のままPRに画像だけ追加してもアプリの問題として出題されない。

## 安全性

MiniMax画像生成時のSubscription Keyは生成workflowのみが参照する。採用/PR workflowは画像生成APIキー不要。`GITHUB_TOKEN`を必要最小権限で使い、生成キーをcommitしない。PR作成設定はユーザーがGitHub管理画面で切り替える。既存のプランキーがチャット上に露出している場合はローテーションを推奨する。
