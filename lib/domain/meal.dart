// lib/domain/meal.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'root_category.dart';

class Meal {
  final int id;
  final String name;
  final String description;
  final int priceUzs;
  final String imagePath; // offline uchun lokal/asset path
  final String? imageUrl; // onlayn rasm URL (Firestore/Storage)
  final String category; // sub-kategoriya nomi
  final RootCategory root; // food | drink
  final bool isAvailable;
  final DateTime updatedAt;

  const Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.priceUzs,
    required this.imagePath,
    required this.imageUrl,
    required this.category,
    required this.root,
    required this.isAvailable,
    required this.updatedAt,
  });

  /// copyWith: faqat berilgan maydonlarni yangilab, qolganlarini saqlaydi.
  Meal copyWith({
    int? id,
    String? name,
    String? description,
    int? priceUzs,
    String? imagePath,
    String? imageUrl,
    String? category,
    RootCategory? root,
    bool? isAvailable,
    DateTime? updatedAt,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceUzs: priceUzs ?? this.priceUzs,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      root: root ?? this.root,
      isAvailable: isAvailable ?? this.isAvailable,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore/JSON dan o‘qish. `updatedAt` Timestamp yoki String bo‘lishi mumkin.
  /// `imagePath` yo‘q bo‘lsa, `localImagePath` fallback sifatida ishlatiladi.
  factory Meal.fromJson(Map<String, dynamic> j, {String? localImagePath}) {
    final dynamicId = j['id'];
    final id = (dynamicId is int)
        ? dynamicId
        : (dynamicId is String ? int.tryParse(dynamicId) : null) ??
              DateTime.now().microsecondsSinceEpoch;

    final dynamicUpdated = j['updatedAt'];
    final updatedAt = (dynamicUpdated is Timestamp)
        ? dynamicUpdated.toDate()
        : (dynamicUpdated is String
              ? (DateTime.tryParse(dynamicUpdated) ?? DateTime.now())
              : (dynamicUpdated is DateTime ? dynamicUpdated : DateTime.now()));

    final rootKey = (j['root'] as String?) ?? 'food';

    return Meal(
      id: id,
      name: (j['name'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      priceUzs: _toInt(j['priceUzs']),
      imagePath:
          (j['imagePath'] as String?) ??
          localImagePath ??
          'assets/images/meals/padshax_defaultImage.webp',
      imageUrl: j['imageUrl'] as String?,
      category: _normalizeCategory(j['category']),
      root: RootCategoryX.fromKey(rootKey),
      isAvailable: (j['isAvailable'] as bool?) ?? true,
      updatedAt: updatedAt,
    );
  }

  /// Firestore/Storage uchun JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'priceUzs': priceUzs,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'category': category,
      'root': root.key,
      'isAvailable': isAvailable,
      // Upsertda serverTimestamp ishlatilsa ham, bu qiymat fallback bo‘lib turadi
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String _normalizeCategory(dynamic v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? 'Other' : s;
  }
}
