import 'dart:io';
import 'package:flutter/material.dart';

class ImageAny extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final String placeholderAsset;

  const ImageAny(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.placeholderAsset = 'assets/images/meals/padshax_defaultImage.webp',
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return Image.asset(placeholderAsset, fit: fit);
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(placeholderAsset, fit: fit),
      );
    }
    return FutureBuilder<bool>(
      future: File(path).exists(),
      builder: (context, snap) {
        final exists = snap.data == true;
        if (!exists) {
          return Image.asset(placeholderAsset, fit: fit);
        }
        return Image.file(
          File(path),
          fit: fit,
          errorBuilder: (_, __, ___) => Image.asset(placeholderAsset, fit: fit),
        );
      },
    );
  }
}
