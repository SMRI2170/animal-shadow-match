# 「ぷにぷにふしぎなモノ」MVPをAndroidで触る

## MVPは何が動くか
- 画面上にカラー物体、下に同じ物体を含む**影2択**。5問正解すると**直近の5個**を並べた自由タッチ画面が出る。
- タップした展示物体はその物体に割り当てたFX（squish / wobble / bounce / inflate）で1回動く。
- 次のセットへ進む（大きい▶）と6問目から3択、16問目から4択。誤答時は同じ問題が続く。
- 月アイコンで休憩、▶で戻る。制限時間・広告・課金・オンライン画像取得はない。
- 5問内で同一ターゲットは原則出題しない。素材不足のときは同じターゲットの再利用を許す。
- **重要**：今回のMVPが起動した時点では、未採用のMiniMax画像はまだ入っていない。既存の8種の動物デモ素材を使ってゲームループを体験する。本物のぷにぷに画像は#35/#36〜#65の承認後に差し替える。

## AndroidでインストールできるAPK（GitHub Actions）
1. [MVP Android APKのGitHub Actions](https://github.com/SMRI2170/animal-shadow-match/actions/workflows/mvp-android-apk.yml)へ進む。
2. このワークフローがデフォルトブランチにマージされた後、`Run workflow`で実行できる。マージ前は対応PR作成時のチェックからも実行される。
3. 実行結果が緑のSuccessとなったらRun下部の**Artifacts → squishy-mvp-android-debug**をダウンロードし、ZIPを解凍する。
4. 中の`app-debug.apk`をAndroidへ転送し、手動インストールする。Androidの「この提供元のアプリを許可」確認が必要な場合がある。
5. **Debug APKは署名済みストア版ではない**。試遊専用で、機密データは要求せず、外部送信もしない。
6. Android Studio / Flutter SDKがある場合はリポジトリを開いて`flutter create --platforms=android --project-name animal_shadow_match .`→`flutter pub get`→`flutter run`も可能。

## 2分の試遊シナリオ
1. 上のカラー画像と一致する下の影を選ぶ。誤った影を押しても先へ進まないか確認。
2. 正解時にゆっくり一回ぷにっと動くか確認。連打しても次の問題を2回進めない。
3. 5問クリア→展示画面で並んだ5画像を一つずつタップ。繰り返し反応するか確認。
4. 月アイコン→休憩画面→▶で展示へ復帰。
5. 展示の▶で次の5問へ。影が3択になっているか確認。16問目以降は4択。

## コードの場所
- `lib/domain/game_session.dart`: 5問状態機械、重複防止、選択肢の増減、休憩
- `lib/domain/round_factory.dart`: 正解1件・不正解選択肢・既出ターゲットの扱い
- `lib/ui/game_page.dart`: 実際のタッチと展示/休憩、時間切れ安全フォールバック
- `lib/ui/single_asset_effect.dart`: 1枚絵をコードで変形
- `test/game_session_test.dart`, `test/game_page_mvp_test.dart`: 再現可能なロジック・UIテスト
- `.github/workflows/mvp-android-apk.yml`: Android Debug APKのビルド。**MiniMaxのAPIキーを使わず、生成課金なし**

## 本物のMiniMaxアセットに差し替える
1. [制作仕様親Issue #35](https://github.com/SMRI2170/animal-shadow-match/issues/35)で採用候補を選ぶ。採用すべき画像は96dpの影でも識別しやすい単体物体。
2. [MiniMaxワークフロー](https://github.com/SMRI2170/animal-shadow-match/actions/workflows/minimax-images.yml)で生成した成功Run IDを控える。
3. #31の`promote-minimax-assets.yml`がマージ後に使える場合、`source_run_id`と採用済み`approved_ids`を指定。背景自動除去は**ドラフト扱いで必ず画像を目視**。カラーWebP、影WebP、JSONをDraft PRへ登録する。
4. 人間がレビューしてPRをマージ後、**新しくAPKをビルドし直す**。既存インストール済みアプリのオフライン画像は自動更新されない。

## 現時点の範囲
音、決済、広告、ログイン、個別の本物MiniMax素材は含まない。自動で生成画像を製品採用したり、Google Playに公開したりしない。
