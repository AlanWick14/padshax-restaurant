import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:padshax_app/data/hive_menu_repository.dart';
import 'package:padshax_app/ui/theme/app_theme.dart';
import 'firebase_options.dart';
import 'data/firebase_menu_repository.dart';
import 'data/image_cache_service.dart';
import 'data/sync_service.dart';
import 'logic/cart_cubit.dart';
import 'ui/pages/startup_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final hiveRepo = await HiveMenuRepository.open();
  final fbRepo = FirebaseMenuRepository();
  final imageCache = ImageCacheService();
  final sync = SyncService(
    hiveRepo: hiveRepo,
    fbRepo: fbRepo,
    imageCache: imageCache,
  );

  runApp(MyApp(hiveRepo: hiveRepo, sync: sync));
}

class MyApp extends StatelessWidget {
  final HiveMenuRepository hiveRepo;
  final SyncService sync;
  const MyApp({super.key, required this.hiveRepo, required this.sync});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: hiveRepo),
        RepositoryProvider.value(value: sync),
      ],
      child: MultiBlocProvider(
        providers: [BlocProvider(create: (_) => CartCubit())],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Padshax Menu',
          theme: buildRestaurantTheme(),
          home: const StartupRouter(),
        ),
      ),
    );
  }
}
