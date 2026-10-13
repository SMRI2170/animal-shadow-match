# [P1][Tests] Unit・Widget・CI・アセット検証

## 目的
GitHub上で追加画像やゲームロジックの破壊を自動的に検出する。

## 実装
- `test/round_factory_test.dart` を拡張し、2/3/4択、重複、直前ターゲット回避を検証。
- Widget testで正答/誤答/難易度移行と画面破綻を確認。
- GitHub Actionsで `flutter analyze`, `flutter test`, 画像検証をPR時に必ず実行。
- 画像を増やした際のCI実行時間を計測。

## 受入基準
- [ ] mainへのPRでFlutter/画像のCIが動く。
- [ ] エラーがあればPRチェックは失敗。
- [ ] 故意に壊したasset pathでCI失敗。
- [ ] 少なくともUI正誤分岐のWidget testがある。
