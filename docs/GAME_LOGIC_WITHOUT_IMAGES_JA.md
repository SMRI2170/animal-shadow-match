# 画像なしでも動くゲームロジック設計（2026-10-14）

> このドキュメントは **採用画像が揃う前** にゲームロジック（問題生成・状態管理・FX・永続化）を先に完成させるための設計メモです。
> 関連: [#29 ShadowItem 移行](https://github.com/SMRI2170/animal-shadow-match/issues/29)、[#20 5問セッション](https://github.com/SMRI2170/animal-shadow-match/issues/20)、[#22 中断再開](https://github.com/SMRI2170/animal-shadow-match/issues/22)、[#16 初回ガイド](https://github.com/SMRI2170/animal-shadow-match/issues/16)、[#25 プレイエリア](https://github.com/SMRI2170/animal-shadow-match/issues/25)、[#30 Clip分割FX](https://github.com/SMRI2170/animal-shadow-match/issues/30)、[画像生成意思決定](../IMAGE_GENERATION_DECISION_JA.md)。

## 0. 問い

> 採用画像が 1 枚も `assets/items/` に無い（または PR 経由で未承認）状態で、ゲームロジックをどう作り込み、どうテストするか？

- 画像は **データ**（Pixel の集合）であり、ロジックは **型の構造** と **状態遷移** である。両者を分離すれば画像は後付けで差し替えられる。
- v6 の ShadowItem はすでに「画像 1 枚と影 1 枚」を絶対パスで参照するだけの構造。**ロジックは画像を一切 decode しない**。
- `flutter test` の **Widget Test は `flutter_test` の `TestWidgetsFlutterBinding` で `AssetsBundle` をメモリに差し替えできる**ため、実画像をバンドルせずに UI をテスト可能。
- 既存の **8 動物デモ** は「画像ありの回帰テスト」。**本書のスコープはそれと独立した "画像なしの進行"**。

## 1. 画像状態を 3 つに定義する

ゲームロジック実装に入る前に、すべての画像参照を 3 状態に分類します。

| 状態 | 意味 | バンドル | 出典 |
|---|---|---|---|
| **S0 absent** | `assets/items/<id>.webp` も `assets/animals/<id>.webp` も無い | × | 何も無い状態。ゲーム起動時にエラーダイアログ |
| **S1 placeholder** | `assets/development/<id>.webp` に**自動生成された手続き型プレースホルダ** | △（`--dart-define ENABLE_DEMO_ASSETS=1` で有効） | `scripts/generate_demo_assets.py` の v6 拡張版 |
| **S2 live** | 採用済み `assets/items/<id>.webp` | ◯（main に取り込まれた確定画像） | Draft PR 経由で `promote-minimax-assets.yml` が追加 |

ロジック層は **S0/S1/S2 を知らず**、`AssetBundle` が解決できる限り動く。`CatalogRepository` が「利用可能なパス一覧」を返すだけ。

## 2. S1 placeholder を `assets/development/` に分離する

既存の `scripts/generate_demo_assets.py` は **`assets/animals/` に 8 動物デモ**を書いてしまう構成。v6 方針では動物に戻らないのでこれを整理：

- **新スクリプト** `scripts/generate_v6_placeholders.py` を追加（既存 `generate_demo_assets.py` は deprecate）
- 出力先: `assets/development/<id>.webp`
- 入力: `assets/generation/minimax_object_prompts.json` の 30 個
- 各プロンプトの `shape` を **3〜5 個のプリミティブ図形** に分解する決定論的レンダラー（OpenCV/polygon ベース）
- 各プレースホルダは：
  - **distinct major bump or notch** を必ず 1 箇所に持つ（v6 シルエット差別化要件）
  - **512×512 WebP** で書き出す（透過）
  - **同一アルファの影 WebP** を `prepare_assets.py` 経由で同時生成
- CI ボタン: `--include-development` を `flutter test` 前に明示的に指定した時のみ `development` を asset バンドルに入れる（デフォルトでは本番ビルドに混入しない）

```text
assets/
  animals/                      ← 8 動物（v4 回帰テスト専用、animal.json のみ）
  items/                        ← S2: 採用画像（draft PR 経由）
  development/                  ← S1: 自動プレースホルダ（明示有効化のみ）
    gel_star.webp
    cloud_cushion.webp
    ...
  catalog/
    animals.json                ← v4 8 動物エントリ（legacy）
    items.json                  ← v6 エントリ（最初は空）
    development.json            ← S1 用メタデータ（自動生成される）
```

> **重要**: S1 を本番に送らないため、`pubspec.yaml` の `assets:` には `assets/development/` を入れない。テスト/CI でだけ `flutter test --dart-define ENABLE_DEVELOPMENT_ASSETS=1` のような仕組みで動的に bundle に追加する。

## 3. CatalogRepository を 3 状態に拡張

```dart
enum CatalogSource { legacyAnimals, itemsV6, developmentPlaceholders }

class CatalogLoadResult {
  final List<ShadowItem> items;       // ゲームに出すリスト
  final Set<CatalogSource> sources;   // 何から取得したか
  final bool isPlaceholderMode;       // S1 が混じっているか
}
```

`CatalogRepository.load()` の新挙動：

1. `items.json` を読み込み（S2 live）。あればそれを優先。
2. なければ `animals.json` を読み込み（legacy 8 動物）。
3. `--dart-define ENABLE_DEVELOPMENT_ASSETS=1` の時のみ `development.json` を読み込む（S1 placeholder）。
4. 全部で **最低 4 件** なければ `FormatException`。UI には「Catalog empty」アイコンを出す。
5. `silhouetteFeatures` を持ち、各アイテムの主稜線（中心から見て最大の凹凸方向）を返す `_SilhouetteHints` を ShadowItem に追加するのは **P1** に保留。テスト容易性のため _internal_ で `bounds()` だけ提供。

## 4. ゲームロジックの画像非依存ポイント

### 4.1 `RoundFactory` — 既に画像非依存

`List<ShadowItem>` を入力に `(target, options)` を返すだけ。シルエット画像の有無は結果に影響しない。

**追加要件**:
- 各 round 開始時に「同じ group 同士ばかりを避ける」軽いヒューリスティクス（jelly/toys/cosmic を 4 問中 3 種以上に散らす）
- 連続正解で「直近 5 問で同じアイテムが 3 回以上」を避ける（v6 §「直近 5 個を展示」前提）

### 4.2 `GameState` 状態機械 — 新規（#17 連動）

```dart
sealed class GameState {
  const GameState();
}

class LoadingCatalog extends GameState { ... }      // bootstrap
class Solving extends GameState {
  final ShadowItem target;
  final List<ShadowItem> options;
  final int completedInSet;       // 0..4
  final int optionCount;          // 2..4
  final String? wrongChoiceId;
} 
class Solved extends GameState {
  final ShadowItem target;
  final List<ShadowItem> options;
  final int completedInSet;
  final bool effectPlaying;
}
class ShowingReview extends GameState { ... }       // 5 問終了、5 個展示
class AwaitingContinue extends GameState { ... }     // 続ける/休憩
class CatalogEmpty extends GameState { ... }        // S0 起動エラー
```

画像の有無はこの列挙に含まれない。`_PlayBoardState` の `setState` と `Timer` 乱舞を、**`Cubit`/`ChangeNotifier`** に置き換える作業を含む（#17 の P0 範囲）。

### 4.3 `SingleAssetEffect` — 既に画像非依存

`assetPath: String` を受け、`Image.asset()` を使って描画する。Flutter の `Image` ウィジェットは `AssetBundle` の解決に失敗するとビルド時にエラー。テストでは `AssetBundle` を差し替えて画像パスをメモリ上の `Uint8List` PNG に解決する。

### 4.4 永続化 (#22) — `shared_preferences`

採用する前提で先に実装：

```dart
abstract class GameProgressStore {
  Future<ProgressData?> load();
  Future<void> save(ProgressData data);
  Future<void> clear();
}

class ProgressData {
  final int completedTotal;
  final List<String> recentTargetIds;   // 直近 5
  final DateTime lastPlayed;
  final int currentSetIndex;            // 途中再開用
}
```

`shared_preferences` のキー衝突を避けるため `animal_shadow_match.progress_v1` のような名前空間で保存。テストでは `SharedPreferences.setMockInitialValues({})` で in-memory mock。

### 4.5 初回ガイド (#16) — `AnimatedAlign` で人差し指を出す

正解位置に直接 `Positioned` でカーソルを 1.5 秒間動かして消す。**画像非依存**。`pubspec.yaml` の `uses-material-design: true` で `Icons.touch_app_rounded` が使える。

### 4.6 プレイエリア (#25) — 5 個の影グリッド

「直近 5 問の正解 ShadowItem をグリッドで並べ、タップで `SingleAssetEffect` を再生」するだけ。**画像 1 枚＝影 WebP が `AssetBundle` にあれば動く**。S0 のときは `ShowingReview` 状態に遷移せず `Solving` を継続。

### 4.7 Clip 分割 FX (#30) — `ClipRect` 2 枚と `Transform.translate`

```dart
Widget clipSplit(Widget child) => Stack(children: [
  ClipRect(clipper: _LeftHalf(), child: Transform.translate(offset: Offset(-12, 0), child: child)),
  ClipRect(clipper: _RightHalf(), child: Transform.translate(offset: Offset(12, 0), child: child)),
]);
```

1 画像のみで開くから断面が必要な素材は引き続き不採用。**ドキュメントに明記**。

## 5. 画像なしでも動くテスト戦略

### 5.1 3 種類のテスト

| 種類 | 画像 | 目的 | 速度 |
|---|---|---|---|
| **Pure Dart Unit** | × | `ShadowItem.fromJson` / `RoundFactory` / `EffectPreset.parse` / `GameProgressCodec` | < 50ms |
| **AssetBundle-mocked Widget** | △ メモリ上の 1×1 PNG | `GamePage` のレイアウト、`SingleAssetEffect` の状態遷移 | < 1s |
| **Golden / Visual** | ◯ 実 WebP | `SingleAssetEffect` のフレーム毎スクショ、影と正像の重ね合わせ | 数秒 |

### 5.2 テストフィクスチャの作り方

```dart
// test/helpers/in_memory_assets.dart
class _RecordingAssetBundle extends CachingAssetBundle {
  final Map<String, ByteData> assets;
  _RecordingAssetBundle(this.assets);
  @override
  Future<ByteData> load(String key) async =>
    assets[key] ?? (throw FlutterError('missing: $key'));
}

AssetBundle testBundle(List<ShadowItem> items) {
  final bytes = <String, ByteData>{};
  for (final item in items) {
    bytes[item.imagePath] = _onePixelWebP();
    bytes[item.shadowPath] = _onePixelWebP();
  }
  bytes['assets/catalog/items.json'] = _utf8('{"items":[]}');
  return _RecordingAssetBundle(bytes);
}
```

`1×1 PNG` をバイト列で持ち、**全アイテム同じピクセル**でも `Widget Tree` のサイズと state 遷移は検証可能。**`Image.asset()` の `cacheWidth/cacheHeight` で正しく decode されること**だけ確認。

### 5.3 ゴールデンを使うテスト

本物の `SingleAssetEffect` を Widget Test で動かすには実際の WebP が要る。これに対しては：

- `test/golden/_placeholder_fx_*.png` を **`dev_dependencies: flutter_test`** 内で `flutter test --update-goldens` で一度だけ生成。
- 生成の元画像は `assets/development/*.webp`（CI で `--include-development` 指定時のみ）。
- 以降は **バイナリ差分** で golden 比較。CI で失敗したら人が目視。

## 6. 受け入れ基準

| 軸 | 合格 | 検証方法 |
|---|---|---|
| ロジック層が画像を読まない | `RoundFactory` のテストに `AssetBundle` を渡さない | dart テスト |
| `CatalogRepository` が S0/S1/S2 を切替できる | テストで 3 通りの JSON を渡して結果確認 | dart テスト |
| `--dart-define ENABLE_DEVELOPMENT_ASSETS=0` で `assets/development/` がロードされない | CI で 0 を明示し `validate_catalog.py` も development を無視 | CI |
| `--dart-define ENABLE_DEVELOPMENT_ASSETS=1` の CI でも `validate_catalog.py --strict` が S2 を要求 | CI で両方並走 | CI |
| `flutter test` が画像なしで通る | AssetBundle mock のみ | dart テスト |
| 5 問セッション・中断再開・初回ガイド・プレイエリア・Clip FX が独立 Widget Test を持つ | 各 Issue の Draft PR に最低 1 golden | PR |

## 7. 推奨する着手順

1. **G1. CatalogRepository の 3 状態化＋`assets/development/` の spec 確定** → Draft PR
2. **G2. `generate_v6_placeholders.py` の実装** → Draft PR（#29/#31 とは独立）
3. **G3. GameState 状態機械 + RoundFactory の重複回避** (#17/#20) → Draft PR
4. **G4. `SingleAssetEffect` の AssetBundle mock Widget Test** → Draft PR（#24 の補強）
5. **G5. GameProgressStore + shared_preferences (#22)** → Draft PR
6. **G6. 初回ガイド (#16) + プレイエリア (#25)** → 連続 Draft PR
7. **G7. Clip 分割 FX (#30)** → Draft PR

各 PR は **画像なし CI で緑**、採用画像が PR されたら **Adapter 層（CatalogRepository）経由で自動取り込み**。

## 8. 未確定事項 / ブロッカー

- **`generate_v6_placeholders.py` のレンダリング精度**: 人間が見た目で「物体らしさ」が必要。`polygon + ellipse` ベースで十分な品質が出るかは **G2 着手時に 1 度書き出して目視確認**。
- **メモリ AssetBundle で `Image.asset` が動くか**: Flutter バージョン 3.44 で `TestWidgetsFlutterBinding` が `Image` の `ImageProvider.resolve` まで面倒を見るか確認が必要（G4 で検証）。
- **`shared_preferences` の依存追加**: Issue #22 の合意で GO 済み。本書のスコープでも前提とする。
- **`golden` テストのサイズと差分検出力**: ImageMagick / Pillow の perceptual hash ではなく Flutter 既定の `pixel match` で十分か（#26 着手時に判断）。

---

## 9. 採用する意思決定（提案 / 確認待ち）

1. **画像状態を S0/S1/S2 の 3 つに分類** し、`assets/development/` を本番ビルドから除外
2. **`scripts/generate_v6_placeholders.py` を新設**、既存 `generate_demo_assets.py` を deprecate
3. **`CatalogRepository` を 3 状態対応** に拡張、S2 を最優先
4. **`shared_preferences` ベース `GameProgressStore`** を #22 で実装
5. **テストは 3 層（Pure Dart / AssetBundle mock / Golden）** に分け、`flutter test` の既定は **画像なし**
6. **G1→G7** の順で **Issue ごとに Draft PR** で main に提出
7. **Clip 分割 FX は 1 画像のみで動くプロトタイプ実装**、断面が必要な素材は引き続き不採用

→ 上記 7 項目の GO/差戻を返信ください。
