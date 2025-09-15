// lib/ui/pages/admin_home_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:padshax_app/ui/pages/admin_login_page.dart';
import 'package:padshax_app/ui/widgets/loading_overlay.dart';
import 'package:padshax_app/ui/widgets/root_selector_bar.dart';
import 'package:padshax_app/ui/widgets/subcategory_bar.dart';
import 'package:padshax_app/utils/auth_gate.dart';
import 'package:provider/provider.dart';

import '../../data/hive_menu_repository.dart';
import '../../data/sync_service.dart';
import '../../domain/meal.dart';
import '../../domain/root_category.dart';
import '../widgets/image_any.dart';
import 'create_meal_page.dart';
import 'edit_meal_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  RootCategory _root = RootCategory.food;
  String? _selectedCategory; // null = All

  @override
  Widget build(BuildContext context) {
    final repo = context.read<HiveMenuRepository>();
    final sync = context.read<SyncService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTablet = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      // Fixed AppBar color (no tonal overlay on scroll)
      appBar: AppBar(
        title: const Text('Admin — Menu'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Sync from Firebase",
            onPressed: () async {
              LoadingOverlay.show(
                context,
                message: 'Firebase bilan sinxronlanmoqda',
              );
              try {
                await sync.syncFromFirebase();
                if (mounted) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sinxronlash tugadi')),
                  );
                  setState(() {});
                }
              } finally {
                if (context.mounted) LoadingOverlay.hide(context);
              }
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pop(); // admin sahifadan chiqish
            },
          ),
        ],
      ),

      // Bottom-left Add Meal button (beautiful, extended)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _AddMealFab(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreateMealPage()));
          if (!mounted) return;
          setState(() {});
        },
        label: 'Add meal',
      ),

      body: CustomScrollView(
        slivers: [
          // Root selector — pill tabs with icons (pretty + Menu page vibe)
          SliverToBoxAdapter(
            child: RootSelectorBar(
              value: _root,
              onChanged: (r) {
                setState(() {
                  _root = r;
                  _selectedCategory = null;
                });
              },
              isTablet: isTablet,
            ),
          ),
          SliverToBoxAdapter(
            child: SubCategoryBar(
              root: _root,
              selected: _selectedCategory,
              onSelected: (c) => setState(() => _selectedCategory = c),
              isTablet: isTablet,
              withActions: true, // admin: show ⋮
              onEdit: (sub) async {
                final controller = TextEditingController(text: sub.name);
                final newName = await showDialog<String?>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sub-kategoriya nomini o‘zgartirish'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Yangi nom',
                        hintText: 'masalan: Sho‘rva…',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text('Bekor qilish'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, controller.text.trim()),
                        child: const Text('Saqlash'),
                      ),
                    ],
                  ),
                );
                if (newName != null &&
                    newName.isNotEmpty &&
                    newName != sub.name) {
                  if (!context.mounted) return;
                  await context
                      .read<HiveMenuRepository>()
                      .renameSubCategoryCascade(id: sub.id, newName: newName);
                  if (_selectedCategory == sub.name) {
                    setState(() => _selectedCategory = newName);
                  }
                }
              },
              onDelete: (sub) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sub-kategoriyani o‘chirish'),
                    content: Text(
                      '“${sub.name}” va UNING BARCHA TAOMLARI o‘chirilsinmi? Bu amal qaytarilmaydi.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Bekor qilish'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('O‘chirish'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  if (!context.mounted) return;
                  await context
                      .read<HiveMenuRepository>()
                      .deleteSubCategoryWithMeals(sub.id);
                  if (_selectedCategory == sub.name) {
                    setState(() => _selectedCategory = null);
                  }
                }
              },
            ),
          ),

          // Meals list (old design kept)
          StreamBuilder<List<Meal>>(
            stream: repo.watchAll(root: _root, category: _selectedCategory),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final meals = snap.data!;
              if (meals.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("Hozircha taomlar yo'q")),
                );
              }
              return _MealsListSliver(
                meals: meals,
                onChanged: () => setState(() {}),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// -------------------- Subcategory bar --------------------

// -------------------- Meals list (old design) --------------------

class _MealsListSliver extends StatelessWidget {
  final List<Meal> meals;
  final VoidCallback onChanged;
  const _MealsListSliver({required this.meals, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 700;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final m = meals[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: isTablet ? 10 : 6,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: ImageAny(m.imagePath, fit: BoxFit.cover),
            ),
          ),
          title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_fmtPrice(m.priceUzs)),
          trailing: _MealActions(meal: m, onChanged: onChanged),
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EditMealPage(mealId: m.id, meal: m),
              ),
            );
            if (changed == true) onChanged();
          },
        );
      }, childCount: meals.length),
    );
  }

  String _fmtPrice(int v) {
    final s = v.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _MealActions extends StatelessWidget {
  final Meal meal;
  final VoidCallback onChanged;
  const _MealActions({required this.meal, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Tahrirlash',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditMealPage(mealId: meal.id, meal: meal),
                ),
              );
              if (changed == true) onChanged();
            },
          ),
          IconButton(
            tooltip: "O'chirish",
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              // 1) adminmi?
              final authed = await ensureAdminSignedIn(context);
              if (!authed) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Firebase’dan o‘chirish uchun admin kirishi kerak.',
                      ),
                    ),
                  );
                }
                return;
              }
              if (!context.mounted) return;
              // 2) tasdiq
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("O'chirishni tasdiqlang"),
                  content: Text(
                    "'${meal.name}' o'chirilsinmi? (Bulutdan keyin lokal ham o'chiriladi)",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bekor qilish'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("O'chirish"),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              if (!context.mounted) return;
              // 3) remote-first delete
              final sync = context.read<SyncService>();
              final okRemote = await sync.deleteCloudThenLocal(meal.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      okRemote
                          ? "O‘chirildi (Firebase ham o‘chirildi)"
                          : "Firebase’dan o‘chirilmadi (topilmadi/ruxsat yo‘q/online emas).",
                    ),
                  ),
                );
                if (okRemote) onChanged();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------- Bottom-left FAB (beautiful, extended) ----------

class _AddMealFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const _AddMealFab({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      heroTag: 'add_meal_fab',
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const StadiumBorder(),
      elevation: 3,
    );
  }
}
