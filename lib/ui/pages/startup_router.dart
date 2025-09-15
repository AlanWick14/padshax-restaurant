import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padshax_app/data/hive_menu_repository.dart';
import '../../data/sync_service.dart';
import 'create_meal_page.dart';
import 'menu_page.dart';

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final sync = context.read<SyncService>();
    final repo = context.read<HiveMenuRepository>();

    // Pull remote (if online) then decide route
    await sync.syncFromFirebase();
    final count = await repo.countMeals();

    if (!mounted) return;
    if (count == 0) {
      // First run → go to Create page as a real route
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateMealPage(firstRun: true)),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MenuPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
