class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.shadowPath,
    required this.category,
    required this.distractorIds,
  });

  final String id;
  final String name;
  final String imagePath;
  final String shadowPath;
  final String category;
  final List<String> distractorIds;

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['image'] as String,
      shadowPath: json['shadow'] as String,
      category: json['category'] as String,
      distractorIds: List<String>.from(json['distractors'] as List<dynamic>),
    );
  }
}
