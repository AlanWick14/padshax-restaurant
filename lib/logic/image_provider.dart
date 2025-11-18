import 'dart:io';
import 'package:flutter/widgets.dart';

ImageProvider resolveMealImageProvider(String path) {
  if (path.startsWith('http')) return NetworkImage(path);
  if (path.startsWith('/')) return FileImage(File(path));
  return AssetImage(path);
}
