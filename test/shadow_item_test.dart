import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _stub({
  String id = 'gel_star',
  String image = 'assets/items/gel_star.webp',
  String shadow = 'assets/items/gel_star_shadow.webp',
  String category = 'squishy_object',
  List<String> distractors = const ['cloud_cushion'],
  EffectPreset preset = EffectPreset.squish,
  EffectIntensity intensity = EffectIntensity.gentle,
}) {
  return ShadowItem(
    id: id,
    imagePath: image,
    shadowPath: shadow,
    category: category,
    distractorIds: distractors,
    effectPreset: preset,
    effectIntensity: intensity,
    accessibilityLabel: 'Gel Star',
  );
}

Map<String, dynamic> _json() => <String, dynamic>{
      'id': 'gel_star',
      'image': 'assets/items/gel_star.webp',
      'shadow': 'assets/items/gel_star_shadow.webp',
      'category': 'squishy_object',
      'distractors': ['cloud_cushion', 'teardrop_gummy'],
      'silhouetteFeatures': ['star_outline'],
      'effectPreset': 'wobble',
      'effectIntensity': 'gentle',
      'accessibilityLabel': 'Gel Star',
    };

void main() {
  group('isValidItemId', () {
    test('accepts lowercase ids with digits and underscores', () {
      expect(isValidItemId('gel_star'), isTrue);
      expect(isValidItemId('toy_001'), isTrue);
      expect(isValidItemId('abc123'), isTrue);
    });

    test('rejects empty, uppercase, punctuation, and emoji ids', () {
      expect(isValidItemId(''), isFalse);
      expect(isValidItemId('Gel-Star'), isFalse);
      expect(isValidItemId('gel star'), isFalse);
      expect(isValidItemId('gel/star'), isFalse);
      expect(isValidItemId('star!'), isFalse);
      expect(isValidItemId('🐙'), isFalse);
    });
  });

  group('ShadowItem.fromJson', () {
    test('hydrates every documented field', () {
      final item = ShadowItem.fromJson(_json());
      expect(item.id, 'gel_star');
      expect(item.imagePath, 'assets/items/gel_star.webp');
      expect(item.shadowPath, 'assets/items/gel_star_shadow.webp');
      expect(item.category, 'squishy_object');
      expect(item.distractorIds, ['cloud_cushion', 'teardrop_gummy']);
      expect(item.silhouetteFeatures, ['star_outline']);
      expect(item.effectPreset, EffectPreset.wobble);
      expect(item.effectIntensity, EffectIntensity.gentle);
      expect(item.accessibilityLabel, 'Gel Star');
    });

    test('falls back to squish when effectPreset is missing or unknown', () {
      final json = _json()..remove('effectPreset');
      expect(ShadowItem.fromJson(json).effectPreset, EffectPreset.squish);

      final unknown = _json()..['effectPreset'] = 'teleport';
      expect(ShadowItem.fromJson(unknown).effectPreset, EffectPreset.squish);
    });

    test('omits distractor and feature lists when JSON is sparse', () {
      final json = _json()
        ..remove('distractors')
        ..remove('silhouetteFeatures')
        ..remove('accessibilityLabel');
      final item = ShadowItem.fromJson(json);
      expect(item.distractorIds, isEmpty);
      expect(item.silhouetteFeatures, isEmpty);
      expect(item.accessibilityLabel, isNull);
    });
  });

  group('EffectPreset', () {
    test('parses documented names case-insensitively', () {
      expect(EffectPreset.parse('Squish'), EffectPreset.squish);
      expect(EffectPreset.parse('WOBBLE'), EffectPreset.wobble);
      expect(EffectPreset.parse('bounce'), EffectPreset.bounce);
      expect(EffectPreset.parse('inflate'), EffectPreset.inflate);
    });
  });

  group('ShadowItem — defaults & invariants', () {
    test('default constructor produces a safe playable item', () {
      final item = _stub();
      expect(item.effectPreset, EffectPreset.squish);
      expect(item.effectIntensity, EffectIntensity.gentle);
      expect(item.silhouetteFeatures, isEmpty);
    });
  });
}
