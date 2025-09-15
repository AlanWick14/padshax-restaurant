// lib/data/sync_service.dart
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:padshax_app/domain/root_category.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/meal.dart';
import 'firebase_menu_repository.dart';
import 'hive_menu_repository.dart';
import 'image_cache_service.dart';

class SyncService {
  final HiveMenuRepository hiveRepo;
  final FirebaseMenuRepository fbRepo;
  final ImageCacheService imageCache;

  SyncService({
    required this.hiveRepo,
    required this.fbRepo,
    required this.imageCache,
  });

  // ---- Connectivity ------------------------------------------------------

  Future<bool> get isOnline async {
    final c = await Connectivity().checkConnectivity();
    return c.contains(ConnectivityResult.wifi) ||
        c.contains(ConnectivityResult.mobile);
  }

  // ---- PULL: Firebase -> Hive (startup sync) -----------------------------

  /// Bulutdan barcha meal’larni olib keladi.
  /// Agar remote.updatedAt lokalnikidan YANGI bo‘lsa, lokalni yangilaydi.
  /// Aks holda SKIP (rollback bo‘lmasin).
  Future<void> syncFromFirebase() async {
    if (!await isOnline) return;

    // 🔹 Remote’dan kelgan sub-category juftliklari: "$rootKey::$name"
    final remoteSubPairs = <String>{};

    final remote = await fbRepo.fetchAllRaw(); // normalized Map’lar
    for (final j in remote) {
      try {
        final m = Meal.fromJson(
          j,
          localImagePath: 'assets/images/meals/padshax_defaultImage.webp',
        );

        // Juftlikni to'plab boramiz (root+category)
        final rootKey = m.root.key; // masalan: "food"
        final catName = (m.category).trim(); // "Sho'rva", "Burger", ...
        remoteSubPairs.add('$rootKey::$catName');

        // Lokal yangiroq bo‘lsa — SKIP
        final local = await hiveRepo.getMeal(m.id);
        if (local != null && local.updatedAt.isAfter(m.updatedAt)) {
          continue;
        }

        // Rasm cache
        String localPath = m.imagePath;
        if (m.imageUrl != null && m.imageUrl!.isNotEmpty) {
          localPath = await imageCache.ensureCached(
            remoteUrl: m.imageUrl!,
            fileNameWithExt: 'meal_${m.id}${_extFromUrl(m.imageUrl!)}',
          );
        }

        // Meal va sub-category’ni mavjud ekanligiga ishonch hosil qilib upsert
        await hiveRepo.upsertSubCategory(m.root, m.category);
        await hiveRepo.upsertFromRemote(m.copyWith(imagePath: localPath));
      } catch (e, s) {
        debugPrint('syncFromFirebase item error: $e\n$s');
      }
    }

    // 🔻 Meals uchun PRUNE (Firebase’da yo‘q bo‘lsa lokalni o‘chir)
    try {
      final remoteIds = await fbRepo.fetchAllIds();
      final localIds = await hiveRepo.listMealIds();
      for (final id in localIds) {
        if (!remoteIds.contains(id)) {
          await hiveRepo.deleteMeal(id);
        }
      }
    } catch (e, s) {
      debugPrint('syncFromFirebase pruning error: $e\n$s');
    }

    // 🔻 Sub-category’lar uchun PRUNE:
    // Remote’dan kelgan juftliklarga kirmaydigan sub-category’larni o‘chir.
    try {
      await hiveRepo.pruneSubCategoriesNotIn(remoteSubPairs);
    } catch (e, s) {
      debugPrint('syncFromFirebase subcat prune error: $e\n$s');
    }
  }

  // ---- UPSERT: AVVAL CLOUD, keyin LOCAL ---------------------------------

  /// Create/Edit: Cloud OK bo‘lsa, keyin lokalni yangilaydi.
  Future<bool> upsertCloudThenLocal({
    required Meal draft,
    File? pickedImageFile,
  }) async {
    // print('isOnline ${isOnline.toString()}');
    if (!await isOnline) return false;
    // print('iscurrentuser ');
    // print('adada: ${FirebaseAuth.instance.currentUser}');
    if (FirebaseAuth.instance.currentUser == null) return false;
    try {
      // 1) Rasmni Storage'ga (bo‘lsa)
      String? imageUrl = draft.imageUrl;
      if (pickedImageFile != null) {
        imageUrl = await fbRepo.uploadImage(
          id: draft.id,
          file: pickedImageFile,
        );
      }

      // 2) Cloud: serverTimestamp bilan upsert, va server updatedAt ni olish
      final serverUpdatedAt = await fbRepo.upsertReturningServerUpdatedAt(
        draft.copyWith(imageUrl: imageUrl),
      );

      // 3) Lokal rasm yo‘li (cache yoki lokal nusxa)
      String localPath = draft.imagePath;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        localPath = await imageCache.ensureCached(
          remoteUrl: imageUrl,
          fileNameWithExt: 'meal_${draft.id}${_extFromUrl(imageUrl)}',
        );
      } else if (pickedImageFile != null) {
        // URL yo‘q bo‘lsa ham lokalga nusxa (fallback)
        localPath = await _copyIntoManagedImages(
          pickedImageFile,
          fileName: 'meal_${draft.id}',
        );
      }

      // 4) LOCAL upsert (faqat cloud OK bo‘lgach)
      await hiveRepo.upsertSubCategory(draft.root, draft.category);
      await hiveRepo.upsertFromRemote(
        draft.copyWith(
          imageUrl: imageUrl,
          imagePath: localPath,
          updatedAt: serverUpdatedAt,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('upsertCloudThenLocal error: $e');
      return false;
    }
  }

  // ---- DELETE: AVVAL CLOUD, keyin LOCAL ---------------------------------

  /// Delete: avval Firestore’dan (docId yoki field id bo‘yicha),
  /// muvaffaqiyatli bo‘lsa keyin lokalni tozalaydi.
  Future<bool> deleteCloudThenLocal(int id) async {
    if (!await isOnline) return false;
    if (FirebaseAuth.instance.currentUser == null) return false;

    try {
      final ok = await fbRepo.deleteByIdOrField(id);
      if (!ok) return false;

      // (ixtiyoriy) rasm variantlarini ham o‘chirib ko‘ramiz
      await fbRepo.deleteMealImageVariants(id);

      await hiveRepo.deleteMeal(id);
      return true;
    } catch (e) {
      debugPrint('deleteCloudThenLocal error: $e');
      return false;
    }
  }

  // ---- Helpers -----------------------------------------------------------

  String _extFromUrl(String url) {
    final q = url.split('?').first;
    final i = q.lastIndexOf('.');
    if (i == -1) return '.jpg';
    final ext = q.substring(i);
    return (ext.length > 8 || ext.contains('/')) ? '.jpg' : ext;
  }

  Future<String> _copyIntoManagedImages(
    File file, {
    required String fileName,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docs.path, 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

    final ext = p.extension(file.path).toLowerCase();
    final dest = p.join(imagesDir.path, '$fileName$ext');
    await file.copy(dest);
    return dest;
  }
}
