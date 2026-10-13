# Implementation backlog — issues in order

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
