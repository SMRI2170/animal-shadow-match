# [P0][Foundation] Flutter Androidプロジェクト初期化と実機起動

## 目的
Android端末で画面と影合わせゲームの初期版を起動し、再現可能なセットアップ手順を確立する。

## 実装
- `flutter create --project-name animal_shadow_match --platforms=android .` で不足している `android/` などを生成。既存の `lib/` は上書きしない。
- Androidの `applicationId` は独自の本番用IDに確定（例示値をコピペしない）。
- `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run` を実行。
- Android端末、エミュレータで初期画面を撮影。
- READMEの環境準備を実行結果に合わせて更新。

## 受入基準
- [ ] Androidのdebugビルドが通る。
- [ ] 8枚のデモ画像がオフラインで表示される。
- [ ] 誤答後もゲーム継続、正答後に次の問題へ進む。
- [ ] 解析・単体テスト・GitHub Actionsが成功。
- [ ] APIキーや署名鍵をコミットしない。
