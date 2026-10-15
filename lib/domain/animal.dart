/// Legacy compatibility shim.
///
/// The original `Animal` type was specific to animal illustrations and used
/// a separate `name` field that is not part of the v6 content-neutral model.
/// During the staged migration (see Issue #29) the class is kept so the old
/// demo assets and existing `round_factory_test.dart` continue to compile,
/// but it now forwards all data to [ShadowItem].
///
/// New code should depend on `ShadowItem` directly.
library;

import 'effect_preset.dart';
import 'shadow_item.dart';

class Animal extends ShadowItem {
  Animal({
    required super.id,
    required String name,
    required super.imagePath,
    required super.shadowPath,
    required super.category,
    required super.distractorIds,
  }) : super(accessibilityLabel: name);

  /// Compatibility getter preserved for the legacy semantics label.
  String get name => accessibilityLabel ?? id;

  factory Animal.fromJson(Map<String, dynamic> json) {
    final item = ShadowItem.fromJson(json);
    return Animal(
      id: item.id,
      name: (json['name'] as String?) ?? item.accessibilityLabel ?? item.id,
      imagePath: item.imagePath,
      shadowPath: item.shadowPath,
      category: item.category,
      distractorIds: item.distractorIds,
    );
  }

  @override
  Animal withFallbacks({String? accessibilityLabel}) {
    return Animal(
      id: id,
      name: accessibilityLabel ?? this.accessibilityLabel ?? id,
      imagePath: imagePath,
      shadowPath: shadowPath,
      category: category,
      distractorIds: List<String>.unmodifiable(distractorIds),
    );
  }
}

/// Convenience access used by the catalog loader. Keeps callers from having
/// to special-case the legacy `name` field.
String resolveAnimalName(Map<String, dynamic> json) {
  final value = json['name'];
  if (value is String && value.isNotEmpty) return value;
  final idValue = json['id'];
  return idValue is String ? idValue : '';
}

// Re-export the v6 catalog entity so the rest of the codebase can keep
// `import 'package:animal_shadow_match/domain/animal.dart';` working but
// gradually move to `shadow_item.dart`.
typedef ShadowEffectPreset = EffectPreset;
