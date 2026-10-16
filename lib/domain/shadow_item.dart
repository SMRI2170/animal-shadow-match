/// Generic, content-agnostic item for the silhouette matching game.
///
/// Replaces the legacy `Animal` type so a single transparent raster picture —
/// generated or hand-authored — can stand for any tactile object, toy, or
/// creature. The shadow path is derived mechanically from the item's alpha
/// channel (validated by `scripts/validate_catalog.py`), so a one-pic object
/// is enough to be playable.
///
/// Optional fields default to safe fall-backs. `effectPreset` defaults to
/// [EffectPreset.squish] so old entries remain visually correct after the
/// v6 migration without any manual edit.
library;

import 'effect_preset.dart';

class ShadowItem {
  const ShadowItem({
    required this.id,
    required this.imagePath,
    required this.shadowPath,
    required this.category,
    required this.distractorIds,
    this.silhouetteFeatures = const <String>[],
    this.effectPreset = EffectPreset.squish,
    this.effectIntensity = EffectIntensity.gentle,
    this.accessibilityLabel,
    this.similarityGroup,
  });

  /// Stable, lowercase identifier used in JSON and as the question key.
  ///
  /// Only validated externally by [isValidItemId]; keep this permissive here
  /// so tests can construct items with arbitrary IDs.
  final String id;

  /// Color (or colored raster) image shown in the top half of a question.
  final String imagePath;

  /// Same silhouette, rendered dark. Generated from [imagePath]'s alpha; see
  /// `scripts/prepare_assets.py`.
  final String shadowPath;

  /// Free-form label used purely for grouping (e.g. `squishy_object`).
  final String category;

  /// IDs of items that make interesting wrong choices for this item.
  /// The runtime falls back to other catalog entries to keep option counts
  /// configurable from 2..4.
  final List<String> distractorIds;

  /// Optional silhouette-similarity bucket shared with other items. Items
  /// in the same group are **never** both picked for the same round: when
  /// one of them is the target, no other member can appear as a distractor.
  ///
  /// This is a soft contract from [RoundFactory] (Issue #89 follow-up);
  /// it prevents visually similar items — e.g. `stacked_disks` vs.
  /// `wavy_disc` — from being the only way to tell the question apart.
  /// Keep the value machine-readable (lowercase + underscores, like an id)
  /// so it can be referenced by tests and pipelines.
  final String? similarityGroup;

  /// Coarse silhouette hints for humans — not used at runtime, but kept in
  /// the JSON so reviewers can decide whether two items will look alike.
  final List<String> silhouetteFeatures;

  /// The single image-only effect to play when this item is answered
  /// correctly. Defaults to [EffectPreset.squish] (always safe).
  final EffectPreset effectPreset;

  /// Effect intensity. Only [EffectIntensity.gentle] is shipped.
  final EffectIntensity effectIntensity;

  /// Optional semantic label exposed by TalkBack/VoiceOver. Children never see
  /// text, but the label describes the shape so caregivers can navigate.
  final String? accessibilityLabel;

  factory ShadowItem.fromJson(Map<String, dynamic> json) {
    return ShadowItem(
      id: json['id'] as String,
      imagePath: json['image'] as String,
      shadowPath: json['shadow'] as String,
      category: json['category'] as String,
      distractorIds: _stringList(json['distractors']),
      silhouetteFeatures: _stringList(json['silhouetteFeatures']),
      effectPreset: EffectPreset.parse(json['effectPreset']),
      effectIntensity: EffectIntensity.parse(json['effectIntensity']),
      accessibilityLabel: json['accessibilityLabel'] as String?,
      similarityGroup: json['similarityGroup'] as String?,
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return List<String>.unmodifiable(raw.map((e) => e.toString()));
    }
    return const <String>[];
  }

  ShadowItem withFallbacks({
    String? accessibilityLabel,
  }) {
    return ShadowItem(
      id: id,
      imagePath: imagePath,
      shadowPath: shadowPath,
      category: category,
      distractorIds: List<String>.unmodifiable(distractorIds),
      silhouetteFeatures: List<String>.unmodifiable(silhouetteFeatures),
      effectPreset: effectPreset,
      effectIntensity: effectIntensity,
      accessibilityLabel: accessibilityLabel ?? this.accessibilityLabel,
      similarityGroup: similarityGroup,
    );
  }
}

/// Conservative id check shared with the JSON loaders and the python
/// validator. Lowercase ASCII, digits and underscores only — this matches
/// the rule for MiniMax artifact filenames so a generated PNG can join the
/// catalog without renaming.
bool isValidItemId(String id) {
  if (id.isEmpty || id.length > 64) return false;
  for (final rune in id.runes) {
    final c = String.fromCharCode(rune);
    final ok = (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A) ||
        (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) ||
        c == '_';
    if (!ok) return false;
  }
  return true;
}
