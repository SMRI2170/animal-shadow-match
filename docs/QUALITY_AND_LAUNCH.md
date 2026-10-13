# Quality, compliance, and release readiness

## Automated tests

- [x] Python validator checks file presence, unique IDs, alpha masks, shape equality, and distractor references (passed in scaffolding environment).
- [ ] `flutter analyze` run on configured Flutter SDK.
- [ ] `flutter test` on configured Flutter SDK.
- [ ] CI green on GitHub Actions after pushing.
- [ ] Widget tests for visible 2-, 3-, and 4-choice states, solved and retry.
- [ ] Integration smoke test on Android hardware and tablet.

## Manual QA matrix

| Case | Expected |
|---|---|
| Fresh install, airplane mode | Game launches, no network request required |
| 360dp phone portrait | Target and all choices are visible / interactable |
| Tablet portrait | No stretched pixelation or oversized interactions |
| Correct tap | Brief positive animation then one next round |
| Wrong tap | No penalty, unchanged question, feedback disappears |
| Repeated rapid taps | At most one completion recorded |
| 5 correct completions | 2 → 3 options |
| 15 correct completions | 3 → 4 options |
| 20+ successive questions | No target immediately repeats; no missing assets |
| Child cannot read | Learns behavior from demonstration/first interaction |
| Image QA | No frightening images, defects, clipping, ambiguous pairings |
| App paused/resumed | Doesn't crash and restores current session reasonably |

## Child safety and Google Play

Official references (review before submission):
- Families policy: https://support.google.com/googleplay/android-developer/answer/9893335?hl=ja
- Target audience / content: https://support.google.com/googleplay/android-developer/answer/9867159?hl=ja

Initial app does not include ad SDK, analytics, tracking, account/login, internet access requirements or in-app purchase. This significantly reduces complexity but **does not exempt the app from disclosure obligations**. Before release, provide an accurate privacy policy, complete target-age and Data safety disclosures, age-appropriate store screenshots and disclosures, and check any platform/plugin data flows.

If ads are later introduced, reassess all Families policies. Ads to children must use allowed Families self-certified SDK configurations, cannot be personalized, and may not intentionally induce child accidental clicks. Keep ads separate from child-facing game controls and plan for parent-only entry if monetization is added.

## Initial target measures (hypotheses, not existing results)

- **Comprehension:** 80% of observed target-age playtesters can identify the tap interaction within 10 seconds without reading instructions.
- **Functional quality:** zero missing masks, zero duplicate answer alternatives across full catalog.
- **Responsiveness:** no noticeable lag between tap and visual response on test Pixel/low-end Android; measure frame timing before setting concrete FPS goals.
- **Store validation:** after 30–60 days, compare Google Play's organic search impressions, store conversion, downloads, and retention proxies available without child-tracking SDKs.

## Ship / no-ship gate

Do not ship demo art as real MiniMax assets; do not claim “educationally proven”, “Teacher Approved”, or guaranteed learning outcomes unless individually verified and authorized. Stop release for missing images, unclear silhouette options, dangerous ad SDK, missing privacy disclosures, or failure on small Android displays.


## UI/UX v2 release gate (2026-10-14)

画面・操作の正本: [UI/UX v2](UI_UX_SPEC_JA.md)。公開前に [UX試遊記録](UX_PLAYTEST_TEMPLATE.md) を使って、2〜3歳児と4〜5歳児の双方で操作を観察する。小規模な観察を科学的効果の証明として扱わない。

- [ ] 初回スタートボタン不要・ゲーム上の読字不要・初回手ヒントが分かる
- [ ] 星の進捗行・余分なUIが無く、1匹+影2〜4個に集中できる
- [ ] 360×640dp / 393×851dp / 800×1280dp、全選択肢のタップ領域>=96dp、スクロールなし
- [ ] 誤答・正答・連打・バックグラウンド復帰で問題が壊れない
- [ ] 無音、減らしたアニメ、アクセシビリティを確認
- [ ] 保護者導線を通らずに購入/外部URLに到達しない
- [ ] 画像と影のペアが一義的で、小型端末でも明確
- [ ] 試遊で迷った箇所と設計変更理由を記録


## v3セッション・広告安全ゲート（2026-10-14）

正本: [Session and Monetization v3.0](SESSION_AND_MONETIZATION_JA.md)。**MVPは広告SDK・広告枠なし**。
- [ ] 初回/再開の画面動線（タイトル無し・同じ問題）
- [ ] 5問目だけ達成、無操作では次のセットを開始しない
- [ ] 5匹の絵は直近の正解画像を再利用、毎セット重複なし
- [ ] 続ける/休憩の文字なし大ボタン、休憩から新セットへ復帰
- [ ] OSバック/再起動/連打/低メモリでも二重カウントなし
- [ ] 正解/不正解/5問完了/休憩/起動の全てに広告表示無し
- [ ] 2〜3歳と4〜5歳の試遊で、5問の長さと完了2択の理解を確認
- [ ] Google Play FamiliesポリシーとSDK状況は収益化前に再調査

## v4: intrinsic play / game value QA

Formal spec: [Game value and engagement v4](GAME_VALUE_AND_ENGAGEMENT_JA.md). **Design only until the Flutter implementation and tests pass.**

- [ ] Animal-specific preset reactions (hop/sway/tilt/float/pulse + default) all show a perceivable yet calm response.
- [ ] Color silhouette transitions are tied to a correct tap, never accidental background taps.
- [ ] Every tap triggers at most one reaction, no duplicate round/event on multitouch, resume or dispose.
- [ ] The actual five matched animal images reappear in the parade, tap only the selected animal; no endless autoplay.
- [ ] On smaller screens no animal overlaps another tap region; responsive view, all Semantics and reduce motion tested.
- [ ] No gambling-like rare animations, daily login rewards, loot boxes, time pressure, and no child-facing ads or tracking.
- [ ] Novelty tests: no repeated target in one set, handle recently seen animals without excluding all when catalog is small.
- [ ] Compare baseline (simple success), microreactions, parade using small consented exploratory playtests.
- [ ] Parents can end sessions; do not call increased watch time alone a positive outcome.
