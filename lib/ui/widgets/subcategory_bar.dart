import 'package:flutter/material.dart';
import 'package:padshax_app/data/hive_menu_repository.dart';
import 'package:provider/provider.dart';
import '../../domain/root_category.dart';
import '../../domain/category.dart';

class SubCategoryBar extends StatelessWidget {
  /// Current root (food/drink)
  final RootCategory root;

  /// Currently selected subcategory name; null = no filter
  final String? selected;

  /// Called with a category name to filter, or null to clear selection.
  final ValueChanged<String?> onSelected;

  /// Layout flag you already compute in pages
  final bool isTablet;

  /// If true, show ⋮ actions per chip and wire to these callbacks.
  final bool withActions;
  final Future<void> Function(SubCategory sub)? onEdit;
  final Future<void> Function(SubCategory sub)? onDelete;

  const SubCategoryBar({
    super.key,
    required this.root,
    required this.selected,
    required this.onSelected,
    required this.isTablet,
    this.withActions = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<HiveMenuRepository>();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        isTablet ? 16 : 12,
        isTablet ? 24 : 16,
        0,
      ),
      child: StreamBuilder<List<SubCategory>>(
        stream: repo.watchSubCategories(root),
        builder: (context, snap) {
          final subs =
              (snap.data ?? const <SubCategory>[])
                  .where((s) => s.name.trim().isNotEmpty)
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );

          if (subs.isEmpty) return const SizedBox.shrink();

          return SizedBox(
            height: isTablet ? 56 : 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subs.length,
              separatorBuilder: (_, _) => SizedBox(width: isTablet ? 12 : 8),
              itemBuilder: (context, i) {
                final sub = subs[i];
                final sel = selected == sub.name;

                final chip = FilterChip(
                  label: Text(
                    sub.name,
                    // ✅ Ensure visible text color on selection
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                      color: sel ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                  ),
                  selected: sel,
                  onSelected: (_) {
                    // No "All" chip — tapping selected again clears selection
                    onSelected(sel ? null : sub.name);
                  },
                  backgroundColor: scheme.surface,
                  selectedColor: scheme.primaryContainer,
                  checkmarkColor: scheme.onPrimaryContainer,
                  side: BorderSide(
                    color: sel
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.3),
                    width: sel ? 2 : 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 12 : 8,
                  ),
                );

                if (!withActions) return chip;

                // Admin mode: chip + ⋮ menu (outside chip so it's always tappable)
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    chip,
                    PopupMenuButton<String>(
                      tooltip: 'Boshqarish',
                      onSelected: (v) async {
                        if (v == 'edit' && onEdit != null) await onEdit!(sub);
                        if (v == 'delete' && onDelete != null) {
                          await onDelete!(sub);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Nomini tahrirlash'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('O‘chirish (taomlari bilan)'),
                          ),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.more_vert, size: 18),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
