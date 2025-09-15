// lib/data/firebase_menu_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/meal.dart';

extension FirebaseMenuRepositoryIds on FirebaseMenuRepository {
  Future<Set<int>> fetchAllIds() async {
    final snap = await _col.get();
    final ids = <int>{};
    for (final d in snap.docs) {
      final data = d.data();
      final fieldId = data['id'];
      if (fieldId is int) {
        ids.add(fieldId);
      } else if (fieldId is String) {
        final v = int.tryParse(fieldId);
        if (v != null) ids.add(v);
      } else {
        final v = int.tryParse(d.id);
        if (v != null) ids.add(v);
      }
    }
    return ids;
  }
}

class FirebaseMenuRepository {
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('meals');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---- READ --------------------------------------------------------------

  /// Firestore’dan hamma meal’larni xom map ko‘rinishida oladi va fieldlarni
  /// normalizatsiya qiladi (id, updatedAt, priceUzs, isAvailable, category, root).
  Future<List<Map<String, dynamic>>> fetchAllRaw() async {
    final snap = await _col.get();
    return snap.docs.map((d) {
      final j = Map<String, dynamic>.from(d.data());
      j['id'] = _coerceId(j['id'], d.id);
      j['updatedAt'] = _coerceDate(j['updatedAt']);
      j['priceUzs'] = _coerceInt(j['priceUzs']);
      j['isAvailable'] = (j['isAvailable'] as bool?) ?? true;
      final cat = (j['category'] as String?)?.trim();
      j['category'] = (cat == null || cat.isEmpty) ? 'Other' : cat;
      j['root'] = (j['root'] as String?) ?? 'food';
      return j;
    }).toList();
  }

  // ---- WRITE (REMOTE-FIRST uchun kerakli) --------------------------------

  /// Server timestamp bilan upsert qiladi, so‘ng hujjatni qayta o‘qib
  /// **serverdagi updatedAt** vaqtini qaytaradi.
  Future<DateTime> upsertReturningServerUpdatedAt(Meal meal) async {
    final data = meal.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp(); // server vaqti

    final docRef = _col.doc(meal.id.toString());
    await docRef.set(data, SetOptions(merge: true));

    final snap = await docRef.get();
    final m = snap.data() ?? {};

    final ts = m['updatedAt'];
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  /// Orqaga moslik: oddiy upsert (agar hohlasangiz ishlatishingiz mumkin).
  Future<void> upsert(Meal meal) async {
    await _col
        .doc(meal.id.toString())
        .set(meal.toJson(), SetOptions(merge: true));
  }

  /// Robust delete:
  /// 1) doc(id) bo‘lsa o‘chiradi
  /// 2) Bo‘lmasa `where('id' == id)` bilan topib, auto-ID hujjat(lar)ni ham o‘chiradi.
  Future<bool> deleteByIdOrField(int id) async {
    bool deleted = false;

    // 1) doc(id)
    final docRef = _col.doc(id.toString());
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      await docRef.delete();
      deleted = true;
    }

    // 2) field id == id (eski auto-ID hujjatlar)
    final q = await _col.where('id', isEqualTo: id).limit(50).get();
    for (final d in q.docs) {
      await d.reference.delete();
      deleted = true;
    }

    return deleted;
  }

  /// Orqaga moslik: faqat doc(id) ni o‘chiradi (agar ishlatayotgan bo‘lsangiz).
  Future<void> delete(int id) async {
    await _col.doc(id.toString()).delete();
  }

  /// Storage’ga rasm yuklash va public download URL qaytarish.
  Future<String> uploadImage({required int id, required File file}) async {
    final ref = _storage.ref().child('meals/$id${_extOf(file.path)}');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// (Ixtiyoriy) Rasm variantlarini o‘chirish (agar fayl nomini bilmasangiz).
  Future<void> deleteMealImageVariants(int id) async {
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      try {
        await _storage.ref('meals/$id$ext').delete();
      } catch (_) {
        /* ignore */
      }
    }
  }

  // ---- Helpers -----------------------------------------------------------

  int _coerceId(dynamic v, String docId) {
    if (v is int) return v;
    if (v is String) {
      return int.tryParse(v) ?? DateTime.now().microsecondsSinceEpoch;
    }
    final parsed = int.tryParse(docId);
    return parsed ?? DateTime.now().microsecondsSinceEpoch;
  }

  DateTime _coerceDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  int _coerceInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _extOf(String p) {
    final dot = p.lastIndexOf('.');
    return dot == -1 ? '.jpg' : p.substring(dot);
  }
}
