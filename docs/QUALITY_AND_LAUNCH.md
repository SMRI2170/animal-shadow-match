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
