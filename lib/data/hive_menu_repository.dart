// lib/data/hive_menu_repository.dart
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/meal.dart';
import '../domain/root_category.dart';
import '../domain/category.dart';

extension HiveMenuRepositoryIds on HiveMenuRepository {
  Future<List<int>> listMealIds() async {
    final result = <int>[];
    for (final k in _meals.keys) {
      final asInt = (k is int) ? k : int.tryParse(k.toString());
      if (asInt != null) result.add(asInt);
    }
    return result;
  }
}

extension HiveMenuRepositorySubcatPrune on HiveMenuRepository {
  /// Firebase’dan kelgan (rootKey, name) lar to‘plamiga kirmaydigan
  /// sub-kategoriyalarni lokal bazadan o‘chiradi.
  Future<void> pruneSubCategoriesNotIn(Set<String> remotePairs) async {
    // remotePairs formati: "$rootKey::$name"
    final keysToDelete = <int>[];

    for (final entry in _subcategories.toMap().entries) {
      // key = int id, value = Map
      final id = entry.key;
      final v = Map<String, dynamic>.from(entry.value);
      final rootKey = (v['root'] as String).trim();
      final name = (v['name'] as String).trim();
      final key = '$rootKey::$name';

      if (!remotePairs.contains(key)) {
        // Agar bu sub-kategoriya ostida meal bo'lmasa, olib tashlaymiz.
        final hasMeals = _meals.values.any((vv) {
          final mm = Map<String, dynamic>.from(vv);
          return (mm['root'] == rootKey) && (mm['category'] == name);
        });
        if (!hasMeals && id is int) {
          keysToDelete.add(id);
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      await _subcategories.deleteAll(keysToDelete);
    }
  }
}

class HiveMenuRepository {
  late final Box<Map> _meals; // key: int id,   value: Map
  late final Box<Map> _subcategories; // key: int id,   value: {id, root, name}

  HiveMenuRepository._(this._meals, this._subcategories);

  static Future<HiveMenuRepository> open() async {
    await Hive.initFlutter();
    final meals = await Hive.openBox<Map>('meals');
    final subs = await Hive.openBox<Map>('subcategories');
    final intKeys = meals.keys.whereType<int>().toList();
    for (final k in intKeys) {
      final v = meals.get(k);
      if (v != null) {
        await meals.put(k.toString(), v);
        await meals.delete(k);
      }
    }

    return HiveMenuRepository._(meals, subs);
  }

  // =========================
  // CATEGORY API (SubCategory)
  // =========================

  Future<SubCategory?> getSubCategoryByName(
    RootCategory root,
    String name,
  ) async {
    name = name.trim();
    for (final v in _subcategories.values) {
      final m = Map<String, dynamic>.from(v);
      if ((m['root'] as String) == root.key &&
          (m['name'] as String).trim() == name) {
        return SubCategory(
          id: m['id'] as int,
          name: m['name'] as String,
          root: root,
        );
      }
    }
    return null;
  }

  Stream<List<SubCategory>> watchSubCategories(RootCategory root) async* {
    List<SubCategory> read() {
      final list = _subcategories.values
          .map((v) {
            final m = Map<String, dynamic>.from(v);
            return SubCategory(
              id: m['id'] as int,
              name: m['name'] as String,
              root: RootCategoryX.fromKey(m['root'] as String),
            );
          })
          .where((s) => s.root == root)
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }

    yield read();
    await for (final _ in _subcategories.watch()) {
      yield read();
    }
  }

  Future<int> upsertSubCategory(RootCategory root, String name) async {
    name = name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Sub-kategoriya nomi bo‘sh bo‘lishi mumkin emas');
    }
    // If exists, return its id
    final existing = await getSubCategoryByName(root, name);
    if (existing != null) return existing.id;

    // New id
    final newId = _nextId(_subcategories);
    final rec = {'id': newId, 'root': root.key, 'name': name};
    await _subcategories.put(newId, rec);
    return newId;
  }

  Future<void> renameSubCategory(int id, String newName) async {
    newName = newName.trim();
    if (newName.isEmpty) return;
    final v = _subcategories.get(id);
    if (v == null) return;
    final m = Map<String, dynamic>.from(v);
    m['name'] = newName;
    await _subcategories.put(id, m);
  }

  Future<bool> deleteSubCategory(int id) async {
    final v = _subcategories.get(id);
    if (v == null) return false;
    final m = Map<String, dynamic>.from(v);

    final rootKey = m['root'] as String;
    final name = m['name'] as String;

    // Ensure no meals point to it
    final hasMeals = _meals.values.any((vv) {
      final mm = Map<String, dynamic>.from(vv);
      return (mm['root'] == rootKey) && (mm['category'] == name);
    });
    if (hasMeals) return false;

    await _subcategories.delete(id);
    return true;
  }

  Future<void> deleteSubCategoryWithMeals(int id) async {
    final v = _subcategories.get(id);
    if (v == null) return;
    final m = Map<String, dynamic>.from(v);
    final rootKey = m['root'] as String;
    final name = m['name'] as String;

    // Delete meals under this subcat
    final keysToDelete = <dynamic>[];
    for (final key in _meals.keys) {
      final mm = Map<String, dynamic>.from(_meals.get(key)!);
      if (mm['root'] == rootKey && mm['category'] == name) {
        keysToDelete.add(key); // kalit qanday bo‘lsa, shuni qo‘yamiz (string)
      }
    }
    if (keysToDelete.isNotEmpty) {
      await _meals.deleteAll(keysToDelete);
    }

    await _subcategories.delete(id);
  }

  // =========================
  // MEAL QUERIES
  // =========================

  Future<int> countMeals() async => _meals.length;

  Future<Meal?> getMeal(int id) async {
    final v = _meals.get(id.toString());
    if (v == null) return null;
    return _mealFromMap(Map<String, dynamic>.from(v));
  }

  Stream<List<Meal>> watchAll({
    RootCategory? root,
    String? category,
    bool onlyAvailable = false,
  }) async* {
    Future<List<Meal>> read() async {
      Iterable<Map<String, dynamic>> vals = _meals.values.map(
        (e) => Map<String, dynamic>.from(e),
      );
      if (root != null) {
        vals = vals.where((m) => m['root'] == root.key);
      }
      if (category != null) {
        vals = vals.where((m) => m['category'] == category);
      }
      var items = vals.map(_mealFromMap).toList();
      if (onlyAvailable) {
        items = items.where((e) => e.isAvailable).toList();
      }
      // (istasa updatedAt bo‘yicha sort)
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    }

    yield await read();
    await for (final _ in _meals.watch()) {
      yield await read();
    }
  }

  Future<List<Meal>> searchByName(String query) async {
    final q = query.toLowerCase();
    final vals = _meals.values.map((e) => Map<String, dynamic>.from(e));
    return vals
        .where((m) => (m['name'] as String).toLowerCase().contains(q))
        .map(_mealFromMap)
        .toList();
  }

  // =========================
  // MEAL MUTATIONS
  // =========================

  Future<int> createMeal({
    required String name,
    required String description,
    required int priceUzs,
    required RootCategory root,
    required String category,
    XFile? pickedImage,
  }) async {
    final newId = DateTime.now().microsecondsSinceEpoch;

    String imagePath = 'assets/images/meals/padshax_defaultImage.webp';
    if (pickedImage != null) {
      imagePath = await _copyIntoManagedImages(
        pickedImage,
        fileName: 'meal_$newId',
      );
    }

    // Ensure subcategory exists
    await upsertSubCategory(root, category);

    final rec = _mealToMap(
      Meal(
        id: newId,
        name: name,
        description: description,
        priceUzs: priceUzs,
        imagePath: imagePath,
        imageUrl: null,
        category: category,
        root: root,
        isAvailable: true,
        updatedAt: DateTime.now(),
      ),
    );
    await _meals.put(newId.toString(), rec);
    return newId;
  }

  Future<void> renameSubCategoryCascade({
    required int id,
    required String newName,
  }) async {
    newName = newName.trim();
    if (newName.isEmpty) return;

    final v = _subcategories.get(id);
    if (v == null) return;
    final m = Map<String, dynamic>.from(v);

    final oldName = m['name'] as String;
    final rootKey = m['root'] as String;

    // 1) Subcat nomini yangilash
    m['name'] = newName;
    await _subcategories.put(id, m);

    // 2) Shu subcat nomini ishlatayotgan meal’larni yangilash
    for (final key in _meals.keys) {
      final mm = Map<String, dynamic>.from(_meals.get(key)!);
      if (mm['root'] == rootKey && mm['category'] == oldName) {
        mm['category'] = newName;
        await _meals.put(key, mm);
      }
    }
  }

  Future<void> updateMeal({
    required int id,
    String? name,
    String? description,
    int? priceUzs,
    String? imagePath,
    String? imageUrl,
    String? category,
    RootCategory? root,
    bool? isAvailable,
    DateTime? updatedAt,
  }) async {
    final v = _meals.get(id.toString());
    if (v == null) return;
    final m = Map<String, dynamic>.from(v);

    if (name != null) m['name'] = name;
    if (description != null) m['description'] = description;
    if (priceUzs != null) m['priceUzs'] = priceUzs;
    if (imagePath != null) m['imagePath'] = imagePath;
    if (imageUrl != null) m['imageUrl'] = imageUrl;
    if (category != null) m['category'] = category;
    if (root != null) m['root'] = root.key;
    if (isAvailable != null) m['isAvailable'] = isAvailable;
    m['updatedAt'] = (updatedAt ?? DateTime.now()).toIso8601String();

    await _meals.put(id.toString(), m);

    // ensure subcategory presence if provided
    if (root != null && category != null) {
      await upsertSubCategory(root, category);
    }
  }

  Future<void> upsertFromRemote(Meal remote) async {
    await _meals.put(remote.id.toString(), _mealToMap(remote));
  }

  Future<void> deleteMeal(int id) async {
    String? oldPath;
    final v = _meals.get(id.toString());
    if (v != null) {
      final m = Map<String, dynamic>.from(v);
      oldPath = m['imagePath'] as String?;
    }
    await _meals.delete(id.toString());

    if (oldPath != null) {
      await _safeDeleteImageIfUnused(oldPath);
    }
  }

  // =========================
  // IMAGE HELPERS
  // =========================

  Future<String> _copyIntoManagedImages(
    XFile picked, {
    String? fileName,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docs.path, 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

    final ext = p.extension(picked.path).toLowerCase();
    final filename =
        (fileName ?? 'meal_${DateTime.now().millisecondsSinceEpoch}') + ext;
    final destPath = p.join(imagesDir.path, filename);

    await File(picked.path).copy(destPath);
    return destPath;
  }

  Future<void> _safeDeleteImageIfUnused(String path) async {
    if (path.startsWith('assets/')) return;
    final norm = p.normalize(path);
    final stillUsed = _meals.values.any((v) {
      final m = Map<String, dynamic>.from(v);
      return (m['imagePath'] as String) == norm;
    });
    if (!stillUsed) {
      try {
        await File(norm).delete();
      } catch (_) {}
    }
  }

  // =========================
  // MAPPERS
  // =========================

  Map<String, dynamic> _mealToMap(Meal m) => {
    'id': m.id,
    'name': m.name,
    'description': m.description,
    'priceUzs': m.priceUzs,
    'imagePath': m.imagePath,
    'imageUrl': m.imageUrl,
    'category': m.category,
    'root': m.root.key,
    'isAvailable': m.isAvailable,
    'updatedAt': m.updatedAt.toIso8601String(),
  };

  Meal _mealFromMap(Map<String, dynamic> m) => Meal(
    id: m['id'] as int,
    name: m['name'] as String,
    description: (m['description'] as String?) ?? '',
    priceUzs: (m['priceUzs'] as int?) ?? 0,
    imagePath: m['imagePath'] as String,
    imageUrl: m['imageUrl'] as String?,
    category: m['category'] as String,
    root: RootCategoryX.fromKey(m['root'] as String),
    isAvailable: (m['isAvailable'] as bool?) ?? true,
    updatedAt:
        DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  int _nextId(Box box) {
    final ks = box.keys.whereType<int>();
    if (ks.isEmpty) return 1;
    return ks.reduce((a, b) => a > b ? a : b) + 1;
  }
}
