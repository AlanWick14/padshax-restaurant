import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padshax_app/data/hive_menu_repository.dart';
import 'package:padshax_app/data/sync_service.dart';
import 'package:padshax_app/logic/image_provider.dart';
import 'package:padshax_app/ui/widgets/image_any.dart';
import 'package:padshax_app/ui/widgets/loading_overlay.dart';
import 'package:padshax_app/ui/widgets/root_selector_bar.dart';
import 'package:padshax_app/ui/widgets/subcategory_bar.dart';
import 'package:padshax_app/utils/auth_gate.dart';

import '../../domain/meal.dart';
import '../../domain/root_category.dart';
import '../../logic/cart_cubit.dart';
import '../../logic/cart_state.dart';
import '../widgets/meal_card.dart';
import 'cart_page.dart';
import 'admin_home_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  String _query = '';
  String? _selectedCategory; // null = All
  RootCategory _root = RootCategory.food;
  Timer? _snackDebounce;
  int _pendingAdds = 0;
  String? _lastMealName;

  late AnimationController _searchController;
  bool _isSearchExpanded = false;
  final TextEditingController _searchTextController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _searchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchTextController.addListener(() {
      final q = _searchTextController.text.trim();
      setState(() {
        _query = q;
        if (q.isNotEmpty) {
          _selectedCategory = null; // 🔎 search globally (no subcat filter)
        } else {
          _autoSelectFirstSubcatForRoot(); // back to first subcat when cleared
        }
      });
    });

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchTextController.text.isEmpty) {
        _collapseSearch();
      }
    });

    // pick first subcat on first paint
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoSelectFirstSubcatForRoot(),
    );
  }

  @override
  void dispose() {
    _snackDebounce?.cancel();
    _searchController.dispose();
    _searchTextController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openMealImageViewer(Meal meal) async {
    final provider = resolveMealImageProvider(meal.imagePath);

    // 👇 Ensure the big image is ready before transition (prevents flash)
    await precacheImage(provider, context);

    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) =>
            _MealImageViewer(meal: meal, provider: provider),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _autoSelectFirstSubcatForRoot() {
    // Only pick if nothing is selected yet
    if (_selectedCategory != null) return;

    final repo = context.read<HiveMenuRepository>();
    // Grab the first snapshot of subcategories for the current root
    repo.watchSubCategories(_root).first.then((subs) {
      if (!mounted) return;
      if (subs.isEmpty) return;

      // "First created" ≈ smallest id (Isar ids are monotonic by creation)
      subs.sort((a, b) => a.id.compareTo(b.id));
      setState(() => _selectedCategory = subs.first.name);
    });
  }

  void _collapseSearch() {
    setState(() => _isSearchExpanded = false);
    _searchController.reverse();
    _searchFocusNode.unfocus();
    if (_searchTextController.text.isEmpty) {
      setState(() => _query = '');
      _autoSelectFirstSubcatForRoot(); // 👈 ensure we select first subcat
    }
  }

  void _expandSearch() {
    setState(() => _isSearchExpanded = true);
    _searchController.forward();
    _searchFocusNode.requestFocus();
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
  }

  void _addToCartWithDebouncedSnack(Meal meal) {
    // Add to cart immediately
    context.read<CartCubit>().add(meal);

    // Aggregate taps
    _pendingAdds++;
    _lastMealName = meal.name;

    // Reset debounce
    _snackDebounce?.cancel();
    _snackDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars(); // prevent queue

      final text = (_pendingAdds <= 1)
          ? '${_lastMealName ?? 'Taom'} savatchaga qo\'shildi'
          : '$_pendingAdds ta mahsulot savatchaga qo\'shildi';

      final scheme = Theme.of(context).colorScheme;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: scheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Ko\'rish',
            textColor: scheme.onPrimaryContainer,
            onPressed: _openCart,
          ),
        ),
      );

      // reset counters
      _pendingAdds = 0;
      _lastMealName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<HiveMenuRepository>();
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final isTablet = width >= 600;

    // Responsive columns
    // Responsive columns
    int crossAxisCount;
    double childAspectRatio;

    if (width < 600) {
      crossAxisCount = 1;
      childAspectRatio = 2.6; // was 3.0 -> taller tiles
    } else if (width < 900) {
      crossAxisCount = 2;
      childAspectRatio = 2.9; // was 3.3
    } else if (width < 1200) {
      crossAxisCount = 3;
      childAspectRatio = 3.2; // was 3.5
    } else if (width < 1500) {
      crossAxisCount = 4;
      childAspectRatio = 3.4; // was 3.7
    } else {
      crossAxisCount = 5;
      childAspectRatio = 3.6; // was 3.9
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      // ⛔ no floatingActionButton anymore
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, scheme, isTablet),
          SliverToBoxAdapter(
            child: RootSelectorBar(
              value: _root,
              isTablet: isTablet,
              onChanged: (r) {
                setState(() {
                  _root = r;
                  _selectedCategory = null; // clear subcat on root switch
                });
                _autoSelectFirstSubcatForRoot();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SubCategoryBar(
              root: _root,
              selected: _selectedCategory, // null = no filter
              isTablet: isTablet,
              withActions: false, // Menu page: no edit/delete menu
              onSelected: (c) => setState(() => _selectedCategory = c),
            ),
          ),

          _buildMealGrid(
            context,
            repo,
            scheme,
            isTablet,
            crossAxisCount,
            childAspectRatio,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme scheme, bool isTablet) {
    return SliverAppBar(
      expandedHeight: isTablet ? 200 : 160,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        title: _isSearchExpanded
            ? null
            : Text(
                'Menu',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 28 : 24,
                ),
              ),
        titlePadding: EdgeInsets.only(
          left: isTablet ? 24 : 16,
          bottom: isTablet ? 20 : 16,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.3),
                scheme.secondaryContainer.withValues(alpha: 0.2),
                scheme.surface,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: isTablet ? 60 : 40,
                right: -20,
                child: Icon(
                  Icons.restaurant_menu,
                  size: isTablet ? 120 : 100,
                  color: scheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Search Button/Field in AppBar
        AnimatedBuilder(
          animation: _searchController,
          builder: (context, child) {
            return Container(
              width: _isSearchExpanded ? (isTablet ? 320 : 240) : 48,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: _isSearchExpanded
                  ? TextField(
                      controller: _searchTextController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Taom qidirish...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchTextController.clear();
                            _collapseSearch();
                          },
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _expandSearch,
                      icon: const Icon(Icons.search),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
            );
          },
        ),
        const SizedBox(width: 8),

        // Cart Button with Badge in AppBar
        BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            return Stack(
              children: [
                IconButton(
                  onPressed: _openCart,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                  ),
                ),
                if (!cartState.isEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cartState.items.fold(0, (sum, item) => sum + item.qty)}',
                        style: TextStyle(
                          color: scheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        IconButton(
          tooltip: 'Sync from Firebase',
          icon: const Icon(Icons.sync),
          onPressed: () async {
            LoadingOverlay.show(context, message: 'Sinxronlanmoqda…');
            try {
              await context.read<SyncService>().syncFromFirebase();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sinxronlash tugadi')),
              );
              setState(() {}); // if any local quick reads need refresh
            } finally {
              if (mounted) LoadingOverlay.hide(context);
            }
          },
        ),

        // Admin Button
        IconButton(
          tooltip: 'Admin',
          icon: const Icon(Icons.admin_panel_settings),
          onPressed: () async {
            final ok = await ensureAdminSignedIn(context);
            if (!ok) return;
            if (!context.mounted) return;
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AdminHomePage()));
          },
        ),
        SizedBox(width: isTablet ? 24 : 16),
      ],
    );
  }

  Widget _buildMealGrid(
    BuildContext context,
    HiveMenuRepository repo,
    ColorScheme scheme,
    bool isTablet,
    int crossAxisCount,
    double childAspectRatio,
  ) {
    return StreamBuilder<List<Meal>>(
      stream: repo.watchAll(
        root: _root,
        category: _query.isNotEmpty ? null : _selectedCategory,
        onlyAvailable: true,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Menu yuklanmoqda...',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      fontSize: isTablet ? 18 : 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        var meals = snap.data!;
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          meals = meals.where((m) => m.name.toLowerCase().contains(q)).toList();
        }

        if (meals.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState(context, scheme, isTablet),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: isTablet ? 16 : 12,
              crossAxisSpacing: isTablet ? 16 : 12,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final meal = meals[index];
              return MealCard(
                meal: meal,
                onAdd: () => _addToCartWithDebouncedSnack(meal),
                onImageTap: () => _openMealImageViewer(meal), // 👈 NEW
              );
            }, childCount: meals.length),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme scheme,
    bool isTablet,
  ) {
    final isSearching = _query.isNotEmpty;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 32 : 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.restaurant_menu_outlined,
                size: isTablet ? 80 : 64,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: isTablet ? 32 : 24),
            Text(
              isSearching ? 'Qidiruv natijalari topilmadi' : 'Menyu bo\'sh',
              style: TextStyle(
                fontSize: isTablet ? 28 : 24,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              isSearching
                  ? '"$_query" bo\'yicha hech qanday taom topilmadi.\nBoshqa so\'z bilan qidiring.'
                  : 'Hozircha menyu bo\'sh.\nAdmin orqali taom qo\'shing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealImageViewer extends StatelessWidget {
  const _MealImageViewer({required this.meal, required this.provider});
  final Meal meal;
  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Center(
        child: GestureDetector(
          onTap: () {}, // absorb to allow pinch/drag
          child: Hero(
            tag: 'meal_img_${meal.id}',
            placeholderBuilder: (_, _, child) => child, // 👈 keep same child
            child: Material(
              type: MaterialType.transparency,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image(
                    image: provider, // 👈 same provider as card
                    fit: BoxFit.contain, // modal view
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
