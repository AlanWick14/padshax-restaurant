// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:padshax_app/data/hive_menu_repository.dart';

import 'package:padshax_app/main.dart'; // for MyApp
import 'package:padshax_app/firebase_options.dart';
import 'package:padshax_app/data/firebase_menu_repository.dart';
import 'package:padshax_app/data/image_cache_service.dart';
import 'package:padshax_app/data/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize Firebase for test (uses your generated firebase_options.dart)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Build required dependencies for MyApp
    final hiveRepo = await HiveMenuRepository.open();
    final fbRepo = FirebaseMenuRepository();
    final imageCache = ImageCacheService();
    final sync = SyncService(
      hiveRepo: hiveRepo,
      fbRepo: fbRepo,
      imageCache: imageCache,
    );

    // Pump the app with required args
    await tester.pumpWidget(MyApp(hiveRepo: hiveRepo, sync: sync));

    // Let first frames settle
    await tester.pumpAndSettle();

    // Simple smoke assertions (your app is not a counter demo)
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Restaurant Menu'), findsNothing); // adjust to your UI
  });
}
