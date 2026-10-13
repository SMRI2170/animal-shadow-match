/// Image-only deformation reactions that play when a player answers a
/// [ShadowItem] correctly. Each preset is a tiny, no-bones, no-extra-pose
/// transform: one image, one animation.
///
/// The MVP supports the four transforms listed as 必須 in the v6 design
/// (`squish`, `wobble`, `bounce`, `inflate`). Spin/pop/split are intentionally
/// left out so the shipped product never runs a transform the QA has not
/// validated against real art.
library;

enum EffectPreset {
  squish,
  wobble,
  bounce,
  inflate;

  static EffectPreset parse(Object? raw) {
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      for (final preset in EffectPreset.values) {
        if (preset.name == value) return preset;
      }
    }
    // Undefined or unknown values fall back to the most relaxed transform —
    // this is the explicit behaviour from the v6 spec §5 / Issue #29.
    return EffectPreset.squish;
  }
}

enum EffectIntensity {
  gentle;

  static EffectIntensity parse(Object? raw) {
    if (raw is String && raw.trim().toLowerCase() == 'gentle') {
      return EffectIntensity.gentle;
    }
    return EffectIntensity.gentle;
  }
}
