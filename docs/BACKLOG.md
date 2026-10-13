# Implementation backlog — issues in order

## v6素材取り込み — MiniMaxからゲームの出題プールへ

成功したMiniMax生成のArtifactは**まだゲームの出題プールには入っていない**。Flutterは現在`animals.json`だけを読み、`pubspec.yaml`も`assets/items/`を登録していない。

1. [#29](https://github.com/SMRI2170/animal-shadow-match/issues/29) — 汎用ShadowItemと`items.json`のFlutterロードに移行。
2. [#31](https://github.com/SMRI2170/animal-shadow-match/issues/31) — MiniMaxの成功Run IDと採用IDを指定し、背景除去・影/色WebP化・マスクQA・**Draft PR**を自動作成するパイプライン。
3. PRの差分/影を人が確認してマージ、Flutterアプリを再ビルド。**マージだけでインストール済みアプリが自動更新されるわけではない**。

詳細：[生成画像を実際の出題プールに反映する手順](GENERATED_ASSETS_TO_GAME_POOL_JA.md)。**#31は設計済み・ワークフロー実装はこれから。** すぐ反映する場合は手動/PR版の手順を参照。

## v6 — 非キャラクターのワンアセット方針（優先）

正式仕様：[ぷにぷに物体・1原画像設計 v6](SINGLE_ASSET_OBJECT_GAME_JA.md)。**v5のキャラクター20枚+魔法のおもちゃ12枚の試作は取りやめ**、本番用画像は新試作の評価後に量産。Flutter実装とリポジトリ名は未変更。

| 進める順 | Issue | 完了内容 |
|---:|---|---|
| 1 | [#27](https://github.com/SMRI2170/animal-shadow-match/issues/27) | キャラ不要の製品方針・独自性・試遊ゲート |
| 2 | [#28](https://github.com/SMRI2170/animal-shadow-match/issues/28) | 非キャラ物体30枚（ゼリー12/おもちゃ10/宇宙自然8）の画像/影/Fx評価 |
| 3 | [#29](https://github.com/SMRI2170/animal-shadow-match/issues/29) | Animal→汎用ShadowItemの後方互換移行 |
| 4 | [#24](https://github.com/SMRI2170/animal-shadow-match/issues/24) | 1画像だけでsquish/wobble/bounce/inflate |
| 5 | [#20](https://github.com/SMRI2170/animal-shadow-match/issues/20)、[#21](https://github.com/SMRI2170/animal-shadow-match/issues/21)、[#22](https://github.com/SMRI2170/animal-shadow-match/issues/22) | 5問セット、5個と遊ぶ場、正確な途中復帰 |
| 6 | [#25](https://github.com/SMRI2170/animal-shadow-match/issues/25) | 5つの物体への独立タップによる反応 |
| 7 | [#19](https://github.com/SMRI2170/animal-shadow-match/issues/19)、[#26](https://github.com/SMRI2170/animal-shadow-match/issues/26) | 幼児試遊/輪郭とFx品質 |
| P1実験 | [#30](https://github.com/SMRI2170/animal-shadow-match/issues/30) | 画像1枚を分割して「ぱかっ」と離すClip FX。リアル断面/中身の表現は別画像が必要 |

従来のv4「動物固有の反応」、v5「ふしぎなキャラを生成」の作業は**新仕様で上書き**。#24/#25/#27/#28はこの判断に合わせて本文/タイトル更新済み。動物デモ8種を削除せずリグレッションテストに残す。

## v5 題材の差別化（デザインピボットの比較、未採用）

**[比較設計 v5](THEME_PIVOT_EVALUATION_JA.md)**。既存の動物を乗り物/食べ物へ単純に置換するだけでは差別化が弱く、オリジナルキャラも既存アプリがあるため勝利は未確定。

| 順序 | Issue | 目的 |
|---:|---|---|
| 1 | [#27](https://github.com/SMRI2170/animal-shadow-match/issues/27) | A 動物 / B ふしぎなともだち / C ふしぎなおもちゃ の差別化判断 |
| 2 | [#28](https://github.com/SMRI2170/animal-shadow-match/issues/28) | MiniMaxでB20枚/C12枚を試作し96〜120dpの輪郭品質を比較 |
| 3 | [#19](https://github.com/SMRI2170/animal-shadow-match/issues/19) | 子ども+保護者の同意のある少人数の比較試遊 |
| 4 | [#13](https://github.com/SMRI2170/animal-shadow-match/issues/13) | ストア画面の理解度と検索語候補の確認（検索需要は未測定） |
| 正式採用後 | 新規Issue予定 | ShadowItemモデル/素材/ストア名称へ移行。リポジトリ名変更は別途判断 |

**先行して変更しないこと:** `SMRI2170/animal-shadow-match` リポジトリ名・8種の既存仮画像・Flutterコード・動物の本番画像大量生成。比較結果が出るまで残す。

## v4: 最小のゲーム価値強化（Issue登録済み）

正本: [ゲーム価値と発見 v4](GAME_VALUE_AND_ENGAGEMENT_JA.md)。**Flutterに実装済みではない。**

| 優先 | Issue | 機能 | 依存 |
|---|---|---|---|
| P0 | [#24](https://github.com/SMRI2170/animal-shadow-match/issues/24) | 動物別の控えめな反応プリセットと正答カラー化 | #4, #8, #17 |
| P0 | [#25](https://github.com/SMRI2170/animal-shadow-match/issues/25) | 5匹の個別タップパレード | #20, #21, #22, #24 |
| P1 | [#26](https://github.com/SMRI2170/animal-shadow-match/issues/26) | 画像の鮮度・特徴タグ・同種繰り返し抑制 | #3, #5, #7 |
| P0 / 試遊 | [#19](https://github.com/SMRI2170/animal-shadow-match/issues/19) | 従来型(A)→微反応(B)→パレード(C)の主体性/理解/保護者信頼比較 | #24, #25 |

**実装の推奨順:** #20/21/22の5問・保存基盤 → #24 → #25 → 子どもの試遊#19 → #26。図鑑・生息地パック・逆影モード・過剰なレア演出はMVPから除外。

> **2026-10-14 v3:** [5問セット・起動導線・広告の詳細仕様](SESSION_AND_MONETIZATION_JA.md)を正本とし、実装用の[#20](https://github.com/SMRI2170/animal-shadow-match/issues/20)、[#21](https://github.com/SMRI2170/animal-shadow-match/issues/21)、[#22](https://github.com/SMRI2170/animal-shadow-match/issues/22)、調査用の[#23](https://github.com/SMRI2170/animal-shadow-match/issues/23)を追加。既存のUI/UX v2より起動・セッション・広告について優先。

## v3優先実装（GitHub登録済み）

| 順序 | Issue | 内容 |
|---:|---|---|
| 1 | [#20](https://github.com/SMRI2170/animal-shadow-match/issues/20) | 5問セット進行・正答カウント・ターゲット重複排除 |
| 2 | [#21](https://github.com/SMRI2170/animal-shadow-match/issues/21) | 5匹の達成画面・続行/休憩ボタン・REST |
| 3 | [#22](https://github.com/SMRI2170/animal-shadow-match/issues/22) | 中断/再開・保存スキーマ・二重計上防止 |
| 4 | [#2,#8,#9,#16,#17,#19](https://github.com/SMRI2170/animal-shadow-match/issues) | v2からv3の単問UI・手のガイド・状態機械・試遊を整合 |
| 5（公開後） | [#23](https://github.com/SMRI2170/animal-shadow-match/issues/23) | 親向け広告/課金の可否のみ調査、MVPは広告0 |



> **UI/UXの実装方針:** [UI/UX詳細設計 v2.0](UI_UX_SPEC_JA.md) を参照。既存 #2, #8, #9, #10, #11, #12 を詳細化し、初回ガイド・状態制御・保護者設定・子ども試遊の個別Issueを追加した。以下15件は旧来の基盤バックログで、新規Issueは別途 [GitHub Issues](https://github.com/SMRI2170/animal-shadow-match/issues) を参照。追加したIssue番号はGitHub上で確認すること。

Each linked file is an import-ready GitHub Issue description. `P0` blocks public release, `P1` improves MVP quality, `P2` is post-release growth.

| Order | Priority | Issue | Status |
|---:|---|---|---|
| 1 | P0 | [[P0][Foundation] Flutter Androidプロジェクト初期化と実機起動](issues/01-task.md) | To do / scaffold partial |
| 2 | P0 | [[P0][Gameplay] 文字なし1画面ゲームUIの完成](issues/02-task.md) | To do / scaffold partial |
| 3 | P0 | [[P0][Logic] 問題生成ロジックのテストと難易度調整](issues/03-task.md) | To do / scaffold partial |
| 4 | P0 | [[P0][Assets] 画像・影・メタデータのスキーマ固定](issues/04-task.md) | To do / scaffold partial |
| 5 | P0 | [[P0][MiniMax] ソフト3D動物画像20種を生成して選定](issues/05-task.md) | To do / scaffold partial |
| 6 | P0 | [[P0][Pipeline] 背景除去と影生成の自動処理](issues/06-task.md) | To do / scaffold partial |
| 7 | P0 | [[P0][Content] 影の紛らわしさをレビューする仕組み](issues/07-task.md) | To do / scaffold partial |
| 8 | P1 | [[P1][UX] 反応・効果音・ミュートの追加](issues/08-task.md) | To do / scaffold partial |
| 9 | P1 | [[P1][Progress] ローカル保存と適応難易度](issues/09-task.md) | To do / scaffold partial |
| 10 | P1 | [[P1][Responsive] 小画面・タブレット・アクセシビリティ](issues/10-task.md) | To do / scaffold partial |
| 11 | P1 | [[P1][Tests] Unit・Widget・CI・アセット検証](issues/11-task.md) | To do / scaffold partial |
| 12 | P0 | [[P0][Safety] 子ども向けポリシーとプライバシー](issues/12-task.md) | To do / scaffold partial |
| 13 | P1 | [[P1][ASO] 英語・日本語ストア掲載素材](issues/13-task.md) | To do / scaffold partial |
| 14 | P1 | [[P1][Release] Android内部テスト公開と最終ゲート](issues/14-task.md) | To do / scaffold partial |
| 15 | P2 | [[P2][Growth] 検索流入30〜60日検証](issues/15-task.md) | To do / scaffold partial |

## UI/UX改修：実際のGitHub Issue（v2.0）
 
| 優先順 | Issue | 実装の目的 | 依存 |
|---:|---|---|---|
| 1 | [#2 プレイ画面](https://github.com/SMRI2170/animal-shadow-match/issues/2) | 星の撤去・2/3/4択の大きなタイル | #1 |
| 2 | [#17 状態機械](https://github.com/SMRI2170/animal-shadow-match/issues/17) | 連打・タイマー・復帰の防御 | #2 と並行可 |
| 3 | [#16 初回ガイド](https://github.com/SMRI2170/animal-shadow-match/issues/16) | 無言の手アニメと無操作ヒント | #2, #17 |
| 4 | [#8 反応](https://github.com/SMRI2170/animal-shadow-match/issues/8) | 影がカラーへ変わる成功・控えめな誤答 | #17 |
| 5 | [#9 進捗](https://github.com/SMRI2170/animal-shadow-match/issues/9) | 非表示の適応難易度・ローカル保存 | #3 |
| 6 | [#10 画面対応](https://github.com/SMRI2170/animal-shadow-match/issues/10) | 360dp〜タブレットの視認性 | #2 |
| 7 | [#18 保護者領域](https://github.com/SMRI2170/animal-shadow-match/issues/18) | 子ども向けUIから設定等を隔離 | #12, #10 |
| 8 | [#11 テスト](https://github.com/SMRI2170/animal-shadow-match/issues/11) | Golden / Widget / 状態遷移の検証 | 各UI Issue |
| 9 | [#19 子ども試遊](https://github.com/SMRI2170/animal-shadow-match/issues/19) | 初見UXを検証し修正 | #2, #16, #17, #8, #10 |

**注意:** UXの正本は[UI/UX仕様 v2.0](UI_UX_SPEC_JA.md)。試遊は[記録テンプレート](UX_PLAYTEST_TEMPLATE.md)に従い匿名記録。上記は**Issueとして登録済み、実装済みを意味しない**。

## Suggested release sequence

**Sprint 0:** #01–#04: playable Android + UI and catalog contracts.

**Sprint 1:** #05–#07: 20+ production assets and correct shadow QA.

**Sprint 2:** #08–#11: feedback, progress, screen sizes, CI.

**Sprint 3:** #12–#14: 100+ reviewed art assets, safety, ASO, Android internal release.

**After launch:** #15 search discovery measurement and iteration.

Note: 初期15件は GitHub Issues #1〜#15 として登録済み。docs/issues/XX-task.md は当初の原稿であり、追加の詳細はGitHub Issue本文に反映した。
