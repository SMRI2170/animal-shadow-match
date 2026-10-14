# 画像生成の意思決定メモ（v6, 2026-10-14）

> このドキュメントは #28「30枚試作」を開始する前に、画像生成について**人間が合意すべき事項**を 1 ページにまとめたものです。実装や PR 提出ではなく、合意形成が目的です。
> 関連: [ぷにぷにふしぎなモノ v6](SINGLE_ASSET_OBJECT_GAME_JA.md)、[MiniMax 量産手順](MINIMAX_GITHUB_ACTIONS_JA.md)、[#28 30枚試作](https://github.com/SMRI2170/animal-shadow-match/issues/28)、[#26 輪郭/FX品質](https://github.com/SMRI2170/animal-shadow-match/issues/26)。

## 0. 状況整理（2026-10-14 時点）

| 項目 | 現状 |
|---|---|
| MiniMax API キー登録 | **未確認**。`MINIMAX_API_KEY` が Secrets にあるかは本書からは見えない。利用者は [Settings → Secrets](https://github.com/SMRI2170/animal-shadow-match/settings/secrets/actions) で確認 |
| 画像生成の課金経路 | M Plan Go ($22/月) の Subscription Key、または Pay-as-you-go (image-01: $0.0035 / image) |
| 30 枚試作の課金見積 | **Pay-as-you-go で約 $0.11**、M Plan Go の「5 時間ウィンドウ内」なら枠内（要利用画面で確認） |
| 画像生成ワークフロー | `minimax-images.yml` がコミット済み、`dry_run=true` で動作確認済み / `dry_run=false` の実走は未検証 |
| 採用 PR ワークフロー | Stage 2 完了：`promote-minimax-assets.yml` + `scripts/promote_minimax_assets.py` |
| 既存プロンプト候補 | `assets/generation/minimax_object_prompts.json` に 30 個（jelly 12 / toys 10 / cosmic 8、FX 9/9/7/5） |
| v6 仕様の採用ゲート | 30枚中「完成単体/背景除去可/96dpで識別可/怖くない」を 20/30 以上で満たす |

## 1. 決めるべき 5 つのポイント

### A. 生成する素材の「ジャンル」を確定する

選択肢（v6 §2 の範囲）：

1. **A ぷにぷに（推奨既定）** — ゼリー / グミ / クッション / スポンジ。子どもが「ぷにっ」と触れたい触感の擬態に最適。
2. **B ふしぎなおもちゃ** — 柔らかいリング / くるくる円盤 / ぽこぽこボール / ねじれ形。輪郭が面白く FX が映える。
3. **C 不思議な自然・宇宙** — 柔らかい石 / 雲 / 惑星 / 結晶 / しずく。v6 §6 のとおり 8 枚と少数。

**決定（提案）**: A を主軸に A:B:C = 14:10:6 の **30 枚**。`assets/generation/minimax_object_prompts.json` の現構成（12/10/8）を 14/10/6 に微調整するのは、人手で見直してから判断。

### B. 画風プロンプトの固定

`assets/generation/minimax_object_prompts.json` の `style` フィールドはすでに：

```
One single complete non-character tactile object. Soft 3D clay-toy
illustration, gentle pastel palette, child-friendly, clean studio render.
Centered square composition, entire object visible with generous empty
margin, one isolated subject, plain uniform off-white background suitable
for background removal, clear distinctive outer silhouette, soft diffuse
lighting, no cast shadow. No face, eyes, mouth, hands, feet, animals,
human figures, accessories, letters, logos, labels, watermarks, collage,
or multiple objects.
```

を追加して以下を保証：

- **中央寄せ＋全身が完全に収まる**：512×512 に取り出したとき本体が消えない
- **plain uniform off-white background**：`rembg` または手動で背景除去しやすい
- **no cast shadow**：後でシェードを独自生成するため、AI の影は禁止
- **distinctive outer silhouette**：96dp のシルエットで他アイテムと区別可能
- 個別プロンプトは **shape 1〜2 条件 + material 1 条件** のみ

**決定（提案）**: 上記のままで良い。ただし「distinctive outer silhouette」を保証するため、各 shape 記述に「**has at least one major bump or notch that makes it instantly distinguishable from a generic round/blob silhouette**」を 1 行追加する。

### C. 背景除去（透過化）の方法

選択肢：

1. **D1 事前手動**（v4 と同じ）: 人手で `assets/source/<id>.png` を透過化してから `prepare_assets.py`
2. **D2 `--bg-mode auto_draft`**（Stage 1 で実装済み）: `rembg` を `pip install rembg` して投入時に自動透過化
3. **D3 MiniMax の透明オプション**: `image-01` に「背景なし/透明」を指定できる場合、生成時点で透過（公式ドキュメント未確認、用法検証必要）

**決定（提案）**: **D1 を既定、D2 を補助**。D1 で失敗した画像だけ D2 にフォールバック。D3 は image-01 の公式ドキュメントでサポートが確認できるまで採用しない。

### D. 採用判定の合否ゲート（v6 §6 を明文化）

| 軸 | 合格基準 | 拒否ケース |
|---|---|---|
| 単体性 | 物体 1 個だけが描かれている | 複数 / 集合 / 文字 / 背景物体 |
| 輪郭 | 96dp / 120dp の影で他の候補と瞬時に区別可 | ただの丸/ただの三角/色違いしか違わない |
| アルファ | エッジに白フリンジなし、欠損/断裂なし | 耳や突起が背景に溶ける |
| 構図 | 全身が余白付きで 512×512 に収まる | 切れる／余白ゼロ／枠外 |
| 安全性 | 2〜5 歳に怖くない、商標・ブランド要素なし、既存キャラと混同しない | 武器/牙/グロテスク/企業ロゴ |
| 整合性 | 同じアート系統（同じパレット、同じ 3D 風、同じカメラ） | 写真/水彩/アニメが混在 |
| メタデータ | id / path / category / distractors / effectPreset / アクセシブル名が埋まる | 欠損／重複／他カタログとの衝突 |

**決定（提案）**: 上記を `docs/IMAGE_GENERATION_DECISION_JA.md`（本書）に明示し、`scripts/validate_catalog.py` と `prepare_assets.py` で自動チェックできる軸（単体性・アルファ・寸法・ID/path）はツールで、不快/商標/子ども視点は人でレビューする。

### E. 段階的な検証ステップ（推奨手順）

| 段階 | 件数 | 目的 | 課金 | Go/No-Go |
|---:|---:|---|---|---|
| E0 | 0 件 | `dry_run=true` で動作確認、リソース ID バリデーション | ¥0 | ✅ |
| E1 | **1 件** | リージョン/キー/残枠のリアルタイム確認、`intl` リージョンで `count=1`、`dry_run=false` | ≈$0.004 | 直後に Usage 画面で Go の枠が減っているかを確認、減っていなければキーを入れ替え |
| E2 | **5 件** | E1 が通れば小さい最初のバッチ（jelly グループ中心）。`start=0, count=5` | ≈$0.018 | 5 枚中 4 枚以上がアルファ付きで黒シルエットが成立するか |
| E3 | **30 件** | 上限いっぱいの本走（v6 §6 ゲートへ進む） | ≈$0.11 | 20/30 以上が手動承認可能なら #26（輪郭 QA）に進む |

`★ 5回一気に走らせない。1回ごとに人が画像を確認し Usage を確認してから次へ進む。`

**決定（提案）**: E0 → E1 → E2 → E3 と段階的に進む。`minimax-images.yml` の `count` を **1, 5, 6, 6, 6, 6** と刻んで、6 ラン合計 30 枚に揃える（現行 `count <= 6` 制約と整合）。

## 2. 採用しない選択肢（コスト・UX）

- **複数ポーズ画像 / ボーンアニメーション**: v6 §7 で禁止、SKU v6 #29 で不要と明示済み
- **本物のキャラクター、商標ロゴ**: 上記 D セクションで拒否
- **1 ランで 30 件**: API 失敗時の再現性と課金の不可視性を避けるため採用しない
- **CI 上で自動実行**: `schedule` / `push` / `pull_request` トリガーは一切なし（既存 `.github/workflows/minimax-images.yml` で確定済み）
- **実画像を main に直マージ**: Draft PR ゲート、`promote-minimax-assets.yml` 経由で `gh pr create --draft` のみ

## 3. 採用する Image パイプライン完成形

```text
ローカル開発 (任意)
  assets/source/<id>.png          ← 透明PNG (手動 or D2 で自動)
    ↓ scripts/prepare_assets.py
  assets/items/<id>.webp          ← 512x512 WebP
  assets/items/<id>_shadow.webp   ← 同一アルファの影
    ↓ scripts/validate_catalog.py
  assets/catalog/items.json       ← 人間が inspect
    ↓ Draft PR  (人間マージ)
  main へ昇格 → Android 再ビルド
```

## 4. 未確定事項 / Blockers

1. **`MINIMAX_API_KEY` の登録状況** — 利用者は [Settings → Secrets](https://github.com/SMRI2170/animal-shadow-match/settings/secrets/actions) で確認してください。Go Subscription Key なら `sk-cp-` 接頭辞（コードで拒否ロジック実装済み）。
2. **M Plan Go の画像割当枠** — Go 5 時間ウィンドウ＋週次ウィンドウで image-01 を含む。M Plan ユーザは [console usage](https://platform.minimax.io/) で残枠を確認してください。E1〜E3 で枠を使い切ったら次のリセット時刻まで待つ。
3. **image-01 のスタイル整合性** — E1〜E2 の結果を見て、Soft 3D clay toy 系統が出るかを目視確認。**出ない場合はシャットダウン**して別の選択肢へ。
4. **子どもの試遊（#19）** — 30 枚中 12 枚程度が子どもに「何に見える？」と直接聞いて識別可能かを確認。本書では触れないが、E3 完了後の後段タスク。

## 5. 採用する意思決定（提案 / 確認待ち）

1. **A を主軸に A:B:C = 14:10:6 の 30 枚** を採用（既存プロンプトの比率を微調整）
2. **`style` フィールドに silhouette distinctiveness 文を 1 行追加**
3. **背景除去は D1（手動）既定、D2（rembg）補助**
4. **E0 → E1(1枚)→E2(5枚)→E3(6×4=24枚)** と段階的に進む
5. **各ラン後に Usage と出来栄えを確認し、次ラン前にユーザーが GO サインオフ**
6. **Draft PR 経由で人間が承認、main に取り込む**

→ 上記 6 項目の GO/差戻を返信で指示してください。

---

## A. 参考：MiniMax image-01 仕様（2026-10-14 確認）

- 1 リクエストあたり最大 9 枚、`n=1`、9RPM 制限
- Aspect ratio `1:1`、4096×4096 までの解像度
- 価格は Pay-as-you-go $0.0035 / image、M Plan Go 枠内なら追加課金なし
- `prompt_optimizer: false` でプロンプト通りに出力（既存スクリプト既定）
- 1 枚の出力は base64 で即時返却、永続 URL ではない（既存実装と整合）

## B. 参考：rembg（背景除去ローカルフォールバック）

- `pip install rembg` で導入、`u2net` モデルを初回 1 回ダウンロード
- ゼリー／半透明グミ／細い突起は失敗リスクあり（既存ドキュメント通り）
- 失敗時は人が `assets/source/<id>.png` を手動で透過化した上で再投入
