import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Very small file cache keyed by filename. We use predictable names per meal id.
class ImageCacheService {
  Future<String> ensureCached({
    required String remoteUrl,
    required String fileNameWithExt,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docs.path, 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    final destPath = p.join(imagesDir.path, fileNameWithExt);

    final file = File(destPath);
    if (await file.exists() && (await file.length()) > 0) {
      return destPath; // already cached
    }

    final resp = await http.get(Uri.parse(remoteUrl));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return destPath;
    }
    throw Exception('Failed to download image: ${resp.statusCode}');
  }
}
